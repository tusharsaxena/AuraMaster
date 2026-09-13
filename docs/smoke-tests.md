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
    **Attached container.** Attach one container to another (Layout page) and unlock → the attached
    container's handle sits outside its own edge and may lie over the target's elements or handle.
    This is expected (Known Limitations).
15. **Drag** a screen-attached container → it moves and, after `/reload`, stays. A drag that starts on
    the help mark moves it too. Right-click a handle → the settings open with that container selected.
16. `/am lock` → handles and placeholders go; real auras return.
17. `/am test` → placeholders without handles; `/am test off` → gone. `/am test on` then
    `/reload` → preview is off again. `/am preview` → an unknown-command line and the help index.
18. **Combat drag.** Unlock, enter combat, try to drag → the container does not move.

## D. Settings panel — every page and tab

19. `/am config` out of combat → Settings opens at **Ka0s Aura Master**: logo, the Notes line, the
    Slash Commands list matching `/am help`, and no tab strip.
20. **General** → the strip **[ Master controls ][ Display ][ Containers ]**, and no Container picker
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
    show ][ Categories ][ Sorting ][ Spell lists ][ Always / never ]**; switch the container's aura type
    to Debuffs → **Spell lists** disappears and Categories offers the debuff categories; switch to
    Weapon enchants → only **What to show** and **Sorting**, one row each.
25. **Layout** → **[ Position ][ Growth ][ Frame ][ Mouse ]**; Position ends with **Pick a frame…** and
    **Attach to the screen**.
26. **Bars** → **[ Size ][ Bar ][ Background & border ][ Name text ][ Time text ][ Stack text ][
    Highlights ]**. On an icon container every tab carries the orange "drawn as icons" notice. On
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
33. Rename one on the General tab (Enter to apply) → the handle label, every picker and `/am containers`
    show the new name; a blank name is refused.

## F. Filters

34. **Cast by** → *Me (and my pet)* shows only your auras; *Anyone but me* the rest.
35. **Categories.** On a buff container set *Defensives* to **Show** → only defensive cooldowns appear;
    also set *Offensive cooldowns* to **Show** → both, each aura once. Set *Consumables* to **Hide** on
    a neutral container → your flask disappears from it.
36. **Spell lists.** Untick one starter spell in *Defensives*, cast it → it no longer shows in that
    container. **Add spell ID** with a spell of yours → it counts as a defensive. **Restore this
    category's starter list** → back to shipped.
37. **Always / never.** Add a buff to *Never show* → gone; add a buff to *Always show* on a container
    whose categories exclude it → it shows; the same id on both lists → hidden.
38. **Max duration** `60` → hour-long buffs disappear, short ones stay, permanent ones go.
39. **Duration → Only auras without a duration** on a player buff container → timed buffs disappear
    out of combat once learned; a brand-new timed buff cast in combat may show once. `/am forgettimed`
    → they reappear until relearned out of combat.
40. **Warnings.** Set a spell list or always list on a *player debuffs* container → the Filters page
    shows the orange "ignored for debuffs on your own character or pet" line. On a *target buffs*
    container → "only apply while the unit is friendly". Show a spell category with every spell
    unticked and nothing else → "These filters can never match anything."

## G. Attach

41. **To a container.** Layout → Attach to → *Another container*, pick one → it follows that container
    as it grows and shrinks. Try to attach A to B and B to A → the second is refused.
42. **To a picked frame.** **Pick a frame…** → the settings close, an outline tracks the named frame
    under the cursor with its name beside it; left-click your player frame → the container attaches to
    it and Layout reopens with the frame name filled in. Repeat and press **Escape** → canceled, Layout
    reopens. `/am pick` does the same from chat. In combat, both are refused with the gray
    "cannot pick a frame during combat — attaching to a frame waits until combat ends" line.
43. **Frame not there yet.** Attach to a frame name belonging to an addon that loads on demand →
    the container sits at its screen position until that addon loads, then moves. **Attach to the
    screen** detaches it.

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
