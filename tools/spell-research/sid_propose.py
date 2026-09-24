"""Stage 2 of the combat-log spell research: propose corrections to the shipped category lists.

Input is the merged per-spec evidence (a FileAggregate), the DB2 facts sid_db2 reads (spec map,
spell names, CastToAura families) and the shipped `spells`-kind categories. Output is two lists:

- corrections(): Proposal objects for existing entries. Evidence is grouped by CLASS and
  LOWER-CASED SPELL NAME (the entry's class key plus the DB2 name of the listed id), so a listed id
  and the ids the logs show under the same name are compared directly. A listed id's own evidence
  joins its group under whatever name the logs spell it (a spell renamed since the logs, or a log
  spelling that differs from DB2), so "never applied" means never applied by the class as that
  aura type, under any name.
    * replace -- the listed id is never applied by the class while a same-name aura is.
    * add     -- a same-name aura under another id is applied above the evidence bar and the
                 listed id stays (it is applied, or the candidate exception keeps it).
  The candidate exception (the spec's Ascendance case): a never-applied listed id that DB2 puts in
  the same CastToAura family as an observed id is kept, and flagged unverified, while some spec of
  the class that applies none of the same-name ids has fewer than `min_players` players in the
  logs -- that spec may be the one that applies it.
- flags(): Flag objects, report only, never proposals: unverified, stale, below_bar (a sighting of a
  listed spell under the evidence bar) and cc_unlisted (a player-applied crowd-control debuff in
  neither hardCC nor softCC).
- suggest(): the spec's category rules R1-R9, first match wins, over one aura's class-wide target
  shape, recast and DB2 signals. moves() applies it to listed BUFF entries (a move is medium
  confidence at most, and never from a debuff category); additions() to above-bar player BUFFs in
  no `spells` category.

Anything whose proposal_key() is already in decisions.json is not proposed again. Python 3.8+
standard library only; nothing here writes a file.
"""

import datetime
import statistics
from collections import Counter, OrderedDict
from dataclasses import dataclass
from typing import Dict, Iterable, List, Optional, Set, Tuple

AURA_TYPES = ("BUFF", "DEBUFF")

# The spec's evidence bar: a proposal needs this many applications from this many distinct players.
DEFAULT_MIN_APPLICATIONS = 20
DEFAULT_MIN_PLAYERS = 3
# Stale: a listed id not applied in the newest two months of the scanned range while a sibling is.
DEFAULT_STALE_DAYS = 60

# The debuff categories log evidence only cross-checks (research.py's DB2 mechanic method owns them).
CC_CATEGORIES = ("hardCC", "softCC")

# ChrSpecialization's levelling specs (OrderIndex 4, Name "Initial", one per class, e.g. 1444
# SHAMAN and 1446 WARRIOR in build 12.1.0.69875). No max-level player is ever in one, so they
# never count as a spec "the logs contain no player of".
LEVELLING_SPEC_NAME = "Initial"

UNKNOWN_SPEC = "unknown"

# A Categories.lua class key that lists the id for every class (racials, flasks): its evidence is the
# union of every class's, each spec named with its class ("SHAMAN Restoration").
ALL_CLASSES = "ALL"


@dataclass
class Thresholds:
    min_applications: int = DEFAULT_MIN_APPLICATIONS
    min_players: int = DEFAULT_MIN_PLAYERS
    stale_days: int = DEFAULT_STALE_DAYS


@dataclass
class Proposal:
    type: str              # "replace" | "add" | "move" | "addition"
    category: str          # category key (target category for move/addition)
    from_category: str     # for move; "" otherwise
    klass: str             # class token
    name: str              # spell name
    listed: list           # ids currently listed (replace/add/move)
    proposed: list         # ids to put in
    evidence: dict         # spell_id -> {spec_name: (applications, players)}
    rule: str              # "evidence" for replace/add; R1..R9 for move/addition
    reason: str            # one plain sentence
    confidence: str        # "high" | "medium" | "low"
    applications: int      # total, for ordering


@dataclass
class Flag:
    kind: str              # "unverified" | "stale" | "below_bar" | "cc_unlisted"
    category: str
    klass: str
    spell_id: int
    name: str
    detail: str


def proposal_key(p):
    # type: (Proposal) -> str
    """The decisions.json key: type|category|class|name lower-cased|sorted proposed ids."""
    return "%s|%s|%s|%s|%s" % (p.type, p.category, p.klass, p.name.lower(),
                               ",".join(map(str, sorted(p.proposed))))


# --- evidence ---------------------------------------------------------------------------------

