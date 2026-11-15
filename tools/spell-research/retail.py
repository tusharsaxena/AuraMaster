#!/usr/bin/env python3
"""tools/spell-research/retail.py — re-validate Retail's seed lists against a wago.tools build (issue #27).

WHAT THIS IS
    defaults/Categories_Retail.lua is hand-curated: the 2026-09-20 DB2 run seeded the CC lists, the
    2026-09-24 combat logs corrected the rest, and the owner's rulings live in its comments. This
    tool re-checks every list against one pinned Retail build and turns what it finds into
    CANDIDATES and FLAGS, each of which needs a ruling recorded as data. A re-run on a later build
    therefore shows only what is new since the last ruled one: a ruling is keyed by category and
    id, not by build, and it stays until the thing it ruled on stops being proposed.

    Candidates (key `<category>:<id>`, ruled accept or reject):
        cc-mechanic / bridge   research.derive's hardCC / ccRoot / ccSnare ids the list lacks
        db2-effect             a player spell whose own aura effects fit a non-CC category
                               (sid_seeds.DB2_RULES, the rules forever.py runs on Forever),
                               not shipped anywhere in the same aura type
        hand                   HAND_CANDIDATES below, each with its reason

    Flags (key `shipped:<kind>:<category>:<id>`, ruled keep or remove), over every shipped id:
        unnamed    the build's SpellName has no row for it
        no-aura    it applies no aura of its own (effects 6, 35, 65, 119, 128), so it never matches
        renamed    its name disagrees with the comment beside it
        dropped    the previous bundle's build could reach it and this build cannot

    The player-reachable set ("reach": the class pool closed over EffectTriggerSpell, the racial
    lines and the derived CC ids) is frozen in the bundle's reach.json, so the next run's `dropped`
    flags and its pool delta are computed against it without the old build's tables.

THE STEPS
    python3 tools/spell-research/retail.py status
    python3 tools/spell-research/research.py --bundle docs/spell-research/<date>-retail --date <date>
    python3 tools/spell-research/retail.py derive --bundle docs/spell-research/<date>-retail --date <date>
    python3 tools/spell-research/retail.py rule --key offensiveCDs:1719 --ruling accept --reason "..."
    python3 tools/spell-research/retail.py rule --tsv rulings.tsv --bundle docs/spell-research/<date>-retail
    python3 tools/spell-research/retail.py check --bundle docs/spell-research/<date>-retail
    python3 tools/spell-research/retail.py apply --bundle docs/spell-research/<date>-retail --date <date>
    python3 tools/spell-research/retail.py report --bundle docs/spell-research/<date>-retail --date <date>

    `status` says whether wago.tools has a newer live Retail build than the newest bundle. `derive`
    reads research.py's frozen raw/ tables and adds EXTRA_TABLES to the same raw/; `--replay`
    re-derives offline. `apply` refuses while anything is unruled, inserts each accepted candidate
    into its class table (sid_decide's writer, the one logs.py uses) and removes each id whose flag
    was ruled `remove`. It never removes an id on its own. `report` writes the bundle's RULINGS.md.

    Rulings live in tools/spell-research/retail_rulings.json, and `rule` is its only writer.

Python 3 and its standard library only, like research.py.
"""

from __future__ import annotations

import argparse
import gzip
import json
import re
import shutil
import sys
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import research  # noqa: E402
import sid_decide  # noqa: E402
from sid_seeds import (  # noqa: E402
    ALLOWED_OVERLAPS, AURA_TYPE, CATEGORY_KEYS, CATEGORY_RANK, CC_KEYS, Candidate, SeedDB,
    db2_candidates, load_rulings, read_tsv, save_rulings, write_json,
)

CLIENT = "retail"
SEEDS_PATH = research.repo_root() / "defaults" / "Categories_Retail.lua"
RULINGS_PATH = HERE / "retail_rulings.json"
SPELL_RESEARCH = research.repo_root() / "docs" / "spell-research"
BUNDLE_SUFFIX = "-retail"

