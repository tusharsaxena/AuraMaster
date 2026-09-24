"""Tests for sid_artifacts (the per-spec dictionary and the review set) and `logs.py propose`.

Run: python3 -m unittest discover -s tools/spell-research -p 'test_*.py'

The end-to-end cases scan the fixture log (plus a second, one-player Enhancement log written here,
so every SHAMAN spec is covered and the Ascendance case is a clean `replace`) through the real CLI
into a temp bundle, against a temp DB2 cache built from the fixture CSVs. Nothing touches the
network or the repo.
"""

import csv
import io
import json
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from collections import Counter
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import logs  # noqa: E402
import sid_artifacts  # noqa: E402
import sid_db2  # noqa: E402
import sid_propose  # noqa: E402
from sid_scan import AuraStats, FileAggregate  # noqa: E402

FIXTURES = HERE / "fixtures"
LOG = FIXTURES / "combatlog-sample.txt"
CATEGORIES = FIXTURES / "Categories.lua"
CAST_TO_AURA = FIXTURES / "CastToAura.lua"
BUILD = "0.0.0.1"

# Every unit name in the fixture log and in the Enhancement log below: none may reach the bundle.
UNIT_NAMES = ("Tester", "Smith, the Bold", "Latecomer", "Target1", "Target6", "Wolfie",
              "Training Dummy", "Enhancer", "Realm-US")

ENH_LOG_NAME = "WoWCombatLog-092426_201500.txt"
_TALENTS = ",".join(str(n) for n in range(100, 122))
ENH_LOG = "\r\n".join([
    "9/24/2026 20:15:00.0000  COMBAT_LOG_VERSION,22,ADVANCED_LOG_ENABLED,1,BUILD_VERSION,12.1.0,"
    "PROJECT_ID,1",
    "9/24/2026 20:15:01.0000  COMBATANT_INFO,Player-1-0000000D,0,%s,263,[(82047,103098,1)],"
    "(0,0,0,0),[],[],0" % _TALENTS,
    "9/24/2026 20:15:05.0000  SPELL_AURA_APPLIED,Player-1-0000000D,\"Enhancer-Realm-US\",0x514,"
    "0x80000000,Player-1-0000000D,\"Enhancer-Realm-US\",0x514,0x80000000,900500,\"Fixture Guard\","
    "0x8,BUFF",
]) + "\r\n"

# The pool tables the fixtures do not carry, minimal (research.build_pool reads these columns).
POOL_TABLES = {
    "SkillLine": ("ID,DisplayName_lang,CategoryID,ParentSkillLineID", ["375,Shaman,7,0"]),
    "SkillLineAbility": ("ID,Spell,ClassMask,SkillLine",
                         ["1,108271,0,375", "2,974,0,375", "3,114050,0,375", "4,999001,0,375",
                          "5,188389,0,375", "6,201633,0,375"]),
    "SpecializationSpells": ("ID,SpellID,SpecID", []),
    "TraitDefinition": ("ID,SpellID,VisibleSpellID", []),
    "TraitNodeEntry": ("ID,TraitDefinitionID", []),
    "TraitNodeXTraitNodeEntry": ("ID,TraitNodeID,TraitNodeEntryID", []),
    "TraitNode": ("ID,TraitTreeID", []),
    "TraitTreeLoadout": ("ID,TraitTreeID,ChrSpecializationID", []),
    "SpellCategories": ("ID,DifficultyID,Mechanic,SpellID", []),
    "SpellClassOptions": ("ID,SpellID,SpellClassSet", []),
    "SpellMechanic": ("ID,StateName_lang", []),
}


def make_db2(root):
    """A DB2 cache of build BUILD: the three fixture CSVs plus minimal pool tables."""
    db2 = root / "db2"
    db2.mkdir()
    for table in ("ChrSpecialization", "SpellName", "SpellEffect"):
        shutil.copyfile(FIXTURES / "db2" / ("%s-test.csv" % table),
                        db2 / ("%s-%s.csv" % (table, BUILD)))
    for table, (header, rows) in POOL_TABLES.items():
        (db2 / ("%s-%s.csv" % (table, BUILD))).write_text(
            "\n".join([header] + rows) + "\n", encoding="utf-8")
    return db2


def run_cli(argv):
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        code = logs.main(argv)
    return code, out.getvalue(), err.getvalue()


