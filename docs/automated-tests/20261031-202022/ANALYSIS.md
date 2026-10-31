# Analysis — 20261031-202022

- **Addon:** AuraMaster 1.1.0
- **Verdict:** green
- **Commit:** 472da8f (feat/2026-10-31-font-pickers-skin-faces)
- **Previous run:** [`20261009-191725`](../20261009-191725/ANALYSIS.md)

## Headline

This pre-merge run is green: all four suites pass, no function is above CCN 15, and `lizard` was
sighted in every file with no crash ([`manifest.json`](manifest.json)). Since the 1.1.0 release run the
addon grew by about a tenth and its averages held, apart from avg tokens moving 75.6 → 75.7. Nothing
needs a code change. Four files newly entered the 1000–1500 band, taking it from 10 to 14, and each
now has a disposition. The eight band entries Accepted across three release runs are still neither
fixed nor tracked.

## Suites

| Suite | Status | Result | Artifact | Moved since `20261009-191725` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 193 files | [`lint.txt`](lint.txt) | 174 → 193 files, still 0/0 |
| tests | pass | 2249 passed, 1 skipped, 0 failed, 2250 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 2059 → 2250 cases; skipped unchanged at 1 |
| perf | pass | 12 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 11 → 12 scenarios; `api/iter` up in four, see below |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | grew in size, averages held |

| Metric | Value |
|---|---|
| Total NLOC | 55057 |
| Functions | 5977 |
| Avg NLOC / function | 8.3 |
| Avg CCN | 2.3 |
| Max CCN | 15 |
| Avg tokens / function | 75.7 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 14 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

The tests suite passed with one case skipped, the same one as the previous run: the kit's
diagnostics-contract case for an addon that opts out of turning logging on. This addon keeps the
default, so the case does not apply and the case above it covers the default ([`tests.txt`](tests.txt),
the `SKIP` line). It is a standing fact about that kit case and is not a regression. It is counted in
the total and not in `passed`. Every other suite passed cleanly.

## What moved

Against the previous run, [`20261009-191725`](../20261009-191725/ANALYSIS.md), the 1.1.0 release run at
ad636a2:

- lint: 174 → 193 files in scope, still 0 warnings / 0 errors ([`lint.txt`](lint.txt)).
- tests: 2059 → 2250 cases; 2249 pass and 1 is skipped, as before ([`tests.txt`](tests.txt)).
- complexity: NLOC 49857 → 55057 and functions 5459 → 5977. Avg NLOC per function 8.3 and avg CCN 2.3
  are unchanged, and avg tokens moved 75.6 → 75.7. Max CCN stays 15 and warnings stay 0. The addon grew;
  it did not get denser ([`complexity.txt`](complexity.txt)).
- `crashedFiles` is 0 here; the previous manifest carried no figure for it. `blindFiles` stays 0.
- band: 10 → 14 files, none left and four entered: `core/Database_Migrations.lua` (1076),
  `modules/Anchors.lua` (1068), `modules/Container.lua` (1020) and `settings/Filters.lua` (1018). The
  other ten stayed in the band. Over the cap stays 0.
- perf: 11 → 12 scenarios, the new one being `restyleTextGlow`. `api/iter` rose in `visibilityPass`
  (4.0 → 8.0), `probeOverheadOff`, `probeOverheadOn` and `probeAbsent` (each 5.0 → 9.0) and held in the
  other scenarios. That is the scenario gaining engines, not a pass getting chattier: `tests/perf.lua`
  now counts one `SetEnabled` per engine, and its fixture turns on the text glow, whose twin engines
  (`modules/Container_Twins.lua`, TG-11) join the count. `bytes/iter` fell in `applyPass`
  (107620.5 → 104452.5), `restyle` (50333.5 → 39125.5) and `restyleText` (31587.6 → 27747.6), and held
  elsewhere in the scenarios both runs share ([`perf.txt`](perf.txt)). `ms/iter` is not compared across
  runs, because `perf.txt` says those timings are for orientation within a run.

## Complexity watch list

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/Database_Migrations.lua` | 1076 | Accepted. New in the band; frozen schema steps, 50 functions, max CCN 15 (`Database.MigrateV15`, at the threshold, not over it) |
| 1000–1500 (on notice) | `modules/Anchors.lua` | 1068 | Accepted. New in the band; one concern, 71 functions, max CCN 13 (`Anchors.FlowRoot`) |
| 1000–1500 (on notice) | `modules/Container.lua` | 1020 | Accepted. New in the band; one live container's lifecycle, 64 functions, max CCN 15 (`ContainerClass.ApplyHang`, at the threshold, not over it) |
| 1000–1500 (on notice) | `settings/Filters.lua` | 1018 | Accepted. New in the band; one settings page, 49 functions, max CCN 11 (`viewWhich`) |
| 1000–1500 (on notice) | `modules/Anchors_Snap.lua` | 1156 | Carried: Accepted, first release run counted at 1.1.0 |
| 1000–1500 (on notice) | `tests/test_style_text.lua` | 1023 | Carried: Accepted, second release run counted at 1.1.0 |
| 1000–1500 (on notice) | `defaults/Categories.lua` | 1344 | Carried: third consecutive release run, owed a fix or a tracked deviation |
| 1000–1500 (on notice) | `modules/Style.lua` | 1076 | Carried: third consecutive release run, owed a fix or a tracked deviation |
| 1000–1500 (on notice) | `settings/Schema.lua` | 1057 | Carried: third consecutive release run, owed a fix or a tracked deviation |
| 1000–1500 (on notice) | `tests/test_containermanager.lua` | 1074 | Carried: third consecutive release run, owed a fix or a tracked deviation |
| 1000–1500 (on notice) | `tests/test_database.lua` | 1200 | Carried: third consecutive release run, owed a fix or a tracked deviation |
| 1000–1500 (on notice) | `tests/test_filtercompiler.lua` | 1311 | Carried: third consecutive release run, owed a fix or a tracked deviation |
| 1000–1500 (on notice) | `tests/test_pages_filters.lua` | 1198 | Carried: third consecutive release run, owed a fix or a tracked deviation |
| 1000–1500 (on notice) | `tests/test_style.lua` | 1211 | Carried: third consecutive release run, owed a fix or a tracked deviation |

`RESULTS.md` carries the full disposition text for each row. This is not a release run, so it does not
add to any entry's release-run count.

## Actions

1. The eight third-run band entries (`defaults/Categories.lua`, `modules/Style.lua`,
   `settings/Schema.lua`, `tests/test_containermanager.lua`, `tests/test_database.lua`,
   `tests/test_filtercompiler.lua`, `tests/test_pages_filters.lua`, `tests/test_style.lua`) are still
   owed a split below 1000 lines or a tracked deviation ID in `docs/ARCHITECTURE.md` →
   `## Documented deviations`. This carries the previous run's Action 1 forward; no deviation row or
   issue tracks it yet.
