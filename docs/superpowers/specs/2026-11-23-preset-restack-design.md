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
4. **The untouched-seed record.** A profile whose `presets.seedPrint` matched its registry before the
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

Filled from the replay (`docs/superpowers/plans/2026-11-23-preset-restack.md`, APR-05).
