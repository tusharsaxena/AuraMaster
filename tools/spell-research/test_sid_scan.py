"""Tests for sid_scan: combat log line parsing, player filter, spec tracking.

Run: python3 -m unittest discover -s tools/spell-research -p 'test_*.py'
"""

import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import sid_scan  # noqa: E402

FIXTURE = HERE / "fixtures" / "combatlog-sample.txt"

A = "Player-1-0000000A"
B = "Player-1-0000000B"
C = "Player-1-0000000C"


def fixture_lines():
    """The fixture's raw lines, terminators kept, exactly as a scan reads them."""
    with open(FIXTURE, "rb") as fh:
        return list(fh)


def parsed(event=None):
    out = []
    for raw in fixture_lines():
        ev = sid_scan.parse_event(raw)
        if ev is not None and (event is None or ev[1] == event):
            out.append(ev)
    return out


class FixtureShape(unittest.TestCase):
    def test_fixture_is_crlf_with_an_unterminated_last_line(self):
        lines = fixture_lines()
        self.assertGreaterEqual(len(lines), 30)
        for raw in lines[:-1]:
            self.assertTrue(raw.endswith(b"\r\n"), raw[:60])
        self.assertFalse(lines[-1].endswith(b"\n"))


class SplitFields(unittest.TestCase):
    def test_comma_inside_quotes_is_kept(self):
        self.assertEqual(sid_scan.split_fields('a,"b,c",d'), ["a", '"b,c"', "d"])

    def test_empty_fields_survive(self):
        self.assertEqual(sid_scan.split_fields("a,,b"), ["a", "", "b"])

    def test_unterminated_quote_is_rejected(self):
        self.assertEqual(sid_scan.split_fields('a,"b,c'), [])

    def test_unquote(self):
        self.assertEqual(sid_scan.unquote('"Smith, the Bold-Realm-US"'), "Smith, the Bold-Realm-US")
        self.assertEqual(sid_scan.unquote("nil"), "nil")
        self.assertEqual(sid_scan.unquote('"'), '"')


class ParseEvent(unittest.TestCase):
    LINE = (b'9/23/2026 23:10:51.1345  SPELL_AURA_APPLIED,Player-1-0000000A,"Tester-Realm-US",'
            b'0x511,0x80000000,Player-1-0000000A,"Tester-Realm-US",0x511,0x80000000,'
            b'114052,"Ascendance",0x8,BUFF\r\n')

    def test_aura_line(self):
        date, event, fields = sid_scan.parse_event(self.LINE)
        self.assertEqual(date, "2026-09-23")
        self.assertEqual(event, "SPELL_AURA_APPLIED")
        self.assertEqual(fields[0], A)
        self.assertEqual(fields[8], "114052")
        self.assertEqual(fields[9], '"Ascendance"')
        self.assertEqual(fields[11], "BUFF")

    def test_fixture_aura_line_matches(self):
        auras = parsed("SPELL_AURA_APPLIED")
        self.assertTrue(auras)
        date, event, fields = auras[0]
        self.assertEqual(date, "2026-09-23")
        self.assertEqual(fields[8], "108271")
        self.assertEqual(fields[11], "BUFF")

    def test_comma_in_unit_name_keeps_later_fields_aligned(self):
        # Review Focus 1: "Smith, the Bold-Realm-US" is one field.
        rows = [f for _, _, f in parsed("SPELL_AURA_APPLIED") if f[0] == B]
        self.assertTrue(rows)
        for f in rows:
            self.assertEqual(f[1], '"Smith, the Bold-Realm-US"')
            self.assertEqual(f[2], "0x514")
            self.assertIn(f[11], ("BUFF", "DEBUFF"))

    def test_comma_in_spell_name_keeps_later_fields_aligned(self):
        rows = [f for _, _, f in parsed("SPELL_AURA_APPLIED") if f[8] == "999001"]
        self.assertEqual(len(rows), 1)
        self.assertEqual(sid_scan.unquote(rows[0][9]), "Earth, Wind and Fire")
        self.assertEqual(rows[0][10], "0x8")
        self.assertEqual(rows[0][11], "BUFF")

    def test_truncated_last_line_is_none(self):
        # Review Focus 2: the client was killed mid-write.
        self.assertIsNone(sid_scan.parse_event(fixture_lines()[-1]))

    def test_every_other_fixture_line_parses(self):
        lines = fixture_lines()
        for raw in lines[:-1]:
            self.assertIsNotNone(sid_scan.parse_event(raw), raw[:80])

    def test_garbage_is_none(self):
        for raw in (b"", b"\r\n", b"no separator here\r\n", b"xx/yy/zzzz 1:2:3  EVENT,1\r\n",
                    b"9/23/2026 23:10:51.1345  \xff\xfe,1\r\n", b"9/23/2026 23:10:51.1345  EVENTONLY\r\n",
                    b"9/23 23:10:51.1345  EVENT,1\r\n"):
            self.assertIsNone(sid_scan.parse_event(raw), raw)

    def test_utf8_names_decode(self):
        line = ('9/23/2026 23:10:51.1345  SPELL_AURA_APPLIED,Player-1-0000000A,"Artêmîs-Realm-US",'
                '0x511,0x80000000,Player-1-0000000A,"Artêmîs-Realm-US",0x511,0x80000000,'
                '114052,"Ascendance",0x8,BUFF\r\n').encode("utf-8")
        _, _, fields = sid_scan.parse_event(line)
        self.assertEqual(sid_scan.unquote(fields[1]), "Artêmîs-Realm-US")
        self.assertEqual(fields[8], "114052")


