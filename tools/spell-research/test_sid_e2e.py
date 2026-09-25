"""The end-to-end acceptance run: scan -> propose -> decide -> apply, through the real CLI.

Run: python3 -m unittest discover -s tools/spell-research -p 'test_*.py'

Everything is copied into a temp dir first (the fixture log plus the one-player Enhancement log of
test_sid_artifacts, so every SHAMAN spec is covered and Ascendance is a clean `replace`; the
fixture Categories.lua and CastToAura.lua; a DB2 cache built from the fixture CSVs), and every
stage is a separate `python3 tools/spell-research/logs.py ...` process, so what is tested is the
command line the aura-spells-review slash command drives. Nothing touches the network, the repo
or ~/.cache.
"""

import csv
import io
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


class E2EFixture:
    """The temp dir every end-to-end run starts from, and the logs.py runner."""

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


class AcceptanceRun(E2EFixture, unittest.TestCase):
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


class SheetRun(E2EFixture, unittest.TestCase):
    """scan -> propose -> fill REVIEW.csv -> ingest (SID-14), each a separate logs.py process."""

    def logs_py_fails(self, *argv):
        proc = subprocess.run(
            [sys.executable, "tools/spell-research/logs.py"] + [str(a) for a in argv],
            cwd=str(REPO), stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            universal_newlines=True)
        self.assertNotEqual(proc.returncode, 0, "logs.py %s succeeded:\n%s" % (argv[0], proc.stdout))
        return proc.stdout + proc.stderr

    def fill(self, decide, extra=()):
        """A filled copy of the bundle's REVIEW.csv: decision = decide(row) for each row."""
        text = (self.bundle / "REVIEW.csv").read_text(encoding="utf-8-sig")
        rows = list(csv.DictReader(io.StringIO(text, newline="")))
        for row in rows:
            row["decision"] = decide(row)
        rows += list(extra)
        buf = io.StringIO()
        writer = csv.DictWriter(buf, fieldnames=list(rows[0].keys()), lineterminator="\r\n")
        writer.writeheader()
        writer.writerows(rows)
        path = self.root / "filled.csv"
        path.write_bytes(("\ufeff" + buf.getvalue()).encode("utf-8"))
        return path, rows

    def snapshot(self):
        paths = [self.lua, self.decisions] + sorted(self.bundle.rglob("*"))
        return {str(p): p.read_bytes() for p in paths if p.is_file()}

    def ingest(self, sheet):
        return self.logs_py("ingest", "--bundle", self.bundle, "--csv", sheet, "--date", DATE,
                            "--categories", self.lua, "--decisions", self.decisions)

    def test_approve_the_ascendance_add_and_reject_its_deletion(self):
        self.logs_py("scan", "--logs", self.logs, "--cache", self.root / "cache",
                     "--db2-cache", self.db2, "--out", self.bundle / "evidence.json")
        self.logs_py("propose", "--date", DATE, "--bundle", self.bundle, "--db2-cache", self.db2,
                     "--categories", self.lua, "--cast-to-aura", self.c2a,
                     "--decisions", self.decisions, "--min-apps", 1, "--min-players", 1)
        queue = json.loads((self.bundle / "proposals.json").read_text(encoding="utf-8"))
        asc = next(p for p in queue["proposals"]
                   if p["name"] == "Ascendance" and p["category"] == "offensiveCDs")

        def decide(row):
            if row["proposal_key"] != asc["key"]:
                return ""
            return {"deletion": "Reject", "correction-add": "Approve"}.get(row["type"], "")

        sheet, rows = self.fill(decide)
        mine = [r for r in rows if r["proposal_key"] == asc["key"]]
        self.assertIn("deletion", [r["type"] for r in mine])
        self.assertIn("correction-add", [r["type"] for r in mine])

        # A sheet with an unknown row_id fails and writes nothing.
        before = self.snapshot()
        ghost = dict(rows[0], row_id="R9999", decision="Approve")
        bad, _rows = self.fill(decide, extra=[ghost])
        self.assertIn("R9999", self.logs_py_fails(
            "ingest", "--bundle", self.bundle, "--csv", bad, "--date", DATE,
            "--categories", self.lua, "--decisions", self.decisions))
        self.assertEqual(self.snapshot(), before)

        sheet, _rows = self.fill(decide)
        out = self.ingest(sheet)
        self.assertIn("+114052", out)
        offensive = self.shaman("offensiveCDs")
        self.assertIn(114051, offensive)
        self.assertIn(114052, offensive)
        decisions = json.loads(self.decisions.read_text(encoding="utf-8"))
        self.assertEqual(decisions["%s#114051#deletion" % asc["key"]]["ruling"], "reject")
        self.assertEqual(decisions["%s#114052#correction-add" % asc["key"]]["ruling"], "accept")
        self.assertTrue((self.bundle / "DECISIONS.md").exists())
        data = self.lua.read_bytes()
        self.assertEqual(data.count(b"\n"), data.count(b"\r\n"))

        # A second ingest of the same sheet changes nothing.
        after = self.snapshot()
        self.ingest(sheet)
        self.assertEqual(self.snapshot(), after)


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
