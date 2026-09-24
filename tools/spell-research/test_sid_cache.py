"""Tests for sid_cache (per-log cache, folder scan, merge) and `logs.py scan`.

Run: python3 -m unittest discover -s tools/spell-research -p 'test_*.py'
"""

import io
import json
import os
import shutil
import sys
import tempfile
import unittest
from collections import Counter
from contextlib import redirect_stdout
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import sid_cache  # noqa: E402
import sid_scan  # noqa: E402

FIXTURE = HERE / "fixtures" / "combatlog-sample.txt"
SPEC_TO_CLASS = {262: "SHAMAN", 264: "SHAMAN"}
RESTO = ("SHAMAN", 264)
ELE = ("SHAMAN", 262)
BUFF = "BUFF"
LOG_1 = "WoWCombatLog-092326_230936.txt"
LOG_2 = "WoWCombatLog-092426_201500.txt"


def quiet(*_args, **_kwargs):
    pass


class Folder:
    """A temp logs folder holding the fixture twice, and a separate temp cache folder."""

    def __init__(self, test):
        tmp = tempfile.TemporaryDirectory()
        test.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.logs = self.root / "logs"
        self.cache = self.root / "cache"
        self.logs.mkdir()
        for name in (LOG_1, LOG_2):
            shutil.copyfile(FIXTURE, self.logs / name)

    def scan(self):
        return sid_cache.scan_dir(self.logs, self.cache, SPEC_TO_CLASS, progress=quiet)

    def cache_files(self):
        return sorted((self.cache / "logs").glob("*.json"))


class CacheKey(unittest.TestCase):
    def test_key_is_name_size_and_whole_second_mtime(self):
        f = Folder(self)
        path = f.logs / LOG_1
        os.utime(path, (1790000000.75, 1790000000.75))
        size = path.stat().st_size
        self.assertEqual(sid_cache.cache_key(path), "%s-%d-1790000000" % (LOG_1, size))


class ScanDir(unittest.TestCase):
    def test_first_scan_reads_every_log_and_second_reads_none(self):
        f = Folder(self)
        first, s1 = f.scan()
        self.assertEqual((s1["files"], s1["read"], s1["cached"]), (2, 2, 0))
        second, s2 = f.scan()
        self.assertEqual((s2["files"], s2["read"], s2["cached"]), (2, 0, 2))
        self.assertEqual(sid_scan.aggregate_to_json(first), sid_scan.aggregate_to_json(second))
        for key in ("bytes", "first_date", "last_date", "skipped", "unattributed"):
            self.assertEqual(s1[key], s2[key], key)

    def test_summary_counts(self):
        f = Folder(self)
        agg, summary = f.scan()
        one = sid_scan.scan_file(FIXTURE, SPEC_TO_CLASS)
        self.assertEqual(summary["bytes"], 2 * FIXTURE.stat().st_size)
        self.assertEqual(summary["skipped"], 2 * one.skipped)
        self.assertEqual(summary["unattributed"], 2 * one.unattributed)
        self.assertEqual(summary["lines"], 2 * one.lines)
        self.assertEqual((summary["first_date"], summary["last_date"]), ("2026-09-23", "2026-09-24"))
        self.assertEqual((agg.first_date, agg.last_date), ("2026-09-23", "2026-09-24"))

    def test_a_log_that_changed_is_read_again(self):
        # Review Focus 4: a log the client is still writing is never served stale.
        f = Folder(self)
        f.scan()
        path = f.logs / LOG_2
        with open(path, "ab") as fh:
            fh.write(b"\r\n")
        st = path.stat()
        os.utime(path, (st.st_atime + 10, st.st_mtime + 10))
        _agg, summary = f.scan()
        self.assertEqual((summary["read"], summary["cached"]), (1, 1))

    def test_a_changed_log_replaces_its_old_cache_entry(self):
        f = Folder(self)
        f.scan()
        path = f.logs / LOG_2
        st = path.stat()
        os.utime(path, (st.st_atime + 10, st.st_mtime + 10))
        f.scan()
        names = [p.name for p in f.cache_files()]
        self.assertEqual(len(names), 2)
        self.assertIn(sid_cache.cache_key(path) + ".json", names)

    def test_other_files_in_the_folder_are_ignored(self):
        f = Folder(self)
        shutil.copyfile(FIXTURE, f.logs / "notes.txt")
        shutil.copyfile(FIXTURE, f.logs / "WoWCombatLog-092326_230936.txt.bak")
        (f.logs / "WoWCombatLog-dir.txt").mkdir()
        _agg, summary = f.scan()
        self.assertEqual(summary["files"], 2)

    def test_a_missing_logs_folder_is_an_error(self):
        f = Folder(self)
        with self.assertRaises(FileNotFoundError):
            sid_cache.scan_dir(f.root / "nope", f.cache, SPEC_TO_CLASS, progress=quiet)

    def test_a_corrupt_cache_entry_is_read_again(self):
        f = Folder(self)
        f.scan()
        f.cache_files()[0].write_text("{not json", encoding="utf-8")
        _agg, summary = f.scan()
        self.assertEqual((summary["read"], summary["cached"]), (1, 1))

    def test_a_different_spec_map_reads_again(self):
        # Class attribution depends on the spec map, so a cache made under another map is stale.
        f = Folder(self)
        f.scan()
        _agg, summary = sid_cache.scan_dir(f.logs, f.cache, {264: "SHAMAN"}, progress=quiet)
        self.assertEqual(summary["read"], 2)

    def test_progress_reports_each_log(self):
        f = Folder(self)
        seen = []
        sid_cache.scan_dir(f.logs, f.cache, SPEC_TO_CLASS, progress=seen.append)
        self.assertTrue(any(LOG_1 in m for m in seen))
        self.assertTrue(any(LOG_2 in m for m in seen))


