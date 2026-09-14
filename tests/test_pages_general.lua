-- tests/test_pages_general.lua — settings/General.lua and settings/GeneralContainers.lua, driven
-- through their widgets: what each Master control and Display row writes, what each one's effect is,
-- the two buttons the composer adds, the page's Defaults, and the Containers tab — its picker and New
-- container inside the tab body (the options-ui-§14 deviation, docs/ARCHITECTURE.md), the identity
-- rows and what each writes, and the acts on the selected container (Duplicate, Delete, Copy
-- settings from). The registry behavior under those acts is tests/test_containermanager.lua's; this
-- suite proves the page reaches it, on the right container. Every case builds a fresh environment,
-- because every case clicks something.

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

--- The same, on the Containers tab.
local function containers(opts)
    local NS, m, P, _, tab = general(opts)
    return NS, m, P, tab(NS.L["Containers"])
end

local function ids(NS)
    local out = {}
    for i, c in ipairs(NS.Database.GetContainers()) do out[i] = c.id end
    return table.concat(out, ",")
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

test("general: locking ends preview mode; unlocking leaves it alone", function()
    local NS, _, P, ws = general()
    NS.SetByPath("locked", false)
    NS.SetByPath("state.preview", true)
    assertTrue(NS.State.preview)
    P.row(ws, "locked"):__fire("OnValueChanged", true)
    -- red under: dropping the `locked` onChange in settings/General.lua
    assertTrue(NS.db.profile.locked)
    assertFalse(NS.State.preview, "locking ended the preview")
    NS.SetByPath("state.preview", true)
    P.row(ws, "locked"):__fire("OnValueChanged", false)
    -- red under: the onChange ending the preview whatever the new value is
    assertFalse(NS.db.profile.locked)
    assertTrue(NS.State.preview, "unlocking did not touch the preview")
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

test("general: the Display tab's preview checkbox turns preview mode on for the session only", function()
    local NS, _, P, _, tab = general()
    local ws = tab(NS.L["Display"])
    local cb = P.row(ws, "state.preview")
    assertTrue(cb ~= nil, "Show placeholder auras is on the Display tab")
    local msgs = P.messages()
    cb:__fire("OnValueChanged", true)
    -- red under: the row's set not reaching ContainerManager.SetPreview
    assertTrue(NS.State.preview)
    assertNil(NS.db.profile.state, "a session row never reaches the profile")
    assertEqual(msgs.config, 0, "and announces no setting change")
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
    assertEqual(#NS.Database.GetContainers(), 4, "nothing reset yet")
    assertEqual(NS.db.profile.scale, 2)
end)

test("general: the Reset-all tooltip names the equivalence with Profiles → Reset Profile", function()
    local _, m, P, ws = general()
    local lines = {}
    rawset(m.GameTooltip, "AddLine", function(_, s)
        lines[#lines + 1] = s
    end)
    P.find(ws, "Button", "Reset all settings"):__fire("OnEnter")
    -- red under: the Options descriptor without profilesPage (the tooltip never points at the Profiles page)
    assertEqual(lines[1], "Reset the current profile to its defaults — the same thing Profiles → Reset Profile does. "
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

test("general: Defaults restores the General rows of the profile and no container setting outside the Containers tab", function()
    local NS, m = general()
    NS.SetByPath("enabled", false)
    NS.SetByPath("visibility", "never")
    NS.SetByPath("hideBlizzardBuffs", true)
    NS.SetByPath("container.bars.width", 300, 1)
    m.__subcategories.General.defaultsOnClick()
    -- red under: the General Defaults reaching past its page (or not reaching its own rows)
    assertTrue(NS.db.profile.enabled)
    assertEqual(NS.db.profile.visibility, "always")
    assertFalse(NS.db.profile.hideBlizzardBuffs)
    assertEqual(NS.Database.FindContainer(1).bars.width, 300, "a Bars row is not a General row")
    assertEqual(#NS.Database.GetContainers(), 3, "and the registry is untouched")
end)

test("general: Defaults restores the selected container's Enabled, Unit, Aura type and Style, and never its name", function()
    local NS, m = general()
    local T0 = NS.CONTAINER_TEMPLATE
    NS.State.SetActiveContainer(2)
    NS.SetByPath("container.name", "Raid debuffs")
    NS.SetByPath("container.enabled", false)
    NS.SetByPath("container.unit", "focus")
    m.__subcategories.General.defaultsOnClick()
    local c2 = NS.Database.FindContainer(2)
    assertEqual(c2.enabled, T0.enabled)
    assertEqual(c2.unit, T0.unit)
    assertEqual(c2.auraType, T0.auraType)
    assertEqual(c2.style, T0.style)
    -- red under: NS.ApplyDefault not honoring the name row's noReset (the name goes back to the template's)
    assertEqual(c2.name, "Raid debuffs")
    assertEqual(NS.Database.FindContainer(3).unit, "target", "only the selected container")
end)

test("general: the page's Defaults tooltip says it takes the selected container's identity and keeps its name", function()
    local NS, m = general()
    -- red under: the tooltip still describing a page of profile rows only
    assertEqual(m.__subcategories.General.defaultsTooltip,
        NS.L["Restore every General setting on this profile to its addon default, and the selected container's Enabled, Unit, Aura type and Style. Its name is kept, and so are the spell categories' lists: each category has its own restore."])
end)

test("general: /am reset container.name says a name has no default and changes nothing", function()
    local NS, _, P = general()
    local lines = P.chat()
    local msgs = P.messages()
    NS.Slash:OnSlash("reset container.name")
    local said = false
    for _, l in ipairs(lines) do
        if l:find("A container's name has no default.", 1, true) then said = true end
    end
    -- red under: the Slash descriptor's applyDefault dropping ApplyDefault's refusal (a silent no-op)
    assertTrue(said, "the refusal is printed: " .. table.concat(lines, " | "))
    assertEqual(NS.Database.FindContainer(1).name, "Player buffs")
    assertEqual(msgs.config, 0, "nothing written, nothing announced")
end)

-- ── the Containers tab ────────────────────────────────────────────────────────────────────────

test("general: the tab strip reads Master controls, Display, Containers, Spell Categories, Dispel Colors, and no page is keyed containers", function()
    local NS, m, P = general()
    local keys = P.tabKeys("general")
    -- red under: the identity rows left on their own page, or the bespoke Containers tab added twice;
    -- and under collectTabs ignoring a bespoke tab's `before` (Spell Categories drawn after Dispel
    -- Colors, a schema group, because every schema group is collected first)
    assertEqual(table.concat(keys, ","), "Master controls,Display,Containers,Spell Categories,Dispel Colors")
    local seen = {}
    for _, k in ipairs(keys) do
        assertNil(seen[k], "tab " .. k .. " drawn twice")
        seen[k] = true
    end
    assertNil(m.__subcategories.Containers, "the Containers page no longer registers")
    assertEqual(#NS.SchemaForPage("containers"), 0, "and no row names it")
    for _, path in ipairs({ "container.name", "container.enabled", "container.unit", "container.auraType", "container.style" }) do
        local row = NS.FindSchemaRow(path)
        assertEqual(row.page, "general", path)
        assertEqual(row.group, NS.L["Containers"], path)
    end
end)

test("general: NS.OpenOptionsPage('containers') opens no page, where 'layout' still opens its own", function()
    -- Subcategory ids start at 101: the kit's main category answers GetID() == 1.
    local names, byId, opened = {}, {}, {}
    local NS = fresh({ before = function(mk)
        local register = mk.Settings.RegisterCanvasLayoutSubcategory
        local count = 0
        mk.Settings.RegisterCanvasLayoutSubcategory = function(parent, panel, name)
            local cat = register(parent, panel, name)
            count = count + 1
            names[count] = name
            local id = 100 + count
            byId[id] = name
            cat.GetID = function() return id end
            return cat
        end
        mk.Settings.OpenToCategory = function(id)
            local name = byId[id] or "main"
            opened[#opened + 1] = name
        end
    end })
    NS.OpenOptionsPage("layout")
    assertEqual(opened[1], "Layout")
    NS.OpenOptionsPage("containers")
    -- red under: the Containers page still registering (a category of its own, which its key opens)
    for _, name in ipairs(names) do
        assertTrue(name ~= "Containers", "no Containers category is registered")
    end
    -- red under: OpenOptionsPage opening nothing (or a stale page) for a key it no longer knows,
    -- instead of falling back to the addon's main category
    assertEqual(opened[2], "main", "an unknown key opens the main category")
end)

test("general → containers: the tab body opens with the Container picker and New container on one line", function()
    local NS, _, _, ws = containers()
    local picker, new
    for _, w in ipairs(ws) do
        if w.type == "Dropdown" and w.labelText == NS.L["Container"] then picker = w end
        if w.type == "Button" and w.text == NS.L["New container"] then new = w end
    end
    -- red under: the picker line not drawn, or drawn in a chrome block above the strip (D1)
    assertTrue(picker ~= nil and new ~= nil, "both drawn")
    assertTrue(inScroll(NS, picker) and inScroll(NS, new), "inside the tab body")
    local line
    for _, row in ipairs(NS.Helpers.EnsureScroll(NS.Helpers.__pageCtx.general).children) do
        for _, c in ipairs(row.children or {}) do
            if c == picker then line = row end
        end
    end
    assertTrue(line ~= nil and line.children[2] == new, "New sits beside the picker, on the first line")
    assertEqual(table.concat(picker.order, ","), "1,2,3")
    assertTrue(picker.list[2]:find("(Player debuffs, icons)", 1, true) ~= nil, "what it shows: " .. picker.list[2])
end)

test("general → containers: the picker retargets the tab and every page", function()
    local NS, _, P, ws = containers()
    P.find(ws, "Dropdown", NS.L["Container"]):__fire("OnValueChanged", 3)
    -- red under: the picker not writing the shared selection, or the tab not re-reading it
    local again = P.rerender("General")
    assertEqual(P.row(again, "container.name").text, "Target debuffs (mine)")
    assertEqual(P.row(again, "container.unit").value, "target")
    assertEqual(NS.GetSetting("container.unit"), "target", "every page resolves against it")
end)

test("general → containers: New container creates a container and selects it", function()
    local NS, _, P, ws = containers()
    P.find(ws, "Button", NS.L["New container"]):__fire("OnClick")
    -- red under: doNew not reaching ContainerManager.Create, or not selecting the new container
    assertEqual(#NS.Database.GetContainers(), 4)
    local _, id = NS.ActiveContainer()
    assertEqual(id, NS.db.profile.containerOrder[4])
end)

test("general → containers: Delete keeps the picker and New through both refreshes, and the picker lists what remains (C-3)", function()
    local NS, m, P = containers()
    local popups = P.popups()
    NS.Helpers.SelectContainer(2)
    local ws = P.rerender("General")
    m.__subcategories.General:Show()   -- on screen: both refreshes below re-render it at once
    local renders = 0
    local render = NS.Helpers.RenderTabbedPage
    NS.Helpers.RenderTabbedPage = function(ctx, key, ...)
        if key == "general" then renders = renders + 1 end
        return render(ctx, key, ...)
    end
    P.find(ws, "Button", NS.L["Delete"]):__fire("OnClick")
    local after = P.during(function()
        m.StaticPopupDialogs.AURAMASTER_DELETE_CONTAINER.OnAccept(popups[1], popups[1].data)
        m.__fireTimers()   -- CONTAINERS_CHANGED's coalesced next-frame refresh
    end)
    assertEqual(ids(NS), "1,3")
    assertEqual(renders, 2, "the popup's own refresh, then the registry change's")
    -- What the scroll holds now, after both renders: the kit's scroll drops its children without
    -- marking them released, so "live" here means "parented in the tab body".
    local function drawn(wtype, label)
        local out = {}
        for _, w in ipairs(P.all(after, wtype, label)) do
            if inScroll(NS, w) then
                out[#out + 1] = w
            end
        end
        return out
    end
    local pickers = drawn("Dropdown", NS.L["Container"])
    local news = drawn("Button", NS.L["New container"])
    -- red under: the picker line drawn only on a first render, or into a chrome ledger the second
    -- refresh releases (the reported loss: no picker and no New after a delete)
    assertEqual(#pickers, 1, "one picker in the tab body")
    assertEqual(#news, 1, "one New container in the tab body")
    assertEqual(table.concat(pickers[1].order, ","), "1,3", "the picker lists the remaining containers")
    -- red under: the second refresh drawing New on a line of its own, or dropping it from the
    -- picker's line (the pair must survive both renders together, as the first render drew it)
    local line
    for _, row in ipairs(NS.Helpers.EnsureScroll(NS.Helpers.__pageCtx.general).children) do
        for _, c in ipairs(row.children or {}) do
            if c == pickers[1] then line = row end
        end
    end
    assertTrue(line ~= nil and line.children[2] == news[1], "New still sits beside the picker")
end)

test("general → containers: with no containers the tab draws the picker, New container and one line instead of the rows", function()
    local NS, _, P = containers()
    for _, c in ipairs(NS.Database.GetContainers()) do NS.ContainerManager.Delete(c.id) end
    local ws = P.rerender("General")
    -- red under: collectTabs dropping every General tab when no container exists
    assertEqual(P.tabKeys("general")[1], "Master controls")
    assertTrue(P.find(ws, "Button", NS.L["New container"]) ~= nil, "New is still offered")
    assertTrue(P.find(ws, "Dropdown", NS.L["Container"]) ~= nil, "the picker is drawn, empty")
    assertNil(P.row(ws, "container.name"), "no row edits a container that does not exist")
    assertTrue(P.hasText(ws, NS.L["No containers yet. Click New container, or type /am new."]))
end)

test("general → containers: the Name box renames the selected container, trimmed, and no other", function()
    local NS, _, P = containers()
    NS.Helpers.SelectContainer(2)
    local ws = P.rerender("General")
    local box = P.row(ws, "container.name")
    assertEqual(box.type, "EditBox")
    assertEqual(box.text, "Player debuffs", "the box reads the selected container")
    box:__fire("OnEnterPressed", "  Raid debuffs  ")
    -- red under: the name row's normalize not trimming, or the write missing the selection
    assertEqual(NS.Database.FindContainer(2).name, "Raid debuffs")
    assertEqual(NS.Database.FindContainer(1).name, "Player buffs")
end)

test("general → containers: a blank name is refused and the container keeps its name", function()
    local NS, _, P, ws = containers()
    local msgs = P.messages()
    P.row(ws, "container.name"):__fire("OnEnterPressed", "   ")
    -- red under: dropping the name row's validate (a container nobody can /am select by name)
    assertEqual(NS.Database.FindContainer(1).name, "Player buffs")
    assertEqual(msgs.config, 0, "a refused write announces nothing")
end)

test("general → containers: a rename re-lists every picker and re-applies no container", function()
    local NS, _, P, ws = containers()
    local msgs = P.messages()
    local applies = 0
    local real = NS.ContainerManager.RequestApply
    NS.ContainerManager.RequestApply = function(...) applies = applies + 1; return real(...) end
    P.row(ws, "container.name"):__fire("OnEnterPressed", "Buffs")
    -- red under: the name row losing NotifyRenamed (the banners keep the old name) or its
    -- `effect = "none"` (Container:Apply never reads the name)
    assertEqual(msgs.containers, 1, "one CONTAINERS_CHANGED")
    assertEqual(applies, 0)
end)

test("general → containers: the Unit dropdown offers the four units in order and writes the selected container", function()
    local NS, _, P, ws = containers()
    local dd = P.row(ws, "container.unit")
    assertEqual(table.concat(dd.order, ","), table.concat(NS.Constants.UNITS, ","))
    assertEqual(dd.list.focus, NS.L["Focus"], "each unit carries its label")
    dd:__fire("OnValueChanged", "focus")
    -- red under: the row writing an absolute path, or the active container not being the target
    assertEqual(NS.Database.FindContainer(1).unit, "focus")
    assertEqual(NS.Database.FindContainer(3).unit, "target", "another container is untouched")
end)

test("general → containers: changing the aura type redraws an open Filters page for the new type, on the next frame", function()
    local NS, m, P, ws = containers()
    P.show("Filters")
    m.__subcategories.Filters:Show()   -- on screen, so only a STRUCTURAL refresh re-renders it
    -- Overrides is offered to buffs and debuffs only (a weapon-enchant container has no spell
    -- whitelist/blacklist), so it disappearing is the redraw signal: the Categories tab itself stays
    -- (schema v3: hidePermanentEnchants applies to ENCHANT too), so it cannot serve as one any more.
    local function hasOverridesTab()
        for _, k in ipairs(P.tabKeys("filters")) do if k == "overrides" then return true end end
        return false
    end
    assertTrue(hasOverridesTab(), "a buff container has the Overrides tab")
    P.row(ws, "container.auraType"):__fire("OnValueChanged", "ENCHANT")
    assertEqual(NS.Database.FindContainer(1).auraType, "ENCHANT")
    assertTrue(hasOverridesTab(), "never inside the dropdown's own callback")
    m.__fireTimers()
    -- red under: the aura type row losing its structural onChange (the page keeps offering the
    -- Overrides tab on a weapon-enchant container)
    assertFalse(hasOverridesTab(), "redrawn for a weapon-enchant container")
end)

test("general → containers: the Style dropdown offers bars and icons and writes the selected container", function()
    local NS, _, P, ws = containers()
    local dd = P.row(ws, "container.style")
    assertEqual(table.concat(dd.order, ","), "bars,icons")
    dd:__fire("OnValueChanged", "icons")
    -- red under: the style row writing the wrong path
    assertEqual(NS.Database.FindContainer(1).style, "icons")
end)

test("general → containers: New and Duplicate in combat refuse in gray and create nothing", function()
    local NS, m, P, ws = containers()
    local lines = P.chat()
    m.__lockdown = true
    P.find(ws, "Button", NS.L["Duplicate"]):__fire("OnClick")
    P.find(ws, "Button", NS.L["New container"]):__fire("OnClick")
    -- red under: sayError printing a refusal plain, or a page act bypassing the combat refusal
    assertEqual(#NS.Database.GetContainers(), 3)
    assertEqual(#lines, 2, "one refusal each")
    for _, l in ipairs(lines) do
        assertTrue(l:find("|cff808080cannot create a container during combat", 1, true) ~= nil, l)
    end
end)

test("general → containers: Duplicate copies the selected container and selects the copy", function()
    local NS, _, P = containers()
    NS.SetByPath("container.icons.width", 44, 2)
    NS.Helpers.SelectContainer(2)
    local ws = P.rerender("General")
    P.find(ws, "Button", NS.L["Duplicate"]):__fire("OnClick")
    local _, id = NS.ActiveContainer()
    -- red under: doDuplicate copying something other than the selection, or not selecting the copy
    assertEqual(#NS.Database.GetContainers(), 4)
    assertTrue(id ~= 2 and id == NS.db.profile.containerOrder[4], "the copy is selected")
    local copy = NS.Database.FindContainer(id)
    assertEqual(copy.name, "Player debuffs (copy)")
    assertEqual(copy.icons.width, 44, "every setting came with it")
end)

test("general → containers: Delete asks first, naming the container, and deletes it only on Yes", function()
    local NS, m, P = containers()
    local popups = P.popups()
    NS.Helpers.SelectContainer(2)
    local ws = P.rerender("General")
    P.find(ws, "Button", NS.L["Delete"]):__fire("OnClick")
    -- red under: doDelete deleting without the popup, or the popup not carrying the id
    assertEqual(#popups, 1)
    assertEqual(popups[1].which, "AURAMASTER_DELETE_CONTAINER")
    assertEqual(popups[1].text, "Player debuffs", "the popup names what it will delete")
    assertEqual(popups[1].data, 2)
    assertEqual(#NS.Database.GetContainers(), 3, "nothing deleted before the answer")
    m.StaticPopupDialogs.AURAMASTER_DELETE_CONTAINER.OnAccept(popups[1], popups[1].data)
    assertEqual(ids(NS), "1,3")
    local _, active = NS.ActiveContainer()
    assertEqual(active, 1, "the selection falls back to the first container")
end)

test("general → containers: the copy block offers every other container and copies only the chosen section", function()
    local NS, _, P, ws = containers()
    NS.SetByPath("container.bars.width", 123, 2)
    NS.SetByPath("container.layout.spacing", 9, 2)
    local source = P.find(ws, "Dropdown", NS.L["Source container"])
    local what = P.find(ws, "Dropdown", NS.L["What to copy"])
    -- red under: the source list including the selected container (a copy onto itself)
    assertEqual(table.concat(source.order, ","), "2,3")
    assertEqual(table.concat(what.order, ","), "all,filter,layout,behavior,bars,icons")
    source:__fire("OnValueChanged", 2)
    what:__fire("OnValueChanged", "bars")
    P.find(ws, "Button", NS.L["Copy onto this container"]):__fire("OnClick")
    local c1 = NS.Database.FindContainer(1)
    assertEqual(c1.bars.width, 123, "the chosen section came across")
    assertEqual(c1.layout.spacing, NS.CONTAINER_TEMPLATE.layout.spacing, "and nothing else did")
end)

test("general → containers: copying Everything takes what the source is, never its name or position", function()
    local NS, _, P, ws = containers()
    P.find(ws, "Dropdown", NS.L["Source container"]):__fire("OnValueChanged", 3)
    P.find(ws, "Button", NS.L["Copy onto this container"]):__fire("OnClick")
    local c1 = NS.Database.FindContainer(1)
    -- red under: passing "all" through to CopyFrom rather than nil, which copies nothing at all
    assertEqual(c1.unit, "target")
    assertEqual(c1.auraType, "HARMFUL")
    assertEqual(c1.style, "icons")
    assertEqual(c1.filter.castBy, "mine")
    assertEqual(c1.name, "Player buffs")
    assertEqual(c1.position.x, -240, "the position stays")
end)

test("general → containers: with one container the tab offers Duplicate and Delete but no copy block", function()
    local NS, _, P = containers()
    NS.ContainerManager.Delete(2)
    NS.ContainerManager.Delete(3)
    local ws = P.rerender("General")
    assertTrue(P.find(ws, "Button", NS.L["Duplicate"]) ~= nil)
    assertTrue(P.find(ws, "Button", NS.L["Delete"]) ~= nil)
    -- red under: afterContainers drawing the copy block with nothing to copy from
    assertNil(P.find(ws, "Dropdown", NS.L["Source container"]))
    assertNil(P.find(ws, "Button", NS.L["Copy onto this container"]))
end)

-- ── the Spell Categories tab (G-2) ────────────────────────────────────────────────────────────

--- The General page on its Spell Categories tab.
local function spells(opts)
    local NS, m, P, _, tab = general(opts)
    return NS, m, P, tab(NS.L["Spell Categories"])
end

--- The line an IdList drew for spell `id`: its label, and the widget beside it (the starter's
--- checkbox, or an added spell's Remove).
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

test("general → spell categories: a dropdown of the nine spell categories, Healing among them, opening on the first", function()
    local NS, _, _, ws = spells()
    local dd
    for _, w in ipairs(ws) do
        if w.type == "Dropdown" and w.labelText == NS.L["Category"] then dd = w end
    end
    assertTrue(dd ~= nil, "the category dropdown is drawn")
    assertTrue(inScroll(NS, dd), "in the tab body")
    -- red under: the dropdown offering a flag or token category (only spell categories have lists)
    assertEqual(#dd.order, 9)
    for _, k in ipairs(dd.order) do
        assertTrue(NS.Categories.IsSpellCategory(k), "a spell category: " .. k)
    end
    assertEqual(dd.list.healing, NS.L["Healing"], "the merged Healing category is offered")
    assertEqual(dd.order[1], "defensives")
    assertEqual(dd.value, "defensives")
end)

test("general → spell categories: every starter is a toggle entry, ticked; nothing is removable yet", function()
    local NS, _, P, ws = spells()
    local want = starterIds(NS, "defensives")
    for _, id in ipairs(want) do
        local _, act = entry(ws, id)
        -- red under: the starters drawn as removable entries (Remove would forget a shipped spell
        -- rather than switch it off)
        assertTrue(act ~= nil and act.type == "CheckBox", "a checkbox beside starter " .. id)
        assertTrue(act.value == true, "ticked: " .. id)
    end
    assertEqual(#P.all(ws, "CheckBox"), #want, "one checkbox per starter")
    assertEqual(#P.all(ws, "Button", NS.L["Remove"]), 0)
    assertTrue(P.find(ws, "EditBox", NS.L["Add a spell"]) ~= nil, "the add line is drawn")
end)

test("general → spell categories: adding by id writes categorySpells whole through the seam, and Remove takes it off", function()
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
    local lbl, act = entry(ws, 424242)
    assertTrue(lbl ~= nil, "the added spell is listed")
    assertEqual(lbl.text, "Unknown spell 424242", "by id where the client cannot name it")
    assertTrue(act ~= nil and act.type == "Button" and act.text == NS.L["Remove"], "with Remove")
    act:__fire("OnClick")
    -- red under: onRemove leaving the id in the set
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

test("general → spell categories: unticking a starter stores false; ticking it or adding it again drops the edit", function()
    local NS, _, P, ws = spells()
    local id = starterIds(NS, "defensives")[1]
    local _, cb = entry(ws, id)
    cb:__fire("OnValueChanged", false)
    -- red under: a starter's untick storing nil (the starter list would put it straight back)
    assertEqual(NS.db.profile.categorySpells.defensives[id], false)
    ws = P.rerender("General")
    _, cb = entry(ws, id)
    assertFalse(cb.value, "drawn unticked")
    cb:__fire("OnValueChanged", true)
    assertNil(NS.db.profile.categorySpells.defensives, "ticking it drops the edit")
    NS.SetByPath("categorySpells", { defensives = { [id] = false } })
    ws = P.rerender("General")
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

test("general → spell categories: Restore this category's starter list clears that category's edits and no other's", function()
    local NS, _, P = spells()
    NS.SetByPath("categorySpells", { defensives = { [118038] = false, [424242] = true }, raidCDs = { [99] = true } })
    local ws = P.rerender("General")
    P.find(ws, "Button", NS.L["Restore this category's starter list"]):__fire("OnClick")
    local edits = NS.db.profile.categorySpells
    -- red under: the restore writing an empty set for every category
    assertNil(edits.defensives)
    assertEqual(edits.raidCDs[99], true)
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

test("general → dispel colors: six profile-wide swatches with no class-color companion, under a line saying they drive bars only", function()
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
    assertEqual(#P.all(ws, "ColorPicker"), 6)
    -- red under: a class-color companion beside a palette swatch (options-ui-§17's exemption)
    assertEqual(#P.all(ws, "CheckBox"), 0)
    -- red under: the tab still promising an icon's dispel border the tint (owner 2026-09-13: icons
    -- keep Blizzard's own dispel colors, so the palette drives bars only)
    assertTrue(P.hasText(ws, NS.L["One color per dispel type, shared by every container, for bars colored by dispel type. An icon's dispel border keeps Blizzard's own colors."]))
    for _, name in ipairs(NS.Constants.DISPEL_TYPES) do
        local desc = NS.FindSchemaRow("dispelColors." .. name).desc
        -- red under: a row desc still naming the tint on an icon's dispel border
        assertEqual(desc, NS.L["This dispel type's color for a bar's fill when Color by is set to dispel type. An icon's dispel border keeps Blizzard's own colors."], name)
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
