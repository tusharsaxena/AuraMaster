# AuraMaster — in-client smoke tests (review 2026-10-07)

Only what needs the game client goes here. Headless suites ran in `01_FINDINGS.md`'s measurement block. After the changes land, re-run the gate once: `lua tests/run.lua` and `luacheck .` (0/0).

## Pre-flight
- Retail, `## Interface: 120100` (12.1.x). Use a character with at least one weapon enchant available, a target dummy, and a party or a dungeon for combat.
- `/console scriptErrors 1`. BugSack is optional.
- Load the addon from the `GIT/AuraMaster` symlink, never from a side worktree.
- Load all 11 Ka0s addons for the cross-addon section.

## Per-change tests

### C-01 — `logCandidates` refactor (F-001)
- **Setup:** two containers, A and B, unlocked. `/am debug on`.
- **Steps:** 1. Drag A by its strip near B and drop it without attaching. 2. Drag A again and attach it to B. 3. `/am lock`.
- **Expected:** each drag start and drop writes one `[Anchor] container <A>: start: own l,b,r,t; targets <B> l,b,r,t` line and a `drop <outcome>` line, in the same shape as before the change. No Lua error.
- **Pass/Fail:** pass if both lines appear with an `own` rect and a `targets` list, and no error popup appears.

### C-02 — migration step bodies moved to `core/Database_Migrations.lua` (F-002)
- **Setup:** back up `WTF/Account/<acct>/SavedVariables/AuraMaster.lua`. Use an old SavedVariables with `schemaVersion` ≤ 11 and a container whose `filter.categories.softCC = "hide"`. A copy from before 2026-10-04 works, or hand-set `schemaVersion = 11` with that key.
- **Steps:** 1. Log in. 2. `/am debug on`, then `/reload`. 3. Open the console and read the `[Migrate]` lines. 4. `/logout`, then read the SavedVariables file.
- **Expected:** after step 1, `schemaVersion = 12` and the container has `ccRoot = "hide"` and `ccSnare = "hide"` with no `softCC`. No "migration to schema v… failed" chat line. A fresh profile still gets its starter containers.
- **Pass/Fail:** pass if the stored shape matches and no failure line printed.

### C-03 — drag suite split (F-004)
- Headless only. Nothing to do in game.

### C-04 — numeric names (F-005)
- **Setup:** three or more containers. Rename the one with id 1 to `3`.
- **Steps:** 1. `/am select 3`. 2. `/am select #3`. 3. Rename another container to `42` (no id 42 exists), then `/am select 42`. 4. `/am delete 3`.
- **Expected:** step 1 prints the ambiguity line naming `#3` and selects nothing. Step 2 selects container #3. Step 3 selects the container named "42". Step 4 refuses with the same ambiguity line and deletes nothing (`/am containers` count unchanged).
- **Pass/Fail:** pass if all four outcomes hold.

### C-05 — picker label case (F-006)
- **Steps:** open `/am config` → Containers and open the container picker.
- **Expected:** entries read `<name>  (<Unit> <Type>, <Style>)` in the translated case, with no Lua error.
- **Pass/Fail:** pass if the picker renders and selection still works.

### C-06 — help wording (F-007)
- **Steps:** `/am help`.
- **Expected:** the `debug` row reads "Toggle the debug console — on/off enable/disable logging", using an em dash like every other row.
- **Pass/Fail:** pass on visual match.

### Upstream F-003 (after the re-vendor)
- Headless only. `docs/test-cases.md` Total equals the badge's `<Y>`, and a `Skipped` row lists 1.

## Regression suite
1. `/reload` cleanly. Log in, and confirm ADDON_LOADED → PLAYER_LOGIN → PLAYER_ENTERING_WORLD with no errors and the starter or stored containers drawn.
2. Enter and leave combat on a dummy with every container visible. No `Interface action failed because of an AddOn`.
3. `/am disable`, then fight. Nothing is drawn and no chat lines appear. `/am enable` brings back every container from current settings.
4. Profile switch, copy and reset (Profiles page). Containers rebuild with no errors.
5. Open the settings panel and toggle each Containers section once (Filters, Layout, Bars, Icons, Text).
6. `/am test on`, `/am test off`, `/am redraw full`.

## Cross-addon (all 11 loaded)
Type each root (`/at /am /bl /cm /kcd /lh /mm /pm /pfe /pc /wg`) and confirm each reaches its own addon. Open Settings → AddOns and confirm each addon appears exactly once, and each multi-page addon's pages appear once each.

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-01 | | | |
| C-02 | | | |
| C-03 | n/a (headless) | | |
| C-04 | | | |
| C-05 | | | |
| C-06 | | | |
| F-003 re-vendor | n/a (headless) | | |
| Regression 1–6 | | | |
| Cross-addon | | | |
