# Automated test results

<!-- Regenerated whole by tests/_kit/run-automated-tests.sh on every run. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->
<!-- Everything here is generated EXCEPT the watch list's Disposition column. -->

One row per run. The frozen evidence for each is in the dated folder beside this file;
the analysis of a given run is its `ANALYSIS.md`.

**`lint` and `tests` gate the run and gate the commit** (`testing-§4`).
**`perf` and `complexity` never fail a run and never block a commit** — they are recorded,
read and compared, not thresholded (`performance-§9`, `performance-§10`).

**The tag is gated on all four suites at `pass`, plus zero functions above CCN 15**
(`automated-tests-§3`, *The release gate*), evaluated by `/wow-addon:bump-version` from the
`manifest.json` the release run writes — not by this script, whose exit code is unchanged.

A `skip` is a suite that did not run at all. It is never a pass, and at the release gate it is
**NOT EVALUATED** rather than passed: install the tool and re-run. A `—` is a suite that was
not selected, which is a different fact again.

The **Tests** cell reads `passed/skipped/total`.

| Run | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20260916-184324`](20260916-184324/) | 0.1.0 | 0/0 | 95 | 943/0/943 | pass | 21163 | 2446 | 7.9 | 2.2 | 15 | 0 | **green** |
| [`20260916-094427`](20260916-094427/) | 0.1.0 | 0/0 | 93 | 914/0/914 | pass | 20604 | 2381 | 7.9 | 2.2 | 15 | 0 | **green** |
| [`20260912-020433`](20260912-020433/) | 0.1.0 | 0/0 | 62 | 245/0/245 | pass | 9511 | 1029 | 7.5 | 2.7 | 15 | 0 | **green** |
| [`20260912-015750`](20260912-015750/) | 0.1.0 | 0/0 | 62 | 244/0/244 | pass | 9483 | 1026 | 7.5 | 2.7 | 15 | 0 | **green** |
| [`20260912-004826`](20260912-004826/) | 0.1.0 | 0/0 | 62 | 233/0/233 | pass | 9178 | 981 | 7.6 | 2.8 | 15 | 0 | **green** |
| [`20260911-141809`](20260911-141809/) | 0.1.0 | 0/0 | 62 | 154/0/154 | pass | 6820 | 676 | 6.6 | 2.8 | 15 | 0 | **green** |

## Test suite

**943 cases** — 943 passed, 0 failed, 0 skipped. The generated inventory
[`20260916-184324/test-cases.md`](20260916-184324/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **914 → 943** since the previous run.

No case reported a `skip`, so passed and total agree and nothing in this row claims coverage
that was not exercised.

## Lint

**0 warnings / 0 errors over 95 files** (`luacheck .`).

Read that figure with its scope attached: `.luacheckrc` sets `exclude_files = { "libs/", "tests/_kit/", "docs/audits/", "docs/reviews/", "docs/automated-tests/", "_dev/" }`, so those paths
are not in it. A `0/0` that never moves is partly a statement about what was never looked at, which
is why the exclusion is restated on every run.

## Perf

**9 scenarios** from `tests/perf.lua`; the measurements are in
[`20260916-184324/perf.json`](20260916-184324/perf.json).

`perf` never fails a run and never blocks a commit — it is recorded, read and compared, not
thresholded (`performance-§9`). It does gate the **tag** (`automated-tests-§3`).

## Complexity watch list

Current as of [`20260916-184324`](20260916-184324/) — **this run's measurement, not its diff.** Max CCN **15** across 2446
functions, **0** of them warned on; 2 file(s) in the 1000–1500 band and 0 over the 1500 cap
(`layout-§1`).

Every row below is generated from this run's own `lizard` output. **The `Disposition` column is
the one authored cell in this file** (`automated-tests-§4`, *the one boundary*): it is carried
forward verbatim while its entry is unchanged, and left **blank** when the entry is new — a blank
cell is this file saying something crossed and nobody has ruled on it yet.

### Functions `lizard` warned on

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_anchors.lua` | 1100 | Accepted — case count, not tangle: 55 independent `test(` cases, no function in it above CCN 15 |
| 1000–1500 (on notice) | `tests/test_database.lua` | 1037 | Accepted — case count, not tangle: 64 independent `test(` cases, no function in it above CCN 15 |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

