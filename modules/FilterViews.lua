local _, NS = ...

-- modules/FilterViews.lua — the NO-IDS view of each compiled aura group (spell-list views, V1:
-- docs/superpowers/specs/2026-10-02-spell-list-views-design.md).
--
-- WHY TWO VIEWS. Blizzard applies a group's `includeSpellIDs` / `excludeSpellIDs` only where
-- `AuraContainerUtil.CanApplyIdentityCandidateFilters` passes: buffs on a unit you can assist (or a
-- player-controlled / group unit), debuffs on a unit you cannot. Everywhere else it skips both and
-- still evaluates the rest of the group. A container with a category set to Hide compiles to one
-- group per shown category (R-4, modules/FilterCompiler.lua), and the spell-list groups among them
-- differ ONLY in their ids: with the ids skipped they all become the same group, and one aura is drawn
-- once per group (the 14 Brutal Slams bars on a hostile NPC). The owner's rule (2026-10-02): where
-- Blizzard will not apply spell ids, spell categories and the Overrides lists are not applied at
-- all, and only the Blizzard categories set to Show draw.
--
-- `FC.Compile` keeps building the ids view unchanged and stamps each group with `noIds = { filter,
-- candidateFilters }` from `FV.NoIds`, by the group's ROLE:
--
--   "never"  — the whitelist, a `spells` or `uncategorized` Show group, and the R-5 catch-all. The
--              same filter string, with `candidateFilters = { includeDispelTypes = {} }`: an empty
--              include map fails every aura, typed or not (`DoesAuraPassCandidateFilters`), and
--              Blizzard validates only that it is a table. Keeping the string keeps the group's
--              aura type, so nothing about the group but its match changes.
--   "same"   — the R-3 single group (no category Hidden). Its spell ids only exclude the whitelist
--              and the Overrides blacklist, so with them skipped it is what it always was there.
--   "strip"  — a `token` / `flag` / `dispel` Show group. Its ids view is the base, its positive
--              constraint, minus every earlier shown category and the whitelist; dropping the two
--              spell-id fields leaves exactly the base, the constraint and the earlier Blizzard
--              exclusions, since an earlier spell category and the whitelist exclude by id alone.
--              No dedup is lost: every earlier spell-list group is NEVER in this view.
--
-- Both views have the same group count, so `FC.StructureKey` is unchanged and switching views never
-- rebuilds the engine container. PURE, like the compiler: tables in, tables out.

NS.FilterViews = NS.FilterViews or {}
local FV = NS.FilterViews

--- The candidate filters of a group that matches nothing. A fresh table per call, so no two groups
--- share one the engine might hold on to.
--- @return table
local function neverFilters()
    return { includeDispelTypes = {} }
end

local ID_FIELDS = { includeSpellIDs = true, excludeSpellIDs = true }

--- `cand` without its spell-id fields, or nil when nothing else is left.
--- @return table|nil
local function stripIds(cand)
    if not cand then return nil end
    local out
    for k, v in pairs(cand) do
        if not ID_FIELDS[k] then
            out = out or {}
            out[k] = v
        end
    end
    return out
end

--- The role a SHOWN category's group plays in the no-ids view, from its kind.
--- @param kind string  the category def's kind
--- @return string  "never" | "strip"
function FV.ShownRole(kind)
    if kind == "spells" or kind == "uncategorized" then return "never" end
    return "strip"
end

--- The no-ids view of one compiled group.
--- @param group table  the ids-view group (`filter`, `candidateFilters`)
--- @param role string  "never" | "same" | "strip"
--- @return table  { filter = string, candidateFilters = table|nil }
function FV.NoIds(group, role)
    if role == "never" then
        return { filter = group.filter, candidateFilters = neverFilters() }
    elseif role == "strip" then
        return { filter = group.filter, candidateFilters = stripIds(group.candidateFilters) }
    end
    return { filter = group.filter, candidateFilters = group.candidateFilters }
end