def _top_name(names):
    if not names:
        return ""
    return sorted(names.items(), key=lambda kv: (-kv[1], kv[0]))[0][0]


def spec_name(spec_map, spec):
    # type: (Dict[int, dict], Optional[int]) -> str
    if spec is None:
        return UNKNOWN_SPEC
    info = spec_map.get(spec)
    return info["name"] if info and info.get("name") else str(spec)


def _class_names(agg, aura_type):
    # type: (object, Optional[str]) -> Dict[Tuple[str, str, int], Counter]
    """{(class, aura type, spell_id): spellings summed over every spec of the class}."""
    out = {}  # type: Dict[Tuple[str, str, int], Counter]
    for (cls, _spec), auras in agg.per_spec.items():
        for (atype, spell_id), st in auras.items():
            if aura_type is None or atype == aura_type:
                out.setdefault((cls, atype, spell_id), Counter()).update(st.names)
    return out


def evidence_index(agg, spec_map, aura_type=None):
    """{(class, name lower-cased): {spell_id: {spec_id: entry}}}, one entry per spec that applied it.

    entry: {"spec": spec name, "apps", "players" (distinct casters), "first_seen", "last_seen",
    "player_set"}. player_set holds the aggregate's caster ids so a total across specs can count a
    player seen in two specs once; it is never serialised (from evidence.json the sets are
    placeholders and the exact union comes from the aggregate's class_players instead). `aura_type`
    ("BUFF"/"DEBUFF") keeps only that aura type. The name is the aura's most common spelling across
    every spec of the class, so each (class, spell_id) lands in exactly one group.
    """
    names = _class_names(agg, aura_type)
    out = {}  # type: Dict[Tuple[str, str], Dict[int, Dict[Optional[int], dict]]]
    for (cls, spec), auras in agg.per_spec.items():
        for (atype, spell_id), st in auras.items():
            if aura_type is not None and atype != aura_type:
                continue
            name = _top_name(names[(cls, atype, spell_id)])
            if not name or not st.applications:
                continue
            by_spec = out.setdefault((cls, name.lower()), {}).setdefault(spell_id, {})
            e = by_spec.get(spec)
            if e is None:
                e = by_spec[spec] = {"spec": spec_name(spec_map, spec), "apps": 0, "players": 0,
                                     "first_seen": "", "last_seen": "", "player_set": set()}
            e["apps"] += st.applications
            e["player_set"] |= set(st.players)
            e["players"] = len(e["player_set"])
            if st.first_seen and (not e["first_seen"] or st.first_seen < e["first_seen"]):
                e["first_seen"] = st.first_seen
            if st.last_seen and st.last_seen > e["last_seen"]:
                e["last_seen"] = st.last_seen
    return out


@dataclass
class _Total:
    apps: int
    players: int
    last_seen: str


def _total(by_spec, players=None):
    # type: (Dict[Optional[int], dict], Optional[int]) -> _Total
    """Totals across specs; `players`, when given, is the exact class-wide distinct count."""
    if players is None:
        seen = set()  # type: Set[str]
        for e in by_spec.values():
            seen |= e["player_set"]
        players = len(seen)
    return _Total(sum(e["apps"] for e in by_spec.values()), players,
                  max((e["last_seen"] for e in by_spec.values()), default=""))


def _spec_evidence(by_spec):
    # type: (Dict[Optional[int], dict]) -> Dict[str, Tuple[int, int]]
    return {e["spec"]: (e["apps"], e["players"]) for e in by_spec.values()}


def spec_player_counts(agg):
    # type: (object) -> Dict[tuple, int]
    """{(class, spec): distinct players seen applying ANY aura}: which specs the logs cover.

    From evidence.json (whose caster sets are placeholders) the exact count is the aggregate's
    spec_players; only an evidence.json older than that table falls back to the largest
    single-aura count, a lower bound, which only ever keeps the exception longer.
    """
    exact = getattr(agg, "spec_players", None) or {}
    out = {}
    for key, auras in agg.per_spec.items():
        if key in exact:
            out[key] = exact[key]
            continue
        seen = set()  # type: Set[str]
        for st in auras.values():
            seen |= set(st.players)
        out[key] = len(seen)
    return out


def _cutoff(last_date, days):
    # type: (str, int) -> Optional[str]
    if not last_date:
        return None
    try:
        end = datetime.date.fromisoformat(last_date)
    except ValueError:
        return None
    return (end - datetime.timedelta(days=days)).isoformat()


# --- the review of one (category, class, name) group ----------------------------------------------

