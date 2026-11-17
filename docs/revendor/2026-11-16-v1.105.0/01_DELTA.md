Delta: LibKa0s v1.98.0 -> v1.105.0

Recorded before the commit. The payload was taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.105.0 LibKa0s testkit tools | tar -x -C <scratch>/new` (tag commit 79b1d9c). `git -C ../LibKa0s ls-remote --tags origin v1.105.0` prints nothing. The tag is local-only for now, which the cross-repo run expects: Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/`, item RV-AM. This is a new re-vendor and not a refresh, because the provenance line named v1.98.0 before the copy. The run covers the copy-and-bundle half only. The adoption interview and its issue filing belong to that run's phase [3] (see 02 and 03).

## Step 0 pre-flight (this addon)
- The newest single-tag bundle, `docs/revendor/2026-11-14-v1.98.0/`, states `Delta: LibKa0s v1.93.0 -> v1.98.0`.
- The commit that rolled the line to v1.98.0 is 50097a7 (AM-FP01). Its parent's `CLAUDE.md` names v1.93.0, so the base is ok and needs no correction.

## 3a Base
- `grep -n 'Bundles' CLAUDE.md` gives `36:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.98.0 (MIT).`
- The last payload commit, `git log -1 --format=%h -- libs/LibKa0s tests/_kit`, is 50097a7, and its `CLAUDE.md` names v1.98.0. The two agree.
- Before the copy the payload equals the library at v1.98.0. `diff -rq <scratch>/claimed/LibKa0s libs/LibKa0s` prints only `Only in <scratch>/claimed/LibKa0s/media/icons` and `.../media/sounds: callout` lines (the undeclared icons and the voice packs). `diff -rq <scratch>/claimed/testkit tests/_kit` prints nothing.
- Range: `git -C ../LibKa0s log --oneline v1.98.0..v1.105.0` lists 73 commits across seven releases (v1.99.0 through v1.105.0). `git -C ../LibKa0s diff --stat v1.98.0 v1.105.0` reports 499 files, +227139 / -1448, mostly voice packs, the waypoint art and docs. This addon never vendored v1.99.0 to v1.104.0, and the range covers them.

## 3b/3c Per-file minors that moved (old = this addon, new = v1.105.0)
Command: the spec's loop over the file list in `<scratch>/new/LibKa0s/LibKa0s.xml`, printing the rows where old and new differ.
```
Core.lua                   Core 17            -> 18
Tooltip.lua                (new)              -> LibKa0s-Tooltip-1.0 1
Callout.lua                Callout 2          -> 4
CalloutSettings.lua        SETTINGS_MINOR 3   -> 5
WaypointArrow.lua          (new)              -> LibKa0s-WaypointArrow-1.0 2
WaypointArrowSettings.lua  (new)              -> SETTINGS_MINOR 2
Charts.lua                 Charts 1           -> 2
SkinDefs.lua               DEFS_MINOR 27      -> 28
SkinDefsOthers.lua         OTHERS_MINOR 9     -> 10
Widgets.lua                Widgets 26         -> 27
WidgetsDropdown.lua        DROPDOWN_MINOR 1   -> 2
WidgetsReorder.lua         REORDER_MINOR 6    -> 7
WidgetsDragHandle.lua      DRAG_MINOR 13      -> 14
WidgetsDragHandleTip.lua   (new)              -> DRAGTIP_MINOR 1
WidgetsCopyWindow.lua      COPY_MINOR 5       -> 6
WidgetsHeader.lua          (new)              -> HEADER_MINOR 1
WidgetsBar.lua             (new)              -> BAR_MINOR 1
DebugLog.lua               DebugLog 22        -> 23
DebugLogDiagnostics.lua    DIAG_MINOR 9       -> 11
DebugLogWindow.lua         WINDOW_MINOR 4     -> 5
Launcher.lua               Launcher 10        -> 11
OptionsWidgets.lua         WIDGETS_MINOR 45   -> 46
OptionsNav.lua             NAV_MINOR 6        -> 7
OptionsSkinPicker.lua      PICKER_MINOR 11    -> 12
OptionsSkinPickerQueue.lua (new)              -> QUEUE_MINOR 1
IconBrowserWindow.lua      WINDOW_MINOR 1     -> 2
IconBrowser.lua            BROWSER_MINOR 1    -> 2
PerfPanel.lua              PANEL_MINOR 13     -> 14
Sim.lua                    Sim 2              -> 3
SimPanel.lua               SIM_PANEL_MINOR 10 -> 11
SimPanelRender.lua         RENDER_MINOR 3     -> 4
```
Before the copy, every other file matched v1.98.0, and every file matched the v1.98.0 extract. There was no cross-major skew.

