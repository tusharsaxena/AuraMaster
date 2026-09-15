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

5. `/am` → the version line and the 22-command list. `/auramaster` → identical.
6. `/am help` → each row is a gold `/am verb`, an em dash and a white description.
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

14. `/am unlock` → every container shows a handle with its name and fills with placeholder auras;
    real auras are hidden. The handle is a dark strip with a thin gold edge and a gold label, sitting
    outside the container: above it when the auras grow down, below when they grow up, lined up with
    the edge the first aura starts from. The first bar or icon is fully visible, not under the handle.
    Hovering the strip or the help mark at its right end shows, at the cursor, the name and "Drag to
    move. Right-click for settings.", with no Lua error. Run this after a `/reload` and again after
    Profiles → Reset Profile.
    **Screen edge.** `/am unlock`, drag a container that grows down flush against the top of the
    screen, `/am lock`, then `/am unlock` again → the container shifts down 20px (the handle strip and
    its gap), so the handle stays on screen; `/am lock` → it returns to the edge. Its stored position is the same before and after.
    **Attached container.** Attach one container to another (Layout → Anchor) and unlock → the
    attached container's placeholders start just past the target's last placeholder, and its handle
    draws above the target's placeholders (check 41).
15. **Drag** a screen-attached container → it moves and, after `/reload`, stays. A drag that starts on
    the help mark moves it too. Right-click a handle → the settings open with that container selected.
16. `/am lock` → handles and placeholders go; real auras return.
17. `/am test` → placeholders without handles; `/am test off` → gone. `/am test on` then
    `/reload` → preview is off again. `/am preview` → an unknown-command line and the help index.
18. **Combat drag.** Unlock, enter combat, try to drag → the container does not move.

## D. Settings panel — every page and tab

19. `/am config` out of combat → Settings opens at **Ka0s Aura Master**: logo, the Notes line, the
    Slash Commands list matching `/am help`, and no tab strip.
20. **General** → the strip **[ Master controls ][ Display ][ Containers ][ Spell Categories ][ Dispel Colors ]**, and no Container picker
    above it. Master controls reads, two per line:
    Enable Aura Master | General visibility / Master scale | Master alpha / Lock frame | Debug console,
    then **Reset position** and **Reset all settings**.
21. Untick **Enable Aura Master** → every container disappears; re-tick → back. Set **General
    visibility** to *Only in combat* → containers hide out of combat and show in combat; *Only out of
    combat* is the reverse; *Never* hides them; *Always* restores. Change these **while in combat** →
    they take effect immediately (visibility is legal in combat).
22. **Master scale** and **Master alpha** → every container scales and fades together, multiplying each
    container's own Layout → Frame scale and opacity.
23. **General → Containers** → the tab body's first line holds the Container picker and **New
    container**, side by side and aligned. Below: Name, Enabled, Unit, Aura type, Style, then Duplicate
    and Delete, then (with two or more containers) Copy settings from. Select a container and
    **Delete** it → the picker and New container are still there, and the picker lists what is left.
    Rename a container and change its Unit, then press the page's **Defaults** → Enabled, Unit, Aura
    type and Style go back to their defaults and the name stays.
    **Style switch with auras up.** Locked, with live auras in a container, switch its **Style** from
    Bars to Icons, then back to Bars, then to Icons again → each time the elements redraw in the new
    style only: no cooldown swipe or icon border left over a bar, no bar, bar text or background left
    behind an icon, and the bars come back with their fill, name and time text. Watch a few ticks of
    each aura's countdown; a stray swipe can appear late, when the engine next updates the duration.
24. **Filters** → a Container dropdown above the strip. On a buff container the strip is **[ What to
    show ][ Categories ][ Sorting ][ Overrides ]**, with no Spell lists tab on any aura type.
    **Categories** opens with the five-rank priority sentence, then **Only these categories**, then
    two grids, **Blizzard Categories** then **Spell Categories**, each headed once, with columns
    **Show · Hide** and the category name (hover it for its description). Click **Hide** on a line →
    that line's cell lights solid yellow and the other goes dark, and
    `/am get container.filter.categories.<key>` prints `Hide`. On the **Spell Categories** grid,
    click **See spells** on a row → the settings jump to General → Spell Categories with that
    category already selected. Switch the container's aura type to Debuffs → **Blizzard
    Categories**, **Dispel Types** and **Who Cast It** (no Spell Categories grid); switch to Weapon
    enchants → the strip becomes **[ Categories ][ Sorting ]**, Categories holding only **Hide
    enchants without a duration** and Sorting only **Direction**.
