# Settings panel

How the options are organized, what each control does, and which schema key it writes. The rows
below are derived from the live schema (`NS.Schema`, 203 rows) by loading the addon headlessly and
walking it page → group → subgroup; a page, tab or row listed here that the schema does not produce
is a defect in this doc (documentation-§3).

## Pages at a glance

| Page | Tabs | Covers |
|---|---|---|
| Ka0s Aura Master (landing) | — untabbed (options-ui-§13) | Logo, the TOC's one-line Notes, and the slash command list generated from `NS.COMMANDS`. `/am` and `/am config` open the panel here |
| General | Master controls · Display · Spell Categories · Dispel Colors | Turn the addon off, when containers show at all, master scale and alpha, lock (unlocked shows the placeholder preview), debug console, the two resets; hiding Blizzard's buff and debuff frames; which spells each spell category matches, and one color per dispel type, both shared by every container |
| Containers | Containers | A top-level page (`N-1`, batch 7): create, select, rename, enable, unit, aura type and style of a container, and duplicate, delete, copy settings between containers |
| - Filters (sub-page of Containers, `N-2`) | What to show · Categories · Overrides · Sorting | Who cast it, timed or permanent, max duration, and the five-rank priority block at the foot of the tab; the Show/Hide category grids (weapon enchants among them); the whitelist and blacklist spell lists, each entry's verdict note; sort order and cap (per group). Tabs vary with the aura type |
| - Layout (sub-page of Containers, `N-2`) | Frame · Anchor · Growth · Mouse | Scale, opacity, strata and frame level; where the container sits (the screen, another container or a named frame, with what the mode does not read dimmed) and the frame picker; growth direction and spacing, the flow inherited from the parent while attached to a container; tooltips, cancel, click-through |
| - Bars (sub-page of Containers, `N-2`) | General · Icon · Background & border · Name text · Time text · Stack text · Highlights | The look of a container drawn as bars |
| - Icons (sub-page of Containers, `N-2`) | Size · Border · Cooldown · Time text · Stack text · Highlights | The look of a container drawn as icons |
| Profiles | — untabbed, drawn by AceConfigDialog (options-ui-§3) | Choose, create, copy, reset and delete profiles |

The `- ` prefix is the Settings tree's own nesting mark (`D6`): Filters, Layout, Bars and Icons are
registered under the Containers picker and their tree label carries `NS.SubPageLabel`'s two-space,
hyphen indent (`settings/OptionsSetup.lua`); their page KEY and their own page heading stay plain —
only the tree entry is marked.

## How the panel is built

- **The shell is `LibKa0s-Options-1.0`.** `settings/OptionsSetup.lua` builds `NS.Helpers` from a
  descriptor (`get`/`set`/`applyDefault` over the write seam, `rowsForPage` over
  `NS.SchemaForPage`, `skipRestoreAll`, `resetProfile`, `scheduleTimer`, the color codec) and the
  library draws the canvas, header, tab strip, two-column flow and widgets. The parent category
  registers eagerly at `PLAYER_LOGIN` through `NS.CreateOptionsPanel` (`core/AuraMaster.lua:42`) and every body is built on its first
  `OnShow` (options-ui-§5).
- **Every page renders through the tab strip**, one tab per schema `group` in declaration order
  (options-ui-§13). The landing page and Profiles are the two untabbed pages.
- **Four pages edit one container.** Filters, Layout, Bars and Icons are registered with
  `NS.RegisterContainerPage` and render through `Helpers.RenderContainerPage`, which is the container
  banner plus `Helpers.RenderTabbedPage` (`settings/OptionsSetup.lua`): the page's schema groups
  become tabs, the page's bespoke tabs follow (one may name the tab it is drawn ahead of, as
  General's Spell Categories does), and every row resolves against the selected container. These
  four are also sub-pages of Containers in the tree (`N-2`, `D6`) — their Blizzard subcategory
  registers under a marked label, but their page key, heading and everything above is unaffected.
  General and Containers are both addon-wide and render through `Helpers.RenderTabbedPage` with no
  banner; Containers' one tab edits the selected container's identity.
