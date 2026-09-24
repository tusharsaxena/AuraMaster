"""Tests for sid_db2 (DB2 aura signals, specs, names, player pool, shipped categories, CastToAura).

Run: python3 -m unittest discover -s tools/spell-research -p 'test_*.py'

The AURA_SIGNALS constants are pinned twice. Here, against fixtures/db2/SpellEffect-test.csv, whose
first rows are real rows of build 12.1.0.69875 trimmed to the columns the tool reads. And once by
hand against the real cache (SID-4, step 6), recorded in the SID-4 commit body:

    sid_db2.aura_signals(<cache>/SpellEffect-12.1.0.69875.csv, {108271, 1719, 2825, 1850})

where Astral Shift 108271's only effect row is `Effect 6, EffectAura 87, EffectBasePointsF -40`
and must yield {"damage_taken_down"}.
"""

import io
import sys
import tempfile
import unittest
from contextlib import redirect_stderr
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import research  # noqa: E402
import sid_db2  # noqa: E402

DB2 = HERE / "fixtures" / "db2"
CHR_SPEC = DB2 / "ChrSpecialization-test.csv"
SPELL_NAME = DB2 / "SpellName-test.csv"
SPELL_EFFECT = DB2 / "SpellEffect-test.csv"
CATEGORIES = HERE / "fixtures" / "Categories.lua"
CAST_TO_AURA = HERE / "fixtures" / "CastToAura.lua"

ASCENDANCE = [114051, 114052, 147059, 1219480, 1252197]


class SpecMapTest(unittest.TestCase):
    def test_maps_spec_id_to_class_name_and_role(self):
        specs = sid_db2.load_spec_map(CHR_SPEC)
        self.assertEqual(specs[264], {"class": "SHAMAN", "name": "Restoration", "role": 1})
        self.assertEqual(specs[262], {"class": "SHAMAN", "name": "Elemental", "role": 2})
        self.assertEqual(specs[73], {"class": "WARRIOR", "name": "Protection", "role": 0})

    def test_a_quoted_description_with_commas_does_not_shift_columns(self):
        specs = sid_db2.load_spec_map(CHR_SPEC)
        self.assertEqual(specs[71]["name"], "Arms")
        self.assertEqual(specs[71]["class"], "WARRIOR")

    def test_every_row_is_kept(self):
        self.assertEqual(set(sid_db2.load_spec_map(CHR_SPEC)), {71, 72, 73, 262, 263, 264, 1444})


