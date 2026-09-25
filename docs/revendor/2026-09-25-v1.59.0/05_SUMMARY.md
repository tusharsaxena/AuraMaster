# 05 - Summary: LibKa0s v1.58.0 -> v1.59.0

## The move

Tag `v1.58.0` -> `v1.59.0` (`53c141a`, a local tag: spec D3), base taken from the `CLAUDE.md`
provenance line and confirmed against the last payload commit (`d25ca55`). Re-vendored in commit
`2abe552` (`B8-P9: re-vendor LibKa0s v1.59.0`). One file moved a LibStub minor (WidgetsDragHandle
2 -> 3, `LibKa0s-Widgets-1.0` 10.2 -> 10.3), none was added or removed, no `NEEDS_*` floor rose, and
the test kit stays at revision 26 with identical bytes.

## Delivered for free (class A)

Nothing visible: a DragHandle spec without `onClose` is the 10.2 strip exactly, which the library
suite pins as literals.

## Contract blockers

None (`01_DELTA.md` 3g).

## Adopted

The close mark, the one surface this release was cut for. It was not offered as a candidate: the
owner decided it before the release (spec D3 and `CX-3`, owner feedback #3), so there was no
interview. It landed in the second `B8-P9` commit, test first (`tests/test_anchors_close.lua`, six
cases, red on the copy alone because no `h.close` was built):

- `modules/Anchors.lua` `BuildHandle` passes `closeIcon = NS.Icon("close")`, `onClose` and
  `closeTooltip`. `disableContainer` writes `container.enabled = false` through `NS.SetByPath`, with
  no confirmation, and prints one `NS.L` chat line naming the container and how to turn it back on.
  The row's `visibility` effect then hides that container's preview, outline and strip, as the
  Enabled checkbox does. `closeTooltipSpec` says the same, with a function title that follows a rename,
  cursor-owned under the untrusted-layout anchor.
- Right-click on the X opens the Containers page (the library routes it to `onRightClick`), and a
  drag that starts on it moves the container (the library copies the strip's drag scripts).
- `tests/test_anchors.lua` `RESERVE2` is re-pinned from 58 to 94 (`2 * (29 + 18)`): the strip is 36px
  wider and the label stays centered.
- Two locale keys, ASCII. `core/MediaSetup.lua`'s comment now names both marks.

## Declined

None.

## Skipped or unreached

Steps 5-6 beyond the owner-decided adoption: the release adds no other surface.

## Suite results

| Gate | Headless tests | Lint | Complexity |
|---|---|---|---|
| Before the copy (v1.58.0) | 1422 / 0 / 0 | 0 / 0 in 126 files | 0 above CCN 15 |
| After the copy alone (v1.59.0) | 1422 / 0 / 0 | 0 / 0 in 126 files | 0 above CCN 15 |
| After the adoption | 1428 / 0 / 0 | 0 / 0 in 127 files | 0 above CCN 15 |
