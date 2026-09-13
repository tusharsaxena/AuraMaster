-- tests/test_pages_bars.lua — settings/Bars.lua, driven through its widgets: the page's tabs, the
-- notice on a container that is not drawn as bars, what its sliders and swatches write, and its
-- Defaults. How the stored look is painted is tests/test_style.lua's.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNear =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNear
local fresh = dofile("tests/fresh_env.lua")
local pages = dofile("tests/page_helpers.lua")

local function bars(opts)
    local NS, m = fresh(opts)
    local P = pages(NS, m)
    return NS, m, P, P.show("Bars")
end

local NOTICE = "This container is drawn as icons; these settings apply once its style is Bars (General → Containers)."

test("bars: every tab of an icons container carries the orange notice; a bars container's carry none", function()
    local NS, _, P, ws = bars()
    local notice = "|cffffa040" .. NS.L[NOTICE] .. "|r"
    assertFalse(P.hasText(ws, notice), "container 1 is drawn as bars")
    NS.Helpers.SelectContainer(2)
    ws = P.show("Bars")
    -- red under: the intro testing the style the wrong way round, or not at all
    assertTrue(P.hasText(ws, notice), "the first tab")
    local keys = P.tabKeys("bars")
    local count = #keys
    for i = 2, count do
        assertTrue(P.hasText(P.tab("bars", keys[i]), notice), keys[i])
    end
end)

test("bars: the seven tabs are drawn in order, whatever the container shows", function()
    local NS, _, P = bars()
    local L = NS.L
    local want = table.concat({ L["Size"], L["Bar"], L["Background & border"], L["Name text"],
        L["Time text"], L["Stack text"], L["Highlights"] }, ",")
    assertEqual(table.concat(P.tabKeys("bars"), ","), want)
    NS.SetByPath("container.auraType", "ENCHANT", 1)
    P.rerender("Bars")
    -- red under: a Bars row declaring `auraTypes` (an enchant container drawn as bars loses it)
    assertEqual(table.concat(P.tabKeys("bars"), ","), want)
end)

test("bars: Width writes the selected container, and the page re-reads after the banner moves", function()
    local NS, _, P, ws = bars()
    local slider = P.row(ws, "container.bars.width")
    assertEqual(slider.type, "Slider")
    slider:__fire("OnMouseUp", 300)
    -- red under: the row resolving against anything but the selection
    assertEqual(NS.Database.FindContainer(1).bars.width, 300)
    assertEqual(NS.Database.FindContainer(2).bars.width, NS.CONTAINER_TEMPLATE.bars.width)
    NS.Helpers.__pageCtx.bars.__bannerWidget:__fire("OnValueChanged", 2)
    ws = P.show("Bars")
    assertEqual(P.row(ws, "container.bars.width").value, NS.CONTAINER_TEMPLATE.bars.width, "container 2's width")
end)

test("bars: a confirmed fill color is stored on the selected container, as a table of its own", function()
    local NS, _, P = bars()
    P.show("Bars")
    local ws = P.tab("bars", NS.L["Bar"])
    local cp = P.row(ws, "container.bars.barColor")
    assertEqual(cp.type, "ColorPicker")
    cp:__fire("OnValueConfirmed", 0.1, 0.2, 0.3, 0.4)
    local c = NS.Database.FindContainer(1).bars.barColor
    -- red under: the swatch writing another path, or the stored color aliasing the template's
    assertNear(c.r, 0.1)
    assertNear(c.g, 0.2)
    assertNear(c.b, 0.3)
    assertNear(c.a, 0.4)
    assertTrue(c ~= NS.CONTAINER_TEMPLATE.bars.barColor)
    assertEqual(NS.Database.FindContainer(2).bars.barColor.r, NS.CONTAINER_TEMPLATE.bars.barColor.r)
end)

test("bars: Highlights carries no dispel swatches, and Color by points at General → Dispel Colors (B-6)", function()
    local NS, _, P = bars()
    P.show("Bars")
    local ws = P.tab("bars", NS.L["Highlights"])
    -- red under: the dispel rows still registered on the Bars page (they are profile-wide, G-3)
    for _, name in ipairs(NS.Constants.DISPEL_TYPES) do
        assertEqual(NS.FindSchemaRow("dispelColors." .. name).page, "general", name)
    end
    assertEqual(#P.all(ws, "ColorPicker"), 2, "the running-out and refresh-window colors only")
    -- red under: the tooltip still sending the player to the Highlights tab
    local desc = NS.FindSchemaRow("container.bars.colorMode").desc
    assertTrue(desc:find("General → Dispel Colors", 1, true) ~= nil, desc)
end)

test("bars: Defaults restores the selected container's bar look and leaves its icon look alone", function()
    local NS, m = bars()
    NS.SetByPath("container.bars.width", 300, 1)
    NS.SetByPath("container.bars.name.fontSize", 20, 1)
    NS.SetByPath("container.icons.width", 50, 1)
    m.__subcategories.Bars.defaultsOnClick()
    local c1 = NS.Database.FindContainer(1)
    -- red under: the Bars Defaults reaching the Icons page's rows (or missing its own nested ones)
    assertEqual(c1.bars.width, NS.CONTAINER_TEMPLATE.bars.width)
    assertEqual(c1.bars.name.fontSize, NS.CONTAINER_TEMPLATE.bars.name.fontSize)
    assertEqual(c1.icons.width, 50)
end)
