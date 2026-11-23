# Aura Master presets: tower restack, role colors, fixed bar width (design)

**Date:** 2026-11-23. **Branch:** `feat/2026-11-23-auramaster-preset-restack`. **Clients:** Retail and
WoW Forever (one codebase). Extends `2026-11-14-auramaster-presets-design.md` (sections 17.3, 17.4
and 20 in particular). No version bump.

## 1. The owner's request (2026-11-23)

"ADVANCED PRESET (and all other profiles)":

- **Player tower.** Today, top to bottom: `[09] Player special (mine)` (blue), `[08] Player cooldowns`
  (blue), `[07] Player buffs, short` (gray). Wanted, top to bottom: `[09] Player buffs, short`,
  `[08] Player cooldowns`, `[07] Player special (mine)`. "Container 07 should be in the same blue color
  as Container 08" (Player buffs, short turns blue). "Player cooldowns containers should use the same
  color as [14] Target cooldowns, players" (tan).
- **Target tower.** Today, top to bottom: `[15]` cooldowns NPCs (blue), `[14]` cooldowns players (tan),
  `[13]` crowd control (orange), `[12]` buffs (mine) (blue), `[11]` debuffs (mine) (dispel colors),
  `[10]` special (mine) (gray). Wanted, top to bottom: `[15] Target buffs (mine)`, `[14] Target debuffs
  (mine)`, `[13] Target cooldowns, NPCs`, `[12] Target cooldowns, players`, `[11] Target crowd control`,
  `[10] Target special (mine)`. "[15] Target cooldowns NPCs uses the same color as [14] Target
  cooldowns, players" (tan).
- **Width.** "Make the default width of the bars to be 240px (height can be the same as today) - dont
  do dynamic resizing basis screen width."
- **"And all other profiles":** the owner's existing profiles built from the preset change too.

## 2. How a preset container is identified, numbered and stacked (as found)

- **Identity.** Nothing records which preset or role made a container (`docs/ARCHITECTURE.md`,
  Presets: "Nothing records which preset..."). The only stable identity is the exact name the builder
  wrote, `"[NN] " .. L[role name]` (`defaults/Presets.lua`, `P.Build`). Add mode's " (2)" suffix and any
  rename break that identity, by design.
- **Numbering.** `NN` is the role's index in its tier's creation-order list (`TIERS`), two digits.
  It is stored only inside `name`; `containerOrder` is the creation order, so the two agree on a fresh
  apply. The number is not derived anywhere at run time.
