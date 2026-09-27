# Analysis — 20260927-214918

- **Addon:** AuraMaster 1.0.0, release run for 1.0.1
- **Verdict:** green
- **Commit:** b5208f3 (master)
- **Previous run:** [`20260927-214805`](../20260927-214805/ANALYSIS.md)

## Headline

This is the 1.0.1 release run, and it passes the release gate: lint, tests, perf and complexity all
pass, and no function is above CCN 15 ([`manifest.json`](manifest.json)). The previous run was refused
for a single failing test. It was the eol test, tripped by a bare LF in a perf-capture `dump.json`
working copy; that file was re-checked out before this run, and the same 1702 cases now all pass.
Against the 1.0.0 release run, one file newly entered the 1000–1500 line band, and its disposition is
in the watch list below.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260927-214805` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 146 files | [`lint.txt`](lint.txt) | unchanged |
| tests | pass | 1702 passed, 0 skipped, 0 failed, 1702 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1701 → 1702 passed; the eol failure is gone |
| perf | pass | 11 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same scenarios; `api/iter` and `bytes/iter` unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | unchanged |

| Metric | Value |
|---|---|
| Total NLOC | 41031 |
| Functions | 4472 |
| Avg NLOC / function | 8.2 |
| Avg CCN | 2.3 |
| Max CCN | 15 |
| Avg tokens / function | 72.4 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.0 / 0.0 |
| Files in the 1000–1500 band | 10 |
| Files over the 1500 cap | 0 |

Every suite passed cleanly.

## What moved

Against the previous run, [`20260927-214805`](../20260927-214805/ANALYSIS.md): that run measured
4e03d41, and the only commit between the two is its own record. So nothing in the source moved. The
test result went from 1701 passed and 1 failed to 1702 passed. Lint, the complexity footer and the band
count are identical. The perf `ms/iter` figures shifted within run-to-run noise, and `perf.txt` itself
says they are for orientation only.

Against the 1.0.0 release run, [`20260927-015127`](../20260927-015127/ANALYSIS.md), which is the
comparison this release is really about:

- lint: 144 → 146 files, still 0/0, from the new `modules/FontPrimer.lua` and its suite.
- tests: 1665 → 1702 cases, all passing.
- complexity: NLOC 40071 → 41031 and functions 4367 → 4472, while the averages held (8.2 NLOC,
  CCN 2.3, 72.4 tokens per function). The addon grew and did not get denser.
- band: 9 → 10 files, because `tests/test_style_text.lua` reached 1016 lines.
- perf: the same 11 scenarios, with `api/iter` and `bytes/iter` identical in every one
  ([`perf.txt`](perf.txt)).

## Complexity watch list

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_style_text.lua` | 1016 | Accepted. New in the band at this run (998 → 1016, from the case that pins the text measures to `Style.FontKey`); case count, not tangle: 56 `test(` cases, no function above CCN 8 |
| 1000–1500 (on notice) | `modules/Style.lua` | 1021 | Accepted. Disposition refreshed: 1031 → 1021 since the 1.0.0 release run (`Style.MeasuredTimeWidths` removed, `Style.FontKey` added); 67 functions, max CCN 13 |

The other eight band files are unchanged, and `RESULTS.md` carries their dispositions forward. None
of them has now been Accepted across three consecutive release runs: this is the second release run
since the band dispositions were first written, at `20260926-160451`.

## Actions

None.
