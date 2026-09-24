"""Tests for sid_propose (SID-5: corrections, flags, the evidence bar, decisions suppression).

Run: python3 -m unittest discover -s tools/spell-research -p 'test_*.py'

Every test builds its aggregate by hand (no log files): the propose stage only ever sees a merged
FileAggregate, so the scanner's own fixture has nothing to add here.
"""

import sys
import unittest
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import json  # noqa: E402

import sid_cache  # noqa: E402
import sid_propose  # noqa: E402
from sid_scan import AuraStats, FileAggregate  # noqa: E402

ELE, ENH, RESTO = 262, 263, 264
ARMS, PROT = 71, 73
SPEC_MAP = {
    ELE: {"class": "SHAMAN", "name": "Elemental", "role": 2},
    ENH: {"class": "SHAMAN", "name": "Enhancement", "role": 2},
    RESTO: {"class": "SHAMAN", "name": "Restoration", "role": 1},
    # The levelling spec: OrderIndex 4 in ChrSpecialization, never seen at max level. It must not
    # count as a spec "the logs contain no player of", or the candidate exception would never lift.
    1444: {"class": "SHAMAN", "name": "Initial", "role": 2},
    ARMS: {"class": "WARRIOR", "name": "Arms", "role": 2},
    72: {"class": "WARRIOR", "name": "Fury", "role": 2},
    PROT: {"class": "WARRIOR", "name": "Protection", "role": 0},
    1446: {"class": "WARRIOR", "name": "Initial", "role": 2},
}

ASCENDANCE = [114051, 114052, 147059, 1219480, 1252197]
NAMES = {
    114051: "Ascendance", 114052: "Ascendance", 147059: "Ascendance", 1219480: "Ascendance",
    1252197: "Ascendance", 999001: "Lightning Shield",
    871: "Shield Wall", 900001: "Shield Wall", 900002: "Shield Wall", 1719: "Recklessness",
    5246: "Intimidating Shout", 900777: "Storm Bolt", 900778: "Piercing Howl",
}
FAMILY = {aura: set(ASCENDANCE) for aura in ASCENDANCE}

SHIPPED = [
    {"key": "defensives", "label": "Defensive cooldowns", "aura": "BUFF",
     "classes": {"WARRIOR": [871]}},
    {"key": "offensiveCDs", "label": "Offensive cooldowns", "aura": "BUFF",
     "classes": {"WARRIOR": [1719], "SHAMAN": [114051]}},
    {"key": "hardCC", "label": "Hard CC (loss of control)", "aura": "DEBUFF",
     "classes": {"WARRIOR": [5246]}},
    {"key": "softCC", "label": "Soft CC (roots & snares)", "aura": "DEBUFF",
     "classes": {}},
]


def stats(name, apps, players, first="2026-09-01", last="2026-09-20", tag=""):
    """An AuraStats with `players` distinct casters (opaque ids; `tag` keeps sets apart)."""
    return AuraStats(names=Counter({name: apps}), applications=apps,
                     players={"p%s%d" % (tag, i) for i in range(players)},
                     self_=apps, first_seen=first, last_seen=last)


def agg_of(rows, first="2026-06-01", last="2026-09-20"):
    """rows: [(class, spec, aura_type, spell_id, AuraStats)] -> FileAggregate."""
    agg = FileAggregate(first_date=first, last_date=last)
    for cls, spec, aura_type, spell_id, st in rows:
        agg.per_spec.setdefault((cls, spec), {})[(aura_type, spell_id)] = st
    return agg


def via_evidence_json(agg):
    """The production path: the aggregate written to evidence.json and read back."""
    return sid_cache.evidence_from_json(json.loads(json.dumps(sid_cache.evidence_to_json(agg, {}))))


def run(agg, decisions=None, cc_ids=frozenset()):
    props = sid_propose.corrections(agg, SPEC_MAP, NAMES, SHIPPED, FAMILY, decisions or {})
    flags = sid_propose.flags(agg, SPEC_MAP, NAMES, SHIPPED, FAMILY, cc_ids)
    return props, flags


