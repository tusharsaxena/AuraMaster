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
`modules/Container.lua:167`) that registers `UNIT_AURA` for its unit, gathers, sorts, lays out and
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
| AceConsole-3.0 | `/am` and `/auramaster` registration (`settings/Slash.lua:375-376`) |
| AceDB-3.0 | `AuraMasterDB` and its profiles (`core/Database.lua:213`) |
| AceGUI-3.0, AceGUI-3.0-SharedMediaWidgets | The settings panel body and its `LSM30_*` media dropdowns |
| AceConfig-3.0, AceDBOptions-3.0 | The Profiles sub-page only (`settings/Profiles.lua`, options-ui-§3) |
| LibSharedMedia-3.0 | Texture, border and font lookups (`modules/Style.lua:26`) |
| LibKa0s v1.29.0 | Eight modules wired, one setup file each — table below |

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
`/am list|get|set|reset` and the resets; one write seam, `NS.SetByPath` (`settings/Schema.lua:445`),
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
can, since a row is a leaf. Its writers are `ContainerManager.Create` (with
`Database.NewContainerData` taking the id), `ContainerManager.Delete`, `ContainerManager.Duplicate`
(through `Create`), and `Database.PrepareProfile`'s load repair and first-run seeding
(`seedStarters`, `normalizeKeys`, `backfillContainers`, `rebuildOrder` and the `nextContainerId`
bump). Those writes bypass `NS.SetByPath`, which is the `architecture-§5` row in Documented
deviations.

SavedVariables shape, every default and the migration path: `docs/schema.md`.

## Message Bus

A closed bus on AceEvent messages (`core/Bus.lua`, architecture-§4). Every receiver subscribes on its
own target from `NS.NewBusTarget()`, so no two receivers can clobber each other. There is
deliberately **no aura-data message**: the engine owns `UNIT_AURA` and nothing here reads an aura to
pass on.

| Message | Sender | Payload | Consumers |
|---|---|---|---|
| `Ka0s_AuraMaster_ContainersChanged` (`NS.MSG.CONTAINERS_CHANGED`) | `modules/ContainerManager.lua` — create, delete, rename, duplicate, profile change (copy-from and reset positions are settings writes, announced by `CONFIG_CHANGED`) | none | `settings/OptionsSetup.lua:238` — a coalesced panel re-render (every banner lists containers) |
| `Ka0s_AuraMaster_ConfigChanged` (`NS.MSG.CONFIG_CHANGED`) | `settings/Schema.lua:271` — the write seam, once per write; never for a session row | `{ section, containerId, path }`; `containerId` nil for an addon-wide row, `path` the row written | `modules/ContainerManager.lua:468` — by the row's `effect`: `"visibility"` runs `ApplyVisibility()` at once, `"none"` queues nothing, otherwise `RequestApply(containerId)` (nil re-applies all) |
| `Ka0s_AuraMaster_VisibilityChanged` (`NS.MSG.VISIBILITY_CHANGED`) | `core/AuraMaster.lua` — entering the world, combat start and end | none | `modules/ContainerManager.lua:475` — `ApplyVisibility()` over every container |
| `Ka0s_AuraMaster_TimedSpellsChanged` (`NS.MSG.TIMED_SPELLS_CHANGED`) | `modules/TimedSpells.lua` — a scan learned timed spells, or `/am forgettimed` emptied the set | none | `modules/ContainerManager.lua` `CM.Init` — `RequestApply()` over every container (their excluded ids moved) |

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
| `PLAYER_ENTERING_WORLD` | `core/AuraMaster.lua:44` (AceEvent) | `OnEnterWorld` → `VISIBILITY_CHANGED`, `ContainerManager.FlushPending` |
| `PLAYER_REGEN_DISABLED` | `core/AuraMaster.lua:45` | `OnCombatChanged` → `VISIBILITY_CHANGED` |
| `PLAYER_REGEN_ENABLED` | `core/AuraMaster.lua:46` | `OnCombatChanged` → `VISIBILITY_CHANGED`, `FlushPending`, `ReapplyStaleClass`, `BlizzardFrames.Apply`, `Anchors.ResolvePending` (a frame that appeared during combat) |
| `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED` | `core/AuraMaster.lua:47-48` | `OnUnitSwap` → `RefreshUnit` → the engine's `UpdateAllAuras` (bucket `unitSwap`); re-applies the class-colored containers of that unit when the new unit's class differs, or marks them stale, silently, while an apply must wait |
| `UNIT_PET` | `core/AuraMaster.lua:49` | `OnUnitPet` (player only) → `RefreshUnit("pet")` (bucket `unitSwap`); re-applies the class-colored pet containers when the pet's class differs, or marks them stale while an apply must wait |
| `ADDON_LOADED` | `core/AuraMaster.lua:50` | `OnAddonLoaded` → `Anchors.ResolvePending` (frame-attached containers) |
| `ADDON_RESTRICTION_STATE_CHANGED` | `core/AuraMaster.lua:52` | `OnRestrictionChanged` → `FlushPending`, `ReapplyStaleClass` (a deferred apply runs when secrecy lifts) |
| `UNIT_AURA` | `modules/TimedSpells.lua` (AceEvent, on its own target) — only while a container uses "without a duration", the addon is not suspended, and auras are readable (no combat lockdown, not secret) | `onUnitAura`: a safe-key `player`/`pet` schedules a scan 0.5 s later (bucket `timedScan`); every other unit is dropped. A scan that comes due after the gate closed is dropped too |
| `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`, `ADDON_RESTRICTION_STATE_CHANGED` | `modules/TimedSpells.lua` (AceEvent, on its own target) — while a container uses "without a duration" and the addon is not suspended | `syncAuraListen`: `PLAYER_REGEN_DISABLED` closes the readable gate by itself (it fires before combat lockdown begins); the other two re-check it, dropping or restoring `UNIT_AURA`; reopening schedules one scan |
| AceDB `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset` | `core/Database.lua:216-218` | `NS.OnProfileChanged` → re-prepare the registry, rebuild, re-render |

