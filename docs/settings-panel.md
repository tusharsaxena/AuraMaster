# Settings panel

How the options are organized, what each control does, and which schema key it writes. The rows
below are derived from the live schema (`NS.Schema`, 199 rows) by loading the addon headlessly and
walking it page → group → subgroup; a page, tab or row listed here that the schema does not produce
is a defect in this doc (documentation-§3).

## Pages at a glance

| Page | Tabs | Covers |
|---|---|---|
| Ka0s Aura Master (landing) | — untabbed (options-ui-§13) | Logo, the TOC's one-line Notes, and the slash command list generated from `NS.COMMANDS` |
| General | Master controls · Display · Containers · Spell Categories · Dispel Colors | Turn the addon off, when containers show at all, master scale and alpha, lock, debug console, the two resets; preview mode and hiding Blizzard's buff and debuff frames; create, select, rename, enable, unit, aura type and style of a container, and duplicate, delete, copy settings between containers; which spells each spell category matches, and one color per dispel type, both shared by every container |
| Filters | What to show · Categories · Sorting · Overrides | Who cast it, timed or permanent, max duration, weapon enchants; the Default / Whitelist / Blacklist category grids; sort order and cap; the whitelist and blacklist spell lists. Tabs vary with the aura type |
| Layout | Frame · Anchor · Growth · Mouse | Attach to the screen, a container or a named frame, and the frame picker; growth direction and spacing; scale, opacity, strata; tooltips, cancel, click-through |
| Bars | Size · Bar · Icon · Background & border · Name text · Time text · Stack text · Highlights | The look of a container drawn as bars |
| Icons | Size · Border · Cooldown · Time text · Stack text · Highlights | The look of a container drawn as icons |
| Profiles | — untabbed, drawn by AceConfigDialog (options-ui-§3) | Choose, create, copy, reset and delete profiles |

## How the panel is built

- **The shell is `LibKa0s-Options-1.0`.** `settings/OptionsSetup.lua` builds `NS.Helpers` from a
  descriptor (`get`/`set`/`applyDefault` over the write seam, `rowsForPage` over
  `NS.SchemaForPage`, `skipRestoreAll`, `resetProfile`, `scheduleTimer`, the color codec) and the
  library draws the canvas, header, tab strip, two-column flow and widgets. The parent category
  registers eagerly at `PLAYER_LOGIN` (`core/AuraMaster.lua:38`) and every body is built on its first
  `OnShow` (options-ui-§5).
- **Every page renders through the tab strip**, one tab per schema `group` in declaration order
  (options-ui-§13). The landing page and Profiles are the two untabbed pages.
- **Four pages edit one container.** Filters, Layout, Bars and Icons are registered with
  `NS.RegisterContainerPage` and render through `Helpers.RenderContainerPage`, which is the container
  banner plus `Helpers.RenderTabbedPage` (`settings/OptionsSetup.lua`): the page's schema groups
  become tabs, the page's bespoke tabs follow (one may name the tab it is drawn ahead of, as
  General's Spell Categories does), and every row resolves against the selected container.
  General is addon-wide and renders through `Helpers.RenderTabbedPage` with no banner; its
  Containers tab edits the selected container.
- **Rows that do not apply to the selected container are not drawn.** A row may carry `auraTypes`
  (`settings/Schema.lua:171`): the buff categories are not offered on a debuff container, and a
  weapon-enchant container sees only the rows that mean something for it.
- **Structural rows re-render the panel.** Changing a container's unit, aura type or style, or its
  attach mode, calls `NS.RequestPanelRefresh` (next frame, coalesced), because the set of rows other
  pages offer changes with it. Every `CONTAINERS_CHANGED` does the same.
- **A tab switch is not combat-guarded** (options-ui-§13); opening the window or a category is
  refused under lockdown with the library's gray notice (options-ui-§2).

## The container banner and the one-row band

A page that edits one of many containers says which one, in the band above its tab strip, and that
band holds **the picker itself** (options-ui-§14):

