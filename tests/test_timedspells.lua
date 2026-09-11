-- tests/test_timedspells.lua — modules/TimedSpells.lua: learning which buffs have a duration, for
-- the "only auras without a duration" filter the aura engine cannot express on its own.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")

local function withAuras(mocks, list)
    mocks.C_UnitAuras = {
        GetAuraDataByIndex = function(unit, i)
            if unit ~= "player" then return nil end
            return list[i]
        end,
    }
end

test("timed: nothing is needed until a container shows only timeless auras", function()
    local NS = fresh()
    assertFalse(NS.TimedSpells.Needed())
    NS.SetByPath("container.filter.durationMode", "timeless", 1)
    assertTrue(NS.TimedSpells.Needed())
end)

test("timed: it hears UNIT_AURA through AceEvent only while needed and readable", function()
    -- red under: TS.Sync registering UNIT_AURA regardless of TS.Needed().
    local NS = fresh()
    local ev = NS.TimedSpells.__events()
    assertTrue(ev.__events.UNIT_AURA == nil, "heard while no container needs it")
    NS.SetByPath("container.filter.durationMode", "timeless", 1)
    assertTrue(ev.__events.UNIT_AURA ~= nil, "not heard once a container needs it")
    NS.SetByPath("container.filter.durationMode", "any", 1)
    assertTrue(ev.__events.UNIT_AURA == nil, "still heard once nothing needs it")
end)

