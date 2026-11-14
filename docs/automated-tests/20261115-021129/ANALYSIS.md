# Analysis — 20261115-021129

- **Addon:** AuraMaster 1.1.0 (the presets record after the owner's round-1 feedback, not a release run)
- **Verdict:** green, on both kit profiles
- **Commit:** 01f7833 (feat/2026-11-14-presets), clean tree
- **Previous run:** 20261114-184120 (at aef646a, 8 commits behind this one)

## Headline

This run records the presets branch after the owner's round-1 feedback (AM-PR09 side stacks, corner group and call-outs; AM-PR10 the picker opening centered and unlocked with lock and test-mode buttons; AM-PR11 docs, smoke checks and review fixes). All four suites pass on both profiles. Lint is 0/0 over 224 files. Tests are 2490 passed, 1 skipped, 0 failed of 2491 on Retail and 2489 passed, 2 skipped, 0 failed on Forever ([`manifest.json`](manifest.json)). Perf passes with 12 scenarios, and its engine-call and allocation figures match 20261114-184120 in every scenario ([`perf.txt`](perf.txt)). Complexity passes with max CCN 15, 0 warnings, 0 blind and 0 crashed files. Nothing new to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261114-184120 |
|---|---|---|---|---|
| lint (gates commit and tag) | pass | 0 warnings / 0 errors in 224 files | [`lint.txt`](lint.txt) | unchanged |
| tests (gates commit and tag) | pass | 2490 passed, 1 skipped, 0 failed, 2491 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 2471 → 2491 |
| tests, Forever profile (gates commit and tag) | pass | 2489 passed, 2 skipped, 0 failed, 2491 total | no artifact: `KA0S_KIT_CLIENT=forever` run with `--no-bundle` (console only) | total 2471 → 2491 |
| perf (recorded; gates the tag only) | pass | 12 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | unchanged: 12 scenarios, api/iter and bytes/iter identical |
| complexity (recorded; gates the tag only) | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 61926 → 62714, functions 6548 → 6633 |

| Metric | Value |
|---|---|
| Total NLOC | 62714 |
| Functions | 6633 |
| Avg NLOC / function | 8.3 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 76.2 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 9 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

AuraMaster is `Retail · Forever` in the roster, so the battery ran twice (`clients-§6`). The Retail run wrote this bundle. The Forever run (`KA0S_KIT_CLIENT=forever tests/_kit/run-automated-tests.sh --no-bundle`) ran all four suites and wrote nothing. Its console reported lint 0/0 in 224 files, tests 2489 passed, 0 failed, 2 skipped of 2491, perf at `pass` with 12 scenarios, and complexity at `pass` with the same lizard figures (62714 NLOC, 6633 functions, avg NLOC 8.3, avg CCN 2.4, max 15, avg tokens 76.2, 0 warnings). Its verdict was green too. Those Forever figures are console output with no artifact in this bundle.

Every suite passed, so no suite needs a failure paragraph. The Retail skip is the same pre-existing case as in the previous run: the diagnostics contract case for an addon that opts out of logging, skipped because this addon keeps the default ([`tests.txt`](tests.txt)). The Forever profile's second skip is the v12 frozen-split case, which checks Retail data, as in the previous record. Both skips count toward the total, not toward `passed`, and at a release they read as NOT EVALUATED.

## What moved

- **lint**: did not move: 224 files, 0/0 ([`lint.txt`](lint.txt)). The 8 commits since the previous run changed existing files and added none.
- **tests**: 2471 → 2491 (+20, from a diff of the two [`test-cases.md`](test-cases.md) inventories). `test_presets_data.lua` went from 14 to 19 cases (side stacks grow up, the corner group moved left and down, the call-outs centered and colored, the call-out font fit, the call-out rect in test mode). `test_presetpicker.lua` went from 25 to 40 cases (the window opens centered below the call-outs, no overlap with the call-out block and the skin picker at 1080, opening unlocks, the lock and test buttons, Apply leaves containers locked and test mode off, and the lock write-back on Not now, close, Escape, hide, profile switch and reset, `/am preset <name>`, logout and `/reload`). One existing picker case was renamed ("on the left" dropped from its title). The skip counts did not change: 1 on Retail, 2 on Forever.
- **perf**: did not move. Against 20261114-184120, api/iter and bytes/iter are identical in all 12 scenarios: `compile` 0.0 / 4136.0, `applyPass` 30.0 / 107062.5, `restyle` 0.0 / 50646.1, `restyleText` 0.0 / 32067.7, `restyleTextGlow` 0.0 / 144963.7, `visibilityPass` 8.0 / 384.0, `unitSwap` 1.0 / 0.0, the three probe scenarios 9.0 / 384.0–384.5, and `unitAuraFiltered` and `emptyWatchAura` 0.0 / 0.0 ([`perf.json`](perf.json)). The round-1 changes added no engine calls and no allocation to any measured path. The ms/iter figures are higher across the board (`applyPass` 1.48606 → 1.81939, `restyleTextGlow` 3.11874 → 4.01755), in step with the whole run taking longer (28808 → 62607 ms in `manifest.json`), but timings are for orientation only and are not compared across runs.
- **complexity**: +788 NLOC and +85 functions ([`complexity.txt`](complexity.txt)). Most of it is test code: `tests/test_presetpicker.lua` 411 → 710 NLOC (44 → 75 functions) and `tests/test_presets_data.lua` 548 → 815 (29 → 44). In shipped code, `settings/PresetPicker.lua` went 408 → 488 NLOC (55 → 69 functions, its max CCN 12 in `Picker.Placement`), and `defaults/Presets.lua` 343 → 440 (22 → 32, max CCN 11 in `hideLive`); `tests/wow_mock.lua` went 223 → 245; and `core/AuraMaster.lua`, `core/Database.lua`, `modules/Preview.lua`, `modules/Anchors.lua` and `locales/enUS.lua` moved by 1 to 6 NLOC each. Avg NLOC per function (8.3), avg CCN (2.4) and max CCN (15) did not move; avg tokens per function went 76.0 → 76.2, and there are still 0 warnings.

## Complexity watch list

Functions `lizard` warned on: none.

Files by band: the same 9 files as in the previous run, and none newly crossed. `modules/Anchors.lua` grew 1078 → 1081 lines (4921e6e exports `Anchors.STRIP_ROW` for the call-out rect); its disposition still holds as written (72 functions, max CCN 13 in `Anchors.FlowRoot`, per [`complexity.txt`](complexity.txt)). The other 8 files are at the same line counts. All 9 dispositions carry forward, and none was blank, so no new ruling is owed. `tests/test_presets_data.lua` is now 949 lines, under the band floor; it is not on the list, but it is the nearest file to it.

This is not a release run, so it does not add to the three-release shelf life of any **Accepted** entry.

## Actions

1. The FX-AM-SIZE ruling on `defaults/Categories.lua` carried from the previous records is still open. The file is unchanged at 1399 lines, so nothing new is owed here.