class _Review:
    """One pass over the shipped categories; collects both proposals and flags."""

    def __init__(self, agg, spec_map, names, shipped, aura_to_family, th, cc_ids=None):
        self.spec_map = spec_map
        # Crowd-control ids by DB2 mechanic; None = unknown, no filter. A CC category only ever
        # takes an id DB2 calls CC (its lists are research.py's mechanic method).
        self.cc_ids = None if cc_ids is None else set(cc_ids)
        self.names = names
        self.shipped = shipped
        self.family = aura_to_family or {}
        self.th = th
        self.indexes = {t: evidence_index(agg, spec_map, t) for t in AURA_TYPES}
        # {aura type: {(class, spell_id): by_spec}}: a listed id's evidence under any spelling.
        self.by_id = {t: {(cls, sid): by_spec for (cls, _n), ids in idx.items()
                          for sid, by_spec in ids.items()}
                      for t, idx in self.indexes.items()}
        # Exact class-wide distinct players from evidence.json; empty for an in-memory aggregate.
        self.class_players = getattr(agg, "class_players", None) or {}
        self.coverage = spec_player_counts(agg)
        self.cutoff = _cutoff(agg.last_date, th.stale_days)
        self.proposals = []  # type: List[Proposal]
        self.flags = []  # type: List[Flag]

    def run(self):
        for cat in self.shipped:
            atype = cat.get("aura", "BUFF")
            index = self.indexes.get(atype, {})
            by_id = self.by_id.get(atype, {})
            for klass, ids in cat["classes"].items():
                groups = OrderedDict()  # type: Dict[str, Tuple[str, List[int]]]
                for spell_id in ids:
                    name = self.names.get(spell_id)
                    if not name:
                        continue  # no DB2 name: nothing to match the logs against
                    groups.setdefault(name.lower(), (name, []))[1].append(spell_id)
                for name_l, (name, listed) in groups.items():
                    if klass == ALL_CLASSES:
                        ev = self.all_classes(index, by_id, name_l, listed)
                    else:
                        ev = dict(index.get((klass, name_l), {}))
                    for sid in listed:  # applied under another spelling: still applied
                        if sid not in ev and (klass, sid) in by_id:
                            ev[sid] = by_id[(klass, sid)]
                    if cat["key"] in CC_CATEGORIES and self.cc_ids is not None:
                        # A same-name DoT or tether is not the crowd control (Rake's bleed).
                        ev = {sid: e for sid, e in ev.items() if sid in listed or sid in self.cc_ids}
                    self.group(cat["key"], klass, atype, name, listed, ev)
        return self

    @staticmethod
    def all_classes(index, by_id, name_l, listed):
        """An ALL entry's evidence: every class's, keyed (class, spec), spec names class-prefixed."""
        ev = {}  # type: Dict[int, Dict[tuple, dict]]

        def take(cls, sid, by_spec):
            for spec, e in by_spec.items():
                ev.setdefault(sid, {})[(cls, spec)] = dict(e, spec="%s %s" % (cls, e["spec"]))

        for (cls, n), ids in index.items():
            if n == name_l:
                for sid, by_spec in ids.items():
                    take(cls, sid, by_spec)
        for (cls, sid), by_spec in by_id.items():  # a listed id under another spelling
            if sid in listed and not any(k[0] == cls for k in ev.get(sid, {})):
                take(cls, sid, by_spec)
        return ev

    def players(self, klass, atype, sid):
        # type: (str, str, int) -> Optional[int]
        """Exact distinct casters from evidence.json; for ALL the per-class sum (a character has
        one class, so the classes' caster sets are disjoint). None for an in-memory aggregate."""
        if klass != ALL_CLASSES:
            return self.class_players.get((klass, atype, sid))
        counts = [n for (c, t, i), n in self.class_players.items() if t == atype and i == sid]
        return sum(counts) if counts else None

    def meets(self, total):
        # type: (_Total) -> bool
        return total.apps >= self.th.min_applications and total.players >= self.th.min_players

    def flag(self, kind, category, klass, spell_id, detail):
        self.flags.append(Flag(kind, category, klass, spell_id, self.names.get(spell_id, ""), detail))

    def group(self, category, klass, atype, name, listed, ev):
        totals = {sid: _total(by_spec, self.players(klass, atype, sid)) for sid, by_spec in ev.items()}
        for sid in sorted(ev):
            if not self.meets(totals[sid]):
                self.flag("below_bar", category, klass, sid,
                          "%d applications / %d players, under the bar of %d / %d"
                          % (totals[sid].apps, totals[sid].players,
                             self.th.min_applications, self.th.min_players))
        new_ids = sorted(sid for sid in ev if sid not in listed and self.meets(totals[sid]))
        never = [sid for sid in listed if sid not in ev]
        self.stale(category, klass, listed, totals)
        if not new_ids:
            for sid in never:
                self.flag("unverified", category, klass, sid,
                          "no %s applied it or any aura named %s" % (_who(klass), name))
            return
        covering = {spec for by_spec in ev.values() for spec in by_spec}
        kept, replaceable = [], []
        for sid in never:
            missing = self.uncovered_specs(klass, covering) if self.in_family(sid, ev) else []
            if missing:
                kept.append(sid)
                self.flag("unverified", category, klass, sid,
                          "a DB2 candidate of the same cast as %s; too few %s players in the logs"
                          % (", ".join(map(str, new_ids)), " or ".join(missing)))
            else:
                replaceable.append(sid)
        applications = sum(totals[sid].apps for sid in new_ids)
        if replaceable:
            ptype, plisted, confidence = "replace", replaceable, "high"
            reason = ("%s never applied by any %s, while %s applied %s %d times"
                      % (_ids(replaceable), _who(klass), _ids(new_ids), name, applications))
        else:
            ptype, plisted = "add", list(listed)
            confidence = "medium" if kept else "high"
            reason = ("%s applied %s %d times under %s, which is not listed"
                      % ("Players" if klass == ALL_CLASSES else klass, name, applications,
                         _ids(new_ids)))
        evidence = {sid: _spec_evidence(ev.get(sid, {})) for sid in list(plisted) + new_ids}
        self.proposals.append(Proposal(
            type=ptype, category=category, from_category="", klass=klass, name=name,
            listed=plisted, proposed=new_ids, evidence=evidence, rule="evidence",
            reason=reason + ".", confidence=confidence, applications=applications))

    def in_family(self, sid, ev):
        own = self.family.get(sid, set())
        return any(other in own or sid in self.family.get(other, set()) for other in ev)

    def uncovered_specs(self, klass, covering):
        # type: (str, Set[Optional[int]]) -> List[str]
        """Real specs of the class that apply no same-name id and have too few players in the logs."""
        out = []
        for spec, info in sorted(self.spec_map.items()):
            if info.get("class") != klass or info.get("name") == LEVELLING_SPEC_NAME:
                continue
            if spec in covering:
                continue
            if self.coverage.get((klass, spec), 0) < self.th.min_players:
                out.append(info.get("name") or str(spec))
        return out

    def stale(self, category, klass, listed, totals):
        if not self.cutoff:
            return
        for sid in listed:
            t = totals.get(sid)
            if t is None or not t.last_seen or t.last_seen >= self.cutoff:
                continue
            fresh = sorted(o for o in totals if o != sid and totals[o].last_seen >= self.cutoff)
            if fresh:
                self.flag("stale", category, klass, sid,
                          "last applied %s, before %s, while %s is still applied"
                          % (t.last_seen, self.cutoff, _ids(fresh)))

    def cc_unlisted(self, agg, cc_ids):
        """Player-applied CC debuffs above the bar that are in neither hardCC nor softCC."""
        listed = set()  # type: Set[int]
        for cat in self.shipped:
            if cat["key"] in CC_CATEGORIES:
                for ids in cat["classes"].values():
                    listed.update(ids)
        per_class = {}  # type: Dict[Tuple[str, int], dict]
        for (cls, spec), auras in agg.per_spec.items():
            for (atype, sid), st in auras.items():
                if atype != "DEBUFF" or sid not in cc_ids or sid in listed:
                    continue
                slot = per_class.setdefault((cls, sid), {"apps": 0, "players": set(), "names": {}})
                slot["apps"] += st.applications
                slot["players"] |= set(st.players)
                for n, c in st.names.items():
                    slot["names"][n] = slot["names"].get(n, 0) + c
        for (cls, sid), slot in sorted(per_class.items()):
            players = self.class_players.get((cls, "DEBUFF", sid), len(slot["players"]))
            total = _Total(slot["apps"], players, "")
            if not self.meets(total):
                continue
            self.flags.append(Flag(
                "cc_unlisted", "", cls, sid, self.names.get(sid) or _top_name(slot["names"]),
                "%d applications / %d players; DB2 gives it a crowd-control mechanic, and it is in "
                "neither hardCC nor softCC" % (total.apps, total.players)))


