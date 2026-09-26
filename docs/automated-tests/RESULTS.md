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

**Commit** is the short sha the run measured and **Tree** is whether that tree was clean at the
time. Both are read from git by the runner; neither is ever typed. A **dirty** row measured bytes
that no sha can bring back, so it is kept as an experiment honestly labeled rather than dropped —
and a release record is refused outright on a dirty tree, so no release row can be one.

A row reading `unknown` in both cells was recorded before the runner emitted them. That is what
the record holds about those runs — it is not `clean`, and it is not reconstructed from git
archaeology, for the same reason a skip is never a pass (`automated-tests-§4`).

| Run | Commit | Tree | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20260926-160451`](20260926-160451/) | `e5bb12c` | clean | 0.1.0 | 0/0 | 140 | 1660/0/1660 | pass | 39928 | 4349 | 8.2 | 2.3 | 15 | 0 | **green** |
| [`20260924-185738`](20260924-185738/) | `79d4f80` | clean | 0.1.0 | 0/0 | 119 | 1350/0/1350 | pass | 31677 | 3492 | 8.1 | 2.3 | 15 | 0 | **green** |
| [`20260916-184324`](20260916-184324/) | unknown | unknown | 0.1.0 | 0/0 | 95 | 943/0/943 | pass | 21163 | 2446 | 7.9 | 2.2 | 15 | 0 | **green** |
| [`20260916-094427`](20260916-094427/) | unknown | unknown | 0.1.0 | 0/0 | 93 | 914/0/914 | pass | 20604 | 2381 | 7.9 | 2.2 | 15 | 0 | **green** |
| [`20260912-020433`](20260912-020433/) | unknown | unknown | 0.1.0 | 0/0 | 62 | 245/0/245 | pass | 9511 | 1029 | 7.5 | 2.7 | 15 | 0 | **green** |
| [`20260912-015750`](20260912-015750/) | unknown | unknown | 0.1.0 | 0/0 | 62 | 244/0/244 | pass | 9483 | 1026 | 7.5 | 2.7 | 15 | 0 | **green** |
| [`20260912-004826`](20260912-004826/) | unknown | unknown | 0.1.0 | 0/0 | 62 | 233/0/233 | pass | 9178 | 981 | 7.6 | 2.8 | 15 | 0 | **green** |
| [`20260911-141809`](20260911-141809/) | unknown | unknown | 0.1.0 | 0/0 | 62 | 154/0/154 | pass | 6820 | 676 | 6.6 | 2.8 | 15 | 0 | **green** |

## Test suite

**1660 cases** — 1660 passed, 0 failed, 0 skipped. The generated inventory
[`20260926-160451/test-cases.md`](20260926-160451/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **1350 → 1660** since the previous run.

No case reported a `skip`, so passed and total agree and nothing in this row claims coverage
that was not exercised.

## Lint

**0 warnings / 0 errors over 140 files** (`luacheck .`).

Read that figure with its scope attached: `.luacheckrc` excludes 6 path(s) from it — `libs/`, `tests/_kit/`, `docs/audits/`, `docs/reviews/`, `docs/automated-tests/`, `_dev/` —
so nothing under them is in the count above. A `0/0` that never moves is partly a statement about
what was never looked at, which is why the exclusions are NAMED here on every run rather than left
to whoever thinks to open `.luacheckrc`.

## Perf

**11 scenarios** from `tests/perf.lua`; the measurements are in
[`20260926-160451/perf.json`](20260926-160451/perf.json).

| `scenario` | `iters` | `ms/iter` | `api/iter` | `bytes/iter` |
|---|---|---|---|---|
| `compile` | 2000 | 0.10289 | 0.0 | 42424.0 |
| `applyPass` | 200 | 1.45631 | 30.0 | 164883.4 |
| `restyle` | 200 | 0.32245 | 0.0 | 50203.5 |
| `restyleText` | 200 | 0.23132 | 0.0 | 31587.6 |
| `visibilityPass` | 1000 | 0.01245 | 4.0 | 384.0 |
| `unitSwap` | 1000 | 0.00096 | 1.0 | 0.0 |
| `probeOverheadOff` | 1000 | 0.01620 | 5.0 | 384.0 |
| `probeOverheadOn` | 1000 | 0.01379 | 5.0 | 384.5 |
| `probeAbsent` | 1000 | 0.01557 | 5.0 | 384.0 |
| `unitAuraFiltered` | 1000 | 0.00032 | 0.0 | 0.0 |
| `emptyWatchAura` | 1000 | 0.00007 | 0.0 | 0.0 |

`perf` never fails a run and never blocks a commit — it is recorded, read and compared, not
thresholded (`performance-§9`). It does gate the **tag** (`automated-tests-§3`).

## Complexity watch list

Current as of [`20260926-160451`](20260926-160451/) — **this run's measurement, not its diff.** Max CCN **15** across 4349
functions, **0** of them warned on; 12 file(s) in the 1000–1500 band and 0 over the 1500 cap
(`layout-§1`).

Every row below is generated from this run's own `lizard` output. **The `Disposition` column is
the one authored cell in this file** (`automated-tests-§4`, *the one boundary*): it is carried
forward verbatim while its entry is unchanged, and left **blank** when the entry is new — a blank
cell is this file saying something crossed and nobody has ruled on it yet.

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/Database.lua` | 1327 | Accepted — newly crossed (948 → 1327 since `20260924-185738`); size, not tangle: 87 functions, max CCN 14 (`Database.MigrateV5`, a linear migration step). The growth is migration steps; if it grows further, the migrations are the seam to peel |
| 1000–1500 (on notice) | `defaults/Categories.lua` | 1282 | Accepted — newly crossed (676 → 1282); data, not logic: 7 functions, max CCN 4. The bulk is hand-curated spell-ID tables (authored, so the cap binds; not the generated carve-out) |
| 1000–1500 (on notice) | `modules/Anchors.lua` | 1243 | **Peel next** — newly crossed, and grew 526 → 1243 in one run interval; 81 functions, max CCN 15 (`steadyRelative`, at the threshold, guarding rather than tangle). The attachment half (`attachSpec`, `pairFor`, `steadyRelative`) is the seam |
| 1000–1500 (on notice) | `modules/Style.lua` | 1018 | Accepted — newly crossed (943 → 1018), just inside the band; 65 functions, max CCN 13 (`Style.CurveColor`), size rather than tangle |
| 1000–1500 (on notice) | `settings/GeneralSpells.lua` | 1480 | **Peel next** — source, 20 lines under the cap after AM-23 peeled Dispel Colors out; 73 functions, max CCN 10, so size rather than tangle. The *Make a new category* block is the next seam; any change that grows this file peels first |
| 1000–1500 (on notice) | `settings/Schema.lua` | 1035 | Accepted — newly crossed (976 → 1035); 62 functions, max CCN 13 (`normalizeCategoryEdits`), size rather than tangle |
| 1000–1500 (on notice) | `tests/test_containermanager.lua` | 1053 | Accepted — case count, not tangle: 53 independent `test(` cases, no function in it above CCN 4 |
| 1000–1500 (on notice) | `tests/test_database.lua` | 1194 | Accepted — case count, not tangle: 73 independent `test(` cases, no function in it above CCN 4 |
| 1000–1500 (on notice) | `tests/test_filtercompiler.lua` | 1271 | Accepted — case count, not tangle: 85 independent `test(` cases, no function in it above CCN 5 |
| 1000–1500 (on notice) | `tests/test_pages_filters.lua` | 1085 | Accepted — case count, not tangle: 48 independent `test(` cases; its one CCN 15 function is the `entryHelp` reader, at the threshold, not over it |
| 1000–1500 (on notice) | `tests/test_style.lua` | 1203 | Accepted — case count, not tangle: 59 independent `test(` cases, no function in it above CCN 7 |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

