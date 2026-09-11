local _, NS = ...

-- modules/Style.lua — the shared half of dressing an element: media lookups, fonts, borders, colors,
-- and the one guarded way to hand a region to Blizzard's aura engine.
--
-- AN ELEMENT IS DRESSED ONCE, AND DRESSED AGAIN ONLY WHILE AURAS ARE READABLE. The engine calls our
-- initializeFrame the moment it creates a button and then locks the button against addon access while
-- auras are secret (`DenyTaintedAccessWhenAurasAreSecret`). So Style.Element builds its regions on the
-- first call and re-applies the look on every later one, and modules/Container.lua only makes those
-- later calls when modules/ContainerManager.lua says aura secrecy has lifted.
--
-- The same functions dress the addon's own PREVIEW frames (modules/Preview.lua), with `engine` false:
-- identical regions and looks, no engine bindings, placeholder values filled in by hand.

NS.Style = NS.Style or {}
local Style = NS.Style

local C = NS.Constants
local Perf = NS.Perf

-- A flat one-pixel border, registered under a name the border dropdown can offer. It is not a file this
-- addon ships: WHITE8X8 is a client texture, stretched into an edge of any thickness.
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
if LSM then LSM:Register("border", "Solid", C.WHITE_TEXTURE) end

--- A LibSharedMedia path for `key` of `mediaType`, or `fallback` when LSM is absent or the key no
--- longer resolves (a media pack uninstalled since the profile was written).
function Style.Fetch(mediaType, key, fallback)
    if LSM and type(key) == "string" and key ~= "" then
        local ok, path = pcall(LSM.Fetch, LSM, mediaType, key, true)
        if ok and path then return path end
    end
    return fallback
end

--- r, g, b, a for a stored color and its class-color companion. The class is the PLAYER's for every
--- surface in this addon: an element describes an aura rather than a unit, and a container's unit can
--- change mid-combat when restyling is not allowed, so a class color that followed the target would be
--- wrong until the next restyle. The stored alpha always survives (options-ui-§17).
function Style.Color(stored, useClass)
    return NS.ResolveColor(stored, useClass, "player")
end

local FLAG_MAP = { NONE = "", OUTLINE = "OUTLINE", THICKOUTLINE = "THICKOUTLINE",
    MONOCHROME = "MONOCHROME", MONOCHROMEOUTLINE = "MONOCHROME,OUTLINE" }

--- Apply one text block (the six canonical font leaves plus point / x / y / justify / show) to a
--- FontString parented under `anchorTo`.
function Style.ApplyText(fs, t, anchorTo)
    if not (fs and t) then return end
    local size = tonumber(t.fontSize) or 11
    local flags = FLAG_MAP[t.fontFlags or "NONE"] or (t.fontFlags or "")
    local path = Style.Fetch("font", t.font, C.FALLBACK_FONT)
    if not fs:SetFont(path, size, flags) then fs:SetFont(C.FALLBACK_FONT, size, flags) end
    fs:SetTextColor(Style.Color(t.fontColor, t.useClassColorFont))
    if t.fontShadow then
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowOffset(0, 0)
    end
    fs:ClearAllPoints()
    local point = t.point or "CENTER"
    fs:SetPoint(point, anchorTo, point, tonumber(t.x) or 0, tonumber(t.y) or 0)
    fs:SetJustifyH(t.justify or "CENTER")
    fs:SetWordWrap(false)
end

--- Dress a BackdropTemplate frame as an element border.
function Style.ApplyBorder(frame, show, styleKey, size, stored, useClass)
    if not frame then return end
    if not show or styleKey == "None" or (tonumber(size) or 0) <= 0 then
        frame:Hide()
        return
    end
    local edge = Style.Fetch("border", styleKey, C.FALLBACK_BORDER)
    if frame.SetBackdrop then
        frame:SetBackdrop({ edgeFile = edge, edgeSize = tonumber(size) or 1 })
        frame:SetBackdropBorderColor(Style.Color(stored, useClass))
    end
    frame:Show()
end

