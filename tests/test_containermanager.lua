-- tests/test_containermanager.lua — modules/ContainerManager.lua: the registry's write side, the
-- coalesced apply and the combat / secrecy deferral.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")

local function chat(mocks)
    local lines = {}
    rawset(mocks.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg) lines[#lines + 1] = tostring(msg) end)
    return lines
end

local function countMessages(NS, msg)
    local n = { 0 }
    NS.NewBusTarget():RegisterMessage(msg, function() n[1] = n[1] + 1 end)
    return n
end

test("manager: Create appends a container, names it uniquely and announces it", function()
    local NS = fresh()
    local changed = countMessages(NS, NS.MSG.CONTAINERS_CHANGED)
    local id = NS.ContainerManager.Create({ unit = "focus" })
    local c = NS.Database.FindContainer(id)
    assertEqual(c.unit, "focus")
    assertTrue(c.name:find("^Container") ~= nil)
    assertEqual(NS.db.profile.containerOrder[#NS.db.profile.containerOrder], id)
    assertTrue(NS.ContainerManager.instances[id] ~= nil, "a live instance follows")
    assertEqual(changed[1], 1)
end)

test("manager: two containers with one name become 'X' and 'X (2)'", function()
    local NS = fresh()
    local a = NS.ContainerManager.Create({ name = "Procs" })
    local b = NS.ContainerManager.Create({ name = "Procs" })
    assertEqual(NS.Database.FindContainer(a).name, "Procs")
    assertEqual(NS.Database.FindContainer(b).name, "Procs (2)")
end)

test("manager: deleting a container sends the ones attached to it back to the screen", function()
    local NS = fresh()
    local c2 = NS.Database.FindContainer(2)
    c2.attach.mode, c2.attach.container = "container", 1
    NS.State.SetActiveContainer(1)
    assertTrue(NS.ContainerManager.Delete(1))
    assertEqual(c2.attach.mode, "screen")
    assertNil(NS.State.activeContainerId, "the selection does not point at a deleted container")
    assertFalse((NS.ContainerManager.Delete(1)), "a second delete refuses")
end)

test("manager: Rename trims, refuses an empty name and keeps names unique", function()
    local NS = fresh()
    local changed = countMessages(NS, NS.MSG.CONTAINERS_CHANGED)
    assertTrue(NS.ContainerManager.Rename(1, "  Buffs  "))
    assertEqual(NS.Database.FindContainer(1).name, "Buffs")
    assertEqual(changed[1], 1, "a rename is announced on the registry message")
    assertFalse((NS.ContainerManager.Rename(1, "   ")))
    NS.ContainerManager.Rename(2, "Buffs")
    assertEqual(NS.Database.FindContainer(2).name, "Buffs (2)")
end)

test("manager: Duplicate copies every setting under a new id and name, offset on screen", function()
    local NS = fresh()
    local src = NS.Database.FindContainer(2)
    src.icons.width = 44
    local id = NS.ContainerManager.Duplicate(2)
    local c = NS.Database.FindContainer(id)
    assertEqual(c.icons.width, 44)
    assertEqual(c.auraType, src.auraType)
    assertEqual(c.name, src.name .. " (copy)")
    assertEqual(c.position.x, src.position.x + 20)
    c.icons.width = 10
    assertEqual(src.icons.width, 44, "nothing is shared with the source")
end)

test("manager: CopyFrom copies the chosen section, never the name or the position", function()
    local NS = fresh()
    local src, dst = NS.Database.FindContainer(2), NS.Database.FindContainer(1)
    src.bars.width = 333
    src.icons.width = 55
    local name, x = dst.name, dst.position.x
    assertTrue(NS.ContainerManager.CopyFrom(2, 1, "bars"))
    assertEqual(dst.bars.width, 333)
    assertEqual(dst.icons.width, NS.CONTAINER_TEMPLATE.icons.width, "only the chosen section")
    assertEqual(dst.name, name)
    assertEqual(dst.position.x, x)
    assertFalse((NS.ContainerManager.CopyFrom(1, 1)), "a container cannot copy itself")
    NS.ContainerManager.CopyFrom(2, 1)
    assertEqual(dst.style, src.style, "copying everything copies what it is, too")
end)

test("manager: many apply requests in one frame schedule one pass", function()
    local NS, mocks = fresh()
    local before = #mocks.__timers
    NS.ContainerManager.RequestApply(1)
    NS.ContainerManager.RequestApply(2)
    NS.ContainerManager.RequestApply()
    assertEqual(#mocks.__timers, before + 1)
    mocks.__fireTimers()
end)

test("manager: an apply under combat lockdown waits, says so once, and runs after combat", function()
    local NS, mocks = fresh()
    local lines = chat(mocks)
    mocks.__lockdown = true
    NS.ContainerManager.RequestApply()
    mocks.__fireTimers()
    NS.ContainerManager.RequestApply()
    mocks.__fireTimers()
    local notices = 0
    for _, l in ipairs(lines) do if l:find("when combat ends", 1, true) then notices = notices + 1 end end
    assertEqual(notices, 1, "told once, not per change")
    mocks.__lockdown = false
    assertTrue(NS.ContainerManager.FlushPending() > 0, "the queued apply runs once combat ends")
end)

test("manager: ResetPositions puts every container back on the screen, staggered", function()
    local NS = fresh()
    local c1 = NS.Database.FindContainer(1)
    c1.position.x = 500
    c1.attach.mode = "frame"
    NS.ContainerManager.ResetPositions()
    assertEqual(c1.position.x, 0)
    assertEqual(c1.attach.mode, "screen")
    assertEqual(NS.Database.FindContainer(2).position.y, -30)
end)
