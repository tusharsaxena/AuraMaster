# Architecture — Ka0s Aura Master

The engineer's hub for this addon. Each mandated section summarizes and links out; the detail lives
in the topic docs registered under [Documentation map](#documentation-map) (documentation-§3).

## Overview

Ka0s Aura Master draws player-built aura **containers**. A container is one unit (`player`,
`target`, `focus`, `pet` — `core/Constants.lua:33`), one aura type (`HELPFUL`, `HARMFUL`, or
`ENCHANT` for the player's temporary weapon enchants — `:39`) and one style (`bars` or `icons` —
`:43`), plus its filters, placement and look. A profile holds any number of them; a fresh profile is
seeded with three (`defaults/Profile.lua:188`).

**The design is dictated by one client fact.** On Retail 12.1 an addon cannot read aura data while
auras are secret — combat, encounters, Mythic+ and PvP (`core/Secrets.lua`, `docs/midnight-quirks.md`).
So this addon reads no aura at all. Every container is a Blizzard **AuraContainer**
(`CreateFrame("AuraContainer", nil, anchor, "CustomAuraContainerTemplate")`,
`modules/Container.lua:181`) that registers `UNIT_AURA` for its unit, gathers, sorts, lays out and
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
driving a bar. The one aura-driven Lua path is the readable-state timed-spell scan
(`modules/TimedSpells.lua`), bracketed `timedScan`. It runs only while a container shows auras
without a duration, and only out of combat with auras readable. The full pipeline is in
`docs/data-flow.md`.

### Libraries and what this addon does with each

All vendored under `libs/`, loaded by the `# Libraries` block of `AuraMaster.toc:15-30`.

| Library | Used for |
|---|---|
| LibStub, CallbackHandler-1.0 | Library registry; AceEvent's and AceDB's callbacks |
| AceAddon-3.0 | `NS` promoted to the addon object (`core/AuraMaster.lua:17`) |
| AceEvent-3.0 | Lifecycle events and the message bus (`core/Bus.lua`) |
| AceTimer-3.0 | The color picker's drag throttle, via the options descriptor's `scheduleTimer` |
| AceConsole-3.0 | `/am` and `/auramaster` registration (`settings/Slash.lua:379-380`) |
| AceDB-3.0 | `AuraMasterDB` and its profiles (`core/Database.lua:215`) |
| AceGUI-3.0, AceGUI-3.0-SharedMediaWidgets | The settings panel body and its `LSM30_*` media dropdowns |
| AceConfig-3.0, AceDBOptions-3.0 | The Profiles sub-page only (`settings/Profiles.lua`, options-ui-§3) |
| LibSharedMedia-3.0 | Texture, border and font lookups (`modules/Style.lua:26`) |
| LibKa0s v1.33.0 | Eight modules wired, one setup file each — table below |

| LibKa0s module | Setup file | Publishes |
|---|---|---|
| `LibKa0s-Media-1.0` | `core/MediaSetup.lua` | `NS.Icon`, `NS.MediaFont`, the LSM registration |
| `LibKa0s-Env-1.0` | `core/EnvSetup.lua` | `NS.Meta`, `NS.Version` |
| `LibKa0s-Core-1.0` | `core/CoreSetup.lua` | `NS.Print`, `NS.Printf`, `NS.SafeToString`, `NS.ResolveColor`, `NS.ClassColor`, `NS.MakeCloseButton` |
| `LibKa0s-Pool-1.0` | `core/PoolSetup.lua` | `NS.Pool` (preview element pools) |
| `LibKa0s-Perf-1.0` | `core/PerfSetup.lua` | `NS.Perf` (buckets, `/am perf`, suspend) |
| `LibKa0s-DebugLog-1.0` | `core/DebugLogSetup.lua` | `NS.DebugLog`, `NS.Debug` |
| `LibKa0s-Slash-1.0` | `settings/Slash.lua` | the `/am` dispatcher over `NS.COMMANDS` |
| `LibKa0s-Options-1.0` | `settings/OptionsSetup.lua` | `NS.Helpers` (the panel shell, flow engine, composers) |

`LibKa0s-Item-1.0` and `LibKa0s-Widgets-1.0` arrive with the whole-folder copy (library-stack-§7)
and are not bound by name here; the addon handles no items. Every setup file degrades to a stub when
the library is absent, exercised by `tests/degraded_env.lua`.

## Module Map

Five source folders in the TOC's load order — `locales/` → `core/` → `defaults/` → `modules/` →
`settings/` (layout-§1) — 39 authored Lua files under them: one locale, 14 core, 2 defaults, 11
modules and 11 settings. The load-bearing positions are annotated at their TOC lines:
`core/MediaSetup.lua` before `core/Constants.lua` (the monospace face), `core/CoreSetup.lua` before
anything that prints, `core/PerfSetup.lua` before every module that takes `NS.Perf` as an upvalue,
`defaults/Categories.lua` before `defaults/Profile.lua` (the template's category states), and
`settings/OptionsSetup.lua` before every page file (the composers run at file load).

The engine-facing core is four modules: `modules/FilterCompiler.lua` (settings → groups, pure),
`modules/Container.lua` (one engine), `modules/ContainerManager.lua` (the registry and the deferred
apply) and `modules/Style.lua` with its two style files (dressing a button).

Every non-vendored file, its responsibility and the full load order: `docs/module-map.md`.

## Settings Schema

`NS.Schema` holds **193** rows across six pages — General 9, Containers 5, Filters 40, Layout 26,
Bars 71, Icons 42 — plus the AceConfig-drawn Profiles page, which carries none. It drives the panel,
`/am list|get|set|reset` and the resets; one write seam, `NS.SetByPath` (`settings/Schema.lua:546`),
is where the panel, the CLI, the Defaults buttons and a drag handle all land. It validates, resolves
the container, runs the row's optional `normalize` hook, writes, reacts and announces, in that order.
The name row's hook stores container names unique, case-insensitively. A bulk copy or reset (a page's
Defaults, Reset all, `ContainerManager.CopyFrom`, `ContainerManager.ResetPositions`) runs inside
`NS.Bulk`'s bracket: the seam mutes its per-row `[Set]` line, tallies the rows each write changed as
it stores them, and the act logs one `[Set] <act> <scope>: N rows` line. An act that an error stops
still logs that line once, ending ` (stopped by an error)`. A whole-profile reset is logged by
`NS.OnProfileReset` alone, as `[Set] reset profile '<name>' to defaults` with no row count
(debug-logging-§10 allows omitting it). A reset re-seeds the starter containers, so counting rows not
at default would overcount. AceDB also gives no hook before the wipe, so the Profiles page's reset
cannot cheaply snapshot the rows it changes (`docs/schema.md`, `docs/profiles.md`).

Almost every row belongs to one container, so container rows use a **relative path**:
`container.bars.width` resolves against the container the settings banner has selected
(`NS.State.activeContainerId`), falling back to the first one. Addon-wide rows keep absolute paths
(`enabled`, `hideBlizzardBuffs`). A row's `default` is never typed in a page file —
`NS.RegisterSchemaRows` stamps it from `defaults/Profile.lua`, and `NS.ValidateSchema` proves every
path resolves. Three whole-set carve-outs (`container.filter.whitelist`, `.blacklist`,
`.categorySpells`) and six whole-section paths (`container.filter`, `.layout`, `.behavior`,
`.position`, `.bars`, `.icons`) are written through the same seam and normalized there. A drag, a
copy between containers, a position reset and a delete's fallback to the screen all write that way.

The addon holds one structural registry, the containers (architecture-§5). No schema row addresses
it, and none can, since a row is a leaf.

- **Storage keys:** the profile's `containers` (members keyed by numeric id, each stamped with its
  `c.id`), `containerOrder` (display order), `nextContainerId` (the id counter) and `seeded` (the
  sentinel recording that first-run seeding has run).
