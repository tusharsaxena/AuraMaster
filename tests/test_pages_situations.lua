-- tests/test_pages_situations.lua — filter situations S4 (SI-05): the Situations tab, the last tab of
-- the Filters page, driven through its widgets. Section "Where spell lists don't apply": the unit
-- wording, then the dropdowns the container's FC.IdsMode calls for (On NPCs and On players on a
-- target or focus; one "Your own and your pet's debuffs" on a player or pet debuff container; none,
-- and a note, on a player or pet buff container), the honor line, and the timeless note. Section
-- "Show in": the six zone checkboxes. The Spell Categories and Overrides NOTE lines that point here
-- are tests/test_pages_filters.lua's; the rows' data is tests/test_situations_settings.lua's.
-- Spec: docs/superpowers/specs/2026-10-02-filter-situations-design.md S4.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")
local pages = dofile("tests/page_helpers.lua")

local HONOR = "Every aura still honors Cast by, Max duration and the Blizzard, Dispel and Who Cast It rows you set to Hide; spell categories, Uncategorized and Overrides do not apply there."
local ALWAYS = "Spell lists always apply to your own and your pet's buffs."
local TIMELESS = "Every aura draws nothing extra here: 'Without a duration' is built from spell lists."
local ZONES = { "Open world", "Dungeons", "Scenarios and delves", "Raids", "Battlegrounds", "Arenas" }

--- The Situations tab of container `id`, on `unit` when given; `setup(NS)` runs before the draw.
local function situations(id, unit, setup)
    local NS, m = fresh()
    local P = pages(NS, m)
    if unit then assertTrue(NS.SetByPath("container.unit", unit, id)) end
    if setup then setup(NS) end
    NS.Helpers.SelectContainer(id)
    P.show("Filters")
    return NS, P, P.tab("filters", NS.L["Situations"])
end

