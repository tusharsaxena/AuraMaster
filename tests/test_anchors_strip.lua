-- tests/test_anchors_strip.lua - the marks that make an attachment unambiguous (batch 9 SEP-1,
-- SEP-2, E4), and a side follower's strip (SEP-3 as batch 10 F4 leaves it). The strip's tooltip names
-- each join, and no dot marks it on screen (batch 11 G6 removed SEP-2's gold diamond); in test mode
-- each container's outline encloses its whole placeholder block. Batch 9's StripSide, which put an after follower's strip
-- beside or inside its first element, is gone: every strip sits before its own block
-- (tests/test_anchors_column.lua).
-- Its own suite because tests/test_anchors.lua sits near layout-§1's 1500-line cap.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")

--- Container 1 flows by `axis`, `growH`, `growV`; every other container is one aura wide.
local function rootFlow(NS, axis, growH, growV)
    local L = NS.Database.FindContainer(1).layout
    L.axis, L.growH, L.growV = axis or "vertical", growH or "right", growV or "down"
    for id = 2, 4 do
        local c = NS.Database.FindContainer(id)
        c.layout.axis, c.layout.perLine = "vertical", 0
    end
end

--- Container `id` attached to container `to` on `edge`, straight into the store.
local function join(NS, id, to, edge)
    local c = NS.Database.FindContainer(id)
    c.attach.mode, c.attach.container, c.attach.x, c.attach.y = "container", to, 0, 0
    -- batch 11: a side is two absolute points under the chain's growth now; after-start is Automatic
    c.attach.childPoint, c.attach.relPoint = nil, nil
    if edge and edge ~= "after-start" then
        c.attach.childPoint, c.attach.relPoint = NS.Anchors.EdgePoints(NS.Anchors.EffectiveLayout(c), edge)
    end
    return c
end

local function cfgOf(NS, id) return NS.Database.FindContainer(id) end

-- ── where the strip sits ──────────────────────────────────────────────────────────────────────

local function pointOf(NS, id)
    local point, rel, x, y = NS.Anchors.StripPoints(cfgOf(NS, id))
    return table.concat({ point, rel, tostring(x), tostring(y) }, " ")
end

test("strip: a behind follower's strip sits before it, lined up with the edge that faces its parent, so it runs away from it", function()
    local NS = fresh()
    rootFlow(NS, "vertical", "right", "down")
    join(NS, 2, 1, "behind-start")
    -- red under: the root's H0-aligned strip (a label wider than 2 would run over 1)
    assertEqual(pointOf(NS, 2), "BOTTOMRIGHT TOPRIGHT 0 2")
    rootFlow(NS, "vertical", "left", "up")
    join(NS, 2, 1, "behind-start")   -- the points are absolute (batch 11 G2): behind-start growing left and up
    assertEqual(pointOf(NS, 2), "TOPLEFT BOTTOMLEFT 0 -2")
end)

--- Container `id`'s strip placed unlocked, its SetPoint calls and its anchor's clamp insets recorded.
local function placedStrip(NS, mocks, id)
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    local inst = NS.ContainerManager.instances[id]
    local rec = { points = {} }
    rawset(inst.handle, "SetPoint", function(_, ...) table.insert(rec.points, { ... }) end)
    rawset(inst.anchor, "SetClampRectInsets", function(_, l, r, t, b) rec.insets = { l, r, t, b } end)
    inst.clampInsets = nil
    NS.Anchors.UpdateHandle(inst, true)
    return rec, inst
end

test("strip: a behind follower's before strip clamps over its own column, not toward its parent", function()
    local NS, mocks = fresh()
    rootFlow(NS, "vertical", "right", "down")
    join(NS, 2, 1, "behind-start")
    local rec = placedStrip(NS, mocks, 2)
    local ins = rec.insets
    assertTrue(ins[3] > 0, "reaches up over the strip")
    -- red under: the overhang reaching right, over the parent
    assertEqual(ins[2], 0, "never toward the parent")
end)

test("strip: an icons label mirrors only for a behind follower, whose strip lines up with the edge facing its parent", function()
    local NS = fresh()
    rootFlow(NS, "vertical", "right", "down")
    for id = 1, 4 do NS.Database.FindContainer(id).style = "icons" end
    join(NS, 2, 1)
    -- red under: batch 9's mirror for a label behind the first element
    assertEqual(NS.Anchors.LabelJustify(cfgOf(NS, 2)), "LEFT", "after: on its own block, toward it")
    join(NS, 3, 2, "behind-start")
    assertEqual(NS.Anchors.LabelJustify(cfgOf(NS, 2)), "LEFT", "a behind follower of its own changes nothing")
    assertEqual(NS.Anchors.LabelJustify(cfgOf(NS, 3)), "RIGHT", "a behind follower's before strip runs away from its parent")
    join(NS, 3, 1, "ahead-start")
    assertEqual(NS.Anchors.LabelJustify(cfgOf(NS, 3)), "LEFT", "an ahead follower's before strip")
end)

-- ── no join dot (batch 11 G6), and the tooltip (SEP-2) ────────────────────────────────────────

test("strip: no join dot is built for a container joined to another, unlocked or in test mode", function()
    -- Every frame the client hands out records a turn of its textures (CreateTexture answers with
    -- the frame itself in the mock), so a diamond built anywhere, under any field name, shows here.
    local turned = 0
    local NS, mocks = fresh({ before = function(m)
        local create = m.CreateFrame
        m.CreateFrame = function(...)
            local f = create(...)
            rawset(f, "SetRotation", function(self) turned = turned + 1; return self end)
            return f
        end
    end })
    rootFlow(NS, "vertical", "right", "down")
    NS.SetByPath("container.attach.container", 1, 2)
    NS.SetByPath("container.attach.mode", "container", 2)
    local at = NS.Database.FindContainer(2).attach
    at.childPoint, at.relPoint = "TOPLEFT", "TOPRIGHT"   -- ahead-start
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    local two = NS.ContainerManager.instances[2]
    NS.Anchors.UpdateHandle(two, true)
    NS.State.testMode = true
    NS.Anchors.UpdateHandle(two, true)
    NS.State.testMode = false
    -- red under: the gold diamond join pin (batch 9 SEP-2) built on the child's anchor
    assertEqual(turned, 0, "no texture turned into a diamond")
    assertTrue(two.joinPin == nil, "no join pin")
    assertTrue(two.handle:IsShown(), "the strip still shows")
end)

test("strip: the tooltip of a container joined to another names the parent's point and the parent", function()
    local NS, mocks = fresh()
    rootFlow(NS, "vertical", "right", "down")
    NS.SetByPath("container.attach.container", 1, 2)
    NS.SetByPath("container.attach.mode", "container", 2)
    local at = NS.Database.FindContainer(2).attach
    at.childPoint, at.relPoint = "TOP", "BOTTOM"   -- after-center
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    local lines = {}
    rawset(mocks.GameTooltip, "AddLine", function(_, s) table.insert(lines, s) end)
    NS.ContainerManager.instances[2].handle:__fire("OnEnter")
    local want = NS.L["Joined to the %s of '%s'. Change the anchor points on Layout > Anchor."]
        :format(NS.L["Bottom"], NS.Database.FindContainer(1).name)
    -- red under: the generic "Attached" line
    assertEqual(lines[2], want)
    -- red under: "Drag to move" on a follower a drag cannot move (owner, 2026-09-26)
    assertEqual(lines[1], NS.L["Anchored to '%s', so it cannot be dragged. Right-click for settings."]
        :format(NS.Database.FindContainer(1).name))
end)

-- ── the test-mode block outline (SEP-1) ───────────────────────────────────────────────────────

test("strip: in test mode the outline encloses the whole placeholder block, locked or not; locked outside it, none", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    NS.Preview.SetTestMode(true)
    mocks.__fireTimers()
    local o = inst.outline
    -- red under: ApplyOutline gated off while previewing
    assertTrue(o ~= nil and o:IsShown(), "locked in test mode: the block is outlined")
    local all = {}
    rawset(o, "SetAllPoints", function(_, f) table.insert(all, f) end)
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    assertTrue(o:IsShown(), "unlocked in test mode")
    assertTrue(all[#all] == inst.previewExtent, "around the preview extent")
    NS.Preview.SetTestMode(false)
    NS.SetByPath("locked", true)
    mocks.__fireTimers()
    assertFalse(o:IsShown(), "locked outside test mode: none")
end)

test("strip: the test-mode outline moves no follower: the seam is the same locked and in test mode (SS-3)", function()
    local NS, mocks = fresh()
    NS.SetByPath("container.attach.x", 0, 2)
    NS.SetByPath("container.attach.y", 0, 2)
    NS.SetByPath("container.attach.container", 1, 2)
    NS.SetByPath("container.attach.mode", "container", 2)
    mocks.__fireTimers()
    local two = NS.ContainerManager.instances[2]
    local rec = {}
    rawset(two.anchor, "SetPoint", function(_, ...) table.insert(rec, { ... }) end)
    NS.Anchors.Place(two)
    local locked = rec[#rec]
    NS.Preview.SetTestMode(true)
    mocks.__fireTimers()
    NS.Anchors.Place(two)
    local previewing = rec[#rec]
    -- the outline is not an attach target: the seam is the locked one (SS-3)
    assertEqual(previewing[4], locked[4]); assertEqual(previewing[5], locked[5])
end)
