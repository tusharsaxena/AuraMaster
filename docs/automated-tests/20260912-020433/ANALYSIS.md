# Analysis — 20260912-020433

- **Addon:** AuraMaster 0.1.0
- **Verdict:** green
- **Commit:** 02537f74a79171e47ee3cdabef7d234390026789 (fix/review-audit-2026-09-11)
- **Previous run:** 20260912-015750

## Headline

All four suites pass ([`manifest.json`](manifest.json)) and the complexity watch list is empty. The
regression the previous run recorded is gone: the visibility pass is back to 288.0 bytes/iter
([`perf.txt`](perf.txt)). Nothing is left to act on apart from two functions at CCN 15, carried
forward.

## Suites

| Suite | Status | Result | Artifact | Moved since 20260912-015750 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 62 files | [`lint.txt`](lint.txt) | No change |
| tests | pass | 245 passed, 0 skipped, 0 failed, 245 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 244 → 245 (+1) |
| perf | pass | 9 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | visibilityPass and the probe arms −144.0 bytes/iter; applyPass −140.8 |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | Functions 1026 → 1029; averages flat |

**Complexity is reported in full** (from [`manifest.json`](manifest.json) `suites.complexity`):

| Metric | Value |
|---|---|
| Total NLOC | 9511 |
| Functions | 1029 |
| Avg NLOC / function | 7.5 |
| Avg CCN | 2.7 |
| Max CCN | 15 |
| Avg tokens / function | 60.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.0 / 0.0 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |

Every suite is a clean pass.

## What moved

- **tests:** 244 → 245 ([`tests.txt`](tests.txt)). The new case is "handle: a visibility pass that
  changes nothing re-sets no clamp insets". It pins the cause of the previous run's regression by
  counting engine calls, which does not depend on the mock's allocation.
- **lint:** unchanged at 0/0 over 62 files.
- **complexity:** functions 1026 → 1029 and NLOC 9483 → 9511 (the `setClamp` helper and its test).
  Avg CCN stays 2.7, avg NLOC 7.5, avg tokens 59.9 → 60.0, max CCN 15, no warnings.
- **perf** ([`perf.txt`](perf.txt), against the previous run's `perf.txt`):
  - `visibilityPass` 432.0 → 288.0 bytes/iter, and `probeOverheadOff` and `probeAbsent` 432.0 → 288.0,
    `probeOverheadOn` 432.6 → 288.6. These are the readings of run 20260912-004826, before the unlock
    handle. The dormant bracket is still free: `probeOverheadOff` equals `probeAbsent`.
  - `applyPass` 22946.3 → 22805.5 bytes/iter. That is 3.2 above run 20260912-004826's 22802.3,
    because each container's insets table is built once on its first set.
  - `compile` 3048.0, `restyle` 43221.8, `unitSwap` 0.0 and `unitAuraOther` 0.0 are unchanged, and so
    is every `api/iter` figure.
  - The fix is commit `02537f7`: `clampToHandle` now calls `SetClampRectInsets` only when the insets
    change, where it used to call it on every visibility pass for every container.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|

None.

Nearest the release gate, from [`complexity.txt`](complexity.txt): `Preview.Offset`
(`modules/Preview.lua`) and `Bars.FillPreview` (`modules/Style_Bars.lua`) at CCN 15;
`ContainerClass:Apply` (`modules/Container.lua`, listed as `ContainerClass`), `FP.NamedAncestor`,
`Preview.Show` and `TS.Scan` at 14. Unchanged.

## Actions

1. Carried from `20260912-004826`: `Preview.Offset` and `Bars.FillPreview` remain at CCN 15; extract
   a helper before the next change to either.
