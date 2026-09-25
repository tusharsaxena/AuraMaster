# 05 - Summary: LibKa0s v1.59.0 -> v1.60.0

## The move

Tag `v1.59.0` -> `v1.60.0` (`bed0eb1`), base taken from the `CLAUDE.md` provenance line. Re-vendored
in the `DR-AM-01` commit on `feat/2026-09-25-diagnostics-rollout`, with the provenance line and the
two other places that name the vendored tag (`DEPENDENCIES.md`'s vendor-sync paragraph,
`docs/module-map.md`'s library row). Two files moved a LibStub minor and one is new:

| File | Minor |
|---|---|
| `DebugLog.lua` | 13 -> 14 |
| `DebugLogDiagnostics.lua` | new, 1 (`LibKa0s-DebugLog-1.0` key 13 -> 14.1) |
| `Slash.lua` | 15 -> 16 |

No file was removed, no `NEEDS_*` floor rose, no major was added. The test kit moved revision
26 -> 27 (the shared `test_diagnostics_contract.lua`), copied whole in the same commit.

## Delivered for free (class A)

- The console holds 3000 lines (was 1500) with a 128-line slack; the diagnostics report's 1200-line
  cap is unchanged, so the trace behind a full report grows from 300 to 1800 lines.
- `lib.TIME_COPY`, the copy-window timing switch.
- Slash 16's `diagnostics` live verb, which AuraMaster already had in its own live set.

## Contract blockers

None (`01_DELTA.md` 3g).

## Carried in the re-vendor commit to keep the suite green

- `core/DebugLogSetup.lua`'s library-absent stub gains `RunDiagnostics` (the collection's placeholder
  line naming `/am diagnostics`, nothing written, returns 0), `BuildDiagnostics` (an empty report)
  and `DebugVerb` (`false`), for `tests/test_surface_parity.lua`'s DebugLog case. One new case in
  `tests/test_debuglogsetup.lua` pins what they do.
- `tests/run.lua` registers `{ name = "test_diagnostics_contract", dir = "tests/_kit/" }`; it is one
  declared skip until `DR-AM-02` sets `Kit.diagnostics`.
- `docs/test-cases.md` regenerated; the README badge moves to 1627/1627 (the skip is in neither
  figure, testing-§5).

## Adopted

Nothing in this run. The diagnostics helper is adopted in `DR-AM-02` (`03_DECISIONS.md`).

## Declined

None. No issue filed.

## Skipped or unreached

None.

## Suite results

Run through `ka0s-bounded` from the repo root: `lua tests/run.lua`, `luacheck .`,
`lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .`.

| Gate | Headless tests | Lint | Complexity |
|---|---|---|---|
| Before the copy (v1.59.0) | 1626 passed / 0 failed / 0 skipped | 0 / 0 in 138 files | 0 above CCN 15 |
| After the re-vendor commit (v1.60.0) | 1627 passed / 0 failed / 1 skipped (the kit's contract suite, `Kit.diagnostics` unset) | 0 / 0 in 138 files | 0 above CCN 15 |

`tests/test_vendor_sync.lua` compared both payloads against `v1.60.0` and passed.
`tests/test_anchors_close.lua` (the close mark, WidgetsDragHandle 3, unchanged in this range) stays
green: X still sets `container.enabled = false`.
