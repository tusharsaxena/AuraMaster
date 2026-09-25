local _, NS = ...

-- settings/Layout.lua — where a container sits and how its auras are arranged.
--
--     band      [Container ▾]
--     [ Frame ][ Anchor ][ Growth ][ Mouse ][ Label ]
--     Anchor  [Attach to]
--             -- Screen --            [Point] [Relative point] / [X] [Y]
--             -- Another container -- [Container]
--             -- Named frame --       [Frame name] [Pick a frame...]   <- pairWith / [Point] [Relative point]
--             -- Offset --            [X offset] [Y offset]
--             (Named frame only: a gray hint when Point faces the growth; growsBackNote, below)
--     Label       [Show name label] / [X offset] [Y offset] / -- Font -- (the six font leaves)
--
-- A container attaches to the screen, to another container (following it as it grows) or to any
-- named frame (modules/Anchors.lua). Only the subsections the chosen mode reads are DRAWN (feedback
-- #4, LibKa0s v1.45.0's `shownWhen`): Screen for the screen; Another container, or Named frame, and
-- Offset for an attachment. The rows stay in the schema, so `/am set` and the resets reach every one
-- of them; switching Attach to redraws the tab once, on the next frame, through the library's own
-- selector watch. The frame picker (modules/FramePicker.lua) sits beside Frame name, so it is drawn
-- in Named frame mode; it closes the settings window, lets the player click a frame, writes the
-- mode itself and reopens this page.

local L = NS.L
local H = NS.Helpers
local C = NS.Constants

local PAGE = "layout"
-- Declared in this order because the tab strip is the groups' first-seen order.
local G_FRAME, G_ANCHOR, G_GROW, G_MOUSE = L["Frame"], L["Anchor"], L["Growth"], L["Mouse"]
local G_LABEL = L["Label"]
local S_SCREEN, S_CONTAINER, S_FRAME, S_OFFSET = L["Screen"], L["Another container"], L["Named frame"], L["Offset"]
local POINTS = NS.Choices(C.POINTS, C.POINT_LABELS)

-- The switched subsections under Attach to (LibKa0s-Options-1.0 `shownWhen`, W22): each row is
-- drawn only while the selected container's attach mode is the one (or one of those) named.
local MODE = "container.attach.mode"
local SCREEN_ONLY    = { path = MODE, equals = "screen" }
local CONTAINER_ONLY = { path = MODE, equals = "container" }
local FRAME_ONLY     = { path = MODE, equals = "frame" }
local ATTACHED_ONLY  = { path = MODE, equals = { "container", "frame" } }

--- A `disabledIf` predicate: the selected container follows another container's flow (L-6), so its
--- Fill and growth rows are dimmed. Only while the attachment is usable: a container set to follow
--- one it cannot (missing, a loop) sits on the screen with its own flow, and its rows stay live.
local function inherits()
    return NS.Anchors.FlowRoot(NS.ActiveContainer()) ~= nil
end

--- A Growth row's `panelGet` (settings/OptionsSetup.lua): the inherited value of layout `key` while
--- the selected container follows another, else nil, which shows the stored value. The row keeps its
--- path, so a write, /am get and a detach all use the container's own.
local function inherited(key)
    return function()
        local root = NS.Anchors.FlowRoot(NS.ActiveContainer())
        return root and root.layout and root.layout[key] or nil
    end
end

--- The containers the active one may attach to: "None", then every other one by name (B2-2).
local function attachTargets()
    local _, activeId = NS.ActiveContainer()
    local out = { { value = 0, text = L["None"] } }
    for _, c in ipairs(NS.Database.GetContainersByName()) do
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
        -- The selector of the switched subsections below: the library redraws the tab when it
        -- changes, from the panel, `/am set` or a reset alike, so it needs no onChange of its own.
        path = MODE, page = PAGE, group = G_ANCHOR, type = "string",
        values = NS.Choices(C.ATTACH_MODES, C.ATTACH_MODE_LABELS), label = L["Attach to"],
        desc = L["The screen (drag it anywhere), another container (it follows that container as it grows), or any named frame — a unit frame, an action bar. Only the settings for your choice are shown below."],
    },
    {
        path = "container.position.point", page = PAGE, group = G_ANCHOR, subgroup = S_SCREEN, shownWhen = SCREEN_ONLY,
        type = "string", values = POINTS, label = L["Point"],
        desc = L["The corner of the container's first aura that is placed on the screen. The other auras grow away from it as the Growth tab says. Dragging the container sets these for you."],
    },
    {
        path = "container.position.relativePoint", page = PAGE, group = G_ANCHOR, subgroup = S_SCREEN, shownWhen = SCREEN_ONLY,
        type = "string", values = POINTS, label = L["Relative point"], desc = L["The screen corner the first aura's point is measured from."],
    },
    {
        path = "container.position.x", page = PAGE, group = G_ANCHOR, subgroup = S_SCREEN, shownWhen = SCREEN_ONLY,
        type = "number", min = -2000, max = 2000, step = 1, label = L["X"], desc = L["Horizontal position, in pixels."],
    },
    {
        path = "container.position.y", page = PAGE, group = G_ANCHOR, subgroup = S_SCREEN, shownWhen = SCREEN_ONLY,
        type = "number", min = -2000, max = 2000, step = 1, label = L["Y"], desc = L["Vertical position, in pixels."],
    },
    {
        path = "container.attach.container", page = PAGE, group = G_ANCHOR, subgroup = S_CONTAINER,
        shownWhen = CONTAINER_ONLY, type = "number", values = attachTargets, label = L["Container"],
        desc = L["The container to attach to when 'Another container' is chosen. This one continues its flow: fill and growth follow it, the attachment points are set for you, and the gap to it is this container's own Spacing (its Line spacing when it fills rows). The X and Y offsets nudge it from there. A chain that would loop falls back to the screen."],
        -- Structural: the attachment line beside it (attachedLine) names the target.
        onChange = structural,
        -- `fromId` is the container the write targets, resolved by the seam: the id a caller names,
        -- else the selected container. A loop is checked from there, never from the selection.
        validate = function(v, fromId)
            local id = tonumber(v)
            return id ~= nil and (id == 0 or not NS.Anchors.WouldCycle(fromId, id))
        end,
    },
    {
        -- Half width, so Pick a frame... (pairWith, below) can take the line's right half.
        path = "container.attach.frame", page = PAGE, group = G_ANCHOR, subgroup = S_FRAME, shownWhen = FRAME_ONLY,
        type = "string", dialogControl = "EditBox", maxLetters = 120, label = L["Frame name"],
        desc = L["The global name of the frame to attach to when 'Named frame' is chosen — or use Pick a frame... beside it. /fstack shows frame names."],
    },
    {
        path = "container.attach.point", page = PAGE, group = G_ANCHOR, subgroup = S_FRAME, shownWhen = FRAME_ONLY,
        type = "string", values = POINTS, startsLine = true, label = L["Point"],
        desc = L["The corner of the container's first aura that is attached — the container's full size is secret, so it cannot be anchored itself. The other auras grow away from it as the Growth tab says."],
        -- Structural: the facing-growth hint under the tab (growsBackNote) reads it.
        onChange = structural,
    },
    {
        path = "container.attach.relativePoint", page = PAGE, group = G_ANCHOR, subgroup = S_FRAME, shownWhen = FRAME_ONLY,
        type = "string", values = POINTS, label = L["Relative point"], desc = L["The corner of the target the first aura's point is attached to."],
    },
    {
        path = "container.attach.x", page = PAGE, group = G_ANCHOR, subgroup = S_OFFSET, shownWhen = ATTACHED_ONLY,
        type = "number", min = -500, max = 500, step = 1,
        label = L["X offset"], desc = L["Horizontal offset from the attachment point, in pixels. Attached to another container, it nudges this one from the gap its Spacing leaves."],
    },
    {
        path = "container.attach.y", page = PAGE, group = G_ANCHOR, subgroup = S_OFFSET, shownWhen = ATTACHED_ONLY,
        type = "number", min = -500, max = 500, step = 1,
        label = L["Y offset"], desc = L["Vertical offset from the attachment point, in pixels. Attached to another container, it nudges this one from the gap its Spacing leaves."],
    },

    -- Fill and both growth rows are dimmed, showing the inherited values, while the container follows
    -- another's flow (L-6); per row, spacing and line spacing stay its own and stay live.
    {
        path = "container.layout.axis", page = PAGE, group = G_GROW, type = "string",
        values = NS.Choices(C.AXES, C.AXIS_LABELS), label = L["Fill"],
        desc = L["Lay auras out in rows or in columns. Bars usually stack in a column."],
        disabledIf = inherits, panelGet = inherited("axis"),
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
        disabledIf = inherits, panelGet = inherited("growH"),
    },
    {
        path = "container.layout.growV", page = PAGE, group = G_GROW, type = "string",
        values = NS.Choices(C.GROW_V, C.GROW_V_LABELS), label = L["Grow vertically"],
        desc = L["Which way new auras are added down or up."],
        disabledIf = inherits, panelGet = inherited("growV"),
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
        label = L["Show tooltips"], desc = L["Show an aura's tooltip when hovering it. On, the whole container's rect — padding included, not just the aura buttons — captures the mouse to make that possible, which also blocks mouseover targeting and mouseover macros anywhere under it; if this container overlaps a unit frame or sits over open ground you mouseover-target through, turn Click-through on there, or turn this off so the hover reaches what is behind the container instead."],
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
        label = L["Click-through"], desc = L["Let the mouse pass through this container: no tooltips and no clicks. This is the escape hatch for tooltips' whole-rect mouse capture — turn it on if this container sits over a unit frame or open ground and mouseover targeting or a mouseover macro needs to reach through it."],
    },
})

