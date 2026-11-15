# Resuming the Aura Master Forever port

Plan: `../2026-11-14-auramaster-forever-port.md`. Spec: `../../specs/2026-11-14-auramaster-forever-port-design.md`.
Git is the only state.

1. Run `./resume-state.sh -v`. It lists what has landed (a commit subject opening `<ID>: ` on the run branch or master),
   and the next items to work on.
2. If the tree is dirty, read the diff before doing anything. Continue the work or stash it, and never `reset --hard`
   or `checkout .` work you have not read. A LibKa0s re-vendor and a tool emit are idempotent and can be redone.
3. Work in order: M1 and M2 (in parallel), then M3, M4 and M5. Each item's gate is in the plan's Global Constraints.
4. At each milestone, re-run the gate, append a `checkpoints.tsv` row (commits and test totals) and push the branch.
   Only the lead session pushes.
5. The smoke is the owner's (`docs/smoke-tests.md`, the FOREVER theme). Merge only on the owner's go-ahead, then delete
   the run branches, stashes and worktrees.

## Log

- 2026-11-14: The owner's rulings are recorded in the spec §1. The combat-log follow-up is issue #26. Baseline: retail
  2358/0/1, forever 2358/0/1, lint 0/0, pytest 400.
- 2026-11-14: M3, M4 and M5 landed (AM-FP05 to AM-FP08, WS-FP01). Automated-test bundle 20261114-104251 at 5ff012f is
  green: retail 2377/0/1, forever 2376/0/2, lint 0/0 (213 files), pytest 441. Owed: the owner's FOREVER smoke on both
  clients, a ruling on the stale FX-AM-SIZE row (`defaults/Categories.lua` at 1399 lines), and the pushes.
