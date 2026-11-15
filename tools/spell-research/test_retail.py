"""Tests for tools/spell-research/retail.py and the seed-file shape it reads and writes (issue #27).

Every case works on a small seed file in a temp dir, with a stand-in for the build's facts; the two
repo cases at the end read the real defaults/Categories_Retail.lua and retail_rulings.json, so a
re-derive that leaves a key unruled, or a seed line whose aura type drifts, fails here.
"""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import research  # noqa: E402
import retail  # noqa: E402
import sid_db2  # noqa: E402
import sid_decide  # noqa: E402
from sid_seeds import Candidate  # noqa: E402

DEFS = """local _, NS = ...
Cat.HELPFUL = {
    {
        key = "defensives", kind = "spells", label = "Defensive cooldowns",
    },
    {
        key = "offensiveCDs", kind = "spells", label = "Offensive cooldowns",
    },
}
Cat.HARMFUL = {
    {
        key = "hardCC", kind = "spells", label = "CC Loss of Control",
    },
}
"""

SEEDS = """local _, NS = ...
local SEEDS = {}
local function seed(key, _auraType, list) SEEDS[key] = list end

-- Defensive cooldowns (Cat.HELPFUL)
seed("defensives", "HELPFUL", {
    WARRIOR = {
        871,    -- Shield Wall
    },
})

-- Offensive cooldowns (Cat.HELPFUL)
seed("offensiveCDs", "HELPFUL", {
    WARRIOR = {
        1719,   -- Recklessness
        107574, -- Avatar; context after the name
    },
})

-- CC Loss of Control (Cat.HARMFUL)
seed("hardCC", "HARMFUL", {
    WARRIOR = {
        5246,    -- Intimidating Shout
    },
})
"""


class FakeDB:
    def __init__(self, names, appliers=()):
        self.names = names
        self.appliers = set(appliers)

    def rank(self, _spell):
        return ""

    def notes(self, _spell):
        return []


def write_pair(root: Path, seeds: str = SEEDS) -> Path:
    (root / "Categories.lua").write_text(DEFS, encoding="utf-8")
    path = root / "Categories_Retail.lua"
    path.write_bytes(seeds.replace("\n", "\r\n").encode("utf-8"))
    return path


def doc_with(candidates=(), flags=(), build="12.1.5.70783"):
    return {"build": build, "date": "2026-11-15", "candidates": [c.to_json() for c in candidates],
            "flags": list(flags), "reachSize": 0, "previous": {}, "poolDelta": {}}


class SeedShapeTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = write_pair(Path(self.tmp.name))

    def tearDown(self):
        self.tmp.cleanup()

    def test_reader_takes_key_aura_and_label(self):
        cats = research.read_categories_file(self.path)
        self.assertEqual([(c["key"], c["aura"], c["label"]) for c in cats],
                         [("defensives", "HELPFUL", "Defensive cooldowns"),
                          ("offensiveCDs", "HELPFUL", "Offensive cooldowns"),
                          ("hardCC", "HARMFUL", "CC Loss of Control")])
        self.assertEqual([r["comment"] for r in cats[1]["records"]], ["Recklessness", "Avatar"])

    def test_sid_db2_takes_the_aura_from_the_seed_line(self):
        cats = {c["key"]: c for c in sid_db2.shipped_categories(self.path)}
        self.assertEqual(cats["hardCC"]["aura"], "DEBUFF")
        self.assertEqual(cats["defensives"]["aura"], "BUFF")
        self.assertEqual(cats["offensiveCDs"]["classes"], {"WARRIOR": [1719, 107574]})

    def test_read_shipped_named_reads_every_seed_list(self):
        self.assertEqual([r["id"] for r in research.read_shipped_named(self.path)], [871, 1719, 107574, 5246])

    def test_writer_inserts_into_a_seed_list_with_its_provenance(self):
        lua = sid_decide._Lua(self.path.read_bytes().decode("utf-8"), {12975: "Last Stand"}, "2026-11-15",
                              "added from the 2026-11-15 wago.tools re-validation (12.1.5.70783)")
        self.assertEqual(lua.insert("defensives", "WARRIOR", [12975]), [12975])
        text = lua.text()
        self.assertIn("12975,  -- Last Stand; added from the 2026-11-15 wago.tools re-validation (12.1.5.70783)\r\n",
                      text)
        self.assertNotIn("combat logs", text)

    def test_read_seeds_refuses_an_aura_type_that_disagrees(self):
        bad = write_pair(Path(self.tmp.name), SEEDS.replace('seed("hardCC", "HARMFUL"', 'seed("hardCC", "HELPFUL"'))
        with self.assertRaises(SystemExit):
            retail.read_seeds(bad)


