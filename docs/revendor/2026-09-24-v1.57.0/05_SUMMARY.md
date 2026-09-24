# 05 - Summary: LibKa0s v1.56.0 -> v1.57.0

## The move

Tag `v1.56.0` -> `v1.57.0` (`aa37bc9`), base taken from the `CLAUDE.md` provenance line and
confirmed against the last payload commit (`0fc5248`). Re-vendored in the M5-AM commit that
carries this bundle. One file moved a LibStub minor (Launcher 2 -> 3), none was added or removed,
no `NEEDS_*` floor rose, and the test kit stays at revision 26 with identical bytes.

## Delivered for free (class A)

- **Launcher minor 3**: the LDB object's `OnTooltipShow` is always the library's, so the minimap
  button and any broker display show the status tooltip on hover, including while the addon is
  disabled (`launcher-§1`, standard v2.66.0).

## Contract blockers

None (`01_DELTA.md` 3g). This addon passed no `onTooltipShow`, so the change of meaning of that
field touches nothing here.

## Adopted

The descriptor fields `launcher-§1` now owes, in `core/LauncherSetup.lua`, test first
(`tests/test_launcher.lua`, five new cases):

- `version`: `NS.Version()`, the TOC's `## Version` through `core/EnvSetup.lua`.
- `isLocked`: `NS.GetSetting("locked")`, the Lock frame row's accessor.
- `isTestMode`: `NS.GetSetting("state.testMode")`, the Test mode row's accessor.
- `leftClickLabel`: `L["Toggle test mode"]`, rung (b) as the standard's `ADDONS.md` records it;
  a function, so the locale is read on every show. One new key in `locales/enUS.lua`.
- No `onTooltipShow` (the addon has no extra lines of its own) and no `slash` (the disabled hint
  reads `/am enable` out of the `disabledLine` already passed).

## Declined

None.

## Skipped or unreached

- Steps 5-8 beyond the one adoption above: the release adds no other surface.

## Suite results

| Gate | Headless tests | Lint | Complexity |
|---|---|---|---|
| Before the copy (v1.56.0) | 1350 / 0 / 0 | 0 / 0 in 119 files | not run |
| After the copy and the adoption | 1355 / 0 / 0 | 0 / 0 in 119 files | 0 above CCN 15 |
