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
-- seconds later. The font strings are kept: the fonts stay loaded, and a triple is never primed twice.
--
-- WHEN. From CM.StartListening (login and stand-up, before the first build), from the CONFIG_CHANGED
-- handler before the apply is requested, and from CM.Announce before a profile switch or a registry
-- change is built. Never while stood down: FontPrimer.Stop runs from CM.StopListening and cancels
-- both timers.
--
-- THE REFRESH. A triple primed after live bars already drew in it (a font changed in settings, or a
-- /reload that builds with auras present) leaves those names blank, so a PrimeAll that primed anything
-- arms one refresh REFRESH seconds later: ContainerClass:Refresh (the engine's UpdateAllAuras) on each
-- live instance that has an engine, is neither parked nor stale, and is shown and not previewing (a
-- disabled engine would clear its auras). Re-arming restarts it. It is the only engine call made here.

NS.FontPrimer = NS.FontPrimer or {}
local FP = NS.FontPrimer

local HOLD = 1.0      -- seconds the frame stays shown after the last new triple
local REFRESH = 0.5   -- seconds from priming a new triple to the follow-up refresh

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

--- Every eligible live instance gets one UpdateAllAuras.
local function refresh()
    refreshTimer = nil
    if NS.IsStoodDown() then return end
    local CM = NS.ContainerManager
    for _, inst in pairs(CM and CM.instances or {}) do
        if inst.engine and not inst.parked and not inst.staleData then
            local show, previewing = inst:ShouldShow()
            if show and not previewing then inst:Refresh() end
        end
    end
end

local function hide()
    holdTimer = nil
    if frame then frame:Hide() end
end

--- Show the frame for HOLD more seconds and (re)arm the one refresh.
local function armAfterPrime()
    frame:Show()
    if holdTimer then holdTimer:Cancel() end
    holdTimer = C_Timer.NewTimer(HOLD, hide)
    if refreshTimer then refreshTimer:Cancel() end
    refreshTimer = C_Timer.NewTimer(REFRESH, refresh)
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

--- Stand-down: cancel both timers and hide the frame. The primed set stays: the fonts stay loaded.
function FP.Stop()
    if holdTimer then holdTimer:Cancel() end
    if refreshTimer then refreshTimer:Cancel() end
    holdTimer, refreshTimer = nil, nil
    if frame then frame:Hide() end
end

--- State for the diagnostics report, read only: the primed triples (copies, in priming order) and
--- whether the refresh is armed.
--- @return table { primed = { { path, size, flags }, ... }, refresh = boolean }
function FP.DiagState()
    local list = {}
    for i, e in ipairs(primed) do list[i] = { path = e.path, size = e.size, flags = e.flags } end
    return { primed = list, refresh = refreshTimer ~= nil }
end

--- The primer's frame, or nil before anything was primed (a test seam).
function FP.__frame() return frame end
