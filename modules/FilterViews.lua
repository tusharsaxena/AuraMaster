local _, NS = ...

-- modules/FilterViews.lua — the views of each compiled aura group where Blizzard will not apply spell
-- ids: "blizzard" (spell-list views, V1: docs/superpowers/specs/2026-10-02-spell-list-views-design.md,
-- where it was the no-ids view) and "every" (filter situations, S1: docs/superpowers/specs/
-- 2026-10-02-filter-situations-design.md). The third view, "ids", is the group's own fields.
--
-- WHY MORE THAN ONE VIEW. Blizzard applies a group's `includeSpellIDs` / `excludeSpellIDs` only where
-- `AuraContainerUtil.CanApplyIdentityCandidateFilters` passes: buffs on a unit you can assist (or a
-- player-controlled / group unit), debuffs on a unit you cannot. Everywhere else it skips both and
-- still evaluates the rest of the group. A container with a category set to Hide compiles to one
-- group per shown category (R-4, modules/FilterCompiler.lua), and the spell-list groups among them
-- differ ONLY in their ids: with the ids skipped they all become the same group, and one aura is drawn
-- once per group (the 14 Brutal Slams bars on a hostile NPC). Where Blizzard will not apply spell ids,
-- spell categories and the Overrides lists are not applied at all (the owner, 2026-10-02), and the
-- container's Situations setting picks what draws instead: only the Blizzard categories set to Show
-- (the blizzard view), or every aura once (the every view).
--
-- `FC.Compile` keeps building the ids view unchanged and stamps each group with `views = { blizzard =
-- { filter, candidateFilters }, every = { ... } }` from `FV.Views`, by the group's ROLE:
--
--   "never"  — the whitelist, a `spells` or `uncategorized` Show group, and the R-5 catch-all. The
--              same filter string, with `candidateFilters = { includeDispelTypes = {} }`: an empty
--              include map fails every aura, typed or not (`DoesAuraPassCandidateFilters`), and
--              Blizzard validates only that it is a table. Keeping the string keeps the group's
--              aura type, so nothing about the group but its match changes.
--   "same"   — the R-3 single group (no category Hidden): the ids view minus its whitelist exclude.
--   "strip"  — a `token` / `flag` / `dispel` Show group. Its ids view is the base, its positive
--              constraint, minus every earlier shown category and the whitelist; dropping the two
--              spell-id fields and putting back the BASE's own excludes leaves exactly the base, the
--              constraint and the earlier Blizzard exclusions, since an earlier spell category and
--              the whitelist exclude by id alone. No dedup is lost: every earlier spell-list group
--              is NEVER in this view.
--
-- The every view of a role is its blizzard view. `FV.AppendRemainder` then changes that for an R-4
-- plan on a unit whose ids are not always applied (`FC.IdsMode` not "always"): it appends ONE trailing
-- REMAINDER group, the base minus every Hidden category on the Blizzard Categories, Dispel Types and
-- Who Cast It grids (`FV.BLIZZARD_GRID`), and makes every other group NEVER in the every view. So the
-- every view is one live group: every aura passing the base and in no Hidden Blizzard-grid category,
-- drawn once. The remainder is NEVER in the ids and blizzard views, so both draw exactly what they drew
-- before it existed; its filter string is the same in all three, so a switch sends candidates only.
-- It is NEVER in the every view too where it cannot mean what it says: both Who Cast It rows Hidden
-- (a real contradiction), or "Without a duration" on buffs (built from spell ids Blizzard drops).
-- There the other groups keep their blizzard view in the every view (SI-06), so the every view is
-- the blizzard view and never draws less than it.
-- An R-3 plan needs no remainder (its one group already draws every aura there), and buffs on the
-- player and the pet always take the ids view, so neither gains one.
--
-- THE BASE'S OWN EXCLUDES STAY (SV-05). Blizzard still applies `excludeSpellIDs` to a spell whose
-- `C_Secrets.GetSpellAuraSecrecy` is NeverSecret, on every unit (`CanApplyIdentityCandidateFilters`
-- answers true for it first; its comment names Sated and Exhaustion). So the "same" and "strip" views
-- and the remainder carry exactly the base's `excludeSpellIDs` (the Overrides blacklist and Timeless's
-- learned ids, `baseIds`): a blacklisted NeverSecret aura stays hidden there, as it was before the
-- views. The whitelist's and the earlier spell categories' excludes go: the groups they dedup against
-- are NEVER here, and a whitelist exclude would hide a whitelisted NeverSecret aura outright, its own
-- group matching nothing. An exclude only narrows a group, so keeping one can never draw an aura twice.
--
-- Every view of a plan has the same group count, so switching views never rebuilds the engine
-- container. PURE, like the compiler: tables in, tables out.

