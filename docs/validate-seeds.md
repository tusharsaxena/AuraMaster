# Seed validation — Aura Master

The seed-validation contract `/dev-copilot:validate-seeds AuraMaster <flavor>` runs. The command
supplies the loop (clean tree, one date, status, derive, rule, apply, gate, hand-back) and its
standing rules. This file supplies Aura Master's procedure: the tools, the files they write, the
precedent a ruling follows and the nuances of each client. The headings below are the interface
the command reads, so keep their names.

Each run ends in a frozen bundle under `docs/spell-research/`. The tools are documented in
`tools/spell-research/README.md`. The Retail loop's first run is
`docs/spell-research/2026-11-15-retail/` (issue #27); the Forever lists' derivation is
`docs/spell-research/2026-11-14-forever/`.

## Flavors

| Flavor | Source | Seed files | Tools |
| --- | --- | --- | --- |
| `retail` | wago.tools product `wow` (Retail live) | `defaults/Categories_Retail.lua` (hand-curated, tool-checked), `defaults/CastToAura.lua` (generated) | `tools/spell-research/research.py`, `retail.py` |
| `forever` | wago.tools product `wowf` (WoW Forever) | `defaults/Categories_Forever*.lua`, `defaults/CastToAura_Forever.lua` (both generated, never hand-edited) | `tools/spell-research/research.py --client forever`, `forever.py` |

## Rules

- **Only the tools write the seed files.**
  - `defaults/Categories_Retail.lua` is written by `retail.py apply`, and by `logs.py apply` and
    `ingest` for the combat-log review (`/aura-spells-review`).
  - `defaults/Categories_Forever*.lua` and `defaults/CastToAura_Forever.lua` are written only by
    `forever.py emit`.
  - Never edit any of them by hand. The one exception is a comment that the `renamed` flag below
    says to fix.
- **Rulings are data.** Retail's rulings live in `tools/spell-research/retail_rulings.json`, written
  only by `retail.py rule`. Forever's live in `tools/spell-research/forever_rulings.json`, written
  only by `forever.py rule`. A ruling is keyed `<category>:<id>`, or `shipped:<kind>:<category>:<id>`
  for a Retail flag, and never by build. It holds until the thing it ruled on stops being proposed.
- **Precedent, in this order, never re-litigated:**
  1. a ruling already in the flavor's rulings file;
  2. the owner's 2026-09-25 combat-log review rulings in `tools/spell-research/decisions.json` on
     the same id (row keys carry the id between `#` marks);
  3. the curation notes in `defaults/Categories.lua`, especially the one above `hardCC`:
     - rule 1, one id per ability;
     - rule 2, every class's signature CC;
     - rule 3, the long tail is the curator's call;
     - Wake of Ashes, which the owner removed;
     - the named encounter and trinket exclusions;
     - the Earthbind and Earthgrab auras, which ship by hand;
  4. each category's own note: Active mitigation excludes Blood Shield, Shuffle and Rushing Jade
     Wind; Racials leaves out passives; Defensives holds externals such as Pain Suppression,
     Ironbark and Blessing of Sacrifice.
- **What "accept" means here.** Accept the aura id an active ability puts on a unit, when a player
  of that class gets it and would track it in that category. The filter matches the **aura's** id,
  never the cast's (`tools/spell-research/README.md`, "The crux").
- **What to reject.**
  - Passives, and procs of the kind the owner rejected (Felfire Haste, Pretense of Instability).
  - Ranks and variants of an id already shipped.
  - Item, delve and NPC copies under `ALL`.
  - Shadowlands covenant leftovers.
  - Anything in the wrong category: a heal is not an offensive cooldown, and a channel is not a
    stance.
- **Evidence.** Read each candidate's effects and cooldown on the build (the bundle's
  `raw/*.csv.gz`). For Retail, also read `docs/spell-research/2026-09-24-logs/evidence.json`
  (`auras[]`: `spellId`, `class`, `auraType`, `players`, `applications`, `self`, `group`). It shows
  whether real players get the aura at all; an aura nobody got in 102 million log lines is a reject
  unless it is a class's signature ability.