25. **Layout** → **[ Frame ][ Anchor ][ Growth ][ Mouse ]**; Anchor reads **Attach to**, then
    **Screen**, **Another container**, **Named frame** (Frame name with **Pick a frame…** beside it)
    and **Offset**, and there is no Attach to the screen button. Set **Attach to** → *Screen* → every
    row but Screen's is dimmed; → *Named frame* → Named frame and Offset light up and Screen dims on
    the same frame; → *Another container* → Another container and Offset are live.
26. **Bars** → **[ Size ][ Bar ][ Icon ][ Background & border ][ Name text ][ Time text ][ Stack text ][
    Highlights ]**. On an icon container every tab carries the large orange "drawn as icons" notice
    naming General → Containers, a gap below it, and every control dimmed and unclickable; the tabs
    and the Container dropdown still work. On **Icon** tick **Show border**, set the thickness to 3 →
    a border frames each bar's icon and the art shrinks inside it rather than under it. On **Bar**
    untick **Show the spark on auras without a duration** → a permanent buff's full bar shows no
    spark, and a timed buff's spark still rides its moving edge, sitting just inside it (the
    in-game check docs/midnight-quirks.md names; if the permanent bar still shows a spark, or the
    timed one loses it, report it). In the preview the "Well Fed" placeholder loses its spark. On
    **Background & border**, Background reads **Background texture** · **Background opacity** /
    **Background color** · **Use class color**; drag **Background opacity** down → the bars'
    background fades while the fill stays as it was.
27. **Icons** → **[ Size ][ Border ][ Cooldown ][ Time text ][ Stack text ][ Highlights ]**. On
    Cooldown tick **Blizzard countdown numbers** → on a timed aura the countdown and the time text
    read the same whole second throughout, in each time format (both round a fraction up: 12.7 s
    reads 13). Past 90 s the Blizzard format reads minutes, as the game's own buff text does.
28. **The picker is shared.** On Bars → Bar, switch the Container dropdown → the page stays on **Bar**,
    now showing the other container; open Layout → the same container is selected there.
29. Every media dropdown (bar texture, background, border, font) opens with entries in it.

## E. Create, duplicate, delete

30. General → Containers → **New container** → a player-buff bar container named *Container N* appears, offset
    from the last new one, and is selected.
31. **Duplicate** → a *… (copy)* container with every setting, nudged 20 px; **Delete** → a confirmation
    popup; **Yes** removes it and any container attached to it falls back to the screen. In combat,
    **New container**, **Duplicate** and `/am new` are refused with the gray "cannot create a container
    during combat — it would not be drawn or placed until combat ends" line, and the Delete popup's
    **Yes** and `/am delete` with the gray "cannot delete a container during combat — its display
    cannot be torn down until combat ends" line; nothing is created or removed.
32. **Copy settings from** → pick a source and *Bar style* → the selected container takes only the
    source's bar look; its name and position are unchanged.
33. Rename one on General → Containers (Enter to apply) → the handle label, every picker and `/am containers`
    show the new name; a blank name is refused.

## F. Filters

34. **Cast by** → *Me (and my pet)* shows only your auras; *Anyone but me* the rest.
35. **Categories.** On a buff container set *Consumables* to **Hide**, every other category left at
    Show → your flask disappears from it, nothing else changes. Now also set *Defensives* to
    **Hide** on a defensive cooldown that is ALSO in *Cancelable* (left at Show) → it still shows
    (rank 3: a Show elsewhere rescues it). Turn on **Only these categories** with nothing set to
    Show and the Overrides whitelist empty → the container goes empty and shows the "Only the
    categories set to Show are drawn, and no category is set to Show." warning; set *Defensives*
    back to Show → only defensive cooldowns appear, and only those.