- **Stacking.** A tower is a chain: its head (the tier's first role in that stack) is placed on the
  screen (`attach.mode = "screen"`, `position` CENTER on CENTER for the `left`/`right` stacks), and every
  later role attaches to the one created just before it (`attach.mode = "container"`, `attach.container`
  the parent's id, `BOTTOM` to `TOP` for an up stack, flush). The side towers grow up, so the head is
  the bottom bar and the highest number is the top.

## 3. The preset changes

**Order and numbers.** Restacking is a reorder of the tier's list, so the chain and the numbers
follow from it:

| Preset | Stack | Today (head first, bottom up) | New (head first, bottom up) |
| --- | --- | --- | --- |
| Advanced | left | 07 pshort, 08 pcd, 09 pspec | 07 pspec, 08 pcd, 09 pshort |
| Advanced | right | 10 tspec, 11 tdeb, 12 tbuff, 13 tcc, 14 tcdp, 15 tcdn, 16 tsteal | 10 tspec, 11 tcc, 12 tcdp, 13 tcdn, 14 tdeb, 15 tbuff, 16 tsteal |
| Intermediate | left | 04 pshort, 05 pcd | 04 pcd, 05 pshort |
| Intermediate | right | 06 tdeb, 07 tcd | 06 tcd, 07 tdeb |
| Healer | left, right | unchanged (pcdHealer alone; heals and dispels) | unchanged |

Target stealable (16, stored off) stays the tower's top, now over Target buffs (mine). Intermediate
ships the same player roles and a merged Target cooldowns (it stands in for Advanced's two), so it
takes the same relative order: cooldowns under buffs short, target cooldowns under target debuffs
(Claude's call, "change any other preset that ships these same containers the same way"). The
owner-rank test table moves with it (pspec 7, pshort 9; tcc 11, tcdp 12 and Intermediate's tcd,
tcdn 13, tdeb 14 and its Healer stand-ins, tbuff 15).

**Colors.** `BAR_GRAY` leaves Player buffs, short (it keeps the template's blue, One color, written as
every buff bar's fill mode); `BAR_TAN` goes on Player cooldowns (Advanced's, Intermediate's and Healer's
`pcdHealer`: "Player cooldowns containers", plural), Target cooldowns, NPCs and Intermediate's merged
Target cooldowns (both its sources are now tan). Target special (mine) keeps gray, Target crowd control
orange, Weapon enchants purple. All stay off the skin (section 20 of the presets design, ruling U-12).

**Width.** Every column's width is used as is, no longer scaled (`columnWidth` answers `stack.width`):
a bar is 240 wide on every screen, as is the Player buffs/debuffs pair; the call-out line's stored
width (its fallback when Size to fit cannot measure) is 400; an Icons preset's row sizes against the
unscaled column. Bar height was never scaled and is unchanged. Positions still scale with the screen
(the layout keeps its place on a 768 or 1440-tall screen); only sizes stop. `P.ClusterShift` now keeps
Player buffs' right edge `EDGE_IN` in with its real, unscaled half-width (identical at 1080 tall,
where the scale is 1), so the corner never runs off the right edge on a short screen. On a screen
under 1080 tall the bars are relatively wider than the gaps, which narrow; that is recorded in
`docs/known-limitations.md`.

## 4. The migration (schema v23), the decision rule

One step, `Database.RestackPresets(p, W, H)` in `core/Database_PresetRestack.lua`, run by the ladder
over every stored profile (savedvariables-§1). Its data is frozen in the file (the old and new names,
the old colors), so a later preset change never moves what v23 does. `W, H` is the parent's size at
load (`NS.Presets.ParentSize`, the size the first-run seeding reads).

**The rule.** A field changes only while it still holds the value the old preset wrote; anything else
is the player's and is left as it is. Per field:

1. **Fill color** (a container named exactly as an old preset role with a color change). Changes only
   when the whole fill is still the old preset's: `colorMode = "static"`, `barColorFromSkin = false`,
   `useClassColorBar = false`, and `barColor` equal on every channel (1e-6) to the old color (gray for
   Player buffs, short; the template's blue for the cooldown roles). It is then written as the new
   preset writes it: the template's blue for Player buffs, short; tan, off the skin, for the others.
2. **Width** (a bars container named exactly as any old preset bars role). Changes to 240 only when
   `bars.width` is one of the two widths the old builder could have written on this parent,
   `floor(240 * kx)` and `ceil(240 * kx)` (`kx` the old horizontal scale, `min(H / 1080, W / 1693.6)`,
   frozen: 1693.6 is twice the old layout reach, 846.8). A width the player typed, or one written on a
   different screen, stays. Where the parent cannot be read `kx` is 1, so only 240 counts, a no-op.
3. **Slot and number** (a tower, Section 3's table). The tower restacks only when every role of its old
   chain is present by exact old name, exactly once, and the chain is intact: each member's `attach` is
   `mode = "container"` naming the id of the role before it. It is also refused when any container
   outside the tower attaches to one of its members (a hand-made extra would be left hanging off a bar
   in the middle). When it restacks, each **slot** keeps its own placement: the head slot's `attach` and
   `position` (where the player dragged the tower, screen or frame) go to the new head, and each member
   slot's `attach` (its points and offsets) to the new member in that slot, its `container` set to the
   new parent's id. Each container keeps its id, spells, filters and every other setting; only its
   `name` changes to the new `[NN]`. `containerOrder` is refilled with the new order in the places the
   tower's ids held, when they held them in the old chain order (otherwise the player's order stays).
4. **A stack head's place** (added by APR-06, the lead's follow-up). A head of an old preset's stack
   (by its old head name, still placed on the screen, `attach.mode = "screen"`) moves to where a fresh
   apply puts it now (`NS.PresetData.HeadPlace`) only while its `position` (point, relative point,
   x, y) is exactly the one the v22 builder computed on this parent, by that builder's own arithmetic
   frozen in the file (its stacks, scales and cluster shift), never a stored figure such as 589. On
   the owner's screen that moves the focus and far heads from 589 to 629 (Player debuffs' new left
   edge); on 2560 x 1440 the cluster's heads follow the new shift too. A head the player moved stays.
   It runs before the restack, on the head slot's position table, so a restacked tower's new head
   takes the moved place.
5. **The untouched-seed record.** A profile whose `presets.seedPrint` matched its registry before the
   step is re-recorded after it, so a still-untouched seed stays untouched for the first-run picker.

Identity is always the exact old name; never a position, an id or a count. The step is idempotent:
after it no old name with an old value remains, and a profile built from the new presets matches no old
chain and no old color (the new names that reuse an old name, `[08] Player cooldowns` and `[10] Target
special (mine)`, `[05] Player cooldowns`, already hold the new values).

## 5. Tests (test first, both kit profiles)

- Presets data: the new tier orders, numbers, the attach chain, the colors (tan on the cooldown roles,
  Player buffs, short without a color), and the width 240 at 768, 1080, 1200 and 1440 tall.
- The cluster: Player buffs 10 in from the right edge on every screen with its real width.
- The step: a fresh Advanced/Intermediate built by the OLD builder (frozen fixture) migrates to exactly
  what the new builder writes in the fields the step owns; an edited color, width, link, an extra
  attacher, a duplicate name, a renamed role each stay; idempotence; the seed record.
- The SavedVariables replay (Appendix A) against the owner's real files.

## 6. Non-goals

No change to positions on a 1080-tall screen, no change to Healer's order, no role identity field
added to the stored data (a stored preset key would need its own migration and has no reader), no
version bump.

## Appendix A. The owner's SavedVariables, before and after v23

Replayed 2026-11-23 against read-only copies of the owner's SavedVariables (two Retail accounts and the
WoW Forever account). Each file was loaded with the vendored LibKa0s, the TOC's files and the real
AceDB, first on the v22 build (master at 7e713b9, every step up to v22), then that result on this
branch, so the diff below is v23's alone. The parent was the owner's screen, 3440 x 1440 at UI scale
1.2 (2866.7 x 1200), so the v22 widths v23 recognizes there are 266 and 267. The notes are the step's
own, from the same input. Head place is a screen-placed head's point and x,y (`-` for a container
attached to another).