class Privacy(unittest.TestCase):
    def test_cache_holds_no_guid_and_no_unit_name(self):
        f = Folder(self)
        f.scan()
        files = f.cache_files()
        self.assertEqual(len(files), 2)
        for path in files:
            text = path.read_text(encoding="utf-8")
            self.assertNotIn("Player-", text)
            self.assertNotIn("Realm", text)
            self.assertNotIn("Smith", text)

    def test_salt_is_created_once_and_reused(self):
        f = Folder(self)
        f.scan()
        salt_path = f.cache / "salt"
        salt = salt_path.read_bytes()
        self.assertEqual(len(salt), 32)
        path = f.logs / LOG_1
        st = path.stat()
        os.utime(path, (st.st_atime + 10, st.st_mtime + 10))
        f.scan()
        self.assertEqual(salt_path.read_bytes(), salt)
        self.assertEqual(sid_cache.load_salt(f.cache), salt)

    def test_a_new_salt_invalidates_the_cache(self):
        # Hashes from two salts never meet in one merge, or one player would count twice.
        f = Folder(self)
        f.scan()
        (f.cache / "salt").unlink()
        _agg, summary = f.scan()
        self.assertEqual(summary["read"], 2)

    def test_hashes_are_salted(self):
        f = Folder(self)
        agg, _ = f.scan()
        players = agg.per_spec[RESTO][(BUFF, 114052)].players
        self.assertTrue(players)
        unsalted = {sid_scan.hash_player(p) for p in
                    sid_scan.scan_file(FIXTURE, SPEC_TO_CLASS).per_spec[RESTO][(BUFF, 114052)].players}
        self.assertTrue(players.isdisjoint(unsalted))


def stats(**kw):
    base = dict(names=Counter({"Ascendance": 1}), applications=1, players={"h1"},
                first_seen="2026-09-23", last_seen="2026-09-23")
    base.update(kw)
    return sid_scan.AuraStats(**base)


