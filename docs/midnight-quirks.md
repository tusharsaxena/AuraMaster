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

**What this addon does.** Every container is one `AuraContainer` engine (`modules/Container.lua:220`). The addon
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
`AddAuraGroup` (`modules/Container.lua:224-228`). Every anchor frame, and the frame picker's outline,
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
hide-permanent flag, style, growth corner —
`FilterCompiler.StructureKey`) is applied in place, calling only the setters whose values changed;
candidate filters are compared with `FilterCompiler.Signature` first (`modules/Container.lua:292-300`). A
new shape disables, hides and retires the old engine and builds a new one (`Container:Retire`).

## Spell-id filters are honored only on one side of the friend/foe line

**The restriction.** The engine applies identity candidate filters (`includeSpellIDs`,
`excludeSpellIDs`) only to buffs on friendly units and debuffs on hostile units.

**What this addon does.** The filters still compile, because a target or focus can be either, but
`FilterCompiler` adds a per-container warning wherever a spell-id filter is in play
(`identityWarning`, `modules/FilterCompiler.lua:548`): ignored outright for debuffs on the player or pet, conditional on
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
(`modules/Style_Bars.lua:158`). Zero elapsed is a full bar; a timed aura drains. The technique is
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
  width in a chain can be read, so a multi-piece line cannot be centered as one line (Center stacks
  it in rows instead, feedback #1).
- A **Scale** animation broke a left-justified chain (the glyphs grew about 8 % past their boxes and
  overlapped the next piece); an Alpha animation did not. Round 2, four chains each piece boxed and
  tinted, laid out cleanly in and out of combat: the client sizes an engine-written, single-anchored,
  auto-sized font string to its secret text, and a chain anchored to it lays out right.

So a Text line is a chain of single-anchored, auto-sized font strings (`modules/Style_Text.lua`),
its loops are Alpha and Translation only, built and played at dress time.

**The gap between pieces (smoke batch 2, item 8).** The client pads an auto-sized font string on both
sides, so pieces chained edge to edge showed gaps no template asked for (`Fire Breath - Magic - 6 s`
for `$spellname$-$dispeltype$-...`), while the duration run, one engine string, had none. The padding
belongs to the font, not the text, so it is measured on the addon's own hidden, never-secret string:
`W("a") + W("b") - W("ab")`, never below 0, once per font, size and flags (`Style.PiecePadding`), and
each chained piece is anchored that far back over the one before, every piece justified to the
chain's side. A font it cannot measure chains at 0, as before. An empty field still has a width no
addon code can read, so its separator cannot be dropped by measuring: a separator written inside the
field's brackets (`$spellname$[-$stacks$]`) goes with the field, and the Text page's Rules list says so.

## Additive bindings stack

**The restriction.** `AddDispelTypeTexture` and `AddPandemicRegion` append to the button.

**What this addon does.** Every live restyle empties both lists FIRST, before any other binding,
through `Style.ClearAdditiveBindings` (`modules/Style.lua:338`), and then adds again
(`modules/Style_Bars.lua:310`, `modules/Style_Icons.lua:149`). The order matters: every `Set*` /
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
  aura buttons (`modules/Container.lua:447`).

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
  stands). So the growth corner it is pinned at is part of its shape: a Grow vertically or Grow
  horizontally change that moves the corner rebuilds the engine rather than sending the new flow
  anchor point to one still pinned at the old corner. `SetUnit` comes last, once every group exists, so `UNIT_AURA` is registered for a container
  that already knows what it is looking for.
- **A disabled engine draws nothing.** `SetEnabled(false)` unregisters its events and its next rebuild
  clears every button (`ManagedAuraContainerPrivateMixin:ParseAllAuras`), which is why preview and the
  General visibility gate disable the engine instead of hiding frames an aura button descends from.

The frame picker cancels itself if combat starts mid-pick: its overlay toggles keyboard propagation,
which is protected under combat lockdown (`modules/FramePicker.lua`).

## An attached anchor's geometry is secret

