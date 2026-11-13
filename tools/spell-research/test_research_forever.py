"""Tests for research.py's WoW Forever client (AM-FP03).

Run: python3 -m pytest -q tools/spell-research

The fixture CSVs under fixtures/forever/ are a few rows in the shape wago.tools exports for the
Forever build 1.60.1.70938 (product `wowf`). Nothing here touches the network.
"""

import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import research  # noqa: E402

FOREVER = HERE / "fixtures" / "forever"
RETAIL_ONLY = {"DEATHKNIGHT", "MONK", "DEMONHUNTER", "EVOKER"}


def forever_cache() -> dict:
    """{table: fixture path} for every Forever table; Talent/TalentTab included."""
    return {table: FOREVER / ("%s.csv" % table) for table, _why in research.tables_for("forever")}


def quiet(fn, *args, **kwargs):
    with redirect_stderr(io.StringIO()):
        return fn(*args, **kwargs)


class ForeverTablesTest(unittest.TestCase):
    def test_forever_tables(self):
        retail = [t for t, _w in research.tables_for("retail")]
        forever = [t for t, _w in research.tables_for("forever")]
        self.assertNotIn("SpecializationSpells", forever)
        self.assertNotIn("TraitTreeLoadout", forever)
        self.assertIn("Talent", forever)
        self.assertIn("TalentTab", forever)
        self.assertEqual(set(forever),
                         set(retail) - {"SpecializationSpells", "TraitTreeLoadout"}
                         | {"Talent", "TalentTab"})
        self.assertEqual(research.CLIENTS["forever"]["product"], "wowf")
        # Every table the fixture set carries is a Forever table, so the tests read real names.
        self.assertTrue(all(path.exists() for path in forever_cache().values()))

    def test_retail_default_unchanged(self):
        args = research.parse_args([])
        self.assertEqual(args.client, "retail")
        self.assertEqual(research.CLIENTS["retail"]["product"], "wow")
        self.assertIs(research.tables_for("retail"), research.TABLES)
        self.assertEqual(len(research.TABLES), 14)
        self.assertIs(research.CLIENTS["retail"]["sentinels"], research.SENTINELS)

        payload = json.dumps({"wow": [{"version": "12.1.5.1"}],
                              "wowf": [{"version": "1.60.1.70938"}]}).encode()
        real = research.http_get
        research.http_get = lambda url, accept="*/*": io.BytesIO(payload)
        try:
            self.assertEqual(quiet(research.resolve_build, None), "12.1.5.1")
            self.assertEqual(quiet(research.resolve_build, None, "wowf"), "1.60.1.70938")
            self.assertEqual(quiet(research.resolve_build, "9.9.9.9", "wowf"), "9.9.9.9")
        finally:
            research.http_get = real


class ForeverPoolTest(unittest.TestCase):
    def setUp(self):
        self.pool = research.build_pool_forever(forever_cache())

    def test_forever_pool_excludes_runes_and_pets(self):
        for spell in (6358,     # Pet - Succubus, ClassMask 0
                      900010,   # Pet - Generic, a hunter-masked row: the line drops it anyway
                      900020,   # a rune ability on the Frost line, named by "Engrave Gloves - ..."
                      900022, 900024,  # the engrave spells themselves, on Engraving 2851
                      900021,   # Runes 2853
                      900030, 23214,  # Mounts, including the paladin-masked row
                      900031,   # Companions
                      900040):  # a profession line
            self.assertNotIn(spell, self.pool, spell)
        self.assertEqual(self.pool[118], {"MAGE"})
        # A ClassMask-0 row on a class line takes the line's class (Arms 26 -> WARRIOR).
        self.assertEqual(self.pool[12282], {"WARRIOR"})

    def test_forever_rune_fence(self):
        # A talent rank keeps its name's rune at bay: a talent is the class's own (owner ruling 3).
        self.assertEqual(self.pool[900060], {"MAGE"})
        # The class fence: the rune "Fixture Rune" is the mage's, so a druid spell of that name stays.
        self.assertEqual(self.pool[900026], {"DRUID"})
        fence = research.load_forever_fence(forever_cache())
        self.assertEqual(fence.rune_classes["Fixture Rune"], {"MAGE"})
        self.assertIn(900090, fence.dropped_only)    # Claw, on a Pet - line only
        self.assertNotIn(900091, fence.dropped_only)

    def test_forever_class_lines(self):
        lines = quiet(research.load_forever_class_lines, forever_cache())
        self.assertEqual(lines[26], "WARRIOR")
        self.assertEqual(lines[267], "PALADIN")   # Protection, the paladin one
        self.assertEqual(lines[355], "WARLOCK")   # its -1 row casts no vote
        for line in (205, 270, 2851, 2853, 777, 778, 164):
            self.assertNotIn(line, lines)

    def test_forever_talent_pool(self):
        # ClassID 0 (as every measured row is): the class comes from TalentTab 161's ClassMask.
        for spell in (12289, 12668, 23695):
            self.assertEqual(self.pool[spell], {"WARRIOR"})
        # A non-zero ClassID wins.
        for spell in (900060, 900061):
            self.assertEqual(self.pool[spell], {"MAGE"})

    def test_forever_pool_has_no_retail_only_class(self):
        for spell, tokens in self.pool.items():
            self.assertFalse(tokens & RETAIL_ONLY, spell)
        self.assertEqual(self.pool[900041], set(research.FOREVER_CLASS_TOKENS))

    def test_forever_rank_closure(self):
        cache = forever_cache()
        names = research.read_names(cache["SpellName"])
        families = research.read_spell_families(cache["SpellClassOptions"])
        class_of = research.family_class_of(self.pool, families)
        out = research.rank_closure(self.pool, names, class_of)
        self.assertIs(out, self.pool)
        for rank in (118, 12824, 12825, 12826):
            self.assertEqual(out[rank], {"MAGE"}, rank)
        self.assertNotIn(13323, out)    # the NPC copy: family 0, no class
        self.assertNotIn(900070, out)   # a "Polymorph" in the warlock family: not the same class
        self.assertEqual(out[6213], {"WARLOCK"})  # Fear rank 2

    def test_forever_rank_closure_respects_the_fence(self):
        cache = forever_cache()
        names = research.read_names(cache["SpellName"])
        families = research.read_spell_families(cache["SpellClassOptions"])
        class_of = research.family_class_of(self.pool, families)
        self.assertEqual(class_of[900090], {"HUNTER"})
        fence = research.load_forever_fence(cache)
        out = research.rank_closure(dict(self.pool), names, class_of, fence)
        self.assertNotIn(900090, out)   # the pet's Claw: same name and family as hunter Claw 900091
        self.assertNotIn(900025, out)   # a mage-family "Fixture Mage Talent" that is a rune's name
        self.assertNotIn(900023, out)   # the rune's own family copy
        # Without the fence both would join: the fixture holds the shape the real export has.
        bare = research.rank_closure(dict(self.pool), names, class_of)
        self.assertIn(900090, bare)
        self.assertIn(900025, bare)