def _who(klass):
    # type: (str) -> str
    return "player" if klass == ALL_CLASSES else "%s player" % klass


def _ids(ids):
    # type: (Iterable[int]) -> str
    return ", ".join(map(str, ids))


_FLAG_ORDER = {"unverified": 0, "stale": 1, "below_bar": 2, "cc_unlisted": 3}


def corrections(agg, spec_map, names, shipped, aura_to_family, decisions=None, thresholds=None,
                cc_ids=None):
    """Replace and Add proposals for listed entries, most-applied first, minus ruled keys.

    `cc_ids` (DB2's crowd-control ids, as for flags()) keeps a same-name id without a CC mechanic
    out of hardCC and softCC; None applies no such filter.
    """
    review = _Review(agg, spec_map, names, shipped, aura_to_family, thresholds or Thresholds(),
                     cc_ids).run()
    ruled = decisions or {}
    out = [p for p in review.proposals if proposal_key(p) not in ruled]
    out.sort(key=lambda p: (-p.applications, p.category, p.klass, p.name.lower()))
    return out


def flags(agg, spec_map, names, shipped, aura_to_family, cc_ids=frozenset(), thresholds=None):
    """Unverified, stale, below_bar and cc_unlisted flags; report only.

    `cc_ids` is the set of spell ids DB2 gives a crowd-control mechanic (research.BUCKET_MECHANICS'
    mechanics); the caller derives it, so this module stays free of SpellEffect reads.
    """
    review = _Review(agg, spec_map, names, shipped, aura_to_family, thresholds or Thresholds(),
                     cc_ids).run()
    review.cc_unlisted(agg, set(cc_ids))
    return sorted(review.flags, key=lambda f: (_FLAG_ORDER.get(f.kind, 9), f.category, f.klass,
                                               f.spell_id))


