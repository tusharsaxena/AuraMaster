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
    for k in pairs(t or {}) do
        keys[#keys + 1] = tostring(k)
    end
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

-- ── categories (schema v3: Show / Hide) ──────────────────────────────────────────────────────

test("filter: showing a token category adds nothing — there is always exactly one group", function()
    -- was: "showing a token category adds the token". Show is the absence of a decision now, so it
    -- contributes no token at all; the container draws every aura of its type.
    local plan = compile({ filter = { categories = { bigDefensive = "show" } } })
    assertEqual(#plan.groups, 1)
    assertEqual(plan.groups[1].filter, "HELPFUL")
    assertEqual(plan.groups[1].label, "All")
    assertNil(plan.groups[1].candidateFilters)
end)

test("filter: hiding a token category adds its negation to the one group", function()
    local plan = compile({ auraType = "HARMFUL", filter = { categories = { crowdControl = "hide" } } })
    assertEqual(#plan.groups, 1)
    assertEqual(plan.groups[1].filter, "HARMFUL|!CROWD_CONTROL")
end)

test("filter: hiding a flag category asks for the opposite value", function()
    local plan = compile({ auraType = "HARMFUL", filter = { categories = { boss = "hide" } } })
    assertEqual(plan.groups[1].candidateFilters.isBossAura, false)
end)

test("filter: a dispel category shown includes nothing, hidden excludes", function()
    -- was: "a dispel category shown includes, hidden excludes". The positive (includeDispelTypes)
    -- path is deleted; showing a dispel category contributes no constraint at all.
    local shown = compile({ auraType = "HARMFUL", filter = { categories = { magic = "show" } } })
    assertNil(shown.groups[1].candidateFilters)
    local hidden = compile({ auraType = "HARMFUL", filter = { categories = { poison = "hide" } } })
    assertEqual(setOf(hidden.groups[1].candidateFilters.excludeDispelTypes), "Poison")
end)

test("filter: two shown categories still compile to the one, unfiltered group", function()
    -- was: "two shown categories are a union, and the second excludes the first" (two groups).
    -- Schema v3 deleted the per-shown-category group: showing defensives and bigDefensive together
    -- is exactly the same as showing neither.
    local plan = compile({ filter = { categories = { defensives = "show", bigDefensive = "show" } } })
    assertEqual(#plan.groups, 1)
    assertEqual(plan.groups[1].filter, "HELPFUL")
    assertNil(plan.groups[1].candidateFilters)
end)

test("filter: two hidden token categories both negate, in the one group", function()
    -- was: "a token shown after a token excludes it by negation" (a second shown-category group).
    -- There is only ever one group now, so two Hidden tokens simply both negate it.
    local plan = compile({ filter = { categories = { bigDefensive = "hide", externals = "hide" } } })
    assertEqual(#plan.groups, 1)
    assertEqual(plan.groups[1].filter, "HELPFUL|!BIG_DEFENSIVE|!EXTERNAL_DEFENSIVE")
end)

test("filter: a hidden category's spell edits add and remove ids from the exclusion", function()
    -- was: "a category's spell edits add and remove ids" (against a Shown category's includeSpellIDs).
    -- The edits now land on Hide's excludeSpellIDs, the only spell-id path left.
    local def = NS.Categories.Find("HELPFUL", "movement")
    local starter = next(def.spells)
    local plan = compile({ filter = { categories = { movement = "hide" } } },
        { categorySpells = { movement = { [starter] = false, [999001] = true } } })
    local exc = plan.groups[1].candidateFilters.excludeSpellIDs
    assertNil(exc[starter], "a removed starter id is not excluded")
    assertTrue(exc[999001], "an added id is excluded")
end)

test("filter: spell edits are the profile's, handed in ctx; a container's own old copy is ignored (schema v2)", function()
    local def = NS.Categories.Find("HELPFUL", "movement")
    local starter = next(def.spells)
    local plan = compile({ filter = { categories = { movement = "hide" },
        categorySpells = { movement = { [starter] = false } } } })
    -- red under: Compile still reading cfg.filter.categorySpells (the v1 per-container store)
    assertTrue(plan.groups[1].candidateFilters.excludeSpellIDs[starter])
end)

test("filter: both compile sites hand the compiler the profile's spell lists", function()
    local NS2 = dofile("tests/fresh_env.lua")()
    local seen, n = {}, 0
    local real = NS2.FilterCompiler.Compile
    NS2.FilterCompiler.Compile = function(c, ctx)
        n = n + 1
        seen[n] = ctx and ctx.categorySpells or false
        return real(c, ctx)
    end
    NS2.ContainerManager.RequestApply()
    NS2.ContainerManager.FlushPending()
    NS2.Helpers.RenderWarnings({}, NS2.Database.FindContainer(1))
    NS2.FilterCompiler.Compile = real
    assertTrue(n >= 2, "an apply and a warnings render compiled")
    for i = 1, n do
        -- red under: a compile site passing no categorySpells (every spell edit silently ignored)
        assertTrue(seen[i] == NS2.db.profile.categorySpells, "compile " .. i)
    end
end)

test("filter: showing a spell category with every id removed still contributes nothing", function()
    -- was: "a shown spell category with every id removed can never match, and says so" (a
    -- contradiction: an empty includeSpellIDs). That whole mechanism is deleted with the positive
    -- path — Show never writes a candidate filter, empty or otherwise.
    local def = NS.Categories.Find("HELPFUL", "consumables")
    local removed = {}
    for id in pairs(def.spells) do removed[id] = false end
    local plan = compile({ filter = { categories = { consumables = "show" } } },
        { categorySpells = { consumables = removed } })
    assertEqual(#plan.groups, 1)
    assertNil(plan.groups[1].candidateFilters)
    assertEqual(#plan.warnings, 0)
end)

-- ── Show / Hide (schema v3) ───────────────────────────────────────────────────────────────────

-- red under: the per-shown-category loop surviving, so two shown categories make two groups.
test("filter: categories set to show add no group — there is always exactly one", function()
    local plan = compile({ filter = { categories = { defensives = "show", raidCDs = "show" } } })
    assertEqual(#plan.groups, 1)
    assertEqual(plan.groups[1].filter, "HELPFUL")
    assertEqual(plan.groups[1].label, "All")
    assertNil(plan.groups[1].candidateFilters)
end)

-- red under: a hidden spell category no longer excluding, or excluding into the wrong field.
test("filter: a category set to hide excludes its spells from the one group", function()
    local plan = compile({ filter = { categories = { defensives = "hide" } } })
    assertEqual(#plan.groups, 1)
    assertTrue(plan.groups[1].candidateFilters.excludeSpellIDs[642])
end)

-- red under: a hidden token category losing its negation.
test("filter: a token category set to hide negates its token", function()
    local plan = compile({ filter = { categories = { cancelable = "hide" } } })
    assertEqual(plan.groups[1].filter, "HELPFUL|!CANCELABLE")
end)

-- red under: "show" being treated as an exclusion, which would invert the whole page.
test("filter: show and hide are not symmetric — show excludes nothing", function()
    local shown = compile({ filter = { categories = { defensives = "show" } } })
    assertNil(shown.groups[1].candidateFilters)
end)

-- red under: an empty hidden spell category writing an empty excludeSpellIDs map.
test("filter: a hidden spell category with no ids left contributes no exclusion", function()
    local edits = { defensives = {} }
    for id in pairs(NS.Categories.Find("HELPFUL", "defensives").spells) do edits.defensives[id] = false end
    local plan = FC.Compile(cfg({ filter = { categories = { defensives = "hide" } } }),
        { categorySpells = edits })
    assertEqual(#plan.groups, 1)
    assertNil(plan.groups[1].candidateFilters)
end)

-- ── whitelist and blacklist ───────────────────────────────────────────────────────────────────

test("filter: the whitelist is its own first group and every other group excludes it", function()
    local plan = compile({ filter = { whitelist = { [500] = true } } })
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
    local plan = compile({ unit = "player", filter = { categories = { defensives = "hide" } } })
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

-- ── characterization: whole plans (testing-§13) ──────────────────────────────────────────────────
-- Each signature was captured from FC.Compile as one function, before it was split into helpers. A
-- change to the shipped categories or warnings moves these on purpose; recapture them then.

-- Only token, flag and dispel categories, so a signature does not carry a whole shipped spell list.
local RICH = {
    { { unit = "player", auraType = "HELPFUL", filter = {
        castBy = "others", durationMode = "timeless", maxDuration = 30, maxAuras = 5,
        sortMethod = "bogus", sortDirection = "reverse", includeEnchants = true,
        whitelist = { [100] = true, [200] = true }, blacklist = { [200] = true, [300] = true },
        categories = { bigDefensive = "show", castable = "show", important = "hide", stealable = "hide" },
    } }, { timedSpells = { [400] = true } } },
    { { unit = "target", auraType = "HARMFUL", filter = {
        castBy = "mine", durationMode = "timeless", maxDuration = 12,
        categories = { magic = "show", boss = "show", crowdControl = "hide" },
    } } },
    { { unit = "focus", auraType = "HELPFUL", filter = {
        durationMode = "timed", whitelist = { [500] = true }, categories = { bigDefensive = "show" },
    } } },
    { { unit = "target", auraType = "ENCHANT" } },
}

local RICH_SIGNATURES = {
    -- Show/Hide (schema v3): "show" categories (bigDefensive, castable) contribute nothing; the two
    -- "hide" categories (important, stealable) fold into the one category group alongside the base.
    "{enchants={hidePermanent=boolean:true,slots={1=string:mainHand,2=string:offHand,3=string:ranged}},"
    .. "groups={1={candidateFilters={includeSpellIDs={100=boolean:true}},filter=string:HELPFUL,key=string:g1,"
    .. "label=string:Always shown,maxFrameCount=number:5,sortDirection=string:reverse,sortMethod=string:default},"
    .. "2={candidateFilters={excludeSpellIDs={100=boolean:true,200=boolean:true,300=boolean:true,400=boolean:true},"
    .. "isStealable=boolean:false},filter=string:HELPFUL|!PLAYER|!IMPORTANT,key=string:g2,"
    .. "label=string:All,maxFrameCount=number:5,sortDirection=string:reverse,"
    .. "sortMethod=string:default}},"
    .. "warnings={1=string:Max duration is ignored while showing only auras without a duration.}}",

    -- magic (show) contributes nothing; boss (show) contributes nothing; crowdControl (hide) negates.
    "{groups={1={candidateFilters={maxDuration=number:12},"
    .. "filter=string:HARMFUL|PLAYER|!CROWD_CONTROL,key=string:g1,label=string:All,"
    .. "maxFrameCount=number:inf,sortDirection=string:normal,sortMethod=string:expirationOnly}},"
    .. "warnings={1=string:Only auras without a duration works for buffs only; this container shows every duration.}}",

    -- bigDefensive (show) contributes nothing to the one category group.
    "{groups={1={candidateFilters={includeSpellIDs={500=boolean:true}},filter=string:HELPFUL,key=string:g1,"
    .. "label=string:Always shown,maxFrameCount=number:inf,sortDirection=string:normal,sortMethod=string:expirationOnly},"
    .. "2={candidateFilters={excludeSpellIDs={500=boolean:true},maxDuration=number:inf},filter=string:HELPFUL,"
    .. "key=string:g2,label=string:All,maxFrameCount=number:inf,sortDirection=string:normal,"
    .. "sortMethod=string:expirationOnly}},"
    .. "warnings={1=string:Spell lists only apply while the unit is friendly.}}",

    "{enchants={hidePermanent=boolean:true,slots={1=string:mainHand,2=string:offHand,3=string:ranged}},groups={},"
    .. "warnings={1=string:Weapon enchants only exist on your own character; this container shows the player's "
    .. "enchants whatever its unit is set to.}}",
}

test("filter: the whole plan for four rich containers is unchanged (characterization)", function()
    local off = {}
    for i, case in ipairs(RICH) do
        -- math.huge prints as "inf" here and as "1.#INF" under an MSVC-built Lua.
        local got = (FC.Signature(compile(case[1], case[2])):gsub("1%.#INF", "inf"))
        if got ~= RICH_SIGNATURES[i] then
            off[#off + 1] = "case " .. i .. " got " .. got
        end
    end
    assertEqual(#off, 0, table.concat(off, " || "))
end)

-- ── edges ────────────────────────────────────────────────────────────────────────────────────

test("filter: Signature tells a number from its string and a boolean from its name", function()
    -- red under: Signature dropping the type prefix (a 60 and a "60" filter would compare equal)
    assertTrue(FC.Signature(1) ~= FC.Signature("1"))
    assertTrue(FC.Signature(true) ~= FC.Signature("true"))
    assertTrue(FC.Signature({ maxDuration = 60 }) ~= FC.Signature({ maxDuration = "60" }))
    assertTrue(FC.Signature(nil) ~= FC.Signature(false))
end)

test("filter: numeric strings in the duration and cap settings are read as numbers", function()
    local g = compile({ filter = { maxDuration = "45", maxAuras = "4" } }).groups[1]
    -- red under: applyDuration without its tonumber (a stored string limit would raise or never filter)
    assertEqual(g.candidateFilters.maxDuration, 45)
    assertEqual(g.maxFrameCount, 4)
    -- red under: lookOf without its math.floor
    assertEqual(compile({ filter = { maxAuras = 3.7 } }).groups[1].maxFrameCount, 3, "a cap is whole")
    assertEqual(compile({ filter = { maxAuras = -2 } }).groups[1].maxFrameCount, HUGE, "a negative cap is none")
    assertNil(compile({ filter = { maxDuration = "soon" } }).groups[1].candidateFilters)
end)

test("filter: spell lists accept string ids and drop ids switched off", function()
    local plan = compile({ filter = { whitelist = { ["500"] = true, [600] = false, soon = true } } })
    local inc = plan.groups[1].candidateFilters.includeSpellIDs
    -- red under: spellSet keeping an id stored as false
    assertEqual(setOf(inc), "500")
    -- red under: spellSet keying by the stored key instead of its number
    assertTrue(inc[500], "keyed by number, as the engine matches")
end)

test("filter: a category's spell edits accept string ids and ignore keys that are not ids", function()
    local def = NS.Categories.Find("HELPFUL", "movement")
    local starter = next(def.spells)
    local set = FC.CategorySpells(def, { movement = {
        ["999002"] = true, notAnId = true, [tostring(starter)] = false,
    } })
    -- red under: CategorySpells without its tonumber (the edits would be keyed by string)
    assertTrue(set[999002])
    assertNil(set[starter], "a starter removed by its string id is gone")
    assertNil(set.notAnId)
    assertTrue(next(FC.CategorySpells(def, nil)) ~= nil, "no edits: the starter list")
end)

test("filter: an unknown aura type compiles as buffs, and only buffs append weapon enchants", function()
    -- red under: Compile handing the stored aura type to the engine as its token
    assertEqual(compile({ auraType = "BOGUS" }).groups[1].filter, "HELPFUL")
    assertEqual(compile({ auraType = false }).groups[1].filter, "HELPFUL")
    -- red under: dropping the HELPFUL check (a debuff container would grow enchant slots)
    assertNil(compile({ auraType = "HARMFUL", unit = "player", filter = { includeEnchants = true } }).enchants)
end)

test("filter: the spell-list warning follows the unit and the aura type", function()
    local cases = {
        { "HARMFUL", "pet", "own character or pet" },
        { "HARMFUL", "focus", "while the unit is hostile" },
        { "HELPFUL", "focus", "while the unit is friendly" },
        { "HELPFUL", "pet", nil },
    }
    for _, c in ipairs(cases) do
        local plan = compile({ auraType = c[1], unit = c[2], filter = { blacklist = { [1] = true } } })
        local label = c[1] .. " on " .. c[2]
        if c[3] then
            -- red under: identityWarning treating the pet as a hostile unit
            assertTrue(hasWarning(plan, c[3]), label)
        else
            assertEqual(#plan.warnings, 0, label .. ": the pet is friendly, and its buffs honor ids")
        end
    end
end)

test("filter: 'only timeless' with nothing learned yet filters no ids and warns about none", function()
    local empty = compile({ unit = "target", filter = { durationMode = "timeless" } }, { timedSpells = {} })
    -- red under: applyDuration reporting a spell-id filter for an empty learned set
    assertNil(empty.groups[1].candidateFilters)
    assertEqual(#empty.warnings, 0)
    local learned = compile({ unit = "target", filter = { durationMode = "timeless" } }, { timedSpells = { [7] = true } })
    assertTrue(hasWarning(learned, "friendly"), "once ids are excluded, the friendly-only rule applies")
end)

test("filter: a hidden spell category with every id removed excludes nothing", function()
    local def = NS.Categories.Find("HELPFUL", "consumables")
    local removed = {}
    for id in pairs(def.spells) do removed[id] = false end
    local plan = compile({ filter = { categories = { consumables = "hide" } } }, { categorySpells = { consumables = removed } })
    assertEqual(#plan.groups, 1)
    -- red under: excludeCategory adding an empty exclude map for a hidden category
    assertNil(plan.groups[1].candidateFilters)
end)

test("filter: a contradiction drops the category group without disturbing the whitelist group's key", function()
    -- was: "group keys stay consecutive when a contradiction drops a group" (a dropped middle
    -- shown-category group). Schema v3 leaves at most two groups — whitelist, then the one category
    -- group — so the surviving case is the category group conflicting and being dropped entirely.
    -- fromNonPlayers and fromPlayers hide the same field to opposite values: hiding both is
    -- self-contradictory. Update addresses the live engine's groups by these keys, so the whitelist
    -- group ahead of the drop must keep key "g1" rather than being renumbered.
    local plan = compile({ auraType = "HARMFUL", filter = {
        whitelist = { [500] = true },
        categories = { fromPlayers = "hide", fromNonPlayers = "hide" },
    } })
    assertEqual(#plan.groups, 1, "the contradictory category group is dropped")
    assertEqual(plan.groups[1].key, "g1")
    assertEqual(plan.groups[1].label, "Always shown")
end)

-- red under: setFlag regaining its old "soft" forgiveness for a Hide negation, which would let one
-- of the two contradictory hides silently win (and a group survive) instead of the container being
-- reported as unmatchable.
test("filter: hiding two categories that contradict on the same flag leaves nothing, and says so", function()
    -- fromPlayers and fromNonPlayers share isFromPlayerOrPlayerPet at opposite values; hiding both,
    -- with no whitelist to keep a group alive, is a genuine contradiction that drops the container's
    -- only group — the one case that still exercises finishWarnings' zero-group NEVER_MATCHES branch.
    local plan = compile({ auraType = "HARMFUL", filter = {
        categories = { fromPlayers = "hide", fromNonPlayers = "hide" },
    } })
    assertEqual(#plan.groups, 0, "isFromPlayerOrPlayerPet can't be both true and false")
    assertTrue(hasWarning(plan, "can never match"))
end)
