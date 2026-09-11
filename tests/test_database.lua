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
