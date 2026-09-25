local _, NS = ...

-- settings/Layout.lua — where a container sits and how its auras are arranged.
--
--     band      [Container ▾]
--     [ Frame ][ Anchor ][ Growth ][ Mouse ][ Label ]
--     Anchor  [Attach to]
--             -- Screen --            [Point] [Relative point] / [X] [Y]
--             -- Another container -- [Container] | joins line / [Parent container anchor point] [This container anchor point]
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

-- ---------------------------------------------------------------------------
-- Growth conflicts on attach (batch 9 GC-1, E3)
-- ---------------------------------------------------------------------------
-- A container attached to another flows like its chain root, and its own Growth settings are kept
-- for a detach (L-6; nothing is written). When the two differ, a pick on the panel asks first
-- (AURAMASTER_ATTACH_FLOW, through the rows' confirmWrite and settings/OptionsSetup.lua's
-- confirmFirst); a write made without asking (/am set, a reset) says so in one chat line, and so does
-- a detach that brings the container's own flow back.

local ATTACH_POPUP = "AURAMASTER_ATTACH_FLOW"
local FLOW_ROW = { axis = L["Fill"], growH = L["Grow horizontally"], growV = L["Grow vertically"] }
local FLOW_VALUES = { axis = C.AXIS_LABELS, growH = C.GROW_H_LABELS, growV = C.GROW_V_LABELS }

-- True while the popup's OnAccept writes: the player has just read what changes, so no chat line.
local confirmed = false

--- The flow a change takes, in words: "Fill: Columns (...), Grow horizontally: Right".
local function flowWords(change)
    local from, base = change.root.layout or {}, NS.CONTAINER_TEMPLATE.layout or {}
    local parts = {}
    for i, k in ipairs(change.keys) do
        local v = from[k] or base[k]
        parts[i] = FLOW_ROW[k] .. ": " .. L[FLOW_VALUES[k][v] or tostring(v)]
    end
    return table.concat(parts, ", ")
end

--- The popup and its text when attaching `cfg` to container `targetId` changes how it flows, else nil.
local function attachPrompt(cfg, targetId)
    local change = NS.Anchors.FlowChangeOnAttach(cfg, targetId)
    if not change then return nil end
    local target = NS.Database.FindContainer(tonumber(targetId))
    local name = tostring(cfg.name)
    local text = L["Attach '%s' to '%s'? '%s' will fill and grow like '%s' (%s). Its own Growth settings are kept and come back if you detach it."]
        :format(name, tostring(target.name), name, tostring(change.root.name), flowWords(change))
    if change.followers > 0 then
        text = text .. L[" %d container(s) attached to it follow too."]:format(change.followers)
    end
    return ATTACH_POPUP, text
end

--- The Container row's confirmWrite: a new target picked in container mode.
local function confirmTarget(v, id)
    local cfg = NS.Database.FindContainer(id)
    local at = cfg and cfg.attach
    if not (at and at.mode == "container") or tonumber(v) == tonumber(at.container) then return nil end
    return attachPrompt(cfg, v)
end

--- The Attach to row's confirmWrite: a switch into container mode with a target already stored.
local function confirmMode(v, id)
    local cfg = NS.Database.FindContainer(id)
    local at = cfg and cfg.attach
    if v ~= "container" or not at or at.mode == "container" then return nil end
    return attachPrompt(cfg, at.container)
end

StaticPopupDialogs[ATTACH_POPUP] = {
    -- The whole question is built by attachPrompt and handed in as the one argument, so a container
    -- name holding a % cannot break the format.
    text         = "%s",
    button1      = L["Attach"],
    button2      = L["Cancel"],
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    OnAccept     = function(_, data)
        -- The same gate as the Delete popup: one accepted after combat started writes nothing.
        if InCombatLockdown() then
            return NS.Printf("|cff808080%s|r", L["cannot attach a container during combat; try again when combat ends"])
        end
        if not data then return end
        -- The row's validate checks the loop again: the chain may have changed while the popup was up.
        confirmed = true
        NS.SetByPath(data.path, data.value, data.id)
        confirmed = false
        H.RefreshAllPanels()
    end,
    OnCancel     = function() NS.RequestPanelRefresh() end,
    OnHide       = function() NS.RequestPanelRefresh() end,
}

