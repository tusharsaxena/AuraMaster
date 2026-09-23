# 04 - Execution plan: LibKa0s v1.54.2 -> v1.55.0

Step 7 of `/wow-addon:revendor-libka0s`, written before any code moved. Two adopted candidates
(`03_DECISIONS.md` D1, D3), one commit each, in blast-radius order. Every gate runs through
`~/.claude/wow-addon/bin/ka0s-bounded`: `lua tests/run.lua` and the linter over `.`, both green
before each commit. Baseline at `b2e0e97` (Phase 5 end): 1285 passed, 0 failed, 0 skipped; lint
0 warnings / 0 errors in 110 files.

Fences held on both: `libs/` and `tests/_kit/` untouched; no behavior change the spec does not
name; no close control touched; host seam names kept (`NS.MSG`, `NS.NewBusTarget`, `NS.bus`,
`NS.Compat.GetSpellInfo`, `NS.Secrets.*`), so no call site moves.

## Step 1 - C1 `LibKa0s-Bus-1.0` `Catalog` (one commit)

Files: `core/Bus.lua`, `tests/test_bus.lua`, `tests/test_surface_parity.lua`, `tests/run.lua`,
`docs/ARCHITECTURE.md` (library table, `## Message Bus`, `## Known Limitations`),
`docs/module-map.md` if its `core/Bus.lua` row names what the file publishes.

1. **Characterization, before the code:** `tests/test_bus.lua` "the catalog is exactly these four
   keys and wire names" - a literal key-to-value map compared both ways (every declared key present
   with its string, nothing extra). Green on the old `core/Bus.lua`. This pins the output the wrap
   must not change: `pairs(NS.MSG)` and every `NS.MSG.X` read.
2. **Code:** `core/Bus.lua` resolves `LibStub("LibKa0s-Bus-1.0", true)`; degraded arm is the
   Catalog half of the Bus document's untracked-target stub (`Catalog = function(_, m) return m end`),
   with `New` left out because this host never calls it (the factory stays untracked, `bus.md:607-610`).
   `NS.MSG = Bus.Catalog(addonName, MSG)`. The resolved major (or the stub) is published as
   `NS.BusLib` so the parity gate can reach the degraded half. The publisher `NS.bus` and the factory
   `NS.NewBusTarget` are untouched.
3. **New cases (after):**
   - live: `NS.MSG.NO_SUCH_KEY` raises naming the key; assigning a new key raises; the host's input
     table is the declaration on both arms (the degraded `NS2.MSG` holds the same four pairs, plain,
     reading an undeclared key as nil).
   - parity: `Kit.assertSurfaceParity(NS2.BusLib, "LibKa0s-Bus-1.0", { "New" })`, the ignore naming
     the spec's reason; `tests/run.lua` map gains `["LibKa0s-Bus-1.0"] = mocks.LibStub(...)`.
4. **Proof it behaves the same:** the step-1 characterization case stays green on the new code,
   and the existing bus suite (message delivery counts per registry act and per combat edge) is
   unchanged.
5. **Commit boundary:** the five files above; message "Declare the bus catalog through LibKa0s-Bus-1.0".

## Step 2 - C2 `LibKa0s-Compat-1.0` (one commit)

Files: `core/Compat.lua`, `core/Secrets.lua`, `tests/test_compat.lua`, `tests/test_secrets.lua`,
`tests/test_surface_parity.lua`, `tests/run.lua`, `docs/compat-layer.md`, `docs/ARCHITECTURE.md`,
`docs/module-map.md` (the `core/Secrets.lua` row).

1. **Characterization, before the code:**
   - `tests/test_secrets.lua`: a table-driven case over three fixtures (no secrets system;
     `issecretvalue` alone; both client functions) and six inputs (`nil`, `false`, a plain number,
     a string, a secret, a secret the context may read), pinning `IsSecret`, `CanAccess` and
     `IsSafeKey` value AND arity (exactly 1) for each. Green on the old bodies.
   - `tests/test_compat.lua`: `GetSpellInfo`'s first two returns on a hit (`C_Spell` and the legacy
     remap), and arity exactly 1 on every miss (no such spell, a string id, `nil`). Green on the
     old body.
2. **Code:** `core/Compat.lua` resolves `LibStub("LibKa0s-Compat-1.0", true)` after `:3`;
   `GetSpellInfo` keeps the number-only guard and returns `CompatLib.GetSpellInfo(id)`, else `nil`
   (the reader arm: the documented absent answer). `core/Secrets.lua` wires `IsSecret`, `CanAccess`,
   `IsSafeKey` to the major; the present bodies become the guard arm, each with the deliberate-
   duplication comment naming `LibKa0s docs/api/Compat/version-1-docs.md`, "Degradation".
   `IsReadableNumber` and `NumberOr` stay.
3. **New cases (after):**
   - `GetSpellInfo` on a hit answers exactly 6 values (the spec's named delta), the first two
     unchanged.
   - live identity: `NS.Secrets.IsSecret` (and the other two) IS the library's function.
   - degraded load (`tests/degraded_env.lua`, library files skipped, never a member stubbed):
     `NS2.Compat.GetSpellInfo(774)` is `nil`, arity 1 (the absent table); the degraded trio equals the
     library's answer under the same `issecretvalue`/`canaccessvalue` fixture on every input of the
     characterization matrix.
   - parity, two calls: `NS2.Compat` ignoring the trio and the five unwired readers; `NS2.Secrets`
     ignoring the six readers. `tests/run.lua` map gains `["LibKa0s-Compat-1.0"]`.
4. **Proof it behaves the same:** the characterization matrix is green on the new code for both the
   live (library) and the degraded (host body) arm; the three `GetSpellInfo` callers read `name` only
   (`modules/CastAura.lua:72`, `settings/GeneralSpells.lua:256`, `:1247`).
5. **Commit boundary:** the files above; message "Wire GetSpellInfo and the secret guards to
   LibKa0s-Compat-1.0".

## Not implemented

- C3 Schema: declined, not now (`03_DECISIONS.md` D4). No code.
- The Bus tracked record: declined, never (`03_DECISIONS.md` D2). No code.

## Closing

Regenerate `docs/test-cases.md` from `lua tests/run.lua --list` (CRLF) and the README test badge
if the count moved; write `05_SUMMARY.md`; commit the bundle.
