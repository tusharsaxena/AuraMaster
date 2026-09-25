"""Stage 3 of the combat-log spell research: the owner's rulings and the only Categories.lua writer.

- decisions.json (tools/spell-research/decisions.json) holds one entry per proposal key:
      {"<proposal key>": {"ruling": "accept"|"reject"|"move", "category": "<key>" (optional),
                          "reason": "...", "date": "YYYY-MM-DD"}}
  record() is the only writer: sorted keys, 2-space JSON, CRLF, written to a temp file and renamed
  over the old one, so an interrupted write never leaves half a file. A key is never proposed
  again once it is here (sid_propose checks membership), whatever the ruling.
- apply() rewrites defaults/Categories.lua for the ruled proposals of one bundle, and nothing
  else: it edits only the `spells({ ... })` class lines a ruling touches, keeps every other byte
  (order, alignment, trailing comments, commented-out lines, CRLF), and puts a provenance comment
  above a line that gains ids:
      -- 114052: combat-log evidence, docs/spell-research/<date>-logs (SID)
  A class the category does not list yet gets a new line, placed in research.CLASS_EMIT_ORDER
  order with the block's own indent and `=` column. Applying the same rulings twice changes
  nothing the second time. A proposal handed to apply() without a ruling is refused.

Ruling semantics (the plan, SID-8):
    replace + accept  remove the listed ids from the class line, put the proposed ones in their place
    add + accept      append the proposed ids
    move + accept     remove from from_category, append to category
    addition + accept append to category (or the category chosen at decide time)
    move (ruling)     the same, into the category chosen at decide time ("accept, elsewhere")
    reject            nothing, and the key is suppressed forever

Review by sheet (SID-14, `logs.py ingest`): the owner rules the rows of the bundle's REVIEW.csv, so
decisions.json also holds row keys, `<proposal key>#<spell id>#<row type>` (sid_propose.row_key),
with the same entry shape (record_many() writes a whole sheet's rulings at once). plan_rows() /
apply_rows() apply them per id: a deletion removes the id, a correction-add or addition adds it to
the ruled category, a move does both; an approved deletion and approved adds of one proposal into
the same category are one in-place replace. sheet_decisions_md() is DECISIONS.md for that review,
derived from decisions.json alone so a second ingest writes the same bytes.

Python 3.8+ standard library only.
"""

import json
import os
import re
import tempfile
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import research
import sid_propose

RULINGS = ("accept", "reject", "move")

# One class line of a `spells({ ... })` block: indent, class, the `=` padding, the id list, and
# whatever follows the closing brace (the comma and any trailing comment), kept verbatim.
_CLASS_LINE = re.compile(
    r"^(?P<indent>[ \t]*)(?P<klass>[A-Z]+)(?P<pad>[ \t]*)=[ \t]*\{(?P<ids>[^}]*)\}(?P<tail>.*)$")
_CATEGORY_LINE = r'^[ \t]*key\s*=\s*"%s"\s*,\s*kind\s*=\s*"spells"'
_ANY_KEY_LINE = re.compile(r'^[ \t]*key\s*=\s*"')
_BLOCK_OPEN = re.compile(r"spells\s*=\s*spells\(\{\s*$")
_BLOCK_CLOSE = re.compile(r"^[ \t]*\}\)")
_PROVENANCE = re.compile(r"^[ \t]*-- [\d, ]+: combat-log evidence, .* \(SID\)[ \t]*$")


class UnruledProposal(ValueError):
    """apply() was handed a proposal with no entry in decisions.json."""


# --- decisions.json -----------------------------------------------------------------------------

def load_decisions(path):
    # type: (Path) -> dict
    """{proposal key: entry} from decisions.json; {} when the file does not exist yet.

    Accepts the flat form record() writes and a {"decisions": {...}} wrapper.
    """
    path = Path(path)
    if not path.exists():
        return {}
    doc = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(doc, dict) and isinstance(doc.get("decisions"), dict):
        return doc["decisions"]
    if not isinstance(doc, dict):
        raise ValueError("%s is not a JSON object of rulings" % path)
    return doc


