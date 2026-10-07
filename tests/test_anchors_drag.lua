-- tests/test_anchors_drag.lua - issue #22, the drag lifecycle (DD-02): what happens between a drag's
-- start and its drop. modules/Anchors.lua's beginDrag (the widget's canDrag) lets a screen or a
-- container-attached container drag, never a frame-attached one and never in combat (D9, D11), and
-- lifts an attached anchor onto UIParent first, where it reads or under the cursor where it does not
-- ("Starting a drag"); Anchors.Place leaves a dragging anchor alone ("Holding the drag steady");
-- modules/Anchors_Snap.lua's driver reads the snap at most every 0.03s while a drag is live, and its
-- highlight and join marker show only with a candidate, hidden on Shift, combat and the drop (D3,
-- D4, D11). The detach leeway on an attached container (A4) is tests/test_anchors_attach.lua's, and
-- what the drop does (attach, detach, GC-1) is tests/test_anchors_drop.lua's. The fixtures and the
-- mark's readers both drag suites use are tests/drag_helpers.lua's.
-- Its own suite because tests/test_anchors.lua sits near layout-§1's 1500-line cap.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local BS = dofile("tests/border_strips.lua")
local DH = dofile("tests/drag_helpers.lua")
local plant, env, recordAnchor, recordOverlays = DH.plant, DH.env, DH.recordAnchor, DH.recordOverlays
local stripEdge, assertEdgeOn, dotAt, lineEnd = DH.stripEdge, DH.assertEdgeOn, DH.dotAt, DH.lineEnd

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

local GOLD = "1 1,0.82,0,0.6"   -- the strip's own edge, as stripEdge reads it: 1px of the widget's gold

test("drag: the mark repaints the target strip's own edge 2px in green, never boxes its placeholder, and gives the gold back with no candidate (A6)", function()
    local NS, mocks = env(2)
    local restore = recordOverlays(mocks)
    local CM = NS.ContainerManager
    plant(CM.instances[1].engine, 0, 100, 100, 140)
    local strip = CM.instances[1].handle
    assertEqual(stripEdge(strip), GOLD, "built: the widget's own 1px gold")
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
    assertTrue(hl ~= nil and hl:IsShown(), "shown with a candidate")
    -- red under: A5's overlay (a frame of ours SetAllPoints on the strip, the strip's own edge left gold)
    assertEdgeOn(NS, mocks, strip, NS.Constants.SNAP_COLOR, "the target's strip")
    assertFalse(Snap.box:IsShown(), "no box over the placeholder")
    local m = marker:__last("SetPoint")
    assertEqual(m[1], "CENTER")
    assertTrue(m[2] == mocks.UIParent)
    -- red under: the marker on the child's point, or not placed (the join is the target's BOTTOMLEFT)
    assertEqual(m[3] .. " " .. m[4] .. "," .. m[5], "BOTTOMLEFT 0,100", "on the join")
    -- red under: the 6px marker the owner found too small (addendum A1)
    assertEqual(marker:__joined("SetSize"), "10,10")
    plant(inst.anchor, 300, 75, 320, 95)
    Snap.Tick()
    -- red under: a highlight that stays up once the candidate leaves the radius
    assertFalse(hl:IsShown(), "out of range: hidden")
    -- red under: a hide that leaves the strip's own edge in the mark's color
    assertEqual(stripEdge(strip), GOLD, "the strip's own gold is back")
    assertNil(Snap.MarkedStrip(), "and the mark holds no strip")
    restore()
end)

test("drag: the repaint moves to the new target's strip, and the old one gets its gold back, as the mark moves (A6)", function()
    local NS, mocks = env(3)
    local restore = recordOverlays(mocks)
    local CM = NS.ContainerManager
    plant(CM.instances[1].engine, 0, 100, 100, 140)
    plant(CM.instances[3].engine, 200, 100, 300, 140)
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    inst.handle:__fire("OnDragStart")
    local Snap = NS.Anchors.Snap
    local green = NS.Constants.SNAP_COLOR
    local one, three = CM.instances[1].handle, CM.instances[3].handle
    plant(inst.anchor, 0, 75, 20, 95)
    assertEqual(Snap.Tick().id, 1)
    assertEdgeOn(NS, mocks, one, green, "on 1")
    local paints = BS.strips(one)[1]:__count("SetColorTexture")
    Snap.Tick()
    -- red under: the strip repainted every tick
    assertEqual(BS.strips(one)[1]:__count("SetColorTexture"), paints, "the same target, the same color: not repainted")
    plant(inst.anchor, 200, 75, 220, 95)
    assertEqual(Snap.Tick().id, 3)
    assertEdgeOn(NS, mocks, three, green, "on 3")
    -- red under: the first target's strip left in the mark's color once the mark moved off it
    assertEqual(stripEdge(one), GOLD, "1's own gold is back")
    restore()
end)

