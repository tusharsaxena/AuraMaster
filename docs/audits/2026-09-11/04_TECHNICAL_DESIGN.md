# 04 — Technical design: remediation (2026-09-11)

This design is keyed to the IDs in `02_DEVIATIONS.md` and is ordered by blast radius, largest first.
Every code change follows the green gate (`lua tests/run.lua` plus `luacheck .` at 0/0) and TDD: a
failing case first. Behavior-preserving edits get a characterization case first (testing-§13).

**Two decisions are the user's.** AM-03 and AM-04 can each close in one of two ways: change the code,
or record a `## Documented deviations` row. This design writes out both options. Pick one per ID
before sprint 1 starts.

---

## AM-02 — Defer structural teardown under combat lockdown

**Files:** `modules/ContainerManager.lua`, `modules/Container.lua`, `settings/Slash.lua`,
`settings/Containers.lua`, plus tests.

**The refusal.** `/am delete` and the Containers page's Delete button should refuse under
`InCombatLockdown()` with a gray line, the same way `/am pick` does (`settings/Slash.lua:192`). That
covers the options-ui-§2 SHOULD for setters that create or destroy frames.

**The deferral.** A profile switch in combat can still reach `CM.Sync`, so the refusal alone is not
enough. Split teardown in two:

1. `CM.Sync` keeps doing registry bookkeeping. When `CM.MustDefer()` is true, it only calls
   `inst:Park()` for the vanished instances. `Park` is a new method that calls
   `callEngine(engine, "SetEnabled", false)` (combat-legal, as `ApplyVisibility` already relies on) and
   hides the preview. It never calls `Hide`.
2. The parked instances go into a `pendingDestroy` set, which `FlushPending` drains, calling
   `inst:Destroy()` once `MustDefer` is false.

**Order.** `FlushPending` already runs on `PLAYER_REGEN_ENABLED` and on
`ADDON_RESTRICTION_STATE_CHANGED`. Drain `pendingDestroy` before `applyDirty`, so a re-created id
cannot collide with a parked one.

**Tests.**

- `tests/test_containermanager.lua` — set the mock's lockdown true, delete a container, and assert:
  `Hide` was not called on the engine, `SetEnabled(false)` was, and after
  `InCombatLockdown = false; CM.FlushPending()` the anchor is hidden.
  - Name the mutation: drop the `MustDefer` branch in `Sync`.
- `tests/test_slash.lua` — `/am delete` under lockdown prints the refusal and leaves the registry
  intact.

**Risk.** Parked instances keep their frames for the rest of the session. That is already true of
every destroyed instance, since WoW never frees frames, so nothing new is leaked.

## AM-01 — Replay pending frame anchors after combat

**Files:** `core/AuraMaster.lua`, `tests/test_anchors.lua`.

In `addon:OnCombatChanged`, inside the `PLAYER_REGEN_ENABLED` branch, call
`NS.Anchors.ResolvePending()` after `FlushPending`. It is already guarded, so it no-ops if called under
lockdown.

**Test.** With the mock in lockdown, fire `ADDON_LOADED` after the target frame appears. Assert the
container is still pending. Then fire `PLAYER_REGEN_ENABLED` and assert `Anchors.Pending()` is empty
and the container is placed in `frame` mode.
- Mutation: remove the new call.

## AM-03 — Class color on unit-scoped containers (user decision)

**Option A — ratify (recommended given the engine constraint).** Add a row to
`docs/ARCHITECTURE.md` → `## Documented deviations`:

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `options-ui-§17` | Every container's *Use class color* resolves to the player's class, including target/focus/pet containers | Restyling engine buttons is forbidden while auras are secret, so a unit-class color would go stale on every target swap in combat; reasoned in `docs/scope.md` and audit `AM-03` (2026-09-11) | 2026-09-11 | The engine allows restyling while auras are secret, or exposes a per-button unit-class tint the engine applies itself |

Keep the Known Limitations bullet, and point it at the row.

**Option B — implement.**

- Declare `classColor = { source = "unit" }` on the rows of the per-container pages when the active
  container's unit is not `player`. Because the path cannot decide this (§17), the declaration has to
  follow the container.
- Resolve with `NS.ResolveColor(stored, on, cfg.unit)`.
- On `OnUnitSwap`, queue a restyle through `RequestApply(id)`, which is already deferred while secret.

Colors stay stale during combat until secrecy lifts. That limitation then belongs in Known
Limitations, not in the register.

## AM-04 — TimedSpells event frame (user decision)

**Option A — ratify (recommended).** Add a register row: Rule `events-frames-taint-§1`. What differs:
UNIT_AURA and PLAYER_REGEN_ENABLED are registered on a private frame. Why: AceEvent-3.0 has no
unit-filtered registration, and a bare `UNIT_AURA` fires for every raid member and nameplate.
Re-check trigger: "AceEvent-3.0 gains unit-event registration, or the scan no longer needs UNIT_AURA".

