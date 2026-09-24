"""Tests for sid_review: the review sheet REVIEW.csv and its explainer REVIEW.md (SID-13).

Run: python3 -m unittest discover -s tools/spell-research -p 'test_*.py'
"""

import csv
import io
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import sid_artifacts  # noqa: E402
import sid_propose  # noqa: E402
import sid_review  # noqa: E402

COLUMNS = ["row_id", "spell_id", "spell_name", "type", "class", "current_category",
           "proposed_category", "specs", "applications", "players", "context", "confidence",
           "proposal_key", "decision"]

SHIPPED = [
    {"key": "defensives", "label": "Defensive cooldowns", "aura": "BUFF",
     "classes": {"SHAMAN": [108271]}},
    {"key": "offensiveCDs", "label": "Offensive cooldowns", "aura": "BUFF",
     "classes": {"SHAMAN": [114051, 201633]}},
    {"key": "externals", "label": "External defensives", "aura": "BUFF", "classes": {}},
    {"key": "consumables", "label": "Consumables", "aura": "BUFF", "classes": {}},
]

NAMES = {114051: "Ascendance", 114052: "Ascendance", 1219480: "Ascendance",
         201633: "Earthen Wall", 201634: "Earthen Wall", 900500: "Fixture Guard",
         900600: "Fixture Shield", 900300: "Well Fed", 108271: "Astral Shift"}


def P(ptype, category, klass, name, listed, proposed, evidence, apps, rule="evidence",
      from_category="", confidence="high", reason="A reason."):
    return sid_propose.Proposal(
        type=ptype, category=category, from_category=from_category, klass=klass, name=name,
        listed=listed, proposed=proposed, evidence=evidence, rule=rule, reason=reason,
        confidence=confidence, applications=apps)


def proposals():
    return [
        # Given out of order: the sheet sorts corrections by applications, additions by category.
        P("addition", "consumables", "ALL", "Well Fed", [], [900300],
          {900300: {"WARRIOR Arms": (40, 4), "SHAMAN Restoration": (30, 3)}}, 70, rule="R8",
          reason="Applied by 2 classes; an item effect."),
        P("add", "offensiveCDs", "SHAMAN", "Earthen Wall", [201633], [201634],
          {201633: {"Restoration": (50, 5)}, 201634: {"Restoration": (25, 4)}}, 25),
        P("replace", "offensiveCDs", "SHAMAN", "Ascendance", [114051], [114052, 1219480],
          {114051: {}, 114052: {"Restoration": (1126, 53)}, 1219480: {"Elemental": (693, 73)}},
          1819, reason="114051 never applied by any SHAMAN player, while 114052, 1219480 "
                       "applied Ascendance 1819 times."),
        P("addition", "defensives", "SHAMAN", "Fixture Guard", [], [900500],
          {900500: {"Enhancement": (30, 3)}}, 30, rule="R1", confidence="medium",
          reason="Mostly self and reduces damage taken."),
        P("move", "defensives", "SHAMAN", "Astral Shift", [108271], [108271],
          {108271: {"Elemental": (60, 6), "Restoration": (40, 5)}}, 100, rule="R1",
          from_category="externals", confidence="medium", reason="Mostly self."),
        P("addition", "defensives", "SHAMAN", "Fixture Shield", [], [900600],
          {900600: {"Elemental": (90, 9)}}, 90, rule="R1", reason="Reduces damage taken."),
    ]


CLASS_PLAYERS = {("SHAMAN", "BUFF", 114052): 50, ("SHAMAN", "BUFF", 1219480): 70,
                 ("WARRIOR", "BUFF", 900300): 4, ("SHAMAN", "BUFF", 900300): 3,
                 ("SHAMAN", "BUFF", 108271): 10}


