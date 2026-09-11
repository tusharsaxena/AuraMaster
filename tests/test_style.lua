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
        b[m] = function(_, ...) b.__bound[#b.__bound + 1] = { m, ... } end
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

test("style: the Blizzard time format asks for no formatter of our own", function()
    assertNil(NS.Compat.CreateSecondsFormatter("blizzard"))
end)
