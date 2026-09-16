local addonName, NS = ...
NS.Constants = NS.Constants or {}
local C = NS.Constants

-- core/Constants.lua — enum-like tables and fixed values. Nothing here reads the database; every
-- table is built once at file load and never mutated.

-- ---------------------------------------------------------------------------
-- Media
-- ---------------------------------------------------------------------------

-- Fallbacks returned when LibSharedMedia is absent or a stored media key no longer resolves, so an
-- element always has a real texture, border and face to draw with.
C.FALLBACK_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
C.FALLBACK_BORDER  = "Interface\\Tooltips\\UI-Tooltip-Border"
C.FALLBACK_FONT    = "Fonts\\FRIZQT__.TTF"
C.WHITE_TEXTURE    = "Interface\\Buttons\\WHITE8X8"

-- The debug console's monospace face, from LibKa0s-Media-1.0 (core/MediaSetup.lua loads first and
-- publishes NS.MediaFont). The last rung is a literal client font, never nil: SetFont accepts a path
-- to a missing file and then simply draws nothing.
C.FONT_MONO = NS.MediaFont and NS.MediaFont("JetBrains Mono") or C.FALLBACK_FONT
C.FONT_MONO_NAME = "JetBrains Mono"

-- The landing page logo (options-ui-§5): a .tga, because the client cannot load .png or .jpg.
C.LOGO_PATH = "Interface\\AddOns\\" .. addonName .. "\\media\\logos\\auramaster.logo.tga"

