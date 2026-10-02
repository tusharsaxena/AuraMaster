-- tests/test_anchors_snap.lua - issue #22, the snap core (DD-01): what a container dropped near
-- another snaps to. modules/Anchors_Snap.lua's pure core (Snap.PointAt, Snap.Nearest) picks one of
-- the twelve outside pairs (the addendum's A2: each side's start, middle and end joined to the child's
-- mirror point, absolute and independent of growth) side first, by the gap within C.SNAP_RADIUS (D2),
-- then by the third of that side the child's center is over (A7), and names the side token it
-- classifies as under the target's flow growth, nil for a free one; every rect is a container's
-- drag-handle strip while that shows and reads (A10), else its block with its name label (A8); its
-- eligibility keeps a container off itself, off anything that follows it
-- and off a disabled or hidden one (D5); its rect read goes through the secrets guard and falls back
-- from an unreadable engine to the target's anchor; and its folding stores the picked pair nil, nil
-- only when the whole of it is what Automatic would give, else both points absolute (D7).
-- Its own suite because tests/test_anchors.lua sits near layout-§1's 1500-line cap.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")

local GROWTHS = { { "right", "down" }, { "left", "down" }, { "right", "up" }, { "left", "up" } }

--- Plant a rect on `frame`, in its own units at effective scale `scale` (1 when nil).
local function plant(frame, l, b, r, t, scale)
    rawset(frame, "GetLeft", function() return l end)
    rawset(frame, "GetBottom", function() return b end)
    rawset(frame, "GetRight", function() return r end)
    rawset(frame, "GetTop", function() return t end)
    rawset(frame, "GetEffectiveScale", function() return scale or 1 end)
    return frame
end

local function rectOf(l, b, r, t) return { left = l, bottom = b, right = r, top = t } end

--- A fresh environment with at least `n` containers, all enabled, on the screen, and shown.
local function env(n)
    local NS, mocks = fresh()
    while #NS.Database.GetContainers() < (n or 3) do NS.ContainerManager.Create({}) end
    mocks.__fireTimers()
    for _, c in ipairs(NS.Database.GetContainers()) do
        c.enabled, c.attach.mode = true, "screen"
        local inst = NS.ContainerManager.instances[c.id]
        inst.anchor:Show()
        inst.hangMode = "engine"
    end
    return NS, mocks
end

