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
-- HOW IT LISTENS. Through AceEvent on this file's own target, never a private frame
-- (events-frames-taint-§1). The vendored AceEvent has no RegisterUnitEvent, so UNIT_AURA arrives for
-- every unit, raid members and nameplates included, and the handler keeps only the player and pet.
-- That cost is bounded by registering UNIT_AURA only while a scan could read anything: out of combat
-- lockdown and while auras are not secret. PLAYER_REGEN_DISABLED closes that gate (lockdown begins
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
local listening = false    -- whether UNIT_AURA is registered right now
local SCAN_UNITS = { "player", "pet" }
local MAX_INDEX = 40

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
    C_Timer.After(0.5, scanTick)
end

--- UNIT_AURA arrives for every unit. The payload is secret while auras are, so the unit is proven a
--- safe key before it is compared.
local function onUnitAura(_, unit)
    if NS.Secrets.IsSafeKey(unit) and (unit == "player" or unit == "pet") then scheduleScan() end
end

--- Register UNIT_AURA while a scan could read anything, and drop it while none could. The client
--- fires PLAYER_REGEN_DISABLED before its combat lockdown begins, so InCombatLockdown() still answers
--- false inside that handler: the event itself closes the gate (docs/midnight-quirks.md, combat state).
local function syncAuraListen(event)
    local open = event ~= "PLAYER_REGEN_DISABLED" and readable()
    if open and not listening then
        events:RegisterEvent("UNIT_AURA", onUnitAura)
        listening = true
        scheduleScan()
    elseif not open and listening then
        events:UnregisterEvent("UNIT_AURA")
        listening = false
    end
end

--- Stop listening (perf suspend, and any time no container needs it).
function TS.Stop()
    events:UnregisterAllEvents()
    listening = false
end

--- Start or stop listening, from what the containers need right now. THE LATCH WINS
--- (slash-commands-§7): a stood-down addon registers nothing, for either reason it is down.
function TS.Sync()
    if not (TS.Needed() and not NS.IsStoodDown()) then return TS.Stop() end
    events:RegisterEvent("PLAYER_REGEN_DISABLED", syncAuraListen)
    events:RegisterEvent("PLAYER_REGEN_ENABLED", syncAuraListen)
    events:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED", syncAuraListen)
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

--- Everything this file has registered, gone: the two subscriptions and whatever UNIT_AURA gate
--- TS.Sync last opened. A scan already queued is dropped by scanTick's `listening` guard rather than
--- canceled -- C_Timer.After hands back no handle to cancel.
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
