-- tests/test_filterviews.lua — the ids and blizzard views of one compiled plan (spell-list views, V1
-- and V4 of docs/superpowers/specs/2026-10-02-spell-list-views-design.md): `FC.IdsMode`, each group's
-- blizzard view (`views.blizzard`, modules/FilterViews.lua; the no-ids view until filter situations),
-- and the reworded identity warnings. The every view and the remainder slot are
-- tests/test_filterviews_situations.lua's.
--
-- Blizzard applies include/exclude spell ids only where `AuraContainerUtil.
-- CanApplyIdentityCandidateFilters` passes. Where it does not, every group whose only distinguishing
-- constraint is a spell list degenerates into "every aura of this type", and seven such groups draw
-- the same aura seven times. The blizzard view is what a container sends there instead: NEVER for every
-- group built on spell ids, and the Blizzard-category groups with their ids stripped.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil
local NS = T.NS
local FC = NS.FilterCompiler

local H = dofile("tests/filtercompiler_helpers.lua")
local setOf = H.setOf

local function cfg(over)
    local c = NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE)
    return NS.Database.Merge(c, over or {})
end

local function compile(over, ctx) return FC.Compile(cfg(over), ctx) end

--- A `ctx.categories` stub over the real shipped defs, narrowed to `keys`, declaration order kept
--- (the same narrowing tests/test_filtercompiler.lua's `only` does).
local function only(auraType, keys)
    local want = {}
    for _, k in ipairs(keys) do want[k] = true end
    local out = {}
    for _, def in ipairs(NS.Categories.For(auraType)) do
        if want[def.key] then out[#out + 1] = def end
    end
    return { For = function() return out end }
end

--- The NEVER view, rendered: the group's own filter string, and an empty include-dispel map that
--- fails every aura, typed or not (`DoesAuraPassCandidateFilters`).
local NEVER_CAND = "{includeDispelTypes={}}"

local function isNever(group)
    local b = group.views and group.views.blizzard
    return b ~= nil and b.filter == group.filter and FC.Signature(b.candidateFilters) == NEVER_CAND
end

-- ── FC.IdsMode ─────────────────────────────────────────────────────────────────────────────────

test("views: FC.IdsMode is always for player/pet buffs, never for player/pet debuffs, dynamic elsewhere", function()
    -- red under: FC.IdsMode missing (it replaces FC.IdsAlwaysHonored as the gate).
    local expected = {
        { "player", "HELPFUL", "always" }, { "pet", "HELPFUL", "always" },
        { "target", "HELPFUL", "dynamic" }, { "focus", "HELPFUL", "dynamic" },
        { "player", "HARMFUL", "never" }, { "pet", "HARMFUL", "never" },
        { "target", "HARMFUL", "dynamic" }, { "focus", "HARMFUL", "dynamic" },
    }
    for _, c in ipairs(expected) do
        assertEqual(FC.IdsMode(c[1], c[2]), c[3], c[2] .. " on " .. c[1])
    end
    assertNil(FC.IdsAlwaysHonored, "the old gate is gone; IdsMode == \"always\" is its one meaning")
end)

-- ── the owner's container, pinned ─────────────────────────────────────────────────────────────

--- "Target Bar CD (All)": target buffs, every Blizzard category Hide, seven spell categories Show,
--- the rest of the spell categories, Weapon enchants and Uncategorized Hide, timed, 30 s max.
local OWNER_SHOWN = { defensives = true, activeMitigation = true, raidCDs = true, offensiveCDs = true,
    support = true, movement = true, utility = true }

local function ownerContainer()
    local states = {}
    for _, def in ipairs(NS.Categories.For("HELPFUL")) do
        states[def.key] = OWNER_SHOWN[def.key] and "show" or "hide"
    end
    return { unit = "target", auraType = "HELPFUL",
        filter = { categories = states, durationMode = "timed", maxDuration = 30 } }
end

test("views: the owner's target container compiles to seven groups, every blizzard view NEVER", function()
    -- red under: Compile leaving the blizzard view off its groups. Seven groups differing ONLY in their
    -- spell ids are the 14 Brutal Slams bars on a hostile NPC; in the blizzard view none may draw.
    local plan = compile(ownerContainer())
    assertEqual(#plan.groups, 8, "one group per shown spell category, no catch-all (Uncategorized is "
        .. "Hidden), then the remainder (filter situations)")
    assertTrue(plan.groups[8].remainder == true, "the remainder is last")
    assertTrue(isNever(plan.groups[8]), "and NEVER in the blizzard view")
    for i = 1, 7 do
        local g = plan.groups[i]
        assertTrue(g.candidateFilters.includeSpellIDs ~= nil, "group " .. i .. " is a spell-list group")
        assertTrue(isNever(g), "group " .. i .. " (" .. g.label .. ") is NEVER without spell ids")
    end
    assertEqual(FC.StructureKey(plan), "8:-", "every view has the same group count")
end)

-- ── the blizzard view of each group kind ───────────────────────────────────────────────────────

test("views: a Blizzard Show group keeps its own constraint and the earlier Blizzard exclusions, and no ids", function()
    -- red under: deriving a token/flag/dispel group's blizzard view as NEVER, or keeping its spell ids.
    local plan = compile({ unit = "target", auraType = "HELPFUL", filter = {
        maxDuration = 30, whitelist = { [100] = true }, blacklist = { [300] = true },
        categories = { bigDefensive = "show", defensives = "show", castable = "show", important = "hide" },
    } }, { categories = only("HELPFUL", { "defensives", "bigDefensive", "important", "castable" }) })
    local byLabel = {}
    for _, g in ipairs(plan.groups) do byLabel[g.label] = g end
    local castable = byLabel["Castable by you"]
    assertEqual(castable.filter, "HELPFUL|RAID|!BIG_DEFENSIVE", "the ids view: its token, minus the earlier token")
    assertTrue(castable.candidateFilters.excludeSpellIDs ~= nil, "the ids view excludes the earlier spell list")
    assertEqual(castable.views.blizzard.filter, "HELPFUL|RAID|!BIG_DEFENSIVE")
    assertEqual(setOf(castable.views.blizzard.candidateFilters), "excludeSpellIDs,maxDuration",
        "blizzard keeps the max duration and the base's own excludes, nothing else of the ids")
    assertEqual(setOf(castable.views.blizzard.candidateFilters.excludeSpellIDs), "300",
        "the blacklist stays; the whitelist and the earlier spell list go")
    assertEqual(castable.views.blizzard.candidateFilters.maxDuration, 30)
    assertEqual(castable.candidateFilters.maxDuration, 30, "the ids view keeps it too")
    local big = byLabel["Big defensives (Blizzard)"]
    assertEqual(big.views.blizzard.filter, "HELPFUL|BIG_DEFENSIVE")
    assertEqual(setOf(big.views.blizzard.candidateFilters), "excludeSpellIDs,maxDuration")
    assertEqual(setOf(big.views.blizzard.candidateFilters.excludeSpellIDs), "300")
end)

-- Blizzard applies `excludeSpellIDs` to a NeverSecret spell (Sated, Exhaustion) on EVERY unit
-- (`CanApplyIdentityCandidateFilters` answers true for it first). So a blizzard view must keep the
-- base's own excludes (the blacklist and Timeless's learned ids), which narrow a group and can never
-- duplicate, and drop only the whitelist's and the earlier spell categories' excludes.

test("views: a blacklisted id stays excluded in every drawing blizzard view once a category is Hidden", function()
    -- red under: stripIds dropping the base's blacklist (a blacklisted Sated, cast by a player and
    -- NeverSecret, drawn on a player debuff container as soon as Boss debuffs is set to Hide).
    local plan = compile({ unit = "player", auraType = "HARMFUL", filter = {
        blacklist = { [57724] = true }, categories = { boss = "hide" } } })
    local drawing = 0
    for _, g in ipairs(plan.groups) do
        if not isNever(g) then
            drawing = drawing + 1
            assertEqual(setOf((g.views.blizzard.candidateFilters or {}).excludeSpellIDs), "57724",
                g.label .. " keeps the blacklist")
            assertNil(g.views.blizzard.candidateFilters.includeSpellIDs, g.label)
        end
    end
    assertTrue(drawing > 0, "some Blizzard Show group draws in the blizzard view")
end)

