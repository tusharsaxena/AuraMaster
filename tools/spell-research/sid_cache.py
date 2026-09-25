"""Per-log cache, folder scan and merge for the combat-log spell research.

A full scan of the owner's logs is ~30 GB and ~20 minutes, so each log's
FileAggregate is cached as JSON under <cache>/logs/<name>-<size>-<mtime>.json
and a later scan reads only logs whose key is missing: a new log, or one the
client was still writing when it was last cached (its size or mtime moved).

The cache lives OUTSIDE the repo (default ~/.cache/auramaster-spell-research/)
because it holds casters as salted hashes, so distinct-player counts stay
exact across files without a GUID ever being written. The salt is 32 random
bytes created once in <cache>/salt. Nothing in the repo carries a hash:
evidence_to_json() writes counts only.

Python 3.8+ standard library only.
"""

import hashlib
import json
import os
import re
import statistics
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Dict, Iterable, List, Optional, Tuple

import sid_scan
from sid_scan import AuraStats, FileAggregate

DEFAULT_CACHE_DIR = Path.home() / ".cache" / "auramaster-spell-research"

# Bump when the cached aggregate's meaning changes, so old entries are re-read.
CACHE_VERSION = 5
# 2: `other` (applications onto a unit that is no player) split out of `single` (SID-10).
# 3: an external's self-copy is one `single` application; recast is per caster onto any target (SID-11).
# 4: a SPELL_AURA_REFRESH by the caster is a recast too (SID-11).
# 5: ...but only a refresh onto another unit; one on the caster is a proc re-trigger (SID-11 review).
# 2: adds classPlayers and specPlayers (exact distinct-player unions; see evidence_to_json).
EVIDENCE_VERSION = 4
# 3: rows carry `other`; `single` and `group` count player targets only.
# 4: the SID-11 scan: self-copies folded into `single`, recastMedian per caster onto any target.

SALT_BYTES = 32

_LOG_NAME = re.compile(r"^WoWCombatLog-.*\.txt$")


# --- salt and keys -------------------------------------------------------------

def load_salt(cache_dir):
    # type: (Path) -> bytes
    """The per-user salt in <cache_dir>/salt, created on first use and reused after."""
    path = Path(cache_dir) / "salt"
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        part = path.with_name("salt.part")
        fd = os.open(str(part), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "wb") as fh:
            fh.write(os.urandom(SALT_BYTES))
        os.replace(str(part), str(path))
    salt = path.read_bytes()
    if len(salt) != SALT_BYTES:
        raise RuntimeError("%s is not a %d-byte salt; delete it and the logs/ cache beside it"
                           % (path, SALT_BYTES))
    return salt


def cache_key(path):
    # type: (Path) -> str
    """'<name>-<size>-<int(mtime)>' for a log file."""
    path = Path(path)
    st = path.stat()
    return "%s-%d-%d" % (path.name, st.st_size, int(st.st_mtime))


def _context(salt, spec_to_class):
    # type: (bytes, Dict[int, str]) -> str
    """A fingerprint of what a cached aggregate depends on besides the log itself.

    The salt (hashes from two salts must never be merged, or one player would
    count twice) and the spec -> class map (it decides attribution).
    """
    spec_map = json.dumps(sorted((int(k), v) for k, v in spec_to_class.items()))
    return hashlib.sha256(salt + b"\0" + spec_map.encode("utf-8")).hexdigest()[:16]


# --- cache files ---------------------------------------------------------------

def _write_atomic(path, text):
    # type: (Path, str) -> None
    part = path.with_name(path.name + ".part")
    part.write_text(text, encoding="utf-8")
    os.replace(str(part), str(path))


def _read_cached(path, context):
    # type: (Path, str) -> Optional[FileAggregate]
    """The cached aggregate, or None when missing, unreadable or made under another context."""
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
        if doc.get("version") != CACHE_VERSION or doc.get("context") != context:
            return None
        return sid_scan.aggregate_from_json(doc["aggregate"])
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        return None


def _prune(entries_dir, log_name, keep):
    # type: (Path, str, str) -> None
    """Remove cache entries for this log under any other key (it grew or was touched)."""
    stale = re.compile(re.escape(log_name) + r"-\d+-\d+\.json$")
    for p in entries_dir.iterdir():
        if p.name != keep and stale.match(p.name):
            try:
                p.unlink()
            except OSError:
                pass


def list_logs(logs_dir):
    # type: (Path) -> List[Path]
    """Every WoWCombatLog-*.txt file directly in logs_dir, sorted by name."""
    return sorted(p for p in Path(logs_dir).iterdir() if _LOG_NAME.match(p.name) and p.is_file())


# --- scan and merge ------------------------------------------------------------