NS.FilterViews = NS.FilterViews or {}
local FV = NS.FilterViews

--- The candidate filters of a group that matches nothing. A fresh table per call, so no two groups
--- share one the engine might hold on to.
--- @return table
local function neverFilters()
    return { includeDispelTypes = {} }
end

local ID_FIELDS = { includeSpellIDs = true, excludeSpellIDs = true }

--- `cand` without its spell-id fields, plus a copy of `baseIds` as its `excludeSpellIDs` when that is
--- not empty; nil when nothing is left.
--- @return table|nil
local function stripIds(cand, baseIds)
    local out
    for k, v in pairs(cand or {}) do
        if not ID_FIELDS[k] then
            out = out or {}
            out[k] = v
        end
    end
    if baseIds and next(baseIds) then
        local ids = {}
        for id in pairs(baseIds) do ids[id] = true end
        out = out or {}
        out.excludeSpellIDs = ids
    end
    return out
end

--- The kinds drawn in the Blizzard Categories, Dispel Types and Who Cast It grids: what Blizzard
--- evaluates without spell ids, so the only Hides the every view's remainder can honor.
FV.BLIZZARD_GRID = { token = true, flag = true, dispel = true }

--- The role a SHOWN category's group plays in the blizzard view, from its kind.
--- @param kind string  the category def's kind
--- @return string  "never" | "strip"
function FV.ShownRole(kind)
    if kind == "spells" or kind == "uncategorized" then return "never" end
    return "strip"
end

--- A view of `group` that matches nothing: its own filter string, a fresh NEVER table.
local function never(group)
    return { filter = group.filter, candidateFilters = neverFilters() }
end

--- `group`'s spell-id fields stripped, the base's own excludes put back. "same" and "strip" build
--- the same table: the R-3 group has no include and no earlier category, so stripping it removes
--- only its whitelist exclude.
local function stripped(group, baseIds)
    return { filter = group.filter, candidateFilters = stripIds(group.candidateFilters, baseIds) }
end

--- The blizzard and every views of one compiled group, a table each (none shared, so the engine never
--- holds one table for two groups or two views).
--- @param group table  the ids-view group (`filter`, `candidateFilters`)
--- @param role string  "never" | "same" | "strip"
--- @param baseIds table|nil  the base's own `excludeSpellIDs` (blacklist, Timeless's learned ids)
--- @return table  { blizzard = view, every = view }, each `{ filter = string, candidateFilters = table|nil }`
function FV.Views(group, role, baseIds)
    if role == "never" then
        return { blizzard = never(group), every = never(group) }
    end
    return { blizzard = stripped(group, baseIds), every = stripped(group, baseIds) }
end

--- Append the remainder group to `plan` and, when it draws, make every earlier group NEVER in the
--- every view. `group` arrives built from the remainder's constraints (the base minus each Hidden
--- Blizzard-grid category); its ids and blizzard views become NEVER, and its every view is those
--- constraints with the spell ids stripped, or NEVER when `draws` is false. A remainder that cannot
--- draw leaves each earlier group's every view as its blizzard view (SI-06): blanking them too would
--- leave the every view drawing nothing, less than the blizzard view.
--- @param plan table  the plan being compiled
--- @param group table  the remainder, as `FC.Compile` builds any group
--- @param draws boolean  whether the remainder draws in the every view
--- @param baseIds table|nil  the base's own `excludeSpellIDs`
function FV.AppendRemainder(plan, group, draws, baseIds)
    if draws then
        for _, g in ipairs(plan.groups) do
            g.views.every = never(g)
        end
    end
    local every = draws and stripped(group, baseIds) or never(group)
    group.remainder = true
    group.candidateFilters = neverFilters()
    group.views = { blizzard = never(group), every = every }
    plan.groups[#plan.groups + 1] = group
end
