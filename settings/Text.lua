local _, NS = ...

-- settings/Text.lua — how a container drawn as TEXT looks (modules/Style_Text.lua draws it; the
-- template language is modules/TextTemplate.lua's).
--
--     band   [Container ▾]
--     [ General ][ Font ][ Icon ][ Animation ]
--
-- General is drawn bespoke (its `tabs` entry below) only to put two read-only blocks between its
-- rows: the token cheat sheet under the Template box, and the centering note under Placement. Its
-- rows are still ordinary schema rows, drawn by the flow engine, so the panel, `/am set`, the
-- Defaults button and the resets all reach them through the one write seam.
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
local S_PLACEMENT = L["Placement"]
local SMALL = { fontObject = "GameFontHighlightSmall" }
local GRAY = "|cff808080%s|r"

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

-- ── General ───────────────────────────────────────────────────────────────────────────────────

NS.RegisterSchemaRows({
    { path = P .. "width", page = PAGE, group = G_GENERAL, subgroup = L["Size"], type = "number", min = 40, max = 600, step = 1,
      label = L["Width (px)"], desc = L["The width of one line, icon included. Text past the edge is cut off."] },
    { path = P .. "height", page = PAGE, group = G_GENERAL, subgroup = L["Size"], type = "number", min = 8, max = 80, step = 1,
      label = L["Height (px)"], desc = L["The height of one line."] },
    { path = P .. "template", page = PAGE, group = G_GENERAL, subgroup = L["What each line says"], type = "string",
      dialogControl = "EditBox", maxLetters = C.TEXT_TEMPLATE_MAX, wide = true, label = L["Template"],
      desc = L["What each line says, built from the tokens listed below. Press Enter to apply."],
      validate = TT.Validate },
    { path = P .. "justifyH", page = PAGE, group = G_GENERAL, subgroup = S_PLACEMENT, type = "string",
      values = NS.Choices(C.TEXT_JUSTIFY_H, C.JUSTIFY_LABELS), label = L["Justify"],
      desc = L["How the line sits in its box. Center needs a template that is one piece (one token and no text around it); any other lines up Left."] },
    { path = P .. "justifyV", page = PAGE, group = G_GENERAL, subgroup = S_PLACEMENT, type = "string",
      values = NS.Choices(C.TEXT_JUSTIFY_V, C.TEXT_JUSTIFY_V_LABELS), label = L["Vertical justify"],
      desc = L["Whether the line sits at the top, middle or bottom of its box."] },
    { path = P .. "x", page = PAGE, group = G_GENERAL, subgroup = S_PLACEMENT, type = "number",
      min = -100, max = 100, step = 1, startsLine = true, label = L["X offset"], desc = L["Horizontal nudge, in pixels."] },
    { path = P .. "y", page = PAGE, group = G_GENERAL, subgroup = S_PLACEMENT, type = "number",
      min = -100, max = 100, step = 1, label = L["Y offset"], desc = L["Vertical nudge, in pixels."] },
})

--- The token cheat sheet, under the Template box: one line per token, then the bracket rule and the
--- escapes. Read-only text, drawn small.
local function cheatSheet(ctx)
    for _, def in ipairs(C.TEXT_TOKENS) do
        H.TextRow(ctx, ("|cffffd100$%s$|r  %s"):format(def.key, L[C.TEXT_TOKEN_LABELS[def.key]]), SMALL)
    end
    H.TextRow(ctx, L["[ ] hides its text along with the token inside it: $spellname$[ x$stacks$] shows ' x3' only at 2 or more stacks."], SMALL)
    H.TextRow(ctx, L["To write a literal [, ] or $, type it twice: [[, ]] or $$."], SMALL)
end

--- Under Placement: why Center is not honored, when it is chosen and the template has more than one
--- piece (modules/Style_Text.lua lines it up Left).
local function centerNote(ctx, cfg)
    local s = cfg.text or {}
    if (s.justifyH or D.justifyH) ~= "CENTER" then return end
    local compiled = TT.ForDraw(s.template)
    if compiled.single then return end
    local count = #compiled.pieces
    H.TextRow(ctx, GRAY:format(L["Center needs a one-piece template; this one has %d pieces, so it lines up Left."]:format(count)), SMALL)
end

--- The General tab: its rows, with the cheat sheet after the Template box and the centering note
--- after Placement.
local function renderGeneral(ctx, cfg, rows)
    local head, tail = {}, {}
    for _, row in ipairs(rows or {}) do
        local list = (row.subgroup == S_PLACEMENT) and tail or head
        local n = #list
        list[n + 1] = row
    end
    H.RenderRows(ctx, head, nil, nil, { noHeadings = true })
    cheatSheet(ctx)
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
