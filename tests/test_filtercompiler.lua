-- tests/test_filtercompiler.lua — modules/FilterCompiler.lua: settings in, aura-engine groups out.
--
-- The compiler is PURE (no frames, no database), which is what makes the filtering rules testable
-- at all: an aura cannot be read headlessly, but the declaration handed to the engine can. Every
-- case builds a container from the shipped template and asserts the plan.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil
local NS = T.NS
local FC = NS.FilterCompiler
local HUGE = math.huge

local function cfg(over)
    local c = NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE)
    return NS.Database.Merge(c, over or {})
end

local function compile(over, ctx) return FC.Compile(cfg(over), ctx) end

local function setOf(t)
    local keys = {}
    for k in pairs(t or {}) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    return table.concat(keys, ",")
end

local function hasWarning(plan, fragment)
    for _, w in ipairs(plan.warnings) do
        if w:find(fragment, 1, true) then return true end
    end
    return false
end

-- ── the base ──────────────────────────────────────────────────────────────────────────────────

test("filter: an unfiltered buff container is one HELPFUL group with no candidate filters", function()
    local plan = compile({})
    assertEqual(#plan.groups, 1)
    assertEqual(plan.groups[1].filter, "HELPFUL")
    assertNil(plan.groups[1].candidateFilters)
    assertEqual(#plan.warnings, 0)
end)

test("filter: a debuff container starts from HARMFUL", function()
    assertEqual(compile({ auraType = "HARMFUL" }).groups[1].filter, "HARMFUL")
end)

test("filter: cast by me and by others compile to PLAYER and its negation", function()
    assertEqual(compile({ filter = { castBy = "mine" } }).groups[1].filter, "HELPFUL|PLAYER")
    assertEqual(compile({ filter = { castBy = "others" } }).groups[1].filter, "HELPFUL|!PLAYER")
end)

-- ── duration ──────────────────────────────────────────────────────────────────────────────────

test("filter: a max duration becomes the engine's maxDuration candidate filter", function()
    local g = compile({ filter = { maxDuration = 60 } }).groups[1]
    assertEqual(g.candidateFilters.maxDuration, 60)
end)

test("filter: 'only timed' is maxDuration = huge, which drops permanent auras", function()
    local g = compile({ filter = { durationMode = "timed" } }).groups[1]
    assertEqual(g.candidateFilters.maxDuration, HUGE)
end)

test("filter: 'only timeless' excludes every learned timed spell and ignores a max duration", function()
    local plan = compile({ filter = { durationMode = "timeless", maxDuration = 30 } },
        { timedSpells = { [100] = true, [200] = true } })
    local g = plan.groups[1]
    assertEqual(setOf(g.candidateFilters.excludeSpellIDs), "100,200")
    assertNil(g.candidateFilters.maxDuration)
    assertTrue(hasWarning(plan, "Max duration is ignored"), "the ignored limit is reported")
end)

test("filter: 'only timeless' on a debuff container is reported and treated as any duration", function()
    local plan = compile({ auraType = "HARMFUL", filter = { durationMode = "timeless" } },
        { timedSpells = { [100] = true } })
    assertNil(plan.groups[1].candidateFilters, "no learned buff ids are excluded from debuffs")
    assertTrue(hasWarning(plan, "buffs only"))
end)

-- ── categories ────────────────────────────────────────────────────────────────────────────────

test("filter: showing a token category adds the token", function()
    local plan = compile({ filter = { categories = { bigDefensive = "show" } } })
    assertEqual(#plan.groups, 1)
    assertEqual(plan.groups[1].filter, "HELPFUL|BIG_DEFENSIVE")
end)

test("filter: hiding a token category adds its negation to every group", function()
    local plan = compile({ auraType = "HARMFUL", filter = { categories = { crowdControl = "hide" } } })
    assertEqual(plan.groups[1].filter, "HARMFUL|!CROWD_CONTROL")
end)

test("filter: hiding a flag category asks for the opposite value", function()
    local plan = compile({ auraType = "HARMFUL", filter = { categories = { boss = "hide" } } })
    assertEqual(plan.groups[1].candidateFilters.isBossAura, false)
end)

test("filter: a dispel category shown includes, hidden excludes", function()
    local shown = compile({ auraType = "HARMFUL", filter = { categories = { magic = "show" } } })
    assertEqual(setOf(shown.groups[1].candidateFilters.includeDispelTypes), "Magic")
    local hidden = compile({ auraType = "HARMFUL", filter = { categories = { poison = "hide" } } })
    assertEqual(setOf(hidden.groups[1].candidateFilters.excludeDispelTypes), "Poison")
end)

test("filter: two shown categories are a union, and the second excludes the first", function()
    -- defensives (a spell list) is declared before bigDefensive (a token) in defaults/Categories.lua.
    local plan = compile({ filter = { categories = { defensives = "show", bigDefensive = "show" } } })
    assertEqual(#plan.groups, 2)
    local def = NS.Categories.Find("HELPFUL", "defensives")
    assertEqual(setOf(plan.groups[1].candidateFilters.includeSpellIDs), setOf(def.spells))
    assertEqual(plan.groups[2].filter, "HELPFUL|BIG_DEFENSIVE")
    assertEqual(setOf(plan.groups[2].candidateFilters.excludeSpellIDs), setOf(def.spells),
        "an aura in both categories is drawn once, under the first")
end)

test("filter: a token shown after a token excludes it by negation", function()
    local plan = compile({ filter = { categories = { bigDefensive = "show", externals = "show" } } })
    assertEqual(plan.groups[2].filter, "HELPFUL|EXTERNAL_DEFENSIVE|!BIG_DEFENSIVE")
end)

test("filter: a category's spell edits add and remove ids", function()
    local def = NS.Categories.Find("HELPFUL", "movement")
    local starter = next(def.spells)
    local plan = compile({ filter = {
        categories = { movement = "show" },
        categorySpells = { movement = { [starter] = false, [999001] = true } },
    } })
    local inc = plan.groups[1].candidateFilters.includeSpellIDs
    assertNil(inc[starter], "a removed starter id is gone")
    assertTrue(inc[999001], "an added id is included")
end)

test("filter: a shown spell category with every id removed can never match, and says so", function()
    local def = NS.Categories.Find("HELPFUL", "consumables")
    local removed = {}
    for id in pairs(def.spells) do removed[id] = false end
    local plan = compile({ filter = { categories = { consumables = "show" }, categorySpells = { consumables = removed } } })
    assertEqual(#plan.groups, 0, "a contradiction is dropped rather than handed to the engine")
    assertTrue(hasWarning(plan, "can never match"))
end)

-- ── whitelist and blacklist ───────────────────────────────────────────────────────────────────

test("filter: the whitelist is its own first group and every other group excludes it", function()
    local plan = compile({ filter = { whitelist = { [500] = true }, categories = { bigDefensive = "show" } } })
    assertEqual(plan.groups[1].label, "Always shown")
    assertEqual(plan.groups[1].filter, "HELPFUL")
    assertEqual(setOf(plan.groups[1].candidateFilters.includeSpellIDs), "500")
    assertTrue(plan.groups[2].candidateFilters.excludeSpellIDs[500], "nothing is drawn twice")
end)

test("filter: the blacklist is excluded everywhere and beats the whitelist", function()
    local plan = compile({ filter = { whitelist = { [500] = true, [600] = true }, blacklist = { [500] = true } } })
    assertEqual(setOf(plan.groups[1].candidateFilters.includeSpellIDs), "600",
        "an id on both lists is never shown")
    assertTrue(plan.groups[2].candidateFilters.excludeSpellIDs[500])
end)

-- ── what the engine will not do ───────────────────────────────────────────────────────────────

test("filter: spell lists on your own debuffs are flagged as ignored", function()
    local plan = compile({ auraType = "HARMFUL", unit = "player", filter = { blacklist = { [1] = true } } })
    assertTrue(hasWarning(plan, "own character or pet"))
end)

test("filter: spell lists on a target's buffs only apply while it is friendly", function()
    local plan = compile({ unit = "target", filter = { whitelist = { [1] = true } } })
    assertTrue(hasWarning(plan, "friendly"))
end)

test("filter: the player's own buffs carry no identity warning", function()
    local plan = compile({ unit = "player", filter = { categories = { defensives = "show" } } })
    assertEqual(#plan.warnings, 0)
end)

-- ── weapon enchants ───────────────────────────────────────────────────────────────────────────

test("filter: a weapon-enchant container has three slots and no aura groups", function()
    local plan = compile({ auraType = "ENCHANT" })
    assertEqual(#plan.groups, 0)
    assertEqual(#plan.enchants.slots, 3)
    assertTrue(plan.enchants.hidePermanent)
end)

test("filter: an enchant container on another unit still shows the player's, and says so", function()
    assertTrue(hasWarning(compile({ auraType = "ENCHANT", unit = "target" }), "your own character"))
end)

test("filter: a player buff container may append weapon enchants; a target's may not", function()
    assertTrue(compile({ filter = { includeEnchants = true } }).enchants ~= nil)
    assertNil(compile({ unit = "target", filter = { includeEnchants = true } }).enchants)
end)

-- ── sorting and caps ──────────────────────────────────────────────────────────────────────────

test("filter: max auras caps each group; 0 means no cap", function()
    assertEqual(compile({ filter = { maxAuras = 5 } }).groups[1].maxFrameCount, 5)
    assertEqual(compile({ filter = { maxAuras = 0 } }).groups[1].maxFrameCount, HUGE)
end)

test("filter: an unknown sort method falls back to Blizzard's default", function()
    assertEqual(compile({ filter = { sortMethod = "nonsense" } }).groups[1].sortMethod, "default")
    assertEqual(compile({ filter = { sortDirection = "reverse" } }).groups[1].sortDirection, "reverse")
end)

-- ── signatures ────────────────────────────────────────────────────────────────────────────────

test("filter: Signature is independent of key insertion order and sees nested changes", function()
    assertEqual(FC.Signature({ a = 1, b = { c = 2 } }), FC.Signature({ b = { c = 2 }, a = 1 }))
    assertTrue(FC.Signature({ a = { c = 2 } }) ~= FC.Signature({ a = { c = 3 } }))
end)

test("filter: StructureKey tracks the group count, the enchant slots and hide-permanent", function()
    local a = compile({})
    local b = compile({ filter = { castBy = "mine", maxDuration = 30 } })
    assertEqual(FC.StructureKey(a), FC.StructureKey(b), "a live-editable change is not structural")
    local c = compile({ filter = { includeEnchants = true } })
    assertTrue(FC.StructureKey(a) ~= FC.StructureKey(c))
    -- AddItemEnchantment takes hidePermanent only at creation, so flipping it needs a new engine.
    local hide = compile({ filter = { includeEnchants = true, hidePermanentEnchants = true } })
    local keep = compile({ filter = { includeEnchants = true, hidePermanentEnchants = false } })
    assertTrue(FC.StructureKey(hide) ~= FC.StructureKey(keep), "hide-permanent is structural")
end)
