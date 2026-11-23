-- tests/test_presets_look.lua -- the presets' bar look and numbered names (spec sections 17.3 and
-- 17.4, recolored and renumbered by the owner's 2026-11-23 feedback: presets restack spec section 3).
-- Peeled out of tests/test_presets_data.lua at layout-§1's 1500-line cap. A case that applies a
-- preset builds its own environment (tests/fresh_env.lua). Every case runs under both kit profiles.

local freshEnv = dofile("tests/fresh_env.lua")

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil, assertNear =
    T.test, T.assertEqual, T.assertTrue, T.assertNil, T.assertNear
local NS = T.NS

local NAMES = { "empty", "simple", "intermediate", "advanced", "healer" }

-- THE ROLES' OWN BAR COLORS (the owner's 2026-11-17 SmokeTest baseline): these roles keep Fill > Color
-- by at One color, in a color of their own. Since the owner's 2026-11-23 feedback Player buffs, short
-- keeps the template's blue and every cooldown role is tan, Target cooldowns, players'.
local TAN = { 230, 204, 128 }
local OWNER_BAR_COLOR = {
    tspec = { 69, 69, 69 }, tcc = { 255, 128, 64 }, tcdp = TAN, tcdn = TAN, tcd = TAN, pcd = TAN,
    pcdHealer = TAN, wpn = { 163, 53, 238 },
}

-- ── the bar look and the numbered names (spec section 17.3-4) ─────────────────────────────────

test("presets data: debuff bars color by dispel type", function()
    local P = NS.PresetData
    local n = 0
    for _, name in ipairs(NAMES) do
        for _, look in ipairs(P.LOOKS) do
            for _, spec in ipairs(P.Build(name, look, 1920, 1080)) do
                local o, what = spec.overrides, ("%s/%s %s"):format(name, look, spec.role)
                if o.style == "bars" and OWNER_BAR_COLOR[spec.role] then
                    -- red under: the owner's colored roles left to the dispel or blue default
                    local want = OWNER_BAR_COLOR[spec.role]
                    assertEqual(o.bars.colorMode, "static", what .. ": Fill > Color by is One color")
                    assertNear(o.bars.barColor.r, want[1] / 255, 1e-9, what .. ": red")
                    assertNear(o.bars.barColor.g, want[2] / 255, 1e-9, what .. ": green")
                    assertNear(o.bars.barColor.b, want[3] / 255, 1e-9, what .. ": blue")
                    assertEqual(o.bars.barColor.a, 1, what .. ": opaque")
                    assertEqual(o.bars.barColorFromSkin, false, what .. ": the skin does not decide it")
                    assertEqual(o.bars.useClassColorBar, false, what .. ": nor the class color")
                elseif o.style == "bars" and o.auraType == "HARMFUL" then
                    n = n + 1
                    -- red under: a debuff bar left to the template's "static" fill
                    assertEqual(o.bars.colorMode, "dispel", what .. ": Fill > Color by is By dispel type")
                elseif o.style == "bars" then
                    assertEqual(o.bars.colorMode, "static", what .. ": a buff bar keeps one color, written")
                end
            end
        end
    end
    assertTrue(n > 0, "the case saw debuff bars")
    -- What is stored after Apply: the template's "static" does not win over it.
    local env = freshEnv()
    env.Helpers.SkinPicker = function() return nil end
    assertTrue(env.Presets.Apply("advanced", "bars", "replace"))
    for _, c in ipairs(env.Database.GetContainers()) do
        if c.style == "bars" then
            local role = c.name:match("^%[%d+%] (.+)$")
            local colored = role == env.L["Target special (mine)"]
                or role == env.L["Target crowd control"] or role == env.L["Target cooldowns, players"]
                or role == env.L["Weapon enchants"]
            assertEqual(c.bars.colorMode, (c.auraType == "HARMFUL" and not colored) and "dispel" or "static", c.name)
        end
    end
end)

test("presets data: Player buffs, short keeps the template's blue", function()
    local P = NS.PresetData
    local n = 0
    for _, name in ipairs(NAMES) do
        for _, look in ipairs(P.LOOKS) do
            for _, spec in ipairs(P.Build(name, look, 1920, 1080)) do
                local o, what = spec.overrides, ("%s/%s %s"):format(name, look, spec.role)
                if o.style == "bars" and spec.role == "pshort" then
                    n = n + 1
                    -- red under: the gray it had before the owner's 2026-11-23 feedback
                    assertNil(o.bars.barColor, what .. ": the template's blue, as Player cooldowns had")
                    assertEqual(o.bars.colorMode, "static", what .. ": One color")
                end
            end
        end
    end
    assertTrue(n > 0, "the case saw Player buffs, short")
end)

