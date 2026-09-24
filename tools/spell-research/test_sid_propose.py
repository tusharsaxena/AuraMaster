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


class AllClassesTest(unittest.TestCase):
    """A class key of ALL (racials, flasks) lists the id for every class: its evidence is the union
    of every class's (SID-10: War Stomp, applied 336 times by seven classes, read "no ALL player
    applied it", because no log player is of a class called ALL)."""

    NAMES = {**NAMES, 20549: "War Stomp", 900881: "War Stomp"}
    SHIPPED = [{"key": "hardCC", "label": "Hard CC", "aura": "DEBUFF", "classes": {"ALL": [20549]}}]
    ROWS = [("WARRIOR", ARMS, "DEBUFF", 20549, stats("War Stomp", 30, 3)),
            ("SHAMAN", RESTO, "DEBUFF", 20549, stats("War Stomp", 30, 3, tag="s"))]

    def review(self, agg, th=None):
        th = th or sid_propose.Thresholds(min_applications=50, min_players=5)
        props = sid_propose.corrections(agg, SPEC_MAP, self.NAMES, self.SHIPPED, {}, {}, th)
        flags = sid_propose.flags(agg, SPEC_MAP, self.NAMES, self.SHIPPED, {}, frozenset(), th)
        return props, flags

    def test_an_all_entry_applied_by_several_classes_is_confirmed_above_the_bar(self):
        # 60 applications from 3 + 3 players: over a bar of 50 / 5 only as the union.
        for agg in (agg_of(self.ROWS), via_evidence_json(agg_of(self.ROWS))):
            props, flags = self.review(agg)
            self.assertEqual(props, [])
            self.assertEqual({(f.kind, f.klass, f.spell_id) for f in flags}, set())

    def test_an_all_entry_never_applied_is_replaced_by_the_sibling_any_class_applies(self):
        rows = [("WARRIOR", ARMS, "DEBUFF", 900881, stats("War Stomp", 40, 4)),
                ("SHAMAN", RESTO, "DEBUFF", 900881, stats("War Stomp", 40, 4, tag="s"))]
        props, _flags = self.review(via_evidence_json(agg_of(rows)))
        self.assertEqual([(p.type, p.klass, p.listed, p.proposed, p.applications) for p in props],
                         [("replace", "ALL", [20549], [900881], 80)])
        self.assertEqual(props[0].evidence[900881],
                         {"SHAMAN Restoration": (40, 4), "WARRIOR Arms": (40, 4)})


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

    def test_a_same_name_debuff_without_a_cc_mechanic_is_never_proposed_into_a_cc_list(self):
        # SID-10, the real run: Rake's bleed 155722 was proposed into hardCC beside the stun
        # 163505, the Binding Shot tether 117405 beside the stun, Moonfire's DoT into softCC. The
        # CC lists are research.py's DB2-mechanic method; logs may only add an id DB2 calls CC.
        rows = [("WARRIOR", ARMS, "DEBUFF", 5246, stats("Intimidating Shout", 40, 4)),
                ("WARRIOR", ARMS, "DEBUFF", 900779, stats("Intimidating Shout", 400, 9, tag="d"))]
        agg = agg_of(rows)
        props = sid_propose.corrections(agg, SPEC_MAP, NAMES, SHIPPED, FAMILY, {}, cc_ids=self.CC)
        self.assertEqual(props, [])
        props = sid_propose.corrections(agg, SPEC_MAP, NAMES, SHIPPED, FAMILY, {},
                                        cc_ids=self.CC | {900779})
        self.assertEqual([(p.type, p.category, p.proposed) for p in props],
                         [("add", "hardCC", [900779])])

    def test_a_never_applied_cc_id_with_only_a_non_cc_sibling_is_unverified_not_replaced(self):
        rows = [("WARRIOR", ARMS, "DEBUFF", 900779, stats("Intimidating Shout", 400, 9))]
        agg = agg_of(rows)
        props = sid_propose.corrections(agg, SPEC_MAP, NAMES, SHIPPED, FAMILY, {}, cc_ids=self.CC)
        self.assertEqual(props, [])
        flags = sid_propose.flags(agg, SPEC_MAP, NAMES, SHIPPED, FAMILY, self.CC)
        self.assertIn(("unverified", "hardCC", "WARRIOR", 5246), flag_set(flags))

    def test_a_cc_listed_under_another_class_is_listed(self):
        # The addon's filter ignores the class key: an id listed under any class is in the category.
        shipped = SHIPPED[:3] + [{"key": "softCC", "label": "S", "aura": "DEBUFF",
                                  "classes": {"SHAMAN": [900777]}}]
        rows = [("WARRIOR", ARMS, "DEBUFF", 900777, stats("Storm Bolt", 40, 4))]
        flags = sid_propose.flags(agg_of(rows), SPEC_MAP, NAMES, shipped, FAMILY, self.CC)
        self.assertNotIn("cc_unlisted", {f.kind for f in flags})



# --- SID-6: category rules, moves and additions ------------------------------------------------------

def shape(apps=100, self_=0, single=0, group=0, recast=None):
    """A suggest() stats dict. Applications neither self nor single landed inside a burst."""
    return {"applications": apps, "self": self_, "single": single, "group": group, "recast": recast}


class OtherUnitsShareTest(unittest.TestCase):
    """Applications onto units that are not players (pets, guardians) are neither single nor group."""

    def test_a_pet_buff_is_not_support_and_not_group(self):
        got = sid_propose.suggest({"applications": 100, "self": 0, "single": 5, "group": 0,
                                   "other": 95, "recast": 30.0}, set(), True, False)
        self.assertEqual(got[:2], ("utility", "R9"))
        self.assertIn("95% other units", got[3])
        self.assertIn("0% group", got[3])


