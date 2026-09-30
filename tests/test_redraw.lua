-- tests/test_redraw.lua - `/am redraw [light|full]` (SP-AMX-02): the verb in settings/Slash.lua,
-- CM.RedrawLight / CM.RedrawFull in modules/ContainerManager.lua and ContainerClass:Flip in
-- modules/Container.lua.
--
-- light turns every live engine off and on again now (the SP-AMX-01 flip), in any state. full primes
-- the fonts, does the light flip now, and asks for one system apply of every container, which
-- re-dresses every button in place; while an apply has to wait (combat, aura secrecy) that part
-- queues and the usual deferral notice says so. A bare `/am redraw` runs full when nothing holds an
-- apply, else light, and says which ran. Neither form retires or builds an engine. The mock cannot
-- show a repaint; these cases pin which engines are flipped, what is queued, and what is printed.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")

local COMBAT_LINE = "Aura Master settings changes will apply when combat ends."
local SECRET_LINE = "Aura Master settings changes will apply once aura information is available again (after the encounter, key or match)."
local REFUSAL = "Ka0s Aura Master is disabled — enable it with /am enable"
local HINT = "A full redraw has to wait right now, so a light one ran; /am redraw full queues the rest"
local STOOD_DOWN = "Full redraw skipped: Aura Master is stood down while a perf capture runs"