Columns: **slot** is a container's place in its chain counted from the bottom, `@` the chain head's
id (a head is `1@` its own id); **fill** is the bar's One color (gray 454545, blue 338cf2, tan e6cc80,
orange ff8040, purple a335ee), `dispel` By dispel type, or the style for a non-bars container. Bold
marks a changed cell.

Reading it against the rule (section 4):

- **Hand-built profiles** (Retail account 1's Default, Retail account 2's Default, Forever's
  DefaultBackup) carry none of the v22 builder's names, so nothing in them changed.
- **Profiles left as Advanced built them** (Retail SmokeTest, Forever DefaultBackupV3 and SmokeTest5)
  took every change. Forever's **Default** had its widths typed to 240 and
  Player special (mine) recolored by hand: the widths were already the target, Player special kept
  its own color (it is not a recolored role), the towers restacked (the player tower's head, now
  Player special (mine), keeps the frame anchor the owner gave the old head), and Target stealable,
  still 266, went to 240.
- **Forever DefaultBackupv2**, rearranged and renumbered by hand: Player buffs, short was already blue
  and on another member, so its color and its tower stayed; the target tower's names are the
  owner's own numbering, which v23 does not recognize, so only [08] Player cooldowns, still the old
  blue, turned tan, and [15] Target stealable kept 266 (not a v22 name).
- **Forever SmokeTest**: Target stealable renamed [15] and attached by hand, so the target tower kept
  its order and numbers while its fills and widths moved; the player tower restacked.
- **SmokeTest2 to SmokeTest4** (Simple): the widths alone.
- **Heads re-placed** (APR-06): the focus and far heads, 589 to 629, in Retail SmokeTest and Forever
  SmokeTest and SmokeTest5. Player buffs (all) the owner had dragged (Forever Default, DefaultBackupV3,
  DefaultBackupv2, SmokeTest2) stays; in SmokeTest3 and SmokeTest4 it was already where both builders
  put it. Forever Default's focus and far heads hang from frames the owner picked, so they stay.

| Client | Profile | Containers | v22 preset names | What v23 did | Containers changed | Left alone (the player had changed it) |
| --- | --- | --- | --- | --- | --- | --- |
| Retail, account 1 | Default | 20 | 0 | unchanged | 0 | - |
| Retail, account 1 | SmokeTest | 20 | 20 | heads re-placed, recolored, resized, restacked | 16 | - |
| Retail, account 2 | Default | 4 | 0 | unchanged | 0 | - |
| WoW Forever | Default | 20 | 20 | recolored, resized, restacked | 9 | `[01] Player buffs (all)` place (not the old preset place) |
| WoW Forever | DefaultBackup | 20 | 0 | unchanged | 0 | - |
| WoW Forever | DefaultBackupV3 | 20 | 20 | recolored, resized, restacked | 9 | `[01] Player buffs (all)` place (not the old preset place) |
| WoW Forever | DefaultBackupv2 | 20 | 13 | recolored | 1 | `[07] Player buffs, short` color (not the old preset fill); `[01] Player buffs (all)` place (not the old preset place); `[07] Player buffs, short` tower (a member is not on the one before it) |
| WoW Forever | SmokeTest | 20 | 19 | heads re-placed, recolored, resized, restacked | 15 | `[10] Target special (mine)` tower (a role is missing or named twice) |
| WoW Forever | SmokeTest2 | 3 | 3 | resized | 3 | `[01] Player buffs (all)` place (not the old preset place) |
| WoW Forever | SmokeTest3 | 3 | 3 | resized | 3 | - |
| WoW Forever | SmokeTest4 | 3 | 3 | resized | 3 | - |
| WoW Forever | SmokeTest5 | 20 | 20 | heads re-placed, recolored, resized, restacked | 16 | - |

#### Retail, account 1

