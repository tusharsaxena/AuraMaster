# Spell ids from combat logs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `defaults/Categories.lua`'s spell lists correct and authoritative by mining the owner's combat logs for the aura ids players of each spec actually apply, proposing corrections and additions, and applying only owner-ruled changes.

**Architecture:** A standard-library Python tool in `tools/spell-research/`, split by stage: scan (logs → per-spec evidence, cached per log), DB2 signals (reuses `research.py`'s cached tables and readers), propose (corrections, additions with a rule-based category suggestion), artifacts (the browsable per-spec dictionary and the review set), and decide/apply (a durable decisions file, the only writer of `Categories.lua`). A Claude slash command drives the review.

**Tech Stack:** Python 3.8+ standard library only (`argparse`, `csv`, `json`, `statistics`, `unittest`, `pathlib`); Lua 5.1 addon gates via `ka0s-bounded`.

**Spec:** `docs/superpowers/specs/2026-09-24-spell-ids-from-combat-logs-design.md`

**Execution state:** git is the state. Each task lands as one or more commits whose subject starts `SID-<n>: ` on `feat/spell-ids-from-logs` in the worktree `/mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster-spellids`. A task is done when such a commit exists and carries a `refs/notes/ka0s-review` note from its independent review. Resume by skipping tasks whose commits exist.

## Global Constraints

- Python **3.8+**, **standard library only**; no pip packages (`DEPENDENCIES.md` line 101 forbids them).
- `research.py`'s existing behaviour and outputs must not change; new code imports it as a module.
- Every file committed in this repo is **CRLF** (`.gitattributes` pins `* text=auto eol=crlf`); generated Markdown/CSV/Lua is written with `\r\n` (use `research.write_repo_text` or `newline="\r\n"`).
- **No player name, realm or GUID** in any output or committed file. Only class, spec and counts.
- Proposal evidence bar defaults: **≥ 20 applications from ≥ 3 distinct players**.
- Group burst: **≥ 5 distinct players within 1.0 s** from the same caster and aura.
- Only `logs.py apply` writes `defaults/Categories.lua`, and only for entries ruled in `tools/spell-research/decisions.json`.
- Addon gates after any `Categories.lua` change: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .` = 0/0 and `… ka0s-bounded lua5.1 tests/run.lua` = 0 failed.
- Python tests run with `python3 -m unittest discover -s tools/spell-research -p 'test_*.py'`.
- Default logs folder: `/mnt/g/Games/Blizzard/World of Warcraft/_retail_/Logs/RaiderIOLogsArchive`.
- Per-log cache: `~/.cache/auramaster-spell-research/logs/` (outside the repo).
- DB2 cache: `--db2-cache` flag, default `tools/spell-research/.cache` (the path `research.py` uses); the worktree has none, so real runs pass `--db2-cache /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tools/spell-research/.cache` or let `research.fetch_table` download.

## Review Focus

1. **A log line with a comma inside a quoted name** (`"Smith, the Bold"` as a spell or unit name) — the fields after it must still parse correctly; pinned in Task 1.
2. **A truncated or garbled final line** (client killed mid-write) — skipped and counted, the scan continues; pinned in Task 1.
3. **A log whose players never get a `COMBATANT_INFO`** (open-world only) — applications land under spec `unknown` within the class only when the class is known from an earlier line; otherwise they are counted as unattributed and kept out of the per-spec dictionary; pinned in Task 2.
4. **A log that changes after it was cached** (still being written by the client) — re-read, never served stale; pinned in Task 3.
5. **A Categories.lua class line with a trailing comment, or a class that is not yet in the category** — apply edits exactly that line (or inserts a new class line in canonical class order) and leaves every other byte untouched; pinned in Task 8.

---

## File structure

| File | Responsibility |
|---|---|
| `tools/spell-research/sid_scan.py` | Stage 1: line parsing, player filter, spec tracking, per-file aggregates, target shapes, recast |
| `tools/spell-research/sid_cache.py` | Per-log cache keyed by name/size/mtime; merge of per-file aggregates |
| `tools/spell-research/sid_db2.py` | DB2 signals per aura (effect aura types), spec map, player pool, shipped categories and CastToAura candidates |
| `tools/spell-research/sid_propose.py` | Stage 2: corrections, additions, flags, category rules R1–R9, evidence bar, decisions suppression |
| `tools/spell-research/sid_artifacts.py` | The dictionary (`auras.json/.csv`, `AURAS.md`, `non-player.csv`) and the review set (`CURRENT_CATEGORIES.md`, `CORRECTIONS.md`, `PROPOSED_ADDITIONS.md`, `FLAGS.md`, `SOURCES.md`) |
| `tools/spell-research/sid_decide.py` | `decisions.json` read/write, `DECISIONS.md`, and `apply` (the Categories.lua line rewriter) |
| `tools/spell-research/logs.py` | CLI: `scan`, `propose`, `decide`, `apply` |
| `tools/spell-research/fixtures/combatlog-sample.txt` | Hand-written combat log fixture (fictional names) |
| `tools/spell-research/fixtures/db2/*.csv` | Tiny DB2 fixtures (SpellName, SpellEffect, ChrSpecialization, …) with the columns the code reads |
| `tools/spell-research/fixtures/Categories.lua`, `CastToAura.lua` | Small copies in the shipped shape, for apply and propose tests |
| `tools/spell-research/test_sid_*.py` | One test module per source module |
| `.claude/commands/aura-spells-review.md` | The review slash command |
| `.gitignore` | `.claude/` → `.claude/*` plus `!.claude/commands/` |
| `tools/spell-research/README.md`, `DEPENDENCIES.md`, `docs/module-map.md` (if it inventories tools) | Documentation of the new tool |

The spec names "a new module `logs.py`"; splitting it into `sid_*.py` modules behind a `logs.py` CLI keeps each file focused (research.py is already 1886 lines). The CLI surface is exactly the spec's.

### Shared data shapes (every task uses these names)

```python
# sid_scan.py
AuraKey = tuple  # (aura_type: str "BUFF"|"DEBUFF", spell_id: int)
SpecKey = tuple  # (class_token: str e.g. "SHAMAN", spec_id: int | None)  None = "unknown"

@dataclass
class AuraStats:
    names: Counter            # spelling -> count
    applications: int
    players: set              # source GUIDs, IN MEMORY ONLY; serialised as a count
    self_: int                # dest == source
    single: int               # one other player, not part of a burst
    group: int                # bursts (counted once per burst)
    recast_samples: list      # up to 200 seconds-between self-applications by one caster
    first_seen: str           # "YYYY-MM-DD" from the log file name
    last_seen: str

@dataclass
class FileAggregate:
    per_spec: dict            # SpecKey -> {AuraKey -> AuraStats}
    non_player: dict          # AuraKey -> {"names": Counter, "applications": int}
    unattributed: int         # player applications whose class could not be established
    lines: int
    skipped: int              # malformed/truncated lines
    first_date: str
    last_date: str
```

Serialised form: in the **per-log cache** (outside the repo) `players` is stored as a sorted list of salted hashes, `hashlib.sha256(salt + guid).hexdigest()[:16]`, where `salt` is 32 random bytes created once in `~/.cache/auramaster-spell-research/salt` — so `merge` can union them and distinct-player counts stay **exact across files** without a GUID ever being written. In `auras.json` and every bundle file, only `players` as a count appears. `names` serialises as a dict.

---

### Task 1 (SID-1): Log line parser, player filter, spec tracking

**Files:**
- Create: `tools/spell-research/sid_scan.py`, `tools/spell-research/fixtures/combatlog-sample.txt`, `tools/spell-research/test_sid_scan.py`

**Interfaces:**
- Produces: `split_fields(payload: str) -> list[str]`, `parse_event(line: bytes) -> tuple[str, str, list[str]] | None` (date `YYYY-MM-DD`, event name, fields after the event), `is_player_source(guid: str, flags: str) -> bool`, `class_of_guid` tracking via `SpecTracker` with `.observe_combatant_info(fields)`, `.spec_of(guid) -> int | None`.

- [ ] **Step 1: Write the fixture.** A CRLF file of ~40 lines using the real format:
  `9/23/2026 23:09:36.6175  COMBAT_LOG_VERSION,22,ADVANCED_LOG_ENABLED,1,BUILD_VERSION,12.1.0,PROJECT_ID,1`
  then `COMBATANT_INFO,Player-1-0000000A,0,264,…` (264 = Restoration Shaman), `COMBATANT_INFO,Player-1-0000000B,0,262,…` (Elemental), and `SPELL_AURA_APPLIED` lines in the shape
  `9/23/2026 23:10:51.1345  SPELL_AURA_APPLIED,Player-1-0000000A,"Tester-Realm-US",0x511,0x80000000,Player-1-0000000A,"Tester-Realm-US",0x511,0x80000000,114052,"Ascendance",0x8,BUFF`.
  Include: a pet source (`Pet-0-…`, flags `0x1111`), a creature source (`Creature-0-…`, flags `0xa48`), a name with a comma (`"Smith, the Bold-Realm-US"`), a spell name with a comma, one aura before any `COMBATANT_INFO` for its caster, a burst of the same aura from one caster onto 6 players within 0.5 s, and a final line cut mid-field with no line terminator.
- [ ] **Step 2: Write failing tests** in `test_sid_scan.py`:
  - `split_fields('a,"b,c",d')` == `['a', '"b,c"', 'd']`; quotes are kept on name fields, stripped by a helper `unquote`.
  - `parse_event` on a fixture aura line returns `("2026-09-23", "SPELL_AURA_APPLIED", [...])` with spell id at index 8 and aura type at index 11; returns `None` for the truncated last line.
  - `is_player_source("Player-1-0000000A", "0x511")` is True; `("Pet-0-1", "0x1111")` False; `("Creature-0-1", "0xa48")` False; `("Player-1-2", "0x1112")`… (use the real bit test: `int(flags, 16) & 0x400 and int(flags, 16) & 0x100`).
  - `SpecTracker`: after the fixture's `COMBATANT_INFO` for A, `spec_of(A) == 264`; for an unseen GUID, `None`.
- [ ] **Step 3: Run** `python3 -m unittest tools/spell-research/test_sid_scan.py -v` (from the repo root, with `-s`/discover or `PYTHONPATH=tools/spell-research`). Expected: import errors / failures.
- [ ] **Step 4: Implement.**

```python
EVENT_SEP = b"  "          # two spaces between timestamp and payload
def parse_event(line: bytes):
    line = line.rstrip(b"\r\n")
    i = line.find(EVENT_SEP)
    if i < 0:
        return None
    stamp, payload = line[:i], line[i + 2:]
    try:
        text = payload.decode("utf-8")
        month, day, year = stamp.split(b" ", 1)[0].decode().split("/")
    except (UnicodeDecodeError, ValueError):
        return None
    fields = split_fields(text)
    if len(fields) < 2:
        return None
    return ("%s-%02d-%02d" % (year, int(month), int(day)), fields[0], fields[1:])

def split_fields(payload: str) -> list:
    out, cur, quoted = [], [], False
    for ch in payload:
        if ch == '"':
            quoted = not quoted
            cur.append(ch)
        elif ch == "," and not quoted:
            out.append("".join(cur)); cur = []
        else:
            cur.append(ch)
    if quoted:              # unterminated quote = truncated line
        return []
    out.append("".join(cur))
    return out
```

  A `SPELL_AURA_APPLIED` payload has 12 fields after the event (source GUID, name, flags, raid flags, dest GUID, name, flags, raid flags, spell id, spell name, school, aura type); fewer = skipped. `COMBATANT_INFO` fields: `[guid, faction, specID, …]`.
- [ ] **Step 5: Run tests; expect PASS.**
- [ ] **Step 6: Commit** `git add tools/spell-research/sid_scan.py tools/spell-research/test_sid_scan.py tools/spell-research/fixtures/combatlog-sample.txt` — subject `SID-1: Parse combat log lines, filter player sources, track spec`.

### Task 2 (SID-2): Per-file aggregates, target shapes, recast, class attribution

**Files:**
- Modify: `tools/spell-research/sid_scan.py`, `tools/spell-research/test_sid_scan.py`, the fixture if a case is missing

**Interfaces:**
- Consumes: Task 1's functions; `spec_to_class: dict[int, str]` passed in (Task 4 builds it from DB2; tests pass a literal `{262: "SHAMAN", 264: "SHAMAN"}`).
- Produces: `scan_file(path: Path, spec_to_class: dict[int, str]) -> FileAggregate`, `aggregate_to_json(agg) -> dict`, `aggregate_from_json(d) -> FileAggregate`, and the dataclasses above.

- [ ] **Step 1: Failing tests:**
  - The fixture's Restoration `114052` Ascendance lands under `("SHAMAN", 264)`, Elemental's `1219480` under `("SHAMAN", 262)`.
  - The aura applied before its caster's `COMBATANT_INFO`: if that caster's class is known from a later `COMBATANT_INFO` in the same file? No — attribution is **forward only**: applications before the first `COMBATANT_INFO` for a GUID go to `unattributed` unless an earlier `COMBATANT_INFO` in the file gave the class. Assert `agg.unattributed == 1`. (Review Focus 3.)
  - The 6-target burst counts `group == 1` and contributes no `single`.
  - A self-application counts `self_`; a one-target application counts `single`.
  - Pet and creature sources land only in `non_player`.
  - Recast: two self-applications 90 s apart by one caster give `recast_samples == [90.0]`.
  - `skipped` counts the truncated line; `lines` counts all.
  - `aggregate_from_json(aggregate_to_json(agg))` round-trips counts, and the JSON contains no `Player-` substring and no quoted unit names.
- [ ] **Step 2: Run; expect FAIL.**
- [ ] **Step 3: Implement.** Burst detection: keep, per `(source guid, aura key)`, the timestamp of the open burst window and the set of dest GUIDs in it; when an application falls within 1.0 s of the window start, add the dest to the set; when the set first reaches 5, convert the window's already-counted `single`s into one `group` (subtract them from `single`, add 1 to `group`); later additions in the same window change nothing. Timestamps: parse `HH:MM:SS.ffff` to seconds since midnight; windows do not span midnight (accepted edge). The date comes from `parse_event`; `first_seen`/`last_seen` use the log file-name stamp `WoWCombatLog-MMDDYY_HHMMSS.txt` → `20YY-MM-DD` (fallback: the line date).
- [ ] **Step 4: Run; expect PASS.**
- [ ] **Step 5: Commit** — `SID-2: Aggregate per-spec aura evidence with target shapes and recast`.

### Task 3 (SID-3): Per-log cache, directory scan and merge, `logs.py scan`

**Files:**
- Create: `tools/spell-research/sid_cache.py`, `tools/spell-research/logs.py`, `tools/spell-research/test_sid_cache.py`

**Interfaces:**
- Consumes: `scan_file`, `aggregate_to_json`, `aggregate_from_json`.
- Produces: `cache_key(path: Path) -> str` (`"<name>-<size>-<int(mtime)>"`), `scan_dir(logs_dir: Path, cache_dir: Path, spec_to_class: dict, progress=print) -> tuple[FileAggregate, dict]` (merged aggregate, and a summary `{"files": n, "bytes": b, "read": r, "cached": c, "first_date": …, "last_date": …, "skipped": s, "unattributed": u}`), `merge(aggs: list[FileAggregate]) -> FileAggregate`. CLI `python3 tools/spell-research/logs.py scan [--logs DIR] [--cache DIR] [--db2-cache DIR] [--out evidence.json]`.

- [ ] **Step 1: Failing tests** (use `tempfile.TemporaryDirectory`, copy the fixture in twice under two `WoWCombatLog-…` names):
  - First `scan_dir` reads 2, caches 0; second reads 0, caches 2, same merged totals.
  - Touching one file (append a line, `os.utime` forward) makes the next scan read exactly 1 (Review Focus 4).
  - `merge` sums applications and shape counts, **unions the hashed player sets (the same fixture player in two logs counts once)**, extends recast samples capped at 200, and keeps min `first_seen` / max `last_seen`.
  - The cache JSON contains no `Player-` substring; the salt file is created once and reused.
  - Non-`WoWCombatLog-*.txt` files in the folder are ignored.
- [ ] **Step 2: Run; FAIL.**
- [ ] **Step 3: Implement** `sid_cache.py`; write cache JSON atomically (`.part` then `replace`). `logs.py scan` builds `spec_to_class` via `sid_db2.load_spec_map` (Task 4) — until Task 4 lands, accept `--spec-map-json` for tests only is NOT needed; order Task 4 before wiring the CLI's DB2 call, or have the CLI import lazily. Implement the CLI subcommand skeleton with `argparse` subparsers; `scan` prints the summary and writes `--out` (default `~/.cache/auramaster-spell-research/evidence.json`).
- [ ] **Step 4: Run; PASS.**
- [ ] **Step 5: Commit** — `SID-3: Cache per-log evidence and merge a folder scan`.

### Task 4 (SID-4): DB2 signals and shipped-category readers

**Files:**
- Create: `tools/spell-research/sid_db2.py`, `tools/spell-research/test_sid_db2.py`, `tools/spell-research/fixtures/db2/{ChrSpecialization,SpellName,SpellEffect}-test.csv`, `tools/spell-research/fixtures/Categories.lua`, `tools/spell-research/fixtures/CastToAura.lua`

**Interfaces:**
- Consumes: `research.iter_csv`, `research.as_int`, `research.fetch_table`, `research.resolve_build`, `research.build_pool`, `research.read_shipped_named`, `research.CLASS_BY_CLASS_ID`.
- Produces:
  - `load_spec_map(chr_spec_csv: Path) -> dict[int, dict]` → `{spec_id: {"class": "SHAMAN", "name": "Restoration", "role": int}}` (columns `ID, ClassID, Name_lang, Role`; class via `research.CLASS_BY_CLASS_ID`).
  - `aura_signals(spell_effect_csv: Path, spell_ids: set[int]) -> dict[int, set[str]]` → signal names per spell from `EffectAura` (only rows with `Effect == 6`, APPLY_AURA, or 35/119/128 area auras): `"damage_taken_down"` (87 with negative `EffectBasePointsF`), `"absorb"` (69), `"damage_up"` (79 positive), `"haste_up"` (193 or 65 positive), `"rating_up"` (189), `"stat_pct_up"` (137 positive), `"speed_up"` (31, 129), `"periodic_heal"` (8), `"transform"` (56). The constants live in one dict `AURA_SIGNALS` with a comment citing the WoW `AuraType` enum; **each constant is verified** by a test against the fixture AND by a one-off check against the real cache documented in the test docstring: Astral Shift `108271` must yield `damage_taken_down` (its effect row is `Effect 6, EffectAura 87, EffectBasePointsF -40`).
  - `names(spell_name_csv) -> dict[int, str]` (wrap `research.read_names`).
  - `shipped_categories(categories_lua: Path) -> list[dict]` → `[{"key": "offensiveCDs", "label": "Offensive cooldowns", "aura": "BUFF", "classes": {"SHAMAN": [114051], …}}]` for every `kind = "spells"` category, `aura` from whether it is in `Cat.HELPFUL` or `Cat.HARMFUL`. Build on `research.read_shipped_named` if its shape fits; otherwise a regex over `key = "…", kind = "spells"` blocks and their `CLASS = { ids }` lines (reuse `research.CLASS_ENTRY`).
  - `cast_aura_candidates(cast_to_aura_lua: Path) -> dict[int, list[int]]` → REWRITE (`[cast] = aura`) and CHOICES (`[cast] = { a, b, … }`) merged: `{114050: [114051, 114052, 147059, 1219480, 1252197], …}`, plus the reverse `aura_to_family(...) -> dict[int, set[int]]` mapping each aura id to all ids sharing its cast.
  - `player_pool(cache: dict[str, Path]) -> set[int]` (wrap `research.build_pool`) for rule R8.
  - `open_db2(db2_cache: Path, build: str | None) -> dict[str, Path]` → fetches/locates every table in `research.TABLES` via `research.fetch_table(table, build, db2_cache, refresh=False)`; `build` defaults to the newest file name present in the cache (`SpellName-<build>.csv`), falling back to `research.resolve_build(None)`.
- [ ] **Step 1: Write fixtures** (a few rows each, real column headers copied from the cache: `ChrSpecialization` header `Name_lang,FemaleName_lang,Description_lang,ID,ClassID,OrderIndex,PetTalentType,Role,Flags,SpellIconFileID,PrimaryStatPriority,AnimReplacements,MasterySpellID_0,MasterySpellID_1`; `SpellEffect` needs at least `ID,EffectAura,DifficultyID,EffectIndex,Effect,EffectBasePointsF,EffectMiscValue_0,SpellID`). Fixture Categories.lua: two HELPFUL `spells` categories (`offensiveCDs` with `SHAMAN = { 114051 }` and a trailing comment line; `defensives` with `SHAMAN = { 108271 }`) and one HARMFUL (`hardCC`), in the real `spells({ … })` shape.
- [ ] **Step 2: Failing tests** for each function above, including `aura_signals` for 108271 → `{"damage_taken_down"}` and `cast_aura_candidates` returning the Ascendance family.
- [ ] **Step 3: Run; FAIL.  Step 4: Implement.  Step 5: Run; PASS.**
- [ ] **Step 6: Real-cache check** (not a unit test): `python3 -c "import sys; sys.path.insert(0,'tools/spell-research'); import sid_db2; from pathlib import Path; c=Path('/mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tools/spell-research/.cache'); print(sid_db2.aura_signals(c/'SpellEffect-12.1.0.69875.csv', {108271, 1719, 2825, 1850}))"` → record the output in the commit body (Astral Shift damage_taken_down; Recklessness 1719 and Bloodlust 2825 should show haste/rating/damage; Dash 1850 speed_up). If a constant is wrong, fix it here.
- [ ] **Step 7: Commit** — `SID-4: Read DB2 aura signals, specs and the shipped categories`.

### Task 5 (SID-5): Corrections, flags, evidence bar and decisions suppression

**Files:**
- Create: `tools/spell-research/sid_propose.py`, `tools/spell-research/test_sid_propose.py`

**Interfaces:**
- Consumes: merged `FileAggregate` (or its JSON), `spec_map`, `names`, `shipped_categories`, `aura_to_family`, `decisions: dict` (Task 8's shape: `{"<key string>": {"ruling": "accept"|"reject"|"move", "category": str|None, "date": str, "reason": str}}` — Task 5 only reads keys), thresholds.
- Produces: `evidence_index(agg, spec_map) -> dict[(class, name_lower), dict[int spell_id, dict spec_id -> {"apps", "players", …}]]`, `corrections(...) -> list[Proposal]`, `flags(...) -> list[Flag]`, `proposal_key(p) -> str`, and dataclasses:

```python
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
```

- [ ] **Step 1: Failing tests** with a hand-built aggregate (no files):
  - **Replace:** listed `114051` in `offensiveCDs` for SHAMAN, evidence: Restoration applies `114052` 212 times by 9 players, `114051` never applied by any SHAMAN spec, and the evidence covers only Restoration → but `114051` is in `aura_to_family` of `114052` and the logs contain no Enhancement player: expect **Flag unverified** for `114051` AND **Proposal add** `114052`. Second case: logs contain Enhancement players (≥ 3) who apply neither → expect **Proposal replace** `114051 → 114052` (the candidate exception no longer applies). This is the spec's Ascendance acceptance logic, pinned both ways.
  - **Add:** listed id applied by one spec, another spec applies a same-name different id above the bar → `add`.
  - **Evidence bar:** 19 applications or 2 players → no proposal, a `below_bar` flag.
  - **Stale:** listed id last seen before `range_end - 60 days` while a same-name sibling is seen after → `stale` flag.
  - **Decisions suppression:** a proposal whose `proposal_key` is in `decisions` is not returned.
  - **Debuff cross-check:** a player-applied DEBUFF above the bar that DB2 marks with a CC mechanic (take `research`'s `BUCKET_MECHANICS` via a passed-in set of CC spell ids) and that is in neither `hardCC` nor `softCC` → `cc_unlisted` flag, never a proposal.
- [ ] **Step 2: FAIL.  Step 3: Implement.** Matching is by **class and lower-cased spell name**; the listed id's name comes from DB2 `names`. `proposal_key`: `"%s|%s|%s|%s|%s" % (type, category, klass, name.lower(), ",".join(map(str, sorted(proposed))))`.
- [ ] **Step 4: PASS.  Step 5: Commit** — `SID-5: Propose corrections to listed spells from per-spec evidence`.

### Task 6 (SID-6): Category rules R1–R9, moves and additions

**Files:**
- Modify: `tools/spell-research/sid_propose.py`, `tools/spell-research/test_sid_propose.py`

**Interfaces:**
- Consumes: Task 5's structures, `aura_signals`, `player_pool`, `spec_map` roles (tank role = `Role == 0` in ChrSpecialization; verify in the real cache and note it), a set of Blizzard `EXTERNAL_DEFENSIVE`-tagged ids (not available offline → R5 uses "not in the `externals` token category" only as far as known; document that the token category has no id list, so R5 cannot exclude by tag and says so in its reason).
- Produces: `suggest(stats: dict, signals: set, in_pool: bool, tank_only: bool) -> tuple[str | None, str, str, str]` (category key, rule id, confidence, reason sentence); `moves(...) -> list[Proposal]`; `additions(...) -> list[Proposal]`.

- [ ] **Step 1: Failing tests — one per rule**, each asserting category, rule id, confidence and that the reason names the evidence:
  - R1 `damage_taken_down`, self 95 % → `defensives`, high.
  - R2 group 40 %, `damage_taken_down` → `raidCDs`, high.
  - R3 self 95 %, `haste_up`, recast median 120 s → `offensiveCDs`, high; same with recast 20 s → not R3.
  - R4 `speed_up` → `movement`, high.
  - R5 single 80 % → `support`, medium.
  - R6 `periodic_heal`, mostly others, recast 10 s → `healing`, medium.
  - R7 tank-only, self 95 %, recast 15 s → `activeMitigation`, medium.
  - R8 not in player pool → `consumables`, high.
  - R9 nothing → `utility`, low (or None when even utility is unsupported by evidence: self 0 and single 0).
  - **Move:** a listed `defensives` entry whose evidence is 40 % group + `damage_taken_down` → move to `raidCDs`, medium at most.
  - **Addition:** an above-bar player BUFF in no `spells` category → addition with R-rule; one below the bar → nothing; one ruled in `decisions` → nothing.
- [ ] **Step 2: FAIL.  Step 3: Implement** `suggest` as an ordered list of `(rule_id, predicate, category, confidence, reason_template)` tuples; the first match wins. Percentages are of the aura's applications across all specs of the class.
- [ ] **Step 4: PASS.  Step 5: Commit** — `SID-6: Suggest a category by rule; propose moves and additions`.

### Task 7 (SID-7): Artifacts and `logs.py propose`

**Files:**
- Create: `tools/spell-research/sid_artifacts.py`, `tools/spell-research/test_sid_artifacts.py`
- Modify: `tools/spell-research/logs.py`

**Interfaces:**
- Consumes: everything above.
- Produces: `dictionary_rows(agg, spec_map, names, shipped, suggestions) -> list[dict]` (one row per `(class, spec, auraType, spellId)`, keys: `class, spec, spec_id, spell_id, name, aura_type, applications, players, self_pct, single_pct, group_pct, recast_median_s, first_seen, last_seen, category, suggested_category, rule`), `write_bundle(out_dir: Path, date: str, rows, proposals, flags, shipped, sources: dict) -> list[Path]`. CLI: `logs.py propose --date YYYY-MM-DD --bundle docs/spell-research/<date>-logs [--evidence FILE] [--db2-cache DIR] [--categories defaults/Categories.lua] [--cast-to-aura defaults/CastToAura.lua] [--decisions tools/spell-research/decisions.json] [--min-apps 20] [--min-players 3]` — `--date` is required (never `datetime.now()`, like `research.py`).
- Bundle files (CRLF): `dictionary/auras.json`, `dictionary/auras.csv`, `dictionary/AURAS.md`, `dictionary/non-player.csv`, `CURRENT_CATEGORIES.md`, `CORRECTIONS.md`, `PROPOSED_ADDITIONS.md`, `FLAGS.md`, `SOURCES.md`, and `proposals.json` (the machine-readable queue the slash command walks: corrections first, then additions, each ordered by applications descending, each with its `proposal_key`).

- [ ] **Step 1: Failing tests** from the fixture end to end (scan fixture → propose into a temp dir):
  - `auras.csv`, `AURAS.md` and `auras.json` carry the same row set; a two-spec aura is two rows; nothing from pets/creatures; below-bar auras present.
  - `CURRENT_CATEGORIES.md` lists every shipped id of the fixture Categories.lua with one of `confirmed`/`unverified`/`stale`/`wrong id`.
  - `CORRECTIONS.md` contains the Ascendance line in the spec's format (`Offensive cooldowns · SHAMAN · Ascendance — listed 114051 … → 114052 (Restoration, N apps / P players) … — add|replace — high`).
  - Every entry in `PROPOSED_ADDITIONS.md` has a category, a rule id and a reason; entries are grouped by recommended category.
  - No output file contains `Player-` or any fixture unit name; every file ends lines with `\r\n`.
  - `propose` without `--date` exits non-zero with a message.
- [ ] **Step 2: FAIL.  Step 3: Implement.** Markdown tables: keep them readable in a terminal; `AURAS.md` has a table of contents of classes and specs.
- [ ] **Step 4: PASS.  Step 5: Commit** — `SID-7: Write the per-spec dictionary and the review artifacts`.

### Task 8 (SID-8): Decisions, `logs.py decide`, and `logs.py apply`

**Files:**
- Create: `tools/spell-research/sid_decide.py`, `tools/spell-research/test_sid_decide.py`
- Modify: `tools/spell-research/logs.py`

**Interfaces:**
- Consumes: `proposals.json` from a bundle, `proposal_key`.
- Produces: `load_decisions(path) -> dict`, `record(path, key, ruling, category=None, reason="", date=...)` (atomic write, sorted keys, 2-space JSON, CRLF), `apply(categories_lua: Path, decisions: dict, proposals: list[dict], bundle_rel: str) -> list[str]` (returns a change log). CLI: `logs.py decide --bundle DIR --key KEY --ruling accept|reject|move [--category KEY] [--reason TEXT] --date YYYY-MM-DD`; `logs.py apply --bundle DIR [--categories defaults/Categories.lua]`; `apply` also writes `DECISIONS.md` into the bundle.
- Semantics: `accept` of `replace` removes the listed ids of that class line and inserts the proposed ones; `add` appends; `move` removes from `from_category` and appends to `category`; `addition` appends to `category` (or the `--category` chosen at decide time). A `move` ruling on an addition means "accept into a different category". `reject` changes nothing and suppresses the key forever.

- [ ] **Step 1: Failing tests** on a temp copy of `fixtures/Categories.lua`:
  - Replace rewrites only `SHAMAN = { 114051 }` → `SHAMAN = { 114052 }` inside `offensiveCDs`; `git diff`-style comparison shows exactly one changed line plus one provenance comment line above it: `-- 114052: combat-log evidence, docs/spell-research/<date>-logs (SID)`.
  - A class not yet in the category gets a new line inserted in `research.CLASS_EMIT_ORDER` order with the file's alignment (Review Focus 5).
  - A trailing comment on the class line survives.
  - Running `apply` twice changes nothing the second time (idempotent).
  - An accepted proposal whose key is not in `decisions` is refused (exception naming the key).
  - The rewritten file keeps CRLF.
  - `record` then `load_decisions` round-trips; the file is sorted and CRLF.
- [ ] **Step 2: FAIL.  Step 3: Implement.  Step 4: PASS.**
- [ ] **Step 5: Addon gates** on the real repo are not touched in this task (only fixtures). Commit — `SID-8: Record owner rulings and apply them to Categories.lua`.

### Task 9 (SID-9): Slash command, docs, and the end-to-end acceptance run

**Files:**
- Create: `.claude/commands/aura-spells-review.md`
- Modify: `.gitignore` (`.claude/` → `.claude/*` and `!.claude/commands/`; keep `.claude/settings.local.json` ignored), `tools/spell-research/README.md` (a "Combat-log evidence" section: what it does, the commands, the thresholds, the artifacts, privacy), `DEPENDENCIES.md` (the combat-log folder as an optional input; still stdlib only), `docs/module-map.md` or `docs/ARCHITECTURE.md` if either inventories `tools/` (check and follow the repo's doc rules in CLAUDE.md)
- Test: `tools/spell-research/test_sid_e2e.py`

- [ ] **Step 1: Failing E2E test** `test_sid_e2e.py`: in a temp dir, copy the fixture log, the fixture Categories.lua, CastToAura.lua and DB2 fixtures; run `logs.py scan`, `logs.py propose --date 2026-09-24 --bundle <tmp>/bundle`, then `logs.py decide` accept on the Ascendance proposal's key, then `logs.py apply`; assert the temp Categories.lua's `offensiveCDs` SHAMAN line now contains `114052` and `DECISIONS.md` exists. Invoke through `subprocess.run([sys.executable, "tools/spell-research/logs.py", ...])` so the CLI is what is tested.
- [ ] **Step 2: FAIL (until wiring is complete), then fix any wiring gaps; PASS.**
- [ ] **Step 3: Write the slash command** `.claude/commands/aura-spells-review.md`. Frontmatter: `description: Review combat-log evidence for AuraMaster's spell categories and apply the owner's rulings`, `argument-hint: [logs-folder]`. Body, in order:
  1. Confirm cwd is the AuraMaster repo and the tree is clean.
  2. Run `python3 tools/spell-research/logs.py scan --logs "${ARGUMENTS:-<default folder>}" --db2-cache <…>` **in the background** (it can take ~20 min on a first run; later runs read only new logs), then `logs.py propose --date <today YYYY-MM-DD> --bundle docs/spell-research/<today>-logs`.
  3. Tell the owner the counts (corrections, additions, flags) and the paths of the dictionary and review files.
  4. Walk `proposals.json` **one proposal at a time**, corrections first: show the evidence line, the proposed change, the suggested category, rule and reason; ask with AskUserQuestion: **Accept / Change category (then ask which) / Reject (optional reason)**. Record each answer immediately with `logs.py decide …` (never hand-edit JSON). Allow "stop here" — rulings so far are saved; the rest stay pending for the next run.
  5. `logs.py apply --bundle …`; then `ka0s-bounded luacheck .` and `ka0s-bounded lua5.1 tests/run.lua`; if red, show it and stop without committing.
  6. Commit `defaults/Categories.lua`, `tools/spell-research/decisions.json` and the bundle with subject `Spell categories: apply combat-log rulings (<date>)`.
- [ ] **Step 4: Docs** as listed; README examples must be commands that actually run.
- [ ] **Step 5: All Python tests pass** (`python3 -m unittest discover -s tools/spell-research -p 'test_*.py'`) and the addon gates are unchanged (`ka0s-bounded luacheck .` 0/0; `ka0s-bounded lua5.1 tests/run.lua` 0 failed — no Lua changed, but confirm).
- [ ] **Step 6: Commit** — `SID-9: Add the aura-spells-review command, docs and the end-to-end test`.

### Task 10 (SID-10): Warm the cache and dry-run on the real logs (no commit to Categories.lua)

Not a code task; it proves the tool on the 30 GB archive so the owner's first review starts immediately.

- [ ] **Step 1:** `python3 tools/spell-research/logs.py scan --logs "/mnt/g/Games/Blizzard/World of Warcraft/_retail_/Logs/RaiderIOLogsArchive" --db2-cache /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tools/spell-research/.cache` (background; ~20 min). Record wall time, files, bytes, skipped, unattributed.
- [ ] **Step 2:** `logs.py propose --date 2026-09-24 --bundle /tmp/claude-1000/sid-dryrun/2026-09-24-logs …` — to a scratch path, **not** the repo (the real bundle is written by the owner's review run).
- [ ] **Step 3:** Check: Restoration `114052` Ascendance appears under `SHAMAN / Restoration` in the dictionary; `CORRECTIONS.md` proposes it for Offensive cooldowns; Astral Shift `108271` is `confirmed`. Report counts of corrections/additions/flags and any crash or suspicious result; fix bugs found (each fix with a failing test first, committed as `SID-10: …`).

---

## Self-review (done at authoring)

- Spec coverage: stage 1 → Tasks 1–3; DB2 inputs → 4; corrections/flags/evidence bar/decisions → 5; rules/moves/additions → 6; dictionary + review set + SOURCES → 7; decisions/apply/DECISIONS.md → 8; slash command, docs, gitignore → 9; run cost/first run → 10. Debuff cross-check → 5. Privacy → 2 and 7 tests. Cast id ≠ aura id → 4 (`aura_to_family`) and 5.
- Names are consistent across tasks: `FileAggregate`, `AuraStats`, `scan_file`, `scan_dir`, `merge`, `load_spec_map`, `aura_signals`, `shipped_categories`, `cast_aura_candidates`, `aura_to_family`, `player_pool`, `open_db2`, `Proposal`, `Flag`, `proposal_key`, `suggest`, `dictionary_rows`, `write_bundle`, `load_decisions`, `record`, `apply`.
- Distinct-player counts are exact across files (salted hashes in the local cache only); no GUID or hash reaches the repo. Task 3 tests that a player seen in two logs counts once.
