-- tests/test_anchors_tooltip.lua — modules/Anchors_Tooltip.lua: the drag strip's tooltip sits beside
-- the strip, to its right, or to its left near the right edge of the screen, anchored to UIParent
-- alone; a strip whose rect reads secret or not at all falls back to the cursor (issue #22, the
-- owner's smoke feedback of 2026-10-02). Then the strip itself: BuildHandle hands the widget this
-- placement as its `tooltipPlace`, for the strip and the close mark alike.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local HR = dofile("tests/handle_recorder.lua")

--- A frame-shaped table answering the given geometry: `rect` = { left, right, top, scale }.
local function stripAt(rect)
    return {
        GetLeft = function() return rect.left end,
        GetRight = function() return rect.right end,
        GetTop = function() return rect.top end,
        GetEffectiveScale = function() return rect.scale or 1 end,
    }
end

--- A tooltip stand-in `width` wide at `scale`, recording its anchoring.
local function tipOf(width, scale)
    local tip = { points = {}, cleared = 0 }
    function tip.GetWidth() return width end
    function tip.GetEffectiveScale() return scale or 1 end
    function tip.ClearAllPoints(self) self.cleared = self.cleared + 1 end
    function tip.SetPoint(self, ...) self.points[#self.points + 1] = { ... } end
    return tip
end

--- Give the mock's UIParent a screen `right` wide at `scale` (the kit answers neither).
local function screen(mocks, right, scale)
    rawset(mocks.UIParent, "GetRight", function() return right end)
    rawset(mocks.UIParent, "GetEffectiveScale", function() return scale or 1 end)
end

test("tooltip: it sits a gap right of the strip, its TOPLEFT on the strip's TOPRIGHT, anchored to UIParent", function()
    local NS, mocks = fresh()
    screen(mocks, 1920)
    local tip = tipOf(200)
    -- red under: no placement module (NS.AnchorsTooltip nil), or a tooltip still at the cursor
    assertEqual(NS.AnchorsTooltip.Place(tip, stripAt{ left = 100, right = 300, top = 500 }), true)
    assertEqual(tip.cleared, 1, "its old points are cleared first")
    assertEqual(#tip.points, 1)
    local p = tip.points[1]
    assertEqual(p[1], "TOPLEFT")
    -- red under: anchoring to the strip, which the client refuses under the restricted anchor
    assertTrue(p[2] == mocks.UIParent, "anchored to UIParent, never to the strip")
    assertEqual(p[3], "BOTTOMLEFT")
    assertEqual(p[4], 300 + NS.AnchorsTooltip.GAP)
    assertEqual(p[5], 500)
end)

test("tooltip: near the right edge it flips to the strip's left, its TOPRIGHT a gap left of the strip", function()
    local NS, mocks = fresh()
    screen(mocks, 1920)
    local gap = NS.AnchorsTooltip.GAP
    local tip = tipOf(200)
    -- 1800 + gap + 200 passes 1920: the right side would run off the screen.
    assertEqual(NS.AnchorsTooltip.Place(tip, stripAt{ left = 1600, right = 1800, top = 700 }), true)
    local p = tip.points[1]
    -- red under: always placing on the right
    assertEqual(p[1], "TOPRIGHT")
    assertTrue(p[2] == mocks.UIParent)
    assertEqual(p[3], "BOTTOMLEFT")
    assertEqual(p[4], 1600 - gap)
    assertEqual(p[5], 700)
    -- Exactly fitting stays right: 1716 + gap + 200 = 1920.
    local fits = tipOf(200)
    NS.AnchorsTooltip.Place(fits, stripAt{ left = 1516, right = 1920 - 200 - gap, top = 700 })
    assertEqual(fits.points[1][1], "TOPLEFT", "a tooltip that just fits stays on the right")
end)

test("tooltip: a strip rect that reads secret or not at all falls back to the cursor, placing nothing", function()
    local NS, mocks = fresh()
    screen(mocks, 1920)
    local reads = {
        { left = 100, right = mocks.__SECRET, top = 500 },
        { left = mocks.__SECRET, right = 300, top = 500 },
        { left = 100, right = 300, top = mocks.__SECRET },
        { left = 100, right = 300, top = 500, scale = mocks.__SECRET },
        { left = 100, right = nil, top = 500 },
    }
    for i, rect in ipairs(reads) do
        local tip = tipOf(200)
        -- red under: arithmetic on the secret (it raises), or a placement answering true anyway
        local ok, placed = pcall(NS.AnchorsTooltip.Place, tip, stripAt(rect))
        assertTrue(ok, "read " .. i .. " does not raise: " .. tostring(placed))
        assertNil(placed, "read " .. i .. " answers nil, so the widget falls back to the cursor")
        assertEqual(#tip.points, 0, "read " .. i .. " anchors nothing")
    end
    -- The tooltip's own width, and the screen, unreadable: the cursor too.
    local tip = tipOf(mocks.__SECRET)
    assertNil(NS.AnchorsTooltip.Place(tip, stripAt{ left = 100, right = 300, top = 500 }))
    rawset(mocks.UIParent, "GetRight", nil)
    assertNil(NS.AnchorsTooltip.Place(tipOf(200), stripAt{ left = 100, right = 300, top = 500 }))
end)

test("tooltip: the strip's rect is converted into the tooltip's own units through both scales", function()
    local NS, mocks = fresh()
    -- A container at scale 0.5 under a UI at 1; the tooltip at 2. The strip's right edge is
    -- 600 * 0.5 = 300 screen pixels, which is 150 in the tooltip's units; its top 1000 * 0.5 / 2.
    screen(mocks, 1920)
    local gap = NS.AnchorsTooltip.GAP
    local tip = tipOf(100, 2)
    assertEqual(NS.AnchorsTooltip.Place(tip, stripAt{ left = 200, right = 600, top = 1000, scale = 0.5 }), true)
    local p = tip.points[1]
    -- red under: the strip's own units passed straight through (600 + gap, 1000)
    assertEqual(p[1], "TOPLEFT")
    assertEqual(p[4], 150 + gap)
    assertEqual(p[5], 250)
    -- The edge test runs in the same units: the screen is 1920 / 2 = 960 wide to this tooltip, so a
    -- strip whose right edge is 900 of its units (1800 / 2) cannot take a 100-wide tooltip after it.
    local near = tipOf(100, 2)
    NS.AnchorsTooltip.Place(near, stripAt{ left = 1600, right = 1800, top = 1000, scale = 1 })
    assertEqual(near.points[1][1], "TOPRIGHT")
    assertEqual(near.points[1][4], 800 - gap)
    assertEqual(near.points[1][5], 500)
end)

test("tooltip: a help or close mark places by the strip it belongs to, not by itself", function()
    local NS, mocks = fresh()
    screen(mocks, 1920)
    local strip = stripAt{ left = 100, right = 300, top = 500 }
    local mark = stripAt{ left = 270, right = 288, top = 500 }
    function mark.GetParent() return strip end
    strip.close = mark
    local tip = tipOf(200)
    assertEqual(NS.AnchorsTooltip.Place(tip, mark), true)
    -- red under: placing off the mark's own right edge (288 + gap)
    assertEqual(tip.points[1][4], 300 + NS.AnchorsTooltip.GAP)
    assertTrue(NS.AnchorsTooltip.StripOf(strip) == strip, "the strip is its own strip")
    local stray = stripAt{ left = 0, right = 10, top = 10 }
    function stray.GetParent() return strip end
    assertTrue(NS.AnchorsTooltip.StripOf(stray) == stray, "a child that is not a mark is not redirected")
end)

--- Hover `frame` and record GameTooltip's owners and points.
local function hover(mocks, frame)
    local owners, points = {}, {}
    rawset(mocks.GameTooltip, "SetOwner", function(_, owner, anchor)
        owners[#owners + 1] = { owner = owner, anchor = anchor }
    end)
    rawset(mocks.GameTooltip, "SetPoint", function(_, ...) points[#points + 1] = { ... } end)
    frame:__fire("OnEnter")
    return owners, points
end

test("tooltip: the strip, its help mark and its close mark show it beside the strip, owned by UIParent with no anchor", function()
    local NS, mocks = fresh()
    screen(mocks, 1920)
    local inst = NS.ContainerManager.instances[1]
    local h = HR.recordedHandle(mocks, NS, inst)
    for k, v in pairs{ GetLeft = 100, GetRight = 300, GetTop = 500, GetEffectiveScale = 1 } do
        rawset(h, k, function() return v end)
    end
    rawset(h.help, "GetParent", function() return h end)
    rawset(h.close, "GetParent", function() return h end)
    rawset(mocks.GameTooltip, "GetWidth", function() return 200 end)
    rawset(mocks.GameTooltip, "GetEffectiveScale", function() return 1 end)
    for _, frame in ipairs{ h, h.help, h.close } do
        local owners, points = hover(mocks, frame)
        -- red under: BuildHandle passing no tooltipPlace (one ANCHOR_CURSOR owner, no point)
        assertEqual(#owners, 1, "owned once: the placement held")
        assertTrue(owners[1].owner == mocks.UIParent)
        assertEqual(owners[1].anchor, "ANCHOR_NONE")
        assertEqual(#points, 1)
        assertEqual(points[1][1], "TOPLEFT")
        assertTrue(points[1][2] == mocks.UIParent, "anchored to UIParent, never into the strip's tree")
        assertEqual(points[1][4], 300 + NS.AnchorsTooltip.GAP)
    end
end)