class SuggestRuleTest(unittest.TestCase):
    """One test per rule; each checks category, rule id, confidence and the evidence in the reason."""

    def check(self, got, category, rule, confidence, *words):
        self.assertEqual(got[:3], (category, rule, confidence))
        for w in words:
            self.assertIn(w, got[3])

    def test_r1_self_damage_reduction_is_defensive(self):
        got = sid_propose.suggest(shape(self_=95, single=5), {"damage_taken_down"}, True, False)
        self.check(got, "defensives", "R1", "high", "95%", "reduces damage taken", "Defensive cooldowns")

    def test_r1_absorb_counts_too(self):
        got = sid_propose.suggest(shape(self_=100), {"absorb"}, True, False)
        self.check(got, "defensives", "R1", "high", "absorbs")

    def test_r2_group_damage_reduction_is_a_raid_cooldown(self):
        # 40 applications in 4 bursts of ten: 40 % of applications are group.
        got = sid_propose.suggest(shape(self_=60, group=4), {"damage_taken_down"}, True, False)
        self.check(got, "raidCDs", "R2", "high", "40%", "5+ players", "reduces damage taken",
                   "Raid cooldowns")

    def test_r2_takes_a_group_heal_before_r6(self):
        got = sid_propose.suggest(shape(self_=10, single=50, group=4, recast=10.0),
                                  {"periodic_heal"}, True, False)
        self.check(got, "raidCDs", "R2", "high", "heals")

    def test_r1_self_immunity_is_defensive(self):
        # SID-11: Divine Shield 642 (SCHOOL_IMMUNITY) carries no damage-taken or absorb row.
        got = sid_propose.suggest(shape(self_=100, recast=300.0), {"immunity"}, True, False)
        self.check(got, "defensives", "R1", "high", "100%", "immunity", "Defensive cooldowns")

    def test_an_immunity_onto_others_is_not_r1(self):
        # Blessing of Protection 1022 (SCHOOL_IMMUNITY, physical) goes onto another player.
        got = sid_propose.suggest(shape(self_=10, single=90, recast=300.0), {"immunity"}, True, False)
        self.assertEqual(got[:2], ("support", "R5"))

    def test_r2_haste_in_group_bursts_is_a_raid_cooldown(self):
        # SID-11: Bloodlust 2825 (MELEE_SLOW +30) lands on the whole group at once.
        got = sid_propose.suggest(shape(apps=100, group=5, recast=600.0), {"haste_up"}, True, False)
        self.check(got, "raidCDs", "R2", "high", "100%", "5+ players", "haste", "Raid cooldowns")

    def test_haste_mostly_single_is_not_group_haste(self):
        # Power Infusion: haste onto one other player stays Support.
        got = sid_propose.suggest(shape(single=100, recast=120.0), {"haste_up"}, True, False)
        self.assertEqual(got[:2], ("support", "R5"))

    def test_r3_self_haste_with_a_long_recast_is_offensive(self):
        got = sid_propose.suggest(shape(self_=95, single=5, recast=120.0), {"haste_up"}, True, False)
        self.check(got, "offensiveCDs", "R3", "high", "95%", "haste", "120", "Offensive cooldowns")

    def test_r3_needs_a_recast_of_a_minute(self):
        got = sid_propose.suggest(shape(self_=95, single=5, recast=20.0), {"haste_up"}, True, False)
        self.assertNotEqual(got[1], "R3")
        got = sid_propose.suggest(shape(self_=95, single=5, recast=None), {"haste_up"}, True, False)
        self.assertNotEqual(got[1], "R3")

    def test_r4_speed_is_movement(self):
        got = sid_propose.suggest(shape(self_=100, recast=30.0), {"speed_up"}, True, False)
        self.check(got, "movement", "R4", "high", "movement speed", "Movement")

    def test_r5_single_other_player_is_support(self):
        got = sid_propose.suggest(shape(self_=20, single=80, recast=120.0), set(), True, False)
        self.check(got, "support", "R5", "medium", "80%", "one other player", "EXTERNAL_DEFENSIVE",
                   "Support")

    def test_r6_periodic_heal_mostly_on_others_with_a_short_recast_is_healing(self):
        got = sid_propose.suggest(shape(self_=40, single=60, recast=10.0), {"periodic_heal"}, True, False)
        self.check(got, "healing", "R6", "medium", "heals over time", "60%", "10", "Healing")

    def test_r6_needs_a_short_recast(self):
        got = sid_propose.suggest(shape(self_=40, single=60, recast=45.0), {"periodic_heal"}, True, False)
        self.assertNotEqual(got[1], "R6")

    def test_r7_tank_only_self_short_recast_is_active_mitigation(self):
        got = sid_propose.suggest(shape(self_=95, single=5, recast=15.0), set(), True, True)
        self.check(got, "activeMitigation", "R7", "medium", "tank", "95%", "15", "Active mitigation")

    def test_r7_needs_tank_only(self):
        got = sid_propose.suggest(shape(self_=95, single=5, recast=15.0), set(), True, False)
        self.assertNotEqual(got[1], "R7")

    def test_r8_outside_the_player_pool_is_a_consumable(self):
        got = sid_propose.suggest(shape(self_=100, recast=300.0), set(), False, False)
        self.check(got, "consumables", "R8", "high", "player-castable", "Consumables")

    def test_r9_nothing_else_is_utility(self):
        got = sid_propose.suggest(shape(self_=50, single=50), set(), True, False)
        self.check(got, "utility", "R9", "low", "Utility")

    def test_r9_no_suggestion_without_self_or_single_evidence(self):
        got = sid_propose.suggest(shape(self_=0, single=0, group=10), set(), True, False)
        self.assertEqual(got[:3], (None, "R9", "low"))

    def test_first_match_wins_r1_before_r3(self):
        got = sid_propose.suggest(shape(self_=100, recast=180.0), {"damage_taken_down", "haste_up"},
                                  True, False)
        self.assertEqual(got[1], "R1")

    def test_no_applications_is_no_suggestion(self):
        self.assertIsNone(sid_propose.suggest(shape(apps=0), {"speed_up"}, True, False)[0])


