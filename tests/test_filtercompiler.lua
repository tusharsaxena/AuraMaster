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

--- A `ctx.categories` stub over the REAL category defs (defaults/Categories.lua), narrowed to just
--- `keys`, declaration order preserved. Since the filter-priority revision (docs/superpowers/specs/
--- 2026-09-14-feedback-batch6-design.md section 6) makes every OTHER category of the same aura type
--- a Show group the moment one Hide exists (R-4), a case built on the full shipped list explodes to
--- one group per shipped category; this keeps a case testing one or two categories' interaction to
--- exactly that many groups, without inventing category data of its own.
local function only(auraType, keys)
    local want = {}
    for _, k in ipairs(keys) do want[k] = true end
    local out = {}
    for _, def in ipairs(NS.Categories.For(auraType)) do
        if want[def.key] then
            local n = #out
            out[n + 1] = def
        end
    end
    return { For = function() return out end }
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

-- ── categories: filter priority (revised 2026-09-15, spec section 6) ────────────────────────────
--
-- Every case below narrows `ctx.categories` to the specific keys under test (the `only` helper
-- above), because a real container's category list stamps every OTHER category of the aura type to
-- "show" by default (F-6) — once one category is Hidden, R-4 turns every one of those into its own
-- group. The RICH characterization test further down exercises the real, unnarrowed list.

