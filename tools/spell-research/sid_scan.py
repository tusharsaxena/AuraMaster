"""Stage 1 of the combat-log spell research: read WoW combat log lines.

This module turns raw combat log lines into fields, decides whether an aura's
source is a player character (never a pet, totem, guardian or NPC), and
tracks each player's specialization from COMBATANT_INFO lines.

Python 3.8+ standard library only. Lines are handled as bytes so a scan can
stream a multi-gigabyte log without decoding it all at once; a line that
cannot be decoded or split is reported as None and counted by the caller as
skipped, never fatal.

scan_file() folds one log into a FileAggregate: per (class, spec) and per
(aura type, spell id), the applications, distinct casters, target shapes
(self / single / group burst / other units) and a capped sample of recast
intervals (one caster's successive casts of the aura, onto any target).
Only auras whose source is a player character count toward it (the owner's
formula: per spec, and cast by a player, not an NPC); everything else lands
in a separate non-player tally.

Privacy: GUIDs and unit names pass through these functions in memory only.
aggregate_to_json() writes casters as salted hashes, never as GUIDs, and
never writes a unit name.
"""

import datetime
import hashlib
import re
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, NamedTuple, Optional, Set, Tuple

# Two spaces separate the timestamp ("9/23/2026 23:10:51.1345") from the
# comma-separated payload ("SPELL_AURA_APPLIED,...").
EVENT_SEP = b"  "

# COMBATLOG_OBJECT_* unit flag bits (Blizzard's combat log flag enum).
# TYPE_PLAYER marks a player character; CONTROL_PLAYER marks a unit a player
# controls. A pet or guardian has CONTROL_PLAYER but TYPE_PET/TYPE_GUARDIAN;
# a mind-controlled player has TYPE_PLAYER but CONTROL_NPC.
COMBATLOG_OBJECT_TYPE_PLAYER = 0x400
COMBATLOG_OBJECT_CONTROL_PLAYER = 0x100

# SPELL_AURA_APPLIED fields after the event name: source GUID, name, flags,
# raid flags, dest GUID, name, flags, raid flags, spell id, spell name, school,
# aura type, and an optional amount (absorbs).
AURA_FIELDS = 12
AURA_TYPES = ("BUFF", "DEBUFF")

# COMBATANT_INFO fields after the event name: GUID, faction, 22 stats
# (strength ... armor), then the current specialization id. Verified against
# the owner's COMBAT_LOG_VERSION 22 logs (build 12.1.0).
COMBATANT_SPEC_INDEX = 24


def split_fields(payload):
    # type: (str) -> List[str]
    """Split a payload on commas that are outside double quotes.

    Quotes stay on the field (use unquote() for the bare name). An
    unterminated quote means the line was cut mid-field, so the result is [].
    """
    out = []
    cur = []
    quoted = False
    for ch in payload:
        if ch == '"':
            quoted = not quoted
            cur.append(ch)
        elif ch == "," and not quoted:
            out.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    if quoted:
        return []
    out.append("".join(cur))
    return out


def unquote(field):
    # type: (str) -> str
    """Strip one pair of surrounding double quotes, if present."""
    if len(field) >= 2 and field[0] == '"' and field[-1] == '"':
        return field[1:-1]
    return field


def _parse_date(stamp):
    # type: (bytes) -> Optional[str]
    """'9/23/2026 23:10:51.1345' -> '2026-09-23', or None."""
    try:
        date_part = stamp.split(b" ", 1)[0].decode("ascii")
        month, day, year = date_part.split("/")
        m, d, y = int(month), int(day), int(year)
    except (UnicodeDecodeError, ValueError):
        return None
    if not (1 <= m <= 12 and 1 <= d <= 31 and 1000 <= y <= 9999):
        return None
    return "%04d-%02d-%02d" % (y, m, d)