class ParseAuraApplied(unittest.TestCase):
    def test_fixture_rows(self):
        rows = [sid_scan.parse_aura_applied(f) for _, _, f in parsed("SPELL_AURA_APPLIED")]
        self.assertNotIn(None, rows)
        first = rows[0]
        self.assertEqual(first.source, C)
        self.assertEqual(first.source_flags, "0x514")
        self.assertEqual(first.dest, C)
        self.assertEqual(first.spell_id, 108271)
        self.assertEqual(first.spell_name, "Astral Shift")
        self.assertEqual(first.aura_type, "BUFF")

    def test_trailing_amount_is_accepted(self):
        rows = [sid_scan.parse_aura_applied(f) for _, _, f in parsed("SPELL_AURA_APPLIED")]
        amounts = [r for r in rows if r.source == B and r.spell_id == 108271]
        self.assertEqual(len(amounts), 1)

    def test_short_or_garbled_payloads_are_none(self):
        good = sid_scan.split_fields(
            'Player-1-0000000A,"T-R-US",0x511,0x80000000,Player-1-0000000A,"T-R-US",0x511,0x80000000,'
            '114052,"Ascendance",0x8,BUFF')
        self.assertIsNotNone(sid_scan.parse_aura_applied(good))
        self.assertIsNone(sid_scan.parse_aura_applied(good[:11]))  # fewer than 12 fields
        cut = good[:11] + ["BU"]                                      # truncated outside a quote
        self.assertIsNone(sid_scan.parse_aura_applied(cut))
        bad_id = good[:8] + ["11405x"] + good[9:]
        self.assertIsNone(sid_scan.parse_aura_applied(bad_id))
        zero_id = good[:8] + ["0"] + good[9:]
        self.assertIsNone(sid_scan.parse_aura_applied(zero_id))


class PlayerFilter(unittest.TestCase):
    def test_player(self):
        self.assertTrue(sid_scan.is_player_source(A, "0x511"))
        self.assertTrue(sid_scan.is_player_source(B, "0x514"))
        self.assertTrue(sid_scan.is_player_source(A, "0x10511"))  # real-log flag with a raid-target bit

    def test_pet_and_creature(self):
        self.assertFalse(sid_scan.is_player_source("Pet-0-1", "0x1111"))
        self.assertFalse(sid_scan.is_player_source("Creature-0-1", "0xa48"))

    def test_player_guid_without_player_type_bit(self):
        self.assertFalse(sid_scan.is_player_source("Player-1-2", "0x1112"))

    def test_player_type_without_player_control(self):
        # Mind-controlled / NPC-controlled player: type bit set, control bit clear.
        self.assertFalse(sid_scan.is_player_source(A, "0x0412"))

    def test_non_player_guid_with_player_bits(self):
        self.assertFalse(sid_scan.is_player_source("Creature-0-1", "0x511"))

    def test_garbled_flags(self):
        self.assertFalse(sid_scan.is_player_source(A, "nil"))
        self.assertFalse(sid_scan.is_player_source(A, ""))

    def test_fixture_sources(self):
        kinds = {}
        for _, _, f in parsed("SPELL_AURA_APPLIED"):
            kinds.setdefault(f[0].split("-")[0], set()).add(sid_scan.is_player_source(f[0], f[2]))
        self.assertEqual(kinds, {"Player": {True}, "Pet": {False}, "Creature": {False}})


