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

--- The grid line for category `key`: the Show and Hide cells, then the label (schema v3).
local function gridLine(NS, ws, key)
    local label = NS.FindSchemaRow("container.filter.categories." .. key).label
    for _, w in ipairs(ws) do
        local kids = w.children
        local last = kids and kids[3]
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

test("filters: a buff container's Categories tab offers the weapon-enchant rows; a debuff container's does not", function()
    local NS, _, P = filters()
    local ws = P.tab("filters", NS.L["Categories"])
    assertTrue(gridLine(NS, ws, "weaponEnchants") ~= nil, "a buff container offers the enchant category")
    local cb = P.row(ws, "container.filter.hidePermanentEnchants")
    assertTrue(cb ~= nil, "and the hide-permanent row")
    -- red under: hidePermanentEnchants back on a `grid` — a ChoiceGrid radio lights by comparing
    -- the stored value against a column's "show"/"hide" string, which a bool can never match, so it
    -- would draw as an always-unlit pair of radios rather than the checkbox this row actually is
    assertEqual(cb.type, "CheckBox", "a plain bool row, not a grid cell")
    cb:__fire("OnValueChanged", false)
    local stored = NS.Database.FindContainer(1).filter.hidePermanentEnchants
    -- red under: the same mutation — a grid cell's click would write the STRING "hide" here
    assertEqual(stored, false)
    assertEqual(type(stored), "boolean", "a boolean, not a grid cell's stored string")
    NS.Helpers.SelectContainer(2)
    ws = P.rerender("Filters")
    -- red under: the enchant rows losing their `auraTypes` (a debuff container can show no enchant)
    assertNil(gridLine(NS, ws, "weaponEnchants"))
    assertNil(P.row(ws, "container.filter.hidePermanentEnchants"))
    assertTrue(gridLine(NS, ws, "defensives") == nil, "no buff category either")
    assertTrue(gridLine(NS, ws, "magic") ~= nil, "the debuff container keeps its own categories")
end)

test("filters: a weapon-enchant container's hide-permanent row is a checkbox too, and stores a boolean", function()
    local NS, _, P = filters()
    NS.SetByPath("container.auraType", "ENCHANT", 1)
    local ws = P.rerender("Filters")
    local cb = P.row(ws, "container.filter.hidePermanentEnchants")
    -- red under: hidePermanentEnchants back on a `grid` — a weapon-enchant container reaches the
    -- Categories tab too (its own auraTypes now includes ENCHANT), so the same bug would hit it
    assertEqual(cb.type, "CheckBox")
    cb:__fire("OnValueChanged", true)
    local stored = NS.Database.FindContainer(1).filter.hidePermanentEnchants
    assertEqual(stored, true)
    assertEqual(type(stored), "boolean")
end)

test("filters: a weapon-enchant container is offered one row on each of two tabs and no spell tabs", function()
    local NS, _, P = filters()
    NS.SetByPath("container.auraType", "ENCHANT", 1)
    local ws = P.rerender("Filters")
    -- red under: a Filters row that means nothing for enchants dropping its `auraTypes`, or the
    -- bespoke Categories tab losing its `auraTypes` (it would stand alone with no rows to draw).
    -- "What to show" has none of its own rows for an enchant container now that hidePermanentEnchants
    -- lives in Categories, so it drops out and Categories takes its place.
    assertEqual(table.concat(P.tabKeys("filters"), ","), NS.L["Categories"] .. "," .. NS.L["Sorting"])
    assertTrue(P.row(ws, "container.filter.hidePermanentEnchants") ~= nil)
    assertNil(P.row(ws, "container.filter.castBy"))
    ws = P.tab("filters", NS.L["Sorting"])
    assertTrue(P.row(ws, "container.filter.sortDirection") ~= nil, "direction orders the enchants too")
    assertNil(P.row(ws, "container.filter.sortMethod"))
    assertNil(P.row(ws, "container.filter.maxAuras"))
end)

