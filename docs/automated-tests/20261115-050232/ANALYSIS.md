# Analysis — 20261115-050232

- **Addon:** AuraMaster 1.1.0 (the presets record after the owner's round-2 feedback, not a release run)
- **Verdict:** green, on both kit profiles
- **Commit:** ffc8e8e (feat/2026-11-14-presets), clean tree
- **Previous run:** 20261115-024639 (at 9c6bfd2, 7 commits behind this one)

## Headline

This run records the presets branch after the owner's round-2 feedback (spec section 16, tasks AM-PR13 and AM-PR14 and the AM-PR15 docs: the call-outs' glow, a focus stack of its own, the corner group lined up with it, and the Presets tab on the General page). All four suites pass on both profiles. Lint is 0/0 over 224 files. Tests are 2499 passed, 1 skipped, 0 failed of 2500 on Retail and 2498 passed, 2 skipped, 0 failed on Forever ([`manifest.json`](manifest.json)). Perf passes with 12 scenarios, and its engine-call and allocation figures match 20261115-024639 in every scenario ([`perf.txt`](perf.txt)). Complexity passes with max CCN 15, 0 warnings, 0 blind and 0 crashed files. One file newly entered the 1000–1500 band, `tests/test_presets_data.lua`, and it is ruled on below.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261115-024639 |
|---|---|---|---|---|
| lint (gates commit and tag) | pass | 0 warnings / 0 errors in 224 files | [`lint.txt`](lint.txt) | unchanged |
| tests (gates commit and tag) | pass | 2499 passed, 1 skipped, 0 failed, 2500 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 2492 → 2500 |
| tests, Forever profile (gates commit and tag) | pass | 2498 passed, 2 skipped, 0 failed, 2500 total | no artifact: `KA0S_KIT_CLIENT=forever` run with `--no-bundle` (console only) | total 2492 → 2500 |
| perf (recorded; gates the tag only) | pass | 12 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | unchanged: 12 scenarios, api/iter and bytes/iter identical |
| complexity (recorded; gates the tag only) | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 62743 → 63065, functions 6635 → 6664 |

| Metric | Value |
|---|---|
| Total NLOC | 63065 |
| Functions | 6664 |
| Avg NLOC / function | 8.3 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 76.3 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 10 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

AuraMaster is `Retail · Forever` in the roster, so the battery ran twice (`clients-§6`). The Retail run wrote this bundle. The Forever run (`KA0S_KIT_CLIENT=forever tests/_kit/run-automated-tests.sh --no-bundle`) ran all four suites and wrote nothing. Its console reported lint 0/0 in 224 files, tests 2498 passed, 0 failed, 2 skipped of 2500, perf at `pass` with 12 scenarios, and complexity at `pass` with the same lizard figures (63065 NLOC, 6664 functions, avg NLOC 8.3, avg CCN 2.4, max 15, avg tokens 76.3, 0 warnings). Its verdict was green too. Those Forever figures are console output with no artifact in this bundle.

Every suite passed, so no suite needs a failure paragraph. The Retail skip is the same pre-existing case as in the previous run: the diagnostics contract case for an addon that opts out of logging, skipped because this addon keeps the default ([`tests.txt`](tests.txt)). The Forever profile's second skip is the v12 frozen-split case, which checks Retail data, as in the previous record. Both skips count toward the total, not toward `passed`, and at a release they read as NOT EVALUATED.

## What moved

- **lint**: did not move: 224 files, 0/0 ([`lint.txt`](lint.txt)). The 7 commits since the previous run added no file; `settings/ContainersPresets.lua` was renamed to `settings/GeneralPresets.lua` (AM-PR14), which keeps the count.
- **tests**: 2492 → 2500 (+8, from a diff of the two [`test-cases.md`](test-cases.md) inventories). `test_presets_data.lua` went from 20 to 26 cases (spec section 16): the call-outs carry the owner's glow exactly, the focus roles form their own screen-placed stack, no bars container is laid out horizontally after Apply, the focus stack stays clear of the far stack beyond twice the snap radius, Player debuffs' left edge lines up with Focus buffs' left edge, and the focus stack's snap range holds only the recorded targets. `test_presetpicker.lua` went from 40 to 41 with "picker: the footer names the General page's Presets tab". `test_pages_presets.lua` went from 11 to 12: "presets tab: listed after General" is now "presets tab: listed on the General page after Master controls", and "presets tab: gone from the Containers page" is new. Three cases were renamed to follow the tab's move: the General tab strip now lists Presets after Master controls, and the Containers page and its rail now carry one General tab. The skip counts did not change: 1 on Retail, 2 on Forever.
- **perf**: did not move. Against 20261115-024639, api/iter and bytes/iter are identical in all 12 scenarios: `compile` 0.0 / 4136.0, `applyPass` 30.0 / 107062.5, `restyle` 0.0 / 50646.1, `restyleText` 0.0 / 32067.7, `restyleTextGlow` 0.0 / 144963.7, `visibilityPass` 8.0 / 384.0, `unitSwap` 1.0 / 0.0, the three probe scenarios 9.0 / 384.0–384.5, and `unitAuraFiltered` and `emptyWatchAura` 0.0 / 0.0 ([`perf.json`](perf.json)). The round-2 changes are preset data and settings-page placement, and they added no engine calls and no allocation to any measured path. The ms/iter figures moved (`applyPass` 2.12335 → 1.45230, `restyleTextGlow` 4.24581 → 3.09651) while the whole run took 58886 → 59471 ms in `manifest.json`; timings are for orientation only and are not compared across runs.
- **complexity**: +322 NLOC and +29 functions ([`complexity.txt`](complexity.txt)), most of it in test code: `tests/test_presets_data.lua` 831 → 1116 NLOC (45 → 70 functions), `tests/test_presetpicker.lua` 729 → 742 (76 → 78) and `tests/test_pages_presets.lua` 174 → 182 (16 → 17). In shipped code, `defaults/Presets.lua` went 440 → 444 NLOC (32 functions, max CCN 11 in `hideLive`), `settings/OptionsSetup.lua` 413 → 422 (78 → 79), `settings/General.lua` 180 → 185 and `settings/Containers.lua` 183 → 181; `settings/GeneralPresets.lua` carries the 131 NLOC and 19 functions of the old `settings/ContainersPresets.lua` unchanged. Avg NLOC per function (8.3), avg CCN (2.4) and max CCN (15) did not move; avg tokens per function went 76.2 → 76.3, and there are still 0 warnings.

## Complexity watch list

Functions `lizard` warned on: none.

Files by band: 10 files, up from 9. The 9 carried files are at the same line counts and keep their dispositions. `tests/test_presets_data.lua` newly crossed the band floor (971 → 1365 lines) and arrived with a blank disposition, which this record rules on in `RESULTS.md`: accepted, as a suite file whose size is case count, not tangle (26 cases, 70 functions, max CCN 14 in the anonymous case at lines 1258–1311, per [`complexity.txt`](complexity.txt)), to be split by concern (layout, call-outs, snap range) if it grows again. It is 135 lines under the 1500 cap.

This is not a release run, so it does not add to the three-release shelf life of any **Accepted** entry.

## Actions

1. The FX-AM-SIZE ruling on `defaults/Categories.lua` carried from the previous records is still open. The file is unchanged at 1399 lines, so nothing new is owed here.
2. `tests/test_presets_data.lua` (1365 lines) is the nearest file to the 1500 cap. If the presets work adds more data cases, peel the layout and snap-range cases into their own suite file before it reaches the cap. This is new here.
