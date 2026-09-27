# Font primer: implementation plan

> Run as Workflow orchestration (ultracode): each task has one implementer and then one independent
> reviewer, a final multi-lens review with adversarial verification, and then a checkpoint. Tasks
> run in order, because they share files.

**Goal:** remove the NameRepaint workaround and add a font primer, so no container text is ever
first drawn in a font that has not loaded yet (issue #24).

**Spec:** `docs/superpowers/specs/2026-09-27-font-primer-design.md` (binding).
**Branch:** `fix/2026-09-27-blank-bar-names`, continuing from `e38768a` (NR-07). The earlier plan,
`2026-09-27-blank-bar-names.md`, is frozen as the record.

## Rules for every task

The same rules as the frozen plan's "Rules for every task":

- test-first, with a true `-- red under:` note on each case;
- the green gate before every commit: `lua tests/run.lua`, and luacheck at 0/0 through `ka0s-bounded`;
- lizard at or below CCN 15 on touched files;
- `docs/test-cases.md` regenerated, and the README badge updated, with any case change;
- doc citations fixed in the same commit that moves the lines they point at;
- CRLF line endings kept;
- US spelling;
- mock changes only in `tests/wow_mock.lua`;
- a commit subject starts with `<ID>: ` and the message ends with the session trailers;
- no merge, no version bump and no tag; push the branch at checkpoints only.

## Items

| ID | Milestone | Title | Done when |
|---|---|---|---|
| FP-00 | M0 | Findings correction, this design and plan | commit `FP-00:` |
| FP-01 | M1 | Remove NameRepaint and everything that exists only for it (spec P1), with the suite green | no `NameRepaint`, `nameRepaint` or `ShowsEngineName` left outside the frozen spec, plan and findings; perf.lua green |
| FP-02 | M1 | `modules/FontPrimer.lua` (P2) with `tests/test_fontprimer.lua`, and wiring in CM.StartListening, the CONFIG_CHANGED handler and CM.StopListening | the spec's Testing cases green; test_disabled census holds |
| FP-03 | M2 | Diagnostics line and trace (P3); docs (P4), including new FP smoke checks replacing the BN ones | test_docs and test_prose green; no stale repaint claims left in docs/ or comments |
| FP-04 | M3 | Whole-branch review against master (lenses: runtime, standards, tests, docs), adversarial verification, fixes | review note on HEAD |
| FP-05 | M3 | Full battery (sharded and `-j 1`, luacheck, lizard on the whole repo, perf.lua), a checkpoint row, push | row in `2026-09-27-font-primer.checkpoints.tsv`; origin equals HEAD |

## Resume

1. Work in `../AuraMaster` on `fix/2026-09-27-blank-bar-names`. If the tree is dirty, read it before
   doing anything else.
2. Done items: `git log --format=%s e38768a..HEAD | grep -oE '^FP-[0-9]+'`. The next item is the first
   id with no commit.
3. Smoke checks are the owner's. Never mark one passed.
