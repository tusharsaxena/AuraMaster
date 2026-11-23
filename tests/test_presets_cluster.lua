-- tests/test_presets_cluster.lua -- the right-hand cluster lined up, Player debuffs (all) joined to
-- Player buffs (all), and every bar container as wide as Player cooldowns (AM-PR16; presets spec
-- section 17.1 and 17.2). Peeled out of tests/test_presets_data.lua at layout-§1's 1500-line cap; the
-- screens and the test-mode readers both use are tests/presets_spans.lua's. A case that applies a
-- preset builds its own environment (tests/fresh_env.lua), one per screen where it walks them all, so
-- no environment grows by every Apply (the kit's leak gate). Every case runs under both kit profiles.

local freshEnv = dofile("tests/fresh_env.lua")
local PS = dofile("tests/presets_spans.lua")
local SCREENS, headRect, sampleSpans = PS.SCREENS, PS.headRect, PS.sampleSpans
local fits, columnEdges = PS.fits, PS.columnEdges

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil, assertNear =
    T.test, T.assertEqual, T.assertTrue, T.assertNil, T.assertNear
local NS = T.NS

local PRESETS = { "simple", "intermediate", "advanced", "healer" }
-- The presets with a target stack, and so a target column beside the focus column.
local WITH_TARGET = { "intermediate", "advanced", "healer" }

--- An environment whose skin picker never opens (a preset apply would queue it).
local function env1()
    local env, mocks = freshEnv()
    env.Helpers.SkinPicker = function() return nil end
    return env, mocks
end

--- Preset `name` in style `look` applied on a W x H parent in `env`: [role] = its stored container.
local function appliedByRole(env, name, look, W, H)
    env.Presets.ParentSize = function() return W, H end
    assertTrue(env.Presets.Apply(name, look, "replace"), name .. "/" .. look .. " applies")
    local specs, p, out = env.PresetData.Build(name, look, W, H), env.db.profile, {}
    for i, id in ipairs(p.containerOrder) do out[specs[i].role] = p.containers[id] end
    return out
end

--- Each built head's rect on a W x H parent: [stack] = { left, right, y }.
local function headsOf(P, name, look, W, H)
    local heads = {}
    for _, spec in ipairs(P.Build(name, look, W, H)) do
        if not spec.attachTo then heads[spec.stack] = { headRect(spec, W, H) } end
    end
    return heads
end

--- Column `stack`'s left and right edge on a W x H parent, from the parent's left edge (PS.columnEdges:
--- its place scaled, its width not).
local function edgesAt(stack, W, H)
    local l, r = columnEdges(stack, W, H)
    return W / 2 + l, W / 2 + r
end

test("presets data: Player debuffs attaches by its top right to Player buffs' top left", function()
    local env, mocks = env1()
    local FLOW = { "axis", "growH", "growV" }
    for _, name in ipairs(PRESETS) do
        for _, look in ipairs(env.PresetData.LOOKS) do
            local where = name .. "/" .. look
            local c = appliedByRole(env, name, look, 1920, 1080)
            local pb, pd, wpn = c.pbuffs, c.pdebuffs, c.wpn
            -- red under: Player debuffs placed on the screen in a column of its own
            assertEqual(pd.attach.mode, "container", where .. ": Player debuffs is attached")
            assertEqual(tonumber(pd.attach.container), pb.id, where .. ": to Player buffs")
            local point, rel, pointAuto, relAuto = env.Anchors.AttachPoints(pd)
            assertEqual(point, "TOPRIGHT", where .. ": by its top right")
            assertEqual(rel, "TOPLEFT", where .. ": to Player buffs' top left")
            assertTrue(not pointAuto and not relAuto, where .. ": both points picked, as the panel shows them")
            -- One of the nine sides under Player buffs' flow, so the seam leaves its own gap across.
            assertEqual(env.Anchors.AttachEdge(pd), (look == "bars") and "behind-start" or "ahead-start", where)
            -- It takes Player buffs' flow (Anchors.FlowRoot, EffectiveLayout), and is built to it.
            assertEqual(env.Anchors.FlowRoot(pd).id, pb.id, where .. ": flows by Player buffs")
            local eff = env.Anchors.EffectiveLayout(pd)
            for _, key in ipairs(FLOW) do
                assertEqual(eff[key], pb.layout[key], where .. " " .. key .. ": Player buffs'")
                assertEqual(pd.layout[key], eff[key], where .. " " .. key .. ": its own, so nothing re-flows")
            end
            assertEqual(eff.axis, (look == "bars") and "vertical" or "horizontal", where .. ": bars stay a column")
            -- Weapon enchants stays under Player buffs; Player buffs still hangs from the top right.
            assertEqual(tonumber(wpn.attach.container), pb.id, where .. ": Weapon enchants under Player buffs")
            assertEqual(pb.attach.mode, "screen", where)
            -- red under: section 17's corner group, hung from the top-right corner; since the owner's
            -- 2026-11-17 baseline it hangs by its middle from the screen's center
            assertEqual(pb.position.relativePoint, "CENTER", where .. ": the corner group's head, from the screen's center")
            assertEqual(pd.attach.x, 0, where .. ": flush, the seam leaves the gap")
        end
    end
    -- In test mode Player debuffs' top is Player buffs' top, its right edge the seam's 2 (Player
    -- debuffs' line spacing, between columns) left of Player buffs' left edge, locked and unlocked.
    for _, unlocked in ipairs({ false, true }) do
        local _, each = sampleSpans(env, mocks, "simple", "bars", 1920, 1080, unlocked)
        local own = {}
        for _, e in ipairs(each) do own[e.role] = e.span end
        local where = unlocked and "unlocked" or "locked"
        assertNear(own.pdebuffs.top, own.pbuffs.top, 0.5, where .. ": one top line")
        assertNear(own.pbuffs.left - own.pdebuffs.right, 2, 0.5, where .. ": the seam's 2 between the two")
    end
end)

test("presets data: the target column sits 104 left of the focus column", function()
    local P = NS.PresetData
    -- red under: section 17's target column, hung from the right edge; section 18's 50, before the
    -- owner's 2026-11-17 baseline moved the target column in
    assertEqual(P.STACKS.right.anchor, "CENTER", "the target column hangs from the screen's center")
    assertEqual(P.STACKS.focus.x - (P.STACKS.right.x + P.STACKS.right.width), 104, "104 between the columns")
    for _, scr in ipairs(SCREENS) do
        local W, H = scr[1], scr[2]
        local kx = P.ScaleX(W, H)
        for _, name in ipairs(WITH_TARGET) do
            for _, look in ipairs(P.LOOKS) do
                local where = ("%s/%s at %dx%d"):format(name, look, W, H)
                local heads = headsOf(P, name, look, W, H)
                local focusLeft = edgesAt("focus", W, H)
                -- The target head's right edge is its column's: a bar fills it, an Icons row grows
                -- left from it. red under: section 16's target column, 280 right of the center line
                -- A head placed by its CENTER (the owner's baseline) has its edges on half pixels.
                local _, targetRight = edgesAt("right", W, H)
                assertNear(heads.right[2], targetRight, 1, where)
                -- 104 at 1080 tall; since the columns keep their 240 and their places scale
                -- (presets restack spec section 3), the gap is the scaled distance between the two
                -- columns' places less the widths: wider on a taller screen, narrower on a shorter.
                -- The two places 586.8 apart less Player debuffs' 2.8, scaled, less the three
                -- half-widths and the focus column's width between them (480): 104 at a scale of 1.
                local gap = (P.STACKS.cornerRight.x - P.STACKS.right.x - P.CORNER_GAP) * kx - 480
                assertNear(focusLeft - heads.right[2], gap, 1, where .. ": the gap to the focus column")
                if fits(W, H) then assertTrue(focusLeft - heads.right[2] >= 104 - 1, where .. ": at least 104") end
            end
        end
    end
    -- Measured in test mode, as placed: 104 at 1920 x 1080 between the two stacks' blocks.
    local env, mocks = env1()
    local spans = sampleSpans(env, mocks, "advanced", "bars", 1920, 1080)
    assertNear(spans.focus.left - spans.right.right, 104, 0.5, "advanced/bars: 104 between the stacks")
end)

-- WHERE THE TARGET STACK'S TOP SITS (spec section 17.1): its base is on the player stack's (since the
-- owner's 2026-11-17 baseline over the far stack's bottom line), and its test-mode top lines up with Player debuffs (all)'s top as closely as its height allows. A
-- target stack is as tall as its containers, so its top is at or under Player debuffs' everywhere,
-- but where the stack is taller than the room: TOP_OVER names each, with how far its top sits over
-- Player debuffs' top, exactly. Advanced (Bars) on a 768-tall screen also runs off the top edge
-- (the placement case's OFF_TOP), and unlocked on a 1080-tall one its seven drag strips take it 62
-- over. TOP_UNDER pins the owner's preview, Advanced (Bars) at 1080 locked, 18 under. The owner's
-- 2026-11-17 baseline raised the target base and lowered the corner group, the members flush (no
-- gap of their own), Target special (mine) at the base and Target stealable, stored off, last.
local TOP_OVER = {
    ["advanced/bars 768"] = 153, ["advanced/bars 768 unlocked"] = 233,
    ["advanced/bars 1080 unlocked"] = 62,
}
local TOP_UNDER = { ["advanced/bars 1080"] = 18 }

--- The target stack's test-mode top against Player debuffs' for preset `name` in style `look` on a
--- W x H parent, against TOP_OVER and TOP_UNDER.
local function checkTargetTop(env, mocks, name, look, W, H, unlocked)
    local spans, each = sampleSpans(env, mocks, name, look, W, H, unlocked)
    local pd
    for _, e in ipairs(each) do
        if e.role == "pdebuffs" then pd = e.span end
    end
    local key = ("%s/%s %d%s"):format(name, look, H, unlocked and " unlocked" or "")
    local over, where = spans.right.top - pd.top, key .. (" at %dx%d"):format(W, H)
    if TOP_OVER[key] then
        assertNear(over, TOP_OVER[key], 0.5, where .. ": the recorded distance over Player debuffs' top")
    else
        assertTrue(over <= 0.5, ("%s: the target stack's top %d over Player debuffs'"):format(where, over))
    end
    if TOP_UNDER[key] then
        assertNear(-over, TOP_UNDER[key], 0.5, where .. ": the recorded distance under Player debuffs' top")
    end
end

test("presets data: the target stack's base is on the far stack's bottom line and its test-mode top near Player debuffs' top", function()
    local P = NS.PresetData
    for _, scr in ipairs(SCREENS) do
        local W, H = scr[1], scr[2]
        for _, name in ipairs(WITH_TARGET) do
            for _, look in ipairs(P.LOOKS) do
                local heads, where = headsOf(P, name, look, W, H), ("%s/%s at %dx%d"):format(name, look, W, H)
                -- Since the owner's 2026-11-17 baseline the player and target bases sit higher than the
                -- far stack's, each head's middle 153 under the screen's center; still one line.
                -- The far pair's head sits by its top `lift` over the far base (the owner's second
                -- 2026-11-23 change), so the base is that less the lift.
                if heads.far then
                    assertTrue(heads.right[3] > heads.far[3] - P.STACKS.far.lift, where .. ": over the far stack's base")
                end
                assertNear(heads.right[3], heads.left[3], 0.5, where .. ": the player stack's base (half an icon's rounding)")
            end
        end
    end
    for _, scr in ipairs(SCREENS) do
        local env, mocks = env1()
        for _, name in ipairs(WITH_TARGET) do
            for _, look in ipairs(P.LOOKS) do
                for _, unlocked in ipairs({ false, true }) do
                    checkTargetTop(env, mocks, name, look, scr[1], scr[2], unlocked)
                end
            end
        end
    end
end)

-- THE BAR WIDTH (the owner's 2026-11-23 feedback, presets restack spec section 3): "Make the default
-- width of the bars to be 240px ... dont do dynamic resizing basis screen width". Every bars
-- container is 240 wide on every screen, the call-out line's stored width 400, and an Icons preset's
-- rows the owner's 24 a side, ten to the column.
test("presets data: bars are 240 wide on every screen", function()
    local P = NS.PresetData
    local n = 0
    local screens = { { 1366, 768 }, { 1920, 1080 }, { 3440 / 1.2, 1200 }, { 2560, 1440 }, { 1440, 1080 } }
    for _, scr in ipairs(screens) do
        for _, name in ipairs(PRESETS) do
            for _, look in ipairs(P.LOOKS) do
                for _, spec in ipairs(P.Build(name, look, scr[1], scr[2])) do
                    local o, what = spec.overrides, ("%s/%s %s at %dx%d"):format(name, look, spec.role, scr[1], scr[2])
                    if o.style == "bars" then
                        n = n + 1
                        -- red under: the column scaled by the screen's height (266 at 1200 tall)
                        assertEqual(o.bars.width, 240, what)
                    elseif o.style == "text" then
                        assertEqual(o.text.width, 400, what .. ": the call-out column")
                    elseif look == "icons" and P.STACKS[spec.stack].width == 240 and o.layout.perLine == 10 then
                        assertEqual(o.icons.width, 24, what .. ": ten of the owner's 24 fill the column")
                    end
                end
            end
        end
    end
    assertTrue(n > 0, "the case saw bars")
end)

-- THE FAR PAIR (the owner's second 2026-11-23 change): "[18] Target buffs all: anchored to the
-- screen, at about the position it shows today. [17] Target debuffs all: anchored to [18], its
-- BOTTOMLEFT to this container's TOPLEFT", flush (the seam leaves the gap the towers use). The pair
-- now grows down from [18]'s top, where its top showed (two rows of the owner's 24 over the base, as
-- the two sample rows filled it), so a filling [18] pushes [17] down and nothing runs into it.
test("presets data: the far pair hangs Target debuffs (all) under Target buffs (all)", function()
    local P = NS.PresetData
    for _, scr in ipairs({ { 1920, 1080 }, { 3440 / 1.2, 1200 }, { 1366, 768 }, { 2560, 1440 } }) do
        local W, H = scr[1], scr[2]
        for _, look in ipairs(P.LOOKS) do
            local adv, where = {}, ("advanced/%s at %dx%d"):format(look, W, H)
            for i, spec in ipairs(P.Build("advanced", look, W, H)) do
                spec.index = i
                adv[spec.role] = spec
            end
            local B, D = adv.ticoB, adv.ticoD
            -- red under: [17] the head and [18] above it, as before
            assertEqual(D.index, 17, where .. ": Target debuffs (all) keeps 17")
            assertEqual(B.index, 18, where .. ": Target buffs (all) keeps 18")
            assertEqual(B.attachTo, nil, where .. ": [18] is placed on the screen")
            assertEqual(B.overrides.attach.mode, "screen", where)
            local pos = B.overrides.position
            assertEqual(pos.point, "TOPLEFT", where .. ": by its top left")
            assertEqual(pos.relativePoint, "TOP", where)
            assertEqual(pos.x, math.floor(P.Columns(W, H).far.x * P.ScaleX(W, H) + 0.5), where .. ": on the far column")
            assertEqual(pos.y, math.floor(-740 * P.Scale(H) + 0.5) + 48, where .. ": two rows over the base, where its top showed")
            assertEqual(B.overrides.layout.growV, "down", where .. ": the pair grows down")
            assertEqual(D.overrides.layout.growV, "down", where)
            assertEqual(D.attachTo, 18, where .. ": [17] hangs from [18]")
            local at = D.overrides.attach
            assertEqual(at.mode, "container", where)
            assertEqual(at.childPoint, "TOPLEFT", where .. ": its top left")
            assertEqual(at.relPoint, "BOTTOMLEFT", where .. ": to [18]'s bottom left")
            assertEqual(at.x, 0, where .. ": flush")
            assertEqual(at.y, 0, where .. ": flush")
        end
    end
    -- Applied, [17] stores [18]'s id, and the display order is still the numbering.
    local env, mocks = env1()
    local c = appliedByRole(env, "advanced", "bars", 1920, 1080)
    assertEqual(tonumber(c.ticoD.attach.container), c.ticoB.id, "stored: [17] on [18]'s id")
    assertTrue(c.ticoD.id < c.ticoB.id, "[17] created first")
    -- In test mode, locked, [17]'s top meets [18]'s bottom, and the pair's bottom is the base (740
    -- down at 1080), where [17]'s was.
    local _, each = sampleSpans(env, mocks, "advanced", "bars", 1920, 1080)
    local own = {}
    for _, e in ipairs(each) do own[e.role] = e.span end
    assertNear(own.ticoD.top, own.ticoB.bottom, 0.5, "[17] under [18], flush")
    assertNear(own.ticoD.bottom, -740, 0.5, "the pair ends on the base")
end)

test("presets data: Realize refuses a forward attach whose parent took another id", function()
    local P = NS.PresetData
    local specs = P.Build("advanced", "bars", 1920, 1080)
    local next = 100
    -- red under: a forward link left on a placeholder, or on a guessed id the writer did not hand out
    local made, msg = P.Realize(specs, nil, function()
        next = next + ((next == 116) and 2 or 1)
        return next
    end)
    assertEqual(made, nil, "refused")
    assertTrue(type(msg) == "string", "with a reason")
    local ids, seen = {}, 0
    assertTrue(P.Realize(P.Build("advanced", "bars", 1920, 1080), nil, function(o)
        seen = seen + 1
        ids[seen] = o
        return 200 + seen
    end) == #specs, "consecutive ids realize every spec")
    assertEqual(ids[17].attach.container, 218, "[17] on the id [18] took")
end)

test("presets data: every bar container is as wide as Player cooldowns", function()
    local P = NS.PresetData
    local L = P.STACKS.left
    assertEqual(L.width, 240, "Player cooldowns' column, the player stack's")
    -- Every column that holds bars in any preset is that wide (spec section 17.2), so the edges the
    -- cluster lines up are each column's.
    local holdsBars = {}
    for _, name in ipairs(PRESETS) do
        for _, spec in ipairs(P.Build(name, "bars", 1920, 1080)) do
            if spec.overrides.style == "bars" then holdsBars[spec.stack] = true end
        end
    end
    for stack in pairs(holdsBars) do
        -- red under: Player buffs' and Weapon enchants' 175, Player debuffs' and the focus stack's 215
        assertEqual(P.STACKS[stack].width, 240, stack .. " holds bars: 240 wide")
    end
    for _, scr in ipairs(SCREENS) do
        local W, H = scr[1], scr[2]
        -- red under: the column scaled by the screen (presets restack spec section 3)
        local want = L.width
        for _, name in ipairs(PRESETS) do
            local seen = 0
            for _, spec in ipairs(P.Build(name, "bars", W, H)) do
                local o = spec.overrides
                if o.style == "bars" then
                    seen = seen + 1
                    assertNear(o.bars.width, want, 1, ("%s/bars %s at %dx%d: Player cooldowns' width"):format(name,
                        spec.role, W, H))
                end
            end
            assertTrue(seen > 0, name .. " has bars")
            -- Icon rows keep filling their column: a full row is the column, less a pixel an icon.
            for _, spec in ipairs(P.Build(name, "icons", W, H)) do
                local o = spec.overrides
                -- The far stack's own icon rows keep the owner's eight of 24 (defaults/Presets.lua sizeTo).
                if o.style == "icons" and spec.stack ~= "far" then
                    local row = o.layout.perLine * (o.icons.width + o.layout.spacing)
                    local column = P.STACKS[spec.stack].width
                    local where = ("%s/icons %s at %dx%d"):format(name, spec.role, W, H)
                    assertTrue(row <= column + 1 and row > column - o.layout.perLine - 1, where .. ": its row fills its column")
                end
            end
        end
    end
    -- Applied, the stored widths agree: every bar container of Advanced as wide as Player cooldowns.
    local c = appliedByRole(env1(), "advanced", "bars", 1920, 1080)
    for role, cfg in pairs(c) do
        if cfg.style == "bars" then assertEqual(cfg.bars.width, c.pcd.bars.width, role .. ": stored as wide") end
    end
end)

-- THE CALL-OUT BLOCK AND THE TARGET COLUMN (spec sections 17.1 and 18.2). The call-outs keep the
-- screen's center. The target column mirrors the player column, 40 clear of the call-out column, but
-- where the cluster does not fit at the mirror it moves left with it (16:9 and narrower), and there,
-- at 1920 x 1080 by 25, it reaches the block. The call-out column was narrowed first, 480 to 400,
-- never below the widest test-mode line at the owner's 36. Each entry, by look and screen, unlocked
-- in test mode, is how far across the two overlap where their heights meet, Advanced's exactly and
-- the most any preset may (Healer's call-out overlaps as far across); a screen not named has none.
-- Measured over the stored line width, which stands in game only where a
-- line cannot be measured: with Size to fit the block is its widest line, narrower. Recorded in
-- docs/known-limitations.md (presets).
-- Re-measured on the owner's 2026-11-17 baseline, which moved the target column 54 nearer the center
-- line (the mirror at 186, 14 into the stored call-out column), so it meets the block on every screen.
-- Icons re-measured when an icon row's drag strip became its whole row's width (Anchors.RowSpan,
-- 2026-11-17): it no longer overhangs the row toward the center line, so Icons shares less.
-- Re-measured on the owner's 2026-11-23 feedback (presets restack spec section 3): the columns keep
-- their 240 and only their places scale, so the overlap grows where the scale is under 1 (every
-- 768-tall screen, 4:3 and 5:4 at 1080, where the target column can lie wholly under the block) and
-- shrinks to none on 16:9 and wider at 1440 tall.
local CALLOUT_OVER_RIGHT = {
    ["bars 1024x768"] = 240, ["bars 1228x768"] = 240, ["bars 1350x1080"] = 240, ["bars 1365x768"] = 185,
    ["bars 1440x1080"] = 229, ["bars 1728x1080"] = 173, ["bars 1792x768"] = 102, ["bars 1800x1440"] = 174,
    ["bars 1920x1080"] = 77, ["bars 1920x1440"] = 155, ["bars 2304x1440"] = 80, ["bars 2520x1080"] = 14,
    ["bars 960x768"] = 240, ["icons 1024x768"] = 144, ["icons 1228x768"] = 144, ["icons 1350x1080"] = 144,
    ["icons 1365x768"] = 89, ["icons 1440x1080"] = 133, ["icons 1728x1080"] = 77, ["icons 1792x768"] = 6,
    ["icons 1800x1440"] = 78, ["icons 1920x1440"] = 59, ["icons 960x768"] = 144,
}

-- Every other stack the call-out block shares area with, unlocked in test mode (spec section 18.3 put
-- the block's top at the preset picker's, beside the corner group's): since the owner's 2026-11-17
-- baseline the player column in Bars, mirroring the target column 14 into the stored 400. Icons
-- shares nothing since an icon row's drag strip spans its row (Anchors.RowSpan) instead of
-- overhanging it. Advanced's exactly, the most any preset may. Recorded in
-- docs/known-limitations.md (presets).
-- Re-measured on the owner's 2026-11-23 feedback as above: where the scale is under 1 the cluster's
-- columns reach the block too; at 1440 tall the player column no longer does.
local CALLOUT_OVER_OTHER = {
    ["cornerLeft bars 1024x768"] = 180, ["cornerLeft bars 1228x768"] = 78, ["cornerLeft bars 1350x1080"] = 17,
    ["cornerLeft bars 1365x768"] = 9, ["cornerLeft bars 960x768"] = 212, ["cornerLeft icons 1024x768"] = 82,
    ["cornerLeft icons 960x768"] = 114, ["far bars 1024x768"] = 144, ["far bars 1228x768"] = 78,
    ["far bars 1350x1080"] = 17, ["far bars 1365x768"] = 9, ["far bars 960x768"] = 144,
    ["far icons 1024x768"] = 144, ["far icons 1228x768"] = 78, ["far icons 1350x1080"] = 17,
    ["far icons 1365x768"] = 9, ["far icons 960x768"] = 144, ["focus bars 1024x768"] = 180,
    ["focus bars 1228x768"] = 78, ["focus bars 1350x1080"] = 17, ["focus bars 1365x768"] = 9,
    ["focus bars 960x768"] = 212, ["focus icons 1024x768"] = 84, ["focus icons 960x768"] = 116,
    ["left bars 1024x768"] = 135, ["left bars 1228x768"] = 102, ["left bars 1350x1080"] = 76,
    ["left bars 1365x768"] = 102, ["left bars 1440x1080"] = 60, ["left bars 1728x1080"] = 14,
    ["left bars 1792x768"] = 102, ["left bars 1920x1080"] = 14, ["left bars 2520x1080"] = 14,
    ["left bars 960x768"] = 147, ["left icons 1024x768"] = 15, ["left icons 960x768"] = 27,
}

--- How far across rectangles `a` and `b` (sampleSpans') share area, 0 when they do not.
local function sharedAcross(a, b)
    if not (a.bottom < b.top and b.bottom < a.top) then return 0 end
    return math.max(0, math.min(a.right, b.right) - math.max(a.left, b.left))
end

--- No stack in `spans` but the target column shares more area with the call-out block than
--- CALLOUT_OVER_OTHER records for `look` on a W x H parent; Advanced (`exact`) shares exactly that.
local function checkCalloutOthers(spans, where, look, W, H, exact)
    for stack, span in pairs(spans) do
        if stack ~= "middle" and stack ~= "right" then
            local key = ("%s %s %dx%d"):format(stack, look, W, H)
            local across, most = sharedAcross(spans.middle, span), CALLOUT_OVER_OTHER[key] or 0
            local what = ("%s: the call-outs share %.1f with %s"):format(where, across, stack)
            assertTrue(across <= most + 0.5, what .. ", past " .. most)
            if exact then assertNear(across, most, 0.5, what) end
        end
    end
end

test("presets data: the call-out block's overlap with the target column is the recorded one", function()
    local P = NS.PresetData
    assertEqual(P.STACKS.middle.width, 400, "the call-out column, narrowed from 480")
    for _, scr in ipairs(SCREENS) do
        local W, H = scr[1], scr[2]
        local env, mocks = env1()
        for _, name in ipairs({ "advanced", "healer" }) do
            for _, look in ipairs(P.LOOKS) do
                local spans = sampleSpans(env, mocks, name, look, W, H, true)
                local m, r = spans.middle, spans.right
                local across = sharedAcross(m, r)
                local key = ("%s %dx%d"):format(look, W, H)
                checkCalloutOthers(spans, name .. "/" .. key, look, W, H, name == "advanced")
                local most, where = CALLOUT_OVER_RIGHT[key] or 0, name .. "/" .. key
                assertTrue(across <= most + 0.5, ("%s: the call-outs share %.1f with the target column, past %.1f"):format(
                    where, across, most))
                if name == "advanced" then assertNear(across, most, 0.5, where .. ": the recorded overlap") end
                -- The block keeps the screen's center.
                assertNear((m.left + m.right) / 2, W / 2, 0.5, where .. ": the call-outs centered")
            end
        end
    end
    -- Nothing else in the cluster meets the call-outs or the player stack: the heads say so on every
    -- screen (the placement case's SHARED_COLUMNS), and the cluster keeps right of the center line,
    -- moved left of the mirror only as far as it must (spec section 18.2).
    for _, scr in ipairs(SCREENS) do
        local W, H = scr[1], scr[2]
        local heads = headsOf(P, "advanced", "bars", W, H)
        -- Where the 240-wide columns fit (PS.fits; docs/known-limitations.md for the others).
        if fits(W, H) then
            assertTrue(heads.right[1] >= W / 2 + 10 - 1, ("%dx%d: the cluster right of center"):format(W, H))
        end
        assertNil(heads.cornerLeft, "Player debuffs is no head")
    end
end)

-- ---------------------------------------------------------------------------
-- Spec section 18, the owner's round-4 feedback: the player stack nearer the center, the target
-- cluster mirroring it from the center line, clamped left only where it would not fit.
-- ---------------------------------------------------------------------------

-- The reference layout of section 18 as the owner's 2026-11-17 baseline moved it: the player column
-- 240 wide, its right edge 186 left of the center line (14 into the call-out column, -200); the
-- target column's left edge 186 right of it; the cluster's right edge, Player buffs', 1012.8 right
-- of it (186 + 240 + 104 + 240 + 2.8 + 240); Player buffs at least 10 in from the screen's right edge.
local MIRROR, CLUSTER_RIGHT, EDGE_IN = 186, 1012.8, 10

--- The x the cluster's Player buffs right edge sits at on a W x H parent: the mirror's, or, where that
--- runs past EDGE_IN from the right edge, EDGE_IN in (spec section 18.2). Its middle is placed by the
--- scale and its half-width is not (presets restack spec section 3).
local function clusterRightAt(P, W, H)
    local kx, half = P.ScaleX(W, H), P.STACKS.cornerRight.width / 2
    return math.min(W / 2 + (CLUSTER_RIGHT - half) * kx + half, W - EDGE_IN)
end

test("presets data: the player column reaches 14 into the call-out column", function()
    local P = NS.PresetData
    local L, M = P.STACKS.left, P.STACKS.middle
    -- red under: section 17's player column, -520..-280, 80 from the call-out column, and section
    -- 18's -480..-240, 40 from it; the owner's 2026-11-17 baseline put its middle at -306
    assertEqual(L.x, -426, "the player column's left edge")
    assertEqual(L.x + L.width, -186, "its right edge")
    assertEqual(M.x - (L.x + L.width), -14, "14 into the call-out column's stored 400")
    assertEqual(L.anchor, "CENTER", "it hangs from the screen's center")
    for _, scr in ipairs(SCREENS) do
        local W, H = scr[1], scr[2]
        local kx = P.ScaleX(W, H)
        for _, name in ipairs(PRESETS) do
            for _, look in ipairs(P.LOOKS) do
                local heads = headsOf(P, name, look, W, H)
                local where = ("%s/%s at %dx%d"):format(name, look, W, H)
                if heads.left then
                    -- A bar fills the column; an Icons row grows right from its left edge. The
                    -- column's middle, -306, is placed by the scale, its 240 is not (presets restack
                    -- spec section 3). red under: the scaled column, -426 * kx
                    assertNear(heads.left[1], W / 2 - 306 * kx - 120, 1, where .. ": the player column's left edge")
                    local slack = (look == "icons") and (240 / 24 + 1) or 0
                    assertTrue(math.abs(heads.left[2] - (W / 2 - 306 * kx + 120)) <= 1 + slack, where .. ": its right edge")
                end
            end
        end
    end
end)

test("presets data: the target column mirrors the player column where the cluster fits", function()
    local P = NS.PresetData
    for _, H in ipairs({ 768, 1080, 1440 }) do
        local W = H * 21 / 9
        local k = P.Scale(H)
        assertEqual(P.ScaleX(W, H), k, "21:9 is not narrowed")
        assertTrue(W / 2 + CLUSTER_RIGHT * k <= W - EDGE_IN * k, "the whole cluster fits at the mirror")
        for _, name in ipairs(WITH_TARGET) do
            for _, look in ipairs(P.LOOKS) do
                local heads, where = headsOf(P, name, look, W, H), ("%s/%s at %dx%d"):format(name, look, W, H)
                -- The target head's right edge is its column's (a bar fills it, an Icons row grows
                -- left from it), so the column's left edge is that less its width.
                local targetLeft = heads.right[2] - P.STACKS.right.width
                local playerRight = (look == "bars") and heads.left[2] or (W / 2 + select(2, columnEdges("left", W, H)))
                -- red under: section 17's target column, hung 785 in from the right edge
                assertNear(targetLeft - W / 2, W / 2 - playerRight, 1, where .. ": the mirror of the player column")
                -- Its middle 306 right of the center line, scaled; 186 at 1080 tall.
                assertNear(targetLeft, W / 2 + (MIRROR + 120) * k - 120, 1, where .. ": the mirror's place")
                assertEqual(P.ClusterShift(W, H), 0, where .. ": no shift")
            end
        end
        -- Player buffs at the mirror's end of the cluster, 1012.8 right of the center line at 1080.
        local pb = headsOf(P, "simple", "bars", W, H).cornerRight
        assertNear(pb[2], W / 2 + (CLUSTER_RIGHT - 120) * k + 120, 1, ("%dx%d: Player buffs at the mirror's end"):format(W, H))
    end
    -- The cluster hangs from the center line now (a TOP or the screen's CENTER), so the mirror holds
    -- wherever the screen is wide.
    for _, spec in ipairs(P.Build("advanced", "bars", 2560, 1080)) do
        if not spec.attachTo and spec.stack ~= "middle" then
            local rel = spec.overrides.position.relativePoint
            assertTrue(rel == "TOP" or rel == "CENTER", spec.role .. " hangs from the center line")
        end
    end
end)

test("presets data: the cluster moves left just enough to fit on narrower screens", function()
    local P = NS.PresetData
    local S = P.STACKS
    for _, scr in ipairs(SCREENS) do
        local W, H = scr[1], scr[2]
        local kx = P.ScaleX(W, H)
        local atMirror = W / 2 + (CLUSTER_RIGHT - 120) * kx + 120 <= W - EDGE_IN
        local want = clusterRightAt(P, W, H)
        local shift = P.ClusterShift(W, H)
        local where = ("%dx%d"):format(W, H)
        assertTrue(shift <= 0, where .. ": the cluster only ever moves left")
        assertEqual(shift == 0, atMirror, where .. ": it moves only where the mirror does not fit")
        local pb = headsOf(P, "simple", "bars", W, H).cornerRight
        -- red under: a cluster hung from the right edge (no move) or one left at the mirror (off screen)
        assertNear(pb[2], want, 1, where .. ": Player buffs' right edge, the mirror's or 10 in")
        assertTrue(pb[2] <= W - EDGE_IN + 0.5, where .. ": at least 10 in from the right edge")
        for _, name in ipairs(WITH_TARGET) do
            local heads = headsOf(P, name, "bars", W, H)
            local w = ("%s/bars at %s"):format(name, where)
            -- Every alignment kept: the focus and far columns on Player debuffs' left edge, Player
            -- debuffs 2.8 (scaled) left of Player buffs, each column 240. The gap to the target column
            -- is the case above's.
            local gap = P.CORNER_GAP
            local focusLeft = heads.focus and heads.focus[1] or (pb[1] - gap * kx - 240)
            assertNear(pb[1] - (focusLeft + 240), gap * kx, 1, w .. ": 2.8 to Player buffs")
            if heads.far then assertNear(heads.far[1], focusLeft, 1, w .. ": the far column on the focus one") end
            -- Moved by the same amount as the rest: closer to the center than the mirror, never past
            -- 10 right of the center line where the columns fit (PS.fits).
            assertTrue(heads.right[1] <= W / 2 + (MIRROR + 120) * kx - 120 + 1, w .. ": no further right than the mirror")
            if fits(W, H) then
                assertTrue(heads.right[1] >= W / 2 + EDGE_IN - 1, w .. ": right of the center line")
            end
        end
        -- The columns as stored: the cluster hangs from the center line, shifted by the same amount;
        -- a `leftOf` column keeps its right edge CORNER_GAP left of Player buffs' (P.Columns).
        local cols = P.Columns(W, H)
        local ANCHOR = { right = "CENTER", focus = "TOP", far = "TOP", cornerLeft = "TOP", cornerRight = "CENTER" }
        for _, key in ipairs({ "right", "focus", "far", "cornerLeft", "cornerRight" }) do
            assertEqual(cols[key].anchor, ANCHOR[key], where .. " " .. key .. " hangs from the center line")
            if S[key].leftOf then
                local pbLeft = select(1, columnEdges("cornerRight", W, H))
                assertNear(cols[key].x * kx + 240, pbLeft - P.CORNER_GAP * kx, 1e-6, where .. " " .. key .. " beside Player buffs")
            else
                assertNear(cols[key].x, S[key].x + shift, 1e-9, where .. " " .. key .. " moved with the cluster")
            end
        end
        assertEqual(cols.left.x, S.left.x, where .. ": the player column never moves")
    end
    assertEqual(S.right.x, MIRROR, "the target column's reference place is the mirror")
    assertNear(S.cornerRight.x + S.cornerRight.width, CLUSTER_RIGHT, 1e-9, "the cluster ends 1012.8 right of the center")
end)

test("presets data: the call-out block starts at about the picker's top", function()
    -- Its own environment: the case narrows the size range to probe the next size up.
    local P = freshEnv().PresetData
    local R = P.ROOM
    local max, min = P.CALLOUT_SIZE_MAX, P.CALLOUT_SIZE_MIN
    for _, H in ipairs({ 768, 1080, 1440 }) do
        for _, ratio in ipairs({ 16 / 9, 21 / 9 }) do
            local W = H * ratio
            -- The preset picker's top, down from the screen's top edge: its CENTER 75% up (spec 15.1).
            local pickerTop = H * (1 - R.skinShare) - R.pickerHeight / 2
            for _, name in ipairs({ "advanced", "healer" }) do
                for _, look in ipairs(P.LOOKS) do
                    local r, where = P.CalloutRect(name, look, W, H), ("%s/%s at %dx%d"):format(name, look, W, H)
                    local top, bottom = H - r.top, H - r.bottom
                    -- red under: section 15.1's block, under the picker
                    assertNear(top, math.max(R.margin, pickerTop), 0.5, where .. ": the block's top at the picker's")
                    assertTrue(bottom <= H - R.margin + 0.5, where .. ": a margin over the bottom edge")
                    assertNear((r.left + r.right) / 2, W / 2, 0.001, where .. ": centered across")
                    if r.fontSize < max then
                        P.CALLOUT_SIZE_MAX, P.CALLOUT_SIZE_MIN = r.fontSize + 1, r.fontSize + 1
                        local bigger = P.CalloutRect(name, look, W, H)
                        P.CALLOUT_SIZE_MAX, P.CALLOUT_SIZE_MIN = max, min
                        assertTrue(H - bigger.bottom > H - R.margin + 0.5 or bigger.top ~= r.top,
                            where .. ": one size larger would run past the bottom margin")
                    end
                end
            end
        end
    end
    -- At 1080 Advanced now takes the owner's 36 (it fell to 24 under the picker in section 15.1).
    assertEqual(P.CalloutRect("advanced", "bars", 1920, 1080).fontSize, 36, "Advanced at the owner's size")
end)
-- THE OWNER'S SMOKETEST BASELINE (2026-11-17): Advanced (Bars), built on their own screen (3440 x
-- 1440 at UI scale 1.2, a parent 1200 tall), places every head where their WoW Forever SmokeTest
-- profile holds it, by the same points, and gives the icons, joins and colors that profile has.
test("presets data: Advanced on the owner's screen is their SmokeTest profile", function()
    local P = NS.PresetData
    local adv = {}
    for i, spec in ipairs(P.Build("advanced", "bars", 3440 / 1.2, 1200)) do
        spec.index = i
        adv[spec.role] = spec
    end
    local HEADS = {
        pbuffs = { "CENTER", "CENTER", 992, 490 }, txtOff = { "TOP", "TOP", 0, -140 },
        pspec = { "CENTER", "CENTER", -340, -170 }, tspec = { "CENTER", "CENTER", 340, -170 },
        -- The focus and far heads on Player debuffs' left edge, 629 since the bars are 240 on every
        -- screen (presets restack spec section 3): Player buffs' middle stays at 992, its half-width
        -- and Player debuffs' are 120 where they were 133. red under: the scaled columns' 589
        -- Since the owner's second 2026-11-23 change [18] Target buffs (all) heads the far pair, by
        -- its top left where its top showed, two rows (48) over the base. red under: [17] the head
        ticoB = { "TOPLEFT", "TOP", 629, -774 }, fdeb = { "BOTTOMLEFT", "TOP", 629, -611 },
    }
    for role, want in pairs(HEADS) do
        local s = adv[role]
        local pos = s.overrides.position
        -- red under: the pre-baseline corner, player and target places (TOPLEFT/BOTTOMLEFT from TOP)
        assertNil(s.attachTo, role .. " heads its stack")
        assertEqual(pos.point, want[1], role .. " point")
        assertEqual(pos.relativePoint, want[2], role .. " relative point")
        assertEqual(pos.x, want[3], role .. " x")
        assertEqual(pos.y, want[4], role .. " y")
    end
    -- The chains: each member on the one before it, as the profile attaches them, both towers in the
    -- owner's 2026-11-23 order (presets restack spec section 3).
    local CHAIN = {
        wpn = "pbuffs", pdebuffs = "pbuffs", txtDef = "txtOff", txtRaid = "txtDef", pcd = "pspec",
        pshort = "pcd", tcc = "tspec", tcdp = "tcc", tcdn = "tcdp", tdeb = "tcdn", tbuff = "tdeb",
        tsteal = "tbuff", ticoD = "ticoB", fbuff = "fdeb",
    }
    for role, parent in pairs(CHAIN) do
        assertEqual(adv[role].attachTo, adv[parent].index, role .. " on " .. parent)
    end
    assertEqual(adv.pdebuffs.overrides.attach.childPoint, "TOPRIGHT")
    assertEqual(adv.pdebuffs.overrides.attach.relPoint, "TOPLEFT")
    assertEqual(adv.pdebuffs.overrides.attach.x, 0, "Player debuffs flush beside Player buffs")
    -- red under: the 6-unit call-out gap (7 on the owner's screen) before their 2026-11-17 follow-up
    for _, role in ipairs({ "txtDef", "txtRaid" }) do
        assertEqual(adv[role].overrides.attach.y, 0, role .. ": flush under the one before, the owner's")
    end
    assertEqual(adv.ticoD.overrides.attach.childPoint, "TOPLEFT")
    assertEqual(adv.ticoD.overrides.attach.relPoint, "BOTTOMLEFT")
    for _, role in ipairs({ "ticoD", "ticoB" }) do
        assertEqual(adv[role].overrides.icons.width, 24, role .. ": the owner's 24")
        assertEqual(adv[role].overrides.icons.height, 24, role)
        assertEqual(adv[role].overrides.layout.perLine, 8, role .. ": eight a row")
    end
    -- The bar width: 240 on every screen since the owner's 2026-11-23 feedback (presets restack spec
    -- section 3), where the profile's columns held 266 and 267, the column scaled by 1200 / 1080.
    -- red under: the scaled column width
    assertEqual(adv.pcd.overrides.bars.width, 240, "Player cooldowns")
    assertEqual(adv.fdeb.overrides.bars.width, 240, "Focus debuffs (mine)")
    -- Dispel coloring where the profile has it, One color everywhere else.
    for _, role in ipairs({ "pdebuffs", "tdeb", "fdeb" }) do
        assertEqual(adv[role].overrides.bars.colorMode, "dispel", role .. " by dispel type")
    end
    for _, role in ipairs({ "tcc", "tspec" }) do
        assertEqual(adv[role].overrides.bars.colorMode, "static", role .. ": One color, though a debuff bar")
    end
    -- red under: the template's blue the owner's 2026-11-23 second change replaced with #393939
    assertNear(adv.pspec.overrides.bars.barColor.r, 0x39 / 255, 1e-9, "Player special (mine) #393939")
    assertNear(adv.tspec.overrides.bars.barColor.g, 0x39 / 255, 1e-9, "Target special (mine) #393939")
    assertNil(adv.pshort.overrides.bars.barColor, "and Player buffs, short, since 2026-11-23")
end)
