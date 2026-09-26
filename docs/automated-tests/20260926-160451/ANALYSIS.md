# Analysis — 20260926-160451

- **Addon:** AuraMaster 0.1.0
- **Verdict:** green
- **Commit:** e5bb12c810a26d78824988df15b9b03bb393434c (master), clean
- **Previous run:** 20260924-185738 (`79d4f80`, 177 commits earlier)

## Headline

All four suites pass ([`manifest.json`](manifest.json)): lint 0/0 over 140 files, 1660 cases with
nothing skipped, 11 perf scenarios, and **0 functions above CCN 15**, so the release gate would be
satisfied on today's numbers. The addon grew by about a quarter (+8251 NLOC, +857 functions) and got
marginally denser per function (avg NLOC 8.1 → 8.2, avg tokens 70.2 → 72.5; avg CCN flat at 2.3).
Three things want action: **perf allocation rose** in `compile` (+91%) and `applyPass` (+40%) with
api/iter unchanged, unattributed; **three more functions reached CCN 15** (six in all, none over);
and **five files newly entered the 1000–1500 band**, one of them (`modules/Anchors.lua`) more than
doubling. `tests/test_anchors.lua` (1481) and `settings/GeneralSpells.lua` (1480) are each about 20
lines under the cap.

## Suites

| Suite | Status | Result | Artifact | Moved since 20260924-185738 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 140 files | [`lint.txt`](lint.txt) | Still 0/0; scope 119 → 140 files |
| tests | pass | 1660 passed, 0 skipped, 0 failed, 1660 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1350 → 1660 (+310) |
| perf | pass | 11 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 10 → 11 (`emptyWatchAura` added); `compile` and `applyPass` bytes/iter rose sharply. See *What moved* |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | +8251 NLOC / +857 funcs; avg NLOC 8.1 → 8.2, avg tokens 70.2 → 72.5, avg CCN flat; band files 7 → 12 |

**Complexity is reported in full** (from [`manifest.json`](manifest.json) `suites.complexity`, which
mirrors `lizard`'s footer in [`complexity.txt`](complexity.txt)):

| Metric | Value |
|---|---|
| Total NLOC | 39928 (was 31677) |
| Functions | 4349 (was 3492) |
| Avg NLOC / function | 8.2 (was 8.1) |
| Avg CCN | 2.3 (was 2.3) |
| Max CCN | 15 (was 15) |
| Avg tokens / function | 72.5 (was 70.2) |
| Warnings (CCN > 15) | 0 (was 0) |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 12 (was 7) |
| Files over the 1500 cap | 0 (was 0) |

## What moved

- **tests:** 1350 → 1660 cases (+310), all passing, none skipped ([`tests.txt`](tests.txt)).
- **lint:** scope 119 → 140 files, still 0/0 ([`lint.txt`](lint.txt)).
- **perf — allocation** (bytes/iter, [`perf.txt`](perf.txt) against the previous bundle's `perf.txt`):

  | Scenario | Was | Now | Change |
  |---|---|---|---|
  | `compile` | 22200.0 | 42424.0 | **+91.1%** |
  | `applyPass` | 118147.2 | 164883.4 | **+39.6%** |
  | `restyle` | 51479.9 | 50203.5 | −2.5% |
  | `restyleText` | 30960.6 | 31587.6 | +2.0% |
  | the other six | — | — | unchanged |

  api/iter is identical on every scenario that exists in both runs (`applyPass` still 30.0 engine
  calls over 4 containers), so the engine-call contract held; what grew is garbage per compile and
  per apply pass. `tests/perf.lua`'s fixture reports the same shape (200 writes → 1 apply pass, 4
  containers), so the rise is in the measured code, not the harness. **Not attributed:** the range is
  177 commits and nothing was bisected. `ms/iter` rose on most scenarios too, but this run shared
  the host with eleven sibling batteries, and timings are for within-run comparison only.
- **perf — scenarios:** `emptyWatchAura` is new (0.0 api/iter, 0.0 bytes/iter).
- **complexity:** functions at exactly CCN 15 went from 3 to 6 ([`complexity.txt`](complexity.txt)).
  Carried: `Preview.Offset` (`modules/Preview.lua@47-72`), `tintColorMap`
  (`modules/Style_Text.lua@474-487`), `entryHelp` (`tests/test_pages_filters.lua@102-124`). **New
  at 15:** `standUp` (`core/LifecycleSetup.lua@105-122`), `steadyRelative`
  (`modules/Anchors.lua@554-569`), `ContainerClass` (`modules/Container.lua@592-600`). None is warned;
  any added branch in one of the six blocks the release gate.
- **band files:** 7 → 12. Newly crossed: `core/Database.lua` 948 → 1327, `defaults/Categories.lua`
  676 → 1282, `modules/Anchors.lua` 526 → 1243, `settings/Schema.lua` 976 → 1035,
  `modules/Style.lua` 943 → 1018. Carried files that moved: `tests/test_anchors.lua` 1384 → 1481,
  `tests/test_pages_filters.lua` 1031 → 1085, `tests/test_style.lua` 1170 → 1203,
  `tests/test_filtercompiler.lua` 1270 → 1271.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None. `lizard` reports 0 warnings ([`complexity.txt`](complexity.txt): "No thresholds exceeded").

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_anchors.lua` | 1481 | Accepted (carried) — case count, not tangle; **19 lines under the cap**, grew +97 |
| 1000–1500 (on notice) | `settings/GeneralSpells.lua` | 1480 | **Peel next** (carried) — 20 lines under the cap |
| 1000–1500 (on notice) | `core/Database.lua` | 1327 | **New.** Accepted — size, not tangle (max CCN 14) |
| 1000–1500 (on notice) | `defaults/Categories.lua` | 1282 | **New.** Accepted — hand-curated data, max CCN 4 |
| 1000–1500 (on notice) | `tests/test_filtercompiler.lua` | 1271 | Accepted (carried) |
| 1000–1500 (on notice) | `modules/Anchors.lua` | 1243 | **New. Peel next** — grew 526 → 1243 in one interval |
| 1000–1500 (on notice) | `tests/test_style.lua` | 1203 | Accepted (carried) |
| 1000–1500 (on notice) | `tests/test_database.lua` | 1194 | Accepted (carried) |
| 1000–1500 (on notice) | `tests/test_pages_filters.lua` | 1085 | Accepted (carried) |
| 1000–1500 (on notice) | `tests/test_containermanager.lua` | 1053 | Accepted (carried) |
| 1000–1500 (on notice) | `settings/Schema.lua` | 1035 | **New.** Accepted — max CCN 13 |
| 1000–1500 (on notice) | `modules/Style.lua` | 1018 | **New.** Accepted — max CCN 13 |

**Shelf life:** no release run exists yet (every row is 0.1.0, no tags), so no *Accepted* entry has
been carried across three release runs.

## Actions

- **Bisect the perf allocation rise** in `compile` and `applyPass` across `79d4f80..e5bb12c` before
  the next tag; perf gates the release.
- **Peel `tests/test_anchors.lua`** (1481) before it gains another case; it is the closest file to
  the cap.
- **Peel `settings/GeneralSpells.lua`** (1480), which was already *Peel next*.
- **Peel `modules/Anchors.lua`** along its attachment seam while it is still 257 lines clear.
- Keep an eye on the six CCN-15 functions; each is at the release threshold.
