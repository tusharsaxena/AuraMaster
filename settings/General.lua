local _, NS = ...

-- settings/General.lua — the addon-wide page, and the home of each container's identity.
--
--     [ Master controls ][ Display ][ Containers ]
--
--     Master controls  [Enable Aura Master]  [General visibility]
--                      [Master scale]        [Master alpha]
--                      [Lock frame]          [Debug console]
--                      [Reset position]      [Reset all settings]     <- afterGroup button pair
--     Display          -- Preview --          [Show placeholder auras]
--                      -- Blizzard frames --  [Hide Blizzard buffs]  [Hide Blizzard debuffs]
--     Containers       settings/GeneralContainers.lua: the picker and New container, then the
--                      selected container's name, enable, unit, aura type and style, and its acts
--
-- MASTER CONTROLS LEADS AND IS COMPOSED (options-ui-§15): H.MasterControls emits the canonical
-- rows from one declaration. Every row applies — containers are movable frames — so nothing is
-- omitted. Master scale and alpha MULTIPLY each container's own scale and alpha on the Layout page;
-- the two are different settings and neither replaces the other.
--
-- The page draws no banner: its Containers tab carries its own picker in the tab body, the one
-- accepted options-ui-§14 deviation (docs/ARCHITECTURE.md → Documented deviations).

local L = NS.L
local H = NS.Helpers
local print = NS.Print
local GC = NS.GeneralContainers

local DEBUG_CONSOLE_PATH = "state.debugConsole"

local masterRows, masterTail = H.MasterControls({
    prefix           = "",
    page             = "general",
    addonName        = "Aura Master",
    frameless        = false,
    debugConsolePath = DEBUG_CONSOLE_PATH,
    onResetPosition  = function() NS.ContainerManager.ResetPositions() end,
    onResetAll       = function() StaticPopup_Show("AURAMASTER_RESET_ALL") end,
})

-- The composer emits DATA; the host attaches behavior, keyed by PATH so an upstream reorder cannot
-- move a handler onto the wrong row.
local masterOnChange = {
    -- Locking ends preview mode (preview-mode), through the seam; unlocking starts it by itself.
    ["locked"] = function(v)
        if v and NS.State and NS.State.preview then NS.SetByPath("state.preview", false) end
    end,
}

-- What each master row changes, read by modules/ContainerManager.lua off CONFIG_CHANGED's `path`.
-- These four change only whether and how brightly containers show, which is a visibility pass: legal
-- in combat, and no apply is queued. Master scale is NOT here: SetScale runs in Container:Apply.
local masterEffect = {
    ["enabled"] = "visibility", ["visibility"] = "visibility",
    ["locked"]  = "visibility", ["alpha"]      = "visibility",
}

-- The two Blizzard-frame rows' whole effect: no container reads them, so none re-applies. Under
-- lockdown BlizzardFrames.Apply waits for PLAYER_REGEN_ENABLED (core/AuraMaster.lua), and the player
-- is told so by the same once-per-stretch notice a held container apply prints.
local function applyBlizzardFrames()
    if NS.BlizzardFrames.Apply() == false then NS.ContainerManager.NoteDeferred() end
end

-- The console row is SESSION state: it mirrors the console window, never the profile.
local console = NS.DebugLog:ConsoleCheckbox()

for _, row in ipairs(masterRows) do
    local fn = masterOnChange[row.path]
    if fn then row.onChange = fn end
    row.effect = masterEffect[row.path]
    if row.path == DEBUG_CONSOLE_PATH then
        row.get, row.set = console.get, console.set
        -- Closed, stated here because the library's composer gives the row none. Without it a
        -- global reset (and the page's Defaults) could never close the console, where options-ui-§12
        -- names the debug console among the session rows a reset MUST restore.
        row.default = false
        -- Explicitly nothing: toggling a window re-applies no container.
        row.onChange = function() end
    end
end

NS.RegisterSchemaRows(masterRows)

NS.RegisterSchemaRows({
    {
        path = "state.preview", page = "general", group = L["Display"], subgroup = L["Preview"],
        type = "bool", sessionOnly = true, default = false,
        label = L["Show placeholder auras"],
        desc  = L["Fill every container with sample auras so you can see and style it without waiting for a real buff. Turns off at /reload. Unlocking shows them too."],
        get = function() return NS.State and NS.State.preview or false end,
        set = function(v) NS.ContainerManager.SetPreview(v) end,
    },
    {
        path = "hideBlizzardBuffs", page = "general", group = L["Display"], subgroup = L["Blizzard frames"],
        type = "bool", startsLine = true,
        label = L["Hide Blizzard buffs"],
        desc  = L["Hide the default buff frame (your weapon enchants go with it). Applied out of combat."],
        onChange = applyBlizzardFrames, effect = "none",
    },
    {
        path = "hideBlizzardDebuffs", page = "general", group = L["Display"], subgroup = L["Blizzard frames"],
        type = "bool",
        label = L["Hide Blizzard debuffs"],
        desc  = L["Hide the default debuff frame. Applied out of combat."],
        onChange = applyBlizzardFrames, effect = "none",
    },
})

-- After the Display rows, so the Containers tab is the strip's third.
NS.RegisterSchemaRows(GC.rows)

-- Reset all settings: options-ui-§12's one wording, verbatim, and the same act as Profiles →
-- Reset Profile.
StaticPopupDialogs["AURAMASTER_RESET_ALL"] = {
    text         = L["Reset this profile to the addon's defaults? Everything you have configured or added in it is discarded — your other profiles are not affected."],
    button1      = L["Yes"],
    button2      = L["No"],
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    OnAccept     = function()
        -- Not refused in combat, like /am resetall: Reset Profile takes the parked teardown there.
        if NS.Helpers and NS.Helpers.RestoreAllDefaults then
            NS.Helpers.RestoreAllDefaults()
            print(L["All settings reset to defaults."])
        else
            print(L["Cannot reset settings — the settings helpers failed to load."])
        end
    end,
}

-- The page's tabs: its schema groups, with the Containers group drawn by its own renderer (the
-- picker line above the rows). `addonWide`: every tab is drawn whether or not a container exists.
local PAGE_SPEC = {
    addonWide  = true,
    -- The group name IS the hook key, read off the instance rather than spelled again.
    afterGroup = { [H.MASTER_GROUP] = masterTail },
    tabs       = { { key = GC.GROUP, label = GC.GROUP, render = GC.render } },
}

local function build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then return nil end
    local ctx = H.CreatePanel("AuraMasterGeneralPanel", L["General"], {
        pageKey         = "general",
        defaultsButton  = true,
        -- Page-wide (options-ui-§13): the Containers tab's rows are this page's, so Defaults takes
        -- the selected container's identity back too — all but its name, which has no default.
        defaultsTooltip = L["Restore every General setting on this profile to its addon default, and the selected container's Enabled, Unit, Aura type and Style. Its name is kept."],
    })
    ctx.panel.defaultsOnClick = function() H.RestoreDefaults("general", ctx) end
    H.__pageCtx.general = ctx
    -- Through SetRenderer, which owns WHEN the page draws and refuses under combat (options-ui-§11).
    H.SetRenderer(ctx, function(c) H.RenderTabbedPage(c, "general", PAGE_SPEC) end)
    return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, L["General"])
end

NS.RegisterOptionsPage("general", L["General"], build)
