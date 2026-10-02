# 05 - Summary: LibKa0s v1.67.0 -> v1.68.0

## The move

Tag `v1.67.0` -> `v1.68.0` (`cc9f5eb`, a local tag), base taken from the `CLAUDE.md` provenance line.
Re-vendored in the first `TP-AM-01` commit on `feat/2026-10-02-drag-attach`, with the provenance line,
`DEPENDENCIES.md`'s vendor-sync paragraph and `docs/module-map.md`'s library row. One file moved
(`01_DELTA.md` 3c): WidgetsDragHandle 3 -> 4. No file added or removed. The test kit stays at
revision 35. No span bundle and no base correction owed.

## Delivered for free (class A)

The tooltip's evaluate/draw split; without a hook the calls are minor 3's (`02_CANDIDATES.md` A).

## Contract blockers

None (`01_DELTA.md` 3g).

## Adopted

`tooltipPlace`, in the second `TP-AM-01` commit: the strip and close-mark tooltips sit beside the
strip, flipping left near the right screen edge, and fall back to the cursor when the strip's rect
reads secret (`02_CANDIDATES.md` B).

## Declined

None. No issue filed.

## Suite results

Run through `ka0s-bounded` from the repo root.

| Gate | Headless tests | Lint | Complexity |
|---|---|---|---|
| After the copy and the provenance roll (v1.68.0) | 2015 passed / 0 failed / 1 skipped (2016) | 0 / 0 in 167 files | `lizard -C 15 -w`: no warnings |

`docs/test-cases.md` regenerated with no change; the README badge stays at 2015/2015.
