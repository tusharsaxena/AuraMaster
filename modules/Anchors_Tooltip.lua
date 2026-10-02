local _, NS = ...

-- modules/Anchors_Tooltip.lua — where the drag strip's tooltip sits: beside the strip, to its right,
-- or to its left when the strip is too close to the right edge of the screen for the tooltip to fit
-- (issue #22, the owner's smoke feedback of 2026-10-02). The strip and its close mark share it.
--
-- The strip is LibKa0s-Widgets-1.0's (WidgetsDragHandle minor 4), and this is its `tooltipPlace`
-- hook: the widget owns GameTooltip by UIParent at ANCHOR_NONE, draws and shows it, then calls
-- Tip.Place(tip, frame) with the frame hovered. Only `true` means placed; anything else, a raise
-- included, sends the widget back to the cursor owner (`tooltipOwner = "cursor"` in BuildHandle).
--
-- ANCHORED TO UIParent ALONE, never to the strip. Every anchor inherits
-- DisableUntrustedLayoutScriptsTemplate (modules/Container.lua), and the client refuses to anchor
-- GameTooltip into that restricted tree. So the strip's rect is READ, through NS.Secrets (a strip
-- under an attached anchor can answer it secret), converted to screen pixels by the strip's own
-- effective scale (a container carries its own scale), and the tooltip is pinned to UIParent's
-- BOTTOMLEFT at that spot in the tooltip's own units: a SetPoint offset is in the scale of the region
-- being placed. Any read that is secret or missing answers nil, and the tooltip follows the cursor.
--
-- LOAD-BEARING POSITION: before modules/Anchors.lua, which binds NS.AnchorsTooltip.Place at file load
-- as the strip's `tooltipPlace`.

local Tip = {}
NS.AnchorsTooltip = Tip

--- The room between the strip and the tooltip, in the tooltip's own units.
Tip.GAP = 4

--- `frame:method()` when the frame has it and it answers a plain, readable number; else nil.
local function readNumber(frame, method)
    local fn = frame and frame[method]
    if type(fn) ~= "function" then return nil end
    return NS.Secrets.NumberOr(fn(frame), nil)
end

--- The strip a hovered frame belongs to: the frame itself, or the strip whose help or close mark it
--- is (the marks are the strip's children, on its `help` and `close` fields).
--- @return table
function Tip.StripOf(frame)
    local parent = type(frame.GetParent) == "function" and frame:GetParent()
    if type(parent) == "table" and parent ~= frame and (parent.help == frame or parent.close == frame) then
        return parent
    end
    return frame
end

--- The strip's left, right and top edges in screen pixels, or nil when any of them, or its scale,
--- does not read.
--- @return number|nil left, number|nil right, number|nil top
local function stripRect(strip)
    local scale = readNumber(strip, "GetEffectiveScale")
    local left, right, top = readNumber(strip, "GetLeft"), readNumber(strip, "GetRight"), readNumber(strip, "GetTop")
    if not (scale and left and right and top) then return nil end
    return left * scale, right * scale, top * scale
end

--- What the placement needs of the tooltip and the screen, in the tooltip's units: its scale, its
--- width and the screen's right edge. Nil when any of them does not read.
--- @return number|nil scale, number|nil width, number|nil screenRight
local function tipFrame(tip)
    local scale, width = readNumber(tip, "GetEffectiveScale"), readNumber(tip, "GetWidth")
    local uiRight, uiScale = readNumber(UIParent, "GetRight"), readNumber(UIParent, "GetEffectiveScale")
    if not (scale and scale > 0 and width and uiRight and uiScale) then return nil end
    return scale, width, uiRight * uiScale / scale
end

--- The strip's `tooltipPlace`: put `tip` beside the strip `frame` belongs to, its TOPLEFT a GAP right
--- of the strip's TOPRIGHT, or, when that would carry it past the screen's right edge, its TOPRIGHT a
--- GAP left of the strip's TOPLEFT.
--- @return true|nil  true when placed; nil (the cursor fallback) when a read was secret or missing
function Tip.Place(tip, frame)
    if not (tip and frame) then return nil end
    local left, right, top = stripRect(Tip.StripOf(frame))
    if not left then return nil end
    local scale, width, screenRight = tipFrame(tip)
    if not scale then return nil end
    local x, y = right / scale + Tip.GAP, top / scale
    tip:ClearAllPoints()
    if x + width > screenRight then
        tip:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", left / scale - Tip.GAP, y)
    else
        tip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    end
    return true
end
