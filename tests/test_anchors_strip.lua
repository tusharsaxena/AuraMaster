-- tests/test_anchors_strip.lua - which side of a container its drag strip sits on, and the marks that
-- make an attachment unambiguous (batch 9 SEP-1..SEP-3, E4). Anchors.StripSide replaces besideSeam:
-- a root keeps its strip before its first element (above it growing down); a follower attached on
-- the after side puts it behind that element, or ahead when a behind follower holds that side and it
-- is one aura wide, or inside the element's top band when both sides are taken; a follower on a side
-- puts it before, which the parent beside it leaves free. A strip never covers the parent and strips
-- never stack. While unlocked a gold diamond marks each join, and the strip's tooltip names it. In
-- test mode each container's outline encloses its whole placeholder block.
-- Its own suite because tests/test_anchors.lua sits near layout-§1's 1500-line cap.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")

local STRIP_H, STRIP_GAP = 18, 2

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
    c.attach.edge = edge or "after-start"
    return c
end

local function cfgOf(NS, id) return NS.Database.FindContainer(id) end

-- ── StripSide ─────────────────────────────────────────────────────────────────────────────────

test("strip: a root's strip is before its first element; an after follower's behind it", function()
    local NS = fresh()
    rootFlow(NS)
    join(NS, 2, 1)
    -- red under: no Anchors.StripSide
    assertEqual(NS.Anchors.StripSide(cfgOf(NS, 1)), "before")
    assertEqual(NS.Anchors.StripSide(cfgOf(NS, 2)), "behind")
    assertEqual(NS.Anchors.StripSide(nil), "before", "no settings")
end)

test("strip: an after follower whose behind side holds a follower moves ahead, or inside when that side is taken too", function()
    local NS = fresh()
    rootFlow(NS)
    join(NS, 2, 1)
    join(NS, 3, 2, "behind-start")
    -- red under: besideSeam's one side (the strip would sit under 3)
    assertEqual(NS.Anchors.StripSide(cfgOf(NS, 2)), "ahead")
    join(NS, 4, 2, "ahead-start")
    assertEqual(NS.Anchors.StripSide(cfgOf(NS, 2)), "inside", "both sides taken")
    join(NS, 4, 1)
    NS.Database.FindContainer(3).layout.perLine = 2
    -- 3 wraps its column now, so its behind is refused and it sits after: behind is free again.
    assertEqual(NS.Anchors.StripSide(cfgOf(NS, 2)), "behind", "a refused behind occupies nothing")
    NS.Database.FindContainer(3).layout.perLine = 0
    join(NS, 3, 2, "ahead-end")
    assertEqual(NS.Anchors.StripSide(cfgOf(NS, 2)), "behind", "an ahead follower leaves behind free")
end)

test("strip: an after follower wider than one aura with its behind side taken puts the strip inside", function()
    local NS = fresh()
    rootFlow(NS)
    join(NS, 2, 1)
    join(NS, 3, 2, "behind-start")
    NS.Database.FindContainer(2).layout.perLine = 2
    -- red under: an ahead strip for a container whose own rows run ahead
    assertEqual(NS.Anchors.StripSide(cfgOf(NS, 2)), "inside")
end)

test("strip: a follower on a side puts its strip before, the side its parent leaves free", function()
    local NS = fresh()
    rootFlow(NS)
    join(NS, 2, 1, "ahead-start")
    join(NS, 3, 1, "behind-center")
    -- red under: besideSeam (every follower beside its first element)
    assertEqual(NS.Anchors.StripSide(cfgOf(NS, 2)), "before")
    assertEqual(NS.Anchors.StripSide(cfgOf(NS, 3)), "before")
end)

test("strip: StripSide allocates nothing, so a repeat visibility pass costs nothing", function()
    local NS = fresh()
    rootFlow(NS)
    join(NS, 2, 1)
    join(NS, 3, 2, "behind-start")
    join(NS, 4, 2, "ahead-end")
    local c2 = cfgOf(NS, 2)
    NS.Anchors.StripSide(c2)
    collectgarbage("collect")
    collectgarbage("stop")
    local before = collectgarbage("count")
    for _ = 1, 200 do NS.Anchors.StripSide(c2) end
    local after = collectgarbage("count")
    collectgarbage("restart")
    -- red under: ResolvedEdge or EffectiveLayout per follower (each copies a layout)
    assertEqual(after - before, 0, "bytes allocated")
end)

-- ── where the strip sits ──────────────────────────────────────────────────────────────────────

local function pointOf(NS, id)
    local point, rel, x, y = NS.Anchors.StripPoints(cfgOf(NS, id))
    return table.concat({ point, rel, tostring(x), tostring(y) }, " ")
end

