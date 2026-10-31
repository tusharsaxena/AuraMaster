-- tests/test_containermanager_queue.lua — modules/ContainerManager.lua: the apply queue, the registry's
-- write side and a pass that survives one container raising. Peeled out of
-- tests/test_containermanager.lua by theme.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")

local function chat(mocks)
    local lines = {}
    rawset(mocks.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
        lines[#lines + 1] = tostring(msg)
    end)
    return lines
end

local function countLines(lines, needle)
    local n = 0
    for _, l in ipairs(lines) do if l:find(needle, 1, true) then n = n + 1 end end
    return n
end

-- ── the queue ────────────────────────────────────────────────────────────────────────────────

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

test("manager: a request for one container applies only that one", function()
    local NS, mocks = fresh()
    local by = countApplies(NS)
    NS.ContainerManager.RequestApply(2)
    mocks.__fireTimers()
    -- red under: applyDirty applying every container whatever was asked
    assertEqual(by[2], 1)
    assertNil(by[1])
    assertNil(by[3])
end)

test("manager: a flushed queue is empty, and a later request schedules a pass of its own", function()
    local NS, mocks = fresh()
    local CM = NS.ContainerManager
    CM.RequestApply(1)
    mocks.__fireTimers()
    assertEqual(CM.FlushPending(), 0, "nothing is left to apply")
    local timers = #mocks.__timers
    CM.RequestApply(1)
    -- red under: FlushPending not clearing `scheduled` (no later request would ever be scheduled)
    assertEqual(#mocks.__timers, timers + 1, "a new pass is scheduled")
end)

test("manager: a held request keeps exactly its container through the hold", function()
    local NS, mocks = fresh()
    local CM = NS.ContainerManager
    local by = countApplies(NS)
    mocks.__aurasSecret = true
    CM.RequestApply(2)
    mocks.__fireTimers()
    assertEqual(CM.FlushPending(), 0, "still held")
    assertNil(by[2])
    mocks.__aurasSecret = false
    NS.addon:OnRestrictionChanged()
    -- red under: the deferral dropping the queue, or widening it to every container
    assertEqual(by[2], 1)
    assertNil(by[1])
    assertNil(by[3])
end)

test("manager: a flush with nothing queued traces no deferral, even under lockdown", function()
    local NS, mocks = fresh()
    local traced = {}
    NS.Debug = function(tag, fmt)
        if tag ~= "Apply" then return end
        local n = #traced
        traced[n + 1] = fmt
    end
    mocks.__lockdown = true
    assertEqual(NS.ContainerManager.FlushPending(), 0)
    -- red under: FlushPending noting a deferral without its idle check (a line on every edge in combat)
    assertEqual(#traced, 0, "nothing was held")
end)

test("manager: a container row re-applies its own container; an addon-wide row re-applies every one", function()
    local NS, mocks = fresh()
    local by = countApplies(NS)
    assertTrue(NS.SetByPath("container.bars.width", 250, 2))
    mocks.__fireTimers()
    -- red under: the CONFIG_CHANGED receiver dropping the payload's containerId
    assertEqual(by[2], 1)
    assertNil(by[1])
    assertTrue(NS.SetByPath("scale", 1.2))
    mocks.__fireTimers()
    assertEqual(by[1], 1, "master scale reaches container 1")
    assertEqual(by[2], 2)
    assertEqual(by[3], 1)
end)

-- ── the registry, write side ─────────────────────────────────────────────────────────────────

test("manager: a new container is named and staggered by its id; a given position is kept", function()
    local NS = fresh()
    local CM = NS.ContainerManager
    local id = CM.Create({})
    assertEqual(id, 5)
    local c = NS.Database.FindContainer(5)
    assertEqual(c.name, "Container 5")
    -- red under: newContainerData staggering without the id
    assertEqual(c.position.y, -120, "four steps down")
    local placed = CM.Create({ position = { point = "CENTER", relativePoint = "CENTER", x = 5, y = 6 } })
    -- red under: newContainerData staggering a position the caller gave
    assertEqual(NS.Database.FindContainer(placed).position.y, 6)
    repeat id = CM.Create({}) until id >= 9
    -- red under: dropping the modulo (a ninth container would start 240 below the first)
    assertEqual(NS.Database.FindContainer(9).position.y, 0, "every eighth id starts the stagger over")
end)

test("manager: UniqueName skips every taken suffix, and a blank name becomes Container", function()
    local NS = fresh()
    local CM = NS.ContainerManager
    CM.Create({ name = "Procs" })
    CM.Create({ name = "Procs" })
    -- red under: UniqueName trying only the (2) suffix
    assertEqual(CM.UniqueName("Procs"), "Procs (3)")
    assertEqual(CM.UniqueName(""), "Container", "an empty name is never handed out")
    assertEqual(CM.UniqueName(nil), "Container")
end)

test("manager: deleting a container leaves every other attachment and the selection alone", function()
    local NS = fresh()
    local c1, c3 = NS.Database.FindContainer(1), NS.Database.FindContainer(3)
    c3.attach.mode, c3.attach.container = "container", 1
    c1.attach.mode, c1.attach.frame = "frame", "SomeBar"
    NS.State.SetActiveContainer(3)
    assertTrue(NS.ContainerManager.Delete(2))
    -- red under: Delete sending every container-attached container back to the screen
    assertEqual(c3.attach.mode, "container", "3 is attached to 1, not to 2")
    assertEqual(c1.attach.mode, "frame")
    -- red under: Delete clearing the selection whatever was deleted
    assertEqual(NS.State.activeContainerId, 3)
    assertEqual(table.concat(NS.db.profile.containerOrder, ","), "1,3,4")
end)

test("manager: a duplicate of an attached container keeps its position; an unknown id is refused", function()
    local NS = fresh()
    local src = NS.Database.FindContainer(1)
    src.attach.mode, src.attach.frame = "frame", "SomeBar"
    local id = NS.ContainerManager.Duplicate(1)
    local c = NS.Database.FindContainer(id)
    -- red under: Duplicate offsetting the position whatever the container is attached to
    assertEqual(c.position.x, src.position.x)
    assertEqual(c.position.y, src.position.y)
    assertEqual(c.attach.frame, "SomeBar")
    local none, err = NS.ContainerManager.Duplicate(99)
    assertNil(none)
    assertEqual(err, "No such container.")
end)

test("manager: a rebuilt engine re-anchors every container attached to it", function()
    local NS, mocks = fresh()
    local CM = NS.ContainerManager
    local c2 = NS.Database.FindContainer(2)
    c2.attach.mode, c2.attach.container = "container", 1
    NS.Anchors.Place(CM.instances[2])
    local points = {}
    rawset(CM.instances[2].anchor, "SetPoint", function(self, ...)
        points[#points + 1] = { ... }
        return self
    end)
    local old = CM.instances[1].engine
    assertTrue(NS.SetByPath("container.filter.hidePermanentEnchants", false, 1))   -- a change of shape
    mocks.__fireTimers()
    local new = CM.instances[1].engine
    assertTrue(new ~= old, "container 1 was rebuilt")
    -- red under: FlushPending without replaceAttached (container 2 would stay on the retired engine)
    local placed = #points
    assertTrue(placed > 0, "container 2 was placed again")
    assertTrue(points[placed][2] == new, "container 2 hangs off container 1's new engine")
end)

test("manager: a client without the aura engine is told once, at startup", function()
    local lines
    fresh({ before = function(m)
        m.AuraContainerSortMethod = nil
        lines = chat(m)
    end })
    -- red under: CM.Init not checking EnsureAuraContainer
    assertEqual(countLines(lines, "no aura container API"), 1)
end)

-- B-5: one container whose Apply raises must not drop the rest of the pass. FlushPending clears the
-- queue before applying, so an unguarded raise loses every later container and replaceAttached.

--- Container 1 raises; container 2 only counts (its real Apply would Place it too, hiding whether
--- replaceAttached ran). Container 2 is attached to container 1, so replaceAttached Places it.
local function raisingPass(NS)
    local CM = NS.ContainerManager
    CM.instances[1].Apply = function() error("boom") end
    local inst2, seen = CM.instances[2], { applied = 0, placed = 0 }
    inst2.Apply = function() seen.applied = seen.applied + 1 end
    local c2 = NS.Database.FindContainer(2)
    c2.attach.mode, c2.attach.container = "container", 1
    local place = NS.Anchors.Place
    NS.Anchors.Place = function(inst, ...)
        if inst == inst2 then seen.placed = seen.placed + 1 end
        return place(inst, ...)
    end
    CM.RequestApply()
    return seen
end

test("apply: an error in one container's Apply does not stop the others or replaceAttached", function()
    local reported = { count = 0 }
    local function handler(err)
        reported.count = reported.count + 1
        reported.last = err
    end
    local NS = fresh({ before = function(m)
        m.debugstack = function() return debug.traceback("stack:", 2) end
        m.geterrorhandler = function() return handler end
    end })
    local containers = NS.Database.GetContainers()
    local total = #containers
    local seen = raisingPass(NS)
    local ok, applied = pcall(NS.ContainerManager.FlushPending)
    -- red under: an unguarded inst:Apply() in applyDirty (the raise escapes, container 2 never applies)
    assertTrue(ok, tostring(applied))
    assertEqual(seen.applied, 1, "container 2 still applied")
    assertEqual(seen.placed, 1, "replaceAttached still ran")
    -- red under: counting the failed container as applied
    assertEqual(applied, total - 1, "only successes count")
    -- red under: reporting the error twice, or not handing it to the client's error handler
    assertEqual(reported.count, 1, "the error is reported once")
    assertTrue(tostring(reported.last):find("boom", 1, true) ~= nil, tostring(reported.last))
    -- red under: a bare pcall (the handler sees no stack from where Apply raised)
    assertTrue(tostring(reported.last):find("\n", 1, true) ~= nil, "the stack travels with the error")
end)

test("apply: with no client error handler the pass finishes, then the first error is raised", function()
    local NS = fresh()
    local seen = raisingPass(NS)
    local ok, err = pcall(NS.ContainerManager.FlushPending)
    -- red under: swallowing the error when geterrorhandler is absent (a headless failure goes silent)
    assertFalse(ok, "the error is not swallowed")
    assertTrue(tostring(err):find("boom", 1, true) ~= nil, tostring(err))
    -- red under: re-raising from inside the loop rather than after the pass
    assertEqual(seen.applied, 1, "container 2 applied before the raise")
    assertEqual(seen.placed, 1, "replaceAttached ran before the raise")
end)
