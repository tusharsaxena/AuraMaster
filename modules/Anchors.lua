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
--              that anchors to an aura container (whose layout scripts are forbidden to addons).
--              While that container previews it hangs from its preview extent instead, and while
--              it is unlocked and predicted empty from its one-element anchor (Anchors.HangMode);
--   frame      any named frame — a unit frame, another add-on's bar — re-resolved when the add-on
--              that creates it loads, and again when combat ends (Anchors.ResolvePending).
-- A chain that would loop back on itself, a target that does not exist, or a frame that is forbidden
-- falls back to the screen position rather than to nowhere, and says so in the [Anchor] debug trace.

NS.Anchors = NS.Anchors or {}
local Anchors = NS.Anchors
local D = NS.CONTAINER_TEMPLATE

-- Frame-mode containers whose frame did not exist yet, by container id.
local pending = {}

-- The room a container's own strip and label take on its before side, and the room its parent's
-- take that a side follower clears (batch 10 F2, F4), defined with the strip below.
local furnitureRoom, sideRoom

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
    anchor:SetPoint(pos.point or D.position.point, UIParent,
        pos.relativePoint or pos.point or D.position.relativePoint,
        tonumber(pos.x) or 0, tonumber(pos.y) or 0)
end

--- Whether `name` names a frame that EXISTS but is forbidden to add-ons: never a target, now or after
--- any add-on loads.
local function isForbidden(name)
    local f = _G[name]
    return type(f) == "table" and type(f.IsForbidden) == "function" and f:IsForbidden() and true or false
end

--- The frame container `container` attaches to and the mode that names it, or nil when its setting
--- names nothing usable: a missing or looping container, or a frame that is absent or forbidden. A
--- named frame that simply does not exist YET is remembered, to be retried when an add-on loads; a
--- forbidden one is not, since no add-on loading makes it a target.
--- The live container `container`'s attach settings `at` name, or nil when it cannot be used: missing,
--- itself, or closing a loop.
local function targetContainer(container, at)
    local targetId = tonumber(at.container)
    local target = targetId and NS.ContainerManager and NS.ContainerManager.instances[targetId]
    if target and targetId ~= container.id and not Anchors.WouldCycle(container.id, targetId) then
        return target
    end
    return nil
end

--- What a container attached to container `t` hangs from, as ContainerClass:ApplyVisibility last
--- recorded it (`t.hangMode`):
---   preview  test mode: its preview extent, since its engine is disabled and keeps a stale rect (L-4);
---   slot     unlocked, not previewing and predicted EMPTY (modules/EmptyWatch.lua, batch 9 HG-1):
---            its anchor, exactly one element, the rect its placeholder outline marks. Its engine
---            holds a 1x1 provisional rect while it has no aura, so a follower hung from it sat
---            about 5px under the parent's top, and an empty chain collapsed onto itself (#9);
---   engine   anything else (locked, or unlocked holding auras or not knowable): the engine, so a
---            follower grows and shrinks with its auras.
--- Before its first visibility pass a container answers from its preview state.
--- @return string  "preview" | "slot" | "engine"
function Anchors.HangMode(t)
    return t.hangMode or (t.previewShown and "preview") or "engine"
end

--- The frame to hang from, the mode that names it and, for a container target, the live container.
local function targetFor(container, at)
    if at.mode == "container" then
        local target = targetContainer(container, at)
        if target then
            local mode = Anchors.HangMode(target)
            if mode == "preview" and target.previewExtent then return target.previewExtent, "container", target end
            if mode == "slot" then return target.anchor, "container", target end
            return target.engine or target.anchor, "container", target
        end
    elseif at.mode == "frame" then
        local f = Anchors.ResolveFrame(at.frame)
        if f then return f, "frame" end
        if at.frame and at.frame ~= "" and not isForbidden(at.frame) then
            pending[container.id] = true
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Inherited flow (L-6)
-- ---------------------------------------------------------------------------
-- A container attached to ANOTHER container continues that container's flow: its fill axis and both
-- growth directions are its chain root's, and it joins the parent by the points in effect
-- (Anchors.AttachPoints: below it by default), one of its own gaps past the parent's block when the
-- pair is one of the nine sides (Anchors.SeamOffset, SS-1).
-- Its offsets nudge on top of that gap; its per-line count and spacing stay its own. Nothing is
-- written: the stored values stay as they are, so a detach restores them at the next apply. A
-- frame-attached or screen container inherits nothing — a named frame has no flow to continue.

local FLOW_KEYS = { "axis", "growH", "growV" }

-- The writes that change what a follower inherits or where its chain leads, so they re-apply every
-- container following the one written (Anchors.Followers; modules/ContainerManager.lua).
local FLOW_PATHS = {
    ["container.layout"] = true,
    ["container.layout.axis"] = true,
    ["container.layout.growH"] = true,
    ["container.layout.growV"] = true,
    ["container.attach.mode"] = true,
    ["container.attach.container"] = true,
    -- The two points (batch 11 G2), and what picks the automatic ones (G3): a parent's style and
    -- text justify choose its followers' default align.
    ["container.attach.childPoint"] = true,
    ["container.attach.relPoint"] = true,
    ["container.style"] = true,
    ["container.text.justifyH"] = true,
}

