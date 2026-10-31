-- tests/test_pages_filters_overrides.lua — the Filters page's Overrides tab: the Whitelist and Blacklist
-- sections and each entry's note. Peeled out of tests/test_pages_filters.lua by theme.

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

--- The line an IdList drew for spell `id`: its label, and the X at the line's left
--- (`removeStyle = "icon"`, B2).
---
--- WALKED PER CHILD, not by position. Two things moved under this helper's feet: these lists pack
--- two entries to a Flow row (`columns = 2`), so the right-hand entry was never at `children[2]`
--- at all; and since LibKa0s v1.51.0 an entry that has something to say draws a "?" mark BETWEEN
--- its X and its name, so the Icon immediately before a label may be the mark rather than the X.
--- The mark is the Icon that records `__helpTint` (libs/LibKa0s/OptionsIdList.lua:615),
--- which is exactly how tests/general_page_helpers.lua tells the two Icons apart.
local function entry(ws, id)
    for _, w in ipairs(ws) do
        local kids = w.children or {}
        for i, lbl in ipairs(kids) do
            if lbl.type == "InteractiveLabel" and type(lbl.text) == "string" then
                local t = lbl.text
                if t:find("(" .. id .. ")|r", 1, true) or t == "Unknown spell " .. id then
                    local x = kids[i - 1]
                    if x and x.__helpTint then x = kids[i - 2] end
                    return lbl, x
                end
            end
        end
    end
    return nil
end

--- The lines entry `id`'s "?" help mark carries, joined; "" for a mark with nothing behind it, and
--- nil when the entry drew no mark at all — which on this page means the LIST it sits in had
--- nothing to say about anything, since `listHasHelp` is asked once per list
--- (libs/LibKa0s/OptionsIdList.lua:464-470) and a list with no help draws no marks.
---
--- `nth` picks between the two lists: the Whitelist draws first, so an id sitting on both is the
--- first match on the whitelist and the second on the blacklist.
---
--- WALKED IN ORDER for the reason tests/general_page_helpers.lua gives: the library draws
--- [X] [?] [label] per entry, two entries to a row, so the mark in force when a label is reached
--- is the one belonging to it.
local function entryHelp(ws, id, nth)
    local seen = 0
    for _, w in ipairs(ws) do
        local mark
        for _, kid in ipairs(w.children or {}) do
            if kid.type == "Icon" and kid.__helpTint then
                mark = kid
            elseif kid.type == "InteractiveLabel" and type(kid.text) == "string" then
                local drawn = kid.text:match("%((%d+)%)|r") or kid.text:match("^Unknown spell (%d+)")
                if drawn and tonumber(drawn) == id then
                    seen = seen + 1
                    if seen == (nth or 1) then
                        if not mark then return nil end
                        if not mark.__helpLines then return "" end
                        return table.concat(mark.__helpLines, "\n")
                    end
                end
                mark = nil   -- the next entry in this row brings its own
            end
        end
    end
    return nil
end

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

-- SV-04 (V3/V4): the Overrides tab is headed by the same NOTE shape. Its whitelist group and every
-- spell-id exclusion are gone in the blizzard view, so on those units the lists do nothing.
test("filters: the Overrides NOTE heads the tab on every container whose spell lists can be off (SV-04)", function()
    local cases = {
        { id = 2, unit = nil,      note = "NOTE: on your own debuffs, these Overrides are not applied (see Categories)." },
        { id = 2, unit = "pet",    note = "NOTE: on your pet's debuffs, these Overrides are not applied (see Categories)." },
        { id = 3, unit = nil,      note = "NOTE: on units you can assist, these Overrides are not applied (see Categories)." },
        { id = 1, unit = "target", note = "NOTE: on units you can't assist, these Overrides are not applied (see Categories)." },
    }
    for _, c in ipairs(cases) do
        local NS, _, P = filters()
        if c.unit then NS.SetByPath("container.unit", c.unit, c.id) end
        NS.Helpers.SelectContainer(c.id)
        P.show("Filters")
        local ws = P.tab("filters", "overrides")
        local where = ("container %d on %s"):format(c.id, tostring(c.unit))
        local at, whitelist
        for i, w in ipairs(ws) do
            if w.text == NS.L[c.note] and not at then at = i end
            if w.type == "Heading" and w.text == NS.L["Whitelist"] and not whitelist then whitelist = i end
        end
        -- red under: no NOTE on the Overrides tab, one drawn below the Whitelist heading, or one
        -- without its pointer to the Situations tab (SI-05)
        assertTrue(at ~= nil, where .. " draws: " .. c.note)
        assertTrue(whitelist ~= nil and at < whitelist, where .. ": the NOTE heads the tab")
    end
    local _, _, P = filters()
    local ws = P.tab("filters", "overrides")
    -- red under: the Overrides NOTE drawn on the player's own buffs, where ids always apply
    assertFalse(P.hasText(ws, "these Overrides are not applied"), "player buffs: no NOTE")
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
    -- red under: the Overrides list without removeStyle = "icon" (a Remove button on the right)
    assertEqual(remove.type, "Icon")
    remove:__fire("OnClick")
    assertNil(next(NS.Database.FindContainer(1).filter.whitelist), "the whitelist is empty again")
    assertEqual(NS.Database.FindContainer(1).filter.blacklist[12345], true, "the blacklist is not")
end)