36. **General → Spell Categories and Dispel Colors.** Untick one starter spell in *Defensives*, cast it
    → it no longer shows in any container showing Defensives. Type a spell of yours by name into **Add
    a spell** → it is listed with its icon and counts as a defensive; a name that matches nothing adds
    nothing and says why under the box. **Restore this category's starter list** → back to shipped. On
    **Dispel Colors** change *Magic* → a bar colored by dispel type takes the new color; an icon's
    Magic dispel border keeps Blizzard's own blue art.
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
    container → "only apply while the unit is friendly". Turn on **Only these categories**, leave
    *Defensives* the only category set to Show, and on General → Spell Categories untick every
    *Defensives* spell (Restore afterward) → "These filters can never match anything.", distinct from
    check 35's "Only the categories set to Show are drawn, and no category is set to Show." (that one
    fires when nothing at all is Shown; this one when what's Shown is an empty list).

## G. Attach

41. **To a container.** Layout → Anchor → Attach to → *Another container*, pick one → it follows that container
    as it grows and shrinks. Try to attach A to B and B to A → the second is refused. Unlocked, with
    B attached to A → B's placeholders start just past A's last placeholder rather than on top of A,
    and B's handle draws above A's placeholders; `/am lock` → B follows A's real auras again.
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
    after the buffs (**Also show weapon enchants** is on there). A container with aura type *Weapon
    enchants* shows it too. **Hide enchants without a duration** hides a permanent one.
45. Set a weapon-enchant container's unit to *target* → the Filters page warns that enchants are always
    the player's, and it still shows yours.

## I. Combat deferral

46. **Enter combat** (a training dummy) and change a container's bar width or a filter → chat prints
    once: `[AM] Aura Master settings changes will apply when combat ends.`; nothing changes on screen.
    Leave combat → the change lands with no reload and no error. In combat, `/am lock`, `/am test`
    and a rename print no notice. With a target container's border on class color, target a player
    of another class and pull at once → no notice prints (you changed no setting), and the border
    takes the new class color when combat ends. Repeat inside a Mythic+ key or a boss encounter →
    the change waits until the key or encounter ends, even if you drop combat between pulls. A change
    made out of combat inside the key prints once: `[AM] Aura Master settings changes will apply once
    aura information is available again (after the encounter, key or match).` A change made in combat
    there prints the combat line; nothing more prints the moment combat ends, and the next change
    still held after the pull prints the restriction line once.
47. In combat, `/am config` → refused with the gray "cannot open settings during combat" line; no taint
    warning, and the panel does not pop open when combat ends. `/am resetall`, and General → **Reset
    all settings** → **Yes**, reset the profile in combat just as Profiles → Reset Profile does: the
    acknowledgment prints and no gray line. After either reset, or a switch to a profile without one
    of your containers, in combat → that container stops drawing, is torn down when combat ends, and
    no taint warning appears. Point container 1 at focus first: after the reset (or a switch or copy)
    in combat it draws nothing, never focus auras under the reset container's name, and once combat
    ends it draws the new container 1 (player buffs).

## J. Blizzard frames

48. General → Display → **Hide Blizzard buffs** → the default buff frame disappears (with its weapon
    enchants); **Hide Blizzard debuffs** → the default debuff frame goes. Untick → both return. Tick one
    in combat → chat prints `[AM] Aura Master settings changes will apply when combat ends.` once
    (tick the other too: still one line), and it applies when combat ends. No taint warnings on any
    of this.

## K. Mouse

49. Hover an aura → its tooltip at the configured position; untick **Tooltips in combat** → none in
    combat. Right-click one of your own buffs in a player-buff container → it is canceled; untick
    **Right-click to cancel** → nothing happens. **Click-through** → no tooltip and clicks pass through.
    **World tooltips (L-3).** Put a bar or icon container over a world unit (an NPC or a player).
    Hover an element → only the aura's tooltip shows, never the unit's tooltip beside it. A unit
    tooltip that was already up when the cursor entered the element fades rather than lingering.
    Unlock and hover a placeholder over a world unit → no unit tooltip. With **Show tooltips** off or
    **Click-through** on, the hover reaches the world by design → the unit's tooltip shows. A new
    container sits in the **High** strata (Layout → Frame → Strata).

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

57. Out of combat, `/am disable` → `Aura Master disabled — /am enable turns it back on` and every
    container hides; General → **Enable Aura Master** is unticked. `/am enable` → `Aura Master
    enabled` and every enabled container shows again. Repeat both **in combat** → the same lines, no
    gray refusal, no "will apply when combat ends" notice and no taint warning; containers hide and
    return at once.

