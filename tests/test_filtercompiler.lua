-- tests/test_filtercompiler.lua — modules/FilterCompiler.lua: settings in, aura-engine groups out.
--
-- The compiler is PURE (no frames, no database), which is what makes the filtering rules testable
-- at all: an aura cannot be read headlessly, but the declaration handed to the engine can. Every
-- case builds a container from the shipped template and asserts the plan. The user-category cases
-- live in tests/test_filtercompiler_categories.lua (issue #18).

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

local H = dofile("tests/filtercompiler_helpers.lua")
local setOf, hasWarning = H.setOf, H.hasWarning

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

--- `only`, with one extra category def spliced in immediately BEFORE the aura type's `uncategorized`
--- row — U-1 keeps that row last and `addShownGroups` leans on it, so an injected def that landed
--- after it would be testing a shape the addon never ships. The debuff cases below use it to narrow
--- `Cat.HARMFUL` to one Blizzard token, the real `hardCC` and `uncategorizedDebuffs`, which is the
--- smallest list that gives a debuff container a NON-EMPTY categorized union. The gate itself is
--- `FC.IdsAlwaysHonored` (`addCategoryGroups`, modules/FilterCompiler.lua), NOT the `FC.IdsHonored`
--- the warning reads, and it answers false for every debuff container whatever the union holds — so
--- a non-empty debuff union is not what makes the gate decide, it is what makes the decision
--- OBSERVABLE: with an empty union `hasUnion` would be false anyway and a case could not tell which
--- half shut the row down. It goes in through the same `ctx.categories` seam every other case uses
--- rather than patching `NS.Categories`: the shipped table stays untouched, so no case here can leak into
--- the next one, and the fixture keeps asserting the compiler rather than a monkey-patch.
local function onlyPlus(auraType, keys, extra)
    local out = {}
    for _, def in ipairs(only(auraType, keys).For()) do
        if extra and def.kind == "uncategorized" then
            out[#out + 1] = extra
            extra = nil
        end
        out[#out + 1] = def
    end
    if extra then
        local n = #out
        out[n + 1] = extra
    end
    return { For = function() return out end }
end

--- The SHIPPED `hardCC` — the first `spells`-kind category `Cat.HARMFUL` carries (issue #11 part A1,
--- defaults/Categories.lua). While A2 was written ahead of A1 this was a two-id stand-in; now that
--- the category exists the cases below pin the gate against the data a player actually gets, so a
--- curation pass that emptied the list or changed its kind takes these cases red rather than leaving
--- them green against a fixture nothing ships.
local HARMFUL_SPELLS_DEF = NS.Categories.Find("HARMFUL", "hardCC")

--- Every id `HARMFUL_SPELLS_DEF` claims, in exactly the form `setOf` renders a candidate filter's id
--- set — so a case can assert the WHOLE union rather than a count, which a wrong list of the right
--- length would satisfy. Built by `setOf` itself rather than by a second sort of its own: the shape
--- under assertion is "these ids and no others", and two independent orderings of the same ids
--- (`setOf` sorts them as strings) would make a case fail over a comma.
local HARD_CC_IDS = setOf(HARMFUL_SPELLS_DEF.spells)

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

test("filter: showing a spell category with every id removed, and nothing hidden, still contributes nothing (R-3)", function()
    -- R-3: with nothing Hidden, `includeCategory` never even runs — the container stays at its one,
    -- unfiltered group whatever a Show category's own spell edits say.
    local def = NS.Categories.Find("HELPFUL", "racials")
    local removed = {}
    for id in pairs(def.spells) do removed[id] = false end
    local plan = compile({ filter = { categories = { racials = "show" } } },
        { categorySpells = { racials = removed }, categories = only("HELPFUL", { "racials" }) })
    assertEqual(#plan.groups, 1)
    assertNil(plan.groups[1].candidateFilters)
    assertEqual(#plan.warnings, 0)
end)

test("filter: a shown spell category with every id removed can never match, and is dropped as a conflict (R-6)", function()
    -- Unlike the R-3 case above, a Hide elsewhere forces the per-shown-category path to actually run
    -- `includeCategory` for "racials". red under: `includeCategory`'s spells branch writing an
    -- EMPTY `includeSpellIDs` instead of `con.conflict = true` — an empty includeSpellIDs is what the
    -- engine would honor, drawing nothing where dropping the group draws through the catch-all instead.
    local def = NS.Categories.Find("HELPFUL", "racials")
    local removed = {}
    for id in pairs(def.spells) do removed[id] = false end
    local plan = compile({ filter = { categories = { racials = "show", defensives = "hide" } } },
        { categorySpells = { racials = removed },
          categories = only("HELPFUL", { "racials", "defensives" }) })
    local labels = {}
    for _, g in ipairs(plan.groups) do labels[g.label] = true end
    assertNil(labels["Racials"], "the empty shown category's own group is dropped, not emitted empty")
    assertTrue(labels["All"], "the catch-all still stands, excluding defensives")
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

-- ── "only these categories" (D8, R-8..R-11) — RETIRED, fix round 2 ──────────────────────────────
--
-- The owner removed the toggle entirely: `Uncategorized = Hide` (buffs) now means exactly what it
-- used to mean, and fix round 1 already proved the two are the same shape once the catch-all is
-- correctly dropped in both of Uncategorized's states, leaving the toggle nothing left to do. The
-- migration that replaces a stored `onlyShown = true` with `categories.uncategorized = "hide"` lives
-- in core/Database.lua (tests/test_database.lua's schema step 4); this file only needs to prove the
-- compiler never reads the dead key at all any more — belt-and-braces, in case one somehow survives
-- migration (a restored backup, a profile copy from before this version).

test("filter: a stray filter.onlyShown key, however it got there, is inert — the compiler never reads it (D8 retired)", function()
    local withKey = compile({ filter = { onlyShown = true, categories = { bigDefensive = "hide" } } },
        { categories = only("HELPFUL", { "bigDefensive" }) })
    local withoutKey = compile({ filter = { categories = { bigDefensive = "hide" } } },
        { categories = only("HELPFUL", { "bigDefensive" }) })
    assertEqual(FC.Signature(withKey), FC.Signature(withoutKey))
end)

-- ── uncategorized (U-1..U-5, fix round 1, docs/superpowers/specs/2026-09-15-feedback-batch7-design.md
-- §4, buffs only as of fix round 1 — see defaults/Categories.lua's KINDS doc) ────────────────────
--
-- The fixture always narrows `ctx.categories` to `cancelable` (the owner's own Blizzard token
-- category), `defensives` (the one spells-kind category standing in for "the lists"), and
-- `uncategorized`, via `only`. "Listed" below means an id in `defensives`' starter set; "unlisted"
-- means any id outside it — the owner's actual buffs, cancelable but on no list.

test("filter: Uncategorized Show draws an unlisted aura even when a Blizzard token category is Hidden — the owner's exact case", function()
    local plan = compile({ filter = { categories = { cancelable = "hide" } } },
        { categories = only("HELPFUL", { "cancelable", "defensives", "uncategorized" }) })
    -- fix round 1: the catch-all is SUPERSEDED, not joined — its constraints were a strict subset of
    -- Uncategorized's own group's, so shipping both would draw a rank-5 aura twice. Exactly two
    -- groups here: Defensives, Uncategorized. No "All".
    assertEqual(#plan.groups, 2)
    local uncat
    for _, g in ipairs(plan.groups) do
        assertTrue(g.label ~= "All", "the catch-all is never emitted once Uncategorized exists")
        if g.label == "Uncategorized" then uncat = g end
    end
    assertTrue(uncat ~= nil, "Show compiles to its own group")
    -- U-3: no `!CANCELABLE` here — a Show carries NO hidden-category exclusion, which is exactly what
    -- lets an unlisted-but-cancelable buff through this group despite `cancelable` being Hidden.
    assertEqual(uncat.filter, "HELPFUL", "no hidden-category exclusion — the whole point")
    -- The complement: excludeSpellIDs of the union of every spells-kind category (just `defensives`
    -- here), so a listed id is excluded and everything else — the unlisted, cancelable buffs — passes.
    local defIds = setOf(FC.CategorySpells(NS.Categories.Find("HELPFUL", "defensives")))
    assertEqual(setOf(uncat.candidateFilters.excludeSpellIDs), defIds)
end)

test("filter: no two groups can match the same aura when Uncategorized is Show — the catch-all would have (fix round 1)", function()
    -- Concretely, not just by construction: Defensives requires the id to be IN the defensives set
    -- (includeSpellIDs); Uncategorized requires it to be OUT of that exact set (excludeSpellIDs) —
    -- complementary constraints on the SAME set, so no spell id can ever satisfy both at once.
    local plan = compile({ filter = { categories = { cancelable = "hide" } } },
        { categories = only("HELPFUL", { "cancelable", "defensives", "uncategorized" }) })
    assertEqual(#plan.groups, 2)
    local def, uncat
    for _, g in ipairs(plan.groups) do
        if g.label == "Defensive cooldowns" then def = g end
        if g.label == "Uncategorized" then uncat = g end
    end
    assertTrue(def ~= nil and uncat ~= nil)
    assertTrue(def.candidateFilters.includeSpellIDs ~= nil, "Defensives: an id must be IN this set")
    assertTrue(uncat.candidateFilters.excludeSpellIDs ~= nil, "Uncategorized: an id must be OUT of it")
    assertEqual(setOf(def.candidateFilters.includeSpellIDs), setOf(uncat.candidateFilters.excludeSpellIDs),
        "the very same set, included by one group and excluded by the other — no overlap is possible")
end)

test("filter: Uncategorized Hide drops the catch-all entirely rather than shipping a group that can never match (fix round 1)", function()
    local plan = compile({ filter = { categories = { cancelable = "hide", uncategorized = "hide" } } },
        { categories = only("HELPFUL", { "cancelable", "defensives", "uncategorized" }) })
    -- U-5's original shape (an include on a surviving catch-all) was a provable no-op: the catch-all
    -- already excludes every spells-kind category's ids, so restricting it to that same union could
    -- never match anything. Fix round 1: no catch-all at all, in either state.
    assertEqual(#plan.groups, 1, "only Defensives — no group of Uncategorized's own, no catch-all")
    assertEqual(plan.groups[1].label, "Defensive cooldowns")
end)

test("filter: a listed aura's own category group is unaffected by Uncategorized either way", function()
    local shownPlan = compile({ filter = { categories = { cancelable = "hide" } } },
        { categories = only("HELPFUL", { "cancelable", "defensives", "uncategorized" }) })
    local hiddenPlan = compile({ filter = { categories = { cancelable = "hide", uncategorized = "hide" } } },
        { categories = only("HELPFUL", { "cancelable", "defensives", "uncategorized" }) })
    local function defensivesGroup(plan)
        for _, g in ipairs(plan.groups) do
            if g.label == "Defensive cooldowns" then return g end
        end
        return nil
    end
    local shownDef, hiddenDef = defensivesGroup(shownPlan), defensivesGroup(hiddenPlan)
    assertTrue(shownDef ~= nil and hiddenDef ~= nil)
    assertEqual(FC.Signature(shownDef), FC.Signature(hiddenDef), "Uncategorized never touches a listed category's own group")
end)

-- ── uncategorized: the debuff row's asymmetry (fix round 3, restored) ────────────────────────────
--
-- The fixture narrows `ctx.categories` to JUST `crowdControl` and `uncategorizedDebuffs`, isolating
-- the row from the real shipped list's `fromPlayers`/`fromNonPlayers` contradiction — that pair
-- already drops the catch-all for its own, unrelated reason (the "real shipped category list" test
-- above), which would otherwise mask a real bug here. Every case in THIS block runs on the default
-- `player` unit and on a `Cat.HARMFUL` narrowed to categories with no spell list, so `hasUnion` is
-- false for both of its reasons at once — the union is empty AND the engine discards debuff ids on
-- the player. The block below ("once a spells-kind debuff category exists") is what separates the
-- two, which is the distinction issue #11 makes load-bearing.

test("filter: Uncategorized Show on a debuff container contributes no group and does not neuter another category's Hide", function()
    -- red under: an unrestricted debuff-side Show group (fix round 1's original mistake) that would
    -- draw every debuff regardless of crowdControl's Hide — the owner's complaint, reborn on debuffs.
    local plan = compile({ auraType = "HARMFUL", filter = { categories = { crowdControl = "hide" } } },
        { categories = only("HARMFUL", { "crowdControl", "uncategorizedDebuffs" }) })
    assertEqual(#plan.groups, 1, "only the ordinary catch-all — Uncategorized contributes nothing")
    assertEqual(plan.groups[1].label, "All")
    assertEqual(plan.groups[1].filter, "HARMFUL|!CROWD_CONTROL",
        "the catch-all still excludes crowdControl, exactly as if Uncategorized did not exist")
end)

test("filter: Uncategorized Hide on a debuff container reproduces the retired 'Only these categories' toggle exactly", function()
    local plan = compile({ auraType = "HARMFUL",
        filter = { categories = { crowdControl = "show", uncategorizedDebuffs = "hide" } } },
        { categories = only("HARMFUL", { "crowdControl", "uncategorizedDebuffs" }) })
    assertEqual(#plan.groups, 1, "only the explicitly shown category — no catch-all")
    assertEqual(plan.groups[1].label, "Crowd control")
    assertEqual(plan.groups[1].filter, "HARMFUL|CROWD_CONTROL")
end)

test("filter: Uncategorized Show on a debuff container with nothing else hidden changes nothing (R-3 still applies)", function()
    local plan = compile({ auraType = "HARMFUL", filter = {} },
        { categories = only("HARMFUL", { "crowdControl", "uncategorizedDebuffs" }) })
    assertEqual(#plan.groups, 1)
    assertEqual(plan.groups[1].label, "All")
    assertNil(plan.groups[1].candidateFilters)
end)

-- ── uncategorized on debuffs, once a spells-kind debuff category exists (issue #11 part A) ───────
--
-- Everything above this point compiles `Cat.HARMFUL` as it ships TODAY, where no `spells`-kind
-- category exists and the union is therefore empty for every debuff container. Issue #11 adds
-- `hardCC`/`softCC` and that stops being true, which is precisely the hazard: the union alone was
-- never the right question. Nor is "can the engine honor ids here at all" — that one is right for
-- the SENTENCE a container prints and wrong for the GATE, because a `target` answers it yes while
-- being free to turn friendly a second after the plan compiles. The gate asks the strict question,
-- `FC.IdsAlwaysHonored`: are the ids this group is made of CERTAIN to be applied? The owner's
-- ruling (2026-09-20) splits the one predicate into those two, and the cases below pin both truth
-- tables plus the four container shapes where they decide something.

test("filter: FC.IdsHonored is the CAN-EVER predicate — true wherever a spell list could ever bite", function()
    -- Blizzard's AuraContainerUtil.CanApplyIdentityCandidateFilters: buffs on friendly units and
    -- debuffs on hostile ones. `target` and `focus` are TRUE for BOTH aura types, because each unit
    -- can be either kind of unit — a target buff list bites on a friendly target, a target debuff
    -- list on a hostile one. Only the player and the pet are pinned, and only on debuffs, which is
    -- why exactly two cells here are false. This predicate exists for `identityWarning`: it decides
    -- whether a setting is DEAD (worth saying so) rather than whether a compiled group is SAFE.
    assertTrue(FC.IdsHonored("player", "HELPFUL"), "your own buffs: ids honored")
    assertTrue(FC.IdsHonored("pet", "HELPFUL"), "your pet's buffs: ids honored")
    assertTrue(FC.IdsHonored("target", "HELPFUL"), "a target CAN be friendly: buff ids can bite")
    assertTrue(FC.IdsHonored("focus", "HELPFUL"), "a focus CAN be friendly: same")
    assertTrue(not FC.IdsHonored("player", "HARMFUL"), "your own debuffs: ids discarded outright")
    assertTrue(not FC.IdsHonored("pet", "HARMFUL"), "your pet's debuffs: ids discarded outright")
    assertTrue(FC.IdsHonored("target", "HARMFUL"), "a target CAN be hostile: debuff ids can bite")
    assertTrue(FC.IdsHonored("focus", "HARMFUL"), "a focus CAN be hostile: same")
end)

test("filter: FC.IdsAlwaysHonored is the CERTAIN predicate — true only for buffs on the player and pet", function()
    -- The gate `addCategoryGroups` and `explainUncategorized`'s caller both read. Every target/focus
    -- cell is false however common the friendly-target or hostile-target case is in play: hostility
    -- is dynamic and the plan is compiled long before anyone looks at the unit, so "usually honored"
    -- is not a thing a group whose ONLY constraint is a spell-id filter can be built on. HARMFUL on
    -- player/pet is false for the blunter reason that ids are never applied there at all.
    assertTrue(FC.IdsAlwaysHonored("player", "HELPFUL"), "your own buffs: nothing can make you hostile")
    assertTrue(FC.IdsAlwaysHonored("pet", "HELPFUL"), "your pet's buffs: same")
    assertTrue(not FC.IdsAlwaysHonored("target", "HELPFUL"), "a target may be hostile: only conditional")
    assertTrue(not FC.IdsAlwaysHonored("focus", "HELPFUL"), "a focus may be hostile: only conditional")
    assertTrue(not FC.IdsAlwaysHonored("player", "HARMFUL"), "your own debuffs: never honored")
    assertTrue(not FC.IdsAlwaysHonored("pet", "HARMFUL"), "your pet's debuffs: never honored")
    assertTrue(not FC.IdsAlwaysHonored("target", "HARMFUL"), "a target may be FRIENDLY: only conditional")
    assertTrue(not FC.IdsAlwaysHonored("focus", "HARMFUL"), "a focus may be FRIENDLY: only conditional")
    -- The two predicates differ in exactly the four target/focus cells and never the other way
    -- round: CERTAIN implies CAN-EVER. ONE predicate answering both questions is what produced the
    -- contradiction the ruling ends — target/HARMFUL counted as honored (a group the engine discards
    -- the moment the target is friendly) and target/HELPFUL as not honored, the same conditionality
    -- treated two opposite ways in one function.
    for _, unit in ipairs({ "player", "pet", "target", "focus" }) do
        for _, auraType in ipairs({ "HELPFUL", "HARMFUL" }) do
            local label = auraType .. " on " .. unit
            if FC.IdsAlwaysHonored(unit, auraType) then
                assertTrue(FC.IdsHonored(unit, auraType), label .. ": certain must imply can-ever")
            end
        end
    end
end)

test("filter: a PLAYER debuff container with a non-empty union still gives Uncategorized Show no group — fix round 3's failure through issue #11's new door", function()
    -- red under `hasUnion = not isEmpty(cats.union or {})`: with a spells-kind debuff category in the
    -- list the union is non-empty, so the Show row would contribute a group whose ONLY constraint is
    -- `excludeSpellIDs` of that union — and the engine DISCARDS spell-id filters for debuffs on the
    -- player. What the engine would actually receive is a group with no effective constraint at all:
    -- every debuff drawn, Hard CC's Hide neutered along with every other Hide on the tab. That
    -- is the exact failure fix round 3 (2026-09-16) diagnosed and closed, re-entering through a door
    -- the union test cannot see. `FC.IdsAlwaysHonored` is what shuts it.
    local plan = compile({ auraType = "HARMFUL", unit = "player",
        filter = { categories = { crowdControl = "hide" } } },
        { categories = onlyPlus("HARMFUL", { "crowdControl", "uncategorizedDebuffs" }, HARMFUL_SPELLS_DEF) })
    for _, g in ipairs(plan.groups) do
        assertTrue(not (g.filter == "HARMFUL" and g.candidateFilters == nil),
            "an unconstrained HARMFUL group would draw every debuff and neuter every Hide on the tab")
        assertTrue(g.label ~= "Uncategorized",
            "the Show row contributes nothing where its one constraint is ignored")
    end
    -- What remains is exactly what compiles today with no spells-kind debuff category at all: the
    -- shown spell category's own group, then the ordinary catch-all, still carrying the Hidden token
    -- category's negation. The catch-all's `excludeSpellIDs` is left in place deliberately — an
    -- exclude the engine ignores costs nothing, and suppressing it would change no outcome.
    assertEqual(#plan.groups, 2)
    assertEqual(plan.groups[1].label, "Hard CC (loss of control)")
    assertEqual(setOf(plan.groups[1].candidateFilters.includeSpellIDs), HARD_CC_IDS)
    assertEqual(plan.groups[2].label, "All")
    assertEqual(plan.groups[2].filter, "HARMFUL|!CROWD_CONTROL")
    assertEqual(setOf(plan.groups[2].candidateFilters.excludeSpellIDs), HARD_CC_IDS)
end)

test("filter: a TARGET debuff container gives Uncategorized Show no group either — a target may be FRIENDLY", function()
    -- Defect (a), and the case the owner's ruling turns on. The mirror of the player case above is
    -- NOT "the target is hostile, so the ids are real": a target's hostility is dynamic and this plan
    -- is compiled once, long before anyone looks at the unit. Target a friendly player and the engine
    -- discards this group's `excludeSpellIDs` on the spot, leaving a group whose only remaining
    -- constraint is the HARMFUL token — every debuff drawn, Hard CC's Hide and every other Hide
    -- on the tab neutered. Compiling a group that is correct only while the unit points one way is
    -- what `FC.IdsAlwaysHonored` refuses; `FC.IdsHonored` (true here) is for the warning, not this.
    local plan = compile({ auraType = "HARMFUL", unit = "target",
        filter = { categories = { crowdControl = "hide" } } },
        { categories = onlyPlus("HARMFUL", { "crowdControl", "uncategorizedDebuffs" }, HARMFUL_SPELLS_DEF) })
    for _, g in ipairs(plan.groups) do
        assertTrue(not (g.filter == "HARMFUL" and g.candidateFilters == nil),
            "a group with nothing but the aura-type token draws every debuff on a friendly target")
        assertTrue(g.label ~= "Uncategorized",
            "the Show row contributes nothing where the engine is free to discard its one constraint")
    end
    -- Same two groups as the player case: the shown spell category, then the catch-all the Show row
    -- no longer supersedes — which is exactly "as if the row were not there", the behavior fix round
    -- 3 defined for this side of the gate.
    assertEqual(#plan.groups, 2)
    assertEqual(plan.groups[1].label, "Hard CC (loss of control)")
    assertEqual(setOf(plan.groups[1].candidateFilters.includeSpellIDs), HARD_CC_IDS)
    assertEqual(plan.groups[2].label, "All")
    assertEqual(plan.groups[2].filter, "HARMFUL|!CROWD_CONTROL")
    assertEqual(setOf(plan.groups[2].candidateFilters.excludeSpellIDs), HARD_CC_IDS)
end)

test("filter: a FRIENDLY-target buff container loses the Uncategorized Show rescue — the accepted cost, pinned", function()
    -- THE ACCEPTED COST (issue #11, owner's ruling 2026-09-20), asserted rather than described, so it
    -- cannot drift back in unnoticed or be "fixed" by someone who reads it as a bug. On the player
    -- this same fixture rescues an unlisted-but-cancelable buff from a Hidden `Cancelable` — it is
    -- byte for byte the fixture of "the owner's exact case" above, with the unit moved off the
    -- player, so the two cases differ in nothing else. On a target it no longer rescues, because
    -- the same group that rescues on a friendly target degenerates into "every buff" on a hostile
    -- one, and the compiler cannot tell which it will be. Losing a niche rescue beats defeating
    -- every Hide on the tab.
    --
    -- This ALSO closes a latent bug predating issue #11: at HEAD, where the gate was the union alone,
    -- a HOSTILE target buff container with this exact shape — Uncategorized Shown, one other category
    -- Hidden so the R-4 branch is the one that runs — emitted the degenerate group, and
    -- `Cat.HELPFUL` has shipped nine spells-kind categories all along, so nothing had to be added to
    -- reach it.
    local plan = compile({ auraType = "HELPFUL", unit = "target",
        filter = { categories = { cancelable = "hide" } } },
        { categories = only("HELPFUL", { "cancelable", "defensives", "uncategorized" }) })
    for _, g in ipairs(plan.groups) do
        assertTrue(not (g.filter == "HELPFUL" and g.candidateFilters == nil),
            "an unconstrained HELPFUL group would draw every buff on a hostile target")
        assertTrue(g.label ~= "Uncategorized", "the rescue group is not compiled on a target")
    end
    -- The catch-all survives instead, and it DOES carry `!CANCELABLE` — which is the cost, stated as
    -- a plan: an unlisted cancelable buff is drawn by no group here, where on the player the rescue
    -- group would have drawn it.
    assertEqual(#plan.groups, 2)
    assertEqual(plan.groups[1].label, "Defensive cooldowns")
    assertEqual(plan.groups[2].label, "All")
    assertEqual(plan.groups[2].filter, "HELPFUL|!CANCELABLE")
end)

test("filter: a target debuff container still warns 'while the unit is hostile' although the gate dropped its Show group", function()
    -- The two predicates are split, and this is where the split is visible in one compile: the GATE
    -- (`IdsAlwaysHonored`, false here) contributed no Uncategorized group, while the WARNING
    -- (`IdsHonored`, true here) still prints the conditional sentence, because the container's OTHER
    -- spell-id constraints — Hard CC's own `includeSpellIDs` — are real and do bite while the
    -- target is hostile. Telling the player "spell lists do nothing here" would be a lie; dropping
    -- the warning to match the gate would be the drift the rewrite exists to prevent.
    local hostile = compile({ auraType = "HARMFUL", unit = "target",
        filter = { categories = { crowdControl = "hide" } } },
        { categories = onlyPlus("HARMFUL", { "crowdControl", "uncategorizedDebuffs" }, HARMFUL_SPELLS_DEF) })
    assertTrue(hasWarning(hostile, "hostile"), "ids are honored here, but only while the unit is hostile")
    for _, g in ipairs(hostile.groups) do
        assertTrue(g.label ~= "Uncategorized", "the gate is stricter than the warning, deliberately")
    end
    local own = compile({ auraType = "HARMFUL", unit = "player",
        filter = { categories = { crowdControl = "hide" } } },
        { categories = onlyPlus("HARMFUL", { "crowdControl", "uncategorizedDebuffs" }, HARMFUL_SPELLS_DEF) })
    assertTrue(hasWarning(own, "own character or pet"), "ids are discarded here, and the plan says so")
end)

test("filter: a TARGET debuff container's spells-kind Show still emits its group, and warns — the accepted residual, pinned", function()
    -- THE ACCEPTED RESIDUAL (issue #11, owner's ruling 2026-09-20), asserted so the behavior is
    -- fixed by a test rather than left to drift, and so nobody "fixes" it by extending the gate
    -- above to `spells`-kind Shows. This group's only constraint beyond the HARMFUL token is an
    -- `includeSpellIDs` of the category's list (`includeCategory`, the `spells` branch), and on a
    -- target the engine MAY discard exactly that — target a FRIENDLY unit and this group draws every
    -- debuff, structurally the same degenerate shape `FC.IdsAlwaysHonored` now forbids the
    -- Uncategorized row. It ships anyway: suppressing it would delete the feature's primary use case,
    -- since Hard CC exists to answer "is my sheep on the target" and that target is hostile, which is
    -- exactly where the ids DO bite. A filter that refuses to work in the case it was built for is
    -- worse than one that is over-broad in a case nobody sets up. It also differs in KIND from the
    -- Uncategorized case: that row SUPERSEDES the catch-all, so its degeneration takes the tab's only
    -- Hide-carrying group with it, while this one sits BESIDE the others and removes nothing — the
    -- catch-all below still carries `!CROWD_CONTROL`.
    local plan = compile({ auraType = "HARMFUL", unit = "target",
        filter = { categories = { crowdControl = "hide" } } },
        { categories = onlyPlus("HARMFUL", { "crowdControl", "uncategorizedDebuffs" }, HARMFUL_SPELLS_DEF) })
    assertEqual(#plan.groups, 2)
    assertEqual(plan.groups[1].label, "Hard CC (loss of control)", "the Show group is emitted, not suppressed")
    assertEqual(plan.groups[1].filter, "HARMFUL", "nothing but the aura-type token in the string")
    assertEqual(setOf(plan.groups[1].candidateFilters), "includeSpellIDs",
        "the id list is its ONLY constraint — which is the residual, stated as a plan")
    assertEqual(setOf(plan.groups[1].candidateFilters.includeSpellIDs), HARD_CC_IDS)
    assertEqual(plan.groups[2].label, "All")
    assertEqual(plan.groups[2].filter, "HARMFUL|!CROWD_CONTROL",
        "an over-broad Show sits beside the others and removes nothing — the Hide still compiles")
    -- And the player is told, per container, rather than left to discover it: `addShownGroups` sets
    -- `usesSpellIds` for a `spells`-kind Show, so `finishWarnings` prints `IDS_HOSTILE_ONLY` off that
    -- flag. The residual is accepted BECAUSE it is a documented, warned-about engine limitation
    -- (docs/scope.md, "Out of reach on this client" -> "Spell-id filtering everywhere"); if this
    -- assertion ever goes red the acceptance loses its footing, because the limitation would then be
    -- silent.
    assertEqual(#plan.warnings, 1, "exactly the one sentence")
    assertEqual(plan.warnings[1], FC.WARN.IDS_HOSTILE_ONLY,
        "the spells-kind Show alone must raise the warning, with no blacklist or whitelist in play")
end)

-- ── uncategorized: ExplainSpell (fix round 1) ─────────────────────────────────────────────────

test("explain: an unlisted id is rank 3 (shown) when Uncategorized is Show — not the old rank 5", function()
    local r = FC.ExplainSpell(cfg({ filter = { categories = { cancelable = "hide" } } }), 999999,
        { categories = only("HELPFUL", { "cancelable", "defensives", "uncategorized" }) })
    assertEqual(r.verdict, "shown")
    assertEqual(r.rank, 3)
    assertEqual(#r.categories, 1)
    assertEqual(r.categories[1].key, "uncategorized")
    assertEqual(r.categories[1].state, "show")
end)

test("explain: an unlisted id is rank 4 (hidden) when Uncategorized is Hide", function()
    local r = FC.ExplainSpell(cfg({ filter = { categories = { cancelable = "hide", uncategorized = "hide" } } }), 999999,
        { categories = only("HELPFUL", { "cancelable", "defensives", "uncategorized" }) })
    assertEqual(r.verdict, "hidden")
    assertEqual(r.rank, 4)
    assertEqual(r.categories[1].state, "hide")
end)

test("explain: with no Uncategorized category for the aura type at all, an unclaimed id is still rank 5", function()
    -- The `only` stub deliberately excludes `uncategorizedDebuffs` here, to cover the general
    -- fallback path for an aura type that carries no such category at all — real HARMFUL has one as
    -- of fix round 3, covered by its own `explain: HARMFUL, Uncategorized Show...` cases below.
    local r = FC.ExplainSpell(cfg({ auraType = "HARMFUL", filter = {} }), 999999,
        { categories = only("HARMFUL", { "crowdControl" }) })
    assertEqual(r.verdict, "shown")
    assertEqual(r.rank, 5)
    assertEqual(#r.categories, 0)
end)

test("explain: HARMFUL, Uncategorized Show (default): an unclaimed id is rank 5, not rank 3 — hasUnion is false, nothing to rescue", function()
    -- red under: explainUncategorized reporting rank 3 for a Show row that contributes no group
    -- (fix round 3) — ExplainSpell must never claim a rescue the compiler does not actually perform.
    local r = FC.ExplainSpell(cfg({ auraType = "HARMFUL", filter = {} }), 999999,
        { categories = only("HARMFUL", { "crowdControl", "uncategorizedDebuffs" }) })
    assertEqual(r.verdict, "shown")
    assertEqual(r.rank, 5)
    assertEqual(#r.categories, 0, "no category is named — Uncategorized decided nothing here")
end)

test("explain: HARMFUL, Uncategorized Hide: an unclaimed id is rank 4, naming Uncategorized", function()
    local r = FC.ExplainSpell(cfg({ auraType = "HARMFUL", filter = { categories = { uncategorizedDebuffs = "hide" } } }), 999999,
        { categories = only("HARMFUL", { "crowdControl", "uncategorizedDebuffs" }) })
    assertEqual(r.verdict, "hidden")
    assertEqual(r.rank, 4)
    assertEqual(r.categories[1].key, "uncategorizedDebuffs")
    assertEqual(r.categories[1].state, "hide")
end)

test("explain: HARMFUL with a non-empty union on the PLAYER: an unclaimed id is still rank 5, never a rescue the compiler does not compile", function()
    -- `explainUncategorized` mirrors `addCategoryGroups` by contract (its own comment says so), so it
    -- gates on the same `FC.IdsAlwaysHonored`. Without it, issue #11's categories would make
    -- ExplainSpell report "shown, rescued by Uncategorized" for a container whose plan carries no
    -- such group at all — the Filters page confidently explaining a group never emitted.
    local r = FC.ExplainSpell(cfg({ auraType = "HARMFUL", unit = "player", filter = {} }), 999999,
        { categories = onlyPlus("HARMFUL", { "crowdControl", "uncategorizedDebuffs" }, HARMFUL_SPELLS_DEF) })
    assertEqual(r.verdict, "shown")
    assertEqual(r.rank, 5)
    assertEqual(#r.categories, 0, "no category is named — Uncategorized decided nothing here")
end)

test("explain: HARMFUL with a non-empty union on a TARGET: still rank 5, in lockstep with the gate", function()
    -- The lockstep requirement stated as a test: `explainUncategorized`'s caller reads the same
    -- `FC.IdsAlwaysHonored` the compiler gates on, so on a target it must report the same "the row
    -- decided nothing" the plan above actually compiles. Reading the looser `FC.IdsHonored` here
    -- would make the Filters page announce a rescuing group that the plan does not contain — the
    -- failure mode of two call sites answering one question with two predicates.
    local r = FC.ExplainSpell(cfg({ auraType = "HARMFUL", unit = "target", filter = {} }), 999999,
        { categories = onlyPlus("HARMFUL", { "crowdControl", "uncategorizedDebuffs" }, HARMFUL_SPELLS_DEF) })
    assertEqual(r.verdict, "shown")
    assertEqual(r.rank, 5)
    assertEqual(#r.categories, 0, "no group rescues it on a target, so no category is named")
end)

test("explain: HELPFUL on a TARGET: the rescue the accepted cost gives up is not claimed here either", function()
    -- The buff-side half of the same lockstep, and the explain-path pin on the accepted cost: on the
    -- player this id is rank 3, rescued by Uncategorized (the case above); on a target the compiler
    -- emits no such group, so the explanation must not name one.
    local r = FC.ExplainSpell(cfg({ auraType = "HELPFUL", unit = "target",
        filter = { categories = { cancelable = "hide" } } }), 999999,
        { categories = only("HELPFUL", { "cancelable", "defensives", "uncategorized" }) })
    assertEqual(r.verdict, "shown")
    assertEqual(r.rank, 5)
    assertEqual(#r.categories, 0)
end)

test("filter: every unit/aura-type combination prints exactly the identity warning it printed before the predicate split", function()
    -- The split touched `identityWarning`'s shape, so this is the parity net around it: the full
    -- 4x2 table, written out rather than derived from the predicates, so a future edit to either
    -- predicate cannot quietly redefine what the Filters page says. These eight answers are the ones
    -- the pre-#11 compiler gave (git HEAD's `identityWarning`: HARMFUL on player/pet -> own debuffs,
    -- HARMFUL otherwise -> hostile only, HELPFUL on target/focus -> friendly only, else silence).
    local expected = {
        { "player", "HELPFUL", nil },
        { "pet",    "HELPFUL", nil },
        { "target", "HELPFUL", FC.WARN.IDS_FRIENDLY_ONLY },
        { "focus",  "HELPFUL", FC.WARN.IDS_FRIENDLY_ONLY },
        { "player", "HARMFUL", FC.WARN.IDS_OWN_DEBUFFS },
        { "pet",    "HARMFUL", FC.WARN.IDS_OWN_DEBUFFS },
        { "target", "HARMFUL", FC.WARN.IDS_HOSTILE_ONLY },
        { "focus",  "HARMFUL", FC.WARN.IDS_HOSTILE_ONLY },
    }
    for _, c in ipairs(expected) do
        -- A blacklist is the smallest thing that makes a plan lean on spell ids, which is what
        -- `finishWarnings` gates the sentence on — the same seam the older warning case above uses.
        local plan = compile({ auraType = c[2], unit = c[1], filter = { blacklist = { [1] = true } } })
        local label = c[2] .. " on " .. c[1]
        if c[3] then
            assertEqual(#plan.warnings, 1, label .. ": exactly one sentence")
            assertEqual(plan.warnings[1], c[3], label)
        else
            assertEqual(#plan.warnings, 0, label .. ": ids are honored outright, so nothing to say")
        end
    end
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

test("filter: an enchant-only buff container's slots also come from the profile, falling back to all three", function()
    local enchantsOnly = { unit = "player", filter = { categories = NS.Categories.EnchantOnlyStates() } }
    local none = FC.Compile(cfg(enchantsOnly), { enchantSlots = { mainHand = false, offHand = false, ranged = false } })
    assertEqual(#none.enchants.slots, 3, "every slot off falls back to all three")
    assertTrue(none.enchants.hidePermanent, "hide-permanent is on by default")
    local some = FC.Compile(cfg(enchantsOnly), { enchantSlots = { mainHand = true, offHand = false, ranged = false } })
    assertEqual(table.concat(some.enchants.slots, ","), "mainHand")
end)

-- ── sorting and caps ──────────────────────────────────────────────────────────────────────────

test("filter: max auras caps each group; 0 means no cap", function()
    assertEqual(compile({ filter = { maxAuras = 5 } }).groups[1].maxFrameCount, 5)
    assertEqual(compile({ filter = { maxAuras = 0 } }).groups[1].maxFrameCount, HUGE)
end)

test("filter: max auras stamps EVERY group, not just the first — the cap is per group, not per container", function()
    -- red under: lookOf only being applied to one group; this is the bug the maxAuras description
    -- exists to warn about — 5 shown groups each capped at 5 is up to 25 frames, not 5.
    local plan = compile({ filter = { maxAuras = 5, categories = { defensives = "show", racials = "hide" } } },
        { categories = only("HELPFUL", { "defensives", "racials" }) })
    assertTrue(#plan.groups > 1, "more than one group exists to check")
    for i, g in ipairs(plan.groups) do
        assertEqual(g.maxFrameCount, 5, "group " .. i)
    end
end)

-- ── the headline rule (spec section 6, rank 3 over rank 4) ───────────────────────────────────────

test("filter: an aura in a Show category is drawn even if it is also in a Hide category (rank 3 beats rank 4)", function()
    -- red under: a shown group inheriting a hidden category's exclusion (rank 4 winning), which
    -- would mean nothing but the catch-all can ever draw an aura
    local plan = compile({ filter = { categories = { defensives = "show", racials = "hide" } } },
        { categories = only("HELPFUL", { "defensives", "racials" }) })
    local shownGroup
    for _, g in ipairs(plan.groups) do
        if g.label == "Defensive cooldowns" then shownGroup = g end
    end
    assertTrue(shownGroup ~= nil, "the shown category gets its own group")
    -- red under: includeCategory's spells branch swapping includeSpellIDs for excludeSpellIDs
    assertTrue(shownGroup.candidateFilters.includeSpellIDs[642], "a defensives id is positively included")
    assertNil(shownGroup.candidateFilters.excludeSpellIDs,
        "nothing hidden narrows the SHOWN group itself — that is what lets rank 3 beat rank 4")
end)

test("filter: a Hide plus a Show yields a group per shown category plus the catch-all, with no aura drawn twice (R-4/R-5)", function()
    local plan = compile({ filter = { categories = { defensives = "show", racials = "hide" } } },
        { categories = only("HELPFUL", { "defensives", "racials" }) })
    assertEqual(#plan.groups, 2, "one shown group (defensives) plus the catch-all")
    local shownGroup, catchAll
    for _, g in ipairs(plan.groups) do
        if g.label == "Defensive cooldowns" then shownGroup = g
        elseif g.label == "All" then catchAll = g end
    end
    assertTrue(shownGroup ~= nil and catchAll ~= nil, "both groups exist")
    -- red under: the catch-all not excluding the shown category too, drawing a defensives id twice
    assertTrue(catchAll.candidateFilters.excludeSpellIDs[642],
        "the catch-all excludes the shown category's ids as well as the hidden one's")
end)

-- ── the cost is real: the REAL shipped category list, not `only` (documented in the plan ledger) ──

test("filter: one Hide on the real shipped category list explodes to one group per other shown category — 17 for HELPFUL, 17 for HARMFUL today", function()
    -- Not a bug — R-4's shape is inherent to "in ANY shown category" being a union over heterogeneous
    -- predicates the engine ORs as groups (ruling, 2026-09-15 fix round 1 of batch 6). This test
    -- exists so the count is visible in the suite: if it moves, a category was added or removed and
    -- someone should look, not silently absorb a costlier (or cheaper but wrong) container.
    --
    -- HELPFUL: 18 filterable categories (15 pre-batch-7 plus `uncategorized`, U-1, then schema v7
    -- retiring `consumables` for `groupBuffs`, `stances` and `racials`) minus 1 hidden
    -- (defensives) = 17 shown groups (`uncategorized` included, own its group like any other shown
    -- category), and NO catch-all: batch 7's fix round 1 suppresses it outright once an
    -- `uncategorized` category exists for the aura type (its constraints were always either a strict
    -- subset of `uncategorized`'s own group's, or a group that could never match — see
    -- modules/FilterCompiler.lua's top-of-file comment). 17 groups total.
    --
    -- HARMFUL: 19 filterable categories (16 pre-batch-7, plus `uncategorizedDebuffs` restored in fix
    -- round 3 with an asymmetric meaning — defaults/Categories.lua's KINDS doc — plus issue #11's
    -- `hardCC` and `softCC`) minus 1 hidden (crowdControl) = 18 shown categories, but only 17
    -- actually become groups: `uncategorizedDebuffs` contributes NO group of its own on Show (fix
    -- round 3, gated on the unit by issue #11 — `hasUnion` is false here). The count moved by
    -- exactly the two categories A1 added, which is the prediction the previous revision of this
    -- comment wrote down before they existed. What did NOT move is the reasoning about this row: it
    -- used to be held false by two independent reasons and is now held false by one, since the debuff
    -- union is no longer empty — `FC.IdsAlwaysHonored` is false for EVERY debuff container whatever
    -- the union holds, because the engine discards debuff ids on the player outright and may discard
    -- them on a target the moment it is friendly. Either way `addShownGroups` skips it rather than
    -- emit an unrestricted group that would draw every debuff and defeat every other
    -- category's Hide. The catch-all is
    -- NOT suppressed by its presence either (Show-with-no-union supersedes nothing), so it is
    -- attempted — and dropped anyway, for the same pre-existing reason as before round 3:
    -- `fromPlayers` and `fromNonPlayers` are both default-Show HARMFUL categories that hide the SAME
    -- field (`isFromPlayerOrPlayerPet`) to opposite values; the catch-all excludes every shown
    -- category (R-5), so it asks for that field to be both true and false at once, `con.conflict`
    -- fires, and `addGroup` drops it. This is correct, not a bug: the pair partitions the debuff aura
    -- space (every debuff either was or was not cast by a player or their pet), so every debuff is
    -- already in one of the two SHOWN groups and rank 3 draws it regardless — nothing is lost by the
    -- catch-all's absence. This holds only on the assumption that a real aura's
    -- `isFromPlayerOrPlayerPet` is never nil; if a future category pair ever left a gap in the aura
    -- space the way this one does not, its catch-all would need to survive, and this count would need
    -- to be revisited along with it. See the dedicated test below that isolates
    -- `uncategorizedDebuffs` from this pair, which the real shipped list otherwise masks.
    local helpfulPlan = compile({ filter = { categories = { defensives = "hide" } } })
    assertEqual(#helpfulPlan.groups, 17, "HELPFUL: 17 shown groups, no catch-all (Uncategorized supersedes it)")
    local harmfulPlan = compile({ auraType = "HARMFUL", filter = { categories = { crowdControl = "hide" } } })
    assertEqual(#harmfulPlan.groups, 17, "HARMFUL: 17 shown groups, no catch-all (it self-contradicts and is dropped)")
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
    { { unit = "player", auraType = "HELPFUL", filter = { categories = NS.Categories.EnchantOnlyStates() } } },
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

    -- An enchant-only buff container (schema v5): the three slots, no aura group, and no warning.
    "{enchants={hidePermanent=boolean:true,slots={1=string:mainHand,2=string:offHand,3=string:ranged}},groups={},"
    .. "warnings={}}",
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
    local def = NS.Categories.Find("HELPFUL", "racials")
    local removed = {}
    for id in pairs(def.spells) do removed[id] = false end
    local plan = compile({ filter = { categories = { racials = "hide" } } },
        { categorySpells = { racials = removed }, categories = only("HELPFUL", { "racials" }) })
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

-- ── FC.ExplainSpell (task B6, spec §6/§6c) ───────────────────────────────────────────────────────
--
-- The Overrides tab's per-entry note is built from this: given a container's settings and one spell
-- id, which of the five ranks decides it, and what does it draw. Every case below narrows
-- `ctx.categories` the same way the compiler tests above do (`only`), so a case testing one or two
-- categories' interaction is not exploded by the whole shipped list.

-- red under: the blacklist beating the whitelist (the superseded order)
test("explain: the whitelist beats the blacklist — rank 1, shown", function()
    local x = FC.ExplainSpell(cfg({ filter = { whitelist = { [500] = true }, blacklist = { [500] = true } } }),
        500, {})
    assertEqual(x.verdict, "shown")
    assertEqual(x.rank, 1)
    assertEqual(#x.categories, 0)
end)

test("explain: the blacklist alone hides — rank 2", function()
    local x = FC.ExplainSpell(cfg({ filter = { blacklist = { [500] = true } } }), 500, {})
    assertEqual(x.verdict, "hidden")
    assertEqual(x.rank, 2)
    assertEqual(#x.categories, 0)
end)

-- red under: a single Hide category removing an aura another category shows (the superseded order)
test("explain: a Show category rescues an aura another category hides — rank 3, shown, both named", function()
    local x = FC.ExplainSpell(cfg({ filter = { categories = { defensives = "hide" } } }), 900001,
        { categorySpells = { defensives = { [900001] = true }, racials = { [900001] = true } },
          categories = only("HELPFUL", { "defensives", "racials" }) })
    assertEqual(x.verdict, "shown")
    assertEqual(x.rank, 3)
    local states = {}
    for _, c in ipairs(x.categories) do states[c.key] = c.state end
    assertEqual(states.defensives, "hide")
    assertEqual(states.racials, "show")
end)

test("explain: an aura whose every category says Hide is hidden — rank 4", function()
    local x = FC.ExplainSpell(cfg({ filter = { categories = { defensives = "hide" } } }), 900002,
        { categorySpells = { defensives = { [900002] = true } },
          categories = only("HELPFUL", { "defensives" }) })
    assertEqual(x.verdict, "hidden")
    assertEqual(x.rank, 4)
    assertEqual(x.categories[1].key, "defensives")
end)

test("explain: an aura in no category is shown, with no categories named — rank 5", function()
    local x = FC.ExplainSpell(cfg({}), 999999, { categories = only("HELPFUL", { "defensives" }) })
    assertEqual(x.verdict, "shown")
    assertEqual(x.rank, 5)
    assertEqual(#x.categories, 0)
end)

-- D8 retired (fix round 2): a stray `filter.onlyShown` key, however it got there, changes nothing —
-- rank 5 is unconditionally shown with no `uncategorized` category for the aura type (here, the
-- `only` stub offers none), matching the compiled plan (the toggle no longer exists for the compiler
-- to read either).
test("explain: a stray filter.onlyShown key does not affect rank 5 — the toggle is retired", function()
    local x = FC.ExplainSpell(cfg({ filter = { onlyShown = true } }), 999999,
        { categories = only("HELPFUL", { "defensives" }) })
    assertEqual(x.verdict, "shown")
    assertEqual(x.rank, 5)
end)

-- red under: a token/flag/dispel category being guessed at by id instead of left silent
test("explain: a token category is never named — only spells-kind categories are reasoned about", function()
    local x = FC.ExplainSpell(cfg({ filter = { categories = { cancelable = "hide" } } }), 999999,
        { categories = only("HELPFUL", { "cancelable" }) })
    assertEqual(#x.categories, 0)
    assertEqual(x.verdict, "shown")
    assertEqual(x.rank, 5)
end)

-- ── the Player cooldowns starter (text style, spec 7.1) ────────────────────────────────────────────────────────────────

test("filter: the Player cooldowns starter draws one group per list it shows and no catch-all", function()
    local c = cfg({ filter = { categories = NS.Categories.StatesShowing({ "offensiveCDs", "defensives" }) } })
    local plan = FC.Compile(c)
    local labels = {}
    for i, g in ipairs(plan.groups) do labels[i] = g.label end
    -- red under: StatesShowing leaving Uncategorized at Show (its group draws every unlisted buff)
    assertEqual(#plan.groups, 2, table.concat(labels, ","))
    local ids = 0
    for _, g in ipairs(plan.groups) do
        assertTrue(g.candidateFilters and g.candidateFilters.includeSpellIDs ~= nil, g.label .. " is an id list")
        ids = ids + 1
    end
    assertEqual(ids, 2)
    -- A buff on neither list has no Show to draw it.
    assertEqual(FC.ExplainSpell(c, 999999).verdict, "hidden")
end)

test("filter: a buff container showing only Weapon enchants draws the slots, no aura group and no never-matches warning (feedback #6)", function()
    local c = cfg({ auraType = "HELPFUL", unit = "player" })
    c.filter.categories = NS.Categories.EnchantOnlyStates()
    local plan = FC.Compile(c, {})
    local slotCount, groupCount = #plan.enchants.slots, #plan.groups
    assertEqual(slotCount, 3)
    assertEqual(groupCount, 0)
    -- red under: NEVER_MATCHES raised for a container whose whole point is its enchant slots
    assertTrue(not hasWarning(plan, "never match"))
    -- The same states on another unit draw nothing at all, and say so.
    c.unit = "target"
    assertTrue(hasWarning(FC.Compile(c, {}), "never match"))
end)