class AuraSignalsTest(unittest.TestCase):
    def signals(self, *spells):
        return sid_db2.aura_signals(SPELL_EFFECT, set(spells))

    def test_astral_shift_is_damage_taken_down(self):
        # The real row: Effect 6, EffectAura 87, EffectBasePointsF -40.
        self.assertEqual(self.signals(108271), {108271: {"damage_taken_down"}})

    def test_bloodlust_is_haste_up(self):
        self.assertEqual(self.signals(2825), {2825: {"haste_up"}})

    def test_dash_is_speed_up(self):
        self.assertEqual(self.signals(1850), {1850: {"speed_up"}})

    def test_recklessness_crit_spell_modifier_is_crit_up(self):
        # ADD_FLAT_MODIFIER (107) on SpellModOp 7 (CritChance), +20.
        self.assertEqual(self.signals(1719), {1719: {"crit_up"}})

    def test_absorb_damage_up_and_periodic_heal(self):
        self.assertEqual(self.signals(17, 31884, 61295),
                         {17: {"absorb"}, 31884: {"damage_up"}, 61295: {"periodic_heal"}})

    def test_transform_and_a_zero_haste_row(self):
        # 114051's MELEE_SLOW row has 0 base points: not an increase, so no haste_up.
        self.assertEqual(self.signals(114051, 114052),
                         {114051: {"transform"}, 114052: {"transform"}})

    def test_area_aura_effects_count(self):
        self.assertEqual(self.signals(900100), {900100: {
            "damage_taken_down", "stat_pct_up", "rating_up", "haste_up", "speed_up"}})

    def test_non_aura_effects_raid_difficulty_and_wrong_sign_rows_are_ignored(self):
        # 900200: a DUMMY effect and a raid-difficulty row. 900300: damage taken UP, damage done
        # DOWN and rating DOWN, none of which is a signal; only its crit row counts.
        self.assertEqual(self.signals(900200, 900300), {900200: set(), 900300: {"crit_up"}})

    def test_a_crit_spell_modifier_needs_positive_points(self):
        # 900400: ADD_FLAT_MODIFIER (107) on SpellModOp 7 with -10 and with 0: a crit penalty or
        # nothing, never crit_up.
        self.assertEqual(self.signals(900400), {900400: set()})

    def test_fractional_base_points_keep_their_sign(self):
        # 900500: MELEE_SLOW (193) +0.5 and MOD_DAMAGE_PERCENT_TAKEN (87) -0.5. Truncated to an
        # int both would be 0, and neither sign rule would pass.
        self.assertEqual(self.signals(900500), {900500: {"haste_up", "damage_taken_down"}})

    def test_only_requested_spells_are_returned_and_each_is_present(self):
        out = self.signals(108271, 424242)
        self.assertEqual(set(out), {108271, 424242})
        self.assertEqual(out[424242], set())

    def test_the_constant_table_names_only_known_signals(self):
        known = {"damage_taken_down", "absorb", "damage_up", "haste_up", "crit_up", "rating_up",
                 "stat_pct_up", "speed_up", "periodic_heal", "transform"}
        names = {signal for signal, _sign in sid_db2.AURA_SIGNALS.values()}
        names |= set(sid_db2.SPELL_MOD_SIGNALS.values())
        self.assertLessEqual(names, known)
        self.assertEqual(sid_db2.AURA_SIGNALS[87], ("damage_taken_down", -1))
        self.assertEqual(sid_db2.AURA_SIGNALS[69], ("absorb", 0))
        self.assertEqual(sid_db2.AURA_SIGNALS[193], ("haste_up", 1))
        self.assertEqual(sid_db2.AURA_SIGNALS[31][0], "speed_up")
        self.assertEqual(sid_db2.AURA_SIGNALS[8][0], "periodic_heal")
        self.assertEqual(sid_db2.APPLY_AURA_EFFECTS, frozenset({6, 35, 119, 128}))


class NamesTest(unittest.TestCase):
    def test_names_wraps_research_read_names(self):
        names = sid_db2.names(SPELL_NAME)
        self.assertEqual(names[108271], "Astral Shift")
        self.assertEqual(names[17], "Power Word: Shield")
        self.assertEqual(names[900300], "Fixture Vulnerability, Taken")
        self.assertEqual(names, research.read_names(SPELL_NAME))