class SpecTracking(unittest.TestCase):
    def test_fixture_combatant_info(self):
        tracker = sid_scan.SpecTracker()
        for _, _, fields in parsed("COMBATANT_INFO"):
            tracker.observe_combatant_info(fields)
        self.assertEqual(tracker.spec_of(A), 264)
        self.assertEqual(tracker.spec_of(B), 262)
        self.assertEqual(tracker.spec_of(C), 264)
        self.assertIsNone(tracker.spec_of("Player-1-0000FFFF"))

    def test_forward_only(self):
        # C's first aura comes before C's COMBATANT_INFO: at that point C is unknown.
        tracker = sid_scan.SpecTracker()
        seen = []
        for _, event, fields in parsed():
            if event == "COMBATANT_INFO":
                tracker.observe_combatant_info(fields)
            elif event == "SPELL_AURA_APPLIED" and fields[0] == C:
                seen.append(tracker.spec_of(C))
        self.assertEqual(seen, [None, 264, 264])

    def test_observe_returns_spec_and_rejects_garbage(self):
        tracker = sid_scan.SpecTracker()
        _, _, fields = parsed("COMBATANT_INFO")[0]
        self.assertEqual(tracker.observe_combatant_info(fields), 264)
        self.assertIsNone(tracker.observe_combatant_info([A, "0", "264"]))    # too short
        short = list(fields)
        short[sid_scan.COMBATANT_SPEC_INDEX] = "x"
        self.assertIsNone(tracker.observe_combatant_info(short))
        self.assertEqual(tracker.spec_of(A), 264)                              # unchanged
        not_player = ["Creature-0-1"] + list(fields[1:])
        self.assertIsNone(tracker.observe_combatant_info(not_player))

    def test_later_combatant_info_wins(self):
        tracker = sid_scan.SpecTracker()
        _, _, fields = parsed("COMBATANT_INFO")[0]
        tracker.observe_combatant_info(fields)
        respec = list(fields)
        respec[sid_scan.COMBATANT_SPEC_INDEX] = "263"
        tracker.observe_combatant_info(respec)
        self.assertEqual(tracker.spec_of(A), 263)

    def test_class_of_guid(self):
        tracker = sid_scan.SpecTracker({262: "SHAMAN", 264: "SHAMAN"})
        for _, _, fields in parsed("COMBATANT_INFO"):
            tracker.observe_combatant_info(fields)
        self.assertEqual(tracker.class_of(A), "SHAMAN")
        self.assertIsNone(tracker.class_of("Player-1-0000FFFF"))
        self.assertIsNone(sid_scan.SpecTracker().class_of(A))



# --- SID-2: per-file aggregates ------------------------------------------------

import json  # noqa: E402
import shutil  # noqa: E402
import tempfile  # noqa: E402

SPEC_TO_CLASS = {262: "SHAMAN", 264: "SHAMAN"}
RESTO = ("SHAMAN", 264)
ELE = ("SHAMAN", 262)
BUFF = "BUFF"


def scan_fixture():
    return sid_scan.scan_file(FIXTURE, SPEC_TO_CLASS)


def aura_line(stamp, source, dest, spell_id, name="Test Aura", aura_type="BUFF",
              flags="0x511", dest_flags="0x514"):
    return ('9/23/2026 %s  SPELL_AURA_APPLIED,%s,"Src-Realm-US",%s,0x80000000,%s,"Dst-Realm-US",'
            '%s,0x80000000,%d,"%s",0x8,%s\r\n' % (stamp, source, flags, dest, dest_flags,
                                                   spell_id, name, aura_type))


def combatant_line(stamp, guid, spec):
    stats = ",".join(str(100 + i) for i in range(22))
    return "9/23/2026 %s  COMBATANT_INFO,%s,0,%s,%d,[],(0,0,0,0),[],[],0\r\n" % (stamp, guid, stats, spec)


class TempLog:
    """A log written under a temporary folder with a given file name."""

    def __init__(self, test, text, name="WoWCombatLog-092326_230936.txt"):
        tmp = tempfile.mkdtemp(prefix="sid-scan-")
        test.addCleanup(shutil.rmtree, tmp, True)
        self.path = Path(tmp) / name
        with open(self.path, "wb") as fh:
            fh.write(text.encode("utf-8") if isinstance(text, str) else text)


def synthetic(test, body_lines, spec=264):
    text = combatant_line("23:00:00.0000", A, spec) + "".join(body_lines)
    return sid_scan.scan_file(TempLog(test, text).path, SPEC_TO_CLASS)


