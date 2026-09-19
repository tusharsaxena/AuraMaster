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

-- ── spark on timeless auras (B-3) ─────────────────────────────────────────────────────────────

--- A fresh environment whose template holds `value` at bars.<key>, for a fallback case: the shared
--- environment's template is read by every suite, so a case moves one of its own.
local function ownTemplate(key, value)
    local ns = dofile("tests/fresh_env.lua")()
    ns.CONTAINER_TEMPLATE.bars[key] = value
    return ns
end

test("bars: with the timeless spark off, the live spark rides a clip frame bounded by the elapsed region", function()
    local _, am = dressed(cfg({ bars = { height = 16, drain = "left", sparkTimeless = false } }), true)
    local edge = am.bar:GetStatusBarTexture()
    -- red under: the clip frame never clipping (a timeless bar's spark shows at the bar's end)
    assertEqual(am.sparkClip:__joined("SetClipsChildren"), "true")
    local pts = am.sparkClip:__calls("SetPoint")
    -- red under: the clip frame bounded by the bar (no geometry ever hides the spark)
    assertEqual(pts[1][1], "TOPLEFT"); assertTrue(pts[1][2] == edge); assertEqual(pts[1][3], "TOPLEFT")
    assertEqual(pts[1][5], 8, "half a bar above, so the double-height spark is not cut")
    assertEqual(pts[2][1], "BOTTOMRIGHT"); assertTrue(pts[2][2] == edge); assertEqual(pts[2][3], "BOTTOMRIGHT")
    assertEqual(pts[2][5], -8)
    local s = am.spark:__last("SetPoint")
    -- red under: the spark left centered on the edge (half of it shows on a timeless bar)
    assertEqual(s[1], "LEFT"); assertTrue(s[2] == edge); assertEqual(s[3], "LEFT")
end)

