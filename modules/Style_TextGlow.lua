local _, NS = ...

-- modules/Style_TextGlow.lua — the glow behind a Text container's text (text glow, owner 2026-10-15;
-- docs/superpowers/specs/2026-10-15-text-glow-design.md G3).
--
--      ┌─┬────────────────────────────┬─┐   nine textures, one radial file: each corner a quadrant
--      ├─┼────────────────────────────┼─┤   (r × r), each edge the center row or column stretched
--      │ │ Power Word: Fortitude x3   │ │   along its side, the center the center texel, so the fade
--      ├─┼────────────────────────────┼─┤   runs exactly r past the text at any line length
--      └─┴────────────────────────────┴─┘
--
-- A HALO, NOT A GLYPH GLOW. Every field is engine-written into one font string of ours, and no addon
-- code can read the secret text to copy it into a second, glow-colored string behind the first; the
-- outline is black and the one shadow is the font's. So the glow is a set of textures hugging the
-- font strings' bounds: every anchor is on a font string, never a read, so the client follows the
-- engine's rewrites in combat with nothing called after the dress. It ADDS to the outline and shadow
-- (Style.ApplyFont is untouched).
--
-- ONE SET PER LINE, ONE PER STACKED ROW. A line's set runs from piece 1 (the leftmost, whatever the
-- justify: pieces are laid in template order) to the last piece. A stacked Center (Text.Stacked) gets
-- a set per name or duration row, and its hidden literals none. Every set past the ones a dress uses,
-- and every set while the glow is off, is hidden. Sets are built lazily, the first time a dress needs
-- one, and kept as `am.glow1`, `am.glow2`, …: a region never hides in a list the style suites cannot
-- see.
--
-- NO SET AROUND A FIELD THAT CAN BE EMPTY. The engine writes "" for stacks below 2 and for an aura
-- with no dispel type, and an empty font string collapses to a point that the four corners still ring
-- as a glowing dot. No addon code can read the secret text to hide the set, and a texture cannot follow
-- a font string's visibility, so a stacks or dispel row gets no set, nor a line of only those fields. A
-- duration is empty only on a timeless aura, and keeps its set (docs/known-limitations.md).
--
-- LAYERS. The textures sit on the animated frame's BACKGROUND layer, under the icon (that frame's
-- ARTWORK), so a halo reaching past the text area runs behind the icon, never over it. The text area is
-- a child frame of `anim`, so its dispel backdrop and edge and the text draw over the glow. Under a
-- hand-set Width and Height the element's clip frame cuts the halo at the box (docs/known-limitations.md).
--
-- DRESSED AFTER THE BINDINGS. Text.Apply calls Text.Glow after Text.Bind, as it plays the loops: in
-- combat every call on a button's objects is refused, so a button built then must have its fields
-- bound first. A change made in combat waits for the deferred restyle, like every other setting.
--
-- INTERIM (TG-09). The glyph glow addendum (docs/superpowers/specs/2026-10-16-text-glow-addendum-
-- glyph-glow.md) removed the halo's falloff, blend and radius leaves and C.TEXT_GLOW_TEXTURES. Until
-- TG-10 rewrites this module, the halo draws the one soft file with the Normal blend, glowThickness
-- deep.
--
-- LOAD-BEARING POSITION: after modules/Style_Text.lua, whose Style.Text this decorates at file scope.

local Style = NS.Style
local D = NS.CONTAINER_TEMPLATE.text
local Text = Style.Text

--- "glow1", "glow2", ...: the keys the sets sit under on `frame.__am`, built once each.
local GLOW = setmetatable({}, { __index = function(t, i)
    local key = "glow" .. i
    t[i] = key
    return key
end })

--- "piece1", "piece2", ...: the chain's font strings on `frame.__am` (modules/Style_Text.lua's PIECE).
local PIECE = setmetatable({}, { __index = function(t, i)
    local key = "piece" .. i
    t[i] = key
    return key
end })

