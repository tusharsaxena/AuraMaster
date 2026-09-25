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

test("migrations: a v8 account climbs through v9 in every profile", function()
    local NS = fresh({ savedVariables = { profiles = { Default = v8profile(), Raid = v8profile() },
        global = { schemaVersion = 8 } } })
    -- red under: the v9 row missing from SCHEMA_STEPS
    assertEqual(NS.SCHEMA_VERSION, 11)
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
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
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
    local cs = NS.db.sv.profiles.Default.containers
    -- red under: the style-blind v8 stamp left in place (the bars container would read false)
    assertEqual(cs[4].text.autoSize, true, "bars reads the template")
    assertEqual(cs[5].text.autoSize, false, "the Text container keeps its hand-set size")
    assertEqual(cs[5].text.width, 200)
end)

-- ── v9 (batch 9 MG-1, E2, E5): the attach edge stamp and the screen-mode 0/-4 reset ───────────────

test("migrations: v9 stamps attach.edge after-start where it is missing or unknown, and keeps a known one", function()
    local NS = fresh()
    local p = v7profile()
    p.containers[3].attach.edge = "ahead-end"
    p.containers[4].attach.edge = "sideways"
    NS.Database.MigrateV8(p)
    -- red under: MigrateV9 without the edge stamp (MG-1)
    local _, stamped = NS.Database.MigrateV9(p)
    assertEqual(stamped, 5, "1, 2, 4 (unknown), 5 and 6: every container with an attach table")
    local at = function(id) return p.containers[id].attach end
    for _, id in ipairs({ 1, 2, 5, 6 }) do
        assertEqual(at(id).edge, "after-start", "container " .. id)
    end
    assertEqual(at(3).edge, "ahead-end", "a known side is the player's own")
    assertEqual(at(4).edge, "after-start", "an unknown side is repaired")
    assertNil(p.containers[7].attach, "no attach table: nothing created")
end)

test("migrations: v9 resets a screen container's old 0/-4 to 0/0, and leaves frame and container offsets", function()
    local NS = fresh()
    local p = v7profile()
    p.containers[8] = { name = "Screen, unstored", style = "bars", attach = { mode = "screen" } }
    p.containers[9] = { name = "Screen, own", style = "bars", attach = { mode = "screen", x = 0, y = -9 } }
    p.containerOrder[8], p.containerOrder[9] = 8, 9
    NS.Database.MigrateV8(p)
    local _, _, reset = NS.Database.MigrateV9(p)
    local at = function(id) return p.containers[id].attach end
    -- red under: the latent seam left on a screen container (a later switch to Another container
    -- would add the old 4px back on top of the seam)
    assertEqual(reset, 2, "the two screen containers on the old default")
    assertEqual(at(1).x, 0); assertEqual(at(1).y, 0, "screen 0/-4")
    assertEqual(at(8).x, 0); assertEqual(at(8).y, 0, "screen, absent: the old default")
    assertEqual(at(9).y, -9, "a screen offset of the player's own")
    assertEqual(at(5).y, -4, "a named frame keeps it")
    assertEqual(at(3).x, 3); assertEqual(at(3).y, -4, "a container nudge of the player's own")
    local before = NS.Database.DeepCopy(p)
    local removed, stamped, again = NS.Database.MigrateV9(p)
    assertEqual(removed + stamped + again, 0, "a second run changes nothing")
    assertNil(diff(p, before))
end)

test("migrations: a v7 and a v8 account climb past v9 with every chain on after-start, Automatic since v11, and no screen 0/-4", function()
    for _, from in ipairs({ 7, 8 }) do
        local NS = fresh({ savedVariables = { profiles = { Default = v7profile(), Raid = v7profile() },
            global = { schemaVersion = from } } })
        assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
        for _, name in ipairs({ "Default", "Raid" }) do
            local cs = NS.db.sv.profiles[name].containers
            -- red under: the step touching the active profile only
            assertNil(cs[2].attach.edge, from .. " " .. name .. ": v9's after-start, dropped by v11")
            assertEqual(cs[1].attach.y, 0, from .. " " .. name .. ": screen reset")
            assertEqual(cs[5].attach.y, -4, from .. " " .. name .. ": frame kept")
        end
        local c2 = NS.Database.FindContainer(2)
        local p, rp = NS.Anchors.AttachPoints(c2)
        assertEqual(p, "TOPLEFT"); assertEqual(rp, "BOTTOMLEFT")
    end
end)

