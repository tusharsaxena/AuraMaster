"""Stage 2 of the combat-log spell research: propose corrections to the shipped category lists.

Input is the merged per-spec evidence (a FileAggregate), the DB2 facts sid_db2 reads (spec map,
spell names, CastToAura families) and the shipped `spells`-kind categories. Output is two lists:

- corrections(): Proposal objects for existing entries. Evidence is grouped by CLASS and
  LOWER-CASED SPELL NAME (the entry's class key plus the DB2 name of the listed id), so a listed id
  and the ids the logs show under the same name are compared directly.
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

Anything whose proposal_key() is already in decisions.json is not proposed again. Python 3.8+
standard library only; nothing here writes a file.
"""

import datetime
from collections import OrderedDict
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


def evidence_index(agg, spec_map, aura_type=None):
    """{(class, name lower-cased): {spell_id: {spec_id: entry}}}, one entry per spec that applied it.

    entry: {"spec": spec name, "apps", "players" (distinct casters), "first_seen", "last_seen",
    "player_set"}. player_set holds the aggregate's in-memory caster ids so a total across specs can
    count a player seen in two specs once; it is never serialised. `aura_type` ("BUFF"/"DEBUFF")
    keeps only that aura type. The name is the aura's most common spelling in the logs.
    """
    out = {}  # type: Dict[Tuple[str, str], Dict[int, Dict[Optional[int], dict]]]
    for (cls, spec), auras in agg.per_spec.items():
        for (atype, spell_id), st in auras.items():
            if aura_type is not None and atype != aura_type:
                continue
            name = _top_name(st.names)
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


def _total(by_spec):
    # type: (Dict[Optional[int], dict]) -> _Total
    players = set()  # type: Set[str]
    for e in by_spec.values():
        players |= e["player_set"]
    return _Total(sum(e["apps"] for e in by_spec.values()), len(players),
                  max((e["last_seen"] for e in by_spec.values()), default=""))


def _spec_evidence(by_spec):
    # type: (Dict[Optional[int], dict]) -> Dict[str, Tuple[int, int]]
    return {e["spec"]: (e["apps"], e["players"]) for e in by_spec.values()}


def spec_player_counts(agg):
    # type: (object) -> Dict[tuple, int]
    """{(class, spec): distinct players seen applying ANY aura}: which specs the logs cover.

    From evidence.json the caster sets are placeholders of each aura's recorded size, so the count
    is the largest single-aura count: a lower bound, which only ever keeps the exception longer.
    """
    out = {}
    for key, auras in agg.per_spec.items():
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

    def __init__(self, agg, spec_map, names, shipped, aura_to_family, th):
        self.spec_map = spec_map
        self.names = names
        self.shipped = shipped
        self.family = aura_to_family or {}
        self.th = th
        self.indexes = {t: evidence_index(agg, spec_map, t) for t in AURA_TYPES}
        self.coverage = spec_player_counts(agg)
        self.cutoff = _cutoff(agg.last_date, th.stale_days)
        self.proposals = []  # type: List[Proposal]
        self.flags = []  # type: List[Flag]

    def run(self):
        for cat in self.shipped:
            index = self.indexes.get(cat.get("aura", "BUFF"), {})
            for klass, ids in cat["classes"].items():
                groups = OrderedDict()  # type: Dict[str, Tuple[str, List[int]]]
                for spell_id in ids:
                    name = self.names.get(spell_id)
                    if not name:
                        continue  # no DB2 name: nothing to match the logs against
                    groups.setdefault(name.lower(), (name, []))[1].append(spell_id)
                for name_l, (name, listed) in groups.items():
                    self.group(cat["key"], klass, name, listed, index.get((klass, name_l), {}))
        return self

    def meets(self, total):
        # type: (_Total) -> bool
        return total.apps >= self.th.min_applications and total.players >= self.th.min_players

    def flag(self, kind, category, klass, spell_id, detail):
        self.flags.append(Flag(kind, category, klass, spell_id, self.names.get(spell_id, ""), detail))

    def group(self, category, klass, name, listed, ev):
        totals = {sid: _total(by_spec) for sid, by_spec in ev.items()}
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
                          "no %s player applied it or any aura named %s" % (klass, name))
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
            reason = ("%s never applied by any %s player, while %s applied %s %d times"
                      % (_ids(replaceable), klass, _ids(new_ids), name, applications))
        else:
            ptype, plisted = "add", list(listed)
            confidence = "medium" if kept else "high"
            reason = ("%s applied %s %d times under %s, which is not listed"
                      % (klass, name, applications, _ids(new_ids)))
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
            total = _Total(slot["apps"], len(slot["players"]), "")
            if not self.meets(total):
                continue
            self.flags.append(Flag(
                "cc_unlisted", "", cls, sid, self.names.get(sid) or _top_name(slot["names"]),
                "%d applications / %d players; DB2 gives it a crowd-control mechanic, and it is in "
                "neither hardCC nor softCC" % (total.apps, total.players)))


def _ids(ids):
    # type: (Iterable[int]) -> str
    return ", ".join(map(str, ids))


_FLAG_ORDER = {"unverified": 0, "stale": 1, "below_bar": 2, "cc_unlisted": 3}


def corrections(agg, spec_map, names, shipped, aura_to_family, decisions=None, thresholds=None):
    """Replace and Add proposals for listed entries, most-applied first, minus ruled keys."""
    review = _Review(agg, spec_map, names, shipped, aura_to_family, thresholds or Thresholds()).run()
    ruled = decisions or {}
    out = [p for p in review.proposals if proposal_key(p) not in ruled]
    out.sort(key=lambda p: (-p.applications, p.category, p.klass, p.name.lower()))
    return out


def flags(agg, spec_map, names, shipped, aura_to_family, cc_ids=frozenset(), thresholds=None):
    """Unverified, stale, below_bar and cc_unlisted flags; report only.

    `cc_ids` is the set of spell ids DB2 gives a crowd-control mechanic (research.BUCKET_MECHANICS'
    mechanics); the caller derives it, so this module stays free of SpellEffect reads.
    """
    review = _Review(agg, spec_map, names, shipped, aura_to_family, thresholds or Thresholds()).run()
    review.cc_unlisted(agg, set(cc_ids))
    return sorted(review.flags, key=lambda f: (_FLAG_ORDER.get(f.kind, 9), f.category, f.klass,
                                               f.spell_id))
