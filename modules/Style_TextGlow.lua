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
-- a set per field row, and its hidden literals none. Every set past the ones a dress uses, and every
-- set while the glow is off, is hidden. Sets are built lazily, the first time a dress needs one, and
-- kept as `am.glow1`, `am.glow2`, …: a region never hides in a list the style suites cannot see.
--
-- LAYERS. The textures sit on the text area's ARTWORK layer: above the dispel backdrop (BACKGROUND)
-- and edge (BORDER), and below the text, whose chain is a child frame of the area. Under a hand-set
-- Width the area clips, and cuts the halo at the box as it cuts the text (docs/known-limitations.md).
--
-- DRESSED AFTER THE BINDINGS. Text.Apply calls Text.Glow after Text.Bind, as it plays the loops: in
-- combat every call on a button's objects is refused, so a button built then must have its fields
-- bound first. A change made in combat waits for the deferred restyle, like every other setting.
--
-- LOAD-BEARING POSITION: after modules/Style_Text.lua, whose Style.Text this decorates at file scope.

local Style = NS.Style
local C = NS.Constants
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

-- The blend modes a stored glowBlend may name (C.TEXT_GLOW_BLENDS); anything else draws the default.
local BLENDS = {}
for _, b in ipairs(C.TEXT_GLOW_BLENDS) do BLENDS[b] = true end

local function number(v, default)
    return tonumber(v) or default
end

--- Set `i` on `am`, built the first time it is asked for: nine textures on the text area's ARTWORK.
local function setAt(am, i)
    local set = am[GLOW[i]]
    if set then return set end
    set = {}
    for _, part in ipairs(PARTS) do set[part[1]] = am.area:CreateTexture(nil, "ARTWORK") end
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

--- The look every texture of every set takes: the falloff's file (nil when none is shipped for it),
--- the blend mode, the color with its alpha × the intensity, and the radius and offset.
local function lookFor(s)
    local files = C.TEXT_GLOW_TEXTURES
    local falloff = s.glowFalloff or D.glowFalloff
    local file = files and (files[falloff] or files[D.glowFalloff])
    if not file then return nil end
    local r, g, b, a = Style.Color(s.glowColor or D.glowColor, s.useClassColorGlow)
    return { file = file, blend = BLENDS[s.glowBlend] and s.glowBlend or D.glowBlend,
        r = r, g = g, b = b, a = (a or 1) * number(s.glowIntensity, D.glowIntensity),
        radius = number(s.glowRadius, D.glowRadius),
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

--- One set per field row of a stacked line, in row order; how many sets were used.
local function dressStack(am, compiled, look)
    local used = 0
    for i, piece in ipairs(compiled.pieces) do
        if piece.kind ~= "literal" then
            used = used + 1
            local fs = am[PIECE[i]]
            dressSet(setAt(am, used), fs, fs, look)
        end
    end
    return used
end

--- Draw `s`'s glow on a dressed text element, after layoutChain has anchored its chain (Text.Apply):
--- hidden when off or when no file is shipped for the falloff, else one set per line or per stacked
--- row, and every set past those hidden.
function Text.Glow(am, s, compiled)
    local look = s.glow and lookFor(s)
    if not look then return hideFrom(am, 1) end
    local used
    if Text.Stacked(s, compiled) then
        used = dressStack(am, compiled, look)
    else
        dressSet(setAt(am, 1), am[PIECE[1]], am[PIECE[am.pieceCount]], look)
        used = 1
    end
    hideFrom(am, used + 1)
end
