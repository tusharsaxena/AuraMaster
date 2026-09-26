local _, NS = ...

-- settings/Icons.lua — how a container drawn as ICONS looks (modules/Style_Icons.lua draws it).
--
--     band   [Container ▾]
--     [ Size ][ Border ][ Cooldown ][ Time text ][ Stack text ][ Pandemic ]
--
-- Same rules as settings/Bars.lua: composed font and border blocks, a class-color companion on every
-- color, resolved to the class of the container's unit and snapshotted per apply, and palette
-- swatches (the pandemic window's time and highlight colors) exempt.
--
-- S-1: Bars folded its Size tab (two sliders) into a renamed General tab. This page's tab set has no
-- Bar-shaped tab to rename, and its Size tab (width, height, zoom) is a coherent "the icon's box"
-- group that would land arbitrarily inside Border or Cooldown if folded anywhere -- so Size stays a
-- tab of its own here; the two pages are deliberately not made to match shape-for-shape.

local L = NS.L
local H = NS.Helpers
local C = NS.Constants

local PAGE = "icons"
local P = "container.icons."
local UNIT = { source = "unit" }

local G_SIZE, G_BORDER, G_CD = L["Size"], L["Border"], L["Cooldown"]
local G_TIME, G_STACK, G_PANDEMIC = L["Time text"], L["Stack text"], L["Pandemic"]
local S_TIME, S_HIGHLIGHT = L["Time color"], L["Highlight"]

local POINTS = NS.Choices(C.POINTS, C.POINT_LABELS)
local JUSTIFY = NS.Choices(C.JUSTIFY, C.JUSTIFY_LABELS)

NS.RegisterSchemaRows({
    { path = P .. "width", page = PAGE, group = G_SIZE, type = "number", min = 8, max = 128, step = 1,
      label = L["Width (px)"], desc = L["The width of one icon."] },
    { path = P .. "height", page = PAGE, group = G_SIZE, type = "number", min = 8, max = 128, step = 1,
      label = L["Height (px)"], desc = L["The height of one icon. A non-square icon is cropped, never squashed."] },
    { path = P .. "zoom", page = PAGE, group = G_SIZE, type = "number", min = 0, max = 0.3, step = 0.01,
      label = L["Icon zoom"], desc = L["Crop the icon's border art."] },
})

local border = H.BorderGroup({
    prefix = P, page = PAGE, group = G_BORDER, subgroup = L["Border"], show = true, classColor = UNIT,
    extra = {
        { path = P .. "dispelBorder", type = "bool", label = L["Color the border by dispel type"],
          desc = L["Where a debuff has a dispel type, this border replaces yours in the dispel color."] },
    },
})
-- A style other than Solid is a backdrop, which a live button's secret size keeps from redrawing
-- (modules/Style.lua's ApplyBorder, B2-3): the tooltip says when it shows.
for _, row in ipairs(border) do
    if row.path == P .. "borderStyle" then row.tooltip = L["The border texture. Solid redraws at once; any other texture, and a new thickness for one, reaches the aura buttons already on screen after a /reload."] end
end
NS.RegisterSchemaRows(border)

NS.RegisterSchemaRows({
    { path = P .. "cooldown", page = PAGE, group = G_CD, type = "bool",
      label = L["Show cooldown swipe"], desc = L["Shade the icon as the aura runs out."] },
    { path = P .. "cooldownReverse", page = PAGE, group = G_CD, type = "bool",
      label = L["Reverse the swipe"], desc = L["Shade what has elapsed rather than what remains."] },
    { path = P .. "cooldownEdge", page = PAGE, group = G_CD, type = "bool",
      label = L["Draw the swipe's edge"], desc = L["A bright line along the swipe's edge."] },
    { path = P .. "swipeAlpha", page = PAGE, group = G_CD, type = "number", min = 0, max = 1, step = 0.05,
      isPercent = true, label = L["Swipe darkness"], desc = L["How dark the shaded part is."] },
    { path = P .. "blizzardNumbers", page = PAGE, group = G_CD, type = "bool",
      label = L["Blizzard countdown numbers"], desc = L["Also show the game's own countdown on the icon, as well as the time text."] },
})

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
          values = POINTS, label = L["Anchor"], desc = L["Where on the icon the text is anchored."] },
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

textRows("time", G_TIME, {
    { path = P .. "timeFormat", subgroup = L["Countdown"], type = "string",
      values = NS.Choices(C.TIME_FORMATS, C.TIME_FORMAT_LABELS), label = L["Time format"],
      desc = L["How the remaining time is written."] },
})
textRows("stacks", G_STACK)

-- The Pandemic tab (smoke batch 2, B2-1): the same two subsections as settings/Bars.lua's, which
-- replaced the Highlights tab. Labels only: paths and stored values unchanged.
NS.RegisterSchemaRows({
    { path = P .. "expiringColorOn", page = PAGE, group = G_PANDEMIC, subgroup = S_TIME, type = "bool",
      label = L["Recolor the time in the pandemic window"],
      desc = L["Turn the time text another color in the pandemic window: the last seconds, set below."] },
    { path = P .. "expiringThreshold", page = PAGE, group = G_PANDEMIC, subgroup = S_TIME, type = "number",
      min = 1, max = 60, step = 1, label = L["Pandemic window (seconds left)"],
      desc = L["The pandemic window starts this many seconds before the aura ends."] },
    -- Palette definitions (options-ui-§17 exemption): each identifies a state, not a player.
    { path = P .. "expiringColor", page = PAGE, group = G_PANDEMIC, subgroup = S_TIME, type = "color",
      startsLine = true, label = L["Pandemic-window time color"], desc = L["The time text's color in the pandemic window."] },
    -- engine-only: as on settings/Bars.lua, the window is the engine's to find and a placeholder has
    -- none (tests/test_render_coverage.lua).
    { path = P .. "pandemic", page = PAGE, group = G_PANDEMIC, subgroup = S_HIGHLIGHT, type = "bool",
      startsLine = true, label = L["Highlight the pandemic window"], coverage = "engine-only",
      desc = L["Wash the icon while the aura can be refreshed without losing any of its duration. The game finds this window for each spell; the seconds set above do not change it."] },
    { path = P .. "pandemicColor", page = PAGE, group = G_PANDEMIC, subgroup = S_HIGHLIGHT, type = "color",
      label = L["Pandemic-window highlight color"], desc = L["The highlight's color."] },
})

NS.RegisterContainerSection(PAGE, L["Icon"], {
    style   = "icons",
    tooltip = L["How this container's icons look."],
})
