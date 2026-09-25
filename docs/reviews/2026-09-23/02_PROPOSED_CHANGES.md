# Ka0s Aura Master — proposed changes (2026-09-23)

**Standard resolved:** Ka0s WoW Addon Standard **v2.64.0 (2026-09-23)** (`../WowAddonStandards` @ `e68795f`,
index byte-identical to the `curl`ed remote). Every change below was checked against it as a
constraint; this is a guardrail on the remediation, not a compliance audit.

No change in this document targets a path under `libs/` or `tests/_kit/`.

## HLD — themes

### T1. Container instances outlive their registry entry (F-001)

Frames cannot be freed, so an instance destroyed out of combat is dead weight; the only question is
whether a later build for the same id reuses it. Today only the **parked** path does. Theme: keep
**destroyed** instances in the same `retiring`-style table (a `dormant[id]`) and let `follow` revive
from it exactly as it revives a parked one — rebuilt for the new data by the next apply, which already
happens because `revive` is followed by `CM.RequestApply()` in `CM.Announce`.

*Alternatives considered.* (a) Drop the global name (`CreateFrame("Frame", nil, …)`) — removes the
`_G` collision but not the leak, and loses the name the docs, debugging and `/fstack` rely on;
rejected as the whole fix, noted as unnecessary once reuse lands. (b) A `CreateFramePool` for anchors —
the anchor is not a pooled widget but a per-id identity with a handle, blocker, outline and preview
pool hanging off it; pooling by id **is** the dormant table, so (b) collapses into the chosen shape.
(c) Never reuse ids (monotonic counter across resets) — would stop the reset case only; a profile
switch legitimately reuses ids from another profile's registry.

*Trade-off.* A dormant instance keeps its retired engines; that is already true of every live instance
(`self.retired`), and bounded by the number of distinct ids ever used this session.

### T2. Filter `UNIT_AURA` in the client, not in Lua (F-002)

Adopt `events-frames-taint-§1`'s *one permitted private frame*: a frame held on `NS.TimedSpells`
whose only job is `RegisterUnitEvent("UNIT_AURA", "player", "pet")` plus the single `OnEvent` that
dispatches to `onUnitAura`. The open/close gate (`syncAuraListen`) and the stand-down stay exactly as
they are; only the registration target moves. The carve-out's three MUSTs shape it: held on the
module (not a closure), unregistered by hand in `TS.Stop` (AceEvent's `UnregisterAllEvents` does not
reach it), and **reused** across disable/enable.

*Rejected:* keeping AceEvent and adding a unit check earlier — the check is already first; the cost
being removed is the client dispatch, which only a unit-filtered registration avoids.

### T3. Bring the two warned functions under CCN 15 by removing decisions, not relocating them (F-003)

