# Analysis — 20261009-191725

- **Addon:** AuraMaster 1.0.1, release run for 1.1.0
- **Verdict:** green
- **Commit:** ad636a2 (master)
- **Previous run:** [`20260927-214918`](../20260927-214918/ANALYSIS.md)

## Headline

This is the 1.1.0 release run, and it passes the release gate: lint, tests, perf and complexity all
pass, no function is above CCN 15, and `lizard` was sighted in every file (`blindFiles` 0)
([`manifest.json`](manifest.json)). Since the 1.0.1 release run the addon grew by about a fifth
(drag to attach, the Situations tab, spell-list views, the CC split, `/am redraw`) while its averages
held. One file newly entered the 1000–1500 line band and one left it, and eight band entries have now
been carried as Accepted across three consecutive release runs, which the Actions below take up.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260927-214918` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 174 files | [`lint.txt`](lint.txt) | 146 → 174 files, still 0/0 |
| tests | pass | 2058 passed, 1 skipped, 0 failed, 2059 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1702 → 2059 cases; 0 → 1 skipped |
| perf | pass | 11 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same scenarios; `api/iter` unchanged in every one |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | grew in size, averages held |

| Metric | Value |
|---|---|
| Total NLOC | 49857 |
| Functions | 5459 |
| Avg NLOC / function | 8.3 |
| Avg CCN | 2.3 |
| Max CCN | 15 |
| Avg tokens / function | 75.6 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 10 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

The tests suite passed with one case skipped. The skip is the kit's diagnostics-contract case for an
addon that opts out of turning logging on; this addon keeps the default, so the case does not apply
and the case beside it covers the default ([`tests.txt`](tests.txt), the `SKIP` line). It is a
standing fact about the kit case, not a regression and not a coverage gap. The skip is counted in the
total and not in `passed`. Every other suite passed cleanly.

## What moved

Against the previous run, [`20260927-214918`](../20260927-214918/ANALYSIS.md), the 1.0.1 release run
at b5208f3:

- lint: 146 → 174 files in scope, still 0 warnings / 0 errors ([`lint.txt`](lint.txt)).
- tests: 1702 → 2059 cases; 2058 pass and 1 is skipped, as above.
- complexity: NLOC 41031 → 49857 and functions 4472 → 5459. Avg NLOC per function 8.2 → 8.3, avg CCN
  2.3 unchanged, avg tokens 72.4 → 75.6. Max CCN stays 15 and warnings stay 0. The addon grew; it did
  not get noticeably denser.
- band: 10 → 10 files. `core/Database.lua` left it (the frozen migrations moved to
  `core/Database_Migrations.lua`), and `modules/Anchors_Snap.lua` (1138 lines) entered it. The other
  nine entries changed size within the band.
- perf: the same 11 scenarios, and `api/iter` is identical in every one ([`perf.txt`](perf.txt)).
  `bytes/iter` rose in `compile` (3576.0 → 4136.0), `applyPass` (104403.4 → 107620.5) and `restyle`
  (50203.5 → 50333.5), and held elsewhere. The `ms/iter` figures are higher across the board, and
  `perf.txt` says those timings are for orientation within a run only.
- `blindFiles` is 0 here; the previous manifest carried no figure for it.

## Complexity watch list

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Anchors_Snap.lua` | 1138 | Accepted. New in the band at this run (a new file, the snap core for drag to attach, #22); 60 functions, max CCN 15 (`classify`, at the threshold, not over it). The pair pick is the next seam if it grows |
| 1000–1500 (on notice) | `defaults/Categories.lua` | 1344 | Accepted, third consecutive release run (1282 → 1344, the CC split); data, not logic: 8 functions, max CCN 4 |
| 1000–1500 (on notice) | `modules/Style.lua` | 1024 | Accepted, third consecutive release run (1021 → 1024); 66 functions, max CCN 13 |
| 1000–1500 (on notice) | `settings/Schema.lua` | 1057 | Accepted, third consecutive release run (1035 → 1057); 63 functions, max CCN 13 |
| 1000–1500 (on notice) | `tests/test_containermanager.lua` | 1074 | Accepted, third consecutive release run; 54 cases, max CCN 4 |
| 1000–1500 (on notice) | `tests/test_database.lua` | 1197 | Accepted, third consecutive release run; 73 cases, max CCN 4 |
| 1000–1500 (on notice) | `tests/test_filtercompiler.lua` | 1311 | Accepted, third consecutive release run; 85 cases, max CCN 5 |
| 1000–1500 (on notice) | `tests/test_pages_filters.lua` | 1184 | Accepted, third consecutive release run; 52 cases, max CCN 15 (`entryHelp`) |
| 1000–1500 (on notice) | `tests/test_style.lua` | 1205 | Accepted, third consecutive release run; 60 cases, max CCN 7 |
| 1000–1500 (on notice) | `tests/test_style_text.lua` | 1023 | Accepted, second release run; 56 cases, max CCN 6 |

`RESULTS.md` carries the full disposition text for each row.

## Actions

1. Eight band entries (`defaults/Categories.lua`, `modules/Style.lua`, `settings/Schema.lua`,
   `tests/test_containermanager.lua`, `tests/test_database.lua`, `tests/test_filtercompiler.lua`,
   `tests/test_pages_filters.lua`, `tests/test_style.lua`) have been Accepted at the 1.0.0, 1.0.1 and
   1.1.0 release runs. Anti-pattern #53 owes each a fix (a split below 1000 lines) or a tracked
   deviation ID in `docs/ARCHITECTURE.md` → `## Documented deviations`. This is new here; no issue
   tracks it yet.
