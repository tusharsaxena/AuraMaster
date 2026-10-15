local _, NS = ...

-- modules/Style_TextGlow.lua — the glow behind a Text container's text: a ring of glow-colored copies
-- of each letter (text glow, owner 2026-10-15; the glyph glow addendum,
-- docs/superpowers/specs/2026-10-16-text-glow-addendum-glyph-glow.md, and the twins' design note,
-- docs/superpowers/research/2026-10-16-text-glow-twins-design.md, sections 3 and 4).
--
--          ·  ·  ·          each copy is the line again, in the glow color, moved thickness × d_k
--        · Renew - 9s ·     (C.TEXT_GLOW_RING) and drawn under the main text; its shadow, in the same
--          ·  ·  ·          color at −2 × thickness × d_k, is the ring's opposite point
--
-- A GLYPH GLOW. The Slug outline is black and takes no color, and a halo of textures drew a box (owner
-- smoke, 2026-10-15). What reads as a glow is the owner's probe ring: r = 2, eight copies at about 0.55
-- alpha, the main on top. Under shadow pairing (C.TEXT_GLOW_PAIRED) each copy's shadow draws the
-- opposite point, so C.TEXT_GLOW_TWINS = 4 copies make all eight (owner probe `/amgp twin4s`).
--
-- WHO DRAWS THE COPIES. A live button's text is engine-written and secret, so no addon code can copy
-- it: a live line's ring is C.TEXT_GLOW_TWINS twin engines, whose buttons Text.Apply dresses as the
-- main's with a twin index (the glow dress: Text.GlowFont on every piece, the icon hidden, no tints,
-- no time color, no mouse; Text.TwinBehavior). A placeholder writes its own text, so its ring is copy
-- strings of ours (Text.GlowCopies), dressed by the same Text.GlowFont, so the preview shows the live
-- look.
--
-- THE COPIES' LAYER. Copy strings sit on the animated frame's BACKGROUND, under the icon (that frame's
-- ARTWORK) and under the text area and chain (child frames), the stacking a twin engine gets from its
-- lower frame level. CreateFontString takes no sublevel, so the layer is set by SetDrawLayer (12.1
-- probe). Under a hand-set Width and Height the element's clip frame cuts them at the box.
--
-- DRESSED AFTER THE BINDINGS. Text.Apply calls Text.GlowCopies after Text.Bind, as it plays the loops:
-- in combat every call on a button's objects is refused, so a button built then must have its fields
-- bound first. A change made in combat waits for the deferred restyle, like every other setting.
--
-- LOAD-BEARING POSITION: after modules/Style_Text.lua, whose Style.Text this decorates at file scope.

local Style = NS.Style
local C = NS.Constants
local D = NS.CONTAINER_TEMPLATE.text
local Text = Style.Text

-- The copies' sublevel on the animated frame's BACKGROUND: nothing else of ours draws there.
local COPY_SUBLEVEL = 0

--- "glow1", "glow2", ...: the keys piece i's copies sit under on `frame.__am`, built once each.
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

local function number(v, default)
    return tonumber(v) or default
end

-- The client flags a copy never takes: the outline is black whatever the color (12.1 probe).
local OUTLINES = { OUTLINE = true, THICKOUTLINE = true }

-- [client flags] = the same flags less the outline, built once each.
local unoutlined = {}

