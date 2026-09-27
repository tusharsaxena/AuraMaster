local _, NS = ...

-- modules/NameRepaint.lua — the blank bar name repaint (issue #24). Blizzard's aura engine writes a
-- bar's spell name from `auraData.name` when an aura is assigned to a button or updated, and at no
-- other time. On a first sighting that name can still be nil, the engine writes an empty string, and
-- an aura that never updates again keeps the blank for its whole life
-- (docs/superpowers/research/2026-09-27-blank-bar-names-findings.md). The repaint is the engine's own
-- UpdateAllAuras, through ContainerClass:Refresh, which rereads every aura and rewrites every name.
-- It is not a protected call, so it runs in combat and while auras are secret. Nothing else is sent:
-- no apply, no restyle and no button access.
--
-- HOW IT LISTENS. UNIT_AURA takes events-frames-taint-§1's unit-filter frame carve-out, as
-- modules/EmptyWatch.lua does: two frames, held on the module (NR.unitFrames), built once, hidden and
-- reused, one for player and pet and one for target and focus. A frame registers only the units that
-- have at least one enabled container showing an engine-written name (Style.ShowsEngineName), and is
-- closed with UnregisterAllEvents when none is left. Unlike EmptyWatch and TimedSpells, the listener
-- STAYS OPEN in combat and while auras are secret: first sightings happen mostly in combat, and the
-- handler reads nothing but its unit argument, and that only once NS.Secrets.IsSafeKey proves it
-- readable.
--
-- WHEN IT REPAINTS. Per unit, in two stages. The first UNIT_AURA of a quiet unit arms QUICK; when it
-- fires, the unit is repainted and SETTLE is always armed, to catch data that arrived late. When
-- SETTLE fires, the unit is repainted again, and SETTLE is rearmed only if the unit went dirty in the
-- meantime. So a single new aura gets two repaints, and constant churn one every SETTLE seconds.
-- A loading screen (NameRepaint.OnEnterWorld) arms every listened unit at ENTER, replacing any armed
-- timer, and a unit swap arms its unit (NameRepaint.Arm). The callbacks are built once at load, so
-- the event path allocates nothing, and nothing arms while stood down (slash-commands-§7).

NS.NameRepaint = NS.NameRepaint or {}
local NR = NS.NameRepaint
local Perf = NS.Perf

local QUICK  = 0.5   -- from the first UNIT_AURA of a quiet unit to its first repaint
local SETTLE = 2.0   -- from a repaint to the follow-up that catches data which arrived late
local ENTER  = 3.0   -- from PLAYER_ENTERING_WORLD to the first repaint of every listened unit

-- The two frames' unit pairs: RegisterUnitEvent allows two units per frame.
local PAIRS = { { "player", "pet" }, { "target", "focus" } }
-- Which units each frame holds registered right now, by frame and slot in PAIRS.
local held = { { false, false }, { false, false } }

-- Per unit: its armed timer, the stage that timer runs, and whether UNIT_AURA came since the last pass.
local timers, stages, dirty = {}, {}, {}
local firstFire, settleFire = {}, {}   -- the prebuilt timer callbacks, per unit

-- ---------------------------------------------------------------------------
-- The pass
-- ---------------------------------------------------------------------------

--- Whether live container `inst` shows an engine-written name for `unit` and may be repainted: it
--- has an engine, is neither parked nor stale, shows and is not previewing (exactly when ApplyLive has
--- its engine enabled; a disabled engine would clear its auras on UpdateAllAuras).
local function eligible(inst, unit)
    if not inst.engine or inst.parked or inst.staleData then return false end
    local cfg = inst:Cfg()
    if not (cfg and cfg.unit == unit and NS.Style.ShowsEngineName(cfg)) then return false end
    local show, previewing = inst:ShouldShow()
    return show and not previewing
end

--- Repaint every eligible container on `unit`: one UpdateAllAuras each. Runs in combat and while
--- auras are secret. `stage` names the timer that asked, for the trace. Returns how many it reached.
--- @return number
function NR.Repaint(unit, stage)
    local t0 = Perf.on and debugprofilestop()
    local CM = NS.ContainerManager
    local n = 0
    for _, inst in pairs(CM and CM.instances or {}) do
        if eligible(inst, unit) then
            inst:Refresh()
            n = n + 1
        end
    end
    if t0 then Perf.Note("nameRepaint", debugprofilestop() - t0) end
    if NS.Debug then NS.Debug("Names", "repaint %s: %d container(s) (%s)", unit, n, stage or "direct") end
    return n
end

-- ---------------------------------------------------------------------------
-- The timers
-- ---------------------------------------------------------------------------

local function arm(unit, delay, stage, fire)
    stages[unit] = stage
    timers[unit] = C_Timer.NewTimer(delay, fire[unit])
end

-- Clearing the dirty mark is defensive: onFirst clears it before SETTLE is armed, so a stale mark
-- never reaches onSettle.
local function cancel(unit)
    if timers[unit] then timers[unit]:Cancel() end
    timers[unit], stages[unit], dirty[unit] = nil, nil, nil
end

--- Whether `unit` is registered on its frame right now.
local function listened(unit)
    for i, pair in ipairs(PAIRS) do
        if pair[1] == unit then return held[i][1] end
        if pair[2] == unit then return held[i][2] end
    end
    return false
end

--- QUICK or ENTER fired: repaint, then always follow up at SETTLE.
local function onFirst(unit)
    local stage = stages[unit]
    timers[unit], dirty[unit] = nil, nil
    if NS.IsStoodDown() or not listened(unit) then return cancel(unit) end
    NR.Repaint(unit, stage)
    arm(unit, SETTLE, "settle", settleFire)
end

--- SETTLE fired: repaint, and follow up again only if the unit went dirty since the last pass.
local function onSettle(unit)
    local again = dirty[unit]
    timers[unit], dirty[unit] = nil, nil
    if NS.IsStoodDown() or not listened(unit) then return cancel(unit) end
    NR.Repaint(unit, "settle")
    if again then arm(unit, SETTLE, "settle", settleFire) else stages[unit] = nil end
end

for _, pair in ipairs(PAIRS) do
    for _, unit in ipairs(pair) do
        firstFire[unit] = function() onFirst(unit) end
        settleFire[unit] = function() onSettle(unit) end
    end
end

--- Schedule a repaint of `unit`: QUICK when nothing is armed, else only a dirty mark, which
--- allocates nothing. A unit no frame listens for, and anything while stood down, arms nothing. The
--- UNIT_AURA handler's entry, and the one a target, focus or pet swap takes.
function NR.Arm(unit)
    if NS.IsStoodDown() or not listened(unit) then return end
    if timers[unit] then
        dirty[unit] = true
        return
    end
    arm(unit, QUICK, "quick", firstFire)
end

--- PLAYER_ENTERING_WORLD (addon:OnEnterWorld): every listened unit is armed at ENTER, replacing any
--- armed timer, and then follows the SETTLE path. Runs on every loading screen: new zones bring new
--- spells.
function NR.OnEnterWorld()
    if NS.IsStoodDown() then return end
    for _, pair in ipairs(PAIRS) do
        for _, unit in ipairs(pair) do
            if listened(unit) then
                cancel(unit)
                arm(unit, ENTER, "enter", firstFire)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Listening
-- ---------------------------------------------------------------------------

--- One frame's UNIT_AURA. The client filters by unit, but the kit's __fire does not, so a readable
--- unit counts only when it is one this frame holds registered. An unreadable one schedules every
--- unit the frame holds. The payload is never touched.
local function onUnitAura(i, unit)
    local pair, h = PAIRS[i], held[i]
    if NS.Secrets.IsSafeKey(unit) then
        if (unit == pair[1] and h[1]) or (unit == pair[2] and h[2]) then NR.Arm(unit) end
        return
    end
    if h[1] then NR.Arm(pair[1]) end
    if h[2] then NR.Arm(pair[2]) end
end

local handlers = {
    function(_, _, unit) onUnitAura(1, unit) end,
    function(_, _, unit) onUnitAura(2, unit) end,
}

NR.unitFrames = NR.unitFrames or {}
local function unitFrame(i)
    local f = NR.unitFrames[i]
    if not f then
        f = CreateFrame("Frame")
        -- Hidden: it still gets its events, and a shown parentless frame counts as on screen.
        f:Hide()
        f:SetScript("OnEvent", handlers[i])
        NR.unitFrames[i] = f
    end
    return f
end

--- Register frame `i` for the wanted units of its pair, or close it. Whether it is registered.
local function register(i, a, b)
    local pair, f = PAIRS[i], unitFrame(i)
    local ok = false
    if a and b then
        ok = NS.SafeRegisterUnitEvent(f, "UNIT_AURA", NS.RejectedEvents, pair[1], pair[2])
    elseif a or b then
        ok = NS.SafeRegisterUnitEvent(f, "UNIT_AURA", NS.RejectedEvents, a and pair[1] or pair[2])
    end
    if not ok then f:UnregisterAllEvents() end
    return ok and true or false
end

--- Frame `i` to exactly the wanted units of its pair. Only called when the pair it holds changes. A
--- unit it stops holding loses its timer and its dirty mark.
local function setFrame(i, a, b)
    local pair, h = PAIRS[i], held[i]
    local ok = register(i, a, b)
    local nowA, nowB = ok and a, ok and b
    if h[1] and not nowA then cancel(pair[1]) end
    if h[2] and not nowB then cancel(pair[2]) end
    h[1], h[2] = nowA, nowB
end

--- Which units have at least one enabled container showing an engine-written name. Four booleans,
--- not a table: Sync runs inside every visibility pass.
local function unitsWanted()
    local player, pet, target, focus = false, false, false, false
    local CM = NS.ContainerManager
    for _, inst in pairs(CM and CM.instances or {}) do
        local cfg = inst:Cfg()
        if cfg and cfg.enabled and NS.Style.ShowsEngineName(cfg) then
            local u = cfg.unit
            player = player or u == "player"
            pet = pet or u == "pet"
            target = target or u == "target"
            focus = focus or u == "focus"
        end
    end
    return player, pet, target, focus
end

--- Stop listening: both frames closed by hand, every timer canceled and every dirty mark cleared.
function NR.Stop()
    for i, pair in ipairs(PAIRS) do
        local f = NR.unitFrames[i]
        if f then f:UnregisterAllEvents() end
        held[i][1], held[i][2] = false, false
        cancel(pair[1])
        cancel(pair[2])
    end
end

--- Listen, or stop, from the containers now. Idempotent and allocation-free: a frame is touched only
--- when the pair it holds changes. While stood down it stops instead: the stand-down path runs a
--- visibility pass after its own Stop calls, and this must not reopen what that closed.
function NR.Sync()
    if NS.IsStoodDown() then return NR.Stop() end
    local player, pet, target, focus = unitsWanted()
    local h1, h2 = held[1], held[2]
    if h1[1] ~= player or h1[2] ~= pet then setFrame(1, player, pet) end
    if h2[1] ~= target or h2[2] ~= focus then setFrame(2, target, focus) end
end
