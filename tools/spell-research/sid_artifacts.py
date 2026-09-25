"""Stage 2's output: the per-spec aura dictionary and the review set, written as one bundle.

The bundle is docs/spell-research/<date>-logs/ (committed; CRLF like every file in the repo):

    evidence.json               from `logs.py scan` (not written here)
    dictionary/auras.json       every (class, spec, auraType, spellId) a player applied -- the
    dictionary/auras.csv        formula is "per spec, and cast by a player, not an NPC" -- whatever
    dictionary/AURAS.md         its count; the same rows three ways (json is the source)
    dictionary/non-player.csv   the pet/totem/guardian/creature tally, not per spec
    CURRENT_CATEGORIES.md       every shipped `spells` id with its evidence status
    CORRECTIONS.md              replace / add / move proposals against listed entries
    PROPOSED_ADDITIONS.md       additions, grouped by recommended category
    FLAGS.md                    unverified, stale, below-the-bar and the CC cross-check
    SOURCES.md                  what was read: logs, DB2 build, thresholds, skipped lines
    proposals.json              the queue the review command walks: corrections, then additions
    REVIEW.csv                  the review sheet: one row per spell id per change (sid_review)
    REVIEW.md                   what the sheet's columns and decision values mean

Nothing here reads a log or a DB2 table: it renders what sid_propose and the evidence already
hold. Only classes, specs, spell names and counts are written -- never a player, realm or GUID.
Python 3.8+ standard library only.
"""

import csv
import io
import json
import re
import statistics
from collections import Counter
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import research
import sid_propose
import sid_review

ROW_KEYS = ("class", "spec", "spec_id", "spell_id", "name", "aura_type", "applications", "players",
            "self_pct", "single_pct", "group_pct", "other_pct", "recast_median_s", "first_seen", "last_seen",
            "category", "suggested_category", "rule")

NON_PLAYER_KEYS = ("aura_type", "spell_id", "name", "applications")

CORRECTION_TYPES = ("replace", "add", "move")

FORMULA = "per spec, and cast by a player (not an NPC)"

STATUSES = (
    ("confirmed", "a player of the class applied it in the logs (counts per spec follow)"),
    ("unverified", "no player of the class applied it, and nothing contradicts it"),
    ("stale", "applied only before the newest two months of the scanned range, while a "
              "same-name sibling is still applied"),
    ("wrong id", "never applied by the class while a same-name aura is: a replace is proposed"),
)

FLAG_SECTIONS = (
    ("unverified", "Unverified",
     "Listed, with no log evidence either way (or kept by the DB2-candidate exception)."),
    ("stale", "Stale", "Listed, not applied recently while a same-name sibling is. Never removed "
                       "without a ruling."),
    ("below_bar", "Below the evidence bar",
     "Sightings of listed spells (and their same-name siblings) under the bar: never proposed."),
    ("cc_unlisted", "Crowd-control debuffs in neither hardCC nor softCC",
     "Debuffs players applied that DB2 gives a crowd-control mechanic. A cross-check only: the CC "
     "categories stay research.py's to derive."),
)


# --- small helpers ------------------------------------------------------------------------------

def _top_name(names):
    # type: (Counter) -> str
    if not names:
        return ""
    return sorted(names.items(), key=lambda kv: (-kv[1], kv[0]))[0][0]


def _pct(part, whole):
    # type: (int, int) -> float
    return round(100.0 * part / whole, 1) if whole else 0.0


def _n(count, word):
    # type: (int, str) -> str
    return sid_propose.plural(count, word)


def _count(value, word):
    """_n() for a count that may be missing ('- applications')."""
    return "- %ss" % word if value is None else _n(int(value), word)


def _cell(value):
    """A Markdown table cell: pipes escaped, newlines flattened."""
    return str(value).replace("|", "\\|").replace("\r", " ").replace("\n", " ")


def _slug(heading):
    # type: (str) -> str
    """GitHub's heading anchor: lower-cased, punctuation dropped, each space a hyphen."""
    return re.sub(r"[^\w\- ]", "", heading.lower()).replace(" ", "-")


def _write(path, text):
    # type: (Path, str) -> Path
    path.parent.mkdir(parents=True, exist_ok=True)
    if not text.endswith("\n"):
        text += "\n"
    research.write_repo_text(path, text)
    return path