test("views: Timeless's learned ids stay excluded in a stripped blizzard view", function()
    -- red under: stripIds dropping the base's timed-id excludes along with the dedup ids.
    local plan = compile({ unit = "target", auraType = "HELPFUL", filter = {
        durationMode = "timeless", whitelist = { [100] = true },
        categories = { bigDefensive = "show", defensives = "show", important = "hide" },
    } }, { categories = only("HELPFUL", { "defensives", "bigDefensive", "important" }),
           timedSpells = { [7] = true } })
    local big
    for _, g in ipairs(plan.groups) do
        if g.label == "Big defensives (Blizzard)" then big = g end
    end
    local ids = big.candidateFilters.excludeSpellIDs
    assertTrue(ids[100] and ids[7] and true, "the ids view excludes the whitelist and the learned ids")
    assertEqual(setOf(big.views.blizzard.candidateFilters.excludeSpellIDs), "7")
end)

test("views: a dispel Show group's blizzard view keeps its include map and its earlier flag exclusions", function()
    -- red under: stripping a candidate field that is not a spell-id list.
    local plan = compile({ unit = "target", auraType = "HARMFUL", filter = {
        categories = { magic = "show", boss = "show", crowdControl = "hide" },
    } }, { categories = only("HARMFUL", { "magic", "boss", "crowdControl" }) })
    local magic = plan.groups[2]
    assertEqual(magic.label, "Magic")
    assertEqual(FC.Signature(magic.views.blizzard.candidateFilters), FC.Signature(magic.candidateFilters),
        "nothing to strip: the blizzard view is the ids view")
    assertEqual(setOf(magic.views.blizzard.candidateFilters), "includeDispelTypes,isBossAura")
end)

