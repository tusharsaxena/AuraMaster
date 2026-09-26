# Settings panel

How the options are organized, what each control does, and which schema key it writes. The rows
below are derived from the live schema (`NS.Schema`, 258 rows on a profile with no categories of the
player's own — each of those adds one more `container.filter.categories.<key>` row at runtime) by
loading the addon headlessly and
walking it page → group → subgroup; a page, tab or row listed here that the schema does not produce
is a defect in this doc (documentation-§3).

## Pages at a glance

| Page | Tabs | Covers |
|---|---|---|
| Ka0s Aura Master (landing) | — untabbed (options-ui-§13) | Logo, the TOC's one-line Notes, and the slash command list generated from `NS.COMMANDS`. `/am` and `/am config` open the panel here |
| General | Master controls · Display · Spell Categories · Dispel Colors | Turn the addon off, when containers show at all, master scale and alpha, lock (unlocked shows the drag handles), debug console, test mode (placeholder auras), the two resets; hiding Blizzard's buff and debuff frames; which spells each spell category matches, and one color per dispel type, both shared by every container |
| Containers | General | A top-level page (`N-1`, batch 7): create, select, rename, enable, unit, aura type and style of a container, and duplicate, delete, copy settings between containers |
| - Filters (sub-page of Containers, `N-2`) | General · Categories · Overrides · Sorting | Who cast it, timed or permanent, max duration, and the five-rank priority block at the foot of the tab; the Show/Hide category grids (weapon enchants among them); the whitelist and blacklist spell lists, each entry's verdict in its "?" mark; sort order and cap (per group). Tabs vary with the aura type |
| - Layout (sub-page of Containers, `N-2`) | Frame · Anchor · Growth · Mouse · Label | Scale, opacity, strata and frame level; where the container sits (the screen, another container or a named frame, with only what the mode reads drawn) and the frame picker; growth direction and spacing, the flow inherited from the parent while attached to a container; tooltips, cancel, click-through; the optional name label |
| - Bars (sub-page of Containers, `N-2`) | General · Background & border · Name text · Time text · Stack text · Icon · Pandemic | The look of a container drawn as bars |
| - Icons (sub-page of Containers, `N-2`) | Size · Border · Cooldown · Time text · Stack text · Pandemic | The look of a container drawn as icons |
| - Text (sub-page of Containers, `N-2`) | General · Font · Icon · Pandemic · Animation | The look of a container drawn as text: what each line says, its font and its optional icon, its pandemic-window color and blink, its loop, and its opt-in dispel type colors |
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
  registers eagerly at `PLAYER_LOGIN` through `NS.CreateOptionsPanel` (`core/AuraMaster.lua:53`) and every body is built on its first
  `OnShow` (options-ui-§5).
- **Every page renders through the tab strip**, one tab per schema `group` in declaration order
  (options-ui-§13). The landing page and Profiles are the two untabbed pages.
- **Four pages edit one container.** Filters, Layout, Bars and Icons are registered with
  `NS.RegisterContainerPage` and render through `Helpers.RenderContainerPage`, which is the container
  banner plus `Helpers.RenderPage` (`settings/OptionsSetup.lua`). `RenderPage` maps the page's spec
  onto the library's `O.RenderTabbedSchema` (LibKa0s v1.56.0, `opts`: `tabs`, `cfg`, `disabledFor`,
  `disabledNotice`, `chrome`), which draws the tabbed page: the page's schema groups become tabs, the
  page's own tabs that the container's aura type admits follow (one keyed by a group takes that
  group's place and is handed its rows; one may name the tab it is drawn ahead of, as Filters'
  Overrides does), a stale active tab heals to the first, a page disabled for its container draws
  the muted-red notice above rows drawn disabled, and every row resolves against the selected
  container. The host keeps no tab renderer of its own (anti-pattern #47, `AuraMaster-R-04`). These
  four are also sub-pages of Containers in the tree (`N-2`, `D6`) — their Blizzard subcategory
  registers under a marked label, but their page key, heading and everything above is unaffected.
  General and Containers are both addon-wide and render through `Helpers.RenderPage`; General draws
  no banner, and Containers' one tab edits the selected container's identity.
- **Rows that do not apply to the selected container are not drawn.** A row may carry `auraTypes`
  (`settings/Schema.lua:370`): the buff categories and Hide enchants without a duration are not
  offered on a debuff container.
- **Structural rows re-render the panel.** Changing a container's unit, aura type or style, or its
  attach mode, calls `NS.RequestPanelRefresh` (next frame, coalesced), because the set of rows other
  pages offer changes with it. Every `CONTAINERS_CHANGED` does the same.
- **In combat a page is locked, by the library alone** (LibKa0s v1.46.1, options-ui-§2, §13). A page
  shown in combat, or open when combat starts, is covered whole, its bands and tab strip included,
  by a gray "Settings are locked during combat." cover and is not rendered; writes, Defaults,
  library-drawn buttons and tab switches are refused with one gray notice per combat
  (`settings are locked during combat — changes are refused until it ends`); the window is never
  closed. At `PLAYER_REGEN_ENABLED` the cover lifts and the page draws from current state, so a value
  `/am set` changed in combat shows. This addon adds no page or tab guard of its own. Opening the
  window or a category is refused under lockdown with the library's gray notice.

## The container banner and the one-row band

A page that edits one of many containers says which one, in the band above its tab strip, and that
band holds **the picker itself** (options-ui-§14):

- **Filters, Layout, Bars, Icons** draw `Helpers.ContainerBanner` — a Container dropdown built through
  the library's `PageBanner`, labeled with each container's unit, aura type and style. It is the
  page's only picker.
- **Containers** carries the page's identity controls in the band, as options-ui-§14 asks: its Container
  picker and **New container** on one row: `Helpers.ContainerBanner` with the page's own tooltip and
  New container as the library's `PageBanner` `action` (feedback #2, 2026-09-19; the picker+create
  band, LibKa0s v1.56.0). The acts on the selected container (Name, Enabled, Duplicate, Delete, Copy
  settings from) stay on the page's one tab, which options-ui-§14 then names **General**. The band is
  drawn on every render, so a Delete's two refreshes cannot lose it; the library releases the band's
  widgets of the render before once the new band exists, and refuses New container in combat as it
  refuses the picker's selection.
- **Every container picker lists by name** (smoke batch 2, B2-2): the Container banner and header,
  **Copy settings from**'s source and Layout's *Another container* all read
  `Database.GetContainersByName` — sorted case-insensitively, the id breaking a tie (names are unique
  regardless of case, so a tie needs a hand-edited store). The banner keeps its gray "(unit, aura type,
  style)" suffix; the stored display order (`containerOrder`, `/am containers`) does not change.
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

### General (18 rows, `settings/General.lua`, `settings/GeneralSpells.lua`, `settings/GeneralDispel.lua`)

**Master controls** — composed by the library's `MasterControls` from one declaration
(options-ui-§15), in canonical order, two per line:

| Row | Path | Type | Behavior |
|---|---|---|---|
| Enable Aura Master | `enabled` | bool | Gates every container; applied as a visibility pass, legal in combat |
| General visibility | `visibility` | string | `always` / `inCombat` / `outOfCombat` / `never`; combat read with `UnitAffectingCombat("player")` |
| Master scale | `scale` | number | Multiplies each container's own Layout → Frame scale |
| Master alpha | `alpha` | number | Multiplies each container's own Layout → Frame opacity; applied as a visibility pass, legal in combat |
| Lock frame | `locked` | bool | Unlocked shows every container's drag handle and a faint outline one element in size, and live auras keep drawing; an unlocked container shows whatever its visibility rule, so one set to *In combat* can still be found and moved. Locking hides them |
| Debug console | `state.debugConsole` | bool, session | Shows or hides the console window; never written to the profile |
| Minimap button | `global.minimap.shown` | bool | Shows or hides the minimap button. **The one row stored outside the profile** — the path is verbatim and absolute, and the table is LibDBIcon's own, in the GLOBAL store (launcher-§3). The label and the path say SHOWN (`global.minimap.shown` is true while the button shows) and the stored key, LibDBIcon's `global.minimap.hide`, says HIDDEN, so `settings/Schema.lua`'s read and write seams invert; the write also calls `NS.Launcher:SetShown`, so the button follows the checkbox at once. **No reset on this page moves it**: whether the button is shown is a per-installation display preference, so this page's **Defaults** button skips the row (`vetoedFromPanelReset`, `settings/OptionsSetup.lua`) and *Reset all settings* never reaches it. `/am reset global.minimap.shown` still restores it |
| Test mode | `state.testMode` | bool, session | Every container shows its placeholder auras, without unlocking; never written to the profile (below) |

