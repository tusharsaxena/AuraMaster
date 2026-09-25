"""Stage 3 of the combat-log spell research: the owner's rulings and the only Categories.lua writer.

- decisions.json (tools/spell-research/decisions.json) holds one entry per proposal key:
      {"<proposal key>": {"ruling": "accept"|"reject"|"move", "category": "<key>" (optional),
                          "reason": "...", "date": "YYYY-MM-DD"}}
  record() is the only writer: sorted keys, 2-space JSON, CRLF, written to a temp file and renamed
  over the old one, so an interrupted write never leaves half a file. A key is never proposed
  again once it is here (sid_propose checks membership), whatever the ruling.
- apply() rewrites defaults/Categories.lua for the ruled proposals of one bundle, and nothing
  else: it edits only the class tables of the `spells({ ... })` blocks a ruling touches and keeps
  every other byte (order, alignment, comments, commented-out lines, CRLF). The file's layout is
  one multi-line table per class with ONE ID PER LINE and the spell's name in a comment on that
  line (research.py's shared reader documents it). An id the tool adds gets its own line, appended
  inside the class table and aligned to the comment column its neighbors use:
      114052,  -- Ascendance; added from the 2026-09-24 combat logs (SID)
  and, for a replace, `; replaces <old ids>` on the end. Removing an id deletes its line; a class
  table left empty is deleted (the table only: a comment line above it stays, since the tool
  cannot tell what else it describes). A class the category does not list yet gets a new table,
  placed in research.CLASS_EMIT_ORDER order with the block's own indent, above any comment lines
  sitting directly over the class it precedes. A legacy one-line class entry (`CLASS = { 1, 2 },
  -- Name1, Name2`) is converted to the table layout when, and only when, a ruling edits it: its
  ids keep their positional names when the comment lines up (an aside in parentheses rides along
  after a `;`), else take the name the proposal or sheet row gives them, else have none, and a
  comment that did not line up is kept as a comment line above the new table. Applying the same
  rulings twice changes nothing the second time. A proposal handed to apply() without a ruling is
  refused.

Ruling semantics (the plan, SID-8):
    replace + accept  remove the listed ids from the class, put the proposed ones in their place
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

# A legacy one-line class entry (its code part): indent, class, the id list, whatever follows.
_CLASS_LINE = re.compile(
    r"^(?P<indent>[ \t]*)(?P<klass>[A-Z]+)[ \t]*=[ \t]*\{(?P<ids>[^}]*)\}(?P<tail>.*)$")
# The opening line of a class table (its code part): `CLASS = {`, nothing after the brace.
_CLASS_OPEN = re.compile(r"^(?P<indent>[ \t]*)(?P<klass>[A-Z]+)[ \t]*=[ \t]*\{[ \t]*$")
# The line that closes a class table (its code part): `},`.
_TABLE_CLOSE = re.compile(r"^[ \t]*\}[ \t]*,?[ \t]*$")
_CATEGORY_LINE = r'^[ \t]*key\s*=\s*"%s"\s*,\s*kind\s*=\s*"spells"'
_ANY_KEY_LINE = re.compile(r'^[ \t]*key\s*=\s*"')
_BLOCK_OPEN = re.compile(r"spells\s*=\s*spells\(\{\s*$")
_BLOCK_CLOSE = re.compile(r"^[ \t]*\}\)")
# The widest id a line is laid out for when no neighbor shows a comment column: seven digits
# and the comma, then the space before `--`.
_DEFAULT_COMMENT_OFFSET = 9


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

def _class_rank(klass):
    order = research.CLASS_EMIT_ORDER
    return order.index(klass) if klass in order else len(order)


def _indent_of(line):
    return line[:len(line) - len(line.lstrip())]


def _code(line):
    return research.split_comment(line)[0]


def _joined(ids):
    return ", ".join(str(i) for i in ids)


def bundle_date(bundle, fallback=""):
    # type: (object, str) -> str
    """The YYYY-MM-DD a bundle is named for (`.../2026-09-24-logs` -> 2026-09-24), else `fallback`,
    else the bundle's own name. It is the date a new id line's comment cites."""
    name = Path(str(bundle)).name
    found = re.search(r"\d{4}-\d{2}-\d{2}", name)
    return found.group(0) if found else (fallback or name)


class _Entry:
    """One class of a `spells({ ... })` block: lines [start, end] of the file (equal for a legacy
    one-line entry) and its id lines as [(line index, id)]; `legacy` is the one-line layout."""

    def __init__(self, klass, start, end, ids, legacy):
        self.klass, self.start, self.end, self.ids, self.legacy = klass, start, end, ids, legacy

    def current(self):
        return [sid for _at, sid in self.ids]


class _Lua:
    """Categories.lua as a list of lines (without terminators), edited in place.

    `names` is {id: spell name} from the proposals or sheet rows being applied, used for the comment
    of an id the tool adds and, as a fallback, of an id on a legacy line it converts. `date` is the
    bundle date a new line's comment cites.
    """

    def __init__(self, text, names=None, date=""):
        self.newline = "\r\n" if "\r\n" in text else "\n"
        self.trailing = text.endswith(("\r\n", "\n"))
        self.lines = text.replace("\r\n", "\n").split("\n")
        if self.trailing:
            self.lines.pop()
        self.names = dict(names or {})
        self.date = date

    def text(self):
        out = self.newline.join(self.lines)
        return out + self.newline if self.trailing else out

    # --- reading --------------------------------------------------------------------------------

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

    def entries(self, category):
        # type: (str) -> List[_Entry]
        """The block's class entries in file order. Ids come from code only, never a comment."""
        lo, hi = self.block(category)
        out = []  # type: List[_Entry]
        i = lo
        while i < hi:
            code = _code(self.lines[i])
            legacy = _CLASS_LINE.match(code)
            opened = None if legacy else _CLASS_OPEN.match(code)
            if legacy:
                ids = [(i, int(t)) for t in re.findall(r"\d+", legacy.group("ids"))]
                out.append(_Entry(legacy.group("klass"), i, i, ids, True))
            elif opened:
                j, ids = i + 1, []
                while j < hi and not _TABLE_CLOSE.match(_code(self.lines[j])):
                    found = [int(t) for t in re.findall(r"\d+", _code(self.lines[j]))]
                    if len(found) > 1:
                        raise ValueError("%s %s: line %d holds more than one id; the writer "
                                         "edits one id per line" % (category, opened.group("klass"),
                                                                     j + 1))
                    ids += [(j, sid) for sid in found]
                    j += 1
                if j >= hi:
                    raise ValueError("%s %s: the class table opened on line %d never closes"
                                     % (category, opened.group("klass"), i + 1))
                out.append(_Entry(opened.group("klass"), i, j, ids, False))
                i = j
            i += 1
        return out

    def find(self, category, klass):
        # type: (str, str) -> Optional[_Entry]
        return next((e for e in self.entries(category) if e.klass == klass), None)

    def ids(self, category, klass):
        entry = self.find(category, klass)
        return entry.current() if entry else []

    # --- layout ---------------------------------------------------------------------------------

    def _tables(self, category, entry):
        """The class tables whose id lines set the layout: `entry` first, then the block's."""
        return [e for e in ([entry] if entry else []) + self.entries(category) if not e.legacy]

    def _id_indent(self, category, entry, class_indent):
        """The indent id lines use: the entry's own, else another table's in the block, else the
        class line's indent plus four spaces."""
        for e in self._tables(category, entry):
            if e.ids:
                return _indent_of(self.lines[e.ids[0][0]])
        return class_indent + "    "

    def _comment_column(self, category, entry, id_indent):
        """The column of `--` on the neighboring id lines: the entry's own, else the first
        commented id line in the block, else a width that fits a seven-digit id."""
        for e in self._tables(category, entry):
            for at, _sid in e.ids:
                if "--" in self.lines[at]:
                    return self.lines[at].index("--")
        return len(id_indent) + _DEFAULT_COMMENT_OFFSET

    @staticmethod
    def _id_line(indent, column, sid, comment):
        head = "%s%d," % (indent, sid)
        if not comment:
            return head
        return "%s%s-- %s" % (head, " " * max(1, column - len(head)), comment)

    def _added_comment(self, sid, replaced):
        parts = [self.names.get(sid) or ""]
        parts.append("added from the %s combat logs (SID)" % self.date if self.date
                     else "added from the combat logs (SID)")
        if replaced:
            parts.append("replaces %s" % _joined(replaced))
        return "; ".join(p for p in parts if p)

    # --- editing --------------------------------------------------------------------------------

    def _convert(self, category, entry):
        # type: (str, _Entry) -> _Entry
        """Rewrite a legacy one-line entry as a class table in place; return the new entry."""
        line = self.lines[entry.start]
        comment = research.split_comment(line)[1]
        indent = _indent_of(line)
        ids = entry.current()
        names = research.legacy_names(comment) if comment else []
        aligned = len(names) == len(ids)
        comments = []
        for i, sid in enumerate(ids):
            if aligned and names[i][0]:
                name, aside = names[i]
                comments.append("%s; %s" % (name, aside) if aside else name)
            else:
                comments.append(self.names.get(sid) or "")
        id_indent = self._id_indent(category, None, indent)
        column = self._comment_column(category, None, id_indent)
        new = ["%s-- %s" % (indent, comment)] if comment and not aligned else []
        head = len(new)
        new.append("%s%s = {" % (indent, entry.klass))
        new += [self._id_line(id_indent, column, sid, c) for sid, c in zip(ids, comments)]
        new.append("%s}," % indent)
        self.lines[entry.start:entry.start + 1] = new
        start = entry.start + head
        return _Entry(entry.klass, start, start + len(ids) + 1,
                      [(start + 1 + k, sid) for k, sid in enumerate(ids)], False)

    def _edit(self, category, klass, drop, add, replaced=()):
        # type: (str, str, list, list, tuple) -> Tuple[List[int], List[int]]
        """The one edit every ruling reduces to: the ids in `drop` out of the class, the ids in
        `add` in (one line each, where the first dropped id was, else at the end of the table).
        Return (removed, added). Nothing changes, and no legacy line is converted, when neither
        list has anything to do."""
        entry = self.find(category, klass)
        current = entry.current() if entry else []
        drop = set(drop) - set(add)  # an id both dropped and added stays where it is
        gone = [sid for sid in current if sid in drop]
        kept = [sid for sid in current if sid not in drop]
        new = [sid for sid in dict.fromkeys(add) if sid not in kept]
        if not gone and not new:
            return [], []
        if entry is None:
            self._new_table(category, klass, new)
            return [], new
        if entry.legacy:
            if not new and set(gone) == set(current):
                del self.lines[entry.start]  # the whole line goes: nothing to convert
                return gone, []
            entry = self._convert(category, entry)
        id_indent = self._id_indent(category, entry, _indent_of(self.lines[entry.start]))
        column = self._comment_column(category, entry, id_indent)
        fresh = [self._id_line(id_indent, column, sid, self._added_comment(sid, list(replaced)))
                 for sid in new]
        inner = []  # type: List[str]
        placed = False
        drop_at = {at for at, sid in entry.ids if sid in drop}
        for at in range(entry.start + 1, entry.end):
            if at in drop_at:
                if not placed:
                    inner += fresh
                    placed = True
                continue
            inner.append(self.lines[at])
        if not placed:
            inner += fresh
        if not any(re.search(r"\d", _code(line)) for line in inner):
            del self.lines[entry.start:entry.end + 1]  # the class table is empty: it goes
        else:
            self.lines[entry.start + 1:entry.end] = inner
        return gone, new

    def _new_table(self, category, klass, ids):
        """A new class table for `klass`, in research.CLASS_EMIT_ORDER order: above the first class
        that sorts after it (and above the comment lines directly over that class), else after the
        last class, else just inside the block."""
        lo, hi = self.block(category)
        present = self.entries(category)
        if present:
            indent = _indent_of(self.lines[present[0].start])
            later = [e for e in present if _class_rank(e.klass) > _class_rank(klass)]
            if later:
                where = later[0].start
                while where > lo and _code(self.lines[where - 1]).strip() == "" \
                        and research.split_comment(self.lines[where - 1])[1] is not None:
                    where -= 1
            else:
                where = present[-1].end + 1
        else:
            indent = _indent_of(self.lines[hi]) + "    "
            where = hi
        id_indent = self._id_indent(category, None, indent)
        column = self._comment_column(category, None, id_indent)
        self.lines[where:where] = (
            ["%s%s = {" % (indent, klass)]
            + [self._id_line(id_indent, column, sid, self._added_comment(sid, [])) for sid in ids]
            + ["%s}," % indent])

    def remove(self, category, klass, ids):
        # type: (str, str, list) -> List[int]
        """Remove ids from the class: each id's line goes, and a class table left empty goes with
        it. Return the ids removed."""
        return self._edit(category, klass, ids, [])[0]

    def replace(self, category, klass, listed, proposed):
        # type: (str, str, list, list) -> Tuple[List[int], List[int]]
        """One edit of one class: the listed ids out, the proposed ones in, in the place of the
        first listed id (appended when none is there), each new line's comment saying what it
        replaces. An id both listed and proposed stays where it is. Return (removed, added)."""
        drop = set(listed) - set(proposed)
        gone = [i for i in self.ids(category, klass) if i in drop]
        return self._edit(category, klass, listed, proposed, tuple(gone))

    def insert(self, category, klass, ids):
        # type: (str, str, list) -> List[int]
        """Append ids to the class table, or add a new class table. Return the ids added."""
        return self._edit(category, klass, [], ids)[1]