class ForeverDeriveTest(unittest.TestCase):
    def test_forever_derive_passes_the_forever_gate(self):
        result = quiet(research.derive, forever_cache(), "forever")
        self.assertEqual(research.check_sentinels(result, research.SENTINELS_FOREVER), [])
        hard = result["buckets"]["hardCC"]
        self.assertEqual(hard[12826]["source"], "rank")
        self.assertEqual(hard[12826]["class"], "MAGE")
        self.assertEqual(hard[118]["source"], "pool")
        self.assertNotIn(13323, hard)
        self.assertEqual(result["rankClosureAdded"], 5)  # 12824-12826, Fear 6213, 900081
        # No rune ability reaches a bucket: not the one on the class line, nor a same-name rank.
        root = result["buckets"]["ccRoot"]
        for spell in (900020, 900023, 900025):
            self.assertNotIn(spell, root, spell)
        self.assertIn(122, root)

    def test_the_forever_gate_matches_ids(self):
        result = quiet(research.derive, forever_cache(), "forever")
        del result["buckets"]["hardCC"][118]
        # Polymorph's other ranks are still there; the gate wants rank 1 itself.
        self.assertEqual(research.check_sentinels(result, research.SENTINELS_FOREVER),
                         ["hardCC: Polymorph (118)"])
        # And the Retail gate, by name, is the default and fails here as it should.
        self.assertTrue(research.check_sentinels(result))

    def test_forever_cast_aura_uses_the_forever_pool(self):
        result = quiet(research.derive_cast_aura, forever_cache(), "forever")
        self.assertEqual(result["pool"], len(research.build_pool_forever(forever_cache())) + 5)


class ForeverCliTest(unittest.TestCase):
    """A Forever bundle written from the fixtures, then replayed offline through main()."""

    def write_bundle(self, root: Path) -> Path:
        bundle = root / "2026-11-14-forever"
        cache = forever_cache()
        result = quiet(research.derive, cache, "forever")
        quiet(research.write_bundle, bundle, "2026-11-14", "1.60.1.70938", cache, result, "",
              "fixture", "forever")
        return bundle

    def test_bundle_records_the_client(self):
        with tempfile.TemporaryDirectory() as tmp:
            bundle = self.write_bundle(Path(tmp))
            derived = json.loads((bundle / "derived.json").read_text(encoding="utf-8"))
            self.assertEqual(derived["client"], "forever")
            self.assertEqual(derived["rankClosureAdded"], 5)
            sources = (bundle / "SOURCES.md").read_text(encoding="utf-8")
            self.assertIn("| Client | `forever` (WoW Forever, wago product `wowf`) |", sources)
            self.assertIn("`Talent`", sources)
            self.assertNotIn("`SpecializationSpells`", sources)
            self.assertTrue((bundle / "raw" / "TalentTab.csv.gz").exists())
            self.assertFalse((bundle / "raw" / "TraitTreeLoadout.csv.gz").exists())

    def test_replay_runs_offline_under_client_forever(self):
        with tempfile.TemporaryDirectory() as tmp:
            bundle = self.write_bundle(Path(tmp))
            out, err = io.StringIO(), io.StringIO()
            with redirect_stdout(out), redirect_stderr(err):
                code = research.main(["--client", "forever", "--replay", str(bundle), "--diff",
                                      "--categories", str(HERE / "fixtures" / "Categories.lua")])
            self.assertEqual(code, 0, err.getvalue())
            self.assertIn("Coverage gate: PASS (7 forever sentinels)", err.getvalue())

    def test_replay_refuses_the_other_client(self):
        with tempfile.TemporaryDirectory() as tmp:
            bundle = self.write_bundle(Path(tmp))
            with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as caught:
                research.main(["--replay", str(bundle), "--diff"])
            self.assertIn("--client forever", str(caught.exception))


if __name__ == "__main__":
    unittest.main()
