-- tests/test_container_situations.lua — which view a live container sends where Blizzard won't apply
-- spell lists (filter situations, S2 of docs/superpowers/specs/2026-10-02-filter-situations-design.md):
-- `ContainerClass:ResolveView` choosing ids, blizzard or every from the container's own
-- `filter.situations`, the `view` effect a Situations write takes (CM.ApplyViews for that container at
-- once, in combat too, never held behind the apply hold), and the [Filter] line naming the view and
-- the situation.
--
-- The truth table: IdsMode "always" (player and pet buffs) is ids; "dynamic" with NS.Compat.IdsApply
-- is ids; otherwise player and pet debuff containers follow the Players setting, and target and focus
-- containers follow Players or NPCs by NS.Compat.IsPlayerUnit, the stricter of the two when that is
-- not knowable. "every" picks the every view, "blizzard" the blizzard view.

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

--- A container on `unit` for `auraType` with one Blizzard category Shown and the rest Hidden (an R-4
--- plan, so it carries the remainder slot off "always"), and `situations` stored when given. Answers
--- NS, mocks and the instance.
local function container(unit, auraType, situations, setup)
    local NS, mocks = fresh()
    if setup then setup(mocks) end
    local shown = auraType == "HARMFUL" and { hardCC = true, crowdControl = true }
        or { defensives = true, bigDefensive = true }
    local filter = { categories = states(NS, auraType, shown) }
    filter.situations = situations
    local id = NS.ContainerManager.Create({ unit = unit, auraType = auraType, filter = filter })
    mocks.__fireTimers()
    return NS, mocks, NS.ContainerManager.instances[id]
end

local function hostile(mocks, isPlayer)
    mocks.__canAssist.target = false
    mocks.__isPlayer.target = isPlayer
end

-- ── ResolveView: the truth table ─────────────────────────────────────────────────────────────

test("situations runtime: player and pet buffs are ids whatever the Situations settings say", function()
    for _, unit in ipairs({ "player", "pet" }) do
        local _, mocks, inst = container(unit, "HELPFUL", { npcs = "blizzard", players = "blizzard" })
        mocks.__canAssist[unit], mocks.__playerControlled[unit] = false, false
        -- red under: ResolveView reading a situation before FC.IdsMode's "always"
        assertEqual(inst:ResolveView(unit, "HELPFUL"), "ids", unit)
        assertEqual(inst.view, "ids", unit)
    end
end)

test("situations runtime: a target whose ids apply is ids whatever the Situations settings say", function()
    local _, mocks, inst = container("target", "HELPFUL", { npcs = "blizzard", players = "every" },
        function(m) m.__canAssist.target = true end)
    -- red under: ResolveView choosing a situation before NS.Compat.IdsApply
    assertEqual(inst.view, "ids")
    assertEqual(inst:ResolveView("target", "HELPFUL"), "ids")
    mocks.__isPlayer.target = true
    assertEqual(inst:ResolveView("target", "HELPFUL"), "ids", "a friendly player too")
end)

test("situations runtime: a hostile NPC follows the NPCs setting, a hostile player the Players setting", function()
    local _, mocks, inst = container("target", "HELPFUL", { npcs = "every", players = "blizzard" },
        function(m) hostile(m, false) end)
    -- red under: the two-way resolver (an NPC on the blizzard view whatever the setting)
    assertEqual(inst.view, "every")
    local view, situation = inst:ResolveView("target", "HELPFUL")
    assertEqual(view, "every"); assertEqual(situation, "npcs")
    hostile(mocks, true)
    view, situation = inst:ResolveView("target", "HELPFUL")
    -- red under: NPCs and players read from one setting (UnitIsPlayer never asked)
    assertEqual(view, "blizzard"); assertEqual(situation, "players")
end)

test("situations runtime: both settings at their default draw every aura on a hostile NPC and player", function()
    local _, mocks, inst = container("focus", "HELPFUL", nil, function(m) m.__canAssist.focus = false end)
    -- red under: a missing setting read as "blizzard" (the template default is "every")
    assertEqual(inst.view, "every")
    mocks.__isPlayer.focus = true
    assertEqual((inst:ResolveView("focus", "HELPFUL")), "every")
end)