- **Registry writer:** `modules/ContainerManager.lua`. `ContainerManager.Create`, `.Delete` and
  `.Duplicate` (through `Create`) make every runtime membership change, and
  `Database.NewContainerData` mints the id and stamps `c.id` for it. `NewContainerData` has no
  other caller, so it is part of the writer.
- **Load pass:** `Database.PrepareProfile` (`core/Database.lua`), run from `NS.RunMigrations` at
  initialization and from `NS.OnProfileChanged` on AceDB's profile changed, copied and reset
  callbacks, and from nowhere else. It runs `seedStarters`, `normalizeKeys`, `backfillContainers`,
  the `nextContainerId` bump and `rebuildOrder`.

A member field a row addresses goes through `NS.SetByPath` with a container id even when
ContainerManager is the caller: rename, copy-from, position reset and a delete's fallback to the
screen. The per-container `container.filter.whitelist`, `.blacklist` and `.categorySpells` sets are
values the seam takes whole at its carve-out paths, not registries. Only its named writer and
load pass write the registry, so it is compliant and carries no Documented deviations row.

The addon holds two pieces of named non-setting state (architecture-§5). The first is learned
data that no control sets and no row addresses.

- **Storage key:** `global.timedSpells` (`db.global.timedSpells`), `[spellId] = true` for every buff
  seen carrying a duration. It is account-wide, so a profile switch, copy or reset never touches it.
