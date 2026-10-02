local _, NS = ...

-- modules/Anchors_SnapRect.lua — the rects drag to attach (issue #22) measures and draws on, each read
-- off the frames through the secrets guard into UIParent units. Peeled off modules/Anchors_Snap.lua,
-- which binds it at file load and publishes its readers as Snap.TargetRect, Snap.Footprint and
-- Snap.ParentRect, so that file stays at the 1000-line mark it is held to.
--
-- THREE RECTS. A container's BLOCK (Snap.TargetRect): the frame a follower hangs from in its hang mode
-- (Anchors.HangFrame), falling back to its anchor's one element where that reads secret. Its FOOTPRINT
-- (the addendum's A10, over A8; Snap.Footprint): its drag-handle strip while that shows and reads,
-- else its block with its name label taken in while that shows and reads. The dragged container is
-- measured on its own footprint, its block there being its one-element anchor. A PARENT's rect, the
-- target a drop would join or the parent a hold returns to (A11; Snap.ParentRect): its footprint, and
-- where that is its strip, each edge on a side the parent grows toward (its flow growth: the bottom
-- growing down, the top growing up, the right growing right, the left growing left) taken out to its
-- block's far edge on that side, when the block reads. A child joined on a growth side lands past
-- the block, so its dots and its side pick are measured there; on the before side the strip stands,
-- since a child joined there is pushed past the strip. Every read goes through readRect.
--
-- LOAD-BEARING POSITION: after modules/Anchors_Attach.lua, whose flow growth it binds at file load;
-- before modules/Anchors_Snap.lua, which binds NS.AnchorsSnapRect at file load. Anchors.HangFrame
-- (modules/Anchors.lua) and NS.Secrets are read at call time.

local SR = {}
NS.AnchorsSnapRect = SR

local flowGrowth = NS.AnchorsAttach.FlowGrowth

--- `v` when it is a plain number, else nil (secret, or not a number).
--- @return number|nil
local function plain(v) return NS.Secrets.NumberOr(v, nil) end
SR.Plain = plain

--- `frame`'s rect in UIParent units, written into `into` (a new table when nil), or nil when any of
--- its four edges or its effective scale does not read as a plain number: secret (an engine holding
--- auras, or a frame hung from one), or nothing yet (a frame with no points answers nil). A frame's
--- edges are in its own effective scale, so each is taken to UIParent's by the ratio of the two.
--- `into` is written only on success.
--- @return table|nil
local function readRect(frame, into)
    if not frame then return nil end
    local l, b, r, t = plain(frame:GetLeft()), plain(frame:GetBottom()), plain(frame:GetRight()), plain(frame:GetTop())
    local scale, ui = plain(frame:GetEffectiveScale()), plain(UIParent:GetEffectiveScale())
    if not (l and b and r and t and scale and ui) or ui <= 0 then return nil end
    local k = scale / ui
    into = into or {}
    into.left, into.bottom, into.right, into.top = l * k, b * k, r * k, t * k
    return into
end

--- The rect live container `target` would be snapped onto, in UIParent units, written into `into`
--- (a new table when nil): the frame a follower hangs from in its hang mode (Anchors.HangFrame:
--- preview extent, anchor in the slot mode, else engine). When that does not read plainly (an
--- engine holding auras reads secret), its anchor's rect: one element, where its first aura sits,
--- so the snap still finds the container's start. Nil when the anchor does not read either.
--- @return table|nil
function SR.TargetRect(target, into)
    local frame = NS.Anchors.HangFrame(target)
    local rect = readRect(frame, into)
    if not rect and frame ~= target.anchor then rect = readRect(target.anchor, into) end
    return rect
end

local function anchorRect(c, into) return readRect(c.anchor, into) end
local function hangRect(c, into) return readRect(NS.Anchors.HangFrame(c), into) end

local labelRect, blockRect = {}, {} -- scratch: a name label's rect, a parent's block rect

--- Live container `container`'s strip rect into `into` while the strip is visible and reads, else nil.
--- @return table|nil
local function stripRect(container, into)
    local strip = container.handle
    return strip and strip:IsVisible() and readRect(strip, into) or nil
end

--- Block rect `block(container, into)` (nil passes through) grown to take in `container`'s name label
--- while that is visible and reads (A8).
--- @return table|nil
local function blockFootprint(container, into, block)
    local rect = block(container, into)
    local label = container.label
    if rect and label and label:IsVisible() and readRect(label, labelRect) then
        rect.left, rect.right = math.min(rect.left, labelRect.left), math.max(rect.right, labelRect.right)
        rect.bottom, rect.top = math.min(rect.bottom, labelRect.bottom), math.max(rect.top, labelRect.top)
    end
    return rect
end

--- Live container `container`'s footprint (A10): its strip, else its block (`block`) with its label.
--- @return table|nil
local function footprint(container, into, block)
    return stripRect(container, into) or blockFootprint(container, into, block)
end

--- Strip rect `rect`'s edges on the sides growth `growH`, `growV` grows toward, each taken out to block
--- rect `b`'s far edge on that side (A11): the edge only, the strip's other edges kept.
local function reach(rect, b, growH, growV)
    if growV == "up" then rect.top = math.max(rect.top, b.top) else rect.bottom = math.min(rect.bottom, b.bottom) end
    if growH == "left" then rect.left = math.min(rect.left, b.left) else rect.right = math.max(rect.right, b.right) end
end

--- The growth live container `container` flows by (Anchors_Attach's FlowGrowth), or the default
--- growth's when it has no settings.
--- @return string growH, string growV
local function growthOf(container)
    local cfg = container:Cfg()
    if cfg then return flowGrowth(cfg) end
    return NS.Container.Growth({})
end

--- Parent `container`'s rect (A11) into `into`, its block read by `block`: its strip with its growth
--- sides out to that block's far edges when the strip shows and reads, else its footprint (the block
--- and its label, which take in the block whole). Second, whether the block read (the rect reaches
--- it): false for a strip alone, whose block does not read.
--- @return table|nil rect, boolean reached
local function parentRect(container, into, block, growH, growV)
    local rect = stripRect(container, into)
    if not rect then
        rect = blockFootprint(container, into, block)
        return rect, rect ~= nil
    end
    local b = block(container, blockRect)
    if b then
        if not growH then growH, growV = growthOf(container) end
        reach(rect, b, growH, growV)
    end
    return rect, b ~= nil
end

--- What the snap reads of live container `target`, in UIParent units, into `into`: its strip, or its
--- SR.TargetRect (the hang rect, or the one-element fallback) with its name label.
--- @return table|nil
function SR.Footprint(target, into)
    return footprint(target, into, SR.TargetRect)
end

--- Live container `target` as a parent a drop would join (A11), into `into`: SR.Footprint, with a
--- strip's growth-side edges out to the far edges of SR.TargetRect's block (its fallback included).
--- `growH`, `growV`: the growth it flows by, read off its settings when nil.
--- @return table|nil
function SR.ParentRect(target, into, growH, growV)
    return parentRect(target, into, SR.TargetRect, growH, growV)
end

--- Live container `parent` as the parent a hold returns to (A4, A11), into `into`: as SR.ParentRect,
--- but its block only the frame a follower hangs from, never the one-element fallback. Second,
--- whether that block read: false when the rect is its strip alone (an engine holding auras reads
--- secret), which SR.ParentRect measures out to the fallback instead, so the two then differ.
--- @return table|nil rect, boolean reached
function SR.HungParent(parent, into)
    return parentRect(parent, into, hangRect)
end

--- The dragged container's own: its strip, or its one-element anchor (the frame whose point a drop
--- joins, hung from UIParent while dragged) with its name label.
--- @return table|nil
function SR.Own(container, into)
    return footprint(container, into, anchorRect)
end
