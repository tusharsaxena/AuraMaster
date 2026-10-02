-- tests/test_filterviews_situations.lua — the third view of a compiled plan, "every", and the trailing
-- remainder slot it draws through (filter situations, SI-01: S1 of
-- docs/superpowers/specs/2026-10-02-filter-situations-design.md).
--
-- Every group now carries `views = { blizzard, every }` beside its own (ids) fields. Where Blizzard
-- will not apply spell ids, a container sends either the Blizzard view (only the Blizzard categories
-- set to Show draw, as master does) or the every view (every aura once, minus the Blizzard, Dispel and
-- Who Cast It categories set to Hide). An R-4 plan on a unit whose ids are not always applied gains
-- one trailing group that is NEVER in the ids and Blizzard views and is the whole every view.
--
-- The no-duplicate proof is a brute force over Blizzard's own candidate-filter rules
-- (AuraContainerUtil.DoesAuraPassCandidateFilters, ported below): every aura is drawn by at most one
-- group in each view, and the every view draws exactly the auras its definition names.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil
local NS = T.NS
local FC = NS.FilterCompiler

local H = dofile("tests/filtercompiler_helpers.lua")
local setOf = H.setOf

local NEVER_CAND = "{includeDispelTypes={}}"

local function cfg(over)
    local c = NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE)
    return NS.Database.Merge(c, over or {})
end

local function compile(over, ctx) return FC.Compile(cfg(over), ctx) end

--- Group `g`'s filter string and candidate filters in `view`, read the way the container reads them.
local function viewOf(g, view)
    local v = (view ~= "ids" and g.views and g.views[view]) or g
    return v.filter, v.candidateFilters
end

local function isNeverIn(g, view)
    local f, c = viewOf(g, view)
    return f == g.filter and FC.Signature(c) == NEVER_CAND
end

