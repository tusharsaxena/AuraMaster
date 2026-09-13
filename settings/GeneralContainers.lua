local _, NS = ...

-- settings/GeneralContainers.lua — General → Containers: which containers exist, and what each is.
--
--     [ Master controls ][ Display ][ Containers ]
--     Containers  [Container ▾ picker ][ New container ]            <- the tab body's first line
--                 [Name] [Enabled] / [Unit] [Aura type] / [Style]
--                 [Duplicate] [Delete]                             <- acts on the selected container
--                 -- Copy settings from --  [Source ▾] [What ▾] [Copy]
--
-- THE PICKER AND NEW CONTAINER SIT IN THE TAB BODY, not in a band above the strip. That is this
-- addon's accepted deviation from options-ui-§14 (docs/ARCHITECTURE.md → Documented deviations): the
-- owner keeps a container's identity with the addon-wide settings on General, which draws no banner
-- and whose first tab stays Master controls (options-ui-§15). Filters, Layout, Bars and Icons keep
-- the banner picker. Drawn in the body, the picker and New are released and redrawn with the scroll
-- like every other widget, so a Delete's two refreshes cannot lose them.
--
-- This file registers nothing. settings/General.lua registers ROWS after its own rows, so the
-- Containers tab follows Master controls and Display in the strip (a tab's place is its group's
-- first-seen order), and draws the tab through RENDER. It loads before General.lua for that reason.

local L = NS.L
local H = NS.Helpers
local C = NS.Constants
local CM = NS.ContainerManager
local print = NS.Print
local printf = NS.Printf

local PAGE = "general"
local GROUP = L["Containers"]

-- Changing what a container IS changes which rows other pages offer (buff categories are not
-- debuff categories), so the panel is rebuilt — on the next frame, out of the dropdown's callback.
local function structural() if NS.RequestPanelRefresh then NS.RequestPanelRefresh() end end

local ROWS = {
    {
        path = "container.name", page = PAGE, group = GROUP, type = "string", dialogControl = "EditBox",
        maxLetters = 40, label = L["Name"],
        desc = L["What this container is called in the picker, on its drag handle and in /am containers. Press Enter to apply."],
        validate = function(v) return type(v) == "string" and v:match("%S") ~= nil end,
        -- Every write — the panel, `/am set`, Rename — stores the trimmed name made unique
        -- case-insensitively, so `/am select|delete <name>` can never match two containers.
        normalize = function(v, id) return CM.UniqueName(v:match("^%s*(.-)%s*$"), id) end,
        -- NotifyRenamed is the whole effect (handles and pickers); Container:Apply never reads the
        -- name, so a rename queues no apply and, in combat, announces no deferral.
        onChange = function() CM.NotifyRenamed() end, effect = "none",
        -- A name has no meaningful default (owner, 2026-09-13): neither General's Defaults nor
        -- `/am reset` restores it, and `/am reset` says why. The template's name still backfills.
        noReset = true, noResetReason = L["A container's name has no default."],
    },
    {
        path = "container.enabled", page = PAGE, group = GROUP, type = "bool",
        label = L["Enabled"], desc = L["Draw this container. A disabled container keeps its settings."], effect = "visibility",
    },
    {
        path = "container.unit", page = PAGE, group = GROUP, type = "string",
        values = NS.Choices(C.UNITS, C.UNIT_LABELS), label = L["Unit"],
        desc = L["Whose auras this container shows."],
        onChange = structural,
    },
    {
        path = "container.auraType", page = PAGE, group = GROUP, type = "string",
        values = NS.Choices(C.AURA_TYPES, C.AURA_TYPE_LABELS), label = L["Aura type"],
        desc = L["Buffs, debuffs, or your temporary weapon enchants. The Filters page offers the categories of whichever you choose."],
        onChange = structural,
    },
    {
        path = "container.style", page = PAGE, group = GROUP, type = "string",
        values = NS.Choices(C.STYLES, C.STYLE_LABELS), label = L["Style"],
        desc = L["Draw each aura as a bar or as an icon. Bars and Icons each have their own settings page."],
        onChange = structural,
    },
}

-- ---------------------------------------------------------------------------
-- Acts on the selected container
-- ---------------------------------------------------------------------------

