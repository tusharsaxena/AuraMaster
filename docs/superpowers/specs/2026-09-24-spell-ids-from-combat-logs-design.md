# Spell ids from combat logs — design

Date: 2026-09-24. Branch `feat/spell-ids-from-logs` (worktree `../AuraMaster-spellids`), cut from
`feat/2026-09-23-review-audit-remediation` at `2c7da5a`, to be merged back into it when done.
Status: approved by the owner in conversation (sections 1–3 plus the corrections addendum), with the
instruction to build it end to end.

## Why

`defaults/Categories.lua`'s `spells`-kind categories are hand-assembled starter lists. Some ids are
wrong for the spec that actually casts them. The owner's case: a container that shows only
Offensive, Defensive and Raid cooldowns and hides everything else, including Uncategorized, draws
nothing when a Restoration Shaman casts **Ascendance**, because the category lists `114051` and the
aura Restoration actually gets is `114052`. **Astral Shift** (`108271`) is right and works.

`tools/spell-research/research.py` already reads Blizzard's DB2 tables and derives
`defaults/CastToAura.lua`, which lists **five** candidate aura ids for Ascendance
(`114051, 114052, 147059, 1219480, 1252197`). DB2 can say which ids are *possible*; it cannot say
which one *lands* for a given spec and talent build. The combat log records exactly that.

**Goal:** the category spell lists become correct and authoritative. Every id is either confirmed
by combat-log evidence or explicitly ruled by the owner, and the process can be re-run whenever new
logs arrive.

## Inputs

- **Combat logs**: `WoWCombatLog-*.txt` under a folder passed on the command line. Default:
  `/mnt/g/Games/Blizzard/World of Warcraft/_retail_/Logs/RaiderIOLogsArchive` (201 files, 30 GB, as
  of 2026-09-24). Advanced combat logging is on (`COMBAT_LOG_VERSION,22,ADVANCED_LOG_ENABLED,1`).
  UTF-8, CRLF, very long lines.
- **DB2 tables**: the ones `research.py` already caches (`tools/spell-research/.cache/`), read through
  its own functions. No new download path.
- **`defaults/Categories.lua`** and **`defaults/CastToAura.lua`**: read, parsed with `research.py`'s
  existing readers (`read_shipped_named`, the `CastToAura` candidate lists).
- **`tools/spell-research/decisions.json`**: the owner's past rulings (created on first review).

## Architecture

A new module `tools/spell-research/logs.py` beside `research.py` (which it imports and never
changes in behaviour). Python 3 standard library only, like `research.py` (`DEPENDENCIES.md`).

### Stage 1 — scan (logs → evidence)

Streams each log as bytes, line by line. Never loads a file into memory.

- **Spec tracking.** `COMBATANT_INFO,<guid>,<faction>,<specID>,…` sets `spec[guid] = specID` for the
  rest of that file. An aura applied before any `COMBATANT_INFO` for its source records spec
  `unknown`. Spec ids map to class and spec name through `ChrSpecialization` (DB2 cache).
- **Player-only filter.** Keep `SPELL_AURA_APPLIED` lines whose source GUID starts `Player-` and
  whose source flags have the player type bit (`0x400`) and the player-controlled bit (`0x100`).
  Auras from `Pet-`/`Creature-` sources are counted in a separate `nonPlayer` tally (see edge cases),
  never in the main evidence.
- **Field parsing.** The line is split on commas outside double quotes (names such as
  `"Artêmîs-Frostmourne-US"` and spell names may contain commas). Fields used: event, source GUID,
  source flags, dest GUID, spell id, spell name, aura type (`BUFF`/`DEBUFF`), and the timestamp.
