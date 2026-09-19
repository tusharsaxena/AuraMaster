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

-- BATCH 8 (owner, from a screenshot): the wrong-style note was a full-width GameFontNormalLarge
-- line in warning orange, which shouted for what is a quiet aside — nothing is wrong, the page is
-- simply inert until the style changes. It is now the small default font in the addon's
-- muted notice color, reworded to lead with the condition and name the page that fixes it, and
-- followed by the ordinary row gap rather than a 12px one. Orange is left to RenderWarnings, which
-- can draw on this very page and must stay the loudest thing on it. The color was gold (B3), then
-- muted red the same day (Task 20).
local MSG = "Not in use: this container is drawn as icons. Set its Style to Bars on the Containers page to use these settings."
local NOTICE = "|c" .. T.NS.Constants.NOTICE_COLOR

test("bars: every tab of an icons container carries the muted-red note; a bars container's carry none", function()
    local NS, _, P, ws = bars()
    local notice = NOTICE .. NS.L[MSG] .. "|r"
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

test("bars: the wrong-style note is drawn small and gray, then a spacer before the first control (B-2)", function()
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
    local notice = NOTICE .. NS.L[MSG] .. "|r"
    assertTrue(seen[notice] ~= nil, "the note is a TextRow, in the color the addon reports notices in")
    -- red under: the note back in large orange, shouting over a page that is merely inert
    assertEqual(seen[notice] and seen[notice].fontObject, "GameFontHighlightSmall")
    local kids = H.EnsureScroll(H.__pageCtx.bars).children
    local at
    for i, w in ipairs(kids) do
        if w.type == "Label" and w.text == notice then at = i end
    end
    local spacer = kids[at + 1]
    -- red under: the note followed straight by the first control
    assertEqual(spacer.type, "SimpleGroup")
    assertEqual(spacer.height, H.ROW_VSPACER)
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

test("bars: the General tab's Spark subsection turns the spark off on auras without a duration (B-3)", function()
    local NS, _, P, ws = bars()
    local row = NS.FindSchemaRow("container.bars.sparkTimeless")
    -- red under: the row missing, or declared on another tab
    assertTrue(row ~= nil, "the row exists")
    assertEqual(row.group, NS.L["General"])
    assertEqual(row.subgroup, NS.L["Spark"])
    assertTrue(NS.CONTAINER_TEMPLATE.bars.sparkTimeless == true, "on by default: today's look")
    -- General is the first (and default-active) tab, so it is drawn by bars()'s own show.
    P.row(ws, "container.bars.sparkTimeless"):__fire("OnValueChanged", false)
    assertFalse(NS.Database.FindContainer(1).bars.sparkTimeless)
end)

test("bars: the seven tabs are drawn in order, whatever the container shows (S-1: Size folded into General)", function()
    local NS, _, P = bars()
    local L = NS.L
    -- red under: Size still a tab of its own, or the icon rows registered after Background & border
    local want = table.concat({ L["General"], L["Icon"], L["Background & border"], L["Name text"],
        L["Time text"], L["Stack text"], L["Pandemic"] }, ",")
    assertEqual(table.concat(P.tabKeys("bars"), ","), want)
    NS.SetByPath("container.auraType", "HARMFUL", 1)
    P.rerender("Bars")
    -- red under: a Bars row declaring `auraTypes` (a debuff container drawn as bars loses it)
    assertEqual(table.concat(P.tabKeys("bars"), ","), want)
end)

test("bars: General opens on Size (Width, Height) ahead of Fill, with paths unchanged (S-1)", function()
    local NS, _, P, ws = bars()
    local L = NS.L
    local pre = "container.bars."
    -- General is the first (and default-active) tab, so it is drawn by bars()'s own show.
    local rows = P.rowWidgets(ws, "bars", L["General"])
    assertTrue(rows[1] ~= nil, "the General tab drew rows")
    -- Width and Height render first, ahead of Fill's first control.
    assertEqual(rows[1].labelText, NS.FindSchemaRow(pre .. "width").label)
    assertEqual(rows[2].labelText, NS.FindSchemaRow(pre .. "height").label)
    -- red under: the row moved and its stored path changed with it
    assertEqual(NS.FindSchemaRow(pre .. "width").subgroup, L["Size"])
    assertEqual(NS.FindSchemaRow(pre .. "height").subgroup, L["Size"])
    local slider = P.row(ws, pre .. "width")
    slider:__fire("OnMouseUp", 250)
    assertEqual(NS.Database.FindContainer(1).bars.width, 250)
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
    -- General is the first (and default-active) tab, so it is drawn by bars()'s own show.
    local NS, _, P, ws = bars()
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

test("bars: Pandemic carries no dispel swatches, and Color by points at General -> Dispel Colors (B-6)", function()
    local NS, _, P = bars()
    P.show("Bars")
    local ws = P.tab("bars", NS.L["Pandemic"])
    -- red under: the dispel rows still registered on the Bars page (they are profile-wide, G-3)
    for _, name in ipairs(NS.Constants.DISPEL_TYPES) do
        assertEqual(NS.FindSchemaRow("dispelColors." .. name).page, "general", name)
    end
    assertEqual(#P.all(ws, "ColorPicker"), 2, "the pandemic-window time and highlight colors only")
    -- red under: the tooltip sending the player to a tab rather than General -> Dispel Colors
    local desc = NS.FindSchemaRow("container.bars.colorMode").desc
    assertTrue(desc:find("General -> Dispel Colors", 1, true) ~= nil, desc)
    -- red under: the tooltip implying a typeless debuff is rare, citing Mystic Touch alone (feedback #7,
    -- smoke batch 2 item 2: many class debuffs have no dispel type)
    assertTrue(desc:find("many debuffs have no dispel type", 1, true) ~= nil, desc)
    assertTrue(desc:find("Judgment or Consecration", 1, true) ~= nil, desc)
end)

-- ── Pandemic (smoke batch 2, B2-1) ────────────────────────────────────────────────────────────
-- The owner's call: "Running out" (the seconds-left time color) and "Refresh window" (the engine's
-- wash) are both named for the pandemic window, on a tab of their own. Labels only: the paths and
-- stored values are unchanged, so no migration.
local PANDEMIC = {
    { "expiringColorOn", "Time color", "Recolor the time in the pandemic window" },
    { "expiringThreshold", "Time color", "Pandemic window (seconds left)" },
    { "expiringColor", "Time color", "Pandemic-window time color" },
    { "pandemic", "Highlight", "Highlight the pandemic window" },
    { "pandemicColor", "Highlight", "Pandemic-window highlight color" },
}

test("bars: the Pandemic tab holds the time color and the highlight, in pandemic-window words, paths unchanged (B2-1)", function()
    local NS, _, P = bars()
    local want, keys = {}, P.tabKeys("bars")
    for _, k in ipairs(keys) do
        -- red under: the old tab still drawn beside the new one
        assertTrue(k ~= "Highlights", "no Highlights tab")
    end
    local ws = P.tab("bars", "Pandemic")
    for i, spec in ipairs(PANDEMIC) do
        local row = NS.FindSchemaRow("container.bars." .. spec[1])
        -- red under: the row still on Highlights, under Running out / Refresh window, or its old label
        assertEqual(row.group, "Pandemic", spec[1])
        assertEqual(row.subgroup, spec[2], spec[1])
        assertEqual(row.label, spec[3], spec[1])
        local text = (row.label .. " " .. (row.desc or row.tooltip or "")):lower()
        assertTrue(not text:find("running out", 1, true) and not text:find("refresh window", 1, true)
            and not text:find("running-out", 1, true) and not text:find("refresh-window", 1, true), spec[1])
        want[i] = spec[3]
    end
    local got = {}
    for i, w in ipairs(P.rowWidgets(ws, "bars", "Pandemic")) do got[i] = w.labelText end
    assertEqual(table.concat(got, "|"), table.concat(want, "|"), "drawn in order on the Pandemic tab")
    assertTrue(P.find(ws, "Heading", "Time color") ~= nil, "the time color subsection")
    assertTrue(P.find(ws, "Heading", "Highlight") ~= nil, "the highlight subsection")
    -- red under: a moved row writing a renamed path
    P.row(ws, "container.bars.expiringThreshold"):__fire("OnMouseUp", 7)
    assertEqual(NS.Database.FindContainer(1).bars.expiringThreshold, 7)
end)

test("bars: Background & border offers Color by beside the background, writing bgColorMode (feedback #7)", function()
    local NS, _, P = bars()
    P.show("Bars")
    local ws = P.tab("bars", NS.L["Background & border"])
    local row = NS.FindSchemaRow("container.bars.bgColorMode")
    -- red under: no bgColorMode row
    assertTrue(row ~= nil and row.subgroup == NS.L["Background"], "a Background row")
    local dd
    for _, w in ipairs(P.rowWidgets(ws, "bars", NS.L["Background & border"])) do
        if w.type == "Dropdown" and w.labelText == row.label then dd = w end
    end
    assertTrue(dd ~= nil, "drawn on the tab")
    assertEqual(table.concat(dd.order, ","), "static,dispel")
    dd:__fire("OnValueChanged", "dispel")
    assertEqual(NS.Database.FindContainer(1).bars.bgColorMode, "dispel")
    local tip = row.tooltip or row.desc
    assertTrue(tip:find("many debuffs have no dispel type", 1, true) ~= nil, "the tooltip says typeless debuffs are common")
    assertTrue(tip:find("Judgment or Consecration", 1, true) ~= nil, tip)
    assertEqual(NS.CONTAINER_TEMPLATE.bars.bgColorMode, "static", "one color by default")
end)

test("pages: every Border style row says Solid redraws at once and another texture after a /reload (B2-3)", function()
    local NS = T.NS
    local tip = NS.L["The border texture. Solid redraws at once; any other texture, and a new thickness for one, reaches the aura buttons already on screen after a /reload."]
    for _, path in ipairs({ "container.bars.borderStyle", "container.bars.iconBorderStyle",
        "container.icons.borderStyle", "container.text.iconBorderStyle" }) do
        local row = NS.FindSchemaRow(path)
        -- red under: the library's own "The border texture." (a live button keeps its old backdrop
        -- until a rebuild, modules/Style.lua's ApplyBorder, and nothing said so)
        assertEqual(row and (row.tooltip or row.desc), tip, path)
    end
end)

test("bars: Defaults restores the selected container's bar look and leaves its icon look alone", function()
    local NS, _ = bars()
    NS.SetByPath("container.bars.width", 300, 1)
    NS.SetByPath("container.bars.name.fontSize", 20, 1)
    NS.SetByPath("container.icons.width", 50, 1)
    NS.Helpers.__pageCtx.bars.panel.defaultsOnClick()
    local c1 = NS.Database.FindContainer(1)
    -- red under: the Bars Defaults reaching the Icons page's rows (or missing its own nested ones)
    assertEqual(c1.bars.width, NS.CONTAINER_TEMPLATE.bars.width)
    assertEqual(c1.bars.name.fontSize, NS.CONTAINER_TEMPLATE.bars.name.fontSize)
    assertEqual(c1.icons.width, 50)
end)
