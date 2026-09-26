-- tests/test_filtercompiler_categories.lua — modules/FilterCompiler.lua against the player's own
-- categories: the categorized union, the overlap guardrail's one question and a user category as the
-- only shown category (issue #10). Peeled out of tests/test_filtercompiler.lua along its
-- user-categories seam (issue #18). Each case builds its own environment.

local T = _G.AM_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local H = dofile("tests/filtercompiler_helpers.lua")
local setOf, hasWarning = H.setOf, H.hasWarning

-- ── user categories and the categorized union (issue #10 checkpoint 4) ─────────────────────────
--
-- Checkpoint 4 asks for NO compiler change at all: `categorizedUnion` walks `Categories.For` and
-- takes every `spells`-kind definition, and checkpoint 3 materializes a user category as exactly
-- that. The plan of record calls this out as must-prove-not-assume, so the cases below prove it
-- through a COMPILED PLAN rather than by reading the local -- and they prove the NEGATIVE the issue
-- is actually worried about, not merely that the union is non-empty.
--
-- Their own environment: materializing a category mutates Cat.HELPFUL, the container template and
-- NS.Schema, all of which the shared environment tests/run.lua builds is read for.

local freshEnv = dofile("tests/fresh_env.lua")

local MINE = 987654      -- an id no shipped list carries, claimed by the player's own category
local NOBODYS = 987655   -- and one nothing claims at all, the control

--- A player buff container with one user category holding MINE, that category HIDDEN and everything
--- else left at its default Show. `unit = "player"` is not incidental: it is the one unit where
--- FC.IdsAlwaysHonored is true, so the Uncategorized rescue group genuinely exists and the rescue
--- this checkpoint is about can actually happen.
local function envWithUserCategory()
    local E = freshEnv()
    local key = E.Categories.CreateUserCategory("My affixes", "HELPFUL")
    E.SetByPath("categorySpells", { [key] = { [MINE] = true } })
    local con = E.Database.DeepCopy(E.CONTAINER_TEMPLATE)
    con.unit, con.auraType = "player", "HELPFUL"
    con.filter.categories[key] = "hide"
    return E, key, con
end

local function groupNamed(plan, label)
    for _, g in ipairs(plan.groups) do
        if g.label == label then return g end
    end
    return nil
end

test("categories: a user category joins the categorized union, so Uncategorized stops rescuing what it claims", function()
    local E, key, con = envWithUserCategory()
    local plan = E.FilterCompiler.Compile(con, E.FilterCompiler.ProfileContext())

    -- 1. The union, read out of the compiled plan and not out of the local: Uncategorized's whole
    -- group IS an excludeSpellIDs of the union. red under: categorizedUnion missing user categories.
    local rescue = groupNamed(plan, "Uncategorized")
    assertTrue(rescue ~= nil, "the player-buff container has its Uncategorized rescue group")
    local excluded = rescue.candidateFilters and rescue.candidateFilters.excludeSpellIDs or {}
    assertTrue(excluded[MINE], "the user category's id is outside what Uncategorized draws")
    assertTrue(excluded[NOBODYS] == nil, "and an id in no category at all is not")

    -- 2. Concretely: nothing in the plan draws MINE. The category that claims it is Hidden and gets
    -- no group, and the rescue group excludes it.
    for _, g in ipairs(plan.groups) do
        local include = g.candidateFilters and g.candidateFilters.includeSpellIDs
        assertTrue(include == nil or include[MINE] == nil, "group " .. g.label .. " draws a hidden id")
    end

    -- 3. And the explanation agrees with the plan. Rank 4 is the assertion that matters: rank 5 --
    -- "in no category at all" -- is exactly the misbehavior issue #10 describes, where rank 3
    -- rescues the aura precisely when the player hid it deliberately.
    local why = E.FilterCompiler.ExplainSpell(con, MINE, E.FilterCompiler.ProfileContext())
    assertEqual(why.verdict, "hidden")
    assertEqual(why.rank, 4)
    assertEqual(#why.categories, 1)
    assertEqual(why.categories[1].key, key)
    assertEqual(why.categories[1].label, "My affixes")
    assertEqual(why.categories[1].state, "hide")

    -- The control, so the case cannot pass by hiding everything: an id no list claims still takes
    -- Uncategorized's Show, at rank 3, on this very container.
    local control = E.FilterCompiler.ExplainSpell(con, NOBODYS, E.FilterCompiler.ProfileContext())
    assertEqual(control.verdict, "shown")
    assertEqual(control.rank, 3)
end)

test("categories: a user category reaches the compiler as an ordinary spells-kind def of Categories.For", function()
    -- The cheaper guard, on the MECHANISM rather than the outcome: a later refactor that stopped
    -- materializing user categories -- keeping them in a side list, say -- would empty the union
    -- silently, and this is where it fails loudly instead.
    local E, key = envWithUserCategory()
    local found
    for _, def in ipairs(E.Categories.For("HELPFUL")) do
        if def.key == key then found = def end
    end
    assertTrue(found ~= nil, "the user category is in Categories.For('HELPFUL')")
    assertEqual(found.kind, "spells", "which is the kind categorizedUnion takes")
    local spells = E.FilterCompiler.CategorySpells(found, E.db.profile.categorySpells)
    assertEqual(spells[MINE], true, "and its effective list is the profile's edits alone")
end)

-- ── the overlap guardrail's one question (issue #10 checkpoint 7) ──────────────────────────────
--
-- `FC.ClaimingCategories` was `ExplainSpell`'s private local until checkpoint 7 published it, so
-- that settings/GeneralSpells.lua could say WHICH other categories already hold a spell id without
-- writing a second answer to that question. These cases pin the published shape: the panel is not
-- free to re-derive it, and the compiler is not free to change it under the panel.

test("categories: ClaimingCategories names every spells-kind category of the aura type that holds an id, in declaration order", function()
    local E = freshEnv()
    local key = E.Categories.CreateUserCategory("My affixes", "HELPFUL")
    local debuffs = E.Categories.CreateUserCategory("Their affixes", "HARMFUL")
    -- The same id on a SHIPPED buff list, on the player's own buff list, and on a DEBUFF list.
    E.SetByPath("categorySpells", {
        defensives = { [MINE] = true }, [key] = { [MINE] = true }, [debuffs] = { [MINE] = true },
    })

    local claiming, anyShow = E.FilterCompiler.ClaimingCategories(E.Categories, "HELPFUL", {},
        E.db.profile.categorySpells, MINE)
    local keys, labels = {}, {}
    for i, c in ipairs(claiming) do
        keys[i], labels[i] = c.key, c.label
    end
    -- red under: an answer that loses the user category (walking only shipped definitions), or one
    -- that includes the debuff category -- a buff list and a debuff list never meet in a container,
    -- so calling that an overlap would be a false alarm on every id that lives in both worlds.
    assertEqual(table.concat(keys, ","), "defensives," .. key, "declaration order, buffs only")
    -- Labels come back already routed by `Cat.LabelOf`: the shipped one through NS.L, the player's
    -- own text untouched. A caller routing them again is what that rule exists to prevent.
    assertEqual(table.concat(labels, ","), E.L["Defensive cooldowns"] .. ",My affixes")
    assertTrue(anyShow, "an empty filter leaves every claim at its default Show")

    -- The control: an id nothing claims answers an EMPTY list, which is what the panel reads as
    -- "no other category holds this" and draws no note for.
    local none = E.FilterCompiler.ClaimingCategories(E.Categories, "HELPFUL", {},
        E.db.profile.categorySpells, NOBODYS)
    assertEqual(#none, 0)

    -- And asking as the debuff side sees only the debuff list.
    local theirs = E.FilterCompiler.ClaimingCategories(E.Categories, "HARMFUL", {},
        E.db.profile.categorySpells, MINE)
    assertEqual(#theirs, 1)
    assertEqual(theirs[1].key, debuffs)
end)

test("categories: ClaimingCategories is the same answer ExplainSpell gives, and the container's filter decides only the state", function()
    local E, key, con = envWithUserCategory()
    -- The user category is HIDDEN on this container (envWithUserCategory), which is what makes the
    -- two calls distinguishable: the guardrail asks with an EMPTY filter because it is a statement
    -- about the category SET, not about one container.
    local asPanel = E.FilterCompiler.ClaimingCategories(E.Categories, "HELPFUL", {},
        E.db.profile.categorySpells, MINE)
    assertEqual(#asPanel, 1)
    assertEqual(asPanel[1].key, key)
    assertEqual(asPanel[1].state, "show", "no container, no Hide")

    local why = E.FilterCompiler.ExplainSpell(con, MINE, E.FilterCompiler.ProfileContext())
    -- red under: the panel and the Overrides notes drifting into two answers to one question.
    assertEqual(#why.categories, 1)
    assertEqual(why.categories[1].key, asPanel[1].key)
    assertEqual(why.categories[1].label, asPanel[1].label)
    assertEqual(why.categories[1].state, "hide", "the container's stored Hide, read from its filter")
end)

-- ── a user category as the ONLY shown category (owner report, 2026-09-21) ────────────────
--
-- THE REPORT: a user category "MyCat1" holding three monk buffs, a player BUFF container with that
-- category Show and EVERY other category Hide (Uncategorized included), Renewing Mist active on the
-- player -- and the container drew nothing at all.
--
-- THE HYPOTHESIS THAT BROUGHT THESE CASES HERE, written down because it was WRONG and the next
-- reader deserves to know it was tested rather than assumed: that `includeCategory`'s `spells`
-- branch conflicts a user category (whose own `def.spells` is empty by construction, checkpoint 3),
-- drops its group, and -- with Uncategorized Hidden suppressing the catch-all -- leaves a plan with
-- no groups at all. It does not: `FC.CategorySpells` resolves starters PLUS `categorySpells[key]`,
-- which is exactly where a user category's whole list lives, so the group compiles with the ids on
-- it. The cases below pin that, and they pin the one shape that really does compile to nothing (an
-- EMPTY list, which can never match and says so) so the two can never be confused again.
--
-- The report's own failure was neither: the ids. AuraMaster filters on the id of the AURA sitting on
-- the unit, never the id of the spell that was cast (tools/spell-research/README.md, "The crux: aura
-- ids, not cast ids"), and 115151 is Renewing Mist's CAST id -- the shipped monk healing starters
-- carry 119611 for it (defaults/Categories.lua:366), beside the same 124682 and 115175 the report
-- lists. A list built from a cast id draws nothing and reports nothing, which is what was seen.

local OWNER_IDS = { 124682, 115151, 115175 }   -- the report's list, its Renewing Mist a CAST id
local RENEWING_MIST_AURA = 119611              -- what the shipped monk healing list carries instead

--- A player BUFF container with `key` Show and every other category of the aura type Hide --
--- Uncategorized included, which is what suppresses the catch-all and leaves the shown groups as
--- the whole plan.
local function onlyShown(E, con, key)
    for _, def in ipairs(E.Categories.For(con.auraType)) do
        con.filter.categories[def.key] = (def.key == key) and "show" or "hide"
    end
    return con
end

local function userContainer(E, unit, auraType)
    local con = E.Database.DeepCopy(E.CONTAINER_TEMPLATE)
    con.unit, con.auraType = unit, auraType
    return con
end

test("categories: a user category alone on Show compiles to its group, with its own spell ids on it", function()
    local E = freshEnv()
    local key = E.Categories.CreateUserCategory("MyCat1", "HELPFUL")
    local edits = {}
    for _, id in ipairs(OWNER_IDS) do edits[id] = true end
    E.SetByPath("categorySpells", { [key] = edits })
    local con = onlyShown(E, userContainer(E, "player", "HELPFUL"), key)

    local plan = E.FilterCompiler.Compile(con, E.FilterCompiler.ProfileContext())
    -- red under the hypothesis above: a conflicted group is dropped, and with Uncategorized Hidden
    -- suppressing the catch-all the plan would carry no group at all.
    assertEqual(#plan.groups, 1, "the shown user category is the whole plan")
    assertEqual(plan.groups[1].filter, "HELPFUL")
    assertEqual(setOf(plan.groups[1].candidateFilters.includeSpellIDs), "115151,115175,124682")
    assertTrue(not hasWarning(plan, "never match"), "a list with ids in it can match")

    -- And the compiler filters on exactly the ids it was given: the aura id the shipped monk list
    -- carries for Renewing Mist is NOT in this group, because nobody put it in this category. That
    -- is the report's actual failure, pinned as behavior rather than as a defect.
    assertTrue(plan.groups[1].candidateFilters.includeSpellIDs[RENEWING_MIST_AURA] == nil,
        "an id the category does not hold is not filtered for")
end)

test("categories: a user category with an EMPTY list is the one shape that compiles to nothing, and it warns", function()
    local E = freshEnv()
    local key = E.Categories.CreateUserCategory("Empty", "HELPFUL")
    local con = onlyShown(E, userContainer(E, "player", "HELPFUL"), key)

    local plan = E.FilterCompiler.Compile(con, E.FilterCompiler.ProfileContext())
    -- An empty `includeSpellIDs` IS what the engine would honor, so `includeCategory` conflicts the
    -- group and `addGroup` drops it (the top-of-file comment's "a group that can never match").
    -- With Uncategorized Hidden there is no catch-all behind it either, so the plan is empty -- and
    -- `finishWarnings` is what keeps that from being silent.
    assertEqual(#plan.groups, 0, "an empty category shown alone leaves nothing to draw")
    assertTrue(hasWarning(plan, "never match anything"), "and the container says so")
end)

test("categories: an empty user category shown does not take Uncategorized's catch-all down with it", function()
    local E = freshEnv()
    local key = E.Categories.CreateUserCategory("Empty", "HELPFUL")
    local con = onlyShown(E, userContainer(E, "player", "HELPFUL"), key)
    con.filter.categories.uncategorized = "show"

    local plan = E.FilterCompiler.Compile(con, E.FilterCompiler.ProfileContext())
    -- The union is non-empty (the shipped buff lists) and the unit is the player, so `hasUnion` is
    -- true and Uncategorized supersedes the catch-all with a group of its own -- which is what still
    -- draws an uncategorized buff on a container whose only other Show holds no ids.
    assertEqual(#plan.groups, 1)
    assertEqual(plan.groups[1].label, "Uncategorized")
    assertTrue(plan.groups[1].candidateFilters.excludeSpellIDs[RENEWING_MIST_AURA],
        "the categorized union is what it draws around")
end)

test("categories: a user DEBUFF category alone on Show compiles the same way, and warns about hostility", function()
    local E = freshEnv()
    local key = E.Categories.CreateUserCategory("Theirs", "HARMFUL")
    E.SetByPath("categorySpells", { [key] = { [118] = true } })
    local con = onlyShown(E, userContainer(E, "target", "HARMFUL"), key)

    local plan = E.FilterCompiler.Compile(con, E.FilterCompiler.ProfileContext())
    assertEqual(#plan.groups, 1, "the aura type is not what decides a user category's group")
    assertEqual(plan.groups[1].filter, "HARMFUL")
    assertEqual(setOf(plan.groups[1].candidateFilters.includeSpellIDs), "118")
    -- The engine honors debuff ids only while the unit is hostile, and `usesSpellIds` is set by the
    -- user category's own Show: the sentence has to reach a container whose only spell list is one
    -- the player made.
    assertTrue(hasWarning(plan, "hostile"), "the identity warning fires for a user category too")
end)

test("categories: a user category shown beside a shipped one gets its own group, after it and minus its ids", function()
    local E = freshEnv()
    local key = E.Categories.CreateUserCategory("Mine", "HELPFUL")
    E.SetByPath("categorySpells", { [key] = { [RENEWING_MIST_AURA] = true, [987654] = true } })
    local con = userContainer(E, "player", "HELPFUL")
    for _, def in ipairs(E.Categories.For("HELPFUL")) do
        con.filter.categories[def.key] = (def.key == key or def.key == "healing") and "show" or "hide"
    end

    local plan = E.FilterCompiler.Compile(con, E.FilterCompiler.ProfileContext())
    assertEqual(#plan.groups, 2, "one group per shown category, user or shipped")
    -- Declaration order: a user category is materialized ahead of Uncategorized and behind every
    -- shipped row (Cat.SyncUserCategories' userInsertIndex), so the shipped group comes first.
    assertEqual(plan.groups[1].label, "Healing")
    assertEqual(plan.groups[2].label, "Mine")
    assertTrue(plan.groups[1].candidateFilters.includeSpellIDs[RENEWING_MIST_AURA],
        "the shipped list claims the aura id")
    -- R-4's dedup runs on a user category like any other: an aura in both is drawn under the FIRST
    -- shown category, so the later group subtracts the earlier one's ids.
    assertTrue(plan.groups[2].candidateFilters.excludeSpellIDs[RENEWING_MIST_AURA],
        "and the user group excludes what the earlier shown group already draws")
    assertTrue(plan.groups[2].candidateFilters.includeSpellIDs[987654], "its own id still includes")
end)