def _write_atomic(path, text):
    # type: (Path, str) -> None
    """CRLF bytes to a temp file beside `path`, then renamed over it."""
    path.parent.mkdir(parents=True, exist_ok=True)
    data = text.replace("\r\n", "\n").replace("\n", "\r\n").encode("utf-8")
    fd, tmp = tempfile.mkstemp(prefix=".%s." % path.name, dir=str(path.parent))
    try:
        with os.fdopen(fd, "wb") as fh:
            fh.write(data)
        os.replace(tmp, str(path))
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def _entry(ruling, category=None, reason="", date=None, key="x"):
    # type: (str, Optional[str], str, Optional[str], str) -> dict
    if ruling not in RULINGS:
        raise ValueError("ruling must be one of %s, got %r" % ("/".join(RULINGS), ruling))
    if not research.DATE_RE.match(date or ""):
        raise ValueError("date must be YYYY-MM-DD, got %r" % (date,))
    if ruling == "move" and not category:
        raise ValueError("a move ruling needs the category it moves into")
    if not key:
        raise ValueError("an empty proposal key")
    entry = {"ruling": ruling, "reason": reason or "", "date": date}
    if category:
        entry["category"] = category
    return entry


def record_many(path, entries):
    # type: (Path, Dict[str, dict]) -> Dict[str, dict]
    """Record (or replace) many rulings in one write: {key: {"ruling", "category"?, "reason"?,
    "date"}}. Every entry is checked first (ValueError, nothing written); return them as written."""
    checked = {key: _entry(e.get("ruling", ""), e.get("category"), e.get("reason", ""),
                           e.get("date"), key)
               for key, e in entries.items()}
    path = Path(path)
    decisions = load_decisions(path)
    decisions.update(checked)
    _write_atomic(path, json.dumps(decisions, indent=2, sort_keys=True, ensure_ascii=False) + "\n")
    return checked


def record(path, key, ruling, category=None, reason="", date=None):
    # type: (Path, str, str, Optional[str], str, Optional[str]) -> dict
    """Record (or replace) the ruling for one proposal key; return the entry written.

    `date` is required (YYYY-MM-DD; never taken from the clock). A `move` ruling needs the
    category it moves into.
    """
    entry = _entry(ruling, category, reason, date, key)
    path = Path(path)
    decisions = load_decisions(path)
    decisions[key] = entry
    _write_atomic(path, json.dumps(decisions, indent=2, sort_keys=True, ensure_ascii=False) + "\n")
    return entry


# --- Categories.lua -----------------------------------------------------------------------------

def _format_ids(ids):
    return "{ %s }" % ", ".join(str(i) for i in ids) if ids else "{ }"


def _parse_ids(text):
    return [int(t) for t in re.findall(r"\d+", text)]


def _class_rank(klass):
    order = research.CLASS_EMIT_ORDER
    return order.index(klass) if klass in order else len(order)


