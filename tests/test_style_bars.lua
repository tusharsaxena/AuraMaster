-- tests/test_style_bars.lua — modules/Style_Bars.lua: how one aura is dressed as a BAR. Every
-- setting reaching the region it paints, the icon side and gap, the drain direction the fill and
-- the spark follow, the texts, the engine bindings, and the preview fill.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local NS = T.NS
local R = dofile("tests/region_recorder.lua")
local D = NS.CONTAINER_TEMPLATE

local function cfg(over)
    return NS.Database.Merge(NS.Database.DeepCopy(D), over or {})
end

--- Dress a bar element for `c`, swap each of its regions for a recorder, and dress it again, so
--- every call a region receives is its own. The element itself is a recorder too: engine bindings
--- land in its log.
local function dressed(c, engine, classColor, ns)
    ns = ns or NS
    local frame = R()
    ns.Style.Element(frame, c, engine, classColor)
    for k in pairs(frame.__am) do frame.__am[k] = R() end
    frame.__log = {}
    ns.Style.Element(frame, c, engine, classColor)
    return frame, frame.__am
end

--- One environment with the client's status-bar and dispel enums, for the binding cases. Built
--- once: nothing below writes to it.
local enumEnv
local function withEnums()
    if not enumEnv then
        enumEnv = dofile("tests/fresh_env.lua")({ before = function(m)
            m.Enum = m.Enum or {}
            m.Enum.StatusBarTimerDirection = { ElapsedTime = 11, RemainingTime = 12 }
            m.Enum.StatusBarInterpolation = { Immediate = 21, ExponentialEaseOut = 22 }
            m.Enum.CustomAuraButtonDispelTypeTextureStyle = { Border = 31, PreserveAsset = 32 }
        end })
    end
    return enumEnv
end

-- ── layout ────────────────────────────────────────────────────────────────────────────────────

test("bars: the element takes its configured size, and a left icon is a square of the bar's height", function()
    local frame, am = dressed(cfg({ bars = { width = 200, height = 20, icon = "LEFT", iconSize = 0, iconGap = 3 } }))
    assertEqual(frame:__joined("SetSize"), "200,20", "the element's size")
    -- red under: layout sizing the icon from iconSize without the zero-means-height rule
    assertEqual(am.icon:__joined("SetSize"), "20,20", "iconSize 0 means the bar's height")
    local p = am.icon:__last("SetPoint")
    assertEqual(p[1], "LEFT"); assertTrue(p[2] == frame); assertEqual(p[3], "LEFT")
    local bar = am.bar:__calls("SetPoint")
    assertEqual(bar[1][1], "TOPLEFT"); assertEqual(bar[1][4], 20 + 3, "the bar starts after the icon and its gap")
    assertEqual(bar[2][1], "BOTTOMRIGHT"); assertEqual(bar[2][4], 0)
    assertTrue(am.icon:IsShown())
end)

test("bars: a right icon pins to the right edge and the bar stops short of it by the icon and its gap", function()
    local frame, am = dressed(cfg({ bars = { height = 18, icon = "RIGHT", iconSize = 24, iconGap = 2 } }))
    assertEqual(am.icon:__joined("SetSize"), "24,24", "an explicit icon size wins over the height")
    local p = am.icon:__last("SetPoint")
    assertEqual(p[1], "RIGHT"); assertTrue(p[2] == frame)
    local bar = am.bar:__calls("SetPoint")
    assertEqual(bar[1][1], "TOPLEFT"); assertEqual(bar[1][4], 0)
    -- red under: the RIGHT branch offsetting the bar's left edge like the LEFT one
    assertEqual(bar[2][1], "BOTTOMRIGHT"); assertEqual(bar[2][4], -(24 + 2))
end)

test("bars: without an icon the bar fills the whole element and the icon is hidden", function()
    local frame, am = dressed(cfg({ bars = { icon = "NONE" } }))
    assertFalse(am.icon:IsShown(), "the icon is hidden")
    local all = am.bar:__last("SetAllPoints")
    -- red under: the NONE branch leaving the bar inset by an icon that is not there
    assertTrue(all ~= nil and all[1] == frame, "the bar covers the element")
    assertEqual(am.bar:__count("SetPoint"), 0)
end)

