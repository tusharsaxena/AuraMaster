# Architecture — Ka0s Aura Master

The engineer's hub for this addon. Each mandated section summarizes and links out; the detail lives
in the topic docs registered under [Documentation map](#documentation-map) (documentation-§3).

## Overview

Ka0s Aura Master draws player-built aura **containers**. A container is one unit (`player`,
`target`, `focus`, `pet` — `core/Constants.lua:33`), one aura type (`HELPFUL`, `HARMFUL`, or
`ENCHANT` for the player's temporary weapon enchants — `:39`) and one style (`bars` or `icons` —
`:43`), plus its filters, placement and look. A profile holds any number of them; a fresh profile is
seeded with three (`defaults/Profile.lua:187`).

**The design is dictated by one client fact.** On Retail 12.1 an addon cannot read aura data while
auras are secret — combat, encounters, Mythic+ and PvP (`core/Secrets.lua`, `docs/midnight-quirks.md`).
So this addon reads no aura at all. Every container is a Blizzard **AuraContainer**
(`CreateFrame("AuraContainer", nil, anchor, "CustomAuraContainerTemplate")`,
`modules/Container.lua:122`) that registers `UNIT_AURA` for its unit, gathers, sorts, lays out and
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
| AceConsole-3.0 | `/am` and `/auramaster` registration (`settings/Slash.lua:327`) |
| AceDB-3.0 | `AuraMasterDB` and its profiles (`core/Database.lua:165`) |
| AceGUI-3.0, AceGUI-3.0-SharedMediaWidgets | The settings panel body and its `LSM30_*` media dropdowns |
| AceConfig-3.0, AceDBOptions-3.0 | The Profiles sub-page only (`settings/Profiles.lua`, options-ui-§3) |
| LibSharedMedia-3.0 | Texture, border and font lookups (`modules/Style.lua:23`) |
| LibKa0s v1.29.0 | Eight modules wired, one setup file each — table below |

| LibKa0s module | Setup file | Publishes |
|---|---|---|
| `LibKa0s-Media-1.0` | `core/MediaSetup.lua` | `NS.Icon`, `NS.MediaFont`, the LSM registration |
| `LibKa0s-Env-1.0` | `core/EnvSetup.lua` | `NS.Meta`, `NS.Version` |
| `LibKa0s-Core-1.0` | `core/CoreSetup.lua` | `NS.Print`, `NS.Printf`, `NS.SafeToString`, `NS.ResolveColor`, `NS.MakeCloseButton` |
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

`NS.Schema` holds **192** rows across six pages — General 9, Containers 5, Filters 40, Layout 26,
Bars 70, Icons 42 — plus the AceConfig-drawn Profiles page, which carries none. It drives the panel,
`/am list|get|set|reset` and the resets; one write seam, `NS.SetByPath` (`settings/Schema.lua:270`),
is where the panel, the CLI, the Defaults buttons and a drag handle all land. It validates, resolves
the container, runs the row's optional `normalize` hook, writes, reacts and announces, in that order.
The name row's hook stores container names unique, case-insensitively.

Almost every row belongs to one container, so container rows use a **relative path**:
`container.bars.width` resolves against the container the settings banner has selected
(`NS.State.activeContainerId`), falling back to the first one. Addon-wide rows keep absolute paths
(`enabled`, `hideBlizzardBuffs`). A row's `default` is never typed in a page file —
`NS.RegisterSchemaRows` stamps it from `defaults/Profile.lua`, and `NS.ValidateSchema` proves every
path resolves. Three whole-set carve-outs (`container.filter.whitelist`, `.blacklist`,
`.categorySpells`) and six whole-section paths (`container.filter`, `.layout`, `.behavior`,
`.position`, `.bars`, `.icons`) are written through the same seam and normalized there. A drag, a
copy between containers, a position reset and a delete's fallback to the screen all write that way.

The registry (which containers exist, their order and the id counter: `containers` membership,
`containerOrder`, `nextContainerId`) is not a settings path. No schema row addresses it, and none
can, since a row is a leaf. Its only writers are `ContainerManager.Create`, `ContainerManager.Delete`,
`ContainerManager.Duplicate` (through `Create`) and `Database.PrepareProfile`'s load repair
(`normalizeKeys`).

SavedVariables shape, every default and the migration path: `docs/schema.md`.

## Message Bus

A closed bus on AceEvent messages (`core/Bus.lua`, architecture-§4). Every receiver subscribes on its
own target from `NS.NewBusTarget()`, so no two receivers can clobber each other. There is
deliberately **no aura-data message**: the engine owns `UNIT_AURA` and nothing here reads an aura to
pass on.

| Message | Sender | Payload | Consumers |
|---|---|---|---|
| `Ka0s_AuraMaster_ContainersChanged` (`NS.MSG.CONTAINERS_CHANGED`) | `modules/ContainerManager.lua` — create, delete, rename, duplicate, profile change (copy-from and reset positions are settings writes, announced by `CONFIG_CHANGED`) | none | `settings/OptionsSetup.lua:237` — a coalesced panel re-render (every banner lists containers) |
| `Ka0s_AuraMaster_ConfigChanged` (`NS.MSG.CONFIG_CHANGED`) | `settings/Schema.lua:255` — the write seam, once per write; never for a session row | `{ section, containerId, path }`; `containerId` nil for an addon-wide row, `path` the row written | `modules/ContainerManager.lua:291` — by the row's `effect`: `"visibility"` runs `ApplyVisibility()` at once, `"none"` queues nothing, otherwise `RequestApply(containerId)` (nil re-applies all) |
| `Ka0s_AuraMaster_VisibilityChanged` (`NS.MSG.VISIBILITY_CHANGED`) | `core/AuraMaster.lua` — entering the world, combat start and end | none | `modules/ContainerManager.lua:295` — `ApplyVisibility()` over every container |
| `Ka0s_AuraMaster_TimedSpellsChanged` (`NS.MSG.TIMED_SPELLS_CHANGED`) | `modules/TimedSpells.lua` — a scan learned timed spells, or `/am forgettimed` emptied the set | none | `modules/ContainerManager.lua` `CM.Init` — `RequestApply()` over every container (their excluded ids moved) |

Four messages, well under the more-than-ten trigger for a separate `message-bus.md`.

## Slash Commands

`/am` with `/auramaster` as the long alias, dispatched by `LibKa0s-Slash-1.0` over the addon's own
ordered `NS.COMMANDS` (`settings/Slash.lua:29`). Twenty verbs; `options` is an alias of `config`.

| Command | What it does |
|---|---|
| `/am help` | List available commands |
| `/am config` | Open the settings panel |
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
| `/am preview [on\|off]` | Show placeholder auras |
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
| `PLAYER_ENTERING_WORLD` | `core/AuraMaster.lua:42` (AceEvent) | `OnEnterWorld` → `VISIBILITY_CHANGED`, `ContainerManager.FlushPending` |
| `PLAYER_REGEN_DISABLED` | `core/AuraMaster.lua:43` | `OnCombatChanged` → `VISIBILITY_CHANGED` |
| `PLAYER_REGEN_ENABLED` | `core/AuraMaster.lua:44` | `OnCombatChanged` → `VISIBILITY_CHANGED`, `FlushPending`, `BlizzardFrames.Apply` |
| `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED` | `core/AuraMaster.lua:45-46` | `OnUnitSwap` → `RefreshUnit` → the engine's `UpdateAllAuras` (bucket `unitSwap`) |
| `UNIT_PET` | `core/AuraMaster.lua:47` | `OnUnitPet` (player only) → `RefreshUnit("pet")` (bucket `unitSwap`) |
| `ADDON_LOADED` | `core/AuraMaster.lua:48` | `OnAddonLoaded` → `Anchors.ResolvePending` (frame-attached containers) |
| `ADDON_RESTRICTION_STATE_CHANGED` | `core/AuraMaster.lua:50` | `OnRestrictionChanged` → `FlushPending` (a deferred apply runs when secrecy lifts) |
| `UNIT_AURA` | `modules/TimedSpells.lua` (AceEvent, on its own target) — only while a container uses "without a duration", the addon is not suspended, and auras are readable (no combat lockdown, not secret) | `onUnitAura`: a safe-key `player`/`pet` schedules a scan 0.5 s later (bucket `timedScan`); every other unit is dropped |
| `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`, `ADDON_RESTRICTION_STATE_CHANGED` | `modules/TimedSpells.lua` (AceEvent, on its own target) — while a container uses "without a duration" and the addon is not suspended | `syncAuraListen`: re-checks the readable gate, dropping or restoring `UNIT_AURA`; reopening schedules one scan |
| AceDB `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset` | `core/Database.lua:171-173` | `NS.OnProfileChanged` → re-prepare the registry, rebuild, re-render |

Each container's own `UNIT_AURA` belongs to the engine (`SetUnit`, `modules/Container.lua:161`) and
is not addon code. The eight `core/AuraMaster.lua` registrations live in one function,
`RegisterLifecycleEvents`, so the perf probe's suspend and resume remove and restore the same list.

## Taint Notes

- **No secure template of our own.** The only protected machinery is Blizzard's aura engine. Each
  container's anchor (`AuraMasterAnchor<id>`) inherits `DisableUntrustedLayoutScriptsTemplate`,
  Blizzard's opt-in for a frame anchored to an aura container (`modules/Container.lua:37-40`).
- **The engine is anchored before its first `AddAuraGroup`**; after that an addon can no longer
  anchor it (`modules/Container.lua:126-130`).
- **No structural work while auras are secret or under combat lockdown.** `ContainerManager.MustDefer`
  (`modules/ContainerManager.lua:86`) holds every build, update and restyle; aura buttons refuse addon
  access while auras are secret.
- **Visibility in combat goes through the engine's `SetEnabled`**, never `Show`/`Hide` on an aura
  button's ancestry (`modules/Container.lua:286-290`).
- **Blizzard's `BuffFrame` and `DebuffFrame` are reparented, never hidden**, and only out of combat
  (`modules/BlizzardFrames.lua`, events-frames-taint-§3).
- **Protected opens are refused, not deferred.** The options panel (the library, options-ui-§2),
  `NS.OpenOptionsPage` (`settings/OptionsSetup.lua:207`), the frame picker and a handle drag all
  refuse under `InCombatLockdown()`.
- **Teardown under lockdown is parked, never hidden.** A container that leaves the registry while
  `MustDefer` is true is parked (`Container:Park`): its engine is disabled through `SetEnabled`, its
  preview and handle (our own frames) are hidden, and the anchor and engine ancestry are left alone.
  The next `FlushPending` that may touch frames destroys it; if its id comes back first, the same
  instance is revived and no second `AuraMasterAnchor<id>` is created.
- **Registry verbs that create or destroy frames are refused in combat** with a gray line
  (options-ui-§2): `/am new`, `/am delete`, `/am resetall`, the Containers page's New container,
  Duplicate and Delete popup, and the General page's Reset-all popup. `ContainerManager.Create`
  refuses itself, so every creating caller is covered.
- **Reset all diverges from Profiles → Reset Profile (options-ui-§12) in combat.** Reset Profile is
  AceDBOptions' own button and cannot be refused, so in combat it completes through the park path.
  Reset all is refused by choice, a deliberate gate on a surface this addon owns; its line says only
  what is true, that the containers cannot be rebuilt until combat ends.
- **A profile switch, copy or reset in combat may create anchor frames.** Those are plain frames,
  which is combat-legal; their engines are built by the deferred apply once combat ends.
- **Every engine and button binding is `pcall`-guarded** (`callEngine`, `Style.Bind`), so a binding
  the client rejects costs that binding, never the engine's frame batch.
- **Secret values never reach a string operation.** Only `modules/TimedSpells.lua` reads aura data,
  only while `Compat.AurasAreSecret()` is false, and through the `core/Secrets.lua` gates; chat and
  debug lines go through `NS.SafeToString`.
- **Right-click cancel uses one click phase** (`RightButtonUp`) so a button reassigned between press
  and release cannot cancel the wrong aura (`modules/Style.lua:144-146`).

## Known Limitations

- **Units are player, target, focus and pet.** Party units 1–5 are deferred and tracked as a GitHub
  issue; so is a text-only container style.
- **Spell-id filters are honored only for buffs on friendly units and debuffs on hostile units** (the
  engine's identity gate). `FilterCompiler` emits a warning per container where that bites
  (`modules/FilterCompiler.lua:141`), rendered in orange on the Filters page.
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
  master enable, visibility, lock and alpha run the visibility pass at once, and the Blizzard-frame
  toggles, a rename and the session toggles queue nothing.
- **A container deleted or switched away in combat draws nothing until combat ends, and is torn
  down then.** Its frames stay parked in the meantime; creating, deleting and resetting from our own
  surfaces are refused in combat instead.
- **A change of shape rebuilds the engine.** A different group count, enchant slots appearing or
  going, toggling hide-permanent enchants, or a style switch retires the old engine and creates a new
  one; WoW never frees a frame, so
  each such change leaves one hidden frame for the session.
- **Preview elements are addon-owned frames**, dressed by the same `Style` code but laid out by
  `Preview.Offset`'s arithmetic rather than by the engine.
- **Class colors resolve to the player's class** on every surface; an element describes an aura, not
  a unit (`modules/Style.lua:40`).
- **A frame anchor needs a global name.** The picker walks up to the nearest named ancestor
  (`modules/FramePicker.lua:26`); an unnamed frame cannot be re-found after a `/reload`.

## Documentation map

Every `.md` under `docs/` appears in exactly one table below (documentation-§3). Frozen and
generated directories are named once and never enumerated: `docs/audits/`, `docs/reviews/`,
`docs/automated-tests/<run>/`, `docs/perf-analysis/<run>/`, `docs/superpowers/`,
`docs/investigations/`.

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
| `slash-dispatch.md` | Present | 20 commands in `NS.COMMANDS`, over the eight-or-more threshold |
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

None.