- **Filters, Layout, Bars, Icons** draw `Helpers.ContainerBanner` — a Container dropdown built through
  the library's `PageBanner`, labeled with each container's unit, aura type and style. It is the
  page's only picker.
- **General → Containers** is the one exception, an accepted deviation from options-ui-§14
  (`docs/ARCHITECTURE.md` → Documented deviations). The tab edits the selected container, but its
  Container picker and **New container** sit on the first line of the tab body
  (`settings/GeneralContainers.lua`), and every act on the selected container (Duplicate, Delete,
  Copy settings from) follows its rows. The General page draws no banner, and its first tab stays
  Master controls (options-ui-§15). Drawn in the body, the picker and New are redrawn with the scroll,
  so a Delete's two refreshes cannot lose them.
- **The selection is shared.** Every banner writes one pointer, `NS.State.activeContainerId`, through
  `Helpers.SelectContainer`, which then re-renders every panel. The active tab survives a container
  change, so one surface can be compared across two containers.
- **The Defaults button stays page-wide**: on a container page it restores every row of that page, for
  the selected container. On General it restores the General rows of the profile, and the selected
  container's Enabled, Unit, Aura type and Style; a container's name is never reset (its row carries
  `noReset`), and `/am reset container.name` says so and changes nothing. Either press logs
  one `[Set] reset <page>: N rows` line, N the rows it changed (debug-logging-§10).
- **`noReset` does not reach Reset all settings, on purpose.** Reset all is a whole-profile reset
  (options-ui-§12, `db:ResetProfile`), not a row walk: it removes your own containers rather than
  renaming them, and brings the starter containers back under their shipped names. No name is
  reset to a default there, so the flag has nothing to guard. Spec G-1's "excluded from Reset all"
  is met that way, with no row flag involved.

## Page → tab → row

Types: `bool` checkbox, `number` slider, `string` dropdown (or edit box where noted), `color` swatch.
Every `container.` path is relative to the selected container (`docs/schema.md`).

### General (20 rows, `settings/General.lua`, `settings/GeneralContainers.lua`, `settings/GeneralSpells.lua`)

**Master controls** — composed by the library's `MasterControls` from one declaration
(options-ui-§15), in canonical order, two per line:

| Row | Path | Type | Behavior |
|---|---|---|---|
| Enable Aura Master | `enabled` | bool | Gates every container; applied as a visibility pass, legal in combat |
| General visibility | `visibility` | string | `always` / `inCombat` / `outOfCombat` / `never`; combat read with `UnitAffectingCombat("player")` |
| Master scale | `scale` | number | Multiplies each container's own Layout → Frame scale |
| Master alpha | `alpha` | number | Multiplies each container's own Layout → Frame opacity; applied as a visibility pass, legal in combat |
| Lock frame | `locked` | bool | Unlocked shows every handle and the preview; locking ends preview mode |
| Debug console | `state.debugConsole` | bool, session | Shows or hides the console window; never written to the profile |

