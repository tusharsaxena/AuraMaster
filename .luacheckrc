std = "lua51"
max_line_length = false
codes = true

-- libs/ holds vendored code, including libs/LibKa0s/ whose upstream is the LibKa0s repo, so it is
-- linted there and not here. tests/_kit/ is the same fact one level down: a byte copy of the
-- library's testkit/, linted in LibKa0s as source. The frozen audit, review and test bundles are
-- records, not source.
exclude_files = { "libs/", "tests/_kit/", "docs/audits/", "docs/reviews/", "docs/automated-tests/", "_dev/" }

-- The WoW client API this addon reads. Each entry is a name some authored file (core/, modules/,
-- settings/, defaults/, locales/ or the tests/ tree outside _kit/) reads as a global; a name nothing
-- reads comes off the list, and tests/test_lintconfig.lua holds it to that. The retired GetSpellInfo stays off: declaring it would let anti-pattern #10 lint clean.
read_globals = {
    "_G", "LibStub", "CreateFrame", "UIParent", "DEFAULT_CHAT_FRAME",
    "C_Timer", "C_AddOns",
    "GetTime", "InCombatLockdown", "UnitAffectingCombat", "UnitClass", "RAID_CLASS_COLORS",
    "UnitGUID", "time",   -- the user-category key generator's seed (defaults/UserCategories.lua)
    "IsMouseButtonDown", "GetCursorPosition",
    "Settings", "SettingsPanel", "StaticPopup_Show",
    "debugprofilestop",   -- the perf bracket's clock (performance-§2)
    "debugstack",         -- a failing styler's stack, kept for the error handler (modules/Style.lua)
    "geterrorhandler",    -- a failing container's apply is reported, not raised (modules/ContainerManager.lua)
    -- whether a container is predicted empty (modules/EmptyWatch.lua)
    "UnitExists", "UnitIsFriend", "GetWeaponEnchantInfo",
}

globals = {
    "AuraMasterDB",       -- the SavedVariables write target
    "AuraMasterPerfDB",   -- the diagnostics capture ring (performance-§5)
    "StaticPopupDialogs", -- Reset all, Delete container, Delete category and Forget unreadable
                          -- categories each register one
}

-- AceAddon calls its lifecycle and event handlers as METHODS (addon:OnEnable(), addon:OnEnterWorld
-- from RegisterEvent's method-name form), so they must keep the colon even where a body never reads
-- `self`. Narrowed to the one file that holds them, and to that one variable.
files["core/AuraMaster.lua"] = {
    ignore = { "212/self" },
}

-- The test tree is linted; only tests/_kit/ is out of scope. The harness global is declared here
-- rather than above, so the addon's own source cannot reach for it (lint).
files["tests/"] = {
    globals = { "AM_TEST" },
    read_globals = { "arg" },
}
