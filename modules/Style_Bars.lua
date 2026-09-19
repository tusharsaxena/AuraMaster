local _, NS = ...

-- modules/Style_Bars.lua — dressing one aura as a BAR.
--
--     [icon][ bar area ................................ ]
--            background texture across the whole area
--            fill: the remaining time, drains toward `drain`
--            spark at the fill's leading edge
--            name text · time text          stacks on the icon (or the bar)
--
-- THE FILL IS NOT THE STATUS BAR. The engine drives a StatusBar by ELAPSED time and we paint nothing
-- with it: its texture's edge only marks where the remaining time ends, and our own `fill` texture is
-- stretched from the bar's start to that edge. A timed aura therefore drains, and a timeless aura —
-- zero elapsed — draws a FULL bar, which is what a player expects of a permanent buff and what a bar
-- driven directly by remaining time cannot do (it would read zero and draw empty). The technique is
-- TinyBuffBars' (MIT), documented in docs/data-flow.md.
--
-- LOAD-BEARING POSITION: after modules/Style.lua, whose NS.Style this decorates at file scope.

local Style = NS.Style
local C = NS.Constants
local D = NS.CONTAINER_TEMPLATE

Style.Bars = Style.Bars or {}
local Bars = Style.Bars

--- Build the regions once. Every region is a DESCENDANT of the button — the engine rejects anything
--- else — and each lives on `frame.__am`, a table of ours on the button, tagged with the style that
--- built it (Style.RegionsFor).
local function build(frame)
    local am = {}
    frame.__am = am
    am.style = "bars"

    am.border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    am.border:SetAllPoints(frame)

    am.icon = frame:CreateTexture(nil, "ARTWORK")
    -- The icon's own border, around the icon's box; the art is inset inside it (layoutIcon).
    am.iconBorder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    am.bg = frame:CreateTexture(nil, "BACKGROUND")

    -- The engine's StatusBar, invisible on purpose (see the file header).
    am.bar = CreateFrame("StatusBar", nil, frame)
    am.bar:SetStatusBarTexture(C.WHITE_TEXTURE)
    am.bar:SetStatusBarColor(1, 1, 1, 0)
    am.bar:SetMinMaxValues(0, 1)

    am.fill = am.bar:CreateTexture(nil, "ARTWORK")
    -- The spark lives on a frame of its own, which clips it when a timeless aura must not show one
    -- (wireSpark).
    am.sparkClip = CreateFrame("Frame", nil, am.bar)
    am.spark = am.sparkClip:CreateTexture(nil, "OVERLAY")
    am.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    am.spark:SetBlendMode("ADD")

    -- Text sits in its own frame above the bar, so it is never under the fill and never inherits an
    -- alpha set on the bar.
    am.text = CreateFrame("Frame", nil, frame)
    am.text:SetAllPoints(frame)

    -- Sibling frames made at one level stack in no promised order, so set it: the spark's frame over
    -- the bar, the texts over the spark. Once, here, where every level is a fresh frame's own.
    local level = am.bar:GetFrameLevel()
    am.sparkClip:SetFrameLevel(level + 1)
    am.text:SetFrameLevel(level + 2)
    am.name = am.text:CreateFontString(nil, "OVERLAY")
    am.time = am.text:CreateFontString(nil, "OVERLAY")
    am.stacks = am.text:CreateFontString(nil, "OVERLAY")

    -- The refresh-window ("pandemic") highlight: an additive wash the engine shows only while the aura
    -- can be refreshed without losing duration.
    am.pandemic = am.text:CreateTexture(nil, "BACKGROUND")
    am.pandemic:SetAllPoints(frame)
    am.pandemic:SetTexture(C.WHITE_TEXTURE)
    am.pandemic:SetBlendMode("ADD")
    am.pandemic:Hide()
    return am
end

--- The icon's side: its stored size, or the template's when that is missing; zero means the bar's
--- height (the shared helper in modules/Style.lua, on the bar's own leaves).
local function iconSizeFor(b, h)
    return Style.IconSizeFor(b, D.bars, h)
end

--- Lay the icon and the bar area out inside the element. The icon's box and its border are placed by
--- modules/Style.lua's Style.LayoutIcon, which the Text style shares.
local function layout(frame, am, b, h)
    local iconPos = b.icon or D.bars.icon
    local iconSize = iconSizeFor(b, h)
    local gap = tonumber(b.iconGap) or D.bars.iconGap

    am.icon:ClearAllPoints()
    am.bar:ClearAllPoints()
    am.bg:ClearAllPoints()

    if iconPos == "NONE" then
        am.icon:Hide()
        am.iconBorder:Hide()
        am.bar:SetAllPoints(frame)
    elseif iconPos == "RIGHT" then
        Style.LayoutIcon(frame, am, b, D.bars, "RIGHT", iconSize)
        am.bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        am.bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(iconSize + gap), 0)
    else
        Style.LayoutIcon(frame, am, b, D.bars, "LEFT", iconSize)
        am.bar:SetPoint("TOPLEFT", frame, "TOPLEFT", iconSize + gap, 0)
        am.bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    end
    am.bg:SetAllPoints(am.bar)