- **Owner:** `modules/TimedSpells.lua`.
- **Writers:** `TS.Scan` adds the id of each newly seen timed buff. The readable-state scan reaches
  it: `scanTick`, 0.5 s after a player or pet `UNIT_AURA` or after the readable gate reopens.
  `TS.Forget` replaces the set with `{}`, and `/am forgettimed` reaches it (`runForgetTimed` in
  `settings/Slash.lua`). That is the owner's forget operation. Nothing else writes it. `store()`
  lazily creates the empty table on first read and is not a writer, and neither is the load pass
  (`NS.RunMigrations` backfills it, as does the no-AceDB fallback in `NS.InitDB`). The two compile
  sites in `modules/Container.lua` and `settings/OptionsSetup.lua` hand it to `FilterCompiler.Compile`,
  which only reads it.

The second is recorded data that a vendored library writes into a key the addon hands it: the perf
capture ring. No control sets it and no row addresses it.

- **Storage key:** `AuraMasterPerfDB`, a SavedVariables global of its own (`AuraMaster.toc:7`),
  outside the AceDB tree, so a profile switch, copy or reset never touches it (performance-§5).
- **Owner:** `core/PerfSetup.lua`, which hands the key to `LibKa0s-Perf-1.0` as the descriptor's
  `sv`.
- **Writers:** the library's `P.Save`, and nothing else. `/am perf finish` reaches it. It appends the
  finished capture, drops the oldest record once the ring holds more than ten (the library's
  `DEFAULT_RING`, since this addon sets no `ring`), and discards a ring stored under an older record
  schema. No addon code writes it, and no verb clears it.

SavedVariables shape, every default and the migration path: `docs/schema.md`.

## Message Bus

A closed bus on AceEvent messages (`core/Bus.lua`, architecture-§4). Every receiver subscribes on its
own target from `NS.NewBusTarget()`, so no two receivers can clobber each other. There is
deliberately **no aura-data message**: the engine owns `UNIT_AURA` and nothing here reads an aura to
pass on.

