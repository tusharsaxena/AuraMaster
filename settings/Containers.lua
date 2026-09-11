local _, NS = ...

-- settings/Containers.lua — which containers exist, and what each one is.
--
--     band      [Container ▾ picker ][ New container ]          <- the ONE chrome row (options-ui-§14)
--     [ General ][ Overview ]
--     General   [Name] [Enabled] / [Unit] [Aura type] / [Style]
--               [Duplicate] [Delete]                            <- acts on the selected container
--               -- Copy settings from --  [Source ▾] [What ▾] [Copy]
--     Overview  one line per container, each with a Select button
--
-- The band carries the identity controls only — the picker and the create control — and every
-- other act on the selected container sits on the FIRST tab, named `General`, which is the page
-- the player lands on (options-ui-§14's one-row band).

local L = NS.L
local H = NS.Helpers
local C = NS.Constants
local CM = NS.ContainerManager
local print = NS.Print
local printf = NS.Printf

local PAGE = "containers"
local GROUP = L["General"]

-- Changing what a container IS changes which rows other pages offer (buff categories are not
-- debuff categories), so the panel is rebuilt — on the next frame, out of the dropdown's callback.
local function structural() if NS.RequestPanelRefresh then NS.RequestPanelRefresh() end end

NS.RegisterSchemaRows({
    {
        path = "container.name", page = PAGE, group = GROUP, type = "string", dialogControl = "EditBox",
        maxLetters = 40, label = L["Name"],
        desc = L["What this container is called in the picker, on its drag handle and in /am containers. Press Enter to apply."],
        validate = function(v) return type(v) == "string" and v:match("%S") ~= nil end,
        -- NotifyRenamed is the whole effect (handles and pickers); Container:Apply never reads the
        -- name, so a rename queues no apply and, in combat, announces no deferral.
        onChange = function() CM.NotifyRenamed() end, effect = "none",
    },
    {
        path = "container.enabled", page = PAGE, group = GROUP, type = "bool",
        label = L["Enabled"], desc = L["Draw this container. A disabled container keeps its settings."],
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
})

-- ---------------------------------------------------------------------------
-- Acts on the selected container
-- ---------------------------------------------------------------------------

local function selectAndRefresh(id)
    H.SelectContainer(id)
end

-- A refusal (CM.Create's third return) is the gray combat line; any other error prints plain.
local function sayError(err, refused)
    if refused then return printf("|cff808080%s|r", err) end
    print(err)
end

local function doNew()
    local id, err, refused = CM.Create({})
    if not id then return sayError(err, refused) end
    selectAndRefresh(id)
end

local function doDuplicate()
    local _, id = NS.ActiveContainer()
    if not id then return end
    local newId, err, refused = CM.Duplicate(id)
    if not newId then return sayError(err, refused) end
    selectAndRefresh(newId)
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

local function renderCopy(ctx)
    local AceGUI = NS.AceGUI
    local _, activeId = NS.ActiveContainer()
    H.Section(ctx, L["Copy settings from"])
    H.RenderGrid(ctx, {
        { make = function(_, parent, rel)
            local list, order = {}, {}
            for _, c in ipairs(NS.Database.GetContainers()) do
                if c.id ~= activeId then
                    list[c.id] = tostring(c.name)
                    order[#order + 1] = c.id
                end
            end
            if not list[copySource] then copySource = order[1] end
            local dd = AceGUI:Create("Dropdown")
            dd:SetLabel(L["Source container"])
            dd:SetList(list, order)
            dd:SetValue(copySource)
            dd:SetRelativeWidth(rel or 0.5)
            dd:SetCallback("OnValueChanged", function(_, _, v) copySource = v end)
            parent:AddChild(dd)
            return dd
        end },
        { make = function(_, parent, rel)
            local list, order = {}, {}
            for i, k in ipairs(SECTION_KEYS) do list[k] = L[SECTION_LABELS[k]]; order[i] = k end
            local dd = AceGUI:Create("Dropdown")
            dd:SetLabel(L["What to copy"])
            dd:SetList(list, order)
            dd:SetValue(copySection)
            dd:SetRelativeWidth(rel or 0.5)
            dd:SetCallback("OnValueChanged", function(_, _, v) copySection = v end)
            parent:AddChild(dd)
            return dd
        end },
    })
    H.InlineButtonPair(ctx, {
        text = L["Copy onto this container"],
        tooltip = L["Replace the chosen settings of the selected container with the source's. Name and position are never copied."],
        onClick = function()
            if not (copySource and activeId) then return end
            local ok, err = CM.CopyFrom(copySource, activeId, copySection ~= "all" and copySection or nil)
            if not ok then print(err) end
        end,
    }, nil)
end

local function afterGeneral(ctx)
    H.InlineButtonPair(ctx,
        { text = L["Duplicate"], tooltip = L["Make a copy of this container with every setting."], onClick = doDuplicate },
        { text = L["Delete"], tooltip = L["Delete this container. Asks first."], onClick = doDelete })
    if #NS.Database.GetContainers() > 1 then renderCopy(ctx) end
end

-- ---------------------------------------------------------------------------
-- The Overview tab
-- ---------------------------------------------------------------------------

local function describe(c)
    local at = c.attach or {}
    local where = L["the screen"]
    if at.mode == "container" then
        local t = NS.Database.FindContainer(tonumber(at.container))
        where = t and ("'" .. tostring(t.name) .. "'") or L["the screen"]
    elseif at.mode == "frame" and at.frame ~= "" then
        where = tostring(at.frame)
    end
    return ("%s%s|r  |cffaaaaaa%s · %s · %s · %s %s|r"):format(c.enabled and "|cffffffff" or "|cff888888",
        tostring(c.name), L[C.UNIT_LABELS[c.unit] or "?"], L[C.AURA_TYPE_LABELS[c.auraType] or "?"],
        L[C.STYLE_LABELS[c.style] or "?"], L["attached to"], where)
end

local function renderOverview(ctx)
    local AceGUI = NS.AceGUI
    local items = {}
    for _, c in ipairs(NS.Database.GetContainers()) do
        items[#items + 1] = { make = function(_, parent, rel)
            local lbl = AceGUI:Create("Label")
            lbl:SetText(describe(c))
            lbl:SetRelativeWidth(rel or 0.5)
            parent:AddChild(lbl)
            return lbl
        end }
        items[#items + 1] = { make = function(_, parent, rel)
            local btn = AceGUI:Create("Button")
            btn:SetText(L["Select"])
            btn:SetRelativeWidth((rel or 0.5) * 0.5)
            btn:SetCallback("OnClick", function() selectAndRefresh(c.id) end)
            parent:AddChild(btn)
            return btn
        end }
    end
    H.RenderGrid(ctx, items)
end

-- ---------------------------------------------------------------------------
-- The page
-- ---------------------------------------------------------------------------

local function header(ctx, frame)
    local picker = H.ContainerPickerWidget(ctx)
    H.PlaceInHeader(picker, frame, "LEFT")
    local btn = NS.AceGUI:Create("Button")
    ctx.__chromeWidgets[#ctx.__chromeWidgets + 1] = btn
    btn:SetText(L["New container"])
    btn:SetCallback("OnClick", doNew)
    H.AttachTooltip(btn, L["New container"], L["Create a container showing the player's buffs as bars. Change what it shows below."])
    H.PlaceInHeader(btn, frame, "RIGHT")
end

NS.RegisterContainerPage(PAGE, L["Containers"], "AuraMasterContainersPanel", {
    header     = header,
    afterGroup = { [GROUP] = afterGeneral },
    tabs       = { { key = "overview", label = L["Overview"], render = function(ctx) renderOverview(ctx) end } },
})
