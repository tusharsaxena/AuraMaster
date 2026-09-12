-- tests/test_pages_filters.lua — settings/Filters.lua, driven through its widgets: the rows each aura
-- type is offered, what each writes, the two bespoke spell-set tabs, and the warnings above every
-- tab. The compiler's reading of what these rows store is tests/test_filtercompiler.lua's.

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

--- The checkbox a spell-list render drew for spell `id` (its label is the spell's text).
local function spellBox(P, ws, id)
    for _, w in ipairs(P.all(ws, "CheckBox")) do
        local l = w.labelText or ""
        if l:find("(" .. id .. ")|r", 1, true) or l:find("Unknown spell " .. id .. "|r", 1, true) then return w end
    end
    return nil
end

local function starterIds(NS, key)
    local out = {}
    for id in pairs(NS.Categories.Find("HELPFUL", key).spells) do
        out[#out + 1] = id
    end
    table.sort(out)
    return out
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

test("filters: Spell lists opens on the first spell category, every starter spell ticked", function()
    local NS, _, P = filters()
    P.show("Filters")
    local ws = P.tab("filters", "spellLists")
    local cat = P.find(ws, "Dropdown", NS.L["Category"])
    assertEqual(cat.value, "defensives")
    assertEqual(cat.order[1], "defensives")
    for _, k in ipairs(cat.order) do
        assertTrue(NS.Categories.IsSpellCategory(k), "only spell categories are offered: " .. k)
    end
    local want = starterIds(NS, "defensives")
    assertEqual(#P.all(ws, "CheckBox"), #want, "one box per starter spell")
    for _, id in ipairs(want) do
        local cb = spellBox(P, ws, id)
        assertTrue(cb ~= nil and cb.value == true, "starter spell ticked: " .. id)
    end
end)

test("filters: choosing another category lists its spells, by name where the client knows them", function()
    local NS, _, P = filters()
    P.show("Filters")
    local ws = P.tab("filters", "spellLists")
    P.find(ws, "Dropdown", NS.L["Category"]):__fire("OnValueChanged", "coreHealing")
    -- red under: the category dropdown not keeping its choice across the re-render it asks for
    ws = P.rerender("Filters")
    assertEqual(P.find(ws, "Dropdown", NS.L["Category"]).value, "coreHealing")
    local rejuv = spellBox(P, ws, 774)
    assertTrue(rejuv ~= nil, "Rejuvenation is a core healing buff")
    assertTrue(rejuv.labelText:find("Rejuvenation", 1, true) ~= nil, rejuv.labelText)
    assertTrue(spellBox(P, ws, 8936).labelText:find("Unknown spell 8936", 1, true) ~= nil,
        "a spell the client does not know is shown by id")
end)

test("filters: Add spell ID adds the number typed and ignores a box without one", function()
    local NS, _, P = filters()
    P.show("Filters")
    local ws = P.tab("filters", "spellLists")
    local msgs = P.messages()
    local box = P.find(ws, "EditBox", NS.L["Add spell ID"])
    box:__fire("OnEnterPressed", "no digits")
    box:__fire("OnEnterPressed", "0")
    -- red under: addBox committing without a positive id
    assertEqual(msgs.config, 0, "nothing written")
    box:__fire("OnEnterPressed", " 424242x")
    assertEqual(NS.Database.FindContainer(1).filter.categorySpells.defensives[424242], true)
    ws = P.rerender("Filters")
    local added = spellBox(P, ws, 424242)
    assertTrue(added ~= nil and added.value == true, "the added spell is listed, ticked")
    added:__fire("OnValueChanged", false)
    assertNil(NS.Database.FindContainer(1).filter.categorySpells.defensives, "unticking an added spell removes it")
end)

test("filters: Restore this category's starter list clears that category's edits and no other's", function()
    local NS, _, P = filters()
    NS.SetByPath("container.filter.categorySpells",
        { defensives = { [118038] = false }, raidCDs = { [99] = true } }, 1)
    P.show("Filters")
    local ws = P.tab("filters", "spellLists")
    P.find(ws, "Button", NS.L["Restore this category's starter list"]):__fire("OnClick")
    local edits = NS.Database.FindContainer(1).filter.categorySpells
    -- red under: the restore writing an empty set for every category
    assertNil(edits.defensives)
    assertEqual(edits.raidCDs[99], true)
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
