-- tests/test_pages_rail.lua -- the Containers page as one page per container (#6): the section
-- registry, the band, the nav rail (General, Filters, Layout and the container's own style), the
-- selected section's tabs, deep links and Defaults, pinned from the outside.
-- Spec: docs/superpowers/specs/2026-09-26-settings-redesign-design.md.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local loadDegraded = dofile("tests/degraded_env.lua")

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
