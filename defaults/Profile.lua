local _, NS = ...

-- defaults/Profile.lua — the ONE place a default value is hardcoded (savedvariables-§2).
--
-- Two shapes live here:
--
--   NS.defaults           what AceDB merges into a profile and into `global`. Addon-wide settings
--                         only — the containers themselves are not defaults.
--   NS.CONTAINER_TEMPLATE the full shape of ONE container. A container is created at runtime by the
--                         player, so it cannot be an AceDB default; modules/ContainerManager.lua
--                         deep-copies this template when one is created, and core/Database.lua fills
--                         any key a later version added into every stored container (`== nil`, never
--                         `or`, so a stored `false` survives — savedvariables-§5).
--
-- Every `container.<...>` schema row in settings/ resolves its default against the template, and
-- settings/Schema.lua's validator proves every path resolves.

local C = NS.Constants
local L = function(s) return s end   -- keys are the English strings (localization-§2)

NS.defaults = NS.defaults or {}

NS.defaults.profile = {
    -- The Master controls tab (options-ui-§15). Addon-wide: `enabled` gates every container,
    -- `visibility` is the four-value dropdown, `scale` and `alpha` multiply each container's own,
    -- `locked` hides every container's drag handle and ends preview mode.
    enabled    = true,
    visibility = "always",
    scale      = 1.0,
    alpha      = 1.0,
    locked     = true,

    -- Blizzard's own buff and debuff frames. Reparented to a hidden frame rather than hidden
    -- (events-frames-taint-§3), and only while not in combat.
    hideBlizzardBuffs   = false,
    hideBlizzardDebuffs = false,

    -- The container registry. `containers` is keyed by id; `containerOrder` is display order (the
    -- settings picker, the CLI, and the order containers are built in). Both are written at runtime by
    -- modules/ContainerManager.lua, and on load by core/Database.lua's PrepareProfile (repair and
    -- first-run seeding). `seeded` records that a fresh profile has had its starter containers
    -- created, so deleting them all does not bring them back on the next login.
    containers      = {},
    containerOrder  = {},
    nextContainerId = 1,
    seeded          = false,
}

NS.defaults.global = {
    -- Account-wide schema stamp (savedvariables-§1). Defaults to 1, NOT the current version: AceDB
    -- fills an absent key the moment the section is read, which happens before NS.RunMigrations, so a
    -- default of the current number would stamp every old database as already migrated.
    schemaVersion = 1,

    -- Spell ids modules/TimedSpells.lua has seen carry a duration. Account-wide on purpose: whether a
    -- spell is timed is a fact about the game, not a preference, and a character learns it for all.
    timedSpells = {},
}

