-- tests/test_categories_clients.lua — the per-client category seeds, the CastToAura selection and
-- the empty-category gate (AM-FP06; spec 3.3 and 3.4; clients-§4, clients-§5). Every case asserts
-- against the ACTIVE kit profile (`KA0S_KIT_CLIENT=retail|forever`, retail the default), so a run
-- under each profile is the per-client test clients-§6 asks for: present where declared, absent
-- where not.
--
-- The shipped `NS.CategorySeedsForever.EMPTY` is empty today (every `spells` category has a Forever
-- seed), so the gate is exercised through a SYNTHETIC empty set, written into the environment right
-- after defaults/Categories_Forever.lua loads and before defaults/Categories.lua reads it.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")

local PROFILE = os.getenv("KA0S_KIT_CLIENT") or "retail"
local IS_FOREVER = PROFILE == "forever"

local SEEDS_FILE = "defaults/Categories_Forever.lua"

--- A fresh environment whose Forever data declares `emptyKeys` empty, as a re-run of the generator
--- that found nothing for them would. `opts` passes through to tests/fresh_env.lua.
local function envWithEmpty(emptyKeys, opts)
    opts = opts or {}
    opts.afterFile = function(path, NS)
        if path ~= SEEDS_FILE then return end
        local seeds = NS.CategorySeedsForever
        for _, key in ipairs(emptyKeys) do
            seeds.EMPTY[key] = true
            seeds[key] = nil
        end
    end
    return fresh(opts)
end

local function keysOf(list)
    local out = {}
    for i, def in ipairs(list) do out[i] = def.key end
    return table.concat(out, ",")
end

--- The id -> class map a class table builds, the shape `def.spells` holds.
local function flatten(byClass)
    local out = {}
    for class, ids in pairs(byClass or {}) do
        for _, id in ipairs(ids) do out[id] = class end
    end
    return out
end

local function sameMap(a, b)
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k, v in pairs(b) do if a[k] ~= v then return false end end
    return true
end

