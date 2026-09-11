# 02 — Proposed changes (HLD + LLD)

Standard resolved: **Ka0s WoW Addon Standard v2.42.0 (2026-09-10)**. The cross-check ran against the full standard: the index plus 27 section files. Finding IDs refer to `01_FINDINGS.md`.

Two decisions belong to the user before implementation (CLAUDE.md: *"STOP and flag the deviation"*):
- **D-1 (F-006):** ratify the registry's wholesale writes as a documented deviation, or reroute them through `NS.SetByPath`.
- **D-2 (F-002):** defer teardown until combat ends, or refuse registry operations in combat.

This document recommends one option for each and lists the alternative.

## HLD — themes

| Theme | Findings | Rationale | Alternatives rejected |
|---|---|---|---|
| **T1 Engine update completeness** | F-001 | Every option handed to the engine at build must either be re-sendable on the in-place path or be part of the structure key. | Rebuild on every enchant-container change: always correct, but it retires a frame per slider tick. |
| **T2 Combat-safe teardown** | F-002 | Teardown is structural work and has to obey the same `MustDefer` gate as build. | Refusing in combat (D-2 alt.) cannot cover AceDB profile callbacks, which fire whatever we say. |
| **T3 Announce only what applies** | F-003, F-012 | A write that has no stored state must not queue an apply. The deferral notice must name its real cause. | Suppress the notice only (hides the wasted apply pass). |
| **T4 Picker forbidden-safety** | F-004 | Check `IsForbidden` before any other method on a frame of unknown provenance. | Wrap in `pcall` (hides the ordering bug and costs a closure per frame). |
| **T5 Registry robustness** | F-005 | `PrepareProfile` promises a registry every reader can trust, so it must drop keys it cannot normalize. | Letting it raise (a load failure). |
| **T6 Write-path discipline** | F-006, F-007 | One seam (architecture-§5), or a ratified register row, never an unrecorded exception. A rule enforced only by dead code is not enforced. | Deleting the `UniqueName` rule (loses a real invariant). |
| **T7 Evidence fidelity** | F-008, F-009, F-010, F-021 | Committed figures must measure the addon, and the zero-overhead claim needs its required scenario (performance-§9). | A wall-clock assertion (forbidden by performance-§9). |
| **T8 Hot-ish allocation** | F-011, F-020 | Client-side objects built once per container look, not once per button. | Caching on the button (`frame.__am`), which ties state to engine-owned frames. |
| **T9 Text and docs hygiene** | F-013, F-014, F-018 | Whole-sentence locale keys (localization-§1), one key per message, and citations that resolve. | — |
| **T10 Small frame/lifecycle fixes** | F-015, F-016, F-017 | Low-risk one-liners. | — |
| **Deferred** | F-019 | Four writes coalesce into one apply; the only extra cost is log lines. Revisit if T3's announce work lands a batching primitive. | A "position" carve-out (adds a fourth whole-set writer for a cosmetic gain). |

## Upstream change-set (lands in another repo)

| ID | Repo / file | Fix | Version bump | Consumer follow-up |
|---|---|---|---|---|
| U-001 | LibKa0s → `testkit/mock_base.lua` | Model `AceGUI:Release(widget)`: mark the widget released, hide its frame, and append it to a `__released` recorder, mirroring tests/wow_mock.lua:132–139. | Per the library's release process: the next LibKa0s release tag, with a CHANGELOG entry. testkit files carry no LibStub minor. | **Re-vendor commit** in this addon: copy the whole `testkit/` into `tests/_kit/`, bump the CLAUDE.md provenance line in the same commit, then delete the local shim at tests/wow_mock.lua:128–139. Repeat for every consumer. |

No entry below targets a path under `libs/` or `tests/_kit/`.

## LLD — change-set

### C-01 (F-001) — Enchant options reach the engine
- **modules/FilterCompiler.lua `FC.StructureKey`:** fold `hidePermanent` into the key, because `AddItemEnchantment` takes it only at creation:
  ```lua
  local e = plan.enchants and (plan.enchants.hidePermanent and "E" or "e") or "-"
  return ("%d:%s"):format(#plan.groups, e)
  ```