class ScanFileAttribution(unittest.TestCase):
    def test_restoration_ascendance_lands_under_restoration(self):
        agg = scan_fixture()
        st = agg.per_spec[RESTO][(BUFF, 114052)]
        self.assertEqual(st.applications, 2)
        self.assertEqual(st.names, {"Ascendance": 2})
        self.assertNotIn((BUFF, 114052), agg.per_spec.get(ELE, {}))

    def test_elemental_ascendance_lands_under_elemental(self):
        agg = scan_fixture()
        self.assertEqual(agg.per_spec[ELE][(BUFF, 1219480)].applications, 1)
        self.assertNotIn((BUFF, 1219480), agg.per_spec[RESTO])

    def test_spec_keys_are_class_and_spec(self):
        self.assertEqual(set(scan_fixture().per_spec), {RESTO, ELE})

    def test_forward_only_attribution(self):
        # Review Focus 3: C's first Astral Shift precedes C's COMBATANT_INFO.
        agg = scan_fixture()
        self.assertEqual(agg.unattributed, 1)
        # C's later Astral Shift (after the COMBATANT_INFO) is attributed.
        st = agg.per_spec[RESTO][(BUFF, 108271)]
        self.assertEqual(st.applications, 1)
        self.assertEqual(len(st.players), 1)
        self.assertEqual(agg.per_spec[ELE][(BUFF, 108271)].applications, 1)

    def test_spec_missing_from_the_map_is_unattributed(self):
        agg = sid_scan.scan_file(FIXTURE, {262: "SHAMAN"})
        self.assertNotIn(RESTO, agg.per_spec)
        self.assertIn(ELE, agg.per_spec)
        self.assertGreater(agg.unattributed, 1)

    def test_no_combatant_info_at_all(self):
        text = aura_line("23:00:01.0000", B, B, 108271)
        agg = sid_scan.scan_file(TempLog(self, text).path, SPEC_TO_CLASS)
        self.assertEqual(agg.per_spec, {})
        self.assertEqual(agg.unattributed, 1)

    def test_players_are_distinct_casters(self):
        agg = scan_fixture()
        self.assertEqual(agg.per_spec[RESTO][(BUFF, 974)].players, {A, C})
        self.assertEqual(agg.per_spec[RESTO][(BUFF, 974)].applications, 2)

    def test_debuff_on_a_creature_is_kept_as_a_debuff(self):
        st = scan_fixture().per_spec[RESTO][("DEBUFF", 188389)]
        self.assertEqual(st.applications, 1)
        # The Training Dummy is no player: `single` is one other PLAYER (the spec), so `other`.
        self.assertEqual((st.single, st.other), (0, 1))


class ScanFileNonPlayer(unittest.TestCase):
    def test_pet_and_creature_sources_only_in_non_player(self):
        agg = scan_fixture()
        self.assertEqual(agg.non_player[(BUFF, 58875)]["applications"], 2)
        self.assertEqual(agg.non_player[(BUFF, 58875)]["names"], {"Spirit Walk": 2})
        self.assertEqual(agg.non_player[("DEBUFF", 388539)]["applications"], 1)
        for auras in agg.per_spec.values():
            self.assertNotIn((BUFF, 58875), auras)
            self.assertNotIn(("DEBUFF", 388539), auras)

    def test_player_guid_without_player_control_is_non_player(self):
        agg = synthetic(self, [aura_line("23:00:01.0000", A, A, 5555, flags="0x0412")])
        self.assertEqual(agg.per_spec, {})
        self.assertEqual(agg.non_player[(BUFF, 5555)]["applications"], 1)
        self.assertEqual(agg.unattributed, 0)