**Default** (20 containers): unchanged; no container carries a v22 preset name (a hand-built profile).

**SmokeTest** (20 containers, 16 changed; containerOrder refilled to 4,5,6,7,8,9,12,11,10,13,16,17,18,14,15,19,20,21,22,23).

| id | before: name | slot | fill | width | head place | after: name | slot | fill | width | head place |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 4 | [01] Player buffs (all) | 1@4 | blue | 266 | CENTER 992,490 | [01] Player buffs (all) | 1@4 | blue | **240** | CENTER 992,490 |
| 5 | [02] Weapon enchants | 2@4 | purple | 266 | - | [02] Weapon enchants | 2@4 | purple | **240** | - |
| 6 | [03] Player debuffs (all) | 2@4 | dispel | 267 | - | [03] Player debuffs (all) | 2@4 | dispel | **240** | - |
| 7 | [04] Offensive cooldowns | 1@7 | (text) | - | TOP 0,-140 | [04] Offensive cooldowns | 1@7 | (text) | - | TOP 0,-140 |
| 8 | [05] Defensive cooldowns | 2@7 | (text) | - | - | [05] Defensive cooldowns | 2@7 | (text) | - | - |
| 9 | [06] Raid cooldowns | 3@7 | (text) | - | - | [06] Raid cooldowns | 3@7 | (text) | - | - |
| 10 | [07] Player buffs, short | 1@10 | gray | 266 | CENTER -340,-170 | **[09] Player buffs, short** | **3@12** | **blue** | **240** | **-** |
| 11 | [08] Player cooldowns | 2@10 | blue | 266 | - | [08] Player cooldowns | **2@12** | **tan** | **240** | - |
| 12 | [09] Player special (mine) | 3@10 | blue | 266 | - | **[07] Player special (mine)** | **1@12** | blue | **240** | **CENTER -340,-170** |
| 13 | [10] Target special (mine) | 1@13 | gray | 266 | CENTER 340,-170 | [10] Target special (mine) | 1@13 | gray | **240** | CENTER 340,-170 |
| 14 | [11] Target debuffs (mine) | 2@13 | dispel | 266 | - | **[14] Target debuffs (mine)** | **5@13** | dispel | **240** | - |
| 15 | [12] Target buffs (mine) | 3@13 | blue | 266 | - | **[15] Target buffs (mine)** | **6@13** | blue | **240** | - |
| 16 | [13] Target crowd control | 4@13 | orange | 266 | - | **[11] Target crowd control** | **2@13** | orange | **240** | - |
| 17 | [14] Target cooldowns, players | 5@13 | tan | 266 | - | **[12] Target cooldowns, players** | **3@13** | tan | **240** | - |
| 18 | [15] Target cooldowns, NPCs | 6@13 | blue | 266 | - | **[13] Target cooldowns, NPCs** | **4@13** | **tan** | **240** | - |
| 19 | [16] Target stealable | 7@13 | blue | 266 | - | [16] Target stealable | 7@13 | blue | **240** | - |
| 20 | [17] Target debuffs (all) | 1@20 | (icons) | - | BOTTOMLEFT 589,-822 | [17] Target debuffs (all) | 1@20 | (icons) | - | **BOTTOMLEFT 629,-822** |
| 21 | [18] Target buffs (all) | 2@20 | (icons) | - | - | [18] Target buffs (all) | 2@20 | (icons) | - | - |
| 22 | [19] Focus debuffs (mine) | 1@22 | dispel | 267 | BOTTOMLEFT 589,-611 | [19] Focus debuffs (mine) | 1@22 | dispel | **240** | **BOTTOMLEFT 629,-611** |
| 23 | [20] Focus buffs (mine) | 2@22 | blue | 267 | - | [20] Focus buffs (mine) | 2@22 | blue | **240** | - |

#### Retail, account 2

**Default** (4 containers): unchanged; no container carries a v22 preset name (a hand-built profile).

#### WoW Forever

**Default** (20 containers, 9 changed; containerOrder refilled to 4,5,6,7,8,9,12,11,10,13,16,17,18,14,15,19,20,21,22,23).

