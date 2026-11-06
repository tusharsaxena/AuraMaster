# Summary

- **Tag:** v1.89.0 -> v1.90.0 (local tag `4485b8f`, not pushed), base from the provenance line. Kit 51 -> 51.
  Moved: Core 15 -> 16, Skin 16 -> 17, SkinPaint 18 -> 19, SkinPaintExtras 17 -> 18, Widgets 23 -> 24,
  WidgetsAutocomplete 7 -> 8, OptionsAppearance 6 -> 7. No span bundle, no base correction, no refresh.
- **For free:** the one-physical-pixel edge on the library's dropdown, search box, menus and autocomplete
  (SF1-L1; AuraMaster draws none of them), and the Scope-keeping skin copy (SF1-L2; AuraMaster is not a
  `keepScope` owner, so its copies behave as before).
- **Blockers:** none. No stub owes a new member, no test pins an old minor, no test pins a library edge size.
- **Icons:** line kept, `chevron-down, chevron-up, clear, close, confirm, copy, eye, help, info, move, reset,
  settings, volume-high`; the prune removed 5826 catalog files after the whole copy (kept 14), so the shipped
  set is unchanged and stays Open Iconic only. README credits unchanged. No provenance split. No dead stub
  mirrors.
- **Adopted:** nothing. **Declined:** nothing filed; `keepScope` not applicable.
- **Column-header check (SF1 item 5):** AuraMaster draws no column-header row in a window of its own. Its only
  column headers are the Filters tab's category grids in the settings panel, drawn by the library's
  `O.ChoiceGrid` (`libs/LibKa0s/OptionsWidgets.lua:946-965`, plain AceGUI Labels and no line); the Section
  heading over a grid (`settings/Filters.lua:686`) sits above the Show all / Hide all buttons, not on the header
  row. Nothing to change.
- **Gate at the copy:** `ka0s-bounded luacheck .` 0 warnings / 0 errors in 207 files;
  `ka0s-bounded lua tests/run.lua` 2355 passed, 0 failed, 1 skipped (2356 total, 16 shards); complexity
  (`run-automated-tests.sh --suite complexity --no-bundle`) pass, 0 functions above CCN 15. Largest authored
  file 1344 lines (`defaults/Categories.lua`), under the 1500 cap.