def rows_st(apps, players, self_=0, single=0, group=0, recast=None, tag="", name="X"):
    st = stats(name, apps, players, tag=tag)
    st.self_, st.single, st.group = self_, single, group
    st.recast_samples = [] if recast is None else [recast]
    return st


RULE_SHIPPED = SHIPPED + [
    {"key": k, "label": k, "aura": "BUFF", "classes": {}}
    for k in ("activeMitigation", "raidCDs", "healing", "support", "movement", "utility", "consumables")
]
POOL = {871, 1719, 900001, 900100, 900101, 900200, 900300, 900400}


class MovesTest(unittest.TestCase):
    NAMES = {**NAMES, **{900100: "Rallying Cry"}}
    SHIPPED = [{"key": "defensives", "label": "D", "aura": "BUFF", "classes": {"WARRIOR": [871, 900100]}},
               {"key": "raidCDs", "label": "R", "aura": "BUFF", "classes": {}},
               {"key": "hardCC", "label": "H", "aura": "DEBUFF", "classes": {"WARRIOR": [5246]}}]
    SIGNALS = {871: {"damage_taken_down"}, 900100: {"damage_taken_down"}, 5246: set()}

    def moves(self, rows, decisions=None):
        return sid_propose.moves(agg_of(rows), SPEC_MAP, self.NAMES, self.SHIPPED, self.SIGNALS, POOL,
                                 decisions=decisions or {})

    GROUP_ROWS = [("WARRIOR", ARMS, "BUFF", 900100,
                   rows_st(100, 5, self_=60, group=4, recast=180.0, name="Rallying Cry")),
                  ("WARRIOR", PROT, "BUFF", 871, rows_st(50, 5, self_=50, recast=180.0, tag="p"))]

    def test_a_group_defensive_moves_to_raid_cooldowns_at_medium(self):
        props = self.moves(self.GROUP_ROWS)
        self.assertEqual([(p.type, p.from_category, p.category, p.klass, p.listed, p.proposed, p.rule)
                          for p in props],
                         [("move", "defensives", "raidCDs", "WARRIOR", [900100], [900100], "R2")])
        p = props[0]
        self.assertEqual(p.confidence, "medium")  # R2 is high; a move is medium at most
        self.assertEqual(p.name, "Rallying Cry")
        self.assertEqual(p.evidence[900100], {"Arms": (100, 5)})
        self.assertEqual(p.applications, 100)
        self.assertIn("40%", p.reason)
        self.assertEqual(sid_propose.proposal_key(p), "move|raidCDs|WARRIOR|rallying cry|900100")

    def test_a_ruled_move_is_not_returned(self):
        decisions = {"move|raidCDs|WARRIOR|rallying cry|900100": {"ruling": "reject"}}
        self.assertEqual(self.moves(self.GROUP_ROWS, decisions), [])

    def test_below_the_bar_never_moves(self):
        rows = [("WARRIOR", ARMS, "BUFF", 900100,
                 rows_st(19, 5, self_=11, group=1, recast=180.0, name="Rallying Cry"))]
        self.assertEqual(self.moves(rows), [])

    def test_a_low_confidence_suggestion_never_moves(self):
        # 50% self, 50% single, no signal: R9 'utility' at low confidence. 'utility' is in the
        # file and does not list 871, so only the medium-confidence gate can stop the move.
        rows = [("WARRIOR", PROT, "BUFF", 871, rows_st(50, 5, self_=25, single=25))]
        self.SIGNALS = {**self.SIGNALS, **{871: set()}}
        self.SHIPPED = self.SHIPPED + [{"key": "utility", "label": "U", "aura": "BUFF", "classes": {}}]
        ruled = sid_propose._Ruled(agg_of(rows), SPEC_MAP, self.NAMES, self.SIGNALS, POOL, None,
                                   sid_propose.Thresholds())
        self.assertEqual(ruled.suggest("WARRIOR", 871)[::2], ("utility", "low"))
        self.assertEqual(self.moves(rows), [])

    def test_debuff_categories_never_move(self):
        # A BUFF observation of an id listed only in hardCC, shaped like a raid cooldown: were
        # the debuff category not skipped, it would move hardCC -> raidCDs.
        rows = [("WARRIOR", ARMS, "BUFF", 5246,
                 rows_st(100, 5, self_=60, group=4, recast=180.0, name="Intimidating Shout"))]
        self.SIGNALS = {**self.SIGNALS, **{5246: {"damage_taken_down"}}}
        ruled = sid_propose._Ruled(agg_of(rows), SPEC_MAP, self.NAMES, self.SIGNALS, POOL, None,
                                   sid_propose.Thresholds())
        self.assertEqual(ruled.suggest("WARRIOR", 5246)[0], "raidCDs")
        self.assertEqual(self.moves(rows), [])

    def moves_in(self, shipped, rows, signals):
        return sid_propose.moves(agg_of(rows), SPEC_MAP, self.NAMES, shipped, signals, POOL)

    def test_an_entry_that_meets_its_own_category_rule_never_moves(self):
        # SID-10, the real run: every listed HoT (Rejuvenation, Riptide, Renewing Mist, ...) was
        # proposed Healing -> Support, because R5 (70% single) precedes R6 in the table. A move
        # needs the entry to CONTRADICT its category's rule (the spec); this one meets R6.
        shipped = [{"key": "healing", "label": "H", "aura": "BUFF", "classes": {"WARRIOR": [900100]}},
                   {"key": "support", "label": "S", "aura": "BUFF", "classes": {}}]
        rows = [("WARRIOR", ARMS, "BUFF", 900100,
                 rows_st(100, 5, self_=5, single=95, recast=10.0, name="Rallying Cry"))]
        signals = {900100: {"periodic_heal"}}
        ruled = sid_propose._Ruled(agg_of(rows), SPEC_MAP, self.NAMES, signals, POOL, None,
                                   sid_propose.Thresholds())
        self.assertEqual(ruled.suggest("WARRIOR", 900100)[:2], ("support", "R5"))
        self.assertEqual(self.moves_in(shipped, rows, signals), [])

    def test_an_offensive_cooldown_that_also_reduces_damage_taken_stays(self):
        # Avatar 107574 on the real run: self 100%, a damage increase AND a damage-taken
        # reduction, recast ~ 90 s. R1 wins the table, but R3 (its own category) holds.
        shipped = [{"key": "offensiveCDs", "label": "O", "aura": "BUFF",
                    "classes": {"WARRIOR": [900100]}},
                   {"key": "defensives", "label": "D", "aura": "BUFF", "classes": {}}]
        rows = [("WARRIOR", ARMS, "BUFF", 900100,
                 rows_st(100, 5, self_=100, recast=90.0, name="Rallying Cry"))]
        signals = {900100: {"damage_taken_down", "damage_up"}}
        self.assertEqual(self.moves_in(shipped, rows, signals), [])

    def test_a_utility_entry_that_a_rule_claims_moves(self):
        # Utility's rule is R9, "none of the above": an entry R1 claims contradicts it.
        shipped = [{"key": "utility", "label": "U", "aura": "BUFF", "classes": {"WARRIOR": [900100]}},
                   {"key": "defensives", "label": "D", "aura": "BUFF", "classes": {}}]
        rows = [("WARRIOR", ARMS, "BUFF", 900100,
                 rows_st(100, 5, self_=100, recast=90.0, name="Rallying Cry"))]
        signals = {900100: {"damage_taken_down"}}
        props = self.moves_in(shipped, rows, signals)
        self.assertEqual([(p.from_category, p.category, p.rule) for p in props],
                         [("utility", "defensives", "R1")])

    def test_already_in_the_suggested_category_is_no_move(self):
        shipped = [dict(self.SHIPPED[0]),
                   {"key": "raidCDs", "label": "R", "aura": "BUFF", "classes": {"PRIEST": [900100]}}]
        props = sid_propose.moves(agg_of(self.GROUP_ROWS), SPEC_MAP, self.NAMES, shipped, self.SIGNALS,
                                  POOL)
        self.assertEqual(props, [])


