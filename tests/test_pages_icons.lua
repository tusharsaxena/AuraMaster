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

local NOTICE = "This container is drawn as bars; these settings apply once its style is Icons (General → Containers)."

test("icons: a bars container's tabs carry the orange notice; an icons container's carry none", function()
    local NS, _, P, ws = icons()
    local notice = "|cffffa040" .. NS.L[NOTICE] .. "|r"
    assertFalse(P.hasText(ws, notice), "container 2 is drawn as icons")
    NS.Helpers.SelectContainer(1)
    ws = P.show("Icons")
    -- red under: the intro testing the style the wrong way round, or not at all
    assertTrue(P.hasText(ws, notice))
    assertTrue(P.hasText(P.tab("icons", NS.L["Highlights"]), notice), "and on the last tab")
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

test("icons: the wrong-style notice is drawn large, then a spacer before the first control (B-2)", function()
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
    local notice = "|cffffa040" .. NS.L[NOTICE] .. "|r"
    assertTrue(seen[notice] ~= nil, "the notice is a TextRow, in the orange it had")
    -- red under: the notice drawn in the default small font
    assertEqual(seen[notice] and seen[notice].fontObject, "GameFontNormalLarge")
    local kids = H.EnsureScroll(H.__pageCtx.icons).children
    local at
    for i, w in ipairs(kids) do
        if w.type == "Label" and w.text == notice then at = i end
    end
    -- red under: the notice followed straight by the first control
    assertEqual(kids[at + 1].type, "SimpleGroup")
    assertEqual(kids[at + 1].height, 12)
end)

test("icons: the six tabs are drawn in order", function()
    local NS, _, P = icons()
    local L = NS.L
    -- red under: a row landing in a group of its own (a stray seventh tab), or tabs reordered
    assertEqual(table.concat(P.tabKeys("icons"), ","), table.concat({ L["Size"], L["Border"],
        L["Cooldown"], L["Time text"], L["Stack text"], L["Highlights"] }, ","))
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

test("icons: Defaults restores the selected container's icon look and leaves its bar look alone", function()
    local NS, m = icons()
    NS.SetByPath("container.icons.width", 50, 2)
    NS.SetByPath("container.icons.time.fontSize", 20, 2)
    NS.SetByPath("container.bars.width", 300, 2)
    m.__subcategories.Icons.defaultsOnClick()
    local c2 = NS.Database.FindContainer(2)
    -- red under: the Icons Defaults reaching the Bars page's rows
    assertEqual(c2.icons.width, NS.CONTAINER_TEMPLATE.icons.width)
    assertEqual(c2.icons.time.fontSize, NS.CONTAINER_TEMPLATE.icons.time.fontSize)
    assertEqual(c2.bars.width, 300)
end)
