# Analysis — 20260924-185738

- **Addon:** AuraMaster 0.1.0
- **Verdict:** green
- **Commit:** 79d4f8017e1d0f5eb4d113523207c6c778a3ed3c (feat/2026-09-23-review-audit-remediation)
- **Previous run:** 20260916-184324

## Headline

All four suites pass ([`manifest.json`](manifest.json)): lint 0/0 over 119 files, 1350 cases with
nothing skipped, 10 perf scenarios, and **0 functions above CCN 15** with max CCN still 15, so the
release gate would be satisfied on today's numbers. This run replaces a record 177 commits stale: it
spans the user-category work, the fourth starter container and the whole 2026-09-23 remediation
(RV-AM, AM-01 to AM-34). The addon grew by half again (+10514 NLOC, +1046 functions) and got
slightly denser (avg CCN 2.2 → 2.3, avg tokens 66.3 → 70.2). Five files newly entered the
1000–1500 band and each now carries a ruling; one of them, `settings/GeneralSpells.lua`, is source
code 20 lines under the cap and is the one thing here to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20260916-184324 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 119 files | [`lint.txt`](lint.txt) | Still 0/0; scope 95 → 119 files |
| tests | pass | 1350 passed, 0 skipped, 0 failed, 1350 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 943 → 1350 (+407) |
| perf | pass | 10 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | One scenario added (`restyleText`), one replaced (`unitAuraOther` → `unitAuraFiltered`); the starter set grew from 3 containers to 4, so `applyPass` and the probe scenarios moved with it. See *What moved* |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | Totals +10514 NLOC / +1046 funcs; avg NLOC 7.9 → 8.1, avg CCN 2.2 → 2.3, avg tokens 66.3 → 70.2; band files 2 → 7 |

**Complexity is reported in full** (from [`manifest.json`](manifest.json) `suites.complexity`, which
mirrors `lizard`'s footer in [`complexity.txt`](complexity.txt)):

| Metric | Value |
|---|---|
| Total NLOC | 31677 |
| Functions | 3492 |
| Avg NLOC / function | 8.1 |
| Avg CCN | 2.3 |
| Max CCN | 15 |
| Avg tokens / function | 70.2 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 7 |
| Files over the 1500 cap | 0 |

Every suite is a clean pass, so there is no failure paragraph to write. The lint figure carries its
scope: `.luacheckrc` excludes `libs/`, `tests/_kit/`, `docs/audits/`, `docs/reviews/`,
`docs/automated-tests/` and `_dev/` (named in `RESULTS.md` → *Lint*).

## What moved

- **Lint:** 0/0 held while its scope grew from 95 to 119 files ([`lint.txt`](lint.txt)). Among the
  new files are the peeled suites (`test_database_categories`, `test_filtercompiler_categories`,
  `test_pages_general_categories`), `test_migrations`, and the source peels
  `settings/GeneralDispel.lua` and `defaults/UserCategories.lua`.
- **Tests:** 943 → 1350 cases, nothing skipped ([`tests.txt`](tests.txt)). The run is sharded (16
  shards), which the harness holds equal to the serial run. `docs/test-cases.md` at HEAD is the same
  list as [`test-cases.md`](test-cases.md).
- **Perf** ([`perf.txt`](perf.txt) against the previous bundle's `perf.txt`): every scenario present
  in both runs moved, but not because of the remediation. A fresh profile now seeds four starter
  containers instead of three (the "Player cooldowns" Text container, commit `7b4754e`), so
  `applyPass` went from 22.0 to 30.0 engine calls and from 44907.6 to 118147.2 bytes per pass, and
  `visibilityPass` and the three probe scenarios each gained one call and 96 bytes. `compile` is flat
  at 22200.0 bytes. `restyleText` (added in `115e927`) has no predecessor. `unitAuraOther` became
  `unitAuraFiltered` in AM-08, when `UNIT_AURA` moved to a player/pet `RegisterUnitEvent` frame: it
  now measures the client-filtered delivery rather than a foreign unit dropped in Lua, and still
  allocates nothing (0 bytes, 0 calls).
  **The remediation's own share was measured by re-running `tests/perf.lua` at each candidate
  commit** (outside this bundle, so not a figure in it): from `0ede122`, the plan's base, to HEAD,
  api/iter is unchanged on every scenario. Two bytes/iter figures moved: `restyle` +66.0 (51413.9 →
  51479.9) at RV-AM, the LibKa0s v1.56.0 re-vendor, and `applyPass` +432.0 (117715.2 → 118147.2) at
  AM-06, which swapped `C_Timer.After` for cancellable `C_Timer.NewTimer` handles on the queued apply
  and the timed-spell scan. AM-08 changed nothing beyond the scenario swap above, and AM-15 (the
  LibKa0s-Schema adoption) moved no figure. ms/iter is for orientation within a run only.
- **Complexity:** +10514 NLOC and +1046 functions ([`complexity.txt`](complexity.txt)). Unlike the
  previous run, the averages moved too: avg NLOC 7.9 → 8.1, avg CCN 2.2 → 2.3, avg tokens 66.3 →
  70.2. That is a small densification over 177 commits, not a jump; max CCN held at 15 with no
  function over it. Band files went from 2 to 7, ruled on below.

## Complexity watch list

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None. Max CCN is 15, at the threshold rather than over it, reached by `Preview.Offset`
(`modules/Preview.lua`), `tintColorMap` (`modules/Style_Text.lua`) and the test reader `entryHelp`
(`tests/test_pages_filters.lua`).

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `settings/GeneralSpells.lua` | 1480 | **Peel next** — source, 20 lines under the cap after AM-23 peeled Dispel Colors out; 73 functions, max CCN 10, so size rather than tangle. The *Make a new category* block is the next seam; any change that grows this file peels first |
| 1000–1500 (on notice) | `tests/test_anchors.lua` | 1384 | Accepted — case count, not tangle: 66 independent `test(` cases, no function in it above CCN 4 |
| 1000–1500 (on notice) | `tests/test_containermanager.lua` | 1053 | Accepted — case count, not tangle: 53 independent `test(` cases, no function in it above CCN 4 |
| 1000–1500 (on notice) | `tests/test_database.lua` | 1194 | Accepted — case count, not tangle: 73 independent `test(` cases, no function in it above CCN 4 |
| 1000–1500 (on notice) | `tests/test_filtercompiler.lua` | 1270 | Accepted — case count, not tangle: 85 independent `test(` cases, no function in it above CCN 5 |
| 1000–1500 (on notice) | `tests/test_pages_filters.lua` | 1031 | Accepted — case count, not tangle: 48 independent `test(` cases; its one CCN 15 function is the `entryHelp` reader, at the threshold, not over it |
| 1000–1500 (on notice) | `tests/test_style.lua` | 1170 | Accepted — case count, not tangle: 59 independent `test(` cases, no function in it above CCN 7 |

The two carried-forward rows (`test_anchors`, `test_database`) had grown since they were ruled on
(1100 → 1384 and 1037 → 1194 lines), so their case counts were re-taken for this run rather than
left at the old 55 and 64.

## Actions

1. `settings/GeneralSpells.lua` (1480 lines): peel the *Make a new category* block into its own
   file before the next change that grows it, the same move AM-23 made for Dispel Colors. New here:
   no issue tracks it yet.
2. No version bump and no tag come with this run (remediation item AM-DOCS): the owner decides the
   release, and a `--release X.Y.Z` run is still owed at that point.
