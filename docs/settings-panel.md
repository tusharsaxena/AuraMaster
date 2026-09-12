# Settings panel

How the options are organized, what each control does, and which schema key it writes. The rows
below are derived from the live schema (`NS.Schema`, 193 rows) by loading the addon headlessly and
walking it page → group → subgroup; a page, tab or row listed here that the schema does not produce
is a defect in this doc (documentation-§3).

## Pages at a glance

| Page | Tabs | Covers |
|---|---|---|
| Ka0s Aura Master (landing) | — untabbed (options-ui-§13) | Logo, the TOC's one-line Notes, and the slash command list generated from `NS.COMMANDS` |
| General | Master controls · Display | Turn the addon off, when containers show at all, master scale and alpha, lock, debug console, the two resets; preview mode and hiding Blizzard's buff and debuff frames |
| Containers | General · Overview | Create, select, rename, enable, unit, aura type and style of a container; duplicate, delete, copy settings between containers; a one-line overview of every container |
| Filters | What to show · Categories · Sorting · Spell lists · Always / never | Who cast it, timed or permanent, max duration, weapon enchants; the tri-state categories; sort order and cap; per-category spell edits; the always and never lists. Tabs vary with the aura type |
| Layout | Position · Growth · Frame · Mouse | Attach to the screen, a container or a named frame, and the frame picker; growth direction and spacing; scale, opacity, strata; tooltips, cancel, click-through |
| Bars | Size · Bar · Background & border · Name text · Time text · Stack text · Highlights | The look of a container drawn as bars |
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
- **Five pages edit one container.** Containers, Filters, Layout, Bars and Icons are registered with
  `NS.RegisterContainerPage` and render through `Helpers.RenderContainerPage`
  (`settings/OptionsSetup.lua:416`): the page's schema groups become tabs, the page's bespoke tabs
  follow, and every row resolves against the selected container. General is addon-wide.
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
- **Containers** has more page-wide acts than fit one row, so it takes the one-row-band escape: the
  band carries only the identity controls — the Container picker and **New container**
  (`settings/Containers.lua:232`) — and every act on the selected container (Duplicate, Delete, Copy
  settings from) sits on the page's first tab, named **General**. No page-wide act is drawn on any
  other tab. The band is not boxed a second time.
- **The selection is shared.** Every banner writes one pointer, `NS.State.activeContainerId`, through
  `Helpers.SelectContainer`, which then re-renders every panel. The active tab survives a container
  change, so one surface can be compared across two containers.
- **The Defaults button stays page-wide**: on a container page it restores every row of that page, for
  the selected container. On General it restores the General rows of the profile. Either press logs
  one `[Set] reset <page>: N rows` line, N the rows it changed (debug-logging-§10).

## Page → tab → row

Types: `bool` checkbox, `number` slider, `string` dropdown (or edit box where noted), `color` swatch.
Every `container.` path is relative to the selected container (`docs/schema.md`).

### General (9 rows, `settings/General.lua`)

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

### Containers (5 rows, `settings/Containers.lua`)

Band: Container picker · **New container** (a player-buff bar container, then selected).

**General**

| Row | Path | Type | Behavior |
|---|---|---|---|
| Name | `container.name` | string, edit box | Non-blank; Enter applies; made unique; renames the handle and every picker |
| Enabled | `container.enabled` | bool | A disabled container keeps its settings |
| Unit | `container.unit` | string | `player` / `target` / `focus` / `pet`; structural |
| Aura type | `container.auraType` | string | Buffs / Debuffs / Weapon enchants; structural |
| Style | `container.style` | string | Bars / Icons; structural (rebuilds the engine) |

Then **Duplicate** and **Delete** (asks first), and — with more than one container — **Copy settings
from**: a source dropdown, a "what to copy" dropdown (everything, or one of Filters, Layout, Mouse,
Bar style, Icon style) and **Copy onto this container**. Name and position are never copied.

**Overview** — bespoke: one line per container (name, unit, type, style, what it is attached to) with
a **Select** button.

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

**Categories** — 32 generated rows, one per `defaults/Categories.lua` entry, each a dropdown
`—` / Show / Hide at `container.filter.categories.<key>`. Buff containers see the 16 buff rows,
debuff containers the 16 debuff rows.

| Subgroup | Buff categories | Debuff categories |
|---|---|---|
| Spell lists | defensives, activeMitigation, raidCDs, offensiveCDs, coreHealing, lesserHealing, support, movement, utility, consumables | — |
| Blizzard flags | bigDefensive, externals, important, castable, cancelable, stealable | crowdControl, boss, role, priority, raid, raidInCombat, groupDispellable, dispellable |
| Dispel types | — | dispels, magic, curse, disease, poison, bleed |
| Who cast it | — | fromNonPlayers, fromPlayers |

**Sorting**

| Row | Path | Type | Applies to |
|---|---|---|---|
| Sort by | `container.filter.sortMethod` | string (9 methods) | buffs, debuffs |
| Direction | `container.filter.sortDirection` | string | every type (also orders weapon enchants) |
| Max auras (0 = no limit) | `container.filter.maxAuras` | number 0–40 | buffs, debuffs; per group |

**Spell lists** (buff containers only) — bespoke: a category dropdown, an **Add spell ID** box, one
checkbox per starter spell (untick to remove it) and per added spell, and **Restore this category's
starter list**. Writes the whole set to `container.filter.categorySpells`.

**Always / never** (buff and debuff containers) — bespoke: an add box and a list with **Remove** for
`container.filter.whitelist` and for `container.filter.blacklist`.

