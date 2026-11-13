"""Tests for forever.py, WoW Forever's seed lists for every `spells` category (AM-FP04).

Run: python3 -m pytest -q tools/spell-research

fixtures/forever_categories/ is a few dozen Forever spells in the shape wago.tools exports for build
1.60.1.70938 (product `wowf`), plus the three EXTRA_TABLES and a small Retail Categories.lua whose
entries are mapped by name. Nothing here touches the network.
"""

import gzip
import io
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import forever  # noqa: E402
import research  # noqa: E402
import sid_db2  # noqa: E402

FIXTURES = HERE / "fixtures" / "forever_categories"
RETAIL_LUA = FIXTURES / "Categories.lua"
BUILD = "1.60.1.70938"
DATE = "2026-11-14"
RETAIL_ONLY = {"DEATHKNIGHT", "MONK", "DEMONHUNTER", "EVOKER"}
LUA = shutil.which("lua") or shutil.which("lua5.1")
LUAC = shutil.which("luac") or shutil.which("luac5.1")


def fixture_tables() -> dict:
    tables = research.tables_for("forever") + forever.EXTRA_TABLES
    return {table: FIXTURES / ("%s.csv" % table) for table, _why in tables}


def quiet(fn, *args, **kwargs):
    with redirect_stderr(io.StringIO()):
        return fn(*args, **kwargs)


def run_main(argv) -> tuple[int, str]:
    err = io.StringIO()
    with redirect_stderr(err):
        code = forever.main(argv)
    return code, err.getvalue()


def make_bundle(root: Path) -> Path:
    """A research.py --client forever bundle of the fixtures, with the EXTRA_TABLES in raw/."""
    bundle = root / "2026-11-14-forever"
    cache = {t: FIXTURES / ("%s.csv" % t) for t, _w in research.tables_for("forever")}
    result = quiet(research.derive, cache, "forever")
    quiet(research.write_bundle, bundle, DATE, BUILD, cache, result, "", "fixture", "forever")
    for table, _why in forever.EXTRA_TABLES:
        with (FIXTURES / ("%s.csv" % table)).open("rb") as src, \
                gzip.open(bundle / "raw" / ("%s.csv.gz" % table), "wb") as dst:
            shutil.copyfileobj(src, dst)
    return bundle


def candidate(spell, category, klass="WARRIOR", name="Fixture", source="db2-effect"):
    return forever.Candidate(spell, category, klass, source, None, name, "")


class DeriveTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.doc = quiet(forever.derive_bundle, fixture_tables(), BUILD, DATE, RETAIL_LUA)
        cls.cands = [forever.Candidate.from_json(c) for c in cls.doc["candidates"]]
        cls.by_key = {c.key: c for c in cls.cands}

    def test_spell_categories_match_the_shipped_file(self):
        shipped = sid_db2.shipped_categories(research.repo_root() / "defaults" / "Categories.lua")
        self.assertEqual(tuple((c["key"], c["aura"]) for c in shipped), forever.SPELL_CATEGORIES)

    def test_forever_maps_through_trigger(self):
        # Retail's "Fixture Flare" maps to Forever 910001, which applies no aura and triggers 910002:
        # the candidate is the AURA, with the cast it came through.
        flare = self.by_key["utility:910002"]
        self.assertEqual((flare.source, flare.origin, flare.via, flare.klass),
                         ("name-map", 199483, 910001, "HUNTER"))
        self.assertEqual(flare.name, "Fixture Flare Effect")
        self.assertFalse([c for c in self.cands if c.id == 910001])
        # And directly, through the documented signature.
        db = forever.ForeverDB(fixture_tables())
        pool = quiet(forever.forever_pool, db)
        cats, names = forever.read_retail(RETAIL_LUA)
        mapped = forever.map_retail_entries(cats, names, db, pool)
        self.assertIn(("utility", 910002, 910001), [(c.category, c.id, c.via) for c in mapped])

    def test_forever_maps_every_rank(self):
        for key, rank in (("groupBuffs:6673", "Rank 1"), ("groupBuffs:5242", "Rank 2"),
                          ("healing:139", "Rank 1"), ("healing:6074", "Rank 2")):
            self.assertEqual(self.by_key[key].rank, rank, key)
            self.assertEqual(self.by_key[key].source, "name-map", key)
        # An NPC copy in the warrior family shares Shield Wall's name: a candidate with no rank text,
        # left for the ruling to reject (forever.py never accepts on a name).
        self.assertEqual(self.by_key["defensives:910060"].rank, "")

    def test_forever_class_keys(self):
        allowed = set(research.FOREVER_CLASS_TOKENS) | {"ALL"}
        self.assertEqual(allowed, forever.CLASS_KEYS)
        self.assertEqual(len(forever.CLASS_KEYS), 10)
        for c in self.cands:
            self.assertIn(c.klass, allowed, c.key)
            self.assertNotIn(c.klass, RETAIL_ONLY, c.key)
        # A Retail-only class's entry maps to nothing, and says why.
        self.assertIn({"category": "defensives", "class": "MONK", "retail": 115203,
                       "name": "Fortifying Brew", "why": "a Retail-only class"}, self.doc["unmapped"])
        # A ClassMask -1 spell reaches all nine classes and is emitted under ALL.
        self.assertEqual(self.by_key["movement:910050"].klass, "ALL")
        self.assertIn("passive", self.by_key["movement:910050"].notes)

    def test_unmapped_name(self):
        self.assertIn({"category": "defensives", "class": "HUNTER", "retail": 186265,
                       "name": "Aspect of the Turtle", "why": "no Forever spell of that name for the class"},
                      self.doc["unmapped"])

    def test_db2_rules(self):
        for key in ("stances:768", "stances:783", "stances:1784", "offensiveCDs:12042",
                    "support:10060", "groupBuffs:23028", "movement:1044", "racials:20600"):
            self.assertEqual(self.by_key[key].source, "db2-effect", key)
        # Devotion Aura is an effect-35 party aura: db2 agrees with the name map.
        self.assertIn("also db2-effect", self.by_key["stances:465"].notes)
        # Recklessness raises damage TAKEN (+20): never a defensive.
        self.assertNotIn("defensives:1719", self.by_key)
        # Arcane Intellect is single-target: a name-map group buff, not a db2 one.
        self.assertNotIn("also db2-effect", self.by_key["groupBuffs:1459"].notes)
        # Racials split by who the aura lands on.
        self.assertIn("racialDebuffs:20549", self.by_key)
        self.assertNotIn("racials:20549", self.by_key)
        self.assertEqual(self.by_key["racials:20594"].klass, "ALL")
        self.assertEqual(set(forever.DB2_RULES) | set(forever.CC_KEYS), set(forever.CATEGORY_KEYS))

    def test_cc_buckets_come_from_the_mechanic(self):
        self.assertEqual(self.by_key["hardCC:118"].source, "cc-mechanic")
        self.assertEqual(self.by_key["ccRoot:122"].source, "cc-mechanic")
        self.assertEqual(self.by_key["ccSnare:1715"].source, "cc-mechanic")
        # Retail's hardCC entries are never name-mapped.
        self.assertFalse([c for c in self.cands if c.category in forever.CC_KEYS and c.source == "name-map"])

    def test_overlaps_are_noted(self):
        self.assertIn("also proposed for stances", self.by_key["movement:783"].notes)
        self.assertIn("also proposed for utility", self.by_key["stances:1784"].notes)


