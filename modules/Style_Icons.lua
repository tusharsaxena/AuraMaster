local _, NS = ...

-- modules/Style_Icons.lua — dressing one aura as an ICON.
--
--     ┌───────────┐  border (ours) · dispel-type edge above it (our shape, the engine's color)
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

-- The dispel edge's four strips on `am`, in Style.TintEdge's order: top, bottom, left, right.
local DISPEL_EDGES = { "dispelTop", "dispelBottom", "dispelLeft", "dispelRight" }

local function build(frame)
    local am = {}
    frame.__am = am
    am.style = "icons"   -- the tag Style.RegionsFor reads

    am.icon = frame:CreateTexture(nil, "ARTWORK")

    -- The cooldown the engine drives from the aura's duration object.
    am.cd = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    am.cd:SetAllPoints(am.icon)
    am.cd:SetDrawBling(false)

    -- A plain frame, never a BackdropTemplate: its size reads secret once the engine lays the button
    -- out (Style.NewBorder, B2-3).
    am.border = Style.NewBorder(frame)
    am.border:SetAllPoints(frame)

    -- The dispel-type edge: four white strips in our Solid border's shape (Style.TintEdge), which the
    -- engine shows and tints in Blizzard's own color for the aura's dispel type, and hides for an
    -- aura without one (DB-1). They live on a frame of their own ABOVE our border: a region of the
    -- button draws below every child frame, so drawn there our border would cover them. Above it, the
    -- colored edge lies exactly over ours where the aura has a dispel type, and ours shows wherever it
    -- has none (I-1; docs/superpowers/research/2026-09-13-aura-engine-notes.md Q3). Each strip is its
    -- own key on `am`: a region never hides in a list the style suites cannot see.
    am.dispelHost = CreateFrame("Frame", nil, frame)
    am.dispelHost:SetAllPoints(frame)
    for _, k in ipairs(DISPEL_EDGES) do am[k] = am.dispelHost:CreateTexture(nil, "OVERLAY") end

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

    -- Sibling frames made at one level stack in no promised order, so set it, bottom to top: the
    -- cooldown swipe, our border, the dispel border, the texts. Once, here, where every level is a
    -- fresh frame's own number.
    local level = am.cd:GetFrameLevel()
    am.border:SetFrameLevel(level + 1)
    am.dispelHost:SetFrameLevel(level + 2)
    am.text:SetFrameLevel(level + 3)
    return am
end

--- The border's thickness: the stored size, or the template's when that is missing or garbage. One
--- reading for the border itself and the art's inset, so the two cannot disagree.
local function borderSizeOf(ic)
    return tonumber(ic.borderSize) or D.icons.borderSize
end

--- Place the icon INSIDE the border, so a thick border never hides the art, and crop the zoom to
--- the element's aspect ratio, so a non-square icon is cropped rather than squashed. Returns the inset.
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
    return inset
end

--- The dispel edge's thickness: our border's, so the colored edge lies exactly over it; 1 px when our
--- border is hidden, styled None or 0 thick, so a typed debuff still shows its color (DB-2).
local function dispelSizeOf(ic)
    local shown = Style.OrTemplate(ic.borderShow, D.icons.borderShow)
    local size = borderSizeOf(ic)
    if shown and ic.borderStyle ~= "None" and size > 0 then return size end
    return 1
end

-- AddDispelTypeTexture's options for the dispel edge, built on first use (the enum may not exist at
-- load): debuffs with a dispel type only, our white strip kept and tinted (PreserveAsset), and NO
-- customDispelColorMap, so the engine paints AuraUtil.SetAuraBorderColor, Blizzard's own color for
-- the type (DB-2; owner 2026-09-13: General -> Dispel Colors do not drive icons).
local dispelOptions
local function dispelOptionsFor()
    if not dispelOptions then
        dispelOptions = { showWhenHarmful = true, showWhenHelpful = false, showWithoutDispelType = false,
            style = NS.Compat.DispelStyle("PreserveAsset") }
    end
    return dispelOptions
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
    local am = Style.RegionsFor(frame, "icons", build)
    -- Before anything is hidden or bound: a binding run with a stale dispel texture still listed
    -- would show the dispel border again after the hide below (B-4).
    if engine then Style.ClearAdditiveBindings(frame) end

    frame:SetSize(w, h)
    layoutIcon(am, frame, ic, w, h)
    -- Guarded (B2-3): a border the client refuses costs the border, never Icons.Bind below, which
    -- re-adds the pandemic highlight and the time color the Clear above removed.
    Style.GuardedBorder("icon border", am.border, Style.OrTemplate(ic.borderShow, D.icons.borderShow),
        ic.borderStyle, borderSizeOf(ic), ic.borderColor, ic.useClassColorBorder)
    applyCooldown(am.cd, ic)

    -- Each text is boxed to the icon's width, so its justification shows.
    Style.ApplyText(am.time, ic.time, frame, D.icons.time, w)
    Style.ApplyText(am.stacks, ic.stacks, frame, D.icons.stacks, w)
    am.time:SetShown(ic.time == nil or ic.time.show ~= false)
    am.stacks:SetShown(ic.stacks == nil or ic.stacks.show ~= false)

    am.pandemic:SetVertexColor(Style.Color(ic.pandemicColor, false))
    -- Every dress, the option on or off: laid, white and hidden before any binding (B-4).
    Style.TintEdge(am.dispelHost, dispelSizeOf(ic), am.dispelTop, am.dispelBottom, am.dispelLeft, am.dispelRight)

    if engine then
        Icons.Bind(frame, am, cfg, ic)
    end
