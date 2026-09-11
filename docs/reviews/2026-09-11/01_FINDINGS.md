# 01 — Findings (requirements) — Ka0s Aura Master v0.1.0

**Verdict: minor issues** — no Critical findings. There are two High functional/taint bugs on documented paths, and a Medium tail that is mostly design discipline and measurement evidence. The code is well structured, and every out-of-game suite is green.

Reviewed: branch `fix/review-audit-2026-09-11` at `83c559e` (clean tree). Standard resolved: **Ka0s WoW Addon Standard v2.42.0 (2026-09-10)**, the index plus all 27 section files fetched with `curl` (the standards cross-check ran).

## Measurement run (Step 0 — measured today, 2026-09-11)

All commands were run from the repo root. Output went to the session scratch directory (`$SCRATCH` = `/tmp/claude-1000/…/scratchpad`) and nothing was written into the repo. `git status --porcelain` was empty after every step.

| Suite | Result | Command and scope |
|---|---|---|
| luacheck | **pass**: 0 warnings / 0 errors in 62 files | `luacheck .`. Scope excludes `libs/`, `tests/_kit/`, `docs/audits/`, `docs/reviews/`, `docs/automated-tests/` and `_dev/` (`.luacheckrc` `exclude_files`). |
| Headless suite | **pass**: 154 passed, 0 failed, 0 skipped, 154 total | `lua5.1 tests/run.lua` (19 suites, including the kit's `test_eol`). |
| Fresh `--list` inventory | **pass**: 243 lines, Total 154 | `lua5.1 tests/run.lua --list > $SCRATCH/test-cases.md`, then `diff` against `docs/test-cases.md`: **identical** (byte-for-byte and EOL-insensitive). README badge `Tests-154/154` (`README.md:6`) agrees. |
| Offline perf runner | **ran**: exit 0, 7 scenarios, 0 assertion failures | `lua5.1 tests/perf.lua`. Bytes/iter: compile 675.2 · applyPass 15243.3 (22.0 api/iter) · restyle **−1920.1** · visibilityPass 625.2 (3.0 api) · unitSwap 96.4 (1.0 api) · probeOverheadOff 721.6 · probeOverheadOn 722.1. |
| Complexity | **pass**: 6820 NLOC, 676 functions, avg CCN 2.8, **max CCN 15**, 0 warnings | `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" . > $SCRATCH/complexity.txt` (lizard 1.24.0). Functions at CCN 15, the limit: `Preview.Offset` (modules/Preview.lua:23), `Bars.FillPreview` (modules/Style_Bars.lua:211), `TS.Scan` (modules/TimedSpells.lua:42). |
| `make test` | **skipped**: no root `Makefile` | — |
| Vendor sync | **pass**: no drift | `diff -rq libs/LibKa0s/ ../LibKa0s/LibKa0s/` and `diff -rq tests/_kit/ ../LibKa0s/testkit/` both empty. The sibling checkout is at tag `v1.29.0` (`git describe --tags`), which matches the CLAUDE.md provenance line. |
| Scratch probe (not a suite) | 6 behaviours reproduced | `lua5.1 $SCRATCH/probe.lua`. It loads fresh environments through `tests/fresh_env.lua` and asserts nothing. Its outputs P1–P6 are cited below. |

**Committed artifacts compared with the fresh runs:**

- `docs/test-cases.md`: matches the fresh inventory exactly.
- `docs/automated-tests/RESULTS.md` and bundle `20260911-141809/complexity.txt`: every figure matches (lint 0/0/62, 154/0/154, NLOC 6820, 676 functions, max CCN 15, empty watch list). The bundle's `manifest.json` records `"git": { "sha": "HEAD", "branch": "HEAD", "dirty": true }`, meaning the run predates the first commit (its ANALYSIS.md says so). Today's run confirms its numbers against `83c559e`.
- Bundle `perf.txt` against today's run: allocation figures are identical except compile (674.7 committed / 675.2 fresh) and restyle (−1914.9 / −1920.1). A deterministic quantity should not move, so this movement is itself evidence for F-009.
- `docs/performance.md` embeds no figures. 3 of its 9 line citations are stale (F-014).
- `docs/perf-analysis/` holds no capture yet (README index empty), so no in-game bucket figures exist to cite. In-client checks are in `03_SMOKE_TESTS.md`.

**Sweep, conventions detected:**
- `NS.PREFIX` cyan `[AM]` tag, with `NS.Print` reclaimed from AceConsole.
- `NS.COMMANDS` positional triples dispatched by LibKa0s-Slash.
- Single write seam `NS.SetByPath` (settings/Schema.lua:271) with a flat-row `NS.Schema`.
- No `docs/CLAUDE_SECRET_VALUES.md`; `core/Secrets.lua` plays that role.
- `.gitattributes` carries `* text=auto eol=crlf`, `*.sh text eol=lf` and the binary list; `test_eol` passes, so the working tree agrees.
- Media: nothing on the user-facing windows draws its own mark where the catalog has one; no close control bypasses `NS.MakeCloseButton`.
- LibKa0s v1.29.0 is vendored with eight majors wired: Media, Env, Core, Pool, Perf, DebugLog, Slash and Options. Their setup files are `core/{Media,Env,Core,Pool,Perf,DebugLog}Setup.lua`, `settings/Slash.lua` and `settings/OptionsSetup.lua`.
- The vendored test kit is at `tests/_kit/`.
- Evidence present: the headless gate plus inventory, `tests/perf.lua` plus `docs/performance.md`, an empty `docs/perf-analysis/` store, and `docs/automated-tests/` with one bundle.

The degradation stubs were diffed against their call sites and every member called is answered (also pinned by `test_surface_parity`). Declared buckets were cross-checked against brackets: 5 declared, 5 reached, and `applyContainer` passes `"applyPass"` as its parent (modules/Container.lua:273).

---

## High

### F-001 — Enchant options changed on a live container never reach the engine `[bug]`
- **Where:**
  - modules/Container.lua:165: `callEngine(engine, "SetItemEnchantmentSortMethod", Compat.EnchantSortByDuration(),`
  - modules/Container.lua:170: `initializeFrame = init, hidePermanent = plan.enchants.hidePermanent,`
  - Both appear only in `Build`. `Update` (modules/Container.lua:206–209) re-sends only `SetItemEnchantmentLayout`.
  - modules/FilterCompiler.lua:349: `return ("%d:%s"):format(#plan.groups, plan.enchants and "e" or "-")`. The structure key ignores both options, so these changes never force a rebuild.
- **Problem:** Toggling "Hide enchants without a duration" (settings/Filters.lua:50) or changing the sort "Direction" goes through the in-place `Update`. `Update` never passes the new `hidePermanent` or the enchant sort direction to the engine.
- **Impact:** The setting looks saved but the display does not change until a `/reload` or an unrelated change of shape.
- **Reachability:** Any player on a default profile who changes either option on the seeded "Player buffs" container, which ships `includeEnchants = true` (defaults/Profile.lua:190: `filter = { castBy = "any", includeEnchants = true },`). Also every weapon-enchant container.
- **Evidence:** Probe P3. After `hidePermanentEnchants = false` the engine received `SetFlowLayout*…, SetAuraGroupLayout, SetItemEnchantmentLayout, SetEnabled`, with no `AddItemEnchantment` or other enchant option, and the same engine was kept. After `sortDirection = reverse` it received `SetAuraGroupSortMethod` but no `SetItemEnchantmentSortMethod`.
- **Coverage:** The inventory has no case over this path. `hidePermanent` is asserted only at compiler level (tests/test_filtercompiler.lua:183), and "container: a filter change is applied in place" covers `castBy` only.

### F-002 — Registry teardown hides aura-engine ancestry during combat `[taint]`
- **Where:**
  - `CM.Delete` → `CM.Announce()` (modules/ContainerManager.lua:213) → `CM.Sync` → `inst:Destroy()` (modules/ContainerManager.lua:53).
  - `Destroy` → `Retire` runs `engine:Hide()` (modules/Container.lua:126) and `self.anchor:Hide()` (modules/Container.lua:333).
  - The same chain runs from `NS.OnProfileChanged` (core/AuraMaster.lua:111) on a profile switch, copy or reset.
- **Problem:** `MustDefer` guards applies, but nothing guards teardown. This contradicts the addon's own invariant (modules/Container.lua:305: *"aura button's ancestry must not be shown or hidden"*) and the ARCHITECTURE Taint Notes (*"No structural work … under combat lockdown"*).
- **Impact:** `Hide()` and `ClearAllPoints()` run on the anchor that parents a Blizzard aura container while combat lockdown is active. If the engine's buttons are protected, the client blocks the action (*"Interface action failed because of an AddOn"*) and taints the ancestry.
- **Reachability:** Any player who, in combat:
  - types `/am delete` (settings/Slash.lua:168) or `/am resetall`;
  - confirms the panel's Delete popup (settings/Containers.lua:91: `if data and CM.Delete(data) then H.RefreshAllPanels() end`); or
  - switches, copies or resets a profile from a panel opened before combat.

  These are documented commands in an ordinary session.
- **Evidence:** Probe P4. With `__lockdown = true`, `/am delete 2` called `Hide()` on `engine,anchor`.
- **Uncertainty:** Whether 12.1 treats the AuraContainer ancestry as protected is **unverified in-client**. If the smoke test shows `ADDON_ACTION_BLOCKED`, re-grade this Critical.
- **Coverage:** tests/test_container.lua:152 (*"deleting a container disables its engine and hides its anchor"*) pins the Hide and never sets lockdown, so the suite asserts the behaviour that is the bug in combat.

## Medium

### F-003 — Session-only rows re-apply every container, and in combat print a false deferral notice `[ux] [perf]`
- **Where:**
  - settings/Schema.lua:293 `if row.sessionOnly then` → settings/Schema.lua:307 `announceWrite(row.page, id, path, value)` with `id == nil`.
  - settings/Schema.lua:256 sends `CONFIG_CHANGED` with `containerId = nil`.
  - modules/ContainerManager.lua:303 `CM.RequestApply(id)` then treats `nil` as "re-apply all".
- **Problem:** The debug-console and preview rows have no stored state, yet each toggle queues a full apply of every container. settings/General.lua:57 (*"Explicitly nothing: toggling a window re-applies no container."*) is false.
- **Impact:**
  - Out of combat, every toggle costs a full apply pass (compile, place, update and restyle of every engine button).
  - In combat, `/am preview` takes effect immediately but chat then says *"Aura Master settings changes will apply when combat ends."* (modules/ContainerManager.lua:94). README.md:50 promises that notice only for real changes.
- **Reachability:** Any player who types `/am preview`, `/am lock` or `/am unlock`, or ticks the Preview or Debug console box. Every time.
- **Evidence:** Probe P1: 3 of 3 containers re-applied after `state.debugConsole` and again after `state.preview`. Probe P2: under lockdown, `/am preview on` printed the preview line followed by the false deferral notice.

### F-004 — Frame picker calls methods on a forbidden frame before asking whether it is forbidden `[bug]`
- **Where:**
  - modules/FramePicker.lua:30 `local name = f.GetName and f:GetName()` runs before modules/FramePicker.lua:32 `if not (f.IsForbidden and f:IsForbidden()) then return f, name end`.
  - modules/FramePicker.lua:34 `f = f.GetParent and f:GetParent() or nil` is called on the forbidden frame too.
  - The walk runs every frame from `onUpdate` (modules/FramePicker.lua:62).
- **Problem:** On a forbidden frame, `GetName` and `GetParent` raise before `IsForbidden` is ever consulted.
- **Impact:** A Lua error on every frame while the cursor rests on a forbidden frame during a pick.
- **Reachability:** A player using *Pick a frame…* or `/am pick` who hovers a forbidden frame. Whether `GetMouseFoci` returns forbidden frames on 12.1 (e.g. instance nameplates) is **unverified**, so this is not graded higher.
- **Evidence:** Probe P6: a forbidden stub whose `GetName` raises made `NamedAncestor` raise. The existing picker cases plant only non-forbidden frames.

### F-005 — A non-numeric container key in SavedVariables aborts initialization `[bug]`
- **Where:** core/Database.lua:127 `if type(k) ~= "number" and tonumber(k) then renames[#renames + 1] = k end` normalizes numeric strings only. A key like `"abc"` survives to core/Database.lua:139 `if id > maxId then maxId = id end`.
- **Problem:** `PrepareProfile` assumes every surviving key is a number and compares it with `>`.
- **Impact:** *"attempt to compare number with string"* inside `OnInitialize`. The addon loads with no database.
- **Reachability:** Only a player whose SavedVariables hold a non-numeric container key (a hand edit or an external tool). Not reachable from the UI. The defect kind is load failure, capped Medium by reachability.
- **Evidence:** Probe P5: `core/Database.lua:139: attempt to compare number with string`.

### F-006 — Registry operations write container settings around the single write seam `[design]`
- **Where:**
  - modules/ContainerManager.lua:208 `c.attach.mode = "screen"` (Delete).
  - modules/ContainerManager.lua:279 `c.position = NS.Database.DeepCopy(template)` (ResetPositions).
  - modules/ContainerManager.lua:261 `if src[key] ~= nil then dst[key] = NS.Database.DeepCopy(src[key]) end` and modules/ContainerManager.lua:264 `dst.unit, dst.auraType, dst.style = src.unit, src.auraType, src.style` (CopyFrom).
  - settings/General.lua:44 `if v and NS.State then NS.State.preview = false end`. This writes the `state.preview` row's storage without calling that row's `set`.
- **Problem:** architecture-§5 says every mutation **MUST** route through one helper. These writes skip `NS.SetByPath`, so they produce no `[Set]` debug line, no row `onChange`, and no `CONFIG_CHANGED`. The code comments justify it (*"A wholesale replacement, not a setting"*), but `docs/ARCHITECTURE.md` → `## Documented deviations` (line 255) says *None*.
- **Impact:** An unratified deviation (CLAUDE.md requires a register row). A change made this way is invisible in a debug trace.
- **Reachability:** Every Delete, Reset position, Copy settings and `/am lock`. No user-visible failure today; this is maintainability and compliance.

### F-007 — `CM.Rename` is dead in production, so names are not unique on the real rename paths `[design] [tests]`
- **Where:** modules/ContainerManager.lua:225 `return NS.SetByPath("container.name", CM.UniqueName(name, id), id)`. Its only callers are tests (tests/test_containermanager.lua:55 `assertTrue(NS.ContainerManager.Rename(1, "  Buffs  "))`).
- **Problem:** The panel's name row (settings/Containers.lua:30–35, `onChange = function() CM.NotifyRenamed() end,`) and `/am set container.name` write the raw name with no `UniqueName`. `/am select|delete <name>` resolves the first match (settings/Slash.lua:90).
- **Impact:** Duplicate names, and a name-addressed delete may remove the wrong container. The case "manager: Rename trims, refuses an empty name and keeps names unique" reads as coverage of a rule nothing enforces.
- **Reachability:** A player who renames a container, in the panel or by CLI, to a name already in use.

### F-008 — The zero-overhead perf scenario compares off with on, not off with absent `[perf] [tests]`
- **Where:** tests/perf.lua:134 (`probeOverheadOff`), tests/perf.lua:136 (`probeOverheadOn`), and tests/perf.lua:139 `assert_(off.bytesPerIter <= on.bytesPerIter + 1, "a dormant bracket allocated more than an armed one")`.
- **Problem:** performance-§9 **MUST** pin that the hottest bracketed path with capture off allocates no more than *the same path with the instrumentation absent*. This scenario compares capture-off with capture-on instead.
- **Impact:** The "a dormant bracket is free" claim (performance-§2, anti-pattern #43) is **unverified**. Today's run gives 721.6 bytes/iter off against 722.1 on, and neither figure says what the brackets themselves cost.
- **Reachability:** Evidence only. The brackets themselves are written in the mandated gated form at all five sites.

### F-009 — Offline allocation figures measure the mock recorder and GC timing, not the addon `[perf] [tests]`
- **Where:**
  - tests/perf.lua:72 collects before and after, but the collector runs freely inside the measured loop (tests/perf.lua:71–86).
  - The engine mock allocates a table per call (tests/wow_mock.lua:49 `self.__calls[#self.__calls + 1] = { name, ... }`).
- **Problem:** The numbers include allocations made by the mock and by garbage-collector timing, not only the addon's own.
- **Impact:**
  - `restyle` reports **−1920.1 bytes/iter** (fresh) and −1914.9 (committed), which is impossible for a real allocation count.
  - `unitSwap`'s 96.4 bytes/iter is one recorded engine call. The addon's own allocation on that path cannot be read.
  - "Deterministic" figures move between runs (compile 674.7 → 675.2).
- **Reachability:** Evidence only. Every perf claim resting on these numbers is unverified.

### F-010 — The one aura-event Lua path has no perf bucket `[perf]`
- **Where:** modules/TimedSpells.lua:96 `f:RegisterUnitEvent("UNIT_AURA", "player", "pet")` → modules/TimedSpells.lua:80 `frame:SetScript("OnEvent", function() scheduleScan() end)` → modules/TimedSpells.lua:72 `C_Timer.After(0.5, TS.Scan)`.
- **Problem:** No bracket, and no declared bucket. docs/performance.md:11 says *"The addon has **no per-aura Lua path**"*.
- **Impact:** A `/am perf` capture cannot attribute the scan (2 units × up to 40 `GetAuraDataByIndex` calls, every 0.5 s while auras change out of combat).
- **Reachability:** Players with any "Only auras without a duration" container.
- **Complexity note:** `TS.Scan` is already at CCN 15 (fresh lizard). An inline bracket inside it would push it to about 17, over the release gate.

### F-011 — Style objects are allocated per button on every dress `[perf]`
- **Where:**
  - modules/Style.lua:159 `local formatter = NS.Compat.CreateSecondsFormatter(s.timeFormat)`.
  - modules/Style.lua:162 `local tc = NS.Compat.ExpiringTextColor(...)` (a new color curve).
  - modules/Style_Bars.lua:183 `customDispelColorMap = Style.DispelColorMap(b.dispelColors),` (new `CreateColor` objects).
- **Problem:** All three are built for every button on every `Style.Element` call.
- **Impact:** N client-side objects per restyle and per engine button creation. `initializeFrame` runs as the engine creates buttons, including in combat.
- **Reachability:** Every player with visible containers.
- **Magnitude:** **Unverified.** The offline mock has no `C_StringUtil` or `C_CurveUtil`, so the `restyle` scenario cannot see this cost.

## Low

### F-012 — The deferral notice blames combat when aura secrecy caused the deferral `[ux]`
- **Where:** modules/ContainerManager.lua:124 `noteDeferred()`, gated on `MustDefer` = `Compat.AurasAreSecret()` (core/Compat.lua:40) or lockdown. The only text is *"…will apply when combat ends."* (modules/ContainerManager.lua:94).
- **Reachability:** A player changing settings out of combat inside a keystone, encounter or PvP match, where secrecy (not combat) holds the apply. The notice is wrong about when the change lands.

### F-013 — CLI sentences are assembled from routed fragments `[locale]`
- **Where:**
  - settings/Slash.lua:153 `return print(L["Unknown word"] .. " '" .. word .. "' — " .. L["try /am new target debuffs icons"])`.
  - settings/Slash.lua:171 `print(L["Deleted"] .. " '" .. tostring(name) .. "'")`.
  - settings/Slash.lua:193 `print(L["Point at a frame and left-click to attach"] .. " '" .. tostring(c.name) .. "'. "`. Also `:134`, `:161` and `:269`.
  - Unrouted user-facing text: modules/ContainerManager.lua:242 `overrides.name = src.name .. " (copy)"` and modules/ContainerManager.lua:186 `("Container " .. id)`.
- **Rule:** localization-§1: route the whole sentence with a format placeholder.
- **Reachability:** Only a future translation. No runtime effect in enUS.

### F-014 — Stale line citations in ARCHITECTURE.md and performance.md `[docs]`
- **Command:** `grep -n -o -E '(core|modules|settings|defaults)/[A-Za-z_]+\.lua:[0-9-]+' docs/ARCHITECTURE.md docs/performance.md`, each hit checked by hand.
- **Scope:** Those two files only; other `docs/*.md` were not swept.
- **Result:** 14 of 36 ARCHITECTURE citations and 3 of 9 performance.md citations point at the wrong line. Examples:
  - `modules/Container.lua:122` should be `:135` (the `CreateFrame("AuraContainer"…)` call).
  - `modules/ContainerManager.lua:291` / `:295` should be `:301` / `:305`.
  - `modules/TimedSpells.lua:84` / `:87` should be `:96` / `:97`.
  - `core/Database.lua:165` should be `:172`.
  - `modules/Container.lua:286-290` should be `:303-310`.
  - `modules/Style.lua:144-146` should be `:149-151`.
  - `modules/FilterCompiler.lua:141` should be `:151-163`.
  - In performance.md, `modules/ContainerManager.lua:103` / `:130` should be `:129` / `:141`, and `modules/Container.lua:230` should be `:247`.
- **Reachability:** Documentation only. The drift likely dates from the pre-release CCN splits recorded in the bundle ANALYSIS.

### F-015 — A named movable anchor may have its position saved by the client's layout cache `[frames]`
- **Where:** modules/Container.lua:39–41 create `AuraMasterAnchor<id>` and call `SetMovable(true)`. modules/Anchors.lua:164 calls `anchor:StartMoving()`. Neither `SetDontSavePosition(true)` nor `SetUserPlaced(false)` is ever called.
- **Reachability:** Any player who drags a container. The addon re-places from stored config on every apply, so the visible effect (a stale layout-cache entry keyed by id across profiles) is **unverified in-client**.

### F-016 — Two fallbacks re-implement library behaviour they say they do not `[design]`
- **Where:**
  - settings/Slash.lua:241 `SlashLib = { FormatRow = function(cmd, desc) return cmd .. " — " .. desc end }` sits under a comment (settings/Slash.lua:237) saying *"NOTHING of the library's rendering is copied here — no row formatter"*.
  - core/PoolSetup.lua:29 `-- BACKWARD, mirroring LibKa0s-Pool-1.0 minor 3: …` re-states library internals, which then go stale.
- **Reachability:** Only a degraded install (`libs/LibKa0s` missing).

### F-017 — Pending frame anchors are never retried after combat `[bug]`
- **Where:** modules/Anchors.lua:102 `if InCombatLockdown() then return end`. This skips `ResolvePending` for an `ADDON_LOADED` that arrives during combat, and nothing retries it on `PLAYER_REGEN_ENABLED`.
- **Reachability:** A frame-attached container whose target addon loads on demand during combat. It stays screen-placed until the next `ADDON_LOADED` or apply.

### F-018 — Two locale keys for one message `[locale] [ux]`
- **Where:** settings/Slash.lua:113 `print(L["All settings reset to defaults"])` against settings/General.lua:101 `print(L["All settings reset to defaults."])`. The same split exists for *"Cannot reset settings — the settings helpers failed to load"* (settings/Slash.lua:115 and settings/General.lua:103, with and without a final period).
- **Reachability:** Any player. The CLI and the panel print slightly different text, and a translator sees two keys.

### F-019 — A drag saves four separate writes `[perf]`
- **Where:** modules/Anchors.lua:128–131 make four `NS.SetByPath` calls, starting with `NS.SetByPath("container.position.point", point, container.id)`.
- **Impact:** Four `CONFIG_CHANGED` messages, four `[Set]` debug lines and four `RefreshScalars` per drag. The applies do coalesce into one.
- **Reachability:** Every drag. The cost is small.

### F-020 — Preview is re-dressed on every visibility pass, with a closure allocated per element `[perf]`
- **Where:** modules/Container.lua:314 `NS.Preview.Show(self)` runs on every `ApplyVisibility`, including combat transitions and master toggles. It releases and re-dresses every placeholder, and modules/Preview.lua:76 `local f = NS.Pool.Acquire(pool, factory(container.anchor))` builds a new factory closure on each Acquire.
- **Reachability:** Only while unlocked or previewing.

### F-021 — Negative assertions carry no `-- red under:` note `[tests]`
- **Where:**
  - tests/test_setups.lua:62 `assertNil(NS2.db.profile.debug)`.
  - tests/test_slash.lua:120 `assertNil(NS2.db.profile.debug)`.
  - tests/test_schema.lua:159 `assertNil(NS2.db.profile.state)`.
- **Problem:** testing-§12 asks for the mutation that turns a negative assertion red. These have plausible mutations but record none. Most other negative cases in the suite do carry the note.
- **Reachability:** The test inventory only. The shipped code is correct.

## Upstream (not fixed in this repo)

### U-001 — The test kit's base mock does not model `AceGUI:Release` `[upstream]` (Low)
- **Owner:** the LibKa0s repo, file `testkit/mock_base.lua`, vendored here as `tests/_kit/mock_base.lua`.
- **Evidence:** `grep -n Release tests/_kit/mock_base.lua` finds only `ReleaseChildren` (line 547). Consumers shim it locally; this addon does so at tests/wow_mock.lua:134 (`function aceGUI:Release(widget)`).
- **Problem:** Every consumer that releases widgets must carry the same shim, and a consumer without it silently records no release.
- **Fix direction:** Fix it in the LibKa0s repo, release it under the library's versioning, then re-vendor the whole `testkit/` folder into `tests/_kit/` as its own commit (and do the same in every consumer). This is **not** a local edit to `tests/_kit/`.
- **Reachability:** Test inventory only.

---

**Fix directions** follow the standard. They are elaborated in `02_PROPOSED_CHANGES.md`, and none steers into a documented anti-pattern. F-006 requires a user decision under CLAUDE.md: either a register row in `## Documented deviations`, or rerouting through the seam.
