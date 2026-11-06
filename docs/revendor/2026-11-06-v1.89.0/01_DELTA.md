Delta: LibKa0s v1.85.0 -> v1.89.0

Part of Ka0sAddonsCommonTasks `docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/` (item V89-AM). Library tag
v1.89.0 (`0bd4839`, pushed), extracted with `git -C ../LibKa0s archive v1.89.0 LibKa0s testkit tools`
into a scratch directory, never the working tree. Written before the copy.

## 3a. Base

`grep -n '[Bb]undles' CLAUDE.md` gives `36:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.85.0 (MIT).`

`git log -1 --format=%H -- libs/LibKa0s tests/_kit` is `f5dbcef`, whose `CLAUDE.md` names v1.85.0. The two
agree, so the base is **v1.85.0**. `git -C ../LibKa0s log --oneline v1.85.0..v1.89.0` lists 27 commits;
`git -C ../LibKa0s diff --stat v1.85.0 v1.89.0` gives 83 files changed.

Step 0 pre-flight (the run's `inputs/step0-preflight.txt`):
`AuraMaster  2026-11-01-v1.85.0  base v1.84.0  vendored-before v1.84.0@146d913  ok`. No base correction.

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` reads the v1.85.0
minors on every file (64 constants), matching the line.

## 3c. Per-file minor delta

The 3c loop over the tag's `LibKa0s/LibKa0s.xml`, printing only files whose constant moved:

| File | old | new |
|---|---|---|
| `Toast.lua` | `LibKa0s-Toast-1.0`, 3 | 4 |
| `Widgets.lua` | `LibKa0s-Widgets-1.0`, 22 | 23 |
| `DebugLogDiagnostics.lua` | `DIAG_MINOR = 6` | 7 |
| `IconBrowserSources.lua` | (new) | `LibKa0s-IconBrowser-1.0`, 1 |
| `IconBrowserWindow.lua` | (new) | `WINDOW_MINOR = 1` |
| `IconBrowser.lua` | (new) | `BROWSER_MINOR = 1` |

No file is behind the tag after the copy; no cross-major skew.

## 3d. Diffs before the copy

`diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s` (icon-folder `Only in <scratch>` lines
omitted, being the undeclared icons): `DebugLogDiagnostics.lua`, `LibKa0s.xml`, `Toast.lua`, `Widgets.lua`
differ; `IconBrowser.lua`, `IconBrowserSources.lua`, `IconBrowserWindow.lua` only in the tag.
`diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit`: `README.md`, `framework.lua`, `mock_ace.lua`
differ. No `Only in libs/LibKa0s` and no `Only in tests/_kit` line, so nothing upstream removed survives here.

## 3e. Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' --include='*.lua' --exclude-dir=libs --exclude-dir=tests .`:
Env (`core/EnvSetup.lua:17`), Media (`core/MediaSetup.lua:20`), Bus (`core/Bus.lua:25`), Launcher
(`core/LauncherSetup.lua:44`), Skin (`core/SkinSetup.lua:95`, `core/Database.lua:444,465`,
`core/Database_Migrations.lua:1187`, `settings/OptionsSetup.lua:91`), Lifecycle (`core/LifecycleSetup.lua:172`),
Compat (`core/Compat.lua:9`, `core/Secrets.lua:38`), Core (`core/CoreSetup.lua:16`), DebugLog
(`core/DebugLogSetup.lua:13`), Pool (`core/PoolSetup.lua:15`), Perf (`core/PerfSetup.lua:14`), Widgets
(`modules/Anchors.lua:464`), Options (`settings/OptionsSetup.lua:110`), Slash (`settings/Slash.lua:26`),
Schema (`settings/Schema.lua:66`).

Not looked up: Toast, IconBrowser (new), Charts, Glow, Item, Sim. Widgets is reached only for
`KW.DRAG_HANDLE` / `KW.DragHandle` (the anchor strip). `grep -rnE 'ContextMenu|Toast|IconBrowser'` outside
`libs/` and `tests/_kit/` finds no use site.

## 3f. Kit revision

`grep -n 'Kit.VERSION'`: tag `testkit/framework.lua:20` is 51, `tests/_kit/framework.lua:20` is 50. Both
payloads move in one commit (the kit-11 pairing rule is satisfied by construction).

## 3g. Contract delta

Majors that moved and are consumed: Widgets (22 -> 23) and DebugLog (Diagnostics 6 -> 7).

- Widgets: `diff` of `docs/api/Widgets/version-22.5.12.6.7.5-docs.md` (v1.85.0) and
  `version-23.5.12.6.7.5-docs.md` (v1.89.0). The only change is the additive `W.ContextMenu` cascade
  (`submenu`, `radio`, `selected`, `opts.check`) and `CloseMenu` closing every level; "What a consumer owes:
  nothing for a flat menu". `WidgetsDragHandle.lua` stays at 12, so the strip AuraMaster draws is unchanged.
- DebugLog: `docs/api/DebugLog/version-22.6.1.4-docs.md` vs `version-22.7.1.4-docs.md`: "No member change";
  the report's `LibKa0s running:` line also names IconBrowser. "A host suite that pins
  `DebugLogDiagnostics 6` re-pins it at 7": `grep -rnE 'DebugLogDiagnostics|DIAG_MINOR' tests` finds only a
  comment (`tests/test_diagnostics.lua:93`, citing minor 2), no pin.
- `grep -rn '__Attach[A-Za-z]*' --exclude-dir=libs --exclude-dir=_kit .` finds no site.
- Toast 3 -> 4 owes a host Toast stub `SetStack`, `Visible`, `FrameFor`; AuraMaster has no Toast stub and no
  Toast lookup, so nothing is owed.

### Blockers

None.

## 3h. Unrecorded vendored tags

The 3h listing (horizon 2026-09-12) prints nothing: every vendored tag through v1.85.0 has a bundle. No
span bundle.

## 3i. Icon declaration

`grep -n 'LibKa0s icons:' CLAUDE.md` gives `37:LibKa0s icons: chevron-down, chevron-up, clear, close,
confirm, copy, eye, help, info, move, reset, settings, volume-high.`, the next non-blank line under the
provenance line, which ends its own line. Kept as decided (the run plan names no change for this addon; no
new surface in this range draws a catalog name AuraMaster wires). Hand lists have drifted before (KickCD
`tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`); the owner's in-client smoke is
the backstop.

## 3j. Tests assuming the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'`:
`tests/test_optionssetup.lua:483-484` opens `info.tga`, which is declared; `tests/test_vendor_sync.lua:10`
is a comment. No blocker.

## Dead stub mirrors

`grep -rn '__releaseChrome' --include='*.lua' --exclude-dir=libs --exclude-dir=_kit .` finds nothing. No `__`
member was removed in this range.