- **Aggregates**, per `(auraType, spellId)`:
  - `name` (most common spelling seen) and `names` if more than one;
  - `bySpec[specID] = applications`, and `byClass[class]` derived from it;
  - `players` = count of distinct source GUIDs (the GUIDs themselves are not kept in the output);
  - target shape counts: `self` (dest == source), `single` (one other player), `group` (the same
    caster applied the same aura to ≥ 5 distinct players within 1.0 s — the application that opens a
    burst is counted once as `group`, its companions are absorbed). An external that the client
    also logs on its caster (the same caster and aura on itself and on exactly one other player
    within 0.1 s: Power Infusion, Blessing of Sacrifice, Guardian Spirit) is ONE `single`
    application, not `self` + `single` (owner ruling, 2026-09-24);
  - `recast` median seconds between successive casts of the aura by the same caster, onto any
    target, a `SPELL_AURA_REFRESH` (a rolling HoT re-cast before it expires) included
    (applications under 0.5 s apart are one cast; across specs each spec's median is weighted by
    its interval count), a rough cooldown, from at most the first
    200 intervals per aura to bound memory. Measured on self-applications alone, a HoT cast onto
    other players had no recast and failed R6 (owner ruling, 2026-09-24);
  - `firstSeen` / `lastSeen` log dates (from the file name stamp, not the line).
- **Per-log cache.** Each log's aggregates are written as JSON to
  `~/.cache/auramaster-spell-research/logs/<name>-<size>-<mtime>.json` (outside the repo). A re-scan
  reads a log only if its key is missing. Merging per-log aggregates into the run total is a plain
  sum (medians are merged from their capped interval samples).
- **Robustness.** A truncated final line (client killed mid-write), an unknown event, or a
  malformed line is skipped and counted in the scan summary, never fatal.
- **Privacy.** No player name, realm or GUID reaches any output or committed file. Only classes,
  specs and counts.

### Stage 2 — propose (evidence + DB2 + decisions → proposals)

Thresholds (flags, with these defaults): a proposal needs **≥ 20 applications from ≥ 3 distinct
players**. Below that, an id is reported as "seen, below the evidence bar" and never proposed.

Proposal types, reviewed in this order, most-applied first within each:

