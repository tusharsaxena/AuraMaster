-- tests/test_style_borders.lua — modules/Style_Border.lua and the dress around it: Solid strips, a
-- backdrop on its own frame, and live re-dresses under a secret size. Peeled out of
-- tests/test_style.lua by theme.

local T = _G.AM_TEST
local own = dofile("tests/own_look.lua")
local spyConsole = dofile("tests/console_spy.lua")
local R = dofile("tests/region_recorder.lua")
local fresh = dofile("tests/fresh_env.lua")
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil
local assertFalse = T.assertFalse
local NS = T.NS
local C, D = NS.Constants, NS.CONTAINER_TEMPLATE

local function cfg(over)
    return own(NS.Database.Merge(NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE), over or {}))
end

--- Dress a bar element, swap its regions for recorders, and dress it again (see test_style_bars).
local function dressedBars(c, engine, classColor)
    local frame = R()
    NS.Style.Element(frame, c, engine, classColor)
    for k in pairs(frame.__am) do frame.__am[k] = R() end
    frame.__log = {}
    NS.Style.Element(frame, c, engine, classColor)
    return frame, frame.__am
end

-- ── borders never read a secret size (B2-3) ───────────────────────────────────────────────────
-- An aura button's border fills the button, and once the engine has laid the button out its size
-- reads secret; Blizzard's Backdrop does arithmetic on that size (Backdrop.lua:226), so a restyle
-- raised. Solid is drawn with four strips of our own and reads no size; any other style keeps a
-- backdrop, applied only while its size reads plain (tests/wow_mock.lua's __layOut, __SECRET).

local BS = dofile("tests/border_strips.lua")
local strips, assertSolid = BS.strips, BS.assertSolid

test("style: a Solid border is four strips between the frame's corners, never a backdrop (B2-3)", function()
    local f = R()
    NS.Style.ApplyBorder(f, true, "Solid", 3, { r = 0.1, g = 0.2, b = 0.3, a = 0.4 }, false)
    assertTrue(f:IsShown())
    -- red under: ApplyBorder drawing Solid with SetBackdrop (arithmetic on a size that may be secret)
    assertSolid(f, 3, "0.1,0.2,0.3,0.4", "solid")
    assertEqual(f:__count("SetBackdrop"), 0, "no backdrop on the border")
    assertNil(f.__amBackdrop, "and no backdrop frame")
    local s = strips(f)
    local top = s[1]:__calls("SetPoint")
    assertEqual(top[1][1], "TOPLEFT"); assertTrue(top[1][2] == f); assertEqual(top[2][1], "TOPRIGHT")
    local left = s[3]:__calls("SetPoint")
    -- red under: the sides running the full height (the corners drawn twice, darker at any alpha)
    assertEqual(left[1][1], "TOPLEFT"); assertEqual(left[1][5], -3, "the left side starts below the top")
    assertEqual(left[2][1], "BOTTOMLEFT"); assertEqual(left[2][5], 3, "and stops above the bottom")
end)

test("style: a tint edge lays the Solid border's four strips, white, untinted and hidden, for the engine to show (DB-1)", function()
    local solid, tint = R(), R()
    NS.Style.DrawEdge(solid, 3, 1, 0, 0, 1)
    local s = { R(), R(), R(), R() }
    -- red under: no Style.TintEdge (the icon's dispel border drawn in a shape of its own)
    NS.Style.TintEdge(tint, 3, s[1], s[2], s[3], s[4])
    local want = strips(solid)
    local setters = { "SetHeight", "SetHeight", "SetWidth", "SetWidth" }
    for i = 1, 4 do
        local got, exp = s[i]:__calls("SetPoint"), want[i]:__calls("SetPoint")
        assertEqual(#got, 2, "strip " .. i .. ": two anchors")
        for j = 1, 2 do
            assertEqual(got[j][1], exp[j][1], "strip " .. i .. " point " .. j)
            assertTrue(got[j][2] == tint, "strip " .. i .. " hangs from the tint frame")
            assertEqual(got[j][3], exp[j][3], "strip " .. i .. " relative point " .. j)
            assertEqual(got[j][4], exp[j][4], "strip " .. i .. " x " .. j)
            assertEqual(got[j][5], exp[j][5], "strip " .. i .. " y " .. j)
        end
        assertEqual(s[i]:__last(setters[i])[1], 3, "strip " .. i .. " thickness")
        assertEqual(s[i]:__joined("SetTexture"), NS.Constants.WHITE_TEXTURE, "strip " .. i .. " white")
        assertEqual(s[i]:__joined("SetVertexColor"), "1,1,1,1", "strip " .. i .. " untinted")
        assertTrue(s[i]:IsShown() == false, "strip " .. i .. " hidden until the engine shows it")
        assertEqual(s[i]:__count("SetColorTexture"), 0, "strip " .. i .. " keeps a texture the engine can tint")
    end
    -- DrawEdge's own shape, unchanged by the shared layout
    local left = want[3]:__calls("SetPoint")
    assertEqual(left[1][5], -3); assertEqual(left[2][5], 3)
    assertEqual(want[1]:__joined("SetColorTexture"), "1,0,0,1")
end)

test("style: a Solid border takes the class color through its companion (B2-3)", function()
    local f = R()
    NS.Style.ApplyBorder(f, true, "Solid", 1, { r = 0.1, g = 0.1, b = 0.1, a = 0.5 }, true)
    local r, g, b, a = NS.ResolveColor({ r = 0.1, g = 0.1, b = 0.1, a = 0.5 }, true, "player")
    assertTrue(r ~= 0.1, "the harness's player has a class color")
    -- red under: the strips painted from the swatch whatever the companion says
    assertEqual(strips(f)[1]:__joined("SetColorTexture"), table.concat({ r, g, b, a }, ","))
end)

test("style: a Solid border under a secret size draws and never raises (B2-3)", function()
    local NS2, m2 = fresh()
    local f = R()
    m2.__layOut(f)
    local ok, err = pcall(NS2.Style.ApplyBorder, f, true, "Solid", 2, { r = 1, g = 0, b = 0, a = 1 }, false)
    -- red under: SetBackdrop on the border (the reported Backdrop.lua:226 raise)
    assertTrue(ok, tostring(err))
    assertSolid(f, 2, "1,0,0,1", "secret")
end)

test("style: another style draws a backdrop on a frame of its own, with its edge, size and color (B2-3)", function()
    local f = R()
    NS.Style.ApplyBorder(f, true, "Uninstalled", 2, { r = 0.1, g = 0.2, b = 0.3, a = 0.4 }, false)
    assertTrue(f:IsShown())
    local host = f.__amBackdrop
    -- red under: the backdrop set on the border frame itself (its template's OnSizeChanged reads the size)
    assertTrue(host ~= nil, "a backdrop frame")
    assertTrue(host:IsShown())
    -- red under: ApplyBorder without the fallback edge (a missing media key draws no border)
    assertEqual(host.backdropInfo.edgeFile, C.FALLBACK_BORDER)
    assertEqual(host.backdropInfo.edgeSize, 2)
    assertEqual(table.concat(host.__borderColor, ","), "0.1,0.2,0.3,0.4")
    for i, strip in ipairs(strips(f)) do assertFalse(strip:IsShown(), "strip " .. i .. " hidden") end
    -- red under: the backdrop frame given the template's size script (arithmetic on every resize)
    assertNil(host:GetScript("OnSizeChanged"), "no size script on the backdrop frame")
end)

test("style: another style applies its backdrop once per edge and size, and again when either moves (B2-3)", function()
    local f = R()
    NS.Style.ApplyBorder(f, true, "Uninstalled", 2, { r = 1, g = 1, b = 1, a = 1 }, false)
    NS.Style.ApplyBorder(f, true, "Uninstalled", 2, { r = 1, g = 0, b = 0, a = 1 }, false)
    local host = f.__amBackdrop
    -- red under: SetBackdrop on every dress (the arithmetic re-run for a recolor)
    assertEqual(host.__backdropApplies, 1, "unchanged: applied once")
    assertEqual(table.concat(host.__borderColor, ","), "1,0,0,1", "and recolored")
    NS.Style.ApplyBorder(f, true, "Uninstalled", 4, { r = 1, g = 0, b = 0, a = 1 }, false)
    assertEqual(host.__backdropApplies, 2, "a new size applies again")
    assertEqual(host.backdropInfo.edgeSize, 4)
end)

test("style: another style under a secret size keeps its last backdrop and only recolors (B2-3)", function()
    local NS2, m2 = fresh()
    local f = R()
    NS2.Style.ApplyBorder(f, true, "Uninstalled", 2, { r = 1, g = 1, b = 1, a = 1 }, false)
    local host = f.__amBackdrop
    m2.__layOut(f)
    m2.__layOut(host)
    local ok, err = pcall(NS2.Style.ApplyBorder, f, true, "Uninstalled", 5, { r = 0, g = 1, b = 0, a = 1 }, false)
    -- red under: SetBackdrop re-run on a size that reads secret (the reported raise)
    assertTrue(ok, tostring(err))
    assertEqual(host.__backdropApplies, 1, "not re-applied")
    assertEqual(host.backdropInfo.edgeSize, 2, "the last applied backdrop stands")
    assertEqual(table.concat(host.__borderColor, ","), "0,1,0,1", "recolored")
    assertTrue(host:IsShown())
end)

test("style: a backdrop frame first made under a secret size applies nothing until its size reads plain (B2-3)", function()
    local NS2, m2 = fresh()
    local f = R()
    m2.__layOut(f)
    local ok, err = pcall(NS2.Style.ApplyBorder, f, true, "Uninstalled", 2, { r = 1, g = 1, b = 1, a = 1 }, false)
    assertTrue(ok, tostring(err))
    -- a frame made under a laid-out one reads secret too (tests/wow_mock.lua's CreateFrame)
    assertNil(f.__amBackdrop.__backdropApplies, "no backdrop applied on a secret size")
end)

test("style: switching between Solid and another style hides the other drawing (B2-3)", function()
    local f = R()
    local color = { r = 1, g = 1, b = 1, a = 1 }
    NS.Style.ApplyBorder(f, true, "Solid", 1, color, false)
    NS.Style.ApplyBorder(f, true, "Uninstalled", 1, color, false)
    -- red under: the strips left drawn under the backdrop
    for i, strip in ipairs(strips(f)) do assertFalse(strip:IsShown(), "to another: strip " .. i .. " hidden") end
    assertTrue(f.__amBackdrop:IsShown(), "the backdrop shows")
    NS.Style.ApplyBorder(f, true, "Solid", 1, color, false)
    -- red under: the backdrop frame left shown over the strips
    assertFalse(f.__amBackdrop:IsShown(), "back to Solid: the backdrop hidden")
    assertSolid(f, 1, "1,1,1,1", "back to Solid")
end)

test("style: another style on a client without the backdrop mixin draws nothing and never raises", function()
    local NS2 = fresh({ before = function(m) m.BackdropTemplateMixin = nil end })
    local f = R()
    local ok, err = pcall(NS2.Style.ApplyBorder, f, true, "Uninstalled", 1, {}, false)
    assertTrue(ok, tostring(err))
    assertTrue(f:IsShown())
end)

test("style: a binding the client lacks is skipped, and one it refuses costs that binding alone", function()
    -- Its own environment: the debug trace is replaced there, never on the shared one.
    local NS2 = fresh()
    NS2.State.debug = true
    local lines = {}
    spyConsole(NS2, function(tag, fmt, ...)
        if tag == "Style" then
            lines[#lines + 1] = fmt:format(...)
        end
    end)
    local frame = R()
    frame.__absent.SetSpellName = true
    frame.__raise.SetIcon = true
    local ok, err = pcall(NS2.Style.Element, frame, cfg({ style = "bars" }), true)
    -- red under: Style.Bind calling the method unguarded (the engine's frame batch dies with the button)
    assertTrue(ok, tostring(err))
    for _, m in ipairs({ "SetDurationBar", "SetDurationText", "SetApplicationCount", "SetTooltipAnchorPoint" }) do
        assertEqual(frame:__count(m), 1, m .. " still bound after SetIcon was refused")
    end
    assertEqual(#lines, 1, "the refusal is traced, once")
    assertTrue(lines[1]:find("SetIcon failed", 1, true) ~= nil, lines[1])
    assertFalse(NS2.Style.Bind(frame, "SetSpellName", 1), "a missing method answers false")
    assertFalse(NS2.Style.Bind(frame, "SetIcon", 1), "a refused one answers false")
    assertTrue(NS2.Style.Bind(frame, "SetDurationBar", 7))
    assertEqual(frame:__last("SetDurationBar")[1], 7, "its arguments reach the method")
end)

test("style: a class color is looked for only in the active style's block, text blocks included", function()
    local U = NS.Style.UsesClassColor
    assertFalse(U(cfg({ style = "bars" })), "the template turns none on")
    assertTrue(U(cfg({ style = "bars", bars = { useClassColorSpark = true } })), "a bar surface")
    assertTrue(U(cfg({ style = "icons", icons = { stacks = { useClassColorFont = true } } })), "an icon's text")
    -- red under: UsesClassColor reading both blocks (a bar flag re-applies an icon container on every swap)
    assertFalse(U(cfg({ style = "icons", bars = { useClassColorBar = true } })), "the inactive block")
    local c = cfg({ style = "icons" })
    c.icons = nil
    assertFalse(U(c), "no block at all")
end)

test("style: a dispel color map holds a color per stored type, and nothing for a leaf that is not a color", function()
    local stored = { Magic = { r = 0.1, g = 0.2, b = 0.3 }, Curse = "junk" }
    local map = NS.Style.DispelColorMap(stored)
    assertEqual(table.concat({ map.Magic.r, map.Magic.g, map.Magic.b }, ","), "0.1,0.2,0.3")
    -- red under: DispelColorMap building a color out of whatever the leaf holds
    assertNil(map.Curse)
    assertNil(map.Poison, "a type with no stored color")
    assertTrue(NS.Style.DispelColorMap(stored) == map, "unchanged leaves: the same map")
    assertEqual(next(NS.Style.DispelColorMap(nil)), nil, "no stored colors: an empty map")
end)

test("style: a dispel color map's None entry is the surface's own color, and every entry opaque (feedback #7, item 4)", function()
    local stored = { Magic = { r = 0.1, g = 0.2, b = 0.3, a = 1 } }
    local bar = { r = 0.9, g = 0.5, b = 0.1, a = 0.6 }
    local map = NS.Style.DispelColorMap(stored, bar)
    -- red under: None left to the palette (or to Blizzard's own tint) for an aura with no type
    assertEqual(table.concat({ map.None.r, map.None.g, map.None.b, map.None.a }, ","), "0.9,0.5,0.1,1")
    -- red under: an entry carrying the surface's alpha (the engine drops it; the region carries it)
    assertEqual(map.Magic.a, 1)
    assertTrue(NS.Style.DispelColorMap(stored, bar) == map, "one map per palette and fallback")
    local bg = { r = 0, g = 0, b = 0, a = 0.5 }
    assertTrue(NS.Style.DispelColorMap(stored, bg) ~= map, "another surface's fallback, another map")
    bar.r = 0.2   -- a class-colored fallback is updated in place
    assertEqual(NS.Style.DispelColorMap(stored, bar).None.r, 0.2, "a moved fallback rebuilds")
    -- red under: a type outside the palette (Enrage) left to Blizzard's own tint instead of the surface's color
    assertEqual(table.concat({ map.Enrage.r, map.Enrage.g, map.Enrage.b, map.Enrage.a }, ","),
        table.concat({ map.None.r, map.None.g, map.None.b, map.None.a }, ","), "Enrage keeps the surface's color, like None")
end)

test("style: tooltips and click-through decide whether a button takes the mouse at all", function()
    local function behave(over)
        local f = R()
        NS.Style.ApplyBehavior(f, cfg(over))
        return f
    end
    local f = behave({ unit = "player", auraType = "HELPFUL" })
    assertEqual(f:__joined("SetMouseMotionEnabled"), "true", "hover shows the tooltip")
    assertEqual(f:__joined("SetMouseClickEnabled"), "true", "right-click cancels")
    f = behave({ behavior = { tooltips = false } })
    -- red under: SetMouseMotionEnabled ignoring the tooltip setting
    assertEqual(f:__joined("SetMouseMotionEnabled"), "false", "no tooltips: no hover")
    f = behave({ unit = "player", auraType = "HELPFUL", behavior = { clickThrough = true } })
    -- red under: click-through that still takes hover or clicks
    assertEqual(f:__joined("SetMouseMotionEnabled"), "false")
    assertEqual(f:__joined("SetMouseClickEnabled"), "false")
end)

test("style: right-click cancel reaches the player's buffs and their enchant slots, never the player's debuffs, and never when turned off", function()
    local function cancelOf(over)
        local f = R()
        NS.Style.ApplyBehavior(f, cfg(over))
        return f:__last("SetCancelAuraButtons")[1]
    end
    assertEqual(cancelOf({ unit = "player", auraType = "HELPFUL" }), "RightButtonUp", "a player buff, or its weapon enchants")
    -- red under: cancelEnabled still reading the retired ENCHANT aura type (feedback #6)
    assertNil(cancelOf({ unit = "player", auraType = "ENCHANT" }), "no aura type of that name any more")
    -- red under: cancelEnabled testing the unit alone (a debuff cannot be canceled, and the click is swallowed)
    assertNil(cancelOf({ unit = "player", auraType = "HARMFUL" }), "the player's debuffs")
    assertNil(cancelOf({ unit = "player", auraType = "HELPFUL", behavior = { cancelOnRightClick = false } }),
        "turned off")
end)

test("style: the tooltip anchor and in-combat hiding come from settings, the template filling a missing anchor", function()
    local f = R()
    NS.Style.ApplyBehavior(f, cfg({ behavior = { tooltipAnchor = "ANCHOR_TOP", tooltipInCombat = false } }))
    assertEqual(f:__joined("SetTooltipAnchorPoint"), "ANCHOR_TOP,0,0")
    -- red under: SetHideTooltipInCombat handed the setting un-negated
    assertEqual(f:__joined("SetHideTooltipInCombat"), "true", "no tooltips in combat")
    local c = cfg()
    c.behavior.tooltipAnchor = nil
    c.behavior.tooltipInCombat = true
    f = R()
    NS.Style.ApplyBehavior(f, c)
    assertEqual(f:__last("SetTooltipAnchorPoint")[1], D.behavior.tooltipAnchor)
    assertEqual(f:__joined("SetHideTooltipInCombat"), "false")
end)

test("style: the time text gets the engine's formatter for its format, and the expiring color at its threshold", function()
    local points = {}
    local nop = function() end
    local NS2 = fresh({ before = function(m)
        m.Enum = m.Enum or {}
        m.Enum.SecondsFormatterAbbreviation = { OneLetter = 1 }
        m.Enum.SecondsFormatterRounding = { Truncate = 1 }
        m.Enum.SecondsFormatterInterval = { Seconds = 1, Days = 4 }
        m.Enum.DurationTextBindingProperty = { RemainingDuration = 1 }
        m.C_StringUtil = { CreateSecondsFormatter = function()
            return setmetatable({}, { __index = function() return nop end })
        end }
        m.C_CurveUtil = { CreateColorCurve = function()
            local curve = {}
            function curve.AddPoint(_, at, color)
                local n = #points
                points[n + 1] = { at, color }
            end
            return curve
        end }
    end })
    local function bound(over)
        local c = NS2.Database.Merge(NS2.Database.DeepCopy(NS2.CONTAINER_TEMPLATE), over)
        local f = R()
        NS2.Style.Element(f, c, true)
        return f:__last("SetDurationText")[2], c
    end
    local opts = bound({ style = "bars", bars = { timeFormat = "blizzard" } })
    -- red under: the Blizzard format left to the engine's default, which truncates (I-2)
    assertTrue(opts.textFormatter ~= nil, "the Blizzard format is a round-up copy of the engine's own")
    assertNil(opts.textColor, "no expiring color unless turned on")
    local short = bound({ style = "bars", bars = { timeFormat = "short" } }).textFormatter
    local long = bound({ style = "bars", bars = { timeFormat = "long" } }).textFormatter
    assertTrue(short ~= nil and long ~= nil and short ~= long, "each format its own formatter")
    assertTrue(opts.textFormatter ~= short and opts.textFormatter ~= long, "the Blizzard one is not the short one")
    local c
    opts, c = bound({ style = "icons", icons = { expiringColorOn = true, expiringThreshold = 8 } })
    assertTrue(opts.textColor ~= nil, "a color curve")
    local n = #points
    -- red under: curveFor keyed without the threshold (every look shares the first threshold)
    assertEqual(points[n][1], 8, "normal color from the threshold up")
    assertEqual(points[n][2].g, c.icons.time.fontColor.g)
    assertEqual(points[n - 1][1], 0, "the expiring color below it")
    assertEqual(points[n - 1][2].g, c.icons.expiringColor.g)
    c.icons.expiringThreshold = nil
    local f = R()
    NS2.Style.Element(f, c, true)
    n = #points
    assertEqual(points[n][1], NS2.CONTAINER_TEMPLATE.icons.expiringThreshold, "a missing threshold is the template's")
end)

test("style: a placeholder's time text is what its format's formatter writes, the one the engine is handed (B-5)", function()
    local made = 0
    local nop = function() end
    local NS2 = fresh({ before = function(m)
        m.Enum = m.Enum or {}
        m.Enum.SecondsFormatterAbbreviation = { OneLetter = 1 }
        m.Enum.SecondsFormatterRounding = { RoundUp = 0, Truncate = 1 }
        m.Enum.SecondsFormatterInterval = { Seconds = 1, Days = 4 }
        m.C_StringUtil = { CreateSecondsFormatter = function()
            made = made + 1
            local id = made
            return setmetatable({ Format = function(_, s) return ("F%d:%d"):format(id, s) end },
                { __index = function() return nop end })
        end }
    end })
    local timed = { name = "X", icon = 1, remaining = 75, duration = 90, stacks = 0 }
    local timeless = { name = "Well Fed", icon = 1, remaining = 0, duration = 0, stacks = 0 }
    for _, style in ipairs({ "bars", "icons" }) do
        local fill = (style == "icons") and NS2.Style.Icons.FillPreview or NS2.Style.Bars.FillPreview
        for _, fmt in ipairs(NS2.Constants.TIME_FORMATS) do
            local c = NS2.Database.Merge(NS2.Database.DeepCopy(NS2.CONTAINER_TEMPLATE),
                { style = style, [style] = { timeFormat = fmt } })
            local live = R()
            NS2.Style.Element(live, c, true)
            local want = live:__last("SetDurationText")[2].textFormatter:Format(75)
            local f = R()
            NS2.Style.Element(f, c, false)
            f.__am.time = R()
            fill(f, timed, c)
            -- red under: a placeholder's time written as plain seconds whatever the format
            assertEqual(f.__am.time:__last("SetText")[1], want, style .. " " .. fmt)
            fill(f, timeless, c)
            assertEqual(f.__am.time:__last("SetText")[1], "", style .. " " .. fmt .. ": a timeless aura writes none")
        end
    end
end)

test("style: a placeholder running out takes the running-out color, as the engine's curve paints a live one (B-5)", function()
    local red = { r = 0.9, g = 0.1, b = 0.2, a = 1 }
    local function timeColor(style, over, aura)
        local c = cfg({ style = style, [style] = over })
        local f = R()
        NS.Style.Element(f, c, false)
        f.__am.time = R()
        local fill = (style == "icons") and NS.Style.Icons.FillPreview or NS.Style.Bars.FillPreview
        fill(f, aura, c)
        return f.__am.time:__joined("SetTextColor")
    end
    local low = { name = "X", icon = 1, remaining = 3, duration = 8, stacks = 0 }
    local high = { name = "X", icon = 1, remaining = 11, duration = 12, stacks = 0 }
    local timeless = { name = "X", icon = 1, remaining = 0, duration = 0, stacks = 0 }
    for _, style in ipairs({ "bars", "icons" }) do
        local on = { expiringColorOn = true, expiringThreshold = 5, expiringColor = red }
        -- red under: a placeholder's time text left in its font color below the threshold
        assertEqual(timeColor(style, on, low), "0.9,0.1,0.2,1", style .. ": below the threshold")
        assertNil(timeColor(style, on, high), style .. ": at or above it, the font color stands")
        assertNil(timeColor(style, on, timeless), style .. ": a timeless aura never runs out")
        assertNil(timeColor(style, { expiringColorOn = false, expiringColor = red }, low), style .. ": off")
        local c = cfg()
        c[style].expiringThreshold = nil
        c[style].expiringColorOn, c[style].expiringColor = true, red
        c.style = style
        local f = R()
        NS.Style.Element(f, c, false)
        f.__am.time = R()
        local fill = (style == "icons") and NS.Style.Icons.FillPreview or NS.Style.Bars.FillPreview
        fill(f, { name = "X", icon = 1, remaining = D[style].expiringThreshold - 1, duration = 60, stacks = 0 }, c)
        assertEqual(f.__am.time:__joined("SetTextColor"), "0.9,0.1,0.2,1", style .. ": a missing threshold is the template's")
    end
end)

test("style: at the default threshold one placeholder is running out, so turning the color on shows (B-5)", function()
    for kind, set in pairs(NS.Constants.PREVIEW_AURAS) do
        local seen = 0
        for _, a in ipairs(set) do
            if a.duration > 0 and a.remaining < D.bars.expiringThreshold then seen = seen + 1 end
        end
        -- red under: every placeholder above the default threshold (the setting would show no change)
        assertTrue(seen >= 1, kind .. ": a placeholder under the default running-out threshold")
    end
    assertEqual(D.icons.expiringThreshold, D.bars.expiringThreshold, "one default for both styles")
end)

test("style: a style leaf left nil draws the template's value, never a literal of its own", function()
    -- The one home for defaults is the template (savedvariables-§2; Style.lua's header). A backfilled
    -- profile never holds a nil leaf, so this is the fallback a reader must still honor.
    local c = cfg({ style = "bars", bars = { icon = "LEFT", iconSize = 10 } })
    c.bars.iconGap, c.bars.iconZoom = nil, nil
    local _, am = dressedBars(c, false)
    local z = D.bars.iconZoom
    -- red under: Style_Bars' layout restating `or 0` for the icon gap and the icon zoom
    assertEqual(am.bar:__calls("SetPoint")[1][4], 10 + D.bars.iconGap, "bar: icon gap")
    assertEqual(am.icon:__joined("SetTexCoord"), table.concat({ z, 1 - z, z, 1 - z }, ","), "bar: icon zoom")

    local ic = cfg({ style = "icons", unit = "player", auraType = "HELPFUL" })
    ic.icons.zoom, ic.icons.cooldownEdge, ic.icons.dispelBorder, ic.icons.borderShow = nil, nil, nil, nil
    ic.behavior.cancelOnRightClick = nil
    local frame, iam = dressedBars(ic, true)
    z = D.icons.zoom
    -- red under: Style_Icons reading a nil zoom, edge, dispel border or border as 0 / off
    assertEqual(iam.icon:__joined("SetTexCoord"), table.concat({ z, 1 - z, z, 1 - z }, ","), "icon: zoom")
    assertEqual(iam.cd:__joined("SetDrawEdge"), tostring(D.icons.cooldownEdge), "icon: cooldown edge")
    assertEqual(iam.border:IsShown(), D.icons.borderShow, "icon: border")
    assertEqual(iam.icon:__calls("SetPoint")[1][4], D.icons.borderShow and D.icons.borderSize or 0, "icon: art inset")
    assertEqual(frame:__count("AddDispelTypeTexture"), D.icons.dispelBorder and 4 or 0, "icon: dispel border")
    -- red under: cancelEnabled reading a nil cancelOnRightClick as off
    assertEqual(frame:__last("SetCancelAuraButtons")[1], D.behavior.cancelOnRightClick and "RightButtonUp" or nil,
        "behavior: right-click cancel")
end)
