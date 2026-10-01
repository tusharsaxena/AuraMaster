# 05 - Summary: LibKa0s v1.66.0 -> v1.67.0

## The move

Tag `v1.66.0` -> `v1.67.0` (`0bccf4c`, a local tag), base taken from the `CLAUDE.md` provenance line.
Re-vendored in the `CA-AM-RV` commit on `feat/2026-10-02-libka0s-census-adoption`, with the provenance
line and the other places that name the vendored tag (`DEPENDENCIES.md`'s vendor-sync paragraph,
`docs/module-map.md`'s library row) and the `Cfg` row of `docs/debug.md`. Three files moved
(`01_DELTA.md` 3c): Core 9 -> 10, Options 27 -> 28, OptionsIdList 2 -> 3. No file added or removed. The
test kit stays at revision 35.

## Delivered for free (class A)

The IdList help art's loaded-addon guard and its one `Cfg` line; the Options docblock correction
(`02_CANDIDATES.md` A).

## Contract blockers

None (`01_DELTA.md` 3g). Nothing visible moves; with logging on, each helped id list writes one
`help art: no addonName ...` line until `CA-AM-NM` lands.

## Carried in the re-vendor commit

- The provenance line, `DEPENDENCIES.md` and `docs/module-map.md`, rolled to `v1.67.0`.
- `docs/debug.md`'s `Cfg` row: Options 28, OptionsIdList 3, and the new library line.
- `docs/test-cases.md` regenerated (no change) and the README badge left at 1788: no case was added
  or removed.

## Adopted

Nothing in this commit. `addonName` is `CA-AM-NM` (`02_CANDIDATES.md` B).

## Declined

None. The three `MakeResizable` fields have no AuraMaster site (no host-built grip). No issue filed.

## Suite results

Run through `ka0s-bounded` from the repo root: `lua tests/run.lua`, `luacheck .`,
`bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`.

| Gate | Headless tests | Lint | Complexity (sighted) |
|---|---|---|---|
| Before the copy (v1.66.0) | 1788 passed / 0 failed / 1 skipped (1789) | 0 / 0 in 151 files | not run |
| The copy alone, provenance not yet rolled | 1787 passed / 1 failed (vendor sync against v1.66.0) / 1 skipped | not run | not run |
| After the re-vendor commit (v1.67.0) | 1788 passed / 0 failed / 1 skipped (1789) | 0 / 0 in 151 files | `pass`: 0 warnings, maxCcn 15, 4683 functions |

`diff -r --strip-trailing-cr ../LibKa0s/LibKa0s libs/LibKa0s` (and the kit against `testkit/`) prints
nothing. No consumer test broke on the library change.