- **Rows that do not apply to the selected container are not drawn.** A row may carry `auraTypes`
  (`settings/Schema.lua:209`): the buff categories are not offered on a debuff container, and a
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
- **Containers** is the one exception, an accepted deviation from options-ui-§14
  (`docs/ARCHITECTURE.md` → Documented deviations). Its one tab edits the selected container, but its
  Container picker and **New container** sit on the first line of the tab body
  (`settings/Containers.lua`), and every act on the selected container (Duplicate, Delete,
  Copy settings from) follows its rows. The Containers page draws no banner. Drawn in the body, the
  picker and New are redrawn with the scroll, so a Delete's two refreshes cannot lose them.
- **The selection is shared.** Every banner writes one pointer, `NS.State.activeContainerId`, through
  `Helpers.SelectContainer`, which then re-renders every panel. The active tab survives a container
  change, so one surface can be compared across two containers.
- **The Defaults button stays page-wide**: on a container page it restores every row of that page, for
  the selected container. On General it restores the General rows of the profile only. On Containers
  it restores the selected container's Enabled, Unit, Aura type and Style; a container's name is
  never reset (its row carries `noReset`), and `/am reset container.name` says so and changes nothing.
  General's press also skips the **Minimap button** row — the only row any press skips because of
  what kind of setting it is rather than because it has no default (launcher-§3, the row below) — and
  the button's tooltip says so, since the row is on the page the player is looking at.
  Either press logs one `[Set] reset <page>: N rows` line, N the rows it changed (debug-logging-§10).
- **`noReset` does not reach Reset all settings, on purpose.** Reset all is a whole-profile reset
  (options-ui-§12, `db:ResetProfile`), not a row walk: it removes your own containers rather than
  renaming them, and brings the starter containers back under their shipped names. No name is
  reset to a default there, so the flag has nothing to guard. Spec G-1's "excluded from Reset all"
  is met that way, with no row flag involved.
- **Ratified 2026-09-13 (owner): a renamed container's name does not survive Reset all.** Because it
  is a whole-profile reset, it re-seeds the starter containers under their shipped names, so a
  starter you renamed comes back under its shipped name. The owner accepted this; it is not a
  deviation from G-1.

## Page → tab → row

Types: `bool` checkbox, `number` slider, `string` dropdown (or edit box where noted), `color` swatch.
Every `container.` path is relative to the selected container (`docs/schema.md`).

### General (18 rows, `settings/General.lua`, `settings/GeneralSpells.lua`)

**Master controls** — composed by the library's `MasterControls` from one declaration
(options-ui-§15), in canonical order, two per line:

| Row | Path | Type | Behavior |
|---|---|---|---|
| Enable Aura Master | `enabled` | bool | Gates every container; applied as a visibility pass, legal in combat |
| General visibility | `visibility` | string | `always` / `inCombat` / `outOfCombat` / `never`; combat read with `UnitAffectingCombat("player")` |
| Master scale | `scale` | number | Multiplies each container's own Layout → Frame scale |
| Master alpha | `alpha` | number | Multiplies each container's own Layout → Frame opacity; applied as a visibility pass, legal in combat |
| Lock frame | `locked` | bool | Unlocked shows every handle and the placeholder preview; locking ends it. The unlocked view is this addon's test mode, so Lock frame is its switch |
| Debug console | `state.debugConsole` | bool, session | Shows or hides the console window; never written to the profile |
| Minimap button | `global.minimap.hide` | bool | Shows or hides the minimap button. **The one row stored outside the profile** — the path is verbatim and absolute, and the table is LibDBIcon's own, in the GLOBAL store (launcher-§3). The label says SHOWN and the stored key says HIDDEN, so `settings/Schema.lua`'s read and write seams invert; the write also calls `NS.Launcher:SetShown`, so the button follows the checkbox at once. **No reset on this page moves it**: whether the button is shown is a per-installation display preference, so this page's **Defaults** button skips the row (`vetoedFromPanelReset`, `settings/OptionsSetup.lua`) and *Reset all settings* never reaches it. `/am reset global.minimap.hide` still restores it |