class _Lua:
    """Categories.lua as a list of lines (without terminators), edited in place."""

    def __init__(self, text):
        self.newline = "\r\n" if "\r\n" in text else "\n"
        self.trailing = text.endswith(("\r\n", "\n"))
        self.lines = text.replace("\r\n", "\n").split("\n")
        if self.trailing:
            self.lines.pop()

    def text(self):
        out = self.newline.join(self.lines)
        return out + self.newline if self.trailing else out

    def block(self, category):
        # type: (str) -> Tuple[int, int]
        """(first line after `spells = spells({`, the `}),` line) of the category's block."""
        head = re.compile(_CATEGORY_LINE % re.escape(category))
        start = next((i for i, line in enumerate(self.lines) if head.match(line)), None)
        if start is None:
            raise ValueError("no `spells` category %r in Categories.lua" % category)
        for i in range(start + 1, len(self.lines)):
            if _ANY_KEY_LINE.match(self.lines[i]):
                break
            if _BLOCK_OPEN.search(self.lines[i]):
                for j in range(i + 1, len(self.lines)):
                    if _BLOCK_CLOSE.match(self.lines[j]):
                        return i + 1, j
                break
        raise ValueError("category %r has no `spells = spells({ ... })` block" % category)

    def class_lines(self, category):
        # type: (str) -> List[Tuple[int, re.Match]]
        lo, hi = self.block(category)
        return [(i, m) for i in range(lo, hi) for m in [_CLASS_LINE.match(self.lines[i])] if m]

    def find(self, category, klass):
        return next(((i, m) for i, m in self.class_lines(category) if m.group("klass") == klass),
                    (None, None))

    def set_ids(self, at, match, ids):
        self.lines[at] = "%s%s%s= %s%s" % (match.group("indent"), match.group("klass"),
                                           match.group("pad"), _format_ids(ids),
                                           match.group("tail"))

    def remove(self, category, klass, ids):
        # type: (str, str, list) -> List[int]
        """Remove ids from the class line; return the ids removed. A line left empty goes, with
        the provenance comments directly above it."""
        at, match = self.find(category, klass)
        if at is None:
            return []
        current = _parse_ids(match.group("ids"))
        gone = [i for i in current if i in set(ids)]
        if not gone:
            return []
        kept = [i for i in current if i not in set(ids)]
        if kept:
            self.set_ids(at, match, kept)
        else:
            first = at
            while first > 0 and _is_provenance(self.lines[first - 1]):
                first -= 1
            del self.lines[first:at + 1]
        return gone

    def replace(self, category, klass, listed, proposed, provenance):
        # type: (str, str, list, list, str) -> Tuple[List[int], List[int]]
        """One edit of one class line: the listed ids out, the proposed ones in the place of the
        first listed id (appended when none is there). Return (removed, added)."""
        at, match = self.find(category, klass)
        if at is None:
            return [], self.insert(category, klass, proposed, provenance)
        current = _parse_ids(match.group("ids"))
        gone = [i for i in current if i in set(listed)]
        pos = current.index(gone[0]) if gone else len(current)
        kept_before = [i for i in current[:pos] if i not in set(listed)]
        kept_after = [i for i in current[pos:] if i not in set(listed)]
        new = [i for i in dict.fromkeys(proposed) if i not in kept_before + kept_after]
        if not gone and not new:
            return [], []
        self.set_ids(at, match, kept_before + new + kept_after)
        if new:
            self.lines.insert(at, "%s%s" % (match.group("indent"), provenance % _joined(new)))
        return gone, new

    def insert(self, category, klass, ids, provenance):
        # type: (str, str, list, str) -> List[int]
        """Append ids to the class line, or add a new class line; a provenance comment goes
        directly above. Return the ids actually added."""
        at, match = self.find(category, klass)
        if at is not None:
            current = _parse_ids(match.group("ids"))
            new = [i for i in dict.fromkeys(ids) if i not in current]
            if not new:
                return []
            self.set_ids(at, match, current + new)
            self.lines.insert(at, "%s%s" % (match.group("indent"), provenance % _joined(new)))
            return new
        new = list(dict.fromkeys(ids))
        if not new:
            return []
        lines = self.class_lines(category)
        lo, hi = self.block(category)
        if lines:
            indent = lines[0][1].group("indent")
            width = len(lines[0][1].group("klass")) + len(lines[0][1].group("pad"))
            later = [i for i, m in lines if _class_rank(m.group("klass")) > _class_rank(klass)]
            where = later[0] if later else lines[-1][0] + 1
            # a later line's own provenance comments stay attached to it
            while later and where > lo and _is_provenance(self.lines[where - 1]):
                where -= 1
        else:
            closing = self.lines[hi]
            indent = closing[:len(closing) - len(closing.lstrip())] + "    "
            width = 0
            where = hi
        pad = " " * max(1, width - len(klass)) if width else " "
        self.lines[where:where] = [
            "%s%s" % (indent, provenance % _joined(new)),
            "%s%s%s= %s," % (indent, klass, pad, _format_ids(new)),
        ]
        return new