## 3d Diffs
After the copy and before the prune, `diff -r --strip-trailing-cr` and `diff -r` of both payloads against the v1.105.0 extract were empty in both directions. No `Only in libs/LibKa0s` line appeared, so nothing was removed upstream that survives here. After the prune, only `Only in <scratch>/new/LibKa0s/media/icons` and `.../media/sounds` lines remain, and `diff -rq <scratch>/new/testkit tests/_kit` is empty.

## 3e Consumption map
`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua'`, with libs/ and tests/ excluded: Bus (core/Bus.lua), Compat (core/Compat.lua, core/Secrets.lua), Core (core/CoreSetup.lua, settings/PresetPicker.lua), Skin (core/Database.lua, core/Database_Migrations.lua, core/SkinSetup.lua, settings/OptionsSetup.lua), DebugLog (core/DebugLogSetup.lua), Env (core/EnvSetup.lua), Launcher (core/LauncherSetup.lua), Lifecycle (core/LifecycleSetup.lua), Media (core/MediaSetup.lua), Perf (core/PerfSetup.lua), Pool (core/PoolSetup.lua), Widgets (modules/Anchors.lua, settings/PresetPicker.lua), Options (settings/OptionsSetup.lua), Schema (settings/Schema.lua) and Slash (settings/Slash.lua). This is the v1.98.0 map plus the PresetPicker's Widgets and Core lookups.

Majors in the payload with no lookup here: Tooltip (new), WaypointArrow (new), Callout, Role, Charts, Glow, IconBrowser, Item, Sim and Toast.

Moved minors intersected with the consumed majors, which is the set 3g reads: Core 18, Skin (SkinDefs 28, SkinDefsOthers 10), Widgets (27 with WidgetsDropdown 2, WidgetsReorder 7, WidgetsDragHandle 14, WidgetsDragHandleTip 1, WidgetsCopyWindow 6, WidgetsHeader 1, WidgetsBar 1), DebugLog (23, Diagnostics 11, Window 5), Launcher 11, Options (OptionsWidgets 46, OptionsNav 7, OptionsSkinPicker 12, OptionsSkinPickerQueue 1) and Perf (PerfPanel 14).