| id | before: name | slot | fill | width | head place | after: name | slot | fill | width | head place |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 4 | [01] Player buffs (all) | 1@4 | blue | 240 | TOPRIGHT -282.5,-24.3 | [01] Player buffs (all) | 1@4 | blue | 240 | TOPRIGHT -282.5,-24.3 |
| 5 | [02] Weapon enchants | 2@4 | purple | 240 | - | [02] Weapon enchants | 2@4 | purple | 240 | - |
| 6 | [03] Player debuffs (all) | 2@4 | dispel | 240 | - | [03] Player debuffs (all) | 2@4 | dispel | 240 | - |
| 7 | [04] Offensive cooldowns | 1@7 | (text) | - | TOP 0,-140 | [04] Offensive cooldowns | 1@7 | (text) | - | TOP 0,-140 |
| 8 | [05] Defensive cooldowns | 2@7 | (text) | - | - | [05] Defensive cooldowns | 2@7 | (text) | - | - |
| 9 | [06] Raid cooldowns | 3@7 | (text) | - | - | [06] Raid cooldowns | 3@7 | (text) | - | - |
| 10 | [07] Player buffs, short | 1@10 | gray | 240 | - | **[09] Player buffs, short** | **3@12** | **blue** | 240 | - |
| 11 | [08] Player cooldowns | 2@10 | blue | 240 | - | [08] Player cooldowns | **2@12** | **tan** | 240 | - |
| 12 | [09] Player special (mine) | 3@10 | #393939 | 240 | - | **[07] Player special (mine)** | **1@12** | #393939 | 240 | - |
| 13 | [10] Target special (mine) | 1@13 | gray | 240 | - | [10] Target special (mine) | 1@13 | gray | 240 | - |
| 14 | [11] Target debuffs (mine) | 2@13 | dispel | 240 | - | **[14] Target debuffs (mine)** | **5@13** | dispel | 240 | - |
| 15 | [12] Target buffs (mine) | 3@13 | blue | 240 | - | **[15] Target buffs (mine)** | **6@13** | blue | 240 | - |
| 16 | [13] Target crowd control | 4@13 | orange | 240 | - | **[11] Target crowd control** | **2@13** | orange | 240 | - |
| 17 | [14] Target cooldowns, players | 5@13 | tan | 240 | - | **[12] Target cooldowns, players** | **3@13** | tan | 240 | - |
| 18 | [15] Target cooldowns, NPCs | 6@13 | blue | 240 | - | **[13] Target cooldowns, NPCs** | **4@13** | **tan** | 240 | - |
| 19 | [16] Target stealable | 7@13 | blue | 266 | - | [16] Target stealable | 7@13 | blue | **240** | - |
| 20 | [17] Target debuffs (all) | 1@20 | (icons) | - | - | [17] Target debuffs (all) | 1@20 | (icons) | - | - |
| 21 | [18] Target buffs (all) | 2@20 | (icons) | - | - | [18] Target buffs (all) | 2@20 | (icons) | - | - |
| 22 | [19] Focus debuffs (mine) | 1@22 | dispel | 240 | - | [19] Focus debuffs (mine) | 1@22 | dispel | 240 | - |
| 23 | [20] Focus buffs (mine) | 2@22 | blue | 240 | - | [20] Focus buffs (mine) | 2@22 | blue | 240 | - |

- Left alone: `[01] Player buffs (all)`, place (not the old preset place).

**DefaultBackup** (20 containers): unchanged; no container carries a v22 preset name (a hand-built profile).

**DefaultBackupV3** (20 containers, 9 changed; containerOrder refilled to 4,5,6,7,8,9,12,11,10,13,16,17,18,14,15,19,20,21,22,23).

| id | before: name | slot | fill | width | head place | after: name | slot | fill | width | head place |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 4 | [01] Player buffs (all) | 1@4 | blue | 240 | TOPRIGHT -282.5,-24.3 | [01] Player buffs (all) | 1@4 | blue | 240 | TOPRIGHT -282.5,-24.3 |
| 5 | [02] Weapon enchants | 2@4 | purple | 240 | - | [02] Weapon enchants | 2@4 | purple | 240 | - |
| 6 | [03] Player debuffs (all) | 2@4 | dispel | 240 | - | [03] Player debuffs (all) | 2@4 | dispel | 240 | - |
| 7 | [04] Offensive cooldowns | 1@7 | (text) | - | TOP 0,-140 | [04] Offensive cooldowns | 1@7 | (text) | - | TOP 0,-140 |
| 8 | [05] Defensive cooldowns | 2@7 | (text) | - | - | [05] Defensive cooldowns | 2@7 | (text) | - | - |
| 9 | [06] Raid cooldowns | 3@7 | (text) | - | - | [06] Raid cooldowns | 3@7 | (text) | - | - |
| 10 | [07] Player buffs, short | 1@10 | gray | 240 | - | **[09] Player buffs, short** | **3@12** | **blue** | 240 | - |
| 11 | [08] Player cooldowns | 2@10 | blue | 240 | - | [08] Player cooldowns | **2@12** | **tan** | 240 | - |
| 12 | [09] Player special (mine) | 3@10 | blue | 240 | - | **[07] Player special (mine)** | **1@12** | blue | 240 | - |
| 13 | [10] Target special (mine) | 1@13 | gray | 240 | - | [10] Target special (mine) | 1@13 | gray | 240 | - |
| 14 | [11] Target debuffs (mine) | 2@13 | dispel | 240 | - | **[14] Target debuffs (mine)** | **5@13** | dispel | 240 | - |
| 15 | [12] Target buffs (mine) | 3@13 | blue | 240 | - | **[15] Target buffs (mine)** | **6@13** | blue | 240 | - |
| 16 | [13] Target crowd control | 4@13 | orange | 240 | - | **[11] Target crowd control** | **2@13** | orange | 240 | - |
| 17 | [14] Target cooldowns, players | 5@13 | tan | 240 | - | **[12] Target cooldowns, players** | **3@13** | tan | 240 | - |
| 18 | [15] Target cooldowns, NPCs | 6@13 | blue | 240 | - | **[13] Target cooldowns, NPCs** | **4@13** | **tan** | 240 | - |
| 19 | [16] Target stealable | 7@13 | blue | 266 | - | [16] Target stealable | 7@13 | blue | **240** | - |
| 20 | [17] Target debuffs (all) | 1@20 | (icons) | - | - | [17] Target debuffs (all) | 1@20 | (icons) | - | - |
| 21 | [18] Target buffs (all) | 2@20 | (icons) | - | - | [18] Target buffs (all) | 2@20 | (icons) | - | - |
| 22 | [19] Focus debuffs (mine) | 1@22 | dispel | 240 | - | [19] Focus debuffs (mine) | 1@22 | dispel | 240 | - |
| 23 | [20] Focus buffs (mine) | 2@22 | blue | 240 | - | [20] Focus buffs (mine) | 2@22 | blue | 240 | - |

