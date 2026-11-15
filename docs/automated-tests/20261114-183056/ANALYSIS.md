# Analysis — 20261114-183056

- **Addon:** AuraMaster 1.1.0 (the presets record, labeled "presets AM-PR08", not a release run)
- **Verdict:** amber, on both kit profiles (perf failed its own assertions; lint and tests pass)
- **Commit:** 73dabd9 (feat/2026-11-14-presets), clean tree
- **Previous run:** 20261114-104251 (at 5ff012f, 27 commits behind this one)

## Headline

This run records the presets branch after the whole-branch review fixes: the preset data and placement builder (`defaults/Presets.lua`), apply and preview (`modules/Presets.lua`), the Simple seed for new profiles with schema v19, the first-run picker (`settings/PresetPicker.lua`), `/am preset` and the Presets tab (`settings/ContainersPresets.lua`). Both gating suites pass on both profiles. Lint is 0/0 over 224 files. Tests are 2469 passed, 1 skipped, 0 failed of 2470 on Retail and 2468 passed, 2 skipped, 0 failed on Forever ([`manifest.json`](manifest.json)). The verdict is amber because `perf` failed 4 of its own deterministic assertions ([`perf.txt`](perf.txt)). `tests/perf.lua` still expects the four old starters, but AM-PR04 seeds new profiles with Simple's 3 containers, none of them text. That is a stale perf fixture, not a runtime regression, and it is the one thing to act on (see Actions). Complexity is at `pass` with max CCN 15, 0 warnings, 0 blind and 0 crashed files.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261114-104251 |
|---|---|---|---|---|
| lint (gates commit and tag) | pass | 0 warnings / 0 errors in 224 files | [`lint.txt`](lint.txt) | files 213 → 224 |
| tests (gates commit and tag) | pass | 2469 passed, 1 skipped, 0 failed, 2470 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 2378 → 2470 |
| tests, Forever profile (gates commit and tag) | pass | 2468 passed, 2 skipped, 0 failed, 2470 total | no artifact: `KA0S_KIT_CLIENT=forever` run with `--no-bundle` (console only) | total 2378 → 2470 |
| perf (recorded; gates the tag only) | **fail** | 10 scenarios, 4 assertions failed | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 12 → 10 scenarios; see below |
| complexity (recorded; gates the tag only) | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 58589 → 61902, functions 6234 → 6546 |

| Metric | Value |
|---|---|
| Total NLOC | 61902 |
| Functions | 6546 |
| Avg NLOC / function | 8.3 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 76.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 9 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

AuraMaster is `Retail · Forever` in the roster, so the battery ran twice (`clients-§6`). The Retail run wrote this bundle. The Forever run (`KA0S_KIT_CLIENT=forever tests/_kit/run-automated-tests.sh --no-bundle`) ran all four suites and wrote nothing. Its console reported lint 0/0 in 224 files, tests 2468 passed, 0 failed, 2 skipped of 2470, perf at `fail` with the same 10 scenarios and the same 4 failed assertions, and complexity at `pass` with the same lizard figures. Its verdict was amber too. Those Forever figures are console output with no artifact in this bundle.

**perf is a regression, caused by the branch's test fixture and not by runtime code.** [`perf.txt`](perf.txt) lists 4 failed assertions:

- `restyleText: no text container among the starters`
- `visibilityPass: the fixture holds 3 engines, pinned at 8`
- `visibilityPass makes 3.0 engine calls, expected 8 (one SetEnabled per engine)`
- `probeOverheadOff makes 3.0 engine calls, expected 8`

`tests/perf.lua` builds its fixture from a fresh profile and expects the four old starters. AM-PR04 (fb7a5c2) retired `NS.STARTER_CONTAINERS` and seeds a new profile with Simple (Bars), which holds 3 containers and no text container ("200 writes coalesced into 1 apply pass; 3 containers", [`perf.txt`](perf.txt)). The headless harness kept the old four as furniture through `tests/starters_fixture.lua`, but `tests/perf.lua` did not adopt it, and perf is not part of the commit gate, so no gate run caught it. `restyleText` and `restyleTextGlow` need a text container and did not run, which accounts for 12 → 10 scenarios. The scenarios that did run measured a smaller fixture, so their figures cannot be compared with the previous run's (see What moved). The failure is the same on both profiles.

