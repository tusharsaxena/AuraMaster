-- tests/test_situations_settings.lua — filter situations S5 (SI-02): the settings data behind the
-- Situations tab. `filter.situations` (what a container draws where spell lists don't apply, per NPC
-- and per player) and `filter.zones` (the six instance types it shows in) live in the container
-- template, so every road a container's settings travel carries them: the load backfill, Copy
-- settings from -> Filters, Duplicate, the Filters page's Defaults and a profile reset. Their rows
-- validate the two modes and the six booleans; the zone rows take the combat-legal visibility pass.
-- Spec: docs/superpowers/specs/2026-10-02-filter-situations-design.md S5.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")

local SITUATIONS = { "npcs", "players" }
local ZONES = { "none", "party", "scenario", "raid", "pvp", "arena" }

--- Assert container `c` holds the shipped defaults for both tables, naming `what` on failure.
local function assertDefaults(c, what)
    local f = c.filter
    assertEqual(type(f.situations), "table", what .. ": filter.situations")
    assertEqual(type(f.zones), "table", what .. ": filter.zones")
    for _, k in ipairs(SITUATIONS) do
        assertEqual(f.situations[k], "every", what .. ": situations." .. k)
    end
    for _, k in ipairs(ZONES) do
        assertEqual(f.zones[k], true, what .. ": zones." .. k)
    end
end

--- Plant a non-default value in every leaf of both tables on container `c`, through the seam.
local function plantNonDefaults(NS, id)
    for _, k in ipairs(SITUATIONS) do
        assertTrue(NS.SetByPath("container.filter.situations." .. k, "blizzard", id))
    end
    for _, k in ipairs(ZONES) do
        assertTrue(NS.SetByPath("container.filter.zones." .. k, false, id))
    end
end

--- Assert container `c` holds exactly what plantNonDefaults wrote.
local function assertPlanted(c, what)
    for _, k in ipairs(SITUATIONS) do
        assertEqual(c.filter.situations[k], "blizzard", what .. ": situations." .. k)
    end
    for _, k in ipairs(ZONES) do
        assertEqual(c.filter.zones[k], false, what .. ": zones." .. k)
    end
end