test("bars: the background sits under the bar area, never under the icon", function()
    local _, am = dressed(cfg({ bars = { icon = "LEFT" } }))
    local all = am.bg:__last("SetAllPoints")
    -- red under: the background anchored to the element instead of the bar
    assertTrue(all ~= nil and all[1] == am.bar)
end)

test("bars: the icon zoom crops the texture evenly from every side", function()
    local _, am = dressed(cfg({ bars = { iconZoom = 0.1 } }))
    -- red under: SetTexCoord handed the zoom without its 1 - z mirror
    assertEqual(am.icon:__joined("SetTexCoord"), "0.1,0.9,0.1,0.9")
end)

-- ── drain, fill and spark ─────────────────────────────────────────────────────────────────────

test("bars: draining left, the fill runs from the bar's start to the timer's edge and the spark rides its right end", function()
    local _, am = dressed(cfg({ bars = { drain = "left" } }))
    local edge = am.bar:GetStatusBarTexture()
    assertEqual(am.bar:__joined("SetReverseFill"), "true", "elapsed grows from the right")
    local pts = am.fill:__calls("SetPoint")
    assertEqual(pts[1][1], "TOPLEFT"); assertTrue(pts[1][2] == am.bar)
    -- red under: wireFill anchoring the fill's end to the bar rather than the timer's moving edge
    assertEqual(pts[2][1], "BOTTOMRIGHT"); assertTrue(pts[2][2] == edge); assertEqual(pts[2][3], "BOTTOMLEFT")
    local s = am.spark:__last("SetPoint")
    assertEqual(s[1], "CENTER"); assertTrue(s[2] == am.fill); assertEqual(s[3], "RIGHT")
end)

test("bars: draining right, the fill runs from the timer's edge to the bar's end and the spark rides its left end", function()
    local _, am = dressed(cfg({ bars = { drain = "right" } }))
    local edge = am.bar:GetStatusBarTexture()
    -- red under: wireFill ignoring the drain setting
    assertEqual(am.bar:__joined("SetReverseFill"), "false")
    local pts = am.fill:__calls("SetPoint")
    assertEqual(pts[1][1], "TOPLEFT"); assertTrue(pts[1][2] == edge); assertEqual(pts[1][3], "TOPRIGHT")
    assertEqual(pts[2][1], "BOTTOMRIGHT"); assertTrue(pts[2][2] == am.bar)
    local s = am.spark:__last("SetPoint")
    assertEqual(s[3], "LEFT", "the spark leads from the left")
end)

test("bars: the spark shows unless turned off, twice the bar's height, in its own width and color", function()
    local _, am = dressed(cfg({ bars = { height = 16, spark = true, sparkWidth = 6,
        sparkColor = { r = 0.3, g = 0.4, b = 0.5, a = 0.7 } } }))
    assertTrue(am.spark:IsShown())
    assertEqual(am.spark:__joined("SetSize"), "6,32")
    assertEqual(am.spark:__joined("SetVertexColor"), "0.3,0.4,0.5,0.7")
    _, am = dressed(cfg({ bars = { spark = false } }))
    -- red under: applySurfaces showing the spark whatever the setting
    assertFalse(am.spark:IsShown())
    local c = cfg()
    c.bars.sparkWidth = nil
    _, am = dressed(c)
    assertEqual(am.spark:__last("SetSize")[1], D.bars.sparkWidth, "a missing width is the template's")
end)

-- ── surfaces ──────────────────────────────────────────────────────────────────────────────────

