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
-- A triple whose SetFont the client refuses is not primed: it goes on a refused set, and every later
-- priming, and the loading screen's end, tries it again on the same font string (FP-07; the owner's
-- run of 6994c46 had every Ka0s Prototype triple refused at PLAYER_LOGIN and never tried again).
--
-- HOW. One 1x1 frame on UIParent, placed above the top edge of the screen and SHOWN: each new triple
-- gets a font string on it, set to the triple and written with SAMPLE. The frame is hidden again HOLD
-- seconds later (WORLD_HOLD after the loading screen ends for a login priming, below). The font
-- strings are kept: the fonts stay loaded, and a triple is never primed twice. A refused triple
-- keeps its one font string for every retry.
--
-- WHEN. From CM.StartListening (login and stand-up, before the first build), from the CONFIG_CHANGED
-- handler before the apply is requested, and from CM.Announce before a profile switch or a registry
-- change is built. Never while stood down: FontPrimer.Stop runs from CM.StopListening and cancels
-- both timers.
--
-- THE LOADING SCREEN (FP-06). Nothing is drawn while the loading screen shows, so the priming at
-- PLAYER_LOGIN loads nothing by itself: a hide and a refresh armed then both ran under the loading
-- screen, and the auras present at login stayed blank. A PrimeAll before the first loading screen
-- ends therefore shows the frame and arms nothing. The client fires PLAYER_ENTERING_WORLD while the
-- loading screen is still up, and LOADING_SCREEN_DISABLED when it ends, seconds later on a slow or
-- cold-cache login. FontPrimer.OnLoadingScreenEnd (from addon:OnLoadingScreenEnd) is the anchor: it
-- runs a priming pass first (a font refused under the loading screen is retried now), then keeps the
-- frame shown and arms the hide at WORLD_HOLD and the refresh at WORLD_REFRESH, when anything was
-- primed since the last loading screen, and clears that mark. FontPrimer.OnEnterWorld
-- (from addon:OnEnterWorld) only notes the time, for the Fonts debug line and the report's
-- `loading screen:` line that show the gap, and is the anchor itself only on a client that refused LOADING_SCREEN_DISABLED (NS.RejectedEvents). A
-- loading screen with nothing newly primed arms nothing. A stood-down addon hears neither event, so
-- FontPrimer.Stop ends the wait: a stand-up happens in play.
--
-- THE REFRESH. A triple primed after text was already drawn in it (a font changed in settings, or a
-- /reload that builds with auras present) leaves that text blank, so a PrimeAll that primed anything
-- arms one refresh REFRESH seconds later (WORLD_REFRESH after the loading screen ends for a login
-- priming, above). It rewrites both kinds of text. The engine's: ContainerClass:
-- Refresh (UpdateAllAuras) on each live instance that has an engine, is neither parked nor stale, and
-- is shown and not previewing (a disabled engine would clear its auras); it is the only engine call
-- made here. The addon's own, written once per apply and by nothing later (the name label, a Text
-- line's literal pieces, the test-mode placeholders): one system apply of every container
-- (CM.RequestApply(nil, true)), which waits quietly if an apply has to. Re-arming restarts it.

NS.FontPrimer = NS.FontPrimer or {}
local FP = NS.FontPrimer

local HOLD = 1.0      -- seconds the frame stays shown after the last new triple
local REFRESH = 0.5   -- seconds from priming a new triple to the follow-up refresh
local WORLD_HOLD = 2.0     -- seconds the frame stays shown after the loading screen ends
local WORLD_REFRESH = 1.5  -- seconds from the loading screen's end to the follow-up refresh
local SCREEN_END = "LOADING_SCREEN_DISABLED"

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
local refusedAt = {}  -- [file][size][flags] = its `refused` entry: refused by SetFont, not primed yet
local refused = {}    -- { path, size, flags, fs } in the order first refused; every priming retries them
-- The "refused" line's key in the console's change gate (DebugLog 18, DebugLogGates 1): a priming
-- runs on every settings write (a slider drag is dozens), so the line is written only when the count
-- moves (debug-logging-§9), and a Clear or turning logging on re-arms it.
local REFUSED_KEY = "FontPrimer.refused"
local holdTimer, refreshTimer
local refreshAt           -- "play" or "world": which refresh refreshTimer is, for the report
local inWorld = false     -- the first loading screen has ended (or a stand-down ended the wait)
local primedSinceLoad = false   -- something was primed since the last loading screen
local pendingEnter        -- GetTime() at a PLAYER_ENTERING_WORLD no loading screen's end has paired yet
local lastEnter, lastEnd  -- GetTime() at the last PLAYER_ENTERING_WORLD and loading screen's end (report)

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

