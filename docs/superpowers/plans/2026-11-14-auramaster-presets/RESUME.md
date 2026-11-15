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
- 2026-11-14: M3 landed (AM-PR07, AM-PR08 review fixes). Automated-test bundle 20261114-183056 at 73dabd9 is amber:
  retail 2469/0/1, forever 2468/0/2, lint 0/0 (224 files), max CCN 15, 0 warnings, but perf fails 4 assertions because
  `tests/perf.lua` still expects the four old starters (AM-PR04 seeds Simple). Owed: the perf fixture fix and a re-run,
  the owner's PRESETS smoke, the owner rulings recorded in the plan, and the pushes.
- 2026-11-14: Perf fixture fixed (080ab31: `tests/perf.lua` installs `tests/starters_fixture.lua`) and the in-play
  category restore routed through the seam (aef646a). Automated-test bundle 20261114-184120 at aef646a is green:
  retail 2470/0/1, forever 2469/0/2, lint 0/0 (224 files), perf pass (12 scenarios, matching 20261114-104251), max
  CCN 15, 0 warnings. Owed: the owner's PRESETS smoke, the owner rulings recorded in the plan, and the pushes.
- 2026-11-15: Round-1 owner feedback landed (AM-PR09 side stacks, corner group and call-outs; AM-PR10 picker
  centered and unlocked with lock and test-mode buttons; AM-PR11 docs, smoke checks and review fixes). Automated-test
  bundle 20261115-021129 at 01f7833 is green: retail 2490/0/1, forever 2489/0/2, lint 0/0 (224 files), perf pass
  (12 scenarios, matching 20261114-184120), max CCN 15, 0 warnings. Owed: the owner's PRESETS smoke (round-1 checks
  included), the owner rulings recorded in the plan, and the pushes.
- 2026-11-15: The owner's round-1 rulings landed (spec 15.1, AM-PR12: the picker takes the skin picker's spot,
  the side stacks start lower; docs and smoke checks). Automated-test bundle 20261115-024639 at 9c6bfd2 is green:
  retail 2491/0/1, forever 2490/0/2, lint 0/0 (224 files), perf pass (12 scenarios, matching 20261115-021129), max
  CCN 15, 0 warnings. Owed: the owner's PRESETS smoke (round-1 and 15.1 checks included), the owner rulings
  recorded in the plan, and the pushes.
- 2026-11-15: The owner's round-2 feedback landed (spec section 16, AM-PR13..15: the call-outs' glow, a focus
  stack of its own, the corner group lined up with it, the Presets tab on the General page; docs and smoke checks).
  Automated-test bundle 20261115-050232 at ffc8e8e is green: retail 2499/0/1, forever 2498/0/2, lint 0/0 (224
  files), perf pass (12 scenarios, matching 20261115-024639), max CCN 15, 0 warnings. Owed: the AM-PR15 independent
  review against section 16, the owner's PRESETS smoke (round-1, 15.1 and round-2 checks included), the owner
  rulings recorded in the plan, and the pushes.
- 2026-11-15: The owner's round-3 feedback landed (spec section 17, AM-PR16..18: the right-hand cluster lined up,
  Player debuffs attached to Player buffs, equal bar widths, debuff bars by dispel type, 50% bar backgrounds,
  numbered names, the unlock hint; docs and smoke checks). Automated-test bundle 20261115-123413 at 317a515 is
  green: retail 2508/0/1, forever 2507/0/2, lint 0/0 (226 files), perf pass (12 scenarios, matching
  20261115-050232), max CCN 15, 0 warnings. Owed: the AM-PR18 independent review against section 17 (the AM-PR15
  review landed as cef03ff and 054b507), the owner's PRESETS smoke (round-1, 15.1, round-2 and round-3 checks
  included), the owner rulings recorded in the plan, and the pushes.
- 2026-11-15: The owner's round-4 feedback landed (spec section 18, AM-PR19..21: the player stack nearer the
  center, the target cluster mirroring it, the call-outs higher, the picker shown once to existing profiles; docs
  and smoke checks). Automated-test bundle 20261115-144535 at acb5545 is green: retail 2519/0/1, forever 2518/0/2,
  lint 0/0 (226 files), perf pass (12 scenarios, matching 20261115-123413), max CCN 15, 0 warnings;
  tests/test_presetpicker.lua newly in the 1000-1500 band at 1074 lines, accepted. Owed: an independent review
  against section 18, the owner's PRESETS smoke (round-1, 15.1, round-2, round-3 and round-4 checks included), the
  owner rulings recorded in the plan, and the pushes.
