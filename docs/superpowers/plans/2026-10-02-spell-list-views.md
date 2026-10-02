# Spell-list views: implementation plan

> Run as Workflow orchestration (ultracode): each task has one implementer and then one independent
> reviewer, a final multi-lens review with adversarial verification, and then a checkpoint. Tasks
> run in order, because they share files.

**Goal:** no aura is drawn twice where Blizzard drops spell ids; there, only Blizzard categories set to
Show draw, and the settings and README say so.

**Spec:** `docs/superpowers/specs/2026-10-02-spell-list-views-design.md` (binding).
**Branch:** `feat/2026-10-02-spell-list-views`, from `master` at `9094fe3`. Worked in its own git
worktree because `feat/2026-10-02-libka0s-census-adoption` was in flight in the main tree; the two
branches touch different code and meet only in generated docs (`docs/test-cases.md`, the README badge,
`docs/smoke-tests.md`), which are regenerated at whichever merge lands second.

## Rules for every task

- test-first, with a true `-- red under:` note on each case;
- the green gate before every commit: `lua tests/run.lua`, and luacheck at 0/0 through `ka0s-bounded`;
- lizard at or below CCN 15 on touched files, through the kit's sighted complexity suite;
- no authored file past 1500 lines; a file crossing 1000 gets its peel tracked (layout-§1) or the new
  code goes in its own file;
- `docs/test-cases.md` regenerated, and the README badge updated, with any case change;
- doc citations fixed in the same commit that moves the lines they point at;
- CRLF line endings kept; US spelling;
- mock changes only in `tests/wow_mock.lua`;
- a commit subject starts with `<ID>: ` and the message ends with the session trailers;
- no merge, no version bump and no tag; push the branch at checkpoints only.

## Items

| ID | Milestone | Title | Done when |
|---|---|---|---|
| SV-00 | M0 | This design and plan | commit `SV-00:` |
| SV-01 | M1 | FilterCompiler: `FC.IdsMode`, each group's `noIds` view (V1), the reworded warnings (V4 first bullet); `IdsAlwaysHonored` callers moved | the spec's FilterCompiler cases green, the owner's container pinned |
| SV-02 | M1 | `NS.Compat.IdsApply` (V2), `ContainerClass:ApplyView`, Build and Update on the active view, the view debug line | Container and Compat cases green |
| SV-03 | M1 | Wiring: `OnUnitSwap` applies the view before `Refresh`; `UNIT_FACTION` / `UNIT_FLAGS` for target and focus; teardown on stand-down; EmptyWatch on the active view and `IdsApply` (V3); diagnostics | events and EmptyWatch cases green; the stand-down census holds |
| SV-04 | M2 | Settings: the Categories and Overrides NOTE lines; README usage and FAQ; `docs/midnight-quirks.md`, ARCHITECTURE, the FilterCompiler header comment; smoke checks | test_docs and test_prose green; no stale "accepted residual" claim left |
| SV-05 | M3 | Whole-branch review against master (lenses: engine semantics against Blizzard's source, runtime and combat legality, tests, docs and UI text), adversarial verification, fixes | review note on HEAD |
| SV-06 | M3 | Full battery (sharded and `-j 1`, luacheck, sighted lizard on the whole repo, perf.lua), a checkpoint row, push | row in `2026-10-02-spell-list-views.checkpoints.tsv`; origin equals HEAD |

## Resume

1. Work on `feat/2026-10-02-spell-list-views` (the worktree, or `../AuraMaster` once the census
   branch has merged). If the tree is dirty, read it before doing anything else.
2. Done items: `git log --format=%s master..HEAD | grep -oE '^SV-[0-9]+'`. The next item is the first
   id with no commit.
3. Smoke checks are the owner's. Never mark one passed.
