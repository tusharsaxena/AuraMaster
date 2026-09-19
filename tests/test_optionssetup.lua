-- tests/test_optionssetup.lua — settings/OptionsSetup.lua and the pages: the library instance, the
-- page registry, the container banner, the global reset's blast radius, and the load-completing
-- degradation stub.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local NS, mocks = T.NS, T.mocks
local fresh = dofile("tests/fresh_env.lua")
local loadDegraded = dofile("tests/degraded_env.lua")

-- Pages, by key and tree label. Filters, Layout, Bars, Icons and Text are sub-pages of Containers
-- (N-2): their KEY stays plain (D6 — the mark is a label prefix, never a second hierarchy), but the
-- tree label Blizzard registers them under carries NS.SubPageLabel's mark.
local PAGES = {
    { key = "general",    label = "General" },
    { key = "containers", label = "Containers" },
    { key = "filters",    label = NS.SubPageLabel("Filters") },
    { key = "layout",     label = NS.SubPageLabel("Layout") },
    { key = "bars",       label = NS.SubPageLabel("Bars") },
    { key = "icons",      label = NS.SubPageLabel("Icons") },
    { key = "text",       label = NS.SubPageLabel("Text") },
}

test("options: NS.Helpers IS the library instance", function()
    assertEqual(type(NS.Helpers.RenderTabbedSchema), "function")
    assertEqual(type(NS.Helpers.PageBanner), "function")
end)

test("options: every page registers, in TOC order, and Profiles opts out without AceDBOptions", function()
    for _, p in ipairs(PAGES) do
        assertTrue(mocks.__subcategories[p.label] ~= nil, "page " .. p.label)
    end
    assertNil(mocks.__subcategories.Profiles, "the harness has no AceDBOptions; the page returns nil")
end)

