local _, NS = ...

-- modules/Anchors_Tooltip.lua — where the drag strip's tooltip sits: BESIDE the strip, to its right,
-- or to its left when the strip is too close to the right edge of the screen for the tooltip to fit
-- (issue #22, the owner's smoke feedback of 2026-10-02, kept by the owner's SR2 answer of
-- 2026-11-17). The strip and its help, close and settings marks share it.
--
-- PLACED BY THE LIBRARY (AD-92-AM, LibKa0s#92, standalone-windows *Tooltip placement*):
-- LibKa0s-Tooltip-1.0's PlaceBeside, the strip being both the hovered element and the group, so the
-- tooltip sits TIP_GAP (2) outside the strip's right edge, else its left, its top level with the
-- strip's, clamped on the screen; with room on neither side, the library's own fallback attaches it
-- centered above the strip (the chrome rule). The library's DragHandle default is PlaceAttached
-- (above the strip); this hook keeps the owner's beside-the-strip ruling through the library placer
-- instead of this file's own arithmetic.
--
-- The strip is LibKa0s-Widgets-1.0's, and this is its `tooltipPlace` hook: the widget owns
-- GameTooltip by UIParent at ANCHOR_NONE, draws and shows it, then calls Tip.Place(tip, frame) with
-- the frame hovered. Only `true` means placed; anything else, a raise included, sends the widget to
-- its own attached placement (WidgetsDragHandleTip minor 1: PlaceAttached above the strip, else a
-- relative point under pcall, never the cursor).
--
-- ANCHORED TO UIParent ALONE, never to the strip. Every anchor inherits
-- DisableUntrustedLayoutScriptsTemplate (modules/Container.lua), and the client refuses to anchor
-- GameTooltip into that restricted tree. The library's placers write one absolute point on
-- UIParent's BOTTOMLEFT, so that holds. The strip's rect is handed to the library through
-- `opts.rect`, read through NS.Secrets (a strip under an attached anchor can answer it secret) and
-- converted to screen units by the strip's own effective scale (a container carries its own scale).
--
-- WHERE THE STRIP DOES NOT READ (a container attached under a parent holding auras: its whole tree
-- reads secret, docs/midnight-quirks.md) this hook places nothing and answers nil, so the widget's
-- attached fallback runs. The cursor pin this file once used there (the owner's option B,
-- 2026-10-03) is retired: the rule says never the cursor.
--
-- LOAD-BEARING POSITION: before modules/Anchors.lua, which binds NS.AnchorsTooltip.Place at file load
-- as the strip's `tooltipPlace`.

local Tip = {}
NS.AnchorsTooltip = Tip

--- `frame:method()` when the frame has it and it answers a plain, readable number; else nil.
local function readNumber(frame, method)
    local fn = frame and frame[method]
    if type(fn) ~= "function" then return nil end
    return NS.Secrets.NumberOr(fn(frame), nil)
end

--- The strip a hovered frame belongs to: the frame itself, or the strip whose help, close or settings
--- mark it is (the marks are the strip's children, on its `help`, `close` and `settings` fields).
--- @return table
function Tip.StripOf(frame)
    local parent = type(frame.GetParent) == "function" and frame:GetParent()
    if type(parent) == "table" and parent ~= frame
        and (parent.help == frame or parent.close == frame or parent.settings == frame) then
        return parent
    end
    return frame
end

--- The strip's left, bottom, right and top in screen units, or nothing when any of them, or its
--- scale, does not read: the library's `opts.rect`, which counts a missing edge as unreadable.
--- @return number|nil left, number|nil bottom, number|nil right, number|nil top
local function stripRect(strip)
    local scale = readNumber(strip, "GetEffectiveScale")
    local left, bottom = readNumber(strip, "GetLeft"), readNumber(strip, "GetBottom")
    local right, top = readNumber(strip, "GetRight"), readNumber(strip, "GetTop")
    if not (scale and left and bottom and right and top) then return nil end
    return left * scale, bottom * scale, right * scale, top * scale
end

local OPTS = { rect = stripRect, comparisons = false }

--- The strip's `tooltipPlace`: put `tip` beside the strip `frame` belongs to through the library's
--- PlaceBeside (the strip as element and group), or above it when neither side has room.
--- @return true|nil  true when placed; nil (the widget's attached fallback) when a read was secret
--- or missing, or the Tooltip major is absent
function Tip.Place(tip, frame)
    if not (tip and frame) then return nil end
    local Lib = LibStub and LibStub("LibKa0s-Tooltip-1.0", true)
    if not (Lib and Lib.PlaceBeside) then return nil end
    local strip = Tip.StripOf(frame)
    if Lib.PlaceBeside(tip, strip, strip, OPTS) then return true end
    return nil
end