local function shippedSpellDefs(NS)
    local out = {}
    for _, auraType in ipairs({ "HELPFUL", "HARMFUL" }) do
        for _, def in ipairs(NS.Categories.For(auraType)) do
            if def.kind == "spells" and not def.userCategory then out[#out + 1] = def end
        end
    end
    return out
end

-- ── Retail regressions (review focus 5) ──────────────────────────────────────────────────────
--
-- Taken from master's defaults/Categories.lua before AM-FP06 (2026-11-14): each category's key in
-- declaration order, and for a `spells` category its distinct id count and the sum of its ids.
local RETAIL_SNAPSHOT = {
    HELPFUL = {
        { "defensives", 54, 7800558 },
        { "bigDefensive" }, { "externals" },
        { "activeMitigation", 6, 1046344 },
        { "raidCDs", 16, 4191808 },
        { "offensiveCDs", 35, 10900713 },
        { "healing", 44, 17554122 },
        { "support", 26, 9305177 },
        { "groupBuffs", 18, 5456421 },
        { "movement", 53, 15483836 },
        { "utility", 9, 183834 },
        { "stances", 15, 2304469 },
        { "racials", 37, 8955369 },
        { "important" }, { "castable" }, { "cancelable" }, { "stealable" },
        { "weaponEnchants" }, { "uncategorized" },
    },
    HARMFUL = {
        { "hardCC", 62, 9244669 },
        { "ccRoot", 14, 2404631 },
        { "ccSnare", 45, 10273016 },
        { "racialDebuffs", 8, 2896090 },
        { "crowdControl" }, { "boss" }, { "role" }, { "priority" }, { "raid" }, { "raidInCombat" },
        { "groupDispellable" }, { "dispellable" }, { "dispels" },
        { "magic" }, { "curse" }, { "disease" }, { "poison" }, { "bleed" },
        { "fromNonPlayers" }, { "fromPlayers" }, { "uncategorizedDebuffs" },
    },
}

test("categories clients: retail categories unchanged, the same keys in the same order with the same ids", function()
    local NS = T.NS
    local empty = NS.CategorySeedsForever.EMPTY
    for _, auraType in ipairs({ "HELPFUL", "HARMFUL" }) do
        local want = {}
        for _, row in ipairs(RETAIL_SNAPSHOT[auraType]) do
            -- on forever a key the data declares empty is absent, and nothing else moves
            if not (IS_FOREVER and empty[row[1]]) then want[#want + 1] = row[1] end
        end
        -- red under: a gate that drops or reorders a category it should keep
        assertEqual(keysOf(NS.Categories.For(auraType)), table.concat(want, ","), auraType .. " keys")
        if not IS_FOREVER then
            for _, row in ipairs(RETAIL_SNAPSHOT[auraType]) do
                local def = NS.Categories.Find(auraType, row[1])
                if row[2] then
                    local n, sum = 0, 0
                    for id in pairs(def.spells) do n, sum = n + 1, sum + id end
                    -- red under: Retail's lists filtered, swapped or edited by the split
                    assertEqual(n, row[2], row[1] .. " id count")
                    assertEqual(sum, row[3], row[1] .. " id sum")
                end
            end
        end
    end
end)

-- ── the seeds, picked once (clients-§5) ──────────────────────────────────────────────────────

test("categories clients: forever seeds picked, every spells category's ids are the client's own list", function()
    local NS = T.NS
    local seeds = NS.CategorySeedsForever
    local differs = 0
    for _, def in ipairs(shippedSpellDefs(NS)) do
        local forever = flatten(seeds[def.key])
        if IS_FOREVER then
            -- red under: the Retail list on Forever, or a Retail list filtered down to Forever's ids
            assertTrue(sameMap(def.spells, forever), def.key .. " carries the Forever seed")
        elseif not sameMap(def.spells, forever) then
            differs = differs + 1
        end
    end
    if not IS_FOREVER then
        -- red under: the Forever seeds picked on Retail
        assertEqual(differs, #shippedSpellDefs(NS), "every Retail list is Retail's own")
    end
end)

test("categories clients: the Forever data covers every shipped spells category exactly once", function()
    local NS = T.NS
    local seeds = NS.CategorySeedsForever
    -- red under: a generator run that drops a category without declaring it empty, which would ship
    -- an empty list on Forever rather than gate it (clients-§5: empty by decision and says so)
    local master = {}
    for _, auraType in ipairs({ "HELPFUL", "HARMFUL" }) do
        for _, row in ipairs(RETAIL_SNAPSHOT[auraType]) do
            if row[2] then master[#master + 1] = row[1] end
        end
    end
    for _, key in ipairs(master) do
        local seeded, empty = seeds[key] ~= nil, seeds.EMPTY[key] == true
        assertTrue(seeded ~= empty, key .. " is seeded or declared empty, not both and not neither")
    end
    for key in pairs(seeds.EMPTY) do
        local def = NS.Categories.Find("HELPFUL", key) or NS.Categories.Find("HARMFUL", key)
        if not IS_FOREVER then
            assertTrue(def ~= nil and def.kind == "spells", "EMPTY names a spells category: " .. tostring(key))
        end
    end
end)

test("categories clients: hardCC holds every Polymorph rank on forever", function()
    local NS = T.NS
    local hardCC = NS.Categories.Find("HARMFUL", "hardCC").spells
    if IS_FOREVER then
        -- red under: a name map that kept rank 1 alone (review focus 2): a filter matches one id
        for _, id in ipairs({ 118, 12824, 12825, 12826, 28271, 28272 }) do
            assertEqual(hardCC[id], "MAGE", "Polymorph " .. id)
        end
    else
        assertEqual(hardCC[118], "MAGE", "Retail's Polymorph")
        assertNil(hardCC[12824], "Retail carries no vanilla rank")
    end
end)

local FOREVER_CLASSES = {
    WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true,
    SHAMAN = true, MAGE = true, WARLOCK = true, DRUID = true, ALL = true,
}

test("categories clients: no Retail-only class key on forever", function()
    local NS = T.NS
    local retailOnly = 0
    for _, def in ipairs(shippedSpellDefs(NS)) do
        for id, class in pairs(def.spells) do
            if IS_FOREVER then
                -- red under: a DEATHKNIGHT/MONK/DEMONHUNTER/EVOKER table on Forever (review focus 3)
                assertTrue(FOREVER_CLASSES[class], ("%s: %d under %s"):format(def.key, id, tostring(class)))
            elseif not FOREVER_CLASSES[class] then
                retailOnly = retailOnly + 1
            end
        end
    end
    if not IS_FOREVER then
        assertTrue(retailOnly > 0, "Retail keeps its own classes (the check can go red)")
    end
end)

-- ── the gate (clients-§4) ────────────────────────────────────────────────────────────────────

test("categories clients: empty forever category absent everywhere on forever, present on retail", function()
    local NS = envWithEmpty({ "stances", "hardCC" })
    local Cat = NS.Categories
    local states = Cat.DefaultStates()
    for _, pair in ipairs({ { "HELPFUL", "stances" }, { "HARMFUL", "hardCC" } }) do
        local auraType, key = pair[1], pair[2]
        local inList = false
        for _, def in ipairs(Cat[auraType]) do if def.key == key then inList = true end end
        local row = NS.FindSchemaRow("container.filter.categories." .. key)
        local templ = NS.CONTAINER_TEMPLATE.filter.categories[key]
        if IS_FOREVER then
            -- red under: a gated category registered and then hidden, or not gated at all
            assertFalse(inList, key .. " in Cat." .. auraType)
            assertNil(Cat.Find(auraType, key), key .. " Cat.Find")
            assertFalse(Cat.IsSpellCategory(key), key .. " IsSpellCategory")
            assertNil(states[key], key .. " DefaultStates")
            assertNil(row, key .. " schema row")
            assertNil(templ, key .. " container template")
        else
            assertTrue(inList, key .. " in Cat." .. auraType)
            assertTrue(Cat.Find(auraType, key) ~= nil, key .. " Cat.Find")
            assertEqual(states[key], "show", key .. " DefaultStates")
            assertTrue(row ~= nil, key .. " schema row")
            assertEqual(templ, "show", key .. " container template")
        end
    end
    -- the neighbors stay (presence only; list order is not asserted here)
    assertTrue(Cat.Find("HELPFUL", "utility") ~= nil and Cat.Find("HELPFUL", "racials") ~= nil)
    assertEqual(NS.ValidateSchema(), 0, "the schema stays valid")
end)

test("categories clients: a gated key leaves no ghost in the Player cooldowns starter", function()
    local NS = envWithEmpty({ "defensives" })
    -- The fixture's Player cooldowns (tests/starters_fixture.lua), built in THIS environment, so its
    -- StatesShowing list reads the gated lists.
    local starter
    for _, c in ipairs(AM_TEST.Starters.list(NS)) do
        if c.name == "Player cooldowns" then starter = c end
    end
    local cats = starter.filter.categories
    if IS_FOREVER then
        -- red under: StatesShowing writing "show" for a key no list holds
        assertNil(cats.defensives, "a gated key is not a starter state")
    else
        assertEqual(cats.defensives, "show")
    end
    assertEqual(cats.offensiveCDs, "show", "the other shown category is kept")
    assertEqual(cats.utility, "hide")
end)

test("categories clients: a gated key in a stored profile is inert", function()
    local function profile()
        return {
            seeded = true, nextContainerId = 2, containerOrder = { 1 },
            containers = { [1] = {
                name = "Copied", unit = "player", auraType = "HELPFUL", style = "bars",
                filter = { categories = { stances = "hide", defensives = "show" } },
            } },
            categorySpells = { stances = { [999001] = true } },
        }
    end
    local NS = envWithEmpty({ "stances" }, {
        savedVariables = { profiles = { Default = profile() }, global = { schemaVersion = T.NS.SCHEMA_VERSION } },
    })
    local con = NS.db.profile.containers[1]
    -- red under: a normalizer or backfill that deletes what another client wrote
    assertEqual(con.filter.categories.stances, "hide", "the stored state is left alone")
    assertTrue(NS.db.profile.categorySpells.stances ~= nil, "the stored edits are left alone")
    local plan = NS.FilterCompiler.Compile(con, NS.FilterCompiler.ProfileContext())
    assertTrue(type(plan) == "table" and type(plan.groups) == "table", "the container compiles")
    local shows = NS.FilterCompiler.ClaimingCategories(NS.Categories, "HELPFUL", con.filter,
        NS.db.profile.categorySpells, 999001)
    if IS_FOREVER then
        -- red under: a ghost row in the grid, or the stored key read as a category
        assertNil(NS.FindSchemaRow("container.filter.categories.stances"), "no grid row")
        assertEqual(#shows, 0, "the stored key is never read as a category")
    else
        assertTrue(NS.FindSchemaRow("container.filter.categories.stances") ~= nil, "the row is live on retail")
        assertEqual(shows[1] and shows[1].key, "stances", "retail reads the stored edit")
    end
    assertEqual(NS.ValidateSchema(), 0, "the schema stays valid")
end)

-- ── CastToAura (clients-§5) ──────────────────────────────────────────────────────────────────

test("categories clients: CastToAura selects per client", function()
    local NS = T.NS
    assertTrue(type(NS.CastToAuraForever) == "table" and NS.CastToAuraForever.REWRITE ~= nil,
        "the Forever table is loaded")
    if IS_FOREVER then
        -- red under: CastToAura_Forever.lua missing from the TOC, or loaded before CastToAura.lua
        assertTrue(NS.CastToAura == NS.CastToAuraForever, "Forever's table on forever")
        local kind, aura = NS.CastAura.Resolve(100)
        assertEqual(kind, "rewrite", "Charge rewrites")
        assertEqual(aura, 7922, "to its Forever aura")
    else
        assertTrue(NS.CastToAura ~= NS.CastToAuraForever, "Retail's table on retail")
        assertTrue(NS.CastToAura.REWRITE ~= NS.CastToAuraForever.REWRITE)
        assertTrue(next(NS.CastToAura.REWRITE) ~= nil, "Retail's REWRITE is populated")
    end
end)

-- ── user categories (the reserved namespace and the materialize path) ────────────────────────

test("categories clients: user categories still materialize on forever", function()
    local NS = envWithEmpty({ "stances" })
    local Cat = NS.Categories
    local buff = Cat.CreateUserCategory("Mine", "HELPFUL")
    local debuff = Cat.CreateUserCategory("Theirs", "HARMFUL")
    assertTrue(buff ~= nil and debuff ~= nil, "both create")
    -- red under: a user category gated as if it were a shipped one with no seed
    assertEqual(Cat.AuraTypeOf(buff), "HELPFUL")
    assertEqual(Cat.AuraTypeOf(debuff), "HARMFUL")
    assertTrue(Cat.IsSpellCategory(buff), "a user category is a spell category")
    assertTrue(NS.FindSchemaRow("container.filter.categories." .. buff) ~= nil, "its row")
    local list = Cat.For("HELPFUL")
    local at, uncategorized
    for i, def in ipairs(list) do
        if def.key == buff then at = i end
        if def.key == "uncategorized" then uncategorized = i end
    end
    assertTrue(at and uncategorized and at < uncategorized, "drawn above Uncategorized")
    assertEqual(NS.ValidateSchema(), 0, "the schema stays valid")
end)
