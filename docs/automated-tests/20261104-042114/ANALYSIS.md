# Analysis — 20261104-042114

- **Addon:** AuraMaster 1.1.0 (round 6 finish run, labelled "R6 finish", not a release run)
- **Verdict:** green
- **Commit:** c9c3a97 (feat/2026-11-01-full-skinning), clean tree
- **Previous run:** 20261102-004743 (at 7bd52a2, 22 commits behind this one)

## Headline

This run records the full skinning branch at the end of round 6: the skin picker previews in test mode and every close route restores it (R6-PV), the launcher menu's Open skin selector entry, the v18 migration of Ka0s Friz Quadrata TT to Ka0s Ubuntu, the HUD icon edges pinned to `icon.border`, and the LibKa0s v1.85.0 re-cuts through R6-RV2. Lint is 0/0 over 207 files and 2355 of 2356 tests pass with 0 failed. All 12 perf scenarios are at `pass`, and complexity is at `pass` with max CCN 15, 0 warnings, 0 blind and 0 crashed files ([`manifest.json`](manifest.json)). Nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261102-004743 |
|---|---|---|---|---|
| lint (gates commit and tag) | pass | 0 warnings / 0 errors in 207 files | [`lint.txt`](lint.txt) | files 206 → 207 |
| tests (gates commit and tag) | pass | 2355 passed, 1 skipped, 0 failed, 2356 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 2344 → 2356 |
| perf (recorded; gates the tag only) | pass | 12 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | see below |
| complexity (recorded; gates the tag only) | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 56543 → 56743, functions 6150 → 6195 |

| Metric | Value |
|---|---|
| Total NLOC | 56743 |
| Functions | 6195 |
| Avg NLOC / function | 8.2 |
| Avg CCN | 2.3 |
| Max CCN | 15 |
| Avg tokens / function | 75.5 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 7 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Every suite is a clean pass. The one skipped case is the same pre-existing skip as in the previous run. It is counted in the total and not in `passed`, and at a release it reads as NOT EVALUATED.

## What moved

- **lint**: 206 → 207 files. The new file is `tests/test_launcher_skin_entry.lua`, and the count is still 0/0.
- **tests**: 2344 → 2356 (+12). The new cases cover the skin picker's test-mode preview and the restore on each close route (Apply, Apply to all, Escape, the close control, the gear, `HideSkinPicker`), the launcher descriptor's `openSkinPicker`, the v18 Friz to Ubuntu migration and the HUD icon edges reading `icon.border`. Three existing picker cases were reworded to the new eye-toggle behaviour (diff of the two [`test-cases.md`](test-cases.md) inventories).
- **perf**: same 12 scenarios, and `api/iter` and `bytes/iter` are identical for every one ([`perf.json`](perf.json)). `ms/iter` moved inside run-to-run noise on a sub-4 ms scale. The largest relative move is `probeOverheadOn`, 0.02461 → 0.03637 ms/iter, with an unchanged API count and allocation. No changed code sits on a perf path apart from the skin seam in `core/SkinSetup.lua`, and `restyle`/`restyleText`/`restyleTextGlow` allocate exactly what they did before.
- **complexity**: +200 NLOC and +45 functions. Avg NLOC/function fell 8.3 → 8.2, avg tokens 75.8 → 75.5, avg CCN held at 2.3 and max CCN at 15. The addon grew without getting denser.

## Complexity watch list

Functions `lizard` warned on: none.

Files by band: the same 7 files as the previous run, each with its disposition carried forward unchanged in `RESULTS.md`. `core/Database_Migrations.lua` grew 1181 → 1200 with the v18 step and stays inside the 1000–1500 band. Nothing newly crossed a threshold and no disposition is blank. This is not a release run, so it does not add to the three-release shelf life of any **Accepted** entry.

## Actions

None.
