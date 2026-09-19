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

--- The line an IdList drew for spell `id`: its label, and the X at the line's left
--- (`removeStyle = "icon"`, B2).
local function entry(ws, id)
    for _, w in ipairs(ws) do
        local lbl = w.children and w.children[2]
        if lbl and lbl.type == "InteractiveLabel" then
            local t = lbl.text or ""
            if t:find("(" .. id .. ")|r", 1, true) or t == "Unknown spell " .. id then
                return lbl, w.children[1]
            end
        end
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

test("general → spell categories: a dropdown of the nine spell categories plus Weapon enchants, opening on the first", function()
    local NS, _, _, ws = spells()
    local dd
    for _, w in ipairs(ws) do
        if w.type == "Dropdown" and w.labelText == NS.L["Category"] then dd = w end
    end
    assertTrue(dd ~= nil, "the category dropdown is drawn")
    assertTrue(inScroll(NS, dd), "in the tab body")
    -- red under: the dropdown offering a flag or token category (only spell categories and the
    -- enchant row belong here)
    assertEqual(#dd.order, 10)
    for _, k in ipairs(dd.order) do
        assertTrue(NS.Categories.IsSpellCategory(k) or k == "weaponEnchants", "a spell category or the enchant row: " .. k)
    end
    assertEqual(dd.list.healing, NS.L["Healing"], "the merged Healing category is offered")
    assertEqual(dd.list.weaponEnchants, NS.L["Weapon enchants"], "Weapon enchants is offered too")
    assertEqual(dd.order[1], "defensives")
    assertEqual(dd.order[10], "weaponEnchants", "last, defaults/Categories.lua's order")
    assertEqual(dd.value, "defensives")
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
    assertTrue(P.hasText(ws, NS.L["One color per dispel type, shared by every container, for bars colored by dispel type and for a text line's dispel type word, backdrop or edge (Text -> Font). Buffs and many debuffs have no dispel type, class debuffs such as Judgment or Consecration included: those keep a bar's own color and show no type word, backdrop or edge. An icon's dispel border keeps Blizzard's own colors."]))
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
