-- tests/test_anchors_edges.lua - the side a container attached to another sits on (batch 9 AP-1..AP-4,
-- E2, E5). The side is stored relative to the chain's flow as one token, `attach.edge` =
-- "<side>-<align>": after (the vertical growth side), ahead (the horizontal growth side) or behind
-- (the side lines start from), and start, center or end along it. The side the chain grows away from
-- is never offered, and behind only to a child one aura wide. `after-start` is exactly the points
-- every attachment had before, so the v9 stamp moves nothing.
-- Its own suite because tests/test_anchors.lua sits near layout-§1's 1500-line cap.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
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

--- Container 2 attached to container 1 on `edge`, straight into the store, 1 flowing by `axis`,
--- `growH`, `growV`; 2 one wide (columns, one line) with spacing 3 and line spacing 5.
local function sided(NS, edge, axis, growH, growV)
    local L1 = NS.Database.FindContainer(1).layout
    L1.axis, L1.growH, L1.growV = axis or "vertical", growH or "right", growV or "down"
    local c2 = NS.Database.FindContainer(2)
    c2.attach.mode, c2.attach.container, c2.attach.x, c2.attach.y = "container", 1, 0, 0
    c2.attach.edge = edge
    c2.layout.perLine, c2.layout.spacing, c2.layout.lineSpacing = 0, 3, 5
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

test("edges: after and ahead are always allowed; behind only for a child one aura wide, with a reason", function()
    local NS = fresh()
    local A = NS.Anchors
    local c2 = sided(NS, "after-start")
    for _, token in ipairs(A.EDGES) do
        assertTrue(A.EdgeAllowed(c2, token), token .. " on a one-wide column child")
    end
    c2.layout.perLine = 3
    for _, token in ipairs({ "behind-start", "behind-center", "behind-end" }) do
        local ok, why = A.EdgeAllowed(c2, token)
        -- red under: behind offered to a child that would grow back into its parent
        assertFalse(ok, token .. " with perLine 3")
        assertEqual(why, NS.L["That side needs this container to be one aura wide (Fill: Columns, Per row or column: 0), or it would grow back over the container it is attached to."])
    end
    assertTrue(A.EdgeAllowed(c2, "after-end")); assertTrue(A.EdgeAllowed(c2, "ahead-center"))
    c2.layout.perLine = 0
    NS.Database.FindContainer(1).layout.axis = "horizontal"
    assertFalse(A.EdgeAllowed(c2, "behind-center"), "the inherited axis is rows")
    assertFalse(A.EdgeAllowed(c2, "behind-center", { axis = "horizontal", perLine = 0 }), "an explicit layout")
    assertTrue(A.EdgeAllowed(c2, "behind-center", { axis = "vertical", perLine = 0 }))
    local ok, why = A.EdgeAllowed(c2, "before-start")
    assertFalse(ok, "no before side exists"); assertTrue(type(why) == "string" and why ~= "", "with a reason")
end)

test("edges: ResolvedEdge falls back to after-<align> at runtime, never writes, and restores on undo", function()
    local NS = fresh()
    local A = NS.Anchors
    local c2 = sided(NS, "behind-end")
    assertEqual(A.ResolvedEdge(c2), "behind-end")
    NS.Database.FindContainer(1).layout.axis = "horizontal"
    -- red under: a ResolvedEdge that trusts the store
    assertEqual(A.ResolvedEdge(c2), "after-end")
    assertEqual(c2.attach.edge, "behind-end", "the stored token kept")
    NS.Database.FindContainer(1).layout.axis = "vertical"
    assertEqual(A.ResolvedEdge(c2), "behind-end", "undoing the change restores the side")
    c2.attach.edge = "sideways"
    assertEqual(A.ResolvedEdge(c2), "after-start", "an unknown token")
    c2.attach.edge = nil
    assertEqual(A.ResolvedEdge(c2), "after-start", "nothing stored")
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
    -- red under: attachSpec ignoring the stored edge (TOPLEFT to BOTTOMLEFT)
    assertEqual(p[1], "TOPLEFT"); assertEqual(p[3], "TOPRIGHT")
    assertEqual(p[4], 5); assertEqual(p[5], 0)
    c2.attach.x, c2.attach.y = 2, -1
    p = placed(NS)
    assertEqual(p[4], 7, "the nudge adds on top (SS-2)"); assertEqual(p[5], -1)
    c2.attach.edge, c2.attach.x, c2.attach.y = "behind-center", 0, 0
    p = placed(NS)
    assertEqual(p[1], "RIGHT"); assertEqual(p[3], "LEFT"); assertEqual(p[4], -5)
    c2.attach.edge = "after-center"
    p = placed(NS)
    assertEqual(p[1], "TOP"); assertEqual(p[3], "BOTTOM"); assertEqual(p[4], 0); assertEqual(p[5], -3)
end)

