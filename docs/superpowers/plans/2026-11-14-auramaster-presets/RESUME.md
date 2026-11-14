# Resuming the Aura Master presets run

Plan: `../2026-11-14-auramaster-presets.md`. Spec: `../../specs/2026-11-14-auramaster-presets-design.md`.
Git is the only state.

1. Run `./resume-state.sh -v`. It lists what has landed (a commit subject opening `<ID>: ` on the run branch or master)
   and the next items to work on.
2. If the tree is dirty, read the diff before doing anything. Continue the work or stash it, and never `reset --hard`
   or `checkout .` work you have not read.
3. Work in order: M1 (AM-PR01..03), then M2 (AM-PR04, then AM-PR05 and AM-PR06), then M3. Each item's gate is in the
   plan's Global Constraints.
4. At each milestone, re-run the gate, append a `checkpoints.tsv` row (commits and test totals) and push the branch.
   Only the lead session pushes.
5. The smoke is the owner's (`docs/smoke-tests.md`, the PRESETS theme). Merge only on the owner's go-ahead, after the
   Forever port branch it was cut from; then delete the run branches, stashes and worktrees.

## Log

- 2026-11-14: Design approved by the owner (spec, with the builder check folded in). Baseline: retail 2377/0/1,
  forever 2376/0/2, lint 0/0.
