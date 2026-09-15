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

local NOTICE = "This container is drawn as icons; these settings apply once its style is Bars (General -> Containers)."

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

test("bars: on an icons container every row of every tab is drawn disabled; on a bars container none is (B-2)", function()
    local NS, _, P = bars()
    NS.Helpers.SelectContainer(2)
    P.eachTab("Bars", "bars", function(key, ws)
        local rows = P.rowWidgets(ws, "bars", key)
        assertTrue(rows[1] ~= nil, key .. " drew its rows")
        for _, w in ipairs(rows) do
            -- red under: renderActiveTab dropping spec.disabledFor (opts.disabled never reaches RenderRows)
            assertTrue(w.disabled, key .. ": " .. w.labelText)
        end
    end)
    NS.Helpers.SelectContainer(1)
    P.eachTab("Bars", "bars", function(key, ws)
        for _, w in ipairs(P.rowWidgets(ws, "bars", key)) do
            -- red under: disabledFor testing the style the wrong way round
            assertFalse(w.disabled, key .. ": " .. w.labelText)
        end
    end)
end)

test("bars: the wrong-style notice is drawn large, then a spacer before the first control (B-2)", function()
    local NS, _, P = bars()
    local H = NS.Helpers
    local seen = {}
    local textRow = H.TextRow
    H.TextRow = function(ctx, text, opts)
        seen[text] = opts or false
        return textRow(ctx, text, opts)
    end
    H.SelectContainer(2)
    P.show("Bars")
    H.TextRow = textRow
    local notice = "|cffffa040" .. NS.L[NOTICE] .. "|r"
    assertTrue(seen[notice] ~= nil, "the notice is a TextRow, in the orange it had")
    -- red under: the notice drawn in the default small font
    assertEqual(seen[notice] and seen[notice].fontObject, "GameFontNormalLarge")
    local kids = H.EnsureScroll(H.__pageCtx.bars).children
    local at
    for i, w in ipairs(kids) do
        if w.type == "Label" and w.text == notice then at = i end
    end
    local spacer = kids[at + 1]
    -- red under: the notice followed straight by the first control
    assertEqual(spacer.type, "SimpleGroup")
    assertEqual(spacer.height, 12)
end)

test("bars: the Icon tab holds the icon's four rows, then the composed icon-border block (B-1)", function()
    local NS, _, P = bars()
    local L = NS.L
    local pre = "container.bars."
    local paths = {}
    for _, row in ipairs(NS.SchemaForPage("bars")) do
        if row.group == L["Icon"] then
            paths[#paths + 1] = row.path
        end
    end
    -- red under: the icon rows left on Size, or H.BorderGroup without its keys map (it would claim
    -- the bar border's own leaves)
    assertEqual(table.concat(paths, ","), table.concat({ pre .. "icon", pre .. "iconSize", pre .. "iconGap",
        pre .. "iconZoom", pre .. "iconBorderShow", pre .. "iconBorderStyle", pre .. "iconBorderSize",
        pre .. "iconBorderColor", pre .. "useClassColorIconBorder" }, ","))
    assertEqual(NS.FindSchemaRow(pre .. "iconBorderShow").subgroup, L["Icon border"])
    assertEqual(NS.FindSchemaRow(pre .. "iconBorderColor").classColorSource, "unit", "the tracked unit's class")
    local ws = P.tab("bars", L["Icon"])
    P.find(ws, "Slider", NS.FindSchemaRow(pre .. "iconBorderSize").label):__fire("OnMouseUp", 4)
    local b = NS.Database.FindContainer(1).bars
    -- red under: the thickness slider writing the bar border's borderSize
    assertEqual(b.iconBorderSize, 4)
    assertEqual(b.borderSize, NS.CONTAINER_TEMPLATE.bars.borderSize)
end)

test("bars: the Bar tab's Spark subsection turns the spark off on auras without a duration (B-3)", function()
    local NS, _, P = bars()
    local row = NS.FindSchemaRow("container.bars.sparkTimeless")
    -- red under: the row missing, or declared on another tab
    assertTrue(row ~= nil, "the row exists")
    assertEqual(row.group, NS.L["Bar"])
    assertEqual(row.subgroup, NS.L["Spark"])
    assertTrue(NS.CONTAINER_TEMPLATE.bars.sparkTimeless == true, "on by default: today's look")
    P.row(P.tab("bars", NS.L["Bar"]), "container.bars.sparkTimeless"):__fire("OnValueChanged", false)
    assertFalse(NS.Database.FindContainer(1).bars.sparkTimeless)
end)

test("bars: the eight tabs are drawn in order, whatever the container shows", function()
    local NS, _, P = bars()
    local L = NS.L
    -- red under: the icon rows left on Size, or registered after Background & border
    local want = table.concat({ L["Size"], L["Bar"], L["Icon"], L["Background & border"], L["Name text"],
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

test("bars: Highlights carries no dispel swatches, and Color by points at General -> Dispel Colors (B-6)", function()
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
    assertTrue(desc:find("General -> Dispel Colors", 1, true) ~= nil, desc)
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
