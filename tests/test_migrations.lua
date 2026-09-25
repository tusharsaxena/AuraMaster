-- tests/test_migrations.lua — core/Database.lua's NS.RunMigrations against savedvariables-§1 at
-- WowAddonStandards v2.65.0: the defaults declare `schemaVersion = 0`, the runner owns the stamp
-- and advances it only past a step that returned without raising, every stored profile is
-- migrated, and every step is idempotent against a fresh default profile.
--
-- Its own suite rather than more cases in tests/test_database.lua: a migration-runner suite is a
-- seam of its own, and that file has already had its user-category cases peeled out to stay under
-- layout-§1's 1500-line cap (issue #17).

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
            if line:match("^v%d+ %-> v%d+$") then
                local n = #into
                into[n + 1] = line
            end
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
    NS.Print = function(...)
        local n = #printed
        printed[n + 1] = table.concat({ ... }, " ")
    end
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
    NS.Printf = function(fmt, ...)
        local n = #printed
        printed[n + 1] = fmt:format(...)
    end
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

-- ── v8 (batch 8 SS-2): the old 0/-4 attach offset on a container attached to another ──────────

--- A profile at v7 whose containers carry every attach shape v8 has to tell apart.
local function v7profile()
    local function c(name, attach)
        return { name = name, unit = "player", auraType = "HELPFUL", style = "bars", attach = attach }
    end
    return {
        seeded = true, nextContainerId = 8, containerOrder = { 1, 2, 3, 4, 5, 6, 7 },
        userCategories = {}, userCategoryOrder = {},
        containers = {
            [1] = c("Parent", { mode = "screen", container = 0, x = 0, y = -4 }),
            [2] = c("Old default", { mode = "container", container = 1, x = 0, y = -4 }),
            [3] = c("Own nudge", { mode = "container", container = 1, x = 3, y = -4 }),
            [4] = c("Own drop", { mode = "container", container = 1, x = 0, y = -9 }),
            [5] = c("Named frame", { mode = "frame", frame = "PlayerFrame", x = 0, y = -4 }),
            [6] = c("Unstored", { mode = "container", container = 1 }),
            [7] = c("No attach", nil),
        },
    }
end

