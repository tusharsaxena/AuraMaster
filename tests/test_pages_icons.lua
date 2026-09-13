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
