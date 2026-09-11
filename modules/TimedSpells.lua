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
-- It only listens while some container actually uses the mode, so an addon with none pays nothing.

NS.TimedSpells = NS.TimedSpells or {}
local TS = NS.TimedSpells

local frame            -- the event frame, built on first need
local scanScheduled = false
local SCAN_UNITS = { "player", "pet" }
local MAX_INDEX = 40

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
        if NS.ContainerManager then NS.ContainerManager.RequestApply() end
    end
    return learned
end

local function scheduleScan()
    if scanScheduled then return end
    scanScheduled = true
    C_Timer.After(0.5, TS.Scan)
end

--- The event frame. UNIT_AURA goes through RegisterUnitEvent for the two units scanned, so the client
--- filters it: registered bare, it would fire for every unit in a raid and every nameplate.
local function eventFrame()
    if not frame and CreateFrame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", function() scheduleScan() end)
    end
    return frame
end

--- Stop listening (perf suspend, and any time no container needs it).
function TS.Stop()
    if frame then frame:UnregisterAllEvents() end
end

--- Start or stop listening, from what the containers need right now. Suspend wins
--- (performance-§6): a suspended addon registers nothing.
function TS.Sync()
    if not (TS.Needed() and not NS.Perf.suspended) then return TS.Stop() end
    local f = eventFrame()
    if not f then return end
    f:RegisterUnitEvent("UNIT_AURA", "player", "pet")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    scheduleScan()
end

--- The event frame, or nil before it is needed (a test seam).
function TS.__frame() return frame end

-- Whether a scan is needed changes when a container's filter or the registry does, so both messages
-- re-sync — on this file's own bus target (architecture-§4).
local bus = NS.NewBusTarget()
bus:RegisterMessage(NS.MSG.CONFIG_CHANGED, function() TS.Sync() end)
bus:RegisterMessage(NS.MSG.CONTAINERS_CHANGED, function() TS.Sync() end)

--- How many spells are known to be timed.
function TS.Count()
    local n = 0
    for _ in pairs(store() or {}) do n = n + 1 end
    return n
end

--- Forget everything learned (`/am forgettimed`). Relearned on the next readable scan.
function TS.Forget()
    local g = NS.db and NS.db.global
    if g then g.timedSpells = {} end
    if NS.ContainerManager then NS.ContainerManager.RequestApply() end
end