class ScanFileShapes(unittest.TestCase):
    def test_six_target_burst_is_one_group(self):
        st = scan_fixture().per_spec[RESTO][(BUFF, 201633)]
        self.assertEqual(st.applications, 6)
        self.assertEqual(st.group, 1)
        self.assertEqual(st.single, 0)
        self.assertEqual(st.self_, 0)

    def test_self_and_single(self):
        agg = scan_fixture()
        self.assertEqual(agg.per_spec[RESTO][(BUFF, 114052)].self_, 2)
        self.assertEqual(agg.per_spec[RESTO][(BUFF, 114052)].single, 0)
        earth_shield = agg.per_spec[RESTO][(BUFF, 974)]
        self.assertEqual((earth_shield.self_, earth_shield.single, earth_shield.group), (0, 2, 0))

    def test_four_targets_stay_single(self):
        lines = [aura_line("23:00:01.%d000" % i, A, "Player-1-000000%d0" % i, 7777) for i in range(4)]
        st = synthetic(self, lines).per_spec[RESTO][(BUFF, 7777)]
        self.assertEqual((st.single, st.group), (4, 0))

    def test_fifth_distinct_target_converts_the_window(self):
        lines = [aura_line("23:00:01.%d000" % i, A, "Player-1-000000%d0" % i, 7777) for i in range(5)]
        st = synthetic(self, lines).per_spec[RESTO][(BUFF, 7777)]
        self.assertEqual((st.applications, st.single, st.group), (5, 0, 1))

    def test_repeat_target_does_not_count_twice(self):
        dests = ["Player-1-00000010", "Player-1-00000010", "Player-1-00000020",
                 "Player-1-00000030", "Player-1-00000040"]
        lines = [aura_line("23:00:01.%d000" % i, A, d, 7777) for i, d in enumerate(dests)]
        st = synthetic(self, lines).per_spec[RESTO][(BUFF, 7777)]
        self.assertEqual((st.single, st.group), (5, 0))

    def test_window_is_one_second_from_its_start(self):
        stamps = ["23:00:01.0000", "23:00:01.3000", "23:00:01.6000", "23:00:01.9000", "23:00:02.2000"]
        lines = [aura_line(s, A, "Player-1-000000%d0" % i, 7777) for i, s in enumerate(stamps)]
        st = synthetic(self, lines).per_spec[RESTO][(BUFF, 7777)]
        # The fifth falls 1.2 s after the window opened: it opens a new window.
        self.assertEqual((st.single, st.group), (5, 0))

    def test_two_bursts_count_twice(self):
        lines = []
        for start in ("23:00:01", "23:00:30"):
            lines += [aura_line("%s.%d000" % (start, i), A, "Player-1-000000%d0" % i, 7777) for i in range(6)]
        st = synthetic(self, lines).per_spec[RESTO][(BUFF, 7777)]
        self.assertEqual((st.applications, st.single, st.group), (12, 0, 2))

    def test_self_inside_a_burst_is_absorbed(self):
        lines = [aura_line("23:00:01.0000", A, A, 7777)]
        lines += [aura_line("23:00:01.%d000" % (i + 1), A, "Player-1-000000%d0" % i, 7777) for i in range(4)]
        st = synthetic(self, lines).per_spec[RESTO][(BUFF, 7777)]
        self.assertEqual((st.self_, st.single, st.group), (0, 0, 1))

    def test_a_pet_or_guardian_target_is_other_never_single(self):
        # SID-10, the real run: Infernal Command 387552 (onto the warlock's demons, Creature-
        # guardians) and Beast Cleave 118455 (onto the hunter's Pet-) read as 70%+ single and R5
        # filed them under Support. `single` is one other PLAYER (the spec).
        lines = [aura_line("23:00:01.0000", A, "Pet-0-1-1-1-1-00000001", 7777, dest_flags="0x1111"),
                 aura_line("23:00:05.0000", A, "Creature-0-1-1-1-1-00000002", 7777,
                           dest_flags="0x2111"),
                 aura_line("23:00:09.0000", A, "Player-1-00000010", 7777)]
        st = synthetic(self, lines).per_spec[RESTO][(BUFF, 7777)]
        self.assertEqual((st.applications, st.self_, st.single, st.group, st.other), (3, 0, 1, 0, 2))

    def test_only_players_make_a_burst(self):
        # 3 players and 3 guardians inside a second: not 5 distinct PLAYERS, so no burst.
        lines = [aura_line("23:00:01.%d000" % i, A, "Player-1-000000%d0" % i, 7777) for i in range(3)]
        lines += [aura_line("23:00:01.%d000" % (i + 3), A, "Creature-0-1-1-1-1-0000000%d" % i, 7777,
                            dest_flags="0x2111") for i in range(3)]
        st = synthetic(self, lines).per_spec[RESTO][(BUFF, 7777)]
        self.assertEqual((st.single, st.group, st.other), (3, 0, 3))

    def test_other_round_trips_through_json(self):
        lines = [aura_line("23:00:01.0000", A, "Pet-0-1-1-1-1-00000001", 7777, dest_flags="0x1111")]
        agg = synthetic(self, lines)
        back = sid_scan.aggregate_from_json(sid_scan.aggregate_to_json(agg))
        self.assertEqual(back.per_spec[RESTO][(BUFF, 7777)].other, 1)

    def test_bursts_are_per_caster(self):
        lines = [aura_line("23:00:01.%d000" % i, A if i % 2 else C, "Player-1-000000%d0" % i, 7777)
                 for i in range(6)]
        text = combatant_line("23:00:00.0000", A, 264) + combatant_line("23:00:00.0000", C, 264) + "".join(lines)
        st = sid_scan.scan_file(TempLog(self, text).path, SPEC_TO_CLASS).per_spec[RESTO][(BUFF, 7777)]
        self.assertEqual((st.single, st.group), (6, 0))


