#!/usr/bin/env python3
"""tools/spell-research/logs.py — combat-log evidence for AuraMaster's spell categories.

Design of record: docs/superpowers/specs/2026-09-24-spell-ids-from-combat-logs-design.md.

Subcommands:
    scan     Stream every WoWCombatLog-*.txt in a folder (only logs not already cached),
             merge the per-spec evidence of player-applied auras, print a summary and write
             evidence.json (counts only; no player name, realm, GUID or hash).
    propose  Read evidence.json, the DB2 tables and the shipped categories, and write the bundle:
             the per-spec aura dictionary and the review set (CORRECTIONS.md,
             PROPOSED_ADDITIONS.md, FLAGS.md, ... and proposals.json, the review queue).
    decide   Record the owner's ruling on one proposal key of a bundle in decisions.json
             (accept / reject / move into a chosen category); the only writer of that file.
    apply    Apply the bundle's ruled proposals to defaults/Categories.lua (the only writer of
             that file; unruled proposals are left alone) and write the bundle's DECISIONS.md.

The per-log cache and its salt live outside the repo (default
~/.cache/auramaster-spell-research/). Python 3.8+ standard library only.
"""

import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import research  # noqa: E402
import sid_cache  # noqa: E402
import sid_decide  # noqa: E402
import sid_propose  # noqa: E402

DEFAULT_LOGS = Path("/mnt/g/Games/Blizzard/World of Warcraft/_retail_/Logs/RaiderIOLogsArchive")
DEFAULT_DB2_CACHE = HERE / ".cache"
REPO = HERE.parent.parent
DEFAULT_CATEGORIES = REPO / "defaults" / "Categories.lua"
DEFAULT_CAST_TO_AURA = REPO / "defaults" / "CastToAura.lua"
DEFAULT_DECISIONS = HERE / "decisions.json"


def spec_to_class_from_db2(db2_cache, build=None):
    """spec id -> class token, from ChrSpecialization in the DB2 cache (sid_db2, imported lazily)."""
    try:
        import sid_db2
    except ImportError as exc:
        raise SystemExit("logs.py: the DB2 reader sid_db2 is not available (%s)" % exc)
    tables = sid_db2.open_db2(Path(db2_cache), build)
    spec_map = sid_db2.load_spec_map(tables["ChrSpecialization"])
    return {int(spec): info["class"] for spec, info in spec_map.items()}


def format_summary(s):
    return ("Scanned %s (%.1f MB): read %d, cached %d; dates %s..%s; "
            "lines %d, skipped %d, unattributed %d"
            % (sid_propose.plural(s["files"], "log"), s["bytes"] / 1e6, s["read"], s["cached"],
               s["first_date"] or "-", s["last_date"] or "-",
               s["lines"], s["skipped"], s["unattributed"]))


def cmd_scan(args):
    spec_to_class = spec_to_class_from_db2(args.db2_cache)
    agg, summary = sid_cache.scan_dir(args.logs, args.cache, spec_to_class,
                                      progress=lambda m: print(m, flush=True))
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    evidence = sid_cache.evidence_to_json(agg, summary)
    research.write_repo_text(out, json.dumps(evidence, indent=1, ensure_ascii=False) + "\n")
    print(format_summary(summary))
    print("Wrote %s" % out)
    return 0


def _shown(path):
    # type: (Path) -> str
    """A path as the bundle records it: repo-relative when inside the repo, else its name."""
    path = Path(path)
    try:
        return path.resolve().relative_to(REPO.resolve()).as_posix()
    except ValueError:
        return path.name


def load_decisions(path):
    # type: (Path) -> dict
    """{proposal key: ruling entry} from decisions.json (sid_decide's reader); {} when missing."""
    try:
        return sid_decide.load_decisions(path)
    except ValueError as exc:
        raise SystemExit("logs.py: %s" % exc)


def _aura_ids(agg, aura_type):
    return {sid for auras in agg.per_spec.values() for (atype, sid) in auras if atype == aura_type}


