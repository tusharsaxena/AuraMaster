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
        │  NS.SetByPath(path, value[, containerId])            settings/Schema.lua:894
        │    write → row.onChange → [Set] debug line → CONFIG_CHANGED { section, containerId, path }
        │    (a session row stops after the debug line: it sends nothing)
        │    (inside a bulk copy or reset the [Set] line is muted and tallied: one line per act)
        ▼
 2  ContainerManager (CONFIG_CHANGED listener)                 modules/ContainerManager.lua:866
        │  first FontPrimer.PrimeAll: a font no container drew in yet is drawn on a shown frame
        │  the row's effect:  "visibility" → ApplyVisibility now    "none" → nothing
        │  otherwise RequestApply(containerId)   nil = every container
        │  batched with C_Timer.NewTimer(0) — a slider drag or a profile reset applies once
        ▼
 3  ContainerManager.FlushPending                              modules/ContainerManager.lua:335
        │  MustDefer()?  Compat.AurasAreSecret() or InCombatLockdown()
        │     yes → keep the request, print the notice naming the cause (once), return
        │     no  → for each dirty container: Container:Apply(); re-place container-attached ones
        ▼
 4  Container:Apply                                            modules/Container.lua:532
        │  plan = FilterCompiler.Compile(cfg, { timedSpells })  (pure)
        │  anchor scale / strata / level; Anchors.Place (screen, container or frame)
        │  structure = #groups : enchant slots (hide-permanent) : style : growth corner
        │     same as the live engine → Update in place, then Restyle every button
        │     different              → Retire the old engine, Build a new one
        │  ApplyVisibility
        ▼
 5  the engine (Blizzard's AuraContainer)
        │  registers UNIT_AURA for its unit; gathers the auras matching each group's filter string
        │  and candidate filters; sorts; lays out with the flow settings; creates buttons
        │  and calls initializeFrame for each new one
        ▼
 6  Style.Element(button, cfg, true)                           modules/Style.lua:844
        │  build the regions once (icon, icon border, bar, fill, spark clip, text, border, pandemic wash)
        │  apply the look; bind regions to the engine: SetIcon, SetDurationBar, SetSpellName,
        │  SetDurationText, SetApplicationCount, AddDispelTypeTexture, AddPandemicRegion,
        │  SetCancelAuraButtons, tooltip options
        ▼
 7  the engine fills every bound region with the (secret) aura data and animates it
```

## When an apply waits

`FlushPending` holds the whole queue while `MustDefer()` is true. The notice is for the player's own
changes: a request the addon makes for itself passes `RequestApply(id, true)` (a class-swap re-apply
from `RefreshUnit` or `ReapplyStaleClass`, a timed-spell scan's `TIMED_SPELLS_CHANGED`, the startup
build in `CM.Init`, a perf resume). It waits and applies on the same edge, but a stretch that holds
only such requests prints nothing. With a player change queued, it says so once per held stretch,
naming the cause: "…will apply when combat ends." under lockdown, "…will apply once aura information
is available again (after the encounter, key or match)." when secrecy alone holds it. One escalation
only: a stretch announced as combat that secrecy still holds afterwards prints the restriction line
once, on the next held request. The `PLAYER_REGEN_ENABLED` flush passes `"regen"` and never escalates,
because that event's order against `ADDON_RESTRICTION_STATE_CHANGED` is unverified. Secret then
combat prints nothing more. A flush that may touch frames clears the stretch, even with nothing
queued, and a deferral writes one gated `[Apply] deferred: secret=… lockdown=… edge=… queued=…` line
when the hold is new or has changed (debug-logging-§9: a key's combat ends all flush the same hold,
and write it once). A
Blizzard-frame toggle made under lockdown is not queued (`BlizzardFrames.Apply` catches it up on
`PLAYER_REGEN_ENABLED`), but its `onChange` announces the wait through
`ContainerManager.NoteDeferred` under the same rule, so one fight prints the line once.

## Filter priority

`modules/FilterCompiler.lua` decides whether one container draws a given aura by one order, highest
rank first (revised by the owner 2026-09-15). `FC.ExplainSpell` answers the same question for a
single spell id, under the same order, and is what the settings panel reads it from — the per-entry
notes under Filters → Overrides' Whitelist and Blacklist (K-3), and the warnings `FilterCompiler.Compile`
attaches to the container.

| Rank | Rule | Outcome |
|---|---|---|
| 1 | On the Overrides **whitelist** | **Shown.** Always, whatever anything else says |
| 2 | On the Overrides **blacklist** | **Hidden**, unless rank 1 already claimed it |
| 3 | In **at least one** category set to Show | **Shown**, even if it is also in a category set to Hide |
| 4 | In one or more categories, **all** of them set to Hide | **Hidden** |
| 5 | In **no** category at all | **Shown** — nothing removed it |

Stated as one sentence: an aura is hidden when the blacklist names it, or when every category it
belongs to says Hide; everything else is drawn, and the whitelist overrides both. A category set to
Show is a positive claim, not merely the absence of a Hide, so rank 3 rescues an aura from a Hide
elsewhere — a Defensive that is also Cancelable is not dropped just because Cancelable says Hide.

**How that compiles.** The engine ANDs the constraints inside one group and ORs the groups, so "in
ANY shown category" is a union and needs a group per Shown category. With nothing Hidden, exactly
one group is emitted (the base minus the whitelist) — a Show cannot rescue anything when nothing is
hiding, so the extra groups would be pure cost. Once anything is Hidden, one group per Shown category
is emitted, followed by a catch-all group that draws an aura in no category at all (rank 5). A
container with anything Hidden therefore compiles to roughly 15 groups on buffs and 17 on debuffs,
not one, and the "Max auras"
cap applies **per group**, not to the container as a whole (`container.filter.maxAuras`,
`docs/schema.md`). The catch-all is skipped instead of joined whenever an `uncategorized` category
exists for the aura type (batch 7 `U-1`..`U-5`; both HELPFUL and HARMFUL carry one as of fix round 3)
and its state actually supersedes the catch-all: Hide always does, on either aura type — that row's
Hide IS the catch-all, made controllable, reproducing the retired **"only these categories"** toggle
exactly. Show does too, but only where `FC.IdsMode(unit, auraType)` is `"always"` — buffs on the
`player` and `pet`, and nowhere else (issue #11, 2026-09-20). There the row's own group is a real
rescue, already a strict superset of what the catch-all would draw. Everywhere else Show contributes
NO group of its own and the catch-all runs normally, because the row's only constraint is
`excludeSpellIDs` and the engine discards spell ids for buffs on a hostile unit and for debuffs on a
friendly one: the group would carry no effective constraint at all, drawing every aura of its type
and defeating every other category's Hide. That reaches further than the debuff case issue #11
added — a hostile `target`/`focus` **buff** container has always been able to emit exactly that
group, which is why the gate asks the unit rather than the aura type. The per-container **"only these
categories"** toggle that used to drop the catch-all a different way (`container.filter.onlyShown`)
is RETIRED (batch 7 fix round 2): once `uncategorized`'s Hide correctly reproduces it on both aura
types (fix round 3 restored the debuff row after fix round 1 dropped it), the toggle had nothing left
to do. A schema v4 migration (`docs/schema.md` → Migration path) converts a stored
`onlyShown = true` accordingly on either aura type; only a container of some other, unrecognized
shape has no category to migrate onto and loses the narrowing, logged and told to the player
directly (`NS.Print`), not silently. Full detail: *Step 4 in detail*, below.

## Step 4 in detail: the filter plan

`FilterCompiler.Compile` (`modules/FilterCompiler.lua:806`) turns one container into
`{ groups, enchants, warnings }`, under the five-rank priority *Filter
priority*, above, states (`FC.ExplainSpell` answers the same question for one spell, for the panel):

- **A player buff container** appends the enchant slots the profile's `enchantSlots` names (falling
  back to all three when none are ticked), with `hidePermanent` from the settings, unless its
  `weaponEnchants` category is Hide. One showing ONLY enchants (schema v5: every other category Hide)
  compiles to those slots and no aura group, and is not warned about as one that can never match.
- **Every container starts from a base**: the aura type token (`HELPFUL` or `HARMFUL`), plus
  `PLAYER` or `!PLAYER` for Cast by, plus the duration rules — `maxDuration = N` for a limit,
  `maxDuration = huge` for "only with a duration", or `excludeSpellIDs = <learned timed spells>` for
  "only without".
- **The Overrides lists** (ranks 1–2): the whitelist beats the blacklist — a whitelisted id is
  dropped from the blacklist, never the reverse (`applyLists`). The blacklist then joins the base as
  `excludeSpellIDs`, so it reaches every category group and the catch-all, but never the whitelist's
  own group. The **whitelist group** is emitted first and alone: the aura type plus
  `includeSpellIDs`, with no blacklist applied to it.
- **Categories** (ranks 3–5): `splitCategories` partitions every category of the container's aura
  type into `shown` and `hidden` (kind `enchant` is excluded — it matches no aura). With nothing
  Hidden, exactly **one** group ("All") is emitted, the base minus the whitelist — a Show cannot
  rescue anything when nothing is hiding, so a group per category would be pure cost. Otherwise, one
  group is emitted **per category set to Show** — the base plus that category's own positive
  constraint, minus every earlier Shown category (so an aura in two Shown categories is drawn once,
  under the first) and minus the whitelist — followed by the **catch-all**: the base minus every
  Hidden and every Shown category and the whitelist, which is what draws an aura in no category at
  all (rank 5). The per-container "Only these categories" toggle that used to drop the catch-all is
  RETIRED (batch 7 fix round 2); an addon-defined `uncategorized` category in the Spell Categories grid (batch 7, `U-1`..`U-5`) does
  that instead — Hide always suppresses the catch-all (on either aura type, reproducing the retired
  toggle exactly, fix round 3); Show suppresses it too, but only where `FC.IdsMode(unit,
  auraType)` is `"always"` — buffs on the `player` and `pet` — because only there is the category's own group
  a real rescue that already covers everything the catch-all would (a strict superset relationship).
  On every debuff container, and on a `target`/`focus` buff container whose unit may be hostile when
  the engine looks, Show contributes no group of its own at all and changes nothing, so the catch-all
  is left exactly as it would be without the category. `hasUnion` is that gate, not an emptiness
  test: `Cat.HARMFUL` has carried `hardCC` and `softCC` since issue #11, so a debuff union is no
  longer empty — what stops the group is that the engine may throw its one `excludeSpellIDs` away. A
  container with anything Hidden this way compiles to roughly 15 groups on buffs and 17 on debuffs,
  not one, and the "Max auras"
  cap (`maxFrameCount`) applies to each group separately.
- **A category applies by kind**: a token adds `TOKEN` or `!TOKEN`; a flag sets a boolean candidate
  filter (`isBossAura`, `isRoleAura`, `isPriorityAura`, `isStealable`, `isFromPlayerOrPlayerPet`); a
  dispel category adds `includeDispelTypes` or `excludeDispelTypes`; a spell category adds
  `includeSpellIDs` or `excludeSpellIDs` from its starter list with the container's edits layered on;
  `uncategorized` (above) is its own case, gated on `hasUnion` rather than the generic per-kind rule.
- **A group that contradicts itself** (it would need `X` and `!X`, or a Shown spell category with no
  ids left) is dropped; if every group drops, the plan warns that nothing can match
  (`FC.WARN.NEVER_MATCHES`).
- **Warnings** record what the engine will silently not do: spell ids on a friendly unit's debuffs or
  a hostile unit's buffs, a max duration in "without" mode, enchants on a non-player unit. What a
  container draws there instead is the Filters section's last tab, **Situations** (the
  `filter.situations` dropdowns, read by `ContainerClass:ResolveView`, never by the compile), which
  the Categories and Overrides NOTE lines point to.
- A player buff container appends the enchant slots after its groups, unless its `weaponEnchants`
  category row is set to Hide (`appendEnchants`).

**Updating in place.** Filter strings, candidate filters, sort (the enchant sort included, re-sent
only when the direction moved), cap and layout can change on a live engine; hide-permanent enchants
cannot, because a slot takes it only when added, so toggling it is a new shape. A plan of the same
shape calls only the setters whose values moved. Candidate filters are serialized with
`FilterCompiler.Signature` (`modules/FilterCompiler.lua:978`) and re-sent only when the two
signatures differ (`modules/Container.lua:327-330`), because the engine clears and re-gathers a
group whenever they are set (`docs/midnight-quirks.md`). **Rebuilding.** Groups are add-only and a
frame is never freed, so a new shape disables and hides the old engine, keeps it aside, and builds a
new one: flow layout first, then the anchor, then every `AddAuraGroup`, then the enchant slots, then
`SetUnit` last (`modules/Container.lua:442`).

## Visibility, separate from applying

Whether a container shows is a cheaper question, and one that is legal in combat:
`Container:ShouldShow` (`modules/Container.lua:665`) answers, in order — perf suspend, profile and
container `enabled`, then General visibility against `UnitAffectingCombat("player")` together with the
container's Filters → Situations → Show in boxes against `NS.Compat.InstanceType()` (filter situations, S3; a
type with no box, or unreadable, is allowed) and, on a target or focus container, its Unit type and
Reaction against `NS.Compat.IsPlayerUnit` and `NS.Compat.UnitReactionKind` (S6; no unit, or an
unreadable answer, is allowed), all of which an
unlocked container skips so one that shows only in combat can still be found and moved; it also
answers whether the container previews, which is the session-only test mode (`NS.State.testMode`),
not the lock. `ApplyVisibility` enables or disables the **engine** (never
`Show`/`Hide` on its ancestry), sets the anchor alpha (container alpha × master alpha), draws or
clears the preview, and shows the drag handle while unlocked, with a faint outline one element in
size unless test mode's placeholders are there. `ApplyVisibility` runs after every
apply, on every `VISIBILITY_CHANGED` (world entry, combat start and end, a test mode switch) and whenever a row whose
`effect` is `"visibility"` is written (the master enable, visibility, lock and alpha, a
container's own enable, its six `filter.zones` rows and its two `filter.unitFilter` rows). A target
or focus swap, and `UNIT_FACTION` / `UNIT_FLAGS` for target, focus or the player, re-run it for each
container whose Unit type answer moved (`CM.ApplyUnitGate`). The handle
(`Anchors.UpdateHandle`) is a strip outside the anchor, on the side the auras do not grow into (the
before side: above the block growing down), so it covers no element. Every container's strip sits
there, a follower's included, in its own column (batch 10 F1, `Anchors.StripPoints`). A shown name
label (`Anchors.PlaceLabel`) sits on the block's before side too, locked or unlocked, and while
unlocked the strip moves out past it (D6), so the order is always strip, label, block (F3). A
follower attached on the after side makes the room itself: its seam is moved on along the chain by
its own strip's row while the strip shows and its label's row while the label shows (F2), and the
visibility pass re-places it when either appears or goes (`Anchors.RefreshSeam`, after
`UpdateHandle`). A follower on the parent's ahead side (Right, growing right) is moved on the same way past the parent's label
while it shows, locked or not, and its strip while that runs past its element (F4). The strip is as
wide as the element (batch 11 T11): `Anchors.UpdateHandle` hands the widget a label whose name is
shortened with "..." to fit between the marks (the TEST tag kept whole), measured through the
widget's `SetLabel` and `Measure` and cached per name and width, and `placeHandle` sets the element's
width, so `stripOverhang` is 0. Only an element too narrow for both reserves and 40 px of label
keeps the natural width, `ApplyWidth(element)`, and runs past it. Nothing on screen
marks the point where a container attached to another joins it (batch 11 G6 removed batch 9's join
pin); the strip's tooltip names the parent's point and the parent (`Anchors.JoinText`). While the
container is attached to another container or a named frame, its strip name is a warm gray
(`C.ATTACHED_NAME_COLOR`, the owner, 2026-09-26): attached, not undraggable. The tooltip's first line
says how to use the strip (`tooltipSpec`, issue #22): on the screen, "Drag to move. Drop it on another
container to attach it there; hold Shift to place it without attaching."; attached to another
container, "Attached to '*parent*'. Drag it away and let go once the marks turn red to detach it; let
go sooner and it snaps back. ..."; attached to a named frame, which a drag cannot move, "Anchored to '*frame*', so it cannot
be dragged", or, before a frame name is set, "Set to a named frame, so it cannot be dragged". A drag and its drop are in *Drag to attach* below. The strip's close mark (X) writes `container.enabled = false` through
`NS.SetByPath`, the same write as the Enabled checkbox, so the next visibility pass hides it.

## Preview

While previewing, the engine is disabled and `Preview.Show` (`modules/Preview.lua:180`) acquires one
addon-owned button per placeholder aura from a pool, dresses it through the same `Style.Element` with
`engine = false`, fills in the placeholder set for the container (`Preview.AurasFor`: weapon enchants,
one per slot, for a container showing only Weapon enchants (batch 9 SEP-4); debuffs of every dispel
type for a debuff container; buffs otherwise; the client's own names and icons by spell id, invented
times and stacks), and positions it with `Preview.Offset`'s copy of the flow rules. In test mode the
container's outline encloses the whole placeholder block (`ContainerClass:ApplyOutline` on the preview
extent, SEP-1), unlocked only (owner, 2026-09-27), so each block of a chain reads as its own. Bars in preview size their fill directly. The placeholders
are dressed again only after an apply of the container's settings (which marks the preview dirty) or
after they were hidden; a visibility pass alone leaves them as they are.

## Lifecycle

| Moment | What runs |
|---|---|
| File load | Every file in TOC order; the options category registers its pages; LSM registration |
| `ADDON_LOADED` (ours) → `OnInitialize` | `NS.InitDB` → AceDB, `RunMigrations`, `PrepareProfile` (seeds the starters on a fresh profile); `/am` registered |
| `PLAYER_LOGIN` → `OnEnable` | Lifecycle events registered; `ContainerManager.Init` primes every container font (`FontPrimer.PrimeAll`, below), then builds an instance per container and applies them (a disabled login builds none: the stand-up primes and builds them); `BlizzardFrames.Apply`; the options panel category is created. Built here, not at load, so the engine's access restrictions (applied at `PLAYER_ENTERING_WORLD`) come after every button's first `initializeFrame` |
| `PLAYER_ENTERING_WORLD` | Visibility pass; flush anything pending; `FontPrimer.OnEnterWorld` notes the time (the loading screen is still up), and arms the primer's hide and refresh itself only on a client that refused `LOADING_SCREEN_DISABLED` |
| `LOADING_SCREEN_DISABLED` | The loading screen has ended: `FontPrimer.OnLoadingScreenEnd` runs a priming pass (a font refused under the loading screen is tried again), then arms the primer's hide and refresh when anything was primed since the last loading screen (below); and arms the weapon-enchant reset 1.75 s later, whatever the primer did (`CM.RequestEnchantReset`, SP-AMX-01) |
| `ZONE_CHANGED_NEW_AREA` | Visibility pass: the zone gate reads the kind of place again (`NS.Compat.InstanceType()`), so a container whose Show in box is unticked there hides, through the engine's `SetEnabled`, in combat too |
| `PLAYER_REGEN_DISABLED` / `ENABLED` | Visibility pass; on combat end, flush pending applies, apply the Blizzard-frame settings, and place again any frame-attached container whose frame appeared during combat |
| `ADDON_RESTRICTION_STATE_CHANGED` | Flush pending applies — secrecy can lift outside a combat transition (a key or encounter ending) |
| `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED`, `UNIT_PET` | Every container on that unit calls the engine's `UpdateAllAuras`, because the engine keeps showing the old unit's auras until told. On a target or focus swap each such container first switches to the view of its plan the new unit's reaction picks (`CM.ApplyViews`, spell-list views V2), and after the refresh each container whose Unit type answer moved re-runs its visibility pass (`CM.ApplyUnitGate`, filter situations S6) |
| `UNIT_FACTION`, `UNIT_FLAGS` (target, focus) | The unit's reaction may have moved without a swap: `CM.ApplyViews` switches each container on it to the view that reaction picks (`ContainerClass:ApplyView`), in combat too. When one moved, EmptyWatch re-predicts at once (`EW.OnViewsMoved`), so the empty prediction follows the engine; then each container on it whose Unit type answer moved re-runs its visibility pass (`CM.ApplyUnitGate`, filter situations S6) |
| `UNIT_FACTION`, `UNIT_FLAGS` (player) | The player's own side moved (mind control): `CM.ApplyViews` for both target and focus, on `CM.viewPlayerFrame`, then one `EW.OnViewsMoved` if any view moved, then `CM.ApplyUnitGate` for both |
| `ADDON_LOADED` (any) | Frame-attached containers whose frame did not exist yet are placed again |
| `ITEM_DATA_LOAD_RESULT`, `GET_ITEM_INFO_RECEIVED` | When the item is the weapon equipped in slot 16 or 17 and the load succeeded, the weapon-enchant reset is armed 0.5 s later (`CM.OnWeaponItemData`); one timer, keeping the later deadline, so a burst flips once. The reset turns each live engine with enchant frames off and on again, so the weapon names are drawn afresh (`docs/midnight-quirks.md` → *Weapon enchants*) |
| Profile changed, copied or reset | `NS.OnProfileChanged`: `PrepareProfile`, selection cleared, `ContainerManager.Announce` (the new profile's fonts primed, instances follow the registry, apply all, `CONTAINERS_CHANGED`), Blizzard frames, panel refresh |

## The disabled state

**Disabled means the addon is not running.** Not hidden, not quiet, not skipping a repaint — not
running (slash-commands-§7). Unticking *Enable Aura Master*, or `/am disable`, or a profile switch to
a profile where the path is false, all land on the same seam and all produce the same outcome.

**One latch, two named holds.** `core/LifecycleSetup.lua` builds one `LibKa0s-Lifecycle-1.0`
instance. `disabled` is taken from the stored `enabled` path and is persisted; `perf` is taken by
`LibKa0s-Perf-1.0` for a capture's suspended arm and is session-only. The addon is down whenever at
least one hold is taken and comes back only when the last one is released, so `/am enable` during a
capture does not resurrect it mid-run and a resume at the end of one does not stand up an addon the
player switched off. There is no `StandUp()` to call; the only route out is releasing a hold.

**What stands down**, in the same turn as the write:

| | |
|---|---|
| The twelve lifecycle events | `addon:UnregisterLifecycleEvents()` — unregistered, not gated |
| `modules/TimedSpells.lua` | `TS.StandDown()`: its unit frame's `UNIT_AURA` (unregistered by hand; the frame is kept for the next stand-up), its gate events, its two bus subscriptions, and a queued scan timer, canceled |
| `modules/EmptyWatch.lua` | `EW.Stop()`: both unit frames' registrations (unregistered by hand; the frames are kept), its AceEvent pet, inventory, target and focus events, and a queued pass or enchant-expiry timer, canceled |
| `modules/ContainerManager.lua` | `CM.StopListening()`: its three bus subscriptions, its two view frames' `UNIT_FACTION` / `UNIT_FLAGS` (unregistered by hand; the frames are kept), the pending queue behind them, and an armed weapon-enchant reset, canceled; `CM.RequestEnchantReset` arms nothing while stood down |
| The coalescing apply timer | canceled by `CM.StopListening`; `CM.RequestApply` returns immediately, so nothing re-arms |
| `modules/FontPrimer.lua` | `FontPrimer.Stop()`, from `CM.StopListening`: the hide timer and the follow-up refresh, canceled, and the frame hidden; a stood-down addon hears no loading-screen event, so the primer stops waiting for one. The fonts it drew stay loaded, so what it primed is kept, and `PrimeAll` does nothing while stood down |
| `modules/FramePicker.lua` | `FP.Stop()` — the overlay's `OnUpdate` cleared |
| Every container | `ContainerClass:ShouldShow` answers no at **step 0**, so the engine is disabled, the preview and handle hidden and the anchor hidden |
| Blizzard's buff and debuff frames | reparented back where they belong: an addon that is not running must not still be hiding them |

**What survives, because it is setup and not a feature:** the chat command registration, the
dispatcher and `NS.COMMANDS`; the settings-category registration and the panel body; the AceDB
handle, `NS.SetByPath` and AceDB's three profile callbacks; the launcher's registration. The slash
surface is unchanged — see `docs/ARCHITECTURE.md` → *Slash Commands*.

**The combat carve-out.** Hiding a container's anchor is hiding an aura engine's ancestry, and
reparenting a Blizzard frame is refused under lockdown, so neither is attempted in combat. The
stand-down holds that half pending and finishes it on `PLAYER_REGEN_ENABLED` — the one registration a
disabled addon keeps — releasing it the moment it fires.

**Without LibKa0s the switch still works.** The master switch's row comes from the Master controls
composer, which answers no rows in a library-absent build (options-ui-§1). `enabled` and `locked` are
therefore declared in `NS.WRITE_THROUGH` (`settings/Schema.lua`), and `NS.SetByPath` stores such a
path raw when no row declares it, then logs and announces it; a path with a row always takes the row.
With no row there is no onChange, so `runEnabled` (`settings/Slash.lua`) calls `NS.SyncEnabled()`
after every successful write: idempotent on the live build, where the row's onChange already synced,
and what moves the latch on the library-absent one. The same list is handed to the Schema instance as
`writeThrough`, so a later adoption of the library's `Set` inherits it.

**Standing up rebuilds from current state**, never from a snapshot taken on the way down: a setting
changed while the addon was off is reflected when it comes back.

**A stood-down addon builds no container frame.** A login with the addon disabled builds none
(`CM.Init` reads the latch before `CM.Sync`), and neither does a profile switch, copy or reset made
while it is down (`CM.Announce` skips its sync, but still sends `CONTAINERS_CHANGED` so an open panel
re-renders). The stand-up calls `CM.Sync` before its visibility pass, so it builds, or revives, every
container the registry holds at that moment and draws them in the same turn. A profile change made
while down is remembered and passed to that sync, so a stand-up in combat parks every id the switch
reused, exactly as `CM.Announce(true)` would have, until the deferred apply rebuilds it. Between the
sync and the visibility pass it moves every target and focus container to the spell-list view its
unit picks now (`CM.ApplyViews`, SV-05): no swap or reaction event was heard while down, and the view
switch, unlike the apply, is never held, so a stand-up in combat cannot re-enable an engine on a stale
view.

**`/am diagnostics` still answers while down, and says so** (batch 10 F8). Its header adds one plain
line, `addon disabled: containers are not built; predictions only` after a login made while off,
the `... hidden and not updated; the plan lines are from the last apply` form once containers were
built, or `addon stood down (holds: ...)` for another hold, and each `[Plan] #N not built` names
its reason (`docs/debug.md`).

**Not a draw gate.** A handler that early-returns has not stopped watching, it has stopped reacting,
and the client still walks the registration list and still enters Lua on every event
(anti-pattern #85). `tests/test_disabled.lua` therefore asserts on the registration set, the live
timer set, the shown frames, the SavedVariables writes and the printed lines — never on a handler's
return value.

## Priming the fonts

WoW loads an addon font file lazily, and text first drawn in it before the load stays empty until it
is written again; the engine writes a bar's name only when an aura is assigned or updated, so such a
name stays blank (`docs/midnight-quirks.md`, *An addon font loads lazily, and the engine writes a name
once*). `modules/FontPrimer.lua` therefore draws each font before any container draws in it:

- **What.** Every (file, size, flags) triple of the active profile's containers, enabled or not: bar
  name, time and stacks, icon time and stacks, the Text line's font and the name label's font, each
  resolved by `Style.FontKey`, the resolution `Style.ApplyFont` sets. A `Fonts\` path is built into the
  client and skipped. A triple is primed once per session.
- **When.** `CM.StartListening` (the login's `CM.Init` and every stand-up), before the first build;
  the `CONFIG_CHANGED` handler, before the apply is requested; `CM.Announce`, before a profile switch,
  copy, reset or registry change is built (a profile switch sends no `CONFIG_CHANGED`). Never while
  stood down.
- **How.** A font string per new triple on one 1x1 frame on `UIParent`, above the top edge of the
  screen, shown and written with a sample of letters, digits and punctuation, then hidden 1 s later.
- **Refused.** A triple whose `SetFont` the client refuses is not marked primed: it keeps its font
  string on a refused set, and every later priming and the end of every loading screen tries it again
  (FP-07).
- **The follow-up.** A priming that drew anything arms one refresh 0.5 s later (re-arming restarts
  it), so text drawn in the font before it loaded is written again. Under the loading screen nothing
  is drawn, so a priming before the first loading screen ends arms neither timer and keeps the
  frame shown; `FontPrimer.OnLoadingScreenEnd` (`LOADING_SCREEN_DISABLED`, which comes after
  `PLAYER_ENTERING_WORLD`) then arms the hide 2 s and the refresh 1.5 s after it, when anything was
  primed since the last loading screen. The engine's text:
  `ContainerClass:Refresh`, the engine's `UpdateAllAuras`, on each live container that has an
  engine, is neither parked nor stale, and is shown and not previewing. The addon's own text, which
  an apply writes once and nothing rewrites (the name label, a Text line's literal pieces, the
  test-mode placeholders): one system apply of every container, `CM.RequestApply(nil, true)`, which
  waits quietly while an apply has to. It reads no aura and changes no setting.

## Registry changes

Create, delete and duplicate live in `modules/ContainerManager.lua`, the registry's one writer;
`Database.PrepareProfile` is its load pass (`docs/schema.md` → *Settings schema, registries and
named non-setting state*). Rename,
copy-from and reset positions live there too, but write through the seam. A structural change calls
`Announce` (instances follow the stored registry, everything re-applies, `CONTAINERS_CHANGED`).
Copy-from and reset positions are settings writes, not registry changes: each section they replace
is one whole-section write through `NS.SetByPath`, which announces `CONFIG_CHANGED`, and the applies
those writes queue coalesce into one pass. Copy-from is all or nothing: it checks every write with
`NS.CheckWrite` before making any, so a write the seam would refuse is reported and nothing is
copied. Deleting a container drops any container attached to it back to the screen, through the same
seam. Under `MustDefer`, an instance that leaves the registry is parked rather than destroyed:
`Container:Park` disables its engine and hides only the preview and handle. The next `FlushPending`
that may touch frames destroys every parked instance before it applies; a parked id that returns
first is revived in place and redrawn at once. A profile switch, copy or reset
(`NS.OnProfileChanged` → `CM.Announce(true)`) is the exception (and while the addon is stood down
it builds nothing; the stand-up syncs): ids are reused across profiles, so
under `MustDefer` every kept or revived instance is parked, and `Container:ShouldShow` keeps it off
until the deferred apply rebuilds it for the new data. One that leaves the registry on a profile
change is marked `staleData` as it parks, so a Create or Duplicate that reuses its id before that
apply (a reset rewinds the id counter) revives it still parked. A destroyed instance is kept dormant
under its id, never dropped: an id that returns out of combat revives it, marked `staleData`, and the
queued apply rebuilds it for the new data, so no second `AuraMasterAnchor<id>` is ever built.
Create and delete are refused in combat on every surface this addon owns. Reset all is not: it is Profiles → Reset Profile, so in
combat it takes the same parked path. `CONTAINERS_CHANGED` re-renders an open panel, because every
banner lists containers.

## Predicting an empty container

While unlocked and out of test mode, a container's followers hang from its one-element anchor, and its
placeholder outline shows, only while `Container:PredictEmpty()` (`EmptyWatch.Predict`) answers
true (batch 9 HG-1, E1 as amended by the owner on 2026-09-25). The engine cannot say whether it is
empty: its frame count is a pool that never shrinks, and its size is secret. So the prediction asks
`C_UnitAuras` the engine's question, per compiled group: a group with no candidate filters asks
`GetAuraSlots(unit, filter, 1)` whether any slot comes back; one with candidate filters reads each
slot's `AuraData` and tests the spell-id lists (only where the engine applies them: buffs of a unit you can
assist, debuffs of one you cannot), the dispel types, the max duration (a permanent aura never passes)
and the boolean flags. Weapon enchants come from `GetWeaponEnchantInfo`, with Hide permanent applied.
A group whose engine pool reads 0, or a unit that does not exist, needs no read. The answer is nil
(counted as not empty) in combat, while auras are secret, on a secret or raising read, and for a flag
the aura data does not carry.

`ContainerClass:ApplyHang` reads the prediction on every visibility pass that finds the container
shown, unlocked and not previewing, and marks it `watchEmpty`. `EW.Sync`, run after every visibility
pass and every apply pass, registers `UNIT_AURA` on the module's two frames only for the units of
watched containers, and only while unlocked, out of test mode, out of combat and while auras are
readable. An event marks one pass due 0.2 s later (a target or focus switch runs it at once,
folding in one already due, since the engine redraws for the new unit in that same frame); that pass re-predicts every watched container and
re-runs the visibility pass of each whose answer changed, which re-places its followers through
`Anchors.PlaceAttached`. A timer at the soonest enchant's expiry does the same, since a lapsing
enchant fires no `UNIT_AURA`. `PLAYER_REGEN_DISABLED` reaches `EW.SetCombat` before the combat
visibility pass, so that pass predicts nil and moves every follower onto its engine while that is
still allowed; `PLAYER_REGEN_ENABLED` predicts again.

## Learning timed buffs

`modules/TimedSpells.lua` listens only while an enabled buff container uses "only auras without a
duration" and the addon is not suspended. The gate events go through AceEvent on its own target:
`PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED` and `ADDON_RESTRICTION_STATE_CHANGED` all re-check
one gate, and `UNIT_AURA` is registered only while that gate is open (no combat lockdown, auras not
secret). `PLAYER_REGEN_DISABLED` closes it on the event itself: it fires before the lockdown begins.
The vendored AceEvent has no unit filter, so `UNIT_AURA` goes on the module's one private frame
(`TS.unitFrame`, events-frames-taint-§1's carve-out), registered with `RegisterUnitEvent` for the
player and pet only; the handler still proves the unit a safe key and compares it, as defense in
depth. Such an event, or the gate reopening,
schedules a scan half a second later, bracketed `timedScan`. A scan that comes due after the gate
closed (in combat, or while auras are secret) is dropped, and the gate reopening schedules a fresh
one. The scan runs only when `Compat.AurasAreSecret()` is false, reads the player's and pet's buffs
by index, and records every readable spell id with a readable positive duration into
`global.timedSpells` (through `Secrets.IsSafeKey` and `Secrets.IsReadableNumber`). A scan that
learned something sends `TIMED_SPELLS_CHANGED`; `ContainerManager` hears it and re-applies every
container, which updates their `excludeSpellIDs`. `/am forgettimed` empties the set and sends the
same message with `{ byPlayer = true }`: a scan's apply that has to wait says nothing, while the
player's forget is announced like a setting change.

## Where a container sits

`Anchors.Place` (`modules/Anchors.lua:306`) sizes the anchor to one element and attaches it: to
another container's engine frame (or its anchor, before the engine exists; or, while that container
previews, its preview extent, because the disabled engine keeps a stale rect; or, while it is unlocked,
not previewing and predicted empty, its one-element anchor, because an engine holding no aura is a
1x1 rect: the three-state `Anchors.HangMode`, recorded as `hangMode` by `ContainerClass:ApplyHang`,
batch 9 HG-1 and "Predicting an empty container" below),
unless that would loop;
to a named frame, if it exists and is not forbidden (one that does not exist yet marks the container
pending, re-placed on the next `ADDON_LOADED`; a forbidden one is never waited on, since no add-on
loading makes it a target); else to the screen at `container.position`. A pending resolve
is skipped under combat lockdown, so `PLAYER_REGEN_ENABLED` runs it again once combat ends. A
container set to a container or a frame that lands on the screen instead writes one `[Anchor]` debug
line, and so does a skipped resolve. Positions are stored, never read back off an engine frame, whose
geometry can be secret; the only positions read are a dragged anchor's own (at the start, to lift an
attached one onto UIParent, and after the drop, saved through the write seam against that
container's id) and, while a drag is live, the rects the snap aims at, every number through
`NS.Secrets.NumberOr` (*Drag to attach* below). The client never saves an anchor's position itself
(`SetDontSavePosition`), so a login cannot restore one over the stored position.

Attached to another container, the child joins it by two absolute points, `attach.childPoint` (its
own) and `attach.relPoint` (the parent's), each Automatic while unset (`Anchors.AttachPoints`, batch
11 G2, in `modules/Anchors_Attach.lua` with the rest of the join). Automatic takes the matching half of the default pair (`Anchors.AutoPoints`, G3): the parent's
vertical growth side, lined up with a Text child's justify, centered for an icons or bars child under
a Text parent justified Center, else on the side the parent's lines start from. The pair in effect is
classified against batch 9's nine sides under the chain's growth (`Anchors.AttachEdge`, G5); a free
pair, one of none of them, is placed at its X/Y alone, with no seam, no spread and no push, except
the three outside pairs on the parent's before side (the child's point mirroring the parent's across
the side its lines start from, as a drop above a parent growing down picks): those are moved out past
the parent's strip while it shows and its name label while that shows, in the parent's scale, so the
child never covers them (`beforeRoom`, DD-10), and `Anchors.PlaceAttached` re-places them when either
shows or hides.
Along the chain the gap across the seam is the child's own gap between consecutive elements in the
direction the chain stacks, its Spacing or, when it fills rows, its Line spacing (`Anchors.SeamOffset`,
SS-1); on a side it is the child's gap across (AP-2); the stored `attach.x` / `.y` add on top as a
nudge (SS-2). The seam is the same locked, unlocked and in test mode.

A join on the parent's center or end holds still while the parent's engine is empty (batch 11 T9).
An empty engine is a 1x1 rect at its start corner (since 2026-09-26 the unit just behind it: see the
next paragraph), so a relative point on the parent's center or far
side landed on that corner, and a centered chain shifted sideways by half an element whenever a middle
link had no aura. On each axis where the parent is exactly one element across (it fills columns with
no per-line limit, so one element wide; or rows, so one element tall; or lines of one) and the join
does not run along that axis, `attachSpec` moves the relative point to the parent's start side on
that axis and adds the offset back: half the parent's one-element size from the center, all of it
from the end, toward the growth, converted from the parent's scale to the child's. Both come from the
parent's own config (`Style.ElementSize`, its Scale), never the engine's geometry. The slot and the
preview block are one element across there too, so every hang mode lands in the same place. The
classification, the seam, the spread and the push read the points in effect, not the moved one. On
the axis the join runs along, an empty parent still closes the chain up, exactly to its start.

An empty link adds nothing along the chain (the engine lead, the owner's chain residue, 2026-09-26).
An engine that holds no aura is the flow layout's 1x1 minimum rect (`AnchorUtil.ApplyFlowLayout` sizes
it `math.max(size, 1)`, even after it held auras and emptied). When the engine was pinned at its
anchor's start corner, that rect's far edge sat one unit past the start. So each empty after-link
pushed the rest of the chain on by one unit: in client, the owner's #19, behind three empty links, sat
3 units above #22. Now `ContainerClass:Build` pins the engine `Container.ENGINE_LEAD` (1) units behind
its anchor's start corner on both growth axes (`Container.EngineOffset`), before the first
`AddAuraGroup`. `applyFlow` pads the engine's two start sides by the same unit
(`Container.EnginePadding`, a live `SetFlowLayoutPadding`, so the flow layout applies it by growth).
A populated engine's first element still starts exactly at the anchor's start, and its far edge is the
start plus its content. An empty engine spans the unit just behind the start, so its far edge is the
start. When a follower hangs from the engine, `attachSpec` takes the lead back on the relative point
(`engineLead`): a whole unit on a start-side part and half a unit on a middle part, toward the parent's
growth, in the child's scale. An end-side part needs nothing. So every populated landing is where it
was, including T9's across the chain. A follower hung from the slot or the preview (both sit at the
start) takes nothing. Nothing predicts emptiness and nothing reads the engine's geometry, which is
secret. So this holds locked, unlocked and in combat, and it holds live as the engine fills and
empties, with no re-place. The mouse blocker covers the engine, so it also covers that one-unit strip
on the start sides.

One element's size is `Style.ElementSize`. On a Text container with Size to fit on
(`container.text.autoSize`), it comes from the content instead of the stored width and height:
`Style.Text.AutoSize` measures the widest line over the placeholders, the sample and the worst-case
durations with the container's font, icon, gap and bounce, clamps the width, memoizes it per style
signature and falls back to the stored size when nothing can be measured (AS-2).

### Drag to attach

While unlocked, a screen container or one attached to another drags by its strip (issue #22,
`modules/Anchors_Snap.lua`); one on a named frame does not, and no drag starts in combat. The widget
asks `beginDrag` (its `canDrag`) immediately before `StartMoving`, so on a yes `Snap.BeginDrag` can
first hang an attached anchor from UIParent: where its left and bottom edges read, at them, so it does
not move; where they read secret (it hangs from an engine holding auras), centered under the cursor.
It sets `dragging`, which makes `Anchors.Place` leave the anchor where the drag has it, and starts
the driver: one frame whose OnUpdate is armed only while a drag is live and runs `Snap.Tick` at most
every 0.03 s. Once combat has started a tick shows nothing; otherwise `classify` works out what a
release now would do (below), and while Shift is not held `Snap.Find` measures, for every eligible container (enabled, its anchor shown, not the dragged one, not
one that follows it: `Anchors.WouldCycle`), the twelve outside pairs (each of its sides' start,
middle and end point joined to the dragged one's point mirrored across that side, absolute and
independent of growth; the three on its before side place as a free pair), side first and then by
alignment (the addendum's A7, `Snap.Nearest`): each side is eligible when the gap between the dragged
container's facing edge and it is at most `C.SNAP_RADIUS` (24 UIParent units) either way and their
spans along it overlap, with the target's widened by the radius; the side's pair is the start, middle
or end one by which third of that side the dragged container's center is over; the smallest gap wins,
ties to the lower id and then the table's order. Both containers are measured on their drag-handle
strips while each shows and reads (A10, `Snap.Footprint`); where a strip is hidden or does not read,
on A8's footprint: the block (the dragged one's anchor; the target's rect a follower would hang from,
`Anchors.HangFrame`, an engine that reads secret falling back to its anchor) with its name label taken
in while that shows and reads. The pick is marked by a green highlight (the addendum's A5, as A6 amends it):
the target's drag-handle strip has its OWN 1 px gold edge repainted 2 px in the mark's color, through
the painter that drew it (`Style.DrawEdge` on the strip, the same four textures; no frame of ours is
anchored to a strip, since A5's overlay hung on it never showed in game), and the widget's gold
(`Anchors.STRIP_EDGE`) painted back the moment the mark moves to another strip or hides, on every way a
drag ends, and from `ContainerClass:Destroy` (`Snap.ReleaseStrip`) when the strip's container is
destroyed mid-drag, so a dormant instance never comes back green; with a 10 px dot on the target's join point, one on the dragged
container's and a 2 px line between them, all in one color, the dots on the two strips. A target
with no visible strip (LibKa0s-Widgets absent, or its strip hidden) gets a box over its block (and name label) instead (`Snap.box`), so a mark
is never lost. The dots, the line and the box hang from UIParent, never from the target. A container attached to another has a
leeway (the owner-feedback addendum's A4): a pair found that way wins only when its gap is strictly
under the leeway's measure of the container's CURRENT pair (its stored pair in effect, `Anchors.AttachPoints`,
measured from its own point now to its parent's point now, on the two strips, or where a strip does not
show or read the parent's block on `Anchors.HangFrame` with no fallback to the anchor): the nearer of
that distance and how far it has moved since the drag began. On the strips those two points rest a
whole parent block apart, so the distance alone let any neighbor's strip in snap range take a container
picked up and let go where it sits; the measure is 0 there (DD-15R). Nor does the pair the pick gave where the
container rested when the drag began win while the container is still there, within 2 UIParent units
(`REST_SLACK`; a child as wide as its parent rests centered, so that pick is its middle pair, whatever
pair it is stored by), so a container picked up and let go where it sits keeps its pair; moved further,
that pick competes like any other pair, so a child wider than its parent, whose rest pick is the end
pair, can still be dropped onto it, and never a pair of the current parent
while that parent's block does not read (the snap measured it on the one-element fallback). When the
pick IS the current pair (measured, the parent's block reading), the container holds whatever the
leeway below says: A7 makes that pair the pick anywhere over its third of the parent's side, so a child
flush under a long parent can be in snap range of its own pair far past `C.DETACH_RADIUS` from that
pair's two points, and it must not turn red there. Otherwise,
while that pair's two points are at most `C.DETACH_RADIUS` (128 UIParent units, A9) from where they were
when the drag began (read before the lift, where its settings put it: the seam gap, its strip and
label room and its X/Y nudge already between them), or from each other, the mark stays green on the current pair (a *hold*); beyond it,
the repainted strip (or the box), both dots and the line all turn red (`C.DETACH_COLOR`, a *detach*). Shift suppresses only
the other pair. When the parent does not read (hidden, or its hang frame secret, as an engine holding
auras is), the hold lasts while the cursor has moved less than `C.DETACH_RADIUS` from where the drag
began, and the dots and the line, having no parent rect to sit on, collapse onto the dot on the dragged
container's join point, green and then red, with the parent's strip still repainted when it shows one,
else a dot-sized box on that dot (a hold or a detach is always drawn on the rect the leeway measured,
never on the one-element fallback); a parent with no live instance gives no hold at all. A screen container has neither. A strip hidden mid-drag (`/am lock`, a
stand-down or a disable run while the button is held) is sent no OnDragStop, so the tick itself
cancels that drag once out of combat: the anchor stops moving, `dragging` is cleared and the
container is placed back from its settings, with nothing written. `ContainerClass:Destroy` ends a
drag still live on the instance it tears down.

`Snap.Drop`, the strip's OnDragStop, reads combat and runs `classify` again at the drop (never the
last tick's answer) and writes through the seam against this container's id, never the panel's
selection:

1. **Combat started mid-drag:** nothing attaches. A screen container stores its position as before; an
   attached one writes nothing and is held: `Snap.PlaceHeld`, at `PLAYER_REGEN_ENABLED`, puts it back
   on its parent, even while auras stay secret and ContainerManager still holds applies.
2. **A candidate and no Shift** (for an attached container, one nearer than its current pair): the whole `container.attach` section (mode container, the target,
   the picked side's two points, both nil when the side is Automatic's and both absolute otherwise,
   `Snap.FoldPoints`, and X/Y 0; the frame mode's keys kept) goes to `NS.AttachByDrop`
   (`settings/Layout.lua`). It writes it, or,
   when the chain the drop joins flows differently, shows the `AURAMASTER_ATTACH_FLOW` popup (GC-1)
   carrying the section, whose Accept writes it and whose Cancel leaves everything as it was. Either
   way the container is placed at once from its settings as they then are (`Anchors.Place`): on its
   new parent, or back where it was until the popup is answered. It never waits for the apply, which
   ContainerManager holds while auras are secret, as between pulls in a key.
3. **A hold** (an attached container within the leeway): nothing is written; the container is placed
   back on its parent from its settings (`Anchors.Place`).
4. **Otherwise:** an attached container detaches. `Anchors.SavePosition` stores the drop position,
   then the section is written with mode screen and X/Y 0, the target and points kept. A position that
   reads secret is not stored, and the container goes back to its parent instead. A screen container
   stores its position, as it always did.

A whole-section write of `container.attach` sends one `CONFIG_CHANGED` whose path re-applies the
container's followers and the container it names (`docs/schema.md`), as a write to its mode, target or
points does. Each outcome writes an `[Anchor]` line: `drop: attach to <id> <side>`, `drop: held
(leeway)`, `drop: detach`, `drop: moved` or `drop: held (combat)`.
