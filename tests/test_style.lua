-- tests/test_style.lua — modules/Style*.lua and modules/Preview.lua: element sizes, the preview
-- layout, and the bindings handed to the aura engine's buttons.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil
local NS, mocks = T.NS, T.mocks

local function cfg(over)
    return NS.Database.Merge(NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE), over or {})
end

--- A stand-in for one of the engine's aura buttons: a frame whose binding methods are recorded.
local BINDINGS = {
    "SetDurationBar", "SetIcon", "SetSpellName", "SetDurationText", "SetApplicationCount",
    "SetDurationCooldown", "ClearDispelTypeTextures", "AddDispelTypeTexture", "ClearPandemicRegions",
    "AddPandemicRegion", "SetCancelAuraButtons", "SetTooltipAnchorPoint", "SetHideTooltipInCombat",
}
local function engineButton()
    local b = mocks.__stubFrame()
    b.__bound = {}
    for _, m in ipairs(BINDINGS) do
        b[m] = function(_, ...)
            b.__bound[#b.__bound + 1] = { m, ... }
        end
    end
    function b:__count(m)
        local n = 0
        for _, c in ipairs(self.__bound) do if c[1] == m then n = n + 1 end end
        return n
    end
    function b:__last(m)
        local hit
        for _, c in ipairs(self.__bound) do if c[1] == m then hit = c end end
        return hit
    end
    return b
end

test("style: an element's size comes from its style's settings", function()
    local w, h = NS.Style.ElementSize(cfg({ style = "bars" }))
    assertEqual(w, NS.CONTAINER_TEMPLATE.bars.width)
    assertEqual(h, NS.CONTAINER_TEMPLATE.bars.height)
    w, h = NS.Style.ElementSize(cfg({ style = "icons", icons = { width = 40, height = 20 } }))
    assertEqual(w, 40)
    assertEqual(h, 20)
end)

test("style: a stored-nil leaf falls back to the template's own value", function()
    -- Its own environment, so the template mutation below can never reach the shared one.
    local NS2, m2 = dofile("tests/fresh_env.lua")()
    local D = NS2.CONTAINER_TEMPLATE
    local function build(over)
        local c = NS2.Database.Merge(NS2.Database.DeepCopy(D), over)
        c.bars.width, c.icons.height, c.layout.strata, c.bars.name.fontSize = nil, nil, nil, nil
        return c
    end
    --- What the render path draws for the four nil leaves: bar width, icon height, the bar name's
    --- font size, and the anchor's strata.
    local function drawn()
        local _, ih = NS2.Style.ElementSize(build({ style = "icons" }))
        local bw = NS2.Style.ElementSize(build({ style = "bars" }))
        local frame, c = m2.__stubFrame(), build({ style = "bars" })
        NS2.Style.Element(frame, c, false)
        local sizes = {}
        -- name, time and stacks are one FontString in the kit (mock_base: CreateFontString aliases).
        rawset(frame.__am.name, "SetFont", function(_, _, size)
            sizes[#sizes + 1] = size
            return true
        end)
        NS2.Style.Element(frame, c, false)
        local inst = NS2.ContainerManager.instances[1]
        inst:Cfg().layout.strata = nil
        local strata
        rawset(inst.anchor, "SetFrameStrata", function(_, v) strata = v end)
        inst:Apply()
        return bw, ih, sizes[1], strata
    end
    local function expectTemplate()
        local bw, ih, fontSize, strata = drawn()
        -- red under: a literal fallback left in ElementSize
        assertEqual(bw, D.bars.width, "bar width")
        assertEqual(ih, D.icons.height, "icon height")
        assertEqual(fontSize, D.bars.name.fontSize, "bar name font size")
        assertEqual(strata, D.layout.strata, "anchor strata")
    end
    expectTemplate()

    -- The value is READ from the template, not restated beside it: move the template and the
    -- fallback moves with it. The restore runs even when an assertion fails.
    local saved = { D.bars.width, D.icons.height, D.layout.strata, D.bars.name.fontSize }
    D.bars.width, D.icons.height, D.layout.strata, D.bars.name.fontSize = 221, 33, "HIGH", 13
    local ok, err = pcall(expectTemplate)
    D.bars.width, D.icons.height, D.layout.strata, D.bars.name.fontSize = saved[1], saved[2], saved[3], saved[4]
    if not ok then error(err, 0) end
end)

--- A fresh stub that records the last paint call of each kind made on it. The kit's CreateTexture
--- returns the frame itself, so the fill and the background are one table until each is swapped
--- for one of these.
local function recorder()
    local r = mocks.__stubFrame()
    r.__calls = {}
    for _, m in ipairs({ "SetTexture", "SetVertexColor", "SetAlpha" }) do
        rawset(r, m, function(_, ...) r.__calls[m] = { ... } end)
    end
    return r
end

--- Dress a bar element, give it recording fill and background regions, and dress it again.
local function dressSurfaces(c)
    local frame = mocks.__stubFrame()
    NS.Style.Element(frame, c, false)
    frame.__am.fill, frame.__am.bg = recorder(), recorder()
    NS.Style.Element(frame, c, false)
    return frame.__am
end

test("style: a bar's fill and background take their texture, color and opacity from settings", function()
    local S, FALLBACK = NS.Style, NS.Constants.FALLBACK_TEXTURE
    local am = dressSurfaces(cfg({ style = "bars", bars = {
        barTexture = "Fill Tex", barAlpha = 0.7, barColor = { r = 0.1, g = 0.2, b = 0.3, a = 0.9 },
        bgTexture = "Bg Tex", bgColor = { r = 0.4, g = 0.5, b = 0.6, a = 0.25 } } }))
    local fill, bg = am.fill.__calls, am.bg.__calls
    assertEqual(fill.SetTexture[1], S.Fetch("statusbar", "Fill Tex", FALLBACK), "fill texture")
    assertEqual(table.concat(fill.SetVertexColor, ","), "0.1,0.2,0.3,0.9", "fill color")
    assertEqual(fill.SetAlpha[1], 0.7, "fill opacity")
    assertEqual(bg.SetTexture[1], S.Fetch("statusbar", "Bg Tex", FALLBACK), "background texture")
    assertEqual(table.concat(bg.SetVertexColor, ","), "0.4,0.5,0.6,0.25", "background color, its alpha kept")
end)

test("style: the background opacity multiplies onto the background texture", function()
    local am = dressSurfaces(cfg({ style = "bars", bars = { barAlpha = 0.7, bgAlpha = 0.4 } }))
    local set = am.bg.__calls.SetAlpha
    -- red under: applySurfaces not setting the bg alpha
    assertEqual(set and set[1], 0.4, "the background's own opacity")
    assertEqual(am.fill.__calls.SetAlpha[1], 0.7, "the fill keeps its own")
    set = dressSurfaces(cfg({ style = "bars" })).bg.__calls.SetAlpha
    assertEqual(set and set[1], NS.CONTAINER_TEMPLATE.bars.bgAlpha, "the template's opacity by default")
    assertEqual(NS.CONTAINER_TEMPLATE.bars.bgAlpha, 1, "opaque by default: the default look is unchanged")
end)

test("preview: a column of bars grows down from the top left", function()
    local c = cfg({ style = "bars", layout = { axis = "vertical", growH = "right", growV = "down", spacing = 2 } })
    local point, x, y = NS.Preview.Offset(c, 1)
    assertEqual(point, "TOPLEFT"); assertEqual(x, 0); assertEqual(y, 0)
    local _, x2, y2 = NS.Preview.Offset(c, 2)
    assertEqual(x2, 0)
    assertEqual(y2, -(NS.CONTAINER_TEMPLATE.bars.height + 2))
end)

test("preview: rows of icons growing left and up wrap after perLine", function()
    local c = cfg({ style = "icons", layout = { axis = "horizontal", growH = "left", growV = "up",
        spacing = 2, lineSpacing = 3, perLine = 2 } })
    local point, x, y = NS.Preview.Offset(c, 2)
    assertEqual(point, "BOTTOMRIGHT")
    assertEqual(x, -(32 + 2)); assertEqual(y, 0)
    local _, x3, y3 = NS.Preview.Offset(c, 3)
    assertEqual(x3, 0); assertEqual(y3, 32 + 3)
end)

test("style: a restyle clears the additive bindings before adding them again", function()
    local b = engineButton()
    local c = cfg({ style = "bars", bars = { colorMode = "dispel", pandemic = true } })
    NS.Style.Element(b, c, true)
    NS.Style.Element(b, c, true)
    assertEqual(b:__count("AddDispelTypeTexture"), 2)
    assertEqual(b:__count("ClearDispelTypeTextures"), 2)
    assertEqual(b:__count("AddPandemicRegion"), 2)
    -- Clear precedes each add.
    local lastClear, lastAdd
    for i, call in ipairs(b.__bound) do
        if call[1] == "ClearDispelTypeTextures" then lastClear = i end
        if call[1] == "AddDispelTypeTexture" then lastAdd = i end
    end
    assertTrue(lastClear < lastAdd)
end)

test("style: a bar binds the engine's timer bar, icon, name, time and stacks", function()
    local b = engineButton()
    NS.Style.Element(b, cfg({ style = "bars" }), true)
    for _, m in ipairs({ "SetDurationBar", "SetIcon", "SetSpellName", "SetDurationText", "SetApplicationCount" }) do
        assertEqual(b:__count(m), 1, m)
    end
    assertEqual(b:__count("AddDispelTypeTexture"), 0, "one color: no dispel tint")
end)

test("style: an icon binds the cooldown and the dispel border", function()
    local b = engineButton()
    NS.Style.Element(b, cfg({ style = "icons" }), true)
    assertEqual(b:__count("SetDurationCooldown"), 1)
    assertEqual(b:__count("AddDispelTypeTexture"), 1)
end)

test("style: right-click cancel is offered only on your own buffs, and never click-through", function()
    local b = engineButton()
    NS.Style.Element(b, cfg({ unit = "player", auraType = "HELPFUL" }), true)
    assertEqual(b:__last("SetCancelAuraButtons")[2], "RightButtonUp")
    b = engineButton()
    NS.Style.Element(b, cfg({ unit = "target", auraType = "HELPFUL" }), true)
    assertNil(b:__last("SetCancelAuraButtons")[2])
    b = engineButton()
    NS.Style.Element(b, cfg({ behavior = { clickThrough = true } }), true)
    assertNil(b:__last("SetCancelAuraButtons")[2])
end)

test("style: a preview element is dressed but never bound to the engine", function()
    local b = engineButton()
    NS.Style.Element(b, cfg({ style = "bars" }), false)
    assertTrue(b.__am ~= nil)
    assertEqual(#b.__bound, 0)
end)

test("style: a class color keeps the stored alpha; off, the stored swatch is used", function()
    local stored = { r = 0.1, g = 0.2, b = 0.3, a = 0.5 }
    local r0, _, _, a0 = NS.Style.Color(stored, false)
    assertEqual(r0, 0.1); assertEqual(a0, 0.5)
    local r, g, b, a = NS.Style.Color(stored, true)
    local mage = mocks.RAID_CLASS_COLORS.MAGE
    assertEqual(r, mage.r); assertEqual(g, mage.g); assertEqual(b, mage.b)
    assertEqual(a, 0.5, "the swatch's opacity always applies (options-ui-§17)")
end)

test("style: a target container's class color is the target's, snapshotted at apply", function()
    -- Its own environment: UnitClass and the priest's color are planted there, never on the shared
    -- mock. The target's class token is an upvalue so the case can make the target an NPC.
    local targetToken = "PRIEST"
    local NS2, m2 = dofile("tests/fresh_env.lua")({ before = function(m)
        m.UnitClass = function(u)
            if u == "target" then return targetToken and "Priest", targetToken end
            return "Mage", "MAGE"
        end
        m.RAID_CLASS_COLORS.PRIEST = { r = 1, g = 1, b = 1 }
    end })
    local swatch = { r = 0.1, g = 0.2, b = 0.3, a = 0.6 }
    --- Container `id` drawn as bars with a class-colored fill, applied.
    local function applied(id)
        local inst = NS2.ContainerManager.instances[id]
        local c = inst:Cfg()
        c.style, c.bars.useClassColorBar, c.bars.barColor = "bars", true, swatch
        inst:Apply()
        return inst
    end
    --- Dress one engine button through the container's initializeFrame and read the fill's color.
    local function fillOf(inst)
        local btn = m2.__stubFrame()
        inst:InitFrame(btn)
        local fill = m2.__stubFrame()
        rawset(fill, "SetVertexColor", function(_, ...) fill.__color = { ... } end)
        btn.__am.fill = fill
        inst:InitFrame(btn)
        return table.concat(fill.__color, ",")
    end
    local priest, mage = m2.RAID_CLASS_COLORS.PRIEST, m2.RAID_CLASS_COLORS.MAGE
    local target = applied(3)
    -- red under: Style.Color ignoring dressClass
    assertEqual(fillOf(target), table.concat({ priest.r, priest.g, priest.b, 0.6 }, ","),
        "the target's class, with the swatch's alpha")
    targetToken = nil
    assertEqual(fillOf(target), table.concat({ priest.r, priest.g, priest.b, 0.6 }, ","),
        "read once per apply, not on every dress")
    target:Apply()
    assertEqual(fillOf(target), "0.1,0.2,0.3,0.6", "an unresolvable class falls through to the swatch")
    assertEqual(fillOf(applied(1)), table.concat({ mage.r, mage.g, mage.b, 0.6 }, ","),
        "a player container keeps the player's class")
end)

test("style: the Blizzard time format asks for no formatter of our own", function()
    assertNil(NS.Compat.CreateSecondsFormatter("blizzard"))
end)

test("style: buttons of one look share one formatter and curve; a new color builds a new curve", function()
    -- Its own environment: the formatter, curve and color constructors are planted with counters
    -- there, never on the shared mock, so a failing case cannot leak them into later suites.
    local built = { formatters = 0, curves = 0, colors = 0 }
    local nop = function() end
    local NS2, m2 = dofile("tests/fresh_env.lua")({ before = function(m)
        m.Enum = m.Enum or {}
        m.Enum.SecondsFormatterAbbreviation = { OneLetter = 1 }
        m.Enum.SecondsFormatterRounding = { Truncate = 1 }
        m.Enum.SecondsFormatterInterval = { Seconds = 1, Days = 4 }
        m.Enum.DurationTextBindingProperty = { RemainingDuration = 1 }
        m.Enum.LuaCurveType = { Step = 1 }
        m.C_StringUtil = { CreateSecondsFormatter = function()
            built.formatters = built.formatters + 1
            return setmetatable({}, { __index = function() return nop end })
        end }
        m.C_CurveUtil = { CreateColorCurve = function()
            built.curves = built.curves + 1
            return { SetType = nop, AddPoint = nop }
        end }
        local base = m.CreateColor
        m.CreateColor = function(...)
            built.colors = built.colors + 1
            return base(...)
        end
    end })
    local function button()
        local b = m2.__stubFrame()
        b.__bound = {}
        for _, name in ipairs(BINDINGS) do
            b[name] = function(_, ...)
                b.__bound[#b.__bound + 1] = { name, ... }
            end
        end
        return b
    end
    local function last(b, name)
        local hit
        for _, c in ipairs(b.__bound) do if c[1] == name then hit = c end end
        return hit
    end
    local c = NS2.Database.Merge(NS2.Database.DeepCopy(NS2.CONTAINER_TEMPLATE), {
        style = "bars", bars = { timeFormat = "short", expiringColorOn = true, colorMode = "dispel" } })
    local dispelLeaves = 0
    for _, name in ipairs(NS2.Constants.DISPEL_TYPES) do
        if type(c.bars.dispelColors[name]) == "table" then dispelLeaves = dispelLeaves + 1 end
    end
    local f0, c0, k0 = built.formatters, built.curves, built.colors
    local b1, b2 = button(), button()
    NS2.Style.Element(b1, c, true)
    NS2.Style.Element(b2, c, true)
    -- red under: BindDurationText calling Compat directly
    assertEqual(built.formatters - f0, 1, "one formatter for two buttons of one look")
    assertEqual(built.curves - c0, 1, "one curve for two buttons of one look")
    -- red under: Style.DispelColorMap without its memo
    assertEqual(built.colors - k0, dispelLeaves + 2, "one dispel map and one curve's two colors")
    assertTrue(last(b1, "AddDispelTypeTexture")[3].customDispelColorMap
        == last(b2, "AddDispelTypeTexture")[3].customDispelColorMap, "the two buttons share one map")
    assertTrue(last(b1, "SetDurationText")[3].textColor == last(b2, "SetDurationText")[3].textColor)

    -- A write replaces the leaf table, so a new expiring color is a new identity: a new curve.
    c.bars.expiringColor = { r = 0, g = 1, b = 0, a = 1 }
    NS2.Style.Element(b1, c, true)
    assertEqual(built.curves - c0, 2, "a new expiring color builds a new curve")
    assertEqual(built.formatters - f0, 1, "the format did not change, so neither did the formatter")
    -- A replaced dispel leaf invalidates the memoized map.
    c.bars.dispelColors.Magic = { r = 0, g = 0, b = 1, a = 1 }
    local k1 = built.colors
    NS2.Style.Element(b1, c, true)
    assertEqual(built.colors - k1, dispelLeaves, "a new dispel color rebuilds the map")
end)
