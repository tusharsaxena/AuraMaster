# Midnight quirks — the 12.1 aura restrictions and how this addon works around them

Every behavior of the Retail 12.x client ("Midnight") this addon shapes itself around, and the code
that does it. When something breaks at patch time, look here first. Retail only — these are
cross-patch facts, never game-flavor branches.

## Aura data is secret, and in 12.1 it is secret wholesale

**The restriction.** While an addon restriction is active — the player in combat, an instance
encounter in progress, a Mythic+ keystone running, a PvP match running, or a restricted map — the
client returns aura data to addon code as **secret values**. From 12.1 an aura-data struct is fully
secret while auras are secret, the `UNIT_AURA` payload is secret, and the by-index, by-slot and
by-instance-id aura APIs error when an addon calls them. Tainted code may store a secret, pass it to
a function or hand it to a widget setter; it may not compare it, do arithmetic on it, use it as a
table key, index it or run `#` on it.

**What this addon does.**
- **It reads no aura in combat.** All display goes through Blizzard's aura engine (next section).
- `core/Secrets.lua` is the only file that asks whether a value is secret (`IsSecret`, `CanAccess`,
  `IsReadableNumber`, `IsSafeKey`), and it degrades to "nothing is secret" on a client without
  `issecretvalue` / `canaccessvalue`.
- `Compat.AurasAreSecret()` (`core/Compat.lua:40`) wraps `C_Secrets.ShouldAurasBeSecret()` and gates
  everything that would touch an aura or an aura button.
- The one place that does read auras, `modules/TimedSpells.lua`, runs only when that answers false,
  and checks every field through `core/Secrets.lua` before comparing or keying on it.
- Every chat and debug line goes through `NS.SafeToString` (LibKa0s-Core), so a secret can never
  reach `table.concat` or `string.format`.

**Measured in-game, client 12.1.0 (120100), 2026-09-18** (a throwaway probe for issue #8, run in
open-world combat, on a target dummy, on dungeon trash and during a boss encounter):
- `ShouldAurasBeSecret()` answered true in **every** combat context, the open world included, not
  only in instances.
- In combat, `C_UnitAuras.GetAuraDataByIndex`, `GetUnitAuras` and `GetAuraSlots` **raised on every
  call** (7,500 calls, 0 readable ids) with *"Auras cannot be accessed when secret while tainted by
  '<addon>'"*. Every addon is tainted, so no addon code reads an aura id in combat.
- The `UNIT_AURA` payload table itself arrived plain, but its `addedAuras` was secret in combat, so no
  id reaches addon code through the payload or `GetAuraDataByAuraInstanceID` either.
- Out of combat every route read every id and name, inside a dungeon between pulls too.
- `ADDON_RESTRICTION_STATE_CHANGED` carries `(type, active)`. Type `0` tracked combat and fired with
  `PLAYER_REGEN_DISABLED` / `_ENABLED`. Types `1` and `5` went active together at
  `ENCOUNTER_START` and cleared at `ENCOUNTER_END`. Type `4` went active on entering a dungeon
  and did not clear, yet auras stayed readable there out of combat.

