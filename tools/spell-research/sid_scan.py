"""Stage 1 of the combat-log spell research: read WoW combat log lines.

This module turns raw combat log lines into fields, decides whether an aura's
source is a player character (never a pet, totem, guardian or NPC), and
tracks each player's specialization from COMBATANT_INFO lines.

Python 3.8+ standard library only. Lines are handled as bytes so a scan can
stream a multi-gigabyte log without decoding it all at once; a line that
cannot be decoded or split is reported as None and counted by the caller as
skipped, never fatal.

Privacy: GUIDs and unit names pass through these functions in memory only.
Nothing here writes them anywhere.
"""

from typing import Dict, List, NamedTuple, Optional, Tuple

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