# The tables read beyond research.py's Retail set (the DB2 rules' recast fence, passive flag and
# rank text), fetched once into the bundle's raw/ and replayed from there after.
EXTRA_TABLES = (
    ("Spell", "NameSubtext_lang: the rank text a spell carries, for the comment and the ruling"),
    ("SpellCooldowns", "RecoveryTime / CategoryRecoveryTime: the long-recast fence of DB2_RULES"),
    ("SpellMisc", "Attributes_0 bit 0x40 (SPELL_ATTR0_PASSIVE): a passive is flagged for the ruling"),
)

# THE HAND CANDIDATES: ids the DB2 rules propose under the wrong category (or not at all), proposed
# where the owner's own precedent files them. Each still needs a ruling; one that is not an aura on
# the build is listed in candidates.json's `handMissing`, so a later build shows what fell out.
# (category, id, class key, why). Evidence: the bundle's ANALYSIS.md.
HAND_CANDIDATES = (
    ("defensives", 47788, "PRIEST", "an external; the owner files externals in Defensives (Pain Suppression 33206)"),
    ("defensives", 22842, "DRUID", "a self-heal cooldown; the rules propose it as a stance (shapeshift-only effect)"),
)

CANDIDATE_RULINGS = ("accept", "reject")
FLAG_RULINGS = ("keep", "remove")
FLAG_KINDS = ("unnamed", "no-aura", "renamed", "dropped")
KEY = re.compile(r"^(?:shipped:(?P<kind>[a-z-]+):)?(?P<category>\w+):(?P<id>\d+)$")
AURA_NAME = {"BUFF": "HELPFUL", "DEBUFF": "HARMFUL"}


# ---------------------------------------------------------------------------
# The build's facts
# ---------------------------------------------------------------------------

def retail_pool(db: SeedDB) -> dict[int, set[str]]:
    """The Retail player pool `{spell: classes}`: research.py's pool closed over EffectTriggerSpell
    (the family bridge is CC-only and stays in research.derive)."""
    pool, classes = research.pool_for(db.tables, CLIENT)
    while research.close_over_triggers(pool, classes, db.triggers):
        pass
    return {spell: set(classes.get(spell, ())) for spell in pool}


def reach_of(db: SeedDB, pool: dict[int, set[str]], cc_result: dict) -> set[int]:
    """Every id a player can reach on the build: the pool, the racial lines, the derived CC ids."""
    cc = {int(sid) for bucket in cc_result["buckets"].values() for sid in bucket}
    return set(pool) | db.racial | cc


def read_seeds(path: Path) -> list[dict]:
    """The seed file's lists: research.read_categories_file plus the aura type as BUFF/DEBUFF."""
    cats = research.read_categories_file(path)
    for cat in cats:
        if cat["aura"] not in ("HELPFUL", "HARMFUL"):
            raise SystemExit("%s: list %r is not in the seed(...) shape." % (path, cat["key"]))
        if cat["key"] not in AURA_TYPE:
            raise SystemExit("%s: %r is a spells category sid_seeds.SPELL_CATEGORIES does not know."
                             % (path, cat["key"]))
        want = AURA_NAME[AURA_TYPE[cat["key"]]]
        if cat["aura"] != want:
            raise SystemExit("%s: %r is seeded as %s, SPELL_CATEGORIES says %s."
                             % (path, cat["key"], cat["aura"], want))
    return cats


def shipped_index(cats: list[dict]) -> tuple[dict[str, set[int]], dict[str, set[int]]]:
    """`({category: ids}, {BUFF|DEBUFF: ids})` of the shipped lists."""
    by_cat: dict[str, set[int]] = {key: set() for key in CATEGORY_KEYS}
    by_aura: dict[str, set[int]] = defaultdict(set)
    for cat in cats:
        ids = {rec["id"] for rec in cat["records"]}
        by_cat[cat["key"]] |= ids
        by_aura[AURA_TYPE[cat["key"]]] |= ids
    return by_cat, by_aura


# ---------------------------------------------------------------------------
# Candidates and flags
# ---------------------------------------------------------------------------

def cc_candidates(cc_result: dict, db: SeedDB, by_cat: dict[str, set[int]]) -> list[Candidate]:
    """research.derive's CC ids a list lacks, labelled `bridge` when the family bridge reached them."""
    out: list[Candidate] = []
    for bucket in CC_KEYS:
        for sid, entry in cc_result["buckets"][bucket].items():
            spell = int(sid)
            if spell in by_cat[bucket]:
                continue
            source = "bridge" if entry.get("source") == "bridge" else "cc-mechanic"
            mechs = ", ".join(m["name"] for m in entry.get("mechanics", ()))
            notes = (["mechanic: " + mechs] if mechs else []) + db.notes(spell)
            out.append(Candidate(spell, bucket, entry["class"], source, None, entry.get("name", ""),
                                 db.rank(spell), None, notes))
    return out


