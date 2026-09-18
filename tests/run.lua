-- Headless test runner for Ka0s Aura Master.
-- Run from the repo root:  lua tests/run.lua        (add --list for the case inventory)
--
-- The registry, the assertions, the source loader and the universal WoW-API mock live in the shared
-- kit under tests/_kit/ (vendored from the LibKa0s repo's testkit/). What stays here is what is this
-- addon's: the load list, the lifecycle kick, and the suite list.

local Kit        = dofile("tests/_kit/framework.lua")
local Loader     = dofile("tests/_kit/loader.lua")
local buildMocks = dofile("tests/wow_mock.lua")

local mocks = buildMocks()
local NS = {}

Loader.addonName = "AuraMaster"

-- The vendored library files, which the TOC reaches through libs\LibKa0s\LibKa0s.xml and so are
-- invisible to Loader.tocFiles. Derived from that XML: a hand-kept list short by one file does not
-- raise — the module never registers, its degradation stub takes over, and the suite measures the
-- stub (testing-§9).
local LIB_FILES = Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml")

-- The addon's own files come from the TOC, so this runner cannot drift from what the client loads.
local ADDON_FILES = Loader.tocFiles("AuraMaster.toc")

Loader.loadAll(LIB_FILES, NS, mocks)
Loader.loadAll(ADDON_FILES, NS, mocks)

-- Mirror the in-game lifecycle: OnInitialize (the database, the slash command), then OnEnable at
-- PLAYER_LOGIN (the containers, Blizzard's frames, the settings panel), then the coalesced first
-- apply the next frame would run.
NS.addon:OnInitialize()
NS.addon:OnEnable()
mocks.__fireTimers()

-- The live halves the degradation stubs are compared against: INSTANCES, not library tables, so
-- registered by name before Kit.expose would auto-wire the wrong thing.
Kit.setSurfaceSource{
    ["LibKa0s-Options-1.0"]  = NS.Helpers,
    ["LibKa0s-DebugLog-1.0"] = NS.DebugLog,
    ["LibKa0s-Slash-1.0"]    = NS.Slash and NS.Slash.__cli,
    ["LibKa0s-Launcher-1.0"] = NS.Launcher,
}

AM_TEST = Kit.expose{
    NS = NS, mocks = mocks,
    loadedAddonFiles = ADDON_FILES,
    loadedLibFiles   = LIB_FILES,
}

-- Suites, in load-order-sensitive order. `dir` is explicit, so Kit.run asserts the inventory: a
-- tests/test_*.lua on disk but missing here, or listed but absent, takes the run down.
Kit.run{
    dir = "tests/",
    suites = {
        "test_loadorder",
        "test_setups",
        "test_launcher",
        "test_database",
        "test_schema",
        "test_schema_paths",
        "test_filtercompiler",
        "test_container",
        "test_containermanager",
        "test_compat",
        "test_secrets",
        "test_bus",
        "test_state",
        "test_lifecycle",
        "test_anchors",
        "test_texttemplate",
        "test_style",
        "test_timedspells",
        "test_style_bars",
        "test_style_icons",
        "test_preview",
        "test_render_coverage",
        "test_blizzardframes",
        "test_framepicker",
        "test_disabled",
        "test_slash",
        "test_slash_verbs",
        "test_bulklog",
        "test_optionssetup",
        "test_options_descriptor",
        "test_pages_general",
        "test_pages_containers",
        "test_pages_filters",
        "test_pages_layout",
        "test_pages_bars",
        "test_pages_icons",
        "test_pages_about",
        "test_pages_profiles",
        "test_envsetup",
        "test_poolsetup",
        "test_defaults",
        "test_perf",
        "test_debuglogsetup",
        "test_locale",
        "test_docs",
        "test_surface_parity",
        "test_vendor_sync",
        "test_lintconfig",
        { name = "test_eol", dir = "tests/_kit/" },
    },
}