test("filters: the max-auras description tells the truth about a group being per-shown-category, not the whole container", function()
    -- red under: the description still claiming the cap draws "at most this many auras in this
    -- container" — false the moment one category is Hidden, since modules/FilterCompiler.lua's
    -- lookOf stamps maxFrameCount on EVERY group and the engine applies it per group, not once.
    local NS = fresh()
    local desc = NS.FindSchemaRow("container.filter.maxAuras").desc
    assertTrue(desc:find("own group", 1, true) ~= nil, "says the cap is per-group: " .. tostring(desc))
    assertTrue(desc:find("EACH", 1, true) ~= nil or desc:find("each", 1, true) ~= nil,
        "says the cap applies to each group separately: " .. tostring(desc))
    -- red under (fix round 2): the rewrite naming only "something is Hidden" as the multi-group case
    -- and staying silent on `onlyShown` — which ALSO multiplies groups (one per shown category) even
    -- with nothing Hidden, so the container-wide claim would be false for that combination too.
    assertTrue(desc:find("Only these categories", 1, true) ~= nil,
        "names the toggle as its own multi-group case: " .. tostring(desc))
end)

test("filters: the sort-by and direction descriptions tell the truth about a group being per-shown-category, not the whole container", function()
    -- red under: the descriptions still claiming the sort/direction order the whole container's
    -- draw order — false the moment one category is Hidden (or 'Only these categories' is on),
    -- since modules/FilterCompiler.lua's lookOf stamps sortMethod/sortDirection on EVERY group and
    -- the engine sorts within each group, laying groups out by layoutIndex.
    local NS = fresh()
    for _, path in ipairs({ "container.filter.sortMethod", "container.filter.sortDirection" }) do
        local desc = NS.FindSchemaRow(path).desc
        assertTrue(desc:find("own group", 1, true) ~= nil,
            path .. " says the sort is per-group: " .. tostring(desc))
        assertTrue(desc:find("EACH", 1, true) ~= nil or desc:find("each", 1, true) ~= nil,
            path .. " says it applies to each group separately: " .. tostring(desc))
        assertTrue(desc:find("Only these categories", 1, true) ~= nil,
            path .. " names the toggle as its own multi-group case: " .. tostring(desc))
    end
end)

-- ── B8: Max duration presets ─────────────────────────────────────────────────────────────────

test("filters: a max-duration preset writes the same path as the slider", function()
    -- red under: the preset not writing the slider's path, which would make it decorative.
    local NS, _, P, ws = filters()
    local dd = P.find(ws, "Dropdown", NS.L["Preset"])
    assertTrue(dd ~= nil, "the What to show tab draws a preset dropdown")
    dd:__fire("OnValueChanged", 300)
    assertEqual(NS.Database.FindContainer(1).filter.maxDuration, 300)
    -- the slider itself agrees, once the tab redraws from the new stored value
    ws = P.rerender("Filters")
    assertEqual(P.row(ws, "container.filter.maxDuration").value, 300)
end)

test("filters: a stored max-duration matching no preset leaves the preset dropdown blank", function()
    -- red under: snapping the dropdown to the nearest preset instead of leaving it unset — silently
    -- changing a player's stored number is worse than a blank dropdown.
    local NS, _, P = filters()
    NS.SetByPath("container.filter.maxDuration", 45, 1)
    local ws = P.rerender("Filters")
    local dd = P.find(ws, "Dropdown", NS.L["Preset"])
    assertTrue(dd ~= nil)
    assertNil(dd.value)
end)

test("filters: the max-duration description says there is no minimum", function()
    -- red under: the description promising a lower bound the engine cannot honor.
    local NS = fresh()
    local desc = NS.FindSchemaRow("container.filter.maxDuration").desc
    assertTrue(desc:find("no minimum", 1, true) ~= nil, "states plainly there is no minimum: " .. tostring(desc))
end)

-- ── the Categories grid (F-1) ─────────────────────────────────────────────────────────────────