def effect_candidates(db: SeedDB, pool: dict[int, set[str]],
                      by_aura: dict[str, set[int]]) -> list[Candidate]:
    """The DB2 rules' candidates for every non-CC category, minus every id already shipped in the
    same aura type (one category per id within an aura type)."""
    out: list[Candidate] = []
    for key in CATEGORY_KEYS:
        if key in CC_KEYS:
            continue
        out.extend(c for c in db2_candidates(key, db, pool) if c.id not in by_aura[AURA_TYPE[key]])
    return out


def hand_candidates(db: SeedDB, by_aura: dict[str, set[int]], missing: list,
                    entries=HAND_CANDIDATES) -> list[Candidate]:
    """HAND_CANDIDATES that are an aura on the build and not yet shipped in their aura type."""
    out: list[Candidate] = []
    for key, spell, klass, why in entries:
        if not db.names.get(spell) or spell not in db.appliers:
            missing.append({"category": key, "id": spell, "class": klass, "why": why})
            continue
        if spell not in by_aura[AURA_TYPE[key]]:
            out.append(Candidate(spell, key, klass, "hand", None, db.names[spell], db.rank(spell),
                                 None, ["hand: " + why] + db.notes(spell)))
    return out


def sort_key(c: Candidate) -> tuple:
    order = research.CLASS_EMIT_ORDER
    return (CATEGORY_RANK.get(c.category, len(CATEGORY_RANK)),
            order.index(c.klass) if c.klass in order else len(order), c.name.lower(), c.id)


def shipped_flags(db: SeedDB, cats: list[dict], reach: set[int], prev_reach: set[int] | None) -> list[dict]:
    """One flag per (kind, category, id) slot a shipped id fails. `dropped` needs a previous reach."""
    out: list[dict] = []
    for cat in cats:
        for rec in cat["records"]:
            spell, name = rec["id"], db.names.get(rec["id"]) or ""
            kinds = []
            if not name:
                kinds.append("unnamed")
            else:
                if spell not in db.appliers:
                    kinds.append("no-aura")
                if rec["comment"] and rec["comment"].lower() != name.lower():
                    kinds.append("renamed")
            if prev_reach is not None and spell in prev_reach and spell not in reach:
                kinds.append("dropped")
            for kind in kinds:
                out.append({"key": "shipped:%s:%s:%d" % (kind, cat["key"], spell), "kind": kind,
                            "category": cat["key"], "id": spell, "class": rec["class"],
                            "name": name, "comment": rec["comment"] or ""})
    return out


# ---------------------------------------------------------------------------
# Bundles
# ---------------------------------------------------------------------------

def bundle_tables(bundle: Path, replay: bool, cache_dir: Path) -> tuple[dict[str, Path], str]:
    """`({table: raw path}, build)`: research.py's Retail tables from the bundle plus EXTRA_TABLES,
    fetched once into raw/ unless `replay`, where a missing one is fatal."""
    if not (bundle / "derived.json").exists():
        raise SystemExit("%s has no derived.json: run research.py --bundle %s --date <date> first."
                         % (bundle, bundle))
    research.check_replay_client(bundle, CLIENT)
    build, _fetched = research.replay_provenance(bundle, None)
    tables = {t: research.fetch_table(t, build, cache_dir, False, bundle) for t, _w in research.tables_for(CLIENT)}
    for table, _why in EXTRA_TABLES:
        member = bundle / "raw" / ("%s.csv.gz" % table)
        if not member.exists():
            if replay:
                raise SystemExit("--replay: %s is missing raw/%s.csv.gz; run derive once without --replay."
                                 % (bundle, table))
            source = research.fetch_table(table, build, cache_dir, False)
            with source.open("rb") as src, gzip.open(member, "wb", compresslevel=9) as dst:
                shutil.copyfileobj(src, dst, research.DOWNLOAD_CHUNK)
        tables[table] = member
    return tables, build