--- `flags` (Style.FontKey's client flag string) with OUTLINE and THICKOUTLINE dropped and the rest,
--- MONOCHROME, kept: "MONOCHROME,OUTLINE" -> "MONOCHROME", "OUTLINE" -> "".
local function withoutOutline(flags)
    local hit = unoutlined[flags]
    if hit then return hit end
    local kept = {}
    for flag in flags:gmatch("[^,%s]+") do
        local n = #kept
        if not OUTLINES[flag] then kept[n + 1] = flag end
    end
    hit = table.concat(kept, ",")
    unoutlined[flags] = hit
    return hit
end

--- How far the paired shadow sits from its copy along one axis: −2 × thickness × `v`, and a plain 0
--- (never −0) on an axis the direction does not move.
local function opposite(t, v)
    if v == 0 then return 0 end
    return -2 * t * v
end

--- Dress font string `fs` as the ring's copy `k` for text block `s`: the line's face and size with
--- the outline dropped, the glow color (Style.Color, so a dress's class snapshot paints it) at its
--- alpha × the intensity, and under shadow pairing a shadow in the same color at −2 × thickness ×
--- d_k, the ring's opposite point; with pairing off, no shadow. The font's own shadow never reaches
--- a copy. One function for a twin's pieces and a placeholder's copies, so the two cannot differ.
function Text.GlowFont(fs, s, k)
    local path, size, flags = Style.FontKey(s.font or D.font, D.font)
    flags = withoutOutline(flags)
    if not fs:SetFont(path, size, flags) then fs:SetFont(C.FALLBACK_FONT, size, flags) end
    local r, g, b, a = Style.Color(s.glowColor or D.glowColor, s.useClassColorGlow)
    a = (a or 1) * number(s.glowIntensity, D.glowIntensity)
    fs:SetTextColor(r, g, b, a)
    if not C.TEXT_GLOW_PAIRED then return fs:SetShadowOffset(0, 0) end
    local t, d = number(s.glowThickness, D.glowThickness), C.TEXT_GLOW_RING[k]
    fs:SetShadowColor(r, g, b, a)
    fs:SetShadowOffset(opposite(t, d[1]), opposite(t, d[2]))
end

--- A twin button's mouse (twins design note, section 3): no hover, no click, no cancel and no tooltip
--- binding. A twin is decoration under its main, whose button keeps all of them.
function Text.TwinBehavior(frame)
    if frame.SetMouseMotionEnabled then frame:SetMouseMotionEnabled(false) end
    if frame.SetMouseClickEnabled then frame:SetMouseClickEnabled(false) end
    Style.Bind(frame, "SetCancelAuraButtons", nil)
end

--- Piece `i`'s copies on `am`, built the first time they are asked for: C.TEXT_GLOW_TWINS single-line
--- font strings on the animated frame's BACKGROUND, under the icon.
local function copiesAt(am, i)
    local set = am[GLOW[i]]
    if set then return set end
    set = {}
    for j = 1, C.TEXT_GLOW_TWINS do
        local copy = am.anim:CreateFontString(nil, "BACKGROUND")
        copy:SetDrawLayer("BACKGROUND", COPY_SUBLEVEL)
        copy:SetWordWrap(false)
        set[j] = copy
    end
    am[GLOW[i]] = set
    am.glowCount = math.max(am.glowCount or 0, i)
    return set
end

local function hideSet(set)
    for _, copy in ipairs(set) do copy:Hide() end
end

--- Hide every built piece's copies from piece `first` on.
local function hideFrom(am, first)
    for i = first, am.glowCount or 0 do hideSet(am[GLOW[i]]) end
end

--- Dress `set` around piece `fs`: copy j as the ring's copy j (Text.GlowFont), justified as its piece,
--- on the piece's rect moved by thickness × d_j + (X, Y).
local function dressSet(set, fs, s, justify)
    local t = number(s.glowThickness, D.glowThickness)
    local x, y = number(s.glowX, D.glowX), number(s.glowY, D.glowY)
    for j, copy in ipairs(set) do
        local d = C.TEXT_GLOW_RING[j]
        local ox, oy = t * d[1] + x, t * d[2] + y
        Text.GlowFont(copy, s, j)
        copy:SetJustifyH(justify)
        copy:ClearAllPoints()
        copy:SetPoint("TOPLEFT", fs, "TOPLEFT", ox, oy)
        copy:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", ox, oy)
        copy:Show()
    end
end

--- A placeholder's ring (twins design note, section 4), after layoutChain has anchored its chain: per
--- piece, its copies dressed on its current string (useChain swaps strings on a shape change), a
--- literal's with its text; a stacked line's hidden literals, every piece past the chain's and all of
--- them while off or on an engine button (whose ring is the twins') hidden. Text.FillPreview gives the
--- field pieces' copies their text (Text.GlowText).
function Text.GlowCopies(am, s, compiled, engine)
    if engine or not s.glow then return hideFrom(am, 1) end
    local stacked = Text.Stacked(s, compiled)
    local justify = stacked and "CENTER" or (s.justifyH or D.justifyH)
    for i, piece in ipairs(compiled.pieces) do
        local set = copiesAt(am, i)
        if stacked and piece.kind == "literal" then
            hideSet(set)
        else
            dressSet(set, am[PIECE[i]], s, justify)
            if piece.kind == "literal" then Text.GlowText(am, i, piece.text) end
        end
    end
    hideFrom(am, #compiled.pieces + 1)
end

--- Write `text` into piece `i`'s copies, when it has any.
function Text.GlowText(am, i, text)
    local set = am[GLOW[i]]
    if not set then return end
    for _, copy in ipairs(set) do copy:SetText(text) end
end
