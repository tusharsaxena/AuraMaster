# Summary

- **Tag:** v1.85.0 -> v1.89.0, base from the provenance line. Kit 50 -> 51. Moved: Toast 3 -> 4, Widgets 22 -> 23,
  DebugLogDiagnostics 6 -> 7; new IconBrowserSources 1, IconBrowserWindow 1, IconBrowser 1. No span bundle,
  no base correction, no refresh.
- **For free:** the kit's unregister guard, the diagnostics header naming IconBrowser, Widgets 23 (flat menus
  unchanged), Toast 4 (unconsumed).
- **Blockers:** none.
- **Icons:** line kept, `chevron-down, chevron-up, clear, close, confirm, copy, eye, help, info, move, reset,
  settings, volume-high`; the prune removed 5826 catalog files after the whole copy (kept 14), so the shipped
  set is unchanged and stays Open Iconic only. README credits unchanged. No provenance split. No dead stub
  mirrors.
- **Adopted:** nothing (the plan names none for AuraMaster). **Declined:** nothing filed; IconBrowser settled,
  cascading menus and the Toast stack not applicable.
- **Gate at the copy:** `ka0s-bounded luacheck .` 0 warnings / 0 errors in 207 files;
  `ka0s-bounded lua tests/run.lua` 2355 passed, 0 failed, 1 skipped (2356 total, 16 shards). Largest authored
  file 1344 lines (`defaults/Categories.lua`), under the 1500 cap.
