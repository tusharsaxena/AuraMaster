-- tests/test_skin_border.lua — the owner's rulings of 2026-11-01 on a border under a skin: a skin's
-- None bar border style defers to the player's Show border and stored style, and a real style in a
-- skin wins (S.BarBorder). The icon beside a bar or a text line takes the same None; its Show border
-- stays the player's, because Ka0s Default's own icon style is a real Solid. Each case registers a
-- probe skin, so a shipped skin's value cannot pass for a surface that never read the skin.

local T = _G.AM_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local fresh = dofile("tests/fresh_env.lua")
local R = dofile("tests/region_recorder.lua")
local BS = dofile("tests/border_strips.lua")

--- Ka0s Default's own values for the bar and icon edge, with `tokens` over them, as a probe skin.
local function probe(NS, mocks, tokens)
    local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
    tokens["bar.border"] = { 0.11, 0.22, 0.33, 1 }
    tokens["icon.border"] = { 0.44, 0.55, 0.66, 1 }
    Skin:RegisterSkin({ key = "probe", label = "Probe", tokens = tokens })
    NS.ApplySkinChoice("ka0s", "probe")
end

--- A template-shaped config with `over` on it, dressed with recorders in every region.
local function dressed(NS, over)
    local c = NS.Database.Merge(NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE), over)
    local frame = R()
    NS.Style.Element(frame, c, false)
    for k, v in pairs(frame.__am) do
        if type(v) == "table" and k ~= "chain" then frame.__am[k] = R() end
    end
    NS.Style.Element(frame, c, false)
    return frame.__am
end

local REAL = { ["bar.borderStyle"] = "Solid", ["bar.borderSize"] = 4 }
local NONE = { ["bar.borderStyle"] = "None", ["bar.borderSize"] = 4 }
local RED = { r = 1, g = 0, b = 0, a = 1 }

test("bar border: a skin's None hands Show border on, the stored style and the stored thickness back", function()
    local NS, mocks = fresh()
    probe(NS, mocks, NONE)
    local am = dressed(NS, { bars = { borderShow = true, borderSize = 3 } })
    -- red under: a followed None drawing no border, or the skin's thickness over the stored one
    BS.assertSolid(am.border, 3, table.concat({ 0.11, 0.22, 0.33, 1 }, ","), "stored Solid at 3")
end)

test("bar border: a skin's None leaves Show border off off", function()
    local NS, mocks = fresh()
    probe(NS, mocks, NONE)
    assertTrue(not dressed(NS, { bars = { borderShow = false } }).border:IsShown())
end)

test("bar border: a real style wins, with Show border off and over the stored thickness", function()
    local NS, mocks = fresh()
    probe(NS, mocks, REAL)
    local am = dressed(NS, { bars = { borderShow = false, borderSize = 3 } })
    -- red under: drawing with the stored borderShow ahead of S.BarBorder
    BS.assertSolid(am.border, 4, table.concat({ 0.11, 0.22, 0.33, 1 }, ","), "the skin's Solid at 4")
end)

test("bar border: with the companion off the stored three stand under a real style", function()
    local NS, mocks = fresh()
    probe(NS, mocks, REAL)
    local over = { bars = { borderStyleFromSkin = false, borderColorFromSkin = false, borderColor = RED, borderSize = 2 } }
    over.bars.borderShow = false
    assertTrue(not dressed(NS, over).border:IsShown(), "off stays off")
    over.bars.borderShow = true
    BS.assertSolid(dressed(NS, over).border, 2, "1,0,0,1", "the stored border")
end)

test("beside icon: a skin's None defers on a bar and on a text line, and the art's inset agrees", function()
    local NS, mocks = fresh()
    probe(NS, mocks, { ["icon.borderStyle"] = "None", ["icon.borderSize"] = 4 })
    local am = dressed(NS, { bars = { iconBorderShow = true, iconBorderSize = 3 } })
    -- red under: a skin's None hiding a border the player has on
    BS.assertSolid(am.iconBorder, 3, table.concat({ 0.44, 0.55, 0.66, 1 }, ","), "beside a bar")
    assertEqual(NS.Style.IconInset(NS.Database.Merge(NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE.bars),
        { iconBorderShow = true, iconBorderSize = 3 }), NS.CONTAINER_TEMPLATE.bars), 3, "the inset")
    local text = dressed(NS, { style = "text", text = { icon = "LEFT", iconBorderShow = true, iconBorderSize = 2 } })
    BS.assertSolid(text.iconBorder, 2, table.concat({ 0.44, 0.55, 0.66, 1 }, ","), "beside a text line")
    assertTrue(not dressed(NS, {}).iconBorder:IsShown(), "Show border off stays off")
end)

test("beside icon: Show border off stays off under a real style, so Ka0s Default keeps its pixels", function()
    local NS, mocks = fresh()
    assertTrue(not dressed(NS, {}).iconBorder:IsShown(), "Ka0s Default's Solid")
    probe(NS, mocks, { ["icon.borderStyle"] = "Solid", ["icon.borderSize"] = 4 })
    assertTrue(not dressed(NS, {}).iconBorder:IsShown(), "a skin's Solid")
    BS.assertSolid(dressed(NS, { bars = { iconBorderShow = true } }).iconBorder, 4,
        table.concat({ 0.44, 0.55, 0.66, 1 }, ","), "shown, the skin's look")
end)

test("icon element: a skin's None stays no border: the rule is the bars' and the beside icons'", function()
    local NS, mocks = fresh()
    probe(NS, mocks, { ["icon.borderStyle"] = "None" })
    assertTrue(not dressed(NS, { style = "icons" }).border:IsShown())
end)

test("degraded: S.BarBorder answers the stored three, so a stored border still draws", function()
    local NS2 = dofile("tests/degraded_env.lua")()
    local style, show, size = NS2.Skin.BarBorder("Solid", true, 3, true)
    assertEqual(style, "Solid")
    assertEqual(show, true)
    assertEqual(size, 3)
end)
