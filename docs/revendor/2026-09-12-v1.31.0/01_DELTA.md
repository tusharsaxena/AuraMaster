# 01 — Delta: LibKa0s v1.30.0 → v1.31.0

Run: 2026-09-12, `/wow-addon:revendor-libka0s`, non-interactive (wave B2 of the 2026-09-12 triage;
the adoption answers came from the orchestrating session, see `03_DECISIONS.md`). Target: this repo,
branch `fix/2026-09-12-triage` @ `facd283`.

Source: the sibling checkout `../LibKa0s`, **tag `v1.31.0` (`30db4ed`)**, extracted with
`git -C ../LibKa0s archive v1.31.0 LibKa0s testkit | tar -x -C <scratch>/`, never the working tree.
The previous tag is `v1.30.0`.

## 3a. Claimed version

```sh
grep -n '[Bb]undles' CLAUDE.md
# 35:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.30.0 (MIT).
```

## 3b. Actual version (the minors in `libs/LibKa0s/`)

```sh
grep -hoE 'local (MAJOR, )?(MINOR|WIDGETS_MINOR|SCROLL_MINOR|PANEL_MINOR) *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua
grep -nE '^local [A-Z_]*MINOR' libs/LibKa0s/OptionsCompose.lua
```

Core 7, DebugLog 12, Env 1, Item 1, Media 3, Options 15, OptionsScroll 3, OptionsWidgets 14,
OptionsCompose 3 (`COMPOSE_MINOR`, which the spec's pattern does not match), Perf 10, PerfPanel 5,
Pool 3, Slash 7, Widgets 9. That is v1.30.0's version block, so the line and the bytes agree.

## 3c. Per-file minor delta

File list read from the tag's `LibKa0s/LibKa0s.xml` (14 files); minors from the same two greps run
against `<scratch>/LibKa0s/`, cross-checked against the v1.31.0 `CHANGELOG.md` version block.

| File | v1.30.0 | v1.31.0 |
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
| **OptionsWidgets** | **14** | **15** |
| **OptionsCompose** | **3** | **4** |
| OptionsScroll | 3 | 3 |
| Perf | 10 | 10 |
| PerfPanel | 5 | 5 |
| **kit revision** | **16** | **17** |

No cross-major skew: before the copy the consumer is behind only on the two files this release
moved, and the whole-folder copy brings both.

## 3d. Both diffs

```sh
diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s   # OptionsCompose.lua, OptionsWidgets.lua differ
diff -rq                     <scratch>/LibKa0s libs/LibKa0s   # the same two files
diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit     # README.md, framework.lua, mock_base.lua differ
diff -rq                     <scratch>/testkit tests/_kit     # the same three files
```

Content and bytes agree, so this is a real content move, not a line-ending disagreement. No
`Only in libs/LibKa0s` or `Only in tests/_kit` lines, so nothing is deleted inside either payload.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '^\./libs/' | grep -v '^\./tests/'
```

| Major | Lookup site |
|---|---|
| Media | `core/MediaSetup.lua:18` |
| Pool | `core/PoolSetup.lua:15` |
| Env | `core/EnvSetup.lua:17` |
| Perf | `core/PerfSetup.lua:14` |
| Core | `core/CoreSetup.lua:16` |
| DebugLog | `core/DebugLogSetup.lua:13` |
| Slash | `settings/Slash.lua:26` |
| Options | `settings/OptionsSetup.lua:28` |

Unchanged from v1.30.0. `LibKa0s-Item-1.0` and `LibKa0s-Widgets-1.0` have no lookup here, for the
reason `docs/ARCHITECTURE.md` records (the addon handles no items; Widgets is reached through the
library's own files). Neither file moved in v1.31.0, so that premise is unchanged.

## 3f. Kit revision, and the pairing rule

```sh
grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua
# <scratch>/testkit/framework.lua:20:Kit.VERSION = 17
# tests/_kit/framework.lua:20:Kit.VERSION = 16
```

A consumer on LibKa0s v1.9.0 or newer takes kit revision 11 or newer in the same commit. Both
payloads are copied whole in one commit, so this is satisfied by construction.

## What moved (from the v1.31.0 changelog block)

- **`OptionsCompose.lua` minor 4.** Every composer takes `spec.bind = { set, get | record }`, a
  record-backed arm: a bound row carries `field` and `get` / `set` closures and no `path`.
  Path-keyed callers are byte-for-byte unaffected, pinned upstream by
  `tests/fixture_compose_golden.lua`.
- **`OptionsWidgets.lua` minor 15.** A row whose `path` is nil reads through `row.get()` and writes
  through `row.set(value)` in every maker and refresher. The gate is `path == nil`, so path-keyed rows
  are untouched.
- **Kit revision 17 (`mock_base.lua`).** The Ace surfaces six consumer harnesses migrate onto:
  `NewAddon` honors its mixin list and names and registers the object; `NewModule` and the lifecycle
  driven from `ADDON_LOADED` / `PLAYER_LOGIN` on `AceAddon.frame`; AceEvent as two CallbackHandler
  registries with `M.__msgRegistry`, `M.__fireEvent` and `M.__badEvents`; a real AceTimer on the
  kit's queue with `M.__fireTimers()` honoring cancellation and answering its count; AceConsole's
  `commands` and `__slash`; AceGUI's `WidgetVersions`, `RegisterLayout` and `GetLayout`. It is not
  the geometry flip (that is revision 18 at the earliest).

## Gate baseline (before the copy)

`lua tests/run.lua`: 251 passed, 0 failed, 0 skipped, 251 total. `luacheck .`: 0 warnings / 0 errors
in 62 files.