class RulingsTest(unittest.TestCase):
    def test_precedence_follows_the_retail_order(self):
        accepted = [candidate(783, "stances"), candidate(783, "movement"), candidate(1784, "utility"),
                    candidate(1784, "stances"), candidate(20549, "racialDebuffs", "ALL"),
                    candidate(20549, "hardCC", "ALL"), candidate(5, "defensives"), candidate(5, "hardCC")]
        kept, conflicts = forever.resolve_precedence(accepted)
        self.assertEqual(sorted(c.key for c in kept),
                         sorted(["movement:783", "utility:1784", "hardCC:20549", "racialDebuffs:20549",
                                 "defensives:5", "hardCC:5"]))
        self.assertEqual(sorted((x["id"], x["kept"], x["dropped"]) for x in conflicts),
                         [(783, "movement", "stances"), (1784, "utility", "stances")])

    def test_set_ruling_validates(self):
        rulings = {}
        forever.set_ruling(rulings, "defensives:871", "accept", "Shield Wall")
        self.assertEqual(rulings, {"defensives:871": {"ruling": "accept", "reason": "Shield Wall"}})
        for key, ruling, reason in (("nope:1", "accept", "x"), ("defensives", "accept", "x"),
                                    ("defensives:1", "maybe", "x"), ("defensives:1", "accept", " "),
                                    ("defensives:1", "accept", "two\nlines")):
            with self.assertRaises(SystemExit):
                forever.set_ruling(rulings, key, ruling, reason)

    def test_split_by_ruling(self):
        cands = [candidate(1, "defensives"), candidate(2, "defensives"), candidate(3, "defensives")]
        rulings = {"defensives:1": {"ruling": "accept", "reason": "a"},
                   "defensives:2": {"ruling": "reject", "reason": "b"},
                   "defensives:9": {"ruling": "accept", "reason": "gone"}}
        accepted, unruled, stale = forever.split_by_ruling(cands, rulings)
        self.assertEqual([c.id for c in accepted], [1])
        self.assertEqual([c.id for c in unruled], [3])
        self.assertEqual(stale, ["defensives:9"])


class EmitTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        doc = quiet(forever.derive_bundle, fixture_tables(), BUILD, DATE, RETAIL_LUA)
        cls.doc = doc
        everything = [forever.Candidate.from_json(c) for c in doc["candidates"]]
        cls.kept, cls.conflicts = forever.resolve_precedence(everything)
        cls.empty = forever.empty_keys_for(cls.kept)
        cls.files = forever.emit_categories_forever(cls.kept, cls.empty, BUILD, DATE,
                                                    "docs/spell-research/2026-11-14-forever/")
        cls.cast = forever.emit_cast_to_aura_forever(doc["castToAura"], BUILD, DATE)

    def test_empty_keys_listed(self):
        self.assertEqual(self.empty, ["raidCDs"])
        text = self.files[0][1]
        self.assertIn("NS.CategorySeedsForever.EMPTY = {\r\n    raidCDs = true,\r\n}\r\n", text)
        # A category with every candidate rejected is empty too.
        without = [c for c in self.kept if c.category != "movement"]
        self.assertEqual(forever.empty_keys_for(without), ["raidCDs", "movement"])
        files = forever.emit_categories_forever(without, forever.empty_keys_for(without), BUILD, DATE)
        self.assertIn("    movement = true,\r\n", files[0][1])
        self.assertNotIn("NS.CategorySeedsForever.movement", "".join(t for _p, t in files))
        # Accepted AND empty is a contradiction, never a file.
        with self.assertRaises(ValueError):
            forever.emit_categories_forever(self.kept, ["defensives"], BUILD, DATE)

    def test_emit_crlf_and_shape(self):
        self.assertEqual([p for p, _t in self.files], ["defaults/Categories_Forever.lua"])
        for path, text in self.files + [(forever.CAST_PATH, self.cast)]:
            raw = text.encode("utf-8")
            self.assertEqual(raw.count(b"\n"), raw.count(b"\r\n"), path)
            self.assertTrue(text.startswith("local _, NS = ...\r\n"), path)
            self.assertIn("-- %s -- GENERATED. Do not edit by hand." % path, text)
            self.assertIn(BUILD, text)
            self.assertIn(DATE, text)
        seeds = self.files[0][1]
        self.assertNotIn("NS.Compat", seeds)
        self.assertNotIn("NS.Categories ", seeds)
        self.assertIn("docs/spell-research/2026-11-14-forever/", seeds)
        self.assertIn("        871,    -- Shield Wall; name-map of Retail 871\r\n", seeds)
        self.assertIn("910002, -- Fixture Flare Effect; name-map of Retail 199483, the aura cast 910001 lands", seeds)
        # The cast table is the only file that names NS.Compat, on its one selector line, last.
        compat = [line for line in self.cast.split("\r\n") if "NS.Compat" in line and not line.startswith("--")]
        self.assertEqual(compat, [forever.SELECTOR])
        self.assertTrue(self.cast.endswith(forever.SELECTOR + "\r\n"))
        self.assertIn("NS.CastToAuraForever.REWRITE = {", self.cast)
        self.assertIn("[910001] = 910002,", self.cast)
        self.assertNotIn("NS.CastToAura.REWRITE", self.cast)

    @unittest.skipUnless(LUAC, "luac not installed")
    def test_emit_parses_with_luac(self):
        with tempfile.TemporaryDirectory() as tmp:
            for n, (_path, text) in enumerate(self.files + [(forever.CAST_PATH, self.cast)]):
                target = Path(tmp) / ("f%d.lua" % n)
                target.write_bytes(text.encode("utf-8"))
                proc = subprocess.run([LUAC, "-p", str(target)], capture_output=True, text=True)
                self.assertEqual(proc.returncode, 0, proc.stderr)

    @unittest.skipUnless(LUA, "lua not installed")
    def test_emit_loads_into_the_addon_namespace(self):
        probe = (
            'local client, seeds, cast = ...\n'
            'local function load(path, NS) assert(loadfile(path))("AuraMaster", NS) end\n'
            'local NS = {}\n'
            'load(seeds, NS)\n'
            'local S = NS.CategorySeedsForever\n'
            'local n = 0 for _, id in ipairs(S.groupBuffs.WARRIOR) do n = n + 1 end\n'
            'print(S.defensives.WARRIOR[1], S.EMPTY.raidCDs, S.raidCDs == nil, n, NS.Categories == nil)\n'
            'local retail = { REWRITE = {} }\n'
            'NS.CastToAura = retail\n'
            'NS.Compat = { ClientKey = function() return client end }\n'
            'load(cast, NS)\n'
            'print(NS.CastToAuraForever.REWRITE[910001], NS.CastToAura == NS.CastToAuraForever,'
            ' NS.CastToAura == retail)\n')
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "probe.lua").write_text(probe)
            (root / "seeds.lua").write_bytes(self.files[0][1].encode("utf-8"))
            (root / "cast.lua").write_bytes(self.cast.encode("utf-8"))
            out = {}
            for client in ("forever", "retail"):
                proc = subprocess.run([LUA, str(root / "probe.lua"), client, str(root / "seeds.lua"),
                                       str(root / "cast.lua")], capture_output=True, text=True)
                self.assertEqual(proc.returncode, 0, proc.stderr)
                out[client] = proc.stdout.split("\n")
        self.assertEqual(out["forever"][0].split("\t"), ["871", "true", "true", "2", "true"])
        self.assertEqual(out["forever"][1].split("\t"), ["910002", "true", "false"])
        self.assertEqual(out["retail"][1].split("\t"), ["910002", "false", "true"])

    def test_emit_splits_under_cap(self):
        many = []
        for n, key in enumerate(("defensives", "offensiveCDs", "healing", "movement", "stances")):
            many += [candidate(100000 * (n + 1) + i, key) for i in range(30)]
        files = forever.emit_categories_forever(many, [], BUILD, DATE, cap=80)
        self.assertEqual([p for p, _t in files][:2],
                         ["defaults/Categories_Forever.lua", "defaults/Categories_Forever_2.lua"])
        self.assertGreater(len(files), 2)
        seen = []
        for n, (path, text) in enumerate(files, start=1):
            self.assertLessEqual(text.count("\r\n"), 80, path)
            self.assertIn("Part %d of %d." % (n, len(files)), text)
            self.assertIn("NS.CategorySeedsForever = NS.CategorySeedsForever or {}", text)
            seen += [key for key in forever.CATEGORY_KEYS if "NS.CategorySeedsForever.%s = {" % key in text]
        # Every category lands whole in exactly one file, in the Retail order.
        self.assertEqual(seen, ["defensives", "offensiveCDs", "healing", "movement", "stances"])
        self.assertEqual(sum("NS.CategorySeedsForever.EMPTY" in t for _p, t in files), 1)
        # The real cap is 1400; one category that cannot fit is an error, never a split category.
        big = [candidate(1000 + i, "defensives") for i in range(1400)]
        with self.assertRaises(ValueError):
            forever.emit_categories_forever(big, [], BUILD, DATE)
        self.assertEqual(forever.FILE_LINE_CAP, 1400)

    def test_emit_refuses_a_retail_only_class_and_duplicates(self):
        with self.assertRaises(ValueError):
            forever.emit_categories_forever([candidate(1, "defensives", "MONK")], [], BUILD, DATE)
        with self.assertRaises(ValueError):
            forever.emit_categories_forever([candidate(1, "defensives"), candidate(1, "movement")],
                                            [], BUILD, DATE)

    def test_forever_cast_table_counts_area_auras(self):
        # Devotion Aura 465 is an effect-35 party aura: it applies its own id, so the Forever cast
        # table says nothing about it. On effect 6 alone it would be offered the NPC copy 910070.
        entries = self.doc["castToAura"]["entries"]
        self.assertNotIn("465", entries)
        cache = {t: FIXTURES / ("%s.csv" % t) for t, _w in research.tables_for("forever")}
        self.assertIn(465, research.read_aura_appliers(cache["SpellEffect"], research.FOREVER_AURA_EFFECTS))
        self.assertNotIn(465, research.read_aura_appliers(cache["SpellEffect"]))
        self.assertIn("1 id\r\n", "".join(t for _p, t in self.files))

    def test_retail_cast_aura_header_unchanged(self):
        text = research.format_cast_aura_lua({"entries": {}, "pool": 1, "appliers": 2,
                                              "dead_no_candidate": 3}, "12.1.5.1", DATE)
        self.assertIn("-- defaults/CastToAura.lua -- GENERATED. Do not edit by hand.\r\n", text)
        self.assertIn("by tools/spell-research/research.py --emit-cast-aura.\r\n", text)
        self.assertIn("\r\nNS.CastToAura = NS.CastToAura or {}\r\n", text)
        self.assertIn("\r\nNS.CastToAura.REWRITE = {\r\n", text)
        shipped = (research.repo_root() / "defaults" / "CastToAura.lua").read_text(encoding="utf-8")
        self.assertIn("NS.CastToAura = NS.CastToAura or {}", shipped)
        self.assertNotIn("NS.Compat", shipped)


class CliTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.bundle = make_bundle(self.root)
        self.rulings = self.root / "rulings.json"
        self.out = self.root / "out"

    def tearDown(self):
        self.tmp.cleanup()

    def derive(self, *extra):
        return run_main(["derive", "--bundle", str(self.bundle), "--date", DATE, "--rulings",
                         str(self.rulings), "--categories", str(RETAIL_LUA), *extra])

    def emit(self):
        return run_main(["emit", "--bundle", str(self.bundle), "--date", DATE, "--rulings",
                         str(self.rulings), "--out-root", str(self.out)])

    def accept_all(self):
        doc = json.loads((self.bundle / "candidates.json").read_text(encoding="utf-8"))
        tsv = self.root / "all.tsv"
        tsv.write_text("# every fixture candidate\n" + "".join(
            "%s\taccept\tfixture\n" % c["key"] for c in doc["candidates"]))
        code, err = run_main(["rule", "--tsv", str(tsv), "--rulings", str(self.rulings),
                              "--bundle", str(self.bundle)])
        self.assertEqual(code, 0, err)

    def test_unruled_blocks_emit(self):
        self.assertEqual(self.derive("--replay")[0], 0)
        code, err = self.emit()
        self.assertEqual(code, 1)
        self.assertIn("unruled", err)
        self.assertIn("defensives:871", err)
        self.assertFalse(self.out.exists())
        # One ruling short is still a refusal.
        self.accept_all()
        rulings = json.loads(self.rulings.read_text(encoding="utf-8"))
        del rulings["stances:768"]
        forever.save_rulings(self.rulings, rulings)
        code, err = self.emit()
        self.assertEqual(code, 1)
        self.assertIn("stances:768", err)
        self.assertFalse(self.out.exists())

    def test_replay_reproduces_candidates_offline(self):
        def no_network(*_a, **_k):
            raise AssertionError("derive touched the network")
        real = research.http_get
        research.http_get = no_network
        try:
            self.assertEqual(self.derive("--replay")[0], 0)
            first = (self.bundle / "candidates.json").read_bytes()
            # Without --replay, tables already in raw/ are not fetched again either.
            self.assertEqual(self.derive()[0], 0)
            self.assertEqual((self.bundle / "candidates.json").read_bytes(), first)
        finally:
            research.http_get = real
        self.assertEqual(first.count(b"\n"), first.count(b"\r\n"))
        (self.bundle / "raw" / "SpellMisc.csv.gz").unlink()
        with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            forever.main(["derive", "--bundle", str(self.bundle), "--date", DATE, "--replay",
                          "--categories", str(RETAIL_LUA)])

    def test_emit_end_to_end(self):
        self.assertEqual(self.derive("--replay")[0], 0)
        self.accept_all()
        stale = self.out / "defaults" / "Categories_Forever_7.lua"
        stale.parent.mkdir(parents=True)
        stale.write_text("-- left by a bigger emit")
        code, err = self.emit()
        self.assertEqual(code, 0, err)
        self.assertFalse(stale.exists())
        seeds = (self.out / "defaults" / "Categories_Forever.lua").read_bytes()
        self.assertIn(b"NS.CategorySeedsForever.EMPTY = {\r\n    raidCDs = true,\r\n}", seeds)
        self.assertIn(b"--   Provenance: %s/ (candidates.json, RULINGS.md)" % str(self.bundle).encode(), seeds)
        self.assertTrue((self.out / "defaults" / "CastToAura_Forever.lua").exists())
        md = (self.bundle / "RULINGS.md").read_text(encoding="utf-8")
        self.assertIn("- 783 Travel Form: kept in `movement`, dropped from `stances`", md)
        self.assertIn("| 871 | Shield Wall |  | WARRIOR | name-map | 871 | accept | fixture |", md)
        self.assertIn("Fortifying Brew: a Retail-only class", md)

    def test_rule_cli(self):
        code, err = run_main(["rule", "--key", "defensives:871", "--key", "stances:2457", "--ruling",
                              "accept", "--reason", "the warrior's own", "--rulings", str(self.rulings)])
        self.assertEqual(code, 0, err)
        raw = self.rulings.read_bytes()
        self.assertEqual(raw.count(b"\n"), raw.count(b"\r\n"))
        self.assertEqual(json.loads(raw), {
            "defensives:871": {"reason": "the warrior's own", "ruling": "accept"},
            "stances:2457": {"reason": "the warrior's own", "ruling": "accept"}})
        self.assertEqual(self.derive("--replay")[0], 0)
        with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            forever.main(["rule", "--key", "defensives:999", "--ruling", "reject", "--reason", "x",
                          "--rulings", str(self.rulings), "--bundle", str(self.bundle)])
        with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            forever.main(["rule", "--rulings", str(self.rulings)])

    def test_shipped_rulings_file_is_a_map(self):
        rulings = json.loads(forever.RULINGS_PATH.read_text(encoding="utf-8"))
        self.assertIsInstance(rulings, dict)
        for key, value in rulings.items():
            self.assertRegex(key, forever.CANDIDATE_KEY)
            self.assertIn(value["ruling"], forever.RULINGS)
            self.assertTrue(value["reason"].strip())


if __name__ == "__main__":
    unittest.main()
