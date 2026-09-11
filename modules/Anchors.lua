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
--              that anchors to an aura container (whose layout scripts are forbidden to addons);
--   frame      any named frame — a unit frame, another add-on's bar — re-resolved when the add-on
--              that creates it loads, and again when combat ends (Anchors.ResolvePending).
-- A chain that would loop back on itself, a target that does not exist, or a frame that is forbidden
-- falls back to the screen position rather than to nowhere, and says so in the [Anchor] debug trace.

NS.Anchors = NS.Anchors or {}
local Anchors = NS.Anchors
local D = NS.CONTAINER_TEMPLATE

-- Frame-mode containers whose frame did not exist yet, by container id.
local pending = {}

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

--- The frame container `container` attaches to and the mode that names it, or nil when its setting
--- names nothing usable: a missing or looping container, or a frame that is absent or forbidden. A
--- named frame that simply does not exist YET is remembered, to be retried when an add-on loads.
local function targetFor(container, at)
    if at.mode == "container" then
        local targetId = tonumber(at.container)
        local target = NS.ContainerManager and NS.ContainerManager.instances[targetId]
        if target and targetId ~= container.id and not Anchors.WouldCycle(container.id, targetId) then
            return target.engine or target.anchor, "container"
        end
    elseif at.mode == "frame" then
        local f = Anchors.ResolveFrame(at.frame)
        if f then return f, "frame" end
        if at.frame and at.frame ~= "" then pending[container.id] = true end
    end
    return nil
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
    local target, mode = targetFor(container, at)
    if target then
        local ok = pcall(anchor.SetPoint, anchor, at.point or D.attach.point, target,
            at.relativePoint or D.attach.relativePoint, tonumber(at.x) or 0, tonumber(at.y) or 0)
        if ok then return mode end
        anchor:ClearAllPoints()
    end
    if at.mode and at.mode ~= "screen" and NS.Debug then
        NS.Debug("Anchor", "container %s: %s target unavailable, screen fallback", container.id, at.mode)
    end
    toScreen(anchor, cfg)
    return "screen"
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
    if not point then return end
    NS.SetByPath("container.position",
        { point = point, relativePoint = relPoint or point, x = round(x), y = round(y) }, container.id)
end

-- ---------------------------------------------------------------------------
-- The drag handle
-- ---------------------------------------------------------------------------

-- A labeled strip OUTSIDE the anchor, on the side the auras do not grow into: a dark WHITE8X8
-- backdrop with a 1px gold edge, a gold label, and the media catalog's help mark inside its far
-- end. Outside, because
-- the anchor is exactly one element in size and the first element sits on it: a handle covering the
-- anchor covered the first bar or icon. Nothing moves to make room for it — the anchor, the engine
-- (which may never be re-anchored once it holds groups) and the preview stay where they are.
local HANDLE_H     = 18   -- strip height
local HANDLE_GAP   = 2    -- gap between the strip and the anchor
local HANDLE_PAD   = 24   -- horizontal padding around the label
local HANDLE_HELP  = 14   -- the help mark's edge, inside the strip's far end
local BACKDROP_TEX = [[Interface\Buttons\WHITE8X8]]
-- The LAST rung of the help mark's ladder: the catalog's `help` icon through NS.Icon first, and this
-- Blizzard texture only when the media library is absent or stops carrying that name.
local HELP_TEXTURE = [[Interface\FriendsFrame\InformationIcon]]

--- Right-click: the settings, on this container.
local function openSettings(container)
    if NS.State then NS.State.SetActiveContainer(container.id) end
    if NS.OpenOptionsPanel then NS.OpenOptionsPanel() end
end

--- One tooltip for the strip and its help mark: the container's name, then how to use the handle.
local function showTooltip(owner, container)
    if not GameTooltip then return end
    local cfg = container:Cfg()
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(cfg and cfg.name or NS.L["Container"], 1, 0.82, 0)
    GameTooltip:AddLine(NS.L["Drag to move. Right-click for settings."], 1, 1, 1, true)
    if cfg and cfg.attach and cfg.attach.mode ~= "screen" then
        GameTooltip:AddLine(NS.L["Attached — set its offsets on the Layout page."], 1, 0.82, 0, true)
    end
    GameTooltip:Show()
end

local function hideTooltip() if GameTooltip then GameTooltip:Hide() end end

--- The strip's two drag scripts, built once per handle and set on the strip AND its help mark, so a
--- drag that starts on the mark moves the container too instead of landing in a dead zone.
local function dragScripts(container)
    local anchor = container.anchor
    local function start()
        local cfg = container:Cfg()
        -- Only a screen-attached container moves by dragging; an attached one follows its target, and
        -- its offsets are set on the Layout page. Never mid-combat: the anchor parents an aura engine.
        if cfg and cfg.attach and cfg.attach.mode == "screen" and not InCombatLockdown() then
            anchor:StartMoving()
            container.__dragging = true
        end
    end
    local function stop()
        if not container.__dragging then return end
        container.__dragging = nil
        anchor:StopMovingOrSizing()
        Anchors.SavePosition(container)
    end
    return start, stop