## P. Feedback batch 5 checks owed (2026-09-13)

What the headless suite cannot settle from the 2026-09-13 feedback batch
(`docs/superpowers/specs/2026-09-13-feedback-batch5-design.md`). Each item names its requirement
and, where the client source left the answer open, its question in
`docs/superpowers/research/2026-09-13-aura-engine-notes.md`. Some live in the sections above; they are
listed here too, so the batch can be signed off in one pass.

58. **Schema v2 migration (spec section 7).** Back up
    `WTF/Account/ACCOUNT/SavedVariables/AuraMaster.lua` first: a profile loaded once on this build
    cannot go back. On the previous build, in two profiles: untick a starter spell in *Core healing*
    and add a spell to *Lesser healing* on the same container; add a spell to *Defensives* on a
    second container; set a bar container's **Color by** to dispel type and change its Magic color;
    leave a container's strata at Medium. Log in on this build → no Lua errors. General → Spell
    Categories lists one *Healing* category (no Core or Lesser healing) holding the added spell, with
    the starter unticked; *Defensives* holds the other added spell. Dispel Colors → Magic shows the
    color you set. Layout → Frame → Strata reads High where it was Medium. Switch to the other
    profile → the same.
59. **Color by → dispel type lets go (B-4, question Q1).** On a bar container showing a debuff with a
    dispel type, set Bars → Bar → **Color by** to dispel type → the fill takes the General → Dispel
    Colors color; set it back to one color → the fill returns to the bar color at once. Enter combat
    with the aura still up → the fill keeps the bar color. The open point is whether a color written
    after the engine's dispel tint holds while auras are secret.
60. **Icon border color (I-1, question Q3).** On an icon container showing a buff, set Icons →
    Border's color to bright red and its thickness to 2 → every icon's border turns red at once. With
    **Dispel border** on, a debuff with a dispel type shows Blizzard's colored border art over yours;
    a debuff without one, and every buff, keeps yours. If a border does not change, `/fstack` over
    that icon and report the frame it names.
61. **Icons keep Blizzard's dispel art; bars take the colors (G-3, owner 2026-09-13).** On
    General → Dispel Colors set Magic to pure red. An icon container with **Dispel border** on,
    showing a Magic debuff → the border is Blizzard's stock blue Magic art, untinted. A bar container
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
65. **Placeholder time text (B-5, question Q7).** Unlock a bar container and switch Time text →
    **Countdown** between Blizzard, short and detailed → the placeholders' time text changes with it
    and reads as a live aura's does in the same format. Tick Highlights → **Running out** → the
    *Shield Wall* placeholder (4 s left) takes the running-out color.
66. **Text justify (B-5).** On Bars → Name text set **Justify** to Right → the name moves to the
    right end of its box and stops short of the time text. On Bars → Time text, with the name shown,
    set **Justify** to Left, then Right → the time moves across a box as wide as its format's longest
    string ("59m"; "23h 59m" in the detailed format), and the name stops short of that box. On Icons →
    Time text set it to Left, then Right → the time text moves across the icon's width.
67. **Inherited flow (L-6).** Attach container B to A (Layout → Anchor → *Another container*) where A
    fills in columns growing down → B continues below A's last element, and the line beside the
    Container dropdown names the points. Set A's **Grow vertically** to up → B moves above A, with
    none of B's own settings changed. On B's Growth tab, Fill, Grow horizontally and Grow vertically
    are dimmed and show A's values under "Fill and growth follow 'A'", while Spacing stays live. Set
    B's **Attach to** back to *Screen* → B's own flow returns.
68. **Attached handle while unlocked (L-4).** Check 41, and check 14's attached-container paragraph.
69. **Dimming (L-5, B-2).** Check 25 for the Anchor subsections; check 26 for the Bars page on an icon
    container, and the Icons page on a bar container the same way.
70. **ID lists take a link (X-1).** On General → Spell Categories click into **Add a spell** and
    shift-click a spell in your spellbook → its link lands in the box; press Enter → the spell is
    added with its icon and name. Do the same on Filters → Overrides → Whitelist. If the shift-click
    goes to the chat box instead, report it: the list reads spell links, but the client decides
    which box a shift-click fills.