test("situations runtime: player and pet debuffs follow the Players setting, never the NPCs one", function()
    for _, unit in ipairs({ "player", "pet" }) do
        local _, _, inst = container(unit, "HARMFUL", { npcs = "every", players = "blizzard" })
        local view, situation = inst:ResolveView(unit, "HARMFUL")
        -- red under: the pet's debuffs read from the NPCs setting (UnitIsPlayer("pet") is false)
        assertEqual(view, "blizzard", unit)
        assertEqual(situation, "players", unit)
        assertEqual(inst.view, "blizzard", unit)
        local _, _, inst2 = container(unit, "HARMFUL", { npcs = "blizzard", players = "every" })
        assertEqual(inst2.view, "every", unit .. ": every")
    end
end)

test("situations runtime: an unknowable player-ness picks the stricter of the two settings", function()
    local function boom() error("refused") end
    local _, mocks, inst = container("target", "HELPFUL", { npcs = "every", players = "blizzard" },
        function(m) m.__canAssist.target = false; m.UnitIsPlayer = boom end)
    local view, situation = inst:ResolveView("target", "HELPFUL")
    -- red under: an unknowable answer read as an NPC (every, while the Players setting is stricter)
    assertEqual(view, "blizzard")
    assertEqual(situation, "unknown")
    local _, _, inst2 = container("target", "HELPFUL", { npcs = "blizzard", players = "every" },
        function(m) m.__canAssist.target = false; m.UnitIsPlayer = boom end)
    -- red under: an unknowable answer read as a player
    assertEqual(inst2.view, "blizzard")
    local _, _, inst3 = container("target", "HELPFUL", nil,
        function(m) m.__canAssist.target = false; m.UnitIsPlayer = boom end)
    assertEqual(inst3.view, "every", "both every: every")
    assertTrue(mocks.UnitIsPlayer == boom)
end)

test("situations runtime: a stored value outside the two modes reads as every, the template default", function()
    local NS, mocks, inst = container("target", "HELPFUL", nil, function(m) hostile(m, false) end)
    NS.Database.FindContainer(inst.id).filter.situations.npcs = "garbage"   -- hand-edited data
    -- red under: any value but "every" read as blizzard
    assertEqual((inst:ResolveView("target", "HELPFUL")), "every")
    NS.Database.FindContainer(inst.id).filter.situations = nil
    -- red under: a container with no situations table raising
    assertEqual((inst:ResolveView("target", "HELPFUL")), "every")
    assertTrue(mocks ~= nil)
end)

-- ── Build, Update and ApplyView on the chosen view ───────────────────────────────────────────

