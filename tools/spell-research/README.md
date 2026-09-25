# tools/spell-research — deriving the CC spell lists from the client's own data

The repeatable half of GitHub issue #11. Design of record:
`docs/superpowers/specs/2026-09-20-cc-categories-spell-research-design.md`, **Part C**.

`defaults/Categories.lua`'s spell lists are a starter set that was assembled by hand from public
spell data (that file's own header says so). This tool replaces the hand-assembly for the two CC
categories: it reads Blizzard's DB2 tables for one pinned retail build, works out which spells a
player can actually be hit by, buckets them by the crowd-control **mechanic the client itself
stamps on them**, and prints either a diff against what the addon ships today or a paste-ready Lua
fragment.

**`research.py` never writes `defaults/Categories.lua`.** Part C's narrowing rule is that the author accepts
the diff per change. A generator that edited the shipped file would turn a judgment call into a
rubber stamp, and the limitations at the bottom of this page are exactly the cases where that
judgment is the only thing standing between the addon and a wrong list.

Its sibling `logs.py` answers a different question from the owner's combat logs (which aura id a
spec actually gets) and does write `defaults/Categories.lua`, but only through `logs.py apply` and
only for proposals the owner has ruled on; see *Combat-log evidence* at the end of this page.

## Running it

Python 3 and the standard library. No pip packages, no virtualenv — see `DEPENDENCIES.md`.

```sh
# What would change, against the live retail build (this is also what a bare run does)
python3 tools/spell-research/research.py --diff

# The paste-ready Lua fragment, in defaults/Categories.lua's own shape. --emit REQUIRES a date:
# the date is pasted into defaults/Categories.lua as provenance, so it has to name a real run.
python3 tools/spell-research/research.py --emit --date 2026-09-20

# Cross-check every id defaults/Categories.lua ships, against the build (issue #15). Three
# questions, over all of them and not just the two CC buckets: does the build still name this id,
# does it apply an aura of its own, and does its name still agree with the comment beside it?
python3 tools/spell-research/research.py --check-shipped

# The cast -> aura table, defaults/CastToAura.lua, whole. A different question from --emit over the
# same tables: which player-castable ids apply no aura, and what aura they actually land.
python3 tools/spell-research/research.py --emit-cast-aura --date 2026-09-20 > defaults/CastToAura.lua

# Freeze a run: gzipped raw exports, SOURCES.md, derived.json, DIFF.md
python3 tools/spell-research/research.py --bundle docs/spell-research/2026-09-20

# Pin a build explicitly, and force a re-download
python3 tools/spell-research/research.py --build 12.1.0.69875 --refresh --diff

# Re-derive a PAST run offline, out of the bundle's own raw/*.csv.gz — no network, no cache
python3 tools/spell-research/research.py --replay docs/spell-research/2026-09-20 --diff
```

The exports are cached in `tools/spell-research/.cache/` (git-ignored, ~75 MB a build) so a re-run
costs nothing. The first run of a build downloads about 75 MB, most of it `SpellEffect`.

`--bundle`'s directory name supplies the date, or pass `--date YYYY-MM-DD`. The date is **an
argument, never `datetime.now()`**: the caller decides what a bundle is called, and a run that
straddles midnight must not quietly land somewhere else.

`--emit` **fails without one.** It used to fall back to the clock, which put a date belonging to no
recorded run into the provenance comment that gets pasted into `defaults/Categories.lua` — where it
is read afterwards as "the day this list was derived", with nothing left to contradict it and no
bundle to look the run up in. Give it the bundle the ids came from (`--date`), or freeze this run
and use its date (`--bundle`).

## What it does, in order

1. **Resolve the build** — `https://wago.tools/api/builds`, key `wow` is retail, newest first. Or
   `--build`. One run, one build: a bundle has to be reproducible.
2. **Fetch** fourteen DB2 tables as CSV, streamed to disk. `SpellEffect` is ~57 MB and is never held
   in memory as text.
3. **Build the player pool** — every spell a player can reach — from `SkillLineAbility` (class masks
   and class skill lines), `SpecializationSpells` (via `ChrSpecialization` for the class) and
   `TraitDefinition` (via the four-table talent-tree join for the class).
