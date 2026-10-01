-- tests/test_container_views.lua — which view of its plan a live container sends (spell-list views,
-- V2 of docs/superpowers/specs/2026-10-02-spell-list-views-design.md): `ContainerClass:ApplyView`,
-- and Build and Update on the ACTIVE view.
--
-- Where Blizzard will not apply spell ids (NS.Compat.IdsApply), a container sends each group's
-- no-ids view (modules/FilterViews.lua) instead of the ids view, so spell-list groups match nothing
-- rather than all becoming the same group. The switch is two live setters per group, sent only where
-- the two views differ, and it runs in combat and while auras are secret: it never goes through
-- ContainerManager's apply hold.

local T = _G.AM_TEST
local spyConsole = dofile("tests/console_spy.lua")
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")

--- Every category of `auraType` Hidden but the keys in `shown`.
local function states(NS, auraType, shown)
    local out = {}
    for _, def in ipairs(NS.Categories.For(auraType)) do
        out[def.key] = shown[def.key] and "show" or "hide"
    end
    return out
end

--- A target buff container showing one spell category (Defensive cooldowns) and one Blizzard
--- category (Big defensives), everything else Hidden, 30 s max: one NEVER group and one stripped
--- group in the no-ids view. Answers NS, mocks, the instance and its engine.
local function targetBuffs(assistable)
    local NS, mocks = fresh()
    mocks.__canAssist.target = assistable
    local id = NS.ContainerManager.Create({ unit = "target", auraType = "HELPFUL", filter = {
        maxDuration = 30, categories = states(NS, "HELPFUL", { defensives = true, bigDefensive = true }),
    } })
    mocks.__fireTimers()
    local inst = NS.ContainerManager.instances[id]
    return NS, mocks, inst, inst.engine
end

--- The `view` values of group `g`: its filter string and candidate filters.
local function valuesOf(g, view)
    if view == "noIds" then return g.noIds.filter, g.noIds.candidateFilters end
    return g.filter, g.candidateFilters
end

--- How many groups of `plan` differ between the two views in filter string, and in candidates.
local function differing(NS, plan)
    local Sig = NS.FilterCompiler.Signature
    local filters, cands = 0, 0
    for _, g in ipairs(plan.groups) do
        local f1, c1 = valuesOf(g, "ids")
        local f2, c2 = valuesOf(g, "noIds")
        if f1 ~= f2 then filters = filters + 1 end
        if Sig(c1) ~= Sig(c2) then cands = cands + 1 end
    end
    return filters, cands
end

