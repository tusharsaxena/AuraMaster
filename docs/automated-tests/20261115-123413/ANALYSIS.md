# Analysis — 20261115-123413

- **Addon:** AuraMaster 1.1.0 (the presets record after the owner's round-3 feedback, not a release run)
- **Verdict:** green, on both kit profiles
- **Commit:** 317a515 (feat/2026-11-14-presets), clean tree
- **Previous run:** 20261115-050232 (at ffc8e8e, 7 commits behind this one)

## Headline

This run records the presets branch after the owner's round-3 feedback (spec section 17, tasks AM-PR16 and AM-PR17 and the AM-PR18 docs: the right-hand cluster lined up, Player debuffs attached to Player buffs, equal bar widths, debuff bars colored by dispel type, 50% bar backgrounds, numbered container names and the unlock hint after the picker closes). All four suites pass on both profiles. Lint is 0/0 over 226 files. Tests are 2508 passed, 1 skipped, 0 failed of 2509 on Retail and 2507 passed, 2 skipped, 0 failed on Forever ([`manifest.json`](manifest.json)). Perf passes with 12 scenarios, and its engine-call and allocation figures match 20261115-050232 in every scenario ([`perf.txt`](perf.txt)). Complexity passes with max CCN 15, 0 warnings, 0 blind and 0 crashed files, and no file newly entered the 1000–1500 band.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261115-050232 |
|---|---|---|---|---|
| lint (gates commit and tag) | pass | 0 warnings / 0 errors in 226 files | [`lint.txt`](lint.txt) | files 224 → 226 |
| tests (gates commit and tag) | pass | 2508 passed, 1 skipped, 0 failed, 2509 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 2500 → 2509 |
| tests, Forever profile (gates commit and tag) | pass | 2507 passed, 2 skipped, 0 failed, 2509 total | no artifact: `KA0S_KIT_CLIENT=forever` run with `--no-bundle` (console only) | total 2500 → 2509 |
| perf (recorded; gates the tag only) | pass | 12 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | unchanged: 12 scenarios, api/iter and bytes/iter identical |
| complexity (recorded; gates the tag only) | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 63065 → 63489, functions 6664 → 6698 |

| Metric | Value |
|---|---|
| Total NLOC | 63489 |
| Functions | 6698 |
| Avg NLOC / function | 8.3 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 76.5 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 10 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

AuraMaster is `Retail · Forever` in the roster, so the battery ran twice (`clients-§6`). The Retail run wrote this bundle. The Forever run (`KA0S_KIT_CLIENT=forever tests/_kit/run-automated-tests.sh --no-bundle`) ran all four suites and wrote nothing. Its console reported lint 0/0 in 226 files, tests 2507 passed, 0 failed, 2 skipped of 2509, perf at `pass` with 12 scenarios, and complexity at `pass` with the same lizard figures (63489 NLOC, 6698 functions, avg NLOC 8.3, avg CCN 2.4, max 15, avg tokens 76.5, 0 warnings). Its verdict was green too. Those Forever figures are console output with no artifact in this bundle.

Every suite passed, so no suite needs a failure paragraph. The Retail skip is the same pre-existing case as in the previous run: the diagnostics contract case for an addon that opts out of logging, skipped because this addon keeps the default ([`tests.txt`](tests.txt)). The Forever profile's second skip is the v12 frozen-split case, which checks Retail data, as in the previous record. Both skips count toward the total, not toward `passed`, and at a release they read as NOT EVALUATED.

## What moved

- **lint**: 224 → 226 files, still 0/0 ([`lint.txt`](lint.txt)). The two new files are `tests/test_presets_cluster.lua` and `tests/presets_spans.lua`, both added by AM-PR16.
- **tests**: 2500 → 2509 (+9, from a diff of the two [`test-cases.md`](test-cases.md) inventories). `test_presets_data.lua` went from 26 to 29 cases: "debuff bars color by dispel type", "bar backgrounds are 50% opaque" and "names are numbered 1..N in the owner's order" are new, and two cases were renamed to follow the round-3 layout ("the corner group sits left of and below its old place" is now "the corner group hangs from the right edge, Player buffs 10 in", and "Player debuffs' left edge lines up with Focus buffs' left edge" is now "the focus, far and Player debuffs left edges line up"). `test_presets_cluster.lua` is a new suite file with 5 cases: Player debuffs attaches by its top right to Player buffs' top left, the target column sits 50 left of the focus column, the target stack's base and test-mode top, every bar container as wide as Player cooldowns, and the call-out block's recorded overlap with the target column. `test_presetpicker.lua` went from 41 to 42 with "picker: every close prints the unlock hint once". The prose case's tracked-file count went 265 → 267 with the two new files. The skip counts did not change: 1 on Retail, 2 on Forever.
- **perf**: did not move. Against 20261115-050232, api/iter and bytes/iter are identical in all 12 scenarios: `compile` 0.0 / 4136.0, `applyPass` 30.0 / 107062.5, `restyle` 0.0 / 50646.1, `restyleText` 0.0 / 32067.7, `restyleTextGlow` 0.0 / 144963.7, `visibilityPass` 8.0 / 384.0, `unitSwap` 1.0 / 0.0, the three probe scenarios 9.0 / 384.0–384.5, and `unitAuraFiltered` and `emptyWatchAura` 0.0 / 0.0 ([`perf.json`](perf.json)). The round-3 changes are preset data, the picker's close hint and test code, and they added no engine calls and no allocation to any measured path. The ms/iter figures moved (`applyPass` 1.45230 → 1.43519, `restyleTextGlow` 3.09651 → 3.23550) while the whole run took 59471 → 83930 ms in `manifest.json`; timings are for orientation only and are not compared across runs.
- **complexity**: +424 NLOC and +34 functions ([`complexity.txt`](complexity.txt)), most of it in test code: the new `tests/test_presets_cluster.lua` (212 NLOC, 12 functions, max CCN 14 in the anonymous case at lines 179–227) and `tests/presets_spans.lua` (124 NLOC, 14 functions, max CCN 11 in `sampleSpans`), `tests/test_presets_data.lua` 1116 → 1127 NLOC (70 → 67 functions), `tests/test_presetpicker.lua` 742 → 781 (78 → 85), `tests/test_presets_apply.lua` 202 → 205 and `tests/test_presets_seed.lua` 112 → 115. In shipped code, `defaults/Presets.lua` went 444 → 466 NLOC (32 → 34 functions, max CCN 12 in `P.Build`), `settings/PresetPicker.lua` 482 → 490 (69 → 71) and `locales/enUS.lua` 877 → 878. Avg NLOC per function (8.3), avg CCN (2.4) and max CCN (15) did not move; avg tokens per function went 76.3 → 76.5, and there are still 0 warnings.

## Complexity watch list

Functions `lizard` warned on: none.

Files by band: 10 files, as in the previous run, and none newly crossed. Nine are at the same line counts and keep their dispositions. `tests/test_presets_data.lua` went 1365 → 1359 lines; the runner carried its disposition forward, and this record updated that cell in `RESULTS.md` to the file's current figures (29 cases, 67 functions, max CCN 14 in the anonymous case at lines 351–397, per [`complexity.txt`](complexity.txt)) and to the round-3 cluster cases having gone to `tests/test_presets_cluster.lua`. It is still accepted as a suite file whose size is case count, not tangle, 141 lines under the 1500 cap.

This is not a release run, so it does not add to the three-release shelf life of any **Accepted** entry.

## Actions

1. The FX-AM-SIZE ruling on `defaults/Categories.lua` carried from the previous records is still open. The file is unchanged at 1399 lines, so nothing new is owed here.
2. The previous record's Action 2 is met for now: the round-3 layout cases went into their own suite file, `tests/test_presets_cluster.lua`, and `tests/test_presets_data.lua` shrank by 6 lines. If later presets work adds more data cases, keep putting them in a file of their own rather than in `tests/test_presets_data.lua`.