4. **Close the pool over `SpellEffect.EffectTriggerSpell`** — *the crux*, see below.
5. **Bridge within the spell family by name** — the one edge DB2 does not give us directed, see
   below. Steps 4 and 5 **alternate to a fixed point**: each feeds the other, so running them once
   each would make the order of two lines load-bearing and leave whichever ran first unfinished.
   On build 12.1.0.69875 that settles after three passes (+886 triggered, +298 bridged).
6. **Bucket** by mechanic: the spell-level `SpellCategories.Mechanic` unioned with every effect-level
   `SpellEffect.EffectMechanic`.
7. **Run the coverage gate.** A miss exits non-zero.
8. **Report** — `--diff`, `--emit`, `--bundle`.

Rows are read at `DifficultyID == 0` wherever that column exists, so raid-difficulty variants do not
multiply the set.

## The crux: aura ids, not cast ids

AuraMaster's filters match **the aura's** spell id. `modules/FilterCompiler.lua` hands Blizzard's
aura container `includeSpellIDs` / `excludeSpellIDs`, and the engine compares those against the id
of the aura sitting on the unit — not against the id of the spell that was cast.

Plenty of crowd control is cast as one spell and lands as another. A list built from cast ids looks
completely populated in the General → Spell Categories editor and **silently never matches anything
in game** — the worst failure available, because nothing anywhere reports it.

Two steps exist solely because of this:

- **The trigger closure (step 4).** The pool is closed transitively over
  `SpellEffect.EffectTriggerSpell`, carrying the class set across each edge.
- **The spell-family name bridge (step 5).** The closure is not enough on its own, and there are
  three distinct shapes of handoff it cannot follow — all verified against build 12.1.0.69875:

  | Shape | Example | Where the edge goes |
  | --- | --- | --- |
  | Ground effect | Freezing Trap 187650 → 187651 (`CREATE_AREATRIGGER`, properties 4424) → aura 3355 | `AreaTriggerCreateProperties` is `ID,ShapeType,StartShapeID,SoundKitID` — no spell column at all |
  | Summoned creature | Capacitor Totem 192058 (`SUMMON`, creature 61245) → stun 118905 | which spells a creature casts is server data |
  | Server spell script | Storm Bolt 107570 (damage + `DUMMY`) → stun 132169 | `EffectTriggerSpell` is 0; the aura is applied from the server binary |

  Blinding Light 115750 → 105421 and Holy Word: Chastise 88625 → 200200 are the third shape too.

  The client does carry a real relationship here, just not a directed one:
  **`SpellClassOptions.SpellClassSet` is the spell *family*** — the grouping the game's own talent
  and set-bonus modifiers are written against (`EffectSpellClassMask_0..3` indexes into it). Every
  pair above shares a family (107570/132169 both 4, 113724/82691 both 3, 115750/105421 both 10,
  88625/200200 both 6, 192058/118905 both 11, 187651/3355 both 9), and every NPC and encounter copy
  that merely shares a *name* with one of them sits in family 0, which is the absence of a family.

  So a pool spell bridges to every spell with **the same exact name and the same non-zero family**
  that carries a bucket mechanic. Family is the foreign key; the name picks one ability out of the
  family. On build 12.1.0.69875 that adds 298 ids, and the names read as a list of player crowd
  control: Freezing Trap, Ring of Frost, Storm Bolt, Shockwave, Capacitor Totem, Sigil of Misery,
  Ursol's Vortex, Imprison, Hex, Blinding Sleet.

  **Why not name alone, and why not an effect fence.** Name alone adds 1,763 ids, most of them
  encounter scripts reusing a word. The fence this bridge *replaced* was "only spells that create an
  area trigger may bridge" — fitted to the single case, Freezing Trap, that had failed, and by
  construction blind to the summon and spell-script shapes. It left Storm Bolt, Ring of Frost,
  Blinding Light, Holy Word: Chastise and Capacitor Totem out of the derived pool **while the
  coverage gate reported PASS**, which is the exact failure the gate exists to prevent. Generalizing
  it to effects 179, 28 and 3 would have caught them at 547 ids of mostly noise, because `DUMMY` is
  not evidence of anything. Family is evidence.

  Every bridged id is still **labeled** — `"source": "bridge"` in `derived.json`,
  `**[family bridge — name match inside the family, check it]**` in the diff, `(family bridge)` in
  the emitted Lua — because a shared name inside a shared family is still weaker than a directed
  edge. `--emit` goes further and **segregates** them: inside each class key the directly derived
  ids come first, then a `-- family bridge` marker, then the bridged ones, and both the block
  header and the class key carry the `N derived + M bridged` split. The derived set is majority
  bridged, so that split is the size of the reading job, stated before the reading starts.

  It is deliberately **not** deduplicated to one id per name. "Freezing Trap" covers several ids
  inside its own family — the live aura plus legacy copies — and nothing in this data reliably says
  which is live. Guessing (lowest id, say) is a *silent* wrong answer, and silent under-coverage is
  this design's stated failure mode; a surplus id is a *visible* one that costs a row in the editor
  and never matches. Prune them at the diff, which is where the judgment belongs anyway.

