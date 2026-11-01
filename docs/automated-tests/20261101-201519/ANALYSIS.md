# Analysis — 20261101-201519

- **Addon:** AuraMaster 1.1.0
- **Verdict:** green
- **Commit:** 72c566c (feat/2026-11-01-full-skinning)
- **Previous run:** [`20261101-145411`](../20261101-145411/ANALYSIS.md)

## Headline

This `full-skinning` run is green: all four suites pass, no function is above CCN 15, and `lizard` was
sighted in every file with no crash ([`manifest.json`](manifest.json)). It measures the re-cut LibKa0s
v1.85.0, kit revision 50's two skin suites and the bar border rulings: 53 more cases and one more
linted file. The band and every perf `api/iter` hold, and `bytes/iter` barely moves.

## Suites

| Suite | Status | Result | Artifact | Moved since `20261101-145411` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 205 files | [`lint.txt`](lint.txt) | 204 → 205 files, still 0/0 |
| tests | pass | 2335 passed, 1 skipped, 0 failed, 2336 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 2283 → 2336 total; the skip is unchanged |
| perf | pass | 12 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | `api/iter` unchanged; `bytes/iter` up by under 20 |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC +353, functions +63; averages and max held; band 7 |

| Metric | Value |
|---|---|
| Total NLOC | 56403 |
| Functions | 6138 |
| Avg NLOC / function | 8.3 |
| Avg CCN | 2.3 |
| Max CCN | 15 |
| Avg tokens / function | 75.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 7 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Tests pass with one skip, which is pre-existing and not a pass: the diagnostics contract case for an
addon that opts out of logging, skipped because this addon keeps the default
([`tests.txt`](tests.txt)). At the release gate a skip is NOT EVALUATED.

## What moved

- **lint:** 204 → 205 files, 0/0. Two authored test files came (`tests/skin_gate.lua`,
  `tests/test_skin_border.lua`) and one went (`tests/test_skin_literals.lua`).
- **tests:** 2283 → 2336 total, 2282 → 2335 passed, 1 skipped, 0 failed. The kit's `test_skin_values` and
  `test_skin_switch` replace the old three-case color gate, and `test_skin_border` pins the None and
  real-style arms.
- **perf:** 12 scenarios, `api/iter` identical in every scenario. `bytes/iter`: `applyPass` 105892.5 →
  105911.3, `restyle` 45653.5 → 45654.4, `restyleText` 32067.7 → 32068.1 and `restyleTextGlow` 144963.7 →
  144964.1. Timings compare within a run, not across them.
- **complexity:** NLOC 56050 → 56403, functions 6075 → 6138, avg NLOC 8.3, avg CCN 2.3, max CCN 15 and avg
  tokens 75.8 held. Warnings stayed 0, and blind and crashed files stayed 0.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/Database_Migrations.lua` | 1146 | Accepted, carried forward |
| 1000–1500 (on notice) | `defaults/Categories.lua` | 1344 | Accepted as a tracked deviation, carried forward |
| 1000–1500 (on notice) | `modules/Anchors.lua` | 1078 | Accepted, carried forward |
| 1000–1500 (on notice) | `modules/Anchors_Snap.lua` | 1156 | Accepted, carried forward |
| 1000–1500 (on notice) | `modules/Container.lua` | 1021 | Accepted, carried forward |
| 1000–1500 (on notice) | `settings/Filters.lua` | 1018 | Accepted, carried forward |
| 1000–1500 (on notice) | `settings/Schema.lua` | 1017 | Accepted, carried forward; split if it grows again |

## Actions

None here. A real border under each skin, a textured edge on a live button and the row states are
in-client checks this offline run cannot see: SKIN-36, SKIN-38 and SKIN-40 in `docs/smoke-tests.md` are
the owner's.
