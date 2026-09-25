"""Tests for ingesting the filled review sheet (SID-14): sid_review's sheet reader and validator,
sid_decide's row-granular rulings and row applier, the row suppression in sid_propose, and
`logs.py ingest`.

Run: python3 -m unittest discover -s tools/spell-research -p 'test_*.py'

Every case works in a temp dir on a copy of fixtures/Categories.lua; nothing touches defaults/,
tools/spell-research/decisions.json or the network.
"""

import csv
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
import sid_artifacts  # noqa: E402
import sid_db2  # noqa: E402
import sid_decide  # noqa: E402
import sid_propose  # noqa: E402
import sid_review  # noqa: E402

FIXTURES = HERE / "fixtures"
DATE = "2026-09-25"
BUNDLE_DATE = "2026-09-24"

# The fixture Categories.lua's `spells` categories (keys and labels as the file has them).
ASC_KEY = "replace|offensiveCDs|SHAMAN|ascendance|114052"


def P(ptype, category, klass, name, listed, proposed, apps, from_category="", rule="evidence",
      confidence="high"):
    return sid_propose.Proposal(
        type=ptype, category=category, from_category=from_category, klass=klass, name=name,
        listed=listed, proposed=proposed,
        evidence={sid: {"Restoration": (apps, 5)} for sid in proposed},
        rule=rule, reason="A reason.", confidence=confidence, applications=apps)


def proposals():
    """Against fixtures/Categories.lua: the Ascendance replace, a move of Astral Shift out of
    defensives into offensiveCDs, and a new aura for SHAMAN defensives."""
    return [
        P("replace", "offensiveCDs", "SHAMAN", "Ascendance", [114051], [114052], 1000),
        P("move", "offensiveCDs", "SHAMAN", "Astral Shift", [108271], [108271], 500,
          from_category="defensives", rule="R3", confidence="medium"),
        P("addition", "defensives", "SHAMAN", "Fixture Guard", [], [900500], 90, rule="R1"),
    ]


def read_csv_text(text):
    return list(csv.DictReader(io.StringIO(text.lstrip("﻿"), newline="")))


class Bundle:
    """A bundle written by sid_artifacts.write_bundle, a copy of the fixture Categories.lua and an
    empty decisions.json path, in a temp dir."""

    FIXTURE = "Categories.lua"

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.lua = self.root / "Categories.lua"
        shutil.copyfile(FIXTURES / self.FIXTURE, self.lua)
        self.shipped = sid_db2.shipped_categories(self.lua)
        self.bundle = self.root / "bundle"
        sid_artifacts.write_bundle(self.bundle, BUNDLE_DATE, [], proposals(), [], self.shipped,
                                   {"thresholds": {"min_applications": 1, "min_players": 1}})
        self.rows = sid_review.read_sheet(self.bundle / "REVIEW.csv")
        self.decisions = self.root / "decisions.json"

    def tearDown(self):
        self.tmp.cleanup()

    def row(self, rtype, sid):
        return next(r for r in self.rows if r["type"] == rtype and int(r["spell_id"]) == sid)

    def filled(self, marks, edits=None, drop=(), extra=()):
        """Write a filled copy of the bundle's sheet: marks {row_id: decision}, edits {row_id:
        {column: value}}; `drop` row ids left out, `extra` rows appended. Returns its path."""
        edits = edits or {}
        out = []
        for r in self.rows:
            if r["row_id"] in drop:
                continue
            r = dict(r)
            r["decision"] = marks.get(r["row_id"], "")
            r.update(edits.get(r["row_id"], {}))
            out.append(r)
        out += [dict(e) for e in extra]
        path = self.root / "filled.csv"
        buf = io.StringIO()
        writer = csv.DictWriter(buf, fieldnames=list(sid_review.COLUMNS), lineterminator="\r\n")
        writer.writeheader()
        writer.writerows(out)
        path.write_bytes(("﻿" + buf.getvalue()).encode("utf-8"))
        return path

    def classes(self, key):
        return next(c for c in sid_db2.shipped_categories(self.lua) if c["key"] == key)["classes"]

    def ingest(self, sheet, *extra):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = logs.main(["ingest", "--bundle", str(self.bundle), "--csv", str(sheet),
                              "--date", DATE, "--categories", str(self.lua),
                              "--decisions", str(self.decisions)] + list(extra))
        return code, out.getvalue()

    def state(self):
        files = sorted(p for p in self.root.rglob("*") if p.is_file() and p.name != "filled.csv")
        return {str(p.relative_to(self.root)): p.read_bytes() for p in files}


