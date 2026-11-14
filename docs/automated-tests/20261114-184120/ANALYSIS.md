# Analysis — 20261114-184120

- **Addon:** AuraMaster 1.1.0 (the presets record after the perf fixture fix, not a release run)
- **Verdict:** green, on both kit profiles
- **Commit:** aef646a (feat/2026-11-14-presets), clean tree
- **Previous run:** 20261114-183056 (at 73dabd9, 3 commits behind this one)

## Headline

This run records the presets branch again after two fixes. 080ab31 makes `tests/perf.lua` install `tests/starters_fixture.lua`, as the headless harness does, and aef646a sends an in-play category restore's spell edits through the settings seam (`defaults/UserCategories.lua`). All four suites pass on both profiles. Lint is 0/0 over 224 files. Tests are 2470 passed, 1 skipped, 0 failed of 2471 on Retail and 2469 passed, 2 skipped, 0 failed on Forever ([`manifest.json`](manifest.json)). Perf is back at `pass` with 12 scenarios, and its engine-call and allocation figures match 20261114-104251, the last comparable bundle, in every scenario ([`perf.txt`](perf.txt)). That resolves the amber record's Action 1. Complexity is at `pass` with max CCN 15, 0 warnings, 0 blind and 0 crashed files. Nothing new to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261114-183056 |
|---|---|---|---|---|
| lint (gates commit and tag) | pass | 0 warnings / 0 errors in 224 files | [`lint.txt`](lint.txt) | unchanged |
| tests (gates commit and tag) | pass | 2470 passed, 1 skipped, 0 failed, 2471 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 2470 → 2471 |
| tests, Forever profile (gates commit and tag) | pass | 2469 passed, 2 skipped, 0 failed, 2471 total | no artifact: `KA0S_KIT_CLIENT=forever` run with `--no-bundle` (console only) | total 2470 → 2471 |
| perf (recorded; gates the tag only) | pass | 12 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | fail → pass, 10 → 12 scenarios |
| complexity (recorded; gates the tag only) | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 61902 → 61926, functions 6546 → 6548 |

| Metric | Value |
|---|---|
| Total NLOC | 61926 |
| Functions | 6548 |
| Avg NLOC / function | 8.3 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 76.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 9 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

AuraMaster is `Retail · Forever` in the roster, so the battery ran twice (`clients-§6`). The Retail run wrote this bundle. The Forever run (`KA0S_KIT_CLIENT=forever tests/_kit/run-automated-tests.sh --no-bundle`) ran all four suites and wrote nothing. Its console reported lint 0/0 in 224 files, tests 2469 passed, 0 failed, 2 skipped of 2471, perf at `pass` with 12 scenarios, and complexity at `pass` with the same lizard figures (61926 NLOC, 6548 functions, avg CCN 2.4, max 15, 0 warnings). Its verdict was green too. Those Forever figures are console output with no artifact in this bundle.

Every suite passed, so no suite needs a failure paragraph. The Retail skip is the same pre-existing case as in the previous run: the diagnostics contract case for an addon that opts out of logging, skipped because this addon keeps the default ([`tests.txt`](tests.txt)). The Forever profile's second skip is the v12 frozen-split case, which checks Retail data, as in the previous record. Both skips count toward the total, not toward `passed`, and at a release they read as NOT EVALUATED.

## What moved

- **lint**: did not move: 224 files, 0/0 ([`lint.txt`](lint.txt)). The three commits since the previous run changed existing files and added none.
- **tests**: 2470 → 2471 (+1, from a diff of the two [`test-cases.md`](test-cases.md) inventories). `test_presets_preview.lua` went from 19 to 20 cases with "preview: an in-play restore puts the spell edits back through the seam, exactly" (aef646a). The skip counts did not change: 1 on Retail, 2 on Forever.
- **perf**: back at `pass`. With the fixture restored ("200 writes coalesced into 1 apply pass; 4 containers", [`perf.txt`](perf.txt)), `restyleText` and `restyleTextGlow` run again, so the run has 12 scenarios instead of 10. Against 20261114-104251, the last bundle measured on the same fixture, api/iter and bytes/iter are identical in all 12 scenarios: `compile` 0.0 / 4136.0, `applyPass` 30.0 / 107062.5, `restyle` 0.0 / 50646.1, `restyleText` 0.0 / 32067.7, `restyleTextGlow` 0.0 / 144963.7, `visibilityPass` 8.0 / 384.0, `unitSwap` 1.0 / 0.0, the three probe scenarios 9.0 / 384.0–384.5, and `unitAuraFiltered` and `emptyWatchAura` 0.0 / 0.0 ([`perf.json`](perf.json)). The presets branch added no engine calls and no allocation to any measured path. The ms/iter figures are close to 20261114-104251's (`applyPass` 1.49005 → 1.48606, `restyleTextGlow` 3.05415 → 3.11874), but timings are for orientation only and are not compared across runs. The 20261114-183056 perf figures came from the 3-container Simple fixture and are not a baseline for anything.
- **complexity**: +24 NLOC and +2 functions ([`complexity.txt`](complexity.txt)). `defaults/UserCategories.lua` went 422 → 429 NLOC (37 functions, its max CCN 14 in `Cat.UserCategoryOrder`), `tests/perf.lua` 264 → 265, and `tests/test_presets_preview.lua` 376 → 392 NLOC with 30 → 32 functions. Avg NLOC per function (8.3), avg CCN (2.4), avg tokens per function (76.0) and max CCN (15) did not move, and there are still 0 warnings.

## Complexity watch list

Functions `lizard` warned on: none.

Files by band: the same 9 files as in the previous run, at the same line counts, and none newly crossed. All 9 dispositions carry forward. One was stale and is refreshed in `RESULTS.md` here: the `core/Database_Migrations.lua` row (1213 lines) said 14 step bodies and 50 functions. This run's [`complexity.txt`](complexity.txt) measures 56 functions in the file, 16 of them `Database.MigrateV` step bodies (v2 through v15, v17 and v19), with max CCN still 15 (`Database.MigrateV15`):

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/Database_Migrations.lua` | 1213 | Accepted — in the band since the skin steps through v15 (935 → 1076), now 1213 lines with the v19 step (AM-PR04); 16 frozen `Database.MigrateV` step bodies (v2–v15, v17, v19) with their private helpers, 56 functions, max CCN 15 (`Database.MigrateV15`, at the threshold, not over it). Steps are independent and frozen once shipped, so the size is ladder length, not tangle |

This is not a release run, so it does not add to the three-release shelf life of any **Accepted** entry.

## Actions

1. Resolved: Action 1 of the amber record 20261114-183056 (`tests/perf.lua` still expecting the four old starters) is fixed by 080ab31. This run shows perf at `pass` with figures comparable to 20261114-104251, so the release gate's perf condition is met again.
2. The FX-AM-SIZE ruling on `defaults/Categories.lua` carried from the previous records is still open. The file is unchanged at 1399 lines, so nothing new is owed here.
