# Ka0s Aura Master — in-game smoke tests

Run on a live Retail client at Interface 120100 (12.1.0), in order; later steps assume earlier ones
passed. Turn on Lua errors first (`/console scriptErrors 1`, or BugSack). Watch chat for the cyan
`[AM]` tag and for any error frame. The headless gate (`docs/testing.md`) covers the pure logic; this
suite covers what only the client can show.

## A. Install and load

1. **Fresh install.** Remove `WTF/Account/ACCOUNT/SavedVariables/AuraMaster.lua`, log in → the world
   loads with **zero Lua errors**.
2. **Starter containers.** Three containers appear without any setup: *Player buffs* as bars near the
   top right, *Player debuffs* as icons just above it, *Target debuffs (mine)* as icons below the
   screen center. Your current buffs are in the first; target a dummy, apply a debuff and it appears
   in the third.
3. **`/reload`** → no errors; every container is where it was.
4. **Delete all three**, `/reload` → they do **not** come back (the profile is marked seeded).
   Recreate one with `/am new` for the rest of the suite, or reset the profile (step 52) to get the
   starters back.

## B. Slash surface

5. `/am` → Settings opens at **Ka0s Aura Master**, the page `/am config` opens; no chat line.
   `/am` followed by only spaces, and `/auramaster` → the same. In combat, `/am` → the gray
   "cannot open settings during combat" line `/am config` prints.
6. `/am help` → the version line and the 21-command list; each row is a gold `/am verb`, an em dash
   and a white description.
7. `/am wibble` → the unknown-command line, then the help block.
8. `/am options` → opens the settings (alias of `config`).
9. `/am version` → `v0.1.0`.
10. `/am containers` → one line per container, the selected one marked `>`.
11. `/am new target debuffs icons` → `Created …` naming a target/debuffs/icons container, which appears
    on screen and becomes the selected one. `/am new nonsense` → `Unknown word 'nonsense' …`, nothing
    created.
12. `/am select 1` and `/am select player buffs` (any case) → `Selected …`; `/am select 999` → `No such
    container …`.
13. `/am get container.name` → the selected container's name, with its name annotated in gray;
    `/am set container.layout.scale 1.5` → it grows; `/am reset container.layout.scale` → back;
    `/am list` → every row, `container.` rows annotated.

## C. Unlock, drag, preview

14. `/am unlock` → every container shows a handle with its name and a faint outline one element in
    size; real auras keep drawing. `/am test` → every container fills with placeholder auras and its
    real auras are hidden, the outline giving way to them. The handle is a dark strip with a thin gold edge and a gold label, sitting
    outside the container: above it when the auras grow down, below when they grow up, lined up with
    the edge the first aura starts from. The first bar or icon is fully visible, not under the handle.
    Flip Grow vertically without reloading (Layout → Growth, Down → Up): the bars stack up from the
    anchor, the handle moves below them, and nothing hangs below the anchor; flip it back and they
    stack down again. Grow horizontally (Right → Left) likewise, on an icons container.
    Hovering the strip or the help mark at its right end shows, at the cursor, the name and "Drag to
    move. Right-click for settings.", with no Lua error. Run this after a `/reload` and again after
    Profiles → Reset Profile.
    **Screen edge.** `/am unlock`, drag a container that grows down flush against the top of the
    screen, `/am lock`, then `/am unlock` again → the container shifts down 20px (the handle strip and
    its gap), so the handle stays on screen; `/am lock` → it returns to the edge. Its stored position is the same before and after.
    **Attached container.** Attach one container to another (Layout → Anchor), unlock and `/am test` → the
    attached container's placeholders start one of its own Spacings past the target's last placeholder,
    and its handle sits beside its own first placeholder, on the side away from its growth, covering
    none of the target's placeholders (check 41, SS-3).
15. **Drag** a screen-attached container → it moves and, after `/reload`, stays. A drag that starts on
    the help mark moves it too. Right-click a handle, then its **?** → each time the settings open on
    the **Containers** page with that container selected in the band's picker (feedback #9); in combat
    the right-click prints the gray "cannot open settings during combat" line and changes nothing.
16. `/am test off` → the placeholders go and real auras return; `/am lock` → handles and outlines go.
17. **Test mode has its own switch.** General → Master controls shows a **Test mode** row beside
    Minimap button. `/am test` is listed in `/am help`; `/am preview` → an unknown-command line and
    the help index.
18. **Combat drag.** Unlock, enter combat, try to drag → the container does not move.

## D. Settings panel — every page and tab

19. `/am config` out of combat → Settings opens at **Ka0s Aura Master**: logo, the Notes line, the
    Slash Commands list matching `/am help`, and no tab strip. The tree reads **General ·
    Containers · - Filters · - Layout · - Bars · - Icons · Profiles** — the four container pages
    indented under Containers with a `-` mark, General, Containers and Profiles flush with it (N-2).
20. **General** → the strip **[ Master controls ][ Display ][ Spell Categories ][ Dispel Colors ]**, and no Container picker
    above it. Master controls reads, two per line:
    Enable Aura Master | General visibility / Master scale | Master alpha / Lock frame | Debug console,
    then **Reset position** and **Reset all settings**.
21. Untick **Enable Aura Master** → every container disappears; re-tick → back. Set **General
    visibility** to *Only in combat* → containers hide out of combat and show in combat; *Only out of
    combat* is the reverse; *Never* hides them; *Always* restores. Change these **while in combat** →
    they take effect immediately (visibility is legal in combat).
22. **Master scale** and **Master alpha** → every container scales and fades together, multiplying each
    container's own Layout → Frame scale and opacity.
23. **Containers** (its own top-level page, one tab, **General**) → the band above the tab strip holds the
    Container picker and **New container**, side by side and aligned. In the tab: Name and Enabled,
    then the subsection heading
    **What it shows, and how** with Unit, Aura type and Style under it (batch 8 — there is no heading
    above Name, and the three rows are visibly one block apart from the two), then Duplicate
    and Delete, then (with two or more containers) Copy settings from. Select a container and
    **Delete** it → the picker and New container are still there, and the picker lists what is left.
    **New container** creates a container and selects it. Hover it → its tooltip. The pair is the
    library's page banner with its create button (LibKa0s v1.56.0, AM-17): flip the picker between
    containers 20 times and `/dump collectgarbage("count")` stays flat.
    Rename a container and change its Unit, then press the page's **Defaults** → Enabled, Unit, Aura
    type and Style go back to their defaults and the name stays.
    **Style switch with auras up.** Locked, with live auras in a container, switch its **Style** from
    Bars to Icons, then back to Bars, then to Icons again → each time the elements redraw in the new
    style only: no cooldown swipe or icon border left over a bar, no bar, bar text or background left
    behind an icon, and the bars come back with their fill, name and time text. Watch a few ticks of
    each aura's countdown; a stray swipe can appear late, when the engine next updates the duration.
24. **Filters** → a Container dropdown above the strip. On a buff container the strip is
    **[ General ][ Categories ][ Overrides ][ Sorting ]**, with no Spell lists tab on any aura type
    (batch 8: Overrides sits right after Categories and Sorting is last; the first tab was called
    *What to show* until 2026-09-20). **General** ends with the priority block — heading **Filter
    priority logic**, the lead-in, then the five rank lines — below its own three rows, and neither
    Categories nor Overrides carries a copy of it any more.
    **Categories** opens straight onto two grids,
    **Blizzard Categories** then **Spell Categories** (its last row **Uncategorized**), each headed
    once, with columns **Show · Hide** and the category name (hover it for its description). Click
    **Hide** on a line → that line's cell shows a plain checkbox check and the other goes unlit, and
    `/am get container.filter.categories.<key>` prints `Hide`. Right under the grid sits **Hide
    enchants without a duration**, tied by name to the **Weapon enchants** row above it. On the
    **Spell Categories** grid, click **See spells** on a row → the settings jump to General → Spell
    Categories with that category already selected. Switch the container's aura type to Debuffs →
    **Blizzard Categories**, **Dispel Types**, **Who Cast It** and a **Spell Categories** grid
    holding only its own **Uncategorized** row (no starter list, no See spells link, no line above
    it naming General → Spell Categories); switch to Weapon enchants → the strip becomes
    **[ Categories ][ Sorting ]**, Categories holding only **Hide
    enchants without a duration** and Sorting only **Direction**.
25. **Layout** → **[ Frame ][ Anchor ][ Growth ][ Mouse ]**; Anchor reads **Attach to**, then only
    the subsections that mode uses, and there is no Attach to the screen button (feedback #4). Set
    **Attach to** → *Screen* → only **Screen** is drawn under it, no empty headings; → *Named frame* →
    the tab redraws with **Named frame** (Frame name with **Pick a frame…** beside it) and **Offset**,
    Screen gone; → *Another container* → **Another container** and **Offset**. Then `/am set
    container.attach.mode screen` with the page open → it redraws to Screen alone; `/am get
    container.attach.x` still answers while Offset is hidden.
26. **Bars** → **[ General ][ Background & border ][ Name text ][ Time text ][ Stack text ][ Icon ][
    Pandemic ]** — Icon is second-last, right before Pandemic (2026-09-20). On an icon container
    every tab carries the small gray "Not in use: this container is drawn as icons. Set its Style to Bars on the Containers page to use these settings." note —
    quiet text, not a full-width orange banner, and not larger than the labels under it — a gap below it, and every control dimmed and unclickable; the tabs
    and the Container dropdown still work. **General** opens on its Size subsection (**Width**,
    **Height**) before Fill and Spark. On **Icon** tick **Show border**, set the thickness to 3 →
    a border frames each bar's icon and the art shrinks inside it rather than under it. On **General**
    untick **Show the spark on auras without a duration** → a permanent buff's full bar shows no
    spark, and a timed buff's spark still rides its moving edge, sitting just inside it (the
    in-game check docs/midnight-quirks.md names; if the permanent bar still shows a spark, or the
    timed one loses it, report it). In the preview the "Well Fed" placeholder loses its spark. On
    **Background & border**, Background reads **Background texture** · **Background opacity** /
    **Background color** · **Use class color**; drag **Background opacity** down → the bars'
    background fades while the fill stays as it was.
27. **Icons** → **[ Size ][ Border ][ Cooldown ][ Time text ][ Stack text ][ Pandemic ]**. On
    Cooldown tick **Blizzard countdown numbers** → on a timed aura the countdown and the time text
    read the same whole second throughout, in each time format (both round a fraction up: 12.7 s
    reads 13). Past 90 s the Blizzard format reads minutes, as the game's own buff text does.
28. **The picker is shared.** On Bars → Icon, switch the Container dropdown → the page stays on **Icon**,
    now showing the other container; open Layout → the same container is selected there.
29. Every media dropdown (bar texture, background, border, font) opens with entries in it.

## E. Create, duplicate, delete

30. Containers → **New container** → a player-buff bar container named *Container N* appears, offset
    from the last new one, and is selected.
31. **Duplicate** → a *… (copy)* container with every setting, nudged 20 px; **Delete** → a confirmation
    popup; **Yes** removes it and any container attached to it falls back to the screen. In combat,
    **New container**, **Duplicate** and `/am new` are refused with the gray "cannot create a container
    during combat — it would not be drawn or placed until combat ends" line, and the Delete popup's
    **Yes** and `/am delete` with the gray "cannot delete a container during combat — its display
    cannot be torn down until combat ends" line; nothing is created or removed.
32. **Copy settings from** → pick a source and *Bar style* → the selected container takes only the
    source's bar look; its name and position are unchanged.
33. Rename one on Containers (Enter to apply) → the handle label, every picker and `/am containers`
    show the new name; a blank name is refused.

## F. Filters

