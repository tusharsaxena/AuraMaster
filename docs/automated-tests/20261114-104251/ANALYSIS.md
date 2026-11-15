# Analysis — 20261114-104251

- **Addon:** AuraMaster 1.1.0 (the WoW Forever port record, labeled "Forever port AM-FP08", not a release run)
- **Verdict:** green, on both kit profiles
- **Commit:** 5ff012f (feat/2026-11-14-forever-port), clean tree
- **Previous run:** 20261104-042114 (at c9c3a97, 50 commits behind this one)

## Headline

This run records the WoW Forever port branch after the whole-branch review fixes: the client seam in `core/Compat.lua`, the per-client default skin, the Forever seed lists and cast table (`defaults/Categories_Forever.lua`, `defaults/CastToAura_Forever.lua`), the empty-category gate and the `## Interface: 120105, 16001` port surface. The bundle is the Retail profile (the kit default). Lint is 0/0 over 213 files, and 2377 of 2378 tests pass with 0 failed. All 12 perf scenarios are at `pass`, and complexity is at `pass` with max CCN 15, 0 warnings, 0 blind and 0 crashed files ([`manifest.json`](manifest.json)). The Forever profile, run the same way without a bundle, passes too: 2376 passed, 2 skipped, 0 failed. The one thing to act on is a stale deviation row (see Actions).

## Suites

| Suite | Status | Result | Artifact | Moved since 20261104-042114 |
|---|---|---|---|---|
| lint (gates commit and tag) | pass | 0 warnings / 0 errors in 213 files | [`lint.txt`](lint.txt) | files 207 → 213 |
| tests (gates commit and tag) | pass | 2377 passed, 1 skipped, 0 failed, 2378 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 2356 → 2378 |
| tests, Forever profile (gates commit and tag) | pass | 2376 passed, 2 skipped, 0 failed, 2378 total | no artifact: `KA0S_KIT_CLIENT=forever` run with `--no-bundle` (console only) | first Forever record |
| perf (recorded; gates the tag only) | pass | 12 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | see below |
| complexity (recorded; gates the tag only) | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 56743 → 58589, functions 6195 → 6234 |

| Metric | Value |
|---|---|
| Total NLOC | 58589 |
| Functions | 6234 |
| Avg NLOC / function | 8.3 |
| Avg CCN | 2.3 |
| Max CCN | 15 |
| Avg tokens / function | 75.6 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 7 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Every suite is a clean pass on both profiles. AuraMaster is `Retail · Forever` in the roster, so the battery ran twice (`clients-§6`). The Retail run wrote this bundle. The Forever run (`KA0S_KIT_CLIENT=forever tests/_kit/run-automated-tests.sh --no-bundle`) ran all four suites and wrote nothing. Its console reported lint 0/0 in 213 files, tests 2376 passed, 0 failed, 2 skipped of 2378, 12 perf scenarios at `pass`, and complexity at `pass` with the same lizard figures (the kit profile does not change which source lizard reads). Those Forever figures are console output with no artifact in this bundle, which is why they are kept out of the table above.

The Retail skip is the same pre-existing case as in the previous run: the diagnostics contract case for an addon that opts out of logging, skipped because this addon keeps the default ([`tests.txt`](tests.txt)). The Forever profile adds one more, by design: `v12: the frozen split is the shipped CC Root and CC Snare lists exactly` skips because the v12 frozen sets mirror Retail's lists and WoW Forever ships its own seeds. Both skips count toward the total, not toward `passed`, and at a release they read as NOT EVALUATED.

## What moved

- **lint**: 207 → 213 files, still 0/0 ([`lint.txt`](lint.txt)). The six new files are `defaults/CastToAura_Forever.lua`, `defaults/Categories_Forever.lua`, `tests/test_categories_clients.lua`, `tests/test_clients.lua`, `tests/wear_ka0s.lua` and `tools/spell-research/fixtures/forever_categories/Categories.lua`.
- **tests**: 2356 → 2378 (+22, diff of the two [`test-cases.md`](test-cases.md) inventories). Three new suite files: `test_clients.lua` (9 cases: `ClientKey`, `IsForever`/`IsRetail`, `ForClient`, the per-client default skin, and the stand-in without LibKa0s), `test_categories_clients.lua` (10 cases: Retail categories unchanged, Forever seeds picked, coverage, every Polymorph rank in hardCC, no Retail-only class key, the empty-category gate, a gated key in a stored profile, CastToAura per client, user categories) and `test_client_globals.lua` (3 cases: no call of a global a client lacks). Two skin seam cases were reworded from Ka0s Default to the client's default skin. The prose gate's waiver count went from 11 to 15 suppressed files under `docs/spell-research/`, because of the new Forever research bundle.
- **perf**: the same 12 scenarios. `api/iter` is identical for every one, and `bytes/iter` moved by less than one byte (`applyPass` 107063.3 → 107062.5, for example) ([`perf.json`](perf.json)). `ms/iter` fell for most scenarios (`applyPass` 1.85261 → 1.49005, `restyleTextGlow` 3.85855 → 3.05415). That is machine noise on a sub-4 ms scale, not a code change: the port added no work to a perf path, and `Cat` and the cast table are read once at file load.
- **complexity**: +1846 NLOC and +39 functions ([`complexity.txt`](complexity.txt)). Most of the NLOC is the two generated Forever data files, which are id tables with almost no functions. That is why avg NLOC per function rose from 8.2 to 8.3 and avg tokens from 75.5 to 75.6, while avg CCN held at 2.3 and max CCN at 15. This is growth in data, not density in code. The branch's own review fixes (5ff012f) brought `build_pool_forever` and `derive_cast_aura` back under CCN 15. Those are Python in `tools/spell-research/`, which lizard does not measure here.

## Complexity watch list

Functions `lizard` warned on: none.

Files by band: the same 7 files as the previous run, and no disposition is blank in `RESULTS.md`. `defaults/Categories.lua` grew 1344 → 1399 lines with the port's `seeded` and `servedHere` helpers, and now has 10 functions with a max CCN of 5 ([`complexity.txt`](complexity.txt)). Its disposition in `RESULTS.md` now gives those figures. The other six files have the same LOC and function counts as before. Neither new Forever data file is in the band: `defaults/Categories_Forever.lua` is 659 lines, under the plan's 1400-line cap for generated files. This is not a release run, so it does not add to the three-release shelf life of any **Accepted** entry.

## Actions

1. `docs/ARCHITECTURE.md`, `## Documented deviations`, the `layout-§1` row for `defaults/Categories.lua` (FX-AM-SIZE): the row still says 1344 lines, 8 functions and max CCN 4. This run measures 1399 lines, 10 functions and max CCN 5. The file is one line under the row's re-check trigger ("The file reaches 1400 lines"). The second trigger (the spell-research tools reading more than one file) has arguably not fired, because `tools/spell-research/forever.py` reads only this file and writes the Forever seeds to separate files. Updating the row's figures and deciding whether to re-check now is the owner's call. This is new here and has no tracking ID beyond FX-AM-SIZE.
