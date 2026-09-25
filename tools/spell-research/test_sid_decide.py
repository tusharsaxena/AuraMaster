"""Tests for sid_decide (decisions.json, DECISIONS.md, apply) and `logs.py decide` / `logs.py apply`.

Run: python3 -m unittest discover -s tools/spell-research -p 'test_*.py'

Every case works on a temp copy of a fixture; nothing touches defaults/ or the network.
fixtures/Categories.lua is the LEGACY layout (one line per class), so ApplyTests covers converting
a legacy line the moment a ruling edits it; fixtures/Categories-multiline.lua is the shipped layout
(one id per line, the name in the same-line comment), covered by MultilineApplyTests.
"""

import difflib
import io
import json
import shutil
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import logs  # noqa: E402
import sid_db2  # noqa: E402
import sid_decide  # noqa: E402

FIXTURES = HERE / "fixtures"
BUNDLE_REL = "docs/spell-research/2026-09-24-logs"
DATE = "2026-09-24"
# The comment the writer puts on a line it adds: the proposal's name, then where it came from.
ADDED = "-- %%s; added from the %s combat logs (SID)" % DATE


def prop(ptype, category, klass, name, listed, proposed, from_category=""):
    """A proposals.json entry (the shape sid_artifacts.proposal_dict writes)."""
    key = "%s|%s|%s|%s|%s" % (ptype, category, klass, name.lower(),
                              ",".join(map(str, sorted(proposed))))
    return {"section": "addition" if ptype == "addition" else "correction", "key": key,
            "type": ptype, "category": category, "from_category": from_category, "class": klass,
            "name": name, "listed": list(listed), "proposed": list(proposed), "evidence": {},
            "rule": "evidence", "reason": "", "confidence": "high", "applications": 100}


ASCENDANCE = prop("replace", "offensiveCDs", "SHAMAN", "Ascendance", [114051], [114052])


def accepted(*proposals, ruling="accept", category=None):
    out = {}
    for p in proposals:
        entry = {"ruling": ruling, "date": DATE, "reason": ""}
        if category:
            entry["category"] = category
        out[p["key"]] = entry
    return out


class TempLua:
    FIXTURE = "Categories.lua"

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.lua = self.root / "Categories.lua"
        shutil.copyfile(FIXTURES / self.FIXTURE, self.lua)
        self.before = self.lua.read_bytes().decode("utf-8")

    def tearDown(self):
        self.tmp.cleanup()

    def after(self):
        return self.lua.read_bytes().decode("utf-8")

    def diff(self):
        """(removed lines, added lines) between the fixture and the rewritten file."""
        removed, added = [], []
        for line in difflib.ndiff(self.before.splitlines(), self.after().splitlines()):
            if line.startswith("- "):
                removed.append(line[2:])
            elif line.startswith("+ "):
                added.append(line[2:])
        return removed, added

    def apply(self, proposals, decisions):
        return sid_decide.apply(self.lua, decisions, proposals, BUNDLE_REL)

    def classes(self, key):
        return next(c for c in sid_db2.shipped_categories(self.lua) if c["key"] == key)["classes"]