--- The ids `list` (Snap.Candidates' answer) names, comma-joined.
local function ids(list)
    local out = {}
    for i, cand in ipairs(list) do out[i] = tostring(cand.id) end
    return table.concat(out, ",")
end

-- ── the pure core ─────────────────────────────────────────────────────────────────────────────

test("snap: PointAt gives each of the nine WoW points on a rect", function()
    local NS = fresh()
    local r = rectOf(10, 20, 50, 80)
    local want = {
        TOPLEFT = { 10, 80 }, TOP = { 30, 80 }, TOPRIGHT = { 50, 80 },
        LEFT = { 10, 50 }, CENTER = { 30, 50 }, RIGHT = { 50, 50 },
        BOTTOMLEFT = { 10, 20 }, BOTTOM = { 30, 20 }, BOTTOMRIGHT = { 50, 20 },
    }
    for _, point in ipairs(NS.Constants.POINTS) do
        -- red under: no Snap.PointAt
        local x, y = NS.Anchors.Snap.PointAt(r, point)
        assertEqual(x .. "," .. y, want[point][1] .. "," .. want[point][2], point)
    end
end)

-- The addendum's A2 table, written out here rather than read from the module: the parent's side,
-- then each of its three points joined to the child's point that mirrors it across that side.
-- How far a child 2 right and 1 up of a pair's join sits from the side it is on (A7: the gap).
local GAP = { bottom = 1, top = 1, right = 2, left = 2 }

local OUTSIDE = {
    { "bottom", "BOTTOMLEFT", "TOPLEFT" }, { "bottom", "BOTTOM", "TOP" }, { "bottom", "BOTTOMRIGHT", "TOPRIGHT" },
    { "top", "TOPLEFT", "BOTTOMLEFT" }, { "top", "TOP", "BOTTOM" }, { "top", "TOPRIGHT", "BOTTOMRIGHT" },
    { "right", "TOPRIGHT", "TOPLEFT" }, { "right", "RIGHT", "LEFT" }, { "right", "BOTTOMRIGHT", "BOTTOMLEFT" },
    { "left", "TOPLEFT", "TOPRIGHT" }, { "left", "LEFT", "RIGHT" }, { "left", "BOTTOMLEFT", "BOTTOMRIGHT" },
}

--- The token pair `point`/`rel` is one of the nine as under growth `growH`/`growV`, or nil (free).
local function tokenOf(NS, growH, growV, point, rel)
    for _, token in ipairs(NS.Constants.ATTACH_EDGES) do
        local p, r = NS.Anchors.EdgePoints({ growH = growH, growV = growV }, token)
        if p == point and r == rel then return token end
    end
    return nil
end

test("snap: Nearest picks each of the twelve outside pairs, the child's point the mirror of the parent's, under two growths", function()
    local NS = fresh()
    local Snap = NS.Anchors.Snap
    local target = rectOf(0, 0, 100, 40)
    local free = { ["right/down"] = "top", ["left/up"] = "bottom" }
    for _, g in ipairs({ { "right", "down" }, { "left", "up" } }) do
        local grow = g[1] .. "/" .. g[2]
        for _, row in ipairs(OUTSIDE) do
            local side, rel, point = row[1], row[2], row[3]
            local what = side .. " " .. point .. ">" .. rel .. " " .. grow
            -- Flush on the join, the child sits outside the parent: they share no area.
            local tx, ty = Snap.PointAt(target, rel)
            local fx, fy = Snap.PointAt(rectOf(0, 0, 20, 20), point)
            local l, b = tx - fx, ty - fy
            local overlapW = math.min(l + 20, 100) - math.max(l, 0)
            local overlapH = math.min(b + 20, 40) - math.max(b, 0)
            assertTrue(overlapW <= 0 or overlapH <= 0, what .. ": outside")
            -- 2 right and 1 up of the join.
            local hit = Snap.Nearest(rectOf(l + 2, b + 1, l + 22, b + 21),
                { { id = 7, rect = target, growH = g[1], growV = g[2] } }, 24)
            -- red under: the nine growth-relative sides only (the parent's before side is never offered)
            assertTrue(hit ~= nil, what)
            assertEqual(hit.side .. " " .. hit.point .. ">" .. hit.relPoint, side .. " " .. point .. ">" .. rel, what)
            -- red under: the distance between the two points (A7: the gap to the side)
            assertEqual(hit.dist, GAP[side], what .. " dist")
            -- The before side is free (G5); every other side is one of the nine under the target's growth.
            local want = tokenOf(NS, g[1], g[2], point, rel)
            assertEqual(tostring(hit.token), tostring(want), what .. " token")
            assertEqual(want == nil, side == free[grow], what .. ": free only on the before side")
        end
    end
end)

test("snap: Nearest picks the pair of each of the nine sides under each growth, and names its token", function()
    local NS = fresh()
    local Snap = NS.Anchors.Snap
    local target = rectOf(0, 0, 100, 40)
    for _, g in ipairs(GROWTHS) do
        for _, token in ipairs(NS.Constants.ATTACH_EDGES) do
            local point, rel = NS.Anchors.EdgePoints({ growH = g[1], growV = g[2] }, token)
            -- A 20x20 child whose `point` sits 2 right and 1 up of the target's `rel`.
            local tx, ty = Snap.PointAt(target, rel)
            local fx, fy = Snap.PointAt(rectOf(0, 0, 20, 20), point)
            local l, b = tx + 2 - fx, ty + 1 - fy
            local hit = Snap.Nearest(rectOf(l, b, l + 20, b + 20),
                { { id = 7, rect = target, growH = g[1], growV = g[2] } }, 24)
            local what = token .. " " .. g[1] .. "/" .. g[2]
            -- red under: the token classified under the dragged container's own growth, or a fixed one
            assertTrue(hit ~= nil, what)
            assertEqual(hit.token, token, what)
            assertEqual(hit.point .. ">" .. hit.relPoint, point .. ">" .. rel, what)
            assertEqual(hit.id, 7, what)
            assertEqual(hit.dist, GAP[hit.side], what .. " dist")
        end
    end
end)

test("snap: Nearest answers nil past the radius, and takes a pair exactly on it", function()
    local NS = fresh()
    local Snap = NS.Anchors.Snap
    local target = { id = 2, rect = rectOf(0, 100, 100, 140), growH = "right", growV = "down" }
    -- The child's TOPLEFT straight under the target's BOTTOMLEFT (after-start), `gap` below.
    local function under(gap) return rectOf(0, 100 - gap - 20, 20, 100 - gap) end
    -- red under: no radius (every drop snaps)
    assertNil(Snap.Nearest(under(24.5), { target }, 24), "past the radius")
    -- red under: a strict comparison against the radius
    local hit = Snap.Nearest(under(24), { target }, 24)
    assertTrue(hit ~= nil and hit.token == "after-start", "on the radius")
    assertNil(Snap.Nearest(under(1), {}, 24), "no candidates")
end)

test("snap: a tie keeps the first target in the order given, and the first side in the A2 table's order", function()
    local NS = fresh()
    local Snap = NS.Anchors.Snap
    local same = rectOf(0, 100, 100, 140)
    local child = rectOf(0, 70, 20, 90)
    local hit = Snap.Nearest(child, {
        { id = 2, rect = same, growH = "right", growV = "down" },
        { id = 3, rect = same, growH = "right", growV = "down" },
    }, 24)
    -- red under: a <= comparison while scanning (the last of equals wins)
    assertEqual(hit.id, 2, "first target")
    -- At the target's bottom-right corner, 5 below it and 5 right of it: the bottom side and the right
    -- side are both 5 away, and the bottom comes first in the table.
    hit = Snap.Nearest(rectOf(105, 75, 125, 95),
        { { id = 4, rect = same, growH = "right", growV = "down" } }, 24)
    -- red under: a <= comparison across sides (the last side of equals, the right, wins)
    assertEqual(hit.side .. " " .. hit.point .. ">" .. hit.relPoint, "bottom TOPRIGHT>BOTTOMRIGHT", "first side")
    assertEqual(hit.token, "after-end")
    assertEqual(hit.dist, 5)
    -- Growing up, the bottom is the before side: the same pick, free.
    hit = Snap.Nearest(rectOf(105, 75, 125, 95),
        { { id = 4, rect = same, growH = "right", growV = "up" } }, 24)
    assertEqual(hit.side .. " " .. hit.point .. ">" .. hit.relPoint, "bottom TOPRIGHT>BOTTOMRIGHT",
        "the table's first side, whatever the growth")
    assertNil(hit.token, "a before-side pair is free")
end)

-- ── side first, then align by thirds (the addendum's A7) ──────────────────────────────────────

-- For each side of a 90x90 target at 0,0: where a 90x90 child sits 5 outside it, centered on that
-- side, and how far "along" moves it toward the side's start (left, or the top for a vertical side).
local SIDE_AT = {
    bottom = function(along) return rectOf(-along, -95, 90 - along, -5) end,
    top    = function(along) return rectOf(-along, 95, 90 - along, 185) end,
    right  = function(along) return rectOf(95, along, 185, 90 + along) end,
    left   = function(along) return rectOf(-95, along, -5, 90 + along) end,
}
-- The pair each third answers, start, middle and end (A2's table, read along the side).
local THIRDS = {
    bottom = { "TOPLEFT>BOTTOMLEFT", "TOP>BOTTOM", "TOPRIGHT>BOTTOMRIGHT" },
    top    = { "BOTTOMLEFT>TOPLEFT", "BOTTOM>TOP", "BOTTOMRIGHT>TOPRIGHT" },
    right  = { "TOPLEFT>TOPRIGHT", "LEFT>RIGHT", "BOTTOMLEFT>BOTTOMRIGHT" },
    left   = { "TOPRIGHT>TOPLEFT", "RIGHT>LEFT", "BOTTOMRIGHT>BOTTOMLEFT" },
}

test("snap: equal-width containers pick the middle pair centered, and the start or end pair in the outer thirds, on all four sides (A7)", function()
    local NS = fresh()
    local Snap = NS.Anchors.Snap
    local target = { { id = 7, rect = rectOf(0, 0, 90, 90), growH = "right", growV = "down" } }
    for _, side in ipairs({ "bottom", "top", "right", "left" }) do
        -- Centered, then its center 5 inside the start end and 5 inside the far end (40 along).
        for i, along in ipairs({ 40, 0, -40 }) do
            local hit = Snap.Nearest(SIDE_AT[side](along), target, 24)
            local what = side .. " " .. along
            -- red under: the nearest pair of points (every pair of a side as near, the start pair kept)
            assertTrue(hit ~= nil, what)
            assertEqual(hit.side .. " " .. hit.point .. ">" .. hit.relPoint, side .. " " .. THIRDS[side][i], what)
            assertEqual(hit.dist, 5, what .. ": dist is the gap")
        end
    end
end)

test("snap: a third's border goes to the middle pair, and a target one point wide answers its middle pair", function()
    local NS = fresh()
    local Snap = NS.Anchors.Snap
    local target = { { id = 7, rect = rectOf(0, 0, 90, 90), growH = "right", growV = "down" } }
    -- A 30-wide child under the target, its center on 30, then on 29.5 (the first third's border is 30).
    local hit = Snap.Nearest(rectOf(15, -35, 45, -5), target, 24)
    -- red under: a border taken by the outer third
    assertEqual(hit.point .. ">" .. hit.relPoint, "TOP>BOTTOM", "on the border")
    hit = Snap.Nearest(rectOf(14.5, -35, 44.5, -5), target, 24)
    assertEqual(hit.point .. ">" .. hit.relPoint, "TOPLEFT>BOTTOMLEFT", "just inside the first third")
    hit = Snap.Nearest(rectOf(45, -35, 75, -5), target, 24)
    assertEqual(hit.point .. ">" .. hit.relPoint, "TOP>BOTTOM", "on the last third's border")
    -- A target with no width: centered over it is the middle, either side of it the start or the end.
    local dot = { { id = 4, rect = rectOf(50, 50, 50, 50), growH = "right", growV = "down" } }
    hit = Snap.Nearest(rectOf(40, 30, 60, 45), dot, 24)
    assertEqual(hit.point .. ">" .. hit.relPoint, "TOP>BOTTOM", "centered on a point")
    hit = Snap.Nearest(rectOf(30, 30, 45, 45), dot, 24)
    -- red under: a span that must overlap the target's own, unwidened (beside a point, it never does)
    assertTrue(hit ~= nil, "left of a point")
    assertEqual(hit.point .. ">" .. hit.relPoint, "TOPLEFT>BOTTOMLEFT", "left of a point")
end)

test("snap: the side is the nearest gap whose span overlaps the target's widened by the radius, an overlap's gap counted as its size (A7)", function()
    local NS = fresh()
    local Snap = NS.Anchors.Snap
    local target = { { id = 7, rect = rectOf(0, 0, 90, 90), growH = "right", growV = "down" } }
    -- Under it, overlapping it by 3: the bottom, 3 away.
    local hit = Snap.Nearest(rectOf(30, -17, 60, 3), target, 24)
    -- red under: a signed gap (an overlap ranked as nearer than flush)
    assertEqual(hit.side .. " " .. hit.dist, "bottom 3", "an overlap")
    -- 5 under it and 23 past its right edge: the bottom side (its span overlaps the widened one) beats
    -- the right side's 23, and the child's center is in the last third.
    hit = Snap.Nearest(rectOf(113, -25, 133, -5), target, 24)
    -- red under: a span that must overlap the target's own (the corner never snaps)
    assertEqual(hit.side .. " " .. hit.point .. ">" .. hit.relPoint .. " " .. hit.dist,
        "bottom TOPRIGHT>BOTTOMRIGHT 5", "the widened span")
    -- 24 past it: the bottom's span only touches the widened one, which is no overlap, and the right
    -- side, 24 away, takes it, by its bottom third.
    hit = Snap.Nearest(rectOf(114, -25, 134, -5), target, 24)
    -- red under: a touch counted as an overlap (the bottom's 5 wins)
    assertEqual(hit.side .. " " .. hit.point .. ">" .. hit.relPoint .. " " .. hit.dist,
        "right BOTTOMLEFT>BOTTOMRIGHT 24", "a touch is no overlap")
    -- 25 past it: the right side is 25 away, and nothing else is in range.
    assertNil(Snap.Nearest(rectOf(115, -25, 135, -5), target, 24), "past the widened span")
    -- 2 right of it and 5 under it: the right side is nearer, and the child's center is in its bottom third.
    hit = Snap.Nearest(rectOf(92, -25, 112, -5), target, 24)
    assertEqual(hit.side .. " " .. hit.point .. ">" .. hit.relPoint .. " " .. hit.dist,
        "right BOTTOMLEFT>BOTTOMRIGHT 2", "the nearer gap")
end)

-- ── eligibility (D5) ──────────────────────────────────────────────────────────────────────────

test("snap: Candidates lists every other live container in id order, with its rect and flow growth", function()
    local NS = env(3)
    local CM = NS.ContainerManager
    for id = 1, 3 do plant(CM.instances[id].engine, 0, id * 100, 100, id * 100 + 40) end
    NS.Database.FindContainer(3).layout.growH = "left"
    -- red under: no Snap.Candidates
    local list = NS.Anchors.Snap.Candidates(CM.instances[2])
    assertEqual(ids(list), "1,3", "the dragged one is never a target")
    assertEqual(list[2].rect.bottom, 300)
    assertEqual(list[2].growH .. "/" .. list[2].growV, "left/down", "the target's own growth")
end)

test("snap: Candidates gives id order whatever order pairs walks the instances in, so a tie keeps the lower id", function()
    local NS, mocks = env(3)
    local CM = NS.ContainerManager
    -- 1 and 3 on one rect, so a drop of 2 is exactly as near to each (D2: the first in id order wins).
    plant(CM.instances[1].engine, 0, 100, 100, 140)
    plant(CM.instances[3].engine, 0, 100, 100, 140)
    plant(CM.instances[2].anchor, 0, 75, 20, 95)
    -- In game, ids left sparse by deletes sit in the table's hash part, where Lua 5.1 leaves the order
    -- pairs walks them in unspecified; here it walks the instances backwards.
    local instances = CM.instances
    mocks.pairs = function(t)
        if t ~= instances then return pairs(t) end
        local keys = {}
        for k in pairs(t) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return a > b end)
        local i = 0
        return function()
            i = i + 1
            local k = keys[i]
            if k ~= nil then return k, t[k] end
        end, t, nil
    end
    local list = ids(NS.Anchors.Snap.Candidates(CM.instances[2]))
    local hit = NS.Anchors.Snap.Find(CM.instances[2])
    mocks.pairs = nil
    -- red under: Candidates without table.sort (the ids in pairs order)
    assertEqual(list, "1,3", "id order")
    assertEqual(hit and hit.id, 1, "the tie keeps the lower id")
end)

test("snap: a follower of the dragged container, and one further down its chain, is never a target", function()
    local NS = env(4)
    local CM = NS.ContainerManager
    for id = 1, 4 do plant(CM.instances[id].engine, 0, id * 100, 100, id * 100 + 40) end
    local c3, c4 = NS.Database.FindContainer(3), NS.Database.FindContainer(4)
    c3.attach.mode, c3.attach.container = "container", 1
    c4.attach.mode, c4.attach.container = "container", 3
    -- red under: an eligibility without WouldCycle (dropping 1 onto 3 or 4 closes a loop)
    assertEqual(ids(NS.Anchors.Snap.Candidates(CM.instances[1])), "2", "3 follows 1, 4 follows 3")
    assertEqual(ids(NS.Anchors.Snap.Candidates(CM.instances[3])), "1,2", "4 follows 3; 1 leads it")
end)

test("snap: a disabled container, and one whose anchor is hidden, is never a target", function()
    local NS = env(4)
    local CM = NS.ContainerManager
    for id = 1, 4 do plant(CM.instances[id].engine, 0, id * 100, 100, id * 100 + 40) end
    NS.Database.FindContainer(3).enabled = false
    CM.instances[4].anchor:Hide()
    -- red under: an eligibility that reads neither `enabled` nor the anchor's shown state
    assertEqual(ids(NS.Anchors.Snap.Candidates(CM.instances[1])), "2")
end)

test("snap: Candidates allocates nothing on a tick, though the dragged container is the last id and never a target", function()
    local NS = env(3)
    local CM = NS.ContainerManager
    local last = 0
    for id, inst in pairs(CM.instances) do
        plant(inst.engine, 0, id * 100, 100, id * 100 + 40)
        last = math.max(last, id)
    end
    local Snap, dragged = NS.Anchors.Snap, CM.instances[last]
    assertEqual(#Snap.Candidates(dragged), last - 1, "the pool filled, every other container in it")
    collectgarbage("collect")
    collectgarbage("stop")
    local before = collectgarbage("count")
    for _ = 1, 200 do Snap.Candidates(dragged) end
    local grew = collectgarbage("count") - before
    collectgarbage("restart")
    -- red under: a pool entry and its rect made before the eligibility check (two tables thrown away
    -- per tick for the dragged container, past the pool's end)
    assertTrue(grew < 1, "allocated " .. grew .. " KB")
end)

-- ── the target rect ───────────────────────────────────────────────────────────────────────────

test("snap: the target rect is the frame a follower would hang from in its hang mode", function()
    local NS, mocks = env(2)
    local inst = NS.ContainerManager.instances[2]
    inst.previewExtent = inst.previewExtent or mocks.CreateFrame("Frame")
    plant(inst.engine, 0, 0, 100, 40)
    plant(inst.anchor, 0, 20, 30, 40)
    plant(inst.previewExtent, 0, -60, 100, 40)
    local Snap = NS.Anchors.Snap
    inst.hangMode = "engine"
    -- red under: no Anchors.HangFrame (the rect read off the anchor in every mode)
    assertTrue(NS.Anchors.HangFrame(inst) == inst.engine, "engine")
    assertEqual(Snap.TargetRect(inst).bottom, 0, "engine")
    inst.hangMode = "slot"
    assertTrue(NS.Anchors.HangFrame(inst) == inst.anchor, "slot")
    assertEqual(Snap.TargetRect(inst).bottom, 20, "slot: the one-element anchor")
    inst.hangMode = "preview"
    assertTrue(NS.Anchors.HangFrame(inst) == inst.previewExtent, "preview")
    assertEqual(Snap.TargetRect(inst).bottom, -60, "preview: the preview extent")
end)

test("snap: rects are read in UIParent units", function()
    local NS, mocks = env(2)
    local inst = NS.ContainerManager.instances[2]
    inst.hangMode = "engine"
    plant(inst.engine, 10, 20, 110, 60, 1.5)
    rawset(mocks.UIParent, "GetEffectiveScale", function() return 0.75 end)
    local r = NS.Anchors.Snap.TargetRect(inst)
    -- red under: the frame's own units (no scale), or a scale divided the wrong way
    assertEqual(r.left .. "," .. r.bottom .. "," .. r.right .. "," .. r.top, "20,40,220,120")
end)

test("snap: an engine whose rect reads secret falls back to the anchor; an unreadable anchor drops the target", function()
    local SECRET = 41.5
    local NS, mocks = env(3)
    mocks.issecretvalue = function(v) return v == SECRET end
    local CM = NS.ContainerManager
    local inst = CM.instances[2]
    inst.hangMode = "engine"
    plant(inst.engine, 0, SECRET, 100, 40)
    plant(inst.anchor, 0, 20, 30, 40)
    local r = NS.Anchors.Snap.TargetRect(inst)
    -- red under: no guard (arithmetic on the secret), or no fallback (the target dropped)
    assertTrue(r ~= nil, "the anchor's rect")
    assertEqual(r.bottom .. "," .. r.right, "20,30")
    plant(inst.anchor, 0, 20, SECRET, 40)
    assertNil(NS.Anchors.Snap.TargetRect(inst), "nothing readable")
    plant(CM.instances[1].engine, 0, 100, 100, 140)
    plant(CM.instances[3].engine, 0, 300, 100, 340)
    assertEqual(ids(NS.Anchors.Snap.Candidates(CM.instances[1])), "3", "2 dropped")
    -- A frame with no geometry at all (the mock's default answers a frame, not a number).
    rawset(inst.engine, "GetLeft", nil)
    rawset(inst.anchor, "GetLeft", nil)
    assertNil(NS.Anchors.Snap.TargetRect(inst), "no geometry")
end)

test("snap: Find reads the dragged anchor and answers the nearest in-range target", function()
    local NS = env(3)
    local CM = NS.ContainerManager
    for id = 1, 3 do CM.instances[id].hangMode = "engine" end
    plant(CM.instances[1].engine, 0, 100, 100, 140)
    plant(CM.instances[3].engine, 400, 100, 500, 140)
    -- 2's TOPLEFT 5 under 3's BOTTOMLEFT: after-start on 3.
    plant(CM.instances[2].anchor, 400, 75, 420, 95)
    -- red under: no Snap.Find
    local hit = NS.Anchors.Snap.Find(CM.instances[2])
    assertTrue(hit ~= nil)
    assertEqual(hit.id .. " " .. hit.token, "3 after-start")
    -- 2's BOTTOMLEFT 5 above 3's TOPLEFT: 3's top, its before side growing down, a free pair.
    plant(CM.instances[2].anchor, 400, 145, 420, 165)
    hit = NS.Anchors.Snap.Find(CM.instances[2])
    -- red under: the nine growth-relative sides only
    assertTrue(hit ~= nil, "the before side")
    assertEqual(hit.id .. " " .. hit.side .. " " .. hit.point .. ">" .. hit.relPoint, "3 top BOTTOMLEFT>TOPLEFT")
    assertNil(hit.token, "free")
    plant(CM.instances[2].anchor, 250, 75, 270, 95)
    assertNil(NS.Anchors.Snap.Find(CM.instances[2]), "nothing within the radius")
    rawset(CM.instances[2].anchor, "GetLeft", nil)
    assertNil(NS.Anchors.Snap.Find(CM.instances[2]), "the dragged anchor unreadable")
end)

-- ── the rect the snap reads: the strip, else the visible footprint (the addendum's A10, A8) ────

--- Give live container `inst` a strip and a name label of plain mock frames where it has none (the
--- snap suite builds neither), both hidden. Returns the strip and the label.
local function furniture(mocks, inst)
    inst.handle = inst.handle or mocks.CreateFrame("Frame")
    inst.label = inst.label or mocks.CreateFrame("Frame")
    inst.handle:Hide()
    inst.label:Hide()
    return inst.handle, inst.label
end

local function edges(r) return r.left .. "," .. r.bottom .. "," .. r.right .. "," .. r.top end

test("snap: a target's rect is its strip's while that shows and reads, on each growth (A10)", function()
    -- Where the strip sits on each growth (Anchors.StripPoints): above the block growing down, below it
    -- growing up, lined up with the side the lines start from and running on past the other.
    local STRIP = {
        ["right/down"] = { 0, 142, 120, 160 }, ["left/down"] = { -20, 142, 100, 160 },
        ["right/up"] = { 0, 80, 120, 98 }, ["left/up"] = { -20, 80, 100, 98 },
    }
    for _, g in ipairs(GROWTHS) do
        local grow = g[1] .. "/" .. g[2]
        local NS, mocks = env(2)
        local inst = NS.ContainerManager.instances[2]
        local L = NS.Database.FindContainer(2).layout
        L.growH, L.growV = g[1], g[2]
        plant(inst.engine, 0, 100, 100, 140)
        local strip = furniture(mocks, inst)
        plant(strip, unpack(STRIP[grow]))
        local Snap = NS.Anchors.Snap
        assertEqual(edges(Snap.Footprint(inst)), "0,100,100,140", grow .. ": the strip hidden, the block alone")
        strip:Show()
        -- red under: A8's footprint, the block and the strip together (the dots on the placeholder's corners)
        assertEqual(edges(Snap.Footprint(inst)), table.concat(STRIP[grow], ","), grow .. ": the strip shown")
        assertEqual(edges(Snap.TargetRect(inst)), "0,100,100,140", grow .. ": the block rect is unchanged")
    end
end)

test("snap: a strip that is hidden or does not read falls back to the block with its name label (A8, A10)", function()
    local SECRET = 41.5
    local NS, mocks = env(2)
    mocks.issecretvalue = function(v) return v == SECRET end
    local inst = NS.ContainerManager.instances[2]
    plant(inst.engine, 0, 100, 100, 140)
    local strip, label = furniture(mocks, inst)
    plant(label, 0, 142, 100, 160)
    plant(strip, 0, 162, 120, 180)
    label:Show()
    local Snap = NS.Anchors.Snap
    -- red under: a fallback without the label (the label between the strip and the block)
    assertEqual(edges(Snap.Footprint(inst)), "0,100,100,160", "the strip hidden: the block and the label")
    strip:Show()
    -- red under: A8's footprint, block, label and strip (0,100,120,180)
    assertEqual(edges(Snap.Footprint(inst)), "0,162,120,180", "the strip shown: the strip alone")
    plant(strip, 0, 162, SECRET, 180)
    -- red under: no guard on the strip's rect (arithmetic on a secret), or a target dropped for it
    assertEqual(edges(Snap.Footprint(inst)), "0,100,100,160", "a strip reading secret: the block and the label")
    plant(label, SECRET, 142, 100, 160)
    assertEqual(edges(Snap.Footprint(inst)), "0,100,100,140", "and a label reading secret: the block")
    -- A block that does not read at all, the anchor neither: the strip still answers while it reads.
    plant(strip, 0, 162, 120, 180)
    rawset(inst.engine, "GetLeft", nil)
    rawset(inst.anchor, "GetLeft", nil)
    -- red under: A8, where no block meant no footprint whatever the strip read
    assertEqual(edges(Snap.Footprint(inst)), "0,162,120,180", "no block: the strip")
    strip:Hide()
    assertNil(Snap.Footprint(inst), "no block and no strip: nothing")
    plant(inst.anchor, 0, 120, 20, 140)
    assertEqual(edges(Snap.Footprint(inst)), "0,120,20,140", "the one-element fallback")
end)

test("snap: Find measures the side on the target's strip and the dragged one's own strip (A10)", function()
    local NS, mocks = env(3)
    local CM = NS.ContainerManager
    plant(CM.instances[3].engine, 400, 100, 500, 140)
    local strip3 = furniture(mocks, CM.instances[3])
    local strip2 = furniture(mocks, CM.instances[2])
    plant(strip3, 400, 142, 500, 160)
    -- 2 as wide as 3, 30 over 3's block: out of range on blocks alone.
    plant(CM.instances[2].anchor, 400, 170, 500, 190)
    assertNil(NS.Anchors.Snap.Find(CM.instances[2]), "the blocks 30 apart")
    strip3:Show()
    local hit = NS.Anchors.Snap.Find(CM.instances[2])
    -- red under: the target's block alone (30 > the radius: no pair)
    assertTrue(hit ~= nil, "3's strip 10 under 2")
    assertEqual(hit.id .. " " .. hit.side .. " " .. hit.point .. ">" .. hit.relPoint .. " " .. hit.dist,
        "3 top BOTTOM>TOP 10")
    local rect = NS.Anchors.Snap.Candidates(CM.instances[2])[1].rect
    -- red under: A10's strip alone (its bottom 142), or the block (its top 140)
    assertEqual(edges(rect), "400,100,500,160", "the candidate's rect is its strip, its growth side out to its block (A11)")
    -- 2's own strip 10 over 3's strip, its anchor 30 under 3's block: the strips' gap, not the blocks'.
    plant(CM.instances[2].anchor, 400, 50, 500, 70)
    plant(strip2, 400, 170, 500, 188)
    strip2:Show()
    hit = NS.Anchors.Snap.Find(CM.instances[2])
    -- red under: A8's footprints (2's strip and anchor, 50..188, over 3's 100..160: no side in range)
    assertTrue(hit ~= nil, "2's strip 10 over 3's")
    assertEqual(hit.side .. " " .. hit.point .. ">" .. hit.relPoint .. " " .. hit.dist, "top BOTTOM>TOP 10")
    -- 2's strip reading nothing: its anchor, 30 under 3's block and 72 under its strip, out of range.
    rawset(strip2, "GetLeft", function() return nil end)
    -- red under: no fallback (the dragged strip's nil read taken as a rect)
    assertNil(NS.Anchors.Snap.Find(CM.instances[2]), "the anchor alone: out of range")
    strip3:Hide()
    plant(CM.instances[2].anchor, 400, 75, 500, 95)
    hit = NS.Anchors.Snap.Find(CM.instances[2])
    assertTrue(hit ~= nil and hit.side == "bottom", "the anchor 5 under 3's block, both strips out")
end)

-- ── the parent's growth sides reach its block (the addendum's A11) ─────────────────────────────

-- A block wider than its strip (several columns), and a strip in from the block's before-side edge, so
-- each edge tells where it was read: the block's far edge on a growth side, the strip's elsewhere.
local REACH = {
    ["right/down"] = { strip = { 10, 142, 120, 160 }, want = "10,100,200,160" },
    ["left/down"] = { strip = { 80, 142, 190, 160 }, want = "0,100,190,160" },
    ["right/up"] = { strip = { 10, 80, 120, 98 }, want = "10,80,200,140" },
    ["left/up"] = { strip = { 80, 80, 190, 98 }, want = "0,80,190,140" },
}

--- Container 1 of a fresh env(2) growing `g`, its block 0,100,200,140 and its strip REACH's, shown.
local function reachEnv(g)
    local NS, mocks = env(2)
    local inst = NS.ContainerManager.instances[1]
    local L = NS.Database.FindContainer(1).layout
    L.growH, L.growV = g[1], g[2]
    plant(inst.engine, 0, 100, 200, 140)
    local strip = furniture(mocks, inst)
    plant(strip, unpack(REACH[g[1] .. "/" .. g[2]].strip))
    strip:Show()
    return NS, mocks, inst, strip
end

test("snap: a parent's rect is its strip, each edge on a side it grows toward out to its block's far edge (A11)", function()
    for _, g in ipairs(GROWTHS) do
        local grow = g[1] .. "/" .. g[2]
        local NS, _, inst = reachEnv(g)
        local Snap = NS.Anchors.Snap
        -- red under: A10's strip alone, or the whole union of strip and block (the before-side edge too)
        assertEqual(edges(Snap.ParentRect(inst)), REACH[grow].want, grow .. ": the parent's rect")
        assertEqual(edges(Snap.Candidates(NS.ContainerManager.instances[2])[1].rect), REACH[grow].want,
            grow .. ": the candidate's rect")
        assertEqual(edges(Snap.Footprint(inst)), table.concat(REACH[grow].strip, ","), grow .. ": the strip itself")
    end
end)

test("snap: a strip that overhangs its block on a side the parent grows toward keeps its own edge there (A11)", function()
    -- A one-element block (50,100 .. 100,140) inside a strip planted past it on every side (as a
    -- stripLabel's natural width is past a lone element): the union, on each growth edge, is the strip's.
    for _, g in ipairs(GROWTHS) do
        local grow = g[1] .. "/" .. g[2]
        local NS, _, inst, strip = reachEnv(g)
        plant(inst.engine, 50, 100, 100, 140)
        plant(strip, 0, 90, 190, 160)
        -- red under: a growth edge taken to the block's alone (left 50 or right 100, bottom 100 or top 140)
        assertEqual(edges(NS.Anchors.Snap.ParentRect(inst)), "0,90,190,160", grow .. ": the strip's edges kept")
    end
end)

test("snap: a block past the strip on the sides the parent does not grow toward leaves the strip's edges there (A11)", function()
    -- A block (0,40 .. 200,180) past a strip (50,100 .. 150,120) on every side: only the growth edges
    -- reach it, the other two stay the strip's.
    local WANT = { ["right/down"] = "50,40,200,120", ["right/up"] = "50,100,200,180",
        ["left/down"] = "0,40,150,120", ["left/up"] = "0,100,150,180" }
    for _, g in ipairs(GROWTHS) do
        local grow = g[1] .. "/" .. g[2]
        local NS, _, inst, strip = reachEnv(g)
        plant(inst.engine, 0, 40, 200, 180)
        plant(strip, 50, 100, 150, 120)
        -- red under: a union on both vertical (or both horizontal) edges, whatever the growth
        assertEqual(edges(NS.Anchors.Snap.ParentRect(inst)), WANT[grow], grow .. ": growth edges only")
    end
end)

test("snap: a parent's block is read with its guards and fallback, and one that does not read leaves the strip (A11)", function()
    local SECRET = 41.5
    local NS, mocks, inst, strip = reachEnv({ "right", "down" })
    mocks.issecretvalue = function(v) return v == SECRET end
    local Snap = NS.Anchors.Snap
    plant(inst.engine, 0, SECRET, 200, 140)
    plant(inst.anchor, 0, 120, 20, 140)
    -- red under: no guard on the block (arithmetic on a secret), or no fallback to the one element
    assertEqual(edges(Snap.ParentRect(inst)), "10,120,120,160", "the engine secret: the one-element anchor")
    plant(inst.anchor, 0, 120, SECRET, 140)
    -- red under: a parent dropped when its block does not read
    assertEqual(edges(Snap.ParentRect(inst)), "10,142,120,160", "no block: the strip")
    strip:Hide()
    assertNil(Snap.ParentRect(inst), "no block and no strip: nothing")
end)

--- Drop child 2 of a reachEnv as the rect `l,b,r,t` (its anchor; it has no strip) and answer the
--- hit's "id side dist", or "none".
local function sideOf(NS, l, b, r, t)
    local CM = NS.ContainerManager
    plant(CM.instances[2].anchor, l, b, r, t)
    local hit = NS.Anchors.Snap.Find(CM.instances[2])
    return hit and (hit.id .. " " .. hit.side .. " " .. hit.dist) or "none"
end

test("snap: the side pick measures a parent's growth sides on its block's far edges, its other sides on its strip (A11)", function()
    -- Growing right and down: under the block's bottom (100), 5 off; over the strip's top (160), 5 off.
    local NS = reachEnv({ "right", "down" })
    -- red under: A10's strip (its bottom 142, 47 over the child: out of range)
    assertEqual(sideOf(NS, 40, 75, 90, 95), "1 bottom 5", "down: under the block")
    assertEqual(sideOf(NS, 40, 165, 90, 185), "1 top 5", "down: over the strip")
    -- Past the block's right (200), 5 off; before the strip's left (10), 19 off (the block's left, 9).
    -- red under: A10's strip (its right 120, 85 off: out of range)
    assertEqual(sideOf(NS, 205, 110, 225, 130), "1 right 5", "right: past the block")
    -- red under: the whole union of strip and block (the block's left edge, 9 off)
    assertEqual(sideOf(NS, -29, 110, -9, 130), "1 left 19", "right: the before side on the strip")
    -- Growing left and up: over the block's top (140), 5 off; under the strip's bottom (80), 5 off.
    NS = reachEnv({ "left", "up" })
    -- red under: A10's strip (its top 98, 47 under the child: out of range)
    assertEqual(sideOf(NS, 40, 145, 90, 165), "1 top 5", "up: over the block")
    assertEqual(sideOf(NS, 40, 55, 90, 75), "1 bottom 5", "up: under the strip")
    -- Before the block's left (0), 5 off; past the strip's right (190), 15 off (the block's, 5).
    -- red under: A10's strip (its left 80, 85 off: out of range)
    assertEqual(sideOf(NS, -25, 110, -5, 130), "1 left 5", "left: past the block")
    assertEqual(sideOf(NS, 205, 110, 225, 130), "1 right 15", "left: the before side on the strip")
end)

-- ── Automatic folding (D7) ────────────────────────────────────────────────────────────────────

test("snap: a picked side equal to Automatic stores nil for both points", function()
    for _, g in ipairs(GROWTHS) do
        local NS = env(2)
        NS.Database.FindContainer(1).style = "bars"
        local L1 = NS.Database.FindContainer(1).layout
        L1.growH, L1.growV = g[1], g[2]
        local c2 = NS.Database.FindContainer(2)
        c2.style = "bars"
        local point, rel = NS.Anchors.EdgePoints(L1, "after-start")
        -- red under: no Snap.FoldPoints
        local cp, rp = NS.Anchors.Snap.FoldPoints(c2, 1, point, rel)
        assertNil(cp, g[1] .. "/" .. g[2])
        assertNil(rp, g[1] .. "/" .. g[2])
        assertEqual(c2.attach.mode, "screen", "the stored config is not touched")
    end
end)

test("snap: a side other than Automatic's stores the whole absolute pair, even one sharing a point with it", function()
    local NS = env(2)
    NS.Database.FindContainer(1).style = "bars"
    local c2 = NS.Database.FindContainer(2)
    c2.style = "bars"
    local Snap = NS.Anchors.Snap
    -- Growing right/down Automatic is after-start, TOPLEFT > BOTTOMLEFT. A drop picks a whole side, so
    -- half of it left Automatic would follow the parent's growth alone: under Grow Left, Automatic
    -- turns TOPRIGHT > BOTTOMRIGHT and a stored nil > TOPRIGHT would resolve to TOPRIGHT > TOPRIGHT,
    -- the child on top of the parent's first element.
    local cp, rp = Snap.FoldPoints(c2, 1, "BOTTOMRIGHT", "BOTTOMLEFT")
    -- red under: the per-half fold (BOTTOMRIGHT>nil, a mixed pair the player never picked)
    assertEqual(tostring(cp) .. ">" .. tostring(rp), "BOTTOMRIGHT>BOTTOMLEFT", "behind-end: shares the relative half")
    cp, rp = Snap.FoldPoints(c2, 1, "TOPLEFT", "TOPRIGHT")
    -- red under: the per-half fold (nil>TOPRIGHT)
    assertEqual(tostring(cp) .. ">" .. tostring(rp), "TOPLEFT>TOPRIGHT", "ahead-start: shares the child half")
    cp, rp = Snap.FoldPoints(c2, 1, "TOPRIGHT", "TOPLEFT")
    assertEqual(tostring(cp) .. ">" .. tostring(rp), "TOPRIGHT>TOPLEFT", "behind-start: shares neither")
end)

test("snap: folding reads Automatic for the target dropped on, not the container's current parent", function()
    local NS = env(3)
    local c1, c3 = NS.Database.FindContainer(1), NS.Database.FindContainer(3)
    c1.style, c1.text.justifyH = "text", "CENTER"
    c3.style = "bars"
    local c2 = NS.Database.FindContainer(2)
    c2.style = "icons"
    c2.attach.mode, c2.attach.container = "container", 3
    -- Under a Text parent justified CENTER an icons child's Automatic is after-center (G3).
    local point, rel = NS.Anchors.EdgePoints(c1.layout, "after-center")
    -- red under: Automatic read off c2 as stored (attached to 3, a bars parent: after-start)
    local cp, rp = NS.Anchors.Snap.FoldPoints(c2, 1, point, rel)
    assertNil(cp)
    assertNil(rp)
    assertEqual(c2.attach.container, 3, "the stored config is not touched")
end)

-- ── constants ─────────────────────────────────────────────────────────────────────────────────

test("snap: the radius is 24 UIParent units and the highlight is an opaque green", function()
    local NS = fresh()
    local C = NS.Constants
    -- red under: no C.SNAP_RADIUS / C.SNAP_COLOR
    assertEqual(C.SNAP_RADIUS, 24)
    local col = C.SNAP_COLOR
    assertTrue(type(col) == "table" and col.g > col.r and col.g > col.b, "green")
    assertEqual(col.a, 1)
    assertFalse(col.r > 0.5, "not yellow")
end)
