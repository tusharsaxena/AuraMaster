local _, NS = ...

-- settings/Icons.lua — how a container drawn as ICONS looks (modules/Style_Icons.lua draws it).
--
--     band   [Container ▾]
--     [ Size ][ Border ][ Cooldown ][ Time text ][ Stack text ][ Highlights ]
--
-- Same rules as settings/Bars.lua: composed font and border blocks, a class-color companion on every
-- color, resolved to the class of the container's unit and snapshotted per apply, and palette
-- swatches (running out, refresh window) exempt.

local L = NS.L
local H = NS.Helpers
local C = NS.Constants

local PAGE = "icons"
local P = "container.icons."
local UNIT = { source = "unit" }

local G_SIZE, G_BORDER, G_CD = L["Size"], L["Border"], L["Cooldown"]
local G_TIME, G_STACK, G_HI = L["Time text"], L["Stack text"], L["Highlights"]

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

NS.RegisterSchemaRows(H.BorderGroup({
    prefix = P, page = PAGE, group = G_BORDER, subgroup = L["Border"], show = true, classColor = UNIT,
    extra = {
        { path = P .. "dispelBorder", type = "bool", label = L["Color the border by dispel type"],
          desc = L["Where a debuff has a dispel type, this border replaces yours in the dispel color."] },
    },
}))

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

NS.RegisterSchemaRows({
    { path = P .. "expiringColorOn", page = PAGE, group = G_HI, subgroup = L["Running out"], type = "bool",
      label = L["Recolor the time when running out"], desc = L["Turn the time text another color in the last seconds."] },
    { path = P .. "expiringThreshold", page = PAGE, group = G_HI, subgroup = L["Running out"], type = "number",
      min = 1, max = 60, step = 1, label = L["Running out below (sec)"], desc = L["When the time text changes color."] },
    -- Palette definitions (options-ui-§17 exemption): each identifies a state, not a player.
    { path = P .. "expiringColor", page = PAGE, group = G_HI, subgroup = L["Running out"], type = "color",
      startsLine = true, label = L["Running-out color"], desc = L["The time text's color in the last seconds."] },
    -- engine-only: as on settings/Bars.lua, the refresh window is the engine's to find and a
    -- placeholder has none (tests/test_render_coverage.lua).
    { path = P .. "pandemic", page = PAGE, group = G_HI, subgroup = L["Refresh window"], type = "bool",
      startsLine = true, label = L["Highlight the refresh window"], coverage = "engine-only",
      desc = L["Wash the icon while the aura can be refreshed without losing any of its duration."] },
    { path = P .. "pandemicColor", page = PAGE, group = G_HI, subgroup = L["Refresh window"], type = "color",
      label = L["Refresh-window color"], desc = L["The highlight's color."] },
})

-- A container drawn as bars sees every row here disabled, under a notice naming where its style is
-- changed (B-2; settings/OptionsSetup.lua's renderActiveTab).
NS.RegisterContainerPage(PAGE, L["Icons"], "AuraMasterIconsPanel", {
    disabledFor = function(cfg) return cfg.style ~= "icons" end,
    disabledNotice = L["This container is drawn as bars; these settings apply once its style is Icons (General → Containers)."],
})