Then the composed button pair: **Reset position** (`ContainerManager.ResetPositions` — every
container back to the screen, staggered) and **Reset all settings** (the `AURAMASTER_RESET_ALL`
popup, options-ui-§12's wording; accepting it is a profile reset). Its tooltip says so: *Reset the
current profile to its defaults — the same thing Profiles → Reset Profile does. Your other profiles
are not affected.* The descriptor's `profilesPage = true` picks that wording (LibKa0s-Options 18).

**Display**

| Subgroup | Row | Path | Type | Behavior |
|---|---|---|---|---|
| Preview | Show placeholder auras | `state.preview` | bool, session | `ContainerManager.SetPreview`; off at `/reload` |
| Blizzard frames | Hide Blizzard buffs | `hideBlizzardBuffs` | bool | Reparents `BuffFrame` (and the weapon enchants in it); out of combat |
| Blizzard frames | Hide Blizzard debuffs | `hideBlizzardDebuffs` | bool | Reparents `DebuffFrame`; out of combat |

**Containers** — the tab body opens with the Container picker and **New container** (a player-buff
bar container, then selected) on one line. With no container, that line and one sentence are all
the tab draws.

| Row | Path | Type | Behavior |
|---|---|---|---|
| Name | `container.name` | string, edit box | Non-blank; Enter applies; made unique; renames the handle and every picker; never reset (`noReset`) |
| Enabled | `container.enabled` | bool | A disabled container keeps its settings |
| Unit | `container.unit` | string | `player` / `target` / `focus` / `pet`; structural |
| Aura type | `container.auraType` | string | Buffs / Debuffs / Weapon enchants; structural |
| Style | `container.style` | string | Bars / Icons; structural (rebuilds the engine) |

Then **Duplicate** and **Delete** (asks first), and — with more than one container — **Copy settings
from**: a source dropdown, a "what to copy" dropdown (everything, or one of Filters, Layout, Mouse,
Bar style, Icon style) and **Copy onto this container**. Name and position are never copied.

**Spell Categories** — bespoke, and profile-wide: every container shares these lists. A **Category**
dropdown of the nine spell categories (defensives, activeMitigation, raidCDs, offensiveCDs, healing,
support, movement, utility, consumables), then that category's ID list (the library's `IdList`):
**Add a spell** takes a spell id, a shift-clicked link or a name (a name the client cannot find is
matched against every category's starters and the timed buffs Aura Master has learned; an unknown
one adds nothing and says why under the box), then one line per starter spell with a checkbox
(untick to leave it out) and one per added spell with **Remove**, then **Restore this category's
starter list**. Writes the whole set to `categorySpells` (a carve-out, so every container re-applies).
The page's Defaults does not touch these lists; each category's restore does.

**Dispel Colors** — one line saying who reads the colors, then six swatches, `dispelColors.Magic`,
`.Curse`, `.Disease`, `.Poison`, `.Bleed`, `.None`: the fill of a bar colored by dispel type, and the
tint on an icon's dispel border. Profile-wide, so a write re-applies every container.

### Filters (40 rows, `settings/Filters.lua`)

