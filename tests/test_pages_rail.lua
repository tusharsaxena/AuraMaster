-- tests/test_pages_rail.lua -- the Containers page as one page per container (#6): the section
-- registry, the band, the nav rail (General, Filters, Layout and the container's own style), the
-- selected section's tabs, deep links and Defaults, pinned from the outside.
-- Spec: docs/superpowers/specs/2026-09-26-settings-redesign-design.md.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local loadDegraded = dofile("tests/degraded_env.lua")
local fresh = dofile("tests/fresh_env.lua")
local pages = dofile("tests/page_helpers.lua")

-- ── the registry ─────────────────────────────────────────────────────────────────────────────

test("sections: Filters, Layout, Bars, Icons and Text register as sections under their page keys", function()
    local NS = T.NS
    local LABELS = { filters = "Filters", layout = "Layout", bars = "Bars", icons = "Icons", text = "Text" }
    for key, label in pairs(LABELS) do
        local s = NS.ContainerSection(key)
        -- red under: a page file registering a Blizzard sub-page and no section
        assertTrue(s ~= nil, key .. " registered")
        assertEqual(s.key, key, key .. " keeps its page key: every row path is unchanged")
        assertEqual(s.label, NS.L[label], key .. "'s rail label")
        assertEqual(type(s.tooltip), "string", key .. " carries a rail tooltip")
    end
    assertEqual(NS.ContainerSection("bars").style, "bars")
    assertEqual(NS.ContainerSection("icons").style, "icons")
    assertEqual(NS.ContainerSection("text").style, "text")
    assertNil(NS.ContainerSection("filters").style, "Filters is every style's")
    assertNil(NS.ContainerSection("layout").style, "and Layout")
end)

-- Characterization: this case passes before and after SR-AM-02. It pins that the predicate
-- modules/Diagnostics.lua reads survives as data when the disabled notice goes (SR-AM-05).
test("sections: each style section's gate is derived from its style, on both builds (Diagnostics' inert split)", function()
    local function check(gates, build)
        for _, key in ipairs({ "bars", "icons", "text" }) do
            assertEqual(type(gates[key]), "function", build .. " " .. key)
            -- red under: the gate testing the style the wrong way round
            assertFalse(gates[key]({ style = key }), build .. " " .. key .. " is in use on its own style")
            assertTrue(gates[key]({ style = "nope" }), build .. " " .. key .. " is inert on another")
        end
        assertNil(gates.filters, build .. ": Filters is never inert by style")
        assertNil(gates.layout, build .. ": Layout neither")
    end
    check(T.NS.ContainerPageDisabledFor, "live")
    -- red under: the registry defined inside the live arm only (a library-absent /am diagnostics
    -- would call every Bars row on an icons container in use)
    check(loadDegraded().ContainerPageDisabledFor, "library-absent")
end)

-- ── the page ─────────────────────────────────────────────────────────────────────────────────

local function env()
    local NS, m = fresh()
    return NS, m, pages(NS, m)
end

local function railKeys(P, ctx)
    local out = {}
    for i, e in ipairs(P.drawnRail(ctx).entries) do out[i] = e.key end
    return table.concat(out, ",")
end

test("rail: Containers draws General, Filters, Layout and the selected container's own style, in that order", function()
    local NS, _, P = env()
    local ctx = NS.Helpers.__pageCtx.containers
    local L = NS.L
    NS.Helpers.SelectContainer(1)                   -- drawn as bars
    P.show("Containers")
    -- red under: the style entries filtered the wrong way round, or listed in TOC order
    assertEqual(railKeys(P, ctx), "containers,filters,layout,bars")
    local labels = {}
    for i, e in ipairs(P.drawnRail(ctx).entries) do labels[i] = e.label end
    assertEqual(table.concat(labels, ","), table.concat({ L["General"], L["Filters"], L["Layout"], L["Bars"] }, ","))
    NS.Helpers.SelectContainer(2)                   -- icons
    P.show("Containers")
    assertEqual(railKeys(P, ctx), "containers,filters,layout,icons")
    NS.Helpers.SelectContainer(4)                   -- text
    P.show("Containers")
    assertEqual(railKeys(P, ctx), "containers,filters,layout,text")
end)

test("rail: the page opens on General, today's one General tab under the band, beside a 120px rail", function()
    local NS, _, P = env()
    local ctx = NS.Helpers.__pageCtx.containers
    local ws = P.show("Containers")
    assertEqual(ctx.activeSection, "containers")
    assertEqual(P.drawnRail(ctx).value, "containers")
    assertEqual(table.concat(P.tabKeys("containers"), ","), NS.L["General"])
    assertTrue(P.find(ws, "Button", NS.L["New container"]) ~= nil, "the band keeps New container")
    assertEqual(ctx.railWidth, 120)
end)

test("rail: the draw order is PageBanner, NavRail, TabStrip", function()
    local NS, _, P = env()
    local H = NS.Helpers
    local order = {}
    for _, name in ipairs({ "PageBanner", "NavRail", "TabStrip" }) do
        local real = H[name]
        H[name] = function(...)
            order[#order + 1] = name
            return real(...)
        end
    end
    P.show("Containers")
    -- red under: the rail drawn before the banner (its top ignores the band) or after the strip
    -- (the strip places itself with no inset)
    assertEqual(table.concat(order, ","), "PageBanner,NavRail,TabStrip")
end)

test("rail: a rail click draws that section's strip and rows under the same band", function()
    local NS, _, P = env()
    local ctx = NS.Helpers.__pageCtx.containers
    NS.Helpers.SelectContainer(1)
    P.show("Containers")
    local ws = P.rail("layout")
    assertEqual(ctx.activeSection, "layout")
    assertEqual(P.drawnRail(ctx).value, "layout")
    local want, seen = {}, {}
    for _, row in ipairs(NS.SchemaForPage("layout")) do
        if not seen[row.group] then
            seen[row.group] = true
            want[#want + 1] = row.group
        end
    end
    -- red under: the section rendered under the Containers page key (General's rows, not Layout's)
    assertEqual(table.concat(P.tabKeys("containers"), ","), table.concat(want, ","))
    assertTrue(P.find(ws, "Dropdown", NS.L["Container"]) ~= nil, "the band is drawn with the section")
end)

test("rail: each section keeps its own tab: Filters, Categories, Layout, back to Filters lands on Categories (smoke 5)", function()
    local NS, _, P = env()
    local ctx = NS.Helpers.__pageCtx.containers
    local L = NS.L
    NS.Helpers.SelectContainer(1)
    P.show("Containers")
    P.rail("filters")
    P.tab("containers", L["Categories"])            -- the library's own strip click: no host render
    assertEqual(ctx.activeTab, L["Categories"])
    P.rail("layout")
    assertEqual(ctx.activeTab, P.tabKeys("containers")[1], "Layout opens on its first tab")
    P.tab("containers", L["Anchor"])
    P.rail("filters")
    -- red under: the tab kept only in the scalar ctx.activeTab (Filters reopens on its first tab),
    -- or stashed only on a host render (the strip click above never reaches the host)
    assertEqual(ctx.activeTab, L["Categories"])
    P.rail("layout")
    assertEqual(ctx.activeTab, L["Anchor"])
    P.rail("containers")
    P.rail("filters")
    assertEqual(ctx.activeTab, L["Categories"], "and through General too")
end)

test("rail: a Style change heals an active style section to the new style's entry; other sections stay (smoke 4)", function()
    local NS, _, P = env()
    local ctx = NS.Helpers.__pageCtx.containers
    NS.Helpers.SelectContainer(1)                   -- bars
    P.show("Containers")
    P.rail("bars")
    NS.SetByPath("container.style", "icons", 1)
    NS.Helpers.RefreshAllPanels()
    P.show("Containers")
    -- red under: the heal falling back to General, or keeping a section the rail no longer lists
    assertEqual(ctx.activeSection, "icons")
    assertEqual(railKeys(P, ctx), "containers,filters,layout,icons")
    P.rail("filters")
    NS.SetByPath("container.style", "text", 1)
    NS.Helpers.RefreshAllPanels()
    P.show("Containers")
    assertEqual(ctx.activeSection, "filters", "a section every style has is kept")
end)

test("rail: choosing a container of another style in the band moves Bars to Icons", function()
    local NS, _, P = env()
    local ctx = NS.Helpers.__pageCtx.containers
    NS.Helpers.SelectContainer(1)
    P.show("Containers")
    P.rail("bars")
    P.banner(ctx):__fire("OnValueChanged", 2)      -- the starter icon container
    P.show("Containers")
    assertEqual(ctx.activeSection, "icons")
    assertEqual(P.drawnRail(ctx).value, "icons")
end)

test("rail: with no containers the rail lists General alone, which says how to make one", function()
    local NS, _, P = env()
    local ctx = NS.Helpers.__pageCtx.containers
    for _, c in ipairs(NS.Database.GetContainers()) do NS.ContainerManager.Delete(c.id) end
    local ws = P.rerender("Containers")
    -- red under: a section that needs a container offered with none (an empty page under a strip)
    assertEqual(railKeys(P, ctx), "containers")
    assertTrue(P.hasText(ws, NS.L["No containers yet. Click New container, or type /am new."]))
end)