**The restriction.** A frame anchored to an aura engine container — or to any frame anchored to one —
inherits its secret geometry, and so does everything anchored under it. Its width, its points and its
frame level (`FrameLevel` is a `SecretAspect`) can read back as secret numbers even out of combat, and
arithmetic on a secret raises "attempt to perform arithmetic on a secret number value" (feedback E,
2026-09-19: the drag handle's label, on a container attached to another).

**What this addon does.** Nothing reads a measurement off a region that can be **attached**. The
handle's label is measured on a detached font string of ours (`Anchors.__labelMeasurer`), and every
frame level or offset read on an attachable frame (the anchor, an attach target's anchor, an engine)
goes through `NS.Secrets.NumberOr`, falling back to the stored level or 0, or through
`NS.Secrets.CanAccess` (`Anchors.SavePosition`, which only stores a drag when every field it read is
readable, never a fallback number). The two exceptions D-E leaves alone are `modules/Style_Bars.lua:64`
and `modules/Style_Icons.lua:59`, which call `GetFrameLevel` on a frame `initializeFrame` itself just
created, not one anchored to anything, and have run unguarded in combat builds since batch 1.

## An empty duration run still takes a space (open, feedback #5)

**What was seen.** The owner's template `($remainingpercent$)` drew `( )`: the literal `(`, then the
duration run, then the literal `)`, with a space where the number should be. The run is one
single-anchored, auto-sized font string the engine writes into, so whatever it wrote was EMPTY, and
the gap is that empty string's own width.

**What could empty it**, and what this addon changed:
- **H1: the rule formatter.** The percent rule was `"%d%%"`, and `RemainingPercent` arrives as a
  fractional 0–100 value. If the client's `%d` writes nothing for a non-integer, the run is empty. Fixed
  here either way: the rule is now `"%d"` with `step = 1` (`modules/Style.lua`'s `PERCENT_BREAKPOINTS`),
  so `%d` only ever sees a whole number, and the player types the `%`.
- **H2: a timeless aura.** The engine disables the duration binding for a zero duration
  (`ApplyDurationText`: `binding:SetEnabled(not auraDuration:IsZero())`), and the binding's zero text is
  `""` (`Compat.CreateDurationBinding`). Nothing to fix: this is text outside `[ ]` showing on a
  timeless aura, by design. The Text page's cheat sheet now says to write `[ ($remainingpercent$%)]`.
- **The gap itself** would then be the client laying an empty, single-anchored font string out with a
  non-zero width, which no addon code can read (the string is engine-written and secret) or trim.

**The in-game check** (docs/smoke-tests.md section T) runs three `/run` probes that tell these apart:
the rule formatter on `45.5` and `45`, the binding's zero-duration text, and an empty font string's
width.

## Many debuffs carry no dispel type (smoke batch 2, item 2)

**What was seen.** A bar container on the target's debuffs, colored by dispel type, drew a Paladin's
Consecration, Judgment, Empyrean Hammer, Seal of Reprisal and Blessed Hammer in blue, and a Text line's
`$dispeltype$` showed nothing for them. Text and bars read the same engine key, the aura's `dispelName`
or `"None"`, so they cannot disagree about one aura: those debuffs almost certainly carry no dispel
type (a Magic, Curse, Disease or Poison type is what a player can dispel, and a class's own damage
debuffs usually have none; bleeds carry `Bleed`). The blue is most likely the bar's default fill,
close to the Magic swatch, which a typeless aura keeps.

**What this addon does.** Nothing changes in code: a typeless aura keeps the surface's own color and
draws no type word, backdrop or edge. The Bars page's Color by tooltips and General -> Dispel Colors
say that buffs and many debuffs have no type, rather than citing one rare debuff.

**The probe.** Out of combat, with a target carrying the debuffs, paste the three lines one at a time.
They print, per harmful aura: its index, name, `auraInstanceID`, `isFromPlayerOrPlayerPet`,
`dispelName`, and the red channel of the color a curve returns for its dispel type (the curve maps the
type's enum `x` to red `x/15`, so the enum is `red * 15`). Every value goes through an `issecretvalue`
guard and every call through `pcall`.

```
/run S=function(v)return issecretvalue and issecretvalue(v)and"SECRET"or tostring(v)end K=C_CurveUtil.CreateColorCurve()K:SetType(1)for x=0,15 do K:AddPoint(x,CreateColor(x/15,0,0,1))end
/run R=function(i,a)local k,c=pcall(C_UnitAuras.GetAuraDispelTypeColor,"target",a.auraInstanceID,K)print(i,S(a.name),S(a.auraInstanceID),S(a.isFromPlayerOrPlayerPet),S(a.dispelName),k and c and S(c.r)or S(c))end
/run for i=1,40 do local o,a=pcall(C_UnitAuras.GetAuraDataByIndex,"target",i,"HARMFUL")if not(o and a)then print("end",i,S(a))break end R(i,a)end
```

**Result (2026-09-19, out of combat, the owner's own debuffs on a target):**

```
1 Blood Plague    69 true Disease 0.20000001788139
2 Insidious Chill 73 true nil     0
3 Wave of Souls   77 true Magic   0.066666670143604
4 Brittle         83 true nil     0
5 Ratfang Toxin   13 true Poison  0.26666668057442
end 6 nil
```

Every aura was applied by the player (`true`), and three of five carry a type: Disease (enum 3),
Magic (1), Poison (4). Being cast by the player does not strip the type. The other two print
`dispelName` `nil` and enum 0 ("None"). The engine itself reports those debuffs as typeless, so
showing no `$dispeltype$` word and keeping the surface's color is correct. Out of combat none of the
values was secret.