end

--- Hand the regions to the engine. The two ADDITIVE bindings only add here: Icons.Apply has already
--- cleared them, before any binding, so a restyle neither stacks a second border or highlight nor
--- lets a binding's apply pass show a border just turned off (Style.ClearAdditiveBindings).
function Icons.Bind(frame, am, cfg, ic)
    Style.Bind(frame, "SetIcon", am.icon)
    if ic.cooldown ~= false then Style.Bind(frame, "SetDurationCooldown", am.cd) end
    if ic.time == nil or ic.time.show ~= false then Style.BindDurationText(frame, am.time, ic, D.icons) end
    if ic.stacks == nil or ic.stacks.show ~= false then Style.Bind(frame, "SetApplicationCount", am.stacks, {}) end

    if Style.OrTemplate(ic.dispelBorder, D.icons.dispelBorder) then
        -- Our strips, in Blizzard's own colors (dispelOptionsFor). A placeholder takes the same
        -- color from Icons.FillPreview.
        local opts = dispelOptionsFor()
        for _, k in ipairs(DISPEL_EDGES) do Style.Bind(frame, "AddDispelTypeTexture", am[k], opts) end
    end
    if ic.pandemic then Style.Bind(frame, "AddPandemicRegion", am.pandemic) end

    Style.ApplyBehavior(frame, cfg)
end

--- Show a placeholder's dispel edge in Blizzard's color for its aura's type, or hide it, by the live
--- binding's rules (Icons.Bind): the option on, a debuff container and an aura with a dispel type
--- (TD-4, DB-1).
local function previewDispel(am, aura, cfg)
    local on = cfg and cfg.auraType == "HARMFUL" and aura.dispel
        and Style.OrTemplate((cfg.icons or {}).dispelBorder, D.icons.dispelBorder)
    for _, k in ipairs(DISPEL_EDGES) do
        local strip = am[k]
        strip:SetShown((on and NS.Compat.SetAuraBorderColor(strip, aura.dispel)) and true or false)
    end
end

--- Fill a PREVIEW icon with placeholder values (modules/Preview.lua), the time in the icon's own
--- format (Style.PreviewTime). A placeholder has no engine, so its dispel edge is tinted here.
function Icons.FillPreview(frame, aura, cfg)
    local am = frame.__am
    if not am then return end
    previewDispel(am, aura, cfg)
    am.icon:SetTexture(aura.icon)
    Style.PreviewTime(am.time, aura, (cfg and cfg.icons) or {}, D.icons)
    am.stacks:SetText(aura.stacks > 1 and tostring(aura.stacks) or "")
    if am.cd.SetCooldown and aura.duration > 0 then
        am.cd:SetCooldown((GetTime() or 0) - (aura.duration - aura.remaining), aura.duration)
    elseif am.cd.Clear then
        am.cd:Clear()
    end
end