class Run:
    """One scan of the fixture logs, then `propose` into a bundle with the given thresholds."""

    def __init__(self, min_apps, min_players):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.logs = root / "logs"
        self.logs.mkdir()
        shutil.copyfile(LOG, self.logs / "WoWCombatLog-092326_230936.txt")
        (self.logs / ENH_LOG_NAME).write_bytes(ENH_LOG.encode("utf-8"))
        self.db2 = make_db2(root)
        self.bundle = root / "docs" / "spell-research" / "2026-09-24-logs"
        code, _out, err = run_cli(["scan", "--logs", str(self.logs), "--cache", str(root / "cache"),
                                   "--db2-cache", str(self.db2),
                                   "--out", str(self.bundle / "evidence.json")])
        assert code == 0, err
        self.code, self.out, self.err = run_cli([
            "propose", "--date", "2026-09-24", "--bundle", str(self.bundle),
            "--db2-cache", str(self.db2), "--categories", str(CATEGORIES),
            "--cast-to-aura", str(CAST_TO_AURA), "--decisions", str(root / "decisions.json"),
            "--min-apps", str(min_apps), "--min-players", str(min_players)])
        assert self.code == 0, self.err

    def read(self, rel):
        return (self.bundle / rel).read_text(encoding="utf-8")

    def close(self):
        self.tmp.cleanup()


BUNDLE_FILES = {
    "evidence.json", "proposals.json", "CURRENT_CATEGORIES.md", "CORRECTIONS.md",
    "PROPOSED_ADDITIONS.md", "FLAGS.md", "SOURCES.md", "dictionary/auras.json",
    "dictionary/auras.csv", "dictionary/AURAS.md", "dictionary/non-player.csv",
    "REVIEW.csv", "REVIEW.md",
}


def md_row_set(text):
    """{(class, spec, aura type, spell id)} from AURAS.md's headings and items."""
    rows, cls, spec = set(), None, None
    for line in text.splitlines():
        m = re.match(r"^## (\S+)$", line)
        if m:
            cls, spec = m.group(1), None
            continue
        m = re.match(r"^### (\S+) · (.+)$", line)
        if m:
            spec = m.group(2)
            continue
        m = re.match(r"^- .*\((\d+), (BUFF|DEBUFF)\)", line)
        if m and cls and spec:
            rows.add((cls, spec, m.group(2), int(m.group(1))))
    return rows


