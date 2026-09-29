-- tests/test_enchantreset.lua - the weapon-enchant name reset (SP-AMX-01): ContainerClass:ResetEnchants
-- (modules/Container.lua) and its two triggers in modules/ContainerManager.lua and core/AuraMaster.lua.
--
-- The engine names an enchant frame from the equipped weapon's item name, drawn once when the enchant
-- is first shown; an unchanged enchant is only updated in place, so a name lost at login (the item's
-- data not loaded yet, or the font not loaded yet) stays blank until a /reload
-- (docs/midnight-quirks.md, "Weapon enchants"). The reset turns a live engine off and on again, which
-- clears its enchant frames and draws them afresh. The mock cannot show a name; these cases pin
-- which engines are flipped, how, when, and that a stand-down leaves nothing armed. The name itself
-- is the owner's smoke check.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")

-- The delays, spelled out rather than read back off the module: the loading screen's end arms the
-- reset a quarter second after the font primer's world refresh (1.5 s), and a weapon's item data
-- half a second after it arrives.
local WORLD_DELAY, ITEM_DELAY = 1.75, 0.5
local MAIN_HAND, OFF_HAND = 16, 17
local SWORD, DAGGER = 190000, 190001

--- A fresh environment whose player wields SWORD in the main hand and DAGGER in the off hand.
--- Starter container 1 is the player's buff bars, with the engine's three enchant slots; container
--- 2 (player icons) has none.
local function env(opts)
    opts = opts or {}
    local NS, mocks = fresh({ before = function(m)
        m.GetInventoryItemID = function(unit, slot)
            if unit ~= "player" then return nil end
            if slot == MAIN_HAND then return SWORD end
            if slot == OFF_HAND then return DAGGER end
            return nil
        end
        if opts.before then opts.before(m) end
    end })
    mocks.__fireTimers(); mocks.__fireTimers()
    return NS, mocks, NS.ContainerManager
end

--- The live C_Timer handles armed with `delay`.
local function armed(mocks, delay)
    local n = 0
    for _, t in ipairs(mocks.__timers()) do
        if t.delay == delay then n = n + 1 end
    end
    return n
end

--- Run the live C_Timer handles armed with `delay`, and only those; each is canceled first, so it
--- leaves the live set as a timer that has fired does.
local function fire(mocks, delay)
    for _, t in ipairs(mocks.__timers()) do
        if t.delay == delay and t.Cancel then
            t.Cancel()
            t.fn()
        end
    end
end

--- The SetEnabled values engine `e` has been sent since call index `from` (exclusive).
local function enabledSince(e, from)
    local out = {}
    local last = #e.__calls
    for i = from + 1, last do
        local c = e.__calls[i]
        if c[1] == "SetEnabled" then
            local n = #out
            out[n + 1] = tostring(c[2])
        end
    end
    return table.concat(out, ",")
end

--- Container 1's instance and engine, and its call count now (a mark for enabledSince).
local function mark(CM)
    local inst = CM.instances[1]
    return inst, inst.engine, #inst.engine.__calls
end

-- -- the gates ----------------------------------------------------------------------------------

