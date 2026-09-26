# Analysis — 20260927-015127

- **Addon:** AuraMaster, release run for **1.0.0** ([`manifest.json`](manifest.json) `release`); the tree still read 0.1.0 when it ran, because the bump follows the gate
- **Verdict:** green, and the release gate passed: lint, tests, perf and complexity all `pass`, 0 functions above CCN 15
- **Commit:** `28c1ee3` (master), clean
- **Previous run:** `20260926-193601` (`8f7fcfb`, 14 commits earlier)

## Headline

The 1.0.0 release gate passed on every condition, with nothing skipped: perf ran its 11 scenarios
rather than claiming a pass by absence. The tree moved 14 commits since the previous run (the
test-mode outline fix, the name-width diagnostics, the Bar and Icon rail labels, the README and
screenshot work, the first in-game perf captures), and it shows as four new test cases, +81 NLOC
and +15 functions with the averages flat. No function crossed CCN 15, no file entered the
1000–1500 band, and no allocation figure moved. Nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20260926-193601 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 144 files | [`lint.txt`](lint.txt) | unchanged, 144 files |
| tests | pass | 1665 passed, 0 skipped, 0 failed, 1665 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1661 → 1665 (+4: the diagnostics width cases) |
| perf | pass | 11 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | bytes/iter and api/iter identical on all 11 |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | +81 NLOC, +15 functions, averages flat |

**Complexity is reported in full** (from [`manifest.json`](manifest.json) `suites.complexity`, which
mirrors `lizard`'s footer in [`complexity.txt`](complexity.txt)):

| Metric | Value |
|---|---|
| Total NLOC | 40071 (was 39990) |
| Functions | 4367 (was 4352) |
| Avg NLOC / function | 8.2 (was 8.2) |
| Avg CCN | 2.3 (was 2.3) |
| Max CCN | 15 (was 15) |
| Avg tokens / function | 72.4 (was 72.5) |
| Warnings (CCN > 15) | 0 (was 0) |
| Files in the 1000–1500 band | 9 (was 9) |
| Files over the 1500 cap | 0 (was 0) |

## What moved

- **tests:** 1661 → 1665 ([`tests.txt`](tests.txt)). The four new cases are the diagnostics report's
  bar-width and cached time-width lines. The test-mode outline change rewrote an existing case rather
  than adding one.
- **complexity:** +81 NLOC and +15 functions, spread over the diagnostics helpers, the
  `Style.MeasuredTimeWidths` accessor and the new test cases. Averages did not move. The five
  functions at exactly CCN 15 are the same five as the previous run ([`complexity.txt`](complexity.txt)):
  `standUp` (`core/LifecycleSetup.lua@105-122`), `ContainerClass` (`modules/Container.lua@593-602`,
  `ApplyHang`, which the outline fix changed without raising: `unlocked` replaced `show` in its
  condition), `Preview.Offset` (`modules/Preview.lua@47-72`), `tintColorMap`
  (`modules/Style_Text.lua@474-487`) and `entryHelp` (`tests/test_pages_filters.lua@102-124`).
- **perf:** bytes/iter and api/iter are identical to the previous run on all 11 scenarios
  ([`perf.txt`](perf.txt)); `compile` stays at 3576.0 and `applyPass` at 104403.4. `ms/iter` moved by
  a few percent both ways, which is host timing and not comparable across runs.
- **band files:** the same nine. `modules/Style.lua` grew 1018 → 1031 with the diagnostics accessor
  and stays well inside the band; its disposition is refreshed in `RESULTS.md`.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None. `lizard` reports 0 warnings ([`complexity.txt`](complexity.txt)), which is what the release gate
requires.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/Database.lua` | 1327 | Accepted (carried) |
| 1000–1500 (on notice) | `defaults/Categories.lua` | 1282 | Accepted (carried): hand-curated data |
| 1000–1500 (on notice) | `tests/test_filtercompiler.lua` | 1271 | Accepted (carried): case count |
| 1000–1500 (on notice) | `tests/test_style.lua` | 1203 | Accepted (carried): case count |
| 1000–1500 (on notice) | `tests/test_database.lua` | 1194 | Accepted (carried): case count |
| 1000–1500 (on notice) | `tests/test_pages_filters.lua` | 1085 | Accepted (carried): case count |
| 1000–1500 (on notice) | `tests/test_containermanager.lua` | 1053 | Accepted (carried): case count |
| 1000–1500 (on notice) | `settings/Schema.lua` | 1035 | Accepted (carried) |
| 1000–1500 (on notice) | `modules/Style.lua` | 1031 | Accepted (refreshed: 1018 → 1031) |

**Shelf life:** this is AuraMaster's first release run, so no *Accepted* entry has been carried across
three release runs.

## Actions

None.