class EndToEnd(unittest.TestCase):
    """The fixture, scanned and proposed with a bar of 1 application / 1 player."""

    @classmethod
    def setUpClass(cls):
        cls.bundle_run = Run(1, 1)

    @classmethod
    def tearDownClass(cls):
        cls.bundle_run.close()

    def rows(self):
        return json.loads(self.bundle_run.read("dictionary/auras.json"))["rows"]

    def test_the_bundle_holds_every_file(self):
        got = {p.relative_to(self.bundle_run.bundle).as_posix()
               for p in self.bundle_run.bundle.rglob("*") if p.is_file()}
        self.assertEqual(got, BUNDLE_FILES)

    def test_one_row_per_class_spec_aura_type_and_id(self):
        keys = [(r["class"], r["spec"], r["aura_type"], r["spell_id"]) for r in self.rows()]
        self.assertEqual(len(keys), len(set(keys)))
        self.assertIn(("SHAMAN", "Restoration", "BUFF", 114052), keys)
        self.assertIn(("SHAMAN", "Elemental", "BUFF", 1219480), keys)
        self.assertIn(("SHAMAN", "Enhancement", "BUFF", 900500), keys)
        self.assertIn(("SHAMAN", "Restoration", "DEBUFF", 188389), keys)

    def test_a_two_spec_aura_is_two_rows(self):
        astral = sorted(r["spec"] for r in self.rows() if r["spell_id"] == 108271)
        self.assertEqual(astral, ["Elemental", "Restoration"])

    def test_row_columns_and_values(self):
        row = next(r for r in self.rows() if r["spell_id"] == 114052)
        self.assertEqual(list(row), list(sid_artifacts.ROW_KEYS))
        self.assertEqual((row["spec_id"], row["name"], row["applications"], row["players"]),
                         (264, "Ascendance", 2, 1))
        self.assertEqual((row["self_pct"], row["single_pct"], row["group_pct"], row["other_pct"]),
                         (100.0, 0.0, 0.0, 0.0))
        self.assertEqual(row["recast_median_s"], 90.0)
        flame_shock = next(r for r in self.rows() if r["spell_id"] == 188389)  # on a creature
        self.assertEqual((flame_shock["single_pct"], flame_shock["group_pct"],
                          flame_shock["other_pct"]), (0.0, 0.0, 100.0))
        self.assertEqual((row["first_seen"], row["last_seen"]), ("2026-09-23", "2026-09-23"))
        self.assertEqual(row["category"], "")   # 114051 is the listed id, not 114052
        astral = next(r for r in self.rows() if r["spell_id"] == 108271)
        self.assertEqual(astral["category"], "defensives")
        self.assertEqual((astral["suggested_category"], astral["rule"]), ("defensives", "R1"))
        wall = next(r for r in self.rows() if r["spell_id"] == 201633)
        self.assertEqual(wall["group_pct"], 100.0)

    def test_nothing_from_pets_or_creatures(self):
        ids = {r["spell_id"] for r in self.rows()}
        self.assertNotIn(58875, ids)    # the pet's Spirit Walk
        self.assertNotIn(388539, ids)   # the creature's Rend
        with (self.bundle_run.bundle / "dictionary" / "non-player.csv").open(encoding="utf-8",
                                                                      newline="") as fh:
            tally = {int(r["spell_id"]): r for r in csv.DictReader(fh)}
        self.assertEqual(set(tally), {58875, 388539})
        self.assertEqual(tally[58875]["applications"], "2")

    def test_csv_md_and_json_carry_the_same_rows(self):
        from_json = {(r["class"], r["spec"], r["aura_type"], r["spell_id"]) for r in self.rows()}
        with (self.bundle_run.bundle / "dictionary" / "auras.csv").open(encoding="utf-8",
                                                                 newline="") as fh:
            reader = csv.DictReader(fh)
            self.assertEqual(reader.fieldnames, list(sid_artifacts.ROW_KEYS))
            from_csv = {(r["class"], r["spec"], r["aura_type"], int(r["spell_id"])) for r in reader}
        from_md = md_row_set(self.bundle_run.read("dictionary/AURAS.md"))
        self.assertEqual(from_csv, from_json)
        self.assertEqual(from_md, from_json)

    def test_auras_md_has_a_table_of_contents(self):
        text = self.bundle_run.read("dictionary/AURAS.md")
        self.assertIn("- [SHAMAN](#shaman)", text)
        self.assertIn("  - [Restoration](#shaman--restoration)", text)
        self.assertIn("### SHAMAN · Restoration", text)

    def test_current_categories_lists_every_shipped_id_with_a_status(self):
        text = self.bundle_run.read("CURRENT_CATEGORIES.md")
        status = {}
        for m in re.finditer(r"^\| (\w+) \| (\d+) \| [^|]* \| (confirmed|unverified|stale|wrong id) \|",
                             text, re.MULTILINE):
            status[(m.group(1), int(m.group(2)))] = m.group(3)
        shipped = {(klass, sid) for cat in sid_db2.shipped_categories(CATEGORIES)
                   for klass, ids in cat["classes"].items() for sid in ids}
        self.assertEqual(set(status), shipped)
        self.assertEqual(status[("SHAMAN", 114051)], "wrong id")
        self.assertEqual(status[("SHAMAN", 108271)], "confirmed")
        self.assertEqual(status[("WARRIOR", 871)], "unverified")
        self.assertIn("## Offensive cooldowns (`offensiveCDs`)", text)

    def test_corrections_has_the_ascendance_replace_in_the_specs_format(self):
        text = self.bundle_run.read("CORRECTIONS.md")
        self.assertRegex(
            text, r"Offensive cooldowns · SHAMAN · Ascendance — listed 114051 \(never applied\) → "
                  r"114052 \(Restoration, 2 apps / 1 player\), 1219480 \(Elemental, 1 app / 1 player\)"
                  r" — replace — high")
        self.assertIn("replace|offensiveCDs|SHAMAN|ascendance|114052,1219480", text)

    def test_every_addition_has_a_category_a_rule_and_a_reason(self):
        text = self.bundle_run.read("PROPOSED_ADDITIONS.md")
        heading, entries = None, []
        for line in text.splitlines():
            if line.startswith("## "):
                heading = line[3:]
            elif line.startswith("- **"):
                entries.append([heading, line, ""])
            elif line.startswith("  - Reason: ") and entries:
                entries[-1][2] = line
        self.assertTrue(entries)
        for heading, line, reason in entries:
            self.assertTrue(heading, line)
            self.assertRegex(line, r" — R[1-9] — (high|medium|low)$")
            self.assertTrue(reason.strip() != "- Reason:", line)
        guard = [e for e in entries if "(900500)" in e[1]]
        self.assertEqual(len(guard), 1)
        self.assertEqual(guard[0][0], "Defensive cooldowns (`defensives`)")
        self.assertIn("reduces damage taken", guard[0][2])

    def test_proposals_json_is_the_ordered_queue(self):
        doc = json.loads(self.bundle_run.read("proposals.json"))
        props = doc["proposals"]
        sections = [p["section"] for p in props]
        self.assertEqual(sections, sorted(sections, key=lambda s: s != "correction"))
        for section in ("correction", "addition"):
            apps = [p["applications"] for p in props if p["section"] == section]
            self.assertEqual(apps, sorted(apps, reverse=True))
        asc = next(p for p in props if p["name"] == "Ascendance")
        self.assertEqual((asc["type"], asc["category"], asc["class"], asc["listed"], asc["proposed"]),
                         ("replace", "offensiveCDs", "SHAMAN", [114051], [114052, 1219480]))
        self.assertEqual(asc["key"], "replace|offensiveCDs|SHAMAN|ascendance|114052,1219480")
        self.assertEqual(asc["evidence"]["114052"], {"Restoration": [2, 1]})
        self.assertEqual(doc["date"], "2026-09-24")

    def test_flags_and_sources(self):
        flags = self.bundle_run.read("FLAGS.md")
        for heading in ("## Unverified", "## Stale", "## Below the evidence bar",
                        "## Crowd-control debuffs in neither hardCC nor softCC"):
            self.assertIn(heading, flags)
        sources = self.bundle_run.read("SOURCES.md")
        self.assertIn("| Logs scanned | 2 |", sources)
        self.assertIn("| Skipped lines | 1 |", sources)
        self.assertIn("| DB2 build | %s |" % BUILD, sources)
        self.assertIn("| Evidence bar | 1 application from 1 player |", sources)
        self.assertIn("| Unattributed applications | 1 |", sources)

    def test_no_player_identity_and_every_file_is_crlf(self):
        for path in self.bundle_run.bundle.rglob("*"):
            if not path.is_file():
                continue
            data = path.read_bytes()
            text = data.decode("utf-8")
            self.assertNotIn("Player-", text, path.name)
            for unit in UNIT_NAMES:
                self.assertNotIn(unit, text, "%s in %s" % (unit, path.name))
            self.assertTrue(data.endswith(b"\r\n"), path.name)
            self.assertEqual(data.count(b"\n"), data.count(b"\r\n"), path.name)

    def test_the_summary_names_the_counts(self):
        self.assertRegex(self.bundle_run.out, r"corrections \d+, additions \d+, flags \d+")
        self.assertIn("REVIEW.csv", self.bundle_run.out)

    def test_the_review_sheet_covers_the_queue(self):
        keys = {p["key"] for p in json.loads(self.bundle_run.read("proposals.json"))["proposals"]}
        data = (self.bundle_run.bundle / "REVIEW.csv").read_bytes()
        self.assertTrue(data.startswith(b"\xef\xbb\xbf"))
        rows = list(csv.DictReader(io.StringIO(data.decode("utf-8-sig"), newline="")))
        self.assertTrue(rows)
        self.assertEqual({r["proposal_key"] for r in rows}, keys)
        asc = [(r["type"], r["spell_id"]) for r in rows
               if r["proposal_key"] == "replace|offensiveCDs|SHAMAN|ascendance|114052,1219480"]
        self.assertEqual(asc, [("deletion", "114051"), ("correction-add", "114052"),
                               ("correction-add", "1219480")])


