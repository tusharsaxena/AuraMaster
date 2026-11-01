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
(`automated-tests-§3`, *The release gate*), evaluated by `/dev-copilot:bump-version` from the
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
| [`20261102-004743`](20261102-004743/) | `7bd52a2` | clean | 1.1.0 | 0/0 | 206 | 2343/1/2344 | pass | 56543 | 6150 | 8.3 | 2.3 | 15 | 0 | **green** |
| [`20261101-210026`](20261101-210026/) | `ce2e6cc` | clean | 1.1.0 | 0/0 | 205 | 2336/1/2337 | pass | 56414 | 6139 | 8.3 | 2.3 | 15 | 0 | **green** |
| [`20261101-201519`](20261101-201519/) | `72c566c` | clean | 1.1.0 | 0/0 | 205 | 2335/1/2336 | pass | 56403 | 6138 | 8.3 | 2.3 | 15 | 0 | **green** |
| [`20261101-145411`](20261101-145411/) | `1b80e05` | clean | 1.1.0 | 0/0 | 204 | 2282/1/2283 | pass | 56050 | 6075 | 8.3 | 2.3 | 15 | 0 | **green** |
| [`20261101-025540`](20261101-025540/) | `31133dc` | clean | 1.1.0 | 0/0 | 201 | 2253/1/2254 | pass | 55274 | 6003 | 8.3 | 2.3 | 15 | 0 | **green** |
| [`20261101-001140`](20261101-001140/) | `b37c794` | clean | 1.1.0 | 0/0 | 201 | 2253/1/2254 | pass | 55273 | 6003 | 8.3 | 2.3 | 15 | 0 | **green** |
| [`20261031-212339`](20261031-212339/) | `16cf393` | clean | 1.1.0 | 0/0 | 201 | 2249/1/2250 | pass | 55169 | 5992 | 8.3 | 2.3 | 15 | 0 | **green** |
| [`20261031-202022`](20261031-202022/) | `472da8f` | clean | 1.1.0 | 0/0 | 193 | 2249/1/2250 | pass | 55057 | 5977 | 8.3 | 2.3 | 15 | 0 | **green** |
| [`20261009-191725`](20261009-191725/) | `ad636a2` | clean | 1.0.1 → 1.1.0 | 0/0 | 174 | 2058/1/2059 | pass | 49857 | 5459 | 8.3 | 2.3 | 15 | 0 | **green** |
| [`20260927-214918`](20260927-214918/) | `b5208f3` | clean | 1.0.0 → 1.0.1 | 0/0 | 146 | 1702/0/1702 | pass | 41031 | 4472 | 8.2 | 2.3 | 15 | 0 | **green** |
| [`20260927-214805`](20260927-214805/) | `4e03d41` | clean | 1.0.0 → 1.0.1 | 0/0 | 146 | 1701/0/1702 | pass | 41031 | 4472 | 8.2 | 2.3 | 15 | 0 | **red** |
| [`20260927-015127`](20260927-015127/) | `28c1ee3` | clean | 0.1.0 → 1.0.0 | 0/0 | 144 | 1665/0/1665 | pass | 40071 | 4367 | 8.2 | 2.3 | 15 | 0 | **green** |
| [`20260926-193601`](20260926-193601/) | `8f7fcfb` | clean | 0.1.0 | 0/0 | 144 | 1661/0/1661 | pass | 39990 | 4352 | 8.2 | 2.3 | 15 | 0 | **green** |
| [`20260926-160451`](20260926-160451/) | `e5bb12c` | clean | 0.1.0 | 0/0 | 140 | 1660/0/1660 | pass | 39928 | 4349 | 8.2 | 2.3 | 15 | 0 | **green** |
| [`20260924-185738`](20260924-185738/) | `79d4f80` | clean | 0.1.0 | 0/0 | 119 | 1350/0/1350 | pass | 31677 | 3492 | 8.1 | 2.3 | 15 | 0 | **green** |
| [`20260916-184324`](20260916-184324/) | unknown | unknown | 0.1.0 | 0/0 | 95 | 943/0/943 | pass | 21163 | 2446 | 7.9 | 2.2 | 15 | 0 | **green** |
| [`20260916-094427`](20260916-094427/) | unknown | unknown | 0.1.0 | 0/0 | 93 | 914/0/914 | pass | 20604 | 2381 | 7.9 | 2.2 | 15 | 0 | **green** |
| [`20260912-020433`](20260912-020433/) | unknown | unknown | 0.1.0 | 0/0 | 62 | 245/0/245 | pass | 9511 | 1029 | 7.5 | 2.7 | 15 | 0 | **green** |
| [`20260912-015750`](20260912-015750/) | unknown | unknown | 0.1.0 | 0/0 | 62 | 244/0/244 | pass | 9483 | 1026 | 7.5 | 2.7 | 15 | 0 | **green** |
| [`20260912-004826`](20260912-004826/) | unknown | unknown | 0.1.0 | 0/0 | 62 | 233/0/233 | pass | 9178 | 981 | 7.6 | 2.8 | 15 | 0 | **green** |
| [`20260911-141809`](20260911-141809/) | unknown | unknown | 0.1.0 | 0/0 | 62 | 154/0/154 | pass | 6820 | 676 | 6.6 | 2.8 | 15 | 0 | **green** |

## Test suite