def _csv_text(keys, rows):
    buf = io.StringIO()
    writer = csv.writer(buf, lineterminator="\r\n")
    writer.writerow(keys)
    for row in rows:
        writer.writerow(["" if row[k] is None else row[k] for k in keys])
    return buf.getvalue()


def _json_text(doc):
    return json.dumps(doc, indent=1, ensure_ascii=False) + "\n"


# --- the dictionary -----------------------------------------------------------------------------

def _listed_in(shipped):
    # type: (list) -> Dict[Tuple[str, int], List[str]]
    """{(aura type, spell id): [category keys listing it under any class]} (the filter ignores
    the class key, so an id listed anywhere in a category is in it)."""
    out = {}  # type: Dict[Tuple[str, int], List[str]]
    for cat in shipped:
        for ids in cat["classes"].values():
            for sid in ids:
                keys = out.setdefault((cat.get("aura", "BUFF"), sid), [])
                if cat["key"] not in keys:
                    keys.append(cat["key"])
    return out


def dictionary_rows(agg, spec_map, names, shipped, suggestions):
    """One row per (class, spec, aura type, spell id) a player applied, whatever the count.

    `suggestions`: sid_propose.suggestions()'s {(class, spell_id): (category, rule, ...)}; it
    applies to BUFF rows only (the category rules are written for buffs). Percentages are of the
    row's applications: `group` is the applications inside bursts (applications - self - single;
    the scanner counts a burst once and absorbs its companions). Sorted by class, spec (unknown
    last), name, spell id, aura type.
    """
    listed = _listed_in(shipped)
    rows = []
    for (cls, spec), auras in agg.per_spec.items():
        for (aura_type, sid), st in auras.items():
            apps = st.applications
            if not apps:
                continue
            in_group = max(apps - st.self_ - st.single - st.other, 0)
            sugg = suggestions.get((cls, sid)) if aura_type == "BUFF" else None
            suggested, rule = (sugg[0], sugg[1]) if sugg and sugg[0] else ("", "")
            rows.append({
                "class": cls,
                "spec": sid_propose.spec_name(spec_map, spec),
                "spec_id": spec,
                "spell_id": sid,
                "name": _top_name(st.names) or names.get(sid, ""),
                "aura_type": aura_type,
                "applications": apps,
                "players": len(st.players),
                "self_pct": _pct(st.self_, apps),
                "single_pct": _pct(st.single, apps),
                "group_pct": _pct(in_group, apps),
                "other_pct": _pct(st.other, apps),
                "recast_median_s": (round(statistics.median(st.recast_samples), 2)
                                    if st.recast_samples else None),
                "first_seen": st.first_seen,
                "last_seen": st.last_seen,
                "category": ";".join(listed.get((aura_type, sid), [])),
                "suggested_category": suggested,
                "rule": rule,
            })
    rows.sort(key=lambda r: (r["class"], r["spec_id"] is None, r["spec"].lower(),
                             r["name"].lower(), r["spell_id"], r["aura_type"]))
    return rows


def _auras_md(date, rows):
    classes = []  # type: List[Tuple[str, List[str]]]
    for row in rows:
        if not classes or classes[-1][0] != row["class"]:
            classes.append((row["class"], []))
        if row["spec"] not in classes[-1][1]:
            classes[-1][1].append(row["spec"])
    out = ["# Aura dictionary — %s" % date, "",
           "Every aura id a player applied, %s: one entry per class, spec, aura type and spell id, "
           "whatever its count and whether or not it is in a category. Applications whose caster's "
           "spec was never established are under `unknown`; those whose class was not known either "
           "are counted in SOURCES.md only. The same rows are in `auras.csv` and `auras.json`."
           % FORMULA, "",
           "Each entry: **name** (spell id, aura type) — applications / distinct players — target "
           "shape (self · single · group, and other units: pets, guardians, NPCs) and median recast — shipped category, or the rule-based "
           "suggestion.", "",
           "%s across %s." % (_n(len(rows), "row"), _n(len(classes), "class")), "",
           "## Contents", ""]
    for cls, specs in classes:
        out.append("- [%s](#%s)" % (cls, _slug(cls)))
        for spec in specs:
            out.append("  - [%s](#%s)" % (spec, _slug("%s · %s" % (cls, spec))))
    current = (None, None)
    for row in rows:
        if row["class"] != current[0]:
            out += ["", "## %s" % row["class"]]
            current = (row["class"], None)
        if row["spec"] != current[1]:
            out += ["", "### %s · %s" % (row["class"], row["spec"]), ""]
            current = (row["class"], row["spec"])
        recast = row["recast_median_s"]
        shape = "self %g%% · single %g%% · group %g%%" % (
            row["self_pct"], row["single_pct"], row["group_pct"])
        if row["other_pct"]:
            shape += " · other units %g%%" % row["other_pct"]
        if recast is not None:
            shape += " · recast %gs" % recast
        if row["category"]:
            where = "in `%s`" % row["category"]
        elif row["suggested_category"]:
            where = "suggested `%s` (%s)" % (row["suggested_category"], row["rule"])
        else:
            where = "no category"
        out.append("- **%s** (%d, %s) — %s / %s — %s — %s" % (
            row["name"] or "?", row["spell_id"], row["aura_type"],
            _n(row["applications"], "app"), _n(row["players"], "player"), shape, where))
    return "\n".join(out)


