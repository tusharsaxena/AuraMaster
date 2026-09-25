-- tests/test_anchors_width.lua - batch 11 T11: the strip is never wider than its container. The
-- owner's report (2026-09-26): five Bars containers of one bar width in test mode, and the strips of
-- the three with long names ran about 15 px past their bars, because the widget floors its width at
-- the element and otherwise takes its natural one (the name, the TEST tag, the pads and the marks).
-- The strip is now the element's width, and a name that does not fit is shortened with "...", the
-- TEST tag kept after it. A container too narrow for the marks, the pads and a readable label keeps
-- the natural width, so a one-icon container still shows its name.
-- Its own suite because tests/test_anchors.lua sits near layout-§1's 1500-line cap.

local T = _G.AM_TEST
local test, assertEqual, assertTrue =
    T.test, T.assertEqual, T.assertTrue
local fresh = dofile("tests/fresh_env.lua")

local PX = 6   -- what one character measures in the stand-in measurer
local RESERVE2 = 94   -- the widget's reserve on both sides of the label, the close mark included

--- The text a label draws, its color escapes removed (the client does not measure them either).
local function plain(s)
    return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

--- What `s` measures: PX per character it draws.
local function widthOf(s)
    local drawn = plain(s)
    return #drawn * PX
end

--- Every label measures PX per character it draws.
local function measurePerChar(mocks)
    mocks.LibStub("LibKa0s-Widgets-1.0").__DragHandleMeasurer = function()
        local text = ""
        return {
            SetText = function(_, s) text = s end,
            GetStringWidth = function() return widthOf(text) end,
        }
    end
end

--- Container `id` shown unlocked with `name`, its strip's last width and its label's last text
--- recorded (in the kit the label is the strip itself).
local function stripOf(NS, mocks, id, name)
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    measurePerChar(mocks)
    local cfg = NS.Database.FindContainer(id)
    cfg.name = name
    local inst = NS.ContainerManager.instances[id]
    local rec = {}
    rawset(inst.handle, "SetWidth", function(_, w) rec.width = w end)
    rawset(inst.handle, "SetText", function(_, s) rec.text = s end)
    rawset(inst.anchor, "SetClampRectInsets", function(_, l, r, t, b) rec.insets = { l, r, t, b } end)
    inst.clampInsets = nil
    NS.Anchors.UpdateHandle(inst, true)
    return rec, inst, cfg
end

local LONG = "Target Defensive (All) and a long tail"

test("width: a long name on a wide Bars container gives a strip exactly as wide as its bar, the name shortened with ...", function()
    local NS, mocks = fresh()
    local rec, inst, cfg = stripOf(NS, mocks, 1, LONG)
    local w = NS.Style.ElementSize(cfg)
    assertEqual(cfg.style, "bars")
    -- red under: handle:ApplyWidth(w), which takes the natural width (#LONG * 6 + 94 = 322 > 220)
    assertEqual(rec.width, w, "the strip is the bar's width")
    local text = plain(rec.text)
    assertTrue(#text * PX <= w - RESERVE2, "the label fits between the marks: " .. text)
    assertEqual(text:sub(-3), "...", "shortened with an ellipsis")
    assertEqual(LONG:sub(1, #text - 3):gsub("%s+$", ""), text:sub(1, -4), "a prefix of the name")
    assertTrue(#text > 3, "some of the name still reads")
    assertEqual(inst.stripOverhang, 0, "no overhang when capped")
    assertEqual(rec.insets[1], 0); assertEqual(rec.insets[2], 0, "the clamp reaches no further along the line")
end)

test("width: in test mode the name is shortened, never the TEST tag, which stays after it", function()
    local NS, mocks = fresh()
    NS.State.testMode = true
    local rec, inst, cfg = stripOf(NS, mocks, 1, "Target Debuffs (Mine) long")
    local w = NS.Style.ElementSize(cfg)
    -- red under: the natural width (the name, two spaces and TEST, plus the reserve)
    assertEqual(rec.width, w)
    local text = plain(rec.text)
    local tag = "  " .. NS.L["TEST"]
    assertEqual(text:sub(-#tag), tag, "the TEST tag kept whole, last")
    assertEqual(text:sub(-#tag - 3, -#tag - 1), "...", "the name before it shortened")
    assertTrue(#text * PX <= w - RESERVE2, "and the whole of it fits: " .. text)
    assertTrue(rec.text:find(NS.Constants.TEST_TAG_COLOR, 1, true) ~= nil, "the tag still orange")
    assertEqual(inst.stripOverhang, 0)
end)

test("width: a name that fits is drawn whole, the strip still the bar's width", function()
    local NS, mocks = fresh()
    NS.State.testMode = true
    local rec, _, cfg = stripOf(NS, mocks, 1, "Target CC")
    assertEqual(rec.width, NS.Style.ElementSize(cfg))
    assertEqual(plain(rec.text), "Target CC  " .. NS.L["TEST"], "nothing shortened")
end)

test("width: the full name stays the strip's tooltip title", function()
    local NS, mocks = fresh()
    local _, inst = stripOf(NS, mocks, 1, LONG)
    local lib = mocks.LibStub("LibKa0s-Widgets-1.0")
    local build, spec = lib.DragHandle, nil
    lib.DragHandle = function(parent, s)
        spec = s
        return build(parent, s)
    end
    NS.Anchors.BuildHandle(inst)
    lib.DragHandle = build
    assertEqual(spec.tooltip.title(), LONG)
end)

test("width: a one-icon container too narrow for the marks and a readable label keeps its natural width", function()
    local NS, mocks = fresh()
    local rec, inst, cfg = stripOf(NS, mocks, 2, LONG)
    local w = NS.Style.ElementSize(cfg)
    assertEqual(cfg.style, "icons")
    assertTrue(w < RESERVE2 + 40, "one icon is narrower than the marks and a label")
    assertEqual(rec.width, #LONG * PX + RESERVE2, "the name and the marks, as before")
    assertEqual(plain(rec.text), LONG, "nothing shortened")
    assertEqual(inst.stripOverhang, #LONG * PX + RESERVE2 - w, "the overhang an ahead follower clears")
end)

test("width: the label is worked out once per name and width, not on every pass", function()
    local NS, mocks = fresh()
    local _, inst = stripOf(NS, mocks, 1, LONG)
    local calls = 0
    local lib = mocks.LibStub("LibKa0s-Widgets-1.0")
    local measurer = lib.__DragHandleMeasurer
    lib.__DragHandleMeasurer = function(...)
        calls = calls + 1
        return measurer(...)
    end
    NS.Anchors.UpdateHandle(inst, true)
    NS.Anchors.UpdateHandle(inst, true)
    assertEqual(calls, 0, "an unchanged name and width measure nothing")
end)