## The shipped-id cross-check (`--check-shipped`)

`--diff` derives the two CC buckets and compares them. Nothing checked the **other nine** shipped
lists, and nothing checked any list for the failure that actually bites: an id that is no longer
what the file says it is. This does, mechanically, over every id in `defaults/Categories.lua`:

* **The build does not name it** — mistyped, or the spell is gone. It draws as *Unknown spell N*.
* **It applies no aura of its own** — it is the CAST of an ability whose aura carries a different
  id. Five shipped ids were in this state when the check was written; see issue #15.
* **Its name disagrees with the comment beside it** — the id has been reused across an expansion,
  or was transcribed wrong. `format_diff` used to say a rename "cannot be detected against the
  shipped file, which stores no names". It does store them, in the comment beside each id.

**Where the names come from.** `defaults/Categories.lua` writes one table per class with **one id
per line**, and the comment on that line gives the spell's name, then any context after a `;`
(`436358,  -- Demolish; from the 2026-09-24 combat logs; ...`). The name is the text before the
first `;`, so every shipped id carries one: all 440 do today. One reader in `research.py`
(`parse_spells_body`) serves this check, `--diff` and the `logs.py` stages alike, and it takes ids
from code only, never from a comment, since comments are full of digits (dates, `replaces 231895`,
`98007 is the cast`).

**The legacy one-line layout is still read, and its name check is positional and only taken when it
is safe.** A class written as `CLASS = { 1, 2 }, -- Name1, Name2` has a comma-separated trailing
comment meant to line up with its ids — but it is prose maintained by hand, and a line whose counts
disagree is not evidence of anything. Such a line contributes its ids with no name, so the first two
checks still run over it and only the name check is skipped.

**What it cannot tell you**, so the gate is not read as more than it is: whether an id is in the
RIGHT category, and whether it is the aura a player actually *sees* rather than some other aura the
same spell applies. Both need a human or a live client — `docs/scope.md` says why.

## The bucket map

`BUCKET_MECHANICS`, at the top of `research.py`, is **the one authored, reviewable input**.
Everything downstream is derived from the client's data. It maps each category to a set of
`SpellMechanic` ids:

- **hardCC** — charmed, disoriented, fleeing, asleep, stunned, frozen, incapacitated, polymorphed,
  banished, shackled, turned, horrified, sapped. *The unit loses control.*
- **softCC** — rooted, slowed, snared, dazed. *The unit keeps control but moves less.*

That is Part A's two-way split, not Blizzard's five DR groups. A spell matching both buckets is Hard
CC: losing control is the stronger statement.

Each id carries the mechanic's name as the pinned build reports it, and a run warns when a name no
longer matches — the loudest early warning available that a human needs to look at the map.

## The coverage gate

`SENTINELS`, also at the top of `research.py`: a checked-in set of spells that **must** land in a
given bucket, grouped by class so a gap is legible as a gap. A miss prints every missing sentinel
and **exits non-zero**. Build 12.1.0.69875 satisfies 66 of them.