-- A refusal (CM.Create's third return) is the gray combat line; any other error prints plain.
local function sayError(err, refused)
    if refused then return printf("|cff808080%s|r", err) end
    print(err)
end

local function doNew()
    local id, err, refused = CM.Create({})
    if not id then return sayError(err, refused) end
    H.SelectContainer(id)
end

local function doDuplicate()
    local _, id = NS.ActiveContainer()
    if not id then return end
    local newId, err, refused = CM.Duplicate(id)
    if not newId then return sayError(err, refused) end
    H.SelectContainer(newId)
end

StaticPopupDialogs["AURAMASTER_DELETE_CONTAINER"] = {
    text         = L["Delete the container '%s'? Its settings are discarded."],
    button1      = L["Yes"],
    button2      = L["No"],
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    OnAccept     = function(_, data)
        -- The same gate as /am delete: a popup accepted after combat started must not tear down.
        if InCombatLockdown() then
            return printf("|cff808080%s|r", L["cannot delete a container during combat — its display cannot be torn down until combat ends"])
        end
        if data and CM.Delete(data) then H.RefreshAllPanels() end
    end,
}

local function doDelete()
    local cfg, id = NS.ActiveContainer()
    if not id then return end
    local popup = StaticPopup_Show("AURAMASTER_DELETE_CONTAINER", tostring(cfg.name))
    if popup then popup.data = id end
end

-- The copy control's selection. Page state, not a setting: it means nothing outside an open panel.
local copySource, copySection = nil, "all"

local SECTION_KEYS = { "all", "filter", "layout", "behavior", "bars", "icons" }
local SECTION_LABELS = {
    all = "Everything (what it shows and how it looks)", filter = "Filters", layout = "Layout",
    behavior = "Mouse", bars = "Bar style", icons = "Icon style",
}

local function sourceCell(_, parent, rel)
    local _, activeId = NS.ActiveContainer()
    local list, order = {}, {}
    for _, c in ipairs(NS.Database.GetContainers()) do
        if c.id ~= activeId then
            list[c.id] = tostring(c.name)
            order[#order + 1] = c.id
        end
    end
    if not list[copySource] then copySource = order[1] end
    local dd = NS.AceGUI:Create("Dropdown")
    dd:SetLabel(L["Source container"])
    dd:SetList(list, order)
    dd:SetValue(copySource)
    dd:SetRelativeWidth(rel or 0.5)
    dd:SetCallback("OnValueChanged", function(_, _, v) copySource = v end)
    parent:AddChild(dd)
    return dd
end

local function sectionCell(_, parent, rel)
    local list, order = {}, {}
    for i, k in ipairs(SECTION_KEYS) do list[k] = L[SECTION_LABELS[k]]; order[i] = k end
    local dd = NS.AceGUI:Create("Dropdown")
    dd:SetLabel(L["What to copy"])
    dd:SetList(list, order)
    dd:SetValue(copySection)
    dd:SetRelativeWidth(rel or 0.5)
    dd:SetCallback("OnValueChanged", function(_, _, v) copySection = v end)
    parent:AddChild(dd)
    return dd
end

local function renderCopy(ctx)
    local _, activeId = NS.ActiveContainer()
    H.Section(ctx, L["Copy settings from"])
    H.RenderGrid(ctx, { { make = sourceCell }, { make = sectionCell } })
    H.InlineButtonPair(ctx, {
        text = L["Copy onto this container"],
        tooltip = L["Replace the chosen settings of the selected container with the source's. Name and position are never copied."],
        onClick = function()
            if not (copySource and activeId) then return end
            local ok, err = CM.CopyFrom(copySource, activeId, copySection ~= "all" and copySection or nil)
            -- A copy can change what the selected container IS (its aura type, its style), and so
            -- which rows every page offers: re-render, as the Delete popup does.
            if ok then H.RefreshAllPanels() else print(err) end
        end,
    }, nil)
end

local function afterRows(ctx)
    H.InlineButtonPair(ctx,
        { text = L["Duplicate"], tooltip = L["Make a copy of this container with every setting."], onClick = doDuplicate },
        { text = L["Delete"], tooltip = L["Delete this container. Asks first."], onClick = doDelete })
    if #NS.Database.GetContainers() > 1 then renderCopy(ctx) end
end

-- ---------------------------------------------------------------------------
-- The tab
-- ---------------------------------------------------------------------------

local function newCell(_, parent, rel)
    local btn = NS.AceGUI:Create("Button")
    btn:SetText(L["New container"])
    btn:SetRelativeWidth(rel or 0.5)
    btn:SetCallback("OnClick", doNew)
    H.AttachTooltip(btn, L["New container"], L["Create a container showing the player's buffs as bars. Change what it shows below."])
    parent:AddChild(btn)
    return btn
end

--- The Containers tab: the picker and New container on one line, then the selected container's
--- identity rows and the acts on it. With no container there is nothing to edit: the line, then
--- the one sentence saying how to make one.
local function render(ctx, cfg, rows)
    H.RenderGrid(ctx, { { make = H.ContainerPickerCell }, { make = newCell } })
    if not cfg then
        H.TextRow(ctx, L["No containers yet. Click New container, or type /am new."])
        return
    end
    H.RenderRows(ctx, rows or {}, { [GROUP] = afterRows }, nil, { noHeadings = true })
end

NS.GeneralContainers = { GROUP = GROUP, rows = ROWS, render = render }