- **modules/Container.lua `ContainerClass:Update`:** inside `if plan.enchants then`, re-send the enchant sort whenever the direction changed:
  ```lua
  local dir = cfg.filter and cfg.filter.sortDirection
  if dir ~= self.enchantDir then
      callEngine(engine, "SetItemEnchantmentSortMethod", Compat.EnchantSortByDuration(), Compat.SortDirection(dir))
      self.enchantDir = dir
  end
  ```
  `Build` records `self.enchantDir` too.
- **Risk:** A `hidePermanent` toggle now retires one engine frame. It is a rare, explicit change and matches the ARCHITECTURE Known Limitation.
- **Complexity:** `Update` is at CCN 12 and gains about 2, landing at about 14, under 15.
- **Tests:**
  - Amend "filter: StructureKey tracks the group count and the enchant slots only". This is a legitimate behaviour change, not a change made to turn a test green.
  - Add "container: toggling hidePermanent rebuilds the engine with the new flag".
  - Add "container: a sort-direction change reaches the enchant sort".
- **Standard:** no new deviation.

### C-02 (F-002) — Teardown waits for combat (D-2, recommended)
- **modules/ContainerManager.lua `CM.Sync`:** when `CM.MustDefer()` holds, a no-longer-wanted instance is **parked**, not destroyed:
  1. Call `callEngine`-guarded `SetEnabled(false)`. This is already legal in combat, since `ApplyVisibility` uses it.
  2. Call `NS.Preview.Hide(inst)` and `handle:Hide()` on our own non-protected children.
  3. Record the instance in a module-local `retiring[id] = inst` table.
- **`CM.FlushPending`:** destroy parked instances once `MustDefer` is false, before `applyDirty`.
- **Id reuse:** if `Sync` wants an id that is parked (a profile switch back), take the instance out of `retiring` and reuse it instead of creating a new frame.
- **Tests:** add "manager: deleting a container under lockdown disables it, hides nothing structural, and tears it down after combat". Amend tests/test_container.lua:152 so its expectation carries the lockdown axis.
- **Alternative (D-2 alt.):** `CM.Delete` refuses with `L["Cannot delete a container during combat."]`, like `NS.OpenOptionsPage`. It does not cover `OnProfileChanged`, so it is not sufficient alone.
- **Standard:** events-frames-taint-§2 (guard secure-adjacent writes and replay on regen). No deviation.

### C-03 (F-003, F-012) — Session rows stop queuing applies; the notice names its cause
- **settings/Schema.lua `NS.SetByPath` / `announceWrite`:**
  - For `row.sessionOnly`, still log `[Set]` and `RefreshScalars`, but **do not** send `CONFIG_CHANGED`: the row's own `set()` already applied its effect.
  - Pass `sessionOnly` into `announceWrite` as a flag. Keep the "write, react, log, announce" order.
  - Check subscribers: `ContainerManager` needs nothing here, since `SetPreview` runs `ApplyVisibility`. `TimedSpells.Sync` is unaffected by session rows.
- **modules/ContainerManager.lua `noteDeferred`:** choose between two whole-sentence keys:
  - `L["Aura Master settings changes will apply when combat ends."]` when `InCombatLockdown()`;
  - `L["Aura Master settings changes will apply once aura information is available again (after the encounter, key or match)."]` otherwise.

  Add the key to `locales/enUS.lua` in the same change (`test_locale` enforces this).
- **Comment:** the one at settings/General.lua:57 becomes true as written, so no edit is needed.
- **Tests:**
  - "schema: a session row announces no CONFIG_CHANGED and re-applies no container" (red under: reverting the flag).
  - "manager: /am preview under lockdown prints no deferral notice".
- **Complexity:** `SetByPath` gains 1 CCN, 12 → 13.
- **Standard:** architecture-§4 (CONFIG_CHANGED keeps exactly one sender), options-ui-§1 (panel set still goes through the seam). No deviation.

### C-04 (F-004) — Forbidden check first
- **modules/FramePicker.lua `FP.NamedAncestor`:** make the first statement in the loop `if f.IsForbidden and f:IsForbidden() then return nil end`. `GetParent` is not legal on a forbidden frame either, so the walk stops there. Then drop the `IsForbidden` test from the named-frame branch.
- **Complexity:** CCN stays at about 14.
- **Test:** "picker: a forbidden frame under the cursor ends the walk without calling its methods" (a stub whose `GetName` raises; red under: reverting the order).

