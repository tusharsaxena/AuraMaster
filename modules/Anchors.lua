local _, NS = ...

-- modules/Anchors.lua — where a container sits, and the handle a player drags it by.
--
-- Every container has an ANCHOR: a small frame of ours, sized to one element, that the aura engine
-- hangs its layout from. Positions are STORED and never read back off an aura frame, because an
-- engine container's geometry is secret (its size depends on how many auras it holds) — the only
-- frame whose position is ever read is the anchor, and only right after a drag, when it is attached
-- to UIParent and carries nothing secret.
--
-- A container attaches to one of three things (container.attach.mode):
--   screen     UIParent, at container.position — the only mode a drag can change;
--   container  another container's ENGINE frame, so it follows that container as it grows. The
--              anchor inherits DisableUntrustedLayoutScriptsTemplate, Blizzard's opt-in for a frame
--              that anchors to an aura container (whose layout scripts are forbidden to addons).
--              While that container previews it hangs from its preview extent instead, and while
--              it is unlocked and predicted empty from its one-element anchor (Anchors.HangMode);
--   frame      any named frame — a unit frame, another add-on's bar — re-resolved when the add-on
--              that creates it loads, and again when combat ends (Anchors.ResolvePending).
-- A chain that would loop back on itself, a target that does not exist, or a frame that is forbidden
-- falls back to the screen position rather than to nowhere, and says so in the [Anchor] debug trace.

NS.Anchors = NS.Anchors or {}
local Anchors = NS.Anchors
local D = NS.CONTAINER_TEMPLATE

-- Frame-mode containers whose frame did not exist yet, by container id.
local pending = {}

-- The room a container's followers leave for its drag strip, defined with the strip below.
local stripRoom

--- Whether attaching container `fromId` to container `toId` would close a loop.
--- @return boolean
function Anchors.WouldCycle(fromId, toId)
    local id, hops = toId, 0
    while id ~= nil and hops < 64 do
        if id == fromId then return true end
        local c = NS.Database.FindContainer(id)
        if not (c and c.attach and c.attach.mode == "container") then return false end
        id = tonumber(c.attach.container)
        hops = hops + 1
    end
    return hops >= 64
end

--- A named frame usable as an anchor target, or nil.
function Anchors.ResolveFrame(name)
    if type(name) ~= "string" or name == "" then return nil end
    local f = _G[name]
    if type(f) ~= "table" or type(f.GetObjectType) ~= "function" then return nil end
    if f.IsForbidden and f:IsForbidden() then return nil end
    return f
end

local function toScreen(anchor, cfg)
    local pos = cfg.position or {}
    anchor:SetPoint(pos.point or D.position.point, UIParent,
        pos.relativePoint or pos.point or D.position.relativePoint,
        tonumber(pos.x) or 0, tonumber(pos.y) or 0)
end

--- Whether `name` names a frame that EXISTS but is forbidden to add-ons: never a target, now or after
--- any add-on loads.
local function isForbidden(name)
    local f = _G[name]
    return type(f) == "table" and type(f.IsForbidden) == "function" and f:IsForbidden() and true or false
end

--- The frame container `container` attaches to and the mode that names it, or nil when its setting
--- names nothing usable: a missing or looping container, or a frame that is absent or forbidden. A
--- named frame that simply does not exist YET is remembered, to be retried when an add-on loads; a
--- forbidden one is not, since no add-on loading makes it a target.
--- The live container `container`'s attach settings `at` name, or nil when it cannot be used: missing,
--- itself, or closing a loop.
local function targetContainer(container, at)
    local targetId = tonumber(at.container)
    local target = targetId and NS.ContainerManager and NS.ContainerManager.instances[targetId]
    if target and targetId ~= container.id and not Anchors.WouldCycle(container.id, targetId) then
        return target
    end
    return nil
end

--- What a container attached to container `t` hangs from, as ContainerClass:ApplyVisibility last
--- recorded it (`t.hangMode`):
---   preview  test mode: its preview extent, since its engine is disabled and keeps a stale rect (L-4);
---   slot     unlocked, not previewing and predicted EMPTY (modules/EmptyWatch.lua, batch 9 HG-1):
---            its anchor, exactly one element, the rect its placeholder outline marks. Its engine
---            holds a 1x1 provisional rect while it has no aura, so a follower hung from it sat
---            about 5px under the parent's top, and an empty chain collapsed onto itself (#9);
---   engine   anything else (locked, or unlocked holding auras or not knowable): the engine, so a
---            follower grows and shrinks with its auras.
--- Before its first visibility pass a container answers from its preview state.
--- @return string  "preview" | "slot" | "engine"
function Anchors.HangMode(t)
    return t.hangMode or (t.previewShown and "preview") or "engine"
