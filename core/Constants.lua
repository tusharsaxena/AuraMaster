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

-- The General page's Unit, Aura type and Style values, each in its own color so the chosen one reads
-- at a glance, in the closed box and the open list alike (owner, 2026-09-30). The AARRGGBB body of a
-- "|c" escape. Aura types keep the green and red settings/GeneralSpells.lua marks categories with.
C.UNIT_COLORS = { player = "ff66b3ff", target = "ffff8c40", focus = "ffb38cff", pet = "ff66d9a6" }
C.AURA_TYPE_COLORS = { HELPFUL = "ff73bf80", HARMFUL = "ffcc7373" }
C.STYLE_COLORS = { bars = "ffffb366", icons = "ff80d4ff", text = "ffe699e6" }

-- The addon's own AceGUI dropdown type: the stock Dropdown with its closed box justified LEFT
-- (settings/OptionsSetup.lua's NS.RegisterDropdownWidget). Its own name gives it its own pool, so a
-- justification set here never reaches another addon's, or the library's, stock Dropdown.
C.DROPDOWN_WIDGET = "AuraMasterDropdown"

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

-- Filter situations (S5): what a container draws where Blizzard won't apply spell lists, chosen per
-- NPC and per player. "every" is one remainder group, every aura passing the base and not in a
-- Hidden Blizzard-grid category, once; "blizzard" is only the Blizzard categories set to Show.
C.SITUATION_MODES = { "every", "blizzard" }
C.SITUATION_MODE_LABELS = { every = "Every aura, once", blizzard = "Only my Blizzard categories set to Show" }

-- The zones a container shows in (S3): IsInInstance()'s instance types, in display order. A type
-- not listed here (or unreadable) is allowed, since no checkbox exists to untick it.
C.ZONE_KEYS = { "none", "party", "scenario", "raid", "pvp", "arena" }
C.ZONE_LABELS = {
    none = "Open world", party = "Dungeons", scenario = "Scenarios and delves",
    raid = "Raids", pvp = "Battlegrounds", arena = "Arenas",
}

-- The Unit type gate (S6, the addendum): which units a target or focus container shows for. `kind`
-- reads UnitIsPlayer, `reaction` UnitReaction(unit, "player") in three bands (NS.Compat.
-- UnitReactionKind). "all" is no gate. Only the units in UNIT_FILTER_UNITS are gated: a player or
-- pet container is always your own character or pet.
C.UNIT_KINDS = { "all", "npc", "player" }
C.UNIT_KIND_LABELS = { all = "All", npc = "NPCs", player = "Players" }
C.UNIT_REACTIONS = { "all", "friendly", "neutral", "hostile" }
C.UNIT_REACTION_LABELS = { all = "All", friendly = "Friendly", neutral = "Neutral", hostile = "Hostile" }
C.UNIT_FILTER_UNITS = { target = true, focus = true }

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

-- The nine sides of batch 9's edge model (E2), relative to the chain's flow, in order. Since batch
-- 11 a container joins its parent by two absolute points, and a pair that is one of these under the
-- parent's growth keeps that side's seam and spread (modules/Anchors_Attach.lua's AttachEdge, G5); schema
-- v11 converted the stored side to points (core/Database_Migrations.lua).
C.ATTACH_EDGES = {
    "after-start", "after-center", "after-end",
    "ahead-start", "ahead-center", "ahead-end",
    "behind-start", "behind-center", "behind-end",
}

-- Drag to attach (issue #22, D2, D3, A2): a container dropped with its own point of one of the twelve
-- outside pairs within this many UIParent units of the matching point on another one snaps on there.
-- Distances are read in UIParent units (modules/Anchors_Snap.lua), so the radius feels the same
-- under any container or UI scale. The highlight that marks the candidate while it is in range is
-- drawn in the skin's `am.attach` (core/SkinSetup.lua; Ka0s Default's opaque green), so it reads over
-- any bar or icon color.
C.SNAP_RADIUS = 24

-- The detach leeway (issue #22, the owner-feedback addendum's A4): while a container attached to another
-- is dragged, it holds (green on its current pair, and a release snaps it back, writing nothing) while
-- its own point of that pair is at most this many UIParent units from where it rested, or from its
-- parent's, both measured on the two containers' strips (A10); past it, the whole mark (the
-- parent's strip edge, both dots and the line) turns the skin's `am.detach` red and a release detaches it. Wider than
-- C.SNAP_RADIUS, so a grab that barely moves never detaches by accident; 128 since the second smoke
-- round (A9: the first 64 was "way too little").
C.DETACH_RADIUS = 128

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
-- Frame layering (frame-layering-§5): the addon's whole stack, once
-- ---------------------------------------------------------------------------
--
-- Strata picks the tier; within a container everything is a named offset over a base frame's level.
-- Every SetFrameStrata and SetFrameLevel in core/, modules/ and settings/ reads this table
-- (tests/test_layers.lua pins it), except the two the player sets: a container anchor's strata and
-- level are `layout.strata` (C.STRATA, default MEDIUM, STRATA.HUD) and `layout.level`, the base L
-- every container band below counts from.
--
--   tier                 strata                 frames
--   T0 non-visual        none                   BlizzardFrames' hidden parent, the font primer, the
--                                               time-text measurer, event drivers
--   T1p HUD (player)     layout.strata          the anchor at L; the mouse blocker one under the
--                                               engine; the engine, live buttons and preview
--                                               placeholders at L+1 (buttons L+2); the glow twins
--                                               under the main (GLOW_* below); the name label L+20
--   T2 edit chrome       the container's        unlocked outline L+30, drag handle L+50 (+HOP over
--                                               an attach parent's strip)
--   T6 modal             DIALOG (library)       LibKa0s debug console and perf panel; Blizzard's
--                                               StaticPopups (reset all, delete, attach flow, ...)
--   T7 child             FULLSCREEN (library)   the debug console's copy window
--   T8 popup             FULLSCREEN_DIALOG      the drag-time snap highlight (STRATA.POPUP); the
--                                               library's menus, autocomplete and ID suggestions;
--                                               AceGUI pullouts and the color picker
--   T9 cursor            TOOLTIP                the frame picker (STRATA.CURSOR): it labels the frame
--                                               under the cursor, whose own GameTooltip would cover
--                                               it from any lower tier; GameTooltip; LSM pullouts
--
-- Library bands this addon relies on: the DragHandle's help and close marks at handle + 1 (Widgets
-- DragHandle minor 5, born there through `spec.level`) and the Options combat cover over its page.
-- A player can pick DIALOG for a container (a value shipped before frame-layering-§1); the Strata
-- row's tooltip (O.StrataTooltip) says what it then covers.
--
-- Inside one element (an engine button, frame-layering-§3), counted from the element root, never
-- from a sibling: FILL (the bar's StatusBar, the cooldown swipe) < SPARK (the bar's spark clip) <
-- BORDER (our border, the bar's icon border) < DISPEL (the icon's dispel edge) < OVERLAY (the texts,
-- and the pandemic wash on them). The Text style's frames nest instead (each its parent + 1).
--
-- Two documented exceptions, both counted from a frame that is not the parent:
--   * The mouse blocker sits BLOCKER under the engine's CURRENT level (Container:ApplyBlocker),
--     because a later layout.level raises the anchor without the engine following it.
--   * The text-glow twins (modules/Container_Twins.lua) sit under the main engine. A text button
--     nests our frames up to four deep (the text's chain at the button's level + 4, the icon at + 2,
--     modules/Style_Text.lua), so a twin's text draws under the main's icon only with a gap above 2
--     (the twins design note, section 2): the main is raised to at least GLOW_GAP + 1, each twin
--     sits at main - GLOW_GAP and its holder GLOW_HOLDER under that. With L = 5 a holder sits at 2,
--     below the anchor: legal and harmless, since the holders carry glow copies only.
C.LAYERS = {
    STRATA = {
        HUD    = "MEDIUM",              -- T1: the default of every container's layout.strata
        POPUP  = "FULLSCREEN_DIALOG",   -- T8: the snap highlight, over every strata a player can pick
        CURSOR = "TOOLTIP",             -- T9: the frame picker's overlay
    },
    LEVEL = {
        -- one container, over its anchor's level L
        BLOCKER = -1,    -- under the engine's current level (see above)
        CONTENT = 1,     -- the engine, the preview placeholders and extent (implicit, anchor + 1)
        LABEL   = 20,
        OUTLINE = 30,
        HANDLE  = 50,
        HOP     = 1,     -- a child's strip over its attach parent's strip
        -- inside one element, over the element root
        SUNK    = 0,     -- a backdrop host sunk to its border frame's level (modules/Style_Border.lua)
        FILL    = 1,
        SPARK   = 2,
        BORDER  = 3,
        DISPEL  = 4,
        OVERLAY = 5,
        -- the text-glow twins (see above)
        GLOW_GAP    = 3,
        GLOW_HOLDER = -1,
    },
}

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

-- The TEST tag, the panel's muted gold and the strip name of an attached container are skin tokens
-- now (core/SkinSetup.lua: `sem.warn`, `am.goldMuted`, `am.attachedName`), read where they are drawn.

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
-- clamped to, which the Text section's Width row offers too (settings/Text.lua).
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

-- The glow around the text's glyphs (text glow, docs/superpowers/specs/2026-10-16-text-glow-addendum-
-- glyph-glow.md): a ring of glow-colored copies of the text, each `glowThickness` px out along one of
-- the ring's unit directions. Live, each copy is a twin engine of the container's own; on the preview,
-- an addon-written copy string. Under shadow pairing a copy's font string shadow, in the glow color,
-- draws the opposite point of the ring, so four copies draw all eight (owner probe `/amgp twin4s`,
-- 2026-10-16). The first four directions hold one of each opposite pair; the last four are the
-- shadows' under pairing, and copies of their own without it. Flipping the flag is the one-line change.
C.TEXT_GLOW_RING = { { 1, 0 }, { 0, 1 }, { 1, 1 }, { 1, -1 }, { -1, 0 }, { 0, -1 }, { -1, -1 }, { -1, 1 } }
C.TEXT_GLOW_PAIRED = true
C.TEXT_GLOW_TWINS = C.TEXT_GLOW_PAIRED and 4 or 8
-- How far below the main engine its twins sit is C.LAYERS.LEVEL.GLOW_GAP (the layers table above).

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

-- The built-in templates the Text section's Template dropdown offers (feedback #5): each a template
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

-- The sample aura the Text section's Preview box renders a template against, per aura type: readable,
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
    -- A container showing only Weapon enchants (batch 9 SEP-4, E4): one per weapon slot, in slot
    -- order (main hand, off hand, ranged), so it previews enchants, not its parent's buffs.
    ENCHANT = {
        { spellId = 33757,  name = "Windfury Weapon",    icon = 462329, remaining = 1740, duration = 3600, stacks = 0 },
        { spellId = 318038, name = "Flametongue Weapon", icon = 135814, remaining = 4,    duration = 3600, stacks = 0 },
        { spellId = 315584, name = "Instant Poison",     icon = 132273, remaining = 0,    duration = 0,    stacks = 0 },
    },
}
