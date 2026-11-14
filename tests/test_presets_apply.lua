-- tests/test_presets_apply.lua -- modules/Presets.lua: applying a preset through the registry writers
-- (AM-PR02; spec sections 3 and 5). Every case creates or deletes containers, so each builds its own
-- environment (tests/fresh_env.lua). A fresh profile holds the starter containers and no custom
-- category of its own.

local freshEnv = dofile("tests/fresh_env.lua")

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

local SIMPLE_NAMES = { "Player buffs (all)", "Weapon enchants", "Player debuffs (all)" }

--- A fresh environment with the first-run skin picker kept out of it: a profile event shows it, and
--- a picker over a hidden HUD turns test mode on (tests/test_skin_picker.lua owns that).
local function fresh()
    local NS, mocks = freshEnv()
    NS.Helpers.SkinPicker = function() return nil end
    return NS, mocks
end

--- A deterministic text of `v`, tables by sorted key, for comparing stored state whole.
local function serialize(v)
    if type(v) ~= "table" then return type(v) .. ":" .. tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. serialize(v[k]) end
    return "{" .. table.concat(out, ",") .. "}"
end

--- The stored state a preset may change: the registry and the custom categories.
local function stored(NS)
    local p = NS.db.profile
    return serialize({
        containers = p.containers, containerOrder = p.containerOrder, nextContainerId = p.nextContainerId,
        userCategories = p.userCategories, userCategoryOrder = p.userCategoryOrder,
        categorySpells = p.categorySpells,
    })
end

