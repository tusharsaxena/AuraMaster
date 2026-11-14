# Aura Master presets: design

Date: 2026-11-14. Branch `feat/2026-11-14-presets`, cut from `feat/2026-11-14-forever-port` (the WoW Forever port,
pushed and awaiting the owner's smoke and merge). Mockup of record: https://claude.ai/artifact/9KAkkmWekBLZcxTAQ1kK8A
(the owner reviewed two rounds; this design follows round two). Source data for the Advanced preset:
`docs/superpowers/specs/2026-11-14-presets/advanced-source.md`. Follow-up: issue #28 replaces the first-run picker with
an FTUX. **(Claude's call)** marks a decision made while designing, under the owner's instruction to decide and ask
only when necessary.

## 1. Intent

A new player opens Aura Master to four starter containers and a blank canvas. The owner's own setup took months to
build. Presets give a player a working setup in one click, graded by how much they want on screen, and give the owner
(and anyone copying a profile between clients) a known-good baseline to start from.

**Success:** a player on a fresh profile picks a preset, sees it on their real screen with sample auras, applies it,
and has a sensible layout that does not cover their action bars or unit frames, on any screen size, on Retail and WoW
Forever.

**Anti-goals:** a preset that only works with EllesmereUI (or any unit-frame addon) installed; a preset that silently
wipes a player's containers; a preview that leaves the profile half-changed after a reload or a crash.

## 2. The owner's rulings (2026-11-14)

1. **Four presets: Simple, Intermediate, Advanced, Healer.** Each in two styles, **Bars** and **Icons**.
2. **Advanced is the owner's current Default profile: all 20 containers**, Target stealable included (off, as stored).
3. **No unit-frame attachment.** Nothing is anchored to a unit frame or any other addon's frame. *Clarified
   2026-11-14 (builder check):* containers **inside a stack may attach to the container above**, so a stack reflows
   as containers fill, as the owner's own setup does. Each stack's top container is placed on the screen.
4. **Placement:** the unit stacks sit higher than the owner's own layout, below the screen-middle cooldown call-outs
   and to their left and right, clear of action bars and unit frames. **Positions follow the player's screen size**;
   1920 × 1080 is the fallback only if the size cannot be read.
5. **No preview pictures** in the picker or the settings panel. Picking a preset shows it on the player's real screen
   with test mode on (`/am test`).
6. **First-run picker:** a small window, like the skin picker, on a new profile: a dropdown of **Empty**, Simple,
   Intermediate, Advanced, Healer. **Empty means a profile with no containers.**
7. **Settings:** a new **Presets** tab on the Containers page.
8. **The picker lives in Aura Master**, not LibKa0s (#28 retires it for an FTUX).

## 3. The presets

Names are plain and stable across tiers, so a player moving up keeps the names they know. **(Claude's call;** the owner
approved the mockup with them.)

| Preset | Containers |
|---|---|
| Empty | none |
| Simple (3) | Player buffs (all), Weapon enchants, Player debuffs (all) |
| Intermediate (8) | Simple + Player buffs, short; Player cooldowns; Target debuffs (mine); Target cooldowns; Focus debuffs (mine) |
| Advanced (20) | the owner's 20 (`advanced-source.md`), renamed in the plain style: Offensive / Defensive / Raid cooldowns (text), Player buffs, short, Player cooldowns, Player special (mine), Target debuffs (mine), Target buffs (mine), Target crowd control, Target cooldowns, players, Target cooldowns, NPCs, Target special (mine), Target stealable (off), Target debuffs (all) (icons), Target buffs (all) (icons), Focus debuffs (mine), Focus buffs (mine), plus Simple's three |
| Healer (9) | Simple + Raid cooldowns (text); Player cooldowns; Your heals on target (target HELPFUL, mine); Dispellable by you on target (target HARMFUL); Your heals on focus; Dispellable by you on focus |

- **The data wins over the mockup's names.** Each name says "(mine)" only where the container's `castBy` is `mine`
  in `advanced-source.md`, and "(all)" only where it is `any` and that distinction matters. The table above uses the
  corrected names; the builder renames any other container whose name and data disagree, never the data.
  **(Claude's call,** builder check Q6.)

- **What a preset container carries:** name, unit, aura type, style, enabled, the whole `filter` (category states,
  cast-by, duration, sort, situations, zones, unit filter), `layout` (axis, grow, per line, spacing) and `behavior`.
  Advanced takes these values from `advanced-source.md`, container by container. Simple and Intermediate reuse the
  Advanced container of the same role (Simple's three are Advanced 1–3; Intermediate's are Advanced's player short,
  player cooldowns, target debuffs, focus debuffs, and "Target cooldowns", which merges Advanced's two target-cooldown
  containers: `unitFilter.kind = all`, the **union** of the two containers' shown categories, and every zone on).
  Healer's new containers are written fresh with the category states named in §3.1. **(Claude's call,** builder
  check Q2: in the source the players/NPC split is `unitFilter.kind`, not `situations`.)
- **Two fields change from the source on purpose:** `attach` and `position` (§4: placed or stacked), and `layout.growV`
  becomes `down` for every stacked container so a stack grows away from its head. Every other filter, layout and
  behavior field matches the source.
- **Appearance is not carried.** Bars, icons, text and label settings come from `NS.CONTAINER_TEMPLATE` and the active
  skin, so a preset looks right in whichever skin the player picks next. The owner's personal media (Ka0s Prototype,
  Ka0s Melli Dark) is never written. Exception: bar `width` is set from the stack's column width (§4), so a stack's
  containers line up.
- **Spell ids are not carried.** Whitelists and blacklists are empty (the owner's one whitelist id, Wither 445474, is
  Retail-only). Every category key a preset names exists on both clients today (`EMPTY` is empty); a key a future
  client gates is dropped at apply time through the existing gate, never stored.
- **Advanced's two custom categories.** The owner's Player special and Target special containers show the owner's
  custom categories. Applying Advanced creates two empty custom categories, **Special player buffs** (HELPFUL) and
  **Special target debuffs** (HARMFUL), through the existing custom-category writer, and the two containers show them.
  Their lists start empty; the player fills them. **(Claude's call:** the owner asked for all 20 containers; without
  the categories two of them would show nothing, and the owner's spell ids are class-specific.)
  **Re-applying reuses them:** a custom category with the same name and aura type that already exists is used as is,
  spell list kept, and is never created twice. **(Claude's call,** builder check Q3.)
- **The player's own custom categories.** A key a container does not hold reads as Show, so a container that shows
  only some categories (Weapon enchants, the call-outs, the cooldowns, the specials, Target stealable, Target crowd
  control, Healer's dispels) also states every custom category of its aura type the player already has as Hide, as
  the source hid the owner's. A container that shows every category shows them. A custom category Advanced reuses is
  stated through its Special key instead. **(Builder's call,** AM-PR01 review.)

### 3.1 Healer's category states (Claude's call)

- Your heals on target / focus: unit target / focus, HELPFUL, cast-by mine, every category shown.
- Dispellable by you on target / focus: HARMFUL, cast-by any, only `raid` ("Raid (you can dispel)") shown.
- Player cooldowns: Advanced's, with `healing` and `raidCDs` shown as well.
- Raid cooldowns: Advanced's Raid cooldowns text container.

### 3.2 Bars and Icons

The Icons variant of a preset is the Bars variant with each `style = "bars"` container switched to `style = "icons"`
and its layout turned horizontal (`axis = "horizontal"`, growing away from the screen edge it sits nearest). Text
containers stay text; containers that are icons in Advanced (Target debuffs/buffs (all)) stay icons in both. The
variant is computed from the Bars definition, never stored twice.

## 4. Placement

- **Stacks.** A preset is a set of **stacks** (columns). Each stack's **head** is placed on the screen; every other
  container in the stack attaches to the one above it (`attach.mode = "container"`, its TOPLEFT to the BOTTOMLEFT of
  the one above, with a small gap) and grows down. So a container that fills pushes the rest of its stack down, the way
  the owner's own stacks behave, and no container needs an aura cap. Nothing attaches to a unit frame (ruling 3).
- **Heads.** A head is anchored to one of two `UIParent` points: `TOPRIGHT` (the corner stacks) or `TOP` (the middle
  call-outs and the three side stacks, offset horizontally from the screen's center line and down from the top edge).
  Head offsets and stack widths are written in a **reference space 1080 units tall** and scaled at apply time by
  `k = UIParent:GetHeight() / 1080`. So positions stay proportional on any screen height, the corner stacks hug the
  corner on any width, and on an ultrawide the side stacks simply have more room outside them.
- **Narrow screens.** The middle and side columns reach 790 units right of the center line, so below about 1.48:1
  (4:3, 5:4) they would run off the right edge. There the horizontal offsets and column widths scale by
  `kx = W / (2 × 800)` instead of `k` (never more than `k`), so the far column ends 10 units in from the edge; tops
  still scale by `k`. On 16:10 and wider `kx = k` and nothing changes. **(Claude's call,** AM-PR01 review: §1 asks for
  a sensible layout on any screen size.)
- **Sizes are not scaled.** Bar height, icon size and fonts stay in UI units, so they keep honouring the player's own
  UI scale setting. (With UI scale off, `UIParent:GetHeight()` reads 768 on every resolution, so `k` is about 0.71 and
  the layout shrinks proportionally with Blizzard's own frames.) **(Claude's call,** builder check Q5.)
- **Where the numbers live:** `defaults/Presets.lua`, as data per container: `{ stack, order }` plus a stack table
  (`{ anchor, x, y, width }`). The apply step turns a head into a `position` and a stack member into an `attach` to the
  container created just before it, through the existing position and attach code, so nothing downstream changes.
- **The reference layout** (1920 × 1080, from the mockup):
  - corner: Player buffs and Weapon enchants in a 175-wide column 175 in from the right edge, top 6; Player debuffs in
    a 215-wide column 395 in from the right.
  - middle: the three text call-outs in a 480-wide column centered on the screen, from y = 200 down. The column is
    centered, not the lines: each line is left-justified and sizes to fit from the column's left edge, since Center on
    a template of more than one piece stacks each field on a row of its own (`modules/Style_Text.lua`,
    `Text.Stacked`). The stored text width is the column's. **(Builder's call,** AM-PR01 review.)
  - left stack (player): 240 wide, its left edge 520 left of center, from y = 330.
  - right stack (target): 240 wide, 280 right of center, from y = 330.
  - far-right stack (target icons, then focus): 220 wide, 570 right of center, from y = 330.
  - The side stacks' heads at y = 330 sit beside the call-out column, with 40 units of clearance either side, so a
    growing call-out list never runs into them. At sample-aura heights (test mode) every stack ends above y = 640,
    clear of the bottom 40% where action bars and unit frames sit; in play a stack may grow further, as the owner's own
    stacks do.
- **The fallback.** `UIParent:GetHeight()` is always readable once the UI is up, so the 1920 × 1080 fallback
  (`k` = 1080/1080 against a 1080-tall parent) is used only when the height reads 0 or nil (a test environment, a
  pre-login call). **(Claude's call;** ruling 4 allows it.)

## 5. Applying a preset

- **One writer.** `modules/Presets.lua` owns preset application. It never touches `p.containers` itself: it calls the
  container registry's writer (create, delete) and the custom-category writer, which the standard's registry-writer
  rule (architecture-§5) requires. Its own state is one profile key, `presets` (below).
- **Modes.** *Replace* deletes every container, then creates the preset's; *Add* creates the preset's after the
  player's own, suffixing a name already in use with " 2", " 3". Empty in Replace mode deletes every container; Empty in
  Add mode is not offered.
- **Confirm.** Replace asks first, naming the count it removes ("Replace your 20 containers…"). The first-run picker on
  a brand-new profile does not ask (nothing of the player's is lost).
- **Combat.** Applying, previewing and the picker are refused in combat, with the standard combat line, and the picker
  waits for combat to end before it shows (the skin picker's behavior).
- **Slash.** `/am preset` opens the picker (the window, not first-run state); `/am preset <name> [icons] [add]` applies
  directly with the same confirm. **(Claude's call;** slash-commands-§ parity for a panel act.)

## 6. Preview on the real screen

- **Picking previews.** In the picker and on the Presets tab, choosing a preset or a style applies it to the profile
  **as a preview**: the current containers and custom categories are snapshotted, the preset is written in Replace
  mode, and test mode is turned on so every container fills with sample auras. Picking again swaps the preview.
- **Ending a preview.** Apply keeps it (in the chosen mode; Add re-applies the preset on top of the snapshot) and turns
  test mode off. Not now, the close control, Escape, leaving the Presets tab, closing the settings panel, a profile
  change and entering combat all restore the snapshot and turn test mode off.
- **Crash safety.** The snapshot is stored in the profile (`presets.previewSnapshot`) while a preview is up, so a
  `/reload`, disconnect or crash mid-preview restores the player's containers at the next login, before anything is
  built. **(Claude's call;** the anti-goal in §1.)
- Test mode is the existing `NS.Preview.SetTestMode`; combat already turns it off, which ends the preview through the
  same path.
- **Restore is exact, ids included.** The player's containers come back with their original ids (an `attach.container`
  refers to them), so restore is a registry-writer operation of its own ("restore snapshot"), not a sequence of
  creates. Custom categories the preview created and the player did not have are removed on restore.

## 7. The first-run picker

- **When:** on a brand-new profile, once, before the skin picker. A profile that has closed it (`presets.pickerSeen`)
  never sees it again; `/am preset` reopens the window on demand. Existing profiles are marked seen by a schema
  migration, so no current player is prompted.
- **What a new profile starts with:** **Simple (Bars)**, seeded as the starters are today, replacing the four-container
  starter set (`NS.STARTER_CONTAINERS` retires). Closing the picker without choosing keeps Simple. **(Claude's call:**
  the owner chose Empty as an option, so "nothing chosen" needs a default; Simple is the closest to today's starters
  and the least surprising.)
- **The window** (mockup board "First run"): title "Choose a preset", the addon label, a dropdown (Empty, Simple,
  Intermediate, Advanced, Healer, each with its container count), a Bars / Icons switch (hidden for Empty), one line
  describing the pick, the line "On your screen now, filled with sample auras. Nothing is saved until Apply.", then
  Apply and Not now, and a footer naming Containers › Presets and the skin picker that follows. It sits on the left,
  vertically centered, clear of the preset stacks, and is movable.
- **Built from LibKa0s pieces** (the window frame, dropdown, buttons, skin painting, layering at DIALOG as the skin
  picker uses) in an Aura Master file, `settings/PresetPicker.lua`. When it closes, it calls `NS.MaybeShowSkinPicker`,
  so the two never show at once.
- **Other Ka0s addons' skin pickers** queue among themselves in LibKa0s and know nothing of this window, so on a fresh
  character one can show while the preset picker is up. The preset picker shows first (it does not wait the skin
  picker's two seconds) and both windows are movable; the overlap is recorded in `docs/known-limitations.md` and #28's
  FTUX is where a shared queue belongs. **(Claude's call,** builder check Q4: joining the queue needs a LibKa0s
  internal or a library change, which ruling 8 argues against.)

## 8. The Presets tab

- **Where:** the Containers page's General section gains a second tab, **Presets**, after General (mockup board
  "Containers page, Presets tab").
- **What it holds:** a line saying a preset changes every container in the profile (not just the one in the band) and
  leaves skin, fonts and General settings alone; the preset choice (Simple, Intermediate, Advanced, Healer); the Bars /
  Icons switch; a status box ("Previewing … on your screen in test mode. Move this panel aside to look. Nothing is
  saved until Apply; leaving this tab or closing the panel puts your containers back."); the list of containers the
  preset creates; When applied: Replace all my containers / Add next to my containers; **Apply preset…** and **Stop
  preview**.
- Empty is not on the tab (Replace with Empty is the same as deleting every container, which the band already does one
  by one; Claude's call, to keep a one-click wipe off the panel).

## 9. Stored data

- `profile.presets = { pickerSeen = false, previewSnapshot = nil }`. `previewSnapshot` holds deep copies of
  `containers`, `containerOrder`, `nextContainerId`, `userCategories`, `userCategoryOrder` and `categorySpells`.
- Schema step v18 → v19: every existing profile that is already `seeded` gets `presets.pickerSeen = true`; a profile
  seeded with the old starter set keeps it. The step keys on `seeded`, because a fresh install climbs the whole
  migration ladder before its first seeding and must still see the picker.
- Nothing about which preset was applied is stored. **(Claude's call:** a preset is a starting point, not a mode;
  remembering it would invite "you changed it, it's no longer Advanced".)

## 10. Standards

- Registry writes go through the writers (architecture-§5). The picker is a DIALOG-layer window (frame-layering §1,
  §4). Every string goes in `locales/enUS.lua`. Client checks go through `NS.Compat` only. A new file stays under 1500
  lines; `defaults/Presets.lua` is data and may sit in the 1000–1500 band.
- **No deviation is expected.** If the builder finds one (for example, a rule that a first-run window must use a
  LibKa0s picker), it stops and flags it, per CLAUDE.md.

## 11. Tests (headless, both kit profiles)

- Each preset's container count, names and units; Advanced has 20 and matches `advanced-source.md` field by field for
  filter, layout and behavior, except the fields §3 changes on purpose (`attach`, `position`, `growV`).
- Every category key in every preset exists on both clients; none is a custom key except the two Advanced creates
  and, as Hide, the player's own (§3); re-applying Advanced reuses them.
- Placement: at heights 768, 1080 and 1440 and widths for 16:9, 16:10 and 21:9 (and, for the on-screen, height and
  corner checks, 4:3 and 5:4), every stack head is inside the screen, no two stacks' columns overlap, every head is above 60% of the height, the corner stacks touch the right edge; every
  stack member attaches to the container created before it; nothing attaches to a frame name; the fallback triggers
  only at height 0/nil.
- Icons variant: bars become icons with a horizontal layout; text and icon-only containers are unchanged.
- Apply: Replace and Add (name suffixes), Empty, the confirm path, refusal in combat, the registry writer is the only
  writer.
- Preview: snapshot and restore are exact, container ids and attach targets included; every end route restores; a
  snapshot left in the profile restores at login; categories the preview created are removed.
- First run: a new profile seeds Simple and shows the picker before the skin picker; a migrated profile never sees it;
  `/am preset` reopens it.
- Smoke (owner): a FOREVER and a Retail theme in `docs/smoke-tests.md`: the picker on a new profile, each preset in
  each style on the real screen, Apply, Not now, a `/reload` mid-preview.

## 12. Approaches considered

1. **Presets as data plus one writer (chosen).** Presets are tables in `defaults/Presets.lua`; one module applies them
   through the existing writers. Cheap, testable, and the Icons variant is a pure transform.
2. **Presets as stored profiles** (an AceDB profile per preset the player copies from). Rejected: it pollutes the
   Profiles list and AceDB's copy cannot place containers by screen size.
3. **A LibKa0s preset picker** shared by every Ka0s addon. Rejected by ruling 8: a library release and re-vendor for a
   window #28 retires.

Preview approaches: **write-and-snapshot (chosen)** against a transient, unsaved container set. The transient set
would need a second build path through ContainerManager for every style; the snapshot reuses the real one and the
stored snapshot gives crash safety.

## 13. Non-goals

No new styles, categories or filter features. No per-spec or per-class presets. No sharing presets between players
(import/export). No change to the skin picker. No version bump, tag, release or merge without the owner's go-ahead.

## 14. Left to the builder

The exact Healer category states beyond §3.1 where a key's meaning is unclear (flag it); the reference heights for bar
height and icon size so §4's stacks fit; how the Presets tab reuses the band and tab helpers in
`settings/OptionsSetup.lua`, and how it detects the player leaving the tab (the library has no leave callback; the
host's re-render is one route); the picker's exact widget set from LibKa0s.
