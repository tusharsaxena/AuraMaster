local _, NS = ...

-- settings/Layout.lua — where a container sits and how its auras are arranged.
--
--     band      [Container ▾]
--     [ Position ][ Growth ][ Frame ][ Mouse ]
--     Position  [Attach to] [Container] / [Frame name] / [Point] [Relative point] / [X] [Y]
--               -- On the screen -- [Point] [Relative point] / [X] [Y]
--               [Pick a frame…] [Attach to the screen]            <- afterGroup
--
-- A container attaches to the screen, to another container (following it as it grows) or to any
-- named frame (modules/Anchors.lua). The frame picker (modules/FramePicker.lua) closes the settings
-- window, lets the player click a frame, and reopens this page.

local L = NS.L
local H = NS.Helpers
local C = NS.Constants

local PAGE = "layout"
local G_POS, G_GROW, G_FRAME, G_MOUSE = L["Position"], L["Growth"], L["Frame"], L["Mouse"]
local POINTS = NS.Choices(C.POINTS, C.POINT_LABELS)

--- The containers the active one may attach to: every other one, plus "None".
local function attachTargets()
    local _, activeId = NS.ActiveContainer()
    local out = { { value = 0, text = L["None"] } }
    for _, c in ipairs(NS.Database.GetContainers()) do
        if c.id ~= activeId then
            out[#out + 1] = { value = c.id, text = tostring(c.name) }
        end
    end
    return out
end

local function structural() if NS.RequestPanelRefresh then NS.RequestPanelRefresh() end end

NS.RegisterSchemaRows({
    {
        path = "container.attach.mode", page = PAGE, group = G_POS, type = "string",
        values = NS.Choices(C.ATTACH_MODES, C.ATTACH_MODE_LABELS), label = L["Attach to"],
        desc = L["The screen (drag it anywhere), another container (it follows that container as it grows), or any named frame — a unit frame, an action bar."],
        onChange = structural,
    },
    {
        path = "container.attach.container", page = PAGE, group = G_POS, type = "number",
        values = attachTargets, label = L["Container"],
        desc = L["The container to attach to when 'Another container' is chosen. A chain that would loop falls back to the screen."],
        -- `fromId` is the container the write targets, resolved by the seam: the id a caller names,
        -- else the selected container. A loop is checked from there, never from the selection.
        validate = function(v, fromId)
            local id = tonumber(v)
            return id ~= nil and (id == 0 or not NS.Anchors.WouldCycle(fromId, id))
        end,
    },
    {
        path = "container.attach.frame", page = PAGE, group = G_POS, type = "string", dialogControl = "EditBox",
        wide = true, maxLetters = 120, label = L["Frame name"],
        desc = L["The global name of the frame to attach to when 'A named frame' is chosen — or use Pick a frame below. /fstack shows frame names."],
    },
    {
        path = "container.attach.point", page = PAGE, group = G_POS, type = "string", values = POINTS,
        startsLine = true, label = L["Point"], desc = L["The corner of this container that is attached."],
    },
    {
        path = "container.attach.relativePoint", page = PAGE, group = G_POS, type = "string", values = POINTS,
        label = L["Relative point"], desc = L["The corner of the target it is attached to."],
    },
    {
        path = "container.attach.x", page = PAGE, group = G_POS, type = "number", min = -500, max = 500, step = 1,
        label = L["X offset"], desc = L["Horizontal offset from the attachment point, in pixels."],
    },
    {
        path = "container.attach.y", page = PAGE, group = G_POS, type = "number", min = -500, max = 500, step = 1,
        label = L["Y offset"], desc = L["Vertical offset from the attachment point, in pixels."],
    },
    {
        path = "container.position.point", page = PAGE, group = G_POS, subgroup = L["On the screen"],
        type = "string", values = POINTS, label = L["Point"],
        desc = L["Used while attached to the screen. Dragging the container sets these for you."],
    },
    {
        path = "container.position.relativePoint", page = PAGE, group = G_POS, subgroup = L["On the screen"],
        type = "string", values = POINTS, label = L["Relative point"], desc = L["The screen corner it is measured from."],
    },
    {
        path = "container.position.x", page = PAGE, group = G_POS, subgroup = L["On the screen"],
        type = "number", min = -2000, max = 2000, step = 1, label = L["X"], desc = L["Horizontal position, in pixels."],
    },
    {
        path = "container.position.y", page = PAGE, group = G_POS, subgroup = L["On the screen"],
        type = "number", min = -2000, max = 2000, step = 1, label = L["Y"], desc = L["Vertical position, in pixels."],
    },

    {
        path = "container.layout.axis", page = PAGE, group = G_GROW, type = "string",
        values = NS.Choices(C.AXES, C.AXIS_LABELS), label = L["Fill"],
        desc = L["Lay auras out in rows or in columns. Bars usually stack in a column."],
    },
    {
        path = "container.layout.perLine", page = PAGE, group = G_GROW, type = "number", min = 0, max = 40, step = 1,
        label = L["Per row or column (0 = one line)"],
        desc = L["Start a new row (or column) after this many auras."],
    },
    {
        path = "container.layout.growH", page = PAGE, group = G_GROW, type = "string",
        values = NS.Choices(C.GROW_H, C.GROW_H_LABELS), label = L["Grow horizontally"],
        desc = L["Which way new auras are added across."],
    },
    {
        path = "container.layout.growV", page = PAGE, group = G_GROW, type = "string",
        values = NS.Choices(C.GROW_V, C.GROW_V_LABELS), label = L["Grow vertically"],
        desc = L["Which way new auras are added down or up."],
    },
    {
        path = "container.layout.spacing", page = PAGE, group = G_GROW, type = "number", min = 0, max = 40, step = 1,
        label = L["Spacing (px)"], desc = L["The gap between two auras in a line."],
    },
    {
        path = "container.layout.lineSpacing", page = PAGE, group = G_GROW, type = "number", min = 0, max = 40, step = 1,
        label = L["Line spacing (px)"], desc = L["The gap between two rows or columns."],
    },

    {
        path = "container.layout.scale", page = PAGE, group = G_FRAME, type = "number", min = 0.5, max = 3, step = 0.05,
        label = L["Scale"], desc = L["This container's scale. Multiplied by Master scale on the General page."],
    },
    {
        path = "container.layout.alpha", page = PAGE, group = G_FRAME, type = "number", min = 0, max = 1, step = 0.05,
        isPercent = true, label = L["Opacity"], desc = L["This container's opacity. Multiplied by Master alpha on the General page."],
    },
    {
        path = "container.layout.strata", page = PAGE, group = G_FRAME, type = "string",
        values = NS.Choices(C.STRATA, C.STRATA_LABELS), label = L["Strata"],
        desc = L["Which layer of the interface the container draws in."],
    },
    {
        path = "container.layout.level", page = PAGE, group = G_FRAME, type = "number", min = 1, max = 100, step = 1,
        label = L["Frame level"], desc = L["The order within the strata; higher draws on top."],
    },

    {
        path = "container.behavior.tooltips", page = PAGE, group = G_MOUSE, type = "bool",
        label = L["Show tooltips"], desc = L["Show an aura's tooltip when hovering it."],
    },
    {
        path = "container.behavior.tooltipInCombat", page = PAGE, group = G_MOUSE, type = "bool",
        label = L["Tooltips in combat"], desc = L["Keep showing tooltips while you are in combat."],
    },
    {
        path = "container.behavior.tooltipAnchor", page = PAGE, group = G_MOUSE, type = "string",
        values = NS.Choices(C.TOOLTIP_ANCHORS, C.TOOLTIP_ANCHOR_LABELS), label = L["Tooltip position"],
        desc = L["Where the tooltip appears."],
    },
    {
        path = "container.behavior.cancelOnRightClick", page = PAGE, group = G_MOUSE, type = "bool",
        label = L["Right-click to cancel"], desc = L["Right-click one of your own buffs or weapon enchants to cancel it."],
    },
    {
        path = "container.behavior.clickThrough", page = PAGE, group = G_MOUSE, type = "bool",
        label = L["Click-through"], desc = L["Let the mouse pass through this container: no tooltips and no clicks."],
    },
})

-- ---------------------------------------------------------------------------
-- The frame picker
-- ---------------------------------------------------------------------------

local function pickFrame()
    local cfg, id = NS.ActiveContainer()
    if not cfg then return end
    if InCombatLockdown() then
        return NS.Printf("|cff808080%s|r", L["cannot pick a frame during combat — attaching to a frame waits until combat ends"])
    end
    -- Get the settings window out of the way so the frames behind it can be clicked.
    if SettingsPanel and SettingsPanel.Close then pcall(SettingsPanel.Close, SettingsPanel, true) end
    NS.FramePicker.Start(function(name)
        NS.SetByPath("container.attach.frame", name, id)
        NS.SetByPath("container.attach.mode", "frame", id)
        NS.OpenOptionsPage(PAGE)
    end, function()
        NS.OpenOptionsPage(PAGE)
    end)
end

local function afterPosition(ctx)
    H.InlineButtonPair(ctx,
        { text = L["Pick a frame…"], onClick = pickFrame,
          tooltip = L["Close the settings, then left-click any frame on screen to attach this container to it. Right-click or Escape cancels."] },
        { text = L["Attach to the screen"], onClick = function()
            NS.SetByPath("container.attach.mode", "screen")
          end,
          tooltip = L["Detach this container and place it on the screen again."] })
end

NS.RegisterContainerPage(PAGE, L["Layout"], "AuraMasterLayoutPanel", {
    afterGroup = { [G_POS] = afterPosition },
})
