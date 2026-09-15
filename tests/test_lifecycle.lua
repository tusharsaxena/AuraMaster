-- tests/test_lifecycle.lua — core/AuraMaster.lua: the lifecycle events and the three AceDB profile
-- handlers. Events are fired through the kit's AceEvent dispatch (mocks.__fireEvent), so a case sees
-- the registration and the handler together, the way the client runs them.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")

-- Every lifecycle event and the method it is registered to (core/AuraMaster.lua).
local LIFECYCLE = {
    PLAYER_ENTERING_WORLD = "OnEnterWorld",
    PLAYER_REGEN_DISABLED = "OnCombatChanged",
    PLAYER_REGEN_ENABLED = "OnCombatChanged",
    PLAYER_TARGET_CHANGED = "OnUnitSwap",
    PLAYER_FOCUS_CHANGED = "OnUnitSwap",
    UNIT_PET = "OnUnitPet",
    ADDON_LOADED = "OnAddonLoaded",
    ADDON_RESTRICTION_STATE_CHANGED = "OnRestrictionChanged",
}

--- Count Container:Apply per id, still calling through. Returns the counts table.
local function countApplies(NS)
    local by = {}
    for id, inst in pairs(NS.ContainerManager.instances) do
        local apply = inst.Apply
        rawset(inst, "Apply", function(self)
            by[id] = (by[id] or 0) + 1
            return apply(self)
        end)
    end
    return by
end

--- How many UpdateAllAuras container `id`'s engine has been sent.
local function refreshes(NS, id)
    return #NS.ContainerManager.instances[id].engine:__callsTo("UpdateAllAuras")
end

local function layouts(e)
    local calls = e:__callsTo("SetAuraGroupLayout")
    return #calls
end

--- Hold a player's change to container 1 while auras are secret, then let secrecy lapse without the
--- event that would announce it. Returns container 1's engine.
local function heldChange(NS, mocks)
    mocks.__aurasSecret = true
    assertTrue(NS.SetByPath("container.bars.width", 260, 1))
    mocks.__fireTimers()
    mocks.__aurasSecret = false
    return NS.ContainerManager.instances[1].engine
end

-- ── events ───────────────────────────────────────────────────────────────────────────────────

test("lifecycle: the eight lifecycle events are registered to their handlers, and nothing else is", function()
    local NS = fresh()
    local events = NS.addon.__events
    for event in pairs(events) do
        -- red under: an event registered outside RegisterLifecycleEvents, which suspend could not remove
        assertTrue(LIFECYCLE[event] ~= nil, "unexpected registration " .. tostring(event))
    end
    for event, handler in pairs(LIFECYCLE) do
        -- red under: dropping ADDON_RESTRICTION_STATE_CHANGED (a hold secrecy alone caused would never flush)
        assertEqual(events[event], handler, event)
    end
end)

test("lifecycle: a focus change refreshes the focus containers, a target change the target ones", function()
    local NS, mocks = fresh()
    local focus = NS.ContainerManager.Create({ unit = "focus" })
    mocks.__fireTimers()
    mocks.__fireEvent("PLAYER_FOCUS_CHANGED")
    -- red under: OnUnitSwap taking every swap for the target
    assertEqual(refreshes(NS, focus), 1)
    assertEqual(refreshes(NS, 3), 0, "the target container is untouched")
    mocks.__fireEvent("PLAYER_TARGET_CHANGED")
    assertEqual(refreshes(NS, 3), 1)
    assertEqual(refreshes(NS, focus), 1)
end)

test("lifecycle: UNIT_PET refreshes the pet containers only for the player's own pet", function()
    local NS, mocks = fresh()
    local pet = NS.ContainerManager.Create({ unit = "pet" })
    mocks.__fireTimers()
    mocks.__fireEvent("UNIT_PET", "party1")
    -- red under: OnUnitPet without its unit == "player" guard
    assertEqual(refreshes(NS, pet), 0, "a party member's pet is not ours")
    mocks.__fireEvent("UNIT_PET", "player")
    assertEqual(refreshes(NS, pet), 1)
end)

test("lifecycle: entering the world runs an apply held while auras were secret", function()
    local NS, mocks = fresh()
    local e = heldChange(NS, mocks)
    local before = layouts(e)
    mocks.__fireEvent("PLAYER_ENTERING_WORLD")
    -- red under: OnEnterWorld without its FlushPending
    assertTrue(layouts(e) > before, "the held change reached the engine")
end)

test("lifecycle: combat starting runs no held apply; combat ending does", function()
    local NS, mocks = fresh()
    local e = heldChange(NS, mocks)
    local before = layouts(e)
    mocks.__fireEvent("PLAYER_REGEN_DISABLED")
    -- red under: OnCombatChanged flushing on PLAYER_REGEN_DISABLED, the edge lockdown begins right after
    assertEqual(layouts(e), before, "nothing is rebuilt as a fight begins")
    mocks.__fireEvent("PLAYER_REGEN_ENABLED")
    assertTrue(layouts(e) > before)
end)