--- Whether `frame` is one of the engine's aura buttons (as opposed to a preview frame of ours).
function Style.IsEngineButton(frame)
    return type(frame) == "table" and type(frame.SetDurationBar) == "function"
        and type(frame.SetIcon) == "function"
end

--- Call one engine binding, guarded. A binding that raises — an option this client does not know, an
--- access refusal the secrecy check did not foresee — costs that one binding and is logged, never the
--- button, because the engine created the button inside its own frame batch and an error there would
--- take the batch with it.
function Style.Bind(frame, method, ...)
    local fn = frame[method]
    if type(fn) ~= "function" then return false end
    local ok, err = pcall(fn, frame, ...)
    if not ok and NS.Debug then NS.Debug("Style", "%s failed: %s", method, err) end
    return ok
end

--- A color map for AddDispelTypeTexture's `customDispelColorMap`, from a stored { Magic = {r,g,b,a} }.
function Style.DispelColorMap(stored)
    local out = {}
    if type(stored) ~= "table" or not _G.CreateColor then return out end
    for _, name in ipairs(C.DISPEL_TYPES) do
        local c = stored[name]
        if type(c) == "table" then out[name] = _G.CreateColor(c.r or 1, c.g or 1, c.b or 1) end
    end
    return out
end

--- The size one element occupies, from the container's style settings — what the engine's flow layout
--- is told (elementWidth / elementHeight), and what the drag handle and the preview are sized to.
--- @return number width, number height
function Style.ElementSize(cfg)
    if cfg.style == "icons" then
        local ic = cfg.icons or {}
        return tonumber(ic.width) or 32, tonumber(ic.height) or 32
    end
    local b = cfg.bars or {}
    return tonumber(b.width) or 220, tonumber(b.height) or 18
end

--- Dress one element for `cfg` (a container's stored table). `engine` true binds the regions to the
--- engine's aura data; false leaves them for the preview to fill.
function Style.Element(frame, cfg, engine)
    local t0 = Perf.on and debugprofilestop()
    local styler = (cfg.style == "icons") and Style.Icons or Style.Bars
    if styler then styler.Apply(frame, cfg, engine) end
    if t0 then Perf.Note("styleElement", debugprofilestop() - t0) end
end

--- Whether right-click cancels this element's aura. Only the player's own buffs and weapon enchants
--- can be canceled — a debuff or a target's buff cannot, and registering the click there would only
--- swallow it — and a click-through container takes no clicks at all.
local function cancelEnabled(cfg, b)
    if b.clickThrough or not b.cancelOnRightClick then return false end
    return cfg.unit == "player" and (cfg.auraType == "HELPFUL" or cfg.auraType == "ENCHANT")
end

--- The mouse behavior shared by both styles: tooltips, click-through and right-click cancel.
function Style.ApplyBehavior(frame, cfg)
    local b = cfg.behavior or {}
    local through = b.clickThrough and true or false
    local cancel = cancelEnabled(cfg, b)
    if frame.SetMouseMotionEnabled then frame:SetMouseMotionEnabled(not through and b.tooltips ~= false) end
    if frame.SetMouseClickEnabled then frame:SetMouseClickEnabled(cancel) end
    -- One click phase only — never both. A button reassigned to a different aura between the press
    -- and the release would cancel the wrong one.
    Style.Bind(frame, "SetCancelAuraButtons", cancel and "RightButtonUp" or nil)
    Style.Bind(frame, "SetTooltipAnchorPoint", b.tooltipAnchor or "ANCHOR_BOTTOMLEFT", 0, 0)
    Style.Bind(frame, "SetHideTooltipInCombat", b.tooltipInCombat == false)
end

--- Bind the duration text with the configured formatter and expiring color.
function Style.BindDurationText(frame, fs, s)
    local opts = {}
    local formatter = NS.Compat.CreateSecondsFormatter(s.timeFormat)
    if formatter then opts.textFormatter = formatter end
    if s.expiringColorOn then
        local tc = NS.Compat.ExpiringTextColor(tonumber(s.expiringThreshold) or 5, s.expiringColor or {},
            (s.time and s.time.fontColor) or {})
        if tc then opts.textColor = tc end
    end
    Style.Bind(frame, "SetDurationText", fs, opts)
end
