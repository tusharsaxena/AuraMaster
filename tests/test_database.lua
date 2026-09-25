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
    assertEqual(table.concat(p.containerOrder, ","), "3,1,4,7",
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
    local NS = fresh({ savedVariables = { global = { schemaVersion = 99 } } })
    -- red under: RunMigrations stamping the current version over whatever was stored. The stored
    -- number is deliberately far past the ladder rather than one step past it, so the case does not
    -- have to be re-numbered every time a step is added (it was 5 until issue #10's v6).
    assertEqual(NS.db.global.schemaVersion, 99, "a file from a newer build keeps its version")
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
    assertEqual(table.concat(p.containerOrder, ","), "2,1,3,4")
end)

test("database: a deleted id is never handed out again, not even after a reload", function()
    local NS, mocks = fresh()
    local CM = NS.ContainerManager
    CM.Delete(4)
    assertEqual(CM.Create({}), 5, "the counter does not rewind to the freed id")
    mocks.__fireTimers()
    CM.Delete(5)
    NS.Database.PrepareProfile(NS.db.profile)   -- what the next login runs
    -- red under: PrepareProfile setting the counter to the largest id kept plus one
    assertEqual(CM.Create({}), 6)
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
    -- red under: logging once for the whole step, or not at all per profile. 2 profiles x the 6
    -- steps a v1 profile now climbs (v2, v3, v4, v5, v6, v7).
    assertEqual(perProfile, 12, table.concat(lines, " | "))
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
    -- Critical review fix: `uncategorized` is the longhand of "only these categories" too — a narrowed
    -- container that left it nil (the pre-fix bug) would have every unlisted buff flood back in the
    -- moment the ordinary backfill supplied Show for it.
    assertEqual(c.uncategorized, "hide", "the narrowing covers unlisted auras too, not just the named categories")
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

test("v3: a HARMFUL container is never given a weaponEnchants row — that category does not exist for debuffs", function()
    -- red under: liftEnchantFlag writing categories.weaponEnchants on HARMFUL containers too, where
    -- no such category exists (defaults/Categories.lua only lists it under HELPFUL) — inert garbage
    -- that would sit in real saved variables forever.
    local NS = fresh()
    local p = { containers = {
        { auraType = "HARMFUL", filter = { includeEnchants = true, categories = { crowdControl = "hide" } } },
    } }
    NS.Database.MigrateV3(p)
    assertNil(p.containers[1].filter.categories.weaponEnchants)
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

test("v3: a container with no filter.categories table at all converges without an enchant row narrowing it, even once weaponEnchants is a real kind=\"enchant\" category", function()
    local NS = fresh()
    -- weaponEnchants (defaults/Categories.lua) is a real kind=="enchant" category now, so this
    -- appends a SECOND, differently-keyed one alongside it, to prove the exclusion in
    -- filterableCategories is categorical on `kind`, not special-cased to the one key "weaponEnchants"
    -- — it holds however many enchant-kind rows a container's category list carries. Run 1 has no
    -- filter.categories table for liftCategoryWhitelist to act on (it runs BEFORE liftEnchantFlag,
    -- which is the one that creates the table, holding only weaponEnchants) — so the real categories
    -- get their first decision on run 2, the first run where the table liftEnchantFlag made on run 1
    -- exists when liftCategoryWhitelist looks. Without the categorical kind == "enchant" exclusion,
    -- run 2 would see two categories at "show" (both enchant rows), read the container as narrowed,
    -- and sweep every other HELPFUL category to "hide" — a near-total blackout of a container the
    -- player never touched. Run 3 then checks the true fixed point: nothing changes once every
    -- category has its first decision.
    local HELPFUL = NS.Categories.HELPFUL
    HELPFUL[#HELPFUL + 1] = { key = "secondEnchantRow", kind = "enchant", label = "Second enchant row", desc = "test stand-in: a second enchant-kind category" }
    local p = { containers = { { auraType = "HELPFUL", filter = { includeEnchants = true } } } }
    NS.Database.MigrateV3(p)
    -- red under: kind == "enchant" counting toward "was this container narrowed" once it is a real
    -- category, sweeping every other category to "hide" here
    NS.Database.MigrateV3(p)
    local cats = p.containers[1].filter.categories
    for _, cat in ipairs(NS.Categories.HELPFUL) do
        -- `uncategorized` is excluded from filterableCategories for its own reason (core/Database.lua's
        -- comment above the function): MigrateV3 has no opinion about a key the old whitelist model
        -- never had, so it is left nil here for the ordinary backfill to supply "show" afterward.
        if cat.kind ~= "enchant" and cat.kind ~= "uncategorized" then
            assertEqual(cats[cat.key], "show", cat.key .. ": never swept to hide by an enchant row")
        end
    end
    assertNil(cats.uncategorized, "left untouched by the migration, not stamped either way")
    local converged = NS.Database.DeepCopy(p)
    NS.Database.MigrateV3(p)
    local Sig = NS.FilterCompiler.Signature
    assertEqual(Sig(p), Sig(converged), "run 3 is a true no-op at the fixed point")
end)

test("v3: a narrowed container's filter.whitelist is left untouched — the compiler rescues the shown categories now", function()
    -- red under: the id-copying half of the old whitelist lift (liftWhitelistSpells) coming back —
    -- the 2026-09-15 filter-priority revision made rank 3 (a Show beats a Hide on the same aura) the
    -- compiler's own job, for every category kind, so migration must not write filter.whitelist at all.
    local NS = fresh()
    local p = { containers = { { auraType = "HELPFUL",
        filter = { blacklist = { [118038] = true },
            categories = { defensives = "show", raidCDs = "" } } } } }
    NS.Database.MigrateV3(p)
    assertNil(p.containers[1].filter.whitelist)
    -- the blacklist is untouched either — nothing here is the migration's to rewrite any more
    assertEqual(p.containers[1].filter.blacklist[118038], true)
    local c = p.containers[1].filter.categories
    assertEqual(c.defensives, "show")
    assertEqual(c.raidCDs, "hide")
end)

test("v3: uncategorized is left to the ordinary backfill (X-2), not to MigrateV3 itself — UNWHITELISTED branch only", function()
    -- U-1..U-5/X-2: `Cat.DefaultStates()` stamps every category "show" by default, including
    -- `uncategorized` (defaults/Categories.lua), and `NS.CONTAINER_TEMPLATE.filter.categories` is
    -- built from that — so the ordinary per-container backfill (`Database.Backfill` against the
    -- template, run by `backfillContainers`/`PrepareProfile` right after every migration) is what
    -- actually stamps "show" onto an existing container's new key, for a container that was never
    -- narrowed. UNWHITELISTED fixture on purpose — no category here is "show" — because this is only
    -- true in that branch; the WHITELISTED branch stamps "hide" directly, see the test below (review
    -- fix: this test used a WHITELISTED fixture and asserted the widening bug as correct until then).
    local NS = fresh()
    local p = { containers = { { auraType = "HELPFUL",
        filter = { categories = { defensives = "", raidCDs = "hide" } } } } }
    NS.Database.MigrateV3(p)
    assertNil(p.containers[1].filter.categories.uncategorized, "MigrateV3 leaves it nil")
    NS.Database.PrepareProfile(p)
    assertEqual(p.containers[1].filter.categories.uncategorized, "show",
        "the ordinary backfill supplies U-1's default")
end)

-- Critical review fix: the WHITELISTED branch. `filterableCategories`'s exclusion of `uncategorized`
-- was correct for the UNWHITELISTED branch above and WRONG, on its own, here — leaving the key nil
-- for a narrowed container lets the ordinary backfill hand it "show", which
-- `addCategoryGroups` (modules/FilterCompiler.lua) then reads as a real, catch-all-superseding Show
-- category: the container ends up drawing every buff not on any spell list, the exact "silently
-- WIDEN what an already-stored container draws" failure this whole lift exists to prevent.
test("v3: a WHITELISTED (narrowed) container gets uncategorized stamped hide directly from MigrateV3, never left for the backfill", function()
    local NS = fresh()
    local p = { containers = { { auraType = "HELPFUL",
        filter = { categories = { defensives = "show", raidCDs = "" } } } } }
    NS.Database.MigrateV3(p)
    -- red under: the pre-fix bug — MigrateV3 leaving this nil for a narrowed container
    assertEqual(p.containers[1].filter.categories.uncategorized, "hide",
        "the longhand of the old exclusive whitelist's 'only these categories'")
    -- The backfill must not be needed, and must not disagree, either
    NS.Database.PrepareProfile(p)
    assertEqual(p.containers[1].filter.categories.uncategorized, "hide",
        "the backfill only fills a NIL key (== nil, savedvariables-§5) — it never overwrites this")
end)

-- The concrete proof the coordinator asked for: compile the migrated container and confirm an
-- arbitrary id on no spell list — the exact shape of aura that used to flood back in — is NOT drawn.
test("v3: a narrowed container does not gain unlisted auras after migrating — compiled, not just stored", function()
    -- Coordinator review: a label check alone is a proxy, not proof — a Shown token/flag category
    -- (no `includeSpellIDs` at all) would also sail past a "label ~= Uncategorized/All" assertion
    -- while still admitting any aura, listed or not. This is sound for `defensives` specifically only
    -- because it is `spells`-kind, so its lone surviving group MUST be id-restricted to be correct at
    -- all. Assert that directly: exactly one group, and it carries a non-empty `includeSpellIDs` — an
    -- id-agnostic group (no `includeSpellIDs`, e.g. a bare token/flag/dispel group or the catch-all)
    -- would fail this even if it happened to be labeled something other than Uncategorized or All.
    local NS = fresh()
    local p = { containers = { { auraType = "HELPFUL",
        filter = { categories = { defensives = "show", raidCDs = "" } } } } }
    NS.Database.MigrateV3(p)
    NS.Database.PrepareProfile(p)
    local cfg = NS.Database.Merge(NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE), p.containers[1])
    local plan = NS.FilterCompiler.Compile(cfg, {})
    assertEqual(#plan.groups, 1, "narrowed to Defensive cooldowns alone: exactly one group")
    local ids = plan.groups[1].candidateFilters and plan.groups[1].candidateFilters.includeSpellIDs
    assertTrue(type(ids) == "table" and next(ids) ~= nil,
        "the one surviving group is id-restricted, not an unlisted-admitting Uncategorized/catch-all/token/flag group")
end)

test("v3: MigrateV3 returns the number of containers it walked", function()
    local NS = fresh()
    local p = { containers = {
        { auraType = "HELPFUL", filter = { categories = {} } },
        { auraType = "HARMFUL", filter = { categories = {} } },
    } }
    assertEqual(NS.Database.MigrateV3(p), 2)
end)

test("v3: a container skipped for an unrecognized auraType is not counted in the walked total, and logs its own line", function()
    local NS = fresh()
    local lines = {}
    NS.Debug = function(tag, fmt, ...)
        if tag == "Migrate" then
            local n = #lines
            lines[n + 1] = fmt:format(...)
        end
    end
    local p = { containers = {
        [1] = { auraType = "HELPFUL", filter = { categories = {} } },
        [2] = { auraType = "BOGUS", filter = { categories = {} } },
    } }
    -- red under: counting the skipped container toward the return value, which the ladder logs as
    -- "over N container(s)" — overstating how many were actually converted
    assertEqual(NS.Database.MigrateV3(p), 1)
    local named = false
    for _, l in ipairs(lines) do
        if l:find("skipped", 1, true) and l:find("2", 1, true) then named = true end
    end
    assertTrue(named, "a line names the skipped container: " .. table.concat(lines, " | "))
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

test("v7: the current schema version is 7", function()
    local NS = fresh()
    -- red under: the v7 step missing from SCHEMA_STEPS
    assertEqual(NS.Database.CurrentSchemaVersion(), 7)
    assertEqual(NS.db.global.schemaVersion, 7)
end)

test("v3: RunMigrations migrates every stored profile, the inactive one included", function()
    -- UNWHITELISTED fixture on purpose (no category at "show"): this test's own point is the
    -- ordinary-backfill path end to end, which only applies in that branch — see the dedicated
    -- WHITELISTED-branch tests below (and in modules/FilterCompiler.lua's) for the narrowed case,
    -- where `uncategorized` must come out "hide" from MigrateV3 itself, not from the backfill.
    local function raw()
        return {
            seeded = true, nextContainerId = 2, containerOrder = { 1 },
            containers = { [1] = {
                name = "Mine", unit = "player", auraType = "HELPFUL", style = "bars",
                filter = { includeEnchants = true, categories = { defensives = "", raidCDs = "hide" } },
            } },
        }
    end
    local NS = fresh({ savedVariables = { profiles = { Default = raw(), Raid = raw() }, global = { schemaVersion = 2 } } })
    -- red under: a later step (v4) failing to run too, or running for one profile but not the other
    assertEqual(NS.db.global.schemaVersion, NS.Database.CurrentSchemaVersion())
    for _, name in ipairs({ "Default", "Raid" }) do
        local c = NS.db.sv.profiles[name].containers[1]
        -- red under: the step migrating NS.db.profile only (Raid would keep its v2 shape for ever)
        assertEqual(c.filter.categories.defensives, "show", name)
        assertEqual(c.filter.categories.raidCDs, "hide", name)
        assertEqual(c.filter.categories.weaponEnchants, "show", name)
        -- B3 retired `includeEnchants` from CONTAINER_TEMPLATE, so the ordinary backfill no longer
        -- resurrects it on the active profile either: the v3 step's clear sticks for both.
        assertNil(c.filter.includeEnchants, name)
    end
    -- X-2, end to end: the active profile (Default) runs the full pipeline through OnEnable's
    -- PrepareProfile call (tests/fresh_env.lua), so its existing container gets `uncategorized`
    -- stamped "show" by the ordinary backfill (this container was never narrowed — see above). Raid
    -- stays inactive here and is never backfilled (only a profile switch would prepare it) — see the
    -- dedicated test above for that step in isolation, direct on a plain profile table.
    local active = NS.db.sv.profiles.Default.containers[1]
    assertEqual(active.filter.categories.uncategorized, "show", "an existing container gets the new row at Show")
end)

-- ---------------------------------------------------------------------------
-- Schema v4: "Only these categories" retired -> categories.<uncategorized key> = "hide"
-- ---------------------------------------------------------------------------

test("v4: a HELPFUL container with the toggle on ends up with Uncategorized hidden, and the dead key cleared", function()
    local NS = fresh()
    local p = { containers = { { auraType = "HELPFUL",
        filter = { onlyShown = true, categories = { defensives = "show" } } } } }
    local converted, lost = NS.Database.MigrateV4(p)
    assertEqual(converted, 1)
    assertEqual(lost, 0)
    local c = p.containers[1]
    assertEqual(c.filter.categories.uncategorized, "hide", "the toggle's old effect, preserved")
    assertNil(c.filter.onlyShown, "the dead key is cleared")
    -- untouched otherwise — the migration does not narrate a decision about defensives
    assertEqual(c.filter.categories.defensives, "show")
end)

-- Fix round 3: the owner restored the debuff row, with Hide reproducing the retired toggle exactly
-- (modules/FilterCompiler.lua's `hasUnion` gate — the compiler-side proof lives in
-- tests/test_filtercompiler.lua). A HARMFUL container now converts too, the same as HELPFUL.
test("v4: a HARMFUL container with the toggle on ends up with Uncategorized (debuffs) hidden, and the dead key cleared", function()
    local NS = fresh()
    local p = { containers = { { auraType = "HARMFUL",
        filter = { onlyShown = true, categories = { crowdControl = "hide" } } } } }
    local converted, lost = NS.Database.MigrateV4(p)
    assertEqual(converted, 1)
    assertEqual(lost, 0)
    local c = p.containers[1]
    assertEqual(c.filter.categories.uncategorizedDebuffs, "hide", "the toggle's old effect, preserved")
    assertNil(c.filter.onlyShown, "the dead key is cleared")
    assertEqual(c.filter.categories.crowdControl, "hide")
end)

test("v4: a container with the toggle off or absent is untouched", function()
    local NS = fresh()
    local p = { containers = {
        { auraType = "HELPFUL", filter = { onlyShown = false, categories = { defensives = "show" } } },
        { auraType = "HELPFUL", filter = { categories = { defensives = "show" } } },
    } }
    local before = NS.Database.DeepCopy(p)
    local converted, lost = NS.Database.MigrateV4(p)
    assertEqual(converted, 0)
    assertEqual(lost, 0)
    local Sig = NS.FilterCompiler.Signature
    assertEqual(Sig(p), Sig(before), "off or absent: not even the dead key is touched")
end)

test("v4: an ENCHANT container with the toggle on is neither converted nor lost — it compiles to no groups, so nothing was ever lost", function()
    -- red under: counting an ENCHANT container as `lost`, which docs/schema.md and the [Migrate]
    -- line would then overstate — FC.Compile's compileEnchant (retired at schema v5) never read filter.onlyShown at all.
    local NS = fresh()
    local p = { containers = { { auraType = "ENCHANT",
        filter = { onlyShown = true, categories = {} } } } }
    local converted, lost, lostList = NS.Database.MigrateV4(p)
    assertEqual(converted, 0)
    assertEqual(lost, 0)
    assertEqual(#lostList, 0)
    assertNil(p.containers[1].filter.onlyShown, "the dead key is still cleared, just not counted")
end)

test("v4: an unrecognized auraType with the toggle on is genuinely lost, named in lostList, and its dead key still cleared", function()
    -- The honest answer for a shape that carries no Uncategorized category and is not ENCHANT
    -- either (a corrupt or future auraType this migration cannot predict): counted, named, and the
    -- SCHEMA_STEPS v4 step turns this into a plain NS.Print notice — nothing invented, nothing silent.
    local NS = fresh()
    local p = { containers = { [7] = { auraType = "BOGUS", name = "Weird One",
        filter = { onlyShown = true, categories = {} } } } }
    local converted, lost, lostList = NS.Database.MigrateV4(p)
    assertEqual(converted, 0)
    assertEqual(lost, 1)
    assertEqual(#lostList, 1)
    assertEqual(lostList[1].id, 7)
    assertEqual(lostList[1].name, "Weird One")
    assertEqual(lostList[1].auraType, "BOGUS")
    assertNil(p.containers[7].filter.onlyShown, "the dead key is cleared even though nothing could be preserved")
end)

test("v4: MigrateV4 is idempotent", function()
    local NS = fresh()
    local function scenario()
        return { containers = {
            { auraType = "HELPFUL", filter = { onlyShown = true, categories = { defensives = "show" } } },
            { auraType = "HARMFUL", filter = { onlyShown = true, categories = { crowdControl = "hide" } } },
            { auraType = "ENCHANT", filter = { onlyShown = true, categories = {} } },
            { auraType = "BOGUS", filter = { onlyShown = true, categories = {} } },
            { auraType = "HELPFUL", filter = { categories = { defensives = "show" } } },
        } }
    end
    local once = scenario()
    NS.Database.MigrateV4(once)
    local twice = NS.Database.DeepCopy(once)
    local converted, lost, lostList = NS.Database.MigrateV4(twice)
    -- red under: a second run re-counting or re-touching a container the first run already decided
    assertEqual(converted, 0, "nothing left at onlyShown == true to convert again")
    assertEqual(lost, 0)
    assertEqual(#lostList, 0)
    local Sig = NS.FilterCompiler.Signature
    assertEqual(Sig(twice), Sig(once), "a second run is a true no-op")
end)

-- Item 3, fix round 3: NS.Debug alone is not enough — it is gated on a flag off by default, so a
-- player who never turned on debug logging would see NOTHING about a container that just silently
-- lost a capability. NS.Print is ungated: it always reaches the chat frame.
test("v4: a genuinely lost container's notice reaches NS.Print, not just NS.Debug (item 3)", function()
    local lines = {}
    local NS = fresh({
        savedVariables = { profiles = { Default = {
            seeded = true, nextContainerId = 2, containerOrder = { 1 },
            containers = { [1] = { name = "Weird One", unit = "player", auraType = "BOGUS", style = "bars",
                filter = { onlyShown = true, categories = {} } } },
        } }, global = { schemaVersion = 3 } },
        before = function(mocks)
            rawset(mocks.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
                lines[#lines + 1] = tostring(msg)
            end)
        end,
    })
    assertEqual(NS.db.global.schemaVersion, NS.Database.CurrentSchemaVersion())
    local found = false
    for _, l in ipairs(lines) do
        -- red under: the debug flag being off (the default) swallowing the only notice a player gets
        if l:find("Weird One", 1, true) and l:find("could not be carried over", 1, true) then found = true end
    end
    assertTrue(found, "NS.Print names the lost container plainly: " .. table.concat(lines, " | "))
end)

test("v4: no notice is printed when nothing was lost", function()
    local lines = {}
    local NS = fresh({
        savedVariables = { profiles = { Default = {
            seeded = true, nextContainerId = 2, containerOrder = { 1 },
            containers = { [1] = { name = "Mine", unit = "player", auraType = "HELPFUL", style = "bars",
                filter = { onlyShown = true, categories = { defensives = "show" } } } },
        } }, global = { schemaVersion = 3 } },
        before = function(mocks)
            rawset(mocks.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
                lines[#lines + 1] = tostring(msg)
            end)
        end,
    })
    assertEqual(NS.db.global.schemaVersion, NS.Database.CurrentSchemaVersion())
    for _, l in ipairs(lines) do
        assertTrue(l:find("could not be carried over", 1, true) == nil, "no lost-capability notice: " .. l)
    end
end)

test("database: a fresh profile seeds the Player cooldowns text container last, showing only two buff lists", function()
    local NS = fresh()
    local list = NS.Database.GetContainers()
    local n = #NS.STARTER_CONTAINERS
    assertEqual(#list, n)
    local c = list[n]
    -- red under: the starter list without its fourth entry, or seeded in another style
    assertEqual(c.name, "Player cooldowns")
    assertEqual(c.style, "text")
    assertEqual(c.unit, "player"); assertEqual(c.auraType, "HELPFUL")
    assertEqual(c.filter.categories.offensiveCDs, "show")
    assertEqual(c.filter.categories.defensives, "show")
    assertEqual(c.filter.categories.uncategorized, "hide")
    assertEqual(c.filter.categories.bigDefensive, "hide")
    assertEqual(c.text.template, NS.CONTAINER_TEMPLATE.text.template, "the rest is the template's")
end)

-- ---------------------------------------------------------------------------
-- Schema v5: the Weapon enchants aura type retires (feedback #6)
-- ---------------------------------------------------------------------------

--- A v4 container with the ENCHANT aura type, styled and placed as a player would have left it.
local function enchantContainer()
    return {
        name = "My enchants", enabled = true, unit = "target", auraType = "ENCHANT", style = "icons",
        filter = { hidePermanentEnchants = false, categories = { defensives = "show" }, sortDirection = "reverse" },
        position = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 12, y = -34 },
        icons = { width = 40, height = 40 },
    }
end

test("v5: an ENCHANT container becomes a player buff container showing only Weapon enchants, its look kept (feedback #6)", function()
    local NS = fresh()
    local p = { containers = { [7] = enchantContainer() } }
    local converted = NS.Database.MigrateV5(p)
    local c = p.containers[7]
    assertEqual(converted, 1)
    -- red under: the aura type left as ENCHANT (C.AURA_TYPES no longer offers it)
    assertEqual(c.auraType, "HELPFUL")
    -- red under: the unit carried over (enchants are only ever the player's)
    assertEqual(c.unit, "player")
    local cats = c.filter.categories
    assertEqual(cats.weaponEnchants, "show")
    for _, def in ipairs(NS.Categories.For("HELPFUL")) do
        if def.key ~= "weaponEnchants" then
            -- red under: a buff category left at Show (the container would draw auras too)
            assertEqual(cats[def.key], "hide", def.key)
        end
    end
    assertEqual(cats.uncategorized, "hide", "Uncategorized is hidden too")
    -- red under: the migration resetting what the player set
    assertEqual(c.filter.hidePermanentEnchants, false, "hide-permanent carries over")
    assertEqual(c.filter.sortDirection, "reverse")
    assertEqual(c.style, "icons"); assertEqual(c.icons.width, 40)
    assertEqual(c.position.x, 12); assertEqual(c.name, "My enchants")
end)

test("v5: a whitelist on the ENCHANT container is cleared, so the migrated container draws no buffs (fix round 1, review Important #1)", function()
    local NS = fresh()
    local c = enchantContainer()
    c.filter.whitelist = { [500] = true, [600] = true }
    local p = { containers = { [9] = c } }
    NS.Database.MigrateV5(p)
    -- red under: the whitelist kept, so FC.Compile's addWhitelistGroup still draws those buffs
    assertTrue(p.containers[9].filter.whitelist == nil, "the whitelist is cleared, not merely left empty")
    local plan = NS.FilterCompiler.Compile(p.containers[9], NS.FilterCompiler.ProfileContext())
    assertEqual(#plan.groups, 0, "no group at all -- only the enchant slots")
end)

test("v5: a container with no filter table at all still converts cleanly (review Minor #2)", function()
    local NS = fresh()
    local p = { containers = { [1] = { name = "Bare", unit = "target", auraType = "ENCHANT" } } }
    -- red under: MigrateV5 indexing a nil filter instead of building one
    assertEqual(NS.Database.MigrateV5(p), 1)
    local c = p.containers[1]
    assertEqual(c.auraType, "HELPFUL"); assertEqual(c.unit, "player")
    assertEqual(c.filter.categories.weaponEnchants, "show")
end)

test("v5: only ENCHANT containers are touched, and a second run changes nothing (feedback #6)", function()
    local NS = fresh()
    local buff = { name = "Buffs", unit = "target", auraType = "HELPFUL", filter = { categories = { defensives = "hide" } } }
    local p = { containers = { [1] = buff, [2] = enchantContainer() } }
    NS.Database.MigrateV5(p)
    -- red under: every container rewritten as an enchant container
    assertEqual(buff.unit, "target"); assertEqual(buff.filter.categories.defensives, "hide")
    assertTrue(buff.filter.categories.weaponEnchants == nil, "a buff container's categories are its own")
    local Sig = NS.FilterCompiler.Signature
    local once = Sig(p)
    -- red under: a second run re-stamping categories or re-counting a container it already converted
    assertEqual(NS.Database.MigrateV5(p), 0, "nothing left to convert")
    assertEqual(Sig(p), once)
end)

test("v5: RunMigrations converts every stored profile, and the result draws enchants only (feedback #6)", function()
    local function raw()
        return { seeded = true, nextContainerId = 3, containerOrder = { 2 }, containers = { [2] = enchantContainer() } }
    end
    local NS = fresh({ savedVariables = { profiles = { Default = raw(), Raid = raw() }, global = { schemaVersion = 4 } } })
    assertEqual(NS.db.global.schemaVersion, NS.Database.CurrentSchemaVersion())
    for _, name in ipairs({ "Default", "Raid" }) do
        local c = NS.db.sv.profiles[name].containers[2]
        -- red under: the step migrating the active profile only
        assertEqual(c.auraType, "HELPFUL", name)
        assertEqual(c.filter.categories.weaponEnchants, "show", name)
    end
    local plan = NS.FilterCompiler.Compile(NS.db.sv.profiles.Default.containers[2], NS.FilterCompiler.ProfileContext())
    local slotCount, groupCount, warnCount = #plan.enchants.slots, #plan.groups, #plan.warnings
    assertEqual(slotCount, 3, "the three enchant slots")
    assertEqual(groupCount, 0, "and no aura group")
    -- red under: finishWarnings calling an enchant-only container one that can never match
    assertEqual(warnCount, 0, table.concat(plan.warnings, " | "))
end)

test("v5: MigrateV5 logs one [Migrate] line per converted container, naming it (feedback #6)", function()
    local NS = fresh()
    local lines = {}
    NS.Debug = function(tag, fmt, ...)
        if tag == "Migrate" then
            local n = #lines
            lines[n + 1] = fmt:format(...)
        end
    end
    NS.Database.MigrateV5({ containers = { [3] = enchantContainer(), [4] = { auraType = "HARMFUL" }, [5] = enchantContainer() } })
    -- red under: the migration silent per container, or logging the untouched debuff one
    assertEqual(table.concat(lines, " | "), "v5 container '3' (My enchants): now a player buff container showing only Weapon enchants"
        .. " | v5 container '5' (My enchants): now a player buff container showing only Weapon enchants")
end)

test("v5: the profile's retired dispelColors.None leaf is cleared (feedback #7)", function()
    local NS = fresh()
    local p = { dispelColors = { Magic = { r = 0.2, g = 0.6, b = 1, a = 1 }, None = { r = 0.8, g = 0, b = 0, a = 1 } },
        containers = {} }
    NS.Database.MigrateV5(p)
    -- red under: MigrateV5 leaving a color nothing reads in every old profile
    assertEqual(p.dispelColors.None, nil)
    assertEqual(p.dispelColors.Magic.r, 0.2, "the palette's colors stay")
end)

-- smoke batch 2, B2-2: the pickers list containers by name, case-insensitively, the id breaking a
-- tie. Names are unique regardless of case (CM.UniqueName), so a tie is written straight to the store.
test("database: GetContainersByName sorts by name, case-insensitively, the id breaking a tie; display order untouched (B2-2)", function()
    local NS = fresh()
    local cs = NS.db.profile.containers
    cs[1].name, cs[2].name, cs[3].name, cs[4].name = "zeta", "Alpha", "beta", "ALPHA"
    local ids = {}
    for i, c in ipairs(NS.Database.GetContainersByName()) do ids[i] = c.id end
    -- red under: display order (1,2,3,4), or a byte sort (4,2,3,1: "ALPHA" sorts before "Alpha")
    assertEqual(table.concat(ids, ","), "2,4,3,1")
    ids = {}
    for i, c in ipairs(NS.Database.GetContainers()) do ids[i] = c.id end
    assertEqual(table.concat(ids, ","), "1,2,3,4", "GetContainers keeps the display order")
    assertEqual(table.concat(NS.db.profile.containerOrder, ","), "1,2,3,4", "and the store is untouched")
end)

-- ── user categories: storage, keying, dynamic rows (issue #10 checkpoint 3) ────────────────────
--
-- This is the checkpoint that can corrupt stored player data -- a spell list silently deleted by an
-- unrelated write, a dead category key written into every container of every profile -- so the cases
-- below are as much the deliverable as the code is.

--- The saved variables a session left behind, fed to a new one: a genuine reload, not a second read
--- of the same live tables.
local function reload()
    local saved = _G.AuraMasterDB
    local copy = {}
    local function deep(v)
        if type(v) ~= "table" then return v end
        local out = {}
        for k, item in pairs(v) do out[k] = deep(item) end
        return out
    end
    for k, v in pairs(saved or {}) do copy[k] = deep(v) end
    return fresh({ savedVariables = copy })
end

test("v6: MigrateV6 stamps the user-category store, and a second run changes nothing", function()
    local NS = fresh()
    local p = {}
    assertEqual(NS.Database.MigrateV6(p), 0)
    assertEqual(type(p.userCategories), "table")
    assertEqual(type(p.userCategoryOrder), "table")
    p.userCategories.userabcdefghij = { key = "userabcdefghij", name = "Mine", auraType = "HELPFUL" }
    p.userCategoryOrder[1] = "userabcdefghij"
    -- red under: a step that recreates or clears what it already stamped
    assertEqual(NS.Database.MigrateV6(p), 1, "the second run counts what is there and converts nothing")
    assertEqual(#p.userCategoryOrder, 1)
    assertEqual(p.userCategories.userabcdefghij.name, "Mine")
    -- A hand-edited or corrupt leaf is REPLACED rather than left for later code to index.
    p.userCategories = "junk"
    NS.Database.MigrateV6(p)
    assertEqual(type(p.userCategories), "table")
    assertEqual(NS.Database.MigrateV6(nil), 0, "a non-table profile is not an error")
end)

test("v6: a profile that predates user categories climbs the ladder and stays valid", function()
    local function raw()
        return {
            seeded = true, nextContainerId = 2, containerOrder = { 1 },
            containers = { [1] = { name = "Mine", unit = "player", auraType = "HELPFUL", style = "bars" } },
        }
    end
    local NS = fresh({ savedVariables = { profiles = { Default = raw(), Raid = raw() }, global = { schemaVersion = 5 } } })
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
    for _, name in ipairs({ "Default", "Raid" }) do
        local p = NS.db.sv.profiles[name]
        -- red under: the step touching the active profile only, as every step before it must not
        assertEqual(type(p.userCategories), "table", name)
        assertEqual(type(p.userCategoryOrder), "table", name)
        assertEqual(next(p.userCategories), nil, name .. " invented a category")
    end
    assertEqual(NS.ValidateSchema(), 0, "and every schema row still resolves")
end)

test("v7: MigrateV7 retires Consumables and seeds the new categories from where their auras fell", function()
    local NS = fresh()
    local p = {
        categorySpells = {
            consumables = { [431971] = false, [900001] = true },
            support = { [1459] = false, [10060] = false },   -- a group buff, and a Support starter that stays
            utility = { [58984] = false },                   -- Shadowmeld, now a racial
            groupBuffs = { [21562] = true },
        },
        containers = {
            [1] = { filter = { categories = { support = "hide", uncategorized = "hide", consumables = "show" } } },
            [2] = { filter = { categories = { support = "show", uncategorized = "show" } } },
            [3] = { filter = { categories = { support = "hide", groupBuffs = "show" } } },
            [4] = { name = "no filter" },
        },
    }
    assertEqual(NS.Database.MigrateV7(p), 3)
    local c1, c2, c3 = p.containers[1].filter.categories, p.containers[2].filter.categories,
        p.containers[3].filter.categories
    -- red under: leaving the retired key behind
    assertNil(c1.consumables)
    -- red under: leaving the new keys to the backfill's Show, which would draw raid buffs and
    -- stances on a container that hid Support or Uncategorized
    assertEqual(c1.groupBuffs, "hide", "Group buffs takes Support's state")
    assertEqual(c1.stances, "hide", "Stances takes Uncategorized's")
    assertEqual(c1.racials, "hide", "and so does Racials")
    assertEqual(c2.groupBuffs, "show")
    assertEqual(c2.racials, "show")
    -- red under: overwriting a state already stored
    assertEqual(c3.groupBuffs, "show", "a stored state is a choice")
    assertNil(c3.stances, "an absent source leaves the key to the backfill")
    local spellEdits = p.categorySpells
    assertNil(spellEdits.consumables, "Consumables edits go with the category")
    -- red under: the player's edits staying on the list their ids left
    assertEqual(spellEdits.groupBuffs[1459], false, "a Support edit on a group buff follows it")
    assertEqual(spellEdits.groupBuffs[21562], true, "beside what Group buffs already held")
    assertNil(spellEdits.support[1459])
    assertEqual(spellEdits.support[10060], false, "a Support edit on an id that stayed is kept")
    assertEqual(spellEdits.racials[58984], false, "Shadowmeld's Utility edit follows it to Racials")
    assertNil(spellEdits.utility, "a list left with no edits is not stored")
end)

test("v7: a second MigrateV7 run changes nothing, and a new key's stored edit wins over a moved one", function()
    local NS = fresh()
    local p = {
        categorySpells = { support = { [6673] = false }, groupBuffs = { [6673] = true } },
        containers = { [1] = { filter = { categories = { support = "hide", uncategorized = "show" } } } },
    }
    NS.Database.MigrateV7(p)
    -- red under: a moved edit overwriting one the new category already had
    assertEqual(p.categorySpells.groupBuffs[6673], true)
    assertNil(p.categorySpells.support)
    local cats = p.containers[1].filter.categories
    local snapshot = {}
    for k, v in pairs(cats) do snapshot[k] = v end
    p.containers[1].filter.categories.support = "show"   -- a later change of Support's state
    NS.Database.MigrateV7(p)
    -- red under: re-seeding from the source on every run
    assertEqual(cats.groupBuffs, snapshot.groupBuffs, "the seed happens once")
    assertEqual(cats.stances, "show")
end)

test("v7: a v6 profile climbs to v7 with every schema row still resolving", function()
    local function raw()
        return {
            seeded = true, nextContainerId = 2, containerOrder = { 1 }, userCategories = {}, userCategoryOrder = {},
            containers = { [1] = { name = "Mine", unit = "player", auraType = "HELPFUL", style = "bars",
                filter = { categories = { support = "hide", uncategorized = "hide", consumables = "hide" } } } },
        }
    end
    local NS = fresh({ savedVariables = { profiles = { Default = raw(), Raid = raw() }, global = { schemaVersion = 6 } } })
    assertEqual(NS.db.global.schemaVersion, 7)
    for _, name in ipairs({ "Default", "Raid" }) do
        local cats = NS.db.sv.profiles[name].containers[1].filter.categories
        -- red under: the step touching the active profile only
        assertNil(cats.consumables, name)
        assertEqual(cats.groupBuffs, "hide", name)
        assertEqual(cats.racials, "hide", name)
    end
    assertEqual(NS.ValidateSchema(), 0, "and every schema row still resolves")
end)

test("user categories: one round-trips through a reload, with its spells", function()
    local NS = fresh()
    local key = NS.Categories.CreateUserCategory("Affixes", "HELPFUL")
    assertTrue(key ~= nil, "created")
    NS.SetByPath("categorySpells", { [key] = { [424242] = true, [424243] = true } })
    -- The list is categorySpells[key] like every other category's edits: no second store.
    assertEqual(NS.db.profile.categorySpells[key][424242], true)

    local NS2 = reload()
    local def = NS2.Categories.Find("HELPFUL", key)
    -- red under: the record surviving but the definition not being rebuilt at load
    assertTrue(def ~= nil, "the definition is materialized again at load")
    assertEqual(def.label, "Affixes")
    assertEqual(def.auraType, "HELPFUL")
    local spells = NS2.FilterCompiler.CategorySpells(def, NS2.db.profile.categorySpells)
    assertEqual(spells[424242], true)
    assertEqual(spells[424243], true)
    assertEqual(NS2.ValidateSchema(), 0)
end)

test("user categories: the sync runs BEFORE PrepareProfile, so a stored one reaches every container", function()
    -- THE ORDER IN NS.RunMigrations IS LOAD-BEARING (core/Database.lua). PrepareProfile's
    -- backfillContainers is what stamps the container template's category keys into every stored
    -- container, and the template only carries a user category's key once the sync has materialized
    -- it. Run the two the other way round and the backfill walks a template that does not yet know
    -- the key, so the stored container carries NO state for it.
    --
    -- A category created in this session hides the bug -- Cat.CreateUserCategory runs its own
    -- PrepareProfile -- so the shape that exposes it is a record already on disk whose key no
    -- container has yet: a profile written by another client, or an import (#9).
    local K = "userabcdefghij"
    local NS = fresh({ savedVariables = { global = { schemaVersion = 6 }, profiles = { Default = {
        seeded = true, nextContainerId = 2, containerOrder = { 1 },
        containers = { [1] = { name = "Mine", unit = "player", auraType = "HELPFUL", style = "bars" } },
        userCategories = { [K] = { key = K, name = "Affixes", auraType = "HELPFUL" } },
        userCategoryOrder = { K },
    } } } })
    assertTrue(NS.Categories.Find("HELPFUL", K) ~= nil, "materialized at load (the premise)")
    local con = NS.db.profile.containers[1]
    -- red under: swapping the two lines in NS.RunMigrations. The compiler would not notice
    -- (splitCategories reads an absent state as Show, the default anyway), but the settings panel
    -- would: a ChoiceGrid cell lights by comparing the STORED value against its column, so the row
    -- draws with neither Show nor Hide lit until something else writes it.
    assertEqual(con.filter.categories[K], "show", "the stored container was backfilled with the key")
    assertEqual(NS.ValidateSchema(), 0)
end)

test("user categories: the schema row resolves, and the seam reads and writes it per container", function()
    local NS = fresh()
    local key = NS.Categories.CreateUserCategory("Affixes", "HELPFUL")
    local path = "container.filter.categories." .. key
    local row = NS.FindSchemaRow(path)
    -- red under: registering the definition without its row, which would leave the category
    -- invisible to /am get|set|list, to a page's Defaults and to every reset
    assertTrue(row ~= nil, "a schema row exists for a key that did not exist at load")
    assertEqual(row.default, "show", "stamped from the container template, like every other row")
    assertEqual(row.grid, "custom")
    assertEqual(row.type, "string")
    assertTrue(row.auraTypes.HELPFUL, "offered on buff containers")
    assertTrue(row.auraTypes.HARMFUL == nil, "and not on debuff ones")
    assertEqual(row.label, "Affixes", "the player's own text, straight through NS.L's miss path")
    assertEqual(NS.DefaultFor(path), "show")
    assertEqual(NS.CONTAINER_TEMPLATE.filter.categories[key], "show")

    local id = NS.Database.GetContainers()[1].id
    assertEqual(NS.GetSetting(path, id), "show", "the backfill stamped it into every stored container")
    NS.SetByPath(path, "hide", id)
    assertEqual(NS.GetSetting(path, id), "hide")
    assertEqual(NS.ValidateSchema(), 0)
end)

test("user categories: Cat.AuraTypeOf answers for a user category KEY, not only for its definition", function()
    -- Checkpoint 2 left the key form answering for the SHIPPED lists only and said so in its own doc
    -- comment; this is the case that closes it. It answers because the definition is materialized
    -- INTO those lists, which is the whole reason materialization was chosen over a side list.
    local NS = fresh()
    local buffs = NS.Categories.CreateUserCategory("Mine", "HELPFUL")
    local debuffs = NS.Categories.CreateUserCategory("Theirs", "HARMFUL")
    assertEqual(NS.Categories.AuraTypeOf(buffs), "HELPFUL")
    assertEqual(NS.Categories.AuraTypeOf(debuffs), "HARMFUL")
    assertEqual(NS.Categories.AuraTypeOf(NS.Categories.Find("HARMFUL", debuffs)), "HARMFUL")
    -- red under: the key form answering for a key nothing knows, which a stored container may well
    -- name (a retired key, and after checkpoint 5 a deleted user category)
    assertTrue(NS.Categories.AuraTypeOf("userffffffffff") == nil)
end)

test("user categories: a profile switch swaps the set and leaves no stale definition, row or template key", function()
    local NS = fresh()
    local key = NS.Categories.CreateUserCategory("Only in Default", "HELPFUL")
    local path = "container.filter.categories." .. key
    assertTrue(NS.FindSchemaRow(path) ~= nil)

    NS.db:SetProfile("Raid")
    -- red under: NS.Schema having only an append path, so the old profile's row survives. The severe
    -- consequence is not the failing validator but the stale DEFINITION below: categorizedUnion
    -- would read the NEW profile's categorySpells under the OLD profile's key and quietly take ids
    -- out of the complement `uncategorized` is defined against.
    assertTrue(NS.Categories.Find("HELPFUL", key) == nil, "the definition went")
    assertTrue(NS.FindSchemaRow(path) == nil, "and the row with it")
    assertTrue(NS.CONTAINER_TEMPLATE.filter.categories[key] == nil, "and the template key")
    assertFalse(NS.Categories.IsSpellCategory(key), "so nothing compiles against it")
    assertEqual(NS.ValidateSchema(), 0)

    NS.db:SetProfile("Default")
    assertTrue(NS.Categories.Find("HELPFUL", key) ~= nil, "and it all comes back on the way home")
    assertTrue(NS.FindSchemaRow(path) ~= nil)
    assertEqual(NS.ValidateSchema(), 0)
end)

test("user categories: a new key collides with nothing shipped and with nothing in any stored profile", function()
    local NS = fresh()
    local mine = NS.Categories.CreateUserCategory("Mine", "HELPFUL")
    -- A key living in a profile this session is not running: exactly the case a per-profile counter
    -- cannot see, and the reason the scan is account-wide (defaults/UserCategories.lua's Cat.NewUserKey).
    NS.db.sv.profiles.Elsewhere = { userCategories = { userzzzzzzzzzz = { key = "userzzzzzzzzzz", name = "Theirs", auraType = "HARMFUL" } } }
    local taken = NS.Categories.UserKeysInUse(NS.db)
    assertTrue(taken[mine], "the active profile's key")
    assertTrue(taken.userzzzzzzzzzz, "and an inactive profile's")
    for _ = 1, 50 do
        local key = NS.Categories.NewUserKey(taken)
        assertTrue(taken[key] == nil, key .. " collides with a stored key")
        assertTrue(NS.Categories.Find("HELPFUL", key) == nil, key .. " collides with a shipped key")
        assertTrue(NS.Categories.Find("HARMFUL", key) == nil, key .. " collides with a shipped key")
    end
end)

test("user categories: a rename keeps the key, so a container's stored Show/Hide survives it", function()
    local NS = fresh()
    local key = NS.Categories.CreateUserCategory("Frist draft", "HELPFUL")
    local path = "container.filter.categories." .. key
    local id = NS.Database.GetContainers()[1].id
    NS.SetByPath(path, "hide", id)
    NS.SetByPath("categorySpells", { [key] = { [424242] = true } })

    assertTrue(NS.Categories.RenameUserCategory(key, "  First draft  "))
    -- red under: a rename that re-keys, which orphans every container's stored state, the schema row
    -- and the spell list in one act. This is the failure mode issue #10 names by name.
    assertEqual(NS.db.profile.userCategories[key].name, "First draft", "trimmed, and stored canonically")
    assertEqual(NS.Categories.Find("HELPFUL", key).label, "First draft", "the label follows")
    assertEqual(NS.FindSchemaRow(path).label, "First draft", "and so does the row's")
    assertEqual(NS.GetSetting(path, id), "hide", "the container's own decision is untouched")
    assertEqual(NS.db.profile.categorySpells[key][424242], true, "and so is the list")
    assertEqual(NS.ValidateSchema(), 0)

    -- The refusals. A shipped category is not the player's to rename, and a name has to be a name.
    assertTrue(NS.Categories.RenameUserCategory("defensives", "Mine") == nil)
    assertTrue(NS.Categories.RenameUserCategory(key, "   ") == nil)
    assertEqual(NS.Categories.Find("HELPFUL", key).label, "First draft", "a refused rename changes nothing")
    -- A duplicate name is allowed and merely reported: the key is identity, and two categories called
    -- the same thing are two categories (checkpoint 6 warns, it does not block).
    local other = NS.Categories.CreateUserCategory("First draft", "HELPFUL")
    assertTrue(other ~= nil and other ~= key)
    assertTrue(NS.Categories.UserCategoryNameTaken(NS.db.profile, "first draft", other))
    assertFalse(NS.Categories.UserCategoryNameTaken(NS.db.profile, "Nobody's", nil))
end)

test("user categories: a stored record alone protects its spell list from the categorySpells write", function()
    -- THE DATA-LOSS GUARD. settings/Schema.lua's normalizer drops every key it does not recognize
    -- and the set is written WHOLE on every edit of ANY category, so a user key whose definition had
    -- failed to materialize would have its entire list deleted by one unrelated write. The record is
    -- the thing that cannot be half-built, so the record is what the normalizer asks about.
    local NS = fresh()
    local key = "userdeadbeef0"
    NS.db.profile.userCategories[key] = { key = key, name = "Unmaterialized", auraType = "HELPFUL" }
    assertTrue(NS.Categories.Find("HELPFUL", key) == nil, "no definition: the sync has not run")
    NS.SetByPath("categorySpells", { [key] = { [424242] = true } })
    -- red under: normalizeCategoryEdits asking only Cat.IsSpellCategory
    assertEqual(NS.db.profile.categorySpells[key][424242], true, "the list survived the write")
    -- And a key with neither a definition nor a record is still dropped, as it always was.
    NS.SetByPath("categorySpells", { [key] = { [424242] = true }, nonsense = { [1] = true } })
    assertTrue(NS.db.profile.categorySpells.nonsense == nil)
    assertEqual(NS.db.profile.categorySpells[key][424242], true)
end)

-- ── user categories: deletion and cleanup (issue #10 checkpoint 5) ─────────────────────────────
--
-- Cleanup is EAGER, across every stored profile, and the argument is in defaults/UserCategories.lua
-- above `forgetUserKey`. These cases are the other half of it: eager is only correct if it reaches
-- the profiles nobody is logged into AND leaves everything that is not this category alone.

--- A stored profile that is not the active one, carrying `key` in a container and in its spell
--- edits -- the debris shape a container copy or a profile copy leaves behind.
local function inactiveProfileWith(NS, name, key, record)
    NS.db.sv.profiles[name] = {
        seeded = true, nextContainerId = 2, containerOrder = { 1 },
        containers = { [1] = { id = 1, name = "Theirs", unit = "player", auraType = "HELPFUL",
            filter = { categories = { [key] = "hide", defensives = "hide" } } } },
        categorySpells = { [key] = { [424242] = true }, defensives = { [871] = false } },
        userCategories = record and { [key] = record } or {},
        userCategoryOrder = record and { key } or {},
    }
    return NS.db.sv.profiles[name]
end

test("user categories: deleting one clears the record, the list and every container's state, in the active profile and in an inactive one", function()
    local NS = fresh()
    local key = NS.Categories.CreateUserCategory("Affixes", "HELPFUL")
    local keep = NS.Categories.CreateUserCategory("Kept", "HELPFUL")
    local path = "container.filter.categories." .. key
    local keepPath = "container.filter.categories." .. keep
    local id = NS.Database.GetContainers()[1].id
    NS.SetByPath(path, "hide", id)
    NS.SetByPath(keepPath, "hide", id)
    NS.SetByPath("categorySpells", { [key] = { [424242] = true }, [keep] = { [424243] = true },
        defensives = { [871] = false } })
    local other = inactiveProfileWith(NS, "Raid", key)

    assertTrue(NS.Categories.DeleteUserCategory(key), "the act answers true")

    -- The record, the order entry and the player's list for it.
    assertTrue(NS.db.profile.userCategories[key] == nil, "the record went")
    assertEqual(table.concat(NS.db.profile.userCategoryOrder, ","), keep, "and its order entry")
    assertTrue(NS.db.profile.categorySpells[key] == nil, "and the spell list it owned")
    -- The three mirrors the sync owns.
    assertTrue(NS.Categories.Find("HELPFUL", key) == nil, "the definition went")
    assertTrue(NS.FindSchemaRow(path) == nil, "and the schema row")
    assertTrue(NS.CONTAINER_TEMPLATE.filter.categories[key] == nil, "and the container template key")
    -- The stored leaf in the ACTIVE profile's container...
    assertTrue(NS.db.profile.containers[id].filter.categories[key] == nil, "the active container's state")
    -- ...and in a profile nobody is logged into. red under: a delete that only walks db.profile, or
    -- a lazy prune that waits for the player to switch to that profile.
    assertTrue(other.containers[1].filter.categories[key] == nil, "an inactive profile's container too")
    assertTrue(other.categorySpells[key] == nil, "and its spell edits")

    -- NOTHING ELSE MOVED. The other user category keeps its record, its row, its list and the
    -- container's own decision about it; so does a shipped one, in both profiles.
    assertTrue(NS.db.profile.userCategories[keep] ~= nil)
    assertEqual(NS.GetSetting(keepPath, id), "hide", "the other category's stored state is untouched")
    assertEqual(NS.db.profile.categorySpells[keep][424243], true)
    assertEqual(NS.GetSetting("container.filter.categories.defensives", id), "show")
    assertEqual(NS.db.profile.categorySpells.defensives[871], false)
    assertEqual(other.containers[1].filter.categories.defensives, "hide", "in the inactive profile too")
    assertEqual(other.categorySpells.defensives[871], false)
    assertEqual(NS.ValidateSchema(), 0, "and the validator is clean the moment the act returns")
end)

test("user categories: deleting one leaves a COPY of it in another profile entirely alone", function()
    -- AceDB's profile copy duplicates userCategories wholesale, so two profiles can legitimately hold
    -- a record under ONE key, each with its own name, list and containers. The eager sweep therefore
    -- skips any profile that still holds a record of its own (defaults/UserCategories.lua's
    -- forgetUserKey). red under: sweeping by key alone, which would silently gut the other profile's
    -- category and leave its record pointing at nothing.
    local NS = fresh()
    local key = NS.Categories.CreateUserCategory("Affixes", "HELPFUL")
    local twin = inactiveProfileWith(NS, "Raid", key,
        { key = key, name = "Affixes", auraType = "HELPFUL" })

    assertTrue(NS.Categories.DeleteUserCategory(key))
    assertTrue(NS.db.profile.userCategories[key] == nil, "gone here")
    assertTrue(twin.userCategories[key] ~= nil, "and untouched there")
    assertEqual(twin.containers[1].filter.categories[key], "hide", "with its container's decision")
    assertEqual(twin.categorySpells[key][424242], true, "and its spell list")

    -- And switching to that profile brings the category back, whole.
    NS.db:SetProfile("Raid")
    local def = NS.Categories.Find("HELPFUL", key)
    assertTrue(def ~= nil and def.label == "Affixes", "the copy is materialized like any record")
    assertEqual(NS.ValidateSchema(), 0)
end)

test("user categories: delete and rename are refused at the ACT for a shipped category, and the aura type has no setter at all", function()
    -- THE LOCK IS THE ACT'S, NOT THE PANEL'S (issue #10 checkpoint 6). Hiding the controls is a
    -- courtesy to the reader; a stale panel, a future slash verb or an import must meet the same
    -- refusal. red under: a delete that tests only `Cat.IsUserKey`, or one that trusts the caller.
    local NS = fresh()
    local id = NS.Database.GetContainers()[1].id
    NS.SetByPath("container.filter.categories.defensives", "hide", id)
    NS.SetByPath("categorySpells", { defensives = { [424242] = true } })

    local ok, why = NS.Categories.DeleteUserCategory("defensives")
    assertTrue(ok == nil, "a shipped category is not the player's to delete")
    assertEqual(why, NS.L["Only a category you made can be deleted."])
    assertTrue(NS.Categories.RenameUserCategory("defensives", "Mine") == nil, "nor to rename")
    assertTrue(NS.Categories.DeleteUserCategory("uncategorized") == nil, "nor the complement row")
    assertTrue(NS.Categories.DeleteUserCategory("weaponEnchants") == nil, "nor the enchant row")
    assertTrue(NS.Categories.DeleteUserCategory("userffffffffff") == nil, "nor a key nothing stores")
    -- Nothing the refusals touched: the definition, the row, the container's decision, the list.
    assertTrue(NS.Categories.Find("HELPFUL", "defensives") ~= nil)
    assertEqual(NS.Categories.Find("HELPFUL", "defensives").label, "Defensive cooldowns")
    assertEqual(NS.GetSetting("container.filter.categories.defensives", id), "hide")
    assertEqual(NS.db.profile.categorySpells.defensives[424242], true,
        "the spell list stays fully the player's -- the lock is on the category OBJECT")

    -- THE AURA TYPE IS IMMUTABLE BECAUSE NOTHING CAN WRITE IT. Create is the only writer in the
    -- addon, and a rename does not take a type, so there is no act to refuse -- which is the
    -- strongest form the lock can take. red under: a later checkpoint adding a "change type" act
    -- without deciding what happens to every container's stored state for the key.
    local key = NS.Categories.CreateUserCategory("Mine", "HELPFUL")
    for name in pairs(NS.Categories) do
        assertTrue(not (name:find("AuraType") and name ~= "AuraTypeOf"),
            "NS.Categories." .. name .. " looks like an aura-type setter")
    end
    assertTrue(NS.Categories.RenameUserCategory(key, "Mine again", nil, "HARMFUL"))
    assertEqual(NS.db.profile.userCategories[key].auraType, "HELPFUL", "a rename cannot retype")
    assertEqual(NS.Categories.AuraTypeOf(key), "HELPFUL")
end)

test("user categories: the reserved namespace is what BOTH the rename and the delete rest on", function()
    -- A record keyed with a SHIPPED key is not a user category with a bad field: it is a claim on
    -- that category's identity, and either act honoring it reaches the shipped category's own data.
    -- red under: dropping `Cat.IsUserKey` from either guard -- the delete sweeps the SHIPPED
    -- category's stored Show/Hide and spell list out of every profile in the account, and the rename
    -- stores a name under a key the sync then refuses to materialize.
    local NS = fresh()
    local id = NS.Database.GetContainers()[1].id
    NS.SetByPath("container.filter.categories.healing", "hide", id)
    NS.SetByPath("categorySpells", { healing = { [424242] = true } })
    NS.db.profile.userCategories.healing = { key = "healing", name = "Forged", auraType = "HELPFUL" }

    local ok, why = NS.Categories.RenameUserCategory("healing", "Mine")
    assertTrue(ok == nil, "the rename refuses it")
    assertEqual(why, NS.L["Only a category you made can be renamed."])
    assertEqual(NS.db.profile.userCategories.healing.name, "Forged", "and changes nothing")
    assertTrue(NS.Categories.DeleteUserCategory("healing") == nil, "the delete refuses it")
    assertTrue(NS.db.profile.userCategories.healing ~= nil, "and discards nothing")

    -- What the guard protects, said out loud: the SHIPPED category's own stored state.
    assertEqual(NS.GetSetting("container.filter.categories.healing", id), "hide")
    assertEqual(NS.db.profile.categorySpells.healing[424242], true)
    assertEqual(NS.Categories.Find("HELPFUL", "healing").label, "Healing")
    assertEqual(NS.ValidateSchema(), 0)
end)

test("user categories: a record the sync cannot read can still be got rid of, and taking it leaves a shipped category alone", function()
    -- THE WAY OUT. `usableName` refuses to guess at a record with no usable aura type, no usable
    -- name or a key outside the namespace -- right, because guessing moves a category between the
    -- two grids or renames it behind the player's back. But a record like that has no definition, so
    -- it is in no dropdown, and `forgetUserKey` skips a profile that still holds a record under the
    -- key, so even its debris could never be swept. red under: `DeleteUserCategory` refusing a
    -- non-table record, and nothing at all reaching a forged shipped-key one.
    local NS = fresh()
    local id = NS.Database.GetContainers()[1].id
    local good = NS.Categories.CreateUserCategory("Kept", "HELPFUL")
    NS.SetByPath("container.filter.categories.healing", "hide", id)
    NS.db.profile.userCategories["userbadbad00"] = { key = "userbadbad00", name = "No type" }
    NS.db.profile.userCategories["userbadbad01"] = "not a table at all"
    NS.db.profile.userCategories.healing = { key = "healing", name = "Forged", auraType = "HELPFUL" }
    NS.db.profile.categorySpells = NS.db.profile.categorySpells or {}
    NS.db.profile.categorySpells["userbadbad00"] = { [424242] = true }

    assertEqual(#NS.Categories.UnusableUserRecords(NS.db.profile), 3, "all three are named")
    assertTrue(NS.Categories.DeleteUserCategory("userbadbad01"), "a corrupt record inside the namespace deletes")
    assertEqual(NS.Categories.ForgetUnusableUserRecords(), 2, "and the rest go together")

    assertNil(NS.db.profile.userCategories["userbadbad00"])
    assertNil(NS.db.profile.userCategories.healing)
    assertNil(NS.db.profile.categorySpells["userbadbad00"], "its debris went with it")
    -- red under: sweeping the LEAVES of a record keyed with a shipped key, which is the shipped
    -- category's own Show/Hide and none of this act's business.
    assertEqual(NS.GetSetting("container.filter.categories.healing", id), "hide")
    assertTrue(NS.Categories.Find("HELPFUL", "healing") ~= nil)
    assertTrue(NS.db.profile.userCategories[good] ~= nil, "a readable category is untouched")
    assertEqual(NS.Categories.Find("HELPFUL", good).label, "Kept")
    assertEqual(NS.ValidateSchema(), 0)
end)

test("user categories: a profile the sweep raises on costs its own leaves and nothing else", function()
    -- THE DELETE IS RECOVERABLE, NOT ATOMIC, and this pins which. The record goes first, so the
    -- definition, the schema row and the container template key MUST come down with it however the
    -- sweep goes -- otherwise a raise leaves a LIVE category no record owns, whose Delete then
    -- refuses. red under: the walk running outside a pcall, where one malformed stored profile
    -- strands the category and takes the rest of the sweep with it.
    local NS = fresh()
    local key = NS.Categories.CreateUserCategory("Affixes", "HELPFUL")
    local path = "container.filter.categories." .. key
    local id = NS.Database.GetContainers()[1].id
    NS.SetByPath(path, "hide", id)
    local other = inactiveProfileWith(NS, "Raid", key)
    local broken = inactiveProfileWith(NS, "Broken", key)
    broken.containers[1] = setmetatable({}, { __index = function() error("stored table is broken") end })

    local ok, why, failed = NS.Categories.DeleteUserCategory(key)
    assertTrue(ok, "the act still answers true")
    assertNil(why)
    -- THE CALLER CAN TELL, which is the whole of this line's point: `true` alone said the delete
    -- went and said nothing about the profile that kept its debris, so the difference reached
    -- NS.Debug and never the player. red under: the third return dropped, or counting profiles that
    -- were merely SKIPPED (one holding a record of its own) as refusals.
    assertEqual(failed, 1, "the profile that raised is counted back to the caller")
    -- The category is gone in every sense the panel and the validator can see.
    assertTrue(NS.db.profile.userCategories[key] == nil)
    assertTrue(NS.Categories.Find("HELPFUL", key) == nil, "the definition went")
    assertTrue(NS.FindSchemaRow(path) == nil, "and the schema row")
    assertTrue(NS.CONTAINER_TEMPLATE.filter.categories[key] == nil, "and the template key")
    assertEqual(NS.ValidateSchema(), 0)
    -- Every OTHER profile was still swept.
    assertTrue(NS.db.profile.containers[id].filter.categories[key] == nil)
    assertTrue(other.containers[1].filter.categories[key] == nil, "the good inactive profile too")
    assertTrue(other.categorySpells[key] == nil)
    -- And the broken one lost only what could be reached without touching its broken container.
    assertTrue(broken.categorySpells[key] == nil, "its spell list still went")
end)

test("user categories: the name cap counts characters, so a non-ASCII name is never cut mid-sequence", function()
    -- red under: a BYTE cap at the store (`#clean`, `clean:sub`) against a CHARACTER cap at both of
    -- the panel's boxes (`SetMaxLetters`). A name of two-byte characters typed up to the box's limit
    -- was stored at half its length with the last character cut in half -- a lone continuation byte
    -- the font draws as a replacement glyph.
    local NS = fresh()
    local max = NS.Categories.USER_NAME_MAX
    local accented = string.rep("\195\169", max + 5)
    local clean = NS.Categories.SanitizeUserName(accented)
    assertEqual(NS.Categories.CharCount(clean), max, "capped at the number the boxes enforce")
    assertEqual(#clean, max * 2, "and every character survived whole")
    assertEqual(NS.Categories.CharCount(string.rep("a", max + 5)), max + 5, "the counter counts characters")
    assertEqual(#NS.Categories.SanitizeUserName(string.rep("a", max + 5)), max, "ASCII is unchanged")
    local key = NS.Categories.CreateUserCategory(accented, "HELPFUL")
    assertEqual(NS.Categories.Find("HELPFUL", key).label, clean, "and the category stores that name")
end)

test("user categories: a deleted category is gone from the grid and from the union, and Uncategorized is still last", function()
    -- Checkpoint 4's invariant, re-asserted across a create AND a delete: `uncategorized` compiles as
    -- the complement of the union of every spells-kind category, so a category that is created must
    -- join that union and one that is deleted must leave it -- otherwise the complement goes on being
    -- drawn against a list nothing owns any more.
    local NS = fresh()
    local MINE = 987654
    local key = NS.Categories.CreateUserCategory("Affixes", "HELPFUL")
    NS.SetByPath("categorySpells", { [key] = { [MINE] = true } })
    -- `unit = "player"` is where FC.IdsAlwaysHonored is true, and a HIDDEN SHIPPED category is what
    -- keeps the Uncategorized rescue group in the plan after the user category is gone -- without it
    -- the group would vanish with the delete and the negative below would pass for the wrong reason.
    local con = NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE)
    con.unit, con.auraType = "player", "HELPFUL"
    con.filter.categories.defensives = "hide"

    local function excluded()
        local plan = NS.FilterCompiler.Compile(con, NS.FilterCompiler.ProfileContext())
        for _, g in ipairs(plan.groups) do
            if g.label == "Uncategorized" then
                return g.candidateFilters and g.candidateFilters.excludeSpellIDs or {}
            end
        end
        return nil
    end
    assertEqual(NS.Categories.HELPFUL[#NS.Categories.HELPFUL].key, "uncategorized", "U-1 after create")
    local before = excluded()
    assertTrue(before ~= nil and before[MINE], "the new category's id joined the union (the premise)")

    assertTrue(NS.Categories.DeleteUserCategory(key))
    assertEqual(NS.Categories.HELPFUL[#NS.Categories.HELPFUL].key, "uncategorized", "U-1 after delete")
    local after = excluded()
    -- red under: a delete that tears the record down but leaves the definition materialized, which
    -- would go on taking the id out of the complement `uncategorized` is defined against.
    assertTrue(after ~= nil, "the rescue group is still there (the hidden shipped category keeps it)")
    assertTrue(after[MINE] == nil, "and the deleted category's id left the union with it")
    assertEqual(NS.ValidateSchema(), 0)
end)