-- ── v10 (batch 10 F7): the edge stamp and the screen reset again, for a v9 stamped before them ──

--- A profile as an early v9 build left it: v9 had only removed Size to fit when this install stamped
--- it, so no container has an attach side and the screen container still holds the old 0/-4. The
--- container-mode offsets are v8's 0/0.
local function v9early()
    local p = v7profile()
    local cs = p.containers
    cs[2].attach.x, cs[2].attach.y = 0, 0
    cs[6].attach.x, cs[6].attach.y = 0, 0
    p.containers[8] = { name = "Screen, unstored", style = "bars", attach = { mode = "screen" } }
    p.containerOrder[8] = 8
    p.nextContainerId = 9
    return p
end

test("migrations: v10 stamps the attach side and resets a screen 0/-4 that an early v9 left", function()
    local NS = fresh()
    local p = v9early()
    p.containers[3].attach.edge = "ahead-end"
    p.containers[4].attach.edge = "sideways"
    -- red under: no MigrateV10 (F7: the v9 halves re-run as their own step)
    local stamped, reset = NS.Database.MigrateV10(p)
    assertEqual(stamped, 6, "1, 2, 4 (unknown), 5, 6 and 8: every attach table without a known side")
    local at = function(id) return p.containers[id].attach end
    for _, id in ipairs({ 1, 2, 4, 5, 6, 8 }) do
        assertEqual(at(id).edge, "after-start", "container " .. id)
    end
    assertEqual(at(3).edge, "ahead-end", "a known side is the player's own")
    assertNil(p.containers[7].attach, "no attach table: nothing created")
    assertEqual(reset, 2, "the screen container on 0/-4 and the one with no offsets stored")
    assertEqual(at(1).x, 0); assertEqual(at(1).y, 0, "screen 0/-4")
    assertEqual(at(8).x, 0); assertEqual(at(8).y, 0, "screen, absent: the old default")
    assertEqual(at(5).y, -4, "a named frame keeps it")
    assertEqual(at(3).x, 3); assertEqual(at(3).y, -4, "a container nudge of the player's own")
    assertEqual(at(4).y, -9, "a container drop of the player's own")
    local before = NS.Database.DeepCopy(p)
    local again, again2 = NS.Database.MigrateV10(p)
    assertEqual(again + again2, 0, "a second run changes nothing")
    assertNil(diff(p, before))
end)

test("migrations: v10 changes nothing on a profile a full v9 already migrated", function()
    local NS = fresh()
    local p = v7profile()
    NS.Database.MigrateV8(p)
    NS.Database.MigrateV9(p)
    local before = NS.Database.DeepCopy(p)
    local stamped, reset = NS.Database.MigrateV10(p)
    assertEqual(stamped + reset, 0)
    assertNil(diff(p, before))
end)