class RulingTest(unittest.TestCase):
    def test_candidate_and_flag_keys_take_their_own_rulings(self):
        rulings = {}
        retail.set_ruling(rulings, "offensiveCDs:191634", "accept", "Stormkeeper")
        retail.set_ruling(rulings, "shipped:no-aura:hardCC:5246", "keep", "known")
        self.assertEqual(rulings["offensiveCDs:191634"]["ruling"], "accept")
        for key, ruling in (("offensiveCDs:1", "keep"), ("shipped:no-aura:hardCC:1", "accept"),
                            ("shipped:bogus:hardCC:1", "keep"), ("nosuch:1", "accept")):
            with self.assertRaises(SystemExit):
                retail.set_ruling(rulings, key, ruling, "why")
        with self.assertRaises(SystemExit):
            retail.set_ruling(rulings, "offensiveCDs:1", "accept", "two\nlines")


class FlagTest(unittest.TestCase):
    def test_each_kind_is_raised_once_per_slot(self):
        cats = [{"key": "offensiveCDs", "records": [
            {"id": 1, "class": "WARRIOR", "comment": "Gone"},
            {"id": 2, "class": "WARRIOR", "comment": "Cast Only"},
            {"id": 3, "class": "WARRIOR", "comment": "Old Name"},
            {"id": 4, "class": "WARRIOR", "comment": "Fine"},
            {"id": 5, "class": "WARRIOR", "comment": "Fine Too"}]}]
        db = FakeDB({2: "Cast Only", 3: "New Name", 4: "Fine", 5: "Fine Too"}, appliers={3, 4, 5})
        flags = retail.shipped_flags(db, cats, reach={4}, prev_reach={4, 5})
        self.assertEqual([f["key"] for f in flags], [
            "shipped:unnamed:offensiveCDs:1", "shipped:no-aura:offensiveCDs:2",
            "shipped:renamed:offensiveCDs:3", "shipped:dropped:offensiveCDs:5"])

    def test_no_previous_reach_raises_no_dropped_flag(self):
        cats = [{"key": "offensiveCDs", "records": [{"id": 5, "class": "WARRIOR", "comment": "Fine"}]}]
        self.assertEqual(retail.shipped_flags(FakeDB({5: "Fine"}, {5}), cats, set(), None), [])


class HandTest(unittest.TestCase):
    def test_hand_candidates_skip_shipped_and_list_missing(self):
        missing = []
        entries = (("defensives", 10, "DRUID", "a"), ("defensives", 11, "DRUID", "b"),
                   ("defensives", 12, "DRUID", "c"))
        db = FakeDB({10: "Ten", 11: "Eleven"}, appliers={10, 11})
        out = retail.hand_candidates(db, {"BUFF": {11}}, missing, entries)
        self.assertEqual([(c.key, c.source) for c in out], [("defensives:10", "hand")])
        self.assertEqual([m["id"] for m in missing], [12])


class ApplyTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = write_pair(Path(self.tmp.name))
        self.add = Candidate(12975, "defensives", "WARRIOR", "db2-effect", None, "Last Stand", "")
        self.cc = Candidate(132168, "hardCC", "WARRIOR", "bridge", None, "Shockwave", "")
        self.flag = {"key": "shipped:no-aura:offensiveCDs:107574", "kind": "no-aura", "category": "offensiveCDs",
                     "id": 107574, "class": "WARRIOR", "name": "Avatar", "comment": "Avatar"}

    def tearDown(self):
        self.tmp.cleanup()

    def rulings(self, **over):
        out = {"defensives:12975": {"ruling": "accept", "reason": "r"},
               "hardCC:132168": {"ruling": "reject", "reason": "r"},
               "shipped:no-aura:offensiveCDs:107574": {"ruling": "remove", "reason": "r"}}
        out.update(over)
        return out

    def test_refuses_while_anything_is_unruled(self):
        doc = doc_with([self.add, self.cc], [self.flag])
        rulings = self.rulings()
        del rulings["hardCC:132168"]
        with self.assertRaises(SystemExit):
            retail.apply_bundle(doc, rulings, self.path, "2026-11-15")
        self.assertNotIn("12975", self.path.read_text(encoding="utf-8"))

    def test_inserts_accepts_removes_ruled_flags_and_is_idempotent(self):
        doc = doc_with([self.add, self.cc], [self.flag])
        changes = retail.apply_bundle(doc, self.rulings(), self.path, "2026-11-15")
        self.assertEqual(changes, ["defensives WARRIOR: +12975", "offensiveCDs WARRIOR: -107574"])
        text = self.path.read_bytes().decode("utf-8")
        self.assertIn("12975,  -- Last Stand; added from the 2026-11-15 wago.tools re-validation", text)
        self.assertNotIn("107574", text)
        self.assertNotIn("132168", text)
        self.assertTrue(text.count("\r\n") == text.count("\n"), "CRLF kept")
        self.assertEqual(retail.apply_bundle(doc, self.rulings(), self.path, "2026-11-15"), [])

    def test_keep_leaves_a_flagged_id_alone(self):
        doc = doc_with([], [self.flag])
        rulings = {"shipped:no-aura:offensiveCDs:107574": {"ruling": "keep", "reason": "r"}}
        self.assertEqual(retail.apply_bundle(doc, rulings, self.path, "2026-11-15"), [])

    def test_refuses_an_accept_another_category_of_the_aura_type_holds(self):
        dup = Candidate(1719, "defensives", "WARRIOR", "db2-effect", None, "Recklessness", "")
        doc = doc_with([dup])
        with self.assertRaises(SystemExit):
            retail.apply_bundle(doc, {"defensives:1719": {"ruling": "accept", "reason": "r"}},
                                self.path, "2026-11-15")


class ReportTest(unittest.TestCase):
    def test_unruled_keys_are_listed_first(self):
        c = Candidate(12975, "defensives", "WARRIOR", "db2-effect", None, "Last | Stand", "")
        md = retail.format_rulings_md(doc_with([c]), {}, "2026-11-15")
        self.assertIn("## Unruled — 1\n\n- `defensives:12975`", md)
        self.assertIn("Last \\| Stand", md)


SEEDS_REAL = HERE.parent.parent / "defaults" / "Categories_Retail.lua"
BUNDLES = retail.retail_bundles(HERE.parent.parent / "docs" / "spell-research")


class RepoTest(unittest.TestCase):
    def test_the_real_seed_file_reads_with_every_aura_type_matching(self):
        cats = retail.read_seeds(SEEDS_REAL)
        self.assertEqual(sorted(c["key"] for c in cats), sorted(retail.CATEGORY_KEYS))

    @unittest.skipUnless(BUNDLES, "no retail bundle under docs/spell-research")
    def test_the_newest_bundle_is_fully_ruled(self):
        doc = json.loads((BUNDLES[-1] / "candidates.json").read_text(encoding="utf-8"))
        self.assertEqual(retail.unruled_keys(doc, retail.load_rulings(retail.RULINGS_PATH)), [])


if __name__ == "__main__":
    unittest.main()