test("bars: class colors paint the fill, background, spark and border with the dress's class, keeping each alpha", function()
    local class = { r = 0.9, g = 0.8, b = 0.7 }
    local _, am = dressed(cfg({ bars = {
        barColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.5 }, useClassColorBar = true,
        bgColor = { r = 0.2, g = 0.2, b = 0.2, a = 0.4 }, useClassColorBg = true,
        sparkColor = { r = 0.3, g = 0.3, b = 0.3, a = 0.3 }, useClassColorSpark = true,
        borderShow = true, borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 0.2 }, useClassColorBorder = true,
    } }), false, class)
    -- red under: any one surface reading its color without its useClassColor* companion
    assertEqual(am.fill:__joined("SetVertexColor"), "0.9,0.8,0.7,0.5", "fill")
    assertEqual(am.bg:__joined("SetVertexColor"), "0.9,0.8,0.7,0.4", "background")
    assertEqual(am.spark:__joined("SetVertexColor"), "0.9,0.8,0.7,0.3", "spark")
    assertEqual(am.border:__joined("SetBackdropBorderColor"), "0.9,0.8,0.7,0.2", "border")
end)

test("bars: the class companions left off paint every surface its stored swatch", function()
    local _, am = dressed(cfg({ bars = {
        barColor = { r = 0.1, g = 0.2, b = 0.3, a = 1 }, sparkColor = { r = 0.4, g = 0.5, b = 0.6, a = 1 },
    } }), false, { r = 0.9, g = 0.8, b = 0.7 })
    -- red under: Style.Color painting the dress class whenever one is set
    assertEqual(am.fill:__joined("SetVertexColor"), "0.1,0.2,0.3,1")
    assertEqual(am.spark:__joined("SetVertexColor"), "0.4,0.5,0.6,1")
end)

--- A fresh environment whose template holds `value` at bars.<key>. A case proving a fallback READS
--- the template, rather than restating a number that happens to equal it, has to move the template's
--- value, and the shared environment's template is read by every suite, so it moves one of its own.
local function withTemplate(key, value)
    local ns = dofile("tests/fresh_env.lua")()
    ns.CONTAINER_TEMPLATE.bars[key] = value
    return ns
end

test("bars: a missing bar opacity paints the template's, never a number restated in the composer", function()
    local ns = withTemplate("barAlpha", 0.35)
    local c = cfg()
    c.bars.barAlpha = nil
    local _, am = dressed(c, nil, nil, ns)
    -- red under: applySurfaces falling back to a literal 1 for a missing barAlpha
    assertEqual(am.fill:__last("SetAlpha")[1], 0.35)
end)

test("bars: a missing border size paints the template's, so a border turned on still shows", function()
    local c = cfg({ bars = { borderShow = true, borderStyle = "Solid" } })
    c.bars.borderSize = nil
    local _, am = dressed(c)
    -- red under: applySurfaces handing ApplyBorder the raw borderSize (a missing size hides the border)
    assertTrue(am.border:IsShown())
    assertEqual(am.border:__last("SetBackdrop")[1].edgeSize, D.bars.borderSize)
end)

test("bars: a bar border shows only when turned on, with its style, size and color", function()
    local _, am = dressed(cfg({ bars = { borderShow = false } }))
    assertFalse(am.border:IsShown(), "off by default for bars")
    _, am = dressed(cfg({ bars = { borderShow = true, borderStyle = "Solid", borderSize = 3,
        borderColor = { r = 1, g = 0, b = 0, a = 1 } } }))
    assertTrue(am.border:IsShown())
    local bd = am.border:__last("SetBackdrop")[1]
    -- red under: applySurfaces handing ApplyBorder the icon style's leaves
    assertEqual(bd.edgeSize, 3)
    assertEqual(bd.edgeFile, NS.Style.Fetch("border", "Solid", NS.Constants.FALLBACK_BORDER))
    assertEqual(am.border:__joined("SetBackdropBorderColor"), "1,0,0,1")
end)

test("bars: the refresh-window highlight takes the pandemic color, never a class color", function()
    local _, am = dressed(cfg({ bars = { pandemicColor = { r = 1, g = 0.5, b = 0, a = 0.6 },
        useClassColorBar = true } }), false, { r = 0.9, g = 0.8, b = 0.7 })
    -- red under: the pandemic wash reading a class companion
    assertEqual(am.pandemic:__joined("SetVertexColor"), "1,0.5,0,0.6")
end)

-- ── texts ─────────────────────────────────────────────────────────────────────────────────────

