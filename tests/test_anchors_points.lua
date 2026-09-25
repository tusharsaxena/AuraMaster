-- tests/test_anchors_points.lua - batch 11 G2, G3, G5: a container attached to another is joined by
-- two absolute points, `attach.childPoint` (its own) and `attach.relPoint` (its parent's), each nil
-- for Automatic. Automatic takes the matching half of the default pair (G3): the batch 9 after side
-- under the parent's growth, at an align picked from the two containers' styles. The pair in effect
-- is classified: one of the nine batch 9 tokens behaves exactly as batch 10 (seam, spread, push);
-- any other pair is free, placed at X/Y alone. Nothing is refused (G1, G5).
-- Its own suite because tests/test_anchors.lua sits near layout-§1's 1500-line cap.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")

local STRIP_H, STRIP_GAP = 18, 2
local ROW = STRIP_H + STRIP_GAP

local GROWTHS = { { "right", "down" }, { "left", "down" }, { "right", "up" }, { "left", "up" } }

--- Container 2 attached to container 1 in the store, 1 flowing by `growH`/`growV` in a column, 2
--- one aura wide with spacing 3 and line spacing 5, both points Automatic, no nudge.
local function joined(NS, growH, growV)
    local L1 = NS.Database.FindContainer(1).layout
    L1.axis, L1.growH, L1.growV = "vertical", growH or "right", growV or "down"
    local c2 = NS.Database.FindContainer(2)
    c2.attach.mode, c2.attach.container, c2.attach.x, c2.attach.y = "container", 1, 0, 0
    c2.attach.childPoint, c2.attach.relPoint = nil, nil
    c2.layout.axis, c2.layout.perLine, c2.layout.spacing, c2.layout.lineSpacing = "vertical", 0, 3, 5
    return c2
end

--- Container `id`'s last SetPoint after one Place.
local function placed(NS, id)
    local inst = NS.ContainerManager.instances[id or 2]
    local rec = {}
    rawset(inst.anchor, "SetPoint", function(_, ...) table.insert(rec, { ... }) end)
    rawset(inst.anchor, "ClearAllPoints", function() end)
    NS.Anchors.Place(inst)
    return rec[#rec], inst
end

--- The pair `token` gives under a column growing `g`.
local function pairOf(NS, token, g)
    local p, rp = NS.Anchors.EdgePoints({ axis = "vertical", growH = g[1], growV = g[2] }, token)
    return p .. ">" .. rp
end

local function effective(NS, c)
    local p, rp = NS.Anchors.AttachPoints(c)
    return p .. ">" .. rp
end

-- ── G3: the default pair ──────────────────────────────────────────────────────────────────────

test("points: a bars or icons child under a bars or icons parent defaults to after-start, under every growth", function()
    for _, g in ipairs(GROWTHS) do
        for _, styles in ipairs({ { "bars", "bars" }, { "icons", "bars" }, { "bars", "icons" }, { "icons", "icons" } }) do
            local NS = fresh()
            local c2 = joined(NS, g[1], g[2])
            c2.style, NS.Database.FindContainer(1).style = styles[1], styles[2]
            local what = styles[1] .. " under " .. styles[2] .. " " .. g[1] .. "/" .. g[2]
            -- red under: no AttachPoints (G2)
            assertEqual(effective(NS, c2), pairOf(NS, "after-start", g), what)
            assertEqual(NS.Anchors.DefaultEdge(c2), "after-start", what)
        end
    end
end)

test("points: an icons or bars child under a Text parent justified CENTER is centered; LEFT or RIGHT is not", function()
    for _, g in ipairs(GROWTHS) do
        for _, style in ipairs({ "icons", "bars" }) do
            local NS = fresh()
            local c2 = joined(NS, g[1], g[2])
            c2.style = style
            local c1 = NS.Database.FindContainer(1)
            c1.style, c1.text.justifyH = "text", "CENTER"
            local what = style .. " " .. g[1] .. "/" .. g[2]
            -- red under: a default blind to the parent's style (batch 9 E5 looked at the child only)
            assertEqual(effective(NS, c2), pairOf(NS, "after-center", g), what)
            c1.text.justifyH = "RIGHT"
            assertEqual(effective(NS, c2), pairOf(NS, "after-start", g), what .. " under RIGHT")
            c1.text.justifyH, c1.style = "CENTER", "bars"
            assertEqual(effective(NS, c2), pairOf(NS, "after-start", g), what .. " under a bars parent")
        end
    end
end)

test("points: a Text child lines up with its own justify, whatever the parent, and flips with growH", function()
    for _, g in ipairs(GROWTHS) do
        for _, parentStyle in ipairs({ "bars", "text" }) do
            local NS = fresh()
            local c2 = joined(NS, g[1], g[2])
            c2.style = "text"
            local c1 = NS.Database.FindContainer(1)
            c1.style, c1.text.justifyH = parentStyle, "CENTER"
            local startSide = (g[1] == "right") and "LEFT" or "RIGHT"
            local endSide = (g[1] == "right") and "RIGHT" or "LEFT"
            local what = parentStyle .. " " .. g[1] .. "/" .. g[2]
            c2.text.justifyH = "CENTER"
            assertEqual(effective(NS, c2), pairOf(NS, "after-center", g), what .. " CENTER")
            c2.text.justifyH = startSide
            -- red under: a Text child centered under a centered Text parent
            assertEqual(effective(NS, c2), pairOf(NS, "after-start", g), what .. " " .. startSide)
            c2.text.justifyH = endSide
            assertEqual(effective(NS, c2), pairOf(NS, "after-end", g), what .. " " .. endSide)
        end
    end
end)

test("points: the default follows the chain root's growth, not the child's own stored growth", function()
    local NS = fresh()
    local c2 = joined(NS, "left", "up")
    c2.layout.growH, c2.layout.growV = "right", "down"
    assertEqual(effective(NS, c2), "BOTTOMRIGHT>TOPRIGHT")
end)

-- ── G2: explicit points, each independent ─────────────────────────────────────────────────────

test("points: an explicit pair is used as stored, and does not mirror when the growth flips", function()
    local NS = fresh()
    local c2 = joined(NS)
    c2.attach.childPoint, c2.attach.relPoint = "BOTTOMLEFT", "TOPRIGHT"
    assertEqual(effective(NS, c2), "BOTTOMLEFT>TOPRIGHT")
    NS.Database.FindContainer(1).layout.growH = "left"
    -- red under: stored points read as a relative token
    assertEqual(effective(NS, c2), "BOTTOMLEFT>TOPRIGHT", "absolute: a flip moves nothing")
end)

test("points: one explicit point keeps the other automatic, as the matching half of the default pair", function()
    local NS = fresh()
    local c2 = joined(NS)
    c2.attach.childPoint = "CENTER"
    -- red under: an explicit child point dropping the automatic parent half
    assertEqual(effective(NS, c2), "CENTER>BOTTOMLEFT")
    c2.attach.childPoint, c2.attach.relPoint = nil, "RIGHT"
    assertEqual(effective(NS, c2), "TOPLEFT>RIGHT")
    local p, rp, pointAuto, relAuto = NS.Anchors.AttachPoints(c2)
    assertEqual(p .. ">" .. rp, "TOPLEFT>RIGHT")
    assertTrue(pointAuto, "the child point is automatic")
    assertFalse(relAuto, "the parent point is explicit")
end)

test("points: a stored point that is not one of the nine reads as Automatic", function()
    local NS = fresh()
    local c2 = joined(NS)
    c2.attach.childPoint, c2.attach.relPoint = "MIDDLE", 7
    assertEqual(effective(NS, c2), "TOPLEFT>BOTTOMLEFT")
end)

test("points: a stored attach.edge is not read outside the migration", function()
    local NS = fresh()
    local c2 = joined(NS)
    c2.attach.edge = "ahead-center"
    local p = placed(NS)
    -- red under: attachSpec still reading attach.edge
    assertEqual(p[1], "TOPLEFT"); assertEqual(p[3], "BOTTOMLEFT")
end)

-- ── G5: classification ────────────────────────────────────────────────────────────────────────

test("points: AttachEdge classifies the pair in effect as one of the nine tokens, or nil when free", function()
    local NS = fresh()
    local A = NS.Anchors
    local c2 = joined(NS)
    -- red under: no AttachEdge (G5)
    assertEqual(A.AttachEdge(c2), "after-start", "automatic")
    for _, g in ipairs(GROWTHS) do
        NS.Database.FindContainer(1).layout.growH, NS.Database.FindContainer(1).layout.growV = g[1], g[2]
        for _, token in ipairs(A.EDGES) do
            c2.attach.childPoint, c2.attach.relPoint = A.EdgePoints({ growH = g[1], growV = g[2] }, token)
            assertEqual(A.AttachEdge(c2), token, token .. " " .. g[1] .. "/" .. g[2])
        end
    end
    NS.Database.FindContainer(1).layout.growH, NS.Database.FindContainer(1).layout.growV = "right", "down"
    c2.attach.childPoint, c2.attach.relPoint = "BOTTOMLEFT", "BOTTOMLEFT"
    assertNil(A.AttachEdge(c2), "a pair none of the nine gives")
    c2.attach.childPoint, c2.attach.relPoint = "TOP", "BOTTOMLEFT"
    assertNil(A.AttachEdge(c2), "half of one token and half of another")
    c2.attach.childPoint, c2.attach.relPoint = "BOTTOMLEFT", "TOPLEFT"
    assertNil(A.AttachEdge(c2), "after-start growing up is free growing down")
end)

test("points: a classified explicit pair is placed exactly as batch 10 places its token", function()
    local NS = fresh()
    local c2 = joined(NS)
    c2.attach.childPoint, c2.attach.relPoint = "TOPLEFT", "TOPRIGHT"
    local p = placed(NS)
    -- red under: an explicit pair treated as free (no gap across)
    assertEqual(p[1], "TOPLEFT"); assertEqual(p[3], "TOPRIGHT")
    assertEqual(p[4], 5, "ahead: the child's line spacing across"); assertEqual(p[5], 0)
    c2.attach.childPoint, c2.attach.relPoint = "TOP", "BOTTOM"
    p = placed(NS)
    assertEqual(p[1], "TOP"); assertEqual(p[3], "BOTTOM"); assertEqual(p[4], 0); assertEqual(p[5], -3, "after: SS-1")
end)

test("points: behind is no longer refused: a child several auras wide sits on its behind pair", function()
    local NS = fresh()
    local A = NS.Anchors
    local c2 = joined(NS)
    c2.layout.perLine = 4
    c2.attach.childPoint, c2.attach.relPoint = "RIGHT", "LEFT"
    -- red under: EdgeAllowed still refusing behind to a wide child (batch 9 E2)
    assertTrue(A.EdgeAllowed(c2, "behind-center"), "allowed")
    assertEqual(A.AttachEdge(c2), "behind-center")
    local p = placed(NS)
    assertEqual(p[1], "RIGHT"); assertEqual(p[3], "LEFT"); assertEqual(p[4], -5)
end)

test("points: a free pair is placed at X/Y alone: no seam, no spread, no push", function()
    local NS, mocks = fresh()
    local c2 = joined(NS)
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    c2.attach.childPoint, c2.attach.relPoint = "BOTTOMLEFT", "BOTTOMLEFT"
    c2.attach.x, c2.attach.y = 4, -6
    local p, inst = placed(NS)
    -- red under: a seam or a spread added to a free pair (G5)
    assertEqual(p[1], "BOTTOMLEFT"); assertEqual(p[3], "BOTTOMLEFT")
    assertEqual(p[4], 4); assertEqual(p[5], -6)
    assertNil(inst.placedRoom, "no spread recorded, so RefreshSeam re-places nothing")
    c2.attach.childPoint, c2.attach.relPoint = "TOPLEFT", "TOPRIGHT"
    p = placed(NS)
    assertEqual(p[4], 9, "the same child classified ahead-start takes its gap across")
end)

test("points: an after pair spreads by the child's furniture while unlocked; the free pair beside it does not", function()
    local NS, mocks = fresh()
    local c2 = joined(NS)
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    local p = placed(NS)
    -- the automatic after-start pair: the seam plus one strip row
    assertEqual(p[5], -3 - ROW)
    c2.attach.childPoint = "BOTTOMLEFT"
    p = placed(NS)
    assertEqual(p[5], 0, "free: X/Y alone")
end)

test("points: a free follower's strip and label sit on its own before side, lined up with H0", function()
    local NS = fresh()
    local c2 = joined(NS)
    c2.attach.childPoint, c2.attach.relPoint = "BOTTOMRIGHT", "TOPLEFT"
    local point, rel, x, y = NS.Anchors.StripPoints(c2)
    -- red under: a free pair read as behind (the strip would line up with H1)
    assertEqual(point .. " " .. rel, "BOTTOMLEFT TOPLEFT")
    assertEqual(x, 0); assertEqual(y, STRIP_GAP)
    c2.style = "icons"
    assertEqual(NS.Anchors.LabelJustify(c2), "LEFT", "no mirror")
end)

test("points: a write to either point, a style or a text justify re-applies the followers", function()
    local NS = fresh()
    local A = NS.Anchors
    -- red under: FLOW_PATHS without the new paths (a parent's style and justify pick the default)
    for _, path in ipairs({ "container.attach.childPoint", "container.attach.relPoint", "container.style",
        "container.text.justifyH" }) do
        assertTrue(A.MovesFollowers(path), path)
    end
    assertFalse(A.MovesFollowers("container.attach.edge"), "no longer a path")
end)

test("points: AttachPoints and AttachEdge allocate nothing", function()
    local NS = fresh()
    local c2 = joined(NS)
    local c1 = NS.Database.FindContainer(1)
    c1.style, c1.text.justifyH = "text", "CENTER"
    NS.Anchors.AttachEdge(c2)
    collectgarbage("collect")
    collectgarbage("stop")
    local before = collectgarbage("count")
    for _ = 1, 200 do
        NS.Anchors.AttachPoints(c2)
        NS.Anchors.AttachEdge(c2)
    end
    local grew = collectgarbage("count") - before
    collectgarbage("restart")
    -- red under: a classification that builds a key string or a layout copy per call
    assertTrue(grew < 1, "allocated " .. grew .. " KB")
end)
