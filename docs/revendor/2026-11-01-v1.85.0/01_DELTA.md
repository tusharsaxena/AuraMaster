Delta: LibKa0s v1.84.0 -> v1.85.0

Part of Ka0sAddonsCommonTasks `docs/2026-11-01-FULL_SKINNING/` (FS-AM-RV). The tag is local, cut by that run's `FS-REL`, at `09a835c`.

## Base (3a)

`grep -n '[Bb]undles' CLAUDE.md` names v1.84.0. `diff -rq` of both payloads against `git archive v1.84.0` shows only the undeclared icons: the bytes are v1.84.0 (3b agrees).

Newest single-tag bundle `2026-10-31-v1.84.0`: no correction owed.

## Per-file minors (3c), moved files only

`for f in LibKa0s.xml files: grep the [A-Z_]*MINOR constant, old against tag`

| File | old | new |
|---|---|---|
| Glow.lua | 1 | 2 |
| Skin.lua | 11 | 13 |
| SkinDefs.lua | 19 | 24 |
| SkinDefsOthers.lua | 1 | 6 |
| SkinPaint.lua | 13 | 16 |
| SkinPaintExtras.lua | 7 | 13 |
| SkinPaintControls.lua | 11 | 14 |
| SkinEUI.lua | 2 | 3 |
| SkinAce.lua | 6 | 9 |
| Widgets.lua | 17 | 20 |
| WidgetsReorder.lua | 3 | 5 |
| WidgetsDragHandle.lua | 10 | 12 |
| WidgetsLineChart.lua | 5 | 6 |
| WidgetsAutocomplete.lua | 5 | 6 |
| WidgetsCopyWindow.lua | 2 | 4 |
| DebugLogWindow.lua | 2 | 3 |
| Launcher.lua | 5 | 6 |
| OptionsWidgets.lua | 41 | 44 |
| OptionsIds.lua | 6 | 7 |
| OptionsIdList.lua | 7 | 8 |
| OptionsTabs.lua | 13 | 15 |
| OptionsCompose.lua | 16 | 17 |
| OptionsScroll.lua | 10 | 13 |
| OptionsNav.lua | 4 | 5 |
| OptionsDrawer.lua | 4 | 5 |
| OptionsKeybinds.lua | 6 | 7 |
| OptionsAppearance.lua | 5 | 6 |
| OptionsSkinPicker.lua | 5 | 7 |
| OptionsMedia.lua | 3 | 4 |
| PerfPanel.lua | 11 | 12 |
| SimPanel.lua | 9 | 10 |
| SimPanelRender.lua | 1 | 2 |

No file is behind the old tag: no cross-major skew.

## Kit (3f)

`grep -n 'Kit.VERSION'`: revision 47 -> 49. The two payloads move together.

## Consumption (3e)

Lookups outside `libs/` and `tests/`: Bus, Compat, Core, DebugLog, Env, Launcher, Lifecycle, Media, Options, Perf, Pool, Schema, Skin, Slash, Widgets. Unchanged.

## Blockers (3g, 3j)

- **Facades.** The degraded Skin facade (`core/SkinSetup.lua`) gains `Mark`, `MarkText`, `HudTextColor`, `HudLabelColor`, `BarFillColor`, `HudShadow`, `BarGloss` and `HudFont`; the Options stub (`settings/OptionsSetup.lua`) gains `LabelFont`. Fixed in the re-vendor commit.
- **Icons.** `docs/releasing.md` Step 8 for v1.85.0: `chevron-down, chevron-up, close, confirm, info, move, reset, volume-high`. Decided by the plan, not re-asked. Hand lists have drifted before; the owner's smoke is the backstop.
- **Drag strip marks.** Widgets minor 18 asks Media itself for an owned mark, so a host handing no art no longer reaches the client rung with Media present. `tests/test_anchors_handle.lua` and `tests/test_anchors_close.lua` stub Media too to reach the last rung. Fixed in the re-vendor commit.
- **`tests/test_setups.lua`** pins the drawn list; it moves with the owed names.
- No `__Attach*` site in this addon, and `__releaseChrome` has no mirror here.

## Unrecorded tags (3h)

v1.80.0 to v1.83.0 are recorded by the span bundle `2026-10-31-v1.80.0-v1.83.0`; nothing unrecorded.
