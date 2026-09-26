# Architecture — Ka0s Aura Master

The engineer's hub for this addon. Each mandated section summarizes and links out; the detail lives
in the topic docs registered under [Documentation map](#documentation-map) (documentation-§3).

## Overview

Ka0s Aura Master draws player-built aura **containers**. A container is one unit (`player`,
`target`, `focus`, `pet` — `core/Constants.lua:39`), one aura type (`HELPFUL` or `HARMFUL` — `:45`;
the player's temporary weapon enchants are the buff category `weaponEnchants`, schema v5) and one style (`bars`, `icons` or
`text` — `:49`), plus its filters, placement and look. A profile holds any number of them; a fresh
profile is seeded with four (`NS.STARTER_CONTAINERS`, `defaults/Profile.lua:283`).

**The design is dictated by one client fact.** On Retail 12.1 an addon cannot read aura data while
auras are secret — combat, encounters, Mythic+ and PvP (`core/Secrets.lua`, `docs/midnight-quirks.md`).
So this addon reads no aura at all. Every container is a Blizzard **AuraContainer**
(`CreateFrame("AuraContainer", nil, anchor, "CustomAuraContainerTemplate")`,
`modules/Container.lua:219`) that registers `UNIT_AURA` for its unit, gathers, sorts, lays out and
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
`settings/` (layout-§1) — 51 authored Lua files under them: one locale, 16 core, 4 defaults, 16
modules and 14 settings. The load-bearing positions are annotated at their TOC lines:
`core/MediaSetup.lua` before `core/Constants.lua` (the monospace face), `core/CoreSetup.lua` before
anything that prints, `core/PerfSetup.lua` before every module that takes `NS.Perf` as an upvalue,
`defaults/Categories.lua` before `defaults/Profile.lua` (the template's category states) and
`defaults/UserCategories.lua` directly after it (the `NS.Categories` upvalue),
`settings/OptionsSetup.lua` before every page file (the composers run at file load), and
`settings/GeneralSpells.lua` then `settings/GeneralDispel.lua` (which reads its bullet constants), both
before `settings/General.lua`, which registers their rows after its own.
The Settings tree's order is the TOC's own registration order (`N-2`): General, then Containers,
then its five sub-pages — Filters, Layout, Bars, Icons and Text, each marked with
`NS.SubPageLabel`'s indent (`D6`, `settings/OptionsSetup.lua`) — then Profiles.

The engine-facing core is four modules: `modules/FilterCompiler.lua` (settings → groups, pure; the
profile's spell-category edits reach it through `FC.ProfileContext`), `modules/Container.lua` (one
engine), `modules/ContainerManager.lua` (the registry and the deferred apply, each container's apply
guarded so one error cannot drop the rest of the pass) and `modules/Style.lua` with its three style
files (`Style_Bars.lua`, `Style_Icons.lua` and `Style_Text.lua`, chosen per container by
`Style.Styler`), plus the pure template parser the Text style draws from
(`modules/TextTemplate.lua`). Placement is `modules/Anchors.lua`. A container attached to another
continues its chain root's flow (`Anchors.EffectiveLayout`) and joins it by two absolute points,
`attach.childPoint` and `attach.relPoint`, each Automatic while unset (`Anchors.AttachPoints`,
batch 11 G2, G3); a pair that is one of batch 9's nine sides keeps that side's seam and spread
(`Anchors.AttachEdge`, G5), and any other is placed at its X/Y alone. A write to a
flow or attachment path re-applies its followers (`Anchors.Followers`) and its parent. While a container previews,
the containers attached to it hang from `Preview.Extent`, a frame of ours sized to its placeholder
block; while it is unlocked, not previewing and predicted empty (`modules/EmptyWatch.lua`, batch 9
HG-1), from its one-element anchor, which its placeholder outline marks; otherwise from its engine
(`Anchors.HangMode`, re-placed by `Anchors.PlaceAttached`). Previewing is the session-only **test mode**
(`NS.State.testMode`, switched only by `Preview.SetTestMode`): every container shows its placeholder
auras. Unlocking is separate: it makes containers draggable while their live auras keep drawing,
each under its drag handle, and one predicted empty under a faint outline one element in size, so an
empty container can still be found and dragged. The handle's close mark (X) turns that container off through the write
seam. A container can also show its name as a label where the handle sits, locked or unlocked;
while unlocked the handle moves out past it (`Anchors.PlaceLabel`, batch 8 D6).

Every non-vendored file, its responsibility and the full load order: `docs/module-map.md`.

## Settings Schema

`NS.Schema` holds **258** rows across seven pages (General 18, Containers 5, Filters 46, Layout 38,
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
| `Ka0s_AuraMaster_ContainersChanged` (`NS.MSG.CONTAINERS_CHANGED`) | `modules/ContainerManager.lua` — create, delete, rename, duplicate, profile change (copy-from and reset positions are settings writes, announced by `CONFIG_CHANGED`) | none | `settings/OptionsSetup.lua:384` — `NS.RequestPanelRefresh`, a coalesced panel re-render (every banner lists containers); `modules/TimedSpells.lua:204` — `TS.Sync`, which starts or stops the timed-spell scan (a container added or removed can change whether any needs it) |
| `Ka0s_AuraMaster_ConfigChanged` (`NS.MSG.CONFIG_CHANGED`) | `settings/Schema.lua:579` — the write seam, once per write; never for a session row | `{ section, containerId, path }`; `containerId` nil for an addon-wide row, `path` the row written | `modules/ContainerManager.lua:618` — by the row's `effect`: `"visibility"` runs `ApplyVisibility()` at once, `"none"` queues nothing, otherwise `RequestApply(containerId)` (nil re-applies all), a write to a flow or attachment path also re-applies every container following that one (`Anchors.Followers`), and a write to a container's attach points, mode or target also re-applies the container it attaches to (`requestParents`); `modules/TimedSpells.lua:203` — `TS.Sync`, the same re-sync (a filter write can change whether any container needs the scan) |
| `Ka0s_AuraMaster_VisibilityChanged` (`NS.MSG.VISIBILITY_CHANGED`) | `core/AuraMaster.lua` — entering the world, combat start and end; `modules/Preview.lua` — `Preview.SetTestMode`, when test mode switches on or off | none | `modules/ContainerManager.lua:629` — `ApplyVisibility()` over every container |
| `Ka0s_AuraMaster_TimedSpellsChanged` (`NS.MSG.TIMED_SPELLS_CHANGED`) | `modules/TimedSpells.lua` — a scan learned timed spells, or `/am forgettimed` emptied the set | none from a scan; `{ byPlayer = true }` from `/am forgettimed` | `modules/ContainerManager.lua` `CM.Init` — `RequestApply(nil, system)` over every container (their excluded ids moved); a scan's request is the addon's own, so a deferral of it prints no notice |

Four messages, well under the more-than-ten trigger for a separate `message-bus.md`.

## Slash Commands

`/am` with `/auramaster` as the long alias, dispatched by `LibKa0s-Slash-1.0` over the addon's own
ordered `NS.COMMANDS` (`settings/Slash.lua:39`). Twenty-three verbs; `options` is an alias of `config`.
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
| `/am debug [on\|off\|diagnostics]` | Toggle the debug console; `on`/`off` enable or disable logging; `diagnostics` writes the diagnostic report, the same as `/am diagnostics` |
| `/am diagnostics` | Write the diagnostic report to the debug console (`docs/debug.md`); answers while disabled |
| `/am perf …` | Measure performance — bare `/am perf` opens the workflow |
| `/am version` | Print the addon version |

**While the addon is disabled** the eight verbs that drive its features — `new`, `delete`, `lock`,
`unlock`, `test`, `pick`, `resetposition`, `forgettimed` — answer on one tagged line naming `/am enable` and
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
| `PLAYER_ENTERING_WORLD` | `core/AuraMaster.lua:59` (AceEvent, through `NS.SafeRegisterEvent`) | `OnEnterWorld` → `VISIBILITY_CHANGED`, `ContainerManager.FlushPending` |
| `PLAYER_REGEN_DISABLED` | `core/AuraMaster.lua:60` | `OnCombatChanged` → `VISIBILITY_CHANGED` |
| `PLAYER_REGEN_ENABLED` | `core/AuraMaster.lua:61` | `OnCombatChanged` → `VISIBILITY_CHANGED`, `FlushPending`, `ReapplyStaleClass`, `BlizzardFrames.Apply`, `Anchors.ResolvePending` (a frame that appeared during combat) |
| `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED` | `core/AuraMaster.lua:62-63` | `OnUnitSwap` → `RefreshUnit` → the engine's `UpdateAllAuras` (bucket `unitSwap`); re-applies the class-colored containers of that unit when the new unit's class differs, or marks them stale, silently, while an apply must wait |
| `UNIT_PET` | `core/AuraMaster.lua:64` | `OnUnitPet` (player only) → `RefreshUnit("pet")` (bucket `unitSwap`); re-applies the class-colored pet containers when the pet's class differs, or marks them stale while an apply must wait |
| `ADDON_LOADED` | `core/AuraMaster.lua:65` | `OnAddonLoaded` → `Anchors.ResolvePending` (frame-attached containers) |
| `ADDON_RESTRICTION_STATE_CHANGED` | `core/AuraMaster.lua:67` | `OnRestrictionChanged` → `FlushPending`, `ReapplyStaleClass` (a deferred apply runs when secrecy lifts) |
| `UNIT_AURA` for `player` and `pet` | `modules/TimedSpells.lua` — the module's one private frame, `TS.unitFrame` (events-frames-taint-§1's carve-out: the vendored AceEvent has no `RegisterUnitEvent`), through `NS.SafeRegisterUnitEvent`; built once and reused, registered only while a container uses "without a duration", the addon is not suspended, and auras are readable (no combat lockdown, not secret), and unregistered by hand in `TS.Stop` | the frame's one `OnEvent` → `onUnitAura`: the client delivers only `player` and `pet`; the handler still proves the unit a safe key and compares it (defense in depth), then schedules a scan 0.5 s later (bucket `timedScan`). A scan that comes due after the gate closed is dropped too |
| `UNIT_AURA` for `player` and `pet`, and for `target` and `focus` | `modules/EmptyWatch.lua` — its two private frames, `EW.unitFrames[1]` (player, pet) and `[2]` (target, focus), the same carve-out, each filtering `UNIT_AURA` and nothing else, through `NS.SafeRegisterUnitEvent`; built once and reused, each registered only while a shown container on its units is unlocked and out of test mode, the addon is not suspended, combat has not started and auras are readable, and unregistered by hand in `EW.Stop` | the frames' one `OnEvent` only marks a pass due: one pass 0.2 s later (bucket `emptyPass`) re-predicts every watched container and re-runs the visibility pass of any whose answer changed |
| `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED` | `modules/EmptyWatch.lua` (AceEvent, on its own target) — while its target and focus frame is registered | the pass run at once, not 0.2 s later, folding in one already due: the engine redraws for the new unit in the same frame, so a follower hung from a parent that just emptied would otherwise sit on the engine's 1x1 rect for the delay |
| `UNIT_PET`, `UNIT_INVENTORY_CHANGED` | `modules/EmptyWatch.lua` (AceEvent, on its own target) — while its player and pet frame is registered | the same pass marked due, for the `player` unit only |
| `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`, `ADDON_RESTRICTION_STATE_CHANGED` | `modules/TimedSpells.lua` (AceEvent, on its own target) — while a container uses "without a duration" and the addon is not suspended | `syncAuraListen`: `PLAYER_REGEN_DISABLED` closes the readable gate by itself (it fires before combat lockdown begins); the other two re-check it, dropping or restoring `UNIT_AURA`; reopening schedules one scan |
| AceDB `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset` | `core/Database.lua:275-279` | `NS.OnProfileChanged` / `NS.OnProfileCopied` / `NS.OnProfileReset` → re-prepare the registry, trace the event once in its own words (a switch `[Profile] changed -> X`; a copy or a reset one `[Set]` line, debug-logging-§10), rebuild, re-render |

Each container's own `UNIT_AURA` belongs to the engine (`SetUnit`, `modules/Container.lua:264`) and
is not addon code. The eight `core/AuraMaster.lua` registrations are one module-level list,
`LIFECYCLE_EVENTS`, which `RegisterLifecycleEvents` and `UnregisterLifecycleEvents` both walk, so the
stand-down and the stand-up remove and restore the same list.

**Every registration goes through one helper** (events-frames-taint-§1): `NS.SafeRegisterEvent`, which
is `LibKa0s-Core-1.0`'s `SafeRegisterEvent`, published by `core/CoreSetup.lua`. That covers every row
above and the stand-down's pending `PLAYER_REGEN_ENABLED`, except the unit frames' `UNIT_AURA` (TimedSpells' one, EmptyWatch's two), which
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
goes through the engine's `SetEnabled`; protected opens and frame-creating verbs are refused in
combat, and a teardown under lockdown is parked; every engine binding is `pcall`-guarded; no border
reads a secret size; and secret values never reach a string operation. Every rule and the code that
keeps it: `docs/midnight-quirks.md` → *Taint notes*.

## Known Limitations

Units stop at player, target, focus and pet. Nothing structural happens while auras are secret or
under lockdown, so settings changes, teardown and class colors wait for it to lift. The engine bounds
what a Text line can do, which spell-id filters it honors, and when a non-Solid border redraws. A
handful of user-category trade-offs were accepted by the owner. Every limitation, its cause and any
ruling: `docs/known-limitations.md`.

## Documentation map

Every `.md` under `docs/` appears in exactly one table below (documentation-§3). Frozen and
generated directories are named once and never enumerated: `docs/audits/`, `docs/reviews/`,
`docs/automated-tests/<run>/`, `docs/perf-analysis/<run>/`, `docs/revendor/<date>-v<tag>/` (a
span bundle is `<date>-v<A>-v<B>/`), `docs/superpowers/`.

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
| `slash-dispatch.md` | Present | 23 commands in `NS.COMMANDS`, over the eight-or-more threshold |
| `midnight-quirks.md` | Present | Client-version workarounds of the addon's own: 12.1 aura secrecy and the aura container engine, and the taint notes that follow from them |
| `compat-layer.md` | Present | 22 shims in `core/Compat.lua`, over the three-or-more threshold |
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
| `documentation-§1` | README's `## Screenshots` section (item 4) is a placeholder with no captioned images | The addon is published: the TOC has carried `X-Curse-Project-ID: 1698345` (AuraMaster.toc:13) since a326ed7 (2026-09-16), so item 4 is a MUST, not a SHOULD. Screenshots can only be captured in a live client and none exist yet, so the section says so in one line, points at the capture issue and shows nothing; images are never fabricated. Audit docs/audits/2026-09-11 AM-20; the capture is tracked as issue tusharsaxena/AuraMaster#3. First ratified by the owner 2026-09-12, when the addon was unpublished; restated for a published addon 2026-09-24 (remediation AM-32) and stands only on the owner's re-ratification, failing which the row is deleted and the finding stays open on issue #3. | 2026-09-12 (restated 2026-09-24, re-ratification pending) | Retired when captioned images from `media/screenshots/` land in README `## Screenshots` (issue #3) |

### Files over the 1500-line cap

No authored file is over the cap; the census is measured by tests/_kit/test_layout_cap.lua.