def parse_event(line):
    # type: (bytes) -> Optional[Tuple[str, str, List[str]]]
    """Parse one raw log line into (date 'YYYY-MM-DD', event, fields after the event).

    Returns None for anything malformed: no separator, a bad date, bytes that
    are not UTF-8, an unterminated quote (a truncated last line), or a payload
    with no fields after the event name.
    """
    line = line.rstrip(b"\r\n")
    if line.startswith(b"\xef\xbb\xbf"):
        line = line[3:]
    i = line.find(EVENT_SEP)
    if i < 0:
        return None
    date = _parse_date(line[:i])
    if date is None:
        return None
    try:
        text = line[i + len(EVENT_SEP):].decode("utf-8")
    except UnicodeDecodeError:
        return None
    fields = split_fields(text)
    if len(fields) < 2 or not fields[0]:
        return None
    return (date, fields[0], fields[1:])


class AuraApplication(NamedTuple):
    source: str
    source_flags: str
    dest: str
    spell_id: int
    spell_name: str
    aura_type: str


def parse_aura_applied(fields):
    # type: (List[str]) -> Optional[AuraApplication]
    """Validate a SPELL_AURA_APPLIED payload (fields after the event).

    Returns None when it has fewer than 12 fields, a non-numeric or zero spell
    id, or an aura type other than BUFF/DEBUFF (e.g. a line cut outside quotes).
    """
    if len(fields) < AURA_FIELDS:
        return None
    raw_id = fields[8]
    if not (raw_id.isascii() and raw_id.isdigit()):
        return None
    spell_id = int(raw_id)
    aura_type = fields[11]
    if spell_id <= 0 or aura_type not in AURA_TYPES:
        return None
    return AuraApplication(fields[0], fields[2], fields[4], spell_id, unquote(fields[9]), aura_type)


def _flag_bits(flags):
    # type: (str) -> Optional[int]
    try:
        return int(flags, 16)
    except (TypeError, ValueError):
        return None


def is_player_source(guid, flags):
    # type: (str, str) -> bool
    """True when the unit is a player character that a player controls."""
    if not guid.startswith("Player-"):
        return False
    bits = _flag_bits(flags)
    if bits is None:
        return False
    return bool(bits & COMBATLOG_OBJECT_TYPE_PLAYER) and bool(bits & COMBATLOG_OBJECT_CONTROL_PLAYER)


class SpecTracker:
    """Each player's specialization within one log file, learned forward only.

    A GUID has no spec until a COMBATANT_INFO line for it is observed; a later
    COMBATANT_INFO (a respec between encounters) replaces the earlier one.
    With a spec_to_class map (spec id -> class token, from ChrSpecialization)
    the tracker also answers class_of(guid).
    """

    def __init__(self, spec_to_class=None):
        # type: (Optional[Dict[int, str]]) -> None
        self._spec = {}  # type: Dict[str, int]
        self._spec_to_class = dict(spec_to_class or {})

    def observe_combatant_info(self, fields):
        # type: (List[str]) -> Optional[int]
        """Record the spec from a COMBATANT_INFO payload; return it, or None if unusable."""
        if len(fields) <= COMBATANT_SPEC_INDEX:
            return None
        guid = fields[0]
        raw = fields[COMBATANT_SPEC_INDEX]
        if not guid.startswith("Player-") or not (raw.isascii() and raw.isdigit()):
            return None
        spec = int(raw)
        if spec <= 0:
            return None
        self._spec[guid] = spec
        return spec

    def spec_of(self, guid):
        # type: (str) -> Optional[int]
        return self._spec.get(guid)

    def class_of(self, guid):
        # type: (str) -> Optional[str]
        spec = self._spec.get(guid)
        if spec is None:
            return None
        return self._spec_to_class.get(spec)


# --- Per-file aggregates (SID-2) ----------------------------------------------

AuraKey = tuple  # (aura_type "BUFF"|"DEBUFF", spell_id int)
SpecKey = tuple  # (class_token e.g. "SHAMAN", spec_id int | None); None = "unknown"

# Group burst: the same caster applies the same aura to at least this many
# distinct units within BURST_WINDOW seconds of the window's first application.
BURST_TARGETS = 5
BURST_WINDOW = 1.0

# Recast intervals kept per aura (per spec), to bound memory.
RECAST_SAMPLE_CAP = 200

# One cast, for the recast interval: the same caster's applications of the same aura less than
# this many seconds after the previous one (a burst, a self-copy). The shortest global cooldown is
# 0.75 s, so a real recast is always further apart.
RECAST_SAME_CAST = 0.5