| Message | Sender | Payload | Consumers |
|---|---|---|---|
| `Ka0s_AuraMaster_ContainersChanged` (`NS.MSG.CONTAINERS_CHANGED`) | `modules/ContainerManager.lua` — create, delete, rename, duplicate, profile change (copy-from and reset positions are settings writes, announced by `CONFIG_CHANGED`) | none | `settings/OptionsSetup.lua:246` — a coalesced panel re-render (every banner lists containers); `modules/TimedSpells.lua:154` — `TS.Sync`, which starts or stops the timed-spell scan (a container added or removed can change whether any needs it) |
| `Ka0s_AuraMaster_ConfigChanged` (`NS.MSG.CONFIG_CHANGED`) | `settings/Schema.lua:338` — the write seam, once per write; never for a session row | `{ section, containerId, path }`; `containerId` nil for an addon-wide row, `path` the row written | `modules/ContainerManager.lua:483` — by the row's `effect`: `"visibility"` runs `ApplyVisibility()` at once, `"none"` queues nothing, otherwise `RequestApply(containerId)` (nil re-applies all); `modules/TimedSpells.lua:153` — `TS.Sync`, the same re-sync (a filter write can change whether any container needs the scan) |
| `Ka0s_AuraMaster_VisibilityChanged` (`NS.MSG.VISIBILITY_CHANGED`) | `core/AuraMaster.lua` — entering the world, combat start and end | none | `modules/ContainerManager.lua:490` — `ApplyVisibility()` over every container |
| `Ka0s_AuraMaster_TimedSpellsChanged` (`NS.MSG.TIMED_SPELLS_CHANGED`) | `modules/TimedSpells.lua` — a scan learned timed spells, or `/am forgettimed` emptied the set | none from a scan; `{ byPlayer = true }` from `/am forgettimed` | `modules/ContainerManager.lua` `CM.Init` — `RequestApply(nil, system)` over every container (their excluded ids moved); a scan's request is the addon's own, so a deferral of it prints no notice |

Four messages, well under the more-than-ten trigger for a separate `message-bus.md`.

## Slash Commands

`/am` with `/auramaster` as the long alias, dispatched by `LibKa0s-Slash-1.0` over the addon's own
ordered `NS.COMMANDS` (`settings/Slash.lua:33`). Twenty-two verbs; `options` is an alias of `config`.

| Command | What it does |
|---|---|
| `/am help` | List available commands |
| `/am config` | Open the settings panel |
| `/am enable` | Turn Aura Master on (every enabled container shows again) |
| `/am disable` | Turn Aura Master off (hides every container) |
| `/am list` | List every setting and its current value (container settings read the selected container) |
| `/am get path` | Print a setting's current value |
| `/am set path value` | Set a setting |
| `/am reset path` | Reset one setting to its default |
| `/am resetall` | Reset every setting to defaults (a profile reset) |
| `/am containers` | List your containers; the selected one is marked |
| `/am select id-or-name` | Choose the container settings apply to |
| `/am new [unit] [type] [style]` | Create a container (`player`/`target`/`focus`/`pet`, `buffs`/`debuffs`/`enchants`, `bars`/`icons`) |
| `/am delete id-or-name` | Delete a container |
| `/am lock` | Lock every container in place |
| `/am unlock` | Unlock containers so they can be dragged (shows placeholder auras) |
| `/am test [on\|off]` | Show placeholder auras (preview mode) |
| `/am pick` | Attach the selected container to a frame by clicking it |
| `/am resetposition` | Move every container back to its default screen position |
| `/am forgettimed` | Forget which buffs were learned to have a duration |
| `/am debug [on\|off]` | Toggle the debug console; `on`/`off` enable or disable logging |
| `/am perf …` | Measure performance — bare `/am perf` opens the workflow |
| `/am version` | Print the addon version |

Dispatch, the host verbs, the container-relative paths and the degraded path: `docs/slash-dispatch.md`.

## Event Subscriptions