def _ruled_target(p, entry):
    return entry.get("category") or p["category"]


def _names_of(pairs):
    # type: (list) -> Dict[int, str]
    """{id: name}, the first non-empty name given for each id."""
    out = {}  # type: Dict[int, str]
    for sid, name in pairs:
        if name and int(sid) not in out:
            out[int(sid)] = name
    return out


def apply(categories_lua, decisions, proposals, bundle_rel, date=None):
    # type: (Path, dict, List[dict], str, Optional[str]) -> List[str]
    """Apply the ruled proposals (proposals.json entries) to Categories.lua; return a change log.

    Every proposal must have an entry in `decisions` (UnruledProposal otherwise, naming the key);
    `reject` entries change nothing. The file is written once, at the end, only when something
    changed; a refusal (an unruled key, an unknown category) leaves it untouched. A new id line's
    comment carries the proposal's `name` and the bundle date (`date`, else the one in
    `bundle_rel`'s name).
    """
    categories_lua = Path(categories_lua)
    names = _names_of([(sid, p.get("name")) for p in proposals
                       for sid in list(p.get("proposed") or []) + list(p.get("listed") or [])])
    lua = _Lua(categories_lua.read_bytes().decode("utf-8"), names,
               date or bundle_date(bundle_rel))
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
            removed, added = lua.replace(target, klass, listed, proposed)
        else:
            # a move into the category it is already in removes nothing (it would re-add the ids)
            removed = (lua.remove(source, klass, listed)
                       if source and listed and source != target else [])
            added = lua.insert(target, klass, proposed)
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


