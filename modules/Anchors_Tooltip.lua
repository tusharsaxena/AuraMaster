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
-- reads secret, docs/midnight-quirks.md) the tooltip goes beside the NEAREST CONTAINER UP THE STRIP'S
-- ATTACH CHAIN WHOSE ANCHOR READS (AD-92-AM review fix), or beside the named frame the chain ends on
-- when that one reads. The chain comes from the stored attach settings (configuration, never a point
-- read back off a secret frame); the first anchor that reads is the group and the element, through
-- the same PlaceBeside and opts.rect. A chain rooted on the screen always reads at its root, whose
-- anchor hangs from UIParent alone. The widget's own attached fallback is no help there: it reads the
-- same secret rect, and its relative point into the restricted tree is refused, which leaves the
-- tooltip with no anchor at all (libs/LibKa0s/WidgetsDragHandleTip.lua, dhPlaceAttached). So this hook
-- answers nil only when nothing on the chain reads (a chain ending on a named frame that is itself
-- secret), and only then does the tooltip go unshown. The cursor pin this file once used for an
-- unreadable strip (the owner's option B, 2026-10-03) is retired: the rule says never the cursor.
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

--- Whether `frame`'s whole rect reads plain.
local function reads(frame)
    return type(frame) == "table" and stripRect(frame) ~= nil
end

--- The live container whose strip `strip` is, or nil (a strip this addon did not build).
local function containerOf(strip)
    local CM = NS.ContainerManager
    for _, c in pairs(CM and CM.instances or {}) do
        if c.handle == strip then return c end
    end
    return nil
end

--- The frame the tooltip places by: the strip when its rect reads; else, walking the strip's
--- container's STORED attach chain (configuration, never a point read off a secret frame), the
--- anchor of the first container up it whose rect reads, or the named frame the chain ends on when
--- that one reads. Nil when nothing on the chain reads, or on a loop (the walk stops at 64 hops or at
--- a container already seen).
local function hostOf(strip)
    if reads(strip) then return strip end
    local c, seen = containerOf(strip), {}
    while c and not seen[c] do
        seen[c] = true
        local cfg = type(c.Cfg) == "function" and c:Cfg() or nil
        local at = cfg and cfg.attach
        if not at then return nil end
        if at.mode == "frame" then
            local A = NS.Anchors
            local f = A and A.ResolveFrame and A.ResolveFrame(at.frame)
            if reads(f) then return f end
            return nil
        end
        if at.mode ~= "container" then return nil end
        local CM = NS.ContainerManager
        c = CM and CM.instances and CM.instances[tonumber(at.container)]
        if c and reads(c.anchor) and not seen[c] then return c.anchor end
    end
    return nil
end

--- The strip's `tooltipPlace`: put `tip` beside the strip `frame` belongs to through the library's
--- PlaceBeside (the strip as element and group), or above it when neither side has room. A strip that
--- reads secret places by its nearest readable host up its attach chain (hostOf).
--- @return true|nil  true when placed; nil (the widget's attached fallback) when nothing on the
--- chain reads, the tooltip or screen does not read, or the Tooltip major is absent
function Tip.Place(tip, frame)
    if not (tip and frame) then return nil end
    local Lib = LibStub and LibStub("LibKa0s-Tooltip-1.0", true)
    if not (Lib and Lib.PlaceBeside) then return nil end
    local host = hostOf(Tip.StripOf(frame))
    if not host then return nil end
    if Lib.PlaceBeside(tip, host, host, OPTS) then return true end
    return nil
end
