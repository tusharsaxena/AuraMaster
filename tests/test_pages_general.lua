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
        NS.L["Restore every General setting on this profile to its addon default, and the selected container's Enabled, Unit, Aura type and Style. Its name is kept."])
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

test("general: the tab strip reads Master controls, Display, Containers, and no page is keyed containers", function()
    local NS, m, P = general()
    local keys = P.tabKeys("general")
    -- red under: the identity rows left on their own page, or the bespoke Containers tab added twice
    assertEqual(table.concat({ keys[1], keys[2], keys[3] }, ","), "Master controls,Display,Containers")
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
    local names, opened = {}, {}
    local NS = fresh({ before = function(mk)
        local register = mk.Settings.RegisterCanvasLayoutSubcategory
        local count = 0
        mk.Settings.RegisterCanvasLayoutSubcategory = function(parent, panel, name)
            local cat = register(parent, panel, name)
            count = count + 1
            names[count] = name
            local id = count
            cat.GetID = function() return id end
            return cat
        end
        mk.Settings.OpenToCategory = function(id)
            local name = names[id] or "main"
            opened[#opened + 1] = name
        end
    end })
    NS.OpenOptionsPage("layout")
    assertEqual(opened[1], "Layout")
    NS.OpenOptionsPage("containers")
    -- red under: the Containers page still registering (its key opens its own category)
    assertTrue(opened[2] ~= "Containers", "opened " .. tostring(opened[2]))
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
    local kids = NS.Helpers.__pageCtx.general.__chromeKids or {}
    assertEqual(#kids, 0, "and nothing sits in the band")
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
    local function hasSpellTab()
        for _, k in ipairs(P.tabKeys("filters")) do if k == "spellLists" then return true end end
        return false
    end
    assertTrue(hasSpellTab(), "a buff container has the spell-list tab")
    P.row(ws, "container.auraType"):__fire("OnValueChanged", "HARMFUL")
    assertEqual(NS.Database.FindContainer(1).auraType, "HARMFUL")
    assertTrue(hasSpellTab(), "never inside the dropdown's own callback")
    m.__fireTimers()
    -- red under: the aura type row losing its structural onChange (the page keeps offering the
    -- buff categories and the spell lists on a debuff container)
    assertFalse(hasSpellTab(), "redrawn for a debuff container")
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
