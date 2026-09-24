"""The review sheet: every proposal of a bundle as rows of REVIEW.csv, plus REVIEW.md to explain it.

The owner reviews by spreadsheet (the ruling after the SID-10 dry run): `logs.py propose` writes
REVIEW.csv into the bundle, one row per spell id per change, the owner writes Approve or Reject in
its last column and hands the sheet back for `logs.py ingest` to apply in one shot.

Row types:
    correction-add  add this id to an existing entry (an `add` proposal's new ids, and the add half
                    of a `replace`)
    deletion        remove this listed id (the delete half of a `replace`), so the add and the
                    delete of one replace can be ruled independently
    move            move this listed id to another category
    addition        a new aura into a category

Order: corrections first, most-applied first (a proposal's rows stay together: its deletions, then
its adds), then additions grouped by recommended category in the file's order, most-applied first
within each. The sheet is UTF-8 with a BOM (so Excel opens it as UTF-8) and CRLF. Only classes,
specs, spell names and counts are written -- never a player, realm or GUID. Python 3.8+ standard
library only.
"""

import csv
import io
from typing import Dict, List, Optional

import sid_propose

COLUMNS = ("row_id", "spell_id", "spell_name", "type", "class", "current_category",
           "proposed_category", "specs", "applications", "players", "context", "confidence",
           "proposal_key", "decision")

ROW_TYPES = ("correction-add", "deletion", "move", "addition")

CORRECTION_TYPES = ("replace", "add", "move")

# What the owner may write in `decision` (case-insensitive, surrounding blanks ignored).
DECISIONS = {"approve": "approve", "a": "approve", "y": "approve",
             "reject": "reject", "r": "reject", "n": "reject"}

BOM = "﻿"


def decision_of(value):
    # type: (Optional[str]) -> Optional[str]
    """'approve' or 'reject' for a filled `decision` cell; None when blank (still pending).
    Raises ValueError on anything else."""
    text = (value or "").strip().lower()
    if not text:
        return None
    if text not in DECISIONS:
        raise ValueError("unrecognised decision %r (use Approve or Reject; A/R and Y/N are "
                         "accepted)" % value)
    return DECISIONS[text]


def _class_of(spec):
    # type: (str) -> str
    """The class of an ALL entry's spec name ("SHAMAN Restoration" -> "SHAMAN")."""
    return spec.split(" ", 1)[0]


def _players(klass, aura_type, sid, by_spec, class_players):
    # type: (str, str, int, dict, dict) -> int
    """Distinct players who applied the id: exact from evidence.json's class-wide counts (for ALL,
    summed over the classes folded into the proposal -- the classes its specs name, whose caster
    sets are disjoint -- never every class that applied the id); without them, the most in one
    spec (per class, summed for ALL) -- a lower bound, never a double count."""
    if klass == sid_propose.ALL_CLASSES:
        most = {}  # type: Dict[str, int]
        for spec, v in by_spec.items():
            cls = _class_of(spec)
            most[cls] = max(most.get(cls, 0), int(v[1]))
        return sum(int(class_players.get((cls, aura_type, sid), n)) for cls, n in most.items())
    exact_one = class_players.get((klass, aura_type, sid))
    if exact_one is not None:
        return int(exact_one)
    return max((int(v[1]) for v in by_spec.values()), default=0)


def _specs(by_spec):
    # type: (dict) -> str
    """'Restoration 1126/53; Elemental 693/73' (applications/players), most-applied first."""
    return "; ".join("%s %d/%d" % (spec, int(v[0]), int(v[1]))
                     for spec, v in sorted(by_spec.items(), key=lambda kv: (-kv[1][0], kv[0])))


def _context(p):
    # type: (sid_propose.Proposal) -> str
    reason = (p.reason or "").strip().rstrip(".")
    return "%s (rule %s)." % (reason, p.rule) if reason else "Rule %s." % p.rule


def _queue(proposals, shipped):
    """Corrections most-applied first, then additions grouped by category (the file's order),
    most-applied first within a group. Stable, so ties keep the given order."""
    corr = sorted((p for p in proposals if p.type in CORRECTION_TYPES), key=lambda p: -p.applications)
    order = [cat["key"] for cat in shipped]
    adds = sorted((p for p in proposals if p.type not in CORRECTION_TYPES),
                  key=lambda p: (order.index(p.category) if p.category in order else len(order),
                                 p.category, -p.applications))
    return corr + adds


def _changes(p):
    """[(row type, spell id, current category, proposed category)] for one proposal."""
    if p.type == "replace":
        return ([("deletion", sid, p.category, "") for sid in p.listed]
                + [("correction-add", sid, p.category, p.category) for sid in p.proposed])
    if p.type == "add":
        return [("correction-add", sid, p.category, p.category)
                for sid in p.proposed if sid not in p.listed]
    if p.type == "move":
        return [("move", sid, p.from_category, p.category) for sid in p.proposed]
    return [("addition", sid, "", p.category) for sid in p.proposed]