--- The container whose flow `cfg` follows, or nil when it follows none: not attached to a container,
--- or attached to one Place cannot use (missing, itself, a loop), which puts it on the screen. The
--- walk goes up the chain while each target is itself container-attached, and stops at the first
--- link that leads nowhere, because that container sits on the screen with its own flow.
function Anchors.FlowRoot(cfg)
    local at = cfg and cfg.attach
    if not (at and at.mode == "container") then return nil end
    local id = tonumber(at.container)
    if id == nil or id == cfg.id or Anchors.WouldCycle(cfg.id, id) then return nil end
    local root, hops = NS.Database.FindContainer(id), 0
    while root and hops < 64 do
        local up = root.attach
        local nextId = up and up.mode == "container" and tonumber(up.container)
        local nextCfg = nextId and NS.Database.FindContainer(nextId)
        if not nextCfg then return root end
        root, hops = nextCfg, hops + 1
    end
    return root
end

--- The layout `cfg` actually flows by. For a container that follows another it is a shallow copy of
--- its own layout with the fill axis and both growth directions taken from its chain root; for any
--- other it is `cfg.layout` itself, with no allocation. Every flow reader goes through this:
--- Container.FlowSettings, Preview.Offset, the handle's side and the anchor's clamp.
--- @return table|nil
function Anchors.EffectiveLayout(cfg)
    local root = Anchors.FlowRoot(cfg)
    if not root then return cfg.layout end
    local out = {}
    for k, v in pairs(cfg.layout or {}) do out[k] = v end
    local from = root.layout or {}
    for _, k in ipairs(FLOW_KEYS) do out[k] = from[k] end
    return out
end

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

--- Whether container `c`'s chain of container attachments passes through container `id`.
local function follows(c, id)
    local at, hops = c.attach, 0
    while at and at.mode == "container" and hops < 64 do
        local targetId = tonumber(at.container)
        if targetId == id then return true end
        local nextCfg = targetId and NS.Database.FindContainer(targetId)
        at, hops = nextCfg and nextCfg.attach, hops + 1
    end
    return false
end