**Option B.** Use a private `NS.NewBusTarget()` embed and `RegisterEvent("UNIT_AURA", handler)`, with
`if unit ~= "player" and unit ~= "pet" then return end` as the first line of the handler. The cost is
one Lua call per UNIT_AURA for every unit, which is why A is recommended. `tests/perf.lua` could
measure it.

## AM-11 — Suspend gates the queued apply

**Files:** `modules/ContainerManager.lua`, `tests/test_perf.lua`.

At the top of `CM.FlushPending`, after `scheduled = false`, add
`if NS.Perf.suspended then return 0 end`. The pending set is kept, and `resume` already calls
`RequestApply()` (`core/PerfSetup.lua:82`), which drains it.

**Test.** Extend the existing suspend case: queue `RequestApply(1)`, suspend, flush, and assert the
`applyContainer` bucket did not grow. Then resume and assert it did.

## AM-17 — Peer notification through the bus

- **New message.** Add `TIMED_SPELLS_CHANGED = "Ka0s_AuraMaster_TimedSpellsChanged"` in
  `core/Bus.lua`, with sender TimedSpells and no payload. Replace `modules/TimedSpells.lua:64` and
  `:121` with `NS.bus:SendMessage(NS.MSG.TIMED_SPELLS_CHANGED)`. ContainerManager subscribes on its
  existing target (`modules/ContainerManager.lua:299`) and calls `CM.RequestApply()`.
- **Master rows.** Delete the `masterOnChange` direct calls (`settings/General.lua:37-47`). In
  ContainerManager's `CONFIG_CHANGED` receiver, when `payload.containerId == nil`, call
  `CM.ApplyVisibility()` immediately (combat-legal) before `RequestApply(nil)`.
- Keep the `locked` side effect (ending preview) in the row's `onChange` or in `SetPreview`. It is a
  state write, not a peer call.
- **Docs.** The `## Message Bus` table grows to four rows, still under the more-than-ten trigger.
- **Tests.** A two-receiver bus case for the new message (architecture-§4 mock fidelity), and a case
  proving a `/am set visibility never` hides containers in the same frame.

## AM-10 — Compat shim for the metadata reader

Add `function Compat.GetAddOnMetadata(name, field)` to `core/Compat.lua`, running the C_AddOns →
global → nil ladder. Replace `core/EnvSetup.lua:24-30` with a call to it. Compat loads first
(`AuraMaster.toc:39` versus `:47`). Update `docs/compat-layer.md` and the Tier 2 row (18 shims), and
add a `tests/test_setups.lua` degraded-arm assertion.

## AM-12 — One home for defaults

In the six `modules/` files, replace the 12 re-typed literals listed in E-18. Use a module-level
upvalue such as `local D = NS.CONTAINER_TEMPLATE` (defaults load before modules), for example
`tonumber(b.width) or D.bars.width`. Where Backfill guarantees the key, drop the fallback outright.

