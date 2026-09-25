---
description: Review combat-log evidence for AuraMaster's spell categories by review sheet, and apply the owner's rulings
argument-hint: [logs-folder] | apply <filled REVIEW.csv>
---

# /aura-spells-review

Mine the owner's combat logs for the aura ids players of each spec actually apply, propose
corrections to `defaults/Categories.lua`'s `spells` categories and additions to them, and hand the
owner **one review sheet**, `REVIEW.csv`, to rule on in a spreadsheet. When the owner hands the
filled sheet back, apply it in one shot. Design of record:
`docs/superpowers/specs/2026-09-24-spell-ids-from-combat-logs-design.md` (and the plan's addendum,
"review by spreadsheet"); the tool is `tools/spell-research/logs.py` (documented in
`tools/spell-research/README.md`, "Combat-log evidence").

The command has two modes, chosen by `$ARGUMENTS`:

- **Propose** (`$ARGUMENTS` empty or a logs folder): steps 1 to 3, then stop and wait for the
  owner. When the folder is empty, use the default,
  `/mnt/g/Games/Blizzard/World of Warcraft/_retail_/Logs/RaiderIOLogsArchive`.
- **Apply** (`$ARGUMENTS` is `apply <path>`, the owner's filled copy of `REVIEW.csv`): steps 1, 4,
  5 and 6.

Rules that hold throughout:

- **Only `logs.py ingest` (or `logs.py apply`) writes `defaults/Categories.lua`**, and only for
  rulings recorded in `tools/spell-research/decisions.json`. Never edit either file by hand.
- **Rulings come from the owner's sheet, through `logs.py ingest`.** Never hand-edit
  `decisions.json`, and never fill in a decision the owner did not write.
- **No player name, realm or GUID** goes into anything you write, show in a commit or paste into
  the conversation. The bundle carries only classes, specs and counts.

## 1. Preconditions

1. Confirm the working directory is the AuraMaster repo: `AuraMaster.toc` and
   `tools/spell-research/logs.py` both exist at the root. If not, stop and say so.
2. Confirm the tree is clean apart from the bundle this review writes: `git status --porcelain`
   prints nothing, or (apply mode) only paths under `docs/spell-research/`. Otherwise show it and
   stop; the review commits at the end and must not sweep up unrelated work.
3. Take today's date once, `date +%F`, and use that same `<date>` for every step below.
   - Propose mode: the bundle is `docs/spell-research/<date>-logs`.
   - Apply mode: the bundle is the one the sheet came from, the newest
     `docs/spell-research/*-logs/` holding a `REVIEW.csv` (ask the owner if more than one could
     be meant). `<date>` is still today's: it is the rulings' date.

## 2. Scan and propose (propose mode)

Run the scan **in the background** (the first run over the full archive takes about 20 minutes;
later runs read only the logs that are new or changed since, from the per-log cache in
`~/.cache/auramaster-spell-research/`):

```sh
python3 tools/spell-research/logs.py scan \
  --logs "<logs folder>" \
  --out docs/spell-research/<date>-logs/evidence.json
```

The DB2 tables come from `tools/spell-research/.cache/` (`--db2-cache` to point elsewhere); a
missing table is downloaded once. When the scan finishes, report its summary line (logs, MB, lines,
skipped, unattributed), then:

```sh
python3 tools/spell-research/logs.py propose --date <date> --bundle docs/spell-research/<date>-logs
```

If either command exits non-zero, show its output and stop. Rows the owner already ruled in an
earlier sheet are not on the new one (a rejected row is never asked again).

## 3. Hand the owner the sheet, and stop (propose mode)

From `propose`'s output, give the counts of corrections, additions and flags, and the paths:

- **the review sheet: `docs/spell-research/<date>-logs/REVIEW.csv`**, explained in `REVIEW.md`
  beside it: one row per spell id per change; the owner writes `Approve` or `Reject` (`A`/`R`,
  `Y`/`N`) in the last column, `decision`, may overwrite `proposed_category` with another category
  key or label, and leaves a row blank to keep it pending. A replace is a `deletion` row plus a
  `correction-add` row per new id, ruled independently.
- the dictionary: `docs/spell-research/<date>-logs/dictionary/AURAS.md` (and `auras.csv`);
- the review set: `CORRECTIONS.md`, `PROPOSED_ADDITIONS.md`, `FLAGS.md`, `CURRENT_CATEGORIES.md`,
  `SOURCES.md` in the bundle.

Tell the owner to save the filled sheet as CSV (UTF-8) and hand it back with
`/aura-spells-review apply <path>`. **Then stop.** Do not ask about the rows one by one, and do
not commit: the bundle stays in the working tree until the sheet comes back.

## 4. Ingest the filled sheet (apply mode)

```sh
python3 tools/spell-research/logs.py ingest --bundle docs/spell-research/<bundle date>-logs \
  --csv '<path>' --date <date>
```

It checks the sheet against the bundle's `REVIEW.csv` by `row_id`, `spell_id` and `type`, records
every Approve/Reject in `decisions.json` (one entry per row), applies the approved rows to
`defaults/Categories.lua`, writes `DECISIONS.md` into the bundle, and prints each line change and
a summary (approved, rejected, pending, line changes). If it exits non-zero (an unknown or
mismatched row, an unrecognized decision value, an edited category that is not a `spells` category
key or label), nothing was written: show its message, ask the owner to fix the sheet, and stop.

If the sheet ruled nothing (every decision blank), there is nothing to apply or commit: say so and
stop.

## 5. Gate (apply mode)

Run the addon gates through the bounded runner:

```sh
/home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .
/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua5.1 tests/run.lua
```

luacheck must report 0 warnings / 0 errors and the suite 0 failed. **If either is red, show the
output and stop without committing**; the owner decides what happens next.

## 6. Commit (apply mode)

Before staging, check the bundle holds no `Player-` string:
`grep -rl 'Player-' docs/spell-research/<bundle date>-logs` must print nothing. The owner's filled
sheet is not committed; the rulings live in `decisions.json` and `DECISIONS.md`.

Stage exactly these paths and commit:

```sh
git add defaults/Categories.lua tools/spell-research/decisions.json docs/spell-research/<bundle date>-logs
git commit -m "Spell categories: apply combat-log review sheet (<date>)"
```

The body lists the counts `ingest` printed (approved, rejected, pending) and its line changes. Do
not push.
