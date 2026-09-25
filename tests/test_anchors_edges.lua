-- tests/test_anchors_edges.lua - the nine sides of batch 9's edge model (AP-1, AP-2, E2), each a token
-- "<side>-<align>" relative to the chain's flow: after (the vertical growth side), ahead (the
-- horizontal growth side) or behind (the side lines start from), and start, center or end along it.
-- Since batch 11 a container joins its parent by two absolute points (tests/test_anchors_points.lua)
-- and a pair that is one of the nine keeps that side's seam and room; `after-start` is exactly the
-- points every attachment had before batch 9. Nothing is refused any more (G1, G5).
-- Its own suite because tests/test_anchors.lua sits near layout-§1's 1500-line cap.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")

--- The points before batch 9 (565fc38, B8-P4): the only pair an attachment could have. Kept here
--- verbatim as the no-visual-change pin's reference.
local function oldDerivedPoints(L)
    local h = (L.growH ~= "left") and "LEFT" or "RIGHT"
    if L.growV ~= "up" then return "TOP" .. h, "BOTTOM" .. h end
    return "BOTTOM" .. h, "TOP" .. h
end

-- The design's point table (findings, design section 1): token -> child point, parent point, per
-- growth down/right, down/left, up/right, up/left.
local TABLE = {
    ["after-start"]   = { "TOPLEFT>BOTTOMLEFT", "TOPRIGHT>BOTTOMRIGHT", "BOTTOMLEFT>TOPLEFT", "BOTTOMRIGHT>TOPRIGHT" },
    ["after-center"]  = { "TOP>BOTTOM", "TOP>BOTTOM", "BOTTOM>TOP", "BOTTOM>TOP" },
    ["after-end"]     = { "TOPRIGHT>BOTTOMRIGHT", "TOPLEFT>BOTTOMLEFT", "BOTTOMRIGHT>TOPRIGHT", "BOTTOMLEFT>TOPLEFT" },
    ["ahead-start"]   = { "TOPLEFT>TOPRIGHT", "TOPRIGHT>TOPLEFT", "BOTTOMLEFT>BOTTOMRIGHT", "BOTTOMRIGHT>BOTTOMLEFT" },
    ["ahead-center"]  = { "LEFT>RIGHT", "RIGHT>LEFT", "LEFT>RIGHT", "RIGHT>LEFT" },
    ["ahead-end"]     = { "BOTTOMLEFT>BOTTOMRIGHT", "BOTTOMRIGHT>BOTTOMLEFT", "TOPLEFT>TOPRIGHT", "TOPRIGHT>TOPLEFT" },
    ["behind-start"]  = { "TOPRIGHT>TOPLEFT", "TOPLEFT>TOPRIGHT", "BOTTOMRIGHT>BOTTOMLEFT", "BOTTOMLEFT>BOTTOMRIGHT" },
    ["behind-center"] = { "RIGHT>LEFT", "LEFT>RIGHT", "RIGHT>LEFT", "LEFT>RIGHT" },
    ["behind-end"]    = { "BOTTOMRIGHT>BOTTOMLEFT", "BOTTOMLEFT>BOTTOMRIGHT", "TOPRIGHT>TOPLEFT", "TOPLEFT>TOPRIGHT" },
}
local GROWTHS = { { "right", "down" }, { "left", "down" }, { "right", "up" }, { "left", "up" } }

--- Record every SetPoint made on a container's anchor.
local function recordAnchor(inst)
    local rec = {}
    rawset(inst.anchor, "SetPoint", function(_, ...) table.insert(rec, { ... }) end)
    rawset(inst.anchor, "ClearAllPoints", function() end)
    return rec
end

--- Store `edge` on attached container `c` as the explicit pair it gives under the chain's growth now
--- (batch 11: a side is two absolute points); nil leaves both Automatic.
local function setEdge(NS, c, edge)
    if edge == nil then
        c.attach.childPoint, c.attach.relPoint = nil, nil
        return
    end
    c.attach.childPoint, c.attach.relPoint = NS.Anchors.EdgePoints(NS.Anchors.EffectiveLayout(c), edge)
