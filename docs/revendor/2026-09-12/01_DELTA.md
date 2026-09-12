# 01 — Delta: LibKa0s v1.29.0 → v1.30.0

Run: 2026-09-12, `/wow-addon:revendor-libka0s`, non-interactive (the adoption answers came from the
orchestrating session; see `03_DECISIONS.md`). Target: this repo, branch
`chore/libka0s-1.30.0-arch5` off `master` @ `9fe3f0a`.

Source: the sibling checkout `../LibKa0s`, **tag `v1.30.0` (`e369e0f`)**, extracted with
`git -C ../LibKa0s archive v1.30.0 LibKa0s testkit | tar -x -C <scratch>/`, never the working tree.
The previous tag is `v1.29.0` (`8054bd4`).

## 3a. Claimed version

```sh
grep -n '[Bb]undles' CLAUDE.md
# 35:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.29.0 (MIT).
```

## 3b. Actual version (the minors in `libs/LibKa0s/`)

```sh
grep -hoE 'local (MAJOR, )?(MINOR|WIDGETS_MINOR|SCROLL_MINOR|PANEL_MINOR) *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua
```

Core 7, DebugLog 12, Env 1, Item 1, Media 3, Options 15, OptionsScroll 3, OptionsWidgets 14, Perf 10,
PerfPanel 5, Pool 3, Slash 7, Widgets 9. They match v1.29.0's version block, so the line and the
bytes agree. (`OptionsCompose.lua` carries no minor constant matched by this pattern; the changelog
gives it as minor 3.)

## 3c. Per-file minor delta

Read from the v1.30.0 `CHANGELOG.md` version block (`git -C ../LibKa0s show v1.30.0:CHANGELOG.md`):
*"No file in `LibKa0s/` moved, so every minor above is the one v1.29.0 shipped."*

| File | v1.29.0 | v1.30.0 |
|---|---|---|
| Core | 7 | 7 |
| Env | 1 | 1 |
| Pool | 3 | 3 |
| Item | 1 | 1 |
| Media | 3 | 3 |
| Widgets | 9 | 9 |
| DebugLog | 12 | 12 |
| Slash | 7 | 7 |
| Options | 15 | 15 |
| OptionsWidgets | 14 | 14 |
| OptionsCompose | 3 | 3 |
| OptionsScroll | 3 | 3 |
| Perf | 10 | 10 |
| PerfPanel | 5 | 5 |
| **kit revision** | **15** | **16** |

No cross-major skew: the consumer is on every file's current minor.

## 3d. Both diffs

```sh
diff -r  --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s   # empty
diff -rq                     <scratch>/LibKa0s libs/LibKa0s   # empty (bytes identical)
diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit     # README.md, framework.lua, mock_base.lua, vendor_sync.lua differ
diff -rq                     <scratch>/testkit tests/_kit     # the same four files
```

The ship payload has not moved. The kit's content moved in four files: kit revision 16. No
`Only in tests/_kit` or `Only in libs/LibKa0s` lines, so nothing is deleted inside either payload.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
```

| Major | Lookup site |
|---|---|
| Media | `core/MediaSetup.lua:18` |
| Env | `core/EnvSetup.lua:17` |
| Pool | `core/PoolSetup.lua:15` |
| DebugLog | `core/DebugLogSetup.lua:13` |
| Core | `core/CoreSetup.lua:16` |
| Perf | `core/PerfSetup.lua:14` |
| Options | `settings/OptionsSetup.lua:28` |
| Slash | `settings/Slash.lua:26` |

`LibKa0s-Item-1.0` and `LibKa0s-Widgets-1.0` have no lookup here. That is already recorded in
`docs/ARCHITECTURE.md` (the addon handles no items; Widgets is reached through the library's own
files). Nothing in v1.30.0 changes that premise, since no file in `LibKa0s/` moved.

## 3f. Kit revision, and the pairing rule

```sh
grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua
# <scratch>/testkit/framework.lua:20:Kit.VERSION = 16
# tests/_kit/framework.lua:20:Kit.VERSION = 15
```

A consumer on LibKa0s v1.9.0 or newer takes kit revision 11 or newer in the same commit. Both
payloads are copied whole in one commit, so this is satisfied by construction.

## What kit revision 16 carries (from the v1.30.0 changelog)

- **#27** `AceGUI:Release(w)` and `w:Release()`: raises on `Release(nil)` and on a double release
  ("Attempt to Release Widget that is already released"). It fires `OnRelease`, wipes `userdata`,
  callbacks and size fields, hides the frame, and records `w.__released = true` and
  `AceGUI.__released`.
- **#28** `VendorSync.register` adds a case named
  `the automated-test runner is recorded executable (100755)`. Every consumer's total moves by +1.
- **#29** The AceEvent Embed target gets recorded `RegisterEvent`, `UnregisterEvent` and
  `UnregisterAllEvents` over `obj.__events`. These are the same functions as the `NewAddon`
  target's, validated as real Ace3 validates them, in a per-build registry.
- **#30** `NewAddon` stamps an AceConsole-shaped `Printf` beside `Print`.

## Gate baseline (before the copy)

`lua tests/run.lua`: 251 passed, 0 failed, 0 skipped, 251 total. `luacheck .`: 0 warnings / 0 errors
in 62 files.