There is **no Test mode row**. Unlocking already shows every container's placeholder auras, so under
preview-mode's exception (standard v2.49.0) the unlocked view is the test mode: `testModePath` is not
passed to the composer and there is no `/am test` verb. Minimap button therefore opens the fourth
line alone, where an addon with a test mode would draw `[Minimap button] [Test mode]`.

**Reset all settings does not reach the Minimap button.** That control is a profile reset
(options-ui-§12) and the row is global, which is the reason launcher-§3 puts it there: a button the
player deliberately hid must not come back from a reset they asked for about something else.

Then the composed button pair: **Reset position** (`ContainerManager.ResetPositions` — every
container back to the screen, staggered) and **Reset all settings** (the `AURAMASTER_RESET_ALL`
popup, options-ui-§12's wording; accepting it is a profile reset). Its tooltip says so: *Reset the
current profile to its defaults — the same thing Profiles → Reset Profile does. Your other profiles
are not affected.* The descriptor's `profilesPage = true` picks that wording (LibKa0s-Options 18).

**Display**

| Subgroup | Row | Path | Type | Behavior |
|---|---|---|---|---|
| Blizzard frames | Hide Blizzard buffs | `hideBlizzardBuffs` | bool | Reparents `BuffFrame` (and the weapon enchants in it); out of combat |
| Blizzard frames | Hide Blizzard debuffs | `hideBlizzardDebuffs` | bool | Reparents `DebuffFrame`; out of combat |

**Spell Categories** — bespoke, and profile-wide: every container shares these lists. A **Category**
dropdown of the nine spell categories (defensives, activeMitigation, raidCDs, offensiveCDs, healing,
support, movement, utility, consumables) **plus Weapon enchants** (schema v3). Every entry but Weapon
enchants draws that category's ID list (the library's `IdList`):
**Add a spell** takes a spell id, a shift-clicked link or a name. While you type, a dropdown lists
the matching spells (the library's suggestions, LibKa0s issue #31), each with its rank where the
client gives one; a click, or Up/Down then Enter, picks one. The client finds a spell by name only
in the character's spellbook and cannot list any other, so the page hands the library `candidates`:
every category's starters, every spell the profile's categories edit, every spell on any
container's whitelist or blacklist, and the timed buffs Aura Master has learned. A name two of
them share is refused until one is picked ("pick one from the list, or use the id"), never
resolved to one rank; a name neither knows adds nothing, and the line under the box says where
names come from (the library's spell hint, localized, which the tooltip quotes too). Then one line
per starter spell with a checkbox
(untick to leave it out) and one per added spell with **Remove**, then **Restore this category's
starter list**. Writes the whole set to `categorySpells` (a carve-out, so every container re-applies).
The page's Defaults does not touch these lists; each category's restore does.

Choosing **Weapon enchants** draws something else entirely: three toggles, one per weapon slot
(Main hand, Off hand, Ranged; `enchantSlots.<slot>`, profile-wide, all on by default, schema v3), and
a line saying that whether a container shows enchants at all is that container's own Filters →
Categories row, with a link back. Unticking every slot here does not turn enchants off anywhere — a
container reads all three anyway — because the container-level Hide on Filters → Categories is the
one switch for that; the tab says so.

**Dispel Colors** — one line saying who reads the colors, then six swatches, `dispelColors.Magic`,
`.Curse`, `.Disease`, `.Poison`, `.Bleed`, `.None`: the fill of a bar colored by dispel type. They
drive bars only; an icon's dispel border keeps Blizzard's own colored art (owner, 2026-09-13), and
the tab line and each row's tooltip say so. Profile-wide, so a write re-applies every container.

### Containers (5 rows, `settings/Containers.lua`)

A top-level page (`N-1`, batch 7 — formerly General's third tab), one tab, **Containers**. The tab
body opens with the Container picker and **New container** (a player-buff bar container, then
selected) on one line. With no container, that line and one sentence are all the tab draws.

| Row | Path | Type | Behavior |
|---|---|---|---|
| Name | `container.name` | string, edit box | Non-blank; Enter applies; made unique; renames the handle and every picker; never reset (`noReset`) |
| Enabled | `container.enabled` | bool | A disabled container keeps its settings |
| *What it shows, and how* | — | subsection | An options-ui-§7 subgroup heading over the three rows below (batch 8): what the container watches and how it is drawn, against Name and Enabled's "which container is this". Name and Enabled carry no heading of their own — one above a tab's first row only repeats the tab |
| Unit | `container.unit` | string | `player` / `target` / `focus` / `pet`; structural |
| Aura type | `container.auraType` | string | Buffs / Debuffs / Weapon enchants; structural |
| Style | `container.style` | string | Bars / Icons; structural (rebuilds the engine) |

Changing Style resets Fill (Layout → Growth) to Columns for Bars and Text and to Rows for Icons;
re-choosing the same style keeps a Fill set by hand (B5).

Then **Duplicate** and **Delete** (asks first), and — with more than one container — **Copy settings
from**: a source dropdown, a "what to copy" dropdown (everything, or one of Filters, Layout, Mouse,
Bar style, Icon style) and **Copy onto this container**. Name and position are never copied.

### Filters (41 rows, `settings/Filters.lua`) — sub-page of Containers (`N-2`, `D6`)

Every tab opens with the container's warnings in orange — what the engine will silently not honor
here (`Helpers.RenderWarnings`, from `FilterCompiler.Compile`'s `warnings`).

**What to show**

| Row | Path | Type | Applies to | Behavior |
|---|---|---|---|---|
| Cast by | `container.filter.castBy` | string | buffs, debuffs | Anyone / Me (and my pet) → `PLAYER` / Anyone but me → `!PLAYER` |
| Duration | `container.filter.durationMode` | string | buffs, debuffs | Any / only with a duration (`maxDuration = huge`) / only without (learned exclusions) |
| Max duration | `container.filter.maxDuration` | number 0–3600, seconds; 0 = no limit | buffs, debuffs | An upper bound only — there is no minimum (`docs/scope.md`). Engine `maxDuration`; also hides permanent auras; ignored in "without" mode. A **Preset** dropdown beside it (`30s · 1m · 5m · 10m · 30m · No limit`, `D-2`) writes the same path; a stored value matching no preset leaves the dropdown blank rather than snapping the slider |

Weapon enchants are the `weaponEnchants` row on the Categories grid (schema v3, B3): Show (the
default) appends the enchant slots to a player buff container, Hide takes them away. The slots drawn
come from the profile-wide `enchantSlots`. `Hide enchants without a duration` keeps its own path
(`container.filter.hidePermanentEnchants`, bool, buffs and enchants) but moves in with the category
group, `skipRender`, so the Categories tab draws it under the `weaponEnchants` row.

**Categories** (`F-1`…`F-7`) — the grids and nothing above them: the five-rank priority block moved
to the foot of **What to show** in batch 8 (see *Filter priority* below), off both this tab and
Overrides. The per-container **Only these categories** toggle
(`container.filter.onlyShown`) that used to sit here is RETIRED (batch 7 fix round 2): once
`Uncategorized = Hide` correctly suppresses the catch-all on its own, on EITHER aura type (fix round
3 restored the debuff row fix round 1 had dropped), the toggle had nothing left to do, so the owner
chose one control over two. A stored `onlyShown = true` is migrated to `categories.uncategorized`
(buffs) or `categories.uncategorizedDebuffs` (debuffs) `= "hide"` (schema v4, `docs/schema.md`) and
the key cleared; only a container of some other, unrecognized shape has no category to migrate onto,
and loses the narrowing — named and printed to the player directly (`NS.Print`), not left to the
debug console. Then 34 generated rows, one per `defaults/Categories.lua` entry, at
`container.filter.categories.<key>`, stored `"show"` / `"hide"` (schema v3) and labeled **Show** /
**Hide** (`/am get` and `/am list` print the label, then the stored value in gray). Show is a
positive claim: an aura in at least one Show category is drawn even if another of its categories says
Hide; only an aura whose every category says Hide is removed by them (rank 3 of the priority order).
Buff containers see the 17 buff rows, debuff containers 17 debuff rows — each list's last row is its
own `Uncategorized`, asymmetric between the two (`Cat.HARMFUL` has no `spells`-kind category for its
row to be a complement of, batch 7 fix round 3): on a buff container Show rescues an unlisted aura
from another category's Hide; on a debuff container Show changes nothing at all (there is no spell
list for it to be outside of), and only Hide does anything — reproducing the retired toggle exactly.
Under the Spell Categories grid, a line states the cost of the buff row's default (Show): hiding a
Blizzard category alone does little while it stays Show, since it keeps rescuing unlisted auras; both
rows need Hide to actually remove one. The rows carry `skipRender`, so the flow engine draws nothing
for them; the tab is bespoke
(keyed by the group's name) and draws one `ChoiceGrid` per row `grid`, each a header line
`Show · Hide · Category` and then a line of two cells (an ordinary checkbox check on the lit one,
LibKa0s v1.36.0's `O.ChoiceGrid`, the yellow fill withdrawn in v1.36.2) and the category's label
(hover it for its description). A grid
with no row for the aura type is not drawn.

| Grid (`grid`) | Buff categories | Debuff categories |
|---|---|---|
| Blizzard Categories (`blizzard`) | bigDefensive, externals, important, castable, cancelable, stealable | crowdControl, boss, role, priority, raid, raidInCombat, groupDispellable, dispellable |
| Spell Categories (`custom`) | defensives, activeMitigation, raidCDs, offensiveCDs, healing, support, movement, utility, consumables, **weaponEnchants**, **uncategorized** (last) | **uncategorizedDebuffs** (last, fix round 3) |
| Dispel Types (`dispel`) | — | dispels, magic, curse, disease, poison, bleed |
| Who Cast It (`who`) | — | fromNonPlayers, fromPlayers |

The **Spell Categories** grid (renamed from Custom Categories, `F-1`) carries one extra line above
it — saying these are the lists on General → Spell Categories, shared by every container — but only
when the grid this container drew actually holds a `spells`- or `enchant`-kind row (batch 7, `T-2`
fix round 4): true on a buff container, false on a debuff one, whose grid is `uncategorizedDebuffs`
alone, a Show/Hide flag over the catch-all rather than a list of anything. It also carries one extra
column: a **See spells** link (`K-2`) on every `spells`- or `enchant`-kind row, which selects that
category on General → Spell Categories, opens the General page and switches to its Spell Categories
tab (`NS.GeneralSpells.Select`, `NS.OpenOptionsPage`, `H.SelectTab`). Right under that grid — ahead
of the Uncategorized cost note below — sits **Hide enchants without a duration**
(`container.filter.hidePermanentEnchants`, bool, buffs and enchants), behind a one-line tie naming
the `weaponEnchants` row it governs by name (batch 7, `T-3`: the grid draws its rows atomically and
cannot host a plain bool inline, so the tie text is what keeps it from reading as floating); an
`ENCHANT`-type container, which draws no Spell Categories grid at all, still sees the checkbox on its
own, with no tie line (there is no row above to tie it to).

**Sorting**

| Row | Path | Type | Applies to |
|---|---|---|---|
| Sort by | `container.filter.sortMethod` | string (9 methods) | buffs, debuffs |
| Direction | `container.filter.sortDirection` | string | every type (also orders weapon enchants) |
| Max auras (0 = no limit) | `container.filter.maxAuras` | number 0–40 | buffs, debuffs; per group |

**Overrides** (buff and debuff containers, the third tab since batch 8 — it sits beside Categories,
the other half of the same decision, and Sorting is last) — bespoke: a **Whitelist** and a **Blacklist**
section, each the library's `IdList` in spell mode over `container.filter.whitelist` /
`container.filter.blacklist`, adding by spell id, link or name with the same suggestions,
candidates, refusals and tooltip as General → Spell Categories (one `candidates()` and one set of
words, `NS.GeneralSpells`), each entry with **Remove**. Each set is written whole through the seam's carve-out;
the lists are not schema rows, so the page's Defaults leaves them alone. Each entry also carries a
trailing **note** under its name (LibKa0s v1.36.0's `O.IdList` `note`, `K-3`), built from
`FC.ExplainSpell` sparingly: it fires only when a category genuinely disagrees with the list's
verdict, or the id sits on both lists, and never claims what the aura will finally do — a duration cap
or Cast by can still keep it off screen even where the lists and categories alone would draw it. Batch
7 fix round 2 retired the one exception this used to carry (an "only these categories" container with
nothing else Shown, whose whitelist entry really was the only thing keeping an aura on screen): rank 5
can no longer be "hidden" at all once the toggle is gone, so every note stays non-definite now.

**Filter priority.** The five ranks, highest first, are stated in ONE place — the foot of the **What
to show** tab (`P-1`, `P-4`), under the heading *Which aura wins*: a lead-in in the normal font, then
one rank per line in `GameFontHighlight` with a hairline gap between them. Before batch 8 the same
five lines were restated at the top of both Categories and Overrides, which put a wall of small text
above the controls on two tabs at once. The wording is unchanged, and drives `FC.ExplainSpell`, the
per-entry notes above: (1) on the Overrides whitelist — always shown; (2) on the Overrides blacklist
— hidden, unless the whitelist already claimed it; (3) in at least one category set to Show — shown,
even if another of its categories says Hide; (4) in categories that all say Hide — hidden; (5) in no
category at all — shown, nothing removed it. Full detail and how it compiles: `docs/ARCHITECTURE.md`
→ Filter priority.

A weapon-enchant container drops **What to show** and **Overrides** entirely (neither has a row that
means anything for it, and with What to show goes the priority block — it has no whitelist, no
blacklist and no categories to rank) and sees only **Categories** — just **Hide enchants without a duration**,
since it draws no Spell Categories grid (`Cat.For("ENCHANT")` is empty) — and **Sorting**, just
**Direction**.

### Layout (26 rows, `settings/Layout.lua`) — sub-page of Containers (`N-2`, `D6`)

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

### Bars (71 rows, `settings/Bars.lua`) — sub-page of Containers (`N-2`, `D6`)

When the selected container is drawn as icons, a small muted-gold note heads every tab — "Not in use: this
container is drawn as icons. Set its Style to Bars on the Containers page to use these settings." —
and every control below it is drawn disabled (the spec's `disabledFor`,
`settings/OptionsSetup.lua`'s drawDisabledNotice). It was a large orange banner until batch 8, which
shouted for what is an aside; orange is left to the engine warnings, which can head the same page.
The tabs and the container picker stay live.

| Tab | Rows (all under `container.bars.`) |
|---|---|
| General (14) | *Size:* `width` 40–600, `height` 6–80; *Fill:* the composed bar block `barTexture` · `barAlpha` / `barColor` · `useClassColorBar`, then `colorMode` (one color / by dispel type), `drain` (toward left / right), `smooth`; *Spark:* `spark`, `sparkWidth` 1–32, `sparkColor` · `useClassColorSpark`, `sparkTimeless` (show the spark on auras without a duration) |
| Icon (9) | *Icon:* `icon` (left / right / hidden), `iconSize` 0–80 (0 = bar height), `iconGap` 0–20, `iconZoom` 0–0.3; *Icon border:* the composed border block on the icon's leaves `iconBorderShow`, `iconBorderStyle` · `iconBorderSize` / `iconBorderColor` · `useClassColorIconBorder` |
| Background & border (9) | *Background:* the composed bar block on the background leaves `bgTexture` · `bgAlpha` / `bgColor` · `useClassColorBg`; *Border:* the composed border block `borderShow`, `borderStyle` · `borderSize` / `borderColor` · `useClassColorBorder` |
| Name text (11) | *Font:* the composed font block on `name.` (`font` · `fontSize` / `fontColor` · `useClassColorFont` / `fontFlags` · `fontShadow`); *Placement:* `name.show`, `name.justify`, `name.point`, `name.x`, `name.y` |
| Time text (12) | The same on `time.`, plus *Countdown:* `timeFormat` (Blizzard / short / detailed) |
| Stack text (11) | The same on `stacks.` |
| Highlights (5) | *Running out:* `expiringColorOn`, `expiringThreshold` 1–60, `expiringColor`; *Refresh window:* `pandemic`, `pandemicColor`. The dispel type colors are the profile's, on General → Dispel Colors |

Behavior worth knowing: the fill is anchored to the edge of an invisible elapsed-time status bar, so
a permanent aura draws full and `drain` picks which end empties (`modules/Style_Bars.lua:161`);
`sparkTimeless` off clips a live spark to the elapsed region, which a timeless aura leaves empty
(docs/midnight-quirks.md); the icon border takes the icon's whole box and the art is inset inside it;
`smooth` selects the engine's eased interpolation; `colorMode = dispel` hands the fill to the engine
as a dispel-type texture tinted from the profile's `dispelColors` (General → Dispel Colors); every `timeFormat` hands the engine a
`SecondsFormatter` that rounds up, Blizzard's being a copy of the engine's own
(`Compat.CreateSecondsFormatter`, `core/Compat.lua:174`); the running-out color is a step color curve over
remaining time (`Compat.ExpiringTextColor`, `core/Compat.lua:196`); the refresh-window highlight is an additive wash the engine
shows only while the aura can be refreshed without loss.

The Background subgroup is a bar group, not options-ui-§16's background clause. That clause gives a
surface with no texture a swatch and its companion and nothing else, and this background has a live
texture, so it takes the whole bar block with its own tooltips. `bgAlpha` multiplies onto the
background texture, and `bgColor`'s own alpha still applies, so the default look is unchanged.

### Icons (42 rows, `settings/Icons.lua`) — sub-page of Containers (`N-2`, `D6`)

Bars folded its two-slider `Size` tab into a renamed `General` tab (`S-1`) because a whole tab for
two sliders did not earn its place. Icons keeps its own `Size` tab as-is: this page has no
`Bar`-shaped tab to rename it into, and `Size` (width, height, zoom) is a coherent "the icon's box"
group that would land arbitrarily inside `Border` or `Cooldown` if folded there — the two pages are
deliberately not made to match shape-for-shape (`settings/Icons.lua`).

When the selected container is drawn as bars, the same small muted-gold note heads every tab — "Not in
use: this container is drawn as bars. Set its Style to Icons on the Containers page to use these
settings." — and every control is drawn disabled, as on the Bars page.

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
`MasterControls`) and `MASTER_GROUP` (every member a page file touches at file load), and a real
`RestoreAllDefaults` (one bulk act under `NS.Bulk.Run`, logged once by `NS.OnProfileReset`), so
every row still registers and `/am list|get|set` and the defaults keep working. Every other function
member of the live instance, this addon's decorations (`SelectContainer`, `ContainerPickerCell`,
`RenderTabbedPage`, …) included, is carried as a no-op, so no call site finds a member missing
(testing-§8); the library's layout and composer constants, `AceGUI` and `LSMValues` are not copied.
The panel itself (`CreateOptionsPanel`, `OpenOptionsPanel`) answers one line naming the missing
library. `tests/degraded_env.lua` builds that environment for the suite, and
`tests/test_surface_parity.lua` compares its member set against the live instance.
