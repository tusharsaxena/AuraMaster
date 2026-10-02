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
--   "same"   — the R-3 single group (no category Hidden): the ids view minus its whitelist exclude.
--   "strip"  — a `token` / `flag` / `dispel` Show group. Its ids view is the base, its positive
--              constraint, minus every earlier shown category and the whitelist; dropping the two
--              spell-id fields and putting back the BASE's own excludes leaves exactly the base, the
--              constraint and the earlier Blizzard exclusions, since an earlier spell category and
--              the whitelist exclude by id alone. No dedup is lost: every earlier spell-list group
--              is NEVER in this view.
--
-- THE BASE'S OWN EXCLUDES STAY (SV-05). Blizzard still applies `excludeSpellIDs` to a spell whose
-- `C_Secrets.GetSpellAuraSecrecy` is NeverSecret, on every unit (`CanApplyIdentityCandidateFilters`
-- answers true for it first; its comment names Sated and Exhaustion). So the "same" and "strip" views
-- carry exactly the base's `excludeSpellIDs` (the Overrides blacklist and Timeless's learned ids,
-- `baseIds`): a blacklisted NeverSecret aura stays hidden there, as it was before the views. The
-- whitelist's and the earlier spell categories' excludes go: the groups they dedup against are NEVER
-- here, and a whitelist exclude would hide a whitelisted NeverSecret aura outright, its own group
-- matching nothing. An exclude only narrows a group, so keeping one can never draw an aura twice.
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

--- The role a SHOWN category's group plays in the no-ids view, from its kind.
--- @param kind string  the category def's kind
--- @return string  "never" | "strip"
function FV.ShownRole(kind)
    if kind == "spells" or kind == "uncategorized" then return "never" end
    return "strip"
end

--- The no-ids view of one compiled group. "same" and "strip" build the same table: the R-3 group
--- has no include and no earlier category, so stripping it removes only its whitelist exclude.
--- @param group table  the ids-view group (`filter`, `candidateFilters`)
--- @param role string  "never" | "same" | "strip"
--- @param baseIds table|nil  the base's own `excludeSpellIDs` (blacklist, Timeless's learned ids)
--- @return table  { filter = string, candidateFilters = table|nil }
function FV.NoIds(group, role, baseIds)
    if role == "never" then
        return { filter = group.filter, candidateFilters = neverFilters() }
    end
    return { filter = group.filter, candidateFilters = stripIds(group.candidateFilters, baseIds) }
end
