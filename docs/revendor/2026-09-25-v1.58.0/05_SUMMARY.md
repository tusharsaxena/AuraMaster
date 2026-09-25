# 05 - Summary: LibKa0s v1.57.0 -> v1.58.0

## The move

Tag `v1.57.0` -> `v1.58.0` (`34931c9`), base taken from the `CLAUDE.md` provenance line and
confirmed against the last payload commit (`826af78`). Re-vendored in the M6-AM commit that
carries this bundle. One file moved a LibStub minor (Launcher 3 -> 4), none was added or removed,
no `NEEDS_*` floor rose, and the test kit stays at revision 26 with identical bytes.

## Delivered for free (class A)

- **Launcher minor 4**: left-click opens the settings panel in either state; the tooltip hints read
  `Left-click: Open settings` / `Right-click: Options menu` (`launcher-§2`, standard v2.67.0).

## Contract blockers

Two, both taken in this commit (`01_DELTA.md` 3g): the left button no longer runs `onClick` (this
addon's rung (b) test-mode toggle), and the disabled refusal (`disabledLine`) is retired.

## Adopted

The toggle pairs `launcher-§2` now owes, in `core/LauncherSetup.lua`, test first
(`tests/test_launcher.lua`, `tests/test_disabled.lua`, through a new `tests/mock_menu.lua` modeled
on the library's repo-local one):

- `setEnabled` -> `NS.Slash.SetEnabled`, the handler `/am enable` / `/am disable` run
  (`runEnabled`), beside the existing `isEnabled`.
- `toggleLock` -> `NS.Slash.ToggleLock`, the handler `/am lock` / `/am unlock` run (`runLock`),
  beside `isLocked` (the Lock frame row's `locked`).
- `toggleTestMode` -> `NS.Slash.ToggleTestMode`, what a bare `/am test` runs (`runTest("")`),
  beside `isTestMode` (the Test mode row's `state.testMode`).
- No `isWindowShown` / `toggleWindow`: the addon has no primary window. The menu therefore reads
  Enabled · Locked · Test mode, which is the row the standard's `ADDONS.md` records for this addon.
- Removed `onClick`, `leftClickLabel` and `disabledLine`, and the `Toggle test mode` locale key
  that only `leftClickLabel` read. `version`, `isLocked` and `isTestMode` stay as M5 left them.

## Declined

None.

## Skipped or unreached

- Steps 5-8 beyond the one adoption above: the release adds no other surface.

## Suite results

| Gate | Headless tests | Lint | Complexity |
|---|---|---|---|
| Before the copy (v1.57.0) | 1355 / 0 / 0 | 0 / 0 in 119 files | 0 above CCN 15 |
| After the copy and the adoption | 1359 / 0 / 0 | 0 / 0 in 120 files | 0 above CCN 15 |