def cmd_propose(args):
    if not research.DATE_RE.match(args.date or ""):
        raise SystemExit("logs.py propose: --date must be YYYY-MM-DD, got %r" % args.date)
    import sid_artifacts
    import sid_db2

    bundle = Path(args.bundle)
    evidence_path = Path(args.evidence) if args.evidence else bundle / "evidence.json"
    if not evidence_path.exists():
        raise SystemExit("logs.py propose: no evidence at %s; run `logs.py scan --out %s` first"
                         % (evidence_path, bundle / "evidence.json"))
    evidence_text = evidence_path.read_text(encoding="utf-8")
    agg = sid_cache.evidence_from_json(json.loads(evidence_text))

    tables = sid_db2.open_db2(Path(args.db2_cache), None)
    build = tables["SpellName"].name[len("SpellName-"):-len(".csv")]
    spec_map = sid_db2.load_spec_map(tables["ChrSpecialization"])
    names = sid_db2.names(tables["SpellName"])
    shipped = sid_db2.shipped_categories(Path(args.categories))
    if not shipped:
        raise SystemExit("logs.py propose: no `spells` category in %s" % args.categories)
    candidates = sid_db2.cast_aura_candidates(Path(args.cast_to_aura))
    family = sid_db2.aura_to_family(candidates)
    decisions = load_decisions(args.decisions)
    signals = sid_db2.aura_signals(tables["SpellEffect"], _aura_ids(agg, "BUFF"))
    pool, pool_names = sid_db2.castable(tables)
    cc_ids = sid_db2.cc_spell_ids(tables["SpellEffect"], tables["SpellCategories"],
                                  _aura_ids(agg, "DEBUFF"))
    th = sid_propose.Thresholds(min_applications=args.min_apps, min_players=args.min_players)

    addition_counts = {}  # type: dict
    proposals = (sid_propose.corrections(agg, spec_map, names, shipped, family, decisions, th,
                                         cc_ids=cc_ids)
                 + sid_propose.moves(agg, spec_map, names, shipped, signals, pool, candidates,
                                     decisions, th, pool_names=pool_names)
                 + sid_propose.additions(agg, spec_map, names, shipped, signals, pool, candidates,
                                         decisions, th, pool_names=pool_names,
                                         summary=addition_counts))
    flags = sid_propose.flags(agg, spec_map, names, shipped, family, cc_ids, th)
    rows = sid_artifacts.dictionary_rows(
        agg, spec_map, names, shipped,
        sid_propose.suggestions(agg, spec_map, signals, pool, candidates, pool_names=pool_names,
                                names=names))

    bundle.mkdir(parents=True, exist_ok=True)
    in_bundle = bundle / "evidence.json"
    if not in_bundle.exists() or in_bundle.resolve() != evidence_path.resolve():
        research.write_repo_text(in_bundle, evidence_text)
    class_players = dict(agg.class_players) or sid_cache.player_unions(agg)[0]
    sources = {
        "summary": dict(json.loads(evidence_text).get("summary") or {}, lines=agg.lines,
                        skipped=agg.skipped, unattributed=agg.unattributed),
        "db2_build": build, "db2_tables": [t for t, _why in research.TABLES],
        "thresholds": {"min_applications": th.min_applications, "min_players": th.min_players,
                       "stale_days": th.stale_days},
        "categories": _shown(args.categories), "cast_to_aura": _shown(args.cast_to_aura),
        "decisions": _shown(args.decisions), "decisions_count": len(decisions),
        "evidence": "evidence.json",
    }
    sid_artifacts.write_bundle(bundle, args.date, rows, proposals, flags, shipped, sources,
                               non_player=agg.non_player, names=names,
                               class_players=class_players, addition_counts=addition_counts)
    corr = sum(1 for p in proposals if p.type in sid_artifacts.CORRECTION_TYPES)
    print("Proposed into %s: corrections %d, additions %d, flags %d; dictionary rows %d"
          % (bundle, corr, len(proposals) - corr, len(flags), len(rows)))
    print("Additions from %s: %d low confidence (dictionary only), %d folded into %s"
          % (sid_propose.plural(addition_counts.get("raw", 0), "candidate"),
             addition_counts.get("low", 0), addition_counts.get("folded", 0),
             sid_propose.plural(addition_counts.get("all", 0), "ALL proposal")))
    print("Review: %s, %s; queue: %s; dictionary: %s"
          % (bundle / "CORRECTIONS.md", bundle / "PROPOSED_ADDITIONS.md",
             bundle / "proposals.json", bundle / "dictionary" / "AURAS.md"))
    return 0


def _bundle_queue(bundle):
    # type: (Path) -> dict
    path = Path(bundle) / "proposals.json"
    if not path.exists():
        raise SystemExit("logs.py: no proposals at %s; run `logs.py propose` first" % path)
    doc = json.loads(path.read_text(encoding="utf-8"))
    return {"date": doc.get("date") or "", "proposals": list(doc.get("proposals") or [])}


def cmd_decide(args):
    if not research.DATE_RE.match(args.date or ""):
        raise SystemExit("logs.py decide: --date must be YYYY-MM-DD, got %r" % args.date)
    queue = _bundle_queue(args.bundle)
    if args.key not in {p["key"] for p in queue["proposals"]}:
        raise SystemExit("logs.py decide: %s is not a proposal key in %s"
                         % (args.key, Path(args.bundle) / "proposals.json"))
    if args.ruling == "move" and not args.category:
        raise SystemExit("logs.py decide: a move ruling needs --category")
    if args.category:
        import sid_db2
        known = [cat["key"] for cat in sid_db2.shipped_categories(Path(args.categories))]
        if args.category not in known:
            raise SystemExit("logs.py decide: --category %s is not a `spells` category of %s "
                             "(known: %s)" % (args.category, args.categories, ", ".join(known)))
    try:
        entry = sid_decide.record(args.decisions, args.key, args.ruling, category=args.category,
                                  reason=args.reason, date=args.date)
    except ValueError as exc:
        raise SystemExit("logs.py decide: %s" % exc)
    print("Recorded %s%s for %s in %s"
          % (entry["ruling"], " -> %s" % entry["category"] if entry.get("category") else "",
             args.key, args.decisions))
    return 0


