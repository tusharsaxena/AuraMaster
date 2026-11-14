-- tests/test_presets_seed.lua -- core/Database.lua: a new profile starts from the Simple preset, and
-- schema v19 marks every profile that was already seeded as having seen the preset picker (AM-PR04;
-- spec sections 7 and 9). Each case builds its own environment (tests/fresh_env.lua).

local freshEnv = dofile("tests/fresh_env.lua")

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local SIMPLE_NAMES = { "Player buffs (all)", "Weapon enchants", "Player debuffs (all)" }

--- A fresh environment holding the real first-run seed, not the harness's fixture
--- (tests/starters_fixture.lua), with the first-run skin picker kept out of it
--- (tests/test_presets_apply.lua).
local function fresh(opts)
    opts = opts or {}
    opts.simple = true
    local NS, mocks = freshEnv(opts)
    NS.Helpers.SkinPicker = function() return nil end
    return NS, mocks
end

--- A deterministic text of `v`, tables by sorted key, with the keys in `skip` left out at every level.
local function serialize(v, skip)
    if type(v) ~= "table" then return type(v) .. ":" .. tostring(v) end
    local keys = {}
    for k in pairs(v) do
        if not (skip and skip[k]) then keys[#keys + 1] = k end
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. serialize(v[k], skip) end
    return "{" .. table.concat(out, ",") .. "}"
end

--- The stored containers in display order.
local function containers(NS)
    local p, out = NS.db.profile, {}
    for _, id in ipairs(p.containerOrder) do out[#out + 1] = p.containers[id] end
    return out
end

test("seed: new profile gets simple", function()
    local NS = fresh()
    local list = containers(NS)
    -- red under: the retired four-container starter set (Player buffs, Player debuffs, Target
    -- debuffs (mine), Player cooldowns) seeded instead of the Simple preset
    assertEqual(#list, 3)
    for i, name in ipairs(SIMPLE_NAMES) do assertEqual(list[i].name, name) end
    assertTrue(NS.db.profile.seeded)
    local pbuffs, wpn, pdebuffs = list[1], list[2], list[3]
    assertEqual(pbuffs.attach.mode, "screen")
    assertEqual(pdebuffs.attach.mode, "screen")
    -- red under: a member left on the builder's placeholder id 0
    assertEqual(wpn.attach.mode, "container")
    assertEqual(wpn.attach.container, pbuffs.id, "Weapon enchants hangs under the seeded Player buffs")
    assertEqual(#NS.db.profile.userCategoryOrder, 0, "Simple creates no custom category")
end)

test("seed: the seeded containers are what applying Simple (Bars) writes", function()
    local NS = fresh()
    -- Ids and the attach id differ between the two (Replace mints new ones), and Create offsets a
    -- container stated without a position by its id: a stack member, which hangs from its head and
    -- never reads it. Everything else agrees.
    local skip = { id = true, container = true }
    local function view()
        local out = {}
        for i, c in ipairs(containers(NS)) do
            local v = NS.Database.DeepCopy(c)
            if v.attach.mode == "container" then v.position = nil end
            out[i] = v
        end
        return serialize(out, skip)
    end
    local seeded = view()
    local ok, err = NS.Presets.Apply("simple", "bars", "replace")
    assertTrue(ok, tostring(err))
    -- red under: seeding that builds its containers by a path of its own and drifts from Apply's
    assertEqual(view(), seeded)
end)

test("seed: PrepareProfile seeds Simple from the profile's own counter", function()
    local NS = fresh()
    local p = { nextContainerId = 10 }
    assertEqual(NS.Database.PrepareProfile(p), 3, "returns how many it seeded")
    assertEqual(table.concat(p.containerOrder, ","), "10,11,12")
    assertEqual(p.nextContainerId, 13)
    assertEqual(p.containers[11].attach.container, 10, "the member attaches to the id the head took")
    assertEqual(NS.Database.PrepareProfile(p), 0, "a second call seeds nothing")
end)

test("seed: the retired starter set is gone", function()
    local NS = fresh()
    -- red under: defaults/Profile.lua still publishing the four-container starter set
    assertTrue(NS.STARTER_CONTAINERS == nil)
end)

test("seed: migrated profile marked seen", function()
    local mine = { name = "Mine", unit = "focus", auraType = "HARMFUL", style = "icons" }
    local NS = fresh({ savedVariables = {
        profiles = {
            Default = { seeded = true, nextContainerId = 5, containers = { [4] = mine }, containerOrder = { 4 } },
            Other = { seeded = true, nextContainerId = 2,
                containers = { [1] = { name = "Kept", unit = "player", auraType = "HELPFUL", style = "bars" } },
                containerOrder = { 1 } },
            Unseeded = { nextContainerId = 1 },
        },
        global = { schemaVersion = 18 },
    } })
    assertEqual(NS.db.global.schemaVersion, NS.Database.CurrentSchemaVersion())
    assertEqual(NS.SCHEMA_VERSION, 19)
    local p = NS.db.profile
    -- red under: no v19 step, or one keyed on something other than `seeded`
    assertTrue(p.presets.pickerSeen, "the active profile, already seeded, is marked seen")
    local list = containers(NS)
    assertEqual(#list, 1, "its containers are unchanged: no Simple seeded over them")
    assertEqual(list[1].name, "Mine")
    assertEqual(list[1].id, 4)
    local store = NS.db.sv.profiles
    assertTrue(store.Other.presets.pickerSeen, "an inactive seeded profile is marked too")
    assertEqual(store.Other.containers[1].name, "Kept")
    assertTrue(store.Unseeded.presets == nil or not store.Unseeded.presets.pickerSeen,
        "a profile that was never seeded still sees the picker")
end)

test("seed: fresh install not marked seen", function()
    local NS = fresh()
    -- A fresh install climbs the whole ladder, v19 included, before its first seeding.
    assertEqual(NS.db.global.schemaVersion, NS.Database.CurrentSchemaVersion())
    -- red under: a v19 step that marks every profile, not only the seeded ones
    assertFalse(NS.db.profile.presets.pickerSeen)
    assertTrue(NS.db.profile.seeded, "the profile is seeded after the ladder")
end)

test("seed: the v19 step is idempotent and keeps a stored false on an unseeded profile", function()
    local NS = fresh()
    local seen = { seeded = true }
    assertEqual(NS.Database.MigrateV19(seen), 1)
    assertTrue(seen.presets.pickerSeen)
    assertEqual(NS.Database.MigrateV19(seen), 0, "a second run marks nothing")
    local unseeded = { seeded = false, presets = { pickerSeen = false } }
    assertEqual(NS.Database.MigrateV19(unseeded), 0)
    assertFalse(unseeded.presets.pickerSeen)
end)
