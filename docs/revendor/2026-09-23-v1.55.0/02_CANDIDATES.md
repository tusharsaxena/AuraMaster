# 02 - Candidates: LibKa0s v1.54.2 -> v1.55.0

Run: 2026-09-23, Step 5 of `/wow-addon:revendor-libka0s`, taken by the suite standards sweep
(Phase 6). The interview of Step 6 is replaced by the owner's delegation (CP-6): the decisions in
`03_DECISIONS.md` follow the delegated rules, each with its reason. Branch
`suite/2026-09-22-standards-sweep` @ `b2e0e97`. No push.

Sources, in the playbook's order:

1. `git -C ../LibKa0s log --oneline v1.54.2..v1.55.0` (eight commits, listed in `01_DELTA.md`).
2. `../LibKa0s/CHANGELOG.md`, the `## v1.55.0 - 2026-09-23` block.
3. The version-1 API documents of the three new majors: `docs/api/Compat/version-1-docs.md`,
   `docs/api/Bus/version-1-docs.md`, `docs/api/Schema/version-1-docs.md` (all new, so every surface
   is `Since 1`).
4. The per-consumer adoption deltas of the three design specs, which name this repo with file:line:
   `Ka0sAddonsCommonTasks/docs/2026-09-22-SUITE_STANDARDS_AND_LIBKA0S_SWEEP/3b-specs/compat.md`
   section 8.1, `bus.md` section 12 ("Catalog only", AuraMaster), `schema.md` section 11
   ("AuraMaster - partial adopter").

No existing major's minor moved (`01_DELTA.md`, 3c), so there is no `Since` diff over a consumed
major, and 3g found no LibKa0s contract blocker. The kit blocker (`test_layout_cap` undeclared) was
fixed in the vendor commit `f6f3ffb` and is in no class below.

Recorded declines searched first (Step 5, class C):
`gh issue list --search "LibKa0s" --state all` returned issues #4, #11, #16-#19, none of which
declines a LibKa0s major; `grep -rn 'LibKa0s' docs --include='*.md' | grep -iE 'declin|not adopt|no combat|exempt'`
(frozen bundles excluded) returned only `docs/ARCHITECTURE.md:69`, Phase 5's note that the three
majors "are not adopted yet". Nothing is settled; every class C candidate below is open.

## Class A - delivered on the copy (recorded, not offered)