- Left alone: `[01] Player buffs (all)`, place (not the old preset place).

**DefaultBackupv2** (20 containers, 1 changed; containerOrder kept).

| id | before: name | slot | fill | width | head place | after: name | slot | fill | width | head place |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 4 | [01] Player buffs (all) | 1@4 | blue | 240 | TOPRIGHT -282.3,-20 | [01] Player buffs (all) | 1@4 | blue | 240 | TOPRIGHT -282.3,-20 |
| 5 | [02] Weapon enchants | 2@4 | purple | 240 | - | [02] Weapon enchants | 2@4 | purple | 240 | - |
| 6 | [03] Player debuffs (all) | 2@4 | dispel | 240 | - | [03] Player debuffs (all) | 2@4 | dispel | 240 | - |
| 7 | [04] Offensive cooldowns | 1@7 | (text) | - | TOP 0,-250 | [04] Offensive cooldowns | 1@7 | (text) | - | TOP 0,-250 |
| 8 | [05] Defensive cooldowns | 2@7 | (text) | - | - | [05] Defensive cooldowns | 2@7 | (text) | - | - |
| 9 | [06] Raid cooldowns | 3@7 | (text) | - | - | [06] Raid cooldowns | 3@7 | (text) | - | - |
| 10 | [07] Player buffs, short | 2@12 | blue | 240 | - | [07] Player buffs, short | 2@12 | blue | 240 | - |
| 11 | [08] Player cooldowns | 3@12 | blue | 240 | - | [08] Player cooldowns | 3@12 | **tan** | 240 | - |
| 12 | [09] Player special (mine) | 1@12 | gray | 240 | - | [09] Player special (mine) | 1@12 | gray | 240 | - |
| 13 | [10] Target debuffs (mine) | 2@19 | dispel | 240 | - | [10] Target debuffs (mine) | 2@19 | dispel | 240 | - |
| 14 | [11] Target buffs (mine) | 3@19 | blue | 240 | - | [11] Target buffs (mine) | 3@19 | blue | 240 | - |
| 15 | [12] Target crowd control | 4@19 | orange | 240 | - | [12] Target crowd control | 4@19 | orange | 240 | - |
| 16 | [13] Target cooldowns, players | 5@19 | tan | 240 | - | [13] Target cooldowns, players | 5@19 | tan | 240 | - |
| 17 | [14] Target cooldowns, NPCs | 6@19 | blue | 240 | - | [14] Target cooldowns, NPCs | 6@19 | blue | 240 | - |
| 18 | [15] Target stealable | 7@19 | blue | 266 | - | [15] Target stealable | 7@19 | blue | 266 | - |
| 19 | [16] Target special (mine) | 1@19 | gray | 240 | - | [16] Target special (mine) | 1@19 | gray | 240 | - |
| 20 | [17] Target debuffs (all) | 2@21 | (icons) | - | - | [17] Target debuffs (all) | 2@21 | (icons) | - | - |
| 21 | [18] Target buffs (all) | 1@21 | (icons) | - | - | [18] Target buffs (all) | 1@21 | (icons) | - | - |
| 22 | [19] Focus debuffs (mine) | 1@22 | dispel | 240 | - | [19] Focus debuffs (mine) | 1@22 | dispel | 240 | - |
| 23 | [20] Focus buffs (mine) | 2@22 | blue | 240 | - | [20] Focus buffs (mine) | 2@22 | blue | 240 | - |

