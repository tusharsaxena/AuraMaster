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
    D.bars.width, D.icons.height, D.layout.strata, D.bars.name.fontSize = 221, 33, "DIALOG", 13
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

test("style: a tracked unit whose class lookup raises paints the swatch, and nothing raises", function()
    -- A class token the client withholds (a secret) raises where the library indexes
    -- RAID_CLASS_COLORS with it. A Lua string cannot be made secret here, so the table's index raises
    -- for the token instead. Planted in the case's own environment, never on the shared mock.
    local NS2, m2 = dofile("tests/fresh_env.lua")({ before = function(m)
        m.UnitClass = function(u)
            if u == "target" then return "Secret", "SECRET" end
            return "Mage", "MAGE"
        end
        setmetatable(m.RAID_CLASS_COLORS, { __index = function(_, k)
            if k == "SECRET" then error("attempt to index a table with a secret value") end
        end })
    end })
    local swatch = { r = 0.1, g = 0.2, b = 0.3, a = 0.6 }
    local inst = NS2.ContainerManager.instances[3]   -- Target debuffs (mine)
    local c = inst:Cfg()
    c.style, c.bars.useClassColorBar, c.bars.barColor = "bars", true, swatch
    local ok, err = pcall(inst.Apply, inst)
    -- red under: ResolveUnitClass calling NS.ClassColor unguarded
    assertTrue(ok, tostring(err))
    assertTrue(inst.classColor ~= nil and inst.classColor.r == nil, "the class is unresolved")
    local btn, fill = m2.__stubFrame(), m2.__stubFrame()
    inst:InitFrame(btn)
    rawset(fill, "SetVertexColor", function(_, ...) fill.__color = { ... } end)
    btn.__am.fill = fill
    inst:InitFrame(btn)
    assertEqual(table.concat(fill.__color, ","), "0.1,0.2,0.3,0.6", "the stored swatch, as for an NPC")
    ok, err = pcall(NS2.ContainerManager.RefreshUnit, "target")
    -- red under: classChanged calling NS.ClassColor unguarded
    assertTrue(ok, tostring(err))
end)

test("style: a dress that raises still clears its class color, and the error reaches the caller", function()
    -- Its own environment: the styler is replaced there, never on the shared one.
    local NS2, m2 = dofile("tests/fresh_env.lua")()
    NS2.Style.Bars.Apply = function() error("styler failed") end
    local c = NS2.Database.Merge(NS2.Database.DeepCopy(NS2.CONTAINER_TEMPLATE), { style = "bars" })
    local ok, err = pcall(NS2.Style.Element, m2.__stubFrame(), c, true, { r = 0.9, g = 0.8, b = 0.7 })
    assertTrue(not ok, "the styler's error is not swallowed")
    assertTrue(tostring(err):find("styler failed", 1, true) ~= nil, tostring(err))
    local mage = m2.RAID_CLASS_COLORS.MAGE
    local r, g, b = NS2.Style.Color({ r = 0.1, g = 0.2, b = 0.3, a = 1 }, true)
    -- red under: Style.Element clearing dressClass only after a clean styler.Apply
    assertEqual(table.concat({ r, g, b }, ","), table.concat({ mage.r, mage.g, mage.b }, ","),
        "outside a dress the player's class paints, not the failed dress's")
end)

test("style: a dress that raises hands the error handler the failing styler's stack", function()
    -- The client's debugstack, planted in this environment only: the headless mock has none.
    local NS2, m2 = dofile("tests/fresh_env.lua")({ before = function(m)
        m.debugstack = function() return debug.traceback("stack:", 2) end
    end })
    NS2.Style.Bars.Apply = function() error("styler failed") end
    local c = NS2.Database.Merge(NS2.Database.DeepCopy(NS2.CONTAINER_TEMPLATE), { style = "bars" })
    local ok, err = pcall(NS2.Style.Element, m2.__stubFrame(), c, true, nil)
    assertTrue(not ok, "the styler's error is not swallowed")
    err = tostring(err)
    local where = err:match("^(.-:%d+): styler failed")
    assertTrue(where ~= nil, "the message keeps the styler's file:line: " .. err)
    local stack = err:match("\n(.*)$") or ""
    -- red under: Style.Element re-raising the bare message from a pcall (no stack captured)
    assertTrue(stack:find(where, 1, true) ~= nil, "the stack names the failing styler's line: " .. err)
end)