def bundle_build(bundle: Path) -> str:
    return json.loads((bundle / "derived.json").read_text(encoding="utf-8"))["build"]


def retail_bundles(root: Path = SPELL_RESEARCH) -> list[Path]:
    """Every retail.py bundle under docs/spell-research/, oldest first (by name: dates sort)."""
    return sorted(p for p in root.glob("*" + BUNDLE_SUFFIX) if (p / "candidates.json").exists())


def previous_reach(previous: Path | None, cache_dir: Path) -> tuple[set[int] | None, dict, str]:
    """`(reach, {id: name}, build)` of the previous bundle: its reach.json when it has one (a
    retail.py bundle), else derived from its raw/ (a research.py bundle such as 2026-09-20)."""
    if previous is None:
        return None, {}, ""
    build = bundle_build(previous)
    frozen = previous / "reach.json"
    tables = {t: research.fetch_table(t, build, cache_dir, False, previous)
              for t, _w in research.tables_for(CLIENT)}
    names = research.read_names(tables["SpellName"])
    if frozen.exists():
        return set(json.loads(frozen.read_text(encoding="utf-8"))["reach"]), names, build
    research.log("Deriving the previous build's reach from %s/raw ..." % previous)
    db = SeedDB(tables)
    return reach_of(db, retail_pool(db), research.derive(tables, CLIENT)), names, build


def derive_bundle(tables: dict[str, Path], build: str, date: str, seeds: Path,
                  previous: Path | None, cache_dir: Path) -> tuple[dict, list[int]]:
    """`(candidates.json's document, the sorted reach)`."""
    db = SeedDB(tables)
    cc_result = research.derive(tables, CLIENT)
    missing = research.check_sentinels(cc_result)
    if missing:
        raise SystemExit("Retail coverage gate FAILED: %s. Fix the pool before ruling anything."
                         % "; ".join(missing))
    pool = retail_pool(db)
    reach = reach_of(db, pool, cc_result)
    cats = read_seeds(seeds)
    by_cat, by_aura = shipped_index(cats)
    hand_missing: list[dict] = []
    candidates = sorted(cc_candidates(cc_result, db, by_cat) + effect_candidates(db, pool, by_aura)
                        + hand_candidates(db, by_aura, hand_missing), key=sort_key)
    prev, prev_names, prev_build = previous_reach(previous, cache_dir)
    flags = shipped_flags(db, cats, reach, prev)
    delta = {"added": [], "removed": []}
    if prev is not None:
        keys = {c.id for c in candidates}
        delta["added"] = [{"id": s, "name": db.names.get(s, ""), "candidate": s in keys}
                          for s in sorted(reach - prev)]
        delta["removed"] = [{"id": s, "name": prev_names.get(s, "") or db.names.get(s, ""),
                             "shipped": any(s in ids for ids in by_cat.values())}
                            for s in sorted(prev - reach)]
    counts = {key: sum(1 for c in candidates if c.category == key) for key in CATEGORY_KEYS}
    doc = {
        "client": CLIENT, "build": build, "date": date, "tool": "tools/spell-research/retail.py derive",
        "previous": {"bundle": previous.name if previous else None, "build": prev_build or None},
        "counts": counts, "reachSize": len(reach),
        "candidates": [c.to_json() for c in candidates],
        "flags": flags, "poolDelta": delta, "handMissing": hand_missing,
    }
    return doc, sorted(reach)


def load_candidates(bundle: Path) -> dict:
    path = bundle / "candidates.json"
    if not path.exists():
        raise SystemExit("%s has no candidates.json: run retail.py derive first." % bundle)
    return json.loads(path.read_text(encoding="utf-8"))


def all_keys(doc: dict) -> list[str]:
    return [c["key"] for c in doc["candidates"]] + [f["key"] for f in doc["flags"]]


def unruled_keys(doc: dict, rulings: dict) -> list[str]:
    return [key for key in all_keys(doc) if key not in rulings]


# ---------------------------------------------------------------------------
# Rulings
# ---------------------------------------------------------------------------