class ReviewRowsTest(unittest.TestCase):
    def setUp(self):
        self.rows = sid_review.review_rows(proposals(), SHIPPED, NAMES, CLASS_PLAYERS)

    def by(self, ptype, sid):
        return [r for r in self.rows if r["type"] == ptype and r["spell_id"] == sid]

    def test_every_proposal_is_covered(self):
        keys = {sid_propose.proposal_key(p) for p in proposals()}
        self.assertEqual({r["proposal_key"] for r in self.rows}, keys)

    def test_a_replace_splits_into_one_deletion_and_one_add_per_proposed_id(self):
        key = "replace|offensiveCDs|SHAMAN|ascendance|114052,1219480"
        mine = [(r["type"], r["spell_id"]) for r in self.rows if r["proposal_key"] == key]
        self.assertEqual(mine, [("deletion", 114051), ("correction-add", 114052),
                                ("correction-add", 1219480)])
        dele = self.by("deletion", 114051)[0]
        self.assertEqual((dele["current_category"], dele["proposed_category"]),
                         ("offensiveCDs", ""))
        add = self.by("correction-add", 114052)[0]
        self.assertEqual((add["current_category"], add["proposed_category"]),
                         ("offensiveCDs", "offensiveCDs"))

    def test_an_add_is_only_its_new_ids(self):
        key = "add|offensiveCDs|SHAMAN|earthen wall|201634"
        self.assertEqual([(r["type"], r["spell_id"]) for r in self.rows if r["proposal_key"] == key],
                         [("correction-add", 201634)])

    def test_a_move_names_both_categories(self):
        row = self.by("move", 108271)[0]
        self.assertEqual((row["current_category"], row["proposed_category"]),
                         ("externals", "defensives"))

    def test_an_addition_has_no_current_category(self):
        row = self.by("addition", 900500)[0]
        self.assertEqual((row["current_category"], row["proposed_category"], row["class"]),
                         ("", "defensives", "SHAMAN"))

    def test_order_corrections_by_applications_then_additions_by_category(self):
        self.assertEqual([(r["type"], r["spell_id"]) for r in self.rows], [
            ("deletion", 114051), ("correction-add", 114052), ("correction-add", 1219480),
            ("move", 108271), ("correction-add", 201634),
            ("addition", 900600), ("addition", 900500),  # defensives, most-applied first
            ("addition", 900300),                         # consumables
        ])

    def test_row_ids_are_sequential_and_unique(self):
        self.assertEqual([r["row_id"] for r in self.rows],
                         ["R%04d" % i for i in range(1, len(self.rows) + 1)])

    def test_specs_applications_players(self):
        row = self.by("correction-add", 114052)[0]
        self.assertEqual((row["specs"], row["applications"], row["players"]),
                         ("Restoration 1126/53", 1126, 50))
        move = self.by("move", 108271)[0]
        self.assertEqual((move["specs"], move["applications"], move["players"]),
                         ("Elemental 60/6; Restoration 40/5", 100, 10))
        dele = self.by("deletion", 114051)[0]
        self.assertEqual((dele["specs"], dele["applications"], dele["players"]), ("", 0, 0))

    def test_all_players_sum_the_classes(self):
        row = self.by("addition", 900300)[0]
        self.assertEqual((row["class"], row["players"], row["applications"]), ("ALL", 7, 70))
        self.assertEqual(row["specs"], "WARRIOR Arms 40/4; SHAMAN Restoration 30/3")

    def test_without_exact_counts_players_is_a_lower_bound(self):
        rows = sid_review.review_rows(proposals(), SHIPPED, NAMES, {})
        move = [r for r in rows if r["type"] == "move"][0]
        self.assertEqual(move["players"], 6)       # the most in one spec
        well_fed = [r for r in rows if r["spell_id"] == 900300][0]
        self.assertEqual(well_fed["players"], 7)   # per-class, summed (disjoint across classes)

    def test_names_context_confidence(self):
        row = self.by("correction-add", 1219480)[0]
        self.assertEqual(row["spell_name"], "Ascendance")
        self.assertIn("114051 never applied", row["context"])
        self.assertIn("rule evidence", row["context"])
        self.assertEqual(row["confidence"], "high")
        guard = self.by("addition", 900500)[0]
        self.assertIn("reduces damage taken", guard["context"])
        self.assertIn("rule R1", guard["context"])
        self.assertEqual(guard["confidence"], "medium")

    def test_the_decision_is_empty(self):
        self.assertTrue(all(r["decision"] == "" for r in self.rows))


class ReviewFilesTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="sid-review-"))
        self.addCleanup(shutil.rmtree, str(self.tmp), True)
        self.written = sid_artifacts.write_bundle(
            self.tmp, "2026-09-24", [], proposals(), [], SHIPPED,
            {"thresholds": {"min_applications": 1, "min_players": 1}},
            names=NAMES, class_players=CLASS_PLAYERS)
        self.data = (self.tmp / "REVIEW.csv").read_bytes()

    def table(self):
        return list(csv.reader(io.StringIO(self.data.decode("utf-8-sig"), newline="")))

    def test_both_files_are_written(self):
        names = {p.name for p in self.written}
        self.assertIn("REVIEW.csv", names)
        self.assertIn("REVIEW.md", names)

    def test_bom_and_crlf(self):
        self.assertTrue(self.data.startswith(b"\xef\xbb\xbf"))
        self.assertTrue(self.data.endswith(b"\r\n"))
        self.assertEqual(self.data.count(b"\n"), self.data.count(b"\r\n"))
        md = (self.tmp / "REVIEW.md").read_bytes()
        self.assertEqual(md.count(b"\n"), md.count(b"\r\n"))

    def test_column_order_is_exact_and_decision_is_last(self):
        table = self.table()
        self.assertEqual(table[0], COLUMNS)
        self.assertEqual(list(sid_review.COLUMNS), COLUMNS)
        self.assertEqual(len(table), 1 + 8)
        for line in table[1:]:
            self.assertEqual(len(line), len(COLUMNS))
            self.assertEqual(line[-1], "")

    def test_a_comma_in_a_cell_round_trips(self):
        table = self.table()
        asc = [line for line in table if line[1] == "1219480"][0]
        self.assertIn("114052, 1219480", asc[COLUMNS.index("context")])

    def test_review_md_explains_the_columns_and_decisions(self):
        md = (self.tmp / "REVIEW.md").read_text(encoding="utf-8")
        for col in COLUMNS:
            self.assertIn("`%s`" % col, md)
        for value in ("Approve", "Reject", "`A`", "`R`", "`Y`", "`N`"):
            self.assertIn(value, md)
        for key in ("defensives", "offensiveCDs", "externals", "consumables"):
            self.assertIn("`%s`" % key, md)
        self.assertIn("apply", md)
        self.assertIn("8 rows", md)

    def test_decision_values(self):
        self.assertEqual(sid_review.decision_of("Approve"), "approve")
        self.assertEqual(sid_review.decision_of(" a "), "approve")
        self.assertEqual(sid_review.decision_of("y"), "approve")
        self.assertEqual(sid_review.decision_of("REJECT"), "reject")
        self.assertEqual(sid_review.decision_of("r"), "reject")
        self.assertEqual(sid_review.decision_of("N"), "reject")
        self.assertIsNone(sid_review.decision_of(""))
        with self.assertRaises(ValueError):
            sid_review.decision_of("maybe")

    def test_proposals_json_and_the_sheet_agree(self):
        keys = {p["key"] for p in json.loads(
            (self.tmp / "proposals.json").read_text(encoding="utf-8"))["proposals"]}
        sheet = {line[COLUMNS.index("proposal_key")] for line in self.table()[1:]}
        self.assertEqual(sheet, keys)


if __name__ == "__main__":
    unittest.main()