- Left alone: `[07] Player buffs, short`, color (not the old preset fill).
- Left alone: `[01] Player buffs (all)`, place (not the old preset place).
- Left alone: `[07] Player buffs, short`, tower (a member is not on the one before it).

**SmokeTest** (20 containers, 15 changed; containerOrder refilled to 4,5,6,7,8,9,12,11,10,13,14,15,16,17,18,19,20,21,22,23).

| id | before: name | slot | fill | width | head place | after: name | slot | fill | width | head place |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 4 | [01] Player buffs (all) | 1@4 | blue | 267 | CENTER 992,490 | [01] Player buffs (all) | 1@4 | blue | **240** | CENTER 992,490 |
| 5 | [02] Weapon enchants | 2@4 | purple | 267 | - | [02] Weapon enchants | 2@4 | purple | **240** | - |
| 6 | [03] Player debuffs (all) | 2@4 | dispel | 267 | - | [03] Player debuffs (all) | 2@4 | dispel | **240** | - |
| 7 | [04] Offensive cooldowns | 1@7 | (text) | - | TOP 0,-140 | [04] Offensive cooldowns | 1@7 | (text) | - | TOP 0,-140 |
| 8 | [05] Defensive cooldowns | 2@7 | (text) | - | - | [05] Defensive cooldowns | 2@7 | (text) | - | - |
| 9 | [06] Raid cooldowns | 3@7 | (text) | - | - | [06] Raid cooldowns | 3@7 | (text) | - | - |
| 10 | [07] Player buffs, short | 1@10 | gray | 266 | CENTER -340,-170 | **[09] Player buffs, short** | **3@12** | **blue** | **240** | **-** |
| 11 | [08] Player cooldowns | 2@10 | blue | 266 | - | [08] Player cooldowns | **2@12** | **tan** | **240** | - |
| 12 | [09] Player special (mine) | 3@10 | blue | 266 | - | **[07] Player special (mine)** | **1@12** | blue | **240** | **CENTER -340,-170** |
| 13 | [11] Target debuffs (mine) | 2@19 | dispel | 266 | - | [11] Target debuffs (mine) | 2@19 | dispel | **240** | - |
| 14 | [12] Target buffs (mine) | 3@19 | blue | 266 | - | [12] Target buffs (mine) | 3@19 | blue | **240** | - |
| 15 | [13] Target crowd control | 4@19 | orange | 266 | - | [13] Target crowd control | 4@19 | orange | **240** | - |
| 16 | [14] Target cooldowns, players | 5@19 | tan | 266 | - | [14] Target cooldowns, players | 5@19 | tan | **240** | - |
| 17 | [15] Target cooldowns, NPCs | 6@19 | blue | 266 | - | [15] Target cooldowns, NPCs | 6@19 | **tan** | **240** | - |
| 18 | [15] Target stealable | 7@19 | blue | 266 | - | [15] Target stealable | 7@19 | blue | 266 | - |
| 19 | [10] Target special (mine) | 1@19 | gray | 266 | CENTER 340,-170 | [10] Target special (mine) | 1@19 | gray | **240** | CENTER 340,-170 |
| 20 | [17] Target debuffs (all) | 1@20 | (icons) | - | BOTTOMLEFT 589,-822 | [17] Target debuffs (all) | 1@20 | (icons) | - | **BOTTOMLEFT 629,-822** |
| 21 | [18] Target buffs (all) | 2@20 | (icons) | - | - | [18] Target buffs (all) | 2@20 | (icons) | - | - |
| 22 | [19] Focus debuffs (mine) | 1@22 | dispel | 267 | BOTTOMLEFT 589,-611 | [19] Focus debuffs (mine) | 1@22 | dispel | **240** | **BOTTOMLEFT 629,-611** |
| 23 | [20] Focus buffs (mine) | 2@22 | blue | 267 | - | [20] Focus buffs (mine) | 2@22 | blue | **240** | - |

- Left alone: `[10] Target special (mine)`, tower (a role is missing or named twice).

**SmokeTest2** (3 containers, 3 changed; containerOrder kept).

| id | before: name | slot | fill | width | head place | after: name | slot | fill | width | head place |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | [01] Player buffs (all) | 1@1 | blue | 267 | TOPLEFT 861,-51 | [01] Player buffs (all) | 1@1 | blue | **240** | TOPLEFT 861,-51 |
| 2 | [02] Weapon enchants | 2@1 | blue | 267 | - | [02] Weapon enchants | 2@1 | blue | **240** | - |
| 3 | [03] Player debuffs (all) | 2@1 | dispel | 267 | - | [03] Player debuffs (all) | 2@1 | dispel | **240** | - |

- Left alone: `[01] Player buffs (all)`, place (not the old preset place).

**SmokeTest3** (3 containers, 3 changed; containerOrder kept).