end

--- The help mark: a fixed 14px icon rather than a line of hint text, so a one-element container's
--- handle is not forced wider by prose. It carries the tooltip, passes a right-click through, and
--- takes a left-drag with the strip's own drag scripts.
local function buildHelp(handle, container)
    local help = CreateFrame("Button", nil, handle)
    help:SetSize(HANDLE_HELP, HANDLE_HELP)
    help:SetPoint("RIGHT", handle, "RIGHT", -4, 0)
    help:RegisterForClicks("RightButtonUp")
    help:RegisterForDrag("LeftButton")
    help:SetScript("OnDragStart", handle:GetScript("OnDragStart"))
    help:SetScript("OnDragStop", handle:GetScript("OnDragStop"))
    local icon = help:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints(help)
    icon:SetTexture(NS.Icon and NS.Icon("help") or HELP_TEXTURE)
    help.icon = icon
    help:SetScript("OnEnter", function(self) showTooltip(self, container) end)
    help:SetScript("OnLeave", hideTooltip)
    help:SetScript("OnClick", function() openSettings(container) end)
    return help
end

--- Build the handle a player drags a container by. Shown only while unlocked; it sits outside the
--- anchor (Anchors.UpdateHandle places it), so no element is covered and nothing moves to make room.
--- The one exception is the screen edge: while the handle shows, the anchor's clamp rect takes the
--- strip in (clampToHandle), so a container flush with the edge on the handle's side is pushed in by
--- the strip while unlocked and returns when locked. Its stored position does not change.
function Anchors.BuildHandle(container)
    local anchor = container.anchor
    local handle = CreateFrame("Button", nil, anchor, "BackdropTemplate")
    handle:SetHeight(HANDLE_H)
    handle:SetFrameLevel((anchor:GetFrameLevel() or 0) + 50)
    handle:SetBackdrop({ bgFile = BACKDROP_TEX, edgeFile = BACKDROP_TEX, edgeSize = 1 })
    handle:SetBackdropColor(0, 0, 0, 0.75)
    handle:SetBackdropBorderColor(1, 0.82, 0, 0.6)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:RegisterForClicks("RightButtonUp")
    handle:Hide()

    local label = handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER")
    label:SetTextColor(1, 0.82, 0)
    handle.label = label

    local dragStart, dragStop = dragScripts(container)
    handle:SetScript("OnDragStart", dragStart)
    handle:SetScript("OnDragStop", dragStop)
    handle.help = buildHelp(handle, container)
    handle:SetScript("OnClick", function(_, button)
        if button == "RightButton" then openSettings(container) end
    end)
    handle:SetScript("OnEnter", function(self) showTooltip(self, container) end)
    handle:SetScript("OnLeave", hideTooltip)
    return handle
end

--- Put the strip on the side the auras do not grow into: above the anchor when they grow down,
--- below when they grow up, its edge lined up with the edge they start from so it runs along the
--- first line. At least as wide as one element, and as its label with room for the help mark.
--- @return number  how far the strip runs past the anchor along the line
local function placeHandle(container, cfg)
    local handle = container.handle
    local growH, growV = NS.Container.Growth(cfg.layout or {})
    local toward = NS.Container.AnchorPoint(growH, growV)       -- the corner the auras start from
    local away = NS.Container.AnchorPoint(growH, (growV == "down") and "up" or "down")
    local w = NS.Style.ElementSize(cfg)
    local width = math.max((tonumber(handle.label:GetStringWidth()) or 0) + HANDLE_PAD + HANDLE_HELP * 2, w)
    handle:ClearAllPoints()
    handle:SetPoint(away, container.anchor, toward, 0, (growV == "down") and HANDLE_GAP or -HANDLE_GAP)
    handle:SetWidth(width)
    handle.placed = true
    return width - w
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

--- The anchor is clamped to the screen; while its handle shows, the clamp rect reaches over the strip
--- too, so the handle cannot be dragged off-screen. Out of combat only (Anchors.UpdateHandle).
local function clampToHandle(container, cfg, overhang)
    if not overhang then
        setClamp(container, 0, 0, 0, 0)
        return
    end
    local growH, growV = NS.Container.Growth(cfg.layout or {})
    local reach = HANDLE_H + HANDLE_GAP
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
    handle.label:SetText(cfg and cfg.name or "")
    if not InCombatLockdown() then
        clampToHandle(container, cfg, show and placeHandle(container, cfg) or nil)
    elseif show and not handle.placed then
        placeHandle(container, cfg)
    end
    handle:SetShown(show)
end
