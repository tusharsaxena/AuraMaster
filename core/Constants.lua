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

-- Aura types: the engine's own filter tokens. The player's temporary weapon enchants are not an aura
-- type (schema v5, feedback #6): they are the buff category `weaponEnchants`, which the engine draws
-- through AddItemEnchantment beside a player buff container's aura groups.
C.AURA_TYPES = { "HELPFUL", "HARMFUL" }
C.AURA_TYPE_LABELS = { HELPFUL = "Buffs", HARMFUL = "Debuffs" }

-- Container styles.
C.STYLES = { "bars", "icons", "text" }
C.STYLE_LABELS = { bars = "Bars", icons = "Icons", text = "Text" }

-- The Fill (layout.axis) each style suits, written when a container's Style changes (B5,
-- settings/Containers.lua): bars and text stack in a column, icons in a row.
C.STYLE_FILL_AXIS = { bars = "vertical", text = "vertical", icons = "horizontal" }

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

-- The side a container attached to another sits on (batch 9 E2; modules/Anchors.lua's edge model),
-- relative to the chain's flow, in display order. An after side is named by its parent point
-- (POINT_LABELS); a side one by the parent point it sits at, here.
C.ATTACH_EDGES = {
    "after-start", "after-center", "after-end",
    "ahead-start", "ahead-center", "ahead-end",
    "behind-start", "behind-center", "behind-end",
}
C.EDGE_SIDE_LABELS = {
    TOPLEFT = "Left, top", LEFT = "Left, middle", BOTTOMLEFT = "Left, bottom",
    TOPRIGHT = "Right, top", RIGHT = "Right, middle", BOTTOMRIGHT = "Right, bottom",
}

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
-- The name label's stored "no pick" (B9 E7): its justify is then its style's default
-- (modules/Anchors.lua's LabelJustify). A value rather than nil because every schema row's path
-- must resolve against the template (architecture-5). Never offered in the dropdown, which shows the
-- justify in effect; a reset writes it back.
C.LABEL_JUSTIFY_AUTO = "AUTO"

C.TOOLTIP_ANCHORS = { "ANCHOR_BOTTOMLEFT", "ANCHOR_BOTTOMRIGHT", "ANCHOR_TOPLEFT", "ANCHOR_TOPRIGHT",
    "ANCHOR_LEFT", "ANCHOR_RIGHT", "ANCHOR_CURSOR" }
C.TOOLTIP_ANCHOR_LABELS = {
    ANCHOR_BOTTOMLEFT = "Below, to the left", ANCHOR_BOTTOMRIGHT = "Below, to the right",
    ANCHOR_TOPLEFT = "Above, to the left", ANCHOR_TOPRIGHT = "Above, to the right",
    ANCHOR_LEFT = "Left", ANCHOR_RIGHT = "Right", ANCHOR_CURSOR = "At the cursor",
}

-- The "Not in use" notice over a container page drawn for another style (settings/OptionsSetup.lua's
-- mutedNotice): a muted red, about (0.80, 0.40, 0.40), readable on the dark panel and quieter
-- than an error red. The owner asked for gold first (2026-09-19, B3), then for this red on the same
-- day, on bars, icons and text pages alike (Task 20). The AARRGGBB body of a "|c" escape.
C.NOTICE_COLOR = "ffcc6666"

-- The TEST tag on a container's drag handle while test mode is on (feedback #8, modules/Anchors.lua's
-- handleText): orange, so the placeholders cannot be mistaken for live auras. The AARRGGBB body of a
-- "|c" escape.
C.TEST_TAG_COLOR = "ffff8000"

-- Time text. Each is a SecondsFormatter setup; "blizzard" copies the engine's own, rounding up.
C.TIME_FORMATS = { "blizzard", "short", "long" }
C.TIME_FORMAT_LABELS = { blizzard = "Blizzard (1 unit, 90 s -> 1 m)", short = "Short (1 unit)",
    long = "Detailed (2 units, 1h 15m)" }
-- The width a Bars time text is boxed to beside the name, in ems of its font size, used only where
-- the widest string cannot be MEASURED (modules/Style.lua's Style.TimeTextWidth, B4): the headless
-- harness. The engine writes the live text secret, so its width is never read back.
C.TIME_TEXT_EMS = { blizzard = 2.5, short = 2.5, long = 4.5 }

-- The dispel types the engine names. An aura with none (the engine keys it "None") takes the surface's
-- own color, not a palette color (feedback #7, modules/Style.lua's DispelColorMap).
C.DISPEL_TYPES = { "Magic", "Curse", "Disease", "Poison", "Bleed" }
C.DEFAULT_DISPEL_COLORS = {
    Magic   = { r = 0.20, g = 0.60, b = 1.00, a = 1 },
    Curse   = { r = 0.60, g = 0.00, b = 1.00, a = 1 },
    Disease = { r = 0.60, g = 0.40, b = 0.00, a = 1 },
    Poison  = { r = 0.00, g = 0.60, b = 0.00, a = 1 },
    Bleed   = { r = 0.80, g = 0.10, b = 0.10, a = 1 },
}

-- ---------------------------------------------------------------------------
-- The text style (issue #2): each aura one line of text, built from a template
-- ---------------------------------------------------------------------------

-- Where the line sits in its box. Center on a template of more than one piece STACKS it, one centered
-- row per field, since a chain's width is never readable (feedback #1, modules/Style_Text.lua's
-- layoutStack); TEXT_ROW_GAP is the space between two rows, in pixels.
C.TEXT_JUSTIFY_H = { "LEFT", "CENTER", "RIGHT" }
C.TEXT_ROW_GAP = 2
-- Size to fit (batch 8, AS-2, modules/Style_Text.lua's Text.AutoSize): the space above and below a
-- line's font, so a 12pt line is 16 tall, the old default height; and the width range a line is
-- clamped to, which the Text page's Width row offers too (settings/Text.lua).
C.TEXT_AUTOSIZE_PAD = 2
C.TEXT_WIDTH_MIN = 40
C.TEXT_WIDTH_MAX = 600
C.TEXT_JUSTIFY_V = { "TOP", "MIDDLE", "BOTTOM" }
C.TEXT_JUSTIFY_V_LABELS = { TOP = "Top", MIDDLE = "Middle", BOTTOM = "Bottom" }

C.TEXT_ICON_POSITIONS = { "NONE", "LEFT", "RIGHT" }
C.TEXT_ICON_POSITION_LABELS = { NONE = "Hidden", LEFT = "Left of the text", RIGHT = "Right of the text" }

-- The looping effect. No scale effect, on purpose: a Scale animation grows the glyphs past the boxes
-- the chain is anchored to, and the pieces overlap (docs/midnight-quirks.md).
C.TEXT_ANIMS = { "none", "pulse", "blink", "bounce" }
C.TEXT_ANIM_LABELS = { none = "None", pulse = "Pulse", blink = "Blink", bounce = "Bounce" }

-- The template's tokens, in cheat-sheet order. modules/TextTemplate.lua parses with this list and
-- settings/Text.lua prints it. `kind` is the engine field that draws a token; a duration token also
-- names the Enum.DurationTextBindingProperty member it reads, and whether it is a time or a percent.
C.TEXT_TOKENS = {
    { key = "spellname",         kind = "name" },
    { key = "stacks",            kind = "stacks" },
    { key = "dispeltype",        kind = "dispel" },
    { key = "remainingduration", kind = "duration", prop = "RemainingDuration", fmt = "time" },
    { key = "maxduration",       kind = "duration", prop = "TotalDuration",     fmt = "time" },
    { key = "elapsedduration",   kind = "duration", prop = "ElapsedDuration",   fmt = "time" },
    { key = "remainingpercent",  kind = "duration", prop = "RemainingPercent",  fmt = "percent" },
    { key = "elapsedpercent",    kind = "duration", prop = "ElapsedPercent",    fmt = "percent" },
}
-- What each token shows, one cheat-sheet line each.
C.TEXT_TOKEN_LABELS = {
    spellname         = "The aura's name",
    stacks            = "Its stack count, hidden below 2",
    dispeltype        = "Its dispel type (Magic, Curse, ...); nothing when it has none",
    remainingduration = "The time left",
    maxduration       = "Its full duration",
    elapsedduration   = "The time since it was applied",
    remainingpercent  = "How much of it is left, 0 to 100 (type the % yourself)",
    elapsedpercent    = "How much of it has run, 0 to 100 (type the % yourself)",
}

-- The types $dispeltype$ names, keyed as the aura's `dispelName`: every C.DISPEL_TYPES entry, plus
-- Enrage. A type this list lacks shows the engine's own text.
C.TEXT_DISPEL_TYPES = { "Magic", "Curse", "Disease", "Poison", "Bleed", "Enrage" }
C.TEXT_DISPEL_LABELS = { Magic = "Magic", Curse = "Curse", Disease = "Disease", Poison = "Poison",
    Bleed = "Bleed", Enrage = "Enrage" }

-- The longest template the parser accepts (modules/TextTemplate.lua, rule 8).
C.TEXT_TEMPLATE_MAX = 200

-- The built-in templates the Text page's Template dropdown offers (feedback #5): each a template
-- string and, for the centered one, the justify it needs. TEXT_BUILTIN_SETS lists them per aura type
-- in dropdown order; a stored template matching none reads as Custom (modules/TextTemplate.lua's
-- MatchBuiltin). Every duration run is bracketed, so no built-in leaves text behind on a timeless aura.
C.TEXT_BUILTINS = {
    name           = { template = "$spellname$" },
    nameTime       = { template = "$spellname$[ - $remainingduration$]" },
    nameStacksTime = { template = "$spellname$[ x$stacks$][ - $remainingduration$]" },
    timeOfMax      = { template = "$spellname$[ $remainingduration$ / $maxduration$]" },
    nameType       = { template = "$spellname$[ ($dispeltype$)]" },
    nameTypeTime   = { template = "$spellname$[ ($dispeltype$)][ - $remainingduration$]" },
    -- No " - " separator (feedback #1): Center STACKS this in two rows, and a leading
    -- dash on the second row (" - 11s") is not clean.
    centered       = { template = "$spellname$[$remainingduration$]", justifyH = "CENTER" },
}
C.TEXT_BUILTIN_LABELS = {
    name = "Name", nameTime = "Name + time", nameStacksTime = "Name, stacks, time", timeOfMax = "Time / max",
    nameType = "Name (type)", nameTypeTime = "Name, type, time", centered = "Centered: name over time",
}
C.TEXT_BUILTIN_SETS = {
    HELPFUL = { "name", "nameTime", "nameStacksTime", "timeOfMax", "centered" },
    HARMFUL = { "name", "nameTime", "nameStacksTime", "timeOfMax", "nameType", "nameTypeTime", "centered" },
}

-- The sample aura the Text page's Preview box renders a template against, per aura type: readable,
-- invented values (preview-mode). The buff has stacks and no dispel type; the debuff a type and none.
C.TEXT_SAMPLE_AURAS = {
    HELPFUL = { name = "Ignore Pain", icon = 1377132, remaining = 11, duration = 12, stacks = 3 },
    HARMFUL = { name = "Shadow Word: Pain", icon = 136207, remaining = 11, duration = 16, stacks = 0, dispel = "Magic" },
}

-- Placeholder auras for preview mode (preview-mode), per aura type: real render path, invented data.
-- `name` and `icon` are fallbacks: modules/Preview.lua asks the client for its own by `spellId`, once
-- per session. HARMFUL covers every C.DISPEL_TYPES entry plus one with no type, so the dispel border,
-- the bar tint and the Text dispel word can all be checked (batch 8 TD-1, TD-2). Enrage stays out: it
-- is on enemy buffs, not in the palette, and no debuff container shows it. Each set has one aura under
-- the default running-out threshold, one with stacks and one with no timer.
C.PREVIEW_AURAS = {
    HELPFUL = {
        { spellId = 21562,  name = "Power Word: Fortitude", icon = 135987,  remaining = 3540, duration = 3600, stacks = 0 },
        { spellId = 2825,   name = "Bloodlust",   icon = 136012,  remaining = 28, duration = 40, stacks = 0, dispel = "Magic" },
        { spellId = 871,    name = "Shield Wall", icon = 132362,  remaining = 4,  duration = 8,  stacks = 0 },
        { spellId = 190456, name = "Ignore Pain", icon = 1377132, remaining = 11, duration = 12, stacks = 3 },
        { spellId = 19705,  name = "Well Fed",    icon = 136000,  remaining = 0,  duration = 0,  stacks = 0 },
    },
    HARMFUL = {
        { spellId = 589,    name = "Shadow Word: Pain", icon = 136207, remaining = 11, duration = 16, stacks = 0, dispel = "Magic" },
        { spellId = 51514,  name = "Hex",           icon = 237579, remaining = 42, duration = 60, stacks = 0, dispel = "Curse" },
        { spellId = 55095,  name = "Frost Fever",   icon = 237522, remaining = 18, duration = 24, stacks = 0, dispel = "Disease" },
        { spellId = 2818,   name = "Deadly Poison", icon = 132290, remaining = 9,  duration = 12, stacks = 3, dispel = "Poison" },
        { spellId = 1943,   name = "Rupture",       icon = 132302, remaining = 4,  duration = 24, stacks = 0, dispel = "Bleed" },
        { spellId = 115804, name = "Mortal Wounds", icon = 132355, remaining = 0,  duration = 0,  stacks = 0 },
    },
}