test("options: the Profiles page SHOWS the container AceConfigDialog fills, even a pooled (hidden) one", function()
    -- AceGUI:Release hides a widget's frame before pooling it, and neither AceGUI:Create nor
    -- AceConfigDialog:Open shows it again. The container is created on first show, when the pool
    -- is rarely empty, so AceConfigDialog filled a hidden frame and the page read as blank. The kit's
    -- frames start hidden, which is exactly the pooled case.
    -- red under: the renderer not calling container.frame:Show().
    local opened = {}
    local _, m = fresh({ before = function(mk)
        mk.__libs["AceDBOptions-3.0"] = { GetOptionsTable = function() return { type = "group", args = {} } end }
        mk.__libs["AceConfig-3.0"] = { RegisterOptionsTable = function() end }
        mk.__libs["AceConfigDialog-3.0"] = { Open = function(_, app, container)
            opened[#opened + 1] = { app = app, container = container }
        end }
    end })
    local panel = m.__subcategories.Profiles
    assertTrue(panel ~= nil, "with AceDBOptions present the Profiles page registers")
    panel:__fire("OnShow")
    assertEqual(#opened, 1, "the first show opens the AceDBOptions table once")
    assertEqual(opened[1].app, "AuraMaster-Profiles")
    local frame = opened[1].container and opened[1].container.frame
    assertTrue(frame ~= nil, "AceConfigDialog is handed an AceGUI container")
    assertTrue(frame:IsShown(), "the container AceConfigDialog fills is shown")
end)

test("options: every page renders without a reported error", function()
    local NS2, m = fresh()
    local lines = {}
    rawset(m.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
        lines[#lines + 1] = tostring(msg)
    end)
    local aceGUI = m.LibStub("AceGUI-3.0")
    for _, p in ipairs(PAGES) do
        local before = #aceGUI.__created
        NS2.Helpers.__pageCtx[p.key].panel:__fire("OnShow")
        assertTrue(#aceGUI.__created > before, p.key .. " drew widgets")
    end
    for _, l in ipairs(lines) do
        assertFalse(l:lower():find("error") or l:lower():find("failed"), "reported: " .. l)
    end
    assertTrue(NS2.Helpers ~= nil)
end)

test("options: the General page leads with Master controls, in canonical order", function()
    local rows = NS.SchemaForPage("general")
    local want = { "enabled", "visibility", "scale", "alpha", "locked", "state.debugConsole",
                   "global.minimap.hide", "state.testMode" }
    for i, path in ipairs(want) do
        assertEqual(rows[i].path, path)
        assertEqual(rows[i].group, NS.Helpers.MASTER_GROUP)
    end
    -- red under: settings/General.lua without its testModePath (B1: unlocking no longer previews,
    -- so the test mode has a row of its own, beside Minimap button: options-ui-§15, anti-pattern #80)
    assertTrue(rows[9] == nil or rows[9].group ~= NS.Helpers.MASTER_GROUP, "Master controls has eight rows")
    assertTrue(rows[8].sessionOnly, "Test mode is session state")
    assertNil(rows[8].startsLine, "it pairs beside Minimap button")
    assertEqual(NS.Helpers.MASTER_GROUP, "Master controls")
end)

test("options: the Filters page offers the Overrides tab only for a buff or debuff container", function()
    local NS2 = fresh()
    local ctx = NS2.Helpers.__pageCtx.filters
    local function tabs()
        local keys = {}
        for _, t in ipairs(ctx.__tabs or {}) do keys[t.key] = true end
        return keys
    end
    NS2.State.SetActiveContainer(1)
    NS2.Helpers.__pageCtx.filters.panel:__fire("OnShow")
    assertTrue(tabs().overrides)
    NS2.SetByPath("container.auraType", "ENCHANT", 1)
    -- Redrawn through the page's own registered spec, whose Overrides tab names its aura types.
    NS2.Helpers.RefreshAllPanels()
    NS2.Helpers.__pageCtx.filters.panel:__fire("OnShow")
    -- red under: collectTabs ignoring a bespoke tab's auraTypes
    assertNil(tabs().overrides)
end)

-- Characterization (testing-§13): pinned on RenderContainerPage as one function, before its tab
-- collection and tab validation moved into local helpers.

test("options: a container page's tabs are its schema groups, with a bespoke tab placed where it asks; a stale tab falls back", function()
    local NS2 = fresh()
    local ctx = NS2.Helpers.__pageCtx.filters
    NS2.State.SetActiveContainer(1)
    NS2.Helpers.__pageCtx.filters.panel:__fire("OnShow")
    -- Batch 8: the Filters page's `overrides` tab carries `before = Sorting`, so it is INSERTED
    -- ahead of that group rather than appended after every group (placeTab). A bespoke tab with no
    -- `before` still lands last; this page no longer has one to prove it with, so the expectation
    -- below is the insertion, derived from the schema rather than written out.
    local want, seen = {}, {}
    for _, row in ipairs(NS2.SchemaForPage("filters")) do
        if not seen[row.group] then
            seen[row.group] = true
            if row.group == NS2.L["Sorting"] then
                want[#want + 1] = "overrides"
            end
            want[#want + 1] = row.group
        end
    end
    local got = {}
    for i, t in ipairs(ctx.__tabs) do got[i] = t.key end
    assertEqual(table.concat(got, ","), table.concat(want, ","), "schema groups, the bespoke tab where it asked")
    ctx.activeTab = "no such tab"
    NS2.Helpers.RefreshAllPanels()   -- a hidden panel is marked dirty, and re-renders on its next show
    NS2.Helpers.__pageCtx.filters.panel:__fire("OnShow")
    assertEqual(ctx.activeTab, want[1], "a tab the page does not draw falls back to the first")
end)

test("options: with no containers a container page draws one placeholder tab", function()
    local NS2 = fresh()
    for _, c in ipairs(NS2.Database.GetContainers()) do NS2.ContainerManager.Delete(c.id) end
    NS2.Helpers.__pageCtx.filters.panel:__fire("OnShow")
    local ctx = NS2.Helpers.__pageCtx.filters
    assertEqual(#ctx.__tabs, 1, "one tab")
    assertEqual(ctx.__tabs[1].key, "__empty")
    assertEqual(ctx.activeTab, "__empty")
end)

test("options: the banner is the picker — choosing a container retargets every page", function()
    local NS2 = fresh()
    NS2.Helpers.__pageCtx.bars.panel:__fire("OnShow")
    local ctx = NS2.Helpers.__pageCtx.bars
    assertTrue(ctx.__bannerWidget ~= nil, "the page drew its banner")
    ctx.__bannerWidget:__fire("OnValueChanged", 3)
    assertEqual(NS2.State.activeContainerId, 3)
    assertEqual(NS2.GetSetting("container.unit"), "target")
end)

test("options: the Containers page's New button creates and selects a container", function()
    local NS2, m = fresh()
    NS2.Helpers.__pageCtx.containers.panel:__fire("OnShow")
    local newButton
    local created = m.LibStub("AceGUI-3.0").__created
    for _, w in ipairs(created) do
        if w.type == "Button" and w.text == "New container" and not w.__released then newButton = w end
    end
    -- red under: the Containers page not drawing its create control
    assertTrue(newButton ~= nil, "the band carries the create control")
    newButton:__fire("OnClick")
    assertEqual(#NS2.Database.GetContainers(), #NS2.STARTER_CONTAINERS + 1)
    local _, id = NS2.ActiveContainer()
    assertEqual(id, NS2.db.profile.containerOrder[#NS2.STARTER_CONTAINERS + 1])
end)

test("options: a page's Defaults button restores only the selected container", function()
    local NS2 = fresh()
    NS2.Helpers.__pageCtx.bars.panel:__fire("OnShow")
    local ctx = NS2.Helpers.__pageCtx.bars
    NS2.SetByPath("container.bars.width", 300, 1)
    NS2.SetByPath("container.bars.width", 300, 2)
    NS2.State.SetActiveContainer(1)
    NS2.Helpers.RestoreDefaults("bars", ctx)
    assertEqual(NS2.Database.FindContainer(1).bars.width, NS2.CONTAINER_TEMPLATE.bars.width)
    assertEqual(NS2.Database.FindContainer(2).bars.width, 300)
end)

test("options: Reset all settings resets the active profile whole, and nothing else (options-ui-§12)", function()
    local NS2 = fresh()
    local CM = NS2.ContainerManager
    CM.Create({ name = "Extra one" })
    CM.Create({ name = "Extra two" })
    NS2.SetByPath("state.debugConsole", true)
    NS2.db:SetProfile("Raid")
    NS2.db:SetProfile("Default")
    local profilesBefore = table.concat(NS2.db:GetProfiles(), ",")
    local changed = { 0 }
    NS2.NewBusTarget():RegisterMessage(NS2.MSG.CONTAINERS_CHANGED, function() changed[1] = changed[1] + 1 end)

    NS2.Helpers.RestoreAllDefaults()

    local names = {}
    for _, c in ipairs(NS2.Database.GetContainers()) do
        names[#names + 1] = c.name
    end
    assertEqual(table.concat(names, "|"), "Player buffs|Player debuffs|Target debuffs (mine)|Player cooldowns",
        "exactly the shipped set survives")
    assertEqual(table.concat(NS2.db:GetProfiles(), ","), profilesBefore, "the profile list is untouched")
    assertEqual(NS2.db:GetCurrentProfile(), "Default")
    assertFalse(NS2.DebugLog:IsShown(), "session rows are swept too")
    assertTrue(changed[1] >= 1, "the registry change was announced")
end)

test("options: opening a page in combat refuses with the canonical gray line", function()
    -- A subcategory that answers GetID, as the client's does, so an ungated open would reach
    -- Settings.OpenToCategory rather than the library's own (also refusing) panel open.
    local opened = 0
    local NS2, m = fresh({ before = function(mk)
        local register = mk.Settings.RegisterCanvasLayoutSubcategory
        mk.Settings.RegisterCanvasLayoutSubcategory = function(...)
            local cat = register(...)
            cat.GetID = function() return 7 end
            return cat
        end
        mk.Settings.OpenToCategory = function() opened = opened + 1 end
    end })
    local lines = {}
    rawset(m.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
        lines[#lines + 1] = tostring(msg)
    end)
    m.__lockdown = true
    NS2.OpenOptionsPage("layout")
    -- red under: OpenOptionsPage without its InCombatLockdown gate
    assertEqual(opened, 0, "no protected category switch in combat")
    assertEqual(#lines, 1, "exactly one refusal line")
    assertTrue(lines[1]:find("|cff808080", 1, true) ~= nil, "gray: " .. lines[1])
    assertTrue(lines[1]:find("cannot open settings during combat — Blizzard's category-switch is protected",
        1, true) ~= nil, "canonical: " .. lines[1])
end)

-- The Reset-all popup is not refused in combat: it is Profiles → Reset Profile (options-ui-§12), and
-- tests/test_slash.lua drives it under lockdown through the parked teardown.
test("options: the Delete popup refuses in combat", function()
    local NS2, m = fresh()
    local lines = {}
    rawset(m.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
        lines[#lines + 1] = tostring(msg)
    end)
    m.__lockdown = true
    m.StaticPopupDialogs.AURAMASTER_DELETE_CONTAINER.OnAccept(nil, 2)
    -- red under: the Delete popup's OnAccept without its InCombatLockdown gate
    assertTrue(NS2.Database.FindContainer(2) ~= nil, "the registry is intact")
    assertEqual(#NS2.Database.GetContainers(), #NS2.STARTER_CONTAINERS)
    assertEqual(#lines, 1, "one refusal")
    assertTrue(lines[1]:find("|cff808080", 1, true) and lines[1]:find("cannot delete a container during combat",
        1, true) ~= nil, lines[1] or "")
end)

test("options: the Background block is composed in canonical order, and its tooltips name the background", function()
    local L, P = NS.L, "container.bars."
    local byPath, order = {}, {}
    for i, row in ipairs(NS.Schema) do byPath[row.path], order[row.path] = row, i end
    local want = {
        { "bgTexture", L["The texture drawn behind the fill."] },
        { "bgAlpha", L["How opaque the background texture is."] },
        { "bgColor", L["The background color."] },
        { "useClassColorBg", L["Draw the background in the class color instead of the swatch beside it."] },
    }
    local first = order[P .. want[1][1]]
    for i, w in ipairs(want) do
        local row = byPath[P .. w[1]]
        assertTrue(row ~= nil, "no row " .. w[1])
        assertEqual(order[row.path], first + i - 1, w[1] .. " in canonical order")
        assertEqual(row.subgroup, L["Background"], w[1] .. " subgroup")
        local tip = row.tooltip or ""
        assertEqual(tip:sub(1, #w[2]), w[2], w[1] .. " tooltip")
        -- red under: dropping the tooltip post-set
        assertFalse(tip:find("fill is drawn", 1, true), w[1] .. " kept the fill's tooltip: " .. tip)
        assertFalse(tip:find("this bar in the class color", 1, true), w[1] .. " kept the bar's companion tooltip")
        assertFalse(tip:find("bar's fill", 1, true), w[1] .. " describes the fill: " .. tip)
    end
    assertEqual(byPath[P .. "bgAlpha"].label, L["Background opacity"])
    -- The swatch keeps the composer's class-color note (options-ui-§17).
    local note = NS.Helpers.CLASS_COLOR_NOTE
    assertTrue(note ~= nil and byPath[P .. "bgColor"].tooltip:find(note, 1, true) ~= nil, "the class-color note")
end)

test("options: a wrapped tab strip reserves the same band and places every tab at the same y for every selection", function()
    -- options-ui-§13: nothing about the strip's geometry may depend on which tab is selected. The
    -- Bars page has seven tabs; a narrow chrome wraps them. Geometry is armed so the pitch probe
    -- measures the kit's atlas fixture, where the selected tab's art is taller than the rest.
    local buttons = {}
    local NS2, m = fresh({ before = function(mk)
        mk.__armGeometry = true
        local create = mk.CreateFrame
        mk.CreateFrame = function(frameType, ...)
            local f = create(frameType, ...)
            if frameType == "Button" then
                buttons[#buttons + 1] = f
                -- Only the strip's own placement anchors TOPLEFT to TOPLEFT of another frame.
                rawset(f, "SetPoint", function(self, point, rel, relPoint, _, y)
                    if point == "TOPLEFT" and relPoint == "TOPLEFT" and type(rel) == "table" then
                        self.__stripRel, self.__stripY = rel, y
                    end
                    return self
                end)
            end
            return f
        end
    end })
    local H = NS2.Helpers
    local ctx = H.__pageCtx.bars
    ctx.chrome:__setGeom(200, 0)
    H.__resetTabArtHeight()

    local function snapshot()
        local ys = {}
        for i in ipairs(ctx.__tabs) do
            local b = ctx.__tabKids[i]
            assertEqual(b.__stripRel, ctx.chrome, "tab " .. i .. " anchors to the chrome")
            ys[i] = b.__stripY
        end
        return { band = ctx.chromeHeight, ys = ys }
    end
    local function clear() for _, b in ipairs(buttons) do b.__stripRel, b.__stripY = nil, nil end end

    clear()
    NS2.Helpers.__pageCtx.bars.panel:__fire("OnShow")
    local keys = {}
    for i, t in ipairs(ctx.__tabs) do keys[i] = t.key end
    assertTrue(#keys >= 2, "the page draws several tabs")
    assertEqual(ctx.activeTab, keys[1])
    assertEqual(H.__tabArtHeight(), m.__atlasSizes["Options_Tab_Left"][2], "the probe measured the inactive art")
    local ref = snapshot()
    local rows = {}
    for _, y in ipairs(ref.ys) do rows[y] = true end
    local rowCount = 0
    for _ in pairs(rows) do rowCount = rowCount + 1 end
    assertTrue(rowCount >= 2, "the strip wrapped (" .. rowCount .. " row)")

    local keyCount = #keys
    for i = 2, keyCount do
        clear()
        ctx.__tabKids[i]:__fire("OnClick")
        assertEqual(ctx.activeTab, keys[i], "selected " .. keys[i])
        local got = snapshot()
        -- red under: placeTabs taking its pitch from the first button's art as drawn (active when tab 1 is selected) — the pre-minor-13 bug
        assertEqual(got.band, ref.band, "band with " .. keys[i] .. " selected")
        for j = 1, keyCount do
            assertEqual(got.ys[j], ref.ys[j], "tab " .. j .. " y with " .. keys[i] .. " selected")
        end
    end
end)

test("options: the degraded stub completes the load — every page's rows still register", function()
    local NS2, m2 = loadDegraded()
    for _, member in ipairs({ "ColorPair", "FontGroup", "BorderGroup", "BarGroup",
            "MasterControls", "RestoreAllDefaults" }) do
        assertEqual(type(NS2.Helpers[member]), "function", member)
    end
    assertEqual(NS2.Helpers.MASTER_GROUP, "Master controls")
    assertEqual(#NS2.Schema, #NS.Schema, "the degraded schema has every row the live one has")
    local lines = {}
    rawset(m2.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
        lines[#lines + 1] = tostring(msg)
    end)
    NS2.CreateOptionsPanel()
    -- The degraded printer names the missing library once, on the first line it ever prints
    -- (core/CoreSetup.lua); the panel's own refusal is the line after it.
    local count = #lines
    assertTrue(count >= 1 and count <= 2, "at most the one-time notice and the refusal")
    local last = lines[count] or ""
    assertTrue(last:find("settings panel is unavailable", 1, true) ~= nil, last)
end)

test("options: a page drawn for another style heads its tabs with the notice in muted gold (B3)", function()
    local NS2, m2 = fresh()
    local P = dofile("tests/page_helpers.lua")(NS2, m2)
    NS2.State.SetActiveContainer(2)   -- the starter icon row
    local ws = P.show("Bars")
    local want = "|c" .. NS2.Constants.NOTICE_COLOR
    assertEqual(NS2.Constants.NOTICE_COLOR, "ffc8a85a")
    local hit
    for _, t in ipairs(P.texts(ws)) do
        if t:find("Not in use:", 1, true) then hit = t end
    end
    -- red under: drawDisabledNotice keeping the old gray |cff808080
    assertTrue(hit ~= nil and hit:sub(1, #want) == want, tostring(hit))
end)