test("migrations: a v9 account missing both climbs through v10 in every profile", function()
    local NS = fresh({ savedVariables = { profiles = { Default = v9early(), Raid = v9early() },
        global = { schemaVersion = 9 } } })
    -- red under: no v10 row (the ladder stops at 9 and never re-runs v9's late halves)
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
    for _, name in ipairs({ "Default", "Raid" }) do
        local cs = NS.db.sv.profiles[name].containers
        -- v10 stamped after-start everywhere; v11 dropped it to Automatic
        assertNil(cs[2].attach.edge, name)
        assertNil(cs[5].attach.edge, name .. ": a named frame's side too")
        assertNil(cs[2].attach.childPoint, name .. ": Automatic")
        assertEqual(cs[1].attach.y, 0, name .. ": screen reset")
        assertEqual(cs[8].attach.y, 0, name .. ": screen, absent, reset")
        assertEqual(cs[5].attach.y, -4, name .. ": frame kept")
        assertEqual(cs[3].attach.x, 3, name .. ": a nudge kept")
    end
end)

test("migrations: a v8 account reaches v11 with the same result as one that climbed through a full v9", function()
    local NS = fresh({ savedVariables = { profiles = { Default = v7profile(), Raid = v7profile() },
        global = { schemaVersion = 8 } } })
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
    -- stamped 8, so v8 does not run again: the ladder is v9, v10 and v11, the same as v9 and v11
    local full = v7profile()
    NS.Database.MigrateV9(full)
    NS.Database.MigrateV11(full)
    -- the inactive profile, read attach by attach (an absent offset reads as the template's 0)
    local cs = NS.db.sv.profiles.Raid.containers
    for id, c in pairs(full.containers) do
        local want, got = c.attach, cs[id].attach
        if want == nil then
            assertNil(got, "container " .. id)
        else
            assertEqual(got.edge, want.edge, "container " .. id .. " edge")
            assertEqual(got.x or 0, want.x or 0, "container " .. id .. " x")
            assertEqual(got.y or 0, want.y or 0, "container " .. id .. " y")
        end
    end
end)

-- ── v11 (batch 11 G4): the attach side becomes two absolute points ───────────────────────────────

--- A profile as v10 leaves it: container 1 on the screen growing left and up (its axis unstored, so
--- the template's columns), a chain under it on every kind of side, a named frame, a follower of a
--- follower, an unknown side, one with no side and one with no attach table.
local function v10profile(growH, growV)
    local function c(name, attach, layout)
        return { name = name, unit = "player", auraType = "HELPFUL", style = "bars", attach = attach, layout = layout }
    end
    local function on(to, edge) return { mode = "container", container = to, x = 0, y = 0, edge = edge } end
    return {
        seeded = true, nextContainerId = 11, containerOrder = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
        userCategories = {}, userCategoryOrder = {},
        containers = {
            [1] = c("Root", { mode = "screen", container = 0, x = 0, y = 0, edge = "after-start" },
                { growH = growH or "left", growV = growV or "up" }),
            [2] = c("Default side", on(1, "after-start")),
            [3] = c("Ahead end", on(1, "ahead-end")),
            [4] = c("Behind, wide", on(1, "behind-center"), { axis = "vertical", perLine = 3 }),
            [5] = c("Behind, one wide", on(1, "behind-start"), { axis = "vertical", perLine = 0 }),
            [6] = c("Named frame", { mode = "frame", frame = "PlayerFrame", x = 0, y = 0, edge = "after-end" }),
            [7] = c("Follower's follower", on(3, "ahead-start")),
            [8] = c("No attach", nil),
            [9] = c("Unknown side", on(1, "sideways")),
            [10] = c("No side", on(1, nil)),
        },
    }
end

local function pairOf(at) return tostring(at.childPoint) .. ">" .. tostring(at.relPoint) end

test("migrations: v11 drops the default side and converts every other to the points it resolved to", function()
    local NS = fresh()
    local p = v10profile()
    -- red under: no MigrateV11 (G4)
    local dropped, converted = NS.Database.MigrateV11(p)
    local at = function(id) return p.containers[id].attach end
    assertEqual(dropped, 3, "1 and 2 on after-start, and 9's unknown side")
    assertEqual(converted, 5, "3, 4, 5, 6 and 7")
    for id = 1, 10 do
        if id ~= 8 then assertNil(at(id).edge, "container " .. id .. ": attach.edge removed") end
    end
    for _, id in ipairs({ 1, 2, 9, 10 }) do
        assertNil(at(id).childPoint, "container " .. id .. ": Automatic")
        assertNil(at(id).relPoint, "container " .. id .. ": Automatic")
    end
    -- 1 grows left and up; its followers flow by it.
    assertEqual(pairOf(at(3)), "TOPRIGHT>TOPLEFT", "ahead-end growing left and up")
    -- red under: a behind side converted as stored rather than as ResolvedEdge placed it
    assertEqual(pairOf(at(4)), "BOTTOM>TOP", "behind on a wide child sat at after-center")
    assertEqual(pairOf(at(5)), "BOTTOMLEFT>BOTTOMRIGHT", "behind-start on a one-wide child")
    assertEqual(pairOf(at(6)), "TOPRIGHT>BOTTOMRIGHT", "a named frame's side, under its own growth")
    -- red under: a follower's follower converted under its own stored growth, not its root's
    assertEqual(pairOf(at(7)), "BOTTOMRIGHT>BOTTOMLEFT", "ahead-start under the root's growth")
    assertNil(p.containers[8].attach, "no attach table: nothing created")
    local before = NS.Database.DeepCopy(p)
    local again, again2 = NS.Database.MigrateV11(p)
    assertEqual(again + again2, 0, "a second run changes nothing")
    assertNil(diff(p, before))
end)

test("migrations: v11 converts to the very points ResolvedEdge and EdgePoints gave at v10", function()
    for _, g in ipairs({ { "right", "down" }, { "left", "down" }, { "right", "up" }, { "left", "up" } }) do
        local NS = fresh()
        local p = v10profile(g[1], g[2])
        NS.Database.MigrateV11(p)
        local L = { axis = "vertical", growH = g[1], growV = g[2] }
        local cases = { [3] = "ahead-end", [4] = "after-center", [5] = "behind-start", [7] = "ahead-start" }
        for id, token in pairs(cases) do
            local cp, rp = NS.Anchors.EdgePoints(L, token)
            assertEqual(pairOf(p.containers[id].attach), cp .. ">" .. rp, g[1] .. "/" .. g[2] .. " #" .. id)
        end
    end
end)

test("migrations: v11 keeps points already stored and still removes the side", function()
    local NS = fresh()
    local p = v10profile()
    p.containers[3].attach.childPoint = "CENTER"
    NS.Database.MigrateV11(p)
    assertEqual(p.containers[3].attach.childPoint, "CENTER", "the player's own")
    assertNil(p.containers[3].attach.edge)
end)

test("migrations: a v10 account reaches v11 in every profile, each converted under its own chain", function()
    local NS = fresh({ savedVariables = { profiles = { Default = v10profile("left", "up"),
        Raid = v10profile("right", "down") }, global = { schemaVersion = 10 } } })
    -- red under: no v11 row in SCHEMA_STEPS
    assertEqual(NS.SCHEMA_VERSION, 11)
    assertEqual(NS.db.global.schemaVersion, 11)
    local d, r = NS.db.sv.profiles.Default.containers, NS.db.sv.profiles.Raid.containers
    assertEqual(pairOf(d[3].attach), "TOPRIGHT>TOPLEFT", "Default grows left and up")
    -- red under: the conversion reading the active profile's chain for an inactive one
    assertEqual(pairOf(r[3].attach), "BOTTOMLEFT>BOTTOMRIGHT", "Raid grows right and down")
    for _, cs in ipairs({ d, r }) do
        for id, c in pairs(cs) do
            if c.attach then assertNil(c.attach.edge, "container " .. id) end
        end
    end
    local c2 = NS.Database.FindContainer(2)
    local cp, rp = NS.Anchors.AttachPoints(c2)
    assertEqual(cp .. ">" .. rp, "BOTTOMRIGHT>TOPRIGHT", "Automatic: G3's default, after-start growing left and up")
end)

test("migrations: v9, v8 and v1 accounts reach v11 with no attach side left and every chain Automatic", function()
    local cases = {
        { name = "v9", sv = function() return { profiles = { Default = v9early(), Raid = v9early() }, global = { schemaVersion = 9 } } end },
        { name = "v8", sv = function() return { profiles = { Default = v7profile(), Raid = v7profile() }, global = { schemaVersion = 8 } } end },
        { name = "v1", sv = function()
            local p = v1profile()
            p.containers[4].attach = { mode = "container", container = 9 }
            return { profiles = { Default = p } }
        end },
    }
    for _, case in ipairs(cases) do
        local NS = fresh({ savedVariables = case.sv() })
        assertEqual(NS.db.global.schemaVersion, 11, case.name)
        for name, prof in pairs(NS.db.sv.profiles) do
            for id, c in pairs(prof.containers) do
                if c.attach then
                    -- red under: v9/v10's after-start stamp surviving the climb (or backfilled back)
                    assertNil(c.attach.edge, case.name .. " " .. name .. " #" .. id)
                    assertNil(c.attach.childPoint, case.name .. " " .. name .. " #" .. id)
                    assertNil(c.attach.relPoint, case.name .. " " .. name .. " #" .. id)
                end
            end
        end
    end
end)

test("migrations: on load a stored point that is not one of the nine is read as Automatic, and a known one kept", function()
    local p = v8profile()
    p.containers[1].attach.childPoint, p.containers[1].attach.relPoint = "upward", "TOPRIGHT"
    local NS = fresh({ savedVariables = { profiles = { Default = p }, global = { schemaVersion = 11 } } })
    -- red under: no normalizeAttach for the points (the ladder did not run: the stamp is 11)
    assertNil(NS.Database.FindContainer(1).attach.childPoint)
    assertEqual(NS.Database.FindContainer(1).attach.relPoint, "TOPRIGHT")
end)
