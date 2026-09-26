-- tests/test_anchors_steady.lua - batch 11 T9: a center or end join holds steady while its parent
-- is empty. A follower hangs from its parent's aura ENGINE (Anchors.HangMode "engine"), and an empty
-- engine holds a 1x1 provisional rect at its START corner, so a relative point on the parent's
-- center or end side landed on that corner: the owner's chain of bars growing up, joined by centered
-- points, shifted sideways by half a bar whenever the middle container had no aura. On each axis the
-- parent is exactly one element across, and that is not the axis the join runs along, the relative
-- point is moved to the parent's start side and the difference added as an offset worked out from
-- the parent's own config (its one-element size and scale), never from engine geometry.
--
-- The mock has no geometry, so each test works out where the join lands from the recorded SetPoint.
-- Hung from the parent's anchor or preview, the parent's rect starts at its start corner (0) and is
-- one element across. Hung from its ENGINE, the rect starts one unit behind the start (the engine lead,
-- tests/test_anchors_collapse.lua: the engine's lead) and runs to the start while the engine is
-- empty (its 1x1 minimum), to one element past the start while it holds auras (its start padding
-- plus the element). The places must agree.

local T = _G.AM_TEST
local test, assertEqual, assertTrue =
    T.test, T.assertEqual, T.assertTrue
local fresh = dofile("tests/fresh_env.lua")

--- The owner's chain 3 -> 2 -> 1, all bars flowing by `growH`/`growV` in one column (perLine 0),
--- 2 and 3 joined by the child's `point` to the parent's `rel`, no nudge, every parent hanging from
--- its engine (locked, or in combat).
local function chain(growH, growV, point, rel)
    local NS = fresh()
    for id = 1, 3 do
        local c = NS.Database.FindContainer(id)
        c.style = "bars"
        c.layout.axis, c.layout.growH, c.layout.growV, c.layout.perLine = "vertical", growH, growV, 0
        if id > 1 then
            c.attach.mode, c.attach.container, c.attach.x, c.attach.y = "container", id - 1, 0, 0
            c.attach.childPoint, c.attach.relPoint = point, rel
        end
    end
    for id = 1, 3 do NS.ContainerManager.instances[id].hangMode = "engine" end
    return NS
end

--- Container `id`'s last SetPoint after one Place.
local function placed(NS, id)
    local inst = NS.ContainerManager.instances[id]
    local rec = {}
    rawset(inst.anchor, "SetPoint", function(_, ...) table.insert(rec, { ... }) end)
    rawset(inst.anchor, "ClearAllPoints", function() end)
    NS.Anchors.Place(inst)
    local p = rec[#rec]
    local parent = NS.ContainerManager.instances[inst:Cfg().attach.container]
    p.onEngine = parent ~= nil and p[2] == parent.engine
    return p
end

local H_OF = { LEFT = "LEFT", RIGHT = "RIGHT", TOPLEFT = "LEFT", BOTTOMLEFT = "LEFT",
    TOPRIGHT = "RIGHT", BOTTOMRIGHT = "RIGHT" }
local V_OF = { TOP = "TOP", BOTTOM = "BOTTOM", TOPLEFT = "TOP", TOPRIGHT = "TOP",
    BOTTOMLEFT = "BOTTOM", BOTTOMRIGHT = "BOTTOM" }

--- Where on screen a join lands on one axis: the relative point on a parent rect running `size` units
--- from the start corner (0) toward `forward` (+1 or -1), starting `lead` units behind it, at parent
--- scale `ps`, plus the offset `off` at child scale `cs`. `low`/`high` name the axis's sides
--- (LEFT/RIGHT, BOTTOM/TOP).
local function land(side, low, high, size, forward, off, ps, cs, lead)
    local a, b = -(lead or 0) * forward, size * forward
    local lo, hi = math.min(a, b), math.max(a, b)
    local at = (side == low and lo) or (side == high and hi) or (lo + hi) / 2
    return at * ps + off * cs
end

--- The engine's lead: 1 when join `p` hangs from an engine (the parent anchor's is never the engine).
local function leadOf(p) return (p.onEngine ~= false) and 1 or 0 end

local function landX(p, size, growH, ps, cs)
    return land(H_OF[p[3]], "LEFT", "RIGHT", size, growH == "left" and -1 or 1, p[4], ps or 1, cs or 1, leadOf(p))
end

local function landY(p, size, growV, ps, cs)
    return land(V_OF[p[3]], "BOTTOM", "TOP", size, growV == "up" and 1 or -1, p[5], ps or 1, cs or 1, leadOf(p))
end

local function near(a, b, what)
    assertTrue(math.abs(a - b) < 1e-6, ("%s: %s vs %s"):format(what, tostring(a), tostring(b)))
end

test("steady: the owner's centered chain growing up lands on the same x with its parent's engine empty as populated", function()
    local NS = chain("right", "up", "BOTTOM", "TOP")
    local w = NS.Style.ElementSize(NS.Database.FindContainer(2))
    local p = placed(NS, 3)
    -- red under: the relative point TOP on an empty engine's 1x1 start corner (half a bar left)
    near(landX(p, 0, "right"), landX(p, w, "right"), "empty vs populated")
    near(landX(p, w, "right"), w / 2, "the parent's center, as before")
    assertEqual(p[1], "BOTTOM", "the child's own point is never rewritten")
end)

test("steady: an end join (right) holds too, and growth left mirrors both", function()
    for _, g in ipairs({ "right", "left" }) do
        for _, pair in ipairs({ { "BOTTOM", "TOP" }, { "BOTTOMRIGHT", "TOPRIGHT" }, { "BOTTOMLEFT", "TOPLEFT" } }) do
            local NS = chain(g, "up", pair[1], pair[2])
            local w = NS.Style.ElementSize(NS.Database.FindContainer(2))
            local p = placed(NS, 3)
            local what = g .. " " .. pair[2]
            near(landX(p, 0, g), landX(p, w, g), what)
            local expect = (H_OF[pair[2]] == "LEFT" and 0) or (H_OF[pair[2]] == "RIGHT" and w) or w / 2
            if g == "left" then expect = expect - w end
            near(landX(p, w, g), expect, what .. " lands where the populated parent's side is")
        end
    end
end)

test("steady: hanging from the parent's one-element anchor (slot) or its preview gives the same place", function()
    local NS = chain("right", "up", "BOTTOM", "TOP")
    local w = NS.Style.ElementSize(NS.Database.FindContainer(2))
    local engine = placed(NS, 3)
    NS.ContainerManager.instances[2].hangMode = "slot"
    local slot = placed(NS, 3)
    assertTrue(slot[2] == NS.ContainerManager.instances[2].anchor, "slot: the anchor")
    near(landX(slot, w, "right"), landX(engine, 0, "right"), "slot vs empty engine")
    assertEqual(slot[3], engine[3])
    assertEqual(slot[4], engine[4] - 1, "the same place: the engine's offset carries its lead")
end)

test("steady: a parent one row across (icons filling a row) is steady on y for a side join centered", function()
    local NS = chain("right", "down", "LEFT", "RIGHT")
    for id = 1, 3 do
        local c = NS.Database.FindContainer(id)
        c.style, c.layout.axis = "icons", "horizontal"
    end
    local _, h = NS.Style.ElementSize(NS.Database.FindContainer(2))
    local p = placed(NS, 3)
    near(landY(p, 0, "down"), landY(p, h, "down"), "empty vs populated on y")
    assertEqual(H_OF[p[3]], "RIGHT", "the join's own axis is not rewritten: the chain still closes up along it")
end)

test("steady: a parent more than one element across is not rewritten on that axis", function()
    local NS = chain("right", "up", "BOTTOM", "TOP")
    for id = 1, 3 do
        local c = NS.Database.FindContainer(id)
        c.style, c.layout.axis = "icons", "horizontal"
    end
    local p = placed(NS, 3)
    -- red under: rewriting an axis where the parent's center legitimately moves with its aura count
    -- (only the engine's lead is taken back: half a unit on a middle part)
    assertEqual(p[3], "TOP"); assertEqual(p[4], 0.5)
end)

test("steady: parent and child at different scales convert the offset to the child's scale", function()
    local NS = chain("right", "up", "BOTTOM", "TOP")
    NS.Database.FindContainer(2).layout.scale = 2
    NS.Database.FindContainer(3).layout.scale = 0.5
    local w = NS.Style.ElementSize(NS.Database.FindContainer(2))
    local p = placed(NS, 3)
    near(landX(p, 0, "right", 2, 0.5), landX(p, w, "right", 2, 0.5), "empty vs populated across scales")
    near(p[4], (w / 2 + 1) * 2 / 0.5, "half the parent's bar and its engine's lead, in the child's units")
end)

test("steady: start-aligned pairs are placed as before, along the chain and across it", function()
    local NS = chain("right", "down", "TOPLEFT", "BOTTOMLEFT")
    local p = placed(NS, 3)
    assertEqual(p[3], "BOTTOMLEFT"); assertEqual(p[4], 1, "the engine's lead, taken back")
    NS.Database.FindContainer(3).attach.childPoint, NS.Database.FindContainer(3).attach.relPoint = "TOPLEFT", "TOPRIGHT"
    p = placed(NS, 3)
    assertEqual(p[3], "TOPRIGHT", "ahead: the join runs across, so an empty parent still closes up")
end)
