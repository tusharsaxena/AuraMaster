-- tests/test_migrations.lua — core/Database.lua's NS.RunMigrations against savedvariables-§1 at
-- WowAddonStandards v2.65.0: the defaults declare `schemaVersion = 0`, the runner owns the stamp
-- and advances it only past a step that returned without raising, every stored profile is
-- migrated, and every step is idempotent against a fresh default profile.
--
-- Its own suite rather than more cases in tests/test_database.lua, which is already over
-- layout-§1's 1500-line cap (issue #17): the census row says the next change that grows that file
-- carries the peel, and a migration-runner suite is a seam of its own.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertNil
local fresh = dofile("tests/fresh_env.lua")

--- Structural equality over plain data, answering the first differing path (nil when equal).
local function diff(a, b, path)
    path = path or "profile"
    if type(a) ~= "table" or type(b) ~= "table" then
        if a ~= b then return path .. ": " .. tostring(a) .. " ~= " .. tostring(b) end
        return nil
    end
    for k, v in pairs(a) do
        local d = diff(v, b[k], path .. "." .. tostring(k))
        if d then return d end
    end
    for k in pairs(b) do
        if a[k] == nil then return path .. "." .. tostring(k) .. ": missing on the left" end
    end
    return nil
end

--- AceDB-3.0's removeDefaults (the scalar and plain-table arms), which the client runs over every
--- section at PLAYER_LOGOUT: a stored value equal to its default is not written to the file. The
--- kit's fake runs it over the outgoing profile on SetProfile only, so a logout is modeled here.
local function logoutStrip(dest, src)
    for k, v in pairs(src or {}) do
        if type(v) == "table" and type(dest[k]) == "table" then
            logoutStrip(dest[k], v)
            if next(dest[k]) == nil then dest[k] = nil end
        elseif dest[k] == v then
            dest[k] = nil
        end
    end
end

--- A profile in the shape schema v1 shipped: one bars container on the retired MEDIUM strata that
--- v2 lifts to HIGH, with its spell list and dispel color still on the container.
local function v1profile()
    return {
        seeded = true, nextContainerId = 5, containerOrder = { 4 },
        containers = { [4] = {
            name = "Mine", unit = "player", auraType = "HELPFUL", style = "bars",
            filter = { categories = { lesserHealing = "hide" }, categorySpells = { defensives = { [111] = true } } },
            bars = { colorMode = "dispel", dispelColors = { Magic = { r = 0.3, g = 0, b = 0, a = 1 } } },
            layout = { strata = "MEDIUM" },
        } },
    }
end

