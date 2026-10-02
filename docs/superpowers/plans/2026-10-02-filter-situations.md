# Filter situations: implementation plan

> Run as Workflow orchestration (ultracode): each task has one implementer and then one independent
> reviewer (up to two fix rounds), a final multi-lens review with adversarial verification, and then a
> checkpoint. Tasks run in order, because they share files.

**Goal:** per-container NPC / player behavior where spell lists don't apply (default "Every aura,
once"), per-container zones (all on), on a new last Filters tab, Situations.

**Spec:** `docs/superpowers/specs/2026-10-02-filter-situations-design.md` (binding).
**Branch:** `feat/2026-10-02-filter-situations`, from `master` at `5b6c9f2`, in the main AuraMaster
tree, so every pushed milestone can be tested in game.

## Rules for every task

- test-first, with a true `-- red under:` note on each case;
- the green gate before every commit: `lua tests/run.lua`, and luacheck at 0/0 through `ka0s-bounded`;
- no function above CCN 15 (the kit's sighted complexity suite, its bundle deleted after);
- no authored Lua file past 1500 lines; a file crossing 1000 gets the new code in its own module;
- `docs/test-cases.md` regenerated, and the README badge updated, with any case change;
- doc citations fixed in the same commit that moves the lines they point at;
- CRLF line endings kept; US spelling; mock changes only in `tests/wow_mock.lua`;
- a commit subject starts with `<ID>: ` and the message ends with the session trailers;
- no merge, no version bump and no tag; push the branch at milestone checkpoints only.

## Items

| ID | Milestone | Title | Done when |
|---|---|---|---|
| SI-00 | M0 | This design and plan, the design inputs | commit `SI-00:` |
| SI-01 | M1 | Compiler: `group.views` (blizzard, every), the remainder slot (S1) | compiler cases green; the owner's profile proves ids and blizzard views unchanged |
| SI-02 | M1 | Settings data: `filter.situations`, `filter.zones` in the template, the schema backfill, Copy / Duplicate / Defaults (S5) | schema and copy cases green |
| SI-03 | M2 | Runtime: three-way `ResolveView` with `Compat.IsPlayerUnit`, the `view` effect, EmptyWatch on `inst.view`, the `[Filter]` line and diagnostics (S2) | runtime cases green |
| SI-04 | M2 | Zones: `Compat.InstanceType`, the zone gate in `ShouldShow`, the two events with stand-down release, the first pass, followers (S3) | zone cases green; stand-down census holds |
| SI-05 | M2 | The Situations tab, last; NOTE lines; README usage and FAQ; docs; smoke checks (S4) | settings cases, test_docs, test_prose green |
| SI-06 | M3 | Whole-branch review (lenses: engine semantics vs Blizzard's source, runtime and combat legality, migration and settings, tests, docs and UI), adversarial verification, fixes | review note on HEAD |
| SI-07 | M3 | Full battery (sharded and `-j 1`, luacheck, complexity, perf.lua, file caps, inventory), checkpoint row, push | row in `2026-10-02-filter-situations.checkpoints.tsv`; origin equals HEAD |

Checkpoints: M1 and M2 end with the gate, a checkpoint row and a push of the branch.

## Resume

1. Work in `../AuraMaster` on `feat/2026-10-02-filter-situations`. If the tree is dirty, read it before
   doing anything else.
2. Done items: `git log --format=%s master..HEAD | grep -oE '^SI-[0-9]+'`. Reviewed items carry a
   `refs/notes/ka0s-review` note starting `OK SI-NN`. The next item is the first id with no commit.
3. Smoke checks are the owner's. Never mark one passed.
4. After the owner's merge go-ahead and the merge: delete the branch (local and origin), and any stash
   or worktree this run made.
