# Analysis — 20260911-141809

- **Addon:** AuraMaster 0.1.0
- **Verdict:** green
- **Commit:** none — the repository has no commits yet (`manifest.json` records `HEAD` on `HEAD`), dirty
- **Previous run:** none — this is the first

## Headline

The first recorded run of the scaffold, and every suite passed: lint clean over 62 files, all 154
headless cases green with nothing skipped, all 7 offline perf scenarios meeting their deterministic
assertions, and no function above CCN 15. It is **not** a release record — `release` is `null`,
because `--release` refuses an uncommitted tree — so the `v0.1.0` tag still waits on a release run
against a commit.

## Suites

| Suite | Status | Result | Artifact | Moved since previous run |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 62 files | [`lint.txt`](lint.txt) | first run — baseline |
| tests | pass | 154 passed, 0 skipped, 0 failed, 154 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | first run — baseline |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | first run — baseline |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | first run — baseline |

| Metric | Value |
|---|---|
| Total NLOC | 6820 |
| Functions | 676 |
| Avg NLOC / function | 6.6 |
| Avg CCN | 2.8 |
| Max CCN | 15 |
| Avg tokens / function | 53.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.0 / 0.0 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |

Every suite is a clean pass. The maximum CCN sits exactly at the threshold (15, not above it): seven
functions that scored 16–23 earlier in the scaffold were split into named helpers before this run
(`modules/Anchors.lua`, `modules/Container.lua`, `modules/ContainerManager.lua`, `modules/Style.lua`,
`modules/Style_Bars.lua`, `modules/Style_Icons.lua`), each with covering cases in `tests.txt`.

`test_vendor_sync` ran for real against the sibling LibKa0s checkout rather than skipping, so the
`tests` figure includes the byte-identity check of `libs/LibKa0s/` and `tests/_kit/` against the
`v1.29.0` tag named in `CLAUDE.md`.

## What moved

First run — nothing to diff against; every figure above is a baseline reading.

## Complexity watch list

**Functions `lizard` warned on:**

None.

**Files by `layout-§1` band:**

None.

## Actions

1. **Commit, then produce the release record.** `tests/_kit/run-automated-tests.sh --release 0.1.0`
   on the committed tree, with its own `ANALYSIS.md`, before tagging `v0.1.0` (automated-tests-§6).
   New here; no tracking id yet.