end

--- Where the spark rides (B-3). By default: centered on the fill's moving edge, nothing clipped.
---
--- With `sparkTimeless` off on a LIVE bar it rides a clip frame bounded by the ELAPSED region — the
--- engine's status-bar texture — and sits wholly on that side of the edge. A timeless aura has zero
--- elapsed, so the clip frame has no width and the spark is clipped away; a timed bar's spark sits
--- just inside its moving edge. Geometry decides because nothing else can: no engine binding shows a
--- region by whether the aura has a duration, and Lua cannot read a secret one
--- (docs/superpowers/research/2026-09-13-aura-engine-notes.md Q5, whose in-game checks this rests
--- on). The clip frame reaches half the bar's height past each edge, so the double-height spark is
--- not cut. A preview has no timer driving that region; FillPreview hides a timeless spark itself.
---
--- The two modes also paint the spark differently, and must (feedback batch 7, SP-1). Centered mode
--- sits on the FILL — an opaque texture, painted from the profile's own bar color, that always backs
--- it the same way — so ADD blending there is a deliberate highlight: it washes toward the fill's own
--- color and reads as "the spark," which is the look the owner already signed off on. Clipped mode
--- sits on the ELAPSED side instead, whose background texture defaults to only half-opaque
--- (defaults/Profile.lua bgColor alpha 0.5) and lets whatever sits behind the frame show through. ADD
--- there sums the spark's texture on top of THAT — unpredictable, and reported as "a random
--- yellow-golden spark" once the fill's steadying backdrop was gone. Swapping to normal alpha
--- blending in clip mode stops the backdrop from having a vote: the spark renders as its own
--- authored (and player-colorable, via `sparkColor`) translucent texture, the same every time,
--- instead of summing with whatever is behind it. Do not "simplify" this back to one blend mode for
--- both — the two backdrops are not alike, so the blending cannot be either.
local function wireSpark(am, b, edge, engine, h)
    local clip = am.sparkClip
    local right = b.drain == "right"
    clip:ClearAllPoints()
    am.spark:ClearAllPoints()
    if engine and not Style.OrTemplate(b.sparkTimeless, D.bars.sparkTimeless) then
        clip:SetPoint("TOPLEFT", edge, "TOPLEFT", 0, h / 2)
        clip:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", 0, -h / 2)
        clip:SetClipsChildren(true)
        local side = right and "RIGHT" or "LEFT"
        am.spark:SetPoint(side, edge, side, 0, 0)
        am.spark:SetBlendMode("BLEND")
    else
        clip:SetAllPoints(am.bar)
        clip:SetClipsChildren(false)
        am.spark:SetPoint("CENTER", am.fill, right and "LEFT" or "RIGHT", 0, 0)
        am.spark:SetBlendMode("ADD")
    end
end

--- Point the fill and the spark at the status bar's moving edge, per drain direction.
local function wireFill(am, b, engine, h)
    local edge = am.bar:GetStatusBarTexture()
    am.fill:ClearAllPoints()
    if b.drain == "right" then
        -- Elapsed grows from the LEFT; remaining is the part right of the texture's right edge.
        am.bar:SetReverseFill(false)
        am.fill:SetPoint("TOPLEFT", edge, "TOPRIGHT", 0, 0)
        am.fill:SetPoint("BOTTOMRIGHT", am.bar, "BOTTOMRIGHT", 0, 0)
    else
        -- Elapsed grows from the RIGHT; remaining is the part left of the texture's left edge.
        am.bar:SetReverseFill(true)
        am.fill:SetPoint("TOPLEFT", am.bar, "TOPLEFT", 0, 0)
        am.fill:SetPoint("BOTTOMRIGHT", edge, "BOTTOMLEFT", 0, 0)
    end
    wireSpark(am, b, edge, engine, h)
end