This is not belt-and-braces. Silent under-coverage was demonstrated three separate times while the
approach was being validated: a first cut matched 32 hard-CC spells, a second 66, and only a third —
after class skill lines joined the pool — reached 81 and finally picked up Hammer of Justice,
Entangling Roots and Leg Sweep. **Every one of those intermediate runs produced a plausible-looking
list a reviewer would have accepted.** A fourth failure, Freezing Trap, is what produced the name
bridge above.

### Sentinels are chosen from the game, never from the output

The gate's first version held ten hard-CC and six soft-CC names, and every one of them was a name
the implementation of the day already produced. **A gate assembled that way can only ever report
PASS.** It certifies that the tool still does what it did, which is not the question anyone is
asking. It duly reported PASS over a derived set missing Storm Bolt, Ring of Frost, Blinding Light,
Holy Word: Chastise and Capacitor Totem — five of the most recognizable stuns in the game — because
the area-trigger fence on the name bridge could not see them.

A gate that cannot fail is worse than no gate: no gate leaves a reviewer suspicious, a passing gate
buys their trust with nothing behind it.

So the list is now built the other way round, and **must keep being built that way**: write down
what a player would name as that class's crowd control, then make the pipeline satisfy it. When a
name here is missing from a run, the answer is to fix the pipeline, or to move the name to
`SENTINELS_UNREACHABLE` with a reason. The answer is never to delete it quietly, and it is never to
bend `BUCKET_MECHANICS` until it passes — bending the map to satisfy its own test is the one thing
this gate must never cause.

`SENTINELS_UNREACHABLE` is the honesty register: names that belong on the domain list but that the
client's own data cannot reach, each with the verified reason. It is not checked at run time — a
gate that fails every run is a gate that gets ignored — and every line in it is mirrored under
*Limitations* below. Two lists, and a reader can audit the gate's honesty by reading both.

Matching is by **name**, case-insensitively. Names rather than ids on purpose: an id is exactly the
thing a patch is allowed to change, and a sentinel that silently stopped existing would defeat the
gate it is part of.

**Entangling Roots is a soft-CC sentinel, deliberately.** The design's Part C prose names it among
the spells the third validation run finally reached, which is a statement about *pool coverage* and
reads easily as one about its *bucket*. It is not: Part A defines Soft CC as "roots and snares", and
the client agrees — Entangling Roots (339) carries mechanic 7, Rooted, and nothing else.

## Class grouping

Each derived id carries the class set that reached it, which becomes the `spells({ CLASS = { … } })`
grouping the defaults file wants. `class` is display-only there — the filter ignores it — but a list
of eighty ids that a player cannot navigate is a list a player will not edit.

Getting that grouping right is why the tool fetches fourteen tables rather than the eight the
spec's table list names (the fourteenth, `SpellClassOptions`, is the family bridge's). Measured
against
build 12.1.0.69875: the thirteen class skill lines carry only 17–122 ability rows each, and Mind
Control, Banish, Psychic Scream and Incapacitating Roar are in **neither** `SkillLineAbility` **nor**
`SpecializationSpells` — they reach the pool only as talents. Without the talent-tree join
(`TraitDefinition → TraitNodeEntry → TraitNodeXTraitNodeEntry → TraitNode → TraitTreeLoadout →
ChrSpecialization`), well over half the derived spells landed in `ALL`; with it, the 2026-09-20 run
puts 46 of 427 there and only 40 carry `classSource: "unknown"`.

A spell reachable by **seven or more** classes is emitted as `ALL` — the key
`defaults/Categories.lua` already uses for racials such as Shadowmeld. Real class abilities reach
one class, or two or three when a mask covers a shared tree; the things that reach many are racials,
trinkets and item effects. Nothing sits in between, so any threshold in the middle separates the two
populations cleanly, and seven is a simple majority of thirteen.

## Limitations — read these before accepting a diff (spec C7)

- **A CC with no mechanic flag will not be derived.** A scripted root, or an aura that only applies
  a movement-speed modifier, carries no `Mechanic` and no `EffectMechanic` and is invisible to this
  tool. The author's accept step stays a real judgment, not a rubber stamp — which is also why the
  diff's *Removed* section says so out loud rather than proposing deletions.
