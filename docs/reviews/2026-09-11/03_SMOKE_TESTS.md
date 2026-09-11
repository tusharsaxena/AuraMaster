# 03 — In-client smoke tests

Only what needs a live client is here. The headless suites (luacheck, `tests/run.lua`, `tests/perf.lua`, lizard) ran in Step 0. After the changes land, re-run them once as pre-flight: `lua tests/run.lua && luacheck .`, both green, 0/0.

## Pre-flight

1. Retail 12.1.x client (`## Interface: 120100`), with the addon copied from the working tree. Enable **only** Ka0s Aura Master.
2. `/console scriptErrors 1`, then `/reload`. Optionally keep `/etrace` open for `ADDON_ACTION_BLOCKED` and `ADDON_ACTION_FORBIDDEN`.
3. Character: any class with a weapon-enchant source (a Shaman, or any class with a weapon oil). Stand at a training dummy (e.g. Valdrakken or Dornogal dummies).
4. SavedVariables:
   - **Fresh profile** for S-01 to S-04: delete `WTF/Account/<ACCOUNT>/SavedVariables/AuraMaster.lua` before logging in.
   - **Keep** it for the regression suite.

## Per-change tests

### S-01 — C-01: enchant options reach the engine
- **Setup:** a fresh profile. Apply a temporary weapon enchant (oil or imbue) and have at least one permanent enchant if possible. Note that the seeded "Player buffs" container shows enchants.
- **Steps:**
  1. `/am select Player buffs`, then `/am set container.filter.hidePermanentEnchants false`.
  2. `/am set container.filter.hidePermanentEnchants true`.
  3. `/am set container.filter.sortDirection reverse`, with two enchants that have different remaining durations.
- **Expected:**
  - Step 1: permanent enchants appear **immediately**, with no `/reload`.
  - Step 2: they disappear again.
  - Step 3: the enchant order flips.
  - No Lua error.
- **Pass:** each change is visible within one second, without a `/reload`.

### S-02 — C-02: deleting in combat does not taint
- **Setup:** 4 containers (`/am new target debuffs icons`), with the new one selected.
- **Steps:**
  1. Attack the dummy.
  2. While in combat, `/am delete 4`.
  3. Still in combat, click an action-bar ability and target something.
  4. Leave combat.
- **Expected:**
  - No red *"Interface action failed because of an AddOn"*, and no `ADDON_ACTION_BLOCKED` in `/etrace`.
  - The deleted container's auras stop drawing at once (engine disabled).
  - After combat, `/am containers` lists 3 containers.
- **Pass:** zero blocked-action lines, and the container is gone after combat.
- **Before the fix**, run the same steps to establish whether F-002 is Critical. If `ADDON_ACTION_BLOCKED` fires, record that in the sign-off table.

### S-03 — C-03: session toggles apply nothing and say nothing false
- **Steps:**
  1. `/am debug on`, then tick and untick General → Debug console. Read the console.
  2. Enter combat, then `/am preview on`, then `/am preview off`.
  3. Inside a Mythic+ key or an encounter but **out of combat**, change `/am set container.bars.width 250`.
- **Expected:**
  - Step 1: no `[Apply] applied 3 container(s)` line follows the console toggle.
  - Step 2: only *"Preview on — …"* and *"Preview off"*, with **no** *"…will apply when combat ends."*
  - Step 3: the notice names the encounter/key wording, not combat, and the width applies when the restriction lifts.
- **Pass:** all three hold.

### S-04 — C-04: the picker survives forbidden frames
- **Steps:**
  1. Inside a dungeon with nameplates on, `/am pick`.
  2. Sweep the cursor across enemy nameplates, the minimap and the chat frame for 5 seconds.
  3. Right-click to cancel.
- **Expected:** no Lua error. The label shows *"Point at a named frame…"* over forbidden or unnamed frames.
- **Pass:** zero errors.

### S-05 — C-05: a corrupt container key loads
- **Steps:**
  1. Log out. In `AuraMaster.lua` SavedVariables, under the profile's `containers`, add `["abc"] = { ["name"] = "junk" },`.
  2. Log in.
- **Expected:** the addon loads, `/am containers` lists the real containers only, and `/am debug on` then `/reload` shows a `[Migrate] dropped container key abc` line.
- **Pass:** no initialization error.

### S-06 — C-06: rename uniqueness and the deviation register
- **Steps:**
  1. Containers page: rename container 2 to `Player buffs`, then press Enter.
  2. `/am set container.name Player buffs` on container 3.