test("views: the whitelist group and the catch-all are NEVER without spell ids", function()
    -- red under: the remainder (catch-all) or "Always shown" drawing where ids are not applied.
    local plan = compile({ unit = "target", auraType = "HELPFUL", filter = {
        whitelist = { [100] = true }, categories = { bigDefensive = "show", important = "hide" },
    } }, { categories = only("HELPFUL", { "bigDefensive", "important" }) })
    assertEqual(#plan.groups, 4, "the whitelist, the Blizzard Show group, the catch-all, the remainder")
    assertEqual(plan.groups[1].label, "Always shown")
    assertTrue(isNever(plan.groups[1]), "the whitelist is ids only")
    assertEqual(plan.groups[3].label, "All")
    assertTrue(isNever(plan.groups[3]), "the remainder never shows where ids are off")
    assertTrue(not isNever(plan.groups[2]), "the Blizzard Show group still draws")
end)

test("views: a spells-kind Show and an Uncategorized Show group are NEVER without spell ids", function()
    -- red under: an Uncategorized rescue group (player buffs, where it exists) not marked NEVER.
    local plan = compile({ unit = "player", auraType = "HELPFUL", filter = {
        categories = { cancelable = "hide" },
    } }, { categories = only("HELPFUL", { "cancelable", "defensives", "uncategorized" }) })
    assertEqual(#plan.groups, 2)
    assertEqual(plan.groups[2].label, "Uncategorized")
    assertTrue(isNever(plan.groups[1]), "Defensive cooldowns")
    assertTrue(isNever(plan.groups[2]), "Uncategorized")
end)

test("views: with no category Hidden the single group's blizzard view is the ids view minus the whitelist (R-3)", function()
    -- red under: deriving the R-3 group as NEVER, which would blank every default container on a
    -- hostile target.
    local plan = compile({ unit = "target", auraType = "HELPFUL", filter = {
        maxDuration = 20, blacklist = { [300] = true }, whitelist = { [100] = true } } })
    assertEqual(#plan.groups, 2)
    assertTrue(isNever(plan.groups[1]), "the whitelist group")
    local g = plan.groups[2]
    assertEqual(g.label, "All")
    assertEqual(g.views.blizzard.filter, g.filter)
    assertEqual(setOf(g.candidateFilters.excludeSpellIDs), "100,300")
    -- red under: role "same" keeping the whitelist exclude, so a whitelisted NeverSecret aura is
    -- excluded here while its own group is NEVER: "Always shown" acting as "never shown".
    assertEqual(setOf(g.views.blizzard.candidateFilters), "excludeSpellIDs,maxDuration")
    assertEqual(setOf(g.views.blizzard.candidateFilters.excludeSpellIDs), "300", "only the blacklist")
    assertEqual(g.views.blizzard.candidateFilters.maxDuration, 20)
    local noLists = compile({ unit = "target", filter = { maxDuration = 20 } }).groups[1]
    assertEqual(FC.Signature(noLists.views.blizzard.candidateFilters), FC.Signature(noLists.candidateFilters),
        "with no whitelist the two views are the same")
    local bare = compile({ unit = "target" }).groups[1]
    assertEqual(bare.views.blizzard.filter, "HELPFUL")
    assertNil(bare.views.blizzard.candidateFilters, "an unconstrained group stays unconstrained")
end)

test("views: a whitelisted NeverSecret id is not excluded by the R-3 blizzard view (player debuffs)", function()
    -- red under: the R-3 blizzard view keeping the whitelist exclude. Player debuffs are always on the
    -- blizzard view; Blizzard applies Sated's (57724) ids there because it is NeverSecret, so an
    -- exclude of it hides the very aura the player marked "Always shown".
    local plan = compile({ unit = "player", auraType = "HARMFUL", filter = { whitelist = { [57724] = true } } })
    assertEqual(#plan.groups, 2)
    local g = plan.groups[2]
    assertEqual(g.label, "All")
    assertEqual(setOf(g.candidateFilters.excludeSpellIDs), "57724", "the ids view still dedups")
    assertNil((g.views.blizzard.candidateFilters or {}).excludeSpellIDs, "no 57724 exclude in the blizzard view")
end)

test("views: the NEVER view is the group's own filter string and an empty include-dispel map", function()
    -- red under: NEVER built from a different filter string, or carrying the group's other fields.
    local g = compile(ownerContainer()).groups[1]
    assertEqual(g.views.blizzard.filter, g.filter)
    assertEqual(FC.Signature(g.views.blizzard.candidateFilters), NEVER_CAND)
    assertEqual(type(g.views.blizzard.candidateFilters.includeDispelTypes), "table")
    assertNil(next(g.views.blizzard.candidateFilters.includeDispelTypes))
end)

-- ── the reworded warnings (V4) ───────────────────────────────────────────────────────────────

test("views: each mode prints the new sentence where a category is Hidden", function()
    -- red under: the old "Spell lists only apply while the unit is ..." sentences.
    local cases = {
        { "target", "HELPFUL", "On units you can't assist (hostile or neutral), spell categories and Overrides are not applied. Only Blizzard categories set to Show draw." },
        { "focus", "HELPFUL", "On units you can't assist (hostile or neutral), spell categories and Overrides are not applied. Only Blizzard categories set to Show draw." },
        { "target", "HARMFUL", "On units you can assist, spell categories and Overrides are not applied. Only Blizzard categories set to Show draw." },
        { "player", "HARMFUL", "On your own and your pet's debuffs, spell categories and Overrides are not applied. Only Blizzard categories set to Show draw." },
        { "pet", "HARMFUL", "On your own and your pet's debuffs, spell categories and Overrides are not applied. Only Blizzard categories set to Show draw." },
    }
    for _, c in ipairs(cases) do
        local hide = (c[2] == "HELPFUL") and { important = "hide" } or { crowdControl = "hide" }
        local plan = compile({ unit = c[1], auraType = c[2], filter = { categories = hide } })
        assertEqual(#plan.warnings, 1, c[2] .. " on " .. c[1])
        assertEqual(plan.warnings[1], c[3], c[2] .. " on " .. c[1])
    end
end)

test("views: an Overrides list alone raises the Overrides-only sentence", function()
    -- red under: the warning gated on Hidden categories alone.
    local plan = compile({ unit = "target", filter = { whitelist = { [100] = true } } })
    -- red under: the full sentence here. With nothing Hidden the R-3 group draws every buff on a
    -- unit you can't assist, so "Only Blizzard categories set to Show draw" would be false.
    assertEqual(#plan.warnings, 1)
    assertEqual(plan.warnings[1], "On units you can't assist (hostile or neutral), the Overrides lists are not applied.")
    plan = compile({ unit = "target", auraType = "HARMFUL", filter = { blacklist = { [1] = true } } })
    assertEqual(plan.warnings[1], "On units you can assist, the Overrides lists are not applied.")
    plan = compile({ unit = "player", auraType = "HARMFUL", filter = { whitelist = { [57724] = true } } })
    assertEqual(plan.warnings[1], "On your own and your pet's debuffs, the Overrides lists are not applied.")
    plan = compile({ unit = "target", filter = { whitelist = { [100] = true }, categories = { important = "hide" } } })
    assertEqual(plan.warnings[1], FC.WARN.IDS_UNASSISTABLE, "a Hidden category still prints the full sentence")
end)

test("views: no sentence on a container the rule changes nothing for", function()
    -- red under: the old `usesSpellIds` gate, which printed for timeless's learned ids too.
    assertEqual(#compile({ unit = "target" }).warnings, 0, "nothing hidden, no lists")
    local timeless = compile({ unit = "target", filter = { durationMode = "timeless" } },
        { timedSpells = { [7] = true } })
    assertEqual(#timeless.warnings, 0, "timeless's own id exclusion is not a spell category or an Override")
    assertEqual(#compile({ unit = "target", auraType = "HARMFUL" }).warnings, 0)
    assertEqual(#compile({ unit = "player", auraType = "HARMFUL" }).warnings, 0)
    assertEqual(#compile({ unit = "player", filter = { categories = { important = "hide" } } }).warnings, 0,
        "player buffs: ids always apply")
end)