local function last(plan) return plan.groups[#plan.groups] end

--- Every category of `auraType` set to Hide except `shown`.
local function hideAllBut(auraType, shown)
    local states = {}
    for _, def in ipairs(NS.Categories.For(auraType)) do
        states[def.key] = shown[def.key] and "show" or "hide"
    end
    return states
end

-- ── the remainder slot's shape ───────────────────────────────────────────────────────────────

test("situations: an R-4 target buff plan ends in a remainder slot, NEVER in the ids and blizzard views", function()
    -- red under: master, where the plan has no `views` and no trailing slot.
    local plan = compile({ unit = "target", auraType = "HELPFUL", filter = { maxDuration = 30, castBy = "mine",
        categories = { important = "hide", defensives = "hide", cancelable = "hide" } } })
    local r = last(plan)
    assertTrue(r.remainder == true, "the last group is the remainder")
    assertEqual(r.label, "Every aura")
    assertTrue(isNeverIn(r, "ids"), "ids view: NEVER")
    assertTrue(isNeverIn(r, "blizzard"), "blizzard view: NEVER")
    local f, c = viewOf(r, "every")
    assertEqual(f, "HELPFUL|PLAYER|!IMPORTANT|!CANCELABLE", "the base minus each Hidden Blizzard token")
    assertEqual(r.filter, f, "one filter string in all three views, so a switch sends candidates only")
    assertEqual(FC.Signature(c), "{maxDuration=number:30}", "a spell category's Hide does not reach it")
    for i = 1, #plan.groups - 1 do
        assertTrue(isNeverIn(plan.groups[i], "every"), plan.groups[i].label .. " is NEVER in the every view")
    end
end)

test("situations: the remainder slot exists only for R-4 on units whose ids are not always applied", function()
    -- red under: a remainder on an R-3 plan or on player/pet buffs (each would rebuild a container
    -- for nothing), or none on target, focus or player/pet debuffs.
    local hideBuff, hideDebuff = { important = "hide" }, { crowdControl = "hide" }
    local cases = {
        { "target", "HELPFUL", hideBuff, true }, { "focus", "HELPFUL", hideBuff, true },
        { "target", "HARMFUL", hideDebuff, true }, { "focus", "HARMFUL", hideDebuff, true },
        { "player", "HARMFUL", hideDebuff, true }, { "pet", "HARMFUL", hideDebuff, true },
        { "player", "HELPFUL", hideBuff, false }, { "pet", "HELPFUL", hideBuff, false },
        { "target", "HELPFUL", {}, false }, { "player", "HARMFUL", {}, false },
    }
    for _, c in ipairs(cases) do
        local plan = compile({ unit = c[1], auraType = c[2], filter = { categories = c[3] } })
        local has = false
        for _, g in ipairs(plan.groups) do has = has or (g.remainder == true) end
        assertEqual(has, c[4], c[2] .. " on " .. c[1] .. (next(c[3]) and " (R-4)" or " (R-3)"))
    end
end)

test("situations: an R-3 plan's every view is its blizzard view", function()
    -- red under: an every view on R-3 that is NEVER, or that differs from the Blizzard view.
    local plan = compile({ unit = "target", auraType = "HELPFUL", filter = {
        maxDuration = 20, blacklist = { [300] = true }, whitelist = { [100] = true } } })
    assertEqual(#plan.groups, 2)
    for _, g in ipairs(plan.groups) do
        local bf, bc = viewOf(g, "blizzard")
        local ef, ec = viewOf(g, "every")
        assertEqual(ef, bf, g.label)
        assertEqual(FC.Signature(ec), FC.Signature(bc), g.label)
        assertTrue(g.views.every ~= g.views.blizzard, "a table per view, never one shared")
    end
    assertTrue(isNeverIn(plan.groups[1], "every"), "the whitelist group")
    assertEqual(setOf(select(2, viewOf(plan.groups[2], "every")).excludeSpellIDs), "300", "only the blacklist")
end)

test("situations: a player buff plan (ids always applied) is unchanged, every reading as blizzard", function()
    -- red under: master (no `views` table), a remainder slot, or an every view that differs from the
    -- Blizzard view, on player buffs.
    local plan = compile({ unit = "player", auraType = "HELPFUL", filter = { categories = { important = "hide" } } })
    for _, g in ipairs(plan.groups) do
        assertNil(g.remainder, g.label)
        assertTrue(g.views ~= nil and g.views.every ~= nil, g.label .. " carries the every view")
        local bf, bc = viewOf(g, "blizzard")
        local ef, ec = viewOf(g, "every")
        assertEqual(ef, bf, g.label)
        assertEqual(FC.Signature(ec), FC.Signature(bc), g.label)
    end
end)

test("situations: the remainder subtracts Hidden Dispel Types and one Hidden Who Cast It row", function()
    -- red under: a remainder built from the Blizzard grid's kinds alone (token, flag), missing dispel
    -- and the Who Cast It flag.
    local plan = compile({ unit = "player", auraType = "HARMFUL", filter = {
        categories = { magic = "hide", poison = "hide", boss = "hide", fromNonPlayers = "hide", hardCC = "hide" } } })
    local f, c = viewOf(last(plan), "every")
    assertEqual(f, "HARMFUL")
    assertEqual(setOf(c), "excludeDispelTypes,isBossAura,isFromPlayerOrPlayerPet")
    assertEqual(setOf(c.excludeDispelTypes), "Magic,Poison")
    assertEqual(c.isBossAura, false)
    assertEqual(c.isFromPlayerOrPlayerPet, true, "From non-players Hidden: only player-cast debuffs remain")
end)

test("situations: both Who Cast It rows Hidden make the remainder NEVER in every view", function()
    -- red under: dropping the conflicting remainder (the plan's group count, and so its structure,
    -- would then follow a Who row), or drawing through it.
    local plan = compile({ unit = "target", auraType = "HARMFUL", filter = {
        categories = { fromPlayers = "hide", fromNonPlayers = "hide" } } })
    local r = last(plan)
    assertTrue(r.remainder == true, "the slot stays")
    assertEqual(r.filter, "HARMFUL")
    assertTrue(isNeverIn(r, "ids") and isNeverIn(r, "blizzard") and isNeverIn(r, "every"))
end)

test("situations: a remainder that cannot draw leaves the every view equal to the blizzard view", function()
    -- red under: every earlier group made NEVER in the every view even when the remainder is NEVER
    -- too (SI-06): the every view then draws nothing, less than the blizzard view, on a timeless buff
    -- container or one with both Who rows Hidden.
    local cases = {
        { "timeless buffs", { unit = "target", auraType = "HELPFUL", filter = { durationMode = "timeless",
            categories = { important = "hide" } } } },
        { "both Who rows Hidden", { unit = "target", auraType = "HARMFUL", filter = {
            categories = { fromPlayers = "hide", fromNonPlayers = "hide" } } } },
    }
    for _, c in ipairs(cases) do
        local plan = compile(c[2], { timedSpells = { [7] = true } })
        assertTrue(isNeverIn(last(plan), "every"), c[1] .. ": the remainder is NEVER")
        local live = 0
        for i = 1, #plan.groups - 1 do
            local g = plan.groups[i]
            local bf, bc = viewOf(g, "blizzard")
            local ef, ec = viewOf(g, "every")
            assertEqual(ef, bf, c[1] .. ": " .. g.label)
            assertEqual(FC.Signature(ec), FC.Signature(bc), c[1] .. ": " .. g.label)
            assertTrue(g.views.every ~= g.views.blizzard, "a table per view, never one shared")
            if not isNeverIn(g, "every") then live = live + 1 end
        end
        if c[1] == "timeless buffs" then
            assertTrue(live > 0, c[1] .. ": the Blizzard Show groups still draw in the every view")
        end
    end
end)

test("situations: 'Without a duration' makes the remainder NEVER in the every view (buffs)", function()
    -- red under: an every view drawing every timed buff on a hostile target: Timeless is built from
    -- spell ids, which Blizzard drops there.
    local plan = compile({ unit = "target", auraType = "HELPFUL", filter = { durationMode = "timeless",
        categories = { important = "hide" } } }, { timedSpells = { [7] = true } })
    assertTrue(isNeverIn(last(plan), "every"))
    -- On debuffs the mode is ignored ("shows every duration", FC.WARN.TIMELESS_BUFFS_ONLY), so it
    -- does not blank the remainder there.
    local deb = compile({ unit = "target", auraType = "HARMFUL", filter = { durationMode = "timeless",
        categories = { crowdControl = "hide" } } })
    assertTrue(not isNeverIn(last(deb), "every"), "debuffs: the mode means nothing, the remainder draws")
end)

test("situations: the remainder keeps the blacklist and ignores the whitelist and spell categories", function()
    -- red under: the remainder excluding the whitelist (a whitelisted NeverSecret aura hidden while
    -- its own group is NEVER) or a Hidden spell category's ids.
    local plan = compile({ unit = "target", auraType = "HELPFUL", filter = {
        whitelist = { [100] = true }, blacklist = { [300] = true },
        categories = { defensives = "hide", uncategorized = "hide", important = "show", castable = "hide" } } })
    local f, c = viewOf(last(plan), "every")
    assertEqual(f, "HELPFUL|!RAID")
    assertEqual(setOf(c), "excludeSpellIDs")
    assertEqual(setOf(c.excludeSpellIDs), "300")
    assertTrue(isNeverIn(plan.groups[1], "every"), "Always shown")
end)

test("situations: the warnings and NEVER_MATCHES ignore the remainder slot", function()
    -- red under: counting the remainder as a group, which would stop a target container that hides
    -- every category from saying it can never match anything (its ids and Blizzard views draw nothing).
    local plan = compile({ unit = "target", auraType = "HELPFUL",
        filter = { categories = hideAllBut("HELPFUL", {}) } })
    assertEqual(#plan.groups, 1, "only the remainder")
    assertTrue(H.hasWarning(plan, FC.WARN.NEVER_MATCHES), "the ids and Blizzard views draw nothing")
end)

-- ── the owner's container ────────────────────────────────────────────────────────────────────

test("situations: the owner's 'Target Bar CD (All)' draws only the remainder in the every view", function()
    -- red under: no remainder (the every view would draw nothing), or a remainder that keeps a spell
    -- list or misses a Hidden Blizzard row.
    local shown = { defensives = true, activeMitigation = true, raidCDs = true, offensiveCDs = true,
        support = true, movement = true, utility = true }
    local plan = compile({ unit = "target", auraType = "HELPFUL", filter = {
        categories = hideAllBut("HELPFUL", shown), durationMode = "timed", maxDuration = 30 } })
    assertEqual(#plan.groups, 8, "seven spell-list groups and the remainder")
    assertEqual(FC.StructureKey(plan), "8:-")
    for i = 1, 7 do
        assertTrue(isNeverIn(plan.groups[i], "blizzard"), plan.groups[i].label)
        assertTrue(isNeverIn(plan.groups[i], "every"), plan.groups[i].label)
    end
    local f, c = viewOf(plan.groups[8], "every")
    assertEqual(f, "HELPFUL|!BIG_DEFENSIVE|!EXTERNAL_DEFENSIVE|!IMPORTANT|!RAID|!CANCELABLE")
    assertEqual(FC.Signature(c), "{isStealable=boolean:false,maxDuration=number:30}")
end)

test("situations: every container of the owner's real profile keeps master's ids and blizzard views", function()
    -- red under: any change to a group master compiled, in either view, or an extra group that is
    -- anything but a remainder NEVER in both (tests/situations_owner_profile.lua records master).
    local F = dofile("tests/situations_owner_profile.lua")
    local now = F.render(NS)
    local plans = {}
    local ctx = F.ctx()
    for _, c in ipairs(F.profile.containers) do plans[c.id] = FC.Compile(c, ctx) end
    local checked, grew = 0, {}
    for _, c in ipairs(F.profile.containers) do
        local was, is = F.master[c.id], now[c.id]
        assertTrue(was ~= nil, "recorded: #" .. c.id)
        for i, g in ipairs(was) do
            local label = "#" .. c.id .. " " .. c.name .. " group " .. i
            for _, field in ipairs({ "label", "filter", "cand", "bFilter", "bCand" }) do
                assertEqual(is[i] and is[i][field], g[field], label .. " " .. field)
            end
            checked = checked + 1
        end
        for i = #was + 1, #is do
            local g = plans[c.id].groups[i]
            assertTrue(g.remainder == true, "#" .. c.id .. ": only a remainder may be added")
            assertTrue(isNeverIn(g, "ids") and isNeverIn(g, "blizzard"), "#" .. c.id .. ": NEVER in both")
            grew[#grew + 1] = c.id
        end
        assertTrue(#is - #was <= 1, "#" .. c.id .. ": at most one slot added")
    end
    assertEqual(checked, 42, "every group master compiled for the profile")
    assertEqual(table.concat(grew, ","), "18,22,27,28,29",
        "the R-4 target containers gain the remainder; player buffs and the R-3 containers do not")
    -- "Target Bar CC (All)" Hides both Who Cast It rows: its remainder draws nothing in any view, so
    -- its every view is its blizzard view (SI-06), never an empty container.
    assertTrue(isNeverIn(last(plans[18]), "every"), "#18: both Who rows Hidden")
    for i = 1, #plans[18].groups - 1 do
        local g = plans[18].groups[i]
        assertEqual(FC.Signature(select(2, viewOf(g, "every"))), FC.Signature(select(2, viewOf(g, "blizzard"))),
            "#18 " .. g.label .. ": every reads as blizzard")
    end
    assertTrue(not isNeverIn(last(plans[22]), "every"), "#22: the remainder draws in the every view")
end)

-- ── no duplicates, brute force ───────────────────────────────────────────────────────────────

--- A deterministic LCG, so a failure is reproducible on every platform.
local function rng(seed)
    local s = seed
    return function(n)
        s = (s * 1103515245 + 12345) % 2147483648
        return (s % n) + 1
    end
end

local TOKENS = {
    HELPFUL = { "BIG_DEFENSIVE", "EXTERNAL_DEFENSIVE", "IMPORTANT", "RAID", "CANCELABLE", "PLAYER" },
    HARMFUL = { "CROWD_CONTROL", "RAID", "RAID_IN_COMBAT", "RAID_PLAYER_DISPELLABLE", "DISPELLABLE", "PLAYER" },
}
local FLAGS = { "isStealable", "isBossAura", "isRoleAura", "isPriorityAura", "isFromPlayerOrPlayerPet" }
local DISPELS = { false, "Magic", "Curse", "Disease", "Poison", "Bleed" }
local DURATIONS = { 0, 10, 60 }

--- One random aura of `auraType`: its tokens, flags, dispel type, duration, spell id, NeverSecret.
local function randomAura(r, auraType, idPool)
    local a = { tokens = { [auraType] = true }, duration = DURATIONS[r(3)], spellId = idPool[r(#idPool)],
        neverSecret = r(6) == 1 }
    for _, t in ipairs(TOKENS[auraType]) do a.tokens[t] = r(2) == 1 end
    for _, f in ipairs(FLAGS) do a[f] = r(2) == 1 end
    local d = DISPELS[r(#DISPELS)]
    a.dispelName = d or nil
    return a
end

local function passesString(a, filter)
    for tok in filter:gmatch("[^|]+") do
        local neg = tok:sub(1, 1) == "!"
        local name = neg and tok:sub(2) or tok
        if (a.tokens[name] and true or false) == neg then return false end
    end
    return true
end

--- The spell-id half of Blizzard's DoesAuraPassCandidateFilters: applied in the ids view, and to a
--- NeverSecret aura in every view (CanApplyIdentityCandidateFilters answers true for it first).
local function passesIds(a, c, idsApplied)
    if not (idsApplied or a.neverSecret) then return true end
    if c.excludeSpellIDs and c.excludeSpellIDs[a.spellId] then return false end
    return not (c.includeSpellIDs and not c.includeSpellIDs[a.spellId])
end

--- The dispel-type half.
local function passesDispel(a, c)
    if c.excludeDispelTypes and a.dispelName and c.excludeDispelTypes[a.dispelName] then return false end
    return not (c.includeDispelTypes and not (a.dispelName and c.includeDispelTypes[a.dispelName]))
end

--- Blizzard's DoesAuraPassCandidateFilters, for the fields this compiler emits.
local function passesCand(a, c, idsApplied)
    if c == nil then return true end
    if not (passesIds(a, c, idsApplied) and passesDispel(a, c)) then return false end
    for _, f in ipairs(FLAGS) do
        if c[f] ~= nil and a[f] ~= c[f] then return false end
    end
    return not (c.maxDuration ~= nil and (a.duration > c.maxDuration or a.duration == 0))
end

local function drawCount(plan, a, view)
    local n = 0
    for _, g in ipairs(plan.groups) do
        local f, c = viewOf(g, view)
        if passesString(a, f) and passesCand(a, c, view == "ids") then n = n + 1 end
    end
    return n
end

local BLIZZARD_GRID = { token = true, flag = true, dispel = true }

--- Whether `a` is in category `def` (token, flag or dispel kinds).
local function inCategory(a, def)
    if def.kind == "token" then return a.tokens[def.token] and true or false end
    if def.kind == "flag" then return a[def.field] == def.value end
    return (a.dispelName and def.types[a.dispelName]) and true or false
end

--- Whether `a` passes the base: Cast by, the max duration, and the blacklist where Blizzard still
--- applies it (a NeverSecret aura; the whitelist takes an id off the blacklist).
local function passesBase(a, filter)
    if filter.castBy == "mine" and not a.tokens.PLAYER then return false end
    if filter.castBy == "others" and a.tokens.PLAYER then return false end
    local max = filter.maxDuration or 0
    if max > 0 and (a.duration > max or a.duration == 0) then return false end
    return not (a.neverSecret and filter.blacklist[a.spellId] and not filter.whitelist[a.spellId])
end

--- What the every view must draw: an aura passing the base that is in no Blizzard-grid category set
--- to Hide. Where the remainder cannot draw (both Who rows Hidden, or "Without a duration" on buffs),
--- the every view is the blizzard view (SI-06): `blizzard` is that view's count for the aura.
local function everyExpected(a, filter, auraType, blizzard)
    local who = 0
    for _, def in ipairs(NS.Categories.For(auraType)) do
        if filter.categories[def.key] == "hide" and def.field == "isFromPlayerOrPlayerPet" then who = who + 1 end
    end
    if who == 2 or (auraType == "HELPFUL" and filter.durationMode == "timeless") then return blizzard end
    if not passesBase(a, filter) then return 0 end
    for _, def in ipairs(NS.Categories.For(auraType)) do
        if filter.categories[def.key] == "hide" and BLIZZARD_GRID[def.kind] and inCategory(a, def) then return 0 end
    end
    return 1
end

local function randomFilter(r, auraType, idPool)
    local states = {}
    for _, def in ipairs(NS.Categories.For(auraType)) do
        states[def.key] = (r(3) == 1) and "hide" or "show"
    end
    local castBy = ({ "any", "mine", "others" })[r(3)]
    return { categories = states, castBy = castBy, maxDuration = ({ 0, 30 })[r(2)],
        durationMode = (r(4) == 1) and "timeless" or "any",
        whitelist = (r(3) == 1) and { [idPool[r(#idPool)]] = true } or {},
        blacklist = (r(3) == 1) and { [idPool[r(#idPool)]] = true } or {} }
end

--- One listed id per spells-kind category of `auraType`, and one id on no list.
local function idPoolOf(auraType)
    local pool = { 999999001 }
    for _, def in ipairs(NS.Categories.For(auraType)) do
        if def.kind == "spells" then
            local lowest
            for id in pairs(def.spells or {}) do
                if not lowest or id < lowest then lowest = id end
            end
            if lowest then pool[#pool + 1] = lowest end
        end
    end
    return pool
end

test("situations: no aura is drawn twice in any view, and the every view draws exactly its definition", function()
    -- red under: a remainder that overlaps a group still drawing in the every view, an every view
    -- missing a Hidden Dispel or Who row, a remainder drawing where it must be NEVER, or an every view
    -- that draws less than the blizzard view where the remainder cannot draw (SI-06).
    local r = rng(20261002)
    local units = { { "target", "HELPFUL" }, { "focus", "HELPFUL" }, { "target", "HARMFUL" },
        { "player", "HARMFUL" }, { "player", "HELPFUL" } }
    local configs, auras = 0, 0
    for _, u in ipairs(units) do
        local unit, auraType = u[1], u[2]
        local pool = idPoolOf(auraType)
        for _ = 1, 24 do
            local filter = randomFilter(r, auraType, pool)
            local plan = compile({ unit = unit, auraType = auraType, filter = filter })
            local remainder = last(plan) and last(plan).remainder
            configs = configs + 1
            for _ = 1, 120 do
                local a = randomAura(r, auraType, pool)
                local where = auraType .. " on " .. unit .. " #" .. configs
                assertTrue(drawCount(plan, a, "ids") <= 1, where .. ": ids view draws twice")
                local blizzard = drawCount(plan, a, "blizzard")
                assertTrue(blizzard <= 1, where .. ": blizzard view draws twice")
                local every = drawCount(plan, a, "every")
                assertTrue(every <= 1, where .. ": every view draws twice")
                if remainder then
                    assertEqual(every, everyExpected(a, filter, auraType, blizzard), where .. ": every view coverage")
                end
                auras = auras + 1
            end
        end
    end
    assertEqual(configs, 120)
    assertTrue(auras > 0)
end)