def scan_dir(logs_dir, cache_dir, spec_to_class, progress=print):
    # type: (Path, Path, Dict[int, str], Callable[[str], None]) -> Tuple[FileAggregate, dict]
    """Scan every log in logs_dir, reading only those not already cached, and merge them.

    Returns the merged aggregate (players as salted hashes) and a summary:
    files, bytes, read, cached, lines, skipped, unattributed, first_date, last_date.
    """
    cache_dir = Path(cache_dir)
    logs = list_logs(logs_dir)
    salt = load_salt(cache_dir)
    context = _context(salt, spec_to_class)
    entries = cache_dir / "logs"
    entries.mkdir(parents=True, exist_ok=True)
    aggs = []
    read = cached = total_bytes = 0
    for i, path in enumerate(logs, 1):
        key = cache_key(path)
        size = path.stat().st_size
        total_bytes += size
        entry = entries / (key + ".json")
        agg = _read_cached(entry, context)
        if agg is not None:
            cached += 1
            progress("[%d/%d] cached %s" % (i, len(logs), path.name))
        else:
            read += 1
            progress("[%d/%d] reading %s (%.1f MB)" % (i, len(logs), path.name, size / 1e6))
            doc = sid_scan.aggregate_to_json(sid_scan.scan_file(path, spec_to_class), salt=salt)
            _write_atomic(entry, json.dumps(
                {"version": CACHE_VERSION, "context": context, "aggregate": doc},
                separators=(",", ":"), sort_keys=True))
            _prune(entries, path.name, entry.name)
            agg = sid_scan.aggregate_from_json(doc)  # hashes, like a cached one
        aggs.append(agg)
    merged = merge(aggs)
    summary = {
        "files": len(logs), "bytes": total_bytes, "read": read, "cached": cached,
        "lines": merged.lines, "skipped": merged.skipped, "unattributed": merged.unattributed,
        "first_date": merged.first_date, "last_date": merged.last_date,
    }
    return merged, summary


def _min_date(a, b):
    # type: (str, str) -> str
    return b if not a or (b and b < a) else a


def _max_date(a, b):
    # type: (str, str) -> str
    return b if not a or (b and b > a) else a


def _merge_stats(into, st):
    # type: (AuraStats, AuraStats) -> None
    into.names.update(st.names)
    into.applications += st.applications
    into.players |= st.players
    into.self_ += st.self_
    into.single += st.single
    into.group += st.group
    into.other += st.other
    room = sid_scan.RECAST_SAMPLE_CAP - len(into.recast_samples)
    if room > 0:
        into.recast_samples.extend(st.recast_samples[:room])
    into.first_seen = _min_date(into.first_seen, st.first_seen)
    into.last_seen = _max_date(into.last_seen, st.last_seen)


def merge(aggs):
    # type: (Iterable[FileAggregate]) -> FileAggregate
    """Combine per-file aggregates into one, without mutating them.

    Counts and spellings sum, player sets union (so a player seen in two logs
    counts once), recast samples concatenate up to the per-aura cap, and the
    date range widens.
    """
    out = FileAggregate()
    for agg in aggs:
        out.lines += agg.lines
        out.skipped += agg.skipped
        out.unattributed += agg.unattributed
        out.first_date = _min_date(out.first_date, agg.first_date)
        out.last_date = _max_date(out.last_date, agg.last_date)
        for spec_key, auras in agg.per_spec.items():
            target = out.per_spec.setdefault(spec_key, {})
            for aura_key, st in auras.items():
                into = target.get(aura_key)
                if into is None:
                    into = target[aura_key] = AuraStats()
                _merge_stats(into, st)
        for aura_key, tally in agg.non_player.items():
            into = out.non_player.setdefault(aura_key, {"names": Counter(), "applications": 0})
            into["names"].update(tally["names"])
            into["applications"] += tally["applications"]
    return out


# --- evidence.json (the repo's copy: counts only) ------------------------------

def _top_name(names):
    # type: (Counter) -> str
    """The most common spelling; ties go to the alphabetically first."""
    if not names:
        return ""
    return sorted(names.items(), key=lambda kv: (-kv[1], kv[0]))[0][0]


def recast_median(samples):
    # type: (List[float]) -> Optional[float]
    return round(statistics.median(samples), 2) if samples else None


def _spec_order(key):
    return (key[0], -1 if key[1] is None else key[1])


@dataclass
class EvidenceAggregate(FileAggregate):
    """A FileAggregate read back from evidence.json, with the exact unions the rows cannot give.

    class_players: (class, auraType, spellId) -> distinct casters across every spec of the class.
    spec_players:  (class, spec) -> distinct casters applying any aura in that spec.
    Both are empty for an evidence.json written before EVIDENCE_VERSION 2.
    """
    class_players: Dict[tuple, int] = field(default_factory=dict)
    spec_players: Dict[tuple, int] = field(default_factory=dict)


