-- tests/test_poolsetup.lua — core/PoolSetup.lua, the LibKa0s-Pool seam behind the preview's
-- placeholders: the live seam is the library, and the fallback a library-absent load gets
-- (tests/degraded_env.lua) recycles exactly as the library does. A fallback that did not would leak
-- a frame per preview dress on one of the seam's two paths, which is the reason it exists.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local NS, mocks = T.NS, T.mocks
local loadDegraded = dofile("tests/degraded_env.lua")

local function pools()
    local degraded = loadDegraded()
    return { { name = "live", Pool = NS.Pool }, { name = "degraded", Pool = degraded.Pool } }
end

--- A placeholder factory that counts what it made.
local function factory()
    local made = {}
    return made, function()
        local f = mocks.__stubFrame()
        made[#made + 1] = f
        return f
    end
end

test("pool: the live seam is the library's own pool, not the fallback", function()
    -- red under: PoolSetup publishing its local table on a healthy install
    assertTrue(NS.Pool == mocks.LibStub("LibKa0s-Pool-1.0"))
end)

test("pool: the fallback carries every member the preview calls", function()
    -- members from: grep -rno "NS\.Pool[:.][A-Za-z]*" core/ modules/ settings/
    local MEMBERS = { "New", "Acquire", "ReleaseAll" }
    local missing = {}
    for _, arm in ipairs(pools()) do
        for _, k in ipairs(MEMBERS) do
            if type(arm.Pool[k]) ~= "function" then
                missing[#missing + 1] = arm.name .. "." .. k
            end
        end
    end
    -- red under: a member dropped from the fallback (the preview raises on a degraded install)
    assertEqual(#missing, 0, "missing: " .. table.concat(missing, ", "))
end)

test("pool: a released placeholder is reused rather than made again, on both arms", function()
    for _, arm in ipairs(pools()) do
        local Pool, name = arm.Pool, arm.name
        local made, make = factory()
        local pool = Pool.New()
        local a = Pool.Acquire(pool, make)
        Pool.Acquire(pool, make)
        assertEqual(#made, 2, name)
        assertTrue(a:IsShown(), name .. ": an acquired placeholder is shown")
        local hooked = 0
        Pool.ReleaseAll(pool, function() hooked = hooked + 1 end)
        assertEqual(hooked, 2, name .. ": the release hook ran for each")
        assertFalse(a:IsShown(), name .. ": a released placeholder is hidden")
        local free, active = Pool.Counts(pool)
        assertEqual(free, 2, name)
        assertEqual(active, 0, name)
        Pool.Acquire(pool, make)
        Pool.Acquire(pool, make)
        -- red under: the fallback's Acquire ignoring its free list (a frame leaked per dress)
        assertEqual(#made, 2, name .. ": nothing new was made")
    end
end)

test("pool: a re-dressed preview gets every placeholder back in the slot it held, on both arms", function()
    for _, arm in ipairs(pools()) do
        local Pool = arm.Pool
        local _, make = factory()
        local pool = Pool.New()
        local first = { Pool.Acquire(pool, make), Pool.Acquire(pool, make), Pool.Acquire(pool, make) }
        Pool.ReleaseAll(pool)
        -- red under: the fallback's ReleaseAll walking forward (every dress reshuffles the frames)
        for i = 1, 3 do
            assertTrue(Pool.Acquire(pool, make) == first[i], arm.name .. ": slot " .. i)
        end
    end
end)