class ApplyTests(TempLua, unittest.TestCase):
    def test_replace_converts_the_legacy_class_line_to_a_table(self):
        changes = self.apply([ASCENDANCE], accepted(ASCENDANCE))
        removed, added = self.diff()
        self.assertEqual(removed, [
            "            SHAMAN      = { 114051 },   -- Ascendance (Enhancement; Restoration is 114052)"])
        self.assertEqual(added, [
            "            SHAMAN = {",
            "                114052,  " + ADDED % "Ascendance" + "; replaces 114051",
            "            },"])
        self.assertEqual(self.classes("offensiveCDs")["SHAMAN"], [114052])
        self.assertEqual(self.classes("offensiveCDs")["WARRIOR"], [1719, 107574])
        self.assertTrue(changes and any("114052" in c for c in changes), changes)

    def test_a_converted_line_keeps_its_positional_names_and_asides(self):
        p = prop("add", "offensiveCDs", "SHAMAN", "Ascendance", [114051], [900114])
        self.apply([p], accepted(p))
        lines = [l.strip() for l in self.after().splitlines()]
        at = lines.index("SHAMAN = {")
        self.assertEqual(lines[at + 1:at + 4], [
            "114051,  -- Ascendance; Enhancement; Restoration is 114052",
            "900114,  " + ADDED % "Ascendance",
            "},"])
        # and the commented-out line above it is untouched
        self.assertIn("-- SHAMAN = { 999999 }, a commented-out line is not an entry", self.after())

    def test_add_appends_a_line_to_the_class(self):
        p = prop("add", "defensives", "SHAMAN", "Astral Shift", [108271], [900108])
        self.apply([p], accepted(p))
        self.assertEqual(self.classes("defensives")["SHAMAN"], [108271, 900108])
        removed, added = self.diff()
        self.assertEqual(removed, ["            SHAMAN      = { 108271 },"])
        # the legacy line had no comment, so its id takes the proposal's name
        self.assertEqual([a.strip() for a in added],
                         ["SHAMAN = {", "108271,  -- Astral Shift",
                          "900108,  " + ADDED % "Astral Shift", "},"])

    def test_a_class_not_yet_in_the_category_gets_a_new_table_in_canonical_order(self):
        # PRIEST sorts after WARRIOR and before SHAMAN in research.CLASS_EMIT_ORDER
        p = prop("addition", "defensives", "PRIEST", "Desperate Prayer", [], [19236])
        self.apply([p], accepted(p))
        removed, added = self.diff()
        self.assertEqual(removed, [])
        self.assertEqual(added, ["            PRIEST = {",
                                 "                19236,   " + ADDED % "Desperate Prayer",
                                 "            },"])
        lines = self.after().splitlines()
        w = next(i for i, l in enumerate(lines) if "WARRIOR     = { 871, 12975 }," in l)
        s = next(i for i, l in enumerate(lines) if "SHAMAN      = { 108271 }," in l)
        pr = lines.index(added[0])
        self.assertTrue(w < pr < s, (w, pr, s))
        self.assertEqual(self.classes("defensives")["PRIEST"], [19236])

    def test_a_class_later_than_every_listed_one_goes_last(self):
        p = prop("addition", "defensives", "EVOKER", "Obsidian Scales", [], [363916])
        self.apply([p], accepted(p))
        lines = self.after().splitlines()
        at = next(i for i, l in enumerate(lines) if "363916," in l)
        self.assertEqual(lines[at - 1].strip(), "EVOKER = {")
        self.assertIn("SHAMAN      = { 108271 },", lines[at - 2])
        self.assertEqual(lines[at + 1].strip(), "},")
        self.assertEqual(lines[at + 2].strip(), "}),")

    def test_move_removes_from_the_source_and_appends_to_the_target(self):
        p = prop("move", "offensiveCDs", "WARRIOR", "Shield Wall", [871], [871],
                 from_category="defensives")
        self.apply([p], accepted(p))
        self.assertEqual(self.classes("defensives")["WARRIOR"], [12975])
        self.assertEqual(self.classes("offensiveCDs")["WARRIOR"], [1719, 107574, 871])

    def test_a_move_ruling_on_an_addition_accepts_into_the_chosen_category(self):
        p = prop("addition", "defensives", "SHAMAN", "Spirit Walk", [], [58875])
        self.apply([p], accepted(p, ruling="move", category="offensiveCDs"))
        self.assertEqual(self.classes("defensives")["SHAMAN"], [108271])
        self.assertEqual(self.classes("offensiveCDs")["SHAMAN"], [114051, 58875])

    def test_accept_with_a_decide_time_category_uses_it(self):
        p = prop("addition", "defensives", "SHAMAN", "Spirit Walk", [], [58875])
        self.apply([p], accepted(p, category="offensiveCDs"))
        self.assertEqual(self.classes("offensiveCDs")["SHAMAN"], [114051, 58875])

    def test_reject_changes_nothing(self):
        changes = self.apply([ASCENDANCE], accepted(ASCENDANCE, ruling="reject"))
        self.assertEqual(changes, [])
        self.assertEqual(self.after(), self.before)

    def test_apply_twice_changes_nothing_the_second_time(self):
        p = prop("addition", "defensives", "PRIEST", "Desperate Prayer", [], [19236])
        props = [ASCENDANCE, p]
        self.apply(props, accepted(*props))
        once = self.lua.read_bytes()
        changes = self.apply(props, accepted(*props))
        self.assertEqual(changes, [])
        self.assertEqual(self.lua.read_bytes(), once)

    def test_an_accepted_proposal_not_in_decisions_is_refused(self):
        with self.assertRaises(sid_decide.UnruledProposal) as ctx:
            self.apply([ASCENDANCE], {})
        self.assertIn(ASCENDANCE["key"], str(ctx.exception))
        self.assertEqual(self.after(), self.before)

    def test_an_unknown_target_category_is_refused_and_nothing_is_written(self):
        p = prop("addition", "noSuchCategory", "SHAMAN", "Spirit Walk", [], [58875])
        with self.assertRaises(ValueError) as ctx:
            self.apply([ASCENDANCE, p], accepted(ASCENDANCE, p))
        self.assertIn("noSuchCategory", str(ctx.exception))
        self.assertEqual(self.after(), self.before)

    def test_the_rewritten_file_keeps_crlf(self):
        p = prop("addition", "defensives", "PRIEST", "Desperate Prayer", [], [19236])
        self.apply([ASCENDANCE, p], accepted(ASCENDANCE, p))
        raw = self.lua.read_bytes()
        self.assertEqual(raw.count(b"\n"), raw.count(b"\r\n"))
        self.assertTrue(raw.endswith(b"\r\n"))

    def test_removing_the_last_id_drops_the_class_line(self):
        p = prop("move", "offensiveCDs", "SHAMAN", "Astral Shift", [108271], [108271],
                 from_category="defensives")
        self.apply([p], accepted(p))
        self.assertNotIn("SHAMAN", self.classes("defensives"))
        self.assertEqual(self.classes("offensiveCDs")["SHAMAN"], [114051, 108271])


