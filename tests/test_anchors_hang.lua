-- tests/test_anchors_hang.lua - what a container attached to another hangs from (batch 8 EO-1/EO-2,
-- owner feedback #9). While a parent is unlocked, not previewing and predicted EMPTY (batch 9 HG-1:
-- here every engine's pool is 0, so each parent is), its followers hang from its
-- ANCHOR, which is exactly one element, the rect its white outline marks, instead of its engine,
-- which holds a 1x1 provisional rect while it has no auras: an empty unlocked chain collapsed into
-- about 5px steps, every strip and outline piled on the last. In test mode they hang from the
-- preview extent (L-4) and locked from the engine. Wherever the strips show, a follower of a
-- follower leaves room for its parent's strip, so no two strips in a chain overlap. A parent that
-- is not predicted empty is tests/test_emptywatch.lua's.
-- Its own suite because tests/test_anchors.lua sits near layout-§1's 1500-line cap.

local T = _G.AM_TEST
local test, assertEqual, assertTrue =
    T.test, T.assertEqual, T.assertTrue
local fresh = dofile("tests/fresh_env.lua")

--- Record every SetPoint made on a container's anchor.
local function recordAnchor(inst)
    local rec = { points = {} }
    rawset(inst.anchor, "SetPoint", function(_, ...) table.insert(rec.points, { ... }) end)
    rawset(inst.anchor, "ClearAllPoints", function() end)
    return rec
end

--- The frame a recorded anchor was last pointed at, and the whole last call.
local function lastTarget(rec)
    local p = rec.points[#rec.points]
    return p and p[2], p
end

--- Attach container `id` to container `to` through the write seam, with no nudge.
local function attach(NS, id, to)
    NS.SetByPath("container.attach.x", 0, id)
    NS.SetByPath("container.attach.y", 0, id)
    NS.SetByPath("container.attach.container", to, id)
    NS.SetByPath("container.attach.mode", "container", id)
end

--- A chain 3 -> 2 -> 1, unlocked, test mode off, flushed. `style` restyles all three.
local function unlockedChain(style)
    local NS, mocks = fresh()
    if style then
        for id = 1, 3 do NS.SetByPath("container.style", style, id) end
    end
    attach(NS, 2, 1)
    attach(NS, 3, 2)
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    return NS, mocks, NS.ContainerManager
end

test("hang: unlocked and not in test mode, an attached container hangs from its parent's one-element anchor, not its empty engine", function()
    local NS, _, CM = unlockedChain()
    local one, two = CM.instances[1], CM.instances[2]
    local rec = recordAnchor(two)
    NS.Anchors.Place(two)
    local target, p = lastTarget(rec)
    -- red under: targetFor answering the parent's engine (a 1x1 rect while it holds no aura)
    assertTrue(target == one.anchor, "the parent's anchor, the rect its outline marks")
    assertEqual(p[1], "TOPLEFT"); assertEqual(p[3], "BOTTOMLEFT")
end)

test("hang: a chain 3 -> 2 -> 1 unlocked: 3 hangs from 2's anchor, 2 from 1's", function()
    local NS, _, CM = unlockedChain()
    local rec2, rec3 = recordAnchor(CM.instances[2]), recordAnchor(CM.instances[3])
    NS.Anchors.Place(CM.instances[2])
    NS.Anchors.Place(CM.instances[3])
    assertTrue(lastTarget(rec2) == CM.instances[1].anchor, "2 on 1's anchor")
    assertTrue(lastTarget(rec3) == CM.instances[2].anchor, "3 on 2's anchor")
end)

test("hang: locking re-anchors followers onto the parent's engine, unlocking puts them back; a pass that changes nothing re-places nothing", function()
    local NS, mocks, CM = unlockedChain()
    local one = CM.instances[1]
    local rec = recordAnchor(CM.instances[2])
    NS.SetByPath("locked", true)
    mocks.__fireTimers()
    -- red under: PlaceAttached memoizing on test mode alone (a lock never re-targets)
    assertTrue(lastTarget(rec) == one.engine, "locked: the engine, which grows with the real auras")
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    assertTrue(lastTarget(rec) == one.anchor, "unlocked: the anchor again")
    local placed = #rec.points
    CM.ApplyVisibility()
    -- red under: re-placing the followers on every visibility pass
    assertEqual(#rec.points, placed, "nothing changed: nothing re-placed")
end)

test("hang: unlocked, ending test mode moves followers from the preview extent to the parent's anchor, and starting it moves them back", function()
    local NS, mocks, CM = unlockedChain()
    local one = CM.instances[1]
    local rec = recordAnchor(CM.instances[2])
    NS.Preview.SetTestMode(true)
    mocks.__fireTimers()
    assertTrue(one.previewExtent ~= nil and lastTarget(rec) == one.previewExtent, "test mode: the extent (L-4)")
    NS.Preview.SetTestMode(false)
    mocks.__fireTimers()
    -- red under: ending test mode sending a follower of an unlocked parent to its empty engine
    assertTrue(lastTarget(rec) == one.anchor, "test mode off, still unlocked: the anchor")
end)

test("hang: under lockdown a lock leaves a follower where it is; the pass after combat moves it", function()
    local NS, mocks, CM = unlockedChain()
    local rec = recordAnchor(CM.instances[2])
    mocks.__lockdown = true
    NS.SetByPath("locked", true)
    mocks.__fireTimers()
    -- red under: re-placing a follower under lockdown (events-frames-taint-§2)
    assertEqual(#rec.points, 0, "the last placement stands")
    mocks.__lockdown = false
    NS.addon:OnCombatChanged("PLAYER_REGEN_ENABLED")
    -- red under: recording the new hang mode as placed when lockdown skipped it
    assertTrue(lastTarget(rec) == CM.instances[1].engine, "combat over: onto the engine")
end)

-- ── strips never stack (EO-2) ─────────────────────────────────────────────────────────────────

--- Where each container's strip spans vertically, in screen units from container 1's top (down is
--- negative), for a chain growing down whose strips all sit above their own block, one strip gap
--- off it (batch 10 F1). Worked out from the recorded offsets, the element heights and the widget's
--- strip height, since the mock has no geometry. Also answers each block's top and bottom.
local function stripSpans(NS, mocks, CM)
    local DRAG = mocks.LibStub("LibKa0s-Widgets-1.0").DRAG_HANDLE
    local spans, top = {}, 0
    local _, h1 = NS.Style.ElementSize(NS.Database.FindContainer(1))
    spans[1] = { DRAG.GAP, DRAG.GAP + DRAG.HEIGHT }            -- the root's strip sits above it
    local bottom = top - h1
    local blocks = { { top = top, bottom = bottom } }
    for id = 2, 3 do
        local rec = recordAnchor(CM.instances[id])
        NS.Anchors.Place(CM.instances[id])
        local _, p = lastTarget(rec)
        top = bottom + p[5]
        spans[id] = { top + DRAG.GAP, top + DRAG.GAP + DRAG.HEIGHT }
        local _, h = NS.Style.ElementSize(NS.Database.FindContainer(id))
        bottom = top - h
        blocks[id] = { top = top, bottom = bottom }
    end
    return spans, DRAG.GAP, blocks
end

--- No two strips overlap, and each pair leaves at least the widget's strip gap between them:
--- two gold edges touching read as one stacked strip.
local function assertNoOverlap(spans, gap, what)
    local n = #spans
    for a = 1, n do
        for b = a + 1, n do
            local sa, sb = spans[a], spans[b]
            assertTrue(sa[2] + gap <= sb[1] or sb[2] + gap <= sa[1],
                ("%s: strips %d [%s,%s] and %d [%s,%s] overlap"):format(what, a, sa[1], sa[2], b, sb[1], sb[2]))
        end
    end
end

test("hang: three empty Text containers chained and unlocked: no two strips overlap, and each sits between its parent's block and its own", function()
    local NS, mocks, CM = unlockedChain("text")
    local spans, gap, blocks = stripSpans(NS, mocks, CM)
    -- red under: the engine target (every link about 5px under the last) or a seam that leaves no
    -- room for the follower's own strip (batch 10 F2)
    assertNoOverlap(spans, gap, "unlocked")
    for id = 2, 3 do
        local seam = NS.Database.FindContainer(id).layout.spacing
        assertEqual(blocks[id - 1].bottom - spans[id][2], seam, id .. "'s strip one seam under its parent's block")
        assertEqual(spans[id][1] - blocks[id].top, gap, id .. "'s strip one strip gap over its own block")
    end
end)

test("hang: the room for a strip is the follower's own: unlocked it adds its strip's row to the seam, locked the seam alone (F2)", function()
    local NS, mocks, CM = unlockedChain("text")
    local rec = recordAnchor(CM.instances[2])
    NS.Anchors.Place(CM.instances[2])
    local _, unlocked = lastTarget(rec)
    NS.SetByPath("locked", true)
    mocks.__fireTimers()
    NS.Anchors.Place(CM.instances[2])
    local _, locked = lastTarget(rec)
    local spacing = NS.Database.FindContainer(2).layout.spacing
    -- red under: the batch 9 seam (the follower's strip beside its column, so no room made)
    assertEqual(unlocked[5], -(spacing + 20), "unlocked: the seam and the strip's row")
    assertEqual(locked[5], -spacing, "locked: the seam alone (SS-3)")
end)

test("hang: locked, a follower of a follower keeps its own seam: no strip shows, so none needs room", function()
    local NS, mocks, CM = unlockedChain("text")
    NS.SetByPath("locked", true)
    mocks.__fireTimers()
    local rec = recordAnchor(CM.instances[3])
    NS.Anchors.Place(CM.instances[3])
    local _, p = lastTarget(rec)
    assertEqual(p[5], -NS.Database.FindContainer(3).layout.spacing)
end)

test("hang: in test mode a chain leaves the same room for its strips (EO-2)", function()
    local NS, mocks, CM = unlockedChain("text")
    for id = 1, 3 do NS.SetByPath("container.filter.maxAuras", 1, id) end
    NS.Preview.SetTestMode(true)
    mocks.__fireTimers()
    local rec = recordAnchor(CM.instances[3])
    NS.Anchors.Place(CM.instances[3])
    assertTrue(lastTarget(rec) == CM.instances[2].previewExtent, "3 on 2's preview extent")
    local spans, gap = stripSpans(NS, mocks, CM)
    assertNoOverlap(spans, gap, "test mode")
end)

test("hang: a test-mode chain locked shows no strips and keeps its own seams", function()
    local NS, mocks, CM = unlockedChain("text")
    NS.SetByPath("locked", true)
    NS.Preview.SetTestMode(true)
    mocks.__fireTimers()
    local rec = recordAnchor(CM.instances[3])
    NS.Anchors.Place(CM.instances[3])
    local _, p = lastTarget(rec)
    -- red under: room made for a strip that does not show
    assertEqual(p[5], -NS.Database.FindContainer(3).layout.spacing)
end)

test("hang: HangMode reads the recorded mode, and before any visibility pass falls back on the preview", function()
    local NS = fresh()
    local A = NS.Anchors
    assertEqual(A.HangMode({ hangMode = "slot", previewShown = true }), "slot")
    assertEqual(A.HangMode({ previewShown = true }), "preview")
    assertEqual(A.HangMode({}), "engine")
end)
