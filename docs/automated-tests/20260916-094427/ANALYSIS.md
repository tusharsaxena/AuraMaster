# Analysis — 20260916-094427

- **Addon:** AuraMaster 0.1.0
- **Verdict:** green
- **Commit:** 9ddad718d6b75ba15b39f0ce7a1a1ade4e2cde7a (master)
- **Previous run:** 20260912-020433

## Headline

All four suites pass ([`manifest.json`](manifest.json)) and no function is above CCN 15, so the
release gate would be satisfied on today's numbers. This is the first recorded run since 193 commits
of product work landed on `master`: the addon roughly doubled — 62 → 93 linted files, 9511 → 20604
NLOC — and the suite grew with it, 245 → 914 cases. The one thing worth a look is `perf`: with
`tests/perf.lua` itself unchanged across that span, `compile` and `applyPass` allocate about twice
what they did, which is a real change in the code under the scenario rather than a change in how it
is measured.

## Suites

| Suite | Status | Result | Artifact | Moved since 20260912-020433 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 93 files | [`lint.txt`](lint.txt) | Still 0/0; scope 62 → 93 files |
| tests | pass | 914 passed, 0 skipped, 0 failed, 914 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 245 → 914 (+669) |
| perf | pass | 9 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | `compile` +19152.0 and `applyPass` +22102.0 bytes/iter; see below |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC and functions ~2.2x; avg CCN 2.7 → 2.2; two files entered the 1000–1500 band |

**Complexity is reported in full** (from [`manifest.json`](manifest.json) `suites.complexity`, which
mirrors `lizard`'s footer in [`complexity.txt`](complexity.txt)):

| Metric | Value |
|---|---|
| Total NLOC | 20604 |
| Functions | 2381 |
| Avg NLOC / function | 7.9 |
| Avg CCN | 2.2 |
| Max CCN | 15 |
| Avg tokens / function | 66.4 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 2 |
| Files over the 1500 cap | 0 |

Every suite is a clean pass; nothing was skipped, so no figure here stands in for something that was
not measured.

## What moved

- **tests:** 245 → 914 ([`tests.txt`](tests.txt), inventory in [`test-cases.md`](test-cases.md)).
  The suite grew faster than the source did — source NLOC roughly doubled while the case count
  nearly quadrupled — so this is not a coverage gap forming.
- **lint:** still 0 warnings / 0 errors, now over 93 files rather than 62
  ([`lint.txt`](lint.txt)). The exclusion set is unchanged; `RESULTS.md`'s `## Lint` section
  restates what is out of scope.
- **complexity** ([`complexity.txt`](complexity.txt)): total NLOC 9511 → 20604 and functions
  1029 → 2381 — growth, not density. The averages say the same thing from the other side: avg CCN
  **fell** 2.7 → 2.2 and avg NLOC/function moved 7.5 → 7.9, with avg tokens 60.0 → 66.4. Max CCN is
  still 15 and the warning count is still 0. Nearest the gate: `Preview.Offset`
  (`modules/Preview.lua`) and `ContainerClass` (`modules/Container.lua:413`) at 15, then
  `renderCategories` (`settings/Filters.lua`), `TS.Scan` (`modules/TimedSpells.lua`) and
  `FP.NamedAncestor` (`modules/FramePicker.lua`) at 14. `Bars.FillPreview`, carried at 15 by the
  previous two runs, is no longer in the top band.
- **perf** ([`perf.txt`](perf.txt), against `20260912-020433/perf.txt`). `tests/perf.lua` is
  byte-identical across the two commits (`git diff 02537f7..9ddad71 -- tests/perf.lua` is empty), so
  these are movements in the code the scenarios exercise:
  - `compile` 3048.0 → 22200.0 bytes/iter and 0.00692 → 0.03891 ms/iter — the largest relative move
    in the run, and the one to explain before it is normalised.
  - `applyPass` 22805.5 → 44907.5 bytes/iter, 0.10935 → 0.15578 ms/iter, while engine calls stay at
    **22.0 per pass over 3 containers**. The API cost is flat; only allocation and time rose.
  - `restyle` 43221.8 → 49434.5 bytes/iter, 0.23588 → 0.28693 ms/iter.
  - `visibilityPass` is unchanged at 288.0 bytes/iter and 3.0 api/iter, and the dormant bracket is
    still free: `probeOverheadOff` (288.0) equals `probeAbsent` (288.0), with `probeOverheadOn` at
    288.5.
  - `unitSwap` and `unitAuraOther` remain at 0.0 bytes/iter.
  - ms/iter is orientation only and is not comparable across machines; the bytes/iter figures are
    the ones carrying the signal here.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_anchors.lua` | 1100 | Accepted — case count, not tangle: 55 `test(` cases, every function in the file below CCN 15 |
| 1000–1500 (on notice) | `tests/test_database.lua` | 1037 | Accepted — case count, not tangle: 64 `test(` cases, every function in the file below CCN 15 |

Both entries are **new** this run (the previous run's band table read `None.`), and both are suite
files whose length is a count of independent cases rather than a single long routine. Splitting
either would move cases between files without removing a line. First recorded as Accepted here;
under `automated-tests-§4` that disposition is owed a fix or a tracked deviation ID if it is still
being written at the third consecutive release run.

## Actions

1. **Explain the `perf` allocation move before it becomes the baseline.** `compile` 3048.0 →
   22200.0 and `applyPass` 22805.5 → 44907.5 bytes/iter across an unchanged `tests/perf.lua`
   ([`perf.txt`](perf.txt)). Engine calls did not move, so this is per-pass garbage, which is what
   `performance-§9` cares about. It has no owner in this addon's tracking today — it is new here.
2. Carried: `Preview.Offset` (`modules/Preview.lua`) and `ContainerClass`
   (`modules/Container.lua:413`) sit at CCN 15, the gate's boundary. Extract a helper before the
   next change to either, or the next edit is what breaks the release gate.
