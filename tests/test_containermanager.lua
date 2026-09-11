-- tests/test_containermanager.lua — modules/ContainerManager.lua: the registry's write side, the
-- coalesced apply and the combat / secrecy deferral.

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

test("manager: CopyFrom is all or nothing — a corrupt later section stores and announces nothing", function()
    local NS = fresh()
    local src, dst = NS.Database.FindContainer(2), NS.Database.FindContainer(1)
    src.bars.width = 333          -- copied before icons in "everything"
    src.icons = "garbage"         -- a section the seam refuses
    local width = dst.bars.width
    local config = countMessages(NS, NS.MSG.CONFIG_CHANGED)
    local ok, err = NS.ContainerManager.CopyFrom(2, 1)
    assertFalse(ok, "the copy is refused")
    assertTrue(type(err) == "string" and err:find("container.icons", 1, true) ~= nil, tostring(err))
    -- red under: copyThrough writing each key before every key is checked
    assertEqual(dst.bars.width, width, "an earlier section is not copied either")
    assertEqual(config[1], 0, "and nothing is announced")
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
    CM.FlushPending = function(...)
        local n = orig(...)
        flushed[#flushed + 1] = n
        return n
    end
    NS.addon:OnRestrictionChanged()
    CM.FlushPending = orig
    assertTrue((flushed[1] or 0) > 0, "the held apply runs once secrecy lifts")
    mocks.__lockdown = true
    CM.RequestApply()
    mocks.__fireTimers()
    assertEqual(countLines(lines, COMBAT_LINE), 2, "a later deferral is announced afresh")
end)

test("manager: a Blizzard-frame toggle in combat says it waits, once, and applies after combat", function()
    local NS, mocks = fresh({ before = function(m)
        m.BuffFrame, m.DebuffFrame = m.__stubFrame(), m.__stubFrame()
    end })
    local BF = NS.BlizzardFrames
    local lines = chat(mocks)
    assertTrue(NS.SetByPath("hideBlizzardBuffs", true))
    assertTrue(BF.IsHidden("BuffFrame"), "out of combat it applies at once")
    assertEqual(countLines(lines, "will apply"), 0, "and says nothing")
    mocks.__lockdown = true
    assertTrue(NS.SetByPath("hideBlizzardBuffs", false))
    assertTrue(NS.SetByPath("hideBlizzardDebuffs", true))
    mocks.__fireTimers()
    -- red under: the hideBlizzard* onChange ignoring BlizzardFrames.Apply's false
    assertEqual(countLines(lines, COMBAT_LINE), 1, "held, and said once for both toggles")
    assertTrue(BF.IsHidden("BuffFrame"), "nothing is reparented under lockdown")
    assertFalse(BF.IsHidden("DebuffFrame"))
    mocks.__lockdown = false
    NS.addon:OnCombatChanged("PLAYER_REGEN_ENABLED")
    assertFalse(BF.IsHidden("BuffFrame"), "applied once combat ends")
    assertTrue(BF.IsHidden("DebuffFrame"))
    mocks.__lockdown = true
    assertTrue(NS.SetByPath("hideBlizzardBuffs", true))
    -- red under: FlushPending clearing the notice only after a pass with work to apply
    assertEqual(countLines(lines, COMBAT_LINE), 2, "a toggle in a later fight is announced afresh")
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
        if type(name) == "string" and name:find(prefix, 1, true) == 1 then n[1] = n[1] + 1 end
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

--- Point container 1 at focus and let it build, then run `change` under lockdown. The new profile
--- also has a container 1, so the id is kept, but the instance was built for the OLD container 1. It
--- must stay parked (disabled, nothing hidden) through every visibility pass until the deferred apply
--- rebuilds it for the new container 1 (unit "player") once combat ends.
local function keptIdStaysParked(change, prepare)
    local NS, mocks = fresh()
    local CM = NS.ContainerManager
    if prepare then prepare(NS, mocks) end
    assertTrue(NS.SetByPath("container.unit", "focus", 1))
    mocks.__fireTimers()
    local inst = CM.instances[1]
    local e = inst.engine
    assertTrue(e.__enabled, "drawing for the old container 1")
    assertEqual(inst.unit, "focus")
    inst.anchor:Show()
    local hides, clears = counted(inst.anchor, "Hide"), counted(inst.anchor, "ClearAllPoints")
    local engineHides = counted(e, "Hide")
    mocks.__lockdown = true
    change(NS)
    assertTrue(CM.instances[1] == inst, "the id is kept")
    -- red under: CM.Sync leaving a kept instance live on a profile change under MustDefer
    assertFalse(e.__enabled, "the old engine does not draw under the new container's name")
    NS.addon:OnCombatChanged("PLAYER_REGEN_DISABLED")
    -- red under: ContainerClass:ShouldShow ignoring self.parked
    assertFalse(e.__enabled, "a visibility pass in combat does not re-enable it")
    assertEqual(hides[1], 0)
    assertEqual(clears[1], 0)
    assertEqual(engineHides[1], 0)
    assertTrue(inst.anchor:IsShown(), "nothing hidden under lockdown")
    mocks.__lockdown = false
    NS.addon:OnCombatChanged("PLAYER_REGEN_ENABLED")
    assertTrue(CM.instances[1] == inst)
    assertNil(inst.parked, "the deferred apply unparks it")
    assertEqual(NS.Database.FindContainer(1).unit, "player")
    assertEqual(inst.unit, "player", "rebuilt for the new container 1")
    assertTrue(inst.engine.__enabled, "and drawing again")
end

test("manager: a profile reset in combat keeps a reused id parked until the deferred apply rebuilds it", function()
    keptIdStaysParked(function(NS) NS.db:ResetProfile() end)
end)

test("manager: a profile switch in combat keeps a reused id parked until the deferred apply rebuilds it", function()
    keptIdStaysParked(function(NS) NS.db:SetProfile("Raid") end)
end)

test("manager: a profile copy in combat keeps a reused id parked until the deferred apply rebuilds it", function()
    keptIdStaysParked(function(NS) NS.db:CopyProfile("Raid") end, function(NS, mocks)
        local home = NS.db:GetCurrentProfile()
        NS.db:SetProfile("Raid")
        NS.db:SetProfile(home)
        mocks.__fireTimers()
    end)
end)

test("manager: a parked id revived by a profile change in combat stays parked until the deferred apply", function()
    local NS, mocks = fresh()
    local CM = NS.ContainerManager
    local home = NS.db:GetCurrentProfile()
    local id = CM.Create({})
    mocks.__fireTimers()
    local inst4 = CM.instances[id]
    local made = spyCreate(mocks, "AuraMasterAnchor4")
    mocks.__lockdown = true
    NS.db:SetProfile("Raid")
    assertTrue(CM.__retiring()[4] == inst4, "parked: Raid has no container 4")
    NS.db:SetProfile(home)
    assertTrue(CM.instances[4] == inst4, "revived, not rebuilt")
    assertEqual(made[1], 0)
    -- red under: revive calling ApplyVisibility with the instance unparked on a profile change
    assertFalse(inst4.engine.__enabled, "a revived engine stays disabled while its data may differ")
    mocks.__lockdown = false
    NS.addon:OnCombatChanged("PLAYER_REGEN_ENABLED")
    assertNil(inst4.parked)
    assertTrue(inst4.engine.__enabled, "drawing again after the deferred apply")
end)

test("manager: an id a later Create reuses after a profile reset while auras are secret stays parked until the deferred apply", function()
    local NS, mocks = fresh()
    local CM = NS.ContainerManager
    local id = CM.Create({})
    mocks.__fireTimers()
    assertEqual(id, 4)
    assertTrue(NS.SetByPath("container.unit", "focus", id))
    mocks.__fireTimers()
    local inst4 = CM.instances[4]
    local e = inst4.engine
    assertEqual(inst4.unit, "focus")
    assertTrue(e.__enabled, "drawing for the old container 4")
    local made = spyCreate(mocks, "AuraMasterAnchor4")
    -- Out of combat, but auras are secret (between pulls in a key): Create is allowed, applies wait.
    mocks.__aurasSecret, mocks.__lockdown = true, false
    NS.db:ResetProfile()
    assertTrue(CM.__retiring()[4] == inst4, "parked: the reset profile has no container 4")
    assertEqual(CM.Create({}), 4, "the reset counter hands id 4 out again")
    assertTrue(CM.instances[4] == inst4, "revived, not rebuilt")
    assertEqual(made[1], 0)
    assertEqual(NS.Database.FindContainer(4).unit, "player")
    -- red under: revive ignoring a profile-change park
    assertFalse(e.__enabled, "the focus engine does not draw under the new container 4")
    NS.bus:SendMessage(NS.MSG.VISIBILITY_CHANGED)
    assertFalse(e.__enabled, "a visibility pass does not re-enable it")
    mocks.__aurasSecret = false
    NS.addon:OnRestrictionChanged()
    assertTrue(CM.instances[4] == inst4)
    assertNil(inst4.parked, "the deferred apply unparks it")
    assertEqual(inst4.unit, "player", "rebuilt for the new container 4")
    assertTrue(inst4.engine.__enabled, "and drawing again")
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

test("manager: a stale class and a held change of the player's re-apply the container once after the hold", function()
    -- Both edges that end a hold run FlushPending and then ReapplyStaleClass (core/AuraMaster.lua).
    local edges = {
        { hold = "__lockdown", lift = function(NS) NS.addon:OnCombatChanged("PLAYER_REGEN_ENABLED") end },
        { hold = "__aurasSecret", lift = function(NS) NS.addon:OnRestrictionChanged() end },
    }
    for _, e in ipairs(edges) do
        local NS, mocks = fresh()
        local inst = NS.ContainerManager.instances[3]   -- Target debuffs (mine)
        classColored(NS, mocks, 3)
        mocks[e.hold] = true
        NS.addon:OnUnitSwap("PLAYER_TARGET_CHANGED")
        assertTrue(inst.classStale, e.hold .. ": the swap marks the class stale")
        assertTrue(NS.SetByPath("container.icons.width", 40, 3))   -- and the player changes a setting
        mocks.__fireTimers()
        local applies, apply = 0, inst.Apply
        rawset(inst, "Apply", function(self)
            applies = applies + 1
            return apply(self)
        end)
        mocks[e.hold] = false
        e.lift(NS)
        mocks.__fireTimers()
        -- red under: SnapshotClass leaving classStale set after the flush re-applied the container
        assertEqual(applies, 1, e.hold .. ": the flush's apply already painted the new class")
        assertNil(inst.classStale, e.hold)
    end
end)

--- A fresh environment whose target's class token is `target.token` (nil makes it an NPC), planted
--- in that environment's own mock. Everyone else is a mage.
local function freshWithTarget(token)
    local target = { token = token }
    local NS, mocks = fresh({ before = function(m)
        m.UnitClass = function(u)
            if u == "target" then return target.token and "Target", target.token end
            return "Mage", "MAGE"
        end
        m.RAID_CLASS_COLORS.PRIEST = { r = 1, g = 1, b = 1 }
    end })
    return NS, mocks, target
end

--- Spy on RequestApply around one target swap; returns the ids it was asked for.
local function requestsOnSwap(NS)
    local CM = NS.ContainerManager
    local asked, orig = {}, CM.RequestApply
    CM.RequestApply = function(id)
        asked[#asked + 1] = id
        return orig(id)
    end
    NS.addon:OnUnitSwap("PLAYER_TARGET_CHANGED")
    CM.RequestApply = orig
    return asked
end

test("manager: a target swap out of combat re-applies only class-colored containers of that unit", function()
    local NS, mocks, target = freshWithTarget("PRIEST")
    local other = NS.ContainerManager.Create({ unit = "target" })
    mocks.__fireTimers()
    assertEqual(NS.Database.FindContainer(other).unit, "target")
    classColored(NS, mocks, 3)
    target.token = "MAGE"
    local asked = requestsOnSwap(NS)
    -- red under: RefreshUnit requesting an apply for every container of the unit
    assertEqual(#asked, 1, "one request, not one per target container")
    assertEqual(asked[1], 3, "for the class-colored one")
end)

test("manager: an out-of-combat swap to a same-class target, or NPC to NPC, queues no apply", function()
    local NS, mocks, target = freshWithTarget("PRIEST")
    classColored(NS, mocks, 3)
    local timers = #mocks.__timers
    -- red under: RefreshUnit dropping the class comparison (requesting on every swap)
    assertEqual(#requestsOnSwap(NS), 0, "priest to priest")
    assertEqual(#mocks.__timers, timers, "no apply is queued")

    target.token = nil
    assertEqual(#requestsOnSwap(NS), 1, "priest to NPC is a change")
    mocks.__fireTimers()
    assertEqual(#requestsOnSwap(NS), 0, "NPC to NPC: both unresolved, nothing changed")
end)

-- The deferral notice is for the player's own changes. What the addon asks of itself (a class-swap
-- re-apply, a learned timed spell, the startup build) still waits for the same edge, silently.

test("manager: a class-changing swap queued just before combat applies after it, with no deferral notice", function()
    local NS, mocks, target = freshWithTarget("PRIEST")
    local inst = NS.ContainerManager.instances[3]   -- Target debuffs (mine)
    classColored(NS, mocks, 3)
    assertEqual(inst.classColor.r, 1, "painted for the priest")
    local lines = chat(mocks)
    target.token = "MAGE"
    NS.addon:OnUnitSwap("PLAYER_TARGET_CHANGED")   -- out of combat: the class changed, an apply is queued
    mocks.__lockdown = true                           -- and combat starts before its frame comes
    mocks.__fireTimers()
    -- red under: RefreshUnit requesting without the system flag
    assertEqual(countLines(lines, "will apply"), 0, "the player changed no setting")
    mocks.__lockdown = false
    NS.addon:OnCombatChanged("PLAYER_REGEN_ENABLED")
    assertEqual(inst.classColor.r, mocks.RAID_CLASS_COLORS.MAGE.r, "re-applied for the mage after combat")
    assertEqual(countLines(lines, "will apply"), 0)
end)

test("manager: timed spells learned just before combat apply after it, with no deferral notice", function()
    local NS, mocks = fresh()
    local lines = chat(mocks)
    NS.bus:SendMessage(NS.MSG.TIMED_SPELLS_CHANGED)   -- what a readable-state scan sends
    mocks.__lockdown = true
    mocks.__fireTimers()
    -- red under: the TIMED_SPELLS_CHANGED receiver requesting without the system flag
    assertEqual(countLines(lines, "will apply"), 0, "the player changed no setting")
    mocks.__lockdown = false
    assertTrue(NS.ContainerManager.FlushPending("regen") > 0, "the held apply runs once combat ends")
end)

test("manager: /am forgettimed in combat is the player's change, so it says it waits", function()
    local NS, mocks = fresh()
    local lines = chat(mocks)
    mocks.__lockdown = true
    NS.TimedSpells.Forget()
    mocks.__fireTimers()
    -- red under: TS.Forget announcing TIMED_SPELLS_CHANGED without its byPlayer mark
    assertEqual(countLines(lines, COMBAT_LINE), 1, "told once")
    mocks.__lockdown = false
    assertTrue(NS.ContainerManager.FlushPending("regen") > 0, "and applied once combat ends")
end)

test("manager: a player's change held beside the addon's own request is announced once", function()
    local NS, mocks = fresh()
    local lines = chat(mocks)
    mocks.__lockdown = true
    NS.bus:SendMessage(NS.MSG.TIMED_SPELLS_CHANGED)
    mocks.__fireTimers()
    assertEqual(countLines(lines, "will apply"), 0, "the addon's own request alone says nothing")
    assertTrue(NS.SetByPath("container.icons.width", 40, 1))
    NS.bus:SendMessage(NS.MSG.TIMED_SPELLS_CHANGED)   -- a system request after it, in the same frame
    mocks.__fireTimers()
    -- red under: RequestApply recording only the latest request's origin (userPending = not system)
    assertEqual(countLines(lines, COMBAT_LINE), 1, "the player's change is announced")
    NS.bus:SendMessage(NS.MSG.TIMED_SPELLS_CHANGED)
    mocks.__fireTimers()
    assertEqual(countLines(lines, "will apply"), 1, "once per stretch")
    mocks.__lockdown = false
    assertTrue(NS.ContainerManager.FlushPending("regen") > 0)
end)

test("manager: a reload in combat builds silently and applies once combat ends", function()
    local lines
    local NS, mocks = fresh({ before = function(m)
        m.__lockdown = true
        lines = chat(m)
    end })
    -- red under: CM.Init requesting its first apply without the system flag
    assertEqual(countLines(lines, "will apply"), 0, "the player changed no setting")
    mocks.__lockdown = false
    assertTrue(NS.ContainerManager.FlushPending("regen") > 0, "the startup apply runs once combat ends")
end)