test("edges: flipping the root's growth mirrors a side-attached child and writes nothing", function()
    local NS = fresh()
    local c2 = sided(NS, "ahead-start")
    NS.Database.FindContainer(1).layout.growH = "left"
    local p = placed(NS)
    -- red under: absolute stored points (the child would sit on the side the chain grows back over)
    assertEqual(p[1], "TOPRIGHT"); assertEqual(p[3], "TOPLEFT"); assertEqual(p[4], -5)
    assertEqual(c2.attach.edge, "ahead-start", "nothing written")
end)

test("edges: a disallowed stored side is placed at its after fallback", function()
    local NS = fresh()
    sided(NS, "behind-end")
    NS.Database.FindContainer(2).layout.perLine = 4
    local p = placed(NS)
    -- red under: attachSpec reading the stored token rather than ResolvedEdge
    assertEqual(p[1], "TOPRIGHT"); assertEqual(p[3], "BOTTOMRIGHT")
    assertEqual(p[4], 0); assertEqual(p[5], -3)
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
    assertTrue(rec[#rec][5] < -spacing, "after: the seam widened for 2's strip (EO-2)")
    NS.Database.FindContainer(3).attach.edge = "ahead-start"
    NS.Anchors.Place(inst)
    -- red under: clearStrip applied to a side seam
    assertEqual(rec[#rec][5], 0, "ahead: no strip room along the chain")
end)

test("edges: the default side of a new attachment follows a Text container's justify; every other style is after-start (E5)", function()
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

test("edges: attaching a centered Text container sets its side to after-center, by mode or by container (AP-4)", function()
    local NS, _, c2 = textChild("CENTER")
    NS.SetByPath("container.attach.container", 1, 2)
    assertEqual(c2.attach.edge, "after-start", "still on the screen: nothing set")
    NS.SetByPath("container.attach.mode", "container", 2)
    -- red under: no new-attachment default
    assertEqual(c2.attach.edge, "after-center", "the mode write made the attachment")
    NS.SetByPath("container.attach.mode", "screen", 2)
    NS.SetByPath("container.attach.edge", "after-start", 2)
    NS.SetByPath("container.attach.container", 0, 2)
    NS.SetByPath("container.attach.mode", "container", 2)
    assertEqual(c2.attach.edge, "after-start", "no usable target yet: nothing set")
    NS.SetByPath("container.attach.container", 3, 2)
    assertEqual(c2.attach.edge, "after-center", "the container write made the attachment")
end)

test("edges: a side picked before the attachment is kept; retargeting keeps the side", function()
    local NS, _, c2 = textChild("RIGHT")
    NS.SetByPath("container.attach.mode", "container", 2)
    NS.SetByPath("container.attach.edge", "ahead-center", 2)
    NS.SetByPath("container.attach.container", 1, 2)
    -- red under: the default overwriting a side the player chose for this attachment
    assertEqual(c2.attach.edge, "ahead-center")
    NS.SetByPath("container.attach.container", 3, 2)
    assertEqual(c2.attach.edge, "ahead-center", "a retarget is not a new attachment")
    NS.SetByPath("container.attach.mode", "screen", 2)
    NS.SetByPath("container.attach.mode", "container", 2)
    assertEqual(c2.attach.edge, "after-end", "a detach and re-attach is a new attachment")
end)

test("edges: a new attachment of a bars container stays after-start", function()
    local NS = fresh()
    local c2 = NS.Database.FindContainer(2)
    NS.SetByPath("container.attach.edge", "ahead-end", 2)
    NS.SetByPath("container.attach.container", 1, 2)
    NS.SetByPath("container.attach.mode", "container", 2)
    -- red under: a default written only for Text
    assertEqual(c2.attach.edge, "after-start", "picked on the screen: not a pick for this attachment")
end)

test("edges: the Side row refuses a side the child cannot take, with the reason, through /am set", function()
    local NS = fresh()
    sided(NS, "after-start")
    NS.Database.FindContainer(2).layout.perLine = 2
    local ok, err, why = NS.SetByPath("container.attach.edge", "behind-start", 2)
    -- red under: a Side row with no EdgeAllowed validate
    assertFalse(ok)
    assertTrue(type(err) == "string")
    assertEqual(why, NS.L["That side needs this container to be one aura wide (Fill: Columns, Per row or column: 0), or it would grow back over the container it is attached to."])
    assertEqual(NS.Database.FindContainer(2).attach.edge, "after-start")
    assertFalse((NS.SetByPath("container.attach.edge", "before-start", 2)), "no before side")
    assertTrue((NS.SetByPath("container.attach.edge", "ahead-end", 2)))
end)

test("edges: a write to the side, per-line count, mode or container re-applies the followers and the parents (AP-4)", function()
    local NS, mocks = fresh()
    local A, CM = NS.Anchors, NS.ContainerManager
    assertTrue(A.MovesFollowers("container.attach.edge"), "attach.edge")
    -- red under: FLOW_PATHS without layout.perLine (behind depends on it)
    assertTrue(A.MovesFollowers("container.layout.perLine"), "layout.perLine")
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
    NS.SetByPath("container.attach.edge", "ahead-start", 2)
    -- red under: no requestParents (the parent's strip side depends on its followers' sides)
    assertTrue(saw(1), "the edge write re-applies the parent")
    applied = {}
    NS.SetByPath("container.attach.container", 3, 2)
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