class AdditionsTest(unittest.TestCase):
    NAMES = {**NAMES, **{900200: "Sprint", 900300: "Well Fed", 900400: "Spell Reflection"}}
    SIGNALS = {900200: {"speed_up"}, 900300: set(), 900400: set(), 114052: {"haste_up"}}

    def additions(self, rows, decisions=None, pool=POOL, candidates=None, shipped=None,
                  pool_names=None):
        return sid_propose.additions(agg_of(rows), SPEC_MAP, self.NAMES, shipped or RULE_SHIPPED,
                                     self.SIGNALS, pool, cast_candidates=candidates,
                                     decisions=decisions or {}, pool_names=pool_names)

    SPRINT = ("WARRIOR", ARMS, "BUFF", 900200, rows_st(60, 4, self_=60, recast=60.0, name="Sprint"))

    def test_an_above_bar_buff_in_no_category_is_an_addition(self):
        props = self.additions([self.SPRINT])
        self.assertEqual([(p.type, p.category, p.from_category, p.klass, p.name, p.listed, p.proposed,
                           p.rule, p.confidence) for p in props],
                         [("addition", "movement", "", "WARRIOR", "Sprint", [], [900200], "R4", "high")])
        self.assertEqual(props[0].evidence, {900200: {"Arms": (60, 4)}})
        self.assertIn("movement speed", props[0].reason)
        self.assertEqual(sid_propose.proposal_key(props[0]), "addition|movement|WARRIOR|sprint|900200")

    def test_below_the_bar_is_nothing(self):
        rows = [("WARRIOR", ARMS, "BUFF", 900200, rows_st(19, 4, self_=19, name="Sprint"))]
        self.assertEqual(self.additions(rows), [])

    def test_a_ruled_addition_is_nothing(self):
        decisions = {"addition|movement|WARRIOR|sprint|900200": {"ruling": "reject"}}
        self.assertEqual(self.additions([self.SPRINT], decisions), [])

    def test_a_listed_id_or_a_debuff_is_no_addition(self):
        rows = [("WARRIOR", PROT, "BUFF", 871, rows_st(50, 5, self_=50, recast=180.0)),
                ("WARRIOR", ARMS, "DEBUFF", 900200, rows_st(60, 4, self_=0, single=60, name="Sprint"))]
        self.assertEqual(self.additions(rows), [])

    def test_listed_under_another_class_is_no_addition(self):
        # The addon's filter ignores the class key: an id listed under any class is in the category.
        shipped = RULE_SHIPPED + [{"key": "x", "label": "x", "aura": "BUFF", "classes": {"ROGUE": [900200]}}]
        self.assertEqual(self.additions([self.SPRINT], shipped=shipped), [])

    def test_a_same_name_sibling_of_a_listed_spell_is_left_to_corrections(self):
        # 114052 is Ascendance, and SHAMAN lists 114051: corrections proposes it, not additions.
        rows = [("SHAMAN", RESTO, "BUFF", 114052, rows_st(212, 9, self_=212, recast=180.0,
                                                          name="Ascendance"))]
        self.assertEqual(self.additions(rows), [])

    def test_outside_the_pool_is_a_consumable(self):
        # No DB2 signal: a stat-raising potion would match R3 first (the table order), so R8 is
        # pinned on a buff no earlier rule claims.
        rows = [("WARRIOR", ARMS, "BUFF", 900300,
                 rows_st(40, 4, self_=40, recast=300.0, name="Well Fed"))]
        props = self.additions(rows, pool=set())
        self.assertEqual([(p.category, p.rule) for p in props], [("consumables", "R8")])

    def test_an_aura_whose_cast_is_in_the_pool_is_player_castable(self):
        # Shield Block's aura (132404) is not in the pool; its cast (2565) is. CastToAura links them.
        rows = [("WARRIOR", ARMS, "BUFF", 900300,
                 rows_st(40, 4, self_=40, recast=300.0, name="Well Fed"))]
        props = self.additions(rows, pool={2565}, candidates={2565: [900300]})
        self.assertNotEqual([p.rule for p in props], ["R8"])

    def test_an_aura_named_like_a_pool_spell_of_its_class_is_player_castable(self):
        # SID-10, the real run: Whirling Dragon Punch's aura 196742 has no trigger edge and no
        # family, but MONK's pool holds a Whirling Dragon Punch; it is no consumable.
        rows = [("WARRIOR", ARMS, "BUFF", 900300,
                 rows_st(40, 4, self_=40, recast=300.0, name="Well Fed"))]
        props = self.additions(rows, pool=set(), pool_names={"WARRIOR": {"well fed"}})
        self.assertNotEqual([p.rule for p in props], ["R8"])

    def test_a_pool_name_of_another_class_does_not_make_it_castable(self):
        rows = [("WARRIOR", ARMS, "BUFF", 900300,
                 rows_st(40, 4, self_=40, recast=300.0, name="Well Fed"))]
        props = self.additions(rows, pool=set(), pool_names={"ROGUE": {"well fed"}})
        self.assertEqual([(p.category, p.rule) for p in props], [("consumables", "R8")])

    def test_tank_only_uses_the_spec_roles(self):
        rows = [("WARRIOR", PROT, "BUFF", 900400,
                 rows_st(80, 5, self_=78, single=2, recast=15.0, name="Spell Reflection"))]
        self.assertEqual([(p.category, p.rule) for p in self.additions(rows)],
                         [("activeMitigation", "R7")])
        rows.append(("WARRIOR", ARMS, "BUFF", 900400,
                     rows_st(20, 3, self_=20, recast=15.0, tag="a", name="Spell Reflection")))
        self.assertNotIn("R7", [p.rule for p in self.additions(rows)])

    def test_shapes_sum_across_specs(self):
        # Neither spec alone is 30 % group; together they are 40 %.
        rows = [("WARRIOR", ARMS, "BUFF", 900400,
                 rows_st(50, 3, self_=50, name="Spell Reflection")),
                ("WARRIOR", 72, "BUFF", 900400,
                 rows_st(50, 3, self_=10, group=4, tag="f", name="Spell Reflection"))]
        self.SIGNALS = {**self.SIGNALS, **{900400: {"absorb"}}}
        props = self.additions(rows)
        self.assertEqual([(p.category, p.rule) for p in props], [("raidCDs", "R2")])
        self.assertEqual(props[0].evidence[900400], {"Arms": (50, 3), "Fury": (50, 3)})

    def test_a_suggested_category_the_file_lacks_is_no_addition(self):
        self.assertEqual(self.additions([self.SPRINT], shipped=SHIPPED), [])

    def test_through_evidence_json(self):
        props = sid_propose.additions(via_evidence_json(agg_of([self.SPRINT])), SPEC_MAP, self.NAMES,
                                      RULE_SHIPPED, self.SIGNALS, POOL)
        self.assertEqual([(p.category, p.rule) for p in props], [("movement", "R4")])



