local addonName, NS = ...

-- core/LauncherSetup.lua — the LibKa0s-Launcher-1.0 seam: the minimap button and the broker plugin
-- (launcher-§1).
--
-- ONE OBJECT, REGISTERED TWICE, and that is the whole point of the section. The library builds a
-- single LibDataBroker-1.1 object of `type = "launcher"` and hands THAT object to LibDBIcon-1.0, so
-- the minimap button and any broker display (Titan Panel, ElvUI data texts, Bazooka) draw from one
-- icon, one label and one OnClick. Two click handlers for one feature is anti-pattern #81, and it
-- cannot be written here because there is only one place to write it.
--
-- WHAT IS OURS AND NOTHING ELSE: the folder name, the logo, how the settings panel opens, and the
-- accessor-and-toggle pairs for the states this addon has. The object, the click dispatch, the
-- tooltip, the menu, the two LibStub lookups and the Show/Hide plumbing are the library's.
--
-- THE TWO BUTTONS (launcher-§2, standard v2.67.0; LibKa0s-Launcher-1.0 minor 4). LEFT-CLICK OPENS THE
-- SETTINGS PANEL, in either state. RIGHT-CLICK OPENS THE CLIENT'S CONTEXT MENU, one checkbox per
-- pair passed below: Enabled, Locked, Test mode. There is no Show window entry because this addon
-- has no primary window — its preview is the test mode (B1, 2026-09-19). While the addon is
-- disabled the library grays Locked and Test mode; Enabled stays live. Neither button is
-- reassignable and there is no setting for either.
--
-- EVERY TOGGLE IS THE SLASH VERB'S OWN HANDLER (settings/Slash.lua's NS.Slash.SetEnabled,
-- ToggleLock, ToggleTestMode), so the menu, the verb and the settings row are three doors onto one
-- switch, with one set of refusals and one set of chat lines. No copy of any state lives here.
--
-- THE MINIMAP TABLE IS PASSED AS A FUNCTION, not as a table. `NS.db` does not exist at file load —
-- core/Database.lua builds it in OnInitialize — and AceDB replaces whatever table was there, so a
-- table captured here would be the one nothing writes to. The library resolves it at Register time.
--
-- THE ROW THAT SHOWS AND HIDES IT IS NOT HERE. It is a composed Master controls row
-- (settings/General.lua's `minimapPath`), whose path is `global.minimap.shown` and whose storage is
-- `db.global.minimap.hide` in the GLOBAL store — global so a profile switch does not move the
-- player's buttons (launcher-§3). The row's label and path say SHOWN and LibDBIcon's key says
-- HIDDEN, so settings/Schema.lua's seam inverts once, in one place, and calls NS.Launcher:SetShown
-- from there.
--
-- AND IT SURVIVES EVERY RESET — a PROPERTY of the setting, not a consequence of the global store
-- (launcher-§3, standard v2.54.0). Whether the button is shown is a per-installation display
-- preference, the same class of thing as the POSITION LibDBIcon keeps in this very table and that no
-- reset touches. settings/OptionsSetup.lua holds the one veto that makes that true here, because
-- this addon's General page has a Defaults button that would otherwise walk the row back to shown.

local Launcher = LibStub and LibStub("LibKa0s-Launcher-1.0", true)

if not Launcher then
    -- Degrade, never error. Nothing in the addon reaches NS.Launcher except this file's Register and
    -- the write seam's inversion, but both would otherwise need a nil guard that says nothing about
    -- why, and the seam's `hide` write must still land so the player's choice survives a reload on a
    -- library-less build. So the stub answers every member of the live instance, honestly: nothing
    -- is registered, there is no object, and the stored `hide` is still the truth about the button.
    local missing = NS.L["%s, so the minimap button is unavailable."]:format(NS.LIBKA0S_MISSING)
    local announced = false
    local function sayOnce()
        if announced then return end
        announced = true
        if NS.Print then NS.Print(missing) end
    end

    --- The one table both halves read, or nil before the database exists.
    local function store()
        local g = NS.db and NS.db.global
        return type(g) == "table" and g.minimap or nil
    end

    NS.Launcher = {
        Register      = function() sayOnce() return false end,
        IsRegistered  = function() return false end,
        Object        = function() return nil end,
        -- From the STORE, exactly as the live instance answers it, so the Master controls checkbox
        -- shows what the player chose rather than reading `true` because nothing contradicted it.
        IsShown       = function()
            local t = store()
            if not t then return true end
            return not t.hide
        end,
        -- The store is updated; there is no button to move, which is what `false` reports.
        SetShown      = function(_, shown)
            local t = store()
            if t then t.hide = not shown end
            return false
        end,
    }
    return
end

NS.Launcher = Launcher:New({
    -- THE FOLDER NAME, and it is not cosmetic: LibDBIcon keys the button's saved position by it, so
    -- a second spelling would drop the angle the player dragged the button to and label the broker
    -- plugin with the other name. Both registrations take this one string.
    name  = addonName,
    -- The addon's own face, the same file `## IconTexture` names — never a Blizzard path and never a
    -- numeric file id (anti-pattern #82). The 128 file, not the landing page's 300x300 one.
    icon  = NS.Constants.LOGO_ICON_PATH,
    -- THE BRAND NAME IN PLAIN TEXT (launcher-§1). This is the string a broker display prints in its
    -- own row, beside the other ten Ka0s addons, so it is the one field that decides whether the
    -- collection reads as one collection in Titan Panel or as eleven unrelated addons. It is
    -- deliberately NOT the TOC's `## Title`: a Title may carry color escapes and one in the
    -- collection does, which would splatter that row across a list of plain-text ones. And it is not
    -- the folder name: `AuraMaster` is the registration identifier above, which LibDBIcon keys the
    -- saved position by; `Ka0s Aura Master` is the name a player reads. Two fields, two jobs.
    label = "Ka0s Aura Master",

    -- CALL-TIME, for the reason in the header: NS.db is AceDB's and arrives in OnInitialize.
    minimap = function() return NS.db and NS.db.global and NS.db.global.minimap end,

    -- LEFT-CLICK, ALWAYS, in either state: the panel is setup, and it is where a disabled addon is
    -- switched back on (slash-commands-§7 lists it among what survives a stand-down).
    openSettings = function() NS.OpenOptionsPanel() end,

    -- THE STATUS TOOLTIP IS THE LIBRARY'S (launcher-§1, LibKa0s-Launcher-1.0 minor 3). It draws the
    -- title, Enabled, Locked, Test mode and the two fixed click hints on every hover, disabled or not;
    -- the accessors below answer its questions and the menu's, each asked on the show or the open,
    -- never cached. There is no onTooltipShow: this addon has no lines of its own, and a hook that
    -- drew a title or a click hint would draw a second copy of the library's (anti-pattern #89).
    --
    -- The version is the TOC's `## Version`, through core/EnvSetup.lua's reader.
    version = function() return NS.Version and NS.Version() end,

    -- THE OPTIONS MENU'S THREE PAIRS (minor 4), each an accessor the settings rows read and the
    -- toggle the slash verb runs. The library draws an entry only where BOTH halves are passed.
    --
    -- Enabled: the one enabled predicate, and `/am enable` / `/am disable`'s handler, handed the
    -- state the addon moves TO.
    isEnabled  = function() return not (NS.IsDisabled and NS.IsDisabled()) end,
    setEnabled = function(on) NS.Slash.SetEnabled(on) end,
    -- Locked: the Lock frame row's `locked`, and `/am lock` / `/am unlock`'s handler.
    isLocked   = function() return NS.GetSetting and NS.GetSetting("locked") and true or false end,
    toggleLock = function() NS.Slash.ToggleLock() end,
    -- Test mode: the Test mode row's `state.testMode`, and a bare `/am test`'s handler, which
    -- switches it through modules/Preview.lua's Preview.SetTestMode — the one writer of the mode.
    isTestMode     = function() return NS.GetSetting and NS.GetSetting("state.testMode") and true or false end,
    toggleTestMode = function() NS.Slash.ToggleTestMode() end,

    -- CALL-TIME forwarders: core/CoreSetup.lua's printer is reclaimed from AceConsole's embed in
    -- core/AuraMaster.lua, which loads after this file.
    print = function(line) NS.Print(line) end,
    debug = function(tag, message) NS.Debug(tag, "%s", message) end,
})