def _is_provenance(line):
    return bool(_PROVENANCE.match(line))


def _joined(ids):
    return ", ".join(str(i) for i in ids)


def _ruled_target(p, entry):
    return entry.get("category") or p["category"]


def apply(categories_lua, decisions, proposals, bundle_rel):
    # type: (Path, dict, List[dict], str) -> List[str]
    """Apply the ruled proposals (proposals.json entries) to Categories.lua; return a change log.

    Every proposal must have an entry in `decisions` (UnruledProposal otherwise, naming the key);
    `reject` entries change nothing. The file is written once, at the end, only when something
    changed; a refusal (an unruled key, an unknown category) leaves it untouched.
    """
    categories_lua = Path(categories_lua)
    lua = _Lua(categories_lua.read_bytes().decode("utf-8"))
    provenance = "-- %%s: combat-log evidence, %s (SID)" % bundle_rel
    changes = []  # type: List[str]
    for p in proposals:
        key = p["key"]
        entry = decisions.get(key)
        if entry is None:
            raise UnruledProposal("no ruling in decisions.json for proposal %s" % key)
        ruling = entry.get("ruling") if isinstance(entry, dict) else entry
        if ruling == "reject":
            continue
        if ruling not in ("accept", "move"):
            raise ValueError("unknown ruling %r for proposal %s" % (ruling, key))
        klass, ptype = p["class"], p["type"]
        target = _ruled_target(p, entry if isinstance(entry, dict) else {})
        if ruling == "move" and not (isinstance(entry, dict) and entry.get("category")):
            raise ValueError("move ruling without a category for proposal %s" % key)
        lua.block(target)  # refuse an unknown target before editing anything
        source = {"replace": p["category"], "move": p.get("from_category") or ""}.get(ptype)
        listed = [int(i) for i in p.get("listed") or []]
        proposed = [int(i) for i in p["proposed"]]
        if ptype == "replace" and source == target:
            removed, added = lua.replace(target, klass, listed, proposed, provenance)
        else:
            removed = lua.remove(source, klass, listed) if source and listed else []
            added = lua.insert(target, klass, proposed, provenance)
        if removed:
            changes.append("%s %s: -%s (%s)" % (source, klass, _joined(removed), key))
        if added:
            changes.append("%s %s: +%s (%s)" % (target, klass, _joined(added), key))
    if changes:
        research.write_repo_text(categories_lua, lua.text())
    return changes


# --- the review sheet's rows (SID-14) -----------------------------------------------------------

def row_key_of(row):
    # type: (dict) -> str
    """The decisions.json key of a REVIEW.csv row (sid_propose.row_key)."""
    return sid_propose.row_key(row["proposal_key"], row["spell_id"], row["type"])


def sheet_entries(ruled, date, reason="review sheet"):
    # type: (list, str, str) -> Dict[str, dict]
    """decisions.json entries for sid_review.ingest()'s ruled rows, keyed by row key (proposal key #
    spell id # row type). Approve is `accept` into the row's proposed category, or `move` when the
    owner edited it to another one; Reject is `reject`. The row id rides along in the reason."""
    out = {}  # type: Dict[str, dict]
    for row, decision, target in ruled:
        entry = {"ruling": "reject", "date": date, "reason": "%s %s" % (reason, row["row_id"])}
        if decision == "approve":
            entry["ruling"] = "accept" if target == row["proposed_category"] else "move"
            if target:
                entry["category"] = target
        out[row_key_of(row)] = entry
    return out


