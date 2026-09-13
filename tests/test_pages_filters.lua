-- tests/test_pages_filters.lua — settings/Filters.lua, driven through its widgets: the rows each aura
-- type is offered, what each writes, the Categories grid (F-1), the Overrides tab (F-3), and the
-- warnings above every tab. The compiler's reading of what these rows store is
-- tests/test_filtercompiler.lua's. The spell categories' lists are profile-wide and edited on
-- General → Spell Categories (tests/test_pages_general.lua).

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

--- The Filters page's Categories tab, on container `id` (1, the player's buffs, when nil).
local function categories(id)
    local NS, m, P = filters()
    if id then
        NS.Helpers.SelectContainer(id)
        P.show("Filters")
    end
    return NS, m, P, P.tab("filters", NS.L["Categories"])
end

--- The texts of the section headings a render drew, in order.
local function headings(ws)
    local out = {}
    for _, w in ipairs(ws) do
        if w.type == "Heading" then
            out[#out + 1] = w.text
        end
    end
    return out
end

--- The grid line for category `key`: the Default, Whitelist and Blacklist cells, then the label.
local function gridLine(NS, ws, key)
    local label = NS.FindSchemaRow("container.filter.categories." .. key).label
    for _, w in ipairs(ws) do
        local kids = w.children
        local last = kids and kids[4]
        if last and last.type == "InteractiveLabel" and last.text == label then
            return kids
        end
    end
    return nil
end

--- The last chat line, or "" when nothing was printed.
local function lastLine(lines)
    local count = #lines
    return lines[count] or ""
end

--- The line an IdList drew for spell `id`: its label, and the Remove beside it.
local function entry(ws, id)
    for _, w in ipairs(ws) do
        local lbl = w.children and w.children[1]
        if lbl and lbl.type == "InteractiveLabel" then
            local t = lbl.text or ""
            if t:find("(" .. id .. ")|r", 1, true) or t == "Unknown spell " .. id then
                return lbl, w.children[2]
            end
        end
    end
    return nil
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
    -- red under: a Filters row that means nothing for enchants dropping its `auraTypes`, or the
    -- bespoke Categories tab losing its `auraTypes` (it would stand alone with no rows to draw)
    assertEqual(table.concat(P.tabKeys("filters"), ","), NS.L["What to show"] .. "," .. NS.L["Sorting"])
    assertTrue(P.row(ws, "container.filter.hidePermanentEnchants") ~= nil)
    assertNil(P.row(ws, "container.filter.castBy"))
    ws = P.tab("filters", NS.L["Sorting"])
    assertTrue(P.row(ws, "container.filter.sortDirection") ~= nil, "direction orders the enchants too")
    assertNil(P.row(ws, "container.filter.sortMethod"))
    assertNil(P.row(ws, "container.filter.maxAuras"))
end)

-- ── the Categories grid (F-1) ─────────────────────────────────────────────────────────────────

test("filters: a buff container's Categories tab is two grids, Blizzard Categories then Custom Categories, each once", function()
    local NS, _, P, ws = categories()
    local L = NS.L
    -- red under: the rows drawn by the flow engine (each subgroup heading repeats as the kinds
    -- interleave), or the grids drawn in the wrong order
    assertEqual(table.concat(headings(ws), "|"), L["Blizzard Categories"] .. "|" .. L["Custom Categories"])
    assertNil(P.find(ws, "Dropdown", NS.FindSchemaRow("container.filter.categories.defensives").label),
        "a category is a grid line, not a dropdown")
    assertTrue(gridLine(NS, ws, "defensives") ~= nil, "a custom category has a grid line")
    assertTrue(gridLine(NS, ws, "bigDefensive") ~= nil, "and a Blizzard one")
    assertNil(gridLine(NS, ws, "crowdControl"), "no debuff category on a buff container")
end)

