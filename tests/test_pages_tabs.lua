-- tests/test_pages_tabs.lua — what every settings page's tabbed render draws, across the seven tabbed
-- pages (General, Containers, Filters, Layout, Bars, Icons, Text), pinned from the outside: the
-- strip's tab keys and labels in order, the active tab healing when a container switch takes it
-- away, the muted-red notice over disabled rows on a page the container's style does not use, the
-- Filters page's engine warnings above its rows, the empty registry's one placeholder tab and line,
-- and the Containers page's picker+create band.
--
-- Characterization (testing-§13), written against the host's own tab renderer before AM-17 moved
-- every page onto LibKa0s' O.RenderTabbedSchema and O.PageBanner (AuraMaster-R-04). Each case reads
-- only what a player sees -- the strip the library's TabStrip was handed, the widgets a render drew,
-- the band the chrome reserved -- so the same pins hold whoever draws the page.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")
local pages = dofile("tests/page_helpers.lua")

local function env()
    local NS, m = fresh()
    return NS, m, pages(NS, m)
end

--- `key=label` for every tab `ctx`'s last render drew, joined in strip order.
local function strip(P, ctx)
    local out = {}
    for i, t in ipairs(P.drawnTabs(ctx)) do out[i] = tostring(t.key) .. "=" .. tostring(t.label) end
    return table.concat(out, " | ")
end

--- Where `w` sits in `ws`, or nil.
local function indexOf(ws, w)
    for i, x in ipairs(ws) do
        if x == w then return i end
    end
    return nil
end

--- The first Label in `ws` whose text is `text`.
local function label(ws, text)
    for _, w in ipairs(ws) do
        if w.type == "Label" and w.text == text then return w end
    end
    return nil
end

-- The seven pages by display name and key, and the strip each draws for container 1 (buffs, bars).
local STRIPS = {
    { "General",    "general",    "Master controls=Master controls | Display=Display | Spell Categories=Spell Categories | Dispel Colors=Dispel Colors" },
    { "Containers", "containers", "General=General" },
    { "Filters",    "filters",    "General=General | Categories=Categories | overrides=Overrides | Sorting=Sorting" },
    { "Layout",     "layout",     "Frame=Frame | Anchor=Anchor | Growth=Growth | Mouse=Mouse | Name label=Name label" },
    { "Bars",       "bars",       "General=General | Background & border=Background & border | Name text=Name text | Time text=Time text | Stack text=Stack text | Icon=Icon | Pandemic=Pandemic" },
    { "Icons",      "icons",      "Size=Size | Border=Border | Cooldown=Cooldown | Time text=Time text | Stack text=Stack text | Pandemic=Pandemic" },
    { "Text",       "text",       "General=General | Font=Font | Icon=Icon | Pandemic=Pandemic | Animation=Animation" },
}

test("tabs: each of the seven pages draws its tab keys and labels in order", function()
    local NS, _, P = env()
    for _, id in ipairs({ 1, 2 }) do
        NS.Helpers.SelectContainer(id)
        for _, page in ipairs(STRIPS) do
            P.rerender(page[1])
            -- red under: a group tab dropped or reordered, a host tab not taking its group's place,
            -- or Overrides not placed ahead of Sorting
            assertEqual(strip(P, NS.Helpers.__pageCtx[page[2]]), page[3], page[2] .. " on container " .. id)
        end
    end
end)

test("tabs: a container switch that takes the active tab away heals the strip to its first tab", function()
    local NS, _, P = env()
    -- An aura type this build does not know (planted: no write can store one) admits neither
    -- Categories nor Overrides, nor the General group's buff/debuff rows.
    NS.Database.FindContainer(3).auraType = "BOGUS"
    NS.Helpers.SelectContainer(1)
    P.show("Filters")
    P.tab("filters", "overrides")
    local ctx = NS.Helpers.__pageCtx.filters
    assertEqual(ctx.activeTab, "overrides")
    NS.Helpers.SelectContainer(3)
    P.show("Filters")
    -- red under: the render keeping a pointer at a tab it no longer draws (an empty page under a strip)
    assertEqual(strip(P, ctx), "Sorting=Sorting", "the strip without Categories and Overrides")
    assertEqual(ctx.activeTab, "Sorting", "healed to the first tab drawn")
end)

-- The notice each page draws on a container its style does not use, in the addon's muted red.
local NOTICES = {
    { "Bars",  "bars",  2, "Not in use: this container is drawn as icons. Set its Style to Bars on the Containers page to use these settings." },
    { "Icons", "icons", 1, "Not in use: this container is drawn as bars. Set its Style to Icons on the Containers page to use these settings." },
    { "Text",  "text",  2, "Not in use: this container is drawn as icons. Set its Style to Text on the Containers page to use these settings." },
}