test("migrations: v8 zeroes the old 0/-4 offset on a container attached to another, and nothing else", function()
    local NS = fresh()
    local p = v7profile()
    -- red under: no MigrateV8 (the step that carries SS-2's reset)
    assertEqual(NS.Database.MigrateV8(p), 2)
    local at = function(id) return p.containers[id].attach end
    assertEqual(at(2).x, 0); assertEqual(at(2).y, 0, "the old default: reset")
    -- An absent offset is the template's, which was 0/-4 when it was stored (the backfill after the
    -- ladder would otherwise hand it the new template's 0/0 without the step saying so).
    assertEqual(at(6).x, 0); assertEqual(at(6).y, 0, "absent: the old default, reset")
    -- red under: resetting any container-mode offset (a value the player chose is theirs)
    assertEqual(at(3).x, 3); assertEqual(at(3).y, -4, "a nudge of the player's own")
    assertEqual(at(4).y, -9, "a drop of the player's own")
    -- red under: resetting outside container mode (a named frame still reads the offset as its gap)
    assertEqual(at(5).y, -4, "a named frame keeps it")
    assertEqual(at(1).y, -4, "a screen container keeps it")
    assertNil(p.containers[7].attach, "no attach table: nothing created")
    local before = NS.Database.DeepCopy(p)
    assertEqual(NS.Database.MigrateV8(p), 0, "a second run resets nothing")
    assertNil(diff(p, before))
end)

test("migrations: a v7 account climbs to v8 in every profile", function()
    local NS = fresh({ savedVariables = { profiles = { Default = v7profile(), Raid = v7profile() },
        global = { schemaVersion = 7 } } })
    -- red under: the v8 row missing from SCHEMA_STEPS
    assertEqual(NS.SCHEMA_VERSION, NS.Database.CurrentSchemaVersion())
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
    for _, name in ipairs({ "Default", "Raid" }) do
        local cs = NS.db.sv.profiles[name].containers
        -- red under: the step touching the active profile only
        assertEqual(cs[2].attach.y, 0, name)
        assertEqual(cs[5].attach.y, -4, name)
    end
end)

test("migrations: a new container's attach offset is 0/0", function()
    local NS = fresh()
    -- red under: the template still carrying the old 0/-4 (every new chain would start 4px apart)
    assertEqual(NS.CONTAINER_TEMPLATE.attach.x, 0)
    assertEqual(NS.CONTAINER_TEMPLATE.attach.y, 0)
end)

-- ── v8 (batch 8 AS-3, D7; batch 9 E6): Size to fit stamped off on every existing Text container ─

--- Size to fit as stored: nil when there is no text block (an inactive profile is not backfilled).
local function fitOf(c)
    return type(c.text) == "table" and c.text.autoSize or nil
end

--- v7profile with styles mixed: #2 and #3 are Text, #5 is Icons, the rest stay Bars.
local function v7mixed()
    local p = v7profile()
    p.containers[2].style = "text"
    p.containers[3].style = "text"
    p.containers[5].style = "icons"
    return p
end

test("migrations: v8 stamps Size to fit off on every stored Text container only, and keeps a stored value", function()
    local NS = fresh()
    local p = v7mixed()
    p.containers[2].text = { width = 180 }
    p.containers[3].text = "junk"
    p.containers[4].style = "text"
    p.containers[4].text = { autoSize = true }
    p.containers[1].text = { width = 90 }
    local reset, stamped = NS.Database.MigrateV8(p)
    assertEqual(reset, 2, "the seam reset still counts first")
    -- red under: the style-blind stamp (E6: Size to fit is Text-only, so a bars or icons container
    -- carries no value of its own)
    assertEqual(stamped, 2)
    assertEqual(p.containers[2].text.autoSize, false, "a text container: stamped off")
    assertEqual(p.containers[3].text.autoSize, false, "a junk text block: recreated and stamped")
    assertEqual(p.containers[4].text.autoSize, true, "a stored value is the player's own")
    assertNil(p.containers[1].text.autoSize, "a bars container: not stamped")
    assertEqual(p.containers[1].text.width, 90, "a bars container's text block untouched")
    for _, id in ipairs({ 5, 6, 7 }) do
        assertNil(p.containers[id].text, "container " .. id .. ": no text block created")
    end
    assertEqual(p.containers[2].text.width, 180, "the rest of the block kept")
    local before = NS.Database.DeepCopy(p)
    local _, again = NS.Database.MigrateV8(p)
    assertEqual(again, 0, "a second run stamps nothing")
    assertNil(diff(p, before))
end)

test("migrations: a v7 account keeps its hand-set text size; a fresh install's starters fit their content", function()
    local NS = fresh({ savedVariables = { profiles = { Default = v7mixed(), Raid = v7mixed() },
        global = { schemaVersion = 7 } } })
    for _, name in ipairs({ "Default", "Raid" }) do
        local cs = NS.db.sv.profiles[name].containers
        -- red under: the step touching the active profile only
        assertEqual(cs[2].text.autoSize, false, name)
        -- red under: the style-blind v8 stamp (E6: a bars or icons container reads the template,
        -- which the backfill hands the active profile only)
        assertTrue(fitOf(cs[1]) ~= false, name .. " bars")
        assertTrue(fitOf(cs[5]) ~= false, name .. " icons")
    end
    local c = NS.Database.FindContainer(2)
    c.text.width, c.text.height = 250, 18
    local w, h = NS.Style.ElementSize(c)
    assertEqual(w, 250); assertEqual(h, 18)
    local fresh2 = fresh()
    for _, k in ipairs(fresh2.Database.GetContainers()) do
        -- red under: a template default of false (Size to fit off on a new install, against D7)
        assertEqual(k.text.autoSize, true, k.name)
    end
end)

test("migrations: after v8 a new container and a new profile start with Size to fit on; a duplicate keeps its source's", function()
    local NS = fresh({ savedVariables = { profiles = { Default = v7mixed() }, global = { schemaVersion = 7 } } })
    local id = NS.ContainerManager.Create({ name = "New" })
    -- red under: v8 stamping false on containers made after the ladder ran
    assertEqual(NS.Database.FindContainer(id).text.autoSize, true)
    local dup = NS.ContainerManager.Duplicate(2)
    assertEqual(NS.Database.FindContainer(dup).text.autoSize, false, "the copy keeps the source's off")
    NS.db:SetProfile("Brand new")
    local all = NS.Database.GetContainers()
    assertTrue(#all > 0, "the new profile is seeded")
    for _, k in ipairs(all) do assertEqual(k.text.autoSize, true, k.name) end
end)

-- ── v9 (batch 9 E6, MG-1): Size to fit leaves bars and icons containers ─────────────────────────

--- A profile as the style-blind v8 left it: every container stamped off, whatever its style.
local function v8profile()
    local function c(name, style, text)
        return { name = name, unit = "player", auraType = "HELPFUL", style = style, text = text,
            attach = { mode = "screen", container = 0, x = 0, y = 0 } }
    end
    return {
        seeded = true, nextContainerId = 7, containerOrder = { 1, 2, 3, 4, 5, 6 },
        userCategories = {}, userCategoryOrder = {},
        containers = {
            [1] = c("Bars", "bars", { autoSize = false }),
            [2] = c("Icons", "icons", { autoSize = false, width = 150 }),
            [3] = c("Text off", "text", { autoSize = false, width = 250 }),
            [4] = c("Text on", "text", { autoSize = true }),
            [5] = c("Unstyled", nil, { autoSize = true }),
            [6] = c("No text block", "icons", nil),
        },
    }
end

test("migrations: v9 removes Size to fit from bars and icons containers, and keeps every Text one", function()
    local NS = fresh()
    local p = v8profile()
    -- red under: no MigrateV9 (E6's removal)
    local removed = NS.Database.MigrateV9(p)
    assertEqual(removed, 3, "bars, icons and an unstyled (bars) container")
    assertNil(p.containers[1].text.autoSize, "bars")
    assertNil(p.containers[2].text.autoSize, "icons")
    assertEqual(p.containers[2].text.width, 150, "the rest of the block kept")
    assertNil(p.containers[5].text.autoSize, "no style stored reads bars")
    assertNil(p.containers[6].text, "no text block: nothing created")
    -- red under: a style-blind removal (a Text container's value is the player's own)
    assertEqual(p.containers[3].text.autoSize, false)
    assertEqual(p.containers[3].text.width, 250)
    assertEqual(p.containers[4].text.autoSize, true)
    local before = NS.Database.DeepCopy(p)
    assertEqual(NS.Database.MigrateV9(p), 0, "a second run removes nothing")
    assertNil(diff(p, before))
end)

test("migrations: a v8 account climbs to v9 in every profile", function()
    local NS = fresh({ savedVariables = { profiles = { Default = v8profile(), Raid = v8profile() },
        global = { schemaVersion = 8 } } })
    -- red under: the v9 row missing from SCHEMA_STEPS
    assertEqual(NS.SCHEMA_VERSION, 9)
    assertEqual(NS.db.global.schemaVersion, 9)
    for _, name in ipairs({ "Default", "Raid" }) do
        local cs = NS.db.sv.profiles[name].containers
        -- red under: the step touching the active profile only
        assertTrue(fitOf(cs[1]) ~= false, name .. ": bars reads the template")
        assertTrue(fitOf(cs[2]) ~= false, name .. ": icons reads the template")
        assertEqual(cs[3].text.autoSize, false, name .. ": a Text container keeps its off")
    end
    local active = NS.Database.FindContainer(1)
    assertEqual(active.text.autoSize, true, "the active profile's bars container reads the template")
end)

test("migrations: a v1 account reaches v9 with Size to fit off on Text only", function()
    local p = v1profile()
    p.containers[5] = { name = "Lines", unit = "player", auraType = "HELPFUL", style = "text",
        text = { width = 200 } }
    p.containerOrder[2] = 5
    p.nextContainerId = 6
    local NS = fresh({ savedVariables = { profiles = { Default = p } } })
    assertEqual(NS.db.global.schemaVersion, 9)
    local cs = NS.db.sv.profiles.Default.containers
    -- red under: the style-blind v8 stamp left in place (the bars container would read false)
    assertEqual(cs[4].text.autoSize, true, "bars reads the template")
    assertEqual(cs[5].text.autoSize, false, "the Text container keeps its hand-set size")
    assertEqual(cs[5].text.width, 200)
end)