def flag_set(flags):
    return {(f.kind, f.category, f.klass, f.spell_id) for f in flags}


class EvidenceIndexTest(unittest.TestCase):
    def test_groups_by_class_and_lowercased_name_per_spec(self):
        agg = agg_of([
            ("SHAMAN", RESTO, "BUFF", 114052, stats("Ascendance", 212, 9)),
            ("SHAMAN", ELE, "BUFF", 1219480, stats("Ascendance", 88, 4, tag="e")),
            ("SHAMAN", ELE, "DEBUFF", 188389, stats("Flame Shock", 50, 3)),
        ])
        idx = sid_propose.evidence_index(agg, SPEC_MAP)
        self.assertEqual(set(idx[("SHAMAN", "ascendance")]), {114052, 1219480})
        resto = idx[("SHAMAN", "ascendance")][114052][RESTO]
        self.assertEqual((resto["apps"], resto["players"], resto["spec"]), (212, 9, "Restoration"))
        self.assertIn(("SHAMAN", "flame shock"), idx)

    def test_aura_type_filter(self):
        agg = agg_of([("SHAMAN", ELE, "DEBUFF", 188389, stats("Flame Shock", 50, 3))])
        self.assertEqual(sid_propose.evidence_index(agg, SPEC_MAP, "BUFF"), {})

    def test_an_id_spelled_differently_per_spec_lands_in_one_group(self):
        # The group name is the id's most common spelling across the class, not per spec.
        agg = agg_of([
            ("WARRIOR", PROT, "BUFF", 871, stats("Shield Wall", 50, 5)),
            ("WARRIOR", ARMS, "BUFF", 871, stats("Shield Wall (old)", 10, 2, tag="a")),
        ])
        idx = sid_propose.evidence_index(agg, SPEC_MAP)
        self.assertEqual(set(idx[("WARRIOR", "shield wall")][871]), {PROT, ARMS})
        self.assertNotIn(("WARRIOR", "shield wall (old)"), idx)

    def test_unknown_spec_is_named_unknown(self):
        agg = agg_of([("SHAMAN", None, "BUFF", 114052, stats("Ascendance", 5, 1))])
        idx = sid_propose.evidence_index(agg, SPEC_MAP)
        self.assertEqual(idx[("SHAMAN", "ascendance")][114052][None]["spec"], "unknown")