--- Every container whose chain passes through container `id`, directly or further down: the ones a
--- change to `id`'s flow or attachment moves.
--- @return table  container ids
function Anchors.Followers(id)
    local out = {}
    for _, c in ipairs(NS.Database.GetContainers()) do
        if c.id ~= id and follows(c, id) then
            out[#out + 1] = c.id
        end
    end
    return out
end

--- The container `childCfg` could attach to by id `targetId`, or nil: none, itself, missing, a loop.
local function attachableTarget(childCfg, targetId)
    local id = tonumber(targetId)
    if not (childCfg and id) or id == 0 or id == childCfg.id then return nil end
    local target = NS.Database.FindContainer(id)
    if not target or Anchors.WouldCycle(childCfg.id, id) then return nil end
    return target
end

--- The FLOW_KEYS on which layouts `own` and `from` differ, in order, each read over the template.
local function flowKeysDiffering(own, from)
    local base = D.layout or {}
    local keys = {}
    for _, k in ipairs(FLOW_KEYS) do
        if (own[k] or base[k]) ~= (from[k] or base[k]) then
            local n = #keys
            keys[n + 1] = k
        end
    end
    return keys
end

--- What attaching container `childCfg` to container `targetId` would change about how it flows
--- (batch 9 GC-1, E3): nil when nothing would (no usable target: none, itself, missing, a loop; or
--- the same axis and growth), else { root = the chain root it would follow, keys = the FLOW_KEYS that
--- differ, in order, followers = how many containers re-flow with it }. The root is the target's
--- own flow root, or the target itself when it follows none. Compared with the child's own STORED
--- flow, which an attachment never writes, so a detach brings it back. Reads only.
--- @return table|nil
function Anchors.FlowChangeOnAttach(childCfg, targetId)
    local target = attachableTarget(childCfg, targetId)
    if not target then return nil end
    local root = Anchors.FlowRoot(target) or target
    local keys = flowKeysDiffering(childCfg.layout or {}, root.layout or {})
    local changed = #keys
    if changed == 0 then return nil end
    local followers = Anchors.Followers(childCfg.id)
    local count = #followers
    return { root = root, keys = keys, followers = count }
end

--- Whether a write to `path` changes what a container's followers inherit or where they sit.
function Anchors.MovesFollowers(path)
    return FLOW_PATHS[path] == true
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
        local room = furnitureRoom(container)
        container.placedRoom = room
        return room
    end
    if side == "ahead" and target then return sideRoom(target) / ownScale(cfg) end
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
    container.placedRoom = nil   -- set again by an after-side placement (seamRoom)

    local at = cfg.attach or {}
    local target, mode, owner = targetFor(container, at)
    if target then
        local onEngine = owner ~= nil and target == owner.engine
        local point, relativePoint, x, y = attachSpec(container, cfg, at, mode, owner, onEngine)
        local ok = pcall(anchor.SetPoint, anchor, point, target, relativePoint, x, y)
        if ok then return mode end
        anchor:ClearAllPoints()
    end
    if at.mode and at.mode ~= "screen" and NS.Debug then
        NS.Debug("Anchor", "container %s: %s target unavailable, screen fallback", container.id, at.mode)
    end
    toScreen(anchor, cfg)
    return "screen"
end

--- Re-place container `container` itself once the room its own strip and label take on its before
--- side (furnitureRoom) differs from what its after-side seam was placed with (batch 10 F2): an
--- unlock shows its strip, a lock hides it, a label turns on. Called on every visibility pass after
--- the strip and the label are shown or hidden, so a pass that changes nothing re-places nothing and
--- allocates nothing. Layout work beside an aura engine, so never under lockdown: the first pass
--- after combat catches up.
function Anchors.RefreshSeam(container)
    local room = container.placedRoom
    if room == nil or room == furnitureRoom(container) or InCombatLockdown() then return end
    container.placedAs = Anchors.Place(container)
end

--- Re-place every container attached to `target` once what they hang from has changed since they
--- were last placed: its hang mode (Anchors.HangMode; test mode, lock, unlock and the empty
--- prediction: L-4, HG-1) or the room its strip and label take over a side follower's column
--- (sideRoom, batch 10 F4). Called on every visibility pass
--- (ContainerClass:ApplyVisibility), so a pass that changes nothing re-places nothing. Layout work
--- beside an aura engine, so never under lockdown: the last placement stands, unrecorded, and the
--- first pass after combat catches up.
function Anchors.PlaceAttached(target)
    local mode, room = Anchors.HangMode(target), sideRoom(target)
    if (target.attachedPlacedFor == mode and target.attachedPlacedRoom == room) or InCombatLockdown() then
        return
    end
    target.attachedPlacedFor, target.attachedPlacedRoom = mode, room
    local CM = NS.ContainerManager
    if not CM then return end
    for _, inst in pairs(CM.instances) do
        local cfg = inst ~= target and inst:Cfg()
        local at = cfg and cfg.attach
        if at and at.mode == "container" and tonumber(at.container) == target.id then
            inst.placedAs = Anchors.Place(inst)
        end
    end
end

--- Re-place every container whose frame target did not exist when it was placed. Called whenever an
--- add-on loads, since that is when a new named frame can appear, and when combat ends, since an
--- add-on that loaded during combat could not be resolved then.
function Anchors.ResolvePending()
    if InCombatLockdown() then
        if NS.Debug then NS.Debug("Anchor", "pending resolve skipped under lockdown; retried when combat ends") end
        return
    end
    local CM = NS.ContainerManager
    if not CM then return end
    for id in pairs(pending) do
        local inst = CM.instances[id]
        if inst then Anchors.Place(inst) else pending[id] = nil end
    end
end

--- Which containers are still waiting on their frame (a test seam: tests/test_anchors.lua).
function Anchors.Pending()
    local out = {}
    for id in pairs(pending) do
        out[#out + 1] = id
    end
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
    -- A screen-attached anchor holds nothing secret, but a read is guarded anyway (feedback E): a
    -- secret offset would raise in round(), and storing one would poison the saved position. `point`
    -- is checked before it is truth-tested below, so a secret point is never boolean-tested either.
    local S = NS.Secrets
    if not (S.CanAccess(point) and S.CanAccess(relPoint) and S.CanAccess(x) and S.CanAccess(y)) then
        if NS.Debug then NS.Debug("Anchor", "container %s: position reads secret, not saved", container.id) end
        return
    end
    if not point then return end
    NS.SetByPath("container.position",
        { point = point, relativePoint = relPoint or point, x = round(x), y = round(y) }, container.id)
end

-- ---------------------------------------------------------------------------
-- The drag handle
-- ---------------------------------------------------------------------------

-- A labeled strip OUTSIDE the anchor, on the side the auras do not grow into: a dark fill with a 1px
-- gold edge, a gold label, and inside its far end the media catalog's close mark (an X that disables
-- the container, batch 8 CX-3) immediately left of its help mark. Outside, because
-- the anchor is exactly one element in size and the first element sits on it: a handle covering the
-- anchor covered the first bar or icon. Nothing moves to make room for it — the anchor, the engine
-- (which may never be re-anchored once it holds groups) and the preview stay where they are.
-- The strip is LibKa0s-Widgets-1.0's (libs/LibKa0s/WidgetsDragHandle.lua, minor 3): the fill, the
-- edge, the label, the help and close marks with their own art fallbacks, the tooltips, the drag
-- scripts and the width arithmetic are the library's; what the X DOES (disableContainer) is ours. ConsumableMaster drew the same strip
-- over its macro bar, which is why the widget exists. Resolved at file load like every other library
-- seam here; absent, Anchors.BuildHandle answers nil and a container simply has no handle, which
-- Anchors.UpdateHandle and Container:Park already tolerate.
local KW   = LibStub and LibStub("LibKa0s-Widgets-1.0", true)
local DRAG = KW and KW.DRAG_HANDLE

-- The strip's height, the gap it leaves and what it keeps clear each side of its label are the
-- widget's numbers (`lib.DRAG_HANDLE`), read through DRAG rather than copied back here: a copy is a
-- second set to keep in step. This number is OURS, because nothing in the widget knows what an aura
-- engine stacks above its anchor.
local HANDLE_LEVEL = 50   -- how far above its anchor the strip sits: over every element it holds

-- The strip's height and gap as the name label (batch 8 NL-2) reads them: the label takes the strip's
-- spot and is as tall as the strip, and it still draws on a build without the widget, so the widget's
-- own figures stand in when it is missing.
local STRIP_H   = DRAG and DRAG.HEIGHT or 18
local STRIP_GAP = DRAG and DRAG.GAP or 2

--- Right-click (the strip or its "?"): the Containers page, with THIS container selected in its band
--- (feedback #9). Under combat lockdown the open is refused with options-ui-§2's gray line, and the
--- selection is left where it was: a refused click moves nothing. NS.OpenOptionsPage is the one
--- panel-open seam that carries the refusal; the panels are redrawn first, so a Containers page built
--- earlier shows the new subject when it opens.
local function openSettings(container)
    if not InCombatLockdown() then
        if NS.State then NS.State.SetActiveContainer(container.id) end
        if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
    end
    if NS.OpenOptionsPage then NS.OpenOptionsPage("containers") end
end

--- The join the strip's tooltip names (SEP-2) for a container placed on another container: the
--- parent's point it joins (AttachPoints), and the parent's name. Nil for any other
--- placement (a frame, or a target it could not use), which keeps the general attached line.
--- @return string|nil
function Anchors.JoinText(container, cfg)
    if container.placedAs ~= "container" or cfg.attach.mode ~= "container" then return nil end
    local parent = NS.Database.FindContainer(tonumber(cfg.attach.container))
    if not parent then return nil end
    local _, rel = Anchors.AttachPoints(cfg)
    return NS.L["Joined to the %s of '%s'. Change the anchor points on Layout > Anchor."]:format(NS.L[C.POINT_LABELS[rel]], tostring(parent.name or ""))
end

--- The tooltip descriptor the strip and its help mark share: the container's name, how to use the
--- handle, and — for an attached container only — where its offsets are set.
---
--- THE LINES ARE FUNCTIONS because the widget calls them on EVERY hover rather than capturing them
--- when the handle is built: a renamed container and a container that has just been attached or
--- detached both show through without rebuilding anything. The attached line carries its own gold
--- through the `{ entry, r, g, b }` shape, so it stays the color it is today instead of taking the
--- body band's white.
---
--- OWNED BY UIParent AT THE CURSOR (`tooltipOwner = "cursor"`), never by the hovered frame. The
--- anchor inherits DisableUntrustedLayoutScriptsTemplate (modules/Container.lua), and that
--- restriction reaches every frame anchored under it: the strip and the mark. GameTooltip does not
--- inherit the template, so the client refuses SetOwner on either ("Anchoring disallowed as dependent
--- object would inherit forbidden aspects: UntrustedLayoutScriptExecution"). ANCHOR_CURSOR depends on
--- nothing under the anchor.
local function tooltipSpec(container)
    -- How to use the strip: drag it, or, attached, why a drag does nothing (canDrag) and what it
    -- follows, by the parent container's name or the frame's (the owner, 2026-09-26).
    local function howTo()
        local cfg = container:Cfg()
        local at = cfg and cfg.attach
        local target
        if at and at.mode == "container" then
            local parent = NS.Database.FindContainer(tonumber(at.container))
            target = parent and parent.name
        elseif at and at.mode == "frame" then
            target = at.frame
        end
        if not (target and target ~= "") then return NS.L["Drag to move. Right-click for settings."] end
        return NS.L["Anchored to '%s', so it cannot be dragged. Right-click for settings."]:format(tostring(target))
    end
    local function attached()
        local cfg = container:Cfg()
        if not (cfg and cfg.attach and cfg.attach.mode ~= "screen") then return nil end
        return Anchors.JoinText(container, cfg) or NS.L["Attached — set its offsets on the Layout page."]
    end
    return {
        title = function()
            local cfg = container:Cfg()
            return cfg and cfg.name or NS.L["Container"]
        end,
        body = {
            howTo,
            { attached, 1, 0.82, 0 },
        },
    }
end

--- The close mark's left click (batch 8 CX-3): disable THIS container through the one write seam,
--- with no confirmation, and say in chat which one and how to bring it back. The row's `visibility`
--- effect does the rest exactly as the Enabled checkbox does: the visibility pass hides the preview,
--- the outline and this strip and re-places its followers, and none of that touches the protected
--- anchor, so it is combat-legal. A refused write prints its reason and nothing else.
local function disableContainer(container)
    local cfg = container:Cfg()
    local name = cfg and cfg.name or NS.L["Container"]
    local ok, err = NS.SetByPath("container.enabled", false, container.id)
    if not ok then
        if err then NS.Print(err) end
        return
    end
    NS.Printf(NS.L["%s disabled. Turn Enabled back on for it on the Containers page to bring it back."], name)
end

--- The close mark's own tooltip: the container's name (a function, read on every hover, so a rename
--- shows through) and what the click does. Cursor-owned like the strip's, through the same
--- `tooltipOwner` (see tooltipSpec).
local function closeTooltipSpec(container)
    return {
        title = function()
            local cfg = container:Cfg()
            return cfg and cfg.name or NS.L["Container"]
        end,
        body = {
            NS.L["Click to disable this container. Its settings are kept; turn Enabled back on for it on the Containers page to bring it back."],
        },
    }
end

--- Asked by the widget at every OnDragStart. Only a screen-attached container moves by dragging; an
--- attached one follows its target, and its offsets are set on the Layout page. Never mid-combat:
--- the anchor parents an aura engine.
local function canDrag(container)
    local cfg = container:Cfg()
    return (cfg and cfg.attach and cfg.attach.mode == "screen" and not InCombatLockdown()) and true or false
end

--- The handle's label, in its three parts: the container's name, a warm gray
--- (C.ATTACHED_NAME_COLOR) while it is attached to another container or a named frame, the sign that
--- it follows that and cannot be dragged on its own (canDrag; the owner, 2026-09-26); and while test
--- mode is on an orange TEST tag after it (feedback #8), so the placeholders on screen read as
--- placeholders. Apart, so a strip too narrow for the whole shortens the name alone (stripLabel).
--- @return string open, string name, string close, string tag  open and close wrap the name's color
local function handleParts(cfg)
    local name = cfg.name or ""
    local open, close, tag = "", "", ""
    local mode = cfg.attach and cfg.attach.mode
    if mode == "container" or mode == "frame" then
        open, close = "|c" .. NS.Constants.ATTACHED_NAME_COLOR, "|r"
    end
    if NS.State and NS.State.testMode then
        tag = ("  |c%s%s|r"):format(NS.Constants.TEST_TAG_COLOR, NS.L["TEST"])
    end
    return open, name, close, tag
end

--- The handle's whole label. It sits ABOVE BuildHandle because the strip is born with its text —
--- `label` is the widget's one required string.
local function handleText(cfg)
    if not cfg then return "" end
    local open, name, close, tag = handleParts(cfg)
    return open .. name .. close .. tag
end

--- Build the handle a player drags a container by: LibKa0s-Widgets-1.0's strip, wearing this
--- addon's strings, art and callbacks. Shown only while unlocked; it sits outside the anchor
--- (Anchors.UpdateHandle places it), so no element is covered and nothing moves to make room. The
--- one exception is the screen edge: while the handle shows, the anchor's clamp rect takes the strip
--- in (clampToHandle), so a container flush with the edge on the handle's side is pushed in by the
--- strip while unlocked and returns when locked. Its stored position does not change.
---
--- THE WIDGET BUILDS A PLAIN BUTTON, never a BackdropTemplate, and paints its edge with the painter
--- we hand it: under an anchor attached to another frame or container the strip's size can read
--- secret, and the Backdrop does arithmetic on that size on every SetBackdrop and every resize
--- (docs/midnight-quirks.md, "A backdrop on an engine button reads a secret size"). `number` hands it
--- NS.Secrets.NumberOr for the same reason, so a measured width that reads secret falls back to the
--- element instead of raising. The widget hides the strip at birth, exactly as this file did.
---
--- THE LEVEL IS OURS and is set after the build: the widget never places, sizes or shows the strip.
--- @return table|nil  nil without LibKa0s-Widgets-1.0, and in a client that cannot make the frame
function Anchors.BuildHandle(container)
    if not (KW and KW.DragHandle) then return nil end
    local anchor = container.anchor
    local handle = KW.DragHandle(anchor, {
        label        = handleText(container:Cfg()),
        moveFrame    = anchor,
        helpIcon     = NS.Icon and NS.Icon("help") or nil,
        closeIcon    = NS.Icon and NS.Icon("close") or nil,
        onClose      = function() disableContainer(container) end,
        closeTooltip = closeTooltipSpec(container),
        canDrag      = function() return canDrag(container) end,
        onDragStop   = function() Anchors.SavePosition(container) end,
        onRightClick = function() openSettings(container) end,
        tooltip      = tooltipSpec(container),
        tooltipOwner = "cursor",
        edge         = NS.Style.DrawEdge,
        number       = NS.Secrets.NumberOr,
    })
    if not handle then return nil end
    handle:SetFrameLevel(NS.Secrets.NumberOr(anchor:GetFrameLevel(), 0) + HANDLE_LEVEL)
    return handle
end

--- A frame's level, READ GUARDED (feedback E): an anchor attached to an engine container, or to a
--- frame anchored to one, can answer its level secret (FrameLevel is a secret aspect), and
--- arithmetic on a secret raises. An unreadable level is the one Container:Apply set from the stored
--- `layout.level`.
local function levelOf(frame, cfg)
    local stored = tonumber(cfg and cfg.layout and cfg.layout.level) or D.layout.level
    return NS.Secrets.NumberOr(frame:GetFrameLevel(), stored)
end

--- Put the strip on the side the auras do not grow into: above the anchor when they grow down,
--- below when they grow up, its edge lined up with the edge they start from so it runs along the
--- first line. As wide as one element, its name shortened to fit (stripLabel, batch 11 T11), or its
--- natural width on an element too narrow for the marks and a readable label. The
--- growth is the effective one: an attached container's auras grow the way its parent's do (L-6).
--- A container attached to another puts it there too, in its own column (batch 10 F1): its seam
--- makes the room (seamRoom).
--- The strip's frame level, set wherever it is placed, since the first apply sets its anchor's level
--- after BuildHandle ran: HANDLE_LEVEL above its anchor. A container attached to another also clears
--- that one's placeholders (L-4), which its strip can still meet where the two blocks sit side by
--- side; every placeholder, inner frames included, stacks under that container's own strip,
--- HANDLE_LEVEL above its anchor.
--- Levels order frames within one strata only: a target in a higher strata still draws on top.
--- Every level is read through levelOf (feedback E).
local function handleLevel(container, cfg)
    local level = levelOf(container.anchor, cfg) + HANDLE_LEVEL
    local at = cfg.attach
    local target = at and at.mode == "container" and targetContainer(container, at)
    if target then
        level = math.max(level, levelOf(target.anchor, target:Cfg()) + HANDLE_LEVEL + 1)
    end
    return level
end

-- ---------------------------------------------------------------------------
-- The strip and the label in each container's own column (batch 10 F1-F5)
-- ---------------------------------------------------------------------------
-- Every container's strip and name label sit on its BEFORE side, the side its auras start from
-- (above its block growing down, below it growing up), in one order: the strip outermost, then the
-- label, then the block. A root, an after follower and a side follower alike, so a chain reads
-- strip, block, strip, block down one column (the owner's mockup). This replaces batch 9's SEP-3,
-- which put an after follower's strip beside the column, behind or ahead of its first element or
-- inside its top band. An after follower makes the room itself: its seam is moved on along the chain
-- by its own furniture (seamRoom, F2). A side follower's parent sits beside it, so it needs no
-- spread, but it is moved on past its parent's label while it shows and its strip while that runs
-- over its column (sideRoom, F4).

--- The side container `cfg` sits on in its chain, with no allocation: nil for a container that
--- follows none, "free" for a pair that is none of the nine (G5), else its token's side.
local function ownSide(cfg)
    if not (cfg and Anchors.FlowRoot(cfg)) then return nil end
    local edge = Anchors.AttachEdge(cfg)
    return edge and EDGE_PARTS[edge][1] or "free"
end

--- The room, in container `c`'s own units, that its strip and label take on its before side: one
--- strip row (the strip's height and its gap) for the strip while it shows, one for the label while
--- it shows. The strip and the label are frames under its anchor, in its scale, so no conversion.
furnitureRoom = function(c)
    local rows = ((DRAG and c.stripShown) and 1 or 0) + (c.labelShown and 1 or 0)
    return rows * (STRIP_H + STRIP_GAP)
end

--- The room, in screen units before the Master scale, that an ahead follower of `target` clears
--- (F4): `target`'s label row while its label shows, locked or not, since the label does not wrap and
--- a name longer than the element runs on over the column beside it (its width is not read: the
--- label can sit on secret geometry); and its strip row while that strip shows and runs past its
--- element (the width the last placement measured, `stripOverhang`). 0 with neither.
sideRoom = function(target)
    local strip = DRAG and target.stripShown and (target.stripOverhang or 0) > 0
    local rows = (strip and 1 or 0) + (target.labelShown and 1 or 0)
    if rows == 0 then return 0 end
    local cfg = target.Cfg and target:Cfg()
    if not cfg then return 0 end
    return rows * (STRIP_H + STRIP_GAP) * ownScale(cfg)
end

--- Where the strip sits, and the name label with it (NL-2): out past V0, the edge the auras start
--- from (TOP growing down), one strip gap from the block, lined up with H0, the side their lines
--- start from (LEFT growing right). A behind follower's is lined up with H1 instead, the edge that
--- faces its parent, so a strip wider than the element runs away from the parent beside it.
--- @return string point, string relativePoint, number x, number y, string growH, string growV
function Anchors.StripPoints(cfg)
    local growH, growV = NS.Container.Growth(Anchors.EffectiveLayout(cfg) or {})
    local V0, V1 = "TOP", "BOTTOM"
    if growV ~= "down" then V0, V1 = "BOTTOM", "TOP" end
    local H0, H1 = "LEFT", "RIGHT"
    if growH == "left" then H0, H1 = "RIGHT", "LEFT" end
    local h = (ownSide(cfg) == "behind") and H1 or H0
    return V1 .. h, V0 .. h, 0, (growV == "down") and STRIP_GAP or -STRIP_GAP, growH, growV
end

--- How far the strip moves out to clear a shown name label (D6, NL-3, F3): the label's height and
--- the gap, further out past V0, so the order reads strip, label, block.
local function labelPush(container, growV)
    if not container.labelShown then return 0 end
    return (growV == "down") and (STRIP_H + STRIP_GAP) or -(STRIP_H + STRIP_GAP)
end

local LABEL_JUSTIFY = { LEFT = true, CENTER = true, RIGHT = true }

--- The name label's justify in effect (B9 LJ-1, E7), inside its own block's width: the player's
--- pick, or with none (AUTO, nil or anything unknown) the style's own. Bars and Text center it.
--- Icons justify it toward the element it names: LEFT, RIGHT when the auras grow left, mirrored for
--- a behind follower, whose label lines up with the edge that faces its parent. The Label tab's
--- Justify row shows this.
--- @return string "LEFT"|"CENTER"|"RIGHT"
function Anchors.LabelJustify(cfg)
    if not cfg then return "CENTER" end
    local pick = cfg.label and cfg.label.justifyH
    if LABEL_JUSTIFY[pick] then return pick end
    if NS.Style.StyleKey(cfg) ~= "icons" then return "CENTER" end
    local growH = NS.Container.Growth(Anchors.EffectiveLayout(cfg) or {})
    local mirror = ownSide(cfg) == "behind"
    return ((growH == "left") ~= mirror) and "RIGHT" or "LEFT"
end

--- How far the label's text sits in from its host's edge, by justify: none when centered.
local LABEL_INSET = { LEFT = 4, CENTER = 0, RIGHT = -4 }

--- Place a container's name label on its block's before side, nudged by its X/Y (NL-2, F3): one
--- element wide and one strip tall, its text on one line, justified per Anchors.LabelJustify. Layout
--- work, so run from Container:Apply (kept out of lockdown) and once on a first show
--- (Container:ApplyLabelShown).
function Anchors.PlaceLabel(container, cfg)
    local host, fs = container.label, container.labelText
    if not (host and fs and cfg) then return end
    local lc = cfg.label or D.label
    host:SetFrameLevel(levelOf(container.anchor, cfg) + 1)
    local point, rel, x, y = Anchors.StripPoints(cfg)
    host:ClearAllPoints()
    host:SetPoint(point, container.anchor, rel, x + (tonumber(lc.x) or 0), y + (tonumber(lc.y) or 0))
    host:SetSize(NS.Style.ElementSize(cfg), STRIP_H)
    local side = Anchors.LabelJustify(cfg)
    fs:ClearAllPoints()
    fs:SetPoint(side, host, side, LABEL_INSET[side], 0)
    fs:SetJustifyH(side)
    fs:SetWordWrap(false)
    host.placed = true
end

-- ---------------------------------------------------------------------------
-- The strip is never wider than its container (batch 11 T11)
-- ---------------------------------------------------------------------------
-- The widget's own width is its natural one (the label, the pads and the marks: Measure) floored at
-- a minimum, so a long name, or a name and the TEST tag, ran the strip past the bars it sits on (the
-- owner, 2026-09-26: about 15 px on three of five containers of one bar width). The strip is now the
-- element's width, and a label that does not fit between the marks is shortened here, the name only,
-- with STRIP_ELLIPSIS, so the TEST tag stays whole after it; the widget bounds its label between
-- its reserves with word wrap off, so what we hand it draws on one line inside the strip. The one
-- exception is an element too narrow for both reserves and MIN_STRIP_LABEL of name: a one-icon
-- container keeps the natural width, as before, so its name still reads. Measuring goes through the
-- widget's public SetLabel and Measure (a detached string, never the label, which can sit on secret
-- geometry) and runs only when the name or the width changes, so a visibility pass allocates nothing.

local MIN_STRIP_LABEL = 40   -- px of label the capped strip keeps readable
local STRIP_ELLIPSIS  = "..."

--- True when the strip is capped at element width `w`: it holds both reserves and a readable label.
local function stripCapped(handle, w)
    return w >= handle:Reserve() * 2 + MIN_STRIP_LABEL
end

--- The width `text` draws in the strip's label face (0 when it cannot be measured).
local function labelWidth(handle, text)
    handle:SetLabel(text)
    return handle:Measure() - handle:Reserve() * 2
end

--- The largest byte count no greater than `n` that ends `s` on a whole UTF-8 character.
local function charEnd(s, n)
    while n > 0 do
        local b = s:byte(n + 1)
        if not b or b < 0x80 or b >= 0xC0 then return n end
        n = n - 1
    end
    return 0
end

--- The label with the name cut to the longest start that fits `avail` with the ellipsis and the tag
--- (a binary search over the name's bytes, snapped to whole characters). None fitting leaves the
--- ellipsis alone before the tag; the widget's bound still keeps it inside the strip.
local function shortened(handle, cfg, avail)
    local open, name, close, tag = handleParts(cfg)
    local function compose(n)
        local head = name:sub(1, charEnd(name, n)):gsub("%s+$", "")
        return open .. head .. STRIP_ELLIPSIS .. close .. tag
    end
    local lo, hi = 0, #name - 1
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if labelWidth(handle, compose(mid)) <= avail then lo = mid else hi = mid - 1 end
    end
    return compose(lo)
end

--- The text the strip draws: the whole label on a natural-width strip or when it fits, else the
--- name shortened (shortened). Cached on the container by the whole label and the room it has, so
--- an unchanged pass measures nothing. Config math and the widget's own measure only: safe in combat.
local function stripLabel(container, handle, cfg)
    local full = handleText(cfg)
    if not (handle.Reserve and cfg) then return full end
    local w = NS.Style.ElementSize(cfg)
    if not stripCapped(handle, w) then return full end
    local avail = w - handle:Reserve() * 2
    if container.stripFull == full and container.stripAvail == avail then return container.stripText end
    local text = full
    if labelWidth(handle, full) > avail then text = shortened(handle, cfg, avail) end
    container.stripFull, container.stripAvail, container.stripText = full, avail, text
    return text
end

--- The strip goes where Anchors.StripPoints says, moved out past a shown name label (D6). Its width
--- is the element's while that holds a readable label (stripCapped), else its natural width floored
--- at the element. Records how far it runs past the element (`stripOverhang`, 0 when capped), which
--- an ahead follower clears (sideRoom).
--- @return number, number  how far the strip runs past the element along its line, and how far out
---                          past the anchor's V0 edge it reaches, its gap included
local function placeHandle(container, cfg)
    local handle = container.handle
    handle:SetFrameLevel(handleLevel(container, cfg))
    handle:ClearAllPoints()
    handle.placed = true
    local point, rel, x, y, _, growV = Anchors.StripPoints(cfg)
    local push = labelPush(container, growV)
    handle:SetPoint(point, container.anchor, rel, x, y + push)
    local w = NS.Style.ElementSize(cfg)
    local overhang = 0
    if handle.Reserve and stripCapped(handle, w) then
        handle:SetWidth(w)
    else
        -- The widget measures its own label on a detached string of its own and floors the width
        -- at the element.
        overhang = handle:ApplyWidth(w) - w
    end
    container.stripOverhang = overhang
    return overhang, DRAG.HEIGHT + math.abs(y + push)
end

--- Set the anchor's clamp insets only when they change. This runs on every visibility pass, and a
--- pass that moves nothing must cost nothing: no engine call, no allocation after the first set.
local function setClamp(container, l, r, t, b)
    local c = container.clampInsets
    if c and c[1] == l and c[2] == r and c[3] == t and c[4] == b then return end
    if not c then
        c = {}
        container.clampInsets = c
    end
    c[1], c[2], c[3], c[4] = l, r, t, b
    container.anchor:SetClampRectInsets(l, r, t, b)
end

--- The anchor is clamped to the screen; while its handle shows, the clamp rect reaches over the strip
--- too, so the handle cannot be dragged off-screen. Out of combat only (Anchors.UpdateHandle). The
--- strip reaches along its line by the overhang, toward H1, or toward H0 for a behind follower's
--- (lined up with H1), and out past V0 by `reach`.
local function clampToHandle(container, cfg, overhang, reach)
    if not overhang then
        setClamp(container, 0, 0, 0, 0)
        return
    end
    local growH, growV = NS.Container.Growth(Anchors.EffectiveLayout(cfg) or {})
    local toRight = (growH == "right") ~= (ownSide(cfg) == "behind")
    local left = toRight and 0 or -overhang
    local right = toRight and overhang or 0
    local top = (growV == "down") and reach or 0
    local bottom = (growV == "up") and -reach or 0
    setClamp(container, left, right, top, bottom)
end

--- Show or hide a container's handle, with its current name, re-placed each time it is shown: the
--- name sets its width and the layout's growth sets its side. Placing the strip and clamping the
--- anchor are layout work beside an aura engine's parent, so neither runs under lockdown: the handle
--- keeps its last placement and only shows or hides, and the next visibility pass after combat
--- catches both up. The one exception is a handle never placed (first shown in combat): it has no
--- points and would draw nothing, so it is placed once, being our own unprotected strip, while the
--- anchor's clamp still waits for combat to end.
function Anchors.UpdateHandle(container, show)
    local handle = container.handle
    if not handle then return end
    local cfg = container:Cfg()
    show = (show and cfg) and true or false
    -- a hidden strip keeps the whole label and measures nothing (a locked pass allocates nothing)
    handle:SetLabel(show and stripLabel(container, handle, cfg) or handleText(cfg))
    container.stripShown = show   -- the room its own seam makes (furnitureRoom)
    if not InCombatLockdown() then
        if show then
            clampToHandle(container, cfg, placeHandle(container, cfg))
        else
            clampToHandle(container, cfg, nil)
        end
    elseif show and not handle.placed then
        placeHandle(container, cfg)
    end
    handle:SetShown(show)
end
