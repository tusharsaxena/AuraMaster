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


if __name__ == "__main__":
    unittest.main()