class DefaultBar(unittest.TestCase):
    """At the default bar (20 / 3) nothing in the fixture is proposed; the dictionary is unchanged."""

    def test_below_bar_auras_are_in_the_dictionary_and_not_proposed(self):
        low, high = Run(20, 3), Run(1, 1)
        try:
            rows = json.loads(low.read("dictionary/auras.json"))["rows"]
            same = json.loads(high.read("dictionary/auras.json"))["rows"]
            self.assertEqual(rows, same)
            self.assertIn(114052, {r["spell_id"] for r in rows})
            self.assertEqual(json.loads(low.read("proposals.json"))["proposals"], [])
            self.assertIn("114052", low.read("FLAGS.md"))   # a below-the-bar sighting
        finally:
            low.close()
            high.close()


class DictionaryRowsTest(unittest.TestCase):
    """dictionary_rows on a hand-built aggregate."""

    SPEC_MAP = {262: {"class": "SHAMAN", "name": "Elemental", "role": 2},
                264: {"class": "SHAMAN", "name": "Restoration", "role": 1}}
    SHIPPED = [{"key": "defensives", "label": "Defensive cooldowns", "aura": "BUFF",
                "classes": {"SHAMAN": [108271]}},
               {"key": "hardCC", "label": "Hard CC", "aura": "DEBUFF",
                "classes": {"SHAMAN": [51514]}}]

    def agg(self):
        agg = FileAggregate(first_date="2026-09-01", last_date="2026-09-20")
        def st(apps, players, **kw):
            return AuraStats(names=Counter({kw.pop("name", "Astral Shift"): apps}),
                             applications=apps, players={"p%d" % i for i in range(players)},
                             first_seen="2026-09-01", last_seen="2026-09-20", **kw)
        agg.per_spec[("SHAMAN", 262)] = {("BUFF", 108271): st(10, 2, self_=10),
                                         ("DEBUFF", 51514): st(4, 1, single=4, name="Hex")}
        agg.per_spec[("SHAMAN", 264)] = {("BUFF", 108271): st(6, 3, self_=5, single=1,
                                                              recast_samples=[90.0, 100.0])}
        agg.per_spec[("SHAMAN", None)] = {("BUFF", 108271): st(1, 1, self_=1)}
        return agg

    def test_rows_sorted_with_categories_and_suggestions(self):
        rows = sid_artifacts.dictionary_rows(
            self.agg(), self.SPEC_MAP, {108271: "Astral Shift"}, self.SHIPPED,
            {("SHAMAN", 108271): ("defensives", "R1", "high", "…")})
        self.assertEqual([(r["spec"], r["aura_type"], r["spell_id"]) for r in rows],
                         [("Elemental", "BUFF", 108271), ("Elemental", "DEBUFF", 51514),
                          ("Restoration", "BUFF", 108271), ("unknown", "BUFF", 108271)])
        resto = rows[2]
        self.assertEqual((resto["self_pct"], resto["single_pct"], resto["group_pct"]),
                         (83.3, 16.7, 0.0))
        self.assertEqual(resto["recast_median_s"], 95.0)
        self.assertEqual(resto["category"], "defensives")
        self.assertEqual((resto["suggested_category"], resto["rule"]), ("defensives", "R1"))
        self.assertIsNone(rows[3]["spec_id"])
        hex_row = rows[1]
        self.assertEqual((hex_row["category"], hex_row["suggested_category"], hex_row["rule"]),
                         ("hardCC", "", ""))
        self.assertIsNone(rows[0]["recast_median_s"])

    def test_a_suggestion_never_reaches_a_debuff_row(self):
        # A suggestion keyed on the debuff's own (class, id): BUFF rows only, so the Hex row stays
        # blank, while the BUFF rows of the same call still take theirs.
        rows = sid_artifacts.dictionary_rows(
            self.agg(), self.SPEC_MAP, {}, self.SHIPPED,
            {("SHAMAN", 51514): ("hardCC", "R7", "high", "…"),
             ("SHAMAN", 108271): ("defensives", "R1", "high", "…")})
        hex_row = next(r for r in rows if r["spell_id"] == 51514)
        self.assertEqual(hex_row["aura_type"], "DEBUFF")
        self.assertEqual((hex_row["suggested_category"], hex_row["rule"]), ("", ""))
        buff = next(r for r in rows if r["spell_id"] == 108271)
        self.assertEqual((buff["suggested_category"], buff["rule"]), ("defensives", "R1"))