-- The ICON logo (launcher-§4, layout-§4): a DIFFERENT, smaller file doing a different job --
-- 128x128, uncompressed 32-bit, the face the client draws in the AddOns list (## IconTexture), on
-- the minimap button and in a broker display. The landing page keeps the 300x300 file above;
-- neither substitutes for the other.
C.LOGO_ICON_PATH = "Interface\\AddOns\\" .. addonName .. "\\media\\logos\\auramaster.logo.128.tga"

-- ---------------------------------------------------------------------------
-- What a container shows
-- ---------------------------------------------------------------------------

-- The units a container can track, in display order. Party members are a tracked enhancement.
C.UNITS = { "player", "target", "focus", "pet" }
C.UNIT_LABELS = { player = "Player", target = "Target", focus = "Focus", pet = "Pet" }

-- Aura types. HELPFUL and HARMFUL are the engine's own filter tokens; ENCHANT is this addon's name for
-- the player's temporary weapon enchants, which the engine draws through AddItemEnchantment rather
-- than through an aura group.
C.AURA_TYPES = { "HELPFUL", "HARMFUL", "ENCHANT" }
C.AURA_TYPE_LABELS = { HELPFUL = "Buffs", HARMFUL = "Debuffs", ENCHANT = "Weapon enchants" }

-- Container styles. Text is a tracked enhancement.
C.STYLES = { "bars", "icons" }
C.STYLE_LABELS = { bars = "Bars", icons = "Icons" }

-- Who applied the aura. "mine" and "others" compile to the PLAYER token and its negation.
C.CAST_BY = { "any", "mine", "others" }
C.CAST_BY_LABELS = { any = "Anyone", mine = "Me (and my pet)", others = "Anyone but me" }

-- Duration modes. "timed" is the engine's maxDuration = huge; "timeless" has no engine filter and is
-- built from the spells modules/TimedSpells.lua has learned are timed (see docs/scope.md).
C.DURATION_MODES = { "any", "timed", "timeless" }
C.DURATION_MODE_LABELS = { any = "Any duration", timed = "Only auras with a duration",
    timeless = "Only auras without a duration" }

--- Category selection (schema v3): Show is the absence of a decision (it excludes nothing);
--- Hide removes the category's auras from the container.
C.CATEGORY_STATES = { "show", "hide" }
C.CATEGORY_STATE_LABELS = { show = "Show", hide = "Hide" }

-- Sort methods: our key → the engine's AuraContainerSortMethod member name.
C.SORT_METHODS = { "default", "expiration", "expirationOnly", "name", "nameOnly",
    "bigDefensive", "important", "unitFrameDebuff", "applied" }
C.SORT_METHOD_LABELS = {
    default         = "Blizzard default",
    expiration      = "Time remaining (grouped)",
    expirationOnly  = "Time remaining",
    name            = "Name (grouped)",
    nameOnly        = "Name",
    bigDefensive    = "Big defensives first",
    important       = "Important first",
    unitFrameDebuff = "Unit-frame debuff order",
    applied         = "Order applied",
}
C.SORT_METHOD_ENGINE = {
    default = "Default", expiration = "Expiration", expirationOnly = "ExpirationOnly",
    name = "Name", nameOnly = "NameOnly", bigDefensive = "BigDefensive",
    important = "ImportantOnly", unitFrameDebuff = "UnitFrameDebuff", applied = "AuraInstanceIDOnly",
}
C.SORT_DIRECTIONS = { "normal", "reverse" }
C.SORT_DIRECTION_LABELS = { normal = "Normal", reverse = "Reversed" }

-- Temporary weapon enchant slots: our key → the engine's AuraContainerItemEnchantmentSlot member.
C.ENCHANT_SLOTS = { "mainHand", "offHand", "ranged" }
C.ENCHANT_SLOT_ENGINE = { mainHand = "MainHand", offHand = "OffHand", ranged = "Ranged" }

-- ---------------------------------------------------------------------------
-- Where a container sits
-- ---------------------------------------------------------------------------

C.POINTS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
C.POINT_LABELS = {
    TOPLEFT = "Top left", TOP = "Top", TOPRIGHT = "Top right",
    LEFT = "Left", CENTER = "Center", RIGHT = "Right",
    BOTTOMLEFT = "Bottom left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom right",
}

-- What a container is attached to.
C.ATTACH_MODES = { "screen", "container", "frame" }
C.ATTACH_MODE_LABELS = { screen = "Screen", container = "Another container", frame = "Named frame" }

-- Growth.
C.AXES = { "horizontal", "vertical" }
C.AXIS_LABELS = { horizontal = "Rows (fill left to right first)", vertical = "Columns (fill top to bottom first)" }
C.GROW_H = { "right", "left" }
C.GROW_H_LABELS = { right = "Right", left = "Left" }
C.GROW_V = { "down", "up" }
C.GROW_V_LABELS = { down = "Down", up = "Up" }

C.STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG" }
C.STRATA_LABELS = { BACKGROUND = "Background", LOW = "Low", MEDIUM = "Medium", HIGH = "High", DIALOG = "Dialog" }

-- ---------------------------------------------------------------------------
-- How elements look
-- ---------------------------------------------------------------------------

C.ICON_POSITIONS = { "LEFT", "RIGHT", "NONE" }
C.ICON_POSITION_LABELS = { LEFT = "Left of the bar", RIGHT = "Right of the bar", NONE = "Hidden" }

C.BAR_COLOR_MODES = { "static", "dispel" }
C.BAR_COLOR_MODE_LABELS = { static = "One color", dispel = "By dispel type" }

C.DRAIN_DIRECTIONS = { "left", "right" }
C.DRAIN_DIRECTION_LABELS = { left = "Toward the left", right = "Toward the right" }

C.JUSTIFY = { "LEFT", "CENTER", "RIGHT" }
C.JUSTIFY_LABELS = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" }

C.TOOLTIP_ANCHORS = { "ANCHOR_BOTTOMLEFT", "ANCHOR_BOTTOMRIGHT", "ANCHOR_TOPLEFT", "ANCHOR_TOPRIGHT",
    "ANCHOR_LEFT", "ANCHOR_RIGHT", "ANCHOR_CURSOR" }
C.TOOLTIP_ANCHOR_LABELS = {
    ANCHOR_BOTTOMLEFT = "Below, to the left", ANCHOR_BOTTOMRIGHT = "Below, to the right",
    ANCHOR_TOPLEFT = "Above, to the left", ANCHOR_TOPRIGHT = "Above, to the right",
    ANCHOR_LEFT = "Left", ANCHOR_RIGHT = "Right", ANCHOR_CURSOR = "At the cursor",
}

-- Time text. Each is a SecondsFormatter setup; "blizzard" copies the engine's own, rounding up.
C.TIME_FORMATS = { "blizzard", "short", "long" }
C.TIME_FORMAT_LABELS = { blizzard = "Blizzard (1 unit, 90 s -> 1 m)", short = "Short (1 unit)",
    long = "Detailed (2 units, 1h 15m)" }
-- The width a Bars time text is boxed to beside the name, in ems of its font size: the widest string
-- each format writes ("59m" in one unit, "23h 59m" in two). The engine writes the text secret, so
-- its width cannot be read back; a fixed budget is what gives the time's Justify a box (B-5).
C.TIME_TEXT_EMS = { blizzard = 2.5, short = 2.5, long = 4.5 }

-- The dispel types the engine names, plus "None" for an aura without one.
C.DISPEL_TYPES = { "Magic", "Curse", "Disease", "Poison", "Bleed", "None" }
C.DEFAULT_DISPEL_COLORS = {
    Magic   = { r = 0.20, g = 0.60, b = 1.00, a = 1 },
    Curse   = { r = 0.60, g = 0.00, b = 1.00, a = 1 },
    Disease = { r = 0.60, g = 0.40, b = 0.00, a = 1 },
    Poison  = { r = 0.00, g = 0.60, b = 0.00, a = 1 },
    Bleed   = { r = 0.80, g = 0.10, b = 0.10, a = 1 },
    None    = { r = 0.80, g = 0.00, b = 0.00, a = 1 },
}

-- Placeholder auras for preview mode (preview-mode): real render path, invented data.
C.PREVIEW_AURAS = {
    { name = "Power Word: Fortitude", icon = 135987, remaining = 3540, duration = 3600, stacks = 0 },
    { name = "Bloodlust",             icon = 136012, remaining = 28,   duration = 40,   stacks = 0 },
    { name = "Shield Wall",           icon = 132362, remaining = 4,    duration = 8,    stacks = 0 },
    { name = "Ignore Pain",           icon = 1377132, remaining = 11,  duration = 12,   stacks = 3 },
    { name = "Well Fed",              icon = 136000, remaining = 0,    duration = 0,    stacks = 0 },
}