test("bars: the name stops short of the time text, and runs to the bar's end when the time is hidden", function()
    local _, am = dressed(cfg())
    local stop
    for _, p in ipairs(am.name:__calls("SetPoint")) do
        if p[1] == "RIGHT" and p[2] == am.time then stop = p end
    end
    -- red under: applyTexts dropping the name's right stop
    assertTrue(stop ~= nil, "the name ends at the time text")
    assertEqual(stop[3], "LEFT"); assertEqual(stop[4], -4)
    _, am = dressed(cfg({ bars = { time = { show = false } } }))
    for _, p in ipairs(am.name:__calls("SetPoint")) do
        assertFalse(p[2] == am.time, "a hidden time text still clips the name")
    end
    assertFalse(am.time:IsShown())
end)

test("bars: each text shows or hides on its own setting", function()
    local _, am = dressed(cfg({ bars = { name = { show = false }, stacks = { show = false } } }))
    -- red under: applyTexts showing every text whatever its block says
    assertFalse(am.name:IsShown(), "name")
    assertTrue(am.time:IsShown(), "time")
    assertFalse(am.stacks:IsShown(), "stacks")
end)

test("bars: the stack count sits on the icon, or on the bar when there is no icon", function()
    local _, am = dressed(cfg({ bars = { icon = "LEFT" } }))
    assertTrue(am.stacks:__last("SetPoint")[2] == am.icon, "on the icon")
    _, am = dressed(cfg({ bars = { icon = "NONE" } }))
    -- red under: the stack host fixed to the icon, which is hidden without one
    assertTrue(am.stacks:__last("SetPoint")[2] == am.bar, "on the bar")
end)

test("bars: the name and time are laid against the bar, in their configured corners", function()
    local _, am = dressed(cfg({ bars = { name = { point = "TOPLEFT", x = 2, y = -1 } } }))
    local p = am.name:__calls("SetPoint")[1]
    -- red under: applyTexts anchoring a text to the element rather than the bar area
    assertTrue(p[2] == am.bar)
    assertEqual(p[1], "TOPLEFT"); assertEqual(p[3], "TOPLEFT"); assertEqual(p[4], 2); assertEqual(p[5], -1)
    assertTrue(am.time:__calls("SetPoint")[1][2] == am.bar)
end)

test("bars: each text is boxed to its host less its offset: the bar area, or the icon for the stacks on it", function()
    -- The template's 220 x 18 element with a left icon of the bar's height and a 1px gap: a 201px bar area.
    local _, am = dressed(cfg({ bars = { name = { show = false } } }))
    -- red under: applyTexts handing the texts no box (their justification has nothing to align within)
    assertEqual(am.time:__last("SetWidth")[1], 201 - 4, "time, with no name beside it")
    assertEqual(am.stacks:__last("SetWidth")[1], 18 - 1, "stacks on the icon")
    _, am = dressed(cfg({ bars = { icon = "NONE" } }))
    -- red under: the stacks boxed to the icon when there is none and they sit on the bar
    assertEqual(am.stacks:__last("SetWidth")[1], 220 - 1, "stacks on the bar")
    assertEqual(am.name:__last("SetWidth")[1], 220 - 4, "name")
end)

test("bars: the time sizes to its own text while the name stops short of it, so the name keeps its room", function()
    local _, am = dressed(cfg())
    -- red under: a time text boxed across the bar area (the name's stop lands at the bar's start)
    assertEqual(am.time:__last("SetWidth")[1], 0)
    assertEqual(am.name:__last("SetWidth")[1], 201 - 4, "the name's own box, which its second anchor overrides")
end)

-- ── engine bindings ───────────────────────────────────────────────────────────────────────────