### C-05 (F-005) — PrepareProfile drops unnormalizable keys
- **core/Database.lua:** in the rename pass, collect keys where `type(k) ~= "number" and not tonumber(k)` and delete them. Log each with `NS.Debug("Migrate", "dropped container key %s", k)`, where `NS.SafeToString` handles the value.
- **Test:** "database: a non-numeric container key is dropped, and the profile loads".

### C-06 (F-006, F-007) — Write-path discipline (D-1)
- **Recommended (D-1a):** add one row to `docs/ARCHITECTURE.md` → `## Documented deviations`:

  `| architecture-§5 (every mutation through one helper) | ContainerManager's Delete, ResetPositions and CopyFrom replace container sub-tables wholesale and announce CONTAINERS_CHANGED instead of CONFIG_CHANGED | A registry operation spans many rows and containers; per-leaf writes would send dozens of CONFIG_CHANGED for one act | 2026-09-11 | A schema row gains an onChange side effect that these operations must also trigger |`

  Also give each operation one `NS.Debug("Containers", …)` line if it lacks one; ResetPositions has none.
- **Alternative (D-1b):** route them through the seam. That needs a new whole-table carve-out per section, which is more surface than the deviation it removes.
- **settings/General.lua:44:** replace the direct `NS.State.preview = false` with `NS.SetByPath("state.preview", false)`. After C-03 that sends no apply, so the paired `ApplyVisibility` in the same handler stays correct.
- **F-007, settings/Schema.lua `SetByPath`:** add an optional row hook `normalize(value, containerId) -> value`, applied after `validate` and before the write. This is host code, not library code.
- **F-007, settings/Containers.lua name row:**
  ```lua
  normalize = function(v, id) return CM.UniqueName(v:match("^%s*(.-)%s*$"), id) end
  ```
- **F-007, CM.Rename:** becomes `return NS.SetByPath("container.name", name, id)` (still used by the tests), or is deleted with its case retargeted to `SetByPath`. Recommended: keep it as the thin wrapper so the existing case keeps meaning something.
- **Test:** "schema: renaming to a taken name through the seam yields 'X (2)'" (red under: dropping `normalize`).
- **Standard:** architecture-§5, and the CLAUDE.md register format. The deviation is proposed, **not** assumed: the user ratifies it.

### C-07 (F-008, F-009, F-010, F-021) — Evidence fidelity
- **tests/perf.lua `measure`:** run `collectgarbage("stop")` before the loop and `collectgarbage("restart")` after, keeping the full collects either side. Record bytes per iteration only once the GC is stopped.
- **tests/wow_mock.lua:** add `M.__countOnly`. When it is true, `makeEngine`'s recorder increments a per-name counter instead of allocating a `{ name, ... }` table. perf.lua sets it for the measured loops; the functional suites keep the full recorder.
- **Zero-overhead scenario (performance-§9):** add an **instrumentation-absent** arm that runs the same work without the bracket wrappers:
  ```lua
  local absent = measure("probeAbsent", 1000, function()
      for _, inst in pairs(CM.instances) do inst:ApplyVisibility() end
      CM.RefreshUnit("target")
  end)
  assert_(off.bytesPerIter <= absent.bytesPerIter, "a dormant bracket allocates")
  assert_(off.apiPerIter == absent.apiPerIter, "a dormant bracket changes engine calls")
  ```
  `CM.ApplyVisibility` and `addon:OnUnitSwap` are exactly this body plus their brackets.
- **F-010, modules/TimedSpells.lua:** bracket the timer entry, not `TS.Scan`, because Scan is at CCN 15:
  ```lua
  local function scanTick()
      local t0 = Perf.on and debugprofilestop()
      TS.Scan()
      if t0 then Perf.Note("timedScan", debugprofilestop() - t0) end
  end
  ```
  `scheduleScan` then arms `scanTick`, and `local Perf = NS.Perf` sits at file top (TimedSpells loads after PerfSetup per the TOC).