test("filters: a debuff container's Categories tab is Blizzard Categories, Dispel Types and Who Cast It, each once", function()
    local NS, _, _, ws = categories(2)
    local L = NS.L
    -- red under: a grid key mapping dispel or who-cast-it rows into the Blizzard grid
    assertEqual(table.concat(headings(ws), "|"),
        L["Blizzard Categories"] .. "|" .. L["Dispel Types"] .. "|" .. L["Who Cast It"])
    assertTrue(gridLine(NS, ws, "magic") ~= nil)
    assertTrue(gridLine(NS, ws, "fromPlayers") ~= nil)
    assertNil(gridLine(NS, ws, "defensives"), "no buff category on a debuff container")
end)

test("filters: every grid's columns are Default, Whitelist and Blacklist, then the category", function()
    local NS, _, _, ws = categories()
    local L = NS.L
    local headers = 0
    for _, w in ipairs(ws) do
        local kids = w.children
        if kids and kids[1] and kids[1].type == "Label" and kids[1].text == L["Default"] then
            headers = headers + 1
            local got = {}
            for i, k in ipairs(kids) do got[i] = k.text end
            -- red under: CATEGORY_STATE_LABELS keeping — / Show / Hide
            assertEqual(table.concat(got, "|"),
                L["Default"] .. "|" .. L["Whitelist"] .. "|" .. L["Blacklist"] .. "|" .. L["Category"])
        end
    end
    assertEqual(headers, 2, "one header line per grid")
end)

test("filters: a grid radio stores show, hide or \"\" for the selected container and re-syncs its line", function()
    local NS, m, _, ws = categories()
    m.__subcategories.Filters:Show()   -- on screen, so a write re-syncs the widgets in place
    local cells = gridLine(NS, ws, "defensives")
    assertEqual(cells[1].checkType, "radio")
    assertTrue(cells[1].value == true, "Default is lit for a fresh container")
    cells[2]:__fire("OnValueChanged", true)
    -- red under: the columns' values out of order (the Whitelist cell storing anything but "show")
    assertEqual(NS.Database.FindContainer(1).filter.categories.defensives, "show")
    assertEqual(NS.Database.FindContainer(2).filter.categories.defensives, "", "no other container")
    cells[3]:__fire("OnValueChanged", true)
    assertEqual(NS.Database.FindContainer(1).filter.categories.defensives, "hide")
    -- red under: a cell's refresher not re-reading the row (the Whitelist cell would stay lit)
    assertTrue(cells[3].value == true and cells[2].value == false, "the line re-syncs to Blacklist")
    cells[1]:__fire("OnValueChanged", true)
    assertEqual(NS.Database.FindContainer(1).filter.categories.defensives, "")
end)

test("filters: /am get and /am list print a category's state as Default, Whitelist or Blacklist", function()
    local NS, _, P = filters()
    NS.SetByPath("container.filter.categories.defensives", "show", 1)
    local lines = P.chat()
    NS.Slash:OnSlash("get container.filter.categories.defensives")
    local got = lastLine(lines)
    -- red under: the Slash descriptor printing the stored value ("show") rather than its label
    assertTrue(got:find(NS.L["Whitelist"], 1, true) ~= nil, got)
    NS.SetByPath("container.filter.categories.defensives", "", 1)
    NS.Slash:OnSlash("get container.filter.categories.defensives")
    got = lastLine(lines)
    assertTrue(got:find(NS.L["Default"], 1, true) ~= nil, got)
    NS.Slash:OnSlash("list")
    local listed
    for _, l in ipairs(lines) do
        if l:find("container.filter.categories.stealable", 1, true) then listed = l end
    end
    assertTrue(listed ~= nil, "the category rows stay in /am list")
    assertTrue(listed:find(NS.L["Default"], 1, true) ~= nil, listed)
    NS.Slash:OnSlash("get container.filter.castBy")
    got = lastLine(lines)
    assertTrue(got:find("any", 1, true) ~= nil, "every other row prints as it always has: " .. got)
end)

