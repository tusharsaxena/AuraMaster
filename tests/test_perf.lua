-- tests/test_perf.lua — the addon's wiring into LibKa0s-Perf-1.0 (core/PerfSetup.lua): every
-- declared bucket is reached by a real bracket, a dormant probe records nothing, suspend makes the
-- addon inert without a /reload, and the degradation stub answers the verb.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")
local loadDegraded = dofile("tests/degraded_env.lua")

--- Drive every path the addon brackets.
local function exercise(NS, mocks)
    NS.addon:OnUnitSwap("PLAYER_TARGET_CHANGED")
    NS.ContainerManager.RequestApply()
    mocks.__fireTimers()
    NS.ContainerManager.ApplyVisibility()
    NS.SetByPath("locked", false)   -- preview: dresses placeholder elements through Style.Element
    mocks.__fireTimers()
end

local function spyNotes(NS)
    local seen = {}
    local P = NS.Perf
    local original = P.Note
    P.Note = function(key, ms, parent)
        seen[key] = (seen[key] or 0) + 1
        return original(key, ms, parent)
    end
    return seen, function() P.Note = original end
end

test("perf: every declared bucket is reached by a real bracket", function()
    local NS, mocks = fresh()
    local seen, restore = spyNotes(NS)
    NS.Perf.on = true
    exercise(NS, mocks)
    NS.Perf.on = false
    restore()
    for _, key in ipairs(NS.Perf.BUCKET_ORDER) do
        assertTrue((seen[key] or 0) > 0, "bucket '" .. key .. "' was never noted")
    end
    assertTrue(#NS.Perf.BUCKET_ORDER == 5, "the five declared buckets")
end)

test("perf: a dormant probe notes nothing", function()
    -- red under: a bracket written without the `Perf.on and` gate.
    local NS, mocks = fresh()
    local seen, restore = spyNotes(NS)
    exercise(NS, mocks)
    restore()
    assertEqual(next(seen), nil)
end)

test("perf: suspend makes the addon inert without a reload, and resume restores it", function()
    local NS, mocks = fresh()
    NS.SetByPath("container.filter.durationMode", "timeless", 1)   -- TimedSpells now listens
    NS.Perf.Suspend()
    assertTrue(NS.Perf.suspended)
    assertTrue(NS.TimedSpells.__frame().__unitEvents.UNIT_AURA == nil, "the timed-spell scan stopped too")
    assertEqual(next(NS.addon.__events), nil, "every lifecycle event unregistered")
    for _, e in ipairs(mocks.__engines) do assertFalse(e.__enabled, "an engine is still enabled") end
    NS.ContainerManager.ApplyVisibility()
    for _, e in ipairs(mocks.__engines) do assertFalse(e.__enabled, "visibility re-enabled an engine") end
    NS.Perf.Resume()
    assertFalse(NS.Perf.suspended)
    assertTrue(NS.TimedSpells.__frame().__unitEvents.UNIT_AURA ~= nil, "and resumed")
    assertTrue(NS.addon.__events.PLAYER_TARGET_CHANGED ~= nil)
    assertTrue(mocks.__engines[1].__enabled)
end)

test("perf: without the library, /am perf answers one honest line", function()
    local NS2 = loadDegraded()
    local lines = NS2.Perf.OnCommand("")
    assertEqual(#lines, 1)
    assertTrue(lines[1]:find("LibKa0s", 1, true) ~= nil)
    assertFalse(NS2.Perf.on)
end)
