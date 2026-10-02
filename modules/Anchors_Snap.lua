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
-- For each pair the distance is measured between the dragged anchor's own point and the target's
-- relative point, on the rect a follower would hang from (Anchors.HangFrame); the nearest pair of the
-- nearest target wins when it is within C.SNAP_RADIUS. Everything is in UIParent units, so the radius
-- feels the same under any scale.
--
-- WHAT IS READ, AND HOW. Two kinds of rect: the dragged anchor's, which hangs from UIParent while it
-- is dragged and holds nothing secret, and each target's hang frame, which may be an ENGINE holding
-- auras, whose geometry reads secret (core/Secrets.lua). Every number goes through
-- Secrets.NumberOr before any arithmetic; an engine that does not read plainly falls back to the
-- target's own anchor (exactly one element, its first), and a target whose anchor does not read
-- either is simply not a candidate this tick.
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

--- The nearest outside pair of the nearest candidate (A2, D2). `childRect` is the dragged anchor's
--- rect and each of `candidates` is { id, rect, growH, growV }, the target's hang rect and the growth
--- its chain flows by, all rects { left, bottom, right, top } in one unit (UIParent's, from
--- Snap.Candidates). For every candidate, in the order given (Snap.Candidates gives id order), and
--- every pair in OUTSIDE order, the distance runs from the child's point of the pair to the target's
--- relative point of it; growth plays no part in the choice. Only a strictly nearer pair replaces the
--- best so far, so a tie keeps the first target and the first pair. Within `radius` (inclusive) the
--- answer is { id, side, point, relPoint, token, dist }: `side` the target's side ("bottom", "top",
--- "right" or "left") and `token` the one of the nine the pair is under the target's growth, nil for
--- a free one (its before side). Else nil. Squared distances while scanning, one sqrt for the answer;
--- allocates only the answer.
--- @return table|nil
function Snap.Nearest(childRect, candidates, radius)
    local bestD, bestCand, bestRow
    for _, cand in ipairs(candidates) do
        for _, row in ipairs(OUTSIDE) do
            local cx, cy = Snap.PointAt(childRect, row[3])
            local tx, ty = Snap.PointAt(cand.rect, row[2])
            local d = (cx - tx) * (cx - tx) + (cy - ty) * (cy - ty)
            if bestD == nil or d < bestD then bestD, bestCand, bestRow = d, cand, row end
        end
    end
    if bestD == nil or bestD > radius * radius then return nil end
    local point, relPoint = bestRow[3], bestRow[2]
    return {
        id = bestCand.id, side = bestRow[1], point = point, relPoint = relPoint,
        token = tokenFor(bestCand.growH, bestCand.growV, point, relPoint), dist = math.sqrt(bestD),
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
-- the answer list and the candidate tables it hands out, each candidate with its own rect table.
local order, list, pool = {}, {}, {}

--- The eligible targets for `dragged`, in id order, each { id, rect, growH, growV }: its hang rect
--- in UIParent units (Snap.TargetRect) and the growth its chain flows by. A target whose rect does
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
        local cand = pool[n + 1] or { rect = {} }
        if eligible(dragged, t) and Snap.TargetRect(t, cand.rect) then
            n = n + 1
            pool[n], list[n] = cand, cand
            cand.id = id
            cand.growH, cand.growV = flowGrowth(t:Cfg())
        end
    end
    for i = #list, n + 1, -1 do list[i] = nil end
    return list
end

local childRect = {}

--- What dropping live container `dragged` now would snap it onto (Snap.Nearest's answer over
--- Snap.Candidates, within C.SNAP_RADIUS), or nil: nothing in range, or its own anchor does not
--- read plainly (it hangs from UIParent while dragged, so it should).
--- @return table|nil
function Snap.Find(dragged)
    if not readRect(dragged and dragged.anchor, childRect) then return nil end
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
-- The highlight is ours and plain: a frame under UIParent with Style.DrawEdge's four strips, never a
-- Backdrop (whose size arithmetic is the secret-geometry trap of docs/midnight-quirks.md), over the
-- target; a dot on each of the pair's two join points, the target's relative point and the dragged
-- anchor's own point (the owner-feedback addendum's A1, A3); and a Line region between the two dots.
-- The dots are child frames of the highlight and the line one of its regions, so one Show or Hide
-- takes them all and none is ever toggled on its own. Everything is placed by numbers already in
-- UIParent units (Snap.TargetRect, readRect), anchored to UIParent (the line's two ends too) and
-- never to the target, so nothing of ours ever hangs from an engine's secret rect. One color paints
-- them all (paintHighlight), so the leeway's detach turns the whole mark red at once. A hold or a
-- detach is drawn on the rect the leeway measured (markRect); where there is none, the whole mark
-- collapses onto the dragged anchor's dot, which then still turns red (showHighlight). All of
-- it is built on the first drag, so an addon nobody drags (or one stood down) makes none of it, and
-- the driver's OnUpdate is cleared, not just idle, between drags: an armed OnUpdate is a per-frame
-- cost nothing on screen reports.

--- One [Anchor] line (debug-logging-§8), when the debug log is there.
local function debug(fmt, ...)
    if NS.Debug then NS.Debug("Anchor", fmt, ...) end
end

local DRIVER_PERIOD = 0.03   -- seconds between two snap reads while a drag is live
local EDGE = 2               -- the highlight's edge, px
local MARKER = 10            -- each join dot's side, px (A1: 6 read too small in game)
local LINE = 2               -- the line between the two dots, px
local HIGHLIGHT_STRATA = "TOOLTIP"   -- over every container, whatever strata its layout picked

local live        -- the live container being dragged, or nil
local elapsed = 0 -- seconds since the driver last read the snap
local hitRect = {} -- scratch: the highlighted target's rect
local dragRect = {} -- scratch: the dragged anchor's rect, for the child's dot
local painted     -- the color table the highlight was last painted in, or nil before it is built
local ownRect, parentRect = {}, {} -- scratch: the dragged anchor's and its parent's rects, for the leeway
local current = {} -- scratch: an attached drag's current pair, shaped as Snap.Nearest's answer
local startX, startY -- the cursor where the live drag began, in screen units (the leeway's fallback)
local restX, restY   -- an attached drag's current-pair vector where it began (currentPair), or nil

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

--- Paint the whole highlight in color `col` ({ r, g, b, a }): the box's four strips, both dots and
--- the line, the one place any of them is colored. A no-op when it is already in `col`, so a tick
--- re-lays no strip.
local function paintHighlight(col)
    if col == painted then return end
    painted = col
    NS.Style.DrawEdge(Snap.highlight, EDGE, col.r, col.g, col.b, col.a)
    Snap.marker.dot:SetColorTexture(col.r, col.g, col.b, col.a)
    Snap.childMarker.dot:SetColorTexture(col.r, col.g, col.b, col.a)
    Snap.line:SetColorTexture(col.r, col.g, col.b, col.a)
end

--- Build the highlight, its two join dots and the line between them, once (Snap.highlight,
--- Snap.marker the target's dot, Snap.childMarker the dragged one's, Snap.line: published for the
--- headless suite), painted in C.SNAP_COLOR. Hidden at birth; shown only while a pair is.
local function buildHighlight()
    if Snap.highlight then return Snap.highlight end
    local hl = CreateFrame("Frame", nil, UIParent)
    hl:SetFrameStrata(HIGHLIGHT_STRATA)
    Snap.highlight, Snap.marker, Snap.childMarker = hl, newDot(hl), newDot(hl)
    local line = hl:CreateLine(nil, "OVERLAY")
    line:SetThickness(LINE)
    Snap.line = line
    paintHighlight(C.SNAP_COLOR)
    hl:Hide()
    return hl
end

--- Hide the highlight (and its dots and line with it), if it was ever built.
local function hideHighlight()
    if Snap.highlight then Snap.highlight:Hide() end
end

--- Center join dot `dot` on (`x`, `y`), in UIParent units.
local function placeDot(dot, x, y)
    dot:ClearAllPoints()
    dot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end

--- Show the highlight for pair `pair` of the drag of live container `dragged`, painted in `col`: the
--- box over `rect` (the target's or parent's, in UIParent units), the target's dot on its relative
--- point of the pair, the dragged anchor's dot on its own point of it, and the line from the first dot
--- to the second. With no `rect` (a parent that is hidden or does not read, A4) the whole mark
--- collapses onto the dragged anchor's dot: the box a dot's size centered on it, the other dot and
--- both ends of the line there too, so the hold and the red still show and nothing is toggled apart.
--- Hidden when there is no pair, or when the dragged anchor no longer reads. Every number is already
--- a plain one in UIParent units, and every part hangs from UIParent, so no offset is converted.
local function showHighlight(pair, rect, dragged, col)
    local own = pair and readRect(dragged and dragged.anchor, dragRect)
    if not own then return hideHighlight() end
    local hl = buildHighlight()
    paintHighlight(col)
    local cx, cy = Snap.PointAt(own, pair.point)
    local px, py = cx, cy
    hl:ClearAllPoints()
    if rect then
        hl:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", rect.left, rect.bottom)
        hl:SetSize(rect.right - rect.left, rect.top - rect.bottom)
        px, py = Snap.PointAt(rect, pair.relPoint)
    else
        hl:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
        hl:SetSize(MARKER, MARKER)
    end
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
--   2. "hold": its current pair's two points (its own now, its parent's now) at most C.DETACH_RADIUS
--      from where they were when the drag began, or from each other: green on the current pair, a
--      release snaps it back and writes nothing;
--   3. "detach": beyond it: the whole mark red (C.DETACH_COLOR) on the current pair, a release
--      detaches it where it was let go (D6).
-- "Strictly nearer" is this file's reading of the addendum's "not its current pair": a pair only as
-- near as the current one (a child as wide as its parent has all three of that side's pairs at one
-- distance, and the first in table order wins the tie) would otherwise re-attach a container picked
-- up and let go where it sits by another pair. Shift suppresses step 1 only. A parent that does not
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
--- is hidden or does not read. Where the parent's anchor is shown and both rects read (the parent's on the
--- frame a follower hangs from, Anchors.HangFrame, with no fallback), `dx`, `dy` run from the parent's
--- point of the pair to the dragged anchor's own point of it, `dist` is their length, and `away` the
--- leeway's measure: the nearer of `dist` and how far that vector has moved from where it was when the
--- drag began (`restX`, `restY`), since Place never sets a child on its bare join (the seam gap, its
--- strip and label room and its X/Y nudge, all in its own scale, lie between). All of them in UIParent
--- units, and nil where they do not read (`away` also with no rest vector). Nil when the parent has
--- no live instance.
--- @return table|nil
local function currentPair(container, cfg)
    local id = tonumber(cfg.attach.container)
    local parent = id and NS.ContainerManager.instances[id]
    if not parent then return nil end
    current.id, current.point, current.relPoint = id, Anchors.AttachPoints(cfg)
    current.dx, current.dy, current.dist, current.away = nil, nil, nil, nil
    local rect = parent.anchor and parent.anchor:IsShown() and readRect(Anchors.HangFrame(parent), parentRect)
    current.rect = rect or nil
    local own = rect and readRect(container.anchor, ownRect)
    if not own then return current end
    local cx, cy = Snap.PointAt(own, current.point)
    local px, py = Snap.PointAt(rect, current.relPoint)
    local dx, dy = cx - px, cy - py
    current.dx, current.dy, current.dist = dx, dy, math.sqrt(dx * dx + dy * dy)
    if restX then
        local mx, my = dx - restX, dy - restY
        current.away = math.min(current.dist, math.sqrt(mx * mx + my * my))
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
--- pair, any hit; never `cur` itself; never any pair of the current parent while `cur` has no
--- distance (its block does not read, so the hit was measured on Snap.TargetRect's one-element
--- fallback, which a child resting under a one-row parent is always in range of); else only a pair
--- strictly nearer than `cur`.
--- @return boolean
local function beats(hit, cur)
    if not (hit and cur) then return hit ~= nil end
    if hit.id == cur.id then
        if not cur.dist then return false end
        if hit.point == cur.point and hit.relPoint == cur.relPoint then return false end
    end
    return not (cur.dist and hit.dist >= cur.dist)
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

