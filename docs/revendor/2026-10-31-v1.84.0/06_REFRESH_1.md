# 06 - Refresh 1: the re-cut v1.84.0

The tag was moved on the run branch before its release was pushed:
`git -C ../LibKa0s ls-remote --tags origin v1.84.0` prints nothing. This is a refresh, so line 1 of
`01_DELTA.md` stands, and the provenance line and the `LibKa0s icons:` line do not move.

| | `git -C ../LibKa0s rev-parse v1.84.0^{commit}` |
|---|---|
| Old | `e917ccd` (vendored in `14c4d1e`) |
| New | `7a8bc0f133ed118d2c79c7c5288b97964e24fae5` |

## Why it moved

The owner's ruling of 2026-11-01: `Ka0sMedia_*` is the only media picker, because it is the one the
skin can paint. A row that names `LSM30_*` draws the picker whether or not
AceGUI-3.0-SharedMediaWidgets is loaded, and the composers write `Ka0sMedia_*`
(LibKa0s `4240039`, `CHANGELOG.md` under v1.84.0).

## Per-file minors, old -> new

| File | Old | New |
|---|---|---|
| `Options.lua` | 35 | 36 |
| `OptionsWidgets.lua` | 40 | 41 |
| `OptionsCompose.lua` | 15 | 16 |
| `OptionsScroll.lua` | 9 | 10 |
| `OptionsMedia.lua` | 1 | 2 |
| `SkinAce.lua` | 5 | 6 |

Every other shipped file keeps its minor. Kit revision 47 on both sides, and `tests/_kit/` is
unchanged. Before the copy, `diff -rq --strip-trailing-cr` named these six files and nothing else
under `libs/LibKa0s/` apart from the pruned icons.

## Contract delta

The library's "a consumer owes" list has two items that reach this addon:

- A test pinning `LSM30_*` on a composed row. `tests/test_schema_paths.lua` allowed only that prefix
  beside the addon's own dropdown, and went red on the copy. It moves in the re-vendor commit.
- `lib.__PatchLSM30Border` is now a no-op that answers false. `settings/OptionsSetup.lua` still
  calls it, which is harmless. The next commit removes the call.

No page here calls `AceGUI:Create("LSM30_*")`, and no authored code reaches
AceGUI-SharedMedia's globals.

## Copy and prune

Both payloads copied whole from the tag, and the content diffs were empty before the prune.
`prune-icons.lua` with the declaration `clear, close, copy, eye, help, info, settings` kept 8 files
and removed 5832. No credit change and no dead stub mirror.

## Gate

`ka0s-bounded luacheck .`: 0 warnings, 0 errors in 201 files.
`ka0s-bounded lua tests/run.lua`: 2253 passed, 0 failed, 1 skipped, 2254 total.
