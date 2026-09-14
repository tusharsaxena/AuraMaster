-- tests/test_database.lua — core/Database.lua: the registry's on-disk shape, the seeding, the
-- backfill and the migration runner. Each case that writes builds its own environment.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")

test("database: a fresh profile is seeded with the three starter containers, once", function()
    local NS = fresh()
    local list = NS.Database.GetContainers()
    assertEqual(#list, #NS.STARTER_CONTAINERS)
    assertEqual(list[1].name, "Player buffs")
    assertTrue(NS.db.profile.seeded)
    -- Deleting every container must not bring the starters back on the next preparation.
    for _, c in ipairs(list) do NS.ContainerManager.Delete(c.id) end
    assertEqual(NS.Database.PrepareProfile(NS.db.profile), 0)
    assertEqual(#NS.Database.GetContainers(), 0)
end)

test("database: PrepareProfile is idempotent", function()
    local NS = fresh()
    local before = NS.Database.DeepCopy(NS.db.profile)
    assertEqual(NS.Database.PrepareProfile(NS.db.profile), 0)
    assertEqual(#NS.db.profile.containerOrder, #before.containerOrder)
    assertEqual(NS.db.profile.nextContainerId, before.nextContainerId)
end)

test("database: string ids, dangling order entries and orphans are repaired", function()
    local NS = fresh()
    local p = NS.db.profile
    local c = p.containers[2]
    p.containers[2] = nil
    p.containers["7"] = c
    p.containerOrder = { 3, 99, 1, 1 }
    p.nextContainerId = 2
    NS.Database.PrepareProfile(p)
    assertTrue(p.containers[7] ~= nil, "a string id is normalized to a number")
    assertEqual(p.containers[7].id, 7)
    assertEqual(table.concat(p.containerOrder, ","), "3,1,7",
        "dangling and duplicate ids dropped, the orphan appended")
    assertEqual(p.nextContainerId, 8, "the counter moves past the largest id")
end)

test("database: the backfill fills a missing leaf and keeps a stored false", function()
    local NS = fresh()
    local c = NS.Database.FindContainer(1)
    c.bars.spark = false
    c.bars.sparkWidth = nil
    c.icons = nil
    NS.Database.PrepareProfile(NS.db.profile)
    assertEqual(c.bars.spark, false, "the player's off stays off (savedvariables-§5)")
    assertEqual(c.bars.sparkWidth, NS.CONTAINER_TEMPLATE.bars.sparkWidth)
    assertTrue(type(c.icons) == "table" and c.icons.width == NS.CONTAINER_TEMPLATE.icons.width)
end)

test("database: every category key is present on a stored container, at Show (schema v3)", function()
    local NS = fresh()
    local cats = NS.Database.FindContainer(1).filter.categories
    for _, list in ipairs({ NS.Categories.HELPFUL, NS.Categories.HARMFUL }) do
        for _, def in ipairs(list) do assertTrue(cats[def.key] ~= nil, "category " .. def.key) end
    end
    assertEqual(cats.defensives, "show")
end)

test("database: category keys are unique across the buff and debuff lists", function()
    local NS = fresh()
    local seen = {}
    for _, list in ipairs({ NS.Categories.HELPFUL, NS.Categories.HARMFUL }) do
        for _, def in ipairs(list) do
            assertNil(seen[def.key], "duplicate category key " .. def.key)
            seen[def.key] = true
        end
    end
end)

test("database: a new container's data is a deep copy of the template with a fresh id", function()
    local NS = fresh()
    local a, idA = NS.Database.NewContainerData({})
    local b, idB = NS.Database.NewContainerData({ bars = { width = 99 } })
    assertTrue(idB == idA + 1)
    assertEqual(b.bars.width, 99)
    assertEqual(a.bars.width, NS.CONTAINER_TEMPLATE.bars.width)
    a.bars.barColor.r = 0.123
    assertTrue(NS.CONTAINER_TEMPLATE.bars.barColor.r ~= 0.123, "no table is shared with the template")
end)

test("database: the migration runner stamps the schema and creates the timed-spell store", function()
    local NS = fresh()
    assertEqual(NS.db.global.schemaVersion, NS.Database.CurrentSchemaVersion())
    assertEqual(type(NS.db.global.timedSpells), "table")
end)

test("database: an existing SavedVariables file keeps its containers", function()
    local seeded = {
        profiles = { Default = {
            seeded = true, nextContainerId = 5,
            containers = { [4] = { name = "Mine", unit = "focus", auraType = "HARMFUL", style = "icons" } },
            containerOrder = { 4 },
        } },
        global = { schemaVersion = 1 },
    }
    local NS = fresh({ savedVariables = seeded })
    local list = NS.Database.GetContainers()
    assertEqual(#list, 1, "no starters are added to a profile that was already seeded")
    assertEqual(list[1].name, "Mine")
    assertEqual(list[1].unit, "focus")
    assertEqual(list[1].bars.width, NS.CONTAINER_TEMPLATE.bars.width, "the missing sections are backfilled")
    assertFalse(list[1].id ~= 4)
end)

test("database: a stored section of the wrong type is replaced from the template on load", function()
    local seeded = {
        profiles = { Default = {
            seeded = true, nextContainerId = 5,
            containers = { [4] = {
                name = "Mine", unit = "player", auraType = "HELPFUL", style = "bars",
                position = "junk", bars = { width = 150, name = false },
            } },
            containerOrder = { 4 },
        } },
        global = { schemaVersion = 1 },
    }
    -- red under: Backfill without the load path's `repair` — the non-table section survives
    -- PrepareProfile, and ContainerManager.Duplicate then indexes it and raises
    local NS = fresh({ savedVariables = seeded })
    local c = NS.db.profile.containers[4]
    assertEqual(type(c.position), "table", "the junk position is replaced by the template's section")
    assertEqual(c.position.point, NS.CONTAINER_TEMPLATE.position.point)
    assertEqual(type(c.bars.name), "table", "a nested section of the wrong type is repaired too")
    assertEqual(c.bars.width, 150, "a stored leaf beside it is the player's and survives")
    assertTrue((pcall(NS.ContainerManager.Duplicate, 4)), "Duplicate on the repaired container does not raise")
end)

test("database: a non-numeric container key is dropped and the profile loads", function()
    local seeded = {
        profiles = { Default = {
            seeded = true, nextContainerId = 5,
            containers = {
                [4] = { name = "Mine", unit = "player", auraType = "HELPFUL", style = "bars" },
                abc = { name = "junk" },
            },
            containerOrder = { 4 },
        } },
        global = { schemaVersion = 1 },
    }
    -- red under: removing the drop branch in normalizeKeys (the env build raises comparing "abc" to a number)
    local NS = fresh({ savedVariables = seeded })
    assertEqual(#NS.Database.GetContainers(), 1)
    assertNil(NS.db.profile.containers.abc, "a key that is neither a number nor a numeric string is dropped")
    assertEqual(NS.db.profile.containers[4].name, "Mine")
end)

test("database: a string key naming an id already stored as a number is dropped; the numeric key wins", function()
    local seeded = {
        profiles = { Default = {
            seeded = true, nextContainerId = 5,
            containers = {
                [2] = { name = "Numeric", unit = "player", auraType = "HELPFUL", style = "bars" },
                ["2"] = { name = "Stale", unit = "player", auraType = "HARMFUL", style = "icons" },
                ["4"] = { name = "Lone", unit = "player", auraType = "HELPFUL", style = "bars" },
            },
            containerOrder = { 2, 4 },
        } },
        global = { schemaVersion = 1 },
    }
    -- red under: normalizeKeys moving every numeric-string key over its number (the stale copy wins)
    local NS = fresh({ savedVariables = seeded })
    local p = NS.db.profile
    assertEqual(p.containers[2].name, "Numeric", "the numeric key is the form the addon writes")
    assertEqual(p.containers[2].style, "bars")
    assertNil(p.containers["2"], "the string twin is gone")
    assertEqual(p.containers[4].name, "Lone", "a string key with no numeric twin is still converted")
    assertNil(p.containers["4"])
    assertEqual(#NS.Database.GetContainers(), 2)
end)

test("database: a dropped string twin leaves one [Migrate] line naming the key", function()
    local NS = fresh()
    local lines = {}
    NS.Debug = function(tag, fmt, ...)
        if tag == "Migrate" then
            lines[#lines + 1] = fmt:format(...)
        end
    end
    local p = {
        seeded = true, nextContainerId = 3,
        containers = { [2] = { name = "Numeric" }, ["2"] = { name = "Stale" } },
        containerOrder = { 2 },
    }
    NS.Database.PrepareProfile(p)
    -- red under: dropping the twin without its trace
    assertEqual(#lines, 1, table.concat(lines, " | "))
    assertTrue(lines[1]:find("dropped container key 2", 1, true) ~= nil, lines[1])
    assertEqual(p.containers[2].name, "Numeric")
end)

-- Characterization (testing-§13): pinned on the single-function PrepareProfile before it was split
-- into local helpers, so the split is proven to change nothing.

test("database: PrepareProfile seeds an empty profile from its own counter, in declaration order", function()
    local NS = fresh()
    local n = #NS.STARTER_CONTAINERS
    local p = { nextContainerId = 10 }
    assertEqual(NS.Database.PrepareProfile(p), n, "returns how many it seeded")
    local want = {}
    for i = 1, n do
        want[i] = tostring(9 + i)
    end
    assertEqual(table.concat(p.containerOrder, ","), table.concat(want, ","))
    assertEqual(p.nextContainerId, 10 + n)
    assertEqual(p.containers[10].id, 10)
    assertEqual(p.containers[10].name, NS.STARTER_CONTAINERS[1].name)
    assertTrue(p.seeded)
    assertEqual(NS.Database.PrepareProfile(p), 0, "a second call seeds nothing")
end)

test("database: PrepareProfile marks a stocked profile seeded, drops a non-table entry and restamps ids", function()
    local NS = fresh()
    assertEqual(NS.Database.PrepareProfile(nil), 0, "a non-table profile is left alone")
    local p = { containers = { [3] = { name = "Three", id = 99 }, [5] = true }, containerOrder = { 5, 3 } }
    assertEqual(NS.Database.PrepareProfile(p), 0, "a profile that has containers gets no starters")
    assertTrue(p.seeded)
    assertNil(p.containers[5], "an entry that is not a table is dropped")
    assertEqual(p.containers[3].id, 3, "the stored id follows the key")
    assertEqual(p.containers[3].bars.width, NS.CONTAINER_TEMPLATE.bars.width, "backfilled")
    assertEqual(table.concat(p.containerOrder, ","), "3")
    assertEqual(p.nextContainerId, 4, "the counter starts past the largest id")
end)

-- ── migrations, the id counter, the order and the seeding, on old and odd shapes ───────────────

test("database: a schema version newer than this build is never lowered", function()
    local NS = fresh({ savedVariables = { global = { schemaVersion = 5 } } })
    -- red under: RunMigrations stamping the current version over whatever was stored
    assertEqual(NS.db.global.schemaVersion, 5, "a file from a newer build keeps its version")
end)

test("database: learned timed spells survive a load", function()
    local NS = fresh({ savedVariables = { global = { schemaVersion = 1, timedSpells = { [774] = true } } } })
    -- red under: RunMigrations replacing the timed-spell store instead of creating it only when missing
    assertTrue(NS.db.global.timedSpells[774])
end)

test("database: without AceDB the addon runs on the raw SavedVariables, keeping what was stored", function()
    local NS = fresh({
        savedVariables = { profile = { scale = 1.5 } },
        before = function(m) m.__libs["AceDB-3.0"] = nil end,
    })
    -- red under: InitDB without its no-AceDB fallback (NS.db stays nil and the load raises)
    assertTrue(NS.db.profile == _G.AuraMasterDB.profile, "writes land in the SavedVariables table")
    assertEqual(NS.db.profile.scale, 1.5, "a stored value survives the backfill")
    assertEqual(NS.db.profile.enabled, NS.defaults.profile.enabled, "a missing one is filled")
    assertEqual(#NS.Database.GetContainers(), #NS.STARTER_CONTAINERS, "and the starters are seeded")
    assertEqual(NS.db.global.schemaVersion, NS.Database.CurrentSchemaVersion())
end)

test("database: GetContainers follows the stored order and skips an id with no container", function()
    local NS = fresh()
    NS.db.profile.containerOrder = { 3, 99, 1, 2 }
    local ids = {}
    for i, c in ipairs(NS.Database.GetContainers()) do ids[i] = c.id end
    -- red under: GetContainers walking the containers table instead of containerOrder
    assertEqual(table.concat(ids, ","), "3,1,2")
end)

test("database: a string id in the stored order keeps its place", function()
    local NS = fresh()
    local p = NS.db.profile
    p.containerOrder = { "2", 1 }
    NS.Database.PrepareProfile(p)
    -- red under: rebuildOrder dropping its tonumber (the "2" is taken for dangling and re-appended)
    assertEqual(table.concat(p.containerOrder, ","), "2,1,3")
end)

test("database: a deleted id is never handed out again, not even after a reload", function()
    local NS, mocks = fresh()
    local CM = NS.ContainerManager
    CM.Delete(3)
    assertEqual(CM.Create({}), 4, "the counter does not rewind to the freed id")
    mocks.__fireTimers()
    CM.Delete(4)
    NS.Database.PrepareProfile(NS.db.profile)   -- what the next login runs
    -- red under: PrepareProfile setting the counter to the largest id kept plus one
    assertEqual(CM.Create({}), 5)
end)

test("database: NewContainerData takes an id from the counter without registering the container", function()
    local NS = fresh()
    local before = #NS.Database.GetContainers()
    local c, id = NS.Database.NewContainerData({ name = "Loose" })
    assertEqual(c.id, id)
    assertEqual(NS.db.profile.nextContainerId, id + 1)
    -- red under: NewContainerData inserting what it builds (Create inserts it, and announces it)
    assertNil(NS.Database.FindContainer(id))
    assertEqual(#NS.Database.GetContainers(), before)
end)

test("database: seeded starters share no table with each other or with the template", function()
    local NS = fresh()
    local p = {}
    NS.Database.PrepareProfile(p)
    local a, b = p.containers[1], p.containers[2]
    -- red under: seedStarters merging onto CONTAINER_TEMPLATE itself instead of a copy of it
    assertTrue(a.bars.barColor ~= b.bars.barColor, "two starters, two color tables")
    assertTrue(a.bars.barColor ~= NS.CONTAINER_TEMPLATE.bars.barColor, "recoloring one never recolors the default")
end)

test("database: a file from before the seeded flag, the id counter and the order keeps its containers", function()
    local seeded = {
        profiles = { Default = {
            containers = {
                [2] = { name = "Two", unit = "player", auraType = "HELPFUL", style = "bars" },
                [6] = { name = "Six", unit = "target", auraType = "HARMFUL", style = "icons" },
            },
        } },
    }
    local NS = fresh({ savedVariables = seeded })
    local p = NS.db.profile
    -- red under: seedStarters seeding an unflagged profile that already has containers
    assertEqual(table.concat(p.containerOrder, ","), "2,6", "no starters; the order rebuilt by id")
    assertTrue(p.seeded)
    assertEqual(p.nextContainerId, 7)
    assertEqual(NS.ContainerManager.Create({}), 7)
end)

-- ── schema v2 (feedback batch 5, spec §7): profile-wide spell lists and dispel colors, the Healing
-- merge, strata High. Each case builds a raw v1 profile table and runs the pure step over it. ─────

--- A raw v1 profile: `list[i]` becomes container i, in that display order unless `order` is given.
local function v1profile(list, order)
    local p = { containers = {}, containerOrder = order or {} }
    for i, c in ipairs(list) do
        p.containers[i] = c
        if not order then p.containerOrder[i] = i end
    end
    return p
end

local function edits(t) return { filter = { categorySpells = t } } end

-- "the schema is at version 2" (this test's original name) stopped being true the moment schema v3
-- landed below it; the equivalent coverage for the ladder's current top is
-- "v3: the current schema version is 3" further down, and "database: the migration runner stamps the
-- schema..." above already checks a fresh profile against CurrentSchemaVersion() dynamically.

test("database v2: spell additions from every container are united in the profile", function()
    local NS = fresh()
    local p = v1profile({ edits({ defensives = { [111] = true } }), edits({ defensives = { [222] = true } }) })
    NS.Database.MigrateV2(p)
    -- red under: lifting only the first container's edits
    assertEqual(p.categorySpells.defensives[111], true)
    assertEqual(p.categorySpells.defensives[222], true)
    for id, c in pairs(p.containers) do
        -- red under: leaving the per-container copy behind (it would never be read again)
        assertNil(c.filter.categorySpells, "container " .. id .. " keeps no spell edits of its own")
    end
end)

test("database v2: a starter is removed profile-wide only when every container that edited it removed it", function()
    local NS = fresh()
    local p = v1profile({
        edits({ defensives = { [871] = false, [118038] = false } }),
        edits({ defensives = { [118038] = false } }),
        edits({ raidCDs = { [97463] = false } }),
        { filter = {} },
    })
    NS.Database.MigrateV2(p)
    local d = p.categorySpells.defensives
    -- red under: keeping a removal any one container made (it would hide the spell in every container)
    assertNil(d[871], "container 2 edited defensives and kept 871")
    -- red under: counting a container with no edit for the category as a veto
    assertEqual(d[118038], false, "every editor of defensives removed it")
    assertEqual(p.categorySpells.raidCDs[97463], false, "a lone editor's removal stands")
end)

test("database v2: an addition beats another container's removal of the same spell", function()
    local NS = fresh()
    local p = v1profile({ edits({ movement = { [2983] = true } }), edits({ movement = { [2983] = false } }) })
    NS.Database.MigrateV2(p)
    -- red under: mergeEditors letting any one removal stand, and an addition not overriding it
    assertEqual(p.categorySpells.movement[2983], true)
end)

test("database v2: the two healing lists' spell edits merge under healing", function()
    local NS = fresh()
    local p = v1profile({
        edits({ coreHealing = { [5] = true, [774] = false }, lesserHealing = { [6] = true } }),
        edits({ lesserHealing = { [774] = false, [102352] = false } }),
    })
    NS.Database.MigrateV2(p)
    local h = p.categorySpells.healing
    -- red under: dropping the retired keys' edits instead of merging them
    assertEqual(h[5], true)
    assertEqual(h[6], true)
    -- red under: counting a container's two old lists as two editors (774 would have two removals
    -- among three editors)
    assertEqual(h[774], false, "both containers removed Rejuvenation, one through each old list")
    -- red under: container 1 not counted as a healing editor (102352 would be removed on container
    -- 2's say alone)
    assertNil(h[102352], "container 1 edited healing and kept it")
    assertNil(p.categorySpells.coreHealing)
    assertNil(p.categorySpells.lesserHealing)
end)

test("database v2: a container's two healing states merge — show beats hide beats neutral", function()
    local NS = fresh()
    local function cats(core, lesser) return { filter = { categories = { coreHealing = core, lesserHealing = lesser } } } end
    local p = v1profile({ cats("show", ""), cats("", "hide"), cats("hide", "show"), cats("", ""), cats("hide", nil) })
    NS.Database.MigrateV2(p)
    local want = { "show", "hide", "show", "", "hide" }
    for i, w in ipairs(want) do
        local c = p.containers[i].filter.categories
        -- red under: taking only the coreHealing state, or letting hide beat show
        assertEqual(c.healing, w, "container " .. i)
        assertNil(c.coreHealing, "container " .. i .. ": the old key is gone")
        assertNil(c.lesserHealing, "container " .. i .. ": the old key is gone")
    end
end)

test("database v2: dispel colors come from the first dispel-colored container in display order", function()
    local NS = fresh()
    local function bars(mode, r) return { bars = { colorMode = mode, dispelColors = { Magic = { r = r, g = 0, b = 0, a = 1 } } } } end
    local p = v1profile({ bars("dispel", 0.1), bars("static", 0.2), bars("dispel", 0.3) }, { 2, 3, 1 })
    NS.Database.MigrateV2(p)
    -- red under: walking the containers table instead of containerOrder (container 1 would win)
    assertEqual(p.dispelColors.Magic.r, 0.3)
    for id, c in pairs(p.containers) do
        -- red under: leaving bars.dispelColors on a container (the template no longer knows it)
        assertNil(c.bars.dispelColors, "container " .. id)
    end
end)

test("database v2: with no dispel-colored container the first container's colors win, completed from the defaults", function()
    local NS = fresh()
    local p = v1profile({
        { bars = { colorMode = "static", dispelColors = { Magic = { r = 0.5, g = 0.5, b = 0.5, a = 1 } } } },
        { bars = { colorMode = "static", dispelColors = { Magic = { r = 0.9, g = 0.9, b = 0.9, a = 1 } } } },
    }, { 2, 1 })
    NS.Database.MigrateV2(p)
    assertEqual(p.dispelColors.Magic.r, 0.9, "container 2 is first in display order")
    -- red under: storing the lifted table as it was (a type it lacks would have no color)
    assertEqual(p.dispelColors.Curse.g, NS.Constants.DEFAULT_DISPEL_COLORS.Curse.g)
end)

test("database v2: a stale string twin or a non-numeric container key takes no part in the merge", function()
    local NS = fresh()
    local function c(mode, r, spells)
        return { bars = { colorMode = mode, dispelColors = { Magic = { r = r, g = 0, b = 0, a = 1 } } },
                 filter = { categorySpells = { defensives = spells } } }
    end
    local p = { containers = {}, containerOrder = { 1, 2 } }
    p.containers[1] = c("static", 0.1, { [111] = true })
    p.containers["1"] = c("dispel", 0.9, { [871] = false, [222] = true })
    p.containers.junk = c("dispel", 0.8, { [333] = true })
    p.containers["2"] = c("static", 0.2, { [444] = true })
    NS.Database.MigrateV2(p)
    -- red under: MigrateV2 merging before the key rules PrepareProfile applies (the twin PrepareProfile
    -- then drops would supply the palette)
    assertEqual(p.dispelColors.Magic.r, 0.1, "the kept container 1's palette")
    local d = p.categorySpells.defensives
    assertNil(d[222], "the twin's addition")
    assertNil(d[871], "the twin's removal")
    assertNil(d[333], "the non-numeric key's addition")
    assertEqual(d[111], true)
    -- red under: normalizing by dropping every string key (a lone numeric string is a real id)
    assertEqual(d[444], true, "container \"2\", stored under a string key with no twin")
    assertNil(p.containers["1"]); assertNil(p.containers.junk)
    assertTrue(p.containers[2] ~= nil, "renamed to its numeric id")
end)

test("database v2: a profile with no containers gets the default dispel colors and empty spell lists", function()
    local NS = fresh()
    local p = v1profile({})
    NS.Database.MigrateV2(p)
    local want = NS.Constants.DEFAULT_DISPEL_COLORS
    for name, w in pairs(want) do
        assertEqual(p.dispelColors[name].b, w.b, name)
        -- red under: storing the constant itself (a swatch edit would repaint the default)
        assertTrue(p.dispelColors[name] ~= w, name .. " is the profile's own table")
    end
    assertEqual(next(p.categorySpells), nil)
end)

test("database v2: stored Medium strata rises to High and every other strata is kept", function()
    local NS = fresh()
    local p = v1profile({ { layout = { strata = "MEDIUM" } }, { layout = { strata = "LOW" } }, {} })
    NS.Database.MigrateV2(p)
    -- red under: the strata step missing (Medium stays under the default UI's own frames)
    assertEqual(p.containers[1].layout.strata, "HIGH")
    assertEqual(p.containers[2].layout.strata, "LOW", "a strata the player chose is theirs")
    assertNil(p.containers[3].layout, "a container with no layout gets none from the step")
end)

test("database v2: the step is idempotent over a profile it already migrated", function()
    local NS = fresh()
    local p = v1profile({
        { filter = { categories = { coreHealing = "show" }, categorySpells = { coreHealing = { [5] = true } } },
          bars = { colorMode = "dispel", dispelColors = { Magic = { r = 0.3, g = 0, b = 0, a = 1 } } },
          layout = { strata = "MEDIUM" } },
    })
    NS.Database.MigrateV2(p)
    local once = NS.Database.DeepCopy(p)
    NS.Database.MigrateV2(p)
    local Sig = NS.FilterCompiler.Signature
    -- red under: a second pass resetting the lifted colors or spell lists to the defaults
    assertEqual(Sig(p), Sig(once))
end)

test("database v2: RunMigrations migrates every stored profile, the inactive one included", function()
    local function raw()
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
    local NS = fresh({ savedVariables = { profiles = { Default = raw(), Raid = raw() }, global = { schemaVersion = 1 } } })
    -- schema v3 rides along from v1 too (the ladder does not stop at 2); its whitelist lift never
    -- disturbs an already-"hide" category (see the v3 tests below), so the v2 assertions below hold.
    assertEqual(NS.db.global.schemaVersion, NS.Database.CurrentSchemaVersion())
    for _, name in ipairs({ "Default", "Raid" }) do
        local p = NS.db.sv.profiles[name]
        local c = p.containers[4]
        -- red under: the step migrating NS.db.profile only (Raid would keep its v1 shape for ever)
        assertEqual(p.categorySpells.defensives[111], true, name)
        assertEqual(p.dispelColors.Magic.r, 0.3, name)
        assertNil(c.filter.categorySpells, name)
        assertNil(c.bars.dispelColors, name)
        assertEqual(c.filter.categories.healing, "hide", name)
        assertEqual(c.layout.strata, "HIGH", name)
    end
end)

test("database v2: RunMigrations logs one [Migrate] line per profile, and a second run is a no-op", function()
    local NS = fresh()
    local lines = {}
    NS.Debug = function(tag, fmt, ...)
        if tag == "Migrate" then
            lines[#lines + 1] = fmt:format(...)
        end
    end
    NS.db.sv.profiles.Other = v1profile({ { layout = { strata = "MEDIUM" } } })
    NS.db.global.schemaVersion = 1
    NS.RunMigrations()
    local perProfile = 0
    for _, l in ipairs(lines) do
        if l:find("profile '", 1, true) then perProfile = perProfile + 1 end
    end
    -- red under: logging once for the whole step, or not at all per profile. 2 profiles x the 2
    -- steps a v1 profile now climbs (v2, v3).
    assertEqual(perProfile, 4, table.concat(lines, " | "))
    assertEqual(NS.db.sv.profiles.Other.containers[1].layout.strata, "HIGH")
    local before = #lines
    NS.db.sv.profiles.Other.containers[1].layout.strata = "MEDIUM"
    NS.RunMigrations()
    -- red under: RunMigrations re-running a step the stamp already passed
    assertEqual(#lines, before, "nothing logged")
    assertEqual(NS.db.sv.profiles.Other.containers[1].layout.strata, "MEDIUM", "nothing migrated")
end)

test("database v2: without AceDB the step migrates the one profile there is", function()
    local NS = fresh({
        savedVariables = { profile = { seeded = true, containerOrder = { 1 },
            containers = { [1] = { name = "Solo", layout = { strata = "MEDIUM" } } } }, global = { schemaVersion = 1 } },
        before = function(m) m.__libs["AceDB-3.0"] = nil end,
    })
    -- red under: the step walking db.sv only (the no-AceDB fallback has none)
    assertEqual(NS.db.profile.containers[1].layout.strata, "HIGH")
    assertEqual(NS.db.global.schemaVersion, NS.Database.CurrentSchemaVersion())
end)

test("database v2: a fresh profile carries the profile-wide spell lists and dispel colors", function()
    local NS = fresh()
    local p = NS.db.profile
    -- red under: the two profile defaults missing from NS.defaults.profile
    assertEqual(type(p.categorySpells), "table")
    for name, w in pairs(NS.Constants.DEFAULT_DISPEL_COLORS) do
        assertEqual(p.dispelColors[name].r, w.r, name)
    end
end)

-- ---------------------------------------------------------------------------
-- Schema v3: Show/Hide categories, weaponEnchants
-- ---------------------------------------------------------------------------

test("v3: a container that whitelisted a category hides every other category of its type", function()
    local NS = fresh()
    local p = { containers = { { auraType = "HELPFUL",
        filter = { categories = { defensives = "show", raidCDs = "", cancelable = "" } } } } }
    -- red under: the old Whitelist intent being dropped, which would silently WIDEN what a container
    -- draws — the one migration failure a player cannot see until an aura appears that should not.
    NS.Database.MigrateV3(p)
    local c = p.containers[1].filter.categories
    assertEqual(c.defensives, "show")
    assertEqual(c.raidCDs, "hide")
    assertEqual(c.cancelable, "hide")
end)

test("v3: a container with no whitelisted category gets every row at show", function()
    local NS = fresh()
    local p = { containers = { { auraType = "HELPFUL",
        filter = { categories = { defensives = "", raidCDs = "hide" } } } } }
    -- red under: "" not being normalized, so a row lights no cell.
    NS.Database.MigrateV3(p)
    local c = p.containers[1].filter.categories
    assertEqual(c.defensives, "show")
    assertEqual(c.raidCDs, "hide")
end)

test("v3: includeEnchants becomes the weaponEnchants row and the old key is cleared", function()
    local NS = fresh()
    local p = { containers = {
        { auraType = "HELPFUL", filter = { includeEnchants = true, categories = {} } },
        { auraType = "HELPFUL", filter = { includeEnchants = false, categories = {} } },
        { auraType = "HELPFUL", filter = { categories = {} } },
    } }
    -- red under: the enchant flag being read backwards, which would turn enchants on everywhere.
    NS.Database.MigrateV3(p)
    assertEqual(p.containers[1].filter.categories.weaponEnchants, "show")
    assertEqual(p.containers[2].filter.categories.weaponEnchants, "hide")
    assertEqual(p.containers[3].filter.categories.weaponEnchants, "hide")
    assertNil(p.containers[1].filter.includeEnchants)
end)

test("v3: an ENCHANT container is left alone", function()
    local NS = fresh()
    local p = { containers = { { auraType = "ENCHANT", filter = { categories = {} } } } }
    -- red under: an ENCHANT container being given a weaponEnchants row it never reads.
    NS.Database.MigrateV3(p)
    assertNil(p.containers[1].filter.categories.weaponEnchants)
end)

test("v3: a container with a missing or unrecognized auraType is left completely untouched", function()
    local NS = fresh()
    local p = { containers = {
        { filter = { includeEnchants = true, categories = { defensives = "show", raidCDs = "" } } },
        { auraType = "BOGUS", filter = { includeEnchants = true, categories = { defensives = "show" } } },
    } }
    local before = NS.Database.DeepCopy(p)
    -- red under: liftEnchantFlag's own "auraType == ENCHANT" check letting a nil or garbage auraType
    -- through, half-converting a container MigrateV3 never had a category list for.
    NS.Database.MigrateV3(p)
    local Sig = NS.FilterCompiler.Signature
    assertEqual(Sig(p), Sig(before))
end)

test("v3: MigrateV3 is idempotent — a second run changes nothing a first run already decided", function()
    local NS = fresh()
    local function scenario()
        return { containers = {
            { auraType = "HELPFUL", filter = { includeEnchants = true,
                categories = { defensives = "show", raidCDs = "" } } },
            { auraType = "HELPFUL", filter = { includeEnchants = false, categories = { defensives = "" } } },
            { auraType = "HARMFUL", filter = { categories = { crowdControl = "hide" } } },
        } }
    end
    local once = scenario()
    NS.Database.MigrateV3(once)
    local twice = NS.Database.DeepCopy(once)
    -- red under: liftEnchantFlag reading filter.includeEnchants (already nil after run 1) instead of
    -- checking whether categories.weaponEnchants is already decided, and re-stamping "hide"
    NS.Database.MigrateV3(twice)
    local Sig = NS.FilterCompiler.Signature
    assertEqual(Sig(twice), Sig(once))
    assertEqual(twice.containers[1].filter.categories.weaponEnchants, "show", "run 1's decision survives run 2")
end)

test("v3: a narrowed container copies its whitelisted spell categories' ids onto filter.whitelist", function()
    local NS = fresh()
    local Cat = NS.Categories.Find("HELPFUL", "defensives")
    local defensivesIds = NS.FilterCompiler.CategorySpells(Cat, nil)
    local p = { containers = { { auraType = "HELPFUL",
        filter = { blacklist = { [118038] = true },
            categories = { defensives = "show", raidCDs = "" } } } } }
    -- red under: the narrowing half of the whitelist lift being skipped entirely — an aura in
    -- "defensives" that ALSO matches another (now hidden) category would stop being drawn, when the
    -- old exclusive whitelist drew it regardless.
    NS.Database.MigrateV3(p)
    local w = p.containers[1].filter.whitelist
    local n = 0
    for id in pairs(defensivesIds) do
        if id ~= 118038 then
            assertEqual(w[id], true, "id " .. id)
            n = n + 1
        end
    end
    assertTrue(n > 0, "the starter defensives list is non-empty")
    -- red under: a migration overturning a player's explicit blacklist entry
    assertNil(w[118038], "already blacklisted, left alone rather than added to the whitelist")
end)

test("v3: a container that was not narrowed gains nothing on filter.whitelist", function()
    local NS = fresh()
    local p = { containers = { { auraType = "HELPFUL",
        filter = { categories = { defensives = "", raidCDs = "hide" } } } } }
    -- red under: copying ids even when no category was whitelisted
    NS.Database.MigrateV3(p)
    assertNil(p.containers[1].filter.whitelist)
end)

test("v3: the whitelist spell copy respects the profile's own category edits, and merges into an existing whitelist", function()
    local NS = fresh()
    local p = { categorySpells = { defensives = { [9999] = true, [871] = false } },
        containers = { { auraType = "HELPFUL",
            filter = { whitelist = { [42] = true },
                categories = { defensives = "show", raidCDs = "" } } } } }
    -- red under: reading only the shipped starter list instead of FC.CategorySpells(def, p.categorySpells)
    NS.Database.MigrateV3(p)
    local w = p.containers[1].filter.whitelist
    assertEqual(w[42], true, "an id already on the whitelist survives the merge")
    assertEqual(w[9999], true, "the profile's own addition to defensives is honored")
    assertNil(w[871], "the profile's own removal from defensives is honored")
end)

test("v3: MigrateV3 returns the number of containers it walked", function()
    local NS = fresh()
    local p = { containers = {
        { auraType = "HELPFUL", filter = { categories = {} } },
        { auraType = "HARMFUL", filter = { categories = {} } },
    } }
    assertEqual(NS.Database.MigrateV3(p), 2)
end)

test("v3: the whitelist lift never sweeps a category the aura type does not have", function()
    local NS = fresh()
    -- red under: liftCategoryWhitelist walking the wrong aura type's category list
    local p = { containers = { { auraType = "HARMFUL",
        filter = { categories = { crowdControl = "show", boss = "" } } } } }
    NS.Database.MigrateV3(p)
    local c = p.containers[1].filter.categories
    assertEqual(c.crowdControl, "show")
    assertEqual(c.boss, "hide")
    assertNil(c.defensives, "a HELPFUL-only category never appears on a HARMFUL container")
end)

test("v3: the current schema version is 3", function()
    local NS = fresh()
    -- red under: the v3 step missing from SCHEMA_STEPS
    assertEqual(NS.Database.CurrentSchemaVersion(), 3)
    assertEqual(NS.db.global.schemaVersion, 3)
end)

test("v3: RunMigrations migrates every stored profile, the inactive one included", function()
    local function raw()
        return {
            seeded = true, nextContainerId = 2, containerOrder = { 1 },
            containers = { [1] = {
                name = "Mine", unit = "player", auraType = "HELPFUL", style = "bars",
                filter = { includeEnchants = true, categories = { defensives = "show", raidCDs = "" } },
            } },
        }
    end
    local NS = fresh({ savedVariables = { profiles = { Default = raw(), Raid = raw() }, global = { schemaVersion = 2 } } })
    assertEqual(NS.db.global.schemaVersion, 3)
    for _, name in ipairs({ "Default", "Raid" }) do
        local c = NS.db.sv.profiles[name].containers[1]
        -- red under: the step migrating NS.db.profile only (Raid would keep its v2 shape for ever)
        assertEqual(c.filter.categories.defensives, "show", name)
        assertEqual(c.filter.categories.raidCDs, "hide", name)
        assertEqual(c.filter.categories.weaponEnchants, "show", name)
        -- Not assertNil(c.filter.includeEnchants) here: the step clears it (see the direct MigrateV3
        -- test above), but RunMigrations backfills the ACTIVE profile from CONTAINER_TEMPLATE right
        -- after the ladder, and the template still declares includeEnchants until B3 retires it —
        -- an expected artifact of B2 landing before B3, not a v3 step concern.
    end
end)