test("drag: a target with no strip, or with its strip hidden, is boxed over its rect instead (A5, A6)", function()
    local NS, mocks = env(2)
    local restore = recordOverlays(mocks)
    local CM = NS.ContainerManager
    plant(CM.instances[1].engine, 0, 100, 100, 140)
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    inst.handle:__fire("OnDragStart")
    local Snap = NS.Anchors.Snap
    local col = NS.Constants.SNAP_COLOR
    local strip = CM.instances[1].handle
    for _, case in ipairs({ "hidden", "none" }) do
        if case == "hidden" then strip:Hide() else CM.instances[1].handle = nil end
        plant(inst.anchor, 0, 75, 20, 95)
        Snap.Tick()
        local box = Snap.box
        -- red under: a mark with no box when the target has no visible strip (the mark lost)
        assertTrue(box ~= nil and box:IsShown(), case .. ": the box shows")
        assertNil(Snap.MarkedStrip(), case .. ": no strip repainted")
        assertEqual(stripEdge(strip), GOLD, case .. ": the target's strip keeps its gold")
        local p = box:__last("SetPoint")
        assertEqual(p[1], "BOTTOMLEFT")
        assertTrue(p[2] == mocks.UIParent, case .. ": hung from UIParent, never from the target")
        assertEqual(p[3] .. " " .. p[4] .. "," .. p[5], "BOTTOMLEFT 0,100")
        assertEqual(box:__joined("SetSize"), "100,40", case .. ": the target's rect")
        -- red under: a BackdropTemplate box (its size arithmetic is the secret-geometry trap)
        assertEqual(box:__count("SetBackdrop"), 0, case .. ": no Backdrop")
        BS.assertSolid(box, 2, table.concat({ col.r, col.g, col.b, col.a }, ","), case .. ": the box's edge")
        plant(inst.anchor, 300, 75, 320, 95)
        Snap.Tick()
    end
    CM.instances[1].handle = strip
    restore()
end)