test("timed: UNIT_AURA for another unit schedules nothing", function()
    -- red under: onUnitAura without its unit filter.
    local secretUnit = false   -- while true, the client reports the unit "player" as a secret value
    local NS, mocks = fresh({ before = function(m)
        m.issecretvalue = function(v) return secretUnit and v == "player" end
    end })
    NS.SetByPath("container.filter.durationMode", "timeless", 1)
    mocks.__fireTimers()   -- drain the sync's own scan and the apply it queued
    local onUnitAura = NS.TimedSpells.__events().__events.UNIT_AURA
    local before = #mocks.__timers
    onUnitAura("UNIT_AURA", "nameplate1")
    assertEqual(#mocks.__timers, before, "a nameplate's aura change scheduled a scan")
    -- red under: onUnitAura without IsSafeKey.
    secretUnit = true
    onUnitAura("UNIT_AURA", "player")
    secretUnit = false
    assertEqual(#mocks.__timers, before, "a secret unit was compared and scheduled a scan")
    onUnitAura("UNIT_AURA", "player")
    assertEqual(#mocks.__timers, before + 1, "the player's own aura change schedules one scan")
end)

test("timed: combat drops UNIT_AURA and its end restores it with a scan", function()
    local NS, mocks = fresh()
    NS.SetByPath("container.filter.durationMode", "timeless", 1)
    mocks.__fireTimers()
    local ev = NS.TimedSpells.__events()
    assertTrue(ev.__events.UNIT_AURA ~= nil, "not heard before combat")
    -- The client fires PLAYER_REGEN_DISABLED before its combat lockdown begins, so InCombatLockdown()
    -- still answers false inside the handler (docs/midnight-quirks.md, "Combat state").
    -- red under: syncAuraListen reading InCombatLockdown alone at the PLAYER_REGEN_DISABLED edge.
    mocks.__lockdown = false
    mocks.__inCombat = true
    ev.__events.PLAYER_REGEN_DISABLED("PLAYER_REGEN_DISABLED")
    assertTrue(ev.__events.UNIT_AURA == nil, "still heard in combat")
    -- red under: syncAuraListen ignoring InCombatLockdown.
    mocks.__lockdown = true
    ev.__events.ADDON_RESTRICTION_STATE_CHANGED("ADDON_RESTRICTION_STATE_CHANGED")
    assertTrue(ev.__events.UNIT_AURA == nil, "a mid-combat restriction change reopened it")
    mocks.__lockdown = false
    mocks.__inCombat = false
    local before = #mocks.__timers
    ev.__events.PLAYER_REGEN_ENABLED("PLAYER_REGEN_ENABLED")
    assertTrue(ev.__events.UNIT_AURA ~= nil, "not heard again after combat")
    assertEqual(#mocks.__timers, before + 1, "reopening scheduled one scan")
end)

test("timed: a scan queued before combat is dropped in combat, and the gate reopening scans again", function()
    local NS, mocks = fresh()
    NS.SetByPath("container.filter.durationMode", "timeless", 1)
    mocks.__fireTimers(); mocks.__fireTimers()   -- drain the sync's scan and the apply it queued
    withAuras(mocks, { { spellId = 77, duration = 8 } })
    local lines = {}
    rawset(mocks.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
        table.insert(lines, tostring(msg))
    end)
    local heard = { 0 }
    NS.NewBusTarget():RegisterMessage(NS.MSG.TIMED_SPELLS_CHANGED, function() heard[1] = heard[1] + 1 end)
    local ev = NS.TimedSpells.__events()
    local onUnitAura = ev.__events.UNIT_AURA   -- kept: combat unregisters it
    onUnitAura("UNIT_AURA", "player")   -- the player's buffs changed: a scan is queued
    -- red under: scanTick without its readable-state gate (the lockdown check).
    mocks.__inCombat, mocks.__lockdown = true, true
    mocks.__fireTimers(); mocks.__fireTimers()
    assertEqual(NS.TimedSpells.Count(), 0, "a queued scan ran in combat")
    assertEqual(heard[1], 0, "a scan in combat announced TIMED_SPELLS_CHANGED")
    for _, l in ipairs(lines) do
        assertFalse(l:find("will apply", 1, true), "a scan in combat produced a deferral notice: " .. l)
    end
    -- The tick can also come due between PLAYER_REGEN_DISABLED and the lockdown it announces.
    -- red under: scanTick reading InCombatLockdown alone, without the closed gate.
    mocks.__lockdown = false
    ev.__events.PLAYER_REGEN_DISABLED("PLAYER_REGEN_DISABLED")
    onUnitAura("UNIT_AURA", "player")   -- a late delivery re-queues it: the tick must not trust that
    mocks.__fireTimers(); mocks.__fireTimers()
    assertEqual(NS.TimedSpells.Count(), 0, "a scan queued before combat ran at the combat edge")
    assertEqual(heard[1], 0, "a scan at the combat edge announced TIMED_SPELLS_CHANGED")
    -- red under: the dropped tick leaving its scan marked scheduled (every later scan is swallowed).
    mocks.__inCombat, mocks.__lockdown = false, false
    ev.__events.PLAYER_REGEN_ENABLED("PLAYER_REGEN_ENABLED")
    mocks.__fireTimers()
    assertEqual(NS.TimedSpells.Count(), 1, "the gate reopening after combat did not scan")
    assertEqual(heard[1], 1, "the scan after combat was not announced")
end)

test("timed: secret auras out of combat keep UNIT_AURA unregistered until the restriction lifts", function()
    -- red under: syncAuraListen ignoring AurasAreSecret.
    local NS, mocks = fresh()
    mocks.__aurasSecret = true
    mocks.__lockdown = false
    NS.SetByPath("container.filter.durationMode", "timeless", 1)   -- its CONFIG_CHANGED syncs
    local ev = NS.TimedSpells.__events()
    assertTrue(ev.__events.UNIT_AURA == nil, "the settings-driven sync heard while auras are secret")
    mocks.__fireTimers()
    assertTrue(ev.__events.UNIT_AURA == nil, "heard while auras are secret")
    mocks.__aurasSecret = false
    local before = #mocks.__timers
    ev.__events.ADDON_RESTRICTION_STATE_CHANGED("ADDON_RESTRICTION_STATE_CHANGED")
    assertTrue(ev.__events.UNIT_AURA ~= nil, "not heard once the restriction lifted")
    assertEqual(#mocks.__timers, before + 1, "reopening scheduled one scan")
end)

test("timed: learning a spell is announced on the bus to every receiver, and the manager re-applies", function()
    local NS, mocks = fresh()
    withAuras(mocks, { { spellId = 55, duration = 12 } })
    mocks.__fireTimers()
    local heard = { a = 0, b = 0 }
    local a, b = NS.NewBusTarget(), NS.NewBusTarget()
    a:RegisterMessage(NS.MSG.TIMED_SPELLS_CHANGED, function() heard.a = heard.a + 1 end)
    b:RegisterMessage(NS.MSG.TIMED_SPELLS_CHANGED, function() heard.b = heard.b + 1 end)
    local before = #mocks.__timers
    assertEqual(NS.TimedSpells.Scan(), 1)
    assertEqual(heard.a, 1, "the first receiver missed it")
    assertEqual(heard.b, 1, "the second receiver missed it")
    assertEqual(#mocks.__timers, before + 1, "the manager queued no apply")
    NS.TimedSpells.Forget()
    assertEqual(heard.a, 2, "Forget was not announced")
    assertEqual(heard.b, 2, "Forget was not announced to the second receiver")
end)

test("timed: a readable scan learns every timed buff once, and skips permanent ones", function()
    local NS, mocks = fresh()
    withAuras(mocks, {
        { spellId = 11, duration = 10 }, { spellId = 22, duration = 0 }, { spellId = 33, duration = 5 },
    })
    assertEqual(NS.TimedSpells.Scan(), 2)
    assertEqual(NS.TimedSpells.Scan(), 0, "already known")
    assertTrue(NS.db.global.timedSpells[11])
    assertTrue(NS.db.global.timedSpells[22] == nil)
    assertEqual(NS.TimedSpells.Count(), 2)
end)

test("timed: while auras are secret nothing is read", function()
    local NS, mocks = fresh()
    withAuras(mocks, { { spellId = 11, duration = 10 } })
    mocks.__aurasSecret = true
    assertEqual(NS.TimedSpells.Scan(), 0)
    assertEqual(NS.TimedSpells.Count(), 0)
end)

test("timed: what was learned reaches the filter as excluded ids, and Forget clears it", function()
    local NS, mocks = fresh()
    withAuras(mocks, { { spellId = 44, duration = 30 } })
    NS.TimedSpells.Scan()
    local cfg = NS.Database.FindContainer(1)
    cfg.filter.durationMode = "timeless"
    local plan = NS.FilterCompiler.Compile(cfg, { timedSpells = NS.db.global.timedSpells })
    assertTrue(plan.groups[1].candidateFilters.excludeSpellIDs[44])
    NS.TimedSpells.Forget()
    assertEqual(NS.TimedSpells.Count(), 0)
end)