test("situations settings: the template holds both situations at 'every' and all six zones on", function()
    local NS = fresh()
    -- red under: CONTAINER_TEMPLATE.filter without situations / zones (S5)
    assertDefaults(NS.CONTAINER_TEMPLATE, "template")
    -- red under: a stray seventh zone or third situation key (one key per IsInInstance() type)
    local n = 0
    for _ in pairs(NS.CONTAINER_TEMPLATE.filter.zones) do n = n + 1 end
    assertEqual(n, #ZONES, "the six instance types")
    n = 0
    for _ in pairs(NS.CONTAINER_TEMPLATE.filter.situations) do n = n + 1 end
    assertEqual(n, #SITUATIONS, "NPCs and players")
end)

test("situations settings: eight rows on the Filters page, situations offering the two modes, zones booleans", function()
    local NS = fresh()
    for _, k in ipairs(SITUATIONS) do
        local row = NS.FindSchemaRow("container.filter.situations." .. k)
        -- red under: no row for the leaf (the CLI, Defaults and the tab could not reach it)
        assertTrue(row ~= nil, "row for situations." .. k)
        assertEqual(row.page, "filters", k)
        assertEqual(row.type, "string", k)
        local values = {}
        for _, v in ipairs(row.values) do values[#values + 1] = v.value end
        -- red under: a dropdown offering anything but every / blizzard, or in another order
        assertEqual(table.concat(values, ","), "every,blizzard", k)
        assertEqual(row.default, "every", k)
        -- red under: the situation rows without the new view effect (SI-03 wires it)
        assertEqual(row.effect, "view", k)
    end
    for _, k in ipairs(ZONES) do
        local row = NS.FindSchemaRow("container.filter.zones." .. k)
        assertTrue(row ~= nil, "row for zones." .. k)
        assertEqual(row.page, "filters", k)
        assertEqual(row.type, "bool", k)
        assertEqual(row.default, true, k)
        -- red under: a zone row without effect = "visibility" (it would queue a full re-apply)
        assertEqual(row.effect, "visibility", k)
    end
    assertEqual(NS.ValidateSchema(), 0, "every new path resolves against the template")
end)

test("situations settings: the seam refuses a mode outside every/blizzard and a zone that is not a boolean", function()
    local NS = fresh()
    local c = NS.Database.FindContainer(1)
    -- red under: a situation row with no validate (any string stored, read later as a view)
    assertFalse((NS.SetByPath("container.filter.situations.npcs", "ids", 1)), "ids is not a choice")
    assertFalse((NS.SetByPath("container.filter.situations.players", 1, 1)), "a number")
    assertEqual(c.filter.situations.npcs, "every", "nothing stored")
    assertEqual(c.filter.situations.players, "every", "nothing stored")
    -- red under: a zone row with no validate (a truthy string would read as shown)
    assertFalse((NS.SetByPath("container.filter.zones.raid", "no", 1)), "a string")
    assertFalse((NS.SetByPath("container.filter.zones.arena", 0, 1)), "a number")
    assertEqual(c.filter.zones.raid, true, "nothing stored")
    assertEqual(c.filter.zones.arena, true, "nothing stored")
    assertTrue(NS.SetByPath("container.filter.situations.npcs", "blizzard", 1))
    assertTrue(NS.SetByPath("container.filter.zones.raid", false, 1))
    assertEqual(c.filter.situations.npcs, "blizzard")
    assertEqual(c.filter.zones.raid, false, "a stored false is the player's choice")
end)

--- The owner's real profile (schema 11, no situations or zones on any container), keyed by id.
local function ownerProfile(NS)
    local F = dofile("tests/situations_owner_profile.lua")
    local p = NS.Database.DeepCopy(F.profile)
    local containers, order, maxId = {}, {}, 0
    for _, c in ipairs(p.containers) do
        containers[c.id] = c
        order[#order + 1] = c.id
        if c.id > maxId then maxId = c.id end
    end
    p.containers, p.containerOrder = containers, order
    p.seeded, p.nextContainerId = true, maxId + 1
    return p, order
end

test("situations settings: the owner's real profile loads with both tables on every container, and a stored choice is kept", function()
    local NS0 = fresh()
    local default, order = ownerProfile(NS0)
    local raid = NS0.Database.DeepCopy(default)
    for _, c in pairs(default.containers) do
        assertEqual(c.filter.situations, nil, "the fixture predates the keys")
        assertEqual(c.filter.zones, nil, "the fixture predates the keys")
    end
    -- One container already carries a partial choice: the backfill fills around it.
    default.containers[10].filter.situations = { npcs = "blizzard" }
    default.containers[10].filter.zones = { raid = false }
    local NS = fresh({ savedVariables = { profiles = { Default = default, Raid = raid },
        global = { schemaVersion = 11 } } })
    -- red under: a schema step added for keys the template backfill already stamps
    assertEqual(NS.SCHEMA_VERSION, 11, "no step: the load backfill reaches them")
    for _, id in ipairs(order) do
        local c = NS.Database.FindContainer(id)
        if id ~= 10 then
            -- red under: the tables declared anywhere the load backfill (backfillContainers) misses
            assertDefaults(c, "Default #" .. id)
        end
    end
    local c10 = NS.Database.FindContainer(10)
    -- red under: a backfill that overwrites a present leaf (Database.Backfill tests `== nil`)
    assertEqual(c10.filter.situations.npcs, "blizzard", "the stored choice")
    assertEqual(c10.filter.situations.players, "every", "the missing leaf backfilled")
    assertEqual(c10.filter.zones.raid, false, "the stored false")
    assertEqual(c10.filter.zones.party, true, "the missing leaf backfilled")
    -- An inactive profile is backfilled when it becomes the active one.
    NS.db:SetProfile("Raid")
    for _, id in ipairs(order) do
        assertDefaults(NS.Database.FindContainer(id), "Raid #" .. id)
    end
end)

test("situations settings: Copy settings from -> Filters carries both tables", function()
    local NS = fresh()
    local CM = NS.ContainerManager
    local second = CM.Create({ name = "Second" })
    plantNonDefaults(NS, second)
    assertDefaults(NS.Database.FindContainer(1), "destination before")
    -- red under: the tables declared outside `filter` (CM.COPY_SECTIONS copies `filter` whole)
    assertTrue(CM.CopyFrom(second, 1, "filter"))
    assertPlanted(NS.Database.FindContainer(1), "after the copy")
end)

test("situations settings: a source holding a mode the rows refuse fails Copy -> Filters, and nothing is stored", function()
    local NS = fresh()
    local CM = NS.ContainerManager
    local second = CM.Create({ name = "Second" })
    NS.Database.FindContainer(second).filter.situations.npcs = "garbage"   -- hand-edited data
    local ok = CM.CopyFrom(second, 1, "filter")
    -- red under: the situation rows without validate (a whole-section write checks every row's)
    assertFalse(ok, "the seam refuses the section")
    assertEqual(NS.Database.FindContainer(1).filter.situations.npcs, "every", "nothing was stored")
end)

test("situations settings: Duplicate carries both tables, and shares no table with the source", function()
    local NS = fresh()
    plantNonDefaults(NS, 1)
    local id = NS.ContainerManager.Duplicate(1)
    local dup = NS.Database.FindContainer(id)
    -- red under: Duplicate building from the template rather than a deep copy of the source
    assertPlanted(dup, "the copy")
    dup.filter.zones.raid = true
    assertEqual(NS.Database.FindContainer(1).filter.zones.raid, false, "nothing is shared")
end)

test("situations settings: the Filters page's Defaults restores both tables", function()
    local NS = fresh()
    NS.State.SetActiveContainer(1)
    plantNonDefaults(NS, 1)
    NS.Helpers.RestoreDefaults("filters")
    -- red under: the rows on another page, or carrying noReset
    assertDefaults(NS.Database.FindContainer(1), "after Defaults")
end)

test("situations settings: a profile reset re-seeds both tables at their defaults", function()
    local NS = fresh()
    plantNonDefaults(NS, 1)
    NS.db:ResetProfile()
    local ids = NS.db.profile.containerOrder
    assertTrue(#ids > 0, "the starters are re-seeded")
    for _, id in ipairs(ids) do
        -- red under: the tables stamped by a schema step rather than the template (a reset seeds
        -- from the template and runs no step)
        assertDefaults(NS.Database.FindContainer(id), "#" .. id)
    end
end)

test("situations settings: a zone write takes the visibility pass and queues no apply", function()
    local NS = fresh()
    local CM = NS.ContainerManager
    CM.FlushPending()
    local asked, passes = 0, 0
    local request, visibility = CM.RequestApply, CM.ApplyVisibility
    CM.RequestApply = function(...) asked = asked + 1; return request(...) end
    CM.ApplyVisibility = function(...) passes = passes + 1; return visibility(...) end
    assertTrue(NS.SetByPath("container.filter.zones.party", false, 1))
    CM.RequestApply, CM.ApplyVisibility = request, visibility
    -- red under: the zone rows without effect = "visibility"
    assertEqual(asked, 0, "no apply queued")
    assertEqual(passes, 1, "one visibility pass")
end)

test("situations settings: the rows are the Situations group, declared last, and drawn by the flow engine (SI-05)", function()
    local NS = fresh()
    NS.State.SetActiveContainer(1)
    local groups, seen = {}, {}
    for _, row in ipairs(NS.SchemaForPage("filters")) do
        if row.group and not seen[row.group] then
            seen[row.group] = true
            groups[#groups + 1] = row.group
        end
    end
    -- red under: the rows still in the General group (SI-02's interim home), or declared before Sorting
    assertEqual(table.concat(groups, ","),
        table.concat({ NS.L["General"], NS.L["Categories"], NS.L["Sorting"], NS.L["Situations"] }, ","))
    for _, path in ipairs({ "container.filter.situations.npcs", "container.filter.zones.raid" }) do
        local row = NS.FindSchemaRow(path)
        -- red under: SI-02's skipRender kept (the tab's own RenderRows would draw nothing)
        assertTrue(row.skipRender == nil, path)
        -- red under: the auraTypes guard dropped (a container of no known aura type would draw an
        -- empty Situations tab)
        assertTrue(row.auraTypes and row.auraTypes.HELPFUL and row.auraTypes.HARMFUL, path)
    end
end)
