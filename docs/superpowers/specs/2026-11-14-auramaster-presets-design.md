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
  Ka0s Melli Dark) is never written. Exception: bar `width`, and an icon row's icon size, are set from the stack's
  scaled column width (§4), so a stack's containers line up.
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

*Round 1 changed this section (§15 and its rulings in §15.1, which win where they differ): the side
stacks grow up from a base 740 down (§15.1; §15 had 640) instead of down from 330, the corner group
sits 80 further left and 40 further down, and the call-outs hang centered from the screen's center
line, their font size and top worked out to clear the preset picker, which opens on the skin
picker's spot (§15.1). A side stack's test-mode top may now reach a corner column (§15,
`docs/known-limitations.md`).*

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
- **Sizes are not scaled, except across the column.** Bar height and fonts stay in UI units, so they keep honoring
  the player's own UI scale setting. Bar width and an icon row's icon size are derived from the scaled column width:
  an icon row fits `floor(width / 28)` icons per line in reference units, and each icon is the scaled column width
  over that count, less the spacing, so the row fills its column (about 29 units per icon on a 1080-tall parent, about 20 on a 768-tall one).
  (With UI scale off, `UIParent:GetHeight()` reads 768 on every resolution, so `k` is about 0.71 and the layout
  shrinks proportionally with Blizzard's own frames.) **(Claude's call,** builder check Q5; icon size amended
  2026-11-14 under the plan's ruling on the AM-PR01 review.)
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
  - **A corner column may sit over a side column.** By these numbers the far stack runs under both corner columns on
    16:9, the right stack under the Player debuffs column on 16:10 as well, and on 4:3 and 5:4 the right and far
    stacks run under the corners entirely. The corner stacks grow down from y = 6 and the side heads sit at y = 330,
    so at the test-mode sample count every corner stack ends above the side heads under it, on every ratio named in
    §11. A heavy buff or debuff load in play can grow a corner stack down into a side stack under it
    (`docs/known-limitations.md`). Every other pair of columns is disjoint. **(Claude's call,** amended 2026-11-14
    under the plan's ruling on the AM-PR01 review: the owner approved the mockup's layout.)
- **The fallback.** `UIParent:GetHeight()` is always readable once the UI is up, so the 1920 × 1080 fallback
  (`k` = 1080/1080 against a 1080-tall parent) is used only when the height reads 0 or nil (a test environment, a
  pre-login call). **(Claude's call;** ruling 4 allows it.)

## 5. Applying a preset

- **One writer.** `modules/Presets.lua` owns preset application. It never touches `p.containers` itself: it calls the
  container registry's writer (create, delete) and the custom-category writer, which the standard's registry-writer
  rule (architecture-§5) requires. Its own state is one profile key, `presets` (below).
- **Modes.** *Replace* deletes every container, then creates the preset's; *Add* creates the preset's after the
  player's own, suffixing a name already in use with " (2)", " (3)". Empty in Replace mode deletes every container; Empty in
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
- **Combat when a restore cannot be applied yet.** Entering combat restores at the `PLAYER_REGEN_DISABLED` edge, which
  comes before lockdown. When an apply must wait even then (lockdown already up, or auras secret at the pull, which on
  Retail covers encounters, Mythic+ and PvP), the restore is held to `PLAYER_REGEN_ENABLED`: test mode goes off at once,
  the previewed containers show real auras through the fight, and the player's own come back when it ends. A restore
  applied under that wait would leave every container an anchor with no aura engine for the whole fight. One chat line
  says which happened. **(Builder's call,** AM-PR03 review, amended 2026-11-14 on the AM-PR08 review; owner to
  confirm.)
- **An apply settles a preview first.** Applying a preset while a preview is up (from any surface) restores the
  snapshot, then writes, so no snapshot outlives a confirmed preset. **(Builder's call,** AM-PR08 review.)
- **Crash safety.** The snapshot is stored in the profile (`presets.previewSnapshot`) while a preview is up, so a
  `/reload`, disconnect or crash mid-preview restores the player's containers at the next login, before anything is
  built. **(Claude's call;** the anti-goal in §1.)
- Test mode is the existing `NS.Preview.SetTestMode`; combat already turns it off, which ends the preview through the
  same path.
- **Restore is exact, ids included.** The player's containers come back with their original ids (an `attach.container`
  refers to them), so restore is a registry-writer operation of its own ("restore snapshot"), not a sequence of
  creates. Custom categories the preview created and the player did not have are removed on restore.

## 7. The first-run picker

*Round 1 changed the window (§15 and §15.1, which win where they differ): it opens where the skin
picker does, centered across with its center 75% of the way up (§15.1), instead of on the left; it
opens with the containers unlocked and carries a lock button and a test-mode button; Apply locks and
turns test mode off, and Not now, the close control and Escape put back the lock it found.*

- **When:** on a brand-new profile, once, before the skin picker. A profile that has closed it (`presets.pickerSeen`)
  never sees it again; `/am preset` reopens the window on demand. Existing profiles are marked seen by a schema
  migration, so no current player is prompted. *Changed by §18.5: a current player sees it once per account.*
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

- `profile.presets = { pickerSeen = false, seedPrint = nil, previewSnapshot = nil }`. `previewSnapshot` holds deep
  copies of `containers`, `containerOrder`, `nextContainerId`, `userCategories`, `userCategoryOrder` and
  `categorySpells`. `seedPrint` is a number, the fingerprint of the containers and order the Simple seed wrote; the
  first-run picker skips its Replace confirm only while the player's own containers still match it (§5), and closing
  the picker clears it. **(Builder's call,** AM-PR05 review.) `pickerSeen` is a skipRender settings row, as
  `skin.pickerSeen` is, so `/am get|set|reset` reach it. **(Builder's call,** AM-PR08 review.)
- Schema step v18 → v19: every existing profile that is already `seeded` gets `presets.pickerSeen = true`; a profile
  seeded with the old starter set keeps it. The step keys on `seeded`, because a fresh install climbs the whole
  migration ladder before its first seeding and must still see the picker.
- `global.presets = { pickerSeen = false }` (§18.5): the account's latch, a skipRender row resolved against the
  global store and written beside the profile's on every close the player makes; no migration step.
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
- Placement: at heights 768, 1080 and 1440 and widths for 16:9, 16:10, 21:9, 4:3 and 5:4, every stack head is inside the screen, no two stacks' columns overlap except a corner
  column over a side column, whose stack ends above the side head at the test-mode sample count (§4), every head is
  above 60% of the height, the corner stacks touch the right edge; every
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

## 15. Owner feedback, round 1 (2026-11-15)

The owner previewed Advanced (Bars) in game and gave this feedback. It applies with the same principles
to Simple, Intermediate and Healer, and to every Icons variant. Where it conflicts with §3–§8, this
section wins.

**Owner's words, in summary:**
1. The player, target and focus stacks (the `left`, `right` and `far` columns) **grow upward**.
2. The corner group (Player buffs / Player debuffs / Weapon enchants) moves **a bit left and down**,
   "not so far top and right".
3. The cooldown call-outs (the `middle` text stack): **text centered horizontally**, a **larger font**,
   **colors like the owner's default profile**, and the stack **in the center of the screen**.
4. The first-run picker opens **centered horizontally**, and vertically so it overlaps **neither the
   skin picker nor the center text stack**. It opens with the containers **unlocked**, has buttons that
   **toggle lock** and **toggle test mode**, and after **Apply** the containers are **locked and test
   mode is off**.

**How it is built (Claude's calls, under the run's "use your best judgement" rule):**
- *Upward stacks.* As in the owner's own profile (advanced-source.md: Buffs Short and Target buffs use
  `growV=up` and are attached bottom-to-top), a side stack's head is its **bottom** container: it is
  placed by its BOTTOMLEFT (BOTTOMRIGHT for a row growing left) at the column's **base**, with
  `layout.growV = "up"`. Each member attaches **above** the one before it (member BOTTOMLEFT to parent
  TOPLEFT, a gap of 6 reference units). The tier's order is kept, so its first role sits nearest the
  base, which is the owner's own pattern (the most important container is nearest the unit frames). The
  base sits above where unit frames and action bars usually are: a starting value of y = -600 reference
  units from the top (480 above the bottom at 1080 tall), and the builder may tune it. *(Tuned to
  y = -640, 440 above the bottom at 1080, on the AM-PR09 review: at -600 Advanced's Bars target stack
  ran about 24 off the top of a 1080-tall screen in test mode. It still runs off a 768-tall one, and
  off a 1080-tall one while unlocked, which `docs/known-limitations.md` records for the owner's call:
  a lower base or a split stack. The owner chose the lower base, y = -740, in §15.1.)*
- *Corner group.* It still grows down from the top-right corner, moved about 80 reference units left
  and 40 down from §4's values. It must stay on screen at every ratio §11 tests.
- *Center text stack.* The head is placed by its TOP at the screen's horizontal center (x = 0) and grows
  down. Lines use `justifyH = "CENTER"`, and the line width is the column. The look copies the owner's
  three call-outs: font colors Offensive (0.1, 1, 0.1), Defensive (1, 0.125, 0.125) and Raid
  (1, 0.486, 0.04) (Healer's Raid cooldowns the same), `fontColorFromSkin = false`, a black glow
  (`glow = true`, color (0, 0, 0), radius 6, offsets 1/-1), no label, and the template `$spellname$`
  unless the current one is wanted. The font size is bigger than today's: the owner uses 36, so the
  builder uses the largest size from 24 to 36 that keeps the test-mode block clear of the picker (below).
  Bar and icon sizes are unchanged. This is the one place a preset carries appearance (§3 said none
  except bar width), by the owner's explicit request.
- *Vertical placement of the text stack.* Its test-mode extent is centered on the screen's vertical
  middle as far as the picker allows. The extent is the **unlocked** one, as the picker opens the
  containers (the head's drag strip above it and each member's strip row in its seam), so the picker
  placed under it clears the block locked or unlocked (`PresetData.CalloutRect`, AM-PR09 review).
- *Picker position.* *(Replaced by §15.1, ruling 1: the picker opens on the skin picker's spot and
  the call-outs clear it. Kept for the record.)* Horizontally centered. Vertically, the picker sits **below** the center text
  stack's test-mode extent and above the bottom edge, and it never overlaps the skin picker's rectangle
  (LibKa0s places that by its CENTER, 75% of the way up UIParent). At 1920x1080, with the text stack in
  test mode, the three rectangles must not intersect. If they cannot all fit, the text stack moves up
  before the font shrinks. Read UIParent's size when the picker shows. *(Not met for Advanced, open
  for the owner since the AM-PR10 review: its three call-outs are 520 tall in test mode, unlocked,
  even at 24, and the room under the skin picker at 1080 cannot hold that and the picker, so the
  picker covers the block's lower lines in Bars and Icons at every 1080 ratio. Healer's single
  call-out clears it. Meeting it needs one of: the block rising into the skin picker's room (the
  skin picker never shows with this window, but the call-outs' head would then sit near the top of
  the screen in play), fewer test-mode lines per call-out, a floor size under 24, the picker
  beside the block instead of centered, or the picker placed by the selected preset's block (today it
  takes the lowest block over every preset, so it opens at the bottom of a 1080 screen for Simple,
  Intermediate and Healer too). `docs/known-limitations.md` and the 1080 case in
  `tests/test_presetpicker.lua` record it until the owner rules.)*
- *Lock and test mode in the picker.* When the picker shows, it records the lock state and unlocks the
  containers (the `locked` setting, through the write seam that `/am unlock` uses). Two buttons in the
  window show and flip the lock and test mode. Turning test mode off while a preview is up ends the
  preview the way Not now does. **Apply** keeps the preset, then sets `locked = true` and test mode off.
  **Not now**, the close control and Escape restore the preview as before, then put the lock state back
  to what it was when the window opened, and test mode is off. *(A logout or a `/reload` with the
  window up takes it down the same way before SavedVariables are written, unmarked, so the lock it
  found is what is saved: the AM-PR11 review.)* A container dragged while the preview is
  unlocked is part of the preview: Apply keeps where it was dragged to. `/am preset` opens the window the
  same way. The Presets tab is unchanged.
- §11's placement checks become: every head and base is on screen at every tested ratio; upward stacks
  grow up (their heads are placed by a BOTTOM point at the column's base); the corner group's
  test-mode bottom stays above the side stacks' bases; at 1080 tall, in test mode, the picker, the
  skin-picker rectangle and the text stack do not intersect. A side stack's test-mode top may reach a
  corner column on tall stacks (Advanced's target stack); that overlap is recorded in
  docs/known-limitations.md, as §4's corner-over-side sharing already is.

### 15.1 Owner rulings on the round-1 conflicts (2026-11-15)

1. **Picker spot.** The preset picker opens where the skin picker does: centered horizontally, its
   CENTER 75% of the way up UIParent (the LibKa0s skin picker's `place()`). The two never show at once
   (the skin picker is hidden while the preset picker is up and opens after it closes), so they no longer
   need separate room. The call-out block is then sized and placed to clear the **preset picker's**
   rectangle (which is also the skin picker's), centered on the screen's middle as far as that allows,
   with the largest font from 24 to 36 that fits. The picker's position no longer depends on any
   preset's call-outs. This replaces §15's "Picker position" bullet. *The call-out half is superseded
   by §18.3: the block's top sits at the picker's top and may overlap it.*
2. **Lower base.** The side stacks' base moves down to about 340 reference units above the bottom edge
   (y = -740 from the top at 1080 tall, scaled by k), to give tall upward stacks (Advanced's target
   stack) room under the top edge. Tall unit-frame or action-bar setups may now meet the base; that goes
   in docs/known-limitations.md.

## 16. Owner feedback, round 2 (2026-11-15)

The owner previewed Advanced (Bars) again. Where this conflicts with §15/§15.1, this section wins. Apply
it with the same principles to the other tiers and to every Icons variant.

1. **The call-outs' glow looks wrong.** The builder set `glowThickness = 6`, a heavy black outline. The
   owner's own three call-outs use `glow = true`, `glowColor = (0, 0, 0)`, `glowColorFromSkin = false`,
   `glowRadius = 6`, `glowThickness = 2`, `glowIntensity = 1`, `glowFalloff = "soft"`,
   `glowBlend = "BLEND"`, `glowX = 1`, `glowY = -1`, `useClassColorGlow = false`. Use exactly these, and
   list every glow field explicitly so a template or skin default cannot leak in. (The owner referred to
   a screenshot of settings that did not come through. If it differs, the owner will send it and these
   values change.)
2. **Focus debuffs (mine) and Focus buffs (mine) grow horizontally**, because Focus debuffs (mine) is
   attached to Target buffs (all), a horizontal icon row. Fix by removing that attachment: the focus
   containers become their **own stack**, a new `focus` column, in every tier that has focus roles
   (Intermediate `fdeb`; Advanced `fdeb`, `fbuff`; Healer `healFocus`, `dispelFocus`). The stack's head is
   placed on the screen (`attach.mode = "screen"`, "None" in the panel) with a position of its own. It
   grows up like the other side stacks, and its members attach above it. Its rectangle, in test mode and
   unlocked, stays further than **2 x `C.SNAP_RADIUS`** from the `far` stack's (Target debuffs (all) /
   Target buffs (all)), so dragging it near cannot snap it back. Find the root cause of the horizontal
   growth too: no **bars** container in any preset may end up laid out horizontally after Apply.
3. **The corner group is still too far right.** Move it further in, so the **left edge of Player debuffs
   (all)** (`cornerLeft`) lines up with the **left edge of Focus buffs (mine)**, the `focus` column. The
   corner group must end up left of where §15 put it (`cornerLeft` left edge at more than 475 reference
   units from the right edge). Choose the `focus` column's place to meet both rules. It must not sit in
   the `right` (target) column's horizontal span where their test-mode vertical extents meet at 1080; if
   that cannot be fully met, keep the overlap smallest and record it in docs/known-limitations.md.
   `cornerRight` keeps its width and its gap to `cornerLeft`.
4. **The Presets tab moves to the General page** (settings/General.lua, the addon's General page), so it
   is easier to find. It is removed from the Containers page. Everything the tab did stays the same: pick,
   preview, Apply with a confirm, Stop preview, and restore on leaving the tab or closing the panel. The
   picker footer string, the docs and the smoke checks name the new place.

### 16.5 Notes from building and reviewing section 16 (AM-PR13, 2026-11-15)

These record where the build departs from the letter of section 16, each left for the owner's call.

1. **The retired glow leaves.** Point 1 lists `glowRadius = 6`, `glowFalloff = "soft"` and
   `glowBlend = "BLEND"`. The glyph glow retired those three halo leaves (TG-09): the container
   template has none of them, the schema refuses them (`tests/test_style_text_glow.lua`) and nothing
   reads them. The call-outs store every glow leaf the template does have (glow, color, color from
   skin, class color, intensity, thickness, x, y) and none of the three. In game the call-outs' glow
   is defined by thickness 2 and the 1, -1 offsets alone; radius, falloff and blend have no effect.
2. **Snap range (point 2).** The focus stack stays more than 2 x `C.SNAP_RADIUS` from the far stack on every
   screen tested, locked or unlocked. It cannot stay that far from every other container: it shares
   a strip with the target column (note 3), and on a 768-tall screen it sits close under Weapon
   enchants. While unlocked, the target stack's containers, and at 768 Weapon enchants and the
   call-outs, sit within one snap radius of a focus container on some screens; Bars at 1080 has none.
   The pairs, by screen, are in docs/known-limitations.md (presets).
3. **How far in the corner group moved (point 3).** It asks for both a corner group left of section 15's
   place and the smallest shared strip with the target column. The build took the least move that
   meets the first rule after rounding (480), about 5 pixels at 1080, so the preview looked
   unmoved. Its review took a move the owner can see instead, since the owner asked to bring the
   group "in even further": Player debuffs' left edge 520 in from the right edge (475 before),
   `cornerRight` at 300 in, keeping its width and its 5 gap. The cost is 40 more shared strip with
   the target column (80 on 16:9, 176 on 16:10, 182 to 194 on 5:4 and 4:3 in Bars), and in Icons on
   4:3 and 5:4 the call-outs come within one snap radius of the focus rows at 1080 and 1440
   (docs/known-limitations.md, presets). The owner keeps 520 or names another distance. *Superseded by
   section 17.1, which hangs the whole right-hand cluster from the right edge instead.*

## 17. Owner feedback, round 3 (2026-11-15)

The owner previewed Advanced (Bars) again and sent a before/after of the layout they want: they dragged
the containers to where they should sit. Where this conflicts with §15, §15.1 or §16, this section
wins. Apply it with the same principles to Simple, Intermediate and Healer, in Bars and in Icons. (The
owner's screenshots look like a 21:9 screen; every ratio §11 tests must still work.)

**1. Positions: line the right-hand cluster up.** In the owner's "after" layout:
- **Player debuffs (all) attaches to Player buffs (all):** `attach.mode = "container"`, parent Player
  buffs (all), this container's **TOPRIGHT** to the parent's **TOPLEFT** (the panel shows "Its Top right
  joins the Top left of 'Player buffs (all)'"). In Icons too. Weapon enchants stays attached under Player
  buffs (all). The corner group's head is Player buffs (all), still hung from the top-right corner.
- **The focus stack's left edge = Player debuffs (all)'s left edge** (kept from §16), below the corner
  group.
- **The far stack (Target debuffs (all) / Target buffs (all)) sits under the focus stack**, its left edge
  on the same line as the focus stack's. Their tops and bottoms stay further apart than 2 x
  `C.SNAP_RADIUS` (§16.2's rule, now vertical).
- **The target stack (the `right` column) moves next to that column**, to its left, with a gap of about
  50 reference units between the target column's right edge and the focus column's left edge. It hangs
  from the right edge like the focus column, so the gap holds on every screen. *Superseded by §18.2: the
  cluster hangs from the center line, the target column at the player column's mirror, and moves left
  only to fit.*
- **Tops and bottoms line up:** the target stack's base is on the far stack's bottom line, and in test
  mode its top lines up with the top of Player debuffs (all) as closely as its height allows. The other
  side stacks (the player stack on the left) keep the same base line.
- **The call-out block keeps the screen's center.** On narrow screens (16:9 and narrower) the target
  column can run into it. If it does, narrow the call-out column first, but never below the widest
  test-mode line at its font size. Whatever overlap is left goes in docs/known-limitations.md with the
  measured figures.
- §16.3's "smallest overlap with the target column" rule and §15's corner offsets give way to these
  alignments. Pick the corner group's distance in from the right edge so the whole cluster (target
  column, gap, focus/corner column, Player buffs) fits on every tested ratio, with Player buffs' right
  edge at least 10 reference units in from the screen edge.

**2. Equal bar widths.** In Bars, every bar container in every preset has the same width as Player
cooldowns: the `left` column's 240 reference units, scaled. Every column that holds bars is 240 wide,
so the alignments above hold. Icon rows keep filling their column.

**3. Bar look, for all presets:**
- Every **HARMFUL bars** container sets Fill → Color by to **By dispel type**.
- Every **bars** container sets the background opacity to **50%**.
Use the bar schema's real field names (settings/Bars.lua). Write each field explicitly so a skin default
cannot override it.

**4. Numbered names, as in the owner's profile.** Each container name starts with `[n] `, numbered in
the owner's order (advanced-source.md brackets): 1 Player buffs (all), 2 Weapon enchants, 3 Player debuffs
(all), 4 Offensive cooldowns, 5 Defensive cooldowns, 6 Raid cooldowns, 7 Player buffs short, 8 Player
cooldowns, 9 Player special, 10 Target debuffs (mine), 11 Target buffs (mine), 12 Target crowd control,
13 Target cooldowns players, 14 Target cooldowns NPCs, 15 Target stealable, 16 Target special,
17 Target debuffs (all), 18 Target buffs (all), 19 Focus debuffs (mine), 20 Focus buffs (mine). A preset
with fewer containers numbers **continuously** (1..N, no gaps), keeping that relative order. Roles that
are not in the owner's profile take the slot of the role they stand in for: Healer's Player cooldowns at
Player cooldowns; Your heals on target, then Dispellable on target, at Target debuffs (mine); Your heals
on focus, then Dispellable on focus, at Focus debuffs (mine); Intermediate's merged Target cooldowns at
Target cooldowns players. **Creation order** (containerOrder) follows the same numbering. The numbers are
not localized; the names after them stay localized. Add mode's " (2)" suffix still applies after the name.

**5. An unlock hint.** When the preset picker closes, by any route (Apply, Not now, the close control,
Escape), print one chat line telling the player they can type `/am unlock` to enter unlock mode. It is
localized, uses the addon's chat prefix, and prints once per close.

### 17.1 Notes from building section 17 (AM-PR16 to AM-PR18, 2026-11-15)

Where the build lands, and where it departs from the letter of section 17, each left for the owner's call.

1. **The distances (point 1).** Player buffs (all)'s right edge sits 10 in from the right edge, the least
   point 1 allows, which keeps the cluster as far from the call-outs as it can be; Player debuffs (all)
   joins it with a 5 gap, and the target column sits 50 left of the focus column. At 1920 x 1080 the
   cluster's left edge is 785 in from the right edge. The call-out column was narrowed from 480 to 400,
   still wider than its widest test-mode line at 36. The target column still meets the call-out block
   on 16:9 and narrower screens; the measured overlaps are in docs/known-limitations.md (presets),
   pinned by `tests/test_presets_cluster.lua`.
2. **The target stack's top (point 1).** On its base the Bars target stack of Advanced ends 64 under
   Player debuffs (all)'s top at 1080 tall locked and 16 over it unlocked (its seven drag strips), and
   runs off a 768-tall screen as before (docs/known-limitations.md).
3. **Player debuffs in Icons (point 1).** Joined by its top right to Player buffs (all)'s row, it leaves
   the focus column whenever that row is not full. Kept as the owner asked; docs/known-limitations.md.
4. **The bar look (point 3).** A buff bar has its Fill > Color by written too, as One color
   (`colorMode = "static"`), so a skin default cannot change it either. An Icons preset has no bars
   container, so the two fields appear only in Bars.
5. **The numbering (point 4).** Advanced's Target stealable (15) is now created before Target special
   (16), so it sits under it in the target stack. Add mode keeps the preset's numbers, so a profile can
   hold two of a number; nothing renumbers after a delete or a rename (docs/known-limitations.md).
6. **The hint (point 5).** It prints on the player's closes only: `NS.HidePresetPicker` (a profile
   event, the stand-down) is the addon's own hide and prints none. `/am preset <name>` with the window
   up prints it once its confirm is answered, Apply or Cancel.

Where each item is checked: tests `tests/test_presets_cluster.lua` (points 1 and 2),
`tests/test_presets_data.lua` (points 3 and 4) and `tests/test_presetpicker.lua` (point 5); smoke
PRESETS-31 (point 1), PRESETS-32 (the attachment), PRESETS-33 (point 2), PRESETS-34 (point 3),
PRESETS-35 (point 4) and PRESETS-36 (point 5) in docs/smoke-tests.md, with PRESETS-1, PRESETS-4 to
PRESETS-6, PRESETS-9, PRESETS-20, PRESETS-21, PRESETS-28, PRESETS-29 and INSTALL-2 reworded to match.

## 18. Owner feedback, round 4 (2026-11-15)

The owner previewed Advanced (Bars) on their screen (it looks like 21:9). Where this conflicts with
§15–§17, this section wins. Every earlier alignment stays: Player debuffs attached to Player buffs, the
focus stack and far stack on Player debuffs' left edge, the target column 50 left of that column, the
shared base line, equal bar widths, numbered names. Apply it with the same logic to Simple,
Intermediate and Healer, in Bars and in Icons.

1. **The player stack moves toward the center.** Halve the gap between the player stack (the `left`
   column) and the call-out column: today 80 reference units (left column right edge at -280, call-out
   column left edge at -200), so it becomes 40 (the left column spans -480..-240 from the center line).
2. **The target stack mirrors the player stack.** The target column's left edge sits as far right of
   the center line as the player column's right edge sits left of it (+240, spanning +240..+480). The
   rest of the right-hand cluster (the focus and far stacks, Player debuffs, Player buffs, Weapon
   enchants) moves with it by the same amount, keeping every gap and alignment, so the cluster now hangs
   from the **center line**, not the right edge. Where the cluster would not fit (Player buffs' right
   edge must stay at least 10 reference units in from the screen edge, which fails on 16:9 and narrower,
   since the cluster reaches +1015), move the whole cluster left just enough to fit. The target column
   then sits closer to the center than the mirror, and any overlap with the call-out block is measured
   and recorded in docs/known-limitations.md. If it still cannot fit, narrow across as P.ScaleX does now.
3. **The call-outs move up.** The call-out block's top sits at about the preset picker's top (the
   picker's CENTER is 75% up UIParent, so its top is about 25% of the height down from the top, minus
   half the picker's height). The block may overlap the picker; the owner accepts that, and §15.1's rule
   that the block clears the picker no longer applies. The font is the largest from 24 to 36 that keeps
   the test-mode block above a margin over the bottom edge. The block stays horizontally centered.
4. **New profiles** get this layout through the Simple seed and the picker, as now.
5. **Existing users see the picker once.** A player whose profiles were made before this change sees the
   first-run preset picker **exactly once per account**: at the next login, on whatever profile is
   active. Closing it by any route (Apply, Not now, the close control, Escape) marks it shown and it
   never shows again for that account, on any profile. A brand-new install, whose first profile already
   shows the picker, marks it shown too, so nobody sees it twice. This is a global (account-wide) latch,
   not a profile key; follow the savedvariables and schema standards for it (a global default and a
   row, a migration only if needed). The usual Replace confirm protects an existing player's own
   containers: nothing changes unless they Apply and confirm. If combat or a hidden UI holds the picker
   back, it shows when it can, as the first-run picker does now.

Where each item is checked: tests `tests/test_presets_data.lua` and `tests/test_presets_cluster.lua`
(points 1 to 3), `tests/test_presetpicker.lua` (points 3 and 5) and `tests/test_presets_seed.lua`
(points 4 and 5); smoke PRESETS-37 (point 1), PRESETS-38 (point 2), PRESETS-39 (point 3), PRESETS-40
(point 5) and PRESETS-41 (points 4 and 5) in docs/smoke-tests.md, with INSTALL-2, PRESETS-1, PRESETS-2,
PRESETS-19, PRESETS-21 to PRESETS-23, PRESETS-29 and PRESETS-31 reworded to match. The overlaps, and
the account latch's reach, are in docs/known-limitations.md (presets).

## 19. Owner feedback, round 5 (2026-11-15)

1. **Every pick sets the window's two toggles.** Picking any preset or style in the first-run picker
   leaves **Containers: unlocked** and **Test mode: on**, whatever the buttons were set to before.
2. **Empty previews an empty screen.** Picking Empty is a preview like any other: the snapshot is taken
   and every container leaves the screen until Apply (which keeps the empty profile) or Not now / the
   close control / Escape (which restore the player's own containers). This replaces the earlier
   behavior, where Empty ended the preview and put the player's containers back on screen.

## 20. Owner ruling U-12 (2026-11-20)

The role bar colors stay in every skin. The four colors the presets write on a role's bars (gray,
orange, tan and purple; `defaults/Presets.lua`'s `BAR_GRAY`, `BAR_ORANGE`, `BAR_TAN` and `BAR_PURPLE`, with
`barColorFromSkin = false`) are an owner override: the roles read apart from the buff and debuff bars
beside them, a meaning use, so no skin recolors them (owner ruling U-12 of 2026-11-20,
Ka0sAddonsCommonTasks `docs/2026-11-20-LIBKA0S_94_97_99_100/SD_RULE.md`). Schema v21 keeps them: it moves
only a `false` whose swatch is still the template's blue (`docs/schema.md`).
