-- tests/test_optionssetup.lua — settings/OptionsSetup.lua and the pages: the library instance, the
-- page registry, the container banner, the global reset's blast radius, and the load-completing
-- degradation stub.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local NS, mocks = T.NS, T.mocks
local fresh = dofile("tests/fresh_env.lua")
local loadDegraded = dofile("tests/degraded_env.lua")

local PAGES = { "General", "Containers", "Filters", "Layout", "Bars", "Icons" }

test("options: NS.Helpers IS the library instance", function()
    assertEqual(type(NS.Helpers.RenderTabbedSchema), "function")
    assertEqual(type(NS.Helpers.PageBanner), "function")
end)

test("options: every page registers, in TOC order, and Profiles opts out without AceDBOptions", function()
    for _, name in ipairs(PAGES) do
        assertTrue(mocks.__subcategories[name] ~= nil, "page " .. name)
    end
    assertNil(mocks.__subcategories.Profiles, "the harness has no AceDBOptions; the page returns nil")
end)

test("options: every page renders without a reported error", function()
    local NS2, m = fresh()
    local lines = {}
    rawset(m.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg) lines[#lines + 1] = tostring(msg) end)
    local aceGUI = m.LibStub("AceGUI-3.0")
    for _, name in ipairs(PAGES) do
        local before = #aceGUI.__created
        m.__subcategories[name]:__fire("OnShow")
        assertTrue(#aceGUI.__created > before, name .. " drew widgets")
    end
    for _, l in ipairs(lines) do
        assertFalse(l:lower():find("error") or l:lower():find("failed"), "reported: " .. l)
    end
    assertTrue(NS2.Helpers ~= nil)
end)

test("options: the General page leads with Master controls, in canonical order", function()
    local rows = NS.SchemaForPage("general")
    local want = { "enabled", "visibility", "scale", "alpha", "locked", "state.debugConsole" }
    for i, path in ipairs(want) do
        assertEqual(rows[i].path, path)
        assertEqual(rows[i].group, NS.Helpers.MASTER_GROUP)
    end
    assertEqual(NS.Helpers.MASTER_GROUP, "Master controls")
end)

test("options: the Filters page offers the spell-list tab only for a buff container", function()
    local NS2, m = fresh()
    local ctx = NS2.Helpers.__containerCtx.filters
    local function tabs()
        local keys = {}
        for _, t in ipairs(ctx.__tabs or {}) do keys[t.key] = true end
        return keys
    end
    NS2.State.SetActiveContainer(1)
    m.__subcategories.Filters:__fire("OnShow")
    assertTrue(tabs().spellLists)
    assertTrue(tabs().alwaysNever)
    NS2.Helpers.SelectContainer(2)
    NS2.Helpers.RenderContainerPage(ctx, "filters", nil)
    assertNil(tabs().spellLists)
end)

test("options: the banner is the picker — choosing a container retargets every page", function()
    local NS2, m = fresh()
    m.__subcategories.Bars:__fire("OnShow")
    local ctx = NS2.Helpers.__containerCtx.bars
    assertTrue(ctx.__bannerWidget ~= nil, "the page drew its banner")
    ctx.__bannerWidget:__fire("OnValueChanged", 3)
    assertEqual(NS2.State.activeContainerId, 3)
    assertEqual(NS2.GetSetting("container.unit"), "target")
end)

test("options: the Containers page's New button creates and selects a container", function()
    local NS2, m = fresh()
    m.__subcategories.Containers:__fire("OnShow")
    local ctx = NS2.Helpers.__containerCtx.containers
    local newButton
    for _, w in ipairs(ctx.__chromeWidgets or {}) do
        if w.type == "Button" then newButton = w end
    end
    assertTrue(newButton ~= nil, "the chrome block carries the create control")
    newButton:__fire("OnClick")
    assertEqual(#NS2.Database.GetContainers(), 4)
    local _, id = NS2.ActiveContainer()
    assertEqual(id, NS2.db.profile.containerOrder[4])
end)

test("options: a page's Defaults button restores only the selected container", function()
    local NS2, m = fresh()
    m.__subcategories.Bars:__fire("OnShow")
    local ctx = NS2.Helpers.__containerCtx.bars
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
    NS2.SetByPath("state.preview", true)
    NS2.db:SetProfile("Raid")
    NS2.db:SetProfile("Default")
    local profilesBefore = table.concat(NS2.db:GetProfiles(), ",")
    local changed = { 0 }
    NS2.NewBusTarget():RegisterMessage(NS2.MSG.CONTAINERS_CHANGED, function() changed[1] = changed[1] + 1 end)

    NS2.Helpers.RestoreAllDefaults()

    local names = {}
    for _, c in ipairs(NS2.Database.GetContainers()) do names[#names + 1] = c.name end
    assertEqual(table.concat(names, "|"), "Player buffs|Player debuffs|Target debuffs (mine)",
        "exactly the shipped set survives")
    assertEqual(table.concat(NS2.db:GetProfiles(), ","), profilesBefore, "the profile list is untouched")
    assertEqual(NS2.db:GetCurrentProfile(), "Default")
    assertFalse(NS2.State.preview, "session rows are swept too")
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
    rawset(m.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg) lines[#lines + 1] = tostring(msg) end)
    m.__lockdown = true
    NS2.OpenOptionsPage("layout")
    -- red under: OpenOptionsPage without its InCombatLockdown gate
    assertEqual(opened, 0, "no protected category switch in combat")
    assertEqual(#lines, 1, "exactly one refusal line")
    assertTrue(lines[1]:find("|cff808080", 1, true) ~= nil, "gray: " .. lines[1])
    assertTrue(lines[1]:find("cannot open settings during combat — Blizzard's category-switch is protected",
        1, true) ~= nil, "canonical: " .. lines[1])
end)

test("options: the Delete and Reset-all popups refuse in combat", function()
    local NS2, m = fresh()
    local resets = 0
    NS2.Helpers.RestoreAllDefaults = function() resets = resets + 1 end
    local lines = {}
    rawset(m.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg) lines[#lines + 1] = tostring(msg) end)
    m.__lockdown = true
    m.StaticPopupDialogs.AURAMASTER_DELETE_CONTAINER.OnAccept(nil, 2)
    m.StaticPopupDialogs.AURAMASTER_RESET_ALL.OnAccept()
    -- red under: the Delete popup's OnAccept without its InCombatLockdown gate
    assertTrue(NS2.Database.FindContainer(2) ~= nil, "the registry is intact")
    assertEqual(#NS2.Database.GetContainers(), 3)
    -- red under: the Reset-all popup's OnAccept without its InCombatLockdown gate
    assertEqual(resets, 0, "no reset ran")
    assertEqual(#lines, 2, "one refusal per popup")
    assertTrue(lines[1]:find("|cff808080", 1, true) and lines[1]:find("cannot delete a container during combat",
        1, true) ~= nil, lines[1] or "")
    assertTrue(lines[2]:find("|cff808080", 1, true) and lines[2]:find("cannot reset settings during combat",
        1, true) ~= nil, lines[2] or "")
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
    local ctx = H.__containerCtx.bars
    ctx.chrome:__setGeom(200, 0)
    H.__resetTabArtHeight()

    local function snapshot()
        local ys = {}
        for i = 1, #ctx.__tabs do
            local b = ctx.__tabKids[i]
            assertEqual(b.__stripRel, ctx.chrome, "tab " .. i .. " anchors to the chrome")
            ys[i] = b.__stripY
        end
        return { band = ctx.chromeHeight, ys = ys }
    end
    local function clear() for _, b in ipairs(buttons) do b.__stripRel, b.__stripY = nil, nil end end

    clear()
    m.__subcategories.Bars:__fire("OnShow")
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

    for i = 2, #keys do
        clear()
        ctx.__tabKids[i]:__fire("OnClick")
        assertEqual(ctx.activeTab, keys[i], "selected " .. keys[i])
        local got = snapshot()
        -- red under: placeTabs taking its pitch from the first button's art as drawn (active when tab 1 is selected) — the pre-minor-13 bug
        assertEqual(got.band, ref.band, "band with " .. keys[i] .. " selected")
        for j = 1, #keys do
            assertEqual(got.ys[j], ref.ys[j], "tab " .. j .. " y with " .. keys[i] .. " selected")
        end
    end
end)

test("options: the degraded stub completes the load — every page's rows still register", function()
    local NS2, m2 = loadDegraded()
    for _, member in ipairs({ "LSMValues", "ColorPair", "FontGroup", "BorderGroup", "BarGroup",
            "MasterControls", "RestoreAllDefaults" }) do
        assertEqual(type(NS2.Helpers[member]), "function", member)
    end
    assertEqual(NS2.Helpers.MASTER_GROUP, "Master controls")
    assertEqual(#NS2.Schema, #NS.Schema, "the degraded schema has every row the live one has")
    local lines = {}
    rawset(m2.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg) lines[#lines + 1] = tostring(msg) end)
    NS2.CreateOptionsPanel()
    -- The degraded printer names the missing library once, on the first line it ever prints
    -- (core/CoreSetup.lua); the panel's own refusal is the line after it.
    assertTrue(#lines >= 1 and #lines <= 2, "at most the one-time notice and the refusal")
    assertTrue(lines[#lines]:find("settings panel is unavailable", 1, true) ~= nil, lines[#lines] or "")
end)
