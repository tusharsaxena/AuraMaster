# Analysis — 20261101-210026

- **Addon:** AuraMaster 1.1.0 (label `final review findings`, not a release run)
- **Verdict:** green
- **Commit:** ce2e6cc (feat/2026-11-01-full-skinning), clean tree
- **Previous run:** 20261101-201519

## Headline

The run records FS-AM-GATE: the two backfilled-channel rows name A7 in place of the undefined FS-AM-01. One new case holds every row to a defined cause. Lint 0/0 over 205 files, 2336 passed and 0 failed of 2337 tests, 12 perf scenarios at `pass`, complexity at `pass` with max CCN 15 ([`manifest.json`](manifest.json)). Nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-201519 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 205 files | [`lint.txt`](lint.txt) | files unchanged |
| tests | pass | 2336 passed, 1 skipped, 0 failed, 2337 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 2336 → 2337 |
| perf | pass | 12 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | see below |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 56403 → 56414, functions 6138 → 6139 |

**Complexity is reported in full**, from `manifest.json`'s `suites.complexity`:

| Metric | Value |
|---|---|
| Total NLOC | 56414 |
| Functions | 6139 |
| Avg NLOC / function | 8.3 |
| Avg CCN | 2.3 |
| Max CCN | 15 |
| Avg tokens / function | 75.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.0 / 0.0 |
| Files in the 1000–1500 band | 7 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

The one skipped case is the same pre-existing skip as the previous run, NOT EVALUATED at the release gate.

## What moved

- **lint**: files unchanged, still 0/0.
- **tests**: total 2336 → 2337, passed 2335 → 2336, skipped unchanged, failed unchanged. `tests/test_skin_fix.lua` gains `skin gate: every allow row names a cause of the run's SKIN_CAUSES.md, or MC`, red against the old rows.
- **perf**: calls and bytes per iteration unchanged on every scenario. `ms/iter` moves are timing noise between runs.
- **complexity**: average CCN unchanged, average tokens unchanged, max CCN unchanged.

## Watch list

See `RESULTS.md`: no entry newly crossed a threshold (0 functions above CCN 15).
