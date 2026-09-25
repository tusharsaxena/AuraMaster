-- tests/test_anchors_column.lua - batch 10 F1-F5: every container's drag strip and name label sit in
-- its own column, on its "before" side (above its block growing down, below it growing up), in the
-- order strip (outermost), label, block, whichever way the chain grows and whether it is a root or a
-- follower. A follower attached on the after side sits past its parent's block by the room its own
-- before-side furniture needs (the strip while it shows, the label while it shows, their gaps), with
-- the seam (SS-1) and the X/Y nudge on top, so the owner's Text chain reads strip, block, strip,
-- block, strip, block in one column. A side follower keeps its furniture before it too, and is pushed
-- along the growth past its parent's strip and label when the parent's strip runs over its column.
-- Its own suite because tests/test_anchors.lua sits near layout-§1's 1500-line cap.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")

local STRIP_H, STRIP_GAP = 18, 2
local ROW = STRIP_H + STRIP_GAP

--- Container 1 flows by `growH`/`growV` in a column; every container is one aura wide.
local function rootFlow(NS, growH, growV)
    for id = 1, 4 do
        local L = NS.Database.FindContainer(id).layout
        L.axis, L.perLine = "vertical", 0
    end
    local L = NS.Database.FindContainer(1).layout
    L.growH, L.growV = growH or "right", growV or "down"
end

--- Container `id` attached to container `to` on `edge` with no nudge, straight into the store.
local function join(NS, id, to, edge)
    local c = NS.Database.FindContainer(id)
    c.attach.mode, c.attach.container, c.attach.x, c.attach.y = "container", to, 0, 0
    c.attach.edge = edge or "after-start"
    return c
end

local function cfgOf(NS, id) return NS.Database.FindContainer(id) end
local function inst(NS, id) return NS.ContainerManager.instances[id] end

--- Apply everything, then lock or unlock (`locked`) and let the visibility pass run.
local function settle(NS, mocks, locked)
    NS.ContainerManager.RequestApply()
    mocks.__fireTimers()
    NS.SetByPath("locked", locked)
    mocks.__fireTimers()
end

--- Record every SetPoint container `id`'s anchor makes from here on.
local function recordAnchor(NS, id)
    local rec = {}
    rawset(inst(NS, id).anchor, "SetPoint", function(_, ...) table.insert(rec, { ... }) end)
    return rec
end