test("bars: the engine drives the timer bar by elapsed time, eased only when smoothing is on", function()
    local NS2 = withEnums()
    local c = NS2.Database.Merge(NS2.Database.DeepCopy(NS2.CONTAINER_TEMPLATE), { bars = { smooth = true } })
    local frame, am = dressed(c, true, nil, NS2)
    local bind = frame:__last("SetDurationBar")
    assertTrue(bind[1] == am.bar, "the engine's own status bar")
    -- red under: TimerDirection("remaining"), which would draw a timeless aura empty
    assertEqual(bind[2].direction, 11, "elapsed time")
    assertEqual(bind[2].interpolation, 22, "eased")
    c.bars.smooth = false
    frame = dressed(c, true, nil, NS2)
    -- red under: Interpolation ignoring the smooth setting
    assertEqual(frame:__last("SetDurationBar")[2].interpolation, 21, "immediate")
end)

test("bars: a hidden region is never handed to the engine", function()
    local c = cfg({ bars = { icon = "NONE", name = { show = false }, time = { show = false },
        stacks = { show = false } } })
    local frame = dressed(c, true)
    -- red under: Bars.Bind binding every region whatever its show setting
    assertEqual(frame:__count("SetIcon"), 0, "icon")
    assertEqual(frame:__count("SetSpellName"), 0, "name")
    assertEqual(frame:__count("SetDurationText"), 0, "time")
    assertEqual(frame:__count("SetApplicationCount"), 0, "stacks")
    assertEqual(frame:__count("SetDurationBar"), 1, "the timer bar is always bound")
end)

test("bars: every shown region is bound to its own engine field", function()
    local frame, am = dressed(cfg(), true)
    -- red under: a binding handed the wrong region (the kit aliases regions, so only a recorder sees it)
    assertTrue(frame:__last("SetIcon")[1] == am.icon, "icon")
    assertTrue(frame:__last("SetSpellName")[1] == am.name, "name")
    assertTrue(frame:__last("SetDurationText")[1] == am.time, "time")
    assertTrue(frame:__last("SetApplicationCount")[1] == am.stacks, "stacks")
end)

test("bars: dispel coloring tints the fill through the engine with the stored dispel colors", function()
    local NS2 = withEnums()
    local c = NS2.Database.Merge(NS2.Database.DeepCopy(NS2.CONTAINER_TEMPLATE), { bars = { colorMode = "dispel" } })
    local frame, am = dressed(c, true, nil, NS2)
    local add = frame:__last("AddDispelTypeTexture")
    assertTrue(add[1] == am.fill, "the fill carries the tint")
    -- red under: the bar asking for the Border style, which paints Blizzard's debuff art over the bar
    assertEqual(add[2].style, 32, "PreserveAsset keeps our texture")
    assertTrue(add[2].showAlways and add[2].showWithoutDispelType, "shown for every aura")
    -- red under: the bar still reading a per-container bars.dispelColors (schema v2 lifted it)
    assertTrue(add[2].customDispelColorMap == NS2.Style.DispelColorMap(NS2.db.profile.dispelColors), "the profile's colors")
    c.bars.colorMode = "static"
    frame = dressed(c, true, nil, NS2)
    assertEqual(frame:__count("AddDispelTypeTexture"), 0, "one color: no tint")
    assertEqual(frame:__count("ClearDispelTypeTextures"), 1, "and an earlier tint is cleared")
end)

-- ── Color by: dispel type lets go (B-4) ──────────────────────────────────────────────────────────

local engineButton = dofile("tests/engine_recorder.lua")
local MAGIC = { 0.2, 0.4, 1, 1 }   -- the engine's dispel tint, a color no swatch below uses

--- Dress ONE live bar button for each colorMode in `modes`, in turn, the button answering like the
--- client's (tests/engine_recorder.lua; `aura` false: a pooled button holding no aura). Every log is
--- emptied before the last dress, so the logs hold that dress alone.
local function toggled(modes, aura)
    local NS2 = withEnums()
    local c = NS2.Database.Merge(NS2.Database.DeepCopy(NS2.CONTAINER_TEMPLATE),
        { bars = { barColor = { r = 0.9, g = 0.5, b = 0.1, a = 1 }, useClassColorBar = false } })
    local frame = R()
    NS2.Style.Element(frame, c, true)
    for k in pairs(frame.__am) do frame.__am[k] = R() end
    engineButton(frame, { tint = MAGIC, aura = aura })
    local last = #modes
    for i, mode in ipairs(modes) do
        if i == last then
            frame.__log = {}
            for _, r in pairs(frame.__am) do r.__log = {} end
        end
        c.bars.colorMode = mode
        NS2.Style.Element(frame, c, true)
    end
    return frame, frame.__am, table.concat({ NS2.Style.Color(c.bars.barColor, false) }, ",")