-- ---------------------------------------------------------------------------
-- The name label (batch 8 NL-4)
-- ---------------------------------------------------------------------------
-- The label's text is always the container's name (modules/Container.lua's ApplyLabel), so the tab
-- holds only whether it shows, where (an X/Y nudge from the strip's spot) and its font. Every row but
-- Show is dimmed while the label is off. The rows carry no `effect`: a write re-applies the selected
-- container (CONFIG_CHANGED), where the label is restyled and placed.

--- A `disabledIf` predicate: the selected container's label is off.
local function labelOff()
    local c = NS.ActiveContainer()
    return not (c and c.label and c.label.show)
end

NS.RegisterSchemaRows({
    {
        path = "container.label.show", page = PAGE, group = G_LABEL, type = "bool",
        label = L["Show name label"],
        desc = L["Show this container's name where its drag handle sits, locked or unlocked: outside the container, on the side its auras do not grow into, or beside its first aura when it is attached to another container. While unlocked, the drag handle moves out past it."],
    },
    {
        path = "container.label.x", page = PAGE, group = G_LABEL, type = "number", min = -200, max = 200, step = 1,
        label = L["X offset"], desc = L["Move the name label left or right, in pixels."], disabledIf = labelOff,
    },
    {
        path = "container.label.y", page = PAGE, group = G_LABEL, type = "number", min = -200, max = 200, step = 1,
        label = L["Y offset"], desc = L["Move the name label up or down, in pixels."], disabledIf = labelOff,
    },
})
-- The composer carries no disabledIf, so the font rows take it here (settings/Bars.lua's tooltips
-- are set the same way). Not the color swatch: a swatch is never grayed (anti-pattern #74).
local labelFont = H.FontGroup({
    prefix = "container.label.font.", page = PAGE, group = G_LABEL, subgroup = L["Font"],
    classColor = { source = "unit" },
})
for _, row in ipairs(labelFont) do
    if row.type ~= "color" then row.disabledIf = labelOff end
end
NS.RegisterSchemaRows(labelFont)

-- ---------------------------------------------------------------------------
-- The frame picker
-- ---------------------------------------------------------------------------

local function pickFrame()
    local function reopen() NS.OpenOptionsPage(PAGE) end
    if NS.FramePicker.PickFor(reopen, reopen) then
        -- Get the settings window out of the way so the frames behind it can be clicked.
        if SettingsPanel and SettingsPanel.Close then pcall(SettingsPanel.Close, SettingsPanel, true) end
    end
end

--- Pick a frame..., as Frame name's right half (the flow engine's pairWith seam, options-ui-§6). It
--- is a cell-filling button, so it takes the library's inset width rather than a flush half.
local function pickButton(_, line)
    local btn = NS.AceGUI:Create("Button")
    btn:SetText(L["Pick a frame..."])
    btn:SetRelativeWidth(H.BUTTON_PAIR_REL)
    btn:SetCallback("OnClick", pickFrame)
    H.AttachTooltip(btn, L["Pick a frame..."],
        L["Close the settings, then left-click any frame on screen to attach this container to it. Right-click or Escape cancels."])
    line:AddChild(btn)
    return btn
end

-- ---------------------------------------------------------------------------
-- Inherited flow (L-6)
-- ---------------------------------------------------------------------------

--- Where the selected container is attached, in words, while it follows another container: the
--- derived points and the target's name. Empty in any other case (the line is still drawn, so the
--- dropdown keeps its half).
local function attachedText()
    local cfg = NS.ActiveContainer()
    if not NS.Anchors.FlowRoot(cfg) then return "" end
    local target = NS.Database.FindContainer(tonumber(cfg.attach.container))
    local point, relativePoint = NS.Anchors.DerivedPoints(NS.Anchors.EffectiveLayout(cfg))
    return L["Attached by its %s to the %s of '%s'"]:format(L[C.POINT_LABELS[point]],
        L[C.POINT_LABELS[relativePoint]], tostring(target and target.name))
end

--- The Container dropdown's right half (pairWith): the read-only attachment line. The points are
--- derived from the parent's flow, never stored, so there is nothing to edit.
local function attachedLine(_, line)
    local label = NS.AceGUI:Create("Label")
    label:SetRelativeWidth(0.5)
    label:SetText(attachedText())
    line:AddChild(label)
    return label
end

--- Above the Growth tab of a container that follows another: whose flow it follows. Named by the
--- chain root, because that is where the values come from.
local function growthIntro(ctx, cfg)
    if ctx.activeTab ~= G_GROW then return end
    local root = NS.Anchors.FlowRoot(cfg)
    if root then H.TextRow(ctx, L["Fill and growth follow '%s'"]:format(tostring(root.name))) end
end

-- ---------------------------------------------------------------------------
-- The facing-growth hint (smoke feedback 2, D-3)
-- ---------------------------------------------------------------------------
-- Point places the corner of the FIRST aura: the anchor is one element in size, because the
-- container's full extent is secret and cannot be anchored, and the other auras grow away from it
-- (modules/Container.lua pins the engine at the growth corner). So a Named frame container whose
-- Point side faces the way its auras grow sits on one side of the frame and grows back across it: a
-- BOTTOM* point (sitting above the frame) with Grow vertically Down, a TOP* point with Up, a LEFT*
-- point (sitting right of the frame) with Grow horizontally Left, a RIGHT* point with Right. Named
-- frame only: a screen container has no frame to grow over, and a follower's points are derived
-- from its parent's flow so that they never face it.

local SMALL = { fontObject = "GameFontHighlightSmall" }
local GRAY = "|cff808080%s|r"
local OPPOSITE = { up = "down", down = "up", left = "right", right = "left" }

--- Whether a point's vertical side faces growth `growV` (its BOTTOM growing down, its TOP up).
local function facesV(point, growV)
    local side = point:match("^BOTTOM") and "down" or point:match("^TOP") and "up"
    return side == growV
end

--- Whether a point's horizontal side faces growth `growH` (its LEFT growing left, its RIGHT right).
local function facesH(point, growH)
    local side = point:match("LEFT$") and "left" or point:match("RIGHT$") and "right"
    return side == growH
end

--- The hint's lines for `cfg`, the vertical one first: none unless it is attached to a named frame
--- by a Point that faces its growth.
local function growsBackLines(cfg)
    local out = {}
    local at = cfg.attach
    if not (at and at.mode == "frame" and C.POINT_LABELS[at.point]) then return out end
    local point = at.point
    local growH, growV = NS.Container.Growth(NS.Anchors.EffectiveLayout(cfg) or {})
    local pointLabel = L[C.POINT_LABELS[point]]
    if facesV(point, growV) then
        out[1] = L["Point is %s and Grow vertically is %s, so the auras grow back over the frame this container is attached to. Set Grow vertically to %s on the Growth tab instead."]:format(
            pointLabel, L[C.GROW_V_LABELS[growV]], L[C.GROW_V_LABELS[OPPOSITE[growV]]])
    end
    if facesH(point, growH) then
        local n = #out
        out[n + 1] = L["Point is %s and Grow horizontally is %s, so the auras grow back over the frame this container is attached to. Set Grow horizontally to %s on the Growth tab instead."]:format(
            pointLabel, L[C.GROW_H_LABELS[growH]], L[C.GROW_H_LABELS[OPPOSITE[growH]]])
    end
    return out
end

--- After the Anchor tab's rows (afterGroup): the facing-growth hint, when it applies. Point's own
--- onChange redraws the tab; a growth change is made on the Growth tab, and coming back draws it.
local function growsBackNote(ctx)
    local cfg = NS.ActiveContainer()
    if not cfg then return end
    for _, line in ipairs(growsBackLines(cfg)) do
        H.TextRow(ctx, GRAY:format(line), SMALL)
    end
end

NS.RegisterContainerPage(PAGE, L["Layout"], "AuraMasterLayoutPanel", {
    intro = growthIntro,
    afterGroup = { [G_ANCHOR] = growsBackNote },
    pairWith = {
        ["container.attach.container"] = attachedLine,
        ["container.attach.frame"] = pickButton,
    },
})