def set_ruling(rulings: dict, key: str, ruling: str, reason: str) -> None:
    """Record one ruling; a malformed key, ruling or reason is a SystemExit naming it."""
    match = KEY.match(key)
    if not match or match.group("category") not in AURA_TYPE:
        raise SystemExit("--key %r is not <category>:<id> or shipped:<kind>:<category>:<id>." % key)
    kind = match.group("kind")
    allowed = FLAG_RULINGS if kind else CANDIDATE_RULINGS
    if kind and kind not in FLAG_KINDS:
        raise SystemExit("--key %r: unknown flag kind %r." % (key, kind))
    if ruling not in allowed:
        raise SystemExit("--ruling for %s must be %s; got %r." % (key, " or ".join(allowed), ruling))
    reason = (reason or "").strip()
    if not reason or "\n" in reason:
        raise SystemExit("--reason for %s must be one non-empty line." % key)
    rulings[key] = {"ruling": ruling, "reason": reason}


# ---------------------------------------------------------------------------
# Apply
# ---------------------------------------------------------------------------

def plan_apply(doc: dict, rulings: dict, cats: list[dict]) -> tuple[list[dict], list[dict]]:
    """`(inserts, removals)`, each `{category, class, id, name}`. Refuses (SystemExit) while
    anything is unruled, or when two accepted ids would share one aura type's category slot."""
    unruled = unruled_keys(doc, rulings)
    if unruled:
        raise SystemExit("apply refused: %d key(s) unruled (retail.py check lists them)." % len(unruled))
    by_cat, _by_aura = shipped_index(cats)
    held: dict[tuple[str, int], str] = {}
    for key, ids in by_cat.items():
        for spell in ids:
            held.setdefault((AURA_TYPE[key], spell), key)
    inserts: list[dict] = []
    for c in doc["candidates"]:
        if rulings[c["key"]]["ruling"] != "accept" or c["id"] in by_cat[c["category"]]:
            continue
        slot = (AURA_TYPE[c["category"]], c["id"])
        other = held.get(slot)
        if other and other != c["category"] and frozenset((other, c["category"])) not in ALLOWED_OVERLAPS:
            raise SystemExit("apply refused: %s is accepted into %s but %s already holds it."
                             % (c["key"], c["category"], other))
        held[slot] = c["category"]
        inserts.append({"category": c["category"], "class": c["class"], "id": c["id"], "name": c["name"]})
    removals = [{"category": f["category"], "class": f["class"], "id": f["id"], "name": f["name"]}
                for f in doc["flags"] if rulings[f["key"]]["ruling"] == "remove"
                and f["id"] in by_cat[f["category"]]]
    return inserts, removals


def apply_bundle(doc: dict, rulings: dict, seeds: Path, date: str) -> list[str]:
    """Write the accepted inserts and ruled removals into the seed file; return the change log."""
    cats = read_seeds(seeds)
    inserts, removals = plan_apply(doc, rulings, cats)
    provenance = "added from the %s wago.tools re-validation (%s)" % (date, doc["build"])
    lua = sid_decide._Lua(seeds.read_bytes().decode("utf-8"),
                          {row["id"]: row["name"] for row in inserts}, date, provenance)
    changes: list[str] = []
    grouped: dict[tuple[str, str], list[int]] = defaultdict(list)
    for row in inserts:
        grouped[(row["category"], row["class"])].append(row["id"])
    for (category, klass), ids in grouped.items():
        added = lua.insert(category, klass, ids)
        if added:
            changes.append("%s %s: +%s" % (category, klass, ", ".join(str(i) for i in added)))
    for row in removals:
        removed = lua.remove(row["category"], row["class"], [row["id"]])
        if removed:
            changes.append("%s %s: -%d" % (row["category"], row["class"], row["id"]))
    if changes:
        research.write_repo_text(seeds, lua.text())
    return changes


# ---------------------------------------------------------------------------
# RULINGS.md
# ---------------------------------------------------------------------------

def _cell(text: str) -> str:
    return (text or "").replace("|", "\\|")


