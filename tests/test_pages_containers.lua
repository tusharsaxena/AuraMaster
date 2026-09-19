-- tests/test_pages_containers.lua — settings/Containers.lua, driven through its widgets: the
-- top-level Containers page (N-1, batch 7) — its own Blizzard category, its picker and New container
-- in the chrome block above the strip (feedback #2, options-ui-§14), its one tab, General, with the
-- identity rows and what each writes, and the acts on the selected container (Duplicate, Delete, Copy
-- settings from). This page used to be General's third tab; tests/test_pages_general.lua covers what
-- is left of General after the split. The registry behavior under Duplicate/Delete/Copy is
-- tests/test_containermanager.lua's; this suite proves the page reaches it, on the right container.
-- Every case builds a fresh environment, because every case clicks something.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local pages = dofile("tests/page_helpers.lua")

--- A fresh environment with the Containers page drawn (its only tab, so no click is needed).
local function containers(opts)
    local NS, m = fresh(opts)
    local P = pages(NS, m)
    local ws = P.show("Containers")
    return NS, m, P, ws
end

local function ids(NS)
    local out = {}
    for i, c in ipairs(NS.Database.GetContainers()) do out[i] = c.id end
    return table.concat(out, ",")
end

--- Whether widget `w` hangs, at any depth, off the Containers page's scroll: drawn in the tab body,
--- and not in a chrome block above the strip.
local function inScroll(NS, w)
    local function walk(node)
        for _, c in ipairs(node.children or {}) do
            if c == w or walk(c) then return true end
        end
        return false
    end
    return walk(NS.Helpers.EnsureScroll(NS.Helpers.__pageCtx.containers))
end

test("containers: registers its own top-level Blizzard category, with one tab, General (N-1, options-ui-§14)", function()
    local NS, m, P = containers()
    local keys = P.tabKeys("containers")
    -- red under: the page drawing more than its one tab, or the tab not named General (options-ui-§14
    -- names the tab holding a page's acts, under a band carrying its picker)
    assertEqual(table.concat(keys, ","), NS.L["General"])
    assertTrue(m.__subcategories.Containers ~= nil, "the page registers its own category")
    for _, path in ipairs({ "container.name", "container.enabled", "container.unit", "container.auraType", "container.style" }) do
        local row = NS.FindSchemaRow(path)
        assertEqual(row.page, "containers", path)
        assertEqual(row.group, NS.L["General"], path)
    end
end)

-- BATCH 8 (owner, from a screenshot): Unit, Aura type and Style used to run on from Name and Enabled
-- with nothing between them, one undifferentiated block of five rows. They are a different question
-- — what the container watches and how it is drawn, against which container this is — so they now
-- carry a subgroup of their own, the same options-ui-§7 mechanism Bars, Icons and Layout use. Name
-- and Enabled deliberately keep no heading: a heading above the first row of a tab reads as a
-- repeat of the tab.
test("containers: Unit, Aura type and Style sit under their own subsection; Name and Enabled do not", function()
    local NS, _, _, ws = containers()
    local S = NS.L["What it shows, and how"]
    for _, path in ipairs({ "container.unit", "container.auraType", "container.style" }) do
        -- red under: a row losing the subgroup, which would drop it back into the identity block
        assertEqual(NS.FindSchemaRow(path).subgroup, S, path)
    end
    for _, path in ipairs({ "container.name", "container.enabled" }) do
        assertNil(NS.FindSchemaRow(path).subgroup, path)
    end
    local heads = {}
    for _, w in ipairs(ws) do
        if w.type == "Heading" then
            heads[#heads + 1] = w.text
        end
    end
    -- red under: the subgroup declared but never drawn (a page rendering with the headings off)
    assertEqual(heads[1], S, "the subsection heading is drawn, above Copy settings from")
end)

test("containers: the subsection heading is drawn between Enabled and Unit, not anywhere else", function()
    local NS, _, _, ws = containers()
    local at, enabled, unit
    for i, w in ipairs(ws) do
        if w.type == "Heading" and w.text == NS.L["What it shows, and how"] then at = i end
        if w.labelText == NS.L["Enabled"] then enabled = i end
        if w.labelText == NS.L["Unit"] then unit = i end
    end
    assertTrue(at ~= nil and enabled ~= nil and unit ~= nil, "all three drew")
    -- red under: the subgroup landing on the wrong rows, or the heading emitted after them
    assertTrue(enabled < at, "Enabled is above the heading")
    assertTrue(at < unit, "Unit is below it")
end)

test("containers: NS.OpenOptionsPage('containers') opens its own category, not the main one (N-3)", function()
    -- Subcategory ids start at 101: the kit's main category answers GetID() == 1. Registering its
    -- own category (the test above) used to not be enough for OpenOptionsPage to find it: that seam
    -- only recorded a category for pages built through NS.RegisterContainerPage
    -- (settings/OptionsSetup.lua), while Containers, like General, builds through the plain
    -- NS.RegisterOptionsPage. N-3 closed that gap: NS.RegisterOptionsPage's own wrapper now records
    -- whatever category its builder returns, so every registered page (not only container pages)
    -- is reachable by key.
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
    -- Layout is a sub-page of Containers (N-2): its tree label carries the mark (D6), though the
    -- key that opened it is still the plain "layout".
    assertEqual(opened[1], NS.SubPageLabel("Layout"))
    local sawContainers = false
    for _, name in ipairs(names) do
        if name == NS.L["Containers"] then sawContainers = true end
    end
    assertTrue(sawContainers, "the Containers page's own category was registered")
    NS.OpenOptionsPage("containers")
    -- red under: OpenOptionsPage still falling back to the main category for "containers" instead
    -- of the category that page registered for itself
    assertEqual(opened[2], NS.L["Containers"], "N-3: Containers opens its own category, not the main panel")
end)

--- The chrome block's two controls, as the last render drew them: the picker and New container.
local function headerWidgets(NS)
    local ctx = NS.Helpers.__pageCtx.containers
    local picker, new
    for _, w in ipairs(ctx.__chromeWidgets or {}) do
        if w.type == "Dropdown" and w.labelText == NS.L["Container"] then picker = w end
        if w.type == "Button" and w.text == NS.L["New container"] then new = w end
    end
    return picker, new
end

test("containers: the picker and New container sit in the band above the strip, drawn before it (feedback #2)", function()
    local NS, _, P = containers()
    local H = NS.Helpers
    local order, real, headerFrame = {}, {}, nil
    for _, name in ipairs({ "PageHeader", "TabStrip" }) do
        real[name] = H[name]
        H[name] = function(...)
            local n = #order
            order[n + 1] = name
            local ret = real[name](...)
            if name == "PageHeader" then headerFrame = ret end
            return ret
        end
    end
    -- A widget's frame is a fresh table per Create (tests/_kit's own spy convention: rawset a
    -- method to record, rawset nil to restore), so shadowing SetParent right after Create catches
    -- placeInHeader's call on it, made moments later inside the same build.
    local AceGUI = NS.AceGUI
    local realCreate = AceGUI.Create
    local parents = {}
    AceGUI.Create = function(self, wtype)
        local w = realCreate(self, wtype)
        if w.frame then
            w.frame.SetParent = function(f, p) parents[w] = p; return f end
        end
        return w
    end
    P.rerender("Containers")
    H.PageHeader, H.TabStrip = real.PageHeader, real.TabStrip
    AceGUI.Create = realCreate
    -- red under: the page drawing no chrome block, or drawing it after the strip (its band unreserved)
    assertEqual(table.concat(order, ","), "PageHeader,TabStrip", "the band, then the tabs")
    local picker, new = headerWidgets(NS)
    -- red under: the picker and New still drawn in the tab body (the retired options-ui-§14 deviation)
    assertTrue(picker ~= nil and new ~= nil, "both drawn in the band")
    assertFalse(inScroll(NS, picker) or inScroll(NS, new), "neither in the tab body")
    -- red under: the pair drawn but never actually anchored into the band (placeInHeader not run,
    -- or run against some other frame) -- "neither in the tab body" alone is trivially true of a
    -- widget parented nowhere at all
    assertTrue(headerFrame ~= nil and parents[picker] == headerFrame and parents[new] == headerFrame,
        "both parented into the header frame PageHeader returned")
    assertTrue(H.__pageCtx.containers.__bannerWidget == picker, "the picker is the page's banner widget")
    assertEqual(table.concat(picker.order, ","), "1,4,2,3", "by name (B2-2)")
    assertTrue(picker.list[2]:find("(Player debuffs, icons)", 1, true) ~= nil, "what it shows: " .. picker.list[2])
end)

test("containers: the picker retargets the tab and every page", function()
    local NS, _, P, ws = containers()
    P.find(ws, "Dropdown", NS.L["Container"]):__fire("OnValueChanged", 3)
    -- red under: the picker not writing the shared selection, or the tab not re-reading it
    local again = P.rerender("Containers")
    assertEqual(P.row(again, "container.name").text, "Target debuffs (mine)")
    assertEqual(P.row(again, "container.unit").value, "target")
    assertEqual(NS.GetSetting("container.unit"), "target", "every page resolves against it")
end)

test("containers: New container creates a container and selects it", function()
    local NS, _, P, ws = containers()
    P.find(ws, "Button", NS.L["New container"]):__fire("OnClick")
    -- red under: doNew not reaching ContainerManager.Create, or not selecting the new container
    assertEqual(#NS.Database.GetContainers(), #NS.STARTER_CONTAINERS + 1)
    local _, id = NS.ActiveContainer()
    assertEqual(id, NS.db.profile.containerOrder[#NS.STARTER_CONTAINERS + 1])
end)

test("containers: New container takes the Fill its style suits (B5)", function()
    local NS, _, P, ws = containers()
    P.find(ws, "Button", NS.L["New container"]):__fire("OnClick")
    local c = NS.ActiveContainer()
    -- red under: newContainerData leaving the Fill out of the style rule
    assertEqual(c.layout.axis, NS.Constants.STYLE_FILL_AXIS[c.style])
end)

test("containers: a created container with its own Fill keeps it; Create with only a style takes the style's", function()
    local NS = containers()
    local CM = NS.ContainerManager
    local id = CM.Create({ style = "icons", layout = { axis = "vertical" } })
    -- red under: the style rule overwriting a Fill the caller gave
    assertEqual(NS.Database.FindContainer(id).layout.axis, "vertical")
    id = CM.Create({ style = "icons" })
    assertEqual(NS.Database.FindContainer(id).layout.axis, "horizontal")
end)

test("containers: Delete keeps the band's picker and New through both refreshes, and the picker lists what remains (C-3)", function()
    local NS, m, P = containers()
    local popups = P.popups()
    NS.Helpers.SelectContainer(2)
    local ws = P.rerender("Containers")
    NS.Helpers.__pageCtx.containers.panel:Show()   -- on screen: both refreshes below re-render it at once
    local renders = 0
    local render = NS.Helpers.RenderTabbedPage
    NS.Helpers.RenderTabbedPage = function(ctx, key, ...)
        if key == "containers" then renders = renders + 1 end
        return render(ctx, key, ...)
    end
    P.find(ws, "Button", NS.L["Delete"]):__fire("OnClick")
    local after = P.during(function()
        m.StaticPopupDialogs.AURAMASTER_DELETE_CONTAINER.OnAccept(popups[1], popups[1].data)
        m.__fireTimers()   -- CONTAINERS_CHANGED's coalesced next-frame refresh
    end)
    assertEqual(ids(NS), "1,3,4")
    assertEqual(renders, 2, "the popup's own refresh, then the registry change's")
    -- red under: the block drawn only on a first render, or its widgets released by the render that
    -- drew them (the reported loss: no picker and no New after a delete)
    local picker, new = headerWidgets(NS)
    assertTrue(picker ~= nil and not picker.__released, "the band's picker is live after both renders")
    assertTrue(new ~= nil and not new.__released, "and so is New container")
    assertEqual(table.concat(picker.order, ","), "1,4,3", "the picker lists the remaining containers, by name")
    local live = 0
    for _, w in ipairs(P.all(after, "Dropdown", NS.L["Container"])) do
        if not w.__released then live = live + 1 end
    end
    -- red under: the stale block's widgets never handed back to AceGUI (one more per render)
    assertEqual(live, 1, "the first render's picker was released; one picker is left")
end)

test("containers: with no containers the page draws the band's picker and New, and one line instead of the rows", function()
    local NS, _, P = containers()
    for _, c in ipairs(NS.Database.GetContainers()) do NS.ContainerManager.Delete(c.id) end
    local ws = P.rerender("Containers")
    -- red under: collectTabs dropping the page's one tab when no container exists
    assertEqual(P.tabKeys("containers")[1], NS.L["General"])
    local picker, new = headerWidgets(NS)
    assertTrue(new ~= nil, "New is still offered")
    assertTrue(picker ~= nil and picker.order[1] == nil, "the picker is drawn, empty")
    assertNil(P.row(ws, "container.name"), "no row edits a container that does not exist")
    assertTrue(P.hasText(ws, NS.L["No containers yet. Click New container, or type /am new."]))
end)

test("containers: the Name box renames the selected container, trimmed, and no other", function()
    local NS, _, P = containers()
    NS.Helpers.SelectContainer(2)
    local ws = P.rerender("Containers")
    local box = P.row(ws, "container.name")
    assertEqual(box.type, "EditBox")
    assertEqual(box.text, "Player debuffs", "the box reads the selected container")
    box:__fire("OnEnterPressed", "  Raid debuffs  ")
    -- red under: the name row's normalize not trimming, or the write missing the selection
    assertEqual(NS.Database.FindContainer(2).name, "Raid debuffs")
    assertEqual(NS.Database.FindContainer(1).name, "Player buffs")
end)

test("containers: /am reset container.name says a name has no default and changes nothing", function()
    local NS, _, P = containers()
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

test("containers: a blank name is refused and the container keeps its name", function()
    local NS, _, P, ws = containers()
    local msgs = P.messages()
    P.row(ws, "container.name"):__fire("OnEnterPressed", "   ")
    -- red under: dropping the name row's validate (a container nobody can /am select by name)
    assertEqual(NS.Database.FindContainer(1).name, "Player buffs")
    assertEqual(msgs.config, 0, "a refused write announces nothing")
end)

test("containers: a rename re-lists every picker and re-applies no container", function()
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

test("containers: the Unit dropdown offers the four units in order and writes the selected container", function()
    local NS, _, P, ws = containers()
    local dd = P.row(ws, "container.unit")
    assertEqual(table.concat(dd.order, ","), table.concat(NS.Constants.UNITS, ","))
    assertEqual(dd.list.focus, NS.L["Focus"], "each unit carries its label")
    dd:__fire("OnValueChanged", "focus")
    -- red under: the row writing an absolute path, or the active container not being the target
    assertEqual(NS.Database.FindContainer(1).unit, "focus")
    assertEqual(NS.Database.FindContainer(3).unit, "target", "another container is untouched")
end)

test("containers: changing the aura type redraws an open Filters page for the new type, on the next frame", function()
    local NS, m, P, ws = containers()
    P.show("Filters")
    P.tab("filters", NS.L["Categories"])
    NS.Helpers.__pageCtx.filters.panel:Show()   -- on screen, so only a STRUCTURAL refresh re-renders it
    -- The Categories tab is the redraw signal: a debuff container's grids include Dispel Types, a buff
    -- container's do not.
    local function drewDispelTypes(widgets)
        for _, w in ipairs(widgets) do
            if w.type == "Heading" and w.text == NS.L["Dispel Types"] then return true end
        end
        return false
    end
    local during = P.during(function() P.row(ws, "container.auraType"):__fire("OnValueChanged", "HARMFUL") end)
    assertEqual(NS.Database.FindContainer(1).auraType, "HARMFUL")
    assertFalse(drewDispelTypes(during), "never inside the dropdown's own callback")
    local redrawn = P.during(function() m.__fireTimers() end)
    -- red under: the aura type row losing its structural onChange (the tab keeps a buff container's grids)
    assertTrue(drewDispelTypes(redrawn), "redrawn with the debuff container's Dispel Types")
end)

test("containers: Aura type offers Buffs and Debuffs only; the retired Weapon enchants type is refused (feedback #6)", function()
    local NS, _, P, ws = containers()
    local dd = P.row(ws, "container.auraType")
    -- red under: C.AURA_TYPES still listing ENCHANT
    assertEqual(table.concat(dd.order, ","), "HELPFUL,HARMFUL")
    local lines = P.chat()
    NS.Slash:OnSlash("set container.auraType ENCHANT")
    -- red under: /am set taking a value the row no longer lists
    assertEqual(NS.Database.FindContainer(1).auraType, "HELPFUL")
    assertTrue(table.concat(lines, "\n"):find("container.auraType", 1, true) ~= nil, "and says why")
end)

test("containers: the Style dropdown offers bars, icons and text and writes the selected container", function()
    local NS, _, P, ws = containers()
    local dd = P.row(ws, "container.style")
    -- red under: C.STYLES without "text" (the Text page would be unreachable)
    assertEqual(table.concat(dd.order, ","), "bars,icons,text")
    dd:__fire("OnValueChanged", "icons")
    -- red under: the style row writing the wrong path
    assertEqual(NS.Database.FindContainer(1).style, "icons")
    dd:__fire("OnValueChanged", "text")
    assertEqual(NS.Database.FindContainer(1).style, "text")
end)

-- ── B5: changing Style resets Fill ─────────────────────────────────────────────────────────

test("containers: a new Style resets Fill to the one it suits and leaves the grow directions (B5)", function()
    local NS, _, P, ws = containers()
    local c1 = NS.Database.FindContainer(1)
    c1.layout.growH, c1.layout.growV = "left", "up"
    local dd = P.row(ws, "container.style")
    dd:__fire("OnValueChanged", "icons")
    -- red under: the Style row without its onChange (Fill stays Columns under an icon row)
    assertEqual(c1.layout.axis, "horizontal", "bars -> icons: Rows")
    dd:__fire("OnValueChanged", "bars")
    assertEqual(c1.layout.axis, "vertical", "icons -> bars: Columns")
    dd:__fire("OnValueChanged", "icons")
    dd:__fire("OnValueChanged", "text")
    assertEqual(c1.layout.axis, "vertical", "icons -> text: Columns")
    -- red under: a reset table that also rewrites the grow directions
    assertEqual(c1.layout.growH, "left")
    assertEqual(c1.layout.growV, "up")
end)

test("containers: re-choosing the same Style keeps a Fill set by hand (B5)", function()
    local NS = containers()
    NS.SetByPath("container.layout.axis", "horizontal", 1)
    NS.SetByPath("container.style", "bars", 1)
    -- red under: onChange resetting Fill without comparing the replaced value
    assertEqual(NS.Database.FindContainer(1).layout.axis, "horizontal")
end)

test("containers: /am set container.style resets Fill the same way, one apply and one rebuild (B5)", function()
    local NS, m = containers()
    local refreshes, applies = 0, 0
    local refresh = NS.RequestPanelRefresh
    NS.RequestPanelRefresh = function(...) refreshes = refreshes + 1; return refresh(...) end
    local inst = NS.ContainerManager.instances[1]
    local apply = inst.Apply
    inst.Apply = function(...) applies = applies + 1; return apply(...) end
    NS.Slash:OnSlash("set container.style icons")
    m.__fireTimers()
    assertEqual(NS.Database.FindContainer(1).layout.axis, "horizontal")
    -- red under: the Fill write re-running the structural handler, or not coalescing with the style's
    assertEqual(refreshes, 1, "one structural rebuild")
    assertEqual(applies, 1, "one apply pass for both writes")
    NS.RequestPanelRefresh = refresh
end)

test("containers: a duplicate and a copy-from keep the source's Fill (B5)", function()
    local NS = containers()
    local CM = NS.ContainerManager
    NS.Database.FindContainer(2).layout.axis = "vertical"   -- an icon row set to Columns by hand
    local dup = NS.Database.FindContainer(CM.Duplicate(2))
    -- red under: Duplicate writing the style through the seam (its onChange would reset Fill)
    assertEqual(dup.layout.axis, "vertical")
    assertTrue(CM.CopyFrom(2, 1))
    -- red under: COPY_ALL writing the layout before the style (the reset lands over the copy)
    assertEqual(NS.Database.FindContainer(1).style, "icons")
    assertEqual(NS.Database.FindContainer(1).layout.axis, "vertical")
end)

test("containers: in combat the library refuses Duplicate; New reaches CM.Create's own gray refusal; nothing is created", function()
    local NS, m, P, ws = containers()
    local lines = P.chat()
    m.__lockdown = true
    P.find(ws, "Button", NS.L["Duplicate"]):__fire("OnClick")
    -- LibKa0s v1.46.1 (options-ui-§2): a library-drawn button is refused by the settings combat lock
    -- first, on its own gray line, once per combat; doDuplicate never runs.
    -- red under: the library's write seam not refusing the button pair in combat
    assertEqual(#lines, 1, "the lock's one notice")
    assertTrue(lines[1]:find(m.LibStub("LibKa0s-Options-1.0").STRINGS.COMBAT_LOCKED_NOTICE, 1, true) ~= nil, lines[1])
    -- New container is the host's own chrome button: in the client the lock's cover sits over it; a
    -- click that still arrives meets CM.Create's gate, the one /am new meets (test_slash.lua pins
    -- that path), since the create's apply cannot run until combat ends.
    P.find(ws, "Button", NS.L["New container"]):__fire("OnClick")
    -- red under: sayError printing a refusal plain, or a page act bypassing the combat refusal
    assertEqual(#lines, 2, "one refusal from the create gate")
    assertTrue(lines[2]:find("|cff808080cannot create a container during combat", 1, true) ~= nil, lines[2])
    assertEqual(#NS.Database.GetContainers(), #NS.STARTER_CONTAINERS)
end)

test("containers: Duplicate copies the selected container and selects the copy", function()
    local NS, _, P = containers()
    NS.SetByPath("container.icons.width", 44, 2)
    NS.Helpers.SelectContainer(2)
    local ws = P.rerender("Containers")
    P.find(ws, "Button", NS.L["Duplicate"]):__fire("OnClick")
    local _, id = NS.ActiveContainer()
    -- red under: doDuplicate copying something other than the selection, or not selecting the copy
    assertEqual(#NS.Database.GetContainers(), #NS.STARTER_CONTAINERS + 1)
    assertTrue(id ~= 2 and id == NS.db.profile.containerOrder[#NS.STARTER_CONTAINERS + 1], "the copy is selected")
    local copy = NS.Database.FindContainer(id)
    assertEqual(copy.name, "Player debuffs (copy)")
    assertEqual(copy.icons.width, 44, "every setting came with it")
end)

test("containers: Delete asks first, naming the container, and deletes it only on Yes", function()
    local NS, m, P = containers()
    local popups = P.popups()
    NS.Helpers.SelectContainer(2)
    local ws = P.rerender("Containers")
    P.find(ws, "Button", NS.L["Delete"]):__fire("OnClick")
    -- red under: doDelete deleting without the popup, or the popup not carrying the id
    assertEqual(#popups, 1)
    assertEqual(popups[1].which, "AURAMASTER_DELETE_CONTAINER")
    assertEqual(popups[1].text, "Player debuffs", "the popup names what it will delete")
    assertEqual(popups[1].data, 2)
    assertEqual(#NS.Database.GetContainers(), #NS.STARTER_CONTAINERS, "nothing deleted before the answer")
    m.StaticPopupDialogs.AURAMASTER_DELETE_CONTAINER.OnAccept(popups[1], popups[1].data)
    assertEqual(ids(NS), "1,3,4")
    local _, active = NS.ActiveContainer()
    assertEqual(active, 1, "the selection falls back to the first container")
end)

test("containers: the copy block offers every other container and copies only the chosen section", function()
    local NS, _, P, ws = containers()
    NS.SetByPath("container.bars.width", 123, 2)
    NS.SetByPath("container.layout.spacing", 9, 2)
    local source = P.find(ws, "Dropdown", NS.L["Source container"])
    local what = P.find(ws, "Dropdown", NS.L["What to copy"])
    -- red under: the source list including the selected container (a copy onto itself)
    -- by name (B2-2): Player cooldowns, Player debuffs, Target debuffs (mine)
    assertEqual(table.concat(source.order, ","), "4,2,3")
    assertEqual(table.concat(what.order, ","), "all,filter,layout,behavior,bars,icons,text")
    source:__fire("OnValueChanged", 2)
    what:__fire("OnValueChanged", "bars")
    P.find(ws, "Button", NS.L["Copy onto this container"]):__fire("OnClick")
    local c1 = NS.Database.FindContainer(1)
    assertEqual(c1.bars.width, 123, "the chosen section came across")
    assertEqual(c1.layout.spacing, NS.CONTAINER_TEMPLATE.layout.spacing, "and nothing else did")
    -- Mixed case (B2-2), written straight to the store: red under a byte sort (Zeta, alpha, beta)
    local cs = NS.db.profile.containers
    cs[2].name, cs[3].name, cs[4].name = "beta", "Zeta", "alpha"
    source = P.find(P.rerender("Containers"), "Dropdown", NS.L["Source container"])
    assertEqual(table.concat(source.order, ","), "4,2,3")
end)

test("containers: copying Everything takes what the source is, never its name or position", function()
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

test("containers: with one container the page offers Duplicate and Delete but no copy block", function()
    local NS, _, P = containers()
    NS.ContainerManager.Delete(2)
    NS.ContainerManager.Delete(3)
    NS.ContainerManager.Delete(4)
    local ws = P.rerender("Containers")
    assertTrue(P.find(ws, "Button", NS.L["Duplicate"]) ~= nil)
    assertTrue(P.find(ws, "Button", NS.L["Delete"]) ~= nil)
    -- red under: afterRows drawing the copy block with nothing to copy from
    assertNil(P.find(ws, "Dropdown", NS.L["Source container"]))
    assertNil(P.find(ws, "Button", NS.L["Copy onto this container"]))
end)

test("containers: Defaults restores Enabled, Unit, Aura type and Style, and never the name", function()
    local NS, m = containers()
    local T0 = NS.CONTAINER_TEMPLATE
    NS.State.SetActiveContainer(2)
    NS.SetByPath("container.name", "Raid debuffs")
    NS.SetByPath("container.enabled", false)
    NS.SetByPath("container.unit", "focus")
    m.__subcategories.Containers.defaultsOnClick()
    local c2 = NS.Database.FindContainer(2)
    assertEqual(c2.enabled, T0.enabled)
    assertEqual(c2.unit, T0.unit)
    assertEqual(c2.auraType, T0.auraType)
    assertEqual(c2.style, T0.style)
    -- red under: NS.ApplyDefault not honoring the name row's noReset (the name goes back to the template's)
    assertEqual(c2.name, "Raid debuffs")
    assertEqual(NS.Database.FindContainer(3).unit, "target", "only the selected container")
end)

test("containers: the page's Defaults tooltip says it takes the selected container's identity and keeps its name", function()
    local NS, m = containers()
    -- red under: the tooltip still describing a page of profile rows, or naming General
    assertEqual(m.__subcategories.Containers.defaultsTooltip,
        NS.L["Restore the selected container's Enabled, Unit, Aura type and Style to its addon default. Its name is kept."])
end)
