-- tests/test_container_unitfilter.lua — the Unit type gate (filter situations, S6 of
-- docs/superpowers/specs/2026-10-02-filter-situations-addendum-unit-filter.md): `filter.unitFilter`
-- (`kind` all | npc | player, `reaction` all | friendly | neutral | hostile) gating
-- ContainerClass:ShouldShow beside the zone rule, as
-- `(not p.locked) or previewing or (visibilityAllows and zoneAllows and unitAllows)`.
--
-- Target and focus containers only: a player or pet container ignores it. A unit that does not match
-- both choices hides a LOCKED container through the combat-legal path (ApplyLive: the engine's
-- SetEnabled and our own blocker), never the anchor. An unknowable answer, or no unit, allows. An
-- unlocked or test-mode container still shows. Re-evaluated on a target or focus swap and on
-- UNIT_FACTION / UNIT_FLAGS for target, focus and the player, through the view frames already
-- registered, and only for a container whose answer moved.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")

local KINDS = { "all", "npc", "player" }
local REACTIONS = { "all", "friendly", "neutral", "hostile" }

--- Who `unit` is now: `isPlayer`, and `reaction` (UnitReaction's 1-8). `exists` false for no unit.
local function be(mocks, unit, isPlayer, reaction, exists)
    mocks.__unitExists[unit] = exists ~= false
    mocks.__isPlayer[unit] = isPlayer
    mocks.__reaction[unit] = reaction
end

--- A locked target (or `unit`) buff container with `kind` / `reaction` stored. Answers NS, mocks,
--- the instance and its id.
local function gated(kind, reaction, unit, setup)
    local NS, mocks = fresh({ before = setup })
    local id = NS.ContainerManager.Create({ unit = unit or "target", auraType = "HELPFUL",
        filter = { unitFilter = { kind = kind, reaction = reaction } } })
    mocks.__fireTimers()
    return NS, mocks, NS.ContainerManager.instances[id], id
end

-- ── the gate ────────────────────────────────────────────────────────────────────────────────

-- isPlayer, UnitReaction, and the kind and reaction each matches.
local UNITS = {
    { name = "a hostile NPC",   isPlayer = false, reaction = 2, kind = "npc",    band = "hostile" },
    { name = "a neutral NPC",   isPlayer = false, reaction = 4, kind = "npc",    band = "neutral" },
    { name = "a friendly NPC",  isPlayer = false, reaction = 5, kind = "npc",    band = "friendly" },
    { name = "a hostile player", isPlayer = true, reaction = 1, kind = "player", band = "hostile" },
    { name = "a friendly player", isPlayer = true, reaction = 8, kind = "player", band = "friendly" },
}

test("unit type: a locked target container shows only on a unit matching both choices", function()
    local NS, mocks, inst = gated("all", "all")
    for _, kind in ipairs(KINDS) do
        for _, reaction in ipairs(REACTIONS) do
            local f = NS.Database.FindContainer(inst.id).filter.unitFilter
            f.kind, f.reaction = kind, reaction
            for _, u in ipairs(UNITS) do
                be(mocks, "target", u.isPlayer, u.reaction)
                NS.ContainerManager.ApplyVisibility()
                local want = (kind == "all" or kind == u.kind) and (reaction == "all" or reaction == u.band)
                local what = kind .. "/" .. reaction .. " on " .. u.name
                -- red under: ShouldShow without the unit gate (every unit shows the container)
                assertEqual((inst:ShouldShow()), want, what)
                assertEqual(inst.engine.__enabled, want, "the engine follows: " .. what)
                assertEqual(inst.blocker:IsShown(), want, "and the blocker: " .. what)
            end
        end
    end
end)

test("unit type: no unit, and an unknowable answer, allow", function()
    local NS, mocks, inst = gated("player", "hostile")
    be(mocks, "target", false, 5, false)
    -- red under: UnitIsPlayer's false for no unit read as an NPC (an empty target hid the container)
    assertTrue((inst:ShouldShow()), "no target")
    be(mocks, "target", false, 5)
    assertFalse((inst:ShouldShow()), "a friendly NPC is hidden")
    mocks.UnitIsPlayer = function() error("refused") end
    mocks.UnitReaction = function() error("refused") end
    -- red under: an unguarded read (the error escapes the show ladder), or unknowable read as a mismatch
    assertTrue((inst:ShouldShow()), "both unknowable")
    mocks.UnitIsPlayer = function() return false end
    assertFalse((inst:ShouldShow()), "the kind alone known, and an NPC")
    NS.Database.FindContainer(inst.id).filter.unitFilter.kind = "npc"
    -- red under: an unknowable reaction read as a mismatch
    assertTrue((inst:ShouldShow()), "the reaction unknowable allows")
end)

test("unit type: a hand-edited choice the rows do not offer allows", function()
    local NS, mocks, inst = gated("all", "all")
    local f = NS.Database.FindContainer(inst.id).filter.unitFilter
    f.kind, f.reaction = "garbage", 7
    be(mocks, "target", true, 1)
    -- red under: a stored value compared as if it were a choice (nothing ever matches it)
    assertTrue((inst:ShouldShow()))
end)

test("unit type: unlocked or in test mode, a container shows on a unit it is set against", function()
    local NS, mocks, inst = gated("player", "all")
    be(mocks, "target", false, 2)
    NS.ContainerManager.ApplyVisibility()
    assertFalse((inst:ShouldShow()), "locked: hidden")
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    -- red under: the unit gate ANDed outside the lock (an unlocked container could not be found)
    assertTrue((inst:ShouldShow()), "unlocked: shown")
    NS.SetByPath("locked", true)
    NS.Preview.SetTestMode(true)
    mocks.__fireTimers()
    local show, previewing = inst:ShouldShow()
    -- red under: the unit gate ANDed outside test mode
    assertTrue(show, "test mode: shown")
    assertTrue(previewing)
end)

test("unit type: the gate sits beside General visibility and the zone rule, all must allow", function()
    local NS, mocks, inst = gated("npc", "hostile")
    be(mocks, "target", false, 2)
    assertTrue((inst:ShouldShow()), "a hostile NPC")
    NS.db.profile.visibility = "never"
    -- red under: the unit gate ORed with visibility
    assertFalse((inst:ShouldShow()), "visibility never")
    NS.db.profile.visibility = "always"
    NS.Database.FindContainer(inst.id).filter.zones.raid = false
    mocks.__context.inInstance, mocks.__context.instanceType = true, "raid"
    -- red under: the unit gate ORed with the zone rule
    assertFalse((inst:ShouldShow()), "an unticked zone")
end)

test("unit type: player and pet containers ignore it", function()
    for _, unit in ipairs({ "player", "pet" }) do
        local NS, mocks, inst = gated("player", "hostile", unit)
        be(mocks, unit, false, 5)
        NS.ContainerManager.ApplyVisibility()
        -- red under: the gate read on every container (a player container set to hostile players
        -- would never show)
        assertTrue((inst:ShouldShow()), unit)
        assertTrue(inst.engine.__enabled, unit .. ": the engine on")
    end
end)

test("unit type: the focus container follows the focus, not the target", function()
    local _, mocks, inst = gated("npc", "all", "focus")
    be(mocks, "target", true, 1)
    be(mocks, "focus", false, 2)
    -- red under: the gate reading the target whatever the container's unit
    assertTrue((inst:ShouldShow()))
    be(mocks, "focus", true, 2)
    assertFalse((inst:ShouldShow()))
end)

-- ── re-evaluation: swaps, reaction changes and writes, in combat too ─────────────────────────

test("unit type: a target swap re-evaluates it in combat, through SetEnabled, never the anchor", function()
    local _, mocks, inst = gated("player", "hostile")
    be(mocks, "target", true, 1)
    mocks.__fireEvent("PLAYER_TARGET_CHANGED")
    assertTrue(inst.engine.__enabled, "a hostile player: shown")
    mocks.__lockdown, mocks.__inCombat = true, true
    be(mocks, "target", false, 2)
    mocks.__fireEvent("PLAYER_TARGET_CHANGED")
    -- red under: OnUnitSwap not re-running the gate (the container kept showing on the NPC)
    assertFalse(inst.engine.__enabled, "a hostile NPC: hidden")
    assertFalse(inst.blocker:IsShown(), "and its blocker")
    -- red under: hiding through the anchor (the aura engine's ancestry, blocked under lockdown)
    assertTrue(inst.anchor:IsShown(), "the anchor stays shown")
    be(mocks, "target", true, 1)
    mocks.__fireEvent("PLAYER_TARGET_CHANGED")
    assertTrue(inst.engine.__enabled, "back on a hostile player")
end)

test("unit type: a focus swap re-evaluates focus containers", function()
    local _, mocks, inst = gated("npc", "all", "focus")
    be(mocks, "focus", true, 5)
    mocks.__fireEvent("PLAYER_FOCUS_CHANGED")
    -- red under: OnUnitSwap re-running the gate for the target only
    assertFalse(inst.engine.__enabled, "a player focus: hidden")
end)

test("unit type: UNIT_FACTION and UNIT_FLAGS on the target, the focus and the player re-evaluate it", function()
    local _, mocks, inst = gated("all", "hostile")
    be(mocks, "target", false, 2)
    mocks.__fireEvent("PLAYER_TARGET_CHANGED")
    assertTrue(inst.engine.__enabled, "hostile: shown")
    mocks.__lockdown, mocks.__inCombat = true, true
    mocks.__reaction.target = 5
    mocks.__fire("UNIT_FLAGS", "focus")
    -- red under: the focus's event re-running the target's gate
    assertTrue(inst.engine.__enabled, "the focus's event leaves the target container alone")
    mocks.__fire("UNIT_FACTION", "target")
    -- red under: the view frame's handler not re-running the gate (an NPC turning friendly)
    assertFalse(inst.engine.__enabled, "turned friendly: hidden")
    mocks.__reaction.target = 3
    mocks.__fire("UNIT_FLAGS", "target")
    assertTrue(inst.engine.__enabled, "hostile again (a duel starting): shown")
    mocks.__reaction.target = 6
    mocks.__fire("UNIT_FACTION", "player")
    -- red under: the player frame's handler not re-running the gate (a mind-controlled player)
    assertFalse(inst.engine.__enabled, "the player's side moved: hidden")
end)

test("unit type: an event that does not move a container's answer runs no visibility pass for it", function()
    local NS, mocks, inst = gated("npc", "all")
    local other = NS.ContainerManager.instances[3]   -- the starter target debuffs, All / All
    be(mocks, "target", false, 2)
    mocks.__fireEvent("PLAYER_TARGET_CHANGED")
    local passes = {}
    for _, i in ipairs({ inst, other }) do
        local orig = i.ApplyVisibility
        rawset(i, "ApplyVisibility", function(self, ...)
            passes[self] = (passes[self] or 0) + 1
            return orig(self, ...)
        end)
    end
    be(mocks, "target", false, 4)
    mocks.__fireEvent("PLAYER_TARGET_CHANGED")
    mocks.__fire("UNIT_FLAGS", "target")
    mocks.__fire("UNIT_FLAGS", "player")
    -- red under: a pass per container on every swap and flag change (UNIT_FLAGS fires on combat)
    assertEqual(passes[inst] or 0, 0, "still an NPC: no pass")
    assertEqual(passes[other] or 0, 0, "All / All: never a pass")
    be(mocks, "target", true, 4)
    mocks.__fireEvent("PLAYER_TARGET_CHANGED")
    assertEqual(passes[inst], 1, "a player now: one pass")
    assertFalse(inst.engine.__enabled)
end)

test("unit type: a full visibility pass between events keeps the moved-answer check true", function()
    local NS, mocks, inst = gated("npc", "all")
    be(mocks, "target", false, 2)
    mocks.__fireEvent("PLAYER_TARGET_CHANGED")
    -- The answer moves with no event, a full pass hides it, and it moves back on a swap.
    mocks.__isPlayer.target = true
    NS.ContainerManager.ApplyVisibility()
    assertFalse(inst.engine.__enabled, "the full pass hid it")
    mocks.__isPlayer.target = false
    mocks.__fireEvent("PLAYER_TARGET_CHANGED")
    -- red under: the moved-answer check keyed on what the last EVENT saw rather than the last pass
    assertTrue(inst.engine.__enabled, "an NPC again: shown")
end)

test("unit type: the unit events stay on the view frames, nothing new is registered", function()
    local NS, mocks = gated("npc", "hostile")
    local out = {}
    for _, r in ipairs(mocks.__registrations()) do
        if r.event == "UNIT_FACTION" or r.event == "UNIT_FLAGS" then
            local key = (r.target == NS.ContainerManager.viewFrame and "view")
                or (r.target == NS.ContainerManager.viewPlayerFrame and "player") or "other"
            out[#out + 1] = key .. ":" .. r.event .. ":" .. tostring(r.unit)
        end
    end
    table.sort(out)
    -- red under: a frame of the gate's own registering the same events
    assertEqual(table.concat(out, " | "), "player:UNIT_FACTION:player | player:UNIT_FLAGS:player | "
        .. "view:UNIT_FACTION:focus | view:UNIT_FACTION:target | view:UNIT_FLAGS:focus | view:UNIT_FLAGS:target")
end)

test("unit type: a Unit type write takes effect at once, in combat too", function()
    local NS, mocks, inst = gated("all", "all")
    be(mocks, "target", false, 2)
    mocks.__fireEvent("PLAYER_TARGET_CHANGED")
    mocks.__lockdown, mocks.__inCombat = true, true
    assertTrue(NS.SetByPath("container.filter.unitFilter.kind", "player", inst.id))
    -- red under: the rows taking the apply hold rather than the visibility effect
    assertFalse(inst.engine.__enabled, "Players on an NPC: hidden")
    assertTrue(inst.anchor:IsShown(), "the anchor stays shown")
    assertTrue(NS.SetByPath("container.filter.unitFilter.kind", "all", inst.id))
    assertTrue(NS.SetByPath("container.filter.unitFilter.reaction", "friendly", inst.id))
    assertFalse(inst.engine.__enabled, "Friendly on a hostile NPC: hidden")
    assertTrue(NS.SetByPath("container.filter.unitFilter.reaction", "all", inst.id))
    assertTrue(inst.engine.__enabled, "All / All: shown")
end)
