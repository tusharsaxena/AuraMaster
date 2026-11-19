# 02 Candidates, LibKa0s v1.106.0 -> v1.107.0

Sources: `git -C ../LibKa0s log --oneline v1.106.0..v1.107.0`; the LibKa0s `CHANGELOG.md` block v1.107.0 and its *What a consumer owes at its re-vendor*; `docs/api/Widgets/version-28.2.7.15.2.7.8.6.1.1-docs.md`. The base is v1.106.0, from this addon's `CLAUDE.md` provenance line.

**Class A, delivered by the copy alone**
- The strip's marks read ? · settings · close, packed at 14 px frames, in the window header's tints (WidgetsDragHandle minor 15). Smoke: CONT-30.
- The strip's tooltip, and its marks', opens centered above the strip (WidgetsDragHandleTip minor 2). Smoke: DRAG-20.
- `ApplyLevel` re-levels the settings mark (LibKa0s#96).

**Class B, host change required**
- B1: delete the strip's `tooltipPlace` hook (`modules/Anchors_Tooltip.lua` and its binding), which the library no longer reads, and keep the explicit mark tooltips and the close and settings handlers on the strip. This is the run's AF-STRIP-AM.

**Class C, whole-module adoption**
- None new. The unconsumed majors are those the v1.105.0 bundle lists, and v1.107.0 changes no premise.