class ReadSheetTests(Bundle, unittest.TestCase):
    def test_reads_the_bundle_sheet_with_its_bom(self):
        self.assertEqual(list(self.rows[0].keys()), list(sid_review.COLUMNS))
        self.assertEqual(self.rows[0]["row_id"], "R0001")
        self.assertFalse(self.rows[0]["row_id"].startswith("﻿"))

    def test_reads_a_sheet_saved_without_bom_or_crlf(self):
        path = self.root / "plain.csv"
        path.write_text((self.bundle / "REVIEW.csv").read_text(encoding="utf-8-sig")
                        .replace("\r\n", "\n"), encoding="utf-8")
        self.assertEqual(sid_review.read_sheet(path), self.rows)

    def test_a_sheet_missing_a_column_is_an_error(self):
        path = self.root / "bad.csv"
        path.write_text("row_id,spell_id,type\r\nR0001,114051,deletion\r\n", encoding="utf-8")
        with self.assertRaises(ValueError) as cm:
            sid_review.read_sheet(path)
        self.assertIn("decision", str(cm.exception))


class ValidateTests(Bundle, unittest.TestCase):
    def check(self, path):
        return sid_review.ingest(self.rows, sid_review.read_sheet(path), self.shipped)

    def test_blank_decisions_are_pending_and_values_are_read(self):
        dele, add = self.row("deletion", 114051), self.row("correction-add", 114052)
        result = self.check(self.filled({dele["row_id"]: "r", add["row_id"]: "Approve"}))
        ruled = {(r["type"], int(r["spell_id"])): (d, t) for r, d, t in result.ruled}
        self.assertEqual(ruled, {("deletion", 114051): ("reject", ""),
                                 ("correction-add", 114052): ("approve", "offensiveCDs")})
        self.assertEqual(sorted(result.pending),
                         sorted(r["row_id"] for r in self.rows
                                if r["row_id"] not in (dele["row_id"], add["row_id"])))

    def test_a_row_left_out_of_the_sheet_is_pending(self):
        add = self.row("addition", 900500)
        result = self.check(self.filled({}, drop=(add["row_id"],)))
        self.assertIn(add["row_id"], result.pending)

    def test_an_unknown_row_id_is_an_error_naming_it(self):
        ghost = dict(self.rows[0], row_id="R9999", decision="Approve")
        with self.assertRaises(sid_review.SheetError) as cm:
            self.check(self.filled({}, extra=[ghost]))
        self.assertIn("R9999", str(cm.exception))

    def test_a_mismatched_spell_id_or_type_is_an_error_listing_every_row(self):
        a, b = self.rows[0]["row_id"], self.rows[1]["row_id"]
        with self.assertRaises(sid_review.SheetError) as cm:
            self.check(self.filled({a: "A", b: "A"},
                                   edits={a: {"spell_id": "1"}, b: {"type": "addition"}}))
        self.assertIn(a, str(cm.exception))
        self.assertIn(b, str(cm.exception))
        self.assertEqual(len(cm.exception.problems), 2)

    def test_a_duplicated_row_id_is_an_error(self):
        with self.assertRaises(sid_review.SheetError) as cm:
            self.check(self.filled({}, extra=[dict(self.rows[0], decision="R")]))
        self.assertIn(self.rows[0]["row_id"], str(cm.exception))

    def test_an_unrecognised_decision_is_an_error(self):
        rid = self.rows[0]["row_id"]
        with self.assertRaises(sid_review.SheetError) as cm:
            self.check(self.filled({rid: "maybe"}))
        self.assertIn(rid, str(cm.exception))
        self.assertIn("maybe", str(cm.exception))

    def test_an_edited_category_may_be_a_key_or_a_label(self):
        add = self.row("addition", 900500)
        for text in ("offensiveCDs", "Offensive cooldowns", " offensive COOLDOWNS "):
            result = self.check(self.filled({add["row_id"]: "Y"},
                                            edits={add["row_id"]: {"proposed_category": text}}))
            self.assertEqual([t for _r, _d, t in result.ruled], ["offensiveCDs"], text)

    def test_an_unknown_edited_category_is_an_error(self):
        add = self.row("addition", 900500)
        with self.assertRaises(sid_review.SheetError) as cm:
            self.check(self.filled({add["row_id"]: "Y"},
                                   edits={add["row_id"]: {"proposed_category": "nowhere"}}))
        self.assertIn("nowhere", str(cm.exception))

    def test_a_token_category_is_not_a_spells_category(self):
        add = self.row("addition", 900500)
        with self.assertRaises(sid_review.SheetError):
            self.check(self.filled({add["row_id"]: "Y"},
                                   edits={add["row_id"]: {"proposed_category": "externals"}}))

    def test_a_deletion_takes_no_category(self):
        dele = self.row("deletion", 114051)
        with self.assertRaises(sid_review.SheetError):
            self.check(self.filled({dele["row_id"]: "Y"},
                                   edits={dele["row_id"]: {"proposed_category": "defensives"}}))


