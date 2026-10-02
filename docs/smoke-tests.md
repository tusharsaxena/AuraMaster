# Smoke tests — Ka0s Aura Master

These are the in-client checks the headless suite (`docs/testing.md`) cannot make: what the client
draws, what it refuses, and what it does in combat. Run them on a live Retail client at the
`## Interface` the TOC names, after a `/reload` on a clean session, with Lua errors on; turn the
debug console on only where a step says so. Checks are grouped by theme and each stands alone once
[Before you start](#before-you-start) is done. Record each run on the check's `Result:` line as
`PASS` or `FAIL`, who ran it and the date, plus a note on anything that failed. Every check has an
ID `<THEME>-<n>`. IDs are stable: a new check takes the next number in its theme, and a retired
check's number is not reused. Checks with no recorded pass, and checks new or corrected on
2026-09-29, are listed under [Pending sign-off](#pending-sign-off).

## Index

| ID range | Theme | What it covers |
|---|---|---|
| INSTALL-1 to INSTALL-8 | Install, load and upgrade | First login, the starter containers, `/reload`, and SavedVariables from older builds |
| SLASH-1 to SLASH-11 | Slash commands | `/am` and `/auramaster`, help, unknown verbs, the container verbs, the schema CLI and `/am redraw` |
| PANEL-1 to PANEL-27 | Settings panel and launcher | The tree, landing page, General page, the Containers band and rail, Blizzard frames, the minimap button and broker |
| PROFILE-1 to PROFILE-13 | Profiles | The Profiles page, the `/am profile` verb, and what a profile holds |
| STATE-1 to STATE-5 | Master switch | Enable and disable, visibility, the inert disabled addon |
| COMBAT-1 to COMBAT-7 | Combat and restrictions | Deferred changes, the settings lock, resets in combat, Mythic+ keys |
| DIAG-1 to DIAG-20 | Debug, diagnostics, perf | The debug console, bulk `[Set]` lines, `/am diagnostics`, `/am perf`, the event trace, resizing the console, its copy window and the perf panel, the console's Diagnostics link, diagnostics turning logging on, the library's own lines (a slash refusal, a stand-down edge, the launcher's at-enable line) |
| CONT-1 to CONT-25 | Containers | Create, duplicate, delete, rename, copy; handles, strips and the close mark; test mode; unit swaps; empty placeholders |
| FILT-1 to FILT-63 | Filters and spell categories | Cast by, the category grids, Overrides, the add-a-spell box, aura ids, your own categories, weapon enchants and their names, the help marks' art, where spell lists apply, the Situations tab, its zones and its Unit type gate |
| LAYOUT-1 to LAYOUT-38 | Layout | Anchor modes, attaching, chains, growth, anchor points, seams, the name label, mouse and tooltips |
| DRAG-1 to DRAG-16 | Layout | Drag to attach (issue #22): dropping a container on another, the highlight, the side a drop picks, Shift, loops, detaching and its leeway (green hold, snap back, red past it), the growth-conflict popup, combat, a parent holding auras, frame-attached containers, the strip's tooltip, a drop between pulls in a key, a dropped side surviving a growth change, a drag cut short, a before-side drop with the line between the two join dots |
| STYLE-1 to STYLE-30 | Bars and Icons style, fonts | Bars and Icons tabs, the spark, borders, dispel colors, pandemic, the font primer |
| TEXT-1 to TEXT-29 | Text style | Templates and tokens, justify, the icon, dispel type word, backdrop and edge, animation, Size to fit |
| DEGRADED-1 | Library-absent install | The launcher libraries missing |
| LOC-1 to LOC-2 | Non-English client | Spell names from the client, adding a spell by its localized name |

## Before you start

- **Client.** Live Retail at the TOC's `## Interface` (120100 when this was written). `/console
  scriptErrors 1`, or BugSack, for the whole run: every check expects no Lua error and no
  `ADDON_ACTION_BLOCKED` or taint warning unless it says otherwise. Chat lines carry the cyan `[AM]`
  tag.
- **Place.** A training dummy, with a party or a friendly player nearby for the target and focus
  checks. COMBAT-2, COMBAT-7, DIAG-11 and DIAG-12 need a Mythic+ key or a boss encounter.
- **The starter set.** Most checks start from a fresh profile's four starters: #1 *Player buffs*
  (bars), #2 *Player debuffs* (icons, growing left), #3 *Target debuffs (mine)* (icons, growing right)
  and #4 *Player cooldowns* (Text). Make a spare profile for this (PROFILE-2) so your own set is not
  touched.
- **The chain.** LAYOUT and some CONT checks use a chain: three Text containers A, B and C, each
  Justify Center and growing down, B attached to A and C attached to B (Layout → Anchor → Attach to
  *Another container*), both anchor-point rows left on Automatic. Name them so the names fit their
  strips.
- **Upgrade checks** (INSTALL-5 to INSTALL-8) need a copy of `WTF/Account/ACCOUNT/SavedVariables/AuraMaster.lua`
  saved by an older build. Back the file up first: a profile loaded once on a newer build cannot go
  back.
- **Opening the settings.** `/am` opens the panel. Filters, Layout and the style sections (Bars,
  Icons, Text) are entries of the rail on the Containers page, not Settings tree entries; the band's
  Container picker chooses which container they edit.

## Install, load and upgrade

**INSTALL-1. Fresh install.** Remove `WTF/Account/ACCOUNT/SavedVariables/AuraMaster.lua` and log in →
the world loads with no Lua error. Result:

**INSTALL-2. Starter containers.** On that fresh install, with no setup → four containers appear: #1
*Player buffs* as bars near the top right, #2 *Player debuffs* as icons just above it, #3 *Target
debuffs (mine)* as icons below the screen center, and #4 *Player cooldowns* as Text left of center.
Your current buffs show in #1; target the dummy and apply a debuff → it appears in #3. Pop an
offensive and a defensive cooldown → #4 shows both and nothing else (no food, flask, mount or raid
buff). Result:

**INSTALL-3. Reload.** `/reload` → no Lua error; every container is where it was. Result:

**INSTALL-4. Deleted starters stay deleted.** Delete all four (Containers → General → Delete),
`/reload` → they do not come back, because the profile is marked seeded. Get them back with
General → Reset all settings (PROFILE-4). Result:

**INSTALL-5. Upgrade from before schema v2.** On a build before schema v2, in two profiles: untick a
starter spell in *Core healing* and add a spell to *Lesser healing* on one container; add a spell to
*Defensive cooldowns* on a second container; set a bar container's **Color by** to dispel type and
change its Magic color; leave a container's strata at Medium. Log in on this build → no Lua error.
General → Spell Categories lists one *Healing* category (no Core or Lesser healing) holding the added
spell, with the starter unticked; *Defensive cooldowns* holds the other added spell. Dispel Colors →
Magic shows the color you set. Layout → Frame → Strata reads High where it was Medium. Switch to the
other profile → the same. Result:

**INSTALL-6. Upgrade of a Weapon enchants container (schema v5).** Use a SavedVariables file with a
Weapon enchants container whose "Always shown" list held spells. Log in, then `/am debug on` → the
console's `[Init]` line reads `schema v11`. The container now reads unit Player, aura type Buffs,
only **Weapon enchants** shown on Filters → Categories, and an empty Overrides list; it draws no
group from the cleared whitelist. Apply an enchant (a sharpening stone, a rogue poison, a shaman
imbue) → it shows, with no "can never match" warning. The Aura type dropdown on Containers → General
offers Buffs and Debuffs only. Result:

**INSTALL-7. Size to fit on upgrade (schema v8 and v9).** On a SavedVariables file from before
schema v8 → every Text container keeps its Width and Height, and **Size to fit** is unticked on its
Text page. `/dump` a bars and an icons container's stored `text` table from `AuraMasterDB` → no
`autoSize` key; a Text container keeps its stored value. Change a bars container's Style to Text →
**Size to fit** starts ticked. Result:

**INSTALL-8. Chains stay put through the attach upgrades (schema v8 to v11).** Note where every
chain sits on the old build, locked and in test mode. Log in on this build, then `/am debug on` →
the console's `[Init]` line reads `schema v11`. Every chain sits where it did, locked and in test
mode, with these exceptions only: a follower that was on the old default side now reads Automatic in
both anchor-point rows and takes Automatic's place, so a Text follower justified Center moves to the
center, and one justified to its growth's end side to that end (LAYOUT-10); an Icons or Bars
follower under a Text parent justified Center moves to the center (LAYOUT-12). A follower that had a
picked side reads that pick in both rows (Side Bottom reads Parent **Bottom**, This **Top**). A
container attached to another with the old 0/-4 offsets reads 0/0 on its Layout page; any other
offsets are unchanged. `/am select` a screen container, `/am get container.attach.y` → `0`; `/am
diagnostics` lists no `attach.y=-4`. Switch a container that was on the screen to Another container
→ it gains no 4px nudge (its X/Y offsets read 0). `/am get container.attach.edge` → "Setting not
found". `/reload`, then `/am debug on` → nothing has moved, and the `[Init]` line still reads
`schema v11`. Result:

## Slash commands

**SLASH-1. Opening the settings from chat.** `/am` → Settings opens at **Ka0s Aura Master** with no
chat line. `/am` followed by only spaces, `/auramaster`, `/am config` and `/am options` (an alias of
`config`) → the same. In combat, `/am` and `/am config` → the gray "cannot open settings during
combat — Blizzard's category-switch is protected" line, no taint warning, and the panel does not pop
open when combat ends. Result:

**SLASH-2. Help.** `/am help` → the version line, then one row per command, 25 in all: a gold `/am
verb`, an em dash and a white description. `profile`, `test`, `redraw` and `diagnostics` are listed,
`redraw` right after `forgettimed`, `diagnostics` right after `debug`, and the `debug` row does not mention `diag`. Result:

**SLASH-3. Unknown verb.** `/am wibble`, and `/am preview` → the unknown-command line, then the help
block. Result:

**SLASH-4. Version.** `/am version` → the version on the TOC's `## Version` line, as `v<version>`.
Result:

**SLASH-5. List containers.** `/am containers` → one line per container in creation order (not by
name), the selected one marked `>`. Result:

**SLASH-6. New from chat.** `/am new target debuffs icons` → `Created …` naming a
target/debuffs/icons container, which appears on screen, becomes the selected one, and whose Layout →
Growth → Fill reads Rows. `/am new text` → a Text container whose Fill reads Columns. `/am new
nonsense` → `Unknown word 'nonsense' …`, nothing created. Result:

**SLASH-7. Select.** `/am select 1`, and `/am select player buffs` in any case → `Selected …`. `/am
select 999` → `No such container …`. Result:

**SLASH-8. The schema CLI.** `/am get container.name` → the selected container's name, annotated in
gray. `/am set container.layout.scale 1.5` → it grows; `/am reset container.layout.scale` → back.
`/am list` → every row, the `container.` rows annotated. `/am get container` and `/am set container 1`
→ both answer "Setting not found: container", and `/am list` reads as before. Result:

**SLASH-9. Light redraw.** With the starter containers showing, `/am debug on`, then `/am redraw light`
→ `Light redraw: N container(s) repainted`, N counting the containers on screen, and the console
shows `[Apply] redraw light: N container(s) flipped`. Every container still shows the same auras
with their timers running. `/am redraw LIGHT` → the same. `/am redraw everything` → `Usage: /am
redraw [light|full]` and nothing else. Pull a dummy and `/am redraw light` in combat → the same
line, no "will apply" notice, no taint warning and no `ADDON_ACTION_BLOCKED`. Result:

**SLASH-10. Full redraw.** Out of combat, `/am debug on`, `/am diagnostics`, then `/am redraw full`
→ `Full redraw: fonts primed, N container(s) repainted, every container re-dressed`, and the console
shows `[Apply] redraw full: N container(s) flipped, re-apply queued`, then `[Apply] applied M
container(s)`. `/am diagnostics` again → each `[Cont]` line's `retired=` count is the same as before:
no engine was rebuilt. Pull a dummy and `/am redraw full` in combat → `Full redraw: fonts primed, N
container(s) repainted; the re-dress waits until it is allowed`, then `[AM] Aura Master settings
changes will apply when combat ends.` (unless that line already printed this fight); leave combat →
`[Apply] applied M container(s)` with no error. Result:

**SLASH-11. Bare redraw.** Out of combat, `/am redraw` → the `Full redraw: …` line of SLASH-10. In
combat, `/am redraw` → `Light redraw: N container(s) repainted`, then `A full redraw has to wait
right now, so a light one ran; /am redraw full queues the rest`, and no "will apply" notice. Inside
a Mythic+ key or a boss encounter, out of combat between pulls → the same two lines. `/am disable`,
then `/am redraw`, `/am redraw light` and `/am redraw full` → each answers only `Ka0s Aura Master is
disabled — enable it with /am enable`; `/am enable` after. During the suspended arm of a perf
capture (`/am perf measure b`), `/am redraw` and `/am redraw full` → `Full redraw skipped: Aura
Master is stood down while a perf capture runs`, and `/am redraw light` → `Light redraw: 0
container(s) repainted`. Result:

## Settings panel and launcher

**PANEL-1. Landing page and tree.** `/am config` out of combat → Settings opens at **Ka0s Aura
Master**: the logo, the Notes line, the Slash Commands list matching `/am help`, and no tab strip.
The tree under it reads **General · Containers · Profiles**, with no Filters, Layout, Bars, Icons or
Text entry, indented or not. Result:

**PANEL-2. The General page.** General → the strip **[ Master controls ][ Display ][ Spell Categories
][ Dispel Colors ]**, and no Container picker above it. Master controls reads, two per line: Enable
Aura Master | General visibility / Master scale | Master alpha / Lock frame | Debug console, with the
**Test mode** row beside **Minimap button**, then **Reset position** and **Reset all settings**.
Result:

**PANEL-3. Master scale and alpha.** Change **Master scale** and **Master alpha** → every container
scales and fades together, multiplying each container's own Layout → Frame scale and opacity.
Result:

**PANEL-4. The Containers band.** Open Containers → the band above the rail and tab strip holds the
**Container** picker and **New container** side by side and aligned; the General section's first tab
is named **General**. Hover New container → its tooltip. The picker switches the page's subject.
Flip the picker between two containers 20 times, then `/dump collectgarbage("count")` → it stays
flat against a reading taken before. Result:

**PANEL-5. The Containers General tab.** Containers → General → Name and Enabled, then the
subsection heading **What it shows, and how** with Unit, Aura type and Style under it (no heading
above Name, and the three rows visibly one block apart from the two), then Duplicate and Delete,
then, with two or more containers, Copy settings from. Select a container and **Delete** it → the
picker and New container are still there, and the picker lists what is left. Result:

**PANEL-6. General Defaults keeps the name.** Rename #1 and change its Unit, then press **Defaults**
on Containers → General → Enabled, Unit, Aura type and Style go back to their defaults, and the name
you typed stays. Result:

**PANEL-7. The rail.** Open Containers with #1 selected → the band is on top, and the rail on the
left lists General · Filters · Layout · Bars. The rail's top edge is level with the top of the tab
art, not the empty space above it. Result:

**PANEL-8. Only the controls scroll.** Rail → Bars → General, scroll to the bottom → only the
controls move; the band, the rail and the tab strip stay put. Result:

**PANEL-9. The first draw after a reload.** `/reload`, then open Containers as the first page of the
session → the tabs sit in one row to the right of the rail from the first frame, not stacked one per
row and none under the rail. Result:

**PANEL-10. The rail's look.** Look at the rail and hover each entry → the tree-pane look (a dark
fill and a thin gray tooltip border); entries gold, the selected one white on a blue bar, a highlight
on hover, visibly different from the gold tabs. Each entry's tooltip says what the section holds.
Result:

**PANEL-11. The style section follows the container.** Make a second bars container (Containers →
**New container**), then pick #1 in the band and open Bars → **Icon**. Pick the new container in the
band → the page stays on Bars → **Icon**, now showing the new container. On Bars, pick #2 (icons) in
the band → the style entry renames to Icons, its tabs follow, and the page stays on the style section,
not General. Back on #1's Bars, change Containers → General → Style to Icons → the same. Open Layout →
the band still has the same container selected. Result:

**PANEL-12. Each section keeps its tab.** Filters → Categories, then Layout, then back to Filters →
Filters opens on Categories. Rail → Bars → Time text, then another section, then Bars → it reopens
on Time text. Result:

**PANEL-13. Section Defaults.** Change a Layout setting and a Bars setting on #1. With Layout
selected, click **Defaults** → only the Layout rows go back to defaults, on #1 only; the Bars change
stays, and other containers are untouched. Result:

**PANEL-14. No containers.** With the Filters section open, delete every container (Containers →
General → Delete, each), close the panel, `/am config`, open Containers → the rail lists General
alone with "No containers yet. Click New container, or type /am new." There is no placeholder
"Container" tab and no "Create one on Containers" line. Click **New container** → Filters, Layout and
the style section appear. Result:

**PANEL-15. A new container lands on General.** Rail → Bars → Time text, then **New container** in the
band → a new container is made and selected, and the page shows the General section and tab with its
Name. Rail → Bars → it reopens on Time text. Keep the panel open, type `/am new` → the page moves to
General on the new container, the same as the button. Go to Filters, close the panel, type `/am new` →
the panel does not open; `/am` → it opens on General with that container. Result:

**PANEL-16. Media dropdowns.** Every media dropdown (bar texture, background, border, font) opens with
entries in it. Result:

**PANEL-17. Other Ka0s addons' pages are unchanged.** Open the settings of another Ka0s addon (KickCD
or MultiMeters) → their tab strips, content panels and scroll bars sit where they always did: a page
with no rail does not move. Result:

**PANEL-18. Container pickers sort by name.** Name three containers "zeta", "Alpha" and "beta" →
the band's Container picker (on every rail section) lists Alpha, beta, zeta, capitals not first,
each followed by its gray "(unit, aura type, style)". Containers → Copy settings from's source and
Layout → Anchor → Parent container (None first) list in the same order. Result:

**PANEL-19. Section wording.** Containers → General, hover **Aura type** → "Buffs or debuffs. The
Filters section offers the categories of whichever you choose; …". No tooltip or line in the panel
names a Filters, Layout, Bars, Icons or Text *page*. Result:

**PANEL-20. Hide Blizzard frames.** General → Display → **Hide Blizzard buffs** → the default buff
frame goes, with its weapon enchants; **Hide Blizzard debuffs** → the default debuff frame goes.
Untick → both return. In combat, `/am set hideBlizzardBuffs true`, then the other one → chat prints
`[AM] Aura Master settings changes will apply when combat ends.` once, and both apply when combat
ends. Result:

**PANEL-21. The AddOns list.** Esc → AddOns (or the character-select AddOns list) → *Ka0s Aura
Master* shows the addon's own logo, not a blank square and not a Blizzard icon. Result:

**PANEL-22. The minimap button.** A round button wearing that logo sits on the minimap ring. Drag it
around the ring → it follows; `/reload` → it is where you left it. Hover it → the title **Ka0s Aura
Master** followed by `v<the TOC version>`, `Enabled: Yes`, `Locked: Yes|No`, `Test mode: On|Off`
(green or red, matching General → Master controls), `Left-click: Open settings`, `Right-click:
Options menu`, nothing twice. `/am unlock` or `/am test` → the next hover says so. `/am disable` →
the tooltip still shows, `Enabled: No`, with the same two hints; `/am enable`. Result:

**PANEL-23. Left-click opens the settings.** Left-click the button → Settings opens at **Ka0s Aura
Master**, and neither the lock nor test mode changes. `/am disable`, left-click → the panel still
opens. `/am enable`. Result:

**PANEL-24. Right-click opens the options menu.** Right-click → a menu titled **Ka0s Aura Master**
with exactly three checkboxes, **Enabled**, **Locked** and **Test mode**, each matching General →
Master controls. Click **Test mode** → the menu closes, every container shows placeholders, chat
prints what `/am test` prints, and the Test mode checkbox ticks; right-click again → ticked; click it
→ they go. Click **Locked** → chat prints what `/am unlock` (or `/am lock`) prints, and the handles
appear (or go). Click **Enabled** → chat prints what `/am disable` prints, and the containers go.
Right-click now → **Locked (enable the addon first)** and **Test mode (enable the addon first)** are
grayed and do nothing; **Enabled** brings the addon back with the `/am enable` line. In combat, click
Test mode while it is off → the combat refusal `/am test` prints. Result:

**PANEL-25. The checkbox and the button agree.** Untick General → Master controls → **Minimap
button** → the button vanishes at once, no reload; tick it → it returns at the same angle. `/am set
global.minimap.shown false` → reopen the settings: the checkbox is unticked too. Result:

**PANEL-26. The button survives profile switches and resets.** Hide the button, then Profiles →
create and switch to a new profile → it stays hidden. Switch back, then General → **Reset all
settings** → still hidden, the checkbox unticked. Press General's own **Defaults** → still hidden,
while every other General row goes back to its default. `/am get global.minimap.shown` → `false`;
`/reload` → still hidden; `/am reset global.minimap.shown` → it comes back and `/am get` reads `true`.
`/am get global.minimap.hide` → `Setting not found`. Result:

**PANEL-27. A broker display.** With Titan Panel, Bazooka or ElvUI data texts installed, add *Ka0s
Aura Master* as a plugin → one row labeled exactly that, grouped with the other Ka0s addons rather
than filed under `A`, the same logo, no empty value cell. Its left click opens the settings, and its
right click the same three-entry menu as the minimap button's. Result:

## Profiles

**PROFILE-1. The page draws.** Open another addon's options page first, then Aura Master →
Profiles → the AceDBOptions controls render (current profile, New, Copy From, Delete, Reset Profile),
never a blank page under the header. Result:

**PROFILE-2. A new profile gets the starters.** Profiles → create a new profile → the four starter
containers appear on it. Switch back → your own set returns, each where you left it. Result:

**PROFILE-3. Copy.** Profiles → **Copy From** another profile into the active one → its containers
replace yours. Result:

**PROFILE-4. Reset all settings.** General → **Reset all settings** → the popup reads *"Reset this
profile to the addon's defaults? Everything you have configured or added in it is discarded — your
other profiles are not affected."* → **Yes** → the starter containers and default settings return;
other profiles are untouched. `/am resetall` does the same. Result:

**PROFILE-5. `/am profile` lists the profiles.** With two or more profiles, `/am profile` → a green
**Profiles** header with no trailing colon, one indented row per profile sorted without regard to
case, the current one followed by `(current)`, then `/am profile <name> switches profile`. Nothing
switches. Result:

**PROFILE-6. `/am profile <name>` switches.** `/am debug on`, then `/am profile <another profile>`,
typed in its exact case → `Switched to profile '<name>'.`; that profile's containers replace the
current set at once, and the debug console holds one `[Profile] changed -> <name>` line. Open
Profiles and leave it open, then `/am profile Default` → `Switched to profile 'Default'.`, and the
page's current profile reads Default without a reopen. Result:

**PROFILE-7. Already on it.** `/am profile <the current profile>` → `Already on profile '<name>'.`,
and nothing redraws. Result:

**PROFILE-8. An unknown name is refused.** `/am profile Nosuch` → `No profile named 'Nosuch'.`, then
the list; no profile is created (Profiles lists the same set, and no starter containers appear). With
a profile named `Raid`, `/am profile raid` → `No profile named 'raid'.`, then `Did you mean 'Raid'?`,
then the list, and nothing switches. Result:

**PROFILE-9. Quotes and spaces.** Create a profile named `Raid Night` on the Profiles page, switch
back to Default. `/am profile "Raid Night"` → `Switched to profile 'Raid Night'.` `/am profile
Default`, then `/am profile 'Raid Night'` → the same switch. `/am profile Default` again, then `/am
profile Raid Night` → the same switch again. Result:

**PROFILE-10. While disabled.** On Default, `/am disable`, then `/am profile` → the list, not the
disabled refusal. `/am profile <another profile>`, one whose General → **Enable Aura Master** is
ticked → it switches and the addon comes up with it: that profile's containers draw and **Enable Aura
Master** reads ticked. `/am profile Default` → the addon goes down again: every container hides and
**Enable Aura Master** reads unticked. `/am enable` → Default's containers draw. Result:

**PROFILE-11. Refused in combat.** Enter combat, `/am profile <another profile>` → `Can't switch
profiles in combat.`, and nothing switches. `/am profile` alone still lists the profiles in combat.
Result:

**PROFILE-12. A reset in combat tears containers down.** The Profiles page and `/am profile` are
refused in combat (COMBAT-3, PROFILE-11), so a reset is the one profile change combat allows. Out of
combat, make a fifth container (CONT-1) and point container 1 at focus. In combat, `/am resetall` →
the fifth container stops drawing, is torn down when combat ends, and no taint warning appears.
Container 1 draws nothing in combat, never focus auras under the reset container's name, and once
combat ends it draws the new container 1 (player buffs). Result:

**PROFILE-13. Your categories belong to the profile.** Make a category (FILT-31), then Profiles →
create and switch to a second profile → General → Spell Categories does not list it, and the Filters
grid has no row for it. Switch back → it is there, with its spells and its Show or Hide. `/reload` on
each profile → no Lua error, and no `/am list` row for a category the loaded profile does not have.
Result:

## Master switch

**STATE-1. Enable and visibility.** Untick **Enable Aura Master** → every container disappears;
re-tick → back. Set **General visibility** to *Only in combat* → containers hide out of combat and
show in combat; *Only out of combat* is the reverse; *Never* hides them; *Always* restores. In
combat, `/am set visibility never` (the page itself is locked in combat) → every container hides at
once, with no "will apply when combat ends" line; `/am set visibility always` → they are back at
once. Result:

**STATE-2. Disable and enable from chat.** Out of combat, `/am disable` → `enabled = false` (gold
key, white value, the shape `/am get enabled` prints) and every container hides; General → **Enable
Aura Master** is unticked. `/am enable` → `enabled = true` and every enabled container shows again.
`/am unlock` and `/am lock` answer the same way, `locked = false` and `locked = true`. Result:

**STATE-3. The disabled addon is inert.** With it disabled: Blizzard's buff and debuff frames come
back if you had them hidden; changing target, entering and leaving combat and summoning a pet do
nothing at all; `/am` still opens the panel, and `/am list`, `/am get` and `/am set` still read and
repair settings; `/am lock` answers `Ka0s Aura Master is disabled — enable it with /am enable` on one
line. Ticking **General → Master controls → Test mode** answers that same line and the box stays
unticked. Result:

**STATE-4. Reload while disabled.** `/am disable`, `/reload` → it comes up disabled, still answers
`/am`, and built no container: `/framestack` over the screen shows no `AuraMasterAnchor` frame and
`/dump AuraMasterAnchor1` is nil. `/am enable` → every container draws at once. Result:

**STATE-5. Disable and enable in combat.** Enter combat with containers shown, `/am disable` → the
same `enabled = false` line, no gray refusal and no "will apply when combat ends" notice; the
containers' engines go quiet at once and the anchors finish hiding when combat ends. `/am enable` in
combat → the containers return at once. No taint warning either side. Result:

## Combat and restrictions

**COMBAT-1. Changes wait for the end of combat.** Enter combat and change a container's bar width or
a filter with `/am set` → chat prints once `[AM] Aura Master settings changes will apply when combat
ends.`, and nothing changes on screen. Leave combat → the change lands with no reload and no error.
In combat, `/am lock` and a `/am set` rename print no notice. With a target container's border on
class color, target a player of another class and pull at once → no notice prints, and the border
takes the new class color when combat ends. Result:

**COMBAT-2. Changes wait for a key or encounter to end.** Inside a Mythic+ key or a boss encounter →
a change waits until the key or encounter ends, even if you drop combat between pulls. A change made
out of combat inside the key prints once `[AM] Aura Master settings changes will apply once aura
information is available again (after the encounter, key or match).` A change made in combat there
prints the combat line; nothing more prints the moment combat ends, and the next change still held
after the pull prints the restriction line once. Result:

**COMBAT-3. The settings lock covers every page.** Open the settings on a Bars page, then pull a
dummy → the whole page, the band, the rail and the tab strip included, goes under a gray "Settings
are locked during combat." cover. In one long pull, show General, Containers (each rail section),
Profiles and the landing page in turn → each is covered. On each, clicking a checkbox, dragging a
slider, typing in a box (Template, a spell id), a tab click, Defaults and Duplicate change nothing;
the values after combat are the ones from before the pull. Result:

**COMBAT-4. Switching page in combat.** With the settings open, pull, then click other Aura Master
categories and another addon's in the AddOns sidebar → each shows covered, the window stays open,
no `ADDON_ACTION_BLOCKED` and no "C stack overflow". The gray `settings are locked during combat —
changes are refused until it ends` line prints once per combat however many pages you show; a
second pull prints it once more. Change a value with `/am set` during the pull, then leave combat →
the cover lifts on the page you are on, its controls work at once, and it shows the new value with no
reload or reopen. Result:

**COMBAT-5. A rail entry in combat.** In combat, click a rail entry, then leave combat → nothing
changes during combat and one gray "locked" line prints; after combat the page draws normally.
Result:

**COMBAT-6. Reset all in combat.** In combat, `/am resetall` → the profile resets, its
acknowledgment prints, and no gray line. Open General → **Reset all settings** before a pull, leave
the popup up, pull, then **Yes** in combat → the same. Clicking the button itself in combat is
refused by the settings lock. Result:

**COMBAT-7. A reload inside a key.** In a Mythic+ key, out of combat between pulls, `/reload` →
every container draws right after the loading screen (the buffs you carry show), not only once the
key ends. `/am debug on`, then `/am diagnostics` → `apply queue: all=false`, and every `[Cont]` line
reads `engine=yes`. Pull the next pack → auras appear and time down in every container as usual.
This needs auras secret out of combat at login, which a key between pulls gives (a PvP match may
too; unverified). Result:

## Debug, diagnostics and perf

**DIAG-1. A perf capture.** `/am perf` → status lines and the step panel. Run a capture as in
`docs/perf-analysis/README.md` → `/am perf report` prints the summary and the JSON line; containers
hide during the suspended arm and come back after **finish** with no reload. Result:

**DIAG-2. The debug console.** Bare `/am debug` → the console opens (again → it closes), and General's
**Debug console** checkbox follows it. `/am debug on` → lines such as `[Set] … = …` stream as you
change settings; `/am debug off` stops them. `/reload` → logging off, window closed. Result:

**DIAG-3. One line per bulk act.** With `/am debug on`, each bulk act logs one `[Set]` line and no
per-row lines: #1's Bars **Defaults** after changing Width → `[Set] reset bars: N rows` with N at
least 1, and again → `reset bars: 0 rows`; **Copy settings from** #1 to #2 → `[Set] copy container
1->2 (<section>): N rows`; General → **Reset position** → `[Set] reset positions: N rows`, then
`/am resetposition` straight after → `[Set] reset positions: 0 rows` (the first container's `-0`
offset over a stored `0` is no change); Filters → Categories → **Hide all** → one `[Set] hide all …`
line; General → **Reset all settings** → only `[Set] reset profile 'Default' to defaults`, no row
count; Profiles → **Copy** → only `[Set] copied profile 'A' -> 'B'`. Result:

**DIAG-4. A memory spot-check.** `/run print(collectgarbage("count"))`, change a bar container's
width 10 times, print it again, and record both numbers and the growth. Result:

**DIAG-5. `/am diagnostics` out of combat.** With a target, a focus and a pet, `/am diagnostics` → the
console opens, one chat line gives the line count, and the report runs from the begin marker to the
end marker with no `attempt to compare ... secret boolean` line. Its `[Aura]` names and stacks match
Blizzard's own buff and debuff frames; every container has its `[Cont]`, `[Filt]` and `[Plan]` lines,
each `[Plan]` reading `shown=` with a number, `?`, or a `<n>+<k>?` count (a `[Shown]` line with
`shown=?` for each button that could not be read). Press **Copy** → no color codes; paste it into a
file and nothing is cut off. Whitelist a spell whose buff is up → `[Shown]` lists a button and
`predicted:` reads shown (rank 1); record whether the button line carries the aura's inst/id or only
its name or icon. `/am test` → run it again: the same, no error; `/am test off` → a third run matches
the first. Result:

**DIAG-6. Diagnostics in combat and while disabled.** In combat on a dummy, `/am diagnostics` → the
units read unreadable, `[Cont]`, `[Filt]` and `[Plan]` still print, `frames=` is a number or `?`,
`shown=?`, and no `[Shown]` button lines. With #1 selected (`/am select 1`), in combat `/am set
container.filter.castBy mine` (the page itself is locked in combat) and run it again → #1 reads
PENDING (combat); after combat → plan in sync. `/am disable`, then `/am diagnostics` and `/am debug
diagnostics` → each runs, the state line reads enabled=false, and after the state flags the header
adds "addon disabled: containers are hidden and not updated; the plan lines are from the last apply".
`/reload` still disabled, `/am diagnostics` → "addon disabled: containers are not built; predictions
only", each `[Plan]` reads `not built (addon disabled)`, and `Shown` holds only `predicted:` lines.
`/am enable`, run it → no such line, and the verdicts read as before. Result:

**DIAG-7. Report caps.** With about eight containers and a long whitelist → the report stays under
the cap or ends with a `truncated` line, and the console never holds more than 3000 lines. Result:

**DIAG-8. The two forms, and no `diag`.** `/am debug on`, reproduce anything, then `/am diagnostics`
→ the report appends after the trace lines, so one **Copy** carries both. `/am debug diagnostics` →
the same report again. `/am debug diag` → no report: the console just toggles, as for any unknown
word after `debug`. Result:

**DIAG-9. Only the rows in use.** In a report: a container on the screen lists no `attach.container`
or attach offsets on its `#id non-default:` line (any it still stores sit on its `#id inert:` line);
a container attached to another puts a stored screen position, if any, on its `inert:` line. A bars
or icons container never lists `text.autoSize` on `non-default:`. A container with nothing inert
prints no `inert:` line. Result:

**DIAG-10. Both anchor points.** On the chain, `/am diagnostics` → the header reads the current
schema version; B's `[Cont]` line reads `attach=container#<A's id> point=TOP(auto)
relPoint=BOTTOM(auto) join=after-center` with both rows Automatic. Pick This container Top left → the
line reads `point=TOPLEFT(picked) relPoint=BOTTOM(auto)` with `join=free`; pick Center to Top right →
`point=CENTER(picked) relPoint=TOPRIGHT(picked) join=free`. A container on the screen or a named frame
prints no `point=` or `join=`. Put both rows back to Automatic. Result:

**DIAG-11. The event trace through a key.** In a Mythic+ key, `/am debug on`, then play on: a pull,
the kill, a boss and the key's end → the console carries `[Event] PLAYER_REGEN_DISABLED` /
`_ENABLED` lines at each pull and kill, and `[Event] ADDON_RESTRICTION_STATE_CHANGED secret=…
lockdown=… queued=… type=<n> active=<0|1|2>` lines; every `[Event]` line has `secret=… lockdown=…
queued=…` right after the event name. No `[Event]` line on a target, focus or pet change. Copy the
whole console into the bug thread: the `type=` values seen at the key's start, a boss and the key's
end are the record this check takes. Result:

**DIAG-12. The event trace at a boss.** Without a key, a boss encounter anywhere (a follower dungeon
or LFR boss) with `/am debug on` → `[Event] ADDON_RESTRICTION_STATE_CHANGED … type=1 active=1` at the
pull and `… type=1 active=0` at the kill. This does not stand in for COMBAT-7: a `/reload`
mid-encounter lands in combat, where the login build waits for combat to end by design. Result:

**DIAG-13. Resizing the debug console.** Bare `/am debug` → the console opens at 700 × 344 with a
size grip in its bottom-right corner. Drag the grip out → the window grows on both axes, the lines
reflow to the new width, the scrollbar and the line counter follow, and no line is lost. Drag it in
as far as it goes → it stops while every title-bar control and the title still fit, with the status
bar and a few lines showing. Close it and open it again → the size you left it at. `/reload` → it
opens at 700 × 344 again. With another Ka0s addon loaded, open its console too → it opens at its own
default, and resizing one leaves the other as it was. Result:

**DIAG-14. Resizing the copy window.** In the console press **Copy** → the copy window opens at
560 × 360 with a grip in its bottom-right corner. Drag the grip → it resizes on both axes and the
text area widens and narrows with it; the scroll bar's down arrow stays clickable above the grip.
Drag it in as far as it goes → it stops at 240 × 140. Close it and press **Copy** again → the size you
left. `/reload` → 560 × 360 again. Another Ka0s addon's copy window keeps its own size. Result:

**DIAG-15. Resizing the perf panel.** `/am perf` → the step panel opens at its usual size with a grip
in its bottom-right corner. Drag the grip → only the width changes, and every step row stretches to
it; dragging up or down does nothing. Drag it narrower → it stops at the width it opened at. Close
it and run `/am perf` again → the width you left. `/reload` → the usual width again. Another Ka0s
addon's perf panel is unaffected. Result:

**DIAG-16. The Diagnostics link.** Bare `/am debug` → in the title bar, top left, the word
**Diagnostics** sits just right of the Debug On/Off label with a small gap, drawn orange in the same
plain text as that label: no button art, border or background. Hover it → it brightens; move off →
orange again. With logging off, click it → logging turns on first: the label reads Debug On, chat
prints the `debug logging ON` line, and the console gains `[Debug] logging enabled` and the `[Init]`
summary; then the diagnostics report is written after them (begin to end marker, as DIAG-5, its
header reading `debug logging: on`) with the one chat line giving its line count, and `[Set]` lines
follow as you change a setting. Click it again → the report appends once more, with no second
`logging enabled` line, and logging stays on. Toggle the label between On and Off
→ the gap after it holds for either word. Drag the console in as far as it goes (DIAG-13) → the link
still fits beside the label and the title. Result:

**DIAG-17. Diagnostics turns logging on for the session.** `/reload` → logging is off (DIAG-2).
`/am diagnostics` → chat prints the `debug logging ON` line, then the report's line-count line; the
console holds `[Debug] logging enabled` and the `[Init]` summary ahead of the begin marker, the header
reads `debug logging: on`, and the console's title-bar label reads Debug On. Change a setting → a `[Set]` line streams. `/reload` → logging is off again. `/am debug
diagnostics` → the same: logging on for the session. `/reload` once more, then `/am debug on` and
`/am diagnostics` → the report appends with no second `logging enabled` line. `/am debug off` →
logging stops, and nothing turns it back on until the next report or `/am debug on`. Result:

**DIAG-18. A slash refusal shows in the console.** `/am debug on`, then bare `/am debug` to open the
console. `/am frobnicate` → chat prints the unknown-command line as before, and the console gains one
line, `[Cmd] refused frobnicate: unknown verb`. `/am disable`, then `/am lock` → chat prints the
disabled line (`Ka0s Aura Master is disabled — enable it with /am enable`), and the console gains one
`[Cmd] refused lock: disabled` line and nothing else for it. `/am set` → one
`[Cmd] refused set: usage`. `/am enable` afterwards. Result:

**DIAG-19. A stand-down edge shows in the console, once.** `/am debug on`, console open. `/am disable`
→ the console gains exactly one `[Lifecycle] stood down: added disabled (holds: disabled)` line, and
no `[State] stood down` line beside it. `/am enable` → exactly one
`[Lifecycle] stood up: released disabled (holds: none)`. Run `/am disable` again while it is already
disabled → no new `[Lifecycle]` line. In combat (a target dummy), `/am disable` → the `[Lifecycle]`
line, then `[State] stand-down: hiding held until combat ends (holds: disabled)`; leave combat →
`[State] stand-down finished after combat: …`. `/am enable`. Result:

**DIAG-20. The launcher's line lands at the first enable, and a Clear re-arms the gates.** `/reload`
→ logging is off. `/am debug on` → just after the `[Init]` summary the console holds one
`[Launcher] registered` line, written at login while logging was off and held until now (this addon
bundles LibDataBroker-1.1 and LibDBIcon-1.0, so neither `absent` line is expected).
`/am debug off`, `/am debug on` → no second `[Launcher]` line. Attach a container to a
frame that does not exist (Layout → Anchor, a made-up name) → one `[Anchor] … screen fallback` line;
change a setting on it → no second one. Press the console's **Clear**, then change the setting again
→ the fallback line is written once more. Result:

## Containers

**CONT-1. New container from the panel.** Containers → **New container** → a player-buff bar
container named *Container N* appears, offset from the last new one, and is selected. Result:

**CONT-2. Duplicate and delete.** **Duplicate** → a *… (copy)* container with every setting, nudged
20 px. **Delete** → a confirmation popup; **Yes** removes it, and any container attached to it falls
back to the screen. Result:

**CONT-3. Create and delete are refused in combat.** The page itself is locked in combat (COMBAT-3),
so these run from chat and from a popup opened before the pull. In combat, `/am new` → the gray
"cannot create a container during combat — it would not be drawn or placed until combat ends" line.
Out of combat click **Delete** and leave the popup up, pull a dummy, then click the popup's **Yes** →
the gray "cannot delete a container during combat — its display cannot be torn down until combat ends"
line; `/am delete` in combat → the same line. Nothing is created or removed. Result:

**CONT-4. Copy settings from.** Containers → General → **Copy settings from** → pick a source and
*Bar style* → the selected container takes only the source's bar look; its name and position are
unchanged. Pick What = *Label* → the label settings copy and the name does not. Result:

**CONT-5. Rename.** Rename a container on Containers → General (Enter to apply) → the handle label,
every picker and `/am containers` show the new name; a blank name is refused. With the container's
name label on (Layout → Label → **Show name label**) and the container selected (`/am select`), in
combat `/am set container.name <a new name>` (the page itself is locked in combat) → the label
changes at once. Result:

**CONT-6. Style switch with auras up.** Locked, with live auras in a container, switch its **Style**
Bars → Icons → Bars → Text → Icons → Text → each time the elements redraw in the new style only: no
cooldown swipe or icon border left over a bar, no bar, bar text or background behind an icon, no
leftover line on a Text container, and bars come back with their fill, name and time text. Watch a
few ticks of each countdown: a stray swipe can appear late, when the engine next updates the
duration. Result:

**CONT-7. Unlock keeps live auras.** `/am unlock` → every container shows its handle, and live auras
keep drawing. A container with nothing to show draws a faint outline one element in size, only while
it is predicted empty (CONT-24). Result:

**CONT-8. The handle.** Unlocked → each handle is a dark strip with a thin gold edge and a gold name
label, sitting outside its container: above it when the auras grow down, below when they grow up,
lined up with the edge the first aura starts from. The first bar or icon is fully visible, not under
the handle. The "?" mark sits at the strip's far end. An empty container's outline is a faint 1px
white box at the corner the flow starts from. Change a container's Width and growth, and move a
container it is attached to → no Lua error (none naming `Backdrop.lua`), and the outline and handle
look the same. Run this after a `/reload` and again after Profiles → Reset Profile. Result:

**CONT-9. The handle's tooltip.** Hover a screen container's strip or its "?" → at the cursor, the
name and "Drag to move. Drop it on another container to attach it there; hold Shift to place it
without attaching. Right-click for settings.", in the usual gold. B (attached to A) and a container
attached to a named frame show their strip name in a desaturated warm gray; hover B's strip or "?" →
the first line reads "Attached to '<A's name>'. Drag it away and let go once the marks turn red to
detach it; let go sooner and it snaps back. Drop it on another container to attach it there; hold
Shift to drop it without attaching. Right-click for settings.", and the
named-frame one's reads "Anchored to '<frame name>', so it cannot be dragged. Right-click for
settings.". With `/am test on`, the named-frame one's tooltip carries the gold line "Attached — set
its offsets in the Layout section." Set B's Attach to back to Screen → the name turns gold at once and
its tooltip says Drag to move; back to Another container → gray again. `/am test` → the orange TEST
tag still follows the gray name. Result:

**CONT-10. The screen edge.** `/am unlock`, drag a container that grows down flush against the top of
the screen, `/am lock`, then `/am unlock` → the container shifts down by the strip and its gap, so the
handle stays on screen; `/am lock` → it returns to the edge. Its stored position is the same before
and after. Result:

**CONT-11. Drag.** Unlocked, drag a screen-attached container by its strip → it moves, and after
`/reload` it stays. A drag that starts on the "?" moves it too. An empty container drags by its
handle. Unlock, enter combat, try to drag → it does not move. Result:

**CONT-12. Right-click opens the Containers page.** Close the panel; right-click a container's
strip, then its "?" → each time the panel opens on Containers with that container in the band's
picker, on the section you last left, not General. In combat, the right-click prints the gray
"cannot open settings during combat — Blizzard's category-switch is protected" line, nothing opens,
and the picker is unchanged afterwards. Result:

**CONT-13. The close mark.** `/am unlock` → every strip shows a gray X immediately left of the "?",
the same size, turning white on hover; the name stays centered and does not run under the X, even for
a long name with the orange TEST tag. Hover the X → the tooltip names the container and says a click
disables it, its settings are kept, and Enabled on the Containers page brings it back. No "Anchoring
disallowed" error, on an attached container too. Result:

**CONT-14. Closing a container.** Left-click the X → that container's auras, placeholders, outline
and strip disappear, nothing else changes, and one chat line names it and says how to bring it back.
Containers → General with it selected → **Enabled** is unticked; tick it → the container and its strip
return at the same stored position. With that page already open on it, click its X → the checkbox
unticks live. Close a container others are attached to → the followers re-place exactly as when
Enabled is unticked in the panel. Result:

**CONT-15. What the close mark does not do.** `/am unlock`, left-drag starting on the X → nothing
moves, and releasing off the X does not disable it. In combat, unlocked, click an X → the container
hides with no Lua error, no taint and no `ADDON_ACTION_BLOCKED`. Result:

**CONT-16. The strip is never wider than its container.** Five one-bar-wide Bars containers with long
names, `/am unlock` and `/am test` → every strip's left and right edges line up with its bars; a name
too long ends in "..." with the orange TEST tag still whole after it, and the X and "?" fully visible.
Hover a shortened strip → the tooltip's title is the whole name. `/am test off` → the name without the
tag, shortened only if it still does not fit. Rename one to a short name → it is drawn whole at once.
A one-icon Icons container with a long name → its strip keeps the width of its name and marks,
running past the icon. No clipped label on a handle's first show. `/am lock` → no strips. Result:

**CONT-17. TEST on the handle.** `/am test`, then `/am unlock` → every handle reads its name, then an
orange **TEST**; end test mode → the tag goes on the next frame and the strip narrows. Result:

**CONT-18. Test mode.** `/am test` → every container fills with placeholder auras and its real auras
are hidden, without unlocking; an empty container's outline gives way to them. General → Master
controls → **Test mode** does the same. `/am test off` → the placeholders go and real auras return.
Start test mode and pull a mob → test mode ends and the checkbox unticks. `/am test` in combat → one
gray line, and nothing starts. Result:

**CONT-19. Each container previews its own kind.** `/am test` on the starter set → *Player debuffs*
and *Target debuffs (mine)* show Shadow Word: Pain, Hex, Frost Fever, Deadly Poison (3 stacks),
Rupture (running out, 4 s) and Mortal Wounds (no timer), each with its real icon and no question-mark
icon. *Player buffs* shows Power Word: Fortitude, Bloodlust, Shield Wall, Ignore Pain and Well Fed.
Result:

**CONT-20. Switching kind while previewing.** In test mode, switch a container's **Aura type**
between Buffs and Debuffs → the placeholders swap without a `/reload`, and a container attached to it
still sits just past the last placeholder (six for debuffs, five for buffs). **Max auras** 3 on a
debuff container → only Shadow Word: Pain, Hex and Frost Fever. Result:

**CONT-21. Weapon enchant placeholders.** A container showing only Weapon enchants (`/am new
enchants`), before applying a real enchant, `/am test` → it previews weapon enchants (Windfury Weapon,
Flametongue Weapon running out, Instant Poison with no timer), not buffs: one placeholder per slot
ticked under General → Spell Categories → *Weapon enchants* (Main hand, Off hand and Ranged, all
ticked by default, so three). Untick **Ranged**, then `/am test off` and `/am test` → two
placeholders; tick it again. A Player buffs container with Weapon enchants also on still previews
buffs. A Text container of enchants under Size to fit sizes to those names. Result:

**CONT-22. Unit swaps.** With a target container, change target several times; with a focus
container, set and clear focus → each shows the new unit's auras at once, never the previous unit's.
Summon and dismiss a pet with a pet container → it follows. Result:

**CONT-23. The filter strings the empty prediction reads.** With a few buffs up, for each category
token a container uses, `/dump C_UnitAuras.GetAuraSlots("player","HELPFUL|BIG_DEFENSIVE",1)` (and the
same with the other tokens, `HELPFUL|PLAYER`, `HARMFUL|PLAYER` on a target) → a slot comes back
exactly when the engine shows a matching aura. A token the client rejects raises; the prediction then
answers not knowable, and that container never shows its placeholder outline. Result:

**CONT-24. The empty outline fills and empties.** #3 with a follower, unlocked, no target → its
outline shows, the follower below it. Target something and apply a DoT → within a moment the outline
hides and the follower sits past the last aura. Let it expire or clear the target → the outline comes
back and the follower returns under it. Result:

**CONT-25. An empty enchant container.** A Weapon enchants container with a follower, unlocked, no
oil → its outline shows. Apply an oil → it hides and the follower sits past the enchant. Let the oil
run out → the outline comes back within a second of it lapsing. Result:

## Filters and spell categories

**FILT-1. Cast by.** Filters → General → **Cast by** → *Me (and my pet)* shows only your auras;
*Anyone but me* the rest. Result:

**FILT-2. The Filters tabs and the priority block.** On a buff container, Filters → **[ General ][
Categories ][ Overrides ][ Sorting ]**, no Spell lists tab on any aura type. **General** ends, past
Cast by, Duration and Max duration, with a **Filter priority logic** heading, the lead-in "Highest
priority first:" and the five numbered rank lines: each rank on its own line, a hairline gap between
them, no word cut off, no horizontal scrollbar. The rank lines read at the same size as the Whitelist
and Blacklist notes on Overrides, and the lead-in is in the normal font's color. Categories and
Overrides carry no lead-in or rank line: Categories opens on its first grid, Overrides on
**Whitelist**. A narrower WoW window → each line still wraps cleanly on its own. Result:

**FILT-3. The category grids.** On a buff container, Filters → **Categories** opens straight onto two
grids, **Blizzard Categories** then **Spell Categories** (its last row **Uncategorized**), each headed
once, with columns **Show · Hide** and the category name (hover it for its description). Click
**Hide** on a line → `/am get container.filter.categories.<key>` prints `Hide`. Right under the grid
sits **Hide enchants without a duration**, tied by name to the **Weapon enchants** row above it.
Result:

**FILT-4. A debuff container's Categories.** Switch the container's aura type to Debuffs → four
grids, **Blizzard Categories**, **Spell Categories**, **Dispel Types** and **Who Cast It**. Above the
Spell Categories grid the line reads "These are the lists on General -> Spell Categories, shared by
every container."; the grid holds **Hard CC (loss of control)**, **Soft CC (roots & snares)** and
**Racials**, each with a **See spells** link, then **Uncategorized** with none (plus any debuff
category of your own); under it a note reads "Hard CC, Soft CC and Racials only match on a target or
focus you can't assist. …". On a *player* container, straight under the **Spell Categories** heading and above its
**Show all** / **Hide all**, a line reads "NOTE: on your own debuffs, these spell categories are not
applied." Result:

**FILT-5. The grid cells.** Look at a lit cell (Show or Hide) → an ordinary checkbox check, the same
shape and color as every other checkbox in the panel, no colored fill. Click the other cell on the
row → the check moves there in full; at no point are both or neither lit. A row set to Show → its
Hide cell looks exactly as clickable as any unlit checkbox, not grayed or lower in contrast. Set
**Uncategorized** to **Hide** → every other row's Hide column still looks the same and still clicks,
live. Result:

**FILT-6. Show and Hide by category.** On a buff container set *Group buffs* to **Hide**, every other
category (Uncategorized included) at Show → Mark of the Wild, Arcane Intellect or Battle Shout
disappears from it, nothing else changes. Set *Defensive cooldowns* to **Hide** on a defensive that
is also in *Cancelable* (left at Show) → it still shows (rank 3: a Show elsewhere rescues it). Set
every category to **Hide**, Uncategorized included, with the whitelist empty → the container goes
empty and shows "These filters can never match anything."; set *Defensive cooldowns* back to Show →
only defensive cooldowns appear. Set every category back to Show except *Uncategorized* → a
cancelable buff in none of the profile's Spell Categories lists disappears too. Result:

**FILT-7. Many groups, nothing lost.** On a *player debuffs* container, set one debuff category (say
*Dispellable by anyone*) to **Hide** and leave the rest at **Show** → the container compiles to one
group per Show category plus a catch-all, not one. Apply enough different debuffs to populate several
categories → every one you expect appears: a debuff only in *Dispellable by anyone* disappears, one
in *Dispellable by anyone* and *Boss debuffs* still shows (rank 3); nothing missing, garbled or
duplicated. `/am perf` a few seconds with the container populated, then again with every category at Show → report if the
many-group container is far slower per apply, or if a group's auras never draw though its category
has live spells (the client capping `AddAuraGroup` calls). Set Sort by to Time Remaining → auras are
ordered category block by category block, each block sorted, not one run across the container, as
the Sorting row's description says. Result:

**FILT-8. Who Cast It covers every debuff.** On a debuff container set both *From any player* and
*From non-players* to **Hide**. Apply a debuff to the dummy → it disappears. Have a pet, an NPC or
another player apply a different debuff to you or the dummy → it disappears too. Any debuff that still shows
with both Hidden reports its `isFromPlayerOrPlayerPet` as neither true nor false: report it, with the
spell. Result:

**FILT-9. Show all and Hide all.** Filters → Categories on a buff container → **Show all** and **Hide
all** under each grid's heading. Hide all on Spell Categories → every row reads Hide, and the
container empties at once, in one pass with no flicker per row. On Player debuffs → the Dispel Types
and Who Cast It headings each have the pair too; hover one → "Set every category in this section to
Show (Hide), for this container.". Hide all under Dispel Types → only its rows read Hide; Hide all
under Who Cast It → only its two rows; Show all on each → back. #3's rows were never touched. A buff
container shows only its two pairs. Result:

**FILT-10. See spells lands on its own category.** Filters → Categories → Spell Categories, click
**See spells** on a row that is not the first (*Support* or *Utility*) → General → Spell Categories
opens with that category selected in the **Category** dropdown. From a different category on a
different container (*Racials*) → it lands on Racials. **See spells** on the **Weapon enchants** row →
Weapon enchants selected, showing the three slot toggles. Result:

**FILT-11. The Spell Categories tab.** General → **Spell Categories** → the **Category** dropdown
with **Restore this category's starter list** on the dropdown's line, right half. On a category of yours,
the rename box and **Delete** sit directly under the picker, with no heading between them, then
**Make a new category**, then **Spells in this category** with the library's rule under it, then the
**Add a spell** box and the list; each block is separated by the gap under it. Pick **Healing** → no
name box, no Delete, no heading and no sentence between the picker and **Make a new category**.
Pick **Weapon enchants** → the lead-in says it matches temporary enchants and there is nothing to
add or remove, a **Weapon slots** heading sits over the three slot toggles, and no "Spells in this
category" heading. Result:

**FILT-12. Starter lists.** Every spell row carries an X on its left and no checkbox; check the X's
height and vertical alignment against the name (the library's Icon widget is 26 px tall). Remove a
starter spell from *Defensive cooldowns* with its X, cast it → it no longer shows in any container
showing Defensive cooldowns. Type a spell of yours by name into **Add a spell** → it is listed with
its icon; cast it → it shows in a container showing Defensive cooldowns. **Restore this category's
starter list** → back to shipped. Filters → Overrides lists carry the X too, and it removes the
spell. Result:

**FILT-13. Lists read alphabetically.** The **Category** dropdown offers **Defensive cooldowns**,
**Hard CC (loss of control)** and **Soft CC (roots & snares)**, the parentheses and `&` as written in
the dropdown, its tooltip and on Filters → Categories. Pick **Soft CC (roots & snares)** → the spells
read in name order (Chains of Ice, Concussive Shot, Crippling Poison, …), not Frost Nova first. Add a
spell of yours by name → it lands in the alphabet among the starters. An id the client cannot name
reads "Unknown spell <id>" at the end, and the order does not shuffle a second after the tab opens.
**Wake of Ashes** is in neither Hard CC nor Soft CC; cast it with a Hard CC container up → nothing is
drawn for it. Result:

**FILT-14. The add box takes a link.** Click into **Add a spell** and shift-click a spell in your
spellbook → its link lands in the box; Enter → the spell is added with its icon and name. The same on
Filters → Overrides → Whitelist. If the shift-click goes to the chat box instead, report it. Result:

**FILT-15. Suggestions while typing.** Type `rej` into **Add a spell** → a dropdown under the box
lists Rejuvenation with its icon and id, plus any matching spell in your spellbook, a ranked spell
showing its rank ("Rank 2"). Down, then Enter → that spell is added once and the dropdown closes;
type again and click a row → the same. A spell you know that is on no list of this addon is suggested
too. The same on Filters → Overrides → Whitelist. Result:

**FILT-16. A name the lists know resolves without the spellbook.** Type the full name of a category
starter your character does not have (*Ironbark* on a non-druid), Enter → it is added. Add a spell by
id to Filters → Overrides → Blacklist, then type its name on General → Spell Categories → it resolves
too. Result:

**FILT-17. A shared name is refused until picked.** Add two spells sharing a name by id to the
Overrides Whitelist (the *Blood Fury* racials 20572 and 33697), then on General → Spell Categories
type `Blood Fury` and Enter without picking → nothing is added, the line under the box reads "Several
spells are named 'Blood Fury' — pick one from the list, or use the id.", and the dropdown lists each.
Pick one → only it is added. Result:

**FILT-18. An unknown name.** Type `Zzz Spell`, Enter → nothing is added, and the line under the box
reads "No spell named 'Zzz Spell' in your spellbook. Names work for spells in your spellbook and ones
this list knows; otherwise use the id or shift-click a link." The same in the Whitelist's **Add a
spell** box on Filters → Overrides. Result:

**FILT-19. The add box's tooltip.** Hover **Add a spell** → the tooltip says "The id has to be the one
the AURA carries, which is not always the one you cast." before the sentence on where a name can come
from, which ends with the same hint as FILT-18 and promises nothing about names the game cannot find.
Result:

**FILT-20. A cast id swapped for its aura.** Aura Master filters on the id an aura carries, and many
spells are cast as one id and land as another (`defaults/CastToAura.lua` carries the mapping). Add
**Corruption** by name or as `172` → the entry appears as **146739**, and chat says "Corruption (172) is
cast, but the aura it applies is … — added 146739 instead, which is what the filter can match." The
swap is never silent. Result:

**FILT-21. A cast id with several auras.** Add **Renewing Mist**, or `115151` → it is stored exactly
as typed, and chat lists the candidates: "Renewing Mist (115151) never appears as an aura, so this
entry will match nothing. Auras with that name: … Add the one you meant.", the list giving 119611,
144080, 448430, 1238851 and 1242480, each as its name then its id in brackets. It does not pick one.
Add `119611` → it goes in silently; remove 115151. Result:

**FILT-22. An unknown id is never refused.** Add `999999` → it is added, with nothing said. Result:

**FILT-23. The note on a stored entry.** With 115151 still in a list, reopen the panel → its row
carries a gray second line naming the candidate auras, on a full-width row of its own (the library's
rule for notes). Result:

**FILT-24. The Overrides lists take the same path.** Filters → Overrides → add `115151` to the
whitelist → the same chat line as FILT-21. If the id also has a verdict note, the two are joined, the
never-matches sentence first. Result:

**FILT-25. The corrected shipped ids.** Each now matches: **Levitate** on yourself → a container
covering *Utility* shows it (111759); **Fear** on the dummy → a *Hard CC* debuff container shows it
(118699); **Spirit Link Totem**, standing in it → the container covering it shows it (325174);
**Ursol's Vortex**, dummy inside it → a *Soft CC* container shows it (127797). `35546` Fatal Flourish
is knowingly still the cast id and matches nothing; if you ever see a lasting Fatal Flourish debuff,
note its id. Result:

**FILT-26. Overrides.** Add a buff to the **Blacklist** → gone. Add a buff by name to the
**Whitelist** on a container whose categories exclude it → it is listed with its icon and id, and it
shows. Add the same id to both lists → the Blacklist entry stays but the aura shows anyway, with a
gray note under the Blacklist entry saying so; remove it from the Whitelist only → the note goes and
the aura is hidden again. Whitelist a spell every category of the container sets to Hide → a gray
note under that entry names the category (or categories) it overrides. Result:

**FILT-27. A long note wraps under its entry.** Whitelist a spell whose categories are all Hidden on
a container where the note names several ("Shown here by the whitelist, overriding Defensive
cooldowns, Cancelable (set to Hide).") → the note wraps under the entry's name and id in gray,
overlapping neither the icon, the id nor **Remove**, and never pushing onto the next entry. Result:

**FILT-28. Max duration.** **Max duration** `60` → hour-long buffs disappear, short ones stay,
permanent ones go. Result:

**FILT-29. Only auras without a duration.** **Duration → Only auras without a duration** on a player
buff container → timed buffs disappear out of combat once learned; a brand-new timed buff cast in
combat may show once. `/am forgettimed` → they reappear until relearned out of combat. Result:

**FILT-30. Warnings.** Whitelist a spell on a *player debuffs* container that hides no category →
Filters shows the orange "On your own and your pet's debuffs, the Overrides lists are not applied."
line; set any category to **Hide** → it becomes "On your own and your pet's debuffs, spell categories
and Overrides are not applied. The Situations tab picks what draws there." On a *target buffs*
container → "On units you can't assist (hostile or neutral), ...". Set every category to **Hide** but *Defensive cooldowns*, then on
General → Spell Categories remove every *Defensive cooldowns* spell → "These filters can never match
anything."; Restore afterward. Result:

**FILT-31. Make a category.** FILT-31 to FILT-39 run in order, on a player-buff bar container and a
target-debuff container. General → **Spell Categories** → under **Make a new category**, type
`Cooldowns I watch`, leave **Aura type** on *Buffs*, click **Create category** → the dropdown jumps to
**[Buffs] Cooldowns I watch (yours)**, `[Buffs]` in muted green and `(yours)` in muted gold; a line
under the rename box and in chat says it was created, empty, and where to set it to Show or Hide. The
list is empty, and there is no Restore button on the picker's line. Result:

**FILT-32. It is a real category everywhere.** Filters → Categories on the buff container → the Spell
Categories grid holds **Cooldowns I watch (yours)** with **Hide** lit (a new category starts hidden
in every container that already existed), after the shipped lists and above **Weapon enchants** and
**Uncategorized** (still last). `/am list` shows the row (no `(yours)`), and
`/am get container.filter.categories.user…` answers **Hide**. The debuff container's grid has no such
row. Make a new player-buff container → its grid shows the category with **Show** lit; delete it
again. Result:

**FILT-33. It filters.** Add a buff you can cast on yourself to it. On the buff container Hide every
other category (Hide all on both grids, then this one back to Show) → cast the buff → it is drawn,
and your other buffs are not. Set the category to **Hide**, Uncategorized still Hidden → the buff
goes. Result:

**FILT-34. The overlap mark.** Add a spell already in a shipped buff category (Power Word: Shield,
in *Defensive cooldowns*) → one chat line naming the other category and saying an aura in two
categories is drawn once, under the first of them a container sets to Show. The entry reads `(X)
[icon] Power Word: Shield (17) (also in 1)`, the count in the id's gray on the entry's own line, its
neighbor still sharing the row. Hover it → the spell tooltip, with **Also in: Defensive cooldowns**
added. In *Defensive cooldowns* the same spell reads `(also in 1)`, its tooltip **Also in: Cooldowns I
watch (yours)**. On a very long name at a narrow panel the `(also in N)` is cut off first; the
tooltip still names the categories, and a wider window brings it back. Result:

**FILT-35. Rename it.** Type `Big cooldowns` in **Rename this category**, Enter → the dropdown, the
box, the Filters grid and `/am list` read the new name; the box shows what is stored; the answer line
says it was renamed and names the old name. The spells are still there, and the grid's Show or Hide is
unchanged. Result:

**FILT-36. The answer line knows what it is about.** With a line under the rename box, switch the
dropdown to another category → the line is gone. Make it say something again, close and reopen the
settings on the same tab → gone. Again, then Profiles → switch profile → come back → gone. Hopping to
General → Display and back keeps it. Result:

**FILT-37. An empty or duplicate name.** Clear the rename box, Enter → a line saying a category needs
a name, and the box snaps back to the stored name. Create a second category with a name you already
used → both are kept, the line says so, and the dropdown shows two entries reading the same. Result:

**FILT-38. Delete it.** Pick the second category, **Delete this category** → the confirmation names it
and says the spell list goes, every container in every profile forgets whether it showed or hid it,
and anything it hid becomes visible again through Uncategorized. **No** → nothing changes. **Yes** →
the tab shows another category, a line says which was deleted and that the tab moved, the Filters
grid no longer holds the row, and `/am get` on its old path answers that the setting is unknown.
Result:

**FILT-39. A deleted category stops filtering.** Set the first category to **Show** on the buff
container with every other category Hidden, and confirm its buff is drawn. Delete it → the container
redraws: the aura comes back only through **Uncategorized** if that is Show. `/reload` → it stays
gone from the dropdown and the grid. Result:

**FILT-40. Weapon enchants on a buff container.** Apply a temporary weapon enchant (an oil, a stone,
a poison) → *Player buffs* shows it after the buffs, its **Weapon enchants** row on Filters →
Categories being Show by default. Set that row to **Hide** → the enchant drops out; **Show** → it
returns. **Hide enchants without a duration** hides a permanent one. Result:

**FILT-41. `/am new enchants`.** `/am new enchants` → a player buff container named *Container N*
whose Filters → Categories are all Hide but **Weapon enchants**: it shows your enchants and no buff.
`/am new enchants text` → the same as Text, showing the enchant's name and time. Result:

**FILT-42. The weapon's name after a fresh login.** Apply a temporary weapon enchant (an oil, a stone,
a poison) so *Player buffs* shows it. Exit the game completely and log back in (not `/reload`) → within
about two seconds of the loading screen ending, the enchant bar shows the weapon's name, not only its
icon and time. Then `/am debug on` and take a loading screen (a hearthstone, a portal or a dungeon
entrance) → the console shows `[Apply] enchants reset on N container(s) after the loading screen`, N
counting the shown containers with an enchant on, and the name is still there. If a name is ever
blank, run `/dump C_Item.GetItemName(ItemLocation:CreateFromEquipmentSlot(16))` and note what it
prints on this line. Result:

**FILT-43. The help marks draw the library's info art.** On the buff container, blacklist a spell that
a Show category holds, so Filters → **Overrides** marks it; and on General → **Spell Categories** add
to your own category a spell a shipped category already holds, so the list marks it. Each mark is the
white `info` glyph tinted by its level (gold, amber or red), not Blizzard's blue information disc, and
no mark is a green or empty square. Result:

**FILT-44. Hovering a help mark.** Hover one of those marks → it brightens, and the tooltip lists the
help lines. Move off it → it returns to its own level's color, not to gold. Result:

**FILT-45. No help-art complaint in the console.** `/am debug on`, then open Filters → Overrides and
General → Spell Categories with those marks drawn → the console shows no `[Cfg] help art:` line.
Result:

FILT-46 to FILT-52 check the spell-list views (2026-10-02). Blizzard applies spell ids to buffs on a
unit you can assist and to debuffs on a unit you cannot. Elsewhere a container that sets any category
to Hide draws only the categories set to Show on its Blizzard Categories, Dispel Types and Who Cast It
grids, each aura once. Turn logging on (`/am debug on`) for the checks that read `[Filter]` lines.
Since filter situations (S2), that is the blizzard view, which a container draws there only with its
Situations settings at "Only my Blizzard categories set to Show"; FILT-46 to FILT-52 assume both
settings (NPCs and players) at that value, on every container they use.

**FILT-46. The Mythic+ repro: one bar per aura.** Make a *target buffs* bar container: every Blizzard
category **Hide**, at least five Spell Categories **Show** (Defensive cooldowns, Offensive cooldowns,
Healing, Support, Utility and so on), **Uncategorized** **Hide**, **Max duration** `30`. In a Mythic+
key or a dungeon, target an enemy NPC that carries a short buff (the report was *Brutal Slams*,
stacked twice) → no bar is drawn more than once, and on this container nothing draws at all, since
no Blizzard category is set to Show. The console shows `[Filter] <name>: spell lists off, only
Blizzard categories set to Show (NPC; unit cannot be assisted)` when you target it. Set *Important (Blizzard)* to **Show** → the NPC's important buffs
each draw once, and nothing else does. Result:

**FILT-47. A hostile player.** In War Mode or a battleground, use a *target buffs* container with
*Defensive cooldowns* **Show**, *Cancelable* **Hide** and *Big defensives (Blizzard)* **Show**. Target
an enemy player who pops a big defensive → it draws once, from *Big defensives (Blizzard)*; a buff
only in *Defensive cooldowns* does not draw; no buff draws twice. `/am diagnostics` → the container's
line reads `spell lists: mode=dynamic view=blizzard situation=players`. Result:

**FILT-48. A friendly target.** Same container, target a friendly player or a party member → the
container filters exactly as set: *Defensive cooldowns* buffs draw, *Cancelable* ones the other
categories do not claim stay hidden, nothing draws twice. Switching from the FILT-47 target logs
`[Filter] <name>: spell lists on (unit can be assisted)`, and `/am diagnostics` reads `view=ids situation=-`.
Result:

**FILT-49. A duel flips the view without a retarget.** Target a friendly player and keep them
targeted. Start a duel → when it begins, the console logs `spell lists off, only Blizzard categories
set to Show (player; unit cannot be assisted)` for each target buff container and `spell lists on (unit cannot be assisted)` for *Target debuffs
(mine)*, with no target change and no Lua error, in combat too; each container redraws on its own.
When the duel ends the lines flip back. Nothing draws twice at any point. Result:

**FILT-50. A player debuff container with several spell categories.** On *Player debuffs* set
*Hard CC*, *Soft CC* and *Racials* to **Show**, *Dispellable by anyone* to **Hide**, and every other
category to **Show**. Take a stun or root from a dungeon mob or a training partner → each debuff
draws once, from the Blizzard Categories, Dispel Types or Who Cast It rows set to Show; the three
spell categories add nothing and duplicate nothing. Set every Blizzard Categories, Dispel Types and
Who Cast It row to **Hide** → the container stays empty whatever you take, since spell ids never apply
to your own debuffs. Result:

**FILT-51. The notes.** Filters → **Categories** → straight under the **Spell Categories** heading:
*Player buffs* → no NOTE; *Player debuffs* → "NOTE: on your own debuffs, these spell categories are
not applied (see Situations)."; *Target debuffs (mine)* → "NOTE: on units you can assist, …"; a
*target buffs* container → "NOTE: on units you can't assist, …"; a *pet debuffs* container → "NOTE:
on your pet's debuffs, …". The **Overrides** tab opens with the same sentence ending "these Overrides
are not applied (see Situations)." on each of those, above **Whitelist**, and with none on *Player
buffs*. The orange warning
above every tab prints only on a container that sets a category to Hide or has an Overrides entry,
and on one that hides nothing it names only the Overrides lists (no "The Situations tab picks what
draws there.").
The README's Usage paragraph on where spell categories apply and the FAQ entry "Why don't my
target's buffs show on enemies?" read the same as these notes. Result:

**FILT-52. Mind control flips the view on the charmer.** On a raid or dungeon boss that mind-controls
(charms) a player, keep a *Target debuffs (mine)* container with *Hard CC*, *Soft CC* and *Racials*
**Show** and *Dispellable by anyone* **Hide**, targeting the boss. When you are charmed, the console
logs `spell lists off, only Blizzard categories set to Show (NPC; unit can be assisted)` for that container if the charm made the boss
assistable, with no target change and no Lua error; nothing draws twice while charmed. When the charm
ends the line flips back to `spell lists on (unit cannot be assisted)`. Result:

FILT-53 to FILT-59 check the Situations tab (filter situations, 2026-10-02), the last tab of
Filters: what a container draws where spell lists don't apply (**Every aura, once**, the default, or
**Only my Blizzard categories set to Show**), and the kinds of zone it shows in. Unlike FILT-46 to
FILT-52, these start from the defaults unless a step says otherwise.

**FILT-53. Mythic+ NPC buffs come back, once each.** Use the FILT-46 container as FILT-46 leaves
it (*Important (Blizzard)* **Show**, every other Blizzard category **Hide**, five or more Spell
Categories **Show**, **Uncategorized** **Hide**, **Max duration** `30`) with Filters → **Situations**
→ **On NPCs** at **Every aura, once**. In a Mythic+ key or a dungeon, target an enemy NPC carrying
short buffs (the report was *Brutal Slams*) → each buff of 30 seconds or less in no Blizzard
category set to Hide draws exactly once, none twice (an Important one included); a cancelable or
purgeable one stays hidden even when it is Important (in the every view a Show does not rescue a
Hide), and a buff over 30 seconds does not draw. The console shows
`[Filter] <name>: spell lists off, every aura (NPC; unit cannot be assisted)`, and `/am diagnostics`
reads `view=every situation=npcs`. Set *Important (Blizzard)* from **Show** to **Hide** → the NPC's
important buffs stop drawing and the rest still draw once. Result: pass (owner, 2026-10-02)

**FILT-54. A hostile player with Players at Only Blizzard.** Use the FILT-47 container with **On
NPCs** at **Every aura, once** and **On players** at **Only my Blizzard categories set to Show**. In
War Mode or a battleground, target an enemy player who pops a big defensive → it draws once, from
*Big defensives (Blizzard)* (or another Blizzard category set to Show: a purgeable or *Important*
buff draws too); a buff only in *Defensive cooldowns* or in no Blizzard category does not draw; no
buff draws twice; `/am diagnostics` reads `view=blizzard situation=players`. Target an enemy NPC next → its buffs that are in no Blizzard category set to
Hide (Cancelable here) draw, once each (`view=every situation=npcs`). Result: pass (owner, 2026-10-02)

**FILT-55. A friendly target is unchanged.** Same container, target a friendly player or a party
member → it filters exactly as before filter situations: the Spell Categories set to Show draw,
*Cancelable* buffs no other category claims stay hidden, nothing draws twice, and `/am diagnostics`
reads `view=ids situation=-` whatever the two dropdowns say. Result: pass (owner, 2026-10-02)

**FILT-56. Switching a dropdown in combat.** Select the FILT-53 container in the panel, target an
enemy NPC and enter combat. The panel is locked in combat, so switch **On NPCs** with `/am set
container.filter.situations.npcs blizzard` → the NPC's buffs disappear at once, not after combat,
with no Lua error, and the console logs one `[Filter]` line naming the blizzard view. `/am set
container.filter.situations.npcs every` → they return at once. Result: pass (owner, 2026-10-02)

**FILT-57. Each zone checkbox.** On a locked container, untick one box at a time under Filters →
**Situations** → **Show in** and visit that kind of place: Open world, a dungeon (Dungeons), a delve
or scenario (Scenarios and delves), a raid (Raids), a battleground (Battlegrounds), an arena
(Arenas) → the container is hidden there and shows again after you leave for a ticked kind of
place, with no `/reload`. Unlock it inside the unticked kind of place → it shows so you can move it;
lock it → it hides again. Tick the box back → it shows at once. Note what a delve reports (it should
be Scenarios and delves). Result: pass (owner, 2026-10-02)

**FILT-58. A /reload inside a dungeon.** Untick **Dungeons** on a locked container, enter a
dungeon, then `/reload` inside it → after the reload the container is hidden from the first frame,
not drawn and then hidden. Leave the dungeon → it shows. Result: pass (owner, 2026-10-02)

**FILT-59. The tab and its rows.** Filters on any buff or debuff container → the tabs read General,
Categories, Overrides, Sorting, Situations, with Situations last, and on every tab a clear gap
separates the orange warning lines from the first section. A *target buffs* container → under
**Unit type** (the first section), **Where spell lists don't apply** opens with "On units you can't assist, spell lists don't apply to
this container.", then **On NPCs** and **On players**, then the line "Every aura still honors Cast
by, Duration, Max duration and the Blizzard, Dispel and Who Cast It rows you set to Hide; …"; set
its **Duration** to *Only auras without a duration* → a further line "Every aura draws nothing extra here: 'Without
a duration' is built from spell lists." *Target debuffs (mine)* → "On units you can assist, …" and
the same two dropdowns. *Player debuffs* → "On your own debuffs, …" and one dropdown, **Your own and
your pet's debuffs**, whose tooltip names your own or your pet's debuffs (not "what a player
shows"). *Player buffs* → "Spell lists always apply to your own and your pet's buffs."
and no dropdown. Each then shows **Show in** and its six checkboxes, all ticked. Result: pass (owner, 2026-10-02)

FILT-60 to FILT-63 check the Situations tab's first section, **Unit type** (filter situations S6,
2026-10-02): which units a target or focus container shows for, by kind (NPCs or Players) and by
reaction to you (Friendly, Neutral or Hostile). They start from the defaults (All / All) unless a step
says otherwise.

**FILT-60. The section.** Filters → **Situations** on *Target debuffs (mine)* → at the top, above
**Where spell lists don't apply**, a section **Unit type** with two dropdowns, **Unit type** (All, NPCs, Players) and **Reaction**
(All, Friendly, Neutral, Hostile), both at All. Each tooltip says an unlocked container, or one in
test mode, still shows. On *Player buffs* and *Player debuffs*, and on a container switched to your
pet, the section shows "Always your own character or pet." and no dropdown. Result: pass (owner, 2026-10-02)

**FILT-61. Hostile NPCs only.** On a locked target container set **Unit type** NPCs and **Reaction**
Hostile. Target an enemy mob → its auras draw. Target a friendly player, a party member, a friendly
NPC and a neutral (yellow) mob in turn → the container shows nothing each time, label included, and
comes back on the next enemy mob, with no `/reload` and no Lua error. Repeat the swaps in combat
→ the same, at once. With no target → nothing to draw, no error. Unlock the container while
targeting a friendly player → it shows so you can move it; lock it → it hides again. Set both
dropdowns back to All → it shows on every target at once. Result: pass (owner, 2026-10-02)

**FILT-62. A reaction change without a swap.** On a locked target container set **Reaction**
Hostile, target a friendly player and start a duel with them → the container shows when the duel
starts (they turn hostile) and hides when it ends, with no target change. Set **Unit type** Players
and **Reaction** All instead, and with a party member targeted switch **Unit type** with `/am set
container.filter.unitFilter.kind npc` in combat → the container hides at once, not after combat;
`/am set container.filter.unitFilter.kind all` → it shows again. Result: pass (owner, 2026-10-02)

**FILT-63. Focus, and the copy.** Make a focus buffs container with **Unit type** Players and
**Reaction** Friendly. Focus a party member → it draws; focus an enemy mob → it hides, while a target
container set to All keeps drawing your target. Containers → **Copy settings from** that focus
container, section **Filters**, onto another target container → its **Unit type** section reads
Players / Friendly. Result: pass (owner, 2026-10-02)

## Layout

**LAYOUT-1. Tabs, and Anchor drawn by mode.** Layout → **[ Frame ][ Anchor ][ Growth ][ Mouse ][ Label
]**. Anchor reads **Attach to**, then only the subsections that mode uses, with no Attach to the
screen button. *Screen* → only **Screen** under it, no empty headings; *Named frame* → **Named frame**
(Frame name with **Pick a frame…** beside it) and **Offset**; *Another container* → **Another
container** and **Offset**. Each redraws at once. With the page open, `/am set container.attach.mode
screen` → it redraws to Screen alone; `/am get container.attach.x` still answers while Offset is
hidden. Result:

**LAYOUT-2. Growth flips without a reload.** Out of combat and out of test mode: on a screen bar
container, Layout → Growth → Grow vertically Down → Up → the bars stack up from where the first one
sat, nothing hangs below it, and the handle (`/am unlock`) moves below the block; back to Down → they
stack down again. On an icons container, Grow horizontally Right → Left and back → likewise,
sideways. On a container attached to `PlayerFrame`, the same two flips → the first aura keeps its
attached corner and the others grow the new way. A follower's flip is LAYOUT-17. Every flip shows
real auras at once. Result:

**LAYOUT-3. The Point rows and the facing-growth hint.** On a container attached to `PlayerFrame`
(Named frame): This container anchor point's tooltip says it is the corner of the container's first
aura that is attached (its full size is secret), the Named frame anchor point the frame's corner. Set
This container Bottom left, Grow vertically Down, Grow horizontally Right → a hint under the rows
reads "Point is Bottom left and Grow vertically is Down, so the auras grow back over the frame this
container is attached to. Set Grow vertically to Up on the Growth tab instead." Top left with Up →
the same hint suggesting Down; a Left point with Grow horizontally Left (a Right point with Right) →
the horizontal hint; Bottom left with Down and Left → both lines, the vertical first. A pair that does
not face → no hint, and a change to the point or the growth redraws it at once. Screen and Another
container show no hint; the Screen rows' tooltips speak of the first aura too. Result:

**LAYOUT-4. Attach to another container.** Layout → Anchor → Attach to → *Another container*, pick one
→ it follows that container as it grows and shrinks. Attach A to B, then B to A → the second is
refused. Result:

**LAYOUT-5. The growth-conflict popup.** Set B to grow Up and A to grow Down, then B → Another
container → pick A → a popup names B, A and the changed growth. **Cancel** → the dropdown shows None
and nothing moves. Pick A again → **Attach** → B attaches and grows down; its Growth tab shows the
dimmed inherited values, and A's Growth tab says one container follows it. With another container
attached to B, the popup adds that it follows too. Attach to → Screen → B grows up again and one chat
line says so. `/am set container.attach.container <A's id>` on a container of differing growth in
container mode → no popup, one chat line. Open the popup, enter combat, press **Attach** → refused
with a gray line and nothing attaches. Result:

**LAYOUT-6. The frame picker.** **Pick a frame…** → the settings close, and a blue 2px outline tracks
the named frame under the cursor, its name beside it; move across several frames, aura buttons
included → the outline follows each, no Lua error. Left-click your player frame → the container
attaches to it and the settings reopen on Containers → Layout with the frame name filled in. Repeat
and press **Escape** → canceled, and the settings reopen on Containers → Layout. `/am pick` does the
same from chat. In combat, `/am pick` is refused with the gray "cannot pick a frame during combat —
attaching to a frame waits until combat ends" line (the button is under the combat cover, COMBAT-3).
Result:

**LAYOUT-7. A frame that is not there yet.** Attach to a frame name belonging to an addon that loads
on demand → the container sits at its screen position until that addon loads, then moves. Attach to
back to *Screen* → it detaches. Result:

**LAYOUT-8. A named frame's two anchor points.** Attach to *Named frame* → below Frame name one line
reads **Named frame anchor point** on the left and **This container anchor point** on the right, each
holding its own corner: a container set on an older build to Bottom left / Top left (container /
frame) reads Top left on the left and Bottom left on the right. Pick a corner in each → the container
moves at once. The Screen section still reads Point / Relative point. Result:

**LAYOUT-9. The two anchor-point rows.** On the chain, select B, Layout → Anchor → below **Parent
container** sit **Parent container anchor point** and **This container anchor point**, and no
**Side** row. Open each → the first entry reads "Automatic (<point>)", naming the point Automatic
gives, then the nine points: Top left, Top, Top right, Left, Center, Right, Bottom left, Bottom,
Bottom right. Pick one in each → B moves at once, and the line beside Parent container reads "Its
<this point> joins the <parent point> of '<A's name>'". A pair that looks odd (Bottom right to Top
left) is stored and drawn as asked: no refusal, no grayed entry, no note. With a pick in one row, open
it again → its Automatic entry still names Automatic's own point. Automatic in both → B returns to its
default place. Result:

**LAYOUT-10. Text under Text.** On the chain, both rows Automatic → each follower sits one Spacing
below its parent, centered under it, the rows reading "Automatic (Bottom)" (parent) and "Automatic
(Top)" (this). Set B's Justify to Left → it lines up on A's left (Bottom left / Top left); Right → on
its right. Change A's Width and toggle Size to fit → the centered ones stay centered. Put Justify back
to Center. Result:

**LAYOUT-11. Icons under Icons.** An Icons parent A filling rows growing right and down, an Icons
child B, both rows Automatic → B sits below A, its first icon under A's first icon, left edges
aligned: "Automatic (Bottom left)" and "Automatic (Top left)", and the line reads "Its Top left joins
the Bottom left of 'A'". Give A a **Per row** that wraps it → B sits below A's last line. Set A's Grow
horizontally to Left → B mirrors to A's right end ("Automatic (Bottom right)" / "Automatic (Top
right)"), with no `/reload`; back to Right → it returns. Result:

**LAYOUT-12. Bars under a centered Text, and growth up.** A Bars child attached to a Text parent
justified Center, both rows Automatic → the bars are centered under the text ("Automatic (Bottom)" /
"Automatic (Top)"). Parent Justify Left → the bars start on the parent's left; put Center back. Set
the parent's Grow vertically to Up → the bars sit centered above the text, the rows reading
"Automatic (Top)" (parent) and "Automatic (Bottom)" (this), and the strips and labels mirror as in
LAYOUT-22. Set it back to Down. Result:

**LAYOUT-13. An odd pair.** On B pick This container Center and Parent container Top right → B's
first element is centered on A's top right corner, plus its X/Y offsets and no Spacing gap.
`/am unlock` → the chain does not spread for B: nothing moves to make room, B is not pushed clear of
A's strip or label, and B's strip and label sit on B's own before side, where they may overlap A.
`/am lock` → B does not move. C, on Automatic below B, follows B. Put both rows back to Automatic.
Result:

**LAYOUT-14. A picked pair that is a side.** On B pick This container Top and Parent container Bottom
→ it behaves as the Automatic Bottom: one Spacing below A, centered; unlocked, the chain spreads for
B's strip and label, and closes up on lock (LAYOUT-19, LAYOUT-21). On an Icons follower with its
parent's label on, pick This container Top left and Parent container Top right → it is pushed clear
of the parent's label as in LAYOUT-23. Result:

**LAYOUT-15. The points from chat.** `/am select` B, then `/am set container.attach.relPoint
bottomright` → accepted in lower case, B moves, and the Parent container anchor point row reads
Bottom right. `/am set container.attach.childPoint Top` → accepted; `/am get
container.attach.childPoint` reads `TOP`. `/am set container.attach.childPoint auto` and `/am set
container.attach.relPoint AUTO` → both Automatic, `/am get` on either reads `auto`. `/am set
container.attach.childPoint middle` → an `Invalid value` line, and nothing moves. `/am set
container.attach.edge after-end` → "Setting not found: container.attach.edge". `/am reset
container.attach.relPoint` after a pick → back to Automatic. Result:

**LAYOUT-16. No join mark, and the join in the tooltip.** On the chain and the pairs of LAYOUT-11 and
LAYOUT-13: `/am unlock` → no dot, diamond or other mark on any join; `/am test` → none; `/am lock` with
test mode on → none. Hover B's strip while unlocked → the tooltip adds "Joined to the <point> of
'<A's name>'. Change the anchor points on Layout > Anchor." A container on the screen or a named frame
adds no such line. `/am test off`. Result:

**LAYOUT-17. The inherited flow.** Attach B to A where A fills columns growing down → B continues
below A's last element. Set A's Grow vertically to Up → B moves above A, none of B's own settings
changed, and without a reload B's own auras stack up from its first element too. B's Growth tab →
above the dimmed Fill, Grow horizontally and Grow vertically rows, which show A's values, it reads
"Fill and growth follow '<A's name>' because this container is attached to it." in dim gold (the gold
of "(yours)" on General → Spell Categories), with a row's gap before Fill; Spacing stays live. A's
Growth tab shows its follower-count line. Set B's Attach to back to *Screen* → B's own flow returns.
Result:

**LAYOUT-18. The seam.** Locked, real auras, B attached to A, A a column growing down → the gap from
A's last bar to B's first equals the gap between B's bars (2px at Spacing 2, not 4). A's Grow
vertically Up → B sits above A, one B Spacing between them, no overlap. A an icon row growing right →
B starts under A, one B **Line spacing** below A's last line. B's Spacing 10 → B's inner gaps and the
seam change together, and A does not move. B's Scale 1.5 with A at 1 → the seam still equals B's
on-screen gap. `/am test` → the seam between the placeholders equals the locked one. B's Y offset -3 →
B drops 3px further. Result:

**LAYOUT-19. An unlocked chain spreads.** On the chain, labels off, test mode off, `/am unlock` → one
column, top to bottom: A's strip, A's block, B's strip, B's block, C's strip, C's block. No strip sits
beside the column or over another container's block, each strip is lined up with its own block, and
each strip sits one Spacing past the block before it. With none of the three showing an aura, each
faint outline sits in its own slot, strip between them, in the same order. A container attached to
`PlayerFrame` and one attached to another container, unlocked → no Lua error in or out of combat.
Result:

**LAYOUT-20. A chain in test mode.** On the chain, unlocked, `/am test` → the same order around the
placeholder blocks: each follower's strip one of its Spacings past the block before it and its
placeholders starting right under its strip, each block enclosed by an outline of its own, and no
placeholder under another container's strip. `/am lock` with test mode on → the strips and outlines
go, and each follower closes up to one Spacing past the block before it. `/am test off` while locked
→ no outline at all; unlocked → only an empty container's one-element outline. Result:

**LAYOUT-21. The chain closes up on lock.** From LAYOUT-19, `/am lock` → every strip goes, and the
chain closes up: B one Spacing below A's last line, C one below B's, plus any X/Y nudge. `/am unlock`
→ it spreads again at once. Toggle three times; enter combat unlocked → no Lua error, taint or
`ADDON_ACTION_BLOCKED`. Result:

**LAYOUT-22. Growth up mirrors the chain.** Labels on for all three, set A's Grow vertically to Up →
B sits above A and C above B; unlocked, each reads bottom to top strip, label, block. `/am lock` →
each label sits directly below its own block, centered, and the followers close up. `/am test` → the
same around the placeholders. Set it back to Down. Result:

**LAYOUT-23. A side follower.** An Icons A, one icon wide, with a long name and its label on; an Icons
B attached This container Top left to Parent container Top right (on A's right), label on. Unlocked →
B's strip and label sit above B, and B is pushed down past A's strip and label rows, so neither of
B's overlaps A's. `/am lock` → B stays one label row lower while A's label shows, so A's name never
runs over B's; untick A's label → B sits level with A. Put B on A's left (This container Top right,
Parent container Top left) → B is never pushed, and its strip lines up with its edge that faces A,
over none of A's elements. With C below B, C's strip sits above C, covering none of B's elements.
Put B back on A's right and untick both labels: while A's strip runs past its one icon (the long
name), unlocked → B sits one strip row lower than A, clear of A's strip; `/am lock` → B moves back
level with A. When A's strip is no wider than its icon, B sits level unlocked too. Result:

**LAYOUT-24. One geometry.** With B below A, on A's right and on A's left in turn, and A showing live
auras: locked and unlocked → B sits on the same side of A (below, it sits one strip row further down
while its strip shows); in test mode → on the same side of A's placeholder block; with A empty and
unlocked → on that side of A's one-element outline. Entering combat unlocked puts B back on A's
engine. Result:

**LAYOUT-25. An empty parent, no overlap.** *Player buffs* with five buffs up and an enchant container
attached to it, unlocked → Player buffs shows no outline, and the follower sits past its last bar,
covering none. `/am lock` and `/am unlock` → nothing moves; `/am test` on and off → the placeholders,
then the live layout. Two chained Text containers, the first empty, unlocked, with Size to fit on and
off → the strips and outlines never overlap. Result:

**LAYOUT-26. An empty chain in combat.** Unlocked, with an empty chain showing outlines, pull a dummy
→ at the pull every follower moves onto its parent's engine and the outlines hide; leave combat →
they return. `/am lock` and take a perf capture while buffs change → no `emptyPass` bucket appears.
Result:

**LAYOUT-27. A centered chain holds still when its middle link is empty.** Three Bars containers in
one column growing up, X (root, the target's crowd control) ← Y (your buffs on the target) ← Z (your
debuffs on the target), each joined This container Bottom to Parent container Top (and once more
Bottom right to Top right). Target a unit with your debuffs but no buff of yours, so Y is empty →
locked, out of combat, Z sits straight above the column, its bars lined up with X's; `/am unlock` →
still; relock and pull a dummy → still, through the fight; unlocked in combat → still. Give Y an aura
and let it fall off → Z moves only up and down, never sideways. Result:

**LAYOUT-28. An empty link adds nothing.** A column of Bars containers growing up from a named frame:
D on the frame at Y 2, E on D and F on E (This container Bottom to Parent container Top), G on F
(Automatic), and a reference R on the same frame at Y 2. This line prints each bottom (put your ids in
place of R, D, E, F and G's 10, 22, 21, 20, 19):

    /run local N=LibStub("AceAddon-3.0"):GetAddon("AuraMaster")for _,i in ipairs{10,22,21,20,19}do local c=N.ContainerManager.instances[i]if c then print(i,c.anchor:GetBottom())end end

`/am lock`, out of combat, on a target where D, E and F show nothing → G's bottom bar is level with
R's, with no step, and the line prints one bottom for all five. Let F show one aura → G sits one bar
(plus its seam) higher; let it expire → G drops back level, one bottom again. Result:

**LAYOUT-29. An empty link in combat.** Locked, pull a dummy with D, E and F empty → G's bottom bar
stays level with R's through the fight, moving only when an aura appears or ends on a link, by exactly
that link's bars. Judge by eye: in combat the line can read secret. Result:

**LAYOUT-30. Populated links stay where they were.** Give D two auras → G sits exactly two of D's bars
(plus the seams) above R's level, and D's first bar starts exactly where the empty D sat, with no 1px
gap or overlap against the frame. On a screen container, the first aura sits where it always did. A
centered join is still centered across the column, no sideways shift of half a pixel or more. `/am
unlock` and `/am test` → the placeholders and the unlocked chain look as they should. Result:

**LAYOUT-31. The name label, locked.** On a fresh profile, Layout → **Label** → tick **Show name
label** on each starter while locked → #1 (Bars) shows its name in gold Friz 12 just above its first
element, centered, **Justify** reading Center; #3 (Icons, growing right) reads Left, lined up with its
first icon; #2 (growing left) reads Right, lined up on the right; #4 (Text) reads Center. Nothing else
moves. Grow vertically Up → the label moves below the first element. On #1 pick Left, then Right → the
name moves to that edge (4px in); Center → back. Set #3's Grow horizontally to Left → Justify reads
Right and the name right-aligns; pick Center and flip the growth → it stays centered. `/am get
container.label.justifyH` on an untouched one → `AUTO`; pick Left → `LEFT`; `/am reset
container.label.justifyH` → `AUTO`, the dropdown Center again. A Bars container changed to Text stays
centered. X/Y offsets and every font leaf (face, size, flags, shadow, color) apply live; with Show off
the offsets and font rows are grayed, but not the color swatch. Result:

**LAYOUT-32. The name label, unlocked.** `/am unlock` → the label stays, and the strip sits past it on
the same side, by the label's height plus the strip gap, never covering it; `/am lock` → the strip
goes and the label stays. `/am test`, locked and unlocked → the placeholders, the label and
(unlocked) the strip with its TEST tag, none overlapping. On the chain with every label on, unlocked →
each container reads strip, label, block, the root included: the label between its own strip and
block, never above its strip and never at the far left of the screen, centered inside its block's
width. Each follower sits one label row further down to make room. An Icons container attached below
another → its name sits above its own first icon, lined up with it as a root's is. Result:

**LAYOUT-33. Labels on a locked chain.** On the chain with every label on, `/am lock` → each label
sits directly on its own block, centered inside the block's width, none floating left of the column.
B's Justify Left, then Right → its name moves to that edge of B's block (4px in); its X and Y offsets
move it on top of that; put Center back. Untick B's label → C moves up one label row; untick all
three → the chain matches LAYOUT-21. Result:

**LAYOUT-34. The label with the rest.** On a target container with the label's class color on,
target a warrior, then a mage → the color follows; an NPC falls back to the swatch. Scale 2.0,
Opacity 0.5 and Master alpha → the label scales and fades with the container. Visibility *Only out of
combat* → entering combat hides container and label together, no `ADDON_ACTION_BLOCKED`. `/am
disable` hides it and `/am enable` brings it back; deleting the container removes it. Flush against
the top edge with the label above → note whether it is cut off (it is not clamped, a known
limitation). Result:

**LAYOUT-35. Fill follows the style.** On Containers → General switch a container's Style: to Icons →
Layout → Growth → Fill reads Rows; to Bars or Text → Columns. Grow horizontally and Grow vertically
are unchanged by the switch. Result:

**LAYOUT-36. Mouse.** Hover an aura → its tooltip at the configured position; untick **Tooltips in
combat** → none in combat. Right-click one of your own buffs in a player-buff container → it is
canceled; untick **Right-click to cancel** → nothing happens. **Click-through** → no tooltip, and
clicks pass through. A new container sits in the **Medium** strata (Layout → Frame → Strata). Result:

**LAYOUT-37. No world tooltip beside the aura's.** Put a bar container with two or more auras over a
world unit (an NPC or a player), Show tooltips on and Click-through off. Hover a bar → only the
aura's tooltip. Hover the gap between two bars, and the container's padding past the last bar →
still only the nearest aura's tooltip (or none past every bar), never the unit's beside it. A unit
tooltip that was up when the cursor entered fades rather than lingering. An icon container → the
same. Turn Click-through on → hovering a bar, and the gap between two, shows the unit's tooltip;
Click-through off again, then Show tooltips off → the unit's tooltip shows on the bar and in the gap
too. `/am test` and hover a placeholder over a unit → no unit tooltip; the gap between placeholders
shows the unit's tooltip by design (the blocker hides with the engine). Result:

**LAYOUT-38. The mouse blocker covers the whole container.** Anchor a bar container with Show
tooltips on and Click-through off over a unit frame, or ground you mouseover-target through, so its
padding sits over the target. Try a `/tar mouseover` macro through the padding → it fails while the
cursor is over the container, padding included; off the container it works again. Layout → Mouse's
**Show tooltips** text names this tradeoff, and Click-through on restores mouseover targeting
everywhere under the container. Result:

**Drag to attach** (issue #22). These use the chain from [Before you start](#before-you-start), A, B
and C, plus two screen containers: D, Icons growing right and down, so its growth differs from the
chain's, and E, a Text container growing down like A. Unlock first (`/am unlock`), and turn the
debug console's logging on (`/am debug on`) to read the `[Anchor]` lines.

**DRAG-1. Drop to attach, with the highlight.** Drag E by its strip toward A → while E comes within
about 24 px of one of A's sides, a 2 px green box frames A, a green dot sits on the point of A where E
would join, a dot of the same size on E's own point and a 2 px green line between the two; moving away hides
them all, and nothing else on screen changes while you drag. Drop E inside that range → E attaches there at once, with no popup: Layout → Anchor reads Attach to
*Another container*, Parent container A, the two anchor points of that side (Automatic where the
side is the default one), X and Y offsets 0. E's strip name turns gray, and moving A moves E. The log shows
`drop: attach to <A's id> <E's point>><A's point> (<side>)`, the side `free` for a pair above A. No Lua error, no `ADDON_ACTION_BLOCKED`. Result:

**DRAG-2. The nearest pair, on all four sides.** Drag E (attached to A, A growing down) to A four
more times, letting go each time just below A, just above A, just to A's right and just to A's left →
the box marks A each time and the marker sits on the point of A you came closest to; E joins flush
outside that side, lined up with whichever of its start, middle or end you dropped nearest: below A
(*after*, E's top on A's bottom), above A (E's bottom on A's top: the side A's lines start from, so a
free pair, placed at X/Y alone with no gap), on its right (*ahead*, E's left on A's right) and on its
left (*behind*, E's right on A's left). Layout → Anchor shows the matching pair each time, the default
side's as Automatic and the pair above A as both points picked. Result:

**DRAG-3. Shift places without attaching.** Drag D toward A with Shift held → no box appears, even
right on A's edge. Let Shift go while still close → the box appears; press it again → it goes. Drop on
A's edge with Shift held → D stays on the screen where you let go, Attach to still *Screen*, and the
log shows `drop: moved`. Result:

**DRAG-4. No loops.** Drag A slowly around the screen → B and C travel with it, sitting right against
it, and neither is ever framed by the green box; drop A → it stays on the screen where you let go (log
`drop: moved`). Likewise drag B → C travels with it and never lights up, though A may; drop B back on
the side of A it came from. No container ever frames the one being dragged. Result:

**DRAG-5. Detach by dragging away.** Drag E (attached to A) well away from every container → once
it is about 64 px from where it was attached, the box over A, both dots and the line turn red; drop it
there → E stays exactly where you let go, now on the screen: Attach to reads *Screen*, the X and Y
offsets 0, and Layout → Anchor → Screen holds the position. Its strip name turns gold, A no longer
moves it, and after `/reload` it is still there. The log shows `drop: detach`. Result:

**DRAG-6. The growth-conflict popup, accepted.** Drop D on A's side (D grows differently from A's
chain) → D goes back to where it was before the drag and the growth-conflict popup of LAYOUT-5 names
D, A and what changes. **Attach** → D attaches on that side with X and Y 0 and takes A's growth. Result:

**DRAG-7. The growth-conflict popup, canceled.** Detach D (drag it away), then drop it on A again →
the popup. **Cancel** → D stays where it was before the drag, Layout → Anchor unchanged (*Screen*, its
old position), and nothing else moved. Result:

**DRAG-8. Combat starting mid-drag.** Start dragging D toward A, then let a pet or a damage-over-time
pull you into combat before you let go → the green box disappears the moment combat starts and does
not come back. Drop on A → D does not attach; it stays where you let go and keeps *Screen*. Repeat with
B (attached to A): drop it far away in combat → nothing is written; B waits where you let go, and
when combat ends it is back on A, still attached. Try to start a drag in combat → nothing moves. No Lua error, no `ADDON_ACTION_BLOCKED`; the log
shows `drop: held (combat)`. Result:

**DRAG-9. A parent holding auras.** Out of test mode, with real auras showing in A (so B hangs from
A's live engine), start dragging B → B may jump so that its center sits under the cursor (by up to the
distance from where you grabbed its strip to its center, strip and name label included) and then
follows the cursor smoothly; the drop attaches or detaches as in DRAG-1
and DRAG-5, and a drop before the cursor has moved about 64 px snaps B back onto A (DRAG-15). Drag E toward A while A holds several auras → the green box frames only A's first
element, and a drop near that element attaches. Both are known limitations. No Lua error. Result:

**DRAG-10. A frame-attached container still does not drag.** Attach a container to `PlayerFrame` and
try to drag it by its strip → it does not move, its name is gray, and its tooltip reads "Anchored to
'PlayerFrame', so it cannot be dragged. Right-click for settings.". Clear its Frame name → the
tooltip reads "Set to a named frame, so it cannot be dragged. Right-click for settings.", never the
screen line's "Drag to move". Result:

**DRAG-11. The strip's tooltip.** Hover D's strip → "Drag to move. Drop it on another container to
attach it there; hold Shift to place it without attaching. Right-click for settings."; hover B's →
"Attached to '<A's name>'. Drag it away and let go once the marks turn red to detach it; let go sooner
and it snaps back. Drop it on another container to attach it there; hold Shift to drop it without
attaching. Right-click for settings.", then the gold "Joined to the …
of '<A's name>'" line; the frame-attached one as DRAG-10. Rename A → B's tooltip names the new name on
the next hover. Result:

**DRAG-12. A drop between pulls in a key.** In a Mythic+ key, out of combat between pulls (auras are
secret there with no combat lockdown), drop E on A's side → E attaches and sits on that side of A at
once; it is never left loose where you let go while Layout → Anchor already says *Another container*.
Drag B (attached to A) in combat in the key and drop it far away → when that pull ends B is back on A,
though the key keeps auras secret. No Lua error, no `ADDON_ACTION_BLOCKED`. Result:

**DRAG-13. A dropped side survives a growth change.** Drop E just to the right of A (*ahead*, start),
so it joins A's top-right → Layout → Anchor shows both anchor points, neither Automatic. Set A's Grow
horizontally to Left → E stays beside A and does not land on top of A's first element. Drop E just
below A (the default side) → both points read Automatic. Result:

**DRAG-14. A drag cut short.** Bind `/am lock` to a key (a macro), start dragging D and press the key
while the mouse button is still held → the strip hides and, within a moment, D stops following the
cursor and goes back to where it was before the drag; nothing is saved (`/reload` agrees), and the log
shows `drag canceled (its strip hid)`. Unlock and drag D → it moves and attaches as normal, and a
Layout change to D moves it at once. Result:

**DRAG-15. The detach leeway.** Drag E (attached to A, below it) slowly straight down, away from A →
at first the box over A, the dot on A's join point, the dot on E's own point and the line between
them stay green, though E is already out of snap range. Let go there → E snaps straight back to where
it was on A, Layout → Anchor is unchanged, `/reload` agrees, and the log shows `drop: held (leeway)`.
Drag it down again past about 64 px → box, dots and line all turn red at once; move back up → they turn
green again; go past it once more and let go → E detaches where you let go (as DRAG-5, log `drop:
detach`). Re-attach E below A, then with Shift held drag it so its top's middle sits just under A's
bottom middle (a pair that would take it without Shift) → no other pair lights up, the marks stay on
E's own pair in green, and a drop snaps it back. Hover E's strip → its tooltip explains all this
(DRAG-11). No Lua error. Result:

**DRAG-16. A drop above the parent, with the line.** Drag E toward the middle of A's top edge (A grows
down, so its top is the side its lines start from) → the green box frames A, a green dot about 10 px
across sits on the middle of A's top edge, a dot of the same size on the middle of E's bottom edge, and
a 2 px green line joins the two; as E moves the line and E's dot follow it, and box, dots and line show
and hide together. Drop → E attaches with its bottom flush on A's top, placed at X/Y alone with no gap;
Layout → Anchor shows both points picked (E's bottom on A's top), neither Automatic, and the log shows
`drop: attach to <A's id> BOTTOM>TOP (free)`. Drag E away → box, dots and line all go at once. Result:

## Bars and Icons style, fonts

