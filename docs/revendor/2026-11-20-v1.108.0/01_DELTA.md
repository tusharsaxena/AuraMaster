Delta: LibKa0s v1.107.0 -> v1.108.0

Recorded before the commit. The payload was taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.108.0 LibKa0s testkit tools | tar -x -C <scratch>/new` (tag commit 56c20b76). `git -C ../LibKa0s ls-remote --tags origin v1.108.0` prints nothing: the tag is local-only, which the cross-repo run expects (Ka0sAddonsCommonTasks `docs/2026-11-20-LIBKA0S_94_97_99_100/`, item SD-RV-AM). This is a new re-vendor, not a refresh, because the provenance line named v1.107.0 before the copy. The run's adoption interview and issue filing are skipped; its adoption items are SD-SK-AM and SD-AM-99 (03_DECISIONS.md).

## Step 0 pre-flight (this addon)
- The newest single-tag bundle, `docs/revendor/2026-11-19-v1.107.0/`, states `Delta: LibKa0s v1.106.0 -> v1.107.0`, and the line was rolled to v1.107.0 by ffeaa16 (AF-RV-AM), whose parent named v1.106.0. The base is ok and needs no correction.

## 3a Base
- `grep -n 'Bundles' CLAUDE.md` gave `36:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.107.0 (MIT).`
- The last payload commit, `git log -1 --format=%h -- libs/LibKa0s tests/_kit`, is ffeaa16, and its `CLAUDE.md` names v1.107.0. The two agree.
- Before the copy, `diff -rq <scratch>/claimed/LibKa0s libs/LibKa0s` (the v1.107.0 extract) printed only `Only in <scratch>/claimed/LibKa0s/media/...` lines (the undeclared icons and the voice packs), and `diff -rq <scratch>/claimed/testkit tests/_kit` printed nothing: `payload-matches`.
- Range: `git -C ../LibKa0s log --oneline v1.107.0..v1.108.0` lists 14 commits, 93633f47 (SD-LK-94) to 56c20b76 (SD-LK-REL).

## 3b/3c Per-file minors that moved (old = this addon, new = v1.108.0)
Command: the spec's loop over the file list in `<scratch>/new/LibKa0s/LibKa0s.xml`, printing the rows where old and new differ.
```
Core.lua                   MINOR 18          -> 19
Callout.lua                MINOR 4           -> 5
CalloutSettings.lua        SETTINGS_MINOR 5  -> 6
WaypointArrow.lua          MINOR 2           -> 3
WaypointArrowSettings.lua  SETTINGS_MINOR 2  -> 3
Charts.lua                 MINOR 2           -> 3
ChartsRender.lua           RENDER_MINOR 1    -> 2
SkinPaint.lua              PAINT_MINOR 19    -> 20
SkinPaintHud.lua           HUD_MINOR 1       -> 2
SkinPaintControls.lua      CONTROLS_MINOR 18 -> 19
Widgets.lua                MINOR 29          -> 30
WidgetsDropdown.lua        DROPDOWN_MINOR 2  -> 3
WidgetsDragHandle.lua      DRAG_MINOR 15     -> 16
WidgetsDragHandleTip.lua   DRAGTIP_MINOR 2   -> 3
WidgetsLineChart.lua       CHART_MINOR 7     -> 8
WidgetsBar.lua             BAR_MINOR 1       -> 2
OptionsCompose.lua         COMPOSE_MINOR 19  -> 20
```
Every other file matched. There was no cross-major skew. No file is added or removed.

## 3d Diffs
After the copy and before the prune, `diff -r --strip-trailing-cr` and `diff -r` of both payloads against the v1.108.0 extract were empty in both directions, so no file removed upstream survives here. After the prune, only `Only in <scratch>/new/LibKa0s/media/icons` and `.../media/sounds` lines remain, and `diff -rq <scratch>/new/testkit tests/_kit` is empty.

## 3e Consumption map
Unchanged from the v1.107.0 bundle: Bus, Compat, Core, Skin, DebugLog, Env, Launcher, Lifecycle, Media, Perf, Pool, Widgets, Options, Schema and Slash. Of the moved files this addon reaches Core, SkinPaint, SkinPaintHud and SkinPaintControls (through its skin owner, `core/SkinSetup.lua`), Widgets and WidgetsDragHandle and WidgetsDragHandleTip (the drag strip, `modules/Anchors.lua`), WidgetsDropdown (the settings panel's dropdowns) and OptionsCompose (`NS.Helpers.FontGroup`, `BorderGroup`, `BarGroup`, `ColorPair` in `settings/Bars.lua`, `settings/Icons.lua`, `settings/Text.lua`, `settings/Layout.lua`). Callout, WaypointArrow, Charts, `W.Bar`, `S.ApplyBarFill` and `W.ContextMenu` are not called.

## 3f Kit
`Kit.VERSION = 57` here, `58` in the tag. Both payloads move together in one commit.

## 3g Contract delta
Read: the v1.108.0 CHANGELOG block in full, its *What a consumer owes at its re-vendor*, and `docs/api/Options/version-38.5.46.3.7.2.9.17.3.1.4.20.13.7.5.8.7.12.1.1.1.4-docs.md` *Moving to this version*. Three moves under surfaces whose signature did not change:

- **The composers emit their companions unasked (OptionsCompose minor 20).** Every composed block here already passes `fromSkin` and declares its color and shadow companions in `extra` (`NS.FollowRow`, `NS.FontFollowRows`, `settings/Schema.lua:327-338`), so the composer emits none of those twice. The one block with no companion of its own is the spark's `H.ColorPair` (`settings/Bars.lua`), which gained `container.bars.sparkColorFromSkin`, a path the template does not hold: the schema validator failed, and with it 37 cases that validate the schema. The spark is game art under the A6 Leave with no skin token (owner U-11, 2026-11-20), so the block now passes `colorFromSkin = false`, citing the ruling. Fixed in this commit.
- **An owned strip's host edge is repainted by the library (WidgetsDragHandle minor 16, SD-LK-97.5).** `Anchors.Reskin` still repaints it; the library's repaint lands after it, in the skin's real `handle.edge`. `tests/test_skin_surfaces.lua`'s edge case read the facade's sentinel and is re-pinned to the skin's real token. No code change.
- **The skin-switch spy walks `GetStatusBarTexture` (kit revision 58).** `tests/region_recorder.lua` answered a new recorder for every `GetStatusBarTexture`, so the walk never ended and the Retail shard holding `test_skin_switch` ran out of memory. The recorder's moving edge now has no `GetStatusBarTexture` of its own (it is a Texture). Fixed in this commit.

Blockers: none left after the fixes above.

## 3i Icon declaration
`LibKa0s icons: chevron-down, chevron-up, clear, close, confirm, copy, eye, help, info, move, reset, settings, volume-high.` is kept as written. The run's item list pre-decides it; nothing in this release draws a new catalog name here.

## 3j Whole-folder icon tests
`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'` finds nothing new since v1.107.0's bundle. None.