class RowKeyTests(unittest.TestCase):
    def test_row_key_shape(self):
        self.assertEqual(sid_propose.row_key(ASC_KEY, 114051, "deletion"),
                         ASC_KEY + "#114051#deletion")

    def test_a_proposal_is_ruled_once_every_row_is(self):
        p = proposals()[0]
        both = {ASC_KEY + "#114051#deletion": {"ruling": "reject"},
                ASC_KEY + "#114052#correction-add": {"ruling": "accept"}}
        self.assertTrue(sid_propose.is_ruled(p, both))
        self.assertTrue(sid_propose.is_ruled(p, {ASC_KEY: {"ruling": "accept"}}))
        one = {ASC_KEY + "#114051#deletion": {"ruling": "reject"}}
        self.assertFalse(sid_propose.is_ruled(p, one))
        self.assertFalse(sid_propose.is_ruled(p, {}))

    def test_a_ruled_row_is_not_asked_again(self):
        one = {ASC_KEY + "#114051#deletion": {"ruling": "reject"}}
        rows = sid_review.review_rows(proposals(), [], decisions=one)
        self.assertNotIn(("deletion", 114051), [(r["type"], r["spell_id"]) for r in rows])
        self.assertIn(("correction-add", 114052), [(r["type"], r["spell_id"]) for r in rows])
        self.assertEqual(rows[0]["row_id"], "R0001")

    def test_propose_drops_a_proposal_whose_rows_are_all_ruled(self):
        both = {ASC_KEY + "#114051#deletion": {"ruling": "reject"},
                ASC_KEY + "#114052#correction-add": {"ruling": "accept"}}
        kept = sid_propose._ordered(proposals(), both)
        self.assertNotIn(ASC_KEY, [sid_propose.proposal_key(p) for p in kept])
        self.assertEqual(len(kept), 2)


class IngestTests(Bundle, unittest.TestCase):
    def test_approve_the_add_reject_the_deletion_keeps_both_ids(self):
        dele, add = self.row("deletion", 114051), self.row("correction-add", 114052)
        code, out = self.ingest(self.filled({dele["row_id"]: "Reject", add["row_id"]: "Approve"}))
        self.assertEqual(code, 0)
        self.assertEqual(self.classes("offensiveCDs")["SHAMAN"], [114051, 114052])
        decisions = json.loads(self.decisions.read_text(encoding="utf-8"))
        self.assertEqual(decisions[ASC_KEY + "#114051#deletion"]["ruling"], "reject")
        self.assertEqual(decisions[ASC_KEY + "#114052#correction-add"]["ruling"], "accept")
        self.assertEqual(decisions[ASC_KEY + "#114052#correction-add"]["date"], DATE)
        self.assertEqual(len(decisions), 2)
        self.assertIn("1 approved, 1 rejected", out)
        self.assertIn("2 pending", out)
        self.assertIn("+114052", out)

    def test_approving_both_halves_is_the_replace(self):
        dele, add = self.row("deletion", 114051), self.row("correction-add", 114052)
        self.ingest(self.filled({dele["row_id"]: "A", add["row_id"]: "A"}))
        self.assertEqual(self.classes("offensiveCDs")["SHAMAN"], [114052])
        text = self.lua.read_bytes().decode("utf-8")
        # the legacy line becomes a class table; the new id's line says what it replaces
        self.assertIn("            SHAMAN = {\r\n                114052,  -- Ascendance; added from "
                      "the 2026-09-24 combat logs (SID); replaces 114051\r\n            },\r\n", text)
        self.assertEqual(text.count("\n"), text.count("\r\n"))

    def test_move_and_addition_honour_an_edited_category(self):
        move, add = self.row("move", 108271), self.row("addition", 900500)
        self.ingest(self.filled({move["row_id"]: "A", add["row_id"]: "A"},
                                edits={add["row_id"]: {"proposed_category": "Offensive cooldowns"}}))
        self.assertNotIn("SHAMAN", self.classes("defensives"))
        self.assertEqual(self.classes("offensiveCDs")["SHAMAN"], [114051, 108271, 900500])
        decisions = json.loads(self.decisions.read_text(encoding="utf-8"))
        entry = decisions[sid_propose.row_key(add["proposal_key"], 900500, "addition")]
        self.assertEqual((entry["ruling"], entry["category"]), ("move", "offensiveCDs"))

    def test_a_second_ingest_changes_nothing(self):
        dele, add = self.row("deletion", 114051), self.row("correction-add", 114052)
        sheet = self.filled({dele["row_id"]: "Reject", add["row_id"]: "Approve"})
        self.ingest(sheet)
        first = self.state()
        code, out = self.ingest(sheet)
        self.assertEqual(code, 0)
        self.assertEqual(self.state(), first)
        self.assertIn("0 line changes", out)

    def test_decisions_md_lists_the_rows(self):
        dele, add = self.row("deletion", 114051), self.row("correction-add", 114052)
        self.ingest(self.filled({dele["row_id"]: "Reject", add["row_id"]: "Approve"}))
        md = (self.bundle / "DECISIONS.md").read_text(encoding="utf-8")
        self.assertIn(dele["row_id"], md)
        self.assertIn(add["row_id"], md)
        self.assertIn("reject", md)
        self.assertIn("accept", md)
        self.assertNotIn("Player-", md)

    def test_an_unknown_row_id_fails_without_writing(self):
        before = self.state()
        ghost = dict(self.rows[0], row_id="R9999", decision="Approve")
        sheet = self.filled({self.rows[0]["row_id"]: "Approve"}, extra=[ghost])
        with self.assertRaises(SystemExit) as cm:
            self.ingest(sheet)
        self.assertIn("R9999", str(cm.exception.code))
        self.assertEqual(self.state(), before)
        self.assertFalse(self.decisions.exists())

    def test_a_bad_date_is_refused(self):
        with self.assertRaises(SystemExit):
            logs.main(["ingest", "--bundle", str(self.bundle), "--csv", str(self.filled({})),
                       "--date", "today", "--categories", str(self.lua),
                       "--decisions", str(self.decisions)])

    def test_nothing_ruled_writes_nothing_but_reports_pending(self):
        before = self.state()
        code, out = self.ingest(self.filled({}))
        self.assertEqual(code, 0)
        self.assertIn("0 approved, 0 rejected", out)
        self.assertIn("%d pending" % len(self.rows), out)
        self.assertEqual(self.state(), before)