def _non_player_rows(non_player):
    rows = [{"aura_type": t, "spell_id": sid, "name": _top_name(v["names"]),
             "applications": v["applications"]}
            for (t, sid), v in (non_player or {}).items()]
    rows.sort(key=lambda r: (-r["applications"], r["spell_id"], r["aura_type"]))
    return rows


# --- the review set -----------------------------------------------------------------------------

class _Labels:
    def __init__(self, shipped):
        self.labels = dict(sid_propose.CATEGORY_LABELS)
        self.labels.update({cat["key"]: cat["label"] for cat in shipped})

    def __call__(self, key):
        return self.labels.get(key, key)


def proposal_dict(p):
    # type: (sid_propose.Proposal) -> dict
    """A Proposal as proposals.json carries it: the key, the section, lists and string ids."""
    return {
        "section": "correction" if p.type in CORRECTION_TYPES else "addition",
        "key": sid_propose.proposal_key(p),
        "type": p.type, "category": p.category, "from_category": p.from_category,
        "class": p.klass, "name": p.name,
        "listed": list(p.listed), "proposed": list(p.proposed),
        "evidence": {str(sid): {spec: [int(v[0]), int(v[1])] for spec, v in by_spec.items()}
                     for sid, by_spec in p.evidence.items()},
        "rule": p.rule, "reason": p.reason, "confidence": p.confidence,
        "applications": p.applications,
    }


def _queue(proposals):
    """(corrections, additions), each most-applied first (stable, so ties keep the given order)."""
    corr = [p for p in proposals if p.type in CORRECTION_TYPES]
    adds = [p for p in proposals if p.type not in CORRECTION_TYPES]
    corr.sort(key=lambda p: -p.applications)
    adds.sort(key=lambda p: -p.applications)
    return corr, adds


def _id_evidence(sid, evidence, never="never applied"):
    by_spec = evidence.get(sid) or {}
    if not by_spec:
        return "%d (%s)" % (sid, never)
    return "%d (%s)" % (sid, "; ".join(
        "%s, %s / %s" % (spec, _n(v[0], "app"), _n(v[1], "player"))
        for spec, v in sorted(by_spec.items(), key=lambda kv: (-kv[1][0], kv[0]))))


def correction_line(p, label):
    # type: (sid_propose.Proposal, _Labels) -> str
    """The spec's one-line form: `Offensive cooldowns · SHAMAN · Ascendance — listed 114051 (never
    applied) → 114052 (Restoration, 212 apps / 9 players) — replace — high`."""
    where = label(p.category)
    if p.type == "move":
        where = "%s → %s" % (label(p.from_category), label(p.category))
    listed = ", ".join(_id_evidence(sid, p.evidence) for sid in p.listed)
    line = "%s · %s · %s — listed %s" % (where, p.klass, p.name, listed)
    if p.type != "move":
        line += " → " + ", ".join(_id_evidence(sid, p.evidence) for sid in p.proposed)
    return "%s — %s — %s" % (line, p.type, p.confidence)


def _corrections_md(date, corr, label, th):
    counts = Counter(p.type for p in corr)
    out = ["# Corrections — %s" % date, "",
           "Proposals against entries already in a `spells` category, in review order (most-applied "
           "first). **replace**: the listed id is never applied by the class while a same-name aura "
           "is. **add**: a same-name aura under another id is applied too. **move**: the entry's "
           "observed behaviour matches another category's rule (medium confidence at most). The "
           "evidence bar is %s from %s; anything already ruled in decisions.json is not repeated."
           % (_n(th["min_applications"], "application"), _n(th["min_players"], "player")), "",
           "%s: %d replace, %d add, %d move." % (_n(len(corr), "proposal"), counts["replace"],
                                                counts["add"], counts["move"]), ""]
    if not corr:
        out.append("No corrections.")
    for i, p in enumerate(corr, 1):
        out += ["%d. %s" % (i, correction_line(p, label)),
                "   - Reason: %s" % p.reason,
                "   - Rule: %s" % p.rule,
                "   - Key: `%s`" % sid_propose.proposal_key(p), ""]
    return "\n".join(out)


