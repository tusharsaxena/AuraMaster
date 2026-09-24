local _, NS = ...

-- settings/Bars.lua — how a container drawn as BARS looks (modules/Style_Bars.lua draws it).
--
--     band   [Container ▾]
--     [ General ][ Background & border ][ Name text ][ Time text ][ Stack text ][ Icon ][ Pandemic ]
--
-- A container drawn as icons sees every row here disabled, under a note naming where its style is
-- changed (B-2; settings/OptionsSetup.lua's mutedNotice, which the library draws small, in muted red).
--
-- The font, border, bar and background blocks are COMPOSED (options-ui-§16) — contiguous, in canonical order,
-- with anything extra appended after the block — and every color row has its class-color companion
-- (options-ui-§17), declared `source = "unit"`: the class is that of the unit the container tracks,
-- snapshotted once per apply (modules/Container.lua's SnapshotClass, modules/Style.lua's
-- Style.Color), so a player container reads the player's. The two pandemic-window swatches are PALETTE
-- definitions — one color per state — and carry no companion, the one exemption options-ui-§17 makes. The
-- dispel type colors are the profile's, on General → Dispel Colors (settings/GeneralSpells.lua).

local L = NS.L
local H = NS.Helpers
local C = NS.Constants

local PAGE = "bars"
local P = "container.bars."
local UNIT = { source = "unit" }

local G_GENERAL, G_ICON, G_BG = L["General"], L["Icon"], L["Background & border"]
local G_NAME, G_TIME, G_STACK, G_PANDEMIC = L["Name text"], L["Time text"], L["Stack text"], L["Pandemic"]
local S_TIME, S_HIGHLIGHT = L["Time color"], L["Highlight"]

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
          label = L["Color by"], desc = L["One color, or each debuff's dispel type (colors on General -> Dispel Colors). Buffs and many debuffs have no dispel type, class debuffs such as Judgment or Consecration included: those keep the bar color."] },
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

-- ── Background & border ───────────────────────────────────────────────────────────────────────

-- The background is a bar group, not options-ui-§16's "group over a background": that clause is for
-- a surface with no texture, and this one has a live texture (modules/Style_Bars.lua paints it). The
-- composer's own tooltips describe a fill, so each row's is replaced, found by path.
local bg = H.BarGroup({
    prefix = P, page = PAGE, group = G_BG, subgroup = L["Background"], classColor = UNIT,
    keys = { barTexture = "bgTexture", barAlpha = "bgAlpha", barColor = "bgColor", useClassColorBar = "useClassColorBg" },
    labels = { barTexture = L["Background texture"], barAlpha = L["Background opacity"], barColor = L["Background color"] },
    -- feedback #7: the background colors by dispel type as the fill does, from the same palette.
    extra = {
        { path = P .. "bgColorMode", type = "string", values = NS.Choices(C.BAR_COLOR_MODES, C.BAR_COLOR_MODE_LABELS),
          label = L["Color by"] },
    },
})
local BG_TOOLTIPS = {
    [P .. "bgTexture"] = L["The texture drawn behind the fill."],
    [P .. "bgAlpha"] = L["How opaque the background texture is."],
    [P .. "bgColor"] = L["The background color."] .. (H.CLASS_COLOR_NOTE and (" " .. H.CLASS_COLOR_NOTE) or ""),
    [P .. "useClassColorBg"] = L["Draw the background in the class color instead of the swatch beside it."],
    [P .. "bgColorMode"] = L["One color, or each debuff's dispel type (colors on General -> Dispel Colors). Buffs and many debuffs have no dispel type, class debuffs such as Judgment or Consecration included: those keep the background color."],
}
for _, row in ipairs(bg) do row.tooltip = BG_TOOLTIPS[row.path] end
NS.RegisterSchemaRows(bg)
local border = H.BorderGroup({
    prefix = P, page = PAGE, group = G_BG, subgroup = L["Border"], show = true, classColor = UNIT,
})
for _, row in ipairs(border) do
    if row.path == P .. "borderStyle" then row.tooltip = L["The border texture. Solid redraws at once; any other texture, and a new thickness for one, reaches the aura buttons already on screen after a /reload."] end
