Delta: LibKa0s v1.83.0 -> v1.84.0

# 01 - Delta (AuraMaster)

Run: 2026-10-31, the M2 adoption of the findings remediation (Ka0sAddonsCommonTasks
`docs/2026-10-31-FINDINGS_REMEDIATION/M2_LIBRARY_RELEASE.md`), executed non-interactively: no adoption
interview, and no GitHub issue is filed. Branch `feat/2026-10-31-findings-remediation`.

Source: the sibling checkout `../LibKa0s`, local tag `v1.84.0` (commit `e917ccd`), not on `origin`
(`git -C ../LibKa0s ls-remote --tags origin v1.84.0` prints nothing). Extracted with
`git -C ../LibKa0s archive v1.84.0 LibKa0s testkit tools | tar -x -C <scratch>`.

## 3a - Claimed version, before this run

`grep -n '[Bb]undles' CLAUDE.md` gives `CLAUDE.md:36: Bundles [LibKa0s](...) v1.83.0 (MIT).` The last
payload commit, `472da8f`, names v1.83.0 too. `diff -rq <v1.83.0>/LibKa0s libs/LibKa0s` printed only
undeclared icons and `diff -rq <v1.83.0>/testkit tests/_kit` printed nothing.

**Base: v1.83.0.** Step 0 for this addon: the newest single-tag bundle, `2026-10-24-v1.77.0`, states
base v1.76.0, which the v1.77.0 bundle's own 3a confirms. No mismatch, no correction.

`git -C ../LibKa0s log --oneline v1.83.0..v1.84.0 | wc -l` gives 26 commits.

## 3b - Actual version, before this run

The minors agree with v1.83.0 and `Kit.VERSION` was 46.

## 3c - Per-file minor delta

The tag's `LibKa0s/LibKa0s.xml` file list, run through the skill's loop. Files not listed did not
move. An empty old column is a file new in this range. No file is behind: there is no cross-major skew.

```
Schema.lua  old: local MAJOR, MINOR = "LibKa0s-Schema-1.0", 2  new: local MAJOR, MINOR = "LibKa0s-Schema-1.0", 3
Charts.lua  old:   new: local MAJOR, MINOR = "LibKa0s-Charts-1.0", 1
ChartsRender.lua  old:   new: local RENDER_MINOR = 1
Skin.lua  old: local MAJOR, MINOR = "LibKa0s-Skin-1.0", 10  new: local MAJOR, MINOR = "LibKa0s-Skin-1.0", 11
SkinOwnerTokens.lua  old:   new: local TOKENS_MINOR = 1
SkinDefs.lua  old: local DEFS_MINOR = 18  new: local DEFS_MINOR = 19
SkinDefsOthers.lua  old:   new: local OTHERS_MINOR = 1
WidgetsDragHandle.lua  old: local DRAG_MINOR = 8  new: local DRAG_MINOR = 10
DebugLogDiagnostics.lua  old: local DIAG_MINOR = 5  new: local DIAG_MINOR = 6
Slash.lua  old: local MAJOR, MINOR = "LibKa0s-Slash-1.0", 20  new: local MAJOR, MINOR = "LibKa0s-Slash-1.0", 21
Options.lua  old: local MAJOR, MINOR = "LibKa0s-Options-1.0", 34  new: local MAJOR, MINOR = "LibKa0s-Options-1.0", 35
OptionsWidgets.lua  old: local WIDGETS_MINOR = 38  new: local WIDGETS_MINOR = 40
OptionsFlow.lua  old:   new: local FLOW_MINOR = 2
OptionsIds.lua  old: local IDS_MINOR = 5  new: local IDS_MINOR = 6
OptionsIdSuggest.lua  old:   new: local SUGGEST_MINOR = 1
OptionsTabs.lua  old: local TABS_MINOR = 11  new: local TABS_MINOR = 13
OptionsTabbed.lua  old:   new: local TABBED_MINOR = 2
OptionsCompose.lua  old: local COMPOSE_MINOR = 14  new: local COMPOSE_MINOR = 15
OptionsSkinPicker.lua  old: local PICKER_MINOR = 4  new: local PICKER_MINOR = 5
OptionsSkinPickerRows.lua  old:   new: local ROWS_MINOR = 1
SimPanel.lua  old: local SIM_PANEL_MINOR = 8  new: local SIM_PANEL_MINOR = 9
SimPanelRender.lua  old:   new: local RENDER_MINOR = 1
```

## 3d - Diffs

Before the copy the two sides differ only by the tag's own changes; nothing had forked. Results after
the copy are in `05_SUMMARY.md`.

## 3e - Consumption map

Fifteen modules by lookup, unchanged: Env, Media, Bus, DebugLog, Compat, Launcher, Skin, Core,
Lifecycle, Pool, Perf, Options, Schema, Slash, Widgets. The new `LibKa0s-Charts-1.0` has no lookup here.

## 3f - Kit revision

`Kit.VERSION` 46 -> 47 (`mock_ace.lua` peeled out of `mock_base.lua`). Both payloads move together,
as the pairing rule requires.

## 3g - Contract delta

Majors moved and consumed: Options, Schema, Slash, Skin, Widgets, DebugLog.

- No `__Attach*` call outside `libs/`: the addon hands no attach seam a member.
- Options: `opts.beforeGroup`, `opts.afterSubgroup`, the `note` row, `O.PositionBlock` and
  `O.PageBanner{ acts }` are additive. `O.ClearScroll` keeps the band's refresher, which this addon's
  `Helpers.ClearScroll` call gains for free.
- **Degradation stub:** `O.PositionBlock` is a new public member, so the stub list in
  `settings/OptionsSetup.lua` owes it (`tests/test_surface_parity.lua`). Fixed in this commit.
- Schema minor 3, Slash minor 21: `note` rows only. This addon declares none.
- WidgetsDragHandle minors 9 and 10: a fitted strip measures at its effective scale and repeats the
  host's last fit on show. A strip with `onRefit` is skipped by the show re-fit, and
  `Anchors.BuildHandle` passes one, so this addon's capped strip takes no extra `ApplyWidth`.

**Blockers:** none beyond the stub entry above.

## 3h - Unrecorded tags

The audit's listing prints nothing unrecorded once the store's first bundle, `2026-09-12` (a folder
with no tag, line 1 read for v1.30.0), is counted. No span bundle is owed.

## 3i - The icon declaration

Kept: `LibKa0s icons: clear, close, copy, eye, help, info, settings.` The line sits directly under the
provenance line. Nothing in this range adds a library-drawn name. Owner's smoke stays the backstop: a
pruned icon resolves to a path and draws blank, which the gate cannot see.

## 3j - Tests that assume the whole icon folder

`tests/test_optionssetup.lua:483` opens `info.tga`, which is declared. No catalog loop. No blocker.
