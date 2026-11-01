# Analysis — 20261101-145411

- **Addon:** AuraMaster 1.1.0
- **Verdict:** green
- **Commit:** 1b80e05 (feat/2026-11-01-full-skinning)
- **Previous run:** [`20261101-025540`](../20261101-025540/ANALYSIS.md)

## Headline

This `full-skinning` run is green: all four suites pass, no function is above CCN 15, and `lizard`
was sighted in every file with no crash ([`manifest.json`](manifest.json)). It measures LibKa0s v1.85.0
and the addon's flip onto the skin: 29 more cases, 3 more linted files and one more file in the
1000–1500 band. `restyle` allocates more per pass, recorded below, and no ceiling tripped.

## Suites

| Suite | Status | Result | Artifact | Moved since `20261101-025540` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 204 files | [`lint.txt`](lint.txt) | 201 → 204 files, still 0/0 |
| tests | pass | 2282 passed, 1 skipped, 0 failed, 2283 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 2254 → 2283 total; the skip is unchanged |
| perf | pass | 12 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | `api/iter` unchanged; `bytes/iter` up in four dress scenarios |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC +776, functions +72; averages but tokens held; band 6 → 7 |

| Metric | Value |
|---|---|
| Total NLOC | 56050 |
| Functions | 6075 |
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

- **lint:** 201 → 204 files, 0/0. The three are `tests/own_look.lua`, `tests/test_skin_flip.lua` and
  `tests/test_skin_fix.lua`.
- **tests:** 2254 → 2283 total, 2253 → 2282 passed, 1 skipped, 0 failed. The new cases are the two
  new suites. Existing style suites now read stored values through `tests/own_look.lua`, and the
  earlier ladder suites seed `skin.fullSkinReset`.
- **perf:** the scenario count held at 12 and `api/iter` is identical in every scenario. `bytes/iter`
  rose where a dress runs: `applyPass` 104452.5 → 105892.5, `restyle` 39125.5 → 45653.5, `restyleText`
  27747.6 → 32067.7 and `restyleTextGlow` 140643.6 → 144963.7. The rest did not move. `ms/iter` moved
  both ways; `restyle` went 1.11502 → 1.96545, and timings compare within a run, not across them.
- **complexity:** NLOC 55274 → 56050, functions 6003 → 6075, avg NLOC 8.3, avg CCN 2.3 and max CCN 15
  held, avg tokens 75.6 → 75.8. Warnings stayed 0 and blind and crashed files stayed 0.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/Database_Migrations.lua` | 1146 | Accepted, carried forward; grew by schema v16 |
| 1000–1500 (on notice) | `defaults/Categories.lua` | 1344 | Accepted as a tracked deviation, carried forward |
| 1000–1500 (on notice) | `modules/Anchors.lua` | 1078 | Accepted, carried forward |
| 1000–1500 (on notice) | `modules/Anchors_Snap.lua` | 1156 | Accepted, carried forward |
| 1000–1500 (on notice) | `modules/Container.lua` | 1020 | Accepted, carried forward |
| 1000–1500 (on notice) | `settings/Filters.lua` | 1018 | Accepted, carried forward |
| 1000–1500 (on notice) | `settings/Schema.lua` | 1017 | Accepted, newly in the band; split if it grows again |

## Actions

None here. The gloss, the shadow on a font object and the migration on a real profile are in-client
checks this offline run cannot see: SKIN-35 to SKIN-42 in `docs/smoke-tests.md` are the owner's.
