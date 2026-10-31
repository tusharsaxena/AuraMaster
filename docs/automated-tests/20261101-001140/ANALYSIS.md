# Analysis — 20261101-001140

- **Addon:** AuraMaster 1.1.0
- **Verdict:** green
- **Commit:** b37c794 (feat/2026-10-31-findings-remediation)
- **Previous run:** [`20261031-212339`](../20261031-212339/ANALYSIS.md)

## Headline

This `v1.84.0-adoption` run is green: all four suites pass, no function is above CCN 15, and `lizard`
was sighted in every file with no crash ([`manifest.json`](manifest.json)). The test count rose from
2250 to 2254 with the adoption's new cases, and perf's `api/iter` and `bytes/iter` did not move in any
scenario. No watch-list entry is new, so no disposition was owed, and nothing needs a code change.

## Suites

| Suite | Status | Result | Artifact | Moved since `20261031-212339` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 201 files | [`lint.txt`](lint.txt) | Unchanged at 201 files, 0/0 |
| tests | pass | 2253 passed, 1 skipped, 0 failed, 2254 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 2250 → 2254 cases; skipped unchanged at 1 |
| perf | pass | 12 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 12 scenarios; `api/iter` and `bytes/iter` unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | Totals rose slightly; averages, max CCN and band count held |

| Metric | Value |
|---|---|
| Total NLOC | 55273 |
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

Every average held while the totals rose, so the addon gained a little size and no density.

Tests pass with one skip, which is pre-existing and not a pass: the diagnostics contract case for an
addon that opts out of logging, skipped because this addon keeps the default
([`tests.txt`](tests.txt)). It was also skipped at the previous run. At the release gate a skip is
NOT EVALUATED.

## What moved

- **lint:** did not move. 201 files, 0 warnings and 0 errors.
- **tests:** 2250 → 2254 total, 2249 → 2253 passed, 1 skipped and 0 failed unchanged. The four new
  cases are two in `test_anchors_width.lua` (the cached label keyed by the strip's scale, and a scale
  that reads secret), one in `test_pages_bars.lua` (the Icon rows dropped under Hidden) and one in
  `test_pages_text.lua` (Icon position and Effect redrawing an open page through the library's
  watch). Two existing `test_pages_text.lua` names were reworded, because the loop and Icon rows
  are now dropped where they used to be dimmed ([`test-cases.md`](test-cases.md)).
- **perf:** the scenario count held at 12, and `api/iter` and `bytes/iter` are identical in every
  scenario. `ms/iter` rose in eight of twelve and fell in four (for example `applyPass` 1.49434 →
  1.68022, `probeOverheadOn` 0.02321 → 0.03130 and `unitSwap` 0.00344 → 0.00339). Offline timing
  varies between runs and the work counters did not change, so this is not read as a slowdown, just
  as the previous run's lower timings were not read as a speedup.
- **complexity:** NLOC 55169 → 55273, functions 5992 → 6003. Avg NLOC (8.3), avg CCN (2.3), avg tokens
  (75.6), max CCN (15) and warnings (0) did not move. Blind and crashed files stayed at 0.
- **band:** held at 6 files, 0 over the cap. Nothing entered or left. `modules/Anchors.lua` grew 1068 →
  1078 inside the band, with its maximum still `Anchors.FlowRoot` at CCN 13.

## Complexity watch list

**Functions `lizard` warned on:**

None.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/Database_Migrations.lua` | 1076 | Carried forward, Accepted; see `RESULTS.md` |
| 1000–1500 (on notice) | `defaults/Categories.lua` | 1344 | Carried forward, tracked deviation (`docs/ARCHITECTURE.md`, FX-AM-SIZE); see `RESULTS.md` |
| 1000–1500 (on notice) | `modules/Anchors.lua` | 1078 | Carried forward, Accepted, function count corrected from 71 to 72; see `RESULTS.md` |
| 1000–1500 (on notice) | `modules/Anchors_Snap.lua` | 1156 | Carried forward, Accepted; see `RESULTS.md` |
| 1000–1500 (on notice) | `modules/Container.lua` | 1020 | Carried forward, Accepted; see `RESULTS.md` |
| 1000–1500 (on notice) | `settings/Filters.lua` | 1018 | Carried forward, Accepted; see `RESULTS.md` |

The runner carried all six dispositions forward and left no cell blank. One figure in the
`modules/Anchors.lua` cell had gone stale and was corrected from [`complexity.txt`](complexity.txt).

## Actions

None.