class Merge(unittest.TestCase):
    def test_the_same_player_in_two_logs_counts_once(self):
        f = Folder(self)
        agg, _ = f.scan()
        one = sid_scan.scan_file(FIXTURE, SPEC_TO_CLASS)
        for spec_key, auras in one.per_spec.items():
            for aura_key, st in auras.items():
                merged = agg.per_spec[spec_key][aura_key]
                self.assertEqual(merged.applications, 2 * st.applications)
                self.assertEqual(len(merged.players), len(st.players))
                self.assertEqual(merged.self_, 2 * st.self_)
                self.assertEqual(merged.single, 2 * st.single)
                self.assertEqual(merged.group, 2 * st.group)

    def test_merge_sums_counts_and_unions_players(self):
        a = sid_scan.FileAggregate(lines=10, skipped=1, unattributed=2,
                                   first_date="2026-09-23", last_date="2026-09-23")
        a.per_spec[RESTO] = {(BUFF, 114052): stats(applications=3, players={"h1", "h2"}, self_=1,
                                                   single=1, group=1, other=1,
                                                   recast_samples=[90.0])}
        a.non_player[(BUFF, 2645)] = {"names": Counter({"Ghost Wolf": 2}), "applications": 2}
        b = sid_scan.FileAggregate(lines=5, skipped=0, unattributed=1,
                                   first_date="2026-08-01", last_date="2026-09-30")
        b.per_spec[RESTO] = {(BUFF, 114052): stats(names=Counter({"Ascendance": 2, "Ascend": 1}),
                                                   applications=4, players={"h2", "h3"}, self_=2,
                                                   single=0, group=2, recast_samples=[120.0],
                                                   first_seen="2026-08-01", last_seen="2026-09-30")}
        b.per_spec[ELE] = {(BUFF, 1219480): stats()}
        b.non_player[(BUFF, 2645)] = {"names": Counter({"Ghost Wolf": 1}), "applications": 1}
        m = sid_cache.merge([a, b])
        st = m.per_spec[RESTO][(BUFF, 114052)]
        self.assertEqual(st.applications, 7)
        self.assertEqual(st.players, {"h1", "h2", "h3"})
        self.assertEqual((st.self_, st.single, st.group, st.other), (3, 1, 3, 1))
        self.assertEqual(st.recast_samples, [90.0, 120.0])
        self.assertEqual(st.names, Counter({"Ascendance": 3, "Ascend": 1}))
        self.assertEqual((st.first_seen, st.last_seen), ("2026-08-01", "2026-09-30"))
        self.assertIn((BUFF, 1219480), m.per_spec[ELE])
        self.assertEqual(m.non_player[(BUFF, 2645)]["applications"], 3)
        self.assertEqual(m.non_player[(BUFF, 2645)]["names"], Counter({"Ghost Wolf": 3}))
        self.assertEqual((m.lines, m.skipped, m.unattributed), (15, 1, 3))
        self.assertEqual((m.first_date, m.last_date), ("2026-08-01", "2026-09-30"))

    def test_merge_caps_recast_samples(self):
        a = sid_scan.FileAggregate()
        a.per_spec[RESTO] = {(BUFF, 1): stats(recast_samples=[1.0] * 150)}
        b = sid_scan.FileAggregate()
        b.per_spec[RESTO] = {(BUFF, 1): stats(recast_samples=[2.0] * 150)}
        st = sid_cache.merge([a, b]).per_spec[RESTO][(BUFF, 1)]
        self.assertEqual(len(st.recast_samples), sid_scan.RECAST_SAMPLE_CAP)
        self.assertEqual(st.recast_samples[:150], [1.0] * 150)

    def test_merge_does_not_mutate_its_inputs(self):
        a = sid_scan.FileAggregate()
        a.per_spec[RESTO] = {(BUFF, 1): stats(players={"h1"})}
        b = sid_scan.FileAggregate()
        b.per_spec[RESTO] = {(BUFF, 1): stats(players={"h2"})}
        sid_cache.merge([a, b])
        self.assertEqual(a.per_spec[RESTO][(BUFF, 1)].players, {"h1"})
        self.assertEqual(a.per_spec[RESTO][(BUFF, 1)].applications, 1)

    def test_merge_of_nothing_is_empty(self):
        m = sid_cache.merge([])
        self.assertEqual((m.per_spec, m.non_player, m.lines, m.first_date), ({}, {}, 0, ""))


