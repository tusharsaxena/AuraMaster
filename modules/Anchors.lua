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
--              that creates it loads (Anchors.ResolvePending).
-- A chain that would loop back on itself, a target that does not exist, or a frame that is forbidden
-- falls back to the screen position rather than to nowhere.

NS.Anchors = NS.Anchors or {}
local Anchors = NS.Anchors

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
    anchor:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or pos.point or "CENTER",
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
        local ok = pcall(anchor.SetPoint, anchor, at.point or "TOPLEFT", target,
            at.relativePoint or "BOTTOMLEFT", tonumber(at.x) or 0, tonumber(at.y) or 0)
        if ok then return mode end
        anchor:ClearAllPoints()
    end
    toScreen(anchor, cfg)
    return "screen"
end

--- Re-place every container whose frame target did not exist when it was placed. Called whenever an
--- add-on loads, since that is when a new named frame can appear.
function Anchors.ResolvePending()
    if InCombatLockdown() then return end
    local CM = NS.ContainerManager
    if not CM then return end
    for id in pairs(pending) do
        local inst = CM.instances[id]
        if inst then Anchors.Place(inst) else pending[id] = nil end
    end
end

--- Which containers are still waiting on their frame (a test seam and a `/am list` aid).
function Anchors.Pending()
    local out = {}
    for id in pairs(pending) do out[#out + 1] = id end
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

--- Build the handle a player drags a container by. Shown only while unlocked; it covers the anchor,
--- above the first element, so what is lined up while unlocked is exactly where it stays.
function Anchors.BuildHandle(container)
    local anchor = container.anchor
    local handle = CreateFrame("Button", nil, anchor)
    handle:SetAllPoints(anchor)
    handle:SetFrameLevel((anchor:GetFrameLevel() or 0) + 50)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:RegisterForClicks("RightButtonUp")
    handle:Hide()

    local bg = handle:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.10, 0.45, 0.80, 0.55)
    handle.bg = bg

    local label = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER")
    handle.label = label

    handle:SetScript("OnDragStart", function()
        local cfg = container:Cfg()
        -- Only a screen-attached container moves by dragging; an attached one follows its target, and
        -- its offsets are set on the Layout page. Never mid-combat: the anchor parents an aura engine.
        if cfg and cfg.attach and cfg.attach.mode == "screen" and not InCombatLockdown() then
            anchor:StartMoving()
            container.__dragging = true
        end
    end)
    handle:SetScript("OnDragStop", function()
        if not container.__dragging then return end
        container.__dragging = nil
        anchor:StopMovingOrSizing()
        Anchors.SavePosition(container)
    end)
    handle:SetScript("OnClick", function(_, button)
        if button ~= "RightButton" then return end
        if NS.State then NS.State.SetActiveContainer(container.id) end
        if NS.OpenOptionsPanel then NS.OpenOptionsPanel() end
    end)
    handle:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        local cfg = container:Cfg()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(cfg and cfg.name or NS.L["Container"])
        GameTooltip:AddLine(NS.L["Drag to move. Right-click for settings."], 1, 1, 1)
        if cfg and cfg.attach and cfg.attach.mode ~= "screen" then
            GameTooltip:AddLine(NS.L["Attached — set its offsets on the Layout page."], 1, 0.82, 0)
        end
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return handle
end

--- Show or hide a container's handle, with its current name.
function Anchors.UpdateHandle(container, show)
    local handle = container.handle
    if not handle then return end
    local cfg = container:Cfg()
    handle.label:SetText(cfg and cfg.name or "")
    handle:SetShown(show and true or false)
end