- **Expected:** the names become `Player buffs (2)` and `Player buffs (3)`. `docs/ARCHITECTURE.md` `## Documented deviations` holds the ratified row (or D-1b is implemented).
- **Pass:** names are unique.

### S-07 — C-07: `timedScan` appears in a capture
- **Setup:** a container with Duration = "Only auras without a duration".
- **Steps:** follow the capture protocol:
  1. `/am perf start smoke`.
  2. `/am perf measure a`, fight the dummy for 60 s out of an instance.
  3. Stop, then `/am perf measure b`, fight 60 s.
  4. `/am perf finish`, then `/am perf report`.
  5. Record it via `/wow-addon:perf-analysis` as `docs/perf-analysis/<stamp>/`.
- **Expected:** the report lists `timedScan` (calls > 0 in arm A, absent in arm B). Read bucket figures, not the frame-time delta, which is unresolved below about 0.5 ms/frame.
- **Pass:** the bucket is present and the capture is committed.

### S-08 — C-08: shared formatter and curve render correctly
- **Setup:** two bar containers with Time format = Detailed, and Recolor the time when running out = on (threshold 5 s).
- **Steps:** apply several short buffs to yourself so both containers show running auras.
- **Expected:** each bar's countdown text is correct and independent, turning red under 5 s on each bar separately.
- **Pass:** no bar shows another bar's time or color. If one does, the shared cache must fall back to the per-container cache, as noted in `02`.

### S-09 — C-09: text
- **Steps:** `/am delete nosuch`, `/am new sparkles`, `/am resetall` (accept), and General → Reset all settings (accept).
- **Expected:** whole sentences, and both reset paths print the **same** line.
- **Pass:** identical reset text.

### S-10 — C-10: anchors
- **Steps:**
  1. Drag a container, `/reload`, then switch profile and back.
  2. Set a container to attach to a frame of a load-on-demand addon (e.g. `Blizzard_ProfessionsFrame`'s frame), then enter combat and open that UI from a keybind if possible. Leave combat.
- **Expected:** positions come only from the profile, not from the layout cache. The pending anchor resolves on leaving combat.
- **Pass:** both hold.

## Regression suite

1. `/reload` is clean: no errors and three containers drawn.
2. Fresh SavedVariables → login: three starter containers are seeded, locked.
3. The ADDON_LOADED → PLAYER_LOGIN → PLAYER_ENTERING_WORLD sequence produces no errors (`/etrace` filtered to AuraMaster).
4. Combat enter and leave with every container visible (visibility = Always, then In combat): containers enable and disable on the transition.
5. `/am unlock` → drag → `/am lock` → `/reload`: the position persists.
6. Profiles page: create `Raid`, switch, copy from `Default`, reset. Out of combat, no errors, and the containers rebuild.
7. Open every settings page (General, Containers, Filters, Layout, Bars, Icons, Profiles) and toggle every checkbox once. No error popup.
8. `/am config` in combat prints the gray refusal line.
9. Target, focus and pet swaps update the target, focus and pet containers.

## Taint-specific

- Repeat S-02 with a **profile switch** (Profiles page opened before combat, switch profile during combat) and with `/am resetall` in combat. Expect no blocked action.
- Esc → Options → AddOns → Aura Master opens the panel, and so does `/am config`.

## Localization sanity

- Switch the client to deDE. No deDE file ships, so strings render in English through the metatable fallback.
- Run S-09 and S-03. Expect no `%s` left unformatted and no Lua error from a format call.

## Performance spot-checks

- S-07 is the capture of record. For C-08, also compare `/run collectgarbage("count")` before and after a restyle (change bar width 10 times). Expect a smaller growth than before the change. Record both numbers in the Notes column.
- The Blizzard CPU profiler attributes shared frames loosely, so do not read its figure as the addon's cost.

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| S-01 (C-01) | | | |
| S-02 (C-02) | | | F-002 pre-fix result: blocked? Y/N |
| S-03 (C-03) | | | |
| S-04 (C-04) | | | |
| S-05 (C-05) | | | |
| S-06 (C-06) | | | D-1 choice: a / b |
| S-07 (C-07) | | | capture bundle stamp: |
| S-08 (C-08) | | | shared cache OK? Y/N |
| S-09 (C-09) | | | |
| S-10 (C-10) | | | |
| Regression 1–9 | | | |
| Taint | | | |
| Locale | | | |
