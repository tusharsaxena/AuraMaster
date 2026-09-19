-- tests/test_pages_icons.lua — settings/Icons.lua, driven through its widgets: the page's tabs, the
-- notice on a container that is not drawn as icons, what its rows write, and its Defaults.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNear =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNear
local fresh = dofile("tests/fresh_env.lua")
local pages = dofile("tests/page_helpers.lua")

--- The Icons page, drawn for container 2 (the starter icon row).
local function icons(opts)
    local NS, m = fresh(opts)
    local P = pages(NS, m)
    NS.State.SetActiveContainer(2)
    return NS, m, P, P.show("Icons")
end

-- BATCH 8 (owner, from a screenshot): the wrong-style note was a full-width GameFontNormalLarge
-- line in warning orange, which shouted for what is a quiet aside — nothing is wrong, the page is
-- simply inert until the style changes. It is now the small default font in the addon's
-- muted notice color, reworded to lead with the condition and name the page that fixes it, and
-- followed by the ordinary row gap rather than a 12px one. Orange is left to RenderWarnings, which
-- can draw on this very page and must stay the loudest thing on it. The color was gold (B3), then
-- muted red the same day (Task 20).
local MSG = "Not in use: this container is drawn as bars. Set its Style to Icons on the Containers page to use these settings."
local NOTICE = "|c" .. T.NS.Constants.NOTICE_COLOR

test("icons: a bars container's tabs carry the muted-red note; an icons container's carry none", function()
    local NS, _, P, ws = icons()
    local notice = NOTICE .. NS.L[MSG] .. "|r"
    assertFalse(P.hasText(ws, notice), "container 2 is drawn as icons")
    NS.Helpers.SelectContainer(1)
    ws = P.show("Icons")
    -- red under: the intro testing the style the wrong way round, or not at all
    assertTrue(P.hasText(ws, notice))
    assertTrue(P.hasText(P.tab("icons", NS.L["Pandemic"]), notice), "and on the last tab")
end)

test("icons: on a bars container every row of every tab is drawn disabled; on an icons container none is (B-2)", function()
    local NS, _, P = icons()
    NS.Helpers.SelectContainer(1)
    P.eachTab("Icons", "icons", function(key, ws)
        local rows = P.rowWidgets(ws, "icons", key)
        assertTrue(rows[1] ~= nil, key .. " drew its rows")
        for _, w in ipairs(rows) do
            -- red under: the Icons spec without disabledFor
            assertTrue(w.disabled, key .. ": " .. w.labelText)
        end
    end)
    NS.Helpers.SelectContainer(2)
    P.eachTab("Icons", "icons", function(key, ws)
        for _, w in ipairs(P.rowWidgets(ws, "icons", key)) do
            -- red under: disabledFor testing the style the wrong way round
            assertFalse(w.disabled, key .. ": " .. w.labelText)
        end
    end)
end)

test("icons: the wrong-style note is drawn small and gray, then a spacer before the first control (B-2)", function()
    local NS, _, P = icons()
    local H = NS.Helpers
    local seen = {}
    local textRow = H.TextRow
    H.TextRow = function(ctx, text, opts)
        seen[text] = opts or false
        return textRow(ctx, text, opts)
    end
    H.SelectContainer(1)
    P.show("Icons")
    H.TextRow = textRow
    local notice = NOTICE .. NS.L[MSG] .. "|r"
    assertTrue(seen[notice] ~= nil, "the note is a TextRow, in the color the addon reports notices in")
    -- red under: the note back in large orange, shouting over a page that is merely inert
    assertEqual(seen[notice] and seen[notice].fontObject, "GameFontHighlightSmall")
    local kids = H.EnsureScroll(H.__pageCtx.icons).children
    local at
    for i, w in ipairs(kids) do
        if w.type == "Label" and w.text == notice then at = i end
    end
    -- red under: the note followed straight by the first control
    assertEqual(kids[at + 1].type, "SimpleGroup")
    assertEqual(kids[at + 1].height, NS.Helpers.ROW_VSPACER)
end)