test("tabs: Bars, Icons and Text on a mismatched style draw the muted-red notice above every row, drawn disabled", function()
    local NS, _, P = env()
    local color = "|c" .. NS.Constants.NOTICE_COLOR
    for _, n in ipairs(NOTICES) do
        NS.Helpers.SelectContainer(n[3])
        P.eachTab(n[1], n[2], function(key, ws)
            local note = label(ws, color .. NS.L[n[4]] .. "|r")
            -- red under: the page dropping disabledNotice, or drawing it without the muted red
            assertTrue(note ~= nil, n[2] .. "/" .. key .. " drew the notice")
            local rows = P.rowWidgets(ws, n[2], key)
            for _, w in ipairs(rows) do
                -- red under: the notice replacing the rows, or drawn under them
                assertTrue(indexOf(ws, note) < indexOf(ws, w), n[2] .. "/" .. key .. ": the notice first")
                -- red under: disabledFor not reaching the rows
                assertTrue(w.disabled, n[2] .. "/" .. key .. ": " .. tostring(w.labelText))
            end
        end)
    end
end)

test("tabs: the Filters page draws the engine's warnings above the tab's rows", function()
    local NS, _, P = env()
    local warning = "|cffffa040" .. NS.L[NS.FilterCompiler.WARN.TIMELESS_BUFFS_ONLY] .. "|r"
    NS.Helpers.SelectContainer(1)
    NS.SetByPath("container.auraType", "HARMFUL", 1)
    NS.SetByPath("container.filter.durationMode", "timeless", 1)
    local ws = P.rerender("Filters")
    local line = label(ws, warning)
    assertTrue(line ~= nil, "the warning is drawn")
    local rows = P.rowWidgets(ws, "filters", P.tabKeys("filters")[1])
    assertTrue(rows[1] ~= nil, "the first tab drew its rows")
    -- red under: the intro drawn after the rows, or not at all
    assertTrue(indexOf(ws, line) < indexOf(ws, rows[1]), "the warning above the first row")
end)

test("tabs: with no containers every per-container page draws one placeholder tab and the empty-registry line", function()
    local NS, _, P = env()
    for _, c in ipairs(NS.Database.GetContainers()) do NS.ContainerManager.Delete(c.id) end
    for _, page in ipairs(STRIPS) do
        local ws = P.rerender(page[1])
        local drawn = strip(P, NS.Helpers.__pageCtx[page[2]])
        if page[2] == "general" then
            -- red under: an addon-wide page losing its tabs with the registry
            assertEqual(drawn, page[3], "General keeps its tabs")
        elseif page[2] == "containers" then
            assertEqual(drawn, page[3], "Containers keeps its one tab")
            assertTrue(P.hasText(ws, NS.L["No containers yet. Click New container, or type /am new."]), "and says how to make one")
        else
            -- red under: a per-container page drawing no strip (options-ui-§13), or its groups' tabs
            assertEqual(drawn, "__empty=" .. NS.L["Container"], page[2])
            assertTrue(P.hasText(ws, NS.L["No containers yet. Create one on Containers, or type /am new."]), page[2] .. "'s line")
        end
    end
end)

test("tabs: the Containers page's band holds the picker and New container, out of the tab body", function()
    local NS, _, P = env()
    local ws = P.rerender("Containers")
    local ctx = NS.Helpers.__pageCtx.containers
    local picker = P.find(ws, "Dropdown", NS.L["Container"])
    local new = P.find(ws, "Button", NS.L["New container"])
    -- red under: the band drawing only one of the pair
    assertTrue(picker ~= nil and new ~= nil, "both drawn")
    assertTrue((ctx.__bannerHeight or 0) > 0, "the band reserved above the strip")
    local function inScroll(w)
        local function walk(node)
            for _, c in ipairs(node.children or {}) do
                if c == w or walk(c) then return true end
            end
            return false
        end
        return walk(NS.Helpers.EnsureScroll(ctx))
    end
    -- red under: the pair drawn in the tab body (the retired options-ui-§14 deviation)
    assertFalse(inScroll(picker) or inScroll(new), "neither in the tab body")
    assertEqual(table.concat(picker.order, ","), "1,4,2,3", "the picker lists every container by name")
end)

--- Make every widget's ReleaseChildren give its children back to AceGUI, as the real AceGUI's does.
--- The kit's fake forgets them instead (tests/_kit/mock_base.lua says why), so without this every
--- row a re-render clears would read as live and hide the chrome's own count under the rows'.
local function releasingChildren(m)
    local ace = m.LibStub("AceGUI-3.0")
    local create = ace.Create
    function ace:Create(wtype, ...)
        local w = create(self, wtype, ...)
        rawset(w, "ReleaseChildren", function(node)
            local kids = node.children or {}
            node.children = {}
            for _, c in ipairs(kids) do
                if not c.__released then ace:Release(c) end
            end
        end)
        return w
    end
end

test("tabs: re-rendering Filters and Containers ten times each leaves the live Dropdown and Button counts flat", function()
    local _, m, P = env()
    releasingChildren(m)
    for _, page in ipairs({ "Filters", "Containers" }) do
        -- Two renders first, so the widgets the environment drew before the patch are all given back.
        P.rerender(page)
        P.rerender(page)
        local dropdowns, buttons = m.__aceguiLive("Dropdown"), m.__aceguiLive("Button")
        for _ = 1, 10 do P.rerender(page) end
        -- red under: the host clearing ctx.__bannerWidget, or any banner or band widget minted per
        -- render and never released (one more Dropdown, or Button, per render)
        assertEqual(m.__aceguiLive("Dropdown"), dropdowns, page .. ": live Dropdowns")
        assertEqual(m.__aceguiLive("Button"), buttons, page .. ": live Buttons")
    end
end)
