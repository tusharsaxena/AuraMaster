-- tests/test_unitfilter_settings.lua — filter situations S6 (SI-10): the settings data behind the
-- Situations tab's Unit type section. `filter.unitFilter = { kind, reaction }` lives in the container
-- template, so the load backfill, Copy settings from -> Filters, Duplicate and the Filters page's
-- Defaults carry it. Its two rows validate their choices and take the combat-legal visibility pass.
-- Spec: docs/superpowers/specs/2026-10-02-filter-situations-addendum-unit-filter.md S6.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")

--- Assert container `c` holds All / All, naming `what` on failure.
local function assertAllAll(c, what)
    local f = c.filter.unitFilter
    assertEqual(type(f), "table", what .. ": filter.unitFilter")
    assertEqual(f.kind, "all", what .. ": kind")
    assertEqual(f.reaction, "all", what .. ": reaction")
end

test("unit type settings: the template holds kind and reaction at All", function()
    local NS = fresh()
    -- red under: CONTAINER_TEMPLATE.filter without unitFilter (S6)
    assertAllAll(NS.CONTAINER_TEMPLATE, "template")
    local n = 0
    for _ in pairs(NS.CONTAINER_TEMPLATE.filter.unitFilter) do n = n + 1 end
    assertEqual(n, 2, "kind and reaction only")
end)

test("unit type settings: two rows in the Situations group, offering their choices, taking the visibility effect", function()
    local NS = fresh()
    local want = { kind = "all,npc,player", reaction = "all,friendly,neutral,hostile" }
    local labels = { kind = "All|NPCs|Players", reaction = "All|Friendly|Neutral|Hostile" }
    for key, values in pairs(want) do
        local row = NS.FindSchemaRow("container.filter.unitFilter." .. key)
        -- red under: no row for the leaf (the CLI, Defaults and the tab could not reach it)
        assertTrue(row ~= nil, key)
        assertEqual(row.page, "filters", key)
        assertEqual(row.group, NS.L["Situations"], key)
        assertEqual(row.type, "string", key)
        local got, shown = {}, {}
        for _, v in ipairs(row.values) do
            got[#got + 1] = v.value
            shown[#shown + 1] = v.text or v.label
        end
        -- red under: a dropdown offering other choices, or in another order
        assertEqual(table.concat(got, ","), values, key)
        assertEqual(table.concat(shown, "|"), labels[key], key .. ": the labels")
        assertEqual(row.default, "all", key)
        -- red under: a row without effect = "visibility" (it would queue a full re-apply, held in combat)
        assertEqual(row.effect, "visibility", key)
    end
    assertEqual(NS.ValidateSchema(), 0, "every new path resolves against the template")
end)

test("unit type settings: the seam refuses a choice the rows do not offer", function()
    local NS = fresh()
    local c = NS.Database.FindContainer(3)
    -- red under: rows with no validate (any string stored, never matching a unit)
    assertFalse((NS.SetByPath("container.filter.unitFilter.kind", "pet", 3)), "pet is not a choice")
    assertFalse((NS.SetByPath("container.filter.unitFilter.reaction", "unfriendly", 3)), "nor unfriendly")
    assertFalse((NS.SetByPath("container.filter.unitFilter.reaction", 4, 3)), "nor a number")
    assertAllAll(c, "nothing stored")
    assertTrue(NS.SetByPath("container.filter.unitFilter.kind", "npc", 3))
    assertTrue(NS.SetByPath("container.filter.unitFilter.reaction", "hostile", 3))
    assertEqual(c.filter.unitFilter.kind, "npc")
    assertEqual(c.filter.unitFilter.reaction, "hostile")
end)

--- The owner's real profile (schema 11, no unitFilter on any container), keyed by id.
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

test("unit type settings: the owner's real profile loads with All / All on every container, a stored choice kept", function()
    local NS0 = fresh()
    local default, order = ownerProfile(NS0)
    for _, c in pairs(default.containers) do
        assertEqual(c.filter.unitFilter, nil, "the fixture predates the key")
    end
    default.containers[10].filter.unitFilter = { reaction = "hostile" }
    local NS = fresh({ savedVariables = { profiles = { Default = default }, global = { schemaVersion = 11 } } })
    assertEqual(NS.SCHEMA_VERSION, 11, "no step: the load backfill reaches it")
    for _, id in ipairs(order) do
        -- red under: the table declared anywhere the load backfill misses
        if id ~= 10 then assertAllAll(NS.Database.FindContainer(id), "#" .. id) end
    end
    local f = NS.Database.FindContainer(10).filter.unitFilter
    -- red under: a backfill that overwrites a present leaf
    assertEqual(f.reaction, "hostile", "the stored choice")
    assertEqual(f.kind, "all", "the missing leaf backfilled")
end)

test("unit type settings: Copy settings from -> Filters and Duplicate carry it, Defaults restores it", function()
    local NS = fresh()
    local CM = NS.ContainerManager
    local second = CM.Create({ name = "Second", unit = "focus" })
    assertTrue(NS.SetByPath("container.filter.unitFilter.kind", "player", second))
    assertTrue(NS.SetByPath("container.filter.unitFilter.reaction", "hostile", second))
    -- red under: unitFilter declared outside `filter` (CM.COPY_SECTIONS copies `filter` whole)
    assertTrue(CM.CopyFrom(second, 3, "filter"))
    local f = NS.Database.FindContainer(3).filter.unitFilter
    assertEqual(f.kind .. "/" .. f.reaction, "player/hostile", "copied")
    local dup = NS.Database.FindContainer(CM.Duplicate(second)).filter.unitFilter
    assertEqual(dup.kind .. "/" .. dup.reaction, "player/hostile", "duplicated")
    dup.kind = "npc"
    assertEqual(NS.Database.FindContainer(second).filter.unitFilter.kind, "player", "nothing shared")
    NS.State.SetActiveContainer(3)
    NS.Helpers.RestoreDefaults("filters")
    -- red under: the rows on another page, or carrying noReset
    assertAllAll(NS.Database.FindContainer(3), "after Defaults")
end)

test("unit type settings: a source holding a choice the rows refuse fails Copy -> Filters", function()
    local NS = fresh()
    local CM = NS.ContainerManager
    local second = CM.Create({ name = "Second", unit = "target" })
    NS.Database.FindContainer(second).filter.unitFilter.kind = "garbage"   -- hand-edited data
    -- red under: the rows without validate (a whole-section write checks every row's)
    assertFalse((CM.CopyFrom(second, 3, "filter")), "the seam refuses the section")
    assertAllAll(NS.Database.FindContainer(3), "nothing was stored")
end)

test("unit type settings: a write takes the visibility pass and queues no apply", function()
    local NS = fresh()
    local CM = NS.ContainerManager
    CM.FlushPending()
    local asked, passes = 0, 0
    local request, visibility = CM.RequestApply, CM.ApplyVisibility
    CM.RequestApply = function(...) asked = asked + 1; return request(...) end
    CM.ApplyVisibility = function(...) passes = passes + 1; return visibility(...) end
    assertTrue(NS.SetByPath("container.filter.unitFilter.reaction", "friendly", 3))
    CM.RequestApply, CM.ApplyVisibility = request, visibility
    -- red under: the rows without effect = "visibility"
    assertEqual(asked, 0, "no apply queued")
    assertEqual(passes, 1, "one visibility pass")
end)