# An external self-copy (SID-11): the same caster's aura on itself AND on exactly one other player
# within this many seconds is ONE application onto that player (Power Infusion, Blessing of
# Sacrifice and Guardian Spirit log a copy on the caster).
SELF_COPY_WINDOW = 0.1

# The only two events a scan decodes; every other line is counted and passed over.
_AURA_PREFIX = b"SPELL_AURA_APPLIED,"
_COMBATANT_PREFIX = b"COMBATANT_INFO,"

_FILE_STAMP = re.compile(r"^WoWCombatLog-(\d\d)(\d\d)(\d\d)_\d{6}\.txt$")
_CLOCK = re.compile(rb" (\d{1,2}):(\d{2}):(\d{2}(?:\.\d+)?)")


@dataclass
class AuraStats:
    names: Counter = field(default_factory=Counter)  # spelling -> count
    applications: int = 0
    players: Set[str] = field(default_factory=set)   # GUIDs in memory; hashes once serialised
    self_: int = 0                                    # dest == source
    single: int = 0                                   # one other player, not part of a burst
    group: int = 0                                    # bursts, counted once per burst
    other: int = 0                                    # onto a unit that is no player (pet, NPC)
    recast_samples: List[float] = field(default_factory=list)  # seconds between one caster's casts
    first_seen: str = ""
    last_seen: str = ""


@dataclass
class FileAggregate:
    per_spec: Dict[tuple, Dict[tuple, AuraStats]] = field(default_factory=dict)
    non_player: Dict[tuple, dict] = field(default_factory=dict)  # AuraKey -> {"names", "applications"}
    unattributed: int = 0  # player applications whose class could not be established
    lines: int = 0
    skipped: int = 0       # malformed or truncated lines
    first_date: str = ""
    last_date: str = ""


def file_date(path):
    # type: (Path) -> Optional[str]
    """'WoWCombatLog-MMDDYY_HHMMSS.txt' -> '20YY-MM-DD', or None."""
    m = _FILE_STAMP.match(Path(path).name)
    if not m:
        return None
    month, day, year = int(m.group(1)), int(m.group(2)), 2000 + int(m.group(3))
    try:
        return datetime.date(year, month, day).isoformat()
    except ValueError:
        return None


def _clock_seconds(line, date):
    # type: (bytes, str) -> Optional[float]
    """Seconds on a continuous scale (date ordinal * 86400 + time of day), or None."""
    m = _CLOCK.search(line, 0, line.find(EVENT_SEP))
    if not m:
        return None
    secs = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))
    return datetime.date.fromisoformat(date).toordinal() * 86400 + secs


def _extend_dates(first, last, date):
    # type: (str, str, str) -> Tuple[str, str]
    return (date if not first or date < first else first,
            date if not last or date > last else last)


class _Burst:
    """One open burst window for a (caster, aura)."""

    __slots__ = ("start", "stats", "dests", "self_", "single", "converted", "collapsed")

    def __init__(self, start, stats):
        self.start = start
        self.stats = stats
        self.dests = set()  # type: Set[str]
        self.self_ = 0
        self.single = 0
        self.converted = False
        self.collapsed = 0  # self-copies taken out of `applications` while this window is open


class _Moment:
    """The applications of one (caster, aura) within SELF_COPY_WINDOW: a possible self-copy."""

    __slots__ = ("start", "stats", "self_burst", "others", "collapsed")

    def __init__(self, start, stats):
        self.start = start
        self.stats = stats
        self.self_burst = None  # the burst window the self-application was counted in
        self.others = set()  # type: Set[str]
        self.collapsed = False