- **Test-kit revision 25** (`CHANGELOG.md` v1.55.0, "test_layout_cap.lua", "The declaration is the
  pair", "test_eol.lua - a second case", "The automated-test runner names the commit"). The cap gate,
  the (basename, directory) suite key, the `.gitattributes` body case and the two new `RESULTS.md`
  cells all reached this repo in `f6f3ffb`; the host work they owed (runner row, census) landed in
  Phase 5 (`08fe43b`, `f6f3ffb`, `b2e0e97`).
- **`Kit.prose = { exempt = ... }`** (`CHANGELOG.md` v1.55.0, "test_prose.lua - the generated-data
  carve-out"). Not a candidate here: this repo has no generated data. Its one narrowing,
  `tests/prose_waivers.lua:15` `skipDirs = { "docs/spell-research/" }`, is a frozen dated store,
  which the kit names as the waiver file's `skipDirs` case (`tests/_kit/test_prose.lua:119-122`),
  not the exempt set's. It passes both refusals today (Phase 5 gate, 1285/0/0).
- **No existing `.lua` payload file changed**, so nothing else arrives for free.

## Class B - host change on a consumed major

None. No consumed major's minor moved (`01_DELTA.md` 3c), so no consumed surface gained a field.

## Class C - whole-module adoption

### C1. `LibKa0s-Bus-1.0`, `Catalog` only

- **What:** wrap `NS.MSG` in `Bus.Catalog(addonName, {...})`, so a mistyped key raises at the call
  site for a publisher as well as a subscriber, and the four wire names are validated once at load.
- **Evidence:** `bus.md:606-610` (AuraMaster, "Catalog only"); `bus.md:540-545` (the common block:
  resolve with `LibStub(..., true)`, the section 7 stub, a `Kit.assertSurfaceParity` case, name the
  major in `## Message Bus`, keep the seam names); `../LibKa0s/docs/api/Bus/version-1-docs.md:184-220`
  (`Catalog`: checks, fresh strict copy, `pairs` still enumerates); `:257-313` (worked example and the
  stub parity members `New`, `Catalog`).
- **Files:** `core/Bus.lua:30-47`, `tests/test_bus.lua`, `tests/test_surface_parity.lua`,
  `tests/run.lua:38` (surface-source map), `docs/ARCHITECTURE.md` (library table, `## Message Bus`).
- **Not taken, per the spec:** the tracked record (`New`/`NewTarget`/`StandDown`/`StandUp`).
  `bus.md:607-610`: AM's factory `core/Bus.lua:21-25` stays untracked because its receivers stand
  down by hand per module and the settings target is setup that survives; "Adopting tracked targets
  here would be a second mechanism beside a working first one; not recommended." That is a
  spec-recorded structural misfit, so it is recorded in `03_DECISIONS.md` as its own decline.
- **Recommendation:** adopt. All four keys and values pass `Catalog`'s checks today (`bus.md:299`,
  AM (4)); the only behavior that changes is that an undeclared key now raises instead of reading
  nil (OPEN-2, `bus.md:653-658`).
- **Blast radius:** additive. No host code is deleted; the declaration table is the same literal on
  both arms. Smallest of the three.

### C2. `LibKa0s-Compat-1.0`, `GetSpellInfo` plus the secret trio

- **What:** `NS.Compat.GetSpellInfo` delegates to the major behind AM's number-only guard;
  `NS.Secrets.IsSecret`, `CanAccess` and `IsSafeKey` wire to the major, with the current bodies kept
  as the guard stubs (deliberate, documented duplication). `IsReadableNumber` and `NumberOr` stay.
- **Evidence:** `compat.md:449-463` (8.1 AuraMaster); `compat.md:173-238` (section 4: reader stub
  answers the absent value, guard stub re-implements the one-rung body, the degraded-load gate, the
  two-call parity split for AM, and the runner map row); `../LibKa0s/docs/api/Compat/version-1-docs.md`
  rows 1-4 of the lib-level table (arity: `GetSpellInfo` hit 6, miss 1) and "How a host wires it".
- **Files:** `core/Compat.lua:1-3`, `:312-328`; `core/Secrets.lua:36-50`, `:71-79`;
  `tests/test_compat.lua`, `tests/test_secrets.lua`, `tests/test_surface_parity.lua`,
  `tests/run.lua:38`; `docs/compat-layer.md:36`; `docs/ARCHITECTURE.md` library table.
- **Behavior deltas the spec names:** `GetSpellInfo` returns 6 values on a hit instead of 2 (the
  first two unchanged; the three callers `modules/CastAura.lua:72`, `settings/GeneralSpells.lua:256`,
  `:1247` read `name` only); on a degraded install it answers nil instead of a `C_Spell` read.
- **Recommendation:** adopt. The guard trio's answers are identical on every input
  (`version-1-docs.md`, "IsSafeKey asks IsSecret, not CanAccess": "the answer is identical on every
  input to the copies' `v == nil`-first ordering").
- **Blast radius:** replaces host code on the live path (four bodies become library calls), keeps
  the bodies as the degraded path. No file deleted.

### C3. `LibKa0s-Schema-1.0`, partial adoption (primitives, registry, bracket, validation)

- **What:** route `settings/Schema.lua`'s path primitives, row index, bulk bracket, `changes()`
  and `ValidateSchema` through a `lib:New{ rows = NS.Schema }` instance when the library is present,
  keeping AM's own functions as the library-absent path; AM keeps `SetByPath`.
- **Evidence:** `schema.md:520-538`. The spec's own cost line (`schema.md:529-531`): "minor 1
  removes none of AM's walker or bracket code; the live path runs the shared copy, the degraded path
  AM's. AM MAY defer this adoption until it adopts `Set` (the re-check trigger below); the revendor
  interview decides." Re-check trigger (`schema.md:538`): "`row.normalize` gains a second consumer".
- **Files:** `settings/Schema.lua` (88-120, 181-270, 389-443, 456-686, 819-835),
  `modules/ContainerManager.lua:471`, `:502`, the degraded Reset all, `tests/test_schema*.lua`,
  `tests/test_bulklog.lua`.
- **Recommendation:** decline, not now. The spec permits deferral, and adopting now adds a second
  code path for every primitive (live: library; degraded: host) while deleting none; the one
  semantic move (`changes()` from `FilterCompiler.Signature` to `lib.SameValue`, and the bulk
  bracket's `return true` to `info.profileReset = true`, JC-9) changes a pinned seam for no removed
  code.
- **Blast radius:** replaces the live path of AM's single write seam's helpers (the heaviest of the
  three), deletes nothing.

Unreached: none. Every candidate the three specs name for this repo is listed above.