def review_rows(proposals, shipped, names=None, class_players=None):
    # type: (list, list, Optional[dict], Optional[dict]) -> List[dict]
    """The sheet's rows (dicts keyed by COLUMNS) for sid_propose Proposals, in review order."""
    names = names or {}
    class_players = class_players or {}
    aura_of = {cat["key"]: cat.get("aura", "BUFF") for cat in shipped}
    rows = []  # type: List[dict]
    for p in _queue(proposals, shipped):
        aura_type = aura_of.get(p.from_category if p.type == "move" else p.category, "BUFF")
        key = sid_propose.proposal_key(p)
        for rtype, sid, current, proposed in _changes(p):
            by_spec = p.evidence.get(sid) or {}
            rows.append({
                "row_id": "R%04d" % (len(rows) + 1),
                "spell_id": sid,
                "spell_name": names.get(sid) or p.name,
                "type": rtype,
                "class": p.klass,
                "current_category": current,
                "proposed_category": proposed,
                "specs": _specs(by_spec),
                "applications": sum(int(v[0]) for v in by_spec.values()),
                "players": _players(p.klass, aura_type, sid, by_spec, class_players),
                "context": _context(p),
                "confidence": p.confidence,
                "proposal_key": key,
                "decision": "",
            })
    return rows


def csv_text(rows):
    # type: (List[dict]) -> str
    """REVIEW.csv's text: a BOM, the header, the rows, CRLF throughout."""
    buf = io.StringIO()
    writer = csv.writer(buf, lineterminator="\r\n")
    writer.writerow(COLUMNS)
    for row in rows:
        writer.writerow(["" if row[c] is None else row[c] for c in COLUMNS])
    return BOM + buf.getvalue()


COLUMN_HELP = (
    ("row_id", "Stable id of the row in this sheet (`R0001`, ...). Do not edit."),
    ("spell_id", "The aura id the row is about. Do not edit."),
    ("spell_name", "Its DB2 name."),
    ("type", "`correction-add` (add this id to an existing entry), `deletion` (remove this listed "
             "id: the delete half of a replace), `move` (move this listed id to another category) "
             "or `addition` (a new aura into a category). Do not edit."),
    ("class", "The class token, or `ALL` for a class-neutral entry."),
    ("current_category", "The category it is in today (blank for an addition)."),
    ("proposed_category", "Where it would go (blank for a deletion). **Editable**: overwrite it "
                          "with another category key or label before approving."),
    ("specs", "Per spec: applications/distinct players, most-applied first."),
    ("applications", "Total applications of this id."),
    ("players", "Distinct players who applied it."),
    ("context", "Why, in one plain sentence, with the rule that chose it."),
    ("confidence", "high, medium or low."),
    ("proposal_key", "The proposal the row belongs to; several rows may share one (a replace is a "
                     "deletion plus one add per new id). Do not edit."),
    ("decision", "**Yours, the last column.** `Approve` or `Reject`; blank leaves the row pending."),
)


def review_md(date, rows, shipped, csv_name="REVIEW.csv"):
    # type: (str, List[dict], list, str) -> str
    """REVIEW.md: what the sheet is, its columns, the decision values and how to hand it back."""
    counts = {t: sum(1 for r in rows if r["type"] == t) for t in ROW_TYPES}
    out = ["# Review sheet — %s" % date, "",
           "`%s` holds every proposal of this bundle as rows, one per spell id per change: "
           "corrections first (most-applied first), then additions grouped by recommended "
           "category. It is UTF-8 with a byte-order mark, so Excel opens it cleanly." % csv_name, "",
           "%s: %d correction-add, %d deletion, %d move, %d addition." % (
               sid_propose.plural(len(rows), "row"), counts["correction-add"], counts["deletion"],
               counts["move"], counts["addition"]), "",
           "## How to review", "",
           "1. Open `%s` in a spreadsheet." % csv_name,
           "2. In the last column, `decision`, write `Approve` or `Reject` on each row you rule "
           "(case does not matter; `A`/`R` and `Y`/`N` are accepted too). A blank row stays "
           "pending and is asked again next time; a rejected row is never asked again.",
           "3. To put an approved row in a different category, overwrite its `proposed_category` "
           "with a category key or label from the list below.",
           "4. A replace is two or more rows sharing one `proposal_key`: the `deletion` of the "
           "listed id and a `correction-add` per new id. Rule them independently: approving the "
           "add and rejecting the deletion keeps both ids.",
           "5. Save the sheet as CSV and hand it back: `/aura-spells-review apply <path>`, which runs "
           "`logs.py ingest` on it, then the addon gates.", "",
           "Do not edit `row_id`, `spell_id`, `type` or `proposal_key`: the sheet is checked "
           "against this bundle's copy by them, and a mismatched row fails the whole ingest.", "",
           "## Columns", "", "| Column | Meaning |", "|---|---|"]
    out += ["| `%s` | %s |" % (col, why) for col, why in COLUMN_HELP]
    out += ["", "## Decision values", "", "| Write | Means |", "|---|---|",
            "| `Approve`, `A`, `Y` | apply the row |",
            "| `Reject`, `R`, `N` | never apply it, and never ask again |",
            "| (blank) | pending |", "",
            "## Categories", "", "| Key | Label |", "|---|---|"]
    out += ["| `%s` | %s |" % (cat["key"], cat["label"]) for cat in shipped]
    return "\n".join(out)