class AscendanceTest(unittest.TestCase):
    """The spec's acceptance logic, pinned both ways."""

    RESTO_ROW = ("SHAMAN", RESTO, "BUFF", 114052, stats("Ascendance", 212, 9))

    def test_candidate_exception_flags_unverified_and_adds(self):
        # Only Restoration in the logs: 114051 may be Enhancement's, and no Enhancement player was seen.
        props, flags = run(agg_of([self.RESTO_ROW]))
        self.assertIn(("unverified", "offensiveCDs", "SHAMAN", 114051), flag_set(flags))
        asc = [p for p in props if p.klass == "SHAMAN"]
        self.assertEqual(len(asc), 1)
        p = asc[0]
        self.assertEqual((p.type, p.category, p.name, p.listed, p.proposed),
                         ("add", "offensiveCDs", "Ascendance", [114051], [114052]))
        self.assertEqual(p.evidence[114052], {"Restoration": (212, 9)})
        self.assertEqual(p.rule, "evidence")
        self.assertEqual(p.applications, 212)
        # Kept alive by the exception only: the listed id is unproven, so the add is medium.
        self.assertEqual(p.confidence, "medium")

    def test_too_few_players_of_a_spec_keeps_the_exception(self):
        # Two Enhancement players are below the 3-player bar: not enough to say the spec never applies it.
        rows = [self.RESTO_ROW,
                ("SHAMAN", ENH, "BUFF", 999001, stats("Lightning Shield", 40, 2, tag="n")),
                ("SHAMAN", ELE, "BUFF", 1219480, stats("Ascendance", 88, 4, tag="e"))]
        props, flags = run(agg_of(rows))
        self.assertIn(("unverified", "offensiveCDs", "SHAMAN", 114051), flag_set(flags))
        self.assertEqual([p.type for p in props if p.klass == "SHAMAN"], ["add"])

    def test_every_spec_seen_and_none_applies_it_replaces(self):
        rows = [self.RESTO_ROW,
                ("SHAMAN", ENH, "BUFF", 999001, stats("Lightning Shield", 40, 5, tag="n")),
                ("SHAMAN", ELE, "BUFF", 1219480, stats("Ascendance", 88, 4, tag="e"))]
        props, flags = run(agg_of(rows))
        self.assertNotIn(("unverified", "offensiveCDs", "SHAMAN", 114051), flag_set(flags))
        asc = [p for p in props if p.klass == "SHAMAN"]
        self.assertEqual(len(asc), 1)
        p = asc[0]
        self.assertEqual((p.type, p.listed, p.proposed), ("replace", [114051], [114052, 1219480]))
        self.assertEqual(p.confidence, "high")
        self.assertEqual(p.evidence[114051], {})
        self.assertEqual(p.evidence[1219480], {"Elemental": (88, 4)})
        self.assertEqual(p.applications, 300)
        self.assertIn("never applied", p.reason)

    def test_not_a_db2_candidate_replaces_without_the_exception(self):
        props = sid_propose.corrections(agg_of([self.RESTO_ROW]), SPEC_MAP, NAMES, SHIPPED, {}, {})
        self.assertEqual([(p.type, p.listed, p.proposed) for p in props],
                         [("replace", [114051], [114052])])


class AddTest(unittest.TestCase):
    def test_listed_id_applied_and_a_sibling_applied_by_another_spec(self):
        rows = [("WARRIOR", PROT, "BUFF", 871, stats("Shield Wall", 50, 5)),
                ("WARRIOR", ARMS, "BUFF", 900001, stats("Shield Wall", 25, 3, tag="a"))]
        props, flags = run(agg_of(rows))
        self.assertEqual([(p.type, p.category, p.klass, p.listed, p.proposed) for p in props],
                         [("add", "defensives", "WARRIOR", [871], [900001])])
        self.assertEqual(props[0].evidence[871], {"Protection": (50, 5)})
        self.assertEqual(props[0].confidence, "high")
        self.assertNotIn(("unverified", "defensives", "WARRIOR", 871), flag_set(flags))

    def test_listed_id_applied_under_another_spelling_is_not_never_applied(self):
        # 871 is applied 500 times, but the logs spell it differently from DB2 (a rename between the
        # old logs and the current build). It is applied, so it is kept: an add, never a replace.
        rows = [("WARRIOR", PROT, "BUFF", 871, stats("Shield Wall (old)", 500, 9)),
                ("WARRIOR", ARMS, "BUFF", 900001, stats("Shield Wall", 30, 4, tag="a"))]
        props, flags = run(agg_of(rows))
        self.assertEqual([(p.type, p.listed, p.proposed, p.confidence) for p in props],
                         [("add", [871], [900001], "high")])
        self.assertEqual(props[0].evidence[871], {"Protection": (500, 9)})
        self.assertNotIn("never", props[0].reason)
        self.assertNotIn(("unverified", "defensives", "WARRIOR", 871), flag_set(flags))

    def test_listed_id_applied_under_another_spelling_alone_is_not_unverified(self):
        rows = [("WARRIOR", PROT, "BUFF", 871, stats("Shield Wall (old)", 500, 9))]
        props, flags = run(agg_of(rows))
        self.assertEqual(props, [])
        self.assertNotIn(("unverified", "defensives", "WARRIOR", 871), flag_set(flags))

    def test_listed_id_applied_only_as_the_other_aura_type_is_still_never_applied(self):
        # A DEBUFF sighting of 871 says nothing about the BUFF the category lists.
        rows = [("WARRIOR", PROT, "DEBUFF", 871, stats("Shield Wall", 500, 9)),
                ("WARRIOR", ARMS, "BUFF", 900001, stats("Shield Wall", 30, 4, tag="a"))]
        props, _flags = run(agg_of(rows))
        self.assertEqual([(p.type, p.listed, p.proposed) for p in props],
                         [("replace", [871], [900001])])


