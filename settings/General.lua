local _, NS = ...

-- settings/General.lua — the addon-wide page.
--
--     [ Master controls ][ Blizzard frames ][ Spell categories ][ Dispel colors ]
--
--     Master controls  [Enable Aura Master]  [General visibility]
--                      [Master scale]        [Master opacity]
--                      [Lock frame]          [Debug console]
--                      [Minimap button]      [Test mode]
--                      [Reset position]      [Reset all settings]     <- afterGroup button pair
--     Blizzard frames  [Hide Blizzard buffs]  [Hide Blizzard debuffs]   <- no heading: the tab names it
--     Spell categories settings/GeneralSpells.lua: one spell category's list, profile-wide
--     Dispel colors    settings/GeneralDispel.lua: one color per dispel type, profile-wide
--
-- A container's OWN identity — create, name, enable, unit, aura type, style, duplicate, delete,
-- copy — is the top-level Containers page's (`settings/Containers.lua`, N-1, batch 7). It used to
-- be this page's third tab; the owner moved it out to its own page, so General is left with only the
-- addon-wide rows: Master controls, Blizzard frames, and General → Spell categories / Dispel colors, which
-- edit profile-wide lists rather than one container.
--
-- MASTER CONTROLS LEADS AND IS COMPOSED (options-ui-§15): H.MasterControls emits the canonical
-- rows from one declaration. Every row applies — containers are movable frames — so nothing is
-- omitted. Master scale and alpha MULTIPLY each container's own scale and alpha in the Layout section;
-- the two are different settings and neither replaces the other.
--
-- THE TEST MODE ROW (preview-mode, options-ui-§15, anti-pattern #80). Unlocking makes containers
-- draggable and leaves their live auras drawing (B1, 2026-09-19), so the unlocked view is no longer a
-- test mode and preview-mode's exception no longer applies: the placeholders have a switch of their
-- own. The composer emits it from `testModePath` beside Minimap button; it is a SESSION row bound to
-- NS.State.testMode through modules/Preview.lua's Preview.SetTestMode, the one writer `/am test` and
-- the launcher menu's Test mode entry also use. Off after a reload, ended when combat starts, refused in
-- combat, and ended by Reset all settings (the row's default is false).
--
-- THE MINIMAP ROW'S PATH IS UNPREFIXED AND ABSOLUTE, `global.minimap.shown` (NS.MINIMAP_PATH,
-- published by settings/Schema.lua), and that is not an oversight of the empty prefix above: the
-- table is LibDBIcon's own and lives in the GLOBAL store, outside any profile (launcher-§3). The
-- path reads in the row's SHOWN sense; the stored key is LibDBIcon's `hide`, and settings/Schema.lua
-- inverts once, at its read and write seams.

local L = NS.L
local H = NS.Helpers
local print = NS.Print
local GS = NS.GeneralSpells
local GD = NS.GeneralDispel

local DEBUG_CONSOLE_PATH = "state.debugConsole"
-- Session state, like the console row: the path names no stored leaf.
local TEST_MODE_PATH = "state.testMode"
-- VERBATIM: the global store, outside the profile prefix (launcher-§3). Spelled once, in Schema.lua.
local MINIMAP_PATH = NS.MINIMAP_PATH

local masterRows, masterTail = H.MasterControls({
    prefix           = "",
    page             = "general",
    addonName        = "Aura Master",
    frameless        = false,
    debugConsolePath = DEBUG_CONSOLE_PATH,
    minimapPath      = MINIMAP_PATH,
    testModePath     = TEST_MODE_PATH,
    onResetPosition  = function() NS.ContainerManager.ResetPositions() end,
    onResetAll       = function() StaticPopup_Show("AURAMASTER_RESET_ALL") end,
})

-- The composer emits DATA; the host attaches behavior, keyed by PATH so an upstream reorder cannot
-- move a handler onto the wrong row. Lock frame needs no onChange of its own: ContainerClass:ShouldShow
-- reads the lock, so its visibility pass alone shows or drops the handles and outlines.
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
    if NS.BlizzardFrames.Apply() == false then
        NS.BlizzardFrames.NoteHeld()
        NS.ContainerManager.NoteDeferred()
    end
end

-- The console row is SESSION state: it mirrors the console window, never the profile.
local console = NS.DebugLog:ConsoleCheckbox()

for _, row in ipairs(masterRows) do
    row.effect = masterEffect[row.path]
    -- THE MASTER SWITCH DRIVES THE LATCH, and this row is where it is wired (slash-commands-§7).
    -- `/am enable`, `/am disable` and `/am set enabled` all write this same path through the same
    -- seam, so they land on this same onChange -- one branch, not four. Disabled is not a visibility
    -- pass: the addon stops registering, stops timing and stops writing, which is what NS.SyncEnabled
    -- asks the latch for.
    if row.path == "enabled" then
        row.onChange = function() NS.SyncEnabled() end
    end
    if row.path == DEBUG_CONSOLE_PATH then
        row.get, row.set = console.get, console.set
        -- Closed, stated here because the library's composer gives the row none. Without it a
        -- global reset (and the page's Defaults) could never close the console, where options-ui-§12
        -- names the debug console among the session rows a reset MUST restore.
        row.default = false
        -- Explicitly nothing: toggling a window re-applies no container.
        row.onChange = function() end
    end
    if row.path == TEST_MODE_PATH then
        -- Bound to the one switch, which refuses a start in combat, sends the visibility pass
        -- itself and re-syncs this checkbox (a refused start reads false again).
        --
        -- AND A START IS REFUSED WHILE THE ADDON IS DISABLED (slash-commands-§7, launcher-§2), the
        -- same refusal `/am test` and the launcher menu's Test mode entry answer: the dispatcher's one line,
        -- then a panel refresh so the checkbox reads off again. Turning it OFF stays allowed, since
        -- stopping a preview is not a feature.
        row.get = function() return NS.State.testMode end
        row.set = function(v)
            if v and NS.IsDisabled() then
                -- The guard named in the log (debug-logging-§8): the seam's [Set] line that follows
                -- records the request, and this line says it was refused.
                if NS.Debug then NS.Debug("Preview", "test mode refused (addon disabled)") end
                if NS.Slash and NS.Slash.DisabledLine then NS.Print(NS.Slash.DisabledLine()) end
                if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
                return
            end
            NS.Preview.SetTestMode(v)
        end
        row.default = false
        row.onChange = function() end
    end
end

NS.RegisterSchemaRows(masterRows)

NS.RegisterSchemaRows({
    {
        path = "hideBlizzardBuffs", page = "general", group = L["Blizzard frames"],
        type = "bool", startsLine = true,
        label = L["Hide Blizzard buffs"],
        desc  = L["Hide the default buff frame (your weapon enchants go with it). Applied out of combat."],
        onChange = applyBlizzardFrames, effect = "none",
    },
    {
        path = "hideBlizzardDebuffs", page = "general", group = L["Blizzard frames"],
        type = "bool",
        label = L["Hide Blizzard debuffs"],
        desc  = L["Hide the default debuff frame. Applied out of combat."],
        onChange = applyBlizzardFrames, effect = "none",
    },
})

-- After the Blizzard frames rows (item 020 renamed the tab from Display and dropped its one
-- subsection, which only repeated the tab, AUR-L01b), the enchant-slot rows, so Spell categories (their group) takes the third
-- place; the Dispel colors rows after those, so theirs is last.
NS.RegisterSchemaRows(GS.ENCHANT_ROWS)
NS.RegisterSchemaRows(GD.ROWS)

-- ── General ▸ Skin (the Appearance group) ──
-- The skin this addon wears (skinning-§2, §3: per addon, per profile). The tab is the library's
-- O.AppearanceTab (PAGE_SPEC below), keyed by this group, which draws every row as its own choice
-- grids, check boxes and media dropdowns, so each row carries `skipRender`; they stay schema rows so
-- the defaults resolve, every reset reaches them, and `/am get|set skin.skin` validates against
-- `values`. Registered after Dispel colors, so the group, and the tab that takes its place, is last:
-- the page has no Keybindings tab (skinning-§3).
--
-- Each onChange applies ONLY its own half (core/SkinSetup.lua says why): the tab and another addon's
-- "Copy to every Ka0s addon" call Skin:SetChoice before they write, so the write is a no-op, and a
-- bare `/am set` still repaints. `effect = "none"`: a skin write re-applies no container; the HUD
-- follows the skin through NS.Skin.OnLooksChanged.
local APPEARANCE = "Appearance"

NS.RegisterSchemaRows({
    {
        path = "skin.source", page = "general", group = APPEARANCE, type = "string",
        skipRender = true, values = NS.SKIN_SOURCE_OPTIONS, effect = "none",
        label = L["Skin source"],
        desc  = L["Where this addon's look comes from: the Ka0s skin chosen below, or EllesmereUI."],
        onChange = function(v) NS.ApplySkinChoice(v, nil) end,
    },
    {
        path = "skin.skin", page = "general", group = APPEARANCE, type = "string",
        skipRender = true, values = NS.SKIN_OPTIONS, effect = "none",
        label = L["Skin"],
        desc  = L["The Ka0s skin this addon wears. Changes its settings, tool windows and containers right away."],
        onChange = function(v) NS.ApplySkinChoice(nil, v) end,
    },
    -- The Scope's two exceptions (LibKa0s-Skin-1.0 minor 5), drawn by the same tab as check boxes.
    {
        path = "skin.ignorePanel", page = "general", group = APPEARANCE, type = "bool",
        skipRender = true, effect = "none",
        label = L["Ignore settings panel"],
        desc  = L["Keep this addon's settings panel in the game's own look. Its other surfaces still wear the skin."],
        onChange = function(v) NS.ApplySkinIgnore(v, nil) end,
    },
    {
        path = "skin.ignoreFonts", page = "general", group = APPEARANCE, type = "bool",
        skipRender = true, effect = "none",
        label = L["Ignore fonts"],
        desc  = L["Keep every font in this addon as the game draws it. The skin still colors the text."],
        onChange = function(v) NS.ApplySkinIgnore(nil, v) end,
    },
    -- The Font and texture section's two overrides (LibKa0s-Skin-1.0 minor 6), drawn by the same tab
    -- as dropdowns of LibSharedMedia keys; "" is the skin's own. Free text, not a list with `values`:
    -- a media pack may register its keys after this file loads, and `/am set` takes any key.
    {
        path = "skin.font", page = "general", group = APPEARANCE, type = "string",
        skipRender = true, effect = "none",
        label = L["Font"],
        desc  = L["The font this addon's text uses, over the skin's own. Empty keeps the skin's."],
        onChange = function(v) NS.ApplySkinOverride(v, nil) end,
    },
    {
        path = "skin.texture", page = "general", group = APPEARANCE, type = "string",
        skipRender = true, effect = "none",
        label = L["Texture"],
        desc  = L["The texture this addon's bars use, over the skin's own. Empty keeps the skin's."],
        onChange = function(v) NS.ApplySkinOverride(nil, v) end,
    },
    -- The Font outline (LibKa0s-Skin-1.0 minor 9, ruling D-06), drawn by the same tab as its "Font
    -- outline" dropdown: where the skin outlines this addon's text. The library's three modes, in its
    -- order; `/am set skin.outline` validates against them.
    {
        path = "skin.outline", page = "general", group = APPEARANCE, type = "string",
        skipRender = true, values = NS.SKIN_OUTLINE_OPTIONS, effect = "none",
        label = L["Font outline"],
        desc  = L["Where the skin outlines this addon's text: all of it, its HUD text only, or nowhere."],
        onChange = function(v) NS.ApplySkinOutline(v) end,
    },
    -- The first-run skin picker's memory: set when the picker closes, so it shows once per profile.
    -- Drawn by nothing; a reset puts it back to false.
    {
        path = "skin.pickerSeen", page = "general", group = APPEARANCE, type = "bool",
        skipRender = true, effect = "none",
        label = L["Skin picker seen"],
        desc  = L["Whether the first-run skin picker was closed on this profile."],
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
        -- Not refused in combat, like /am resetall: Reset Profile takes the parked teardown there.
        if NS.Helpers and NS.Helpers.RestoreAllDefaults then
            NS.Helpers.RestoreAllDefaults()
            print(L["All settings reset to defaults."])
        else
            print(L["Cannot reset settings — the settings helpers failed to load."])
        end
    end,
}

-- skinning-§3: the Skin tab, the library's own entry (O.AppearanceTab): the skin source, the nine
-- skins, the font and texture overrides, the Scope, "Copy to every Ka0s addon..." and the note,
-- drawn from LibKa0s-Skin-1.0 for the owner core/SkinSetup.lua registered. `get` and `set` are that
-- file's read and write seams, so a pick lands through NS.SetByPath like every other setting; the
-- tab calls Skin:SetChoice first, so the live repaint is the library's and the rows' onChange finds
-- nothing left to apply. Keyed by the Appearance group, it takes that group's place, last, as the
-- page has no Keybindings tab (`before = false`). On the degraded path the stub's entry draws
-- nothing, and the tab is still there.
local APPEARANCE_TAB = H.AppearanceTab({
    key = APPEARANCE, before = false,
    owner = NS.Skin and NS.Skin.owner, get = NS.SkinChoice, set = NS.WriteSkinChoice,
})

-- The page's tabs: its schema groups, with Spell categories (settings/GeneralSpells.lua), Dispel
-- colors (settings/GeneralDispel.lua) and Skin as its bespoke ones. `addonWide`: every tab is drawn
-- whether or not a container exists.
local PAGE_SPEC = {
    addonWide  = true,
    -- The group name IS the hook key, read off the instance rather than spelled again.
    afterGroup = { [H.MASTER_GROUP] = masterTail },
    tabs       = { GS.TABS[1], GD.TAB, APPEARANCE_TAB },
}

local function build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then return nil end
    local ctx = H.CreatePanel("AuraMasterGeneralPanel", L["General"], {
        pageKey         = "general",
        defaultsButton  = true,
        -- Page-wide (options-ui-§13): the Dispel colors rows are this page's, so Defaults takes them
        -- back too. The spell categories' lists are not rows; each has its own restore. And the
        -- Minimap button row is exempt (settings/OptionsSetup.lua's `vetoedFromPanelReset`,
        -- launcher-§3) -- it is on this page, so the tooltip says so rather than letting a press
        -- silently skip a row the player can see.
        defaultsTooltip = L["Restore every General setting on this profile to its addon default. The Minimap button is left alone — whether the button is shown is a per-installation preference, like where you dragged it. The spell categories' lists are not rows; each category has its own restore."],
    })
    ctx.panel.defaultsOnClick = function() H.RestoreDefaults("general", ctx) end
    H.__pageCtx.general = ctx
    -- Through SetRenderer, which owns WHEN the page draws and refuses under combat (options-ui-§11).
    H.SetRenderer(ctx, function(c) H.RenderPage(c, "general", PAGE_SPEC) end)
    return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, L["General"])
end

NS.RegisterOptionsPage("general", L["General"], build)