**Test mode** (`state.testMode`, bool, session) sits beside Minimap button, composed from
`testModePath` (preview-mode, options-ui-§15). It shows every container's placeholder auras without
unlocking, and each container's engine is disabled while it is on. It is bound to
`NS.State.testMode` through `Preview.SetTestMode`, the one writer `/am test` and the minimap button's
left click also use: off after a reload, ended when combat starts (`PLAYER_REGEN_DISABLED`), and a
start in combat is refused with one gray line, the checkbox reading false again. Its default is
false, so *Reset all settings* ends it too.

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

**The id has to be the AURA's.** This addon filters on the id an aura carries, and a great many
abilities are *cast* as one id and *land* as another — Renewing Mist is cast as `115151` and lands as
`119611`. A player typing a name gets the id the client knows, which is the one in the spellbook: the
cast's. The entry then draws with the right icon and the right name and matches nothing.

Nothing in the client can answer the mapping (see [scope.md](./scope.md)), so the answer is carried:
`defaults/CastToAura.lua`, generated by `tools/spell-research/research.py --emit-cast-aura` from
Blizzard's own DB2 exports, and read by `modules/CastAura.lua`. Both add boxes — Spell Categories
here and the Filters page's Overrides lists — go through it, and it does one of three things:

* **Rewrites**, when the data found a real `EffectTriggerSpell` edge from the cast to an aura. The
  aura's id is stored and the swap is announced in chat. 58 ids.
* **Offers**, when the only candidates are aura-applying spells of the same *name*. The id is stored
  exactly as typed and the candidates are listed for you to pick from. 590 ids. **Never resolved
  automatically** — a name is shared across the whole game, and picking one for you is how an entry
  ends up holding an unrelated spell that happens to reuse the word.
* **Says nothing**, for every ordinary spell.

It never refuses: the add always happens. A boss aura the generator has never heard of has to be
enterable, and the table's silence about an id is not evidence against it. An id *already* in a list
that can never match carries a gray note naming what to use instead, because the add-time line is
chat and is gone by the next login.

