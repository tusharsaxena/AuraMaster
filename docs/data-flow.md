# Data flow

How a setting becomes auras on screen. This is the engineer's version of the README's
*How the containers work*; the two describe one pipeline and must not disagree.

## The one rule the pipeline is built on

On Retail 12.1 aura data is secret to addon code during combat, encounters, Mythic+ and PvP, and the
engine's aura buttons refuse addon access while it is. So nothing in this addon reads an aura to
decide what to draw. It **declares** each container to Blizzard's aura engine up front, and the
engine does the reading, filtering, sorting, layout and timer animation in its own code
(`docs/midnight-quirks.md`).

## The pipeline

```
 1  a control, /am set, a Defaults button or a drag handle
        │  NS.SetByPath(path, value[, containerId])            settings/Schema.lua:429
        │    write → row.onChange → [Set] debug line → CONFIG_CHANGED { section, containerId, path }
        │    (a session row stops after the debug line: it sends nothing)
        ▼
 2  ContainerManager (listener)                                modules/ContainerManager.lua:427
        │  the row's effect:  "visibility" → ApplyVisibility now    "none" → nothing
        │  otherwise RequestApply(containerId)   nil = every container
        │  batched with C_Timer.After(0) — a slider drag or a profile reset applies once
        ▼
 3  ContainerManager.FlushPending                              modules/ContainerManager.lua:181
        │  MustDefer()?  Compat.AurasAreSecret() or InCombatLockdown()
        │     yes → keep the request, print the notice naming the cause (once), return
        │     no  → for each dirty container: Container:Apply(); re-place container-attached ones
        ▼
 4  Container:Apply                                            modules/Container.lua:290
        │  plan = FilterCompiler.Compile(cfg, { timedSpells })  (pure)
        │  anchor scale / strata / level; Anchors.Place (screen, container or frame)
        │  structure = #groups : enchant slots (hide-permanent) : style
        │     same as the live engine → Update in place, then Restyle every button
        │     different              → Retire the old engine, Build a new one
        │  ApplyVisibility
        ▼
 5  the engine (Blizzard's AuraContainer)
        │  registers UNIT_AURA for its unit; gathers the auras matching each group's filter string
        │  and candidate filters; sorts; lays out with the flow settings; creates buttons
        │  and calls initializeFrame for each new one
        ▼
 6  Style.Element(button, cfg, true)                           modules/Style.lua:226
        │  build the regions once (icon, bar, fill, spark, text, border, pandemic wash)
        │  apply the look; bind regions to the engine: SetIcon, SetDurationBar, SetSpellName,
        │  SetDurationText, SetApplicationCount, AddDispelTypeTexture, AddPandemicRegion,
        │  SetCancelAuraButtons, tooltip options
        ▼
 7  the engine fills every bound region with the (secret) aura data and animates it
```

## When an apply waits

`FlushPending` holds the whole queue while `MustDefer()` is true and says so once per held stretch,
naming the cause: "…will apply when combat ends." under lockdown, "…will apply once aura information
is available again (after the encounter, key or match)." when secrecy alone holds it. One escalation
only: a stretch announced as combat that secrecy still holds afterwards prints the restriction line
once, on the next held request. The `PLAYER_REGEN_ENABLED` flush passes `"regen"` and never escalates,
because that event's order against `ADDON_RESTRICTION_STATE_CHANGED` is unverified. Secret then
combat prints nothing more. A successful flush clears the stretch, and every deferral writes one
gated `[Apply] deferred: secret=… lockdown=… edge=…` line.

## Step 4 in detail: the filter plan

`FilterCompiler.Compile` (`modules/FilterCompiler.lua:189`) turns one container into
`{ groups, enchants, warnings }`:

- **A weapon-enchant container** compiles to no groups and three enchant slots (main hand, off hand,
  ranged), with `hidePermanent` from the settings. A non-player unit only earns a warning: enchants are
  always the player's.
- **Every other container starts from a base**: the aura type token (`HELPFUL` or `HARMFUL`), plus
  `PLAYER` or `!PLAYER` for Cast by, plus the duration rules — `maxDuration = N` for a limit,
  `maxDuration = huge` for "only with a duration", or `excludeSpellIDs = <learned timed spells>` for
  "only without".