end

--- The frame to hang from, the mode that names it and, for a container target, the live container.
local function targetFor(container, at)
    if at.mode == "container" then
        local target = targetContainer(container, at)
        if target then
            local mode = Anchors.HangMode(target)
            if mode == "preview" and target.previewExtent then return target.previewExtent, "container", target end
            if mode == "slot" then return target.anchor, "container", target end
            return target.engine or target.anchor, "container", target
        end
    elseif at.mode == "frame" then
        local f = Anchors.ResolveFrame(at.frame)
        if f then return f, "frame" end
        if at.frame and at.frame ~= "" and not isForbidden(at.frame) then
            pending[container.id] = true
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Inherited flow (L-6)
-- ---------------------------------------------------------------------------
-- A container attached to ANOTHER container continues that container's flow: its fill axis and both
-- growth directions are its chain root's, and its anchor points are derived so it stacks below the
-- parent (above, growing up), one of its own gaps past the parent's block (Anchors.SeamOffset, SS-1).
-- Its offsets nudge on top of that gap; its per-line count and spacing stay its own. Nothing is
-- written: the stored values stay as they are, so a detach restores them at the next apply. A
-- frame-attached or screen container inherits nothing — a named frame has no flow to continue.

local FLOW_KEYS = { "axis", "growH", "growV" }

-- The writes that change what a follower inherits or where its chain leads, so they re-apply every
-- container following the one written (Anchors.Followers; modules/ContainerManager.lua).
local FLOW_PATHS = {
    ["container.layout"] = true,
    ["container.layout.axis"] = true,
    ["container.layout.growH"] = true,
    ["container.layout.growV"] = true,
    ["container.attach.mode"] = true,
    ["container.attach.container"] = true,
}

--- The container whose flow `cfg` follows, or nil when it follows none: not attached to a container,
--- or attached to one Place cannot use (missing, itself, a loop), which puts it on the screen. The
--- walk goes up the chain while each target is itself container-attached, and stops at the first
--- link that leads nowhere, because that container sits on the screen with its own flow.
function Anchors.FlowRoot(cfg)
    local at = cfg and cfg.attach
    if not (at and at.mode == "container") then return nil end
    local id = tonumber(at.container)
    if id == nil or id == cfg.id or Anchors.WouldCycle(cfg.id, id) then return nil end
    local root, hops = NS.Database.FindContainer(id), 0
    while root and hops < 64 do
        local up = root.attach
        local nextId = up and up.mode == "container" and tonumber(up.container)
        local nextCfg = nextId and NS.Database.FindContainer(nextId)
        if not nextCfg then return root end
        root, hops = nextCfg, hops + 1
    end
    return root
end

--- The layout `cfg` actually flows by. For a container that follows another it is a shallow copy of
--- its own layout with the fill axis and both growth directions taken from its chain root; for any
--- other it is `cfg.layout` itself, with no allocation. Every flow reader goes through this:
--- Container.FlowSettings, Preview.Offset, the handle's side and the anchor's clamp.
--- @return table|nil
function Anchors.EffectiveLayout(cfg)
    local root = Anchors.FlowRoot(cfg)
    if not root then return cfg.layout end
    local out = {}
    for k, v in pairs(cfg.layout or {}) do out[k] = v end
    local from = root.layout or {}
    for _, k in ipairs(FLOW_KEYS) do out[k] = from[k] end
    return out
end

--- The points that attach a child to a parent laid out by `L`: the child's point and the parent's
--- relative point. The child stacks below the parent (above, when it grows up), on the side the
--- parent's lines start from, whether the parent fills rows or columns (IA-1). A wrapped row parent's
--- target spans every line, so the child sits below the last. Chosen points: issue #22.
--- @return string point, string relativePoint
function Anchors.DerivedPoints(L)
    local h = (L.growH ~= "left") and "LEFT" or "RIGHT"
    if L.growV ~= "up" then return "TOP" .. h, "BOTTOM" .. h end
    return "BOTTOM" .. h, "TOP" .. h
end

--- The offset that leaves one of the child's own gaps between its parent's block and itself, for a
--- child laid out by `L` (its effective layout). The chain always stacks vertically (IA-1), so the
--- gap is the one the child leaves between consecutive elements in that direction: its spacing when
--- it fills columns, its line spacing when it fills rows (SS-1). Downward when it grows down, upward
--- when it grows up, so a chain growing up no longer overlaps. The child's own values, because
--- SetPoint offsets are in the positioned frame's scale, which is the child's (Container:Apply sets
--- it on the anchor), so the seam matches its inner gaps under any Scale. Never negative.
--- @return number x, number y
function Anchors.SeamOffset(L)
    local gap = (L.axis == "vertical") and L.spacing or L.lineSpacing
    gap = math.max(0, tonumber(gap) or 0)
    return 0, (L.growV == "up") and gap or -gap
