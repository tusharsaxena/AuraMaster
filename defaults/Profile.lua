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

local function color(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end

--- core/Constants.lua's dispel palette as stored colors, each one its own table.
local function dispelColors()
    local out = {}
    for k, v in pairs(C.DEFAULT_DISPEL_COLORS) do out[k] = color(v.r, v.g, v.b, v.a) end
    return out
end

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

    -- Profile-wide since schema v2 (core/Database.lua's MigrateV2 lifted them off the containers):
    -- every container shares one set of spell-category edits and one dispel palette.
    -- `categorySpells` is [categoryKey] = { [spellId] = true (added) | false (removed) }, layered
    -- over defaults/Categories.lua's starter lists, so a shipped list update still reaches a player
    -- who has edited one. Written whole through settings/Schema.lua's `categorySpells` carve-out.
    categorySpells = {},
    -- One color per dispel type, for a bar colored by dispel type.
    dispelColors   = dispelColors(),
    -- Which weapon slots the weaponEnchants category draws (settings/Filters.lua). Profile-wide, like
    -- categorySpells: one set of slots every container's enchant block shares.
    enchantSlots   = { mainHand = true, offHand = true, ranged = true },

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

    -- LibDBIcon's OWN table, and the declaration here is what materializes it (architecture-§5):
    -- the library writes `minimapPos` into it when the player drags the button and `hide` when
    -- they use its own menu, and the Minimap button row writes the same `hide`. One record, never
    -- a `show` beside it (launcher-§3, anti-pattern #81).
    --
    -- GLOBAL, deliberately, not profile: a ring of minimap buttons is furniture the player
    -- arranged once, so a profile switch must not move it, and Reset all settings -- a profile
    -- reset by definition (options-ui-§12) -- must not un-hide a button they deliberately hid.
    --
    -- `hide = false`: the button ships SHOWN. The row's label says shown and this key says
    -- hidden, which is why settings/Schema.lua's seam inverts.
    minimap = { hide = false },
}

--- The six canonical font leaves (options-ui-§16): white, outlined, no shadow, at `size`.
local function font(size)
    return {
        font              = "Friz Quadrata TT",
        fontSize          = size,
        fontColor         = color(1, 1, 1, 1),
        useClassColorFont = false,
        fontFlags         = "OUTLINE",
        fontShadow        = false,
    }
end

--- The font block every Bars and Icons text element carries: the six font leaves, then where the
--- text sits.
local function text(show, size, point, x, y, justify)
    local t = font(size)
    t.show, t.point, t.x, t.y, t.justify = show, point, x, y, justify
    return t
end

NS.CONTAINER_TEMPLATE = {
    name     = L("Container"),
    enabled  = true,
    unit     = "player",
    auraType = "HELPFUL",
    style    = "bars",

    -- What the container shows. See modules/FilterCompiler.lua for how each field reaches the engine.
    filter = {
        -- [categoryKey] = "show" | "hide". Every key of both lists, so each resolves as a schema
        -- row (settings/Filters.lua) and a key added later backfills as Show (the default: it
        -- excludes nothing). defaults/Categories.lua loads first for exactly this line.
        categories      = NS.Categories.DefaultStates(),
        -- The spell-list edits are the profile's since schema v2 (`profile.categorySpells`).
        whitelist       = {},   -- [spellId] = true — always shown, whatever the categories say
        blacklist       = {},   -- [spellId] = true — never shown
        castBy          = "any",
        durationMode    = "any",
        maxDuration     = 0,    -- seconds; 0 = no limit
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
        scale = 1.0, alpha = 1.0, strata = "MEDIUM", level = 5,
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
        colorMode = "static",   -- "dispel" tints by the profile's dispelColors (schema v2)
        drain = "left", smooth = false,

        bgTexture = "Blizzard", bgAlpha = 1.0, bgColor = color(0, 0, 0, 0.5), useClassColorBg = false,
        bgColorMode = "static",   -- "dispel" tints the background as colorMode does the fill (feedback #7)

        borderShow = false, borderStyle = "Solid", borderSize = 1,
        borderColor = color(0, 0, 0, 1), useClassColorBorder = false,

        icon = "LEFT", iconSize = 0, iconGap = 1, iconZoom = 0.08,
        iconBorderShow = false, iconBorderStyle = "Solid", iconBorderSize = 1,
        iconBorderColor = color(0, 0, 0, 1), useClassColorIconBorder = false,

        spark = true, sparkWidth = 8, sparkColor = color(1, 1, 1, 0.9), useClassColorSpark = false,
        sparkTimeless = true,   -- false: no spark on an aura without a duration (modules/Style_Bars.lua)

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

    -- The text style (issue #2): each aura one line, built from `template` by
    -- modules/TextTemplate.lua and drawn as a chain of font strings (modules/Style_Text.lua).
    text = {
        width = 220, height = 16,
        template = "$spellname$[ x$stacks$][ - $remainingduration$]",
        justifyH = "LEFT", justifyV = "MIDDLE", x = 2, y = 0,
        font = font(12),
        timeFormat = "blizzard",

        icon = "NONE", iconSize = 0, iconGap = 2, iconZoom = 0.08,
        iconBorderShow = false, iconBorderStyle = "Solid", iconBorderSize = 1,
        iconBorderColor = color(0, 0, 0, 1), useClassColorIconBorder = false,

        anim = "none", animSpeed = 1.0, animIntensity = 0.3, animBounce = 3,

        expiringColorOn = false, expiringThreshold = 5, expiringColor = color(1, 0.25, 0.25, 1),
        expiringBlink = false,
    },
}

-- The starter containers a fresh profile is seeded with (core/Database.lua): a player-buff bar
-- stack, a player-debuff icon row, a target-debuff icon row, and a text list of the player's
-- offensive and defensive cooldowns — enough to show what the addon does without the player having
-- to build anything first. New profiles only: a profile already `seeded` gets none of them again.
NS.STARTER_CONTAINERS = {
    {
        name = "Player buffs", unit = "player", auraType = "HELPFUL", style = "bars",
        filter = { castBy = "any" },
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
    {
        -- Only the Offensive cooldowns and Defensives lists draw: every other buff category is
        -- Hidden, Uncategorized included (defaults/Categories.lua's StatesShowing).
        name = "Player cooldowns", unit = "player", auraType = "HELPFUL", style = "text",
        filter = { castBy = "any", categories = NS.Categories.StatesShowing({ "offensiveCDs", "defensives" }) },
        position = { point = "CENTER", relativePoint = "CENTER", x = -260, y = -40 },
        layout = { axis = "vertical", growH = "right", growV = "down" },
    },
}