- **The player pool is broad by construction.** A derived list can contain a spell no player casts
  in practice. Removing it is a diff decision, and the bundle records the removal.
- **Bridged ids are name matches inside a shared spell family**, which is weaker evidence than a
  directed edge. Every one is labeled in all three outputs. Check them.
- **Pet crowd control is outside the pool.** Axe Toss (89766) and Seduction (6358) *are* in
  `SkillLineAbility`, with `ClassMask` 0 and a pet skill line — 761 and 931 for the felguard, 205 for
  the succubus — and the pool keeps a `ClassMask`-0 row only when its skill line is one of the
  thirteen **class** lines. That test is what keeps professions, mounts and racial trade skills out,
  and relaxing it to admit pet lines would admit all of those too. A warlock pet's stun is real CC on
  a real player frame, so this is a genuine gap rather than a definitional one; closing it means
  teaching the pool about pet skill lines specifically. Recorded in `SENTINELS_UNREACHABLE`.
- **Repentance (20066) is not reachable at all** on build 12.1.0.69875. The string `20066` does not
  occur in `SkillLineAbility`, `SpecializationSpells`, `TraitDefinition` or `TraitNodeEntry`, no
  `SpellEffect` row names it as an `EffectTriggerSpell`, and all eighteen spells named "Repentance"
  sit outside the pool. It carries mechanic 14 and is unquestionably a paladin ability, so the client
  grants it by a route none of the four pool sources describes. Recorded in `SENTINELS_UNREACHABLE`.
- **A handoff that also renames is invisible.** Earthbind Totem (2484) is in the pool but carries no
  mechanic, and the aura it lands is named "Earthbind" — so neither the mechanic match nor the family
  bridge, which needs an exact name match, can cross from the totem to its snare.
- **A trait outside any loadout's tree has no class** and falls to `ALL` with
  `classSource: "unknown"` in `derived.json`.
- **A new run needs network access.** wago.tools serves the exports. A past run replays offline
  with `--replay docs/spell-research/<date>`, which reads that bundle's `raw/*.csv.gz` directly
  and takes the build and the fetch time out of its `derived.json` rather than asking the builds
  API — a replay that re-resolved the build would stamp today's build number onto older bytes.
- **`wago.tools` rejects urllib's default User-Agent with HTTP 403.** Every request carries an
  identifying one. That is not a rate-limit workaround — the site serves the export happily.

## The bundle

`--bundle docs/spell-research/<YYYY-MM-DD>/` freezes a run, matching the `docs/audits/`,
`docs/reviews/` and `docs/automated-tests/` convention — a dated directory that is never edited
afterwards:

- `raw/*.csv.gz` — the exports the run actually read, and what `--replay` re-derives from
- `SOURCES.md` — build, fetch time, table list with source URLs, pool and bucket counts
- `derived.json` — every derived spell with its name, classes, matched mechanics, diminish type and
  whether it was bridged
- `DIFF.md` — the diff against the shipped lists

`docs` is already `.pkgmeta`-ignored, so none of it reaches a player. `ANALYSIS.md` — the write-up of
what was accepted and why — is written by hand beside them, as in every other bundle here.

## Combat-log evidence (`logs.py`)

`research.py` says which aura ids a spell *could* land; only the combat log says which one a given
spec actually gets. The owner's case: Offensive cooldowns listed Ascendance as `114051`, and
Restoration Shaman never receives that id; Restoration gets `114052`, so a container showing only
cooldowns drew nothing. `logs.py` mines the owner's combat logs for the aura ids **players** of
each spec apply, proposes corrections and additions for the `spells` categories of
`defaults/Categories.lua`, and applies only the ones the owner rules on. Design of record:
`docs/superpowers/specs/2026-09-24-spell-ids-from-combat-logs-design.md`.

The review is normally driven by the `/aura-spells-review` slash command
(`.claude/commands/aura-spells-review.md`): it runs `scan` and `propose` and points the owner at the
bundle's `REVIEW.csv`; the owner fills in the sheet's `decision` column and hands it back with
`/aura-spells-review apply <path>`, which runs `ingest`, the addon gates and the commit. The
subcommands also run on their own; `decide` and `apply` rule and apply one proposal at a time
instead of a sheet.

