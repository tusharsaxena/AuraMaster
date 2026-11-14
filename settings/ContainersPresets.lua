local _, NS = ...

-- settings/ContainersPresets.lua -- the Containers page's Presets tab (spec
-- docs/superpowers/specs/2026-11-14-auramaster-presets-design.md, sections 6 and 8).
--
--     band      [Container v picker ][ New container ]
--     rail      | General |  [ General ][ Presets ]                <- the General section's second tab
--                            A preset is a ready-made set of containers ...
--                            [Preset v               ] [Style v ]
--                            Previewing ... / Pick a preset ...     <- the status line
--                            -- What it creates --
--                            Player buffs (all), Weapon enchants, ...
--                            -- When applied --  [Replace all my containers v]
--                            [Apply preset...] [Stop preview]
--
-- WHAT A PICK DOES. Choosing a preset or a style previews it on the real screen in test mode
-- (NS.Presets.BeginPreview); choosing the mode previews nothing. Apply preset... asks through the
-- preset confirm (NS.ConfirmPreview, settings/PresetPicker.lua), naming the count a Replace removes
-- or an Add adds, and keeps the preview in that mode; with no preview of this tab's up it applies
-- the selection behind the same confirm (NS.ConfirmPreset). Stop preview restores.
--
-- LEAVING RESTORES. A tab click or a rail click away, and the panel's OnHide, call this tab's
-- `onLeave` (settings/OptionsSetup.lua's leave record), which ends the preview with a restore. A
-- profile change restores through modules/Presets.lua's own profile-event path. The tab ends only
-- a preview it started: it keeps the token NS.Presets.Previewed answered when it began, so a
-- preview the first-run picker started is the picker's.
--
-- Empty is not offered here (spec section 8): Replace with Empty deletes every container, which the
-- band already does one at a time, and a one-click wipe stays off the panel.
--
-- Loads after settings/OptionsSetup.lua (the composers) and before settings/Containers.lua, which
-- binds NS.RenderPresetsTab and NS.PresetsTabLeft into its section spec at file load.

local L = NS.L
local H = NS.Helpers

-- The tab's order (spec section 8): the four presets, Empty left out.
local CHOICES = { "simple", "intermediate", "advanced", "healer" }
local LABELS = {
    simple = L["Simple"], intermediate = L["Intermediate"], advanced = L["Advanced"], healer = L["Healer"],
}
local LOOKS = { "bars", "icons" }
local LOOK_LABELS = { bars = L["Bars"], icons = L["Icons"] }
local MODES = { "replace", "add" }
local MODE_LABELS = { replace = L["Replace all my containers"], add = L["Add next to my containers"] }

-- The tab's selection: session state, not a setting (it means nothing outside an open panel).
-- `token` is the preview this tab started (NS.Presets.Previewed's third answer), nil when none.
local state = { sel = "simple", look = "bars", mode = "replace", token = nil }

local function sayGray(msg) NS.Printf("|cff808080%s|r", msg) end

local function say(msg, gray)
    if not msg then return end
    if gray then sayGray(msg) else NS.Print(msg) end
end

--- Whether the preview on screen is the one this tab started.
local function owns()
    if state.token == nil then return false end
    local _, _, token = NS.Presets.Previewed()
    if token ~= state.token then state.token = nil end
    return state.token ~= nil
end

--- The page draws again on the next frame, out of the widget callback that asked.
local function redraw()
    if NS.RequestPanelRefresh then NS.RequestPanelRefresh() end
end

--- Preview the selection: a preset in its style, swapping a preview this tab already has up.
local function preview()
    local P = NS.Presets
    local ok, msg, gray = P.BeginPreview(state.sel, state.look)
    if ok then
        local _, _, token = P.Previewed()
        state.token = token
    else
        say(msg, gray)
    end
    redraw()
end

--- End this tab's preview with a restore: Stop preview, and every leave.
local function stop()
    if not owns() then return end
    local ok, msg, gray = NS.Presets.EndPreview(false)
    if ok then state.token = nil else say(msg, gray) end
    redraw()
end

local function apply()
    if owns() then return NS.ConfirmPreview(state.sel, state.look, state.mode) end
    return NS.ConfirmPreset(state.sel, state.look, state.mode)
end

-- ---------------------------------------------------------------------------
-- The controls
-- ---------------------------------------------------------------------------

--- One dropdown cell: `label`, the choices `keys` labeled by `labels`, `value`, and `onPick(value)`
--- on a change of value.
local function dropdownCell(label, keys, labels, value, onPick, tooltip)
    return function(_, parent, rel)
        local list, order = {}, {}
        for i, k in ipairs(keys) do list[k] = labels[k]; order[i] = k end
        local dd = NS.CreateDropdown()
        dd:SetLabel(label)
        dd:SetList(list, order)
        dd:SetValue(value)
        dd:SetRelativeWidth(rel or 0.5)
        if tooltip and H.AttachTooltip then H.AttachTooltip(dd, label, tooltip) end
        dd:SetCallback("OnValueChanged", function(_, _, v)
            if v == nil or v == value then return end
            onPick(v)
        end)
        parent:AddChild(dd)
        return dd
    end
end

--- The preset dropdown's labels: each preset's name and its container count.
local function presetLabels()
    local out = {}
    for _, name in ipairs(CHOICES) do
        out[name] = L["%s - %d containers"]:format(LABELS[name], NS.PresetData.Count(name))
    end
    return out
end

local function pickPreset(v)
    if not LABELS[v] then return end
    state.sel = v
    preview()
end

local function pickLook(v)
    if not LOOK_LABELS[v] then return end
    state.look = v
    preview()
end

local function pickMode(v)
    if MODE_LABELS[v] then state.mode = v end
end

--- The names of the containers the selection creates, in creation order: one cell each, two to a
--- row (a name may hold a comma, so they are not joined into one line).
local function createdNames()
    local w, h = NS.Presets.ParentSize()
    local cells = {}
    for i, spec in ipairs(NS.PresetData.Build(state.sel, state.look, w, h)) do
        local name = tostring(spec.overrides.name)
        cells[i] = { make = function(_, parent, rel)
            local label = H.AceGUI:Create("Label")
            label:SetText(name)
            label:SetRelativeWidth(rel or 0.5)
            parent:AddChild(label)
            return label
        end }
    end
    return cells
end

--- The status line: what is on screen now.
local function statusLine()
    if owns() then
        local line = L["Previewing %s (%s) on your screen in test mode. Move this panel aside to look. Nothing is saved until Apply; leaving this tab or closing the panel puts your containers back."]
        return (NS.PanelEscape("am.goldMuted") or "") .. line:format(LABELS[state.sel], LOOK_LABELS[state.look]) .. "|r"
    end
    return (NS.PanelEscape("am.note") or "") .. L["Pick a preset or a style to see it on your screen."] .. "|r"
end

-- ---------------------------------------------------------------------------
-- The tab
-- ---------------------------------------------------------------------------

--- The Presets tab (spec section 8). Drawn whether or not a container exists: a preset is how a
--- profile with none gets some.
function NS.RenderPresetsTab(ctx)
    owns()   -- a preview ended elsewhere (combat, a profile change) is no longer this tab's
    H.TextRow(ctx, L["A preset is a ready-made set of containers, placed for your screen size. Applying one changes every container in this profile, not just the one in the band above. Skin, fonts and General settings are left alone."])
    H.RenderGrid(ctx, {
        { make = dropdownCell(L["Preset"], CHOICES, presetLabels(), state.sel, pickPreset,
            L["Picking a preset shows it on your screen in test mode, in place of your containers."]) },
        { make = dropdownCell(L["Style"], LOOKS, LOOK_LABELS, state.look, pickLook,
            L["Bars or icons for the preset's containers. Text containers stay text."]) },
    })
    H.TextRow(ctx, statusLine())
    H.Section(ctx, L["What it creates"])
    H.RenderGrid(ctx, createdNames(), nil, { gap = false })
    H.Section(ctx, L["When applied"])
    H.RenderGrid(ctx, {
        { make = dropdownCell(L["When applied"], MODES, MODE_LABELS, state.mode, pickMode,
            L["Replace deletes every container in this profile first. Add keeps yours and puts the preset's next to them; a name already in use gets a number added."]) },
    })
    H.InlineButtonPair(ctx,
        { text = L["Apply preset…"], tooltip = L["Keep the preset. Asks first, naming how many containers it replaces or adds."], onClick = apply },
        { text = L["Stop preview"], tooltip = L["Put your own containers back and turn test mode off."], onClick = stop })
end

--- The page moved off the tab, or the panel hid (settings/OptionsSetup.lua's leave record): the
--- preview this tab started is restored.
function NS.PresetsTabLeft()
    stop()
end
