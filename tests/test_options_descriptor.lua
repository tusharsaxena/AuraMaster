-- tests/test_options_descriptor.lua — settings/OptionsSetup.lua's own half of LibKa0s-Options-1.0:
-- the descriptor's seams driven through real widgets and the library's resets, the Profiles veto on
-- both arms, the container banner and picker, RenderContainerPage's spec, the coalesced refresh,
-- OpenOptionsPage, and the degradation stub's composers and reset loop. The library's flow engine and
-- widget makers are tested in LibKa0s (testing-§8).

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local loadDegraded = dofile("tests/degraded_env.lua")

--- The newest AceGUI widget of `wtype` whose label is `label`.
local function widget(mocks, wtype, label)
    local created = mocks.LibStub("AceGUI-3.0").__created
    local last = #created
    for i = last, 1, -1 do
        local w = created[i]
        if w.type == wtype and w.labelText == label and not w.__released then return w end
    end
end

local function announcements(NS2)
    local got = {}
    NS2.NewBusTarget():RegisterMessage(NS2.MSG.CONFIG_CHANGED, function(_, p)
        got[#got + 1] = p
    end)
    return got
end

local function counter(tbl, name)
    local n, orig = { 0 }, tbl[name]
    tbl[name] = function(...)
        n[1] = n[1] + 1
        return orig(...)
    end
    return n
end

--- Click the tab `key` on a rendered container page.
local function clickTab(ctx, key)
    for i, t in ipairs(ctx.__tabs) do
        if t.key == key then return ctx.__tabKids[i]:__fire("OnClick") end
    end
    error("no tab " .. tostring(key))
end

local function deleteAll(NS2)
    for _, c in ipairs(NS2.Database.GetContainers()) do NS2.ContainerManager.Delete(c.id) end
end

-- ── the descriptor's seams ────────────────────────────────────────────────────────────────────

test("options descriptor: a rendered widget reads the selected container and writes it through the seam", function()
    local NS2, m = fresh()
    NS2.State.SetActiveContainer(1)
    NS2.Helpers.__pageCtx.bars.activeTab = NS2.L["Icon"]
    NS2.Helpers.__pageCtx.bars.panel:__fire("OnShow")
    local dd = widget(m, "Dropdown", NS2.FindSchemaRow("container.bars.icon").label)
    assertTrue(dd ~= nil, "the Icon tab drew the icon-position dropdown")
    assertEqual(dd.value, NS2.Database.FindContainer(1).bars.icon, "get read the selected container")
    local got = announcements(NS2)
    dd:__fire("OnValueChanged", "RIGHT")
    assertEqual(NS2.Database.FindContainer(1).bars.icon, "RIGHT")
    assertEqual(NS2.Database.FindContainer(2).bars.icon, NS2.CONTAINER_TEMPLATE.bars.icon)
    -- red under: the descriptor's set writing the table around NS.SetByPath (nothing announced)
    assertEqual(#got, 1)
    assertEqual(got[1].path, "container.bars.icon")
    assertEqual(got[1].containerId, 1)
end)

test("options descriptor: a color swatch shows the stored color and stores the picker's in the {r, g, b, a} shape", function()
    local NS2, m = fresh()
    NS2.State.SetActiveContainer(1)
    NS2.Helpers.__pageCtx.bars.panel:__fire("OnShow")
    local row = NS2.FindSchemaRow("container.bars.barColor")
    clickTab(NS2.Helpers.__pageCtx.bars, row.group)
    local cp = widget(m, "ColorPicker", row.label)
    assertTrue(cp ~= nil, "the " .. row.group .. " tab drew the bar color swatch")
    local stored = NS2.Database.FindContainer(1).bars.barColor
    -- red under: colorDecode reading positional channels (every swatch paints white)
    assertEqual(cp.color.r, stored.r)
    assertEqual(cp.color.b, stored.b)
    cp:__fire("OnValueConfirmed", 0.1, 0.2, 0.3)
    local c = NS2.Database.FindContainer(1).bars.barColor
    -- red under: colorEncode storing { r, g, b, a } positionally, or leaving a nil alpha nil
    assertEqual(c.r, 0.1)
    assertEqual(c.b, 0.3)
    assertEqual(c.a, 1)
    assertNil(c[1])
end)

test("options descriptor: a page's Defaults resets the page's session rows too", function()
    local NS2 = fresh()
    -- A planted session row, not preview: resetting `locked` ends preview through its own onChange,
    -- so preview going off would prove nothing about which rows the page's walk was handed.
    local restored = {}
    NS2.RegisterSchemaRows({
        { path = "state.generalProbe", page = "general", group = "G", type = "bool", sessionOnly = true,
          default = false, get = function() return true end,
          set = function(v)
              restored[#restored + 1] = tostring(v)
          end },
    })
    NS2.SetByPath("hideBlizzardBuffs", true)
    NS2.Helpers.RestoreDefaults("general")
    -- red under: rowsForPage answering only profile-backed rows (the session row is never reset)
    assertEqual(table.concat(restored, ","), "false")
    assertFalse(NS2.db.profile.hideBlizzardBuffs)
end)

test("options descriptor: Reset all writes only session rows through the seam and resets only the active profile", function()
    local NS2 = fresh()
    NS2.db:SetProfile("Raid")
    NS2.SetByPath("alpha", 0.3)
    NS2.db:SetProfile("Default")
    NS2.SetByPath("alpha", 0.6)
    NS2.SetByPath("state.debugConsole", true)
    local written, real = {}, NS2.SetByPath
    NS2.SetByPath = function(path, ...)
        written[#written + 1] = path
        return real(path, ...)
    end
    NS2.Helpers.RestoreAllDefaults()
    NS2.SetByPath = real
    assertTrue(#written >= 1, "the session rows are still restored")
    for _, path in ipairs(written) do
        local row = NS2.FindSchemaRow(path)
        -- red under: the descriptor reverting to a sweep (resetProfile dropped, the veto only the Profiles page)
        assertTrue(row ~= nil and row.sessionOnly, "a profile-backed row walked: " .. path)
    end
    -- red under: the descriptor's resetProfile dropped (nothing empties the profile)
    assertEqual(NS2.db.profile.alpha, 1)
    assertFalse(NS2.DebugLog:IsShown())
    -- red under: a reset that empties every profile, not the active one
    assertEqual(NS2.db.sv.profiles.Raid.alpha, 0.3)
end)

--- Two session rows that answer "not at default", one on the Profiles page and one on General.
local function plantSessionRows(NS2)
    local calls = { profiles = 0, general = 0 }
    NS2.RegisterSchemaRows({
        { path = "state.profilesProbe", page = "profiles", group = "G", type = "bool", sessionOnly = true,
          default = false, get = function() return true end, set = function() calls.profiles = calls.profiles + 1 end },
        { path = "state.generalProbe", page = "general", group = "G", type = "bool", sessionOnly = true,
          default = false, get = function() return true end, set = function() calls.general = calls.general + 1 end },
    })
    return calls
end

test("options descriptor: Reset all never writes a Profiles-page row, live or degraded", function()
    local live = fresh()
    local calls = plantSessionRows(live)
    live.Helpers.RestoreAllDefaults()
    -- red under: vetoedFromResetAll losing its `page == "profiles"` clause
    assertEqual(calls.profiles, 0, "live")
    assertEqual(calls.general, 1, "live: a session row elsewhere is restored")

    local degraded = loadDegraded()
    rawset(_G, "AuraMasterDB", nil)
    degraded.addon:OnInitialize()
    calls = plantSessionRows(degraded)
    degraded.Helpers.RestoreAllDefaults()
    assertEqual(calls.profiles, 0, "degraded")
    assertEqual(calls.general, 1, "degraded: a session row elsewhere is restored")
end)

test("options descriptor: the degraded Reset all resets the profile whole and walks no profile-backed row", function()
    local NS2 = loadDegraded()
    rawset(_G, "AuraMasterDB", nil)
    NS2.addon:OnInitialize()
    local walked = { 0 }
    -- A hand-written profile row: the degraded build registers no composed one (options-ui-§1).
    local PATH = "hideBlizzardBuffs"
    NS2.FindSchemaRow(PATH).onChange = function() walked[1] = walked[1] + 1 end
    NS2.SetByPath(PATH, true)
    walked[1] = 0
    local resets = counter(NS2.db, "ResetProfile")
    NS2.Helpers.RestoreAllDefaults()
    -- red under: the stub's loop dropping the `not row.sessionOnly` veto (the row is written, then discarded)
    assertEqual(walked[1], 0)
    assertEqual(resets[1], 1)
    assertEqual(NS2.db.profile[PATH], false)
end)

-- ── the banner, the picker, the page renderer ─────────────────────────────────────────────────

test("options descriptor: the banner lists every container by name and ignores a re-pick of the selection", function()
    local NS2 = fresh()
    NS2.State.SetActiveContainer(2)
    NS2.Helpers.__pageCtx.bars.panel:__fire("OnShow")
    local dd = NS2.Helpers.__pageCtx.bars.__bannerWidget
    -- Player buffs, Player cooldowns, Player debuffs, Target debuffs (mine): by name (B2-2)
    assertEqual(table.concat(dd.order, ","), "1,4,2,3")
    assertEqual(dd.list[2], "Player debuffs  |cff888888(Player debuffs, icons)|r")
    assertEqual(dd.value, 2)
    local refreshes = counter(NS2.Helpers, "RefreshAllPanels")
    dd:__fire("OnValueChanged", 2)
    dd:__fire("OnValueChanged", nil)
    -- red under: the banner's onSelect without its `id == nil or id == activeId` guard
    assertEqual(refreshes[1], 0)
    dd:__fire("OnValueChanged", 3)
    assertEqual(NS2.State.activeContainerId, 3)
    assertEqual(refreshes[1], 1)
end)

test("options descriptor: Containers' picker sits in the chrome block above the strip and selects (feedback #2)", function()
    local NS2 = fresh()
    NS2.State.SetActiveContainer(1)
    NS2.Helpers.__pageCtx.containers.panel:__fire("OnShow")
    local ctx = NS2.Helpers.__pageCtx.containers
    local dd = ctx.__bannerWidget
    -- red under: the picker still drawn in the tab body (the retired options-ui-§14 deviation)
    assertTrue(dd ~= nil and dd.type == "Dropdown", "the band carries the picker")
    assertEqual(dd.labelText, "Container")
    assertTrue((ctx.__bannerHeight or 0) > 0, "and reserves the band above the strip")
    assertEqual(table.concat(dd.order, ","), "1,4,2,3", "by name (B2-2)")
    dd:__fire("OnValueChanged", 2)
    -- red under: the header's callback not reaching SelectContainer
    assertEqual(NS2.State.activeContainerId, 2)
end)

-- smoke batch 2, B2-2: every page's Container picker lists by name, case-insensitively, the id
-- breaking a tie (names differing only in case are refused by CM.UniqueName, so the tie is written
-- straight to the store), with the gray "(unit, style)" suffix kept.
test("options descriptor: every page's Container picker sorts by name, case-insensitively, the id breaking a tie (B2-2)", function()
    local NS2 = fresh()
    local cs = NS2.db.profile.containers
    cs[1].name, cs[2].name, cs[3].name, cs[4].name = "zeta", "Alpha", "beta", "ALPHA"
    NS2.State.SetActiveContainer(1)
    for _, page in ipairs({ "containers", "filters", "layout", "bars", "icons", "text" }) do
        local ctx = NS2.Helpers.__pageCtx[page]
        ctx.panel:__fire("OnShow")
        local dd = ctx.__bannerWidget
        -- red under: the picker in display order (1,2,3,4), or a byte sort (4,2,3,1: "ALPHA" < "Alpha")
        assertEqual(table.concat(dd.order, ","), "2,4,3,1", page)
        assertTrue(dd.list[2]:find("Alpha  |cff888888(", 1, true) == 1, page .. ": the gray suffix stays: " .. dd.list[2])
    end
    assertEqual(table.concat(NS2.db.profile.containerOrder, ","), "1,2,3,4", "the stored order untouched")
end)

test("options descriptor: a container page draws its intro, then the bespoke tabs its container's type admits", function()
    local NS2 = fresh()
    NS2.Helpers.__pageCtx.bars.panel:__fire("OnShow")
    local ctx = NS2.Helpers.__pageCtx.bars
    NS2.State.SetActiveContainer(2)                   -- a debuff container
    local intro, drawn = {}, {}
    local spec = {
        intro = function(_, cfg)
            intro[#intro + 1] = cfg.id
        end,
        tabs = {
            { key = "extra", label = "Extra", render = function(_, cfg)
                drawn[#drawn + 1] = cfg.id
            end },
            { key = "buffsOnly", label = "Buffs only", auraTypes = { HELPFUL = true }, render = function() end },
        },
    }
    NS2.Helpers.RenderContainerPage(ctx, "bars", spec)
    local keys = {}
    for _, t in ipairs(ctx.__tabs) do keys[t.key] = true end
    assertTrue(keys.extra)
    -- red under: collectTabs ignoring a bespoke tab's auraTypes
    assertNil(keys.buffsOnly)
    assertEqual(table.concat(intro, ","), "2", "the intro, with the selected container")
    clickTab(ctx, "extra")
    assertEqual(ctx.activeTab, "extra")
    assertEqual(table.concat(drawn, ","), "2", "the bespoke tab's render, with the container")
    -- The library's strip already ignores a click on the active tab, so the page's own guard is
    -- reached by calling the onSelect the page handed the strip.
    local onSelect
    local strip = NS2.Helpers.TabStrip
    NS2.Helpers.TabStrip = function(c, s, ...)
        onSelect = s.onSelect
        return strip(c, s, ...)
    end
    NS2.Helpers.RenderContainerPage(ctx, "bars", spec)
    local renders = table.concat(intro, ",")
    onSelect("extra")
    -- red under: the strip's onSelect without its `key == ctx.activeTab` guard (it re-renders)
    assertEqual(table.concat(intro, ","), renders, "selecting the active tab draws nothing")
    onSelect(ctx.__tabs[1].key)
    assertEqual(ctx.activeTab, ctx.__tabs[1].key, "another tab still switches")
end)

test("options descriptor: with no containers a page draws the one empty-registry line and no intro", function()
    local NS2 = fresh()
    NS2.Helpers.__pageCtx.bars.panel:__fire("OnShow")
    local ctx = NS2.Helpers.__pageCtx.bars
    deleteAll(NS2)
    local rows, introduced = {}, { 0 }
    local textRow = NS2.Helpers.TextRow
    NS2.Helpers.TextRow = function(c, text, ...)
        rows[#rows + 1] = text
        return textRow(c, text, ...)
    end
    NS2.Helpers.RenderContainerPage(ctx, "bars", { intro = function() introduced[1] = introduced[1] + 1 end })
    -- red under: renderActiveTab calling spec.intro with a nil cfg
    assertEqual(introduced[1], 0)
    assertEqual(table.concat(rows, "|"), "No containers yet. Create one on Containers, or type /am new.")
    assertEqual(ctx.__tabs[1].label, "Container", "the placeholder tab")
end)

test("options descriptor: a page disabled for its container hands the disable to a bespoke tab, and lets go after", function()
    local NS2 = fresh()
    NS2.Helpers.__pageCtx.bars.panel:__fire("OnShow")
    local ctx = NS2.Helpers.__pageCtx.bars
    local seen = {}
    local spec = { disabledFor = function() return true end,
        tabs = { { key = "extra", label = "Extra", render = function(c)
            seen[#seen + 1] = c.__renderDisabled
        end } } }
    ctx.activeTab = "extra"
    NS2.Helpers.RenderContainerPage(ctx, "bars", spec)
    -- red under: renderActiveTab rendering a bespoke tab outside the page's disable
    assertTrue(seen[1] == true)
    -- red under: the flag left on the ctx (every later render of the page drawn disabled)
    assertNil(ctx.__renderDisabled)
    spec.tabs[1].render = function() error("boom") end
    assertFalse(pcall(NS2.Helpers.RenderContainerPage, ctx, "bars", spec), "the raise still surfaces")
    -- red under: the flag restored only on the way out of a render that returned
    assertNil(ctx.__renderDisabled, "even when the tab raises")
end)

test("options descriptor: RenderTabbedPage draws no banner; RenderContainerPage is the banner plus it", function()
    local NS2 = fresh()
    NS2.Helpers.__pageCtx.bars.panel:__fire("OnShow")
    local ctx = NS2.Helpers.__pageCtx.bars
    assertTrue(ctx.__bannerWidget ~= nil, "a container page draws the banner")
    local strips = counter(NS2.Helpers, "TabStrip")
    NS2.Helpers.RenderTabbedPage(ctx, "bars", {})
    -- red under: RenderTabbedPage drawing the container banner (General would grow one, against D1)
    assertNil(ctx.__bannerWidget)
    assertEqual(strips[1], 1, "the strip is still drawn")
    NS2.Helpers.RenderContainerPage(ctx, "bars", {})
    assertTrue(ctx.__bannerWidget ~= nil, "and the container page draws it again")
end)

test("options descriptor: an addon-wide tabbed page draws every tab with no container, and a bespoke tab keyed by a group takes its place", function()
    local NS2 = fresh()
    NS2.Helpers.__pageCtx.containers.panel:__fire("OnShow")
    local ctx = NS2.Helpers.__pageCtx.containers
    deleteAll(NS2)
    local drawn = {}
    NS2.Helpers.RenderTabbedPage(ctx, "containers", {
        addonWide = true,
        tabs = { { key = "General", label = "General", render = function(_, cfg, rows)
            local list = rows or {}
            local count = #list
            drawn[#drawn + 1] = { cfg = cfg, rows = count }
        end } },
    })
    local keys = {}
    for i, t in ipairs(ctx.__tabs) do keys[i] = t.key end
    -- red under: collectTabs returning no tabs without a container, or adding the bespoke tab twice
    assertEqual(table.concat(keys, ","), "General")
    clickTab(ctx, "General")
    assertEqual(#drawn, 1, "the bespoke render replaced the group's rows")
    assertNil(drawn[1].cfg, "with no container")
    assertEqual(drawn[1].rows, 5, "and was handed the group's rows")
end)

test("options descriptor: a bespoke tab with `before` is drawn ahead of the tab it names, else last", function()
    local NS2 = fresh()
    NS2.Helpers.__pageCtx.bars.panel:__fire("OnShow")
    local ctx = NS2.Helpers.__pageCtx.bars
    local function strip(before)
        NS2.Helpers.RenderTabbedPage(ctx, "general", {
            addonWide = true,
            tabs = { { key = "Extra", label = "Extra", before = before, render = function() end } },
        })
        local keys = {}
        for i, t in ipairs(ctx.__tabs) do keys[i] = t.key end
        return table.concat(keys, ",")
    end
    -- red under: placeTab ignoring `before` (every bespoke tab appended after the schema groups)
    assertEqual(strip("Display"), "Master controls,Extra,Display,Spell Categories,Dispel Colors")
    -- red under: placeTab dropping a tab whose `before` names nothing this render draws
    assertEqual(strip("No such tab"), "Master controls,Display,Spell Categories,Dispel Colors,Extra")
    assertEqual(strip(nil), "Master controls,Display,Spell Categories,Dispel Colors,Extra")
end)

test("options descriptor: RenderWarnings draws one orange line per thing the engine will not do", function()
    local NS2 = fresh()
    NS2.Helpers.__pageCtx.bars.panel:__fire("OnShow")
    local ctx = NS2.Helpers.__pageCtx.bars
    local rows = {}
    NS2.Helpers.TextRow = function(_, text)
        rows[#rows + 1] = text
    end
    local CM, Database = NS2.ContainerManager, NS2.Database
    NS2.Helpers.RenderWarnings(ctx, Database.FindContainer(CM.Create({ auraType = "HARMFUL", unit = "player" })))
    assertEqual(#rows, 0, "a plain debuff container is fine")
    NS2.Helpers.RenderWarnings(ctx, Database.FindContainer(CM.Create({ auraType = "HARMFUL", unit = "player",
        filter = { durationMode = "timeless" } })))
    -- red under: RenderWarnings not wrapping the localized warning in the orange code
    assertEqual(table.concat(rows, "|"), "|cffffa040" .. NS2.FilterCompiler.WARN.TIMELESS_BUFFS_ONLY .. "|r")
end)

-- ── refresh and open ──────────────────────────────────────────────────────────────────────────

test("options descriptor: panel refreshes asked for in one frame are one refresh, on the next frame", function()
    local NS2, m = fresh()
    local refreshes = counter(NS2.Helpers, "RefreshAllPanels")
    NS2.RequestPanelRefresh()
    NS2.RequestPanelRefresh()
    NS2.RequestPanelRefresh()
    assertEqual(refreshes[1], 0, "never inside the caller's callback")
    m.__fireTimers()
    -- red under: RequestPanelRefresh without its refreshQueued latch
    assertEqual(refreshes[1], 1)
    NS2.bus:SendMessage(NS2.MSG.CONTAINERS_CHANGED)
    m.__fireTimers()
    assertTrue(refreshes[1] >= 2, "a registry change reaches it")
    NS2.RequestPanelRefresh()
    m.__fireTimers()
    assertTrue(refreshes[1] >= 3, "and the latch was released")
end)

test("options descriptor: OpenOptionsPage opens a registered page's category and falls back to the panel otherwise", function()
    local opened = {}
    local NS2 = fresh({ before = function(mk)
        local register = mk.Settings.RegisterCanvasLayoutSubcategory
        mk.Settings.RegisterCanvasLayoutSubcategory = function(parent, frame, name)
            local cat = register(parent, frame, name)
            cat.GetID = function() return "cat:" .. name end
            return cat
        end
        mk.Settings.OpenToCategory = function(id)
            opened[#opened + 1] = id
        end
    end })
    local panels = { 0 }
    NS2.Helpers.OpenOptionsPanel = function() panels[1] = panels[1] + 1 end
    NS2.OpenOptionsPage("layout")
    -- red under: NS.RegisterContainerPage not recording its category. The category is registered
    -- under Layout's MARKED tree label (D6, N-2: Layout is a sub-page of Containers) — the key the
    -- frame picker and OpenOptionsPage use is unaffected, only the label Blizzard's tree shows.
    assertEqual(table.concat(opened, ","), "cat:" .. NS2.SubPageLabel("Layout"))
    NS2.OpenOptionsPage("no such page")
    assertEqual(panels[1], 1, "an unknown page opens the panel")
    assertEqual(#opened, 1)
end)

-- ── the degradation stub's composers ──────────────────────────────────────────────────────────

test("options descriptor: every stub composer answers an empty row list", function()
    local NS2 = loadDegraded()
    local SPECS = {
        { "ColorPair", { prefix = "p.", key = "barColor", page = "bars", group = "G" } },
        { "FontGroup", { prefix = "p.text.", page = "bars", group = "G" } },
        { "BorderGroup", { prefix = "p.", page = "icons", group = "G", show = true,
                           extra = { { path = "p.extra", type = "bool" } } } },
        { "BarGroup", { prefix = "p.", page = "bars", group = "G" } },
        { "MasterControls", { prefix = "", page = "general", addonName = "Aura Master",
                              minimapPath = "global.minimap.shown", testModePath = "state.testMode" } },
    }
    for _, s in ipairs(SPECS) do
        local rows, tail = NS2.Helpers[s[1]](s[2])
        -- red under: a host copy of a composed block in the stub (anti-pattern #73, options-ui-§1)
        assertEqual(type(rows), "table", s[1])
        assertNil(next(rows), s[1] .. " answered rows")
        if s[1] == "MasterControls" then assertEqual(type(tail), "function", "MasterControls' tail") end
    end
end)