### The formula

An aura counts when it is **per spec, and cast by a player, not an NPC**: a
`SPELL_AURA_APPLIED` line whose source GUID starts `Player-` and whose source flags carry both the
player type bit (`0x400`) and the player-controlled bit (`0x100`). The spec comes from the source's
`COMBATANT_INFO` earlier in the same file. Before one arrives, the application goes under spec
`unknown` within the class if the class is known, and is otherwise counted as unattributed and
kept out of the per-spec dictionary. Pets, totems, guardians and creatures go to a separate
non-player tally, never into the evidence.

### Running it

```sh
# 1. Scan: stream every WoWCombatLog-*.txt in the folder (only logs not already cached) into
#    evidence.json. --logs defaults to the RaiderIO archive folder. About 20 minutes over 30 GB
#    the first time, and only the new logs after that.
python3 tools/spell-research/logs.py scan \
  --logs "/mnt/g/Games/Blizzard/World of Warcraft/_retail_/Logs/RaiderIOLogsArchive" \
  --out docs/spell-research/2026-09-24-logs/evidence.json

# 2. Propose: the dictionary and the review set, into the same bundle. --date is required and
#    never taken from the clock.
python3 tools/spell-research/logs.py propose --date 2026-09-24 \
  --bundle docs/spell-research/2026-09-24-logs

# 3. Ingest the filled review sheet: check it against the bundle's REVIEW.csv (by row_id, spell_id
#    and type; any mismatch, unknown row, unrecognized decision or unknown edited category fails
#    the whole run before anything is written), record each Approve/Reject in decisions.json by
#    row, apply the approved rows to defaults/Categories.lua and write the bundle's DECISIONS.md.
#    Blank decisions stay pending. A second ingest of the same sheet changes nothing.
python3 tools/spell-research/logs.py ingest --bundle docs/spell-research/2026-09-24-logs \
  --csv ~/REVIEW-filled.csv --date 2026-09-25

# Or, one proposal at a time: decide records one ruling on one proposal key (from the bundle's proposals.json). The only
#    writer of tools/spell-research/decisions.json. --ruling is accept, reject or move (with
#    --category: accept into a different category).
python3 tools/spell-research/logs.py decide --bundle docs/spell-research/2026-09-24-logs \
  --key 'replace|offensiveCDs|SHAMAN|ascendance|114052' --ruling accept --date 2026-09-24

# ... and apply rewrites the ruled class tables of defaults/Categories.lua and writes the bundle's
#    DECISIONS.md. Unruled proposals are left alone.
python3 tools/spell-research/logs.py apply --bundle docs/spell-research/2026-09-24-logs
```

The key given to `decide` is illustrative: copy the real one from `proposals.json` (it is also printed in
`CORRECTIONS.md` and `PROPOSED_ADDITIONS.md`), and quote it, since it contains `|`. Every
subcommand takes `--help`. `scan` and `propose` read the DB2 tables from `--db2-cache` (default
`tools/spell-research/.cache/`, the cache `research.py` fills; a missing table is downloaded).
`propose`, `decide`, `apply` and `ingest` take `--categories` and `--decisions` (and `propose` also
`--cast-to-aura`) to work on copies, which is what the tests do.

**`logs.py apply` and `logs.py ingest` are the only paths that write `defaults/Categories.lua`**,
and they write only what has a ruling in `decisions.json`. They edit just the class tables a ruling
touches and keep every other line as it was. An id they remove loses its line, and a class table
left empty is deleted (the table only: a comment line above it stays). An id they add gets its own
line at the end of its class table (a replace puts it where the old id was), aligned to the comment
column the neighboring lines use, with a same-line comment naming the spell and the bundle:
`114052,  -- Ascendance; added from the 2026-09-24 combat logs (SID)`, plus `; replaces 114051` for a
replace. A category without that class gets a new table in canonical class order. A legacy one-line
class entry is rewritten as a table when a ruling edits it: its ids keep their positional names when
the comment lines up (an aside in parentheses follows after a `;`), else take the name from the
proposal or sheet row, else have none, and a comment that did not line up is kept as a comment line
above the table. A second `apply` or `ingest` changes nothing. Run the addon's green gate after it,
as for any `Categories.lua` change.

