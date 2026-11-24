-- tests/test_sample_names.lua -- no sample person's name is typed outside tests/ (FB2-AM-01,
-- Ka0sAddonsCommonTasks docs/2026-11-24-FEEDBACK_BATCH, R2_SMOKE_FEEDBACK.md decision D1, LibKa0s#104;
-- WowAddonStandards v2.120.0 preview-mode, *Sample characters*, rule 6).
--
-- Every named sample person an addon draws (a test mode, a simulator, a preview, a showcase) comes
-- from LibKa0s-Sim-1.0: `Sim.Sample(client)` for the five protagonists and `Sim.SampleCrowd` for
-- everyone else. Aura Master draws no named person anywhere today: its test mode shows placeholder
-- auras, not players, and it has no simulator. This suite keeps it that way: a `Sample…` or
-- `Mock…` name literal in a shipped file or a living doc fails the run, so a list of the addon's own
-- cannot arrive unseen.
--
-- In scope: every tracked file but `libs/` and `tests/` (vendored copies and fixtures, which the rule
-- leaves out) and the frozen bundles (docs/audits, docs/reviews, docs/automated-tests,
-- docs/perf-analysis, docs/revendor, docs/superpowers), which record what was true when they were
-- written. A handful of ordinary English words that start the same way are allowed by name.

local T = _G.AM_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local SKIP_PREFIXES = { "libs/", "tests/", "docs/audits/", "docs/reviews/", "docs/automated-tests/",
                        "docs/perf-analysis/", "docs/revendor/", "docs/superpowers/" }
local BINARY = { tga = true, png = true, jpg = true, ttf = true, otf = true, blp = true, pdf = true,
                 ogg = true, mp3 = true, zip = true }
-- Ordinary words, not people.
local WORDS = { Sampled = true, Samples = true, Sampler = true, Sampling = true,
                Mocked = true, Mocking = true, Mocks = true, Mockup = true, Mockups = true }

--- The `Sample…`/`Mock…` name literals in `text`, in order, each as "line: word".
local function names(text)
    local out, n = {}, 0
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        n = n + 1
        for word in line:gmatch("%f[%a]([SM][ao][mc][pk]%a*)") do
            local named = (word:match("^Sample%l%l+$") or word:match("^Mock%l%l+$")) and not WORDS[word]
            if named then out[#out + 1] = n .. ": " .. word end
        end
    end
    return out
end

local function inScope(path)
    for _, prefix in ipairs(SKIP_PREFIXES) do
        if path:sub(1, #prefix) == prefix then return false end
    end
    local ext = path:match("%.(%w+)$")
    return not (ext and BINARY[ext:lower()])
end

--- Every tracked path in scope (git ls-files; tests run from the repo root).
local function files()
    local out, p = {}, io.popen("git ls-files 2>/dev/null")
    assertTrue(p ~= nil, "git ls-files runs")
    for line in p:lines() do
        if line ~= "" and inScope(line) then out[#out + 1] = line end
    end
    p:close()
    return out
end

test("sample names: the scan is falsifiable, a planted Sample or Mock person is caught", function()
    -- red under: a scan that finds nothing, so the guard below passes on any tree
    local hits = names('local POOL = { "Samplemist Mockwind", "Mockdawn" }\nreturn "Samplerealm"')
    assertEqual(table.concat(hits, ","), "1: Samplemist,1: Mockwind,1: Mockdawn,2: Samplerealm")
    assertEqual(#names("Sampled and Mockup are words; Sample, Mock and Samples are too"), 0)
end)

test("sample names: no Sample or Mock person literal lives outside tests/ (libs/ and frozen docs aside)", function()
    local list = files()
    assertTrue(#list > 20, "the tracked files were listed, got " .. #list)
    local bad = {}
    for _, path in ipairs(list) do
        local f = io.open(path, "rb")
        if f then
            local body = f:read("*a")
            f:close()
            for _, hit in ipairs(names(body)) do bad[#bad + 1] = path .. ":" .. hit end
        end
    end
    -- red under: a sample person typed into shipped code or a living doc instead of read from the
    -- library's Sim.Sample / Sim.SampleCrowd (anti-pattern #128)
    assertEqual(table.concat(bad, "; "), "", "every named sample person comes from LibKa0s-Sim-1.0")
end)