# --- SID-6: category rules R1-R9, moves and additions ---------------------------------------------

# Rule thresholds (the spec's table). Shares are of the aura's applications across every spec of
# the class. The scanner counts a burst ONCE in `group` and absorbs its companions, so `group` is a
# count of bursts, not of applications; the applications inside bursts are the rest,
# applications - self - single, and that is the group share.
SELF_SHARE = 0.90        # R1, R3, R7
GROUP_SHARE = 0.30       # R2
SINGLE_SHARE = 0.70      # R5
OTHERS_SHARE = 0.50      # R6 "applied mostly to others": more than half not on the caster
LONG_RECAST = 60.0       # R3: median seconds between self-applications
SHORT_RECAST = 30.0      # R6, R7

TANK_ROLE = 0  # ChrSpecialization.Role: 0 tank, 1 healer, 2 damage (build 12.1.0.69875)

DEFENSIVE_SIGNALS = frozenset({"damage_taken_down", "absorb"})
RAID_SIGNALS = frozenset({"damage_taken_down", "absorb", "periodic_heal"})
# "A damage, haste, crit, mastery or versatility increase". stat_pct_up (a primary-stat percent,
# e.g. Pillar of Frost's Strength) is a damage increase too; rating_up covers the four ratings.
OFFENSIVE_SIGNALS = frozenset({"damage_up", "haste_up", "crit_up", "rating_up", "stat_pct_up"})
MOVEMENT_SIGNALS = frozenset({"speed_up"})
HEALING_SIGNALS = frozenset({"periodic_heal", "absorb"})

_SIGNAL_WORDS = {
    "damage_taken_down": "reduces damage taken", "absorb": "absorbs damage",
    "periodic_heal": "heals over time", "damage_up": "raises damage done", "haste_up": "raises haste",
    "crit_up": "raises critical strike", "rating_up": "raises a secondary stat",
    "stat_pct_up": "raises a primary stat", "speed_up": "raises movement speed",
}

CATEGORY_LABELS = {
    "defensives": "Defensive cooldowns", "raidCDs": "Raid cooldowns",
    "offensiveCDs": "Offensive cooldowns", "movement": "Movement", "support": "Support",
    "healing": "Healing", "activeMitigation": "Active mitigation", "consumables": "Consumables",
    "utility": "Utility",
}

_CONFIDENCE_RANK = {"low": 0, "medium": 1, "high": 2}


@dataclass
class _Facts:
    apps: int
    self_: float      # shares, 0..1
    single: float
    group: float      # applications inside bursts
    bursts: int
    recast: Optional[float]
    signals: Set[str]
    in_pool: bool
    tank_only: bool


def _pct(share):
    return "%d%%" % round(share * 100)


def _says(f, wanted):
    return " and ".join(_SIGNAL_WORDS[s] for s in sorted(f.signals & wanted))


