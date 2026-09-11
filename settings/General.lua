local _, NS = ...

-- settings/General.lua — the addon-wide page.
--
--     [ Master controls ][ Display ]
--
--     Master controls  [Enable Aura Master]  [General visibility]
--                      [Master scale]        [Master alpha]
--                      [Lock frame]          [Debug console]
--                      [Reset position]      [Reset all settings]     <- afterGroup button pair
--     Display          -- Preview --          [Show placeholder auras]
--                      -- Blizzard frames --  [Hide Blizzard buffs]  [Hide Blizzard debuffs]
--
-- MASTER CONTROLS LEADS AND IS COMPOSED (options-ui-§15): H.MasterControls emits the canonical
-- rows from one declaration. Every row applies — containers are movable frames — so nothing is
-- omitted. Master scale and alpha MULTIPLY each container's own scale and alpha on the Layout page;
-- the two are different settings and neither replaces the other.

local L = NS.L
local H = NS.Helpers
local print = NS.Print

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
    -- enabled / visibility / locked change only whether containers show, which is a visibility
    -- pass: legal in combat, unlike a rebuild. CONFIG_CHANGED still queues the ordinary apply.
    ["enabled"]    = function() NS.ContainerManager.ApplyVisibility() end,
    ["visibility"] = function() NS.ContainerManager.ApplyVisibility() end,
    ["locked"]     = function(v)
        -- Locking ends preview mode (preview-mode); unlocking starts it by itself.
        if v and NS.State then NS.State.preview = false end
        NS.ContainerManager.ApplyVisibility()
    end,
}

-- The console row is SESSION state: it mirrors the console window, never the profile.
local console = NS.DebugLog:ConsoleCheckbox()

for _, row in ipairs(masterRows) do
    local fn = masterOnChange[row.path]
    if fn then row.onChange = fn end
    if row.path == DEBUG_CONSOLE_PATH then
        row.get, row.set = console.get, console.set
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
        onChange = function() NS.BlizzardFrames.Apply() end,
    },
    {
        path = "hideBlizzardDebuffs", page = "general", group = L["Display"], subgroup = L["Blizzard frames"],
        type = "bool",
        label = L["Hide Blizzard debuffs"],
        desc  = L["Hide the default debuff frame. Applied out of combat."],
        onChange = function() NS.BlizzardFrames.Apply() end,
    },
})

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
        if NS.Helpers and NS.Helpers.RestoreAllDefaults then
            NS.Helpers.RestoreAllDefaults()
            print(L["All settings reset to defaults."])
        else
            print(L["Cannot reset settings — the settings helpers failed to load."])
        end
    end,
}

local function build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then return nil end
    local ctx = H.CreatePanel("AuraMasterGeneralPanel", L["General"], {
        pageKey         = "general",
        defaultsButton  = true,
        defaultsTooltip = L["Restore every General setting on this profile to its addon default."],
    })
    ctx.panel.defaultsOnClick = function() H.RestoreDefaults("general", ctx) end
    -- Through SetRenderer, which owns WHEN the page draws and refuses under combat (options-ui-§11).
    H.SetRenderer(ctx, function(c)
        H.ClearScroll(c)
        -- The group name IS the hook key, read off the instance rather than spelled again.
        H.RenderTabbedSchema(c, "general", { [H.MASTER_GROUP] = masterTail })
    end)
    return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, L["General"])
end

NS.RegisterOptionsPage("general", L["General"], build)