- **F-010, declaring the bucket:** add `{ key = "timedScan" }` to `buckets` in core/PerfSetup.lua; update docs/performance.md's bucket table and the "no per-aura Lua path" sentence; and update test_perf's `#BUCKET_ORDER == 5` to 6 with an `exercise` step that fires the timer. That last edit is legitimate because the declared count changes.
- **F-021:** add `-- red under: SetEnabled writing to the profile` style notes to tests/test_setups.lua:62, tests/test_slash.lua:120 and tests/test_schema.lua:159, after proving each goes red by mutation using a `cp` backup (testing-§12).
- **Standard:** performance-§2, §3 and §9, testing-§7 (perf stays outside the gate; scenarios are not cases) and testing-§12. Rejected: asserting on ms (performance-§9 **MUST NOT**).

### C-08 (F-011, F-020) — Build shared style objects once
- **core/Compat.lua:** memoize `CreateSecondsFormatter(format)` per format key, and `ExpiringTextColor` per `(threshold, expiring rgba, normal rgba)` signature. Use small module-local caches, and clear them from `CM.FlushPending` on each apply pass so a settings change builds fresh objects.
- **modules/Style.lua:** memoize `DispelColorMap` the same way.
- **Risk:** whether a `SecondsFormatter` or a color curve may be shared across buttons is **unverified**. The smoke test S-08 checks it in-client. If sharing fails, fall back to a per-container cache built in `Container:Apply` and handed to `InitFrame`.
- **modules/Preview.lua:** store `container.previewFactory = container.previewFactory or factory(container.anchor)` once per container.
- **Complexity:** `Preview.Offset` (CCN 15) is untouched. The `Preview.Show` change adds no decisions.

### C-09 (F-013, F-014, F-018) — Text and docs
- **settings/Slash.lua:** use one key per sentence with `%s` placeholders, for example `L["Deleted '%s'"]:format(name)`, `L["Unknown word '%s' — try /am new target debuffs icons"]`, `L["Selected %s"]` and `L["Created %s"]`.
- **modules/ContainerManager.lua:242 and :186:** `L["%s (copy)"]` and `L["Container %d"]`. Both are stored names, localized at creation only.
- **F-018:** keep one key per message (drop the period variants) and route both surfaces to it.
- **locales/enUS.lua:** add and remove keys in the same change. `test_locale` fails on a dead key.
- **docs:** fix the 17 stale citations (F-014), or cite the function name (`Container:Build`) where a line will keep moving.

### C-10 (F-015, F-016, F-017) — Small fixes
- **F-015, modules/Container.lua after `SetMovable(true)`:** `if self.anchor.SetDontSavePosition then self.anchor:SetDontSavePosition(true) end`.
- **F-016:** correct the settings/Slash.lua:237 comment to say the stub keeps a *minimal* row join for the landing page, and trim core/PoolSetup.lua:29's minor-number reference to the *behaviour*. No functional change.
- **F-017:** `Anchors.ResolvePending` sets `resolveAfterCombat = true` when it bails. `addon:OnCombatChanged` calls `NS.Anchors.ResolvePending()` on `PLAYER_REGEN_ENABLED` (core/AuraMaster.lua:71–74 already hosts the regen tail).
- **Rejected:** registering `UNIT_PET` as a unit event on a private frame to drop the early return at core/AuraMaster.lua:88. AceEvent-3.0 (minor 4) has no `RegisterUnitEvent`, and a private event frame breaks events-frames-taint-§1 (*"MUST NOT create per-module frames just for events"*).

## Regression pressure

- **Pass count:** 154 → about 163.
  - C-01: +2 (plus 1 amended).
  - C-02: +1 (plus 1 amended).
  - C-03: +2.
  - C-04, C-05 and C-06: +1 each.
  - C-07: 0 new cases (1 amended). Perf scenarios are **not** cases (testing-§7).
- **Same-change rule:** `docs/test-cases.md` (regenerated with `lua tests/run.lua --list > docs/test-cases.md`) and the README `[tests]` badge **must move in the same change** as each new case, never as a follow-up.
- **Complexity watch list:** expected direction only, to be confirmed by the next release run, not regenerated here.
  - `ContainerClass:Update` 12 → about 14; `NS.SetByPath` 12 → about 13; `FP.NamedAncestor` about 14 → about 14.
  - `TS.Scan` stays 15 because its bracket lives in `scanTick`.
  - Nothing is expected to cross 15.
