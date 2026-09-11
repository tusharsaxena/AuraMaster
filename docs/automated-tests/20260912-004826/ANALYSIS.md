# Analysis — 20260912-004826

- **Addon:** AuraMaster 0.1.0
- **Verdict:** green
- **Commit:** 38b8184807caf207df522bd5f220da1491fda5e1 (fix/review-audit-2026-09-11)
- **Previous run:** 20260911-141809

## Headline

All four suites pass, and lint and tests are clean ([`manifest.json`](manifest.json)). Every figure
moved since the previous run because the run sits at the end of the review and audit remediation
branch: the suite grew from 154 to 233 cases, the perf runner gained two scenarios and changed how it
measures allocation, and `lizard` now counts functions it could not see before. Nothing is owed: no
function is above CCN 15 and no file is in a `layout-§1` band.

## Suites

| Suite | Status | Result | Artifact | Moved since 20260911-141809 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 62 files | [`lint.txt`](lint.txt) | No change (0/0 over 62 files) |
| tests | pass | 233 passed, 0 skipped, 0 failed, 233 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 154 → 233 (+79) |
| perf | pass | 9 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 7 → 9 scenarios; allocation method changed (see below) |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | Functions 676 → 981; averages mostly flat |

**Complexity is reported in full** (from [`manifest.json`](manifest.json) `suites.complexity`):

| Metric | Value |
|---|---|
| Total NLOC | 9178 |
| Functions | 981 |
| Avg NLOC / function | 7.6 |
| Avg CCN | 2.8 |
| Max CCN | 15 |
| Avg tokens / function | 59.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.0 / 0.0 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |

Every suite is a clean pass, so there is no failure or skip paragraph to write.

## What moved

- **tests:** 154 → 233 cases, all passing, none skipped ([`tests.txt`](tests.txt),
  [`test-cases.md`](test-cases.md)). The new cases pin the remediation's fixes: deferred teardown in
  combat, the write seam's section writes, the deferral notice rules, class color per unit,
  TimedSpells' readable-state gate, `/am enable` and `/am disable`, and the lint guards.
- **lint:** unchanged at 0/0 over 62 files ([`lint.txt`](lint.txt)).
- **complexity:** functions 676 → 981 and NLOC 6820 → 9178. Avg CCN is flat at 2.8 and max CCN is 15
  in both runs; avg NLOC/function rose 6.6 → 7.6 and avg tokens 53.8 → 59.8. **The previous run's
  figures were measured blind.** `lizard` 1.24.0 reads Lua's `#` length operator as a C preprocessor
  line and drops the rest of that line, which hid 67 functions from the previous run, three of them
  above CCN 15 (`FC.Compile` 42, `Database.PrepareProfile` about 21,
  `Helpers.RenderContainerPage` 20). Remediation commit `ba7d18a` rewrote the affected lines, split
  the three functions and added a guard case ("lintconfig: no length operator shares its line with a
  keyword or brace lizard must see"); the upstream report is tusharsaxena/WowAddonStandards#6. Part
  of the +305 functions is that restored visibility and part is new code and tests, and this bundle
  cannot separate the two. The previous bundle's "0 warnings, max CCN 15" stands as what was believed
  at the time; it was not true of the code it measured.
- **perf:** two scenarios are new: `probeAbsent`, the instrumentation-absent arm that
  `performance-§9` asks for, and `unitAuraOther` ([`perf.txt`](perf.txt)). With capture off,
  `probeOverheadOff` allocates 288.0 bytes/iter, the same as `probeAbsent` (288.0); capture on is
  288.6. This is the first run whose figures show a dormant bracket costs nothing measurable. The
  **bytes/iter columns are not comparable with the previous run.** Remediation commit `ac2dd12` changed
  the runner so the collector no longer runs inside a measured loop and the engine mock only counts
  its calls. The previous run's restyle figure of −1914.9 bytes/iter was an artifact of the old method
  and is gone; restyle now reads 43221.8. Read this run as the allocation baseline. The `api/iter`
  column, which does not depend on that method, is unchanged for every carried scenario (applyPass
  22.0, visibilityPass 3.0, unitSwap 1.0, probe 4.0).

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|

None.

Nearest the release gate, from [`complexity.txt`](complexity.txt): `Preview.Offset`
(`modules/Preview.lua`) and `Bars.FillPreview` (`modules/Style_Bars.lua`) sit at CCN 15.
`ContainerClass:Apply` (`modules/Container.lua`, listed by `lizard` as `ContainerClass`),
`FP.NamedAncestor`, `Preview.Show` and `TS.Scan` sit at 14. Adding one branch to any of the first
two breaks the release gate.

## Actions

1. `modules/Preview.lua` `Preview.Offset` and `modules/Style_Bars.lua` `Bars.FillPreview` are at CCN
   15, the release-gate limit. The next change to either should extract a helper first. This is new
   here; no deviation ID or review finding tracks it.