class Evidence(unittest.TestCase):
    def evidence(self):
        f = Folder(self)
        agg, summary = f.scan()
        return agg, summary, sid_cache.evidence_to_json(agg, summary)

    def test_evidence_holds_counts_never_hashes_or_guids(self):
        agg, _summary, ev = self.evidence()
        text = json.dumps(ev)
        self.assertNotIn("Player-", text)
        for auras in agg.per_spec.values():
            for st in auras.values():
                for h in st.players:
                    self.assertNotIn(h, text)

    def test_evidence_rows_are_per_class_spec_aura(self):
        agg, _summary, ev = self.evidence()
        rows = {(r["class"], r["spec"], r["auraType"], r["spellId"]): r for r in ev["auras"]}
        n = sum(len(a) for a in agg.per_spec.values())
        self.assertEqual(len(rows), n)
        row = rows[("SHAMAN", 264, BUFF, 114052)]
        st = agg.per_spec[RESTO][(BUFF, 114052)]
        self.assertEqual(row["applications"], st.applications)
        self.assertEqual(row["players"], len(st.players))
        self.assertEqual(row["name"], "Ascendance")
        self.assertEqual((row["self"], row["single"], row["group"]), (st.self_, st.single, st.group))

    def test_evidence_carries_summary_and_non_player(self):
        _agg, summary, ev = self.evidence()
        self.assertEqual(ev["summary"], summary)
        self.assertTrue(ev["nonPlayer"])
        for r in ev["nonPlayer"]:
            self.assertEqual(set(r), {"auraType", "spellId", "name", "names", "applications"})

    def test_recast_median(self):
        agg = sid_scan.FileAggregate()
        agg.per_spec[RESTO] = {(BUFF, 1): stats(recast_samples=[30.0, 90.0, 120.0]),
                               (BUFF, 2): stats()}
        ev = sid_cache.evidence_to_json(agg, {})
        med = {r["spellId"]: r["recastMedian"] for r in ev["auras"]}
        self.assertEqual(med, {1: 90.0, 2: None})

    def test_evidence_carries_exact_cross_spec_and_per_spec_player_counts(self):
        # Per-row counts cannot be merged; these two tables carry the unions the propose stage needs.
        agg = sid_scan.FileAggregate()
        agg.per_spec[RESTO] = {(BUFF, 1): stats(players={"h1", "h2"}), (BUFF, 2): stats(players={"h3"})}
        agg.per_spec[ELE] = {(BUFF, 1): stats(players={"h2", "h4"})}
        ev = sid_cache.evidence_to_json(agg, {})
        cp = {(r["class"], r["auraType"], r["spellId"]): r["players"] for r in ev["classPlayers"]}
        self.assertEqual(cp, {("SHAMAN", BUFF, 1): 3, ("SHAMAN", BUFF, 2): 1})
        sp = {(r["class"], r["spec"]): r["players"] for r in ev["specPlayers"]}
        self.assertEqual(sp, {RESTO: 3, ELE: 2})
        for h in ("h1", "h2", "h3", "h4"):
            self.assertNotIn(h, json.dumps(ev))
        back = sid_cache.evidence_from_json(json.loads(json.dumps(ev)))
        self.assertEqual(back.class_players, cp)
        self.assertEqual(back.spec_players, sp)

    def test_evidence_without_the_player_tables_still_reads(self):
        ev = sid_cache.evidence_to_json(sid_scan.FileAggregate(), {})
        del ev["classPlayers"], ev["specPlayers"]
        back = sid_cache.evidence_from_json(ev)
        self.assertEqual((back.class_players, back.spec_players), ({}, {}))

    def test_evidence_rows_carry_other(self):
        agg = sid_scan.FileAggregate()
        agg.per_spec[RESTO] = {(BUFF, 114052): stats(applications=3, self_=1, other=2)}
        row = sid_cache.evidence_to_json(agg, {})["auras"][0]
        self.assertEqual((row["self"], row["single"], row["other"]), (1, 0, 2))
        back = sid_cache.evidence_from_json(json.loads(json.dumps(sid_cache.evidence_to_json(agg, {}))))
        self.assertEqual(back.per_spec[RESTO][(BUFF, 114052)].other, 2)

    def test_evidence_round_trips_into_an_aggregate(self):
        agg, _summary, ev = self.evidence()
        back = sid_cache.evidence_from_json(json.loads(json.dumps(ev)))
        self.assertEqual(set(back.per_spec), set(agg.per_spec))
        for spec_key, auras in agg.per_spec.items():
            for aura_key, st in auras.items():
                b = back.per_spec[spec_key][aura_key]
                self.assertEqual(b.applications, st.applications)
                self.assertEqual(len(b.players), len(st.players))
                self.assertEqual((b.self_, b.single, b.group, b.other),
                                 (st.self_, st.single, st.group, st.other))
                self.assertEqual(b.names, st.names)
        self.assertEqual(set(back.non_player), set(agg.non_player))
        self.assertEqual((back.unattributed, back.skipped), (agg.unattributed, agg.skipped))


class ScanCli(unittest.TestCase):
    def test_scan_writes_crlf_evidence_and_prints_the_summary(self):
        import logs
        f = Folder(self)
        out = f.root / "bundle" / "evidence.json"
        orig = logs.spec_to_class_from_db2
        logs.spec_to_class_from_db2 = lambda db2_cache, build=None: dict(SPEC_TO_CLASS)
        self.addCleanup(setattr, logs, "spec_to_class_from_db2", orig)
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = logs.main(["scan", "--logs", str(f.logs), "--cache", str(f.cache),
                            "--db2-cache", str(f.root), "--out", str(out)])
        self.assertEqual(rc, 0)
        raw = out.read_bytes()
        self.assertIn(b"\r\n", raw)
        self.assertNotIn(b"\n", raw.replace(b"\r\n", b""))
        ev = json.loads(raw.decode("utf-8"))
        self.assertEqual(ev["summary"]["files"], 2)
        self.assertNotIn("Player-", raw.decode("utf-8"))
        self.assertIn("2 logs", buf.getvalue())

    def test_scan_requires_out(self):
        import logs
        with redirect_stdout(io.StringIO()), self.assertRaises(SystemExit):
            with open(os.devnull, "w") as devnull:
                old = sys.stderr
                sys.stderr = devnull
                try:
                    logs.main(["scan"])
                finally:
                    sys.stderr = old


if __name__ == "__main__":
    unittest.main()