def _addition_counts_line(c):
    # type: (dict) -> str
    """SID-12's before/after: raw candidates, the low-confidence drop, the racial fold, ruled,
    proposed."""
    return ("%s above the bar in no category: %s dropped as low confidence (R9 Utility; they stay in "
            "the dictionary's suggested_category and rule columns); %s folded into %s; %s; %s."
            % (_n(c.get("raw", 0), "candidate"), c.get("low", 0),
               _n(c.get("folded", 0), "racial candidate"),
               _n(c.get("all", 0), "class-neutral (ALL) racial proposal"),
               "%d already ruled" % c.get("ruled", 0), "%d proposed" % c.get("proposed", 0)))


def _additions_md(date, adds, label, shipped, th, counts=None):
    order = [cat["key"] for cat in shipped]
    groups = {}  # type: Dict[str, list]
    for p in adds:
        groups.setdefault(p.category, []).append(p)
    keys = sorted(groups, key=lambda k: (order.index(k) if k in order else len(order), k))
    out = ["# Proposed additions — %s" % date, "",
           "Buffs that players applied, above the evidence bar (%s from %s) that are in no `spells` "
           "category, grouped by the recommended category. Each names the rule that chose it "
           "(R0-R9: the spec's table plus R0 Racials), a reason in plain words and a confidence."
           % (_n(th["min_applications"], "application"), _n(th["min_players"], "player")), "",
           "%s in %s." % (_n(len(adds), "addition"), _n(len(keys), "category")), ""]
    if counts:
        out += [_addition_counts_line(counts), ""]
    if not adds:
        out.append("No additions.")
    for key in keys:
        out += ["## %s (`%s`)" % (label(key), key), ""]
        for p in groups[key]:
            sid = p.proposed[0] if p.proposed else 0
            specs = "; ".join("%s %s / %s" % (spec, _n(v[0], "app"), _n(v[1], "player"))
                              for spec, v in sorted((p.evidence.get(sid) or {}).items(),
                                                    key=lambda kv: (-kv[1][0], kv[0])))
            out += ["- **%s** (%s) · %s — %s — %s — %s" % (
                        p.name, ", ".join(map(str, p.proposed)), p.klass, specs or "no evidence",
                        p.rule, p.confidence),
                    "  - Reason: %s" % p.reason,
                    "  - Key: `%s`" % sid_propose.proposal_key(p)]
        out.append("")
    return "\n".join(out)


def _class_evidence(rows):
    """{(class, aura type, spell id): {"apps", "players" (max over specs), "specs": [...]}}."""
    out = {}  # type: Dict[Tuple[str, str, int], dict]
    for r in rows:
        e = out.setdefault((r["class"], r["aura_type"], r["spell_id"]),
                           {"apps": 0, "players": 0, "specs": []})
        e["apps"] += r["applications"]
        e["players"] = max(e["players"], r["players"])
        e["specs"].append("%s %d/%d" % (r["spec"], r["applications"], r["players"]))
    return out


def _all_classes_evidence(rows, class_players):
    """{(aura type, spell id): the ALL-entry view}: every class's rows, specs class-prefixed, and
    the per-class exact player counts summed (a character has one class)."""
    out = {}  # type: Dict[Tuple[str, int], dict]
    per_class = {}  # type: Dict[Tuple[str, int, str], int]
    for r in rows:
        e = out.setdefault((r["aura_type"], r["spell_id"]), {"apps": 0, "specs": []})
        e["apps"] += r["applications"]
        e["specs"].append("%s %s %d/%d" % (r["class"], r["spec"], r["applications"], r["players"]))
        key = (r["aura_type"], r["spell_id"], r["class"])
        per_class[key] = max(per_class.get(key, 0), r["players"])
    for (atype, sid, cls), most in per_class.items():
        e = out[(atype, sid)]
        exact = class_players.get((cls, atype, sid))
        e["players"] = e.get("players", 0) + (exact if exact is not None else most)
        e["exact"] = e.get("exact", True) and exact is not None
    return out