--- The offsets container `id` is placed with now.
local function placed(NS, id)
    local rec = recordAnchor(NS, id)
    NS.Anchors.Place(inst(NS, id))
    local p = rec[#rec]
    return p[4], p[5], p
end

local function spacingOf(NS, id) return cfgOf(NS, id).layout.spacing end

local function pointOf(NS, id)
    local point, rel, x, y = NS.Anchors.StripPoints(cfgOf(NS, id))
    return table.concat({ point, rel, tostring(x), tostring(y) }, " ")
end

--- The point container `c`'s label host is placed at (the kit hands its font string back as the same
--- frame, so the text's own point on the host is told apart by what it is relative to).
local function labelPoint(NS, c)
    local at = {}
    rawset(c.label, "SetPoint", function(_, ...)
        local p = { ... }
        if p[2] == c.anchor then table.insert(at, p) end
    end)
    NS.Anchors.PlaceLabel(c, cfgOf(NS, c.id))
    return at[#at]
end

-- ── F1, F3: the strip and the label on the before side of every container ──────────────────────

test("column: an after follower's strip sits before its own block, like a root's, mirrored by the growth", function()
    local NS = fresh()
    local cases = {
        { "right", "down", "BOTTOMLEFT TOPLEFT 0 2" },
        { "left", "down", "BOTTOMRIGHT TOPRIGHT 0 2" },
        { "right", "up", "TOPLEFT BOTTOMLEFT 0 -2" },
        { "left", "up", "TOPRIGHT BOTTOMRIGHT 0 -2" },
    }
    for _, c in ipairs(cases) do
        rootFlow(NS, c[1], c[2])
        join(NS, 2, 1)
        join(NS, 3, 2, "after-center")
        local what = c[1] .. "/" .. c[2]
        assertEqual(pointOf(NS, 1), c[3], what .. " root")
        -- red under: batch 9's StripSide (behind the first element, beside the column)
        assertEqual(pointOf(NS, 2), c[3], what .. " follower")
        assertEqual(pointOf(NS, 3), c[3], what .. " follower's follower")
    end
end)

test("column: a follower's strip stays before it whatever other followers hold its sides", function()
    local NS = fresh()
    rootFlow(NS)
    join(NS, 2, 1)
    join(NS, 3, 2, "behind-start")
    join(NS, 4, 2, "ahead-start")
    -- red under: batch 9's ahead and inside strips
    assertEqual(pointOf(NS, 2), "BOTTOMLEFT TOPLEFT 0 2")
end)

test("column: unlocked with the label on, a follower reads strip, label, block before its own block", function()
    local NS, mocks = fresh()
    rootFlow(NS)
    join(NS, 2, 1)
    cfgOf(NS, 2).label.show = true
    settle(NS, mocks, false)
    local two = inst(NS, 2)
    local l = labelPoint(NS, two)
    -- red under: the label beside the column (TOPRIGHT on TOPLEFT), far left of the block
    assertEqual(l[1], "BOTTOMLEFT"); assertTrue(l[2] == two.anchor); assertEqual(l[3], "TOPLEFT")
    assertEqual(l[5], STRIP_GAP, "the label right on the block")
    local stripAt = {}
    rawset(two.handle, "SetPoint", function(_, ...) table.insert(stripAt, { ... }) end)
    NS.Anchors.UpdateHandle(two, true)
    local s = stripAt[#stripAt]
    assertEqual(s[1], "BOTTOMLEFT"); assertEqual(s[3], "TOPLEFT")
    assertEqual(s[5], STRIP_GAP + ROW, "the strip outermost, past the label")
end)

test("column: locked with the label on, a follower's label sits on its block's before side, not beside the column", function()
    local NS, mocks = fresh()
    rootFlow(NS, "right", "up")
    join(NS, 2, 1)
    cfgOf(NS, 2).label.show = true
    settle(NS, mocks, true)
    local two = inst(NS, 2)
    local l = labelPoint(NS, two)
    -- red under: the label placed behind the first element (owner screenshot: far left)
    assertEqual(l[1], "TOPLEFT"); assertEqual(l[3], "BOTTOMLEFT"); assertEqual(l[5], -STRIP_GAP)
    assertTrue(two.label:IsShown())
    assertFalse(two.handle:IsShown(), "locked: no strip")
end)

test("column: a label is justified inside its own block per LJ-1, with no mirror for an after follower", function()
    local NS = fresh()
    rootFlow(NS)
    for id = 1, 3 do cfgOf(NS, id).style = "icons" end
    join(NS, 2, 1)
    -- red under: batch 9's mirror for a label behind the first element
    assertEqual(NS.Anchors.LabelJustify(cfgOf(NS, 2)), "LEFT")
    join(NS, 3, 1, "behind-start")
    assertEqual(NS.Anchors.LabelJustify(cfgOf(NS, 3)), "RIGHT", "a behind follower's lines up with the edge facing its parent")
    cfgOf(NS, 2).label.justifyH = "CENTER"
    assertEqual(NS.Anchors.LabelJustify(cfgOf(NS, 2)), "CENTER", "a pick wins")
end)

-- ── F2: the chain spreads while the furniture shows ───────────────────────────────────────────

test("column: an after follower sits past its parent by its own strip's room while unlocked, and by the seam alone locked", function()
    local NS, mocks = fresh()
    rootFlow(NS)
    join(NS, 2, 1)
    settle(NS, mocks, false)
    local s = spacingOf(NS, 2)
    local x, y = placed(NS, 2)
    -- red under: batch 9's clearStrip (the seam alone: the strip sat beside the column)
    assertEqual(x, 0); assertEqual(y, -(s + ROW), "unlocked: the seam and one strip row")
    settle(NS, mocks, true)
    x, y = placed(NS, 2)
    assertEqual(x, 0); assertEqual(y, -s, "locked, no label: exactly the seam, as before")
end)

test("column: the label's row counts locked and unlocked, the strip's only while it shows", function()
    local NS, mocks = fresh()
    rootFlow(NS)
    join(NS, 2, 1)
    cfgOf(NS, 2).label.show = true
    settle(NS, mocks, true)
    local s = spacingOf(NS, 2)
    local _, y = placed(NS, 2)
    -- red under: no room for a follower's own label (it sat beside the column)
    assertEqual(y, -(s + ROW), "locked: the label's row")
    settle(NS, mocks, false)
    _, y = placed(NS, 2)
    assertEqual(y, -(s + 2 * ROW), "unlocked: the strip's row too")
end)

test("column: growing up, the chain spreads upward, the furniture below each block", function()
    local NS, mocks = fresh()
    rootFlow(NS, "left", "up")
    join(NS, 2, 1)
    cfgOf(NS, 2).label.show = true
    settle(NS, mocks, false)
    local x, y, p = placed(NS, 2)
    assertEqual(p[1], "BOTTOMRIGHT"); assertEqual(p[3], "TOPRIGHT")
    assertEqual(x, 0); assertEqual(y, spacingOf(NS, 2) + 2 * ROW)
    assertEqual(pointOf(NS, 2), "TOPRIGHT BOTTOMRIGHT 0 -2")
end)

test("column: the X/Y nudge adds on top of the spread seam", function()
    local NS, mocks = fresh()
    rootFlow(NS)
    local c2 = join(NS, 2, 1)
    settle(NS, mocks, false)
    c2.attach.x, c2.attach.y = 3, -4
    local x, y = placed(NS, 2)
    assertEqual(x, 3); assertEqual(y, -(spacingOf(NS, 2) + ROW) - 4)
end)

test("column: a lock or unlock re-places a follower through its own visibility pass, and a repeat pass re-places nothing", function()
    local NS, mocks = fresh()
    rootFlow(NS)
    join(NS, 2, 1)
    settle(NS, mocks, true)
    local rec = recordAnchor(NS, 2)
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    -- red under: nothing re-placing a follower when its OWN strip appears
    assertTrue(#rec > 0, "placed again on unlock")
    assertEqual(rec[#rec][5], -(spacingOf(NS, 2) + ROW))
    local n = #rec
    inst(NS, 2):ApplyVisibility()
    assertEqual(#rec, n, "a pass that changes nothing re-places nothing")
    NS.SetByPath("locked", true)
    mocks.__fireTimers()
    assertEqual(rec[#rec][5], -spacingOf(NS, 2), "locked again: the seam alone")
end)

test("column: under lockdown the seam waits; the first pass after combat catches up", function()
    local NS, mocks = fresh()
    rootFlow(NS)
    join(NS, 2, 1)
    settle(NS, mocks, true)
    local rec = recordAnchor(NS, 2)
    local two = inst(NS, 2)
    mocks.__lockdown = true
    two.stripShown = true
    NS.Anchors.RefreshSeam(two)
    assertEqual(#rec, 0, "no SetPoint on an aura engine's anchor in combat")
    mocks.__lockdown = false
    NS.Anchors.RefreshSeam(two)
    assertEqual(rec[#rec][5], -(spacingOf(NS, 2) + ROW))
end)

test("column: RefreshSeam allocates nothing when the seam already fits", function()
    local NS, mocks = fresh()
    rootFlow(NS)
    join(NS, 2, 1)
    join(NS, 3, 2)
    settle(NS, mocks, false)
    local three = inst(NS, 3)
    NS.Anchors.RefreshSeam(three)
    collectgarbage("collect")
    collectgarbage("stop")
    local before = collectgarbage("count")
    for _ = 1, 200 do NS.Anchors.RefreshSeam(three) end
    local after = collectgarbage("count")
    collectgarbage("restart")
    assertEqual(after - before, 0, "bytes allocated")
end)

test("column: test mode, unlocked, spreads the chain the same way and hangs from the preview block", function()
    local NS, mocks = fresh()
    rootFlow(NS)
    join(NS, 2, 1)
    settle(NS, mocks, false)
    local _, unlocked = placed(NS, 2)
    NS.Preview.SetTestMode(true)
    mocks.__fireTimers()
    local _, previewing, p = placed(NS, 2)
    assertTrue(p[2] == inst(NS, 1).previewExtent, "the parent's preview block")
    assertEqual(previewing, unlocked)
    assertTrue(inst(NS, 1).outline:IsShown(), "the test-mode block outline stays (SEP-1)")
    NS.Preview.SetTestMode(false)
    mocks.__fireTimers()
end)

-- ── the owner's mockup: the Text chain #13 -> #14 -> #15, Side Bottom, growing down ────────────

test("column: the owner's Text chain reads strip, block, strip, block, strip, block in one column", function()
    local NS, mocks = fresh()
    rootFlow(NS)
    for id = 1, 3 do
        local c = cfgOf(NS, id)
        c.style = "text"
        c.text = c.text or {}
        c.text.justifyH = "CENTER"
    end
    join(NS, 2, 1, "after-center")
    join(NS, 3, 2, "after-center")
    settle(NS, mocks, false)
    -- Each anchor's top, from the root's top at 0, one element tall (every block holds one line):
    -- the child's top is its parent's bottom plus the seam and the child's own strip row.
    local w, h = NS.Style.ElementSize(cfgOf(NS, 1))
    local tops, strips = { 0 }, {}
    for id = 2, 3 do
        local x, y, p = placed(NS, id)
        -- red under: the batch 9 seam (the strip beside the column, the blocks one gap apart)
        assertEqual(p[1], "TOP"); assertEqual(p[3], "BOTTOM", "Side Bottom: centered under the parent")
        assertEqual(x, 0)
        tops[id] = tops[id - 1] - h + y
    end
    for id = 1, 3 do
        assertEqual(pointOf(NS, id), "BOTTOMLEFT TOPLEFT 0 2", "#" .. id .. " strip on its own block")
        local stripW = NS.Style.ElementSize(cfgOf(NS, id))
        assertEqual(stripW, w, "one column: every block as wide")
        strips[id] = { bottom = tops[id] + STRIP_GAP, top = tops[id] + ROW }
    end
    for id = 2, 3 do
        local parentBottom = tops[id - 1] - h
        assertTrue(strips[id].top < parentBottom, "#" .. id .. "'s strip below its parent's block")
        assertEqual(parentBottom - strips[id].top, spacingOf(NS, id), "the seam between them")
        assertTrue(strips[id].bottom > tops[id], "and above its own block")
    end
end)

-- ── F4: side followers ────────────────────────────────────────────────────────────────────────

--- Make container `id`'s strip run `over` pixels past its element on the next placement.
local function overhang(NS, id, over)
    rawset(inst(NS, id).handle, "ApplyWidth", function(_, w) return (w or 0) + over end)
end

test("column: an ahead follower is pushed along the growth past its parent's strip and label while that strip runs over it", function()
    local NS, mocks = fresh()
    rootFlow(NS)
    join(NS, 2, 1, "ahead-start")
    cfgOf(NS, 1).label.show = true
    overhang(NS, 1, 60)
    settle(NS, mocks, false)
    local gx = NS.Anchors.SeamOffset(NS.Anchors.EffectiveLayout(cfgOf(NS, 2)), "ahead")
    local x, y = placed(NS, 2)
    assertEqual(x, gx)
    -- red under: batch 9's parentRows (the child's strip pushed up, its block left level)
    assertEqual(y, -2 * ROW, "the parent's strip and label rows")
    assertEqual(pointOf(NS, 2), "BOTTOMLEFT TOPLEFT 0 2", "the child's own furniture before it")
    settle(NS, mocks, true)
    x, y = placed(NS, 2)
    assertEqual(x, gx); assertEqual(y, 0, "locked: no strip to run over it, level with its parent")
end)

test("column: an ahead follower stays level when its parent's strip fits its own block, and growing up it is pushed upward", function()
    local NS, mocks = fresh()
    rootFlow(NS)
    join(NS, 2, 1, "ahead-start")
    overhang(NS, 1, 0)
    settle(NS, mocks, false)
    local _, y = placed(NS, 2)
    assertEqual(y, 0, "nothing runs over it")
    rootFlow(NS, "right", "up")
    overhang(NS, 1, 40)
    settle(NS, mocks, false)
    _, y = placed(NS, 2)
    assertEqual(y, ROW, "growing up: upward by the strip's row")
end)

test("column: a behind follower keeps its strip before it, lined up with the edge facing its parent, and is never pushed", function()
    local NS, mocks = fresh()
    rootFlow(NS)
    join(NS, 2, 1, "behind-start")
    overhang(NS, 1, 60)
    settle(NS, mocks, false)
    assertEqual(pointOf(NS, 2), "BOTTOMRIGHT TOPRIGHT 0 2")
    local _, y = placed(NS, 2)
    -- the parent's strip runs away from it, toward the other side
    assertEqual(y, 0)
end)

test("column: a follower of a side follower spreads by its own strip, as any after follower does", function()
    local NS, mocks = fresh()
    rootFlow(NS)
    join(NS, 2, 1, "ahead-start")
    join(NS, 3, 2)
    settle(NS, mocks, false)
    local _, y = placed(NS, 3)
    assertEqual(y, -(spacingOf(NS, 3) + ROW))
end)

test("column: the join pin stays at the child's attach point while unlocked", function()
    local NS, mocks = fresh()
    rootFlow(NS)
    join(NS, 2, 1, "after-center")
    settle(NS, mocks, false)
    local two = inst(NS, 2)
    assertTrue(two.joinPin ~= nil and two.joinPin:IsShown())
    local rec = {}
    rawset(two.joinPin, "SetPoint", function(_, ...) table.insert(rec, { ... }) end)
    NS.Anchors.UpdateHandle(two, true)
    assertEqual(rec[#rec][1], "CENTER"); assertEqual(rec[#rec][3], "TOP")
end)