class _FileScan:
    """The mutable state of one scan_file() pass."""

    def __init__(self, spec_to_class, stamp_date):
        self.agg = FileAggregate()
        self.tracker = SpecTracker(spec_to_class)
        self.stamp_date = stamp_date
        self.bursts = {}      # (source, aura key) -> _Burst
        self.moments = {}     # (source, aura key) -> _Moment
        self.last_cast = {}   # (source, aura key) -> [start of the last cast, its last application]

    def line(self, raw):
        agg = self.agg
        agg.lines += 1
        if not raw.endswith(b"\n"):
            agg.skipped += 1  # the client was killed mid-write
            return
        i = raw.find(EVENT_SEP)
        if i < 0:
            agg.skipped += 1
            return
        payload = raw[i + len(EVENT_SEP):]
        if payload.startswith(_AURA_PREFIX):
            self.aura(raw)
        elif payload.startswith(_COMBATANT_PREFIX):
            ev = parse_event(raw)
            if ev is None:
                agg.skipped += 1
            else:
                self.tracker.observe_combatant_info(ev[2])

    def aura(self, raw):
        agg = self.agg
        ev = parse_event(raw)
        app = parse_aura_applied(ev[2]) if ev is not None else None
        when = _clock_seconds(raw, ev[0]) if app is not None else None
        if when is None:
            agg.skipped += 1
            return
        date = self.stamp_date or ev[0]
        agg.first_date, agg.last_date = _extend_dates(agg.first_date, agg.last_date, date)
        key = (app.aura_type, app.spell_id)
        if not is_player_source(app.source, app.source_flags):
            tally = agg.non_player.setdefault(key, {"names": Counter(), "applications": 0})
            tally["names"][app.spell_name] += 1
            tally["applications"] += 1
            return
        cls = self.tracker.class_of(app.source)
        if cls is None:
            agg.unattributed += 1
            return
        spec_key = (cls, self.tracker.spec_of(app.source))
        st = agg.per_spec.setdefault(spec_key, {}).get(key)
        if st is None:
            st = agg.per_spec[spec_key][key] = AuraStats()
        st.names[app.spell_name] += 1
        st.applications += 1
        st.players.add(app.source)
        st.first_seen, st.last_seen = _extend_dates(st.first_seen, st.last_seen, date)
        self.shape(app, key, st, when)
        self.recast(app.source, key, st, when)

    def shape(self, app, key, st, when):
        is_self = app.dest == app.source
        if not is_self and not app.dest.startswith("Player-"):
            # The spec's `single` is one other PLAYER and a burst is 5+ distinct PLAYERS: a pet,
            # guardian, totem or NPC target (Beast Cleave, Infernal Command) is neither.
            st.other += 1
            return
        burst_key = (app.source, key)
        burst = self.bursts.get(burst_key)
        if burst is None or not (0 <= when - burst.start <= BURST_WINDOW) or burst.stats is not st:
            burst = self.bursts[burst_key] = _Burst(when, st)
        if burst.converted:
            return  # a companion of a burst already counted as one group
        burst.dests.add(app.dest)
        if is_self:
            st.self_ += 1
            burst.self_ += 1
        else:
            st.single += 1
            burst.single += 1
        if len(burst.dests) >= BURST_TARGETS:
            st.self_ -= burst.self_
            st.single -= burst.single
            st.group += 1
            st.applications += burst.collapsed  # inside a burst a self-copy is a group application
            burst.collapsed = 0
            burst.converted = True
            return
        self.self_copy(app, burst_key, st, when, is_self, burst)

    def self_copy(self, app, moment_key, st, when, is_self, burst):
        """Fold an external's copy on its caster into the one application onto the other player.

        The moment opens at its first application; while it holds the caster plus exactly one other
        player, the self-application is taken out of `applications` and `self`. A second other
        player in the same moment puts it back: that is a small group, not an external.
        """
        moment = self.moments.get(moment_key)
        if moment is None or moment.stats is not st or not (0 <= when - moment.start <= SELF_COPY_WINDOW):
            moment = self.moments[moment_key] = _Moment(when, st)
        if is_self:
            if moment.self_burst is not None:
                return  # a second self-application in one moment: leave it counted
            moment.self_burst = burst
        else:
            moment.others.add(app.dest)
        home = moment.self_burst
        external = home is not None and len(moment.others) == 1
        if external and not moment.collapsed and not home.converted:
            st.applications -= 1
            st.self_ -= 1
            home.self_ -= 1
            home.collapsed += 1
            moment.collapsed = True
        elif moment.collapsed and not external:
            moment.collapsed = False
            if home.collapsed > 0:  # else a burst has already counted it back as a group application
                st.applications += 1
                st.self_ += 1
                home.self_ += 1
                home.collapsed -= 1

    def recast(self, source, key, st, when):
        """Seconds between one caster's successive casts of the aura, onto any target (SID-11).

        Applications less than RECAST_SAME_CAST after the previous one belong to its cast.
        """
        recast_key = (source, key)
        last = self.last_cast.get(recast_key)
        if last is not None and 0 <= when - last[1] < RECAST_SAME_CAST:
            last[1] = when
            return
        self.last_cast[recast_key] = [when, when]
        if last is not None and when > last[0] and len(st.recast_samples) < RECAST_SAMPLE_CAP:
            st.recast_samples.append(round(when - last[0], 4))