test("bars: draining right, the clipped spark sits wholly on the elapsed side of the right-hand edge", function()
    local _, am = dressed(cfg({ bars = { drain = "right", sparkTimeless = false } }), true)
    local edge = am.bar:GetStatusBarTexture()
    local s = am.spark:__last("SetPoint")
    -- red under: the clipped spark ignoring the drain (it would sit on the fill's side, clipped away)
    assertEqual(s[1], "RIGHT"); assertTrue(s[2] == edge); assertEqual(s[3], "RIGHT")
end)

test("bars: with the timeless spark on, and in every preview, nothing is clipped and the spark stays centered", function()
    local _, am = dressed(cfg({ bars = { sparkTimeless = true } }), true)
    -- red under: clipping whatever the option (the default look would change)
    assertEqual(am.sparkClip:__joined("SetClipsChildren"), "false")
    local s = am.spark:__last("SetPoint")
    assertEqual(s[1], "CENTER"); assertTrue(s[2] == am.fill)
    _, am = dressed(cfg({ bars = { sparkTimeless = false } }), false)
    -- red under: the preview clipping to an elapsed region no timer drives (every preview spark vanishes)
    assertEqual(am.sparkClip:__joined("SetClipsChildren"), "false")
end)

-- ── spark blend mode matches its backdrop (SP-1) ─────────────────────────────────────────────────

test("bars: with the timeless spark off, the live clipped spark blends normally, not additively", function()
    local _, am = dressed(cfg({ bars = { sparkTimeless = false } }), true)
    -- red under: the clip-mode spark still summing onto its (partly transparent) backdrop, which
    -- reads as a random wash rather than the spark's own authored color (feedback batch 7 SP-1)
    assertEqual(am.spark:__joined("SetBlendMode"), "BLEND")
end)

test("bars: with the timeless spark on, the live spark stays additive over the opaque fill", function()
    local _, am = dressed(cfg({ bars = { sparkTimeless = true } }), true)
    assertEqual(am.spark:__joined("SetBlendMode"), "ADD")
end)

test("bars: a non-engine dress (preview) always keeps the additive, centered spark, whatever sparkTimeless says", function()
    local _, am = dressed(cfg({ bars = { sparkTimeless = false } }), false)
    -- red under: wireSpark keying the blend mode off sparkTimeless alone instead of `engine and not sparkTimeless`
    assertEqual(am.spark:__joined("SetBlendMode"), "ADD")
end)

test("bars: the clip-mode blend switch leaves the player's own spark color alone", function()
    local _, am = dressed(cfg({ bars = { sparkTimeless = false,
        sparkColor = { r = 0.1, g = 0.2, b = 0.9, a = 0.4 } } }), true)
    -- red under: neutralizing the backdrop by overriding sparkColor instead of the blend mode, which
    -- would silently discard a custom color the player chose
    assertEqual(am.spark:__joined("SetVertexColor"), "0.1,0.2,0.9,0.4")
    assertEqual(am.spark:__joined("SetBlendMode"), "BLEND")
end)

test("bars: a missing timeless-spark setting reads the template's", function()
    local ns = ownTemplate("sparkTimeless", false)
    local c = cfg()
    c.bars.sparkTimeless = nil
    local _, am = dressed(c, true, nil, ns)
    -- red under: wireSpark reading a missing sparkTimeless as off, or as on, instead of the template's
    assertEqual(am.sparkClip:__joined("SetClipsChildren"), "true")
end)

test("bars: a timeless preview aura hides its spark when the option is off; a timed one keeps it", function()
    local timeless = { name = "Well Fed", icon = 1, remaining = 0, duration = 0, stacks = 0 }
    local timed = { name = "X", icon = 1, remaining = 5, duration = 10, stacks = 0 }
    local c = cfg({ bars = { sparkTimeless = false } })
    local frame, am = dressed(c, false)
    NS.Style.Bars.FillPreview(frame, timeless, c)
    -- red under: FillPreview ignoring sparkTimeless
    assertFalse(am.spark:IsShown())
    NS.Style.Bars.FillPreview(frame, timed, c)
    assertTrue(am.spark:IsShown(), "a timed aura's spark")
    c.bars.sparkTimeless = true
    NS.Style.Bars.FillPreview(frame, timeless, c)
    assertTrue(am.spark:IsShown(), "on: today's look")
    c.bars.spark = false
    NS.Style.Bars.FillPreview(frame, timed, c)
    -- red under: FillPreview showing a spark turned off
    assertFalse(am.spark:IsShown())
end)

test("bars: the texts sit above the spark's clip frame, which sits above the bar", function()
    local frame = R()
    NS.Style.Element(frame, cfg(), false)
    local am = frame.__am
    -- red under: build leaving the frame levels to chance (the spark drawn over the name)
    assertTrue(am.sparkClip:GetFrameLevel() > am.bar:GetFrameLevel(), "clip above the bar")
    assertTrue(am.text:GetFrameLevel() > am.sparkClip:GetFrameLevel(), "texts above the spark")
end)

-- ── icon border (B-1) ─────────────────────────────────────────────────────────────────────────

test("bars: a shown icon border frames the icon's box and the art insets by its size", function()
    local frame, am = dressed(cfg({ bars = { height = 20, icon = "LEFT", iconSize = 0,
        iconBorderShow = true, iconBorderStyle = "Solid", iconBorderSize = 3,
        iconBorderColor = { r = 1, g = 0, b = 0, a = 1 } } }))
    -- red under: nothing painting am.iconBorder (the icon-border rows reach no region)
    assertTrue(am.iconBorder:IsShown())
    local bd = am.iconBorder:__last("SetBackdrop")[1]
    assertEqual(bd.edgeSize, 3)
    assertEqual(bd.edgeFile, NS.Style.Fetch("border", "Solid", NS.Constants.FALLBACK_BORDER))
    assertEqual(am.iconBorder:__joined("SetBackdropBorderColor"), "1,0,0,1")
    assertEqual(am.iconBorder:__joined("SetSize"), "20,20", "the border takes the icon's whole box")
    local b = am.iconBorder:__last("SetPoint")
    assertEqual(b[1], "LEFT"); assertTrue(b[2] == frame)
    -- red under: the art laid at the box's full size under a thick border
    assertEqual(am.icon:__joined("SetSize"), "14,14")
    local p = am.icon:__last("SetPoint")
    assertEqual(p[1], "LEFT"); assertTrue(p[2] == frame); assertEqual(p[4], 3)
    assertEqual(am.bar:__calls("SetPoint")[1][4], 20 + D.bars.iconGap, "the bar still starts after the whole box")
end)

test("bars: a right-hand icon insets from the right edge", function()
    local frame, am = dressed(cfg({ bars = { icon = "RIGHT", iconSize = 24,
        iconBorderShow = true, iconBorderStyle = "Solid", iconBorderSize = 2 } }))
    local p = am.icon:__last("SetPoint")
    -- red under: the inset applied toward the bar rather than inward from the element's edge
    assertEqual(p[1], "RIGHT"); assertTrue(p[2] == frame); assertEqual(p[4], -2)
    assertEqual(am.icon:__joined("SetSize"), "20,20")
    assertEqual(am.iconBorder:__last("SetPoint")[1], "RIGHT")
end)

test("bars: an icon border turned off, styled None or with no icon draws nothing and insets nothing", function()
    local _, am = dressed(cfg({ bars = { height = 20, iconSize = 0, iconBorderShow = false, iconBorderSize = 3 } }))
    -- red under: the inset read from iconBorderSize alone
    assertFalse(am.iconBorder:IsShown())
    assertEqual(am.icon:__joined("SetSize"), "20,20")
    _, am = dressed(cfg({ bars = { height = 20, iconSize = 0, iconBorderShow = true, iconBorderStyle = "None",
        iconBorderSize = 3 } }))
    assertFalse(am.iconBorder:IsShown(), "None")
    assertEqual(am.icon:__joined("SetSize"), "20,20")
    -- A restyle of one element from a bordered icon to none: a fresh recorder was never shown, so
    -- only a border that WAS shown can prove the NONE branch hides it.
    local frame
    frame, am = dressed(cfg({ bars = { icon = "LEFT", iconBorderShow = true, iconBorderStyle = "Solid" } }))
    assertTrue(am.iconBorder:IsShown(), "shown while there is an icon")
    NS.Style.Element(frame, cfg({ bars = { icon = "NONE", iconBorderShow = true, iconBorderStyle = "Solid" } }))
    assertTrue(frame.__am.iconBorder == am.iconBorder, "the same element, restyled")
    -- red under: the NONE branch leaving a border around an icon that is not there
    assertFalse(am.iconBorder:IsShown(), "no icon")
end)

test("bars: the icon border takes the class color through its own companion, and a missing size the template's", function()
    local _, am = dressed(cfg({ bars = { iconBorderShow = true, iconBorderStyle = "Solid",
        iconBorderColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.5 }, useClassColorIconBorder = true,
        useClassColorBorder = false } }), false, { r = 0.9, g = 0.8, b = 0.7 })
    -- red under: the icon border reading the bar border's companion
    assertEqual(am.iconBorder:__joined("SetBackdropBorderColor"), "0.9,0.8,0.7,0.5")
    local ns = ownTemplate("iconBorderSize", 5)
    local c = cfg({ bars = { iconBorderShow = true, iconBorderStyle = "Solid" } })
    c.bars.iconBorderSize = nil
    _, am = dressed(c, false, nil, ns)
    -- red under: a missing iconBorderSize read as nothing (no border) or a literal
    assertEqual(am.iconBorder:__last("SetBackdrop")[1].edgeSize, 5)
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

test("bars: beside the name the time is boxed to its format's widest string, so its justify shows and the name keeps its room", function()
    -- The template's 11pt time in the Blizzard format (one unit, "59m"): 2.5 ems, 28px.
    local _, am = dressed(cfg())
    -- red under: a time sized to its own string beside the name (its Justify has nothing to align within)
    assertEqual(am.time:__last("SetWidth")[1], 28)
    assertTrue(am.time:__last("SetPoint")[2] == am.bar, "the box hangs off its own point on the bar")
    -- red under: a time text boxed across the bar area (the name's stop lands at the bar's start)
    assertTrue(am.time:__last("SetWidth")[1] < 201 - 4, "not the whole bar area")
    assertEqual(am.name:__last("SetWidth")[1], 201 - 4, "the name's own box, which its second anchor overrides")
    -- red under: one width budget for every format (two units need more room than one)
    _, am = dressed(cfg({ bars = { timeFormat = "long" } }))
    assertEqual(am.time:__last("SetWidth")[1], 50, "the detailed format's two units, 4.5 ems")
    -- red under: a budget that ignores the font size
    _, am = dressed(cfg({ bars = { time = { fontSize = 20 } } }))
    assertEqual(am.time:__last("SetWidth")[1], 50, "2.5 ems of a 20pt font")
    -- red under: a budget wider than the bar area on a narrow bar
    _, am = dressed(cfg({ bars = { width = 40, time = { fontSize = 40 } } }))
    assertEqual(am.time:__last("SetWidth")[1], 40 - 18 - 1 - 4, "held to the bar area less the offset")
end)

-- ── the measured time box (B4) ──────────────────────────────────────────────────────────────────

--- A fresh environment whose time texts are measured on a recorder answering half the font size per
--- character of the last string set, so a longer string or a bigger font measures wider.
local function measuring()
    local ns = dofile("tests/fresh_env.lua")()
    local fs = R()
    fs.__answer.GetStringWidth = function(self)
        local font, text = self:__last("SetFont"), self:__last("SetText")
        return #text[1] * font[2] * 0.5
    end
    ns.Style.__measurer = function() return fs end
    return ns, fs
end

test("bars: beside the name the time is boxed to the measured width of its format's widest string (B4)", function()
    local ns, fs = measuring()
    -- No formatter headlessly: the samples are written as whole seconds, the widest "863999s".
    local _, am = dressed(cfg(), false, nil, ns)
    -- red under: timeBoxWidth keeping the ems budget (2.5 ems of 11pt, 28px: "59 m" cut to "59...")
    assertEqual(am.time:__last("SetWidth")[1], math.ceil(7 * 11 * 0.5 + 2))
    _, am = dressed(cfg({ bars = { time = { fontSize = 20 } } }), false, nil, ns)
    assertEqual(am.time:__last("SetWidth")[1], 7 * 20 * 0.5 + 2, "a bigger font, a wider box")
    -- red under: the offset taken out of the box (moving the text would clip it)
    _, am = dressed(cfg({ bars = { time = { x = -15 } } }), false, nil, ns)
    assertEqual(am.time:__last("SetWidth")[1], math.ceil(7 * 11 * 0.5 + 2), "the offset moves the box, never narrows it")
    local measured = fs:__count("SetText")
    dressed(cfg(), false, nil, ns)
    -- red under: TimeTextWidth measuring on every dress
    assertEqual(fs:__count("SetText"), measured, "cached per font and format")
    dressed(cfg({ bars = { time = { fontFlags = "NONE" } } }), false, nil, ns)
    assertTrue(fs:__count("SetText") > measured, "a new font measures again")
end)

test("bars: a measurer answering no width, refusing the font or raising gives the ems budget and caches nothing", function()
    local ns, fs = measuring()
    local t, tdef = { fontSize = 11 }, ns.CONTAINER_TEMPLATE.bars.time
    local width = fs.__answer.GetStringWidth
    fs.__answer.GetStringWidth = function() return 0 end
    -- red under: a zero width cached as the time box (a string not yet laid out measures 0)
    assertNil(ns.Style.TimeTextWidth(t, tdef, "blizzard"))
    fs.__answer.GetStringWidth = width
    -- red under: the failed measure cached, so a later dress never measures again
    assertEqual(ns.Style.TimeTextWidth(t, tdef, "blizzard"), 7 * 11 * 0.5 + 2)
    fs.__raise.GetStringWidth = true
    -- red under: widestSample unguarded (the raise aborts the dress)
    assertNil(ns.Style.TimeTextWidth({ fontSize = 12 }, tdef, "blizzard"))
    fs.__raise.GetStringWidth = nil
    assertEqual(ns.Style.TimeTextWidth({ fontSize = 12 }, tdef, "blizzard"), 7 * 12 * 0.5 + 2, "measured once it answers")
    local refused = false
    fs.__answer.SetFont = function()
        if refused then return true end
        refused = true
        return false
    end
    local fonts = fs:__count("SetFont")
    -- red under: the SetFont refusal ignored (the samples measured in whatever font was last set)
    assertEqual(ns.Style.TimeTextWidth({ fontSize = 13 }, tdef, "blizzard"), 7 * 13 * 0.5 + 2)
    assertEqual(fs:__count("SetFont") - fonts, 2, "a refused font falls back")
    assertEqual(fs:__last("SetFont")[1], ns.Constants.FALLBACK_FONT, "measured in the fallback font")
    fs.__answer.SetFont = function() return false end
    assertNil(ns.Style.TimeTextWidth({ fontSize = 14 }, tdef, "blizzard"), "no font at all: nothing measured")
end)

test("bars: where nothing can be measured the time keeps its ems budget", function()
    -- The shared environment's measuring string is the kit's, whose GetStringWidth answers no number.
    local _, am = dressed(cfg())
    assertEqual(am.time:__last("SetWidth")[1], 28, "2.5 ems of 11pt")
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
    -- red under: the bar still reading a per-container bars.dispelColors (schema v2 lifted it), or the
    -- map built without the bar's own color for an aura with no type (feedback #7)
    assertTrue(add[2].customDispelColorMap
        == NS2.Style.DispelColorMap(NS2.db.profile.dispelColors, NS2.Style.CurveColor(c.bars.barColor, false)), "the profile's colors")
    c.bars.colorMode = "static"
    frame = dressed(c, true, nil, NS2)
    assertEqual(frame:__count("AddDispelTypeTexture"), 0, "one color: no tint")
    assertEqual(frame:__count("ClearDispelTypeTextures"), 1, "and an earlier tint is cleared")
end)

-- ── the background by dispel type (feedback #7) ───────────────────────────────────────────────

test("bars: Color by dispel type on the background tints it through the engine, no type keeping the background color (feedback #7)", function()
    local NS2 = withEnums()
    local c = NS2.Database.Merge(NS2.Database.DeepCopy(NS2.CONTAINER_TEMPLATE), { bars = { bgColorMode = "dispel" } })
    local frame, am = dressed(c, true, nil, NS2)
    local add = frame:__last("AddDispelTypeTexture")
    -- red under: no background binding at all
    assertTrue(add ~= nil and add[1] == am.bg, "the background carries the tint")
    assertEqual(frame:__count("AddDispelTypeTexture"), 1, "the fill, on one color, carries none")
    assertEqual(add[2].style, 32, "PreserveAsset keeps our texture")
    assertTrue(add[2].showAlways and add[2].showWithoutDispelType, "shown for every aura")
    local map = add[2].customDispelColorMap
    local bgc = c.bars.bgColor
    -- red under: the background's map built with the bar color's fallback
    assertEqual(table.concat({ map.None.r, map.None.g, map.None.b, map.None.a }, ","),
        table.concat({ bgc.r, bgc.g, bgc.b, bgc.a }, ","))
    c.bars.bgColorMode = "static"
    frame = dressed(c, true, nil, NS2)
    assertEqual(frame:__count("AddDispelTypeTexture"), 0, "one color: no tint")
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

--- The background's twin of `toggled`: dress ONE live bar button for each bgColorMode in `modes`.
local function toggledBg(modes, aura)
    local NS2 = withEnums()
    local c = NS2.Database.Merge(NS2.Database.DeepCopy(NS2.CONTAINER_TEMPLATE),
        { bars = { bgColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.5 }, useClassColorBg = false } })
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
        c.bars.bgColorMode = mode
        NS2.Style.Element(frame, c, true)
    end
    return frame, frame.__am, table.concat({ NS2.Style.Color(c.bars.bgColor, false) }, ",")
end

test("bars: switching Color by from dispel type back to static on the background paints the background's own color again (feedback #7)", function()
    local frame, am, bgColor = toggledBg({ "static", "dispel", "static" }, true)
    -- red under: the static color never repainted last, so the dispel tint or Blizzard's own art wins
    assertEqual(am.bg:__joined("SetVertexColor"), bgColor, "the static color is the last word")
    assertTrue(frame:__lastSeq("ClearDispelTypeTextures") < am.bg:__lastSeq("SetVertexColor"),
        "the tint is cleared before the background is painted")
    assertTrue(am.bg:IsShown(), "the background shows")
end)

test("bars: back to static on a button holding no aura, the background the engine hid shows again (feedback #7)", function()
    local _, am = toggledBg({ "static", "dispel", "static" }, false)
    -- red under: applySurfaces never showing the background the engine's no-aura pass hid
    assertTrue(am.bg:IsShown())
end)

test("bars: the refresh-window highlight is bound only when turned on, and always cleared first", function()
    local frame, am = dressed(cfg({ bars = { pandemic = true } }), true)
    assertTrue(frame:__last("AddPandemicRegion")[1] == am.pandemic)
    frame = dressed(cfg({ bars = { pandemic = false } }), true)
    -- red under: Bars.Bind adding the highlight whatever the setting
    assertEqual(frame:__count("AddPandemicRegion"), 0)
    assertEqual(frame:__count("ClearPandemicRegions"), 1, "a restyle that turned it off removes it")
end)

test("bars: with the time's class color on, the running-out curve returns to the class color, one curve per container", function()
    local ns = dofile("tests/fresh_env.lua")({ before = dofile("tests/text_apis.lua") })
    local class = { r = 0.2, g = 0.4, b = 0.6 }
    local c = ns.Database.Merge(ns.Database.DeepCopy(ns.CONTAINER_TEMPLATE), { bars = { expiringColorOn = true,
        time = { fontColor = { r = 1, g = 1, b = 1, a = 0.7 }, useClassColorFont = true } } })
    local a = dressed(c, true, class, ns)
    local b = dressed(c, true, class, ns)
    local curve = a:__last("SetDurationText")[2].textColor
    local normal = curve.curve:__last("AddPoint")[2]
    -- red under: BindDurationText reading the raw time color (white above the threshold)
    assertEqual(("%s,%s,%s,%s"):format(normal.r, normal.g, normal.b, normal.a), "0.2,0.4,0.6,0.7")
    -- red under: a fresh color table per dress (one curve built per button)
    assertTrue(b:__last("SetDurationText")[2].textColor == curve, "two buttons of one container share one curve")
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
