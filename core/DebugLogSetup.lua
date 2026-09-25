local addonName, NS = ...

-- core/DebugLogSetup.lua — the LibKa0s-DebugLog-1.0 seam: the on-screen debug console.
--
-- The console window, the copy window, both formatters, the 1500-line buffer, the scrollbar and the
-- enable seam are the library's and are NOT in this addon's source (debug-logging). This file supplies
-- only what is ours: the frame-name prefix, the title, the monospace face, where the flag lives, and
-- what the [Init] session summary says.
--
-- LOAD-BEARING POSITION: after core/Constants.lua (FONT_MONO), core/State.lua (the flag) and
-- core/CoreSetup.lua (NS.Print / NS.SafeToString), and before anything that calls NS.Debug.

local lib = LibStub and LibStub("LibKa0s-DebugLog-1.0", true)

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

NS.DebugLog = lib:New({
    -- Seeds AuraMasterDebugWindow / …DebugCopyWindow. Two hosts sharing a name would clobber each
    -- other's globals and Esc handlers.
    name      = addonName,
    -- THE FOLDER NAME, a different question from `name` even though this addon answers both with one
    -- string: `addonName` is what the library builds texture paths from, so the console's close, copy
    -- and clear controls draw the collection's marks. Passed explicitly, never inferred.
    addonName = addonName,
    title     = "Aura Master",
    font      = NS.Constants.FONT_MONO,
    slash     = "/am",

    -- The flag stays ours. The library never stores a copy: a second copy would be a second truth.
    isEnabled  = function() return NS.State and NS.State.debug or false end,
    setEnabled = function(on) if NS.State then NS.State.debug = on end end,

    -- CALL-TIME forwarders, never captured references: NS.Print is reclaimed from AceConsole's embed
    -- in core/AuraMaster.lua, which loads after this file.
    print        = function(line) NS.Print(line) end,
    safeToString = function(v) return NS.SafeToString(v) end,

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