class SuggestionsTest(unittest.TestCase):
    """suggestions(): the rule-based category of every player BUFF, for the dictionary's columns."""

    def test_every_buff_gets_its_rule_and_debuffs_none(self):
        agg = agg_of([
            ("WARRIOR", ARMS, "BUFF", 900200, rows_st(60, 4, self_=60, recast=60.0, name="Sprint")),
            ("WARRIOR", ARMS, "BUFF", 871, rows_st(2, 1, self_=2, name="Shield Wall")),
            ("SHAMAN", ELE, "DEBUFF", 188389, stats("Flame Shock", 50, 3)),
        ])
        got = sid_propose.suggestions(agg, SPEC_MAP, {900200: {"speed_up"},
                                                      871: {"damage_taken_down"}}, POOL)
        self.assertEqual(set(got), {("WARRIOR", 900200), ("WARRIOR", 871)})
        self.assertEqual(got[("WARRIOR", 900200)][:3], ("movement", "R4", "high"))
        # Below the evidence bar still gets a suggestion: the dictionary shows every aura.
        self.assertEqual(got[("WARRIOR", 871)][:2], ("defensives", "R1"))
        self.assertIn("reduces damage taken", got[("WARRIOR", 871)][3])

if __name__ == "__main__":
    unittest.main()


# --- SID-11: the rule fixes, from a scanned log to a suggestion ----------------------------------

import shutil  # noqa: E402
import tempfile  # noqa: E402

import sid_scan  # noqa: E402

DRUID_RESTO, PRIEST_DISC, PALADIN_HOLY, PALADIN_PROT = 105, 256, 65, 66
SID11_SPEC_MAP = {
    DRUID_RESTO: {"class": "DRUID", "name": "Restoration", "role": 1},
    PRIEST_DISC: {"class": "PRIEST", "name": "Discipline", "role": 1},
    257: {"class": "PRIEST", "name": "Holy", "role": 1},
    PALADIN_HOLY: {"class": "PALADIN", "name": "Holy", "role": 1},
    PALADIN_PROT: {"class": "PALADIN", "name": "Protection", "role": 0},
    RESTO: {"class": "SHAMAN", "name": "Restoration", "role": 1},
    ELE: {"class": "SHAMAN", "name": "Elemental", "role": 2},
}
SID11_SPEC_TO_CLASS = {spec: info["class"] for spec, info in SID11_SPEC_MAP.items()}


def _clock(seconds):
    h, rest = divmod(seconds, 3600)
    m, s = divmod(rest, 60)
    return "%02d:%02d:%07.4f" % (h, m, s)


def _guid(n):
    return "Player-1-%08X" % n


