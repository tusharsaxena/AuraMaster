local _, NS = ...

-- modules/Anchors_Snap.lua — drag to attach (issue #22): which container a dragged one would snap
-- onto if it were dropped now, and by which pair of points. Its own file, so modules/Anchors.lua
-- (which places the anchor and owns the drag handle) stays well under layout-§1's cap.
--
-- THE MODEL (the design's D1, D2, D5, D7). A drop never picks a free pair: it picks one of the nine
-- classified sides (C.ATTACH_EDGES), read under the TARGET's flow growth, since that is the growth the
-- dragged container inherits the moment it attaches (Anchors.FlowRoot) and so the growth its points
-- are classified under from then on. For each side the distance is measured between the dragged
-- anchor's own point of the pair and the target's relative point of it, on the rect a follower would
-- hang from (Anchors.HangFrame); the nearest side of the nearest target wins when it is within
-- C.SNAP_RADIUS. Everything is in UIParent units, so the radius feels the same under any scale.
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
-- THE DRAG LIFECYCLE (D3, D4, D9, D11) is at the end of the file: Snap.BeginDrag, the throttled
-- driver and its highlight, Snap.Drop. modules/Anchors.lua's beginDrag and the handle's OnDragStop
-- call into it.
--
-- LOAD-BEARING POSITION: after modules/Anchors_Attach.lua, whose pair table and flow growth this
-- file binds from NS.AnchorsAttach at file load; after modules/Anchors.lua, which it extends
-- (Anchors.Snap) and whose HangFrame, WouldCycle, AutoPoints, Place and SavePosition it calls at
-- call time.

NS.Anchors = NS.Anchors or {}
local Anchors = NS.Anchors
local C = NS.Constants

-- From modules/Anchors_Attach.lua, at file load: EDGE_PAIRS[growH][growV][token] = { point,
-- relativePoint }, the very table a Place classifies by, and the growth a container flows by.
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

--- The pair table for a growth, normalized as NS.Container.Growth normalizes it ("right" unless
--- "left", "down" unless "up"), so a candidate built by hand can never miss a row.
local function pairsFor(growH, growV)
    return EDGE_PAIRS[(growH == "left") and "left" or "right"][(growV == "up") and "up" or "down"]
end

--- The nearest side of the nearest candidate (D1, D2). `childRect` is the dragged anchor's rect and
--- each of `candidates` is { id, rect, growH, growV }, the target's hang rect and the growth its
--- chain flows by, all rects { left, bottom, right, top } in one unit (UIParent's, from
--- Snap.Candidates). For every candidate, in the order given (Snap.Candidates gives id order), and
--- every side in C.ATTACH_EDGES order, the distance runs from the child's point of the side's pair
--- to the target's relative point of it. Only a strictly nearer side replaces the best so far, so a
--- tie keeps the first target and the first side. Within `radius` (inclusive) the answer is
--- { id, token, point, relPoint, dist }, else nil. Squared distances while scanning, one sqrt for
--- the answer; allocates only the answer.
--- @return table|nil
function Snap.Nearest(childRect, candidates, radius)
    local bestD, bestCand, bestToken
    for _, cand in ipairs(candidates) do
        local sides = pairsFor(cand.growH, cand.growV)
        for _, token in ipairs(C.ATTACH_EDGES) do
            local pair = sides[token]
            local cx, cy = Snap.PointAt(childRect, pair[1])
            local tx, ty = Snap.PointAt(cand.rect, pair[2])
            local d = (cx - tx) * (cx - tx) + (cy - ty) * (cy - ty)
            if bestD == nil or d < bestD then bestD, bestCand, bestToken = d, cand, token end
        end
    end
    if bestD == nil or bestD > radius * radius then return nil end
    local pair = pairsFor(bestCand.growH, bestCand.growV)[bestToken]
    return { id = bestCand.id, token = bestToken, point = pair[1], relPoint = pair[2], dist = math.sqrt(bestD) }
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
--- `targetId` by the pair `point`/`relPoint`: each nil (Automatic) where it equals the matching half
--- of Automatic's pair for that child on that target (Anchors.AutoPoints, G3), else the absolute
--- point. So a drop on the default side stores the same Automatic pair a fresh attach on the panel
--- does, and keeps following the parent's growth and justify as they change. Automatic is read for
--- the container AS IF attached to `targetId` (a probe carrying its id, style, text and layout),
--- since its stored attach still names wherever it was before the drop; `cfg` is not touched.
--- @return string|nil childPoint, string|nil relPoint
function Snap.FoldPoints(cfg, targetId, point, relPoint)
    local probe = {
        id = cfg.id, style = cfg.style, text = cfg.text, layout = cfg.layout,
        attach = { mode = "container", container = targetId },
    }
    local autoPoint, autoRel = Anchors.AutoPoints(probe)
    return (point ~= autoPoint) and point or nil, (relPoint ~= autoRel) and relPoint or nil
end

-- ---------------------------------------------------------------------------
-- The drag lifecycle (D3, D4, D9, D11; "Starting a drag", "Holding the drag steady")
-- ---------------------------------------------------------------------------
-- A drag starts in modules/Anchors.lua's beginDrag (the widget's canDrag, asked immediately before
-- StartMoving), which gates it (screen or container-attached, never frame, never in combat) and
-- hands the container here: Snap.BeginDrag lifts an attached anchor onto UIParent, marks the
-- container `dragging` (Anchors.Place leaves a dragging anchor where the drag has it) and starts
-- the DRIVER, one plain frame whose OnUpdate runs only while a drag is live and does its work at
-- most every DRIVER_PERIOD: Shift held or combat started means no candidate, else Snap.Find, and
-- the HIGHLIGHT follows the answer. The widget's OnDragStop ends it through Snap.Drop.
--
-- The highlight is ours and plain: a frame under UIParent with Style.DrawEdge's four strips, never a
-- Backdrop (whose size arithmetic is the secret-geometry trap of docs/midnight-quirks.md), and its
-- marker a child of it, so one Hide takes both. It is placed by numbers already in UIParent units
-- (Snap.TargetRect), anchored to UIParent and never to the target, so nothing of ours ever hangs
-- from an engine's secret rect. Both frames are built on the first drag, so an addon nobody drags
-- (or one stood down) makes neither, and the driver's OnUpdate is cleared, not just idle, between
-- drags: an armed OnUpdate is a per-frame cost nothing on screen reports.

local DRIVER_PERIOD = 0.03   -- seconds between two snap reads while a drag is live
local EDGE = 2               -- the highlight's edge, px
local MARKER = 6             -- the join marker's side, px
local HIGHLIGHT_STRATA = "TOOLTIP"   -- over every container, whatever strata its layout picked

local live        -- the live container being dragged, or nil
local elapsed = 0 -- seconds since the driver last read the snap
local hitRect = {} -- scratch: the highlighted target's rect

--- Build the highlight and its join marker, once (Snap.highlight, Snap.marker: published for the
--- headless suite). Hidden at birth; shown only while a candidate is in range.
local function buildHighlight()
    if Snap.highlight then return Snap.highlight end
    local col = C.SNAP_COLOR
    local hl = CreateFrame("Frame", nil, UIParent)
    hl:SetFrameStrata(HIGHLIGHT_STRATA)
    NS.Style.DrawEdge(hl, EDGE, col.r, col.g, col.b, col.a)
    local marker = CreateFrame("Frame", nil, hl)
    marker:SetSize(MARKER, MARKER)
    local dot = marker:CreateTexture(nil, "OVERLAY")
    dot:SetAllPoints(marker)
    dot:SetColorTexture(col.r, col.g, col.b, col.a)
    hl:Hide()
    Snap.highlight, Snap.marker = hl, marker
    return hl
end

--- Hide the highlight (and its marker with it), if it was ever built.
local function hideHighlight()
    if Snap.highlight then Snap.highlight:Hide() end
end

--- Show the highlight over the rect of the target `hit` names, its marker centered on the join
--- (the target's relative point of the picked pair), or hide it when there is no hit or the
--- target's rect no longer reads. Every number is already a plain one in UIParent units, and both
--- frames hang from UIParent (the marker through the highlight), so no offset is converted.
local function showHighlight(hit)
    local target = hit and NS.ContainerManager.instances[hit.id]
    local rect = target and Snap.TargetRect(target, hitRect)
    if not rect then return hideHighlight() end
    local hl = buildHighlight()
    hl:ClearAllPoints()
    hl:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", rect.left, rect.bottom)
    hl:SetSize(rect.right - rect.left, rect.top - rect.bottom)
    local x, y = Snap.PointAt(rect, hit.relPoint)
    local marker = Snap.marker
    marker:ClearAllPoints()
    marker:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    hl:Show()
end

--- One driver tick's work, published so the suite drives it without a clock: the candidate the
--- live drag would snap to now (nil while Shift is held, D4, or once combat has started, D11, as well
--- as when nothing is in range), with the highlight shown over it or hidden. Nil with no live drag.
--- @return table|nil  Snap.Nearest's answer
function Snap.Tick()
    local hit = live and not (IsShiftKeyDown() or InCombatLockdown()) and Snap.Find(live) or nil
    showHighlight(hit)
    return hit
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
--- hangs from an engine holding auras), its center under the cursor, which jumps it by at most its
--- own size. Offsets are in the anchor's own units: its edges are read in them, and the cursor
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
--- first (lift); a screen one already hangs there. Then `dragging` holds Anchors.Place off it, and
--- the driver starts.
function Snap.BeginDrag(container)
    local cfg = container:Cfg()
    if cfg and cfg.attach and cfg.attach.mode == "container" and container.anchor then
        local how = lift(container)
        if NS.Debug then NS.Debug("Anchor", "container %s: drag lifts it off its parent (%s)", container.id, how) end
    end
    container.dragging = true
    startDriver(container)
end

--- The drag of `container` is over, however it ends: `dragging` cleared, the driver stopped and the
--- highlight hidden. Safe to call when no drag is live.
function Snap.EndDrag(container)
    container.dragging = nil
    if live == container or live == nil then stopDriver() end
end

--- The widget's OnDragStop (after StopMovingOrSizing). Ends the drag (Snap.EndDrag), then settles
--- the anchor: a screen container stores where it was dropped (Anchors.SavePosition, as before
--- issue #22); a container-attached one goes back where its settings put it (Anchors.Place), out of
--- combat, since placing beside an aura engine is never done under lockdown. A drop that reaches
--- here with no drag of this container live (a stray stop) does nothing.
function Snap.Drop(container)
    if not container.dragging then return end
    Snap.EndDrag(container)
    local cfg = container:Cfg()
    local mode = cfg and cfg.attach and cfg.attach.mode
    if mode == "container" then
        if not InCombatLockdown() then container.placedAs = Anchors.Place(container) end
        return
    end
    Anchors.SavePosition(container)
end
