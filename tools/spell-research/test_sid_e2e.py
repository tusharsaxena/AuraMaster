"""The end-to-end acceptance run: scan -> propose -> decide -> apply, through the real CLI.

Run: python3 -m unittest discover -s tools/spell-research -p 'test_*.py'

Everything is copied into a temp dir first (the fixture log plus the one-player Enhancement log of
test_sid_artifacts, so every SHAMAN spec is covered and Ascendance is a clean `replace`; the
fixture Categories.lua and CastToAura.lua; a DB2 cache built from the fixture CSVs), and every
stage is a separate `python3 tools/spell-research/logs.py ...` process, so what is tested is the
command line the aura-spells-review slash command drives. Nothing touches the network, the repo
or ~/.cache.
"""

import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import sid_db2  # noqa: E402
from test_sid_artifacts import ENH_LOG, ENH_LOG_NAME, make_db2  # noqa: E402

FIXTURES = HERE / "fixtures"
DATE = "2026-09-24"


class AcceptanceRun(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        logs_dir = self.root / "logs"
        logs_dir.mkdir()
        shutil.copyfile(FIXTURES / "combatlog-sample.txt",
                        logs_dir / "WoWCombatLog-092326_230936.txt")
        (logs_dir / ENH_LOG_NAME).write_bytes(ENH_LOG.encode("utf-8"))
        self.logs = logs_dir
        self.lua = self.root / "Categories.lua"
        shutil.copyfile(FIXTURES / "Categories.lua", self.lua)
        self.c2a = self.root / "CastToAura.lua"
        shutil.copyfile(FIXTURES / "CastToAura.lua", self.c2a)
        self.db2 = make_db2(self.root)
        self.bundle = self.root / "bundle"
        self.decisions = self.root / "decisions.json"

    def tearDown(self):
        self.tmp.cleanup()

    def logs_py(self, *argv):
        proc = subprocess.run(
            [sys.executable, "tools/spell-research/logs.py"] + [str(a) for a in argv],
            cwd=str(REPO), stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            universal_newlines=True)
        self.assertEqual(proc.returncode, 0, "logs.py %s failed:\n%s%s"
                         % (argv[0], proc.stdout, proc.stderr))
        return proc.stdout

    def shaman(self, key):
        cat = next(c for c in sid_db2.shipped_categories(self.lua) if c["key"] == key)
        return cat["classes"]["SHAMAN"]

    def test_scan_propose_decide_apply_puts_114052_into_offensive_cooldowns(self):
        self.assertEqual(self.shaman("offensiveCDs"), [114051])
        out = self.logs_py("scan", "--logs", self.logs, "--cache", self.root / "cache",
                           "--db2-cache", self.db2, "--out", self.bundle / "evidence.json")
        self.assertIn("Scanned 2 logs", out)
        out = self.logs_py("propose", "--date", DATE, "--bundle", self.bundle,
                           "--db2-cache", self.db2, "--categories", self.lua,
                           "--cast-to-aura", self.c2a, "--decisions", self.decisions,
                           "--min-apps", 1, "--min-players", 1)
        self.assertIn("corrections", out)

        queue = json.loads((self.bundle / "proposals.json").read_text(encoding="utf-8"))
        asc = next(p for p in queue["proposals"]
                   if p["name"] == "Ascendance" and p["category"] == "offensiveCDs")
        self.assertEqual(asc["type"], "replace")

        self.logs_py("decide", "--bundle", self.bundle, "--key", asc["key"], "--ruling", "accept",
                     "--date", DATE, "--decisions", self.decisions, "--categories", self.lua)
        self.assertEqual(json.loads(self.decisions.read_text(encoding="utf-8"))[asc["key"]]
                         ["ruling"], "accept")

        before = self.lua.read_bytes()
        self.logs_py("apply", "--bundle", self.bundle, "--categories", self.lua,
                     "--decisions", self.decisions)
        after = self.lua.read_bytes()
        self.assertIn(114052, self.shaman("offensiveCDs"))
        self.assertNotIn(114051, self.shaman("offensiveCDs"))
        self.assertTrue((self.bundle / "DECISIONS.md").exists())
        self.assertEqual(after.count(b"\n"), after.count(b"\r\n"))  # still CRLF
        self.assertNotEqual(before, after)

        # Only the accepted proposal was applied: a second apply changes nothing.
        self.logs_py("apply", "--bundle", self.bundle, "--categories", self.lua,
                     "--decisions", self.decisions)
        self.assertEqual(self.lua.read_bytes(), after)


class FormulaWording(unittest.TestCase):
    """The README states the owner's formula verbatim (spec: "per spec, and cast by a player,
    not an NPC"); the source of a SPELL_AURA_APPLIED line is the caster."""

    def test_readme_states_the_owners_formula(self):
        readme = (HERE / "README.md").read_text(encoding="utf-8")
        formula = "**per spec, and cast by a player, not an NPC**"
        self.assertTrue(formula in readme, "README.md does not state " + formula)
        self.assertFalse("applied by a player, not an NPC" in readme,
                         "README.md still words the formula as 'applied by a player'")


if __name__ == "__main__":
    unittest.main()
