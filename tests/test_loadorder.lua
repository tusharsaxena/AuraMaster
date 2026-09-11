-- tests/test_loadorder.lua — the load lists cannot drift from the TOC (testing-§9), and the TOC's
-- load-bearing positions stay where they have to be.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local mocks, NS = T.mocks, T.NS
local Loader = dofile("tests/_kit/loader.lua")

local function readFile(path)
    local f = io.open(path, "r")
    assertTrue(f ~= nil, "cannot open " .. path)
    local s = f:read("*a")
    f:close()
    return s
end

local function indexOf()
    local index = {}
    for i, p in ipairs(Loader.tocFiles("AuraMaster.toc")) do index[p] = i end
    return index
end

test("loadorder: the TOC lists the locale first and the Profiles page last", function()
    local files = Loader.tocFiles("AuraMaster.toc")
    assertTrue(#files > 30)
    assertEqual(files[1], "locales/enUS.lua")
    assertEqual(files[#files], "settings/Profiles.lua")
end)

test("loadorder: every TOC path exists, and none is a library", function()
    for _, p in ipairs(Loader.tocFiles("AuraMaster.toc")) do
        local f = io.open(p, "r")
        assertTrue(f ~= nil, "the TOC names a missing file: " .. p)
        f:close()
        assertFalse(p:lower():match("^libs/"), p)
    end
end)

test("loadorder: the load-bearing pairs are in order, and the TOC says why", function()
    -- red under: moving any of the first files below the second.
    local index = indexOf()
    local pairs_ = {
        { "core/MediaSetup.lua", "core/Constants.lua" },
        { "core/Namespace.lua", "core/CoreSetup.lua" },
        { "core/CoreSetup.lua", "core/PerfSetup.lua" },
        { "core/PerfSetup.lua", "core/AuraMaster.lua" },
        { "core/Constants.lua", "core/DebugLogSetup.lua" },
        { "defaults/Categories.lua", "defaults/Profile.lua" },
        { "modules/Style.lua", "modules/Style_Bars.lua" },
        { "settings/Schema.lua", "settings/OptionsSetup.lua" },
        { "settings/OptionsSetup.lua", "settings/General.lua" },
    }
    for _, pr in ipairs(pairs_) do
        assertTrue(index[pr[1]] and index[pr[2]] and index[pr[1]] < index[pr[2]],
            pr[1] .. " must load before " .. pr[2])
    end
    assertTrue(readFile("AuraMaster.toc"):find("Constants.FONT_MONO is resolved from", 1, true) ~= nil,
        "the MediaSetup position carries its note")
end)

test("loadorder: the runner loaded exactly the TOC's files and the XML's library files", function()
    assertEqual(table.concat(T.loadedAddonFiles, "\n"), table.concat(Loader.tocFiles("AuraMaster.toc"), "\n"))
    assertEqual(table.concat(T.loadedLibFiles, "\n"),
        table.concat(Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml"), "\n"))
end)

test("loadorder: the offline perf runner and the degraded list derive from the TOC too", function()
    local perf = readFile("tests/perf.lua")
    assertTrue(perf:find("Loader.tocFiles", 1, true) ~= nil)
    assertTrue(perf:find("Loader.xmlFiles", 1, true) ~= nil)
    assertTrue(readFile("tests/degraded_env.lua"):find("Loader.tocFiles", 1, true) ~= nil)
    assertTrue(readFile("tests/fresh_env.lua"):find("Loader.tocFiles", 1, true) ~= nil)
end)

test("loadorder: the library registered — NS.Perf is the real probe, not the stub", function()
    local perf = mocks.LibStub("LibKa0s-Perf-1.0", true)
    assertTrue(perf ~= nil)
    assertEqual(type(NS.Perf.Start), "function", "the degradation stub has no Start")
    assertEqual(type(NS.Perf.BUCKET_ORDER), "table")
end)