class MultilineApplyTests(TempLua, unittest.TestCase):
    """The writer on the shipped layout: one id per line, the name in the same-line comment."""

    FIXTURE = "Categories-multiline.lua"

    def test_add_appends_one_line_aligned_to_the_class_tables_comment_column(self):
        p = prop("add", "offensiveCDs", "WARRIOR", "Recklessness", [1719], [900719, 900720])
        changes = self.apply([p], accepted(p))
        removed, added = self.diff()
        self.assertEqual(removed, [])
        self.assertEqual(added, ["                900719,  " + ADDED % "Recklessness",
                                 "                900720,  " + ADDED % "Recklessness"])
        lines = self.after().splitlines()
        at = lines.index(added[0])
        self.assertEqual(lines[at - 1], "                107574,  -- Avatar")
        self.assertEqual(lines[at + 2], "            },")
        self.assertEqual(self.classes("offensiveCDs")["WARRIOR"], [1719, 107574, 900719, 900720])
        self.assertEqual(changes, ["offensiveCDs WARRIOR: +900719, 900720 (%s)" % p["key"]])

    def test_an_id_that_only_appears_in_a_comment_is_still_added(self):
        # "replaces 231895" is in PALADIN's comments; 231895 is not listed, so it is added, and
        # into PALADIN's own table (not a second PALADIN entry)
        p = prop("add", "offensiveCDs", "PALADIN", "Avenging Wrath", [31884], [231895])
        self.apply([p], accepted(p))
        removed, added = self.diff()
        self.assertEqual(removed, [])
        self.assertEqual(added, ["                231895,  " + ADDED % "Avenging Wrath"])
        self.assertEqual(self.classes("offensiveCDs")["PALADIN"], [31884, 454351, 231895])
        self.assertEqual(self.after().count("PALADIN = {"), 1)

    def test_remove_deletes_only_the_ids_line(self):
        p = prop("move", "offensiveCDs", "WARRIOR", "Shield Wall", [871], [871],
                 from_category="defensives")
        self.apply([p], accepted(p))
        removed, added = self.diff()
        self.assertEqual(removed, ["                871,    -- Shield Wall"])
        self.assertEqual(added, ["                871,     " + ADDED % "Shield Wall"])
        self.assertEqual(self.classes("defensives")["WARRIOR"], [12975])
        self.assertEqual(self.classes("offensiveCDs")["WARRIOR"], [1719, 107574, 871])

    def test_a_class_table_left_empty_is_deleted_but_the_comment_above_it_stays(self):
        p = prop("move", "offensiveCDs", "SHAMAN", "Astral Shift", [108271], [108271],
                 from_category="defensives")
        self.apply([p], accepted(p))
        self.assertNotIn("SHAMAN", self.classes("defensives"))
        removed, _added = self.diff()
        self.assertEqual(removed, ["            SHAMAN = {", "                108271, -- Astral Shift",
                                   "            },"])
        self.assertIn("            -- Spirit Walk (58875) is Movement only (owner 2026-09-25)\r\n"
                      "            EVOKER = {\r\n", self.after())

    def test_replace_puts_the_new_line_where_the_old_one_was_and_says_what_it_replaces(self):
        p = prop("replace", "offensiveCDs", "PALADIN", "Avenging Wrath", [31884], [900884])
        self.apply([p], accepted(p))
        removed, added = self.diff()
        self.assertEqual(removed, ["                31884,   -- Avenging Wrath"])
        self.assertEqual(added, ["                900884,  " + ADDED % "Avenging Wrath"
                                 + "; replaces 31884"])
        self.assertEqual(self.classes("offensiveCDs")["PALADIN"], [900884, 454351])

    def test_replace_keeps_the_comment_lines_inside_the_table(self):
        self.apply([ASCENDANCE], accepted(ASCENDANCE))
        self.assertIn("            SHAMAN = {\r\n"
                      "                -- 999999,  -- commented out: not an entry\r\n"
                      "                114052,  " + ADDED % "Ascendance" + "; replaces 114051\r\n"
                      "            },\r\n", self.after())
        self.assertEqual(self.classes("offensiveCDs")["SHAMAN"], [114052])

    def test_a_new_class_goes_in_canonical_order_above_the_comment_over_the_next_class(self):
        # PRIEST sorts before SHAMAN, and SHAMAN's table has a comment line directly above it
        p = prop("addition", "defensives", "PRIEST", "Desperate Prayer", [], [19236])
        self.apply([p], accepted(p))
        removed, added = self.diff()
        self.assertEqual(removed, [])
        self.assertEqual(len(added), 3)
        self.assertIn("                12975,  -- Last Stand\r\n"
                      "            },\r\n"
                      "            PRIEST = {\r\n"
                      "                19236,  " + ADDED % "Desperate Prayer" + "\r\n"
                      "            },\r\n"
                      "            -- Spirit Walk (58875) is Movement only (owner 2026-09-25)\r\n"
                      "            SHAMAN = {\r\n", self.after())

    def test_a_new_class_takes_the_blocks_comment_column(self):
        p = prop("addition", "offensiveCDs", "PRIEST", "Voidform", [], [194249])
        self.apply([p], accepted(p))
        _removed, added = self.diff()
        self.assertEqual(added, ["            PRIEST = {",
                                 "                194249,  " + ADDED % "Voidform",
                                 "            },"])
        self.assertEqual(list(self.classes("offensiveCDs")), ["WARRIOR", "PALADIN", "PRIEST", "SHAMAN"])

    def test_a_legacy_line_in_a_multiline_block_is_converted_when_edited(self):
        p = prop("add", "hardCC", "SHAMAN", "Hex", [51514], [900514])
        self.apply([p], accepted(p))
        removed, added = self.diff()
        self.assertEqual(removed, [
            "            SHAMAN      = { 51514, 118905 },                        "
            "-- Hex (Frog; 211004 is the Spider), Capacitor Totem"])
        # the block's table sets the indent and the comment column; the aside rides along
        self.assertEqual(added, [
            "            SHAMAN = {",
            "                51514,   -- Hex; Frog; 211004 is the Spider",
            "                118905,  -- Capacitor Totem",
            "                900514,  " + ADDED % "Hex",
            "            },"])
        self.assertEqual(self.classes("hardCC")["SHAMAN"], [51514, 118905, 900514])

    def test_a_legacy_comment_that_does_not_line_up_stays_as_a_comment_line(self):
        text = self.before.replace("-- Hex (Frog; 211004 is the Spider), Capacitor Totem",
                                   "-- Hex and a totem")
        self.lua.write_bytes(text.encode("utf-8"))
        self.before = text
        p = prop("add", "hardCC", "SHAMAN", "Hex", [51514], [900514])
        self.apply([p], accepted(p))
        _removed, added = self.diff()
        # 51514 takes the proposal's name; 118905 has none to take
        self.assertEqual(added, [
            "            -- Hex and a totem",
            "            SHAMAN = {",
            "                51514,   -- Hex",
            "                118905,",
            "                900514,  " + ADDED % "Hex",
            "            },"])

    def test_removing_every_id_of_a_legacy_line_just_deletes_it(self):
        p = prop("move", "offensiveCDs", "SHAMAN", "Hex", [51514, 118905], [51514, 118905],
                 from_category="hardCC")
        self.apply([p], accepted(p))
        self.assertNotIn("SHAMAN", self.classes("hardCC"))
        self.assertNotIn("Capacitor Totem", self.after().split("Cat.HARMFUL")[1])
        self.assertEqual(self.classes("offensiveCDs")["SHAMAN"], [114051, 51514, 118905])

    def test_a_second_apply_changes_nothing(self):
        props = [
            ASCENDANCE,
            prop("replace", "offensiveCDs", "PALADIN", "Avenging Wrath", [31884], [900884]),
            prop("add", "offensiveCDs", "WARRIOR", "Recklessness", [1719], [900719]),
            prop("addition", "defensives", "PRIEST", "Desperate Prayer", [], [19236]),
            prop("move", "offensiveCDs", "SHAMAN", "Astral Shift", [108271], [108271],
                 from_category="defensives"),
            prop("add", "hardCC", "SHAMAN", "Hex", [51514], [900514]),
        ]
        first = self.apply(props, accepted(*props))
        self.assertEqual(len(first), 9, first)
        once = self.lua.read_bytes()
        self.assertEqual(self.apply(props, accepted(*props)), [])
        self.assertEqual(self.lua.read_bytes(), once)
        self.assertEqual(once.count(b"\n"), once.count(b"\r\n"))
        self.assertTrue(once.endswith(b"\r\n"))


class RecordTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = Path(self.tmp.name) / "decisions.json"

    def tearDown(self):
        self.tmp.cleanup()

    def test_missing_file_loads_empty(self):
        self.assertEqual(sid_decide.load_decisions(self.path), {})

    def test_record_then_load_round_trips_sorted_and_crlf(self):
        sid_decide.record(self.path, "replace|b|SHAMAN|x|2", "accept", date=DATE)
        sid_decide.record(self.path, "addition|a|MAGE|y|1", "move", category="defensives",
                          reason="it is a defensive", date=DATE)
        sid_decide.record(self.path, "add|c|DRUID|z|3", "reject", reason="noise", date=DATE)
        got = sid_decide.load_decisions(self.path)
        self.assertEqual(got["replace|b|SHAMAN|x|2"]["ruling"], "accept")
        self.assertEqual(got["addition|a|MAGE|y|1"],
                         {"ruling": "move", "category": "defensives",
                          "reason": "it is a defensive", "date": DATE})
        self.assertEqual(got["add|c|DRUID|z|3"]["reason"], "noise")
        raw = self.path.read_bytes()
        self.assertEqual(raw.count(b"\n"), raw.count(b"\r\n"))
        text = raw.decode("utf-8")
        self.assertEqual(json.loads(text), got)
        self.assertEqual(list(got), sorted(got))
        self.assertIn('\r\n  "add|c|DRUID|z|3": {\r\n    "date"', text)  # 2-space, sorted keys

    def test_rerecording_a_key_replaces_its_entry(self):
        sid_decide.record(self.path, "k", "accept", date=DATE)
        sid_decide.record(self.path, "k", "reject", reason="changed my mind", date="2026-09-25")
        got = sid_decide.load_decisions(self.path)
        self.assertEqual(got, {"k": {"ruling": "reject", "reason": "changed my mind",
                                     "date": "2026-09-25"}})

    def test_bad_ruling_date_and_move_without_category_are_refused(self):
        with self.assertRaises(ValueError):
            sid_decide.record(self.path, "k", "maybe", date=DATE)
        with self.assertRaises(ValueError):
            sid_decide.record(self.path, "k", "accept", date="24/09/2026")
        with self.assertRaises(ValueError):
            sid_decide.record(self.path, "k", "move", date=DATE)
        self.assertFalse(self.path.exists())

    def test_record_leaves_no_temp_file_behind(self):
        sid_decide.record(self.path, "k", "accept", date=DATE)
        self.assertEqual(sorted(p.name for p in self.path.parent.iterdir()), ["decisions.json"])


