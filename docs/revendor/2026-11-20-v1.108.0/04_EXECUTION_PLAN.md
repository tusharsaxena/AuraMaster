# 04 Execution plan

- **SD-RV-AM**: both payloads copied whole from the tag and pruned, the provenance roll, the `DEPENDENCIES.md` verify line, the standard reference refreshed to v2.116.0 (the vendored quirks catalog in `docs/midnight-quirks.md` restamped v2.116.0; its body is byte-identical to the standard's `client-quirks.md` at v2.116.0), and the fixes the payload forced (01_DELTA 3g): the spark's `colorFromSkin = false` (U-11), `tests/region_recorder.lua`'s edge, and `tests/test_skin_surfaces.lua`'s edge case. `docs/test-cases.md` regenerated and the badge moved.
- **SD-SK-AM**: the R-2 default flips and their one-time step, the overrides recorded, the guard declarations (B1, B2).
- **SD-AM-99**: the secret-rect strip tooltip's known limitation retired, DRAG-20 and a new smoke check, a headless case.