def _aura(seconds, source, dest, spell_id, name, dest_flags="0x514"):
    return ('9/23/2026 %s  SPELL_AURA_APPLIED,%s,"Src-Realm-US",0x511,0x80000000,%s,"Dst-Realm-US",'
            '%s,0x80000000,%d,"%s",0x8,BUFF\r\n' % (_clock(seconds), source, dest, dest_flags,
                                                     spell_id, name))


def _combatant(guid, spec):
    stats22 = ",".join(str(100 + i) for i in range(22))
    return "9/23/2026 20:00:00.0000  COMBATANT_INFO,%s,0,%s,%d,[],(0,0,0,0),[],[],0\r\n" % (
        guid, stats22, spec)


def scanned(test, casters, body):
    """Scan a synthetic log: casters [(guid, spec)], body lines. Returns the FileAggregate."""
    tmp = tempfile.mkdtemp(prefix="sid-propose-")
    test.addCleanup(shutil.rmtree, tmp, True)
    path = Path(tmp) / "WoWCombatLog-092326_200000.txt"
    text = "".join(_combatant(g, s) for g, s in casters) + "".join(body)
    path.write_bytes(text.encode("utf-8"))
    return sid_scan.scan_file(path, SID11_SPEC_TO_CLASS)


T0 = 20 * 3600 + 60  # 20:01:00


def externals(spell_id, name, spec, casts=8, self_first=True):
    """Three casters, each casting an external `casts` times, 2 min apart, each logged twice:
    once on the target, once on the caster (the copy), 0.05 s apart."""
    casters = [(_guid(0x100 + i), spec) for i in range(3)]
    body = []
    for c, (guid, _spec) in enumerate(casters):
        for k in range(casts):
            t = T0 + c * 3 + k * 120
            target = _guid(0x900 + k % 4)
            pair = [_aura(t, guid, guid, spell_id, name), _aura(t + 0.05, guid, target, spell_id, name)]
            body += pair if self_first else pair[::-1]
    return casters, sorted(body, key=lambda line: line[10:23])


class Sid11ExternalsReachSupportTest(unittest.TestCase):
    """Power Infusion 10060, Blessing of Sacrifice 6940, Guardian Spirit 47788: R5 Support."""

    def suggest(self, klass, spell_id, name, spec, signals, self_first=True):
        casters, body = externals(spell_id, name, spec, self_first=self_first)
        agg = scanned(self, casters, body)
        ruled = sid_propose._Ruled(agg, SID11_SPEC_MAP, {spell_id: name}, {spell_id: signals},
                                   {spell_id}, None, sid_propose.Thresholds())
        stats = sid_propose._stats_of(ruled.rows[(klass, spell_id)])
        self.assertEqual((stats["applications"], stats["self"], stats["single"]), (24, 0, 24))
        return ruled.suggest(klass, spell_id)

    def test_power_infusion(self):
        # DB2: MELEE_SLOW +20 (haste_up). Never self-applied, so not R3.
        got = self.suggest("PRIEST", 10060, "Power Infusion", PRIEST_DISC, {"haste_up"})
        self.assertEqual(got[:3], ("support", "R5", "medium"))
        self.assertIn("100%", got[3])

    def test_blessing_of_sacrifice(self):
        # DB2: SCHOOL_ABSORB (absorb) and a 0-point speed row (no signal since SID-10).
        got = self.suggest("PALADIN", 6940, "Blessing of Sacrifice", PALADIN_HOLY, {"absorb"},
                           self_first=False)
        self.assertEqual(got[:2], ("support", "R5"))

    def test_guardian_spirit(self):
        got = self.suggest("PRIEST", 47788, "Guardian Spirit", 257, set())
        self.assertEqual(got[:2], ("support", "R5"))


def hot_log(spell_id, name, spec, casters=3, casts=10, every=8.0, self_every=0):
    """Each caster applies a HoT every `every` seconds to another player (or itself every
    `self_every`-th cast), the way Rejuvenation, Riptide and Lifebloom show up in the logs."""
    who = [(_guid(0x200 + i), spec) for i in range(casters)]
    body = []
    for c, (guid, _spec) in enumerate(who):
        for k in range(casts):
            t = T0 + c * 600 + k * every
            dest = guid if self_every and k % self_every == 0 else _guid(0xA00 + k % 5)
            body.append(_aura(t, guid, dest, spell_id, name))
    return who, body


class Sid11HotRecastTest(unittest.TestCase):
    """A HoT's recast is per caster onto anyone: it meets R6, so Healing never moves to Support."""

    SHIPPED = [{"key": "healing", "label": "Healing", "aura": "BUFF",
                "classes": {"DRUID": [774, 33763], "SHAMAN": [61295]}},
               {"key": "support", "label": "Support", "aura": "BUFF", "classes": {}}]
    NAMES = {774: "Rejuvenation", 33763: "Lifebloom", 61295: "Riptide"}
    SIGNALS = {774: {"periodic_heal"}, 33763: {"periodic_heal"}, 61295: {"periodic_heal"}}

    def test_a_hot_every_8s_onto_others_has_an_8s_median_and_meets_r6(self):
        who, body = hot_log(774, "Rejuvenation", DRUID_RESTO)
        agg = scanned(self, who, body)
        ruled = sid_propose._Ruled(agg, SID11_SPEC_MAP, self.NAMES, self.SIGNALS, set(self.NAMES),
                                   None, sid_propose.Thresholds())
        stats = sid_propose._stats_of(ruled.rows[("DRUID", 774)])
        self.assertEqual(stats["recast"], 8.0)
        self.assertTrue(ruled.fits("healing", "DRUID", 774))

    def test_rejuvenation_riptide_lifebloom_are_not_moved_to_support(self):
        druids, rejuv = hot_log(774, "Rejuvenation", DRUID_RESTO, every=6.0, self_every=7)
        _d, bloom = hot_log(33763, "Lifebloom", DRUID_RESTO, every=12.0)
        shamans = [(_guid(0x300 + i), RESTO) for i in range(3)]
        riptide = []
        for c, (guid, _spec) in enumerate(shamans):
            for k in range(10):
                riptide.append(_aura(T0 + 5000 + c * 600 + k * 7.0, guid, _guid(0xA00 + k % 5),
                                     61295, "Riptide"))
        agg = scanned(self, druids + shamans, sorted(rejuv + bloom + riptide,
                                                     key=lambda line: line[10:23]))
        ruled = sid_propose._Ruled(agg, SID11_SPEC_MAP, self.NAMES, self.SIGNALS, set(self.NAMES),
                                   None, sid_propose.Thresholds())
        for klass, sid in (("DRUID", 774), ("DRUID", 33763), ("SHAMAN", 61295)):
            self.assertEqual(ruled.suggest(klass, sid)[:2], ("support", "R5"), sid)  # R5 first...
            self.assertTrue(ruled.fits("healing", klass, sid), sid)                  # ...R6 holds
        props = sid_propose.moves(agg, SID11_SPEC_MAP, self.NAMES, self.SHIPPED, self.SIGNALS,
                                  set(self.NAMES))
        self.assertEqual(props, [])


