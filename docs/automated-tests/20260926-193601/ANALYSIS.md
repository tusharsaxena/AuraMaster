# Analysis — 20260926-193601

- **Addon:** AuraMaster 0.1.0
- **Verdict:** green
- **Commit:** 8f7fcfb0951fa00974035a6730ae507b648b4b22 (feat/2026-09-26-automated-tests-sweep), clean
- **Previous run:** 20260926-160451 (`e5bb12c`, 12 commits earlier)

## Headline

All four suites pass ([`manifest.json`](manifest.json)): lint 0/0 over 144 files, 1661 cases with
nothing skipped, 11 perf scenarios, and **0 functions above CCN 15**, so the release gate would be
satisfied on today's numbers. This is the closing run of the automated-tests sweep, and every action
the previous analysis raised has moved. The perf allocation rise is reversed: `compile` bytes/iter
fell 42424.0 → 3576.0 and `applyPass` 164883.4 → 104403.4. The three files nearest the cap left the
band (12 → 9 band files), and the CCN-15 functions went from six to five. Nothing new needs action.

## Suites

| Suite | Status | Result | Artifact | Moved since 20260926-160451 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 144 files | [`lint.txt`](lint.txt) | Still 0/0; scope 140 → 144 files (four new authored files from the peels) |
| tests | pass | 1661 passed, 0 skipped, 0 failed, 1661 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1660 → 1661 (+1) |
| perf | pass | 11 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | Same 11 scenarios; `compile` and `applyPass` bytes/iter fell sharply. See *What moved* |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | +62 NLOC / +3 funcs; every average flat; band files 12 → 9 |

**Complexity is reported in full** (from [`manifest.json`](manifest.json) `suites.complexity`, which
mirrors `lizard`'s footer in [`complexity.txt`](complexity.txt)):

| Metric | Value |
|---|---|
| Total NLOC | 39990 (was 39928) |
| Functions | 4352 (was 4349) |
| Avg NLOC / function | 8.2 (was 8.2) |
| Avg CCN | 2.3 (was 2.3) |
| Max CCN | 15 (was 15) |
| Avg tokens / function | 72.5 (was 72.5) |
| Warnings (CCN > 15) | 0 (was 0) |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 9 (was 12) |
| Files over the 1500 cap | 0 (was 0) |

All four suites pass cleanly, so there is no failing or skipped suite to explain.

## What moved

- **tests:** 1660 → 1661 cases (+1), all passing, none skipped ([`tests.txt`](tests.txt)).
- **lint:** scope 140 → 144 files, still 0/0 ([`lint.txt`](lint.txt)). The four new files are
  `modules/Anchors_Attach.lua`, `settings/GeneralUserCategories.lua`,
  `tests/test_anchors_handle.lua` and `tests/handle_recorder.lua`, all products of the peels.
- **perf — allocation** (bytes/iter, [`perf.txt`](perf.txt) against the previous bundle's `perf.txt`):

  | Scenario | Was | Now | Change |
  |---|---|---|---|
  | `compile` | 42424.0 | 3576.0 | **−91.6%** |
  | `applyPass` | 164883.4 | 104403.4 | **−36.7%** |
  | the other nine | — | — | unchanged |

  api/iter is identical on every scenario (`applyPass` still 30.0), so the engine-call contract
  held. `AM-ATS-01` ("Build the categorized union only where the hasUnion gate reads it") is the
  only commit in `e5bb12c..8f7fcfb` that touched `modules/FilterCompiler.lua`, and the drop lines up
  with it. It was not bisected. `compile` now allocates less than it did at `20260924-185738`
  (22200.0). `applyPass` is below that run's 118147.2 as well. `ms/iter` fell on every scenario too, but timings are for within-run comparison only.
- **complexity:** functions at exactly CCN 15 went from 6 to 5 ([`complexity.txt`](complexity.txt)).
  `steadyRelative` (`modules/Anchors.lua`) left the list through `AM-ATS-05` (CCN 15 → 7). The five
  that remain are `standUp` (`core/LifecycleSetup.lua@105-122`), `ContainerClass`
  (`modules/Container.lua@592-600`), `Preview.Offset` (`modules/Preview.lua@47-72`), `tintColorMap`
  (`modules/Style_Text.lua@474-487`) and `entryHelp` (`tests/test_pages_filters.lua@102-124`).
  None is warned, but a branch added to any of them would block the release gate.
- **band files:** 12 → 9. Three files left the band: `tests/test_anchors.lua` 1481 → 815
  (`AM-ATS-02`), `settings/GeneralSpells.lua` 1480 → under 1000 (`AM-ATS-03`) and
  `modules/Anchors.lua` 1243 → 890 (`AM-ATS-04`). None of the files they were peeled into is in the
  band. The nine that remain are unchanged in LOC. Nothing newly crossed.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None. `lizard` reports 0 warnings ([`complexity.txt`](complexity.txt): "No thresholds exceeded").

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/Database.lua` | 1327 | Accepted (carried): size, not tangle. 87 functions, max CCN 14 (`Database.MigrateV5`) |
| 1000–1500 (on notice) | `defaults/Categories.lua` | 1282 | Accepted (carried): data, not logic. 7 functions, max CCN 4 |
| 1000–1500 (on notice) | `tests/test_filtercompiler.lua` | 1271 | Accepted (carried): case count, 85 cases, max CCN 5 |
| 1000–1500 (on notice) | `tests/test_style.lua` | 1203 | Accepted (carried): case count, 60 cases, max CCN 7 |
| 1000–1500 (on notice) | `tests/test_database.lua` | 1194 | Accepted (carried): case count, 73 cases, max CCN 4 |
| 1000–1500 (on notice) | `tests/test_pages_filters.lua` | 1085 | Accepted (carried): case count, 49 cases; `entryHelp` at CCN 15 |
| 1000–1500 (on notice) | `tests/test_containermanager.lua` | 1053 | Accepted (carried): case count, 53 cases, max CCN 4 |
| 1000–1500 (on notice) | `settings/Schema.lua` | 1035 | Accepted (carried): 62 functions, max CCN 13 |
| 1000–1500 (on notice) | `modules/Style.lua` | 1018 | Accepted (carried): 65 functions, max CCN 13 |

The Disposition cells in `RESULTS.md` were refreshed to today's figures. Two case counts in the
carried text were stale: `tests/test_pages_filters.lua` now has 49 cases (the cell said 48), and
`tests/test_style.lua` has 60 (the cell said 59). The four "newly crossed" cells now read "in the
band since `20260926-160451`". No ruling changed.

**Shelf life:** there is still no release run (every row is 0.1.0 and there are no tags), so no
*Accepted* entry has been carried across three release runs.

## Actions

None new. The previous run's four actions are closed: the perf rise was reversed by `AM-ATS-01`
(not bisected), and `tests/test_anchors.lua`, `settings/GeneralSpells.lua` and
`modules/Anchors.lua` were peeled (`AM-ATS-02`/`03`/`04`). The five remaining CCN-15 functions are
still worth watching before the first tag.
