-- tests/test_pages_general.lua — settings/General.lua and settings/GeneralSpells.lua, driven
-- through their widgets: what each Master control and Display row writes, what each one's effect is,
-- the two buttons the composer adds, the page's Defaults, the Spell Categories ID list and its
-- restore, and the Dispel Colors rows. The top-level Containers page — its picker and New container
-- in the band above the strip (options-ui-§14), its identity rows and the acts on the selected
-- container (Duplicate, Delete, Copy settings from) — moved out to its own page (N-1, batch 7) and is
-- tests/test_pages_containers.lua's now. Every case builds a fresh environment, because every case
-- clicks something.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local pages = dofile("tests/page_helpers.lua")

--- A fresh environment with the General page drawn; `tab(name)` clicks a tab and answers what that
--- render drew.
local function general(opts)
    local NS, m = fresh(opts)
    local P = pages(NS, m)
    local ws = P.show("General")
    local function tab(name) return P.tab("general", name) end
    return NS, m, P, ws, tab
end

--- Whether widget `w` hangs, at any depth, off the General page's scroll: drawn in the tab body,
--- and not in a chrome block above the strip.
local function inScroll(NS, w)
    local function walk(node)
        for _, c in ipairs(node.children or {}) do
            if c == w or walk(c) then return true end
        end
        return false
    end
    return walk(NS.Helpers.EnsureScroll(NS.Helpers.__pageCtx.general))
end

