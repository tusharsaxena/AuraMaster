-- tests/test_defaults_v17.lua -- schema v17, the defaults the smoke feedback moved off the skin
-- (SF-AM-1..3, owner 2026-11-01). A new container takes the new default; v17 moves a stored container
-- still holding the OLD default and leaves any other value alone. The owner's ruling R-2 of 2026-11-20
-- turned SF-AM-3 and SF-AM-2's background back onto the skin (U-8, U-9; tests/test_defaults_r2.lua
-- holds v21's move): the text glow (U-10) and the bar border's color (U-9) are what stay off.

local T = _G.AM_TEST
local test, assertEqual = T.test, T.assertEqual
local fresh = dofile("tests/fresh_env.lua")

test("v17: the text glow's color does not follow the skin by default (SF-AM-1, OVERRIDE, owner U-10)", function()
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

test("v17: a bar has a black border whatever the skin, its background the skin's (SF-AM-2, U-9)", function()
    local NS = fresh()
    local b = NS.CONTAINER_TEMPLATE.bars
    -- red under: the border color following the skin (OVERRIDE, owner U-9), the background not
    -- following it (R-2), or Show border off
    assertEqual(b.bgColorFromSkin, true)
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

test("v17: bar fill, Text font and icon border colors follow the skin by default again (R-2 over SF-AM-3, U-8)", function()
    local NS = fresh()
    local D = NS.CONTAINER_TEMPLATE
    -- red under: any of the five still defaulting off, the addon's own color under every skin
    assertEqual(D.bars.barColorFromSkin, true)
    assertEqual(D.text.font.fontColorFromSkin, true)
    assertEqual(D.icons.borderColorFromSkin, true)
    assertEqual(D.bars.iconBorderColorFromSkin, true)
    assertEqual(D.text.iconBorderColorFromSkin, true)
    assertEqual(D.bars.name.fontColorFromSkin, true, "every other font follows too")
    assertEqual(D.label.font.fontColorFromSkin, true)
end)

test("v17: a new profile keeps the new defaults through the one-time follow step", function()
    local NS = fresh()
    local c = NS.Database.FindContainer(NS.db.profile.containerOrder[1])
    NS.db.profile.skin.fullSkinReset = false
    NS.Database.FollowSkin(NS.db.profile)
    -- red under: FOLLOW_LEAVES naming the border's color, so the step wrote it back on; the fill and
    -- background follow from the template (R-2)
    assertEqual(c.bars.borderColorFromSkin, false)
    assertEqual(c.text.glowColorFromSkin, false)
    assertEqual(c.bars.barColorFromSkin, true)
    assertEqual(c.bars.bgColorFromSkin, true)
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
