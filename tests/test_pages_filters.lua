-- tests/test_pages_filters.lua — settings/Filters.lua, driven through its widgets: the rows each aura
-- type is offered, what each writes, the bespoke Always / never tab, and the warnings above every
-- tab. The compiler's reading of what these rows store is tests/test_filtercompiler.lua's. The spell
-- categories' lists are profile-wide and edited on General → Spell Categories
-- (tests/test_pages_general.lua).

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local pages = dofile("tests/page_helpers.lua")

local function filters(opts)
    local NS, m = fresh(opts)
    local P = pages(NS, m)
    return NS, m, P, P.show("Filters")
end

test("filters: Cast by writes the selected container's filter and no other", function()
    local NS, _, P, ws = filters()
    local dd = P.row(ws, "container.filter.castBy")
    assertEqual(table.concat(dd.order, ","), "any,mine,others")
    dd:__fire("OnValueChanged", "others")
    -- red under: the row resolving against anything but the selection
    assertEqual(NS.Database.FindContainer(1).filter.castBy, "others")
    assertEqual(NS.Database.FindContainer(2).filter.castBy, "any")
end)

test("filters: a buff container is offered the weapon-enchant rows; a debuff container is not", function()
    local NS, _, P, ws = filters()
    assertTrue(P.row(ws, "container.filter.includeEnchants") ~= nil, "a buff container offers enchants")
    P.row(ws, "container.filter.includeEnchants"):__fire("OnValueChanged", false)
    assertFalse(NS.Database.FindContainer(1).filter.includeEnchants)
    NS.Helpers.SelectContainer(2)
    ws = P.show("Filters")
    -- red under: the enchant rows losing their `auraTypes` (a debuff container can show no enchant)
    assertNil(P.row(ws, "container.filter.includeEnchants"))
    assertNil(P.row(ws, "container.filter.hidePermanentEnchants"))
    assertTrue(P.row(ws, "container.filter.castBy") ~= nil, "the debuff container keeps Cast by")
end)

test("filters: a weapon-enchant container is offered one row on each of two tabs and no spell tabs", function()
    local NS, _, P = filters()
    NS.SetByPath("container.auraType", "ENCHANT", 1)
    local ws = P.rerender("Filters")
    -- red under: a Filters row that means nothing for enchants dropping its `auraTypes`
    assertEqual(table.concat(P.tabKeys("filters"), ","), NS.L["What to show"] .. "," .. NS.L["Sorting"])
    assertTrue(P.row(ws, "container.filter.hidePermanentEnchants") ~= nil)
    assertNil(P.row(ws, "container.filter.castBy"))
    ws = P.tab("filters", NS.L["Sorting"])
    assertTrue(P.row(ws, "container.filter.sortDirection") ~= nil, "direction orders the enchants too")
    assertNil(P.row(ws, "container.filter.sortMethod"))
    assertNil(P.row(ws, "container.filter.maxAuras"))
end)

test("filters: a category dropdown stores show, hide or neutral for the selected container", function()
    local NS, _, P = filters()
    P.show("Filters")
    local ws = P.tab("filters", NS.L["Categories"])
    local dd = P.row(ws, "container.filter.categories.defensives")
    assertEqual(dd.type, "Dropdown")
    assertEqual(table.concat(dd.order, "|"), "|show|hide", "neutral, Show, Hide")
    dd:__fire("OnValueChanged", "hide")
    -- red under: a category row's path not ending in its category key
    assertEqual(NS.Database.FindContainer(1).filter.categories.defensives, "hide")
    dd:__fire("OnValueChanged", "")
    assertEqual(NS.Database.FindContainer(1).filter.categories.defensives, "")
    assertNil(P.row(ws, "container.filter.categories.crowdControl"), "no debuff category on a buff container")
end)

test("filters: each category row sits under the subgroup its kind names", function()
    local NS = filters()
    local L = NS.L
    local function sub(key) return NS.FindSchemaRow("container.filter.categories." .. key).subgroup end
    assertEqual(sub("defensives"), L["Spell lists"])
    assertEqual(sub("bigDefensive"), L["Blizzard flags"], "a token")
    assertEqual(sub("stealable"), L["Blizzard flags"], "a flag")
    assertEqual(sub("magic"), L["Dispel types"])
    -- red under: dropping categoryRows' isFromPlayerOrPlayerPet special case
    assertEqual(sub("fromPlayers"), L["Who cast it"])
    assertEqual(sub("fromNonPlayers"), L["Who cast it"])
    assertEqual(sub("boss"), L["Blizzard flags"], "every other flag stays a Blizzard flag")
end)

test("filters: no aura type is offered a Spell lists tab; the lists live on General → Spell Categories", function()
    local NS, _, P = filters()
    for _, auraType in ipairs({ "HELPFUL", "HARMFUL", "ENCHANT" }) do
        NS.SetByPath("container.auraType", auraType, 1)
        P.rerender("Filters")
        for _, k in ipairs(P.tabKeys("filters")) do
            -- red under: the Filters page still registering its spellLists tab (G-2)
            assertTrue(k ~= "spellLists" and k ~= NS.L["Spell lists"], auraType .. ": " .. k)
        end
    end
end)

test("filters: Always / never adds to one list at a time, and Remove takes an id off", function()
    local NS, _, P = filters()
    P.show("Filters")
    local ws = P.tab("filters", "alwaysNever")
    local boxes = P.all(ws, "EditBox", NS.L["Add spell ID"])
    assertEqual(#boxes, 2, "an add box per list")
    boxes[1]:__fire("OnEnterPressed", "774")
    boxes[2]:__fire("OnEnterPressed", "12345")
    local f = NS.Database.FindContainer(1).filter
    -- red under: renderIdSet writing both lists through one path
    assertEqual(f.whitelist[774], true)
    assertNil(f.whitelist[12345])
    assertEqual(f.blacklist[12345], true)
    assertNil(f.blacklist[774])
    ws = P.rerender("Filters")
    assertTrue(P.hasText(ws, "Rejuvenation"), "the list shows what is on it")
    local removes = P.all(ws, "Button", NS.L["Remove"])
    assertEqual(#removes, 2)
    removes[1]:__fire("OnClick")
    assertNil(next(NS.Database.FindContainer(1).filter.whitelist), "the always list is empty again")
    assertEqual(NS.Database.FindContainer(1).filter.blacklist[12345], true, "the never list is not")
end)

test("filters: every tab opens with what the engine will not honor here, in orange", function()
    local NS, _, P = filters()
    local warning = "|cffffa040" .. NS.L[NS.FilterCompiler.WARN.ENCHANT_UNIT] .. "|r"
    local ws = P.rerender("Filters")
    assertFalse(P.hasText(ws, "|cffffa040"), "a container the engine honors whole has no warning")
    NS.SetByPath("container.auraType", "ENCHANT", 1)
    NS.SetByPath("container.unit", "target", 1)
    ws = P.rerender("Filters")
    -- red under: the page's intro not calling RenderWarnings
    assertTrue(P.hasText(ws, warning), "What to show")
    ws = P.tab("filters", NS.L["Sorting"])
    assertTrue(P.hasText(ws, warning), "and every other tab")
end)