--- The chat line for an attachment written without the popup, when it changes how `cfg` flows.
local function sayAttached(cfg, targetId)
    if confirmed then return end
    local change = NS.Anchors.FlowChangeOnAttach(cfg, targetId)
    if not change then return end
    NS.Printf("%s", L["'%s' now grows like '%s'; its own Growth settings are kept."]:format(
        tostring(cfg.name), tostring(change.root.name)))
end

--- The chat line for a detach from container `targetId` that brings `cfg`'s own flow back (E9 q7:
--- a line, not a popup; its followers re-flow with it).
local function sayDetached(cfg, targetId)
    if not NS.Anchors.FlowChangeOnAttach(cfg, targetId) then return end
    local target = NS.Database.FindContainer(tonumber(targetId))
    NS.Printf("%s", L["'%s' is no longer attached to '%s' and fills and grows by its own Growth settings again."]:format(
        tostring(cfg.name), tostring(target and target.name)))
end

--- After an attach write: a new or moved attachment (`now`, from `oldTarget` to `newTarget`), or a
--- detach, each said in chat when it changes how the container flows.
local function flowNotice(cfg, was, now, oldTarget, newTarget)
    if now and (not was or tonumber(oldTarget) ~= tonumber(newTarget)) then return sayAttached(cfg, newTarget) end
    if was and not now then sayDetached(cfg, oldTarget) end
end

-- ---------------------------------------------------------------------------
-- Attachments starting and ending
-- ---------------------------------------------------------------------------
-- A new attachment needs nothing written: its two points are Automatic until the player picks one
-- (batch 11 G2), and Automatic follows the parent's growth and the two styles (G3). The mode and
-- target rows only say in chat when an attach or detach changes how the container flows.

--- Whether container `cfg` attached to container `targetId` would follow it: a container, not itself,
--- not closing a loop.
local function usable(cfg, targetId)
    local id = tonumber(targetId)
    if not id or id == 0 or id == cfg.id then return false end
    return NS.Database.FindContainer(id) ~= nil and not NS.Anchors.WouldCycle(cfg.id, id)
end

--- The attach mode row's onChange: a switch into container mode with a usable target stored makes a
--- new attachment; a switch out of it ends one.
local function modeChanged(v, id, old)
    local cfg = NS.Database.FindContainer(id)
    if not cfg then return end
    local target = cfg.attach and cfg.attach.container
    local was, now = old == "container" and usable(cfg, target), v == "container" and usable(cfg, target)
    flowNotice(cfg, was, now, target, target)
end

--- The target row's onChange: redraw the attachment line, re-apply the parent it left (its strip
--- side depends on its followers; ContainerManager re-applies the new one), and say in chat when a
--- first usable target in container mode changes how it flows.
local function targetChanged(v, id, old)
    structural()
    local cfg = NS.Database.FindContainer(id)
    if not cfg then return end
    local oldId = tonumber(old)
    if oldId and oldId ~= tonumber(v) and NS.ContainerManager.instances[oldId] then
        NS.ContainerManager.RequestApply(oldId)
    end
    local inMode = cfg.attach and cfg.attach.mode == "container"
    local was, now = inMode and usable(cfg, old), inMode and usable(cfg, v)
    flowNotice(cfg, was, now, old, v)
end