Each container's own `UNIT_AURA` belongs to the engine (`SetUnit`, `modules/Container.lua:212`) and
is not addon code. The eight `core/AuraMaster.lua` registrations live in one function,
`RegisterLifecycleEvents`, so the perf probe's suspend and resume remove and restore the same list.

## Taint Notes

- **No secure template of our own.** The only protected machinery is Blizzard's aura engine. Each
  container's anchor (`AuraMasterAnchor<id>`) inherits `DisableUntrustedLayoutScriptsTemplate`,
  Blizzard's opt-in for a frame anchored to an aura container (`modules/Container.lua:38-41`).
- **Anchors stay out of the client's layout cache.** An anchor is movable (a handle drag moves it
  with `StartMoving`), and the client saves a movable frame's position and restores it at login.
  `Container.New` calls `SetDontSavePosition(true)`, so the stored `container.position` is the only
  position an anchor ever has.
- **The engine is anchored before its first `AddAuraGroup`**; after that an addon can no longer
  anchor it (`modules/Container.lua:171-175`).
- **No structural work while auras are secret or under combat lockdown.** `ContainerManager.MustDefer`
  (`modules/ContainerManager.lua:150`) holds every build, update and restyle; aura buttons refuse addon
  access while auras are secret.
- **Visibility in combat goes through the engine's `SetEnabled`**, never `Show`/`Hide` on an aura
  button's ancestry (`modules/Container.lua:366`).
- **Blizzard's `BuffFrame` and `DebuffFrame` are reparented, never hidden**, and only out of combat
  (`modules/BlizzardFrames.lua`, events-frames-taint-§3).
- **Protected opens are refused, not deferred.** The options panel (the library, options-ui-§2),
  `NS.OpenOptionsPage` (`settings/OptionsSetup.lua:208`), the frame picker and a handle drag all
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
  and release cannot cancel the wrong aura (`modules/Style.lua:256-258`).

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
  once-per-stretch rule, and applies on `PLAYER_REGEN_ENABLED`.
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
- **Unpublished; README `## Screenshots` is owed before first publish** — see Documented deviations
  and issue tusharsaxena/AuraMaster#3.
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
| `options-ui-§17` | The "One resolver" clause: a unit-scoped container caches another unit's class. Each apply snapshots it (`ContainerClass:SnapshotClass` / `ResolveUnitClass`) and `Style.Color` paints from that snapshot, so after a target, focus or pet swap while auras are secret or under combat lockdown the container keeps the previous unit's class until it re-applies. Under lockdown alone (open world, auras readable) `ReapplyStaleClass` catches up on `PLAYER_REGEN_ENABLED`; while auras are secret it catches up when the restriction lifts (`ADDON_RESTRICTION_STATE_CHANGED`) | While auras are secret a re-dress is impossible: the engine dresses buttons in initializeFrame and forbids restyling them (DenyTaintedAccessWhenAurasAreSecret). Under combat lockdown alone, with auras readable, the wait is the addon's choice: `ContainerManager.MustDefer` holds every apply until combat ends, because an apply re-places the anchor and may retire and rebuild the engine, structural work that events-frames-taint-§2 keeps out of combat. Conforming there would take a second, restyle-only path that runs in combat beside the deferred apply, only to repaint a swatch that `ReapplyStaleClass` corrects on `PLAYER_REGEN_ENABLED`; audit docs/audits/2026-09-11 AM-03 | 2026-09-11 | The aura engine offers a class-color binding it resolves per button itself, or addon restyling of engine buttons becomes legal while auras are secret |
| `architecture-§5` | The container registry (`containers` membership, `containerOrder`, `nextContainerId`) is written outside `NS.SetByPath`: by `ContainerManager.Create` (with `Database.NewContainerData` taking the id and stamping `c.id`), `.Delete` and `.Duplicate` (through `Create`), and by `Database.PrepareProfile`'s load repair and first-run seeding (`seedStarters`, `normalizeKeys`, `backfillContainers`, `rebuildOrder` and the `nextContainerId` bump). That load pass also writes the profile's `seeded` flag, backfills missing template leaves into every stored container and stamps each container's `c.id` from its key | The registry is not addressable by any schema row, since a row is a leaf; membership changes are structural and go through ContainerManager, and the load repair normalizes what AceDB loaded and, on a brand-new profile, seeds the starters, before any reader sees the registry; follow-up to docs/reviews/2026-09-11 F-006, whose settings writes now go through the seam, leaving only the registry, which is not a settings path | 2026-09-11 | A schema row (or the seam) gains a registry address, or architecture-§5 scopes the rule to schema rows |
| `documentation-§1` | README has no `## Screenshots` section (item 5) | Screenshots can only be captured in a live client and none exist yet; the addon is unpublished (no CurseForge id, AuraMaster.toc:13), so item 5 is still a SHOULD; images are never fabricated; audit docs/audits/2026-09-11 AM-20; the capture is tracked as issue tusharsaxena/AuraMaster#3 | 2026-09-11 | The first in-client capture session or the first publish (item 5 becomes a MUST), whichever comes first; the row is retired when the section lands |