A weapon-enchant container sees only **What to show** (one row) and **Sorting** (one row).

### Layout (26 rows, `settings/Layout.lua`)

**Position**

| Row | Path | Type | Behavior |
|---|---|---|---|
| Attach to | `container.attach.mode` | string | The screen / Another container / A named frame; structural |
| Container | `container.attach.container` | number (dropdown) | Every other container, or None; a choice that would loop is refused |
| Frame name | `container.attach.frame` | string, edit box | A global frame name |
| Point | `container.attach.point` | string | Corner of this container |
| Relative point | `container.attach.relativePoint` | string | Corner of the target |
| X offset / Y offset | `container.attach.x` / `.y` | number −500–500 | |
| *On the screen:* Point / Relative point | `container.position.point` / `.relativePoint` | string | Used in screen mode; set by dragging |
| *On the screen:* X / Y | `container.position.x` / `.y` | number −2000–2000 | |

Then **Pick a frame…** (closes the settings, starts the picker, reopens this page) and **Attach to
the screen**.

**Growth** — Fill `container.layout.axis` (rows or columns), Per row or column
`container.layout.perLine` (0–40, 0 is one line), Grow horizontally `container.layout.growH`, Grow
vertically `container.layout.growV`, Spacing `container.layout.spacing` (0–40), Line spacing
`container.layout.lineSpacing` (0–40).

**Frame** — Scale `container.layout.scale` (0.5–3), Opacity `container.layout.alpha` (0–1, percent),
Strata `container.layout.strata`, Frame level `container.layout.level` (1–100).

**Mouse** — Show tooltips `container.behavior.tooltips`, Tooltips in combat
`container.behavior.tooltipInCombat`, Tooltip position `container.behavior.tooltipAnchor`,
Right-click to cancel `container.behavior.cancelOnRightClick` (only on a player buff or enchant
container), Click-through `container.behavior.clickThrough` (no tooltips and no clicks).

### Bars (71 rows, `settings/Bars.lua`)

A notice in orange heads every tab when the selected container is drawn as icons.

| Tab | Rows (all under `container.bars.`) |
|---|---|
| Size (6) | `width` 40–600, `height` 6–80; *Icon:* `icon` (left / right / hidden), `iconSize` 0–80 (0 = bar height), `iconGap` 0–20, `iconZoom` 0–0.3 |
| Bar (11) | *Fill:* the composed bar block `barTexture` · `barAlpha` / `barColor` · `useClassColorBar`, then `colorMode` (one color / by dispel type), `drain` (toward left / right), `smooth`; *Spark:* `spark`, `sparkWidth` 1–32, `sparkColor` · `useClassColorSpark` |
| Background & border (9) | *Background:* the composed bar block on the background leaves `bgTexture` · `bgAlpha` / `bgColor` · `useClassColorBg`; *Border:* the composed border block `borderShow`, `borderStyle` · `borderSize` / `borderColor` · `useClassColorBorder` |
| Name text (11) | *Font:* the composed font block on `name.` (`font` · `fontSize` / `fontColor` · `useClassColorFont` / `fontFlags` · `fontShadow`); *Placement:* `name.show`, `name.justify`, `name.point`, `name.x`, `name.y` |
| Time text (12) | The same on `time.`, plus *Countdown:* `timeFormat` (Blizzard / short / detailed) |
| Stack text (11) | The same on `stacks.` |
| Highlights (11) | *Running out:* `expiringColorOn`, `expiringThreshold` 1–60, `expiringColor`; *Refresh window:* `pandemic`, `pandemicColor`; *Dispel type colors:* `dispelColors.Magic`, `.Curse`, `.Disease`, `.Poison`, `.Bleed`, `.None` |

Behavior worth knowing: the fill is anchored to the edge of an invisible elapsed-time status bar, so
a permanent aura draws full and `drain` picks which end empties (`modules/Style_Bars.lua:108`);
`smooth` selects the engine's eased interpolation; `colorMode = dispel` hands the fill to the engine
as a dispel-type texture tinted from `dispelColors`; `timeFormat` other than Blizzard hands the engine
a `SecondsFormatter` (`core/Compat.lua:135`); the running-out color is a step color curve over
remaining time (`core/Compat.lua:168`); the refresh-window highlight is an additive wash the engine
shows only while the aura can be refreshed without loss.

The Background subgroup is a bar group, not options-ui-§16's background clause. That clause gives a
surface with no texture a swatch and its companion and nothing else, and this background has a live
texture, so it takes the whole bar block with its own tooltips. `bgAlpha` multiplies onto the
background texture, and `bgColor`'s own alpha still applies, so the default look is unchanged.

### Icons (42 rows, `settings/Icons.lua`)

A notice in orange heads every tab when the selected container is drawn as bars.

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
pages, and the six `bars.dispelColors.*`.

## The degraded panel

With `libs/LibKa0s/` missing, `settings/OptionsSetup.lua` installs a **load-completing** stub
(options-ui-§1): the five composers (`ColorPair`, `FontGroup`, `BorderGroup`, `BarGroup`,
`MasterControls`), `MASTER_GROUP`, a real `RestoreAllDefaults` (one bulk act under `NS.Bulk.Run`,
logged once by `NS.OnProfileReset`), and no-op refreshers — every member a
page file touches at file load — so every row still registers and `/am list|get|set` and the defaults
keep working. The panel itself answers one line naming the missing library. `tests/degraded_env.lua`
builds that environment for the suite.
