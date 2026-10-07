-- tests/test_anchors_attach.lua - issue #22, the detach leeway on an attached container (A4; DD-02):
-- while a container-attached container is dragged, modules/Anchors_Snap.lua holds it on its current
-- pair, green, within C.DETACH_RADIUS of where it rests, and turns the mark red past it; another pair
-- takes it only when strictly nearer, Shift suppresses only that, and a parent that does not read
-- (hidden, or its block secret) is measured by the cursor's travel or on its strip. Peeled verbatim
-- out of tests/test_anchors_drag.lua at layout-§1's 1500-line cap (AM-04); the drag lifecycle and its
-- highlight stay there, and what the drop does is tests/test_anchors_drop.lua's. The fixtures and the
-- mark's readers both suites use are tests/drag_helpers.lua's.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local BS = dofile("tests/border_strips.lua")
local DH = dofile("tests/drag_helpers.lua")
local plant, env, recordAnchor, recordOverlays = DH.plant, DH.env, DH.recordAnchor, DH.recordOverlays
local rgba, stripEdge, assertEdgeOn, dotAt, lineEnd = DH.rgba, DH.stripEdge, DH.assertEdgeOn, DH.dotAt, DH.lineEnd

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
    -- red under: beats on the current pair's distance, not `away` (0 at rest: the middle pair, 5 < 5.1,
    -- re-attaches it)
    assertEqual(state, "hold", "let go where it rests")
    assertEqual(pair.point .. ">" .. pair.relPoint, "TOPLEFT>BOTTOMLEFT", "its own pair")
    -- 2 to the right, a cursor's jitter (REST_SLACK): its own pair's points 5.8 apart, the middle
    -- pair still 5 away by its gap, and still the pick where it rested.
    plant(inst.anchor, 3, 75, 103, 95)
    pair, state = Snap.Tick()
    -- red under: beats on the current pair's distance, not `away` (2 here: the middle pair, 5 < 5.8,
    -- re-attaches it)
    assertEqual(state, "hold", "2 off where it rests: still held")
    assertEqual(pair.point .. ">" .. pair.relPoint, "TOPLEFT>BOTTOMLEFT", "its own pair")
    -- 3 to the right, past the slack: its own pair's points 6.4 apart, but it has moved only 3 from
    -- where it rests, and the middle pair (5) is no nearer than that (beats compares `away`, A10).
    plant(inst.anchor, 4, 75, 104, 95)
    pair, state = Snap.Tick()
    -- red under: beats on the current pair's distance alone (5 < 6.4: re-attached by its middle pair)
    assertEqual(state, "hold", "3 off: moved less than the middle pair's gap")
    assertEqual(pair.point .. ">" .. pair.relPoint, "TOPLEFT>BOTTOMLEFT", "its own pair")
    -- 6 to the right: moved 6, its own pair's points 8.6 apart; the middle pair (5) is strictly nearer.
    plant(inst.anchor, 7, 75, 107, 95)
    pair, state = Snap.Tick()
    -- red under: a slack with no bound (the middle pair could never take a child once moved)
    assertEqual(state, "attach", "6 off: past the slack and the gap")
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