- **Privacy.** No player name, realm or GUID goes into a bundle, a ruling or a commit.

## Flavor: retail

### Status

```sh
python3 tools/spell-research/retail.py status
```

Prints `CURRENT <build> (<bundle>)`, or `NEW <build> (last ruled <build>, <bundle>)`.

### Freeze and derive

```sh
python3 tools/spell-research/research.py --build <build> --bundle docs/spell-research/<date>-retail --date <date>
python3 tools/spell-research/retail.py derive --bundle docs/spell-research/<date>-retail --date <date>
```

The first command downloads about 75 MB on a new build (cached in `tools/spell-research/.cache/`)
and runs the coverage gate of 71 Retail sentinels. **If the gate fails, stop**: the pipeline needs
fixing, and bending `BUCKET_MECHANICS` until it passes is forbidden (README, "The coverage gate").
`derive` diffs reach against the newest earlier `*-retail` bundle, or `--previous <bundle>`.
Report the per-category candidate counts, the flag count and the unruled count.

### Rule

```sh
python3 tools/spell-research/retail.py check --bundle docs/spell-research/<date>-retail
python3 tools/spell-research/retail.py rule --tsv <scratchpad>/rulings.tsv --bundle docs/spell-research/<date>-retail
```

`check` lists every unruled key, and must print `OK` after `rule`.

- **Candidates** (`accept` or `reject`). Their sources:
  - `cc-mechanic` and `bridge`: the CC buckets;
  - `db2-effect`: the shared `sid_seeds.DB2_RULES`;
  - `hand`: `HAND_CANDIDATES` in `retail.py`.

  An id that belongs in a different category than the one proposed is rejected here. Then add it
  to `HAND_CANDIDATES` with its reason, re-run `derive`, and rule the new key.