class ShippedCategoriesTest(unittest.TestCase):
    def setUp(self):
        self.cats = sid_db2.shipped_categories(CATEGORIES)
        self.by_key = {c["key"]: c for c in self.cats}

    def test_only_spells_kind_categories_in_file_order(self):
        self.assertEqual([c["key"] for c in self.cats], ["defensives", "offensiveCDs", "hardCC"])

    def test_a_commented_out_category_is_not_read(self):
        self.assertNotIn("notACategory", self.by_key)

    def test_labels_and_aura_types(self):
        self.assertEqual(self.by_key["offensiveCDs"]["label"], "Offensive cooldowns")
        self.assertEqual(self.by_key["defensives"]["aura"], "BUFF")
        self.assertEqual(self.by_key["offensiveCDs"]["aura"], "BUFF")
        self.assertEqual(self.by_key["hardCC"]["aura"], "DEBUFF")
        self.assertEqual(self.by_key["hardCC"]["label"], "Hard CC (loss of control)")

    def test_class_lines_with_trailing_comments_and_commented_lines(self):
        self.assertEqual(self.by_key["offensiveCDs"]["classes"],
                         {"WARRIOR": [1719, 107574], "SHAMAN": [114051]})
        self.assertEqual(self.by_key["defensives"]["classes"],
                         {"WARRIOR": [871, 12975], "SHAMAN": [108271]})
        self.assertEqual(self.by_key["hardCC"]["classes"],
                         {"WARRIOR": [5246, 132168], "SHAMAN": [51514, 118905]})

    def test_record_shape(self):
        for cat in self.cats:
            self.assertEqual(set(cat), {"key", "label", "aura", "classes"})

    def test_the_real_file_parses_and_ascendance_is_listed(self):
        real = HERE.parent.parent / "defaults" / "Categories.lua"
        cats = {c["key"]: c for c in sid_db2.shipped_categories(real)}
        self.assertIn(114051, cats["offensiveCDs"]["classes"]["SHAMAN"])
        self.assertEqual(cats["hardCC"]["aura"], "DEBUFF")
        self.assertEqual(cats["defensives"]["aura"], "BUFF")
        # Every id research.py's own reader sees is in exactly one class line here.
        ours = sorted(i for c in cats.values() for ids in c["classes"].values() for i in ids)
        theirs = sorted(r["id"] for r in research.read_shipped_named(real))
        self.assertEqual(ours, theirs)

    def test_a_spells_category_without_its_own_table_is_skipped(self):
        # "noTable" says kind = "spells" but has no spells({ ... }) before the next category's
        # key; the next spells block belongs to "withTable" and must not be read as noTable's.
        text = CATEGORIES.read_text(encoding="utf-8").replace(
            '        key = "offensiveCDs", kind = "spells"',
            '        key = "noTable", kind = "spells", label = "No table of its own",\n'
            '    },\n'
            '    {\n'
            '        key = "offensiveCDs", kind = "spells"', 1)
        self.assertIn("noTable", text)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "Categories.lua"
            path.write_text(text, encoding="utf-8")
            cats = sid_db2.shipped_categories(path)
        self.assertEqual([c["key"] for c in cats], ["defensives", "offensiveCDs", "hardCC"])
        self.assertEqual(cats[1]["classes"], {"WARRIOR": [1719, 107574], "SHAMAN": [114051]})

    def test_missing_file_is_empty(self):
        self.assertEqual(sid_db2.shipped_categories(HERE / "no-such-file.lua"), [])


class CastToAuraTest(unittest.TestCase):
    def test_rewrites_and_choices_are_merged(self):
        cands = sid_db2.cast_aura_candidates(CAST_TO_AURA)
        self.assertEqual(cands[114050], ASCENDANCE)
        self.assertEqual(cands[172], [146739])
        self.assertEqual(cands[98008], [98007])
        self.assertEqual(cands[53], [245689, 319065])
        self.assertEqual(set(cands), {172, 98008, 53, 114050, 900050, 900060, 900070})

    def test_aura_to_family_maps_every_aura_to_its_siblings(self):
        family = sid_db2.aura_to_family(sid_db2.cast_aura_candidates(CAST_TO_AURA))
        self.assertEqual(family[114052], set(ASCENDANCE))
        self.assertEqual(family[114051], set(ASCENDANCE))
        self.assertEqual(family[98007], {98007})
        # An aura two casts can land is in both families (the union).
        self.assertEqual(family[146739], {146739, 900051})
        # Its larger family is read first and a smaller one after: an overwrite would lose
        # 900062 and 900063.
        self.assertEqual(family[900061], {900061, 900062, 900063, 900071})
        self.assertEqual(family[900062], {900061, 900062, 900063})
        self.assertEqual(family[900071], {900061, 900071})
        self.assertNotIn(114050, family)

    def test_the_real_file_has_the_ascendance_family(self):
        real = HERE.parent.parent / "defaults" / "CastToAura.lua"
        self.assertEqual(sid_db2.cast_aura_candidates(real)[114050], ASCENDANCE)


