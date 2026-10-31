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
local setOf, hasWarning, categoryGroups = H.setOf, H.hasWarning, H.categoryGroups

local function only(...) return H.only(NS, ...) end

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
    assertTrue(hasWarning(plan, "Maximum duration is ignored"), "the ignored limit is reported")
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
    assertEqual(#categoryGroups(plan), 1, "nothing else is shown or hidden, so the catch-all is the only group")
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
-- in core/Database_Migrations.lua (tests/test_database.lua's schema step 4); this file only needs
-- to prove the compiler never reads the dead key at all any more — belt-and-braces, in case one
-- somehow survives migration (a restored backup, a profile copy from before this version).

test("filter: a stray filter.onlyShown key, however it got there, is inert — the compiler never reads it (D8 retired)", function()
    local withKey = compile({ filter = { onlyShown = true, categories = { bigDefensive = "hide" } } },
        { categories = only("HELPFUL", { "bigDefensive" }) })
    local withoutKey = compile({ filter = { categories = { bigDefensive = "hide" } } },
        { categories = only("HELPFUL", { "bigDefensive" }) })
    assertEqual(FC.Signature(withKey), FC.Signature(withoutKey))
end)

-- ── what the engine will not do ───────────────────────────────────────────────────────────────

test("filter: spell lists on your own debuffs are flagged as ignored", function()
    local plan = compile({ auraType = "HARMFUL", unit = "player", filter = { blacklist = { [1] = true } } })
    assertTrue(hasWarning(plan, "your pet's debuffs"))
end)

test("filter: spell lists on a target's buffs only apply while it is friendly", function()
    local plan = compile({ unit = "target", filter = { whitelist = { [1] = true } } })
    assertTrue(hasWarning(plan, "units you can't assist"))
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

test("filter: one Hide on the real shipped category list explodes to one group per other shown category — 17 for HELPFUL, 19 for HARMFUL today", function()
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
    -- HARMFUL: 21 filterable categories (16 pre-batch-7, plus `uncategorizedDebuffs` restored in fix
    -- round 3 with an asymmetric meaning — defaults/Categories.lua's KINDS doc — plus issue #11's
    -- `hardCC` and `softCC`, plus schema v7's `racialDebuffs`, plus one more since schema v12 split
    -- `softCC` into `ccRoot` and `ccSnare`) minus 1 hidden (crowdControl) = 20
    -- shown categories, but only 19 actually become groups: `uncategorizedDebuffs` contributes NO group of its own on Show (fix
    -- round 3, gated on the unit by issue #11 — `hasUnion` is false here). The count moved by
    -- exactly the two categories A1 added, which is the prediction the previous revision of this
    -- comment wrote down before they existed. What did NOT move is the reasoning about this row: it
    -- used to be held false by two independent reasons and is now held false by one, since the debuff
    -- union is no longer empty — `FC.IdsMode` is never "always" for a debuff container whatever
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
    assertEqual(#categoryGroups(harmfulPlan), 19, "HARMFUL: 19 shown groups, no catch-all (it self-contradicts and is dropped)")
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
-- Recaptured 2026-10-02 (SV-01): every group now carries its no-ids view (modules/FilterViews.lua),
-- and the identity sentence is reworded and printed wherever a category is Hidden. Recaptured again
-- 2026-10-02 (SI-01): the no-ids view is now `views.blizzard`, beside `views.every`, and the target
-- debuff case gains the trailing remainder slot (filter situations, S1).

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
    .. "groups={1={candidateFilters={includeSpellIDs={100=boolean:true,200=boolean:true}},"
    .. "filter=string:HELPFUL,key=string:g1,label=string:Always shown,maxFrameCount=number:5,"
    .. "sortDirection=string:reverse,sortMethod=string:default,"
    .. "views={blizzard={candidateFilters={includeDispelTypes={}},filter=string:HELPFUL},"
    .. "every={candidateFilters={includeDispelTypes={}},filter=string:HELPFUL}}},"
    .. "2={candidateFilters={excludeSpellIDs={100=boolean:true,200=boolean:true,300=boolean:true,"
    .. "400=boolean:true}},filter=string:HELPFUL|!PLAYER|BIG_DEFENSIVE,key=string:g2,"
    .. "label=string:Big defensives (Blizzard),maxFrameCount=number:5,sortDirection=string:reverse,"
    .. "sortMethod=string:default,views={blizzard={candidateFilters={excludeSpellIDs={300=boolean:true,"
    .. "400=boolean:true}},filter=string:HELPFUL|!PLAYER|BIG_DEFENSIVE},"
    .. "every={candidateFilters={excludeSpellIDs={300=boolean:true,400=boolean:true}},"
    .. "filter=string:HELPFUL|!PLAYER|BIG_DEFENSIVE}}},"
    .. "3={candidateFilters={excludeSpellIDs={100=boolean:true,200=boolean:true,300=boolean:true,"
    .. "400=boolean:true}},filter=string:HELPFUL|!PLAYER|RAID|!BIG_DEFENSIVE,key=string:g3,"
    .. "label=string:Castable/Dispellable by you,maxFrameCount=number:5,sortDirection=string:reverse,"
    .. "sortMethod=string:default,views={blizzard={candidateFilters={excludeSpellIDs={300=boolean:true,"
    .. "400=boolean:true}},filter=string:HELPFUL|!PLAYER|RAID|!BIG_DEFENSIVE},"
    .. "every={candidateFilters={excludeSpellIDs={300=boolean:true,400=boolean:true}},"
    .. "filter=string:HELPFUL|!PLAYER|RAID|!BIG_DEFENSIVE}}},"
    .. "4={candidateFilters={excludeSpellIDs={100=boolean:true,200=boolean:true,300=boolean:true,"
    .. "400=boolean:true},isStealable=boolean:false},"
    .. "filter=string:HELPFUL|!PLAYER|!IMPORTANT|!BIG_DEFENSIVE|!RAID,key=string:g4,label=string:All,"
    .. "maxFrameCount=number:5,sortDirection=string:reverse,sortMethod=string:default,"
    .. "views={blizzard={candidateFilters={includeDispelTypes={}},"
    .. "filter=string:HELPFUL|!PLAYER|!IMPORTANT|!BIG_DEFENSIVE|!RAID},"
    .. "every={candidateFilters={includeDispelTypes={}},"
    .. "filter=string:HELPFUL|!PLAYER|!IMPORTANT|!BIG_DEFENSIVE|!RAID}}}},"
    .. "warnings={1=string:Maximum duration is ignored while showing only auras without a duration.}}",

    -- magic and boss (rank 3, shown) each get their own group; crowdControl (rank 4, hidden) only
    -- narrows the catch-all, which also excludes magic and boss so they are not drawn twice.
    "{groups={1={candidateFilters={isBossAura=boolean:true,maxDuration=number:12},"
    .. "filter=string:HARMFUL|PLAYER,key=string:g1,label=string:Boss debuffs,maxFrameCount=number:inf,"
    .. "sortDirection=string:normal,sortMethod=string:expirationOnly,"
    .. "views={blizzard={candidateFilters={isBossAura=boolean:true,maxDuration=number:12},"
    .. "filter=string:HARMFUL|PLAYER},every={candidateFilters={includeDispelTypes={}},"
    .. "filter=string:HARMFUL|PLAYER}}},2={candidateFilters={includeDispelTypes={Magic=boolean:true},"
    .. "isBossAura=boolean:false,maxDuration=number:12},filter=string:HARMFUL|PLAYER,key=string:g2,"
    .. "label=string:Magic,maxFrameCount=number:inf,sortDirection=string:normal,"
    .. "sortMethod=string:expirationOnly,"
    .. "views={blizzard={candidateFilters={includeDispelTypes={Magic=boolean:true},isBossAura=boolean:false,"
    .. "maxDuration=number:12},filter=string:HARMFUL|PLAYER},"
    .. "every={candidateFilters={includeDispelTypes={}},filter=string:HARMFUL|PLAYER}}},"
    .. "3={candidateFilters={excludeDispelTypes={Magic=boolean:true},isBossAura=boolean:false,"
    .. "maxDuration=number:12},filter=string:HARMFUL|PLAYER|!CROWD_CONTROL,key=string:g3,label=string:All,"
    .. "maxFrameCount=number:inf,sortDirection=string:normal,sortMethod=string:expirationOnly,"
    .. "views={blizzard={candidateFilters={includeDispelTypes={}},"
    .. "filter=string:HARMFUL|PLAYER|!CROWD_CONTROL},every={candidateFilters={includeDispelTypes={}},"
    .. "filter=string:HARMFUL|PLAYER|!CROWD_CONTROL}}},4={candidateFilters={includeDispelTypes={}},"
    .. "filter=string:HARMFUL|PLAYER|!CROWD_CONTROL,key=string:g4,label=string:Every aura,"
    .. "maxFrameCount=number:inf,remainder=boolean:true,sortDirection=string:normal,"
    .. "sortMethod=string:expirationOnly,views={blizzard={candidateFilters={includeDispelTypes={}},"
    .. "filter=string:HARMFUL|PLAYER|!CROWD_CONTROL},every={candidateFilters={maxDuration=number:12},"
    .. "filter=string:HARMFUL|PLAYER|!CROWD_CONTROL}}}},"
    .. "warnings={1=string:Only auras without a duration works for buffs only; this container shows every duration.,"
    .. "2=string:On units you can assist,"
    .. " spell categories and Overrides are not applied. Where spell lists don't apply, at the top of the Categories tab, picks what draws there.}}",

    -- No category is Hidden here, so R-3 still applies: bigDefensive (show) buys its own group only
    -- when something else is hiding, and nothing is — one whitelist group, one catch-all.
    "{groups={1={candidateFilters={includeSpellIDs={500=boolean:true}},filter=string:HELPFUL,"
    .. "key=string:g1,label=string:Always shown,maxFrameCount=number:inf,sortDirection=string:normal,"
    .. "sortMethod=string:expirationOnly,views={blizzard={candidateFilters={includeDispelTypes={}},"
    .. "filter=string:HELPFUL},every={candidateFilters={includeDispelTypes={}},filter=string:HELPFUL}}},"
    .. "2={candidateFilters={excludeSpellIDs={500=boolean:true},maxDuration=number:inf},"
    .. "filter=string:HELPFUL,key=string:g2,label=string:All,maxFrameCount=number:inf,"
    .. "sortDirection=string:normal,sortMethod=string:expirationOnly,"
    .. "views={blizzard={candidateFilters={maxDuration=number:inf},filter=string:HELPFUL},"
    .. "every={candidateFilters={maxDuration=number:inf},filter=string:HELPFUL}}}},"
    .. "warnings={1=string:On units you can't assist (hostile or neutral),"
    .. " the Overrides lists are not applied.}}",

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
        { "HARMFUL", "pet", "your pet's debuffs" },
        { "HARMFUL", "focus", "On units you can assist" },
        { "HELPFUL", "focus", "units you can't assist" },
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
    -- red under: the retired `usesSpellIds` gate. Timeless's learned-id exclusion is neither a spell
    -- category nor an Override, so the sentence about those is not printed for it (2026-10-02).
    assertEqual(#learned.warnings, 0, "no Hide and no Overrides list: nothing for the sentence to say")
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
    assertEqual(#categoryGroups(plan), 1, "the contradictory catch-all is dropped")
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
    assertEqual(#categoryGroups(plan), 0, "isFromPlayerOrPlayerPet can't be both true and false")
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
