local addonName, NS = ...

-- core/DebugLogSetup.lua — the LibKa0s-DebugLog-1.0 seam: the on-screen debug console.
--
-- The console window, the copy window, both formatters, the 3000-line buffer, the scrollbar and the
-- enable seam are the library's and are NOT in this addon's source (debug-logging). This file supplies
-- only what is ours: the frame-name prefix, the title, the monospace face, where the flag lives, and
-- what the [Init] session summary says.
--
-- LOAD-BEARING POSITION: after core/Constants.lua (FONT_MONO), core/State.lua (the flag) and
-- core/CoreSetup.lua (NS.Print / NS.SafeToString), and before anything that calls NS.Debug.

local lib = LibStub and LibStub("LibKa0s-DebugLog-1.0", true)

-- Keys NS.DebugOnce has logged this session: the tag, the site and the error's first line.
local loggedOnce = {}

--- An error a pcall of ours caught, logged ONCE per distinct error (debug-logging-§8, "Errors
--- caught"): `[<tag>] <site> failed: <first line>`, or `<site> #<id> failed: ...` with an `id`. A
--- guarded call on a repeating path (a restyle of forty buttons, a refresh on every target swap)
--- that keeps failing the same way writes one line, not one per pass (§9). Gated first: with logging
--- off it builds and records nothing, so an error first met then is logged once logging is on.
function NS.DebugOnce(tag, site, err, id)
    if not (NS.State and NS.State.debug and NS.Debug) then return end
    local first = tostring(err):match("^[^\n]*")
    local key = ("%s|%s|%s|%s"):format(tostring(tag), tostring(site), tostring(id), first)
    if loggedOnce[key] then return end
    loggedOnce[key] = true
    if id ~= nil then
        NS.Debug(tag, "%s #%s failed: %s", site, id, first)
    else
        NS.Debug(tag, "%s failed: %s", site, first)
    end
end

if not lib then
    -- Degrade, never error. The stub answers EVERY member the addon calls — `/am debug`, the Master
    -- controls tab's console row and core/PerfSetup.lua's log sink all reach for one — and the flag
    -- itself still works, because NS.State.debug is ours. What is lost is the window, said once.
    local missing = NS.L["%s, so the debug console window is unavailable."]:format(NS.LIBKA0S_MISSING)
    local announced = false
    local function sayOnce()
        if announced then return end
        announced = true
        if NS.Print then NS.Print(missing) end
    end

    -- No formatters here: nothing in the addon calls them, and a copy of the library's line format is
    -- the one duplicate testing-§8 forbids.
    NS.DebugLog = {
        buffer = {},
        Add             = function() end,
        Debug           = function() end,
        -- The console's change gates and at-enable queue (DebugLog 18, DebugLogGates 1): gated off
        -- with no console, so each answers false, as the library does with logging off.
        DebugOnce       = function() return false end,
        DebugChanged    = function() return false end,
        DebugForget     = function() end,
        DebugAtEnable   = function() return false end,
        Clear           = function() end,
        Show            = function() sayOnce() end,
        Hide            = function() end,
        Toggle          = function() sayOnce() end,
        IsShown         = function() return false end,
        IsEnabled       = function() return NS.State and NS.State.debug or false end,
        SetEnabled      = function(_, on)
            on = not not on
            if NS.State then NS.State.debug = on end
            -- Two whole sentences; the color is a layout-only wrap with no words in it.
            if NS.Printf then
                NS.Printf(on and "|cff40ff40%s|r" or "|cffff4040%s|r",
                    on and NS.L["Debug logging on."] or NS.L["Debug logging off."])
            end
            if on then sayOnce() end
        end,
        RefreshHeader   = function() end,
        ShowCopy        = function() sayOnce() end,
        UpdateScrollBar = function() end,
        UpdateStatus    = function() end,
        BufferSize      = function() return 0 end,
        LastLine        = function() return nil end,
        FindLine        = function() return nil end,
        MakeCloseButton = function() return nil end,
        -- The diagnostics report (DebugLog 14.1, debug-logging-§14). With no console there is nowhere
        -- to write it, so one line says so and nothing is written: 0 lines, as the library counts.
        RunDiagnostics  = function()
            if NS.Printf then
                NS.Printf(NS.L["%s is unavailable: the LibKa0s library did not load."], "/am diagnostics")
            end
            return 0
        end,
        BuildDiagnostics = function()
            return { lines = {}, dropped = 0, capped = false, capsHit = false }
        end,
        -- `false` for every word, so the host's own `/am debug` fallback answers.
        DebugVerb       = function() return false end,
        ConsoleCheckbox = function()
            return {
                label   = NS.L["Debug console"],
                tooltip = missing,
                get = function() return false end,
                set = function() sayOnce() end,
            }
        end,
    }
    NS.Debug = NS.DebugLog.Debug
    return
end

--- What the [Init] line adds when something is not as a healthy session has it, each once per
--- enable (debug-logging-§8, "Dependencies" and the stand-down state): a missing optional library,
--- no aura container API, a stood-down addon. Nothing on a healthy session, so its line is unchanged.
local function initNotes()
    local notes = {}
    if not (LibStub and LibStub("LibSharedMedia-3.0", true)) then
        notes[1] = "LibSharedMedia-3.0 missing (media-pack fonts and textures fall back)"
    end
    local C = NS.Compat
    if C and C.HasAuraContainer and not C.HasAuraContainer() then
        local n = #notes
        notes[n + 1] = "no aura container API (containers are not drawn)"
    end
    if NS.IsStoodDown and NS.IsStoodDown() then
        local n = #notes
        notes[n + 1] = "stood down (holds: " .. (NS.HoldsText and NS.HoldsText() or "?") .. ")"
    end
    return notes
end

NS.DebugLog = lib:New({
    -- Seeds AuraMasterDebugWindow / …DebugCopyWindow. Two hosts sharing a name would clobber each
    -- other's globals and Esc handlers.
    name      = addonName,
    -- THE FOLDER NAME, a different question from `name` even though this addon answers both with one
    -- string: `addonName` is what the library builds texture paths from, so the console's close, copy
    -- and clear controls draw the collection's marks. Passed explicitly, never inferred.
    addonName = addonName,
    title     = "Aura Master",
    -- The diagnostics report's markers name the full brand (debug-logging-§14 STD-08), not the
    -- console's short title.
    brandName = "Ka0s Aura Master",
    font      = NS.Constants.FONT_MONO,
    slash     = "/am",

    -- The flag stays ours. The library never stores a copy: a second copy would be a second truth.
    isEnabled  = function() return NS.State and NS.State.debug or false end,
    setEnabled = function(on) if NS.State then NS.State.debug = on end end,

    -- CALL-TIME forwarders, never captured references: NS.Print is reclaimed from AceConsole's embed
    -- in core/AuraMaster.lua, which loads after this file.
    print        = function(line) NS.Print(line) end,
    safeToString = function(v) return NS.SafeToString(v) end,

    -- The one chat line a report prints, through our locale. A plain table the library rawgets from,
    -- never NS.L itself: its key-echo fallback would answer every other key with the key.
    L = {
        DIAG_WRITTEN = NS.L["Diagnostic report written to the debug console: %s lines. Use Copy to share it."],
    },

    -- The report's sections (modules/Diagnostics.lua, which loads after this file), fetched per run.
    diagnostics = function()
        return NS.Diagnostics and NS.Diagnostics.Sections and NS.Diagnostics.Sections() or {}
    end,

    initSummary = function()
        local schemaVer = NS.db and NS.db.global and NS.db.global.schemaVersion
        local profile = NS.db and NS.db.GetCurrentProfile and NS.db:GetCurrentProfile()
        local containers = NS.ContainerManager and NS.ContainerManager.Count and NS.ContainerManager.Count()
        local line = ("%s v%s, schema v%s, profile '%s', %s container(s)"):format(
            NS.SafeToString(NS.name), NS.SafeToString(NS.Version and NS.Version() or NS.version),
            NS.SafeToString(schemaVer or "?"), NS.SafeToString(profile or "?"),
            NS.SafeToString(containers or "?"))
        -- Where a player sees the event names this client refused (events-frames-taint-§1). Read at
        -- call time: the library calls this each time logging turns on.
        local rejected = NS.RejectedEvents or {}
        local count = #rejected
        if count > 0 then
            line = line .. ", rejected events: " .. table.concat(rejected, ", ")
        end
        local notes = initNotes()
        if notes[1] then line = line .. ", " .. table.concat(notes, ", ") end
        return line
    end,

    -- The Master controls tab's console row mirrors the window, so `/am debug` has to move the
    -- checkbox on an options panel that is already open.
    onVisibilityChanged = function()
        if NS.Helpers and NS.Helpers.RefreshAllPanels then NS.Helpers.RefreshAllPanels() end
    end,
})

-- The gated sink (debug-logging-§4), bound bare so call sites stay `NS.Debug("Tag", "%s", v)`.
NS.Debug = NS.DebugLog.Debug
