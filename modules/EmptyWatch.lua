local _, NS = ...

-- modules/EmptyWatch.lua — whether a container is EMPTY right now, predicted, so that while unlocked
-- a chain hangs its followers from a one-element placeholder only while their parent holds nothing
-- (batch 9 HG-1; E1 as amended by the owner, 2026-09-25: "When unlocked and empty, create a
-- placeholder block and have anchors attach to that. Do this only if that container is empty. If
-- it's not empty, hide that placeholder block.").
--
-- WHY A PREDICTION. The engine cannot say whether it is empty. GetAuraGroupFrameCount is the pool of
-- buttons it has created, which never shrinks; a released button stays anchored; its size is set
-- through a secret. So this file asks the question the engine answers, from C_UnitAuras, and answers
-- TRUE only when that is certain, FALSE when a matching aura or weapon enchant is certainly there,
-- and NIL whenever anything is secret, raises, or lies outside what it can check. Nil counts as not
-- empty (modules/Container.lua's hangModeFor): a wrong "not empty" costs only the cosmetic collapse
-- of an empty chain (#9), while a wrong "empty" would draw a parent's later auras under its follower.
--
-- HOW IT LISTENS. UNIT_AURA takes events-frames-taint-§1's unit-filter frame carve-out, as
-- modules/TimedSpells.lua does: RegisterUnitEvent allows two units per frame, so there are two
-- frames, held on the module (EW.unitFrames), built once and reused, one for player and pet and one
-- for target and focus, each registered only while a shown container on those units needs a
-- prediction, and unregistered by hand in EW.Stop. Each frame filters UNIT_AURA and nothing else (the
-- carve-out's whole permission); the player's pet and gear changes and the target and focus swaps
-- come through AceEvent on this file's own target. The gate is narrow: unlocked, not in test mode, out of combat (the combat edge
-- is PLAYER_REGEN_DISABLED, which fires before lockdown: EW.SetCombat) and while auras are readable.
-- A handler only marks the pass due; one pass, PASS_DELAY later, re-predicts every watched container
-- and re-runs the visibility pass of any whose answer changed. Nothing is allocated per event.

NS.EmptyWatch = NS.EmptyWatch or {}
local EW = NS.EmptyWatch
local Perf = NS.Perf

local PASS_DELAY = 0.2
-- Where each weapon slot's "has an enchant" sits in GetWeaponEnchantInfo's returns; its expiration,
-- in milliseconds left, follows it.
local ENCHANT_ARG = { mainHand = 1, offHand = 5, ranged = 9 }
-- The candidate-filter keys that are not boolean flags on the aura (matchKey below).
local ID_KEYS = { includeSpellIDs = true, excludeSpellIDs = true }

local combat = false          -- PLAYER_REGEN_DISABLED seen, PLAYER_REGEN_ENABLED not yet
local onPlayer, onOther = false, false   -- which unit frame is registered
local passTimer, expiryTimer, expiryDue = nil, nil, nil

-- ---------------------------------------------------------------------------
-- The prediction
-- ---------------------------------------------------------------------------

local function secretsGate()
    return combat or InCombatLockdown() or NS.Compat.AurasAreSecret()
end

--- Whether `unit` exists: true, false, or nil when that is not knowable.
local function unitExists(unit)
    local ok, v = pcall(UnitExists, unit)
    if not (ok and NS.Secrets.CanAccess(v)) then return nil end
    return v and true or false
end

--- Whether the engine honors spell ids for this unit and aura type right now: only on buffs of a
--- friendly unit and debuffs of a hostile one (docs/midnight-quirks.md). Nil when not knowable.
local function idsApply(unit, auraType)
    if unit == "player" or unit == "pet" then return NS.FilterCompiler.IdsHonored(unit, auraType) end
    local ok, friend = pcall(UnitIsFriend, "player", unit)
    if not (ok and NS.Secrets.CanAccess(friend)) then return nil end
    friend = friend and true or false
    if auraType == "HARMFUL" then return not friend end
    return friend
end

--- One spell-id list against the aura: true when it passes, false when it fails, nil when unknowable.
local function matchIds(aura, key, set, idsOk)
    if idsOk == false then return true end
    if idsOk == nil then return nil end
    local id = aura.spellId
    if not NS.Secrets.IsSafeKey(id) then return nil end
    local listed = set[id] == true
    if key == "includeSpellIDs" then return listed end
    return not listed
end

--- One dispel-type list against the aura. An aura with no type fails an include and passes an exclude.
local function matchDispel(aura, set, include)
    local d = aura.dispelName
    if d == nil or d == "" then return not include end
    if not NS.Secrets.IsSafeKey(d) then return nil end
    local listed = set[d] == true
    if include then return listed end
    return not listed
end

--- The max duration against the aura's FULL duration: a permanent aura (no duration) never passes,
--- as the engine drops it whenever maxDuration is set.
local function matchDuration(aura, cap)
    local dur = aura.duration
    if not NS.Secrets.IsReadableNumber(dur) then return nil end
    if dur <= 0 then return false end
    return dur <= cap
end

--- A boolean flag (isBossAura, isStealable, ...) against the aura. Nil when the aura data does not
--- carry it or it is secret.
local function matchFlag(aura, key, want)
    local v = aura[key]
    if v == nil or not NS.Secrets.CanAccess(v) then return nil end
    return (v and true or false) == want
end

--- One candidate-filter key against the aura: true, false, or nil when unknowable or unknown.
local function matchKey(aura, key, value, idsOk)
    if ID_KEYS[key] then return matchIds(aura, key, value, idsOk) end
    if key == "includeDispelTypes" then return matchDispel(aura, value, true) end
    if key == "excludeDispelTypes" then return matchDispel(aura, value, false) end
    if key == "maxDuration" then return matchDuration(aura, value) end
    if type(value) == "boolean" then return matchFlag(aura, key, value) end
    return nil
end

--- Whether the aura passes every candidate filter: false as soon as one certainly fails, nil when
--- none fails but one is unknowable.
local function matchAura(aura, cand, idsOk)
    local unknown = false
    for key, value in pairs(cand) do
        local r = matchKey(aura, key, value, idsOk)
        if r == false then return false end
        if r == nil then unknown = true end
    end
    if unknown then return nil end
    return true
end

--- Whether none of the slots GetAuraSlots returned holds an aura passing `cand`. Raises through to
--- the caller's pcall on anything the client refuses.
local function slotsEmpty(api, unit, cand, idsOk, token, ...)
    local unknown = false
    for i = 1, select("#", ...) do
        local aura = api.GetAuraDataBySlot(unit, (select(i, ...)))
        local m = nil
        if type(aura) == "table" then m = matchAura(aura, cand, idsOk) end
        if m == true then return false end
        if m == nil then unknown = true end
    end
    -- More slots than one call returns: the rest were not read.
    if unknown or token ~= nil then return nil end
    return true
end

--- Whether group `g` holds nothing for `unit`. A token-only group asks for one slot: any slot back
--- means an aura, and no table is built. Run under pcall: a rejected filter token raises.
local function groupEmpty(api, unit, g, idsOk)
    local cand = g.candidateFilters
    if not cand then return select("#", api.GetAuraSlots(unit, g.filter, 1)) <= 1 end
    return slotsEmpty(api, unit, cand, idsOk, api.GetAuraSlots(unit, g.filter))
end

--- The engine's created-button pool for one group, when it reads as a plain number.
local function poolOf(engine, key)
    if not engine then return nil end
    local ok, n = pcall(engine.GetAuraGroupFrameCount, engine, key)
    if ok and NS.Secrets.IsReadableNumber(n) then return n end
    return nil
end

--- Whether the container's aura groups hold nothing: true, false or nil.
local function aurasEmpty(inst, plan, cfg)
    local unit = cfg.unit
    local exists = unitExists(unit)
    if exists == false then return true end
    local api, idsOk = _G.C_UnitAuras, idsApply(unit, cfg.auraType)
    local result = true
    for _, g in ipairs(plan.groups) do
        local r = true
        if poolOf(inst.engine, g.key) ~= 0 then
            local ok, v = pcall(groupEmpty, api, unit, g, idsOk)
            if ok then r = v else r = nil end
            if exists == nil and r == true then r = nil end
        end
        if r == false then return false end
        if r == nil then result = nil end
    end
    return result
end

--- Arm a pass for the soonest enchant expiry, `ms` from now, while listening: an enchant that lapses
--- fires no UNIT_AURA. A later expiry than the one already armed changes nothing.
local function noteExpiry(ms)
    if not (onPlayer or onOther) then return end
    local due = GetTime() + ms / 1000
    if expiryTimer and expiryDue <= due then return end
    expiryDue = due
    if expiryTimer then expiryTimer:Cancel() end
    expiryTimer = C_Timer.NewTimer(ms / 1000 + 0.1, EW.OnExpiry)
end

--- One weapon slot: false when it shows an enchant, true when it shows none, nil when unknowable.
local function slotEmpty(has, ms, hidePermanent)
    if not NS.Secrets.CanAccess(has) then return nil end
    if not has then return true end
    local timed = NS.Secrets.IsReadableNumber(ms) and ms > 0
    if timed then noteExpiry(ms) end
    if not hidePermanent then return false end
    if not NS.Secrets.CanAccess(ms) then return nil end
    return not timed
end

--- The enchant block against GetWeaponEnchantInfo's returns (`ok` first, from the pcall).
local function enchantState(block, ok, ...)
    if not ok then return nil end
    local result = true
    for _, slot in ipairs(block.slots) do
        local at = ENCHANT_ARG[slot]
        local r = nil
        if at then r = slotEmpty(select(at, ...), select(at + 1, ...), block.hidePermanent) end
        if r == false then return false end
        if r == nil then result = nil end
    end
    return result
end

--- Whether the container's weapon-enchant slots show nothing: true, false or nil.
local function enchantsEmpty(block)
    if not block then return true end
    local fn = GetWeaponEnchantInfo
    if type(fn) ~= "function" then return nil end
    return enchantState(block, pcall(fn))
end

--- Whether live container `inst` is empty: true, false, or nil when that is not knowable (combat,
--- secret auras, a secret or raising read, a filter this file cannot check). Container:PredictEmpty.
--- @return boolean|nil
function EW.Predict(inst)
    if secretsGate() then return nil end
    local plan = inst.plan
    local cfg = plan and inst.Cfg and inst:Cfg()
    if not cfg then return nil end
    local e = enchantsEmpty(plan.enchants)
    if e == false then return false end
    local a = aurasEmpty(inst, plan, cfg)
    if a == false then return false end
    if a == nil or e == nil then return nil end
    return true
end

-- ---------------------------------------------------------------------------
-- Re-evaluation
-- ---------------------------------------------------------------------------

--- Re-predict every container its last visibility pass marked as watched (`watchEmpty`: shown,
--- unlocked, not previewing), and re-run the visibility pass of each whose answer changed.
function EW.Reevaluate()
    local CM = NS.ContainerManager
    if not CM then return end
    for _, inst in pairs(CM.instances) do
        if inst.watchEmpty and EW.Predict(inst) ~= inst.predictedEmpty then inst:ApplyVisibility() end
    end
end

local function runPass()
    passTimer = nil
    if not (onPlayer or onOther) or secretsGate() then return end
    local t0 = Perf.on and debugprofilestop()
    EW.Reevaluate()
    if t0 then Perf.Note("emptyPass", debugprofilestop() - t0) end
end

local function schedulePass()
    if passTimer then return end
    passTimer = C_Timer.NewTimer(PASS_DELAY, runPass)
end

--- An enchant's expiry lapsed: re-predict.
function EW.OnExpiry()
    expiryTimer, expiryDue = nil, nil
    schedulePass()
end

--- The unit frames' one OnEvent. It only marks the pass due: the client already filtered the units.
local function onUnitEvent()
    schedulePass()
end

--- PLAYER_TARGET_CHANGED and PLAYER_FOCUS_CHANGED: re-predict NOW rather than PASS_DELAY later. The
--- engine redraws for the new unit in this same frame, so a follower hung from a parent that just
--- emptied would sit at the engine's 1x1 provisional rect for the whole delay, and jump there and
--- back (the owner, 2026-09-26). One switch is one pass; a pass already due is folded into it.
local function onUnitSwitch()
    if passTimer then passTimer:Cancel() end
    runPass()
end

--- UNIT_PET and UNIT_INVENTORY_CHANGED through AceEvent, which does not filter by unit: only the
--- player's own pet or gear marks the pass due.
local function onPlayerUnit(_, unit)
    if unit == "player" then schedulePass() end
end

-- Game events that are not unit events, on a target of their own (architecture-§4).
local events = NS.NewBusTarget()

EW.unitFrames = EW.unitFrames or {}
local function unitFrame(i)
    local f = EW.unitFrames[i]
    if not f then
        f = CreateFrame("Frame")
        f:SetScript("OnEvent", onUnitEvent)
        EW.unitFrames[i] = f
    end
    return f
end

--- Whether a prediction is wanted at all right now.
local function wanted()
    if secretsGate() or NS.IsStoodDown() or NS.State.testMode then return false end
    local p = NS.db and NS.db.profile
    return (p and not p.locked) and true or false
end

--- Which unit frames a watched container needs: player or pet, target or focus.
local function unitsWanted()
    local player, other = false, false
    local CM = NS.ContainerManager
    for _, inst in pairs(CM and CM.instances or {}) do
        local cfg = inst.watchEmpty and inst:Cfg()
        local unit = cfg and cfg.unit
        if unit == "player" or unit == "pet" then player = true
        elseif unit == "target" or unit == "focus" then other = true end
    end
    return player, other
end

local function openPlayer()
    local f, rejected = unitFrame(1), NS.RejectedEvents
    onPlayer = NS.SafeRegisterUnitEvent(f, "UNIT_AURA", rejected, "player", "pet")
    if onPlayer then
        NS.SafeRegisterEvent(events, "UNIT_PET", onPlayerUnit, rejected)
        NS.SafeRegisterEvent(events, "UNIT_INVENTORY_CHANGED", onPlayerUnit, rejected)
    end
end

local function openOther()
    onOther = NS.SafeRegisterUnitEvent(unitFrame(2), "UNIT_AURA", NS.RejectedEvents, "target", "focus")
    if onOther then
        NS.SafeRegisterEvent(events, "PLAYER_TARGET_CHANGED", onUnitSwitch, NS.RejectedEvents)
        NS.SafeRegisterEvent(events, "PLAYER_FOCUS_CHANGED", onUnitSwitch, NS.RejectedEvents)
    end
end

local function closePlayer()
    if EW.unitFrames[1] then EW.unitFrames[1]:UnregisterAllEvents() end
    events:UnregisterEvent("UNIT_PET")
    events:UnregisterEvent("UNIT_INVENTORY_CHANGED")
    onPlayer = false
end

local function closeOther()
    if EW.unitFrames[2] then EW.unitFrames[2]:UnregisterAllEvents() end
    events:UnregisterEvent("PLAYER_TARGET_CHANGED")
    events:UnregisterEvent("PLAYER_FOCUS_CHANGED")
    onOther = false
end

--- Stop listening: both unit frames closed by hand (AceEvent never reaches them), the AceEvent
--- ones dropped, and a queued pass or expiry timer canceled.
function EW.Stop()
    if onPlayer then closePlayer() end
    if onOther then closeOther() end
    if passTimer then passTimer:Cancel() end
    if expiryTimer then expiryTimer:Cancel() end
    passTimer, expiryTimer, expiryDue = nil, nil, nil
end

--- Listen, or stop, from the state now: called after every visibility pass and apply pass
--- (modules/ContainerManager.lua). Listening schedules one pass, which catches an engine that had
--- not yet gathered when the visibility pass predicted.
function EW.Sync()
    if not wanted() then return EW.Stop() end
    local player, other = unitsWanted()
    if player and not onPlayer then openPlayer() elseif onPlayer and not player then closePlayer() end
    if other and not onOther then openOther() elseif onOther and not other then closeOther() end
    if onPlayer or onOther then schedulePass() else EW.Stop() end
end

--- The combat edge, from core/AuraMaster.lua's OnCombatChanged BEFORE its visibility pass:
--- PLAYER_REGEN_DISABLED fires before lockdown begins, so that pass can still move every follower
--- onto its engine, predicting nil. PLAYER_REGEN_ENABLED lets the next pass predict again.
function EW.SetCombat(on)
    combat = on and true or false
    if combat then EW.Stop() end
end

--- Aura secrecy started or stopped (ADDON_RESTRICTION_STATE_CHANGED): re-predict what is watched,
--- which answers nil while secret, then listen or stop.
function EW.Refresh()
    EW.Reevaluate()
    EW.Sync()
end

--- Whether a pass or an expiry timer is still armed (a test seam).
function EW.__pending()
    return (passTimer ~= nil) or (expiryTimer ~= nil)
end
