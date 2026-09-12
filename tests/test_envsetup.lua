-- tests/test_envsetup.lua — core/EnvSetup.lua, the LibKa0s-Env seam: which manifest NS.Meta reads,
-- and what NS.Version answers, on both arms — the live load, and a real load without the library
-- (tests/degraded_env.lua), never a hand-written stub (testing-§8). The reader is planted on the
-- environment's own mock after the load, so the seam must look it up at call time.

local T = _G.AM_TEST
local test, assertEqual = T.test, T.assertEqual
local fresh = dofile("tests/fresh_env.lua")
local loadDegraded = dofile("tests/degraded_env.lua")

--- The two arms, each with its own mock.
local function arms()
    local live, lm = fresh()
    local degraded, dm = loadDegraded()
    return { { name = "live", NS = live, m = lm }, { name = "degraded", NS = degraded, m = dm } }
end

--- A TOC reader answering `fields[field]`, recording who asked for what.
local function reader(m, fields)
    local asked = {}
    m.C_AddOns = { GetAddOnMetadata = function(addon, field)
        asked[#asked + 1] = tostring(addon) .. "/" .. tostring(field)
        return fields[field]
    end }
    return asked
end

test("env: NS.Meta reads this addon's own manifest, by its folder name, on both arms", function()
    for _, arm in ipairs(arms()) do
        local asked = reader(arm.m, { Title = "Ka0s Aura Master" })
        assertEqual(arm.NS.Meta("Title"), "Ka0s Aura Master", arm.name)
        -- red under: EnvSetup handing the reader anything but the addonName vararg
        assertEqual(asked[1], "AuraMaster/Title", arm.name)
    end
end)

test("env: the version is the TOC's where it can be read, and the fallback constant where not", function()
    for _, arm in ipairs(arms()) do
        reader(arm.m, { Version = "2.3.4" })
        -- red under: NS.Version preferring core/Namespace.lua's constant to the packaged TOC
        assertEqual(arm.NS.Version(), "2.3.4", arm.name)
        reader(arm.m, {})
        assertEqual(arm.NS.Version(), arm.NS.version, arm.name .. ": no field, the constant")
    end
end)

test("env: an empty TOC version falls back like an absent one, on both arms", function()
    for _, arm in ipairs(arms()) do
        reader(arm.m, { Version = "" })
        -- red under: the degraded reader passing the TOC's empty string through as a version
        assertEqual(arm.NS.Version(), arm.NS.version, arm.name)
    end
end)

test("env: the version is never nil — '?' when neither the TOC nor the constant answers", function()
    for _, arm in ipairs(arms()) do
        arm.m.C_AddOns = nil
        arm.NS.version = nil
        -- red under: dropping the last `or "?"` rung (`/am version` would concatenate a nil)
        assertEqual(arm.NS.Version(), "?", arm.name)
    end
end)
