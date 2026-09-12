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
    am.bg = frame:CreateTexture(nil, "BACKGROUND")

    -- The engine's StatusBar, invisible on purpose (see the file header).
    am.bar = CreateFrame("StatusBar", nil, frame)
    am.bar:SetStatusBarTexture(C.WHITE_TEXTURE)
    am.bar:SetStatusBarColor(1, 1, 1, 0)
    am.bar:SetMinMaxValues(0, 1)

    am.fill = am.bar:CreateTexture(nil, "ARTWORK")
    am.spark = am.bar:CreateTexture(nil, "OVERLAY")
    am.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    am.spark:SetBlendMode("ADD")

    -- Text sits in its own frame above the bar, so it is never under the fill and never inherits an
    -- alpha set on the bar.
    am.text = CreateFrame("Frame", nil, frame)
    am.text:SetAllPoints(frame)
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

--- The icon's side: its stored size, or the template's when that is missing; zero means the bar's height.
local function iconSizeFor(b, h)
    local size = tonumber(b.iconSize) or D.bars.iconSize
    return size > 0 and size or h
end

--- Lay the icon and the bar area out inside the element.
local function layout(frame, am, b, h)
    local iconPos = b.icon or D.bars.icon
    local iconSize = iconSizeFor(b, h)
    local gap = tonumber(b.iconGap) or D.bars.iconGap

    am.icon:ClearAllPoints()
    am.bar:ClearAllPoints()
    am.bg:ClearAllPoints()

    if iconPos == "NONE" then
        am.icon:Hide()
        am.bar:SetAllPoints(frame)
    else
        am.icon:Show()
        am.icon:SetSize(iconSize, iconSize)
        if iconPos == "RIGHT" then
            am.icon:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
            am.bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            am.bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(iconSize + gap), 0)
        else
            am.icon:SetPoint("LEFT", frame, "LEFT", 0, 0)
            am.bar:SetPoint("TOPLEFT", frame, "TOPLEFT", iconSize + gap, 0)
            am.bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        end
        local z = tonumber(b.iconZoom) or D.bars.iconZoom
        am.icon:SetTexCoord(z, 1 - z, z, 1 - z)
    end
    am.bg:SetAllPoints(am.bar)
end

--- Point the fill and the spark at the status bar's moving edge, per drain direction.
local function wireFill(am, b)
    local edge = am.bar:GetStatusBarTexture()
    am.fill:ClearAllPoints()
    am.spark:ClearAllPoints()
    if b.drain == "right" then
        -- Elapsed grows from the LEFT; remaining is the part right of the texture's right edge.
        am.bar:SetReverseFill(false)
        am.fill:SetPoint("TOPLEFT", edge, "TOPRIGHT", 0, 0)
        am.fill:SetPoint("BOTTOMRIGHT", am.bar, "BOTTOMRIGHT", 0, 0)
        am.spark:SetPoint("CENTER", am.fill, "LEFT", 0, 0)
    else
        -- Elapsed grows from the RIGHT; remaining is the part left of the texture's left edge.
        am.bar:SetReverseFill(true)
        am.fill:SetPoint("TOPLEFT", am.bar, "TOPLEFT", 0, 0)
        am.fill:SetPoint("BOTTOMRIGHT", edge, "BOTTOMLEFT", 0, 0)
        am.spark:SetPoint("CENTER", am.fill, "RIGHT", 0, 0)
    end
end

--- Paint the surfaces: the fill, the background, the border and the spark. Each surface's opacity
--- multiplies onto its color's own alpha, so a color's alpha still applies.
local function applySurfaces(am, b)
    am.fill:SetTexture(Style.Fetch("statusbar", b.barTexture, C.FALLBACK_TEXTURE))
    am.fill:SetVertexColor(Style.Color(b.barColor, b.useClassColorBar))
    am.fill:SetAlpha(tonumber(b.barAlpha) or D.bars.barAlpha)

    am.bg:SetTexture(Style.Fetch("statusbar", b.bgTexture, C.FALLBACK_TEXTURE))
    am.bg:SetVertexColor(Style.Color(b.bgColor, b.useClassColorBg))
    am.bg:SetAlpha(tonumber(b.bgAlpha) or D.bars.bgAlpha)

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