end

--- Whether container `c`'s chain of container attachments passes through container `id`.
local function follows(c, id)
    local at, hops = c.attach, 0
    while at and at.mode == "container" and hops < 64 do
        local targetId = tonumber(at.container)
        if targetId == id then return true end
        local nextCfg = targetId and NS.Database.FindContainer(targetId)
        at, hops = nextCfg and nextCfg.attach, hops + 1
    end
    return false
end

--- Every container whose chain passes through container `id`, directly or further down: the ones a
--- change to `id`'s flow or attachment moves.
--- @return table  container ids
function Anchors.Followers(id)
    local out = {}
    for _, c in ipairs(NS.Database.GetContainers()) do
        if c.id ~= id and follows(c, id) then
            out[#out + 1] = c.id
        end
    end
    return out
end

--- Whether a write to `path` changes what a container's followers inherit or where they sit.
function Anchors.MovesFollowers(path)
    return FLOW_PATHS[path] == true
end

--- A container's own scale, which its anchor's SetPoint offsets are in. The Master scale multiplies
--- every container alike (Container:Apply), so it cancels between a parent and its follower.
local function ownScale(cfg)
    return math.max(0.1, tonumber(cfg.layout and cfg.layout.scale) or 1)
end

--- The seam's y offset `gy`, widened when the parent's strip needs more room than the seam leaves
--- (`room`, in the parent's screen units: stripRoom). Along the chain's growth, only by the shortfall,
--- so a seam with room enough is the locked one (SS-3) and no two strips in a chain overlap (EO-2).
local function clearStrip(L, cfg, gy, room)
    if room <= 0 then return gy end
    local extra = math.max(0, room / ownScale(cfg) - math.abs(gy))
    return (L.growV == "up") and gy + extra or gy - extra
end

--- The points and offsets container `cfg` attaches with. Attached to a container: points derived
--- from the flow it continues, and one of its own gaps across the seam with the stored X/Y added on
--- top as a nudge (SS-1, SS-2), widened where the parent's strip needs the room (EO-2). Attached to
--- a named frame: the stored points and offsets as they are.
--- @return string point, string relativePoint, number x, number y
local function attachSpec(cfg, at, mode, target)
    local x, y = tonumber(at.x) or 0, tonumber(at.y) or 0
    if mode == "container" then
        local L = Anchors.EffectiveLayout(cfg) or {}
        local point, relativePoint = Anchors.DerivedPoints(L)
        local gx, gy = Anchors.SeamOffset(L)
        gy = clearStrip(L, cfg, gy, target and stripRoom(target) or 0)
        return point, relativePoint, gx + x, gy + y
    end
    return at.point or D.attach.point, at.relativePoint or D.attach.relativePoint, x, y
end

--- Place one container's anchor from its settings. Returns the mode it actually ended up in, which
--- differs from the setting when a target could not be used.
--- @return string  "screen" | "container" | "frame"
function Anchors.Place(container)
    local cfg = container:Cfg()
    local anchor = container.anchor
    if not (cfg and anchor) then return "screen" end

    local w, h = NS.Style.ElementSize(cfg)
    anchor:SetSize(w, h)
    anchor:ClearAllPoints()
    pending[container.id] = nil

    local at = cfg.attach or {}
    local target, mode, owner = targetFor(container, at)
    if target then
        local point, relativePoint, x, y = attachSpec(cfg, at, mode, owner)
        local ok = pcall(anchor.SetPoint, anchor, point, target, relativePoint, x, y)
        if ok then return mode end
        anchor:ClearAllPoints()
    end
    if at.mode and at.mode ~= "screen" and NS.Debug then
        NS.Debug("Anchor", "container %s: %s target unavailable, screen fallback", container.id, at.mode)
    end
    toScreen(anchor, cfg)
    return "screen"
end

--- Re-place every container attached to `target` once what they hang from has changed since they
--- were last placed: its hang mode (Anchors.HangMode; test mode, lock, unlock and the empty
--- prediction: L-4, HG-1) or the
--- room its strip needs (stripRoom, EO-2). Called on every visibility pass
--- (ContainerClass:ApplyVisibility), so a pass that changes nothing re-places nothing. Layout work
--- beside an aura engine, so never under lockdown: the last placement stands, unrecorded, and the
--- first pass after combat catches up.
function Anchors.PlaceAttached(target)
    local mode, room = Anchors.HangMode(target), stripRoom(target)
    if (target.attachedPlacedFor == mode and target.attachedPlacedRoom == room) or InCombatLockdown() then
        return
    end
    target.attachedPlacedFor, target.attachedPlacedRoom = mode, room
    local CM = NS.ContainerManager
    if not CM then return end
    for _, inst in pairs(CM.instances) do
        local cfg = inst ~= target and inst:Cfg()
        local at = cfg and cfg.attach
        if at and at.mode == "container" and tonumber(at.container) == target.id then
            inst.placedAs = Anchors.Place(inst)
        end
    end
end

--- Re-place every container whose frame target did not exist when it was placed. Called whenever an
--- add-on loads, since that is when a new named frame can appear, and when combat ends, since an
--- add-on that loaded during combat could not be resolved then.
function Anchors.ResolvePending()
    if InCombatLockdown() then
        if NS.Debug then NS.Debug("Anchor", "pending resolve skipped under lockdown; retried when combat ends") end
        return
    end
    local CM = NS.ContainerManager
    if not CM then return end
    for id in pairs(pending) do
        local inst = CM.instances[id]
        if inst then Anchors.Place(inst) else pending[id] = nil end
    end
end

--- Which containers are still waiting on their frame (a test seam: tests/test_anchors.lua).
function Anchors.Pending()
    local out = {}
    for id in pairs(pending) do
        out[#out + 1] = id
    end
    table.sort(out)
    return out
end

--- An offset to one decimal place: what a drag stores.
local function round(v) return math.floor((tonumber(v) or 0) * 10 + 0.5) / 10 end

--- After a drag: read the anchor's point back (it is attached to UIParent and holds nothing secret)
--- and store it through the single write seam, on THIS container rather than the settings panel's
--- active one. One whole-section write: the position lands whole or not at all, announced once.
function Anchors.SavePosition(container)
    local anchor = container.anchor
    if not (anchor and anchor.GetPoint) then return end
    local point, _, relPoint, x, y = anchor:GetPoint(1)
    -- A screen-attached anchor holds nothing secret, but a read is guarded anyway (feedback E): a
    -- secret offset would raise in round(), and storing one would poison the saved position. `point`
    -- is checked before it is truth-tested below, so a secret point is never boolean-tested either.
    local S = NS.Secrets
    if not (S.CanAccess(point) and S.CanAccess(relPoint) and S.CanAccess(x) and S.CanAccess(y)) then
        if NS.Debug then NS.Debug("Anchor", "container %s: position reads secret, not saved", container.id) end
        return
    end
    if not point then return end
    NS.SetByPath("container.position",
        { point = point, relativePoint = relPoint or point, x = round(x), y = round(y) }, container.id)
end

-- ---------------------------------------------------------------------------
-- The drag handle
-- ---------------------------------------------------------------------------

-- A labeled strip OUTSIDE the anchor, on the side the auras do not grow into: a dark fill with a 1px
-- gold edge, a gold label, and inside its far end the media catalog's close mark (an X that disables
-- the container, batch 8 CX-3) immediately left of its help mark. Outside, because
-- the anchor is exactly one element in size and the first element sits on it: a handle covering the
-- anchor covered the first bar or icon. Nothing moves to make room for it — the anchor, the engine
-- (which may never be re-anchored once it holds groups) and the preview stay where they are.
-- The strip is LibKa0s-Widgets-1.0's (libs/LibKa0s/WidgetsDragHandle.lua, minor 3): the fill, the
-- edge, the label, the help and close marks with their own art fallbacks, the tooltips, the drag
-- scripts and the width arithmetic are the library's; what the X DOES (disableContainer) is ours. ConsumableMaster drew the same strip
-- over its macro bar, which is why the widget exists. Resolved at file load like every other library
-- seam here; absent, Anchors.BuildHandle answers nil and a container simply has no handle, which
-- Anchors.UpdateHandle and Container:Park already tolerate.
local KW   = LibStub and LibStub("LibKa0s-Widgets-1.0", true)
local DRAG = KW and KW.DRAG_HANDLE

-- The strip's height, the gap it leaves and what it keeps clear each side of its label are the
-- widget's numbers (`lib.DRAG_HANDLE`), read through DRAG rather than copied back here: a copy is a
-- second set to keep in step. This number is OURS, because nothing in the widget knows what an aura
-- engine stacks above its anchor.
local HANDLE_LEVEL = 50   -- how far above its anchor the strip sits: over every element it holds

-- The strip's height and gap as the name label (batch 8 NL-2) reads them: the label takes the strip's
-- spot and is as tall as the strip, and it still draws on a build without the widget, so the widget's
-- own figures stand in when it is missing.
local STRIP_H   = DRAG and DRAG.HEIGHT or 18
local STRIP_GAP = DRAG and DRAG.GAP or 2

--- Right-click (the strip or its "?"): the Containers page, with THIS container selected in its band
--- (feedback #9). Under combat lockdown the open is refused with options-ui-§2's gray line, and the
--- selection is left where it was: a refused click moves nothing. NS.OpenOptionsPage is the one
--- panel-open seam that carries the refusal; the panels are redrawn first, so a Containers page built
--- earlier shows the new subject when it opens.
local function openSettings(container)
    if not InCombatLockdown() then
        if NS.State then NS.State.SetActiveContainer(container.id) end
        if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
    end
    if NS.OpenOptionsPage then NS.OpenOptionsPage("containers") end
end

--- The tooltip descriptor the strip and its help mark share: the container's name, how to use the
--- handle, and — for an attached container only — where its offsets are set.
---
--- THE LINES ARE FUNCTIONS because the widget calls them on EVERY hover rather than capturing them
--- when the handle is built: a renamed container and a container that has just been attached or
--- detached both show through without rebuilding anything. The attached line carries its own gold
--- through the `{ entry, r, g, b }` shape, so it stays the color it is today instead of taking the
--- body band's white.
---
--- OWNED BY UIParent AT THE CURSOR (`tooltipOwner = "cursor"`), never by the hovered frame. The
--- anchor inherits DisableUntrustedLayoutScriptsTemplate (modules/Container.lua), and that
--- restriction reaches every frame anchored under it: the strip and the mark. GameTooltip does not
--- inherit the template, so the client refuses SetOwner on either ("Anchoring disallowed as dependent
--- object would inherit forbidden aspects: UntrustedLayoutScriptExecution"). ANCHOR_CURSOR depends on
--- nothing under the anchor.
local function tooltipSpec(container)
    local function attached()
        local cfg = container:Cfg()
        if cfg and cfg.attach and cfg.attach.mode ~= "screen" then
            return NS.L["Attached — set its offsets on the Layout page."]
        end
    end
    return {
        title = function()
            local cfg = container:Cfg()
            return cfg and cfg.name or NS.L["Container"]
        end,
        body = {
            NS.L["Drag to move. Right-click for settings."],
            { attached, 1, 0.82, 0 },
        },
    }
end

--- The close mark's left click (batch 8 CX-3): disable THIS container through the one write seam,
--- with no confirmation, and say in chat which one and how to bring it back. The row's `visibility`
--- effect does the rest exactly as the Enabled checkbox does: the visibility pass hides the preview,
--- the outline and this strip and re-places its followers, and none of that touches the protected
--- anchor, so it is combat-legal. A refused write prints its reason and nothing else.
local function disableContainer(container)
    local cfg = container:Cfg()
    local name = cfg and cfg.name or NS.L["Container"]
    local ok, err = NS.SetByPath("container.enabled", false, container.id)
    if not ok then
        if err then NS.Print(err) end
        return
    end
    NS.Printf(NS.L["%s disabled. Turn Enabled back on for it on the Containers page to bring it back."], name)
end

--- The close mark's own tooltip: the container's name (a function, read on every hover, so a rename
--- shows through) and what the click does. Cursor-owned like the strip's, through the same
--- `tooltipOwner` (see tooltipSpec).
local function closeTooltipSpec(container)
    return {
        title = function()
            local cfg = container:Cfg()
            return cfg and cfg.name or NS.L["Container"]
        end,
        body = {
            NS.L["Click to disable this container. Its settings are kept; turn Enabled back on for it on the Containers page to bring it back."],
        },
    }
end

--- Asked by the widget at every OnDragStart. Only a screen-attached container moves by dragging; an
--- attached one follows its target, and its offsets are set on the Layout page. Never mid-combat:
--- the anchor parents an aura engine.
local function canDrag(container)
    local cfg = container:Cfg()
    return (cfg and cfg.attach and cfg.attach.mode == "screen" and not InCombatLockdown()) and true or false
end

--- The handle's label: the container's name, and while test mode is on an orange TEST tag after it
--- (feedback #8), so the placeholders on screen read as placeholders. It sits ABOVE BuildHandle
--- because the strip is born with its text — `label` is the widget's one required string.
local function handleText(cfg)
    if not cfg then return "" end
    local name = cfg.name or ""
    if not (NS.State and NS.State.testMode) then return name end
    return ("%s  |c%s%s|r"):format(name, NS.Constants.TEST_TAG_COLOR, NS.L["TEST"])
end

--- Build the handle a player drags a container by: LibKa0s-Widgets-1.0's strip, wearing this
--- addon's strings, art and callbacks. Shown only while unlocked; it sits outside the anchor
--- (Anchors.UpdateHandle places it), so no element is covered and nothing moves to make room. The
--- one exception is the screen edge: while the handle shows, the anchor's clamp rect takes the strip
--- in (clampToHandle), so a container flush with the edge on the handle's side is pushed in by the
--- strip while unlocked and returns when locked. Its stored position does not change.
---
--- THE WIDGET BUILDS A PLAIN BUTTON, never a BackdropTemplate, and paints its edge with the painter
--- we hand it: under an anchor attached to another frame or container the strip's size can read
--- secret, and the Backdrop does arithmetic on that size on every SetBackdrop and every resize
--- (docs/midnight-quirks.md, "A backdrop on an engine button reads a secret size"). `number` hands it
--- NS.Secrets.NumberOr for the same reason, so a measured width that reads secret falls back to the
--- element instead of raising. The widget hides the strip at birth, exactly as this file did.
---
--- THE LEVEL IS OURS and is set after the build: the widget never places, sizes or shows the strip.
--- @return table|nil  nil without LibKa0s-Widgets-1.0, and in a client that cannot make the frame
function Anchors.BuildHandle(container)
    if not (KW and KW.DragHandle) then return nil end
    local anchor = container.anchor
    local handle = KW.DragHandle(anchor, {
        label        = handleText(container:Cfg()),
        moveFrame    = anchor,
        helpIcon     = NS.Icon and NS.Icon("help") or nil,
        closeIcon    = NS.Icon and NS.Icon("close") or nil,
        onClose      = function() disableContainer(container) end,
        closeTooltip = closeTooltipSpec(container),
        canDrag      = function() return canDrag(container) end,
        onDragStop   = function() Anchors.SavePosition(container) end,
        onRightClick = function() openSettings(container) end,
        tooltip      = tooltipSpec(container),
        tooltipOwner = "cursor",
        edge         = NS.Style.DrawEdge,
        number       = NS.Secrets.NumberOr,
    })
    if not handle then return nil end
    handle:SetFrameLevel(NS.Secrets.NumberOr(anchor:GetFrameLevel(), 0) + HANDLE_LEVEL)
    return handle
end

--- A frame's level, READ GUARDED (feedback E): an anchor attached to an engine container, or to a
--- frame anchored to one, can answer its level secret (FrameLevel is a secret aspect), and
--- arithmetic on a secret raises. An unreadable level is the one Container:Apply set from the stored
--- `layout.level`.
local function levelOf(frame, cfg)
    local stored = tonumber(cfg and cfg.layout and cfg.layout.level) or D.layout.level
    return NS.Secrets.NumberOr(frame:GetFrameLevel(), stored)
end

--- Put the strip on the side the auras do not grow into: above the anchor when they grow down,
--- below when they grow up, its edge lined up with the edge they start from so it runs along the
--- first line. At least as wide as one element, and as its label with room for the help mark. The
--- growth is the effective one: an attached container's auras grow the way its parent's do (L-6).
--- A container attached to another is the exception: that side faces the parent across the seam,
--- so its strip sits beside its first element instead (placeBeside, SS-3).
--- The strip's frame level, set wherever it is placed, since the first apply sets its anchor's level
--- after BuildHandle ran: HANDLE_LEVEL above its anchor. A container attached to another also clears
--- that one's placeholders (L-4), which its strip can still meet where the two blocks sit side by
--- side; every placeholder, inner frames included, stacks under that container's own strip,
--- HANDLE_LEVEL above its anchor.
--- Levels order frames within one strata only: a target in a higher strata still draws on top.
--- Every level is read through levelOf (feedback E).
local function handleLevel(container, cfg)
    local level = levelOf(container.anchor, cfg) + HANDLE_LEVEL
    local at = cfg.attach
    local target = at and at.mode == "container" and targetContainer(container, at)
    if target then
        level = math.max(level, levelOf(target.anchor, target:Cfg()) + HANDLE_LEVEL + 1)
    end
    return level
end

--- A container that follows another's flow stacks against it across the seam, so the side away
--- from its growth faces the parent's last aura: its strip goes beside its first element instead
--- (SS-3). One that follows nothing keeps the strip above or below.
local function besideSeam(cfg)
    return Anchors.FlowRoot(cfg) ~= nil
end

--- How tall the block a follower of `target` hangs from is, in `target`'s units: its preview extent
--- in test mode (Preview.Extent records it), otherwise one element, its anchor.
local function hangHeight(target, cfg)
    local _, h = NS.Style.ElementSize(cfg)
    local extent = target.previewExtent
    if Anchors.HangMode(target) == "preview" and extent and extent.height then return extent.height end
    return h
end

--- The room, in screen units before the Master scale, that a container attached to `target` leaves
--- for `target`'s own strip (EO-2): only while that strip shows, and only when it sits beside
--- `target`'s first element (a follower's, SS-3), where it runs down along the block the follower
--- hangs from; a root's strip sits on the far side, away from its followers. Enough that the
--- follower's strip, level with its own edge, starts one strip gap past the end of `target`'s. 0 when
--- the block is already that tall.
--- A shown name label beside that element counts too (NL-3): the strip moves on past it, so the room
--- is for both.
stripRoom = function(target)
    local n = ((DRAG and target.stripShown) and 1 or 0) + (target.labelShown and 1 or 0)
    if n == 0 then return 0 end
    local cfg = target.Cfg and target:Cfg()
    if not (cfg and besideSeam(cfg)) then return 0 end
    return math.max(0, n * (STRIP_H + STRIP_GAP) - hangHeight(target, cfg)) * ownScale(cfg)
end

--- Where the strip sits, and the name label with it (NL-2): on the side the auras do not grow into,
--- its edge lined up with the edge they start from; beside the first element for a container that
--- follows another (SS-3), level with the edge that faces the parent.
--- @return string point, string relativePoint, number x, number y, string growH, string growV, boolean beside
function Anchors.StripPoints(cfg)
    local growH, growV = NS.Container.Growth(Anchors.EffectiveLayout(cfg) or {})
    if besideSeam(cfg) then
        local v = (growV == "down") and "TOP" or "BOTTOM"
        local right = (growH ~= "left")
        return v .. (right and "RIGHT" or "LEFT"), v .. (right and "LEFT" or "RIGHT"),
            right and -STRIP_GAP or STRIP_GAP, 0, growH, growV, true
    end
    local toward = NS.Container.AnchorPoint(growH, growV)       -- the corner the auras start from
    local away = NS.Container.AnchorPoint(growH, (growV == "down") and "up" or "down")
    return away, toward, 0, (growV == "down") and STRIP_GAP or -STRIP_GAP, growH, growV, false
end

--- How far the strip moves to clear a shown name label (D6, NL-3): the label's height and the gap,
--- out on the far side of the anchor, or on along the growth when it sits beside the first element.
local function labelPush(container, growV, beside)
    if not container.labelShown then return 0 end
    local out = (growV == "down") ~= beside
    return out and (STRIP_H + STRIP_GAP) or -(STRIP_H + STRIP_GAP)
end

local LABEL_JUSTIFY = { LEFT = true, CENTER = true, RIGHT = true }

--- The name label's justify in effect (B9 LJ-1, E7): the player's pick, or with none (AUTO, nil or
--- anything unknown) the style's own. Bars and Text center it. Icons justify it toward the element it
--- names: LEFT, RIGHT when the auras grow left, mirrored for a label beside a follower's first
--- element (SS-3), which sits on the far side of it. The Label tab's Justify row shows this.
--- @return string "LEFT"|"CENTER"|"RIGHT"
function Anchors.LabelJustify(cfg)
    if not cfg then return "CENTER" end
    local pick = cfg.label and cfg.label.justifyH
    if LABEL_JUSTIFY[pick] then return pick end
    if NS.Style.StyleKey(cfg) ~= "icons" then return "CENTER" end
    local growH = NS.Container.Growth(Anchors.EffectiveLayout(cfg) or {})
    return ((growH == "left") ~= besideSeam(cfg)) and "RIGHT" or "LEFT"
end

--- How far the label's text sits in from its host's edge, by justify: none when centered.
local LABEL_INSET = { LEFT = 4, CENTER = 0, RIGHT = -4 }

--- Place a container's name label on the strip's spot, nudged by its X/Y (NL-2): one element wide and
--- one strip tall, its text on one line, justified per Anchors.LabelJustify. Layout work, so run
--- from Container:Apply (kept out of lockdown) and once on a first show (Container:ApplyLabelShown).
function Anchors.PlaceLabel(container, cfg)
    local host, fs = container.label, container.labelText
    if not (host and fs and cfg) then return end
    local lc = cfg.label or D.label
    host:SetFrameLevel(levelOf(container.anchor, cfg) + 1)
    local point, rel, x, y = Anchors.StripPoints(cfg)
    host:ClearAllPoints()
    host:SetPoint(point, container.anchor, rel, x + (tonumber(lc.x) or 0), y + (tonumber(lc.y) or 0))
    host:SetSize(NS.Style.ElementSize(cfg), STRIP_H)
    local side = Anchors.LabelJustify(cfg)
    fs:ClearAllPoints()
    fs:SetPoint(side, host, side, LABEL_INSET[side], 0)
    fs:SetJustifyH(side)
    fs:SetWordWrap(false)
    host.placed = true
end

--- The strip goes where Anchors.StripPoints says, moved past a shown name label (D6). Beside the
--- anchor (a container attached to another) it runs into the child's own rows and never back over
--- the parent, as wide as its label with room for the help mark, not the element: it sits beside it,
--- not along it.
--- @return number, boolean  how far the strip runs past the anchor (along the line, or out from its
---                          side, its gap included), and whether it sits beside the anchor rather
---                          than above or below
local function placeHandle(container, cfg)
    local handle = container.handle
    handle:SetFrameLevel(handleLevel(container, cfg))
    handle:ClearAllPoints()
    handle.placed = true
    local point, rel, x, y, _, growV, beside = Anchors.StripPoints(cfg)
    handle:SetPoint(point, container.anchor, rel, x, y + labelPush(container, growV, beside))
    if beside then return handle:ApplyWidth(0) + DRAG.GAP, true end
    local w = NS.Style.ElementSize(cfg)
    -- The widget measures its own label on a detached string of its own and floors the width at the
    -- element, which is the arithmetic this file used to carry (labelWidth + HANDLE_PAD + …).
    return handle:ApplyWidth(w) - w, false
end

--- Set the anchor's clamp insets only when they change. This runs on every visibility pass, and a
--- pass that moves nothing must cost nothing: no engine call, no allocation after the first set.
local function setClamp(container, l, r, t, b)
    local c = container.clampInsets
    if c and c[1] == l and c[2] == r and c[3] == t and c[4] == b then return end
    if not c then
        c = {}
        container.clampInsets = c
    end
    c[1], c[2], c[3], c[4] = l, r, t, b
    container.anchor:SetClampRectInsets(l, r, t, b)
end

--- A strip beside the anchor (SS-3) sits on the side its lines do not grow into, so the clamp reaches
--- out from that side only, by the strip's width and gap.
local function clampBeside(container, growH, reach)
    if growH == "left" then return setClamp(container, 0, reach, 0, 0) end
    setClamp(container, -reach, 0, 0, 0)
end

--- The anchor is clamped to the screen; while its handle shows, the clamp rect reaches over the strip
--- too, so the handle cannot be dragged off-screen. Out of combat only (Anchors.UpdateHandle). A
--- strip beside the anchor (SS-3) reaches out from that side only.
local function clampToHandle(container, cfg, overhang, beside)
    if not overhang then
        setClamp(container, 0, 0, 0, 0)
        return
    end
    local growH, growV = NS.Container.Growth(Anchors.EffectiveLayout(cfg) or {})
    if beside then return clampBeside(container, growH, overhang) end
    local reach = DRAG.HEIGHT + DRAG.GAP + math.abs(labelPush(container, growV, false))
    local left = (growH == "left") and -overhang or 0
    local right = (growH == "right") and overhang or 0
    local top = (growV == "down") and reach or 0
    local bottom = (growV == "up") and -reach or 0
    setClamp(container, left, right, top, bottom)
end

--- Show or hide a container's handle, with its current name, re-placed each time it is shown: the
--- name sets its width and the layout's growth sets its side. Placing the strip and clamping the
--- anchor are layout work beside an aura engine's parent, so neither runs under lockdown: the handle
--- keeps its last placement and only shows or hides, and the next visibility pass after combat
--- catches both up. The one exception is a handle never placed (first shown in combat): it has no
--- points and would draw nothing, so it is placed once, being our own unprotected strip, while the
--- anchor's clamp still waits for combat to end.
function Anchors.UpdateHandle(container, show)
    local handle = container.handle
    if not handle then return end
    local cfg = container:Cfg()
    show = (show and cfg) and true or false
    handle:SetLabel(handleText(cfg))
    container.stripShown = show   -- what a follower leaves room for (stripRoom)
    if not InCombatLockdown() then
        if show then
            clampToHandle(container, cfg, placeHandle(container, cfg))
        else
            clampToHandle(container, cfg, nil)
        end
    elseif show and not handle.placed then
        placeHandle(container, cfg)
    end
    handle:SetShown(show)
end
