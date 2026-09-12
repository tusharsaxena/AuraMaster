-- tests/test_bus.lua — core/Bus.lua: the closed message bus. Its contract is the catalog (every
-- name this addon's own, none shared), a target per receiver (two receivers never clobber each
-- other), and one sender per message: CONTAINERS_CHANGED once per registry act and never for a
-- refused one, VISIBILITY_CHANGED once per world or combat edge, and a CONFIG_CHANGED receiver that
-- reads its payload defensively.

local T = _G.AM_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local fresh = dofile("tests/fresh_env.lua")

--- Count deliveries of `msg` on a receiver of its own. Returns a one-slot box.
local function counter(NS, msg)
    local n = { 0 }
    NS.NewBusTarget():RegisterMessage(msg, function() n[1] = n[1] + 1 end)
    return n
end

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

local function total(by)
    local n = 0
    for _, v in pairs(by) do n = n + v end
    return n
end

test("bus: every message name carries this addon's prefix and no two share one", function()
    local names, count = {}, 0
    for key, name in pairs(T.NS.MSG) do
        -- red under: a message renamed without the Ka0s_AuraMaster_ prefix
        assertTrue(type(name) == "string" and name:find("^Ka0s_AuraMaster_") ~= nil, key .. " = " .. tostring(name))
        assertTrue(names[name] == nil, key .. " shares its name with " .. tostring(names[name]))
        names[name] = key
        count = count + 1
    end
    assertEqual(count, 4, "the four messages docs/ARCHITECTURE.md catalogs")
end)

test("bus: two receivers on their own targets both hear one message, with its payload", function()
    local NS = T.NS
    local probe = "Ka0s_AuraMaster_TestProbe"
    local got, payload = {}, { containerId = 2 }
    local function receiver(msg, p)
        local n = #got
        got[n + 1] = { msg, p }
    end
    NS.NewBusTarget():RegisterMessage(probe, receiver)
    NS.NewBusTarget():RegisterMessage(probe, receiver)
    NS.bus:SendMessage(probe, payload)
    -- red under: NewBusTarget handing out one shared table (the second registration replaces the first)
    assertEqual(#got, 2, "both receivers ran")
    for _, g in ipairs(got) do
        assertEqual(g[1], probe)
        assertTrue(g[2] == payload, "the payload arrives as sent")
    end
end)

test("bus: CONTAINERS_CHANGED goes out once per registry act, and never for a refused one", function()
    local NS, mocks = fresh()
    local CM = NS.ContainerManager
    local n = counter(NS, NS.MSG.CONTAINERS_CHANGED)
    local steps = {
        { "create",             function() CM.Create({}) end, 1 },
        { "duplicate",          function() CM.Duplicate(1) end, 1 },
        { "delete",             function() CM.Delete(2) end, 1 },
        { "delete, no such id", function() CM.Delete(99) end, 0 },
        { "copy settings",      function() CM.CopyFrom(1, 3, "bars") end, 0 },
        { "create in combat",   function()
            mocks.__lockdown = true
            CM.Create({})
            mocks.__lockdown = false
        end, 0 },
        { "profile switch",     function() NS.db:SetProfile("Raid") end, 1 },
        { "profile reset",      function() NS.db:ResetProfile() end, 1 },
        { "profile copy",       function() NS.db:CopyProfile("Default") end, 1 },
    }
    for _, s in ipairs(steps) do
        local before = n[1]
        s[2]()
        mocks.__fireTimers()
        -- red under: CM.Delete announcing before its no-such-container guard
        -- red under: OnProfileReset or OnProfileCopied not rebuilding through CM.Announce
        assertEqual(n[1] - before, s[3], s[1])
    end
end)

test("bus: world entry and each combat edge send one VISIBILITY_CHANGED; a unit swap sends none", function()
    local NS, mocks = fresh()
    local n = counter(NS, NS.MSG.VISIBILITY_CHANGED)
    local edges = {
        { "PLAYER_ENTERING_WORLD", 1 }, { "PLAYER_REGEN_DISABLED", 1 },
        { "PLAYER_REGEN_ENABLED", 1 }, { "PLAYER_TARGET_CHANGED", 0 },
    }
    for _, e in ipairs(edges) do
        local before = n[1]
        mocks.__fireEvent(e[1])
        -- red under: OnCombatChanged sending VISIBILITY_CHANGED on one edge only
        assertEqual(n[1] - before, e[2], e[1])
    end
end)

test("bus: a CONFIG_CHANGED the receiver cannot read re-applies the container it names, or every one", function()
    local NS, mocks = fresh()
    local by = countApplies(NS)
    NS.bus:SendMessage(NS.MSG.CONFIG_CHANGED)
    mocks.__fireTimers()
    -- red under: the CONFIG_CHANGED receiver indexing a missing payload
    assertEqual(total(by), 3, "no payload: every container re-applies")
    for k in pairs(by) do by[k] = nil end
    NS.bus:SendMessage(NS.MSG.CONFIG_CHANGED, { containerId = 2, path = "no.such.row" })
    mocks.__fireTimers()
    -- red under: a path with no schema row taken for an effect = "none" row
    assertEqual(by[2], 1, "an unknown row still re-applies its container")
    assertEqual(total(by), 1, "and only that one")
end)