class CurrentCategoriesAllTest(unittest.TestCase):
    """CURRENT_CATEGORIES.md: an ALL entry is confirmed by any class's evidence (SID-10)."""

    def test_an_all_entry_is_confirmed_from_every_class(self):
        spec_map = {71: {"class": "WARRIOR", "name": "Arms", "role": 2},
                    264: {"class": "SHAMAN", "name": "Restoration", "role": 1}}
        shipped = [{"key": "hardCC", "label": "Hard CC", "aura": "DEBUFF",
                    "classes": {"ALL": [20549]}}]
        agg = FileAggregate(first_date="2026-09-01", last_date="2026-09-20")
        for key, n in ((("WARRIOR", 71), 30), (("SHAMAN", 264), 12)):
            agg.per_spec[key] = {("DEBUFF", 20549): AuraStats(
                names=Counter({"War Stomp": n}), applications=n,
                players={"%s%d" % (key[0], i) for i in range(3)}, single=n,
                first_seen="2026-09-01", last_seen="2026-09-20")}
        rows = sid_artifacts.dictionary_rows(agg, spec_map, {}, shipped, {})
        text = sid_artifacts._current_md("2026-09-24", rows, shipped, [], [], {20549: "War Stomp"},
                                         {("WARRIOR", "DEBUFF", 20549): 3,
                                          ("SHAMAN", "DEBUFF", 20549): 3})
        line = next(l for l in text.split("\n") if "| 20549 |" in l)
        self.assertIn("| confirmed |", line)
        self.assertIn("42 apps / 6 players", line)
        self.assertIn("SHAMAN Restoration 12/3", line)
        self.assertIn("WARRIOR Arms 30/3", line)