test("filters: a buff container's Categories tab is two grids, Blizzard Categories then Spell Categories, each once", function()
    local NS, _, P, ws = categories()
    local L = NS.L
    -- red under: the rows drawn by the flow engine (each subgroup heading repeats as the kinds
    -- interleave), or the grids drawn in the wrong order. F-1: the heading reads Spell Categories,
    -- not Custom Categories.
    assertEqual(table.concat(headings(ws), "|"), L["Blizzard Categories"] .. "|" .. L["Spell Categories"])
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

test("filters: every grid's columns are Show and Hide, then the category (schema v3)", function()
    local NS, _, _, ws = categories()
    local L = NS.L
    local headers = 0
    for _, w in ipairs(ws) do
        local kids = w.children
        if kids and kids[1] and kids[1].type == "Label" and kids[1].text == L["Show"] then
            headers = headers + 1
            -- Only the first three: the Spell Categories grid's header carries a fourth, blank cell
            -- for F-3's `See spells` link column, checked on its own below.
            local got = { kids[1].text, kids[2].text, kids[3].text }
            -- red under: CATEGORY_STATE_LABELS keeping a third, Default column
            assertEqual(table.concat(got, "|"), L["Show"] .. "|" .. L["Hide"] .. "|" .. L["Category"])
        end
    end
    assertEqual(headers, 2, "one header line per grid")
end)

-- ── F-2/F-3: the Spell Categories grid's blurb and its `See spells` link ─────────────────────────

test("filters: the Spell Categories grid opens with a line naming where its lists live (F-2)", function()
    local _, _, P, ws = categories()
    -- red under: F-2's line missing, or attached under the wrong grid
    assertTrue(P.hasText(ws, "General → Spell Categories"), "names where the lists live")
end)

test("filters: a spells-kind row's See spells link selects that category on General -> Spell Categories and lands there; a token row gets no link (F-3)", function()
    local NS, _, P = filters()
    P.show("General") -- render once, so H.SelectTab (K-4) has a rendered ctx to land the click on
    local ws = P.tab("filters", NS.L["Categories"])
    local kids = gridLine(NS, ws, "healing")
    local link = kids[4]
    assertTrue(link ~= nil and link.type == "InteractiveLabel", "a spells-kind row carries the link")
    assertEqual(link.text, NS.L["See spells"])
    -- red under: onClick reaching the wrong seam, or reaching none at all
    link:__fire("OnClick")
    assertEqual(NS.Helpers.__pageCtx.general.activeTab, NS.L["Spell Categories"], "lands on General -> Spell Categories")
    local gws = P.rerender("General")
    local dd = P.find(gws, "Dropdown", NS.L["Category"])
    assertEqual(dd.value, "healing", "and selects the row's own category there")
    -- a Blizzard token row's grid carries no extra column at all
    local bigDef = gridLine(NS, ws, "bigDefensive")
    assertTrue(bigDef ~= nil and bigDef[4] == nil, "a token row's grid line carries no extra cell")
    -- Decision #3: the enchant row gets the link too, since that tab can also draw it
    local enchantKids = gridLine(NS, ws, "weaponEnchants")
    assertEqual(enchantKids[4].text, NS.L["See spells"], "the enchant row's link too")
end)

-- ── the priority blurb (F-4) and 'Only these categories' (R-8/R-10) ─────────────────────────────

test("filters: the priority order (spec §6) appears on both the Categories and the Overrides tab, highest rank first", function()
    local NS, _, P = filters()
    local cats = P.tab("filters", NS.L["Categories"])
    local overrides = P.tab("filters", "overrides")
    -- red under: the blurb missing from either tab, or restating the superseded blacklist-first order
    for _, ws in ipairs({ cats, overrides }) do
        assertTrue(P.hasText(ws, "whitelist"), "names the whitelist")
        assertTrue(P.hasText(ws, "blacklist"), "names the blacklist")
        assertTrue(P.hasText(ws, "set to Show"), "Show is its own rank, not the absence of Hide")
        assertTrue(P.hasText(ws, "all say Hide"), "only an aura hidden by every one of its categories is removed")
    end
end)

test("filters: 'Only these categories' is drawn at the top of the Categories tab, above the grids, and its text explains Hide differently while it is on (R-8/R-10)", function()
    local NS, _, P = filters()
    local ws = P.tab("filters", NS.L["Categories"])
    local cb = P.row(ws, "container.filter.onlyShown")
    assertTrue(cb ~= nil and cb.type == "CheckBox", "a plain toggle, not a grid cell")
    local idxCb, idxHeading
    for i, w in ipairs(ws) do
        if w == cb and not idxCb then idxCb = i end
        if w.type == "Heading" and not idxHeading then idxHeading = i end
    end
    -- red under: the toggle drawn after the grids rather than above them
    assertTrue(idxCb ~= nil and idxHeading ~= nil and idxCb < idxHeading, "sits above the first grid heading")
    assertFalse(P.hasText(ws, "not shown"), "off: nothing to explain differently yet")
    cb:__fire("OnValueChanged", true)
    ws = P.rerender("Filters")
    -- red under: R-10 — the tab dimming or disabling the Hide column while this is on
    local cells = gridLine(NS, ws, "defensives")
    assertFalse(cells[2].disabled == true, "Hide stays live: it is still the only way to un-Show a row")
    -- red under: the note missing, so a player reads Hide as "removed" while it means "not shown"
    assertTrue(P.hasText(ws, "not shown"), "on: explains Hide means not shown, not removed")
end)

test("filters: a grid checkbox stores show or hide for the selected container and re-syncs its line", function()
    local NS, m, _, ws = categories()
    m.__subcategories.Filters:Show()   -- on screen, so a write re-syncs the widgets in place
    local cells = gridLine(NS, ws, "defensives")
    -- red under: LibKa0s v1.36.0 draws choice cells as CheckBox widgets (yellow fill), not radios
    assertEqual(cells[1].type, "CheckBox")
    assertTrue(cells[1].value == true, "Show is lit for a fresh container")
    cells[2]:__fire("OnValueChanged", true)
    -- red under: the columns' values out of order (the Hide cell storing anything but "hide")
    assertEqual(NS.Database.FindContainer(1).filter.categories.defensives, "hide")
    assertEqual(NS.Database.FindContainer(2).filter.categories.defensives, "show", "no other container")
    -- red under: a cell's refresher not re-reading the row (the Show cell would stay lit)
    assertTrue(cells[2].value == true and cells[1].value == false, "the line re-syncs to Hide")
    cells[1]:__fire("OnValueChanged", true)
    assertEqual(NS.Database.FindContainer(1).filter.categories.defensives, "show")
end)

test("filters: /am get and /am list print a category's state as Show or Hide", function()
    local NS, _, P = filters()
    NS.SetByPath("container.filter.categories.defensives", "hide", 1)
    local lines = P.chat()
    NS.Slash:OnSlash("get container.filter.categories.defensives")
    local got = lastLine(lines)
    -- red under: the Slash descriptor printing the stored value ("hide") rather than its label
    assertTrue(got:find(NS.L["Hide"], 1, true) ~= nil, got)
    NS.SetByPath("container.filter.categories.defensives", "show", 1)
    NS.Slash:OnSlash("get container.filter.categories.defensives")
    got = lastLine(lines)
    assertTrue(got:find(NS.L["Show"], 1, true) ~= nil, got)
    NS.Slash:OnSlash("list")
    local listed
    for _, l in ipairs(lines) do
        if l:find("container.filter.categories.stealable", 1, true) then listed = l end
    end
    assertTrue(listed ~= nil, "the category rows stay in /am list")
    assertTrue(listed:find(NS.L["Show"], 1, true) ~= nil, listed)
    NS.Slash:OnSlash("get container.filter.castBy")
    got = lastLine(lines)
    assertTrue(got:find("any", 1, true) ~= nil, "every other row prints as it always has: " .. got)
end)

test("filters: every category row is skipRender and names its grid", function()
    local NS = filters()
    local want = { spells = "custom", token = "blizzard", flag = "blizzard", dispel = "dispel", enchant = "custom" }
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
    assertTrue(P.hasText(ws, "No spell named 'No Such Spell' in your spellbook."))
end)

--- The Filters page on a client with the suggestions' sources (tests/_kit/mock_ids.lua), `seed`
--- run before the Overrides tab draws: NS, m, P, its widgets, the dropdown's reader and the two
--- add boxes (whitelist first).
local function overridesSuggesting(seed)
    local NS, m, P = filters({ before = function(m2)
        dofile("tests/_kit/mock_ids.lua")(m2)
        m2.installIdSuggestions()
    end })
    seed(NS, m)
    local ws = P.tab("filters", "overrides")
    return NS, m, P, ws, P.suggestions(), P.all(ws, "EditBox", NS.L["Add a spell"])
end

test("filters: an Overrides list suggests the profile's edits and the other list; a keyboard pick writes that list once", function()
    local NS, _, _, _, S, boxes = overridesSuggesting(function(NS2, m)
        m.__spells[5701] = { name = "Gale Ward", iconID = 1 }
        m.__spells[5702] = { name = "Gale Veil", iconID = 1 }
        NS2.SetByPath("categorySpells", { healing = { [5701] = true } })
        NS2.SetByPath("container.filter.blacklist", { [5702] = true }, 1)
    end)
    S.type(boxes[1], "gale")
    -- red under: candidates() omitting the profile's categorySpells ids or the containers' lists
    assertEqual(S.ids(true), "5701,5702")
    local first = S.rows()[1].entry.id
    local paths = {}
    local real = NS.SetByPath
    NS.SetByPath = function(path, ...)
        paths[#paths + 1] = path
        return real(path, ...)
    end
    boxes[1].editbox:__fire("OnArrowPressed", "DOWN")
    boxes[1]:__fire("OnEnterPressed", "gale")
    -- red under: a pick bypassing onAdd, or onAdd writing the set more than once or elsewhere
    assertEqual(table.concat(paths, ","), "container.filter.whitelist")
    assertEqual(NS.Database.FindContainer(1).filter.whitelist[first], true)
end)

test("filters: an Overrides name two ranks share is refused until one is picked, and the tooltip says where names come from", function()
    local NS, m, P, ws, S, boxes = overridesSuggesting(function(NS2, m2)
        for rank, id in ipairs({ 5711, 5712 }) do
            m2.__spells[id] = { name = "Hushed Gale", iconID = 1 }
            m2.setSpellSubtext(id, "Rank " .. rank)
        end
        NS2.db.global.timedSpells = { [5711] = true, [5712] = true }
    end)
    local msgs = P.messages()
    boxes[1]:__fire("OnEnterPressed", "Hushed Gale")
    -- red under: a shared name resolving to one rank the player did not pick
    assertEqual(msgs.config, 0)
    assertTrue(P.hasText(ws, "Several spells are named 'Hushed Gale' — pick one from the list, or use the id."))
    assertEqual(S.ids(), "5711,5712", "the refusal lists both ranks")
    local lines = {}
    rawset(m.GameTooltip, "AddLine", function(_, s)
        lines[#lines + 1] = s
    end)
    boxes[2]:__fire("OnEnter")
    -- red under: the Overrides tooltip still promising any name the game cannot find is matched
    assertTrue((lines[1] or ""):find(NS.Helpers.ID_NAME_HINT.spell, 1, true) ~= nil)
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

-- ── Overrides entry notes (task B6, spec §6/§6c) ─────────────────────────────────────────────────

-- A plain, uncategorized WHITELIST entry has no note: nothing claims it, so the container would
-- draw it either way (rank 5, shown, with `onlyShown` off) — no mismatch. A plain, uncategorized
-- BLACKLIST entry is different (fix round 2): the ordinary catch-all WOULD draw it if the entry
-- were removed, which is exactly the mismatch task-B6's other tests exercise, so it is covered
-- separately below rather than folded into a single "plain entry has no note" claim that is no
-- longer true for the blacklist side.
test("filters: a plain, uncategorized whitelist entry has no note", function()
    local NS, _, P = filters()
    NS.SetByPath("container.filter.whitelist", { [774] = true }, 1)
    local ws = P.tab("filters", "overrides")
    -- red under: a note drawn for every entry regardless of whether anything disagrees
    assertFalse(P.hasText(ws, "overriding"), "no category conflict to report")
    assertFalse(P.hasText(ws, "outranks"), "not on the other list either")
    assertFalse(P.hasText(ws, "not be drawn at all"), "onlyShown is off; nothing else to warn about")
end)

-- red under: the blacklist entry not reporting that the whitelist already claimed the same id
test("filters: a spell on both lists gets a note on its blacklist entry saying the whitelist wins", function()
    local NS, _, P = filters()
    NS.SetByPath("container.filter.whitelist", { [500] = true }, 1)
    NS.SetByPath("container.filter.blacklist", { [500] = true }, 1)
    local ws = P.tab("filters", "overrides")
    assertTrue(P.hasText(ws, NS.L["Shown here anyway — it is also on the whitelist, which outranks the blacklist."]))
end)

-- red under: the whitelist entry not reporting that it is also blacklisted
test("filters: a spell on both lists gets a note on its whitelist entry naming the blacklist too", function()
    local NS, _, P = filters()
    NS.SetByPath("container.filter.whitelist", { [500] = true }, 1)
    NS.SetByPath("container.filter.blacklist", { [500] = true }, 1)
    local ws = P.tab("filters", "overrides")
    assertTrue(P.hasText(ws, NS.L["Also on the blacklist, but the whitelist outranks it — still shown here."]))
end)

-- red under: a blacklisted spell that a Show category would rescue not reporting the conflict
test("filters: a blacklisted spell in a Show category names that category as overridden", function()
    local NS, _, P = filters()
    NS.SetByPath("container.filter.blacklist", { [900001] = true }, 1)
    NS.SetByPath("categorySpells", { defensives = { [900001] = true } })
    local ws = P.tab("filters", "overrides")
    assertTrue(P.hasText(ws, ("overriding %s (set to Show)"):format(NS.L["Defensives"])))
end)

-- red under: a whitelisted spell whose categories all say Hide not reporting the conflict
test("filters: a whitelisted spell every one of its categories would hide names them as overridden", function()
    local NS, _, P = filters()
    NS.SetByPath("container.filter.whitelist", { [900002] = true }, 1)
    NS.SetByPath("categorySpells", { defensives = { [900002] = true } })
    NS.SetByPath("container.filter.categories.defensives", "hide", 1)
    local ws = P.tab("filters", "overrides")
    assertTrue(P.hasText(ws, ("overriding %s (set to Hide)"):format(NS.L["Defensives"])))
end)

-- red under: a blacklisted spell in a Hide-only category getting a spurious note (the blacklist and
-- the category already agree, so there is nothing to explain)
test("filters: a blacklisted spell a Hide category would also hide gets no note", function()
    local NS, _, P = filters()
    NS.SetByPath("container.filter.blacklist", { [900003] = true }, 1)
    NS.SetByPath("categorySpells", { defensives = { [900003] = true } })
    NS.SetByPath("container.filter.categories.defensives", "hide", 1)
    local ws = P.tab("filters", "overrides")
    assertFalse(P.hasText(ws, "overriding"), "the blacklist and the category agree")
end)

-- Fix round 1: a whitelisted spell no category claims, under "only these categories", would vanish
-- from the container entirely if it were not whitelisted (R-9's catch-all is gone) — the case the
-- rank-4-only check missed, because the counterfactual is rank 5 hidden, not rank 4.
-- red under: overrideNote checking `cat.rank == 4` instead of `cat.verdict == "hidden"`
test("filters: a whitelisted spell no category claims, under 'only these categories', warns it would vanish", function()
    local NS, _, P = filters()
    NS.SetByPath("container.filter.whitelist", { [900004] = true }, 1)
    NS.SetByPath("container.filter.onlyShown", true, 1)
    local ws = P.tab("filters", "overrides")
    assertTrue(P.hasText(ws, "not be drawn at all"),
        "an unclaimed whitelisted spell under onlyShown needs its own wording, not the category one")
end)

-- Fix round 2: an uncategorized blacklisted spell, with onlyShown OFF, would be drawn by the
-- ordinary catch-all if the entry were removed (rank 5, shown) — a real mismatch a rank-3-only check
-- misses, mirroring the whitelist bug fixed above.
-- red under: overrideNote's blacklist branch checking `cat.rank == 3` instead of `cat.verdict == "shown"`
test("filters: an uncategorized blacklisted spell warns that no category hides it", function()
    local NS, _, P = filters()
    NS.SetByPath("container.filter.blacklist", { [900005] = true }, 1)
    local ws = P.tab("filters", "overrides")
    assertTrue(P.hasText(ws, "no category here hides it"),
        "no category claims it, but the ordinary catch-all would still draw it")
end)
