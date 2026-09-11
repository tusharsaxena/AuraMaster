-- tests/test_surface_parity.lua — every degradation stub carries the whole live surface it stands
-- in for, minus the members named here with the reason (testing-§8).
--
-- The degraded half always comes from a real load without the library (tests/degraded_env.lua),
-- never from a hand-written table: a hand-stub asserts its author's typing, not the shipped file.
-- The live halves are the INSTANCES tests/run.lua registers with Kit.setSurfaceSource.

local T = _G.AM_TEST
local test, assertTrue = T.test, T.assertTrue
local NS = T.NS
local loadDegraded = dofile("tests/degraded_env.lua")

test("parity: the Core stub publishes everything core/CoreSetup.lua publishes live", function()
    -- Both halves are blocks of ONE file; what they share is a set of NS names, derived from the
    -- source so a publication added to the live half joins this case in the commit that adds it.
    local f = io.open("core/CoreSetup.lua", "r")
    local src = f:read("*a")
    f:close()
    local live, n = {}, 0
    for name in src:gmatch("\nNS%.([A-Za-z_]+)%s*=") do
        if NS[name] ~= nil then live[name] = NS[name]; n = n + 1 end
    end
    assertTrue(n >= 5, "the derivation found only " .. n .. " publications")
    T.assertSurfaceParity(live, loadDegraded(), "Core stub")
end)

test("parity: the DebugLog stub carries every member the addon calls", function()
    local NS2 = loadDegraded()
    T.assertSurfaceParity(NS2.DebugLog, "LibKa0s-DebugLog-1.0", {
        -- The formatters and text accessors are reached only inside the library's own Add; a copy
        -- of the line format in the stub is the duplicate testing-§8 forbids.
        "FormatPlain", "FormatColored", "CopyText", "Text",
        -- Stamped on the live instance when it builds its window; a library-less build has none.
        "_frameForTest", "_toggleClickForTest",
    })
end)

test("parity: the Options stub carries every helper a page file reaches at load", function()
    local NS2 = loadDegraded()
    T.assertSurfaceParity(NS2.Helpers, "LibKa0s-Options-1.0", {
        -- The load-completing stub (options-ui-§1) answers only what a page file touches at FILE
        -- LOAD — the composers, LSMValues, MASTER_GROUP — plus the recovery reset. Everything below
        -- is reached from a builder, a render or a click, and a library-less build draws no panel,
        -- so the stub answers NS.CreateOptionsPanel / NS.OpenOptionsPanel with one honest line
        -- instead of carrying a panel toolkit it could never use.
        "CreatePanel", "EnsureDefaultsButton", "EnsureScroll", "ClearScroll", "Section", "AddSpacer",
        "AttachTooltip", "InlineButtonPair", "RenderField", "RenderGrid", "RenderRows", "RenderSchema",
        "RenderTabbedSchema", "SessionCheckbox", "SetRenderer", "SetChromeHeight", "TabStrip",
        "SubTabStrip", "PageHeader", "PageBanner", "TextRow", "BuildLandingPage", "RefreshPanel",
        "PatchAlwaysShowScrollbar", "CreateOptionsPanel", "OpenOptionsPanel", "RegisterOptionsPage",
        -- lib.LAYOUT's scalars and the composer constants: read only inside a render or stamped onto
        -- rows by the live composers; a host copy is the copy that goes stale.
        "ROW_VSPACER", "SECTION_HEADING_H", "BUTTON_PAIR_REL", "PADDING_X", "CHROME_GAP", "TAB_H",
        "BANNER_H", "CLASS_COLOR_NOTE", "FONT_FLAGS", "FONT_FLAGS_SORT", "VISIBILITY_SORT",
        "VISIBILITY_VALUES", "AceGUI",
        -- This addon's own decorations on the live instance (settings/OptionsSetup.lua, About.lua):
        -- every one is a render-time helper for a panel the degraded build never draws.
        "SelectContainer", "ContainerBanner", "PlaceInHeader", "ContainerPickerWidget",
        "RenderWarnings", "RenderContainerPage", "BuildMainContent",
    })
end)

test("parity: the Slash stub carries every dispatcher member the addon calls", function()
    local NS2 = loadDegraded()
    assertTrue(type(NS.Slash.__cli) == "table" and type(NS2.Slash.__cli) == "table")
    T.assertSurfaceParity(NS2.Slash.__cli, "LibKa0s-Slash-1.0", {
        -- Live-only, with no call site here: `grep -n "cli[:.]" settings/Slash.lua` names what is
        -- called, and a stub member with no caller is a copy waiting to go stale.
        "HelpHeader", "HelpRows", "BuildListLines", "CliVersion", "CliResetAll", "Text",
    })
end)