def cmd_apply(args):
    queue = _bundle_queue(args.bundle)
    decisions = load_decisions(args.decisions)
    ruled = [p for p in queue["proposals"] if p["key"] in decisions]
    pending = len(queue["proposals"]) - len(ruled)
    try:
        changes = sid_decide.apply(Path(args.categories), decisions, ruled, _shown(args.bundle))
    except ValueError as exc:
        raise SystemExit("logs.py apply: %s" % exc)
    md = sid_decide.write_decisions_md(Path(args.bundle), queue["date"], decisions,
                                       queue["proposals"], changes)
    for change in changes:
        print(change)
    print("Applied %s to %s: %s; %d not yet ruled. Wrote %s"
          % (sid_propose.plural(len(ruled), "ruled proposal"), args.categories,
             sid_propose.plural(len(changes), "line change"), pending, md))
    return 0


def build_parser():
    p = argparse.ArgumentParser(prog="logs.py", description=__doc__.split("\n\n")[0])
    sub = p.add_subparsers(dest="command", metavar="command")
    sub.required = True

    scan = sub.add_parser("scan", help="scan combat logs into evidence.json")
    scan.add_argument("--logs", type=Path, default=DEFAULT_LOGS,
                      help="folder of WoWCombatLog-*.txt files (default: %(default)s)")
    scan.add_argument("--cache", type=Path, default=sid_cache.DEFAULT_CACHE_DIR,
                      help="per-log cache and salt, outside the repo (default: %(default)s)")
    scan.add_argument("--db2-cache", type=Path, default=DEFAULT_DB2_CACHE,
                      help="research.py's DB2 CSV cache (default: %(default)s)")
    scan.add_argument("--out", type=Path, required=True,
                      help="evidence.json to write, e.g. docs/spell-research/<date>-logs/evidence.json")
    scan.set_defaults(func=cmd_scan)

    prop = sub.add_parser("propose", help="write the dictionary and the review set into a bundle")
    prop.add_argument("--date", required=True,
                      help="the bundle's date, YYYY-MM-DD (required; never taken from the clock)")
    prop.add_argument("--bundle", type=Path, required=True,
                      help="bundle folder, e.g. docs/spell-research/<date>-logs")
    prop.add_argument("--evidence", type=Path, default=None,
                      help="evidence.json from `scan` (default: <bundle>/evidence.json)")
    prop.add_argument("--db2-cache", type=Path, default=DEFAULT_DB2_CACHE,
                      help="research.py's DB2 CSV cache (default: %(default)s)")
    prop.add_argument("--categories", type=Path, default=DEFAULT_CATEGORIES,
                      help="the shipped categories (default: defaults/Categories.lua)")
    prop.add_argument("--cast-to-aura", type=Path, default=DEFAULT_CAST_TO_AURA,
                      help="the cast -> aura candidates (default: defaults/CastToAura.lua)")
    prop.add_argument("--decisions", type=Path, default=DEFAULT_DECISIONS,
                      help="the owner's rulings (default: tools/spell-research/decisions.json)")
    prop.add_argument("--min-apps", type=int, default=sid_propose.DEFAULT_MIN_APPLICATIONS,
                      help="evidence bar: applications (default: %(default)s)")
    prop.add_argument("--min-players", type=int, default=sid_propose.DEFAULT_MIN_PLAYERS,
                      help="evidence bar: distinct players (default: %(default)s)")
    prop.set_defaults(func=cmd_propose)

    dec = sub.add_parser("decide", help="record the owner's ruling on one proposal")
    dec.add_argument("--bundle", type=Path, required=True,
                     help="bundle folder holding proposals.json")
    dec.add_argument("--key", required=True, help="the proposal key (proposals.json `key`)")
    dec.add_argument("--ruling", required=True, choices=sid_decide.RULINGS,
                     help="accept, reject (suppressed for good), or move (into --category)")
    dec.add_argument("--category", default=None,
                     help="the category to put it in instead (required for move)")
    dec.add_argument("--reason", default="", help="optional reason, kept with the ruling")
    dec.add_argument("--date", required=True,
                     help="the ruling's date, YYYY-MM-DD (required; never taken from the clock)")
    dec.add_argument("--decisions", type=Path, default=DEFAULT_DECISIONS,
                     help="the owner's rulings (default: tools/spell-research/decisions.json)")
    dec.add_argument("--categories", type=Path, default=DEFAULT_CATEGORIES,
                     help="the shipped categories, to check --category (default: "
                          "defaults/Categories.lua)")
    dec.set_defaults(func=cmd_decide)

    app = sub.add_parser("apply", help="apply the bundle's ruled proposals to Categories.lua")
    app.add_argument("--bundle", type=Path, required=True,
                     help="bundle folder holding proposals.json; DECISIONS.md is written there")
    app.add_argument("--categories", type=Path, default=DEFAULT_CATEGORIES,
                     help="the file to rewrite (default: defaults/Categories.lua)")
    app.add_argument("--decisions", type=Path, default=DEFAULT_DECISIONS,
                     help="the owner's rulings (default: tools/spell-research/decisions.json)")
    app.set_defaults(func=cmd_apply)
    return p


def main(argv=None):
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