test("drag: the highlight puts a dot of the parent's size on the child's join point and a 2px line between the two (A3)", function()
    local NS, mocks = env(2)
    local restore = recordOverlays(mocks)
    local CM = NS.ContainerManager
    plant(CM.instances[1].engine, 0, 100, 100, 140)
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    inst.handle:__fire("OnDragStart")
    local Snap = NS.Anchors.Snap
    plant(inst.anchor, 3, 75, 23, 95)
    local hit = Snap.Tick()
    assertEqual(hit.point .. ">" .. hit.relPoint, "TOPLEFT>BOTTOMLEFT")
    local hl, marker, child, line = Snap.highlight, Snap.marker, Snap.childMarker, Snap.line
    -- red under: no child dot and no line (the highlight drew only the parent's marker)
    assertTrue(child ~= nil and line ~= nil, "a child dot and a line are built")
    assertEqual(dotAt(mocks, marker, "the parent's dot"), "BOTTOMLEFT 0,100", "on the target's relative point")
    -- red under: the child dot left on the parent's point, or sized apart from the parent's
    assertEqual(dotAt(mocks, child, "the child's dot"), "BOTTOMLEFT 3,95", "on the dragged anchor's own point")
    assertEqual(child:__joined("SetSize"), marker:__joined("SetSize"), "the same size as the parent's")
    assertEqual(lineEnd(mocks, line, "SetStartPoint"), "BOTTOMLEFT 0,100", "the line starts on the parent's dot")
    assertEqual(lineEnd(mocks, line, "SetEndPoint"), "BOTTOMLEFT 3,95", "and ends on the child's")
    assertEqual(line:__joined("SetThickness"), "2")
    -- red under: a part painted apart from the box (one color for all of them, A3)
    local col = NS.Constants.SNAP_COLOR
    local want = table.concat({ col.r, col.g, col.b, col.a }, ",")
    assertEqual(marker.dot:__joined("SetColorTexture"), want, "the parent's dot")
    assertEqual(child.dot:__joined("SetColorTexture"), want, "the child's dot")
    assertEqual(line:__joined("SetColorTexture"), want, "the line")
    -- red under: a dot or the line hung apart from the highlight, or shown and hidden on its own
    assertTrue(marker.__parentFrame == hl and child.__parentFrame == hl, "both dots are the highlight's children")
    assertTrue(line.parent == hl, "the line is a region of the highlight")
    for _, part in ipairs({ marker, child, line }) do
        assertEqual(part:__count("Hide") + part:__count("SetShown"), 0, "never toggled apart from the highlight")
    end
    plant(inst.anchor, 3, 145, 23, 165)
    Snap.Tick()
    -- red under: the child dot or the line kept where the last pair had them
    assertEqual(dotAt(mocks, child, "the child's dot, moved"), "BOTTOMLEFT 3,145", "follows the new pair")
    assertEqual(lineEnd(mocks, line, "SetEndPoint"), "BOTTOMLEFT 3,145")
    assertEqual(lineEnd(mocks, line, "SetStartPoint"), "BOTTOMLEFT 0,140")
    plant(inst.anchor, 300, 75, 320, 95)
    Snap.Tick()
    assertFalse(hl:IsShown(), "out of range: the box, both dots and the line go with the highlight")
    restore()
end)

test("drag: a before-side pair draws the line from the target's top to the child's bottom, as a free pair (A2, A3)", function()
    local NS, mocks = env(2)
    local restore = recordOverlays(mocks)
    local CM = NS.ContainerManager
    plant(CM.instances[1].engine, 0, 100, 100, 140)
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    inst.handle:__fire("OnDragStart")
    local Snap = NS.Anchors.Snap
    plant(inst.anchor, 40, 145, 60, 165)
    local hit = Snap.Tick()
    assertEqual(hit.point .. ">" .. hit.relPoint, "BOTTOM>TOP")
    assertNil(hit.token, "the target grows down, so its top is its before side: free")
    -- red under: the child dot or the line's far end on the target's point (the free pair's bottom)
    assertTrue(Snap.highlight:IsShown())
    assertEqual(dotAt(mocks, Snap.marker, "the parent's dot"), "BOTTOMLEFT 50,140")
    assertEqual(dotAt(mocks, Snap.childMarker, "the child's dot"), "BOTTOMLEFT 50,145")
    assertEqual(lineEnd(mocks, Snap.line, "SetStartPoint"), "BOTTOMLEFT 50,140")
    assertEqual(lineEnd(mocks, Snap.line, "SetEndPoint"), "BOTTOMLEFT 50,145")
    restore()
end)

test("drag: the dots and the line sit on the target's strip and the dragged one's own strip, never on their placeholders (A8, A10)", function()
    local NS, mocks = env(2)
    local restore = recordOverlays(mocks)
    local CM = NS.ContainerManager
    plant(CM.instances[1].engine, 0, 100, 100, 140)
    plant(CM.instances[1].handle, 0, 142, 100, 160)   -- 1's strip, above its block (it grows down)
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    inst.handle:__fire("OnDragStart")
    local Snap = NS.Anchors.Snap
    -- 2, as wide as 1, 5 over 1's strip and 25 over its block.
    plant(inst.anchor, 0, 165, 100, 185)
    local hit = Snap.Tick()
    -- red under: the target's block alone (25 past the radius: no pair, nothing shown)
    assertTrue(hit ~= nil, "in range of 1's strip")
    assertEqual(hit.side .. " " .. hit.point .. ">" .. hit.relPoint, "top BOTTOM>TOP", "centered: the middle pair")
    assertEqual(dotAt(mocks, Snap.marker, "the parent's dot"), "BOTTOMLEFT 50,160", "on the strip's top edge")
    assertEqual(dotAt(mocks, Snap.childMarker, "the child's dot"), "BOTTOMLEFT 50,165")
    -- 1's strip hidden, 2 under 1, its own strip 5 under 1's block and its anchor 25 under it.
    CM.instances[1].handle:Hide()
    plant(inst.handle, 0, 77, 100, 95)
    plant(inst.anchor, 0, 55, 100, 75)
    hit = Snap.Tick()
    -- red under: the dragged anchor's rect alone (25 past the radius)
    assertTrue(hit ~= nil, "in range by 2's own strip")
    assertEqual(hit.side .. " " .. hit.point .. ">" .. hit.relPoint, "bottom TOP>BOTTOM")
    assertEqual(dotAt(mocks, Snap.childMarker, "the child's dot"), "BOTTOMLEFT 50,95", "on its strip's top edge")
    assertEqual(lineEnd(mocks, Snap.line, "SetStartPoint"), "BOTTOMLEFT 50,100")
    assertEqual(lineEnd(mocks, Snap.line, "SetEndPoint"), "BOTTOMLEFT 50,95")
    restore()
end)

test("drag: a parent growing up whose strip sits below its block takes the dot on the strip's corner, not the block's, on its before side (A10, A11)", function()
    local NS, mocks = env(2)
    local restore = recordOverlays(mocks)
    local CM = NS.ContainerManager
    NS.Database.FindContainer(1).layout.growV = "up"
    plant(CM.instances[1].engine, 0, 100, 100, 140)
    plant(CM.instances[1].handle, 0, 82, 100, 100)   -- 1's strip, below its block (it grows up)
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    inst.handle:__fire("OnDragStart")
    local Snap = NS.Anchors.Snap
    -- 2 narrow, its strip 5 under 1's strip and its anchor under that.
    plant(inst.handle, 0, 59, 20, 77)
    plant(inst.anchor, 0, 37, 20, 57)
    local hit = Snap.Tick()
    assertEqual(hit.side .. " " .. hit.point .. ">" .. hit.relPoint .. " " .. hit.dist,
        "bottom TOPLEFT>BOTTOMLEFT 5", "1's strip's bottom, its first third")
    -- red under: the parent's dot on the block's bottom-left corner (0,100), the placeholder's
    assertEqual(dotAt(mocks, Snap.marker, "the parent's dot"), "BOTTOMLEFT 0,82", "on the strip's bottom-left corner")
    assertEqual(dotAt(mocks, Snap.childMarker, "the child's dot"), "BOTTOMLEFT 0,77", "on 2's strip's corner")
    assertEqual(lineEnd(mocks, Snap.line, "SetStartPoint"), "BOTTOMLEFT 0,82")
    assertEqual(lineEnd(mocks, Snap.line, "SetEndPoint"), "BOTTOMLEFT 0,77")
    -- 2's strip reading nothing: its anchor (37..57), 25 under 1's strip: no side.
    rawset(inst.handle, "GetLeft", function() return nil end)
    -- red under: no fallback for an unreadable strip (its nil read taken as a rect)
    assertNil(Snap.Tick(), "the anchor alone: out of range")
    Snap.EndDrag(inst)
    restore()
end)

-- Each growth: 1's block 0,100,200,140, its strip on its before side (above it growing down, below it
-- growing up) and lined up with the side its lines start from; 2's strip `child` on 1's growth side,
-- 5 off the block's far edge there and centered on its middle third; the pair, and the two dots.
local GROWTH_DOTS = {
    { grow = { "right", "down" }, strip = { 0, 142, 120, 160 }, child = { 80, 77, 120, 95 },
      pair = "bottom TOP>BOTTOM", parent = "100,100", own = "100,95" },
    { grow = { "right", "up" }, strip = { 0, 82, 120, 100 }, child = { 80, 145, 120, 163 },
      pair = "top BOTTOM>TOP", parent = "100,140", own = "100,145" },
    { grow = { "right", "down" }, strip = { 0, 142, 120, 160 }, child = { 205, 120, 225, 140 },
      pair = "right LEFT>RIGHT", parent = "200,130", own = "205,130" },
    { grow = { "left", "down" }, strip = { 80, 142, 200, 160 }, child = { -25, 120, -5, 140 },
      pair = "left RIGHT>LEFT", parent = "0,130", own = "-5,130" },
}

test("drag: the parent's dot sits on its block's far edge on the side it grows toward (A11)", function()
    for _, case in ipairs(GROWTH_DOTS) do
        local what = case.grow[1] .. "/" .. case.grow[2] .. " " .. case.pair
        local NS, mocks = env(2)
        local restore = recordOverlays(mocks)
        local CM = NS.ContainerManager
        local L = NS.Database.FindContainer(1).layout
        L.growH, L.growV = case.grow[1], case.grow[2]
        plant(CM.instances[1].engine, 0, 100, 200, 140)
        plant(CM.instances[1].handle, unpack(case.strip))
        local inst = CM.instances[2]
        recordAnchor(inst.anchor)
        inst.handle:__fire("OnDragStart")
        local Snap = NS.Anchors.Snap
        plant(inst.handle, unpack(case.child))
        plant(inst.anchor, case.child[1], case.child[2] - 22, case.child[3], case.child[2] - 2)
        local hit = Snap.Tick()
        -- red under: A10's strip alone (its edge on that side 45 or more short of the block's: out of range)
        assertTrue(hit ~= nil, what .. ": in range of the block's far edge")
        assertEqual(hit.side .. " " .. hit.point .. ">" .. hit.relPoint .. " " .. hit.dist, case.pair .. " 5", what)
        assertEqual(dotAt(mocks, Snap.marker, what), "BOTTOMLEFT " .. case.parent, what .. ": the parent's dot")
        assertEqual(dotAt(mocks, Snap.childMarker, what), "BOTTOMLEFT " .. case.own, what .. ": the child's dot")
        assertEqual(lineEnd(mocks, Snap.line, "SetStartPoint"), "BOTTOMLEFT " .. case.parent, what)
        Snap.EndDrag(inst)
        restore()
    end
end)

