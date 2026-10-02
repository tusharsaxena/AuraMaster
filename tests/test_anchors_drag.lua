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
--- with its handle rebuilt under the recorder (tests/handle_recorder.lua) and shown, as an unlocked
--- profile shows it: a drag starts from a visible strip, and one whose strip hides is canceled.
local function env(n)
    local NS, mocks = fresh()
    while #NS.Database.GetContainers() < (n or 2) do NS.ContainerManager.Create({}) end
    mocks.__fireTimers()
    for _, c in ipairs(NS.Database.GetContainers()) do
        c.enabled, c.attach.mode = true, "screen"
        local inst = NS.ContainerManager.instances[c.id]
        inst.anchor:Show()
        inst.hangMode = "engine"
        HR.recordedHandle(mocks, NS, inst):Show()
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
--- the highlight and its marker log every call they receive, each with its parent on `__parentFrame`,
--- and each listed on `mocks.__overlays` (so a case can show none is anchored to a strip, A6).
--- Returns a restore.
local function recordOverlays(mocks)
    local real = mocks.CreateFrame
    mocks.__overlays = {}
    mocks.CreateFrame = function(kind, name, parent, ...)
        if parent and (parent == mocks.UIParent or parent.__overlay) then
            local f = newRegion()
            f.__overlay, f.__shown, f.__parentFrame = true, true, parent
            mocks.__overlays[#mocks.__overlays + 1] = f
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

--- `col` ({ r, g, b, a }) as SetColorTexture's joined arguments.
local function rgba(col) return table.concat({ col.r, col.g, col.b, col.a }, ",") end

local GOLD = "1 1,0.82,0,0.6"   -- the strip's own edge, as stripEdge reads it: 1px of the widget's gold

--- How `strip`'s OWN four edge strips (the widget's edge, painted with Style.DrawEdge on the handle)
--- were last painted, as "size r,g,b,a": GOLD is the widget's own 1px gold, "2 <color>" the mark's
--- (A6). Strips that disagree come back each listed, so a half-repainted edge fails by name.
--- @return string
local function stripEdge(strip)
    local s = BS.strips(strip)
    if #s ~= 4 then return #s .. " strips" end
    local function size(i, setter)
        local last = s[i]:__last(setter)
        return last and last[1] or "?"
    end
    local seen = {}
    for i, setter in ipairs({ "SetHeight", "SetHeight", "SetWidth", "SetWidth" }) do
        seen[i] = size(i, setter) .. " " .. (s[i]:__joined("SetColorTexture") or "?")
    end
    for i = 2, 4 do
        if seen[i] ~= seen[1] then return table.concat(seen, " | ") end
    end
    return seen[1]
end