- **The never list** joins the base as `excludeSpellIDs`, and removes the same ids from the always
  list.
- **The always list** becomes its own group first: the aura type plus `includeSpellIDs`.
- **Categories**, in declaration order: with none shown, one group ("All") minus every hidden
  category; with some shown, one group per shown category, each minus the hidden ones and minus every
  shown category before it, so an aura matching two appears once. Every group also excludes the
  always list.
- **A category applies by kind**: a token adds `TOKEN` or `!TOKEN`; a flag sets a boolean candidate
  filter (`isBossAura`, `isRoleAura`, `isPriorityAura`, `isStealable`, `isFromPlayerOrPlayerPet`); a
  dispel category adds `includeDispelTypes` or `excludeDispelTypes`; a spell category adds
  `includeSpellIDs` or `excludeSpellIDs` from its starter list with the container's edits layered on.
- **A group that contradicts itself** (it would need `X` and `!X`, or a shown spell category with no
  ids left) is dropped; if every group drops, the plan warns that nothing can match.
- **Warnings** record what the engine will silently not do: spell ids on a friendly unit's debuffs or
  a hostile unit's buffs, a max duration in "without" mode, enchants on a non-player unit.
- A player buff container with **Also show weapon enchants** gets the enchant slots after its groups.

**Updating in place.** Filter strings, candidate filters, sort (the enchant sort included, re-sent
only when the direction moved), cap and layout can change on a live engine; hide-permanent enchants
cannot, because a slot takes it only when added, so toggling it is a new shape. A plan of the same
shape calls only the setters whose values moved. Candidate filters are serialized with
`FilterCompiler.Signature` (`modules/FilterCompiler.lua:333`) and re-sent only when the two
signatures differ (`modules/Container.lua:244-246`), because the engine clears and re-gathers a
group whenever they are set (`docs/midnight-quirks.md`). **Rebuilding.** Groups are add-only and a
frame is never freed, so a new shape disables and hides the old engine, keeps it aside, and builds a
new one: flow layout first, then the anchor, then every `AddAuraGroup`, then the enchant slots, then
`SetUnit` last (`modules/Container.lua:164`).

## Visibility, separate from applying

Whether a container shows is a cheaper question, and one that is legal in combat:
`Container:ShouldShow` (`modules/Container.lua:344`) answers, in order — perf suspend, profile and
container `enabled`, preview (unlocked or `/am preview`), then General visibility against
`UnitAffectingCombat("player")`. `ApplyVisibility` enables or disables the **engine** (never
`Show`/`Hide` on its ancestry), sets the anchor alpha (container alpha × master alpha), draws or
clears the preview, and shows the drag handle while unlocked. It runs after every apply, on every
`VISIBILITY_CHANGED` (world entry, combat start and end) and whenever a row whose `effect` is
`"visibility"` is written (the master enable, visibility, lock and alpha).

## Preview

While previewing, the engine is disabled and `Preview.Show` (`modules/Preview.lua:61`) acquires one
addon-owned button per placeholder aura from a pool, dresses it through the same `Style.Element` with
`engine = false`, fills in invented names, times and stacks, and positions it with
`Preview.Offset`'s copy of the flow rules. Bars in preview size their fill directly. The placeholders
are dressed again only after an apply of the container's settings (which marks the preview dirty) or
after they were hidden; a visibility pass alone leaves them as they are.

## Lifecycle