--- Paint one surface (the fill or the background) its color and its `opacity`. A live surface colored
--- by dispel type takes its own color here and the engine's tint over it; a PREVIEW one stands in with
--- the profile's Magic color, since no placeholder names a type. The tint is part of the dress, so a
--- later static dress is never left tinted. A static surface keeps its color's alpha on the color and
--- the opacity on the region. A dispel-colored one paints its color opaque and carries the opacity
--- times the color's alpha on the region (smoke batch 2, item 4): the engine's tint paints the map's
--- RGB at alpha 1 (Style.DispelColorMap), so an alpha on the color would be lost. Both are plain
--- config numbers, never an engine value.
local function paintSurface(tex, mode, stored, useClass, preview, opacity)
    local r, g, bl, a = Style.Color(stored, useClass)
    a = a or 1
    if mode ~= "dispel" then
        tex:SetVertexColor(r, g, bl, a)
        tex:SetAlpha(opacity)
        return
    end
    local dc = preview and Style.ProfileDispelColors()
    local m = dc and dc.Magic
    if m then r, g, bl = m.r or 1, m.g or 1, m.b or 1 end
    tex:SetVertexColor(r, g, bl, 1)
    tex:SetAlpha(opacity * a)
end

--- Paint the fill and show it. The fill is shown every dress: the engine's no-aura pass hides a
--- dispel texture, and clearing the binding does not show it again.
local function paintFill(am, b, preview)
    am.fill:SetTexture(Style.Fetch("statusbar", b.barTexture, C.FALLBACK_TEXTURE))
    paintSurface(am.fill, b.colorMode, b.barColor, b.useClassColorBar, preview,
        tonumber(b.barAlpha) or D.bars.barAlpha)
    am.fill:Show()
end

