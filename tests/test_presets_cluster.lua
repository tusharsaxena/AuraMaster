-- tests/test_presets_cluster.lua -- the right-hand cluster lined up, Player debuffs (all) joined to
-- Player buffs (all), and every bar container as wide as Player cooldowns (AM-PR16; presets spec
-- section 17.1 and 17.2). Peeled out of tests/test_presets_data.lua at layout-§1's 1500-line cap; the
-- screens and the test-mode readers both use are tests/presets_spans.lua's. A case that applies a
-- preset builds its own environment (tests/fresh_env.lua), one per screen where it walks them all, so
-- no environment grows by every Apply (the kit's leak gate). Every case runs under both kit profiles.

local freshEnv = dofile("tests/fresh_env.lua")
local PS = dofile("tests/presets_spans.lua")
local SCREENS, headRect, sampleSpans = PS.SCREENS, PS.headRect, PS.sampleSpans

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

--- The x a column's edge `x` (reference units, from the anchor) is placed at on a W x H parent, as
--- defaults/Presets.lua's `place` rounds a head's offset.
local function edgeAt(P, x, W, H)
    return W + math.floor(x * P.ScaleX(W, H) + 0.5)
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
            assertEqual(pb.position.relativePoint, "TOPRIGHT", where .. ": the corner group's head")
        end
    end
    -- In test mode Player debuffs' top is Player buffs' top, its right edge 5 left of Player buffs'
    -- left edge (spec section 4's gap between the corner columns), locked and unlocked.
    for _, unlocked in ipairs({ false, true }) do
        local _, each = sampleSpans(env, mocks, "simple", "bars", 1920, 1080, unlocked)
        local own = {}
        for _, e in ipairs(each) do own[e.role] = e.span end
        local where = unlocked and "unlocked" or "locked"
        assertNear(own.pdebuffs.top, own.pbuffs.top, 0.5, where .. ": one top line")
        assertNear(own.pbuffs.left - own.pdebuffs.right, 5, 0.5, where .. ": 5 between the two")
    end
end)

test("presets data: the target column sits 50 left of the focus column", function()
    local P = NS.PresetData
    assertEqual(P.STACKS.right.anchor, "TOPRIGHT", "the target column hangs from the right edge")
    assertEqual(P.STACKS.focus.x - (P.STACKS.right.x + P.STACKS.right.width), 50, "50 between the columns")
    for _, scr in ipairs(SCREENS) do
        local W, H = scr[1], scr[2]
        for _, name in ipairs(WITH_TARGET) do
            for _, look in ipairs(P.LOOKS) do
                local where = ("%s/%s at %dx%d"):format(name, look, W, H)
                local heads = headsOf(P, name, look, W, H)
                local focusLeft = edgeAt(P, P.STACKS.focus.x, W, H)
                -- The target head's right edge is its column's: a bar fills it, an Icons row grows
                -- left from it. red under: section 16's target column, 280 right of the center line
                assertNear(heads.right[2], edgeAt(P, P.STACKS.right.x + P.STACKS.right.width, W, H), 0.001, where)
                assertNear(focusLeft - heads.right[2], 50 * P.ScaleX(W, H), 1, where .. ": 50 to the focus column")
            end
        end
    end
    -- Measured in test mode, as placed: 50 at 1920 x 1080 between the two stacks' blocks.
    local env, mocks = env1()
    local spans = sampleSpans(env, mocks, "advanced", "bars", 1920, 1080)
    assertNear(spans.focus.left - spans.right.right, 50, 0.5, "advanced/bars: 50 between the stacks")
end)

-- WHERE THE TARGET STACK'S TOP SITS (spec section 17.1): its base is on the far stack's bottom line,
-- and its test-mode top lines up with Player debuffs (all)'s top as closely as its height allows. A
-- target stack is as tall as its containers, so its top is at or under Player debuffs' everywhere,
-- but where the stack is taller than the room: TOP_OVER names each, with how far its top sits over
-- Player debuffs' top, exactly. Advanced (Bars) on a 768-tall screen also runs off the top edge
-- (the placement case's OFF_TOP), and unlocked on a 1080-tall one its seven drag strips take it 10
-- over. TOP_UNDER pins the owner's preview, Advanced (Bars) at 1080 locked, 70 under.
local TOP_OVER = {
    ["advanced/bars 768"] = 121, ["advanced/bars 768 unlocked"] = 201,
    ["advanced/bars 1080 unlocked"] = 10,
}
local TOP_UNDER = { ["advanced/bars 1080"] = 70 }

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
                -- red under: a target base apart from the far stack's
                if heads.far then assertEqual(heads.right[3], heads.far[3], where .. ": the far stack's base") end
                assertEqual(heads.right[3], heads.left[3], where .. ": the player stack's base too")
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
        local kx = P.ScaleX(W, H)
        local want = math.floor((L.x + L.width) * kx + 0.5) - math.floor(L.x * kx + 0.5)
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
                if o.style == "icons" then
                    local row = o.layout.perLine * (o.icons.width + o.layout.spacing)
                    local column = P.STACKS[spec.stack].width * kx
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

-- THE CALL-OUT BLOCK AND THE TARGET COLUMN (spec section 17.1). The call-outs keep the screen's
-- center; the target column hangs from the right edge, so on 16:10 and narrower, and at 1920 x 1080
-- by 25, it reaches the block. The call-out column was narrowed first, 480 to 400, never below the
-- widest test-mode line at the owner's 36. Each entry, by look and screen, unlocked in test mode, is
-- how far across the two overlap where their heights meet, Advanced's exactly and the most any preset
-- may (Healer's call-out overlaps as far across); a screen not named, 21:9, has none. Measured over
-- the stored line width, which stands in game only where a line cannot be measured: with Size to fit
-- the block is its widest line, narrower. Recorded in docs/known-limitations.md (presets).
local CALLOUT_OVER_RIGHT = {
    ["bars 1365x768"] = 17.3, ["icons 1365x768"] = 48.3, ["bars 1228x768"] = 85.6, ["icons 1228x768"] = 116.6,
    ["bars 1024x768"] = 123, ["icons 1024x768"] = 159, ["bars 960x768"] = 115, ["icons 960x768"] = 156,
    ["bars 1920x1080"] = 25, ["icons 1920x1080"] = 31, ["bars 1728x1080"] = 121, ["icons 1728x1080"] = 127,
    ["bars 1440x1080"] = 172, ["icons 1440x1080"] = 186, ["bars 1350x1080"] = 162, ["icons 1350x1080"] = 179,
    ["bars 2560x1440"] = 34, ["icons 2560x1440"] = 10, ["bars 2304x1440"] = 162, ["icons 2304x1440"] = 138,
    ["bars 1920x1440"] = 230, ["icons 1920x1440"] = 216, ["bars 1800x1440"] = 215, ["icons 1800x1440"] = 209,
}

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
                local meet = m.bottom < r.top and r.bottom < m.top
                local across = meet and math.max(0, math.min(m.right, r.right) - math.max(m.left, r.left)) or 0
                local key = ("%s %dx%d"):format(look, W, H)
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
    -- screen (the placement case's SHARED_COLUMNS), and the cluster keeps right of the center line.
    for _, scr in ipairs(SCREENS) do
        local W, H = scr[1], scr[2]
        local heads = headsOf(P, "advanced", "bars", W, H)
        assertTrue(heads.right[1] >= W / 2 + 10 * P.ScaleX(W, H) - 1, ("%dx%d: the cluster right of center"):format(W, H))
        assertNil(heads.cornerLeft, "Player debuffs is no head")
    end
end)
