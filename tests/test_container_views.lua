-- tests/test_container_views.lua — which view of its plan a live container sends (spell-list views,
-- V2 of docs/superpowers/specs/2026-10-02-spell-list-views-design.md): `ContainerClass:ApplyView`,
-- and Build and Update on the ACTIVE view.
--
-- Where Blizzard will not apply spell ids (NS.Compat.IdsApply), a container sends each group's
-- blizzard view (modules/FilterViews.lua) instead of the ids view, so spell-list groups match nothing
-- rather than all becoming the same group. The switch is two live setters per group, sent only where
-- the two views differ, and it runs in combat and while auras are secret: it never goes through
-- ContainerManager's apply hold. The wiring (SV-03): a target or focus swap switches the view before
-- the refresh, and UNIT_FACTION / UNIT_FLAGS on ContainerManager's view frame switch it without a swap.
--
-- Every container here stores both Situations settings as "blizzard" (BLIZZARD_ONLY), so its no-ids
-- view is the blizzard view these cases are about; the every view and the choice between the two are
-- tests/test_container_situations.lua's (filter situations, S2).

local T = _G.AM_TEST
local spyConsole = dofile("tests/console_spy.lua")
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")

local BLIZZARD_ONLY = { npcs = "blizzard", players = "blizzard" }

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
--- group in the blizzard view. Answers NS, mocks, the instance and its engine.
local function targetBuffs(assistable)
    local NS, mocks = fresh()
    mocks.__canAssist.target = assistable
    local id = NS.ContainerManager.Create({ unit = "target", auraType = "HELPFUL", filter = {
        maxDuration = 30, categories = states(NS, "HELPFUL", { defensives = true, bigDefensive = true }),
        situations = BLIZZARD_ONLY,
    } })
    mocks.__fireTimers()
    local inst = NS.ContainerManager.instances[id]
    return NS, mocks, inst, inst.engine
end

--- The `view` values of group `g`: its filter string and candidate filters.
local function valuesOf(g, view)
    local v = (view ~= "ids" and g.views[view]) or g
    return v.filter, v.candidateFilters
end

--- How many groups of `plan` differ between the two views in filter string, and in candidates.
local function differing(NS, plan)
    local Sig = NS.FilterCompiler.Signature
    local filters, cands = 0, 0
    for _, g in ipairs(plan.groups) do
        local f1, c1 = valuesOf(g, "ids")
        local f2, c2 = valuesOf(g, "blizzard")
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
    assertEqual(inst.view, "blizzard")
    assertEqual(#inst.plan.groups, 3, "one spell-list group, one Blizzard group, the remainder")
    assertBuiltOn(NS, inst, "blizzard")
    local NS2, _, inst2 = targetBuffs(true)
    -- red under: Build sending the blizzard view unconditionally
    assertEqual(inst2.view, "ids")
    assertBuiltOn(NS2, inst2, "ids")
end)