| Event | Registered by | Handler → effect |
|---|---|---|
| `PLAYER_ENTERING_WORLD` | `core/AuraMaster.lua:44` (AceEvent) | `OnEnterWorld` → `VISIBILITY_CHANGED`, `ContainerManager.FlushPending` |
| `PLAYER_REGEN_DISABLED` | `core/AuraMaster.lua:45` | `OnCombatChanged` → `VISIBILITY_CHANGED` |
| `PLAYER_REGEN_ENABLED` | `core/AuraMaster.lua:46` | `OnCombatChanged` → `VISIBILITY_CHANGED`, `FlushPending`, `ReapplyStaleClass`, `BlizzardFrames.Apply`, `Anchors.ResolvePending` (a frame that appeared during combat) |
| `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED` | `core/AuraMaster.lua:47-48` | `OnUnitSwap` → `RefreshUnit` → the engine's `UpdateAllAuras` (bucket `unitSwap`); re-applies the class-colored containers of that unit when the new unit's class differs, or marks them stale, silently, while an apply must wait |
| `UNIT_PET` | `core/AuraMaster.lua:49` | `OnUnitPet` (player only) → `RefreshUnit("pet")` (bucket `unitSwap`); re-applies the class-colored pet containers when the pet's class differs, or marks them stale while an apply must wait |
| `ADDON_LOADED` | `core/AuraMaster.lua:50` | `OnAddonLoaded` → `Anchors.ResolvePending` (frame-attached containers) |
| `ADDON_RESTRICTION_STATE_CHANGED` | `core/AuraMaster.lua:52` | `OnRestrictionChanged` → `FlushPending`, `ReapplyStaleClass` (a deferred apply runs when secrecy lifts) |
| `UNIT_AURA` | `modules/TimedSpells.lua` (AceEvent, on its own target) — only while a container uses "without a duration", the addon is not suspended, and auras are readable (no combat lockdown, not secret) | `onUnitAura`: a safe-key `player`/`pet` schedules a scan 0.5 s later (bucket `timedScan`); every other unit is dropped. A scan that comes due after the gate closed is dropped too |
| `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`, `ADDON_RESTRICTION_STATE_CHANGED` | `modules/TimedSpells.lua` (AceEvent, on its own target) — while a container uses "without a duration" and the addon is not suspended | `syncAuraListen`: `PLAYER_REGEN_DISABLED` closes the readable gate by itself (it fires before combat lockdown begins); the other two re-check it, dropping or restoring `UNIT_AURA`; reopening schedules one scan |
| AceDB `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset` | `core/Database.lua:218-222` | `NS.OnProfileChanged` / `NS.OnProfileCopied` / `NS.OnProfileReset` → re-prepare the registry, trace the event once in its own words (a switch `[Profile] changed -> X`; a copy or a reset one `[Set]` line, debug-logging-§10), rebuild, re-render |

Each container's own `UNIT_AURA` belongs to the engine (`SetUnit`, `modules/Container.lua:226`) and
is not addon code. The eight `core/AuraMaster.lua` registrations live in one function,
`RegisterLifecycleEvents`, so the perf probe's suspend and resume remove and restore the same list.

## Taint Notes

- **No secure template of our own.** The only protected machinery is Blizzard's aura engine. Each
  container's anchor (`AuraMasterAnchor<id>`) inherits `DisableUntrustedLayoutScriptsTemplate`,
  Blizzard's opt-in for a frame anchored to an aura container (`modules/Container.lua:38-41`).
- **Nothing under an anchor may own a tooltip.** The template's restriction reaches every frame
  anchored under the anchor, the drag handle and its help mark included, and the client refuses
  `GameTooltip:SetOwner` on any of them ("Anchoring disallowed as dependent object would inherit
  forbidden aspects: UntrustedLayoutScriptExecution"). The handle's tooltip is therefore owned by
  `UIParent` and follows the cursor (`modules/Anchors.lua`, `showTooltip`).
- **Anchors stay out of the client's layout cache.** An anchor is movable (a handle drag moves it
  with `StartMoving`), and the client saves a movable frame's position and restores it at login.
  `Container.New` calls `SetDontSavePosition(true)`, so the stored `container.position` is the only
  position an anchor ever has.
- **The drag handle sits outside the anchor and never re-anchors anything.** It is our own strip,
  placed against the anchor on the side the auras do not grow into; the anchor, the engine and the
  preview stay where they are. While it shows, the anchor's clamp rect is widened over it
  (`SetClampRectInsets`). Placing the strip and widening the clamp both happen only out of combat,
  because the anchor parents an aura engine: under lockdown the handle keeps its last placement and
  only shows or hides, except that a handle never placed (first shown in combat) is placed once so
  it draws. The next visibility pass after combat catches both up.
- **The engine is anchored before its first `AddAuraGroup`**; after that an addon can no longer
  anchor it (`modules/Container.lua:185-189`).
