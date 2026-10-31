-- tests/test_pages_filters.lua — settings/Filters.lua, driven through its widgets: the rows each aura
-- type is offered, what each writes, the Categories grid (F-1), the Overrides tab (F-3), and the
-- warnings above every tab. The compiler's reading of what these rows store is
-- tests/test_filtercompiler.lua's. The spell categories' lists are profile-wide and edited on
-- General → Spell categories (tests/test_pages_general.lua).

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
---
--- The DRAWN label, which for a category the player made is the schema row's name plus the 'yours'
--- marker (settings/Filters.lua's markedRows, owner 2026-09-21); for every shipped category the two
--- are the same string.
local function gridLine(NS, ws, key)
    local def = NS.Categories.Find("HELPFUL", key) or NS.Categories.Find("HARMFUL", key)
    local label = def and NS.GeneralSpells.MarkedName(def)
        or NS.FindSchemaRow("container.filter.categories." .. key).label
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

-- T-3 (batch 7): hidePermanentEnchants used to sit alone below the grid, below the Uncategorized
-- note too. It now draws directly under the Spell categories grid, ahead of that note, behind a
-- line naming the row it is a sub-option of — so it reads as tied to Weapon enchants, not floating.
test("filters: hidePermanentEnchants draws right under the Spell categories grid, tied to Weapon enchants by name, ahead of the Uncategorized note (T-3)", function()
    local _, _, P, ws = categories()
    local texts = P.texts(ws)
    local tieIndex, noteIndex
    for i, t in ipairs(texts) do
        if t:find("Weapon enchants", 1, true) then tieIndex = i end
        if t:find("Uncategorized defaults to Show", 1, true) then noteIndex = i end
    end
    -- red under: the tie text missing (the row floating with nothing naming what it belongs to), or
    -- the checkbox/tie landing after the Uncategorized note again (T-3's actual complaint)
    assertTrue(tieIndex ~= nil, "the tie line names Weapon enchants")
    assertTrue(noteIndex ~= nil, "the Uncategorized note still draws")
    assertTrue(tieIndex < noteIndex, "the tie (and the checkbox right after it) comes before the note, directly under the grid")
    local cb = P.row(ws, "container.filter.hidePermanentEnchants")
    assertEqual(cb.type, "CheckBox", "still a plain checkbox, not a grid cell (regression guard)")
end)

-- The three Order and cap tooltips used to repeat one ~70-word paragraph about engine groups each.
-- Item 020 (AUR-L06) cuts each to one sentence pointing at a note drawn ONCE on the tab.
test("filters: Sort by, Direction and Maximum auras each say in one sentence that they work per engine group, and point at the note", function()
    local NS = fresh()
    for _, path in ipairs({ "container.filter.sortMethod", "container.filter.sortDirection", "container.filter.maxAuras" }) do
        local desc = NS.FindSchemaRow(path).desc
        -- red under: the paragraph left in the tooltip (three copies in three hovers)
        assertTrue(desc:find("within each engine group", 1, true) ~= nil, path .. ": per group: " .. desc)
        assertTrue(desc:sub(-#"see the note below.") == "see the note below.", path .. ": points at the note: " .. desc)
        assertEqual(select(2, desc:gsub("%. ", "")), 0, path .. " is one sentence: " .. desc)
    end
end)

-- The engine-group note tells the truth about a group being per-shown-category, not the whole
-- container: modules/FilterCompiler.lua's lookOf stamps sortMethod, sortDirection and maxFrameCount
-- on EVERY group and the engine applies each within a group, laying groups out by layoutIndex.
test("filters: the engine-group note is drawn once, after the Order and cap rows and before the priority block", function()
    local NS, _, _, ws = filters()
    local L = NS.L
    local note, count, lastRow, priority
    for i, w in ipairs(ws) do
        if type(w.text) == "string" and w.text:find("work within each engine group", 1, true) then
            note, count = note or i, (count or 0) + 1
        end
        if w.labelText == L["Maximum auras per group (0 = no limit)"] or w.labelText == L["Direction"] then lastRow = i end
        if w.type == "Heading" and w.text == L["Filter priority logic"] then priority = i end
    end
    -- red under: the note missing, drawn twice, or drawn above the rows it explains
    assertEqual(count, 1, "drawn once")
    assertTrue(lastRow < note and note < priority, "under Order and cap, ahead of Filter priority logic")
    local text = ws[note].text
    assertTrue(text:find("own group", 1, true) ~= nil and text:find("separately", 1, true) ~= nil, text)
    -- Fix round 2 of batch 7 retired the "Only these categories" toggle (D8): a dangling mention of a
    -- control that no longer exists would be its own bug.
    assertTrue(text:find("Only these categories", 1, true) == nil, text)
end)

test("filters: General opens with What to show, then Order and cap (AUR-L02)", function()
    local NS, _, _, ws = filters()
    local L = NS.L
    local heads = headings(ws)
    -- red under: the Sorting rows left on a tab of their own, or the subsections missing
    assertEqual(table.concat(heads, "|"), L["What to show"] .. "|" .. L["Order and cap"] .. "|" .. L["Filter priority logic"])
    assertEqual(NS.FindSchemaRow("container.filter.sortMethod").group, L["General"])
    assertEqual(NS.FindSchemaRow("container.filter.maxDuration").label, L["Maximum duration (seconds, 0 = no limit)"], "AUR-L07")
    assertEqual(NS.FindSchemaRow("container.filter.maxAuras").label, L["Maximum auras per group (0 = no limit)"], "AUR-L-new1")
end)

-- ── B8: Max duration presets ─────────────────────────────────────────────────────────────────

test("filters: a max-duration preset writes the same path as the slider", function()
    -- red under: the preset not writing the slider's path, which would make it decorative.
    local NS, _, P, ws = filters()
    local dd = P.find(ws, "Dropdown", NS.L["Preset"])
    assertTrue(dd ~= nil, "the General tab draws a preset dropdown")
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

test("filters: a buff container's Categories tab is two grids, Blizzard categories then Spell categories, each once", function()
    local NS, _, P, ws = categories()
    local L = NS.L
    -- red under: the rows drawn by the flow engine (each subgroup heading repeats as the kinds
    -- interleave), or the grids drawn in the wrong order. F-1: the heading reads Spell categories,
    -- not Custom Categories.
    -- AUR-L03: the spell-list section opens the tab, above the grids it decides for
    assertEqual(table.concat(headings(ws), "|"), L["Where spell lists don't apply"] .. "|" .. L["Blizzard categories"] .. "|" .. L["Spell categories"])
    assertNil(P.find(ws, "Dropdown", NS.FindSchemaRow("container.filter.categories.defensives").label),
        "a category is a grid line, not a dropdown")
    assertTrue(gridLine(NS, ws, "defensives") ~= nil, "a custom category has a grid line")
    assertTrue(gridLine(NS, ws, "bigDefensive") ~= nil, "and a Blizzard one")
    assertNil(gridLine(NS, ws, "crowdControl"), "no debuff category on a buff container")
end)

test("filters: a debuff container's Categories tab is Blizzard categories, Spell categories, Dispel types and Who cast it, each once", function()
    local NS, _, _, ws = categories(2)
    local L = NS.L
    -- U-1, fix round 3 (2026-09-16): the owner restored the debuff row — `uncategorizedDebuffs`
    -- shares the Spell categories grid, so it draws for a debuff container again, one row, asymmetric
    -- with the buff row (Hide reproduces the retired toggle; Show is inert — defaults/Categories.lua's
    -- KINDS doc, modules/FilterCompiler.lua's `hasUnion` gate).
    -- red under: a grid key mapping dispel or who-cast-it rows into the Blizzard grid
    assertEqual(table.concat(headings(ws), "|"), L["Where spell lists don't apply"] .. "|" ..
        L["Blizzard categories"] .. "|" .. L["Spell categories"] .. "|" .. L["Dispel types"] .. "|" .. L["Who cast it"])
    assertTrue(gridLine(NS, ws, "magic") ~= nil)
    assertTrue(gridLine(NS, ws, "fromPlayers") ~= nil)
    assertTrue(gridLine(NS, ws, "uncategorizedDebuffs") ~= nil, "U-1: restored for debuffs (fix round 3)")
    assertNil(gridLine(NS, ws, "defensives"), "no buff category on a debuff container")
end)

test("filters: the Dispel types grid draws no 4th cell, blank or otherwise", function()
    local NS, _, _, ws = categories(2)
    -- A characterization (AM-13, before renderCategories went table-dispatched): the plain grids
    -- pass no extraColumn at all, so their lines stay three cells wide.
    -- red under: the plain-grid branch passing CATEGORY_EXTRA and letting the cell answer nil
    for _, key in ipairs({ "dispels", "magic", "curse", "disease", "poison", "bleed" }) do
        local line = gridLine(NS, ws, key)
        assertTrue(line ~= nil, key .. " draws a grid line")
        assertNil(line[4], key .. " carries no extra cell")
    end
end)

test("filters: a category the player made is marked as theirs in the grid, and its schema row is not (owner 2026-09-21)", function()
    local NS, _, P = filters()
    local key = NS.Categories.CreateUserCategory("Affixes", "HELPFUL")
    local ws = P.tab("filters", NS.L["Categories"])
    local line = gridLine(NS, ws, key)
    -- red under: the grid drawing the bare name, so a player reading the Categories grid cannot tell
    -- their own categories from Aura Master's without leaving the page and selecting each one.
    assertTrue(line ~= nil, "the row is drawn")
    -- In muted gold, as everywhere else the panel marks one (owner, 2026-09-21): the grid reads
    -- `NS.GeneralSpells.MarkedName`, which is the ONE definition of the marker and of its color.
    assertEqual(line[3].text, "Affixes |cffd9b861(yours)|r")
    -- red under: marking the SCHEMA row rather than a per-render copy, which would carry the marker
    -- into `/am list` and the write log, where the name is the row's identity and not decoration.
    assertEqual(NS.FindSchemaRow("container.filter.categories." .. key).label, "Affixes")
    assertEqual(gridLine(NS, ws, "healing")[3].text, NS.L["Healing"], "a shipped row is unmarked")
end)

test("filters: every grid's columns are Show and Hide, then the category (schema v3)", function()
    local NS, _, _, ws = categories()
    local L = NS.L
    local headers = 0
    for _, w in ipairs(ws) do
        local kids = w.children
        if kids and kids[1] and kids[1].type == "Label" and kids[1].text == L["Show"] then
            headers = headers + 1
            -- Only the first three: the Spell categories grid's header carries a fourth, blank cell
            -- for F-3's `See spells` link column, checked on its own below.
            local got = { kids[1].text, kids[2].text, kids[3].text }
            -- red under: CATEGORY_STATE_LABELS keeping a third, Default column
            assertEqual(table.concat(got, "|"), L["Show"] .. "|" .. L["Hide"] .. "|" .. L["Category"])
        end
    end
    assertEqual(headers, 2, "one header line per grid")
end)

-- ── F-2/F-3: the Spell categories grid's blurb and its `See spells` link ─────────────────────────

test("filters: the Spell categories grid opens with a line naming where its lists live (F-2)", function()
    local _, _, P, ws = categories()
    -- red under: F-2's line missing, or attached under the wrong grid
    assertTrue(P.hasText(ws, "the General page > Spell categories"), "names where the lists live")
end)

-- T-2 fix round 4 (batch 7), revised by issue #11 A1: the F-2 line claims the grid holds EDITABLE
-- lists. That is now true on BOTH aura types — `Cat.HARMFUL` carries the CC lists — so the
-- gate has stopped discriminating by aura type, which is exactly what it was written to do: it asks
-- the grid what it drew, never which tab it is on. It still refuses a grid whose only row is
-- `uncategorized`, the Show/Hide flag over the catch-all, which is what a debuff grid was before A1.
test("filters: the 'these are the lists' line draws wherever the grid holds an editable list — both aura types since the CC lists (T-2)", function()
    local NS, _, P, buffWs = categories(1)
    assertTrue(P.hasText(buffWs, "the General page > Spell categories"), "a buff container has editable lists")
    local _, _, P2, debuffWs = categories(2)
    assertTrue(P2.hasText(debuffWs, "the General page > Spell categories"),
        "a debuff container's grid now carries the CC lists, which live there")
    assertTrue(P2.find(debuffWs, "Heading", NS.L["Spell categories"]) ~= nil, "the Spell categories grid still draws")
    assertTrue(gridLine(NS, debuffWs, "uncategorizedDebuffs") ~= nil, "and still carries its Uncategorized row")
    assertTrue(gridLine(NS, debuffWs, "hardCC") ~= nil, "and the CC Loss of Control row the claim is now about")
    assertTrue(gridLine(NS, debuffWs, "ccRoot") ~= nil, "and CC Root")
    assertTrue(gridLine(NS, debuffWs, "ccSnare") ~= nil, "and CC Snare")
end)

-- A3 (issue #11): the debuff grid's own limitation note. Blizzard honors debuff spell ids only on a
-- unit you cannot assist, so on a player, pet or assistable unit the debuff spell lists match nothing. Said under
-- the grid that offers them and nowhere else — a buff tab's limit is the mirror one and would be
-- actively misleading here.
test("filters: a debuff container's Categories tab says its spell lists only match on a target or focus you can't assist (A3)", function()
    local _, _, P2, debuffWs = categories(2)
    -- red under: the old "Hard CC and Soft CC only work on a hostile target or focus ... change
    -- nothing" note, which the blizzard view made false
    assertTrue(P2.hasText(debuffWs, "only match on a target or focus you can't assist"),
        "the debuff grid carries the spell-list note")
    -- red under: the note promising only the Blizzard Show categories there, which the every view
    -- (the default) made false (SI-06)
    assertTrue(P2.hasText(debuffWs, "Where spell lists don't apply, at the top of the Categories tab, picks what draws there"),
        "and points where the lists match nothing to the section that decides it (AUR-L29)")
    assertFalse(P2.hasText(debuffWs, "leaves only the Blizzard categories set to Show"),
        "and no longer promises only the Blizzard Show categories")
    local _, _, P, buffWs = categories(1)
    assertFalse(P.hasText(buffWs, "only match on a target or focus you can't assist"),
        "never on a buff container, whose spell lists are honored on friendly units instead")
end)

-- Review fix wave item 2, re-derived by issue #11 A2: UNCATEGORIZED_NOTE ("Uncategorized defaults to
-- Show, which rescues...") describes a group the compiler emits only where `FC.IdsMode` is "always",
-- for buffs on the player and the pet. The old gate ("is this a buff container") gave the right
-- answer for both fixtures below by coincidence; the live gate asks the UNIT, so a debuff container
-- is silent because the engine discards its ids, not because its grid holds no list any more.
test("filters: the Uncategorized cost note draws only where the engine is certain to honor spell ids (A2)", function()
    local _, _, P, buffWs = categories(1)
    assertTrue(P.hasText(buffWs, "rescues any aura not on the lists above"),
        "true on the player's own buffs, the one place the rescue group is emitted")
    local _, _, P2, debuffWs = categories(2)
    assertFalse(P2.hasText(debuffWs, "rescues any aura not on the lists above"),
        "false on a debuff container — the engine throws that group's one constraint away")
    -- Container 3 is "Target debuffs (mine)" (defaults/Profile.lua): a debuff container on a unit
    -- that MAY be hostile, which is still not CERTAIN, so still no rescue and still no sentence.
    local _, _, P3, targetWs = categories(3)
    assertFalse(P3.hasText(targetWs, "rescues any aura not on the lists above"),
        "false on a target too — hostility is dynamic and the plan is compiled long before anyone looks")
end)

-- SV-04 (spell-list views, V4): the NOTE under the Spell categories heading. Where Blizzard does not
-- apply spell ids the container switches to its blizzard view, in which every spell category's group
-- is NEVER, so the grid must say so on every container whose `FC.IdsMode` is not "always", in the
-- words of the unit it is about, and stay silent on a buff container on the player or the pet.

--- The Categories tab of container `id` after its unit is set to `unit` (left alone when nil).
local function categoriesOn(id, unit)
    local NS, m, P = filters()
    if unit then NS.SetByPath("container.unit", unit, id) end
    NS.Helpers.SelectContainer(id)
    P.show("Filters")
    return NS, m, P, P.tab("filters", NS.L["Categories"])
end

--- The index of the first widget whose text is `text`, or nil.
local function indexOfText(ws, text)
    for i, w in ipairs(ws) do
        if w.text == text then return i end
    end
    return nil
end

test("filters: the Spell categories NOTE names where spell categories are not applied, per unit (SV-04)", function()
    local cases = {
        { id = 2, unit = nil,      note = "NOTE: on your own debuffs, these spell categories are not applied (see above)." },
        { id = 2, unit = "pet",    note = "NOTE: on your pet's debuffs, these spell categories are not applied (see above)." },
        { id = 3, unit = nil,      note = "NOTE: on units you can assist, these spell categories are not applied (see above)." },
        { id = 1, unit = "target", note = "NOTE: on units you can't assist, these spell categories are not applied (see above)." },
        { id = 1, unit = "focus",  note = "NOTE: on units you can't assist, these spell categories are not applied (see above)." },
    }
    for _, c in ipairs(cases) do
        local NS, _, _, ws = categoriesOn(c.id, c.unit)
        local where = ("container %d on %s"):format(c.id, tostring(c.unit))
        local at = indexOfText(ws, NS.L[c.note])
        -- red under: no NOTE line drawn, the wrong unit wording for this container, or the line
        -- without its pointer to the Situations tab (SI-05)
        assertTrue(at ~= nil, where .. " draws: " .. c.note)
        local heading = indexOfText(ws, NS.L["Spell categories"])
        local showAll = indexOfText(ws, NS.L["Show all"])
        -- red under: the NOTE drawn anywhere but straight under the heading
        assertTrue(heading ~= nil and heading < at, where .. ": under the Spell categories heading")
        local buttons
        for i = heading, #ws do
            if ws[i].text == NS.L["Show all"] then buttons = i break end
        end
        assertTrue(showAll ~= nil and buttons ~= nil and at < buttons, where .. ": above the grid's own buttons")
    end
end)

test("filters: no Spell categories NOTE on a buff container on the player or the pet (SV-04)", function()
    for _, unit in ipairs({ "player", "pet" }) do
        local _, _, P, ws = categoriesOn(1, unit)
        -- red under: the NOTE gated on anything but FC.IdsMode ~= "always"
        assertFalse(P.hasText(ws, "these spell categories are not applied"), unit .. " buffs: spell ids always apply")
    end
end)

--- The lines a widget's tooltip draws when hovered, via the mocked GameTooltip's :AddLine (the
--- idiom this suite already uses below for the Overrides tooltip).
local function tooltipLines(m, widget)
    local lines = {}
    rawset(m.GameTooltip, "AddLine", function(_, s)
        lines[#lines + 1] = s
    end)
    widget:__fire("OnEnter")
    return table.concat(lines, "\n")
end

test("filters: a spells-kind row's See spells link selects that category on the General page > Spell categories and lands there; a token row gets an info icon instead (F-3/N-3/N-4/N-5)", function()
    local NS, m, P = filters()
    P.show("General") -- render once, so H.SelectTab (K-4) has a rendered ctx to land the click on
    local ws = P.tab("filters", NS.L["Categories"])
    local kids = gridLine(NS, ws, "healing")
    local link = kids[4]
    -- N-4: the link is an interactive control, not plain text — it carries a tooltip saying where
    -- it goes, and its text is colored (the color code is ASCII, never baked into the locale value).
    assertTrue(link ~= nil and link.type == "InteractiveLabel", "a spells-kind row carries the link")
    assertTrue(link.text:find(NS.L["See spells"], 1, true) ~= nil, "carries the See spells text")
    assertTrue(tooltipLines(m, link):find("General", 1, true) ~= nil, "the tooltip says where it goes")
    -- red under: onClick reaching the wrong seam, or reaching none at all
    link:__fire("OnClick")
    -- N-3: this used to land on the addon's main panel (categories["general"] was never recorded
    -- because General registers through the plain NS.RegisterOptionsPage). Landing on General ->
    -- Spell categories, not the main panel, is exactly what N-3 fixed.
    assertEqual(NS.Helpers.__pageCtx.general.activeTab, NS.L["Spell categories"], "lands on the General page > Spell categories")
    local gws = P.rerender("General")
    local dd = P.find(gws, "Dropdown", NS.L["Category"])
    assertEqual(dd.value, "healing", "and selects the row's own category there")
    -- N-5: a Blizzard token row gets an info icon in the same column instead of a link — never
    -- both, and never the See spells text.
    local bigDef = gridLine(NS, ws, "bigDefensive")
    local icon = bigDef and bigDef[4]
    assertTrue(icon ~= nil and icon.type == "InteractiveLabel", "a token row's grid line carries the info icon")
    assertTrue(icon.text:find(NS.L["See spells"], 1, true) == nil, "never the See spells text")
    local iconTip = tooltipLines(m, icon)
    assertTrue(iconTip:find("illustrative", 1, true) ~= nil,
        "N-5: the tooltip says the examples are illustrative, not authoritative")
    assertTrue(iconTip:find("secure", 1, true) ~= nil or iconTip:find("cannot list", 1, true) ~= nil,
        "N-5: the tooltip says the addon cannot enumerate the category")
    -- Decision #3: the enchant row gets the link too, since that tab can also draw it
    local enchantKids = gridLine(NS, ws, "weaponEnchants")
    assertTrue(enchantKids[4].text:find(NS.L["See spells"], 1, true) ~= nil, "the enchant row's link too")
    -- A "who cast it" flag row (fromPlayers) is the addon's own computation, not a Blizzard secret
    -- (it lives in its own "Who cast it" grid) — it carries no extra cell either. Categories is
    -- already the active tab, so switching container and rerendering redraws it directly — a
    -- second click on the tab that is already active draws nothing new (page_helpers.lua's P.tab).
    NS.Helpers.SelectContainer(2)
    local ws2 = P.rerender("Filters")
    local whoRow = gridLine(NS, ws2, "fromPlayers")
    assertTrue(whoRow ~= nil and whoRow[4] == nil, "a caster-identity flag row carries no extra cell")
end)

-- ── the priority block (F-4) ──────────────────────────────────────────────────────────────────

-- BATCH 8 (owner, from a screenshot): the five ranks used to be restated at the TOP of both the
-- Categories and the Overrides tab. They are now drawn ONCE, at the foot of the first tab (called
-- What to show then, General since 2026-09-20). The expectations below moved with the behavior —
-- the order itself, and every word of it, is unchanged.

test("filters: the priority order (spec §6) is stated on the General tab, highest rank first", function()
    -- General is the page's FIRST tab, so the show's own draw is that tab's (a click on the
    -- active tab draws nothing — tests/page_helpers.lua).
    local _, _, P, ws = filters()
    -- red under: the block missing from the tab, or restating the superseded blacklist-first order
    assertTrue(P.hasText(ws, "whitelist"), "names the whitelist")
    assertTrue(P.hasText(ws, "blacklist"), "names the blacklist")
    assertTrue(P.hasText(ws, "set to Show"), "Show is its own rank, not the absence of Hide")
    assertTrue(P.hasText(ws, "all say Hide"), "only an aura hidden by every one of its categories is removed")
end)

test("filters: the priority block is stated once — not on Categories, not on Overrides (batch 8)", function()
    local NS, _, P = filters()
    for _, key in ipairs({ NS.L["Categories"], "overrides" }) do
        local ws = P.tab("filters", key)
        -- red under: either tab keeping its copy of the five-line wall the owner asked to be rid of
        assertFalse(P.hasText(ws, "Highest priority first"), key .. " carries no lead-in")
        for _, t in ipairs(P.texts(ws)) do
            assertFalse(t:find("^1%. On the Overrides whitelist") ~= nil, key .. " carries no rank line")
        end
    end
end)

-- T-2 (batch 7) gave each rank its own line; batch 8 kept that and framed it — an H.Section heading,
-- the lead-in in the normal font, the ranks in GameFontHighlight rather than the Label default's
-- small font, and a gap between them. The wording is verbatim what it was.
test("filters: the priority block is a heading, a lead-in and five separate rank lines (T-2, batch 8)", function()
    local NS, _, P, ws = filters()
    local found = {}
    for _, t in ipairs(P.texts(ws)) do
        for rank = 1, 5 do
            if t:find("^" .. rank .. "%.") then found[rank] = t end
        end
    end
    for rank = 1, 5 do
        -- red under: a rank folded back into a shared paragraph rather than its own Label line
        assertTrue(found[rank] ~= nil, "rank " .. rank .. " is its own line")
    end
    assertTrue(found[1]:find("whitelist", 1, true) ~= nil, "rank 1 is the whitelist")
    assertTrue(found[2]:find("blacklist", 1, true) ~= nil, "rank 2 is the blacklist")
    assertTrue(found[3]:find("set to Show", 1, true) ~= nil, "rank 3 is the positive Show claim")
    assertTrue(found[4]:find("all say Hide", 1, true) ~= nil, "rank 4 is the all-Hide case")
    assertTrue(found[5]:find("no category at all", 1, true) ~= nil, "rank 5 is the uncategorized case")
    assertTrue(P.hasText(ws, "Highest priority first"), "the lead-in line still introduces the order")
    -- red under: the block drawn as bare text again, with nothing announcing or separating it
    local heads = headings(ws)
    assertEqual(heads[#heads], NS.L["Filter priority logic"], "a Section heading announces it, last on the tab")
end)

-- The block is a FOOTNOTE to the tab: every one of the tab's own controls is drawn before it.
test("filters: the priority block is drawn under the General rows, not above them (batch 8)", function()
    local NS, _, _, ws = filters()
    local lastRow, firstRankLine
    for i, w in ipairs(ws) do
        if w.labelText == NS.L["Maximum duration (seconds, 0 = no limit)"] or w.labelText == NS.L["Cast by"]
            or w.labelText == NS.L["Duration"] or w.labelText == NS.L["Sort by"]
            or w.labelText == NS.L["Maximum auras per group (0 = no limit)"] then
            lastRow = i
        end
        if not firstRankLine and type(w.text) == "string"
            and w.text:find("^1%. On the Overrides whitelist") then
            firstRankLine = i
        end
    end
    assertTrue(lastRow ~= nil and firstRankLine ~= nil, "both the rows and the block drew")
    -- red under: the block hoisted back above the controls it is a footnote to
    assertTrue(lastRow < firstRankLine, "every General control comes first")
end)

-- 2026-09-20 (owner, from the live panel): the ranks read one size LARGER than the Overrides tab's
-- own Whitelist/Blacklist notes and shouted. Both now take the AceGUI Label default — which the
-- notes get by passing no opts at all — and the lead-in drops to GameFontNormalSmall so it shrinks
-- with them while keeping the normal font's color. LibKa0s/OptionsWidgets.lua's applyLabelFont only
-- overrides the face when a NAME is passed, so "no fontObject" is what "the default size" means.
test("filters: the priority ranks read at the same size as the Overrides notes (2026-09-20)", function()
    local NS, m = fresh()
    local P = pages(NS, m)
    local H = NS.Helpers
    local seen = {}
    local textRow = H.TextRow
    H.TextRow = function(ctx, text, opts)
        seen[text] = opts or false
        return textRow(ctx, text, opts)
    end
    P.show("Filters")
    P.tab("filters", "overrides")
    H.TextRow = textRow
    -- red under: the lead-in back at GameFontNormal, a full step above the ranks under it
    assertEqual(seen[NS.L["Highest priority first:"]].fontObject, "GameFontNormalSmall")
    -- red under: a fontObject back on the rank lines (GameFontHighlight, the larger face)
    local rank = seen[NS.L["1. On the Overrides whitelist — always shown."]]
    assertTrue(rank == false or rank.fontObject == nil, "a rank line names no font object")
    -- the Whitelist note is the yardstick: it passes no opts, so it IS the Label default
    local note = seen[NS.L["These spells are shown whatever the categories say. Blizzard only honors this for buffs on units you can assist and debuffs on units you can't."]]
    assertEqual(note, false, "the Overrides note names no font object either")
end)

-- BATCH 8: Overrides moved up to sit beside Categories — the two halves of one decision — and
-- Sorting, which only orders whatever survived them, follows. SI-05: Situations, which says what
-- draws where the spell lists cannot, is the last tab, after Sorting.
test("filters: the four tabs read General, Categories, Overrides, Situations (batch 8, SI-05, AUR-L02)", function()
    local NS, _, P = filters()
    local L = NS.L
    -- red under: the overrides tab appended after Sorting again (its `before` dropped), or the first
    -- tab back at "What to show" (renamed 2026-09-20), or Situations anywhere but last
    assertEqual(table.concat(P.tabKeys("filters"), ","),
        table.concat({ L["General"], L["Categories"], "overrides", L["Situations"] }, ","))
    -- red under: tabs keyed globally rather than per page, which would fuse this General with the
    -- Text and Bars pages' own General tabs (the library's O.RenderTabbedSchema builds a strip
    -- out of NS.SchemaForPage(pageKey) alone, so the name is the PAGE's)
    NS.Helpers.SelectContainer(4)                   -- the starter drawn as text
    P.show("Text")
    assertEqual(P.tabKeys("text")[1], L["General"], "the Text page keeps its own General tab")
    NS.Helpers.SelectContainer(1)                   -- back to the bars starter
    P.show("Bars")
    assertEqual(P.tabKeys("bars")[1], L["General"], "so does the Bars page")
end)

-- Fix round 2 (batch 7): "Only these categories" (D8/R-8..R-11) is retired — the owner chose one
-- concept (`Uncategorized = Hide`) over two controls that needed explaining against each other. No
-- row, no checkbox, no "not shown" note. Its removal is covered as absence, not a positive test of
-- its own — there is no control left to assert anything about.
test("filters: the retired 'Only these categories' row is gone — no such control on the Categories tab", function()
    local NS = filters()
    -- red under: the schema row surviving removal (P.row asserts a row exists, so it cannot be used
    -- to prove absence — it is the schema lookup itself that must answer nil).
    assertNil(NS.FindSchemaRow("container.filter.onlyShown"), "no such schema row any more")
end)

test("filters: a grid checkbox stores show or hide for the selected container and re-syncs its line", function()
    local NS, _, _, ws = categories()
    NS.Helpers.__pageCtx.filters.panel:Show()   -- on screen, so a write re-syncs the widgets in place
    local cells = gridLine(NS, ws, "defensives")
    -- red under: LibKa0s v1.36.0+ draws choice cells as CheckBox widgets, not radios
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
    local want = { spells = "custom", token = "blizzard", flag = "blizzard", dispel = "dispel", enchant = "custom", uncategorized = "custom" }
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

test("filters: no aura type is offered a Spell lists tab; the lists live on General → Spell categories", function()
    local NS, _, P = filters()
    for _, auraType in ipairs({ "HELPFUL", "HARMFUL" }) do
        NS.SetByPath("container.auraType", auraType, 1)
        P.rerender("Filters")
        for _, k in ipairs(P.tabKeys("filters")) do
            -- red under: the Filters page still registering its spellLists tab (G-2)
            assertTrue(k ~= "spellLists", auraType .. ": " .. k)
        end
    end
end)

-- ── Show all / Hide all (feedback #10) ────────────────────────────────────────────────────────

--- The category keys `auraType` draws in grid `grid` ("blizzard" | "custom" | "dispel" | "who"), in declaration order.
local function gridKeys(NS, auraType, grid)
    local out = {}
    for _, def in ipairs(NS.Categories.For(auraType)) do
        local row = NS.FindSchemaRow("container.filter.categories." .. def.key)
        if row.grid == grid then
            local n = #out
            out[n + 1] = def.key
        end
    end
    return out
end

--- Record every [Set] and [Apply] line, rendered `[Tag] text`, with debug on.
local function captureLog(NS)
    NS.State.debug = true
    local lines = {}
    NS.Debug = function(tag, fmt, ...)
        if tag ~= "Set" and tag ~= "Apply" then return end
        local args = { ... }
        for i = 1, select("#", ...) do args[i] = tostring(args[i]) end
        local n = #lines
        lines[n + 1] = ("[%s] %s"):format(tag, fmt:format(unpack(args)))
    end
    return lines
end

--- Heading and button text -> the widget indexes it sits at, in order.
local function positions(ws)
    local at = {}
    for i, w in ipairs(ws) do
        local key = (w.type == "Heading" and w.text) or (w.type == "Button" and w.text) or nil
        if key then
            at[key] = at[key] or {}
            table.insert(at[key], i)
        end
    end
    return at
end

test("filters: Show all and Hide all head every Categories section, one pair each (feedback #10, B11-T10)", function()
    -- the player's buffs draw two sections; the player's debuffs draw all four
    local expect = {
        [1] = { "Blizzard categories", "Spell categories" },
        [2] = { "Blizzard categories", "Spell categories", "Dispel types", "Who cast it" },
    }
    for _, id in ipairs({ 1, 2 }) do
        local NS, _, _, ws = categories(id)
        local L = NS.L
        local at = positions(ws)
        local shows, hides = at[L["Show all"]] or {}, at[L["Hide all"]] or {}
        local sections = expect[id]
        local showCount, hideCount, sectionCount = #shows, #hides, #sections
        -- red under: no pair on Dispel types / Who cast it, or a pair too many
        assertEqual(showCount, sectionCount, "container " .. id .. ": one Show all per section")
        assertEqual(hideCount, sectionCount, "container " .. id .. ": one Hide all per section")
        for i, heading in ipairs(sections) do
            local here = at[L[heading]][1]
            local nextHeading = sections[i + 1] and at[L[sections[i + 1]]][1] or math.huge
            assertTrue(here < shows[i] and shows[i] < nextHeading, "pair " .. i .. " heads " .. heading)
            assertTrue(here < hides[i] and hides[i] < nextHeading, "pair " .. i .. " heads " .. heading)
        end
    end
end)

test("filters: Show all / Hide all on Dispel types and Who cast it set exactly their own section, for this container only (B11-T10)", function()
    local NS, m, P, ws = categories(2)   -- the player's debuffs
    local c, other = NS.Database.FindContainer(2), NS.Database.FindContainer(3)
    local keys = {}
    for _, grid in ipairs({ "blizzard", "custom", "dispel", "who" }) do
        keys[grid] = gridKeys(NS, "HARMFUL", grid)
    end
    local dispelCount, whoCount = #keys.dispel, #keys.who
    assertTrue(dispelCount > 1 and whoCount > 1, "both sections have rows")
    local before, otherBefore = {}, {}
    for key, state in pairs(c.filter.categories) do before[key] = state end
    for key, state in pairs(other.filter.categories) do otherBefore[key] = state end
    m.__fireTimers()
    local lines = captureLog(NS)
    P.all(ws, "Button", NS.L["Hide all"])[3]:__fire("OnClick")    -- Dispel types
    m.__fireTimers()
    -- red under: no Hide all on Dispel types, or one reaching past its own section
    for _, key in ipairs(keys.dispel) do assertEqual(c.filter.categories[key], "hide", key) end
    for _, grid in ipairs({ "blizzard", "custom", "who" }) do
        for _, key in ipairs(keys[grid]) do
            assertEqual(c.filter.categories[key], before[key], key .. " is another section's")
        end
    end
    assertEqual(table.concat(lines, " | "),
        ("[Set] hide all dispel categories of container 2: %d rows | [Apply] applied 1 container(s)"):format(dispelCount))
    P.all(ws, "Button", NS.L["Hide all"])[4]:__fire("OnClick")    -- Who cast it
    for _, key in ipairs(keys.who) do assertEqual(c.filter.categories[key], "hide", key) end
    P.all(ws, "Button", NS.L["Show all"])[3]:__fire("OnClick")    -- Dispel types again
    for _, key in ipairs(keys.dispel) do assertEqual(c.filter.categories[key], "show", key) end
    -- red under: Show all on Dispel types reaching Who cast it
    for _, key in ipairs(keys.who) do assertEqual(c.filter.categories[key], "hide", key .. " stays hidden") end
    for key, state in pairs(otherBefore) do
        -- red under: the buttons writing every debuff container, not the selected one
        assertEqual(other.filter.categories[key], state, "container 3's " .. key)
    end
end)

test("filters: Hide all on Blizzard categories hides exactly that section, as one [Set] line and one apply (feedback #10)", function()
    local NS, m, P, ws = categories()
    local c = NS.Database.FindContainer(1)
    local blizzard, custom = gridKeys(NS, "HELPFUL", "blizzard"), gridKeys(NS, "HELPFUL", "custom")
    local blizzardCount, customCount = #blizzard, #custom
    assertTrue(blizzardCount > 1 and customCount > 1, "both sections have rows")
    m.__fireTimers()
    local lines = captureLog(NS)
    P.all(ws, "Button", NS.L["Hide all"])[1]:__fire("OnClick")
    m.__fireTimers()
    for _, key in ipairs(blizzard) do
        -- red under: a key of the section left out of the write
        assertEqual(c.filter.categories[key], "hide", key)
    end
    for _, key in ipairs(custom) do
        -- red under: the button writing every category of the aura type, not its own section's
        assertEqual(c.filter.categories[key], "show", key .. " is another section's")
    end
    -- red under: one [Set] line per row (no bulk bracket), or one apply pass per row
    assertEqual(table.concat(lines, " | "),
        ("[Set] hide all blizzard categories of container 1: %d rows | [Apply] applied 1 container(s)"):format(blizzardCount))
end)

test("filters: Show all on Spell categories shows exactly that section, whatever Blizzard categories say (feedback #10)", function()
    local NS, _, P, ws = categories()
    local c = NS.Database.FindContainer(1)
    local blizzard, custom = gridKeys(NS, "HELPFUL", "blizzard"), gridKeys(NS, "HELPFUL", "custom")
    P.all(ws, "Button", NS.L["Hide all"])[1]:__fire("OnClick")    -- Blizzard categories: all Hide
    P.all(ws, "Button", NS.L["Hide all"])[2]:__fire("OnClick")    -- Spell categories: all Hide
    P.all(ws, "Button", NS.L["Show all"])[2]:__fire("OnClick")    -- Spell categories: all Show
    for _, key in ipairs(custom) do assertEqual(c.filter.categories[key], "show", key) end
    for _, key in ipairs(blizzard) do
        -- red under: Show all reaching past its own section
        assertEqual(c.filter.categories[key], "hide", key .. " stays hidden")
    end
end)
