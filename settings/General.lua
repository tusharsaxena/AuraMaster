local _, NS = ...

-- settings/General.lua — the addon-wide page.
--
--     [ Master controls ][ Display ][ Spell Categories ][ Dispel Colors ]
--
--     Master controls  [Enable Aura Master]  [General visibility]
--                      [Master scale]        [Master alpha]
--                      [Lock frame]          [Debug console]
--                      [Minimap button]
--                      [Reset position]      [Reset all settings]     <- afterGroup button pair
--     Display          -- Blizzard frames --  [Hide Blizzard buffs]  [Hide Blizzard debuffs]
--     Spell Categories settings/GeneralSpells.lua: one spell category's list, profile-wide
--     Dispel Colors    settings/GeneralSpells.lua: one color per dispel type, profile-wide
--
-- A container's OWN identity — create, name, enable, unit, aura type, style, duplicate, delete,
-- copy — is the top-level Containers page's (`settings/Containers.lua`, N-1, batch 7). It used to
-- be this page's third tab; the owner moved it out to its own page, so General is left with only the
-- addon-wide rows: Master controls, Display, and General → Spell Categories / Dispel Colors, which
-- edit profile-wide lists rather than one container.
--
-- MASTER CONTROLS LEADS AND IS COMPOSED (options-ui-§15): H.MasterControls emits the canonical
-- rows from one declaration. Every row applies — containers are movable frames — so nothing is
-- omitted. Master scale and alpha MULTIPLY each container's own scale and alpha on the Layout page;
-- the two are different settings and neither replaces the other.
--
-- NO TEST MODE ROW. Unlocking already shows every container's placeholder auras, so under
-- preview-mode's exception (standard v2.49.0) the unlocked view is this addon's test mode and Lock
-- frame is its switch: no `testModePath` is passed, and there is no `/am test` verb. The fourth
-- line is therefore [Minimap button] alone, which is the shape the composer computes for an addon
-- that names one of the two paths.
--
-- THE MINIMAP ROW'S PATH IS UNPREFIXED AND ABSOLUTE, `global.minimap.hide`, and that is not an
-- oversight of the empty prefix above: the table is LibDBIcon's own and lives in the GLOBAL store,
-- outside any profile (launcher-§3). The row says SHOWN and the key says HIDDEN;
-- settings/Schema.lua inverts once, at the write seam.

local L = NS.L
local H = NS.Helpers
local print = NS.Print
local GS = NS.GeneralSpells

local DEBUG_CONSOLE_PATH = "state.debugConsole"
-- VERBATIM: the global store, outside the profile prefix (launcher-§3).
local MINIMAP_PATH = "global.minimap.hide"

local masterRows, masterTail = H.MasterControls({
    prefix           = "",
    page             = "general",
    addonName        = "Aura Master",
    frameless        = false,
    debugConsolePath = DEBUG_CONSOLE_PATH,
    minimapPath      = MINIMAP_PATH,
    onResetPosition  = function() NS.ContainerManager.ResetPositions() end,
    onResetAll       = function() StaticPopup_Show("AURAMASTER_RESET_ALL") end,
})

-- The composer emits DATA; the host attaches behavior, keyed by PATH so an upstream reorder cannot
-- move a handler onto the wrong row. Lock frame needs no onChange of its own: ContainerClass:ShouldShow
-- reads the lock, so its visibility pass alone shows or drops the placeholders.
--
-- What each master row changes, read by modules/ContainerManager.lua off CONFIG_CHANGED's `path`.
-- These four change only whether and how brightly containers show, which is a visibility pass: legal
-- in combat, and no apply is queued. Master scale is NOT here: SetScale runs in Container:Apply.
local masterEffect = {
    ["enabled"] = "visibility", ["visibility"] = "visibility",
    ["locked"]  = "visibility", ["alpha"]      = "visibility",
    -- The minimap button is not a container: the write seam already moved it through
    -- NS.Launcher:SetShown, and re-applying every container for it would be work for nothing.
    [MINIMAP_PATH] = "none",
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

-- After the Display rows, the enchant-slot rows, so Spell Categories (their group) takes the third
-- place; the Dispel Colors rows after those, so theirs is last.
NS.RegisterSchemaRows(GS.ENCHANT_ROWS)
NS.RegisterSchemaRows(GS.DISPEL_ROWS)

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

-- The page's tabs: its schema groups, with Spell Categories and Dispel Colors
-- (settings/GeneralSpells.lua) as its bespoke ones. `addonWide`: every tab is drawn whether or not a
-- container exists.
local PAGE_SPEC = {
    addonWide  = true,
    -- The group name IS the hook key, read off the instance rather than spelled again.
    afterGroup = { [H.MASTER_GROUP] = masterTail },
    tabs       = { GS.TABS[1], GS.TABS[2] },
}

local function build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then return nil end
    local ctx = H.CreatePanel("AuraMasterGeneralPanel", L["General"], {
        pageKey         = "general",
        defaultsButton  = true,
        -- Page-wide (options-ui-§13): the Dispel Colors rows are this page's, so Defaults takes them
        -- back too. The spell categories' lists are not rows; each has its own restore.
        defaultsTooltip = L["Restore every General setting on this profile to its addon default. The spell categories' lists are not rows; each category has its own restore."],
    })
    ctx.panel.defaultsOnClick = function() H.RestoreDefaults("general", ctx) end
    H.__pageCtx.general = ctx
    -- Through SetRenderer, which owns WHEN the page draws and refuses under combat (options-ui-§11).
    H.SetRenderer(ctx, function(c) H.RenderTabbedPage(c, "general", PAGE_SPEC) end)
    return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, L["General"])
end

NS.RegisterOptionsPage("general", L["General"], build)