def run_cli(argv):
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        code = logs.main(argv)
    return code, out.getvalue(), err.getvalue()


class CliTests(TempLua, unittest.TestCase):
    def setUp(self):
        super().setUp()
        self.bundle = self.root / "bundle"
        self.bundle.mkdir()
        self.decisions = self.root / "decisions.json"
        self.addition = prop("addition", "defensives", "PRIEST", "Desperate Prayer", [], [19236])
        self.pending = prop("add", "defensives", "SHAMAN", "Astral Shift", [108271], [900108])
        doc = {"date": DATE, "thresholds": {},
               "proposals": [ASCENDANCE, self.pending, self.addition]}
        (self.bundle / "proposals.json").write_bytes(
            json.dumps(doc, indent=1).replace("\n", "\r\n").encode("utf-8"))

    def decide(self, key, ruling, *extra):
        return run_cli(["decide", "--bundle", str(self.bundle), "--key", key, "--ruling", ruling,
                        "--date", DATE, "--decisions", str(self.decisions),
                        "--categories", str(self.lua)] + list(extra))

    def test_decide_then_apply_end_to_end(self):
        self.assertEqual(self.decide(ASCENDANCE["key"], "accept")[0], 0)
        self.assertEqual(self.decide(self.addition["key"], "reject", "--reason", "not a CD")[0], 0)
        code, out, _err = run_cli(["apply", "--bundle", str(self.bundle), "--categories",
                                   str(self.lua), "--decisions", str(self.decisions)])
        self.assertEqual(code, 0)
        self.assertEqual(self.classes("offensiveCDs")["SHAMAN"], [114052])
        self.assertNotIn("PRIEST", self.classes("defensives"))
        self.assertEqual(self.classes("defensives")["SHAMAN"], [108271])  # unruled: untouched
        self.assertIn("1 not yet ruled", out)
        md = (self.bundle / "DECISIONS.md").read_bytes()
        self.assertEqual(md.count(b"\n"), md.count(b"\r\n"))
        text = md.decode("utf-8")
        cell = lambda key: key.replace("|", "\\|")  # a Markdown table cell escapes its pipes
        self.assertIn(cell(ASCENDANCE["key"]), text)
        self.assertIn(cell(self.addition["key"]), text)
        self.assertIn("not a CD", text)
        self.assertNotIn(cell(self.pending["key"]), text)
        self.assertNotIn(self.pending["key"], text)

    def test_decide_refuses_a_key_not_in_the_bundle(self):
        with self.assertRaises(SystemExit) as ctx:
            self.decide("replace|x|y|z|1", "accept")
        self.assertIn("replace|x|y|z|1", str(ctx.exception.code))
        self.assertFalse(self.decisions.exists())

    def test_decide_move_needs_a_known_category(self):
        with self.assertRaises(SystemExit):
            self.decide(self.addition["key"], "move")
        with self.assertRaises(SystemExit) as ctx:
            self.decide(self.addition["key"], "move", "--category", "nope")
        self.assertIn("nope", str(ctx.exception.code))
        self.assertFalse(self.decisions.exists())
        self.assertEqual(self.decide(self.addition["key"], "move", "--category",
                                     "offensiveCDs")[0], 0)

    def test_decide_needs_a_date(self):
        with self.assertRaises(SystemExit):
            run_cli(["decide", "--bundle", str(self.bundle), "--key", ASCENDANCE["key"],
                     "--ruling", "accept", "--decisions", str(self.decisions)])


if __name__ == "__main__":
    unittest.main()
