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

test("manager: names that differ only in case are not unique", function()
    local NS = fresh()
    -- red under: UniqueName keying taken names case-sensitively
    assertEqual(NS.ContainerManager.UniqueName("player buffs"), "player buffs (2)")
    assertEqual(NS.ContainerManager.UniqueName("player buffs", 1), "player buffs",
        "a container's own name does not count against it")
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

test("manager: CopyFrom and ResetPositions write through the seam, send no CONTAINERS_CHANGED, and report a rejected write", function()
    local NS = fresh()
    local CM = NS.ContainerManager
    local changed = countMessages(NS, NS.MSG.CONTAINERS_CHANGED)
    local config = countMessages(NS, NS.MSG.CONFIG_CHANGED)
    assertTrue(CM.CopyFrom(2, 1))
    CM.ResetPositions()
    assertTrue(config[1] > 0, "a copy and a reset are settings writes")
    -- red under: restoring the direct CONTAINERS_CHANGED send
    assertEqual(changed[1], 0, "the registry did not change")
    NS.Database.FindContainer(2).filter.whitelist = "garbage"
    local ok, err = CM.CopyFrom(2, 1, "filter")
    -- red under: CopyFrom ignoring SetByPath's result
    assertFalse(ok, "a write the seam rejects fails the copy")
    assertTrue(type(err) == "string" and err ~= "", tostring(err))
    assertEqual(type(NS.Database.FindContainer(1).filter.whitelist), "table", "nothing was stored")
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

local COMBAT_LINE = "will apply when combat ends"
local SECRET_LINE = "will apply once aura information is available again"

--- How many captured chat lines contain `needle`.
local function countLines(lines, needle)
    local n = 0
    for _, l in ipairs(lines) do if l:find(needle, 1, true) then n = n + 1 end end
    return n
end

--- Wrap CM.RequestApply with a counter, still calling through. Returns a one-slot box.
local function countRequests(CM)
    local n, orig = { 0 }, CM.RequestApply
    CM.RequestApply = function(...) n[1] = n[1] + 1; return orig(...) end
    return n
end

test("manager: /am preview, /am lock and a rename under lockdown print no deferral notice", function()
    local NS, mocks = fresh()
    local lines = chat(mocks)
    mocks.__lockdown = true
    assertTrue(NS.SetByPath("state.preview", true))
    assertTrue(NS.SetByPath("locked", true))
    assertTrue(NS.SetByPath("container.name", "Renamed", 1))
    mocks.__fireTimers()
    -- red under: the receiver calling RequestApply for effect="visibility" rows
    -- red under: the container.name row without effect = "none"
    assertEqual(countLines(lines, "will apply"), 0, "nothing was held, so nothing is announced")
    assertEqual(NS.Database.FindContainer(1).name, "Renamed")
    assertFalse(NS.State.preview, "locking ended preview")
end)

test("manager: a master visibility row hides containers at once, with no apply pass", function()
    local NS = fresh()
    local CM = NS.ContainerManager
    local requests = countRequests(CM)
    assertTrue(NS.SetByPath("visibility", "never"))
    for id, inst in pairs(CM.instances) do
        assertFalse(inst.engine.__enabled, "container " .. id .. " hidden in the same frame")
    end
    -- red under: the receiver calling RequestApply for effect="visibility" rows
    assertEqual(requests[1], 0, "a visibility row queues no apply")
    assertEqual(CM.FlushPending(), 0)
end)

test("manager: a deferral out of combat while auras are secret names the restriction, and combat inside it adds no line", function()
    local NS, mocks = fresh()
    local lines = chat(mocks)
    mocks.__aurasSecret, mocks.__lockdown = true, false
    NS.ContainerManager.RequestApply()
    mocks.__fireTimers()
    assertEqual(countLines(lines, SECRET_LINE), 1, "the restriction is named")
    assertEqual(countLines(lines, COMBAT_LINE), 0, "combat is not blamed out of combat")
    mocks.__lockdown = true
    NS.ContainerManager.RequestApply()
    mocks.__fireTimers()
    -- red under: noteDeferred printing on every reason change
    assertEqual(countLines(lines, "will apply"), 1, "the restriction wording already covers combat")
end)

test("manager: the regen edge never escalates the notice; a later held request does", function()
    local NS, mocks = fresh()
    local CM = NS.ContainerManager
    local lines = chat(mocks)
    mocks.__lockdown = true
    CM.RequestApply()
    mocks.__fireTimers()
    assertEqual(countLines(lines, COMBAT_LINE), 1)
    mocks.__lockdown, mocks.__aurasSecret = false, true
    NS.addon:OnCombatChanged("PLAYER_REGEN_ENABLED")
    -- red under: noteDeferred escalating on the regen edge
    assertEqual(countLines(lines, "will apply"), 1, "a momentary secret reading at the regen edge says nothing")
    CM.RequestApply()
    mocks.__fireTimers()
    assertEqual(countLines(lines, SECRET_LINE), 1, "a request still held after combat names the restriction")
    assertEqual(countLines(lines, "will apply"), 2)
    mocks.__aurasSecret = false
    local flushed, orig = {}, CM.FlushPending
    CM.FlushPending = function(...) local n = orig(...); flushed[#flushed + 1] = n; return n end
    NS.addon:OnRestrictionChanged()
    CM.FlushPending = orig
    assertTrue((flushed[1] or 0) > 0, "the held apply runs once secrecy lifts")
    mocks.__lockdown = true
    CM.RequestApply()
    mocks.__fireTimers()
    assertEqual(countLines(lines, COMBAT_LINE), 2, "a later deferral is announced afresh")
end)

--- Count calls to `frame[method]`, still calling through. Returns a one-slot box.
local function counted(frame, method)
    local n, orig = { 0 }, frame[method]
    frame[method] = function(self, ...)
        n[1] = n[1] + 1
        return orig(self, ...)
    end
    return n
end

--- Count CreateFrame calls whose name starts with `prefix`. Installed on the mock, which the loader
--- resolves at call time.
local function spyCreate(mocks, prefix)
    local n, orig = { 0 }, mocks.CreateFrame
    mocks.CreateFrame = function(frameType, name, ...)
        if type(name) == "string" and name:sub(1, #prefix) == prefix then n[1] = n[1] + 1 end
        return orig(frameType, name, ...)
    end
    return n
end

test("manager: a container deleted under lockdown is parked — disabled, nothing hidden — and destroyed after combat", function()
    local NS, mocks = fresh()
    local CM = NS.ContainerManager
    local inst = CM.instances[2]
    local e = inst.engine
    inst.anchor:Show()
    local hides, clears = counted(inst.anchor, "Hide"), counted(inst.anchor, "ClearAllPoints")
    local engineHides = counted(e, "Hide")
    mocks.__lockdown = true
    CM.Delete(2)
    assertFalse(e.__enabled, "the engine is disabled, which is combat-legal")
    -- red under: CM.Sync destroying instead of parking under MustDefer
    assertTrue(inst.anchor:IsShown(), "the anchor is not hidden under lockdown")
    assertEqual(hides[1], 0)
    assertEqual(clears[1], 0)
    assertEqual(engineHides[1], 0)
    assertNil(CM.instances[2])
    assertTrue(CM.__retiring()[2] == inst, "parked until combat ends")
    mocks.__lockdown = false
    CM.FlushPending()
    assertTrue(hides[1] >= 1 and clears[1] >= 1, "torn down after combat")
    assertTrue(engineHides[1] >= 1)
    assertFalse(inst.anchor:IsShown())
    assertNil(next(CM.__retiring()), "nothing left parked")
end)

test("manager: a parked id that comes back before combat ends reuses its instance and draws again", function()
    local NS, mocks = fresh()
    local CM = NS.ContainerManager
    local inst = CM.instances[2]
    local e = inst.engine
    local made = spyCreate(mocks, "AuraMasterAnchor2")
    mocks.__lockdown = true
    local c2 = NS.Database.DeepCopy(NS.Database.FindContainer(2))
    CM.Delete(2)
    local p = NS.db.profile
    p.containers[2] = c2
    table.insert(p.containerOrder, 2)
    CM.Announce()
    -- red under: CM.Sync calling NS.Container.New instead of reusing retiring[id]
    assertEqual(made[1], 0, "no second AuraMasterAnchor2 global")
    assertTrue(CM.instances[2] == inst, "the parked instance is back in the registry")
    assertNil(inst.parked)
    -- red under: revive without inst:ApplyVisibility()
    assertTrue(e.__enabled, "a returning container draws again at once")
    assertNil(CM.__retiring()[2])
end)

--- Create container 4 out of lockdown, then run `leave` under lockdown: id 4 departs (the new or
--- reset profile seeds only 1-3) and must be parked, then torn down once combat ends.
local function departsUnderLockdown(leave)
    local NS, mocks = fresh()
    local CM = NS.ContainerManager
    local id = CM.Create({})
    mocks.__fireTimers()
    local inst4 = CM.instances[id]
    assertEqual(id, 4)
    assertTrue(inst4.engine ~= nil, "built out of lockdown")
    inst4.anchor:Show()
    local hides, clears = counted(inst4.anchor, "Hide"), counted(inst4.anchor, "ClearAllPoints")
    mocks.__lockdown = true
    leave(NS)
    -- red under: CM.Sync ignoring MustDefer
    assertEqual(hides[1], 0)
    assertEqual(clears[1], 0)
    assertTrue(inst4.anchor:IsShown())
    assertFalse(inst4.engine.__enabled)
    assertTrue(CM.__retiring()[4] == inst4)
    mocks.__lockdown = false
    CM.FlushPending()
    assertTrue(hides[1] >= 1 and clears[1] >= 1, "torn down after combat")
    assertNil(next(CM.__retiring()))
end

test("manager: a profile switch under lockdown parks departing containers and tears them down after combat", function()
    departsUnderLockdown(function(NS) NS.db:SetProfile("Raid") end)
end)

test("manager: a profile reset under lockdown parks departing containers and tears them down after combat", function()
    departsUnderLockdown(function(NS) NS.db:ResetProfile() end)
end)

test("manager: creating or duplicating a container in combat is refused and creates nothing", function()
    local NS, mocks = fresh()
    local CM = NS.ContainerManager
    local made = spyCreate(mocks, "AuraMasterAnchor")
    local before = #NS.Database.GetContainers()
    mocks.__lockdown = true
    local id, err, refused = CM.Create({})
    -- red under: CM.Create without its InCombatLockdown gate
    assertNil(id)
    assertTrue(type(err) == "string" and err:find("during combat", 1, true) ~= nil, tostring(err))
    assertTrue(refused)
    local dup, dupErr, dupRefused = CM.Duplicate(1)
    assertNil(dup)
    assertEqual(dupErr, err)
    assertTrue(dupRefused)
    assertEqual(#NS.Database.GetContainers(), before)
    assertEqual(made[1], 0, "no anchor frame was created")
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

--- Turn container `id`'s icon border class color on through the seam and let the apply run, so the
--- container's per-apply snapshot knows it uses a class color.
local function classColored(NS, mocks, id)
    assertTrue(NS.SetByPath("container.icons.useClassColorBorder", true, id))
    mocks.__fireTimers()
end

test("manager: a target swap under lockdown leaves the class color silently stale and re-applies after combat", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[3]   -- Target debuffs (mine)
    classColored(NS, mocks, 3)
    local lines = chat(mocks)
    local timers = #mocks.__timers
    mocks.__lockdown = true
    NS.addon:OnUnitSwap("PLAYER_TARGET_CHANGED")
    -- red under: RefreshUnit calling RequestApply under MustDefer
    assertEqual(#mocks.__timers, timers, "no apply is queued under lockdown")
    mocks.__fireTimers()
    assertEqual(#lines, 0, "and nothing is announced")
    assertTrue(inst.classStale, "the container is marked stale instead")

    local axis = inst.engine.__counts.SetFlowLayoutAxis or 0
    mocks.__lockdown = false
    NS.addon:OnCombatChanged("PLAYER_REGEN_ENABLED")
    mocks.__fireTimers()
    assertTrue((inst.engine.__counts.SetFlowLayoutAxis or 0) > axis, "container 3 was applied after combat")
    assertNil(inst.classStale)
end)

test("manager: a target swap out of combat re-applies only class-colored containers of that unit", function()
    local NS, mocks = fresh()
    local CM = NS.ContainerManager
    local other = CM.Create({ unit = "target" })
    mocks.__fireTimers()
    assertEqual(NS.Database.FindContainer(other).unit, "target")
    classColored(NS, mocks, 3)
    local asked, orig = {}, CM.RequestApply
    CM.RequestApply = function(id) asked[#asked + 1] = id; return orig(id) end
    NS.addon:OnUnitSwap("PLAYER_TARGET_CHANGED")
    CM.RequestApply = orig
    -- red under: RefreshUnit requesting an apply for every container of the unit
    assertEqual(#asked, 1, "one request, not one per target container")
    assertEqual(asked[1], 3, "for the class-colored one")
end)
