-- tests/test_anchors_drag.lua - issue #22, the drag lifecycle (DD-02): what happens between a drag's
-- start and its drop. modules/Anchors.lua's beginDrag (the widget's canDrag) lets a screen or a
-- container-attached container drag, never a frame-attached one and never in combat (D9, D11), and
-- lifts an attached anchor onto UIParent first, where it reads or under the cursor where it does not
-- ("Starting a drag"); Anchors.Place leaves a dragging anchor alone ("Holding the drag steady");
-- modules/Anchors_Snap.lua's driver reads the snap at most every 0.03s while a drag is live, and its
-- highlight and join marker show only with a candidate, hidden on Shift, combat and the drop (D3,
-- D4, D11). What the drop does (attach, detach, GC-1) is tests/test_anchors_drop.lua's.
-- Its own suite because tests/test_anchors.lua sits near layout-§1's 1500-line cap.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local BS = dofile("tests/border_strips.lua")
local HR = dofile("tests/handle_recorder.lua")
local newRegion = dofile("tests/region_recorder.lua")

--- Plant a rect on `frame`, in its own units at effective scale `scale` (1 when nil).
local function plant(frame, l, b, r, t, scale)
    rawset(frame, "GetLeft", function() return l end)
    rawset(frame, "GetBottom", function() return b end)
    rawset(frame, "GetRight", function() return r end)
    rawset(frame, "GetTop", function() return t end)
    rawset(frame, "GetEffectiveScale", function() return scale or 1 end)
    return frame
end

--- A fresh environment with at least `n` containers, all enabled, on the screen, and shown, each
--- with its handle rebuilt under the recorder (tests/handle_recorder.lua).
local function env(n)
    local NS, mocks = fresh()
    while #NS.Database.GetContainers() < (n or 2) do NS.ContainerManager.Create({}) end
    mocks.__fireTimers()
    for _, c in ipairs(NS.Database.GetContainers()) do
        c.enabled, c.attach.mode = true, "screen"
        local inst = NS.ContainerManager.instances[c.id]
        inst.anchor:Show()
        inst.hangMode = "engine"
        HR.recordedHandle(mocks, NS, inst)
    end
    return NS, mocks
end