def scan_file(path, spec_to_class):
    # type: (Path, Dict[int, str]) -> FileAggregate
    """Stream one combat log and fold its player-applied auras into a FileAggregate.

    Attribution is forward only: an application counts under (class, spec)
    when a COMBATANT_INFO earlier in this file gave its caster a spec that
    spec_to_class maps to a class; otherwise it is counted in `unattributed`.
    Non-player sources (pets, totems, guardians, NPCs, controlled players)
    go to `non_player`. Only SPELL_AURA_APPLIED and COMBATANT_INFO lines are
    decoded; a malformed one, a line with no timestamp separator, or an
    unterminated final line is counted in `skipped`.
    """
    scan = _FileScan(spec_to_class, file_date(Path(path)))
    with open(path, "rb") as fh:
        for raw in fh:
            scan.line(raw)
    return scan.agg


def hash_player(guid, salt=b""):
    # type: (str, bytes) -> str
    """A 16-hex-digit salted hash of a player GUID; a value that is not a GUID passes through."""
    if not guid.startswith("Player-"):
        return guid
    return hashlib.sha256(salt + guid.encode("utf-8")).hexdigest()[:16]


def _names_json(names):
    return {n: names[n] for n in sorted(names)}


def aggregate_to_json(agg, salt=b""):
    # type: (FileAggregate, bytes) -> dict
    """A JSON-ready dict of the aggregate. Casters become salted hashes; no GUID or unit name is written."""
    per_spec = []
    for (cls, spec) in sorted(agg.per_spec, key=lambda k: (k[0], -1 if k[1] is None else k[1])):
        auras = []
        for (aura_type, spell_id), st in sorted(agg.per_spec[(cls, spec)].items()):
            auras.append({
                "auraType": aura_type, "spellId": spell_id, "names": _names_json(st.names),
                "applications": st.applications,
                "players": sorted({hash_player(p, salt) for p in st.players}),
                "self": st.self_, "single": st.single, "group": st.group, "other": st.other,
                "recastSamples": list(st.recast_samples),
                "firstSeen": st.first_seen, "lastSeen": st.last_seen,
            })
        per_spec.append({"class": cls, "spec": spec, "auras": auras})
    non_player = [{"auraType": t, "spellId": i, "names": _names_json(v["names"]),
                   "applications": v["applications"]}
                  for (t, i), v in sorted(agg.non_player.items())]
    return {
        "lines": agg.lines, "skipped": agg.skipped, "unattributed": agg.unattributed,
        "firstDate": agg.first_date, "lastDate": agg.last_date,
        "perSpec": per_spec, "nonPlayer": non_player,
    }


def aggregate_from_json(d):
    # type: (dict) -> FileAggregate
    """The inverse of aggregate_to_json; `players` holds the serialised hashes."""
    agg = FileAggregate(lines=d["lines"], skipped=d["skipped"], unattributed=d["unattributed"],
                        first_date=d["firstDate"], last_date=d["lastDate"])
    for row in d["perSpec"]:
        auras = agg.per_spec.setdefault((row["class"], row["spec"]), {})
        for a in row["auras"]:
            auras[(a["auraType"], a["spellId"])] = AuraStats(
                names=Counter(a["names"]), applications=a["applications"], players=set(a["players"]),
                self_=a["self"], single=a["single"], group=a["group"], other=a.get("other", 0),
                recast_samples=list(a["recastSamples"]),
                first_seen=a["firstSeen"], last_seen=a["lastSeen"])
    for a in d["nonPlayer"]:
        agg.non_player[(a["auraType"], a["spellId"])] = {
            "names": Counter(a["names"]), "applications": a["applications"]}
    return agg