-- ---------------------------------------------------------------------------
-- The two anchor points (batch 11 G1, G2, G7)
-- ---------------------------------------------------------------------------
-- A follower joins its parent by two absolute points, each stored on its own and nil for Automatic
-- (modules/Anchors.lua's AttachPoints: the matching half of the default pair, G3). Each dropdown
-- offers "Automatic (<the point in effect>)" first, then the nine points; any pair is stored and
-- nothing is refused: "if it looks weird, it's on the user". The rows are `nilAs = "auto"`
-- (settings/Schema.lua): the panel and `/am get` read a stored nil as auto, and auto, in any case,
-- is written as nil. `/am set` takes the nine names in any case too (cliParse).

local AUTO_POINT = "auto"
local IS_POINT = {}
for _, point in ipairs(C.POINTS) do IS_POINT[point] = true end

--- What was typed, as a row value: a point name or auto in upper case becomes the value itself.
local function foldPoint(text)
    local word = tostring(text or ""):match("^%s*(.-)%s*$")
    local upper = word:upper()
    if upper == "AUTO" then return AUTO_POINT end
    if IS_POINT[upper] then return upper end
    return word
end

--- Whether `v` is one of the nine points or auto, in any case; nil is Automatic too.
local function validPoint(v)
    if v == nil then return true end
    if type(v) ~= "string" then return false end
    local upper = v:upper()
    return upper == "AUTO" or IS_POINT[upper] == true
end

--- The stored form: the point token, or nil for Automatic.
local function storedPoint(v)
    if type(v) ~= "string" then return nil end
    local upper = v:upper()
    if IS_POINT[upper] then return upper end
    return nil
end

--- A point row's values: "Automatic (<the point Automatic puts in effect>)", then the nine points.
--- The Automatic entry names Automatic's own point even while the row holds a pick (AutoPoints, not
--- AttachPoints), so it says what choosing it would do. `half` picks the child's (1) or the
--- parent's (2) point.
local function pointChoices(half)
    return function()
        local own, rel = NS.Anchors.AutoPoints(NS.ActiveContainer())
        local inEffect = (half == 1) and own or rel
        local out = { { value = AUTO_POINT, text = L["Automatic (%s)"]:format(L[C.POINT_LABELS[inEffect]]) } }
        for _, point in ipairs(C.POINTS) do
            local n = #out
            out[n + 1] = { value = point, text = L[C.POINT_LABELS[point]] }
        end
        return out
    end
end

--- One of the two point rows. Structural: the attachment line and the other row's Automatic entry
--- read the pick. The write's CONFIG_CHANGED re-places the container, its parent and its followers
--- (modules/ContainerManager.lua's PARENT_PATHS, modules/Anchors.lua's FLOW_PATHS).
local function pointRow(path, half, label, desc, startsLine)
    return {
        path = path, page = PAGE, group = G_ANCHOR, subgroup = S_CONTAINER, shownWhen = CONTAINER_ONLY,
        type = "string", values = pointChoices(half), startsLine = startsLine, label = label, desc = desc,
        nilAs = AUTO_POINT, validate = validPoint, normalize = storedPoint, cliParse = foldPoint,
        onChange = structural,
    }