--- Record the anchor's moves: every StartMoving, and its points as ClearAllPoints and SetPoint
--- leave them (`anchor.__points`, the last SetPoint's arguments; `anchor.__moves`, the log in
--- order, "clear", "point" and "start").
local function recordAnchor(anchor)
    anchor.__moves = {}
    rawset(anchor, "ClearAllPoints", function(self) self.__moves[#self.__moves + 1] = "clear" end)
    rawset(anchor, "SetPoint", function(self, ...)
        self.__points = { ... }
        self.__moves[#self.__moves + 1] = "point"
    end)
    rawset(anchor, "StartMoving", function(self) self.__moves[#self.__moves + 1] = "start" end)
    rawset(anchor, "StopMovingOrSizing", function() end)
    return anchor
end

--- Make every frame created under UIParent (or under one of those) a region recorder from now on, so
--- the highlight and its marker log every call they receive. Returns a restore.
local function recordOverlays(mocks)
    local real = mocks.CreateFrame
    mocks.CreateFrame = function(kind, name, parent, ...)
        if parent and (parent == mocks.UIParent or parent.__overlay) then
            local f = newRegion()
            f.__overlay, f.__shown = true, true
            return f
        end
        return real(kind, name, parent, ...)
    end
    return function() mocks.CreateFrame = real end
end

-- ── starting a drag (D9, D11) ─────────────────────────────────────────────────────────────────

test("drag: a screen container and a container-attached one drag; a frame-attached one does not", function()
    local NS = env(2)
    local inst = NS.ContainerManager.instances[2]
    recordAnchor(inst.anchor)
    local at = NS.Database.FindContainer(2).attach
    inst.handle:__fire("OnDragStart")
    assertEqual(inst.anchor.__moves[#inst.anchor.__moves], "start", "screen")
    inst.handle:__fire("OnDragStop")
    at.mode, at.container = "container", 1
    recordAnchor(inst.anchor)
    inst.handle:__fire("OnDragStart")
    -- red under: canDrag's old screen-only gate (an attached container could not be dragged at all)
    assertEqual(inst.anchor.__moves[#inst.anchor.__moves], "start", "container-attached")
    inst.handle:__fire("OnDragStop")
    -- The drop detached it (DD-03), writing container.attach whole: read the stored table again.
    at = NS.Database.FindContainer(2).attach
    at.mode, at.frame = "frame", "PlayerFrame"
    recordAnchor(inst.anchor)
    inst.handle:__fire("OnDragStart")
    -- red under: a gate that lets every attached mode through (frame-attached stays out of scope)
    assertEqual(#inst.anchor.__moves, 0, "frame-attached: nothing moves")
    assertNil(inst.dragging, "and no drag is live")
end)

test("drag: no drag starts in combat, and none leaves the container marked dragging", function()
    local NS, mocks = env(2)
    local inst = NS.ContainerManager.instances[2]
    for _, mode in ipairs({ "screen", "container" }) do
        local at = NS.Database.FindContainer(2).attach
        at.mode, at.container = mode, 1
        recordAnchor(inst.anchor)
        mocks.__lockdown = true
        inst.handle:__fire("OnDragStart")
        mocks.__lockdown = false
        -- red under: beginDrag without its lockdown check (the anchor parents an aura engine)
        assertEqual(#inst.anchor.__moves, 0, mode .. ": not lifted, not moved")
        assertNil(inst.dragging, mode)
        assertTrue(NS.Anchors.Snap.driver == nil or NS.Anchors.Snap.driver:GetScript("OnUpdate") == nil,
            mode .. ": no driver armed")
    end
end)

test("drag: a container-attached anchor is lifted onto UIParent where it reads, before it moves", function()
    local NS, mocks = env(2)
    local inst = NS.ContainerManager.instances[2]
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1
    plant(inst.anchor, 140.5, 220, 160.5, 240, 0.8)
    recordAnchor(inst.anchor)
    inst.handle:__fire("OnDragStart")
    local p = inst.anchor.__points
    -- red under: no lift (the move starts from the parent's possibly secret geometry)
    assertTrue(p ~= nil, "re-anchored")
    assertEqual(p[1], "BOTTOMLEFT")
    assertTrue(p[2] == mocks.UIParent, "onto UIParent")
    assertEqual(p[3], "BOTTOMLEFT")
    -- red under: offsets converted by the scale (the edges are read in the anchor's own units)
    assertEqual(p[4] .. "," .. p[5], "140.5,220", "where it is: it does not move")
    assertEqual(table.concat(inst.anchor.__moves, ","), "clear,point,start", "lifted before StartMoving")
    assertTrue(inst.dragging == true, "the drag is live")
end)

test("drag: a container-attached anchor whose rect reads secret is centered under the cursor", function()
    local SECRET = 41.5
    local NS, mocks = env(2)
    mocks.issecretvalue = function(v) return v == SECRET end
    mocks.GetCursorPosition = function() return 300, 150 end
    local inst = NS.ContainerManager.instances[2]
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1
    plant(inst.anchor, SECRET, 220, 160, 240, 1.5)
    recordAnchor(inst.anchor)
    -- red under: no guard on the read (arithmetic on, or an anchor point at, a secret offset)
    inst.handle:__fire("OnDragStart")
    local p = inst.anchor.__points
    assertEqual(p[1], "CENTER")
    assertTrue(p[2] == mocks.UIParent)
    assertEqual(p[3], "BOTTOMLEFT")
    -- red under: the cursor's screen units used as the anchor's own (not over its effective scale)
    assertEqual(p[4] .. "," .. p[5], "200,100")
end)

test("drag: a screen container is not re-anchored at the start; it already hangs from UIParent", function()
    local NS = env(2)
    local inst = NS.ContainerManager.instances[2]
    plant(inst.anchor, 10, 20, 30, 40)
    recordAnchor(inst.anchor)
    inst.handle:__fire("OnDragStart")
    -- red under: a lift for every mode (a screen container's stored point is rewritten to BOTTOMLEFT)
    assertEqual(table.concat(inst.anchor.__moves, ","), "start")
    assertTrue(inst.dragging == true)
end)

-- ── holding the drag steady ───────────────────────────────────────────────────────────────────

test("drag: Place leaves a dragging anchor where the drag has it, and answers how it was placed", function()
    local NS = env(2)
    local inst = NS.ContainerManager.instances[2]
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1
    NS.Anchors.Place(inst)
    inst.placedAs = "container"
    recordAnchor(inst.anchor)
    inst.dragging = true
    -- red under: no dragging guard in Place (a visibility pass yanks the anchor back to its parent)
    assertEqual(NS.Anchors.Place(inst), "container", "the mode it was placed in")
    assertEqual(#inst.anchor.__moves, 0, "its points are not touched")
    NS.Anchors.PlaceAttached(NS.ContainerManager.instances[1])
    NS.Anchors.RefreshSeam(inst)
    assertEqual(#inst.anchor.__moves, 0, "nor by a parent's re-place or a seam refresh")
    inst.placedAs = nil
    assertEqual(NS.Anchors.Place(inst), "screen", "never placed: screen")
    inst.dragging = nil
    NS.Anchors.Place(inst)
    assertTrue(#inst.anchor.__moves > 0, "the drag over, it is placed again")
end)

-- ── the driver ────────────────────────────────────────────────────────────────────────────────

test("drag: the driver runs only while a drag is live, at most every 0.03s, and is cleared at the drop", function()
    local NS = env(2)
    local inst = NS.ContainerManager.instances[2]
    recordAnchor(inst.anchor)
    local Snap = NS.Anchors.Snap
    local finds, find = 0, Snap.Find
    Snap.Find = function(...)
        finds = finds + 1
        return find(...)
    end
    assertNil(Snap.driver, "no drag yet, no driver frame")
    inst.handle:__fire("OnDragStart")
    local driver = Snap.driver
    -- red under: no driver
    assertTrue(driver ~= nil and driver:GetScript("OnUpdate") ~= nil, "armed")
    assertTrue(driver:IsShown(), "shown: an OnUpdate runs only on a shown frame")
    driver:__fire("OnUpdate", 0.01)
    driver:__fire("OnUpdate", 0.01)
    -- red under: no throttle (a snap read every frame)
    assertEqual(finds, 0, "0.02s: not yet")
    driver:__fire("OnUpdate", 0.015)
    assertEqual(finds, 1, "0.035s: one read")
    driver:__fire("OnUpdate", 0.01)
    assertEqual(finds, 1, "the clock restarts after a read")
    inst.handle:__fire("OnDragStop")
    -- red under: a drop that leaves the OnUpdate armed (a per-frame cost nothing on screen reports)
    assertNil(driver:GetScript("OnUpdate"), "cleared, not idle")
    assertFalse(driver:IsShown())
    assertNil(inst.dragging, "the drop clears dragging")
    Snap.Find = find
end)

test("drag: Shift held, or combat started, means no candidate this tick", function()
    local NS, mocks = env(2)
    local CM = NS.ContainerManager
    plant(CM.instances[1].engine, 0, 100, 100, 140)
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    inst.handle:__fire("OnDragStart")
    plant(inst.anchor, 0, 75, 20, 95)   -- 5 under 1's BOTTOMLEFT: after-start on 1
    local Snap = NS.Anchors.Snap
    assertEqual((Snap.Tick() or {}).id, 1, "in range")
    mocks.__shift = true
    -- red under: no Shift check (D4)
    assertNil(Snap.Tick(), "Shift")
    mocks.__shift = false
    mocks.__lockdown = true
    -- red under: no lockdown check in the tick (D11)
    assertNil(Snap.Tick(), "combat")
    mocks.__lockdown = false
    assertEqual((Snap.Tick() or {}).id, 1, "back in range")
    inst.handle:__fire("OnDragStop")
    assertNil(Snap.Tick(), "no live drag")
end)

-- ── the highlight and the join marker (D3) ────────────────────────────────────────────────────

test("drag: the highlight frames the target's rect in green with a marker on the join, and hides with no candidate", function()
    local NS, mocks = env(2)
    local restore = recordOverlays(mocks)
    local CM = NS.ContainerManager
    plant(CM.instances[1].engine, 0, 100, 100, 140)
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    inst.handle:__fire("OnDragStart")
    local Snap = NS.Anchors.Snap
    plant(inst.anchor, 300, 75, 320, 95)
    Snap.Tick()
    assertTrue(Snap.highlight == nil or not Snap.highlight:IsShown(), "nothing in range: nothing shown")
    plant(inst.anchor, 0, 75, 20, 95)
    Snap.Tick()
    local hl, marker = Snap.highlight, Snap.marker
    -- red under: no highlight
    assertTrue(hl ~= nil and hl:IsShown(), "shown with a candidate")
    local p = hl:__last("SetPoint")
    assertEqual(p[1], "BOTTOMLEFT")
    assertTrue(p[2] == mocks.UIParent, "hung from UIParent, never from the target")
    assertEqual(p[3] .. " " .. p[4] .. "," .. p[5], "BOTTOMLEFT 0,100")
    assertEqual(hl:__joined("SetSize"), "100,40", "the target's rect")
    -- red under: a BackdropTemplate highlight (its size arithmetic is the secret-geometry trap)
    assertEqual(hl:__count("SetBackdrop"), 0, "no Backdrop")
    local col = NS.Constants.SNAP_COLOR
    BS.assertSolid(hl, 2, table.concat({ col.r, col.g, col.b, col.a }, ","), "the highlight's edge")
    local m = marker:__last("SetPoint")
    assertEqual(m[1], "CENTER")
    assertTrue(m[2] == mocks.UIParent)
    -- red under: the marker on the child's point, or not placed (the join is the target's BOTTOMLEFT)
    assertEqual(m[3] .. " " .. m[4] .. "," .. m[5], "BOTTOMLEFT 0,100", "on the join")
    assertEqual(marker:__joined("SetSize"), "6,6")
    plant(inst.anchor, 300, 75, 320, 95)
    Snap.Tick()
    -- red under: a highlight that stays up once the candidate leaves the radius
    assertFalse(hl:IsShown(), "out of range: hidden")
    restore()
end)

test("drag: the highlight hides on Shift, on combat and at the drop", function()
    local NS, mocks = env(2)
    local restore = recordOverlays(mocks)
    local CM = NS.ContainerManager
    plant(CM.instances[1].engine, 0, 100, 100, 140)
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    inst.handle:__fire("OnDragStart")
    plant(inst.anchor, 0, 75, 20, 95)
    local Snap = NS.Anchors.Snap
    Snap.Tick()
    local hl = Snap.highlight
    assertTrue(hl:IsShown())
    mocks.__shift = true
    Snap.Tick()
    assertFalse(hl:IsShown(), "Shift")
    mocks.__shift = false
    Snap.Tick()
    assertTrue(hl:IsShown())
    mocks.__lockdown = true
    Snap.driver:__fire("OnUpdate", 0.05)
    assertFalse(hl:IsShown(), "combat, on the driver's own tick")
    mocks.__lockdown = false
    Snap.Tick()
    assertTrue(hl:IsShown())
    inst.handle:__fire("OnDragStop")
    -- red under: a drop that leaves the highlight up
    assertFalse(hl:IsShown(), "the drop")
    restore()
end)
