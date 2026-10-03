-- tests/test_anchors_mark.lua - issue #22, the owner's smoke round four (A13): while a drag shows a
-- mark, the DRAGGED container's own strip is repainted 2px in the mark's color as well as the target's
-- (or current parent's), green for an attach or a hold and red past the leeway, and every way the
-- mark ends gives both strips their own gold back. modules/Anchors_Snap.lua's edgeStrip, in its two
-- slots. Its own suite because tests/test_anchors_drag.lua sits at layout-§1's 1500-line cap.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local BS = dofile("tests/border_strips.lua")
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

--- A fresh environment with `n` containers, all enabled, on the screen and shown, each strip rebuilt
--- under the recorder and shown (as tests/test_anchors_drag.lua's env).
local function env(n)
    local NS, mocks = fresh()
    while #NS.Database.GetContainers() < n do NS.ContainerManager.Create({}) end
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

--- Keep the anchor's moves inert, so a plant is where it stays.
local function holdAnchor(anchor)
    rawset(anchor, "ClearAllPoints", function() end)
    rawset(anchor, "SetPoint", function() end)
    rawset(anchor, "StartMoving", function() end)
    rawset(anchor, "StopMovingOrSizing", function() end)
end

local GOLD = "1 1,0.82,0,0.6"   -- the strip's own edge: 1px of the widget's gold

local function rgba(col) return "2 " .. table.concat({ col.r, col.g, col.b, col.a }, ",") end

--- How `strip`'s own four edge strips were last painted, "size r,g,b,a", or the four listed when they
--- disagree (as tests/test_anchors_drag.lua's stripEdge).
local function stripEdge(strip)
    local s = BS.strips(strip)
    if #s ~= 4 then return #s .. " strips" end
    local seen = {}
    for i, setter in ipairs({ "SetHeight", "SetHeight", "SetWidth", "SetWidth" }) do
        local last = s[i]:__last(setter)
        seen[i] = (last and last[1] or "?") .. " " .. (s[i]:__joined("SetColorTexture") or "?")
    end
    for i = 2, 4 do
        if seen[i] ~= seen[1] then return table.concat(seen, " | ") end
    end
    return seen[1]
end

--- Container 2 dragged from the screen to just under container 1 (1's engine at 0,100 .. 100,140),
--- one tick run. Returns NS, mocks, 2's instance and Snap.
local function screenDrag(n)
    local NS, mocks = env(n or 2)
    plant(NS.ContainerManager.instances[1].engine, 0, 100, 100, 140)
    local inst = NS.ContainerManager.instances[2]
    holdAnchor(inst.anchor)
    inst.handle:__fire("OnDragStart")
    plant(inst.anchor, 0, 75, 20, 95)
    NS.Anchors.Snap.Tick()
    return NS, mocks, inst, NS.Anchors.Snap
end

test("mark: the dragged container's own strip is repainted with the target's, 2px in green (A13)", function()
    local NS, _, inst, Snap = screenDrag()
    local green = NS.Constants.SNAP_COLOR
    -- red under: only the target's strip repainted (the dragged one kept its gold)
    assertEqual(stripEdge(inst.handle), rgba(green), "the dragged strip")
    assertTrue(Snap.MarkedChildStrip() == inst.handle, "the strip the mark says it painted")
    assertEqual(stripEdge(NS.ContainerManager.instances[1].handle), rgba(green), "and the target's")
    local paints = BS.strips(inst.handle)[1]:__count("SetColorTexture")
    Snap.Tick()
    -- red under: the dragged strip repainted every tick
    assertEqual(BS.strips(inst.handle)[1]:__count("SetColorTexture"), paints, "the same color: not repainted")
end)

test("mark: past the leeway the dragged strip turns red with its parent's, and a hold is green (A4, A13)", function()
    local NS = env(2)
    local CM = NS.ContainerManager
    plant(CM.instances[1].engine, 0, 100, 100, 140)
    local at = NS.Database.FindContainer(2).attach
    at.mode, at.container = "container", 1
    local inst = CM.instances[2]
    holdAnchor(inst.anchor)
    plant(inst.anchor, 0, 75, 20, 95)
    inst.handle:__fire("OnDragStart")
    local Snap, C = NS.Anchors.Snap, NS.Constants
    plant(inst.anchor, 0, 50, 20, 70)
    assertEqual(select(2, Snap.Tick()), "hold", "within the leeway")
    assertEqual(stripEdge(inst.handle), rgba(C.SNAP_COLOR), "hold: the dragged strip green")
    plant(inst.anchor, 0, -54, 20, -34)
    assertEqual(select(2, Snap.Tick()), "detach", "past the leeway")
    -- red under: the dragged strip left green (or gold) while the rest of the mark turned red
    assertEqual(stripEdge(inst.handle), rgba(C.DETACH_COLOR), "detach: the dragged strip red")
    assertEqual(stripEdge(CM.instances[1].handle), rgba(C.DETACH_COLOR), "detach: the parent's strip red")
    inst.handle:__fire("OnDragStop")
    assertEqual(stripEdge(inst.handle), GOLD, "dropped: its gold back")
    assertNil(Snap.MarkedChildStrip(), "and the mark holds no dragged strip")
end)

-- Every way a mark ends while the drag's container is still the one dragged, or the drag itself ends.
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
    { "the dragged container destroyed", function(_, _, inst) inst:Destroy() end },
    { "a profile switch", function(NS, mocks)
        NS.db:SetProfile("Raid")
        mocks.__fireTimers()
        NS.Anchors.Snap.driver:__fire("OnUpdate", 0.05)
    end },
}

test("mark: the dragged strip's own gold comes back on every path the mark ends by (A13)", function()
    for _, path in ipairs(END_PATHS) do
        local what, run = path[1], path[2]
        local NS, mocks, inst, Snap = screenDrag()
        local strip = inst.handle
        assertEqual(stripEdge(strip), rgba(NS.Constants.SNAP_COLOR), what .. ": marked first")
        run(NS, mocks, inst)
        -- red under: a path that hides the mark without restoring the dragged strip's own edge
        assertEqual(stripEdge(strip), GOLD, what .. ": the dragged strip's own gold is back")
        assertNil(Snap.MarkedChildStrip(), what .. ": the mark holds no dragged strip")
    end
end)
