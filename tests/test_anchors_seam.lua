-- tests/test_anchors_seam.lua — the seam between a container and the container it is attached to
-- (batch 8 SS-1..SS-3, owner feedback #13): the gap across it is the child's own spacing between
-- consecutive elements in the direction it stacks, the stored X/Y offsets nudge on top of it, and
-- the child's drag strip sits beside its first element instead of over the parent's last aura.
-- Its own suite because tests/test_anchors.lua sits near layout-§1's 1500-line cap.

local T = _G.AM_TEST
local test, assertEqual, assertTrue =
    T.test, T.assertEqual, T.assertTrue
local fresh = dofile("tests/fresh_env.lua")

--- Record every SetPoint made on a container's anchor.
local function recordAnchor(inst)
    local rec = {}
    rawset(inst.anchor, "SetPoint", function(_, ...) rec[#rec + 1] = { ... } end)
    rawset(inst.anchor, "ClearAllPoints", function() end)
    return rec
end

--- Container `id` attached to container `to`, its offsets set to `x`, `y`.
local function attach(NS, id, to, x, y)
    local c = NS.Database.FindContainer(id)
    c.attach.mode, c.attach.container, c.attach.x, c.attach.y = "container", to, x, y
    return c
end

--- The flow container 1 hands down: `axis`, growing `growH` and `growV`.
local function parentFlow(NS, axis, growH, growV)
    local L = NS.Database.FindContainer(1).layout
    L.axis, L.growH, L.growV = axis, growH, growV
    return L
end

--- Place container 2 and answer the offsets it was anchored with.
local function placedOffsets(NS)
    local inst = NS.ContainerManager.instances[2]
    local rec = recordAnchor(inst)
    NS.Anchors.Place(inst)
    local p = rec[#rec]
    return p[4], p[5], p
end

test("seam: SeamOffset leaves one of the child's gaps in the direction the chain stacks", function()
    local NS = fresh()
    local cases = {
        -- axis, growH, growV, x, y: a column child's gap is its spacing (3), a row child's its line
        -- spacing (5); the chain always stacks vertically (IA-1), so x is 0 whatever growH says.
        { "vertical", "right", "down", 0, -3 },
        { "vertical", "left", "down", 0, -3 },
        { "vertical", "right", "up", 0, 3 },
        { "vertical", "left", "up", 0, 3 },
        { "horizontal", "right", "down", 0, -5 },
        { "horizontal", "left", "down", 0, -5 },
        { "horizontal", "right", "up", 0, 5 },
        { "horizontal", "left", "up", 0, 5 },
    }
    for _, c in ipairs(cases) do
        local x, y = NS.Anchors.SeamOffset({ axis = c[1], growH = c[2], growV = c[3], spacing = 3, lineSpacing = 5 })
        local what = table.concat({ c[1], c[2], c[3] }, "/")
        assertEqual(x, c[4], what)
        assertEqual(y, c[5], what)
    end
    for _, s in ipairs({ 0, -4, "junk" }) do
        local _, y = NS.Anchors.SeamOffset({ axis = "vertical", growV = "down", spacing = s })
        assertEqual(y, 0, "spacing " .. tostring(s) .. " leaves no gap")
    end
    local _, y = NS.Anchors.SeamOffset({})
    assertEqual(y, 0, "nothing stored: no gap")
end)

test("seam: a child attached below a column leaves its own spacing, and its X/Y nudge on top", function()
    local NS = fresh()
    parentFlow(NS, "vertical", "right", "down")
    local c2 = attach(NS, 2, 1, 0, 0)
    c2.layout.spacing, c2.layout.lineSpacing = 3, 9
    local x, y = placedOffsets(NS)
    -- red under: Place handing SetPoint the stored offsets alone (0,0: the blocks touch)
    assertEqual(x, 0); assertEqual(y, -3, "one of 2's spacings below 1's last bar")
    c2.attach.x, c2.attach.y = 4, -1
    x, y = placedOffsets(NS)
    -- red under: the derived gap replacing the stored offsets instead of adding to them (SS-2)
    assertEqual(x, 4); assertEqual(y, -4, "the nudge adds on top")
end)

test("seam: a chain growing up leaves the gap upward, so the child never overlaps its parent", function()
    local NS = fresh()
    parentFlow(NS, "vertical", "left", "up")
    local c2 = attach(NS, 2, 1, 0, 0)
    c2.layout.spacing = 2
    local x, y, p = placedOffsets(NS)
    assertEqual(p[1], "BOTTOMRIGHT"); assertEqual(p[3], "TOPRIGHT")
    -- red under: a fixed downward gap (the old 0/-4 pushed the child into the parent)
    assertEqual(x, 0); assertEqual(y, 2)
end)

test("seam: a child attached below an icon row leaves its own line spacing", function()
    local NS = fresh()
    parentFlow(NS, "horizontal", "right", "down")
    local c2 = attach(NS, 2, 1, 0, 0)
    c2.layout.spacing, c2.layout.lineSpacing = 1, 6
    local x, y = placedOffsets(NS)
    -- red under: the row child's element spacing (1) used across a vertical seam
    assertEqual(x, 0); assertEqual(y, -6)
end)

test("seam: the gap is the child's spacing, never the parent's", function()
    local NS = fresh()
    local L1 = parentFlow(NS, "vertical", "right", "down")
    L1.spacing = 9
    attach(NS, 2, 1, 0, 0).layout.spacing = 2
    local _, y = placedOffsets(NS)
    -- red under: reading the parent's spacing (SetPoint offsets are in the child's scale)
    assertEqual(y, -2)
end)

test("seam: a frame-attached container keeps its stored offsets and takes no gap", function()
    local NS, mocks = fresh()
    local f = mocks.__stubFrame()
    f.GetName = function() return "PlayerFrame" end
    f.IsForbidden = function() return false end
    f.GetParent = function() return nil end
    mocks.__globals.PlayerFrame = f
    local c2 = NS.Database.FindContainer(2)
    c2.attach = { mode = "frame", frame = "PlayerFrame", point = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = 1, y = 2 }
    c2.layout.spacing = 7
    local x, y = placedOffsets(NS)
    -- red under: the seam gap applied to a named frame (it has no flow to continue)
    assertEqual(x, 1); assertEqual(y, 2)
end)

test("seam: a container whose target cannot be used sits at its screen position, with no gap", function()
    local NS, mocks = fresh()
    local c2 = attach(NS, 2, 99, 5, 5)
    c2.position = { point = "CENTER", relativePoint = "CENTER", x = 11, y = 12 }
    local x, y, p = placedOffsets(NS)
    assertTrue(p[2] == mocks.UIParent, "the screen")
    assertEqual(x, 11); assertEqual(y, 12)
end)

test("seam: while the parent previews, the child hangs from its extent with the same gap as locked", function()
    local NS, mocks = fresh()
    NS.SetByPath("container.layout.spacing", 4, 2)
    NS.SetByPath("container.attach.x", 0, 2)
    NS.SetByPath("container.attach.y", 0, 2)
    NS.SetByPath("container.attach.container", 1, 2)
    NS.SetByPath("container.attach.mode", "container", 2)
    mocks.__fireTimers()
    local _, locked = placedOffsets(NS)
    NS.Preview.SetTestMode(true)
    mocks.__fireTimers()
    local one = NS.ContainerManager.instances[1]
    local _, previewing, p = placedOffsets(NS)
    assertTrue(p[2] == one.previewExtent, "the parent's preview extent")
    -- red under: an extent-only offset (SS-3: the seam is the same locked and in test mode)
    assertEqual(previewing, locked)
    assertEqual(locked, -4)
end)

-- ── the child's drag strip (SS-3) ─────────────────────────────────────────────────────────────

--- Container 2 attached to 1, its handle's SetPoint calls and its anchor's clamp insets recorded.
local function stripOf(NS)
    local inst = NS.ContainerManager.instances[2]
    local rec = { points = {} }
    rawset(inst.handle, "SetPoint", function(_, ...) rec.points[#rec.points + 1] = { ... } end)
    rawset(inst.anchor, "SetClampRectInsets", function(_, l, r, t, b)
        rec.insets = { l, r, t, b }
    end)
    return inst, rec
end

test("seam: an attached child's strip sits beside its first element, edge-aligned at the seam", function()
    local NS = fresh()
    local cases = {
        -- growH, growV, point, relativePoint, x: on the side opposite the growth, level with the
        -- child's edge that faces the parent, so the strip runs into the child's rows, never the parent's.
        { "right", "down", "TOPRIGHT", "TOPLEFT", -2 },
        { "left", "down", "TOPLEFT", "TOPRIGHT", 2 },
        { "right", "up", "BOTTOMRIGHT", "BOTTOMLEFT", -2 },
        { "left", "up", "BOTTOMLEFT", "BOTTOMRIGHT", 2 },
    }
    for _, axis in ipairs({ "vertical", "horizontal" }) do
        for _, c in ipairs(cases) do
            parentFlow(NS, axis, c[1], c[2])
            attach(NS, 2, 1, 0, 0)
            local inst, rec = stripOf(NS)
            NS.Anchors.UpdateHandle(inst, true)
            local p = rec.points[#rec.points]
            local what = axis .. "/" .. c[1] .. "/" .. c[2]
            -- red under: the strip on the side away from growth (over the parent's last aura)
            assertEqual(p[1], c[3], what)
            assertTrue(p[3] == c[4], what)
            assertTrue(p[2] == inst.anchor, what)
            assertEqual(p[4], c[5], what)
            assertEqual(p[5], 0, what)
            local ins = rec.insets
            -- red under: a top or bottom clamp reach for a strip that sits beside the anchor
            assertEqual(ins[3], 0, what .. " top"); assertEqual(ins[4], 0, what .. " bottom")
            if c[1] == "right" then
                assertTrue(ins[1] < 0 and ins[2] == 0, what .. " reaches left")
            else
                assertTrue(ins[2] > 0 and ins[1] == 0, what .. " reaches right")
            end
        end
    end
end)

test("seam: a screen container's strip keeps its place above or below its auras", function()
    local NS = fresh()
    local inst = NS.ContainerManager.instances[1]
    parentFlow(NS, "vertical", "right", "down")
    local points = {}
    rawset(inst.handle, "SetPoint", function(_, ...) points[#points + 1] = { ... } end)
    NS.Anchors.UpdateHandle(inst, true)
    local p = points[#points]
    -- red under: the side strip given to a container that follows nothing
    assertEqual(p[1], "BOTTOMLEFT"); assertEqual(p[3], "TOPLEFT"); assertEqual(p[5], 2)
end)
