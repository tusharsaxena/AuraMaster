-- tests/test_timedspells.lua — modules/TimedSpells.lua: learning which buffs have a duration, for
-- the "only auras without a duration" filter the aura engine cannot express on its own.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")

local function withAuras(mocks, list)
    mocks.C_UnitAuras = {
        GetAuraDataByIndex = function(unit, i)
            if unit ~= "player" then return nil end
            return list[i]
        end,
    }
end

--- The unit tokens UNIT_AURA is registered for on the module's own frame (events-frames-taint-§1's
--- carve-out), or nil while it is not registered or the frame was never built.
local function auraUnits(NS)
    local f = NS.TimedSpells.unitFrame
    return f and f.__unitEvents.UNIT_AURA
end

--- The frame's OnEvent, called as the client calls it: `handler(event, unit)`. Kept across an
--- unregistration, as a delivery already in flight would be.
local function auraHandler(NS)
    local f = NS.TimedSpells.unitFrame
    return function(event, unit) f.__scripts.OnEvent(f, event, unit) end
end

--- Whether any AceEvent target (not a frame) holds a UNIT_AURA registration.
local function aceUnitAura(mocks)
    for _, r in ipairs(mocks.__registrations()) do
        if r.kind == "event" and r.event == "UNIT_AURA" then return true end
    end
    return false
end

test("timed: nothing is needed until a container shows only timeless auras", function()
    local NS = fresh()
    assertFalse(NS.TimedSpells.Needed())
    NS.SetByPath("container.filter.durationMode", "timeless", 1)
    assertTrue(NS.TimedSpells.Needed())
end)

test("timed: it hears UNIT_AURA only while needed and readable", function()
    -- red under: TS.Sync registering UNIT_AURA regardless of TS.Needed().
    local NS = fresh()
    assertTrue(auraUnits(NS) == nil, "heard while no container needs it")
    NS.SetByPath("container.filter.durationMode", "timeless", 1)
    assertTrue(auraUnits(NS) ~= nil, "not heard once a container needs it")
    NS.SetByPath("container.filter.durationMode", "any", 1)
    assertTrue(auraUnits(NS) == nil, "still heard once nothing needs it")
end)

test("timedspells: UNIT_AURA is registered for player and pet only, on the module's own frame", function()
    -- red under: events:RegisterEvent('UNIT_AURA')
    local NS, mocks = fresh()
    NS.SetByPath("container.filter.durationMode", "timeless", 1)
    local units = auraUnits(NS)
    assertTrue(units ~= nil, "UNIT_AURA is not registered on the module's frame")
    assertEqual(table.concat(units, ","), "player,pet")
    assertTrue(NS.TimedSpells.__events().__events.UNIT_AURA == nil, "UNIT_AURA still rides AceEvent")
    assertFalse(aceUnitAura(mocks), "an AceEvent target still holds UNIT_AURA")
end)

test("timedspells: disable unregisters the unit frame and enable reuses it", function()
    local NS, mocks = fresh()
    NS.SetByPath("container.filter.durationMode", "timeless", 1)
    local frame = NS.TimedSpells.unitFrame
    assertTrue(frame ~= nil, "no unit frame was built")
    -- red under: TS.Stop without the hand-written unregistration (UnregisterAllEvents on the AceEvent
    -- target never reaches a private frame).
    NS.SetByPath("enabled", false)
    assertTrue(auraUnits(NS) == nil, "the unit frame still watches UNIT_AURA while disabled")
    assertFalse(aceUnitAura(mocks))
    -- red under: a frame built per Sync (events-frames-taint-§1: reused across cycles).
    NS.SetByPath("enabled", true)
    assertTrue(NS.TimedSpells.unitFrame == frame, "enable built a second frame")
    assertEqual(table.concat(auraUnits(NS) or {}, ","), "player,pet")
end)