def format_rulings_md(doc: dict, rulings: dict, date: str) -> str:
    cands, flags = doc["candidates"], doc["flags"]
    unruled = unruled_keys(doc, rulings)
    tally = defaultdict(int)
    for key in all_keys(doc):
        tally[rulings.get(key, {}).get("ruling", "unruled")] += 1
    prev = doc.get("previous") or {}
    lines = ["# Rulings — Retail re-validation, %s (build %s)" % (doc["date"], doc["build"]), "",
             "Generated by `tools/spell-research/retail.py report` on %s from this bundle's "
             "`candidates.json` and `tools/spell-research/retail_rulings.json`. Do not edit by hand." % date, "",
             "Previous bundle: %s (build %s). Reach %d ids." % (prev.get("bundle") or "none",
                                                                 prev.get("build") or "-", doc["reachSize"]), "",
             "%d candidates, %d flags: %s." % (len(cands), len(flags), ", ".join(
                 "%d %s" % (n, r) for r, n in sorted(tally.items()))), ""]
    if unruled:
        lines += ["## Unruled — %d" % len(unruled), ""] + ["- `%s`" % k for k in unruled] + [""]
    lines += ["## Candidates", ""]
    for key in CATEGORY_KEYS:
        rows = [c for c in cands if c["category"] == key]
        if not rows:
            continue
        lines += ["### %s — %d" % (key, len(rows)), "",
                  "| Id | Name | Class | Source | Notes | Ruling | Reason |", "| --- | --- | --- | --- | --- | --- | --- |"]
        for c in rows:
            r = rulings.get(c["key"], {})
            lines.append("| `%d` | %s | %s | %s | %s | %s | %s |" % (
                c["id"], _cell(c["name"]), c["class"], c["source"], _cell("; ".join(c["notes"])),
                r.get("ruling", "**unruled**"), _cell(r.get("reason", ""))))
        lines.append("")
    lines += ["## Shipped-id flags — %d" % len(flags), ""]
    if flags:
        lines += ["| Kind | Category | Id | Build name | File comment | Ruling | Reason |",
                  "| --- | --- | --- | --- | --- | --- | --- |"]
        for f in flags:
            r = rulings.get(f["key"], {})
            lines.append("| %s | %s | `%d` | %s | %s | %s | %s |" % (
                f["kind"], f["category"], f["id"], _cell(f["name"]), _cell(f["comment"]),
                r.get("ruling", "**unruled**"), _cell(r.get("reason", ""))))
    else:
        lines.append("None.")
    lines.append("")
    delta = doc.get("poolDelta") or {}
    if prev.get("build"):
        lines += ["## Reach delta since build %s" % prev["build"], ""]
        for title, rows, extra in (("Added", delta.get("added", ()), "candidate"),
                                   ("Removed", delta.get("removed", ()), "shipped")):
            lines.append("**%s — %d**" % (title, len(rows)))
            lines.append("")
            lines += ["- `%d` %s%s" % (row["id"], row["name"] or "(no name)",
                                       " — %s" % extra if row.get(extra) else "") for row in rows] or ["None."]
            lines.append("")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def _date(value: str) -> str:
    if not research.DATE_RE.match(value):
        raise argparse.ArgumentTypeError("a date is YYYY-MM-DD; got %r" % value)
    return value


def cmd_status(args) -> int:
    live = research.resolve_build(None, "wow")
    bundles = retail_bundles(args.root)
    if not bundles:
        research.log("Live Retail is %s; no retail.py bundle yet." % live)
        print("NEW %s" % live)
        return 0
    last = bundles[-1]
    built = bundle_build(last)
    if built == live:
        print("CURRENT %s (%s)" % (live, last.name))
    else:
        print("NEW %s (last ruled %s, %s)" % (live, built, last.name))
    return 0


def cmd_derive(args) -> int:
    tables, build = bundle_tables(args.bundle, args.replay, args.cache_dir)
    previous = args.previous
    if previous is None:
        earlier = [b for b in retail_bundles(args.bundle.parent) if b.resolve() != args.bundle.resolve()]
        previous = earlier[-1] if earlier else None
    doc, reach = derive_bundle(tables, build, args.date, args.seeds, previous, args.cache_dir)
    write_json(args.bundle / "candidates.json", doc)
    research.write_repo_text(args.bundle / "reach.json", json.dumps({"build": build, "reach": reach}) + "\n")
    rulings = load_rulings(args.rulings)
    unruled = unruled_keys(doc, rulings)
    for key in CATEGORY_KEYS:
        research.log("  %-17s %d candidates" % (key, doc["counts"][key]))
    research.log("%d candidates, %d flags, %d unruled; reach %d (previous: %s)"
                 % (len(doc["candidates"]), len(doc["flags"]), len(unruled), doc["reachSize"],
                    previous.name if previous else "none"))
    return 0