34. **Cast by** → *Me (and my pet)* shows only your auras; *Anyone but me* the rest.
35. **Categories.** On a buff container set *Group buffs* to **Hide**, every other category (including
    *Uncategorized*) left at Show → your Mark of the Wild / Arcane Intellect / Battle Shout disappears
    from it, nothing else changes. Now also set
    *Defensive cooldowns* to **Hide** on a defensive cooldown that is ALSO in *Cancelable* (left at Show) → it
    still shows (rank 3: a Show elsewhere rescues it). Set every category to **Hide**, *Uncategorized*
    included, with the Overrides whitelist empty → the container goes empty and shows "These filters
    can never match anything."; set *Defensive cooldowns* back to Show → only defensive cooldowns appear, and
    only those. Now set every category back to Show except *Uncategorized*, which stays Hide → a
    cancelable-but-unlisted buff (one in none of the profile's Spell Categories lists) disappears too,
    even though nothing named it directly.
36. **General → Spell Categories and Dispel Colors.** Untick one starter spell in *Defensive cooldowns*, cast it
    → it no longer shows in any container showing Defensive cooldowns. Type a spell of yours by name into **Add
    a spell** → it is listed with its icon and counts as a defensive; a name that matches nothing adds
    nothing and says why under the box. **Restore this category's starter list** → back to shipped. On
    **Dispel Colors** change *Magic* → a bar colored by dispel type takes the new color; an icon's
    Magic dispel border keeps Blizzard's own blue.
37. **Overrides.** Opens with the same five-rank priority sentence as Categories. Add a buff to the
    *Blacklist* → gone; add a buff to the *Whitelist* by name on a container whose categories exclude
    it → it is listed with its icon and id, and it shows; a name the game does not know → nothing
    added, and the reason under the box. Add the SAME spell id to both lists → the entry on the
    *Blacklist* stays there but the aura shows anyway (the whitelist wins), and a gray note appears
    under the *Blacklist* entry saying so; remove it from the *Whitelist* only → the *Blacklist*
    note disappears and the aura is hidden again. Add to the *Whitelist* a spell every category of
    the container already sets to Hide → a gray note appears under that *Whitelist* entry naming
    the category (or categories) it is overriding.
38. **Max duration** `60` → hour-long buffs disappear, short ones stay, permanent ones go.
39. **Duration → Only auras without a duration** on a player buff container → timed buffs disappear
    out of combat once learned; a brand-new timed buff cast in combat may show once. `/am forgettimed`
    → they reappear until relearned out of combat.
40. **Warnings.** Add a spell to the Overrides *Whitelist* on a *player debuffs* container → the Filters page
    shows the orange "ignored for debuffs on your own character or pet" line. On a *target buffs*
    container → "only apply while the unit is friendly". Set every category to **Hide**, *Defensive cooldowns*
    left at Show, and on General → Spell Categories untick every *Defensive cooldowns* spell (Restore
    afterward) → "These filters can never match anything." (the only group left, Defensive cooldowns' Show
    group, now matches no id at all).

## G. Attach

41. **To a container.** Layout → Anchor → Attach to → *Another container*, pick one → it follows that container
    as it grows and shrinks. Try to attach A to B and B to A → the second is refused. Unlocked and in
    test mode, with B attached to A → B's placeholders start one of B's Spacings past A's last placeholder, below A's block, rather
    than on top of A, and B's handle sits beside B's first placeholder, level with B's top edge, over
    none of A's placeholders (SS-3); `/am test off` → B moves back to one element past A (A's
    outline) while unlocked (check 191), and follows A's real auras again once locked.
42. **To a picked frame.** **Pick a frame…** → the settings close, an outline tracks the named frame
    under the cursor with its name beside it; left-click your player frame → the container attaches to
    it and Layout reopens with the frame name filled in. Repeat and press **Escape** → canceled, Layout
    reopens. `/am pick` does the same from chat. In combat, both are refused with the gray
    "cannot pick a frame during combat — attaching to a frame waits until combat ends" line.
43. **Frame not there yet.** Attach to a frame name belonging to an addon that loads on demand →
    the container sits at its screen position until that addon loads, then moves. Setting **Attach
    to** back to *Screen* detaches it.

## H. Weapon enchants

44. Apply a temporary weapon enchant (an oil, a stone, a poison). The *Player buffs* starter shows it
    after the buffs, because its **Weapon enchants** row on Filters → Categories is Show (the
    default, schema v3). Set that row to **Hide** → the enchant drops out of that container; set it
    back to **Show** → it returns. **Hide enchants without a duration** hides a permanent one.