class Sid11SelfProcRefreshTest(unittest.TestCase):
    """SID-11 review: a tank's self-only proc that refreshes itself every few seconds is not
    recast every few seconds, so it stays out of R7 Active mitigation (Coagulopathy 391481)."""

    def test_a_self_proc_refreshing_itself_stays_out_of_r7(self):
        tanks = [(_guid(0x600 + i), PALADIN_PROT) for i in range(3)]
        body = []
        for c, (guid, _spec) in enumerate(tanks):
            for k in range(8):  # applied once a minute, refreshed on the tank every 4 s
                t = T0 + c * 3600 + k * 60
                body.append(_aura(t, guid, guid, 391481, "Coagulopathy"))
                body += [_aura(t + 4 * j, guid, guid, 391481, "Coagulopathy")
                         .replace("SPELL_AURA_APPLIED", "SPELL_AURA_REFRESH") for j in range(1, 12)]
        agg = scanned(self, tanks, body)
        ruled = sid_propose._Ruled(agg, SID11_SPEC_MAP, {391481: "Coagulopathy"}, {391481: set()},
                                   {391481}, None, sid_propose.Thresholds())
        self.assertEqual(sid_propose._stats_of(ruled.rows[("PALADIN", 391481)])["recast"], 60.0)
        self.assertEqual(ruled.suggest("PALADIN", 391481)[:2], ("utility", "R9"))


class Sid11LustAndImmunityTest(unittest.TestCase):
    """Bloodlust-shaped and Divine Shield-shaped logs, scanned, reach R2 and R1."""

    def ruled(self, agg, spell_id, name, signals):
        return sid_propose._Ruled(agg, SID11_SPEC_MAP, {spell_id: name}, {spell_id: signals},
                                  {spell_id}, None, sid_propose.Thresholds())

    def test_bloodlust_group_burst_is_a_raid_cooldown(self):
        shamans = [(_guid(0x400 + i), ELE) for i in range(3)]
        body = []
        for c, (guid, _spec) in enumerate(shamans):
            for k in range(3):  # three pulls, 10 minutes apart, 20 players each (the caster first)
                t = T0 + c * 3600 + k * 600
                body.append(_aura(t, guid, guid, 2825, "Bloodlust"))
                body += [_aura(t + 0.01 * (j + 1), guid, _guid(0xB00 + j), 2825, "Bloodlust")
                         for j in range(19)]
        agg = scanned(self, shamans, body)
        ruled = self.ruled(agg, 2825, "Bloodlust", {"haste_up"})
        got = ruled.suggest("SHAMAN", 2825)
        self.assertEqual(got[:3], ("raidCDs", "R2", "high"))
        self.assertIn("raises haste", got[3])

    def test_divine_shield_is_a_defensive_cooldown(self):
        paladins = [(_guid(0x500 + i), PALADIN_PROT) for i in range(3)]
        body = [_aura(T0 + c * 3600 + k * 300, guid, guid, 642, "Divine Shield")
                for c, (guid, _spec) in enumerate(paladins) for k in range(8)]
        agg = scanned(self, paladins, body)
        got = self.ruled(agg, 642, "Divine Shield", {"immunity"}).suggest("PALADIN", 642)
        self.assertEqual(got[:3], ("defensives", "R1", "high"))
        self.assertIn("immunity", got[3])


class Sid11PluralTest(unittest.TestCase):
    def test_a_below_bar_flag_with_one_application_reads_singular(self):
        agg = agg_of([("WARRIOR", ARMS, "BUFF", 871, stats("Shield Wall", 1, 1))])
        _props, flags = run(agg)
        below = [f for f in flags if f.kind == "below_bar" and f.spell_id == 871]
        self.assertEqual(len(below), 1)
        self.assertIn("1 application / 1 player, under the bar of 20 / 3", below[0].detail)

    def test_one_burst_reads_singular(self):
        got = sid_propose.suggest(shape(apps=10, group=1), {"damage_taken_down"}, True, False)
        self.assertEqual(got[1], "R2")
        self.assertIn("(1 burst)", got[3])

    def test_plural_helper(self):
        self.assertEqual(sid_propose.plural(1, "time"), "1 time")
        self.assertEqual(sid_propose.plural(21, "time"), "21 times")
        self.assertEqual(sid_propose.plural(0, "time"), "0 times")
        self.assertEqual(sid_propose.plural(0, "category"), "0 categories")
        self.assertEqual(sid_propose.plural(9, "category"), "9 categories")


class Sid11WeightedMedianTest(unittest.TestCase):
    def test_equal_weights_are_the_plain_median(self):
        wm = sid_propose._weighted_median
        self.assertEqual(wm([(1.0, 1), (2.0, 1)]), 1.5)
        self.assertEqual(wm([(3.0, 1), (1.0, 1), (2.0, 1)]), 2.0)
        self.assertIsNone(wm([]))

    def test_a_heavy_spec_wins(self):
        self.assertEqual(sid_propose._weighted_median([(7.77, 16619), (43.41, 124), (68.92, 343)]),
                         7.77)