test("enchantreset: a live, shown enchant container is turned off and on again, in that order", function()
    local _, _, CM = env()
    local inst, e, from = mark(CM)
    assertEqual(#inst.enchantFrames, 3, "the starter buff bars carry the three enchant slots")
    -- red under: no ResetEnchants, or the flip reversed (an engine left off)
    assertTrue(inst:ResetEnchants())
    assertEqual(enabledSince(e, from), "false,true")
    assertTrue(e.__enabled, "left enabled")
end)

test("enchantreset: the flip is two SetEnabled calls on the same engine and nothing else", function()
    local _, _, CM = env()
    local inst, e, from = mark(CM)
    inst:ResetEnchants()
    -- red under: a reset that rebuilds (it would leak an engine frame) or re-sends the slots
    assertTrue(inst.engine == e, "the same engine")
    assertEqual(#inst.retired, 0, "nothing retired")
    assertEqual(#e.__calls - from, 2, "exactly the two SetEnabled calls")
end)

test("enchantreset: a container with no enchant frames is not flipped", function()
    local _, _, CM = env()
    local inst = CM.instances[2]   -- the player's icons: no enchant slot
    local e, from = inst.engine, #inst.engine.__calls
    assertEqual(#inst.enchantFrames, 0)
    -- red under: a gate on the engine alone (every aura bar flickers for nothing)
    assertFalse(inst:ResetEnchants())
    assertEqual(enabledSince(e, from), "")
end)

test("enchantreset: a container without an engine is not flipped", function()
    local _, _, CM = env()
    local inst = CM.instances[1]
    local e = inst.engine
    inst.engine = nil
    -- red under: no engine gate (a nil index)
    assertFalse(inst:ResetEnchants())
    inst.engine = e
end)

test("enchantreset: a parked or stale container is not flipped", function()
    local _, _, CM = env()
    local inst, e, from = mark(CM)
    inst.staleData = true
    -- red under: no staleData gate (an engine built for another container's data turned on)
    assertFalse(inst:ResetEnchants())
    assertEqual(enabledSince(e, from), "")
    inst.staleData = nil
    inst:Park()
    from = #e.__calls
    -- red under: neither ResetEnchants' parked gate nor ShouldShow's parked check (either alone
    -- holds it; the next case pins ResetEnchants' own gate)
    assertFalse(inst:ResetEnchants())
    assertEqual(enabledSince(e, from), "")
    assertFalse(e.__enabled, "still off")
end)

test("enchantreset: the parked gate holds on its own, whatever ShouldShow answers", function()
    local _, _, CM = env()
    local inst, e = mark(CM)
    inst:Park()
    local from = #e.__calls
    -- ShouldShow answers false for a parked container too; shadow it on the instance so the gate
    -- in ResetEnchants is the only thing between a parked engine and the flip.
    inst.ShouldShow = function() return true, false end
    -- red under: no parked gate in ResetEnchants (Park's SetEnabled(false) undone)
    assertFalse(inst:ResetEnchants())
    assertEqual(enabledSince(e, from), "")
    assertFalse(e.__enabled, "still off")
    inst.ShouldShow = nil
end)

test("enchantreset: a hidden container is not flipped", function()
    local NS, _, CM = env()
    local inst, e = mark(CM)
    NS.SetByPath("container.enabled", false, 1)
    local from = #e.__calls
    -- red under: no ShouldShow gate (a container the player switched off comes back on)
    assertFalse(inst:ResetEnchants())
    assertEqual(enabledSince(e, from), "")
    assertFalse(e.__enabled)
    NS.SetByPath("container.enabled", true, 1)
    NS.SetByPath("visibility", "never")
    from = #e.__calls
    assertFalse(inst:ResetEnchants(), "visibility Never")
    assertEqual(enabledSince(e, from), "")
end)

test("enchantreset: a previewing container is not flipped", function()
    local NS, _, CM = env()
    local inst, e = mark(CM)
    NS.Preview.SetTestMode(true)
    local from = #e.__calls
    -- red under: no previewing gate (the live engine drawn over the placeholders)
    assertFalse(inst:ResetEnchants())
    assertEqual(enabledSince(e, from), "")
    assertFalse(e.__enabled, "test mode keeps the engine off")
    NS.Preview.SetTestMode(false)
end)

test("enchantreset: a stood-down addon flips nothing", function()
    local NS, _, CM = env()
    local inst, e = mark(CM)
    NS.SetByPath("enabled", false)
    local from = #e.__calls
    -- red under: no stand-down gate (a disabled addon's engine turned back on)
    assertFalse(inst:ResetEnchants())
    assertEqual(enabledSince(e, from), "")
end)

test("enchantreset: the flip runs under combat lockdown and while auras are secret", function()
    local _, mocks, CM = env()
    local inst, e, from = mark(CM)
    mocks.__lockdown, mocks.__aurasSecret = true, true
    -- red under: a MustDefer gate (a name lost in a key stays blank until it ends)
    assertTrue(inst:ResetEnchants())
    assertEqual(enabledSince(e, from), "false,true")
    mocks.__lockdown, mocks.__aurasSecret = false, false
end)

test("enchantreset: CM.ResetEnchants flips every eligible container and counts them", function()
    local _, mocks, CM = env()
    local id = CM.Create({})   -- a second player buff container, with its enchant slots
    mocks.__fireTimers()
    local e1, e2 = CM.instances[1].engine, CM.instances[id].engine
    local f1, f2, f3 = #e1.__calls, #e2.__calls, #CM.instances[2].engine.__calls
    -- red under: a reset that stops at the first container
    assertEqual(CM.ResetEnchants("world"), 2)
    assertEqual(enabledSince(e1, f1), "false,true")
    assertEqual(enabledSince(e2, f2), "false,true")
    assertEqual(enabledSince(CM.instances[2].engine, f3), "", "the icons container is left alone")
end)

-- -- the loading screen ---------------------------------------------------------------------------

test("enchantreset: the loading screen's end arms one reset WORLD_DELAY later, and it flips then", function()
    local _, mocks, CM = env()
    mocks.__fireEvent("PLAYER_ENTERING_WORLD")
    assertEqual(armed(mocks, WORLD_DELAY), 0, "the loading screen is still up")
    -- After the world entry's own visibility pass, which re-sends SetEnabled(true).
    local _, e, from = mark(CM)
    mocks.__fireEvent("LOADING_SCREEN_DISABLED")
    -- red under: no LOADING_SCREEN_DISABLED trigger
    assertEqual(armed(mocks, WORLD_DELAY), 1)
    assertEqual(enabledSince(e, from), "", "nothing flips before the delay")
    fire(mocks, WORLD_DELAY)
    assertEqual(enabledSince(e, from), "false,true")
end)

test("enchantreset: the loading-screen reset does not wait on the font primer", function()
    -- Every starter container draws in Friz Quadrata, built into the client, so nothing is primed and
    -- the primer arms no world refresh at all.
    local NS, mocks, CM = env()
    mocks.__fireEvent("PLAYER_ENTERING_WORLD")
    local _, e, from = mark(CM)
    mocks.__fireEvent("LOADING_SCREEN_DISABLED")
    assertEqual(NS.FontPrimer.DiagState().state, "idle", "the primer armed nothing")
    -- red under: the reset hung off the primer's refresh (it runs only when a font was primed)
    assertEqual(armed(mocks, WORLD_DELAY), 1)
    fire(mocks, WORLD_DELAY)
    assertEqual(enabledSince(e, from), "false,true")
end)

test("enchantreset: every loading screen arms a reset, a zone change included", function()
    local _, mocks = env()
    mocks.__fireEvent("LOADING_SCREEN_DISABLED")
    fire(mocks, WORLD_DELAY)
    mocks.__fireEvent("LOADING_SCREEN_DISABLED")
    -- red under: a once-per-session latch
    assertEqual(armed(mocks, WORLD_DELAY), 1)
end)

-- -- a weapon's item data -----------------------------------------------------------------------

test("enchantreset: the main-hand weapon's item data arriving arms one reset ITEM_DELAY later", function()
    local _, mocks, CM = env()
    local _, e, from = mark(CM)
    mocks.__fireEvent("ITEM_DATA_LOAD_RESULT", SWORD, true)
    -- red under: no ITEM_DATA_LOAD_RESULT trigger
    assertEqual(armed(mocks, ITEM_DELAY), 1)
    fire(mocks, ITEM_DELAY)
    assertEqual(enabledSince(e, from), "false,true")
end)

test("enchantreset: GET_ITEM_INFO_RECEIVED for the off-hand weapon arms the reset too", function()
    local _, mocks = env()
    mocks.__fireEvent("GET_ITEM_INFO_RECEIVED", DAGGER, true)
    -- red under: no GET_ITEM_INFO_RECEIVED trigger, or slot 17 left out
    assertEqual(armed(mocks, ITEM_DELAY), 1)
end)

test("enchantreset: item data for anything but an equipped weapon, or a failed load, arms nothing", function()
    local _, mocks = env()
    mocks.__fireEvent("ITEM_DATA_LOAD_RESULT", 12345, true)
    mocks.__fireEvent("GET_ITEM_INFO_RECEIVED", 12345, true)
    -- red under: every item load in the game arming a reset
    assertEqual(armed(mocks, ITEM_DELAY), 0, "a bag item")
    mocks.__fireEvent("ITEM_DATA_LOAD_RESULT", SWORD, false)
    -- red under: a failed load flipping (the engine would draw the same empty name again)
    assertEqual(armed(mocks, ITEM_DELAY), 0, "a failed load")
    mocks.__fireEvent("ITEM_DATA_LOAD_RESULT", nil, true)
    assertEqual(armed(mocks, ITEM_DELAY), 0, "no item id")
end)

test("enchantreset: with no weapon equipped, item data arms nothing", function()
    local _, mocks = env({ before = function(m) m.GetInventoryItemID = function() return nil end end })
    mocks.__fireEvent("ITEM_DATA_LOAD_RESULT", SWORD, true)
    -- red under: a nil slot compared loosely against the item id
    assertEqual(armed(mocks, ITEM_DELAY), 0)
end)

-- -- the debounce ---------------------------------------------------------------------------------

test("enchantreset: a burst of item data arms one timer and flips once", function()
    local _, mocks, CM = env()
    local _, e, from = mark(CM)
    mocks.__fireEvent("ITEM_DATA_LOAD_RESULT", SWORD, true)
    mocks.__fireEvent("GET_ITEM_INFO_RECEIVED", SWORD, true)
    mocks.__fireEvent("ITEM_DATA_LOAD_RESULT", DAGGER, true)
    -- red under: one timer per event (the engine flipped three times in a row)
    assertEqual(armed(mocks, ITEM_DELAY), 1)
    mocks.__fireTimers()
    assertEqual(enabledSince(e, from), "false,true")
end)

test("enchantreset: an armed reset keeps the later of two deadlines", function()
    local _, mocks = env()
    mocks.__fireEvent("LOADING_SCREEN_DISABLED")
    mocks.__fireEvent("ITEM_DATA_LOAD_RESULT", SWORD, true)
    -- red under: the item's shorter delay replacing the world's (a flip before the fonts are drawn)
    assertEqual(armed(mocks, WORLD_DELAY), 1)
    assertEqual(armed(mocks, ITEM_DELAY), 0)
    fire(mocks, WORLD_DELAY)
    mocks.__fireEvent("ITEM_DATA_LOAD_RESULT", SWORD, true)
    mocks.__fireEvent("LOADING_SCREEN_DISABLED")
    -- red under: a second timer beside the first
    assertEqual(armed(mocks, ITEM_DELAY), 0, "the item's timer was replaced")
    assertEqual(armed(mocks, WORLD_DELAY), 1)
end)

test("enchantreset: a fired reset clears the debounce, so the next trigger arms again", function()
    local _, mocks = env()
    mocks.__fireEvent("ITEM_DATA_LOAD_RESULT", SWORD, true)
    fire(mocks, ITEM_DELAY)
    mocks.__fireEvent("ITEM_DATA_LOAD_RESULT", SWORD, true)
    -- red under: the handle never cleared (every later trigger absorbed by a timer that has run)
    assertEqual(armed(mocks, ITEM_DELAY), 1)
end)

-- -- the stand-down -------------------------------------------------------------------------------

test("enchantreset: a stand-down cancels an armed reset and hears no trigger", function()
    local NS, mocks, CM = env()
    local _, e = mark(CM)
    mocks.__fireEvent("LOADING_SCREEN_DISABLED")
    assertEqual(armed(mocks, WORLD_DELAY), 1)
    NS.SetByPath("enabled", false)
    -- red under: StopListening leaving the reset armed (it would wake a stood-down addon)
    assertEqual(armed(mocks, WORLD_DELAY), 0)
    mocks.__fireEvent("LOADING_SCREEN_DISABLED")
    mocks.__fireEvent("ITEM_DATA_LOAD_RESULT", SWORD, true)
    mocks.__fireEvent("GET_ITEM_INFO_RECEIVED", SWORD, true)
    -- red under: the item events registered outside the lifecycle list (a stand-down could not remove them)
    assertEqual(armed(mocks, WORLD_DELAY) + armed(mocks, ITEM_DELAY), 0)
    local from = #e.__calls
    assertEqual(CM.RequestEnchantReset("item"), false, "a direct request is refused too")
    assertEqual(enabledSince(e, from), "")
    NS.SetByPath("enabled", true)
    mocks.__fireTimers()
    mocks.__fireEvent("ITEM_DATA_LOAD_RESULT", SWORD, true)
    -- red under: the stand-up not restoring the item events
    assertEqual(armed(mocks, ITEM_DELAY), 1)
end)

-- -- the trace ------------------------------------------------------------------------------------

test("enchantreset: a reset writes one [Apply] line naming its count and its trigger", function()
    local NS, mocks = env()
    local lines = {}
    NS.Debug = function(tag, fmt, ...)
        if tag ~= "Apply" then return end
        local args = { ... }
        for i = 1, select("#", ...) do args[i] = tostring(args[i]) end
        lines[#lines + 1] = fmt:format(unpack(args, 1, select("#", ...)))
    end
    mocks.__fireEvent("ITEM_DATA_LOAD_RESULT", SWORD, true)
    fire(mocks, ITEM_DELAY)
    mocks.__fireEvent("LOADING_SCREEN_DISABLED")
    fire(mocks, WORLD_DELAY)
    -- red under: a silent reset (the owner cannot tell whether it ran)
    assertEqual(#lines, 2)
    assertEqual(lines[1], "enchants reset on 1 container(s) after item data")
    assertEqual(lines[2], "enchants reset on 1 container(s) after the loading screen")
end)