test("situations runtime: Build sends the every view's values on a hostile NPC", function()
    local NS, _, inst = container("target", "HELPFUL", nil, function(m) hostile(m, false) end)
    local Sig = NS.FilterCompiler.Signature
    local adds = inst.engine:__callsTo("AddAuraGroup")
    assertEqual(#adds, #inst.plan.groups)
    for i, g in ipairs(inst.plan.groups) do
        local v = g.views.every
        -- red under: Build resolving ids or blizzard only (the every view never sent)
        assertEqual(adds[i][3], v.filter, "group " .. i .. "'s filter string")
        assertEqual(Sig(adds[i][4].candidateFilters), Sig(v.candidateFilters), "group " .. i)
    end
end)

test("situations runtime: a target swap from an NPC to a player with different settings moves the view", function()
    local _, mocks, inst = container("target", "HELPFUL", { npcs = "every", players = "blizzard" },
        function(m) hostile(m, false) end)
    assertEqual(inst.view, "every")
    local e = inst.engine
    e.__calls = {}
    mocks.__isPlayer.target = true
    mocks.__fireEvent("PLAYER_TARGET_CHANGED")
    -- red under: ResolveView ignoring player-ness on a swap
    assertEqual(inst.view, "blizzard")
    local set, refresh = e:__firstCall("SetAuraGroupCandidateFilters"), e:__firstCall("UpdateAllAuras")
    assertTrue(set ~= nil and refresh ~= nil and set < refresh, "the switch precedes the refresh")
end)

test("situations runtime: switching blizzard <-> every sends candidate filters only where they differ", function()
    local NS, mocks, inst = container("target", "HELPFUL", { npcs = "every", players = "blizzard" },
        function(m) hostile(m, false) end)
    local Sig = NS.FilterCompiler.Signature
    local want = 0
    for _, g in ipairs(inst.plan.groups) do
        if Sig(g.views.every.candidateFilters) ~= Sig(g.views.blizzard.candidateFilters) then want = want + 1 end
    end
    assertTrue(want > 0, "the two views differ")
    local e = inst.engine
    e.__calls = {}
    mocks.__isPlayer.target = true
    assertTrue(inst:ApplyView())
    -- red under: ApplyView re-sending every group's values
    assertEqual(#e:__callsTo("SetAuraGroupCandidateFilters"), want)
    e.__calls = {}
    assertFalse(inst:ApplyView(), "nothing moved")
    assertEqual(#e.__calls, 0)
end)

-- ── the `view` effect ────────────────────────────────────────────────────────────────────────

test("situations runtime: a Situations write switches the live engine at once, in combat, with no apply held", function()
    local NS, mocks, inst = container("target", "HELPFUL", nil, function(m) hostile(m, false) end)
    local CM = NS.ContainerManager
    assertEqual(inst.view, "every")
    local e = inst.engine
    mocks.__lockdown, mocks.__aurasSecret = true, true
    assertTrue(CM.MustDefer(), "an apply would be held")
    local chat = {}
    rawset(mocks.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg) chat[#chat + 1] = tostring(msg) end)
    local asked, moved = 0, 0
    local request = CM.RequestApply
    CM.RequestApply = function(...) asked = asked + 1; return request(...) end
    NS.EmptyWatch.OnViewsMoved = function() moved = moved + 1 end
    e.__calls = {}
    assertTrue(NS.SetByPath("container.filter.situations.npcs", "blizzard", inst.id))
    mocks.__fireTimers()
    CM.RequestApply = request
    -- red under: the view effect left as the default re-apply (held until combat ends)
    assertEqual(inst.view, "blizzard", "switched at once")
    assertEqual(asked, 0, "no apply queued")
    assertTrue(#e:__callsTo("SetAuraGroupCandidateFilters") > 0, "the setters were sent")
    assertEqual(#CM.QueueSnapshot().ids, 0, "nothing pending")
    assertEqual(#chat, 0, "no deferral notice: " .. table.concat(chat, " | "))
    assertEqual(moved, 1, "EmptyWatch re-predicts")
end)

test("situations runtime: a Situations write moves only the container it names", function()
    local NS, mocks, inst = container("target", "HELPFUL", nil, function(m) hostile(m, false) end)
    local other = NS.ContainerManager.Create({ unit = "target", auraType = "HELPFUL", filter = {
        categories = states(NS, "HELPFUL", { defensives = true, bigDefensive = true }),
    } })
    mocks.__fireTimers()
    local inst2 = NS.ContainerManager.instances[other]
    assertEqual(inst2.view, "every")
    -- The other container's stored setting asks for blizzard, written past the effect, so a broadcast
    -- ApplyView on it WOULD move it; only the container the write names may move.
    NS.Database.FindContainer(other).filter.situations.npcs = "blizzard"
    assertTrue(NS.SetByPath("container.filter.situations.npcs", "blizzard", inst.id))
    assertEqual(inst.view, "blizzard")
    -- red under: the view effect switching every container on the unit (the other would re-resolve
    -- to its stored "blizzard")
    assertEqual(inst2.view, "every")
end)

test("situations runtime: the stand-up re-resolves a player or pet debuff container's view, apply held", function()
    for _, unit in ipairs({ "player", "pet" }) do
        local NS, mocks, inst = container(unit, "HARMFUL")
        assertEqual(inst.view, "every", unit)
        NS.SetByPath("enabled", false)
        -- Stood down: CONFIG_CHANGED is not heard, so the write reaches no view effect.
        NS.SetByPath("container.filter.situations.players", "blizzard", inst.id)
        assertEqual(inst.view, "every", unit .. ": no view move while stood down")
        mocks.__lockdown, mocks.__aurasSecret = true, true
        NS.SetByPath("enabled", true)
        assertTrue(NS.ContainerManager.MustDefer(), "the apply is held")
        -- red under: a stand-up that re-resolves target and focus only (the player or pet debuff
        -- container keeps the stale every view until the held apply runs)
        assertEqual(inst.view, "blizzard", unit)
    end
end)

test("situations runtime: a Situations write on a container on the ids view moves nothing", function()
    local NS, _, inst = container("target", "HELPFUL", nil, function(m) m.__canAssist.target = true end)
    local e = inst.engine
    e.__calls = {}
    assertTrue(NS.SetByPath("container.filter.situations.npcs", "blizzard", inst.id))
    assertEqual(inst.view, "ids")
    -- red under: a view effect that re-sends values when the view has not moved
    assertEqual(#e:__callsTo("SetAuraGroupCandidateFilters"), 0)
    assertEqual(#e:__callsTo("SetAuraGroupFilterString"), 0)
end)

-- ── the log ──────────────────────────────────────────────────────────────────────────────────

--- Logging on, and every [Filter] line recorded as `[Filter] text`.
local function record(NS)
    NS.State.debug = true
    local lines = {}
    spyConsole(NS, function(tag, fmt, ...)
        if tag ~= "Filter" then return end
        local n, args = select("#", ...), { ... }
        for i = 1, n do args[i] = tostring(args[i]) end
        lines[#lines + 1] = "[" .. tag .. "] " .. fmt:format(unpack(args, 1, n))
    end)
    return lines
end

test("situations runtime: the [Filter] line names the view and the situation", function()
    local NS, mocks, inst = container("target", "HELPFUL", { npcs = "every", players = "blizzard" },
        function(m) m.__canAssist.target = true end)
    local lines = record(NS)
    local name = NS.Database.FindContainer(inst.id).name
    hostile(mocks, false)
    inst:ApplyView()
    -- red under: the two-way line ("spell lists off (unit cannot be assisted)") naming neither
    assertEqual(lines[1], "[Filter] " .. name .. ": spell lists off, every aura (NPC; unit cannot be assisted)")
    mocks.__isPlayer.target = true
    inst:ApplyView()
    assertEqual(lines[2], "[Filter] " .. name
        .. ": spell lists off, only Blizzard categories set to Show (player; unit cannot be assisted)")
    mocks.UnitIsPlayer = function() error("refused") end
    -- Both settings every now: the stricter of the two is every, written by the view effect itself.
    NS.SetByPath("container.filter.situations.players", "every", inst.id)
    assertEqual(#lines, 3, table.concat(lines, " | "))
    -- red under: an unknowable side named as an NPC or a player
    assertEqual(lines[3], "[Filter] " .. name
        .. ": spell lists off, every aura (NPC or player not knowable; unit cannot be assisted)")
end)

test("situations runtime: player debuffs' [Filter] line names your own and your pet's debuffs", function()
    local NS, _, inst = container("player", "HARMFUL", { npcs = "every", players = "every" })
    local lines = record(NS)
    local name = NS.Database.FindContainer(inst.id).name
    NS.SetByPath("container.filter.situations.players", "blizzard", inst.id)
    assertEqual(#lines, 1, table.concat(lines, " | "))
    -- red under: the line reading player-ness for a player-debuff container (it has no NPC side)
    assertEqual(lines[1], "[Filter] " .. name
        .. ": spell lists off, only Blizzard categories set to Show (your own and your pet's debuffs)")
end)