end

test("bars: switching Color by from dispel type back to static paints the bar's own color again", function()
    local frame, am, barColor = toggled({ "static", "dispel", "static" }, true)
    -- red under: Bars.Bind clearing the dispel texture after SetDurationBar, whose apply pass re-tints the fill
    assertEqual(am.fill:__joined("SetVertexColor"), barColor, "the static color is the last word")
    assertTrue(frame:__lastSeq("ClearDispelTypeTextures") < am.fill:__lastSeq("SetVertexColor"),
        "the tint is cleared before the fill is painted")
    assertTrue(frame:__lastSeq("ClearDispelTypeTextures") < frame:__lastSeq("SetDurationBar"),
        "and before any binding can run a pass over it")
    assertTrue(am.fill:IsShown(), "the fill shows")
end)

test("bars: back to static on a button holding no aura, the fill the engine hid shows again", function()
    local _, am = toggled({ "static", "dispel", "static" }, false)
    -- red under: applySurfaces never showing the fill (the engine's no-aura pass hid it, and Clear restores nothing)
    assertTrue(am.fill:IsShown())
end)

test("bars: in dispel mode the engine's tint stays the fill's last color", function()
    local _, am = toggled({ "static", "dispel" }, true)
    -- red under: repainting the static color after the bindings (the dispel tint then never shows)
    assertEqual(am.fill:__joined("SetVertexColor"), table.concat(MAGIC, ","))
end)

test("bars: the refresh-window highlight is bound only when turned on, and always cleared first", function()
    local frame, am = dressed(cfg({ bars = { pandemic = true } }), true)
    assertTrue(frame:__last("AddPandemicRegion")[1] == am.pandemic)
    frame = dressed(cfg({ bars = { pandemic = false } }), true)
    -- red under: Bars.Bind adding the highlight whatever the setting
    assertEqual(frame:__count("AddPandemicRegion"), 0)
    assertEqual(frame:__count("ClearPandemicRegions"), 1, "a restyle that turned it off removes it")
end)

-- ── preview fill ──────────────────────────────────────────────────────────────────────────────

--- The width a preview fill was given.
local function fillWidth(am) return am.fill:__last("SetWidth")[1] end

test("bars: a preview fill is the remaining fraction of the bar area, net of the icon and its gap", function()
    local c = cfg({ bars = { width = 200, height = 20, icon = "LEFT", iconSize = 0, iconGap = 4 } })
    local frame, am = dressed(c, false)
    NS.Style.Bars.FillPreview(frame, { name = "X", icon = 1, remaining = 30, duration = 40, stacks = 0 }, c)
    -- red under: barAreaWidth measuring the whole element
    assertEqual(fillWidth(am), (200 - 20 - 4) * 30 / 40)
    c.bars.icon = "NONE"
    frame, am = dressed(c, false)
    NS.Style.Bars.FillPreview(frame, { name = "X", icon = 1, remaining = 30, duration = 40, stacks = 0 }, c)
    assertEqual(fillWidth(am), 200 * 30 / 40, "no icon: the whole element")
end)

test("bars: a preview with a missing icon gap measures the template's gap, as the layout does", function()
    local c = cfg({ bars = { width = 200, height = 20, icon = "LEFT" } })
    c.bars.iconGap = nil
    local frame, am = dressed(c, false)
    NS.Style.Bars.FillPreview(frame, { name = "X", icon = 1, remaining = 30, duration = 40, stacks = 0 }, c)
    -- red under: barAreaWidth falling back to a literal 0 gap where layout reads the template's
    assertEqual(fillWidth(am), (200 - 20 - D.bars.iconGap) * 30 / 40)
end)

test("bars: a missing icon size is the template's, in the layout and in the preview alike", function()
    local ns = withTemplate("iconSize", 24)
    local c = cfg({ bars = { width = 200, height = 20, icon = "LEFT", iconGap = 2 } })
    c.bars.iconSize = nil
    local frame, am = dressed(c, false, nil, ns)
    -- red under: layout reading a missing iconSize as 0 (the bar's height) instead of the template's
    assertEqual(am.icon:__joined("SetSize"), "24,24")
    ns.Style.Bars.FillPreview(frame, { name = "X", icon = 1, remaining = 30, duration = 40, stacks = 0 }, c)
    -- red under: barAreaWidth reading a missing iconSize as 0
    assertEqual(fillWidth(am), (200 - 24 - 2) * 30 / 40)
end)

test("bars: a timeless preview aura draws a full bar with no time text, and an expired one keeps one pixel", function()
    local c = cfg({ bars = { width = 100, icon = "NONE" } })
    local frame, am = dressed(c, false)
    NS.Style.Bars.FillPreview(frame, { name = "Well Fed", icon = 1, remaining = 0, duration = 0, stacks = 0 }, c)
    -- red under: the fraction computed as remaining / duration for a timeless aura (0/0)
    assertEqual(fillWidth(am), 100, "a permanent buff is a full bar")
    assertEqual(am.time:__last("SetText")[1], "", "no time for a timeless aura")
    NS.Style.Bars.FillPreview(frame, { name = "X", icon = 1, remaining = 0, duration = 10, stacks = 0 }, c)
    -- red under: dropping the math.max(1, ...) floor (a zero width collapses the anchors)
    assertEqual(fillWidth(am), 1)
end)

test("bars: preview text shows the name, whole seconds left, and stacks only above one", function()
    local c = cfg()
    local frame, am = dressed(c, false)
    NS.Style.Bars.FillPreview(frame, { name = "Ignore Pain", icon = 77, remaining = 11, duration = 12, stacks = 3 }, c)
    assertEqual(am.name:__last("SetText")[1], "Ignore Pain")
    assertEqual(am.time:__last("SetText")[1], "11s")
    assertEqual(am.stacks:__last("SetText")[1], "3")
    assertEqual(am.icon:__last("SetTexture")[1], 77)
    NS.Style.Bars.FillPreview(frame, { name = "X", icon = 1, remaining = 5, duration = 8, stacks = 1 }, c)
    -- red under: previewText printing a stack count of 1
    assertEqual(am.stacks:__last("SetText")[1], "")
end)

test("bars: a preview fill drains from the configured side, spark at its leading edge", function()
    local c = cfg({ bars = { drain = "right" } })
    local frame, am = dressed(c, false)
    NS.Style.Bars.FillPreview(frame, NS.Constants.PREVIEW_AURAS[2], c)
    local pts = am.fill:__calls("SetPoint")
    local n = #pts
    -- red under: FillPreview anchoring the fill left whatever the drain
    assertEqual(pts[n - 1][1], "TOPRIGHT"); assertEqual(pts[n][1], "BOTTOMRIGHT")
    assertEqual(am.spark:__last("SetPoint")[3], "LEFT")
end)

test("bars: a dispel-colored preview paints the Magic color, since no real aura names a type", function()
    local c = cfg({ bars = { colorMode = "dispel" } })
    local frame, am = dressed(c, false)
    NS.Style.Bars.FillPreview(frame, NS.Constants.PREVIEW_AURAS[1], c)
    local m = NS.db.profile.dispelColors.Magic
    -- red under: FillPreview ignoring colorMode (the preview then looks unlike the engine's tint)
    assertEqual(am.fill:__joined("SetVertexColor"), table.concat({ m.r, m.g, m.b, 1 }, ","))
end)

test("bars: filling a preview element that was never dressed does nothing and raises nothing", function()
    local ok, err = pcall(NS.Style.Bars.FillPreview, R(), NS.Constants.PREVIEW_AURAS[1], cfg())
    -- red under: FillPreview without its missing-regions guard
    assertTrue(ok, tostring(err))
    assertNil(err)
end)
