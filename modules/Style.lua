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

--- The key of the style `cfg` is drawn in: "icons", "text", or "bars" for anything else (a style a
--- later version removed draws as bars, the template's own style).
function Style.StyleKey(cfg)
    local style = cfg.style
    if style == "icons" or style == "text" then return style end
    return "bars"
end

--- The container's active style block: cfg.icons, cfg.text or cfg.bars.
local function styleBlock(cfg)
    return cfg[Style.StyleKey(cfg)]
end

--- Whether the container's active style block (or one of its text blocks) turns a class color on.
--- Allocation-free: it runs on every unit swap for each container tracking the swapped unit.
function Style.UsesClassColor(cfg)
    local s = styleBlock(cfg)
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

--- Apply the six canonical font leaves of `t` (options-ui-§16) to a FontString: face, size, flags,
--- color (with its class-color companion) and shadow. `tdef` is the template's block for the same
--- text, which the size falls back to.
function Style.ApplyFont(fs, t, tdef)
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
end

--- Apply one text block (the six canonical font leaves plus point / x / y / justify / show) to a
--- FontString parented under `anchorTo`. `tdef` is the template's block for the same element, which
--- the size, point and justify fall back to. `boxWidth` is the width the text may take (its host's):
--- a single-anchor font string sized to its own string has nothing to justify within, so a text given
--- a box is as wide as the box less its offset. A second anchor, set after this, overrides the width.
function Style.ApplyText(fs, t, anchorTo, tdef, boxWidth)
    if not (fs and t) then return end
    Style.ApplyFont(fs, t, tdef)
    fs:ClearAllPoints()
    local point = t.point or tdef.point
    local x = tonumber(t.x) or 0
    fs:SetPoint(point, anchorTo, point, x, tonumber(t.y) or 0)
    fs:SetWidth(textWidth(boxWidth, x))
    fs:SetJustifyH(t.justify or tdef.justify)
    fs:SetWordWrap(false)
end

-- ---------------------------------------------------------------------------
-- The icon beside a bar or a line of text
-- ---------------------------------------------------------------------------
-- Shared by modules/Style_Bars.lua and modules/Style_Text.lua. `s` is the stored style block and
-- `sdef` the template's block it was copied from (D.bars, D.text); both carry the same icon leaves:
-- iconSize, iconZoom and the composed icon-border block.

--- The icon's side: its stored size, or the template's when that is missing; zero means `h`, the
--- element's height.
function Style.IconSizeFor(s, sdef, h)
    local size = tonumber(s.iconSize) or sdef.iconSize
    return size > 0 and size or h
end

--- The icon border's thickness when it draws, else 0: how far the art is inset inside the icon's box.
function Style.IconInset(s, sdef)
    if not Style.OrTemplate(s.iconBorderShow, sdef.iconBorderShow) then return 0 end
    if Style.OrTemplate(s.iconBorderStyle, sdef.iconBorderStyle) == "None" then return 0 end
    return tonumber(s.iconBorderSize) or sdef.iconBorderSize
end

--- Place the icon's `size` box at `side` ("LEFT" | "RIGHT") of `host`: the icon border (am.iconBorder)
--- takes the whole box and the art (am.icon) sits inside it, inset by the border's thickness, as
--- modules/Style_Icons.lua's layoutIcon does, so a thick border never hides the art.
function Style.LayoutIcon(host, am, s, sdef, side, size)
    local inset = Style.IconInset(s, sdef)
    am.iconBorder:ClearAllPoints()
    am.iconBorder:SetSize(size, size)
    am.iconBorder:SetPoint(side, host, side, 0, 0)
    Style.ApplyBorder(am.iconBorder, inset > 0, Style.OrTemplate(s.iconBorderStyle, sdef.iconBorderStyle), inset,
        s.iconBorderColor or sdef.iconBorderColor, s.useClassColorIconBorder)

    local art = math.max(0, size - 2 * inset)
    am.icon:Show()
    am.icon:SetSize(art, art)
    am.icon:SetPoint(side, host, side, side == "RIGHT" and -inset or inset, 0)
    local z = tonumber(s.iconZoom) or sdef.iconZoom
    am.icon:SetTexCoord(z, 1 - z, z, 1 - z)
end

-- ---------------------------------------------------------------------------
-- Measuring a time text (B4)
-- ---------------------------------------------------------------------------
-- A bar's time text beside the name needs a box of its own, and the engine writes it secret, so its
-- width cannot be read back. It CAN be measured beforehand: the formatter the engine is handed writes
-- plain numbers too, so the widest strings a format produces are set on one hidden FontString of ours
-- (never secret) and measured. The ems budget (C.TIME_TEXT_EMS) guessed, and guessed short: 2.5 ems
-- of an 11pt font cut a Blizzard-format "59 m" to "59...".

-- The seconds sampled: the largest value before each unit or digit count changes.
local TIME_SAMPLES = { 59, 599, 3599, 35999, 86399, 863999 }
local measureFS             -- the hidden FontString, built on first use
local measuredWidths = {}   -- ["path|size|flags|format"] = width; a failed measure is never cached

--- The FontString time texts are measured on: one hidden, addon-owned string, built on first use. A
--- test replaces this function to measure on a recorder.
function Style.__measurer()
    if measureFS == nil then
        local host = CreateFrame("Frame", nil, UIParent)
        host:Hide()
        measureFS = host:CreateFontString(nil, "OVERLAY")
    end
    return measureFS
end

--- The widest of the sample strings `fmt` writes, in one font; nil when the string cannot be measured:
--- no measurer, a font the client refuses (the fallback font too, as Style.ApplyFont falls back), or
--- a width that is not a number. Called guarded (Style.TimeTextWidth), so a raise costs the measure.
local function widestSample(path, size, flags, fmt)
    local fs = Style.__measurer()
    if not fs then return nil end
    if not fs:SetFont(path, size, flags) and not fs:SetFont(C.FALLBACK_FONT, size, flags) then return nil end
    local most
    for _, seconds in ipairs(TIME_SAMPLES) do
        fs:SetText(Style.PreviewSeconds(seconds, fmt))
        local w = fs:GetStringWidth()
        if not NS.Secrets.IsReadableNumber(w) then return nil end
        if not most or w > most then most = w end
    end
    return most
end

--- The width, in pixels, a time text in font block `t` needs for the widest string format `fmt`
--- writes, plus 2 for the outline and shadow; nil when it cannot be measured (the caller keeps its
--- ems budget then). Cached per font path, size, flags and format. Only a width is cached: a measure
--- that raised, found no width or found none above 0 (a string the client has not laid out yet) is
--- not, so the ems budget stands for this dress and a later one measures again.
function Style.TimeTextWidth(t, tdef, fmt)
    local size = tonumber(t.fontSize) or tdef.fontSize
    local flags = FLAG_MAP[t.fontFlags or "NONE"] or (t.fontFlags or "")
    local path = Style.Fetch("font", t.font, C.FALLBACK_FONT)
    local key = ("%s|%s|%s|%s"):format(path, size, flags, tostring(fmt))
    local w = measuredWidths[key]
    if w then return w end
    local ok, most = pcall(widestSample, path, size, flags, fmt)
    if not (ok and most and most > 0) then return nil end
    w = most + 2
    measuredWidths[key] = w
    return w
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
local blinkCurves = setmetatable({}, WEAK_KEYS)
local dispelMaps = setmetatable({}, WEAK_KEYS)

-- Dispel types the engine can report that the palette has no color for (Enrage: C.TEXT_DISPEL_TYPES
-- names it as a real dispelName, but it is not a C.DISPEL_TYPES palette entry). buildDispelMap maps
-- each of these to the fallback too, exactly like None, so an aura of one of them keeps the surface's
-- own color rather than Blizzard's own tint.
local EXTRA_DISPEL_TYPES = {}
do
    local palette = {}
    for _, name in ipairs(C.DISPEL_TYPES) do palette[name] = true end
    for _, name in ipairs(C.TEXT_DISPEL_TYPES) do
        if not palette[name] then
            EXTRA_DISPEL_TYPES[#EXTRA_DISPEL_TYPES + 1] = name
        end
    end
end

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

--- The memo slot for one color pair under `root`: `root[expiring][normal]`, a table keyed by
--- threshold, each level built on demand. Weak on both colors, so a replaced color takes its entries.
local function curveSlot(root, expiring, normal)
    local byNormal = root[expiring]
    if not byNormal then
        byNormal = setmetatable({}, WEAK_KEYS)
        root[expiring] = byNormal
    end
    local byThreshold = byNormal[normal]
    if not byThreshold then
        byThreshold = {}
        byNormal[normal] = byThreshold
    end
    return byThreshold
end

--- The expiring-text color curve for one threshold and color pair: `curves[expiring][normal][threshold]`.
local function curveFor(threshold, expiring, normal)
    local slot = curveSlot(curves, expiring, normal)
    local tc = slot[threshold]
    if tc == nil then
        tc = NS.Compat.ExpiringTextColor(threshold, expiring, normal)
        slot[threshold] = tc
    end
    return tc
end

--- The blinking running-out curve for one threshold and color pair, memoized as curveFor is.
local function blinkCurveFor(threshold, blink, normal)
    local slot = curveSlot(blinkCurves, blink, normal)
    local tc = slot[threshold]
    if tc == nil then
        tc = NS.Compat.BlinkTextColor(threshold, blink, normal)
        slot[threshold] = tc
    end
    return tc
end

-- A curve's `normal` for a class-colored font: { r, g, b, a } with the class's channels and the
-- stored alpha, memoized per class source (the dress's snapshot, or PLAYER_CLASS for a player
-- container) and stored color, so every button of one container hands the curve memos the SAME
-- table and shares one curve. The snapshot is reused in place across unit swaps
-- (modules/Container.lua's ResolveUnitClass), so an entry is checked against the channels resolved
-- now and replaced, never edited, when they moved: a new table misses the curve memos.
local classNormals = setmetatable({}, WEAK_KEYS)
local PLAYER_CLASS = {}

--- The color a running-out curve returns to above its threshold, as a table stable across the
--- buttons of one look: `stored` itself when the class color is off or does not resolve, else the
--- class color with the stored alpha (Style.Color), memoized as above.
function Style.CurveColor(stored, useClass)
    stored = stored or NO_COLOR
    if not useClass then return stored end
    local r, g, b, a = Style.Color(stored, true)
    local sr, sg, sb = NS.ResolveColor(stored, false)
    if r == sr and g == sg and b == sb then return stored end
    local source = dressClass or PLAYER_CLASS
    local byStored = classNormals[source]
    if not byStored then
        byStored = setmetatable({}, WEAK_KEYS)
        classNormals[source] = byStored
    end
    local c = byStored[stored]
    if not (c and c.r == r and c.g == g and c.b == b and c.a == a) then
        c = { r = r, g = g, b = b, a = a }
        byStored[stored] = c
    end
    return c
end

--- Whether a memoized dispel map was built from exactly the color leaves `stored` holds now, and from
--- the fallback color's channels as they are now (a class-colored fallback is reused in place).
local function dispelMapCurrent(entry, stored, fallback)
    local src = entry.src
    for _, name in ipairs(C.DISPEL_TYPES) do
        if stored[name] ~= src[name] then return false end
    end
    return entry.r == fallback.r and entry.g == fallback.g and entry.b == fallback.b and entry.a == fallback.a
end

--- The profile's dispel palette (profile-wide since schema v2; bars colored by dispel type read it,
--- and so does a Text line's dispel type word, backdrop and edge (feedback #7) -- icons keep
--- Blizzard's own dispel colors), or nil before the database exists.
function Style.ProfileDispelColors()
    local p = NS.db and NS.db.profile
    return p and p.dispelColors
end

--- A new dispel map entry for DispelColorMap: the map, and what it was built from.
local function buildDispelMap(stored, fallback)
    local a = fallback.a or 1
    local map, src = {}, {}
    for _, name in ipairs(C.DISPEL_TYPES) do
        local c = stored[name]
        src[name] = c
        if type(c) == "table" then map[name] = _G.CreateColor(c.r or 1, c.g or 1, c.b or 1, a) end
    end
    local none = _G.CreateColor(fallback.r or 1, fallback.g or 1, fallback.b or 1, a)
    map.None = none
    for _, name in ipairs(EXTRA_DISPEL_TYPES) do map[name] = none end
    return { map = map, src = src, r = fallback.r, g = fallback.g, b = fallback.b, a = fallback.a }
end

--- A color map for AddDispelTypeTexture's `customDispelColorMap`, from a stored { Magic = {r,g,b,a} }
--- and the surface's own color `fallback` ({ r, g, b, a }, stable per look: Style.CurveColor). Each
--- dispel type takes its palette color; an aura with NO dispel type — the engine keys it "None"
--- (GetDispelTypeMapKey) — takes `fallback`, so it keeps the surface's normal color rather than
--- Blizzard's own "none" tint (feedback #7, owner decision: no type means the normal color). A type
--- the palette does not cover but the engine can still report (`EXTRA_DISPEL_TYPES`, e.g. `Enrage`)
--- takes `fallback` too, for the same reason. Every entry carries the fallback's alpha, so a
--- dispel-colored surface keeps its own transparency. Built once per set of color leaves and
--- fallback, and shared by every button that shows it.
function Style.DispelColorMap(stored, fallback)
    if type(stored) ~= "table" or not _G.CreateColor then return {} end
    fallback = fallback or NO_COLOR
    local byFallback = dispelMaps[stored]
    if not byFallback then
        byFallback = setmetatable({}, WEAK_KEYS)
        dispelMaps[stored] = byFallback
    end
    local entry = byFallback[fallback]
    if not (entry and dispelMapCurrent(entry, stored, fallback)) then
        entry = buildDispelMap(stored, fallback)
        byFallback[fallback] = entry
    end
    return entry.map
end

--- The size one element occupies, from the container's style settings — what the engine's flow layout
--- is told (elementWidth / elementHeight), and what the drag handle and the preview are sized to.
--- @return number width, number height
function Style.ElementSize(cfg)
    local key = Style.StyleKey(cfg)
    local s, sdef = cfg[key] or {}, D[key]
    local w, h = tonumber(s.width) or sdef.width, tonumber(s.height) or sdef.height
    -- A Text line stacked by Center grows to its rows (feedback #1, modules/Style_Text.lua).
    if key == "text" and Style.Text then h = math.max(h, Style.Text.StackHeight(s)) end
    return w, h
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

--- The regions `frame` carries for `style` ("bars" | "icons" | "text"), building them when absent or built
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

--- What a live engine is rebuilt for when it changes (modules/Container.lua's structure key): the
--- style, and for the text style the template's shape (modules/Style_Text.lua). A new shape then
--- gets new buttons, so no engine binding is left pointing into the old shape's font strings.
function Style.StructureKey(cfg)
    local key = Style.StyleKey(cfg)
    if key ~= "text" or not Style.Text then return key end
    return "text:" .. Style.Text.Compiled(cfg.text or {}).shape
end

--- The styler that dresses `cfg`'s elements: Style.Bars, Style.Icons or Style.Text (each decorates
--- NS.Style at file scope in its own file, so it is looked up here, at call time).
function Style.Styler(cfg)
    local key = Style.StyleKey(cfg)
    if key == "icons" then return Style.Icons end
    if key == "text" then return Style.Text end
    return Style.Bars
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
    local styler = Style.Styler(cfg)
    if styler then
        dressClass, dressStyler, dressFrame, dressCfg, dressEngine = classColor, styler, frame, cfg, engine
        local ok, err = xpcall(runDress, withStack)
        dressClass, dressStyler, dressFrame, dressCfg, dressEngine = nil, nil, nil, nil, nil
        if not ok then error(err, 0) end
    end
    if t0 then Perf.Note("styleElement", debugprofilestop() - t0) end
end

--- Whether right-click cancels this element's aura. Only the player's own buffs and weapon enchants
--- (a player buff container's enchant slots) can be canceled — a debuff or a target's buff cannot,
--- and registering the click there would only swallow it — and a click-through container takes no
--- clicks at all.
local function cancelEnabled(cfg, b)
    if b.clickThrough or not Style.OrTemplate(b.cancelOnRightClick, D.behavior.cancelOnRightClick) then
        return false
    end
    return cfg.unit == "player" and cfg.auraType == "HELPFUL"
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
--- button of the same look (formatterFor, curveFor). Above the threshold the curve returns to the
--- time's font color through its class-color companion (Style.CurveColor). `sdef` is the template's style block (`bars` or
--- `icons`) that `s` was copied from, which the threshold falls back to.
function Style.BindDurationText(frame, fs, s, sdef)
    local opts = { textFormatter = formatterFor(s.timeFormat) }
    if s.expiringColorOn then
        local t = s.time or NO_COLOR
        opts.textColor = curveFor(tonumber(s.expiringThreshold) or sdef.expiringThreshold, s.expiringColor or NO_COLOR,
            Style.CurveColor(t.fontColor, t.useClassColorFont))
    end
    Style.Bind(frame, "SetDurationText", fs, opts)
end

-- ---------------------------------------------------------------------------
-- A Text style's duration run (modules/Style_Text.lua)
-- ---------------------------------------------------------------------------

local textFormats = setmetatable({}, WEAK_KEYS)
-- A percent is written as a BARE whole number (feedback #5, 2026-09-19): the rule is "%d" and the
-- player types the % in the template, so no token adds text of its own. RemainingPercent arrives on a
-- fractional 0-100 scale; `step = 1` rounds it to a whole number before "%d" sees it (the 12.1
-- NumericRuleFormatBreakpoint's own field). A client that refuses `step` gets the plain rule.
local PERCENT_BREAKPOINTS = { { threshold = 0, step = 1, format = "%d" } }
local PERCENT_PLAIN = { { threshold = 0, format = "%d" } }
local percentFormatter   -- nil until first asked for; false when the client cannot build one

--- The rule formatter every percent component shares: a whole number, 0-100, with no "%".
local function percentFor()
    if percentFormatter == nil then
        local Compat = NS.Compat
        percentFormatter = Compat.CreateRuleFormatter(PERCENT_BREAKPOINTS)
            or Compat.CreateRuleFormatter(PERCENT_PLAIN) or false
    end
    return percentFormatter or nil
end

--- The `textFormat` option for one compiled duration piece (modules/TextTemplate.lua) in one time
--- format: the piece's format string, and one { property, formatter } component per {} in order, a
--- time through the look's seconds formatter (formatterFor) and a percent through "%d". Built once
--- per piece and time format; the parser memoizes its pieces, so a hit allocates nothing.
function Style.DurationTextFormat(piece, timeFormat)
    local byFormat = textFormats[piece]
    if not byFormat then
        byFormat = {}
        textFormats[piece] = byFormat
    end
    local key = timeFormat or false
    local tf = byFormat[key]
    if tf then return tf end
    local components = {}
    for i, c in ipairs(piece.components) do
        components[i] = { property = NS.Compat.DurationProperty(c.prop),
            formatter = (c.fmt == "percent") and percentFor() or formatterFor(timeFormat) }
    end
    tf = { formatString = piece.format, components = components }
    byFormat[key] = tf
    return tf
end

--- The `textColor` of a Text style's duration run: the blinking curve when `expiringBlink` is on (in
--- the running-out color when the recolor is on too, else in `normal`), the plain running-out curve
--- when only the recolor is on, else nil, and the font color stands.
local function runTextColor(s, sdef, normal)
    local threshold = tonumber(s.expiringThreshold) or sdef.expiringThreshold
    local expiring = s.expiringColor or NO_COLOR
    if s.expiringBlink then
        return blinkCurveFor(threshold, s.expiringColorOn and expiring or normal, normal)
    end
    if s.expiringColorOn then return curveFor(threshold, expiring, normal) end
    return nil
end

--- Bind a Text style's duration run: `textFormat` (Style.DurationTextFormat) through the prebuilt
--- `binding` (Compat.CreateDurationBinding, nil on a client without one), recolored by the
--- running-out curve or the blinking one (runTextColor). `normal` is the line's font color, which a
--- curve returns to above the threshold, resolved through Style.CurveColor so it is stable per look. `sdef` is the template's block the threshold falls back to.
function Style.BindDurationFormat(frame, fs, textFormat, binding, s, sdef, normal)
    Style.Bind(frame, "SetDurationText", fs, {
        textFormat = textFormat, binding = binding, textColor = runTextColor(s, sdef, normal or NO_COLOR),
    })
end

--- `seconds` written as a live button's time text reads (B-5), for a placeholder: through the
--- formatter the engine is handed for the same format (formatterFor). A placeholder's seconds are a
--- plain number, so the formatter's own Format answers here (research notes Q7); a client without
--- the formatter, or one that refuses, writes whole seconds.
function Style.PreviewSeconds(seconds, timeFormat)
    local f = formatterFor(timeFormat)
    local ok, text = false, nil
    if f and f.Format then ok, text = pcall(f.Format, f, seconds) end
    return (ok and type(text) == "string") and text or ("%ds"):format(seconds)
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
    fs:SetText(Style.PreviewSeconds(aura.remaining, s.timeFormat))
    if s.expiringColorOn and aura.remaining < (tonumber(s.expiringThreshold) or sdef.expiringThreshold) then
        fs:SetTextColor(Style.Color(s.expiringColor or sdef.expiringColor, false))
    end
end
