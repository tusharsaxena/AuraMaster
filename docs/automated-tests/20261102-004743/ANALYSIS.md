# Analysis — 20261102-004743

- **Addon:** AuraMaster 1.1.0 (smoke feedback run, not a release run)
- **Verdict:** green
- **Commit:** 7bd52a2 (feat/2026-11-01-full-skinning), clean tree
- **Previous run:** 20261101-210026

## Headline

The run records SF-AM-1 to SF-AM-3: the text glow, a bar's background and border color, the bar fill, the Text font color and the icon border colors default off the skin, and schema v17 moves a stored container still holding the old default. Lint 0/0 over 206 files, 2343 passed and 0 failed of 2344 tests, 12 perf scenarios at `pass`, complexity at `pass` with max CCN 15 ([`manifest.json`](manifest.json)). Nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-210026 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 206 files | [`lint.txt`](lint.txt) | files 205 → 206 |
| tests | pass | 2343 passed, 1 skipped, 0 failed, 2344 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 2337 → 2344 |
| perf (recorded, non-gating) | pass | 12 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | see below |
| complexity (recorded, non-gating) | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 56414 → 56543, functions 6139 → 6150 |

| Metric | Value |
|---|---|
| Total NLOC | 56543 |
| Functions | 6150 |
| Avg NLOC / function | 8.3 |
| Avg CCN | 2.3 |
| Max CCN | 15 |
| Avg tokens / function | 75.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.0 / 0.0 |
| Files in the 1000–1500 band | 7 |
| Files over the 1500 cap | 0 |
| Blind files | 0 |
| Crashed files | 0 |

The one skipped case is the same pre-existing skip as before.

## What moved

- **lint**: one new file, `tests/test_defaults_v17.lua`, still 0/0.
- **tests**: 2337 → 2344. Seven new cases in `tests/test_defaults_v17.lua` pin the new defaults and `Database.MigrateV17`; existing suites were adjusted where they read the followed arm.
- **perf**: not re-read case by case; no scenario touches the changed defaults.
- **complexity**: average CCN and tokens unchanged, max CCN unchanged. `Database.MigrateV17` and the v17 step are small.

## Watch list

See `RESULTS.md`: no entry newly crossed a threshold. `core/Database_Migrations.lua` grew inside the 1000–1500 band.
