# 01 — Delta: LibKa0s v1.31.0 → v1.32.0

Run: 2026-09-12, `/wow-addon:revendor-libka0s`, non-interactive (the bulk-logging rollout of the
2026-09-12 triage; the adoption answers came from the orchestrating session, see `03_DECISIONS.md`).
Target: this repo, branch `fix/2026-09-12-triage` @ `8944966`.

Source: the sibling checkout `../LibKa0s`, **tag `v1.32.0` (`e18dd12`)**, extracted with
`git -C ../LibKa0s archive v1.32.0 LibKa0s testkit | tar -x -C <scratch>/`, never the working tree.
The previous tag is `v1.31.0` (`e7e1962`, the re-cut).

## 3a. Claimed version

```sh
grep -n '[Bb]undles' CLAUDE.md
# 35:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.31.0 (MIT).
```

## 3b. Actual version (the minors in `libs/LibKa0s/`)

Core 7, DebugLog 12, Env 1, Item 1, Media 3, Options 15, OptionsScroll 3, OptionsWidgets 15,
OptionsCompose 4, Perf 11, PerfPanel 5, Pool 3, Slash 7, Widgets 9. That is v1.31.0's version block
(the re-cut), so the line and the bytes agree.

## 3c. Per-file minor delta

| File | v1.31.0 | v1.32.0 |
|---|---|---|
| Core | 7 | 7 |
| Env | 1 | 1 |
| Pool | 3 | 3 |
| Item | 1 | 1 |
| Media | 3 | 3 |
| Widgets | 9 | 9 |
| DebugLog | 12 | 12 |
| **Slash** | **7** | **8** |
| **Options** | **15** | **16** |
| OptionsWidgets | 15 | 15 |
| OptionsCompose | 4 | 4 |
| OptionsScroll | 3 | 3 |
| Perf | 11 | 11 |
| PerfPanel | 5 | 5 |
| kit revision | 17 | 17 |

No cross-major skew. Both moved files are copied in the same whole-folder copy.

## 3d. Both diffs

```sh
diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s   # Options.lua, Slash.lua differ
diff -rq                     <scratch>/LibKa0s libs/LibKa0s   # the same two files
diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit     # nothing
diff -rq                     <scratch>/testkit tests/_kit     # nothing
```

Content and bytes agree. Nothing is deleted inside either payload. `tests/_kit/run-automated-tests.sh`
keeps mode 100755.

## 3e. Consumption map

Unchanged from v1.31.0: Media, Pool, Env, Perf, Core, DebugLog (`core/*Setup.lua`), Slash
(`settings/Slash.lua`), Options (`settings/OptionsSetup.lua`). Both moved majors are consumed here.

## 3f. Kit revision, and the pairing rule

`Kit.VERSION = 17` on both sides. The kit did not move, so the pairing rule is satisfied trivially.

## What moved (from the v1.32.0 changelog block)

- **`Options.lua` minor 16.** Two optional descriptor fields, `bulkBegin(act, scope)` and
  `bulkEnd(act, scope, count, err, info)`, called around `RestoreDefaults(pageKey)` (act `"reset"`,
  scope `pageKey`) and `RestoreAllDefaults()` (act `"reset"`, scope `"all"`, spanning the row walk,
  `resetProfile` and `afterRestoreAll`). `info` is `{ profileReset = boolean }`, true only when
  `resetProfile` ran and returned. A begun bracket always closes; an error is re-raised unchanged
  after `bulkEnd`. No member is added, removed or renamed.
- **`Slash.lua` minor 8.** The same pair around `CliResetAll` (act `"reset"`, scope `"all"`);
  `info.profileReset` is always false there.

## Gate baseline (before the copy)

`lua tests/run.lua`: 252 passed, 0 failed, 0 skipped, 252 total. `luacheck .`: 0 warnings / 0 errors
in 62 files.