--- Assert that AddAuraGroup sent every group's `view` values.
local function assertBuiltOn(NS, inst, view)
    local Sig = NS.FilterCompiler.Signature
    local adds = inst.engine:__callsTo("AddAuraGroup")
    assertEqual(#adds, #inst.plan.groups)
    for i, g in ipairs(inst.plan.groups) do
        local f, c = valuesOf(g, view)
        assertEqual(adds[i][3], f, "group " .. i .. "'s filter string")
        assertEqual(Sig(adds[i][4].candidateFilters), Sig(c), "group " .. i .. " (" .. g.label .. ")'s candidates")
    end
end

-- ── Build on the active view ─────────────────────────────────────────────────────────────────

test("container views: a target buff container is built on the view its unit's reaction picks", function()
    local NS, _, inst = targetBuffs(false)
    -- red under: Build sending the ids view whatever the unit (the 14 Brutal Slams bars)
    assertEqual(inst.view, "noIds")
    assertEqual(#inst.plan.groups, 2, "one spell-list group, one Blizzard group")
    assertBuiltOn(NS, inst, "noIds")
    local NS2, _, inst2 = targetBuffs(true)
    -- red under: Build sending the no-ids view unconditionally
    assertEqual(inst2.view, "ids")
    assertBuiltOn(NS2, inst2, "ids")
end)

test("container views: player debuffs are always built on the no-ids view, player buffs on the ids view", function()
    local NS, mocks = fresh()
    -- Blizzard never applies ids to your own debuffs and always to your own buffs, whatever the
    -- unit APIs say: FC.IdsMode decides those two outright.
    mocks.__canAssist.player = false
    local deb = NS.ContainerManager.Create({ unit = "player", auraType = "HARMFUL", filter = {
        categories = states(NS, "HARMFUL", { hardCC = true, crowdControl = true }),
    } })
    local buf = NS.ContainerManager.Create({ unit = "player", auraType = "HELPFUL", filter = {
        categories = states(NS, "HELPFUL", { defensives = true, bigDefensive = true }),
    } })
    mocks.__fireTimers()
    local CM = NS.ContainerManager
    -- red under: a "never" container answered from IdsApply (UnitCanAssist false reads "applies")
    assertEqual(CM.instances[deb].view, "noIds")
    assertBuiltOn(NS, CM.instances[deb], "noIds")
    -- red under: an "always" container answered from IdsApply (the player is not assistable here)
    assertEqual(CM.instances[buf].view, "ids")
    assertBuiltOn(NS, CM.instances[buf], "ids")
    mocks.__canAssist.player = true
    assertFalse(CM.instances[deb]:ApplyView(), "nothing moves a never container")
    assertFalse(CM.instances[buf]:ApplyView(), "nothing moves an always container")
end)

-- ── ApplyView ────────────────────────────────────────────────────────────────────────────────

test("container views: ApplyView switches in place, sending only what differs, and nothing when unchanged", function()
    local NS, mocks, inst, e = targetBuffs(false)
    local Sig = NS.FilterCompiler.Signature
    local wantF, wantC = differing(NS, inst.plan)
    assertTrue(wantC > 0, "the two views differ in candidates")
    -- red under: ApplyView sending a setter when the view has not changed
    assertFalse(inst:ApplyView(), "the target still cannot be assisted")
    assertEqual(#e:__callsTo("SetAuraGroupCandidateFilters"), 0)
    mocks.__canAssist.target = true
    -- red under: no ApplyView
    assertTrue(inst:ApplyView())
    assertTrue(inst.engine == e, "a view switch never rebuilds")
    assertEqual(inst.view, "ids")
    local cands = e:__callsTo("SetAuraGroupCandidateFilters")
    -- red under: sending both setters for every group, differing or not
    assertEqual(#cands, wantC)
    assertEqual(#e:__callsTo("SetAuraGroupFilterString"), wantF)
    for _, c in ipairs(cands) do
        local g
        for _, x in ipairs(inst.plan.groups) do if x.key == c[2] then g = x end end
        assertEqual(Sig(c[3]), Sig(g.candidateFilters), "the ids view's candidates")
    end
    assertFalse(inst:ApplyView(), "unchanged again")
    assertEqual(#e:__callsTo("SetAuraGroupCandidateFilters"), wantC)
    mocks.__canAssist.target = false
    assertTrue(inst:ApplyView())
    assertEqual(inst.view, "noIds")
    assertEqual(#e:__callsTo("SetAuraGroupCandidateFilters"), 2 * wantC)
end)

test("container views: the switch runs in combat and while auras are secret", function()
    local NS, mocks, inst, e = targetBuffs(false)
    local _, wantC = differing(NS, inst.plan)
    mocks.__aurasSecret, mocks.__lockdown = true, true
    mocks.__canAssist.target = true
    -- red under: ApplyView held behind ContainerManager's apply gate (CM.MustDefer)
    assertTrue(inst:ApplyView())
    assertEqual(#e:__callsTo("SetAuraGroupCandidateFilters"), wantC)
    assertEqual(inst.view, "ids")
end)

-- ── Update on the active view ────────────────────────────────────────────────────────────────

test("container views: an in-place update compares and sends the active view's values", function()
    local NS, mocks, inst, e = targetBuffs(false)
    local Sig = NS.FilterCompiler.Signature
    NS.SetByPath("container.filter.maxDuration", 20, inst.id)
    mocks.__fireTimers()
    assertTrue(inst.engine == e, "a live-editable change")
    local cands = e:__callsTo("SetAuraGroupCandidateFilters")
    -- red under: Update diffing the ids view (the spell-list group's ids candidates carry the max
    -- duration; its NEVER no-ids candidates do not, so only the Blizzard group is re-sent)
    assertEqual(#cands, 1)
    assertEqual(cands[1][2], inst.plan.groups[2].key)
    assertEqual(Sig(cands[1][3]), Sig(inst.plan.groups[2].noIds.candidateFilters))
    assertEqual(cands[1][3].maxDuration, 20)
    assertEqual(inst.view, "noIds")
end)

test("container views: an update that finds the reaction changed sends the new view's values", function()
    local NS, mocks, inst, e = targetBuffs(false)
    local Sig = NS.FilterCompiler.Signature
    mocks.__canAssist.target = true
    NS.SetByPath("container.filter.maxDuration", 20, inst.id)
    mocks.__fireTimers()
    -- red under: Update keeping the view it was built on
    assertEqual(inst.view, "ids")
    local cands = e:__callsTo("SetAuraGroupCandidateFilters")
    assertEqual(#cands, 2, "both groups moved: new view and new max duration")
    for i, c in ipairs(cands) do
        assertEqual(Sig(c[3]), Sig(inst.plan.groups[i].candidateFilters))
    end
    assertFalse(inst:ApplyView(), "the update already switched it")
end)

test("container views: an update that leaves the plan's view values alone still sends the view switch", function()
    local NS, mocks, inst, e = targetBuffs(false)
    local Sig = NS.FilterCompiler.Signature
    local wantF, wantC = differing(NS, inst.plan)
    assertTrue(wantC > 0, "the two views differ in candidates")
    mocks.__canAssist.target = true
    -- A live edit that moves neither view's values: only the reaction makes the engine's values stale.
    NS.SetByPath("container.filter.sortDirection", "reverse", inst.id)
    mocks.__fireTimers()
    assertTrue(inst.engine == e, "a live-editable change")
    assertEqual(inst.view, "ids")
    -- red under: Update diffing the old plan in the NEW view (`sendGroupView(engine, g, view, o, view)`):
    -- the ids values match themselves, so nothing is sent while self.view still records "ids"
    local cands = e:__callsTo("SetAuraGroupCandidateFilters")
    assertEqual(#cands, wantC)
    assertEqual(#e:__callsTo("SetAuraGroupFilterString"), wantF)
    for _, c in ipairs(cands) do
        local g
        for _, x in ipairs(inst.plan.groups) do if x.key == c[2] then g = x end end
        assertEqual(Sig(c[3]), Sig(g.candidateFilters), "the ids view's candidates")
    end
    for _, c in ipairs(e:__callsTo("SetAuraGroupFilterString")) do
        local g
        for _, x in ipairs(inst.plan.groups) do if x.key == c[2] then g = x end end
        assertEqual(c[3], g.filter, "the ids view's filter string")
    end
    assertFalse(inst:ApplyView(), "the update already switched it")
end)

-- ── the log ──────────────────────────────────────────────────────────────────────────────────

--- Logging on, and every line of the tags in `tags` recorded as `[Tag] text`.
local function record(NS, tags)
    NS.State.debug = true
    local lines = {}
    spyConsole(NS, function(tag, fmt, ...)
        if not tags[tag] then return end
        local n, args = select("#", ...), { ... }
        for i = 1, n do args[i] = tostring(args[i]) end
        lines[#lines + 1] = "[" .. tag .. "] " .. fmt:format(unpack(args, 1, n))
    end)
    return lines
end

test("container views: a view change writes one [Filter] line, and an unchanged view none", function()
    local NS, mocks, inst = targetBuffs(false)
    local lines = record(NS, { Filter = true })
    local name = NS.Database.FindContainer(inst.id).name
    inst:ApplyView()
    -- red under: a line on every ApplyView, changed or not (it runs on every target swap)
    assertEqual(#lines, 0)
    mocks.__canAssist.target = true
    inst:ApplyView()
    inst:ApplyView()
    -- red under: no [Filter] line on a view change
    assertEqual(#lines, 1, table.concat(lines, " | "))
    assertEqual(lines[1], "[Filter] " .. name .. ": spell lists on (unit can be assisted)")
    -- A live edit with the reaction unchanged: Update calls NoteView on every apply.
    NS.SetByPath("container.filter.maxDuration", 20, inst.id)
    mocks.__fireTimers()
    -- red under: NoteView logging without its `was == view` early return (a line on every live edit)
    assertEqual(#lines, 1, table.concat(lines, " | "))
    mocks.__canAssist.target = false
    inst:ApplyView()
    assertEqual(lines[2], "[Filter] " .. name .. ": spell lists off (unit cannot be assisted)")
end)

test("container views: a setter the engine refuses is caught, and logged once", function()
    local NS, mocks, inst, e = targetBuffs(false)
    local lines = record(NS, { Engine = true })
    e.SetAuraGroupCandidateFilters = function() error("candidateFilters refused") end
    for _ = 1, 3 do
        mocks.__canAssist.target = not mocks.__canAssist.target
        -- red under: a setter called outside callEngine (the error escapes ApplyView)
        assertTrue(inst:ApplyView())
    end
    assertEqual(#lines, 1, table.concat(lines, " | "))
    assertTrue(lines[1]:find("SetAuraGroupCandidateFilters failed", 1, true) ~= nil, lines[1])
end)