local function color(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end

--- The font block every text element carries: the six canonical leaves (options-ui-§16), then where
--- the text sits.
local function text(show, size, point, x, y, justify)
    return {
        show              = show,
        font              = "Friz Quadrata TT",
        fontSize          = size,
        fontColor         = color(1, 1, 1, 1),
        useClassColorFont = false,
        fontFlags         = "OUTLINE",
        fontShadow        = false,
        point             = point,
        x                 = x,
        y                 = y,
        justify           = justify,
    }
end

local function dispelColors()
    local out = {}
    for k, v in pairs(C.DEFAULT_DISPEL_COLORS) do out[k] = color(v.r, v.g, v.b, v.a) end
    return out
end

NS.CONTAINER_TEMPLATE = {
    name     = L("Container"),
    enabled  = true,
    unit     = "player",
    auraType = "HELPFUL",
    style    = "bars",

    -- What the container shows. See modules/FilterCompiler.lua for how each field reaches the engine.
    filter = {
        -- [categoryKey] = "" (neutral) | "show" | "hide". Every key of both lists, so each resolves
        -- as a schema row (settings/Filters.lua) and a key added later backfills as neutral.
        -- defaults/Categories.lua loads first for exactly this line.
        categories      = NS.Categories.NeutralStates(),
        -- Per-category spell-list edits: [categoryKey] = { [spellId] = true (added) | false (removed) }.
        -- Layered over defaults/Categories.lua's starter list, so a shipped list update still reaches
        -- a player who has edited it.
        categorySpells  = {},
        whitelist       = {},   -- [spellId] = true — always shown, whatever the categories say
        blacklist       = {},   -- [spellId] = true — never shown
        castBy          = "any",
        durationMode    = "any",
        maxDuration     = 0,    -- seconds; 0 = no limit
        includeEnchants = false,-- a player buff container may also show weapon enchants
        hidePermanentEnchants = true,
        sortMethod      = "expirationOnly",
        sortDirection   = "normal",
        maxAuras        = 0,    -- per group; 0 = no limit
    },

    -- Where the container sits when it is attached to the screen: stored, never read back off a frame.
    position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },

    -- What the container is attached to (modules/Anchors.lua). `container` is a container id; `frame`
    -- is a global frame name, re-resolved when the add-on that owns it loads.
    attach = {
        mode = "screen", container = 0, frame = "",
        point = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = 0, y = -4,
    },

    -- How elements are arranged.
    layout = {
        axis = "vertical", growH = "right", growV = "down",
        spacing = 2, lineSpacing = 2, perLine = 0,
        scale = 1.0, alpha = 1.0, strata = "HIGH", level = 5,
    },

    -- Mouse behavior shared by both styles.
    behavior = {
        tooltips = true, tooltipAnchor = "ANCHOR_BOTTOMLEFT", tooltipInCombat = true,
        clickThrough = false, cancelOnRightClick = true,
    },

    bars = {
        width = 220, height = 18,

        barTexture = "Blizzard", barAlpha = 1.0,
        barColor = color(0.20, 0.55, 0.95, 1), useClassColorBar = false,
        colorMode = "static", dispelColors = dispelColors(),
        drain = "left", smooth = false,

        bgTexture = "Blizzard", bgAlpha = 1.0, bgColor = color(0, 0, 0, 0.5), useClassColorBg = false,

        borderShow = false, borderStyle = "Solid", borderSize = 1,
        borderColor = color(0, 0, 0, 1), useClassColorBorder = false,

        icon = "LEFT", iconSize = 0, iconGap = 1, iconZoom = 0.08,

        spark = true, sparkWidth = 8, sparkColor = color(1, 1, 1, 0.9), useClassColorSpark = false,

        name   = text(true, 11, "LEFT", 4, 0, "LEFT"),
        time   = text(true, 11, "RIGHT", -4, 0, "RIGHT"),
        stacks = text(true, 10, "BOTTOMRIGHT", -1, 1, "RIGHT"),

        timeFormat = "blizzard",
        expiringColorOn = false, expiringThreshold = 5, expiringColor = color(1, 0.25, 0.25, 1),

        pandemic = false, pandemicColor = color(1, 0.85, 0.10, 1),
    },

    icons = {
        width = 32, height = 32, zoom = 0.08,

        borderShow = true, borderStyle = "Solid", borderSize = 1,
        borderColor = color(0, 0, 0, 1), useClassColorBorder = false,
        dispelBorder = true,

        cooldown = true, cooldownReverse = false, cooldownEdge = true,
        swipeAlpha = 0.6, blizzardNumbers = false,

        time   = text(true, 11, "BOTTOM", 0, -12, "CENTER"),
        stacks = text(true, 11, "BOTTOMRIGHT", -1, 1, "RIGHT"),

        timeFormat = "blizzard",
        expiringColorOn = false, expiringThreshold = 5, expiringColor = color(1, 0.25, 0.25, 1),

        pandemic = false, pandemicColor = color(1, 0.85, 0.10, 1),
    },
}

-- The starter containers a fresh profile is seeded with (core/Database.lua): a player-buff bar
-- stack, a player-debuff icon row, and a target-debuff icon row — enough to show what the addon does
-- without the player having to build anything first.
NS.STARTER_CONTAINERS = {
    {
        name = "Player buffs", unit = "player", auraType = "HELPFUL", style = "bars",
        filter = { castBy = "any", includeEnchants = true },
        position = { point = "TOPRIGHT", relativePoint = "TOPRIGHT", x = -240, y = -220 },
    },
    {
        name = "Player debuffs", unit = "player", auraType = "HARMFUL", style = "icons",
        position = { point = "TOPRIGHT", relativePoint = "TOPRIGHT", x = -240, y = -160 },
        layout = { axis = "horizontal", growH = "left", growV = "down" },
    },
    {
        name = "Target debuffs (mine)", unit = "target", auraType = "HARMFUL", style = "icons",
        filter = { castBy = "mine" },
        position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -160 },
        layout = { axis = "horizontal", growH = "right", growV = "down" },
    },
}