test("presets data: bar backgrounds are 50% opaque", function()
    local P = NS.PresetData
    local n = 0
    for _, name in ipairs(NAMES) do
        for _, look in ipairs(P.LOOKS) do
            for _, spec in ipairs(P.Build(name, look, 1920, 1080)) do
                local o, what = spec.overrides, ("%s/%s %s"):format(name, look, spec.role)
                if o.style == "bars" then
                    n = n + 1
                    -- red under: the template's fully opaque background
                    assertEqual(o.bars.bgAlpha, 0.5, what .. ": Background opacity 50%")
                else
                    assertTrue(o.bars == nil, what .. ": no bar fields on a non-bars container")
                end
            end
        end
    end
    assertTrue(n > 0, "the case saw bars")
    local env = freshEnv()
    env.Helpers.SkinPicker = function() return nil end
    assertTrue(env.Presets.Apply("healer", "bars", "replace"))
    for _, c in ipairs(env.Database.GetContainers()) do
        if c.style == "bars" then assertEqual(c.bars.bgAlpha, 0.5, c.name .. " stored") end
    end
end)

-- The owner's numbering (advanced-source.md brackets, spec section 17.4, Target special (mine) moved
-- to 10 by their 2026-11-17 SmokeTest baseline, both towers restacked by their 2026-11-23 feedback,
-- presets restack spec section 3); a role that stands in for
-- one of the owner's takes its slot, and two that share a slot keep the order listed in TIES.
local OWNER_RANK = {
    pbuffs = 1, wpn = 2, pdebuffs = 3, txtOff = 4, txtDef = 5, txtRaid = 6, pspec = 7,
    pcd = 8, pcdHealer = 8, pshort = 9, tspec = 10, tcc = 11, tcdp = 12, tcd = 12, tcdn = 13,
    tdeb = 14, healTarget = 14, dispelTarget = 14, tbuff = 15, tsteal = 16, ticoD = 17, ticoB = 18,
    fdeb = 19, healFocus = 19, dispelFocus = 19, fbuff = 20,
}
local TIES = { healTarget = 1, dispelTarget = 2, healFocus = 1, dispelFocus = 2 }

test("presets data: names are numbered 1..N in the owner's order", function()
    local P = NS.PresetData
    for _, name in ipairs(NAMES) do
        for _, look in ipairs(P.LOOKS) do
            local prev, prevTie
            for i, spec in ipairs(P.Build(name, look, 1920, 1080)) do
                local what = ("%s/%s #%d %s"):format(name, look, i, spec.role)
                local num, rest = spec.overrides.name:match("^%[(%d+)%] (.+)$")
                -- red under: an unnumbered name, a gap in the numbers, or creation out of the owner's order
                assertEqual(tonumber(num), i, what .. ": numbered continuously, in creation order")
                -- red under: a single-digit number, which a name sort puts after [10] (owner, 2026-11-15)
                assertEqual(num, ("%02d"):format(i), what .. ": two digits, so a sort by name keeps the order")
                assertTrue(rest ~= nil and not rest:find("^%["), what .. ": the localized name follows")
                local rank = OWNER_RANK[spec.role]
                assertTrue(rank ~= nil, what .. ": has a slot in the owner's order")
                if prev then
                    assertTrue(rank > prev or (rank == prev and (TIES[spec.role] or 0) > (prevTie or 0)),
                        what .. ": after the one before in the owner's order")
                end
                prev, prevTie = rank, TIES[spec.role]
            end
        end
    end
    -- Advanced is the owner's own twenty: its numbers are theirs.
    for i, spec in ipairs(P.Build("advanced", "bars", 1920, 1080)) do
        assertEqual(OWNER_RANK[spec.role], i, "advanced #" .. i .. " " .. spec.role)
    end
    -- Applied, the stored order (containerOrder) is the numbering; Add's suffix follows the name.
    local env = freshEnv()
    env.Helpers.SkinPicker = function() return nil end
    assertTrue(env.Presets.Apply("intermediate", "icons", "replace"))
    for i, c in ipairs(env.Database.GetContainers()) do
        assertEqual(c.name:match("^%[(%d+)%] "), ("%02d"):format(i), "stored #" .. i .. " " .. c.name)
    end
    assertTrue(env.Presets.Apply("simple", "bars", "add"))
    local list = env.Database.GetContainers()
    assertEqual(list[#list - 2].name, "[01] " .. env.L["Player buffs (all)"] .. " (2)", "Add's suffix after the name")
end)
