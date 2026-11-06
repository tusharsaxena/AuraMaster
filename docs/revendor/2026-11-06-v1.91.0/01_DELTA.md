Delta: LibKa0s v1.90.0 -> v1.91.0

Part of Ka0sAddonsCommonTasks `docs/2026-11-06-FOLLOWUPS_V1_91/` (item FU-RV-AM). Library tag v1.91.0
(`55bfbb4`), a **local** tag not yet pushed, so `git -C ../LibKa0s ls-remote --tags origin v1.91.0` prints
nothing; the addon's provenance named v1.90.0, so this is a new tag, not a refresh. Extracted with
`git -C ../LibKa0s archive v1.91.0 LibKa0s testkit tools` into a scratch directory, never the working tree.

## Step 0

Skipped, stated: the installed skill's roster regex (`\]\(\.\./\.\./[A-Za-z]+/\)`) matches nothing in
`ADDONS.md`'s current backticked format, and its `tag_at` helper arrives with its positionals substituted.
Both are fixed upstream in this run (dev-copilot item FU-DC1). Checked by hand for this addon instead: the
newest single-tag bundle, `2026-11-06-v1.90.0`, states base v1.89.0, and `git show 5b23188^:CLAUDE.md`
(the parent of that bundle's re-vendor commit) names v1.89.0. `ok`, so no base correction.

## 3a. Base

`grep -n '[Bb]undles' CLAUDE.md` gives `36:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.90.0 (MIT).`

`git log -1 --format=%H -- libs/LibKa0s tests/_kit` is `c6b25c9` (SF2-RV-AM, the v1.90.0 refresh), whose
`CLAUDE.md` names v1.90.0, and `git log c6b25c9..HEAD -- CLAUDE.md` lists nothing. The two agree, so the base
is **v1.90.0**. `git -C ../LibKa0s log --oneline v1.90.0..v1.91.0` lists 7 commits (`55d3b0f` FU-L1;
`d72dc4a`, `c1ed261`, `acc9640`, `3f7be30` FU-L2; `1938837`, `55bfbb4` FU-L3).
`git -C ../LibKa0s diff --stat v1.90.0 v1.91.0 -- LibKa0s testkit` gives 9 files changed, 1414 insertions,
1203 deletions, all under `LibKa0s/`; the kit is untouched.

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` read the v1.90.0
minors on every file before the copy (Core 16, Widgets 25, WidgetsLineChart 6, SkinPaintExtras 18),
matching the line.

## 3c. Per-file minor delta

The 3c loop over the tag's `LibKa0s/LibKa0s.xml`, printing only files whose constant moved or is new:

| File | old | new |
|---|---|---|
| `Core.lua` | `LibKa0s-Core-1.0`, 16 | 17 |
| `CorePixel.lua` | (new) | `PIXEL_MINOR = 1` |
| `SkinPaintExtras.lua` | `EXTRAS_MINOR = 18` | 19 |
| `SkinPaintHud.lua` | (new) | `HUD_MINOR = 1` |
| `SkinAceConfirm.lua` | (new) | `CONFIRM_MINOR = 1` |
| `Widgets.lua` | `LibKa0s-Widgets-1.0`, 25 | 26 |
| `WidgetsDropdown.lua` | (new) | `DROPDOWN_MINOR = 1` |
| `WidgetsLineChart.lua` | `CHART_MINOR = 6` | 7 |

Every other file is at its v1.90.0 minor. No cross-major skew. No `NEEDS_*` floor rises (CHANGELOG v1.91.0).

## 3d. Diffs

Before the copy, `diff -rq --strip-trailing-cr <extract>/LibKa0s libs/LibKa0s` listed the five changed files,
the four new ones and the undeclared icons (`Only in <extract>/LibKa0s/media/icons`); `tests/_kit` was clean.
After `cp -r` of both payloads whole, `diff -r --strip-trailing-cr` and `diff -r` (bytes) of both payloads
were both empty. Nothing removed upstream, so nothing deleted in `libs/` apart from the prune.

## 3e. Consumption map

Unchanged from v1.90.0: Bus, Compat, Core, DebugLog, Env, Launcher, Lifecycle, Media, Perf, Pool, Schema,
Skin, Slash are looked up in `core/` and `settings/`. Widgets is looked up only in tests
(`tests/test_anchors_handle.lua`); the drag handle is drawn through the library's own seams. AuraMaster
draws no LineChart and no library dropdown or context menu of its own
(`grep -rnE 'LineChart|W\.Dropdown|ContextMenu|CloseMenu'` outside `libs/`, `tests/_kit/` finds nothing).
It does call `S.BarGloss` (`modules/Style_Bars.lua:239`) and `S.HudFont` (`modules/Style.lua:197`),
whose code moved from `SkinPaintExtras.lua` to the new `SkinPaintHud.lua` unchanged.

## 3f. Kit revision

`grep -n 'Kit.VERSION'` gives 51 in both the extract and `tests/_kit/framework.lua`. The pairing rule
(LibKa0s v1.9.0 or newer needs kit revision 11 or newer in the same commit) holds by construction, since
both payloads are copied whole.

## 3g. Contract delta

Majors whose minor moved: Core, Widgets, Skin. Diffed `docs/api/Core/version-16-docs.md` against
`version-17.1-docs.md`, `docs/api/Widgets/version-25.6.13.6.8.5-docs.md` against
`version-26.1.6.13.7.8.5-docs.md`, and `docs/api/Skin/version-17.1.27.8.19.18.17.4.9-docs.md` against
`version-17.1.27.8.19.19.1.1.17.4.9-docs.md` (v1.90.0 against v1.91.0). The only changed prose under an
existing surface is the LineChart's `series[i].thickness` row (Widgets doc, now "physical pixels ... Since 7")
and the line-order note above it; AuraMaster draws no chart. The three peels are stated as pure moves with
the same member manifests. `grep -rn '__Attach[A-Za-z]*'` outside `libs/`, `tests/_kit/` finds no site.

## Blockers

None.

- **Library file lists:** every suite that loads the library does it through
  `Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml")` (`tests/run.lua:21`, `tests/perf.lua:47`,
  `tests/test_loadorder.lua:206`, `tests/test_optionssetup.lua:395`, `tests/test_slash.lua:461`), so the four
  new files load in the tag's XML order with no edit. No hand-written list exists.
- **Minor pins:** no test pins a Core, Widgets, WidgetsLineChart or SkinPaintExtras minor.
- **Stub mirrors:** the library-absent Skin facade in `core/SkinSetup.lua` mirrors `BarGloss` (no-op) and
  `HudFont`; both members keep their names and signatures and only changed files, so the stub stands. No
  `__releaseChrome` mirror exists.

## 3h. Span

The 3h listing (horizon `2026-09-12`, with `tag_at` rewritten on a named variable) gives 58 vendored tags
and 58 recorded ones; `grep -vxF -f recorded.txt vendored.txt` is empty. No span bundle.

## 3i. Icon declaration

Kept as decided by the run's plan (nothing in this tag changes what AuraMaster draws):
`LibKa0s icons: chevron-down, chevron-up, clear, close, confirm, copy, eye, help, info, move, reset, settings, volume-high.`,
the next line under the provenance line (`CLAUDE.md:37`). Hand lists have drifted before (KickCD
`tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`); the owner's in-client smoke is
the backstop for a name the host forgot to declare.

## 3j. Whole-folder icon tests

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'` finds only
`tests/test_optionssetup.lua:483-484`, which opens `info.tga`, a declared name. Not a blocker.