-- The nine pieces of a set: each key, the slice of the texture it samples (left, right, top, bottom),
-- its anchors as { point, "L" or "R", that font string's point }, and how `r` sizes it ("corner" for
-- r × r, an edge's one setter, nothing for the center, which its anchors size).
local PARTS = {
    { "topLeft",     { 0, .5, 0, .5 },   { { "BOTTOMRIGHT", "L", "TOPLEFT" } }, "corner" },
    { "topRight",    { .5, 1, 0, .5 },   { { "BOTTOMLEFT", "R", "TOPRIGHT" } }, "corner" },
    { "bottomLeft",  { 0, .5, .5, 1 },   { { "TOPRIGHT", "L", "BOTTOMLEFT" } }, "corner" },
    { "bottomRight", { .5, 1, .5, 1 },   { { "TOPLEFT", "R", "BOTTOMRIGHT" } }, "corner" },
    { "top",    { .5, .5, 0, .5 }, { { "BOTTOMLEFT", "L", "TOPLEFT" }, { "BOTTOMRIGHT", "R", "TOPRIGHT" } }, "SetHeight" },
    { "bottom", { .5, .5, .5, 1 }, { { "TOPLEFT", "L", "BOTTOMLEFT" }, { "TOPRIGHT", "R", "BOTTOMRIGHT" } }, "SetHeight" },
    { "left",   { 0, .5, .5, .5 }, { { "TOPRIGHT", "L", "TOPLEFT" }, { "BOTTOMRIGHT", "L", "BOTTOMLEFT" } }, "SetWidth" },
    { "right",  { .5, 1, .5, .5 }, { { "TOPLEFT", "R", "TOPRIGHT" }, { "BOTTOMLEFT", "R", "BOTTOMRIGHT" } }, "SetWidth" },
    { "center", { .5, .5, .5, .5 }, { { "TOPLEFT", "L", "TOPLEFT" }, { "BOTTOMRIGHT", "R", "BOTTOMRIGHT" } } },
}

-- The halo's file, a radial texture the client ships, so the addon ships no media for it (layout-§3:
-- a generic glow is not this addon's own art): GenericGlow64 (file 1063457), a linear radial alpha
-- fade to nothing at its edge. Every piece of a set samples it as a nine-slice.
local FILE = "Interface\\GLUES\\Models\\UI_Draenei\\GenericGlow64"

local function number(v, default)
    return tonumber(v) or default
end

-- The piece kinds the engine may write as "" (stacks below 2, no dispel type): no set rings them.
local MAY_BE_EMPTY = { stacks = true, dispel = true }

--- Set `i` on `am`, built the first time it is asked for: nine textures on the animated frame's
--- BACKGROUND, under the icon.
local function setAt(am, i)
    local set = am[GLOW[i]]
    if set then return set end
    set = {}
    for _, part in ipairs(PARTS) do set[part[1]] = am.anim:CreateTexture(nil, "BACKGROUND") end
    am[GLOW[i]] = set
    am.glowCount = math.max(am.glowCount or 0, i)
    return set
end

--- Hide every built set from `first` on.
local function hideFrom(am, first)
    for i = first, am.glowCount or 0 do
        local set = am[GLOW[i]]
        for _, part in ipairs(PARTS) do set[part[1]]:Hide() end
    end
end

--- The look every texture of every set takes: the file, the blend mode, the color with its alpha ×
--- the intensity, and the depth (the thickness) and offset.
local function lookFor(s)
    local r, g, b, a = Style.Color(s.glowColor or D.glowColor, s.useClassColorGlow)
    return { file = FILE, blend = "BLEND",
        r = r, g = g, b = b, a = (a or 1) * number(s.glowIntensity, D.glowIntensity),
        radius = number(s.glowThickness, D.glowThickness),
        x = number(s.glowX, D.glowX), y = number(s.glowY, D.glowY) }
end

--- Size piece `tex` of a set for radius `r` (PARTS' fourth field).
local function sizePart(tex, how, r)
    if how == "corner" then
        tex:SetSize(r, r)
    elseif how then
        tex[how](tex, r)
    end
end

--- Dress set `set` around font strings `left` and `right` (the same one for a stacked row) in `look`.
local function dressSet(set, left, right, look)
    local ends = { L = left, R = right }
    for _, part in ipairs(PARTS) do
        local tex = set[part[1]]
        tex:SetTexture(look.file)
        tex:SetTexCoord(part[2][1], part[2][2], part[2][3], part[2][4])
        tex:SetBlendMode(look.blend)
        tex:SetVertexColor(look.r, look.g, look.b, look.a)
        tex:ClearAllPoints()
        for _, a in ipairs(part[3]) do tex:SetPoint(a[1], ends[a[2]], a[3], look.x, look.y) end
        sizePart(tex, part[4], look.radius)
        tex:Show()
    end
end

--- One set per name or duration row of a stacked line, in row order; how many sets were used.
local function dressStack(am, compiled, look)
    local used = 0
    for i, piece in ipairs(compiled.pieces) do
        if piece.kind ~= "literal" and not MAY_BE_EMPTY[piece.kind] then
            used = used + 1
            local fs = am[PIECE[i]]
            dressSet(setAt(am, used), fs, fs, look)
        end
    end
    return used
end

--- Whether a line holds a piece that is never empty: a name, a duration or plain text.
local function lineDraws(compiled)
    for _, piece in ipairs(compiled.pieces) do
        if not MAY_BE_EMPTY[piece.kind] then return true end
    end
    return false
end

--- One set over a line, from piece 1 to the last; how many sets were used (none for a line of only
--- fields that may be empty).
local function dressLine(am, compiled, look)
    if not lineDraws(compiled) then return 0 end
    dressSet(setAt(am, 1), am[PIECE[1]], am[PIECE[am.pieceCount]], look)
    return 1
end

--- Draw `s`'s glow on a dressed text element, after layoutChain has anchored its chain (Text.Apply):
--- hidden when off, else one set per line or per stacked row, and every set past those hidden.
function Text.Glow(am, s, compiled)
    local look = s.glow and lookFor(s)
    if not look then return hideFrom(am, 1) end
    local used
    if Text.Stacked(s, compiled) then
        used = dressStack(am, compiled, look)
    else
        used = dressLine(am, compiled, look)
    end
    hideFrom(am, used + 1)
end
