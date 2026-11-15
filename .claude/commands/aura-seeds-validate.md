---
description: Re-validate AuraMaster's Retail spell-category seed lists against the newest wago.tools build, rule what is new, and apply it
argument-hint: [commit] | [--build <version>]
---

# /aura-seeds-validate

Re-check every Retail `spells` seed list in `defaults/Categories_Retail.lua`, and
`defaults/CastToAura.lua`, against the live Retail build on wago.tools (product `wow`). Each
candidate and flag the build raises gets a ruling recorded as data, and the accepted ones are
applied. A re-run surfaces only what is new since the last ruled build. GitHub issue #27; the tool
is `tools/spell-research/retail.py`, documented in `tools/spell-research/README.md`, "Retail
re-validation". The first run is `docs/spell-research/2026-11-15-retail/`.

`$ARGUMENTS`:
- `--build <version>` pins a build instead of the newest live one.
- `commit` commits at the end. Without it the run stops before staging, and the owner commits.

Rules that hold throughout:

- **Only `retail.py apply` (and `logs.py`) writes `defaults/Categories_Retail.lua`**, and only
  for ruled ids. Never edit it, or `tools/spell-research/retail_rulings.json`, by hand: `retail.py
  rule` is the rulings file's only writer.
- **A candidate is a proposal, never a conclusion.** The DB2 rules are broad on purpose. NPC copies
  share player names, and passives and procs match the effect rules.
- **Follow the owner's precedent and never re-litigate it.**
  - A ruling already in `retail_rulings.json` stands.
  - So does a 2026-09-25 review-sheet ruling in `tools/spell-research/decisions.json` on the same id.
  - So do the curation notes in `defaults/Categories.lua` above `hardCC` (the starter-set rules,
    Wake of Ashes, the named exclusions).
- **The date is an argument, never the clock:** take `date +%F` once and use that `<date>` everywhere.

## 1. Preconditions and status

1. The working directory is the AuraMaster repo: `AuraMaster.toc` and
   `tools/spell-research/retail.py` both exist. Otherwise stop and say so.
2. The tree is clean (`git status --porcelain` prints nothing). Otherwise show it and stop.
3. `python3 tools/spell-research/retail.py status`:
   - `CURRENT <build> (<bundle>)` with no `--build`: the newest bundle already covers the live build.
     Say so and **stop**; there is nothing to do.
   - `NEW <build> ...`: continue with that build (or the pinned one).

## 2. Freeze the build and derive

```sh
python3 tools/spell-research/research.py --build <build> --bundle docs/spell-research/<date>-retail --date <date>
python3 tools/spell-research/retail.py derive --bundle docs/spell-research/<date>-retail --date <date>
```

The first downloads the tables (about 75 MB, cached in `tools/spell-research/.cache/`) and runs the
coverage gate. **If the gate fails, show the missing sentinels and stop**: the pipeline needs
fixing before anything is ruled (README, "The coverage gate"). `derive` diffs reach against the
newest earlier `*-retail` bundle. Report its per-category candidate counts, the flag count and the
unruled count.

## 3. Rule what is new

`python3 tools/spell-research/retail.py check --bundle docs/spell-research/<date>-retail` lists
every unruled key. For each one, read its candidate or flag in the bundle's `candidates.json`
(source, notes, class), and the spell's effects and cooldown in the build's tables. Where it helps,
also read `docs/spell-research/2026-09-24-logs/evidence.json`: whether players actually get the
aura, how many and which classes. Then rule:

- **Candidates** (`<category>:<id>`): `accept` or `reject`.
  - Accept an active ability's aura that a player of that class gets and would track in that
    category, filed where the owner files its kind (externals in Defensives, for example).
  - Reject passives, procs of the kind the owner rejected, ranks and variants of an id already
    shipped, NPC, item or delve copies under `ALL`, and anything in the wrong category.
  - If an id belongs in a different category than the one proposed, reject it here. Then add it to
    `HAND_CANDIDATES` in `retail.py` with its reason, re-run `derive`, and rule the new key.
- **Flags** (`shipped:<kind>:<category>:<id>`): `keep` or `remove`.
  - `unnamed` or `dropped` on an id: the build no longer has it, or players can no longer reach it.
    Remove it, unless the file's comment records why it is shipped by hand (Earthbind, Earthgrab).
  - `renamed`: check what the id is now. Fix the comment by hand if the spell is the same, or
    remove the id if it was reused.
  - `no-aura`: keep it only when the file already knows (issue #15).

Write every ruling, with a one-line reason, to a TSV in the scratchpad
(`key<TAB>ruling<TAB>reason`), then:

```sh
python3 tools/spell-research/retail.py rule --tsv <scratchpad>/rulings.tsv --bundle docs/spell-research/<date>-retail
python3 tools/spell-research/retail.py check --bundle docs/spell-research/<date>-retail   # must print OK
```

## 4. Report, apply, regenerate

```sh
python3 tools/spell-research/retail.py report --bundle docs/spell-research/<date>-retail --date <date>
python3 tools/spell-research/retail.py apply  --bundle docs/spell-research/<date>-retail --date <date>
python3 tools/spell-research/research.py --replay docs/spell-research/<date>-retail --emit-cast-aura --date <date> > defaults/CastToAura.lua
```

Run `report` before `apply`; README, "Ordering", says why.

Then:
- Roll `tests/test_categories_clients.lua`'s `RETAIL_SNAPSHOT` count and sum for every list that
  changed.
- Re-resolve any `defaults/Categories.lua:N` citation the docs suite flags.
- Write the bundle's `ANALYSIS.md` by hand, in the 2026-11-15 bundle's shape:
  - what changed between the builds;
  - what was proposed, accepted and rejected, and why;
  - what a later run should re-check.
- Add a smoke check per newly shipped ability to `docs/smoke-tests.md` and the *Pending sign-off*
  list, following FILT-65 to FILT-67.

## 5. Gate

```sh
lua tests/run.lua
KA0S_KIT_CLIENT=forever lua tests/run.lua
~/.claude/dev-copilot/bin/ka0s-bounded luacheck .
python3 -m pytest -q tools/spell-research
```

Every one must be green: 0 failed, and luacheck 0 / 0. **If any is red, show the output and stop
without committing.**

## 6. Hand back, and commit only if asked

Summarize: the build pair, what was accepted (per category, with ids), how many were rejected and
why in broad strokes, the flags and their rulings, and the CastToAura delta. Then:

- **Without `commit`:** stop. List the paths to stage: `defaults/Categories_Retail.lua`,
  `defaults/CastToAura.lua`, `tools/spell-research/retail_rulings.json`,
  `docs/spell-research/<date>-retail`, plus any test, smoke or citation edits.
- **With `commit`:** stage exactly those paths (never `-A`) and commit
  `Spell categories: Retail re-validation against <build> (<date>)`, with the summary as the body.
  Do not push.