test("icons: the six tabs are drawn in order", function()
    local NS, _, P = icons()
    local L = NS.L
    -- red under: a row landing in a group of its own (a stray seventh tab), or tabs reordered
    assertEqual(table.concat(P.tabKeys("icons"), ","), table.concat({ L["Size"], L["Border"],
        L["Cooldown"], L["Time text"], L["Stack text"], L["Pandemic"] }, ","))
end)

test("icons: Width on the Icons page writes the icon width, never the bar width", function()
    local NS, _, P, ws = icons()
    P.row(ws, "container.icons.width"):__fire("OnMouseUp", 40)
    local c2 = NS.Database.FindContainer(2)
    -- red under: an Icons row built on the Bars prefix
    assertEqual(c2.icons.width, 40)
    assertEqual(c2.bars.width, NS.CONTAINER_TEMPLATE.bars.width)
    assertEqual(NS.Database.FindContainer(3).icons.width, NS.CONTAINER_TEMPLATE.icons.width)
end)

test("icons: the Cooldown rows write the selected container's swipe", function()
    local NS, _, P = icons()
    local ws = P.tab("icons", NS.L["Cooldown"])
    P.row(ws, "container.icons.cooldown"):__fire("OnValueChanged", false)
    local swipe = P.row(ws, "container.icons.swipeAlpha")
    assertTrue(swipe.isPercent, "darkness reads as a percentage")
    swipe:__fire("OnMouseUp", 0.3)
    local c2 = NS.Database.FindContainer(2)
    -- red under: a Cooldown row pointing at another leaf
    assertFalse(c2.icons.cooldown)
    assertNear(c2.icons.swipeAlpha, 0.3)
end)

-- ── Pandemic (smoke batch 2, B2-1) ────────────────────────────────────────────────────────────
-- As on the Bars page: the time color and the highlight are both named for the pandemic window, on
-- a tab of their own that replaces Highlights. Labels only; paths and stored values unchanged.
local PANDEMIC = {
    { "expiringColorOn", "Time color", "Recolor the time in the pandemic window" },
    { "expiringThreshold", "Time color", "Pandemic window (seconds left)" },
    { "expiringColor", "Time color", "Pandemic-window time color" },
    { "pandemic", "Highlight", "Highlight the pandemic window" },
    { "pandemicColor", "Highlight", "Pandemic-window highlight color" },
}

test("icons: the Pandemic tab holds the time color and the highlight, in pandemic-window words, paths unchanged (B2-1)", function()
    local NS, _, P = icons()
    for _, k in ipairs(P.tabKeys("icons")) do
        -- red under: the old tab still drawn beside the new one
        assertTrue(k ~= "Highlights", "no Highlights tab")
    end
    local ws = P.tab("icons", "Pandemic")
    local want = {}
    for i, spec in ipairs(PANDEMIC) do
        local row = NS.FindSchemaRow("container.icons." .. spec[1])
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
    for i, w in ipairs(P.rowWidgets(ws, "icons", "Pandemic")) do got[i] = w.labelText end
    assertEqual(table.concat(got, "|"), table.concat(want, "|"), "drawn in order on the Pandemic tab")
    assertTrue(P.find(ws, "Heading", "Time color") ~= nil, "the time color subsection")
    assertTrue(P.find(ws, "Heading", "Highlight") ~= nil, "the highlight subsection")
    -- red under: a moved row writing a renamed path
    P.row(ws, "container.icons.expiringThreshold"):__fire("OnMouseUp", 9)
    assertEqual(NS.Database.FindContainer(2).icons.expiringThreshold, 9)
end)

test("icons: Defaults restores the selected container's icon look and leaves its bar look alone", function()
    local NS, _ = icons()
    NS.SetByPath("container.icons.width", 50, 2)
    NS.SetByPath("container.icons.time.fontSize", 20, 2)
    NS.SetByPath("container.bars.width", 300, 2)
    NS.Helpers.__pageCtx.icons.panel.defaultsOnClick()
    local c2 = NS.Database.FindContainer(2)
    -- red under: the Icons Defaults reaching the Bars page's rows
    assertEqual(c2.icons.width, NS.CONTAINER_TEMPLATE.icons.width)
    assertEqual(c2.icons.time.fontSize, NS.CONTAINER_TEMPLATE.icons.time.fontSize)
    assertEqual(c2.bars.width, 300)
end)
