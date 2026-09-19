-- tests/border_strips.lua — reading an element border as modules/Style.lua's ApplyBorder draws it
-- (B2-3): a Solid border is four strip textures on the border frame (`__amStrips`, top, bottom,
-- left, right), and any other style a backdrop on a frame of its own (`__amBackdrop`).
--
-- Not a suite (tests/run.lua does not list it) and not part of the vendored kit.
--
--     local BS = dofile("tests/border_strips.lua")
--     BS.assertSolid(am.border, 2, "1,0,0,1", "the icon border")

local T = _G.AM_TEST
local BS = {}

--- The four strips of a Solid border, in order, or an empty list when none was ever built.
function BS.strips(border)
    return border.__amStrips or {}
end

--- A Solid border of thickness `size` in `color` ("r,g,b,a"): the border shown, four shown strips,
--- each in the color, the top and bottom `size` tall and the sides `size` wide. `what` names the case.
function BS.assertSolid(border, size, color, what)
    local s = BS.strips(border)
    T.assertTrue(border:IsShown(), what .. ": the border shows")
    T.assertEqual(#s, 4, what .. ": four strips")
    for i, strip in ipairs(s) do
        T.assertTrue(strip:IsShown(), what .. ": strip " .. i .. " shown")
        T.assertEqual(strip:__joined("SetColorTexture"), color, what .. ": strip " .. i .. " color")
    end
    T.assertEqual(s[1]:__last("SetHeight")[1], size, what .. ": top thickness")
    T.assertEqual(s[2]:__last("SetHeight")[1], size, what .. ": bottom thickness")
    T.assertEqual(s[3]:__last("SetWidth")[1], size, what .. ": left thickness")
    T.assertEqual(s[4]:__last("SetWidth")[1], size, what .. ": right thickness")
end

return BS
