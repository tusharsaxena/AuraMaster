local _, NS = ...

-- modules/Style_Icons.lua — dressing one aura as an ICON.
--
--     ┌───────────┐  border (ours) · dispel-type border (the engine tints it)
--     │   icon    │  cooldown swipe driven by the aura's duration
--     │        3  │  stack count
--     └───────────┘
--         12s        time text
--
-- LOAD-BEARING POSITION: after modules/Style.lua, whose NS.Style this decorates at file scope.

local Style = NS.Style
local C = NS.Constants
local D = NS.CONTAINER_TEMPLATE

Style.Icons = Style.Icons or {}
local Icons = Style.Icons

local function build(frame)
    local am = {}
    frame.__am = am

    am.icon = frame:CreateTexture(nil, "ARTWORK")

    -- The cooldown the engine drives from the aura's duration object.
    am.cd = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    am.cd:SetAllPoints(am.icon)
    am.cd:SetDrawBling(false)

    am.border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    am.border:SetAllPoints(frame)

    -- The dispel-type border: a texture the engine sets to Blizzard's own debuff border art for the
    -- aura's dispel type, and hides for an aura without one.
    am.dispel = frame:CreateTexture(nil, "OVERLAY")
    am.dispel:SetAllPoints(frame)

    -- Text above the cooldown swipe, so the countdown is never shaded by it.
    am.text = CreateFrame("Frame", nil, frame)
    am.text:SetAllPoints(frame)
    am.time = am.text:CreateFontString(nil, "OVERLAY")
    am.stacks = am.text:CreateFontString(nil, "OVERLAY")

    am.pandemic = am.text:CreateTexture(nil, "BACKGROUND")
    am.pandemic:SetAllPoints(frame)
    am.pandemic:SetTexture(C.WHITE_TEXTURE)
    am.pandemic:SetBlendMode("ADD")
    am.pandemic:Hide()
    return am
end

--- The border's thickness: the stored size, or the template's when that is missing or garbage. One
--- reading for the border itself and the art's inset, so the two cannot disagree.
local function borderSizeOf(ic)
    return tonumber(ic.borderSize) or D.icons.borderSize
end

--- Place the icon INSIDE the border, so a thick border never hides the art, and crop the zoom to
--- the element's aspect ratio, so a non-square icon is cropped rather than squashed.
local function layoutIcon(am, frame, ic, w, h)
    local shown = Style.OrTemplate(ic.borderShow, D.icons.borderShow)
    local inset = (shown and ic.borderStyle ~= "None") and borderSizeOf(ic) or 0
    am.icon:ClearAllPoints()
    am.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    am.icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    local z = tonumber(ic.zoom) or D.icons.zoom
    local zx, zy = z, z
    if w > h and w > 0 then
        zy = z + (1 - 2 * z) * (1 - h / w) / 2
    elseif h > w and h > 0 then
        zx = z + (1 - 2 * z) * (1 - w / h) / 2
    end
    am.icon:SetTexCoord(zx, 1 - zx, zy, 1 - zy)
end

--- The cooldown swipe's look.
local function applyCooldown(cd, ic)
    local on = ic.cooldown ~= false
    cd:SetShown(on)
    cd:SetDrawSwipe(on)
    cd:SetReverse(ic.cooldownReverse and true or false)
    cd:SetDrawEdge(Style.OrTemplate(ic.cooldownEdge, D.icons.cooldownEdge) and true or false)
    cd:SetSwipeColor(0, 0, 0, tonumber(ic.swipeAlpha) or D.icons.swipeAlpha)
    cd:SetHideCountdownNumbers(not ic.blizzardNumbers)
end

function Icons.Apply(frame, cfg, engine)
    local ic = cfg.icons or {}
    local w, h = Style.ElementSize(cfg)
    local am = frame.__am or build(frame)

    frame:SetSize(w, h)
    layoutIcon(am, frame, ic, w, h)
    Style.ApplyBorder(am.border, Style.OrTemplate(ic.borderShow, D.icons.borderShow), ic.borderStyle,
        borderSizeOf(ic), ic.borderColor, ic.useClassColorBorder)
    applyCooldown(am.cd, ic)

    Style.ApplyText(am.time, ic.time, frame, D.icons.time)
    Style.ApplyText(am.stacks, ic.stacks, frame, D.icons.stacks)
    am.time:SetShown(ic.time == nil or ic.time.show ~= false)
    am.stacks:SetShown(ic.stacks == nil or ic.stacks.show ~= false)

    am.pandemic:SetVertexColor(Style.Color(ic.pandemicColor, false))
    if not Style.OrTemplate(ic.dispelBorder, D.icons.dispelBorder) then am.dispel:Hide() end

    if engine then
        Icons.Bind(frame, am, cfg, ic)
    end
end

--- Hand the regions to the engine. The two ADDITIVE bindings are cleared first so a restyle does not
--- stack a second border or highlight (see modules/Style_Bars.lua's Bind).
function Icons.Bind(frame, am, cfg, ic)
    local Compat = NS.Compat
    Style.Bind(frame, "SetIcon", am.icon)
    if ic.cooldown ~= false then Style.Bind(frame, "SetDurationCooldown", am.cd) end
    if ic.time == nil or ic.time.show ~= false then Style.BindDurationText(frame, am.time, ic, D.icons) end
    if ic.stacks == nil or ic.stacks.show ~= false then Style.Bind(frame, "SetApplicationCount", am.stacks, {}) end

    Style.Bind(frame, "ClearDispelTypeTextures")
    if Style.OrTemplate(ic.dispelBorder, D.icons.dispelBorder) then
        Style.Bind(frame, "AddDispelTypeTexture", am.dispel, {
            showWhenHarmful = true, showWhenHelpful = false,
            style = Compat.DispelStyle("Border"),
        })
    end

    Style.Bind(frame, "ClearPandemicRegions")
    if ic.pandemic then Style.Bind(frame, "AddPandemicRegion", am.pandemic) end

    Style.ApplyBehavior(frame, cfg)
end

--- Fill a PREVIEW icon with placeholder values (modules/Preview.lua).
function Icons.FillPreview(frame, aura)
    local am = frame.__am
    if not am then return end
    am.icon:SetTexture(aura.icon)
    am.time:SetText(aura.duration > 0 and ("%ds"):format(aura.remaining) or "")
    am.stacks:SetText(aura.stacks > 1 and tostring(aura.stacks) or "")
    if am.cd.SetCooldown and aura.duration > 0 then
        am.cd:SetCooldown((GetTime() or 0) - (aura.duration - aura.remaining), aura.duration)
    elseif am.cd.Clear then
        am.cd:Clear()
    end
end