class ScanFileRecast(unittest.TestCase):
    def test_fixture_ascendance_recast(self):
        st = scan_fixture().per_spec[RESTO][(BUFF, 114052)]
        self.assertEqual(st.recast_samples, [90.0])

    def test_single_self_application_has_no_sample(self):
        # B's one application (23:10:52) is followed by B's refresh (23:12:30): one recast of 98 s.
        self.assertEqual(scan_fixture().per_spec[ELE][(BUFF, 1219480)].recast_samples, [98.0])
        lines = [aura_line("23:00:01.0000", A, A, 7777)]
        self.assertEqual(synthetic(self, lines).per_spec[RESTO][(BUFF, 7777)].recast_samples, [])

    def test_two_casters_applications_are_not_one_casters_recast(self):
        # Earth Shield 974: A onto B (23:10:53), C onto A (23:11:30), A refreshes B (23:11:41).
        # Recast is per caster: A's 48 s only, never the 37 s to C's application.
        self.assertEqual(scan_fixture().per_spec[RESTO][(BUFF, 974)].recast_samples, [48.0])

    def test_a_hot_recast_onto_different_targets_is_measured(self):
        # SID-11: a HoT applied every 8 s, each time to another player, never to the caster.
        # Measured on self-applications only, it had no recast, failed R6 and was proposed
        # Healing -> Support.
        lines = [aura_line("23:00:%02d.0000" % (i * 8), A, "Player-1-000000%d0" % (i % 4 + 1), 7777)
                 for i in range(6)]
        st = synthetic(self, lines).per_spec[RESTO][(BUFF, 7777)]
        self.assertEqual(st.recast_samples, [8.0] * 5)

    def test_a_recast_mixes_self_and_other_targets(self):
        lines = [aura_line("23:00:00.0000", A, A, 7777),
                 aura_line("23:00:06.0000", A, "Player-1-00000010", 7777),
                 aura_line("23:00:16.0000", A, A, 7777)]
        st = synthetic(self, lines).per_spec[RESTO][(BUFF, 7777)]
        self.assertEqual(st.recast_samples, [6.0, 10.0])

    def test_one_cast_onto_many_targets_is_one_recast(self):
        # A burst (0.1 s apart) and a self-copy are one cast: no near-zero samples.
        lines = [aura_line("23:00:01.%d000" % i, A, "Player-1-000000%d0" % i, 7777) for i in range(6)]
        lines += [aura_line("23:00:11.%d000" % i, A, "Player-1-000000%d0" % i, 7777) for i in range(6)]
        st = synthetic(self, lines).per_spec[RESTO][(BUFF, 7777)]
        self.assertEqual(st.recast_samples, [10.0])

    def test_a_refresh_by_the_same_caster_is_a_recast(self):
        # SID-11, the real run: Lifebloom and Rejuvenation kept rolling on one target log
        # SPELL_AURA_REFRESH, not APPLIED; without refreshes Lifebloom's recast read 32 s.
        lines = [aura_line("23:00:00.0000", A, "Player-1-00000010", 7777)]
        lines += [aura_line("23:00:%02d.0000" % (8 * i), A, "Player-1-00000010", 7777)
                  .replace("SPELL_AURA_APPLIED", "SPELL_AURA_REFRESH") for i in range(1, 4)]
        st = synthetic(self, lines).per_spec[RESTO][(BUFF, 7777)]
        self.assertEqual(st.recast_samples, [8.0, 8.0, 8.0])
        self.assertEqual((st.applications, st.single), (1, 1))

    def test_a_refresh_before_any_application_or_by_a_non_player_is_ignored(self):
        lines = [aura_line("23:00:00.0000", A, "Player-1-00000010", 7777)
                 .replace("SPELL_AURA_APPLIED", "SPELL_AURA_REFRESH"),
                 aura_line("23:00:05.0000", A, "Player-1-00000010", 7777),
                 aura_line("23:00:09.0000", "Pet-0-1-1-1-1-00000001", "Player-1-00000010", 7777,
                           flags="0x1111").replace("SPELL_AURA_APPLIED", "SPELL_AURA_REFRESH")]
        agg = synthetic(self, lines)
        st = agg.per_spec[RESTO][(BUFF, 7777)]
        self.assertEqual((st.applications, st.recast_samples), (1, []))
        self.assertNotIn((BUFF, 7777), agg.non_player)

    def test_recasts_onto_pets_count_too(self):
        lines = [aura_line("23:00:00.0000", A, "Pet-0-1-1-1-1-00000001", 7777, dest_flags="0x1111"),
                 aura_line("23:00:12.0000", A, "Pet-0-1-1-1-1-00000001", 7777, dest_flags="0x1111")]
        st = synthetic(self, lines).per_spec[RESTO][(BUFF, 7777)]
        self.assertEqual(st.recast_samples, [12.0])

    def test_samples_are_capped(self):
        lines = ["9/23/2026 23:%02d:%02d.0000  " % divmod(i * 2, 60) + aura_line("x", A, A, 7777).split("  ", 1)[1]
                 for i in range(1, 260)]
        st = synthetic(self, lines).per_spec[RESTO][(BUFF, 7777)]
        self.assertEqual(len(st.recast_samples), sid_scan.RECAST_SAMPLE_CAP)
        self.assertEqual(sid_scan.RECAST_SAMPLE_CAP, 200)
        self.assertEqual(set(st.recast_samples), {2.0})

    def test_recast_across_midnight(self):
        text = (combatant_line("23:00:00.0000", A, 264) + aura_line("23:59:30.0000", A, A, 7777)
                + aura_line("00:00:30.0000", A, A, 7777).replace("9/23/2026", "9/24/2026"))
        st = sid_scan.scan_file(TempLog(self, text).path, SPEC_TO_CLASS).per_spec[RESTO][(BUFF, 7777)]
        self.assertEqual(st.recast_samples, [60.0])


