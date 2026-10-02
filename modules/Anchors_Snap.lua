local _, NS = ...

-- modules/Anchors_Snap.lua — drag to attach (issue #22): which container a dragged one would snap
-- onto if it were dropped now, and by which pair of points. Its own file, so modules/Anchors.lua
-- (which places the anchor and owns the drag handle) stays well under layout-§1's cap.
--
-- THE MODEL (the design's D2, D5, D7, as the owner-feedback addendum's A2 amends D1). A drop picks one
-- of the TWELVE OUTSIDE PAIRS (OUTSIDE below), absolute and independent of growth: each of the
-- target's four sides, its start, middle and end point, joined to the dragged container's point that
-- mirrors it across that side, so the child sits flush outside the target. Nine of them are the nine
-- classified sides (C.ATTACH_EDGES) under any growth; the other three lie on the target's before side
-- (the one its lines start from) and place as a FREE pair (batch 11 G5: X/Y alone, no seam, no
-- spread), moved out past the target's own strip and label there (Anchors_Attach.lua's beforeRoom,
-- DD-10). The answer names the token the pair classifies as under the TARGET's flow growth, the
-- growth the dragged container inherits the moment it attaches (Anchors.FlowRoot), or nil when free.
-- Which pair is SIDE FIRST, THEN ALIGN (the addendum's A7, Snap.Nearest): the nearest side within
-- C.SNAP_RADIUS by the gap between the two containers' facing edges, then the pair whose third of
-- that side the dragged container's center is over. Everything is measured on the two containers'
-- STRIPS (A10, below), or their block and name label where a strip is hidden or does not read (A8).
-- Everything is in UIParent units, so the radius feels the same under any scale.
--
-- WHAT IS READ, AND HOW. Two kinds of block rect: the dragged anchor's, which hangs from UIParent
-- while it is dragged and holds nothing secret, and each target's hang frame (Anchors.HangFrame),
-- which may be an ENGINE holding auras, whose geometry reads secret (core/Secrets.lua). Every number
-- goes through Secrets.NumberOr before any arithmetic; an engine that does not read plainly falls
-- back to the target's own anchor (exactly one element, its first), and a target whose anchor does
-- not read either is simply not a candidate this tick. A strip that shows and reads, read the same
-- guarded way, stands for its container; else the block, widened by a name label that shows and
-- reads (Snap.Footprint).
--
-- THE PURE CORE (Snap.PointAt, Snap.Nearest) touches no frame, so the headless harness tests the
-- choice directly; Snap.Candidates and Snap.Find are the frame side that feeds it.
--
-- THE DRAG LIFECYCLE (D3, D4, D9, D11, and the addendum's A4 detach leeway) is at the end of the
-- file: Snap.BeginDrag, the throttled driver and its highlight, the leeway's classify, Snap.Drop.
-- modules/Anchors.lua's beginDrag and the handle's OnDragStop call into it.
--
-- LOAD-BEARING POSITION: after modules/Anchors_Attach.lua, whose pair table and flow growth this
-- file binds from NS.AnchorsAttach at file load; after modules/Anchors.lua, which it extends
-- (Anchors.Snap) and whose HangFrame, WouldCycle, AutoPoints, Place and SavePosition it calls at
-- call time. settings/Layout.lua's NS.AttachByDrop (a drop's attach, and its GC-1 popup) loads after
-- it and is read at call time too, at the drop.

NS.Anchors = NS.Anchors or {}
local Anchors = NS.Anchors
local C = NS.Constants

-- From modules/Anchors_Attach.lua, at file load: EDGE_PAIRS[growH][growV][token] = { point,
-- relativePoint }, the very table a Place classifies by (read once, below, into PAIR_TOKEN), and the
-- growth a container flows by.
local AA = NS.AnchorsAttach
local EDGE_PAIRS, flowGrowth = AA.EDGE_PAIRS, AA.FlowGrowth

local Snap = {}
Anchors.Snap = Snap

-- ---------------------------------------------------------------------------
-- The pure core
-- ---------------------------------------------------------------------------

-- FX[point], FY[point]: where on a rect's width and height each of the nine WoW points sits (0 at
-- the left or bottom edge, 1 at the right or top, 0.5 in the middle), built once so a tick parses
-- no string.
local FX, FY = {}, {}
for _, point in ipairs(C.POINTS) do
    FX[point] = (point:match("LEFT$") and 0) or (point:match("RIGHT$") and 1) or 0.5
    FY[point] = (point:match("^TOP") and 1) or (point:match("^BOTTOM") and 0) or 0.5
end

--- The coordinates of WoW point `point` on `rect` ({ left, bottom, right, top }, any one unit). A
--- point that is not one of the nine reads as CENTER.
--- @return number x, number y
function Snap.PointAt(rect, point)
    local fx, fy = FX[point] or 0.5, FY[point] or 0.5
    return rect.left + (rect.right - rect.left) * fx, rect.bottom + (rect.top - rect.bottom) * fy
end

-- The twelve outside pairs (A2), in tie order: { side, the target's relative point, the child's
-- point }, the child's point the target's mirrored across that side (bottom and top swap TOP and
-- BOTTOM, right and left swap LEFT and RIGHT), so a child joined by one sits flush outside the target.
local OUTSIDE = {
    { "bottom", "BOTTOMLEFT", "TOPLEFT" }, { "bottom", "BOTTOM", "TOP" }, { "bottom", "BOTTOMRIGHT", "TOPRIGHT" },
    { "top", "TOPLEFT", "BOTTOMLEFT" }, { "top", "TOP", "BOTTOM" }, { "top", "TOPRIGHT", "BOTTOMRIGHT" },
    { "right", "TOPRIGHT", "TOPLEFT" }, { "right", "RIGHT", "LEFT" }, { "right", "BOTTOMRIGHT", "BOTTOMLEFT" },
    { "left", "TOPLEFT", "TOPRIGHT" }, { "left", "LEFT", "RIGHT" }, { "left", "BOTTOMLEFT", "BOTTOMRIGHT" },
}

-- PAIR_TOKEN[growH][growV][point][relPoint] = the token that pair is under that growth, read off
-- EDGE_PAIRS once, so naming the answer's token builds no string. A pair with no row is free.
local PAIR_TOKEN = {}
for growH, byV in pairs(EDGE_PAIRS) do
    PAIR_TOKEN[growH] = {}
    for growV, sides in pairs(byV) do
        local back = {}
        for token, pair in pairs(sides) do
            back[pair[1]] = back[pair[1]] or {}
            back[pair[1]][pair[2]] = token
        end
        PAIR_TOKEN[growH][growV] = back
    end
end