def _current_md(date, rows, shipped, flags, proposals, names, class_players):
    evidence = _class_evidence(rows)
    all_evidence = _all_classes_evidence(rows, class_players)
    flagged = {(f.kind, f.category, f.klass, f.spell_id): f for f in flags}
    replaced = {}  # type: Dict[Tuple[str, str, int], list]
    for p in proposals:
        if p.type == "replace":
            for sid in p.listed:
                replaced[(p.category, p.klass, sid)] = p.proposed
    out = ["# Current categories — %s" % date, "",
           "Every `spells`-kind category of defaults/Categories.lua as shipped, each class line and "
           "each id with its combat-log status:", ""]
    out += ["- **%s** — %s" % (s, why) for s, why in STATUSES]
    for cat in shipped:
        atype = cat.get("aura", "BUFF")
        total = sum(len(ids) for ids in cat["classes"].values())
        out += ["", "## %s (`%s`)" % (cat["label"], cat["key"]), "",
                "%s · %s on %s." % (atype, _n(total, "id"), _n(len(cat["classes"]), "class line")),
                "", "| Class | Id | Name | Status | Evidence |", "|---|---|---|---|---|"]
        for klass, ids in cat["classes"].items():
            for sid in ids:
                key = (cat["key"], klass, sid)
                if klass == sid_propose.ALL_CLASSES:
                    ev = all_evidence.get((atype, sid))
                    players = ev["players"] if ev and ev["exact"] else None
                else:
                    ev = evidence.get((klass, atype, sid))
                    players = class_players.get((klass, atype, sid))
                if ev:
                    who = (_n(players, "player") if players is not None
                           else "at least %s" % _n(ev["players"], "player"))
                    detail = "%s / %s (%s)" % (_n(ev["apps"], "app"), who, ", ".join(ev["specs"]))
                    status = "confirmed"
                    stale = flagged.get(("stale",) + key)
                    if stale:
                        status, detail = "stale", "%s; %s" % (detail, stale.detail)
                    elif ("below_bar",) + key in flagged:
                        detail += "; below the evidence bar"
                elif key in replaced:
                    status = "wrong id"
                    detail = "never applied; replace with %s proposed" % ", ".join(
                        map(str, replaced[key]))
                else:
                    status = "unverified"
                    flag = flagged.get(("unverified",) + key)
                    detail = flag.detail if flag else "no %s applied it" % sid_propose._who(klass)
                out.append("| %s | %d | %s | %s | %s |" % (
                    klass, sid, _cell(names.get(sid) or "—"), status, _cell(detail)))
    return "\n".join(out)


def _flags_md(date, flags, label):
    out = ["# Flags — %s" % date, "",
           "Report only: nothing here is a proposal, and nothing here changes Categories.lua.", ""]
    for kind, title, why in FLAG_SECTIONS:
        these = [f for f in flags if f.kind == kind]
        out += ["## %s" % title, "", why, ""]
        if not these:
            out += ["None.", ""]
            continue
        out += ["| Category | Class | Id | Name | Detail |", "|---|---|---|---|---|"]
        for f in these:
            out.append("| %s | %s | %d | %s | %s |" % (
                _cell(label(f.category) if f.category else "—"), f.klass, f.spell_id,
                _cell(f.name or "—"), _cell(f.detail)))
        out.append("")
    return "\n".join(out)


def _sources_md(date, sources, counts):
    s = sources.get("summary") or {}
    th = sources.get("thresholds") or {}

    def val(key, default="-"):
        v = s.get(key, sources.get(key))
        return default if v is None or v == "" else v

    size = s.get("bytes")
    out = ["# Sources — %s" % date, "",
           "What this bundle was built from. Counts only: no player name, realm or GUID is read into "
           "any file here.", "",
           "| Item | Value |", "|---|---|",
           "| Logs scanned | %s |" % val("files"),
           "| Logs read / served from the per-log cache | %s / %s |" % (val("read"), val("cached")),
           "| Log bytes | %s |" % ("-" if size is None else "{:,} ({:.1f} MB)".format(size, size / 1e6)),
           "| Log date range | %s .. %s |" % (val("first_date"), val("last_date")),
           "| Lines | %s |" % val("lines"),
           "| Skipped lines | %s |" % val("skipped"),
           "| Unattributed applications | %s |" % val("unattributed"),
           "| DB2 build | %s |" % (sources.get("db2_build") or "-"),
           "| Evidence bar | %s from %s |" % (
               _count(th.get("min_applications"), "application"),
               _count(th.get("min_players"), "player")),
           "| Stale window | %s days |" % th.get("stale_days", "-"),
           "| Categories | %s |" % _cell(sources.get("categories", "-")),
           "| CastToAura | %s |" % _cell(sources.get("cast_to_aura", "-")),
           "| Decisions | %s (%s) |" % (_cell(sources.get("decisions", "-")),
                                       _n(int(sources.get("decisions_count", 0)), "ruling")),
           "| Evidence | %s |" % _cell(sources.get("evidence", "evidence.json")),
           "", "## Results", "", "| Item | Count |", "|---|---|"]
    out += ["| %s | %d |" % (k, v) for k, v in counts]
    tables = sources.get("db2_tables") or []
    if tables:
        out += ["", "## DB2 tables read", ""] + ["- %s" % t for t in tables]
    return "\n".join(out)


