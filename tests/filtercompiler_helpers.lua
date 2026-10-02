-- tests/filtercompiler_helpers.lua — the plan readers both FilterCompiler suites share.
--
-- Not a suite (tests/run.lua does not list it) and not part of the vendored kit. Loaded with dofile
-- by tests/test_filtercompiler.lua, tests/test_filtercompiler_categories.lua, tests/test_filterviews.lua
-- and tests/test_filterviews_situations.lua, so the suites read a compiled plan the same way instead
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

return H
