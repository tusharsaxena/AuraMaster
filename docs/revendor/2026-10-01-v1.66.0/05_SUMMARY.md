# 05 - Summary: LibKa0s v1.65.0 -> v1.66.0

## The move

Tag `v1.65.0` -> `v1.66.0` (`e4c5ef7`, a local tag), base taken from the `CLAUDE.md` provenance line.
Re-vendored in the `GI-AM-RV` commit on `feat/2026-10-01-github-issue-pass`, with the provenance line
and the two other places that name the vendored tag (`DEPENDENCIES.md`'s vendor-sync paragraph,
`docs/module-map.md`'s library row). Ten files moved or arrived (`01_DELTA.md` 3c): Widgets 12 +
WidgetsReorder 1, DebugLog 19, Slash 19 + SlashParse 1, OptionsWidgets 34, OptionsTabs 8, Perf 14 +
PerfSampler 1 + PerfCommands 1. Four files were added and none removed. The test kit moves from
revision 34 to 35.

The span bundle `docs/revendor/2026-10-01-v1.64.0-v1.65.0/` was written in the same run: two tags
(v1.64.0, v1.65.0) vendored by the 2026-09-30 runs with no bundle. No base correction was needed.

## Delivered for free (class A)

Perf's zero-count ancestors in the record, `RenderGrid`'s failed-item guard, the four peels,
DebugLog minor 19's refactor, and kit 35's sighted complexity suite (`02_CANDIDATES.md` A).

## Contract blockers

None (`01_DELTA.md` 3g).

## Carried in the re-vendor commit

- The provenance line, `DEPENDENCIES.md` and `docs/module-map.md`, rolled to `v1.66.0`.
- `{ name = "test_lizard_sighted", dir = "tests/_kit/" }` wired in `tests/run.lua`.
- The raw lizard command in `docs/testing.md` and `DEPENDENCIES.md` replaced by
  `bash tests/_kit/run-automated-tests.sh --suite complexity`; `DEPENDENCIES.md`'s line citations into
  the runner re-pointed, and the Lua row names the sighted shadow.
- `docs/test-cases.md` regenerated and the README badge rolled: 1781 -> 1789 passing.

## Adopted

Nothing. Spec S4 step 1: candidates are noted, not interviewed, this cycle.

## Declined

None. No issue filed.

## Skipped or unreached

The four candidates in `02_CANDIDATES.md` B, deliberately unreached this cycle (`03_DECISIONS.md`),
for the LibKa0s consumer census (`GI-LK-13`).

## Suite results

Run through `ka0s-bounded` from the repo root: `lua tests/run.lua`, `luacheck .`,
`bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`.

| Gate | Headless tests | Lint | Complexity (sighted) |
|---|---|---|---|
| Before the copy (v1.65.0) | 1781 passed / 0 failed / 1 skipped (1782) | 0 / 0 in 151 files | not run |
| The copy alone | refused: the inventory gate names `test_lizard_sighted.lua` unwired | not run | not run |
| Wired, provenance not yet rolled | 1787 passed / 2 failed (vendor sync, both payloads against v1.65.0) / 1 skipped | not run | not run |
| After the re-vendor commit (v1.66.0) | 1789 passed / 0 failed / 1 skipped (1790) | 0 / 0 in 151 files | `pass`: 0 warnings, maxCcn 15, 4685 functions, blindFiles 0 |

`tests/test_vendor_sync.lua` compared both payloads against `v1.66.0` and passed. The sighted suite
lists 4685 functions, which is the 4685 `function` tokens the 2026-10-01 validation counted in this
repo, where raw lizard listed 4662: full parity, and no newly revealed function above CCN 15.