class EvidenceBarTest(unittest.TestCase):
    def _check(self, apps, players):
        rows = [("WARRIOR", PROT, "BUFF", 871, stats("Shield Wall", 50, 5)),
                ("WARRIOR", ARMS, "BUFF", 900001, stats("Shield Wall", apps, players, tag="a"))]
        props, flags = run(agg_of(rows))
        self.assertEqual(props, [])
        self.assertIn(("below_bar", "defensives", "WARRIOR", 900001), flag_set(flags))

    def test_nineteen_applications_is_below_the_bar(self):
        self._check(19, 5)

    def test_two_players_is_below_the_bar(self):
        self._check(200, 2)

    def test_players_are_distinct_across_specs(self):
        # 20 applications split over two specs by the SAME two players: still 2 players.
        rows = [("WARRIOR", PROT, "BUFF", 871, stats("Shield Wall", 50, 5)),
                ("WARRIOR", ARMS, "BUFF", 900001, stats("Shield Wall", 10, 2, tag="x")),
                ("WARRIOR", 72, "BUFF", 900001, stats("Shield Wall", 10, 2, tag="x"))]
        props, flags = run(agg_of(rows))
        self.assertEqual(props, [])
        self.assertIn(("below_bar", "defensives", "WARRIOR", 900001), flag_set(flags))

    def test_players_are_distinct_across_specs_from_evidence_json(self):
        # Two Arms and two OTHER Fury players: 4 distinct, above the bar, on the evidence.json path too.
        rows = [("WARRIOR", PROT, "BUFF", 871, stats("Shield Wall", 50, 5)),
                ("WARRIOR", ARMS, "BUFF", 900001, stats("Shield Wall", 15, 2, tag="a")),
                ("WARRIOR", 72, "BUFF", 900001, stats("Shield Wall", 15, 2, tag="f"))]
        props, flags = run(via_evidence_json(agg_of(rows)))
        self.assertEqual([(p.type, p.proposed) for p in props], [("add", [900001])])
        self.assertNotIn(("below_bar", "defensives", "WARRIOR", 900001), flag_set(flags))

    def test_the_same_players_in_two_specs_from_evidence_json_count_once(self):
        rows = [("WARRIOR", PROT, "BUFF", 871, stats("Shield Wall", 50, 5)),
                ("WARRIOR", ARMS, "BUFF", 900001, stats("Shield Wall", 15, 2, tag="x")),
                ("WARRIOR", 72, "BUFF", 900001, stats("Shield Wall", 15, 2, tag="x"))]
        props, flags = run(via_evidence_json(agg_of(rows)))
        self.assertEqual(props, [])
        below = [f for f in flags if f.kind == "below_bar" and f.spell_id == 900001]
        self.assertIn("30 applications / 2 players", below[0].detail)

    def test_thresholds_are_parameters(self):
        rows = [("WARRIOR", PROT, "BUFF", 871, stats("Shield Wall", 50, 5)),
                ("WARRIOR", ARMS, "BUFF", 900001, stats("Shield Wall", 19, 2, tag="a"))]
        th = sid_propose.Thresholds(min_applications=10, min_players=2)
        props = sid_propose.corrections(agg_of(rows), SPEC_MAP, NAMES, SHIPPED, FAMILY, {}, th)
        self.assertEqual([p.proposed for p in props], [[900001]])