| Moment | What runs |
|---|---|
| File load | Every file in TOC order; the options category registers its pages; LSM registration |
| `ADDON_LOADED` (ours) → `OnInitialize` | `NS.InitDB` → AceDB, `RunMigrations`, `PrepareProfile` (seeds the starters on a fresh profile); `/am` registered |
| `PLAYER_LOGIN` → `OnEnable` | Lifecycle events registered; `ContainerManager.Init` builds an instance per container and applies them; `BlizzardFrames.Apply`; the options panel category is created. Built here, not at load, so the engine's access restrictions (applied at `PLAYER_ENTERING_WORLD`) come after every button's first `initializeFrame` |
| `PLAYER_ENTERING_WORLD` | Visibility pass; flush anything pending |
| `PLAYER_REGEN_DISABLED` / `ENABLED` | Visibility pass; on combat end, flush pending applies, apply the Blizzard-frame settings, and place again any frame-attached container whose frame appeared during combat |
| `ADDON_RESTRICTION_STATE_CHANGED` | Flush pending applies — secrecy can lift outside a combat transition (a key or encounter ending) |
| `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED`, `UNIT_PET` | Every container on that unit calls the engine's `UpdateAllAuras`, because the engine keeps showing the old unit's auras until told |
| `ADDON_LOADED` (any) | Frame-attached containers whose frame did not exist yet are placed again |
| Profile changed, copied or reset | `NS.OnProfileChanged`: `PrepareProfile`, selection cleared, `ContainerManager.Announce` (instances follow the registry, apply all, `CONTAINERS_CHANGED`), Blizzard frames, panel refresh |

## Registry changes

Create, delete, duplicate, rename, copy-from and reset positions all live in
`modules/ContainerManager.lua`, the one writer of the registry. A structural change calls `Announce`
(instances follow the stored registry, everything re-applies, `CONTAINERS_CHANGED`). Copy-from and
reset positions are settings writes, not registry changes: each section they replace is one
whole-section write through `NS.SetByPath`, which announces `CONFIG_CHANGED`, and the applies those
writes queue coalesce into one pass. Copy-from stops at the first write the seam rejects and reports
it. Deleting a container drops any container attached to it back to the screen, through the same
seam. Under `MustDefer`, an instance that leaves
the registry is parked rather than destroyed: `Container:Park` disables its engine and hides only
the preview and handle. The next `FlushPending` that may touch frames destroys every parked
instance before it applies; a parked id that returns first is revived in place and redrawn at once.
Create and delete are refused in combat on every surface this addon owns. Reset all is not: it is
Profiles → Reset Profile, so in combat it takes the same parked path. `CONTAINERS_CHANGED` re-renders an open
panel, because every banner lists containers.

## Learning timed buffs

`modules/TimedSpells.lua` listens only while an enabled buff container uses "only auras without a
duration" and the addon is not suspended. It registers through AceEvent on its own target:
`PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED` and `ADDON_RESTRICTION_STATE_CHANGED` all re-check
one gate, and `UNIT_AURA` is registered only while that gate is open (no combat lockdown, auras not
secret). `PLAYER_REGEN_DISABLED` closes it on the event itself: it fires before the lockdown begins. The vendored AceEvent has no unit filter, so `UNIT_AURA` arrives for every unit; the handler
proves the unit a safe key and keeps only the player and pet. Such an event, or the gate reopening,
schedules a scan half a second later, bracketed `timedScan`. The scan runs only when
`Compat.AurasAreSecret()` is false, reads the player's and pet's buffs by index, and records every
readable spell id with a readable positive duration into `global.timedSpells` (through
`Secrets.IsSafeKey` and `Secrets.IsReadableNumber`). A scan that learned something sends
`TIMED_SPELLS_CHANGED`; `ContainerManager` hears it and re-applies every container, which updates
their `excludeSpellIDs`. `/am forgettimed` empties the set and sends the same message.

## Where a container sits

`Anchors.Place` (`modules/Anchors.lua:79`) sizes the anchor to one element and attaches it: to
another container's engine frame (or its anchor, before the engine exists), unless that would loop;
to a named frame, if it exists and is not forbidden — otherwise the container is marked pending and
re-placed on the next `ADDON_LOADED`; else to the screen at `container.position`. A pending resolve
is skipped under combat lockdown, so `PLAYER_REGEN_ENABLED` runs it again once combat ends. A
container set to a container or a frame that lands on the screen instead writes one `[Anchor]` debug
line, and so does a skipped resolve. Positions are stored, never read back off an engine frame, whose
geometry can be secret; the only position read is the anchor's own after a drag, saved through the
write seam against that container's id. The client never saves an anchor's position itself
(`SetDontSavePosition`), so a login cannot restore one over the stored position.
