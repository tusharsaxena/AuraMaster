-- tests/test_defaults_v17.lua -- schema v17, the defaults the smoke feedback moved off the skin
-- (SF-AM-1..3, owner 2026-11-01). A new container takes the new default; v17 moves a stored container
-- still holding the OLD default and leaves any other value alone.

local T = _G.AM_TEST
local test, assertEqual = T.test, T.assertEqual
local fresh = dofile("tests/fresh_env.lua")

test("v17: the text glow's color does not follow the skin by default (SF-AM-1)", function()
    local NS = fresh()
    -- red under: glowColorFromSkin defaulted on, so every skin tinted the glow
    assertEqual(NS.CONTAINER_TEMPLATE.text.glowColorFromSkin, false)
end)

test("v17: MigrateV17 moves an old default and keeps a pick", function()
    local NS = fresh()
    local p = { containers = {
        { text = { glowColorFromSkin = true } },
        { text = { glowColorFromSkin = false } },
        { bars = {} },
    } }
    local n = NS.Database.MigrateV17(p)
    assertEqual(p.containers[1].text.glowColorFromSkin, false, "the old default moves")
    assertEqual(p.containers[2].text.glowColorFromSkin, false, "a value already off stays")
    assertEqual(n, 1)
    assertEqual(NS.Database.MigrateV17({}), 0, "no containers")
end)

test("v17: a bar has a dark background and a black border whatever the skin (SF-AM-2)", function()
    local NS = fresh()
    local b = NS.CONTAINER_TEMPLATE.bars
    -- red under: the background or the border color following the skin, or Show border off
    assertEqual(b.bgColorFromSkin, false)
    assertEqual(b.borderColorFromSkin, false)
    assertEqual(b.borderShow, true)
    assertEqual(b.bgTextureFromSkin, true, "the textures still follow the skin")
    assertEqual(b.borderStyleFromSkin, true)
end)

test("v17: MigrateV17 moves a bar's old background and border defaults, not a pick", function()
    local NS = fresh()
    local p = { containers = {
        { bars = { bgColorFromSkin = true, borderColorFromSkin = true, borderShow = false } },
        { bars = { bgColorFromSkin = false, borderColorFromSkin = false, borderShow = true } },
    } }
    NS.Database.MigrateV17(p)
    for i = 1, 2 do
        local b = p.containers[i].bars
        assertEqual(b.bgColorFromSkin, false, i)
        assertEqual(b.borderColorFromSkin, false, i)
        assertEqual(b.borderShow, true, i)
    end
end)

test("v17: bar fill, Text font and icon border colors stay off the skin by default (SF-AM-3)", function()
    local NS = fresh()
    local D = NS.CONTAINER_TEMPLATE
    -- red under: any of the five defaulting on, so a skin recolored a stored pick
    assertEqual(D.bars.barColorFromSkin, false)
    assertEqual(D.text.font.fontColorFromSkin, false)
    assertEqual(D.icons.borderColorFromSkin, false)
    assertEqual(D.bars.iconBorderColorFromSkin, false)
    assertEqual(D.text.iconBorderColorFromSkin, false)
    assertEqual(D.bars.name.fontColorFromSkin, true, "the other fonts are not named by the ruling")
    assertEqual(D.label.font.fontColorFromSkin, true)
end)

test("v17: a new profile keeps the new defaults through the one-time follow step", function()
    local NS = fresh()
    local c = NS.Database.FindContainer(NS.db.profile.containerOrder[1])
    NS.db.profile.skin.fullSkinReset = false
    NS.Database.FollowSkin(NS.db.profile)
    -- red under: FOLLOW_LEAVES still naming a moved leaf, so the step wrote it back on
    assertEqual(c.bars.barColorFromSkin, false)
    assertEqual(c.bars.bgColorFromSkin, false)
end)

test("v17: MigrateV17 moves the old fill, text font and icon border defaults", function()
    local NS = fresh()
    local p = { containers = { { bars = { barColorFromSkin = true, iconBorderColorFromSkin = true },
        icons = { borderColorFromSkin = true },
        text = { iconBorderColorFromSkin = true, font = { fontColorFromSkin = true } } } } }
    assertEqual(NS.Database.MigrateV17(p), 5)
    local c = p.containers[1]
    assertEqual(c.bars.barColorFromSkin, false)
    assertEqual(c.bars.iconBorderColorFromSkin, false)
    assertEqual(c.icons.borderColorFromSkin, false)
    assertEqual(c.text.iconBorderColorFromSkin, false)
    assertEqual(c.text.font.fontColorFromSkin, false)
end)