class ScanFileExternalSelfCopy(unittest.TestCase):
    """SID-11: an external logged on the caster AND one other player at once is one application.

    Power Infusion 10060, Blessing of Sacrifice 6940 and Guardian Spirit 47788 show up in the logs
    as two SPELL_AURA_APPLIED lines at the same moment from the same caster: one on the target, one
    on the caster. Counted as self + single, R5 (70% single) never saw them.
    """

    def pair(self, stamp, spell_id, dest="Player-1-00000010", self_first=True, gap="0500"):
        a = aura_line("%s.0000" % stamp, A, A, spell_id)
        b = aura_line("%s.%s" % (stamp, gap), A, dest, spell_id)
        if not self_first:
            a = aura_line("%s.0000" % stamp, A, dest, spell_id)
            b = aura_line("%s.%s" % (stamp, gap), A, A, spell_id)
        return [a, b]

    def shape_of(self, lines, spell_id):
        st = synthetic(self, lines).per_spec[RESTO][(BUFF, spell_id)]
        return (st.applications, st.self_, st.single, st.group)

    def test_power_infusion_self_copy_is_one_single(self):
        lines = self.pair("23:00:01", 10060) + self.pair("23:02:01", 10060)
        self.assertEqual(self.shape_of(lines, 10060), (2, 0, 2, 0))

    def test_blessing_of_sacrifice_other_first_then_self(self):
        lines = self.pair("23:00:01", 6940, self_first=False)
        self.assertEqual(self.shape_of(lines, 6940), (1, 0, 1, 0))

    def test_guardian_spirit_on_the_same_timestamp(self):
        lines = self.pair("23:00:01", 47788, gap="0000")
        self.assertEqual(self.shape_of(lines, 47788), (1, 0, 1, 0))

    def test_more_than_a_tenth_of_a_second_apart_is_two_applications(self):
        lines = self.pair("23:00:01", 10060, gap="2000")
        self.assertEqual(self.shape_of(lines, 10060), (2, 1, 1, 0))

    def test_self_and_two_others_at_once_is_not_an_external(self):
        lines = self.pair("23:00:01", 7777) + [aura_line("23:00:01.0800", A, "Player-1-00000020", 7777)]
        self.assertEqual(self.shape_of(lines, 7777), (3, 1, 2, 0))

    def test_another_casters_application_is_no_copy(self):
        lines = [aura_line("23:00:01.0000", A, A, 7777),
                 aura_line("23:00:01.0500", C, "Player-1-00000010", 7777)]
        text = combatant_line("23:00:00.0000", A, 264) + combatant_line("23:00:00.0000", C, 264) + "".join(lines)
        st = sid_scan.scan_file(TempLog(self, text).path, SPEC_TO_CLASS).per_spec[RESTO][(BUFF, 7777)]
        self.assertEqual((st.applications, st.self_, st.single), (2, 1, 1))

    def test_another_aura_is_no_copy(self):
        lines = [aura_line("23:00:01.0000", A, A, 7777),
                 aura_line("23:00:01.0500", A, "Player-1-00000010", 7778)]
        agg = synthetic(self, lines)
        self.assertEqual(agg.per_spec[RESTO][(BUFF, 7777)].self_, 1)
        self.assertEqual(agg.per_spec[RESTO][(BUFF, 7778)].single, 1)

    def test_a_pair_that_grows_into_a_burst_is_one_group_of_every_application(self):
        lines = self.pair("23:00:01", 7777)
        lines += [aura_line("23:00:01.%d000" % (i + 5), A, "Player-1-000000%d0" % (i + 2), 7777)
                  for i in range(3)]
        self.assertEqual(self.shape_of(lines, 7777), (5, 0, 0, 1))

    def test_shapes_stay_consistent_through_json(self):
        lines = self.pair("23:00:01", 10060)
        agg = synthetic(self, lines)
        back = sid_scan.aggregate_from_json(sid_scan.aggregate_to_json(agg))
        st = back.per_spec[RESTO][(BUFF, 10060)]
        self.assertEqual((st.applications, st.self_, st.single), (1, 0, 1))