test("drag: a child resting a unit under its parent, nudged within REST_SLACK, is not re-attached by the pick where it rests (A4, A7)", function()
    local NS, mocks = env(2)
    local restore = recordOverlays(mocks)
    local CM = NS.ContainerManager
    plant(CM.instances[1].engine, 0, 100, 100, 140)
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1   -- Automatic: TOPLEFT on BOTTOMLEFT
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    -- At rest, as wide as 1 and 1 under it, 1 to the right: its center in the middle third, so the
    -- pick where it rests is the middle pair, 1 away by its gap.
    plant(inst.anchor, 1, 79, 101, 99)
    inst.handle:__fire("OnDragStart")
    local Snap = NS.Anchors.Snap
    assertEqual(select(2, Snap.Tick()), "hold", "let go where it rests")
    -- 2 to the right (REST_SLACK): moved 2, its own pair's points 3.2 apart, so `away` is 2 and the
    -- middle pair's gap (1) is under it; only the rest pick keeps it.
    plant(inst.anchor, 3, 79, 103, 99)
    local pair, state = Snap.Tick()
    -- red under: no exception for the pick where it rests (attach TOP>BOTTOM, 1 < 2)
    assertEqual(state, "hold", "2 off where it rests: still held")
    assertEqual(pair.point .. ">" .. pair.relPoint, "TOPLEFT>BOTTOMLEFT", "its own pair")
    -- 3 to the right, past the slack: `away` 3, and the middle pair (1) takes it.
    plant(inst.anchor, 4, 79, 104, 99)
    pair, state = Snap.Tick()
    -- red under: a slack with no bound (the rest pick could never take a child once moved)
    assertEqual(state, "attach", "3 off: past the slack")
    assertEqual(pair.point .. ">" .. pair.relPoint, "TOP>BOTTOM", "the middle pair")
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

test("drag: the leeway is measured on the parent's rect and the child's own strip (A4, A10, A11)", function()
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
    -- 370 up: 2's strip's TOPLEFT (0,-32) 132 under 1's BOTTOMLEFT (0,100), 1's strip reaching its
    -- block's bottom on the side it grows toward (A11).
    plant(inst.handle, 0, -50, 20, -32)
    plant(inst.anchor, 0, -30, 20, -10)
    -- red under: A8's own footprint (2's anchor top -10 to 1's 100: 110 apart, a hold)
    assertEqual(select(2, Snap.Tick()), "detach", "132 apart by 2's strip")
    plant(inst.handle, 0, -30, 20, -12)
    plant(inst.anchor, 0, -10, 20, 10)
    -- red under: A10's parent strip alone (its BOTTOMLEFT 0,142: 154 apart, a detach)
    assertEqual(select(2, Snap.Tick()), "hold", "112 apart, 1 measured on its block's bottom")
    -- 1's strip hidden: its block with its label, 1's BOTTOMLEFT (0,100), 122 from 2's strip.
    CM.instances[1].handle:Hide()
    plant(inst.handle, 0, -40, 20, -22)
    plant(inst.anchor, 0, -20, 20, 0)
    assertEqual(select(2, Snap.Tick()), "hold", "122 apart, 1 measured on its block")
    Snap.EndDrag(inst)
    restore()
end)

test("drag: a child let go where it rests holds, though a neighbor's strip is nearer than its own pair's points are apart (A4, A10, A11)", function()
    local NS, mocks = env(3)
    local restore = recordOverlays(mocks)
    local CM = NS.ContainerManager
    plant(CM.instances[1].engine, 0, 100, 100, 240)
    plant(CM.instances[1].handle, 0, 242, 100, 260)   -- 1's strip, above its block
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1   -- Automatic: TOPLEFT on BOTTOMLEFT
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    -- 2 at rest under 1 with a Y nudge, its strip on its block's top, 22 under 1's block; 3 on the
    -- screen beside it, 10 to its right.
    plant(inst.handle, 0, 60, 100, 78)
    plant(inst.anchor, 0, 38, 100, 58)
    plant(CM.instances[3].engine, 110, 38, 210, 58)
    plant(CM.instances[3].anchor, 110, 38, 210, 58)
    plant(CM.instances[3].handle, 110, 60, 210, 78)
    inst.handle:__fire("OnDragStart")
    local Snap = NS.Anchors.Snap
    local pair, state = Snap.Tick()
    -- red under: beats on the current pair's distance (1's BOTTOMLEFT, its block's bottom, A11, to 2's
    -- strip's TOPLEFT, 22 apart at rest: 3's pair, 10 away, re-attaches a child nobody moved)
    assertEqual(state, "hold", "let go where it rests")
    assertEqual(pair.id .. " " .. pair.point .. ">" .. pair.relPoint, "1 TOPLEFT>BOTTOMLEFT", "its own pair")
    Snap.Drop(inst)
    assertEqual(at.mode .. " " .. tostring(at.container), "container 1", "the release writes no attach to 3")
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

test("drag: a parent whose block reads secret but whose strip reads holds on its strip, two dots and a line (A4, A11; DRAG-9)", function()
    local SECRET = 41.5
    local NS, mocks = env(2)
    mocks.issecretvalue = function(v) return v == SECRET end
    local CM = NS.ContainerManager
    local restore = recordOverlays(mocks)
    -- As in game: an engine holding auras reads secret, its anchor (the first element) plainly, and
    -- its strip, hung from that anchor, reads too.
    plant(CM.instances[1].engine, SECRET, 100, 100, 240)
    plant(CM.instances[1].anchor, 0, 220, 20, 240)
    plant(CM.instances[1].handle, 0, 242, 100, 260)   -- 1's strip, above its first element
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1   -- Automatic: TOPLEFT on BOTTOMLEFT
    local inst = CM.instances[2]
    recordAnchor(inst.anchor)
    plant(inst.handle, 0, 77, 20, 95)
    plant(inst.anchor, 0, 55, 20, 75)
    inst.handle:__fire("OnDragStart")
    local Snap = NS.Anchors.Snap
    local pair, state = Snap.Tick()
    assertEqual(state, "hold", "the cursor has not moved")
    assertEqual(pair.id, 1, "the current pair's parent")
    -- Characterizes DRAG-9 (DD-16R): not the lone dot it described, which only a hidden or unreadable
    -- strip gives; 1's dot on its strip's BOTTOMLEFT, since its secret block never reaches its growth side
    assertEqual(dotAt(mocks, Snap.marker, "the parent's dot"), "BOTTOMLEFT 0,242")
    assertEqual(dotAt(mocks, Snap.childMarker, "the child's dot"), "BOTTOMLEFT 0,95")
    assertEqual(lineEnd(mocks, Snap.line, "SetStartPoint"), "BOTTOMLEFT 0,242", "the line from 1's strip")
    assertEqual(lineEnd(mocks, Snap.line, "SetEndPoint"), "BOTTOMLEFT 0,95", "the line to 2's strip")
    assertEdgeOn(NS, mocks, CM.instances[1].handle, NS.Constants.SNAP_COLOR, "hold: the parent's strip")
    assertFalse(Snap.box:IsShown(), "hold: no box")
    assertPainted(NS, NS.Constants.SNAP_COLOR, "hold")
    Snap.EndDrag(inst)
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

test("drag: on a parent whose block reads secret but whose strip reads, a nudge inside the radius holds on the stored pair (A4, A11)", function()
    local SECRET = 41.5
    local NS, mocks = env(2)
    mocks.issecretvalue = function(v) return v == SECRET end
    local CM = NS.ContainerManager
    -- In game: a one-row engine holding auras reads secret, its anchor (the first element) and the
    -- strip hung from that anchor read plainly.
    plant(CM.instances[1].engine, SECRET, 220, 100, 240)
    plant(CM.instances[1].anchor, 0, 220, 20, 240)
    plant(CM.instances[1].handle, 0, 242, 20, 260)
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1   -- Automatic: TOPLEFT on BOTTOMLEFT
    local inst = CM.instances[2]
    plant(inst.anchor, 0, 195, 60, 215)       -- 60 wide, resting 5 under the block
    recordAnchor(inst.anchor)
    mocks.GetCursorPosition = function() return 100, 100 end
    inst.handle:__fire("OnDragStart")
    local Snap = NS.Anchors.Snap
    for _, dx in ipairs({ -10, 10, 20 }) do
        plant(inst.anchor, dx, 195, 60 + dx, 215)
        local pair, state = Snap.Tick()
        -- red under: the hit measured on the strip-and-first-element rect beat the stored pair, whose
        -- distance read off the strip alone ("attach TOPRIGHT>BOTTOMRIGHT", "BOTTOMLEFT>BOTTOMRIGHT")
        assertEqual(state, "hold", "nudged " .. dx .. ": well inside C.DETACH_RADIUS")
        assertEqual(pair.id .. ":" .. pair.point .. ">" .. pair.relPoint, "1:TOPLEFT>BOTTOMLEFT",
            "nudged " .. dx .. ": on the stored pair")
    end
    inst.handle:__fire("OnDragStop")
    at = NS.Database.FindContainer(2).attach
    -- red under: the release wrote the far pair nobody picked
    assertEqual(at.mode .. ":" .. tostring(at.container), "container:1", "still on its parent")
    assertNil(at.childPoint, "no pair written: still Automatic")
    assertNil(at.relPoint, "no pair written: still Automatic")
end)

test("drag: under a parent read off its strip, a child whose anchor read secret at the start holds until the cursor moves C.SNAP_RADIUS (A4, A11)", function()
    local SECRET = 41.5
    local NS, mocks = env(2)
    mocks.issecretvalue = function(v) return v == SECRET end
    local CM = NS.ContainerManager
    -- In game: 1's one-row engine holds auras and reads secret; its strip reads. 2 hangs from that
    -- engine, so its anchor reads secret too until the lift: no rest vector is noted.
    plant(CM.instances[1].engine, SECRET, 220, 100, 240)
    plant(CM.instances[1].anchor, 0, 220, 20, 240)
    plant(CM.instances[1].handle, 0, 242, 20, 260)
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1   -- Automatic: TOPLEFT on BOTTOMLEFT
    local inst = CM.instances[2]
    plant(inst.anchor, SECRET, 195, 60, 215)
    recordAnchor(inst.anchor)
    mocks.GetCursorPosition = function() return 100, 100 end
    inst.handle:__fire("OnDragStart")
    -- The lift put its center under the cursor: 3 right of where it rested, its center over the
    -- strip's last third.
    plant(inst.anchor, 3, 205, 63, 225)
    local Snap = NS.Anchors.Snap
    local pair, state = Snap.Tick()
    -- red under: attach 1:TOPRIGHT>BOTTOMRIGHT (with no rest vector the hit's gap beat the stored
    -- pair's Euclidean distance, so a let-go after the lift wrote a pair nobody aimed at)
    assertEqual(state, "hold", "the cursor has not moved")
    assertEqual(pair.id .. ":" .. pair.point .. ">" .. pair.relPoint, "1:TOPLEFT>BOTTOMLEFT", "on the stored pair")
    mocks.GetCursorPosition = function() return 120, 100 end
    state = select(2, Snap.Tick())
    assertEqual(state, "hold", "20 units: inside C.SNAP_RADIUS")
    mocks.GetCursorPosition = function() return 124, 100 end
    -- red under: a gate at C.SNAP_RADIUS inclusive (travel >= 24: attach 1:TOPRIGHT>BOTTOMRIGHT)
    assertEqual(select(2, Snap.Tick()), "hold", "exactly C.SNAP_RADIUS: still held")
    -- Moved on purpose, its pairs compete as any other's.
    mocks.GetCursorPosition = function() return 130, 100 end
    pair, state = Snap.Tick()
    assertEqual(state, "attach", "30 units: past C.SNAP_RADIUS")
    assertEqual(pair.id .. ":" .. pair.point .. ">" .. pair.relPoint, "1:TOPRIGHT>BOTTOMRIGHT", "the pair under it")
    mocks.GetCursorPosition = function() return 100, 100 end
    inst.handle:__fire("OnDragStop")
    at = NS.Database.FindContainer(2).attach
    assertEqual(at.mode .. ":" .. tostring(at.container), "container:1", "still on its parent")
    assertNil(at.childPoint, "no pair written: still Automatic")
    assertNil(at.relPoint, "no pair written: still Automatic")
end)

test("drag: with no rest read, a neighbor in snap range takes no child until the cursor moves C.SNAP_RADIUS (A4, A11)", function()
    local SECRET = 41.5
    local NS, mocks = env(3)
    mocks.issecretvalue = function(v) return v == SECRET end
    local CM = NS.ContainerManager
    -- 1 several rows deep holding auras: its engine reads secret, its first element and its strip
    -- plainly. 2 hangs from that engine, so its anchor reads secret until the lift: no rest vector.
    plant(CM.instances[1].engine, SECRET, 100, 100, 240)
    plant(CM.instances[1].anchor, 0, 220, 20, 240)
    plant(CM.instances[1].handle, 0, 242, 100, 260)
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1   -- Automatic: TOPLEFT on BOTTOMLEFT
    local inst = CM.instances[2]
    plant(inst.anchor, SECRET, 75, 60, 95)
    recordAnchor(inst.anchor)
    -- 3 on the screen, 10 right of where the lift leaves 2.
    plant(CM.instances[3].engine, 73, 75, 173, 95)
    plant(CM.instances[3].anchor, 73, 75, 173, 95)
    plant(CM.instances[3].handle, 73, 97, 173, 115)
    mocks.GetCursorPosition = function() return 100, 100 end
    inst.handle:__fire("OnDragStart")
    plant(inst.anchor, 3, 75, 63, 95)
    local Snap = NS.Anchors.Snap
    local pair, state = Snap.Tick()
    -- red under: the travel gate on the current parent's hits alone (attach 3, 10 off, beat 1's
    -- stored pair, measured to 1's strip 147 above)
    assertEqual(state, "hold", "the cursor has not moved")
    assertEqual(pair.id .. ":" .. pair.point .. ">" .. pair.relPoint, "1:TOPLEFT>BOTTOMLEFT", "on the stored pair")
    mocks.GetCursorPosition = function() return 130, 100 end
    pair, state = Snap.Tick()
    assertEqual(state .. " " .. pair.id, "attach 3", "30 units: the neighbor competes")
    mocks.GetCursorPosition = function() return 100, 100 end
    local asked = 0
    local attachByDrop = NS.AttachByDrop
    NS.AttachByDrop = function(...) asked = asked + 1; return attachByDrop(...) end
    inst.handle:__fire("OnDragStop")
    NS.AttachByDrop = attachByDrop
    at = NS.Database.FindContainer(2).attach
    -- red under: the release took 3 (NS.AttachByDrop called, its GC-1 ask or its write), nobody aimed at it
    assertEqual(asked, 0, "a let-go offers 3 nothing")
    assertEqual(at.mode .. ":" .. tostring(at.container), "container:1", "a let-go snaps it back")
end)

test("drag: with no rect of its parent readable and no rest read, a neighbor takes no child until the cursor moves C.SNAP_RADIUS (A4)", function()
    local SECRET = 41.5
    local NS, mocks = env(3)
    mocks.issecretvalue = function(v) return v == SECRET end
    local CM = NS.ContainerManager
    -- 1 hangs from a populated grandparent's engine: its engine, anchor and strip all read secret, so
    -- the current pair has no distance; 2 hangs from 1, its anchor secret until the lift.
    plant(CM.instances[1].engine, SECRET, 100, 100, 240)
    plant(CM.instances[1].anchor, SECRET, 220, 20, 240)
    plant(CM.instances[1].handle, SECRET, 242, 100, 260)
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1
    local inst = CM.instances[2]
    plant(inst.anchor, SECRET, 75, 60, 95)
    recordAnchor(inst.anchor)
    plant(CM.instances[3].engine, 73, 75, 173, 95)
    plant(CM.instances[3].anchor, 73, 75, 173, 95)
    plant(CM.instances[3].handle, 73, 97, 173, 115)
    mocks.GetCursorPosition = function() return 100, 100 end
    inst.handle:__fire("OnDragStart")
    plant(inst.anchor, 3, 75, 63, 95)
    local Snap = NS.Anchors.Snap
    local pair, state = Snap.Tick()
    -- red under: the travel gate applied only while the current pair has a distance (attach 3)
    assertTrue(not (pair and pair.id == 3 and state == "attach"), "the cursor has not moved: 3 does not take it")
    mocks.GetCursorPosition = function() return 130, 100 end
    pair, state = Snap.Tick()
    assertEqual(state .. " " .. pair.id, "attach 3", "30 units: the neighbor competes")
end)

--- Two containers as in game with 1 holding auras: its one-row engine reads secret, its anchor (the
--- first element) and its strip (`stripR` wide, above the anchor) plainly; 2 attached to 1 by
--- Automatic (TOPLEFT on BOTTOMLEFT), 60 wide, resting 5 under the block, its drag begun with the
--- overlays recorded. Returns NS, mocks, 2's instance and the overlays' restore.
local function secretParentDrag(stripR)
    local SECRET = 41.5
    local NS, mocks = env(2)
    mocks.issecretvalue = function(v) return v == SECRET end
    local CM = NS.ContainerManager
    local restore = recordOverlays(mocks)
    plant(CM.instances[1].engine, SECRET, 220, 100, 240)
    plant(CM.instances[1].anchor, 0, 220, 20, 240)
    plant(CM.instances[1].handle, 0, 242, stripR, 260)
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1
    local inst = CM.instances[2]
    plant(inst.anchor, 0, 195, 60, 215)
    recordAnchor(inst.anchor)
    mocks.GetCursorPosition = function() return 100, 100 end
    inst.handle:__fire("OnDragStart")
    return NS, mocks, inst, restore
end

test("drag: beside a parent whose block reads secret but whose strip reads, a child re-pairs onto that side (A4, A11)", function()
    local NS, mocks, inst, restore = secretParentDrag(20)
    local Snap = NS.Anchors.Snap
    -- 4 right of 1's strip, its center over the strip's middle third: the pair is LEFT on RIGHT.
    plant(inst.anchor, 24, 238, 84, 258)
    local pair, state = Snap.Tick()
    -- red under: hold 1:TOPLEFT>BOTTOMLEFT (DD-16R refused every pair of a parent whose block reads
    -- secret, so a child could not be moved to another side of a parent holding auras)
    assertEqual(state, "attach", "a nearer pair of its own parent")
    assertEqual(pair.id .. ":" .. pair.point .. ">" .. pair.relPoint, "1:LEFT>RIGHT", "the side it is beside")
    -- The parent's dot on the strip the pair was measured on, not on the first element's fallback.
    assertEqual(dotAt(mocks, Snap.marker, "the parent's dot"), "BOTTOMLEFT 20,251")
    inst.handle:__fire("OnDragStop")
    local at = NS.Database.FindContainer(2).attach
    assertEqual(at.mode .. ":" .. tostring(at.container), "container:1", "still on its parent")
    assertEqual(tostring(at.childPoint) .. ">" .. tostring(at.relPoint), "LEFT>RIGHT", "the new pair written")
    restore()
end)

test("drag: a drop on the right side of a parent whose block reads secret but whose strip reads re-attaches there (A4, A11)", function()
    local NS, mocks, inst, restore = secretParentDrag(200)
    -- 5 right of a 200-wide strip, its center over the strip's top third: TOPLEFT on TOPRIGHT, its
    -- stored pair's points far past C.DETACH_RADIUS.
    plant(inst.anchor, 205, 250, 225, 270)
    local pair, state = NS.Anchors.Snap.Tick()
    -- red under: detach 1:TOPLEFT>BOTTOMLEFT, and the release sent it to the screen
    assertEqual(state, "attach", "its own parent's right side")
    assertEqual(pair.id .. ":" .. pair.point .. ">" .. pair.relPoint, "1:TOPLEFT>TOPRIGHT", "the right side's top pair")
    assertEqual(dotAt(mocks, NS.Anchors.Snap.marker, "the parent's dot"), "BOTTOMLEFT 200,260")
    inst.handle:__fire("OnDragStop")
    local at = NS.Database.FindContainer(2).attach
    assertEqual(at.mode .. ":" .. tostring(at.container), "container:1", "re-attached to its parent")
    assertEqual(tostring(at.childPoint) .. ">" .. tostring(at.relPoint), "TOPLEFT>TOPRIGHT", "on its right side")
    restore()
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