test("style: a dress that raises a non-string value hands that value on unchanged", function()
    local NS2, m2 = dofile("tests/fresh_env.lua")({ before = function(m)
        m.debugstack = function() return debug.traceback("stack:", 2) end
    end })
    local raised = { reason = "styler failed" }
    NS2.Style.Bars.Apply = function() error(raised) end
    local c = NS2.Database.Merge(NS2.Database.DeepCopy(NS2.CONTAINER_TEMPLATE), { style = "bars" })
    local ok, err = pcall(NS2.Style.Element, m2.__stubFrame(), c, true, nil)
    assertTrue(not ok, "the styler's error is not swallowed")
    -- red under: withStack stringifying every error, whatever its type
    assertTrue(err == raised, "the caller receives the very table the styler raised: " .. tostring(err))
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
        if type(NS2.db.profile.dispelColors[name]) == "table" then dispelLeaves = dispelLeaves + 1 end
    end
    local f0, c0, k0 = built.formatters, built.curves, built.colors
    local b1, b2 = button(), button()
    NS2.Style.Element(b1, c, true)
    NS2.Style.Element(b2, c, true)
    -- red under: BindDurationText calling Compat directly
    assertEqual(built.formatters - f0, 1, "one formatter for two buttons of one look")
    assertEqual(built.curves - c0, 1, "one curve for two buttons of one look")
    -- red under: Style.DispelColorMap without its memo (a map is the palette's colors plus the None
    -- fallback, feedback #7)
    assertEqual(built.colors - k0, dispelLeaves + 1 + 2, "one dispel map and one curve's two colors")
    assertTrue(last(b1, "AddDispelTypeTexture")[3].customDispelColorMap
        == last(b2, "AddDispelTypeTexture")[3].customDispelColorMap, "the two buttons share one map")
    assertTrue(last(b1, "SetDurationText")[3].textColor == last(b2, "SetDurationText")[3].textColor)

    -- A write replaces the leaf table, so a new expiring color is a new identity: a new curve.
    c.bars.expiringColor = { r = 0, g = 1, b = 0, a = 1 }
    NS2.Style.Element(b1, c, true)
    assertEqual(built.curves - c0, 2, "a new expiring color builds a new curve")
    assertEqual(built.formatters - f0, 1, "the format did not change, so neither did the formatter")
    -- A replaced dispel leaf invalidates the memoized map.
    NS2.db.profile.dispelColors.Magic = { r = 0, g = 0, b = 1, a = 1 }
    local k1 = built.colors
    NS2.Style.Element(b1, c, true)
    assertEqual(built.colors - k1, dispelLeaves + 1, "a new dispel color rebuilds the map, its None fallback included")
end)

-- ── Style.lua: media, text, borders, bindings, behavior ───────────────────────────────────────

local R = dofile("tests/region_recorder.lua")
local fresh = dofile("tests/fresh_env.lua")
local assertFalse = T.assertFalse
local C, D = NS.Constants, NS.CONTAINER_TEMPLATE

--- A fresh environment with a LibSharedMedia stand-in that knows what was registered with it, and
--- raises for the key "Broken" (a media pack uninstalled half-way). Unknown methods answer a table,
--- so the library's own media setup can use it.
local function withMedia()
    local registered = {}
    local NS2 = fresh({ before = function(m)
        local lsm = setmetatable({ MediaType = { FONT = "font", STATUSBAR = "statusbar", BORDER = "border",
            BACKGROUND = "background", SOUND = "sound" } },
            { __index = function() return function() return {} end end })
        function lsm.Register(_, kind, key, path)
            registered[kind .. ":" .. key] = path
            return true
        end
        function lsm.Fetch(_, kind, key)
            if key == "Broken" then error("media pack half-installed") end
            return registered[kind .. ":" .. key]
        end
        m.__libs["LibSharedMedia-3.0"] = lsm
    end })
    return NS2, registered
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

test("style: the Solid border is registered with the media library as the flat white texture", function()
    local _, registered = withMedia()
    -- red under: dropping Style.lua's LSM:Register (the default "Solid" border draws the tooltip edge)
    assertEqual(registered["border:Solid"], C.WHITE_TEXTURE)
end)

test("style: a media key resolves through the media library; an unknown, empty, odd or broken one draws the fallback", function()
    local NS2 = withMedia()
    local Fetch = NS2.Style.Fetch
    assertEqual(Fetch("border", "Solid", "FB"), C.WHITE_TEXTURE, "a registered key")
    assertEqual(Fetch("statusbar", "Uninstalled", "FB"), "FB", "a key that no longer resolves")
    assertEqual(Fetch("statusbar", "", "FB"), "FB", "an empty key")
    assertEqual(Fetch("statusbar", 42, "FB"), "FB", "a key that is not a string")
    local ok, path = pcall(Fetch, "statusbar", "Broken", "FB")
    -- red under: Style.Fetch calling LSM.Fetch unguarded (every dress raises until the pack is fixed)
    assertTrue(ok, tostring(path))
    assertEqual(path, "FB", "a lookup that raises")
end)

test("style: a font the client refuses falls back to the built-in font at the same size and flags", function()
    -- The media library still lists the font, but the file is gone: the client refuses it.
    local NS2, registered = withMedia()
    registered["font:Gone"] = "Interface\\AddOns\\SomePack\\Gone.ttf"
    local fs = R()
    fs.__answer.SetFont = function(_, path) return path == C.FALLBACK_FONT end
    NS2.Style.ApplyText(fs, { font = "Gone", fontSize = 13, fontFlags = "OUTLINE" }, R(), D.bars.name)
    local calls = fs:__calls("SetFont")
    assertEqual(calls[1][1], registered["font:Gone"], "the listed font is tried first")
    -- red under: ApplyText ignoring SetFont's answer (the text draws in no font at all)
    assertEqual(#calls, 2)
    assertEqual(table.concat({ calls[2][1], calls[2][2], calls[2][3] }, ","), C.FALLBACK_FONT .. ",13,OUTLINE")
end)

test("style: each outline setting reaches the font as the client's flag string", function()
    local cases = { NONE = "", OUTLINE = "OUTLINE", THICKOUTLINE = "THICKOUTLINE", MONOCHROME = "MONOCHROME",
        MONOCHROMEOUTLINE = "MONOCHROME,OUTLINE" }
    for setting, flags in pairs(cases) do
        local fs = R()
        NS.Style.ApplyText(fs, { fontFlags = setting }, R(), D.bars.name)
        -- red under: FLAG_MAP missing an entry (the combined flag is not the setting's own name)
        assertEqual(fs:__last("SetFont")[3], flags, setting)
    end
    local fs = R()
    NS.Style.ApplyText(fs, {}, R(), D.bars.name)
    assertEqual(fs:__last("SetFont")[3], "", "no setting: no outline")
end)

test("style: a font shadow is a one-pixel black drop when on, and no offset when off", function()
    local fs = R()
    NS.Style.ApplyText(fs, { fontShadow = true }, R(), D.bars.name)
    assertEqual(fs:__joined("SetShadowColor"), "0,0,0,1")
    assertEqual(fs:__joined("SetShadowOffset"), "1,-1")
    fs = R()
    NS.Style.ApplyText(fs, { fontShadow = false }, R(), D.bars.name)
    -- red under: the shadow's offset left at the font object's default when turned off
    assertEqual(fs:__joined("SetShadowOffset"), "0,0")
    assertEqual(fs:__count("SetShadowColor"), 0)
end)

test("style: a text's corner, offsets and justification come from its block, the template filling what is missing", function()
    local fs, anchor = R(), R()
    NS.Style.ApplyText(fs, { point = "TOP", x = 3, y = "junk", justify = "LEFT", fontSize = 9 }, anchor, D.bars.name)
    local p = fs:__last("SetPoint")
    assertEqual(p[1], "TOP"); assertTrue(p[2] == anchor); assertEqual(p[3], "TOP")
    assertEqual(p[4], 3); assertEqual(p[5], 0, "an offset that is not a number is 0")
    assertEqual(fs:__last("SetJustifyH")[1], "LEFT")
    assertEqual(fs:__last("SetFont")[2], 9)
    assertEqual(fs:__joined("SetWordWrap"), "false", "one line, never wrapped")
    assertEqual(fs:__count("ClearAllPoints"), 1, "re-placed, never stacked on the last point")
    fs = R()
    NS.Style.ApplyText(fs, {}, anchor, D.icons.time)
    -- red under: ApplyText falling back to literals instead of the element's template block
    assertEqual(fs:__last("SetPoint")[1], D.icons.time.point)
    assertEqual(fs:__last("SetJustifyH")[1], D.icons.time.justify)
    assertEqual(fs:__last("SetFont")[2], D.icons.time.fontSize)
end)

test("style: a text given a box is as wide as the box less its offset, so its justification has room to show", function()
    local fs = R()
    NS.Style.ApplyText(fs, { point = "RIGHT", x = -4, justify = "RIGHT" }, R(), D.bars.time, 200)
    -- red under: a single-anchor FontString with no width (justify has nothing to align within)
    assertEqual(fs:__last("SetWidth")[1], 196)
    assertEqual(fs:__last("SetJustifyH")[1], "RIGHT")
    fs = R()
    NS.Style.ApplyText(fs, { x = 30 }, R(), D.bars.time, 20)
    -- red under: a box narrower than the offset handing the font string a zero or negative width
    assertEqual(fs:__last("SetWidth")[1], 1)
    fs = R()
    NS.Style.ApplyText(fs, { x = "junk" }, R(), D.bars.time, 50)
    assertEqual(fs:__last("SetWidth")[1], 50, "an offset that is not a number takes nothing off")
    fs = R()
    NS.Style.ApplyText(fs, { x = -4 }, R(), D.bars.time)
    -- red under: a box left over from an earlier dress (a text that lost its box keeps the old width)
    assertEqual(fs:__last("SetWidth")[1], 0, "no box: the text sizes to its own string")
end)

test("style: a missing text block leaves its font string untouched", function()
    local fs = R()
    local ok = pcall(NS.Style.ApplyText, fs, nil, R(), D.bars.name)
    -- red under: ApplyText without its missing-block guard
    assertTrue(ok)
    assertEqual(#fs.__log, 0)
end)

test("style: a text's color is its own swatch, or the dress's class when its companion is on", function()
    local _, am = dressedBars(cfg({ style = "bars", bars = {
        name = { fontColor = { r = 0.1, g = 0.2, b = 0.3, a = 0.4 }, useClassColorFont = true },
        time = { fontColor = { r = 0.5, g = 0.6, b = 0.7, a = 0.8 }, useClassColorFont = false },
    } }), false, { r = 0.9, g = 0.8, b = 0.7 })
    -- red under: ApplyText painting fontColor without its useClassColorFont companion
    assertEqual(am.name:__joined("SetTextColor"), "0.9,0.8,0.7,0.4", "class, with the swatch's alpha")
    assertEqual(am.time:__joined("SetTextColor"), "0.5,0.6,0.7,0.8", "the swatch")
end)

test("style: a missing color paints opaque white rather than raising", function()
    local c = cfg({ style = "bars" })
    c.bars.barColor = nil
    local ok, err = pcall(dressedBars, c, false)
    assertTrue(ok, tostring(err))
    local _, am = dressedBars(c, false)
    -- red under: a resolver handing SetVertexColor nil channels
    assertEqual(am.fill:__joined("SetVertexColor"), "1,1,1,1")
end)

test("style: a border is hidden when off, styled None, or without a positive size", function()
    local cases = {
        { false, "Solid", 1, "off" }, { true, "None", 1, "the None style" },
        { true, "Solid", 0, "zero size" }, { true, "Solid", "junk", "a size that is not a number" },
    }
    for _, c in ipairs(cases) do
        local f = R()
        f:Show()
        NS.Style.ApplyBorder(f, c[1], c[2], c[3], { r = 1, g = 1, b = 1, a = 1 }, false)
        -- red under: ApplyBorder drawing a border it was told not to
        assertFalse(f:IsShown(), c[4])
        assertEqual(f:__count("SetBackdrop"), 0, c[4])
        assertNil(f.__amBackdrop, c[4] .. ": no backdrop frame")
    end
end)

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
    local lines = {}
    NS2.Debug = function(tag, fmt, ...)
        if tag == "Style" then
            lines[#lines + 1] = fmt:format(...)
        end
    end
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
    assertEqual(frame:__count("AddDispelTypeTexture"), D.icons.dispelBorder and 1 or 0, "icon: dispel border")
    -- red under: cancelEnabled reading a nil cancelOnRightClick as off
    assertEqual(frame:__last("SetCancelAuraButtons")[1], D.behavior.cancelOnRightClick and "RightButtonUp" or nil,
        "behavior: right-click cancel")
end)

-- ── one element, two styles (C-4) ───────────────────────────────────────────────────────────────

test("style: a frame dressed as a bar, then as an icon, builds icon regions and hides the bar's", function()
    local frame = R()
    local c = cfg()
    c.style = "bars"
    NS.Style.Element(frame, c, false)
    local bars = frame.__am
    assertEqual(bars.style, "bars", "tagged with the style that built it")
    for k, v in pairs(bars) do if type(v) == "table" then bars[k] = R() end end
    bars.icon:Show(); bars.pandemic:Hide()
    -- bar and text: shown by build, never re-shown by Bars.Apply (only the icon is, in its layout)
    bars.bar:Show(); bars.text:Show()
    c.style = "icons"
    local ok, err = pcall(NS.Style.Element, frame, c, false)
    -- red under: Icons.Apply reusing the bar's __am (it has no cd)
    assertTrue(ok, tostring(err))
    local icons = frame.__am
    assertTrue(icons ~= bars, "icon regions of its own")
    assertEqual(icons.style, "icons")
    assertTrue(icons.cd ~= nil)
    -- red under: RegionsFor leaving the other style's regions drawn under the new ones
    for k, v in pairs(bars) do
        if type(v) == "table" then assertTrue(not v:IsShown(), "the bar's " .. k .. " is hidden") end
    end
    c.style = "bars"
    NS.Style.Element(frame, c, false)
    -- red under: RegionsFor building a second set of bar regions (a frame is never freed)
    assertTrue(frame.__am == bars, "the bar's own regions again")
    assertTrue(bars.icon:IsShown(), "shown again as it was")
    -- red under: RegionsFor dropping restoreRegions (Bars.Apply never re-shows the bar or the text
    -- frame, so a bars -> icons -> bars button would draw no fill, no name and no time)
    assertTrue(bars.bar:IsShown(), "the bar is shown again")
    assertTrue(bars.text:IsShown(), "the texts' frame is shown again")
    -- red under: re-showing every region (the pandemic wash drawn on a bar that is not in its window)
    assertTrue(not bars.pandemic:IsShown(), "the pandemic wash stays as it was: hidden")
end)

test("style: hiding the other style's regions never hides the element itself", function()
    local frame = mocks.__stubFrame()
    frame:Show()
    local c = cfg()
    c.style = "bars"
    NS.Style.Element(frame, c, false)
    c.style = "icons"
    NS.Style.Element(frame, c, false)
    -- red under: HideRegions hiding a region that is the host (the kit's textures ARE the frame;
    -- a region handed the host in-game would hide the whole button)
    assertTrue(frame:IsShown(), "the element still draws")
end)

-- ── the text style's shared helpers (issue #2) ──────────────────────────────────────────────────

test("style: a text element takes its size from its own block, and a missing leaf from the template", function()
    local w, h = NS.Style.ElementSize(cfg({ style = "text", text = { width = 300, height = 20 } }))
    -- red under: ElementSize answering the bar's size for every style but icons
    assertEqual(w, 300)
    assertEqual(h, 20)
    local c = cfg({ style = "text" })
    c.text.width = nil
    w = NS.Style.ElementSize(c)
    assertEqual(w, D.text.width)
    assertEqual(NS.Style.StyleKey(cfg({ style = "text" })), "text")
    assertEqual(NS.Style.StyleKey(cfg({ style = "nonsense" })), "bars", "an unknown style draws as bars")
end)

test("style: a text container's class color is looked for in its text block, the font included", function()
    local U = NS.Style.UsesClassColor
    assertFalse(U(cfg({ style = "text" })), "the template turns none on")
    -- red under: UsesClassColor still reading the bar block for every style but icons
    assertTrue(U(cfg({ style = "text", text = { font = { useClassColorFont = true } } })), "the line's font")
    assertTrue(U(cfg({ style = "text", text = { useClassColorIconBorder = true } })), "the icon border")
    assertFalse(U(cfg({ style = "text", bars = { useClassColorBar = true } })), "the inactive block")
end)

test("style: a duration run's text format has its format string and one component per token, built once", function()
    local NS2 = fresh({ before = dofile("tests/text_apis.lua") })
    local piece = NS2.TextTemplate.Compile("$spellname$ $remainingduration$ / $maxduration$ ($remainingpercent$)").pieces[3]
    local tf = NS2.Style.DurationTextFormat(piece, "short")
    assertEqual(tf.formatString, "{} / {} ({}")
    local P = NS2.Compat
    -- red under: a component naming the token's key instead of the engine property
    assertEqual(tf.components[1].property, P.DurationProperty("RemainingDuration"))
    assertEqual(tf.components[2].property, P.DurationProperty("TotalDuration"))
    assertEqual(tf.components[3].property, P.DurationProperty("RemainingPercent"))
    assertEqual(tf.components[1].formatter.kind, "seconds")
    assertTrue(tf.components[1].formatter == tf.components[2].formatter, "one seconds formatter per format")
    -- red under: a percent written through the seconds formatter ("40s" for 40 %)
    local pf = tf.components[3].formatter
    assertEqual(pf.kind, "rule")
    local bp = pf:__last("SetBreakpoints")[1]
    assertEqual(bp[1].threshold, 0)
    -- red under: the old "%d%%" (a token adding a "%" the player did not type, feedback #5)
    assertEqual(bp[1].format, "%d")
    -- red under: a fractional 0-100 value handed to "%d" unrounded
    assertEqual(bp[1].step, 1)
    -- red under: DurationTextFormat rebuilding on every dress
    assertTrue(NS2.Style.DurationTextFormat(piece, "short") == tf, "memoized per piece and format")
    assertTrue(NS2.Style.DurationTextFormat(piece, "long") ~= tf, "a new format builds its own")
end)

test("style: a duration run binds its format and binding, recolored only when asked, blinking only when asked", function()
    local NS2 = fresh({ before = dofile("tests/text_apis.lua") })
    local S = NS2.Style
    local D2 = NS2.CONTAINER_TEMPLATE.text
    local piece = NS2.TextTemplate.Compile("$remainingduration$").pieces[1]
    local tf = S.DurationTextFormat(piece, "blizzard")
    local white = { r = 1, g = 1, b = 1, a = 1 }
    local function bind(s)
        local b = R()
        S.BindDurationFormat(b, "fs", tf, "binding", s, D2, white)
        return b:__last("SetDurationText")[2]
    end
    local opts = bind({})
    assertTrue(opts.textFormat == tf)
    assertEqual(opts.binding, "binding")
    assertNil(opts.textColor, "no curve unless turned on")
    local red = { r = 1, g = 0, b = 0, a = 1 }
    opts = bind({ expiringColorOn = true, expiringThreshold = 3, expiringColor = red })
    local points = opts.textColor.curve:__count("AddPoint")
    -- red under: runTextColor building the blink curve for the plain recolor
    assertEqual(points, 2, "the plain step: the running-out color, then the font color")
    opts = bind({ expiringColorOn = true, expiringBlink = true, expiringThreshold = 3, expiringColor = red })
    -- red under: runTextColor ignoring expiringBlink
    assertEqual(opts.textColor.curve:__count("AddPoint"), 3 / 0.25 + 1, "a point every quarter second, then the font color")
    assertEqual(opts.textColor.curve:__last("AddPoint")[2].g, 1, "the font color from the threshold up")
    assertEqual(opts.textColor.curve.calls[1].name, "SetType")
    assertEqual(opts.textColor.curve.calls[2][2].r, 1, "the blink is in the running-out color")
    opts = bind({ expiringBlink = true, expiringThreshold = 3, expiringColor = red })
    assertEqual(opts.textColor.curve.calls[2][2].g, 1, "blink without the recolor blinks the font color")
end)

test("style: a placeholder's seconds are written by the format's formatter, else as whole seconds", function()
    local NS2 = fresh({ before = dofile("tests/text_apis.lua") })
    -- tests/text_apis.lua's formatter writes "<n>s"
    assertEqual(NS2.Style.PreviewSeconds(28, "short"), "28s")
    -- red under: PreviewSeconds not falling back when the client has no formatter
    assertEqual(NS.Style.PreviewSeconds(28, "short"), "28s", "the shared environment has none")
end)

test("style: a client that refuses the percent rule's step gets the plain \"%d\" rule, never none (feedback #5)", function()
    local NS2 = fresh({ before = function(m)
        dofile("tests/text_apis.lua")(m)
        local create = m.C_StringUtil.CreateNumericRuleFormatter
        m.C_StringUtil.CreateNumericRuleFormatter = function()
            local f = create()
            f.SetBreakpoints = function(self, bps)
                if bps[1].step ~= nil then error("unknown breakpoint field 'step'") end
                self.given = bps
                return self
            end
            return f
        end
    end })
    local piece = NS2.TextTemplate.Compile("$remainingpercent$").pieces[1]
    local pf = NS2.Style.DurationTextFormat(piece, "short").components[1].formatter
    -- red under: percentFor giving up after the refused rule (the component would have no formatter)
    assertTrue(pf ~= nil, "a formatter was built")
    assertEqual(pf.given[1].format, "%d")
    assertEqual(pf.given[1].step, nil)
end)

test("style: no format Aura Master itself authors carries a leading or trailing space (feedback #5)", function()
    local NS2 = fresh({ before = dofile("tests/text_apis.lua") })
    local TT = NS2.TextTemplate
    local function trimmed(s) return s == s:match("^%s*(.-)%s*$") end
    -- An unbracketed token's own format: the stacks rule and the duration run.
    assertEqual(TT.Compile("$spellname$ $stacks$").pieces[3].format, "%d")
    local run = TT.Compile("$remainingpercent$").pieces[1]
    assertEqual(run.format, "{}")
    local bp = NS2.Style.DurationTextFormat(run, "short").components[1].formatter:__last("SetBreakpoints")[1]
    for _, b in ipairs(bp) do
        -- red under: a percent rule writing " %" or a trailing space around its number
        assertTrue(trimmed(b.format), ("%q is trimmed"):format(b.format))
    end
    -- Bracket text is the player's and is kept verbatim.
    assertEqual(TT.Compile("$spellname$[ - $remainingduration$]").pieces[2].format, " - {}")
end)
