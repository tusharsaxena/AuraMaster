-- tests/test_pages_general.lua — settings/General.lua, GeneralSpells.lua and GeneralDispel.lua, driven
-- through their widgets: what each Master control and Display row writes, what each one's effect is,
-- the two buttons the composer adds, the page's Defaults, the Spell Categories ID list and its
-- restore, and the Dispel Colors rows. The top-level Containers page — its picker and New container
-- in the band above the strip (options-ui-§14), its identity rows and the acts on the selected
-- container (Duplicate, Delete, Copy settings from) — moved out to its own page (N-1, batch 7) and is
-- tests/test_pages_containers.lua's now. The Spell Categories tab's editing flows (the 'Your
-- categories' block, the overlap guardrail and the add line's suggestions) are
-- tests/test_pages_general_categories.lua's (issue #19), and the page readers both suites use live in
-- tests/general_page_helpers.lua. Every case builds a fresh environment, because every case clicks
-- something.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local H = dofile("tests/general_page_helpers.lua")
local general, inScroll, spyApply, spells, TYPE_COLOR, rendered, marked, drawnEntries, entry,
    listedIds, starterIds, spyPaths =
    H.general, H.inScroll, H.spyApply, H.spells, H.TYPE_COLOR, H.rendered, H.marked,
    H.drawnEntries, H.entry, H.listedIds, H.starterIds, H.spyPaths

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


test("general → spell categories: a dropdown of the thirteen spell categories plus Weapon enchants, opening on the first", function()
    local NS, _, _, ws = spells()
    local dd
    for _, w in ipairs(ws) do
        if w.type == "Dropdown" and w.labelText == NS.L["Category"] then dd = w end
    end
    assertTrue(dd ~= nil, "the category dropdown is drawn")
    assertTrue(inScroll(NS, dd), "in the tab body")
    -- red under: the dropdown offering a flag or token category (only spell categories and the
    -- enchant row belong here). 14 = eleven buff spell lists + weaponEnchants + issue #11's hardCC and
    -- softCC, which are `spells`-kind on Cat.HARMFUL: this tab is keyed on the KIND, never on the
    -- aura type, or a shipped debuff list would have no editor and its `See spells` link would go
    -- nowhere.
    assertEqual(#dd.order, 14)
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
    assertEqual(dd.order[12], "weaponEnchants", "the buff rows first, in defaults/Categories.lua's order")
    assertEqual(dd.order[13], "hardCC", "then Cat.HARMFUL's, in its own order")
    assertEqual(dd.order[14], "softCC")
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