--- The [flags] table for `path` and `size` under `root`, built on first use: one table per file and
--- per size, never one per look-up.
local function flagsOf(root, path, size)
    local bySize = root[path]
    if not bySize then
        bySize = {}
        root[path] = bySize
    end
    local byFlags = bySize[size]
    if not byFlags then
        byFlags = {}
        bySize[size] = byFlags
    end
    return byFlags
end

--- Draw one triple on the frame, on `fs` when an earlier refused try made one (one font string per
--- triple, however many tries). Answers whether the client accepted the font, and the font string.
local function prime(path, size, flags, fs)
    if not fs then
        fs = ensureFrame():CreateFontString(nil, "OVERLAY")
        fs:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    end
    if not fs:SetFont(path, size, flags) then return false, fs end
    fs:SetText(FP.SAMPLE)
    return true, fs
end

local function markPrimed(path, size, flags)
    flagsOf(seen, path, size)[flags] = true
    primed[#primed + 1] = { path = path, size = size, flags = flags }
end

--- Prime one text block's triple if it is new, not built in and not on the refused set (retryRefused
--- tries those). Only an accepted font is marked primed (FP-07); a refused one joins the refused set.
--- Answers how many it primed and how many it refused, each 0 or 1.
local function primeBlock(t, tdef)
    if type(t) ~= "table" or type(tdef) ~= "table" then return 0, 0 end
    local path, size, flags = NS.Style.FontKey(t, tdef)
    if builtIn(path) or flagsOf(seen, path, size)[flags] then return 0, 0 end
    local byFlags = flagsOf(refusedAt, path, size)
    if byFlags[flags] then return 0, 0 end
    local ok, fs = prime(path, size, flags)
    if ok then
        markPrimed(path, size, flags)
        return 1, 0
    end
    local e = { path = path, size = size, flags = flags, fs = fs }
    byFlags[flags] = e
    refused[#refused + 1] = e
    return 0, 1
end

--- Try every refused triple again, on its own font string; one accepted is primed and leaves the set.
--- Answers how many it primed and how many stay refused.
local function retryRefused()
    local n, kept = 0, 0
    local count = #refused
    for i = 1, count do
        local e = refused[i]
        refused[i] = nil
        if prime(e.path, e.size, e.flags, e.fs) then
            refusedAt[e.path][e.size][e.flags] = nil
            markPrimed(e.path, e.size, e.flags)
            n = n + 1
        else
            kept = kept + 1
            refused[kept] = e
        end
    end
    return n, kept
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

--- One priming pass: the refused set retried, then every triple the active profile's containers use
--- that is neither primed nor refused. Arms nothing. A no-op while stood down. One Fonts line for what
--- it primed and one for what stays refused, counts only. Answers how many triples it primed.
local function primePass()
    if NS.IsStoodDown() then return 0 end
    local n, r = retryRefused()
    local D = NS.CONTAINER_TEMPLATE
    for _, c in ipairs(NS.Database.GetContainers()) do
        for _, b in ipairs(BLOCKS) do
            local block, def = c[b[1]], D[b[1]]
            local p, q = primeBlock(block and block[b[2]], def and def[b[2]])
            n, r = n + p, r + q
        end
    end
    if NS.Debug and n > 0 then NS.Debug("Fonts", "primed %d new font(s)", n) end
    -- A retry the client accepts is the `primed` line above; the count going to 0 writes nothing.
    local Dl = NS.DebugLog
    if Dl and Dl.DebugChanged then
        if r > 0 then
            Dl.DebugChanged(REFUSED_KEY, "Fonts", "%d font(s) refused, retried at the next priming", r)
        else
            Dl.DebugForget(REFUSED_KEY)
        end
    end
    return n
end

--- Prime every font triple the active profile's containers use that has not been primed yet, and
--- retry every refused one. A no-op while stood down. Answers how many triples it primed.
function FP.PrimeAll()
    local n = primePass()
    if n > 0 then armAfterPrime() end
    return n
end

--- The loading screen has ended. First a priming pass: a font the client refused under the loading
--- screen is tried again now it is gone (FP-07), and one it accepts counts as newly primed. Anything
--- primed since the last loading screen is drawn only now, so the frame stays shown for WORLD_HOLD and
--- one refresh runs at WORLD_REFRESH; then the mark clears. Nothing newly primed arms nothing.
local function worldReady()
    inWorld = true
    if NS.IsStoodDown() then return end
    if primePass() > 0 then primedSinceLoad = true end
    if not primedSinceLoad then return end
    primedSinceLoad = false
    arm(WORLD_HOLD, WORLD_REFRESH, "world")
end

--- Whether this client refused LOADING_SCREEN_DISABLED, so the loading screen's end is never heard.
local function screenEndRefused()
    for _, name in ipairs(NS.RejectedEvents or {}) do
        if name == SCREEN_END then return true end
    end
    return false
end

--- PLAYER_ENTERING_WORLD, from addon:OnEnterWorld. The loading screen is still up: this only notes
--- the time for the gap line, unless this client cannot say when the loading screen ends, when it is
--- the best anchor there is.
function FP.OnEnterWorld()
    local now = GetTime()
    pendingEnter, lastEnter, lastEnd = now, now, nil
    if not screenEndRefused() then return end
    if NS.Debug then
        NS.Debug("Fonts", "PLAYER_ENTERING_WORLD at %.2f, no %s on this client: timing from here",
            now, SCREEN_END)
    end
    worldReady()
end

--- LOADING_SCREEN_DISABLED, from addon:OnLoadingScreenEnd: the loading screen is gone. Logs both
--- timestamps (the smoke check STYLE-29 reads the gap), then arms the world timers.
function FP.OnLoadingScreenEnd()
    local now = GetTime()
    lastEnd = now
    if NS.Debug then
        if pendingEnter then
            NS.Debug("Fonts", "PLAYER_ENTERING_WORLD at %.2f, loading screen ended at %.2f (%.2f s later)",
                pendingEnter, now, now - pendingEnter)
        else
            NS.Debug("Fonts", "loading screen ended at %.2f, no PLAYER_ENTERING_WORLD before it", now)
        end
    end
    pendingEnter = nil
    worldReady()
end

--- Stand-down: cancel every timer and hide the frame. The primed set stays: the fonts stay loaded.
--- It also ends any wait for the world: a stood-down addon hears no loading-screen event, and the
--- stand-up that follows happens in play.
function FP.Stop()
    if holdTimer then holdTimer:Cancel() end
    if refreshTimer then refreshTimer:Cancel() end
    holdTimer, refreshTimer, refreshAt = nil, nil, nil
    inWorld = true
    if frame then frame:Hide() end
end

--- The refresh's state for the report: "armed" (the short one, in play), "armed-world" (from the
--- loading screen's end), "awaiting-world" (primed under the first loading screen, nothing armed
--- yet) or "idle".
local function refreshState()
    if refreshTimer then return refreshAt == "world" and "armed-world" or "armed" end
    if not inWorld and primedSinceLoad then return "awaiting-world" end
    return "idle"
end

--- Copies of `list`'s triples, in order.
local function copies(list)
    local out = {}
    for i, e in ipairs(list) do out[i] = { path = e.path, size = e.size, flags = e.flags } end
    return out
end

--- State for the diagnostics report, read only: the primed triples (copies, in priming order), the
--- triples the client refused and no retry has primed yet (copies, in the order first refused),
--- whether the refresh is armed, which state it is in, and the GetTime() of the last
--- PLAYER_ENTERING_WORLD and of the last loading screen's end after it (nil when not seen).
--- @return table { primed = { { path, size, flags }, ... }, refused = { { path, size, flags }, ... },
---   refresh = boolean, state = string, enteredAt = number|nil, screenEndAt = number|nil }
function FP.DiagState()
    return { primed = copies(primed), refused = copies(refused), refresh = refreshTimer ~= nil,
        state = refreshState(), enteredAt = lastEnter, screenEndAt = lastEnd }
end

--- The primer's frame, or nil before anything was primed (a test seam).
function FP.__frame() return frame end