class QueueOrderTest(unittest.TestCase):
    """write_bundle orders the queue: corrections first, then additions, each most-applied first
    (given out of order here, interleaved, so a one-way or missing sort fails)."""

    @staticmethod
    def prop(ptype, name, sid, apps, category="defensives"):
        listed = [sid + 1] if ptype != "addition" else []
        return sid_propose.Proposal(
            type=ptype, category=category, from_category="", klass="SHAMAN", name=name,
            listed=listed, proposed=[sid], evidence={sid: {"Elemental": (apps, 2)}},
            rule="evidence" if ptype != "addition" else "R1", reason="A reason.",
            confidence="high", applications=apps)

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="sid-queue-"))
        proposals = [self.prop("addition", "Add Low", 800001, 5),
                     self.prop("replace", "Corr Low", 700001, 3),
                     self.prop("addition", "Add High", 800003, 40),
                     self.prop("add", "Corr High", 700003, 30),
                     self.prop("replace", "Corr Mid", 700005, 12)]
        shipped = [{"key": "defensives", "label": "Defensive cooldowns", "aura": "BUFF",
                    "classes": {"SHAMAN": [700002, 700004, 700006]}}]
        sid_artifacts.write_bundle(self.tmp, "2026-09-24", [], proposals, [], shipped,
                                   {"thresholds": {"min_applications": 1, "min_players": 1}})

    def tearDown(self):
        shutil.rmtree(str(self.tmp), ignore_errors=True)

    def read(self, rel):
        return (self.tmp / rel).read_bytes().decode("utf-8")

    def test_proposals_json_order(self):
        props = json.loads(self.read("proposals.json"))["proposals"]
        self.assertEqual([(p["section"], p["name"]) for p in props],
                         [("correction", "Corr High"), ("correction", "Corr Mid"),
                          ("correction", "Corr Low"), ("addition", "Add High"),
                          ("addition", "Add Low")])

    def test_corrections_md_order(self):
        text = self.read("CORRECTIONS.md")
        numbered = re.findall(r"^(\d+)\. .* · SHAMAN · (Corr \w+) — ", text, re.M)
        self.assertEqual(numbered, [("1", "Corr High"), ("2", "Corr Mid"), ("3", "Corr Low")])

    def test_proposed_additions_md_order(self):
        text = self.read("PROPOSED_ADDITIONS.md")
        self.assertEqual(re.findall(r"^- \*\*(Add \w+)\*\*", text, re.M),
                         ["Add High", "Add Low"])