- **Flags** (`keep` or `remove`):
  - `unnamed` or `dropped`: the build no longer has the id, or players can no longer reach it.
    Remove it, unless the file's comment records why it ships by hand.
  - `renamed`: check what the id is now. If the spell is the same, fix its comment by hand. If the
    id was reused, remove it.
  - `no-aura`: keep it only when the file already knows (35546 Fatal Flourish, issue #15).

### Apply

```sh
python3 tools/spell-research/retail.py report --bundle docs/spell-research/<date>-retail --date <date>
python3 tools/spell-research/retail.py apply  --bundle docs/spell-research/<date>-retail --date <date>
python3 tools/spell-research/research.py --replay docs/spell-research/<date>-retail --emit-cast-aura --date <date> > defaults/CastToAura.lua
```

`report` comes before `apply`. Once an id has been applied, a re-derive no longer proposes it, so
`RULINGS.md` has to be written while the run's candidates still include it. `apply` refuses while
anything is unruled, and a second `apply` changes nothing.

### After

- Roll `tests/test_categories_clients.lua`'s `RETAIL_SNAPSHOT` (the count and the sum) for every
  list that changed.
- Re-resolve every `defaults/Categories.lua:N` citation that the docs suite flags.
- Roll the `RE-VALIDATED AGAINST BUILD` note above `Cat.HARMFUL` in `defaults/Categories.lua`.
- Write the bundle's `ANALYSIS.md` by hand, in the 2026-11-15 bundle's shape:
  - what changed between the builds;
  - what was proposed, accepted and rejected, and why;
  - what a later run should re-check.
- Add a smoke check per newly shipped ability to `docs/smoke-tests.md`'s Filters section, plus its
  *Pending sign-off* note, following FILT-65 to FILT-67. A run that ships nothing new adds none.

### Stage

`defaults/Categories_Retail.lua`, `defaults/CastToAura.lua`, `defaults/Categories.lua` (the note),
`tools/spell-research/retail_rulings.json`, `docs/spell-research/<date>-retail`,
`tests/test_categories_clients.lua`, `docs/smoke-tests.md`, plus any citation edits. Commit message:
`Spell categories: Retail re-validation against <build> (<date>)`.

## Flavor: forever

### Status

```sh
python3 tools/spell-research/forever.py status
```

Prints `CURRENT <build> (<bundle>)` or `NEW <build> (...)`, comparing the live `wowf` build with the
newest `*-forever` bundle.

### Freeze and derive

```sh
python3 tools/spell-research/research.py --client forever --build <build> --bundle docs/spell-research/<date>-forever --date <date>
python3 tools/spell-research/forever.py derive --bundle docs/spell-research/<date>-forever --date <date>
```

The coverage gate checks Forever's own sentinels (`SENTINELS_FOREVER`). **If it fails, stop.**
`derive` maps every Retail entry by name to the same class's Forever spells, every rank. It adds
the DB2 effect candidates and `HAND_CANDIDATES` in `forever.py`. It reports the candidate counts,
the unruled count, stale rulings and the Retail entries left unmapped.

### Rule

```sh
python3 tools/spell-research/forever.py rule --tsv <scratchpad>/rulings.tsv --bundle docs/spell-research/<date>-forever
```

Rulings are `accept` or `reject`. The unruled keys are the ones `emit` refuses on (below); list them
by running `emit` once, which refuses and prints each.

Nuances:

- **Every rank ships.** An aura filter matches one id, and vanilla keeps each rank as its own.
- **Retail-only class keys never appear** (`DEATHKNIGHT`, `MONK`, `DEMONHUNTER`, `EVOKER`).
- **The rune skill lines are excluded** (owner ruling of 2026-11-14).
- **A name match is a candidate.** NPC copies share a player spell's name and family.
- **No Forever combat logs exist yet** (issue #26). The evidence is the build's data alone, so
  say so in the reason wherever a ruling would otherwise lean on logs.

### Apply

```sh
python3 tools/spell-research/forever.py emit --bundle docs/spell-research/<date>-forever --date <date>
```

`emit` writes `defaults/Categories_Forever*.lua` (split so that no file passes 1400 lines),
`defaults/CastToAura_Forever.lua` and the bundle's `RULINGS.md`, and refuses while anything is
unruled. A category left with nothing goes into `NS.CategorySeedsForever.EMPTY` and is gated off on
Forever with no code change. Say so in the hand-back whenever `EMPTY` changes.

### After

- Write the bundle's `ANALYSIS.md` by hand, in the 2026-11-14 bundle's shape.
- Add a FOREVER smoke check for any newly ungated or newly empty category, plus its *Pending
  sign-off* note.
- If a TOC load line changed (a new numbered part), update `tests/test_loadorder.lua`.

### Stage

`defaults/Categories_Forever*.lua`, `defaults/CastToAura_Forever.lua`,
`tools/spell-research/forever_rulings.json`, `docs/spell-research/<date>-forever`, plus any TOC,
test, smoke or citation edits. Commit message:
`Spell categories: Forever re-validation against <build> (<date>)`.

## Gate

```sh
~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua
KA0S_KIT_CLIENT=forever ~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua
~/.claude/dev-copilot/bin/ka0s-bounded luacheck .
python3 -m pytest -q tools/spell-research
```

luacheck must report 0 warnings and 0 errors, and every suite 0 failed.

## Notes

- **Bundle size.** A Retail bundle's `raw/` is about 24 MB, because the DB2 rules read `Spell` and
  `SpellMisc` alongside research.py's tables. One bundle per patch is acceptable.
- **Combat-log evidence ages.** The 2026-09-24 evidence predates later patches. A new Retail
  ability has no log rows until `/aura-spells-review` runs again, so for one, the build's data and
  the class's design are the evidence. Say so in the reason.
- **A ruling outlives its candidate.** After `apply`, an accepted id stops being proposed. Its
  ruling stays in the file as provenance, and that is not an error.
