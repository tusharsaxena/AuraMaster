local _, NS = ...

-- settings/Bars.lua — how a container drawn as BARS looks (modules/Style_Bars.lua draws it).
--
--     band   [Container ▾]
--     [ General ][ Icon ][ Background & border ][ Name text ][ Time text ][ Stack text ][ Highlights ]
--
-- A container drawn as icons sees every row here disabled, under a note naming where its style is
-- changed (B-2; settings/OptionsSetup.lua's drawDisabledNotice, which draws it small and gray).
--
-- The font, border, bar and background blocks are COMPOSED (options-ui-§16) — contiguous, in canonical order,
-- with anything extra appended after the block — and every color row has its class-color companion
-- (options-ui-§17), declared `source = "unit"`: the class is that of the unit the container tracks,
-- snapshotted once per apply (modules/Container.lua's SnapshotClass, modules/Style.lua's
-- Style.Color), so a player container reads the player's. The expiring and pandemic swatches are PALETTE
-- definitions — one color per state — and carry no companion, the one exemption §17 makes. The
-- dispel type colors are the profile's, on General → Dispel Colors (settings/GeneralSpells.lua).

local L = NS.L
local H = NS.Helpers
local C = NS.Constants

local PAGE = "bars"
local P = "container.bars."
local UNIT = { source = "unit" }

local G_GENERAL, G_ICON, G_BG = L["General"], L["Icon"], L["Background & border"]
local G_NAME, G_TIME, G_STACK, G_HI = L["Name text"], L["Time text"], L["Stack text"], L["Highlights"]

local POINTS = NS.Choices(C.POINTS, C.POINT_LABELS)
local JUSTIFY = NS.Choices(C.JUSTIFY, C.JUSTIFY_LABELS)

-- ── General ───────────────────────────────────────────────────────────────────────────────────
-- S-1: a whole tab for two sliders did not earn its place, so Size is this tab's first subsection
-- rather than a tab of its own; the old Bar tab (Fill, Spark) follows it, and the tab itself is
-- renamed General to cover both.

NS.RegisterSchemaRows({
    { path = P .. "width", page = PAGE, group = G_GENERAL, subgroup = L["Size"], type = "number", min = 40, max = 600, step = 1,
      label = L["Width (px)"], desc = L["The width of one bar, icon included."] },
    { path = P .. "height", page = PAGE, group = G_GENERAL, subgroup = L["Size"], type = "number", min = 6, max = 80, step = 1,
      label = L["Height (px)"], desc = L["The height of one bar."] },
})

NS.RegisterSchemaRows(H.BarGroup({
    prefix = P, page = PAGE, group = G_GENERAL, subgroup = L["Fill"], classColor = UNIT,
    extra = {
        { path = P .. "colorMode", type = "string", values = NS.Choices(C.BAR_COLOR_MODES, C.BAR_COLOR_MODE_LABELS),
          label = L["Color by"], desc = L["One color, or each debuff's dispel type (colors on General -> Dispel Colors)."] },
        { path = P .. "drain", type = "string", values = NS.Choices(C.DRAIN_DIRECTIONS, C.DRAIN_DIRECTION_LABELS),
          label = L["Drains toward"], desc = L["Which end the bar empties toward as the aura runs out. A permanent aura draws a full bar."] },
        -- engine-only: it eases the engine's timer between its updates; a placeholder's fill is drawn
        -- once, at a fixed fraction, and never moves (tests/test_render_coverage.lua).
        { path = P .. "smooth", type = "bool", label = L["Smooth animation"], coverage = "engine-only",
          desc = L["Ease the bar between updates instead of stepping."] },
    },
}))

NS.RegisterSchemaRows({
    { path = P .. "spark", page = PAGE, group = G_GENERAL, subgroup = L["Spark"], type = "bool",
      label = L["Show spark"], desc = L["A bright line at the bar's moving edge."] },
    { path = P .. "sparkWidth", page = PAGE, group = G_GENERAL, subgroup = L["Spark"], type = "number", min = 1, max = 32, step = 1,
      label = L["Spark width (px)"], desc = L["How wide the spark is."] },
})
NS.RegisterSchemaRows(H.ColorPair({
    prefix = P, page = PAGE, group = G_GENERAL, subgroup = L["Spark"], key = "sparkColor",
    companionKey = "useClassColorSpark", label = L["Spark color"], classColor = UNIT,
}))
-- Off: a live bar's spark rides a clip frame bounded by the elapsed region, which a timeless aura
-- leaves empty (modules/Style_Bars.lua's wireSpark).
NS.RegisterSchemaRows({
    { path = P .. "sparkTimeless", page = PAGE, group = G_GENERAL, subgroup = L["Spark"], type = "bool", startsLine = true,
      label = L["Show the spark on auras without a duration"],
      desc = L["A permanent aura's bar is full and never moves. Turn this off to hide its spark; a timed bar's spark then sits just inside its moving edge."] },
})

-- ── Icon ──────────────────────────────────────────────────────────────────────────────────────

NS.RegisterSchemaRows({
    { path = P .. "icon", page = PAGE, group = G_ICON, subgroup = L["Icon"], type = "string",
      values = NS.Choices(C.ICON_POSITIONS, C.ICON_POSITION_LABELS), label = L["Icon position"],
      desc = L["Where the aura's icon sits, or hide it."] },
    { path = P .. "iconSize", page = PAGE, group = G_ICON, subgroup = L["Icon"], type = "number", min = 0, max = 80, step = 1,
      label = L["Icon size (0 = bar height)"], desc = L["A square icon this many pixels wide."] },
    { path = P .. "iconGap", page = PAGE, group = G_ICON, subgroup = L["Icon"], type = "number", min = 0, max = 20, step = 1,
      label = L["Icon gap (px)"], desc = L["Space between the icon and the bar."] },
    { path = P .. "iconZoom", page = PAGE, group = G_ICON, subgroup = L["Icon"], type = "number", min = 0, max = 0.3, step = 0.01,
      label = L["Icon zoom"], desc = L["Crop the icon's border art."] },
})
-- The composed border block (options-ui-§16) on the icon's own leaves; modules/Style_Bars.lua draws
-- it around the icon's box and insets the art inside it.
local iconBorder = H.BorderGroup({
    prefix = P, page = PAGE, group = G_ICON, subgroup = L["Icon border"], show = true, classColor = UNIT,
    keys = { borderShow = "iconBorderShow", borderStyle = "iconBorderStyle", borderSize = "iconBorderSize",
             borderColor = "iconBorderColor", useClassColorBorder = "useClassColorIconBorder" },
})
for _, row in ipairs(iconBorder) do
    if row.path == P .. "iconBorderShow" then row.tooltip = L["Draw a border around the icon; its art sits inside it."] end
end
NS.RegisterSchemaRows(iconBorder)

-- ── Background & border ───────────────────────────────────────────────────────────────────────

-- The background is a bar group, not options-ui-§16's "group over a background": that clause is for
-- a surface with no texture, and this one has a live texture (modules/Style_Bars.lua paints it). The
-- composer's own tooltips describe a fill, so each row's is replaced, found by path.
local bg = H.BarGroup({
    prefix = P, page = PAGE, group = G_BG, subgroup = L["Background"], classColor = UNIT,
    keys = { barTexture = "bgTexture", barAlpha = "bgAlpha", barColor = "bgColor", useClassColorBar = "useClassColorBg" },
    labels = { barTexture = L["Background texture"], barAlpha = L["Background opacity"], barColor = L["Background color"] },
})
local BG_TOOLTIPS = {
    [P .. "bgTexture"] = L["The texture drawn behind the fill."],
    [P .. "bgAlpha"] = L["How opaque the background texture is."],
    [P .. "bgColor"] = L["The background color."] .. (H.CLASS_COLOR_NOTE and (" " .. H.CLASS_COLOR_NOTE) or ""),
    [P .. "useClassColorBg"] = L["Draw the background in the class color instead of the swatch beside it."],
}
for _, row in ipairs(bg) do row.tooltip = BG_TOOLTIPS[row.path] end
NS.RegisterSchemaRows(bg)
NS.RegisterSchemaRows(H.BorderGroup({
    prefix = P, page = PAGE, group = G_BG, subgroup = L["Border"], show = true, classColor = UNIT,
}))

-- ── Text ──────────────────────────────────────────────────────────────────────────────────────

--- One text element's tab: the composed font block, then where the text sits.
local function textRows(leaf, group, extras)
    local prefix = P .. leaf .. "."
    NS.RegisterSchemaRows(H.FontGroup({
        prefix = prefix, page = PAGE, group = group, subgroup = L["Font"], classColor = UNIT,
    }))
    local rows = {
        { path = prefix .. "show", page = PAGE, group = group, subgroup = L["Placement"], type = "bool",
          label = L["Show"], desc = L["Draw this text."] },
        { path = prefix .. "justify", page = PAGE, group = group, subgroup = L["Placement"], type = "string",
          values = JUSTIFY, label = L["Justify"], desc = L["How the text lines up within its space."] },
        { path = prefix .. "point", page = PAGE, group = group, subgroup = L["Placement"], type = "string",
          values = POINTS, label = L["Anchor"], desc = L["Where on the bar the text is anchored."] },
        { path = prefix .. "x", page = PAGE, group = group, subgroup = L["Placement"], type = "number",
          min = -100, max = 100, step = 1, startsLine = true, label = L["X offset"], desc = L["Horizontal nudge, in pixels."] },
        { path = prefix .. "y", page = PAGE, group = group, subgroup = L["Placement"], type = "number",
          min = -100, max = 100, step = 1, label = L["Y offset"], desc = L["Vertical nudge, in pixels."] },
    }
    for _, r in ipairs(extras or {}) do
        r.page, r.group = PAGE, group
        rows[#rows + 1] = r
    end
    NS.RegisterSchemaRows(rows)
end

textRows("name", G_NAME)
textRows("time", G_TIME, {
    { path = P .. "timeFormat", subgroup = L["Countdown"], type = "string",
      values = NS.Choices(C.TIME_FORMATS, C.TIME_FORMAT_LABELS), label = L["Time format"],
      desc = L["How the remaining time is written."] },
})
textRows("stacks", G_STACK)

-- ── Highlights ────────────────────────────────────────────────────────────────────────────────

local HI = {
    { path = P .. "expiringColorOn", page = PAGE, group = G_HI, subgroup = L["Running out"], type = "bool",
      label = L["Recolor the time when running out"], desc = L["Turn the time text another color in the last seconds."] },
    { path = P .. "expiringThreshold", page = PAGE, group = G_HI, subgroup = L["Running out"], type = "number",
      min = 1, max = 60, step = 1, label = L["Running out below (sec)"], desc = L["When the time text changes color."] },
    -- Palette definition (options-ui-§17 exemption): identifies a state, not a player.
    { path = P .. "expiringColor", page = PAGE, group = G_HI, subgroup = L["Running out"], type = "color",
      startsLine = true, label = L["Running-out color"], desc = L["The time text's color in the last seconds."] },
    -- engine-only: the refresh window is the engine's to find (CustomAuraButton's pandemic window, a
    -- per-spell rule Lua cannot read); a placeholder is a made-up aura with none (the color below
    -- still reaches the wash on both).
    { path = P .. "pandemic", page = PAGE, group = G_HI, subgroup = L["Refresh window"], type = "bool",
      startsLine = true, label = L["Highlight the refresh window"], coverage = "engine-only",
      desc = L["Wash the bar while the aura can be refreshed without losing any of its duration."] },
    { path = P .. "pandemicColor", page = PAGE, group = G_HI, subgroup = L["Refresh window"], type = "color",
      label = L["Refresh-window color"], desc = L["The highlight's color."] },
}
NS.RegisterSchemaRows(HI)

NS.RegisterContainerPage(PAGE, L["Bars"], "AuraMasterBarsPanel", {
    disabledFor = function(cfg) return cfg.style ~= "bars" end,
    disabledNotice = L["Not in use: this container is drawn as icons. Set its Style to Bars on the Containers page to use these settings."],
})