| id | before: name | slot | fill | width | head place | after: name | slot | fill | width | head place |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | [01] Player buffs (all) | 1@1 | blue | 266 | CENTER 992,490 | [01] Player buffs (all) | 1@1 | blue | **240** | CENTER 992,490 |
| 2 | [02] Weapon enchants | 2@1 | purple | 266 | - | [02] Weapon enchants | 2@1 | purple | **240** | - |
| 3 | [03] Player debuffs (all) | 2@1 | dispel | 267 | - | [03] Player debuffs (all) | 2@1 | dispel | **240** | - |

**SmokeTest4** (3 containers, 3 changed; containerOrder kept).

| id | before: name | slot | fill | width | head place | after: name | slot | fill | width | head place |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | [01] Player buffs (all) | 1@1 | blue | 266 | CENTER 992,490 | [01] Player buffs (all) | 1@1 | blue | **240** | CENTER 992,490 |
| 2 | [02] Weapon enchants | 2@1 | purple | 266 | - | [02] Weapon enchants | 2@1 | purple | **240** | - |
| 3 | [03] Player debuffs (all) | 2@1 | dispel | 267 | - | [03] Player debuffs (all) | 2@1 | dispel | **240** | - |

**SmokeTest5** (20 containers, 16 changed; containerOrder refilled to 4,5,6,7,8,9,12,11,10,13,16,17,18,14,15,19,20,21,22,23).

| id | before: name | slot | fill | width | head place | after: name | slot | fill | width | head place |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 4 | [01] Player buffs (all) | 1@4 | blue | 266 | CENTER 992,490 | [01] Player buffs (all) | 1@4 | blue | **240** | CENTER 992,490 |
| 5 | [02] Weapon enchants | 2@4 | purple | 266 | - | [02] Weapon enchants | 2@4 | purple | **240** | - |
| 6 | [03] Player debuffs (all) | 2@4 | dispel | 267 | - | [03] Player debuffs (all) | 2@4 | dispel | **240** | - |
| 7 | [04] Offensive cooldowns | 1@7 | (text) | - | TOP 0,-140 | [04] Offensive cooldowns | 1@7 | (text) | - | TOP 0,-140 |
| 8 | [05] Defensive cooldowns | 2@7 | (text) | - | - | [05] Defensive cooldowns | 2@7 | (text) | - | - |
| 9 | [06] Raid cooldowns | 3@7 | (text) | - | - | [06] Raid cooldowns | 3@7 | (text) | - | - |
| 10 | [07] Player buffs, short | 1@10 | gray | 266 | CENTER -340,-170 | **[09] Player buffs, short** | **3@12** | **blue** | **240** | **-** |
| 11 | [08] Player cooldowns | 2@10 | blue | 266 | - | [08] Player cooldowns | **2@12** | **tan** | **240** | - |
| 12 | [09] Player special (mine) | 3@10 | blue | 266 | - | **[07] Player special (mine)** | **1@12** | blue | **240** | **CENTER -340,-170** |
| 13 | [10] Target special (mine) | 1@13 | gray | 266 | CENTER 340,-170 | [10] Target special (mine) | 1@13 | gray | **240** | CENTER 340,-170 |
| 14 | [11] Target debuffs (mine) | 2@13 | dispel | 266 | - | **[14] Target debuffs (mine)** | **5@13** | dispel | **240** | - |
| 15 | [12] Target buffs (mine) | 3@13 | blue | 266 | - | **[15] Target buffs (mine)** | **6@13** | blue | **240** | - |
| 16 | [13] Target crowd control | 4@13 | orange | 266 | - | **[11] Target crowd control** | **2@13** | orange | **240** | - |
| 17 | [14] Target cooldowns, players | 5@13 | tan | 266 | - | **[12] Target cooldowns, players** | **3@13** | tan | **240** | - |
| 18 | [15] Target cooldowns, NPCs | 6@13 | blue | 266 | - | **[13] Target cooldowns, NPCs** | **4@13** | **tan** | **240** | - |
| 19 | [16] Target stealable | 7@13 | blue | 266 | - | [16] Target stealable | 7@13 | blue | **240** | - |
| 20 | [17] Target debuffs (all) | 1@20 | (icons) | - | BOTTOMLEFT 589,-822 | [17] Target debuffs (all) | 1@20 | (icons) | - | **BOTTOMLEFT 629,-822** |
| 21 | [18] Target buffs (all) | 2@20 | (icons) | - | - | [18] Target buffs (all) | 2@20 | (icons) | - | - |
| 22 | [19] Focus debuffs (mine) | 1@22 | dispel | 267 | BOTTOMLEFT 589,-611 | [19] Focus debuffs (mine) | 1@22 | dispel | **240** | **BOTTOMLEFT 629,-611** |
| 23 | [20] Focus buffs (mine) | 2@22 | blue | 267 | - | [20] Focus buffs (mine) | 2@22 | blue | **240** | - |