end

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
        -- changes, from the panel, `/am set` or a reset alike. Its onChange only starts or ends an
        -- attachment (the new one's default side, E5).
        path = MODE, page = PAGE, group = G_ANCHOR, type = "string", onChange = modeChanged,
        -- Asks first when a stored target would change how it flows (GC-1): panel only.
        confirmWrite = confirmMode,
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
        shownWhen = CONTAINER_ONLY, type = "number", values = attachTargets, label = L["Parent container"],
        desc = L["The container to attach to when 'Another container' is chosen. This one continues its flow: fill and growth follow it, the two anchor points below say where it joins it (below it, Automatic), and the gap to it is this container's own spacing. The X and Y offsets nudge it from there. A chain that would loop falls back to the screen."],
        -- Structural: the attachment line beside it (attachedLine) names the target.
        onChange = targetChanged,
        -- Asks first when the chain it joins flows differently from its own Growth (GC-1): panel only.
        confirmWrite = confirmTarget,
        -- `fromId` is the container the write targets, resolved by the seam: the id a caller names,
        -- else the selected container. A loop is checked from there, never from the selection.
        validate = function(v, fromId)
            local id = tonumber(v)
            return id ~= nil and (id == 0 or not NS.Anchors.WouldCycle(fromId, id))
        end,
    },
    pointRow("container.attach.relPoint", 2, L["Parent container anchor point"],
        L["The point of the container this one is attached to where the two join. Automatic picks one from the two containers' types and the way the chain grows. Any point can be picked."], true),
    pointRow("container.attach.childPoint", 1, L["This container anchor point"],
        L["The point of this container's first aura that joins the parent's anchor point. Automatic picks one from the two containers' types and the way the chain grows. Any point can be picked."]),
    {
        -- Half width, so Pick a frame... (pairWith, below) can take the line's right half.
        path = "container.attach.frame", page = PAGE, group = G_ANCHOR, subgroup = S_FRAME, shownWhen = FRAME_ONLY,
        type = "string", dialogControl = "EditBox", maxLetters = 120, label = L["Frame name"],
        desc = L["The global name of the frame to attach to when 'Named frame' is chosen — or use Pick a frame... beside it. /fstack shows frame names."],
    },
    -- The named frame's point on the left and this container's on the right, as the owner asked
    -- (2026-09-26): the same order and names as Another container's two anchor-point rows.
    {
        path = "container.attach.relativePoint", page = PAGE, group = G_ANCHOR, subgroup = S_FRAME, shownWhen = FRAME_ONLY,
        type = "string", values = POINTS, startsLine = true, label = L["Named frame anchor point"],
        desc = L["The corner of the target the first aura's point is attached to."],
    },
    {
        path = "container.attach.point", page = PAGE, group = G_ANCHOR, subgroup = S_FRAME, shownWhen = FRAME_ONLY,
        type = "string", values = POINTS, label = L["This container anchor point"],
        desc = L["The corner of the container's first aura that is attached — the container's full size is secret, so it cannot be anchored itself. The other auras grow away from it as the Growth tab says."],
        -- Structural: the facing-growth hint under the tab (growsBackNote) reads it.
        onChange = structural,
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

local JUSTIFY_OK = {}
for _, k in ipairs(C.JUSTIFY) do JUSTIFY_OK[k] = true end

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
    -- Stored AUTO until the player picks (B9 E7); the dropdown shows the justify in effect through
    -- panelGet, never AUTO itself, and the row's reset writes AUTO back (the template's value).
    {
        path = "container.label.justifyH", page = PAGE, group = G_LABEL, type = "string",
        values = NS.Choices(C.JUSTIFY, C.JUSTIFY_LABELS), label = L["Justify"],
        desc = L["How the name lines up in its space. Until you pick one, Bars and Text containers center it and Icons containers line it up with the first icon."],
        validate = function(v) return v == C.LABEL_JUSTIFY_AUTO or JUSTIFY_OK[v] == true end,
        panelGet = function() return NS.Anchors.LabelJustify(NS.ActiveContainer()) end,
        disabledIf = labelOff,
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

--- Where the selected container is attached, in words, while it follows another container: the two
--- points in effect (Anchors.AttachPoints: each picked or Automatic) and the target's name. Empty in
--- any other case (the line is still drawn, so the dropdown keeps its half).
local function attachedText()
    local cfg = NS.ActiveContainer()
    if not NS.Anchors.FlowRoot(cfg) then return "" end
    local target = NS.Database.FindContainer(tonumber(cfg.attach.container))
    local point, relativePoint = NS.Anchors.AttachPoints(cfg)
    return L["Its %s joins the %s of '%s'"]:format(L[C.POINT_LABELS[point]],
        L[C.POINT_LABELS[relativePoint]], tostring(target and target.name))
end

--- The Container dropdown's right half (pairWith): the read-only attachment line.
local function attachedLine(_, line)
    local label = NS.AceGUI:Create("Label")
    label:SetRelativeWidth(0.5)
    label:SetText(attachedText())
    line:AddChild(label)
    return label
end

--- Above the Growth tab of a container that follows another: whose flow it follows. Named by the
--- chain root, because that is where the values come from. Above a chain root's: how many follow it
--- (GC-1), since a Growth change there moves them too, with no popup. The follower's note says why,
--- in the panel's muted gold for secondary text, with a row gap before the Growth rows (batch 10 F6).
local function growthIntro(ctx, cfg)
    if ctx.activeTab ~= G_GROW then return end
    local root = NS.Anchors.FlowRoot(cfg)
    if root then
        local note = L["Fill and growth follow '%s' because this container is attached to it."]
        H.TextRow(ctx, "|c" .. C.SECONDARY_GOLD .. note:format(tostring(root.name)) .. "|r")
        local scroll = H.EnsureScroll(ctx)
        if scroll then H.AddSpacer(scroll, H.ROW_VSPACER) end
        return
    end
    local followers = cfg and NS.Anchors.Followers(cfg.id) or {}
    local count = #followers
    if count > 0 then
        H.TextRow(ctx, L["%d container(s) attached to this one follow its fill and growth."]:format(count))
    end
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

--- The Anchor tab's notes, in order.
local function anchorNotes(ctx)
    growsBackNote(ctx)
end

NS.RegisterContainerPage(PAGE, L["Layout"], "AuraMasterLayoutPanel", {
    intro = growthIntro,
    afterGroup = { [G_ANCHOR] = anchorNotes },
    pairWith = {
        ["container.attach.container"] = attachedLine,
        ["container.attach.frame"] = pickButton,
    },
})