def plan_rows(categories_lua, decisions, rows, bundle_rel):
    # type: (Path, dict, List[dict], str) -> Tuple[str, List[str]]
    """(Categories.lua's new text, the change log) for the review-sheet rows ruled in `decisions`
    (row keys); nothing is written. Rows without a ruling, and rejected rows, change nothing.

    Per row: `deletion` removes the id from its class line in current_category; `correction-add`
    and `addition` add it to the ruled category; `move` removes it from current_category and adds
    it to the ruled category. Within one proposal an approved deletion and approved adds into the
    same category are one in-place replace (the new ids take the deleted id's place). Every target
    category is checked before anything is edited; ValueError names an unknown one.
    """
    categories_lua = Path(categories_lua)
    text = categories_lua.read_bytes().decode("utf-8")
    lua = _Lua(text)
    provenance = "-- %%s: combat-log evidence, %s (SID)" % bundle_rel
    groups = []  # type: List[Tuple[str, str, Dict[str, list], Dict[str, list], list]]
    by_key = {}  # type: Dict[str, int]
    for row in rows:
        entry = decisions.get(row_key_of(row))
        if not isinstance(entry, dict) or entry.get("ruling") not in ("accept", "move"):
            continue
        rtype, sid = row["type"], int(row["spell_id"])
        target = entry.get("category") or row["proposed_category"]
        pkey = row["proposal_key"]
        if pkey not in by_key:
            by_key[pkey] = len(groups)
            groups.append((pkey, row["class"], {}, {}, []))
        _k, _c, dels, adds, moves = groups[by_key[pkey]]
        if rtype == "deletion":
            lua.block(row["current_category"])
            dels.setdefault(row["current_category"], []).append(sid)
        elif rtype == "move":
            lua.block(row["current_category"])
            lua.block(target)
            moves.append((row["current_category"], target, sid))
        else:
            lua.block(target)
            adds.setdefault(target, []).append(sid)
    changes = []  # type: List[str]

    def log(cat, klass, sign, ids, key):
        if ids:
            changes.append("%s %s: %s%s (%s)" % (cat, klass, sign, _joined(ids), key))

    for pkey, klass, dels, adds, moves in groups:
        for cat, ids in dels.items():
            if cat in adds:
                removed, added = lua.replace(cat, klass, ids, adds.pop(cat), provenance)
                log(cat, klass, "-", removed, pkey)
                log(cat, klass, "+", added, pkey)
            else:
                log(cat, klass, "-", lua.remove(cat, klass, ids), pkey)
        for cat, ids in adds.items():
            log(cat, klass, "+", lua.insert(cat, klass, ids, provenance), pkey)
        for source, target, sid in moves:
            log(source, klass, "-", lua.remove(source, klass, [sid]), pkey)
            log(target, klass, "+", lua.insert(target, klass, [sid], provenance), pkey)
    return (lua.text() if changes else text), changes


def apply_rows(categories_lua, decisions, rows, bundle_rel):
    # type: (Path, dict, List[dict], str) -> List[str]
    """plan_rows(), then write Categories.lua when anything changed; return the change log."""
    text, changes = plan_rows(categories_lua, decisions, rows, bundle_rel)
    if changes:
        research.write_repo_text(Path(categories_lua), text)
    return changes


