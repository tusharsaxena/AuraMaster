-- tests/test_defaults_r2.lua -- the owner's ruling R-2 of 2026-11-20 (Ka0sAddonsCommonTasks
-- docs/2026-11-20-LIBKA0S_94_97_99_100/, skinning-§9 "Every option default follows the skin"): the bar
-- fill, background and icon-border colors and the Text line's font color default to follow the skin
-- (U-8, U-9), and schema v21's one move (Database.FollowDefaults) puts back on the skin each stored
-- `false` this addon wrote at the old default, a swatch still the template's. A player's color, a
-- preset's role bar and call-out (presets spec sections 15 and 17, owner U-12), the bar border's color
-- (U-9) and the text glow's (U-10) stay as they are.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil
local fresh = dofile("tests/fresh_env.lua")

local MOVED = {
    "bars.barColorFromSkin", "bars.bgColorFromSkin", "bars.iconBorderColorFromSkin",
    "icons.borderColorFromSkin", "text.iconBorderColorFromSkin", "text.font.fontColorFromSkin",
}

local function at(t, path)
    for seg in path:gmatch("[^%.]+") do
        if type(t) ~= "table" then return nil end
        t = t[seg]
    end
    return t
end

local function rgb(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end

--- A stored container as v17 left it: every moved companion false, beside the template's colors.
local function v17Container(NS)
    local c = NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE)
    c.bars.barColorFromSkin, c.bars.bgColorFromSkin, c.bars.iconBorderColorFromSkin = false, false, false
    c.icons.borderColorFromSkin, c.text.iconBorderColorFromSkin = false, false
    c.text.font.fontColorFromSkin = false
    return c
end

test("r2: the six companions default to follow the skin; the border and the glow stay off (U-9, U-10)", function()
    local NS = fresh()
    for _, path in ipairs(MOVED) do
        -- red under: SF-AM-3 or SF-AM-2's background still holding the default off
        assertEqual(at(NS.CONTAINER_TEMPLATE, path), true, path)
        local row = NS.FindSchemaRow("container." .. path)
        assertEqual(row and row.default, true, path .. " row default agrees")
    end
    assertEqual(NS.CONTAINER_TEMPLATE.bars.borderColorFromSkin, false, "the bar border stays dark (U-9)")
    assertEqual(NS.CONTAINER_TEMPLATE.text.glowColorFromSkin, false, "the glow stays black (U-10)")
    assertEqual(NS.defaults.profile.skin.defaultsFollow, false, "the record starts unwritten")
end)

test("r2: FollowDefaults moves a false at the old default, keeps a picked color, and records it once", function()
    local NS = fresh()
    local mine = v17Container(NS)
    mine.bars.barColor = rgb(0.9, 0.1, 0.1)          -- the player's fill
    mine.text.font.fontColor = rgb(0.1, 1, 0.1)      -- a call-out's green (presets spec section 15)
    local partial = { bars = { barColorFromSkin = false, bgColorFromSkin = false, bgColor = { r = 0 } },
        text = { font = { fontColorFromSkin = false } } }
    local p = { skin = {}, containers = { [1] = v17Container(NS), [2] = mine, [3] = partial,
        [4] = { bars = { borderColorFromSkin = false }, text = { glowColorFromSkin = false } } } }
    local ran, n = NS.Database.FollowDefaults(p)
    assertTrue(ran, "it ran")
    for _, path in ipairs(MOVED) do
        -- red under: a step that skips a moved companion
        assertEqual(at(p.containers[1], path), true, "the addon's write follows: " .. path)
    end
    assertEqual(mine.bars.barColorFromSkin, false, "a picked fill stays the player's")
    assertEqual(mine.text.font.fontColorFromSkin, false, "a call-out's color stays (U-12)")
    assertEqual(mine.bars.bgColorFromSkin, true, "the same container's untouched background follows")
    -- An absent swatch, or one lacking channels, takes the template's: it draws the old default.
    assertEqual(partial.bars.barColorFromSkin, true, "no swatch stored")
    assertEqual(partial.bars.bgColorFromSkin, true, "a swatch short of channels")
    assertEqual(partial.text.font.fontColorFromSkin, true)
    assertEqual(p.containers[4].bars.borderColorFromSkin, false, "the border is not listed (U-9)")
    assertEqual(p.containers[4].text.glowColorFromSkin, false, "the glow is not listed (U-10)")
    assertEqual(n, 6 + 4 + 3)
    assertEqual(p.skin.defaultsFollow, true)
    mine.bars.bgColorFromSkin = false
    -- red under: no record, so a companion turned off afterwards is turned back on at the next load
    assertEqual(NS.Database.FollowDefaults(p), false, "the record gates")
    assertEqual(mine.bars.bgColorFromSkin, false)
end)

test("r2: FollowDefaults goes through Skin.ResetToSkin, and writes the same with the library absent", function()
    local NS, mocks = fresh()
    local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
    local keep, seen = Skin.ResetToSkin, {}
    Skin.ResetToSkin = function(c, keys)
        for _, k in ipairs(keys) do seen[#seen + 1] = k end
        return keep(c, keys)
    end
    local p = { containers = { [7] = v17Container(NS) } }
    NS.Database.FollowDefaults(p)
    -- red under: the step writing the companions around the library's seam
    assertEqual(#seen, #MOVED, table.concat(seen, ","))
    assertEqual(p.skin.defaultsFollow, true, "the skin table made for the record")
    Skin.ResetToSkin = nil
    local q = { containers = { [1] = v17Container(NS) } }
    local ok, err = pcall(NS.Database.FollowDefaults, q)
    assertTrue(ok, tostring(err))
    for _, path in ipairs(MOVED) do assertEqual(at(q.containers[1], path), true, "by hand: " .. path) end
    Skin.ResetToSkin = keep
end)

test("r2: v21 walks every stored profile, and a new profile's load records the step", function()
    local NS0 = fresh()
    local function stored() return { seeded = true, nextContainerId = 2, containerOrder = { 1 },
        skin = { fullSkinReset = true }, containers = { [1] = v17Container(NS0) } } end
    local NS = fresh({ savedVariables = { profiles = { Default = stored(), Parked = stored() },
        global = { schemaVersion = 20 } } })
    for _, name in ipairs({ "Default", "Parked" }) do
        local p = NS.db.sv.profiles[name]
        -- red under: no v21 step, or one walking the active profile alone
        assertEqual(p.skin.defaultsFollow, true, name)
        assertEqual(p.containers[1].bars.barColorFromSkin, true, name)
        assertEqual(p.containers[1].text.font.fontColorFromSkin, true, name)
    end
    assertEqual(NS.db.global.schemaVersion, 21)
    local S = fresh({ simple = true })
    assertEqual(S.db.profile.skin.defaultsFollow, true, "a new profile records the step")
    assertNil(S.FindSchemaRow("skin.defaultsFollow"), "no row: no Defaults path walks the record")
end)