test("drag: the box fallback frames the target's footprint, its name label included (A8)", function()
    local NS, mocks = env(2)
    local restore = recordOverlays(mocks)
    local CM = NS.ContainerManager
    plant(CM.instances[1].engine, 0, 100, 100, 140)
    CM.instances[1].handle:Hide()
    local label = mocks.CreateFrame("Frame")
    plant(label, 0, 142, 100, 160)
    label:Show()
    CM.instances[1].label = label
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    inst.handle:__fire("OnDragStart")
    local Snap = NS.Anchors.Snap
    plant(inst.anchor, 40, 165, 60, 185)
    local hit = Snap.Tick()
    -- red under: the target's block alone (25 past the radius: no pair, no box)
    assertTrue(hit ~= nil and hit.point == "BOTTOM", "5 over 1's label")
    local p = Snap.box:__last("SetPoint")
    assertEqual(p[3] .. " " .. p[4] .. "," .. p[5], "BOTTOMLEFT 0,100")
    assertEqual(Snap.box:__joined("SetSize"), "100,60", "the block and its label")
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

-- ── a drag cut short (the strip hidden, the container destroyed) ──────────────────────────────

--- Record StopMovingOrSizing into the anchor's move log as "stop".
local function recordStop(anchor)
    rawset(anchor, "StopMovingOrSizing", function(self) self.__moves[#self.__moves + 1] = "stop" end)
end

test("drag: a strip hidden mid-drag ends the drag at the next tick, and the container goes back where its settings put it", function()
    local NS, mocks = env(2)
    local inst = NS.ContainerManager.instances[2]
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1
    recordAnchor(inst.anchor)
    recordStop(inst.anchor)
    inst.handle:__fire("OnDragStart")
    -- /am lock (or a stand-down) while the button is held: the client sends the hidden strip no
    -- OnDragStop.
    inst.handle:Hide()
    mocks.__lockdown = true
    local Snap = NS.Anchors.Snap
    assertNil(Snap.Tick(), "no candidate")
    -- red under: a cancel under lockdown (StopMovingOrSizing and Place on an anchor parenting an engine)
    assertTrue(inst.dragging == true, "in combat it waits")
    mocks.__lockdown = false
    inst.anchor.__moves = {}
    Snap.driver:__fire("OnUpdate", 0.05)
    -- red under: nothing but OnDragStop ends a drag (dragging stuck true, Place frozen for the session)
    assertNil(inst.dragging, "the drag is over")
    assertEqual(inst.anchor.__moves[1], "stop", "the anchor stops following the cursor first")
    assertEqual(inst.placedAs, "container", "re-placed on its parent")
    assertNil(Snap.driver:GetScript("OnUpdate"), "the driver cleared")
    assertEqual(NS.Database.FindContainer(2).attach.mode, "container", "nothing written: a cancel, not a drop")
end)

test("drag: a container destroyed mid-drag ends its drag and stops the driver", function()
    local NS = env(2)
    local inst = NS.ContainerManager.instances[2]
    recordAnchor(inst.anchor)
    recordStop(inst.anchor)
    inst.handle:__fire("OnDragStart")
    inst:Destroy()
    -- red under: a Destroy that leaves the drag live (the driver ticking on a dead instance)
    assertNil(inst.dragging, "not dragging")
    assertTrue(table.concat(inst.anchor.__moves, ","):find("stop", 1, true) ~= nil, "stopped moving")
    assertNil(NS.Anchors.Snap.driver:GetScript("OnUpdate"), "the driver cleared")
end)

-- ── the strip's own gold comes back on every end path (A6) ───────────────────────────────────

--- Each way a mark on container 1's strip can end, as `run(NS, mocks, inst)` with 2 (`inst`) dragged
--- onto 1 and the mark shown on 1's strip. None ticks afterwards unless its path is a tick.
local END_PATHS = {
    { "the drop", function(_, _, inst) inst.handle:__fire("OnDragStop") end },
    { "out of range", function(NS, _, inst)
        plant(inst.anchor, 300, 75, 320, 95)
        NS.Anchors.Snap.Tick()
    end },
    { "Shift (a screen drag's cancel)", function(NS, mocks)
        mocks.__shift = true
        NS.Anchors.Snap.Tick()
        mocks.__shift = false
    end },
    { "combat, on the driver's own tick", function(NS, mocks)
        mocks.__lockdown = true
        NS.Anchors.Snap.driver:__fire("OnUpdate", 0.05)
        mocks.__lockdown = false
    end },
    { "the dragged strip hidden mid-drag", function(NS, _, inst)
        inst.handle:Hide()
        NS.Anchors.Snap.Tick()
    end },
    { "the target's strip hidden mid-drag", function(NS)
        NS.ContainerManager.instances[1].handle:Hide()
        NS.Anchors.Snap.Tick()
    end },
    { "the dragged container destroyed", function(_, _, inst) inst:Destroy() end },
    -- No tick follows: Destroy alone must give the gold back, since a destroyed instance is kept
    -- dormant and comes back under its id with the same strip.
    { "the target destroyed", function(NS) NS.ContainerManager.instances[1]:Destroy() end },
    -- A switch keeps the instances under ids both profiles hold, so the mark stays until the apply
    -- the switch queues has run (here it hides both strips, so the tick cancels the drag) and the driver ticks.
    { "a profile switch", function(NS, mocks)
        NS.db:SetProfile("Raid")
        mocks.__fireTimers()
        NS.Anchors.Snap.driver:__fire("OnUpdate", 0.05)
    end },
}

test("drag: the target strip's own gold comes back on every path the mark ends by (A6)", function()
    for _, path in ipairs(END_PATHS) do
        local what, run = path[1], path[2]
        local NS, mocks = env(2)
        local restore = recordOverlays(mocks)
        local CM = NS.ContainerManager
        plant(CM.instances[1].engine, 0, 100, 100, 140)
        local strip = CM.instances[1].handle
        local inst = CM.instances[2]
        recordAnchor(inst.anchor)
        inst.handle:__fire("OnDragStart")
        plant(inst.anchor, 0, 75, 20, 95)
        NS.Anchors.Snap.Tick()
        assertEdgeOn(NS, mocks, strip, NS.Constants.SNAP_COLOR, what .. ": marked first")
        run(NS, mocks, inst)
        -- red under: a path that hides the mark (or drops the target) without restoring the strip's
        -- own edge, and for "the target destroyed" a Destroy with no Snap.ReleaseStrip call
        assertEqual(stripEdge(strip), GOLD, what .. ": the strip's own gold is back")
        assertNil(NS.Anchors.Snap.MarkedStrip(), what .. ": the mark holds no strip")
        restore()
    end
end)
