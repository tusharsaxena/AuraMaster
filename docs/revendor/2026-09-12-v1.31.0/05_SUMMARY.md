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

## Addendum, 2026-09-12: the v1.31.0 tag was re-cut before release

This bundle was written against the first cut of the `v1.31.0` tag (commit `30db4ed`). Before anything
was pushed, a review of that release found defects in the kit-17 fakes, and LibKa0s re-cut the tag on the
fixed tree: **`v1.31.0` now points at `e7e1962`**. The re-vendor commit that follows this bundle copied
both payloads whole from the re-cut tag, and the vendor-sync cases pass against it.

What the re-cut changed, relative to the tables above:

| File | First cut | Re-cut |
|---|---|---|
| `Perf.lua` | minor 10 (unchanged) | **minor 11**: `P.Save` traces the ring trim once past its cap (debug-logging-§8) |
| `OptionsWidgets.lua` | minor 15 | minor 15 (review fixes land inside the unreleased minor: `pairWith` keyed by `row.path or row.field`; a bound row's `disabledIf` reads through `row.get`) |
| `OptionsCompose.lua` | minor 4 | minor 4 (unchanged surface) |
| kit (`tests/_kit/`) | revision 17 | revision 17 (review fixes: repeating-timer delay no longer drifts; the nameless `NewAddon` path is exactly one table argument; the timer handle field is AceTimer's own `cancelled`, and `NewTimer` handles answer `IsCancelled()`; dispatch survives a handler error; `ADDON_LOADED` after login enables a load-on-demand addon; the AceEvent library object carries the message API) |

So three files in `LibKa0s/` move in this release, not two, and any "the ring trim is not traced" finding
recorded above is resolved upstream by Perf minor 11. The gate was re-run on the re-cut payload at the
re-vendor commit `cb2e440`: `lua tests/run.lua` 252 passed, 0 failed, 0 skipped, 252 total; `luacheck .`
0 warnings / 0 errors in 62 files.