So learning spell ids from auras can only happen out of combat: `modules/TimedSpells.lua`'s gate
is the most any feature can have. A seen-aura cache that had to learn in combat (#8) was dropped
for this reason.

## The display is Blizzard's AuraContainer

**The restriction.** An addon that cannot read auras cannot decide what to draw. 12.1 supplies the
replacement: the `AuraContainer` widget (`CustomAuraContainerTemplate`), which registers `UNIT_AURA`
itself, gathers auras against declared groups, and creates and fills `AuraButton`s in secure code.
`SecureAuraHeaderTemplate` is no longer available on Retail.

**What this addon does.** Every container is one `AuraContainer` engine (`modules/Container.lua:215`). The addon
declares groups — `AddAuraGroup(key, filterString, { candidateFilters, sortMethod, sortDirection,
maxFrameCount, layout, initializeFrame })` — compiled from the settings by
`modules/FilterCompiler.lua`, and dresses each button in `initializeFrame` (`modules/Style.lua`). The
engine owns everything per aura: gathering, sorting, layout, timers, the tooltip, cancel.

## Aura buttons lock while auras are secret

**The restriction.** An `AuraButton` becomes forbidden to tainted code whenever auras are secret —
after its `initializeFrame` has run. Its child regions cannot be reparented afterwards. The engine
applies these access restrictions from `PLAYER_ENTERING_WORLD`.

**What this addon does.**
- **Builds at `PLAYER_LOGIN`** (`core/AuraMaster.lua:39`), before the restrictions apply, so every
  button's first dressing has an unrestricted window.
- **Defers every structural apply and restyle** while `Compat.AurasAreSecret()` or
  `InCombatLockdown()` is true (`ContainerManager.MustDefer`, `modules/ContainerManager.lua:161`),
  prints one notice, and flushes on `PLAYER_REGEN_ENABLED`, `PLAYER_ENTERING_WORLD` and
  **`ADDON_RESTRICTION_STATE_CHANGED`** — secrecy can end without a combat transition (a key or an
  encounter finishing).
- **Creates every region as a descendant of the button**, once, in `initializeFrame`, stored on
  `frame.__am` (`modules/Style_Bars.lua:32`, `modules/Style_Icons.lua:22`).
- **Guards every binding** with `pcall` (`Style.Bind`, `callEngine`), so a refusal costs one binding,
  not the engine's frame batch.

## Anchoring an aura container

**The restriction.** Once an engine has an aura group, it forbids untrusted layout scripts, and an
addon can no longer anchor it. Another frame may only anchor **to** an aura container if it inherits
`DisableUntrustedLayoutScriptsTemplate`. Containers with groups no longer receive `OnSizeChanged`, and
their geometry can be secret.

**What this addon does.** The engine is anchored to its container's anchor frame *before* the first
`AddAuraGroup` (`modules/Container.lua:219-223`). Every anchor frame, and the frame picker's outline,
inherits `DisableUntrustedLayoutScriptsTemplate`, so a container can attach to another container's
engine (`modules/Anchors.lua`) and the picker can outline one. Positions are computed from settings,
never read back off an engine frame; the anchor is sized to one element from config.

**The cost of the template: no tooltip can anchor under an anchor.** The restriction carries down the
anchor chain. `GameTooltip` does not inherit the template, so `GameTooltip:SetOwner` on the drag handle
or its help mark, both anchored under the anchor, raises "Anchoring disallowed as dependent object
would inherit forbidden aspects: UntrustedLayoutScriptExecution". The handle's tooltip is owned by
`UIParent` with `ANCHOR_CURSOR` instead, so it depends on nothing under the anchor.

## Groups are add-only, and some setters reset a group

**The restriction.** An engine cannot remove a group, and WoW never frees a frame.
`SetAuraGroupCandidateFilters` clears and re-gathers the group's auras.

**What this addon does.** A plan of the same shape (group count, enchant slots and their
hide-permanent flag, style —
`FilterCompiler.StructureKey`) is applied in place, calling only the setters whose values changed;
candidate filters are compared with `FilterCompiler.Signature` first (`modules/Container.lua:289-290`). A
new shape disables, hides and retires the old engine and builds a new one (`Container:Retire`).

## Spell-id filters are honored only on one side of the friend/foe line

**The restriction.** The engine applies identity candidate filters (`includeSpellIDs`,
`excludeSpellIDs`) only to buffs on friendly units and debuffs on hostile units.

**What this addon does.** The filters still compile, because a target or focus can be either, but
`FilterCompiler` adds a per-container warning wherever a spell-id filter is in play
(`identityWarning`, `modules/FilterCompiler.lua:558`): ignored outright for debuffs on the player or pet, conditional on
hostility or friendliness for target and focus. The Filters page prints them in orange. The starter
spell lists are all buff categories for the same reason (`defaults/Categories.lua`).

## There is no "no duration" filter, and `maxDuration` drops permanent auras

**The restriction.** Candidate filters include `maxDuration`, and setting it excludes permanent
auras. Nothing selects auras *without* a duration.

**What this addon does.** "Only auras with a duration" is `maxDuration = math.huge`. "Only auras
without a duration" excludes every spell id the addon has seen carry a duration, learned out of
combat by `modules/TimedSpells.lua` into `global.timedSpells` — TinyBuffBars' approach (MIT). A max
duration is ignored in that mode, with a warning.

## A permanent aura would draw an empty bar

**The restriction.** The engine drives a `StatusBar` by time (`SetDurationBar`, direction elapsed or
remaining). Driven by remaining time, a permanent aura has none and draws empty.

**What this addon does.** The status bar runs on **elapsed** time with an invisible texture, and the
addon's own `fill` texture stretches from the bar's start to that texture's moving edge
(`modules/Style_Bars.lua:183`). Zero elapsed is a full bar; a timed aura drains. The technique is
TinyBuffBars' (MIT).

## Nothing tells a region whether an aura has a duration

**The restriction.** No binding shows or hides an arbitrary region by whether the aura has a
duration, and the duration itself is secret, so Lua cannot test it. `SetDurationBar` neither hides
nor resets the bar for a permanent aura.

**What this addon does.** With Bars → General → **Show the spark on auras without a duration** off, a
live bar's spark rides a clip frame (`SetClipsChildren`) bounded by the elapsed region, the engine's
status-bar texture, and sits wholly on that side of the moving edge (`modules/Style_Bars.lua:145`).
A timeless aura has zero elapsed, so the clip frame has no width and the spark is clipped away. A
timed bar's spark sits just inside its edge rather than centered on it. This rests on the client
leaving a zero-duration bar's texture at zero width, which is an in-game check (smoke check 26). The
preview reads its placeholders' durations and hides the spark directly.

## Text chains and animations on engine buttons

**Measured in-game, client 12.1.0 (120100), 2026-09-18** (two throwaway probes, 40 player-buff
buttons each, for issue #2):
- Every binding the Text style uses was accepted: `SetSpellName`; `SetApplicationCount` with a
  `C_StringUtil.CreateNumericRuleFormatter` whose breakpoints `{0: ""}, {2: " x%d"}` hide a single
  stack; `SetDurationText` with `textFormat = { formatString, components }` (several `{}` in one
  string) and a prebuilt `C_DurationUtil.CreateDurationTextBinding()` carrying
  `SetZeroDurationText("")`, `SetExpiredText("")` and `SetUpdateInterval(0.1)`; a stepped
  `C_CurveUtil` color curve on `RemainingDuration`. `RemainingPercent` arrives on a 0–100 scale.
- A timeless aura writes nothing through that binding, so text folded into the duration's format
  disappears with it.
- A stepped curve with alternating alpha blinks the duration text in the last seconds, in and out of
  combat.
- AnimationGroups started at dress time keep playing through combat and after it. In combat every
  call on the button's objects raises "Attempt to access forbidden object from code tainted by an
  AddOn" (`AnimationGroup:IsPlaying/Play/Stop`, `Region:IsShown`, `IsAnchoringSecret`), so an
  animation is set up at dress time only.
- `FontString:IsAnchoringSecret()` answers true even out of combat for an engine-written name: no
  width in a chain can be read, so a multi-piece line cannot be centered.
- A **Scale** animation broke a left-justified chain (the glyphs grew about 8 % past their boxes and
  overlapped the next piece); an Alpha animation did not. Round 2, four chains each piece boxed and
  tinted, laid out cleanly in and out of combat: the client sizes an engine-written, single-anchored,
  auto-sized font string to its secret text, and a chain anchored to it lays out right.

So a Text line is a chain of single-anchored, auto-sized font strings (`modules/Style_Text.lua`),
its loops are Alpha and Translation only, built and played at dress time.

## Additive bindings stack

**The restriction.** `AddDispelTypeTexture` and `AddPandemicRegion` append to the button.

**What this addon does.** Every live restyle empties both lists FIRST, before any other binding,
through `Style.ClearAdditiveBindings` (`modules/Style.lua:277`), and then adds again
(`modules/Style_Bars.lua:299`, `modules/Style_Icons.lua:149`). The order matters: every `Set*` /
`Add*` binding re-runs the engine's whole apply pass, which re-tints, shows or hides each dispel
texture still listed, while `ClearDispelTypeTextures` itself touches no region. A clear made after
the bindings let a bar switched away from Color by → Dispel type keep the tint (B-4). For the same
reason the dress shows the bar's fill every time: the engine's pass on a button holding no aura
hides it, and clearing does not show it again.

## The engine does not notice a unit token changing

**The restriction.** A container on `target` keeps showing the previous target's auras until told;
`UpdateAllAuras` exists for external refreshes such as target changes.

**What this addon does.** `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED` and `UNIT_PET` (for the
player) call `UpdateAllAuras` on every container on that unit (`core/AuraMaster.lua:89-101`).

## Weapon enchants

**The restriction.** Temporary weapon enchants are not auras; the engine shows them per slot through
`AddItemEnchantment(slot, options)`, which returns a frame outside any group. The player's enchants
also live inside Blizzard's `BuffFrame`.

**What this addon does.** Enchant slots (`Compat.EnchantSlot`, main hand / off hand / ranged) are
added after the groups, ordered by duration, with `hidePermanent`, and their frames are kept in
`enchantFrames` so a restyle can reach them. `hidePermanent` is taken only when a slot is added, so
toggling *Hide enchants without a duration* is a change of shape and rebuilds the engine; a change of
sort direction re-sends the enchant sort in place, once. Hiding Blizzard's buff frame takes its
enchants with it, and the setting's description says so.

## Combat state: which question to ask

- **`UnitAffectingCombat("player")`** answers General visibility (`Container:ShouldShow`) — the
  player's combat state, available at the `PLAYER_REGEN_DISABLED` edge.
- **`InCombatLockdown()`** gates secure-adjacent writes: building or rebuilding an engine,
  reparenting Blizzard's frames, starting a drag, the frame picker, opening a settings category,
  creating a container, and tearing one down. A container that leaves the registry in combat is
  parked (engine disabled, anchor untouched) and destroyed once combat ends.
- **Visibility in combat is the engine's `SetEnabled`**, not `Show`/`Hide` on an ancestry holding
  aura buttons (`modules/Container.lua:433`).

## Smaller API moves this addon absorbs

- **Filter tokens.** 12.1 re-added `IMPORTANT`, added `DISPELLABLE` and `!` negation, and removed
  `NOT_CANCELABLE` (use `!CANCELABLE`). The categories use `BIG_DEFENSIVE`, `EXTERNAL_DEFENSIVE`,
  `IMPORTANT`, `RAID`, `CANCELABLE`, `CROWD_CONTROL`, `RAID_IN_COMBAT`, `RAID_PLAYER_DISPELLABLE` and
  `DISPELLABLE`, and hide with `!TOKEN`.
- **Engine enums** (`AuraContainerSortMethod`, `AuraContainerSortDirection`,
  `AuraContainerItemEnchantmentSlot`, `AnchorUtil.FlowLayoutAxis`/`FlowDirection`,
  `Enum.StatusBarTimerDirection`, `Enum.StatusBarInterpolation`,
  `Enum.CustomAuraButtonDispelTypeTextureStyle`) are read through `core/Compat.lua`, each with a
  plain fallback.
- **Duration text** is formatted by the engine from a `C_StringUtil.CreateSecondsFormatter` the addon
  builds, and recolored in the last seconds by a `C_CurveUtil` step color curve over remaining time —
  neither needs the addon to see the duration (`Compat.CreateSecondsFormatter`,
  `Compat.ExpiringTextColor`). Both are built once per look and the same object is handed to every
  button that shares it (`modules/Style.lua`). That the engine accepts one formatter or curve shared
  across buttons is not yet verified in the client; if it does not, the memo moves to one per
  container.
- **The engine's default duration text truncates** (`DefaultAuraDurationFormatter` in
  `Blizzard_AuraContainerShared.lua` sets `SecondsFormatterRounding.Truncate`), so 12.7 s reads "12"
  beside a cooldown countdown that reads 13. Every format the addon builds sets `RoundUp` instead, and
  the Blizzard format is a copy of that default (one letter, one unit, the same step curve for the
  largest unit) that rounds up. The countdown's own rounding is in C++ and undocumented, so the match
  is an in-game check.
- **`GetMouseFocus` was removed in 11.0** in favor of `GetMouseFoci`; the frame picker uses the first
  frame it returns (`Compat.GetMouseFocus`).
- **Right-click cancel** is `SetCancelAuraButtons("RightButtonUp")` — one phase, so a button
  reassigned between press and release cannot cancel the wrong aura.
- **Blizzard's buff display is an Edit Mode system**, so `Hide()` does not stick and spreads taint;
  it is reparented to a hidden frame instead, out of combat (`modules/BlizzardFrames.lua`).

## Creating a container

Four client facts decide how `modules/Container.lua` builds an engine, each read from Blizzard's own
`Blizzard_AuraContainer` source (and matching what EllesmereUI's aura kit does):

- **The engine is a load-on-demand add-on.** `CustomAuraContainerTemplate` and every enum
  `core/Compat.lua` reads live in `Blizzard_AuraContainer`, which is not loaded until something asks.
  `Compat.EnsureAuraContainer()` calls `C_AddOns.LoadAddOn("Blizzard_AuraContainer")` before the first
  container is built; without it `Compat.HasAuraContainer()` would answer false on a healthy client.
- **It needs a size from the start.** The engine drains its parse and layout work from an `OnUpdate`
  that runs only while visible, so a new engine gets a provisional `SetSize(1, 1)` right after it is
  anchored; every layout pass replaces it with the real size.
- **Anchor first, groups second, unit last.** `AddAuraGroup` forbids untrusted layout work on the
  container, after which it can no longer be anchored — so the engine is anchored before its first
  group, and never re-anchored or cleared afterwards (a retired engine is disabled and hidden where it
  stands). `SetUnit` comes last, once every group exists, so `UNIT_AURA` is registered for a container
  that already knows what it is looking for.
- **A disabled engine draws nothing.** `SetEnabled(false)` unregisters its events and its next rebuild
  clears every button (`ManagedAuraContainerPrivateMixin:ParseAllAuras`), which is why preview and the
  General visibility gate disable the engine instead of hiding frames an aura button descends from.

The frame picker cancels itself if combat starts mid-pick: its overlay toggles keyboard propagation,
which is protected under combat lockdown (`modules/FramePicker.lua`).