--- Collect the [Migrate] step lines ("v2 -> v3") into `into`.
local function captureSteps(NS, into)
    NS.Debug = function(tag, fmt, ...)
        if tag == "Migrate" then
            local line = fmt:format(...)
            if line:match("^v%d+ %-> v%d+$") then into[#into + 1] = line end
        end
    end
end

test("migrations: NS.SCHEMA_VERSION is the runner's target, the last step's version", function()
    local NS = fresh()
    -- red under: no named target (savedvariables-§1 v2.65.0 names NS.SCHEMA_VERSION)
    assertEqual(NS.SCHEMA_VERSION, NS.Database.CurrentSchemaVersion())
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
end)

test("migrations: a legacy v1 account with NO stamp runs every step", function()
    local NS = fresh({ savedVariables = { profiles = { Default = v1profile() } } })
    -- A v1 file predates the stamp, so the global section is absent. AceDB backfills the declared
    -- default before NS.RunMigrations reads it: 0 now, 1 before, and either climbs the whole ladder,
    -- which is why this case pairs with the logout case below rather than standing alone.
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
    local p = NS.db.sv.profiles.Default
    assertEqual(p.containers[4].layout.strata, "HIGH", "v2 ran")
    assertEqual(p.categorySpells.defensives[111], true, "v2 lifted the spell list")
    assertEqual(type(p.userCategories), "table", "v6 ran")
end)

test("migrations: a stored stamp survives the logout strip, so the next build's step runs", function()
    local NS = fresh()
    local sv = _G.AuraMasterDB
    logoutStrip(sv.global, NS.defaults.global)
    -- red under: default = the current version (6). AceDB's removeDefaults drops a stored 6 equal
    -- to a default 6, the file holds no stamp, and the next build's default (7, when a step is
    -- added) backfills over it, so step 7 never runs for any existing player (WhatGroup F-003).
    -- Under the old default of 1 this held only because a real store never sat at 1 after load.
    assertEqual(sv.global.schemaVersion, NS.SCHEMA_VERSION, "the stamp is in the file")
    local steps = {}
    local NS2 = fresh({
        savedVariables = sv,
        before = function() end,
    })
    captureSteps(NS2, steps)
    NS2.RunMigrations()
    assertEqual(NS2.db.global.schemaVersion, NS2.SCHEMA_VERSION)
    assertEqual(#steps, 0, "nothing re-runs: " .. table.concat(steps, " | "))
end)

test("migrations: every step is idempotent on a fresh default profile", function()
    local NS = fresh()
    -- The profile a fresh install's ladder sees: AceDB's defaults and nothing else. The starter
    -- containers are not in it, because Database.PrepareProfile seeds them AFTER the ladder. Parked
    -- as the only stored profile, so the ladder walks it and PrepareProfile (active profile only)
    -- does not seed it.
    local freshProfile = NS.Database.DeepCopy(NS.defaults.profile)
    NS.db.sv.profiles = { Fresh = freshProfile }
    local before = NS.Database.DeepCopy(freshProfile)
    local printed = {}
    NS.Print = function(...) printed[#printed + 1] = table.concat({ ... }, " ") end
    for _ = 1, 2 do
        NS.db.global.schemaVersion = 0
        NS.RunMigrations()
        assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
        -- red under: any step writing to a fresh profile (a fresh install runs the whole ladder)
        assertNil(diff(freshProfile, before))
    end
    assertEqual(#printed, 0, "a fresh profile prints no migration notice: " .. table.concat(printed, " | "))
end)

test("migrations: a step that raises leaves the stamp where it was and the addon loads", function()
    local NS = fresh()
    local printed, steps = {}, {}
    NS.Printf = function(fmt, ...) printed[#printed + 1] = fmt:format(...) end
    captureSteps(NS, steps)
    local real = NS.Database.MigrateV4
    NS.Database.MigrateV4 = function() error("boom") end
    NS.db.global.schemaVersion = 3
    -- red under: stamping without pcall (the error escapes InitDB, OnInitialize dies, no NS.db)
    local ok, err = pcall(NS.RunMigrations)
    assertTrue(ok, tostring(err))
    assertEqual(NS.db.global.schemaVersion, 3, "the stamp stays at the last completed step")
    assertEqual(#printed, 1, table.concat(printed, " | "))
    assertTrue(printed[1]:find("migration to schema v4 failed", 1, true) ~= nil, printed[1])
    assertTrue(printed[1]:find("boom", 1, true) ~= nil, "the error is named")
    assertEqual(#steps, 0, "no step after the failure ran")
    assertTrue(NS.db ~= nil and NS.db.profile ~= nil)
    assertTrue(#NS.Database.GetContainers() > 0, "the rest of the load still ran")
    -- The next load retries from where it stopped.
    NS.Database.MigrateV4 = real
    NS.RunMigrations()
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
end)

test("migrations: an inactive profile is migrated too", function()
    local function v5()
        return { seeded = true, nextContainerId = 2, containerOrder = { 1 },
            containers = { [1] = { name = "One", unit = "player", auraType = "HELPFUL", style = "icons" } } }
    end
    local NS = fresh({ savedVariables = { profiles = { Default = v5(), Raid = v5() }, global = { schemaVersion = 5 } } })
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
    -- red under: a profile step gated to NS.db.profile (Raid is never activated in this load)
    for _, name in ipairs({ "Default", "Raid" }) do
        assertEqual(type(NS.db.sv.profiles[name].userCategories), "table", name)
    end
end)