### Thresholds

| What | Default | Where |
|---|---|---|
| Evidence bar for a proposal | ≥ 20 applications from ≥ 3 distinct players | `propose --min-apps`, `--min-players` |
| Group burst (target shape `group`) | the same caster and aura onto ≥ 5 distinct players within 1.0 s | `sid_scan.BURST_TARGETS`, `BURST_WINDOW` |
| Recast samples | at most 200 intervals per aura: seconds between one caster's successive casts (applications, and `SPELL_AURA_REFRESH`es onto another unit — never one on the caster, a proc re-trigger), onto any target; applications under 0.5 s apart are one cast | `sid_scan.RECAST_SAMPLE_CAP`, `RECAST_SAME_CAST` |
| External self-copy | the same caster's aura on itself and on exactly one other player within 0.1 s is one `single` application | `sid_scan.SELF_COPY_WINDOW` |
| Stale | not applied in the newest 60 days of the scanned range while a same-name sibling is | `sid_propose.DEFAULT_STALE_DAYS` |

Below the bar an aura is still in the dictionary, and reported in `FLAGS.md` when it is listed; it
is never proposed. A key already in `decisions.json`, accepted or rejected, is never proposed
again; a sheet row ruled by `ingest` (keyed `<proposal key>#<spell id>#<row type>`) is never put on
the sheet again, and a proposal whose rows are all ruled is not proposed again.

### Category rules

`sid_propose.suggest` reads one aura's class-wide evidence and DB2 facts; the first rule that
matches wins. R1 to R9 are the spec's table; R0 was added, and R8 lost its category, when the owner
dropped Consumables and added Group buffs, Stances and Racials (2026-09-25).

| Rule | When | Category | Confidence |
|---|---|---|---|
| R0 | DB2 puts the aura (or the cast that lands it: trigger edge or CastToAura) on a `Racial - <race>` skill line (`sid_db2.racial_auras`) | Racials | high |
| R1 | ≥ 90% self-applied, and DB2 says it reduces damage taken, absorbs or grants immunity | Defensive cooldowns | high |
| R2 | ≥ 30% of applications land in group bursts, and DB2 says it reduces damage taken, absorbs, heals over time or raises the group's haste | Raid cooldowns | high |
| R3 | ≥ 90% self-applied, DB2 says it raises damage, haste, critical strike or a stat, recast ≥ 60 s | Offensive cooldowns | high |
| R4 | DB2 says it raises movement speed | Movement | high |
| R5 | ≥ 70% of applications go to one other player | Support | medium |
| R6 | DB2 says it heals over time or absorbs, more than 50% onto others, recast < 30 s | Healing | medium |
| R7 | only tank specs apply it, ≥ 90% self-applied, recast < 30 s | Active mitigation | medium |
| R8 | not in the player-castable pool: an item or consumable effect | none (no proposal) | high |
| R9 | none of the above, with some self or single evidence | Utility | low |

The shares and recasts are `sid_propose`'s constants (`SELF_SHARE`, `GROUP_SHARE`, `SINGLE_SHARE`,
`OTHERS_SHARE`, `LONG_RECAST`, `SHORT_RECAST`). No rule proposes into Group buffs or Stances: their
lists are the owner's. Nothing is ever moved out of Racials, because the racial skill lines do not
reach every racial's aura (Stoneform 65116 and Fireblood 273104 are on none in build
12.1.0.69875), so R0 not matching a listed racial is no evidence it is misfiled.

### The artifacts

`propose` writes the bundle `docs/spell-research/<date>-logs/`, all of it committed:

- `evidence.json`: the merged per-spec evidence from `scan` (counts only).
- `dictionary/auras.json`, `auras.csv`, `AURAS.md`: every aura that matches the formula, one row
  per `(class, spec, aura type, spell id)`, whatever its count and whether or not it is in a
  category, with applications, distinct players, `self`/`single`/`group`/`other` shares, median
  recast, first and last seen, current category, and suggested category with its rule. `single`
  and `group` count player targets only; an application onto a pet, guardian, totem or NPC is
  `other`.
