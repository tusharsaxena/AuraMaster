-- tests/test_pages_general.lua — settings/General.lua, GeneralSpells.lua and GeneralDispel.lua, driven
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
    -- red under: rewording the one sentence options-ui-§12 fixes for every addon's global reset
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

--- The muted markers the panel colors with (settings/GeneralSpells.lua's TYPE_COLORS and
--- YOURS_COLOR). Restated here as literals on purpose: the panel's own constants are file-local, so
--- these are what say a color CHANGED, and the register they were picked from -- the drag handle's
--- gold (1, 0.82, 0) and its help mark (0.7, 0.7, 0.72) -- is written above the constants there.
local TYPE_COLOR = { HELPFUL = "|cff73bf80", HARMFUL = "|cffcc7373" }
local YOURS_COLOR = "|cffd9b861"

--- `text` with every color escape taken out: what the client actually DRAWS. `|cAARRGGBB` and `|r`
--- are read by the client and rendered as nothing at all, so this is the string a player's eye
--- measures -- which is what the padding case asserts the name column against.
local function rendered(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

--- The Category dropdown's label for `key`, built the way the panel builds it: the aura type's own
--- `C.AURA_TYPE_LABELS` word in its bracket, colored, then padding out to the widest such word, then
--- the category's name (settings/GeneralSpells.lua's `categoryLabel`, issue #10 checkpoint 1 and the
--- owner's colors of 2026-09-21). Built here out of the SAME locale strings rather than hard-coded,
--- so a case asserting it asserts the composition and never re-states the wording -- which is also
--- why it is NOT the only thing the marker cases rest on: this helper takes the aura type from the
--- accessor under test, so the cases below anchor the type itself to the literal label and to the
--- list the category is declared in.
---
--- THE PADDING IS MEASURED ON THE BARE WORD HERE TOO, which is the whole point: a helper that padded
--- the colored mark would agree with a panel that did the same, and both would be wrong by twelve
--- characters the player cannot see. `rendered` above is the second, independent check.
local function marked(NS, key, auraType)
    auraType = auraType or NS.Categories.AuraTypeOf(key)
    local def = NS.Categories.Find(auraType, key)
    -- Byte length is character length here: the locale guard already holds enUS to ASCII.
    local widest = 0
    for _, word in pairs(NS.Constants.AURA_TYPE_LABELS) do
        local n = #NS.L[word]
        widest = math.max(widest, n)
    end
    local word = NS.L[NS.Constants.AURA_TYPE_LABELS[auraType]]
    local pad = (" "):rep(widest - #word)
    -- A category the player made carries the ownership marker too, in muted gold, and it is a SUFFIX
    -- on the name rather than a second prefix, so the padding above still starts every name at one
    -- offset.
    local name = NS.Categories.LabelOf(def)
    if NS.Categories.IsUserCategory(def) then
        name = (NS.L["{name} {mark}"]
            :gsub("{mark}", function() return YOURS_COLOR .. NS.L["(yours)"] .. "|r" end)
            :gsub("{name}", function() return name end))
    end
    local mark = TYPE_COLOR[auraType] .. (NS.L["[{type}]"]:gsub("{type}", function() return word end)) .. "|r"
    return (NS.L["{mark} {name}"]
        :gsub("{mark}", function() return mark end)
        :gsub("{name}", function() return pad .. name end))
end

--- `key`'s name as the panel writes it in a list of categories: the 'yours' marker, no aura type.
--- `NS.GeneralSpells.MarkedName` is the panel's ONE definition of that, so the claimed-by cases read
--- it rather than composing a second one.
local function ownedName(NS, key)
    local def = NS.Categories.Find("HELPFUL", key) or NS.Categories.Find("HARMFUL", key)
    return NS.GeneralSpells.MarkedName(def)
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
---
--- NEITHER MATCH IS ANCHORED AT THE END any more: since LibKa0s v1.49.0 an entry may carry a
--- `suffix` drawn inside the same label after the id ("(also in 1)", settings/GeneralSpells.lua's
--- overlap guardrail), so the id is no longer the last thing in the string. The first
--- "(<digits>)|r" in the label is the id; the count in a suffix never wears parentheses of its own.
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
                local id = t:match("%((%d+)%)|r") or t:match("^Unknown spell (%d+)")
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

--- The lines an IdList entry's tooltip draws when the entry is hovered, joined. The claim line
--- ("Also in: ...") is added there by settings/GeneralSpells.lua's own kind table, under the
--- client's spell tooltip, which is where the NAMES live now that the row itself carries only a
--- count. Same idiom as the Reset-all tooltip case above: capture the mocked GameTooltip's AddLine.
local function entryTooltip(m, lbl)
    local lines = {}
    rawset(m.GameTooltip, "AddLine", function(_, s)
        lines[#lines + 1] = s
    end)
    lbl:__fire("OnEnter")
    return table.concat(lines, "\n")
end

--- The Icon carrying entry `id`'s "?" help mark, and whether that entry was drawn at all — which
--- entryHelp and entryHelpTint below both read, because the mark's LINES and its TINT are two
--- claims about one widget (the severity, 2026-09-22) and both have to walk the row the same way.
---
--- WALKED IN ORDER, because a Flow row holds TWO entries at two columns and each has its own mark.
--- The library draws [X] [?] [label] per entry, so the mark in force when a label is reached is the
--- one belonging to it -- picking "the first Icon in the row" would answer the left entry's mark
--- for the right entry's label. `__helpLines` is what the library records on the Icon (v1.51.0);
--- the kit's fake has no texture and no tooltip to hover, so it is the only way to read one.
local function entryMark(ws, id)
    for _, row in ipairs(ws) do
        local mark
        for _, kid in ipairs(row.children or {}) do
            if kid.type == "Icon" and kid.__helpTint then
                mark = kid
            elseif kid.type == "InteractiveLabel" and type(kid.text) == "string" then
                local drawn = kid.text:match("%((%d+)%)|r") or kid.text:match("^Unknown spell (%d+)")
                if drawn and tonumber(drawn) == id then
                    return mark, true
                end
            end
        end
    end
    return nil
end

--- The lines an entry's "?" help mark carries, joined; "" for a mark with nothing behind it, and
--- nil when the entry was not drawn at all.
local function entryHelp(ws, id)
    local mark, drawn = entryMark(ws, id)
    if not drawn then return nil end
    if not (mark and mark.__helpLines) then return "" end
    return table.concat(mark.__helpLines, "\n")
end

--- The color `id`'s mark was tinted, as a comparable string, or nil when it drew no mark.
---
--- COMPARED, NEVER SPELLED OUT. The library owns the numbers (ID_HELP_TINT and ID_HELP_DIM,
--- libs/LibKa0s/OptionsWidgets.lua:1956-1958, and the severity tints beside them), and a case that
--- restated them here would go red on a palette change that broke nothing. What the page promises
--- is that the three severities do not LOOK alike, so that is what is asserted.
local function entryHelpTint(ws, id)
    local mark = entryMark(ws, id)
    if not (mark and mark.__helpTint) then return nil end
    return table.concat(mark.__helpTint, ",")
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
    -- SAY WHAT CANVAS THIS PACKS INTO. From LibKa0s v1.50.0 `columns` is a maximum, fitted to
    -- the measured content width, and the kit's ScrollFrame fixture is 400 (380 of content
    -- after OptionsScroll's gutter) -- under the icon style's 520px two-column floor, so the
    -- library would correctly draw ONE column and this case would be asserting the fixture
    -- rather than the packing. 700 pays for two columns in either style; see P.canvasWidth.
    P.canvasWidth(700)
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
        -- red under: the color escape read as part of the marker's text, which is how this goes
        -- wrong -- `rendered` is what the player sees, and there the prefix is exactly as it was.
        assertEqual(rendered(dd.list[key]):sub(1, #word + 3), "[" .. word .. "] ", key .. ": marked as a prefix")
        -- red under: the marker drawn in no color at all, or in the OTHER aura type's color.
        assertEqual(dd.list[key]:sub(1, 10), TYPE_COLOR[auraType], key .. ": colored by aura type")
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
    assertEqual(rendered(dd.list.weaponEnchants):sub(1, 8), "[" .. NS.L["Buffs"] .. "] ")
    -- Anchored to the literal rather than to the accessor: everything above builds its expectation
    -- by asking Cat.AuraTypeOf, so a build in which EVERY category answered the wrong type would
    -- still pass. These two say what a player reads, in full, padding included.
    assertEqual(dd.list.hardCC, "|cffcc7373[Debuffs]|r Hard CC (loss of control)")
    assertEqual(dd.list.healing, "|cff73bf80[Buffs]|r   Healing")
    -- And what the client DRAWS of those two, which is the pair the padding is for.
    assertEqual(rendered(dd.list.hardCC), "[Debuffs] Hard CC (loss of control)")
    assertEqual(rendered(dd.list.healing), "[Buffs]   Healing")
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
    --
    -- MEASURED ON THE RENDERED STRING (owner's colors, 2026-09-21). The markers now carry
    -- `|cAARRGGBB` and `|r`, which the client reads and draws as NOTHING -- so a padding computed
    -- over the colored string would pad by twelve phantom characters, and a case measuring the
    -- colored string would agree with it and pass. `rendered` strips every escape, so what is
    -- compared here is the text the player's eye lines up.
    local at
    for _, key in ipairs(dd.order) do
        local def = NS.Categories.Find(NS.Categories.AuraTypeOf(key), key)
        local shown = rendered(dd.list[key])
        local i = shown:find(NS.Categories.LabelOf(def), 1, true)
        assertTrue(i ~= nil, key .. ": the name is in the entry")
        at = at or i
        -- red under: the padding dropped from categoryLabel, or measured over the colored mark
        assertEqual(i, at, key .. ": the name starts where every other name starts")
        -- red under: an escape left in what the player reads -- `rendered` must take out every one
        -- of them, or the offsets above are a statement about nothing.
        assertNil(shown:find("|c", 1, true), key .. ": no escape survives the strip")
        assertNil(shown:find("|r", 1, true), key)
    end
    -- red under: a padding rule that happens to align only one aura type's rows with itself
    assertEqual(rendered(dd.list.softCC):find("Soft CC", 1, true),
        rendered(dd.list.healing):find("Healing", 1, true))
    -- The escapes are the same length on both aura types (one `|c` and one `|r` each), so the
    -- column survives in BYTES as well -- which is what every other case here indexes with.
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
-- The tab's LAYOUT, as the owner arranged it from the live panel (2026-09-22):
--
--     [ Category ................................ ]   <- the whole row
--     [ Rename ] [ Delete ]
--     ---- Make a new category ----
--     [ New category's name ] [ Create category ]
--     [ Aura type ]
--
-- Pinned because every other case on this tab finds its widgets by LABEL, which is exactly what a
-- layout change does not disturb -- the arrangement could drift back with the whole suite green.
test("general → spell categories: the picker owns its row, and Create sits beside the name (owner 2026-09-22)", function()
    local NS, _, P, ws = spells()
    local picker = P.find(ws, "Dropdown", NS.L["Category"])
    -- The shipped branch puts Restore beside the picker, so make a user category first: that is
    -- the branch with nothing to share the line with.
    assertTrue(picker ~= nil, "the picker is drawn")
    local m = manage(NS, ws, P)
    m.newName:__fire("OnEnterPressed", "Cooldowns I watch")
    m.create:__fire("OnClick")
    ws = P.rerender("General")
    picker = P.find(ws, "Dropdown", NS.L["Category"])
    -- red under the half-width picker, which left empty space where a control looked like it had
    -- failed to draw and truncated "(yours)" off a long name for no reason
    assertTrue(picker.fullWidth == true, "the picker takes the whole row when nothing shares it")

    local m2 = manage(NS, ws, P)
    local nameLine = lineOf(ws, m2.newName)
    -- red under the previous arrangement, which paired the name with Aura type and gave Create a
    -- line of its own
    assertEqual(lineOf(ws, m2.create), nameLine, "Create sits beside the box it consumes")
    assertTrue(lineOf(ws, m2.auraType) > nameLine, "Aura type is on its own line under them")
end)

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

-- Owner, 2026-09-21, from the live panel: the block drew a "This category" heading over a sentence
-- saying the selected category is Aura Master's own, on twelve of the fourteen entries. Neither is
-- wanted. A shipped category now draws NOTHING between the picker and "Make a new category".
test("general → spell categories: a shipped category draws no controls, no heading and no sentence (owner 2026-09-21)", function()
    local NS, _, P, ws = spells()
    local shipped = manage(NS, ws, P)
    -- red under: drawing the two controls for every category and leaving the refusal to the act,
    -- which would offer the player a Delete that can only ever fail.
    assertNil(shipped.name, "a shipped category has no name box")
    assertNil(shipped.delete, "and no Delete")
    -- red under: the lock sentence, or a heading over the empty space where it stood.
    assertFalse(P.hasText(ws, "one of Aura Master's own categories"), "and no sentence saying so")
    for _, w in ipairs(ws) do
        assertFalse(w.type == "Heading" and w.text == "This category", "no heading over nothing")
    end
    assertTrue(shipped.create ~= nil, "but a category can still be made from here")
    -- The create form still opens the next block, which is what keeps this from reading as a run-on.
    local head
    for i, w in ipairs(ws) do
        if w.type == "Heading" and w.text == NS.L["Make a new category"] then head = head or i end
    end
    assertTrue(head ~= nil, "'Make a new category' still names itself")

    local key = NS.Categories.CreateUserCategory("Mine", "HELPFUL")
    NS.GeneralSpells.Select(key)
    local ws2 = P.rerender("General")
    local mine = manage(NS, ws2, P)
    assertTrue(mine.name ~= nil and mine.delete ~= nil, "a category the player made has both")
    assertFalse(P.hasText(ws2, "one of Aura Master's own categories"), "and still no sentence")
end)

-- Owner, 2026-09-21: the rename and the Delete belong to the dropdown directly above them -- they
-- act on what it is showing -- so nothing is drawn between the two, heading included.
test("general → spell categories: the rename and the Delete sit directly under the picker (owner 2026-09-21)", function()
    local NS, _, P = spells()
    local key = NS.Categories.CreateUserCategory("Affixes", "HELPFUL")
    NS.GeneralSpells.Select(key)
    local ws = P.rerender("General")
    local mine = manage(NS, ws, P)
    local dd = P.find(ws, "Dropdown", NS.L["Category"])
    local picker, acts = lineOf(ws, dd), lineOf(ws, mine.name)
    assertTrue(picker ~= nil and acts ~= nil, "both lines are drawn")
    assertTrue(acts > picker, "the rename comes after the picker")
    -- red under: a heading, a sentence or the answer line put back between the two. What is allowed
    -- between them is layout and the picker line's own cells; what is not is anything a player
    -- READS -- a Heading, or a Label, which is what both the old "This category" heading and the
    -- lock sentence were drawn as.
    for i = picker + 1, acts - 1 do
        assertFalse(ws[i].type == "Heading" or ws[i].type == "Label",
            "nothing is read between the picker and the rename: " .. tostring(ws[i].type))
    end
    assertTrue(lineOf(ws, mine.delete) >= acts, "with Delete beside it, as Restore is beside the picker")
    -- And everything else this tab draws about the category is BELOW them.
    assertTrue(lineOf(ws, mine.newName) > acts, "the create form follows")
    assertTrue(lineOf(ws, P.find(ws, "EditBox", NS.L["Add a spell"])) > acts, "then the spell list")
    -- The gap below is what makes it a block: "Make a new category" closes the picker and its two
    -- acts off, which is the job the heading over them used to be doing badly.
    local head
    for i, w in ipairs(ws) do
        if w.type == "Heading" and w.text == NS.L["Make a new category"] then head = head or i end
    end
    assertTrue(head ~= nil and head > lineOf(ws, mine.delete), "and the next heading is below them")
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
    -- red under: the enchant branch promising a spell list, a Restore and add/remove -- three
    -- things this entry does not have. It draws slot toggles, and says so in its own lead-in above
    -- the picker, which is the sentence that survived the owner's 2026-09-21 cull of the block.
    assertFalse(P.hasText(ws, "Its spell list is still yours"), "no promise of a list it has not got")
    assertFalse(P.hasText(ws, "one of Aura Master's own categories"), "and no lock sentence either")
    assertTrue(P.hasText(ws, "there is nothing to add or remove here"), "it says what it actually is")
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
    -- red under: the marker drawn in the panel's own text color, which the owner asked for muted
    -- gold (2026-09-21). The parentheses are inside the escape: the mark is one object.
    assertTrue(dd.list[key]:find(YOURS_COLOR .. "(yours)|r", 1, true) ~= nil, "in muted gold, brackets and all")
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
    local NS, m, P = spells()
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

    -- And the entry carries the same answer permanently, in its "?" mark (LibKa0s v1.51.0). It
    -- was an `(also in N)` suffix inline until 2026-09-22, and before that a `note` -- a full-width
    -- second line, which cost the entry its place in the two-column grid. The mark costs a fixed
    -- 18px and leaves every row the same shape.
    -- red under: the answer back on the row or on a line of its own.
    local ws = P.rerender("General")
    local lbl = entry(ws, claimed)
    assertTrue(lbl ~= nil and lbl.text:find("also in", 1, true) == nil,
        "the row itself carries no count: " .. tostring(lbl and lbl.text))
    assertFalse(P.hasText(ws, "Also in: " .. NS.L["Defensive cooldowns"]),
        "and nothing is drawn on a line of its own")
    assertTrue(entryHelp(ws, claimed):find("Also in: " .. NS.L["Defensive cooldowns"], 1, true) ~= nil,
        "the mark names the category")
    assertTrue(entryTooltip(m, lbl):find("Also in: " .. NS.L["Defensive cooldowns"], 1, true) ~= nil,
        "and so does the entry's own tooltip, which is unchanged")

    -- The control: an id nothing else claims is neither reported nor marked.
    local quiet = P.chat()
    P.find(ws, "EditBox", NS.L["Add a spell"]):__fire("OnEnterPressed", "424242")
    assertEqual(#quiet, 0, "an unclaimed id says nothing")
    local ws2 = P.rerender("General")
    local still = entry(ws2, claimed)
    assertTrue(still ~= nil, "the claimed entry is still drawn")
    assertTrue(entryHelp(ws2, claimed):find("Also in", 1, true) ~= nil,
        "and its mark still says so")
    local unclaimed = entry(ws2, 424242)
    assertTrue(unclaimed ~= nil, "the added id is drawn")
    assertEqual(entryHelp(ws2, 424242), "",
        "an id nothing claims gets a mark with nothing behind it, not no mark at all")
    local said2 = entryTooltip(m, unclaimed)
    assertTrue(said2:find("Also in:", 1, true) == nil,
        "and a category never reports itself as a claimant of its own entry: " .. said2)
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

test("general → spell categories: a claimed-by tooltip says when the other category is one the player made", function()
    local NS, m, P = spells()
    local key = NS.Categories.CreateUserCategory("Immunities", "HELPFUL")
    local mine = ownedName(NS, key)   -- the name as the panel writes it in a list, marker and all
    NS.SetByPath("categorySpells", { [key] = { [424242] = true, [424243] = true }, defensives = { [424242] = true } })
    NS.GeneralSpells.Select("defensives")

    -- red under: the line built from the compiler's bare label, which is `Cat.LabelOf` and carries
    -- no ownership marker -- so a sentence whose whole job is to say where else a spell already
    -- lives could name a category the player made without saying it was theirs.
    local ws = P.rerender("General")
    assertTrue(entryTooltip(m, entry(ws, 424242)):find("Also in: " .. mine, 1, true) ~= nil,
        "the entry's tooltip marks it")
    assertTrue(mine:find("(yours)", 1, true) ~= nil, "and the marker is what a user category wears")

    local chat = P.chat()
    P.find(ws, "EditBox", NS.L["Add a spell"]):__fire("OnEnterPressed", "424243")
    local said = table.concat(chat, "\n")
    assertTrue(said:find("also in: " .. mine, 1, true) ~= nil, "and so does the line at the add: " .. said)

    -- The control: one of Aura Master's own is named without a marker, here as everywhere else.
    NS.GeneralSpells.Select(key)
    assertTrue(entryTooltip(m, entry(P.rerender("General"), 424242))
        :find("Also in: " .. NS.L["Defensive cooldowns"], 1, true) ~= nil)
end)

-- The owner's rule for the glyph's color (2026-09-22): red for an entry that can never match,
-- yellow for one another category also claims, dimmed for an entry with nothing to say.
--
-- red under one gold tint for every mark that has lines, which is what LibKa0s v1.51.0 drew: the
-- severity is the whole of what tells a BROKEN entry apart from a merely noteworthy one without
-- opening a tooltip, and until it existed the two were the same pixel.
--
-- The generated table is replaced rather than read (tests/test_castaura.lua says why): a case
-- pinned to a real Blizzard build's cast->aura edge would go red on a re-generation that changed
-- nothing about this page.
test("general → spell categories: the mark's color says which of the two things it has to say", function()
    local NS, _, P = spells()
    NS.CastToAura = { REWRITE = { [424242] = 424243 }, CHOICES = {} }
    local key = NS.Categories.CreateUserCategory("Immunities", "HELPFUL")
    NS.SetByPath("categorySpells", {
        [key] = { [424242] = true, [424244] = true, [424245] = true },
        defensives = { [424244] = true },
    })
    NS.GeneralSpells.Select(key)
    local ws = P.rerender("General")
    local never = entryHelpTint(ws, 424242)   -- stored as a cast id: it can never match
    local also  = entryHelpTint(ws, 424244)   -- Defensive cooldowns claims it too
    local quiet = entryHelpTint(ws, 424245)   -- nothing to say, so a dimmed, hoverless mark
    assertTrue(never ~= nil and also ~= nil and quiet ~= nil, "all three entries drew a mark")
    assertTrue(never ~= also, "never-matches and also-in are not the same color")
    assertTrue(also ~= quiet, "and neither is the entry with nothing behind its mark")
    assertTrue(never ~= quiet, "nor is the broken one")
    -- The lines are unchanged by any of it: the color is a summary of them, never a replacement.
    assertTrue(entryHelp(ws, 424242):find("424243", 1, true) ~= nil, "the red mark names the aura to use")
    assertTrue(entryHelp(ws, 424244):find(NS.L["Defensive cooldowns"], 1, true) ~= nil, "the yellow one names the category")
    assertEqual(entryHelp(ws, 424245), "", "and the dim one says nothing at all")
end)

test("general → spell categories: two other claimants are both named, in the mark and the tooltip", function()
    local NS, m, P = spells()
    -- This used to assert the row read "(also in 2)" against a single claimant's "(also in 1)" --
    -- two whole locale strings and a branch, so that no `%d` string did the singular by accident.
    -- The count is gone with the suffix (LibKa0s v1.51.0): the mark NAMES them instead, so there
    -- is no number to get wrong and nothing for a plural rule to do.
    local both = { NS.L["Defensive cooldowns"], NS.L["Healing"] }
    local key = NS.Categories.CreateUserCategory("Immunities", "HELPFUL")
    NS.SetByPath("categorySpells", {
        [key] = { [424242] = true }, defensives = { [424242] = true }, healing = { [424242] = true },
    })
    NS.GeneralSpells.Select(key)
    local ws = P.rerender("General")
    local lbl = entry(ws, 424242)
    assertTrue(lbl ~= nil and lbl.text:find("also in", 1, true) == nil,
        "the row carries no count: " .. tostring(lbl and lbl.text))
    local help = entryHelp(ws, 424242)
    local said = entryTooltip(m, lbl)
    for _, name in ipairs(both) do
        assertTrue(help:find(name, 1, true) ~= nil, "the mark names " .. name .. ": " .. help)
        assertTrue(said:find(name, 1, true) ~= nil, "the tooltip names " .. name .. ": " .. said)
    end
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

test("general → spell categories: the add box still offers a spellbook spell that is on NO list of this addon", function()
    local NS, _, _, _, S, box = suggesting(function(_, m)
        -- In the SPELLBOOK and nowhere else: no category's starters or edits, no container's
        -- overrides, not a learned timed buff. Nothing candidates() can hand the dropdown.
        spell(m, 5621, "Zephyr Ember")
        m.setSpellBook({ 5621 })
    end)
    S.type(box, "zephyr emb")
    -- red under: LibKa0s v1.49.0 (OptionsWidgets minor 25), where SUGGEST_KIND was keyed by the kind
    -- TABLE IDENTITY, so this tab's own `base = "spell"` host kind -- the one that carries the
    -- claimed-by tooltip -- matched no row and reached no client source. The dropdown then showed
    -- candidates() alone, which does not know 5621, and this assert read "" instead of "5621".
    -- v1.49.1 keys that table through decorKind, so a based kind reads its base's row.
    assertEqual(S.ids(), "5621", "a spellbook spell on no list of ours is offered as you type")
    local row = S.row(5621)
    assertTrue(row ~= nil and row.labelText:find("Zephyr Ember", 1, true) ~= nil,
        "named as the client names it")
    row:__fire("OnClick")
    assertEqual(NS.db.profile.categorySpells.defensives[5621], true, "and the pick adds it")
end)

test("general → spell categories: a host kind with a base keeps its own entry tooltip AND its base's suggestions", function()
    local NS, m, P, _, S, box = suggesting(function(NS2, m2)
        spell(m2, 5622, "Zephyr Bloom")
        m2.setSpellBook({ 5622 })
        local key = NS2.Categories.CreateUserCategory("Immunities", "HELPFUL")
        NS2.SetByPath("categorySpells", { [key] = { [5622] = true } })
    end)
    -- The two halves of what v1.49.1 bought back, in one place: the client source AND the tooltip
    -- the host kind exists for. Either one alone is a regression the other would hide.
    S.type(box, "zephyr blo")
    assertEqual(S.ids(), "5622", "the spellbook still reaches the dropdown")
    S.row(5622):__fire("OnClick")
    local ws = P.rerender("General")
    local said = entryTooltip(m, entry(ws, 5622))
    -- red under: dropping the host kind to win the suggestions back, which would take the names of
    -- the claiming categories with it -- O.IdList builds an entry tooltip from the kind and nothing
    -- else.
    assertTrue(said:find("Also in: ", 1, true) ~= nil, "and the entry tooltip still names them: " .. said)
    assertTrue(said:find("(yours)", 1, true) ~= nil, "a category the player made still says so there")
    assertTrue(said:find(YOURS_COLOR .. "(yours)|r", 1, true) ~= nil, "in the same muted gold")
    assertEqual(NS.ValidateSchema(), 0)
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