def cmd_rule(args) -> int:
    todo = [(key, args.ruling, args.reason) for key in (args.key or ())]
    if args.tsv:
        todo += read_tsv(args.tsv)
    if not todo:
        raise SystemExit("rule needs --key (with --ruling and --reason) or --tsv.")
    known = set(all_keys(load_candidates(args.bundle))) if args.bundle else None
    rulings = load_rulings(args.rulings)
    for key, ruling, reason in todo:
        if known is not None and key not in known:
            raise SystemExit("%s is not a candidate or flag in %s/candidates.json." % (key, args.bundle))
        set_ruling(rulings, key, ruling, reason)
    save_rulings(args.rulings, rulings)
    research.log("Recorded %d ruling(s) in %s" % (len(todo), args.rulings))
    return 0


def cmd_check(args) -> int:
    doc = load_candidates(args.bundle)
    unruled = unruled_keys(doc, load_rulings(args.rulings))
    if not unruled:
        print("OK: every candidate and flag in %s is ruled." % args.bundle.name)
        return 0
    by_key = {c["key"]: c for c in doc["candidates"]} | {f["key"]: f for f in doc["flags"]}
    print("%d unruled:" % len(unruled))
    for key in unruled:
        row = by_key[key]
        print("  %s  %s [%s, %s]" % (key, row["name"], row["class"], row.get("source") or row.get("kind")))
    return 1


def cmd_apply(args) -> int:
    doc = load_candidates(args.bundle)
    changes = apply_bundle(doc, load_rulings(args.rulings), args.seeds, args.date)
    for line in changes:
        research.log("  " + line)
    research.log("%d change(s) to %s" % (len(changes), args.seeds))
    return 0


def cmd_report(args) -> int:
    doc = load_candidates(args.bundle)
    research.write_repo_text(args.bundle / "RULINGS.md", format_rulings_md(doc, load_rulings(args.rulings), args.date))
    research.log("Wrote %s" % (args.bundle / "RULINGS.md"))
    return 0


def parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Re-validate Retail's seed lists against a wago.tools build.",
                                     epilog="See tools/spell-research/README.md, 'Retail re-validation'.")
    parser.add_argument("--rulings", type=Path, default=RULINGS_PATH, help="the rulings file")
    parser.add_argument("--seeds", type=Path, default=SEEDS_PATH, help="the Retail seed file")
    parser.add_argument("--cache-dir", type=Path, default=HERE / ".cache", help="the per-build download cache")
    sub = parser.add_subparsers(dest="command", required=True)
    status = sub.add_parser("status", help="is there a live Retail build newer than the newest bundle?")
    status.add_argument("--root", type=Path, default=SPELL_RESEARCH, help="where the bundles are")
    derive = sub.add_parser("derive", help="candidates and flags into the bundle's candidates.json")
    derive.add_argument("--bundle", type=Path, required=True)
    derive.add_argument("--date", type=_date, required=True)
    derive.add_argument("--replay", action="store_true", help="read only the bundle's raw/, no network")
    derive.add_argument("--previous", type=Path, default=None,
                        help="the bundle to diff reach against (default: the newest earlier retail bundle)")
    rule = sub.add_parser("rule", help="record rulings (the only writer of the rulings file)")
    rule.add_argument("--key", action="append")
    rule.add_argument("--ruling")
    rule.add_argument("--reason")
    rule.add_argument("--tsv", type=Path, help="key<TAB>ruling<TAB>reason lines")
    rule.add_argument("--bundle", type=Path, help="refuse keys this bundle's candidates.json lacks")
    for name, helptext in (("check", "exit 1 while anything is unruled"),
                           ("apply", "write accepted ids and ruled removals into the seed file"),
                           ("report", "write the bundle's RULINGS.md")):
        cmd = sub.add_parser(name, help=helptext)
        cmd.add_argument("--bundle", type=Path, required=True)
        if name != "check":
            cmd.add_argument("--date", type=_date, required=True)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    return {"status": cmd_status, "derive": cmd_derive, "rule": cmd_rule, "check": cmd_check,
            "apply": cmd_apply, "report": cmd_report}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