# --- the bundle ---------------------------------------------------------------------------------

def write_bundle(out_dir, date, rows, proposals, flags, shipped, sources, non_player=None,
                 names=None, class_players=None, addition_counts=None, decisions=None):
    # type: (Path, str, list, list, list, list, dict, Optional[dict], Optional[dict], Optional[dict], Optional[dict], Optional[dict]) -> List[Path]
    """Write the dictionary and the review set into out_dir; return the paths written.

    proposals: sid_propose Proposals (corrections -- replace/add/move -- and additions), already
    free of ruled keys. flags: sid_propose Flags. sources: {"summary" (evidence.json's), "db2_build",
    "db2_tables", "thresholds", "categories", "cast_to_aura", "decisions", "decisions_count",
    "evidence"}. non_player: the aggregate's non_player tally; names: DB2 spell names (for listed
    ids never seen); class_players: exact distinct casters per (class, aura type, spell id);
    addition_counts: sid_propose.additions()' summary (raw, low, folded, all, ruled, proposed),
    stated in PROPOSED_ADDITIONS.md when given; decisions: decisions.json, whose row rulings keep
    those rows off REVIEW.csv.
    evidence.json is scan's to write and is not touched here.
    """
    out_dir = Path(out_dir)
    names = names or {}
    class_players = class_players or {}
    label = _Labels(shipped)
    th = dict(sources.get("thresholds") or {})
    th.setdefault("min_applications", sid_propose.DEFAULT_MIN_APPLICATIONS)
    th.setdefault("min_players", sid_propose.DEFAULT_MIN_PLAYERS)
    corr, adds = _queue(proposals)
    counts = [("Dictionary rows", len(rows)), ("Corrections", len(corr)),
              ("Additions", len(adds)), ("Flags", len(flags))]
    counts += [("Flags: %s" % title, sum(1 for f in flags if f.kind == kind))
               for kind, title, _why in FLAG_SECTIONS]
    written = [
        _write(out_dir / "dictionary" / "auras.json",
               _json_text({"date": date, "formula": FORMULA, "rows": rows})),
        _write(out_dir / "dictionary" / "auras.csv", _csv_text(ROW_KEYS, rows)),
        _write(out_dir / "dictionary" / "AURAS.md", _auras_md(date, rows)),
        _write(out_dir / "dictionary" / "non-player.csv",
               _csv_text(NON_PLAYER_KEYS, _non_player_rows(non_player))),
        _write(out_dir / "CURRENT_CATEGORIES.md",
               _current_md(date, rows, shipped, flags, proposals, names, class_players)),
        _write(out_dir / "CORRECTIONS.md", _corrections_md(date, corr, label, th)),
        _write(out_dir / "PROPOSED_ADDITIONS.md", _additions_md(date, adds, label, shipped, th,
                                                                 addition_counts)),
        _write(out_dir / "FLAGS.md", _flags_md(date, flags, label)),
        _write(out_dir / "SOURCES.md", _sources_md(date, sources, counts)),
        _write(out_dir / "proposals.json", _json_text({
            "date": date, "thresholds": th,
            "proposals": [proposal_dict(p) for p in corr + adds]})),
    ]
    review = sid_review.review_rows(proposals, shipped, names, class_players, decisions)
    written += [
        _write(out_dir / "REVIEW.csv", sid_review.csv_text(review)),
        _write(out_dir / "REVIEW.md", sid_review.review_md(date, review, shipped)),
    ]
    return written
