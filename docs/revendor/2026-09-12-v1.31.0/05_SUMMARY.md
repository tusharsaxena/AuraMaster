# 05 — Summary

**Tag moved v1.30.0 → v1.31.0 (`30db4ed`).** Two files moved: `OptionsWidgets.lua` (minor 14 → 15)
and `OptionsCompose.lua` (minor 3 → 4). Every other file keeps its minor. The kit moved from revision
16 to 17 (`README.md`, `framework.lua`, `mock_base.lua`). The per-file table is in `01_DELTA.md`.
Nothing was deleted inside either payload.

**Reached the addon for free (class A).** OptionsWidgets 15's bound-row branch is gated on
`path == nil`, and every AuraMaster row has a path, so the panel renders as before. The path-keyed
composer output is byte-identical upstream. Kit 17's named `NewAddon` path now gives the headless
addon object AceEvent's message half, `UnregisterAllMessages`, a cancellable AceTimer and the object
model.

**Adopted:** nothing. No local `tests/wow_mock.lua` layer has a kit 17 counterpart. The Ace shims
were already retired at v1.30.0.

**Declined:** B1, the `spec.bind` record-backed composer arm, as **never**. AuraMaster reaches
registry records through `container.`-relative schema paths, and binding would take rows out of the
schema. The proposed issue is `state:will-not-do`, `severity:low`. It is **unfiled**, because this run
was told to skip filing.

**Skipped or unreached:** none.

**Gates.**

| Point | `lua tests/run.lua` | `luacheck .` |
|---|---|---|
| Before the copy | 251 passed, 0 failed, 0 skipped, 251 total | 0 / 0 in 62 files |
| After the copy and the provenance roll | 251 passed, 0 failed, 0 skipped, 251 total | 0 / 0 in 62 files |

The vendored-payload pair ran rather than skipped, against `../LibKa0s` at `v1.31.0`. `.luacheckrc`
excludes `libs/` and `tests/_kit/`, and this commit changes no file in the checked set apart from
docs. The total is unchanged, so `docs/test-cases.md` and the README badge do not move.

Nothing was pushed.
