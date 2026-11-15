# Analysis — 20261115-144535

- **Addon:** AuraMaster 1.1.0 (the presets record after the owner's round-4 feedback, not a release run)
- **Verdict:** green, on both kit profiles
- **Commit:** acb5545 (feat/2026-11-14-presets), clean tree
- **Previous run:** 20261115-123413 (at 317a515, 6 commits behind this one)

## Headline

This run records the presets branch after the owner's round-4 feedback (spec section 18, tasks AM-PR19 to AM-PR21: the player stack nearer the center, the target cluster mirroring it, the call-out block higher, and the preset picker shown once to existing profiles). All four suites pass on both profiles. Lint is 0/0 over 226 files. Tests are 2519 passed, 1 skipped, 0 failed of 2520 on Retail and 2518 passed, 2 skipped, 0 failed on Forever ([`manifest.json`](manifest.json)). Perf passes with 12 scenarios, and its engine-call and allocation figures match 20261115-123413 in every scenario ([`perf.txt`](perf.txt)). Complexity passes with max CCN 15, 0 warnings, 0 blind and 0 crashed files. One file newly entered the 1000–1500 band, `tests/test_presetpicker.lua` at 1074 lines, and this record accepts it.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261115-123413 |
|---|---|---|---|---|
| lint (gates commit and tag) | pass | 0 warnings / 0 errors in 226 files | [`lint.txt`](lint.txt) | unchanged: 226 files, 0/0 |
| tests (gates commit and tag) | pass | 2519 passed, 1 skipped, 0 failed, 2520 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 2509 → 2520 |
| tests, Forever profile (gates commit and tag) | pass | 2518 passed, 2 skipped, 0 failed, 2520 total | no artifact: `KA0S_KIT_CLIENT=forever` run with `--no-bundle` (console only) | total 2509 → 2520 |
| perf (recorded; gates the tag only) | pass | 12 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | unchanged: 12 scenarios, api/iter and bytes/iter identical |
| complexity (recorded; gates the tag only) | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 63489 → 63807, functions 6698 → 6723 |

| Metric | Value |
|---|---|
| Total NLOC | 63807 |
| Functions | 6723 |
| Avg NLOC / function | 8.4 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 76.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 11 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

AuraMaster is `Retail · Forever` in the roster, so the battery ran twice (`clients-§6`). The Retail run wrote this bundle. The Forever run (`KA0S_KIT_CLIENT=forever tests/_kit/run-automated-tests.sh --no-bundle`) ran all four suites and wrote nothing. Its console reported lint 0/0 in 226 files, tests 2518 passed, 0 failed, 2 skipped of 2520, perf at `pass` with 12 scenarios, and complexity at `pass` with the same lizard figures (63807 NLOC, 6723 functions, avg NLOC 8.4, avg CCN 2.4, max 15, avg tokens 76.8, 0 warnings). Its verdict was green too. Those Forever figures are console output with no artifact in this bundle.

Every suite passed, so no suite needs a failure paragraph. The Retail skip is the same pre-existing case as in the previous run: the diagnostics contract case for an addon that opts out of logging, skipped because this addon keeps the default ([`tests.txt`](tests.txt)). The Forever profile's second skip is the v12 frozen-split case, which checks Retail data, as in the previous record. Both skips count toward the total, not toward `passed`, and at a release they read as NOT EVALUATED.

## What moved

- **lint**: did not move, 226 files at 0/0 ([`lint.txt`](lint.txt)). Round 4 added no Lua file.
- **tests**: 2509 → 2520 (+11, from a diff of the two [`test-cases.md`](test-cases.md) inventories). `test_presets_cluster.lua` went from 5 to 9 cases: "the player column sits 40 from the call-out column", "the target column mirrors the player column where the cluster fits", "the cluster moves left just enough to fit on narrower screens" and "the call-out block starts at about the picker's top" are new (AM-PR19). `test_presetpicker.lua` went from 42 to 48 with the six once-per-account cases of AM-PR20 (an existing profile sees the picker once per account, any close marks it shown for every profile, a brand-new install does not see it twice, combat holds it, an existing player's containers stay unless they apply and confirm, the account latch is a global row written through the seam). `test_presets_seed.lua` went from 7 to 8 with "the account latch needs no migration step". Three cases were renamed to follow the round-4 layout: in `test_presets_data.lua` "the corner group hangs from the right edge, Player buffs 10 in" is now "the corner group ends the cluster, Player buffs at least 10 in" and "the call-out block takes the largest font that fits, centered as far as it can" is now "the call-out block takes the largest font that fits under the picker's top"; in `test_presetpicker.lua` "the call-out block clears the picker at 1080 for every preset" is now "the call-out block starts at the picker's top for every preset". The skip counts did not change: 1 on Retail, 2 on Forever.
- **perf**: did not move. Against 20261115-123413, api/iter and bytes/iter are identical in all 12 scenarios: `compile` 0.0 / 4136.0, `applyPass` 30.0 / 107062.5, `restyle` 0.0 / 50646.1, `restyleText` 0.0 / 32067.7, `restyleTextGlow` 0.0 / 144963.7, `visibilityPass` 8.0 / 384.0, `unitSwap` 1.0 / 0.0, the three probe scenarios 9.0 / 384.0–384.5, and `unitAuraFiltered` and `emptyWatchAura` 0.0 / 0.0 ([`perf.json`](perf.json)). The round-4 changes are preset data, the picker's once-per-account latch and test code, and they added no engine calls and no allocation to any measured path. The ms/iter figures moved (`applyPass` 1.43519 → 1.45826, `restyleTextGlow` 3.23550 → 3.08664) while the whole run took 83930 → 74074 ms in `manifest.json`; timings are for orientation only and are not compared across runs.
- **complexity**: +318 NLOC and +25 functions ([`complexity.txt`](complexity.txt)), most of it in test code: `tests/test_presetpicker.lua` 781 → 903 NLOC (85 → 99 functions, max CCN 9), `tests/test_presets_cluster.lua` 212 → 345 (12 → 19, max CCN 14 in the anonymous case at lines 182–230), `tests/test_presets_seed.lua` 115 → 126 (13 → 14) and `tests/test_presets_data.lua` 1127 → 1129. In shipped code, `defaults/Presets.lua` went 466 → 495 NLOC (34 → 36 functions, max CCN 12 in `P.Build`), `modules/Presets.lua` 251 → 257 (30 → 31), `settings/Schema.lua` 588 → 592, `settings/General.lua` 185 → 191, `defaults/Profile.lua` 161 → 162 and `locales/enUS.lua` 878 → 879. Avg CCN (2.4) and max CCN (15) did not move; avg NLOC per function went 8.3 → 8.4 and avg tokens per function 76.5 → 76.8, both from the larger test cases, and there are still 0 warnings.

## Complexity watch list

Functions `lizard` warned on: none.

Files by band: 11 files, up from 10. `tests/test_presetpicker.lua` newly crossed, 932 → 1074 lines, with the six once-per-account cases of AM-PR20. The runner left its Disposition blank, and this record rules it **Accepted**: a suite file, so case count, not tangle (48 cases, 99 functions, max CCN 9, per [`complexity.txt`](complexity.txt) and [`test-cases.md`](test-cases.md)), 426 lines under the 1500 cap, to be split by concern (the once-per-account latch, the call-out geometry) if it grows again. Three carried entries moved a few lines and their dispositions still hold: `core/Database_Migrations.lua` 1213 → 1214, `settings/Schema.lua` 1017 → 1025 (the `global.` path resolution for the account latch, AM-PR20) and `tests/test_presets_data.lua` 1359 → 1366. The other seven are at the same line counts.

This is not a release run, so it does not add to the three-release shelf life of any **Accepted** entry.

## Actions

1. The FX-AM-SIZE ruling on `defaults/Categories.lua` carried from the previous records is still open. The file is unchanged at 1399 lines, so nothing new is owed here.
2. New here: `tests/test_presetpicker.lua` is in the band at 1074 lines. If later presets work adds more picker cases, put the once-per-account latch cases in a file of their own rather than growing this one.
