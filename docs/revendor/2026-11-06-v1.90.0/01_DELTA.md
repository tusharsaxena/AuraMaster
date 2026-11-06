Delta: LibKa0s v1.89.0 -> v1.90.0

Part of Ka0sAddonsCommonTasks `docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/` (item SF1-RV-AM, from
`SF1_SMOKE_FEEDBACK.md`). Library tag v1.90.0 (`4485b8f`), a **local** tag not yet pushed, so
`git -C ../LibKa0s ls-remote --tags origin v1.90.0` prints nothing; this is a new tag, not a refresh.
Extracted with `git -C ../LibKa0s archive v1.90.0 LibKa0s testkit tools` into a scratch directory, never
the working tree. Written before the copy.

## 3a. Base

`grep -n '[Bb]undles' CLAUDE.md` gives `36:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.89.0 (MIT).`

`git log -1 --format=%H -- libs/LibKa0s tests/_kit` is `805f09e`, whose `CLAUDE.md` names v1.89.0. The two
agree, and `diff -rq --strip-trailing-cr` of the v1.89.0 extract against `libs/LibKa0s` (undeclared icons
aside) and `tests/_kit` is empty, so the base is **v1.89.0**. `git -C ../LibKa0s log --oneline v1.89.0..v1.90.0`
lists 4 commits (`7d42f4e` SF1-L1, `b9f7651` SF1-L2, `4ac9f3c` and `4485b8f` SF1-L3);
`git -C ../LibKa0s diff --stat v1.89.0 v1.90.0` gives 37 files changed.

Step 0 pre-flight for this addon: `AuraMaster  2026-11-06-v1.89.0  base v1.85.0  vendored-before v1.85.0@805f09e  ok`.
No base correction.

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` reads the v1.89.0
minors on every file (67 constants), matching the line.

## 3c. Per-file minor delta

The 3c loop over the tag's `LibKa0s/LibKa0s.xml`, printing only files whose constant moved:

| File | old | new |
|---|---|---|
| `Core.lua` | `LibKa0s-Core-1.0`, 15 | 16 |
| `Skin.lua` | `LibKa0s-Skin-1.0`, 16 | 17 |
| `SkinPaint.lua` | `PAINT_MINOR = 18` | 19 |
| `SkinPaintExtras.lua` | `EXTRAS_MINOR = 17` | 18 |
| `Widgets.lua` | `LibKa0s-Widgets-1.0`, 23 | 24 |
| `WidgetsAutocomplete.lua` | `AUTOCOMPLETE_MINOR = 7` | 8 |
| `OptionsAppearance.lua` | `APPEARANCE_MINOR = 6` | 7 |

No new file and no file removed. No cross-major skew after the copy.

## 3d. Diffs before the copy

`diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s` (icon-folder `Only in <scratch>` lines
omitted, being the undeclared icons): the seven files above differ. `diff -rq --strip-trailing-cr
<scratch>/testkit tests/_kit` is empty (kit unchanged). No `Only in libs/LibKa0s` and no `Only in tests/_kit`.

## 3e. Consumption map

Unchanged from the v1.89.0 bundle: `grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)'` outside `libs/`
and `tests/` finds Env, Media, Bus, Launcher, Skin, Lifecycle, Compat, Core, DebugLog, Pool, Perf, Widgets
(`modules/Anchors.lua:464`, the drag handle only), Options, Slash, Schema.

## 3f. Kit revision

`grep -n 'Kit.VERSION'`: tag `testkit/framework.lua:20` is 51, `tests/_kit/framework.lua:20` is 51. Both
payloads still move in one commit (the kit-11 pairing rule holds by construction).

## 3g. Contract delta

Moved and consumed: Core (15 -> 16), Skin (16 -> 17, SkinPaint 19, SkinPaintExtras 18), Widgets (23 -> 24,
Autocomplete 8), Options (OptionsAppearance 6 -> 7). Documents diffed between the tags:

- Core `docs/api/Core/version-15-docs.md` -> `version-16-docs.md`: "No public member is added, removed or
  renamed"; four `__` pixel-edge internals, "A host calls none of them".
- Widgets `version-23.5.12.6.7.5-docs.md` -> `version-24.5.12.6.8.5-docs.md`: "What a host owes: nothing. A
  host's own `edgeSize = 1` backdrops are its own". AuraMaster draws no `W.Dropdown`, `W.SearchBox`,
  menu or autocomplete; `WidgetsDragHandle.lua` stays at 12, so the anchor strip is unchanged.
- Skin `version-16.1.27.8.18.17.17.4.9-docs.md` -> `version-17.1.27.8.19.18.17.4.9-docs.md`: `RegisterOwner`'s
  optional `opts.keepScope`; "a host's Skin facade owes nothing".
- Options `version-37.4.44.2.7.2.9.15.2.4.19.13.5.5.7.6.11.1.1.4-docs.md` -> `...7.7.11.1.1.4-docs.md`: "a host
  whose Scope is a documented deviation registers with `keepScope = true`; every other host owes nothing".
  AuraMaster's Scope defaults are the standard's (`defaults/Profile.lua:55`, `ignorePanel = true,
  ignoreFonts = false`), not a deviation, so it owes nothing (`core/SkinSetup.lua:601` unchanged).
- `grep -rn '__Attach[A-Za-z]*' --exclude-dir=libs --exclude-dir=_kit .` finds no site.
- Edge-size and minor pins: `grep -rnE 'MINOR|edgeSize|__PixelSize|keepScope|__copySkinTo'` outside `libs/`
  and `_kit/` finds only AuraMaster's own aura borders (`modules/Style_Border.lua:158`,
  `tests/test_style_borders.lua:114,131,145`, `tests/region_recorder.lua:53`, `tests/wow_mock.lua:174`),
  which no library file draws. No test pins an old minor.

### Blockers

None.

## 3h. Unrecorded vendored tags

The 3h listing (horizon 2026-09-12) prints nothing: every vendored tag through v1.89.0 has a bundle. No
span bundle.

## 3i. Icon declaration

`grep -n 'LibKa0s icons:' CLAUDE.md` gives `37:LibKa0s icons: chevron-down, chevron-up, clear, close,
confirm, copy, eye, help, info, move, reset, settings, volume-high.`, the next non-blank line under the
provenance line, which ends its own line. Kept as decided (SF1 names no icon change; no surface in this range
draws a catalog name). Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup
`tests/test_mediasetup.lua:19`); the owner's in-client smoke is the backstop.

## 3j. Tests assuming the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'`:
`tests/test_optionssetup.lua:483-484` opens `info.tga`, which is declared; `tests/test_vendor_sync.lua:10`
is a comment. No blocker.

## Dead stub mirrors

`grep -rn '__releaseChrome' --include='*.lua' --exclude-dir=libs --exclude-dir=_kit .` finds nothing. No `__`
member was removed in this range.