The Retail skip is the same pre-existing case as in the previous run: the diagnostics contract case for an addon that opts out of logging, skipped because this addon keeps the default ([`tests.txt`](tests.txt)). The Forever profile's second skip is the v12 frozen-split case, as in the previous record. Both skips count toward the total, not toward `passed`, and at a release they read as NOT EVALUATED.

## What moved

- **lint**: 213 → 224 files, still 0/0 ([`lint.txt`](lint.txt)). The 11 new files are `defaults/Presets.lua`, `modules/Presets.lua`, `settings/ContainersPresets.lua`, `settings/PresetPicker.lua`, `tests/starters_fixture.lua`, `tests/test_pages_presets.lua`, `tests/test_presetpicker.lua`, `tests/test_presets_apply.lua`, `tests/test_presets_data.lua`, `tests/test_presets_preview.lua` and `tests/test_presets_seed.lua`.
- **tests**: 2378 → 2470 (+92, from a diff of the two [`test-cases.md`](test-cases.md) inventories). Six new suite files add 87 cases: `test_presets_data.lua` (14), `test_presets_apply.lua` (11), `test_presets_preview.lua` (19), `test_presets_seed.lua` (7), `test_presetpicker.lua` (25) and `test_pages_presets.lua` (11). `test_slash_verbs.lua` went from 55 to 60 cases with `/am preset`. The skip counts did not change: 1 on Retail, 2 on Forever.
- **perf**: not comparable with the previous run, because the fixture changed under it (3 containers instead of 4, no text starter). `restyleText` and `restyleTextGlow` are absent. `applyPass` went from 30.0 to 21.0 api/iter and from 107062.5 to 69329.6 bytes/iter. `visibilityPass`, `probeOverheadOff`, `probeOverheadOn` and `probeAbsent` went from 8.0–9.0 to 3.0 api/iter, and `unitSwap` from 1.0 to 0.0 ([`perf.json`](perf.json)). Those drops reflect fewer engines in the fixture and say nothing about what the code costs. `compile` (4136.0 → 3864.0 bytes/iter) measures container 1, which is now a Simple container rather than the old starter. A comparable reading is owed by the first run after the fixture fix.
- **complexity**: +3313 NLOC and +312 functions ([`complexity.txt`](complexity.txt)). Avg CCN rose from 2.3 to 2.4 and avg tokens per function from 75.6 to 76.0. Avg NLOC per function held at 8.3, max CCN held at 15, and there are 0 warnings. The avg CCN rise is a small density signal, and the new code accounts for it: `defaults/Presets.lua` alone averages CCN 4.3 over 22 functions (the placement builder). No function crossed 15.

## Complexity watch list

Functions `lizard` warned on: none.

Files by band: 9 files, up from 7. The 7 carried files keep their dispositions. `core/Database_Migrations.lua` grew 1200 → 1213 lines with the v19 step (AM-PR04), and its max CCN is still 15 (`Database.MigrateV15`). Two files entered the band at this run, and their dispositions in `RESULTS.md` are ruled here:

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/ContainerManager.lua` | 1000 | Accepted — 956 → 1000 with the preview snapshot and exact restore (AM-PR03), at the band floor; 68 functions, max CCN 13 (`CM.FlushPending`). The preview snapshot and restore is the next seam to peel if it grows |
| 1000–1500 (on notice) | `tests/test_slash_verbs.lua` | 1034 | Accepted — 950 → 1034 with the five `/am preset` cases (AM-PR05); a suite file, case count rather than tangle, 88 functions, max CCN 5. Split by verb family if it grows again |

The figures come from [`complexity.txt`](complexity.txt). This is not a release run, so it does not add to the three-release shelf life of any **Accepted** entry.

## Actions

1. `tests/perf.lua`: build the perf fixture from `tests/starters_fixture.lua` (the four old starters the headless harness already keeps as furniture), or re-pin its expectations to Simple's 3 containers and give `restyleText`/`restyleTextGlow` a text container. Then re-run this battery so perf is back at `pass` with a figure comparable to 20261114-104251. Until then the tag gate cannot pass (perf must be at `pass` for a release, `automated-tests-§3`). This is new here: a regression from AM-PR04 (fb7a5c2), with no tracking ID yet.
2. The FX-AM-SIZE ruling on `defaults/Categories.lua` carried from the previous record is still open. The file is unchanged at 1399 lines, so nothing new is owed here.