-- ── the profile handlers ─────────────────────────────────────────────────────────────────────

test("lifecycle: a profile switch out of combat rebuilds every container for the new profile at once", function()
    local NS, mocks = fresh()
    local CM = NS.ContainerManager
    local id = CM.Create({})
    assertTrue(NS.SetByPath("container.unit", "focus", 1))
    mocks.__fireTimers()
    local inst1, gone = CM.instances[1], CM.instances[id]
    gone.anchor:Show()
    local by = countApplies(NS)
    NS.db:SetProfile("Raid")
    -- red under: CM.Sync parking departing containers out of combat
    assertNil(next(CM.__retiring()), "nothing is parked out of combat")
    assertFalse(gone.anchor:IsShown(), "the container Raid lacks is torn down at once")
    assertNil(CM.instances[id])
    mocks.__fireTimers()
    for i = 1, 3 do assertEqual(by[i], 1, "container " .. i .. " applied once") end
    assertNil(by[id])
    assertNil(inst1.parked)
    assertEqual(inst1.unit, "player", "rebuilt for Raid's container 1")
    assertTrue(inst1.engine.__enabled)
end)

test("lifecycle: every profile event clears the container selection and re-renders the panel once", function()
    local NS = fresh()
    local renders, refresh = 0, NS.RefreshOptionsPanel
    NS.RefreshOptionsPanel = function(...)
        renders = renders + 1
        if refresh then return refresh(...) end
    end
    local acts = {
        { "switch", function() NS.db:SetProfile("Raid") end },
        { "copy",   function() NS.db:CopyProfile("Default") end },
        { "reset",  function() NS.db:ResetProfile() end },
    }
    for _, a in ipairs(acts) do
        NS.State.SetActiveContainer(2)
        local before = renders
        a[2]()
        -- red under: prepareProfile without its SetActiveContainer(nil)
        assertNil(NS.State.activeContainerId, a[1] .. ": the selection may name another profile's container")
        -- red under: rebuildProfile without RefreshOptionsPanel
        assertEqual(renders - before, 1, a[1])
    end
end)

test("lifecycle: a copied profile is prepared before its containers are built", function()
    local sv = { profiles = { Legacy = {
        seeded = true,
        containers = { ["7"] = { name = "Old focus", unit = "focus", auraType = "HARMFUL", style = "icons" } },
        containerOrder = { "7" },
    } } }
    local NS, mocks = fresh({ savedVariables = sv })
    NS.db:CopyProfile("Legacy")
    local c = NS.Database.FindContainer(7)
    -- red under: OnProfileCopied skipping prepareProfile (the string key reaches CM.Sync with no id)
    assertTrue(c ~= nil, "the string key is normalized")
    assertEqual(c.id, 7)
    assertEqual(c.bars.width, NS.CONTAINER_TEMPLATE.bars.width, "backfilled from the template")
    assertEqual(NS.db.profile.nextContainerId, 8, "the counter moves past the copied id")
    mocks.__fireTimers()
    local inst = NS.ContainerManager.instances[7]
    assertTrue(inst ~= nil and inst.engine ~= nil, "built for the copied container")
    assertEqual(inst.unit, "focus")
    assertNil(NS.ContainerManager.instances[1], "the old profile's containers are gone")
end)

test("lifecycle: a reset profile gets its starters back, numbered from 1 again", function()
    local NS, mocks = fresh()
    local CM = NS.ContainerManager
    CM.Create({})
    mocks.__fireTimers()
    for _, c in ipairs(NS.Database.GetContainers()) do CM.Delete(c.id) end
    mocks.__fireTimers()
    assertEqual(CM.Count(), 0)
    NS.db:ResetProfile()
    -- red under: OnProfileReset skipping prepareProfile (the reset profile would stay empty)
    assertEqual(CM.Count(), #NS.STARTER_CONTAINERS)
    assertEqual(NS.db.profile.nextContainerId, #NS.STARTER_CONTAINERS + 1)
    mocks.__fireTimers()
    local starters = #NS.STARTER_CONTAINERS
    for id = 1, starters do
        local inst = CM.instances[id]
        assertTrue(inst ~= nil and inst.engine ~= nil, "container " .. id .. " built")
    end
end)

test("lifecycle: a profile switch applies the new profile's Blizzard-frame settings", function()
    local NS = fresh({
        savedVariables = { profiles = { Raid = { hideBlizzardBuffs = true } } },
        before = function(m) m.BuffFrame, m.DebuffFrame = m.__stubFrame(), m.__stubFrame() end,
    })
    assertFalse(NS.BlizzardFrames.IsHidden("BuffFrame"))
    NS.db:SetProfile("Raid")
    -- red under: rebuildProfile without BlizzardFrames.Apply
    assertTrue(NS.BlizzardFrames.IsHidden("BuffFrame"))
end)