def player_unions(agg):
    # type: (FileAggregate) -> Tuple[Dict[tuple, int], Dict[tuple, int]]
    """({(class, auraType, spellId): n}, {(class, spec): n}): distinct casters, from the real sets."""
    by_aura, by_spec = {}, {}  # type: Dict[tuple, set], Dict[tuple, set]
    for (cls, spec), auras in agg.per_spec.items():
        seen = by_spec.setdefault((cls, spec), set())
        for (aura_type, spell_id), st in auras.items():
            by_aura.setdefault((cls, aura_type, spell_id), set()).update(st.players)
            seen.update(st.players)
    return ({k: len(v) for k, v in by_aura.items()}, {k: len(v) for k, v in by_spec.items()})


def evidence_to_json(agg, summary):
    # type: (FileAggregate, dict) -> dict
    """The evidence written into the repo: one row per (class, spec, auraType, spellId).

    Counts only: `players` is the number of distinct casters. No hash, GUID or
    unit name appears. Recast is reduced to its median and sample count.

    Per-row counts cannot be unioned once the casters are gone, so two tables carry the unions
    the propose stage needs, computed here from the real caster sets: `classPlayers` (distinct
    casters of an aura across every spec of the class: the evidence bar) and `specPlayers`
    (distinct casters of a spec across every aura: which specs the logs cover).
    """
    class_players, spec_players = player_unions(agg)
    rows = []
    for spec_key in sorted(agg.per_spec, key=_spec_order):
        cls, spec = spec_key
        for (aura_type, spell_id), st in sorted(agg.per_spec[spec_key].items()):
            rows.append({
                "class": cls, "spec": spec, "auraType": aura_type, "spellId": spell_id,
                "name": _top_name(st.names), "names": {n: st.names[n] for n in sorted(st.names)},
                "applications": st.applications, "players": len(st.players),
                "self": st.self_, "single": st.single, "group": st.group, "other": st.other,
                "recastMedian": recast_median(st.recast_samples),
                "recastIntervals": len(st.recast_samples),
                "firstSeen": st.first_seen, "lastSeen": st.last_seen,
            })
    non_player = [{"auraType": t, "spellId": i, "name": _top_name(v["names"]),
                   "names": {n: v["names"][n] for n in sorted(v["names"])},
                   "applications": v["applications"]}
                  for (t, i), v in sorted(agg.non_player.items())]
    return {
        "version": EVIDENCE_VERSION, "summary": dict(summary),
        "lines": agg.lines, "skipped": agg.skipped, "unattributed": agg.unattributed,
        "firstDate": agg.first_date, "lastDate": agg.last_date,
        "auras": rows, "nonPlayer": non_player,
        "classPlayers": [{"class": c, "auraType": t, "spellId": i, "players": n}
                         for (c, t, i), n in sorted(class_players.items())],
        "specPlayers": [{"class": c, "spec": sp, "players": spec_players[(c, sp)]}
                        for (c, sp) in sorted(spec_players, key=_spec_order)],
    }


def evidence_from_json(d):
    # type: (dict) -> EvidenceAggregate
    """Rebuild an aggregate from evidence.json for the propose stage.

    `players` becomes a set of opaque placeholders of the recorded size, so
    len() gives the row's distinct-player count; a union of two rows' sets is
    NOT a distinct count (every row shares '#0'..), so the exact unions come
    from classPlayers / specPlayers into class_players / spec_players.
    `recast_samples` holds the recorded median alone, so its median is exact (the propose stage
    weights each spec's median by its applications across specs).
    """
    agg = EvidenceAggregate(lines=d["lines"], skipped=d["skipped"], unattributed=d["unattributed"],
                        first_date=d["firstDate"], last_date=d["lastDate"])
    for r in d["auras"]:
        median = r.get("recastMedian")
        agg.per_spec.setdefault((r["class"], r["spec"]), {})[(r["auraType"], r["spellId"])] = AuraStats(
            names=Counter(r["names"]), applications=r["applications"],
            players={"#%d" % i for i in range(r["players"])},
            self_=r["self"], single=r["single"], group=r["group"], other=r.get("other", 0),
            recast_samples=[] if median is None else [median],
            first_seen=r["firstSeen"], last_seen=r["lastSeen"])
    for r in d["nonPlayer"]:
        agg.non_player[(r["auraType"], r["spellId"])] = {
            "names": Counter(r["names"]), "applications": r["applications"]}
    for r in d.get("classPlayers", ()):
        agg.class_players[(r["class"], r["auraType"], r["spellId"])] = r["players"]
    for r in d.get("specPlayers", ()):
        agg.spec_players[(r["class"], r["spec"])] = r["players"]
    return agg
