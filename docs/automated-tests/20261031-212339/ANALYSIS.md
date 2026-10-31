# Analysis — 20261031-212339

- **Addon:** AuraMaster 1.1.0
- **Verdict:** green
- **Commit:** 16cf393 (feat/2026-10-31-findings-remediation)
- **Previous run:** [`20261031-202022`](../20261031-202022/ANALYSIS.md)

## Headline

This post-remediation run is green: all four suites pass, no function is above CCN 15, and `lizard`
was sighted in every file with no crash ([`manifest.json`](manifest.json)). The 1000–1500 band fell
from 14 files to 6, while the test count held at 2250 and perf's `api/iter` and `bytes/iter` did not
move in any scenario. No band entry is new, so no disposition was owed, and nothing needs a code change.

## Suites

| Suite | Status | Result | Artifact | Moved since `20261031-202022` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 201 files | [`lint.txt`](lint.txt) | 193 → 201 files, still 0/0 |
| tests | pass | 2249 passed, 1 skipped, 0 failed, 2250 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | Unchanged at 2250 cases; skipped unchanged at 1 |
| perf | pass | 12 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 12 scenarios; `api/iter` and `bytes/iter` unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | Averages held apart from avg tokens; band 14 → 6 |

| Metric | Value |
|---|---|
| Total NLOC | 55169 |
| Functions | 5992 |
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

The averages held while the totals rose slightly, so the addon gained a little size and no density.
Avg tokens fell from 75.7 to 75.6.

Tests pass with one skip, which is pre-existing and not a pass: the diagnostics contract case for an
addon that opts out of logging, skipped because this addon keeps the default
([`tests.txt`](tests.txt)). It was also skipped at the previous run. At the release gate a skip is
NOT EVALUATED.

## What moved

- **lint:** 193 → 201 files, still 0 warnings and 0 errors.
- **tests:** did not move. 2249 passed, 1 skipped, 0 failed, 2250 total. The band splits moved cases
  between files without changing the count.
- **perf:** the scenario count held at 12, and `api/iter` and `bytes/iter` are identical in every
  scenario. `ms/iter` is lower in ten of twelve (for example `applyPass` 1.85437 → 1.49434 and
  `restyleTextGlow` 3.84614 → 3.45817), `emptyWatchAura` is unchanged at 0.00005 and `unitSwap` rose
  0.00332 → 0.00344. Offline timing varies between runs, so this is not read as a speedup.
- **complexity:** NLOC 55057 → 55169, functions 5977 → 5992, avg tokens 75.7 → 75.6. Avg NLOC (8.3),
  avg CCN (2.3), max CCN (15) and warnings (0) did not move. Blind and crashed files stayed at 0.
- **band:** 14 → 6 files. The eight entries the previous `RESULTS.md` marked as split on FX-AM-SIZE
  have left: `modules/Style.lua`, `settings/Schema.lua`, `tests/test_containermanager.lua`,
  `tests/test_database.lua`, `tests/test_filtercompiler.lua`, `tests/test_pages_filters.lua`,
  `tests/test_style.lua` and `tests/test_style_text.lua`. Nothing entered the band, and over-cap
  files stayed at 0.

## Complexity watch list

**Functions `lizard` warned on:**

None.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/Database_Migrations.lua` | 1076 | Carried forward, Accepted; see `RESULTS.md` |
| 1000–1500 (on notice) | `defaults/Categories.lua` | 1344 | Carried forward, tracked deviation (`docs/ARCHITECTURE.md`, FX-AM-SIZE); see `RESULTS.md` |
| 1000–1500 (on notice) | `modules/Anchors.lua` | 1068 | Carried forward, Accepted; see `RESULTS.md` |
| 1000–1500 (on notice) | `modules/Anchors_Snap.lua` | 1156 | Carried forward, Accepted; see `RESULTS.md` |
| 1000–1500 (on notice) | `modules/Container.lua` | 1020 | Carried forward, Accepted; see `RESULTS.md` |
| 1000–1500 (on notice) | `settings/Filters.lua` | 1018 | Carried forward, Accepted; see `RESULTS.md` |

The runner carried all six dispositions forward and left no cell blank.

## Actions

None.