--- The token pair `point`/`relPoint` classifies as under a growth, normalized as NS.Container.Growth
--- normalizes it ("right" unless "left", "down" unless "up", so a candidate built by hand can never
--- miss a row), or nil when it is none of the nine (free, G5).
--- @return string|nil
local function tokenFor(growH, growV, point, relPoint)
    local row = PAIR_TOKEN[(growH == "left") and "left" or "right"][(growV == "up") and "up" or "down"][point]
    return row and row[relPoint]
end

-- The four sides in OUTSIDE's order, and BY_SIDE[side] = that side's three rows of OUTSIDE, start,
-- middle and end, so an align third indexes its row with no search. ALONG_X: the sides whose edge
-- runs along x (their start is LEFT); the other two run along y, and their start is the TOP.
local SIDES, BY_SIDE = {}, {}
for _, row in ipairs(OUTSIDE) do
    if not BY_SIDE[row[1]] then
        SIDES[#SIDES + 1] = row[1]
        BY_SIDE[row[1]] = {}
    end
    local three = BY_SIDE[row[1]]
    three[#three + 1] = row
end
local ALONG_X = { bottom = true, top = true }

--- The gap between child rect `c`'s edge that faces side `side` of target rect `p` and that side
--- (A7): positive while the child is clear of it, negative by as much as it overlaps.
--- @return number
local function sideGap(side, c, p)
    if side == "bottom" then return p.bottom - c.top end
    if side == "top" then return c.bottom - p.top end
    if side == "right" then return c.left - p.right end
    return p.left - c.right
end

--- Which of side `side`'s three pairs child rect `c` aligns to on target rect `p` (A7): the child's
--- center along that side over the target's edge cut in thirds, the first third the start pair
--- (LEFT, or the TOP of a vertical side), the middle third the middle pair, the last the end pair.
--- A center exactly on a border takes the middle pair, and a target with no length along the side
--- answers its middle pair to a center over it, else the start or the end pair. Nil when the child's
--- span along the side does not overlap the target's widened by `radius` at either end (a touch is
--- no overlap: a child that only touches the widened span is past the side's corner).
--- @return table|nil
local function sideRow(side, c, p, radius)
    local lo, hi, cLo, cHi = p.bottom, p.top, c.bottom, c.top
    if ALONG_X[side] then lo, hi, cLo, cHi = p.left, p.right, c.left, c.right end
    if not (cHi > lo - radius and cLo < hi + radius) then return nil end
    local third, mid = (hi - lo) / 3, (cLo + cHi) / 2
    local k = 2
    if mid < lo + third then k = 1 elseif mid > hi - third then k = 3 end
    if not ALONG_X[side] then k = 4 - k end   -- along y the start is the high end, the top
    return BY_SIDE[side][k]
end

--- The pair a drop of child rect `childRect` would join one of `candidates` by: SIDE FIRST, THEN
--- ALIGN (the addendum's A7, which replaced A2's nearest pair of points: equal-width containers made
--- a side's three pairs exactly as near, and the tie kept the start pair, so a middle pair never won).
--- Each of `candidates` is { id, rect, growH, growV }, the target's rect (A10) and the growth its chain
--- flows by, all rects { left, bottom, right, top } in one unit (UIParent's, from Snap.Candidates).
--- For every candidate in the order given (Snap.Candidates gives id order) and each of its four sides
--- in OUTSIDE's order: 1. the side is eligible when the child's facing edge is within `radius` of it
--- (|sideGap|, inclusive) and its span along the side overlaps the target's widened by `radius`;
--- 2. its pair is the one the child's center aligns to (sideRow), with the child's point mirrored
--- (OUTSIDE). 3. Only a strictly smaller |gap| replaces the best so far, so a tie keeps the first
--- target and then the first side. Growth plays no part in the choice. The answer is { id, side,
--- point, relPoint, token, dist }: `side` the target's side, `token` the one of the nine the pair is
--- under the target's growth, nil for a free one (its before side), and `dist` the |gap|, which is
--- what A4's "strictly nearer" compares (beats). Nil with no eligible side. Allocates only the answer.
--- @return table|nil
function Snap.Nearest(childRect, candidates, radius)
    local bestGap, bestCand, bestRow
    for _, cand in ipairs(candidates) do
        for _, side in ipairs(SIDES) do
            local gap = math.abs(sideGap(side, childRect, cand.rect))
            if gap <= radius and (bestGap == nil or gap < bestGap) then
                local row = sideRow(side, childRect, cand.rect, radius)
                if row then bestGap, bestCand, bestRow = gap, cand, row end
            end
        end
    end
    if not bestRow then return nil end
    local point, relPoint = bestRow[3], bestRow[2]
    return {
        id = bestCand.id, side = bestRow[1], point = point, relPoint = relPoint,
        token = tokenFor(bestCand.growH, bestCand.growV, point, relPoint), dist = bestGap,
    }
end

-- ---------------------------------------------------------------------------
-- Reading rects
-- ---------------------------------------------------------------------------

local function plain(v) return NS.Secrets.NumberOr(v, nil) end

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
function Snap.TargetRect(target, into)
    local frame = Anchors.HangFrame(target)
    local rect = readRect(frame, into)
    if not rect and frame ~= target.anchor then rect = readRect(target.anchor, into) end
    return rect
end

-- THE RECT THE SNAP READS (the addendum's A10, over A8). Every rect the snap measures or draws on, a
-- target's and the dragged container's alike, is the container's drag-handle STRIP (`container.handle`)
-- while it shows and reads: the owner's third smoke round found the dots on the placeholder's corners,
-- and the strip is what the player grabs and aims at. The side, the align third, the dots, the line,
-- the box and the leeway all go by it. Where the strip is hidden or does not read (a strip under an
-- anchor that hangs from an engine holding auras reads secret), A8's footprint stands in: the block
-- rect with the name label (`container.label`) taken in while it shows and reads. Where a drop attaches
-- is not touched (the twelve pairs, Place's seam and its rooms past the strip and label), so the dots
-- mark the strips, not the exact join (docs/known-limitations.md). Every read goes through readRect.

local labelRect = {} -- scratch: a name label's rect

--- Live container `container`'s rect as the snap reads it, written into `into` (a new table when
--- nil): its strip's while that is visible and reads, else block rect `block(container, into)` (nil
--- passes through) grown to take in its name label while that is visible and reads.
--- @return table|nil
local function footprint(container, into, block)
    local strip = container.handle
    local rect = strip and strip:IsVisible() and readRect(strip, into)
    if rect then return rect end
    rect = block(container, into)
    local label = container.label
    if rect and label and label:IsVisible() and readRect(label, labelRect) then
        rect.left, rect.right = math.min(rect.left, labelRect.left), math.max(rect.right, labelRect.right)
        rect.bottom, rect.top = math.min(rect.bottom, labelRect.bottom), math.max(rect.top, labelRect.top)
    end
    return rect
end

--- What the snap reads of live container `target`, in UIParent units, into `into`: its strip, or
--- its Snap.TargetRect (the hang rect, or the one-element fallback) with its name label.
--- @return table|nil
function Snap.Footprint(target, into)
    return footprint(target, into, Snap.TargetRect)
end

local function anchorRect(c, into) return readRect(c.anchor, into) end
local function hangRect(c, into) return readRect(Anchors.HangFrame(c), into) end

--- The dragged container's own: its strip, or its one-element anchor (the frame whose point a drop
--- joins, hung from UIParent while dragged) with its name label.
--- @return table|nil
local function ownFootprint(container, into)
    return footprint(container, into, anchorRect)
end

-- ---------------------------------------------------------------------------
-- Eligible targets (D5)
-- ---------------------------------------------------------------------------

--- Whether live container `t` may take the dragged container `dragged`: not the dragged one itself,
--- enabled, its anchor shown (a hidden container gives the player nothing to aim at), and not
--- following `dragged`, directly or down a chain (Anchors.WouldCycle), since attaching onto a
--- follower would close a loop.
local function eligible(dragged, t)
    if t == dragged or t.id == dragged.id then return false end
    local cfg = t:Cfg()
    if not (cfg and cfg.enabled) then return false end
    if not (t.anchor and t.anchor:IsShown()) then return false end
    return not Anchors.WouldCycle(dragged.id, t.id)
end

-- Scratch the driver's ticks reuse (D3 runs Find every 0.03s while a drag is live): the sorted ids,
-- the answer list and the candidate tables it hands out, each candidate with its own rect table. A
-- pool entry is made only the first time its slot is reached, so an ineligible target (the dragged
-- container itself, always) costs no table on a tick.
local order, list, pool = {}, {}, {}

--- The eligible targets for `dragged`, in id order, each { id, rect, growH, growV }: its strip or
--- footprint in UIParent units (Snap.Footprint, A10) and the growth its chain flows by. A target whose rect does
--- not read is left out. The list and its entries are SCRATCH, reused by the next call: read them,
--- never keep them.
--- @return table
function Snap.Candidates(dragged)
    local instances = NS.ContainerManager.instances
    for i = #order, 1, -1 do order[i] = nil end
    for id in pairs(instances) do order[#order + 1] = id end
    table.sort(order)
    local n = 0
    for _, id in ipairs(order) do
        local t = instances[id]
        local cand = pool[n + 1]
        if not cand then
            cand = { rect = {} }
            pool[n + 1] = cand
        end
        if eligible(dragged, t) and Snap.Footprint(t, cand.rect) then
            n = n + 1
            list[n] = cand
            cand.id = id
            cand.growH, cand.growV = flowGrowth(t:Cfg())
        end
    end
    for i = #list, n + 1, -1 do list[i] = nil end
    return list
end

local childRect = {}

--- What dropping live container `dragged` now would snap it onto (Snap.Nearest's answer for its own
--- strip or footprint over Snap.Candidates, within C.SNAP_RADIUS), or nil: nothing in range, or its own
--- strip and anchor do not read plainly (it hangs from UIParent while dragged, so it should).
--- @return table|nil
function Snap.Find(dragged)
    if not ownFootprint(dragged, childRect) then return nil end
    return Snap.Nearest(childRect, Snap.Candidates(dragged), C.SNAP_RADIUS)
end

-- ---------------------------------------------------------------------------
-- Automatic folding (D7, the points)
-- ---------------------------------------------------------------------------

--- The `attach.childPoint` and `attach.relPoint` to store for container `cfg` dropped on container
--- `targetId` by the pair `point`/`relPoint`: both nil (Automatic) when the WHOLE pair is Automatic's
--- for that child on that target (Anchors.AutoPoints, G3), else both points absolute. So a drop on the
--- default side stores the same Automatic pair a fresh attach on the panel does, and keeps following
--- the parent's growth and justify as they change, while a drop on any other side keeps that side.
--- Never one half of each: a drop picks a whole side, and a pair half Automatic follows the growth with
--- one point only (ahead-start under right/down, TOPLEFT > TOPRIGHT, stored as nil > TOPRIGHT, would
--- resolve to TOPRIGHT > TOPRIGHT under Grow Left: the child on top of the parent's first element).
--- The panel's two dropdowns still set one point each. Automatic is read for the container AS IF
--- attached to `targetId` (a probe carrying its id, style, text and layout), since its stored attach
--- still names wherever it was before the drop; `cfg` is not touched.
--- @return string|nil childPoint, string|nil relPoint
function Snap.FoldPoints(cfg, targetId, point, relPoint)
    local probe = {
        id = cfg.id, style = cfg.style, text = cfg.text, layout = cfg.layout,
        attach = { mode = "container", container = targetId },
    }
    local autoPoint, autoRel = Anchors.AutoPoints(probe)
    if point == autoPoint and relPoint == autoRel then return nil, nil end
    return point, relPoint
end

-- ---------------------------------------------------------------------------
-- The drag lifecycle (D3, D4, D9, D11; "Starting a drag", "Holding the drag steady")
-- ---------------------------------------------------------------------------
-- A drag starts in modules/Anchors.lua's beginDrag (the widget's canDrag, asked immediately before
-- StartMoving), which gates it (screen or container-attached, never frame, never in combat) and
-- hands the container here: Snap.BeginDrag lifts an attached anchor onto UIParent, marks the
-- container `dragging` (Anchors.Place leaves a dragging anchor where the drag has it) and starts
-- the DRIVER, one plain frame whose OnUpdate runs only while a drag is live and does its work at
-- most every DRIVER_PERIOD: combat started means no mark, else classify (below) says what a release
-- now would do and the HIGHLIGHT follows its answer. The widget's OnDragStop ends it through Snap.Drop.
--
-- The highlight is ours and plain: a holder frame under UIParent in the TOOLTIP strata, and in it a
-- dot on each of the pair's two join points, the target's relative point and the dragged anchor's own
-- point (the owner-feedback addendum's A1, A3), a Line region between the two dots, and the BOX, the
-- fallback edge below. Every part is a child frame or a region of the holder, so one Show or Hide takes
-- them all; the dots and the line are never toggled on their own, and the box only as the mark picks
-- it. They are placed by numbers already in UIParent units, on the strips (Snap.Footprint and the
-- dragged container's own, A10), and anchored to UIParent (the line's two ends too), never to a target.
--
-- WHICH CONTAINER is said by its drag-handle STRIP (A5, as A6 amends it): the TARGET's strip (for a
-- hold or a detach, the current parent's) has its OWN edge repainted 2px in the mark's color, through
-- the painter that drew it (Style.DrawEdge, the same four textures, which live on the strip), and the
-- widget's gold (Anchors.STRIP_EDGE) painted back when the mark leaves that strip or hides (edgeStrip).
-- No frame of ours is anchored to a strip: A5 hung an overlay on it with SetAllPoints, and in game it
-- never showed, most likely because the strip hangs under the container's anchor, a tree the client
-- refuses or voids anchors into from outside (the rule that makes GameTooltip refuse SetOwner on the
-- strip, modules/Anchors.lua's tooltipSpec); not provable headless. The repaint reads nothing off the
-- strip and lays its textures only against the strip itself, so a strip on secret geometry is fine.
-- ONE strip at most is repainted at a time (`edged`), and every way a mark ends gives its gold back:
-- the mark moving to another strip or to the box, and hideHighlight, which every end runs through (no
-- pair, Shift, combat, a strip hidden mid-drag, the drop, Snap.EndDrag from a cancel or a Destroy of
-- the dragged container), plus Snap.ReleaseStrip, which a Destroy of ANY container calls, so a target
-- destroyed mid-drag (a profile switch, a delete) is not kept dormant with its strip in the mark's
-- color until the next tick. A target with no visible strip (LibKa0s-Widgets absent, or its strip
-- hidden) gets the BOX instead (Snap.box, over its rect), so a mark is never lost: Style.DrawEdge's
-- four strips on a plain frame of ours, never a Backdrop (whose size arithmetic is the secret-geometry
-- trap of docs/midnight-quirks.md).
--
-- One color paints it all (paintHighlight, and edgeStrip for the strip), so the leeway's detach turns
-- the whole mark red at once. A hold or a detach is drawn on the rect the leeway measured (markRect);
-- where there is none, the dots and the line collapse onto the dragged anchor's dot, which then still
-- turns red, and the parent's strip is still repainted when it has one (showHighlight). All of it is
-- built on the first drag, so an addon nobody drags (or one stood down) makes none of it, and the
-- driver's OnUpdate is cleared, not just idle, between drags: an armed OnUpdate is a per-frame cost
-- nothing on screen reports.

--- One [Anchor] line (debug-logging-§8), when the debug log is there.
local function debug(fmt, ...)
    if NS.Debug then NS.Debug("Anchor", fmt, ...) end
end

local DRIVER_PERIOD = 0.03   -- seconds between two snap reads while a drag is live
local EDGE = 2               -- the repainted strip edge's and the box's thickness, px (A5: the strip's own is 1)
local MARKER = 10            -- each join dot's side, px (A1: 6 read too small in game)
local LINE = 2               -- the line between the two dots, px
local HIGHLIGHT_STRATA = "TOOLTIP"   -- over every container, whatever strata its layout picked

local live        -- the live container being dragged, or nil
local elapsed = 0 -- seconds since the driver last read the snap
local hitRect = {} -- scratch: the highlighted target's rect
local edged       -- the strip whose own edge the mark has repainted, or nil while it has none
local edgedCol    -- the color table `edged` was last repainted in, or nil before its first repaint
local GOLD = Anchors.STRIP_EDGE   -- the strip's own edge, put back when the mark leaves it (A6)
local dragRect = {} -- scratch: the dragged container's strip or footprint, for the child's dot
local painted     -- the color table the highlight was last painted in, or nil before it is built
local ownRect, parentRect = {}, {} -- scratch: the dragged container's and its parent's strips or footprints, for the leeway
local current = {} -- scratch: an attached drag's current pair, shaped as Snap.Nearest's answer
local startX, startY -- the cursor where the live drag began, in screen units (the leeway's fallback)
local restX, restY   -- an attached drag's current-pair vector where it began (currentPair), or nil
local restPoint, restRel -- the pair Snap.Nearest picked on the parent where the drag began, or nil
local REST_SLACK = 2 -- how far, UIParent units, a child may drift from where it rests and still be let go there (beats)
local restCand, restList = { rect = parentRect }, {} -- scratch: the parent as Snap.Nearest's one candidate
restList[1] = restCand

--- One join dot, a `MARKER`-square child frame of highlight `hl` filled by one texture (`dot.dot`,
--- which paintHighlight colors).
--- @return table
local function newDot(hl)
    local dot = CreateFrame("Frame", nil, hl)
    dot:SetSize(MARKER, MARKER)
    local tex = dot:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(dot)
    dot.dot = tex
    return dot
end

--- The box, the mark's fallback edge: a plain child frame of highlight `hl`, hidden, that
--- Style.DrawEdge paints. Placed only by placeBox.
--- @return table
local function newBox(hl)
    local f = CreateFrame("Frame", nil, hl)
    f:Hide()
    return f
end

--- Paint the highlight's own parts in color `col` ({ r, g, b, a }): the box's four strips, both dots
--- and the line, the one place any of them is colored (a repainted strip is edgeStrip's). A no-op when
--- it is already in `col`, so a tick re-lays no strip.
local function paintHighlight(col)
    if col == painted then return end
    painted = col
    NS.Style.DrawEdge(Snap.box, EDGE, col.r, col.g, col.b, col.a)
    Snap.marker.dot:SetColorTexture(col.r, col.g, col.b, col.a)
    Snap.childMarker.dot:SetColorTexture(col.r, col.g, col.b, col.a)
    Snap.line:SetColorTexture(col.r, col.g, col.b, col.a)
end

--- Build the highlight, its two join dots, the line between them and the box, once (Snap.highlight
--- the holder, Snap.marker the target's dot, Snap.childMarker the dragged one's, Snap.line, Snap.box:
--- published for the headless suite), painted in C.SNAP_COLOR. The holder covers UIParent and takes
--- no mouse (a plain frame never enables it), so it only carries its parts' visibility and strata; the
--- TOOLTIP strata puts the dots, the line and the box over any container, whatever strata its layout
--- picked. Hidden at birth; shown only while a pair is.
local function buildHighlight()
    if Snap.highlight then return Snap.highlight end
    local hl = CreateFrame("Frame", nil, UIParent)
    hl:SetFrameStrata(HIGHLIGHT_STRATA)
    hl:SetAllPoints(UIParent)
    Snap.highlight, Snap.marker, Snap.childMarker = hl, newDot(hl), newDot(hl)
    Snap.box = newBox(hl)
    local line = hl:CreateLine(nil, "OVERLAY")
    line:SetThickness(LINE)
    Snap.line = line
    paintHighlight(C.SNAP_COLOR)
    hl:Hide()
    return hl
end

--- Repaint strip `strip`'s own edge `EDGE` px in color `col` ({ r, g, b, a }), or, with `strip` nil,
--- repaint none (A6). Whatever strip it repainted before and is leaving gets the widget's gold back
--- first (GOLD: 1px, as the widget drew it), so at most one strip is ever off its own gold. A strip
--- already in `col` is not repainted, so a tick on the same target in the same color lays nothing.
--- Both paints are Style.DrawEdge on the strip, the painter the widget drew it with: the same four
--- textures, laid against the strip alone, no size read and no frame of ours anchored to it.
local function edgeStrip(strip, col)
    if strip ~= edged then
        if edged then NS.Style.DrawEdge(edged, GOLD.size, GOLD.r, GOLD.g, GOLD.b, GOLD.a) end
        edged, edgedCol = strip, nil
    end
    if strip and col ~= edgedCol then
        edgedCol = col
        NS.Style.DrawEdge(strip, EDGE, col.r, col.g, col.b, col.a)
    end
end

--- Hide the highlight (and every part of it with it), if it was ever built, and give the repainted
--- strip its gold back (edgeStrip), built or not: every way a mark ends runs through here.
local function hideHighlight()
    edgeStrip(nil)
    if Snap.highlight then Snap.highlight:Hide() end
end

--- The strip whose own edge the mark has repainted now, or nil (published for the headless suite).
--- @return table|nil
function Snap.MarkedStrip()
    return edged
end

--- Container `container` is being destroyed (ContainerClass:Destroy, for a delete, a profile switch or
--- reset, or a stand-down): when its strip is the one the mark repainted, the gold goes back now. A
--- destroyed instance is kept dormant and revived under its id with the same strip, and a destroyed
--- TARGET is not the drag's, so no tick or end of drag might come to restore it before it shows again.
--- The drag itself, the mark and the driver go on as they were; the next tick finds another pair or none.
function Snap.ReleaseStrip(container)
    if edged and container.handle == edged then edgeStrip(nil) end
end

--- The strip the mark for `pair` repaints (A5, A6): the drag-handle strip of the container it names (the
--- target of an "attach", the current parent of a "hold" or a "detach"), or nil when there is no
--- pair, no such live container, no strip (LibKa0s-Widgets absent) or the strip is not visible. Only
--- its visibility is read, never its geometry.
--- @return table|nil
local function markStrip(pair)
    local target = pair and NS.ContainerManager.instances[pair.id]
    local strip = target and target.handle
    if strip and strip:IsVisible() then return strip end
    return nil
end

--- Place the box, the mark's fallback edge, or hide it: hidden when `strip` is repainted instead (A6);
--- else over `rect` (UIParent units), or, with no rect, a dot's size centered on (`cx`, `cy`).
local function placeBox(rect, strip, cx, cy)
    local box = Snap.box
    if strip then return box:Hide() end
    box:ClearAllPoints()
    if rect then
        box:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", rect.left, rect.bottom)
        box:SetSize(rect.right - rect.left, rect.top - rect.bottom)
    else
        box:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
        box:SetSize(MARKER, MARKER)
    end
    box:Show()
end

--- Center join dot `dot` on (`x`, `y`), in UIParent units.
local function placeDot(dot, x, y)
    dot:ClearAllPoints()
    dot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end

--- Show the highlight for pair `pair` of the drag of live container `dragged`, painted in `col`: the
--- own edge of `strip` repainted (markStrip: the target's or parent's strip, A6), or with none the box over `rect`
--- (the target's or parent's strip or footprint, in UIParent units, A10); the target's dot on its relative point
--- of the pair, the dragged container's dot on its own point of it on its own strip, and the line
--- from the first dot to the second. With no `rect` (a parent that is hidden or does not read, A4) the
--- dots and the line collapse onto the dragged container's dot, and so does the box when there is no
--- strip either, so the hold and the red still show and nothing is toggled apart. Hidden when there is
--- no pair, or when the dragged anchor no longer reads. Every number is already a plain one in UIParent units, and every part
--- hangs from UIParent, so no offset is converted.
local function showHighlight(pair, rect, strip, dragged, col)
    local own = pair and ownFootprint(dragged, dragRect)
    if not own then return hideHighlight() end
    local hl = buildHighlight()
    paintHighlight(col)
    local cx, cy = Snap.PointAt(own, pair.point)
    local px, py = cx, cy
    if rect then px, py = Snap.PointAt(rect, pair.relPoint) end
    edgeStrip(strip, col)
    placeBox(rect, strip, cx, cy)
    placeDot(Snap.marker, px, py)
    placeDot(Snap.childMarker, cx, cy)
    Snap.line:SetStartPoint("BOTTOMLEFT", UIParent, px, py)
    Snap.line:SetEndPoint("BOTTOMLEFT", UIParent, cx, cy)
    hl:Show()
end

-- ---------------------------------------------------------------------------
-- The detach leeway (the owner-feedback addendum's A4)
-- ---------------------------------------------------------------------------
-- A container attached to another is not detached the moment it leaves snap range. Each tick, and
-- again at the release, classify works out what letting go now would do, in this order:
--   1. "attach": a pair in snap range (Snap.Find, any target including its own parent) that is not
--      its current pair and is STRICTLY NEARER than it (beats), Shift not held: green on that pair, a
--      release attaches;
--   2. "hold": the snap answer IS its current pair (sameAsCurrent: A7 makes it the pick anywhere over
--      its third of the parent's side, however far from that pair's points on a long parent), or its
--      current pair's two points (its own now, its parent's now) at most C.DETACH_RADIUS from where
--      they were when the drag began, or from each other: green on the current pair, a release snaps
--      it back and writes nothing;
--   3. "detach": beyond it: the whole mark red (C.DETACH_COLOR) on the current pair, a release
--      detaches it where it was let go (D6).
-- "Strictly nearer" is this file's reading of the addendum's "not its current pair": the hit's |gap|
-- (A7) under the current pair's distance, so a pair only as near as the current one never re-attaches
-- a container picked up and let go where it sits; nor, while it is still there (REST_SLACK), does the
-- pair the pick gave where it rested (beats). Both pairs are measured on the strips (A10). Shift suppresses step 1 only. A parent that does not
-- read (hidden, or the frame a follower hangs from reading secret, as an engine holding auras does)
-- has no measurable pair, so step 2 holds while the cursor has moved less than C.DETACH_RADIUS from
-- where the drag began. Never the one-element anchor Snap.TargetRect falls back to: the child hangs
-- from the whole block, so a parent several rows deep would measure it far past the radius at rest,
-- and step 1 takes no pair of such a parent either, since Snap.Find measured it on that fallback. A
-- parent with no live instance at all leaves nothing to hold on: such a container detaches as before.
-- A screen container has no current pair: step 1 or nothing, exactly as before A4.

--- How far the cursor has moved since the live drag began, in UIParent units (the cursor reads in
--- screen units, so over UIParent's effective scale), or nil when any reading is not plain.
--- @return number|nil
local function cursorTravel()
    local x, y = GetCursorPosition()
    x, y = plain(x), plain(y)
    local ui = plain(UIParent:GetEffectiveScale())
    if not (x and y and startX and startY and ui) or ui <= 0 then return nil end
    local dx, dy = (x - startX) / ui, (y - startY) / ui
    return math.sqrt(dx * dx + dy * dy)
end

--- The pair attached container `container` (settings `cfg`) joins its parent by, in `current`
--- (scratch, Snap.Nearest's shape): the parent's id and the pair in effect (Anchors.AttachPoints,
--- Automatic resolved), and `rect` the parent's rect the hold and the red are drawn on, nil where it
--- is hidden or neither its strip nor its block reads. Where the parent's anchor is shown and both
--- rects read (A10: each its strip, or else A8's: the parent's block on the frame a follower hangs
--- from, Anchors.HangFrame, with no fallback, the dragged one's anchor, each with its label), `dx`,
--- `dy` run from the parent's point of the pair to the dragged container's own point of it, `dist` is
--- their length, and `away` the leeway's measure: the nearer of `dist` and `moved`, how far that vector
--- has moved from where it was when the drag began (`restX`, `restY`), since Place never sets a child
--- on its bare join (the seam gap, its strip and label room and its X/Y nudge, all in its own scale,
--- lie between). All of them in UIParent units, and nil where they do not read (`away` and `moved`
--- also with no rest vector). Nil when the parent has no live instance.
--- @return table|nil
local function currentPair(container, cfg)
    local id = tonumber(cfg.attach.container)
    local parent = id and NS.ContainerManager.instances[id]
    if not parent then return nil end
    current.id, current.point, current.relPoint = id, Anchors.AttachPoints(cfg)
    current.dx, current.dy, current.dist, current.away, current.moved = nil, nil, nil, nil, nil
    local rect = parent.anchor and parent.anchor:IsShown() and footprint(parent, parentRect, hangRect)
    current.rect = rect or nil
    local own = rect and ownFootprint(container, ownRect)
    if not own then return current end
    local cx, cy = Snap.PointAt(own, current.point)
    local px, py = Snap.PointAt(rect, current.relPoint)
    local dx, dy = cx - px, cy - py
    current.dx, current.dy, current.dist = dx, dy, math.sqrt(dx * dx + dy * dy)
    if restX then
        local mx, my = dx - restX, dy - restY
        current.moved = math.sqrt(mx * mx + my * my)
        current.away = math.min(current.dist, current.moved)
    end
    return current
end

--- Whether current pair `cur` (currentPair) is within the leeway: `away` at most C.DETACH_RADIUS, or,
--- when that does not read, the cursor less than that from where the drag began.
local function holds(cur)
    if cur.away then return cur.away <= C.DETACH_RADIUS end
    local travel = cursorTravel()
    return travel ~= nil and travel < C.DETACH_RADIUS
end

--- Whether snap answer `hit` takes the container from current pair `cur` (step 1): with no current
--- pair, any hit; never `cur` itself; never the pair the pick gave on the current parent where the
--- drag began (`restPoint`, `restRel`, Snap.BeginDrag) while the child is still where it rests (`cur`'s
--- `moved` at most REST_SLACK); never any pair of the current parent while `cur` has no distance (its
--- block does not read, so the hit was measured on Snap.TargetRect's one-element fallback, which a
--- child resting under a one-row parent is always in range of); else only a pair strictly nearer than
--- `cur`: the hit's |gap| (A7) under `cur`'s distance between its two points. The rest pick is this
--- file's reading of A7 against A4, not the addendum's: a child as wide as its parent rests centered
--- under it whatever pair it was stored by, so the pick there is the middle pair, as near by its gap as
--- the stored pair's two points are apart, and nearer by any sideways drift (in game the parent's
--- engine lead alone is one unit). Without it, a child stored by its start pair (Automatic's) and let
--- go where it sits would be re-attached by its middle pair, writing a pair nobody picked. It covers
--- only that let-go: once the child has moved past REST_SLACK the rest pick competes like any pair, so
--- a child wider than its parent, whose rest pick is a real and different pair (the end pair, its
--- center in the last third), can still be dropped onto it. With no rest vector it never applies.
--- @return boolean
local function beats(hit, cur)
    if not (hit and cur) then return hit ~= nil end
    if hit.id == cur.id then
        if not cur.dist then return false end
        if hit.point == cur.point and hit.relPoint == cur.relPoint then return false end
        if hit.point == restPoint and hit.relPoint == restRel
            and cur.moved and cur.moved <= REST_SLACK then return false end
    end
    return not (cur.dist and hit.dist >= cur.dist)
end

--- Whether snap answer `hit` is current pair `cur` itself, measured (`cur.dist` reads): then the
--- child is in snap range of the very pair it hangs by, so it holds whatever the leeway says. Never
--- when `cur` has no distance: the hit was then measured on Snap.TargetRect's one-element fallback of
--- a parent whose block does not read, which a child resting under it is always in range of.
--- @return boolean
local function sameAsCurrent(hit, cur)
    return hit ~= nil and cur ~= nil and cur.dist ~= nil and hit.id == cur.id
        and hit.point == cur.point and hit.relPoint == cur.relPoint
end

--- What releasing live container `container` now would do (the order above), and the pair the mark
--- is shown on: "attach" and Snap.Nearest's answer, "hold" or "detach" and the current pair
--- (scratch), or nil and nil (a screen container with nothing in range). Reads Shift, the rects and
--- the cursor afresh on every call, so a tick and the release answer alike for the same state. Combat
--- is the caller's: the tick hides the mark, the drop holds (D11).
--- @return string|nil state, table|nil pair
local function classify(container)
    local cfg = container:Cfg()
    local hit = not IsShiftKeyDown() and Snap.Find(container) or nil
    if not (cfg and cfg.attach and cfg.attach.mode == "container") then
        return hit and "attach" or nil, hit
    end
    local cur = currentPair(container, cfg)
    if beats(hit, cur) then return "attach", hit end
    if not cur then return "detach", nil end
    if sameAsCurrent(hit, cur) then return "hold", cur end
    return holds(cur) and "hold" or "detach", cur
end

--- Whether live container `container`'s drag can still end the usual way: its strip is visible. A
--- strip hidden mid-drag (/am lock, a stand-down, a disable or a profile switch run while the button is
--- held) is sent no OnDragStop by the client, which is why the OnHide->StopMovingOrSizing idiom
--- exists, so without this the anchor kept following the cursor and `dragging` held Anchors.Place off
--- it until the next drag of it.
local function strandedDrag(container)
    local handle = container.handle
    return not (handle and handle:IsVisible())
end

--- Cancel the drag of `container`, whose strip hid mid-drag (strandedDrag): the anchor stops moving,
--- the drag ends (Snap.EndDrag) and the anchor goes back where its stored settings put it. Nothing is
--- written, since nobody dropped it: an attached one goes back on its parent, a screen one to its
--- stored position. Out of lockdown only; the tick waits for combat to end before it calls this.
local function cancelStranded(container)
    debug("container %s: drag canceled (its strip hid)", container.id)
    if container.anchor then container.anchor:StopMovingOrSizing() end
    Snap.EndDrag(container)
    container.placedAs = Anchors.Place(container)
end

--- The rect the mark for classify's answer is measured on: an "attach" target's footprint
--- (Snap.Footprint, A10), else the current pair's parent's as the leeway measured it (currentPair:
--- never the one-element fallback, never a hidden parent), so the parent's dot (and the box, where the
--- parent has no visible strip) sits on what a snap back returns to. Nil when there is none.
--- @return table|nil
local function markRect(state, pair)
    if not pair then return nil end
    if state ~= "attach" then return pair.rect end
    local target = NS.ContainerManager.instances[pair.id]
    return target and Snap.Footprint(target, hitRect)
end

--- One driver tick's work, published so the suite drives it without a clock: classify's answer for
--- the live drag (A4), the highlight shown on its pair and its container's strip repainted (A5, A6), red for
--- "detach" and green otherwise, or hidden when there is none. Returns the pair and the state: a candidate and "attach" (on Shift a
--- screen container has none, D4), an attached container's current pair and "hold" or "detach", or
--- nil once combat has started (D11), with no live drag, or with nothing to show. A drag whose strip
--- hid is canceled here instead (cancelStranded), once out of combat.
--- @return table|nil pair, string|nil state
function Snap.Tick()
    if live and strandedDrag(live) then
        hideHighlight()
        if not InCombatLockdown() then cancelStranded(live) end
        return nil
    end
    if not live or InCombatLockdown() then
        hideHighlight()
        return nil
    end
    local state, pair = classify(live)
    local col = state == "detach" and C.DETACH_COLOR or C.SNAP_COLOR
    showHighlight(pair, markRect(state, pair), markStrip(pair), live, col)
    return pair, state
end

--- The driver's OnUpdate: Snap.Tick at most every DRIVER_PERIOD.
local function onUpdate(_, dt)
    elapsed = elapsed + (tonumber(dt) or 0)
    if elapsed < DRIVER_PERIOD then return end
    elapsed = 0
    Snap.Tick()
end

--- Start the driver on live container `container` (Snap.driver: published for the suite). An
--- OnUpdate runs only on a shown frame, so the driver is shown while it drives and hidden after.
local function startDriver(container)
    local driver = Snap.driver
    if not driver then
        driver = CreateFrame("Frame")
        Snap.driver = driver
    end
    live, elapsed = container, 0
    driver:SetScript("OnUpdate", onUpdate)
    driver:Show()
end

--- Stop the driver, clear its OnUpdate (not idle: cleared) and hide the highlight.
local function stopDriver()
    live = nil
    local driver = Snap.driver
    if driver then
        driver:SetScript("OnUpdate", nil)
        driver:Hide()
    end
    hideHighlight()
end

--- Hang container `container`'s anchor from UIParent for the drag ("Starting a drag"), so the move
--- starts from a rect of ours and not from its parent's, which may read secret. Where its left and
--- bottom edges read plain, BOTTOMLEFT at them, so it does not move; where either reads secret (it
--- hangs from an engine holding auras), its center under the cursor. The cursor is on the strip,
--- which sits outside the block (past a shown name label, and wider than a narrow element), so the
--- jump is up to the distance from the grab to the anchor's center, more than its own size on a
--- short bar. Offsets are in the anchor's own units: its edges are read in them, and the cursor
--- (screen units) is taken to them over its effective scale. Never under lockdown (beginDrag gates).
local function lift(container)
    local anchor = container.anchor
    local l, b = plain(anchor:GetLeft()), plain(anchor:GetBottom())
    anchor:ClearAllPoints()
    if l and b then
        anchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
        return "read"
    end
    local x, y = GetCursorPosition()
    local scale = plain(anchor:GetEffectiveScale()) or plain(UIParent:GetEffectiveScale()) or 1
    if scale <= 0 then scale = 1 end
    anchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (plain(x) or 0) / scale, (plain(y) or 0) / scale)
    return "cursor"
end

--- Note where attached container `container` rests (settings `cfg`), before it is lifted: its current
--- pair's vector (currentPair) as the leeway's rest, and the pair Snap.Nearest picks for it on its
--- parent there as the rest pick that never re-attaches it (beats). Both nil where they do not read.
local function noteRest(container, cfg)
    local rest = currentPair(container, cfg)
    if not (rest and rest.dx) then return end
    restX, restY = rest.dx, rest.dy
    restCand.id = rest.id
    local pick = Snap.Nearest(ownRect, restList, C.SNAP_RADIUS)
    if pick then restPoint, restRel = pick.point, pick.relPoint end
end

--- A drag of live container `container` begins (beginDrag in modules/Anchors.lua said yes, so it is
--- screen or container-attached and out of combat). A container-attached one is lifted onto UIParent
--- first (lift), where it rests noted beforehand (noteRest); a screen one already hangs there. Then
--- `dragging` holds Anchors.Place off it, and the driver starts, with the cursor's position noted for
--- the leeway's fallback (classify).
function Snap.BeginDrag(container)
    local cfg = container:Cfg()
    restX, restY, restPoint, restRel = nil, nil, nil, nil
    if cfg and cfg.attach and cfg.attach.mode == "container" and container.anchor then
        noteRest(container, cfg)
        local how = lift(container)
        if NS.Debug then NS.Debug("Anchor", "container %s: drag lifts it off its parent (%s)", container.id, how) end
    end
    container.dragging = true
    startX, startY = GetCursorPosition()
    startX, startY = plain(startX), plain(startY)
    startDriver(container)
end

--- The drag of `container` is over, however it ends: `dragging` cleared, the driver stopped and the
--- highlight hidden. Safe to call when no drag is live.
function Snap.EndDrag(container)
    container.dragging = nil
    if live == container or live == nil then stopDriver() end
end

-- ---------------------------------------------------------------------------
-- The drop (D6, D7, D8, D10, D11; "Dropping")
-- ---------------------------------------------------------------------------
-- What a drop does is decided here, from the drop alone: combat is read, and classify (A4) run, again
-- at the drop, never taken from the driver's last tick (a tick may be up to DRIVER_PERIOD old, and
-- the key may have changed since). Every write goes through the seam, NS.SetByPath, on THIS
-- container rather than the settings panel's active one, and every outcome writes one [Anchor] line.

--- A copy of container `cfg`'s stored attach section, the start of a whole-section write: every key
--- it holds kept (the frame mode's frame, point and relativePoint, the target and the two points a
--- detach leaves stored, as a mode switch on the panel leaves them), one level deep, which is all the
--- section is.
local function attachCopy(cfg)
    local out = {}
    for k, v in pairs(cfg.attach or {}) do out[k] = v end
    return out
end

--- The section a drop on `hit` writes for container `cfg` (D7, D10): container mode on the target,
--- the picked pair's two points (both nil when the pair is Automatic's, Snap.FoldPoints), and the
--- offsets reset to 0, since the drop is the placement and an old nudge would only push it off it.
local function attachSection(cfg, hit)
    local section = attachCopy(cfg)
    section.mode, section.container, section.x, section.y = "container", hit.id, 0, 0
    section.childPoint, section.relPoint = Snap.FoldPoints(cfg, hit.id, hit.point, hit.relPoint)
    return section
end

--- Attach live container `container` where `hit` says (D7, D8). settings/Layout.lua's
--- NS.AttachByDrop owns the write, because the growth-conflict popup (GC-1) is that page's: it
--- writes the section, or asks first when the chain the drop joins flows differently. Whenever it
--- did not write (it asked, or the seam refused the section), the anchor goes back where the stored
--- settings put it, so a drop the player has yet to confirm is never left looking attached; Cancel
--- then leaves everything as it was before the drag. Whatever the answer, the anchor is placed here
--- and now, from the settings as the drop left them: the apply a written attach's CONFIG_CHANGED
--- queues is held by ContainerManager while auras are secret as well as under lockdown
--- (CM.MustDefer), and between pulls in a key a drag runs with no lockdown, so waiting for it would
--- leave the anchor loose where it was let go. Place is layout only (SetPoint, SetSize), legal out of
--- lockdown, which the drop is (Snap.Drop handles combat before this).
local function dropOn(container, cfg, hit)
    debug("container %s: drop: attach to %s %s>%s (%s)", container.id, hit.id, hit.point, hit.relPoint,
        hit.token or "free")
    if NS.AttachByDrop then NS.AttachByDrop(container.id, attachSection(cfg, hit)) end
    container.placedAs = Anchors.Place(container)
end

--- Detach container-attached `container` where it was dropped (D6, D10): its screen position first,
--- read from the anchor as a screen drag stores it (Anchors.SavePosition; the drag hung it from
--- UIParent), then the attach section with mode screen and x and y 0. When the position could not be
--- stored (it read secret), it does not detach at all, since the screen mode would place it at a
--- stale position; it goes back to its parent instead.
local function detach(container, cfg)
    if not Anchors.SavePosition(container) then
        container.placedAs = Anchors.Place(container)
        return
    end
    debug("container %s: drop: detach", container.id)
    local section = attachCopy(cfg)
    section.mode, section.x, section.y = "screen", 0, 0
    NS.SetByPath("container.attach", section, container.id)
end

--- A release within the leeway (A4's hold): nothing written, and the anchor goes back where its
--- stored settings put it, on its parent, as a canceled drag does (cancelStranded).
local function snapBack(container)
    debug("container %s: drop: held (leeway)", container.id)
    container.placedAs = Anchors.Place(container)
end

-- Containers dropped in combat while attached, [id] = true, re-placed when combat ends (Snap.PlaceHeld).
local held = {}

--- A drop after combat started mid-drag (D11): nothing attaches. A screen container stores where it
--- was dropped, as it did before issue #22. A container-attached one is neither detached nor written:
--- its anchor parents an aura engine and may not be re-placed under lockdown, so it is HELD, and
--- Snap.PlaceHeld puts it back on its parent at PLAYER_REGEN_ENABLED. An apply is asked for too (a
--- system one, silent), but that alone is not enough: ContainerManager keeps holding it after combat
--- for as long as auras stay secret (CM.MustDefer), as in a key between pulls.
local function dropInCombat(container, attached)
    debug("container %s: drop: held (combat)", container.id)
    if attached then
        held[container.id] = true
        NS.ContainerManager.RequestApply(container.id, true)
        return
    end
    Anchors.SavePosition(container)
end

--- Combat is over (core/AuraMaster.lua's PLAYER_REGEN_ENABLED, after the flush): every container a
--- combat drop held goes back where its settings put it, whether or not the apply it asked for may
--- run yet. A container gone since, or being dragged again, is only forgotten. Answers how many it
--- placed; does nothing under lockdown (the held ones wait for the next end of combat).
--- @return number
function Snap.PlaceHeld()
    if InCombatLockdown() or next(held) == nil then return 0 end
    local n = 0
    for id in pairs(held) do
        held[id] = nil
        local inst = NS.ContainerManager.instances[id]
        if inst and not inst.dragging then
            inst.placedAs = Anchors.Place(inst)
            n = n + 1
        end
    end
    debug("drop: %d container(s) held by combat re-placed", n)
    return n
end

--- The widget's OnDragStop (after StopMovingOrSizing). Ends the drag (Snap.EndDrag), then:
---   1. combat started mid-drag: dropInCombat (no attach, no detach);
---   2. else as classify (A4) answers now: "attach", dropOn (or its GC-1 question); "hold", snapBack;
---   3. else a container-attached one detaches where it was dropped, and a screen one stores its
---      position (Anchors.SavePosition), exactly as before issue #22.
--- A drop that reaches here with no drag of this container live (a stray stop) does nothing.
function Snap.Drop(container)
    if not container.dragging then return end
    Snap.EndDrag(container)
    local cfg = container:Cfg()
    if not cfg then return end
    local attached = cfg.attach and cfg.attach.mode == "container"
    if InCombatLockdown() then return dropInCombat(container, attached) end
    local state, hit = classify(container)
    if state == "attach" then return dropOn(container, cfg, hit) end
    if state == "hold" then return snapBack(container) end
    if attached then return detach(container, cfg) end
    debug("container %s: drop: moved", container.id)
    Anchors.SavePosition(container)
end