def _recast(f):
    return "recast about %gs" % f.recast


# (rule id, predicate, category, confidence, reason) in the spec's table order; the first match
# wins. Each reason names the evidence it rests on, in plain words, and ends with the category.
_RULES = (
    ("R1", lambda f: f.signals & DEFENSIVE_SIGNALS and f.self_ >= SELF_SHARE,
     "defensives", "high",
     lambda f: "%s self-applied and DB2 says it %s" % (_pct(f.self_), _says(f, DEFENSIVE_SIGNALS))),
    ("R2", lambda f: f.group >= GROUP_SHARE and f.signals & RAID_SIGNALS,
     "raidCDs", "high",
     lambda f: "%s of applications land on 5+ players at once (%d bursts) and DB2 says it %s"
     % (_pct(f.group), f.bursts, _says(f, RAID_SIGNALS))),
    ("R3", lambda f: (f.self_ >= SELF_SHARE and f.signals & OFFENSIVE_SIGNALS
                      and f.recast is not None and f.recast >= LONG_RECAST),
     "offensiveCDs", "high",
     lambda f: "%s self-applied, DB2 says it %s, %s"
     % (_pct(f.self_), _says(f, OFFENSIVE_SIGNALS), _recast(f))),
    ("R4", lambda f: f.signals & MOVEMENT_SIGNALS,
     "movement", "high",
     lambda f: "DB2 says it raises movement speed"),
    ("R5", lambda f: f.single >= SINGLE_SHARE,
     "support", "medium",
     lambda f: "%s of applications go to one other player (Blizzard's EXTERNAL_DEFENSIVE tag is not "
     "readable offline, so an external defensive is not excluded)" % _pct(f.single)),
    ("R6", lambda f: (f.signals & HEALING_SIGNALS and 1 - f.self_ > OTHERS_SHARE
                      and f.recast is not None and f.recast < SHORT_RECAST),
     "healing", "medium",
     lambda f: "DB2 says it %s, %s applied to others, %s"
     % (_says(f, HEALING_SIGNALS), _pct(1 - f.self_), _recast(f))),
    ("R7", lambda f: (f.tank_only and f.self_ >= SELF_SHARE
                      and f.recast is not None and f.recast < SHORT_RECAST),
     "activeMitigation", "medium",
     lambda f: "only tank specs apply it, %s self-applied, %s" % (_pct(f.self_), _recast(f))),
    ("R8", lambda f: not f.in_pool,
     "consumables", "high",
     lambda f: "not in the player-castable spell pool, so an item or consumable effect"),
)


def _facts(stats, signals, in_pool, tank_only):
    # type: (dict, Set[str], bool, bool) -> Optional[_Facts]
    """suggest()'s inputs as shares; None when there are no applications."""
    apps = stats.get("applications", 0)
    if apps <= 0:
        return None
    self_, single = stats.get("self", 0), stats.get("single", 0)
    return _Facts(apps=apps, self_=self_ / apps, single=single / apps,
                  group=max(apps - self_ - single, 0) / apps, bursts=stats.get("group", 0),
                  recast=stats.get("recast"), signals=set(signals or ()), in_pool=in_pool,
                  tank_only=tank_only)


def meets_category(category, stats, signals, in_pool, tank_only):
    # type: (str, dict, Set[str], bool, bool) -> bool
    """Whether one aura's evidence meets its OWN category's rule, whatever rule would win first.

    The spec moves an entry only when its behaviour contradicts its category's rule; the first
    match of the table is not that test (Rejuvenation meets R6 Healing, though R5 Support is met
    first; Avatar meets R3 though R1 is). Utility's rule is R9, "none of the above". A category no
    rule names (or an aura with no applications) is never contradicted.
    """
    f = _facts(stats, signals, in_pool, tank_only)
    if f is None:
        return True
    if category == "utility":
        return not any(predicate(f) for _r, predicate, _c, _conf, _why in _RULES)
    own = [predicate for _r, predicate, cat, _conf, _why in _RULES if cat == category]
    return not own or any(predicate(f) for predicate in own)