# --- SID-12: filter and fold the additions ---------------------------------------------------------

ARCANE = 62
FOLD_SPEC_MAP = {**SPEC_MAP, ARCANE: {"class": "MAGE", "name": "Arcane", "role": 2}}


class Sid12FilterFoldTest(unittest.TestCase):
    """Additions are proposed only at high or medium confidence; an item effect (R8) applied by
    several classes becomes one class-neutral ALL proposal with the classes' evidence summed."""

    NAMES = {**NAMES, **{900300: "Well Fed", 900500: "Battle Stance", 900200: "Sprint"}}
    SIGNALS = {900300: set(), 900500: set(), 900200: {"speed_up"}}
    POOL = {900200, 900500}

    def additions(self, rows, decisions=None, summary=None, json_path=False):
        agg = agg_of(rows)
        if json_path:
            agg = via_evidence_json(agg)
        return sid_propose.additions(agg, FOLD_SPEC_MAP, self.NAMES, RULE_SHIPPED, self.SIGNALS,
                                     self.POOL, decisions=decisions or {}, summary=summary)

    # Half self, half onto one other player, no DB2 signal: R9 Utility at low confidence.
    LOW = ("WARRIOR", ARMS, "BUFF", 900500,
           rows_st(60, 4, self_=30, single=30, name="Battle Stance"))
    SPRINT = ("WARRIOR", ARMS, "BUFF", 900200, rows_st(60, 4, self_=60, recast=60.0, tag="s",
                                                       name="Sprint"))

    def well_fed(self, cls, spec, apps, players):
        return (cls, spec, "BUFF", 900300,
                rows_st(apps, players, self_=apps, recast=300.0, tag=cls, name="Well Fed"))

    def test_a_low_confidence_addition_is_not_proposed_but_is_in_the_dictionary(self):
        summary = {}
        props = self.additions([self.LOW, self.SPRINT], summary=summary)
        self.assertEqual([p.proposed for p in props], [[900200]])
        got = sid_propose.suggestions(agg_of([self.LOW]), FOLD_SPEC_MAP, self.SIGNALS, self.POOL)
        self.assertEqual(got[("WARRIOR", 900500)][:3], ("utility", "R9", "low"))
        self.assertEqual(summary, {"raw": 2, "low": 1, "folded": 0, "all": 0, "ruled": 0,
                                   "proposed": 1})

    def test_an_item_effect_of_three_classes_is_one_all_proposal_with_summed_evidence(self):
        rows = [self.well_fed("WARRIOR", ARMS, 40, 4), self.well_fed("SHAMAN", RESTO, 30, 3),
                self.well_fed("MAGE", ARCANE, 10, 2)]
        for json_path in (False, True):
            summary = {}
            props = self.additions(rows, summary=summary, json_path=json_path)
            self.assertEqual(len(props), 1, props)
            p = props[0]
            self.assertEqual((p.type, p.category, p.klass, p.name, p.listed, p.proposed, p.rule,
                              p.confidence, p.applications),
                             ("addition", "consumables", "ALL", "Well Fed", [], [900300], "R8",
                              "high", 80))
            self.assertEqual(p.evidence, {900300: {"WARRIOR Arms": (40, 4),
                                                   "SHAMAN Restoration": (30, 3),
                                                   "MAGE Arcane": (10, 2)}})
            self.assertIn("3 classes", p.reason)
            self.assertIn("80 applications / 9 players", p.reason)
            self.assertTrue(p.reason.endswith("→ Consumables."), p.reason)
            self.assertEqual(sid_propose.proposal_key(p), "addition|consumables|ALL|well fed|900300")
            # WARRIOR and SHAMAN were candidates on their own; MAGE (10 applications) was not.
            self.assertEqual(summary, {"raw": 2, "low": 0, "folded": 2, "all": 1, "ruled": 0,
                                       "proposed": 1})

    def test_classes_under_the_bar_alone_fold_into_one_above_it(self):
        rows = [self.well_fed("WARRIOR", ARMS, 12, 2), self.well_fed("SHAMAN", RESTO, 12, 2)]
        props = self.additions(rows)
        self.assertEqual([(p.klass, p.applications) for p in props], [("ALL", 24)])
        self.assertIn("24 applications / 4 players", props[0].reason)

    def test_an_item_effect_of_one_class_stays_with_that_class(self):
        props = self.additions([self.well_fed("WARRIOR", ARMS, 40, 4)])
        self.assertEqual([(p.klass, p.rule) for p in props], [("WARRIOR", "R8")])

    def test_a_ruled_all_proposal_is_not_returned_and_is_counted(self):
        rows = [self.well_fed("WARRIOR", ARMS, 40, 4), self.well_fed("SHAMAN", RESTO, 30, 3)]
        summary = {}
        decisions = {"addition|consumables|ALL|well fed|900300": {"ruling": "reject"}}
        self.assertEqual(self.additions(rows, decisions, summary), [])
        self.assertEqual(summary["ruled"], 1)
        self.assertEqual(summary["proposed"], 0)

    def test_an_item_effect_listed_under_all_by_name_is_left_to_corrections(self):
        shipped = RULE_SHIPPED + [{"key": "consumables2", "label": "c", "aura": "BUFF",
                                   "classes": {"ALL": [900301]}}]
        names = {**self.NAMES, 900301: "Well Fed"}
        rows = [self.well_fed("WARRIOR", ARMS, 40, 4), self.well_fed("SHAMAN", RESTO, 30, 3)]
        props = sid_propose.additions(agg_of(rows), FOLD_SPEC_MAP, names, shipped, self.SIGNALS,
                                      self.POOL)
        self.assertEqual(props, [])
