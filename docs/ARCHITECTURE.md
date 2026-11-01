# Architecture — Ka0s Aura Master

The engineer's hub for this addon. Each mandated section summarizes and links out; the detail lives
in the topic docs registered under [Documentation map](#documentation-map) (documentation-§3).

## Overview

Ka0s Aura Master draws player-built aura **containers**. A container is one unit (`player`,
`target`, `focus`, `pet` — `core/Constants.lua:39`), one aura type (`HELPFUL` or `HARMFUL` — `:45`;
the player's temporary weapon enchants are the buff category `weaponEnchants`, schema v5) and one style (`bars`, `icons` or
`text` — `:49`), plus its filters, placement and look. A profile holds any number of them; a fresh
profile is seeded with four (`NS.STARTER_CONTAINERS`, `defaults/Profile.lua:332`).

**The design is dictated by one client fact.** On Retail 12.1 an addon cannot read aura data while
auras are secret — combat, encounters, Mythic+ and PvP (`core/Secrets.lua`, `docs/midnight-quirks.md`).
So this addon reads no aura at all. Every container is a Blizzard **AuraContainer**
(`CreateFrame("AuraContainer", nil, anchor, "CustomAuraContainerTemplate")`,
`modules/Container.lua:449`) that registers `UNIT_AURA` for its unit, gathers, sorts, lays out and
animates its buttons in Blizzard's own code. A Text container with Glow on adds `C.TEXT_GLOW_TWINS`
twin engines with the same content, offset around the main and dressed in the glow color
(`modules/Container_Twins.lua`), since no addon code can copy the engine's secret text. The addon's
job is to **declare** what each container shows and **dress** each button the engine creates:

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
the optional LibDataBroker and LibDBIcon, and LibKa0s with fifteen modules bound by name, every
one of which degrades to a stub or a fallback when the library is absent. What each library is used for, and
what each LibKa0s setup file publishes: `docs/module-map.md` → *Libraries*.

## Module Map

Five source folders in the TOC's load order — `locales/` → `core/` → `defaults/` → `modules/` →
`settings/` (layout-§1) — 62 authored Lua files under them: one locale, 18 core, 4 defaults, 24
modules and 15 settings. The load-bearing positions are annotated at their TOC lines:
`core/MediaSetup.lua` before `core/Constants.lua` (the monospace face), `core/CoreSetup.lua` before
anything that prints, `core/SkinSetup.lua` after it and before every frame builder (the skin owner registers at file load, skinning-§1), `core/PerfSetup.lua` before every module that takes `NS.Perf` as an upvalue,
`defaults/Categories.lua` before `defaults/Profile.lua` (the template's category states) and
`defaults/UserCategories.lua` directly after it (the `NS.Categories` upvalue),
`modules/Style_Text.lua` before `modules/Style_TextGlow.lua` (which decorates `NS.Style.Text` at file
load),
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

The engine-facing modules: `modules/FilterCompiler.lua` with `modules/FilterViews.lua` (settings →
groups, pure), `modules/Container.lua` (one main engine) with `modules/Container_Twins.lua` (a glowing
Text container's twin engines, right after it by convention only, resolving its peers at call time),
`modules/ContainerManager.lua` (the registry and
the deferred apply), `modules/Style.lua` with `Style_Border.lua`, `Style_Bars.lua`, `Style_Icons.lua`, `Style_Text.lua`,
`Style_TextGlow.lua` and `modules/TextTemplate.lua`, placement in `modules/Anchors.lua` with
`Anchors_Attach.lua`, `Anchors_Snap.lua`, `Anchors_SnapRect.lua` and `Anchors_Tooltip.lua`,
`modules/EmptyWatch.lua`, `modules/FontPrimer.lua` and `modules/Preview.lua` (the session-only test
mode). How they place, attach, preview, unlock and drag a container: `docs/data-flow.md` →
[*Placement, preview and drag in brief*](data-flow.md#placement-preview-and-drag-in-brief).

Every non-vendored file, its responsibility and the full load order: `docs/module-map.md`.

## Settings Schema

`NS.Schema` holds **293** rows across seven pages (General 26, Containers 5, Filters 57, Layout 39,
Bars 77, Icons 44, Text 45), plus one runtime row per user category. It drives the panel,
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
passing the base and in no Hidden Blizzard, Dispel or Who cast it category, once, through the
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
| `Ka0s_AuraMaster_ContainersChanged` (`NS.MSG.CONTAINERS_CHANGED`) | `modules/ContainerManager.lua` — create, delete, rename, duplicate, profile change (copy-from and reset positions are settings writes, announced by `CONFIG_CHANGED`) | none | `settings/OptionsSetup.lua:433` — `NS.RequestPanelRefresh`, a coalesced panel re-render (every banner lists containers); `modules/TimedSpells.lua:204` — `TS.Sync`, which starts or stops the timed-spell scan (a container added or removed can change whether any needs it) |
| `Ka0s_AuraMaster_ConfigChanged` (`NS.MSG.CONFIG_CHANGED`) | `settings/Schema.lua:629` — the write seam, once per write; never for a session row | `{ section, containerId, path }`; `containerId` nil for an addon-wide row, `path` the row written | `modules/ContainerManager.lua:866` — first `FontPrimer.PrimeAll` (a new font is drawn before anything is applied in it), then by the row's `effect`: `"visibility"` (the master enable, visibility, lock and alpha, a container's enable, its six `filter.zones` rows and its two `filter.unitFilter` rows) runs `ApplyVisibility()` at once, `"none"` queues nothing, `"view"` (the two `filter.situations` rows) runs `CM.ApplyViews` for that container at once, in combat too and never held, otherwise `RequestApply(containerId)` (nil re-applies all), a write to a flow or attachment path also re-applies every container following that one (`Anchors.Followers`), and a write to a container's attach points, mode or target also re-applies the container it attaches to (`requestParents`); `modules/TimedSpells.lua:203` — `TS.Sync`, the same re-sync (a filter write can change whether any container needs the scan) |
| `Ka0s_AuraMaster_VisibilityChanged` (`NS.MSG.VISIBILITY_CHANGED`) | `core/AuraMaster.lua` — entering the world, combat start and end; `modules/Preview.lua` — `Preview.SetTestMode`, when test mode switches on or off | none | `modules/ContainerManager.lua:879` — `ApplyVisibility()` over every container |
| `Ka0s_AuraMaster_TimedSpellsChanged` (`NS.MSG.TIMED_SPELLS_CHANGED`) | `modules/TimedSpells.lua` — a scan learned timed spells, or `/am forgettimed` emptied the set | none from a scan; `{ byPlayer = true }` from `/am forgettimed` | `modules/ContainerManager.lua` `CM.Init` — `RequestApply(nil, system)` over every container (their excluded ids moved); a scan's request is the addon's own, so a deferral of it prints no notice |

Four messages, well under the more-than-ten trigger for a separate `message-bus.md`.

## Slash Commands

`/am` with `/auramaster` as the long alias, dispatched by `LibKa0s-Slash-1.0` over the addon's own
ordered `NS.COMMANDS` (`settings/Slash.lua:39`). Twenty-six verbs; `options` is an alias of `config`.
A bare `/am` runs `config`, opening the settings panel on its landing page (slash-commands-§4); `/am
help` prints the list.
`/am test` is the test mode's verb (preview-mode): unlocking no longer previews, so the placeholders
have a switch of their own, shared with the Master controls *Test mode* checkbox and the launcher
menu's *Test mode* entry. While it is on and unlocked, each strip reads its name and then an orange
TEST. Locked, the placeholders carry no TEST of their own: the owner removed that marker (D-14 of
Ka0sAddonsCommonTasks `docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK/`, image-35), and preview-mode's
on-display marker is a MAY for a HUD display such as an aura container (WS-01).

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
| `PLAYER_ENTERING_WORLD` | `core/AuraMaster.lua:62` (AceEvent, through `NS.SafeRegisterEvent`) | `OnEnterWorld` → `VISIBILITY_CHANGED`, `ContainerManager.FlushPending`, `FontPrimer.OnEnterWorld` (notes the time: the loading screen is still up; the primer's anchor only on a client that refused `LOADING_SCREEN_DISABLED`) |
| `LOADING_SCREEN_DISABLED` | `core/AuraMaster.lua:64` | `OnLoadingScreenEnd` → `FontPrimer.OnLoadingScreenEnd` (the loading screen's real end: arms the primer's world hide and refresh), then `CM.RequestEnchantReset("world")`: the weapon-enchant reset, 1.75 s later, whatever the primer did (SP-AMX-01) |
| `PLAYER_REGEN_DISABLED` | `core/AuraMaster.lua:65` | `OnCombatChanged` → `VISIBILITY_CHANGED` |
| `PLAYER_REGEN_ENABLED` | `core/AuraMaster.lua:66` | `OnCombatChanged` → `VISIBILITY_CHANGED`, `FlushPending`, `ReapplyStaleClass`, `BlizzardFrames.Apply`, `Anchors.ResolvePending` (a frame that appeared during combat) |
| `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED` | `core/AuraMaster.lua:67-68` | `OnUnitSwap` → `CM.ApplyViews` (each container on that unit switched to the view of its plan the new unit's reaction picks, spell-list views V2) → `RefreshUnit` → the engine's `UpdateAllAuras` → `CM.ApplyUnitGate` (the visibility pass of each container on that unit whose Unit type answer moved, filter situations S6) (bucket `unitSwap`); re-applies the class-colored containers of that unit when the new unit's class differs, or marks them stale, silently, while an apply must wait |
| `UNIT_PET` | `core/AuraMaster.lua:69` | `OnUnitPet` (player only) → `RefreshUnit("pet")` (bucket `unitSwap`); re-applies the class-colored pet containers when the pet's class differs, or marks them stale while an apply must wait |
| `ADDON_LOADED` | `core/AuraMaster.lua:70` | `OnAddonLoaded` → `Anchors.ResolvePending` (frame-attached containers) |
| `ADDON_RESTRICTION_STATE_CHANGED` | `core/AuraMaster.lua:72` | `OnRestrictionChanged` → `FlushPending`, `ReapplyStaleClass` (a deferred apply runs when secrecy lifts) |
| `ITEM_DATA_LOAD_RESULT`, `GET_ITEM_INFO_RECEIVED` | `core/AuraMaster.lua:75-76` | `OnItemDataLoaded` → `CM.OnWeaponItemData`: the item equipped in slot 16 or 17, loaded successfully, arms the weapon-enchant reset 0.5 s later. One debounced `C_Timer` serves both triggers and keeps the later deadline; when it fires, `CM.ResetEnchants` turns each live engine with enchant frames off and on again (`ContainerClass:ResetEnchants`), so the weapon names are drawn afresh (`docs/midnight-quirks.md` → *Weapon enchants*). `CM.StopListening` cancels it |
| `ZONE_CHANGED_NEW_AREA` | `core/AuraMaster.lua:79` | `OnZoneChanged` → `VISIBILITY_CHANGED`: a border crossing into another kind of place with no loading screen re-runs the visibility pass, whose zone gate (`ContainerClass:ShouldShow`, filter situations S3) reads `NS.Compat.InstanceType()` on every pass. Untraced |
| `UNIT_AURA` for `player` and `pet` | `modules/TimedSpells.lua` — the module's one private frame, `TS.unitFrame` (events-frames-taint-§1's carve-out: the vendored AceEvent has no `RegisterUnitEvent`), through `NS.SafeRegisterUnitEvent`; built once and reused, registered only while a container uses "without a duration", the addon is not suspended, and auras are readable (no combat lockdown, not secret), and unregistered by hand in `TS.Stop` | the frame's one `OnEvent` → `onUnitAura`: the client delivers only `player` and `pet`; the handler still proves the unit a safe key and compares it (defense in depth), then schedules a scan 0.5 s later (bucket `timedScan`). A scan that comes due after the gate closed is dropped too |
| `UNIT_AURA` for `player` and `pet`, and for `target` and `focus` | `modules/EmptyWatch.lua` — its two private frames, `EW.unitFrames[1]` (player, pet) and `[2]` (target, focus), the same carve-out, each filtering `UNIT_AURA` and nothing else, through `NS.SafeRegisterUnitEvent`; built once and reused, each registered only while a shown container on its units is unlocked and out of test mode, the addon is not suspended, combat has not started and auras are readable, and unregistered by hand in `EW.Stop` | the frames' one `OnEvent` only marks a pass due: one pass 0.2 s later (bucket `emptyPass`) re-predicts every watched container and re-runs the visibility pass of any whose answer changed |
| `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED` | `modules/EmptyWatch.lua` (AceEvent, on its own target) — while its target and focus frame is registered | `CM.ApplyViews(unit)` first (AceEvent runs this and `OnUnitSwap` in no set order, so the prediction never reads the old unit's view; a no-op when the view is already right), then the pass run at once, not 0.2 s later, folding in one already due: the engine redraws for the new unit in the same frame, so a follower hung from a parent that just emptied would otherwise sit on the engine's 1x1 rect for the delay |
| `UNIT_PET`, `UNIT_INVENTORY_CHANGED` | `modules/EmptyWatch.lua` (AceEvent, on its own target) — while its player and pet frame is registered | the same pass marked due, for the `player` unit only |
| `UNIT_FACTION`, `UNIT_FLAGS` for `target` and `focus` | `modules/ContainerManager.lua:820` — the module's one private frame, `CM.viewFrame` (the same carve-out), through `NS.SafeRegisterUnitEvent`; built once, hidden and reused, opened by `CM.StartListening` and unregistered by hand in `CM.StopListening` | `onViewEvent`: proves the unit a safe key, then `CM.ApplyViews(unit)`: a reaction change without a swap (a duel, mind control, an NPC turning hostile) switches the view; the two setters redraw, so no refresh follows; then `CM.ApplyUnitGate(unit)` re-runs the visibility pass of each container whose Unit type answer moved (filter situations S6). Combat-legal, never held. When a view moved, `EW.OnViewsMoved` re-predicts at once (gated on unlocked, out of combat and auras readable), so the empty prediction follows the engine |
| `UNIT_FACTION`, `UNIT_FLAGS` for `player` | `modules/ContainerManager.lua` — a second private frame, `CM.viewPlayerFrame`, built, opened and closed with `CM.viewFrame` (`RegisterUnitEvent` takes two units, and a second call replaces the first) | `onPlayerViewEvent`: proves the unit a safe key, then `CM.ApplyViews` for `target` and for `focus`, quietly, and one `EW.OnViewsMoved` if either moved: the player's own side changing (mind control) moves whether a target or focus can be assisted with no event for that unit (SV-05); then `CM.ApplyUnitGate` for `target` and for `focus`, since the same change moves their reaction to you |
| `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`, `ADDON_RESTRICTION_STATE_CHANGED` | `modules/TimedSpells.lua` (AceEvent, on its own target) — while a container uses "without a duration" and the addon is not suspended | `syncAuraListen`: `PLAYER_REGEN_DISABLED` closes the readable gate by itself (it fires before combat lockdown begins); the other two re-check it, dropping or restoring `UNIT_AURA`; reopening schedules one scan |
| AceDB `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset` | `core/Database.lua:274-278` | `NS.OnProfileChanged` / `NS.OnProfileCopied` / `NS.OnProfileReset` → re-prepare the registry, trace the event once in its own words (a switch `[Profile] changed -> X`; a copy or a reset one `[Set]` line, debug-logging-§10), rebuild, re-render |

Each container's own `UNIT_AURA` belongs to its engine, and to each twin engine of a glowing Text
container, which takes the same `SetUnit` (`modules/Container.lua:443`); none of it is addon code.
The twelve `core/AuraMaster.lua` registrations are one module-level list, `LIFECYCLE_EVENTS`, which
`RegisterLifecycleEvents` and `UnregisterLifecycleEvents` both walk, so the stand-down and the
stand-up remove and restore the same list. With logging on, the world-entry, loading-screen, combat
and restriction handlers each write one `[Event]` line before acting (`traceEvent`,
`core/AuraMaster.lua:103`; `docs/debug.md` -> *The event trace*); the unit swaps, `ADDON_LOADED`,
the two item events and `ZONE_CHANGED_NEW_AREA` (a border crossing, which fires on every zone
border) do not. The weapon-enchant reset writes one `[Apply]` line when it fires.

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

## Skins

Every surface Aura Master draws paints through the `LibKa0s-Skin-1.0` facade with this addon as its
**owner** (skinning-§1 to §3; Ka0sAddonsCommonTasks `docs/2026-10-29-SKINNING_ROLLOUT/`, the AM items).

- **The seam.** `core/SkinSetup.lua` registers the owner `"AuraMaster"` at file load with its read and
  write seams (`NS.SkinChoice`, `NS.WriteSkinChoice`, every half through `NS.SetByPath`) and its own
  `am.*` tokens (`NS.SKIN_TOKENS`: the colors no library token holds exactly, each drawn at today's
  value on Ka0s Default and following a library role token in every other skin). It publishes
  `NS.Skin`, `NS.SkinColor`, `NS.SkinEscape`, `NS.PanelEscape` and `NS.SkinPaintAce` /
  `NS.SkinPaintAceTree` / `NS.SkinOnRelease`; its degraded arm answers from `NS.SKIN_FALLBACK`, which
  `tests/test_skinsetup.lua` holds to the library's values. The choice is the profile's `skin` table,
  seven rows drawn by the library's Skin tab on General ([schema.md](schema.md),
  [settings-panel.md](settings-panel.md)). `NS.ApplySkinChoice` applies it right after `NS:InitDB`
  and on every profile event.
- **The HUD reads the skin at dress time.** The aura buttons are Blizzard's pooled engine buttons,
  whose geometry reads secret, so no recorded primitive ever touches them. `Style.SkinKey` resolves
  `hud.font` (every font block, through `Style.FontKey`) and `bar.texture` (the bar fill and
  background) while the element's "Use the skin's ..." companion is on, and the stored pick while it
  is off. While the Skin tab's Ignore fonts is on every font block draws its stored face, companion
  or override notwithstanding: the library's `S.Resolve` answers the stored value for `hud.font` then
  (LibKa0s v1.81.0, LK-01), so `Style.SkinKey` needs no check of its own, and a nil answer draws the
  stored pick. The composer's font pickers preview the same stored face. Since v1.81.0 each skin
  carries a HUD face of its own (WoW Default keeps Friz Quadrata; SKIN-4 lists them). Since
  schema v16 (the owner's rulings of 2026-11-01, reversing X4 and D1) the colors, borders, shadow and
  the text glow follow too, each under a companion of its own: `Style.Followed` answers a skin
  color shaped as a stored one (`hud.text`, `hud.label`, `bar.fill`, `bar.bg`, `bar.border`,
  `icon.border`, `am.textGlow`), `Style.BorderLook` a block's style, thickness and color, and
  `S.HudFont` puts the face, size, flags and shadow on one font object per string. A class color
  comes first and has no companion; dispel colors and the running-out and pandemic tints stay. Show
  border and sizes stay the player's. Ka0s Default keeps this addon's pixels through two owner
  tokens: `am.iconBorderSize` (1 px) and `am.textGlow` (black). The gloss is the one recorded paint
  on a bar: `am.sheen`, a clear status bar laid over the visible fill, because `am.bar`'s own fill is
  the invisible elapsed part. Since LibKa0s
  v1.82.0 two follow the skin without being rewritten: a block on the skin's face draws at
  `S.HudFontSize(stored)`, scaled to Ka0s Default's width (D-09), and a Font flags of *From skin*
  (`"@skin"`, every block's default; schema v14 moved the old default OUTLINE onto it, D-07) draws
  `S.FontFlags`, the Skin tab's Font outline (`skin.outline`, applied by `NS.ApplySkinOutline`, D-06).
  A flag the player picked draws as picked.
  One `OnLooksChanged` listener (`modules/ContainerManager.lua`) primes the fonts and re-applies every
  container; under lockdown the apply waits for combat to end (D12). Schema v13 turned every stored
  companion on once (O2), which visibly changes Ka0s Default's HUD (X5): Oxanium and the Ka0s
  Default bar in place of Friz Quadrata and Blizzard. Schema v15 turned it back off, once, on every
  block whose stored face is the player's own (neither the skin's HUD face nor the template's Friz
  Quadrata), so the owner's Ka0s Kait Text containers and their glow came back (D-15). Schema v16
  turns it on again with every other companion; the stored face waits for the player to untick it.
- **The drag strips re-fit after a repaint.** The widget calls `Anchors.Refit` (its `onRefit`,
  DragHandle minor 8, D-12) after every repaint of the skin: a shown strip takes its label again in
  the new face (the shortened label is cached per face and scale) and, out of combat, is re-placed.
- **The unlock furniture** (the drag strip and its tooltips, the outline, the drag-to-attach marks,
  the frame picker) repaints from tokens on `OnLooksChanged`
  (`modules/Anchors.lua`, `Anchors_Snap.lua`, `Container.lua`, `FramePicker.lua`, `Preview.lua`); the
  strip's library parts follow the `owner` handed to `KW.DragHandle`.
- **Settings and tools.** The library paints the pages, the composed rows, the debug console, its
  copy window, the perf panel and the close marks for the owner already named. What this addon
  acquires itself, the `AuraMasterDropdown` widgets, the hand-built buttons, edit boxes and label,
  and the Profiles page, goes through `NS.SkinPaintAce` and `NS.SkinPaintAceTree`, and stays stock
  while **Ignore settings panel** is on. The pages' own markup (plan warnings, notes, the gold
  emphasis, the **See spells** link) colors through `NS.PanelEscape`, which answers Ka0s Default's
  bytes while that switch is on, so a stock page never carries skinned notes (D-03 of
  Ka0sAddonsCommonTasks `docs/2026-10-30-SKIN_LIBRARY_FOLLOWUPS/`). The debug console, its copy window,
  the perf panel and the drag strip are windows: they wear the skin whatever that switch says, and
  their strings obey Ignore fonts (D-01).
- **The first-run skin picker.** `NS.MaybeShowSkinPicker` shows `O.SkinPicker` two seconds after the
  first world entry and after every profile event while the profile's `skin.pickerSeen` is false and
  the addon stands up (O3); in combat it waits for `PLAYER_REGEN_ENABLED`. Its eye turns test mode
  on; the player's close writes `pickerSeen`, and a close the addon makes (`NS.HideSkinPicker`) does
  not. `/am skin` (`NS.RunSkinVerb`, LibKa0s v1.82.0's `O.SkinVerb`, D-16) shows the same picker on
  demand, whatever `pickerSeen` says. Since LibKa0s v1.83.0 the picker also carries the Skin tab's
  Font, Texture, Font outline and Scope rows: a change previews and writes nothing, Apply or the gear
  saves it through `NS.WriteSkinChoice`, and a dismissal puts back what the window opened with.
- **EllesmereUI.** The library's provider: with source `eui` and its gate holding, EllesmereUI's
  facade paints; otherwise the addon wears its Ka0s skin and the Skin tab says why.
- **The color gate.** `tests/test_skin_literals.lua` fails on a numeric color literal in a paint call
  or a `|cff` escape in code outside `core/SkinSetup.lua` and its named allow-list: chat output (X7),
  the dispel-type and identity palettes (rung 4, D8) and the engine-tinted strips.

## Frame layering

Strata picks a frame's tier and frame level orders it within the tier (frame-layering-§1 to §5). The
one layers table, `NS.Constants.LAYERS` in `core/Constants.lua`, names every strata and level band
the addon writes, and its header comment states the whole stack, including the tiers the library and
Blizzard own. The tiers:

- **HUD content (T1p).** Each container draws in the strata its player picked (`layout.strata`,
  default Medium) over its anchor's level `L` (`layout.level`). The engine and its buttons sit at
  `L+1` and up, and the name label at `L+20`. Inside one element, every frame is counted from the
  button: fill, spark, border, dispel edge, then the texts.
- **Edit chrome (T2).** The chrome stays in the container's strata. The unlocked outline sits at
  `L+30` and the drag strip at `L+50`. The strip ignores the
  container's opacity.
- **Modals (T6) and their child window (T7).** These belong to the library and Blizzard: the debug
  console, the perf panel and the StaticPopups at Dialog, and the console's copy window at
  Fullscreen.
- **Popups (T8).** The drag-time snap highlight sits at Fullscreen Dialog, alongside the library's
  menus and suggestion lists and the AceGUI pullouts.
- **Cursor (T9).** The frame picker sits at Tooltip, because it labels the frame under the cursor,
  and that frame's own tooltip would otherwise cover the label.

The Frame strata row's tooltip (Layout → Scale and strata) is the library's `O.StrataTooltip`. A player can still pick Dialog, so the
tooltip says what Dialog covers.

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
starts. A Text line's glow costs `C.TEXT_GLOW_TWINS` twin engines, each with its own `UNIT_AURA`
work; a twin could break a sort tie differently from its main, runs its loop a few frames out of
phase, and under a hand-set Width its ring and paired shadow are clipped at its own box. Every
limitation, its cause and any ruling: `docs/known-limitations.md`.

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
| `settings-panel.md` | The `Page \| Tabs \| Covers` table, the page → tab → row tree, per-option behavior and schema keys; the launcher |
| `data-flow.md` | Settings → filter plan → aura groups → the engine renders; the filter priority; lifecycle, deferral and the disabled state |
| `common-tasks.md` | Recipes for the changes made most often here, naming real files; the locale-routing rule and its one exemption |

### Conditional (documentation-§3, Tier 2)

| Doc | Status | Trigger |
|---|---|---|
| `perf-analysis/README.md` | Present | The performance harness is wired (`core/PerfSetup.lua`) |
| `slash-dispatch.md` | Present | 26 commands in `NS.COMMANDS`, over the eight-or-more threshold |
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
| `frame-layering-§3` | Two levels are counted from a sibling, not the parent. The mouse blocker sits `LAYERS.LEVEL.BLOCKER` under the engine's current level (`ContainerClass:ApplyBlocker`). Each text-glow twin sits `GLOW_GAP` under the main engine, and its holder `GLOW_HOLDER` under that (`modules/Container_Twins.lua`). With `L = 5` a holder sits below the anchor. | A later `layout.level` raises the anchor, but the engine does not follow it, so only the engine's own current level keeps the blocker under it. The twins must sit under the main's whole text-and-icon stack, which is a fixed gap below the main and not a band over the anchor. The holders carry glow copies only. | 2026-10-24, the owner accepted AUR-Z10 (the frame-layering run, item 030). The values are unchanged and named in `NS.Constants.LAYERS`. | The engine follows its anchor's level, or the glow stops using twin engines. |
| `layout-§1` | `defaults/Categories.lua` stays in the 1000–1500 band (1344 lines). `Cat.HELPFUL` and `Cat.HARMFUL` are not split across files. | The file is data: hand-curated spell ids, 8 functions, max CCN 4. `tools/spell-research/logs.py` is the only writer of those lists and rewrites this one path, and `sid_db2.py` tells a buff list from a debuff list by where it sits around `Cat.HARMFUL =` in this one file. A split would change the tool chain, so it is not a pure move. Tracks anti-pattern #53. | 2026-10-31 (FX-AM-SIZE) | The file reaches 1400 lines, or the spell-research tools are reworked to read more than one file. |

### Files over the 1500-line cap

No authored file is over the cap; the census is measured by tests/_kit/test_layout_cap.lua.
