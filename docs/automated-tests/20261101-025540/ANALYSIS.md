# Analysis — 20261101-025540

- **Addon:** AuraMaster 1.1.0
- **Verdict:** green
- **Commit:** 31133dc (feat/2026-10-31-findings-remediation)
- **Previous run:** [`20261101-001140`](../20261101-001140/ANALYSIS.md)

## Headline

This `final-pre-merge` run is green: all four suites pass, no function is above CCN 15, and `lizard`
was sighted in every file with no crash ([`manifest.json`](manifest.json)). The case inventory is
identical to the previous run's, and perf's `api/iter` and `bytes/iter` did not move, though `ms/iter`
rose in eleven of twelve scenarios. No watch-list entry is new, so no disposition was owed, and
nothing needs a code change.

## Suites

| Suite | Status | Result | Artifact | Moved since `20261101-001140` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 201 files | [`lint.txt`](lint.txt) | Unchanged at 201 files, 0/0 |
| tests | pass | 2253 passed, 1 skipped, 0 failed, 2254 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | Unchanged; the inventory is identical |
| perf | pass | 12 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 12 scenarios; `api/iter` and `bytes/iter` unchanged, `ms/iter` up in eleven |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC +1; functions, averages, max CCN and band count held |

| Metric | Value |
|---|---|
| Total NLOC | 55274 |
| Functions | 6003 |
| Avg NLOC / function | 8.3 |
| Avg CCN | 2.3 |
| Max CCN | 15 |
| Avg tokens / function | 75.6 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 6 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Tests pass with one skip, which is pre-existing and not a pass: the diagnostics contract case for an
addon that opts out of logging, skipped because this addon keeps the default
([`tests.txt`](tests.txt)). It was also skipped at the previous run. At the release gate a skip is
NOT EVALUATED.

## What moved

This run measures the three commits after the previous record: the re-cut LibKa0s v1.84.0 re-vendor,
the removal of `AceGUI-3.0-SharedMediaWidgets` in favor of the `Ka0sMedia_*` pickers, and the SKIN-17
smoke-test correction.

- **lint:** did not move. 201 files, 0 warnings and 0 errors. `libs/` is excluded, so the removed
  widget library was never in this count.
- **tests:** did not move. 2254 total, 2253 passed, 1 skipped and 0 failed, and
  [`test-cases.md`](test-cases.md) matches the previous bundle's line for line. The count holds
  although the suite changed: an existing case in `test_schema_paths.lua` now accepts `Ka0sMedia_*`
  rather than `LSM30_*` as a named control, and pins two composed media rows to
  `Ka0sMedia_Font` and `Ka0sMedia_Border`.
- **perf:** the scenario count held at 12, and `api/iter` and `bytes/iter` are identical in every
  scenario. `ms/iter` rose in eleven of twelve and fell in one (for example `applyPass` 1.68022 →
  2.00861, `restyle` 0.82971 → 1.11502, `visibilityPass` 0.02793 → 0.03747 and `emptyWatchAura`
  0.00006 → 0.00005). The manifest's tests suite duration rose as well, 17663 → 29171 ms, on an
  unchanged case list, which suggests a busier host, but this run does not establish the cause. The
  work counters did not change, so this is not read as a slowdown, and the scenarios bear watching
  at the next run.
- **complexity:** NLOC 55273 → 55274. Functions (6003), avg NLOC (8.3), avg CCN (2.3), avg tokens
  (75.6), max CCN (15), warnings (0), the band count (6) and the over-cap count (0) did not move.
  Blind and crashed files stayed at 0.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

No file's LOC changed since the previous run, and every disposition is carried forward unchanged in
[`RESULTS.md`](../RESULTS.md).

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/Database_Migrations.lua` | 1076 | Accepted, carried forward |
| 1000–1500 (on notice) | `defaults/Categories.lua` | 1344 | Accepted as a tracked deviation, carried forward |
| 1000–1500 (on notice) | `modules/Anchors.lua` | 1078 | Accepted, carried forward |
| 1000–1500 (on notice) | `modules/Anchors_Snap.lua` | 1156 | Accepted, carried forward |
| 1000–1500 (on notice) | `modules/Container.lua` | 1020 | Accepted, carried forward |
| 1000–1500 (on notice) | `settings/Filters.lua` | 1018 | Accepted, carried forward |

## Actions

None. The picker change is a rendering change that this offline run cannot see, so its in-client
check stays with the owner's smoke tests in `docs/smoke-tests.md`.