test("container views: player debuffs are always built on the blizzard view, player buffs on the ids view", function()
    local NS, mocks = fresh()
    -- Blizzard never applies ids to your own debuffs and always to your own buffs, whatever the
    -- unit APIs say: FC.IdsMode decides those two outright. Both IdsApply clauses answer false for
    -- player and pet buffs here (neither assistable nor player-controlled), so only the "always"
    -- shortcut can put a buff container on the ids view.
    mocks.__canAssist.player, mocks.__canAssist.pet = false, false
    mocks.__playerControlled.player, mocks.__playerControlled.pet = false, false
    assertFalse(NS.Compat.IdsApply("player", "HELPFUL"), "IdsApply alone would pick the blizzard view")
    local deb = NS.ContainerManager.Create({ unit = "player", auraType = "HARMFUL", filter = {
        categories = states(NS, "HARMFUL", { hardCC = true, crowdControl = true }), situations = BLIZZARD_ONLY,
    } })
    local buf = NS.ContainerManager.Create({ unit = "player", auraType = "HELPFUL", filter = {
        categories = states(NS, "HELPFUL", { defensives = true, bigDefensive = true }),
    } })
    local petBuf = NS.ContainerManager.Create({ unit = "pet", auraType = "HELPFUL", filter = {
        categories = states(NS, "HELPFUL", { defensives = true, bigDefensive = true }),
    } })
    mocks.__fireTimers()
    local CM = NS.ContainerManager
    -- red under: a "never" container answered from IdsApply (UnitCanAssist false reads "applies")
    assertEqual(CM.instances[deb].view, "blizzard")
    assertBuiltOn(NS, CM.instances[deb], "blizzard")
    -- red under: an "always" container answered from IdsApply (the player and the pet are neither
    -- assistable nor player-controlled here)
    assertEqual(CM.instances[buf].view, "ids")
    assertBuiltOn(NS, CM.instances[buf], "ids")
    assertEqual(CM.instances[petBuf].view, "ids", "the pet's buffs too")
    mocks.__canAssist.player, mocks.__playerControlled.player = true, true
    assertFalse(CM.instances[deb]:ApplyView(), "nothing moves a never container")
    mocks.__canAssist.player, mocks.__playerControlled.player = false, false
    assertFalse(CM.instances[buf]:ApplyView(), "nothing moves an always container")
    assertFalse(CM.instances[petBuf]:ApplyView(), "nor the pet's")
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
    assertEqual(inst.view, "blizzard")
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
    -- duration; its NEVER blizzard candidates do not, so only the Blizzard group is re-sent)
    assertEqual(#cands, 1)
    assertEqual(cands[1][2], inst.plan.groups[2].key)
    assertEqual(Sig(cands[1][3]), Sig(inst.plan.groups[2].views.blizzard.candidateFilters))
    assertEqual(cands[1][3].maxDuration, 20)
    assertEqual(inst.view, "blizzard")
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
    assertEqual(lines[2], "[Filter] " .. name
        .. ": spell lists off, only Blizzard categories set to Show (NPC; unit cannot be assisted)")
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

-- ── wiring: when ApplyView runs (V2, SV-03) ──────────────────────────────────────────────────

--- The registrations on ContainerManager's view frame (or `frameKey`), as `kind:event:unit`, sorted.
local function viewRegs(mocks, NS, frameKey)
    local out = {}
    for _, r in ipairs(mocks.__registrations()) do
        if r.target ~= nil and r.target == NS.ContainerManager[frameKey or "viewFrame"] then
            out[#out + 1] = r.kind .. ":" .. tostring(r.event) .. ":" .. tostring(r.unit)
        end
    end
    table.sort(out)
    return table.concat(out, " | ")
end

local VIEW_REGS = "unit:UNIT_FACTION:focus | unit:UNIT_FACTION:target | unit:UNIT_FLAGS:focus | unit:UNIT_FLAGS:target"
local PLAYER_REGS = "unit:UNIT_FACTION:player | unit:UNIT_FLAGS:player"

test("container views: a target swap switches the view BEFORE it refreshes the engine", function()
    local _, mocks, inst, e = targetBuffs(false)
    e.__calls = {}
    mocks.__canAssist.target = true
    mocks.__fireEvent("PLAYER_TARGET_CHANGED")
    -- red under: OnUnitSwap refreshing without ApplyView (the new target keeps the old one's view)
    assertEqual(inst.view, "ids")
    local set, refresh = e:__firstCall("SetAuraGroupCandidateFilters"), e:__firstCall("UpdateAllAuras")
    assertTrue(set ~= nil and refresh ~= nil, "both the switch and the refresh were sent")
    -- red under: ApplyView after RefreshUnit (one UpdateAllAuras draws the new target in the old view)
    assertTrue(set < refresh, "the switch precedes the refresh")
end)

test("container views: a focus swap moves focus containers only", function()
    local _, mocks, inst = targetBuffs(false)
    mocks.__canAssist.target = true
    mocks.__fireEvent("PLAYER_FOCUS_CHANGED")
    -- red under: OnUnitSwap applying the view on every container, whatever its unit
    assertEqual(inst.view, "blizzard", "the target container waits for its own swap")
end)

test("container views: UNIT_FACTION and UNIT_FLAGS on the target and focus switch the view without a swap", function()
    local NS, mocks, inst, e = targetBuffs(false)
    -- red under: no unit-event registration on ContainerManager's view frame
    assertEqual(viewRegs(mocks, NS), VIEW_REGS)
    mocks.__canAssist.target = true
    mocks.__fire("UNIT_FLAGS", "focus")
    -- red under: the handler ignoring its unit (a focus flag change switching a target container)
    assertEqual(inst.view, "blizzard")
    e.__calls = {}
    mocks.__fire("UNIT_FLAGS", "target")
    -- red under: UNIT_FLAGS not wired to ApplyView (a duel starting mid-target)
    assertEqual(inst.view, "ids")
    assertEqual(#e:__callsTo("UpdateAllAuras"), 0, "the setters redraw; no extra refresh")
    mocks.__canAssist.target = false
    mocks.__fire("UNIT_FACTION", "target")
    -- red under: UNIT_FACTION not wired (an NPC turning hostile)
    assertEqual(inst.view, "blizzard")
end)

test("container views: a secret unit token from a unit event switches nothing and raises nothing", function()
    local secretUnit = false
    local NS, mocks = fresh({ before = function(m)
        m.issecretvalue = function(v) return secretUnit and v == "target" end
    end })
    mocks.__canAssist.target = false
    local id = NS.ContainerManager.Create({ unit = "target", auraType = "HELPFUL", filter = {
        categories = states(NS, "HELPFUL", { defensives = true, bigDefensive = true }), situations = BLIZZARD_ONLY,
    } })
    mocks.__fireTimers()
    local inst = NS.ContainerManager.instances[id]
    assertEqual(inst.view, "blizzard")
    mocks.__canAssist.target = true
    secretUnit = true
    -- red under: the unit compared before NS.Secrets.IsSafeKey proves it a safe key
    mocks.__fire("UNIT_FLAGS", "target")
    assertEqual(inst.view, "blizzard")
    secretUnit = false
    mocks.__fire("UNIT_FLAGS", "target")
    assertEqual(inst.view, "ids", "a readable token still switches")
end)

test("container views: the view frame's unit events go down with the addon and come back with it", function()
    local NS, mocks = targetBuffs(false)
    assertEqual(viewRegs(mocks, NS), VIEW_REGS)
    assertEqual(viewRegs(mocks, NS, "viewPlayerFrame"), PLAYER_REGS)
    NS.SetByPath("enabled", false)
    -- red under: CM.StopListening leaving the view frame registered (a frame AceEvent never reaches)
    assertEqual(viewRegs(mocks, NS), "")
    assertEqual(viewRegs(mocks, NS, "viewPlayerFrame"), "")
    NS.SetByPath("enabled", true)
    -- red under: CM.StartListening not re-opening the view frame on the stand-up
    assertEqual(viewRegs(mocks, NS), VIEW_REGS)
    assertEqual(viewRegs(mocks, NS, "viewPlayerFrame"), PLAYER_REGS)
end)

test("container views: UNIT_FACTION and UNIT_FLAGS on the player move target and focus views", function()
    -- Mind control: the charmed player takes the charmer's side, so whether the player can assist the
    -- target moves while only the PLAYER's faction and flags change.
    local NS, mocks, inst = targetBuffs(false)
    -- red under: no registration for the player (RegisterUnitEvent takes two units, so its own frame)
    assertEqual(viewRegs(mocks, NS, "viewPlayerFrame"), PLAYER_REGS)
    local moved = 0
    NS.EmptyWatch.OnViewsMoved = function() moved = moved + 1 end
    mocks.__canAssist.target = true
    mocks.__fire("UNIT_FLAGS", "player")
    -- red under: the player's own reaction change not re-resolving the target's view
    assertEqual(inst.view, "ids")
    assertEqual(moved, 1, "EmptyWatch re-predicts once")
    mocks.__canAssist.target = false
    mocks.__fire("UNIT_FACTION", "player")
    assertEqual(inst.view, "blizzard")
    mocks.__fire("UNIT_FACTION", "player")
    assertEqual(moved, 2, "nothing moved, no re-prediction")
end)

test("container views: the stand-up moves the view before it re-enables, in combat too", function()
    local NS, mocks, inst, e = targetBuffs(true)
    assertEqual(inst.view, "ids")
    NS.SetByPath("enabled", false)
    -- While stood down nothing hears the swap: the new target cannot be assisted.
    mocks.__canAssist.target = false
    mocks.__fireEvent("PLAYER_TARGET_CHANGED")
    assertEqual(inst.view, "ids", "no view move while stood down")
    mocks.__lockdown, mocks.__aurasSecret = true, true
    e.__calls = {}
    NS.SetByPath("enabled", true)
    assertTrue(NS.ContainerManager.MustDefer(), "the apply is held")
    -- red under: a stand-up that re-enables the engine on the view it held at stand-down (every
    -- spell-list group drawing every buff of a hostile target until the hold lifts)
    assertEqual(inst.view, "blizzard")
    local never
    for _, c in ipairs(e:__callsTo("SetAuraGroupCandidateFilters")) do
        if NS.FilterCompiler.Signature(c[3]) == "{includeDispelTypes={}}" then never = true end
    end
    assertTrue(never, "the NEVER candidate filters were sent")
    local set, enable = e:__firstCall("SetAuraGroupCandidateFilters"), e:__firstCall("SetEnabled")
    -- red under: the views moved after the visibility pass (one draw of the new target in the old view)
    assertTrue(set ~= nil and enable ~= nil and set < enable, "the switch precedes the re-enable")
end)

test("container views: a refused setter leaves the view stale, and the next switch resends it in full", function()
    local _, mocks, inst, engine = targetBuffs(false)
    assertEqual(inst.view, "blizzard")
    local real = engine.SetAuraGroupCandidateFilters
    engine.SetAuraGroupCandidateFilters = function() error("refused") end
    mocks.__canAssist.target = true
    inst:ApplyView()
    -- red under: ApplyView recording the switch as done although the engine refused a setter (the
    -- diagnostics would name a view the engine does not hold)
    assertTrue(inst.viewStale == true, "a refused setter marks the view stale")
    engine.SetAuraGroupCandidateFilters = real
    local before = #engine:__callsTo("SetAuraGroupCandidateFilters")
    inst:ApplyView()
    -- red under: the retry sending only the values that differ between the views, or nothing at all
    -- because the view already reads "ids"
    assertEqual(#engine:__callsTo("SetAuraGroupCandidateFilters") - before, #inst.plan.groups,
        "every group resent")
    assertTrue(not inst.viewStale, "a clean resend clears the mark")
    assertEqual(inst.view, "ids")
end)

test("container views: a refused filter-string setter is resent for every group at the next switch", function()
    local _, mocks, inst, engine = targetBuffs(false)
    -- Both setters refused: here the two views share every filter string, so the switch itself sends
    -- none, and only the stale retry must send them all.
    local realF, realC = engine.SetAuraGroupFilterString, engine.SetAuraGroupCandidateFilters
    engine.SetAuraGroupFilterString = function() error("refused") end
    engine.SetAuraGroupCandidateFilters = function() error("refused") end
    mocks.__canAssist.target = true
    inst:ApplyView()
    assertTrue(inst.viewStale == true)
    engine.SetAuraGroupFilterString, engine.SetAuraGroupCandidateFilters = realF, realC
    local before = #engine:__callsTo("SetAuraGroupFilterString")
    inst:ApplyView()
    -- red under: the retry resending a filter string only where the two views differ (none here)
    assertEqual(#engine:__callsTo("SetAuraGroupFilterString") - before, #inst.plan.groups,
        "every group's filter string resent")
    assertTrue(not inst.viewStale)
end)

test("container views: an Update whose setter is refused leaves the view stale, and the next Update resends in full", function()
    local NS, mocks, inst, engine = targetBuffs(false)
    local real = engine.SetAuraGroupCandidateFilters
    engine.SetAuraGroupCandidateFilters = function() error("refused") end
    NS.SetByPath("container.filter.maxDuration", 20, inst.id)
    mocks.__fireTimers()
    -- red under: Update clearing (or never setting) the mark after a refused setter
    assertTrue(inst.viewStale == true, "a refused setter during an update marks the view stale")
    engine.SetAuraGroupCandidateFilters = real
    local before = #engine:__callsTo("SetAuraGroupCandidateFilters")
    NS.SetByPath("container.filter.sortDirection", "reverse", inst.id)
    mocks.__fireTimers()
    -- red under: Update sending only what differs while the view is stale (a sort change sends no
    -- candidate filters at all)
    assertEqual(#engine:__callsTo("SetAuraGroupCandidateFilters") - before, #inst.plan.groups,
        "every group resent")
    assertTrue(not inst.viewStale, "a clean resend clears the mark")
end)

test("container views: a rebuilt engine starts clean, not stale, and a same-view switch then sends nothing", function()
    local NS, mocks, inst, engine = targetBuffs(false)
    engine.SetAuraGroupCandidateFilters = function() error("refused") end
    mocks.__canAssist.target = true
    inst:ApplyView()
    assertTrue(inst.viewStale == true)
    -- Showing one more category changes the plan's structure, so the engine is retired and rebuilt.
    NS.SetByPath("container.filter.categories.activeMitigation", "show", inst.id)
    mocks.__fireTimers()
    assertTrue(inst.engine ~= engine, "a new engine was built")
    -- red under: Build leaving the old engine's stale mark on the new one
    assertTrue(not inst.viewStale, "a fresh engine holds a known view")
    local fresh = inst.engine
    local before = #fresh:__callsTo("SetAuraGroupCandidateFilters")
    assertFalse(inst:ApplyView(), "the same view: no switch")
    assertEqual(#fresh:__callsTo("SetAuraGroupCandidateFilters"), before, "nothing resent")
end)
