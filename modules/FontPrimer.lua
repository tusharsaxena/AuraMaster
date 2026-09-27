local _, NS = ...

-- modules/FontPrimer.lua — draws every font the containers use once, on a shown frame, before any
-- container text is drawn in it (issue #24).
--
-- WHY. WoW loads an addon-supplied font file lazily, and text first drawn in it before the load
-- completes comes out empty and stays empty until it is written again. The aura engine writes a bar's
-- name once, when the aura is assigned, so a name drawn in a font that has not loaded yet stays blank
-- (docs/superpowers/research/2026-09-27-blank-bar-names-findings.md, "Correction"). Drawing on a
-- hidden frame does not load the font; drawing on a shown one does.
--
-- WHAT. Every distinct (file, size, flags) triple any container in the active profile uses, enabled
-- or not, resolved by Style.FontKey, the same resolution Style.ApplyFont sets. A font under `Fonts\`
-- is built into the client, always loaded, and skipped. Each triple is primed once per session.
--
-- HOW. One 1x1 frame on UIParent, placed above the top edge of the screen and SHOWN: each new triple
-- gets a font string on it, set to the triple and written with SAMPLE. The frame is hidden again HOLD
-- seconds later (WORLD_HOLD after PLAYER_ENTERING_WORLD for a login priming, below). The font strings are kept: the fonts stay loaded, and a triple is never primed twice.
--
-- WHEN. From CM.StartListening (login and stand-up, before the first build), from the CONFIG_CHANGED
-- handler before the apply is requested, and from CM.Announce before a profile switch or a registry
-- change is built. Never while stood down: FontPrimer.Stop runs from CM.StopListening and cancels
-- both timers.
--
-- THE LOADING SCREEN (FP-06). Nothing is drawn while the loading screen shows, so the priming at
-- PLAYER_LOGIN loads nothing by itself: a hide and a refresh armed then both ran under the loading
-- screen, and the auras present at login stayed blank. A PrimeAll before the first
-- PLAYER_ENTERING_WORLD therefore shows the frame and arms nothing. FontPrimer.OnEnterWorld (from
-- addon:OnEnterWorld) then keeps the frame shown and arms the hide at WORLD_HOLD and the refresh at
-- WORLD_REFRESH, when anything was primed since the last loading screen, and clears that mark. A
-- loading screen with nothing newly primed arms nothing. A stood-down addon hears no
-- PLAYER_ENTERING_WORLD, so FontPrimer.Stop ends the wait: a stand-up happens in play.
--
-- THE REFRESH. A triple primed after text was already drawn in it (a font changed in settings, or a
-- /reload that builds with auras present) leaves that text blank, so a PrimeAll that primed anything
-- arms one refresh REFRESH seconds later (WORLD_REFRESH after PLAYER_ENTERING_WORLD for a login
-- priming, below). It rewrites both kinds of text. The engine's: ContainerClass:
-- Refresh (UpdateAllAuras) on each live instance that has an engine, is neither parked nor stale, and
-- is shown and not previewing (a disabled engine would clear its auras); it is the only engine call
-- made here. The addon's own, written once per apply and by nothing later (the name label, a Text
-- line's literal pieces, the test-mode placeholders): one system apply of every container
-- (CM.RequestApply(nil, true)), which waits quietly if an apply has to. Re-arming restarts it.

NS.FontPrimer = NS.FontPrimer or {}
local FP = NS.FontPrimer

local HOLD = 1.0      -- seconds the frame stays shown after the last new triple
local REFRESH = 0.5   -- seconds from priming a new triple to the follow-up refresh
local WORLD_HOLD = 2.0     -- seconds the frame stays shown after PLAYER_ENTERING_WORLD
local WORLD_REFRESH = 1.5  -- seconds from PLAYER_ENTERING_WORLD to the follow-up refresh

--- What each font string is written with: every character a name, time or stack count is likely to
--- draw (probe v4 drew this set and every blank went).
FP.SAMPLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789 .,:;!?'\"-+/()[]%&#*"

-- Every text block a container draws in, as { style block, key in it }; the label font sits one
-- level deeper, under `label.font`, and the Text line's under `text.font`.
local BLOCKS = {
    { "bars", "name" }, { "bars", "time" }, { "bars", "stacks" },
    { "icons", "time" }, { "icons", "stacks" },
    { "text", "font" }, { "label", "font" },
}

local frame
local seen = {}       -- [file][size][flags] = true, primed this session (no string built per look-up)
local primed = {}     -- { path, size, flags } in priming order, for the diagnostics report
local holdTimer, refreshTimer
local refreshAt           -- "play" or "world": which refresh refreshTimer is, for the report
local inWorld = false     -- the first PLAYER_ENTERING_WORLD has come (or a stand-down ended the wait)
local primedSinceLoad = false   -- something was primed since the last loading screen

--- Whether `path` is a font built into the client (always loaded).
local function builtIn(path)
    return type(path) ~= "string" or path:lower():find("^fonts[\\/]") ~= nil
end

local function ensureFrame()
    if frame then return frame end
    frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(1, 1)
    -- Above the screen's top edge: drawn, never seen (the text grows up from the frame).
    frame:SetPoint("BOTTOMLEFT", UIParent, "TOPLEFT", 0, 200)
    return frame
end

--- Draw one triple on the frame; true when the client accepted the font.
local function prime(path, size, flags)
    local f = ensureFrame()
    local fs = f:CreateFontString(nil, "OVERLAY")
    fs:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT")
    if not fs:SetFont(path, size, flags) then return false end
    fs:SetText(FP.SAMPLE)
    return true
end

--- Prime one text block's triple if it is new and not built in; answers 1 when it primed, else 0.
local function primeBlock(t, tdef)
    if type(t) ~= "table" or type(tdef) ~= "table" then return 0 end
    local path, size, flags = NS.Style.FontKey(t, tdef)
    if builtIn(path) then return 0 end
    local bySize = seen[path] or {}
    seen[path] = bySize
    local byFlags = bySize[size] or {}
    bySize[size] = byFlags
    if byFlags[flags] then return 0 end
    byFlags[flags] = true
    if not prime(path, size, flags) then return 0 end
    primed[#primed + 1] = { path = path, size = size, flags = flags }
    return 1
end

--- Every eligible live instance gets one UpdateAllAuras (the engine's text), and every container one
--- system apply (the addon's own text: labels, literal pieces, placeholders).
local function refresh()
    refreshTimer, refreshAt = nil, nil
    if NS.IsStoodDown() then return end
    local CM = NS.ContainerManager
    if not CM then return end
    for _, inst in pairs(CM.instances) do
        if inst.engine and not inst.parked and not inst.staleData then
            local show, previewing = inst:ShouldShow()
            if show and not previewing then inst:Refresh() end
        end
    end
    CM.RequestApply(nil, true)
end

local function hide()
    holdTimer = nil
    if frame then frame:Hide() end
end

--- Show the frame, and (re)arm the hide `hold` seconds and the one refresh `delay` seconds from now.
local function arm(hold, delay, at)
    frame:Show()
    if holdTimer then holdTimer:Cancel() end
    holdTimer = C_Timer.NewTimer(hold, hide)
    if refreshTimer then refreshTimer:Cancel() end
    refreshTimer, refreshAt = C_Timer.NewTimer(delay, refresh), at
end

--- After a priming that drew something: the short hide and refresh in play; before the world, the
--- frame shown and nothing armed (OnEnterWorld arms both).
local function armAfterPrime()
    primedSinceLoad = true
    if inWorld then
        arm(HOLD, REFRESH, "play")
    else
        frame:Show()
    end
end

--- Prime every font triple the active profile's containers use that has not been primed yet. A
--- no-op while stood down. Answers how many triples it primed.
function FP.PrimeAll()
    if NS.IsStoodDown() then return 0 end
    local D = NS.CONTAINER_TEMPLATE
    local n = 0
    for _, c in ipairs(NS.Database.GetContainers()) do
        for _, b in ipairs(BLOCKS) do
            local block, def = c[b[1]], D[b[1]]
            n = n + primeBlock(block and block[b[2]], def and def[b[2]])
        end
    end
    if n > 0 then
        armAfterPrime()
        if NS.Debug then NS.Debug("Fonts", "primed %d new font(s)", n) end
    end
    return n
end

--- PLAYER_ENTERING_WORLD, from addon:OnEnterWorld: the loading screen is gone. Anything primed since
--- the last one is drawn only now, so the frame stays shown for WORLD_HOLD and one refresh runs at
--- WORLD_REFRESH; then the mark clears. Nothing newly primed arms nothing.
function FP.OnEnterWorld()
    inWorld = true
    if NS.IsStoodDown() or not primedSinceLoad then return end
    primedSinceLoad = false
    arm(WORLD_HOLD, WORLD_REFRESH, "world")
end

--- Stand-down: cancel every timer and hide the frame. The primed set stays: the fonts stay loaded.
--- It also ends any wait for the world: a stood-down addon hears no PLAYER_ENTERING_WORLD, and the
--- stand-up that follows happens in play.
function FP.Stop()
    if holdTimer then holdTimer:Cancel() end
    if refreshTimer then refreshTimer:Cancel() end
    holdTimer, refreshTimer, refreshAt = nil, nil, nil
    inWorld = true
    if frame then frame:Hide() end
end

--- The refresh's state for the report: "armed" (the short one, in play), "armed-world" (from
--- PLAYER_ENTERING_WORLD), "awaiting-world" (primed before the world, nothing armed yet) or "idle".
local function refreshState()
    if refreshTimer then return refreshAt == "world" and "armed-world" or "armed" end
    if not inWorld and primedSinceLoad then return "awaiting-world" end
    return "idle"
end

--- State for the diagnostics report, read only: the primed triples (copies, in priming order),
--- whether the refresh is armed, and which state it is in.
--- @return table { primed = { { path, size, flags }, ... }, refresh = boolean, state = string }
function FP.DiagState()
    local list = {}
    for i, e in ipairs(primed) do list[i] = { path = e.path, size = e.size, flags = e.flags } end
    return { primed = list, refresh = refreshTimer ~= nil, state = refreshState() }
end

--- The primer's frame, or nil before anything was primed (a test seam).
function FP.__frame() return frame end