## 3f Kit revision
```
grep -n 'Kit.VERSION' <scratch>/new/testkit/framework.lua tests/_kit/framework.lua
new: 20:Kit.VERSION = 57
old: 20:Kit.VERSION = 56
```
Revision 57 brings three changes. A frame with a raw event registration is now held until it unregisters (LibKa0s#75). It adds the opt-in `mock_screen.lua`. And `VendorSync.LIBRARY_MARKS` gains `settings`, which this addon already declares. The kit moves with the library in one commit, both copied whole, so the pairing rule (v1.9.0+ needs kit 11+) holds by construction. No suite here relied on a garbage collection dropping a registered frame: both profiles are green.

## 3g Contract delta and Blockers
Read from the tag's `CHANGELOG.md` blocks v1.99.0 to v1.105.0 and from `docs/api/`, for each consumed major whose minor moved:
- **Widgets 27, WidgetsDragHandle 14 / WidgetsDragHandleTip 1** (`docs/api/Widgets/version-27.2.7.14.1.7.8.6.1.1-docs.md:91`, `:93`, `:95`): the drag strip's tooltip is owned by UIParent at `ANCHOR_NONE`, and the library no longer re-owns it. `tooltipOwner` and `tooltipAnchor` are retired: they are still accepted but no longer read. A host `tooltipPlace` hook that answers `true` still keeps its point. Any other answer now falls back to the attached placement below the strip, where it used to fall back to `UIParent` at `ANCHOR_CURSOR` with the lines redrawn. This addon's hook (`modules/Anchors_Tooltip.lua`) answers `true` wherever the strip, the cursor or the screen reads, so nothing visible moves there. In the case where nothing reads, the tooltip now attaches below the strip by a relative point under pcall, which the restricted tree refuses. The tooltip is then left with no anchor (its points cleared, `libs/LibKa0s/WidgetsDragHandleTip.lua` `dhPlaceAttached`), where before it followed the cursor. This is a smoke line for the owner. `modules/Anchors.lua:709` still passes `tooltipOwner = "cursor"`, which is now inert; removing it is #92 adoption. Two suites pinned the old cursor fallback (`tests/test_anchors_handle.lua`, `tests/test_anchors_close.lua`). Both are re-pinned in this commit to one `ANCHOR_NONE` owner per show, as the document asks ("re-pins `ANCHOR_NONE`"). Not a blocker: the library documents the fix and it needs no decision.
- **DebugLog 23** (`docs/api/DebugLog/version-23.11.1.5-docs.md:52-66`): the instance gains `Report` and `Serialize`. The library-absent stub in `core/DebugLogSetup.lua` gains both, following the document's snippet with `NS.Print` and `NS.SafeToString`. `Add` now buffers plain text. No suite here pins a color code in a buffered line. The console's status line is now a 24 px `W.Footer`. No suite here pins the counter color or the 16 px line.
- **Options, OptionsNav 7** (v1.100.0, `docs/releasing.md` re-vendor note): the instance gains `SideTabs`. The Options stub in `settings/OptionsSetup.lua` gains a no-op `SideTabs`. OptionsWidgets 46 (the slider's box takes no junk) owes nothing. OptionsSkinPicker 12 moves the picker's gear into its header (#86) and attaches its toolbar tips below the control (#92). OptionsSkinPickerQueue 1 is a peel.
- **Core 18** (`docs/api/Core/version-18.1-docs.md`): `RegisterSettingsOpener`, `HasSettings` and `OpenSettings` are additive, and no host parity-checks Core. **Launcher 11** (`docs/api/Launcher/version-11-docs.md`) adds the optional `extraEntries` and re-places LibDBIcon's tooltip toward the screen's center. It adds no instance member. The launcher registers `d.openSettings` under `d.name`. Here that is `addonName` (core/LauncherSetup.lua:91, :109), the same `addonName` the debug console (core/DebugLogSetup.lua:154) and the perf panel (core/PerfSetup.lua:33) hand the library, so their new settings marks open this addon's settings (R9 C8).
- **SkinDefs 28 / SkinDefsOthers 10** (`docs/api/Skin/version-18.1.28.10.19.19.1.1.17.4.9-docs.md`): Ka0s Default's `list.stripe`, `list.hover` and `list.sel` change, and seven skins' `icon.hot`. No token or member moves. The suite `parity: each host-copy skin token is the live library's Ka0s Default value` stays green, so this addon copies none of the changed values.
- **PerfPanel 14** (`docs/api/Perf/version-16.1.1.14-docs.md`): header marks with settings, built with no `decorate`, and no member change.

Host-supplied members: `grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit` finds none.

Tests that load library files by name: none. `tests/run.lua` and the namespace-rebuilding suites read `Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml")`, so the five new payload files load in XML order and owe no loader line.

Pinned minors: no suite here pins an exact minor of a moved file.

`VendorSync.register` with its own `pairs`: no. `tests/test_vendor_sync.lua` passes no custom pairs.

**Blockers: none.**

## 3h Unrecorded vendored tags
The spec's walk from the store's first bundle (horizon 2026-09-12) covers the payload commits and the `CLAUDE.md` line rolls, checked against the store's bundle tags. The output is empty, so no span bundle is written.

## 3i The icon declaration, and the sound declaration
- `grep -n 'LibKa0s icons:' CLAUDE.md` gives `37:LibKa0s icons: chevron-down, chevron-up, clear, close, confirm, copy, eye, help, info, move, reset, settings, volume-high.` It is the next non-blank line under the provenance line, and the provenance line is one sentence. Kit 57's `LIBRARY_MARKS` gains `settings`, which is already declared, so the line is kept as written.
- Sounds: this addon has no `LibKa0s sounds:` line, which means none, so the prune removes `media/sounds/` whole.
- Hand-written icon lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`). The owner's in-client smoke remains the backstop for a name the host forgot to declare.

## 3j Tests that assume the whole icon folder
`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'`:
```
tests/test_optionssetup.lua:483-484  opens libs/LibKa0s/media/icons/info.tga (declared)
tests/test_vendor_sync.lua:10        comment
```
Neither assumes an undeclared icon, so there is no blocker.