def write_csv(path, header, rows):
    path.write_text("\n".join([header] + rows) + "\n", encoding="utf-8")


class PlayerPoolTest(unittest.TestCase):
    def test_player_pool_is_research_build_pool_ids(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            write_csv(d / "SkillLine.csv", "ID,DisplayName_lang,CategoryID,ParentSkillLineID",
                      ["375,Shaman,7,0", "999,Cooking,9,0"])
            write_csv(d / "SkillLineAbility.csv", "ID,Spell,ClassMask,SkillLine",
                      ["1,108271,0,375", "2,2825,64,0", "3,818,0,999"])
            write_csv(d / "SpecializationSpells.csv", "ID,SpellID,SpecID", ["1,61295,264"])
            write_csv(d / "TraitDefinition.csv", "ID,SpellID,VisibleSpellID", ["5,114050,114051"])
            write_csv(d / "TraitNodeEntry.csv", "ID,TraitDefinitionID", ["7,5"])
            write_csv(d / "TraitNodeXTraitNodeEntry.csv", "ID,TraitNodeID,TraitNodeEntryID",
                      ["1,9,7"])
            write_csv(d / "TraitNode.csv", "ID,TraitTreeID", ["9,11"])
            write_csv(d / "TraitTreeLoadout.csv", "ID,TraitTreeID,ChrSpecializationID", ["1,11,264"])
            cache = {p.stem: p for p in d.glob("*.csv")}
            cache["ChrSpecialization"] = CHR_SPEC
            with redirect_stderr(io.StringIO()):
                pool = sid_db2.player_pool(cache)
        self.assertEqual(pool, {108271, 2825, 61295, 114050, 114051})


class OpenDb2Test(unittest.TestCase):
    def fill(self, cache, build):
        for table, _why in research.TABLES:
            (cache / ("%s-%s.csv" % (table, build))).write_text("ID\n", encoding="utf-8")

    def test_defaults_to_the_newest_build_in_the_cache(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache = Path(tmp)
            self.fill(cache, "12.1.0.9999")
            self.fill(cache, "12.1.0.10000")   # newer, though it sorts first as a string
            with redirect_stderr(io.StringIO()):
                tables, build = sid_db2.open_db2(cache, None), sid_db2.newest_cached_build(cache)
            self.assertEqual(build, "12.1.0.10000")
            self.assertEqual(set(tables), {t for t, _w in research.TABLES})
            self.assertEqual(tables["SpellName"], cache / "SpellName-12.1.0.10000.csv")

    def test_an_explicit_build_wins(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache = Path(tmp)
            self.fill(cache, "12.1.0.9999")
            self.fill(cache, "12.1.0.10000")
            with redirect_stderr(io.StringIO()):
                tables = sid_db2.open_db2(cache, "12.1.0.9999")
            self.assertEqual(tables["SpellEffect"], cache / "SpellEffect-12.1.0.9999.csv")

    def test_an_empty_cache_falls_back_to_resolve_build(self):
        calls = []
        real_resolve, real_fetch = research.resolve_build, research.fetch_table

        def fake_resolve(explicit):
            calls.append(("resolve", explicit))
            return "12.1.0.1"

        def fake_fetch(table, build, cache_dir, refresh, replay_dir=None):
            calls.append(("fetch", table, build, refresh))
            return cache_dir / ("%s-%s.csv" % (table, build))

        research.resolve_build, research.fetch_table = fake_resolve, fake_fetch
        try:
            with tempfile.TemporaryDirectory() as tmp:
                tables = sid_db2.open_db2(Path(tmp), None)
        finally:
            research.resolve_build, research.fetch_table = real_resolve, real_fetch
        self.assertEqual(calls[0], ("resolve", None))
        self.assertIn(("fetch", "SpellName", "12.1.0.1", False), calls)
        self.assertEqual(len(tables), len(research.TABLES))


if __name__ == "__main__":
    unittest.main()