71. **Dispel border sits on the icon's edge (owner report 2026-09-13).** On an icon container
    showing debuffs with a dispel type (your own DoTs on a target), with Icons → Border →
    **Color the border by dispel type** on → Blizzard's colored border art frames each icon at its
    edge, with no second ring inside the icon's art. The art reaches a sixth of the icon past each
    edge, as Blizzard's buff frame sizes it; if the ring lands a pixel in or out, report which.
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
    **Preview is exempt by design.** `/am unlock` (or `/am test`) and hover a gap between placeholders
    → the unit's tooltip shows there, same as Click-through. Expected: the blocker is hidden whenever
    the engine is (real auras are hidden while previewing too), so this is not a regression to report.

## Q. Feedback batch 6 checks owed (2026-09-14/15)

Categories became Show/Hide, the priority order was revised mid-batch (rank 3's Show now rescues an
aura from a Hide elsewhere), and a container with anything Hidden compiles to many groups instead of
one. None of this is reproducible headlessly; these checks are.

77. **Group explosion has a real cost, and nothing silently vanishes (spec §6b, `R-4`).** On a
    *player debuffs* container, set exactly one debuff category — say *Dispellable* — to **Hide**
    and leave the other 15 at **Show** → the container now compiles to roughly 15 groups plus a
    catch-all (spec §6b), not one. Cast or apply enough different debuffs to populate several
    categories at once and confirm **every** one you expect still appears — a debuff in *Dispellable*
    and nothing else disappears, but one in *Dispellable* and also, say, *Boss* still shows (rank 3).
    Nothing is missing, garbled or duplicated. Then `/am perf` a capture over a few seconds with the
    container populated → compare its container-apply bucket against the same container with every
    category left at Show (one group): if the many-group container is dramatically slower per apply,
    or the client silently refuses some of the `AddAuraGroup` calls (a group's auras never draw even
    though its category has live spells), report it — that is the "what does it cost, does the client
    cap groups" open question this batch could not settle offline.
78. **The Hide column reads as live, never dimmed (`K-1`, `R-10`).** On Filters → Categories, look at
    a row currently set to Show → its **Hide** cell must look exactly as clickable as every other
    unlit cell elsewhere in the panel (not grayed out, not lower-contrast) — compare it side by side
    with a genuinely disabled row on Layout → Anchor (a mode's dimmed fields) to see the difference.
    Turn **Only these categories** on → the Hide column still looks the same, still clickable, on
    every row, including one already set to Show; click a lit Show cell's Hide → it moves there, live,
    exactly as it did with the toggle off.
79. **`See spells` lands on the row's own category, not the first one (`F-3`, `K-4`).** On Filters →
    Categories → Spell Categories, click **See spells** on a category that is NOT the first row
    (say *Support* or *Utility*) → General → Spell Categories opens with the tab selected AND that
    same category already chosen in the **Category** dropdown, not defensives or whatever was last
    selected there. Do it again from a DIFFERENT category (say *Consumables*) on a different
    container → it lands on Consumables, not Support. Click **See spells** on the **Weapon enchants**
    row → it lands on General → Spell Categories with **Weapon enchants** selected, showing the three
    slot toggles, not a spell list.
80. **The priority blurb wraps readably (`F-4`, `P-1`).** At the top of both Filters → Categories and
    Filters → Overrides, read the full five-clause priority sentence at the panel's normal width →
    every clause is fully visible, wrapped onto as many lines as it needs with no word cut off
    mid-character, no horizontal scrollbar appearing on the tab, and no overlap with the row or grid
    drawn immediately below it. Resize the WoW window narrower (if your UI scale allows it) and
    re-open the tab → it still wraps cleanly, just onto more lines.
81. **The yellow fill matches its cell, on both columns (`K-1`).** On Filters → Categories, look
    closely at a lit cell (Show or Hide) → the solid yellow fill sits inside the cell's own
    checkbox-shaped border with no gap around its edges and no bleed into the neighboring column or
    the category label. Click the other cell on the same row → the yellow fill moves there in full,
    the previously-lit cell now shows its plain unlit checkbox shape, and at no point are both cells
    lit or neither lit.
82. **An Overrides entry's note wraps under it, not through it (`K-3`).** Add a spell to the
    Whitelist whose categories are ALL set to Hide, on a container with several categories so the
    note names more than one (a long note, e.g. "Shown here by the whitelist, overriding Defensives,
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