Build no per-call table (anti-pattern #43). Add a characterization case over `Style.ElementSize` and
`Container.FlowSettings` with a stored-nil container before editing (testing-§13).

## AM-05 — Compose the Background block

**Files:** `settings/Bars.lua`, `defaults/Profile.lua`, `modules/Style_Bars.lua`.

- Replace `:74-82` with
  `H.BarGroup({ prefix = P, page = PAGE, group = G_BG, subgroup = L["Background"], keys = { barTexture = "bgTexture", barAlpha = "bgAlpha", barColor = "bgColor", useClassColorBar = "useClassColorBg" }, classColor = PLAYER })`.
  Before adopting it, confirm that the vendored composer honors `keys`: the stub mirrors it at
  `settings/OptionsSetup.lua:91,96`, but read `libs/LibKa0s/OptionsCompose.lua` for the live arm.
- Add `bgAlpha = 1.0` to the template. Backfill fills it with `== nil`, so no `schemaVersion` bump is
  needed.
- Apply `am.bg:SetAlpha(tonumber(b.bgAlpha) or 1)`.

**Tests.** The schema row count becomes 193. Update `docs/ARCHITECTURE.md:83`, `docs/settings-panel.md`
and the pinned counts in `tests/test_optionssetup.lua`, including the degraded-versus-live delta
(options-ui-§1).

**Alternative.** Drop the texture picker, which leaves a pure background swatch and its companion.
That loses a feature players may already use, so it is not recommended.

## AM-19 — Canonical refusal wording

`settings/OptionsSetup.lua:209`: print
`"|cff808080" .. L["cannot open settings during combat — Blizzard's category-switch is protected"] .. "|r"`.
Swap the `enUS` key and its locale test. Update the README FAQ line that paraphrases it
(`README.md:91`, which says "prints a gray line") only if the wording is quoted there. Today it is
not.

## AM-13 / AM-14 — Translatable, unformatted chat lines

Rewrite the `settings/Slash.lua` sites as single keyed sentences with placeholders, for example
`L["Selected %s"]`, `L["Created %s"]`, `L["Deleted '%s'"]` and `L["'%s' is now attached to %s"]`.
Pass each argument through `NS.SafeToString`. This is the one place where localization-§1 (route the
whole sentence) outranks the events-frames-taint-§8 SHOULD NOT: the values are addon-owned names and
ids, outside the trigger set.

Route `"Container %d"` and `"%s (copy)"` in ContainerManager through `L`. `tests/test_locale.lua`
already fails on a missing key, so it covers the new ones.

## AM-16 — Trace the silent decisions

Add three gated lines, keeping the zero-alloc form (debug-logging-§4):

- `NS.Debug("Apply", "deferred: secret=%s lockdown=%s", NS.Compat.AurasAreSecret(), InCombatLockdown())`
  in `FlushPending`'s defer branch;
- `NS.Debug("Anchor", "container %s: %s unavailable, screen fallback", id, at.mode)` in `Anchors.Place`;
- `NS.Debug("Anchor", "resolve skipped under lockdown")` in `ResolvePending`.

## AM-06 — Wrap-invariant case

- In `tests/wow_mock.lua`, answer a **different** atlas height for the selected-state tab art than for
  the inactive art. Without that the case is green against nothing (testing-§12).
- In `tests/test_optionssetup.lua`, render the Bars page's container ctx at a width that forces a
  wrap. Then, for each tab key, set `ctx.activeTab`, re-render, and record the reserved band and every
  tab's y offset. Assert all selections agree.
- Comment the mutation it dies under: `-- red under: pitch read from the selected tab's art`.

## AM-18 — Assert the runner's recorded mode

**Upstream (the canonical fix).** File an issue in LibKa0s asking the consumer gate
(`testkit/vendor_sync.lua`) to assert `git ls-files -s tests/_kit/run-automated-tests.sh` reports
`100755`. Re-vendor when it lands, per automated-tests-§2.

**Interim.** Add a case to `tests/test_vendor_sync.lua`, which is the addon's own file and not the
kit. Shell `git ls-files -s tests/_kit/run-automated-tests.sh` once and assert that the mode field is
`100755`. Skip with a reason when `git` is unavailable.

## AM-07 / AM-08 / AM-09 — Citation sweep

One docs-only change:

- Re-run the E-15 script over `docs/*.md` and `DEPENDENCIES.md`, and fix each of the 35 citations to
  the line in E-15's "Actually at" column. Resolve the two unverified ones by rewording.
- In `DEPENDENCIES.md:27-29`, delete the `Compat.IsAddOnLoaded` sentence, or reword it to say that
  the only add-on-loaded check is `Compat.EnsureAuraContainer`'s own (`core/Compat.lua:30`).
- Correct `core/PoolSetup.lua:5-9`: the pool serves preview elements only.
- Correct `core/CoreSetup.lua:80-81`. Either delete the frame-picker claim, or stop publishing
  `NS.SKIN`/`NS.ApplySkin`, which have no consumer. If you remove them, remove them from the stub too.
  The parity case (`tests/test_surface_parity.lua`) keeps the two arms equal.

A lasting guard is optional: a `tests/test_docs.lua` case that resolves every `path.lua:N` cited in
`docs/` to a non-blank line. That would have caught 4 of the 35 (the blank-line ones) mechanically.

## AM-15 — TOC conventional marks

Add one `# Conventional: …` line above `core\Secrets.lua`/`core\Database.lua` (reached at call time),
one for the Modules group after Style, and one for the settings pages. `tests/test_loadorder.lua:39`
("the TOC says why") should keep passing. Extend it if it enumerates comments.

## AM-20 — Screenshots

Capture:

- a bar container and an icon container;
- the unlocked handle with its preview;
- one image per settings sub-panel.

Put them under `media/screenshots/`, which is already ignored by nothing, so it ships as intended.
Add `## Screenshots` between the description and `## Usage`, with captions. This is a README edit, so
it takes the de-AI pass (anti-pattern #77).

---

## Ordering constraints

- **AM-11 before AM-17.** Moving TimedSpells' notification onto the bus makes ContainerManager's
  receiver the only apply entry point, and that receiver has to respect suspend first.
- **AM-02 before AM-01.** Both touch the `PLAYER_REGEN_ENABLED` flush path.
- **AM-05 after the AM-03 decision.** Both edit the Bars page's color declarations.
- **AM-07 last.** Every code change above moves lines, so the citation sweep runs once, after them.
