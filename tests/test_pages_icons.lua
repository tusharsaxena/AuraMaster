-- tests/test_pages_icons.lua — settings/Icons.lua, driven through its widgets: the section's tabs,
-- what its rows write, and its Defaults.

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
