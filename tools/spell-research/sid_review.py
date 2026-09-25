"""The review sheet: every proposal of a bundle as rows of REVIEW.csv, plus REVIEW.md to explain it.

The owner reviews by spreadsheet (the ruling after the SID-10 dry run): `logs.py propose` writes
REVIEW.csv into the bundle, one row per spell id per change, the owner writes Approve or Reject in
its last column and hands the sheet back for `logs.py ingest` to apply in one shot.

Ingest (SID-14): read_sheet() reads a sheet (the bundle's own or the owner's filled copy, with or
without the BOM), and ingest() checks the filled sheet against the bundle's by row_id + spell_id +
type, reads each decision and resolves an edited proposed_category; every problem is collected
and raised together as a SheetError, so nothing is written from a sheet that is wrong anywhere.

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
from pathlib import Path
from typing import Dict, List, NamedTuple, Optional, Tuple

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


def review_rows(proposals, shipped, names=None, class_players=None, decisions=None):
    # type: (list, list, Optional[dict], Optional[dict], Optional[dict]) -> List[dict]
    """The sheet's rows (dicts keyed by COLUMNS) for sid_propose Proposals, in review order.

    A row already ruled in `decisions` (its sid_propose.row_key() is there, from an earlier
    `logs.py ingest`) is left out, so a rejected row is never asked again; row ids number the rows
    that remain.
    """
    names = names or {}
    class_players = class_players or {}
    decisions = decisions or {}
    aura_of = {cat["key"]: cat.get("aura", "BUFF") for cat in shipped}
    rows = []  # type: List[dict]
    for p in _queue(proposals, shipped):
        aura_type = aura_of.get(p.from_category if p.type == "move" else p.category, "BUFF")
        key = sid_propose.proposal_key(p)
        for rtype, sid, current, proposed in sid_propose.review_changes(p):
            if sid_propose.row_key(key, sid, rtype) in decisions:
                continue
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


# --- ingest: the filled sheet ------------------------------------------------------------------

class SheetError(ValueError):
    """The filled sheet does not fit the bundle's; `problems` lists every row at fault."""

    def __init__(self, problems):
        # type: (List[str]) -> None
        self.problems = list(problems)
        ValueError.__init__(self, "the review sheet has %s:\n  %s" % (
            sid_propose.plural(len(self.problems), "problem"), "\n  ".join(self.problems)))


class Ingest(NamedTuple):
    ruled: List[Tuple[dict, str, str]]   # (the bundle's row, "approve"|"reject", target category)
    pending: List[str]                   # row ids with no decision (blank, or left out)


def read_sheet(path):
    # type: (Path) -> List[dict]
    """The rows of a review sheet as {column: text}, in file order; a leading BOM and either line
    ending are accepted. ValueError when it is not UTF-8 or lacks one of COLUMNS."""
    path = Path(path)
    try:
        text = path.read_bytes().decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise ValueError("%s is not UTF-8 (%s); save it as CSV UTF-8" % (path, exc))
    reader = csv.DictReader(io.StringIO(text, newline=""))
    header = [h.strip() for h in (reader.fieldnames or [])]
    missing = [c for c in COLUMNS if c not in header]
    if missing:
        raise ValueError("%s lacks the column%s %s" % (path, "" if len(missing) == 1 else "s",
                                                        ", ".join(missing)))
    reader.fieldnames = header
    rows = []
    for raw in reader:
        row = {c: (raw.get(c) or "").strip() for c in COLUMNS}
        if any(row.values()):
            rows.append(row)
    return rows


def resolve_category(text, shipped):
    # type: (str, list) -> Optional[str]
    """The `spells` category key a sheet cell names, by key or label (case and surrounding blanks
    ignored); None when it names none."""
    want = (text or "").strip().lower()
    for cat in shipped:
        if want in (cat["key"].lower(), (cat.get("label") or "").strip().lower()):
            return cat["key"]
    return None


def _same_id(a, b):
    try:
        return int(str(a).strip()) == int(str(b).strip())
    except ValueError:
        return False


def ingest(bundle_rows, filled_rows, shipped):
    # type: (List[dict], List[dict], list) -> Ingest
    """Check the filled sheet against the bundle's and read its rulings.

    A row whose row_id the bundle lacks, whose spell_id or type differs from the bundle's row, that
    appears twice, whose decision is not a recognized value, or whose edited proposed_category is
    not a `spells` category key or label of `shipped` (or is filled in on a deletion) is a problem;
    all problems are raised together as a SheetError. A blank decision, or a row left out of the
    filled sheet, is pending. The target of an approved row is its proposed_category (as edited);
    a deletion's is "".
    """
    by_id = {r["row_id"]: r for r in bundle_rows}
    problems = []  # type: List[str]
    seen = set()  # type: set
    ruled = []  # type: List[Tuple[dict, str, str]]
    for filled in filled_rows:
        rid = filled.get("row_id", "")
        mine = by_id.get(rid)
        if mine is None:
            problems.append("%s: not a row of the bundle's REVIEW.csv" % (rid or "(no row_id)"))
            continue
        if rid in seen:
            problems.append("%s: appears more than once" % rid)
            continue
        seen.add(rid)
        if not _same_id(filled.get("spell_id"), mine["spell_id"]) or \
                filled.get("type", "").strip() != mine["type"]:
            problems.append("%s: spell_id/type %s/%s does not match the bundle's %s/%s" % (
                rid, filled.get("spell_id"), filled.get("type"), mine["spell_id"], mine["type"]))
            continue
        try:
            decision = decision_of(filled.get("decision"))
        except ValueError as exc:
            problems.append("%s: %s" % (rid, exc))
            continue
        edited = (filled.get("proposed_category") or "").strip()
        target = mine["proposed_category"]
        if edited and edited != target:
            if mine["type"] == "deletion":
                problems.append("%s: a deletion takes no proposed_category (got %r)"
                                % (rid, edited))
                continue
            target = resolve_category(edited, shipped)
            if target is None:
                problems.append("%s: proposed_category %r is not a `spells` category key or "
                                "label (known: %s)" % (rid, edited,
                                                       ", ".join(c["key"] for c in shipped)))
                continue
        if decision is not None:
            ruled.append((mine, decision, target))
    if problems:
        raise SheetError(problems)
    decided = {row["row_id"] for row, _d, _t in ruled}
    return Ingest(ruled=ruled, pending=[r["row_id"] for r in bundle_rows
                                        if r["row_id"] not in decided])