def plan_rows(categories_lua, decisions, rows, bundle_rel, date=None):
    # type: (Path, dict, List[dict], str, Optional[str]) -> Tuple[str, List[str]]
    """(Categories.lua's new text, the change log) for the review-sheet rows ruled in `decisions`
    (row keys); nothing is written. Rows without a ruling, and rejected rows, change nothing.

    Per row: `deletion` removes the id (its line) from its class in current_category; `correction-add`
    and `addition` add it to the ruled category; `move` removes it from current_category and adds
    it to the ruled category. Within one proposal an approved deletion and approved adds into the
    same category are one in-place replace (the new ids take the deleted id's place). Every target
    category is checked before anything is edited; ValueError names an unknown one. A new id
    line's comment carries the row's `spell_name` and the bundle date (`date`, else the one in
    `bundle_rel`'s name).
    """
    categories_lua = Path(categories_lua)
    text = categories_lua.read_bytes().decode("utf-8")
    lua = _Lua(text, _names_of([(row["spell_id"], row.get("spell_name")) for row in rows]),
               date or bundle_date(bundle_rel))
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
                removed, added = lua.replace(cat, klass, ids, adds.pop(cat))
                log(cat, klass, "-", removed, pkey)
                log(cat, klass, "+", added, pkey)
            else:
                log(cat, klass, "-", lua.remove(cat, klass, ids), pkey)
        for cat, ids in adds.items():
            log(cat, klass, "+", lua.insert(cat, klass, ids), pkey)
        for source, target, sid in moves:
            if source != target:
                log(source, klass, "-", lua.remove(source, klass, [sid]), pkey)
            log(target, klass, "+", lua.insert(target, klass, [sid]), pkey)
    return (lua.text() if changes else text), changes


def apply_rows(categories_lua, decisions, rows, bundle_rel, date=None):
    # type: (Path, dict, List[dict], str, Optional[str]) -> List[str]
    """plan_rows(), then write Categories.lua when anything changed; return the change log."""
    text, changes = plan_rows(categories_lua, decisions, rows, bundle_rel, date)
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