--- A fresh environment with its startup build flushed, and a chat capture.
local function env()
    local NS, mocks = fresh()
    mocks.__fireTimers(); mocks.__fireTimers()
    local lines = {}
    rawset(mocks.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
        lines[#lines + 1] = tostring(msg)
    end)
    return NS, mocks, NS.ContainerManager, lines
end

--- A chat line with its color codes and the [AM] tag taken off.
local function strip(s)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return (s:gsub("^%[AM%] ", ""))
end

--- Run one `/am` line and answer what it printed, plain.
local function slash(NS, lines, msg)
    for k in pairs(lines) do lines[k] = nil end
    NS.Slash:OnSlash(msg)
    local out = {}
    for i, l in ipairs(lines) do out[i] = strip(l) end
    return out
end

local function dump(p) return "{" .. table.concat(p, " | ") .. "}" end

--- The instances, sorted by id, each with its engine and the engine's call count now.
local function marks(CM)
    local out = {}
    for id, inst in pairs(CM.instances) do
        local n = #out
        local from = #inst.engine.__calls
        out[n + 1] = { id = id, inst = inst, engine = inst.engine, from = from }
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

--- The SetEnabled values `m`'s engine has been sent since its mark.
local function flips(m)
    local out = {}
    local last = #m.engine.__calls
    for i = m.from + 1, last do
        local c = m.engine.__calls[i]
        if c[1] == "SetEnabled" then
            local n = #out
            out[n + 1] = tostring(c[2])
        end
    end
    return table.concat(out, ",")
end

--- Count the calls to `obj[name]`, still calling through. Returns a one-slot box and the args seen.
local function spy(obj, name)
    local box, args, orig = { 0 }, {}, obj[name]
    obj[name] = function(...)
        box[1] = box[1] + 1
        args[#args + 1] = { ... }
        return orig(...)
    end
    return box, args
end

--- Count every Restyle each instance makes from now on (Update's in-place re-dress).
local function restyles(CM)
    local box = { 0 }
    for _, inst in pairs(CM.instances) do
        local orig = inst.Restyle
        inst.Restyle = function(...)
            box[1] = box[1] + 1
            return orig(...)
        end
    end
    return box
end

--- How many printed lines equal `text`.
local function count(p, text)
    local n = 0
    for _, l in ipairs(p) do if l == text then n = n + 1 end end
    return n
end

-- -- light ----------------------------------------------------------------------------------------

test("redraw: /am redraw light flips every live container, enchant slots or not, and says how many", function()
    local NS, _, CM, lines = env()
    local ms = marks(CM)
    assertTrue(#ms >= 2, "the starter containers")
    assertEqual(#CM.instances[2].enchantFrames, 0, "container 2 has no enchant slot")
    local p = slash(NS, lines, "redraw light")
    for _, m in ipairs(ms) do
        -- red under: light reusing ResetEnchants' enchant-slot gate (the aura bars never repaint)
        assertEqual(flips(m), "false,true", "container " .. m.id)
        assertTrue(m.engine.__enabled, "container " .. m.id .. " left enabled")
    end
    local want = ("Light redraw: %d container(s) repainted"):format(#ms)
    assertEqual(dump(p), dump({ want }))
end)

test("redraw: light is the flip alone: no rebuild, no apply, no font priming", function()
    local NS, mocks, CM, lines = env()
    local ms = marks(CM)
    local requests = spy(CM, "RequestApply")
    local primes = spy(NS.FontPrimer, "PrimeAll")
    slash(NS, lines, "redraw light")
    mocks.__fireTimers()
    for _, m in ipairs(ms) do
        -- red under: a redraw that retires and builds (one leaked engine frame per container per run)
        assertTrue(m.inst.engine == m.engine, "container " .. m.id .. " keeps its engine")
        assertEqual(#m.inst.retired, 0, "nothing retired")
        assertEqual(#m.engine.__calls - m.from, 2, "exactly the two SetEnabled calls")
    end
    -- red under: light queuing full's re-apply or priming
    assertEqual(requests[1], 0, "no apply requested")
    assertEqual(primes[1], 0, "no priming")
end)

test("redraw: light leaves a hidden, parked, stale or previewing container off", function()
    local NS, _, CM, lines = env()
    NS.SetByPath("container.enabled", false, 2)
    CM.instances[3]:Park()
    CM.instances[4].staleData = true
    local ms = marks(CM)
    slash(NS, lines, "redraw light")
    assertEqual(flips(ms[1]), "false,true", "the live one")
    -- red under: Flip without ResetEnchants' gates (an engine that should be off comes back on)
    assertEqual(flips(ms[2]), "", "disabled")
    assertEqual(flips(ms[3]), "", "parked")
    assertEqual(flips(ms[4]), "", "stale")
    CM.instances[4].staleData = nil
    NS.Preview.SetTestMode(true)
    ms = marks(CM)
    local p = slash(NS, lines, "redraw light")
    assertEqual(flips(ms[1]), "", "previewing")
    assertFalse(ms[1].engine.__enabled, "test mode keeps the engine off")
    assertEqual(dump(p), "{Light redraw: 0 container(s) repainted}")
    NS.Preview.SetTestMode(false)
end)

test("redraw: light runs under combat lockdown and while auras are secret, with no deferral notice", function()
    local NS, mocks, CM, lines = env()
    mocks.__lockdown, mocks.__aurasSecret = true, true
    local ms = marks(CM)
    local p = slash(NS, lines, "redraw light")
    -- red under: a MustDefer gate on light
    for _, m in ipairs(ms) do assertEqual(flips(m), "false,true", "container " .. m.id) end
    assertEqual(count(p, COMBAT_LINE) + count(p, SECRET_LINE), 0, "nothing waits: " .. dump(p))
    assertEqual(#p, 1, dump(p))
end)

-- -- full -----------------------------------------------------------------------------------------

test("redraw: /am redraw full primes the fonts, flips now, then re-dresses every container in place", function()
    local NS, mocks, CM, lines = env()
    local ms = marks(CM)
    local order = {}
    local primeOrig = NS.FontPrimer.PrimeAll
    NS.FontPrimer.PrimeAll = function(...)
        order[#order + 1] = "prime@" .. (#ms[1].engine.__calls - ms[1].from)
        return primeOrig(...)
    end
    local requests, args = spy(CM, "RequestApply")
    local dressed = restyles(CM)
    local p = slash(NS, lines, "redraw full")
    -- red under: the flip after the priming skipped, or run before it
    assertEqual(table.concat(order, ","), "prime@0", "primed before the flip")
    for _, m in ipairs(ms) do assertEqual(flips(m), "false,true", "container " .. m.id) end
    -- red under: a user request (its deferral would print twice) or a per-container one
    assertEqual(requests[1], 1, "one apply request")
    assertEqual(args[1][1], nil, "for every container")
    assertEqual(args[1][2], true, "the addon's own request")
    assertEqual(dressed[1], 0, "the re-dress is coalesced to the next frame")
    mocks.__fireTimers()
    -- red under: no re-apply (fonts, textures and labels never re-dressed)
    assertEqual(dressed[1], #ms, "every container re-dressed")
    for _, m in ipairs(ms) do
        -- red under: a full redraw that retires and builds
        assertTrue(m.inst.engine == m.engine, "container " .. m.id .. " keeps its engine")
        assertEqual(#m.inst.retired, 0, "nothing retired")
    end
    local want = ("Full redraw: fonts primed, %d container(s) repainted, every container re-dressed"):format(#ms)
    assertEqual(dump(p), dump({ want }))
    NS.FontPrimer.PrimeAll = primeOrig
end)

test("redraw: full in combat flips now and queues the re-dress with the combat notice", function()
    local NS, mocks, CM, lines = env()
    mocks.__lockdown = true
    local ms = marks(CM)
    local dressed = restyles(CM)
    local p = slash(NS, lines, "redraw full")
    for _, m in ipairs(ms) do assertEqual(flips(m), "false,true", "container " .. m.id) end
    -- red under: the command silent about the wait, or a notice of its own wording
    assertEqual(p[1], ("Full redraw: fonts primed, %d container(s) repainted; the re-dress waits until it is allowed"):format(#ms))
    assertEqual(count(p, COMBAT_LINE), 1, dump(p))
    assertEqual(#p, 2, dump(p))
    mocks.__fireTimers()
    -- red under: an apply under lockdown
    assertEqual(dressed[1], 0, "held while combat lasts")
    assertTrue(CM.QueueSnapshot().all, "queued for every container")
    mocks.__lockdown = false
    CM.FlushPending("regen")
    -- red under: a redraw kept outside the apply queue (nothing runs when combat ends)
    assertEqual(dressed[1], #ms, "re-dressed when combat ends")
    for _, m in ipairs(ms) do assertTrue(m.inst.engine == m.engine, "container " .. m.id .. " keeps its engine") end
end)

test("redraw: full while auras are secret names the restriction instead", function()
    local NS, mocks, CM, lines = env()
    mocks.__aurasSecret = true
    local dressed = restyles(CM)
    local p = slash(NS, lines, "redraw full")
    assertEqual(count(p, SECRET_LINE), 1, dump(p))
    assertEqual(count(p, COMBAT_LINE), 0, dump(p))
    mocks.__fireTimers()
    assertEqual(dressed[1], 0, "held while auras are secret")
    mocks.__aurasSecret = false
    CM.FlushPending()
    assertTrue(dressed[1] > 0, "re-dressed once the restriction lifts")
end)

test("redraw: the deferral notice keeps its once-per-stretch rule", function()
    local NS, mocks, _, lines = env()
    mocks.__lockdown = true
    local first = slash(NS, lines, "redraw full")
    assertEqual(count(first, COMBAT_LINE), 1, dump(first))
    local second = slash(NS, lines, "redraw full")
    -- red under: a private notice printed on every run (the usual one says it once per fight)
    assertEqual(count(second, COMBAT_LINE), 0, dump(second))
    assertEqual(#second, 1, "the command's own line still says the re-dress waits: " .. dump(second))
    assertTrue(second[1]:find("waits until it is allowed", 1, true) ~= nil, second[1])
end)

-- -- bare -----------------------------------------------------------------------------------------

test("redraw: a bare /am redraw runs full when nothing holds an apply, and says so", function()
    local NS, mocks, CM, lines = env()
    local primes = spy(NS.FontPrimer, "PrimeAll")
    local requests = spy(CM, "RequestApply")
    local p = slash(NS, lines, "redraw")
    -- red under: bare defaulting to light
    assertEqual(primes[1], 1, "primed")
    assertEqual(requests[1], 1, "re-apply requested")
    assertEqual(#p, 1, dump(p))
    assertTrue(p[1]:find("^Full redraw: ") ~= nil, p[1])
    mocks.__fireTimers()
end)

test("redraw: a bare /am redraw in combat or while secret runs light, says so, and queues nothing", function()
    for _, flag in ipairs({ "__lockdown", "__aurasSecret" }) do
        local NS, mocks, CM, lines = env()
        mocks[flag] = true
        local ms = marks(CM)
        local primes = spy(NS.FontPrimer, "PrimeAll")
        local requests = spy(CM, "RequestApply")
        local p = slash(NS, lines, "redraw")
        for _, m in ipairs(ms) do assertEqual(flips(m), "false,true", flag .. " container " .. m.id) end
        -- red under: bare running full while held (a queued re-dress the player did not ask for)
        assertEqual(requests[1], 0, flag .. ": no apply requested")
        assertEqual(primes[1], 0, flag .. ": no priming")
        local want = ("Light redraw: %d container(s) repainted"):format(#ms)
        assertEqual(dump(p), dump({ want, HINT }), flag)
    end
end)

-- -- words, the disabled gate, the trace --------------------------------------------------------

test("redraw: the word is read in any case, and any other word prints the usage and flips nothing", function()
    local NS, _, CM, lines = env()
    local p = slash(NS, lines, "redraw LIGHT")
    assertTrue(p[1]:find("^Light redraw: ") ~= nil, dump(p))
    local ms = marks(CM)
    p = slash(NS, lines, "redraw everything")
    -- red under: an unknown word falling through to a redraw
    assertEqual(dump(p), "{Usage: /am redraw [light|full]}")
    for _, m in ipairs(ms) do assertEqual(flips(m), "", "container " .. m.id) end
end)

test("redraw: while disabled every form refuses on one line and flips, primes and queues nothing", function()
    local NS, mocks, CM, lines = env()
    NS.SetByPath("enabled", false)
    local ms = marks(CM)
    local primes = spy(NS.FontPrimer, "PrimeAll")
    local requests = spy(CM, "RequestApply")
    for _, line in ipairs({ "redraw", "redraw light", "redraw full" }) do
        local p = slash(NS, lines, line)
        -- red under: redraw named in liveVerbs (a disabled addon's engines turned back on)
        assertEqual(dump(p), dump({ REFUSAL }), "/am " .. line)
    end
    for _, m in ipairs(ms) do assertEqual(flips(m), "", "container " .. m.id) end
    assertEqual(primes[1] + requests[1], 0, "nothing primed or requested")
    assertEqual(#mocks.__timers(), 0, "nothing armed")
end)

test("redraw: while a perf capture stands the addon down, full and bare say they were skipped, light repaints none", function()
    local NS, _, CM, lines = env()
    NS.lifecycle:Hold(NS.HOLD_PERF)
    local ms = marks(CM)
    local primes = spy(NS.FontPrimer, "PrimeAll")
    local requests = spy(CM, "RequestApply")
    for _, line in ipairs({ "redraw full", "redraw" }) do
        local p = slash(NS, lines, line)
        -- red under: a full redraw reporting fonts primed and every container re-dressed when none was
        assertEqual(dump(p), dump({ STOOD_DOWN }), "/am " .. line)
    end
    local p = slash(NS, lines, "redraw light")
    assertEqual(dump(p), "{Light redraw: 0 container(s) repainted}")
    for _, m in ipairs(ms) do assertEqual(flips(m), "", "container " .. m.id) end
    assertEqual(primes[1] + requests[1], 0, "nothing primed or requested")
    NS.lifecycle:Release(NS.HOLD_PERF)
end)

test("redraw: each run writes one [Apply] line naming the form and the count", function()
    local NS, mocks, CM, lines = env()
    local trace = {}
    NS.Debug = function(tag, fmt, ...)
        if tag ~= "Apply" then return end
        local args = { ... }
        for i = 1, select("#", ...) do args[i] = tostring(args[i]) end
        trace[#trace + 1] = fmt:format(unpack(args, 1, select("#", ...)))
    end
    local n = #marks(CM)
    slash(NS, lines, "redraw light")
    slash(NS, lines, "redraw full")
    mocks.__lockdown = true
    slash(NS, lines, "redraw full")
    -- red under: a silent redraw (the owner cannot tell from the console what ran)
    assertEqual(trace[1], ("redraw light: %d container(s) flipped"):format(n))
    assertEqual(trace[2], ("redraw full: %d container(s) flipped, re-apply queued"):format(n))
    assertEqual(trace[3], ("redraw full: %d container(s) flipped, re-apply deferred"):format(n))
end)