class RecordManyTests(unittest.TestCase):
    def test_writes_once_sorted_crlf_and_keeps_other_entries(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "decisions.json"
            sid_decide.record(path, "a|b", "reject", date=DATE)
            sid_decide.record_many(path, {"z#1#addition": {"ruling": "accept", "reason": "",
                                                          "date": DATE, "category": "defensives"}})
            data = path.read_bytes()
            self.assertEqual(data.count(b"\n"), data.count(b"\r\n"))
            doc = json.loads(data.decode("utf-8"))
            self.assertEqual(list(doc), ["a|b", "z#1#addition"])

    def test_refuses_a_bad_entry(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "decisions.json"
            with self.assertRaises(ValueError):
                sid_decide.record_many(path, {"k": {"ruling": "maybe", "date": DATE}})
            self.assertFalse(path.exists())


class MultilineIngestTests(Bundle, unittest.TestCase):
    """`logs.py ingest` on the shipped layout (fixtures/Categories-multiline.lua, which lists the
    same SHAMAN ids the proposals above touch): a line per id, the name in the same-line comment."""

    FIXTURE = "Categories-multiline.lua"

    def test_the_replace_rewrites_one_id_line_and_a_second_ingest_changes_nothing(self):
        dele, add = self.row("deletion", 114051), self.row("correction-add", 114052)
        move, extra = self.row("move", 108271), self.row("addition", 900500)
        sheet = self.filled({dele["row_id"]: "A", add["row_id"]: "A", move["row_id"]: "A",
                             extra["row_id"]: "A"})
        before = self.lua.read_bytes().decode("utf-8")
        code, out = self.ingest(sheet)
        self.assertEqual(code, 0)
        text = self.lua.read_bytes().decode("utf-8")
        self.assertIn("            SHAMAN = {\r\n"
                      "                -- 999999,  -- commented out: not an entry\r\n"
                      "                114052,  -- %s; added from the 2026-09-24 combat logs (SID); "
                      "replaces 114051\r\n" % add["spell_name"], text)
        self.assertEqual(self.classes("offensiveCDs")["SHAMAN"], [114052, 108271])
        # the move empties defensives' SHAMAN table (it goes) and the addition makes a new one
        self.assertEqual(self.classes("defensives")["SHAMAN"], [900500])
        self.assertIn("                900500, -- %s; added from the 2026-09-24 combat logs (SID)"
                      % extra["spell_name"], text)
        self.assertNotIn("108271, -- Astral Shift", text)
        self.assertEqual(text.count("\n"), text.count("\r\n"))
        # every line outside the edited tables is byte-for-byte what it was
        self.assertIn("            -- Spirit Walk (58875) is Movement only (owner 2026-09-25)\r\n",
                      text)
        self.assertEqual(before.split("Cat.HARMFUL")[1], text.split("Cat.HARMFUL")[1])
        first = self.state()
        code, out = self.ingest(sheet)
        self.assertEqual(code, 0)
        self.assertEqual(self.state(), first)
        self.assertIn("0 line changes", out)


if __name__ == "__main__":
    unittest.main()