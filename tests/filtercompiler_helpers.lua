-- tests/filtercompiler_helpers.lua — the plan readers both FilterCompiler suites share.
--
-- Not a suite (tests/run.lua does not list it) and not part of the vendored kit. Loaded with dofile
-- by tests/test_filtercompiler.lua and tests/test_filtercompiler_categories.lua, so the two suites
-- read a compiled plan the same way instead of each keeping a copy.
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

return H
