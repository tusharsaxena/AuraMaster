-- tests/presets_spans.lua - the presets' screen sizes and the readers that measure an applied preset
-- in test mode, shared by tests/test_presets_data.lua (placement, the focus stack) and
-- tests/test_presets_cluster.lua (the right-hand cluster of presets spec section 17), which was peeled
-- out of it at layout-§1's 1500-line cap. Moved verbatim; each suite binds the names it uses to locals
-- of the same name.
--
-- Not a suite (tests/run.lua does not list it) and not part of the vendored kit.
--
--     local PS = dofile("tests/presets_spans.lua")
--     local SCREENS, sampleSpans = PS.SCREENS, PS.sampleSpans

local T = _G.AM_TEST
local assertEqual, assertTrue, assertNear = T.assertEqual, T.assertTrue, T.assertNear
local NS = T.NS

-- The screen sizes: three heights, each at the ratios spec section 11 names (16:9, 16:10, 21:9) and
-- the narrow ones (4:3, 5:4; 1024 x 768 is a UI-scale-off 4:3).
local SCREENS = {}
for _, h in ipairs({ 768, 1080, 1440 }) do
    for _, ratio in ipairs({ 16 / 9, 16 / 10, 21 / 9, 4 / 3, 5 / 4 }) do SCREENS[#SCREENS + 1] = { h * ratio, h } end
end

--- The height of one element of container data `o` (overrides or stored): its icon, its bar (the
--- template's when it states none), or its line.
local function elementHeight(o)
    local D = NS.CONTAINER_TEMPLATE
    if o.style == "icons" then return (o.icons and o.icons.height) or D.icons.height end
    if o.style == "bars" then return (o.bars and o.bars.height) or D.bars.height end
    return (o.text and o.text.height) or D.text.height
end

--- The y (a negative offset from a H-tall parent's top edge) a head placed by `pos` starts its
--- stack at: its top, or for a head growing up (`up`) its bottom, the column's base. A head hung
--- from the screen's CENTER (the owner's 2026-11-17 baseline) is placed by the middle of its first
--- element, `h` tall.
local function headEdge(pos, H, up, h)
    if pos.relativePoint ~= "CENTER" then return pos.y end
    local mid = -H / 2 + pos.y
    return up and (mid - h / 2) or (mid + h / 2)
end

--- A head's span on a W x H parent, out of its stored position and size alone: [left, right] and the
--- y it is placed at (a negative offset from the parent's top edge): its top, or for an up stack's head
--- its bottom, the column's base. A text head's is its stored width, the column, centered on the
--- center line it hangs from by its TOP (defaults/Presets.lua, sizeTo and place).
local function headRect(spec, W, H)
    local o, P = spec.overrides, NS.PresetData
    local pos = o.position
    local ax = (pos.relativePoint == "TOPRIGHT") and W or (W / 2)
    assertTrue(pos.relativePoint == "TOPRIGHT" or pos.relativePoint == "TOP" or pos.relativePoint == "CENTER",
        "a head hangs from TOP, TOPRIGHT or CENTER")
    local w
    if o.style == "bars" then
        w = o.bars.width
    elseif o.style == "icons" then
        w = o.layout.perLine * (o.icons.width + o.layout.spacing)
    else
        w = o.text.width
        assertNear(w, P.STACKS[spec.stack].width * P.ScaleX(W, H), 1, "a text head is its column wide")
    end
    local x = ax + pos.x
    local y = headEdge(pos, H, o.layout.growV == "up", elementHeight(o))
    if pos.point == "TOP" or pos.point == "CENTER" then return x - w / 2, x + w / 2, y end
    if pos.point:find("RIGHT$") then return x - w, x, y end
    assertTrue(pos.point == "TOPLEFT" or pos.point == "BOTTOMLEFT" or pos.point == "LEFT",
        "a head is placed by a corner or the middle of an edge")
    return x, x + w, y
end

--- The y offset container `id`'s anchor is placed at from what it hangs from, read off the live
--- placement (Anchors.Place): the stored gap plus the seam and, while unlocked, the drag strip's room
--- (modules/Anchors_Attach.lua seamRoom).
local function placedOffset(env, id)
    local inst = env.ContainerManager.instances[id]
    local rec = {}
    rawset(inst.anchor, "SetPoint", function(_, ...) rec[#rec + 1] = { ... } end)
    env.Anchors.Place(inst)
    rawset(inst.anchor, "SetPoint", nil)
    local last = rec[#rec]
    return last[5], inst, last[4], last[1], last[3]
end

--- One container's span from what it hangs from (`parent`, nil for a head), its stored data `c`, its
--- placed y offset `dy`, its test-mode block's height `h`, and the points it is placed by (`point`,
--- its own, and `rel`, its parent's); while `unlocked`, `room` is its own strip row, which sits on the
--- side its auras start from (Anchors.StripPoints). A member hangs from its parent's block (its
--- `blockTop` or `blockBottom`, the span less the strip), as its relative point says. A head's room is
--- added to the span, and so is the room of a member joined beside its parent, top to top (Player
--- debuffs (all), presets spec section 17); an after member's is already in its offset, between it
--- and its parent.
local function spanFrom(parent, c, dy, h, room, point, rel, H)
    local up = c.layout.growV == "up"
    local edge
    if parent then
        local relTop = rel:find("^TOP") ~= nil
        edge = (relTop and parent.blockTop or parent.blockBottom) + dy
        if relTop ~= (point:find("^TOP") ~= nil) then room = 0 end
    else
        edge = headEdge(c.position, H, up, elementHeight(c))
    end
    if up then return { top = edge + h, bottom = edge - room, blockTop = edge + h, blockBottom = edge } end
    return { top = edge + room, bottom = edge - h, blockTop = edge, blockBottom = edge - h }
end

--- A point's horizontal part: "LEFT", "RIGHT", or "" for the middle.
local function hPart(point) return point:match("LEFT$") or point:match("RIGHT$") or "" end

--- The x part `part` (hPart) sits at on span `r`.
local function xOn(r, part)
    if part == "LEFT" then return r.left end
    if part == "RIGHT" then return r.right end
    return (r.left + r.right) / 2
end

--- Fill `span`'s [left, right]: a block `w` wide whose own `point` sits at `x`, and, while unlocked,
--- the drag strip's overhang past it (`over`, Anchors' stripOverhang): the strip starts on the side
--- the auras start from and runs on along the growth (Anchors.StripPoints, placeHandle).
local function spanAcross(span, point, x, w, over, growH)
    local part = hPart(point)
    span.left = (part == "LEFT" and x) or (part == "RIGHT" and x - w) or (x - w / 2)
    span.right = span.left + w
    if over > 0 then
        if growH == "left" then span.left = span.left - over else span.right = span.right + over end
    end
end

--- Narrow the span of a container that shows nothing (`span`, its anchor's) to what a follower
--- hangs from when it hangs from its ENGINE (Anchors.HangMode "engine"): an empty engine's 1x1 rect,
--- pinned ENGINE_LEAD behind its anchor's start corner across (modules/Container.lua), so the
--- follower's placed offset, which takes that lead back (modules/Anchors_Attach.lua), lands it on
--- the anchor's start edge. Down the growth the empty rect's far edge is the start, which the span's
--- zero height already is.
local function emptyEngineAcross(env, inst, span, growH)
    if env.Anchors.HangMode(inst) ~= "engine" then return end
    local lead = env.Container.ENGINE_LEAD
    if growH == "left" then
        span.left, span.right = span.right, span.right + lead
    else
        span.left, span.right = span.left - lead, span.left
    end
end

--- Widen stack span `whole` (nil for a stack's first) to hold container span `span`.
local function union(whole, span)
    if not whole then return { top = span.top, bottom = span.bottom, left = span.left, right = span.right } end
    whole.top, whole.bottom = math.max(whole.top, span.top), math.min(whole.bottom, span.bottom)
    whole.left, whole.right = math.min(whole.left, span.left), math.max(whole.right, span.right)
    return whole
end

--- The x container `c`'s own point sits at on a W-wide parent: a member's, its parent's relative
--- point (`rel`) moved on by its placed `dx`; a head's, its stored position from TOPRIGHT, or TOP or
--- CENTER (both on the center line).
local function pointX(parent, c, rel, dx, W)
    if parent then return xOn(parent, hPart(rel)) + dx end
    return ((c.position.relativePoint == "TOPRIGHT") and W or W / 2) + c.position.x
end

--- Each stack's test-mode span with preset `name` in style `look` applied on a W x H parent in `env`,
--- every container filled with its test-mode samples: [stack] = { top, bottom, left, right }, top and
--- bottom offsets from the parent's top (negative is down), left and right from its left edge (each
--- block as wide as Preview.BlockSize makes it, joined where its live placement puts it). A head
--- placed by a BOTTOM point starts at its base and grows up; a member hangs below the one before it growing down, above it growing up, at its live placement's
--- offset. `unlocked` measures with the containers unlocked, their drag strips shown, as the preset
--- picker opens them (spec section 15); otherwise locked.
local function sampleSpans(env, mocks, name, look, W, H, unlocked)
    env.Presets.ParentSize = function() return W, H end
    assertTrue(env.Presets.Apply(name, look, "replace"), name .. "/" .. look .. " applies")
    env.SetByPath("locked", not unlocked)
    env.Preview.SetTestMode(true)
    mocks.__fireTimers()
    local specs, p = env.PresetData.Build(name, look, W, H), env.db.profile
    assertEqual(#p.containerOrder, #specs, "one container per spec, in creation order")
    local spanOf, out, each = {}, {}, {}
    for i, id in ipairs(p.containerOrder) do
        local c = p.containers[id]
        local extent = env.Preview.Extent({ Cfg = function() return c end, anchor = mocks.CreateFrame("Frame") })
        local parent = (c.attach.mode == "container") and spanOf[tonumber(c.attach.container)]
        local dy, inst, dx, point, rel = placedOffset(env, id)
        -- A disabled container (Advanced's tsteal, as the source stores it) shows nothing, test mode
        -- or not (ShouldShow): no height, and no part of its stack's span.
        local shown = c.enabled ~= false
        assertEqual(inst.stripShown == true, shown and unlocked == true, "the strip shows while unlocked")
        local span = spanFrom(parent, c, dy, shown and extent.height or 0, env.AnchorsAttach.furnitureRoom(inst),
            point, rel, H)
        local over = unlocked and (inst.stripOverhang or 0) or 0
        local growH = env.Anchors.EffectiveLayout(c).growH
        spanAcross(span, point, pointX(parent, c, rel, dx, W), (env.Preview.BlockSize(c)), over, growH)
        if not shown then emptyEngineAcross(env, inst, span, growH) end
        spanOf[id] = span
        local stack = specs[i].stack
        if shown then
            out[stack] = union(out[stack], span)
            each[#each + 1] = { role = specs[i].role, stack = stack, span = span }
        end
    end
    env.Preview.SetTestMode(false)
    env.SetByPath("locked", true)
    mocks.__fireTimers()
    return out, each
end

--- The distance between rectangles `a` and `b` (from sampleSpans): the larger of the horizontal and
--- the vertical gap between their facing edges, 0 when they overlap. Never more than the straight
--- distance, so a check against it is the stricter one.
local function rectGap(a, b)
    local h = math.max(0, a.left - b.right, b.left - a.right)
    local v = math.max(0, a.bottom - b.top, b.bottom - a.top)
    return math.max(h, v)
end

return {
    SCREENS = SCREENS, headRect = headRect, sampleSpans = sampleSpans, rectGap = rectGap,
    elementHeight = elementHeight,
}