class ScanFileCountsAndDates(unittest.TestCase):
    def test_lines_and_skipped(self):
        agg = scan_fixture()
        self.assertEqual(agg.lines, len(fixture_lines()))
        self.assertEqual(agg.skipped, 1)

    def test_garbled_aura_and_blank_lines_are_skipped(self):
        agg = synthetic(self, [
            "9/23/2026 23:00:01.0000  SPELL_AURA_APPLIED,Player-1-0000000A,short\r\n",
            "\r\n",
            "9/23/2026 23:00:02.0000  SOME_FUTURE_EVENT,1,2,3\r\n",
            aura_line("23:00:03.0000", A, A, 7777),
        ])
        self.assertEqual(agg.lines, 5)
        self.assertEqual(agg.skipped, 2)
        self.assertEqual(agg.per_spec[RESTO][(BUFF, 7777)].applications, 1)

    def test_dates_come_from_the_file_name(self):
        text = combatant_line("23:00:00.0000", A, 264) + aura_line("23:00:01.0000", A, A, 7777)
        agg = sid_scan.scan_file(TempLog(self, text, "WoWCombatLog-010225_101500.txt").path, SPEC_TO_CLASS)
        st = agg.per_spec[RESTO][(BUFF, 7777)]
        self.assertEqual((st.first_seen, st.last_seen), ("2025-01-02", "2025-01-02"))
        self.assertEqual((agg.first_date, agg.last_date), ("2025-01-02", "2025-01-02"))

    def test_dates_fall_back_to_the_lines(self):
        text = (combatant_line("23:00:00.0000", A, 264) + aura_line("23:59:30.0000", A, A, 7777)
                + aura_line("00:00:30.0000", A, A, 7777).replace("9/23/2026", "9/24/2026"))
        agg = sid_scan.scan_file(TempLog(self, text, "renamed.txt").path, SPEC_TO_CLASS)
        st = agg.per_spec[RESTO][(BUFF, 7777)]
        self.assertEqual((st.first_seen, st.last_seen), ("2026-09-23", "2026-09-24"))
        self.assertEqual((agg.first_date, agg.last_date), ("2026-09-23", "2026-09-24"))

    def test_file_date(self):
        self.assertEqual(sid_scan.file_date(Path("WoWCombatLog-092326_230936.txt")), "2026-09-23")
        self.assertEqual(sid_scan.file_date(Path("/x/WoWCombatLog-123199_000000.txt")), "2099-12-31")
        self.assertIsNone(sid_scan.file_date(Path("WoWCombatLog.txt")))
        self.assertIsNone(sid_scan.file_date(Path("WoWCombatLog-133126_000000.txt")))


class AggregateJson(unittest.TestCase):
    def test_round_trip_keeps_counts(self):
        agg = scan_fixture()
        back = sid_scan.aggregate_from_json(json.loads(json.dumps(sid_scan.aggregate_to_json(agg))))
        self.assertEqual((back.lines, back.skipped, back.unattributed), (agg.lines, agg.skipped, agg.unattributed))
        self.assertEqual((back.first_date, back.last_date), (agg.first_date, agg.last_date))
        self.assertEqual(set(back.per_spec), set(agg.per_spec))
        for spec, auras in agg.per_spec.items():
            self.assertEqual(set(back.per_spec[spec]), set(auras))
            for key, st in auras.items():
                bt = back.per_spec[spec][key]
                self.assertEqual(bt.names, st.names)
                self.assertEqual(len(bt.players), len(st.players))
                self.assertEqual((bt.applications, bt.self_, bt.single, bt.group),
                                 (st.applications, st.self_, st.single, st.group))
                self.assertEqual(bt.recast_samples, st.recast_samples)
                self.assertEqual((bt.first_seen, bt.last_seen), (st.first_seen, st.last_seen))
        self.assertEqual(back.non_player, agg.non_player)

    def test_json_holds_no_guid_or_unit_name(self):
        text = json.dumps(sid_scan.aggregate_to_json(scan_fixture()))
        self.assertNotIn("Player-", text)
        for name in ("Tester", "Smith", "Latecomer", "Realm", "Wolfie", "Training Dummy", "Target1"):
            self.assertNotIn(name, text)

    def test_players_hash_with_the_salt_and_stay_stable(self):
        agg = scan_fixture()
        one = sid_scan.aggregate_to_json(agg, salt=b"s1")
        again = sid_scan.aggregate_to_json(agg, salt=b"s1")
        other = sid_scan.aggregate_to_json(agg, salt=b"s2")
        self.assertEqual(one, again)
        self.assertNotEqual(one, other)
        # Serialising an already-hashed aggregate keeps the hashes (so merges stay exact).
        self.assertEqual(sid_scan.aggregate_to_json(sid_scan.aggregate_from_json(one), salt=b"s1"), one)

    def test_unknown_spec_round_trips(self):
        agg = sid_scan.FileAggregate()
        st = sid_scan.AuraStats()
        st.applications = 1
        agg.per_spec[("SHAMAN", None)] = {(BUFF, 1): st}
        back = sid_scan.aggregate_from_json(sid_scan.aggregate_to_json(agg))
        self.assertIn(("SHAMAN", None), back.per_spec)


if __name__ == "__main__":
    unittest.main()
