# Analysis — 20261115-024639

- **Addon:** AuraMaster 1.1.0 (the presets record after the owner's round-1 rulings, not a release run)
- **Verdict:** green, on both kit profiles
- **Commit:** 9c6bfd2 (feat/2026-11-14-presets), clean tree
- **Previous run:** 20261115-021129 (at 01f7833, 4 commits behind this one)

## Headline

This run records the presets branch after the owner's rulings on the round-1 conflicts (spec section 15.1, task AM-PR12: the picker takes the skin picker's spot, and the side stacks start from a lower base). All four suites pass on both profiles. Lint is 0/0 over 224 files. Tests are 2491 passed, 1 skipped, 0 failed of 2492 on Retail and 2490 passed, 2 skipped, 0 failed on Forever ([`manifest.json`](manifest.json)). Perf passes with 12 scenarios, and its engine-call and allocation figures match 20261115-021129 in every scenario ([`perf.txt`](perf.txt)). Complexity passes with max CCN 15, 0 warnings, 0 blind and 0 crashed files. Nothing new to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261115-021129 |
|---|---|---|---|---|
| lint (gates commit and tag) | pass | 0 warnings / 0 errors in 224 files | [`lint.txt`](lint.txt) | unchanged |
| tests (gates commit and tag) | pass | 2491 passed, 1 skipped, 0 failed, 2492 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 2491 → 2492 |
| tests, Forever profile (gates commit and tag) | pass | 2490 passed, 2 skipped, 0 failed, 2492 total | no artifact: `KA0S_KIT_CLIENT=forever` run with `--no-bundle` (console only) | total 2491 → 2492 |
| perf (recorded; gates the tag only) | pass | 12 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | unchanged: 12 scenarios, api/iter and bytes/iter identical |
| complexity (recorded; gates the tag only) | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 62714 → 62743, functions 6633 → 6635 |

| Metric | Value |
|---|---|
| Total NLOC | 62743 |
| Functions | 6635 |
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

AuraMaster is `Retail · Forever` in the roster, so the battery ran twice (`clients-§6`). The Retail run wrote this bundle. The Forever run (`KA0S_KIT_CLIENT=forever tests/_kit/run-automated-tests.sh --no-bundle`) ran all four suites and wrote nothing. Its console reported lint 0/0 in 224 files, tests 2490 passed, 0 failed, 2 skipped of 2492, perf at `pass` with 12 scenarios, and complexity at `pass` with the same lizard figures (62743 NLOC, 6635 functions, avg NLOC 8.3, avg CCN 2.4, max 15, avg tokens 76.2, 0 warnings). Its verdict was green too. Those Forever figures are console output with no artifact in this bundle.

Every suite passed, so no suite needs a failure paragraph. The Retail skip is the same pre-existing case as in the previous run: the diagnostics contract case for an addon that opts out of logging, skipped because this addon keeps the default ([`tests.txt`](tests.txt)). The Forever profile's second skip is the v12 frozen-split case, which checks Retail data, as in the previous record. Both skips count toward the total, not toward `passed`, and at a release they read as NOT EVALUATED.

## What moved

- **lint**: did not move: 224 files, 0/0 ([`lint.txt`](lint.txt)). The 4 commits since the previous run changed existing files and added none.
- **tests**: 2491 → 2492 (+1, from a diff of the two [`test-cases.md`](test-cases.md) inventories). `test_presets_data.lua` went from 19 to 20 cases with "presets data: side stacks sit on the lower base" (spec section 15.1), and its top-edge check was tightened to that base. `test_presetpicker.lua` stayed at 40 cases, with two renamed to follow the 15.1 ruling: "picker: opens centered below the call-outs" is now "picker: opens where the skin picker does", and "presets data: the call-out block, the picker and the skin picker do not intersect at 1080" is now "picker: the call-out block clears the picker at 1080 for every preset". The skip counts did not change: 1 on Retail, 2 on Forever.
- **perf**: did not move. Against 20261115-021129, api/iter and bytes/iter are identical in all 12 scenarios: `compile` 0.0 / 4136.0, `applyPass` 30.0 / 107062.5, `restyle` 0.0 / 50646.1, `restyleText` 0.0 / 32067.7, `restyleTextGlow` 0.0 / 144963.7, `visibilityPass` 8.0 / 384.0, `unitSwap` 1.0 / 0.0, the three probe scenarios 9.0 / 384.0–384.5, and `unitAuraFiltered` and `emptyWatchAura` 0.0 / 0.0 ([`perf.json`](perf.json)). The rulings added no engine calls and no allocation to any measured path. The ms/iter figures moved (`applyPass` 1.81939 → 2.12335, `restyleTextGlow` 4.01755 → 4.24581) while the whole run took 62607 → 58886 ms in `manifest.json`; timings are for orientation only and are not compared across runs.
- **complexity**: +29 NLOC and +2 functions ([`complexity.txt`](complexity.txt)), all of it in test code: `tests/test_presetpicker.lua` 710 → 729 NLOC (75 → 76 functions) and `tests/test_presets_data.lua` 815 → 831 (44 → 45). In shipped code, `settings/PresetPicker.lua` went 488 → 482 NLOC (69 functions), and `Picker.Placement` dropped from CCN 12 to 5 now that the picker takes the skin picker's spot, so the file's max CCN is 10 (`NS.ConfirmPreset`). `defaults/Presets.lua` stayed at 440 NLOC and 32 functions (max CCN 11 in `hideLive`). Avg NLOC per function (8.3), avg CCN (2.4), max CCN (15) and avg tokens per function (76.2) did not move, and there are still 0 warnings.

## Complexity watch list

Functions `lizard` warned on: none.

Files by band: the same 9 files as in the previous run, at the same line counts, and none newly crossed. All 9 dispositions carry forward, and none was blank, so no new ruling is owed. `tests/test_presets_data.lua` is now 971 lines, still under the band floor and still the nearest file to it.

This is not a release run, so it does not add to the three-release shelf life of any **Accepted** entry.

## Actions

1. The FX-AM-SIZE ruling on `defaults/Categories.lua` carried from the previous records is still open. The file is unchanged at 1399 lines, so nothing new is owed here.
