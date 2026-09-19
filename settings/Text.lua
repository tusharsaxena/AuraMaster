local _, NS = ...

-- settings/Text.lua — how a container drawn as TEXT looks (modules/Style_Text.lua draws it; the
-- template language is modules/TextTemplate.lua's).
--
--     band   [Container ▾]
--     [ General ][ Font ][ Icon ][ Animation ]
--     General   Size, then -- What each line says --: [Template ▾] (a built-in, or Custom), the
--               Custom template box (Custom only), Preview: <the line on a sample aura>, the cheat
--               sheet; then Placement and the centering note
--     Animation Loop, then Dispel type (feedback #7: the word's color, a backdrop, an edge, each
--               opt-in and off), then Running out and its note
--
-- General is drawn bespoke (its `tabs` entry below) to put the built-in picker, the preview and two
-- read-only blocks between its rows: the token cheat sheet, and the centering note under Placement.
-- Its rows are still ordinary schema rows, drawn by the flow engine, so the panel, `/am set`, the
-- Defaults button and the resets all reach them through the one write seam. The Template dropdown is
-- not a row: it writes the template (and, for the centered built-in, Justify) through that seam
-- (feedback #5).
--
-- The Template row's `validate` is the parser (TT.Validate): a refused template is never stored, and
-- the refusal's reason reaches the player through the write seam's third return (settings/Schema.lua)
-- -- printed under "Invalid value for container.text.template" by the panel and by `/am set` alike.
--
-- A container drawn as bars or icons sees every row here disabled, under a note naming where its
-- style is changed (settings/OptionsSetup.lua's drawDisabledNotice). The font and icon-border blocks
-- are composed (options-ui-§16) with class-color companions (§17) resolved to the tracked unit's
-- class, as on the Bars page; the running-out swatch is a palette color and carries none.

local L = NS.L
local H = NS.Helpers
local C = NS.Constants
local TT = NS.TextTemplate
local D = NS.CONTAINER_TEMPLATE.text

local PAGE = "text"
local P = "container.text."
local UNIT = { source = "unit" }

local G_GENERAL, G_FONT, G_ICON, G_ANIM = L["General"], L["Font"], L["Icon"], L["Animation"]
local S_PLACEMENT, S_DISPEL = L["Placement"], L["Dispel type"]
local SMALL = { fontObject = "GameFontHighlightSmall" }
local GRAY = "|cff808080%s|r"
local CUSTOM = "custom"

-- Which containers have Custom chosen in the Template dropdown this session, by id. Page state, not a
-- setting: a stored template matching no built-in reads as Custom on its own; this keeps the box open
-- for one that matches a built-in once the player asked to edit it.
local customOpen = {}

-- A write that changes what the General tab draws (the box, the preview, the centering note) redraws
-- it, on the next frame, out of the widget's own callback.
local function structural() if NS.RequestPanelRefresh then NS.RequestPanelRefresh() end end

--- The selected container's text block (empty with no container).
local function textBlock()
    local c = NS.ActiveContainer()
    return c and c.text or {}
end

--- A `disabledIf` predicate: the row is dimmed unless the selected container's loop effect is one
--- of `...`.
local function unlessAnim(...)
    local wanted = {}
    for _, v in ipairs({ ... }) do wanted[v] = true end
    return function() return not wanted[textBlock().anim or D.anim] end
end

--- A `disabledIf` predicate: the running-out rows need a duration token in the template (the blink
--- and the color ride the duration run's text).
local function noDuration()
    return not TT.ForDraw(textBlock().template).hasDuration
end

--- A `disabledIf` predicate: Color the dispel type needs a $dispeltype$ token to color (feedback #7).
local function noDispel()
    return not TT.ForDraw(textBlock().template).hasDispel
end

--- A `disabledIf` predicate: the row is dimmed while the selected container's toggle `key` is off.
local function unlessOn(key)
    return function() return not textBlock()[key] end
end

-- ── General ───────────────────────────────────────────────────────────────────────────────────

NS.RegisterSchemaRows({
    { path = P .. "width", page = PAGE, group = G_GENERAL, subgroup = L["Size"], type = "number", min = 40, max = 600, step = 1,
      label = L["Width (px)"], desc = L["The width of one line, icon included. Text past the edge is cut off."] },
    { path = P .. "height", page = PAGE, group = G_GENERAL, subgroup = L["Size"], type = "number", min = 8, max = 80, step = 1,
      label = L["Height (px)"], desc = L["The height of one line. Center stacks a line of several fields in rows, and the box grows to fit them."] },
    { path = P .. "template", page = PAGE, group = G_GENERAL, subgroup = L["What each line says"], type = "string",
      dialogControl = "EditBox", maxLetters = C.TEXT_TEMPLATE_MAX, wide = true, label = L["Custom template"],
      desc = L["What each line says, built from the tokens listed below. Press Enter to apply."],
      validate = TT.Validate, onChange = structural },
    { path = P .. "justifyH", page = PAGE, group = G_GENERAL, subgroup = S_PLACEMENT, type = "string",
      values = NS.Choices(C.TEXT_JUSTIFY_H, C.JUSTIFY_LABELS), label = L["Justify"],
      desc = L["How the line sits in its box. Center on a template of several fields stacks them, one centered row each; text outside [ ] is not drawn then, so put it inside the brackets of the field it belongs to."],
      onChange = structural },
    { path = P .. "justifyV", page = PAGE, group = G_GENERAL, subgroup = S_PLACEMENT, type = "string",
      values = NS.Choices(C.TEXT_JUSTIFY_V, C.TEXT_JUSTIFY_V_LABELS), label = L["Vertical justify"],
      desc = L["Whether the line sits at the top, middle or bottom of its box."] },
    { path = P .. "x", page = PAGE, group = G_GENERAL, subgroup = S_PLACEMENT, type = "number",
      min = -100, max = 100, step = 1, startsLine = true, label = L["X offset"], desc = L["Horizontal nudge, in pixels."] },
    { path = P .. "y", page = PAGE, group = G_GENERAL, subgroup = S_PLACEMENT, type = "number",
      min = -100, max = 100, step = 1, label = L["Y offset"], desc = L["Vertical nudge, in pixels."] },
})

--- The token cheat sheet, under the Template box: one line per token, then the bracket rule, the
--- escapes, how an odd run of [ combines the two, and why a duration belongs in brackets (feedback
--- #5: text outside them shows on a timeless aura too). Read-only text, drawn small.
local function cheatSheet(ctx)
    for _, def in ipairs(C.TEXT_TOKENS) do
        H.TextRow(ctx, ("|cffffd100$%s$|r  %s"):format(def.key, L[C.TEXT_TOKEN_LABELS[def.key]]), SMALL)
    end
    H.TextRow(ctx, L["[ ] hides its text along with the token inside it: $spellname$[ x$stacks$] shows ' x3' only at 2 or more stacks."], SMALL)
    H.TextRow(ctx, L["To write a literal [, ] or $, type it twice: [[, ]] or $$."], SMALL)
    H.TextRow(ctx, L["Escapes and brackets combine: [[[$stacks$]]] shows [3] only when stacked."], SMALL)
    H.TextRow(ctx, L["Text outside [ ] always shows, even on an aura with no duration: ($remainingpercent$%) leaves ( ) behind, [ ($remainingpercent$%)] hides with the time."], SMALL)
end

--- Under Placement: what Center does to a template of more than one piece (feedback #1): it stacks
--- the fields in rows and leaves plain text out (modules/Style_Text.lua's layoutStack). One row reads
--- singular (fix round 1): a literal-plus-one-field template (`Buff: $spellname$`) is Stacked but has
--- only one field row.
local function centerNote(ctx, cfg)
    local s = cfg.text or {}
    local compiled = TT.ForDraw(s.template)
    if not NS.Style.Text.Stacked(s, compiled) then return end
    local n = NS.Style.Text.FieldCount(compiled)
    local msg = n == 1 and L["Center stacks this template in 1 row; text outside [ ] is not drawn."]
        or L["Center stacks this template in %d rows, one per field; text outside [ ] is not drawn."]:format(n)
    H.TextRow(ctx, GRAY:format(msg), SMALL)
end

-- ── The built-in templates (feedback #5) ──────────────────────────────────────────────────────

--- Whether container `id`'s Template dropdown reads Custom: its template matches no built-in, or the
--- player chose Custom this session.
local function isCustom(cfg, id)
    local s = cfg.text or {}
    return customOpen[id] or TT.MatchBuiltin(cfg.auraType, s.template, s.justifyH or D.justifyH) == nil
end

--- Choose built-in `key` for container `id`: its template, then the justify it needs (Center for the
--- centered one; Left for any other when the stored justify is Center), each through the write seam.
local function pickBuiltin(cfg, id, key)
    local def = C.TEXT_BUILTINS[key]
    customOpen[id] = nil
    NS.SetByPath(P .. "template", def.template, id)
    local justify = (cfg.text and cfg.text.justifyH) or D.justifyH
    if def.justifyH and justify ~= def.justifyH then
        NS.SetByPath(P .. "justifyH", def.justifyH, id)
    elseif not def.justifyH and justify == "CENTER" then
        NS.SetByPath(P .. "justifyH", "LEFT", id)
    end
end

--- The Template dropdown: the container's built-ins, then Custom. A bespoke cell (not a schema row:
--- it has no stored value of its own), drawn disabled with the page.
local function templatePicker(cfg, id)
    return { make = function(ctx, parent, rel)
        local list, order = {}, {}
        for i, key in ipairs(TT.Builtins(cfg.auraType)) do
            list[key] = L[C.TEXT_BUILTIN_LABELS[key]]
            order[i] = key
        end
        local n = #order
        order[n + 1] = CUSTOM
        list[CUSTOM] = L["Custom"]
        local s = cfg.text or {}
        local dd = NS.AceGUI:Create("Dropdown")
        dd:SetLabel(L["Template"])
        dd:SetList(list, order)
        dd:SetValue(isCustom(cfg, id) and CUSTOM or TT.MatchBuiltin(cfg.auraType, s.template, s.justifyH or D.justifyH))
        dd:SetRelativeWidth(rel or 0.5)
        if ctx.__renderDisabled then dd:SetDisabled(true) end
        dd:SetCallback("OnValueChanged", function(_, _, key)
            if key == CUSTOM then customOpen[id] = true else pickBuiltin(cfg, id, key) end
            structural()
        end)
        H.AttachTooltip(dd, L["Template"], L["A ready-made line, or Custom to write your own from the tokens below. The Preview shows the result on a sample aura."])
        parent:AddChild(dd)
        return dd
    end }
end

--- A copy of `row` the flow engine draws nothing for but its subsection heading (RenderRows emits a
--- subgroup's heading before it looks at skipRender).
local function headingOnly(row)
    local copy = {}
    for k, v in pairs(row) do copy[k] = v end
    copy.skipRender = true
    return copy
end

--- What each line says: the subsection heading, the Template dropdown, the Custom template box (Custom
--- only), the Preview line on the aura type's sample aura, then the cheat sheet.
local function renderTemplate(ctx, cfg, row)
    local _, id = NS.ActiveContainer()
    if row then H.RenderRows(ctx, { headingOnly(row) }, nil, nil, { noHeadings = true }) end
    H.RenderGrid(ctx, { templatePicker(cfg, id) })
    if row and isCustom(cfg, id) then H.RenderRows(ctx, { row }, nil, nil, { noHeadings = true }) end
    local sample = C.TEXT_SAMPLE_AURAS[cfg.auraType] or C.TEXT_SAMPLE_AURAS.HELPFUL
    H.TextRow(ctx, L["Preview: %s"]:format(NS.Style.Text.PreviewLine(cfg.text, sample)))
    cheatSheet(ctx)
end

--- The General tab: Size, then what each line says (renderTemplate), then Placement and the
--- centering note.
local function renderGeneral(ctx, cfg, rows)
    local size, tail, templateRow = {}, {}, nil
    for _, row in ipairs(rows or {}) do
        if row.path == P .. "template" then
            templateRow = row
        else
            local list = (row.subgroup == S_PLACEMENT) and tail or size
            local n = #list
            list[n + 1] = row
        end
    end
    H.RenderRows(ctx, size, nil, nil, { noHeadings = true })
    renderTemplate(ctx, cfg, templateRow)
    H.RenderRows(ctx, tail, nil, nil, { noHeadings = true })
    centerNote(ctx, cfg)
end

-- ── Font ──────────────────────────────────────────────────────────────────────────────────────

NS.RegisterSchemaRows(H.FontGroup({
    prefix = P .. "font.", page = PAGE, group = G_FONT, subgroup = L["Font"], classColor = UNIT,
}))
NS.RegisterSchemaRows({
    { path = P .. "timeFormat", page = PAGE, group = G_FONT, subgroup = L["Countdown"], type = "string",
      values = NS.Choices(C.TIME_FORMATS, C.TIME_FORMAT_LABELS), label = L["Time format"],
      desc = L["How the duration tokens write a time."] },
})

-- ── Icon ──────────────────────────────────────────────────────────────────────────────────────

NS.RegisterSchemaRows({
    { path = P .. "icon", page = PAGE, group = G_ICON, subgroup = L["Icon"], type = "string",
      values = NS.Choices(C.TEXT_ICON_POSITIONS, C.TEXT_ICON_POSITION_LABELS), label = L["Icon position"],
      desc = L["Where the aura's icon sits beside the text, or hide it."] },
    { path = P .. "iconSize", page = PAGE, group = G_ICON, subgroup = L["Icon"], type = "number", min = 0, max = 80, step = 1,
      label = L["Icon size (0 = line height)"], desc = L["A square icon this many pixels wide."] },
    { path = P .. "iconGap", page = PAGE, group = G_ICON, subgroup = L["Icon"], type = "number", min = 0, max = 20, step = 1,
      label = L["Icon gap (px)"], desc = L["Space between the icon and the text."] },
    { path = P .. "iconZoom", page = PAGE, group = G_ICON, subgroup = L["Icon"], type = "number", min = 0, max = 0.3, step = 0.01,
      label = L["Icon zoom"], desc = L["Crop the icon's border art."] },
})
local iconBorder = H.BorderGroup({
    prefix = P, page = PAGE, group = G_ICON, subgroup = L["Icon border"], show = true, classColor = UNIT,
    keys = { borderShow = "iconBorderShow", borderStyle = "iconBorderStyle", borderSize = "iconBorderSize",
             borderColor = "iconBorderColor", useClassColorBorder = "useClassColorIconBorder" },
})
for _, row in ipairs(iconBorder) do
    if row.path == P .. "iconBorderShow" then row.tooltip = L["Draw a border around the icon; its art sits inside it."] end
end
NS.RegisterSchemaRows(iconBorder)

-- ── Animation ─────────────────────────────────────────────────────────────────────────────────

NS.RegisterSchemaRows({
    { path = P .. "anim", page = PAGE, group = G_ANIM, subgroup = L["Loop"], type = "string",
      values = NS.Choices(C.TEXT_ANIMS, C.TEXT_ANIM_LABELS), label = L["Effect"],
      desc = L["A looping effect on the whole line. Pulse fades it down and back, Blink switches it off and on, Bounce moves it up and down (give the box a few pixels of headroom). A change made in combat starts when combat ends."] },
    { path = P .. "animSpeed", page = PAGE, group = G_ANIM, subgroup = L["Loop"], type = "number",
      min = 0.2, max = 3, step = 0.1, disabledIf = unlessAnim("pulse", "blink", "bounce"),
      label = L["Seconds per cycle"], desc = L["How long one pulse, blink or bounce takes."] },
    { path = P .. "animIntensity", page = PAGE, group = G_ANIM, subgroup = L["Loop"], type = "number",
      min = 0, max = 0.9, step = 0.05, isPercent = true, disabledIf = unlessAnim("pulse", "blink"),
      label = L["Faded to"], desc = L["How visible the line stays at the low point of a pulse or blink."] },
    { path = P .. "animBounce", page = PAGE, group = G_ANIM, subgroup = L["Loop"], type = "number",
      min = 1, max = 10, step = 1, disabledIf = unlessAnim("bounce"),
      label = L["Bounce height (px)"], desc = L["How far the line moves up. The box clips it, so leave headroom."] },
    -- Color by dispel type (feedback #7): three opt-in stand-ins, all off, since no engine binding
    -- colors a whole line by the aura's type (modules/Style_Text.lua's header).
    { path = P .. "dispelTypeColor", page = PAGE, group = G_ANIM, subgroup = S_DISPEL, type = "bool",
      startsLine = true, disabledIf = noDispel,
      label = L["Color the dispel type"],
      desc = L["Write $dispeltype$ in its type's color from General -> Dispel Colors. The rest of the line keeps the font color. Needs $dispeltype$ in the template."] },
    { path = P .. "dispelBackdrop", page = PAGE, group = G_ANIM, subgroup = S_DISPEL, type = "bool",
      startsLine = true, label = L["Backdrop in the dispel color"],
      desc = L["Fill the line's box, behind the text, with the aura's dispel type color from General -> Dispel Colors. An aura with no dispel type gets none."] },
    { path = P .. "dispelBackdropAlpha", page = PAGE, group = G_ANIM, subgroup = S_DISPEL, type = "number",
      min = 0.05, max = 1, step = 0.05, isPercent = true, disabledIf = unlessOn("dispelBackdrop"),
      label = L["Backdrop opacity"], desc = L["How strongly the backdrop shows behind the text."] },
    { path = P .. "dispelEdge", page = PAGE, group = G_ANIM, subgroup = S_DISPEL, type = "bool",
      startsLine = true, label = L["Edge in the dispel color"],
      desc = L["Outline the line's box in the aura's dispel type color from General -> Dispel Colors. An aura with no dispel type gets none."] },
    { path = P .. "dispelEdgeSize", page = PAGE, group = G_ANIM, subgroup = S_DISPEL, type = "number",
      min = 1, max = 4, step = 1, disabledIf = unlessOn("dispelEdge"),
      label = L["Edge thickness (px)"], desc = L["How thick the edge is."] },
    { path = P .. "expiringColorOn", page = PAGE, group = G_ANIM, subgroup = L["Running out"], type = "bool",
      startsLine = true, disabledIf = noDuration,
      label = L["Recolor the time when running out"], desc = L["Turn the duration tokens another color in the last seconds. The rest of the line keeps the font color."] },
    { path = P .. "expiringThreshold", page = PAGE, group = G_ANIM, subgroup = L["Running out"], type = "number",
      min = 1, max = 60, step = 1, disabledIf = noDuration,
      label = L["Running out below (sec)"], desc = L["When the time text changes color."] },
    -- Palette definition (options-ui-§17 exemption): identifies a state, not a player.
    -- Never dimmed, even without a duration token: a swatch is read for its alpha (anti-pattern #74,
    -- tests/test_schema.lua).
    { path = P .. "expiringColor", page = PAGE, group = G_ANIM, subgroup = L["Running out"], type = "color",
      startsLine = true,
      label = L["Running-out color"], desc = L["The time text's color in the last seconds."] },
    -- engine-only: the blink is a curve the engine steps on its own clock; a placeholder's time is a
    -- fixed number, so the preview shows the running-out color and never the blink
    -- (tests/test_render_coverage.lua).
    { path = P .. "expiringBlink", page = PAGE, group = G_ANIM, subgroup = L["Running out"], type = "bool",
      disabledIf = noDuration, coverage = "engine-only",
      label = L["Blink when running out"],
      desc = L["Blink the duration tokens in the last seconds, in the running-out color when that is on. Only the duration tokens blink. The preview shows the color, not the blink."] },
})

--- After the Animation tab's rows: why Running out is dimmed, when the template has no duration.
local function animationNote(ctx)
    if not noDuration() then return end
    H.TextRow(ctx, GRAY:format(L["Running out needs a duration token, such as $remainingduration$, in the template."]), SMALL)
end

NS.RegisterContainerPage(PAGE, L["Text"], "AuraMasterTextPanel", {
    tabs = { { key = G_GENERAL, label = G_GENERAL, render = renderGeneral } },
    afterGroup = { [G_ANIM] = animationNote },
    disabledFor = function(cfg) return cfg.style ~= "text" end,
    disabledNotice = function(cfg)
        if cfg.style == "icons" then
            return L["Not in use: this container is drawn as icons. Set its Style to Text on the Containers page to use these settings."]
        end
        return L["Not in use: this container is drawn as bars. Set its Style to Text on the Containers page to use these settings."]
    end,
})