Every tab opens with the container's warnings in orange — what the engine will silently not honor
here (`Helpers.RenderWarnings`, from `FilterCompiler.Compile`'s `warnings`).

**What to show**

| Row | Path | Type | Applies to | Behavior |
|---|---|---|---|---|
| Cast by | `container.filter.castBy` | string | buffs, debuffs | Anyone / Me (and my pet) → `PLAYER` / Anyone but me → `!PLAYER` |
| Duration | `container.filter.durationMode` | string | buffs, debuffs | Any / only with a duration (`maxDuration = huge`) / only without (learned exclusions) |
| Max duration (sec, 0 = no limit) | `container.filter.maxDuration` | number 0–3600 | buffs, debuffs | Engine `maxDuration`; also hides permanent auras; ignored in "without" mode |
| *Weapon enchants:* Also show weapon enchants | `container.filter.includeEnchants` | bool | buffs | Appends the enchant slots on a player buff container |
| *Weapon enchants:* Hide enchants without a duration | `container.filter.hidePermanentEnchants` | bool | buffs, enchants | Engine `hidePermanent` |

**Categories** — 32 generated rows, one per `defaults/Categories.lua` entry, at
`container.filter.categories.<key>`, stored `""` / `"show"` / `"hide"` and labeled Default /
Whitelist / Blacklist (`/am get` and `/am list` print the label, then the stored value in gray).
Buff containers see the 16 buff rows, debuff containers the 16 debuff rows. The rows carry
`skipRender`, so the flow engine draws nothing for them; the tab is bespoke (keyed by the group's
name) and draws one `ChoiceGrid` per row `grid`, each a header line
`Default · Whitelist · Blacklist · Category` and then a line of three radios and the label per
category. A grid with no row for the aura type is not drawn.

| Grid (`grid`) | Buff categories | Debuff categories |
|---|---|---|
| Blizzard Categories (`blizzard`) | bigDefensive, externals, important, castable, cancelable, stealable | crowdControl, boss, role, priority, raid, raidInCombat, groupDispellable, dispellable |
| Custom Categories (`custom`) | defensives, activeMitigation, raidCDs, offensiveCDs, healing, support, movement, utility, consumables | — |
| Dispel Types (`dispel`) | — | dispels, magic, curse, disease, poison, bleed |
| Who Cast It (`who`) | — | fromNonPlayers, fromPlayers |

**Sorting**

| Row | Path | Type | Applies to |
|---|---|---|---|
| Sort by | `container.filter.sortMethod` | string (9 methods) | buffs, debuffs |
| Direction | `container.filter.sortDirection` | string | every type (also orders weapon enchants) |
| Max auras (0 = no limit) | `container.filter.maxAuras` | number 0–40 | buffs, debuffs; per group |

**Overrides** (buff and debuff containers) — bespoke: a **Whitelist** and a **Blacklist** section,
each the library's `IdList` in spell mode over `container.filter.whitelist` /
`container.filter.blacklist`, adding by spell id, link or name (a name the client cannot find is
matched against the spell categories' starters and the learned timed buffs, as on General → Spell
Categories), each entry with **Remove**. Each set is written whole through the seam's carve-out;
the lists are not schema rows, so the page's Defaults leaves them alone.

A weapon-enchant container sees only **What to show** (one row) and **Sorting** (one row).

### Layout (26 rows, `settings/Layout.lua`)

**Frame** — Scale `container.layout.scale` (0.5–3), Opacity `container.layout.alpha` (0–1, percent),
Strata `container.layout.strata`, Frame level `container.layout.level` (1–100).

**Anchor**

| Row | Path | Type | Behavior |
|---|---|---|---|
| Attach to | `container.attach.mode` | string | Screen / Another container / Named frame; structural |
| *Screen:* Point / Relative point | `container.position.point` / `.relativePoint` | string | Used in screen mode; set by dragging |
| *Screen:* X / Y | `container.position.x` / `.y` | number −2000–2000 | |
| *Another container:* Container | `container.attach.container` | number (dropdown) | Every other container, or None; a choice that would loop is refused; structural. Beside it (`pairWith`) a read-only line, "Attached by its *point* to the *relative point* of '*target*'", names the derived points |
| *Named frame:* Frame name | `container.attach.frame` | string, edit box | A global frame name; **Pick a frame…** beside it |
| *Named frame:* Point / Relative point | `container.attach.point` / `.relativePoint` | string | Corner of this container / of the frame |
| *Offset:* X offset / Y offset | `container.attach.x` / `.y` | number −500–500 | Used by both attached modes |

Each subsection's rows carry a `disabledIf` predicate on the selected container's attach mode, so
the ones the mode does not read are dimmed: in `screen` mode only Screen is live; in `container`
mode Another container and Offset; in `frame` mode Named frame and Offset. Changing **Attach to**
re-dims them on the same frame through the scalar refresh. **Pick a frame…** (closes the settings,
starts the picker, reopens this page) is Frame name's `pairWith` partner and stays live in every
mode, because a pick sets the mode to Named frame itself.

**Growth** — Fill `container.layout.axis` (rows or columns), Per row or column
`container.layout.perLine` (0–40, 0 is one line), Grow horizontally `container.layout.growH`, Grow
vertically `container.layout.growV`, Spacing `container.layout.spacing` (0–40), Line spacing
`container.layout.lineSpacing` (0–40).

**Inherited flow (L-6).** A container attached to another container continues that container's
flow. Its fill axis and both growth directions are its chain root's, resolved up the chain by
`Anchors.EffectiveLayout` (cycle-safe through `Anchors.WouldCycle`). Its anchor points come from
`Anchors.DerivedPoints`: a column parent stacks the child below it (above, when growing up), and a
row parent puts it beside it. `container.attach.point` / `.relativePoint` are read only in `frame`
mode; the offsets apply in both attached modes. `Container.FlowSettings`, `Preview.Offset` and the
handle's placement and clamp all read the effective layout. A write that moves a container's flow or
attachment re-applies every container following it (`Anchors.Followers`). On this tab, in that mode,
Fill, Grow horizontally and Grow vertically are dimmed and show the inherited values. They do that
through a row `panelGet` that only the panel descriptor reads; `/am get` and every module read the
stored values. The line "Fill and growth follow '*root*'" sits above them. Per row, Spacing and Line
spacing stay the container's own and stay live. The stored flow is never written, so a detach
restores it at the next apply. A container attached to a missing or looping target sits on the
screen and keeps its own flow.

**Frame and Mouse inherit nothing.** That was audited, not assumed: scale, opacity, strata and frame
level are applied to the container's own anchor in `ContainerClass:Apply` / `ApplyVisibility`, and
the Mouse rows are read per element by the stylers. Neither reads the chain.

**Mouse** — Show tooltips `container.behavior.tooltips`, Tooltips in combat
`container.behavior.tooltipInCombat`, Tooltip position `container.behavior.tooltipAnchor`,
Right-click to cancel `container.behavior.cancelOnRightClick` (only on a player buff or enchant
container), Click-through `container.behavior.clickThrough` (no tooltips and no clicks).

### Bars (71 rows, `settings/Bars.lua`)

When the selected container is drawn as icons, a large orange notice heads every tab, naming
General → Containers, and every control below it is drawn disabled (the spec's `disabledFor`,
`settings/OptionsSetup.lua`'s renderActiveTab). The tabs and the container picker stay live.

| Tab | Rows (all under `container.bars.`) |
|---|---|
| Size (2) | `width` 40–600, `height` 6–80 |
| Bar (12) | *Fill:* the composed bar block `barTexture` · `barAlpha` / `barColor` · `useClassColorBar`, then `colorMode` (one color / by dispel type), `drain` (toward left / right), `smooth`; *Spark:* `spark`, `sparkWidth` 1–32, `sparkColor` · `useClassColorSpark`, `sparkTimeless` (show the spark on auras without a duration) |
| Icon (9) | *Icon:* `icon` (left / right / hidden), `iconSize` 0–80 (0 = bar height), `iconGap` 0–20, `iconZoom` 0–0.3; *Icon border:* the composed border block on the icon's leaves `iconBorderShow`, `iconBorderStyle` · `iconBorderSize` / `iconBorderColor` · `useClassColorIconBorder` |
| Background & border (9) | *Background:* the composed bar block on the background leaves `bgTexture` · `bgAlpha` / `bgColor` · `useClassColorBg`; *Border:* the composed border block `borderShow`, `borderStyle` · `borderSize` / `borderColor` · `useClassColorBorder` |
| Name text (11) | *Font:* the composed font block on `name.` (`font` · `fontSize` / `fontColor` · `useClassColorFont` / `fontFlags` · `fontShadow`); *Placement:* `name.show`, `name.justify`, `name.point`, `name.x`, `name.y` |
| Time text (12) | The same on `time.`, plus *Countdown:* `timeFormat` (Blizzard / short / detailed) |
| Stack text (11) | The same on `stacks.` |
| Highlights (5) | *Running out:* `expiringColorOn`, `expiringThreshold` 1–60, `expiringColor`; *Refresh window:* `pandemic`, `pandemicColor`. The dispel type colors are the profile's, on General → Dispel Colors |

Behavior worth knowing: the fill is anchored to the edge of an invisible elapsed-time status bar, so
a permanent aura draws full and `drain` picks which end empties (`modules/Style_Bars.lua:168`);
`sparkTimeless` off clips a live spark to the elapsed region, which a timeless aura leaves empty
(docs/midnight-quirks.md); the icon border takes the icon's whole box and the art is inset inside it;
`smooth` selects the engine's eased interpolation; `colorMode = dispel` hands the fill to the engine
as a dispel-type texture tinted from the profile's `dispelColors` (General → Dispel Colors); every `timeFormat` hands the engine a
`SecondsFormatter` that rounds up, Blizzard's being a copy of the engine's own
(`core/Compat.lua:174`); the running-out color is a step color curve over
remaining time (`core/Compat.lua:196`); the refresh-window highlight is an additive wash the engine
shows only while the aura can be refreshed without loss.

The Background subgroup is a bar group, not options-ui-§16's background clause. That clause gives a
surface with no texture a swatch and its companion and nothing else, and this background has a live
texture, so it takes the whole bar block with its own tooltips. `bgAlpha` multiplies onto the
background texture, and `bgColor`'s own alpha still applies, so the default look is unchanged.

### Icons (42 rows, `settings/Icons.lua`)

When the selected container is drawn as bars, a large orange notice heads every tab and every
control is drawn disabled, as on the Bars page.

| Tab | Rows (all under `container.icons.`) |
|---|---|
| Size (3) | `width` 8–128, `height` 8–128 (a non-square icon is cropped, never squashed), `zoom` 0–0.3 |
| Border (6) | *Border:* the composed border block `borderShow`, `borderStyle` · `borderSize` / `borderColor` · `useClassColorBorder`, then `dispelBorder` |
| Cooldown (5) | `cooldown`, `cooldownReverse`, `cooldownEdge`, `swipeAlpha` 0–1, `blizzardNumbers` |
| Time text (12) | *Font:* the composed font block on `time.`; *Placement:* `time.show`, `.justify`, `.point`, `.x`, `.y`; *Countdown:* `timeFormat` |
| Stack text (11) | The same on `stacks.` without the countdown |
| Highlights (5) | *Running out:* `expiringColorOn`, `expiringThreshold`, `expiringColor`; *Refresh window:* `pandemic`, `pandemicColor` |

`dispelBorder` asks the engine to draw Blizzard's own debuff border art in the dispel color, on
harmful auras with a dispel type only. The art sits above your border and replaces it there; every
other icon shows your border. `blizzardNumbers` shows the cooldown frame's own countdown beside the time text.

### Profiles (`settings/Profiles.lua`)

No schema rows. `AceDBOptions:GetOptionsTable(NS.db)` is registered with AceConfig and drawn by
`AceConfigDialog:Open` into an AceGUI group inside the canvas, re-opened on every render. The page
opts out (its builder returns nil) when AceDBOptions, AceConfig, AceConfigDialog or AceGUI is missing.
See `docs/profiles.md`.

## Colors and the class-color companion

Every color that describes the player's taste has a **Use class color** checkbox immediately to its
right, default off, declared with `classColorSource = "unit"` on both rows (options-ui-§17). The
class is that of the unit the container tracks, read once per apply: a player container shows the
player's, a target container the target's, and a unit with no class (an NPC) falls through to the
swatch. The swatch is never disabled; its alpha applies under both modes.
With companions: Bars `barColor`, `sparkColor`, `bgColor`, `borderColor`, and `fontColor` on
`name`/`time`/`stacks`; Icons `borderColor`, and `fontColor` on `time`/`stacks`.

**Palette-definition swatches carry no companion** — they identify a state or a dispel type, not a
player, which is the one exemption options-ui-§17 makes: `expiringColor` and `pandemicColor` on both
pages, and the six `dispelColors.*` on General → Dispel Colors.

## The degraded panel

With `libs/LibKa0s/` missing, `settings/OptionsSetup.lua` installs a **load-completing** stub
(options-ui-§1): the five composers (`ColorPair`, `FontGroup`, `BorderGroup`, `BarGroup`,
`MasterControls`), `MASTER_GROUP`, a real `RestoreAllDefaults` (one bulk act under `NS.Bulk.Run`,
logged once by `NS.OnProfileReset`), and no-op refreshers — every member a
page file touches at file load — so every row still registers and `/am list|get|set` and the defaults
keep working. The panel itself answers one line naming the missing library. `tests/degraded_env.lua`
builds that environment for the suite.
