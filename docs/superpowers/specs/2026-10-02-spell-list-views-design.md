# Spell-list views: design (no duplicate bars where Blizzard drops spell ids)

- **Date:** 2026-10-02
- **Branch:** `feat/2026-10-02-spell-list-views`
- **Plan:** `docs/superpowers/plans/2026-10-02-spell-list-views.md`
- **Owner decisions (2026-10-02):** spell categories and the Overrides lists are not applied wherever
  Blizzard will not apply spell ids; there, only Blizzard categories set to Show draw. Both cases (buffs
  on units you cannot assist, debuffs on units you can, including your own and your pet's). The
  remainder (an aura no Blizzard Show category claims) never shows there. A container with no category
  set to Hide is unchanged. Make it explicit on the Filters tab and in the README (usage and FAQ).

## Problem

Reported in M+: a target buff container drew one NPC buff ("Brutal Slams") 14 times. Reproduced
headlessly: the owner's "Target Bar CD (All)" container (target, buffs, every Blizzard category Hide,
seven spell categories Show, Uncategorized Hide, max duration 30 s) compiles to seven engine groups
(R-4, `modules/FilterCompiler.lua`). They differ ONLY in `includeSpellIDs` (that category's list) and
`excludeSpellIDs` (the earlier groups' lists, the dedup).

Blizzard's engine applies those two filters only when `AuraContainerUtil.CanApplyIdentityCandidateFilters`
passes (Blizzard_AuraContainerUtil.lua, read 2026-10-02 from the wow-ui-source mirror):

| Aura | Spell-id filters applied when |
|---|---|
| Helpful | `UnitIsPlayerControlledOrGroupMember(unit)` (token-based: player, pet, vehicle, partyN, raidN and their pets; never `target`/`focus`), or `UnitCanAssist("player", unit, true, true)` |
| Harmful | NOT `UnitCanAssist("player", unit, true, true)` |
| Any | the spell's `C_Secrets.GetSpellAuraSecrecy` is `NeverSecret` (per aura) |

Otherwise both id filters are skipped and the rest of the group still evaluates. On a hostile NPC the
seven groups all become "every buff of 30 s or less": two Brutal Slams instances times seven groups is
the 14 bars. It is not a regression: the shape has existed since the batch-6 filter priority
(2026-09-15). The issue #11 ruling accepted ONE over-broad spell-list group; the duplication across
several was not considered. The same shape duplicates on player and pet debuff containers, where
Blizzard never applies debuff ids, and on target debuff containers while the target is friendly. A
non-empty whitelist group degenerates the same way.

Flags, dispel types, max duration and the filter-string tokens are always applied. Those are what the
Blizzard categories compile to (kinds `token`, `flag`, `dispel`).

## Goal

No aura is ever drawn twice. Where Blizzard applies spell ids, filtering is exactly as today. Where it
does not, the player sees only what the Blizzard categories they set to Show claim, and the settings say
so.

## Design

### V1. Two views per plan, one structure

`FC.Compile` keeps building today's plan unchanged: the **ids view**. Each group also gets a
**no-ids view**, `group.noIds = { filter, candidateFilters }`:

| Group | No-ids view |
|---|---|
| Whitelist ("Always shown") | NEVER |
| R-3 single group (no category Hidden) | identical to the ids view (spell ids only exclude the whitelist there, whose group is NEVER) |
| R-4 shown `spells` / `uncategorized` group | NEVER |
| R-4 shown `token` / `flag` / `dispel` group | base plus its positive constraint, minus every EARLIER shown `token`/`flag`/`dispel` category; no spell-id constraint |
| R-5 catch-all ("All") | NEVER (the remainder never shows) |

NEVER is the same filter string with `candidateFilters = { includeDispelTypes = {} }`. An empty include
map fails every aura, typed or not (`DoesAuraPassCandidateFilters`), and Blizzard validates only that it
is a table. Both views have the same group count, so `FC.StructureKey` is unchanged and a switch never
rebuilds the engine.

`FC.IdsMode(unit, auraType)` (pure) is `"always"` for buffs on `player`/`pet`, `"never"` for debuffs on
`player`/`pet`, and `"dynamic"` for everything else. It replaces `FC.IdsAlwaysHonored` as the gate, with
the same meaning for `"always"`.

### V2. Choosing the view at runtime

`NS.Compat.IdsApply(unit, auraType)` mirrors Blizzard's predicate, minus its per-aura never-secret
exemption:

- helpful: `UnitIsPlayerControlledOrGroupMember(unit) or UnitCanAssist("player", unit, true, true)`
- harmful: `not UnitCanAssist("player", unit, true, true)`

Neither API's return is documented as secret, but each call is pcall-guarded and checked with
`NS.Secrets.CanAccess`. An unknowable answer is `false`: the no-ids view can under-show but never
duplicate.

The container keeps `self.view` (`"ids"` or `"noIds"`). `ContainerClass:ApplyView()` resolves the mode
(`"always"` → ids, `"never"` → noIds, `"dynamic"` → `IdsApply`) and, when it differs from `self.view`,
sends each group's filter string and candidate filters for that view through `callEngine`
(`SetAuraGroupFilterString`, `SetAuraGroupCandidateFilters`), only where they differ. Blizzard's Lua has
no combat or secrecy check on either setter, and both end in `UpdateAllAuras`, the call `Refresh` already
makes in combat on every target swap. So the switch runs in combat and while auras are secret,
unlike an apply, which `ContainerManager` holds. `Build` and `Update` send the active view's values,
not always the ids view.

**When it runs:** at `Build`, at every `Update`, on `PLAYER_TARGET_CHANGED` / `PLAYER_FOCUS_CHANGED`
(`OnUnitSwap`, before `Refresh`), and on `UNIT_FACTION` and `UNIT_FLAGS` for `target` and `focus`
(reaction changes without a swap: duels, mind control, an NPC turning hostile). The unit events go
through `NS.SafeRegisterUnitEvent` on a frame of the container manager, the pattern
`modules/TimedSpells.lua` uses, because the vendored AceEvent has no `RegisterUnitEvent`.

A view change logs one gated line: `[Filter] <container>: spell lists off (unit cannot be assisted)` or
`... on ...`. `/am diagnostics` reports each container's mode and current view.

### V3. Everything that reads the plan follows the view

- `modules/EmptyWatch.lua` predicts from the ACTIVE view's groups and uses `NS.Compat.IdsApply` in place
  of its own `UnitIsFriend` reading, so the empty prediction agrees with the engine.
- `FC.ExplainSpell` and the Overrides notes describe the ids view. The Overrides tab gains a line
  saying the lists do nothing where spell lists are off.

### V4. Telling the player

- The plan warnings (orange, above every Filters tab) are reworded to the new rule:
  - `IDS_OWN_DEBUFFS`: "On your own and your pet's debuffs, spell categories and Overrides are not
    applied. Only Blizzard categories set to Show draw."
  - target/focus buffs: "On units you can't assist (hostile or neutral), spell categories and
    Overrides are not applied. Only Blizzard categories set to Show draw."
  - target/focus debuffs: "On units you can assist, spell categories and Overrides are not applied.
    Only Blizzard categories set to Show draw."
  These print only when the container has at least one category set to Hide or a non-empty Overrides
  list, the cases where the rule changes anything.
- Filters → Categories: a NOTE line under the "Spell Categories" heading, on every container whose
  mode is not `"always"`: "NOTE: on <units you can't assist | units you can assist | your own debuffs>,
  these spell categories are not applied." The same sentence shape heads Overrides.
- README: a Usage paragraph on where spell categories apply, and an FAQ entry ("Why does my target
  container show fewer buffs on enemies?").
- docs: `docs/midnight-quirks.md` (the spell-id section, with Blizzard's predicate), ARCHITECTURE, the
  FilterCompiler top-of-file comment (the ACCEPTED RESIDUAL section is superseded), smoke checks.

## Accepted costs

- On a hostile or neutral target, a container that hides any category shows only auras in its Blizzard
  Show categories. A container built on spell lists (like the owner's) shows nothing there. This is the
  owner's call.
- The Overrides whitelist does nothing on those units, so "Always shown" there means "always shown
  where spell lists apply". The Overrides note says so.
- `NeverSecret` spells (Sated, Exhaustion and the like) would have their ids applied by Blizzard even
  where the view is no-ids. The view does not model that, so such an aura, if its only claim is a spell
  category, is not drawn there. Harmless, and consistent with the rule.

## Testing

- FilterCompiler: the owner's container yields seven groups whose no-ids views are all NEVER; a
  Blizzard Show group's no-ids view carries its token/flag/dispel constraint and the earlier non-spells
  exclusions only; whitelist and catch-all are NEVER in no-ids; R-3 unchanged; `IdsMode` for every
  unit and aura type; the reworded warnings, and their silence on a container that filters nothing.
- Container: `ApplyView` sends only differing setters; no call when the view is unchanged; Build on a
  `"never"` container sends the no-ids values; a refused setter is caught and logged once.
- Compat: `IdsApply` mirrors the table above, and is `false` when an API raises or answers secret.
- EmptyWatch: prediction follows the active view.
- Settings: the NOTE lines render for non-`"always"` containers only.
- Smoke (owner): the M+ repro (one bar per aura); a hostile player in PvP; a friendly target; a duel
  flip mid-target; a player debuff container with several spell categories; the notes and the README.