--- Assert no frame of ours (every overlay recordOverlays made) is anchored to `strip` (A6: the client
--- voids an anchor into the restricted tree a strip hangs in, which is why A5's overlay never showed).
local function assertNothingHungOn(mocks, strip, what)
    for _, f in ipairs(mocks.__overlays or {}) do
        for _, m in ipairs({ "SetAllPoints", "SetPoint" }) do
            for _, args in ipairs(f:__calls(m)) do
                for i = 1, args.n do
                    assertTrue(args[i] ~= strip, what .. ": no frame of ours is anchored to the strip (" .. m .. ")")
                end
            end
        end
    end
end

--- Assert the mark is on strip `strip` in `col` (A6): the strip's OWN four edge strips repainted 2px in
--- the mark's color, the strip the mark says it painted, and no frame of ours hung on it.
local function assertEdgeOn(NS, mocks, strip, col, what)
    local Snap = NS.Anchors.Snap
    assertEqual(stripEdge(strip), "2 " .. rgba(col), what .. ": the strip's own edge, 2px in the mark's color")
    assertTrue(Snap.MarkedStrip and Snap.MarkedStrip() == strip, what .. ": the strip the mark painted")
    assertNil(Snap.stripEdge, what .. ": no overlay frame (A5's) is built")
    assertNothingHungOn(mocks, strip, what)
end

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

--- The last SetPoint of dot `dot` as "POINT x,y", after checking it is centered and hung from UIParent.
local function dotAt(mocks, dot, what)
    local p = dot:__last("SetPoint")
    assertTrue(p ~= nil, what .. ": placed")
    assertEqual(p[1], "CENTER", what .. ": centered")
    assertTrue(p[2] == mocks.UIParent, what .. ": hung from UIParent")
    return p[3] .. " " .. p[4] .. "," .. p[5]
end

--- One end of line `line` (`which` "SetStartPoint" or "SetEndPoint") as "POINT x,y", after checking it
--- is set against UIParent.
local function lineEnd(mocks, line, which)
    local p = line:__last(which)
    assertTrue(p ~= nil, which .. " set")
    assertTrue(p[2] == mocks.UIParent, which .. ": in UIParent units")
    return p[1] .. " " .. p[3] .. "," .. p[4]
end

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

test("drag: a parent whose strip sits below its block takes the dot on the strip's corner, not the block's (A10)", function()
    local NS, mocks = env(2)
    local restore = recordOverlays(mocks)
    local CM = NS.ContainerManager
    plant(CM.instances[1].engine, 0, 100, 100, 140)
    plant(CM.instances[1].handle, 0, 82, 100, 100)   -- 1's strip, below its block (it grows up)
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    inst.handle:__fire("OnDragStart")
    local Snap = NS.Anchors.Snap
    -- 2 narrow, its strip 5 over 1's strip (inside 1's block) and its anchor above that.
    plant(inst.handle, 0, 105, 20, 123)
    plant(inst.anchor, 0, 125, 20, 145)
    local hit = Snap.Tick()
    -- red under: A8's footprints (the two overlap by 35 on top, so the left side, 20 off, and its pair)
    assertEqual(hit.side .. " " .. hit.point .. ">" .. hit.relPoint .. " " .. hit.dist,
        "top BOTTOMLEFT>TOPLEFT 5", "1's strip's top, its first third")
    -- red under: the parent's dot on the block's top-left corner (0,140), the placeholder's
    assertEqual(dotAt(mocks, Snap.marker, "the parent's dot"), "BOTTOMLEFT 0,100", "on the strip's top-left corner")
    assertEqual(dotAt(mocks, Snap.childMarker, "the child's dot"), "BOTTOMLEFT 0,105", "on 2's strip's corner")
    assertEqual(lineEnd(mocks, Snap.line, "SetStartPoint"), "BOTTOMLEFT 0,100")
    assertEqual(lineEnd(mocks, Snap.line, "SetEndPoint"), "BOTTOMLEFT 0,105")
    -- 2's strip reading nothing: its anchor (125..145) inside 1's block, 25 over 1's strip: no side.
    rawset(inst.handle, "GetLeft", function() return nil end)
    -- red under: no fallback for an unreadable strip (its nil read taken as a rect)
    assertNil(Snap.Tick(), "the anchor alone: out of range")
    Snap.EndDrag(inst)
    restore()
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

-- ── the detach leeway on an attached container (A4) ───────────────────────────────────────────

--- Container 2 attached to container 1 (Automatic: TOPLEFT on 1's BOTTOMLEFT, 1 growing right and
--- down), 1's engine planted at 0,100 .. 100,140, 2 resting where its settings put it, `restY`
--- under 1's BOTTOMLEFT (5 when nil), the overlays recorded and 2's drag started.
--- Returns NS, mocks, 2's instance, Snap and the overlays' restore.
local function leewayDrag(n, restY)
    local NS, mocks = env(n or 2)
    local restore = recordOverlays(mocks)
    local CM = NS.ContainerManager
    plant(CM.instances[1].engine, 0, 100, 100, 140)
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    local top = 100 - (restY or 5)
    plant(inst.anchor, 0, top - 20, 20, top)
    inst.handle:__fire("OnDragStart")
    return NS, mocks, inst, NS.Anchors.Snap, restore
end

--- Assert the whole mark is painted in `col`: the edge it shows (the marked strip's own edge, or the box
--- where the target has no visible strip) with its four strips, both dots and the line.
local function assertPainted(NS, col, what)
    local Snap, want = NS.Anchors.Snap, rgba(col)
    if Snap.box:IsShown() then
        BS.assertSolid(Snap.box, 2, want, what .. ": the box")
    else
        assertEqual(stripEdge(Snap.MarkedStrip()), "2 " .. want, what .. ": the strip's own edge")
    end
    assertEqual(table.concat(Snap.marker.dot:__last("SetColorTexture"), ","), want, what .. ": the parent's dot")
    assertEqual(table.concat(Snap.childMarker.dot:__last("SetColorTexture"), ","), want, what .. ": the child's dot")
    assertEqual(table.concat(Snap.line:__last("SetColorTexture"), ","), want, what .. ": the line")
end

--- Assert the mark collapsed onto the child's dot at `x`, `y` in `col`: no parent rect read, so no box
--- and no line to show, both dots and both ends of the line on it. With `strip` (the parent's visible
--- strip) that strip's own edge is still repainted and no box shows (A5, A6); without, the box is a
--- dot's size centered there.
local function assertLoneDot(NS, mocks, x, y, col, what, strip)
    local Snap, at = NS.Anchors.Snap, "BOTTOMLEFT " .. x .. "," .. y
    assertTrue(Snap.highlight:IsShown(), what .. ": the child's dot shows")
    if strip then
        assertEdgeOn(NS, mocks, strip, col, what)
        assertFalse(Snap.box:IsShown(), what .. ": no box")
    else
        assertNil(Snap.MarkedStrip(), what .. ": no strip repainted")
        local p = Snap.box:__last("SetPoint")
        assertEqual(p[1] .. " " .. p[3] .. " " .. p[4] .. "," .. p[5], "CENTER " .. at, what .. ": the box on the dot")
        assertEqual(Snap.box:__joined("SetSize"), "10,10", what .. ": a dot's size")
    end
    assertEqual(dotAt(mocks, Snap.childMarker, what .. ": the child's dot"), at)
    assertEqual(dotAt(mocks, Snap.marker, what .. ": the parent's dot"), at)
    assertEqual(lineEnd(mocks, Snap.line, "SetStartPoint"), at, what .. ": no line")
    assertEqual(lineEnd(mocks, Snap.line, "SetEndPoint"), at, what .. ": no line")
    assertPainted(NS, col, what)
end

test("drag: held within C.DETACH_RADIUS of its current pair, green on that pair; past it, red, and green again on the way back (A4)", function()
    local NS, mocks, inst, Snap, restore = leewayDrag()
    local C = NS.Constants
    -- red under: the first leeway, 64 UIParent units (the owner, the second smoke round: far too little; A9)
    assertEqual(C.DETACH_RADIUS, 128)
    -- 2's TOPLEFT 30 under 1's BOTTOMLEFT, 25 from where it rested: out of snap range, inside the leeway.
    plant(inst.anchor, 0, 50, 20, 70)
    local pair, state = Snap.Tick()
    -- red under: the old tick (no candidate in range: nothing shown, a release detaches)
    assertEqual(state, "hold", "within the leeway")
    assertEqual(pair.id .. " " .. pair.point .. ">" .. pair.relPoint, "1 TOPLEFT>BOTTOMLEFT", "its current pair")
    assertTrue(Snap.highlight:IsShown(), "the mark is shown on it")
    assertEqual(dotAt(mocks, Snap.marker, "the parent's dot"), "BOTTOMLEFT 0,100")
    -- red under: the hold drawn as a box over the parent's placeholder, its strip left plain (A5)
    assertEdgeOn(NS, mocks, NS.ContainerManager.instances[1].handle, C.SNAP_COLOR, "hold: the parent's strip")
    assertFalse(Snap.box:IsShown(), "hold: no box")
    assertPainted(NS, C.SNAP_COLOR, "hold")
    -- Exactly 128 from where it rested holds ("at most"); 129 does not.
    plant(inst.anchor, 0, -53, 20, -33)
    assertEqual(select(2, Snap.Tick()), "hold", "128: still held")
    plant(inst.anchor, 0, -54, 20, -34)
    pair, state = Snap.Tick()
    -- red under: a hold with no bound (an attached container could never be detached)
    assertEqual(state, "detach", "129: past the radius")
    assertEqual(pair.id .. " " .. pair.point .. ">" .. pair.relPoint, "1 TOPLEFT>BOTTOMLEFT", "shown on the current pair")
    assertTrue(Snap.highlight:IsShown(), "still shown")
    -- red under: no DETACH_COLOR, or only the box repainted (the dots and the line left green)
    assertPainted(NS, C.DETACH_COLOR, "detach")
    assertEdgeOn(NS, mocks, NS.ContainerManager.instances[1].handle, C.DETACH_COLOR, "detach: the parent's strip, red")
    assertEqual(dotAt(mocks, Snap.childMarker, "the child's dot"), "BOTTOMLEFT 0,-34",
        "the child's dot on its own point of the current pair")
    plant(inst.anchor, 0, 50, 20, 70)
    Snap.Tick()
    -- red under: a paint that never goes back to green once red
    assertPainted(NS, C.SNAP_COLOR, "back within the leeway")
    restore()
end)

test("drag: the leeway runs from where the container rests, seam room and nudge included, never from the bare join (A4)", function()
    -- Its seam gap, strip and label room and a Y nudge put it 150 under 1's BOTTOMLEFT at rest.
    local NS, _, inst, Snap, restore = leewayDrag(2, 150)
    local pair, state = Snap.Tick()
    -- red under: the bare join measured (more than the radius: red the moment the drag starts)
    assertEqual(state, "hold", "at rest")
    assertEqual(pair.point .. ">" .. pair.relPoint, "TOPLEFT>BOTTOMLEFT", "on its current pair")
    plant(inst.anchor, 0, -198, 20, -178)
    assertEqual(select(2, Snap.Tick()), "hold", "128 further down: still held")
    plant(inst.anchor, 0, -199, 20, -179)
    assertEqual(select(2, Snap.Tick()), "detach", "129 further down")
    -- red under: a distance from the rest point alone (it would only grow, moving toward the parent)
    plant(inst.anchor, 0, 80, 20, 100)
    assertEqual(select(2, Snap.Tick()), "hold", "150 up, flush on its parent: its own pair, held")
    NS.Anchors.Snap.EndDrag(inst)
    restore()
end)

test("drag: another pair in snap range beats the hold, and Shift suppresses only that (A4)", function()
    local NS, mocks, inst, Snap, restore = leewayDrag()
    -- 2's TOP 5 under 1's BOTTOM; its current pair (TOPLEFT on BOTTOMLEFT) is 40.3 away, inside the leeway.
    plant(inst.anchor, 40, 75, 60, 95)
    local pair, state = Snap.Tick()
    -- red under: hold checked before another pair (the drop could never move it along its parent)
    assertEqual(state, "attach", "another pair")
    assertEqual(pair.id .. " " .. pair.point .. ">" .. pair.relPoint, "1 TOP>BOTTOM")
    assertPainted(NS, NS.Constants.SNAP_COLOR, "attach")
    mocks.__shift = true
    pair, state = Snap.Tick()
    -- red under: Shift suppressing the hold too (no mark at all, a release detaches)
    assertEqual(state, "hold", "Shift: no other pair, but still the hold")
    assertEqual(pair.point .. ">" .. pair.relPoint, "TOPLEFT>BOTTOMLEFT", "on the current pair")
    plant(inst.anchor, 300, 75, 320, 95)
    assertEqual(select(2, Snap.Tick()), "detach", "Shift, past the radius: red")
    assertPainted(NS, NS.Constants.DETACH_COLOR, "Shift, detach")
    mocks.__shift = false
    restore()
end)

test("drag: a pair no nearer than its current one does not take it, so a child let go where it sits holds (A4)", function()
    local _, _, inst, Snap, restore = leewayDrag()
    -- Its own pair Automatic's, TOPLEFT on BOTTOMLEFT; where it rested (20 wide) the pick was that
    -- pair too, so only "strictly nearer" is left to hold it. Now as wide as its parent and 5 under
    -- it: centered, the pick is the middle pair (A7), 5 away by its gap, and its own pair's two points
    -- are 5 apart: no nearer.
    plant(inst.anchor, 0, 75, 100, 95)
    local pair, state = Snap.Tick()
    -- red under: "any pair that is not the current one" (a pick-up and release re-attaches by another pair)
    assertEqual(state, "hold")
    assertEqual(pair.point .. ">" .. pair.relPoint, "TOPLEFT>BOTTOMLEFT", "its own pair")
    restore()
end)

test("drag: an equal-width child let go where it rests holds by its own pair, though its center is in the middle third; moved into another third, that pair takes it (A4, A7)", function()
    local NS, mocks = env(2)
    local restore = recordOverlays(mocks)
    local CM = NS.ContainerManager
    plant(CM.instances[1].engine, 0, 100, 100, 140)
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1   -- Automatic: TOPLEFT on BOTTOMLEFT
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    -- At rest, as wide as 1 and 5 under it, 1 to the right (the parent's engine lead taken back):
    -- its own pair's points 5.1 apart, the bottom side 5 away and its middle pair the pick.
    plant(inst.anchor, 1, 75, 101, 95)
    inst.handle:__fire("OnDragStart")
    local Snap = NS.Anchors.Snap
    local pair, state = Snap.Tick()
    -- red under: no exception for the pick where it rests (the middle pair, 5 < 5.1, re-attaches it)
    assertEqual(state, "hold", "let go where it rests")
    assertEqual(pair.point .. ">" .. pair.relPoint, "TOPLEFT>BOTTOMLEFT", "its own pair")
    -- 2 to the right, a cursor's jitter (REST_SLACK): its own pair's points 5.8 apart, the middle
    -- pair still 5 away by its gap, and still the pick where it rested.
    plant(inst.anchor, 3, 75, 103, 95)
    pair, state = Snap.Tick()
    -- red under: no slack (REST_SLACK 0: a pixel's twitch re-attaches it by its middle pair)
    assertEqual(state, "hold", "2 off where it rests: still held")
    assertEqual(pair.point .. ">" .. pair.relPoint, "TOPLEFT>BOTTOMLEFT", "its own pair")
    -- 3 to the right, past the slack: the middle pair (5) is strictly nearer than its own (6.4).
    plant(inst.anchor, 4, 75, 104, 95)
    pair, state = Snap.Tick()
    -- red under: a slack with no bound (the middle pair could never take a child once moved)
    assertEqual(state, "attach", "3 off: past the slack")
    assertEqual(pair.point .. ">" .. pair.relPoint, "TOP>BOTTOM", "the middle pair")
    plant(inst.anchor, 60, 75, 160, 95)
    pair, state = Snap.Tick()
    assertEqual(state, "attach", "its center in the last third")
    assertEqual(pair.point .. ">" .. pair.relPoint, "TOPRIGHT>BOTTOMRIGHT")
    plant(inst.anchor, 1, 75, 101, 95)
    assertEqual(select(2, Snap.Tick()), "hold", "back where it rests")
    Snap.EndDrag(inst)
    restore()
end)

test("drag: a child wider than its parent, moved off where it rests, is re-attached by the end pair its rest pick named (A4, A7)", function()
    local NS, mocks = env(2)
    local restore = recordOverlays(mocks)
    local CM = NS.ContainerManager
    plant(CM.instances[1].engine, 0, 100, 100, 140)
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1   -- Automatic: TOPLEFT on BOTTOMLEFT
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    -- 200 wide and 5 under 1: its center (100) is in the last third, so the pick where it rests is
    -- the end pair, TOPRIGHT on BOTTOMRIGHT, though it is stored by the start pair.
    plant(inst.anchor, 0, 75, 200, 95)
    inst.handle:__fire("OnDragStart")
    local Snap = NS.Anchors.Snap
    assertEqual(select(2, Snap.Tick()), "hold", "let go where it rests: its own pair")
    -- 10 to the left, its center (90) still in the last third: the end pair is 5 away by its gap,
    -- its own pair's two points 11.2 apart.
    plant(inst.anchor, -10, 75, 190, 95)
    local pair, state = Snap.Tick()
    -- red under: the rest pick never re-attaching, however far the child has moved (it held, so the
    -- end pair was out of reach of a drop)
    assertEqual(state, "attach", "moved off where it rests")
    assertEqual(pair.point .. ">" .. pair.relPoint, "TOPRIGHT>BOTTOMRIGHT", "the end pair")
    Snap.EndDrag(inst)
    restore()
end)

test("drag: a child flush under a long parent, in snap range of its own pair far from that pair's points, holds (A4, A7)", function()
    local NS, mocks = env(2)
    local restore = recordOverlays(mocks)
    local CM = NS.ContainerManager
    plant(CM.instances[1].engine, 0, 100, 600, 140)
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1   -- Automatic: TOPLEFT on BOTTOMLEFT
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    plant(inst.anchor, 0, 75, 20, 95)
    inst.handle:__fire("OnDragStart")
    local Snap = NS.Anchors.Snap
    -- 150 along, still 5 under 1: its center (160) in 1's first third (0..200), so the pick is its
    -- own pair, 5 away by its gap, while that pair's two points are 150.1 apart and 150 from where
    -- they rested, past C.DETACH_RADIUS.
    plant(inst.anchor, 150, 75, 170, 95)
    local pair, state = Snap.Tick()
    -- red under: a hit on the current pair left to the leeway (150 past it: red, a release detaches)
    assertEqual(state, "hold", "its own pair in snap range")
    assertEqual(pair.id .. " " .. pair.point .. ">" .. pair.relPoint, "1 TOPLEFT>BOTTOMLEFT")
    assertPainted(NS, NS.Constants.SNAP_COLOR, "hold")
    Snap.Drop(inst)
    assertEqual(at.mode .. " " .. tostring(at.container), "container 1", "a release snaps it back")
    restore()
end)

test("drag: the leeway is measured on the strips, the parent's and the child's own (A4, A10)", function()
    local NS, mocks = env(2)
    local restore = recordOverlays(mocks)
    local CM = NS.ContainerManager
    plant(CM.instances[1].engine, 0, 100, 100, 140)
    plant(CM.instances[1].handle, 0, 142, 100, 160)   -- 1's strip, above its block
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1   -- Automatic: TOPLEFT on BOTTOMLEFT
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    -- At rest (a Y nudge), 2's own strip under its block, far under 1.
    plant(inst.handle, 0, -420, 20, -402)
    plant(inst.anchor, 0, -400, 20, -380)
    inst.handle:__fire("OnDragStart")
    local Snap = NS.Anchors.Snap
    -- 380 up: 2's strip's TOPLEFT (0,-22) 164 under 1's strip's BOTTOMLEFT (0,142).
    plant(inst.handle, 0, -40, 20, -22)
    plant(inst.anchor, 0, -20, 20, 0)
    -- red under: A8's footprints (2's anchor top 0 to 1's block bottom 100: 100 apart, a hold)
    assertEqual(select(2, Snap.Tick()), "detach", "164 apart by the strips")
    plant(inst.handle, 0, 0, 20, 18)
    plant(inst.anchor, 0, 20, 20, 40)
    assertEqual(select(2, Snap.Tick()), "hold", "124 apart by the strips")
    -- 1's strip hidden: its block with its label, 1's BOTTOMLEFT (0,100), 82 from 2's strip.
    CM.instances[1].handle:Hide()
    plant(inst.handle, 0, -40, 20, -22)
    plant(inst.anchor, 0, -20, 20, 0)
    assertEqual(select(2, Snap.Tick()), "hold", "122 apart, 1 measured on its block")
    Snap.EndDrag(inst)
    restore()
end)

test("drag: an unreadable parent holds while the cursor has moved less than C.DETACH_RADIUS, in UIParent units (A4)", function()
    local NS, mocks = env(3)
    local restore = recordOverlays(mocks)
    local CM = NS.ContainerManager
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 3   -- 3's engine and anchor read nothing plain
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    mocks.UIParent.GetEffectiveScale = function() return 2 end
    mocks.GetCursorPosition = function() return 400, 300 end
    inst.handle:__fire("OnDragStart")
    plant(inst.anchor, 300, 410, 320, 430)
    local Snap = NS.Anchors.Snap
    mocks.GetCursorPosition = function() return 600, 300 end   -- 200 screen px: 100 UIParent units
    local pair, state = Snap.Tick()
    -- red under: no fallback (an unreadable parent detaches at once), or screen units (200 > 128)
    assertEqual(state, "hold", "100 units from the start")
    assertEqual(pair.id, 3, "the current pair's parent")
    -- red under: nothing drawn with no parent rect (a detach then never turns anything red)
    -- (its TOPLEFT, 300,430 at scale 1 under UIParent's 2: 150,215 in UIParent units)
    -- red under: the parent's strip left plain where its rect does not read (it has one: A5 still edges it)
    local strip = CM.instances[3].handle
    assertLoneDot(NS, mocks, 150, 215, NS.Constants.SNAP_COLOR, "hold", strip)
    mocks.GetCursorPosition = function() return 658, 300 end   -- 129 units
    assertEqual(select(2, Snap.Tick()), "detach", "129 units")
    assertLoneDot(NS, mocks, 150, 215, NS.Constants.DETACH_COLOR, "detach", strip)
    mocks.GetCursorPosition = function() return 100, 100 end
    restore()
end)

test("drag: a hidden parent is measured by the cursor and drawn as the child's dot alone, never at its last rect (A4)", function()
    local NS, mocks = env(2)
    local restore = recordOverlays(mocks)
    local CM = NS.ContainerManager
    -- 1 hidden: a hidden frame still answers its last layout's edges, here far from the child.
    plant(CM.instances[1].engine, 0, 400, 100, 440)
    plant(CM.instances[1].anchor, 0, 420, 20, 440)
    CM.instances[1].anchor:Hide()
    -- Its strip with it: hidden in the client as a child of the hidden anchor, hidden by hand here,
    -- since the mock's IsVisible reads a frame's own shown flag alone.
    CM.instances[1].handle:Hide()
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    plant(inst.anchor, 0, 75, 20, 95)
    mocks.GetCursorPosition = function() return 100, 100 end
    inst.handle:__fire("OnDragStart")
    local Snap = NS.Anchors.Snap
    local _, state = Snap.Tick()
    assertEqual(state, "hold", "the cursor has not moved")
    -- red under: a hidden parent's stale rect boxed (the parent's IsShown not read for the mark)
    assertLoneDot(NS, mocks, 0, 95, NS.Constants.SNAP_COLOR, "hold")
    mocks.GetCursorPosition = function() return 229, 100 end   -- 129 units
    -- red under: the hidden parent measured at its last rect (its rest vector read too: held at 0)
    assertEqual(select(2, Snap.Tick()), "detach", "129 units of cursor travel")
    assertLoneDot(NS, mocks, 0, 95, NS.Constants.DETACH_COLOR, "detach")
    mocks.GetCursorPosition = function() return 100, 100 end
    restore()
end)

test("drag: a parent whose block reads secret is measured by the cursor, never by its one-element fallback (A4)", function()
    local SECRET = 41.5
    local NS, mocks = env(2)
    mocks.issecretvalue = function(v) return v == SECRET end
    local CM = NS.ContainerManager
    local restore = recordOverlays(mocks)
    -- An engine three rows deep holding auras: its rect reads secret; its anchor, the first element, plainly.
    plant(CM.instances[1].engine, SECRET, 100, 100, 240)
    plant(CM.instances[1].anchor, 0, 220, 20, 240)
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    inst.handle:__fire("OnDragStart")
    -- Where it hangs, 5 under the block: 125 under the first element's BOTTOMLEFT.
    plant(inst.anchor, 0, 75, 20, 95)
    local _, state = NS.Anchors.Snap.Tick()
    -- red under: the current pair measured on Snap.TargetRect's anchor fallback (red at rest)
    assertEqual(state, "hold", "the cursor has not moved")
    -- red under: the mark drawn on that fallback too (the dots on the first element alone, not on
    -- the block it snaps back onto), or the parent's strip left plain (A5)
    assertLoneDot(NS, mocks, 0, 95, NS.Constants.SNAP_COLOR, "hold", CM.instances[1].handle)
    restore()
end)

test("drag: on a parent whose block reads secret, a hit on its one-element fallback never takes the current parent back (A4)", function()
    local SECRET = 41.5
    local NS, mocks = env(2)
    mocks.issecretvalue = function(v) return v == SECRET end
    local CM = NS.ContainerManager
    -- An engine one row deep holding auras: its rect reads secret; its anchor, the first element,
    -- plainly, and that element's bottom is the block's.
    plant(CM.instances[1].engine, SECRET, 220, 20, 240)
    plant(CM.instances[1].anchor, 0, 220, 20, 240)
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container, at.x, at.y = "container", 1, 7, -3
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    mocks.GetCursorPosition = function() return 100, 100 end
    inst.handle:__fire("OnDragStart")
    -- Where it rests, nudged: its TOPLEFT 8.6 from the fallback's BOTTOMLEFT, inside C.SNAP_RADIUS.
    plant(inst.anchor, 7, 195, 27, 215)
    local pair, state = NS.Anchors.Snap.Tick()
    -- red under: any hit wins while the current pair has no distance (it re-attached by its own pair,
    -- measured on the first element, and the drop wrote the section, losing the nudge)
    assertEqual(state, "hold", "its own parent's fallback is not another pair")
    assertEqual(pair.point .. ">" .. pair.relPoint, "TOPLEFT>BOTTOMLEFT", "shown on the current pair")
    -- 12 to the left, its center (5) over the fallback's first third, so the hit is its own pair; the
    -- cursor 129 units from where the drag began: the leeway's fallback decides.
    plant(inst.anchor, -5, 195, 15, 215)
    mocks.GetCursorPosition = function() return 229, 100 end
    -- red under: a hit on the current pair held with no distance read (the fallback's hit counted as
    -- the current pair, so a parent that reads secret could never be left)
    pair, state = NS.Anchors.Snap.Tick()
    assertEqual(state, "detach", "the cursor past the radius")
    assertEqual(pair.point .. ">" .. pair.relPoint, "TOPLEFT>BOTTOMLEFT", "red on the current pair")
    mocks.GetCursorPosition = function() return 100, 100 end
end)

test("drag: a screen container's drag has no hold and no red (A4)", function()
    local NS = env(2)
    local CM = NS.ContainerManager
    plant(CM.instances[1].engine, 0, 100, 100, 140)
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    inst.handle:__fire("OnDragStart")
    plant(inst.anchor, 0, 50, 20, 70)
    local pair, state = NS.Anchors.Snap.Tick()
    -- red under: the leeway applied to a container that is not attached
    assertNil(pair, "nothing in snap range: nothing shown")
    assertNil(state)
end)