**Spell Categories** — bespoke, and profile-wide: every container shares these lists. A **Category**
dropdown of the fourteen shipped spell categories, plus every category the player has made — the eleven buff ones (defensives, activeMitigation, raidCDs,
offensiveCDs, healing, support, groupBuffs, movement, utility, stances, racials; schema v7 retired consumables) and the three debuff ones (hardCC and
softCC from issue #11, racialDebuffs from schema v7) — **plus Weapon enchants** (schema v3). The dropdown is keyed on the category
KIND, not on an aura type, so a debuff spell list is editable here like any other. Every entry
carries an aura-type marker — `[Buffs] Healing`, `[Debuffs] Hard CC (loss of control)` — read out of
`C.AURA_TYPE_LABELS` rather than worded again here, so the picker uses the same two words the
container's own Aura type control does (issue #10). The shorter word is padded so every name starts
at the same character offset; that is character-exact rather than pixel-exact, since the row font is
proportional. The markers are **colored, muted** (owner, 2026-09-21): `[Buffs]` in muted green
(0.45, 0.75, 0.50 = `73bf80`), `[Debuffs]` in muted red (0.80, 0.45, 0.45 = `cc7373`) and `(yours)`
in muted gold (0.85, 0.72, 0.38 = `d9b861`) — the register of the drag handle's gold label
(1, 0.82, 0) and its help mark (0.7, 0.7, 0.72), dimmed because a marker sits beside a name and is
not the subject of the row. The brackets and the parentheses are inside the escape, so each mark
reads as one object. **The escapes do not move the column**: `|cAARRGGBB` and `|r` are drawn as
nothing, and the padding is measured on the bare aura-type word before any color reaches it, so the
name still starts at the same character offset — a case strips every escape and asserts that on what
is left. A category the player made carries **`(yours)`** after its name — a SUFFIX, because the
aura-type marker is a padded prefix and a second prefix would move the column that padding bought,
and because only a few rows answer yes while marking the rest "not yours" would be noise on every
row. One definition (`NS.GeneralSpells.MarkedName`) serves this dropdown, the Filters → Categories
grid and the claiming names in an entry's tooltip, so no two of them can come to say it
differently. A **Spells in this
category** section heading (2026-09-20) separates the picker and its Restore from the list below it;
Weapon enchants, which has no spell list, draws a **Weapon slots** heading over its three toggles
instead (2026-09-21), so every block of the tab sits under a heading naming it. Every entry but
Weapon enchants draws that category's ID list (the library's `IdList`):
**Add a spell** takes a spell id, a shift-clicked link or a name. While you type, a dropdown lists
the matching spells (the library's suggestions, LibKa0s issue #31), each with its rank where the
client gives one; a click, or Up/Down then Enter, picks one. The client finds a spell by name only
in the character's spellbook and cannot list any other, so the page hands the library `candidates`:
every category's starters, every spell the profile's categories edit, every spell on any
container's whitelist or blacklist, and the timed buffs Aura Master has learned. A name two of
them share is refused until one is picked ("pick one from the list, or use the id"), never
resolved to one rank; a name neither knows adds nothing, and the line under the box says where
names come from (the library's spell hint, localized, which the tooltip quotes too). Every entry —
starter or added — carries an X at the left of every entry (a starter's X hides it, stored `false`;
an added spell's X forgets it), and **Restore this category's starter list** on the Category
dropdown's own line, to its right (feedback #3), above Add a spell. Writes the whole set to
`categorySpells` (a carve-out, so every container re-applies). The page's Defaults does not touch
these lists; each category's restore does.

**The picked category's own controls** — drawn between the picker and the create form, because their
subject is which category is being edited, which is the dropdown's subject and not the list's
(issue #10, 2026-09-21). They sit **directly under the picker and under no heading of their own**
(owner, 2026-09-21): a heading between a control and the two controls that act on what it is showing
separated things that belong together. What keeps the tab reading as blocks rather than a run-on is
the gap below — the picker and its two acts are consecutive rows, and **Make a new category** closes
them off. What it draws:

- **A category the player made:** a **Rename this category** box, pre-filled from the store on every
  render and committing on Enter (never per keystroke — that would write a record, re-run the sync and
  rebuild every schema row per character), and **Delete this category** in the right half of the same
  line, the column Restore sits in above. A rename keeps the key, so the spells and every container's
  Show or Hide survive it, and the answer line says the OLD name back, which is a rename's only undo.
  Delete asks first, through `AURAMASTER_DELETE_CATEGORY`: the confirmation names what is lost — the
  spell list, and every container's Show/Hide in every profile — and the one consequence that is not a
  loss, that an aura the category was hiding becomes visible again through Uncategorized. The popup
  carries the KEY, never the definition, so a popup that outlives its render cannot act on a stale one.
- **One of Aura Master's own: nothing at all** (owner, 2026-09-21) — no controls, no heading and no
  sentence. It drew a sentence saying the name and the buff-or-debuff choice are fixed and the spell
  list is still the player's; the owner asked for it gone, and nothing is lost, because the lead-in
  above the picker already describes the list in the words its own controls use, and the Weapon
  enchants branch says in its own lead-in that there is no spell list to add to. Disabled controls
  were declined for the same block long before: on ten of the twelve shipped entries they would be
  mostly things that do not work, and they would not say why. The lock itself was never drawn from
  here — `Cat.RenameUserCategory` and `Cat.DeleteUserCategory` enforce it.
- **Only while the profile holds a record the sync cannot read:** a line saying how many there are,
  that nothing is using them and that they cannot be repaired from here, and a **Forget unreadable
  categories** button behind its own confirmation. Both read at a count of one, through two whole
  strings and a branch (the idiom `settings/Text.lua`'s `centerNote` already uses). Without this a
  record with an unusable aura type, name or key was permanently stuck: the sync refuses to
  materialize it, so it is in no dropdown and no Delete could reach it.
- **The answer line**: one row under whatever the block drew, carrying what the last act answered —
  an empty or refused name, a duplicate name kept, a create, a rename, a delete, the restore refusal.
  Everything is said in chat as well, since that is this addon's act log. The line belongs to the
  state it was said in and the draw enforces it: it is stamped with the profile and the category, and
  dropped on the first draw that does not match either, or when the panel goes off screen (hooked on
  the panel's own OnHide, with a structural refresh beside it, because a hidden page is not re-drawn
  on its next show unless something marked it dirty). A delete stamps no category — the one it names
  is gone — so the next draw adopts the category shown in its place and the line dies with that one.
  It deliberately survives a hop to another tab of this page and back: the panel never left the
  screen, and the sentence is still about the category on it.

**Make a new category** — its own heading, and three controls in reading order: **New category's
name**, **Aura type** and **Create category**. The heading, labels that name acts rather than the noun
the two boxes share, and only the rename box ever being pre-filled are the three things that tell the
two Enter-committing name boxes apart. The aura type is set here and nowhere else, because it is fixed
at creation — the compiler groups by aura type and every container's stored Show/Hide is keyed by
category key, so a type that could move would carry a category between two grids and orphan that
state. A name is capped at `Cat.USER_NAME_MAX` characters in the box and at the store, is stripped of
`|` and control characters, and a DUPLICATE is kept and reported rather than refused: the key is
identity, so two categories called the same thing are two categories. Creating selects the new
category, so it is not left to be found in a dropdown of twelve and counting.

**Restore is not drawn for a category the player made**, and `NS.GeneralSpells.RestoreStarters`
refuses one at the act, so the drawing rule is a courtesy and never the enforcement. Its starter list
is `{}`, so the one act behind that label would silently empty the category, one row above a Delete
that stops to ask for exactly that loss. The picker's lead-in drops its Restore clause on those
categories too.

**The overlap guardrail informs, it never blocks** (issue #10). Adding a spell already held by another
category of the same aura type prints one chat line naming the others and what the compiler does about
it, and each such entry is marked on its own row. Both read
`FC.ClaimingCategories` — the compiler's own answer, asked with an empty filter because this is a
statement about the category set and not about any one container — so the guardrail and the Overrides
tab's notes cannot drift into two answers to one question. Only the same aura type can claim: a buff
list and a debuff list never meet in one container. Every name in both surfaces carries the `(yours)`
marker where it applies.

**The mark rides the row, and the names are in the tooltip** (owner, 2026-09-21; LibKa0s v1.49.0).
A claimed entry reads

```
(X) [icon] Renewing Mist (119611) (also in 1)
```

— the count in the same gray as the id, drawn INSIDE the label through `O.IdList`'s entry `suffix`
(OptionsWidgets minor 25). It is bytes on a string the row was already drawing, so it adds no widget
and, unlike `note`, never costs the entry its place in the two-column grid. Hovering the entry gives
the client's own spell tooltip with one line added: `Also in: Immunities (yours)`, every claiming
category by name, through `Cat.LabelOf` and the panel's own `(yours)` marker. The count is
`FC.ClaimingCategories`'s answer, the same one the chat line at the add reads; `(also in 1)` and
`(also in %d)` are two whole locale strings with a branch, as `settings/Text.lua` writes a count.

The tooltip line needs a host kind table (`spellKind`), because `O.IdList` builds an entry's tooltip
from the kind's `tooltip` and nothing else. It is `base = "spell"`, so the list draws exactly as
before, and its `resolve` hands typed text straight back to `O.ResolveId("spell", …)` so the add box
keeps the client's name lookup and the shared-name check. **The suggestions come with the base**
(LibKa0s v1.49.1): the library reads its client-source table through `decorKind`, so a kind that
declares `base = "spell"` is offered the spellbook exactly as the library's own spell kind is. A
spell in the spellbook and on no list of this addon is suggested as you type, and resolves and adds
by name, by id or by link. Under v1.49.0 that table was keyed by the kind table itself, a host
table matched no row, and the tooltip cost this tab its autocomplete.

**It does not always fit, and the suffix is what goes.** The label is `0.43` of the content width in
the icon style at two columns (`(0.78 + 0.20 − 0.08 − 0.04) / 2`, `entryNameRel`) less the 16px icon,
and the floor for THIS list is the icon style's **520px** content — not the 584px the default style
needs, which an earlier version of this paragraph used and which overstated the budget by about 28px.
The real number is `0.43 × 520 − 16 = 207.6px`. Turning that into characters needs a figure this repo
does not measure: LibKa0s publishes a **rule of thumb** of ~4.5px a character for this face, which
puts the budget at about **46 characters** for the name, the space, the gray `(id)` and the suffix
together. A long row such as
`Ancestral Protection Totem (207399) (also in 1)` is 47. At the floor it overruns by about a
character, word wrap is off at two columns, and the library's truncation order is suffix first, then
the id, then the tail of the name — so the `(also in 1)` is what disappears on that row at the
narrowest width. That is the documented degradation and it is accepted: the tooltip still carries
every claiming category by name, which is the information itself. Wider than the floor, roughly 8
more characters per 100px of content, and the suffix is back.

Starters and added spells are drawn as ONE list **ordered by name**, case-insensitively (owner,
2026-09-20; before that it was id order, which read Frost Nova, Entangling Roots, Hamstring). The
two are indistinguishable on screen anyway, so an added spell sits in the alphabet rather than below
it. An id the client cannot name is drawn `Unknown spell <id>` and sorts after every named one, ties
there broken on the id ascending — a deliberate, stable answer rather than whatever `pairs` handed
over. It is drawn **two columns wide, filled row-major** — 1 2 / 3 4 / 5 6, so the alphabet reads
left-to-right then down (owner, 2026-09-20: one entry per row ran very long for a 60-id category).
That is `O.IdList`'s `columns` option, new in LibKa0s v1.47.0; each entry's width is divided by the
count, so a pair fills the row one entry used to, and an odd count leaves the last row half filled.
Two is the option's whole range — the library caps it there and says why. The trade at two columns
is that an entry's name no longer wraps: one that does not fit is cut from the TAIL, which is where
the gray `(id)` sits, so such an entry shows part of its name and no id (hover it and the client's
own spell tooltip names it). The library's `entryNoWrap` explains why a wrapped name would break the
grid rather than merely look uneven.
The list does not resettle a moment later: `O.IdList`'s re-ask-and-redraw is the item path
(`loads = true`), and a spell's name is client data with no load step. The Filters page's
**Overrides** lists keep their own id order, and since 2026-09-21 they draw **two columns wide** as well. That
is a consistency call rather than a length one: an override list is per container and holds a handful of
ids, so it was never the scroll this option was bought for — but the same spell rows, with the same X
and the same gray id, drawn one per line here and two per line on General read as an omission on
whichever page you saw second.

Choosing **Weapon enchants** draws something else entirely: three toggles, one per weapon slot
(Main hand, Off hand, Ranged; `enchantSlots.<slot>`, profile-wide, all on by default, schema v3), and
a line saying that whether a container shows enchants at all is that container's own Filters →
Categories row, with a link back. Unticking every slot here does not turn enchants off anywhere — a
container reads all three anyway — because the container-level Hide on Filters → Categories is the
one switch for that; the tab says so.

**Dispel Colors** — a lead-in ("One color per dispel type, shared by every container:") and three
bullets (2026-09-20, owner: a list rather than a wall of prose — the shape the Filters priority block
already uses), then five swatches, `dispelColors.Magic`,
`.Curse`, `.Disease`, `.Poison`, `.Bleed`: the fill or background of a bar colored by dispel type, and
a Text line's dispel type word, backdrop and edge when those are on (Text → Font → Dispel type,
feedback #7). An aura with no dispel type — every buff and many debuffs, class debuffs such as
Judgment or Consecration included (`docs/midnight-quirks.md`) — keeps a bar's own color and draws no
text type word, backdrop or edge, so there is no None swatch. Icons do not read them: an icon's dispel border keeps Blizzard's own
colors on our Solid shape (owner, 2026-09-13; batch 8 DB-2), and the tab line and each row's tooltip say so. Profile-wide, so a
write re-applies every container.

### Containers (5 rows, `settings/Containers.lua`)

A top-level page (`N-1`, batch 7 — formerly General's third tab), one tab, **General**. The band above
the strip holds the Container picker and **New container** (a player-buff bar container, then
selected) on one row. With no container, the band and one sentence are all the page draws.

| Row | Path | Type | Behavior |
|---|---|---|---|
| Name | `container.name` | string, edit box | Non-blank; Enter applies; made unique; renames the handle and every picker; never reset (`noReset`) |
| Enabled | `container.enabled` | bool | A disabled container keeps its settings |
| *What it shows, and how* | — | subsection | An options-ui-§7 subgroup heading over the three rows below (batch 8): what the container watches and how it is drawn, against Name and Enabled's "which container is this". Name and Enabled carry no heading of their own — one above a tab's first row only repeats the tab |
| Unit | `container.unit` | string | `player` / `target` / `focus` / `pet`; structural |
| Aura type | `container.auraType` | string | Buffs / Debuffs; structural (weapon enchants are a buff category, schema v5) |
| Style | `container.style` | string | Bars / Icons / Text; structural (rebuilds the engine) |

Changing Style resets Fill (Layout → Growth) to Columns for Bars and Text and to Rows for Icons;
re-choosing the same style keeps a Fill set by hand (B5). A new container (**New container**, or
`/am new … icons`) starts with the Fill its style suits by the same rule; a duplicate keeps its
source's.

Then **Duplicate** and **Delete** (asks first), and — with more than one container — **Copy settings
from**: a source dropdown (every other container, by name), a "what to copy" dropdown (everything, or one of Filters, Layout, Mouse,
Label, Bar style, Icon style, Text style) and **Copy onto this container**. Name and position are never copied.

### Filters (46 rows, `settings/Filters.lua`) — sub-page of Containers (`N-2`, `D6`)

Every tab opens with the container's warnings in orange — what the engine will silently not honor
here (`Helpers.RenderWarnings`, from `FilterCompiler.Compile`'s `warnings`).

**General** (named *What to show* until 2026-09-20)

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
to the foot of **General** in batch 8 (see *Filter priority* below), off both this tab and
Overrides. The per-container **Only these categories** toggle
(`container.filter.onlyShown`) that used to sit here is RETIRED (batch 7 fix round 2): once
`Uncategorized = Hide` correctly suppresses the catch-all on its own, on EITHER aura type (fix round
3 restored the debuff row fix round 1 had dropped), the toggle had nothing left to do, so the owner
chose one control over two. A stored `onlyShown = true` is migrated to `categories.uncategorized`
(buffs) or `categories.uncategorizedDebuffs` (debuffs) `= "hide"` (schema v4, `docs/schema.md`) and
the key cleared; only a container of some other, unrecognized shape has no category to migrate onto,
and loses the narrowing — named and printed to the player directly (`NS.Print`), not left to the
debug console. Then one generated row per category at
`container.filter.categories.<key>` — the 36 `defaults/Categories.lua` ships, and one more for every
category the player has made (issue #10), built by the same `NS.CategoryRow` and registered in front
of the aura type's Weapon enchants or Uncategorized row so schema order still tracks declaration
order — stored `"show"` / `"hide"` (schema v3) and labeled **Show** /
**Hide** (`/am get` and `/am list` print the label, then the stored value in gray). Show is a
positive claim: an aura in at least one Show category is drawn even if another of its categories says
Hide; only an aura whose every category says Hide is removed by them (rank 3 of the priority order).
Buff containers see the 17 shipped buff rows, debuff containers the 19 shipped debuff ones, each plus
the player's own categories of that aura type — each list's last row is still its
own `Uncategorized`, asymmetric between the two, and since issue #11 (2026-09-20) that asymmetry is
about the UNIT rather than the aura type: the rescuing group's only constraint is an
`excludeSpellIDs` of the categorized union, so the compiler emits it only where
`FC.IdsAlwaysHonored(unit, auraType)` holds — buffs on the `player` and `pet`. There Show rescues an
unlisted aura from another category's Hide. On every debuff container, and on a `target`/`focus`
buff container whose unit may be hostile, Show changes nothing at all and only Hide does anything —
reproducing the retired toggle exactly.
Under the Spell Categories grid, a line states the cost of the buff row's default (Show): hiding a
Blizzard category alone does little while it stays Show, since it keeps rescuing unlisted auras; both
rows need Hide to actually remove one. The rows carry `skipRender`, so the flow engine draws nothing
for them; the tab is bespoke
(keyed by the group's name) and draws one `ChoiceGrid` per row `grid`, each a header line
`Show · Hide · Category` and then a line of two cells (an ordinary checkbox check on the lit one,
LibKa0s v1.36.0's `O.ChoiceGrid`, the yellow fill withdrawn in v1.36.2) and the category's label
(hover it for its description). A grid
with no row for the aura type is not drawn. Every section, **Blizzard Categories**, **Spell
Categories**, **Dispel Types** and **Who Cast It**, opens with **Show all** and **Hide all** (feedback
#10; the last two since B11-T10): each writes every category of that section, and only that section,
for the selected container, as one bulk act (`NS.Bulk.Run`: one `[Set] show all|hide all <grid>
categories of container <id>: N rows` line, one apply pass).

| Grid (`grid`) | Buff categories | Debuff categories |
|---|---|---|
| Blizzard Categories (`blizzard`) | bigDefensive, externals, important, castable, cancelable, stealable | crowdControl, boss, role, priority, raid, raidInCombat, groupDispellable, dispellable |
| Spell Categories (`custom`) | defensives, activeMitigation, raidCDs, offensiveCDs, healing, support, groupBuffs, movement, utility, stances, racials, *then every buff category the player made*, **weaponEnchants**, **uncategorized** (last) | *every debuff category the player made*, **uncategorizedDebuffs** (last, fix round 3) |
| Dispel Types (`dispel`) | — | dispels, magic, curse, disease, poison, bleed |
| Who Cast It (`who`) | — | fromNonPlayers, fromPlayers |

The **Spell Categories** grid (renamed from Custom Categories, `F-1`) carries one extra line above
it — saying these are the lists on General → Spell Categories, shared by every container — but only
when the grid this container drew actually holds a `spells`- or `enchant`-kind row (batch 7, `T-2`
fix round 4): true on a buff container, false on a debuff one, whose grid is `uncategorizedDebuffs`
alone, a Show/Hide flag over the catch-all rather than a list of anything. A category the player made is labeled **`<name> (yours)`** in this grid, in the same words the General
→ Spell Categories dropdown uses and read from there (`NS.GeneralSpells.MarkedName`) rather than
formatted twice; the marker is added to a per-render COPY of the row, because the schema row's label
is the row's identity in `/am list` and in the write log. It also carries one extra
column: a **See spells** link (`K-2`) on every `spells`- or `enchant`-kind row, which selects that
category on General → Spell Categories, opens the General page and switches to its Spell Categories
tab (`NS.GeneralSpells.Select`, `NS.OpenOptionsPage`, `H.SelectTab`). Right under that grid — ahead
of the Uncategorized cost note below — sits **Hide enchants without a duration**
(`container.filter.hidePermanentEnchants`, bool, buffs only), behind a one-line tie naming
the `weaponEnchants` row it governs by name (batch 7, `T-3`: the grid draws its rows atomically and
cannot host a plain bool inline, so the tie text is what keeps it from reading as floating).

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
words, `NS.GeneralSpells`), each entry with an X at the left of each entry. Each set is written whole through the seam's carve-out;
the lists are not schema rows, so the page's Defaults leaves them alone. Each entry also carries a
**"?" help mark** between its X and its name (LibKa0s v1.51.0's `O.IdList` `entry.help`, `K-3`;
it was a full-width `note` under the name until 2026-09-22, which cost such an entry its place in
the two-column grid — the library gives a noted entry a row of its own whatever the column count).
Hovering it gives the entry's name and the sentence, built from
`FC.ExplainSpell` sparingly: it fires only when a category genuinely disagrees with the list's
verdict, or the id sits on both lists, and never claims what the aura will finally do — a duration cap
or Cast by can still keep it off screen even where the lists and categories alone would draw it. Batch
7 fix round 2 retired the one exception this used to carry (an "only these categories" container with
nothing else Shown, whose whitelist entry really was the only thing keeping an aura on screen): rank 5
can no longer be "hidden" at all once the toggle is gone, so every note stays non-definite now.

**Filter priority.** The five ranks, highest first, are stated in ONE place — the foot of the
**General** tab (`P-1`, `P-4`), under the heading *Filter priority logic*: a lead-in in
`GameFontNormalSmall`, then one rank per line at the AceGUI Label default with a hairline gap between
them. Both sizes were a step larger until 2026-09-20, which made the block shout beside the Overrides
tab's own notes; heading and sizes changed in that pass, the wording did not. Before batch 8 the same
five lines were restated at the top of both Categories and Overrides, which put a wall of small text
above the controls on two tabs at once. The wording is unchanged, and drives `FC.ExplainSpell`, the
per-entry notes above: (1) on the Overrides whitelist — always shown; (2) on the Overrides blacklist
— hidden, unless the whitelist already claimed it; (3) in at least one category set to Show — shown,
even if another of its categories says Hide; (4) in categories that all say Hide — hidden; (5) in no
category at all — shown, nothing removed it. Full detail and how it compiles: `docs/data-flow.md`
→ Filter priority.

A container that shows only weapon enchants is a buff container (schema v5): on its Categories tab
every category is Hide but **Weapon enchants**, and **Show all** / **Hide all** (feedback #10) reach
it like any other.

### Layout (38 rows, `settings/Layout.lua`) — sub-page of Containers (`N-2`, `D6`)

**Frame** — Scale `container.layout.scale` (0.5–3), Opacity `container.layout.alpha` (0–1, percent),
Strata `container.layout.strata`, Frame level `container.layout.level` (1–100).

**Anchor**

| Row | Path | Type | Behavior |
|---|---|---|---|
| Attach to | `container.attach.mode` | string | Screen / Another container / Named frame; structural. Switching to Another container with a target already stored asks first when that target's chain flows differently (GC-1, below) |
| *Screen:* Point / Relative point | `container.position.point` / `.relativePoint` | string | The corner of the container's **first aura** placed on the screen / the screen corner it is measured from; set by dragging |
| *Screen:* X / Y | `container.position.x` / `.y` | number −2000–2000 | |
| *Another container:* Parent container | `container.attach.container` | number (dropdown) | Labeled "Parent container" (the owner, 2026-09-26; the banner picker keeps "Container"). None, then every other container by name (B2-2); a choice that would loop is refused; one whose chain flows differently asks first (GC-1, below); structural, and it re-applies the container it left. Beside it (`pairWith`) a read-only line, "Its *point* joins the *relative point* of '*target*'", names the two points in effect, picked or Automatic (`Anchors.AttachPoints`, batch 11 G2) |
| *Another container:* Parent container anchor point / This container anchor point | `container.attach.relPoint` / `.childPoint` | string (dropdown) | Batch 11 G1, in place of batch 9's Side row. Each offers "Automatic (*the point Automatic gives*)" first, then the nine points; the entry names Automatic's own point (`Anchors.AutoPoints`) even while the row holds a pick, so it says what choosing it would do; Automatic stores nothing (`nilAs = "auto"`, docs/schema.md), a point stores its token, and one picked point leaves the other Automatic. Any pair is stored, with no validate refusal and no fallback note. Structural (the attachment line and the other row's Automatic entry redraw); the write re-places the container, its parent and its followers. `/am set` takes the nine names in any case or `auto`; `container.attach.edge` is not a path |
| *Named frame:* Frame name | `container.attach.frame` | string, edit box | A global frame name; **Pick a frame…** beside it |
| *Named frame:* Named frame anchor point / This container anchor point | `container.attach.relativePoint` / `.point` | string | The corner of the frame, on the left / the corner of the container's **first aura** that is attached, on the right: the same order and names as Another container's two rows (the owner, 2026-09-26); This container anchor point is structural (it redraws the facing-growth hint) |
| *Offset:* X offset / Y offset | `container.attach.x` / `.y` | number −500–500 | Used by both attached modes: from the named frame's point, or as a nudge on top of the seam gap (SS-2) |

Each subsection's rows carry a `shownWhen` switch on **Attach to** (LibKa0s-Options-1.0 W22,
feedback #4), so only the subsections the mode reads are drawn, each heading with its rows: in
`screen` mode Screen; in `container` mode Another container and Offset; in `frame` mode Named frame
and Offset. The hidden rows stay in the schema, so `/am set`, `/am get` and the resets still reach
them. Changing **Attach to** (from the panel, `/am set` or a reset) redraws the tab once, on the next
frame, through the library's selector watch. The mode row's `onChange` only starts or ends an attachment
(below). **Pick a
frame…** (closes the settings, starts the picker, reopens this page) is Frame name's `pairWith`
partner, so it is drawn with Named frame; a pick still sets the mode to Named frame itself.

**Point places the first aura (D-3).** The anchor is one element in size and the engine is pinned at
its growth corner, because the container's full extent is secret and cannot be anchored; so both
Point rows (screen and Named frame) name the corner of the **first aura**, and the other auras grow
away from it as the Growth tab says. **The facing-growth hint.** After the tab's rows (`afterGroup`),
in `frame` mode only, a small gray line appears when the Point's side faces the growth: a BOTTOM*
point (the container sits above the frame) with Grow vertically Down, a TOP* point with Up, a LEFT*
point (it sits right of the frame) with Grow horizontally Left, a RIGHT* point with Right. It reads
"Point is *point* and Grow vertically is *growth*, so the auras grow back over the frame this
container is attached to. Set Grow vertically to *opposite* on the Growth tab instead." (the
horizontal line likewise; a corner point can draw both). The screen has no frame to grow over, and a
follower's two points are the user's to pick, odd pairs included (batch 11 G1), so neither mode draws it.

**The points of a new attachment (batch 11 G2, G3).** An attachment writes nothing: while no point
is picked, both are Automatic, and Automatic follows the parent's growth and the two styles
(`Anchors.DefaultEdge`: a Text child lines up with its text justify, an icons or bars child under a
Text parent justified Center is centered, every other pair starts on the side the parent's lines start
from). Picked points survive an attach, a retarget and a detach. A write to either point, Attach to or
Container also re-applies the parent, old and new.

**Growth conflicts (batch 9 GC-1, E3).** Attaching keeps inheritance: the container fills and grows
like its chain root and its own Growth settings are kept, never written, for a detach. When a panel
pick would attach it to a chain that flows differently from its own Growth settings
(`Anchors.FlowChangeOnAttach`: the target's chain root, compared on Fill, Grow horizontally and Grow
vertically), nothing is written: the rows' `confirmWrite` hands the write to the
`AURAMASTER_ATTACH_FLOW` popup (`settings/OptionsSetup.lua`'s `confirmFirst`) and the page redraws
on the stored value. The popup reads "Attach '*child*' to '*target*'? '*child*' will fill and grow
like '*root*' (*the changed settings*). Its own Growth settings are kept and come back if you detach
it.", plus " *n* container(s) attached to it follow too." when others follow it. **Attach** writes
through the seam, whose validate checks the loop again; in combat it is refused with a gray line.
**Cancel** writes nothing. It asks on the Parent container row in container mode, and on Attach to when
switching to Another container with a target already stored; a matching flow, None and every other
write attach at once. `/am set` and the resets never ask: an attachment they make that changes the
flow prints "'*child*' now grows like '*root*'; its own Growth settings are kept.", and a detach
that brings the container's own flow back prints "'*child*' is no longer attached to '*target*' and
fills and grows by its own Growth settings again." (from the panel too; a line, not a popup, E9).
A chain root's Growth tab opens with "*n* container(s) attached to this one follow its fill and
growth."; changing it there asks nothing, and the chain re-flows.

**Growth** — Fill `container.layout.axis` (rows or columns), Per row or column
`container.layout.perLine` (0–40, 0 is one line), Grow horizontally `container.layout.growH`, Grow
vertically `container.layout.growV`, Spacing `container.layout.spacing` (0–40), Line spacing
`container.layout.lineSpacing` (0–40).

**Inherited flow (L-6).** A container attached to another container continues that container's
flow. Its fill axis and both growth directions are its chain root's, resolved up the chain by
`Anchors.EffectiveLayout` (cycle-safe through `Anchors.WouldCycle`). Its anchor points are the two
in effect (`Anchors.AttachPoints`, batch 11 G2): each picked, or Automatic, the matching half of the
default pair (G3), which for a bars child under a bars parent is `after-start`, the same as
`Anchors.DerivedPoints`: the child stacks below its parent (above, when growing up), on the side the
parent's lines start from, whether the parent fills rows or columns (IA-1). A pair that is none of
batch 9's nine sides is free: placed at X/Y alone, with no seam (G5). `container.attach.point` / `.relativePoint` are read only in `frame`
mode. The gap across the seam is the child's own gap between consecutive elements in the direction
the chain stacks: its Spacing when it fills columns, its Line spacing when it fills rows
(`Anchors.SeamOffset`, SS-1), upward when the chain grows up; on a Right or Left side it is the
child's gap across instead, its Spacing when it fills rows and its Line spacing when it fills columns
(AP-2), and a parent's strip widens only a seam along the chain. The offsets add on top of it as a
nudge (SS-2). `Container.FlowSettings`, `Preview.Offset` and the
handle's placement and clamp all read the effective layout. A write that moves a container's flow or
attachment re-applies every container following it (`Anchors.Followers`). On this tab, in that mode,
Fill, Grow horizontally and Grow vertically are dimmed and show the inherited values. They do that
through a row `panelGet` that only the panel descriptor reads; `/am get` and every module read the
stored values. The line "Fill and growth follow '*root*' because this container is attached to it."
sits above them, in the panel's muted secondary gold (`C.SECONDARY_GOLD`), with a row gap below it. Per row, Spacing and Line
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

**Label** (batch 8 NL-1..NL-4, owner feedback #8) — Show name label `container.label.show`,
Justify `container.label.justifyH` (Left, Center, Right; batch 9 LJ-1, E7), X
offset `container.label.x` and Y offset `container.label.y` (-200 to 200), then a *Font* subgroup, the
composed font block on `container.label.font.` (gold Friz 12 OUTLINE by default, the strip's own
look; class color from the container's unit). Ten rows. Justify is stored `"AUTO"` until the player
picks one, and the dropdown shows the justify in effect (the row's `panelGet`,
`Anchors.LabelJustify`): Bars and Text center the name, Icons line it up with the first icon (Left,
Right when the icons grow left, mirrored above a Left-attached follower, whose label lines up with
the edge that faces its parent). The row's reset writes
`"AUTO"` back. The text is always the container's name, so
a rename redraws it. Every row but Show is dimmed while the label is off, except the color swatch,
which is never dimmed (anti-pattern #74). The label sits on its block's before side, outside the
first element on the side the auras do not grow into, on a container attached to another as on a
root (batch 10 F3); it shows locked or unlocked, and while unlocked the strip moves out past it by
the label's height plus the strip gap (D6, `Anchors.PlaceLabel`), so the order is strip, label,
block. A follower's seam makes room for both (F2). The rows carry no `effect`: a write re-applies
the selected container.

### Bars (72 rows, `settings/Bars.lua`) — sub-page of Containers (`N-2`, `D6`)

When the selected container is drawn as icons, a small muted-red note heads every tab — "Not in use: this
container is drawn as icons. Set its Style to Bars on the Containers page to use these settings." —
and every control below it is drawn disabled (the spec's `disabledFor`,
`settings/OptionsSetup.lua`'s `mutedNotice`, drawn by the library's `O.RenderTabbedSchema` above
the rows). It was a large orange banner until batch 8, which
shouted for what is an aside; orange is left to the engine warnings, which can head the same page.
The tabs and the container picker stay live.

| Tab | Rows (all under `container.bars.`) |
|---|---|
| General (14) | *Size:* `width` 40–600, `height` 6–80; *Fill:* the composed bar block `barTexture` · `barAlpha` / `barColor` · `useClassColorBar`, then `colorMode` (one color / by dispel type), `drain` (toward left / right), `smooth`; *Spark:* `spark`, `sparkWidth` 1–32, `sparkColor` · `useClassColorSpark`, `sparkTimeless` (show the spark on auras without a duration) |
| Background & border (10) | *Background:* the composed bar block on the background leaves `bgTexture` · `bgAlpha` / `bgColor` · `useClassColorBg`, then `bgColorMode` (one color / by dispel type); *Border:* the composed border block `borderShow`, `borderStyle` · `borderSize` / `borderColor` · `useClassColorBorder` |
| Name text (11) | *Font:* the composed font block on `name.` (`font` · `fontSize` / `fontColor` · `useClassColorFont` / `fontFlags` · `fontShadow`); *Placement:* `name.show`, `name.justify`, `name.point`, `name.x`, `name.y` |
| Time text (12) | The same on `time.`, plus *Countdown:* `timeFormat` (Blizzard / short / detailed) |
| Stack text (11) | The same on `stacks.` |
| Icon (9) | *Icon:* `icon` (left / right / hidden), `iconSize` 0–80 (0 = bar height), `iconGap` 0–20, `iconZoom` 0–0.3; *Icon border:* the composed border block on the icon's leaves `iconBorderShow`, `iconBorderStyle` · `iconBorderSize` / `iconBorderColor` · `useClassColorIconBorder` |
| Pandemic (5) | *Time color:* `expiringColorOn` (Recolor the time in the pandemic window), `expiringThreshold` 1–60 (Pandemic window (seconds left)), `expiringColor` (Pandemic-window time color); *Highlight:* `pandemic` (Highlight the pandemic window), `pandemicColor` (Pandemic-window highlight color). Once the Highlights tab's *Running out* and *Refresh window* (smoke batch 2, B2-1: labels only, paths unchanged). The dispel type colors are the profile's, on General → Dispel Colors |

Behavior worth knowing: the fill is anchored to the edge of an invisible elapsed-time status bar, so
a permanent aura draws full and `drain` picks which end empties (`modules/Style_Bars.lua:158`);
`sparkTimeless` off clips a live spark to the elapsed region, which a timeless aura leaves empty
(docs/midnight-quirks.md); the icon border takes the icon's whole box and the art is inset inside it;
`smooth` selects the engine's eased interpolation; `colorMode = dispel` hands the fill to the engine
as a dispel-type texture tinted from the profile's `dispelColors` (General → Dispel Colors), and
`bgColorMode = dispel` the background the same way (feedback #7); an aura with no dispel type — a buff,
or one of the many debuffs that carry none, class debuffs such as Judgment or Consecration included —
keeps the surface's own color (the map's
`None` entry, `Style.DispelColorMap`); every `timeFormat` hands the engine a
`SecondsFormatter` that rounds up, Blizzard's being a copy of the engine's own
(`Compat.CreateSecondsFormatter`, `core/Compat.lua:180`); the pandemic-window time color is a step color curve over
remaining time, at the player's own seconds threshold (`Compat.ExpiringTextColor`, `core/Compat.lua:202`); the pandemic-window highlight is an additive wash the engine
shows only while the aura can be refreshed without loss, a window the game finds per spell (the threshold does not move it).

The Background subgroup is a bar group, not options-ui-§16's background clause. That clause gives a
surface with no texture a swatch and its companion and nothing else, and this background has a live
texture, so it takes the whole bar block with its own tooltips. `bgAlpha` multiplies onto the
background texture, and `bgColor`'s own alpha still applies, so the default look is unchanged. A
surface colored by dispel type keeps both too: the engine paints its tint's RGB at alpha 1, so the
map's entries are opaque and the region carries `bgAlpha × bgColor.a` (the fill `barAlpha ×
barColor.a`) through `SetAlpha` (`paintSurface`, smoke batch 2 item 4).

Every Border style row (Bars' Border and Icon border, Icons' Border, Text's Icon border) replaces the
composer's tooltip with one that says when a change shows: Solid, the default, redraws at once, while
any other texture, and a new thickness for one, reaches the aura buttons already on screen after a
`/reload`. Solid is drawn with four strips; another texture is a backdrop, which cannot redraw on a
laid-out button because its size reads secret (`Style.ApplyBorder`, B2-3, docs/midnight-quirks.md).
Its color still changes at once.

### Icons (42 rows, `settings/Icons.lua`) — sub-page of Containers (`N-2`, `D6`)

Bars folded its two-slider `Size` tab into a renamed `General` tab (`S-1`) because a whole tab for
two sliders did not earn its place. Icons keeps its own `Size` tab as-is: this page has no
`Bar`-shaped tab to rename it into, and `Size` (width, height, zoom) is a coherent "the icon's box"
group that would land arbitrarily inside `Border` or `Cooldown` if folded there — the two pages are
deliberately not made to match shape-for-shape (`settings/Icons.lua`).

When the selected container is drawn as bars, the same small muted-red note heads every tab — "Not in
use: this container is drawn as bars. Set its Style to Icons on the Containers page to use these
settings." — and every control is drawn disabled, as on the Bars page.

| Tab | Rows (all under `container.icons.`) |
|---|---|
| Size (3) | `width` 8–128, `height` 8–128 (a non-square icon is cropped, never squashed), `zoom` 0–0.3 |
| Border (6) | *Border:* the composed border block `borderShow`, `borderStyle` · `borderSize` / `borderColor` · `useClassColorBorder`, then `dispelBorder` |
| Cooldown (5) | `cooldown`, `cooldownReverse`, `cooldownEdge`, `swipeAlpha` 0–1, `blizzardNumbers` |
| Time text (12) | *Font:* the composed font block on `time.`; *Placement:* `time.show`, `.justify`, `.point`, `.x`, `.y`; *Countdown:* `timeFormat` |
| Stack text (11) | The same on `stacks.` without the countdown |
| Pandemic (5) | *Time color:* `expiringColorOn`, `expiringThreshold`, `expiringColor`; *Highlight:* `pandemic`, `pandemicColor` — the Bars page's labels (smoke batch 2, B2-1; once Highlights) |

`dispelBorder` has the engine tint four white strips in Blizzard's own dispel color, on harmful
auras with a dispel type only (batch 8 DB-1, DB-2). The strips have the Solid border's shape: flat,
square-cornered, inside the icon at the stored Border thickness, or 1 px when the border is hidden,
None or 0, whatever the border style. They sit above your border and replace it there; every other
icon shows your border. In test mode the placeholders are tinted the same way
(`Compat.SetAuraBorderColor`). `blizzardNumbers` shows the cooldown frame's own countdown beside the time text.

### Text (37 rows, `settings/Text.lua`) — sub-page of Containers (`N-2`, `D6`)

Four tabs. **General** is drawn bespoke, not by the ordinary schema-group renderer, so it can put the
built-in picker, the preview and two read-only blocks between its rows (feedback #5). Under **Text
Template** (Task 20, owner: renamed from "What each line says"): a **Template** dropdown of the aura
type's built-in templates (Name; Name + time; Name, stacks, time — the default; Time / max; and on
debuffs Name (type) and Name, type, time; Centered: name over time, which also sets Justify to Center)
plus **Custom**, then the **Custom template** box (drawn only for Custom: a template matching no
built-in reads as Custom by itself), then a read-only **Preview** — an AceGUI EditBox, PrettyChat's own
shape (`SetLabel`, `SetFullWidth(true)`, `SetDisabled(true)`), holding the line rendered on a sample
aura (`C.TEXT_SAMPLE_AURAS`, through the placeholders' own fill, `Style.Text.PreviewLine`), wrapped in
the container's own font color with a stray `|` doubled so it cannot break the box, and a Task 12
colored dispel word riding live inside it — then the **Tokens** / **Rules** cheat sheet (Task 20, owner:
"split it into keywords and guidelines - use bullet points"): one gold `$token$` bullet per token, then
a bulleted rule per bracket-hiding, the two escapes, how they combine, text outside `[ ]` always
showing, and a separator belonging inside the brackets of the field it leads (`$spellname$[-$stacks$]`:
an empty field takes its separator with it; smoke batch 2, item 8), each rule's example on its own
indented gold continuation line. On a container NOT drawn as text the whole Text Template block goes
gray with the rows around it (2026-09-20) — the Preview line loses the container's font color, and the
cheat sheet's headings, bullets and gold examples are all drawn in the notes' gray; the Placement
notes were already gray at all times, which is why they alone looked right on a dimmed page. Under
Placement, a gray **Justify note** always sits between the
justify pair and the offsets (smoke batch 2, item 3): Center centers a one-piece template only; with
several fields each field (the duration tokens together) gets its own centered row, text outside `[ ]`
is not drawn, the box grows to fit, rows keep their place when a field is empty, an icon at size 0 is
one row tall, and the reason — aura text is secret, so its width cannot be measured. The centering
note, naming this template's row count, sits under the offsets. Picking a built-in writes `template` (and `justifyH` where the built-in needs it) through
the write seam; picking Custom writes nothing. Its rows are still ordinary schema rows — the panel,
`/am set`, Defaults and the resets all reach them through the one write seam.

The Template row's `validate` is the parser (`modules/TextTemplate.lua`'s `TT.Validate`): a refused
template is never stored, and its reason reaches the player through the write seam's third return
(`settings/Schema.lua`), printed under "Invalid value for container.text.template" — in the panel and
by `/am set` alike.

The **Pandemic** tab (smoke batch 2, B2-1: once *Running out* on the Animation tab; labels only, paths
unchanged) is dimmed (the Pandemic-window time color swatch excepted, since a swatch is read for its alpha even
unused) when the template carries no duration token, with a note saying so ("The pandemic window needs a
duration token, such as $remainingduration$, in the template."); on the Animation tab the Loop rows are dimmed
per the chosen effect (`animSpeed`/`animIntensity` unless Pulse or Blink, `animBounce` unless
Bounce).

The **Icon** tab's rows draw nothing while **Icon position** is None (the default): the Text style
draws the icon and its border only on Left or Right. So every row but Icon position is dimmed then
(`noIcon`), the icon border's swatch excepted for the same alpha reason, under a gray note, "Set Icon
position to show the icon." (smoke batch 2, item 6). Icon position redraws the page on a change, so
the note and the dimming follow it at once.

**Dispel type** (Font, feedback #7; on the Animation tab until smoke batch 2, item 5 — the paths and
stored values did not change) holds three opt-in stand-ins for "color the text by dispel
type", all off by default, since no engine binding colors a font string by the aura's type
(`docs/known-limitations.md`). `dispelTypeColor` writes the `$dispeltype$` word in its
palette color: each value of the engine's `customDispelTextMap` carries a `|cffRRGGBB…|r` escape
around the word, the bracket text keeping the font color (dimmed without a `$dispeltype$` token).
`dispelBackdrop` fills the text area behind the chain with a white texture the engine tints and shows
per aura (`AddDispelTypeTexture`, `PreserveAsset`, the profile's palette), at `dispelBackdropAlpha`;
`dispelEdge` draws four strips `dispelEdgeSize` px thick around the text area the same way. The
backdrop and the edge show only for an aura with a dispel type (buff or debuff) the palette colors;
a type it has no color for (Enrage) gets no visible tint at all, the same as a typeless aura (fix
round 1). The opacity and the thickness are dimmed while their toggle is off. The preview draws all
three from the placeholder's own type.

When the selected container is drawn as bars or icons, the same small muted-red note heads every tab
— naming whichever of the two it actually is ("Not in use: this container is drawn as icons/bars. Set
its Style to Text on the Containers page to use these settings.") — and every control is drawn
disabled, as on the Bars and Icons pages.

| Tab | Rows (all under `container.text.`) |
|---|---|
| General | Size: `autoSize` (Size to fit; `width` and `height` dim under a note while it is on, batch 8 AS-1), `width`, `height`. Text Template: the Template dropdown, `template` (Custom only; + the Preview box and the Tokens/Rules cheat sheet). Placement: `justifyH`, `justifyV` (+ the Justify note), `x`, `y` (+ the centering note) |
| Font | the composed font block under `font.`; Countdown: `timeFormat`. Dispel type: `dispelTypeColor`, `dispelBackdrop`, `dispelBackdropAlpha`, `dispelEdge`, `dispelEdgeSize` |
| Icon | `icon`, `iconSize`, `iconGap`, `iconZoom`; the composed icon-border block |
| Pandemic | Time color: `expiringColorOn` (Recolor the time in the pandemic window), `expiringThreshold` (Pandemic window (seconds left)), `expiringColor` (Pandemic-window time color), `expiringBlink` (Blink in the pandemic window; engine-only) (+ the duration-token note) |
| Animation | Loop: `anim`, `animSpeed`, `animIntensity`, `animBounce` |

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
pages, and the five `dispelColors.*` on General → Dispel Colors.

## Launcher

**One object, registered twice** (launcher-§1). `core/LauncherSetup.lua` owns it: it builds a single
LibDataBroker-1.1 object of `type = "launcher"` through `LibKa0s-Launcher-1.0` and hands that very
object to LibDBIcon-1.0, so the minimap button and any broker display (Titan Panel, ElvUI data
texts, Bazooka) draw from one icon, one label and one `OnClick`. `NS.Launcher:Register()` is called
from `OnInitialize` after `InitDB`, and is idempotent.

| | |
|---|---|
| Owner | `core/LauncherSetup.lua` → `NS.Launcher` |
| Registered as | `AuraMaster` — the **folder name**, on both registrations, because LibDBIcon keys the button's saved position by it |
| Icon | `C.LOGO_ICON_PATH`, the same file `## IconTexture` names (launcher-§4) |
| Label | `Ka0s Aura Master` — the **brand name in plain text** (launcher-§1). What a broker display prints in its row, beside the other ten Ka0s addons, so it is spelled the way they are. Deliberately not the TOC `## Title` (a Title may carry color escapes) and not the folder name |
| Left click | **Opens the settings panel** (`openSettings` → `NS.OpenOptionsPanel`), in either state (launcher-§2, `LibKa0s-Launcher-1.0` minor 4): the panel is where a disabled addon is switched back on |
| Right click | **Opens the options menu** — the client's context menu, drawn by the library, titled `Ka0s Aura Master`, with one checkbox per pair the descriptor passes: **Enabled** (`isEnabled` + `setEnabled` → `NS.Slash.SetEnabled`, what `/am enable`/`disable` run), **Locked** (`isLocked` + `toggleLock` → `NS.Slash.ToggleLock`, what `/am lock`/`unlock` run) and **Test mode** (`isTestMode` + `toggleTestMode` → `NS.Slash.ToggleTestMode`, what a bare `/am test` runs). No *Show window*: the addon has no primary window. Each state is read when the menu opens; each click runs the verb's own handler, so the refusals and chat lines are the verb's. **While the addon is disabled** *Locked* and *Test mode* are grayed (`(enable the addon first)`) and *Enabled* stays live. On a client without `MenuUtil` the right click opens the panel instead |
| Tooltip | **Drawn by `LibKa0s-Launcher-1.0`** (minor 3, launcher-§1) on every hover, **including while the addon is disabled**: `Ka0s Aura Master  v<version>` (the TOC's `## Version`, through `NS.Version`), `Enabled: Yes\|No`, `Locked: Yes\|No` (the Lock frame row's `locked`), `Test mode: On\|Off` (the Test mode row's `state.testMode`), `Left-click: Open settings`, `Right-click: Options menu` (fixed since minor 4, the same in either state). The descriptor only answers the questions (`version`, `isEnabled`, `isLocked`, `isTestMode`), each asked on the show and never cached. No `onTooltipShow`: the addon has no lines of its own, and a hook drawing a title or a click hint would draw a second copy (anti-pattern #89) |
| Visibility | The **Minimap button** row. Its CLI path is `global.minimap.shown`, which answers true while the button shows; its storage is LibDBIcon's own `global.minimap.hide`, in the global store, never a second `shown` key (launcher-§3, anti-pattern #81, General's Master controls in this file) |
| Survives every reset | A per-installation display preference, like the button's position, so **no** reset the panel runs may move it — neither *Reset all settings* nor the General page's **Defaults** button. The one veto is `vetoedFromPanelReset` in the options descriptor's `applyDefault`, the library's single reset seam. `/am reset global.minimap.shown` is deliberately **not** vetoed: that is the player naming this one row |

**Three menu entries, because the addon has three toggles.** This addon has no primary window; its
preview is the session-only test mode, switched by the Master controls *Test mode* checkbox
(unlocking no longer previews: live auras keep drawing while containers are unlocked). So the menu
carries *Enabled*, *Locked* and *Test mode*, the row the standard's `ADDONS.md` records for it, and
no *Show window*. Neither button is reassignable and there is no setting for either; the menu and
the click routing are the library's, never the addon's (launcher-§2, anti-pattern #81).

**Both broker libraries are optional.** `LibKa0s-Launcher-1.0` resolves them with
`LibStub(…, true)` at Register time, so a client with LibDataBroker but no LibDBIcon gets the
broker plugin and no button, one with neither gets a line naming what is missing, and one without
LibKa0s at all gets `core/LauncherSetup.lua`'s stub. In every case the stored `hide` is still written, so the
checkbox reflects what the player chose and a later reload draws the button where they left it.

## The degraded panel

With `libs/LibKa0s/` missing, `settings/OptionsSetup.lua` installs a **load-completing** stub
(options-ui-§1): the five composers (`ColorPair`, `FontGroup`, `BorderGroup`, `BarGroup`,
`MasterControls`) and `MASTER_GROUP` (every member a page file touches at file load), and a real
`RestoreAllDefaults` (one bulk act under `NS.Bulk.Run`, logged once by `NS.OnProfileReset`). Every
composer answers an **empty row list** (`MasterControls` answers `{}` and a no-op tail), so the page
files finish loading and register their hand-written rows while every composed row (the Master
controls block, the font, border, bar and color-pair blocks) is absent from that build's schema: a
host copy of a composed block in the stub is anti-pattern #73. `/am set` on a composed path, like
every schema verb in that build, prints the library-absent line (`/am set is unavailable: the LibKa0s
library did not load.`). `/am enable`, `/am disable`, `/am lock` and `/am unlock` keep working: their
two paths, `enabled` and `locked`, are declared in `NS.WRITE_THROUGH` (`settings/Schema.lua`), and
`NS.SetByPath` stores a listed path that has no row raw, with no validate, normalize or onChange, then
logs and announces it (route (a)); `runEnabled` syncs the latch itself. Every other function
member of the live instance, this addon's decorations (`SelectContainer`, `ContainerBanner`,
`RenderPage`, …) included, is carried as a no-op, so no call site finds a member missing
(testing-§8); the library's layout and composer constants, `AceGUI` and `LSMValues` are not copied.
The panel itself (`CreateOptionsPanel`, `OpenOptionsPanel`) answers one line naming the missing
library. `tests/degraded_env.lua` builds that environment for the suite,
`tests/test_surface_parity.lua` compares its member set against the live instance, and
`tests/test_optionssetup.lua` pins the full row count, the library-absent count and the delta, derived
from what the live composers emit.
