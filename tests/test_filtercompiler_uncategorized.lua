-- tests/test_filtercompiler_uncategorized.lua — modules/FilterCompiler.lua: the Uncategorized rows, on
-- buffs and debuffs, and FC.ExplainSpell's account of them. Peeled out of tests/test_filtercompiler.lua
-- by theme.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil
local NS = T.NS
local FC = NS.FilterCompiler

local function cfg(over)
    local c = NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE)
    return NS.Database.Merge(c, over or {})
end

local function compile(over, ctx) return FC.Compile(cfg(over), ctx) end

local H = dofile("tests/filtercompiler_helpers.lua")
local setOf, hasWarning, categoryGroups = H.setOf, H.hasWarning, H.categoryGroups
local function only(...) return H.only(NS, ...) end
local function onlyPlus(...) return H.onlyPlus(NS, ...) end

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
    assertEqual(#categoryGroups(plan), 1, "only the ordinary catch-all — Uncategorized contributes nothing")
    assertEqual(plan.groups[1].label, "All")
    assertEqual(plan.groups[1].filter, "HARMFUL|!CROWD_CONTROL",
        "the catch-all still excludes crowdControl, exactly as if Uncategorized did not exist")
end)

test("filter: Uncategorized Hide on a debuff container reproduces the retired 'Only these categories' toggle exactly", function()
    local plan = compile({ auraType = "HARMFUL",
        filter = { categories = { crowdControl = "show", uncategorizedDebuffs = "hide" } } },
        { categories = only("HARMFUL", { "crowdControl", "uncategorizedDebuffs" }) })
    assertEqual(#categoryGroups(plan), 1, "only the explicitly shown category — no catch-all")
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
-- `FC.IdsMode`: are the ids this group is made of CERTAIN to be applied? The owner's
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

test("filter: FC.IdsMode \"always\" is the CERTAIN gate — only for buffs on the player and pet", function()
    -- The gate `addCategoryGroups` and `explainUncategorized`'s caller both read. Every target/focus
    -- cell is false however common the friendly-target or hostile-target case is in play: hostility
    -- is dynamic and the plan is compiled long before anyone looks at the unit, so "usually honored"
    -- is not a thing a group whose ONLY constraint is a spell-id filter can be built on. HARMFUL on
    -- player/pet is false for the blunter reason that ids are never applied there at all.
    local function always(unit, auraType) return FC.IdsMode(unit, auraType) == "always" end
    assertTrue(always("player", "HELPFUL"), "your own buffs: nothing can make you hostile")
    assertTrue(always("pet", "HELPFUL"), "your pet's buffs: same")
    assertTrue(not always("target", "HELPFUL"), "a target may be hostile: only conditional")
    assertTrue(not always("focus", "HELPFUL"), "a focus may be hostile: only conditional")
    assertTrue(not always("player", "HARMFUL"), "your own debuffs: never honored")
    assertTrue(not always("pet", "HARMFUL"), "your pet's debuffs: never honored")
    assertTrue(not always("target", "HARMFUL"), "a target may be FRIENDLY: only conditional")
    assertTrue(not always("focus", "HARMFUL"), "a focus may be FRIENDLY: only conditional")
    -- The two predicates differ in exactly the four target/focus cells and never the other way
    -- round: CERTAIN implies CAN-EVER. ONE predicate answering both questions is what produced the
    -- contradiction the ruling ends — target/HARMFUL counted as honored (a group the engine discards
    -- the moment the target is friendly) and target/HELPFUL as not honored, the same conditionality
    -- treated two opposite ways in one function.
    for _, unit in ipairs({ "player", "pet", "target", "focus" }) do
        for _, auraType in ipairs({ "HELPFUL", "HARMFUL" }) do
            local label = auraType .. " on " .. unit
            if always(unit, auraType) then
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
    -- the union test cannot see. `FC.IdsMode` is what shuts it.
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
    assertEqual(#categoryGroups(plan), 2)
    assertEqual(plan.groups[1].label, "CC Loss of Control")
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
    -- what `FC.IdsMode` refuses; `FC.IdsHonored` (true here) is for the warning, not this.
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
    assertEqual(#categoryGroups(plan), 2)
    assertEqual(plan.groups[1].label, "CC Loss of Control")
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
    assertEqual(#categoryGroups(plan), 2)
    assertEqual(plan.groups[1].label, "Defensive cooldowns")
    assertEqual(plan.groups[2].label, "All")
    assertEqual(plan.groups[2].filter, "HELPFUL|!CANCELABLE")
end)

test("filter: a target debuff container still warns about units you can assist although the gate dropped its Show group", function()
    -- The two predicates are split, and this is where the split is visible in one compile: the GATE
    -- (`IdsMode`, not "always" here) contributed no Uncategorized group, while the WARNING
    -- (`IdsHonored`, true here) still prints the conditional sentence, because the container's OTHER
    -- spell-id constraints — Hard CC's own `includeSpellIDs` — are real and do bite while the
    -- target is hostile. Telling the player "spell lists do nothing here" would be a lie; dropping
    -- the warning to match the gate would be the drift the rewrite exists to prevent.
    local hostile = compile({ auraType = "HARMFUL", unit = "target",
        filter = { categories = { crowdControl = "hide" } } },
        { categories = onlyPlus("HARMFUL", { "crowdControl", "uncategorizedDebuffs" }, HARMFUL_SPELLS_DEF) })
    assertTrue(hasWarning(hostile, "On units you can assist"), "ids are honored here, but only while the unit is hostile")
    for _, g in ipairs(hostile.groups) do
        assertTrue(g.label ~= "Uncategorized", "the gate is stricter than the warning, deliberately")
    end
    local own = compile({ auraType = "HARMFUL", unit = "player",
        filter = { categories = { crowdControl = "hide" } } },
        { categories = onlyPlus("HARMFUL", { "crowdControl", "uncategorizedDebuffs" }, HARMFUL_SPELLS_DEF) })
    assertTrue(hasWarning(own, "your pet's debuffs"), "ids are discarded here, and the plan says so")
end)

test("filter: a TARGET debuff container's spells-kind Show emits its ids-view group, whose blizzard view is NEVER, and warns (the issue #11 residual, superseded)", function()
    -- Issue #11 (owner, 2026-09-20) accepted this group as a RESIDUAL: its only constraint beyond the
    -- HARMFUL token is an `includeSpellIDs` of the category's list, and on a target the engine MAY
    -- skip exactly that, so on a FRIENDLY target it drew every debuff. The spell-list views
    -- (2026-10-02, docs/superpowers/specs/2026-10-02-spell-list-views-design.md) supersede that
    -- ruling. The ids view still ships the group unchanged, because Hard CC exists to answer "is my
    -- sheep on the target", and on a hostile target the ids DO bite. Where they do not, the container
    -- sends the blizzard or every view, in which this group matches nothing, so the residual cannot
    -- draw.
    local plan = compile({ auraType = "HARMFUL", unit = "target",
        filter = { categories = { crowdControl = "hide" } } },
        { categories = onlyPlus("HARMFUL", { "crowdControl", "uncategorizedDebuffs" }, HARMFUL_SPELLS_DEF) })
    assertEqual(#categoryGroups(plan), 2)
    assertEqual(plan.groups[1].label, "CC Loss of Control", "the Show group is emitted, not suppressed")
    assertEqual(plan.groups[1].filter, "HARMFUL", "nothing but the aura-type token in the string")
    assertEqual(setOf(plan.groups[1].candidateFilters), "includeSpellIDs",
        "in the ids view the id list is its only constraint")
    assertEqual(setOf(plan.groups[1].candidateFilters.includeSpellIDs), HARD_CC_IDS)
    -- red under: the residual still accepted, i.e. a blizzard (formerly no-ids) view that keeps the
    -- group drawing
    local blizzard = plan.groups[1].views and plan.groups[1].views.blizzard
    assertEqual(blizzard and blizzard.filter, "HARMFUL", "the blizzard view keeps the group's aura type")
    assertEqual(FC.Signature(blizzard and blizzard.candidateFilters), "{includeDispelTypes={}}",
        "and matches nothing: where ids are skipped, this group cannot degenerate")
    assertEqual(plan.groups[2].label, "All")
    assertEqual(plan.groups[2].filter, "HARMFUL|!CROWD_CONTROL", "the Hide still compiles in the ids view")
    -- And the player is told, per container: `finishWarnings` prints `IDS_ASSISTABLE` because a
    -- category is Hidden.
    assertEqual(#plan.warnings, 1, "exactly the one sentence")
    assertEqual(plan.warnings[1], FC.WARN.IDS_ASSISTABLE,
        "the Hidden crowdControl category raises the warning (#hidden > 0), with no blacklist or whitelist in play")
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
    -- gates on the same `FC.IdsMode`. Without it, issue #11's categories would make
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
    -- `FC.IdsMode` the compiler gates on, so on a target it must report the same "the row
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
        { "target", "HELPFUL", FC.WARN.IDS_UNASSISTABLE_LISTS },
        { "focus",  "HELPFUL", FC.WARN.IDS_UNASSISTABLE_LISTS },
        { "player", "HARMFUL", FC.WARN.IDS_OWN_DEBUFFS_LISTS },
        { "pet",    "HARMFUL", FC.WARN.IDS_OWN_DEBUFFS_LISTS },
        { "target", "HARMFUL", FC.WARN.IDS_ASSISTABLE_LISTS },
        { "focus",  "HARMFUL", FC.WARN.IDS_ASSISTABLE_LISTS },
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
