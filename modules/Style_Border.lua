local _, NS = ...

-- modules/Style_Border.lua — the element border: four strips of our own for Solid, a backdrop on a
-- plain frame for anything else, and the edges of our own frames that hang under secret geometry.
-- Peeled out of modules/Style.lua, which loads first and owns Style.ReportError.

local Style = NS.Style
local C = NS.Constants

-- ---------------------------------------------------------------------------
-- Element borders (B2-3)
-- ---------------------------------------------------------------------------
-- A border frame covers an aura button (or its icon's box), and once the engine has laid the button
-- out, its size and every size anchored to it read SECRET. Blizzard's Backdrop does arithmetic on the
-- frame's size (Blizzard_SharedXML/Backdrop.lua:226, SetupTextureCoordinates), on every SetBackdrop
-- and, from BackdropTemplate's OnSizeChanged script, on every resize, so a restyle of a live button
-- raised there (docs/midnight-quirks.md, "A backdrop on an engine button reads a secret size"). So:
--   * Solid (the default, WHITE8X8) is drawn with four strip textures of our own, each anchored
--     between two corners of the border frame, its thickness a plain config number: no size is read.
--   * Any other style keeps a backdrop, on a frame of its own (`__amBackdrop`): a PLAIN frame with
--     BackdropTemplateMixin mixed in, so no OnSizeChanged script exists to run the arithmetic on a
--     resize. SetBackdrop is applied only while that frame's size reads as a plain number, and only
--     when the edge or size changed; otherwise the backdrop last applied stays and is recolored
--     (SetBackdropBorderColor does no arithmetic). A live button therefore shows a new edge or size
--     after its next rebuild or /reload. One with no backdrop yet to keep (a skin switch from Solid)
--     keeps the strips in the same place until then, so a switch never leaves it with no border.
-- The border frame itself is a plain frame too (Style.NewBorder), never a BackdropTemplate. The other
-- frames of ours that hang under geometry that can read secret (the unlocked outline, the drag
-- handle, the frame picker's outline) draw their edges with the same strips (Style.DrawEdge).

-- The four strips: the two corners each runs between, the setter its thickness goes through, and
-- whether it is a side, which stops a thickness short of each end so no corner is drawn twice.
local BORDER_STRIPS = {
    { "TOPLEFT", "TOPRIGHT", "SetHeight" },
    { "BOTTOMLEFT", "BOTTOMRIGHT", "SetHeight" },
    { "TOPLEFT", "BOTTOMLEFT", "SetWidth", true },
    { "TOPRIGHT", "BOTTOMRIGHT", "SetWidth", true },
}

local SOLID_EDGE = C.WHITE_TEXTURE:lower()

--- The four strip textures of `frame`'s Solid border, built on first use.
local function borderStrips(frame)
    local strips = frame.__amStrips
    if strips then return strips end
    strips = {}
    for i in ipairs(BORDER_STRIPS) do
        local strip = frame:CreateTexture(nil, "BORDER")
        strip:Hide()
        strips[i] = strip
    end
    frame.__amStrips = strips
    return strips
end

--- A border frame on `parent`: a plain frame, never a BackdropTemplate (whose OnSizeChanged script
--- reads the size), with its Solid strips built now, with the element's other regions.
function Style.NewBorder(parent)
    local border = CreateFrame("Frame", nil, parent)
    borderStrips(border)
    return border
end

--- Whether a border style draws as Solid: the style this addon registers, or any key whose media is
--- the same flat texture.
local function isSolid(styleKey, edge)
    return styleKey == "Solid" or (type(edge) == "string" and edge:lower() == SOLID_EDGE)
end

--- Lay one strip as the `i`th of BORDER_STRIPS on `frame`, `size` thick: the one shape every edge of
--- ours takes (the Solid border, Style.DrawEdge, Style.TintEdge), so none can drift from another.
local function layStrip(frame, i, strip, size)
    local e = BORDER_STRIPS[i]
    local from, to = 0, 0
    if e[4] then from, to = -size, size end
    strip:ClearAllPoints()
    strip:SetPoint(e[1], frame, e[1], 0, from)
    strip:SetPoint(e[2], frame, e[2], 0, to)
    strip[e[3]](strip, size)
end

--- Lay `frame`'s strips at thickness `size` and paint them (r, g, b, a), or hide them (`show` false).
local function drawStrips(frame, show, size, r, g, b, a)
    local strips = frame.__amStrips
    if not show then
        if strips then
            for _, strip in ipairs(strips) do strip:Hide() end
        end
        return
    end
    strips = borderStrips(frame)
    for i, strip in ipairs(strips) do
        layStrip(frame, i, strip, size)
        strip:SetColorTexture(r, g, b, a)
        strip:Show()
    end
end

--- Draw a Solid edge `size` thick in (r, g, b, a) on any plain frame of ours, with the same four
--- strips as Style.ApplyBorder's Solid path: no size is read, so the frame may sit under secret
--- geometry. The unlocked outline (modules/Container.lua), the drag handle (modules/Anchors.lua) and
--- the frame picker's outline (modules/FramePicker.lua) draw their edges with it, once, when built:
--- the strips hang from the frame's corners and follow every later resize on their own.
function Style.DrawEdge(frame, size, r, g, b, a)
    drawStrips(frame, true, size, r, g, b, a)
end

--- Lay four caller-owned strips (top, bottom, left, right) on `frame` in the Solid border's shape,
--- `size` thick, and leave them white, untinted and HIDDEN, for the engine to show and tint (an
--- AddDispelTypeTexture binding with style PreserveAsset). Hidden on every dress, because the engine's
--- ClearDispelTypeTextures restores nothing: a strip it last showed would stay drawn (B-4). The white
--- goes on with SetTexture, not SetColorTexture, as the text style's dispel edge does in-game.
function Style.TintEdge(frame, size, top, bottom, left, right)
    for i = 1, 4 do
        local strip = select(i, top, bottom, left, right)
        layStrip(frame, i, strip, size)
        strip:SetTexture(C.WHITE_TEXTURE)
        strip:SetVertexColor(1, 1, 1, 1)
        strip:Hide()
    end
end

--- Whether `f`'s width and height both read as plain numbers now (a laid-out button's do not).
local function sizeReadable(f)
    local okW, w = pcall(f.GetWidth, f)
    local okH, h = pcall(f.GetHeight, f)
    return okW and okH and NS.Secrets.IsReadableNumber(w) and NS.Secrets.IsReadableNumber(h)
end

--- The frame `frame`'s backdrop is drawn on, built on first use: a plain frame covering it, with
--- BackdropTemplateMixin mixed in (no template, so no OnSizeChanged script), at the border's own
--- level when that level reads plain. Without the mixin it draws nothing.
local function backdropHost(frame)
    local host = frame.__amBackdrop
    if host then return host end
    host = CreateFrame("Frame", nil, frame)
    local mixin, mix = _G.BackdropTemplateMixin, _G.Mixin
    if mixin and mix then mix(host, mixin) end
    host:SetAllPoints(frame)
    local ok, level = pcall(frame.GetFrameLevel, frame)
    if ok and NS.Secrets.IsReadableNumber(level) then host:SetFrameLevel(level + C.LAYERS.LEVEL.SUNK) end
    frame.__amBackdrop = host
    return host
end

--- Draw `frame`'s backdrop in `edge` at `size`, colored (r, g, b, a), or hide it (`show` false). The
--- backdrop is (re)applied only when the edge or size changed and the host's size reads plain.
--- Answers whether a backdrop stands: false with none ever applied, or with no mixin to draw one.
local function drawBackdrop(frame, show, edge, size, r, g, b, a)
    local host = frame.__amBackdrop
    if not show then
        if host then host:Hide() end
        return false
    end
    host = backdropHost(frame)
    if not host.SetBackdrop then return false end
    if (host.__amEdge ~= edge or host.__amEdgeSize ~= size) and sizeReadable(host) then
        host:SetBackdrop({ edgeFile = edge, edgeSize = size })
        host.__amEdge, host.__amEdgeSize = edge, size
    end
    if not host.__amEdge then
        host:Hide()
        return false
    end
    host:SetBackdropBorderColor(r, g, b, a)
    host:Show()
    return true
end

--- Dress a border frame (Style.NewBorder) as an element border: hidden when off, styled None or
--- without a positive size; Solid as four strips; any other style as a guarded backdrop. The other
--- drawing is hidden, so a switch between Solid and another style never shows both. Another style
--- with no backdrop standing (a laid-out button's secret size refused it) draws the strips instead.
function Style.ApplyBorder(frame, show, styleKey, size, stored, useClass)
    if not frame then return end
    size = tonumber(size) or 0
    if not show or styleKey == "None" or size <= 0 then
        frame:Hide()
        return
    end
    local edge = Style.Fetch("border", styleKey, C.FALLBACK_BORDER)
    local r, g, b, a = Style.Color(stored, useClass)
    local backdrop = drawBackdrop(frame, not isSolid(styleKey, edge), edge, size, r, g, b, a)
    drawStrips(frame, not backdrop, size, r, g, b, a)
    frame:Show()
end

-- One border block's keys and the skin's tokens for them: the bar's own, an icon element's, and the
-- icon beside a bar or a text line (the icon family under the keys that block stores it in).
-- `am.iconBorderSize` is core/SkinSetup.lua's: this addon's 1 px under Ka0s Default, `icon.borderSize`
-- under every other skin.
Style.BORDER_BAR = {
    show = "borderShow", barEdge = true,
    style = "borderStyle", size = "borderSize", color = "borderColor", useClass = "useClassColorBorder",
    styleFromSkin = "borderStyleFromSkin", colorFromSkin = "borderColorFromSkin",
    styleToken = "bar.borderStyle", sizeToken = "bar.borderSize", colorToken = "bar.border",
}
Style.BORDER_ICON = {
    show = "borderShow",
    style = "borderStyle", size = "borderSize", color = "borderColor", useClass = "useClassColorBorder",
    styleFromSkin = "borderStyleFromSkin", colorFromSkin = "borderColorFromSkin",
    styleToken = "icon.borderStyle", sizeToken = "am.iconBorderSize", colorToken = "icon.border",
}
Style.BORDER_BESIDE = {
    show = "iconBorderShow", defersNone = true,
    style = "iconBorderStyle", size = "iconBorderSize", color = "iconBorderColor",
    useClass = "useClassColorIconBorder",
    styleFromSkin = "iconBorderStyleFromSkin", colorFromSkin = "iconBorderColorFromSkin",
    styleToken = "icon.borderStyle", sizeToken = "am.iconBorderSize", colorToken = "icon.border",
}

--- The style, thickness and whether it shows, for the bar's own border: S.BarBorder. A skin's None is
--- no border of its own, so the player's Show border, stored style and thickness stand; a real style
--- in a skin wins, Show border off included. Without the library the stored three stand.
local function barEdge(stored, show, storedSize, fromSkin)
    return NS.Skin.BarBorder(stored, show, storedSize, fromSkin)
end

--- The same rule for the icon family, whose Ka0s Default style is a real Solid: a skin's None hands
--- back the stored style and thickness, and Show border stays the player's under every style, so an
--- icon that is off under Ka0s Default stays off (the owner, 2026-11-01).
local function iconEdge(k, stored, storedSize, fromSkin, defersNone)
    local style = Style.SkinKey(k.styleToken, stored, fromSkin)
    if defersNone and fromSkin and style == "None" then return stored, storedSize end
    return style, Style.SkinKey(k.sizeToken, storedSize, fromSkin)
end

--- The style, thickness, stored-shaped color and shown flag block `s` draws its border in (`sdef` the
--- template's block, `k` one of the three above). "Use the skin's border" governs the style and the
--- thickness, "Use the skin's color" the color, and a class color comes first (Style.Followed). A bar's
--- border and the icon beside a bar or a text line take a skin's None as no border of its own
--- (barEdge, iconEdge). One reading for the border and the art's inset, so the two cannot disagree.
function Style.BorderLook(s, sdef, k)
    local fromSkin = Style.OrTemplate(s[k.styleFromSkin], sdef[k.styleFromSkin]) == true
    local stored, storedSize = Style.OrTemplate(s[k.style], sdef[k.style]), tonumber(s[k.size]) or sdef[k.size]
    local show = Style.OrTemplate(s[k.show], sdef[k.show])
    local style, size
    if k.barEdge then
        style, show, size = barEdge(stored, show, storedSize, fromSkin)
    else
        style, size = iconEdge(k, stored, storedSize, fromSkin, k.defersNone)
    end
    local color = Style.Followed(s[k.color] or sdef[k.color],
        Style.OrTemplate(s[k.colorFromSkin], sdef[k.colorFromSkin]) == true, k.colorToken, s[k.useClass])
    return style, size, color, show
end

--- Style.ApplyBorder, guarded: a border the client refuses costs the border alone (hidden, and
--- reported through Style.ReportError as `what`), never the rest of the dress, whose engine bindings
--- come after it (B2-3).
function Style.GuardedBorder(what, frame, ...)
    local ok, err = pcall(Style.ApplyBorder, frame, ...)
    if ok then return end
    Style.ReportError(what, err)
    if frame then pcall(frame.Hide, frame) end
end