class EvidenceJsonCoverageTest(unittest.TestCase):
    def test_spec_coverage_is_exact_from_evidence_json(self):
        # Four Enhancement players, two per aura, none shared: the spec is covered (>= 3 players), so
        # the candidate exception lifts and 114051 is replaced, on the evidence.json path as in memory.
        rows = [AscendanceTest.RESTO_ROW,
                ("SHAMAN", ENH, "BUFF", 999001, stats("Lightning Shield", 40, 2, tag="n")),
                ("SHAMAN", ENH, "BUFF", 999002, stats("Maelstrom", 40, 2, tag="m")),
                ("SHAMAN", ELE, "BUFF", 1219480, stats("Ascendance", 88, 4, tag="e"))]
        for agg in (agg_of(rows), via_evidence_json(agg_of(rows))):
            self.assertEqual(sid_propose.spec_player_counts(agg)[("SHAMAN", ENH)], 4)
            props, _flags = run(agg)
            self.assertEqual([p.type for p in props if p.klass == "SHAMAN"], ["replace"])

    def test_cc_unlisted_counts_players_across_specs_from_evidence_json(self):
        rows = [("WARRIOR", ARMS, "DEBUFF", 900777, stats("Storm Bolt", 20, 2, tag="a")),
                ("WARRIOR", 72, "DEBUFF", 900777, stats("Storm Bolt", 20, 2, tag="f"))]
        _props, flags = run(via_evidence_json(agg_of(rows)), cc_ids={900777})
        cc = [f for f in flags if f.kind == "cc_unlisted"]
        self.assertEqual([f.spell_id for f in cc], [900777])
        self.assertIn("40 applications / 4 players", cc[0].detail)


class UnverifiedTest(unittest.TestCase):
    def test_listed_id_with_no_evidence_either_way(self):
        props, flags = run(agg_of([]))
        self.assertEqual(props, [])
        fs = flag_set(flags)
        self.assertIn(("unverified", "defensives", "WARRIOR", 871), fs)
        self.assertIn(("unverified", "offensiveCDs", "SHAMAN", 114051), fs)

    def test_an_id_with_no_db2_name_is_not_flagged(self):
        shipped = [{"key": "defensives", "label": "D", "aura": "BUFF", "classes": {"WARRIOR": [123]}}]
        self.assertEqual(sid_propose.flags(agg_of([]), SPEC_MAP, NAMES, shipped, FAMILY), [])


class StaleTest(unittest.TestCase):
    def test_listed_id_not_seen_in_the_last_two_months_while_a_sibling_is(self):
        rows = [("WARRIOR", PROT, "BUFF", 871, stats("Shield Wall", 50, 5, last="2026-06-01")),
                ("WARRIOR", PROT, "BUFF", 900001, stats("Shield Wall", 50, 5, tag="a", last="2026-09-20"))]
        _props, flags = run(agg_of(rows, last="2026-09-20"))
        self.assertIn(("stale", "defensives", "WARRIOR", 871), flag_set(flags))

    def test_no_stale_when_the_sibling_is_old_too(self):
        rows = [("WARRIOR", PROT, "BUFF", 871, stats("Shield Wall", 50, 5, last="2026-06-01")),
                ("WARRIOR", PROT, "BUFF", 900001, stats("Shield Wall", 50, 5, tag="a", last="2026-07-01"))]
        _props, flags = run(agg_of(rows, last="2026-09-20"))
        self.assertNotIn("stale", {f.kind for f in flags})

    def test_no_stale_when_the_listed_id_is_recent(self):
        rows = [("WARRIOR", PROT, "BUFF", 871, stats("Shield Wall", 50, 5, last="2026-07-22")),
                ("WARRIOR", PROT, "BUFF", 900001, stats("Shield Wall", 50, 5, tag="a", last="2026-09-20"))]
        _props, flags = run(agg_of(rows, last="2026-09-20"))
        self.assertNotIn("stale", {f.kind for f in flags})