--- Dress the name, time and stack texts, each boxed to its host so its justification shows, and show
--- each one its settings leave on.
local function applyTexts(am, b, w, h)
    local area = barAreaWidth(b, w, h)
    local nameStops = b.name and b.time and textShown(b.name) and textShown(b.time)
    Style.ApplyText(am.name, b.name, am.bar, D.bars.name, area)
    -- While the name stops short of it, the time sizes to its own string: a time boxed across the bar
    -- would put its left edge at the bar's start and leave the name no room.
    Style.ApplyText(am.time, b.time, am.bar, D.bars.time, (not nameStops) and area or nil)
    local onIcon = b.icon ~= "NONE"
    Style.ApplyText(am.stacks, b.stacks, onIcon and am.icon or am.bar, D.bars.stacks,
        onIcon and iconSizeFor(b, h) or area)
    -- The name stops short of the time text rather than running under it; the second anchor
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

    frame:SetSize(w, h)
    layout(frame, am, b, h)
    applySurfaces(am, b)
    wireFill(am, b)
    am.spark:SetSize(tonumber(b.sparkWidth) or D.bars.sparkWidth, h * 2)
    applyTexts(am, b, w, h)

    am.pandemic:SetVertexColor(Style.Color(b.pandemicColor, false))

    if engine then
        Bars.Bind(frame, am, cfg, b)
    end
end

--- Hand the regions to the engine. Every call is guarded (Style.Bind), and the two ADDITIVE bindings
--- are cleared first: AddDispelTypeTexture and AddPandemicRegion append, so a restyle that re-added
--- them would stack a second tint and a second highlight on every settings change.
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

    Style.Bind(frame, "ClearDispelTypeTextures")
    if b.colorMode == "dispel" then
        Style.Bind(frame, "AddDispelTypeTexture", am.fill, {
            showAlways = true, showWithoutDispelType = true,
            style = Compat.DispelStyle("PreserveAsset"),
            customDispelColorMap = Style.DispelColorMap(b.dispelColors),
        })
    end

    Style.Bind(frame, "ClearPandemicRegions")
    if b.pandemic then Style.Bind(frame, "AddPandemicRegion", am.pandemic) end

    Style.ApplyBehavior(frame, cfg)
end

--- A placeholder's icon and texts.
local function previewText(am, aura)
    am.icon:SetTexture(aura.icon)
    am.name:SetText(aura.name)
    am.time:SetText(aura.duration > 0 and ("%ds"):format(aura.remaining) or "")
    am.stacks:SetText(aura.stacks > 1 and tostring(aura.stacks) or "")
end

--- Fill a PREVIEW element with placeholder values (modules/Preview.lua). The regions are ours, so
--- this is ordinary drawing; the fraction stands in for what the engine's timer would show.
function Bars.FillPreview(frame, aura, cfg)
    local am = frame.__am
    if not am then return end
    local b = cfg.bars or {}
    previewText(am, aura)

    -- Preview draws the fill directly, as the fraction of the bar area the engine's timer would.
    local frac = aura.duration > 0 and (aura.remaining / aura.duration) or 1
    local fromRight = (b.drain == "right")
    local side = fromRight and "RIGHT" or "LEFT"
    am.fill:ClearAllPoints()
    am.fill:SetPoint("TOP" .. side, am.bar, "TOP" .. side, 0, 0)
    am.fill:SetPoint("BOTTOM" .. side, am.bar, "BOTTOM" .. side, 0, 0)
    local w, h = Style.ElementSize(cfg)
    am.fill:SetWidth(math.max(1, barAreaWidth(b, w, h) * frac))
    local c = (b.colorMode == "dispel") and b.dispelColors and b.dispelColors.Magic
    if c then am.fill:SetVertexColor(c.r or 1, c.g or 1, c.b or 1, 1) end
    am.spark:ClearAllPoints()
    am.spark:SetPoint("CENTER", am.fill, fromRight and "LEFT" or "RIGHT", 0, 0)
end