--- The rect the mark for classify's answer is drawn on: an "attach" target's (Snap.TargetRect), else
--- the current pair's parent's as the leeway measured it (currentPair: never the one-element
--- fallback, never a hidden parent), so the box frames the block a snap back returns to. Nil when
--- there is none.
--- @return table|nil
local function markRect(state, pair)
    if not pair then return nil end
    if state ~= "attach" then return pair.rect end
    local target = NS.ContainerManager.instances[pair.id]
    return target and Snap.TargetRect(target, hitRect)
end

--- One driver tick's work, published so the suite drives it without a clock: classify's answer for
--- the live drag (A4), the highlight shown on its pair, red for "detach" and green otherwise, or
--- hidden when there is none. Returns the pair and the state: a candidate and "attach" (on Shift a
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
    showHighlight(pair, markRect(state, pair), live, state == "detach" and C.DETACH_COLOR or C.SNAP_COLOR)
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

--- A drag of live container `container` begins (beginDrag in modules/Anchors.lua said yes, so it is
--- screen or container-attached and out of combat). A container-attached one is lifted onto UIParent
--- first (lift), its current pair's vector read beforehand, where its settings put it, as the leeway's
--- rest (currentPair); a screen one already hangs there. Then `dragging` holds Anchors.Place off it,
--- and the driver starts, with the cursor's position noted for the leeway's fallback (classify).
function Snap.BeginDrag(container)
    local cfg = container:Cfg()
    restX, restY = nil, nil
    if cfg and cfg.attach and cfg.attach.mode == "container" and container.anchor then
        local rest = currentPair(container, cfg)
        if rest then restX, restY = rest.dx, rest.dy end
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