test("strip: StripPoints puts each side's strip where the design says, mirrored by the growth", function()
    local NS = fresh()
    local cases = {
        -- growH, growV, behind, ahead, inside
        { "right", "down", "TOPRIGHT TOPLEFT -2 0", "TOPLEFT TOPRIGHT 2 0", "TOPLEFT TOPLEFT 0 0" },
        { "left", "down", "TOPLEFT TOPRIGHT 2 0", "TOPRIGHT TOPLEFT -2 0", "TOPRIGHT TOPRIGHT 0 0" },
        { "right", "up", "BOTTOMRIGHT BOTTOMLEFT -2 0", "BOTTOMLEFT BOTTOMRIGHT 2 0", "BOTTOMLEFT BOTTOMLEFT 0 0" },
        { "left", "up", "BOTTOMLEFT BOTTOMRIGHT 2 0", "BOTTOMRIGHT BOTTOMLEFT -2 0", "BOTTOMRIGHT BOTTOMRIGHT 0 0" },
    }
    for _, c in ipairs(cases) do
        rootFlow(NS, "vertical", c[1], c[2])
        join(NS, 2, 1)
        join(NS, 3, 1, "ahead-start")
        join(NS, 4, 1, "ahead-end")
        local what = c[1] .. "/" .. c[2]
        assertEqual(pointOf(NS, 2), c[3], what .. " behind")
        join(NS, 3, 2, "behind-start")
        -- red under: the strip left behind the element, under 3
        assertEqual(pointOf(NS, 2), c[4], what .. " ahead")
        join(NS, 4, 2, "ahead-start")
        assertEqual(pointOf(NS, 2), c[5], what .. " inside")
    end
end)

test("strip: a behind follower's strip sits before it, lined up with the edge that faces its parent, so it runs away from it", function()
    local NS = fresh()
    rootFlow(NS, "vertical", "right", "down")
    join(NS, 2, 1, "behind-start")
    -- red under: the root's H0-aligned strip (a label wider than 2 would run over 1)
    assertEqual(pointOf(NS, 2), "BOTTOMRIGHT TOPRIGHT 0 2")
    rootFlow(NS, "vertical", "left", "up")
    assertEqual(pointOf(NS, 2), "TOPLEFT BOTTOMLEFT 0 -2")
end)