1. **Corrections to existing entries.** For every id in a `spells`-kind category, group evidence by
   **class and spell name** (the entry's class key plus the DB2 name of the listed id):
   - **Replace (wrong id).** The listed id is never applied by that class, while an aura of the
     same name is. Propose replacing it with the observed id(s). Exception: if the listed id is a
     DB2 candidate of the same spell (in `CastToAura`'s candidate list for its cast) and the logs
     simply contain no player of the spec that would apply it, keep it and flag **unverified**.
   - **Add (missing variant).** The listed id is applied (correct for some spec) and other specs of
     the class apply a same-name aura under other ids. Propose adding those ids.
   - **Move (wrong category).** The entry's observed behaviour contradicts its category's rule
     (table below) with at least medium confidence. Propose moving it. Medium confidence at most.
2. **Additions.** Player-applied buffs above the evidence bar that are in no `spells`-kind category,
   with a suggested category from the rules below.
3. **Flags (report only, no proposal).** **Unverified** (listed, no log evidence either way, DB2
   says it is a real aura). **Stale** (listed, not applied in logs newer than the newest two months
   of the scanned range while a same-name sibling is). Stale ids are never removed without a ruling.

Anything whose key (`type`, `category`, `class`, `spellId`, and for additions the suggested
category) is already in `decisions.json` is not proposed again.

#### Category suggestion rules (first match wins; the rule id is recorded)

| Rule | Evidence | Suggestion | Confidence |
|---|---|---|---|
| R1 | DB2: the aura reduces damage taken, absorbs, or grants immunity (SCHOOL_IMMUNITY 39, DAMAGE_IMMUNITY 40: Divine Shield), and target shape is ≥ 90 % `self` | Defensive cooldowns | high |
| R2 | ≥ 30 % of applications are `group`, and DB2 shows damage reduction or healing, or a haste increase (`group_haste_up`: Bloodlust) | Raid cooldowns | high |
| R3 | ≥ 90 % `self`; DB2 shows a damage, haste, crit, mastery or versatility increase; median recast ≥ 60 s | Offensive cooldowns | high |
| R4 | DB2: movement speed increase, or the cast is a teleport or leap | Movement | high |
| R5 | ≥ 70 % `single` onto another player, and the aura is not tagged Blizzard `EXTERNAL_DEFENSIVE` | Support | medium |
| R6 | DB2: periodic heal or absorb, applied mostly to others, median recast < 30 s | Healing | medium |
| R7 | only tank specs apply it, ≥ 90 % `self`, median recast < 30 s | Active mitigation | medium |
| R8 | DB2: the spell is an item/consumable effect (not in the player-castable class pool) | Consumables | high |
| R9 | none of the above | Utility, or no suggestion | low |

The DB2 "effect" signals come from `SpellEffect`'s aura types (e.g. mod damage taken, school
absorb, mod damage/haste/crit/mastery/versatility percent, mod increase speed, periodic heal),
through `research.py`'s cached tables. The exact aura-type ids are pinned as named constants in
`logs.py` with a comment citing the DB2 enum, and each has a unit test.

**Debuff categories** (`hardCC`, `softCC`) keep `research.py`'s DB2 mechanic method. Log evidence
only **cross-checks** them: player-applied CC debuffs not in either list are flagged in the report,
never proposed as moves.

#### Edge cases

- **Same name, different id** is the whole point of Replace/Add. Different name = different spell;
  talent-renamed variants surface as Additions, never silent merges.
- **Pets, totems, guardians.** Excluded from the main evidence by the player-only rule. Counted in a
  separate `nonPlayer` table so the report can show "also applied by pets/totems" where relevant.
- **Cast id ≠ aura id.** When a category lists a *cast* id that `CastToAura` maps to candidate aura
  ids, the observed aura ids are proposed against that entry.

### Stage 3 — review and apply (the Claude slash command)

A project command at `.claude/commands/aura-spells-review.md` in AuraMaster. It:

1. runs `logs.py scan` (logs folder as an optional argument) in the background, then
   `logs.py propose --date <today> --bundle docs/spell-research/<date>-logs`;
2. asks the owner about each proposal, one at a time, corrections first then additions, each with
   its evidence line and suggested category: **accept / change category / reject (optional reason)**;
3. records every ruling in `tools/spell-research/decisions.json` through `logs.py decide …` (never
   hand-edited JSON);
4. applies the accepted ones with `logs.py apply`, which rewrites only the affected `spells({…})`
   class lines in `defaults/Categories.lua`, preserving order and comments, and adds a provenance
   comment naming the bundle; then runs luacheck and the headless tests through
   `ka0s-bounded`, and commits.

`apply` is the only writer of `defaults/Categories.lua`, and it applies only rulings in
`decisions.json`. No path edits the shipped file without an owner ruling.

## Outputs

- `docs/spell-research/<date>-logs/` (frozen bundle), in two groups (owner requirement,
  2026-09-24):

  **The dictionary — every aura id that matches the formula, to browse later.** The formula (owner,
  2026-09-24): **per spec, and cast by a player, not an NPC.** So the dictionary's key is
  `(class, spec, auraType, spellId)`, built from stage 1's player-only filter (source GUID `Player-`
  with the player type and player-controlled flag bits), whatever the count and whether or not the
  aura is in a category. An aura applied by three specs is three rows. Applications whose caster's
  spec could not be established (no `COMBATANT_INFO` for that player earlier in the same file) go
  under spec `unknown` within the class when the class is known from an earlier line, and are
  otherwise kept out of the per-spec dictionary and counted in `SOURCES.md`.
  - `dictionary/auras.csv` — one row per `(class, spec, auraType, spellId)`: class, spec, spell id,
    name, aura type, applications, distinct players, `self`/`single`/`group` percentages, median
    recast, first/last seen, current category (or blank), suggested category and rule id (or blank).
    Sorted by class, spec, name, id. Opens in any spreadsheet.
  - `dictionary/AURAS.md` — the same rows as a readable page: one section per class, one sub-section
    per spec, each aura as `name (id) — applications / players — shape — category or suggestion`,
    with a table of contents.
  - `dictionary/auras.json` — the same rows, machine-readable; the source the other two are rendered
    from.
  - `dictionary/non-player.csv` — the separate pet/totem/guardian tally (not per spec; not part of
    the formula, kept only so the report can say "also applied by pets/totems").

  **The review set — what the categories are and what should change.**
  - `CURRENT_CATEGORIES.md` — every `spells`-kind category as shipped: each class line and each id
    with its name and its evidence status (**confirmed** with counts, **unverified**, **stale**, or
    **wrong id**), so the current state can be read on its own.
  - `CORRECTIONS.md` — the Replace / Add / Move proposals for existing entries, one block each:
    category, class, listed id(s), proposed id(s), the evidence per spec, the rule or reason, and the
    confidence. E.g. `Offensive cooldowns · SHAMAN · Ascendance — listed 114051 (never applied) →
    114052 (Restoration, 212 apps / 9 players), 1219480 (Elemental, 88 / 4) — replace — high`.
  - `PROPOSED_ADDITIONS.md` — new auras above the evidence bar and in no category: spell, class and
    specs, evidence, **recommended category, the rule that chose it and a one-sentence reason in
    plain words** (e.g. "applied to 5+ players at once and reduces damage taken → Raid cooldowns"),
    and the confidence. Grouped by recommended category.
  - `FLAGS.md` — unverified ids, stale ids, below-the-bar sightings of listed spells, and the
    debuff-category cross-check.
  - `SOURCES.md` — logs scanned (count, date range, bytes), DB2 build, thresholds, skipped-line
    counts.
  - `DECISIONS.md` — the rulings made in this review (copied from `decisions.json`'s entries dated
    this run), written after the review.

  The review in stage 3 walks `CORRECTIONS.md` then `PROPOSED_ADDITIONS.md`; the dictionary is
  never reviewed item by item.
