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
-- being placed.
--
-- WHERE THE STRIP DOES NOT READ (a container attached under a parent holding auras: its whole tree
-- reads secret, docs/midnight-quirks.md), the tooltip is pinned instead beside the CURSOR where it
-- entered the strip (the owner's pick, option B, 2026-10-03): its TOPLEFT CURSOR_GAP right of the
-- cursor and CURSOR_RISE above it, or its TOPRIGHT CURSOR_GAP left of it near the screen's right
-- edge, fixed there for the hover rather than following the cursor. The widget calls the hook once,
-- on enter, so the spot is the one the cursor came in at. Only when the cursor, the tooltip or the
-- screen does not read either does it answer nil, and the tooltip follows the cursor.
--
-- LOAD-BEARING POSITION: before modules/Anchors.lua, which binds NS.AnchorsTooltip.Place at file load
-- as the strip's `tooltipPlace`.

local Tip = {}
NS.AnchorsTooltip = Tip

--- The room between the strip and the tooltip, in the tooltip's own units.
Tip.GAP = 4

--- Where the strip does not read: the room right (or left) of the cursor, and how far above it the
--- tooltip's top sits (about half a strip, so its top is near the strip's), in the tooltip's units.
Tip.CURSOR_GAP = 16
Tip.CURSOR_RISE = 10

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

--- The cursor in screen pixels, or nil when either coordinate does not read.
--- @return number|nil x, number|nil y
local function cursorAt()
    local x, y = GetCursorPosition()
    x, y = NS.Secrets.NumberOr(x, nil), NS.Secrets.NumberOr(y, nil)
    if not (x and y) then return nil end
    return x, y
end

--- Pin `tip` at `y` (tooltip units), its TOPLEFT at `rightX` unless a tooltip `width` wide would run
--- past `screenRight` from there; then its TOPRIGHT at `leftX`.
local function pin(tip, leftX, rightX, y, width, screenRight)
    tip:ClearAllPoints()
    if rightX + width > screenRight then
        tip:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", leftX, y)
    else
        tip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", rightX, y)
    end
end

--- The strip's `tooltipPlace`: put `tip` beside the strip `frame` belongs to, its TOPLEFT a GAP right
--- of the strip's TOPRIGHT, or, when that would carry it past the screen's right edge, its TOPRIGHT a
--- GAP left of the strip's TOPLEFT. Where the strip does not read, the same beside the cursor where
--- it entered (CURSOR_GAP, CURSOR_RISE).
--- @return true|nil  true when placed; nil (the cursor fallback) when a read was secret or missing
function Tip.Place(tip, frame)
    if not (tip and frame) then return nil end
    local scale, width, screenRight = tipFrame(tip)
    if not scale then return nil end
    local left, right, top = stripRect(Tip.StripOf(frame))
    if left then
        pin(tip, left / scale - Tip.GAP, right / scale + Tip.GAP, top / scale, width, screenRight)
        return true
    end
    local cx, cy = cursorAt()
    if not cx then return nil end
    cx, cy = cx / scale, cy / scale
    pin(tip, cx - Tip.CURSOR_GAP, cx + Tip.CURSOR_GAP, cy + Tip.CURSOR_RISE, width, screenRight)
    return true
end
