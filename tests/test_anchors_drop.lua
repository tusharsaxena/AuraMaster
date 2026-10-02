-- tests/test_anchors_drop.lua - issue #22, the drop (DD-03): what modules/Anchors_Snap.lua's Snap.Drop
-- does with a drag once the player lets go. A candidate in range, and no Shift, attaches by one
-- whole-section write of container.attach (D7: the picked side's points, Automatic folded to nil, x
-- and y 0, the frame-mode keys kept), through settings/Layout.lua's NS.AttachByDrop, which asks first
-- with the AURAMASTER_ATTACH_FLOW popup when the chain the drop joins flows differently (D8, GC-1)
-- and re-places the container meanwhile. An attached container dropped with no candidate, or with
-- Shift held, detaches (D6): its position written from the drop, then container.attach with mode
-- screen and x and y 0. Combat started mid-drag attaches nothing (D11). Every outcome writes one
-- [Anchor] line. What happens between a drag's start and its drop is tests/test_anchors_drag.lua's.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local HR = dofile("tests/handle_recorder.lua")

--- Plant a rect on `frame`, in its own units at effective scale 1.
local function plant(frame, l, b, r, t)
    rawset(frame, "GetLeft", function() return l end)
    rawset(frame, "GetBottom", function() return b end)
    rawset(frame, "GetRight", function() return r end)
    rawset(frame, "GetTop", function() return t end)
    rawset(frame, "GetEffectiveScale", function() return 1 end)
    return frame
end

--- Record the anchor's points (`anchor.__placed` counts SetPoint calls, `anchor.__points` holds the
--- last one's arguments) and let it read back the point a drag left it at, BOTTOMLEFT of UIParent at
--- `x`, `y`.
local function recordAnchor(anchor, x, y)
    anchor.__placed = 0
    rawset(anchor, "ClearAllPoints", function() end)
    rawset(anchor, "SetPoint", function(self, ...)
        self.__placed = self.__placed + 1
        self.__points = { ... }
    end)
    rawset(anchor, "StartMoving", function() end)
    rawset(anchor, "StopMovingOrSizing", function() end)
    rawset(anchor, "GetPoint", function() return "BOTTOMLEFT", nil, "BOTTOMLEFT", x or 40, y or 60 end)
    return anchor
end

--- A fresh environment with at least three containers, all enabled, on the screen and shown, each
--- handle rebuilt under the recorder; container 1's engine planted at 0,100 .. 100,140 (growing
--- right and down by default), so a drop 5 under its BOTTOMLEFT is after-start on it.
local function env()
    local NS, mocks = fresh()
    while #NS.Database.GetContainers() < 3 do NS.ContainerManager.Create({}) end
    mocks.__fireTimers()
    for _, c in ipairs(NS.Database.GetContainers()) do
        c.enabled, c.attach.mode = true, "screen"
        local inst = NS.ContainerManager.instances[c.id]
        inst.anchor:Show()
        inst.hangMode = "engine"
        HR.recordedHandle(mocks, NS, inst)
    end
    plant(NS.ContainerManager.instances[1].engine, 0, 100, 100, 140)
    return NS, mocks
end

--- Container `id` takes container 1's flow as its own, so attaching it to 1 changes nothing (no GC-1).
local function sameFlow(NS, id)
    local from, to = NS.Database.FindContainer(1).layout, NS.Database.FindContainer(id).layout
    to.axis, to.growH, to.growV = from.axis, from.growH, from.growV
end

--- Container `id`'s flow made unlike container 1's, so attaching it to 1 asks first (GC-1).
local function otherFlow(NS, id)
    local from, to = NS.Database.FindContainer(1).layout, NS.Database.FindContainer(id).layout
    to.axis = (from.axis == "horizontal") and "vertical" or "horizontal"
end

