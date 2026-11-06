# Summary

- **Tag:** v1.90.0 -> v1.91.0 (local tag `55bfbb4`, not pushed), base from the provenance line. Kit 51 -> 51.
  Moved: Core 16 -> 17, SkinPaintExtras 18 -> 19, Widgets 25 -> 26, WidgetsLineChart 6 -> 7. New: CorePixel 1,
  SkinPaintHud 1, SkinAceConfirm 1, WidgetsDropdown 1. No span bundle, no base correction, no refresh.
  Step 0 skipped (the installed skill's roster regex is broken; fixed upstream in this run), checked by hand
  for this addon: ok.
- **For free:** the line chart's lines in physical pixels (FU-L1; AuraMaster draws no chart), and the four
  peels (FU-L2), pure moves that leave `S.BarGloss` and `S.HudFont` as AuraMaster calls them.
- **Blockers:** none. Every library load reads the tag's `LibKa0s.xml` through `Loader.xmlFiles`, so the four
  new files load in order with no edit; no test pins a moved minor; the Skin degradation stub's `BarGloss`
  and `HudFont` keep their names.
- **Icons:** line kept, `chevron-down, chevron-up, clear, close, confirm, copy, eye, help, info, move, reset,
  settings, volume-high`; the prune removed 5826 catalog files after the whole copy (kept 14), so the shipped
  set is unchanged and stays Open Iconic only. README credits unchanged. No provenance split. No dead stub
  mirrors.
- **Adopted:** nothing. **Declined:** nothing filed.
- **Gate at the copy:** `ka0s-bounded luacheck .` 0 warnings / 0 errors in 207 files;
  `ka0s-bounded lua tests/run.lua` 2355 passed, 0 failed, 1 skipped (2356 total, 16 shards); complexity
  (`run-automated-tests.sh --suite complexity --no-bundle`) pass, max CCN 15, 0 warnings. Largest authored
  file 1344 lines (`defaults/Categories.lua`), under the 1500 cap.
- **Left for the finalize's doc sync:** `DEPENDENCIES.md:92,99` still name v1.90.0; this re-vendor commit
  moves only the provenance line, as the v1.90.0 one did.