class DecisionsTest(unittest.TestCase):
    ROWS = [("WARRIOR", PROT, "BUFF", 871, stats("Shield Wall", 50, 5)),
            ("WARRIOR", ARMS, "BUFF", 900001, stats("Shield Wall", 25, 3, tag="a"))]

    def test_proposal_key_shape(self):
        props, _flags = run(agg_of(self.ROWS))
        self.assertEqual(sid_propose.proposal_key(props[0]), "add|defensives|WARRIOR|shield wall|900001")

    def test_proposal_key_sorts_the_proposed_ids(self):
        p = sid_propose.Proposal(type="replace", category="offensiveCDs", from_category="",
                                 klass="SHAMAN", name="Ascendance", listed=[114051],
                                 proposed=[1219480, 114052], evidence={}, rule="evidence",
                                 reason="", confidence="high", applications=0)
        self.assertEqual(sid_propose.proposal_key(p),
                         "replace|offensiveCDs|SHAMAN|ascendance|114052,1219480")

    def test_a_ruled_proposal_is_not_returned(self):
        decisions = {"add|defensives|WARRIOR|shield wall|900001":
                     {"ruling": "reject", "category": None, "date": "2026-09-24", "reason": ""}}
        props, _flags = run(agg_of(self.ROWS), decisions=decisions)
        self.assertEqual(props, [])

    def test_a_ruling_on_another_key_does_not_suppress(self):
        decisions = {"add|defensives|WARRIOR|shield wall|900002": {"ruling": "reject"}}
        props, _flags = run(agg_of(self.ROWS), decisions=decisions)
        self.assertEqual(len(props), 1)


class OrderTest(unittest.TestCase):
    def test_most_applied_first(self):
        rows = [("WARRIOR", PROT, "BUFF", 871, stats("Shield Wall", 50, 5)),
                ("WARRIOR", ARMS, "BUFF", 900001, stats("Shield Wall", 25, 3, tag="a")),
                ("SHAMAN", RESTO, "BUFF", 114052, stats("Ascendance", 212, 9, tag="r"))]
        props, _flags = run(agg_of(rows))
        self.assertEqual([p.klass for p in props], ["SHAMAN", "WARRIOR"])


class CrowdControlCrossCheckTest(unittest.TestCase):
    CC = frozenset({5246, 900777, 900778})

    def test_player_cc_debuff_in_no_cc_category_is_flagged_never_proposed(self):
        rows = [("WARRIOR", ARMS, "DEBUFF", 900777, stats("Storm Bolt", 40, 4)),
                ("WARRIOR", ARMS, "DEBUFF", 5246, stats("Intimidating Shout", 40, 4, tag="i"))]
        props, flags = run(agg_of(rows), cc_ids=self.CC)
        self.assertEqual(props, [])
        cc = [f for f in flags if f.kind == "cc_unlisted"]
        self.assertEqual([(f.klass, f.spell_id, f.name) for f in cc], [("WARRIOR", 900777, "Storm Bolt")])
        self.assertIn("40", cc[0].detail)

    def test_below_the_bar_or_not_cc_or_a_buff_is_not_flagged(self):
        rows = [("WARRIOR", ARMS, "DEBUFF", 900777, stats("Storm Bolt", 19, 4)),
                ("WARRIOR", ARMS, "DEBUFF", 900900, stats("Rend", 400, 4, tag="r")),
                ("WARRIOR", ARMS, "BUFF", 900778, stats("Piercing Howl", 400, 4, tag="h"))]
        _props, flags = run(agg_of(rows), cc_ids=self.CC)
        self.assertNotIn("cc_unlisted", {f.kind for f in flags})

    def test_a_cc_listed_under_another_class_is_listed(self):
        # The addon's filter ignores the class key: an id listed under any class is in the category.
        shipped = SHIPPED[:3] + [{"key": "softCC", "label": "S", "aura": "DEBUFF",
                                  "classes": {"SHAMAN": [900777]}}]
        rows = [("WARRIOR", ARMS, "DEBUFF", 900777, stats("Storm Bolt", 40, 4))]
        flags = sid_propose.flags(agg_of(rows), SPEC_MAP, NAMES, shipped, FAMILY, self.CC)
        self.assertNotIn("cc_unlisted", {f.kind for f in flags})


if __name__ == "__main__":
    unittest.main()
