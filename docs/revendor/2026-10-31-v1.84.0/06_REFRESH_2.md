# 06 - Refresh 2: the re-cut v1.84.0

The tag was moved again on the run branch before its release was pushed:
`git -C ../LibKa0s ls-remote --tags origin v1.84.0` prints nothing. This is a refresh, so line 1 of
`01_DELTA.md` stands, and the provenance line and the `LibKa0s icons:` line do not move.

| | `git -C ../LibKa0s rev-parse v1.84.0^{commit}` |
|---|---|
| Old | `7a8bc0f133ed118d2c79c7c5288b97964e24fae5` (vendored in `0b6f538`) |
| New | `b5229b876e803768322fb4d8c66be69f01c8e4a1` |

## Why it moved

The owner's ruling of 2026-11-01: `lib.__PatchLSM30Border` goes altogether, with no stub
(LibKa0s `8b2293e`, `CHANGELOG.md` under v1.84.0).

## Per-file minors, old -> new

| File | Old | New |
|---|---|---|
| `Options.lua` | 36 | 37 |
| `OptionsDrawer.lua` | 3 | 4 |
| `OptionsMedia.lua` | 2 | 3 |

Every other shipped file keeps its minor. `OptionsDrawer.lua` and `OptionsMedia.lua` change one
comment each. Kit revision 47 on both sides, and `tests/_kit/` is unchanged. Before the copy,
`diff -rq --strip-trailing-cr` named these three files and nothing else under `libs/LibKa0s/`
apart from the pruned icons.

## Contract delta

The member is gone, and nothing here needed changing for that. `git grep -iE 'PatchLSM|LSM30'`
over `*.lua` outside `libs/` and `tests/_kit/` finds nothing: the call in
`settings/OptionsSetup.lua` and any test of it left in the earlier M3 commits. The only other
mention is in the frozen `docs/audits/2026-09-11/01_CURRENT_STATE.md`, which stays. No stub or
guard was added, and no test or doc pins any of the three minors.

## Copy and prune

Both payloads copied whole from the tag, and the content and byte diffs were empty before the
prune. `prune-icons.lua` with the declaration `clear, close, copy, eye, help, info, settings` kept
8 files and removed 5832. No credit change and no dead stub mirror.

## Gate

`ka0s-bounded luacheck .`: 0 warnings, 0 errors in 201 files.
`ka0s-bounded lua tests/run.lua`: 2253 passed, 0 failed, 1 skipped, 2254 total.
