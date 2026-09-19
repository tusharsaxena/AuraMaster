local _, NS = ...

-- modules/Style_Text.lua — dressing one aura as a LINE OF TEXT (issue #2).
--
--     clip ─ anim ─┬─ [icon]      the element, clipped: a bounce never draws over a neighbor
--                  └─ area ─ chain ─ [Power Word: Fortitude][ x3][ - 12s]
--                                     one font string per template piece
--
-- A LINE IS A CHAIN. No addon code can read a secret aura value, so none can build the line as one
-- string: the engine writes each field into a font string of ours, one per template piece
-- (modules/TextTemplate.lua), and plain text between fields is a static font string. Every piece is
-- single-anchored and auto-sized, so the client sizes an engine-written piece to its secret text and
-- the next piece anchors to its edge (the 2026-09-18 probes, docs/midnight-quirks.md). Their widths
-- are never readable, which is why a multi-piece line cannot be centered as one line: Center STACKS
-- it instead, one centered row per field (feedback #1, layoutStack).
--
-- THREE NESTED FRAMES. `clip` covers the element and clips its children; `anim` fills it and carries
-- the looping animations, so the icon and the text move and fade together; `area` is the text's box
-- (the element less the icon and its gap), clipped again, so a long line is cut at its box and never
-- runs under the icon. No Scale animation: glyphs scaled past the boxes they are anchored by overlap.
--
-- ONE CHAIN PER SHAPE. A chain frame holds the font strings of one piece-kind sequence
-- ("name|stacks|duration", TT's `shape`). A template edit that keeps the shape re-dresses the same
-- strings, each still bound to its own engine field; a new shape hides the current chain (with it
-- every string the engine may still write into) and builds or re-shows the one for the new shape.
-- Live buttons also get a fresh engine when the shape changes (modules/Container.lua's structure key,
-- Style.StructureKey), so no stale binding outlives it; the chains are what a PREVIEW frame, reused
-- across templates, relies on.
--
-- COLOR BY DISPEL TYPE (feedback #7). No engine binding colors a font string by the aura's dispel type,
-- and no addon code may read the type or touch a button's objects in combat. Three opt-in stand-ins,
-- each wired at dress time: the $dispeltype$ word colored by a |c escape written into the engine's own
-- text map (dispelOptionsFor), and a backdrop and a four-strip edge in the text area, textures the
-- engine tints and shows per aura (AddDispelTypeTexture, dispelTints).
--
-- ANIMATIONS ARE SET UP AT DRESS TIME ONLY. In combat every call on a button's objects is refused
-- (AnimationGroup:Play/Stop included), but an animation started at dress time keeps running through
-- combat. All three loops are built once with the regions; a dress configures them, stops them all
-- and plays the chosen one, AFTER the engine bindings, so a refused call on a button built in combat
-- cannot leave its fields unbound. A change made in combat waits for the deferred restyle
-- (ContainerManager.MustDefer), like every other setting.
--
-- LOAD-BEARING POSITION: after modules/Style.lua, whose NS.Style this decorates at file scope, and
-- after modules/TextTemplate.lua, taken below as a file-scope upvalue.

local Style = NS.Style
local C = NS.Constants
local D = NS.CONTAINER_TEMPLATE.text
local TT = NS.TextTemplate
local L = NS.L

Style.Text = Style.Text or {}
local Text = Style.Text

-- The refresh a blinking run needs (Compat.CreateDurationBinding): four updates per blink step.
local BLINK_INTERVAL = 0.1

--- "piece1", "piece2", ...: the keys a chain's font strings sit under on `frame.__am`, built once
--- each, so a dress indexes them without building a string.
local PIECE = setmetatable({}, { __index = function(t, i)
    local key = "piece" .. i
    t[i] = key
    return key
end })

local function number(v, default)
    return tonumber(v) or default
end

-- The dispel edge's four strips (feedback #7): each region key, the two corners of the text area it
-- runs between, and the setter its thickness goes through.
local EDGES = {
    { "edgeTop", "TOPLEFT", "TOPRIGHT", "SetHeight" },
    { "edgeBottom", "BOTTOMLEFT", "BOTTOMRIGHT", "SetHeight" },
    { "edgeLeft", "TOPLEFT", "BOTTOMLEFT", "SetWidth" },
    { "edgeRight", "TOPRIGHT", "BOTTOMRIGHT", "SetWidth" },
}

--- The line's font size, which is a stacked row's height (and, per-row, the icon's "line height").
local function fontSize(s)
    return number((s.font or D.font).fontSize, D.font.fontSize)
end

-- ---------------------------------------------------------------------------
-- Regions
-- ---------------------------------------------------------------------------

--- The three loops, built once on `anim`: a pulse (alpha down and back), a blink (alpha off, a hold,
--- on) and a bounce (up and back). A dress sets their timing and plays at most one (applyLoops).
local function buildLoops(am)
    am.pulseGroup = am.anim:CreateAnimationGroup()
    am.pulseGroup:SetLooping("BOUNCE")
    am.pulse = am.pulseGroup:CreateAnimation("Alpha")
    am.pulse:SetFromAlpha(1)
    am.pulse:SetSmoothing("IN_OUT")

    am.blinkGroup = am.anim:CreateAnimationGroup()
    am.blinkGroup:SetLooping("REPEAT")
    am.blink = am.blinkGroup:CreateAnimation("Alpha")
    am.blink:SetFromAlpha(1)
    am.blink:SetDuration(0.01)

    am.bounceGroup = am.anim:CreateAnimationGroup()
    am.bounceGroup:SetLooping("BOUNCE")
    am.bounce = am.bounceGroup:CreateAnimation("Translation")
    am.bounce:SetSmoothing("IN_OUT")
end

--- The dispel backdrop and edge (feedback #7): textures of the text area, so they sit under the chain
--- (a child frame) and move with the loops. Each is its own key on `am`: a region never hides in a
--- list the style suites cannot see.
local function buildDispelTints(am)
    am.backdrop = am.area:CreateTexture(nil, "BACKGROUND")
    am.backdrop:SetAllPoints(am.area)
    for _, e in ipairs(EDGES) do
        local strip = am.area:CreateTexture(nil, "BORDER")
        strip:SetPoint(e[2], am.area, e[2])
        strip:SetPoint(e[3], am.area, e[3])
        am[e[1]] = strip
    end
end

--- Build the regions once (Style.RegionsFor). Every region is a descendant of the button, tagged
--- "text"; the font strings are built per shape (useChain).
local function build(frame)
    local am = {}
    frame.__am = am
    am.style = "text"
    frame.__amChains = frame.__amChains or {}

    am.clip = CreateFrame("Frame", nil, frame)
    am.clip:SetAllPoints(frame)
    am.clip:SetClipsChildren(true)
    am.anim = CreateFrame("Frame", nil, am.clip)
    am.anim:SetAllPoints(am.clip)

    am.icon = am.anim:CreateTexture(nil, "ARTWORK")
    am.iconBorder = CreateFrame("Frame", nil, am.anim, "BackdropTemplate")
    am.area = CreateFrame("Frame", nil, am.anim)
    am.area:SetClipsChildren(true)
    buildDispelTints(am)

    buildLoops(am)
    am.pieceCount = 0
    return am
end

--- Put the current chain away: hidden, with its font strings, under its shape.
local function stashChain(frame, am)
    if not am.chain then return end
    local saved = { chain = am.chain, count = am.pieceCount }
    for i = 1, am.pieceCount do
        saved[i] = am[PIECE[i]]
        am[PIECE[i]] = nil
    end
    am.chain:Hide()
    frame.__amChains[am.shape] = saved
end

--- A new chain frame in the text area with `count` single-line font strings.
local function newChain(am, count)
    local chain = CreateFrame("Frame", nil, am.area)
    chain:SetAllPoints(am.area)
    local saved = { chain = chain, count = count }
    for i = 1, count do
        local fs = chain:CreateFontString(nil, "OVERLAY")
        fs:SetWordWrap(false)
        saved[i] = fs
    end
    return saved
end

--- Make `compiled`'s shape the element's chain: unchanged when it already is, else the current chain
--- is put away and the one for the new shape is taken back, or built.
local function useChain(frame, am, compiled)
    if am.chain and am.shape == compiled.shape then return end
    stashChain(frame, am)
    local pieces = compiled.pieces
    local count = #pieces
    local saved = frame.__amChains[compiled.shape] or newChain(am, count)
    frame.__amChains[compiled.shape] = nil
    am.chain, am.pieceCount, am.shape = saved.chain, saved.count, compiled.shape
    for i = 1, saved.count do am[PIECE[i]] = saved[i] end
    am.chain:Show()
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

--- The icon and its border: hidden with no `size` (no icon), else the `size` box at `pos` of the
--- animated frame (Style.LayoutIcon). Every call here is an icon or border call, run guarded.
local function placeIcon(am, s, pos, size)
    am.icon:ClearAllPoints()
    if not size then
        am.icon:Hide()
        am.iconBorder:Hide()
        return
    end
    Style.LayoutIcon(am.anim, am, s, D, pos, size)
end

--- The icon at `pos` ("LEFT" | "RIGHT") of the animated frame, and the text area beside it; with no
--- icon the area is the whole element. An `iconSize` of 0 takes ONE ROW's height (fix round 1,
--- feedback #1): a stacked Center's box holds several rows, and "line height" is one of them, not the
--- whole stack. The text area is anchored FIRST, from plain arithmetic, and the icon block after it,
--- guarded as Style.Bind guards a binding (smoke batch 2, item 7): a client call the icon or its
--- border refuses costs the icon alone (hidden, and reported through Style.ReportError), never the
--- text, which was left unanchored between the icon's error and the re-anchoring that followed it.
local function layoutIconAndArea(am, s, compiled, h)
    local pos = s.icon or D.icon
    local size
    am.area:ClearAllPoints()
    if pos == "LEFT" or pos == "RIGHT" then
        local lineHeight = Text.Stacked(s, compiled) and fontSize(s) or h
        size = Style.IconSizeFor(s, D, lineHeight)
        local inset = size + number(s.iconGap, D.iconGap)
        am.area:SetPoint("TOPLEFT", am.anim, "TOPLEFT", pos == "LEFT" and inset or 0, 0)
        am.area:SetPoint("BOTTOMRIGHT", am.anim, "BOTTOMRIGHT", pos == "RIGHT" and -inset or 0, 0)
    else
        am.area:SetAllPoints(am.anim)
    end
    local ok, err = pcall(placeIcon, am, s, pos, size)
    if ok then return end
    Style.ReportError("text icon", err)
    pcall(am.icon.Hide, am.icon)
    pcall(am.iconBorder.Hide, am.iconBorder)
end

-- The anchor-point prefix for each vertical justify: TOPLEFT / LEFT / BOTTOMLEFT and the right-hand
-- equivalents.
local V_PREFIX = { TOP = "TOP", MIDDLE = "", BOTTOM = "BOTTOM" }

--- Whether a line is laid out as STACKED ROWS (feedback #1, 2026-09-19): Center on a template of more
--- than one piece. A chain's width is never readable and no addon code runs when the engine rewrites a
--- piece in combat, so a multi-piece line cannot be centered as one line; each field piece gets a row of
--- its own instead, centered in the box, and plain literal pieces are not drawn (between two rows they
--- have nothing to sit between). A one-piece template is not stacked: the client centers it as a line.
function Text.Stacked(s, compiled)
    return (s.justifyH or D.justifyH) == "CENTER" and not compiled.single
end

--- How many field pieces (every kind but literal) a compiled template has: a stacked line's rows.
function Text.FieldCount(compiled)
    local n = 0
    for _, piece in ipairs(compiled.pieces) do
        if piece.kind ~= "literal" then n = n + 1 end
    end
    return n
end

--- The height a stacked line's rows take: one font size per field row and C.TEXT_ROW_GAP between two;
--- 0 for a line that is not stacked. Rows are FIXED: an engine-written string that is empty (and
--- secret) can be neither measured nor collapsed, so a row holds its place whatever its field says.
--- modules/Style.lua's ElementSize grows the element to this height.
function Text.StackHeight(s)
    local compiled = Text.Compiled(s)
    if not Text.Stacked(s, compiled) then return 0 end
    local n = Text.FieldCount(compiled)
    return n * fontSize(s) + (n - 1) * C.TEXT_ROW_GAP
end

-- How far below the text area's top a stack starts, for each vertical justify, in a box `h` tall
-- holding rows `stack` tall (never negative: the box grows to the stack).
local STACK_TOP = {
    TOP = function() return 0 end,
    MIDDLE = function(h, stack) return (h - stack) / 2 end,
    BOTTOM = function(h, stack) return h - stack end,
}

--- Lay a stacked line out in a box `h` tall: each field piece's TOP at the area's TOP, centered, a row
--- pitch lower than the one before (x/y nudge the whole stack); every literal piece hidden.
local function layoutStack(am, s, compiled, h)
    local pitch = fontSize(s) + C.TEXT_ROW_GAP
    local top = (STACK_TOP[s.justifyV or D.justifyV] or STACK_TOP.MIDDLE)(h, Text.StackHeight(s))
    local x, y = number(s.x, D.x), number(s.y, D.y)
    local row = 0
    for i, piece in ipairs(compiled.pieces) do
        local fs = am[PIECE[i]]
        fs:ClearAllPoints()
        if piece.kind == "literal" then
            fs:Hide()
        else
            fs:SetPoint("TOP", am.area, "TOP", x, y - top - row * pitch)
            row = row + 1
        end
    end
end

--- The anchor point `side` ("LEFT" | "CENTER" | "RIGHT") names at vertical prefix `v`.
local function pointAt(v, side)
    if side == "CENTER" then return v ~= "" and v or "CENTER" end
    return v .. side
end

--- Anchor the chain in the text area: the head piece at the justified edge, nudged by x/y, and each
--- next piece against the previous one's far edge (LEFT to the previous RIGHT, or the mirror for a
--- Right-justified line, laid from the last piece back). A stacked line is laid out by layoutStack.
local function layoutChain(am, s, compiled, h)
    if Text.Stacked(s, compiled) then return layoutStack(am, s, compiled, h) end
    local side = s.justifyH or D.justifyH
    local v = V_PREFIX[s.justifyV or D.justifyV] or ""
    local x, y = number(s.x, D.x), number(s.y, D.y)
    local n = am.pieceCount
    local first, last, step, near, far = 1, n, 1, "LEFT", "RIGHT"
    if side == "RIGHT" then first, last, step, near, far = n, 1, -1, "RIGHT", "LEFT" end
    local head = am[PIECE[first]]
    head:ClearAllPoints()
    head:SetPoint(pointAt(v, side), am.area, pointAt(v, side), x, y)
    for i = first + step, last, step do
        local fs = am[PIECE[i]]
        fs:ClearAllPoints()
        fs:SetPoint(pointAt(v, near), am[PIECE[i - step]], pointAt(v, far), 0, 0)
    end
end

--- Every piece in the line's font; a literal also takes its text now, since nothing else writes it.
local function dressPieces(am, s, compiled)
    local font = s.font or D.font
    for i, piece in ipairs(compiled.pieces) do
        local fs = am[PIECE[i]]
        Style.ApplyFont(fs, font, D.font)
        if piece.kind == "literal" then fs:SetText(piece.text) end
        fs:Show()
    end
end

--- The dispel backdrop and edge (feedback #7): white, the backdrop at its opacity, each strip its
--- thickness, and every one HIDDEN. A live one is shown and tinted by the engine for an aura with a
--- dispel type (Text.Bind); a placeholder's by Text.FillPreview. Hidden on every dress, because the
--- engine's Clear restores nothing: a switched-off tint would stay as the engine last drew it.
local function dressDispelTints(am, s)
    am.backdrop:SetTexture(C.WHITE_TEXTURE)
    am.backdrop:SetAlpha(number(s.dispelBackdropAlpha, D.dispelBackdropAlpha))
    am.backdrop:Hide()
    local size = number(s.dispelEdgeSize, D.dispelEdgeSize)
    for _, e in ipairs(EDGES) do
        local strip = am[e[1]]
        strip:SetTexture(C.WHITE_TEXTURE)
        strip[e[4]](strip, size)
        strip:Hide()
    end
end

-- The loops, each the group a dress plays for its `anim` value.
local LOOPS = { { "pulse", "pulseGroup" }, { "blink", "blinkGroup" }, { "bounce", "bounceGroup" } }

--- Time the three loops from the settings, stop them all, and play the chosen one. Only Play and Stop
--- go through Style.Bind (a refusal costs the call and is logged); the timing setters are called raw,
--- so a refusal there raises, which is why Text.Apply runs this after the engine bindings.
local function applyLoops(am, s)
    local half = number(s.animSpeed, D.animSpeed) / 2
    local low = number(s.animIntensity, D.animIntensity)
    am.pulse:SetToAlpha(low)
    am.pulse:SetDuration(half)
    am.blink:SetToAlpha(low)
    am.blink:SetStartDelay(half)
    am.blink:SetEndDelay(half)
    am.bounce:SetOffset(0, number(s.animBounce, D.animBounce))
    am.bounce:SetDuration(half)
    local want = s.anim or D.anim
    for _, loop in ipairs(LOOPS) do
        local group = am[loop[2]]
        Style.Bind(group, "Stop")
        if loop[1] == want then Style.Bind(group, "Play") end
    end
end

-- ---------------------------------------------------------------------------
-- The engine
-- ---------------------------------------------------------------------------

local stackOptions, dispelOptions = {}, {}

--- SetApplicationCount's options for a stacks piece: a rule formatter that writes nothing below two
--- stacks and the piece's format from two up. Built once per format string.
local function stackOptionsFor(piece)
    local opts = stackOptions[piece.format]
    if not opts then
        opts = { formatter = NS.Compat.CreateRuleFormatter({
            { threshold = 0, format = "" }, { threshold = 2, format = piece.format } }) }
        stackOptions[piece.format] = opts
    end
    return opts
end

--- One color channel as two hex digits.
local function hex(v)
    return ("%02x"):format(math.floor(math.max(0, math.min(1, tonumber(v) or 1)) * 255 + 0.5))
end

--- The palette `s` colors the dispel type word from: the profile's, when Color the dispel type is on
--- (feedback #7), else nil.
local function wordPalette(s)
    return s and s.dispelTypeColor and Style.ProfileDispelColors() or nil
end

--- Dispel type `t`'s word inside a piece's bracket text, in `palette`'s color for `t` when it has one:
--- a |cffRRGGBB escape the font string renders, closed before the bracket text, which keeps the font
--- color. A type the palette lacks (Enrage) keeps the font color.
local function dispelWord(piece, t, palette)
    local word = L[C.TEXT_DISPEL_LABELS[t]]
    local c = palette and palette[t]
    if type(c) == "table" then word = "|cff" .. hex(c.r) .. hex(c.g) .. hex(c.b) .. word .. "|r" end
    return piece.pre .. word .. piece.post
end

--- Whether a memoized dispel entry was built from exactly the palette leaves `palette` holds now (a
--- settings write stores a new leaf table, modules/Style.lua's memo note).
local function paletteCurrent(entry, palette)
    for _, t in ipairs(C.TEXT_DISPEL_TYPES) do
        if (palette and palette[t] or nil) ~= entry.src[t] then return false end
    end
    return true
end

--- SetDispelTypeText's options for a dispel piece: every type in C.TEXT_DISPEL_TYPES mapped to its
--- localized name inside the piece's bracket text (colored when `s` asks, dispelWord), on harmful and
--- helpful auras alike, nothing for an aura with no type. The map's values are the engine's own text
--- (`stringView`, written by fontString:SetText), so the escape is the one path that colors text by
--- dispel type in combat. Built once per bracket text, coloring and palette.
local function dispelOptionsFor(piece, s)
    local palette = wordPalette(s)
    local key = (palette and "c" or "p") .. piece.pre .. "\0" .. piece.post
    local entry = dispelOptions[key]
    if not (entry and paletteCurrent(entry, palette)) then
        local map, src = {}, {}
        for _, t in ipairs(C.TEXT_DISPEL_TYPES) do
            map[t] = dispelWord(piece, t, palette)
            src[t] = palette and palette[t] or nil
        end
        entry = { src = src, opts = { showWhenHarmful = true, showWhenHelpful = true,
            showWithoutDispelType = false, customDispelTextMap = map } }
        dispelOptions[key] = entry
    end
    return entry.opts
end

-- A single fully transparent color, shared by every dispel type the profile's palette does not cover
-- (Enrage): the engine still calls Show for it (it has a dispelName, and showWithoutDispelType is
-- false only for a TYPELESS aura), so nothing but a transparent tint keeps it invisible (fix round 1,
-- controller ruling: an out-of-palette type gets no visible tint, the same as a typeless aura).
local invisible

--- The backdrop and edge's color map (feedback #7, fix round 1): every type in C.TEXT_DISPEL_TYPES the
--- profile's palette colors takes that color at full alpha (the backdrop's own opacity is
--- `dispelBackdropAlpha`'s SetAlpha, not this alpha); a type it does not cover (Enrage) takes
--- `invisible`. Unlike Style.DispelColorMap (Bars, Task 11), no entry here falls back to a surface
--- color: a Text tint has no surface color of its own to fall back to, so "no color" IS the fallback. No `None` entry: showWithoutDispelType is false, so the engine never looks
--- a typeless aura up. Built once per set of palette leaves, and read by the live dress
--- (tintOptionsFor) and the preview (previewTints) alike, so the two cannot disagree.
local tintMapEntry
local function tintColorMap()
    local palette = Style.ProfileDispelColors()
    if not (tintMapEntry and paletteCurrent(tintMapEntry, palette)) then
        invisible = invisible or (_G.CreateColor and _G.CreateColor(1, 1, 1, 0))
        local map, src = {}, {}
        for _, t in ipairs(C.TEXT_DISPEL_TYPES) do
            local c = palette and palette[t]
            src[t] = palette and palette[t] or nil
            map[t] = (type(c) == "table" and _G.CreateColor) and _G.CreateColor(c.r or 1, c.g or 1, c.b or 1, 1) or invisible
        end
        tintMapEntry = { src = src, map = map }
    end
    return tintMapEntry.map
end

--- AddDispelTypeTexture's options for the backdrop and edge (feedback #7): shown for a buff or a debuff
--- WITH a dispel type (as the word is), our white texture kept (PreserveAsset) and tinted from
--- tintColorMap. Built once per map.
local tintOptions
local function tintOptionsFor()
    local map = tintColorMap()
    if not (tintOptions and tintOptions.customDispelColorMap == map) then
        tintOptions = { showWhenHarmful = true, showWhenHelpful = true, showWithoutDispelType = false,
            style = NS.Compat.DispelStyle("PreserveAsset"), customDispelColorMap = map }
    end
    return tintOptions
end

--- Hand the backdrop and each edge strip that `s` turns on to the engine to tint (Style.Bind). The
--- additive list was cleared at the head of the dress (Style.ClearAdditiveBindings).
local function dispelTints(frame, am, s)
    if not (s.dispelBackdrop or s.dispelEdge) then return end
    local opts = tintOptionsFor()
    if s.dispelBackdrop then Style.Bind(frame, "AddDispelTypeTexture", am.backdrop, opts) end
    if not s.dispelEdge then return end
    for _, e in ipairs(EDGES) do Style.Bind(frame, "AddDispelTypeTexture", am[e[1]], opts) end
end

--- The button's prebuilt duration binding, plain or with the blink's refresh, built on first use and
--- kept on the element (a binding is the button's own, never shared).
local function bindingFor(am, blink)
    local key = blink and "blinkBinding" or "binding"
    if am[key] == nil then am[key] = NS.Compat.CreateDurationBinding(blink and BLINK_INTERVAL or nil) end
    return am[key]
end

-- How each kind of piece is handed to the engine. A literal is bound to nothing.
local BINDERS = {
    name = function(frame, fs) Style.Bind(frame, "SetSpellName", fs) end,
    stacks = function(frame, fs, piece) Style.Bind(frame, "SetApplicationCount", fs, stackOptionsFor(piece)) end,
    dispel = function(frame, fs, piece, s) Style.Bind(frame, "SetDispelTypeText", fs, dispelOptionsFor(piece, s)) end,
    duration = function(frame, fs, piece, s, am)
        local font = s.font or D.font
        Style.BindDurationFormat(frame, fs, Style.DurationTextFormat(piece, s.timeFormat),
            bindingFor(am, s.expiringBlink and true or false), s, D,
            Style.CurveColor(font.fontColor, font.useClassColorFont))
    end,
}

--- Hand the pieces and the icon to the engine, each through its own binding (Style.Bind).
function Text.Bind(frame, am, cfg, s, compiled)
    if (s.icon or D.icon) ~= "NONE" then Style.Bind(frame, "SetIcon", am.icon) end
    for i, piece in ipairs(compiled.pieces) do
        local bind = BINDERS[piece.kind]
        if bind then bind(frame, am[PIECE[i]], piece, s, am) end
    end
    dispelTints(frame, am, s)
    Style.ApplyBehavior(frame, cfg)
end

-- ---------------------------------------------------------------------------
-- The dress
-- ---------------------------------------------------------------------------

local warned = {}

--- The compiled template this element draws: the stored one, or the default when the stored one is
--- refused, which is said once per template in the debug log and never raised.
function Text.Compiled(s)
    local compiled, fellBack = TT.ForDraw(s.template)
    if fellBack and not warned[tostring(s.template)] then
        warned[tostring(s.template)] = true
        if NS.Debug then NS.Debug("Style", "text template refused, drawing the default: %s", s.template) end
    end
    return compiled
end

function Text.Apply(frame, cfg, engine)
    local s = cfg.text or {}
    local w, h = Style.ElementSize(cfg)
    local am = Style.RegionsFor(frame, "text", build)
    if engine then Style.ClearAdditiveBindings(frame) end

    frame:SetSize(w, h)
    local compiled = Text.Compiled(s)
    useChain(frame, am, compiled)
    layoutIconAndArea(am, s, compiled, h)
    dressPieces(am, s, compiled)
    layoutChain(am, s, compiled, h)
    dressDispelTints(am, s)
    if engine then Text.Bind(frame, am, cfg, s, compiled) end
    applyLoops(am, s)
end

-- ---------------------------------------------------------------------------
-- The preview
-- ---------------------------------------------------------------------------

-- The placeholder being filled, handed to componentText through upvalues (gsub passes it only the
-- match).
local fillAura, fillSettings, fillPiece, fillIndex

--- One duration component of a placeholder, as the engine would write it: a time through the look's
--- formatter (Style.PreviewSeconds), a percent as a bare whole number, rounded to the nearest as the
--- engine's `step = 1` rule rounds it (modules/Style.lua's PERCENT_BREAKPOINTS).
local VALUES = {
    RemainingDuration = function(a) return a.remaining end,
    TotalDuration = function(a) return a.duration end,
    ElapsedDuration = function(a) return a.duration - a.remaining end,
    RemainingPercent = function(a) return math.floor(a.remaining / a.duration * 100 + 0.5) end,
    ElapsedPercent = function(a) return math.floor((a.duration - a.remaining) / a.duration * 100 + 0.5) end,
}
local function componentText()
    fillIndex = fillIndex + 1
    local c = fillPiece.components[fillIndex]
    local value = VALUES[c.prop](fillAura)
    if c.fmt == "percent" then return ("%d"):format(value) end
    return Style.PreviewSeconds(value, fillSettings.timeFormat)
end

--- A placeholder's duration run as text: the format with each {} filled, nothing for a timeless aura
--- (the prebuilt binding's zero-duration text).
local function durationText(piece, aura, s)
    if aura.duration <= 0 then return "" end
    fillAura, fillSettings, fillPiece, fillIndex = aura, s, piece, 0
    local text = piece.format:gsub("{}", componentText)
    fillAura, fillSettings, fillPiece = nil, nil, nil
    return text
end

-- What each kind of piece reads for a placeholder aura, as the engine would write it. Shared by the
-- placeholders (Text.FillPreview) and the Text page's Preview box (Text.PreviewLine).
local PIECE_TEXT = {
    literal = function(piece) return piece.text end,
    name = function(_, aura) return aura.name end,
    stacks = function(piece, aura) return aura.stacks >= 2 and piece.format:format(aura.stacks) or "" end,
    dispel = function(piece, aura, s)
        if not (aura.dispel and C.TEXT_DISPEL_LABELS[aura.dispel]) then return "" end
        return dispelWord(piece, aura.dispel, wordPalette(s))
    end,
    duration = durationText,
}

--- A placeholder's duration run below the running-out threshold takes the running-out color, as the
--- engine's curve paints a live one (a timeless one has no threshold to cross).
local function previewRunColor(fs, aura, s)
    if aura.duration <= 0 or not (s.expiringColorOn or s.expiringBlink) then return end
    if aura.remaining < number(s.expiringThreshold, D.expiringThreshold) then
        fs:SetTextColor(Style.Color(s.expiringColorOn and s.expiringColor or (s.font or D.font).fontColor, false))
    end
end

--- A placeholder's backdrop and edge (feedback #7): shown in tintColorMap's color for its aura's
--- dispel type -- the SAME map the live engine is handed (fix round 1), so the preview and a live
--- button cannot disagree -- left hidden (dressDispelTints) for an aura with no type, and for a type
--- the palette does not cover (Enrage: invisible, not shown, controller ruling).
local function previewTints(am, aura, s)
    local c = aura.dispel and tintColorMap()[aura.dispel]
    if not (c and c ~= invisible) then return end
    local r, g, b = c.r or 1, c.g or 1, c.b or 1
    if s.dispelBackdrop then
        am.backdrop:SetVertexColor(r, g, b, 1)
        am.backdrop:Show()
    end
    if not s.dispelEdge then return end
    for _, e in ipairs(EDGES) do
        am[e[1]]:SetVertexColor(r, g, b, 1)
        am[e[1]]:Show()
    end
end

--- Fill a PREVIEW element with placeholder values (modules/Preview.lua), from the same compiled
--- pieces the live dress binds, so the preview and a live button cannot differ in structure. A
--- literal already holds its text (dressPieces).
function Text.FillPreview(frame, aura, cfg)
    local am = frame.__am
    if not (am and am.style == "text") then return end
    local s = (cfg and cfg.text) or {}
    local compiled = Text.Compiled(s)
    am.icon:SetTexture(aura.icon)
    for i, piece in ipairs(compiled.pieces) do
        if piece.kind ~= "literal" then
            local fs = am[PIECE[i]]
            fs:SetText(PIECE_TEXT[piece.kind](piece, aura, s))
            if piece.kind == "duration" then previewRunColor(fs, aura, s) end
        end
    end
    previewTints(am, aura, s)
end

--- The line text block `s` draws for a sample `aura`, as one plain string: the Text page's Preview
--- box (feedback #5). The same compile and the same fill as the placeholders, so the two cannot
--- disagree.
--- A stacked line (feedback #1) previews as its field rows, one per line, its literals left out.
function Text.PreviewLine(s, aura)
    s = s or {}
    local compiled = Text.Compiled(s)
    local stacked = Text.Stacked(s, compiled)
    local parts = {}
    for _, piece in ipairs(compiled.pieces) do
        if not (stacked and piece.kind == "literal") then
            local n = #parts
            parts[n + 1] = PIECE_TEXT[piece.kind](piece, aura, s)
        end
    end
    return table.concat(parts, stacked and "\n" or "")
end