end
NS.RegisterSchemaRows(border)

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

-- ── Icon ──────────────────────────────────────────────────────────────────────────────────────
-- Second-last in the strip, ahead of Pandemic (owner, 2026-09-20): the icon is an ornament beside
-- the bar rather than part of the bar itself, so it follows the bar's own look and its three text
-- elements. A tab's place is where its group is FIRST DECLARED — the library's
-- O.RenderTabbedSchema walks NS.SchemaForPage(pageKey) in declaration order and opens a tab the
-- first time it meets a group — so this block sits here, between the text rows and Pandemic, rather than
-- carrying an index of its own.

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
-- A style other than Solid is a backdrop, which a live button's secret size keeps from redrawing
-- (modules/Style.lua's ApplyBorder, B2-3): the Border style tooltips say when it shows.
for _, row in ipairs(iconBorder) do
    if row.path == P .. "iconBorderShow" then row.tooltip = L["Draw a border around the icon; its art sits inside it."] end
    if row.path == P .. "iconBorderStyle" then row.tooltip = L["The border texture. Solid redraws at once; any other texture, and a new thickness for one, reaches the aura buttons already on screen after a /reload."] end
end
NS.RegisterSchemaRows(iconBorder)

-- ── Pandemic ──────────────────────────────────────────────────────────────────────────────────
-- Smoke batch 2, B2-1 (the owner's call): the seconds-left time color (once "Running out") and the
-- engine's refresh-window wash (once "Refresh window", on a Highlights tab) are both named for the
-- pandemic window, on this tab. Two subsections keep them apart: Time color is the player's own
-- seconds threshold; Highlight is the window the game finds per spell. Labels only: the paths and
-- stored values are unchanged.

NS.RegisterSchemaRows({
    { path = P .. "expiringColorOn", page = PAGE, group = G_PANDEMIC, subgroup = S_TIME, type = "bool",
      label = L["Recolor the time in the pandemic window"],
      desc = L["Turn the time text another color in the pandemic window: the last seconds, set below."] },
    { path = P .. "expiringThreshold", page = PAGE, group = G_PANDEMIC, subgroup = S_TIME, type = "number",
      min = 1, max = 60, step = 1, label = L["Pandemic window (seconds left)"],
      desc = L["The pandemic window starts this many seconds before the aura ends."] },
    -- Palette definition (options-ui-§17 exemption): identifies a state, not a player.
    { path = P .. "expiringColor", page = PAGE, group = G_PANDEMIC, subgroup = S_TIME, type = "color",
      startsLine = true, label = L["Pandemic-window time color"], desc = L["The time text's color in the pandemic window."] },
    -- engine-only: the window is the engine's to find (CustomAuraButton's pandemic window, a
    -- per-spell rule Lua cannot read); a placeholder is a made-up aura with none (the color below
    -- still reaches the wash on both).
    { path = P .. "pandemic", page = PAGE, group = G_PANDEMIC, subgroup = S_HIGHLIGHT, type = "bool",
      startsLine = true, label = L["Highlight the pandemic window"], coverage = "engine-only",
      desc = L["Wash the bar while the aura can be refreshed without losing any of its duration. The game finds this window for each spell; the seconds set above do not change it."] },
    { path = P .. "pandemicColor", page = PAGE, group = G_PANDEMIC, subgroup = S_HIGHLIGHT, type = "color",
      label = L["Pandemic-window highlight color"], desc = L["The highlight's color."] },
})

NS.RegisterContainerPage(PAGE, L["Bars"], "AuraMasterBarsPanel", {
    disabledFor = function(cfg) return cfg.style ~= "bars" end,
    disabledNotice = function(cfg)
        if cfg.style == "text" then
            return L["Not in use: this container is drawn as text. Set its Style to Bars on the Containers page to use these settings."]
        end
        return L["Not in use: this container is drawn as icons. Set its Style to Bars on the Containers page to use these settings."]
    end,
})