--- Count ContainerManager.RequestApply calls from here on, by the id each one named.
local function spyApply(NS)
    local calls = {}
    local real = NS.ContainerManager.RequestApply
    NS.ContainerManager.RequestApply = function(id, ...)
        local tag = id == nil and "all" or id
        calls[#calls + 1] = tag
        return real(id, ...)
    end
    return calls
end

test("general: the Enable checkbox writes the master switch through the seam", function()
    local NS, _, P, ws = general()
    local msgs = P.messages()
    local cb = P.row(ws, "enabled")
    assertTrue(cb ~= nil and cb.type == "CheckBox", "the Enable row draws a checkbox")
    assertTrue(cb.value, "it reads the stored switch")
    cb:__fire("OnValueChanged", false)
    -- red under: the row's path not being `enabled` (a write that lands on a key nothing reads)
    assertFalse(NS.db.profile.enabled)
    assertEqual(msgs.config, 1, "one CONFIG_CHANGED, from the seam")
    assertEqual(msgs.paths[1], "enabled")
end)

test("general: the four show-or-hide master rows are visibility passes; Master scale re-applies", function()
    local NS = general()
    -- red under: masterEffect losing a row (a visibility write would queue a full re-apply, which
    -- combat defers) or gaining `scale` (SetScale runs in Container:Apply, so a visibility pass
    -- would never rescale anything)
    for _, path in ipairs({ "enabled", "visibility", "locked", "alpha" }) do
        assertEqual(NS.FindSchemaRow(path).effect, "visibility", path)
    end
    assertNil(NS.FindSchemaRow("scale").effect, "scale takes the default apply")
    local calls = spyApply(NS)
    NS.SetByPath("scale", 1.5)
    assertEqual(#calls, 1, "a Master scale write queues one apply")
    assertEqual(calls[1], "all", "an addon-wide row re-applies every container")
    NS.SetByPath("alpha", 0.5)
    assertEqual(#calls, 1, "a Master alpha write queues none")
end)

test("general: the visibility dropdown offers the four states in order and stores the one chosen", function()
    local NS, _, P, ws = general()
    local dd = P.row(ws, "visibility")
    assertEqual(dd.type, "Dropdown")
    assertEqual(table.concat(dd.order, ","), "always,inCombat,outOfCombat,never")
    assertEqual(dd.value, "always", "the default is read back")
    dd:__fire("OnValueChanged", "inCombat")
    -- red under: the row writing a path other than `visibility`
    assertEqual(NS.db.profile.visibility, "inCombat")
end)

test("general: the Debug console checkbox shows the window and writes nothing to the profile", function()
    local NS, _, P, ws = general()
    local msgs = P.messages()
    local calls = spyApply(NS)
    local cb = P.row(ws, "state.debugConsole")
    assertTrue(cb ~= nil, "the console row is drawn")
    assertFalse(cb.value, "the window starts hidden")
    cb:__fire("OnValueChanged", true)
    -- red under: General.lua not handing the row the console's get/set
    assertTrue(NS.DebugLog:IsShown(), "the console window opened")
    assertNil(NS.db.profile.state, "no `state` table in the profile")
    assertEqual(msgs.config, 0, "a window toggle announces nothing")
    assertEqual(#calls, 0, "and re-applies no container")
    cb:__fire("OnValueChanged", false)
    assertFalse(NS.DebugLog:IsShown(), "and closed again")
end)

test("general: the Test mode checkbox shows the placeholders without unlocking, and reads the mode back (B1)", function()
    local NS, _, P, ws = general()
    local box = P.row(ws, "state.testMode")
    assertEqual(box.type, "CheckBox")
    box:__fire("OnValueChanged", true)
    for id, inst in pairs(NS.ContainerManager.instances) do
        -- red under: the row's set not reaching Preview.SetTestMode
        assertTrue(inst.previewShown, "container " .. id .. " shows its placeholders")
    end
    assertTrue(NS.db.profile.locked, "without unlocking")
    box:__fire("OnValueChanged", false)
    for id, inst in pairs(NS.ContainerManager.instances) do
        assertFalse(inst.previewShown, "container " .. id .. " drops them")
    end
end)

test("general: a Test mode start in combat is refused and the checkbox reads false again (B1)", function()
    local NS, m, P, ws = general()
    local box = P.row(ws, "state.testMode")
    m.__lockdown = true
    box:__fire("OnValueChanged", true)
    -- red under: the row storing the value past Preview.SetTestMode's refusal
    assertFalse(NS.State.testMode)
    assertFalse(box.value and true or false, "the checkbox follows the refusal")
end)

test("general: combat starting ends test mode, and Reset all settings ends it too (B1)", function()
    local NS, _, P = general()
    NS.Preview.SetTestMode(true)
    NS.addon:OnCombatChanged("PLAYER_REGEN_DISABLED")
    -- red under: OnCombatChanged not ending test mode (a placeholder covering real auras in a fight)
    assertFalse(NS.State.testMode)
    assertFalse(P.row(P.rerender("General"), "state.testMode").value and true or false)
    NS.Preview.SetTestMode(true)
    NS.Helpers.RestoreAllDefaults()
    -- red under: the Test mode row without its default (options-ui-§12's reset leaves it on)
    assertFalse(NS.State.testMode)
end)

test("general: Hide Blizzard buffs reparents BuffFrame away, and back to where it was", function()
    local NS, m, P, _, tab = general()
    local original = m.UIParent
    local buffs = m.CreateFrame("Frame", "BuffFrame")
    local debuffs = m.CreateFrame("Frame", "DebuffFrame")
    for _, f in ipairs({ buffs, debuffs }) do
        f.__parent = original
        rawset(f, "SetParent", function(self, p) self.__parent = p end)
        rawset(f, "GetParent", function(self) return self.__parent end)
    end
    local ws = tab(NS.L["Display"])
    P.row(ws, "hideBlizzardBuffs"):__fire("OnValueChanged", true)
    -- red under: dropping applyBlizzardFrames from the row's onChange
    assertTrue(NS.db.profile.hideBlizzardBuffs)
    assertTrue(buffs.__parent ~= original, "the buff frame was moved away")
    assertEqual(debuffs.__parent, original, "the debuff row is its own setting")
    P.row(ws, "hideBlizzardBuffs"):__fire("OnValueChanged", false)
    assertEqual(buffs.__parent, original, "unticking puts it back where it was")
end)

test("general: the Blizzard-frame rows re-apply no container", function()
    local NS, _, P, _, tab = general()
    local ws = tab(NS.L["Display"])
    local calls = spyApply(NS)
    P.row(ws, "hideBlizzardBuffs"):__fire("OnValueChanged", true)
    P.row(ws, "hideBlizzardDebuffs"):__fire("OnValueChanged", true)
    -- red under: the rows losing `effect = "none"` (every container re-applied for a frame no
    -- container reads, and a deferral notice in combat for nothing)
    assertEqual(#calls, 0)
    assertTrue(NS.db.profile.hideBlizzardDebuffs)
end)

test("general: Reset position puts every container back on the screen", function()
    local NS, _, P, ws = general()
    NS.SetByPath("container.position.x", 700, 2)
    NS.SetByPath("container.attach.mode", "frame", 3)
    local btn = P.find(ws, "Button", "Reset position")
    assertTrue(btn ~= nil, "the composer's button pair is drawn under Master controls")
    btn:__fire("OnClick")
    -- red under: onResetPosition not reaching ContainerManager.ResetPositions
    local c2, c3 = NS.Database.FindContainer(2), NS.Database.FindContainer(3)
    assertEqual(c2.position.x, NS.CONTAINER_TEMPLATE.position.x)
    assertEqual(c2.position.y, -30, "staggered by its place in the order")
    assertEqual(c3.attach.mode, "screen")
end)

test("general: Reset all settings asks first and resets nothing until the answer", function()
    local NS, _, P, ws = general()
    local popups = P.popups()
    NS.ContainerManager.Create({ name = "Keep me" })
    NS.SetByPath("scale", 2)
    P.find(ws, "Button", "Reset all settings"):__fire("OnClick")
    -- red under: onResetAll calling RestoreAllDefaults straight away (a destructive act unasked)
    assertEqual(#popups, 1)
    assertEqual(popups[1].which, "AURAMASTER_RESET_ALL")
    assertEqual(#NS.Database.GetContainers(), #NS.STARTER_CONTAINERS + 1, "nothing reset yet")
    assertEqual(NS.db.profile.scale, 2)
end)

test("general: the Reset-all tooltip names the equivalence with Profiles -> Reset Profile", function()
    local _, m, P, ws = general()
    local lines = {}
    rawset(m.GameTooltip, "AddLine", function(_, s)
        lines[#lines + 1] = s
    end)
    P.find(ws, "Button", "Reset all settings"):__fire("OnEnter")
    -- red under: the Options descriptor without profilesPage (the tooltip never points at the Profiles page)
    assertEqual(lines[1], "Reset the current profile to its defaults — the same thing Profiles -> Reset Profile does. "
        .. "Your other profiles are not affected.")
end)

test("general: the Reset-all popup carries options-ui-§12's wording and cannot be clicked through", function()
    local NS, m = general()
    local d = m.StaticPopupDialogs.AURAMASTER_RESET_ALL
    -- red under: rewording the one sentence §12 fixes for every addon's global reset
    assertEqual(d.text, "Reset this profile to the addon's defaults? Everything you have configured or added in it is discarded — your other profiles are not affected.")
    assertEqual(d.timeout, 0, "it waits for an answer")
    assertTrue(d.hideOnEscape, "Escape is a No")
    assertEqual(d.button1, NS.L["Yes"])
    assertEqual(d.button2, NS.L["No"])
end)

test("general: Defaults restores the General rows of the profile and no container setting, now that Containers is its own page", function()
    local NS, m = general()
    NS.SetByPath("enabled", false)
    NS.SetByPath("visibility", "never")
    NS.SetByPath("hideBlizzardBuffs", true)
    NS.SetByPath("container.bars.width", 300, 1)
    NS.SetByPath("container.enabled", false, 1)
    m.__subcategories.General.defaultsOnClick()
    -- red under: the General Defaults reaching past its page (or not reaching its own rows)
    assertTrue(NS.db.profile.enabled)
    assertEqual(NS.db.profile.visibility, "always")
    assertFalse(NS.db.profile.hideBlizzardBuffs)
    assertEqual(NS.Database.FindContainer(1).bars.width, 300, "a Bars row is not a General row")
    -- red under: N-1 half-done (Containers rows still page = "general", so a General Defaults press
    -- would still reach the selected container's identity)
    assertFalse(NS.Database.FindContainer(1).enabled, "a Containers row is not a General row either")
    assertEqual(#NS.Database.GetContainers(), #NS.STARTER_CONTAINERS, "and the registry is untouched")
end)

test("general: the page's Defaults tooltip no longer mentions a container's identity (N-1: Containers is its own page)", function()
    local NS, m = general()
    -- red under: the tooltip still describing container rows General's Defaults no longer reaches
    assertEqual(m.__subcategories.General.defaultsTooltip,
        NS.L["Restore every General setting on this profile to its addon default. The Minimap button is left alone — whether the button is shown is a per-installation preference, like where you dragged it. The spell categories' lists are not rows; each category has its own restore."])
end)

test("general: the tab strip reads Master controls, Display, Spell Categories, Dispel Colors — Containers is gone from it", function()
    local NS, m, P = general()
    local keys = P.tabKeys("general")
    -- red under: the Containers tab left behind on General after N-1's move, or dropped without the
    -- Spell Categories / Dispel Colors tabs shifting up to take its old place
    assertEqual(table.concat(keys, ","), "Master controls,Display,Spell Categories,Dispel Colors")
    local seen = {}
    for _, k in ipairs(keys) do
        assertNil(seen[k], "tab " .. k .. " drawn twice")
        seen[k] = true
    end
    -- red under: N-1 half-done (the container identity rows still keyed to "general")
    for _, row in ipairs(NS.SchemaForPage("general")) do
        assertNil(row.path:match("^container%."), "no container.* row is keyed to the general page any more: " .. row.path)
    end
    for _, path in ipairs({ "container.name", "container.enabled", "container.unit", "container.auraType", "container.style" }) do
        local row = NS.FindSchemaRow(path)
        assertEqual(row.page, "containers", path)
        assertEqual(row.group, NS.L["General"], path)
    end
    -- The Containers page now registers its OWN Blizzard category (N-1), not a General tab.
    assertTrue(m.__subcategories.Containers ~= nil, "the Containers page registers on its own")
end)

-- ── the Spell Categories tab (G-2) ────────────────────────────────────────────────────────────

--- The General page on its Spell Categories tab.
local function spells(opts)
    local NS, m, P, _, tab = general(opts)
    return NS, m, P, tab(NS.L["Spell Categories"])
end

--- The Category dropdown's label for `key`, built the way the panel builds it: the aura type's own
--- `C.AURA_TYPE_LABELS` word, then padding out to the widest such word, then the category's name
--- (settings/GeneralSpells.lua's `categoryLabel`, issue #10 checkpoint 1). Built here out of the
--- SAME locale strings rather than hard-coded, so a case asserting it asserts the composition and
--- never re-states the wording -- which is also why it is NOT the only thing the marker cases rest
--- on: this helper takes the aura type from the accessor under test, so the cases below anchor the
--- type itself to the literal label and to the list the category is declared in.
local function marked(NS, key, auraType)
    auraType = auraType or NS.Categories.AuraTypeOf(key)
    local def = NS.Categories.Find(auraType, key)
    -- Byte length is character length here: the locale guard already holds enUS to ASCII.
    local widest = 0
    for _, word in pairs(NS.Constants.AURA_TYPE_LABELS) do
        local n = #NS.L[word]
        widest = math.max(widest, n)
    end
    local mine = #NS.L[NS.Constants.AURA_TYPE_LABELS[auraType]]
    local pad = (" "):rep(widest - mine)
    -- A category the player made carries the ownership marker too, and it is a SUFFIX on the name
    -- rather than a second prefix, so the padding above still starts every name at one offset.
    local name = NS.Categories.LabelOf(def)
    if NS.Categories.IsUserCategory(def) then
        name = (NS.L["{name} (yours)"]:gsub("{name}", function() return name end))
    end
    return (NS.L["[{type}] {name}"]
        :gsub("{type}", function() return NS.L[NS.Constants.AURA_TYPE_LABELS[auraType]] end)
        :gsub("{name}", function() return pad .. name end))
end

--- Every entry the IdList drew, in DRAW ORDER, as { id =, label =, x =, row =, col = }.
---
--- The walk is per CHILD, not per row, because the spell-category list asks for `columns = 2`
--- (settings/GeneralSpells.lua's H.IdList call, LibKa0s v1.47.0): two entries share one Flow row,
--- so a row's children run X, label, X, label and a helper that read `w.children[2]` alone would
--- see the left column and call the right one absent. `row` is that row's index among the widgets
--- handed in and `col` the entry's position inside it, 1-based -- which is what lets a test assert
--- ROW-MAJOR placement (1 2 / 3 4) rather than only the flat sequence.
---
--- A named entry reads "<name> (<id>)", an unnamed one "Unknown spell <id>" (the library's
--- entryLabel); the X is the Icon immediately before the label (`removeStyle = "icon"`, B2).
local function drawnEntries(ws)
    local out = {}
    for r, w in ipairs(ws) do
        local kids, col = w.children, 0
        if type(kids) ~= "table" then kids = {} end
        local n = #kids
        for i = 1, n do
            local lbl = kids[i]
            if type(lbl) == "table" and lbl.type == "InteractiveLabel" then
                local t = lbl.text or ""
                local id = t:match("%((%d+)%)|r$") or t:match("^Unknown spell (%d+)$")
                if id then
                    local prev = kids[i - 1]
                    col = col + 1
                    local at = #out + 1
                    out[at] = {
                        id = tonumber(id), label = lbl, row = r, col = col,
                        x = (type(prev) == "table" and prev.type == "Icon") and prev or nil,
                    }
                end
            end
        end
    end
    return out
end

--- The line an IdList drew for spell `id`: its label, and the X at its left.
local function entry(ws, id)
    for _, e in ipairs(drawnEntries(ws)) do
        if e.id == id then return e.label, e.x end
    end
    return nil
end

--- Every id the IdList drew, in the order it drew them.
local function listedIds(ws)
    local out = {}
    for _, e in ipairs(drawnEntries(ws)) do
        local n = #out
        out[n + 1] = e.id
    end
    return out
end

-- Owner, 2026-09-20: the list came out in id order, so it read Frost Nova (122), Entangling Roots
-- (339), Hamstring (1715) -- no order at all to someone looking for a spell by name.
test("general → spell categories: the list is ordered by name, case-insensitively, ids the client cannot name last (owner 2026-09-20)", function()
    local NS, m, P = spells()
    -- Names chosen so that name order and id order disagree on every pair, and so that a
    -- case-sensitive compare would put both capitalized names ahead of "alpha".
    m.__spells[871]    = { name = "zeta", iconID = 1 }
    m.__spells[12975]  = { name = "alpha", iconID = 1 }
    m.__spells[118038] = { name = "Mid", iconID = 1 }
    m.__spells[424242] = { name = "Beta", iconID = 1 }
    NS.SetByPath("categorySpells", { defensives = { [424242] = true } })
    local order = listedIds(P.rerender("General"))
    -- red under: the old numeric sort (871, 12975, 118038, ...), a case-sensitive compare (Beta,
    -- Mid, alpha, zeta), or the added spell parked below the starters instead of in the alphabet
    assertEqual(table.concat({ order[1], order[2], order[3], order[4] }, ","), "12975,424242,118038,871")
    -- Every remaining defensive is one this client cannot name, and those go LAST, ascending by id:
    -- the library draws them "Unknown spell <id>", so there is no name for a reader to look for.
    local drawn = #order
    assertTrue(drawn > 4, "the rest of the defensives are drawn too")
    for i = 5, drawn do
        assertNil(m.__spells[order[i]], "id " .. order[i] .. " is one the client cannot name")
        -- red under: a nil name reaching the comparison and leaving the tail in pairs() order
        if i > 5 then assertTrue(order[i - 1] < order[i], "unnamed ids break the tie on the id") end
    end
end)

-- Owner, 2026-09-20: one entry per row ran very long for a 60-id category, so the list asks the
-- library for two columns. The two changes of that day have to agree: the sort is BY NAME and the
-- packing is ROW-MAJOR, so the alphabet reads left-to-right then down (1 2 / 3 4). Column-major
-- would put the same ids on screen in an order no reader could follow, and nothing about the flat
-- sequence would notice -- which is why this asserts the ROW and the COLUMN each entry landed in,
-- not just the order they came back in.
test("general → spell categories: the list draws two columns, filled row-major, in the by-name order (owner 2026-09-20)", function()
    local NS, m, P = spells()
    -- Four names whose alphabet disagrees with their ids, so a list that fell back to id order
    -- could not pass by luck.
    m.__spells[871]    = { name = "delta", iconID = 1 }
    m.__spells[12975]  = { name = "charlie", iconID = 1 }
    m.__spells[118038] = { name = "bravo", iconID = 1 }
    m.__spells[424242] = { name = "alpha", iconID = 1 }
    NS.SetByPath("categorySpells", { defensives = { [424242] = true } })
    local drawn = drawnEntries(P.rerender("General"))
    assertTrue(#drawn >= 4, "the four named defensives are drawn")
    -- The by-name order first: alpha, bravo, charlie, delta.
    assertEqual(table.concat({ drawn[1].id, drawn[2].id, drawn[3].id, drawn[4].id }, ","),
        "424242,118038,12975,871")
    -- Then WHERE each one landed. red under column-major (alpha and charlie sharing a row), and
    -- red under a silent return to one entry per row (every col == 1).
    assertEqual(drawn[1].row, drawn[2].row, "entries 1 and 2 share the first row")
    assertEqual(drawn[1].col, 1, "entry 1 is the left column")
    assertEqual(drawn[2].col, 2, "entry 2 is the right column, not the row below")
    assertTrue(drawn[3].row > drawn[2].row, "entry 3 starts the next row down")
    assertEqual(drawn[3].col, 1, "entry 3 is the left column of that row")
    assertEqual(drawn[4].row, drawn[3].row, "entry 4 sits beside entry 3")
    assertEqual(drawn[4].col, 2, "entry 4 is the right column")
    -- Every entry keeps its own X at its own left, one per entry and not one per row (B2).
    for i = 1, 4 do
        assertTrue(drawn[i].x ~= nil, "entry " .. i .. " carries its own X")
    end
end)

local function starterIds(NS, key)
    local out = {}
    for id in pairs(NS.Categories.Find("HELPFUL", key).spells) do
        out[#out + 1] = id
    end
    table.sort(out)
    return out
end

--- Record every NS.SetByPath call's path from here on.
local function spyPaths(NS)
    local paths = {}
    local real = NS.SetByPath
    NS.SetByPath = function(path, ...)
        paths[#paths + 1] = path
        return real(path, ...)
    end
    return paths
end

test("general → spell categories: a dropdown of the eleven spell categories plus Weapon enchants, opening on the first", function()
    local NS, _, _, ws = spells()
    local dd
    for _, w in ipairs(ws) do
        if w.type == "Dropdown" and w.labelText == NS.L["Category"] then dd = w end
    end
    assertTrue(dd ~= nil, "the category dropdown is drawn")
    assertTrue(inScroll(NS, dd), "in the tab body")
    -- red under: the dropdown offering a flag or token category (only spell categories and the
    -- enchant row belong here). 12 = nine buff spell lists + weaponEnchants + issue #11's hardCC and
    -- softCC, which are `spells`-kind on Cat.HARMFUL: this tab is keyed on the KIND, never on the
    -- aura type, or a shipped debuff list would have no editor and its `See spells` link would go
    -- nowhere.
    assertEqual(#dd.order, 12)
    for _, k in ipairs(dd.order) do
        assertTrue(NS.Categories.IsSpellCategory(k) or k == "weaponEnchants", "a spell category or the enchant row: " .. k)
    end
    -- Every entry now carries its aura type as a prefix (issue #10 checkpoint 1); the name follows
    -- it unchanged, which is what these four pin alongside the marker itself.
    assertEqual(dd.list.healing, marked(NS, "healing"), "the merged Healing category is offered")
    assertEqual(dd.list.weaponEnchants, marked(NS, "weaponEnchants"), "Weapon enchants is offered too")
    assertEqual(dd.list.hardCC, marked(NS, "hardCC"), "and the debuff lists")
    assertEqual(dd.list.softCC, marked(NS, "softCC"))
    assertEqual(dd.order[1], "defensives")
    assertEqual(dd.order[10], "weaponEnchants", "the buff rows first, in defaults/Categories.lua's order")
    assertEqual(dd.order[11], "hardCC", "then Cat.HARMFUL's, in its own order")
    assertEqual(dd.order[12], "softCC")
    assertEqual(dd.value, "defensives")
end)

test("general → spell categories: every Category entry is prefixed with the aura type it filters (issue #10)", function()
    local NS, _, P, ws = spells()
    local dd = P.find(ws, "Dropdown", NS.L["Category"])
    assertTrue(dd ~= nil, "the category dropdown is drawn")
    local buffs, debuffs = 0, 0
    for _, key in ipairs(dd.order) do
        local auraType = NS.Categories.AuraTypeOf(key)
        -- red under: an entry whose category the accessor cannot type, which would draw unmarked
        assertTrue(auraType == "HELPFUL" or auraType == "HARMFUL", key .. ": no aura type")
        local word = NS.L[NS.Constants.AURA_TYPE_LABELS[auraType]]
        -- red under: the marker dropped from an entry, or matching the OTHER aura type
        assertEqual(dd.list[key], marked(NS, key), key)
        assertEqual(dd.list[key]:sub(1, #word + 3), "[" .. word .. "] ", key .. ": marked as a prefix")
        -- red under: a suffix-shaped marker, which would collide with the two CC rows' own
        -- parenthetical suffixes ("Hard CC (loss of control)")
        assertTrue(dd.list[key]:find(NS.L[NS.Categories.Find(auraType, key).label], 1, true) ~= nil,
            key .. ": the name survives the marker whole")
        if auraType == "HELPFUL" then buffs = buffs + 1 else debuffs = debuffs + 1 end
    end
    -- red under: the case passing on a buff-only list again — issue #11 put hardCC and softCC here,
    -- and a marker nothing ever draws as Debuffs is a marker that is not doing its job
    assertTrue(buffs > 0 and debuffs > 0, ("both aura types appear: %d buff, %d debuff"):format(buffs, debuffs))
    -- Weapon enchants is kind "enchant", not a spell list, and is marked buff-side like the rest of
    -- Cat.HELPFUL — the Aura type row's own description already calls it a buff category.
    assertEqual(dd.list.weaponEnchants:sub(1, 8), "[" .. NS.L["Buffs"] .. "] ")
    -- Anchored to the literal rather than to the accessor: everything above builds its expectation
    -- by asking Cat.AuraTypeOf, so a build in which EVERY category answered the wrong type would
    -- still pass. These two say what a player reads, in full, padding included.
    assertEqual(dd.list.hardCC, "[Debuffs] Hard CC (loss of control)")
    assertEqual(dd.list.healing, "[Buffs]   Healing")
    -- And anchored to the declaration: hardCC reads Debuffs because it is declared in Cat.HARMFUL.
    local declaredHarmful = false
    for _, d in ipairs(NS.Categories.For("HARMFUL")) do
        if d.key == "hardCC" then declaredHarmful = true end
    end
    assertTrue(declaredHarmful, "hardCC is declared in the HARMFUL list, which is what it is marked as")
    assertEqual(dd.list.hardCC, marked(NS, "hardCC", "HARMFUL"))
end)

test("general → spell categories: the markers are padded so every name starts at the same column (issue #10)", function()
    local NS, _, P, ws = spells()
    local dd = P.find(ws, "Dropdown", NS.L["Category"])
    -- "[Buffs] " and "[Debuffs] " are different lengths, so an unpadded prefix would start every
    -- name at a different place and cost the list the name column the marker is there to keep.
    -- Character-exact is what the panel can promise in a proportional font, and it is what this
    -- pins; settings/GeneralSpells.lua says plainly why pixel-exact is not on offer.
    local at
    for _, key in ipairs(dd.order) do
        local def = NS.Categories.Find(NS.Categories.AuraTypeOf(key), key)
        local i = dd.list[key]:find(NS.Categories.LabelOf(def), 1, true)
        assertTrue(i ~= nil, key .. ": the name is in the entry")
        at = at or i
        -- red under: the padding dropped from categoryLabel
        assertEqual(i, at, key .. ": the name starts where every other name starts")
    end
    -- red under: a padding rule that happens to align only one aura type's rows with itself
    assertEqual(dd.list.softCC:find("Soft CC", 1, true), dd.list.healing:find("Healing", 1, true))
end)

test("general → spell categories: the closed dropdown shows the marked label too (issue #10)", function()
    local NS, _, P, ws = spells()
    -- AceGUI's Dropdown draws its selection by looking the value up in the same list table, so this
    -- is what a player sees on the closed control, not only in the open one.
    local dd = P.find(ws, "Dropdown", NS.L["Category"])
    assertEqual(dd.list[dd.value], marked(NS, dd.value), "the opening selection reads marked")
    dd:__fire("OnValueChanged", "hardCC")
    local dd2 = P.find(P.rerender("General"), "Dropdown", NS.L["Category"])
    assertEqual(dd2.value, "hardCC")
    -- red under: the marker read off the tab's own aura type rather than the category's, which only
    -- shows once the selection is a debuff list
    assertEqual(dd2.list[dd2.value], marked(NS, "hardCC"), "and so does a debuff list, as Debuffs")
end)

-- Owner, 2026-09-20: the picker, its Restore and the whole spell list ran together as one column.
-- The heading is the library's own section rule, and it names what the block IS rather than
-- repeating the add row's "Add a spell" label.
test("general → spell categories: a section heading separates the picker from the spell list (2026-09-20)", function()
    local NS, _, P, ws = spells()
    local head, dd, add
    for i, w in ipairs(ws) do
        if w.type == "Heading" and w.text == NS.L["Spells in this category"] then head = head or i end
        if w.type == "Dropdown" and w.labelText == NS.L["Category"] then dd = i end
        if w.type == "EditBox" and w.labelText == NS.L["Add a spell"] then add = add or i end
    end
    -- red under: the H.Section dropped, so the tab reads as one undivided column again
    assertTrue(head ~= nil, "a Spells in this category heading is drawn")
    assertTrue(dd ~= nil and add ~= nil, "the picker and the add line both drew")
    -- red under: the heading drawn above the picker, or below the add line
    assertTrue(dd < head, "the Category picker and its Restore come first")
    assertTrue(head < add, "then the heading, then Add a spell")
    -- red under: the heading following the enchant row too, which has no spell list to head
    P.find(ws, "Dropdown", NS.L["Category"]):__fire("OnValueChanged", "weaponEnchants")
    assertNil(P.find(P.rerender("General"), "Heading", NS.L["Spells in this category"]),
        "Weapon enchants draws no spell-list heading")
end)

test("general → spell categories: every starter is listed with an X on its left, and no checkbox (B2)", function()
    local NS, _, P, ws = spells()
    local want = starterIds(NS, "defensives")
    for _, id in ipairs(want) do
        local _, x = entry(ws, id)
        -- red under: the list without removeStyle = "icon", or starters sent as toggle entries
        assertTrue(x ~= nil and x.type == "Icon", "an X beside starter " .. id)
    end
    assertEqual(#P.all(ws, "CheckBox"), 0, "no checkboxes")
    assertEqual(#P.all(ws, "Button", NS.L["Remove"]), 0, "no Remove buttons")
    assertTrue(P.find(ws, "EditBox", NS.L["Add a spell"]) ~= nil, "the add line is drawn")
end)

test("general → spell categories: adding by id writes categorySpells whole through the seam, and its X takes it off", function()
    local NS, _, P, ws = spells()
    NS.SetByPath("categorySpells", { raidCDs = { [99] = true } })
    local paths = spyPaths(NS)
    P.find(ws, "EditBox", NS.L["Add a spell"]):__fire("OnEnterPressed", "424242")
    local edits = NS.db.profile.categorySpells
    -- red under: onAdd writing anything but the whole profile set at `categorySpells`
    assertEqual(table.concat(paths, ","), "categorySpells")
    assertEqual(edits.defensives[424242], true)
    assertEqual(edits.raidCDs[99], true, "another category's edits are kept")
    assertNil(NS.Database.FindContainer(1).filter.categorySpells, "no container keeps its own copy")
    ws = P.rerender("General")
    local lbl, x = entry(ws, 424242)
    assertTrue(lbl ~= nil, "the added spell is listed")
    assertEqual(lbl.text, "Unknown spell 424242", "by id where the client cannot name it")
    x:__fire("OnClick")
    -- red under: onRemove storing false for an added spell (it would linger as an edit)
    assertNil(NS.db.profile.categorySpells.defensives, "no edit left to store")
end)

test("general → spell categories: a name resolves through the candidates — any category's starter, or a learned timed spell", function()
    local NS, m, P, ws = spells()
    NS.db.global.timedSpells = { [5555] = true }
    m.__spells[5555] = { name = "Learned Buff", iconID = 1 }
    local box = P.find(ws, "EditBox", NS.L["Add a spell"])
    box:__fire("OnEnterPressed", "rejuvenation")
    -- red under: candidates() omitting the other categories' starters (the mock client finds no
    -- spell by name, so only the candidates can resolve one)
    assertEqual(NS.db.profile.categorySpells.defensives[774], true, "Rejuvenation, a Healing starter")
    box:__fire("OnEnterPressed", "Learned Buff")
    -- red under: candidates() omitting NS.db.global.timedSpells
    assertEqual(NS.db.profile.categorySpells.defensives[5555], true)
    local msgs = P.messages()
    box:__fire("OnEnterPressed", "No Such Spell")
    assertEqual(msgs.config, 0, "an unknown name writes nothing")
    assertTrue(P.hasText(ws, "No spell named 'No Such Spell' in your spellbook."), "and says why on the add line")
end)


-- ── 'Your categories': create, rename, delete and the shipped lock (issue #10 checkpoint 6) ────
--
-- The acts themselves are pinned in tests/test_database.lua, including both refusals. What these
-- cases own is the PANEL: that the block draws the controls the owner asked for, that it draws them
-- only where they mean something, and that the destructive one asks first.

--- The tab's own management controls, by the labels the block gives them.
local function manage(NS, ws, P)
    return {
        name   = P.find(ws, "EditBox", NS.L["Rename this category"]),
        delete = P.find(ws, "Button", NS.L["Delete this category"]),
        newName = P.find(ws, "EditBox", NS.L["New category's name"]),
        auraType = P.find(ws, "Dropdown", NS.L["Aura type"]),
        create = P.find(ws, "Button", NS.L["Create category"]),
    }
end

--- The index, among the widgets `ws`, of the line `w` was drawn on: `w` itself when it is a
--- top-level widget, or the H.RenderGrid line holding it when it is a cell.
local function lineOf(ws, w)
    for i, line in ipairs(ws) do
        if line == w then return i end
        for _, kid in ipairs(line.children or {}) do
            if kid == w then return i end
        end
    end
    return nil
end

--- The profile's one user category's key, or nil.
local function onlyUserKey(NS)
    local found
    for key in pairs(NS.db.profile.userCategories) do
        assertNil(found, "more than one user category")
        found = key
    end
    return found
end

test("general → spell categories: the create form makes a category, shows it, and it is usable at once", function()
    local NS, _, P, ws = spells()
    local m1 = manage(NS, ws, P)
    assertTrue(m1.newName ~= nil and m1.auraType ~= nil and m1.create ~= nil, "the create form is drawn")
    -- The two aura types, in C.AURA_TYPES order and in the words every other surface uses, so the
    -- choice reads the same here as on the container's own Aura type row.
    assertEqual(table.concat(m1.auraType.order, ","), "HELPFUL,HARMFUL")
    assertEqual(m1.auraType.list.HARMFUL, NS.L[NS.Constants.AURA_TYPE_LABELS.HARMFUL])

    m1.newName:__fire("OnTextChanged", "My affixes")
    m1.auraType:__fire("OnValueChanged", "HARMFUL")
    m1.create:__fire("OnClick")

    local key = onlyUserKey(NS)
    assertTrue(key ~= nil, "the category was created")
    assertEqual(NS.db.profile.userCategories[key].name, "My affixes")
    assertEqual(NS.db.profile.userCategories[key].auraType, "HARMFUL", "the type the form chose")

    -- USABLE AT ONCE, which is what "created" has to mean: a row that resolves, a template entry, a
    -- stored state in every container, and a place in the debuff grid above Uncategorized.
    local path = "container.filter.categories." .. key
    assertTrue(NS.FindSchemaRow(path) ~= nil, "a schema row")
    assertEqual(NS.DefaultFor(path), "show")
    assertEqual(NS.GetSetting(path, NS.Database.GetContainers()[1].id), "show")
    assertEqual(NS.ValidateSchema(), 0)
    assertEqual(NS.Categories.HARMFUL[#NS.Categories.HARMFUL].key, "uncategorizedDebuffs",
        "Uncategorized is still last after a create (U-1)")

    -- And the tab moved onto it, so the player is looking at the list they just made rather than
    -- hunting for it in a dropdown of fifteen.
    local ws2 = P.rerender("General")
    local dd = P.find(ws2, "Dropdown", NS.L["Category"])
    assertEqual(dd.value, key, "the new category is selected")
    assertEqual(dd.list[key], marked(NS, key, "HARMFUL"), "and marked as a debuff category")
    assertEqual(manage(NS, ws2, P).newName.text, "", "the form is cleared for the next one")
end)

test("general → spell categories: the name box renames without moving the key, and keeps the container's Show/Hide", function()
    local NS, _, P = spells()
    local key = NS.Categories.CreateUserCategory("Frist draft", "HELPFUL")
    local path = "container.filter.categories." .. key
    local id = NS.Database.GetContainers()[1].id
    NS.SetByPath(path, "hide", id)
    NS.SetByPath("categorySpells", { [key] = { [424242] = true } })
    NS.GeneralSpells.Select(key)

    local ws = P.rerender("General")
    local box = manage(NS, ws, P).name
    assertTrue(box ~= nil, "a category the player made has a name box")
    assertEqual(box.text, "Frist draft", "showing the stored name")
    box:__fire("OnEnterPressed", "  First draft  ")

    -- red under: a rename that re-keys. Every one of these is stored UNDER THE KEY.
    assertEqual(NS.db.profile.userCategories[key].name, "First draft", "trimmed and stored")
    assertEqual(NS.GetSetting(path, id), "hide", "the container's own decision survives")
    assertEqual(NS.db.profile.categorySpells[key][424242], true, "and the spell list")
    assertEqual(NS.FindSchemaRow(path).label, "First draft", "the row's label follows the name")
    assertEqual(NS.ValidateSchema(), 0)

    -- An empty name is refused by the act and the box goes back to what is stored.
    P.rerender("General")
    manage(NS, P.rerender("General"), P).name:__fire("OnEnterPressed", "   ")
    assertEqual(NS.db.profile.userCategories[key].name, "First draft", "a refused rename changes nothing")
    assertEqual(manage(NS, P.rerender("General"), P).name.text, "First draft", "and the box is redrawn from the store")
end)

test("general → spell categories: a shipped category draws the lock sentence instead of a name box and a Delete", function()
    local NS, _, P, ws = spells()
    local shipped = manage(NS, ws, P)
    -- red under: drawing the two controls for every category and leaving the refusal to the act,
    -- which would offer the player a Delete that can only ever fail.
    assertNil(shipped.name, "a shipped category has no name box")
    assertNil(shipped.delete, "and no Delete")
    assertTrue(P.hasText(ws, "one of Aura Master's own categories"),
        "the sentence says why, and that the spell list is still the player's")
    assertTrue(shipped.create ~= nil, "but a category can still be made from here")

    local key = NS.Categories.CreateUserCategory("Mine", "HELPFUL")
    NS.GeneralSpells.Select(key)
    local ws2 = P.rerender("General")
    local mine = manage(NS, ws2, P)
    assertTrue(mine.name ~= nil and mine.delete ~= nil, "a category the player made has both")
    assertFalse(P.hasText(ws2, "one of Aura Master's own categories"), "and not the sentence")
end)

test("general → spell categories: Delete asks first, and the confirmation's act is what refuses a shipped key", function()
    local NS, m, P = spells()
    local key = NS.Categories.CreateUserCategory("Affixes", "HELPFUL")
    NS.SetByPath("categorySpells", { [key] = { [424242] = true } })
    NS.GeneralSpells.Select(key)
    local ws = P.rerender("General")
    local popups = P.popups()
    manage(NS, ws, P).delete:__fire("OnClick")

    assertEqual(#popups, 1, "the click asks rather than acts")
    assertEqual(popups[1].which, "AURAMASTER_DELETE_CATEGORY")
    assertEqual(popups[1].text, "Affixes", "the confirmation names the category")
    assertEqual(popups[1].data, key, "and carries the KEY, not the definition")
    -- red under: a confirmation that names the losses and not the one CONSEQUENCE -- an aura this
    -- category was hiding is hidden by nothing once it is gone, and comes back under Uncategorized.
    assertTrue(m.StaticPopupDialogs.AURAMASTER_DELETE_CATEGORY.text:find("Uncategorized", 1, true) ~= nil,
        "the confirmation says what becomes visible again")
    assertTrue(NS.db.profile.userCategories[key] ~= nil, "nothing is discarded until it is accepted")

    m.StaticPopupDialogs.AURAMASTER_DELETE_CATEGORY.OnAccept(popups[1], popups[1].data)
    assertTrue(NS.db.profile.userCategories[key] == nil, "accepting discards it")
    assertTrue(NS.db.profile.categorySpells[key] == nil, "with the list it held")
    assertTrue(NS.FindSchemaRow("container.filter.categories." .. key) == nil)
    assertEqual(NS.ValidateSchema(), 0)

    -- THE ACT IS THE ENFORCEMENT. A popup that outlived its render -- or any other caller -- handing
    -- the dialog a shipped key is refused by Cat.DeleteUserCategory, not by the drawing rule that
    -- kept the button off a shipped category in the first place.
    m.StaticPopupDialogs.AURAMASTER_DELETE_CATEGORY.OnAccept(nil, "defensives")
    assertTrue(NS.Categories.Find("HELPFUL", "defensives") ~= nil, "the shipped category is still there")
    assertTrue(NS.FindSchemaRow("container.filter.categories.defensives") ~= nil)
    -- And a second accept of the key just deleted is refused rather than raising.
    m.StaticPopupDialogs.AURAMASTER_DELETE_CATEGORY.OnAccept(popups[1], key)
    assertEqual(NS.ValidateSchema(), 0)
end)

-- ── the four things review round four asked for (owner, 2026-09-21) ────────────────────────────

test("general → spell categories: a category the player made is drawn no Restore, and the act refuses one", function()
    local NS, _, P, ws = spells()
    -- The premise: one of Aura Master's own categories does get the button.
    assertTrue(P.find(ws, "Button", NS.L["Restore this category's starter list"]) ~= nil,
        "a shipped category has a Restore")

    local key = NS.Categories.CreateUserCategory("Affixes", "HELPFUL")
    NS.SetByPath("categorySpells", { [key] = { [424242] = true, [555] = true } })
    NS.GeneralSpells.Select(key)
    local ws2 = P.rerender("General")
    -- red under: Restore drawn for every non-enchant category. A category the player made ships
    -- with NO starter list, so "restore the starter list" there empties it -- silently, under a
    -- label about something else, one row above the Delete that stops to ask for exactly that loss.
    assertNil(P.find(ws2, "Button", NS.L["Restore this category's starter list"]),
        "no Restore on a category with no starter list")
    assertFalse(P.hasText(ws2, "Restore brings the starter list back"),
        "and the lead-in does not promise one either")

    -- THE ACT REFUSES IT TOO, so not drawing the button is a courtesy and never the enforcement --
    -- the same division of labor the Delete already uses. red under: the guard living only in the
    -- drawing rule, where a stale render or a future caller walks straight past it.
    local ok, why = NS.GeneralSpells.RestoreStarters(key)
    assertTrue(ok == nil, "the act refuses a category the player made")
    assertEqual(why, NS.L["Only one of Aura Master's own categories has a starter list to go back to. Take spells out of your own with the X beside each one, or delete the category."])
    assertEqual(NS.db.profile.categorySpells[key][424242], true, "and the list is untouched")
    assertEqual(NS.db.profile.categorySpells[key][555], true)

    -- While a shipped one still restores, which is what the button is for.
    NS.SetByPath("categorySpells", { defensives = { [424242] = true } })
    assertTrue(NS.GeneralSpells.RestoreStarters("defensives"))
    assertNil(NS.db.profile.categorySpells.defensives, "no edit left to store")
end)

test("general → spell categories: Weapon enchants is promised no spell list, Restore or add/remove", function()
    local NS, _, P, ws = spells()
    P.find(ws, "Dropdown", NS.L["Category"]):__fire("OnValueChanged", "weaponEnchants")
    ws = P.rerender("General")
    -- red under: the enchant branch drawing the general shipped sentence, which describes a spell
    -- list, a Restore and add/remove -- three things this entry does not have. It draws slot
    -- toggles.
    assertFalse(P.hasText(ws, "Its spell list is still yours"), "no promise of a list it has not got")
    assertTrue(P.hasText(ws, "It holds no spell list at all"), "it says what it actually is")
    assertNil(P.find(ws, "Button", NS.L["Restore this category's starter list"]))
    assertTrue(P.find(ws, "Button", NS.L["Create category"]) ~= nil,
        "but a category can still be made from here")
end)

test("general → spell categories: a category the player made says so, without moving the name column", function()
    local NS, _, P = spells()
    local key = NS.Categories.CreateUserCategory("Affixes", "HELPFUL")
    local dd = P.find(P.rerender("General"), "Dropdown", NS.L["Category"])
    -- red under: no ownership marker at all, which left a player unable to tell their own categories
    -- from Aura Master's without selecting each one and reading the block underneath.
    assertEqual(dd.list[key], marked(NS, key, "HELPFUL"))
    assertTrue(dd.list[key]:find("(yours)", 1, true) ~= nil, "the player's own is marked")
    assertFalse(dd.list.healing:find("(yours)", 1, true) ~= nil, "and only the player's own")
    -- red under: an ownership marker put in FRONT of the name, which would move the column
    -- checkpoint 1's padding bought, for exactly the rows that carry it.
    assertEqual(dd.list[key]:find("Affixes", 1, true), dd.list.healing:find("Healing", 1, true),
        "every name still starts at the same character offset")
end)

test("general → spell categories: the rename box and the create box cannot be mistaken for each other", function()
    local NS, _, P = spells()
    local key = NS.Categories.CreateUserCategory("Affixes", "HELPFUL")
    NS.GeneralSpells.Select(key)
    local ws = P.rerender("General")
    local mine = manage(NS, ws, P)
    assertTrue(mine.name ~= nil and mine.newName ~= nil, "both boxes are drawn")
    -- red under: the two labeled "Name" and "New category" -- one word apart, one row apart, both
    -- committing on Enter, and one of them renaming a live category with no undo. Each label now
    -- names its ACT.
    assertEqual(mine.name.labelText, NS.L["Rename this category"])
    assertEqual(mine.newName.labelText, NS.L["New category's name"])
    -- Only one of them is ever pre-filled: the rename box is redrawn from the store every render.
    assertEqual(mine.name.text, "Affixes")
    assertEqual(mine.newName.text, "")
    -- And a heading sits between them, so the block being read says which act it is.
    local head
    for i, w in ipairs(ws) do
        if w.type == "Heading" and w.text == NS.L["Make a new category"] then head = head or i end
    end
    assertTrue(head ~= nil, "the create form has a heading of its own")
    assertTrue(lineOf(ws, mine.name) < head, "the rename box is above it")
    assertTrue(head < lineOf(ws, mine.newName), "and the create box below it")
end)

test("general → spell categories: every act of the block answers in the panel, not only in chat", function()
    local NS, m, P, ws = spells()
    -- EMPTY NAME. red under: the refusal being NS.Print alone, so Create with an empty box
    -- re-rendered with nothing visibly different and the panel looked broken.
    manage(NS, ws, P).create:__fire("OnClick")
    local ws2 = P.rerender("General")
    assertTrue(P.hasText(ws2, NS.L["A category needs a name."]), "the refusal is on the panel")

    -- A SUCCESSFUL CREATE says what was made and what to do with it.
    local made = manage(NS, ws2, P)
    made.newName:__fire("OnTextChanged", "Affixes")
    made.create:__fire("OnClick")
    local ws3 = P.rerender("General")
    assertTrue(P.hasText(ws3, "Created 'Affixes'"), "and so is the act that worked")

    -- A DUPLICATE NAME is reported rather than refused (the ledger), and reported HERE.
    local dup = manage(NS, ws3, P)
    dup.newName:__fire("OnTextChanged", "Affixes")
    dup.create:__fire("OnClick")
    local ws4 = P.rerender("General")
    assertTrue(P.hasText(ws4, "There is already a category called 'Affixes'"))

    -- A RENAME SAYS THE OLD NAME BACK, which is the only undo a rename has: the box itself is
    -- redrawn from the store, so the previous name is nowhere else by the time it is wanted.
    manage(NS, ws4, P).name:__fire("OnEnterPressed", "Affixes II")
    local ws5 = P.rerender("General")
    assertTrue(P.hasText(ws5, "Renamed 'Affixes' to 'Affixes II'"))
    assertTrue(P.hasText(ws5, "type 'Affixes' back into the box"))

    -- A DELETE SAYS SO, because the tab jumps to the first category and would otherwise read as the
    -- dropdown changing its mind.
    local popups = P.popups()
    manage(NS, ws5, P).delete:__fire("OnClick")
    m.StaticPopupDialogs.AURAMASTER_DELETE_CATEGORY.OnAccept(popups[1], popups[1].data)
    assertTrue(P.hasText(P.rerender("General"), "Deleted 'Affixes II'"))

    -- And the line is about the act just run, so picking another category clears it.
    local ws6 = P.rerender("General")
    P.find(ws6, "Dropdown", NS.L["Category"]):__fire("OnValueChanged", "raidCDs")
    assertFalse(P.hasText(P.rerender("General"), "Deleted 'Affixes II'"))
end)

test("general → spell categories: a saved record the sync cannot read can be forgotten from the panel", function()
    local NS, m, P = spells()
    local id = NS.Database.GetContainers()[1].id
    NS.SetByPath("container.filter.categories.healing", "hide", id)
    -- Two shapes of stuck record: one inside the reserved namespace with no usable aura type, and
    -- one claiming a SHIPPED key. Neither materializes, so neither is in the dropdown and no Delete
    -- reaches it -- and forgetUserKey skips a profile that still holds a record under the key, so
    -- even their debris could never be swept while they sat there.
    NS.db.profile.userCategories["userbadbad00"] = { key = "userbadbad00", name = "Broken" }
    NS.db.profile.userCategories.healing = { key = "healing", name = "Forged", auraType = "HELPFUL" }
    NS.Categories.SyncUserCategories(NS.db.profile)
    assertEqual(#NS.Categories.UnusableUserRecords(NS.db.profile), 2, "both are unreadable")

    local ws = P.rerender("General")
    local btn = P.find(ws, "Button", NS.L["Forget unreadable categories"])
    -- red under: no way out at all, which is what "left on disk for the player to fix or delete"
    -- amounted to while nothing in the panel could reach them.
    assertTrue(btn ~= nil, "the panel offers a way out")
    local popups = P.popups()
    btn:__fire("OnClick")
    assertEqual(#popups, 1, "it asks first")
    assertEqual(popups[1].which, "AURAMASTER_FORGET_BROKEN_CATEGORIES")
    assertTrue(NS.db.profile.userCategories.healing ~= nil, "and discards nothing until accepted")

    m.StaticPopupDialogs.AURAMASTER_FORGET_BROKEN_CATEGORIES.OnAccept()
    assertNil(NS.db.profile.userCategories["userbadbad00"])
    assertNil(NS.db.profile.userCategories.healing)
    -- red under: sweeping the leaves of a record keyed with a SHIPPED key, which would take the
    -- shipped category's stored Show/Hide out of every profile in the account with it.
    assertEqual(NS.GetSetting("container.filter.categories.healing", id), "hide")
    assertTrue(NS.Categories.Find("HELPFUL", "healing") ~= nil)
    assertEqual(NS.ValidateSchema(), 0)
    assertNil(P.find(P.rerender("General"), "Button", NS.L["Forget unreadable categories"]),
        "and the line goes with them")
end)

-- ── the overlap guardrail (issue #10 checkpoint 7) ─────────────────────────────────────────────

test("general → spell categories: an id another category already claims is marked in the list and reported at the add", function()
    local NS, _, P = spells()
    local claimed = starterIds(NS, "defensives")[1]
    local key = NS.Categories.CreateUserCategory("Immunities", "HELPFUL")
    NS.GeneralSpells.Select(key)
    local chat = P.chat()
    -- The add itself is never refused: overlap is CORRECT (a defensive that is also an immunity),
    -- and the compiler draws such an aura once, under the first category set to Show.
    P.find(P.rerender("General"), "EditBox", NS.L["Add a spell"]):__fire("OnEnterPressed", tostring(claimed))
    assertEqual(NS.db.profile.categorySpells[key][claimed], true, "the add went through")
    local said = table.concat(chat, "\n")
    -- red under: blocking the add, or informing without naming WHICH category already claims it.
    assertTrue(said:find("also in", 1, true) ~= nil, "the add says so: " .. said)
    assertTrue(said:find(NS.L["Defensive cooldowns"], 1, true) ~= nil, "and names the category: " .. said)

    -- And the entry carries the same answer permanently, under its name in the list.
    local ws = P.rerender("General")
    assertTrue(P.hasText(ws, "Also in: " .. NS.L["Defensive cooldowns"]), "the entry is marked")

    -- The control: an id nothing else claims is neither reported nor marked.
    local quiet = P.chat()
    P.find(ws, "EditBox", NS.L["Add a spell"]):__fire("OnEnterPressed", "424242")
    assertEqual(#quiet, 0, "an unclaimed id says nothing")
    local ws2 = P.rerender("General")
    assertTrue(P.hasText(ws2, "Also in: " .. NS.L["Defensive cooldowns"]), "the claimed entry is still marked")
    assertFalse(P.hasText(ws2, "Also in: Immunities"),
        "and a category never reports itself as a claimant of its own entry")
end)

-- ── review round five: the headings, the answer line's lifetime and the counts (owner, 2026-09-21) ─

--- Make a category, then answer the widgets of the render that shows the line saying so.
local function withNotice(NS, P, ws)
    local made = manage(NS, ws, P)
    made.newName:__fire("OnTextChanged", "Affixes")
    made.create:__fire("OnClick")
    local drawn = P.rerender("General")
    assertTrue(P.hasText(drawn, "Created 'Affixes'"), "the act answered on the panel")
    return drawn
end

test("general → spell categories: the answer line dies with the profile it was said in", function()
    local NS, _, P, ws = spells()
    withNotice(NS, P, ws)
    -- red under: the line cleared by the Category dropdown alone, which is what it was. A profile
    -- switch replaces every category, list and container decision the sentence names, so the
    -- sentence is about a store that is no longer loaded -- and it survived one, so a player could
    -- open the panel and be told about an act they ran in a profile they had left.
    NS.db:SetProfile("Raid")
    assertFalse(P.hasText(P.rerender("General"), "Created 'Affixes'"),
        "the line does not follow the player into another profile")
    -- And the block still draws: the line went, not the render.
    assertTrue(P.find(P.rerender("General"), "Button", NS.L["Create category"]) ~= nil)
end)

test("general → spell categories: the answer line ends when the page leaves the screen", function()
    local NS, m, P, ws = spells()
    withNotice(NS, P, ws)
    -- The settings window closing, or another page being opened: either hides this panel.
    m.__subcategories["General"]:__fire("OnHide")
    -- NO RefreshAllPanels here, deliberately. Clearing the variable is only half the answer: a
    -- hidden page is not re-rendered on its next show unless something marked it dirty, so the
    -- sentence would still be sitting there in pixels when the panel came back. red under: the hide
    -- hook dropping the line without the structural refresh beside it.
    local back = P.show("General")
    assertTrue(#back > 0, "the page drew again on its own")
    assertFalse(P.hasText(back, "Created 'Affixes'"), "and without the line")
end)

test("general → spell categories: Weapon enchants has a lead-in, and its slots have a heading of their own", function()
    local NS, _, P, ws = spells()
    P.find(ws, "Dropdown", NS.L["Category"]):__fire("OnValueChanged", "weaponEnchants")
    ws = P.rerender("General")
    -- red under: the one entry in the dropdown whose picker said nothing at all about what it was
    -- picking, while every spell list above it has a lead-in.
    assertTrue(P.hasText(ws, "matches the temporary enchants on your weapons"),
        "the picker has a lead-in of its own")

    local slotsHead, createHead
    for i, w in ipairs(ws) do
        if w.type == "Heading" and w.text == NS.L["Weapon slots"] then slotsHead = slotsHead or i end
        if w.type == "Heading" and w.text == NS.L["Make a new category"] then createHead = createHead or i end
    end
    assertTrue(slotsHead ~= nil, "the slots are drawn under a heading")
    assertTrue(createHead ~= nil and createHead < slotsHead, "which comes after the create form's")
    -- red under: no heading here at all, which is what shipped. renderEnchant is called AFTER
    -- renderManage, and a heading owns everything drawn beneath it until the next one -- so the
    -- lead-in and all three checkboxes landed under "Make a new category" and read as part of the
    -- create form.
    for _, slot in ipairs({ "mainHand", "offHand", "ranged" }) do
        local cb = P.row(ws, "enchantSlots." .. slot)
        assertTrue(cb ~= nil and cb.type == "CheckBox", slot .. " is drawn")
        assertTrue(lineOf(ws, cb) > slotsHead, slot .. " sits under the slots heading, not the create form's")
    end
end)

test("general → spell categories: a claimed-by note says when the other category is one the player made", function()
    local NS, _, P = spells()
    local key = NS.Categories.CreateUserCategory("Immunities", "HELPFUL")
    local mine = marked(NS, key):gsub("^.*%] +", "")   -- the name as the panel writes it, marker and all
    NS.SetByPath("categorySpells", { [key] = { [424242] = true, [424243] = true }, defensives = { [424242] = true } })
    NS.GeneralSpells.Select("defensives")

    -- red under: the note built from the compiler's bare label, which is `Cat.LabelOf` and carries
    -- no ownership marker -- so a note whose whole job is to say where else a spell already lives
    -- could name a category the player made without saying it was theirs.
    local ws = P.rerender("General")
    assertTrue(P.hasText(ws, "Also in: " .. mine), "the entry's note marks it")
    assertTrue(mine:find("(yours)", 1, true) ~= nil, "and the marker is what a user category wears")

    local chat = P.chat()
    P.find(ws, "EditBox", NS.L["Add a spell"]):__fire("OnEnterPressed", "424243")
    local said = table.concat(chat, "\n")
    assertTrue(said:find("also in: " .. mine, 1, true) ~= nil, "and so does the line at the add: " .. said)

    -- The control: one of Aura Master's own is named without a marker, here as everywhere else.
    NS.GeneralSpells.Select(key)
    assertTrue(P.hasText(P.rerender("General"), "Also in: " .. NS.L["Defensive cooldowns"]))
end)

test("general → spell categories: one unreadable record reads in the singular", function()
    local NS, m, P = spells()
    NS.db.profile.userCategories["userbadbad00"] = { key = "userbadbad00", name = "Broken" }
    NS.Categories.SyncUserCategories(NS.db.profile)
    assertEqual(#NS.Categories.UnusableUserRecords(NS.db.profile), 1, "one, which is the common count")

    -- red under: plural-only strings, which is what shipped -- "Aura Master cannot read 1 of this
    -- profile's saved categories, so they are in no list", and a confirmation offering to forget
    -- "the 1 saved categories".
    local ws = P.rerender("General")
    assertTrue(P.hasText(ws, "so it is in no list and nothing is using it"), "the line agrees with its count")
    assertFalse(P.hasText(ws, "so they are in no list"), "and does not also say the plural")

    local popups = P.popups()
    P.find(ws, "Button", NS.L["Forget unreadable categories"]):__fire("OnClick")
    local dialog = m.StaticPopupDialogs.AURAMASTER_FORGET_BROKEN_CATEGORIES
    assertEqual(dialog.text, NS.L["Forget the saved category Aura Master cannot read? It is in no list and cannot be repaired from here, and whatever it held is discarded. Your other categories are not affected."])
    dialog.OnAccept()
    assertTrue(P.hasText(P.rerender("General"), "Forgot 1 unreadable saved category."), "and so does the answer")

    -- Two is still the plural, on the same dialog: the sentence is picked at the show.
    NS.db.profile.userCategories["userbadbad00"] = { key = "userbadbad00", name = "Broken" }
    NS.db.profile.userCategories["userbadbad01"] = { key = "userbadbad01", name = "Also broken" }
    NS.Categories.SyncUserCategories(NS.db.profile)
    local ws2 = P.rerender("General")
    assertTrue(P.hasText(ws2, "so they are in no list and nothing is using them"))
    P.find(ws2, "Button", NS.L["Forget unreadable categories"]):__fire("OnClick")
    assertEqual(#popups, 2, "both presses asked first")
    assertTrue(dialog.text:find("the %d saved categories", 1, true) ~= nil, "the plural sentence is back")
    dialog.OnAccept()
    assertTrue(P.hasText(P.rerender("General"), "Forgot 2 unreadable saved categories."))
end)

test("general → spell categories: a profile that refuses the sweep is said out loud, not only logged", function()
    local NS, m, P = spells()
    local key = NS.Categories.CreateUserCategory("Affixes", "HELPFUL")
    NS.GeneralSpells.Select(key)
    -- A stored profile whose container table raises on any read. The delete is recoverable rather
    -- than atomic (tests/test_database.lua pins that), so it still goes -- but "Deleted 'Affixes'"
    -- alone claims a little more than happened.
    NS.db.sv.profiles.Broken = {
        seeded = true, nextContainerId = 2, containerOrder = { 1 },
        containers = { setmetatable({}, { __index = function() error("stored table is broken") end }) },
        categorySpells = { [key] = { [424242] = true } },
        userCategories = {}, userCategoryOrder = {},
    }

    local ws = P.rerender("General")
    local popups = P.popups()
    manage(NS, ws, P).delete:__fire("OnClick")
    m.StaticPopupDialogs.AURAMASTER_DELETE_CATEGORY.OnAccept(popups[1], popups[1].data)
    -- red under: the panel reading only `ok` and saying "Deleted 'Affixes'. This tab is showing
    -- another category now.", with the refusal visible in NS.Debug and nowhere a player looks.
    local after = P.rerender("General")
    assertTrue(P.hasText(after, "Deleted 'Affixes'"), "it still leads with what went")
    assertTrue(P.hasText(after, "One saved profile could not be tidied up"), "and names what did not")
    assertTrue(NS.db.profile.userCategories[key] == nil, "the category is gone all the same")
    assertEqual(NS.ValidateSchema(), 0)
end)

-- ── the Spell Categories add line: suggestions while typing, and where a name can come from (#31) ─

--- The id lookups and the suggestions' sources (the bags, the spellbook, a spell's subtext), from
--- the kit's opt-in tests/_kit/mock_ids.lua. AM's own C_Spell.GetSpellInfo keeps answering.
local function withIds(m)
    dofile("tests/_kit/mock_ids.lua")(m)
    m.installIdSuggestions()
end

--- Seed spell `id` with `name` in the mock client, which never finds a spell BY NAME: only the
--- candidates can resolve one.
local function spell(m, id, name, rank)
    m.__spells[id] = { name = name, iconID = 1 }
    if rank then m.setSpellSubtext(id, rank) end
end

--- The Spell Categories tab drawn again after `seed(NS, m)`, recording the suggestion dropdown:
--- NS, m, P, the widgets, the dropdown's reader and the Add a spell box.
local function suggesting(seed)
    local NS, m, P = spells({ before = withIds })
    if seed then seed(NS, m) end
    local ws = P.rerender("General")
    return NS, m, P, ws, P.suggestions(), P.find(ws, "EditBox", NS.L["Add a spell"])
end

--- Four spells only the candidates know: an added spell in another category, one on a container's
--- whitelist, one on another container's blacklist, and a learned timed buff.
local function seedZephyrs(NS, m)
    spell(m, 5601, "Zephyr Ward"); spell(m, 5602, "Zephyr Veil")
    spell(m, 5603, "Zephyr Step"); spell(m, 5604, "Zephyr Guard")
    NS.SetByPath("categorySpells", { raidCDs = { [5601] = true } })
    NS.SetByPath("container.filter.whitelist", { [5602] = true }, 1)
    NS.SetByPath("container.filter.blacklist", { [5604] = true }, 2)
    NS.db.global.timedSpells = { [5603] = true }
end

test("general → spell categories: typing lists the candidates — the profile's edits, every container's overrides, the learned timed buffs", function()
    local _, _, _, _, S, box = suggesting(seedZephyrs)
    S.type(box, "zephyr")
    -- red under: candidates() omitting the profile's categorySpells ids (5601) or the containers'
    -- whitelist and blacklist ids (5602, 5604) — the client cannot enumerate spells a character
    -- does not know, so the list shows only what the candidates hand it
    assertEqual(S.ids(true), "5601,5602,5603,5604")
    S.type(box, "rejuv")
    assertEqual(S.ids(), "774", "and any category's starter")
end)

test("general → spell categories: a name only the candidates know resolves — another category's added spell, a spell on any container's overrides", function()
    local NS, _, _, _, _, box = suggesting(seedZephyrs)
    box:__fire("OnEnterPressed", "Zephyr Ward")
    -- red under: candidates() omitting the profile's categorySpells ids
    assertEqual(NS.db.profile.categorySpells.defensives[5601], true)
    box:__fire("OnEnterPressed", "zephyr guard")
    -- red under: candidates() reading the selected container's lists only (5604 is container 2's)
    assertEqual(NS.db.profile.categorySpells.defensives[5604], true)
end)

test("general → spell categories: picking a suggestion adds it through the one writer, exactly once", function()
    local NS, _, _, _, S, box = suggesting(seedZephyrs)
    S.type(box, "zephyr w")
    local row = S.row(5601)
    assertTrue(row ~= nil, "Zephyr Ward is offered")
    local paths = spyPaths(NS)
    row:__fire("OnClick")
    -- red under: a pick that bypasses onAdd, or an onAdd that writes more than the whole set once
    assertEqual(table.concat(paths, ","), "categorySpells")
    assertEqual(NS.db.profile.categorySpells.defensives[5601], true)
    assertEqual(S.ids(), "", "the pick closes the list")
end)

test("general → spell categories: a name two ranks share lists both, labeled; Enter without a pick adds neither", function()
    local NS, _, P, ws, S, box = suggesting(function(NS2, m)
        spell(m, 5611, "Hushed Zephyr", "Rank 1")
        spell(m, 5612, "Hushed Zephyr", "Rank 2")
        NS2.db.global.timedSpells = { [5611] = true, [5612] = true }
    end)
    S.type(box, "hushed zephyr")
    assertEqual(S.ids(), "5611,5612", "every rank is its own row")
    assertTrue(S.row(5611).labelText:find("Rank 1", 1, true) ~= nil, "labeled with its rank")
    assertTrue(S.row(5612).labelText:find("Rank 2", 1, true) ~= nil)
    local msgs = P.messages()
    box:__fire("OnEnterPressed", "Hushed Zephyr")
    -- red under: a shared name resolving to one rank the player did not pick (or to both)
    assertEqual(msgs.config, 0, "Enter without a pick writes nothing")
    assertNil(NS.db.profile.categorySpells.defensives)
    -- red under: the host's ambiguous string still saying only "Use the id", with a list up to pick from
    assertTrue(P.hasText(ws, "Several spells are named 'Hushed Zephyr' — pick one from the list, or use the id."))
    assertEqual(S.ids(), "5611,5612", "the refusal lists the ranks to pick from")
    S.row(5612):__fire("OnClick")
    assertEqual(NS.db.profile.categorySpells.defensives[5612], true, "the picked rank is added")
    assertNil(NS.db.profile.categorySpells.defensives[5611], "and only it")
end)

test("general → spell categories: the add line's tooltip and its refusal say where a name can come from", function()
    local NS, m, P, ws = spells()
    local hint = NS.L["Names work for spells in your spellbook and ones this list knows; otherwise use the id or shift-click a link."]
    -- red under: the enUS hint drifting from the library's own (the tooltip and the refusal quote it)
    assertEqual(hint, NS.Helpers.ID_NAME_HINT.spell)
    local lines = {}
    rawset(m.GameTooltip, "AddLine", function(_, s)
        lines[#lines + 1] = s
    end)
    local box = P.find(ws, "EditBox", NS.L["Add a spell"])
    box:__fire("OnEnter")
    -- red under: the tooltip without the hint, or still promising that any name "the game cannot
    -- find" is matched (a spell no list knows and the spellbook lacks cannot be named at all)
    assertTrue((lines[1] or ""):find(hint, 1, true) ~= nil, "the tooltip carries the hint")
    assertFalse((lines[1] or ""):find("cannot find", 1, true) ~= nil)
    box:__fire("OnEnterPressed", "No Such Spell")
    -- red under: spec.strings without nameHint (the library's `{hint}` would read empty)
    assertTrue(P.hasText(ws, "No spell named 'No Such Spell' in your spellbook. " .. hint))
end)

test("general → spell categories: a starter's X stores false and drops it from the list; adding it again drops the edit (B2)", function()
    local NS, _, P, ws = spells()
    local id = starterIds(NS, "defensives")[1]
    local _, x = entry(ws, id)
    x:__fire("OnClick")
    -- red under: a starter's X storing nil (the starter list would put it straight back)
    assertEqual(NS.db.profile.categorySpells.defensives[id], false)
    ws = P.rerender("General")
    -- red under: entriesFor still listing a removed starter
    assertNil(entry(ws, id), "a removed starter is off the list")
    P.find(ws, "EditBox", NS.L["Add a spell"]):__fire("OnEnterPressed", tostring(id))
    -- red under: onAdd storing `true` for a starter (an addition that duplicates the shipped spell)
    assertNil(NS.db.profile.categorySpells.defensives, "adding a removed starter back includes it again")
end)

test("general → spell categories: choosing another category lists its starters, by name where the client knows them", function()
    local NS, _, P, ws = spells()
    P.find(ws, "Dropdown", NS.L["Category"]):__fire("OnValueChanged", "healing")
    -- red under: the category dropdown not keeping its choice across the re-render it asks for
    ws = P.rerender("General")
    assertEqual(P.find(ws, "Dropdown", NS.L["Category"]).value, "healing")
    local rejuv = entry(ws, 774)
    assertTrue(rejuv ~= nil and rejuv.text:find("Rejuvenation", 1, true) ~= nil, "Rejuvenation is listed by name")
    assertTrue(entry(ws, 8936) ~= nil, "a spell the client does not know is listed by id")
    assertNil(entry(ws, starterIds(NS, "defensives")[1]), "the defensives are not")
end)

test("general → spell categories: Restore sits above the Add line and clears that category's edits and no other's (B2)", function()
    local NS, _, P = spells()
    NS.SetByPath("categorySpells", { defensives = { [118038] = false, [424242] = true }, raidCDs = { [99] = true } })
    local ws = P.rerender("General")
    local restore = P.find(ws, "Button", NS.L["Restore this category's starter list"])
    local at = {}
    for i, w in ipairs(ws) do
        if w == restore then at.restore = i end
        if w.type == "EditBox" and w.labelText == NS.L["Add a spell"] then at.add = i end
    end
    -- red under: the restore still drawn under the list (a removed starter has no way back in view)
    assertTrue(at.restore < at.add, "Restore above Add a spell")
    restore:__fire("OnClick")
    local edits = NS.db.profile.categorySpells
    -- red under: the restore writing an empty set for every category
    assertNil(edits.defensives)
    assertEqual(edits.raidCDs[99], true)
end)

test("general → spell categories: Restore sits on the Category dropdown's line, to its right (feedback #3)", function()
    local NS, _, P, ws = spells()
    local dd = P.find(ws, "Dropdown", NS.L["Category"])
    local restore = P.find(ws, "Button", NS.L["Restore this category's starter list"])
    local line
    for _, w in ipairs(ws) do
        if w.children and w.children[1] == dd then line = w end
    end
    -- red under: Restore still drawn by InlineButtonPair on a line of its own under the dropdown
    assertTrue(line ~= nil, "the dropdown heads a grid line")
    assertTrue(line.children[2] == restore, "Restore is the same line's second cell")
    assertEqual(restore.relativeWidth, NS.Helpers.BUTTON_PAIR_REL, "a cell-filling button takes the inset width")
end)

-- ── the Weapon enchants entry, and the Select seam (B7) ──────────────────────────────────────

test("general → spell categories: choosing Weapon enchants draws slot toggles, not a spell list", function()
    local NS, _, P, ws = spells()
    P.find(ws, "Dropdown", NS.L["Category"]):__fire("OnValueChanged", "weaponEnchants")
    ws = P.rerender("General")
    -- red under: the enchant entry drawing an (empty) spell list instead of its own controls
    assertTrue(P.row(ws, "enchantSlots.mainHand") ~= nil, "the Main hand toggle is drawn")
    assertTrue(P.row(ws, "enchantSlots.offHand") ~= nil, "the Off hand toggle is drawn")
    assertTrue(P.row(ws, "enchantSlots.ranged") ~= nil, "the Ranged toggle is drawn")
    assertNil(P.find(ws, "EditBox", NS.L["Add a spell"]), "no add line for a category with no spell list")
    assertTrue(P.hasText(ws, "Filters -> Categories"), "says where the per-container switch lives")
end)

test("general → spell categories: the Weapon enchants entry explains the all-slots fallback", function()
    local NS, _, P, ws = spells()
    P.find(ws, "Dropdown", NS.L["Category"]):__fire("OnValueChanged", "weaponEnchants")
    ws = P.rerender("General")
    -- red under: deleting the fallback explanation (unticking every slot still reads all three,
    -- modules/FilterCompiler.lua's enchantBlock), which would leave the panel looking broken
    assertTrue(P.hasText(ws, "all three are read anyway"), "says unticking every slot changes nothing")
end)

test("general → spell categories: unticking a weapon slot writes the profile, one row at a time", function()
    local NS, _, P, ws = spells()
    P.find(ws, "Dropdown", NS.L["Category"]):__fire("OnValueChanged", "weaponEnchants")
    ws = P.rerender("General")
    local cb = P.row(ws, "enchantSlots.offHand")
    -- red under: a slot toggle not reaching the profile, so unticking one changes nothing
    cb:__fire("OnValueChanged", false)
    assertEqual(NS.db.profile.enchantSlots.offHand, false)
    assertEqual(NS.db.profile.enchantSlots.mainHand, true, "another slot is untouched")
end)

test("general: Select moves the Spell Categories tab onto the given category, and ignores a key it cannot draw", function()
    local NS, _, P = general()
    NS.GeneralSpells.Select("raidCDs")
    local ws = P.rerender("General")
    assertEqual(P.find(ws, "Dropdown", NS.L["Category"]).value, "raidCDs", "landed on raidCDs")
    -- red under: Select storing a key this tab cannot draw (cancelable is a token category, no list)
    NS.GeneralSpells.Select("cancelable")
    ws = P.rerender("General")
    assertEqual(P.find(ws, "Dropdown", NS.L["Category"]).value, "raidCDs", "the stale selection is kept")
end)

test("general: Select accepts the enchant key too, and lands the tab on it", function()
    local NS, _, P = general()
    NS.GeneralSpells.Select("weaponEnchants")
    local ws = P.rerender("General")
    assertEqual(P.find(ws, "Dropdown", NS.L["Category"]).value, "weaponEnchants")
    assertTrue(P.row(ws, "enchantSlots.mainHand") ~= nil, "the tab moved and drew the slot toggles")
end)

test("general → spell categories: the tab and Dispel Colors are drawn with no container at all", function()
    local NS, _, P = general()
    for _, c in ipairs(NS.Database.GetContainers()) do NS.ContainerManager.Delete(c.id) end
    P.rerender("General")
    -- red under: the tabs gated on a container (they edit the profile, which exists regardless)
    local ws = P.tab("general", NS.L["Spell Categories"])
    assertTrue(P.find(ws, "Dropdown", NS.L["Category"]) ~= nil)
    ws = P.tab("general", NS.L["Dispel Colors"])
    assertTrue(P.row(ws, "dispelColors.Magic") ~= nil)
end)

-- ── the Dispel Colors tab (G-3) ───────────────────────────────────────────────────────────────

test("general → dispel colors: five profile-wide swatches, no None, no class-color companion, under a line saying they drive bars and text", function()
    local NS, _, P, _, tab = general()
    local ws = tab(NS.L["Dispel Colors"])
    for _, name in ipairs(NS.Constants.DISPEL_TYPES) do
        local row = NS.FindSchemaRow("dispelColors." .. name)
        -- red under: the rows left on the Bars page's Highlights tab
        assertEqual(row.page, "general", name)
        assertEqual(row.group, NS.L["Dispel Colors"], name)
        local cp = P.row(ws, "dispelColors." .. name)
        assertTrue(cp ~= nil and cp.type == "ColorPicker", "a swatch for " .. name)
    end
    -- red under: the None swatch still drawn (an aura with no type keeps the surface's color, feedback #7)
    assertEqual(#P.all(ws, "ColorPicker"), 5)
    assertEqual(NS.FindSchemaRow("dispelColors.None"), nil, "no None row")
    -- red under: a class-color companion beside a palette swatch (options-ui-§17's exemption)
    assertEqual(#P.all(ws, "CheckBox"), 0)
    -- red under: the tab still promising an icon's dispel border the tint (owner 2026-09-13:
    -- keep Blizzard's own dispel colors), or silent on the Text style's word, backdrop and edge
    -- (feedback #7)
    -- 2026-09-20: the one paragraph is now a lead-in and four bullets, each its own Label line
    -- (settings/Filters.lua's priority block, same shape). The FACTS are unchanged.
    assertTrue(P.hasText(ws, NS.L["One color per dispel type, shared by every container:"]))
    assertTrue(P.hasText(ws, "- " .. NS.L["Read by bars colored by dispel type, and by a text line's dispel type word, backdrop or edge (Text -> Font)."]))
    -- Split in two: at panel width the single ~170-char fact wrapped, and its second line landed
    -- flush under the "- " with no hanging indent, so the block read 1/2/1 lines instead of 1/1/1.
    assertTrue(P.hasText(ws, "- " .. NS.L["Buffs and many debuffs have no dispel type at all, class debuffs such as Judgment or Consecration included."]))
    assertTrue(P.hasText(ws, "- " .. NS.L["Those keep a bar's own color, and show no type word, backdrop or edge."]))
    assertTrue(P.hasText(ws, "- " .. NS.L["An icon's dispel border keeps Blizzard's own colors."]))
    for _, name in ipairs(NS.Constants.DISPEL_TYPES) do
        local desc = NS.FindSchemaRow("dispelColors." .. name).desc
        -- red under: a row desc still naming the tint on an icon's dispel border
        assertEqual(desc, NS.L["This dispel type's color for a bar's fill or background, and for a text line's dispel type word, backdrop or edge when those are on. An icon's dispel border keeps Blizzard's own colors."], name)
    end
end)

test("general → dispel colors: a swatch writes its own type's color and re-applies every container", function()
    local NS, _, P, _, tab = general()
    local ws = tab(NS.L["Dispel Colors"])
    local calls = spyApply(NS)
    P.row(ws, "dispelColors.Poison"):__fire("OnValueConfirmed", 1, 0, 1, 1)
    local dc = NS.db.profile.dispelColors
    -- red under: the dispel rows sharing one path, or carrying an `effect` (no re-apply)
    assertEqual(dc.Poison.g, 0)
    assertEqual(dc.Magic.r, NS.Constants.DEFAULT_DISPEL_COLORS.Magic.r, "the other types keep theirs")
    assertEqual(#calls, 1)
    assertEqual(calls[1], "all", "a profile-wide row re-applies every container")
end)

test("general → dispel colors: the page's Defaults restores them", function()
    local NS, m = general()
    NS.SetByPath("dispelColors.Magic", { r = 0, g = 0, b = 0, a = 1 })
    m.__subcategories.General.defaultsOnClick()
    -- red under: the rows registered on a page other than General (its Defaults would miss them)
    assertEqual(NS.db.profile.dispelColors.Magic.r, NS.Constants.DEFAULT_DISPEL_COLORS.Magic.r)
end)