--- The stored containers in creation order.
local function containers(NS)
    local p, out = NS.db.profile, {}
    for _, id in ipairs(p.containerOrder) do out[#out + 1] = p.containers[id] end
    return out
end

local function byName(NS, name)
    for _, c in ipairs(NS.Database.GetContainers()) do
        if c.name == name then return c end
    end
    return nil
end

--- The custom category records, in order.
local function userCategories(NS)
    local p, out = NS.db.profile, {}
    for _, key in ipairs(p.userCategoryOrder or {}) do out[#out + 1] = p.userCategories[key] end
    return out
end

test("apply: replace simple", function()
    local NS = fresh()
    assertTrue(#NS.Database.GetContainers() > 0, "the starters are there to replace")
    local ok, err = NS.Presets.Apply("simple", "bars", "replace")
    assertTrue(ok, tostring(err))
    local list = containers(NS)
    assertEqual(#list, 3)
    for i, name in ipairs(SIMPLE_NAMES) do assertEqual(list[i].name, name) end
    local pbuffs, wpn, pdebuffs = list[1], list[2], list[3]
    assertEqual(pbuffs.attach.mode, "screen")
    assertEqual(pdebuffs.attach.mode, "screen")
    -- red under: a member left on the placeholder id the builder hands the writer
    assertEqual(wpn.attach.mode, "container")
    assertEqual(wpn.attach.container, pbuffs.id, "Weapon enchants hangs under the new Player buffs")
    assertEqual(#NS.db.profile.userCategoryOrder, 0, "Simple creates no custom category")
end)

test("apply: replace empty", function()
    local NS = fresh()
    assertTrue(NS.Presets.Apply("empty", "bars", "replace"))
    assertEqual(#NS.Database.GetContainers(), 0)
    assertEqual(#NS.db.profile.containerOrder, 0)
end)

test("apply: add empty refused", function()
    local NS = fresh()
    local before = stored(NS)
    local ok, err = NS.Presets.Apply("empty", "bars", "add")
    assertNil(ok)
    assertTrue(type(err) == "string" and err ~= "", "a reason is given")
    assertEqual(stored(NS), before, "nothing changed")
end)

test("apply: an unknown preset, style or mode is refused and changes nothing", function()
    local NS = fresh()
    local before = stored(NS)
    for _, args in ipairs({ { "huge", "bars", "replace" }, { "simple", "lines", "replace" },
        { "simple", "bars", "merge" } }) do
        local ok, err = NS.Presets.Apply(args[1], args[2], args[3])
        assertNil(ok, table.concat(args, " "))
        assertTrue(type(err) == "string" and err ~= "", table.concat(args, " "))
    end
    assertEqual(stored(NS), before)
end)

test("apply: add mode chains to new ids", function()
    local NS = fresh()
    local CM = NS.ContainerManager
    local seeded = assert(CM.Create({ name = "Player buffs (all)" }))
    local kept = #NS.Database.GetContainers()
    assertTrue(NS.Presets.Apply("simple", "bars", "add"))
    assertEqual(#NS.Database.GetContainers(), kept + 3, "the player's containers stay")
    assertEqual(NS.Database.FindContainer(seeded).name, "Player buffs (all)", "the player's keeps its name")
    local pbuffs, wpn = byName(NS, "Player buffs (all) (2)"), byName(NS, "Weapon enchants")
    assertTrue(pbuffs ~= nil, "the new one is suffixed")
    assertTrue(wpn ~= nil)
    -- red under: chaining members by the builder's index, or by name, instead of the id Create returned
    assertEqual(wpn.attach.mode, "container")
    assertEqual(wpn.attach.container, pbuffs.id)
    assertTrue(wpn.attach.container ~= seeded, "never the player's container with the old name")
end)

test("apply: advanced creates two categories", function()
    local NS = fresh()
    assertTrue(NS.Presets.Apply("advanced", "bars", "replace"))
    assertEqual(#NS.Database.GetContainers(), 20)
    local cats = userCategories(NS)
    assertEqual(#cats, 2)
    assertEqual(cats[1].name, "Special player buffs")
    assertEqual(cats[1].auraType, "HELPFUL")
    assertEqual(cats[2].name, "Special target debuffs")
    assertEqual(cats[2].auraType, "HARMFUL")
    local pspec, tspec = byName(NS, "Player special (mine)"), byName(NS, "Target special (mine)")
    assertEqual(pspec.filter.categories[cats[1].key], "show")
    assertEqual(tspec.filter.categories[cats[2].key], "show")
    assertEqual(byName(NS, "Weapon enchants").filter.categories[cats[1].key], "hide")
    -- red under: the builder's placeholder keys stored instead of the categories' own
    for _, c in ipairs(NS.Database.GetContainers()) do
        assertNil(c.filter.categories.SPECIAL_PLAYER, c.name)
        assertNil(c.filter.categories.SPECIAL_TARGET, c.name)
    end
end)

test("apply: advanced re-apply reuses categories", function()
    local NS = fresh()
    assertTrue(NS.Presets.Apply("advanced", "bars", "replace"))
    local first = userCategories(NS)
    local p = NS.db.profile
    p.categorySpells[first[1].key] = { [12345] = true }
    p.categorySpells[first[2].key] = { [67890] = true }
    local spells = serialize(p.categorySpells)
    assertTrue(NS.Presets.Apply("advanced", "icons", "replace"))
    local again = userCategories(NS)
    -- red under: ResolveCustom creating a category every time
    assertEqual(#again, 2, "still two custom categories")
    assertEqual(again[1].key, first[1].key)
    assertEqual(again[2].key, first[2].key)
    assertEqual(serialize(p.categorySpells), spells, "the spell lists the player filled stay")
    assertEqual(byName(NS, "Player special (mine)").filter.categories[first[1].key], "show")
    assertEqual(byName(NS, "Target special (mine)").filter.categories[first[2].key], "show")
    assertTrue(NS.Presets.Apply("advanced", "bars", "add"))
    assertEqual(#userCategories(NS), 2, "adding over it reuses them too")
end)

test("apply: ResolveCustom reuses only a category of the same aura type, by name in any case", function()
    local NS = fresh()
    local Cat = NS.Categories
    local harmful = assert(Cat.CreateUserCategory("Special player buffs", "HARMFUL"))
    local helpful = assert(Cat.CreateUserCategory("SPECIAL PLAYER BUFFS", "HELPFUL"))
    assertEqual(NS.Presets.ResolveCustom("SPECIAL_PLAYER"), helpful)
    local target = NS.Presets.ResolveCustom("SPECIAL_TARGET")
    assertTrue(target ~= nil and target ~= harmful, "a debuff category of another name is not reused")
    assertEqual(NS.Presets.ResolveCustom("SPECIAL_TARGET"), target, "the one it made is reused next time")
    assertEqual(#userCategories(NS), 3)
    assertNil(NS.Presets.ResolveCustom("NOT_A_KEY"))
end)

test("apply: refused in combat", function()
    local NS, mocks = fresh()
    local before = stored(NS)
    mocks.__lockdown = true
    for _, args in ipairs({ { "simple", "bars", "replace" }, { "empty", "bars", "replace" },
        { "advanced", "icons", "add" } }) do
        local ok, err = NS.Presets.Apply(args[1], args[2], args[3])
        -- red under: Apply without its InCombatLockdown gate (Replace would delete before Create refused)
        assertNil(ok, table.concat(args, " "))
        assertTrue(type(err) == "string" and err:find("during combat", 1, true) ~= nil, tostring(err))
    end
    assertEqual(stored(NS), before, "nothing changed")
end)

test("apply: only the registry writers write", function()
    local NS = fresh()
    local CM, Cat = NS.ContainerManager, NS.Categories
    -- Between two writer calls the stored state must not move: any change outside Create, Delete and
    -- the custom-category writer is a write the preset module made itself (architecture-section 5).
    local last, strays, calls = stored(NS), {}, 0
    local function wrap(owner, key)
        local real = owner[key]
        owner[key] = function(...)
            calls = calls + 1
            if stored(NS) ~= last then strays[#strays + 1] = "before " .. key end
            local a, b, c = real(...)
            last = stored(NS)
            return a, b, c
        end
    end
    wrap(CM, "Create")
    wrap(CM, "Delete")
    wrap(Cat, "CreateUserCategory")
    assertTrue(NS.Presets.Apply("advanced", "bars", "replace"))
    assertTrue(NS.Presets.Apply("intermediate", "icons", "add"))
    if stored(NS) ~= last then strays[#strays + 1] = "after the last writer" end
    assertTrue(calls > 30, "the writers did the work: " .. calls)
    assertEqual(#strays, 0, table.concat(strays, "; "))
    local f = assert(io.open("modules/Presets.lua", "r"))
    local src = f:read("*a")
    f:close()
    for _, field in ipairs({ "containers", "containerOrder", "nextContainerId", "userCategories",
        "userCategoryOrder" }) do
        assertNil(src:find("%." .. field .. "%s*%[[^\n]*%]%s*=[^=]"), "no direct write to " .. field)
        assertNil(src:find("%." .. field .. "%s*=[^=]"), "no direct write to " .. field)
    end
end)