-- The Overrides lists pack TWO entries to a Flow row, as the Spell categories list does
-- (`columns`, LibKa0s v1.47.0 / OptionsWidgets minor 24; the canvas fit that makes it a MAXIMUM is
-- v1.50.0, minor 27). Pinned here because the reason is a CONSISTENCY one rather than a length one
-- -- an override list is short, so nothing about its own scroll would notice a silent return to one
-- entry a row, and the point of the option here is that these rows look like General's.
test("filters: the Overrides lists pack two entries to a row, row-major", function()
    local NS, _, P = filters()
    -- Through the seam, not by writing the table: the page reads the container the seam wrote,
    -- and settings/Filters.lua's own edit() puts the whole set back through `container.filter.*`.
    NS.SetByPath("container.filter.whitelist", { [774] = true, [8936] = true, [33763] = true })
    -- SAY WHAT CANVAS THIS PACKS INTO: the kit's ScrollFrame fixture is 400, 380 of content once
    -- OptionsScroll takes its gutter, which is under the icon style's 520px floor for two columns.
    -- Unarmed, the library correctly draws ONE column and this case asserts the fixture.
    P.canvasWidth(700)
    local ws = P.tab("filters", "overrides")
    local rows, seen = {}, {}
    for _, w in ipairs(ws) do
        local kids = type(w.children) == "table" and w.children or {}
        local col = 0
        for _, kid in ipairs(kids) do
            if type(kid) == "table" and kid.type == "InteractiveLabel" and type(kid.text) == "string" then
                local id = kid.text:match("%((%d+)%)|r") or kid.text:match("^Unknown spell (%d+)")
                if id and not seen[id] then
                    seen[id] = true
                    col = col + 1
                    rows[#rows + 1] = { id = tonumber(id), row = w, col = col }
                end
            end
        end
    end
    assertTrue(#rows >= 3, "the three whitelisted ids are drawn")
    -- red under no `columns` (each entry takes a row of its own), and red under column-major.
    assertEqual(rows[1].row, rows[2].row, "the first two share one row")
    assertEqual(rows[1].col, 1, "the first is the left column")
    assertEqual(rows[2].col, 2, "the second is beside it, not under it")
    assertTrue(rows[3].row ~= rows[2].row, "the third starts the next row down")
    assertEqual(rows[3].col, 1, "and is the left column of that row")
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
    local warning = "|cffffa040" .. NS.L[NS.FilterCompiler.WARN.TIMELESS_BUFFS_ONLY] .. "|r"
    local ws = P.rerender("Filters")
    assertFalse(P.hasText(ws, "|cffffa040"), "a container the engine honors whole has no warning")
    NS.SetByPath("container.auraType", "HARMFUL", 1)
    NS.SetByPath("container.filter.durationMode", "timeless", 1)
    ws = P.rerender("Filters")
    -- red under: the page's intro not calling RenderWarnings
    assertTrue(P.hasText(ws, warning), "General")
    ws = P.tab("filters", NS.L["Situations"])
    assertTrue(P.hasText(ws, warning), "and every other tab")
end)

-- ── Overrides entry notes (task B6, spec §6/§6c) ─────────────────────────────────────────────────

-- A plain WHITELIST entry with nothing to disagree with it has no note: the categories already
-- agree it is shown (774 is in the real, unnarrowed "healing" list, at its default Show), so the
-- whitelist entry is not overriding anything. A plain, uncategorized BLACKLIST entry is different
-- (fix round 2): the ordinary catch-all WOULD draw it if the entry were removed, which is exactly
-- the mismatch task-B6's other tests exercise, so it is covered separately below rather than folded
-- into a single "plain entry has no note" claim that is no longer true for the blacklist side.
test("filters: a plain whitelist entry with nothing to disagree has no note", function()
    local NS, _, P = filters()
    NS.SetByPath("container.filter.whitelist", { [774] = true }, 1)
    local ws = P.tab("filters", "overrides")
    -- red under: a note drawn for every entry regardless of whether anything disagrees
    assertFalse(P.hasText(ws, "overriding"), "no category conflict to report")
    assertFalse(P.hasText(ws, "outranks"), "not on the other list either")
end)

-- red under: the blacklist entry not reporting that the whitelist already claimed the same id
test("filters: a spell on both lists gets a note on its blacklist entry saying the whitelist wins", function()
    local NS, _, P = filters()
    NS.SetByPath("container.filter.whitelist", { [500] = true }, 1)
    NS.SetByPath("container.filter.blacklist", { [500] = true }, 1)
    local ws = P.tab("filters", "overrides")
    -- In the MARK now, not on a line of its own (LibKa0s v1.51.0). The blacklist's entry for this
    -- id is the SECOND the page draws for it, the whitelist having drawn the first.
    assertFalse(P.hasText(ws, "outranks the blacklist"), "nothing is drawn under the entry")
    assertTrue(entryHelp(ws, 500, 2):find(NS.L["Shown here anyway — it is also on the whitelist, which outranks the blacklist."], 1, true) ~= nil)
end)

-- red under: the whitelist entry not reporting that it is also blacklisted
test("filters: a spell on both lists gets a note on its whitelist entry naming the blacklist too", function()
    local NS, _, P = filters()
    NS.SetByPath("container.filter.whitelist", { [500] = true }, 1)
    NS.SetByPath("container.filter.blacklist", { [500] = true }, 1)
    local ws = P.tab("filters", "overrides")
    assertFalse(P.hasText(ws, "Also on the blacklist"), "nothing is drawn under the entry")
    assertTrue(entryHelp(ws, 500, 1):find(NS.L["Also on the blacklist, but the whitelist outranks it — still shown here."], 1, true) ~= nil)
end)

-- red under: a blacklisted spell that a Show category would rescue not reporting the conflict
test("filters: a blacklisted spell in a Show category names that category as overridden", function()
    local NS, _, P = filters()
    NS.SetByPath("container.filter.blacklist", { [900001] = true }, 1)
    NS.SetByPath("categorySpells", { defensives = { [900001] = true } })
    local ws = P.tab("filters", "overrides")
    assertTrue(entryHelp(ws, 900001):find(("overriding %s (set to Show)"):format(NS.L["Defensive cooldowns"]), 1, true) ~= nil)
end)

-- red under: a whitelisted spell whose categories all say Hide not reporting the conflict
test("filters: a whitelisted spell every one of its categories would hide names them as overridden", function()
    local NS, _, P = filters()
    NS.SetByPath("container.filter.whitelist", { [900002] = true }, 1)
    NS.SetByPath("categorySpells", { defensives = { [900002] = true } })
    NS.SetByPath("container.filter.categories.defensives", "hide", 1)
    local ws = P.tab("filters", "overrides")
    assertTrue(entryHelp(ws, 900002):find(("overriding %s (set to Hide)"):format(NS.L["Defensive cooldowns"]), 1, true) ~= nil)
end)

-- red under: a blacklisted spell in a Hide-only category getting a spurious note (the blacklist and
-- the category already agree, so there is nothing to explain)
test("filters: a blacklisted spell a Hide category would also hide gets no note", function()
    local NS, _, P = filters()
    NS.SetByPath("container.filter.blacklist", { [900003] = true }, 1)
    NS.SetByPath("categorySpells", { defensives = { [900003] = true } })
    NS.SetByPath("container.filter.categories.defensives", "hide", 1)
    local ws = P.tab("filters", "overrides")
    -- READ THE MARK, not the drawn text. Once the sentence lives in a tooltip, a hasText check for
    -- it can only ever pass, so the "no verdict here" claim has to be made where the verdict now
    -- is: `listHasHelp` is asked once per list, and this list has nothing to say about anything in
    -- it, so it draws no mark at all rather than a dimmed one.
    assertTrue(entry(ws, 900003) ~= nil, "the entry is drawn")
    assertNil(entryHelp(ws, 900003), "the blacklist and the category agree, so there is no mark")
    assertFalse(P.hasText(ws, "overriding"), "and nothing under it either")
end)

-- THE WHOLE REASON THE SENTENCES MOVED INTO THE MARK. A `note` is a full-width second line, so the
-- library gives a noted entry a row of ITS OWN whatever the column count (`entryNoted`,
-- libs/LibKa0s/OptionsIdList.lua:942-944) -- which on a list that asked for two columns meant
-- every entry with a verdict punched a hole through the grid, the exact complaint the help mark
-- was introduced to answer (owner, 2026-09-22).
--
-- red under a `note`: these two entries land on rows of their own and the grid is not a grid.
test("filters: an entry with a verdict keeps its place in the two-column grid", function()
    local NS, _, P = filters()
    -- Both are claimed by a Show category, so the blacklist has a verdict to state about EACH --
    -- one noted entry alone would still pair with nothing and prove less.
    NS.SetByPath("categorySpells", { defensives = { [900001] = true, [900002] = true } })
    NS.SetByPath("container.filter.blacklist", { [900001] = true, [900002] = true }, 1)
    -- The canvas the columns fit into, as the packing case above sets it: the kit's fixture is
    -- under the icon style's floor for two columns, and unarmed the library correctly draws one.
    P.canvasWidth(700)
    local ws = P.tab("filters", "overrides")
    local rowOf = {}
    for r, w in ipairs(ws) do
        for _, kid in ipairs(w.children or {}) do
            if kid.type == "InteractiveLabel" and type(kid.text) == "string" then
                local drawn = kid.text:match("^Unknown spell (%d+)")
                if drawn then rowOf[tonumber(drawn)] = r end
            end
        end
    end
    assertTrue(rowOf[900001] ~= nil and rowOf[900002] ~= nil, "both blacklisted ids are drawn")
    assertEqual(rowOf[900001], rowOf[900002], "and share one row, as every other pair of entries does")
    assertTrue(entryHelp(ws, 900001):find("overriding", 1, true) ~= nil, "the verdict is in the mark")
    assertFalse(P.hasText(ws, "overriding"), "and on no line of its own")
end)

-- Fix round 2 of batch 7 retired "Only these categories" (D8) entirely, and with it went the one
-- scenario where a whitelisted, wholly unclaimed id's counterfactual was "hidden" at rank 5: rank 5
-- is now unconditionally "shown" wherever no `uncategorized` category exists for the aura type
-- (HARMFUL — buffs only, fix round 1). A plain whitelisted debuff with nothing else deciding it is
-- therefore never rescuing anything any more, so it earns no note; the test this comment used to
-- introduce ("...warns it would vanish") tested exactly that now-impossible case and is gone with it.

-- Fix round 2: an uncategorized blacklisted spell would be drawn by the ordinary catch-all if the
-- entry were removed (rank 5, shown) — a real mismatch a rank-3-only check misses, mirroring the
-- whitelist case above (batch 6 fix round 2).
-- red under: overrideNote's blacklist branch checking `cat.rank == 3` instead of `cat.verdict == "shown"`
--
-- batch 7 fix round 1: moved to container 2 (HARMFUL) for the reason above — on a buff container
-- this id's counterfactual now goes through `explainUncategorized` (rank 3, the default Show), not
-- the plain rank-5 catch-all this note's wording describes.
test("filters: an uncategorized blacklisted spell warns that no category hides it", function()
    local NS, _, P = filters()
    NS.Helpers.SelectContainer(2)
    P.show("Filters")
    NS.SetByPath("container.filter.blacklist", { [900005] = true }, 2)
    local ws = P.tab("filters", "overrides")
    assertTrue(entryHelp(ws, 900005):find("no category here hides it", 1, true) ~= nil,
        "no category claims it, but the ordinary catch-all would still draw it")
end)

-- The buff-side mirror of the test above (batch 7, U-1..U-5): with `uncategorized` present, an
-- unclaimed id's fate is always decided by ITS state, never left to the generic rank-5 wording.
test("filters: a whitelisted spell no category claims, on a buff container, names Uncategorized instead of the generic rank-5 wording", function()
    local NS, _, P = filters()
    NS.SetByPath("container.filter.whitelist", { [900004] = true }, 1)
    NS.SetByPath("container.filter.categories.uncategorized", "hide", 1)
    local ws = P.tab("filters", "overrides")
    assertTrue(entryHelp(ws, 900004):find("overriding Uncategorized (set to Hide)", 1, true) ~= nil,
        "the counterfactual is rank 4 (Uncategorized itself says Hide), not the generic rank-5 case")
end)