class ProposeCliTest(unittest.TestCase):
    def test_propose_without_a_date_exits_non_zero_with_a_message(self):
        with tempfile.TemporaryDirectory() as tmp:
            proc = subprocess.run(
                [sys.executable, str(HERE / "logs.py"), "propose", "--bundle", tmp],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("--date", proc.stderr)

    def test_a_malformed_date_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            proc = subprocess.run(
                [sys.executable, str(HERE / "logs.py"), "propose", "--date", "24/09/2026",
                 "--bundle", tmp],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("YYYY-MM-DD", proc.stderr)

    def test_a_missing_evidence_file_names_the_scan_command(self):
        with tempfile.TemporaryDirectory() as tmp:
            proc = subprocess.run(
                [sys.executable, str(HERE / "logs.py"), "propose", "--date", "2026-09-24",
                 "--bundle", tmp],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("logs.py scan", proc.stderr)


class Sid12AdditionCountsTest(unittest.TestCase):
    """PROPOSED_ADDITIONS.md states the filter and fold: raw candidates, dropped as low confidence,
    folded into class-neutral proposals, already ruled, proposed."""

    def write(self, counts):
        tmp = Path(tempfile.mkdtemp(prefix="sid-counts-"))
        self.addCleanup(shutil.rmtree, str(tmp), True)
        p = sid_propose.Proposal(
            type="addition", category="consumables", from_category="", klass="ALL", name="Well Fed",
            listed=[], proposed=[900300], evidence={900300: {"WARRIOR Arms": (40, 4),
                                                             "SHAMAN Restoration": (30, 3)}},
            rule="R8", reason="A reason.", confidence="high", applications=70)
        shipped = [{"key": "consumables", "label": "Consumables", "aura": "BUFF", "classes": {}}]
        sid_artifacts.write_bundle(tmp, "2026-09-24", [], [p], [], shipped,
                                   {"thresholds": {"min_applications": 20, "min_players": 3}},
                                   addition_counts=counts)
        return (tmp / "PROPOSED_ADDITIONS.md").read_text(encoding="utf-8")

    def test_the_before_and_after_counts(self):
        text = self.write({"raw": 2046, "low": 1500, "folded": 300, "all": 40, "ruled": 1,
                           "proposed": 285})
        self.assertIn("2046 candidates above the bar", text)
        self.assertIn("1500 dropped as low confidence", text)
        self.assertIn("300 item-effect candidates folded into 40 class-neutral (ALL) proposals",
                      text)
        self.assertIn("1 already ruled", text)
        self.assertIn("285 proposed", text)
        self.assertIn("\n\n1 addition in 1 category.\n\n2046 candidates", text)
        self.assertIn("285 proposed.\n\n## ", text)
        self.assertIn("suggested_category", text)
        self.assertIn("- **Well Fed** (900300) · ALL — WARRIOR Arms 40 apps / 4 players; "
                      "SHAMAN Restoration 30 apps / 3 players — R8 — high", text)

    def test_the_counts_read_singular(self):
        text = self.write({"raw": 1, "low": 1, "folded": 1, "all": 1, "ruled": 0, "proposed": 1})
        self.assertIn("1 candidate above the bar", text)
        self.assertIn("1 item-effect candidate folded into 1 class-neutral (ALL) proposal", text)

    def test_no_counts_no_line(self):
        self.assertNotIn("candidates above the bar", self.write(None))

    def test_the_cli_bundle_states_the_counts(self):
        run = Run(1, 1)
        self.addCleanup(run.close)
        self.assertRegex(run.read("PROPOSED_ADDITIONS.md"),
                         r"\d+ candidates? above the bar in no category: \d+ dropped as low "
                         r"confidence")
        self.assertRegex(run.out, r"Additions from \d+ candidates?: \d+ low confidence "
                                  r"\(dictionary only\), \d+ folded into \d+ ALL proposals?")


if __name__ == "__main__":
    unittest.main()


class PluralTest(unittest.TestCase):
    """SID-11 cosmetics: "9 categories", "1 application / 1 player"."""

    def test_counts_read_as_english(self):
        n = sid_artifacts._n
        self.assertEqual(n(9, "category"), "9 categories")
        self.assertEqual(n(1, "category"), "1 category")
        self.assertEqual(n(2, "class"), "2 classes")
        self.assertEqual(n(1, "class"), "1 class")
        self.assertEqual(n(3, "class line"), "3 class lines")
        self.assertEqual(n(0, "application"), "0 applications")
        self.assertEqual(n(1, "application"), "1 application")
        self.assertEqual(n(1, "player"), "1 player")
        self.assertEqual(n(2, "id"), "2 ids")

    def test_the_scan_summary_reads_singular(self):
        import logs
        line = logs.format_summary({"files": 1, "bytes": 0, "read": 1, "cached": 0, "first_date": "",
                                    "last_date": "", "lines": 1, "skipped": 0, "unattributed": 0})
        self.assertTrue(line.startswith("Scanned 1 log (0.0 MB)"), line)