**STYLE-1. The Bars tabs.** On a bars container, rail → Bars → **[ General ][ Background & border ][
Name text ][ Time text ][ Stack text ][ Icon ][ Pandemic ]**. **General** opens on its Size subsection
(**Width**, **Height**) before Fill and Spark. Result:

**STYLE-2. A bar's icon border.** Bars → Icon → tick **Show border**, thickness 3 → a border frames
each bar's icon, and the art shrinks inside it rather than under it. Result:

**STYLE-3. No spark on a timeless aura.** Bars → General → untick **Show the spark on auras without a
duration** → a permanent buff's full bar shows no spark (`/fstack`: its status-bar texture has no
width), and a timed buff's spark still rides its moving edge, just inside it; a spark placed wholly on
the elapsed side is clipped. In test mode the "Well Fed" placeholder loses its spark. If the permanent
bar still shows a spark, or the timed one loses it, report it. Result:

**STYLE-4. A timed bar's spark reads the same either way.** Two live timed auras of the same kind on
one bar container. Tick, then untick **Show the spark on auras without a duration** → a timed bar's
spark looks the same both times (color and brightness), differing only in position (centered on the
edge when ticked, just inside it when not). Repeat at a saturated **Spark color** (pure red or green)
and at a low-alpha one (about 25%) → still the same on and off. Unticked, no dark or black rectangle
around the spark and nothing sticking out above or below the bar, at the default color, the low-alpha
color and **Spark width** 32. A permanent aura's bar still shows no spark with the option off. Report
any difference, citing this check. Result:

**STYLE-5. Background opacity.** Bars → Background & border → Background reads **Background texture**
· **Background opacity** / **Background color** · **Use class color**. Drag **Background opacity**
down → the bars' background fades while the fill stays as it was. Result:

**STYLE-6. The fill by dispel type.** A bar container showing debuffs, Bars → General → **Color by**
dispel type → each bar's fill takes its type's General → Dispel Colors color; a debuff with no type
keeps the bar color. Set it back to one color → the fill returns to the bar color at once. Enter combat
with the aura still up → the fill keeps the bar color. In test mode on a debuff container → each
placeholder takes its type's color, Mortal Wounds the bar color; change the Poison swatch → the Deadly
Poison bar recolors while test mode is on. On a buff container only Bloodlust is Magic-colored. Result:

**STYLE-7. The background by dispel type.** Bars → Background & border → Color by **Dispel type** on
a target-debuff bar container → a Magic debuff's background is blue, a Curse's purple; a typeless
debuff and an Enrage-type buff keep the background's own color. The same in test mode. Color by Static
→ the background color alone, including on bar slots that had shown a dispel tint a moment before and
on the next auras to reuse them. Back on Dispel type, Background opacity 20% (and separately the
background color's own alpha 50%) → a typed and a typeless debuff's background both go see-through,
and the fill likewise at 20% Bar opacity. Then in combat, on debuffs applied after the pull → the
background keeps its 20%. A background that turns opaque in combat only means the engine refused the
region alpha: report it. Result:

**STYLE-8. Typeless debuffs.** Out of combat, target a dummy carrying a Paladin's Judgment and
Consecration and run the three `/run` lines in `docs/midnight-quirks.md` → "Many debuffs carry no
dispel type"; copy the output there. On a bar container colored by dispel type, say whether those
debuffs' background is dark (typeless) or blue (the engine reports a type; the probe's `dispelName`
column says which). The Bars **Color by** tooltips and General → Dispel Colors say buffs and many
debuffs have no dispel type, naming class debuffs such as Judgment or Consecration. Result:

**STYLE-9. The Dispel Colors tab.** General → **Dispel Colors** → above the five swatches (no None
swatch), "One color per dispel type, shared by every container:" on its own line, then four lines
each opening with "- ": where the colors are read (bars by dispel type, and a text line's dispel
type word, backdrop or edge, ending "(Text -> Font)"), that buffs and many debuffs have no dispel
type, class debuffs such as Judgment or Consecration included, how those look, and that an icon's
dispel border keeps Blizzard's own colors. A hairline gap between the bullets, none sharing a line,
nothing cut off or scrolling sideways. Set Magic to pure red → a bar container colored by dispel
type shows a Magic debuff's fill red, while an icon container's Magic dispel border stays Blizzard's
blue. Each swatch's tooltip says it colors a bar's fill or background and a text line's dispel type
word, backdrop or edge, and that an icon's dispel border keeps Blizzard's own colors. Result:

**STYLE-10. The Icons tabs and the countdown.** Rail → Icons → **[ Size ][ Border ][ Cooldown ][ Time
text ][ Stack text ][ Pandemic ]**. On Cooldown tick **Blizzard countdown numbers** → on a timed aura
the countdown and the time text read the same whole second throughout, in each time format (both round
up: 12.7 s reads 13). Past 90 s the Blizzard format reads minutes, as the game's own buff text does.
If the two still disagree by a second, report it. Result:

**STYLE-11. The icon border color.** On an icon container showing a buff, Icons → Border → color
bright red, thickness 2 → every icon's border turns red at once. If a border does not change, `/fstack`
over that icon and report the frame it names. Result:

**STYLE-12. The dispel border's shape.** On an icon debuff container with a Solid 1 px black border,
Icons → Border → **Color the border by dispel type** on → each typed debuff shows a square edge in
Blizzard's type color exactly where its neighbors show black: no beveled corners, nothing in the icon
spacing; a typeless debuff and every buff keep yours. Thickness 4, then 8 → the colored edge always
matches the black edge's thickness. **Show border** off (or style None) → the typed icons still show a
1 px colored edge. A non-Solid border style → the colored edge is flat strips at the border's
thickness; report whether that looks acceptable. In test mode → Shadow Word: Pain (Magic), Hex
(Curse), Frost Fever (Disease), Deadly Poison (Poison) and Rupture (Bleed, if the client gives it a
color) show it, Mortal Wounds none; turn it off → every one goes at once. An icon buff container never
shows one, Bloodlust included. Record the color Blizzard gives a Bleed. Result:

**STYLE-13. Placeholder time text.** `/am test` on a bar container and switch Time text →
**Countdown** between Blizzard, short and detailed → the placeholders' time text follows and reads as
a live aura's does in that format. Tick Pandemic → **Recolor the time in the pandemic window** → the
*Shield Wall* placeholder (4 s left) takes the pandemic-window time color. Result:

**STYLE-14. Justify on bars and icons.** Bars → Name text → **Justify** Right → the name moves to the
right end of its box and stops short of the time text. Bars → Time text, name shown, **Justify** Left,
then Right → the time moves across a box as wide as its format's longest string ("59m"; "23h 59m" in
the detailed format), and the name stops short of that box. Icons → Time text Left, then Right → the
time moves across the icon's width. Result:

**STYLE-15. A 59-minute buff on a bar.** A 59-minute Power Word: Fortitude on a default bar reads `59
m` in full, not `59...`, and still does with the time text's X offset at -15. Result:

**STYLE-16. The Pandemic tab.** Bars and Icons each end with a **Pandemic** tab; Text has one between
Icon and Animation. On Bars and Icons it holds **Time color** (Recolor the time in the pandemic window,
Pandemic window (seconds left), Pandemic-window time color) and **Highlight** (Highlight the pandemic
window, Pandemic-window highlight color). On Text, Time color with those three and Blink in the
pandemic window, and the gray "The pandemic window needs a duration token, such as $remainingduration$,
in the template." under them on a template without one; Text → Animation holds the Loop rows alone.
No tooltip says "running out" or "refresh window", and `/am list` names the same paths as before.
Values set on a build that still had the Highlights tab are kept (a pandemic window of 8 still reads
8). Result:

**STYLE-17. An icon border through the pandemic settings.** An Icons container with auras up, Icons →
Border → Show border on (Solid, 2). Out of combat, change Icons → Pandemic one row at a time
(Highlight off and on, the highlight color, Recolor the time, the window's seconds) → no Lua error
(none naming `Backdrop.lua`), the border keeps drawing, and an aura in its pandemic window still
highlights and recolors its time. Repeat with the border off → the same. Result:

**STYLE-18. A bar's borders.** A bar container with Background & border → Show border on, and Icon →
Show border on. Change the bar's Width, then its Pandemic rows → both borders keep drawing at their
thickness and color, no Lua error, and the pandemic highlight still shows. Result:

**STYLE-19. A border style other than Solid.** On a bars, an icons and a Text container, pick another
Border style (a media pack's edge, or "Blizzard Tooltip") → no Lua error; test mode draws it at once,
while buttons already on screen keep their old look until `/reload`, then draw it. Change its color →
the live buttons recolor at once. Hover Border style → the tooltip says Solid redraws at once and any
other texture after a `/reload`. Back to Solid → the strips draw at once, with no texture edge left
under them. Result:

STYLE-20 to STYLE-30 check the font primer (`modules/FontPrimer.lua`), which draws every container
font once on a shown frame before any container text uses it. First set every container's text fonts
to **Ka0s Prototype** (Bars name, time and stacks; Icons time and stacks; the Text line; the name
label), and disable any other addon that draws that font first. Between an aura appearing and the
check, do not lock, unlock, toggle test mode or change a setting: each rewrites every name and would
hide a blank.

**STYLE-20. A cold cache at login.** Quit the client, rename `World of Warcraft\_retail_\Cache` to
`Cache.old`, start it and log in with several of your own buffs up (a long class buff, a food or flask
buff) and a dummy nearby. Do not `/reload` or touch any setting → every bar, icon and Text line present
at login shows its text (name, time and stacks) from the moment it appears. Result:

**STYLE-21. New auras after login.** Straight after STYLE-20, out of combat, cast spells not yet cast
this session that put a buff on you and a debuff on the dummy → each new bar, icon and Text line shows
its text from the moment it appears. Result:

**STYLE-22. New auras in combat.** In the same session, attack the dummy and cast the rest of your
rotation → no bar, icon or Text line is ever blank, in combat or after it. Result:

**STYLE-23. A font change.** Out of combat, buffs up in a bars container, change its Bars → Name text
font to one no container has used this session (**Ka0s Kait**, or a new size of Ka0s Prototype) → the
names redraw in it, and any that go blank come back within about 1 s with nothing touched. Result:

**STYLE-24. A reload with auras up.** With auras up in every container, `/reload` → after the loading
screen every container's text shows; any blank at first fills in within about 2 s. Result:

**STYLE-25. The primed fonts in diagnostics.** `/am diagnostics` → the header has one `[Diag] fonts
primed: N [...] refresh=idle` line, N at least 1, listing `Ka0s Prototype.ttf` with each size and
outline your containers use (and `Ka0s Kait.ttf` after STYLE-23), and no Friz Quadrata entry. Result:

**STYLE-26. The primer's debug line.** `/am debug on`, open the console, change a container's font
size to one not used yet → one `[Fonts] primed 1 new font(s)` line. Change a setting that is not a
font (a bar height) → no new `[Fonts]` line. Result:

**STYLE-27. While disabled.** `/am disable`, wait a few seconds, `/am diagnostics` → the report still
prints the `fonts primed:` line, with the same list and `refresh=idle`. `/am enable` → every container
comes back with its text showing, none blank. Result:

**STYLE-28. Labels and literal text.** Turn on one container's name label and give a Text container a
template with literal text between tokens (`$spellname$ - $stacks$`), both in Ka0s Prototype, then
`/reload` with auras up → the label and the literal text show from the start, or fill in within about
2 s. Out of combat, turn on test mode and change the label font and a Bars name font to a size not
used yet → the label and the placeholder names and stack counts show in it, or fill in within about
1 s. Result:

**STYLE-29. The loading-screen gap.** Quit the client, delete `World of Warcraft\_retail_\Cache`, start
it and log in with permanent buffs up (a long class buff, an aura or a flask) in containers on Ka0s
Prototype. Do not `/reload` or touch any setting → every name present at login draws within about 2 s
after the loading screen ends and stays drawn. `/am diagnostics` right after the loading screen may
read `refresh=armed-world`, and a few seconds later `refresh=idle`; its `loading screen:` line gives
both times and the gap (record the gap here; `ended -` is a failure). Zone (a portal or an instance) →
nothing blanks after that loading screen either. Result:

**STYLE-30. Every font primed after a cold start.** Quit the client, delete the Cache folder, start it
and log in on a character whose containers use Ka0s Prototype (and Ka0s Kait, if any does). Do not
`/reload` or touch any setting. A few seconds after the loading screen, `/am diagnostics` → the
`fonts primed:` line lists every Ka0s font in use with each size and outline (every Ka0s Prototype
triple, not only Ka0s Kait), and ends `refused=0`. Result:

## Text style

TEXT checks run on a Text container on your buffs (an icon on the left, its border on) and one on the
target's debuffs, near a dummy.

**TEXT-1. The default template.** A player-buff container styled as Text → names, ` x3` stacks and ` -
12s`, all live in combat; a timeless buff shows its name only. Result:

**TEXT-2. Several durations.** Template `$spellname$ $remainingduration$ / $maxduration$
($remainingpercent$)`, Justify Left, then Right → the line reads and lines up both ways. Result:

**TEXT-3. The dispel type token.** `$spellname$[ ($dispeltype$)]` on a target-debuff Text container →
the correct type names; nothing, brackets included, on a typeless debuff. `[$dispeltype$]` on a Bleed
debuff → "Bleed"; on an Enrage-type buff → record what it reads. Result:

**TEXT-4. Loops.** Pulse, Blink and Bounce, each through a pull → no piece overlaps another while it
animates; a change made in combat starts when combat ends. Result:

**TEXT-5. The pandemic window.** Text → Pandemic → Recolor on, then Blink on → the duration run turns
the color, then blinks, in the last N seconds; the rest of the line keeps the font color. Blink on and
Recolor off → the alpha steps read as a blink, not a flicker or a smooth fade. Result:

**TEXT-6. The Icon tab.** On a new Text container (Icon position None), the Icon tab's rows are dimmed
under a gray "Set Icon position to show the icon.", except Icon position and the border's color
swatch. Icon Left → the rows go live and the note goes at once. Show border on at thickness 2 in red →
a red border frames the icon on every line, the art inside it. Result:

**TEXT-7. An icon on the right.** Icon position Right, with the border → the text starts after the
icon and its gap, and with Size to fit off a long line is cut at its box rather than drawn under the
icon. Result:

**TEXT-8. Changes keep every line.** `/am debug on`, then bare `/am debug` to open the console, with
auras showing, on the Text container with its icon on the left and its red border on: change Text →
General → **Width (px)** several times (drag, then type), then the other Text settings one after
another (font, size, template, icon size, the border) → every line keeps its text, its icon and its
border; no empty bordered squares, no `[Style] text icon failed` line in the console, no Lua error.
Rows that go blank must come with a `[Style] … failed:` line in the console and one Lua error naming
it: copy both word for word. A refused icon call costs the icon alone, the text still drawing; rows
that go empty with no such line are a defect too, so report the steps. Result:

**TEXT-9. Template refusals.** In the Template box, and with `/am set container.text.template
$spellname$ $bogus$` (no quotes) → chat prints `Invalid value for container.text.template` and,
indented, the rule that broke; the stored template does not change. Try each template rule once.
Result:

**TEXT-10. Nested clipping.** A template wider than the box, on a narrow Text container with Size to
fit off → the line is cut at the box edge, never drawn past it or under a neighboring container.
Result:

**TEXT-11. A Text button built in combat.** With a Text container up, gain a brand-new aura mid-fight
→ the new button dresses and animates like the others, with no error. Result:

**TEXT-12. Icon Left to None, live.** On an unlocked Text container showing its icon on the Left,
switch Icon position to None → the icon disappears cleanly, and none comes back on the next aura
change. Result:

**TEXT-13. A literal percent sign.** Template `$remainingduration$ % $maxduration$` → a literal `%`
between the two times, not a formatting artifact or an error. Result:

**TEXT-14. Bracketed stacks.** Template `[[[$stacks$]]]` → `[3]` (however many stacks) on a stacked
aura; nothing at all on a non-stacking aura. Result:

**TEXT-15. Center stacks the pieces.** Text → General → Justify Center, template *Centered: name over
time* → the name on one row and the time centered under it, each row centered; the container grows to
hold both, the outline and the handle following. Justify Left → one line again. Result:

**TEXT-16. Percent tokens.** Template `$spellname$ ($remainingpercent$%)` on a 30 s buff → `Name
(73%)`, a whole number, no space inside the brackets. On a buff without a duration (a mount) → record
whether it reads `( )`; `[ ($remainingpercent$%)]` shows nothing there. Run these probes and record
what each prints:

- `/run local f=C_StringUtil.CreateNumericRuleFormatter() f:SetBreakpoints({{threshold=0,format="%d%%"}}) print("["..f:FormatNumber(45.5).."]","["..f:FormatNumber(45).."]")`
  (`[]` for 45.5 and `[45%]` for 45 confirms the old rule's gap; `[45%]` twice rules it out);
- `/run local f=C_StringUtil.CreateNumericRuleFormatter() f:SetBreakpoints({{threshold=0,step=1,format="%d"}}) print("["..f:FormatNumber(45.5).."]")`
  (the current rule: `[46]` or `[45]`, never `[]`);
- `/run local s=UIParent:CreateFontString(nil,"OVERLAY","GameFontNormal") s:SetPoint("CENTER") s:SetText("") print(s:GetWidth(), s:GetStringWidth())`
  (a non-zero first number is the space seen between `(` and `)`).

Result:

**TEXT-17. The percent formatter's rounding.** `$remainingpercent$` near a round number (a buff at
99.6% remaining, ticking to 99% and 100%) → compare the live line with the Text preview's rounding
(to the nearest whole number). Report whether the live formatter rounds (99.6 → 100) or floors (99.6 →
99); a mismatch between the two is a defect. Result:

**TEXT-18. Built-in templates and the Preview.** Text → General → **Template** lists the built-ins
(Name, Name + time, …; a debuff container adds Name (type) and Name, type, time) and **Custom**. Pick
each → the read-only **Preview** under it and the live auras follow. *Centered: name over time* also
sets Justify to Center and previews `$spellname$[$remainingduration$]`, joined by " / " in the Preview
("Ignore Pain / 11s") while the live container shows the rows stacked. **Custom** → the template box
appears. Result:

**TEXT-19. The dispel type word in color.** A Text container on the target's debuffs, template Name,
type, time, Text → Font → Dispel type → **Color the dispel type** on → a Magic debuff reads `Name
(Magic) - 12s` with only `Magic` in the Magic color from General → Dispel Colors, the brackets and the
rest in the font color; a Curse in its color. Change the Magic swatch → the word follows after the
re-apply. In combat the word keeps its color as auras come and go. If the word shows raw `|cff…`
characters, report it. With a template without `$dispeltype$` the toggle is dimmed. The Dispel type
subsection (Color the dispel type, Backdrop in the dispel color, Backdrop opacity, Edge in the dispel
color, Edge thickness) sits on the Font tab under Countdown, not on Animation; toggles set on a build
that still had them on Animation keep their values. In test mode each placeholder line shows its type
word, tinted, and Mortal Wounds shows no type and no tint. Result:

**TEXT-20. The dispel backdrop.** Same container, **Backdrop in the dispel color** on → a typed
debuff's line has a box in its type's color behind the text, the text on top and readable; a typeless
debuff has none. **Backdrop opacity** changes its strength and is dimmed while the backdrop is off.
With the icon on the left, the box covers the text area only. With Pulse or Bounce, the box moves and
fades with the line. Test mode → each typed placeholder (Shadow Word: Pain, Hex, Frost Fever, Deadly
Poison, Rupture) has a box in its type's color, and Mortal Wounds has none. Turn the backdrop off →
every box goes at once. Result:

**TEXT-21. The dispel edge.** **Edge in the dispel color** on, backdrop off → a thin outline in the
type's color around a typed debuff's text area, none on a typeless one; **Edge thickness** 1 to 4
thickens it. Both on → the edge draws over the backdrop. On a buff container, a Magic buff (Power
Word: Fortitude, Arcane Intellect) is outlined too. `/reload` and combat → nothing to fix up. Result:

**TEXT-22. A type the palette does not cover.** A Text container on the target's buffs with Color the
dispel type, Backdrop and Edge all on, on a mob with an Enrage-type buff (an enraged dungeon mob) →
the line has no tint on its type word, no backdrop box and no edge, the same as a typeless aura, and
no blank space held for them. A box or edge that shows (white, or any color): report it with the mob
and the buff's name. Result:

**TEXT-23. A stacked icon keeps one row's height.** On the Text container with Icon position Left,
Text → General → Justify Center, template *Centered: name over time* → the rows stack and center and
the container grows to hold them, but the icon keeps its configured size. Set **Icon size (0 = line
height)** to 0 → the icon is one row's height (the font size), not the height of the whole stack.
Justify Left with size 0 → the icon is the box's height again. Result:

**TEXT-24. The Text Template section.** Text → General → the subsection is titled **Text Template**.
Under the Custom template box, **Preview** is a disabled edit box holding the rendered line in the
container's font color, a colored dispel word riding live in it when that option is on. Under it, the
cheat sheet: two headed, bulleted lists with a gap before each heading, **Tokens** (one gold `$token$`
bullet each) and **Rules** (bracket hiding, the two escapes, how they combine, text outside `[ ]`
always showing, a separator inside the brackets of the field it leads), each rule's example on its own
indented line in the token gold. The headings are bright; only the Placement notes are gray. Result:

**TEXT-25. No gap between template pieces.** A target-debuff Text container, Justify Left, template
`$spellname$-$stacks$-$dispeltype$-$remainingduration$-$maxduration$-$elapsedduration$-$remainingpercent$-$elapsedpercent$`,
on a typed debuff with stacks → `Fire Breath-3-Magic-6 s-…` with no space either side of any `-`
between two non-empty fields. Justify Right → the same, laid from the right. An empty field (one stack,
no type) still leaves its `-` and a small gap; rewritten as `$spellname$[-$stacks$][-$dispeltype$]...`
the empty field's separator goes with it. A gap between two non-empty fields is a defect: report the
font, size and flags. Result:

**TEXT-26. The Justify note.** Text → General → Placement: a gray note under Justify and Vertical
justify, above the offsets, on Left, Center and Right alike. It says Center centers a one-piece
template only and stacks several fields in rows (text outside `[ ]` not drawn, the box growing, rows
kept when a field is empty, an icon at size 0 one row tall), and that aura text is secret so its width
cannot be measured. Each claim holds on a live container. Result:

**TEXT-27. Size to fit starts ticked.** A new profile's *Player cooldowns* starter has **Size to fit**
ticked, and so does a container made in an existing profile and set to Text. Tick it on a container
that had it off → the box resizes at once and the handle and outline follow; Width and Height gray
out with the note under them, and their tooltips say why. Result:

**TEXT-28. Size to fit follows the content.** With it on, change the font size, the template, the
countdown format, Icon Left with size 24, and Justify Center with a three-field template → each
resizes the box. Icon size 0 with Bounce → neither the icon nor the text is cut at the right; at
Vertical justify Middle or Bottom the bounce is not cut at the top (at Top it rises above the box,
uncut). A long-lived aura (hours or days) shows its whole time string. Result:

**TEXT-29. Size to fit and a long live name.** A `$spellname$` template, live, Size to fit on: gain
Guardian of Ancient Kings (or a buff whose name is longer than every sample) → the whole name draws,
past the box's edge if need be, from the justify point: Left runs right, Right runs left, Center both
ways, in and out of combat. Two such auras at once → neither is cut. Untick Size to fit (a narrow
Width) → cut at the box again; tick it → whole again, no `/reload`. `/am test` on and off with the
buff up → the samples, then the whole live name. In combat, gain and lose auras → no error and the
size does not change; untick Size to fit out of combat, then in combat `/am set
container.text.autoSize true` (the page itself is locked in combat) → it applies after combat. With a SharedMedia font, log in → at worst one
apply at the stored size, then sized to fit. Result:

## Library-absent install

**DEGRADED-1. Without the launcher libraries.** Rename `libs/LibDBIcon-1.0` aside, `/reload` → one
chat line naming Aura Master and the missing library, no error frame, and the addon otherwise works.
Rename `libs/LibDataBroker-1.1` aside too, `/reload` → the same. Put both back. Result:

## Non-English client

Only the enUS locale ships, so the addon's own words stay English on every client; the spell names
it shows come from the client. Run these on a non-English client (a language pack on the PTR, or a
non-English account).

**LOC-1. Spell names come from the client.** Log in with the starter set → no Lua error. `/am test`
→ the placeholders show their spells' names in the client's language, each with its real icon. General
→ Spell Categories → *Defensive cooldowns* → the starter spells read in the client's language, sorted
by name with case ignored for the plain letters A to Z; a name that starts with an accented or
non-Latin letter sorts after every name that starts with a plain one (the list sorts the lowercased
names byte by byte, not by the language's alphabet). A Text container on your buffs shows the live aura names in the client's
language. The addon's own labels, chat lines and the `$dispeltype$` word are English, with no raw key
and no blank label. Result:

**LOC-2. Adding a spell by its localized name.** On General → Spell Categories → **Add a spell**, type
the client-language name of a spell in your spellbook → it is suggested, and Enter adds it with its
icon. Type the same spell's English name → record whether it resolves. Its id and a shift-clicked link
add it either way. Result:

## Pending sign-off

Two kinds of check are listed here. First, old checks with no recorded pass: the batch 5 and batch 6
checks that were listed as owed (2026-09-13 and 2026-09-14/15), the smoke batch 2 checks after the
range the owner verified on 2026-09-20 (143 to 161), the settings redesign checks that were not
reported individually (2026-09-26), the batch 8 and batch 9 checks whose items failed the owner's two
2026-09-25 runs and that no later run passed, the font primer (2026-09-27) and the mid-key reload
(2026-09-29).
Second, every check that is new on 2026-09-29 or later, or whose expected result was corrected against
the code then, since none of those has been run in its current form. Sign one off on its own `Result:`
line, then remove its row here.

| ID | Origin (old numbering) |
|---|---|
| INSTALL-2 | 2 and 103: the starter count corrected on 2026-09-29 (four, #4 *Player cooldowns* included) |
| INSTALL-4 | 4: the starter count corrected on 2026-09-29 (four) |
| INSTALL-5 | 58a, batch 5 |
| INSTALL-6 | 125 and 135: the upgrade read-out corrected on 2026-09-29 (the `[Migrate]` lines are written while logging is still off at login, so the check reads the `[Init]` line's schema version) |
| INSTALL-8 | 68, batch 8 (failed 2026-09-25): its v8 step, the 0/-4 offsets of an attached container reading 0/0; 212, batch 9 (failed in the late 2026-09-25 run): its step switching a screen container to Another container; the chains and `attach.y` steps passed as 234 and 242, but its upgrade read-out was corrected on 2026-09-29 as INSTALL-6's |
| SLASH-2 | 208, batch 8 (failed 2026-09-25): the help-order step, which the 2026-09-26 diagnostics run did not repeat; and its row count, 24 with `profile` listed, new on 2026-09-29, now 25 with `redraw` listed (2026-09-30) |
| SLASH-9 to SLASH-11 | new on 2026-09-30 with `/am redraw` (SP-AMX-02) |
| PANEL-1 | 251 (S1), settings redesign |
| PANEL-6 | 264 (S14), settings redesign |
| PANEL-9 | 259 (S9), settings redesign |
| PANEL-10 | 260 (S10), settings redesign |
| PANEL-13 | 256 (S6), settings redesign |
| PANEL-14 | 263 (S13), settings redesign; its empty-rail half (270, I23-4) passed |
| PANEL-22 | 87: the tooltip title's expected text corrected on 2026-09-29 (the name, then the version) |
| PROFILE-2 | 50: the starter count corrected on 2026-09-29 (four) |
| PROFILE-5 to PROFILE-11 | new on 2026-09-29 with the `/am profile` verb; PROFILE-10 extends 58's profile switch while disabled |
| PROFILE-12 | 47: rewritten on 2026-09-29, a reset being the one profile change combat allows |
| STATE-1 | 21: its in-combat step rewritten on 2026-09-29 for `/am set`, since the panel is locked in combat |
| COMBAT-5 | 265 (S15), settings redesign |
| COMBAT-7 | 292 (MK1), mid-key reload |
| DIAG-3 | 54: the Profiles → Copy line corrected on 2026-09-29 to the ASCII `->` the code prints; the rest is unchanged or passed as 271 to 273 |
| DIAG-5 | 206, batch 8 (failed 2026-09-25): the steps 210 does not repeat; 210 passed |
| DIAG-6 | 207, batch 8 (failed 2026-09-25): the in-combat steps, its Cast by change rewritten on 2026-09-29 for `/am set container.filter.castBy`, since the panel is locked in combat; the disabled steps passed as 235 |
| DIAG-9 | 211, batch 9 (failed in the late 2026-09-25 run): all of it; its `attach.y=-4` step moved to INSTALL-8 and passed as 234 |
| DIAG-11 | 293 (MK2), mid-key reload; its line shape corrected on 2026-09-29 |
| DIAG-12 | 294 (MK3), mid-key reload |
| DIAG-13 to DIAG-15 | new on 2026-09-30 with the resizable console, copy window and perf panel (LibKa0s v1.64.0, DL-AM-01) |
| DIAG-16 | new on 2026-09-30 with the console's Diagnostics link (LibKa0s v1.64.0 re-cut, DebugLog 16, DL-AM-03); its click reworded the same day, the link now turning logging on (DebugLogDiagnostics 2, DL-AM-04) |
| DIAG-17 | new on 2026-09-30: diagnostics turns debug logging on for the session (standard v2.71.0, DebugLogDiagnostics 2, DL-AM-04) |
| DIAG-18 to DIAG-20 | new on 2026-10-01 with LibKa0s v1.65.0 (DG-AM-01): the library's own `[Cmd]`, `[Lifecycle]` and at-enable `[Launcher]` lines in this addon's console, and its change gates re-armed by a Clear |
| CONT-3 | 31: its in-combat steps rewritten on 2026-09-29 for `/am new`, `/am delete` and a Delete popup opened before the pull, since the panel is locked in combat |
| CONT-5 | 205: its in-combat rename rewritten on 2026-09-29 for `/am set container.name` |
| CONT-8 | 162, smoke batch 2 (owed: the owner verified 143 to 161 only) |
| CONT-9 | its tooltip lines corrected on 2026-10-02 for drag to attach (issue #22): the screen line names the drop, and a container attached to another names its parent and how to detach it |
| CONT-21 | 136 and 224: the placeholder count corrected on 2026-09-29 (one per ticked slot, three by default) |
| FILT-2 | 80, batch 6 |
| FILT-4 | 24: its Spell Categories grid corrected on 2026-09-29 (Hard CC, Soft CC and Racials with their See spells links, the line naming General -> Spell Categories and the hostile-unit note, since issue #11); its NOTE line under the Spell Categories heading new on 2026-10-02 (spell-list views, SV-04); the note under the grid reworded to "you can't assist" (SV-05) |
| FILT-5 | 78 and 81, batch 6 |
| FILT-7 | 77, batch 6; its row labels corrected on 2026-09-29 (*Dispellable by anyone*, *Boss debuffs*) |
| FILT-8 | 83, batch 6; its row label corrected on 2026-09-29 (*From any player*) |
| FILT-10 | 79, batch 6; 262 (S12), settings redesign |
| FILT-11 | 164, smoke batch 2 (owed, as CONT-8) |
| FILT-13 | 166, smoke batch 2 (owed, as CONT-8) |
| FILT-14 | 70, batch 5 |
| FILT-15 | 72, batch 5 |
| FILT-16 | 73, batch 5 |
| FILT-17 | 74, batch 5 |
| FILT-18 | 75, batch 5 |
| FILT-19 | 75, batch 5 (the tooltip half) |
| FILT-21 | 179 and 180: the chat line's expected text corrected on 2026-09-29 (each spell named, its id in brackets) |
| FILT-27 | 82, batch 6 |
| FILT-30 | its warning sentences corrected on 2026-10-02 (spell-list views, SV-01; the Overrides-only sentence, SV-05; the full sentence points to the Situations tab, SI-06) |
| FILT-42 | new on 2026-09-30 with the weapon-enchant name reset (SP-AMX-01) |
| FILT-43 to FILT-45 | new on 2026-10-02: the Options descriptor passes `addonName`, so help marks draw the library's `info` art (LibKa0s#42, CA-AM-NM) |
| FILT-46 to FILT-51 | new on 2026-10-02 with the spell-list views (SV-04); FILT-51's NOTE sentences end "(see Situations)" since the same day (filter situations, SI-05) |
| FILT-52 | new on 2026-10-02: the player's own reaction change (SV-05) |
| LAYOUT-1 | 69, batch 5 |
| LAYOUT-6 | 162, smoke batch 2 (owed, as CONT-8): the outline moving across aura buttons; 42: its combat refusal corrected on 2026-09-29 to `/am pick` alone, since the panel's button is locked in combat |
| LAYOUT-11 | 67, batch 8 (failed 2026-09-25): the **Per row** step; the rest passed as 238 |
| LAYOUT-17 | 67, batch 8 (failed 2026-09-25): all but the inherited-growth note, which passed as 233 |
| LAYOUT-18 | 68, batch 8 (failed 2026-09-25) |
| LAYOUT-20 | 221 and 227: no outline on lock since 2026-09-27 (commit d01ac9d), after both passes |
| LAYOUT-25 | 202, batch 8 (failed 2026-09-25): the step with two chained Text containers; the rest passed as 194 |
| LAYOUT-37 | 64 and 76, batch 5 |
| LAYOUT-38 | 84, batch 6 |
| DRAG-1 to DRAG-14 | new on 2026-10-02 with drag to attach (issue #22); DRAG-12 to DRAG-14 from its whole-branch review (DD-05); DRAG-1's highlight corrected the same day for the two join dots and the line (owner feedback, DD-08) |
| DRAG-15 | new on 2026-10-02 from the owner's smoke feedback (addendum A4; DD-09): the detach leeway, its snap back and the red past `C.DETACH_RADIUS`; DRAG-5, DRAG-9, DRAG-11 and CONT-9 corrected the same day for it |
| DRAG-16 | new on 2026-10-02 from the owner's smoke feedback (addendum A1, A3; DD-08): a before-side drop, the line and both dots |
| STYLE-3 | 63, batch 5 |
| STYLE-6 | 59a, batch 5 |
| STYLE-9 | 61, batch 5; 163, smoke batch 2 (owed, as CONT-8); its bullet count corrected to four on 2026-09-29 |
| STYLE-10 | 62, batch 5 |
| STYLE-11 | 60, batch 5 |
| STYLE-13 | 65, batch 5 |
| STYLE-14 | 66, batch 5 |
| STYLE-20 to STYLE-30 | 281 to 291 (FP1 to FP11), font primer |
| TEXT-8 | 99, 153 and 159: its logging step corrected on 2026-09-29 to `/am debug on` (bare `/am debug` only toggles the console, and the `[Style]` line is written only while logging is on) |
| TEXT-20 | 131: its test-mode step corrected on 2026-09-29 (a debuff container previews the debuff placeholders, each typed one boxed in its type's color, Mortal Wounds none) |
| TEXT-23 | 134: corrected on 2026-09-29 to a Text container's own icon on a stacked Center (an Icons container has no Text section and draws no template text) |
| TEXT-27 | 200, batch 8 (failed 2026-09-25): all but the migrated-profile step, which passed as 213 |
| TEXT-28 | 201, batch 8 (failed 2026-09-25) |
| TEXT-29 | 202, batch 8 (failed 2026-09-25): the in and out of combat, in-combat and SharedMedia steps, its in-combat Size to fit step rewritten on 2026-09-29 for `/am set container.text.autoSize`, since the panel is locked in combat; the rest passed as 214 |
| LOC-1, LOC-2 | new on 2026-09-29 (the Non-English client section) |