`Cat.SyncUserCategories` becomes an orchestrator over four named local phases whose names say what
they do: `teardownUserDefinitions(template)`, `insertBeforePaths()`, `materializeRecords(recs, order,
template)` and `registerUserRows(built, before)`. Each is a real phase with its own invariant already
documented in the existing comment, so this is the split `performance-§11` asks for, not a `part2`
(anti-pattern #52). `renderCategories` loses its `custom` arm to a named `renderCustomGrid(ctx, cfg,
mine, hideRow, auraType)`, leaving a three-way dispatch.

*Constraint:* the existing comments (the WHY — teardown-before-build, rows-last, schema-order-tracks-
Cat.For) travel with the code they explain; no behavior change rides in this diff.

### T4. Tabbed rendering: route upstream, don't polish the fork (F-004)

No local rewrite. The host's `RenderTabbedPage` / `buildContainerHeader` stay until LibKa0s grows the
fields they need; then the host adopts. The upstream request is **additive** (see the upstream
change-set). It must clear anti-pattern #55 in the library repo: the candidate consumers
(AbsorbTracker, KickCD, ConsumableMaster, MultiMeters, AuraMaster) need the same *semantics* —
bespoke tabs beside group tabs, a whole-page disabled notice, and a one-row band carrying picker +
create — with no per-consumer behavior flag. If the library owner rules otherwise, the fallback is a
documented deviation row in `docs/ARCHITECTURE.md`, not silence.

### T5. Robustness and the disabled contract (F-005, F-006, F-007, F-009)

Small, independent hardening:
- per-event `pcall` registration with a recorded reject list (F-005, `events-frames-taint-§1`);
- `CM.Init` / `CM.Announce` build no instances while stood down, and the stand-up builds them
  (F-006) — or, the lighter option, correct the comment and hide freshly built anchors; the first is
  preferred because it makes the doc true rather than the code smaller;
- the degraded Lifecycle stub gains an edge (a remembered `down` boolean) so it fires only on change
  (F-007);
- the Test mode row refuses while disabled with the dispatcher's one line (F-009), matching the verb
  and the launcher.

### T6. Stubs, lint, comments and docs (F-008, F-010, F-011, F-012, F-013, F-014)

Trim the stubs to what a degraded build actually needs; remove dead `read_globals`; fix the misplaced
and merged comments and move review-history narration out of code; correct the stale citations and
README row; collapse the duplicated predicate and the duplicated pick flow.

---

## Upstream change-set (lands in LibKa0s, not here)

There is no **defect** in the vendored library from this review — vendor sync is clean and nothing
under `libs/` misbehaves. One **additive** request arises from F-004:

| # | Owning repo | File(s) | Change | Minor bump | Consumer follow-up |
|---|---|---|---|---|---|
| U-1 | `tusharsaxena/LibKa0s` | `LibKa0s/OptionsWidgets.lua` (`O.RenderTabbedSchema`), `LibKa0s/OptionsTabs.lua` (`O.PageBanner`) | Additive spec fields: `tabs` (bespoke tabs rendered by a host callback, placed `before` a group), `disabledFor(cfg)` + `disabledNotice`, and a `chrome(ctx)` hook; `PageBanner` gains an optional right-half `action` button (options-ui-§14's one-row band). Existing callers unchanged. Evaluate against anti-pattern #55 first. | OptionsWidgets minor +1, OptionsTabs minor +1 | Re-vendor the **whole** `libs/LibKa0s/` into every consumer as its own commit; then AuraMaster adopts (C-04b) |

**Never** patch `libs/LibKa0s/` in this repo for U-1; the next whole-folder copy would silently revert it.

---

## LLD — change-set

### C-01 — Revive destroyed instances instead of rebuilding them (F-001)

`modules/ContainerManager.lua`
- `CM.Sync`: in the non-deferred branch replace `inst:Destroy()` with `inst:Destroy(); dormant[id] = inst`.
- `follow(id, hold)`: after the `retiring[id]` branch add `elseif dormant[id] then` → `local d = dormant[id]; dormant[id] = nil; d.staleData = true; revive(id, d, hold)`.
  `staleData = true` keeps it parked until its apply rebuilds it for the new data (the same guard a
  profile-change park already relies on); `CM.Announce` already queues that apply.
- `destroyParked()` moves destroyed instances into `dormant` rather than dropping them.
- Correct the `:51-63` comment to cover both halves.

`modules/Container.lua` — `Destroy` stays as is (Retire + hide); add `ContainerClass:Revive()` only if
`revive` needs to re-`Show` the anchor (it does: `Destroy` hid it and `ApplyAnchorShown` only shows when
not stood down — verify, then rely on it).

Tests (new, in `tests/test_containermanager.lua`): *"an id rebuilt after an out-of-combat destroy
revives the dormant instance — no second AuraMasterAnchor<id>"* driving A(1–5)→B(1–2)→A, asserting
`spyCreate(mocks, "AuraMasterAnchor3")` counts 0 on the return and the instance draws for A's data after
the apply. `-- red under: CM.Sync dropping the destroyed instance instead of keeping it dormant`.
**Moves the pass count** → regenerate `docs/test-cases.md` and the README `[tests]` badge in the same
commit.

Risk: an instance revived from `dormant` carries a `classColor` / `plan` from the old data; `Apply`
re-snapshots and rebuilds, and `staleData` keeps it dark until then.

### C-02 — Unit-filtered `UNIT_AURA` frame (F-002)

`modules/TimedSpells.lua`
```lua
-- The one permitted private frame (events-frames-taint-§1): its only job is the unit filter.
TS.unitFrame = TS.unitFrame or CreateFrame("Frame")
TS.unitFrame:SetScript("OnEvent", function(_, _, unit) onUnitAura(nil, unit) end)
-- syncAuraListen:
--   open:  TS.unitFrame:RegisterUnitEvent("UNIT_AURA", "player", "pet")
--   close: TS.unitFrame:UnregisterEvent("UNIT_AURA")
-- TS.Stop: also TS.unitFrame:UnregisterAllEvents()
```
The frame is built once at file load and reused (carve-out MUST). `onUnitAura`'s `IsSafeKey` guard stays
(the unit is still compared). Rewrite the `:13-21` header to cite the carve-out instead of the old
"AceEvent cannot" rationale.

Tests: `tests/test_disabled.lua`'s registration census must now include this frame (it will go red
until the stand-down unregisters it — that is the point); `tests/test_timedspells.lua` asserts the
registration is `RegisterUnitEvent` with exactly `player`,`pet`. Requires the kit mock to record
`RegisterUnitEvent` (testing-§1 fidelity) — if it does not, that is an `[upstream]` kit gap, not a
local mock edit. `tests/perf.lua`'s `unitAuraOther` scenario changes meaning (the client no longer
delivers `nameplate1`): replace it with an assertion that no `UNIT_AURA` registration exists on the
shared AceEvent target. Pass count moves → inventory + badge in the same commit.

### C-03 — Split the two warned functions (F-003)

`defaults/Categories.lua` — extract four local phases from `Cat.SyncUserCategories` (T3). Target: each
≤ CCN 8; the orchestrator ≤ 5. `settings/Filters.lua` — extract `renderCustomGrid`. No behavior change;
the existing suites are the characterization net (`tests/test_defaults.lua`, `test_database.lua`
user-category sections, `test_pages_filters.lua`). No pass-count change expected. Expected watch-list
movement: both entries leave the warning list at the next release regeneration — a note for
`/wow-addon:bump-version`, not a run now.

### C-04 — Tabbed render (F-004)

- **C-04a (now):** add a `docs/ARCHITECTURE.md` note under *Settings* naming `Helpers.RenderTabbedPage`
  as a host fork pending U-1, with the upstream issue link. No code.
- **C-04b (after U-1 re-vendor):** replace `Helpers.RenderTabbedPage` with `RenderTabbedSchema(ctx,
  pageKey, afterGroup, pairWith, { tabs, disabledFor, disabledNotice, chrome })` and
  `buildContainerHeader` with `PageBanner` + `action`. Test impact: `test_optionssetup.lua` /
  `test_pages_*` tab cases re-pointed, not removed.

### C-05 — Isolated event registration (F-005)

`core/AuraMaster.lua` — a local `safeRegister(target, event, handler)` that `pcall`s and appends
rejects to `NS.RejectedEvents`; `RegisterLifecycleEvents` and `TS.Sync` go through it; the `debug`
verb's `[Init]` summary (core/DebugLogSetup.lua `initSummary`) appends `rejected: <names>` when
non-empty. Front-gate with `C_EventUtils.IsEventValid` where present. Test: kit `M.__badEvents =
{ ADDON_RESTRICTION_STATE_CHANGED = true }` → every other lifecycle event still registers and the
reject is recorded. `-- red under: a bare RegisterEvent loop`.

### C-06 — Nothing built while stood down (F-006)

`modules/ContainerManager.lua` — `CM.Init` returns after `EnsureAuraContainer` + `TimedSpells.Sync`
when `NS.IsStoodDown()`; `CM.Announce` skips `CM.Sync` when stood down. `core/LifecycleSetup.lua`
`standUp` calls `NS.ContainerManager.Sync()` before `ApplyVisibility`. Fix the `:568-569` doc to match.
Test: login-disabled → `spyCreate(mocks, "AuraMasterAnchor")` counts 0; enable → instances exist and
draw. `red under: CM.Init building before the latch check`.

### C-07 — Edge-triggered degraded Lifecycle stub (F-007)

`core/LifecycleSetup.lua:120-131` — keep `local down = false`; `SyncEnabled` computes `want = not
enabledStored()` and calls `standDown`/`standUp` only when `want ~= down`. Test in the degraded suite
(`tests/degraded_env.lua` load path): two `SyncEnabled` calls with no change arm one timer, not two.

### C-08 — Trim stubs to what a degraded build needs (F-008)

- `settings/Slash.lua` stub `DisabledLine`: keep the refusal (slash-commands-§2's SHOULD still applies on a
  degraded build — `/am new` would otherwise create a container behind the latch), but make the copy
  **falsifiable**: a case in `tests/test_surface_parity.lua` that loads the addon once with and once
  without `LibKa0s-Slash-1.0` and asserts the two `DisabledLine()` strings are identical.
  `-- red under: the library rewording its line`. The copy stays; its drift now goes red.
- `settings/OptionsSetup.lua` stub: keep `MasterControls` (load-bearing: `/am enable|disable`); replace
  `FontGroup` / `BorderGroup` / `BarGroup` / `ColorPair` with `function() return {} end` if and only if
  `NS.ValidateSchema` and the degraded suite stay green — otherwise keep them and record why in the
  stub comment.
- `core/PoolSetup.lua`: keep (a pool-less preview leaks); tighten the comment to say that is the reason.
Standards: `library-stack-§7`, anti-pattern #56 — the stub must answer every member called and must not
copy formatting.

### C-09 — Test mode row honors the disabled gate (F-009)

`settings/General.lua:107-114` — `row.set = function(v) if v and NS.IsDisabled() then
NS.Print(NS.Slash.DisabledLine()) return end NS.Preview.SetTestMode(v) end`. Turning it **off** stays
allowed. Test in `test_disabled.lua`: panel set of `state.testMode` true while disabled leaves
`NS.State.testMode` false and prints the one refusal line.

### C-10 — Lint config (F-010)

`.luacheckrc:14-15` — remove `GameTooltip`, `C_Spell`, `GetAddOnMetadata`, `GetSpellInfo`. Re-run
`luacheck .` (must stay 0/0). If `tests/test_lintconfig.lua` pins the list, update it in the same
commit.

### C-11 — Comments (F-011)

`core/Database.lua:478-538` — split the fused block into three doc comments placed above
`liftCategoryWhitelist`, `categoriesDecided`, `filterableCategories`; drop "CORRECTION (review…)" /
"fix round N" framing, keeping the WHY. `modules/Container.lua:414-416` — re-wrap. Comment-only.

### C-12 — Docs (F-012)

`docs/performance.md:51` `:98` → `:115`; `:55` `772-780` → `774-784`. `README.md:156` — reword the 0.1.0
row (bars, icons or text; weapon enchants as a buff category; test mode). The README row is a history
line: correct it only to fix the inaccuracy, don't rewrite history.

### C-13 — De-duplicate (F-013, F-014)

- One `NS.EnabledStored()` in `core/LifecycleSetup.lua`, consumed by `settings/Slash.lua:109`.
- `CM.Rename`, `Database.Merge`, `NS.IsSection`: keep (test seams are documented), but rename to the
  `__` prefix convention the file already uses for seams (`CM.__retiring`) so production readers can
  tell. Update the callers in tests in the same commit.
- `core/Compat.lua:314`: drop the removed `GetMouseFocus` fallback.
- A shared `NS.FramePicker.PickFor(id, onDone)` used by both `runPick` and `pickFrame`; unname the
  overlay (`CreateFrame("Frame", nil, UIParent)`).

## Standards conformance (per change)

| Change | Rule(s) that shaped it | Rejected option and why |
|---|---|---|
| C-01 | events-frames-taint-§2 (no anchor work under lockdown — dormant revive stays parked until an out-of-combat apply) | Unnamed anchors alone: leaves the leak |
| C-02 | events-frames-taint-§1 carve-out (held on module, hand-unregistered, reused); slash-commands-§7 (stand-down reaches it) | A general private-frame helper — explicitly outside the carve-out |
| C-03 | performance-§11, anti-pattern #52, automated-tests-§3 | A `doTheRest` helper; a gate on commits (automated-tests: release-only) |
| C-04 | library-stack-§5/§7, anti-patterns #47 and #55 | Patching `libs/`; polishing the local fork |
| C-05 | events-frames-taint-§1 (isolated registration, discoverable rejects) | — |
| C-06 | slash-commands-§7 (nothing built/armed while down); performance-§6 (stand-up rebuilds from current state) | Hiding the built anchors — keeps the work, only masks it |
| C-07 | library-stack-§7 (stub mirrors the member's contract) | — |
| C-08 | library-stack-§7, anti-pattern #56 | Deleting the Pool stub — degraded preview would leak |
| C-09 | slash-commands-§2/§7, launcher-§2 (one refusal line from the dispatcher) | A host-worded refusal |
| C-10 | lint | — |
| C-11/C-12 | documentation | Editing committed review/audit bundles — frozen |
| C-13 | architecture | — |

No change here introduces a new deviation. Out of scope and not proposed: the four `layout-§1`
over-cap files already carry deviation rows and issues #16–#19 (`docs/ARCHITECTURE.md`); that is the
audit's lane.

## Regression pressure

C-01, C-02, C-05, C-06, C-07 and C-09 add cases → `docs/test-cases.md` (regenerated by
`lua tests/run.lua --list`) and the README `[tests]` badge move **in the same commit** as each. C-02
changes the offline scenario list → `docs/performance.md`'s scenario table moves with it.