**2344 cases** — 2343 passed, 0 failed, 1 skipped. The generated inventory
[`20261102-004743/test-cases.md`](20261102-004743/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **2337 → 2344** since the previous run.

**1 case(s) reported a `skip`.** A skip is counted in the total and never in `passed`, and at
the release gate it is NOT EVALUATED rather than passed (`automated-tests-§3`).

## Lint

**0 warnings / 0 errors over 206 files** (`luacheck .`).

Read that figure with its scope attached: `.luacheckrc` excludes 6 path(s) from it — `libs/`, `tests/_kit/`, `docs/audits/`, `docs/reviews/`, `docs/automated-tests/`, `_dev/` —
so nothing under them is in the count above. A `0/0` that never moves is partly a statement about
what was never looked at, which is why the exclusions are NAMED here on every run rather than left
to whoever thinks to open `.luacheckrc`.

## Perf

**12 scenarios** from `tests/perf.lua`; the measurements are in
[`20261102-004743/perf.json`](20261102-004743/perf.json).

| `scenario` | `iters` | `ms/iter` | `api/iter` | `bytes/iter` |
|---|---|---|---|---|
| `compile` | 2000 | 0.01126 | 0.0 | 4136.0 |
| `applyPass` | 200 | 1.74354 | 30.0 | 107063.3 |
| `restyle` | 200 | 1.56044 | 0.0 | 50646.4 |
| `restyleText` | 200 | 0.82193 | 0.0 | 32068.1 |
| `restyleTextGlow` | 200 | 3.80002 | 0.0 | 144964.1 |
| `visibilityPass` | 1000 | 0.02499 | 8.0 | 384.0 |
| `unitSwap` | 1000 | 0.00337 | 1.0 | 0.0 |
| `probeOverheadOff` | 1000 | 0.02554 | 9.0 | 384.0 |
| `probeOverheadOn` | 1000 | 0.02461 | 9.0 | 384.5 |
| `probeAbsent` | 1000 | 0.02032 | 9.0 | 384.0 |
| `unitAuraFiltered` | 1000 | 0.00020 | 0.0 | 0.0 |
| `emptyWatchAura` | 1000 | 0.00007 | 0.0 | 0.0 |

`perf` never fails a run and never blocks a commit — it is recorded, read and compared, not
thresholded (`performance-§9`). It does gate the **tag** (`automated-tests-§3`).

## Complexity watch list

Current as of [`20261102-004743`](20261102-004743/) — **this run's measurement, not its diff.** Max CCN **15** across 6150
functions, **0** of them warned on; 7 file(s) in the 1000–1500 band and 0 over the 1500 cap
(`layout-§1`).

Every row below is generated from this run's own `lizard` output. **The `Disposition` column is
the one authored cell in this file** (`automated-tests-§4`, *the one boundary*): it is carried
forward verbatim while its entry is unchanged, and left **blank** when the entry is new — a blank
cell is this file saying something crossed and nobody has ruled on it yet.

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/Database_Migrations.lua` | 1181 | Accepted — newly in the band at this run (935 → 1076, the skin steps through v15); 14 frozen `Database.MigrateV` step bodies with their private helpers, 50 functions, max CCN 15 (`Database.MigrateV15`, at the threshold, not over it). Steps are independent and frozen once shipped, so the size is ladder length, not tangle |
| 1000–1500 (on notice) | `defaults/Categories.lua` | 1344 | Accepted as a tracked deviation: `docs/ARCHITECTURE.md` → `## Documented deviations`, the `layout-§1` row for this file (FX-AM-SIZE). Data, 8 functions, max CCN 4, and `tools/spell-research/` reads and rewrites this one path, so a split is not a pure move |
| 1000–1500 (on notice) | `modules/Anchors.lua` | 1078 | Accepted — newly in the band at this run (982 → 1068, the skin seam on the unlock furniture); 72 functions, max CCN 13 (`Anchors.FlowRoot`). One concern, where a container sits and its drag handle; the join and snap code are already peeled into `modules/Anchors_Attach.lua` and `modules/Anchors_Snap.lua` |
| 1000–1500 (on notice) | `modules/Anchors_Snap.lua` | 1156 | Accepted — newly in the band at the 1.1.0 release run (a new file: the snap core for drag to attach, #22); 60 functions, max CCN 15 (`classify`, at the threshold, not over it). One concern, the pair pick and its geometry; `modules/Anchors_SnapRect.lua` already holds the rect reads, and the pick is the next seam if it grows |
| 1000–1500 (on notice) | `modules/Container.lua` | 1021 | Accepted — newly in the band at this run (928 → 1020), just inside it; 64 functions, max CCN 15 (`ContainerClass.ApplyHang`, at the threshold, not over it). One cohesive class, a live container's anchor, handle and engine lifecycle, with the twin engines already in `modules/Container_Twins.lua` |
| 1000–1500 (on notice) | `settings/Filters.lua` | 1018 | Accepted — newly in the band at this run (971 → 1018), just inside it; 49 functions, max CCN 11 (`viewWhich`). One settings page: its four tabs, their grids and the per-category help text, so size rather than tangle |
| 1000–1500 (on notice) | `settings/Schema.lua` | 1017 | Accepted — newly in the band at this run (975 → 1017, the follow rows and the tinted choices of FS-AM-FLIP and FS-AM-FIX), just inside it; the seam every write goes through. Split if it grows again. |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

