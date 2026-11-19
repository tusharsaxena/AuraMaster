-- tests/test_anchors_tooltip.lua — modules/Anchors_Tooltip.lua: the drag strip's tooltip sits beside
-- the strip, to its right, or to its left near the right edge of the screen, anchored to UIParent
-- alone (issue #22, the owner's smoke feedback of 2026-10-02, kept by the owner's SR2 answer of
-- 2026-11-17). Since AD-92-AM (LibKa0s#92) it is placed by LibKa0s-Tooltip-1.0's PlaceBeside, the
-- strip being both the element and the group, at the library's TIP_GAP, and never at the cursor: a
-- strip whose rect reads secret places beside the nearest container up its stored attach chain whose
-- anchor reads (the AD-92-AM review fix), and only a strip with nothing readable on its chain is not
-- placed by this hook. Then the strip itself: BuildHandle hands the widget this placement as its
-- `tooltipPlace`, for the strip and its marks alike, and no retired `tooltipOwner`.
--
-- RE-PINNED by AD-92-AM to standalone-windows *Tooltip placement* (WowAddonStandards v2.113.0): the
-- gap is TIP_GAP (2) where it was this file's own GAP (4), and the cursor pin the owner chose for an
-- unreadable strip (option B, 2026-10-03) is gone, as the rule's "never the cursor" asks.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local HR = dofile("tests/handle_recorder.lua")

--- A frame-shaped table answering the given geometry: `rect` = { left, bottom, right, top, scale }.
--- `bottom` defaults to 10 below `top`, a strip's height.
local function stripAt(rect)
    return {
        GetLeft = function() return rect.left end,
        GetBottom = function()
            if rect.bottom ~= nil then return rect.bottom end
            return type(rect.top) == "number" and rect.top - 10 or rect.top
        end,
        GetRight = function() return rect.right end,
        GetTop = function() return rect.top end,
        GetEffectiveScale = function() return rect.scale or 1 end,
    }
end

--- A tooltip stand-in `width` x `height` (80 by default) at `scale`, recording its anchoring.
local function tipOf(width, scale, height)
    local tip = { points = {}, cleared = 0 }
    function tip.GetWidth() return width end
    function tip.GetHeight() return height or 80 end
    function tip.GetEffectiveScale() return scale or 1 end
    function tip.ClearAllPoints(self) self.cleared = self.cleared + 1 end
    function tip.SetPoint(self, ...) self.points[#self.points + 1] = { ... } end
    return tip
end

--- Give the mock's UIParent a `width` x `height` screen at `scale` (the kit answers none of them).
local function screen(mocks, width, scale, height)
    rawset(mocks.UIParent, "GetWidth", function() return width end)
    rawset(mocks.UIParent, "GetHeight", function() return height or 1080 end)
    rawset(mocks.UIParent, "GetEffectiveScale", function() return scale or 1 end)
end

--- The cursor must never be read: a read raises, so a placement that consults it fails the case.
local function noCursor(mocks)
    mocks.GetCursorPosition = function() error("the strip's tooltip read the cursor") end
end

--- Record every PlaceBeside call the hook makes (element, group, opts), passing it through.
local function spyBeside(mocks)
    local Lib = mocks.LibStub("LibKa0s-Tooltip-1.0")
    local real, calls = Lib.PlaceBeside, {}
    Lib.PlaceBeside = function(tip, element, group, opts)
        calls[#calls + 1] = { element = element, group = group, opts = opts }
        return real(tip, element, group, opts)
    end
    return calls, function() Lib.PlaceBeside = real end
end

test("tooltip: PlaceBeside puts it TIP_GAP right of the strip, its top level with the strip's, pinned to UIParent", function()
    local NS, mocks = fresh()
    screen(mocks, 1920)
    noCursor(mocks)
    local calls, restore = spyBeside(mocks)
    local gap = mocks.LibStub("LibKa0s-Tooltip-1.0").TIP_GAP
    local strip = stripAt{ left = 100, right = 300, top = 500 }
    local tip = tipOf(200)
    -- red under: the hook's own arithmetic (no PlaceBeside call), or a tooltip still at the cursor
    assertEqual(NS.AnchorsTooltip.Place(tip, strip), true)
    restore()
    assertEqual(#calls, 1, "the library's body placer, once")
    assertTrue(calls[1].element == strip, "the element is the strip")
    assertTrue(calls[1].group == strip, "the group is the strip: beside the strip, the owner's ruling")
    assertEqual(type(calls[1].opts.rect), "function", "the strip's rect is read through the secret guard")
    assertEqual(calls[1].opts.comparisons, false, "no comparison tooltips on a strip")
    assertEqual(#tip.points, 1)
    local p = tip.points[1]
    assertEqual(p[1], "TOPLEFT")
    -- red under: anchoring to the strip, which the client refuses under the restricted anchor
    assertTrue(p[2] == mocks.UIParent, "anchored to UIParent, never to the strip")
    assertEqual(p[3], "BOTTOMLEFT")
    assertEqual(gap, 2)
    -- red under: the retired 4 px gap of this file's own
    assertEqual(p[4], 300 + gap)
    assertEqual(p[5], 500)
end)

test("tooltip: near the right edge it flips to the strip's left, its TOPRIGHT TIP_GAP left of the strip", function()
    local NS, mocks = fresh()
    screen(mocks, 1920)
    noCursor(mocks)
    local gap = mocks.LibStub("LibKa0s-Tooltip-1.0").TIP_GAP
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
    -- Exactly fitting stays right: right + gap + 200 = 1920.
    local fits = tipOf(200)
    NS.AnchorsTooltip.Place(fits, stripAt{ left = 1516, right = 1920 - 200 - gap, top = 700 })
    assertEqual(fits.points[1][1], "TOPLEFT", "a tooltip that just fits stays on the right")
end)

test("tooltip: a strip rect that reads secret or not at all is not placed and never pinned at the cursor", function()
    local NS, mocks = fresh()
    screen(mocks, 1920)
    noCursor(mocks)
    local Tip = NS.AnchorsTooltip
    local reads = {
        { left = 100, right = mocks.__SECRET, top = 500 },
        { left = mocks.__SECRET, right = 300, top = 500 },
        { left = 100, right = 300, top = mocks.__SECRET },
        { left = 100, right = 300, top = 500, bottom = mocks.__SECRET },
        { left = 100, right = 300, top = 500, scale = mocks.__SECRET },
        { left = 100, right = nil, top = 500 },
    }
    for i, rect in ipairs(reads) do
        local tip = tipOf(200)
        -- red under: arithmetic on the secret (it raises), the cursor read (noCursor raises), or a
        -- point written from either
        local ok, placed = pcall(Tip.Place, tip, stripAt(rect))
        assertTrue(ok, "read " .. i .. " does not raise: " .. tostring(placed))
        assertNil(placed, "read " .. i .. ": not placed, so the widget's attached fallback runs")
        assertEqual(#tip.points, 0, "read " .. i .. ": nothing anchored, at the cursor or anywhere")
    end
    -- The tooltip's own size, and the screen, unreadable: nil too, whatever the strip.
    assertNil(Tip.Place(tipOf(mocks.__SECRET), stripAt{ left = 100, right = 300, top = 500 }))
    rawset(mocks.UIParent, "GetWidth", nil)
    assertNil(Tip.Place(tipOf(200), stripAt{ left = 100, right = 300, top = 500 }))
    assertNil(Tip.Place(nil, stripAt{ left = 100, right = 300, top = 500 }), "no tooltip")
    assertNil(Tip.Place(tipOf(200), nil), "no frame")
end)

--- Stand in for the live containers: `list` maps an id to { strip = rect|nil, anchor = rect, attach = at }.
--- Answers the instances by id; each has a strip (its `handle`, a child of its anchor), an anchor
--- and the stored attach settings its Cfg answers.
local function liveChain(NS, list)
    local saved, instances = NS.ContainerManager.instances, {}
    for id, c in pairs(list) do
        local anchor = stripAt(c.anchor)
        local strip = stripAt(c.strip or c.anchor)
        function strip.GetParent() return anchor end
        local cfg = { id = id, attach = c.attach or { mode = "screen" } }
        instances[id] = { id = id, anchor = anchor, handle = strip, Cfg = function() return cfg end }
    end
    NS.ContainerManager.instances = instances
    return instances, function() NS.ContainerManager.instances = saved end
end

test("tooltip: a strip whose rect reads secret places beside the nearest container up its attach chain that reads", function()
    -- REVIEW FIX (AD-92-AM): a container attached under a parent holding auras reads secret, and the
    -- widget's own attached fallback reads the same secret rect, so it left the tooltip unanchored.
    -- The hook walks the stored attach chain instead (configuration, never a secret read back) to
    -- the first container whose anchor reads, and places beside that one, never at the cursor.
    local NS, mocks = fresh()
    screen(mocks, 1920)
    noCursor(mocks)
    local gap = mocks.LibStub("LibKa0s-Tooltip-1.0").TIP_GAP
    local S = mocks.__SECRET
    local secret = { left = S, right = S, top = S, bottom = S }
    local calls, restore = spyBeside(mocks)
    local inst, done = liveChain(NS, {
        [1] = { anchor = { left = 100, right = 300, top = 500 } },
        [2] = { anchor = secret, attach = { mode = "container", container = 1 } },
        [3] = { anchor = secret, attach = { mode = "container", container = 2 } },
    })
    local tip = tipOf(200)
    -- red under: answering nil (the widget's fallback then leaves the tooltip with no anchor)
    local ok, placed = pcall(NS.AnchorsTooltip.Place, tip, inst[3].handle)
    assertTrue(ok, tostring(placed))
    assertEqual(placed, true, "a two-hop chain places by the first container that reads")
    assertTrue(calls[#calls].element == inst[1].anchor, "beside container 1's anchor")
    assertTrue(calls[#calls].group == inst[1].anchor)
    assertEqual(#tip.points, 1)
    assertEqual(tip.points[1][1], "TOPLEFT")
    assertTrue(tip.points[1][2] == mocks.UIParent, "pinned to UIParent")
    assertEqual(tip.points[1][4], 300 + gap)
    assertEqual(tip.points[1][5], 500)
    -- A mark on the secret strip places the same way.
    local mark = stripAt(secret)
    function mark.GetParent() return inst[2].handle end
    inst[2].handle.help = mark
    local mt = tipOf(200)
    assertEqual(NS.AnchorsTooltip.Place(mt, mark), true)
    assertEqual(mt.points[1][4], 300 + gap, "the mark's strip's chain")
    done()
    restore()
end)

test("tooltip: a secret strip attached to a named frame places beside that frame when it reads, and only then answers nil", function()
    local NS, mocks = fresh()
    screen(mocks, 1920)
    noCursor(mocks)
    local gap = mocks.LibStub("LibKa0s-Tooltip-1.0").TIP_GAP
    local S = mocks.__SECRET
    local secret = { left = S, right = S, top = S, bottom = S }
    local named = stripAt{ left = 400, right = 600, top = 800 }
    named.GetObjectType = function() return "Frame" end
    rawset(_G, "AMTestNamedFrame", named)
    local inst, done = liveChain(NS, {
        [1] = { anchor = secret, attach = { mode = "frame", frame = "AMTestNamedFrame" } },
        [2] = { anchor = secret, attach = { mode = "container", container = 1 } },
    })
    local tip = tipOf(200)
    -- red under: answering nil for a chain that ends on a readable named frame
    assertEqual(NS.AnchorsTooltip.Place(tip, inst[2].handle), true)
    assertEqual(tip.points[1][4], 600 + gap, "beside the named frame")
    assertEqual(tip.points[1][5], 800)
    -- Nothing on the chain reads (the named frame itself secret): nil, nothing anchored, no cursor.
    local secretNamed = stripAt(secret)
    secretNamed.GetObjectType = function() return "Frame" end
    rawset(_G, "AMTestNamedFrame", secretNamed)
    local none = tipOf(200)
    local ok, placed = pcall(NS.AnchorsTooltip.Place, none, inst[2].handle)
    assertTrue(ok, tostring(placed))
    assertNil(placed)
    assertEqual(#none.points, 0)
    -- A loop in the stored settings ends the walk rather than spinning.
    local loop, undo = liveChain(NS, {
        [1] = { anchor = secret, attach = { mode = "container", container = 2 } },
        [2] = { anchor = secret, attach = { mode = "container", container = 1 } },
    })
    assertNil(NS.AnchorsTooltip.Place(tipOf(200), loop[1].handle), "a loop answers nil")
    undo()
    done()
    rawset(_G, "AMTestNamedFrame", nil)
end)

test("tooltip: the strip's rect is converted into the tooltip's own units through both scales", function()
    local NS, mocks = fresh()
    -- A container at scale 0.5 under a UI at 1; the tooltip at 2. The strip's right edge is
    -- 600 * 0.5 = 300 screen pixels, which is 150 in the tooltip's units; its top 1000 * 0.5 / 2.
    screen(mocks, 1920)
    local gap = mocks.LibStub("LibKa0s-Tooltip-1.0").TIP_GAP
    local tip = tipOf(100, 2, 40)
    assertEqual(NS.AnchorsTooltip.Place(tip, stripAt{ left = 200, right = 600, top = 1000, scale = 0.5 }), true)
    local p = tip.points[1]
    -- red under: the strip's own units passed straight through (600 + gap, 1000)
    assertEqual(p[1], "TOPLEFT")
    assertEqual(p[4], (300 + gap) / 2)
    assertEqual(p[5], 250)
    -- The edge test runs in screen units: the tooltip is 100 * 2 = 200 wide, so a strip whose right
    -- edge is 1800 cannot take it after it on a 1920 screen.
    local near = tipOf(100, 2, 40)
    NS.AnchorsTooltip.Place(near, stripAt{ left = 1600, right = 1800, top = 1000, scale = 1 })
    assertEqual(near.points[1][1], "TOPRIGHT")
    assertEqual(near.points[1][4], (1600 - gap) / 2)
    assertEqual(near.points[1][5], 500)
end)

test("tooltip: with room on neither side of the strip it attaches centered above it (the library's fallback)", function()
    local NS, mocks = fresh()
    screen(mocks, 1920)
    noCursor(mocks)
    local gap = mocks.LibStub("LibKa0s-Tooltip-1.0").TIP_GAP
    local tip = tipOf(200)
    -- A strip spanning the screen: neither 0 - gap - 200 >= 0 nor 1920 + gap + 200 <= 1920.
    -- red under: a hook that answers nil here (the widget's unguarded relative point, refused in game)
    assertEqual(NS.AnchorsTooltip.Place(tip, stripAt{ left = 0, right = 1920, top = 500 }), true)
    local p = tip.points[1]
    assertEqual(p[1], "BOTTOM", "attached above the strip")
    assertTrue(p[2] == mocks.UIParent, "still pinned to UIParent")
    assertEqual(p[4], 960, "centered on the strip")
    assertEqual(p[5], 500 + gap)
end)

test("tooltip: a help, close or settings mark places by the strip it belongs to, not by itself", function()
    local NS, mocks = fresh()
    screen(mocks, 1920)
    local gap = mocks.LibStub("LibKa0s-Tooltip-1.0").TIP_GAP
    local strip = stripAt{ left = 100, right = 300, top = 500 }
    for _, key in ipairs{ "help", "close", "settings" } do
        local mark = stripAt{ left = 270, right = 288, top = 500 }
        function mark.GetParent() return strip end
        strip[key] = mark
        local tip = tipOf(200)
        assertEqual(NS.AnchorsTooltip.Place(tip, mark), true)
        -- red under: placing off the mark's own right edge (288 + gap); the settings mark (AD-86-AM)
        -- not redirected
        assertEqual(tip.points[1][4], 300 + gap, key .. " places by the strip")
        assertTrue(NS.AnchorsTooltip.StripOf(mark) == strip, key .. "'s strip")
        strip[key] = nil
    end
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

test("tooltip: the strip and each of its marks show it beside the strip, owned by UIParent with no anchor", function()
    local NS, mocks = fresh()
    screen(mocks, 1920)
    noCursor(mocks)
    local gap = mocks.LibStub("LibKa0s-Tooltip-1.0").TIP_GAP
    local inst = NS.ContainerManager.instances[1]
    local h = HR.recordedHandle(mocks, NS, inst)
    for k, v in pairs{ GetLeft = 100, GetBottom = 490, GetRight = 300, GetTop = 500, GetEffectiveScale = 1 } do
        rawset(h, k, function() return v end)
    end
    local marks = { h }
    for _, key in ipairs{ "help", "close", "settings" } do
        if h[key] then
            rawset(h[key], "GetParent", function() return h end)
            marks[#marks + 1] = h[key]
        end
    end
    assertEqual(#marks, 4, "the strip, its ?, its X and its settings mark")
    rawset(mocks.GameTooltip, "GetWidth", function() return 200 end)
    rawset(mocks.GameTooltip, "GetHeight", function() return 80 end)
    rawset(mocks.GameTooltip, "GetEffectiveScale", function() return 1 end)
    for i, frame in ipairs(marks) do
        local owners, points = hover(mocks, frame)
        -- red under: BuildHandle passing no tooltipPlace (the widget's attached placement, BOTTOM)
        assertEqual(#owners, 1, "frame " .. i .. ": owned once, the placement held")
        assertTrue(owners[1].owner == mocks.UIParent)
        assertEqual(owners[1].anchor, "ANCHOR_NONE")
        assertEqual(#points, 1)
        assertEqual(points[1][1], "TOPLEFT")
        assertTrue(points[1][2] == mocks.UIParent, "anchored to UIParent, never into the strip's tree")
        assertEqual(points[1][4], 300 + gap)
    end
end)

test("tooltip: BuildHandle hands the widget the beside placement and no retired cursor owner", function()
    local NS, mocks = fresh()
    local KW = mocks.LibStub("LibKa0s-Widgets-1.0")
    local real, spec = KW.DragHandle, nil
    KW.DragHandle = function(parent, s) spec = s; return real(parent, s) end
    NS.Anchors.BuildHandle(NS.ContainerManager.instances[1])
    KW.DragHandle = real
    assertTrue(spec ~= nil, "the strip was built")
    assertTrue(spec.tooltipPlace == NS.AnchorsTooltip.Place, "the beside placement is the strip's tooltipPlace")
    -- red under: `tooltipOwner = "cursor"` still passed (retired at WidgetsDragHandle minor 14)
    assertNil(spec.tooltipOwner)
    assertNil(spec.tooltipAnchor)
end)

test("tooltip guard: no addon file places a tooltip at the cursor or owns one at an anchor of its own", function()
    -- standalone-windows *Tooltip placement*: never the cursor, never a corner offset. The aura
    -- buttons' tooltips are the client's (SetTooltipAnchorPoint, modules/Style.lua) and out of scope,
    -- so core/Constants.lua may name the corner anchors that setting offers; the migration that
    -- retires the cursor choice (core/Database_Migrations.lua, schema v20) has to name it.
    local NAMES_CURSOR = { ["core/Database_Migrations.lua"] = true }
    local files = T.Loader.tocFiles("AuraMaster.toc")
    assertTrue(#files > 50, "the TOC's files were read")
    for _, path in ipairs(files) do
        local f = assert(io.open(path, "r"), path)
        local src = f:read("*a")
        f:close()
        -- red under: ANCHOR_CURSOR back in C.TOOLTIP_ANCHORS, or a hook pinning at the cursor
        if not NAMES_CURSOR[path] then
            assertTrue(not src:find("ANCHOR_CURSOR", 1, true), path .. " names ANCHOR_CURSOR")
        end
        assertTrue(not src:find("tooltipOwner%s*="), path .. " passes the retired tooltipOwner")
        assertTrue(not src:find(":SetOwner%([^)]*\"ANCHOR_[A-Z_]*\""), path .. " owns a tooltip at an anchor")
    end
    local f = assert(io.open("modules/Anchors_Tooltip.lua", "r"))
    local hook = f:read("*a")
    f:close()
    assertTrue(not hook:find("GetCursorPosition", 1, true), "the strip's placement never reads the cursor")
end)