--- The texts of the section headings a render drew, in order.
local function headings(ws)
    local out = {}
    for _, w in ipairs(ws) do
        if w.type == "Heading" then out[#out + 1] = w.text end
    end
    return table.concat(out, "|")
end

--- The index of the first widget whose text or label is `text`, or nil.
local function at(ws, text)
    for i, w in ipairs(ws) do
        if w.text == text or w.labelText == text then return i end
    end
    return nil
end

--- The labels of every Dropdown drawn, in order.
local function dropdowns(ws)
    local out = {}
    for _, w in ipairs(ws) do
        if w.type == "Dropdown" then out[#out + 1] = w.labelText end
    end
    return table.concat(out, "|")
end

test("situations tab: the Filters strip reads General, Categories, Overrides, Sorting, Situations", function()
    for _, id in ipairs({ 1, 2, 3 }) do
        local NS, m = fresh()
        local P = pages(NS, m)
        local L = NS.L
        NS.Helpers.SelectContainer(id)
        P.show("Filters")
        -- red under: the Situations rows declared before Sorting's (a `before` on the tab does not
        -- move it: collectTabs gives a group-keyed tab its group's slot)
        assertEqual(table.concat(P.tabKeys("filters"), ","),
            table.concat({ L["General"], L["Categories"], "overrides", L["Sorting"], L["Situations"] }, ","),
            "container " .. id)
    end
end)

test("situations tab: a target or focus buff container draws its unit line, On NPCs and On players, and the honor line", function()
    for _, unit in ipairs({ "target", "focus" }) do
        local NS, P, ws = situations(1, unit)
        local L = NS.L
        -- red under: the tab drawn as a plain group (no sections), or the zone section missing
        assertEqual(headings(ws), L["Where spell lists don't apply"] .. "|" .. L["Show in"], unit)
        -- red under: a unit line in another wording than the Spell Categories NOTE's
        local line = at(ws, L["On units you can't assist, spell lists don't apply to this container."])
        assertTrue(line ~= nil, unit .. ": the unit line")
        -- red under: the dropdowns gated on anything but FC.IdsMode "dynamic"
        assertEqual(dropdowns(ws), L["On NPCs"] .. "|" .. L["On players"], unit)
        local honor = at(ws, L[HONOR])
        assertTrue(honor ~= nil and honor > at(ws, L["On players"]), unit .. ": the honor line under the dropdowns")
        assertTrue(line < at(ws, L["On NPCs"]), unit .. ": the unit line above them")
        assertFalse(P.hasText(ws, L[ALWAYS]), unit .. ": no always note")
        assertFalse(P.hasText(ws, L[TIMELESS]), unit .. ": not in 'Without a duration' mode")
    end
end)

test("situations tab: a target debuff container names units you can assist", function()
    local NS, _, ws = situations(3)
    -- red under: the unit line ignoring the aura type (debuffs lose spell lists on assistable units)
    assertTrue(at(ws, NS.L["On units you can assist, spell lists don't apply to this container."]) ~= nil)
    assertEqual(dropdowns(ws), NS.L["On NPCs"] .. "|" .. NS.L["On players"])
end)

test("situations tab: a player or pet debuff container draws one dropdown, the players setting, relabeled", function()
    local cases = {
        { unit = nil,   line = "On your own debuffs, spell lists don't apply to this container." },
        { unit = "pet", line = "On your pet's debuffs, spell lists don't apply to this container." },
    }
    for _, c in ipairs(cases) do
        local NS, _, ws = situations(2, c.unit)
        local L = NS.L
        local where = tostring(c.unit or "player")
        assertTrue(at(ws, L[c.line]) ~= nil, where .. ": the unit line")
        -- red under: On NPCs drawn where no NPC can carry the auras, or the players row unrelabeled
        assertEqual(dropdowns(ws), L["Your own and your pet's debuffs"], where)
        assertTrue(at(ws, L[HONOR]) ~= nil, where .. ": the honor line")
        local dd = ws[at(ws, L["Your own and your pet's debuffs"])]
        dd:__fire("OnValueChanged", "blizzard")
        local s = NS.Database.FindContainer(2).filter.situations
        -- red under: the relabeled copy writing the npcs leaf
        assertEqual(s.players, "blizzard", where .. ": writes the players setting")
        assertEqual(s.npcs, "every", where .. ": and leaves the NPC one alone")
    end
end)

test("situations tab: a player or pet buff container says spell lists always apply, and draws no dropdown", function()
    for _, unit in ipairs({ "player", "pet" }) do
        local NS, P, ws = situations(1, unit)
        local L = NS.L
        -- red under: the dropdowns drawn where spell lists always apply (they would change nothing)
        assertEqual(dropdowns(ws), "", unit)
        assertTrue(P.hasText(ws, L[ALWAYS]), unit .. ": the always note")
        assertFalse(P.hasText(ws, L[HONOR]), unit .. ": no honor line")
        assertFalse(P.hasText(ws, "spell lists don't apply to this container"), unit .. ": no unit line")
        -- red under: the timeless note drawn outside the where-spell-lists-don't-apply branch (no
        -- every view on these units)
        NS.SetByPath("container.filter.durationMode", "timeless", 1)
        ws = P.rerender("Filters")
        assertFalse(P.hasText(ws, L[TIMELESS]), unit .. ": no timeless note where ids always apply")
        -- and the zones still draw
        assertEqual(#P.all(ws, "CheckBox"), #ZONES, unit .. ": the six zone checkboxes")
    end
end)

test("situations tab: the timeless note keys on the effective mode, timeless buffs only", function()
    local timeless = function(id)
        return function(NS) assertTrue(NS.SetByPath("container.filter.durationMode", "timeless", id)) end
    end
    local NS, P, ws = situations(1, "target", timeless(1))
    -- red under: no timeless note on a target buff container in 'Without a duration' mode
    assertTrue(P.hasText(ws, NS.L[TIMELESS]), "target buffs, timeless")
    assertTrue(at(ws, NS.L[TIMELESS]) > at(ws, NS.L[HONOR]), "under the honor line")
    NS, P, ws = situations(3, nil, timeless(3))
    -- red under: the note keyed on the literal setting (timeless on debuffs compiles as 'any')
    assertFalse(P.hasText(ws, NS.L[TIMELESS]), "target debuffs: timeless is not effective")
end)

test("situations tab: Show in draws the six zone checkboxes in order, all ticked, each writing its zone", function()
    local NS, P, ws = situations(1, "target")
    local L = NS.L
    local boxes = P.all(ws, "CheckBox")
    local labels = {}
    for i, b in ipairs(boxes) do labels[i] = b.labelText end
    local want = {}
    for i, z in ipairs(ZONES) do want[i] = L[z] end
    -- red under: the zone rows drawn out of C.ZONE_KEYS order, or one missing
    assertEqual(table.concat(labels, "|"), table.concat(want, "|"))
    for _, b in ipairs(boxes) do assertTrue(b.value == true, b.labelText .. " ticked") end
    assertTrue(at(ws, L["Show in"]) < at(ws, L["Open world"]), "under the Show in heading")
    boxes[4]:__fire("OnValueChanged", false)
    -- red under: the checkbox drawn from a copy that writes nowhere
    assertEqual(NS.Database.FindContainer(1).filter.zones.raid, false, "Raids unticked")
    assertEqual(NS.Database.FindContainer(1).filter.zones.party, true, "the rest untouched")
end)

test("situations tab: On NPCs writes the npcs setting", function()
    local NS, P, ws = situations(1, "target")
    P.find(ws, "Dropdown", NS.L["On NPCs"]):__fire("OnValueChanged", "blizzard")
    local s = NS.Database.FindContainer(1).filter.situations
    -- red under: the dropdown drawn from a row with no path
    assertEqual(s.npcs, "blizzard")
    assertEqual(s.players, "every")
end)
