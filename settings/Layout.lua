local _, NS = ...

-- settings/Layout.lua — where a container sits and how its auras are arranged.
--
--     band      [Container ▾]
--     [ Frame ][ Anchor ][ Growth ][ Mouse ]
--     Anchor  [Attach to]
--             -- Screen --            [Point] [Relative point] / [X] [Y]
--             -- Another container -- [Container]
--             -- Named frame --       [Frame name] [Pick a frame…]   <- pairWith / [Point] [Relative point]
--             -- Offset --            [X offset] [Y offset]
--
-- A container attaches to the screen, to another container (following it as it grows) or to any
-- named frame (modules/Anchors.lua). A subsection the chosen mode does not read is dimmed through
-- its rows' `disabledIf`, re-read on every scalar refresh, so switching Attach to re-dims the page
-- in place. The frame picker (modules/FramePicker.lua) closes the settings window, lets the player
-- click a frame, and reopens this page; it switches the mode to Named frame itself, so it stays
-- live in every mode.

local L = NS.L
local H = NS.Helpers
local C = NS.Constants

local PAGE = "layout"
-- Declared in this order because the tab strip is the groups' first-seen order.
local G_FRAME, G_ANCHOR, G_GROW, G_MOUSE = L["Frame"], L["Anchor"], L["Growth"], L["Mouse"]
local S_SCREEN, S_CONTAINER, S_FRAME, S_OFFSET = L["Screen"], L["Another container"], L["Named frame"], L["Offset"]
local POINTS = NS.Choices(C.POINTS, C.POINT_LABELS)

--- A `disabledIf` predicate: the row is dimmed unless the selected container's attach mode is one
--- of `...`, and dimmed with no container at all.
local function onlyIn(...)
    local modes = {}
    for _, m in ipairs({ ... }) do modes[m] = true end
    return function()
        local c = NS.ActiveContainer()
        return not (c and c.attach and modes[c.attach.mode])
    end
end
local SCREEN_ONLY, CONTAINER_ONLY, FRAME_ONLY = onlyIn("screen"), onlyIn("container"), onlyIn("frame")
local ATTACHED_ONLY = onlyIn("container", "frame")

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
        path = "container.attach.mode", page = PAGE, group = G_ANCHOR, type = "string",
        values = NS.Choices(C.ATTACH_MODES, C.ATTACH_MODE_LABELS), label = L["Attach to"],
        desc = L["The screen (drag it anywhere), another container (it follows that container as it grows), or any named frame — a unit frame, an action bar. Only the settings for your choice are enabled below."],
        onChange = structural,
    },
    {
        path = "container.position.point", page = PAGE, group = G_ANCHOR, subgroup = S_SCREEN, disabledIf = SCREEN_ONLY,
        type = "string", values = POINTS, label = L["Point"],
        desc = L["Used while attached to the screen. Dragging the container sets these for you."],
    },
    {
        path = "container.position.relativePoint", page = PAGE, group = G_ANCHOR, subgroup = S_SCREEN, disabledIf = SCREEN_ONLY,
        type = "string", values = POINTS, label = L["Relative point"], desc = L["The screen corner it is measured from."],
    },
    {
        path = "container.position.x", page = PAGE, group = G_ANCHOR, subgroup = S_SCREEN, disabledIf = SCREEN_ONLY,
        type = "number", min = -2000, max = 2000, step = 1, label = L["X"], desc = L["Horizontal position, in pixels."],
    },
    {
        path = "container.position.y", page = PAGE, group = G_ANCHOR, subgroup = S_SCREEN, disabledIf = SCREEN_ONLY,
        type = "number", min = -2000, max = 2000, step = 1, label = L["Y"], desc = L["Vertical position, in pixels."],
    },
    {
        path = "container.attach.container", page = PAGE, group = G_ANCHOR, subgroup = S_CONTAINER,
        disabledIf = CONTAINER_ONLY, type = "number", values = attachTargets, label = L["Container"],
        desc = L["The container to attach to when 'Another container' is chosen. A chain that would loop falls back to the screen."],
        -- `fromId` is the container the write targets, resolved by the seam: the id a caller names,
        -- else the selected container. A loop is checked from there, never from the selection.
        validate = function(v, fromId)
            local id = tonumber(v)
            return id ~= nil and (id == 0 or not NS.Anchors.WouldCycle(fromId, id))
        end,
    },
    {
        -- Half width, so Pick a frame… (pairWith, below) can take the line's right half.
        path = "container.attach.frame", page = PAGE, group = G_ANCHOR, subgroup = S_FRAME, disabledIf = FRAME_ONLY,
        type = "string", dialogControl = "EditBox", maxLetters = 120, label = L["Frame name"],
        desc = L["The global name of the frame to attach to when 'Named frame' is chosen — or use Pick a frame… beside it. /fstack shows frame names."],
    },
    {
        path = "container.attach.point", page = PAGE, group = G_ANCHOR, subgroup = S_FRAME, disabledIf = FRAME_ONLY,
        type = "string", values = POINTS, startsLine = true, label = L["Point"],
        desc = L["The corner of this container that is attached."],
    },
    {
        path = "container.attach.relativePoint", page = PAGE, group = G_ANCHOR, subgroup = S_FRAME, disabledIf = FRAME_ONLY,
        type = "string", values = POINTS, label = L["Relative point"], desc = L["The corner of the target it is attached to."],
    },
    {
        path = "container.attach.x", page = PAGE, group = G_ANCHOR, subgroup = S_OFFSET, disabledIf = ATTACHED_ONLY,
        type = "number", min = -500, max = 500, step = 1,
        label = L["X offset"], desc = L["Horizontal offset from the attachment point, in pixels."],
    },
    {
        path = "container.attach.y", page = PAGE, group = G_ANCHOR, subgroup = S_OFFSET, disabledIf = ATTACHED_ONLY,
        type = "number", min = -500, max = 500, step = 1,
        label = L["Y offset"], desc = L["Vertical offset from the attachment point, in pixels."],
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
        path = "container.behavior.tooltips", page = PAGE, group = G_MOUSE, type = "bool",
        label = L["Show tooltips"], desc = L["Show an aura's tooltip when hovering it. Off, the hover reaches what is behind the container, so a unit there shows its own tooltip."],
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

--- Pick a frame…, as Frame name's right half (the flow engine's pairWith seam, options-ui-§6). It
--- is a cell-filling button, so it takes the library's inset width rather than a flush half.
local function pickButton(_, line)
    local btn = NS.AceGUI:Create("Button")
    btn:SetText(L["Pick a frame…"])
    btn:SetRelativeWidth(H.BUTTON_PAIR_REL)
    btn:SetCallback("OnClick", pickFrame)
    H.AttachTooltip(btn, L["Pick a frame…"],
        L["Close the settings, then left-click any frame on screen to attach this container to it. Right-click or Escape cancels."])
    line:AddChild(btn)
    return btn
end

NS.RegisterContainerPage(PAGE, L["Layout"], "AuraMasterLayoutPanel", {
    pairWith = { ["container.attach.frame"] = pickButton },
})