def sheet_decisions_md(date, decisions, rows):
    # type: (str, dict, List[dict]) -> str
    """DECISIONS.md for a review by sheet: every row of the bundle's REVIEW.csv with its ruling
    (or pending). Derived from decisions.json alone, so a second ingest writes the same bytes."""
    ruled = [(row, decisions.get(row_key_of(row))) for row in rows]
    count = {"accept": 0, "move": 0, "reject": 0}
    for _row, e in ruled:
        if isinstance(e, dict) and e.get("ruling") in count:
            count[e["ruling"]] += 1
    pending = sum(1 for _row, e in ruled if not isinstance(e, dict))
    lines = ["# Decisions -- %s" % date, "",
             "The owner's rulings on this bundle's review sheet (`REVIEW.csv`), copied from "
             "`tools/spell-research/decisions.json` (the durable record; one entry per sheet row, "
             "keyed `<proposal key>#<spell id>#<row type>`). `logs.py ingest` applied the accept "
             "and move rulings to `defaults/Categories.lua`; a rejected row is never asked again.",
             "", "Accepted %d, accepted into another category %d, rejected %d, pending %d."
             % (count["accept"], count["move"], count["reject"], pending), "",
             "| Row | Ruling | Type | Class | Spell id | Spell | Category | Date | Proposal |",
             "|---|---|---|---|---|---|---|---|---|"]
    for row, e in ruled:
        if not isinstance(e, dict):
            continue
        category = e.get("category") or row["proposed_category"] or row["current_category"]
        lines.append("| %s | %s | %s | %s | %s | %s | %s | %s | `%s` |" % tuple(_cell(v) for v in (
            row["row_id"], e.get("ruling", ""), row["type"], row["class"], row["spell_id"],
            row["spell_name"], category, e.get("date", ""), row["proposal_key"])))
    if not any(isinstance(e, dict) for _row, e in ruled):
        lines.append("| - | - | - | - | - | - | - | - | - |")
    return "\n".join(lines) + "\n"


def write_sheet_decisions_md(bundle, date, decisions, rows):
    # type: (Path, str, dict, List[dict]) -> Path
    path = Path(bundle) / "DECISIONS.md"
    research.write_repo_text(path, sheet_decisions_md(date, decisions, rows))
    return path


# --- DECISIONS.md -------------------------------------------------------------------------------

def _cell(value):
    return str(value).replace("|", "\\|").replace("\r", " ").replace("\n", " ")


def decisions_md(date, decisions, proposals, changes):
    # type: (str, dict, List[dict], List[str]) -> str
    """The rulings of this review: every decisions.json entry for a proposal in this bundle or
    dated this run, and what apply changed."""
    in_bundle = {p["key"]: p for p in proposals}
    keys = sorted(k for k, e in decisions.items()
                  if k in in_bundle or (isinstance(e, dict) and e.get("date") == date))
    lines = ["# Decisions -- %s" % date, "",
             "The owner's rulings for this review, copied from "
             "`tools/spell-research/decisions.json` (the durable record; one entry per proposal "
             "key). `logs.py apply` applied the accept and move rulings to "
             "`defaults/Categories.lua`.", "",
             "| Ruling | Category | Class | Spell | Proposed | Reason | Date | Key |",
             "|---|---|---|---|---|---|---|---|"]
    for k in keys:
        e = decisions[k] if isinstance(decisions[k], dict) else {"ruling": decisions[k]}
        p = in_bundle.get(k, {})
        parts = k.split("|")
        klass = p.get("class") or (parts[2] if len(parts) > 2 else "")
        name = p.get("name") or (parts[3] if len(parts) > 3 else "")
        proposed = _joined(p.get("proposed") or []) or (parts[4] if len(parts) > 4 else "")
        lines.append("| %s | %s | %s | %s | %s | %s | %s | `%s` |" % tuple(_cell(v) for v in (
            e.get("ruling", ""), e.get("category") or p.get("category", ""), klass, name,
            proposed, e.get("reason", ""), e.get("date", ""), k)))
    if not keys:
        lines.append("| - | - | - | - | - | - | - | - |")
    lines += ["", "## Applied changes", ""]
    lines += ["- %s" % c for c in changes] if changes else ["None (nothing new to apply)."]
    return "\n".join(lines) + "\n"


def write_decisions_md(bundle, date, decisions, proposals, changes):
    # type: (Path, str, dict, List[dict], List[str]) -> Path
    path = Path(bundle) / "DECISIONS.md"
    research.write_repo_text(path, decisions_md(date, decisions, proposals, changes))
    return path
