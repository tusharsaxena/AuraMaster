-- tests/test_perf.lua — the addon's wiring into LibKa0s-Perf-1.0 (core/PerfSetup.lua): every
-- declared bucket is reached by a real bracket, a dormant probe records nothing, suspend makes the
-- addon inert without a /reload, and the degradation stub answers the verb.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")
local loadDegraded = dofile("tests/degraded_env.lua")

--- Drive every path the addon brackets.
local function exercise(NS, mocks)
    NS.SetByPath("container.filter.durationMode", "timeless", 1)   -- TimedSpells arms its scan
    mocks.__fireTimers()                                          -- ...and scanTick runs it
    NS.addon:OnUnitSwap("PLAYER_TARGET_CHANGED")
    NS.ContainerManager.RequestApply()
    mocks.__fireTimers()
    NS.ContainerManager.ApplyVisibility()
    NS.Preview.SetTestMode(true)    -- preview: dresses placeholder elements through Style.Element
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
    assertTrue(#NS.Perf.BUCKET_ORDER == 6, "the six declared buckets")
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
    assertTrue(NS.TimedSpells.__events().__events.UNIT_AURA == nil, "the timed-spell scan stopped too")
    assertEqual(next(NS.addon.__events), nil, "every lifecycle event unregistered")
    for _, e in ipairs(mocks.__engines) do assertFalse(e.__enabled, "an engine is still enabled") end
    NS.ContainerManager.ApplyVisibility()
    for _, e in ipairs(mocks.__engines) do assertFalse(e.__enabled, "visibility re-enabled an engine") end
    NS.Perf.Resume()
    assertFalse(NS.Perf.suspended)
    assertTrue(NS.TimedSpells.__events().__events.UNIT_AURA ~= nil, "and resumed")
    assertTrue(NS.addon.__events.PLAYER_TARGET_CHANGED ~= nil)
    assertTrue(mocks.__engines[1].__enabled)
end)

test("perf: suspend holds a queued apply until resume", function()
    -- red under: FlushPending without its suspended gate.
    local NS, mocks = fresh()
    NS.Perf.Suspend()
    for _, e in ipairs(mocks.__engines) do e.__calls = {} end
    NS.SetByPath("container.bars.width", 250, 1)
    mocks.__fireTimers()
    local calls = 0
    for _, e in ipairs(mocks.__engines) do
        calls = calls + #e.__calls
    end
    assertEqual(calls, 0, "a suspended addon sent an engine call")
    assertEqual(NS.ContainerManager.FlushPending(), 0)
    NS.Perf.Resume()
    mocks.__fireTimers()
    assertTrue(#mocks.__engines[1]:__callsTo("SetAuraGroupLayout") > 0, "resume drained the queued apply")
end)

test("perf: the buckets are declared in report order, and only the per-container apply nests", function()
    local NS = fresh()
    -- red under: a bucket reordered, renamed or dropped from core/PerfSetup.lua
    assertEqual(table.concat(NS.Perf.BUCKET_ORDER, ","),
        "unitSwap,applyPass,applyContainer,visibilityPass,styleElement,timedScan")
    local nested = {}
    for key, parent in pairs(NS.Perf.BUCKET_WITHIN) do
        nested[#nested + 1] = key .. "<" .. parent
    end
    -- red under: applyContainer losing `within = "applyPass"`
    assertEqual(table.concat(nested, ","), "applyContainer<applyPass")
end)

test("perf: suspend and resume log to the console whatever the debug flag says", function()
    local NS = fresh()
    assertFalse(NS.State.debug)
    NS.Perf.Suspend()
    -- red under: the descriptor's `log` routed through the gated NS.Debug sink
    assertTrue(NS.DebugLog:FindLine("[Perf] addon SUSPENDED") ~= nil, tostring(NS.DebugLog:LastLine()))
    NS.Perf.Resume()
    assertTrue(NS.DebugLog:FindLine("[Perf] addon RESUMED") ~= nil, tostring(NS.DebugLog:LastLine()))
end)

test("perf: resume re-registers exactly the lifecycle events suspend took away", function()
    local NS = fresh()
    local function events()
        local out = {}
        for e in pairs(NS.addon.__events) do
            out[#out + 1] = e
        end
        table.sort(out)
        return table.concat(out, ",")
    end
    local before = events()
    assertTrue(before ~= "", "the addon listens to something")
    NS.Perf.Suspend()
    assertEqual(events(), "")
    NS.Perf.Resume()
    -- red under: resume re-registering from a hand-kept list rather than RegisterLifecycleEvents
    assertEqual(events(), before)
end)

test("perf: without the library, /am perf answers one honest line", function()
    local NS2 = loadDegraded()
    local lines = NS2.Perf.OnCommand("")
    assertEqual(#lines, 1)
    assertTrue(lines[1]:find("LibKa0s", 1, true) ~= nil)
    assertFalse(NS2.Perf.on)
end)