- `dictionary/non-player.csv`: the pet, totem and guardian tally.
- `CURRENT_CATEGORIES.md`: every shipped id of every `spells` category with its evidence status,
  one of confirmed, unverified, stale or wrong id.
- `CORRECTIONS.md`: replace, add and move proposals for listed ids.
- `PROPOSED_ADDITIONS.md`: new auras above the bar, grouped by recommended category, each with a
  rule and a one-sentence reason. Only high- and medium-confidence suggestions are proposed; a
  low-confidence one (R9 Utility) stays in the dictionary's `suggested_category` column. A racial
  (R0) is one proposal under class `ALL`, whichever classes applied it, its evidence and player
  counts summed across the classes; an item effect (R8) is never proposed. The summary line gives
  the counts before and after: candidates, dropped as low confidence, folded, already ruled,
  proposed.
- `FLAGS.md`: unverified and stale ids, below-the-bar sightings, and the crowd-control debuff
  cross-check (report only, never proposed).
- `SOURCES.md`: logs scanned, date range, bytes, skipped lines, DB2 build and thresholds.
- `proposals.json`: the review queue, corrections then additions, most-applied first.
- `REVIEW.csv`: the review sheet, UTF-8 with a byte-order mark so Excel opens it cleanly. One row
  per spell id per change (`correction-add`, `deletion`, `move`, `addition`): corrections first,
  most-applied first, then additions grouped by recommended category. A replace is a `deletion`
  row plus a `correction-add` row per new id, so each half is ruled on its own. Columns: `row_id`,
  `spell_id`, `spell_name`, `type`, `class`, `current_category`, `proposed_category` (editable),
  `specs`, `applications`, `players`, `context`, `confidence`, `proposal_key` and, last,
  `decision`, where the owner writes `Approve` or `Reject` (`A`/`R`, `Y`/`N` accepted).
- `REVIEW.md`: explains the sheet's columns, the decision values and how to hand it back.
- `DECISIONS.md`: written by `ingest` (every sheet row with its ruling) or by `apply` (this
  review's proposal rulings and the lines they changed).

The durable record of rulings is `tools/spell-research/decisions.json`.

### Privacy

No player name, realm or GUID reaches any output or committed file: the repo carries classes,
specs and counts only. Distinct-player counts stay exact across logs because the **per-log cache**
stores each aura's players as salted hashes (`sha256(salt + GUID)`, truncated), where the salt is
32 random bytes made once. The cache and the salt live outside the repo, in
`~/.cache/auramaster-spell-research/` (`scan --cache` to move it), and no hash ever enters a
bundle. A log is re-read when its size or modification time changes, so a log the client is still
writing is never served stale.

### The code

| File | Stage |
|---|---|
| `sid_scan.py` | Line parsing, the player filter, spec tracking, per-file aggregates, target shapes, recast |
| `sid_cache.py` | The per-log cache and the merge of per-file aggregates |
| `sid_db2.py` | DB2 signals per aura, the spec map, the player pool, the shipped categories, CastToAura candidates |
| `sid_propose.py` | Corrections, additions, flags, the category rules, the evidence bar, decisions suppression |
| `sid_artifacts.py` | The dictionary and the review set |
| `sid_review.py` | The review sheet: `REVIEW.csv` and `REVIEW.md`, and reading and checking a filled sheet |
| `sid_decide.py` | `decisions.json` (by proposal and by sheet row), `DECISIONS.md`, and the `Categories.lua` line rewriter |
| `logs.py` | The command line: `scan`, `propose`, `decide`, `apply`, `ingest` |

Tests: `python3 -m unittest discover -s tools/spell-research -p 'test_*.py'`, one `test_sid_*.py`
per module plus `test_sid_e2e.py`, the acceptance run: scan, propose, decide and apply through the
real command line on the fixtures in `fixtures/`, ending with `114052` in Offensive cooldowns, and
the sheet run: propose, fill `REVIEW.csv` (approve Ascendance's add, reject its deletion), ingest,
ending with both `114051` and `114052` listed.