test("timed: UNIT_AURA for another unit schedules nothing", function()
    -- The frame's registration already filters to player and pet; the handler's own check is
    -- defense in depth, driven here by calling the frame's OnEvent directly.
    -- red under: onUnitAura without its unit filter.
    local secretUnit = false   -- while true, the client reports the unit "player" as a secret value
    local NS, mocks = fresh({ before = function(m)
        m.issecretvalue = function(v) return secretUnit and v == "player" end
    end })
    NS.SetByPath("container.filter.durationMode", "timeless", 1)
    mocks.__fireTimers()   -- drain the sync's own scan and the apply it queued
    local onUnitAura = auraHandler(NS)
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
    assertTrue(auraUnits(NS) ~= nil, "not heard before combat")
    -- The client fires PLAYER_REGEN_DISABLED before its combat lockdown begins, so InCombatLockdown()
    -- still answers false inside the handler (docs/midnight-quirks.md, "Combat state").
    -- red under: syncAuraListen reading InCombatLockdown alone at the PLAYER_REGEN_DISABLED edge.
    mocks.__lockdown = false
    mocks.__inCombat = true
    ev.__events.PLAYER_REGEN_DISABLED("PLAYER_REGEN_DISABLED")
    assertTrue(auraUnits(NS) == nil, "still heard in combat")
    -- red under: syncAuraListen ignoring InCombatLockdown.
    mocks.__lockdown = true
    ev.__events.ADDON_RESTRICTION_STATE_CHANGED("ADDON_RESTRICTION_STATE_CHANGED")
    assertTrue(auraUnits(NS) == nil, "a mid-combat restriction change reopened it")
    mocks.__lockdown = false
    mocks.__inCombat = false
    local before = #mocks.__timers
    ev.__events.PLAYER_REGEN_ENABLED("PLAYER_REGEN_ENABLED")
    assertTrue(auraUnits(NS) ~= nil, "not heard again after combat")
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
    local onUnitAura = auraHandler(NS)   -- kept: combat unregisters it
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
    assertTrue(auraUnits(NS) == nil, "the settings-driven sync heard while auras are secret")
    mocks.__fireTimers()
    assertTrue(auraUnits(NS) == nil, "heard while auras are secret")
    mocks.__aurasSecret = false
    local before = #mocks.__timers
    ev.__events.ADDON_RESTRICTION_STATE_CHANGED("ADDON_RESTRICTION_STATE_CHANGED")
    assertTrue(auraUnits(NS) ~= nil, "not heard once the restriction lifted")
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

test("timed: Forget traces what it cleared", function()
    -- A forget of learned data is a data mutation debug-logging-§8 traces.
    local NS, mocks = fresh()
    withAuras(mocks, { { spellId = 11, duration = 10 }, { spellId = 33, duration = 5 } })
    NS.TimedSpells.Scan()
    local lines = {}
    NS.Debug = function(tag, fmt, ...)
        if tag == "Timed" then
            lines[#lines + 1] = fmt:format(...)
        end
    end
    NS.TimedSpells.Forget()
    -- red under: TS.Forget without its NS.Debug trace
    assertEqual(#lines, 1, "one forget line")
    assertTrue(lines[1]:find("forgot 2", 1, true) ~= nil, lines[1])
end)

--- Auras for more than one unit: `byUnit[unit]` is that unit's list.
local function withUnits(mocks, byUnit)
    mocks.C_UnitAuras = {
        GetAuraDataByIndex = function(unit, i)
            local list = byUnit[unit]
            if type(list) == "function" then return list(i) end
            return list and list[i]
        end,
    }
end

test("timed: the pet's timed buffs are learned too", function()
    local NS, mocks = fresh()
    withUnits(mocks, { player = { { spellId = 11, duration = 10 } }, pet = { { spellId = 99, duration = 20 } } })
    assertEqual(NS.TimedSpells.Scan(), 2)
    -- red under: SCAN_UNITS without "pet" (a hunter's pet buffs would never be excluded)
    assertTrue(NS.db.global.timedSpells[99])
end)

test("timed: an aura read that raises ends that unit's scan, not the other unit's", function()
    local NS, mocks = fresh()
    withUnits(mocks, {
        player = function(i)
            if i == 1 then return { spellId = 11, duration = 10 } end
            error("aura index out of range")
        end,
        pet = { { spellId = 99, duration = 20 } },
    })
    local ok, learned = pcall(NS.TimedSpells.Scan)
    -- red under: GetAuraDataByIndex called unguarded
    assertTrue(ok, tostring(learned))
    assertEqual(learned, 2, "the player's first buff and the pet's")
end)

test("timed: a secret spell id or a secret duration is never learned", function()
    local NS, mocks = fresh({ before = function(m)
        m.issecretvalue = function(v) return v == 666 or v == 9.5 end
    end })
    withUnits(mocks, { player = {
        { spellId = 666, duration = 10 }, { spellId = 22, duration = 9.5 }, { spellId = 33, duration = 4 },
    } })
    -- red under: Scan keying the store with an unproven spell id, or comparing an unproven duration
    assertEqual(NS.TimedSpells.Scan(), 1)
    assertTrue(NS.db.global.timedSpells[33])
    assertNil(NS.db.global.timedSpells[22])
end)

test("timed: a burst of the player's aura changes queues one scan", function()
    local NS, mocks = fresh()
    NS.SetByPath("container.filter.durationMode", "timeless", 1)
    mocks.__fireTimers(); mocks.__fireTimers()
    local onUnitAura = auraHandler(NS)
    local before = #mocks.__timers
    onUnitAura("UNIT_AURA", "player")
    onUnitAura("UNIT_AURA", "pet")
    onUnitAura("UNIT_AURA", "player")
    -- red under: scheduleScan without its scanScheduled latch (a scan per aura change)
    assertEqual(#mocks.__timers, before + 1)
    withAuras(mocks, { { spellId = 5, duration = 3 } })
    mocks.__fireTimers()
    assertEqual(NS.TimedSpells.Count(), 1, "the one queued scan ran")
    -- The scan's announcement queued the manager's apply; the next change adds one scan beside it.
    local after = #mocks.__timers
    onUnitAura("UNIT_AURA", "player")
    assertEqual(#mocks.__timers, after + 1, "and a later change queues the next")
end)

test("timed: Forget is announced as the player's own change, and the next readable scan learns again", function()
    local NS, mocks = fresh()
    withAuras(mocks, { { spellId = 44, duration = 30 } })
    local payloads = {}
    NS.NewBusTarget():RegisterMessage(NS.MSG.TIMED_SPELLS_CHANGED, function(_, p)
        local n = #payloads
        payloads[n + 1] = p or false
    end)
    NS.TimedSpells.Scan()
    NS.TimedSpells.Forget()
    assertEqual(#payloads, 2)
    assertFalse(payloads[1] and payloads[1].byPlayer, "a scan is not the player's change")
    -- red under: Forget announced like a scan (an apply it queues in combat would never say so)
    assertTrue(payloads[2] and payloads[2].byPlayer, "a forget is")
    assertEqual(NS.TimedSpells.Count(), 0)
    assertEqual(NS.TimedSpells.Scan(), 1, "relearned")
end)

test("timed: a scan tick the gate drops is never bracketed; one that reads is, once", function()
    local NS, mocks = fresh()
    NS.SetByPath("container.filter.durationMode", "timeless", 1)
    mocks.__fireTimers(); mocks.__fireTimers()
    local notes = 0
    local P = NS.Perf
    local note = P.Note
    P.Note = function(key, ...)
        if key == "timedScan" then notes = notes + 1 end
        return note(key, ...)
    end
    P.on = true
    local onUnitAura = auraHandler(NS)
    onUnitAura("UNIT_AURA", "player")
    mocks.__lockdown = true
    mocks.__fireTimers()
    local dropped = notes
    mocks.__lockdown = false
    onUnitAura("UNIT_AURA", "player")
    mocks.__fireTimers()
    P.on, P.Note = false, note
    -- red under: the timedScan bracket opened before the readable gate (a dropped tick reports a scan)
    assertEqual(dropped, 0, "a dropped tick")
    assertEqual(notes, 1, "a scan that ran")
end)

test("timed: a disabled container, or one showing debuffs, needs no scan", function()
    local NS = fresh()
    local c1, c2 = NS.Database.FindContainer(1), NS.Database.FindContainer(2)
    c2.filter.durationMode = "timeless"
    -- red under: Needed without its HELPFUL check (the exclusion list only exists for buffs)
    assertFalse(NS.TimedSpells.Needed(), "a debuff container")
    c1.filter.durationMode, c1.enabled = "timeless", false
    -- red under: Needed without its enabled check
    assertFalse(NS.TimedSpells.Needed(), "a disabled buff container")
    c1.enabled = true
    assertTrue(NS.TimedSpells.Needed())
end)

test("timed: a client without the aura API learns nothing and raises nothing", function()
    local NS, mocks = fresh()
    mocks.C_UnitAuras = nil
    local ok, learned = pcall(NS.TimedSpells.Scan)
    -- red under: Scan indexing C_UnitAuras unguarded
    assertTrue(ok, tostring(learned))
    assertEqual(learned, 0)
end)

test("timed: a client that refuses UNIT_AURA leaves TimedSpells not listening, and the rest loads", function()
    -- red under: bare events:RegisterEvent (the raise takes TS.Sync, and the settings write, with it)
    local NS, mocks = fresh({ before = function(m) m.__badEvents = { UNIT_AURA = true } end })
    assertTrue(NS.SetByPath("container.filter.durationMode", "timeless", 1))
    mocks.__fireTimers()
    local ev = NS.TimedSpells.__events()
    assertTrue(auraUnits(NS) == nil, "UNIT_AURA registered on a client that refuses it")
    assertTrue(ev.__events.PLAYER_REGEN_DISABLED ~= nil, "the gate events were lost with it")
    local seen = 0
    for _, name in ipairs(NS.RejectedEvents) do
        if name == "UNIT_AURA" then seen = seen + 1 end
    end
    assertEqual(seen, 1, "UNIT_AURA recorded once")
    -- red under: `listening` set regardless of the registration's answer (the queued scan would
    -- read, and learn the timed buff below)
    withAuras(mocks, { { spellId = 1459, duration = 3600 } })
    ev.__events.PLAYER_REGEN_ENABLED("PLAYER_REGEN_ENABLED")
    mocks.__fireTimers()
    assertEqual(NS.TimedSpells.Count(), 0, "a scan ran with nothing listening")
    assertTrue(NS.ContainerManager.Count() > 0, "the rest of the addon loaded")
end)
