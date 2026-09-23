# 05 - Summary: LibKa0s v1.54.2 -> v1.55.0

Run: 2026-09-23, `/wow-addon:revendor-libka0s` in two passes by the suite standards sweep: Steps
2-4 in Phase 5 (`01_DELTA.md`), Steps 5-8 in Phase 6 under the owner's delegation (CP-6) in place
of the interview. Branch `suite/2026-09-22-standards-sweep`. No push, no version bump.

## The tag and the per-file minors

`v1.54.2` -> `v1.55.0` (tag object `bb161b7`, commit `6f9c5e0`). Every existing payload file's
LibStub minor is unchanged; three new majors arrive: `LibKa0s-Compat-1.0` (Compat.lua minor 1),
`LibKa0s-Bus-1.0` (Bus.lua minor 1), `LibKa0s-Schema-1.0` (Schema.lua minor 1). `LibKa0s.xml` gains
their three rows. Test kit revision 24 -> 25. The full table is in `01_DELTA.md`, 3c.

## Delivered for free (class A)

- Kit revision 25: the layout-§1 cap gate (`test_layout_cap`), the (basename, directory) suite key,
  the `.gitattributes` body case in `test_eol`, and the commit and tree cells in `RESULTS.md`. The
  host work they owed landed in Phase 5 (`08fe43b`, `f6f3ffb`, `b2e0e97`).
- `Kit.prose.exempt` is not needed: this repo's one prose narrowing (`tests/prose_waivers.lua:15`,
  `docs/spell-research/`) is a frozen dated store, the waiver file's `skipDirs` case.

## Contract blockers

None in LibKa0s (`01_DELTA.md` 3g). One kit blocker (`test_layout_cap` undeclared) was fixed in
the vendor commit `f6f3ffb`.

## Adopted

| Candidate | Commit | Tests added |
|---|---|---|
| C1 `LibKa0s-Bus-1.0`, `Catalog` only | `059f0a1` | `test_bus`: the four pairs pinned (characterization, green before the change), the strict read raising on an undeclared key and on a new key, the degraded plain table. `test_surface_parity`: Bus stub parity (ignore `New`). Runner map row `LibKa0s-Bus-1.0`. |
| C2 `LibKa0s-Compat-1.0`, `GetSpellInfo` and the guard trio | `c802172` | `test_secrets`: the 3 x 6 guard matrix, value and arity (characterization), the library identity of the three guards, the same matrix on the degraded arm. `test_compat`: hit name/icon and miss arity 1 (characterization), the six-value hit and legacy miss arity 1, the degraded absent answer. `test_surface_parity`: two Compat calls (`NS.Compat`, `NS.Secrets`). Runner map row `LibKa0s-Compat-1.0`. |

Seam names kept: `NS.MSG`, `NS.bus`, `NS.NewBusTarget`, `NS.Compat.GetSpellInfo`,
`NS.Secrets.IsSecret` / `CanAccess` / `IsSafeKey`. No call site moved. New name: `NS.BusLib` (the
resolved Bus major or its stub, for the parity gate).

Behavior deltas, all named in the spec or in `03_DECISIONS.md` D3:
- An undeclared `NS.MSG` key now raises (live); the degraded load reads it as nil.
- `NS.Compat.GetSpellInfo` answers six values on a hit (the first two unchanged; every caller
  reads the first), one nil on every miss (the legacy branch used to answer two nils), and nil
  without the library (it used to read `C_Spell` there).

## Declined

| Candidate | Decision | Issue | Labels |
|---|---|---|---|
| The Bus stand-down record (`New` / `NewTarget` / `StandDown` / `StandUp`) | never: a second mechanism beside the per-module stand-downs (`bus.md:606-610`) | https://github.com/tusharsaxena/AuraMaster/issues/20 | `state:will-not-do`, `severity:low` |
| C3 `LibKa0s-Schema-1.0` partial adoption | not now: the spec permits the deferral and minor 1 deletes no host code (`schema.md:529-531`) | https://github.com/tusharsaxena/AuraMaster/issues/21 | `state:triaged`, `severity:medium` |

## Skipped or unreached

None. Issue #20 was not closed: closing it as "not planned" (the collection's convention for a
terminal will-not-do) was refused by this session's permission check, so it stays open for the
owner.

## Gates

All through `~/.claude/wow-addon/bin/ka0s-bounded`; lint is the linter over `.`.

| Point | Headless suite | Lint |
|---|---|---|
| Baseline, `b2e0e97` | 1285 passed, 0 failed, 0 skipped | 0 warnings / 0 errors in 110 files |
| C1 characterization only (uncommitted) | 1286 passed, 0 failed, 0 skipped | not run |
| C1, `059f0a1` | 1289 passed, 0 failed, 0 skipped | 0 / 0 in 110 files |
| C2 characterization only (uncommitted) | 1291 passed, 0 failed, 0 skipped | 0 / 0 in 110 files |
| C2, `c802172` | 1296 passed, 0 failed, 0 skipped | 0 / 0 in 110 files |
| This bundle (with the four files written, before its commit) | 1296 passed, 0 failed, 0 skipped | 0 / 0 in 110 files |

`docs/test-cases.md` was regenerated with `lua tests/run.lua --list` in each adoption commit (1296
cases now) and the README badge moved with it. The perf scenarios and lizard were not run: neither
adoption touches a per-frame path, and they are not part of the commit gate.