def suggest(stats, signals, in_pool, tank_only):
    # type: (dict, Set[str], bool, bool) -> Tuple[Optional[str], str, str, str]
    """(category key or None, rule id, confidence, reason sentence) for one aura, by rules R1-R9.

    stats: {"applications", "self", "single", "group" (bursts), "recast" (median seconds or None)},
    summed over every spec of the class. signals: sid_db2.aura_signals' names for the aura.
    in_pool: the aura (or the cast it comes from) is player-castable. tank_only: every spec that
    applied it is a tank spec.
    """
    f = _facts(stats, signals, in_pool, tank_only)
    if f is None:
        return None, "R9", "low", "No applications, so no suggestion."
    self_, single = stats.get("self", 0), stats.get("single", 0)
    for rule, predicate, category, confidence, reason in _RULES:
        if predicate(f):
            return category, rule, confidence, "%s → %s." % (reason(f), CATEGORY_LABELS[category])
    shape_words = "%s self, %s single, %s group" % (_pct(f.self_), _pct(f.single), _pct(f.group))
    if not self_ and not single:
        return None, "R9", "low", "No rule matched (%s), so no suggestion." % shape_words
    return "utility", "R9", "low", "No rule matched (%s) → Utility." % shape_words


def _class_rows(agg, aura_type):
    # type: (object, str) -> Dict[Tuple[str, int], List[Tuple[Optional[int], object]]]
    """{(class, spell_id): [(spec, AuraStats), ...]} for one aura type."""
    out = {}  # type: Dict[Tuple[str, int], List[Tuple[Optional[int], object]]]
    for (cls, spec), auras in agg.per_spec.items():
        for (atype, sid), st in auras.items():
            if atype == aura_type and st.applications:
                out.setdefault((cls, sid), []).append((spec, st))
    return out


def _stats_of(rows):
    """suggest()'s stats summed over specs. The recast median pools every spec's samples; from
    evidence.json each spec carries only its own median, so there it is a median of medians."""
    samples = [x for _spec, st in rows for x in st.recast_samples]
    return {"applications": sum(st.applications for _s, st in rows),
            "self": sum(st.self_ for _s, st in rows),
            "single": sum(st.single for _s, st in rows),
            "group": sum(st.group for _s, st in rows),
            "recast": round(statistics.median(samples), 2) if samples else None}


def _tank_only(rows, spec_map):
    specs = {spec for spec, _st in rows if spec is not None}
    return bool(specs) and all(spec_map.get(s, {}).get("role") == TANK_ROLE for s in specs)


def _castable(pool, cast_candidates):
    # type: (Iterable[int], Optional[Dict[int, List[int]]]) -> Set[int]
    """The pool plus every aura a pooled cast lands (CastToAura): the pool holds cast ids."""
    out = set(pool or ())
    for cast, auras in (cast_candidates or {}).items():
        if cast in out:
            out.update(auras)
    return out


class _Ruled:
    """Shared state of moves() and additions(): evidence per (class, id), the bar, the rules."""

    def __init__(self, agg, spec_map, names, signals, pool, cast_candidates, th, pool_names=None):
        self.spec_map = spec_map
        self.names = names
        self.signals = signals or {}
        self.castable = _castable(pool, cast_candidates)
        self.pool_names = pool_names or {}
        self.th = th
        self.rows = _class_rows(agg, "BUFF")
        self.class_players = getattr(agg, "class_players", None) or {}

    def total(self, klass, sid):
        rows = self.rows[(klass, sid)]
        players = self.class_players.get((klass, "BUFF", sid))
        if players is None:
            seen = set()  # type: Set[str]
            for _spec, st in rows:
                seen |= set(st.players)
            players = len(seen)
        return _Total(sum(st.applications for _s, st in rows), players, "")

    def suggest(self, klass, sid):
        rows = self.rows[(klass, sid)]
        return suggest(_stats_of(rows), self.signals.get(sid, set()), self.in_pool(klass, sid),
                       _tank_only(rows, self.spec_map))

    def in_pool(self, klass, sid):
        """A class spell: in the castable ids, or named like a pool spell of the same class."""
        if sid in self.castable:
            return True
        name = self.name(klass, sid)
        return bool(name) and name.lower() in self.pool_names.get(klass, ())

    def meets(self, total):
        return total.apps >= self.th.min_applications and total.players >= self.th.min_players

    def fits(self, category, klass, sid):
        """The listed aura meets its own category's rule (meets_category)."""
        rows = self.rows[(klass, sid)]
        return meets_category(category, _stats_of(rows), self.signals.get(sid, set()),
                              self.in_pool(klass, sid), _tank_only(rows, self.spec_map))

    def evidence(self, klass, sid):
        return {spec_name(self.spec_map, spec): (st.applications, len(st.players))
                for spec, st in sorted(self.rows[(klass, sid)],
                                       key=lambda r: -1 if r[0] is None else r[0])}

    def name(self, klass, sid):
        if self.names.get(sid):
            return self.names[sid]
        spellings = Counter()  # type: Counter
        for _spec, st in self.rows[(klass, sid)]:
            spellings.update(st.names)
        return _top_name(spellings)