- **No structural work while auras are secret or under combat lockdown.** `ContainerManager.MustDefer`
  (`modules/ContainerManager.lua:155`) holds every build, update and restyle; aura buttons refuse addon
  access while auras are secret.
- **Visibility in combat goes through the engine's `SetEnabled`**, never `Show`/`Hide` on an aura
  button's ancestry (`modules/Container.lua:380`).
- **Blizzard's `BuffFrame` and `DebuffFrame` are reparented, never hidden**, and only out of combat
  (`modules/BlizzardFrames.lua`, events-frames-taint-§3).
- **Protected opens are refused, not deferred.** The options panel (the library, options-ui-§2),
  `NS.OpenOptionsPage` (`settings/OptionsSetup.lua:216`), the frame picker and a handle drag all
  refuse under `InCombatLockdown()`.
- **Teardown under lockdown is parked, never hidden.** A container that leaves the registry while
  `MustDefer` is true is parked (`Container:Park`): its engine is disabled through `SetEnabled`, its
  preview and handle (our own frames) are hidden, and the anchor and engine ancestry are left alone.
  The next `FlushPending` that may touch frames destroys it; if its id comes back first, the same
  instance is revived and no second `AuraMasterAnchor<id>` is created.
- **A profile change in combat parks every reused id.** Ids are reused across profiles (a reset
  reseeds the starters from id 1), so an instance kept or revived under its id by a switch, copy or
  reset may be built for another container. Under `MustDefer`, `CM.Sync(true)` parks each one
  (engine disabled, nothing hidden); `Container:ShouldShow` keeps a parked instance off through every
  visibility pass, and the deferred apply rebuilds it for the new data and unparks it. An instance a
  profile change parks because the new profile lacks its id is marked `staleData`, so a later Create
  or Duplicate that reuses the id (a reset rewinds the counter) revives it still parked too.
- **Registry verbs that create or destroy frames are refused in combat** with a gray line
  (options-ui-§2): `/am new`, `/am delete`, and the Containers page's New container, Duplicate and
  Delete popup. `ContainerManager.Create` refuses itself, so every creating caller is covered.
- **Reset all is Profiles → Reset Profile, in combat as well (options-ui-§12).** `/am resetall` and
  the General page's Reset-all popup both run `db:ResetProfile()`, the same call AceDBOptions' button
  makes, and neither is refused. In combat all three take the parked teardown above: a container the
  reset drops draws nothing until combat ends and is torn down then. Ours also restore the session
  rows, so preview turns off through `ApplyVisibility` (combat-safe); AceDBOptions' button leaves
  session rows alone.
- **A profile switch, copy or reset in combat may create anchor frames.** Those are plain frames,
  which is combat-legal; their engines are built by the deferred apply once combat ends.
- **Every engine and button binding is `pcall`-guarded** (`callEngine`, `Style.Bind`), so a binding
  the client rejects costs that binding, never the engine's frame batch.
- **Secret values never reach a string operation.** Only `modules/TimedSpells.lua` reads aura data,
  only while `Compat.AurasAreSecret()` is false, and through the `core/Secrets.lua` gates; chat and
  debug lines go through `NS.SafeToString`.
- **Right-click cancel uses one click phase** (`RightButtonUp`) so a button reassigned between press
  and release cannot cancel the wrong aura (`modules/Style.lua:269-271`).

## Known Limitations

- **Units are player, target, focus and pet.** Party units 1–5 are deferred and tracked as a GitHub
  issue; so is a text-only container style.