test("filter: showing a token category adds nothing when nothing is hidden — there is always exactly one group (R-3)", function()
    -- Show is a positive claim now (rank 3), but rank 3 cannot rescue anything when nothing is
    -- hiding (R-3), so a lone Show still contributes no token and the container draws everything.
    local plan = compile({ filter = { categories = { bigDefensive = "show" } } },
        { categories = only("HELPFUL", { "bigDefensive" }) })
    assertEqual(#plan.groups, 1)
    assertEqual(plan.groups[1].filter, "HELPFUL")
    assertEqual(plan.groups[1].label, "All")
    assertNil(plan.groups[1].candidateFilters)
end)

test("filter: hiding a token category negates its token in the catch-all (R-5)", function()
    local plan = compile({ auraType = "HARMFUL", filter = { categories = { crowdControl = "hide" } } },
        { categories = only("HARMFUL", { "crowdControl" }) })
    assertEqual(#plan.groups, 1, "nothing else is shown or hidden, so the catch-all is the only group")
    assertEqual(plan.groups[1].filter, "HARMFUL|!CROWD_CONTROL")
end)

test("filter: hiding a flag category asks for the opposite value", function()
    local plan = compile({ auraType = "HARMFUL", filter = { categories = { boss = "hide" } } },
        { categories = only("HARMFUL", { "boss" }) })
    assertEqual(plan.groups[1].candidateFilters.isBossAura, false)
end)

test("filter: a dispel category shown includes nothing when nothing is hidden, hidden excludes", function()
    local shown = compile({ auraType = "HARMFUL", filter = { categories = { magic = "show" } } },
        { categories = only("HARMFUL", { "magic" }) })
    assertNil(shown.groups[1].candidateFilters)
    local hidden = compile({ auraType = "HARMFUL", filter = { categories = { poison = "hide" } } },
        { categories = only("HARMFUL", { "poison" }) })
    assertEqual(setOf(hidden.groups[1].candidateFilters.excludeDispelTypes), "Poison")
end)

test("filter: two shown categories with nothing hidden still compile to the one, unfiltered group (R-3)", function()
    local plan = compile({ filter = { categories = { defensives = "show", bigDefensive = "show" } } },
        { categories = only("HELPFUL", { "defensives", "bigDefensive" }) })
    assertEqual(#plan.groups, 1)
    assertEqual(plan.groups[1].filter, "HELPFUL")
    assertNil(plan.groups[1].candidateFilters)
end)

test("filter: two hidden token categories both negate, in the catch-all (R-5)", function()
    local plan = compile({ filter = { categories = { bigDefensive = "hide", externals = "hide" } } },
        { categories = only("HELPFUL", { "bigDefensive", "externals" }) })
    assertEqual(#plan.groups, 1)
    assertEqual(plan.groups[1].filter, "HELPFUL|!BIG_DEFENSIVE|!EXTERNAL_DEFENSIVE")
end)

test("filter: a hidden category's spell edits add and remove ids from the catch-all's exclusion", function()
    local def = NS.Categories.Find("HELPFUL", "movement")
    local starter = next(def.spells)
    local plan = compile({ filter = { categories = { movement = "hide" } } },
        { categorySpells = { movement = { [starter] = false, [999001] = true } },
          categories = only("HELPFUL", { "movement" }) })
    local exc = plan.groups[1].candidateFilters.excludeSpellIDs
    assertNil(exc[starter], "a removed starter id is not excluded")
    assertTrue(exc[999001], "an added id is excluded")
end)

test("filter: spell edits are the profile's, handed in ctx; a container's own old copy is ignored (schema v2)", function()
    local def = NS.Categories.Find("HELPFUL", "movement")
    local starter = next(def.spells)
    local plan = compile({ filter = { categories = { movement = "hide" },
        categorySpells = { movement = { [starter] = false } } } },
        { categories = only("HELPFUL", { "movement" }) })
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

-- ── Show / Hide, rechecked against the catch-all (R-3 / R-5) ────────────────────────────────────

-- red under: R-3's single-group optimization not applying when nothing is Hidden.
test("filter: categories set to show add no group when nothing is hidden — there is always exactly one", function()
    local plan = compile({ filter = { categories = { defensives = "show", raidCDs = "show" } } },
        { categories = only("HELPFUL", { "defensives", "raidCDs" }) })
    assertEqual(#plan.groups, 1)
    assertEqual(plan.groups[1].filter, "HELPFUL")
    assertEqual(plan.groups[1].label, "All")
    assertNil(plan.groups[1].candidateFilters)
end)

-- red under: a hidden spell category no longer excluding, or excluding into the wrong field.
test("filter: a category set to hide excludes its spells from the catch-all", function()
    local plan = compile({ filter = { categories = { defensives = "hide" } } },
        { categories = only("HELPFUL", { "defensives" }) })
    assertEqual(#plan.groups, 1)
    assertTrue(plan.groups[1].candidateFilters.excludeSpellIDs[642])
end)

-- red under: a hidden token category losing its negation.
test("filter: a token category set to hide negates its token", function()
    local plan = compile({ filter = { categories = { cancelable = "hide" } } },
        { categories = only("HELPFUL", { "cancelable" }) })
    assertEqual(plan.groups[1].filter, "HELPFUL|!CANCELABLE")
end)

-- red under: "show" being treated as an exclusion, which would invert the whole page.
test("filter: show and hide are not symmetric — show excludes nothing", function()
    local shown = compile({ filter = { categories = { defensives = "show" } } },
        { categories = only("HELPFUL", { "defensives" }) })
    assertNil(shown.groups[1].candidateFilters)
end)

-- red under: an empty hidden spell category writing an empty excludeSpellIDs map.
test("filter: a hidden spell category with no ids left contributes no exclusion", function()
    local edits = { defensives = {} }
    for id in pairs(NS.Categories.Find("HELPFUL", "defensives").spells) do edits.defensives[id] = false end
    local plan = FC.Compile(cfg({ filter = { categories = { defensives = "hide" } } }),
        { categorySpells = edits, categories = only("HELPFUL", { "defensives" }) })
    assertEqual(#plan.groups, 1)
    assertNil(plan.groups[1].candidateFilters)
end)

-- ── whitelist and blacklist (R-1, R-2, R-7) ──────────────────────────────────────────────────────

test("filter: the whitelist is its own first group and every other group excludes it", function()
    local plan = compile({ filter = { whitelist = { [500] = true } } })
    assertEqual(plan.groups[1].label, "Always shown")
    assertEqual(plan.groups[1].filter, "HELPFUL")
    assertEqual(setOf(plan.groups[1].candidateFilters.includeSpellIDs), "500")
    assertTrue(plan.groups[2].candidateFilters.excludeSpellIDs[500], "nothing is drawn twice")
end)

test("filter: the whitelist beats the blacklist — an id on both lists is shown (R-2)", function()
    -- was: "the blacklist is excluded everywhere and beats the whitelist" (500 dropped from both).
    -- The owner's 2026-09-15 revision inverts this: the whitelist wins, so 500 stays shown and is
    -- removed from the blacklist instead.
    local plan = compile({ filter = { whitelist = { [500] = true, [600] = true }, blacklist = { [500] = true } } })
    assertEqual(setOf(plan.groups[1].candidateFilters.includeSpellIDs), "500,600",
        "both ids are shown; the whitelist wins over the blacklist")
    -- red under: applyLists still removing the whitelisted id from the WHITELIST (the old "never
    -- beats always"), which would drop 500 out of includeSpellIDs above
    assertEqual(setOf(plan.groups[2].candidateFilters.excludeSpellIDs), "500,600",
        "the catch-all excludes the whole whitelist; nothing is left on the blacklist to add to it")
end)

test("filter: the blacklist still reaches the catch-all, but never the whitelist group (R-7)", function()
    local plan = compile({ filter = { whitelist = { [500] = true }, blacklist = { [700] = true } } })
    assertNil(plan.groups[1].candidateFilters.excludeSpellIDs, "the whitelist group ignores the blacklist entirely")
    assertTrue(plan.groups[2].candidateFilters.excludeSpellIDs[700], "the catch-all still honors the blacklist")
end)

-- ── "only these categories" (D8, R-8..R-11) ──────────────────────────────────────────────────────

test("filter: off, the toggle changes nothing — a default container still stays at one group (R-3)", function()
    local plan = compile({ filter = { onlyShown = false } },
        { categories = only("HELPFUL", { "bigDefensive" }) })
    assertEqual(#plan.groups, 1)
    assertEqual(plan.groups[1].label, "All")
    assertNil(plan.groups[1].candidateFilters)
end)

test("filter: on, one shown category and nothing hidden still gets its own group — R-3 does not apply (R-9)", function()
    -- red under: the toggle reusing R-3's single-group optimization when nothing is Hidden
    local plan = compile({ filter = { onlyShown = true, categories = { bigDefensive = "show" } } },
        { categories = only("HELPFUL", { "bigDefensive" }) })
    assertEqual(#plan.groups, 1, "the shown group IS the container; no catch-all beside it")
    assertEqual(plan.groups[1].filter, "HELPFUL|BIG_DEFENSIVE")
    assertTrue(plan.groups[1].label ~= "All", "not the catch-all — there isn't one")
end)

test("filter: on, an aura in no category is not drawn — the catch-all is dropped (R-9)", function()
    -- Two categories in the fixture: one Shown, one left at its default Show too (still contributes
    -- its own group under the toggle), so the only way to prove the catch-all is gone is that a
    -- container narrowed to just one category draws through exactly one, whitelist-less group.
    local on = compile({ filter = { onlyShown = true, categories = { bigDefensive = "show" } } },
        { categories = only("HELPFUL", { "bigDefensive" }) })
    local off = compile({ filter = { onlyShown = false, categories = { bigDefensive = "show" } } },
        { categories = only("HELPFUL", { "bigDefensive" }) })
    assertEqual(#on.groups, 1, "on: only the shown group")
    assertEqual(#off.groups, 1, "off: R-3's single unfiltered group, since nothing is hidden")
    assertEqual(off.groups[1].filter, "HELPFUL", "off draws everything — no positive constraint")
    assertEqual(on.groups[1].filter, "HELPFUL|BIG_DEFENSIVE", "on draws only the shown category")
end)

test("filter: on, nothing shown and nothing whitelisted draws nothing, with its own warning (R-11)", function()
    local plan = compile({ filter = { onlyShown = true, categories = { bigDefensive = "hide" } } },
        { categories = only("HELPFUL", { "bigDefensive" }) })
    assertEqual(#plan.groups, 0)
    -- red under: the generic NEVER_MATCHES firing instead of the toggle's own, more specific warning
    assertTrue(hasWarning(plan, "no category is set to Show"))
    assertTrue(not hasWarning(plan, "These filters can never match anything."))
end)

test("filter: on, nothing shown but the whitelist still draws — no ONLY_SHOWN_NONE warning", function()
    local plan = compile({ filter = { onlyShown = true, whitelist = { [500] = true },
        categories = { bigDefensive = "hide" } } }, { categories = only("HELPFUL", { "bigDefensive" }) })
    assertEqual(#plan.groups, 1, "the whitelist group alone")
    assertEqual(plan.groups[1].label, "Always shown")
    assertTrue(not hasWarning(plan, "no category is set to Show"), "the whitelist is drawing something")
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

test("filter: the weaponEnchants row decides the enchant slots, and adds no group", function()
    -- red under: the enchant row being read as a category (an extra group) or ignored (no enchants)
    local on = compile({ unit = "player", filter = { categories = { weaponEnchants = "show" } } })
    assertEqual(#on.groups, 1)
    assertTrue(on.enchants ~= nil)

    local off = compile({ unit = "player", filter = { categories = { weaponEnchants = "hide" } } })
    assertEqual(#off.groups, 1)
    assertNil(off.enchants)
end)

test("filter: the enchant row does nothing on a debuff or a non-player container", function()
    -- red under: enchants leaking onto a container that is not the player's buffs
    assertNil(compile({ unit = "target", filter = { categories = { weaponEnchants = "show" } } }).enchants)
    assertNil(compile({ auraType = "HARMFUL", unit = "player",
        filter = { categories = { weaponEnchants = "show" } } }).enchants)
end)

test("filter: the enchant slots the container draws are exactly the profile's, in a fixed order", function()
    -- red under: enchantSlots ignored, so unticking a slot changes nothing
    local plan = FC.Compile(cfg({ unit = "player", filter = { categories = { weaponEnchants = "show" } } }),
        { enchantSlots = { mainHand = true, offHand = false, ranged = false } })
    assertEqual(#plan.enchants.slots, 1)
    assertEqual(plan.enchants.slots[1], "mainHand")

    local ordered = FC.Compile(cfg({ unit = "player", filter = { categories = { weaponEnchants = "show" } } }),
        { enchantSlots = { ranged = true, mainHand = true, offHand = true } })
    assertEqual(table.concat(ordered.enchants.slots, ","), "mainHand,offHand,ranged", "declared slot order")
end)

test("filter: an enchant container's slots also come from the profile, falling back to all three", function()
    local none = FC.Compile(cfg({ auraType = "ENCHANT" }),
        { enchantSlots = { mainHand = false, offHand = false, ranged = false } })
    assertEqual(#none.enchants.slots, 3, "every slot off falls back to all three")
    local some = FC.Compile(cfg({ auraType = "ENCHANT" }),
        { enchantSlots = { mainHand = true, offHand = false, ranged = false } })
    assertEqual(table.concat(some.enchants.slots, ","), "mainHand")
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
    -- Show is the default (a already carries enchants), so hiding is what changes the structure.
    local c = compile({ filter = { categories = { weaponEnchants = "hide" } } })
    assertTrue(FC.StructureKey(a) ~= FC.StructureKey(c))
    -- AddItemEnchantment takes hidePermanent only at creation, so flipping it needs a new engine.
    local hide = compile({ filter = { hidePermanentEnchants = true } })
    local keep = compile({ filter = { hidePermanentEnchants = false } })
    assertTrue(FC.StructureKey(hide) ~= FC.StructureKey(keep), "hide-permanent is structural")
end)

-- ── characterization: whole plans (testing-§13) ──────────────────────────────────────────────────
-- Each signature was captured from FC.Compile as one function, before it was split into helpers. A
-- change to the shipped categories or warnings moves these on purpose; recapture them then.

-- Only token, flag and dispel categories, narrowed with `only` so a signature does not carry a
-- whole shipped spell list — and, since the filter-priority revision, does not carry one group per
-- OTHER shipped category of the aura type either (R-4 fires the moment any category is Hidden).
local RICH = {
    { { unit = "player", auraType = "HELPFUL", filter = {
        castBy = "others", durationMode = "timeless", maxDuration = 30, maxAuras = 5,
        sortMethod = "bogus", sortDirection = "reverse",
        whitelist = { [100] = true, [200] = true }, blacklist = { [200] = true, [300] = true },
        categories = { bigDefensive = "show", castable = "show", important = "hide", stealable = "hide" },
    } }, { timedSpells = { [400] = true },
          categories = only("HELPFUL", { "bigDefensive", "castable", "important", "stealable" }) } },
    { { unit = "target", auraType = "HARMFUL", filter = {
        castBy = "mine", durationMode = "timeless", maxDuration = 12,
        categories = { magic = "show", boss = "show", crowdControl = "hide" },
    } }, { categories = only("HARMFUL", { "magic", "boss", "crowdControl" }) } },
    { { unit = "focus", auraType = "HELPFUL", filter = {
        durationMode = "timed", whitelist = { [500] = true }, categories = { bigDefensive = "show" },
    } }, { categories = only("HELPFUL", { "bigDefensive" }) } },
    { { unit = "target", auraType = "ENCHANT" } },
}

local RICH_SIGNATURES = {
    -- Filter priority (spec section 6): the whitelist group (rank 1), then one group per SHOWN
    -- category (bigDefensive, castable — rank 3), then the catch-all (rank 4/5) excluding both
    -- hidden categories (important, stealable) AND both shown ones, so nothing is drawn twice.
    "{enchants={hidePermanent=boolean:true,slots={1=string:mainHand,2=string:offHand,3=string:ranged}},"
    .. "groups={1={candidateFilters={includeSpellIDs={100=boolean:true,200=boolean:true}},filter=string:HELPFUL,"
    .. "key=string:g1,label=string:Always shown,maxFrameCount=number:5,sortDirection=string:reverse,"
    .. "sortMethod=string:default},"
    .. "2={candidateFilters={excludeSpellIDs={100=boolean:true,200=boolean:true,300=boolean:true,400=boolean:true}},"
    .. "filter=string:HELPFUL|!PLAYER|BIG_DEFENSIVE,key=string:g2,label=string:Big defensives (Blizzard),"
    .. "maxFrameCount=number:5,sortDirection=string:reverse,sortMethod=string:default},"
    .. "3={candidateFilters={excludeSpellIDs={100=boolean:true,200=boolean:true,300=boolean:true,400=boolean:true}},"
    .. "filter=string:HELPFUL|!PLAYER|RAID|!BIG_DEFENSIVE,key=string:g3,label=string:Castable by you,"
    .. "maxFrameCount=number:5,sortDirection=string:reverse,sortMethod=string:default},"
    .. "4={candidateFilters={excludeSpellIDs={100=boolean:true,200=boolean:true,300=boolean:true,400=boolean:true},"
    .. "isStealable=boolean:false},filter=string:HELPFUL|!PLAYER|!IMPORTANT|!BIG_DEFENSIVE|!RAID,key=string:g4,"
    .. "label=string:All,maxFrameCount=number:5,sortDirection=string:reverse,sortMethod=string:default}},"
    .. "warnings={1=string:Max duration is ignored while showing only auras without a duration.}}",

    -- magic and boss (rank 3, shown) each get their own group; crowdControl (rank 4, hidden) only
    -- narrows the catch-all, which also excludes magic and boss so they are not drawn twice.
    "{groups={1={candidateFilters={isBossAura=boolean:true,maxDuration=number:12},filter=string:HARMFUL|PLAYER,"
    .. "key=string:g1,label=string:Boss debuffs,maxFrameCount=number:inf,sortDirection=string:normal,"
    .. "sortMethod=string:expirationOnly},"
    .. "2={candidateFilters={includeDispelTypes={Magic=boolean:true},isBossAura=boolean:false,maxDuration=number:12},"
    .. "filter=string:HARMFUL|PLAYER,key=string:g2,label=string:Magic,maxFrameCount=number:inf,"
    .. "sortDirection=string:normal,sortMethod=string:expirationOnly},"
    .. "3={candidateFilters={excludeDispelTypes={Magic=boolean:true},isBossAura=boolean:false,maxDuration=number:12},"
    .. "filter=string:HARMFUL|PLAYER|!CROWD_CONTROL,key=string:g3,label=string:All,maxFrameCount=number:inf,"
    .. "sortDirection=string:normal,sortMethod=string:expirationOnly}},"
    .. "warnings={1=string:Only auras without a duration works for buffs only; this container shows every duration.}}",

    -- No category is Hidden here, so R-3 still applies: bigDefensive (show) buys its own group only
    -- when something else is hiding, and nothing is — one whitelist group, one catch-all.
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
    assertNil(compile({ auraType = "HARMFUL", unit = "player",
        filter = { categories = { weaponEnchants = "show" } } }).enchants)
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
    local plan = compile({ filter = { categories = { consumables = "hide" } } },
        { categorySpells = { consumables = removed }, categories = only("HELPFUL", { "consumables" }) })
    assertEqual(#plan.groups, 1)
    -- red under: excludeCategory adding an empty exclude map for a hidden category
    assertNil(plan.groups[1].candidateFilters)
end)

test("filter: a contradiction drops the catch-all without disturbing the whitelist group's key", function()
    -- fromNonPlayers and fromPlayers hide the same field to opposite values: hiding both is
    -- self-contradictory, so the catch-all (the only category group here — narrowed to just these
    -- two, neither is Shown) is dropped. The live engine addresses its groups by these keys, so the
    -- whitelist group ahead of the drop must keep key "g1" rather than being renumbered.
    local plan = compile({ auraType = "HARMFUL", filter = {
        whitelist = { [500] = true },
        categories = { fromPlayers = "hide", fromNonPlayers = "hide" },
    } }, { categories = only("HARMFUL", { "fromPlayers", "fromNonPlayers" }) })
    assertEqual(#plan.groups, 1, "the contradictory catch-all is dropped")
    assertEqual(plan.groups[1].key, "g1")
    assertEqual(plan.groups[1].label, "Always shown")
end)

-- red under: setFlag regaining its old "soft" forgiveness for a Hide negation, which would let one
-- of the two contradictory hides silently win (and a group survive) instead of the container being
-- reported as unmatchable.
test("filter: hiding two categories that contradict on the same flag leaves nothing, and says so", function()
    -- fromPlayers and fromNonPlayers share isFromPlayerOrPlayerPet at opposite values; hiding both,
    -- with no whitelist and neither Shown, is a genuine contradiction that drops the container's only
    -- (catch-all) group — the one case that still exercises finishWarnings' zero-group NEVER_MATCHES.
    local plan = compile({ auraType = "HARMFUL", filter = {
        categories = { fromPlayers = "hide", fromNonPlayers = "hide" },
    } }, { categories = only("HARMFUL", { "fromPlayers", "fromNonPlayers" }) })
    assertEqual(#plan.groups, 0, "isFromPlayerOrPlayerPet can't be both true and false")
    assertTrue(hasWarning(plan, "can never match"))
end)
