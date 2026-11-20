-- tests/test_anchors_tooltip.lua — the drag strip's tooltip and its marks' (AF-STRIP-AM, LibKa0s
-- v1.107.0, the owner's rulings of 2026-11-19, *Strip marks* and *Strip tooltip*): the strip's own
-- tooltip, and its "?"'s, gear's and X's, open centered above the strip through the library's
-- attached placement (WidgetsDragHandleTip minor 2), owned by UIParent at ANCHOR_NONE and pinned to
-- UIParent alone, never at the cursor. The addon passes no placement of its own: its `tooltipPlace`
-- hook (the Anchors_Tooltip file, which put the tooltip beside the strip since issue #22 and
-- AD-92-AM) was deleted in AF-STRIP-AM. BuildHandle hands the widget all three marks' wiring: the
-- close handler and its own tooltip, the settings opener and its own tooltip, so no mark falls back to
-- the strip's drag hint.
--
-- Standalone-windows *The drag strip's marks* and *Tooltip placement* (WowAddonStandards v2.115.0).
-- An aura's tooltip is not this file's: it stays the client's (Layout's tooltip position, wave C
-- option B), and the guard below keeps every TOC file off the cursor.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local HR = dofile("tests/handle_recorder.lua")

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

test("tooltip: the strip and each of its marks show it centered above the strip, owned by UIParent with no anchor", function()
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
        -- LibKa0s v1.107.0 (WidgetsDragHandleTip minor 2, AF-LK-02, the owner's ruling of 2026-11-19):
        -- the strip's tooltip, and its marks', always takes the library's attached placement, centered
        -- above the strip. Through v1.106.0 this addon's retired hook put it beside the strip (TOPLEFT
        -- at the strip's right edge + TIP_GAP).
        -- red under: a payload before WidgetsDragHandleTip minor 2 with a beside hook passed
        assertEqual(#owners, 1, "frame " .. i .. ": owned once")
        assertTrue(owners[1].owner == mocks.UIParent)
        assertEqual(owners[1].anchor, "ANCHOR_NONE")
        assertEqual(#points, 1)
        assertEqual(points[1][1], "BOTTOM", "frame " .. i .. ": above the strip")
        assertTrue(points[1][2] == mocks.UIParent, "anchored to UIParent, never into the strip's tree")
        assertEqual(points[1][4], 200, "centered on the strip")
        assertEqual(points[1][5], 500 + gap, "TIP_GAP over the strip's top")
    end
end)

test("tooltip: a strip whose rect reads secret, or not at all, raises nothing, reads no cursor and is never anchored into the strip's tree", function()
    -- A container attached under a parent holding auras can read its strip's rect as secret in an
    -- instance or in combat. Here the strip's parents read nothing either, so the library (from
    -- WidgetsDragHandleTip minor 3, LibKa0s#99) finds no readable ancestor and hides the tooltip;
    -- the case above has one. A relative point on the strip is what the client refuses for a
    -- restricted tree; the mock raises on that point, as the client does. The hover must not raise, must not read the cursor, owns the tooltip once at UIParent /
    -- ANCHOR_NONE, and lands no point relative to the strip or any of its marks.
    -- red under: a placement that reads the cursor, does arithmetic on a secret edge, or anchors
    -- GameTooltip into the strip's tree without the client refusing it
    local SECRET = 63.5
    for _, rect in ipairs{ "secret", "unread" } do
        local NS, mocks = fresh()
        screen(mocks, 1920)
        noCursor(mocks)
        mocks.issecretvalue = function(v) return v == SECRET end
        local inst = NS.ContainerManager.instances[1]
        local h = HR.recordedHandle(mocks, NS, inst)
        local edge = rect == "secret" and SECRET or nil
        for _, k in ipairs{ "GetLeft", "GetBottom", "GetRight", "GetTop" } do
            rawset(h, k, function() return edge end)
        end
        rawset(h, "GetEffectiveScale", function() return 1 end)
        local tree = { [h] = true }
        local marks = { h }
        for _, key in ipairs{ "help", "close", "settings" } do
            if h[key] then
                rawset(h[key], "GetParent", function() return h end)
                marks[#marks + 1] = h[key]
                tree[h[key]] = true
            end
        end
        assertEqual(#marks, 4, rect .. ": the strip, its ?, its X and its settings mark")
        rawset(mocks.GameTooltip, "GetWidth", function() return 200 end)
        rawset(mocks.GameTooltip, "GetHeight", function() return 80 end)
        rawset(mocks.GameTooltip, "GetEffectiveScale", function() return 1 end)
        for i, frame in ipairs(marks) do
            local owners, points = {}, {}
            rawset(mocks.GameTooltip, "SetOwner", function(_, owner, anchor)
                owners[#owners + 1] = { owner = owner, anchor = anchor }
            end)
            rawset(mocks.GameTooltip, "SetPoint", function(_, point, rel, ...)
                if tree[rel] then error("restricted: the client refuses an anchor into this tree") end
                points[#points + 1] = { point, rel, ... }
            end)
            local ok, err = pcall(frame.__fire, frame, "OnEnter")
            local label = rect .. " frame " .. i
            assertTrue(ok, label .. ": the hover raised: " .. tostring(err))
            assertEqual(#owners, 1, label .. ": owned once")
            assertTrue(owners[1].owner == mocks.UIParent, label .. ": owned by UIParent")
            assertEqual(owners[1].anchor, "ANCHOR_NONE", label)
            for _, p in ipairs(points) do
                assertTrue(not tree[p[2]], label .. ": a point relative to the strip landed")
            end
        end
    end
end)

test("tooltip: a strip whose rect reads secret shows its tooltip above its nearest readable container (LibKa0s#99, SD-AM-99)", function()
    -- LibKa0s v1.108.0 (WidgetsDragHandleTip minor 3, the owner's ruling R-3 of 2026-11-20): where the
    -- strip's rect reads secret (a container attached under a parent holding auras), the library walks
    -- the strip's ancestors and places the tooltip above the nearest one whose rect reads, by an
    -- absolute point on UIParent, so nothing anchors into the restricted tree. Secret all the way up,
    -- the tooltip is hidden. Retires AF-STRIP-AM's known limitation (docs/known-limitations.md).
    -- red under: WidgetsDragHandleTip minor 2 (no ancestor walk: no point on UIParent at all)
    local SECRET = 63.5
    for _, readable in ipairs{ true, false } do
        local NS, mocks = fresh()
        screen(mocks, 1920)
        noCursor(mocks)
        local gap = mocks.LibStub("LibKa0s-Tooltip-1.0").TIP_GAP
        mocks.issecretvalue = function(v) return v == SECRET end
        local h = HR.recordedHandle(mocks, NS, NS.ContainerManager.instances[1])
        for _, k in ipairs{ "GetLeft", "GetBottom", "GetRight", "GetTop" } do
            rawset(h, k, function() return SECRET end)
        end
        rawset(h, "GetEffectiveScale", function() return 1 end)
        -- The strip's parent: the readable container frame it hangs from, or another secret one.
        local parent = mocks.CreateFrame("Frame", nil, mocks.UIParent)
        local rect = readable and { GetLeft = 100, GetBottom = 300, GetRight = 400, GetTop = 500 } or
            { GetLeft = SECRET, GetBottom = SECRET, GetRight = SECRET, GetTop = SECRET }
        for k, v in pairs(rect) do rawset(parent, k, function() return v end) end
        rawset(parent, "GetEffectiveScale", function() return 1 end)
        rawset(parent, "GetParent", function() return mocks.UIParent end)
        rawset(h, "GetParent", function() return parent end)
        rawset(mocks.GameTooltip, "GetWidth", function() return 200 end)
        rawset(mocks.GameTooltip, "GetHeight", function() return 80 end)
        rawset(mocks.GameTooltip, "GetEffectiveScale", function() return 1 end)
        local hidden = false
        rawset(mocks.GameTooltip, "Hide", function() hidden = true end)
        local owners, points = hover(mocks, h)
        local label = readable and "a readable parent" or "secret all the way up"
        assertEqual(#owners, 1, label .. ": owned once")
        assertTrue(owners[1].owner == mocks.UIParent, label .. ": owned by UIParent")
        if readable then
            assertEqual(#points, 1, label .. ": one point")
            assertEqual(points[1][1], "BOTTOM", label .. ": above the container")
            assertTrue(points[1][2] == mocks.UIParent, label .. ": on UIParent, never into the strip's tree")
            assertEqual(points[1][4], 250, label .. ": centered on the container")
            assertEqual(points[1][5], 500 + gap, label .. ": TIP_GAP over the container's top")
            assertTrue(not hidden, label .. ": shown")
        else
            assertEqual(#points, 0, label .. ": no point")
            assertTrue(hidden, label .. ": hidden, no error")
        end
    end
end)

test("tooltip: BuildHandle wires all three marks, each with its own tooltip, and passes no placement", function()
    local NS, mocks = fresh()
    local KW = mocks.LibStub("LibKa0s-Widgets-1.0")
    local real, spec = KW.DragHandle, nil
    KW.DragHandle = function(parent, s) spec = s; return real(parent, s) end
    NS.Anchors.BuildHandle(NS.ContainerManager.instances[1])
    KW.DragHandle = real
    assertTrue(spec ~= nil, "the strip was built")
    -- red under: the strip `tooltipPlace` hook still passed (AF-STRIP-AM; unread since
    -- WidgetsDragHandleTip minor 2, so the library places the strip's tooltip above it)
    assertNil(spec.tooltipPlace, "no host placement for the strip's tooltip")
    -- red under: `tooltipOwner = "cursor"` still passed (retired at WidgetsDragHandle minor 14)
    assertNil(spec.tooltipOwner)
    assertNil(spec.tooltipAnchor)
    -- The marks (the owner's ruling: all three on every strip, ? · settings · close).
    assertTrue(spec.settings ~= false, "the settings mark is not opted out")
    assertEqual(type(spec.settings), "function", "the gear opens this container's own settings")
    assertEqual(type(spec.onClose), "function", "the X has a close handler, so the widget builds it")
    -- Each mark's own words, so neither falls back to the strip's drag hint (spec.tooltip).
    for _, key in ipairs{ "closeTooltip", "settingsTooltip" } do
        local d = spec[key]
        assertTrue(type(d) == "table" and d ~= spec.tooltip, key .. " is the mark's own descriptor")
        assertEqual(type(d.title), "function", key .. ": the container's name, read on every hover")
        assertTrue(type(d.body) == "table" and type(d.body[1]) == "string", key .. ": a line saying what the click does")
    end
    -- The X's tooltip says how to bring the container back (the close keeps its settings).
    local body = spec.closeTooltip.body[1]
    assertTrue(body:find("Containers page", 1, true) ~= nil, "the X's tooltip names where to turn it back on")
    assertTrue(body:find("settings are kept", 1, true) ~= nil, "the X's tooltip says its settings are kept")
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
        -- red under: a strip `tooltipPlace` hook back in any file (AF-STRIP-AM: retired at
        -- WidgetsDragHandleTip minor 2, and the standard's *The drag strip's marks* calls one dead code)
        assertTrue(not src:find("tooltipPlace%s*="), path .. " passes the retired tooltipPlace")
    end
    -- The hook's file is gone (AF-STRIP-AM): nothing in the TOC places the strip's tooltip.
    for _, path in ipairs(files) do
        assertTrue(path ~= "modules/Anchors_Tooltip.lua", "the retired hook's file is still loaded")
    end
end)
