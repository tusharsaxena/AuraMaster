local _, NS = ...

-- modules/Anchors_Attach.lua — how a follower joins the container it is attached to: the two points,
-- the default pair Automatic takes, their classification into one of the nine sides, the seam gap,
-- the join held steady on an empty parent and the parent's engine lead taken back. Peeled out of
-- modules/Anchors.lua (AM-ATS-04), which still places the anchor (Anchors.Place), resolves what it
-- hangs from, and owns the flow a follower inherits, the drag handle and the name label.
--
-- LOAD-BEARING POSITION: before modules/Anchors.lua, which binds EDGE_PARTS, ownScale and the join
-- spec from NS.AnchorsAttach at file load. The one thing this half needs back, the room a
-- container's own strip and label take (furnitureRoom, sideRoom), is Anchors.lua's: it fills
-- AA.furnitureRoom and AA.sideRoom at its own load, and this file reads them at call time.

NS.Anchors = NS.Anchors or {}
local Anchors = NS.Anchors
local D = NS.CONTAINER_TEMPLATE

-- The file-private seam the two halves share (not an API: nothing else reads it).
local AA = {}
NS.AnchorsAttach = AA

-- ---------------------------------------------------------------------------
-- The points a follower joins its parent by (batch 11 G2, G3, G5; batch 9 AP-1, AP-2)
-- ---------------------------------------------------------------------------
-- Two ABSOLUTE points, `attach.childPoint` (this container's own, on its one-element anchor) and
-- `attach.relPoint` (its parent's, on the parent's hang target), each nil for Automatic. Any pair is
-- allowed and nothing is refused: "if it looks weird, it's on the user". Automatic takes the matching
-- half of the default pair (DefaultEdge, G3), so one explicit point leaves the other automatic.
--
-- The pair in effect is CLASSIFIED against the nine batch 9 tokens, "<side>-<align>", which name a
-- pair relative to the chain's flow:
--   after   the parent's vertical growth side (below growing down);
--   ahead   the parent's horizontal growth side (right growing right);
--   behind  the side the parent's lines start from;
-- and start, center or end along that edge (start is the edge lines start from). A pair that is one
-- of the nine under the parent's growth behaves exactly as batch 10 placed that token: its seam, the
-- chain's spread, the side push. Any other pair is FREE: placed at X/Y alone, no spread, no push, its
-- strip and label still on its own before side (G5). `attach.edge`, the stored token before v11, is
-- read by the v11 migration alone (core/Database.lua).

local C = NS.Constants

--- The nine tokens, in display order: after, ahead, behind; start, center, end within each.
Anchors.EDGES = C.ATTACH_EDGES

-- token -> { side, align }, built once so a Place parses nothing.
local EDGE_PARTS = {}
for _, token in ipairs(C.ATTACH_EDGES) do
    local side, align = token:match("^(%a+)%-(%a+)$")
    EDGE_PARTS[token] = { side, align }
end
local DEFAULT_EDGE = "after-start"

-- The nine WoW points, as a set: a stored point that is not one of them reads as Automatic.
local IS_POINT = {}
for _, point in ipairs(C.POINTS) do IS_POINT[point] = true end

--- The side and align of `token`; anything that is not one of the nine reads as "after", "start".
--- @return string side, string align
function Anchors.ParseEdge(token)
    local parts = EDGE_PARTS[token] or EDGE_PARTS[DEFAULT_EDGE]
    return parts[1], parts[2]
end

--- Whether `token` is one of the nine sides.
function Anchors.IsEdge(token)
    return EDGE_PARTS[token] ~= nil
end

--- The pair `side`/`align` gives under growth `growH`/`growV`. V0/V1 are the start and end vertical
--- edges (TOP/BOTTOM growing down), H0/H1 the horizontal ones (LEFT/RIGHT growing right). The
--- findings' design section 1 has the whole table. Load time only: EDGE_PAIRS holds every answer.
local function pairFor(growH, growV, side, align)
    local V0, V1 = "TOP", "BOTTOM"
    if growV == "up" then V0, V1 = "BOTTOM", "TOP" end
    local H0, H1 = "LEFT", "RIGHT"
    if growH == "left" then H0, H1 = "RIGHT", "LEFT" end
    if side == "after" then
        local h = (align == "start" and H0) or (align == "end" and H1) or ""
        return V0 .. h, V1 .. h
    end
    local v = (align == "start" and V0) or (align == "end" and V1) or ""
    if side == "ahead" then return v .. H0, v .. H1 end
    return v .. H1, v .. H0
end

-- EDGE_PAIRS[growH][growV][token] = { point, relativePoint }, and PAIR_EDGE[growH][growV][point]
-- [relativePoint] = token, built once, so neither a Place nor a classification builds a string. No
-- two tokens give the same pair under one growth.
local EDGE_PAIRS, PAIR_EDGE = {}, {}
for _, growH in ipairs({ "right", "left" }) do
    EDGE_PAIRS[growH], PAIR_EDGE[growH] = {}, {}
    for _, growV in ipairs({ "down", "up" }) do
        local forward, back = {}, {}
        for token, parts in pairs(EDGE_PARTS) do
            local point, rel = pairFor(growH, growV, parts[1], parts[2])
            forward[token] = { point, rel }
            back[point] = back[point] or {}
            back[point][rel] = token
        end
        EDGE_PAIRS[growH][growV], PAIR_EDGE[growH][growV] = forward, back
    end
end

--- The child's point and the parent's relative point for `token`, under layout `L`'s growth. A token
--- that is not one of the nine reads as after-start.
--- @return string point, string relativePoint
function Anchors.EdgePoints(L, token)
    local growH, growV = NS.Container.Growth(L or {})
    local pair = EDGE_PAIRS[growH][growV][EDGE_PARTS[token] and token or DEFAULT_EDGE]
    return pair[1], pair[2]
end

--- The points that attach a child to a parent laid out by `L` on the after-start side: below the
--- parent (above, growing up), on the side its lines start from. Every attachment had exactly these
--- before batch 9.
--- @return string point, string relativePoint
function Anchors.DerivedPoints(L)
    return Anchors.EdgePoints(L, DEFAULT_EDGE)
end

--- Whether container `cfg` may sit on `token`: any of the nine, always. Batch 9 refused behind to a
--- child more than one aura wide; batch 11 (G1, G5) refuses nothing, so only a token that is not one
--- of the nine answers false.
--- @return boolean
function Anchors.EdgeAllowed(_, token)
    return EDGE_PARTS[token] ~= nil
end

--- The growth container `cfg` flows by: its chain root's while it follows one, else its own. Read
--- off the stored layouts, with no copy (EffectiveLayout allocates).
--- @return string growH, string growV
local function flowGrowth(cfg)
    local root = Anchors.FlowRoot(cfg)
    return NS.Container.Growth((root or cfg).layout or D.layout)
end

--- The token of the default pair (G3) for container `cfg` under `growH`, attached to `parent`:
---   a Text child lines up with its justify: CENTER on the center, LEFT or RIGHT on whichever end
---   that is under the chain's growth (start is the side lines start from);
---   an Icons or Bars child under a Text parent justified CENTER is centered;
---   every other pair starts on the side the parent's lines start from.
--- Always an after side, so the default follows the parent's growth and flips with it.
local function defaultToken(cfg, parent, growH)
    if cfg.style == "text" then
        local j = cfg.text and cfg.text.justifyH
        if j == "CENTER" then return "after-center" end
        if j ~= "LEFT" and j ~= "RIGHT" then return DEFAULT_EDGE end
        local startSide = (growH == "left") and "RIGHT" or "LEFT"
        return (j == startSide) and DEFAULT_EDGE or "after-end"
    end
    local pt = parent and parent.style == "text" and parent.text
    if pt and pt.justifyH == "CENTER" then return "after-center" end
    return DEFAULT_EDGE
end

--- The container `cfg` is attached to by `at`, or nil.
local function parentOf(at)
    return at and NS.Database.FindContainer(tonumber(at.container))
end

--- The token of container `cfg`'s default pair (G3): what Automatic resolves to.
--- @return string token
function Anchors.DefaultEdge(cfg)
    if not cfg then return DEFAULT_EDGE end
    local growH = flowGrowth(cfg)
    return defaultToken(cfg, parentOf(cfg.attach), growH)
end

--- The pair container `cfg` joins its parent by (G2): each stored point that is one of the nine, the
--- matching half of the default pair (G3) for each that is not, and whether each is automatic, plus
--- the growth the pair is read under. Allocates nothing.
--- @return string point, string relativePoint, boolean pointAuto, boolean relAuto, string growH, string growV
function Anchors.AttachPoints(cfg)
    local at = cfg and cfg.attach
    local growH, growV = flowGrowth(cfg or {})
    local own = at and at.childPoint
    local rel = at and at.relPoint
    local ownAuto, relAuto = not IS_POINT[own], not IS_POINT[rel]
    if ownAuto or relAuto then
        local pair = EDGE_PAIRS[growH][growV][defaultToken(cfg or {}, parentOf(at), growH)]
        if ownAuto then own = pair[1] end
        if relAuto then rel = pair[2] end
    end
    return own, rel, ownAuto, relAuto, growH, growV
end

--- The pair Automatic gives container `cfg` (G3), whatever is picked: what each dropdown's Automatic
--- entry names, so a picked row still says what choosing Automatic would do. Allocates nothing.
--- @return string point, string relativePoint
function Anchors.AutoPoints(cfg)
    local c = cfg or {}
    local growH, growV = flowGrowth(c)
    local pair = EDGE_PAIRS[growH][growV][defaultToken(c, parentOf(c.attach), growH)]
    return pair[1], pair[2]
end

--- The token the pair in effect is under the chain's growth, or nil when it is free (G5).
--- Allocates nothing.
--- @return string|nil
function Anchors.AttachEdge(cfg)
    local point, rel, _, _, growH, growV = Anchors.AttachPoints(cfg)
    local row = PAIR_EDGE[growH][growV][point]
    return row and row[rel]
end

--- The offset that leaves one of the child's own gaps between its parent's block and itself, for a
--- child laid out by `L` (its effective layout) on `side` (after when nil). The child's own values,
--- because SetPoint offsets are in the positioned frame's scale, which is the child's (Container:Apply
--- sets it on the anchor), so the seam matches its inner gaps under any Scale. Never negative.
---   after          the gap it leaves between consecutive elements along the chain: its spacing when
---                  it fills columns, its line spacing when it fills rows (SS-1); downward growing
---                  down, upward growing up, so a chain growing up never overlaps;
---   ahead, behind  its gap across: its spacing when it fills rows, its line spacing (between
---                  columns) when it fills columns; toward the horizontal growth for ahead, away
---                  for behind.
--- @return number x, number y
function Anchors.SeamOffset(L, side)
    if side == "ahead" or side == "behind" then
        local gap = (L.axis == "horizontal") and L.spacing or L.lineSpacing
        gap = math.max(0, tonumber(gap) or 0)
        if (L.growH == "left") == (side == "ahead") then gap = -gap end
        return gap, 0
    end
    local gap = (L.axis == "vertical") and L.spacing or L.lineSpacing
    gap = math.max(0, tonumber(gap) or 0)
    return 0, (L.growV == "up") and gap or -gap
end

--- A container's own scale, which its anchor's SetPoint offsets are in. The Master scale multiplies
--- every container alike (Container:Apply), so it cancels between a parent and its follower.
local function ownScale(cfg)
    return math.max(0.1, tonumber(cfg.layout and cfg.layout.scale) or 1)
end

--- The seam's y offset `gy`, moved on along the chain's growth by `room` (in the child's own units).
local function alongGrowth(L, gy, room)
    if room <= 0 then return gy end
    return (L.growV == "up") and gy + room or gy - room
end

--- The room along the chain a follower on `side` takes past its seam (batch 10 F2, F4): an after
--- follower spreads the chain by its OWN before-side furniture (its strip while it shows, its label
--- while it shows), which sits between its parent's block and its own, and records it on `container`
--- so a visibility pass that shows or hides either re-places it (Anchors.RefreshSeam). An ahead
--- follower moves past its parent's label while it shows and its strip while that runs over its
--- column (sideRoom, in the parent's units until converted here). A behind follower takes none: the parent's
--- strip runs away from it.
local function seamRoom(container, cfg, side, target)
    if side == "after" then
        local room = AA.furnitureRoom(container)
        container.placedRoom = room
        return room
    end
    if side == "ahead" and target then return AA.sideRoom(target) / ownScale(cfg) end
    return 0
end

-- ---------------------------------------------------------------------------
-- A steady join on an empty parent (batch 11 T9)
-- ---------------------------------------------------------------------------
-- A follower hangs from its parent's ENGINE whenever the parent is locked, in combat or not
-- predicted empty (HangMode), and an empty engine holds a 1x1 rect at its START corner (since the
-- engine lead, the unit just behind it: engineLead, below).
-- A relative point on the parent's center or end side then lands on that corner: the owner's chain of
-- bars growing up, joined by centered points, shifted sideways by half a bar whenever the middle
-- container had no aura. So on each axis where the parent is exactly ONE element across, the relative
-- point is moved to the parent's start side on that axis and the difference is added as an offset,
-- worked out from the parent's own config (its one-element size and scale), never from the engine's
-- geometry, which is secret. There the slot and the preview block are one element across as well, so
-- the result is the same in every hang mode, and steady when the engine empties.
-- The axis a classified join runs along (after: vertical; ahead, behind: horizontal) is left alone,
-- so an empty parent still closes the chain up along it, since the engine lead exactly to its start.
-- An axis on which the parent is more than one element across is left alone too: its center moves
-- with its aura count.

-- POINT_V[point], POINT_H[point]: a point's vertical and horizontal parts ("" for the middle), and
-- JOIN_POINT[v][h] the point back, built once so a Place builds no string.
local POINT_V, POINT_H, JOIN_POINT = {}, {}, {}
for _, point in ipairs(C.POINTS) do
    local v = point:match("^TOP") or point:match("^BOTTOM") or ""
    local h = point:match("LEFT$") or point:match("RIGHT$") or ""
    POINT_V[point], POINT_H[point] = v, h
    JOIN_POINT[v] = JOIN_POINT[v] or {}
    JOIN_POINT[v][h] = point
end

-- The axis each classified side's join runs along.
local JOIN_AXIS = { after = "v", ahead = "h", behind = "h" }

--- Whether container `pcfg` is exactly one element across horizontally and vertically: it fills
--- columns (or rows) with no per-line limit, or rows (or columns) of one. Its axis is its chain's,
--- its per-line count its own. Allocates nothing.
--- @return boolean acrossH, boolean acrossV
local function oneAcross(pcfg)
    local root = Anchors.FlowRoot(pcfg)
    local L = (root or pcfg).layout or D.layout
    local vertical = (L.axis == "vertical")
    local perLine = tonumber(pcfg.layout and pcfg.layout.perLine) or 0
    local single, unlimited = (perLine == 1), (perLine <= 0)
    return (vertical and unlimited) or (not vertical and single),
        (not vertical and unlimited) or (vertical and single)
end

--- Move part `part` of a relative point to `start` (the parent's start side on that axis), and the
--- offset that keeps it where it was on a parent `size` across: half of it from the center, all of
--- it from the end, toward the growth (`forward` +1 or -1). A part already on the start side stays.
--- @return string part, number offset
local function toStart(part, start, size, forward)
    if part == start then return part, 0 end
    local frac = (part == "") and 0.5 or 1
    return start, frac * size * forward
end

--- The relative point `rel` container `cfg` joins its parent `pcfg` by, moved onto the parent's
--- start side on each axis the parent is one element across and the join does not run along
--- (`joinAxis`, nil for a free pair), with the offset that keeps it in place, in the child's scale.
--- @return string relativePoint, number dx, number dy
local function steadyRelative(rel, joinAxis, pcfg, cfg, growH, growV)
    local acrossH, acrossV = oneAcross(pcfg)
    acrossH, acrossV = acrossH and joinAxis ~= "h", acrossV and joinAxis ~= "v"
    if not (acrossH or acrossV) then return rel, 0, 0 end
    local v, h = POINT_V[rel], POINT_H[rel]
    local w, ht = NS.Style.ElementSize(pcfg)
    local k = ownScale(pcfg) / ownScale(cfg)
    local dx, dy = 0, 0
    if acrossH then
        h, dx = toStart(h, (growH == "left") and "RIGHT" or "LEFT", w * k, (growH == "left") and -1 or 1)
    end
    if acrossV then
        v, dy = toStart(v, (growV == "up") and "BOTTOM" or "TOP", ht * k, (growV == "up") and 1 or -1)
    end
    return JOIN_POINT[v][h], dx, dy
end

-- How far a relative point on a parent's ENGINE sits from where the parent's block starts, on one
-- axis (modules/Container.lua's ENGINE_LEAD): the engine is pinned one unit behind its
-- anchor's start corner and pads its start sides by that unit, so a start part is a whole unit short
-- and a middle part half of one; an end part is exact (the engine's far edge is start + content, and
-- exactly the start while it is empty, which is the point: an empty link adds nothing along a chain).

--- The fraction of the lead part `part` takes back: all on the start side `start`, half in the middle.
local function leadFraction(part, start)
    if part == start then return 1 end
    return (part == "") and 0.5 or 0
end

--- The offset that takes the parent's engine lead back for relative point `rel`, toward the growth
--- of the parent `pcfg` (its engine's), in the child's scale. Allocates nothing.
--- @return number dx, number dy
local function engineLead(rel, pcfg, cfg)
    local growH, growV = flowGrowth(pcfg)
    local lead = NS.Container.ENGINE_LEAD * ownScale(pcfg) / ownScale(cfg)
    local fx = leadFraction(POINT_H[rel], (growH == "left") and "RIGHT" or "LEFT")
    local fy = leadFraction(POINT_V[rel], (growV == "up") and "BOTTOM" or "TOP")
    return fx * lead * ((growH == "left") and -1 or 1), fy * lead * ((growV == "up") and 1 or -1)
end

--- The points and offsets container `cfg` attaches with. Attached to a container: the points in
--- effect (AttachPoints, G2, G3), the relative one held steady on an empty parent (steadyRelative,
--- T9), and, hung from the parent's engine (`onEngine`), the engine's lead taken back
--- (engineLead). A pair that is one of the nine sides (AttachEdge) takes one of its own gaps across the seam
--- with the stored X/Y on top as a nudge (SS-1, SS-2, AP-2), moved on along the chain by the
--- furniture in the way (seamRoom, batch 10 F2, F4); a free pair is placed at X/Y alone (G5). The
--- classification reads the points in effect, never the steadied one. Attached to a named frame: the
--- stored points and offsets as they are.
--- @return string point, string relativePoint, number x, number y
local function attachSpec(container, cfg, at, mode, target, onEngine)
    local x, y = tonumber(at.x) or 0, tonumber(at.y) or 0
    if mode == "container" then
        local point, rel, _, _, growH, growV = Anchors.AttachPoints(cfg)
        local edge = Anchors.AttachEdge(cfg)
        local side = edge and EDGE_PARTS[edge][1]
        local pcfg = target and target:Cfg()
        local sx, sy = 0, 0
        if pcfg then rel, sx, sy = steadyRelative(rel, JOIN_AXIS[side], pcfg, cfg, growH, growV) end
        if pcfg and onEngine then
            local lx, ly = engineLead(rel, pcfg, cfg)
            sx, sy = sx + lx, sy + ly
        end
        if not edge then return point, rel, x + sx, y + sy end
        local L = Anchors.EffectiveLayout(cfg) or {}
        local gx, gy = Anchors.SeamOffset(L, side)
        gy = alongGrowth(L, gy, seamRoom(container, cfg, side, target))
        return point, rel, gx + x + sx, gy + y + sy
    end
    return at.point or D.attach.point, at.relativePoint or D.attach.relativePoint, x, y
end

AA.EDGE_PARTS = EDGE_PARTS
AA.ownScale = ownScale
AA.Spec = attachSpec
