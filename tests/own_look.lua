-- tests/own_look.lua — one config with every "Use the skin's color / border / shadow" companion off,
-- so a suite that pins what a stored swatch, border or shadow draws reads the stored value. What each
-- draws with its companion on is tests/test_skin_flip.lua's. The face and texture companions are not
-- named: their owning suites turn them off themselves (tests/test_skin_hud.lua's header).
--
-- Not a suite (tests/run.lua does not list it).

local OFF = {}
for _, key in ipairs({
    "barColorFromSkin", "bgColorFromSkin", "borderStyleFromSkin", "borderColorFromSkin",
    "iconBorderStyleFromSkin", "iconBorderColorFromSkin", "glowColorFromSkin",
    "fontColorFromSkin", "fontShadowFromSkin",
}) do OFF[key] = true end

--- Turn every listed companion in `t` off, in place, at every depth; answers `t`.
local function own(t)
    for k, v in pairs(t) do
        if OFF[k] then
            t[k] = false
        elseif type(v) == "table" then
            own(v)
        end
    end
    return t
end

return own