test("filters: every category row is skipRender and names its grid", function()
    local NS = filters()
    local want = { spells = "custom", token = "blizzard", flag = "blizzard", dispel = "dispel" }
    for _, auraType in ipairs({ "HELPFUL", "HARMFUL" }) do
        for _, def in ipairs(NS.Categories.For(auraType)) do
            local row = NS.FindSchemaRow("container.filter.categories." .. def.key)
            -- red under: a category row losing `skipRender` (a flow-engine render of the group, as
            -- the page's Defaults reset or any future plain tab would do, draws it a dropdown too)
            assertTrue(row.skipRender == true, def.key)
            local grid = want[def.kind]
            -- red under: dropping categoryRows' isFromPlayerOrPlayerPet special case
            if def.field == "isFromPlayerOrPlayerPet" then grid = "who" end
            assertEqual(row.grid, grid, def.key)
        end
    end
end)

test("filters: no aura type is offered a Spell lists tab; the lists live on General → Spell Categories", function()
    local NS, _, P = filters()
    for _, auraType in ipairs({ "HELPFUL", "HARMFUL", "ENCHANT" }) do
        NS.SetByPath("container.auraType", auraType, 1)
        P.rerender("Filters")
        for _, k in ipairs(P.tabKeys("filters")) do
            -- red under: the Filters page still registering its spellLists tab (G-2)
            assertTrue(k ~= "spellLists", auraType .. ": " .. k)
        end
    end
end)

-- ── Overrides (F-3) ───────────────────────────────────────────────────────────────────────────

test("filters: Overrides replaces Always / never, with a Whitelist and a Blacklist section", function()
    local NS, _, P = filters()
    local keys = table.concat(P.tabKeys("filters"), ",")
    -- red under: the old alwaysNever tab still registered
    assertFalse(keys:find("alwaysNever", 1, true) ~= nil, keys)
    local ws = P.tab("filters", "overrides")
    assertEqual(table.concat(headings(ws), "|"), NS.L["Whitelist"] .. "|" .. NS.L["Blacklist"])
    assertEqual(#P.all(ws, "EditBox", NS.L["Add a spell"]), 2, "an ID input per list")
end)

test("filters: Overrides adds to one list at a time by id or by name, and Remove takes an id off", function()
    local NS, _, P = filters()
    local ws = P.tab("filters", "overrides")
    local boxes = P.all(ws, "EditBox", NS.L["Add a spell"])
    boxes[1]:__fire("OnEnterPressed", "rejuvenation")
    boxes[2]:__fire("OnEnterPressed", "12345")
    local f = NS.Database.FindContainer(1).filter
    -- red under: a known spell name not resolving to its id (no candidates handed to the IdList),
    -- or both lists written through one path
    assertEqual(f.whitelist[774], true)
    assertNil(f.whitelist[12345])
    assertEqual(f.blacklist[12345], true)
    assertNil(f.blacklist[774])
    ws = P.rerender("Filters")
    local lbl, remove = entry(ws, 774)
    assertTrue(lbl ~= nil and lbl.text:find("Rejuvenation", 1, true) ~= nil, "listed by name")
    assertTrue(entry(ws, 12345) ~= nil, "an unknown id is listed by id")
    assertEqual(remove.text, NS.L["Remove"])
    remove:__fire("OnClick")
    assertNil(next(NS.Database.FindContainer(1).filter.whitelist), "the whitelist is empty again")
    assertEqual(NS.Database.FindContainer(1).filter.blacklist[12345], true, "the blacklist is not")
end)

test("filters: an Overrides name the game cannot find adds nothing and says why on the add line", function()
    local NS, _, P = filters()
    local ws = P.tab("filters", "overrides")
    local msgs = P.messages()
    P.all(ws, "EditBox", NS.L["Add a spell"])[1]:__fire("OnEnterPressed", "No Such Spell")
    -- red under: onAdd reached with something other than a resolved id
    assertEqual(msgs.config, 0, "an unknown name writes nothing")
    assertNil(next(NS.Database.FindContainer(1).filter.whitelist or {}))
    assertTrue(P.hasText(ws, "No spell named 'No Such Spell'."))
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
