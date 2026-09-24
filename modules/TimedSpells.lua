local _, NS = ...

-- modules/TimedSpells.lua — learning which buffs have a duration, for the "only auras WITHOUT a
-- duration" filter.
--
-- WHY THIS EXISTS. Blizzard's aura engine can select auras that HAVE a duration (maxDuration) but has
-- no filter for auras that do not. The workaround, which TinyBuffBars (MIT) established: exclude every
-- spell we have seen carry a duration. While auras are readable — out of combat, outside an encounter,
-- key or PvP match — the player's and pet's buffs are scanned and every timed spell id is remembered
-- account-wide (db.global.timedSpells), and modules/FilterCompiler.lua hands that set to the engine as
-- excludeSpellIDs. A timed buff never yet seen out of combat shows up once, then is learned for good.
--
-- HOW IT LISTENS. The gate events go through AceEvent on this file's own target. UNIT_AURA cannot:
-- the vendored AceEvent still has no RegisterUnitEvent, and through AceEvent UNIT_AURA would arrive
-- for every unit, raid members and nameplates included. So UNIT_AURA takes events-frames-taint-§1's
-- one permitted private frame: TS.unitFrame, registered with RegisterUnitEvent for "player" and "pet"
-- only, so the client filters every other unit out before Lua is entered. The carve-out's MUSTs, and
-- where each is met: the frame is HELD ON THE MODULE (TS.unitFrame, built once, lazily, by the first
-- gate opening); it is UNREGISTERED IN THE DISABLE PATH by hand (TS.Stop, which the stand-down runs,
-- because AceEvent's UnregisterAllEvents never reaches it); and it is REUSED ACROSS CYCLES, never
-- rebuilt. It carries one OnEvent script and nothing else. Registration is bounded further by
-- opening the gate only while a scan could read anything: out of combat lockdown and while auras are
-- not secret. PLAYER_REGEN_DISABLED closes that gate (lockdown begins
-- only after it fires); PLAYER_REGEN_ENABLED and ADDON_RESTRICTION_STATE_CHANGED re-check it, and
-- reopening it schedules one scan. In combat and in every secret stretch UNIT_AURA is not registered
-- at all, and a scan queued before the gate closed is dropped when it comes due, so combat never
-- learns a spell, announces one, or queues an apply.
--
-- It only listens while some container actually uses the mode, so an addon with none pays nothing.
-- What it learned is announced on the bus (TIMED_SPELLS_CHANGED), never pushed into another module.

NS.TimedSpells = NS.TimedSpells or {}
local TS = NS.TimedSpells
local Perf = NS.Perf

local scanScheduled = false
local scanTimer = nil      -- the queued scan's handle, so TS.Stop can cancel it
local listening = false    -- whether UNIT_AURA is registered right now
local SCAN_UNITS = { "player", "pet" }   -- also the unit frame's RegisterUnitEvent filter
local MAX_INDEX = 40
-- The events that open and close the UNIT_AURA gate (syncAuraListen).
local GATE_EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ADDON_RESTRICTION_STATE_CHANGED" }

-- Game events, on a target of their own: apart from the message target below, so
-- UnregisterAllEvents can never touch a message registration.
local events = NS.NewBusTarget()

local function store()
    local g = NS.db and NS.db.global
    if not g then return nil end
    g.timedSpells = g.timedSpells or {}
    return g.timedSpells
end

--- Whether any container shows only auras without a duration.
function TS.Needed()
    for _, c in ipairs(NS.Database.GetContainers()) do
        if c.enabled and c.auraType == "HELPFUL" and c.filter and c.filter.durationMode == "timeless" then
            return true
        end
    end
    return false
end

--- Read the units' buffs, if that is allowed right now, and learn every timed spell. Returns how many
--- new spells were learned.
function TS.Scan()
    scanScheduled = false
    local known = store()
    if not known or NS.Compat.AurasAreSecret() then return 0 end
    local api = _G.C_UnitAuras
    if not (api and api.GetAuraDataByIndex) then return 0 end
    local Secrets = NS.Secrets
    local learned = 0
    for _, unit in ipairs(SCAN_UNITS) do
        for i = 1, MAX_INDEX do
            local ok, aura = pcall(api.GetAuraDataByIndex, unit, i, "HELPFUL")
            if not ok or type(aura) ~= "table" then break end
            local id, duration = aura.spellId, aura.duration
            if Secrets.IsSafeKey(id) and Secrets.IsReadableNumber(duration) and duration > 0
                    and not known[id] then
                known[id] = true
                learned = learned + 1
            end
        end
    end
    if learned > 0 then
        NS.Debug("Timed", "learned %s timed spell(s)", learned)
        NS.bus:SendMessage(NS.MSG.TIMED_SPELLS_CHANGED)
    end
    return learned
end

--- Whether a scan could read anything right now: no combat lockdown, auras not secret.
local function readable()
    return not InCombatLockdown() and not NS.Compat.AurasAreSecret()
end

--- One scan, bracketed (bucket `timedScan`, performance-§3). A tick queued before the gate closed
--- (combat, a secret stretch, suspend) is dropped, unmarked, so it neither reads nor announces
--- anything; the gate reopening schedules a fresh scan.
local function scanTick()
    if not (listening and readable()) then
        scanScheduled = false
        return
    end
    local t0 = Perf.on and debugprofilestop()
    TS.Scan()
    if t0 then Perf.Note("timedScan", debugprofilestop() - t0) end
end

local function scheduleScan()
    if scanScheduled then return end
    scanScheduled = true
    scanTimer = C_Timer.NewTimer(0.5, function()
        scanTimer = nil
        scanTick()
    end)
end

--- UNIT_AURA, from the unit frame. The payload is secret while auras are, so the unit is proven a
--- safe key before it is compared.
local function onUnitAura(_, unit)
    -- The frame's RegisterUnitEvent already delivers only player and pet; the comparison stays as
    -- defense in depth, so a widened registration still scans for nothing else.
    if NS.Secrets.IsSafeKey(unit) and (unit == "player" or unit == "pet") then scheduleScan() end
end

--- The module's one private frame (events-frames-taint-§1 carve-out), built on first use and reused
--- for every later gate opening. One OnEvent script, nothing else.
TS.unitFrame = TS.unitFrame or nil
local function unitFrame()
    local f = TS.unitFrame
    if not f then
        f = CreateFrame("Frame")
        f:SetScript("OnEvent", function(_, _, unit) onUnitAura(nil, unit) end)
        TS.unitFrame = f
    end
    return f
end

--- Drop the unit frame's UNIT_AURA registration, if the frame exists. UnregisterAllEvents rather
--- than UnregisterEvent: the frame holds UNIT_AURA and nothing else, so the two agree in the client,
--- and only the former clears a RegisterUnitEvent registration in the test kit's frame stub.
local function closeUnitFrame()
    if TS.unitFrame then TS.unitFrame:UnregisterAllEvents() end
end

--- Register UNIT_AURA while a scan could read anything, and drop it while none could. The client
--- fires PLAYER_REGEN_DISABLED before its combat lockdown begins, so InCombatLockdown() still answers
--- false inside that handler: the event itself closes the gate (docs/midnight-quirks.md, combat state).
local function syncAuraListen(event)
    local open = event ~= "PLAYER_REGEN_DISABLED" and readable()
    if open and not listening then
        -- Listening only if the registration took: a client that refuses UNIT_AURA leaves the
        -- queued scan to find `listening` false and drop itself (events-frames-taint-§1).
        listening = NS.SafeRegisterUnitEvent(unitFrame(), "UNIT_AURA", NS.RejectedEvents,
            SCAN_UNITS[1], SCAN_UNITS[2])
        if listening then scheduleScan() end
    elseif not open and listening then
        closeUnitFrame()
        listening = false
    end
end

--- Stop listening (perf suspend, stand-down, and any time no container needs it). The unit frame is
--- closed by hand: AceEvent's UnregisterAllEvents below never reaches a private frame. A scan
--- already queued is canceled with it, and `scanScheduled` reset so the next gate opening can queue
--- a fresh one.
function TS.Stop()
    closeUnitFrame()
    events:UnregisterAllEvents()
    listening = false
    if scanTimer then
        scanTimer:Cancel()
        scanTimer = nil
    end
    scanScheduled = false
end

--- Start or stop listening, from what the containers need right now. THE LATCH WINS
--- (slash-commands-§7): a stood-down addon registers nothing, for either reason it is down.
function TS.Sync()
    if not (TS.Needed() and not NS.IsStoodDown()) then return TS.Stop() end
    for _, event in ipairs(GATE_EVENTS) do
        NS.SafeRegisterEvent(events, event, syncAuraListen, NS.RejectedEvents)
    end
    syncAuraListen()
    scheduleScan()
end

--- This file's event target (a test seam).
function TS.__events() return events end

-- Whether a scan is needed changes when a container's filter or the registry does, so both messages
-- re-sync — on this file's own bus target (architecture-§4).
local bus = NS.NewBusTarget()

--- Subscribe. Called at load, and again by the stand-up: the stand-down drops these two, because
--- slash-commands-§7 counts a MESSAGE registration exactly as it counts a game event, and a
--- subscription kept alive behind a flag is the draw gate the section exists to end.
function TS.StartListening()
    bus:RegisterMessage(NS.MSG.CONFIG_CHANGED, function() TS.Sync() end)
    bus:RegisterMessage(NS.MSG.CONTAINERS_CHANGED, function() TS.Sync() end)
end

--- Everything this file has registered, gone: the two subscriptions, the gate events and the unit
--- frame's UNIT_AURA that TS.Sync last opened, and the scan it may have queued: TS.Stop cancels that timer rather than
--- leaving it armed to wake up and find the latch. scanTick's `listening` guard stays as defense in
--- depth.
function TS.StandDown()
    TS.Stop()
    bus:UnregisterAllMessages()
end

--- Subscribed again, then re-synced from what the containers need NOW.
function TS.StandUp()
    TS.StartListening()
    TS.Sync()
end

--- This file's bus target (a test seam).
function TS.__bus() return bus end

TS.StartListening()

--- How many spells are known to be timed.
function TS.Count()
    local n = 0
    for _ in pairs(store() or {}) do n = n + 1 end
    return n
end

--- Forget everything learned (`/am forgettimed`). Relearned on the next readable scan.
function TS.Forget()
    local g = NS.db and NS.db.global
    if g then
        local forgotten = TS.Count()
        g.timedSpells = {}
        -- A forget of learned data is a data mutation (debug-logging-§8).
        NS.Debug("Timed", "forgot %s learned timed spell(s)", forgotten)
    end
    -- The player's own change, unlike a scan's: an apply it queues in combat is announced.
    NS.bus:SendMessage(NS.MSG.TIMED_SPELLS_CHANGED, { byPlayer = true })
end