def _spells_keys(shipped):
    return {cat["key"] for cat in shipped}


def _category_ids(shipped):
    # type: (list) -> Dict[str, Set[int]]
    """{category key: every id listed under any class} (the addon's filter ignores the class)."""
    return {cat["key"]: {sid for ids in cat["classes"].values() for sid in ids} for cat in shipped}


def _ordered(props, decisions):
    ruled = decisions or {}
    out = [p for p in props if proposal_key(p) not in ruled]
    out.sort(key=lambda p: (-p.applications, p.category, p.klass, p.name.lower()))
    return out


def moves(agg, spec_map, names, shipped, signals, pool, cast_candidates=None, decisions=None,
          thresholds=None, pool_names=None):
    """Move proposals: a listed BUFF entry whose evidence contradicts its category's rule.

    The entry must fail its own category's rule (meets_category); the target is then what the
    table suggests.
    Only above-bar entries, only a suggestion of at least medium confidence, only into a category
    the file has and that does not already list the id; the move itself is medium at most (the
    spec). Debuff categories are never moved: log evidence only cross-checks them.
    """
    ruled = _Ruled(agg, spec_map, names, signals, pool, cast_candidates, thresholds or Thresholds(),
                   pool_names)
    listed_in = _category_ids(shipped)
    out = []  # type: List[Proposal]
    for cat in shipped:
        if cat.get("aura", "BUFF") != "BUFF":
            continue
        for klass, ids in cat["classes"].items():
            for sid in ids:
                if (klass, sid) not in ruled.rows:
                    continue
                total = ruled.total(klass, sid)
                if not ruled.meets(total) or ruled.fits(cat["key"], klass, sid):
                    continue
                target, rule, confidence, reason = ruled.suggest(klass, sid)
                if (target is None or target == cat["key"] or target not in listed_in
                        or sid in listed_in[target] or _CONFIDENCE_RANK[confidence] < 1):
                    continue
                out.append(Proposal(
                    type="move", category=target, from_category=cat["key"], klass=klass,
                    name=ruled.name(klass, sid), listed=[sid], proposed=[sid],
                    evidence={sid: ruled.evidence(klass, sid)}, rule=rule, reason=reason,
                    confidence="medium", applications=total.apps))
    return _ordered(out, decisions)


def additions(agg, spec_map, names, shipped, signals, pool, cast_candidates=None, decisions=None,
              thresholds=None, pool_names=None):
    """Addition proposals: above-bar player BUFFs in no `spells` category, with a category by rule.

    An aura named like a spell the class already lists (in a BUFF category) is left to
    corrections(), which proposes it as a replace or an add. No proposal when the rules give no
    category, or one the file lacks.
    """
    ruled = _Ruled(agg, spec_map, names, signals, pool, cast_candidates, thresholds or Thresholds(),
                   pool_names)
    listed = set().union(*_category_ids(shipped).values()) if shipped else set()
    keys = _spells_keys(shipped)
    listed_names = set()  # type: Set[Tuple[str, str]]
    for cat in shipped:
        if cat.get("aura", "BUFF") == "BUFF":
            for klass, ids in cat["classes"].items():
                listed_names.update((klass, names[sid].lower()) for sid in ids if names.get(sid))
    out = []  # type: List[Proposal]
    for (klass, sid) in sorted(ruled.rows):
        if sid in listed:
            continue
        name = ruled.name(klass, sid)
        if not name or (klass, name.lower()) in listed_names:
            continue
        total = ruled.total(klass, sid)
        if not ruled.meets(total):
            continue
        target, rule, confidence, reason = ruled.suggest(klass, sid)
        if target is None or target not in keys:
            continue
        out.append(Proposal(
            type="addition", category=target, from_category="", klass=klass, name=name, listed=[],
            proposed=[sid], evidence={sid: ruled.evidence(klass, sid)}, rule=rule, reason=reason,
            confidence=confidence, applications=total.apps))
    return _ordered(out, decisions)


def suggestions(agg, spec_map, signals, pool, cast_candidates=None, pool_names=None, names=None):
    """{(class, spell_id): suggest()'s (category or None, rule, confidence, reason)} for every
    player BUFF, whatever its count: the dictionary's suggested-category column."""
    ruled = _Ruled(agg, spec_map, names or {}, signals, pool, cast_candidates, Thresholds(),
                   pool_names)
    return {key: ruled.suggest(*key) for key in sorted(ruled.rows)}
