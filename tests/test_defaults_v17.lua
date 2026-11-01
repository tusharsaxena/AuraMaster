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
