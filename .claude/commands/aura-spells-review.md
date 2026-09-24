---
description: Review combat-log evidence for AuraMaster's spell categories and apply the owner's rulings
argument-hint: [logs-folder]
---

# /aura-spells-review

Mine the owner's combat logs for the aura ids players of each spec actually apply, propose
corrections to `defaults/Categories.lua`'s `spells` categories and additions to them, ask the owner
about each proposal one at a time, and apply only what the owner rules. Design of record:
`docs/superpowers/specs/2026-09-24-spell-ids-from-combat-logs-design.md`; the tool is
`tools/spell-research/logs.py` (documented in `tools/spell-research/README.md`, "Combat-log
evidence").

Rules that hold throughout:

- **`logs.py apply` is the only writer of `defaults/Categories.lua`**, and it applies only rulings
  recorded in `tools/spell-research/decisions.json`. Never edit either file by hand.
- **Every ruling goes through `logs.py decide`.** Never hand-edit `decisions.json`.
- **No player name, realm or GUID** goes into anything you write, show in a commit or paste into
  the conversation. The bundle carries only classes, specs and counts.
- Arguments: `$ARGUMENTS` is the logs folder. When it is empty, use the default,
  `/mnt/g/Games/Blizzard/World of Warcraft/_retail_/Logs/RaiderIOLogsArchive`.

## 1. Preconditions

1. Confirm the working directory is the AuraMaster repo: `AuraMaster.toc` and
   `tools/spell-research/logs.py` both exist at the root. If not, stop and say so.
2. Confirm the tree is clean: `git status --porcelain` prints nothing. If it does not, show it and
   stop; the review commits at the end and must not sweep up unrelated work.
3. Take today's date once, `date +%F`, and use that same `<date>` for every step below. The bundle
   is `docs/spell-research/<date>-logs`.

## 2. Scan and propose

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

If either command exits non-zero, show its output and stop.

**Resuming a review started earlier today:** if `docs/spell-research/<date>-logs/proposals.json`
already exists and `decisions.json` already holds rulings for some of its keys, do **not** re-run
`propose` (it drops ruled keys from the queue, and `apply` then could not apply them). Skip straight
to step 4 and walk only the keys that `decisions.json` does not yet hold.

## 3. Tell the owner what there is

From `propose`'s output, give the counts of corrections, additions and flags, and the paths:

- the dictionary: `docs/spell-research/<date>-logs/dictionary/AURAS.md` (and `auras.csv`);
- the review set: `CORRECTIONS.md`, `PROPOSED_ADDITIONS.md`, `FLAGS.md`, `CURRENT_CATEGORIES.md`,
  `SOURCES.md` in the bundle.

Flags are report-only; they are never asked about. The dictionary is never reviewed item by item.

## 4. Walk the proposals, one at a time

Read `docs/spell-research/<date>-logs/proposals.json`. Its `proposals` list is already in review
order: corrections first (`section: "correction"`, types `replace` / `add` / `move`), then additions
(`section: "addition"`), each most-applied first. For each proposal whose `key` is not already in
`tools/spell-research/decisions.json`:

1. Show it in a few lines: the type, the category (and `from_category` for a move), the class and
   spell name, the listed ids and the proposed ids, the evidence per id and spec (`applications /
   players`), the rule, the reason and the confidence. Keep it to what `proposals.json` says.
2. Ask with **AskUserQuestion**, one question, three options:
   - **Accept** — the proposal as written.
   - **Change category** — then ask a second question for the category, offering the `spells`
     categories of `defaults/Categories.lua` (the keys `CURRENT_CATEGORIES.md` lists, e.g.
     `offensiveCDs`, `defensives`, `raidCDs`).
   - **Reject** — then ask for an optional reason (the owner may leave it blank). A rejected key is
     never proposed again.
   The owner may also answer **stop here**: the rulings made so far are saved, and the rest stay
   pending for the next run. Go to step 5.
3. Record the answer **immediately**, before showing the next proposal:

   ```sh
   # Accept
   python3 tools/spell-research/logs.py decide --bundle docs/spell-research/<date>-logs \
     --key '<key>' --ruling accept --date <date>
   # Change category
   python3 tools/spell-research/logs.py decide --bundle docs/spell-research/<date>-logs \
     --key '<key>' --ruling move --category <categoryKey> --date <date>
   # Reject
   python3 tools/spell-research/logs.py decide --bundle docs/spell-research/<date>-logs \
     --key '<key>' --ruling reject --reason '<reason>' --date <date>
   ```

   Quote the key: it contains `|`. If `decide` exits non-zero, show the message and ask again.

## 5. Apply and gate

If the owner made no ruling at all this session, there is nothing to apply or commit: say so and
stop (the bundle stays uncommitted in the working tree for the next run to reuse).

```sh
python3 tools/spell-research/logs.py apply --bundle docs/spell-research/<date>-logs
```

It prints each line change and writes `DECISIONS.md` into the bundle. Then run the addon gates
through the bounded runner:

```sh
/home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .
/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua5.1 tests/run.lua
```

luacheck must report 0 warnings / 0 errors and the suite 0 failed. **If either is red, show the
output and stop without committing**; the owner decides what happens next.

## 6. Commit

Before staging, check the bundle holds no `Player-` string:
`grep -rl 'Player-' docs/spell-research/<date>-logs` must print nothing.

Stage exactly these paths and commit:

```sh
git add defaults/Categories.lua tools/spell-research/decisions.json docs/spell-research/<date>-logs
git commit -m "Spell categories: apply combat-log rulings (<date>)"
```

The body lists the counts (accepted, moved, rejected, still pending) and the line changes `apply`
printed. Do not push.