- `tools/spell-research/decisions.json` — durable rulings, sorted, one entry per key, with date and
  optional reason.

## Testing

Standard-library `unittest`, in `tools/spell-research/test_logs.py`, run with
`python3 -m unittest discover tools/spell-research`. Test-first throughout.

- **Scanner** against a hand-written fixture `tools/spell-research/fixtures/combatlog-sample.txt`
  (a few dozen lines, fictional names): `COMBATANT_INFO` spec tracking; the player-only filter
  (player, pet, creature sources); quoted names with commas; CRLF; a truncated final line;
  `self`/`single`/`group` shape counting including the 1-second burst window; the recast median.
- **Cache**: a second scan of an unchanged log reads nothing; a changed size or mtime re-reads.
- **Proposals**: one test per rule R1–R9; Replace vs the DB2-candidate exception (unverified);
  Add; Move; the evidence bar; decisions-file suppression; the debuff cross-check stays a flag.
- **Artifacts**: from the fixture, the dictionary holds one row per `(class, spec, auraType,
  spellId)` for every player-applied aura (including ones below the evidence bar and ones in no
  category), a two-spec aura is two rows, and nothing from pets/creatures appears; `auras.csv`,
  `AURAS.md` and `auras.json` carry the same row set; `CURRENT_CATEGORIES.md` lists every shipped
  id with a status; each addition in `PROPOSED_ADDITIONS.md` has a category, a rule id and a reason.
- **Apply**: rewrites only the targeted class line, keeps comments and order, is idempotent, and
  refuses an entry not in `decisions.json`.
- **The Ascendance acceptance test**: fixture evidence of Restoration applying `114052` must yield a
  Replace proposal for `114051` in Offensive cooldowns (subject to the candidate exception for any
  spec the fixture lacks), and after an accept ruling, `apply` must put `114052` into that category.
- **Addon gates**: any `Categories.lua` change keeps `ka0s-bounded luacheck .` at 0/0 and
  `ka0s-bounded lua5.1 tests/run.lua` green, including the existing category-shape and
  duplicate-id checks.

## Out of scope

Auto-editing without a ruling; changing the addon's filter engine; per-spec lists inside the addon
(the filter ignores the class key, so a category is one flat id set); a scheduled run (the owner
runs the command when there are new logs); changes to `research.py`'s existing outputs.

## Run cost

Measured 2026-09-24: one streaming pass over the largest log (760 MB) took 31 s wall, I/O-bound
(12 % CPU). The first full scan of 30 GB is about 20 minutes; later scans read only new logs.