--- Paint the surfaces: the fill, the background, the border and the spark. Each surface's opacity
--- multiplies onto its color's own alpha, so a color's alpha still applies (paintSurface). The background colors by
--- dispel type as the fill does (feedback #7) and is shown every dress for the same reason.
local function applySurfaces(am, b, preview)
    paintFill(am, b, preview)

    am.bg:SetTexture(Style.Fetch("statusbar", b.bgTexture, C.FALLBACK_TEXTURE))
    paintSurface(am.bg, b.bgColorMode, b.bgColor, b.useClassColorBg, preview,
        tonumber(b.bgAlpha) or D.bars.bgAlpha)
    am.bg:Show()

    Style.ApplyBorder(am.border, b.borderShow, b.borderStyle, tonumber(b.borderSize) or D.bars.borderSize,
        b.borderColor, b.useClassColorBorder)

    am.spark:SetShown(b.spark ~= false)
    am.spark:SetVertexColor(Style.Color(b.sparkColor, b.useClassColorSpark))
end

--- The width of the bar area: the element (`w` x `h`) minus the icon and its gap.
local function barAreaWidth(b, w, h)
    if b.icon == "NONE" then return w end
    return w - iconSizeFor(b, h) - (tonumber(b.iconGap) or D.bars.iconGap)
end

--- Whether a text block leaves its text shown (a missing block does).
local function textShown(t)
    return t == nil or t.show ~= false
end

--- The box a time text takes beside the name: the measured width of the widest string its format
--- writes in its font (Style.TimeTextWidth, B4), or, where nothing can be measured, the ems budget
--- (C.TIME_TEXT_EMS; a format this build does not know gets the widest). Plus its offset, which
--- Style.ApplyText takes back off, so an offset moves the text and never narrows its box; never wider
--- than the bar area.
local function timeBoxWidth(b, area)
    local t = b.time or {}
    local width = Style.TimeTextWidth(t, D.bars.time, b.timeFormat)
    if not width then
        local size = tonumber(t.fontSize) or D.bars.time.fontSize
        width = size * (C.TIME_TEXT_EMS[b.timeFormat] or C.TIME_TEXT_EMS.long)
    end
    return math.min(area, math.ceil(width) + math.abs(tonumber(t.x) or 0))
end

--- Dress the name, time and stack texts, each boxed to its host so its justification shows, and show
--- each one its settings leave on.
local function applyTexts(am, b, w, h)
    local area = barAreaWidth(b, w, h)
    local nameStops = b.name and b.time and textShown(b.name) and textShown(b.time)
    Style.ApplyText(am.name, b.name, am.bar, D.bars.name, area)
    -- While the name stops short of it, the time takes a box of its own format's width: one across
    -- the bar would put its left edge at the bar's start and leave the name no room.
    Style.ApplyText(am.time, b.time, am.bar, D.bars.time, nameStops and timeBoxWidth(b, area) or area)
    local onIcon = b.icon ~= "NONE"
    Style.ApplyText(am.stacks, b.stacks, onIcon and am.icon or am.bar, D.bars.stacks,
        onIcon and iconSizeFor(b, h) or area)
    -- The name stops short of the time's box rather than running under it; the second anchor
    -- overrides the name's own box.
    if nameStops then am.name:SetPoint("RIGHT", am.time, "LEFT", -4, 0) end
    am.name:SetShown(textShown(b.name))
    am.time:SetShown(textShown(b.time))
    am.stacks:SetShown(textShown(b.stacks))
end

function Bars.Apply(frame, cfg, engine)
    local b = cfg.bars or {}
    local w, h = Style.ElementSize(cfg)
    local am = Style.RegionsFor(frame, "bars", build)
    -- Before anything is painted or bound: a binding run with a stale dispel texture still listed
    -- would re-tint the fill after the static color (B-4).
    if engine then Style.ClearAdditiveBindings(frame) end

    frame:SetSize(w, h)
    layout(frame, am, b, h)
    applySurfaces(am, b, not engine)
    wireFill(am, b, engine, h)
    am.spark:SetSize(tonumber(b.sparkWidth) or D.bars.sparkWidth, h * 2)
    applyTexts(am, b, w, h)

    am.pandemic:SetVertexColor(Style.Color(b.pandemicColor, false))

    if engine then
        Bars.Bind(frame, am, cfg, b)
    end
end

--- AddDispelTypeTexture's options for a surface colored by dispel type: shown for every aura, our own
--- texture kept (PreserveAsset), tinted from the profile's palette, and an aura with no dispel type in
--- the surface's own `fallback` color (Style.DispelColorMap).
local function dispelTint(Compat, palette, fallback)
    return {
        showAlways = true, showWithoutDispelType = true,
        style = Compat.DispelStyle("PreserveAsset"),
        customDispelColorMap = Style.DispelColorMap(palette, fallback),
    }
end

--- Hand the regions to the engine. Every call is guarded (Style.Bind). The two ADDITIVE bindings only
--- add here: Bars.Apply has already cleared them, before any binding (Style.ClearAdditiveBindings).
function Bars.Bind(frame, am, cfg, b)
    local Compat = NS.Compat
    Style.Bind(frame, "SetDurationBar", am.bar, {
        direction = Compat.TimerDirection("elapsed"),
        interpolation = Compat.Interpolation(b.smooth),
    })
    if b.icon ~= "NONE" then Style.Bind(frame, "SetIcon", am.icon) end
    if b.name == nil or b.name.show ~= false then Style.Bind(frame, "SetSpellName", am.name) end
    if b.time == nil or b.time.show ~= false then Style.BindDurationText(frame, am.time, b, D.bars) end
    if b.stacks == nil or b.stacks.show ~= false then Style.Bind(frame, "SetApplicationCount", am.stacks, {}) end

    local palette = Style.ProfileDispelColors()
    if b.colorMode == "dispel" then
        Style.Bind(frame, "AddDispelTypeTexture", am.fill,
            dispelTint(Compat, palette, Style.CurveColor(b.barColor, b.useClassColorBar)))
    end
    if b.bgColorMode == "dispel" then
        Style.Bind(frame, "AddDispelTypeTexture", am.bg,
            dispelTint(Compat, palette, Style.CurveColor(b.bgColor, b.useClassColorBg)))
    end
    if b.pandemic then Style.Bind(frame, "AddPandemicRegion", am.pandemic) end

    Style.ApplyBehavior(frame, cfg)
end

--- A placeholder's icon and texts, the time in the bar's own format (Style.PreviewTime).
local function previewText(am, aura, b)
    am.icon:SetTexture(aura.icon)
    am.name:SetText(aura.name)
    Style.PreviewTime(am.time, aura, b, D.bars)
    am.stacks:SetText(aura.stacks > 1 and tostring(aura.stacks) or "")
end

--- Whether a placeholder's spark shows. Its duration is readable, so `sparkTimeless` is honored
--- directly: a timeless placeholder shows none when the option is off.
local function previewSparkShown(b, aura)
    if b.spark == false then return false end
    return aura.duration > 0 or Style.OrTemplate(b.sparkTimeless, D.bars.sparkTimeless) and true or false
end

--- Fill a PREVIEW element with placeholder values (modules/Preview.lua). The regions are ours, so
--- this is ordinary drawing; the fraction stands in for what the engine's timer would show.
function Bars.FillPreview(frame, aura, cfg)
    local am = frame.__am
    if not am then return end
    local b = cfg.bars or {}
    previewText(am, aura, b)

    -- Preview draws the fill directly, as the fraction of the bar area the engine's timer would.
    local frac = aura.duration > 0 and (aura.remaining / aura.duration) or 1
    local fromRight = (b.drain == "right")
    local side = fromRight and "RIGHT" or "LEFT"
    am.fill:ClearAllPoints()
    am.fill:SetPoint("TOP" .. side, am.bar, "TOP" .. side, 0, 0)
    am.fill:SetPoint("BOTTOM" .. side, am.bar, "BOTTOM" .. side, 0, 0)
    local w, h = Style.ElementSize(cfg)
    am.fill:SetWidth(math.max(1, barAreaWidth(b, w, h) * frac))
    am.spark:ClearAllPoints()
    am.spark:SetPoint("CENTER", am.fill, fromRight and "LEFT" or "RIGHT", 0, 0)
    am.spark:SetShown(previewSparkShown(b, aura))
end
