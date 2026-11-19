# 04 Execution plan

Two commits.

- **AF-RV-AM**: both payloads copied whole from the tag and pruned, the provenance roll, the `DEPENDENCIES.md` verify line, the standard reference refreshed to v2.115.0 (the vendored quirks catalog in `docs/midnight-quirks.md`, stamped v2.115.0), and the host fixes the payload forced: `tests/test_anchors_handle.lua`, `tests/test_anchors_width.lua` (the reserve 130 -> 114, the "?" frame 18 -> 14 wide, the "?" against the gear), `tests/test_anchors_close.lua` (the X in the corner, the gear against it, the "?" against the gear) and `tests/test_anchors_tooltip.lua` (the strip tooltip centered above the strip, the library's attached placement). Docs: ARCHITECTURE's strip-marks paragraph, module-map's close-suite row, smoke CONT-30 and DRAG-20, `docs/test-cases.md` regenerated.
- **AF-STRIP-AM**: delete `modules/Anchors_Tooltip.lua`, its TOC line and its `tooltipPlace` binding in `modules/Anchors.lua`; re-point the suites that tested it at the library's attached placement and at a guard that `BuildHandle` passes no `tooltipPlace`, the explicit `closeTooltip` and `settingsTooltip`, `onClose` and a settings opener. Docs ripple per that commit.
