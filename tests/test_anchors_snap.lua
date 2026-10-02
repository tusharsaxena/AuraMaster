-- tests/test_anchors_snap.lua - issue #22, the snap core (DD-01): what a container dropped near
-- another snaps to. modules/Anchors_Snap.lua's pure core (Snap.PointAt, Snap.Nearest) picks the
-- nearest of the nine classified sides (C.ATTACH_EDGES) under the target's flow growth, within
-- C.SNAP_RADIUS (D1, D2); its eligibility keeps a container off itself, off anything that follows it
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

test("snap: Nearest picks the side whose two points meet, for each of the nine under each growth", function()
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
            -- red under: the pairs read under the dragged container's own growth, or a fixed one
            assertTrue(hit ~= nil, what)
            assertEqual(hit.token, token, what)
            assertEqual(hit.point .. ">" .. hit.relPoint, point .. ">" .. rel, what)
            assertEqual(hit.id, 7, what)
            assertTrue(math.abs(hit.dist - math.sqrt(5)) < 1e-9, what .. " dist")
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

test("snap: a tie keeps the first target in the order given, and the first side in ATTACH_EDGES order", function()
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
    -- A point-sized target and a zero-width child: TOPLEFT, TOP and TOPRIGHT are one point, so
    -- after-start, after-center, after-end and ahead-start all meet at distance 0.
    hit = Snap.Nearest(rectOf(50, 30, 50, 50),
        { { id = 4, rect = rectOf(50, 50, 50, 50), growH = "right", growV = "down" } }, 24)
    assertEqual(hit.token, "after-start", "first side")
    assertEqual(hit.dist, 0)
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
    plant(CM.instances[2].anchor, 250, 75, 270, 95)
    assertNil(NS.Anchors.Snap.Find(CM.instances[2]), "nothing within the radius")
    rawset(CM.instances[2].anchor, "GetLeft", nil)
    assertNil(NS.Anchors.Snap.Find(CM.instances[2]), "the dragged anchor unreadable")
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
