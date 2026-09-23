# Ka0s Aura Master — in-client smoke tests (2026-09-23)

Run after the changes in `02_PROPOSED_CHANGES.md` land. Everything headless (lint, the suite, the
offline perf scenarios, lizard) already ran in Step 0 of `01_FINDINGS.md`; re-run it once as
pre-flight and spend this document on what needs a login.

## Pre-flight

1. Headless, from the repo root: `lua tests/run.lua` (all green, count equals the README badge and
   `docs/test-cases.md`) and `luacheck .` (0/0).
2. Retail client, `## Interface: 120100`. Install the addon folder as `Interface\AddOns\AuraMaster`
   with the whole `libs/` tree.
3. `/console scriptErrors 1` (or BugSack), then `/reload`. `/am debug on` to enable session logging;
   `/am debug` to open the console.
4. A character with a pet class (Hunter or Warlock) is best: it exercises `player` + `pet` filtering.
   A target dummy (any capital's training grounds) for combat steps.
5. Have at least **two profiles**: `Default` with 5 containers, and `Small` with 2 (create `Small`
   via Profiles → New, reset it, delete two of its four starters, then add nothing).

## Per-change tests

### C-01 — Destroyed ids are revived, not rebuilt (F-001)
- **Setup:** profiles as in pre-flight; out of combat; `/am debug on`.
- **Steps:**
  1. On `Default`, `/run print(AuraMasterAnchor5 and tostring(AuraMasterAnchor5))` → note the table address.
  2. Profiles → switch to `Small`. Then switch back to `Default`.
  3. Repeat step 1.
  4. Repeat the round trip 5 times, then `/run UpdateAddOnMemoryUsage(); print(GetAddOnMemoryUsage("AuraMaster"))` — note; do 10 more round trips and read again.
- **Expected:** step 3 prints the **same** address as step 1; container 5 draws `Default`'s config
  after the switch back; memory after 15 round trips is within noise of after 5 (no monotonic climb
  per round trip).
- **Pass:** identical address AND correct drawing AND no climb.

### C-02 — `UNIT_AURA` is unit-filtered (F-002)
- **Setup:** make one buff container with Filters → duration *only auras without a duration*.
  Stand in a capital city with many players/nameplates, out of combat.
- **Steps:** `/etrace` → filter `UNIT_AURA`; watch for 20 s. Then `/am perf` workflow (see Performance).
  Buff yourself (e.g. a class self-buff), wait 1 s, check `/am debug` console for `[Timed] learned`.
- **Expected:** the addon still learns timed buffs (the `[Timed] learned N timed spell(s)` debug line
  appears after the self-buff). Toggle **Enable Aura Master** off, buff yourself again: no `[Timed]`
  line. Toggle it on: learning resumes. No Lua error at any step.
- **Pass:** learning works, no error, disable/enable cycle clean.

### C-03 — Split functions (F-003)
- **Setup:** General → Spell Categories → create a user category *"Test Cat"* (buffs), add one spell.
- **Steps:** switch profile to `Small` and back; open Filters → Categories on a buff container;
  rename *Test Cat* to *Test Cat 2*; delete it.
- **Expected:** the row appears in the Spell Categories grid **above** Weapon enchants and
  Uncategorized, follows the rename, disappears on delete; Show all / Hide all still work on each grid.
- **Pass:** identical behavior to before the change, no Lua error.

### C-04b — Tabbed pages (only after the U-1 re-vendor)
- **Steps:** open every page (General, Containers, Filters, Layout, Bars, Icons, Text); click every
  tab; on a container page switch the banner's container and click New container; disable a
  container and open Filters.
- **Expected:** same tabs as before, same order; banner picker + New container on one row; the
  disabled notice shows on a disabled container's pages; in combat, tabs refuse.
- **Pass:** no visual regression; no Lua error.

### C-05 — Isolated event registration (F-005)
- **Steps:** `/reload`; `/am debug` → read the `[Init]` summary.
- **Expected:** no `rejected:` suffix on 12.1 (every name is valid).
- **Pass:** summary clean; target swap still refreshes a target container.

### C-06 — Nothing built while disabled (F-006)
- **Steps:** `/am disable`; `/reload`; `/run print(AuraMasterAnchor1)`; then `/am enable`.
- **Expected:** `nil` before enable; after enable every container draws at its stored position.
- **Pass:** both.

### C-07 — Degraded stub edge (F-007)
- **Setup:** temporarily rename `libs/LibKa0s` to `libs/_LibKa0s` (restore afterwards).
- **Steps:** `/reload`; switch profile twice; `/am disable`; `/am enable`.
- **Expected:** one "LibKa0s is missing" line; no Lua errors; containers draw after enable.
- **Pass:** as stated. **Restore the folder.**

### C-08 — Stubs (F-008)
- Same degraded setup as C-07. `/am new target debuffs icons` while enabled creates one; `/am disable`
  then `/am new` prints the one refusal line; `/am` (bare) prints the "settings panel unavailable" line.
- **Pass:** as stated.

### C-09 — Test mode refused while disabled (F-009)
- **Steps:** `/am disable`; Settings → AddOns → Ka0s Aura Master → General → Master controls → tick
  **Test mode**. Then `/am enable`.
- **Expected:** one gray refusal line naming `/am enable`; the checkbox reads unticked; after enable,
  containers are **not** in test mode.
- **Pass:** all three.

### C-10..C-13 — Lint, comments, docs, de-duplication
- `/am pick` and Layout → *Pick a frame...* both attach the selected container to `PlayerFrame`,
  and both cancel cleanly with right-click and Escape. `/run print(AuraMasterFramePicker)` prints `nil`.
- **Pass:** both flows identical; no named overlay.

## Regression suite

- `/reload` cleanly; login → first-time defaults (fresh `WTF` for the account: four starters appear).
- ADDON_LOADED → PLAYER_LOGIN → PLAYER_ENTERING_WORLD: no errors with `scriptErrors 1`.
- Enter combat at a dummy with every container visible; leave combat; `/am unlock` → drag a handle →
  `/am lock`; `/reload` → position kept.
- Profile switch, copy and reset (Profiles page); every option on every page toggled at least once.
- `/am disable` **in combat**: every container stops drawing at once; Blizzard's buff frame returns
  after combat ends; `/am enable` restores everything.
- **Cross-addon (collection):** with several Ka0s addons loaded, type each root — `/at`, `/am`, `/bl`,
  `/cm`, `/kcd`, `/lh`, `/mm`, `/pm`, `/pc`, `/wg` — and confirm each reaches its own addon; open
  Settings → AddOns and confirm each addon appears exactly once and each multi-page addon's pages
  appear once each.

## Taint-specific

- With a player-buff bars container set to Right-click to cancel: in combat, right-click a buff →
  canceled, no `Interface action failed because of an AddOn`.
- `/am config` and Esc → Options → AddOns both open the panel out of combat; in combat, open the
  panel and click a tab — the page is locked, no red text, no `ADDON_ACTION_BLOCKED`.

## Performance spot-checks (F-002)

Run the addon's own harness, `/am perf` (it prints the workflow), with the standard's two-arm
protocol: the clean arm first, the suspended arm second, windows opened on the player's combat
**state**, no `/reload` between arms, the same addon set in both. Do it once on the pre-change build
and once on the post-change build, in the same capital, with a timeless container configured. Read
the **bucket figures** (`timedScan`, `visibilityPass`, `unitSwap`), not the frame-time delta, which is
unresolved below the harness's run-to-run spread. Record each capture as a frozen
`docs/perf-analysis/<YYYYMMDD-HHMMSS>/` bundle via `/wow-addon:perf-analysis` — this addon has none yet.

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-01 | | | |
| C-02 | | | |
| C-03 | | | |
| C-04b | | | (after U-1 re-vendor) |
| C-05 | | | |
| C-06 | | | |
| C-07 | | | |
| C-08 | | | |
| C-09 | | | |
| C-10..C-13 | | | |
| Regression | | | |
| Taint | | | |
| Perf capture | | | |
