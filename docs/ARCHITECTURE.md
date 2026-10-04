# Architecture — Ka0s Aura Master

The engineer's hub for this addon. Each mandated section summarizes and links out; the detail lives
in the topic docs registered under [Documentation map](#documentation-map) (documentation-§3).

## Overview

Ka0s Aura Master draws player-built aura **containers**. A container is one unit (`player`,
`target`, `focus`, `pet` — `core/Constants.lua:39`), one aura type (`HELPFUL` or `HARMFUL` — `:45`;
the player's temporary weapon enchants are the buff category `weaponEnchants`, schema v5) and one style (`bars`, `icons` or
`text` — `:49`), plus its filters, placement and look. A profile holds any number of them; a fresh
profile is seeded with four (`NS.STARTER_CONTAINERS`, `defaults/Profile.lua:294`).

**The design is dictated by one client fact.** On Retail 12.1 an addon cannot read aura data while
auras are secret — combat, encounters, Mythic+ and PvP (`core/Secrets.lua`, `docs/midnight-quirks.md`).
So this addon reads no aura at all. Every container is a Blizzard **AuraContainer**
(`CreateFrame("AuraContainer", nil, anchor, "CustomAuraContainerTemplate")`,
`modules/Container.lua:391`) that registers `UNIT_AURA` for its unit, gathers, sorts, lays out and
animates its buttons in Blizzard's own code. The addon's job is to **declare** what each container
shows and **dress** each button the engine creates:

```
settings row ─► NS.SetByPath ─► CONFIG_CHANGED ─► ContainerManager.RequestApply (next frame, coalesced)
   ─► wait while auras are secret or combat lockdown is on
   ─► Container:Apply ─► FilterCompiler.Compile ─► aura groups + candidate filters
   ─► build the engine (new shape) or update it in place (same shape)
   ─► engine creates buttons ─► initializeFrame ─► Style.Element dresses them ─► engine renders
```

There is therefore **no per-aura Lua path while auras are secret**: no timer and no `OnUpdate`
driving a bar. There are two aura-driven Lua paths, both only out of combat with auras readable:
the readable-state timed-spell scan (`modules/TimedSpells.lua`), bracketed `timedScan`, which runs
only while a container shows auras without a duration; and the empty-container prediction
(`modules/EmptyWatch.lua`), bracketed `emptyPass`, which runs only while containers are unlocked and
out of test mode. The full pipeline is in `docs/data-flow.md`.

### Libraries

Everything is vendored under `libs/`: LibStub and CallbackHandler, the Ace3 stack, LibSharedMedia,
the optional LibDataBroker and LibDBIcon, and LibKa0s with fourteen modules bound by name, every
one of which degrades to a stub or a fallback when the library is absent. What each library is used for, and
what each LibKa0s setup file publishes: `docs/module-map.md` → *Libraries*.

## Module Map

Five source folders in the TOC's load order — `locales/` → `core/` → `defaults/` → `modules/` →
`settings/` (layout-§1) — 58 authored Lua files under them: one locale, 16 core, 4 defaults, 22
modules and 15 settings. The load-bearing positions are annotated at their TOC lines:
`core/MediaSetup.lua` before `core/Constants.lua` (the monospace face), `core/CoreSetup.lua` before
anything that prints, `core/PerfSetup.lua` before every module that takes `NS.Perf` as an upvalue,
`defaults/Categories.lua` before `defaults/Profile.lua` (the template's category states) and
`defaults/UserCategories.lua` directly after it (the `NS.Categories` upvalue),
`modules/Anchors_Attach.lua` before `modules/Anchors.lua` (which binds `NS.AnchorsAttach` at file load),
`modules/Anchors_Tooltip.lua` before `modules/Anchors.lua` (which binds `NS.AnchorsTooltip.Place` at file
load as the strip's `tooltipPlace`),
`modules/Anchors_SnapRect.lua` after `modules/Anchors_Attach.lua` (it binds `FlowGrowth` at file load) and
before `modules/Anchors_Snap.lua`,
`modules/Anchors_Snap.lua` after all three (it binds `NS.AnchorsAttach`'s pair table and
`NS.AnchorsSnapRect` at file load and extends `Anchors` as `Anchors.Snap`),
`settings/OptionsSetup.lua` before every page file (the composers run at file load), and
`settings/GeneralUserCategories.lua` (read by `settings/GeneralSpells.lua` at file load), then
`settings/GeneralSpells.lua`, then `settings/GeneralDispel.lua` (which reads its bullet constants), all
before `settings/General.lua`, which registers their rows after its own.
The Settings tree's order is the TOC's own registration order: General, then Containers, then Profiles. Filters, Layout, Bars, Icons and Text are sections of the Containers page (#6) with no tree entry; they load after `settings/OptionsSetup.lua` in any order, and the rail's order is `SECTION_ORDER` there.

The engine-facing core is four modules: `modules/FilterCompiler.lua` (settings → groups, pure; the
profile's spell-category edits reach it through `FC.ProfileContext`, and each group's blizzard view comes
from `modules/FilterViews.lua`), `modules/Container.lua` (one
engine), `modules/ContainerManager.lua` (the registry and the deferred apply, each container's apply
guarded so one error cannot drop the rest of the pass) and `modules/Style.lua` with its three style
files (`Style_Bars.lua`, `Style_Icons.lua` and `Style_Text.lua`, chosen per container by
`Style.Styler`), plus the pure template parser the Text style draws from
(`modules/TextTemplate.lua`). Placement is `modules/Anchors.lua`, with how a follower joins its parent in
`modules/Anchors_Attach.lua`. A container attached to another
continues its chain root's flow (`Anchors.EffectiveLayout`) and joins it by two absolute points,
`attach.childPoint` and `attach.relPoint`, each Automatic while unset (`Anchors.AttachPoints`,
batch 11 G2, G3); a pair that is one of batch 9's nine sides keeps that side's seam and spread
(`Anchors.AttachEdge`, G5), and any other is placed at its X/Y alone, except that one mirrored onto the
parent's before side is moved out past the parent's strip and label while each shows (DD-10). A write to a
flow or attachment path re-applies its followers (`Anchors.Followers`) and its parent. While a container previews,
the containers attached to it hang from `Preview.Extent`, a frame of ours sized to its placeholder
block; while it is unlocked, not previewing and predicted empty (`modules/EmptyWatch.lua`, batch 9
HG-1), from its one-element anchor, which its placeholder outline marks; otherwise from its engine
(`Anchors.HangMode`, re-placed by `Anchors.PlaceAttached`). Before any container text is drawn,
`modules/FontPrimer.lua` draws every font the containers use once on a shown frame of its own, because
the client loads an addon font file lazily and text first drawn before the load stays blank (issue
#24, `docs/midnight-quirks.md`). Previewing is the session-only **test mode**
(`NS.State.testMode`, switched only by `Preview.SetTestMode`): every container shows its placeholder
auras. Unlocking is separate: it makes containers draggable while their live auras keep drawing,
each under its drag handle, and one predicted empty under a faint outline one element in size, so an
empty container can still be found and dragged. A screen container or one attached to another drags
(never one on a named frame, never in combat); dropped near another container it attaches there
(issue #22, `modules/Anchors_Snap.lua`). The handle's `beginDrag` lifts an attached anchor onto
`UIParent` and starts the snap driver, which every 0.03 s highlights one of the twelve
outside pairs (each side's start, middle and end joined to the child's mirror point, absolute and
independent of growth; the three on the target's before side place as a free pair) of an
eligible container within `C.SNAP_RADIUS` (`Snap.Find`; never itself or one that follows
it, `Anchors.WouldCycle`), picked side first and then by alignment (the addendum's A7: the nearest
side by the gap between the two facing edges, its span overlapping, then the start, middle or end
pair by which third of that side the dragged container's center is over; of the sides in range, A12:
one the dragged container spans alongside beats one it is only off the corner of, then the pair whose
two join points are nearest, the shortest line, wins), every rect measured and
drawn on the container's drag-handle strip while it shows and reads (A10, `Snap.Footprint`; else
A8's footprint, its block with its name label while that shows), the target's (and, for the detach
leeway, the parent's) strip with each edge on a side it grows toward taken out to its block's far
edge (A11, `Snap.ParentRect`, read in `modules/Anchors_SnapRect.lua`), with a 2 px edge in the mark's color on that container's drag-handle strip
and on the dragged container's own (A13)
(the owner-feedback addendum's A5 and A6: the strip's own 1 px gold edge repainted through
`Style.DrawEdge`, no frame of ours anchored to it, and its gold, `Anchors.STRIP_EDGE`, painted back
when the mark leaves it, hides or its container is destroyed; a box over its rect only when it has no
visible strip), a dot on each of the two join
points and a line between them, all in one color, and `Anchors.Place` leaves a dragging anchor alone. `Snap.Drop` decides
from the drop itself: a candidate and no Shift writes the whole `container.attach` section through
`NS.AttachByDrop` (`settings/Layout.lua`), which asks first with the GC-1 popup when the chain's flow
would change. An attached container has a leeway (the owner-feedback addendum's A4, `C.DETACH_RADIUS`,
128 since A9): while its current pair's two points stay that close to where they rested when the drag began, or
to each other (the cursor's travel when its parent does not read), or while the snap's own pick is that
very pair (over its third of a long parent's side, however far from its points), the mark stays green on that pair, the parent's strip repainted, and a release snaps it back, writing nothing; past it, the
whole mark turns red (`C.DETACH_COLOR`) and a release detaches to the drop position, X/Y 0. Another
pair in snap range, not its current one nor the one the pick gave where it rested, and nearer than it
by the leeway's measure (the nearer of its two points' distance and how far that has moved since the
drag began: 0 where it rests, though those points rest a seam, a nudge or a strip apart; DD-15R)
(the current parent measured on the rect its current pair is, `findFrom`: its strip alone where its
block reads secret; never one of it where no rect of it reads but the one-element fallback, nor, when
its rest did not read before the lift, before the cursor has moved past `C.SNAP_RADIUS`, nor then any other
container's either; DD-16R), wins over both, and Shift suppresses only that.
The tick and the drop classify alike (`classify`); combat started mid-drag attaches nothing. The handle's close mark (X) turns that container off through the write
seam. The strip's tooltip, and its marks', sits beside the strip: to its right, or to its left when
the strip is too close to the right edge of the screen for it to fit (`modules/Anchors_Tooltip.lua`,
LibKa0s-Widgets' `tooltipPlace`); where the strip's rect reads secret (a container attached under a
parent holding auras), beside the cursor where it entered the strip instead, fixed for the hover. It is anchored to `UIParent` alone, from the strip's rect read through
`NS.Secrets` and converted through both effective scales, because nothing may anchor into the
anchor's restricted tree; only where the cursor, the tooltip or the screen does not read either does it follow the cursor. A container can also show its name as a label where the handle sits, locked or unlocked;
while unlocked the handle moves out past it (`Anchors.PlaceLabel`, batch 8 D6).

Every non-vendored file, its responsibility and the full load order: `docs/module-map.md`.

## Settings Schema

`NS.Schema` holds **269** rows across seven pages (General 18, Containers 5, Filters 57, Layout 38,
Bars 72, Icons 42, Text 37), plus one runtime row per user category. It drives the panel,
`/am list|get|set|reset` and the resets through one write seam, `NS.SetByPath`.

- **Containers registry** (architecture-§5): keys `containers`, `containerOrder`, `nextContainerId`,
  `seeded`; writer `modules/ContainerManager.lua` (with `Database.NewContainerData`); load pass
  `Database.PrepareProfile`.
- **User spell categories registry:** keys `userCategories`, `userCategoryOrder`; writer
  `defaults/UserCategories.lua`; load pass `Cat.SyncUserCategories`.
- **Named non-setting state:** `global.timedSpells` (owner `modules/TimedSpells.lua`; writers
  `TS.Scan`, `TS.Forget`), `AuraMasterPerfDB` (owner `core/PerfSetup.lua`; writer the library's
  `P.Save`) and `global.minimap.minimapPos` (owner `core/LauncherSetup.lua`; writer LibDBIcon-1.0).

Every row rule and carve-out, each registry's surfaces and every writer: `docs/schema.md` →
*Settings schema, registries and named non-setting state*.

## Locale routing, and its one exemption

Every user-visible string routes through `NS.L`, keyed by its English text (localization-§2), and
`tests/test_locale.lua` fails on a routed string with no `enUS` line and on an `enUS` line nothing
routes. The one exemption is a user category's name, enforced at the draw by `Cat.LabelOf`. The
rule and its guard: `docs/common-tasks.md` → *Locale routing, and its one exemption*.

## Filter priority

`modules/FilterCompiler.lua` ranks, highest first: the whitelist shows, the blacklist hides, a
category set to Show shows, categories all set to Hide hide, and an aura in no category shows.
`FC.ExplainSpell` answers the same question for one spell id. The rank table, how it compiles to
aura groups and the retired `onlyShown` toggle: `docs/data-flow.md` → *Filter priority*.

Every group carries three views: ids, blizzard and every (`group.views`). Where Blizzard applies
spell ids to the container's unit and aura type, the engine holds the ids view, exactly as compiled. Where it does not (debuffs on the player or
the pet always; buffs on a target or focus you cannot assist, and debuffs on one you can), it holds
the view the container's Situations setting picks (`filter.situations`): the every view, every aura
passing the base and in no Hidden Blizzard, Dispel or Who Cast It category, once, through the
trailing remainder slot (the default), or the blizzard view (`modules/FilterViews.lua`), where spell
categories, Uncategorized, the Overrides lists and the catch-all match nothing and only the Blizzard
categories set to Show draw, each aura once. Player and pet debuffs follow the Players setting; a
target or focus follows Players or NPCs by `NS.Compat.IsPlayerUnit`, the stricter setting when that
is not knowable. `FC.IdsMode`, `NS.Compat.IdsApply` and the setting choose the view
(`ContainerClass:ResolveView`), and `ContainerClass:ApplyView` switches a live engine on a swap, a
reaction change or a Situations write, in combat too. The Filters section says so in its orange
warning and in a NOTE on Categories and Overrides that points to its last tab, **Situations**, which
holds, first, on a target or focus container the Unit type gate (`filter.unitFilter`: NPCs or players
by `NS.Compat.IsPlayerUnit`, friendly, neutral or hostile by `NS.Compat.UnitReactionKind`; filter
situations S6), then the setting (the dropdowns its `FC.IdsMode` calls for) and the six zone
checkboxes (`filter.zones`, the gate in `ContainerClass:ShouldShow`). Blizzard's predicate and the switch:
`docs/midnight-quirks.md` → *Spell-id filters apply only where Blizzard's predicate allows them*.

## Message Bus

A closed bus on AceEvent messages (`core/Bus.lua`, architecture-§4). Every receiver subscribes on its
own target from `NS.NewBusTarget()`, so no two receivers can clobber each other. The catalog below
is declared through `LibKa0s-Bus-1.0`'s `Catalog`, which validates the four wire names at load and
hands back a strict copy: a mistyped `NS.MSG` key raises at the call site, for a publisher as well
as a subscriber. Without the library the same table is used plain, and a mistyped key reads nil
(the one thing a degraded install loses here). `NS.NewBusTarget()` stays this addon's own untracked
factory, not the major's stand-down record: every receiver stands down in its own module (issue #20). There is
deliberately **no aura-data message**: the engine owns `UNIT_AURA` and nothing here reads an aura to
pass on.

| Message | Sender | Payload | Consumers |
|---|---|---|---|
| `Ka0s_AuraMaster_ContainersChanged` (`NS.MSG.CONTAINERS_CHANGED`) | `modules/ContainerManager.lua` — create, delete, rename, duplicate, profile change (copy-from and reset positions are settings writes, announced by `CONFIG_CHANGED`) | none | `settings/OptionsSetup.lua:405` — `NS.RequestPanelRefresh`, a coalesced panel re-render (every banner lists containers); `modules/TimedSpells.lua:204` — `TS.Sync`, which starts or stops the timed-spell scan (a container added or removed can change whether any needs it) |
| `Ka0s_AuraMaster_ConfigChanged` (`NS.MSG.CONFIG_CHANGED`) | `settings/Schema.lua:603` — the write seam, once per write; never for a session row | `{ section, containerId, path }`; `containerId` nil for an addon-wide row, `path` the row written | `modules/ContainerManager.lua:866` — first `FontPrimer.PrimeAll` (a new font is drawn before anything is applied in it), then by the row's `effect`: `"visibility"` (the master enable, visibility, lock and alpha, a container's enable, its six `filter.zones` rows and its two `filter.unitFilter` rows) runs `ApplyVisibility()` at once, `"none"` queues nothing, `"view"` (the two `filter.situations` rows) runs `CM.ApplyViews` for that container at once, in combat too and never held, otherwise `RequestApply(containerId)` (nil re-applies all), a write to a flow or attachment path also re-applies every container following that one (`Anchors.Followers`), and a write to a container's attach points, mode or target also re-applies the container it attaches to (`requestParents`); `modules/TimedSpells.lua:203` — `TS.Sync`, the same re-sync (a filter write can change whether any container needs the scan) |
| `Ka0s_AuraMaster_VisibilityChanged` (`NS.MSG.VISIBILITY_CHANGED`) | `core/AuraMaster.lua` — entering the world, combat start and end; `modules/Preview.lua` — `Preview.SetTestMode`, when test mode switches on or off | none | `modules/ContainerManager.lua:879` — `ApplyVisibility()` over every container |
| `Ka0s_AuraMaster_TimedSpellsChanged` (`NS.MSG.TIMED_SPELLS_CHANGED`) | `modules/TimedSpells.lua` — a scan learned timed spells, or `/am forgettimed` emptied the set | none from a scan; `{ byPlayer = true }` from `/am forgettimed` | `modules/ContainerManager.lua` `CM.Init` — `RequestApply(nil, system)` over every container (their excluded ids moved); a scan's request is the addon's own, so a deferral of it prints no notice |

Four messages, well under the more-than-ten trigger for a separate `message-bus.md`.

## Slash Commands

`/am` with `/auramaster` as the long alias, dispatched by `LibKa0s-Slash-1.0` over the addon's own
ordered `NS.COMMANDS` (`settings/Slash.lua:39`). Twenty-five verbs; `options` is an alias of `config`.
A bare `/am` runs `config`, opening the settings panel on its landing page (slash-commands-§4); `/am
help` prints the list.
`/am test` is the test mode's verb (preview-mode): unlocking no longer previews, so the placeholders
have a switch of their own, shared with the Master controls *Test mode* checkbox and the minimap
button's left click.

| Command | What it does |
|---|---|
| `/am help` | List available commands |
| `/am config` | Open the settings panel (a bare `/am` does the same) |
| `/am enable` | Turn Aura Master on (every enabled container shows again) |
| `/am disable` | Turn Aura Master off (hides every container) |
| `/am list` | List every setting and its current value (container settings read the selected container) |
| `/am get path` | Print a setting's current value |
| `/am set path value` | Set a setting |
| `/am reset path` | Reset one setting to its default |
| `/am resetall` | Reset every setting to defaults (a profile reset) |
| `/am profile [name]` | List profiles, current marked; with a name, switch to that existing profile (quotes stripped, case kept; an unknown name is refused, never created; refused in combat). The behavior is `LibKa0s-Slash-1.0`'s `CliProfile` (`docs/profiles.md`); answers while disabled |
| `/am containers` | List your containers; the selected one is marked |
| `/am select id-or-name` | Choose the container settings apply to |
| `/am new [unit] [type] [style]` | Create a container (`player`/`target`/`focus`/`pet`, `buffs`/`debuffs`/`enchants`, `bars`/`icons`/`text`) |
| `/am delete id-or-name` | Delete a container |
| `/am lock` | Lock every container in place |
| `/am unlock` | Unlock containers so they can be dragged |
| `/am test [on\|off]` | Toggle test mode: placeholder auras on every container; refused in combat |
| `/am pick` | Attach the selected container to a frame by clicking it |
| `/am resetposition` | Move every container back to its default screen position |
| `/am forgettimed` | Forget which buffs were learned to have a duration |
| `/am redraw [light\|full]` | Repaint every container. `light` turns every live engine off and on again now, in any state, combat and aura secrecy included (the weapon-enchant flip, SP-AMX-01). `full` primes the fonts, does the same flip, then asks for one system apply of every container, which re-dresses every button in place; while combat or aura secrecy holds applies that part waits, the line says so and the usual deferral notice follows. A bare `/am redraw` runs `full` when nothing holds an apply, else `light` with a line saying a full one waits. While a perf capture stands the addon down, `full` and a bare `/am redraw` do nothing and say so, and `light` repaints 0. Neither form retires or builds an engine |
| `/am debug [on\|off\|diagnostics]` | Toggle the debug console; `on`/`off` enable or disable logging; `diagnostics` writes the diagnostic report, the same as `/am diagnostics` |
| `/am diagnostics` | Write the diagnostic report to the debug console (`docs/debug.md`); answers while disabled |
| `/am perf …` | Measure performance — bare `/am perf` opens the workflow |
| `/am version` | Print the addon version |

**While the addon is disabled** the nine verbs that drive its features — `new`, `delete`, `lock`,
`unlock`, `test`, `pick`, `resetposition`, `forgettimed`, `redraw` — answer on one tagged line naming `/am enable` and
do nothing else (slash-commands-§2). Everything else keeps working, the bare `/am` included: it
opens the settings panel, which is the surface a player switches the addon back on from by hand. The
gate is `LibKa0s-Slash-1.0`'s, closed by the descriptor's `isEnabled` in `settings/Slash.lua` with
`liveVerbs` naming the live set as data; a verb added to `NS.COMMANDS` refuses by default.
The Master controls **Test mode** checkbox refuses a start the same way, on the same line, and the
launcher menu's *Test mode* entry is grayed; turning test mode off stays allowed.

Dispatch, the host verbs, the container-relative paths and the degraded path: `docs/slash-dispatch.md`.

`enable` and `disable` are **aliases, not state**: both write the Master controls Enable row's own
path through `NS.SetByPath`, so the verb and the checkbox cannot disagree. The dispatcher is
registered in `OnInitialize` and is never torn down, so every verb — `enable` above all — still
answers while the addon is disabled (slash-commands-§2). What disabling *does* do is
`## The disabled state`, below.

## Launcher

One LibDataBroker `launcher` object, built by `core/LauncherSetup.lua` through `LibKa0s-Launcher-1.0`
and registered with LibDBIcon under the folder name (launcher-§1). Left click opens the settings
panel; right click opens the library's context menu with three entries, *Enabled*, *Locked* and
*Test mode*, each wired to the same `NS.Slash` handler its verb runs (launcher-§2, LibKa0s-Launcher
minor 4; no *Show window*, as the addon has no primary window). While disabled, *Locked* and *Test
mode* are grayed. The Minimap button row stores LibDBIcon's own `global.minimap.hide`. The hover
tooltip is the library's (enabled, locked and test-mode status and the fixed click hints, drawn
while disabled too); the descriptor only answers its questions. Both broker libraries are
optional. The full table and the reasons:
`docs/settings-panel.md` → *Launcher*.

## Event Subscriptions

| Event | Registered by | Handler → effect |
|---|---|---|
| `PLAYER_ENTERING_WORLD` | `core/AuraMaster.lua:59` (AceEvent, through `NS.SafeRegisterEvent`) | `OnEnterWorld` → `VISIBILITY_CHANGED`, `ContainerManager.FlushPending`, `FontPrimer.OnEnterWorld` (notes the time: the loading screen is still up; the primer's anchor only on a client that refused `LOADING_SCREEN_DISABLED`) |
| `LOADING_SCREEN_DISABLED` | `core/AuraMaster.lua:61` | `OnLoadingScreenEnd` → `FontPrimer.OnLoadingScreenEnd` (the loading screen's real end: arms the primer's world hide and refresh), then `CM.RequestEnchantReset("world")`: the weapon-enchant reset, 1.75 s later, whatever the primer did (SP-AMX-01) |
| `PLAYER_REGEN_DISABLED` | `core/AuraMaster.lua:62` | `OnCombatChanged` → `VISIBILITY_CHANGED` |
| `PLAYER_REGEN_ENABLED` | `core/AuraMaster.lua:63` | `OnCombatChanged` → `VISIBILITY_CHANGED`, `FlushPending`, `ReapplyStaleClass`, `BlizzardFrames.Apply`, `Anchors.ResolvePending` (a frame that appeared during combat) |
| `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED` | `core/AuraMaster.lua:64-65` | `OnUnitSwap` → `CM.ApplyViews` (each container on that unit switched to the view of its plan the new unit's reaction picks, spell-list views V2) → `RefreshUnit` → the engine's `UpdateAllAuras` → `CM.ApplyUnitGate` (the visibility pass of each container on that unit whose Unit type answer moved, filter situations S6) (bucket `unitSwap`); re-applies the class-colored containers of that unit when the new unit's class differs, or marks them stale, silently, while an apply must wait |
| `UNIT_PET` | `core/AuraMaster.lua:66` | `OnUnitPet` (player only) → `RefreshUnit("pet")` (bucket `unitSwap`); re-applies the class-colored pet containers when the pet's class differs, or marks them stale while an apply must wait |
| `ADDON_LOADED` | `core/AuraMaster.lua:67` | `OnAddonLoaded` → `Anchors.ResolvePending` (frame-attached containers) |
| `ADDON_RESTRICTION_STATE_CHANGED` | `core/AuraMaster.lua:69` | `OnRestrictionChanged` → `FlushPending`, `ReapplyStaleClass` (a deferred apply runs when secrecy lifts) |
| `ITEM_DATA_LOAD_RESULT`, `GET_ITEM_INFO_RECEIVED` | `core/AuraMaster.lua:72-73` | `OnItemDataLoaded` → `CM.OnWeaponItemData`: the item equipped in slot 16 or 17, loaded successfully, arms the weapon-enchant reset 0.5 s later. One debounced `C_Timer` serves both triggers and keeps the later deadline; when it fires, `CM.ResetEnchants` turns each live engine with enchant frames off and on again (`ContainerClass:ResetEnchants`), so the weapon names are drawn afresh (`docs/midnight-quirks.md` → *Weapon enchants*). `CM.StopListening` cancels it |
| `ZONE_CHANGED_NEW_AREA` | `core/AuraMaster.lua:76` | `OnZoneChanged` → `VISIBILITY_CHANGED`: a border crossing into another kind of place with no loading screen re-runs the visibility pass, whose zone gate (`ContainerClass:ShouldShow`, filter situations S3) reads `NS.Compat.InstanceType()` on every pass. Untraced |
| `UNIT_AURA` for `player` and `pet` | `modules/TimedSpells.lua` — the module's one private frame, `TS.unitFrame` (events-frames-taint-§1's carve-out: the vendored AceEvent has no `RegisterUnitEvent`), through `NS.SafeRegisterUnitEvent`; built once and reused, registered only while a container uses "without a duration", the addon is not suspended, and auras are readable (no combat lockdown, not secret), and unregistered by hand in `TS.Stop` | the frame's one `OnEvent` → `onUnitAura`: the client delivers only `player` and `pet`; the handler still proves the unit a safe key and compares it (defense in depth), then schedules a scan 0.5 s later (bucket `timedScan`). A scan that comes due after the gate closed is dropped too |
| `UNIT_AURA` for `player` and `pet`, and for `target` and `focus` | `modules/EmptyWatch.lua` — its two private frames, `EW.unitFrames[1]` (player, pet) and `[2]` (target, focus), the same carve-out, each filtering `UNIT_AURA` and nothing else, through `NS.SafeRegisterUnitEvent`; built once and reused, each registered only while a shown container on its units is unlocked and out of test mode, the addon is not suspended, combat has not started and auras are readable, and unregistered by hand in `EW.Stop` | the frames' one `OnEvent` only marks a pass due: one pass 0.2 s later (bucket `emptyPass`) re-predicts every watched container and re-runs the visibility pass of any whose answer changed |
| `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED` | `modules/EmptyWatch.lua` (AceEvent, on its own target) — while its target and focus frame is registered | `CM.ApplyViews(unit)` first (AceEvent runs this and `OnUnitSwap` in no set order, so the prediction never reads the old unit's view; a no-op when the view is already right), then the pass run at once, not 0.2 s later, folding in one already due: the engine redraws for the new unit in the same frame, so a follower hung from a parent that just emptied would otherwise sit on the engine's 1x1 rect for the delay |
| `UNIT_PET`, `UNIT_INVENTORY_CHANGED` | `modules/EmptyWatch.lua` (AceEvent, on its own target) — while its player and pet frame is registered | the same pass marked due, for the `player` unit only |
| `UNIT_FACTION`, `UNIT_FLAGS` for `target` and `focus` | `modules/ContainerManager.lua:820` — the module's one private frame, `CM.viewFrame` (the same carve-out), through `NS.SafeRegisterUnitEvent`; built once, hidden and reused, opened by `CM.StartListening` and unregistered by hand in `CM.StopListening` | `onViewEvent`: proves the unit a safe key, then `CM.ApplyViews(unit)`: a reaction change without a swap (a duel, mind control, an NPC turning hostile) switches the view; the two setters redraw, so no refresh follows; then `CM.ApplyUnitGate(unit)` re-runs the visibility pass of each container whose Unit type answer moved (filter situations S6). Combat-legal, never held. When a view moved, `EW.OnViewsMoved` re-predicts at once (gated on unlocked, out of combat and auras readable), so the empty prediction follows the engine |
| `UNIT_FACTION`, `UNIT_FLAGS` for `player` | `modules/ContainerManager.lua` — a second private frame, `CM.viewPlayerFrame`, built, opened and closed with `CM.viewFrame` (`RegisterUnitEvent` takes two units, and a second call replaces the first) | `onPlayerViewEvent`: proves the unit a safe key, then `CM.ApplyViews` for `target` and for `focus`, quietly, and one `EW.OnViewsMoved` if either moved: the player's own side changing (mind control) moves whether a target or focus can be assisted with no event for that unit (SV-05); then `CM.ApplyUnitGate` for `target` and for `focus`, since the same change moves their reaction to you |
| `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`, `ADDON_RESTRICTION_STATE_CHANGED` | `modules/TimedSpells.lua` (AceEvent, on its own target) — while a container uses "without a duration" and the addon is not suspended | `syncAuraListen`: `PLAYER_REGEN_DISABLED` closes the readable gate by itself (it fires before combat lockdown begins); the other two re-check it, dropping or restoring `UNIT_AURA`; reopening schedules one scan |
| AceDB `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset` | `core/Database.lua:275-279` | `NS.OnProfileChanged` / `NS.OnProfileCopied` / `NS.OnProfileReset` → re-prepare the registry, trace the event once in its own words (a switch `[Profile] changed -> X`; a copy or a reset one `[Set]` line, debug-logging-§10), rebuild, re-render |

Each container's own `UNIT_AURA` belongs to the engine (`SetUnit`, `modules/Container.lua:442`) and
is not addon code. The twelve `core/AuraMaster.lua` registrations are one module-level list,
`LIFECYCLE_EVENTS`, which `RegisterLifecycleEvents` and `UnregisterLifecycleEvents` both walk, so the
stand-down and the stand-up remove and restore the same list. With logging on, the world-entry, loading-screen, combat and
restriction handlers each write one `[Event]` line before acting (`traceEvent`,
`core/AuraMaster.lua:100`; `docs/debug.md` -> *The event trace*); the unit swaps, `ADDON_LOADED`, the two item events and
`ZONE_CHANGED_NEW_AREA` (a border crossing, which fires on every zone border) do not. The weapon-enchant reset writes one `[Apply]` line when it fires.

The font primer (`modules/FontPrimer.lua`) registers no event of its own. It runs from
`CM.StartListening` (the login's `CM.Init` and every stand-up, before the first build), from the
`CONFIG_CHANGED` handler before the apply is requested, and from `CM.Announce` before a profile
switch or a registry change is built. A priming that drew a new font arms two `C_Timer` handles, the
1 s hide and the 0.5 s follow-up refresh; `CM.StopListening` cancels both through `FontPrimer.Stop`.
A priming before the first loading screen ends arms neither. The client fires
`PLAYER_ENTERING_WORLD` while the loading screen is still up and `LOADING_SCREEN_DISABLED` when it
ends, so `addon:OnLoadingScreenEnd` calls `FontPrimer.OnLoadingScreenEnd`, which first runs a
priming pass (a font the client refused under the loading screen is tried again, FP-07) and then arms
them at 2 s and 1.5 s when anything was primed since the last loading screen. `FontPrimer.OnEnterWorld` only notes
the time for the report's gap line, and arms them itself only on a client that refused
`LOADING_SCREEN_DISABLED`.

**Every registration goes through one helper** (events-frames-taint-§1): `NS.SafeRegisterEvent`, which
is `LibKa0s-Core-1.0`'s `SafeRegisterEvent`, published by `core/CoreSetup.lua`. That covers every row
above and the stand-down's pending `PLAYER_REGEN_ENABLED`, except the unit frames' `UNIT_AURA` (TimedSpells' one, EmptyWatch's two) and ContainerManager's two `UNIT_FACTION` / `UNIT_FLAGS` frames, which
go through its unit-event twin, `NS.SafeRegisterUnitEvent`. A name the client does not know costs only
itself: the rest of the block still registers, and the name is appended once to `NS.RejectedEvents`.
Where a player sees it: the `[Init]` line that `/am debug` writes adds `rejected events: A, B` when
the list is not empty (`core/DebugLogSetup.lua`), and a name refused while logging is on is traced as
`[Init] event <NAME> rejected by this client` when it happens. What a refused name costs is written
up in `docs/midnight-quirks.md` ("An unknown event name raises").

**Every row in this table is gone while the addon is stood down** — unregistered, not gated. The one
exception is `PLAYER_REGEN_ENABLED`, which a stand-down that combat refused re-registers on its own
handler until the combat-restricted half finishes; see below.

## The disabled state

Disabled means not running (slash-commands-§7). One `LibKa0s-Lifecycle-1.0` latch holds two named
holds, `disabled` (persisted) and `perf` (session-only). Standing down unregisters the lifecycle
events and every module's subscriptions and timers, turns every container off and hands Blizzard's
frames back, finishing the combat-restricted half on `PLAYER_REGEN_ENABLED`; standing up rebuilds
from current state. What stands down, what survives and the library-absent path:
`docs/data-flow.md` → *The disabled state*.

## Taint Notes

No secure template of our own: the only protected machinery is Blizzard's aura engine, and each
container's anchor opts in through `DisableUntrustedLayoutScriptsTemplate`. No structural work runs
while auras are secret or under combat lockdown (`ContainerManager.MustDefer`); visibility in combat
goes through the engine's `SetEnabled`, and so does the weapon-enchant reset (off, then on, only for
an engine that should be on); protected opens and frame-creating verbs are refused in
combat, and a teardown under lockdown is parked; every engine binding is `pcall`-guarded; no border
reads a secret size; and secret values never reach a string operation. The font primer's frame hangs
from `UIParent`, outside every anchor, and its one engine call, a follow-up `UpdateAllAuras`, is not
protected and skips a disabled engine. Every rule and the code that
keeps it: `docs/midnight-quirks.md` → *Taint notes*.

## Known Limitations

Units stop at player, target, focus and pet. Nothing structural happens while auras are secret or
under lockdown, so settings changes, teardown and class colors wait for it to lift. The engine bounds
what a Text line can do, which spell-id filters it honors, and when a non-Solid border redraws. A
handful of user-category trade-offs were accepted by the owner. A font a media addon registers
after login is not primed until the next settings change or `/reload`. A container on a named frame
cannot be dragged, and an attached one whose position reads secret jumps to the cursor when its drag
starts. Every limitation, its cause and any
ruling: `docs/known-limitations.md`.

## Documentation map

Every `.md` under `docs/` appears in exactly one table below (documentation-§3). Frozen and
generated directories are named once and never enumerated: `docs/audits/`, `docs/reviews/`,
`docs/automated-tests/<run>/`, `docs/perf-analysis/<run>/`, `docs/revendor/<date>-v<tag>/` (a
span bundle is `<date>-v<A>-v<B>/`, and the one untagged bundle is `docs/revendor/2026-09-12/`),
`docs/superpowers/`.

### Required (documentation-§3, Tier 1)

| Doc | Covers |
|---|---|
| `scope.md` | What the addon does, and what it deliberately does not |
| `module-map.md` | Every non-vendored file, its one-line responsibility, and the TOC load order and why; the vendored libraries and what each is used for |
| `schema.md` | The profile and global SavedVariables shape, the container template, every default, the migration path; the settings schema's rules, both structural registries and the named non-setting state |
| `settings-panel.md` | The `Tab \| Covers` table, the page → tab → row tree, per-option behavior and schema keys; the launcher |
| `data-flow.md` | Settings → filter plan → aura groups → the engine renders; the filter priority; lifecycle, deferral and the disabled state |
| `common-tasks.md` | Recipes for the changes made most often here, naming real files; the locale-routing rule and its one exemption |

### Conditional (documentation-§3, Tier 2)

| Doc | Status | Trigger |
|---|---|---|
| `perf-analysis/README.md` | Present | The performance harness is wired (`core/PerfSetup.lua`) |
| `slash-dispatch.md` | Present | 25 commands in `NS.COMMANDS`, over the eight-or-more threshold |
| `midnight-quirks.md` | Present | Client-version workarounds of the addon's own: 12.1 aura secrecy and the aura container engine, and the taint notes that follow from them |
| `compat-layer.md` | Present | 26 shims in `core/Compat.lua`, over the three-or-more threshold |
| `message-bus.md` | Not applicable | 4 messages in `NS.MSG`; the trigger is more than ten. The table lives in `## Message Bus` above |
| `profiles.md` | Present | AceDB profiles are user-visible: the Profiles sub-page is a profile control in the options UI |
| `debug.md` | Present | `/am diagnostics` (or `/am debug diagnostics`), the diagnostic report `modules/Diagnostics.lua` writes to the console |

### Verification and record (documentation-§3)

| Doc | Covers |
|---|---|
| `testing.md` | How to run the harness and lint; the green commit gate; the four suites and their checkpoints |
| `smoke-tests.md` | The in-game smoke-test suite |
| `test-cases.md` | The generated case inventory (authoritative pass count) |
| `performance.md` | The addon performance page |
| `automated-tests/README.md` | What the automated-test record is and how to produce it |
| `automated-tests/RESULTS.md` | One row per run; generated by the runner, never hand-edited apart from the watch list's `Disposition` column (automated-tests-§4) |

### Addon-specific (documentation-§3, Tier 3)

| Doc | Covers |
|---|---|
| `known-limitations.md` | Every known limitation: what the player sees, why the client or the engine forces it, and the owner's ruling where one was made |
| `spell-research/` | Frozen per-build derivation bundles written by `tools/spell-research/research.py`; the dated bundles are not enumerated |

## Documented deviations

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `options-ui-§17` | The "One resolver" clause: a unit-scoped container caches another unit's class. Each apply snapshots it (`ContainerClass:SnapshotClass` / `ResolveUnitClass`) and `Style.Color` paints from that snapshot, so after a target, focus or pet swap while auras are secret or under combat lockdown the container keeps the previous unit's class until it re-applies. Under lockdown alone (open world, auras readable) `ReapplyStaleClass` catches up on `PLAYER_REGEN_ENABLED`; while auras are secret it catches up when the restriction lifts (`ADDON_RESTRICTION_STATE_CHANGED`) | While auras are secret a re-dress is impossible: the engine dresses buttons in initializeFrame and forbids restyling them (DenyTaintedAccessWhenAurasAreSecret). Under combat lockdown alone, with auras readable, the wait is the addon's choice: `ContainerManager.MustDefer` holds every apply until combat ends, because an apply re-places the anchor and may retire and rebuild the engine, structural work that events-frames-taint-§2 keeps out of combat. Conforming there would take a second, restyle-only path that runs in combat beside the deferred apply, only to repaint a swatch that `ReapplyStaleClass` corrects on `PLAYER_REGEN_ENABLED`; audit docs/audits/2026-09-11 AM-03. Ratified by the owner 2026-09-12. | 2026-09-12 | The secret-auras half ends when the aura engine offers a class-color binding it resolves per button itself, or addon restyling of engine buttons becomes legal while auras are secret; the lockdown-only half ends when a restyle-only path may run under combat lockdown (`ContainerManager.MustDefer` stops holding a class-only re-dress). The row is retired when both halves have ended |

### Files over the 1500-line cap

No authored file is over the cap; the census is measured by tests/_kit/test_layout_cap.lua.