end

--- Container 2 attached to container 1 on `edge`, straight into the store, 1 flowing by `axis`,
--- `growH`, `growV`; 2 one wide (columns, one line) with spacing 3 and line spacing 5.
local function sided(NS, edge, axis, growH, growV)
    local L1 = NS.Database.FindContainer(1).layout
    L1.axis, L1.growH, L1.growV = axis or "vertical", growH or "right", growV or "down"
    local c2 = NS.Database.FindContainer(2)
    c2.attach.mode, c2.attach.container, c2.attach.x, c2.attach.y = "container", 1, 0, 0
    c2.layout.perLine, c2.layout.spacing, c2.layout.lineSpacing = 0, 3, 5
    setEdge(NS, c2, edge)
    return c2
end

--- Place container 2 and answer its last SetPoint.
local function placed(NS)
    local inst = NS.ContainerManager.instances[2]
    local rec = recordAnchor(inst)
    NS.Anchors.Place(inst)
    return rec[#rec]
end

test("edges: EDGES lists the nine tokens, after then ahead then behind, and no before or center side", function()
    local NS = fresh()
    -- red under: no Anchors.EDGES (AP-1)
    assertEqual(table.concat(NS.Anchors.EDGES, ","),
        "after-start,after-center,after-end,ahead-start,ahead-center,ahead-end,behind-start,behind-center,behind-end")
    local side, align = NS.Anchors.ParseEdge("ahead-end")
    assertEqual(side, "ahead"); assertEqual(align, "end")
    for _, junk in ipairs({ "before-start", "center", "", "after", 7 }) do
        side, align = NS.Anchors.ParseEdge(junk)
        assertEqual(side .. "-" .. align, "after-start", "unknown " .. tostring(junk))
    end
end)

test("edges: EdgePoints gives the design table's pair for every token and growth", function()
    local NS = fresh()
    for token, row in pairs(TABLE) do
        for i, g in ipairs(GROWTHS) do
            local p, rp = NS.Anchors.EdgePoints({ axis = "vertical", growH = g[1], growV = g[2] }, token)
            local what = token .. " " .. g[1] .. "/" .. g[2]
            -- red under: no EdgePoints, or a mirrored pair
            assertEqual(p .. ">" .. rp, row[i], what)
        end
    end
end)

test("edges: EdgePoints(L, 'after-start') is exactly the old DerivedPoints for all 8 axis, growH and growV combinations", function()
    local NS = fresh()
    local n = 0
    for _, axis in ipairs({ "vertical", "horizontal" }) do
        for _, g in ipairs(GROWTHS) do
            local L = { axis = axis, growH = g[1], growV = g[2] }
            local op, orp = oldDerivedPoints(L)
            local p, rp = NS.Anchors.EdgePoints(L, "after-start")
            local what = axis .. "/" .. g[1] .. "/" .. g[2]
            -- red under: after-start drifting from the points every stored attachment had (MG-1's
            -- stamp would move a chain)
            assertEqual(p, op, what); assertEqual(rp, orp, what)
            local dp, drp = NS.Anchors.DerivedPoints(L)
            assertEqual(dp, op, what .. " DerivedPoints"); assertEqual(drp, orp, what .. " DerivedPoints")
            n = n + 1
        end
    end
    assertEqual(n, 8)
end)

test("edges: every one of the nine is allowed, behind on a wide child too; only a non-token is not (G5)", function()
    local NS = fresh()
    local A = NS.Anchors
    local c2 = sided(NS, "after-start")
    c2.layout.perLine = 3
    NS.Database.FindContainer(1).layout.axis = "horizontal"
    for _, token in ipairs(A.EDGES) do
        -- red under: batch 9's behind restriction (E2)
        assertTrue(A.EdgeAllowed(c2, token), token .. " on a wide child")
    end
    assertFalse(A.EdgeAllowed(c2, "before-start"), "no before side exists")
end)

test("edges: SeamOffset leaves the child's own gap across for a side, and after is unchanged (AP-2)", function()
    local NS = fresh()
    local S = NS.Anchors.SeamOffset
    local col = { axis = "vertical", growH = "right", growV = "down", spacing = 3, lineSpacing = 5 }
    local row = { axis = "horizontal", growH = "right", growV = "down", spacing = 3, lineSpacing = 5 }
    local x, y = S(col, "ahead")
    -- red under: a side seam taken along the chain (SS-1's vertical gap)
    assertEqual(x, 5, "a column child: its line spacing across"); assertEqual(y, 0)
    x, y = S(row, "ahead")
    assertEqual(x, 3, "a row child: its spacing across"); assertEqual(y, 0)
    x, y = S(col, "behind")
    assertEqual(x, -5, "behind is negated"); assertEqual(y, 0)
    col.growH = "left"
    x = S(col, "ahead"); assertEqual(x, -5, "growH left mirrors ahead")
    x = S(col, "behind"); assertEqual(x, 5, "and behind")
    x, y = S(row, "after")
    assertEqual(x, 0); assertEqual(y, -5, "after is SS-1's")
    x, y = S(row)
    assertEqual(x, 0); assertEqual(y, -5, "no side reads after")
    col.lineSpacing = -2
    x = S(col, "ahead"); assertEqual(x, 0, "never negative")
end)

test("edges: a side-attached child is placed at its edge's points with its gap across and the nudge on top", function()
    local NS = fresh()
    local c2 = sided(NS, "ahead-start")
    local p = placed(NS)
    -- red under: attachSpec ignoring the stored points (TOPLEFT to BOTTOMLEFT)
    assertEqual(p[1], "TOPLEFT"); assertEqual(p[3], "TOPRIGHT")
    assertEqual(p[4], 5); assertEqual(p[5], 0)
    c2.attach.x, c2.attach.y = 2, -1
    p = placed(NS)
    assertEqual(p[4], 7, "the nudge adds on top (SS-2)"); assertEqual(p[5], -1)
    c2.attach.x, c2.attach.y = 0, 0
    setEdge(NS, c2, "behind-center")
    p = placed(NS)
    assertEqual(p[1], "RIGHT"); assertEqual(p[3], "LEFT"); assertEqual(p[4], -5)
    setEdge(NS, c2, "after-center")
    p = placed(NS)
    -- T9: the parent is one column, so its BOTTOM is held steady as its start side plus half its width
    local w = NS.Style.ElementSize(NS.Database.FindContainer(1))
    assertEqual(p[1], "TOP"); assertEqual(p[3], "BOTTOMLEFT"); assertEqual(p[4], w / 2); assertEqual(p[5], -3)
end)

test("edges: flipping the root's growth mirrors an Automatic child; an explicit pair stays and takes the seam of the side it now is", function()
    local NS = fresh()
    local c2 = sided(NS, nil)
    NS.Database.FindContainer(1).layout.growH = "left"
    local p = placed(NS)
    -- red under: an Automatic pair frozen at the growth it was attached under
    assertEqual(p[1], "TOPRIGHT"); assertEqual(p[3], "BOTTOMRIGHT")
    assertNil(c2.attach.childPoint, "nothing written"); assertNil(c2.attach.relPoint, "nothing written")
    NS.Database.FindContainer(1).layout.growH = "right"
    setEdge(NS, c2, "ahead-start")
    NS.Database.FindContainer(1).layout.growH = "left"
    p = placed(NS)
    -- absolute points (G2): TOPLEFT to TOPRIGHT growing left is behind-start, its gap away from growH
    assertEqual(p[1], "TOPLEFT"); assertEqual(p[3], "TOPRIGHT"); assertEqual(p[4], 5)
end)

test("edges: a side-attached follower of a follower takes no strip room; an after one does (AP-2)", function()
    local NS, mocks = fresh()
    for id = 1, 3 do NS.SetByPath("container.style", "text", id) end
    for _, pair in ipairs({ { 2, 1 }, { 3, 2 } }) do
        NS.SetByPath("container.attach.x", 0, pair[1])
        NS.SetByPath("container.attach.y", 0, pair[1])
        NS.SetByPath("container.attach.container", pair[2], pair[1])
        NS.SetByPath("container.attach.mode", "container", pair[1])
    end
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    local inst = NS.ContainerManager.instances[3]
    local rec = recordAnchor(inst)
    NS.Anchors.Place(inst)
    local spacing = NS.Database.FindContainer(3).layout.spacing
    assertTrue(rec[#rec][5] < -spacing, "after: the seam widened for its own strip (batch 10 F2)")
    setEdge(NS, NS.Database.FindContainer(3), "ahead-start")
    NS.Anchors.Place(inst)
    -- red under: the after room (seamRoom) applied to a side seam: 2's strip fits its own block
    assertEqual(rec[#rec][5], 0, "ahead: no strip room along the chain")
end)

test("edges: the default side follows a Text container's justify; a bars child under a bars parent is after-start (E5, G3)", function()
    local NS = fresh()
    local A = NS.Anchors
    local c2 = sided(NS, "after-start")
    c2.style = "bars"
    assertEqual(A.DefaultEdge(c2), "after-start")
    c2.style = "text"
    local cases = { LEFT = "after-start", CENTER = "after-center", RIGHT = "after-end" }
    for j, want in pairs(cases) do
        c2.text.justifyH = j
        -- red under: no DefaultEdge, or one blind to the justify
        assertEqual(A.DefaultEdge(c2), want, j)
    end
    NS.Database.FindContainer(1).layout.growH = "left"
    c2.text.justifyH = "RIGHT"
    assertEqual(A.DefaultEdge(c2), "after-start", "growing left, the lines start from the right")
    c2.text.justifyH = "LEFT"
    assertEqual(A.DefaultEdge(c2), "after-end")
end)

--- Container 2 a Text container of `justify`, on the screen, flushed.
local function textChild(justify)
    local NS, mocks = fresh()
    NS.SetByPath("container.style", "text", 2)
    NS.SetByPath("container.text.justifyH", justify, 2)
    mocks.__fireTimers()
    return NS, mocks, NS.Database.FindContainer(2)
end

test("edges: an attachment writes no points: a centered Text container attaches Automatic, on after-center (G2, G3)", function()
    local NS, _, c2 = textChild("CENTER")
    NS.SetByPath("container.attach.container", 1, 2)
    NS.SetByPath("container.attach.mode", "container", 2)
    -- red under: batch 9's new-attachment stamp (AP-4) writing a pick
    assertNil(c2.attach.childPoint); assertNil(c2.attach.relPoint)
    local p, rp = NS.Anchors.AttachPoints(c2)
    assertEqual(p .. ">" .. rp, "TOP>BOTTOM", "Automatic: after-center")
    assertNil(c2.attach.edge, "no side is stored")
end)

test("edges: picked points survive an attach, a retarget and a detach and re-attach", function()
    local NS, _, c2 = textChild("RIGHT")
    c2.attach.childPoint, c2.attach.relPoint = "LEFT", "RIGHT"
    NS.SetByPath("container.attach.container", 1, 2)
    NS.SetByPath("container.attach.mode", "container", 2)
    -- red under: an attachment resetting what the player picked
    assertEqual(c2.attach.childPoint .. ">" .. c2.attach.relPoint, "LEFT>RIGHT")
    NS.SetByPath("container.attach.container", 3, 2)
    assertEqual(c2.attach.childPoint .. ">" .. c2.attach.relPoint, "LEFT>RIGHT", "a retarget")
    NS.SetByPath("container.attach.mode", "screen", 2)
    NS.SetByPath("container.attach.mode", "container", 2)
    assertEqual(c2.attach.childPoint .. ">" .. c2.attach.relPoint, "LEFT>RIGHT", "a detach and re-attach")
end)

test("edges: a write to either point, the mode or the container re-applies the followers and the parents (AP-4)", function()
    local NS, mocks = fresh()
    local A, CM = NS.Anchors, NS.ContainerManager
    assertTrue(A.MovesFollowers("container.attach.childPoint"), "attach.childPoint")
    assertTrue(A.MovesFollowers("container.attach.relPoint"), "attach.relPoint")
    NS.SetByPath("container.attach.container", 1, 2)
    NS.SetByPath("container.attach.mode", "container", 2)
    mocks.__fireTimers()
    local applied = {}
    local real = CM.RequestApply
    CM.RequestApply = function(id, ...)
        local n = #applied
        applied[n + 1] = id
        return real(id, ...)
    end
    local function saw(id)
        for _, v in ipairs(applied) do if v == id then return true end end
        return false
    end
    NS.SetByPath("container.attach.container", 3, 2)
    -- red under: no requestParents (the parent's strip side depends on its followers' sides)
    assertTrue(saw(1), "the old parent")
    assertTrue(saw(3), "the new parent")
    applied = {}
    NS.SetByPath("container.attach.mode", "screen", 2)
    assertTrue(saw(3), "a detach re-applies the parent it left")
    CM.RequestApply = real
end)

-- ── growth conflicts on attach (batch 9 GC-1, E3) ─────────────────────────────────────────────
-- Attaching keeps inheritance: the child flows like its chain root, and its own Growth settings are
-- kept for a detach. FlowChangeOnAttach tells the panel (and /am set's chat line) what would change.

test("anchors: FlowChangeOnAttach is nil when nothing would change or nothing is usable", function()
    local NS = fresh()
    local A, DB = NS.Anchors, NS.Database
    -- 4 fills columns growing right and down, as 1 does.
    -- red under: no FlowChangeOnAttach (GC-1)
    assertEqual(A.FlowChangeOnAttach(DB.FindContainer(4), 1), nil, "the same flow")
    local c2 = DB.FindContainer(2)
    assertEqual(A.FlowChangeOnAttach(c2, 0), nil, "None")
    assertEqual(A.FlowChangeOnAttach(c2, 2), nil, "itself")
    assertEqual(A.FlowChangeOnAttach(c2, 99), nil, "a missing container")
    NS.SetByPath("container.attach.container", 2, 4)
    NS.SetByPath("container.attach.mode", "container", 4)
    -- red under: no loop check (2 onto 4 closes 2 -> 4 -> 2, which falls back to the screen)
    assertEqual(A.FlowChangeOnAttach(c2, 4), nil, "a loop")
end)

test("anchors: FlowChangeOnAttach names the keys that change and the followers that re-flow too", function()
    local NS = fresh()
    local A, DB = NS.Anchors, NS.Database
    NS.SetByPath("container.attach.container", 2, 3)
    NS.SetByPath("container.attach.mode", "container", 3)
    -- 2 fills rows growing left and down; 1 columns growing right and down.
    local change = A.FlowChangeOnAttach(DB.FindContainer(2), 1)
    assertTrue(change ~= nil, "a change")
    assertEqual(change.root.id, 1, "the root")
    assertEqual(table.concat(change.keys, ","), "axis,growH", "the keys, in FLOW_KEYS order")
    -- red under: followers not counted (3 follows 2, so it re-flows too)
    assertEqual(change.followers, 1, "3 follows 2")
    local own = DB.FindContainer(2).layout
    assertEqual(own.axis .. own.growH .. own.growV, "horizontalleftdown", "nothing written")
end)

test("anchors: FlowChangeOnAttach compares with the target's chain root, not the target", function()
    local NS = fresh()
    local A, DB = NS.Anchors, NS.Database
    NS.SetByPath("container.layout.growV", "up", 1)
    NS.SetByPath("container.attach.container", 1, 4)
    NS.SetByPath("container.attach.mode", "container", 4)
    -- 4's own flow is columns, right, down; it follows 1, which grows up.
    local change = A.FlowChangeOnAttach(DB.FindContainer(2), 4)
    -- red under: comparing with the target's own layout (growV would match 4's stored down)
    assertEqual(change.root.id, 1, "the root, not the target")
    assertEqual(table.concat(change.keys, ","), "axis,growH,growV")
end)