test("strip: an ahead follower of a root is pushed out past its parent's strip and label rows, so strips never stack", function()
    local NS, mocks = fresh()
    rootFlow(NS, "vertical", "right", "down")
    join(NS, 2, 1, "ahead-start")
    local row = STRIP_H + STRIP_GAP
    -- red under: the child's strip level with its parent's (a parent label wider than 1 covers it)
    assertEqual(pointOf(NS, 2), "BOTTOMLEFT TOPLEFT 0 " .. tostring(STRIP_GAP + row))
    NS.SetByPath("container.label.show", true, 1)
    mocks.__fireTimers()
    assertEqual(pointOf(NS, 2), "BOTTOMLEFT TOPLEFT 0 " .. tostring(STRIP_GAP + 2 * row), "and the label's row")
    rootFlow(NS, "vertical", "right", "up")
    assertEqual(pointOf(NS, 2), "TOPLEFT BOTTOMLEFT 0 " .. tostring(-(STRIP_GAP + 2 * row)), "growing up: downward")
    join(NS, 2, 1, "behind-start")
    assertEqual(pointOf(NS, 2), "TOPRIGHT BOTTOMRIGHT 0 -2", "behind: the parent's strip runs the other way")
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

test("strip: the clamp reaches out from whichever side the strip is on", function()
    local NS, mocks = fresh()
    rootFlow(NS, "vertical", "right", "down")
    join(NS, 2, 1)
    join(NS, 3, 2, "behind-start")
    local rec = placedStrip(NS, mocks, 2)
    local ins = rec.insets
    -- red under: clampBeside reaching out behind (left) for an ahead strip
    assertTrue(ins[2] > 0 and ins[1] == 0, "ahead: reaches right")
    assertEqual(ins[3], 0); assertEqual(ins[4], 0)
    join(NS, 4, 2, "ahead-start")
    rec = placedStrip(NS, mocks, 2)
    ins = rec.insets
    -- red under: an inside strip given the before side's vertical reach
    assertEqual(ins[3], 0, "inside: no reach up"); assertEqual(ins[4], 0, "nor down")
    local p = rec.points[#rec.points]
    assertEqual(p[1], "TOPLEFT"); assertEqual(p[3], "TOPLEFT")
end)

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

test("strip: an icons label mirrors wherever its strip sits on the far side of the element", function()
    local NS = fresh()
    rootFlow(NS, "vertical", "right", "down")
    for id = 1, 4 do NS.Database.FindContainer(id).style = "icons" end
    join(NS, 2, 1)
    assertEqual(NS.Anchors.LabelJustify(cfgOf(NS, 2)), "RIGHT", "behind: hugs the element on its right")
    join(NS, 3, 2, "behind-start")
    -- red under: LabelJustify reading besideSeam (an ahead label justified away from its element)
    assertEqual(NS.Anchors.LabelJustify(cfgOf(NS, 2)), "LEFT", "ahead")
    assertEqual(NS.Anchors.LabelJustify(cfgOf(NS, 3)), "RIGHT", "a behind follower's before strip runs away from its parent")
    join(NS, 3, 1, "ahead-start")
    assertEqual(NS.Anchors.LabelJustify(cfgOf(NS, 3)), "LEFT", "an ahead follower's before strip")
end)

test("strip: a follower of a side follower keeps its own seam unlocked: the side follower's strip is before it", function()
    local NS, mocks = fresh()
    rootFlow(NS, "vertical", "right", "down")
    for id = 1, 3 do NS.Database.FindContainer(id).style = "text" end
    join(NS, 2, 1, "ahead-start")
    join(NS, 3, 2)
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    local inst = NS.ContainerManager.instances[3]
    local rec = {}
    rawset(inst.anchor, "SetPoint", function(_, ...) table.insert(rec, { ... }) end)
    rawset(inst.anchor, "ClearAllPoints", function() end)
    NS.Anchors.Place(inst)
    -- red under: room made for a strip that sits above 2, away from 3
    assertEqual(rec[#rec][5], -NS.Database.FindContainer(3).layout.spacing)
end)

-- ── the join pin and the tooltip (SEP-2) ──────────────────────────────────────────────────────

test("strip: unlocked, a gold diamond marks the join at the child's attach point; locked, screen and frame show none", function()
    local NS, mocks = fresh()
    rootFlow(NS, "vertical", "right", "down")
    NS.SetByPath("container.attach.x", 0, 2)
    NS.SetByPath("container.attach.y", 0, 2)
    NS.SetByPath("container.attach.container", 1, 2)
    NS.SetByPath("container.attach.mode", "container", 2)
    NS.SetByPath("container.attach.edge", "ahead-start", 2)
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    local two = NS.ContainerManager.instances[2]
    local pin = two.joinPin
    -- red under: no join pin
    assertTrue(pin ~= nil and pin:IsShown(), "the pin shows")
    local rec = {}
    rawset(pin, "SetPoint", function(_, ...) table.insert(rec, { ... }) end)
    NS.Anchors.UpdateHandle(two, true)
    local p = rec[#rec]
    assertEqual(p[1], "CENTER"); assertTrue(p[2] == two.anchor, "on the child's anchor")
    assertEqual(p[3], "TOPLEFT", "the child's point for ahead-start")
    assertFalse(NS.ContainerManager.instances[1].joinPin ~= nil and NS.ContainerManager.instances[1].joinPin:IsShown(),
        "a screen container shows none")
    NS.SetByPath("locked", true)
    mocks.__fireTimers()
    assertFalse(pin:IsShown(), "locked: hidden")
    NS.SetByPath("locked", false)
    NS.SetByPath("container.attach.mode", "screen", 2)
    mocks.__fireTimers()
    assertFalse(pin:IsShown(), "screen: hidden")
    NS.SetByPath("container.attach.mode", "frame", 2)
    mocks.__fireTimers()
    assertFalse(pin:IsShown(), "frame: hidden")
end)

test("strip: Park and Destroy hide the join pin", function()
    local NS, mocks = fresh()
    NS.SetByPath("container.attach.container", 1, 2)
    NS.SetByPath("container.attach.mode", "container", 2)
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    local two = NS.ContainerManager.instances[2]
    assertTrue(two.joinPin:IsShown())
    two:Park()
    assertFalse(two.joinPin:IsShown(), "parked")
    two.joinPin:Show()
    two:Destroy()
    assertFalse(two.joinPin:IsShown(), "destroyed")
end)

test("strip: the tooltip of a container joined to another names the side and the parent", function()
    local NS, mocks = fresh()
    rootFlow(NS, "vertical", "right", "down")
    NS.SetByPath("container.attach.container", 1, 2)
    NS.SetByPath("container.attach.mode", "container", 2)
    NS.SetByPath("container.attach.edge", "after-center", 2)
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    local lines = {}
    rawset(mocks.GameTooltip, "AddLine", function(_, s) lines[#lines + 1] = s end)
    NS.ContainerManager.instances[2].handle:__fire("OnEnter")
    local want = NS.L["Joined to the %s of '%s'. Change the side on Layout > Anchor."]
        :format(NS.L["Bottom"], NS.Database.FindContainer(1).name)
    -- red under: the generic "Attached" line
    assertEqual(lines[2], want)
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
    rawset(o, "SetAllPoints", function(_, f) all[#all + 1] = f end)
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