45. `/am new enchants` → a player buff container named *Container N* whose Filters → Categories are
    all Hide but **Weapon enchants**: it shows your enchants and no buff. The Aura type dropdown on
    Containers offers Buffs and Debuffs only (schema v5, feedback #6).

## I. Combat deferral

46. **Enter combat** (a training dummy) and change a container's bar width or a filter with `/am set`
    (the settings window is locked in combat, item 46a) → chat prints once: `[AM] Aura Master settings
    changes will apply when combat ends.`; nothing changes on screen. Leave combat → the change lands
    with no reload and no error. In combat, `/am lock` and a `/am set` rename print no notice. With a target container's border on class color, target a player
    of another class and pull at once → no notice prints (you changed no setting), and the border
    takes the new class color when combat ends. Repeat inside a Mythic+ key or a boss encounter →
    the change waits until the key or encounter ends, even if you drop combat between pulls. A change
    made out of combat inside the key prints once: `[AM] Aura Master settings changes will apply once
    aura information is available again (after the encounter, key or match).` A change made in combat
    there prints the combat line; nothing more prints the moment combat ends, and the next change
    still held after the pull prints the restriction line once.
47. In combat, `/am config` → refused with the gray "cannot open settings during combat" line; no taint
    warning, and the panel does not pop open when combat ends. `/am resetall`, and a General → **Reset
    all settings** popup opened before the pull and answered **Yes** in combat, reset the profile in
    combat: the acknowledgment prints and no gray line. The button itself, clicked in combat, is
    refused by the settings lock (item 46a). After either reset, or a switch to a profile without one
    of your containers, in combat → that container stops drawing, is torn down when combat ends, and
    no taint warning appears. Point container 1 at focus first: after the reset (or a switch or copy)
    in combat it draws nothing, never focus auras under the reset container's name, and once combat
    ends it draws the new container 1 (player buffs).

46a. **The settings lock (LibKa0s v1.46.1).** Open the settings on a Bars page, then pull a dummy:
    the whole page, the container band and the tab strip included, goes under a gray "Settings are
    locked during combat." cover. Clicking, dragging, typing, a tab, Defaults, Duplicate: nothing
    changes, and one gray `settings are locked during combat — changes are refused until it ends`
    line prints for the whole combat. Switch category in the AddOns sidebar in combat → the new page
    shows covered; no error (`/console scriptErrors 1`), no `ADDON_ACTION_BLOCKED`, and the window
    stays open. Change a value with `/am set` in combat, then leave combat → the covers lift and the
    page shows the new value. A second combat prints the line once more.

## J. Blizzard frames

48. General → Display → **Hide Blizzard buffs** → the default buff frame disappears (with its weapon
    enchants); **Hide Blizzard debuffs** → the default debuff frame goes. Untick → both return. Set one
    in combat with `/am set hideBlizzardBuffs true` (the page itself is locked in combat, item 46a) →
    chat prints `[AM] Aura Master settings changes will apply when combat ends.` once (set the other
    too: still one line), and it applies when combat ends. No taint warnings on any
    of this.

## K. Mouse

49. Hover an aura → its tooltip at the configured position; untick **Tooltips in combat** → none in
    combat. Right-click one of your own buffs in a player-buff container → it is canceled; untick
    **Right-click to cancel** → nothing happens. **Click-through** → no tooltip and clicks pass through.
    **World tooltips (L-3).** Put a bar or icon container over a world unit (an NPC or a player).
    Hover an element → only the aura's tooltip shows, never the unit's tooltip beside it. A unit
    tooltip that was already up when the cursor entered the element fades rather than lingering.
    `/am test` and hover a placeholder over a world unit → no unit tooltip. With **Show tooltips** off or
    **Click-through** on, the hover reaches the world by design → the unit's tooltip shows. A new
    container sits in the **Medium** strata (Layout → Frame → Strata).

## L. Profiles

**The page draws.** Open another addon's options page first, then Aura Master → Profiles → the
AceDBOptions controls render (current profile, New, Copy From, Delete, Reset Profile): never a blank
page under the header.
50. Profiles → create a new profile → the three starter containers appear on it; switch back → your
    own set returns, each where you left it.
51. **Copy** a profile into the active one → its containers replace yours.
52. General → **Reset all settings** → the popup reads *"Reset this profile to the addon's defaults?
    Everything you have configured or added in it is discarded — your other profiles are not
    affected."* → **Yes** → the starter containers, default settings, other profiles untouched. `/am
    resetall` does the same.

## M. Performance and debug

53. `/am perf` → status lines and the step panel. Run a capture as in `docs/perf-analysis/README.md`
    → `/am perf report` prints the summary and the JSON line; containers are hidden during the
    suspended arm and come back after **finish** without a reload.
54. `/am debug` → the debug console opens; the General page's **Debug console** checkbox follows it.
    `/am debug on` → lines such as `[Set] … = …` stream as you change settings; `/am debug off` stops
    them; `/reload` → logging off, window closed. With debug on, each bulk act logs **one** `[Set]`
    line and no per-row lines (debug-logging-§10): the Bars page's **Defaults** → `[Set] reset bars:
    N rows` (0 when nothing was off its default); **Copy settings from** → `[Set] copy container
    A→B (section): N rows`; **Reset position** → `[Set] reset positions: N rows`; **Reset all
    settings** → only `[Set] reset profile 'Default' to defaults`, with no row count, even when
    nothing was off its default; Profiles → **Copy** →
    only `[Set] copied profile 'A' → 'B'`.
55. Memory spot-check: `/run print(collectgarbage("count"))`, change a bar container's bar width 10
    times, then print it again. Note the growth. Style objects are built once per look, so the growth
    should be smaller than on a build from before that change. Record both numbers.

## N. Unit swaps

56. With a target container, change target several times, and target and clear focus with a focus
    container → each shows the new unit's auras at once, never the previous unit's. Summon and dismiss
    a pet with a pet container → it follows.

## O. Master switch from chat

57. Out of combat, `/am disable` → `enabled = false` (gold key, white value: the line `/am get enabled`
    prints, slash-commands-§5's set shape) and every container hides; General → **Enable Aura Master**
    is unticked. `/am enable` → `enabled = true` and every enabled container shows again; `/am unlock`
    and `/am lock` confirm the same way, `locked = false` and `locked = true`. Repeat enable and
    disable **in combat** → the same lines, no
    gray refusal, no "will apply when combat ends" notice and no taint warning; containers stop
    drawing and return at once (the anchors themselves finish hiding when combat ends, step 59).
58. **The disabled addon is inert, not merely blank** (slash-commands-§7). With it disabled: Blizzard's
    own buff and debuff frames come back if you had them hidden; changing target, entering and leaving
    combat and summoning a pet all do nothing at all; `/am` still opens the settings panel and
    `/am list`, `/am get` and `/am set` still read and repair settings; `/am lock` answers
    `Ka0s Aura Master is disabled — enable it with /am enable` on one line; **left-clicking the
    minimap button** still opens the panel, and **right-clicking** it shows Locked and Test mode
    grayed (`(enable the addon first)`) with only Enabled clickable; ticking **General → Master
    controls → Test mode** answers that same one line and the box stays unticked (after
    `/am enable`, the box and the menu's Test mode entry both toggle test mode). Then `/reload` while disabled → it comes up disabled and still answers `/am`,
    and built no container: `/framestack` over the screen shows no `AuraMasterAnchor` frame and
    `/dump AuraMasterAnchor1` is nil. `/am enable` draws every container at once. Switch to another
    profile while disabled and back, then `/am enable` → its containers draw.
59. **Disable it in combat.** Enter combat with containers shown, `/am disable` → the containers'
    engines go quiet at once and the anchors finish hiding when combat ends; no taint warning either
    side of the transition.

## P. Feedback batch 5 checks owed (2026-09-13)

What the headless suite cannot settle from the 2026-09-13 feedback batch
(`docs/superpowers/specs/2026-09-13-feedback-batch5-design.md`). Each item names its requirement
and, where the client source left the answer open, its question in
`docs/superpowers/research/2026-09-13-aura-engine-notes.md`. Some live in the sections above; they are
listed here too, so the batch can be signed off in one pass.

58. **Schema v2 migration (spec section 7).** Back up
    `WTF/Account/ACCOUNT/SavedVariables/AuraMaster.lua` first: a profile loaded once on this build
    cannot go back. On the previous build, in two profiles: untick a starter spell in *Core healing*
    and add a spell to *Lesser healing* on the same container; add a spell to *Defensive cooldowns* on a
    second container; set a bar container's **Color by** to dispel type and change its Magic color;
    leave a container's strata at Medium. Log in on this build → no Lua errors. General → Spell
    Categories lists one *Healing* category (no Core or Lesser healing) holding the added spell, with
    the starter unticked; *Defensive cooldowns* holds the other added spell. Dispel Colors → Magic shows the
    color you set. Layout → Frame → Strata reads High where it was Medium. Switch to the other
    profile → the same.
59. **Color by → dispel type lets go (B-4, question Q1).** On a bar container showing a debuff with a
    dispel type, set Bars → General → **Color by** to dispel type → the fill takes the General → Dispel
    Colors color; set it back to one color → the fill returns to the bar color at once. Enter combat
    with the aura still up → the fill keeps the bar color. The open point is whether a color written
    after the engine's dispel tint holds while auras are secret.
60. **Icon border color (I-1, question Q3).** On an icon container showing a buff, set Icons →
    Border's color to bright red and its thickness to 2 → every icon's border turns red at once. With
    **Dispel border** on, a debuff with a dispel type shows a square edge in Blizzard's dispel color
    over yours, the same shape and thickness; a debuff without one, and every buff, keeps yours. If a border does not change, `/fstack` over
    that icon and report the frame it names.
61. **Icons keep Blizzard's dispel colors; bars take the palette (G-3, owner 2026-09-13).** On
    General → Dispel Colors set Magic to pure red. An icon container with **Dispel border** on,
    showing a Magic debuff → the edge is Blizzard's blue, the same shape as your border. A bar container
    with **Color by** set to dispel type, showing the same debuff → the fill is red. The tab's line
    and each swatch's tooltip say the colors drive bars only.
62. **Countdown and time text agree (I-2, question Q4).** Check 27. Also note the cooldown's own
    number with 12.x s left: 13 means the countdown rounds up, as the time text now does. The notes'
    stronger option, handing the cooldown frame our formatter (`SetCountdownFormatter`), was not
    taken; if the two numbers still disagree by a second, that is the follow-up.
63. **Spark on auras without a duration (B-3, question Q5).** Check 26, which settles three points:
    on a permanent buff the bar's status-bar texture has no width (`/fstack`), so the clipped spark
    is gone; the clip frame hides a spark placed wholly on the elapsed side; a timed bar's spark still
    reads as riding its edge. If the permanent bar still shows its spark with the option off, stop
    and report it to the owner (spec B-3, option 3).
64. **World tooltips (L-3, question Q6).** Check 49's World tooltips paragraph: a live element with
    tooltips on holds the hover, so no unit tooltip appears beside the aura's; a placeholder over a
    unit shows no unit tooltip; a unit tooltip already up fades.
65. **Placeholder time text (B-5, question Q7).** `/am test` on a bar container and switch Time text →
    **Countdown** between Blizzard, short and detailed → the placeholders' time text changes with it
    and reads as a live aura's does in the same format. Tick Pandemic → **Recolor the time in the pandemic window** → the
    *Shield Wall* placeholder (4 s left) takes the pandemic-window time color.
66. **Text justify (B-5).** On Bars → Name text set **Justify** to Right → the name moves to the
    right end of its box and stops short of the time text. On Bars → Time text, with the name shown,
    set **Justify** to Left, then Right → the time moves across a box as wide as its format's longest
    string ("59m"; "23h 59m" in the detailed format), and the name stops short of that box. On Icons →
    Time text set it to Left, then Right → the time text moves across the icon's width.
67. **Inherited flow (L-6).** Attach container B to A (Layout → Anchor → *Another container*) where A
    fills in columns growing down → B continues below A's last element, and the line beside the
    Container dropdown names the points. Set A's **Grow vertically** to up → B moves above A, with
    none of B's own settings changed, and without a reload B's own auras stack up from its first
    element too. On B's Growth tab, Fill, Grow horizontally and Grow vertically
    are dimmed and show A's values under "Fill and growth follow 'A'", while Spacing stays live. Set
    B's **Attach to** back to *Screen* → B's own flow returns. Repeat with an icon A that fills rows
    growing right and down (IA-1) → B starts directly under A's first icon, left edges aligned, and
    the line reads "Attached by its Top left to the Bottom left of 'A'"; give A a **Per row** that
    wraps it → B sits below A's last line; set A's **Grow horizontally** to left → B is right-aligned
    under A (Top right to Bottom right).
68. **Attached handle while unlocked (L-4, SS-3).** Check 41, and check 14's attached-container paragraph.
    **Seam (SS-1, SS-2).** Locked, real auras, B attached to A, A a column growing down: the gap from
    A's last bar to B's first equals the gap between B's bars (2px at Spacing 2, not 4). Set A's
    **Grow vertically** to up → B sits above A with one B Spacing between them and no overlap. Make A
    an icon row growing right → B starts under A, one B **Line spacing** below A's last line. Set B's
    Spacing to 10 → B's inner gaps and the seam change together, and A does not move. B's **Scale**
    1.5 with A at 1 → the seam still equals B's on-screen gap. `/am test` → the seam between the
    placeholders equals the locked one. Set B's **Y offset** to -3 → B drops 3px further (a nudge on
    top). After updating from a build before schema v8, a container that was attached to another with
    the old 0/-4 offsets reads 0/0 on its Layout page; any other offsets are unchanged.
69. **Dimming (L-5, B-2).** Check 25 for the Anchor subsections (now drawn by mode, not dimmed); check
    26 for the Bars page on an icon container, and the Icons page on a bar container the same way.
70. **ID lists take a link (X-1).** On General → Spell Categories click into **Add a spell** and
    shift-click a spell in your spellbook → its link lands in the box; press Enter → the spell is
    added with its icon and name. Do the same on Filters → Overrides → Whitelist. If the shift-click
    goes to the chat box instead, report it: the list reads spell links, but the client decides
    which box a shift-click fills.
71. **Dispel border has the Solid border's shape (batch 8 DB-1, DB-2).** On an icon container
    showing debuffs with a dispel type and one without (Target Debuffs, a Solid 1 px black border),
    with Icons → Border → **Color the border by dispel type** on → each typed icon shows a square
    edge in Blizzard's type color exactly where its neighbors show black: no beveled corners,
    nothing drawn into the icon spacing. Set Border thickness to 4, then 8 → the colored edge always
    matches the black edge's thickness. Turn **Show border** off (or style None) → the typed icons
    still show a 1 px colored edge. Pick a non-Solid border style → the colored edge is flat strips
    at the border's thickness; report whether that looks acceptable. A Bleed debuff: report the color
    Blizzard gives it (it may have none).
72. **Suggestions while typing (#31).** On General → Spell Categories type `rej` into **Add a
    spell** → a dropdown opens under the box listing Rejuvenation with its icon and id, plus any
    matching spell in your spellbook; a spell the client gives a rank shows it ("Rank 2") beside
    the name. Press Down, then Enter → that spell is added once, with its icon and name, and the
    dropdown closes. Type again and click a row instead → the same. Repeat on Filters → Overrides →
    Whitelist.
73. **A name the lists know resolves without the spellbook (#31).** Type the full name of a
    category starter your character does not have (*Ironbark* on a non-druid) and press Enter → it
    is added. Add a spell by id to Filters → Overrides → Blacklist, then type that spell's name on
    General → Spell Categories → it resolves too.
74. **A shared name is refused until picked (#31).** Add two spells that share a name by id to the
    Overrides Whitelist (for example the *Blood Fury* racials 20572 and 33697), then on General →
    Spell Categories type `Blood Fury` and press Enter without picking → nothing is added, the line
    under the box reads "Several spells are named 'Blood Fury' — pick one from the list, or use the
    id.", and the dropdown lists each of them. Pick one → only it is added.
75. **An unknown name says where names come from (#31).** Type a name no list knows and your
    spellbook lacks (`Zzz Spell`) and press Enter → nothing is added, and the line under the box
    reads "No spell named 'Zzz Spell' in your spellbook. Names work for spells in your spellbook and
    ones this list knows; otherwise use the id or shift-click a link." Hover the box → the tooltip
    ends with the same hint, and promises nothing about names the game cannot find.
76. **Gaps between bars no longer leak the world tooltip (L-3, owner report 2026-09-14, B-9).** Put a
    bar container with at least two auras over a world unit (an NPC or a player), with default
    settings (Show tooltips on, Click-through off). Hover a bar → only the aura's tooltip. Hover the
    narrow **gap between two bars**, and separately the container's own **padding** past the last bar
    → in both spots, still only the aura tooltip nearest the cursor (or none, past every bar) — never
    the unit's tooltip drawn alongside it. This is the failure the report's screenshot showed: two
    tooltips side by side. Now turn **Click-through** on for that container and hover the same gap
    again → the unit's tooltip comes back, proving the blocker that closes the gap is gated off, not
    unconditional. Turn Click-through back off, then turn **Show tooltips** off instead and hover the
    gap once more → the unit's tooltip shows there too, for the same reason.
    **Preview is exempt by design.** `/am test` and hover a gap between placeholders
    → the unit's tooltip shows there, same as Click-through. Expected: the blocker is hidden whenever
    the engine is (real auras are hidden while previewing too), so this is not a regression to report.

## Q. Feedback batch 6 checks owed (2026-09-14/15)

Categories became Show/Hide, the priority order was revised mid-batch (rank 3's Show now rescues an
aura from a Hide elsewhere), and a container with anything Hidden compiles to many groups instead of
one. None of this is reproducible headlessly; these checks are.

77. **Group explosion has a real cost, and nothing silently vanishes (spec §6b, `R-4`).** On a
    *player debuffs* container, set exactly one debuff category — say *Dispellable* — to **Hide**
    and leave the other 18 at **Show** → the container now compiles to roughly 17 groups plus a
    catch-all (spec §6b), not one. (16 and 15 when this check was written; issue #11 added *Hard CC*
    and *Soft CC* to the debuff list on 2026-09-20.) Cast or apply enough different debuffs to populate several
    categories at once and confirm **every** one you expect still appears — a debuff in *Dispellable*
    and nothing else disappears, but one in *Dispellable* and also, say, *Boss* still shows (rank 3).
    Nothing is missing, garbled or duplicated. Then `/am perf` a capture over a few seconds with the
    container populated → compare its container-apply bucket against the same container with every
    category left at Show (one group): if the many-group container is dramatically slower per apply,
    or the client silently refuses some of the `AddAuraGroup` calls (a group's auras never draw even
    though its category has live spells), report it — that is the "what does it cost, does the client
    cap groups" open question this batch could not settle offline. Then check the ORDER, not just
    the presence: set Sort by to a method with an obvious visual order (e.g. Time Remaining) and
    confirm the container is no longer sorted end to end — auras are ordered category-block by
    category-block (each Show category's block internally sorted, blocks laid out one after another),
    not as one sorted run across the whole container. This is the sort-row description's own claim
    (Filters → Sorting), so it should read as expected once you know to look for it, not as a bug.
78. **The Hide column reads as live, never dimmed (`K-1`, `R-10`).** On Filters → Categories, look at
    a row currently set to Show → its **Hide** cell must look exactly as clickable as every other
    unlit cell elsewhere in the panel (not grayed out, not lower-contrast) — compare it side by side
    with a genuinely disabled row on the Bars page of an icon container (check 26) to see
    the difference.
    Set **Uncategorized** to **Hide** → every other row's Hide column still looks the same, still
    clickable, on every row, including one already set to Show; click a lit Show cell's Hide → it
    moves there, live, exactly as it did before Uncategorized was touched.
79. **`See spells` lands on the row's own category, not the first one (`F-3`, `K-4`).** On Filters →
    Categories → Spell Categories, click **See spells** on a category that is NOT the first row
    (say *Support* or *Utility*) → General → Spell Categories opens with the tab selected AND that
    same category already chosen in the **Category** dropdown, not defensives or whatever was last
    selected there. Do it again from a DIFFERENT category (say *Racials*) on a different
    container → it lands on Racials, not Support. Click **See spells** on the **Weapon enchants**
    row → it lands on General → Spell Categories with **Weapon enchants** selected, showing the three
    slot toggles, not a spell list.
80. **The priority block reads as one rank per line, once, at the foot of General (`F-4`,
    `P-1`, `T-2`, batch 8).** On Filters → **General**, scroll past Cast by, Duration and Max
    duration → a **Filter priority logic** section heading, the lead-in line ("Highest priority
    first:") and the five numbered rank lines below it → each rank is its own line, none sharing a
    line with another, separated by a hairline gap, no word cut off mid-character, no horizontal
    scrollbar appearing on the tab. The rank lines read at the SAME size as the Whitelist and
    Blacklist notes on the **Overrides** tab — flip between the two tabs and compare (2026-09-20);
    the lead-in is one notch smaller than it was too, and still in the normal font's color. Now open
    **Categories** and **Overrides** → neither carries the lead-in or any rank line; Categories opens straight onto its
    first grid and Overrides onto **Whitelist**. Resize the WoW window narrower (if your UI scale
    allows it) and re-open the tab → each line still wraps cleanly on its own, just onto more
    sub-lines.
81. **The grid cell is a plain checkbox, on both columns (`G-1`, `G-2`).** On Filters → Categories,
    look closely at a lit cell (Show or Hide) → it shows an ordinary checkbox check, the same shape
    and color as every other checkbox in the panel, with no colored fill behind it. Click the other
    cell on the same row → the check moves there in full, the previously-lit cell now shows its plain
    unlit checkbox shape, and at no point are both cells lit or neither lit.
82. **An Overrides entry's note wraps under it, not through it (`K-3`).** Add a spell to the
    Whitelist whose categories are ALL set to Hide, on a container with several categories so the
    note names more than one (a long note, e.g. "Shown here by the whitelist, overriding Defensive cooldowns,
    Cancelable (set to Hide)."). Confirm the note text wraps onto as many lines as it needs directly
    under the entry's name/id, in the existing gray, without overlapping the entry's icon, id, or its
    **Remove** button, and without pushing the NEXT entry's row on top of it.
83. **Every debuff carries `isFromPlayerOrPlayerPet` one way or the other (`docs/schema.md`'s Who
    Cast It grid; the assumption `R-4`'s dropped catch-all depends on).** On a debuff container, set
    BOTH *From players* (`fromPlayers`) and *From non-players* (`fromNonPlayers`) to **Hide** — under
    the current model this drops the debuff catch-all group as a contradiction, since the two
    together are assumed to cover every debuff. Apply a debuff you cast on a training dummy → it
    disappears (claimed by `fromPlayers`'s Hide). Have a pet, NPC, or another player's spell apply a
    DIFFERENT debuff to you or the dummy → it disappears too (claimed by `fromNonPlayers`'s Hide). If
    you can find or produce ANY debuff that still shows with both Hidden, its `isFromPlayerOrPlayerPet`
    is neither true nor false as the engine reports it — report it, since that is exactly the case
    that would make dropping the catch-all here wrong.
84. **The mouse blocker's reach is the whole container, not just the bars (owner report,
    B-9 follow-up).** Anchor a bar container with **Show tooltips** on and Click-through off
    directly over a unit frame, or over open ground you normally mouseover-target through, so its
    padding — not just a bar — sits over the target. Bind a `/tar mouseover` (or similar mouseover)
    macro, or just try to mouseover-target the unit/NPC through the container's padding → it fails
    while the cursor is over the container, including its padding, not only over a bar; moving the
    cursor off the container's rect entirely restores mouseover targeting. This is Layout ->
    Mouse's own documented tradeoff, not a bug — confirm the tab's **Show tooltips** text names it
    and that turning **Click-through** on restores mouseover targeting everywhere under the
    container, padding included.
85. **A timed bar's spark reads the same with the timeless option on or off (owner report
    2026-09-14, batch 7 `SP-1`; re-fixed in feedback batch 8 `SP-1`/`SP-2`).** Put two live, timed auras of the same kind side by side on one bar
    container — say, two casts of the same buff so their sparks share a color and position along the
    bar. On **General** tick **Show the spark on auras without a duration**, screenshot or eyeball
    one bar's spark, then untick it and compare the same bar's spark again → the spark should look
    the same both times (same color, same brightness), not "a random yellow-golden spark" that
    only appears with the option off. This is the half of the check that FAILS if the fix regresses:
    if the two sparks still visibly differ, report it and cite this check. Repeat the on/off
    comparison at a CUSTOM spark color, not the default gold: on Bars → General set **Spark color**
    to something saturated (pure red or pure green) and, separately, something low-alpha (drop the
    color's own alpha to roughly 25%) → the spark must still read the same with the option on and
    off at BOTH custom colors. The spark is additive and desaturated in both modes, so its hue comes
    only from **Spark color** and the two modes differ only in position (centered on the edge when
    ticked, just inside it when unticked); report it and cite this check if either custom color still
    visibly differs between on and off. With the option unticked there must be no dark or black
    rectangle around the spark, and nothing sticking out above or below the bar as a box, at the
    default color, at the low-alpha color and at **Spark width** 32. A black-and-gold box is the
    batch 8 regression (the clipped spark drawn with normal blending, which paints the art's black
    matte); report it and cite this check. Then, without changing anything else, confirm the other half
    still holds — a permanent (no-duration) aura's bar still
    shows NO spark with the option off (check 26/63): if unticking the option makes every spark
    uniform by also restoring the permanent aura's spark, that is a regression of B-3, not a fix of
    this defect, and must also be reported.

## R. The launcher — the minimap button and the broker plugin

Only the client can settle these: the headless suite proves what was handed to the two libraries,
never that the icon file actually draws (a TGA in the wrong format draws **nothing** and raises
nothing).

86. **The AddOns list.** Esc → AddOns (or the character-select AddOns list) → *Ka0s Aura Master*
    shows **the addon's own logo**, not a blank square and not a Blizzard icon.
87. **The button is there.** A round button wearing that same logo sits on the minimap ring. Drag it
    around the ring → it follows; `/reload` → it is still where you left it. **Hover it** → the
    tooltip reads `Ka0s Aura Master  v<the TOC version>`, `Enabled: Yes`, `Locked: Yes|No`,
    `Test mode: On|Off` (green or red, matching General → Master controls), `Left-click: Open
    settings`, `Right-click: Options menu`, and nothing twice. `/am unlock` or `/am test` → the next
    hover says so. `/am disable` → hover again: the tooltip still shows, `Enabled: No`, with the same
    two hints; `/am enable` puts it back.
88. **Left-click = settings.** Left-click the button → Settings opens at **Ka0s Aura Master**, and
    neither the lock nor test mode changes. `/am disable`, left-click again → the panel still opens
    (it is where you turn the addon back on). `/am enable`.
89. **Right-click = the options menu.** Right-click the button → a menu titled **Ka0s Aura Master**
    with exactly three checkboxes, **Enabled**, **Locked**, **Test mode** (no Show window), each
    ticked to match General → Master controls. Click **Test mode** → the menu closes, every container
    shows its placeholder auras, chat prints the line `/am test` prints, and the Test mode checkbox
    ticks; right-click again → Test mode is ticked; click it → they go. Click **Locked** → chat
    prints what `/am unlock` (or `/am lock`) prints and the handles appear (or go). Click **Enabled**
    → chat prints what `/am disable` prints and the containers go. Right-click now → **Locked (enable
    the addon first)** and **Test mode (enable the addon first)** are grayed and do nothing when
    clicked; **Enabled** is live: click it → the addon comes back with the `/am enable` line. In
    combat, click Test mode while it is off → the same combat refusal `/am test` prints.
90. **The checkbox and the button agree, both ways.** Untick General → Master controls → **Minimap
    button** → the button vanishes at once, no reload. Tick it → it comes back **at the same angle**.
    Now hide it from chat instead, `/am set global.minimap.shown false` → reopen the settings and the
    checkbox is unticked too.
91. **It survives a profile switch and BOTH resets.** Hide the button, then Profiles → create and
    switch to a new profile → it stays hidden. Switch back, then General → **Reset all settings** →
    the button stays hidden and the checkbox stays unticked. Now press General's own **Defaults**
    button → still hidden, still unticked, while every other General row on the page goes back to
    its default. Whether the button is shown is a per-installation preference, like the angle you
    dragged it to, so no reset moves it. `/am reset global.minimap.shown` — you naming that one row —
    → it comes back.
    **From chat, in the shown sense:** `/am get global.minimap.shown` → `true` while the button
    shows; `/am set global.minimap.shown false` → the button hides; `/reload` → still hidden;
    `/am reset global.minimap.shown` → it comes back. `/am get global.minimap.hide` → `Setting not
    found` (the storage key is not a path).
92. **A broker display, if one is installed.** With Titan Panel, Bazooka or ElvUI data texts, add
    *Ka0s Aura Master* as a plugin → one row labeled exactly that, **grouped with the other Ka0s
    addons** rather than filed under `A`, the same logo, **no empty value cell beside it**, and its
    left click opens the settings and its right click opens the same three-entry menu as the
    minimap button's.
93. **Without the libraries.** Rename `libs/LibDBIcon-1.0` aside, `/reload` → one chat line naming
    Aura Master and the missing library, **no error frame**, and the addon otherwise works. Rename
    `libs/LibDataBroker-1.1` aside too, `/reload` → the same. Put both back.

## S. The Text style (issue #2)

94. **The default template on player buffs.** Style a player-buff container as Text: names, ` x3`
    stacks and ` - 12s`, all live in combat; a timeless buff shows its name only.
95. **Several durations.** Template `$spellname$ $remainingduration$ / $maxduration$ ($remainingpercent$)`,
    justified Left, then Right: the line reads and lines up both ways.
96. **Dispel type.** `$spellname$[ ($dispeltype$)]` on a target-debuff Text container: correct type
    names; nothing (brackets included) on a typeless debuff.
97. **Loops.** Pulse, Blink and Bounce, each through a pull: no piece overlaps another while it
    animates; a change made in combat starts when combat ends.
98. **The pandemic window.** On the Pandemic tab, Recolor on, then Blink on: the duration run turns the color, then blinks, in the
    last N seconds; the rest of the line keeps the font color.
99. **The icon.** On a new Text container (Icon position None), the Icon tab's rows are dimmed but
    Icon position and the border's color swatch, under a gray "Set Icon position to show the icon."
    (smoke batch 2, item 6). Icon Left → the rows go live and the note goes at once; turn Show border
    on at thickness 2 in red → a red border frames the icon, the art inside it. Then Right, with the
    border: the text starts after the icon and its gap,
    and a long line is cut at its box rather than drawn under the icon. Then, with `/am debug` and
    `/console scriptErrors 1`, and auras showing, change Text settings one after another (font, size,
    template, icon size, the border): every line keeps its text. Rows that go blank, or become empty
    bordered squares, must now come with a `[Style] … failed:` line in the debug console and one Lua
    error naming it; copy both (smoke batch 2, item 7). A refused icon call costs the icon alone,
    the text still drawing.
100. **Refusals.** In the Template box and with `/am set container.text.template $spellname$ $bogus$`
     (no quotes): chat prints `Invalid value for container.text.template` and, indented, the rule
     that broke; the stored template does not change. Try each rule of spec §3.2 once.
101. **Style switching.** A container Bars → Text → Icons → Text, out of combat: each redraws cleanly,
     and Layout → Growth → Fill follows (Columns, Rows, Columns).
102. **Weapon enchants.** An enchant-only buff container (`/am new enchants text`) shows the enchant's name and time.
103. **The Player cooldowns starter.** On a NEW profile, the "Player cooldowns" Text container shows
     an offensive and a defensive cooldown when popped, and nothing else (no food, flask, mount or
     raid buffs).
104. **The pandemic-window blink's feel.** Blink on, no recolor, watch the last seconds: the alpha steps
     in 0.01 s increments with delays under REPEAT, so it reads as a blink, not a flicker or a smooth
     fade.
105. **Nested clipping.** A template wider than the box, on a narrow Text container: the line is cut
     at the box edge, never drawn past it or under a neighboring container.
106. **Dispel type text.** `[$dispeltype$]` on a Bleed debuff and on an Enrage-type buff: Bleed prints
     "Bleed"; check what Enrage's own dispel name actually reads (is it really "Enrage"?) and record
     it.
107. **A Text button built in combat.** With a Text container already up, let it gain a brand-new aura
     mid-fight (one the engine has not drawn before): the new button dresses and animates like every
     other one, with no error.
108. **Icon Left → None live.** On an unlocked, already-dressed Text container showing its icon on the
     Left, switch Icon position to None: the icon disappears cleanly, with no stray icon left behind
     or reappearing on the next aura change.
109. **A literal percent sign.** Template `$remainingduration$ % $maxduration$`: the line shows a
     literal `%` between the two times, not a formatting artifact or an error.
110. **Bracketed stacks.** Template `[[[$stacks$]]]`: on a stacked aura the line reads `[3]` (or
     however many stacks); on a non-stacking aura the brackets do not appear at all.
111. **Unlock keeps live auras.** `/am unlock`: live auras keep drawing, and each container shows an
     outline and its handle; an EMPTY container can still be dragged by its handle.
112. **Test mode.** The Master controls checkbox and `/am test` show placeholders without unlocking.
     Pull a mob: test mode ends and the checkbox unticks. `/am test` in combat prints one gray line
     and starts nothing. The minimap button's right-click menu toggles it.
113. **Spell lists.** General → Spell Categories: an X on the left of every row and no checkboxes.
     X on a starter hides it; Restore, at the top, brings it back. Filters → Overrides lists show
     the X too, and it removes the spell. Check the X row's height and vertical alignment against the
     spell name — the library's Icon widget is 26 px tall.
114. **The "Not in use" notice** heads every tab of Bars, Icons and Text in muted red, not gray, on a
     container drawn in another style.
115. **A 59-minute buff's time on a bar.** A 59-minute Power Word: Fortitude on a default bar reads
     `59 m` in full, not `59...`, and still does with the time text's X offset at -15.
116. **Changing Style resets Fill, keeps grow directions.** On the Containers page switch a
     container's Style: to Icons, Layout → Growth → Fill reads Rows; to Bars or Text, it reads
     Columns. Whatever Grow horizontally/Grow vertically were set to before the switch are unchanged
     by it. `/am new target debuffs icons` makes a container whose Fill reads Rows; `/am new text`
     makes one whose Fill reads Columns.

## T. The smoke-test feedback batch (2026-09-19)

Run with one bar container, one Text container and one icon container on the player's buffs, and a
debuff container on the target, in a party or with a target dummy.

117. **Attached to another frame: no Lua error (E).** Attach a container to another container, then
     one to a named frame (`PlayerFrame`), with `/am unlock` → no Lua error, in or out of combat
     (enable `/console scriptErrors 1`), and each handle's strip is at least as wide as its name, with
     no clipped label on the handle's first show (the detached measurer's first measure may read 0).
     Drag the screen-attached one → it moves and saves; `/reload` → it is where you left it.
118. **Center stacks the pieces (#1).** A Text container, Text → General → Justify Center, template
     Centered: name over time → the spell name sits on one row and the time centered under it, each
     row centered; the container's height grows to hold both, the outline and the handle follow.
     Justify Left → one line again.
119. **The Containers band (#2).** Containers opens with the **Container** picker and **New
     container** side by side above the tab strip, and the first tab is named **General**. New
     container → the new one is selected in the picker; the picker switches the page's subject.
120. **Restore beside the Category dropdown (#3).** General → Spell Categories: **Restore** sits on
     the dropdown's own line, right half; hide a starter spell, Restore → it is back.
121. **TEST on the handle (#8).** `/am test` then `/am unlock` → every handle reads its name, then an
     orange **TEST**; end test mode → the tag goes on the next frame, the strip narrows.
122. **Show all / Hide all (#10).** Filters → Categories: under each grid's heading, **Show all** and
     **Hide all**. Hide all on Spell categories → every row reads Hide, the container empties at once
     (one pass, no flicker per row), and `/am debug` shows one `[Set] hide all …` line, not one per row.
123. **Percent tokens and the `( )` (#5a).** Template `$spellname$ ($remainingpercent$%)` on a 30 s
     buff → `Name (73%)`, a whole number, no space inside the brackets. Now the three probes, one at a
     time, and write down what each prints:
     - `/run local f=C_StringUtil.CreateNumericRuleFormatter() f:SetBreakpoints({{threshold=0,format="%d%%"}}) print("["..f:FormatNumber(45.5).."]","["..f:FormatNumber(45).."]")`
       — H1 (the old rule): `[]` for 45.5 and `[45%]` for 45 confirms it; `[45%]` twice rules it out.
     - `/run local f=C_StringUtil.CreateNumericRuleFormatter() f:SetBreakpoints({{threshold=0,step=1,format="%d"}}) print("["..f:FormatNumber(45.5).."]")`
       — the new rule: `[46]` or `[45]`, never `[]`.
     - `/run local s=UIParent:CreateFontString(nil,"OVERLAY","GameFontNormal") s:SetPoint("CENTER") s:SetText("") print(s:GetWidth(), s:GetStringWidth())`
       — the empty-string gap: a non-zero first number is the space seen between `(` and `)`.
     Then the same template on a buff **without** a duration (a mount, or a permanent aura) → `( )`
     means H2 (the binding's zero-duration text); `[ ($remainingpercent$%)]` shows nothing there.
124. **Built-in templates and the Preview (#5b).** Text → General → **Template**: the list names the
     built-ins (Name, Name + time, …; the debuff container adds Name (type), Name, type, time) and
     **Custom**. Pick each → the read-only **Preview** box under it changes with it and the
     live auras follow; Centered: name over time also sets Justify to Center and previews the
     built-in's own template, `$spellname$[$remainingduration$]` (no separator before the time).
     Custom → the template box appears.
125. **Weapon enchants on a real profile (#6).** On a profile that had a Weapon enchants container
     with an "Always shown" list (back up `WTF/…/SavedVariables/AuraMaster.lua` first): log in → one
     `[Migrate]` line naming the converted container, plus a second `[Migrate]` line for the cleared
     whitelist; the container now reads aura type Buffs, unit Player, with only Weapon enchants shown
     in Filters → Categories, its Overrides list empty, and it still shows your weapon enchant (apply
     one: a sharpening stone, a rogue poison, a shaman imbue) with no "can never match" warning. The
     aura-type dropdown has no Weapon enchants entry; `/am new enchants` makes an enchant-only buff
     container, and `/am test` on it shows exactly as many placeholders as it has enchant slots (one
     per hand, none for an empty slot), not the usual full set.
126. **Bars' background by dispel type (#7).** Bars → Background & border → Color by **Dispel type** on
     a target-debuff bar container: a Magic debuff's background is blue, a Curse's purple; a debuff
     with no type, and an Enrage-type buff (a type the palette does not cover), each keep the
     background's own color. Color by Static → the background color alone, including on an empty
     (currently-unused) button slot that had shown a dispel tint a moment before. General → Dispel
     Colors lists the five types and no None swatch. Back on Dispel type, set Background opacity to
     20% (and separately the background color's own alpha to 50%) → a typed and a typeless debuff's
     background both go see-through, the fill's Bar opacity likewise on Color by Dispel type. Then
     check it **in combat**, a debuff applied after the pull: the background keeps its 20%. If it
     turns opaque in combat only, the engine refused the region alpha (`AddDispelTypeTexture` marks
     the texture's alpha secret) — report it: the fix then moves the background onto its own child
     frame, whose frame alpha carries the opacity (smoke batch 2, item 4).
127. **Right-click the "?" (#9).** `/am unlock`; right-click container 2's handle **?** → the settings
     open on the **Containers** page with container 2 in the band's picker. In combat → the gray
     "cannot open settings during combat" line, nothing opens, the picker is unchanged afterwards.
128. **Switched sections, Aura Master (#4).** Check 25: only the chosen mode's subsections on Layout →
     Anchor, redrawn at once on a change, from the panel and from `/am set`.
129. **Switched sections, Party Frame Enhanced (#4).** That addon's smoke item 31a on its
     `feat/switched-sections` build.
130. **The dispel type word in color (#7).** A Text container on the target's debuffs, template Name,
     type, time; Text → Font → Dispel type → **Color the dispel type** on. A Magic debuff reads
     `Name (Magic) - 12s` with only `Magic` in the Magic color from General → Dispel Colors, the
     brackets and the rest in the font color; a Curse in its color; an Enrage-type buff (a type the
     palette does not cover) keeps the plain font color. Change the Magic swatch → the word
     follows after the re-apply. In combat the word keeps its color as auras come and go (the engine
     writes the text; nothing of ours runs). If the word shows the raw `|cff…` characters instead,
     the engine's options processing stripped the escape: report it (option c then does not work, and
     the toggle is withdrawn). With a template without `$dispeltype$` the toggle is dimmed. The
     Dispel type subsection sits on the Font tab under Countdown, and no longer on Animation (smoke
     batch 2, item 5); toggles set before the move keep their values.
131. **The dispel backdrop (#7).** Same container, **Backdrop in the dispel color** on: a typed debuff's
     line has a Magic-blue (or Curse-purple, …) box behind its text, the text on top and readable; a
     debuff with no type, and an Enrage-type buff, each have no box. **Backdrop opacity** changes its
     strength (dimmed while the backdrop is off). With a text icon on the left, the box covers the text
     area only, not the icon. With Pulse or Bounce on, the box moves and fades with the line. Test
     mode: the Bloodlust placeholder has a Magic box, the others none. Turn the backdrop off → every
     box goes at once, a typed aura included.
132. **The dispel edge (#7).** **Edge in the dispel color** on (backdrop off): a thin outline in the
     type's color around a typed debuff's text area, none on a typeless one and none on an Enrage-type
     buff; **Edge thickness** 1–4 thickens it. Both on at once → the edge draws over the backdrop. On a
     buff container, a Magic buff (Power Word: Fortitude, Arcane Intellect) is outlined too. `/reload`
     and combat: nothing to fix up, no Lua error.
133. **The percent formatter, live (Task 6 carry).** `$remainingpercent$` near a round-number boundary
     (a buff at 99.6% remaining, then watch it tick to 99% and 100%): compare what the live client
     prints against the Text preview's own rounding (`math.floor(v + 0.5)`, no `%`). Report whether the
     live formatter rounds (99.6 → 100) or floors (99.6 → 99); a mismatch between the two is a defect,
     not a matter of taste.
134. **A stacked icon keeps one row's height (Task 8 fix round).** An icon container's own text piece,
     Text → General → Justify Center, a multi-piece template: the rows stack and center exactly as a
     Text container's do, but the icon element itself does NOT grow to fit them — it keeps its
     configured size (icon size 0 included), and a row that does not fit is clipped rather than
     pushing the icon taller. This is the one place `Style.ElementSize` does not add `Text.StackHeight`
     (`modules/Style.lua`, `key == "text"` only).
135. **A migrated Weapon enchants container's Overrides list (Task 9 fix round).** Repeat item 125 on
     a backed-up profile whose Weapon enchants container had spells in Overrides → Always shown: after
     the migration the list reads empty (not just re-filtered to enchants), and the container's compile
     draws no group from a cleared whitelist — only the enchant slots show, matching the aura-type
     switch.
136. **An enchant-only container in test mode (Task 10 fix round).** `/am test` on `/am new enchants`
     (before applying a real enchant): the number of placeholders shown equals the number of enchant
     slots the container can ever draw (one per weapon that can carry an enchant on the player's
     current spec/gear, at most two), never the full generic test-mode set the other aura types show.
137. **Bars: switching dispel color back to static repaints idle slots (Task 11 fix round).** Color by
     Dispel type, let several buttons draw and fade out (so pooled bar frames sit hidden with a stale
     dispel tint on their background texture), then Color by Static: the next auras to use those pooled
     frames show the plain static background immediately, not a leftover dispel tint from before the
     switch.
138. **An out-of-palette dispel type gets no stand-in at all (Task 12 fix round).** With all three of
     Color the dispel type, Backdrop in the dispel color and Edge in the dispel color on together, an
     Enrage-type buff (or any other type General → Dispel Colors does not list a swatch for) shows
     none of the three — plain font color, no backdrop, no edge — the same treatment a typeless aura
     gets, never a blank/invisible stand-in that still reserves space.
139. **The Text Template section, PrettyChat's look (Task 20, owner follow-up).** Text → General: the
     subsection is titled **Text Template**, not "What each line says". Under the Custom template box,
     **Preview** is a disabled EditBox (PrettyChat's own shape), holding the same rendered line the old
     Preview line showed, in the container's font color, with a Task 12 colored dispel word still
     riding live inside it when that option is on. Under it, the cheat sheet reads as two headed,
     bulleted lists with a gap before each heading — **Tokens** (one gold `$token$` bullet per token)
     and **Rules** (bracket hiding, the two escapes, how they combine, text outside `[ ]` always
     showing, a separator inside the brackets of the field it leads), each rule's example on its own indented line in the token gold. On a bars or icons
     container, the "Not in use" notice at the top of every tab (Bars, Icons and Text alike) reads in a
     muted red, not the earlier muted gold. A Center template's Preview shows its stacked rows joined
     by " / " (Centered: name over time reads "Ignore Pain / 11s"), never a raw line break, while the
     live container itself still shows them stacked, each on its own row (final review).
140. **No gap between template pieces (smoke batch 2, item 8).** A target-debuff Text container,
     Justify Left, template
     `$spellname$-$stacks$-$dispeltype$-$remainingduration$-$maxduration$-$elapsedduration$-$remainingpercent$-$elapsedpercent$`,
     on a typed debuff with stacks: the line reads `Fire Breath-3-Magic-6 s-…` with no space either
     side of any `-` wherever the field beside it is non-empty. Then Justify Right: the same, laid from
     the right. A field that is empty (one stack, no dispel type) still leaves its `-` and a small gap:
     rewrite it as `$spellname$[-$stacks$][-$dispeltype$]...` and the empty field's separator goes
     with it. A gap that remains between two non-empty fields is a defect: report the font and size.
141. **The Justify note (smoke batch 2, item 3).** Text → General → Placement: a gray note sits under
     Justify and Vertical justify, above the offsets, on Left, Center and Right alike. It says Center
     centers a one-piece template only, stacks several fields in rows (text outside `[ ]` not drawn,
     the box growing, rows kept when a field is empty, an icon at size 0 one row tall) and that aura
     text is secret so its width cannot be measured. Each of those claims holds on a live container.
142. **Typeless debuffs (smoke batch 2, item 2).** Out of combat, target a dummy carrying your class's
     debuffs (a Paladin's Judgment and Consecration) and run the three `/run` lines in
     `docs/midnight-quirks.md` → "Many debuffs carry no dispel type"; copy the output there. The Bars
     page's Color by tooltips and General → Dispel Colors say buffs and many debuffs have no dispel
     type (Judgment, Consecration), and the Dispel Colors line points at Text → Font.

## U. The smoke-test feedback batch 2 (2026-09-19)

Run with `/console scriptErrors 1` throughout, one bar container on the target's debuffs, one Text
container on the player's buffs (an icon on the left, its border on), one icons container, and one
container attached to `PlayerFrame`, near a target dummy. Where an earlier item already holds the
detail, the step points at it rather than repeating it.

143. **The settings lock covers every page (⚔).** Item 46a first, on a Bars page. Then, one combat
     each (or one long pull), show every page in turn: General, Containers, Layout, Filters, Bars,
     Icons, Text, Profiles and About → each is under the gray "Settings are locked during combat."
     cover, the header band (the Container picker, New container, Duplicate) and the tab strip
     included. On each: a click on a checkbox, a drag of a slider, typing in a box (Template, a
     spell ID), Defaults and a tab click change nothing; the value on screen after combat is the one
     from before the pull. A widget that moves, a tab that switches, or a value that lands after combat
     is a defect.
144. **Switching category in combat (⚔).** With the settings open, pull, then click other Aura Master
     categories (and another addon's) in the Blizzard AddOns sidebar → each shows covered, the window
     stays open, no Lua error, no `ADDON_ACTION_BLOCKED` and no "C stack overflow" in chat or the error
     frame (`scriptErrors 1` stays silent). The gray `settings are locked during combat — changes are
     refused until it ends` line prints **once** per combat however many pages you show or click; a
     second pull prints it once more. Leave combat → the cover lifts on the page you are on, its
     controls work at once, and it shows current values: a value changed with `/am set` during the pull
     (item 46) is shown, with no reload and no re-open. A window that closes itself, or a page that stays
     covered after combat, is a defect.
145. **A Reset-all confirmation open at the pull (⚔, accepted).** General → **Reset all settings**, leave
     the popup up, pull, then **Accept** in combat → the profile resets (item 47: the acknowledgment
     prints, no gray line). The owner accepted this: the popup is Blizzard's, opened before combat, and
     not part of the locked page. Clicking the button itself in combat stays refused (item 46a).
146. **Growth flips without a reload (item 1).** Out of combat, and not in test mode:
     - The screen-attached bar container, Layout → Growth, Grow vertically Down → Up → the bars stack up
       from where the first one sat, nothing hangs below it, the handle (`/am unlock`) moves below the
       block (item 14). Back to Down → they stack down again.
     - The icons container, Grow horizontally Right → Left, then back → likewise, sideways.
     - The container attached to `PlayerFrame`: the same two flips → the first aura keeps its attached
       corner and the others grow the new way.
     - A follower (item 67): container B attached to A; flip A's Grow vertically → B moves to A's other
       side and its own auras follow A's new direction, B's own settings unchanged.
     Every flip shows real auras at once, with no `/reload`. A block that hangs across its anchor until a
     reload is the old bug.
147. **The reworded Point rows and the facing-growth hint (item 1).** Layout → Anchor on the
     `PlayerFrame`-attached container (Attach to: Named frame): Point's tooltip says it is the corner of
     the container's **first aura** that is attached (its full size is secret), Relative point the
     corner of the target that point is attached to. Set Point Bottom left, Grow vertically Down and
     Grow horizontally Right → a hint under the tab's rows reads "Point is Bottom left and Grow
     vertically is Down, so the auras grow back over the frame this container is attached to. Set Grow
     vertically to Up on the Growth tab instead." Point Top left with Up → the same hint, suggesting
     Down; a Left point with Grow horizontally Left (and a Right point with Right) → the horizontal
     hint; Bottom left with Down and Left → both lines, the vertical one first. A pair that does not face
     → no hint, and changing Point or the growth redraws it at once. On Screen and Another container
     there is no hint at all (named-frame mode only); the Screen rows' tooltips speak of the first
     aura too.
148. **Dispel-mode bar opacity (item 4).** Item 126's last paragraph in full: Color by Dispel type,
     Background opacity 20% → a typed (Magic, Curse) and a typeless debuff (a Paladin's Judgment) each
     show a see-through background, and the fill likewise at 20% Bar opacity. Out of combat first; then
     in combat, on debuffs applied after the pull. Report both, and whether the region alpha lands in
     combat: a background that goes opaque in combat only means the engine refused `SetAlpha` on the
     dispel texture (the child-frame fix is then owed).
149. **The Text style's Enrage stays invisible (item 138 carry).** A Text container on the target's
     buffs with Color the dispel type, Backdrop in the dispel color and Edge in the dispel color all on,
     on a mob with an Enrage-type buff (an enraged dungeon mob) → the line has no tint on its type
     word, no backdrop box and no edge, the same as a typeless aura. The code hands the engine a
     transparent color for a type the palette does not cover; a box or edge that shows (white, or any
     color) means the engine dropped that color's alpha: report it, with the mob and the buff's name.
150. **The Text icon and its border (item 6).** Item 99's first paragraph: with Icon position None the
     Icon tab's rows are dimmed under the gray "Set Icon position to show the icon." note, while Icon
     position and the border's color swatch stay live (a color swatch never dims, options-ui-§17). Icon
     Left → the rows go live, the note goes; Show border on, thickness 2, red → a red border frames
     the icon on every line.
151. **The moved Dispel type rows (item 5).** Item 130's last lines: Text → Font carries the Dispel
     type subsection (Color the dispel type, Backdrop in the dispel color, Backdrop opacity, Edge in the
     dispel color, Edge thickness) under Countdown; Text → Animation no longer does; values set before
     the move are kept.
152. **The Justify note (item 3).** Item 141.
153. **Item 7's sequence, instrumented.** `/am debug` and `/console scriptErrors 1`, the Text container
     with its icon on the left and its border on, auras showing. Change Text → General → **Width (px)**
     several times (drag the slider, then type values), then the other Text settings one after another
     as item 99 says → every line keeps its text and its icon. If rows go empty (bordered squares, no
     text), copy the `[Style] … failed:` debug line and the one Lua error that names it, word for word:
     that named line decides the next fix. Rows that go empty with no such line are a defect too:
     report the exact steps.
154. **The owner's all-tokens template (item 8).** Item 140 with the owner's own template, Justify Left
     and then Right → no gap either side of a separator between two non-empty fields. If gaps remain,
     report the font, size and flags: the measured padding came back about 0 (`GetStringWidth` on the
     measurer did not see the padding), so the pull-back did nothing.
155. **The item-2 probe and the Paladin bars.** Item 142: run the three `/run` lines from
     `docs/midnight-quirks.md` → "Many debuffs carry no dispel type" on a dummy carrying a Paladin's
     Judgment and Consecration, out of combat, and copy the output there. Then look at the bar container
     (Color by Dispel type) for those debuffs: the blue is the default fill; say whether the bar's
     **empty part** (its background) is dark or blue. Dark confirms they are typeless (the background
     keeps its own color); blue means the engine reports a type for them, and the probe's `dispelName`
     column should say which.
156. **The Pandemic tab (B2-1).** Bars, Icons and Text each draw a **Pandemic** tab: Bars and Icons
     last (**Highlights** is gone), Text between Icon and Animation. On Bars and Icons it holds two
     subsections, **Time color** (Recolor the time in the pandemic window, Pandemic window (seconds
     left), Pandemic-window time color) and **Highlight** (Highlight the pandemic window,
     Pandemic-window highlight color); on Text, Time color with those three and Blink in the pandemic
     window, and the gray "The pandemic window needs a duration token, such as $remainingduration$, in
     the template." note under them on a template without one. Text → Animation now holds the Loop
     rows alone. Hover each row: no tooltip says "running out" or "refresh window". Values set before
     the rename are kept (a threshold of 8 still reads 8), and `/am list` still names the same paths.
157. **The container pickers sort by name (B2-2).** Name three containers "zeta", "Alpha" and "beta"
     (Containers → Name). The Container dropdown in the band of Containers, Filters, Layout, Bars,
     Icons and Text lists Alpha, beta, zeta — capitals do not sort first — each still followed by its
     gray "(unit, aura type, style)"; Containers → Copy settings from's source and Layout → Anchor →
     Another container (None first) list in the same order. `/am containers` keeps the creation order.
158. **The owner's repro: an icon border and the pandemic settings (B2-3).** `/console scriptErrors 1`,
     an Icons container with auras showing, Icons → Border → Show border on (Solid, thickness 2). Then,
     out of combat, change Icons → Pandemic one row at a time: Highlight the pandemic window off and on,
     the highlight color, Recolor the time in the pandemic window, the window's seconds → **no Lua
     error** (none naming `Backdrop.lua`), the border keeps drawing, and an aura inside its pandemic
     window still highlights and recolors its time. Repeat with the border off: the same.
159. **A Text icon border and Width (B2-3).** The Text container with Icon position Left and its icon
     border on (thickness 2, red). Change Text → General → **Width (px)** several times, by slider and
     typed → every line keeps its text, its icon and the red border; no empty rows, no `[Style] text
     icon failed` debug line, no Lua error.
160. **A bar border (B2-3).** A bar container with Background & border → Show border on, and Icon →
     Icon border on. Change the bar's Width, then its Pandemic rows → both borders keep drawing at their
     thickness and color, no Lua error, and the pandemic highlight still shows.
161. **A border style other than Solid (B2-3).** On any of the three, pick another Border style (a
     media pack's edge, or "Blizzard Tooltip") → no Lua error; the preview (test mode) draws it at once,
     while the aura buttons already on screen keep their old look until `/reload`, then draw it. Change
     its color → the live buttons recolor at once. Hover Border style: the tooltip says Solid redraws at
     once and any other texture after a `/reload`. Back to Solid → the strips draw at once and no
     texture edge is left under them.
162. **The outline and the handle on an attached container (follow-up).** `/console scriptErrors 1`.
     Attach a container to another frame (Layout → Anchor → Another container, or a frame picked with
     the frame picker, an aura container of another addon if one is at hand), then `/am unlock`. Change
     that container's Width and its growth direction, and move the container it is attached to → **no
     Lua error** (none naming `Backdrop.lua`), and the outline and the handle look as before: a faint
     1px white outline one element in size at the corner the flow starts from, and a dark strip with a
     1px gold edge, the gold name label (with the orange TEST tag in test mode) and the "?" mark at its
     far end. Right-click the strip → the Containers page opens on that container; a screen-attached
     container still drags by it. While picking a frame, move the cursor across several frames,
     aura buttons included → the blue 2px outline follows each, no Lua error.
163. **General → Dispel Colors reads as a list (2026-09-20).** General → **Dispel Colors** → above the
     five swatches, "One color per dispel type, shared by every container:" on its own line, then three
     lines each opening with "- ": where the colors are read (bars by dispel type, and a text line's
     dispel type word, backdrop or edge), what has no dispel type and how that looks, and that an icon's
     dispel border keeps Blizzard's own colors. No wall of prose, a hairline gap between the bullets, no
     bullet sharing a line with another, and nothing cut off or scrolling sideways.
164. **General → Spell Categories is split in two (2026-09-20).** General → **Spell Categories** → the
     Category dropdown and its **Restore this category's starter list** button, then a **Spells in this
     category** section heading with the library's own rule under it, and only then the **Add a spell**
     box and the list of spells. Pick **Weapon enchants** → the three slot toggles, and NO "Spells in
     this category" heading (there is no spell list to head).
165. **The Text page's Text Template block dims with the page (2026-09-20).** Select a container drawn
     as **bars** and open **Text** → the "Not in use: this container is drawn as bars." note, every
     control dimmed. Now look at the **Text Template** subsection: the **Preview** line, the **Tokens**
     and **Rules** headings, every bullet and every gold example are all gray, the same gray as the
     Placement note under Justify — nothing in the block is brighter than the dimmed controls around
     it. Switch the container's Style to **Text** on the Containers page and come back → the Preview is
     in the container's own font color again, the tokens and examples in gold, the headings bright.
166. **Spell category lists read alphabetically, and three categories are renamed (2026-09-20).**
     General → **Spell Categories** → the **Category** dropdown now offers **Defensive cooldowns**,
     **Hard CC (loss of control)** and **Soft CC (roots & snares)** — the parentheses and the `&`
     render as written, in the dropdown, in its tooltip and on Filters → Categories, with no stray
     escape. Pick **Soft CC (roots & snares)** → the spells read in name order (Chains of Ice,
     Concussive Shot, Crippling Poison, … ), NOT Frost Nova (122) first. Add a spell of your own by
     name → it lands in the alphabet among the starters, not at the bottom of the list. Any id the
     client cannot name shows as "Unknown spell <id>" at the very END of the list, and the order does
     not visibly shuffle a second after the tab opens. Pick **Hard CC (loss of control)** → **Wake of
     Ashes is absent**, and it is absent from Soft CC too; cast it on a target with a Hard CC
     container up → nothing is drawn for it.

## V. Categories you make (issue #10, 2026-09-21)

Run with `/console scriptErrors 1`, one player-buff bar container and one target-debuff container up,
near a target dummy. Steps 167–177 run in order: each uses the category the one before it made.

167. **Make one.** General → **Spell Categories** → under **Make a new category**, type `Cooldowns I
     watch`, leave **Aura type** on *Buffs*, click **Create category** → the **Category** dropdown
     jumps to the new entry, reading **[Buffs] Cooldowns I watch (yours)** — `[Buffs]` in muted
     green, `(yours)` in muted gold — and a line under the **Rename this category** box and in chat
     says it was created, empty, and where to set it to Show or Hide. The list below is empty, and
     there is **no Restore this category's starter list** button on the picker's line. No Lua error.
168. **It is a real category everywhere.** Filters → **Categories** on the buff container → the
     **Spell Categories** grid holds a **Cooldowns I watch (yours)** row, with Show lit, sitting
     *after* the shipped spell lists and *above* **Weapon enchants** and **Uncategorized** —
     Uncategorized is still the last row of the grid. `/am list` shows the row (its label with no
     `(yours)` on it), and `/am get container.filter.categories.user…` answers **Show**. On the debuff
     container's Categories tab the row is absent, which is right: the category holds buffs.
169. **It filters.** Put a buff you can cast on yourself into it (General → Spell Categories → **Add a
     spell**, by name or id). On the buff container set every other category to **Hide** (Hide all on
     both sections, then set this one back to Show) → cast the buff → it is drawn, and your other
     buffs are not. Set the category to **Hide** and leave Uncategorized Hidden → the buff goes.
170. **The overlap mark, on the row and in the tooltip.** Add a spell that is already in a shipped
     category of the same aura type (Power Word: Shield, in *Defensive cooldowns*, works) → one chat
     line naming the other category and saying an aura in two categories is drawn once, under the
     first of them a container sets to Show. **The row form:** that entry reads
     `(X) [icon] Power Word: Shield (17) (also in 1)` — the count in the same gray as the id, ON the
     entry's own line, with the entry beside it still sharing the row (a claimed entry does not push
     its neighbor down). **The tooltip:** hover the entry → the client's spell tooltip, with
     **Also in: Defensive cooldowns** added under it. Open *Defensive cooldowns* in the dropdown →
     that same spell reads `(also in 1)` there, and its tooltip says **Also in: Cooldowns I watch
     (yours)** — the marker is on both surfaces. Nothing was refused: the spell is in both.
     **Expected degradation:** on a very long name at a narrow panel the `(also in N)` is cut off the
     end of the row (the library truncates the suffix first, then the id, then the name) — the
     tooltip still names the categories. Widen the settings window and it comes back.
170a. **The rename and the Delete sit directly under the picker** (owner, 2026-09-21), with no
     heading between them and the **Category** dropdown, and **Make a new category** below them: the
     tab reads picker → rename and Delete → create form → **Spells in this category**. Each block is
     separated by the gap under it, not by a heading over the acts.
170b. **The add box suggests from the spellbook as well as from our own lists** (LibKa0s v1.49.1;
     the tooltip above no longer costs this). In **Add a spell** type the name of a spell that is in
     one of Aura Master's lists → it is suggested as you type, and Enter adds it. Now type the name
     of a spell you know but that is on NO list of this addon → **it is suggested too**, with its
     rank where the client gives one, and clicking the row adds it. Its id and a shift-clicked link
     still work. A name no spell carries is still refused with
     "No spell named '…' in your spellbook."
171. **Rename it.** In **Rename this category**, type `Big cooldowns` and press **Enter** → the
     dropdown, the rename box, the Filters grid and `/am list` all read the new name, the box is no
     longer holding what you typed but what is stored, and the answer line says it was renamed and
     names the OLD name to type back. The spells are all still there, and the Filters row's Show or
     Hide is unchanged — a rename must never reset it.
172. **A shipped category draws nothing about itself** (owner, 2026-09-21). Pick **Healing** in the
     dropdown → between the picker and **Make a new category** there is **no name box, no Delete, no
     heading and no sentence** — the picker line, then the create form. **Restore this category's
     starter list** is back on the picker's line and works. Pick **Weapon enchants** → the lead-in
     above the picker still says it matches temporary enchants and there is nothing to add or remove,
     a **Weapon slots** heading sits over the three slot toggles, and the toggles sit under THAT
     heading rather than under **Make a new category**.
173. **The answer line knows what it is about.** With a line showing under the rename box, switch
     the dropdown to another category → the line is gone. Say something again (rename, or a refused
     empty name), then close the settings window and reopen it on the same tab → the line is gone.
     Say something again, then Profiles → switch profile → come back → the line is gone. Hopping to
     General's **Display** tab and back deliberately KEEPS it — the panel never left the screen.
174. **An empty or duplicate name.** Clear the rename box and press Enter → a line saying a category
     needs a name, and the box snaps back to the stored name. Create a second category with a name you
     already used → both are kept, and the line says so — they are separate categories with separate
     spell lists. The dropdown shows two entries reading the same.
175. **Delete it, with what that costs said first.** Pick the second category, **Delete this
     category** → the confirmation names it and says the spell list goes, every container in every
     profile forgets whether it showed or hid it, and anything it was hiding becomes visible again
     through Uncategorized. **No** → nothing changes. **Yes** → the tab shows another category, a line
     says which one was deleted and that the tab has moved, the Filters grid no longer holds the row,
     `/am get` on its old path answers that the setting is unknown, and no Lua error.
176. **A deleted category stops filtering.** Before deleting the first one, set it to **Show** on the
     buff container with every other category Hidden, and confirm the buff in it is drawn. Delete the
     category → the buff container redraws: the aura is no longer drawn by that category, and it comes
     back only through **Uncategorized** if that is set to Show. `/reload` → it stays gone, the
     dropdown does not list it, and the Filters grid has no row for it.
177. **They belong to the profile.** Make a category, then Profiles → create and switch to a second
     profile → the dropdown does not list it, and the Filters grid has no row for it. Switch back →
     it is there, with its spells and its Show or Hide. `/reload` on each profile → no Lua error, and
     no `/am list` row for a category the loaded profile does not have.


## W. The id has to be the aura's (issue #15, 2026-09-21)

Run with `/console scriptErrors 1`. Steps 178–184 cover the add box; 185 is the temporary probe, and
it is the one that needs you rather than the suite.

**What this is about.** Aura Master filters on the id an *aura* carries. Many abilities are cast as
one id and land as another — Renewing Mist is cast as `115151` and lands as `119611`. Typing a name
gets you the id the client knows, which is the cast's, so the entry draws perfectly and matches
nothing. Nothing in the client can answer the mapping, so the addon carries it in
`defaults/CastToAura.lua`.

178. **A spell the data resolves.** General → **Spell Categories**, pick any category, and add
     **Corruption** by name or as `172`. → The entry appears as **146739**, not 172, and chat says
     *"Corruption (172) is cast, but the aura it applies is … — added 146739 instead, which is what
     the filter can match."* The swap is never silent.
179. **A spell it cannot resolve.** Add **Renewing Mist**, or `115151`. → The entry is stored
     **exactly as typed** — still 115151 — and chat lists the candidates: *"115151 never appears as
     an aura, so this entry will match nothing. Auras with that name: 119611, 144080, 448430,
     1238851, 1242480. Add the one you meant."* It does **not** pick one for you.
180. **Then pick one.** Add `119611` → it goes in silently, as an ordinary id. Remove 115151.
181. **It never refuses.** Add a made-up id, say `999999` → it is added, with nothing said. An id
     the table has never heard of is not an id the addon may reject; a boss aura the generator has
     never seen has to be enterable.
182. **The note on an entry already stored.** With 115151 still in a list, reopen the panel → its
     row carries a **gray second line** naming the candidate auras. A noted entry takes a full-width
     row of its own, so it breaks the two-column grid for that row — that is the library's rule for
     notes and is expected.
183. **The hint.** Hover the **Add a spell** box → the tooltip says *"The id has to be the one the
     AURA carries, which is not always the one you cast."* before the usual sentence about where a
     name can come from.
184. **The Overrides lists take the same path.** Filters → **Overrides** → add `115151` to the
     whitelist → the same chat line. If that id also has a verdict note, the two are joined, with
     the never-matches sentence first.

185. **The four corrected shipped ids.** Five ids in the shipped lists were the CAST, not the aura,
     and none could be fixed from the data — not one has an `EffectTriggerSpell` edge. A temporary
     `/am probe` settled four against a live client on 2026-09-21 and was then deleted. Confirm each
     now matches:

     * **Levitate** on yourself → a container covering *Utility* shows it. (`1706` → `111759`)
     * **Fear** on the dummy → a *Hard CC* debuff container shows it. (`5782` → `118699`)
     * **Spirit Link Totem**, standing in it → the container covering it shows it. (`98007` → `325174`)
     * **Ursol's Vortex**, dummy inside it → a *Soft CC* container shows it. (`102793` → `127797`)

     **`35546` Fatal Flourish is knowingly still the cast id** and matches nothing. It applies no
     aura, has no trigger edge, and the probe found nothing to observe — it reads as a proc that
     fires and vanishes. Left in place so the record that the slow exists is not lost. If you ever
     see a lasting Fatal Flourish debuff on a target, note its id and it can be settled.

## X. Test mode previews debuffs (batch 8 item 4, owner to run)

186. **Each container previews its own kind.** `/am test` on the default profile → *Player debuffs*
     and *Target debuffs (mine)* show Shadow Word: Pain, Hex, Frost Fever, Deadly Poison (3 stacks),
     Rupture (running out, 4 s) and Mortal Wounds (no timer), each with its real icon and no
     question-mark icon. *Player buffs* still shows Power Word: Fortitude, Bloodlust, Shield Wall,
     Ignore Pain and Well Fed.
187. **The icon dispel border.** An icons debuff container with Border → **Color the border by
     dispel type** on → a square edge in Blizzard's color, the same shape as the Solid border, on
     SW:P (Magic), Hex (Curse), Frost Fever (Disease), Deadly Poison (Poison) and Rupture (Bleed, if
     the client gives it a color), and none on Mortal Wounds. Turn it off → every one goes at once. An icons buff container never shows
     one, Bloodlust included.
188. **Bars colored by dispel type.** A bars debuff container with **Color by** dispel type → each
     bar takes its type's color from General → Dispel Colors, and Mortal Wounds keeps the bar color.
     Change the Poison swatch → the Deadly Poison bar recolors while test mode is on. On a buff
     container only Bloodlust is Magic-colored and the others keep the bar color (before this every
     bar was Magic). Repeat with the background's color set to dispel type.
189. **Text.** A Text debuff container on the name, type, time template with the dispel backdrop and
     edge on → each line shows its type word, tinted when **Color the dispel type** is on; Mortal
     Wounds shows no type and no tint.
190. **Switching kind while previewing.** Switch a container's **Shows** between Buffs and Debuffs in
     test mode → the placeholders swap without a `/reload`, and a container attached to it still sits
     just past the last placeholder (six for debuffs, five for buffs). **Max auras** 3 on a debuff
     container → only SW:P, Hex and Frost Fever.

## Y. Empty unlocked chains (batch 8 item 9, owner to run)

191. **An empty chain unlocked.** Chain three Text containers (B attached to A, C attached to B),
     none with a matching aura. `/am unlock` with test mode off → each faint outline sits in its own
     slot under the one before, one Spacing apart (a few pixels more between B and C, so B's strip
     clears C's); A's strip sits above A, B's and C's beside their own outlines, and no strip covers
     another strip or another container's outline. Before this every link sat about 5px under the
     last, the strips and outlines piled together.
192. **Lock and unlock.** Same chain, `/am lock` → nothing shows (all empty) and there is no Lua
     error. Give A real auras while locked → B starts one Spacing past A's last aura (check 41
     unchanged). Unlock with A holding two or more auras → B moves up to one element past A's first
     aura, and A's later auras draw under B (known limitation); `/am lock` → B jumps back past A's
     last aura.
193. **Test mode.** Unlocked, `/am test` → B's placeholders start past A's placeholder block (L-4),
     and the strips still do not overlap. `/am test` off while still unlocked → B returns to one
     element past A, with no error.
194. **Drag and reload.** Drag A while unlocked → B and C follow. `/reload` → the positions persist and
     the chain re-forms the same way.
195. **Other shapes.** An Icons chain → B's outline sits one icon plus B's Line spacing under A's
     first icon. A chain growing up → B sits above A, its strip beside it, clear of A's outline.
196. **Combat.** Unlocked, enter combat and `/am lock` → nothing re-anchors in combat, and there is no
     ADDON_ACTION_BLOCKED or taint report. Leave combat → the followers snap onto the engines.

## Z. Feedback batch 8 sign-off (2026-09-25, owner to run)

The in-game checks for every item of feedback batch 8
(`docs/superpowers/specs/2026-09-25-feedback-batch8-design.md`). None of them has been run: each is
for the owner, and none is marked passed here. Items already covered by a check above point at it;
the rest are new below. Run on a build carrying schema v8, and once on a copy of a pre-v8
SavedVariables file for the migration lines.

| Item | Requirement | Check |
|---|---|---|
| #1 spark | SP-1, SP-2 | 85 |
| #3 close mark | CX-1..CX-3 | 197-199 |
| #4 test-mode debuffs | TD-1..TD-4 | 186-190 |
| #7 Size to fit | AS-1..AS-3 | 200-202 |
| #8 name label | NL-1..NL-4 | 203-205 |
| #9 empty unlocked chains | EO-1, EO-2 | 191-196 |
| #10 dispel border shape | DB-1, DB-2 | 71 (and 60, 61, 187) |
| #11 icon attach points | IA-1, IA-2 | 67 |
| #13 seam spacing | SS-1..SS-3 | 68 (and 14, 41) |
| #16 `/am diagnostics` | DG-1..DG-4 | 206-209 |

**Owner run, 2026-09-25.** Everything passed except the items below. Those go to feedback batch 9,
on the same branch.

| Item | Checks | Result |
|---|---|---|
| #1 spark | 85 | pass |
| #3 close mark | 197-199 | pass |
| #4 test-mode debuffs | 186-190 | pass |
| #8 name label | 203-205 | pass (the tab is renamed Label; batch 9 adds a Justify option) |
| #10 dispel border shape | 71 | pass |
| #7 Size to fit | 200-202 | **fail**: live auras longer than the samples are clipped (202's stated limit is rejected), test-mode columns misalign after a width change or Size to fit, and existing Text containers were not stamped off |
| #9, #11, #13 attached containers | 191-196, 67, 68 | **fail**: an attached child's strip sits beside the parent's first element, so the child reads as attached elsewhere and its test-mode auras read as the parent's. Batch 9 reworks attach points so they can be chosen |
| #16 `/am diagnostics` | 206-209 | **fail**: out of combat, every container's plan and shown sections error on a secret boolean compare (`Diagnostics.lua:453`) |

197. **The X on the strip (CX-1, CX-3).** `/am unlock` → every container's strip shows a gray X
     immediately left of the **?**, the same size, turning white on hover; the name stays centered
     and does not run under the X, even for a long name with the orange TEST tag in test mode.
     Hover the X → the tooltip names the container and says a click disables it, its settings are
     kept, and Enabled on the Containers page brings it back. No "Anchoring disallowed" error,
     including on a container attached to another.
198. **Click it (CX-3).** Left-click the X → that container's auras, placeholders, outline and strip
     disappear, nothing else changes, and one chat line names it and says how to bring it back.
     Containers page with that container selected → **Enabled** is unticked; tick it → the container
     and its strip return at the same stored position. With the Containers page already open on it,
     click its X → the checkbox unticks live. Close a container others are attached to → the
     followers re-place exactly as when Enabled is unticked in the panel.
199. **What the X does not do.** Right-click on the strip and on the **?** still opens the Containers
     page; a left-drag on the strip or the **?** still moves the container; a left-drag that starts
     on the X moves nothing, and releasing off the X does not disable it. In combat, unlocked at a
     target dummy, click an X → the container hides with no Lua error, no taint and no
     ADDON_ACTION_BLOCKED. A container flush against the screen edge on its strip's side is pushed in
     a little further than before while unlocked (the wider strip) and returns on `/am lock`.
200. **Size to fit, migrated and new (AS-1, AS-3).** On a profile made before this build, every
     Text container keeps its width and height and **Size to fit** is unticked on its Text page. Tick it
     → the box resizes at once and the handle and outline follow; Width and Height gray out with the
     note under them, and their tooltips say why. A new profile's *Player cooldowns* starter has it
     ticked, and a container made in an existing profile and set to Text has it ticked too.
201. **It follows the content (AS-2).** With it on, change the font size, the template, the countdown
     format, Icon Left with size 24, and Justify Center with a three-field template → each resizes the
     box. Icon size 0 with Bounce → neither the icon nor the text is cut at the right, and at Justify
     vertical Middle or Bottom the bounce is not cut at the top (Top still is, as before). A long-lived
     aura (hours or days) shows its whole time string.
202. **Its limits (AS-2).** A live buff with a name longer than the samples (Incarnation: Chosen of
     Elune) is cut at the box edge and never overlaps its neighbor. In combat gain and lose auras →
     no error and the size does not change; tick Size to fit in combat → it applies after combat.
     With a SharedMedia font, log in → at worst one apply at the stored size, then sized to fit; no
     lasting wrong size. Chain two Text containers, the first empty, unlocked, with Size to fit on and
     off → the strips and outlines never overlap (check 191).
203. **The name label, locked (NL-1, NL-2, NL-4).** Layout → **Label**, tick **Show name label**
     on *Player buffs* while locked → its name appears in gold Friz 12 just above its first element
     (growing down), left-aligned, and nothing else moves. Grow vertically Up → the label moves below
     the first element; Grow horizontally Left → it right-aligns. X/Y offsets and every font leaf
     (face, size, flags, shadow, color) apply live; with Show off the offsets and the font rows are
     grayed, but the color swatch is not.
204. **Unlocked, both show (NL-3, D6).** `/am unlock` → the label stays, and the drag strip sits
     past it on the same side, by the label's height plus the strip gap, never covering it;
     `/am lock` → the strip goes and the label stays where it was. `/am test` locked and unlocked →
     the placeholders, the label and (unlocked) the strip with its TEST tag, none overlapping. A
     container attached to another with its label on → the label sits beside its first element,
     level with its top and right-aligned against it, over none of the parent's elements, and the
     strip (unlocked) sits past the label along the growth (below it growing down); note anything
     else the label runs over, which the offsets fix.
205. **The label with the rest (NL-1, NL-4).** Rename the container, in combat too → the label
     changes at once. On a target container with the label's class color on, target a warrior then
     a mage → the color follows; an NPC falls back to the swatch. Scale 2.0, Opacity 0.5 and Master
     alpha → the label scales and fades with the container. Visibility *Out of combat only* → entering
     combat hides container and label together; no ADDON_ACTION_BLOCKED. `/am disable` hides it and
     `/am enable` brings it back; deleting the container removes it. Containers → Copy settings from,
     What = *Label* → the label settings copy and the name does not. Flush against the top edge
     with the label above → note whether it is cut off (it is not clamped, a known limitation).
206. **`/am diagnostics` out of combat (DG-1, DG-2).** With a target, a focus and a pet,
     `/am diagnostics` → the console opens, one chat line gives the line count, and the report runs
     from the begin marker to the end marker. Its `[Aura]` names and stacks match Blizzard's own buff
     and debuff frames; every container has its `[Cont]`, `[Filt]` and `[Plan]` lines. Press **Copy**
     → the text has no color codes; paste it into a file and check nothing is cut off. Whitelist a
     spell whose buff is up → `[Shown]` lists a button and `predicted:` reads shown (rank 1); record
     whether the button line carries the aura's inst/id or only its name or icon.
207. **In combat and while disabled (DG-1, DG-3).** In combat on a dummy, `/am diagnostics` → no Lua
     error, the units read unreadable, `[Cont]`, `[Filt]` and `[Plan]` still print, `frames=` is a
     number or `?`, `shown=?`, and no `[Shown]` button lines. Change a container's Cast by in combat
     and run it again → that container reads PENDING (combat); after combat → plan in sync.
     `/am disable`, then `/am diagnostics` and `/am debug diagnostics` → each still runs and the
     state line reads enabled=false.
208. **Caps and the old verbs (DG-4).** With about eight containers and a long whitelist → the report
     stays under the cap or ends with a `truncated` line, and the console never holds more than 1500
     lines. Bare `/am debug` still toggles the window, `/am debug on` and `off` still switch logging,
     and `/am help` shows `diagnostics` right after `debug`, with a `debug` row that no longer
     mentions diag.
209. **The two forms, and no `diag` (DG-1 as amended 2026-09-25).** `/am debug on`, reproduce
     anything, then `/am diagnostics` → the report appends after the trace lines, so one **Copy**
     carries both. `/am debug diagnostics` → the same report again. `/am debug diag` → no report:
     the console window just toggles, like any other unknown word after `debug`.