--- Every CONFIG_CHANGED path, in order.
local function recordWrites(NS)
    local paths = {}
    NS.NewBusTarget():RegisterMessage(NS.MSG.CONFIG_CHANGED, function(_, p) paths[#paths + 1] = p.path end)
    return paths
end

--- Every [Anchor] line, formatted. NS.Debug is read at call time, so a replacement records them.
local function recordAnchorLines(NS)
    local lines = {}
    NS.Debug = function(tag, fmt, ...)
        if tag ~= "Anchor" then return end
        local args = { ... }
        for i = 1, select("#", ...) do args[i] = tostring(args[i]) end
        lines[#lines + 1] = fmt:format(unpack(args, 1, select("#", ...)))
    end
    return lines
end

--- Record StaticPopup_Show calls, each popup a table as the client's is (popup.data is read back).
local function recordPopups(mocks)
    local shown = {}
    mocks.StaticPopup_Show = function(which, text)
        local popup = { which = which, text = text }
        shown[#shown + 1] = popup
        return popup
    end
    return shown
end

--- Drag container `inst` and drop it with its anchor's rect at l, b, r, t.
local function dragTo(inst, l, b, r, t)
    inst.handle:__fire("OnDragStart")
    plant(inst.anchor, l, b, r, t)
    inst.handle:__fire("OnDragStop")
end

-- ── attaching (D7) ────────────────────────────────────────────────────────────────────────────

test("drop: a candidate in range attaches by one whole-section write: the side's points, x and y 0, the rest kept", function()
    local NS, mocks = env()
    sameFlow(NS, 2)
    local inst = NS.ContainerManager.instances[2]
    recordAnchor(inst.anchor)
    local at = NS.Database.FindContainer(2).attach
    at.x, at.y, at.frame, at.point = 7, -3, "PlayerFrame", "TOP"
    local popups = recordPopups(mocks)
    local writes = recordWrites(NS)
    -- 2's TOPLEFT 5 right of 1's TOPRIGHT: ahead-start on 1 (TOPLEFT on TOPRIGHT, growing right).
    inst.handle:__fire("OnDragStart")
    plant(inst.anchor, 105, 120, 125, 140)
    local hit = NS.Anchors.Snap.Find(inst)
    assertEqual(hit.id .. " " .. hit.token, "1 ahead-start", "the side the case aims at")
    local cp, rp = NS.Anchors.Snap.FoldPoints(NS.Database.FindContainer(2), 1, hit.point, hit.relPoint)
    inst.handle:__fire("OnDragStop")
    at = NS.Database.FindContainer(2).attach
    -- red under: a drop that only saves the screen position (DD-02's stop)
    assertEqual(at.mode .. " " .. tostring(at.container), "container 1", "attached to 1")
    assertEqual(tostring(at.childPoint) .. " " .. tostring(at.relPoint), tostring(cp) .. " " .. tostring(rp),
        "the picked side's pair, Automatic folded")
    assertTrue(at.relPoint ~= nil, "a side that is not Automatic stores its point")
    -- red under: the offsets kept (D10: a drop resets them)
    assertEqual(at.x .. "," .. at.y, "0,0", "x and y reset")
    assertEqual(at.frame .. " " .. at.point, "PlayerFrame TOP", "the frame-mode keys kept")
    -- red under: leaf writes (one CONFIG_CHANGED per row) or a position written too
    assertEqual(table.concat(writes, ","), "container.attach", "one whole-section write, nothing else")
    assertEqual(#popups, 0, "the same flow: nothing to ask")
end)

test("drop: on the Automatic side both points store nil (Automatic), as a fresh attach on the panel does", function()
    local NS = env()
    sameFlow(NS, 2)
    local inst = NS.ContainerManager.instances[2]
    recordAnchor(inst.anchor)
    -- 2's TOPLEFT 5 under 1's BOTTOMLEFT: after-start, Automatic growing right and down.
    dragTo(inst, 0, 75, 20, 95)
    local at = NS.Database.FindContainer(2).attach
    assertEqual(at.mode .. " " .. tostring(at.container), "container 1")
    -- red under: the absolute pair stored (it would stop following the parent's growth)
    assertNil(at.childPoint, "childPoint Automatic")
    assertNil(at.relPoint, "relPoint Automatic")
end)

test("drop: on the parent's before side the absolute pair is stored, and it places as a free pair (A2)", function()
    local NS = env()
    sameFlow(NS, 2)
    local lines = recordAnchorLines(NS)
    local inst = NS.ContainerManager.instances[2]
    recordAnchor(inst.anchor)
    -- 2's BOTTOMLEFT 5 above 1's TOPLEFT: 1's top, the side its lines start from growing down.
    dragTo(inst, 0, 145, 20, 165)
    local cfg = NS.Database.FindContainer(2)
    -- red under: the nine growth-relative sides only (nothing in range: a screen drop, "moved")
    assertEqual(cfg.attach.mode .. " " .. tostring(cfg.attach.container), "container 1", "attached to 1")
    assertEqual(tostring(cfg.attach.childPoint) .. ">" .. tostring(cfg.attach.relPoint), "BOTTOMLEFT>TOPLEFT",
        "the absolute pair, not Automatic")
    assertNil(NS.Anchors.AttachEdge(cfg), "none of the nine: free (G5)")
    assertEqual(lines[#lines], "container 2: drop: attach to 1 BOTTOMLEFT>TOPLEFT (free)")
end)

test("drop: container.attach written whole re-applies the new parent, the container and its followers", function()
    local NS, mocks = env()
    sameFlow(NS, 2)
    NS.SetByPath("container.attach", { mode = "container", container = 2 }, 3)
    mocks.__fireTimers()
    local CM = NS.ContainerManager
    local applied, real = {}, CM.RequestApply
    CM.RequestApply = function(id, ...)
        applied[#applied + 1] = tostring(id)
        return real(id, ...)
    end
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    dragTo(inst, 0, 75, 20, 95)
    CM.RequestApply = real
    table.sort(applied)
    -- red under: container.attach missing from PARENT_PATHS and FLOW_PATHS (1 and 3 never re-applied)
    assertEqual(table.concat(applied, ","), "1,2,3", "parent 1, the container, its follower 3")
end)

test("drop: a written attach places the container on its new parent at once, even while applies are held", function()
    local NS, mocks = env()
    sameFlow(NS, 2)
    local CM = NS.ContainerManager
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    -- Between pulls in a key: auras secret, no lockdown, so the drag runs and every apply waits.
    mocks.__aurasSecret = true
    dragTo(inst, 0, 75, 20, 95)
    mocks.__fireTimers()
    assertEqual(NS.Database.FindContainer(2).attach.mode, "container", "the attach is written")
    -- red under: a dropOn that leaves the placement to the apply CONFIG_CHANGED queues (held by
    -- CM.MustDefer while auras are secret, so the anchor stays loose where it was let go)
    assertEqual(inst.placedAs, "container", "placed as attached")
    local p = inst.anchor.__points or {}
    assertTrue(p[2] == CM.instances[1].engine, "hung from its new parent's engine")
    mocks.__aurasSecret = false
end)

test("drop: an attached container dropped in combat goes back on its parent when combat ends, applies held or not", function()
    local NS, mocks = env()
    local CM = NS.ContainerManager
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    inst.handle:__fire("OnDragStart")
    plant(inst.anchor, 300, 410, 320, 430)
    mocks.__lockdown = true
    inst.handle:__fire("OnDragStop")
    inst.anchor.__points = nil
    mocks.__lockdown, mocks.__aurasSecret = false, true
    NS.addon:OnCombatChanged("PLAYER_REGEN_ENABLED")
    -- red under: only the held RequestApply (still held after combat while auras stay secret)
    assertEqual(inst.placedAs, "container", "re-placed as attached")
    local p = inst.anchor.__points or {}
    assertTrue(p[2] == CM.instances[1].engine, "back on its parent's engine")
    mocks.__aurasSecret = false
end)

-- ── growth conflicts at the drop (D8, GC-1) ───────────────────────────────────────────────────

test("drop: a chain that flows differently asks with the attach popup, writes nothing and re-places the container", function()
    local NS, mocks = env()
    otherFlow(NS, 2)
    local inst = NS.ContainerManager.instances[2]
    recordAnchor(inst.anchor)
    local popups = recordPopups(mocks)
    local writes = recordWrites(NS)
    dragTo(inst, 0, 75, 20, 95)
    -- red under: AttachByDrop writing without asking (GC-1)
    assertEqual(#popups, 1, "one popup")
    assertEqual(popups[1].which, "AURAMASTER_ATTACH_FLOW")
    assertTrue(popups[1].text:find(NS.Database.FindContainer(1).name, 1, true) ~= nil, "names the target")
    assertEqual(#writes, 0, "nothing written")
    assertEqual(NS.Database.FindContainer(2).attach.mode, "screen", "still on the screen")
    -- red under: no re-place (the anchor stays where it was dropped, unattached)
    assertTrue(inst.anchor.__placed > 0, "re-placed where its settings put it")
    assertEqual(inst.placedAs, "screen")
    local data = popups[1].data
    assertEqual(data.path .. "|" .. data.id .. "|" .. data.value.mode .. "|" .. data.value.container,
        "container.attach|2|container|1", "the popup carries the section")
end)

test("drop: accepting the drop's popup writes the section; canceling it leaves everything as it was", function()
    local NS, mocks = env()
    otherFlow(NS, 2)
    local inst = NS.ContainerManager.instances[2]
    recordAnchor(inst.anchor)
    local popups = recordPopups(mocks)
    local dialog = mocks.StaticPopupDialogs.AURAMASTER_ATTACH_FLOW
    dragTo(inst, 0, 75, 20, 95)
    local before = NS.Database.FindContainer(2).position.x
    dialog.OnCancel(popups[1], popups[1].data)
    mocks.__fireTimers()
    assertEqual(NS.Database.FindContainer(2).attach.mode, "screen", "cancel: not attached")
    assertEqual(NS.Database.FindContainer(2).position.x, before, "cancel: the position untouched")
    dragTo(inst, 0, 75, 20, 95)
    -- red under: an OnAccept that writes only a leaf (the popup's data is the whole section)
    dialog.OnAccept(popups[2], popups[2].data)
    local at = NS.Database.FindContainer(2).attach
    assertEqual(at.mode .. " " .. tostring(at.container) .. " " .. at.x .. "," .. at.y, "container 1 0,0", "attached")
end)

test("drop: accepting the drop's popup after its target was deleted writes nothing and says why", function()
    local NS, mocks = env()
    otherFlow(NS, 2)
    local inst = NS.ContainerManager.instances[2]
    recordAnchor(inst.anchor)
    local popups = recordPopups(mocks)
    local chat = {}
    NS.Printf = function(fmt, ...) chat[#chat + 1] = fmt:format(...) end
    dragTo(inst, 0, 75, 20, 95)
    assertEqual(#popups, 1, "asked")
    -- The popup has no timeout: the player deletes the target (the panel, /am delete) meanwhile.
    NS.ContainerManager.Delete(1)
    mocks.__fireTimers()
    local writes = recordWrites(NS)
    mocks.StaticPopupDialogs.AURAMASTER_ATTACH_FLOW.OnAccept(popups[1], popups[1].data)
    -- red under: an OnAccept that checks only combat (mode container written on a missing target,
    -- which Place sends to a stale screen position)
    assertEqual(#writes, 0, "nothing written")
    assertEqual(NS.Database.FindContainer(2).attach.mode, "screen", "still on the screen")
    assertTrue(#chat == 1 and chat[1]:find("no longer exists", 1, true) ~= nil, "one chat line says why")
end)

test("drop: re-attaching onto the chain it already follows asks nothing, however its own flow differs", function()
    local NS, mocks = env()
    otherFlow(NS, 2)
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1
    local inst = NS.ContainerManager.instances[2]
    recordAnchor(inst.anchor)
    local popups = recordPopups(mocks)
    local chat = {}
    NS.Printf = function(fmt, ...) chat[#chat + 1] = fmt:format(...) end
    dragTo(inst, 105, 120, 125, 140)
    -- red under: GC-1 asked whenever the child's own flow differs (its flow does not change here)
    assertEqual(#popups, 0, "no popup")
    assertEqual(NS.Database.FindContainer(2).attach.relPoint, "TOPRIGHT", "the new side is stored")
    assertEqual(#chat, 0, "and no chat line: it already grew like 1")
end)

test("drop: moving along its own chain asks nothing and says nothing in chat, though the target changes", function()
    local NS, mocks = env()
    -- 3 and 2 both follow 1; 2's own stored flow differs from 1's, but it grows like 1 already.
    local c3 = NS.Database.FindContainer(3).attach
    c3.mode, c3.container = "container", 1
    otherFlow(NS, 2)
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1
    plant(NS.ContainerManager.instances[3].engine, 300, 100, 400, 140)
    local inst = NS.ContainerManager.instances[2]
    recordAnchor(inst.anchor)
    local popups = recordPopups(mocks)
    local chat = {}
    NS.Printf = function(fmt, ...) chat[#chat + 1] = fmt:format(...) end
    -- 2's TOPLEFT 5 under 3's BOTTOMLEFT: after-start on 3.
    dragTo(inst, 300, 75, 320, 95)
    assertEqual(#popups, 0, "no popup: the flow root stays 1")
    assertEqual(NS.Database.FindContainer(2).attach.container, 3, "moved onto 3")
    -- red under: confirmed = false in NS.AttachByDrop (the targetChanged chat line on a move along its
    -- own chain: FlowChangeOnAttach compares 2's own stored flow with 1's)
    assertEqual(#chat, 0, "no chat line")
end)

-- ── detaching (D6, D10) ───────────────────────────────────────────────────────────────────────

test("drop: an attached container dropped with no candidate detaches: position, then mode screen with x and y 0", function()
    local NS = env()
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container, at.x, at.y, at.relPoint = "container", 1, 4, 5, "TOPRIGHT"
    local inst = NS.ContainerManager.instances[2]
    recordAnchor(inst.anchor, 300.24, 410)
    plant(inst.anchor, 104, 125, 124, 145)   -- at rest: its TOPLEFT on 1's TOPRIGHT, nudged 4, 5
    local writes = recordWrites(NS)
    dragTo(inst, 300, 410, 320, 430)
    local cfg = NS.Database.FindContainer(2)
    -- red under: DD-02's drop (an attached container always went back to its parent)
    assertEqual(table.concat(writes, ","), "container.position,container.attach", "position first, then the attach")
    assertEqual(cfg.position.point .. " " .. cfg.position.x .. "," .. cfg.position.y, "BOTTOMLEFT 300.2,410",
        "where it was dropped")
    assertEqual(cfg.attach.mode, "screen", "detached")
    assertEqual(cfg.attach.x .. "," .. cfg.attach.y, "0,0", "x and y reset")
    assertEqual(tostring(cfg.attach.container) .. " " .. tostring(cfg.attach.relPoint), "1 TOPRIGHT",
        "the target and the points stay stored, as a mode switch leaves them")
end)

test("drop: Shift held at the drop places without attaching: a screen one moves, an attached one detaches", function()
    local NS, mocks = env()
    sameFlow(NS, 2)
    local inst = NS.ContainerManager.instances[2]
    recordAnchor(inst.anchor, 12, 75)
    inst.handle:__fire("OnDragStart")
    plant(inst.anchor, 0, 75, 20, 95)
    mocks.__shift = true
    inst.handle:__fire("OnDragStop")
    local cfg = NS.Database.FindContainer(2)
    -- red under: no Shift read at the drop (D4)
    assertEqual(cfg.attach.mode, "screen", "screen: not attached")
    assertEqual(cfg.position.x .. "," .. cfg.position.y, "12,75", "screen: its position saved")
    mocks.__shift = false
    cfg.attach.mode, cfg.attach.container = "container", 3
    -- 3 planted far from 1, so the drop is past the leeway of 2's pair on 3 (A4).
    plant(NS.ContainerManager.instances[3].engine, 300, 100, 400, 140)
    plant(inst.anchor, 300, 75, 320, 95)   -- at rest, 5 under 3's BOTTOMLEFT
    inst.handle:__fire("OnDragStart")
    plant(inst.anchor, 0, 75, 20, 95)
    mocks.__shift = true
    inst.handle:__fire("OnDragStop")
    mocks.__shift = false
    assertEqual(cfg.attach.mode, "screen", "attached, in range of 1, Shift: detached rather than attached")
end)

-- ── the detach leeway (A4) ────────────────────────────────────────────────────────────────────

test("drop: let go within the leeway, an attached container snaps back onto its parent and writes nothing", function()
    local NS = env()
    local lines = recordAnchorLines(NS)
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1
    local CM = NS.ContainerManager
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    local writes = recordWrites(NS)
    plant(inst.anchor, 0, 75, 20, 95)   -- at rest, 5 under 1's BOTTOMLEFT
    -- 2's TOPLEFT 30 under 1's BOTTOMLEFT, 25 from its rest: no pair in snap range, inside C.DETACH_RADIUS.
    dragTo(inst, 0, 50, 20, 70)
    -- red under: the old drop (no candidate: an attached container detached where it was let go)
    assertEqual(#writes, 0, "nothing written")
    assertEqual(NS.Database.FindContainer(2).attach.mode .. " " .. NS.Database.FindContainer(2).attach.container,
        "container 1", "still attached to 1")
    -- red under: a hold that leaves the anchor loose where it was let go
    assertEqual(inst.placedAs, "container", "placed back on its parent")
    local p = inst.anchor.__points or {}
    assertTrue(p[2] == CM.instances[1].engine, "hung from 1's engine again")
    assertEqual(lines[#lines], "container 2: drop: held (leeway)")
end)

test("drop: let go past the leeway, an attached container detaches where it was let go", function()
    local NS = env()
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1
    local inst = NS.ContainerManager.instances[2]
    recordAnchor(inst.anchor, 0, 10)
    plant(inst.anchor, 0, 75, 20, 95)   -- at rest, 5 under 1's BOTTOMLEFT
    local writes = recordWrites(NS)
    -- 65 below its rest (70 under 1's BOTTOMLEFT): one past the radius.
    dragTo(inst, 0, 10, 20, 30)
    -- red under: a hold with no bound, or a bound read exclusive of 65
    assertEqual(table.concat(writes, ","), "container.position,container.attach", "detached")
    assertEqual(NS.Database.FindContainer(2).attach.mode, "screen")
end)

test("drop: released where it rests, a container its settings put past the radius snaps back and writes nothing", function()
    local NS = env()
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container, at.y = "container", 1, -70
    local inst = NS.ContainerManager.instances[2]
    recordAnchor(inst.anchor)
    local writes = recordWrites(NS)
    -- Its seam gap and Y nudge put its TOPLEFT 75 under 1's BOTTOMLEFT.
    plant(inst.anchor, 0, 5, 20, 25)
    dragTo(inst, 2, 5, 22, 25)
    -- red under: the leeway measured on the bare join (75 > 64: a pick-up and release detached it)
    assertEqual(#writes, 0, "nothing written")
    assertEqual(NS.Database.FindContainer(2).attach.mode, "container", "still attached")
    assertEqual(inst.placedAs, "container", "placed back on its parent")
end)

test("drop: the release is classified again, never taken from the last tick", function()
    local NS = env()
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1
    local inst = NS.ContainerManager.instances[2]
    recordAnchor(inst.anchor, 300, 410)
    inst.handle:Show()   -- a tick cancels the drag of a strip that is not visible
    plant(inst.anchor, 0, 75, 20, 95)   -- at rest, 5 under 1's BOTTOMLEFT
    inst.handle:__fire("OnDragStart")
    plant(inst.anchor, 0, 50, 20, 70)
    assertEqual(select(2, NS.Anchors.Snap.Tick()), "hold", "the last tick held")
    plant(inst.anchor, 300, 410, 320, 430)
    inst.handle:__fire("OnDragStop")
    -- red under: a drop that acts on the driver's last state (up to 0.03s old)
    assertEqual(NS.Database.FindContainer(2).attach.mode, "screen", "detached: it was let go far away")
end)

test("drop: Shift within the leeway still snaps back; another pair in range attaches without Shift", function()
    local NS, mocks = env()
    sameFlow(NS, 2)
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1
    local inst = NS.ContainerManager.instances[2]
    recordAnchor(inst.anchor)
    local writes = recordWrites(NS)
    -- 2's TOP 5 under 1's BOTTOM: another pair of 1 in range, its current pair 40.3 away.
    inst.handle:__fire("OnDragStart")
    plant(inst.anchor, 40, 75, 60, 95)
    mocks.__shift = true
    inst.handle:__fire("OnDragStop")
    mocks.__shift = false
    -- red under: Shift suppressing the hold as well (it would detach)
    assertEqual(#writes, 0, "Shift: held, nothing written")
    assertEqual(inst.placedAs, "container")
    dragTo(inst, 40, 75, 60, 95)
    at = NS.Database.FindContainer(2).attach
    -- red under: the hold checked before another pair
    assertEqual(tostring(at.childPoint) .. ">" .. tostring(at.relPoint), "TOP>BOTTOM", "no Shift: attached by the other pair")
end)

test("drop: an attached container whose parent has no live instance detaches, with no leeway to hold it", function()
    local NS = env()
    local lines = recordAnchorLines(NS)
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 9   -- no container 9: deleted, or never built
    local inst = NS.ContainerManager.instances[2]
    recordAnchor(inst.anchor, 302, 410)
    plant(inst.anchor, 300, 410, 320, 430)
    local writes = recordWrites(NS)
    dragTo(inst, 302, 410, 322, 430)
    -- red under: a hold for a parent that is not there (it could never be dragged off it)
    assertEqual(table.concat(writes, ","), "container.position,container.attach", "detached")
    assertEqual(NS.Database.FindContainer(2).attach.mode, "screen")
    assertEqual(lines[#lines], "container 2: drop: detach")
end)

test("drop: with its parent unreadable, a release before the cursor travels C.DETACH_RADIUS snaps back", function()
    local NS, mocks = env()
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 3   -- 3's engine and anchor read nothing plain
    local inst = NS.ContainerManager.instances[2]
    recordAnchor(inst.anchor, 300, 410)
    local writes = recordWrites(NS)
    mocks.GetCursorPosition = function() return 100, 100 end
    inst.handle:__fire("OnDragStart")
    plant(inst.anchor, 300, 410, 320, 430)
    mocks.GetCursorPosition = function() return 140, 100 end
    inst.handle:__fire("OnDragStop")
    -- red under: no fallback (an unreadable parent detached at once)
    assertEqual(#writes, 0, "40 units: held")
    inst.handle:__fire("OnDragStart")
    mocks.GetCursorPosition = function() return 200, 160 end
    inst.handle:__fire("OnDragStop")
    mocks.GetCursorPosition = function() return 100, 100 end
    assertEqual(NS.Database.FindContainer(2).attach.mode, "screen", "116.6 units: detached")
end)

test("drop: a one-row parent reading secret, released where it rests, snaps back and keeps its nudge", function()
    local SECRET = 41.5
    local NS, mocks = env()
    mocks.issecretvalue = function(v) return v == SECRET end
    local CM = NS.ContainerManager
    plant(CM.instances[1].engine, SECRET, 220, 20, 240)
    plant(CM.instances[1].anchor, 0, 220, 20, 240)
    local lines = recordAnchorLines(NS)
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container, at.x, at.y = "container", 1, 7, -3
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    local writes = recordWrites(NS)
    dragTo(inst, 7, 195, 27, 215)
    -- red under: the current pair re-attached by its one-element fallback (x and y reset to 0)
    assertEqual(#writes, 0, "nothing written")
    at = NS.Database.FindContainer(2).attach
    assertEqual(at.x .. "," .. at.y, "7,-3", "the nudge kept")
    assertEqual(lines[#lines], "container 2: drop: held (leeway)")
end)

test("drop: an attached container whose drop position reads secret is not detached; it goes back to its parent", function()
    local SECRET = 77.5
    local NS, mocks = env()
    mocks.issecretvalue = function(v) return v == SECRET end
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1
    local inst = NS.ContainerManager.instances[2]
    recordAnchor(inst.anchor, SECRET, 410)
    local writes = recordWrites(NS)
    dragTo(inst, 300, 410, 320, 430)
    -- red under: a detach whose position was never stored (it would land at a stale screen spot)
    assertEqual(#writes, 0, "nothing written")
    assertEqual(NS.Database.FindContainer(2).attach.mode, "container", "still attached")
    assertEqual(inst.placedAs, "container", "re-placed on its parent")
end)

-- ── combat (D11) ──────────────────────────────────────────────────────────────────────────────

test("drop: combat started mid-drag attaches nothing; an attached one writes nothing and waits to be re-placed", function()
    local NS, mocks = env()
    sameFlow(NS, 2)
    local inst = NS.ContainerManager.instances[2]
    recordAnchor(inst.anchor, 12, 75)
    local writes = recordWrites(NS)
    inst.handle:__fire("OnDragStart")
    plant(inst.anchor, 0, 75, 20, 95)
    mocks.__lockdown = true
    inst.handle:__fire("OnDragStop")
    local cfg = NS.Database.FindContainer(2)
    -- red under: no lockdown check at the drop (an attach written and applied under lockdown)
    assertEqual(cfg.attach.mode, "screen", "screen: not attached")
    assertEqual(table.concat(writes, ","), "container.position", "screen: its position saved, as today")
    mocks.__lockdown = false
    cfg.attach.mode, cfg.attach.container = "container", 3
    local CM = NS.ContainerManager
    local applied, real = {}, CM.RequestApply
    CM.RequestApply = function(id, ...)
        applied[#applied + 1] = id
        return real(id, ...)
    end
    for i = #writes, 1, -1 do writes[i] = nil end
    inst.handle:__fire("OnDragStart")
    plant(inst.anchor, 300, 410, 320, 430)
    mocks.__lockdown = true
    inst.handle:__fire("OnDragStop")
    mocks.__lockdown = false
    CM.RequestApply = real
    -- red under: a detach under lockdown
    assertEqual(#writes, 0, "attached: nothing written")
    assertEqual(cfg.attach.mode .. " " .. cfg.attach.container, "container 3", "still attached to 3")
    -- red under: nothing asked (the anchor would hang from UIParent where it was dropped until the next apply)
    assertEqual(table.concat(applied, ","), "2", "an apply requested, which waits for combat to end")
end)

-- ── the [Anchor] lines ────────────────────────────────────────────────────────────────────────

test("drop: every outcome writes one [Anchor] line", function()
    local NS, mocks = env()
    sameFlow(NS, 2)
    local lines = recordAnchorLines(NS)
    local inst = NS.ContainerManager.instances[2]
    recordAnchor(inst.anchor)
    local function last() return lines[#lines] or "" end
    dragTo(inst, 300, 410, 320, 430)
    -- red under: a silent drop (debug-logging-§8: the log must say what the drop did)
    assertEqual(last(), "container 2: drop: moved")
    dragTo(inst, 0, 75, 20, 95)
    -- red under: the line naming the token alone (a free pair would read "nil")
    assertEqual(last(), "container 2: drop: attach to 1 TOPLEFT>BOTTOMLEFT (after-start)")
    dragTo(inst, 0, 50, 20, 70)
    -- red under: a silent snap-back
    assertEqual(last(), "container 2: drop: held (leeway)")
    dragTo(inst, 300, 410, 320, 430)
    assertEqual(last(), "container 2: drop: detach")
    inst.handle:__fire("OnDragStart")
    mocks.__lockdown = true
    inst.handle:__fire("OnDragStop")
    mocks.__lockdown = false
    assertEqual(last(), "container 2: drop: held (combat)")
    assertFalse(inst.dragging == true, "and the drag is over")
end)
