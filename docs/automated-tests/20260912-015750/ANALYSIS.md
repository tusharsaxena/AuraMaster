# Analysis — 20260912-015750

- **Addon:** AuraMaster 0.1.0
- **Verdict:** green
- **Commit:** d6221d06bebc2885234dd161684d99da20eb865b (fix/review-audit-2026-09-11)
- **Previous run:** 20260912-004826

## Headline

All four suites pass ([`manifest.json`](manifest.json)) and the complexity watch list is empty. One
thing needs action: the visibility pass now allocates 432.0 bytes/iter against 288.0 in the previous
run ([`perf.txt`](perf.txt)). That is a deterministic rise (the runner stops the collector inside
measured loops), and it contradicts the claim that the visibility pass is allocation-free.

## Suites

| Suite | Status | Result | Artifact | Moved since 20260912-004826 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 62 files | [`lint.txt`](lint.txt) | No change |
| tests | pass | 244 passed, 0 skipped, 0 failed, 244 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 233 → 244 (+11) |
| perf | pass | 9 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | visibilityPass and the probe arms +144.0 bytes/iter; applyPass +144.0 |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | Functions 981 → 1026; avg CCN 2.8 → 2.7 |

**Complexity is reported in full** (from [`manifest.json`](manifest.json) `suites.complexity`):

| Metric | Value |
|---|---|
| Total NLOC | 9483 |
| Functions | 1026 |
| Avg NLOC / function | 7.5 |
| Avg CCN | 2.7 |
| Max CCN | 15 |
| Avg tokens / function | 59.9 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.0 / 0.0 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |

**perf** passes its assertions but carries the regression below.

## What moved

- **tests:** 233 → 244 cases ([`tests.txt`](tests.txt)). The new cases cover the unlock handle (its
  placement outside the container for all four growth directions, look, width, clamp and help mark),
  one apply after combat for a stale class, the styler's error stack, a drag started on the help mark,
  the container enable as a visibility row, and a non-string styler error.
- **lint:** unchanged at 0/0 over 62 files.
- **complexity:** functions 981 → 1026 and NLOC 9178 → 9483 (+305) with avg CCN 2.8 → 2.7, avg NLOC
  7.6 → 7.5 and avg tokens 59.8 → 59.9. The addon grew without getting denser. Max CCN is 15 with no
  warnings, and no file is in a band.
- **perf** ([`perf.txt`](perf.txt), against the previous run's `perf.txt`):
  - `visibilityPass` 288.0 → 432.0 bytes/iter, and `probeOverheadOff`, `probeAbsent` 288.0 → 432.0
    and `probeOverheadOn` 288.6 → 432.6, because all three run a visibility pass. The dormant bracket
    is still free: `probeOverheadOff` equals `probeAbsent`.
  - `applyPass` 22802.3 → 22946.3 bytes/iter (+144.0), which ends in a visibility pass.
  - `compile` 3048.0, `restyle` 43221.8, `unitSwap` 0.0 and `unitAuraOther` 0.0 are unchanged, and
    every `api/iter` figure is unchanged (applyPass still 22.0 engine calls over 3 containers).
  - +144 bytes over the scenarios' 3 containers is 48 bytes per container per pass. **Measured outside
    this bundle:** running `tests/perf.lua` at each commit between the two runs puts the whole rise at
    `1ee9d01` (the unlock handle placed outside the container). `a339f5d` reads 288.0 and every commit
    from `1ee9d01` on reads 432.0.

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
`Preview.Show` and `TS.Scan` at 14. Unchanged since the previous run.

## Actions

1. `modules/Anchors.lua` (the unlock handle, `1ee9d01`): the visibility pass allocates 48 bytes per
   container per pass that it did not before. Find the allocation in the handle's per-pass update
   and remove it, and have `tests/perf.lua` assert the visibility pass's allocation so the claim is
   pinned rather than asserted in a comment. New here; no deviation ID or review finding tracks it.
2. Carried from `20260912-004826`: `Preview.Offset` and `Bars.FillPreview` remain at CCN 15; extract
   a helper before the next change to either.
