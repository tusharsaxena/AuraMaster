# 05 - Summary

**Tag moved v1.83.0 -> v1.84.0**, base taken from the provenance line. The per-file minors are in
`01_DELTA.md`. Kit revision 46 -> 47. No span bundle and no base correction.

- **For free:** the peels, `ApplyLevel` without garbage, `O.ClearScroll` keeping the band's refresher,
  the strip's measure at its own scale.
- **Contract blockers:** none. The new `PositionBlock` member joins the degradation stub list in
  `settings/OptionsSetup.lua`, in the re-vendor commit.
- **Icons:** `clear, close, copy, eye, help, info, settings` kept. The prune removed 5832 files and
  kept 8. No provenance split, no credit change, no dead stub mirror.
- **Pins moved:** `DEPENDENCIES.md` and `docs/module-map.md` name v1.84.0.
- **Adopted:** nothing from the candidate list. **Declined:** every candidate, per `03_DECISIONS.md`;
  no issue filed, by the brief.
- **Gate at the re-vendor:** `lua tests/run.lua` 2249 passed, 0 failed, 1 skipped.
  `ka0s-bounded luacheck .` 0 warnings / 0 errors in 201 files.