- **Spell-id filters are honored only for buffs on friendly units and debuffs on hostile units** (the
  engine's identity gate). `FilterCompiler` emits a warning per container where that bites
  (`modules/FilterCompiler.lua:154`), rendered in orange on the Filters page.
- **"Only auras without a duration" is learned, not filtered.** The engine has no such filter; the
  addon excludes every spell it has seen carry a duration, learned from player and pet buffs while
  auras are readable (`modules/TimedSpells.lua`). A timed buff never seen out of combat shows once;
  the set only grows until `/am forgettimed`. Because only buffs are scanned, the mode narrows
  nothing on a debuff container.
- **Settings changes wait for secrecy and lockdown to lift.** The player is told once per deferral,
  and the line names the cause: "…will apply when combat ends." under lockdown, or "…will apply once
  aura information is available again (after the encounter, key or match)." when secrecy alone holds
  the change. A stretch announced as combat that secrecy still holds afterwards says so once more, on
  the next held change and never on the `PLAYER_REGEN_ENABLED` edge itself, whose order against
  `ADDON_RESTRICTION_STATE_CHANGED` is unverified. Writes that apply no container never wait: the
  master enable, visibility, lock and alpha run the visibility pass at once, and a rename and the
  session toggles queue nothing. The Blizzard-frame toggles queue nothing either, but reparenting
  waits for lockdown to lift: a toggle in combat prints the combat line, under the same
  once-per-stretch rule, and applies on `PLAYER_REGEN_ENABLED`. The notice is only for the
  player's changes. What the addon queues for itself waits just the same but prints nothing: a
  class-swap re-apply, a learned timed spell, the startup build after a reload in combat, a perf
  resume (`RequestApply(id, true)`).
- **A container deleted or switched away in combat, or while aura information is withheld (an
  encounter, key or match), draws nothing until that ends, and is torn down then.** Its frames stay
  parked in the meantime. Creating and deleting from our own surfaces are refused in combat instead;
  Reset all, like Reset Profile, takes this parked path.
- **After a profile switch, copy or reset in combat, a container whose id the new profile shares
  draws nothing until combat ends** (or, while aura information is withheld, until that ends). Its
  engine was built for the old container, so it stays parked rather than show stale auras under the
  new container's name, and the deferred apply rebuilds it. The same goes for a container a Create
  or Duplicate adds under an id the profile change just retired: while aura information is withheld
  out of combat it draws nothing until that ends.
- **A change of shape rebuilds the engine.** A different group count, enchant slots appearing or
  going, toggling hide-permanent enchants, or a style switch retires the old engine and creates a new
  one; WoW never frees a frame, so
  each such change leaves one hidden frame for the session.
- **Preview elements are addon-owned frames**, dressed by the same `Style` code but laid out by
  `Preview.Offset`'s arithmetic rather than by the engine.
- **Class colors follow the container's unit, snapshotted per apply.** After a target, focus or pet
  swap under combat lockdown or while auras are secret, a class-colored container keeps the previous
  unit's class until it re-applies. Under lockdown alone (open world, auras readable) that happens
  on `PLAYER_REGEN_ENABLED` (`ReapplyStaleClass`). While auras are secret it happens when the
  restriction lifts, since engine buttons cannot be re-dressed until then. That residual is ratified
  by the `options-ui-§17` row in Documented deviations.
- **Unpublished; README `## Screenshots` is a placeholder, and its images are owed before first
  publish** — see Documented deviations and issue tusharsaxena/AuraMaster#3.
- **A frame anchor needs a global name.** The picker walks up to the nearest named ancestor
  (`modules/FramePicker.lua:26`); an unnamed frame cannot be re-found after a `/reload`.
- **While unlocked, a container flush with the screen edge on its handle's side is pushed in.** The
  anchor's clamp rect takes the handle in, so the handle can never be dragged off the screen
  (`Anchors.UpdateHandle`). A container dragged against the top edge that grows down therefore sits
  20px lower (the 18px strip and its 2px gap) until `/am lock`, and a handle wider than one element
  pushes a container off the side edge it runs toward the same way. Locking puts it back, and the
  stored position never changes.
- **An attached container's handle can lie over the container it is attached to.** The handle sits
  outside its own container, on the side its auras do not grow into, and an attached container often
  has its target on exactly that side. The handle shows only while unlocked, and an attached
  container is placed by its Layout-page offsets rather than dragged, so nothing is lost.

## Documentation map

Every `.md` under `docs/` appears in exactly one table below (documentation-§3). Frozen and
generated directories are named once and never enumerated: `docs/audits/`, `docs/reviews/`,
`docs/automated-tests/<run>/`, `docs/perf-analysis/<run>/`, `docs/revendor/<date>/`,
`docs/superpowers/`, `docs/investigations/`.

### Required (documentation-§3, Tier 1)

| Doc | Covers |
|---|---|
| `scope.md` | What the addon does, and what it deliberately does not |
| `module-map.md` | Every non-vendored file, its one-line responsibility, and the TOC load order and why |
| `schema.md` | The profile and global SavedVariables shape, the container template, every default, the migration path |
| `settings-panel.md` | The `Tab \| Covers` table, the page → tab → row tree, per-option behavior and schema keys |
| `data-flow.md` | Settings → filter plan → aura groups → the engine renders; lifecycle and deferral |
| `common-tasks.md` | Recipes for the changes made most often here, naming real files |

### Conditional (documentation-§3, Tier 2)

| Doc | Status | Trigger |
|---|---|---|
| `perf-analysis/README.md` | Present | The performance harness is wired (`core/PerfSetup.lua`) |
| `slash-dispatch.md` | Present | 22 commands in `NS.COMMANDS`, over the eight-or-more threshold |
| `midnight-quirks.md` | Present | Client-version workarounds of the addon's own: 12.1 aura secrecy and the aura container engine |
| `compat-layer.md` | Present | 17 shims in `core/Compat.lua`, over the three-or-more threshold |
| `message-bus.md` | Not applicable | 4 messages in `NS.MSG`; the trigger is more than ten. The table lives in `## Message Bus` above |
| `profiles.md` | Present | AceDB profiles are user-visible: the Profiles sub-page is a profile control in the options UI |
| `debug.md` | Not applicable | Only the LibKa0s default console (`core/DebugLogSetup.lua`); no debug surface of the addon's own |

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

None.

## Documented deviations

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `options-ui-§17` | The "One resolver" clause: a unit-scoped container caches another unit's class. Each apply snapshots it (`ContainerClass:SnapshotClass` / `ResolveUnitClass`) and `Style.Color` paints from that snapshot, so after a target, focus or pet swap while auras are secret or under combat lockdown the container keeps the previous unit's class until it re-applies. Under lockdown alone (open world, auras readable) `ReapplyStaleClass` catches up on `PLAYER_REGEN_ENABLED`; while auras are secret it catches up when the restriction lifts (`ADDON_RESTRICTION_STATE_CHANGED`) | While auras are secret a re-dress is impossible: the engine dresses buttons in initializeFrame and forbids restyling them (DenyTaintedAccessWhenAurasAreSecret). Under combat lockdown alone, with auras readable, the wait is the addon's choice: `ContainerManager.MustDefer` holds every apply until combat ends, because an apply re-places the anchor and may retire and rebuild the engine, structural work that events-frames-taint-§2 keeps out of combat. Conforming there would take a second, restyle-only path that runs in combat beside the deferred apply, only to repaint a swatch that `ReapplyStaleClass` corrects on `PLAYER_REGEN_ENABLED`; audit docs/audits/2026-09-11 AM-03. Ratified by the owner 2026-09-12. | 2026-09-12 | The secret-auras half ends when the aura engine offers a class-color binding it resolves per button itself, or addon restyling of engine buttons becomes legal while auras are secret; the lockdown-only half ends when a restyle-only path may run under combat lockdown (`ContainerManager.MustDefer` stops holding a class-only re-dress). The row is retired when both halves have ended |
| `documentation-§1` | README's `## Screenshots` section (item 5) is a placeholder with no captioned images | Screenshots can only be captured in a live client and none exist yet, so the section says so in one line and shows nothing; the addon is unpublished (no CurseForge id, AuraMaster.toc:13), so item 5 is still a SHOULD; images are never fabricated; audit docs/audits/2026-09-11 AM-20; the capture is tracked as issue tusharsaxena/AuraMaster#3. Ratified by the owner 2026-09-12. | 2026-09-12 | The first in-client capture session or the first publish (item 5 becomes a MUST), whichever comes first; the row is retired when captioned images land in the section |
