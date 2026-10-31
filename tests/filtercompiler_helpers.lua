-- tests/filtercompiler_helpers.lua — the plan readers both FilterCompiler suites share.
--
-- Not a suite (tests/run.lua does not list it) and not part of the vendored kit. Loaded with dofile
-- by tests/test_filtercompiler.lua, tests/test_filtercompiler_uncategorized.lua,
-- tests/test_filtercompiler_categories.lua, tests/test_filterviews.lua and
-- tests/test_filterviews_situations.lua, so the suites read a compiled plan the same way instead
-- of each keeping a copy.
local H = {}

--- A spell-id set rendered as its sorted keys joined by commas: a case asserts the WHOLE set, not a
--- count.
function H.setOf(t)
    local keys = {}
    for k in pairs(t or {}) do
        keys[#keys + 1] = tostring(k)
    end
    table.sort(keys)
    return table.concat(keys, ",")
end

--- True when any of the plan's warnings contains `fragment` (a plain find).
function H.hasWarning(plan, fragment)
    for _, w in ipairs(plan.warnings) do
        if w:find(fragment, 1, true) then return true end
    end
    return false
end

--- The plan's groups without its trailing remainder slot (filter situations, S1: modules/
--- FilterViews.lua), which is NEVER in the ids view: what a case about the category groups counts.
function H.categoryGroups(plan)
    local out = {}
    for _, g in ipairs(plan.groups) do
        if not g.remainder then out[#out + 1] = g end
    end
    return out
end

--- A `ctx.categories` stub over the REAL category defs (defaults/Categories.lua), narrowed to just
--- `keys`, declaration order preserved. Since the filter-priority revision (docs/superpowers/specs/
--- 2026-09-14-feedback-batch6-design.md section 6) makes every OTHER category of the same aura type
--- a Show group the moment one Hide exists (R-4), a case built on the full shipped list explodes to
--- one group per shipped category; this keeps a case testing one or two categories' interaction to
--- exactly that many groups, without inventing category data of its own.
function H.only(NS, auraType, keys)
    local want = {}
    for _, k in ipairs(keys) do want[k] = true end
    local out = {}
    for _, def in ipairs(NS.Categories.For(auraType)) do
        if want[def.key] then
            local n = #out
            out[n + 1] = def
        end
    end
    return { For = function() return out end }
end

--- `only`, with one extra category def spliced in immediately BEFORE the aura type's `uncategorized`
--- row — U-1 keeps that row last and `addShownGroups` leans on it, so an injected def that landed
--- after it would be testing a shape the addon never ships. The debuff cases use it to narrow
--- `Cat.HARMFUL` to one Blizzard token, the real `hardCC` and `uncategorizedDebuffs`, which is the
--- smallest list that gives a debuff container a NON-EMPTY categorized union. The gate itself is
--- `FC.IdsMode` (`addCategoryGroups`, modules/FilterCompiler.lua), NOT the `FC.IdsHonored`
--- the warning reads, and it answers false for every debuff container whatever the union holds — so
--- a non-empty debuff union is not what makes the gate decide, it is what makes the decision
--- OBSERVABLE: with an empty union `hasUnion` would be false anyway and a case could not tell which
--- half shut the row down. It goes in through the same `ctx.categories` seam every other case uses
--- rather than patching `NS.Categories`: the shipped table stays untouched, so no case can leak into
--- the next one, and the fixture keeps asserting the compiler rather than a monkey-patch.
function H.onlyPlus(NS, auraType, keys, extra)
    local out = {}
    for _, def in ipairs(H.only(NS, auraType, keys).For()) do
        if extra and def.kind == "uncategorized" then
            out[#out + 1] = extra
            extra = nil
        end
        out[#out + 1] = def
    end
    if extra then
        local n = #out
        out[n + 1] = extra
    end
    return { For = function() return out end }
end

return H
