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
-- The one home for defaults (savedvariables-§2): a stored leaf that is missing or garbage falls back
-- to the template's value for the same path, never to a number restated here.
local D = NS.CONTAINER_TEMPLATE

--- A stored leaf, or `default` (the template's value for the same path) when the leaf is missing.
--- For the boolean leaves, where `v or default` would turn a stored false into the default.
function Style.OrTemplate(v, default)
    if v == nil then return default end
    return v
end

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

-- The class color of the dress in progress: the container's snapshot of its tracked unit's class
-- ({ r, g, b }, with r nil when that class did not resolve), or nil for a player container. Set and
-- cleared by Style.Element, so nothing between it and Style.Color has to thread it through.
local dressClass

--- r, g, b, a for a stored color and its class-color companion. The class is the one the surface
--- describes (options-ui-§17): a container tracking another unit paints with that unit's class, as
--- snapshotted at its last apply (modules/Container.lua's SnapshotClass), because buttons cannot be
--- re-dressed while auras are secret and every button of one container must show one class. A
--- tracked unit whose class does not resolve (an NPC) falls through to the stored swatch; a player
--- container reads the player's class. The stored alpha always survives. The in-combat staleness
--- after a unit swap is the residual ratified in docs/ARCHITECTURE.md → Documented deviations.
function Style.Color(stored, useClass)
    if useClass and dressClass then
        local r, g, b, a = NS.ResolveColor(stored, false)
        if dressClass.r == nil then return r, g, b, a end
        return dressClass.r, dressClass.g, dressClass.b, a
    end
    return NS.ResolveColor(stored, useClass, "player")
end

--- Whether any `useClassColor*` flag in one table is on.
local function anyClassFlag(t)
    for k, v in pairs(t) do
        if v == true and type(k) == "string" and k:find("^useClassColor") then return true end
    end
    return false
end

--- Whether the container's active style block (or one of its text blocks) turns a class color on.
--- Allocation-free: it runs on every unit swap for each container tracking the swapped unit.
function Style.UsesClassColor(cfg)
    local s = (cfg.style == "icons") and cfg.icons or cfg.bars
    if type(s) ~= "table" then return false end
    if anyClassFlag(s) then return true end
    for _, sub in pairs(s) do
        if type(sub) == "table" and anyClassFlag(sub) then return true end
    end
    return false
end

local FLAG_MAP = { NONE = "", OUTLINE = "OUTLINE", THICKOUTLINE = "THICKOUTLINE",
    MONOCHROME = "MONOCHROME", MONOCHROMEOUTLINE = "MONOCHROME,OUTLINE" }

--- A text's width inside a box `boxWidth` wide, less its X offset so it stays inside its host; never
--- under one pixel. No box answers 0: the font string sizes to its own string.
local function textWidth(boxWidth, x)
    if not boxWidth then return 0 end
    return math.max(1, boxWidth - math.abs(x))
end

--- Apply one text block (the six canonical font leaves plus point / x / y / justify / show) to a
--- FontString parented under `anchorTo`. `tdef` is the template's block for the same element, which
--- the size, point and justify fall back to. `boxWidth` is the width the text may take (its host's):
--- a single-anchor font string sized to its own string has nothing to justify within, so a text given
--- a box is as wide as the box less its offset. A second anchor, set after this, overrides the width.
function Style.ApplyText(fs, t, anchorTo, tdef, boxWidth)
    if not (fs and t) then return end
    local size = tonumber(t.fontSize) or tdef.fontSize
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
    local point = t.point or tdef.point
    local x = tonumber(t.x) or 0
    fs:SetPoint(point, anchorTo, point, x, tonumber(t.y) or 0)
    fs:SetWidth(textWidth(boxWidth, x))
    fs:SetJustifyH(t.justify or tdef.justify)
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

--- Empty the engine's two ADDITIVE binding lists (AddDispelTypeTexture and AddPandemicRegion append,
--- so a restyle that re-added them would stack a second tint and a second highlight). Called FIRST in
--- a live dress, before any other binding: every Set* / Add* binding re-runs the engine's whole apply
--- pass, which re-tints whatever dispel texture is still listed, while the Clear itself restores
--- nothing (docs/superpowers/research/2026-09-13-aura-engine-notes.md Q1, B-4).
function Style.ClearAdditiveBindings(frame)
    Style.Bind(frame, "ClearDispelTypeTextures")
    Style.Bind(frame, "ClearPandemicRegions")
end

-- ---------------------------------------------------------------------------
-- Built once per look
-- ---------------------------------------------------------------------------
-- A formatter, a color curve and a dispel color map are the same for every button of one look, so
-- each is built once per distinct input and handed to every button, with no allocation on a hit.
-- The memos are validated by INPUT IDENTITY, which is sound because a settings write never edits a
-- stored table in place: NS.SetByPath stores a copy of the value, and a whole-section write stores
-- deep copies. A changed color is therefore a new table, and a new table misses. Keys are weak, so
-- the entries for a replaced color go when the color does.

local WEAK_KEYS = { __mode = "k" }
local NO_COLOR = {}
local formatters = {}
local curves = setmetatable({}, WEAK_KEYS)
local dispelMaps = setmetatable({}, WEAK_KEYS)

--- The engine's text formatter for one time format, shared by every button that uses it.
local function formatterFor(fmt)
    local key = fmt or false
    local f = formatters[key]
    if f == nil then
        f = NS.Compat.CreateSecondsFormatter(fmt)
        formatters[key] = f
    end
    return f
end

--- The expiring-text color curve for one threshold and color pair: `curves[expiring][normal][threshold]`.
local function curveFor(threshold, expiring, normal)
    local byNormal = curves[expiring]
    if not byNormal then
        byNormal = setmetatable({}, WEAK_KEYS)
        curves[expiring] = byNormal
    end
    local byThreshold = byNormal[normal]
    if not byThreshold then
        byThreshold = {}
        byNormal[normal] = byThreshold
    end
    local tc = byThreshold[threshold]
    if tc == nil then
        tc = NS.Compat.ExpiringTextColor(threshold, expiring, normal)
        byThreshold[threshold] = tc
    end
    return tc
end

--- Whether a memoized dispel map was built from exactly the color leaves `stored` holds now.
local function dispelMapCurrent(entry, stored)
    local types, src = C.DISPEL_TYPES, entry.src
    local count = #types
    for i = 1, count do
        if stored[types[i]] ~= src[types[i]] then return false end
    end
    return true
end

--- The profile's dispel palette (profile-wide since schema v2; bars colored by dispel type read it,
--- icons keep Blizzard's own dispel colors), or nil before the database exists.
function Style.ProfileDispelColors()
    local p = NS.db and NS.db.profile
    return p and p.dispelColors
end

--- A color map for AddDispelTypeTexture's `customDispelColorMap`, from a stored { Magic = {r,g,b,a} }.
--- Built once per set of color leaves and shared by every button that shows it.
function Style.DispelColorMap(stored)
    if type(stored) ~= "table" or not _G.CreateColor then return {} end
    local entry = dispelMaps[stored]
    if entry and dispelMapCurrent(entry, stored) then return entry.map end
    local map, src = {}, {}
    for _, name in ipairs(C.DISPEL_TYPES) do
        local c = stored[name]
        src[name] = c
        if type(c) == "table" then map[name] = _G.CreateColor(c.r or 1, c.g or 1, c.b or 1) end
    end
    dispelMaps[stored] = { map = map, src = src }
    return map
end

--- The size one element occupies, from the container's style settings — what the engine's flow layout
--- is told (elementWidth / elementHeight), and what the drag handle and the preview are sized to.
--- @return number width, number height
function Style.ElementSize(cfg)
    if cfg.style == "icons" then
        local ic = cfg.icons or {}
        return tonumber(ic.width) or D.icons.width, tonumber(ic.height) or D.icons.height
    end
    local b = cfg.bars or {}
    return tonumber(b.width) or D.bars.width, tonumber(b.height) or D.bars.height
end

--- Hide `am`'s regions and remember which were shown, so a return to that style draws them as they
--- were (the pandemic wash, say, stays hidden). Never the host itself: the harness's textures ARE the
--- frame, and a region that was the host would hide the whole element.
local function stashRegions(frame, am)
    local was = {}
    for _, v in pairs(am) do
        if v ~= frame and type(v) == "table" and v.Hide then
            was[v] = v:IsShown() and true or false
            v:Hide()
        end
    end
    frame.__amShown = frame.__amShown or {}
    frame.__amShown[am] = was
end

--- Put back the visibility stashRegions recorded for `am`.
local function restoreRegions(frame, am)
    local was = frame.__amShown and frame.__amShown[am]
    if not was then return end
    for region, shown in pairs(was) do region:SetShown(shown) end
    frame.__amShown[am] = nil
end

--- The regions `frame` carries for `style` ("bars" | "icons"), building them when absent or built
--- for the other style (C-4: a button restyled from bars to icons must not be dressed with a bar's
--- regions, which have no cooldown). The other style's regions are hidden, never destroyed: frames
--- are never freed in WoW, so a switch back finds and re-shows them. Identity is `__amByStyle`, the
--- per-frame map of the tables built so far; `am.style` is the tag each build sets.
function Style.RegionsFor(frame, style, build)
    local byStyle = frame.__amByStyle
    if not byStyle then
        byStyle = {}
        frame.__amByStyle = byStyle
    end
    local am = frame.__am
    if am and (byStyle[style] == am or am.style == style) then
        byStyle[style] = am
        return am
    end
    if am then stashRegions(frame, am) end
    am = byStyle[style]
    if am then
        frame.__am = am
        restoreRegions(frame, am)
        return am
    end
    am = build(frame)
    byStyle[style] = am
    return am
end

-- The dress in progress, handed to runDress through upvalues: Lua 5.1's xpcall passes no arguments
-- to the function it calls, and a closure per dress would allocate on every button.
local dressStyler, dressFrame, dressCfg, dressEngine

local function runDress()
    return dressStyler.Apply(dressFrame, dressCfg, dressEngine)
end

--- A dress's error handler. It runs where the styler raised, while the stack still holds the failing
--- line, and that stack travels with the message, because the re-raise in Style.Element starts a new
--- one and an error handler (BugSack) would otherwise see a stack that ends there. The headless
--- harness has no debugstack; the message then goes on as it came, and so does an error that is not
--- a string (a table or other value), which the caller must receive unchanged.
local function withStack(err)
    if type(debugstack) ~= "function" or type(err) ~= "string" then return err end
    return tostring(err) .. "\n" .. debugstack(2)
end
--- The same handler for any other guarded call whose error goes on to an error handler: the apply
--- pass (modules/ContainerManager.lua's applyDirty) reports a failing container through it.
Style.WithStack = withStack

--- Dress one element for `cfg` (a container's stored table). `engine` true binds the regions to the
--- engine's aura data; false leaves them for the preview to fill. `classColor` is the container's
--- class snapshot (nil for a player container), used by every class-colored region of this dress.
--- The snapshot is cleared on every exit: a styler that raises (Container:Restyle catches it) must not
--- leave it set for the next Style.Color outside a dress, so the error is re-raised only after, with
--- the styler's own stack attached (withStack).
function Style.Element(frame, cfg, engine, classColor)
    local t0 = Perf.on and debugprofilestop()
    local styler = (cfg.style == "icons") and Style.Icons or Style.Bars
    if styler then
        dressClass, dressStyler, dressFrame, dressCfg, dressEngine = classColor, styler, frame, cfg, engine
        local ok, err = xpcall(runDress, withStack)
        dressClass, dressStyler, dressFrame, dressCfg, dressEngine = nil, nil, nil, nil, nil
        if not ok then error(err, 0) end
    end
    if t0 then Perf.Note("styleElement", debugprofilestop() - t0) end
end

--- Whether right-click cancels this element's aura. Only the player's own buffs and weapon enchants
--- can be canceled — a debuff or a target's buff cannot, and registering the click there would only
--- swallow it — and a click-through container takes no clicks at all.
local function cancelEnabled(cfg, b)
    if b.clickThrough or not Style.OrTemplate(b.cancelOnRightClick, D.behavior.cancelOnRightClick) then
        return false
    end
    return cfg.unit == "player" and (cfg.auraType == "HELPFUL" or cfg.auraType == "ENCHANT")
end

--- Whether `cfg`'s elements hold the mouse's hover: yes unless the container is click-through or
--- shows no tooltips. An element that holds it is the mouse focus, so the world unit under it is not
--- moused over and its GameTooltip does not show beside the aura's own (L-3). The aura tooltip is the
--- engine's separate AuraButtonTooltip, so strata cannot stop that bleed; only the hover can. One rule
--- for the live buttons (Style.ApplyBehavior) and the placeholders (Preview.Show).
function Style.TakesHover(cfg)
    local b = cfg.behavior or {}
    return not b.clickThrough and b.tooltips ~= false
end

--- The container-wide mouse blocker's behavior. A container's BUTTONS hold the hover
--- (ApplyBehavior), but the gaps between them and the container's own padding hold nothing, so the
--- world unit behind is moused over there and draws its GameTooltip beside the aura's separate
--- AuraButtonTooltip (the owner's 2026-09-14 report). One frame under the buttons, covering the
--- container, closes those gaps. Gated on the SAME rule the live buttons and the preview
--- placeholders use (TakesHover), so a click-through or tooltips-off container is unaffected — and
--- it never takes clicks itself: a click-through container's gaps must still pass a click through to
--- whatever is behind it (modules/Container.lua's ApplyBlocker).
function Style.ApplyBlockerBehavior(frame, cfg)
    frame:SetMouseMotionEnabled(Style.TakesHover(cfg))
    frame:SetMouseClickEnabled(false)
end

--- The mouse behavior shared by both styles: tooltips, click-through and right-click cancel.
function Style.ApplyBehavior(frame, cfg)
    local b = cfg.behavior or {}
    local cancel = cancelEnabled(cfg, b)
    if frame.SetMouseMotionEnabled then frame:SetMouseMotionEnabled(Style.TakesHover(cfg)) end
    if frame.SetMouseClickEnabled then frame:SetMouseClickEnabled(cancel) end
    -- One click phase only — never both. A button reassigned to a different aura between the press
    -- and the release would cancel the wrong one.
    Style.Bind(frame, "SetCancelAuraButtons", cancel and "RightButtonUp" or nil)
    Style.Bind(frame, "SetTooltipAnchorPoint", b.tooltipAnchor or D.behavior.tooltipAnchor, 0, 0)
    Style.Bind(frame, "SetHideTooltipInCombat", b.tooltipInCombat == false)
end

--- Bind the duration text with the configured formatter and expiring color, both shared across every
--- button of the same look (formatterFor, curveFor). `sdef` is the template's style block (`bars` or
--- `icons`) that `s` was copied from, which the threshold falls back to.
function Style.BindDurationText(frame, fs, s, sdef)
    local opts = { textFormatter = formatterFor(s.timeFormat) }
    if s.expiringColorOn then
        opts.textColor = curveFor(tonumber(s.expiringThreshold) or sdef.expiringThreshold, s.expiringColor or NO_COLOR,
            (s.time and s.time.fontColor) or NO_COLOR)
    end
    Style.Bind(frame, "SetDurationText", fs, opts)
end

--- A placeholder's time text, written as a live button's reads (B-5): the remaining seconds through
--- the formatter the engine is handed for the same format (formatterFor). A placeholder's seconds
--- are a plain number, so the formatter's own Format answers here (research notes Q7). A client
--- without the formatter, or one that refuses, writes whole seconds; a timeless aura writes nothing.
--- Below the running-out threshold the text takes the running-out color, as the engine's step curve
--- (curveFor) paints a live one; above it, the font color the dress just set stands. `sdef` is the
--- template's style block, which the threshold and the color fall back to.
function Style.PreviewTime(fs, aura, s, sdef)
    if aura.duration <= 0 then
        fs:SetText("")
        return
    end
    local f = formatterFor(s.timeFormat)
    local ok, text = false, nil
    if f and f.Format then ok, text = pcall(f.Format, f, aura.remaining) end
    fs:SetText((ok and type(text) == "string") and text or ("%ds"):format(aura.remaining))
    if s.expiringColorOn and aura.remaining < (tonumber(s.expiringThreshold) or sdef.expiringThreshold) then
        fs:SetTextColor(Style.Color(s.expiringColor or sdef.expiringColor, false))
    end
end
