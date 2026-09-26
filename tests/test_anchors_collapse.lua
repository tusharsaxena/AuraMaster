-- tests/test_anchors_collapse.lua - an EMPTY link adds nothing along a chain (the owner's chain
-- residue, 2026-09-26). Locked, or in combat, a follower hangs from its parent's ENGINE
-- (Anchors.HangMode "engine"), and an engine that holds no aura is the flow layout's 1x1 minimum
-- rect (AnchorUtil.ApplyFlowLayout: math.max(size, 1)). Pinned AT its anchor's start corner, the
-- rect's far edge sat one unit past the start, so every empty after-link pushed the rest of the
-- chain on by one unit: the owner's #19, behind three empty links, sat 3 units above #22 in client
-- (container bottoms 281.99996948242, 283, 283.99996948242, 285).
--
-- The fix (the engine lead): the engine is pinned one unit BEHIND its anchor's start corner on both growth
-- axes and pads its start sides by that unit, so a populated engine's first element still starts at
-- the anchor's start and its far edge is start + content, while an empty one spans [start - 1,
-- start]: its far edge IS the start. A follower's relative point on a start side takes the unit
-- back (half of it on a middle part), so the across-axis landing (batch 11 T9) is unchanged.
--
-- The mock has no geometry, so each test works the geometry out: an engine's rect from the SetPoint
-- and the padding its Build RECORDED on the engine, sized the way AnchorUtil.ApplyFlowLayout sizes
-- it for `n` auras; each anchor's rect from the SetPoint Anchors.Place gave it. Nothing here reads
-- the fix's own constants, so a wrong offset or padding fails the landing, not just an equality.

local T = _G.AM_TEST
local test, assertEqual, assertTrue =
    T.test, T.assertEqual, T.assertTrue
local fresh = dofile("tests/fresh_env.lua")

local function near(a, b, what)
    assertTrue(math.abs(a - b) < 1e-6, ("%s: %s vs %s"):format(what, tostring(a), tostring(b)))
end

