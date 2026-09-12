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

test("database: every category key is present on a stored container, neutral", function()
    local NS = fresh()
    local cats = NS.Database.FindContainer(1).filter.categories
    for _, list in ipairs({ NS.Categories.HELPFUL, NS.Categories.HARMFUL }) do
        for _, def in ipairs(list) do assertTrue(cats[def.key] ~= nil, "category " .. def.key) end
    end
    assertEqual(cats.defensives, "")
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