--- The last recorded call named `name` on engine `e`.
local function lastCall(e, name)
    local calls = e:__callsTo(name)
    return calls[#calls]
end

--- Container `id`'s last anchor SetPoint after one Place: { point, relativeTo, relPoint, x, y }.
local function placed(NS, id)
    local inst = NS.ContainerManager.instances[id]
    local rec = {}
    local set, clear = inst.anchor.SetPoint, inst.anchor.ClearAllPoints
    rawset(inst.anchor, "SetPoint", function(_, ...) table.insert(rec, { ... }) end)
    rawset(inst.anchor, "ClearAllPoints", function() end)
    NS.Anchors.Place(inst)
    rawset(inst.anchor, "SetPoint", set)
    rawset(inst.anchor, "ClearAllPoints", clear)
    return rec[#rec]
end

-- A point's horizontal and vertical parts: "LEFT"/"RIGHT"/"" and "TOP"/"BOTTOM"/"".
local function hPart(p) return p:match("LEFT$") or p:match("RIGHT$") or "" end
local function vPart(p) return p:match("^TOP") or p:match("^BOTTOM") or "" end

--- Where part `part` of a rect { l, b, r, t } sits on one axis.
local function onX(rect, part)
    if part == "LEFT" then return rect.l elseif part == "RIGHT" then return rect.r end
    return (rect.l + rect.r) / 2
end
local function onY(rect, part)
    if part == "BOTTOM" then return rect.b elseif part == "TOP" then return rect.t end
    return (rect.b + rect.t) / 2
end

--- The rect of a `w` x `h` frame whose point `point` sits at (x, y).
local function rectAt(point, x, y, w, h)
    local hp, vp = hPart(point), vPart(point)
    local l = (hp == "LEFT" and x) or (hp == "RIGHT" and x - w) or x - w / 2
    local b = (vp == "BOTTOM" and y) or (vp == "TOP" and y - h) or y - h / 2
    return { l = l, b = b, r = l + w, t = b + h }
end

--- Container `id`'s ENGINE rect while it holds `n` auras in one column (axis vertical, perLine 0),
--- hung off its anchor rect `anchor`: pinned where its Build recorded, sized as ApplyFlowLayout
--- sizes it from the recorded padding (start padding + content + end padding, never under 1).
local function engineRect(NS, id, anchor, n)
    local inst = NS.ContainerManager.instances[id]
    local cfg = inst:Cfg()
    local e = inst.engine
    local sp = lastCall(e, "SetPoint")
    assertTrue(sp[3] == inst.anchor, "the engine hangs off its own anchor")
    local corner = sp[2]
    local cx, cy = onX(anchor, hPart(sp[4])) + sp[5], onY(anchor, vPart(sp[4])) + sp[6]
    local pad = lastCall(e, "SetFlowLayoutPadding")
    local L = NS.Anchors.EffectiveLayout(cfg)
    local padL, padR, padT, padB = pad[2], pad[3], pad[4], pad[5]
    local w, h = NS.Style.ElementSize(cfg)
    local s = tonumber(cfg.layout.spacing) or 0
    local contentW = (n > 0) and w or 0
    local contentH = (n > 0) and (n * h + (n - 1) * s) or 0
    local ew = math.max(padL + contentW + padR, 1)
    local eh = math.max(padT + contentH + padB, 1)
    -- The first element's own start corner, from the start padding on each growth axis.
    local startX = (L.growH == "left") and -padR or padL
    local startY = (L.growV == "up") and padB or -padT
    return rectAt(corner, cx, cy, ew, eh), cx + startX, cy + startY
end

--- The owner's chain: 1 (#22) on a named frame, 2 (#21) on 1, 3 (#20) on 2 by BOTTOM -> TOP (after-
--- center), 4 (#19) on 3 by Automatic (after-start); bars in one column growing `growV`/`growH`, no
--- spacing, every parent hanging from its engine (locked, or in combat).
local function ownerChain(growH, growV)
    local NS, mocks = fresh()
    local f = mocks.__stubFrame()
    f.GetName = function() return "OwnerFrame" end
    f.IsForbidden = function() return false end
    f.GetParent = function() return nil end
    mocks.__globals.OwnerFrame = f
    for id = 1, 4 do
        local c = NS.Database.FindContainer(id)
        c.style = "bars"
        c.layout.axis, c.layout.growH, c.layout.growV, c.layout.perLine = "vertical", growH, growV, 0
        c.layout.spacing, c.layout.lineSpacing = 0, 0
        c.label = c.label or {}
        c.label.show = false
    end
    local c1 = NS.Database.FindContainer(1)
    c1.attach = { mode = "frame", frame = "OwnerFrame", point = "BOTTOMLEFT", relativePoint = "TOPLEFT", x = 0, y = 2 }
    for id = 2, 4 do
        local c = NS.Database.FindContainer(id)
        c.attach.mode, c.attach.container, c.attach.x, c.attach.y = "container", id - 1, 0, 0
        c.attach.childPoint, c.attach.relPoint = nil, nil
    end
    local up = (growV == "up")
    NS.Database.FindContainer(3).attach.childPoint = up and "BOTTOM" or "TOP"
    NS.Database.FindContainer(3).attach.relPoint = up and "TOP" or "BOTTOM"
    NS.ContainerManager.RequestApply(nil, true)
    mocks.__fireTimers()
    for id = 1, 4 do NS.ContainerManager.instances[id].hangMode = "engine" end
    return NS
end

--- Every anchor rect down the chain when containers 1..4 hold `counts[id]` auras, with container 1's
--- anchor at the origin. Each follower is placed ONCE (`places`, from placed()), so a count change
--- with no re-place models an engine that resizes live, in combat.
local function walk(NS, places, counts)
    local w, h = NS.Style.ElementSize(NS.Database.FindContainer(1))
    local anchors = { [1] = { l = 0, b = 0, r = w, t = h } }
    local starts = {}
    for id = 1, 4 do
        local engine, sx, sy = engineRect(NS, id, anchors[id], counts[id] or 0)
        starts[id] = { x = sx, y = sy }
        local p = places[id + 1]
        if p then
            local x = onX(engine, hPart(p[3])) + p[4]
            local y = onY(engine, vPart(p[3])) + p[5]
            local cw, ch = NS.Style.ElementSize(NS.Database.FindContainer(id + 1))
            anchors[id + 1] = rectAt(p[1], x, y, cw, ch)
        end
    end
    return anchors, starts
end

local function placeAll(NS)
    return { [2] = placed(NS, 2), [3] = placed(NS, 3), [4] = placed(NS, 4) }
end

test("collapse: the owner's chain growing up, three empty links, #19 lands level with #22's start", function()
    local NS = ownerChain("right", "up")
    local anchors = walk(NS, placeAll(NS), {})
    -- red under: the engine pinned AT its anchor's start corner (+1 per empty link: +3 here)
    near(anchors[4].b, anchors[1].b, "#19's bottom vs #22's")
    near(anchors[2].b, anchors[1].b, "#21's bottom vs #22's")
    near(anchors[3].b, anchors[1].b, "#20's bottom vs #22's")
end)

test("collapse: #22 holding n auras puts #19 at #22's start + n bars, exactly", function()
    local NS = ownerChain("right", "up")
    local _, h = NS.Style.ElementSize(NS.Database.FindContainer(1))
    local places = placeAll(NS)
    for _, n in ipairs({ 1, 3 }) do
        local anchors, starts = walk(NS, places, { [1] = n })
        near(starts[1].y, anchors[1].b, "#22's first bar starts at its anchor's start")
        near(anchors[4].b, anchors[1].b + n * h, ("#19 above %d bars"):format(n))
    end
end)

test("collapse: every link populated lands where it always has, one block past its parent", function()
    local NS = ownerChain("right", "up")
    local _, h = NS.Style.ElementSize(NS.Database.FindContainer(1))
    local anchors = walk(NS, placeAll(NS), { 2, 1, 3, 1 })
    near(anchors[2].b, anchors[1].b + 2 * h, "#21 above #22's two")
    near(anchors[3].b, anchors[2].b + 1 * h, "#20 above #21's one")
    near(anchors[4].b, anchors[3].b + 3 * h, "#19 above #20's three")
end)

test("collapse: growing down mirrors it, and growing left too", function()
    for _, g in ipairs({ { "right", "down" }, { "left", "up" }, { "left", "down" } }) do
        local NS = ownerChain(g[1], g[2])
        local _, h = NS.Style.ElementSize(NS.Database.FindContainer(1))
        local places = placeAll(NS)
        local what = g[1] .. "/" .. g[2]
        local anchors = walk(NS, places, {})
        local top = function(r) return (g[2] == "up") and r.b or r.t end
        near(top(anchors[4]), top(anchors[1]), what .. ": three empty links add nothing")
        anchors = walk(NS, places, { [1] = 2 })
        local sign = (g[2] == "up") and 1 or -1
        near(top(anchors[4]), top(anchors[1]) + sign * 2 * h, what .. ": two bars on #22")
    end
end)

test("collapse: an engine that held auras and emptied adds nothing either, with no re-place", function()
    local NS = ownerChain("right", "up")
    local places = placeAll(NS)   -- placed while every engine held auras
    local held = walk(NS, places, { 2, 2, 2, 2 })
    local emptied = walk(NS, places, { 0, 0, 0, 0 })
    assertTrue(held[4].b > held[1].b, "precondition: the held chain spreads")
    near(emptied[4].b, emptied[1].b, "emptied: #19 back level with #22")
end)

test("collapse: the across-axis landing (batch 11 T9) is unchanged, empty or populated", function()
    for _, g in ipairs({ { "right", "up" }, { "left", "up" }, { "right", "down" }, { "left", "down" } }) do
        local NS = ownerChain(g[1], g[2])
        local places = placeAll(NS)
        local what = g[1] .. "/" .. g[2]
        for _, counts in ipairs({ {}, { 1, 1, 1, 1 }, { 3, 0, 2, 0 } }) do
            local anchors = walk(NS, places, counts)
            -- after-start (#21 on #22, #19 on #20): the child's start edge on the parent's
            local startEdge = function(r) return (g[1] == "left") and r.r or r.l end
            near(startEdge(anchors[2]), startEdge(anchors[1]), what .. ": after-start #21")
            near(startEdge(anchors[4]), startEdge(anchors[3]), what .. ": after-start #19")
            -- after-center (#20 on #21): centered on the parent's one-bar column
            near((anchors[3].l + anchors[3].r) / 2, (anchors[2].l + anchors[2].r) / 2, what .. ": after-center #20")
        end
    end
end)

test("collapse: a join hung from the slot or the preview is not given the engine's unit", function()
    local NS = ownerChain("right", "up")
    local engine = placed(NS, 4)
    NS.ContainerManager.instances[3].hangMode = "slot"
    local slot = placed(NS, 4)
    assertTrue(slot[2] == NS.ContainerManager.instances[3].anchor, "slot: the anchor")
    -- the anchor sits AT the start: no unit to take back
    assertEqual(slot[4], 0); assertEqual(slot[5], 0)
    assertTrue(engine[2] == NS.ContainerManager.instances[3].engine, "engine: the engine")
    assertEqual(engine[4], 1, "the engine sits one unit behind the start: taken back across")
    NS.Preview.Show(NS.ContainerManager.instances[3])
    NS.ContainerManager.instances[3].hangMode = "preview"
    local preview = placed(NS, 4)
    assertTrue(preview[2] == NS.ContainerManager.instances[3].previewExtent, "preview: the extent")
    assertEqual(preview[4], 0); assertEqual(preview[5], 0)
end)

--- A fresh container 1 built to grow `growH`/`growV`.
local function builtAs(growH, growV)
    local NS, mocks = fresh()
    assertTrue(NS.SetByPath("container.layout.growH", growH, 1))
    assertTrue(NS.SetByPath("container.layout.growV", growV, 1))
    mocks.__fireTimers()
    return NS, mocks, NS.ContainerManager.instances[1]
end

test("collapse: Build pins the engine one unit behind its anchor's start corner and pads the start sides", function()
    local want = {
        -- growH, growV, corner, x, y, padding left, right, top, bottom
        { "right", "up",   "BOTTOMLEFT",  -1, -1, 1, 0, 0, 1 },
        { "right", "down", "TOPLEFT",     -1,  1, 1, 0, 1, 0 },
        { "left",  "up",   "BOTTOMRIGHT",  1, -1, 0, 1, 0, 1 },
        { "left",  "down", "TOPRIGHT",     1,  1, 0, 1, 1, 0 },
    }
    for _, c in ipairs(want) do
        local _, _, inst = builtAs(c[1], c[2])
        local e = inst.engine
        local what = c[1] .. "/" .. c[2]
        local sp = lastCall(e, "SetPoint")
        assertEqual(sp[2], c[3], what .. ": the start corner")
        assertTrue(sp[3] == inst.anchor, what .. ": off its own anchor")
        assertEqual(sp[4], c[3], what .. ": to the anchor's start corner")
        assertEqual(sp[5], c[4], what .. ": x, one unit against the growth")
        assertEqual(sp[6], c[5], what .. ": y, one unit against the growth")
        local pad = lastCall(e, "SetFlowLayoutPadding")
        assertEqual(pad[2], c[6], what .. ": left"); assertEqual(pad[3], c[7], what .. ": right")
        assertEqual(pad[4], c[8], what .. ": top"); assertEqual(pad[5], c[9], what .. ": bottom")
    end
end)

test("collapse: a live update re-sends the same start padding (no rebuild)", function()
    local NS, mocks, inst = builtAs("left", "up")
    local e = inst.engine
    assertTrue(NS.SetByPath("container.layout.spacing", 3, 1))
    mocks.__fireTimers()
    assertTrue(inst.engine == e, "a spacing change keeps the engine")
    local pad = lastCall(e, "SetFlowLayoutPadding")
    assertEqual(pad[2], 0); assertEqual(pad[3], 1); assertEqual(pad[4], 0); assertEqual(pad[5], 1)
end)
