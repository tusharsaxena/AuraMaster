local _, NS = ...

-- defaults/Presets.lua -- the container presets as data, and the pure builder that turns one into
-- container overrides for a given screen size and style (spec
-- docs/superpowers/specs/2026-11-14-auramaster-presets-design.md, sections 3 and 4).
--
-- WHAT A PRESET IS. A list of { stack, role } pairs in creation order (TIERS). A role (CONTAINERS) is
-- one container's name, unit, aura type, style, enabled state, the categories it hides and the
-- filter and layout fields that differ from the shared base. A stack (STACKS) is a column on the
-- screen: its head is placed on UIParent, and every other container in it attaches to the one created
-- just before it, so a filling container pushes the rest of its stack along. A `beside` stack's head
-- joins another stack's head instead (Player debuffs (all) beside Player buffs (all), spec section 17).
--
-- WHAT IT IS NOT. No appearance media and no spell ids (spec section 3): bars, icons, text and label
-- settings come from NS.CONTAINER_TEMPLATE and the skin, except the column width (a bar's width, an
-- icon row's icon size), so a stack's containers line up, the bar look (a 50% background, debuff
-- bars colored by dispel type, spec section 17.3), and the call-outs' look, which copies the owner's
-- own (spec section 15). Whitelists and blacklists are empty.
--
-- THE SOURCE. Advanced is the owner's Retail Default profile, container by container, transcribed from
-- docs/superpowers/specs/2026-11-14-presets/advanced-source.md with the section 3 changes: plain
-- names numbered in the owner's order (spec section 17.4), growV away from the head ("up" in a side
-- stack, spec section 15), no attach or position (placed here instead), empty spell lists, and the
-- two personal custom categories renamed SPECIAL_PLAYER and SPECIAL_TARGET.
-- tests/test_presets_data.lua holds every role to that document field by field.
--
-- PURE. Build reads its arguments and, for a role that shows only some categories, the live category
-- lists (NS.Categories, at call time): the player's own custom categories are hidden there too, since
-- a key a container does not hold reads as Show (modules/FilterCompiler.lua, splitCategories). For a
-- preset with call-outs it also measures their test-mode block (NS.Preview.BlockSize over the
-- template and the live skin's sizes) to pick their font size and place them. It writes nothing:
-- applying a preset is modules/Presets.lua's, through the registry writers (architecture-§5).

local L = NS.L

local P = {}
NS.PresetData = P

P.NAMES = { "empty", "simple", "intermediate", "advanced", "healer" }
P.LOOKS = { "bars", "icons" }
local IS_LOOK = { bars = true, icons = true }

-- The reference space: offsets and column widths are written for a parent 1080 units tall and scaled
-- by its real height (spec section 4).
P.REF_H = 1080

--- The scale a parent `parentH` units tall places at: parentH / 1080, or 1 when the height cannot be
--- read (nil, 0, not a number: a test environment, a call before the UI is up).
--- @param parentH number|nil
--- @return number
function P.Scale(parentH)
    if type(parentH) ~= "number" or parentH ~= parentH or parentH <= 0 then return 1 end
    return parentH / P.REF_H
end

-- How far the layout reaches across from the center line, in reference units: the TOP-anchored
-- columns either side of it, and the right-hand cluster (every TOPRIGHT column) in from the right
-- edge; and the room kept clear of the screen edge and of the center line. Set from STACKS below.
local TOP_REACH, CLUSTER_REACH, EDGE = 0, 0, 10

--- The horizontal scale on a `parentW` x `parentH` parent: Scale(parentH), shrunk on a screen too
--- narrow for the layout (below about 1.47:1, so 4:3 and 5:4) until the outermost TOP column ends EDGE
--- units in from the edge and the right-hand cluster's left edge, the target column's, stays EDGE
--- units right of the center line (spec section 17), so every head stays on the screen and the
--- cluster on its own half. Unchanged on 16:10 and wider, and when the width cannot be read.
--- @param parentW number|nil
--- @param parentH number|nil
--- @return number
function P.ScaleX(parentW, parentH)
    local k = P.Scale(parentH)
    if type(parentW) ~= "number" or parentW ~= parentW or parentW <= 0 then return k end
    return math.min(k, parentW / (2 * (math.max(TOP_REACH, CLUSTER_REACH) + EDGE)))
end

-- The two custom categories Advanced creates (spec section 3): empty, for the player to fill. The
-- writer resolves `nameKey` through NS.L and maps each key below to the category it created or reused.
P.CUSTOM = {
    SPECIAL_PLAYER = { nameKey = "Special player buffs", auraType = "HELPFUL" },
    SPECIAL_TARGET = { nameKey = "Special target debuffs", auraType = "HARMFUL" },
}
local CUSTOM_ORDER = { "SPECIAL_PLAYER", "SPECIAL_TARGET" }
-- The presets that create them. Every other preset drops a custom key from its states.
local CREATES_CUSTOM = { advanced = true }

--- The CUSTOM key a live category stands for: a custom category of the same name (any case) and aura
--- type, which the writer reuses rather than creating a second (spec section 3); nil for any other.
--- @param def table  a definition from NS.Categories.For
--- @return string|nil
function P.CustomKeyOf(def)
    if type(def) ~= "table" or not def.userCategory or type(def.label) ~= "string" then return nil end
    for _, key in ipairs(CUSTOM_ORDER) do
        local c = P.CUSTOM[key]
        if c.auraType == def.auraType and L[c.nameKey]:lower() == def.label:lower() then return key end
    end
    return nil
end

-- The columns, in reference units (spec sections 4, 15, 16 and 17, the mockup's layout as the owner
-- moved it). `anchor` is the UIParent point the head hangs from; `x` is the column's LEFT edge from
-- that point (from the right edge for TOPRIGHT, from the center line for TOP); `iconsGrowH` is the way
-- an Icons row grows, away from the screen edge the column sits nearest (spec section 3.2): the
-- columns right of center grow left, the rest right (the middle one straddles the center line and
-- grows right). A stack grows down from a head placed by its top at `y`, but for an `up` stack (the
-- side stacks, spec section 15): that grows up from a head placed by its BOTTOM at `y`, the column's
-- base, so the tier's first role sits nearest the unit frames, as in the owner's own profile. The
-- `center` stack (the call-outs) hangs by its top from the center line and has no stored `y`:
-- calloutLayout below centers its test-mode block on the screen's middle, as far as the preset
-- picker above it allows. A `beside` stack's head is not placed: it joins the head of the stack it
-- names by its TOPRIGHT to that head's TOPLEFT (besideAttach), so it takes that head's flow.
-- THE BASE, 740 down (340 above the bottom at 1080 tall), the owner's ruling (spec section 15.1)
-- after 600 and then 640 left Advanced's Bars target stack, six shown containers about 620 tall with
-- their test-mode samples, too little room under the top edge. At 740 it fits a 1080-tall screen
-- locked and unlocked; on a 768-tall one it still runs off the top (docs/known-limitations.md,
-- presets). Tall unit frames or action bars may now reach the base (the same file).
local SIDE_BASE = -740
-- THE FOCUS STACK (spec section 16): the focus roles in a stack of their own, placed on the screen.
-- In the far stack they followed its head, Target debuffs (all), an icon row, and a container
-- attached to another flows by its chain's head (Anchors.EffectiveLayout: axis and both growths), so
-- Advanced's focus bars were laid out across. Its base sits FOCUS_BASE down, high enough over the far
-- stack (which keeps its base) that the two stay more than twice C.SNAP_RADIUS apart in test mode,
-- locked or unlocked, so a drag near the far stack does not snap the focus stack back onto it.
local FOCUS_BASE = -550
-- THE RIGHT-HAND CLUSTER (spec section 17, the owner's "after" layout). Every column that holds bars
-- is COL_W wide, Player cooldowns' (section 17.2), so the edges below line up. From the right edge
-- in: Player buffs (all) with Weapon enchants under it, its right edge EDGE_IN in; Player debuffs
-- (all) joined to its left side by its top right, CORNER_GAP between; the focus stack and, under it,
-- the far stack, on Player debuffs' left edge; and the target stack TARGET_GAP left of that column.
-- All of it hangs from the right edge, so the gaps hold on every screen. EDGE_IN is the least
-- section 17 allows, which keeps the cluster as far from the call-outs as it can be: at 1920 wide its
-- left edge is 1135 across, 175 right of the center line; on 16:9 and narrower the target column
-- still meets the call-out block (docs/known-limitations.md, presets).
local COL_W, EDGE_IN, CORNER_GAP, TARGET_GAP = 240, 10, 5, 50
local CORNER_Y = -46
local CORNER_RIGHT_X = -(EDGE_IN + COL_W)
local FOCUS_X = CORNER_RIGHT_X - CORNER_GAP - COL_W
P.STACKS = {
    cornerRight = { anchor = "TOPRIGHT", x = CORNER_RIGHT_X, y = CORNER_Y, width = COL_W, iconsGrowH = "left" },
    cornerLeft  = { anchor = "TOPRIGHT", x = FOCUS_X, y = CORNER_Y, width = COL_W, iconsGrowH = "left",
        beside = "cornerRight" },
    focus       = { anchor = "TOPRIGHT", x = FOCUS_X, y = FOCUS_BASE, width = COL_W, iconsGrowH = "left", up = true },
    far         = { anchor = "TOPRIGHT", x = FOCUS_X, y = SIDE_BASE, width = COL_W, iconsGrowH = "left", up = true },
    right       = { anchor = "TOPRIGHT", x = FOCUS_X - TARGET_GAP - COL_W, y = SIDE_BASE, width = COL_W,
        iconsGrowH = "left", up = true },
    -- THE CALL-OUT COLUMN, 400 wide (480 before section 17), narrowed so the target column meets it
    -- less: its line sizes to fit its widest test-mode line (Size to fit, the template's), which is
    -- the stored width only where a line cannot be measured, and 400 stays wider than that line at
    -- the owner's 36 (C.PREVIEW_AURAS's longest name, "Power Word: Fortitude"), so narrowing it never
    -- cuts a line. It could go narrower, down to that line's width (section 17); 400 keeps a margin
-- because the harness cannot measure text and the estimate needs an in-game check.
    middle      = { anchor = "TOP",      x = -200, width = 400, iconsGrowH = "right", center = true },
    left        = { anchor = "TOP",      x = -520, y = SIDE_BASE, width = COL_W, iconsGrowH = "right", up = true },
}
for _, stack in pairs(P.STACKS) do
    if stack.anchor == "TOP" then TOP_REACH = math.max(TOP_REACH, -stack.x, stack.x + stack.width) end
    if stack.anchor == "TOPRIGHT" then CLUSTER_REACH = math.max(CLUSTER_REACH, -stack.x) end
end

-- The gap a stack member leaves from the container before it, in reference units, and the icon a
-- bars role turned into an Icons row is sized near (a column fits floor(width / ICON_REF) of them).
local GAP = 6
local ICON_REF = 28

-- THE ROOM AROUND THE CALL-OUTS (spec sections 15 and 15.1), in UIParent units: the windows are not
-- scaled with the layout, so neither is this. The LibKa0s skin picker is centered `skinShare` of the
-- way up UIParent (libs/LibKa0s/OptionsSkinPicker.lua, HEIGHT_SHARE and place()) and about
-- `skinHeight` tall with its media, outline and scope rows (BASE_H and OptionsSkinPickerRows.lua's
-- acquireControls). The preset picker (settings/PresetPicker.lua) opens on the same spot and is
-- given `pickerHeight` (its laid-out height, lock and test buttons included, stays within it). The
-- two never show at once, so the call-out block clears one rectangle there, as tall as the taller of
-- the two; `margin` is kept under it and from the screen's bottom edge.
P.ROOM = { skinShare = 0.75, skinHeight = 334, skinWidth = 308, pickerHeight = 360, pickerWidth = 340,
    margin = 8 }
-- The call-outs' font sizes, largest first: the owner's is 36 (spec section 15).
P.CALLOUT_SIZE_MAX, P.CALLOUT_SIZE_MIN = 36, 24

-- ---------------------------------------------------------------------------
-- The shared base every role starts from (the source's common values)
-- ---------------------------------------------------------------------------

local FILTER = {
    whitelist = {}, blacklist = {},
    castBy = "any", durationMode = "any", maxDuration = 0, hidePermanentEnchants = true,
    sortMethod = "expirationOnly", sortDirection = "reverse", maxAuras = 0,
    situations = { npcs = "every", players = "every" },
    zones = { none = true, party = true, scenario = true, raid = true, pvp = true, arena = true },
    unitFilter = { kind = "all", reaction = "all" },
}

local LAYOUT = {
    axis = "vertical", growH = "right", growV = "down",
    spacing = 0, lineSpacing = 2, perLine = 0,
    scale = 1, alpha = 1, strata = "MEDIUM", level = 5,
}

local BEHAVIOR = {
    tooltips = true, tooltipAnchor = "ANCHOR_BOTTOMLEFT", tooltipInCombat = true,
    clickThrough = false, cancelOnRightClick = true,
}

-- The filter deltas the source repeats.
local MINE_SHORT = { castBy = "mine", durationMode = "timed", maxDuration = 30 }
local MINE_TIMED = { castBy = "mine", durationMode = "timed" }
local TIMED_30 = { durationMode = "timed", maxDuration = 30 }
local NO_PVP = { arena = false, pvp = false }

-- ---------------------------------------------------------------------------
-- Category states: the keys each role hides, as the source lists them
-- ---------------------------------------------------------------------------

-- Every buff and every debuff key the source names, custom keys included. Literal, so the data does
-- not move with the live lists; tests/test_presets_data.lua proves every key exists on both clients.
local ALL_BUFFS = {
    "SPECIAL_PLAYER", "activeMitigation", "bigDefensive", "cancelable", "castable", "defensives",
    "externals", "groupBuffs", "healing", "important", "movement", "offensiveCDs", "racials", "raidCDs",
    "stances", "stealable", "support", "uncategorized", "utility", "weaponEnchants",
}
local ALL_DEBUFFS = {
    "SPECIAL_TARGET", "bleed", "boss", "ccRoot", "ccSnare", "crowdControl", "curse", "disease",
    "dispellable", "dispels", "fromNonPlayers", "fromPlayers", "groupDispellable", "hardCC", "magic",
    "poison", "priority", "racialDebuffs", "raid", "raidInCombat", "role", "uncategorizedDebuffs",
}

--- Every key of the given lists but `keep`.
local function except(lists, keep)
    local skip, out = {}, {}
    for _, k in ipairs(keep) do skip[k] = true end
    for _, list in ipairs(lists) do
        for _, k in ipairs(list) do
            if not skip[k] then out[#out + 1] = k end
        end
    end
    return out
end

local HIDE_ENCHANTS = { "weaponEnchants" }

local function rgb(r, g, b) return { r = r, g = g, b = b, a = 1 } end

--- A call-out's look, the owner's (spec sections 15 and 16): its line centered, in `color` from no
--- skin, the owner's glow exactly (black from no skin, full intensity, 2 px, nudged 1 right and 1
--- down; every glow leaf the template has, so none comes from it), the spell's name alone (a template
--- of more than one piece under Center stacks each field on a row of its own, modules/Style_Text.lua
--- Text.Stacked), and no name label. The owner's list also names a radius, a falloff and a blend,
--- the halo leaves the glyph glow retired, which nothing reads, so none is stored. The font size is
--- calloutLayout's, set at build time.
local function calloutLook(color)
    return {
        text = {
            justifyH = "CENTER", template = "$spellname$",
            font = { fontColor = color, fontColorFromSkin = false, useClassColorFont = false },
            glow = true, glowColor = rgb(0, 0, 0), glowColorFromSkin = false, useClassColorGlow = false,
            glowIntensity = 1, glowThickness = 2, glowX = 1, glowY = -1,
        },
        label = { show = false },
    }
end
-- The owner's three call-out colors.
local LOOK_OFF = calloutLook(rgb(0.1, 1, 0.1))
local LOOK_DEF = calloutLook(rgb(1, 0.125, 0.125))
local LOOK_RAID = calloutLook(rgb(1, 0.486, 0.04))

-- ---------------------------------------------------------------------------
-- The roles
-- ---------------------------------------------------------------------------
-- name, unit, auraType, style; `enabled` false only where the source stores it off; `hide` the keys
-- the source hides (every other key shows); `showOnly` instead hides every live category of the aura
-- type but those; `onlyNamed` (implied by showOnly) marks a role that shows only some categories, so
-- it also hides every custom category of its aura type the player already has, as the source hid the
-- owner's in each of them; `filter` and `layout` the fields that differ from the base above; `look`
-- the appearance a call-out carries (calloutLook).

local CONTAINERS = {
    -- Simple's three (Advanced 1 to 3): the corner, where Blizzard puts buffs.
    pbuffs = { name = L["Player buffs (all)"], unit = "player", auraType = "HELPFUL", style = "bars",
        hide = HIDE_ENCHANTS },
    wpn = { onlyNamed = true, name = L["Weapon enchants"], unit = "player", auraType = "HELPFUL", style = "bars",
        hide = except({ ALL_BUFFS }, { "weaponEnchants" }) },
    pdebuffs = { name = L["Player debuffs (all)"], unit = "player", auraType = "HARMFUL", style = "bars",
        hide = HIDE_ENCHANTS },

    -- The screen-middle call-outs.
    txtOff = { onlyNamed = true, name = L["Offensive cooldowns"], unit = "player", auraType = "HELPFUL", style = "text",
        hide = except({ ALL_BUFFS }, { "offensiveCDs" }), look = LOOK_OFF,
        filter = { sortDirection = "normal" }, layout = { spacing = 2 } },
    txtDef = { onlyNamed = true, name = L["Defensive cooldowns"], unit = "player", auraType = "HELPFUL", style = "text",
        hide = except({ ALL_BUFFS }, { "defensives" }), look = LOOK_DEF,
        filter = { sortDirection = "normal" }, layout = { spacing = 2 } },
    txtRaid = { onlyNamed = true, name = L["Raid cooldowns"], unit = "player", auraType = "HELPFUL", style = "text",
        hide = except({ ALL_BUFFS }, { "raidCDs" }), look = LOOK_RAID,
        filter = { sortDirection = "normal" }, layout = { spacing = 2 } },

    -- The player stack.
    pshort = { name = L["Player buffs, short"], unit = "player", auraType = "HELPFUL", style = "bars",
        hide = HIDE_ENCHANTS, filter = MINE_SHORT },
    pcd = { onlyNamed = true, name = L["Player cooldowns"], unit = "player", auraType = "HELPFUL", style = "bars",
        hide = { "SPECIAL_PLAYER", "bigDefensive", "cancelable", "castable", "externals", "groupBuffs",
            "healing", "important", "racials", "stances", "stealable", "support", "uncategorized",
            "weaponEnchants" },
        filter = TIMED_30 },
    pspec = { onlyNamed = true, name = L["Player special (mine)"], unit = "player", auraType = "HELPFUL", style = "bars",
        hide = except({ ALL_BUFFS }, { "SPECIAL_PLAYER", "stances", "utility" }),
        filter = { castBy = "mine" } },

    -- The target stack.
    tdeb = { name = L["Target debuffs (mine)"], unit = "target", auraType = "HARMFUL", style = "bars",
        hide = HIDE_ENCHANTS, filter = MINE_SHORT },
    tbuff = { name = L["Target buffs (mine)"], unit = "target", auraType = "HELPFUL", style = "bars",
        hide = HIDE_ENCHANTS, filter = MINE_SHORT },
    tcc = { onlyNamed = true, name = L["Target crowd control"], unit = "target", auraType = "HARMFUL", style = "bars",
        hide = except({ ALL_DEBUFFS, HIDE_ENCHANTS }, { "hardCC", "ccRoot" }),
        filter = { durationMode = "timed", maxDuration = 30, zones = NO_PVP } },
    tcdp = { onlyNamed = true, name = L["Target cooldowns, players"], unit = "target", auraType = "HELPFUL", style = "bars",
        hide = { "SPECIAL_PLAYER", "bigDefensive", "cancelable", "castable", "externals", "groupBuffs",
            "healing", "important", "racials", "stances", "stealable", "uncategorized", "weaponEnchants" },
        filter = { durationMode = "timed", maxDuration = 30, unitFilter = { kind = "player" }, zones = NO_PVP } },
    tcdn = { onlyNamed = true, name = L["Target cooldowns, NPCs"], unit = "target", auraType = "HELPFUL", style = "bars",
        hide = { "SPECIAL_PLAYER", "activeMitigation", "defensives", "groupBuffs", "healing", "movement",
            "offensiveCDs", "racials", "raidCDs", "stances", "support", "uncategorized", "utility",
            "weaponEnchants" },
        filter = { durationMode = "timed", unitFilter = { kind = "npc" }, zones = NO_PVP } },
    tspec = { onlyNamed = true, name = L["Target special (mine)"], unit = "target", auraType = "HARMFUL", style = "bars",
        hide = except({ ALL_BUFFS, ALL_DEBUFFS }, { "SPECIAL_TARGET" }),
        filter = { castBy = "mine" } },
    tsteal = { onlyNamed = true, name = L["Target stealable"], unit = "target", auraType = "HELPFUL", style = "bars",
        enabled = false,
        hide = except({ ALL_BUFFS }, { "stealable" }),
        filter = { durationMode = "timed", unitFilter = { kind = "npc", reaction = "hostile" }, zones = NO_PVP } },

    -- The far stack: the target's icon rows. Then the focus stack (spec section 16).
    ticoD = { name = L["Target debuffs (all)"], unit = "target", auraType = "HARMFUL", style = "icons",
        filter = { maxAuras = 16, sortDirection = "normal", zones = { raid = false } },
        layout = { axis = "horizontal", lineSpacing = 0, perLine = 8 } },
    ticoB = { name = L["Target buffs (all)"], unit = "target", auraType = "HELPFUL", style = "icons",
        filter = { maxAuras = 16, sortDirection = "normal", zones = { raid = false } },
        layout = { axis = "horizontal", lineSpacing = 0, perLine = 8 } },
    fdeb = { name = L["Focus debuffs (mine)"], unit = "focus", auraType = "HARMFUL", style = "bars",
        hide = HIDE_ENCHANTS, filter = MINE_TIMED },
    fbuff = { name = L["Focus buffs (mine)"], unit = "focus", auraType = "HELPFUL", style = "bars",
        hide = HIDE_ENCHANTS, filter = MINE_TIMED },

    -- Healer's own (spec section 3.1).
    healTarget = { name = L["Your heals on target"], unit = "target", auraType = "HELPFUL", style = "bars",
        filter = { castBy = "mine" } },
    dispelTarget = { name = L["Dispellable by you on target"], unit = "target", auraType = "HARMFUL",
        style = "bars", showOnly = { "raid" } },
    healFocus = { name = L["Your heals on focus"], unit = "focus", auraType = "HELPFUL", style = "bars",
        filter = { castBy = "mine" } },
    dispelFocus = { name = L["Dispellable by you on focus"], unit = "focus", auraType = "HARMFUL",
        style = "bars", showOnly = { "raid" } },
}

--- The keys both lists hold.
local function intersect(a, b)
    local inB, out = {}, {}
    for _, k in ipairs(b) do inB[k] = true end
    for _, k in ipairs(a) do
        if inB[k] then out[#out + 1] = k end
    end
    return out
end

-- Intermediate's "Target cooldowns" merges Advanced's two (spec section 3): every unit kind, every
-- zone, the union of what the two show (so the keys both hide), and no duration cap (the NPC one has
-- none; the union keeps the wider of the two).
CONTAINERS.tcd = {
    name = L["Target cooldowns"], unit = "target", auraType = "HELPFUL", style = "bars", onlyNamed = true,
    hide = intersect(CONTAINERS.tcdp.hide, CONTAINERS.tcdn.hide),
    filter = { durationMode = "timed" },
}

-- Healer's Player cooldowns: Advanced's, with Healing and Raid cooldowns shown as well (spec 3.1).
CONTAINERS.pcdHealer = {
    name = CONTAINERS.pcd.name, unit = "player", auraType = "HELPFUL", style = "bars", onlyNamed = true,
    hide = except({ CONTAINERS.pcd.hide }, { "healing", "raidCDs" }),
    filter = TIMED_30,
}

-- The presets, each a list of { stack, role } in creation order (spec section 3's table, the mockup's
-- stacks). A stack's first entry is its head. Creation order is the owner's numbering (spec section
-- 17.4, advanced-source.md's brackets), which Build writes in front of each name: a preset with fewer
-- containers keeps the relative order and numbers 1..N, and a role the owner's profile lacks takes
-- the slot of the one it stands in for (Healer's Player cooldowns at Player cooldowns, its target and
-- focus roles at Target and Focus debuffs (mine), Intermediate's Target cooldowns at Target
-- cooldowns, players). Advanced's Target stealable (15) is created before Target special (16), so it
-- sits under it in the target stack.
local SIMPLE = { { "cornerRight", "pbuffs" }, { "cornerRight", "wpn" }, { "cornerLeft", "pdebuffs" } }

--- `SIMPLE` followed by `more`.
local function simplePlus(more)
    local out = {}
    for _, e in ipairs(SIMPLE) do out[#out + 1] = e end
    for _, e in ipairs(more) do out[#out + 1] = e end
    return out
end

local TIERS = {
    empty = {},
    simple = SIMPLE,
    intermediate = simplePlus({
        { "left", "pshort" }, { "left", "pcd" },
        { "right", "tdeb" }, { "right", "tcd" },
        { "focus", "fdeb" },
    }),
    advanced = simplePlus({
        { "middle", "txtOff" }, { "middle", "txtDef" }, { "middle", "txtRaid" },
        { "left", "pshort" }, { "left", "pcd" }, { "left", "pspec" },
        { "right", "tdeb" }, { "right", "tbuff" }, { "right", "tcc" }, { "right", "tcdp" },
        { "right", "tcdn" }, { "right", "tsteal" }, { "right", "tspec" },
        { "far", "ticoD" }, { "far", "ticoB" },
        { "focus", "fdeb" }, { "focus", "fbuff" },
    }),
    healer = simplePlus({
        { "middle", "txtRaid" },
        { "left", "pcdHealer" },
        { "right", "healTarget" }, { "right", "dispelTarget" },
        { "focus", "healFocus" }, { "focus", "dispelFocus" },
    }),
}

--- How many containers preset `name` creates; 0 for Empty and for a name that is not a preset.
--- @param name string
--- @return number
function P.Count(name)
    local tier = TIERS[name]
    return tier and #tier or 0
end

--- Whether applying preset `name` creates the CUSTOM categories.
--- @param name string
--- @return boolean
function P.CreatesCustom(name)
    return CREATES_CUSTOM[name] == true
end

-- ---------------------------------------------------------------------------
-- The builder
-- ---------------------------------------------------------------------------

local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = copy(x) end
    return out
end

local function merge(dst, src)
    for k, v in pairs(src or {}) do
        if type(v) == "table" and type(dst[k]) == "table" then merge(dst[k], v) else dst[k] = copy(v) end
    end
    return dst
end

local function round(v) return math.floor(v + 0.5) end

--- Whether live custom category `def` is the one a preset that creates the custom categories reuses
--- for a CUSTOM key. A name match (P.CustomKeyOf) is; with `picked` ([CUSTOM key] = the key the writer
--- chose), only the chosen one is, so a second category of the same name is hidden like any other
--- custom category (spec section 3).
local function isReused(def, withCustom, picked)
    local customKey = withCustom and P.CustomKeyOf(def)
    if not customKey then return false end
    return picked == nil or picked[customKey] == nil or picked[customKey] == def.key
end

--- State, in `out`, the live categories of `role`'s aura type for a role that shows only some: for a
--- `showOnly` role every shipped one (Show for the keys it names, Hide for the rest), and for it or an
--- `onlyNamed` role every custom one as Hide. With `withCustom`, a live category the preset reuses
--- (isReused) is left to its CUSTOM key, which the role's own list states.
local function hideLive(out, role, withCustom, picked)
    if not (role.showOnly or role.onlyNamed) then return end
    local shown = {}
    for _, key in ipairs(role.showOnly or {}) do shown[key] = true end
    for _, def in ipairs(NS.Categories.For(role.auraType)) do
        if def.userCategory then
            if not isReused(def, withCustom, picked) then out[def.key] = "hide" end
        elseif role.showOnly then
            out[def.key] = shown[def.key] and "show" or "hide"
        end
    end
end

--- A role's category states. Hidden keys read "hide". A preset that creates the custom categories
--- states both in every container, so the writer's order of creation cannot change what shows; any
--- other preset names neither. A role showing only some categories hides the player's own as well.
local function categoriesFor(role, withCustom, picked)
    local out = {}
    hideLive(out, role, withCustom, picked)
    for _, key in ipairs(role.hide or {}) do
        if withCustom or not P.CUSTOM[key] then out[key] = "hide" end
    end
    if withCustom then
        for _, key in ipairs(CUSTOM_ORDER) do
            if out[key] == nil then out[key] = "show" end
        end
    end
    return out
end

--- A role's overrides before placement: a fresh copy, never shared with the data.
local function overridesFor(role, withCustom, picked)
    local o = {
        name = role.name, unit = role.unit, auraType = role.auraType, style = role.style,
        enabled = role.enabled ~= false,
        filter = merge(copy(FILTER), role.filter),
        layout = merge(copy(LAYOUT), role.layout),
        behavior = copy(BEHAVIOR),
    }
    o.filter.categories = categoriesFor(role, withCustom, picked)
    if role.look then
        o.text = copy(role.look.text)
        o.label = copy(role.look.label)
    end
    return o
end

--- A role's overrides in `stack`: an up stack's containers grow up from its base.
local function growthIn(o, stack)
    if stack.up then o.layout.growV = "up" end
end

--- The Icons variant of a bars role (spec section 3.2): an icon row growing away from the nearest
--- screen edge, as many icons per line as the column fits. Text and icon roles are unchanged.
local function toIcons(o, stack)
    if o.style ~= "bars" then return end
    o.style = "icons"
    o.layout.axis = "horizontal"
    o.layout.growH = stack.iconsGrowH
    o.layout.perLine = math.max(1, math.floor(stack.width / ICON_REF))
end

-- THE BAR LOOK (spec section 17.3), on every bars container, both fields written so neither the
-- template nor a skin decides them: the background 50% opaque (bars.bgAlpha, Background opacity), and
-- Fill > Color by (bars.colorMode) By dispel type on a debuff bar, One color on a buff bar.
local BAR_BG_ALPHA = 0.5

--- The column width, scaled: a bar's width, or an icon row's icon size (its line fills the column). A
--- text line's stored width is the column too, which stands when Size to fit is off or cannot measure;
--- with it on (the template's) a call-out line is as wide as its content, centered on the center
--- line its head hangs from (place): the line is justified CENTER and its template one piece
--- (calloutLook). The width runs between the column's two edges, each rounded as `place` rounds a
--- head's offset, so a corner column ends on the screen's right edge at any scale.
local function sizeTo(o, stack, kx)
    local w = round((stack.x + stack.width) * kx) - round(stack.x * kx)
    if o.style == "bars" then
        o.bars = { width = w, bgAlpha = BAR_BG_ALPHA, colorMode = (o.auraType == "HARMFUL") and "dispel" or "static" }
    elseif o.style == "text" then
        o.text = o.text or {}
        o.text.width = w
    elseif o.style == "icons" then
        local perLine = (o.layout.perLine > 0) and o.layout.perLine or 1
        local px = math.max(1, math.floor(w / perLine) - o.layout.spacing)
        o.icons = { width = px, height = px }
    end
end

--- A head's screen placement, `kx` across and `k` down. A row growing left hangs by its right corner
--- from the column's right edge, so it fills toward the screen; every other head by its left corner
--- from the left edge. That is the top corner, but for an up stack's head, which sits on the column's
--- base by its bottom corner. The center stack's head hangs by its TOP from the center line, `top`
--- units down (calloutLayout).
local function place(o, stack, kx, k, top)
    o.attach = { mode = "screen", container = 0, frame = "" }
    if stack.center then
        o.position = { point = "TOP", relativePoint = stack.anchor, x = 0, y = -top }
        return
    end
    local left = o.layout.growH == "left"
    local x = left and (stack.x + stack.width) or stack.x
    o.position = {
        point = (stack.up and "BOTTOM" or "TOP") .. (left and "RIGHT" or "LEFT"), relativePoint = stack.anchor,
        x = round(x * kx), y = round(stack.y * k),
    }
end

--- A `beside` stack's head's attachment to the head of the stack it names (spec section 17): its TOP
--- RIGHT to that head's TOP LEFT, two explicit points (the panel's "Its Top right joins the Top left"),
--- so it takes that head's flow (Anchors.EffectiveLayout) and sits on its left. The join is one of the
--- nine sides under that flow (behind-start for a bars column, ahead-start for a row growing left), so
--- its seam already leaves the container's own gap across (Anchors.SeamOffset: its line spacing
--- between columns, its spacing along a row); the nudge makes up the rest of `gap`, the pixels between
--- the two columns as they are rounded. `container` is the writer's to fill with the new id.
local function besideAttach(o, gap)
    local lay = o.layout
    local seam = (lay.axis == "horizontal") and lay.spacing or lay.lineSpacing
    return { mode = "container", container = 0, frame = "", childPoint = "TOPRIGHT", relPoint = "TOPLEFT",
        x = -math.max(0, gap - seam), y = 0 }
end

--- The pixels between a `beside` stack's column and the column of the stack it names, each edge
--- rounded as `place` rounds a head's offset.
local function besideGap(stack, kx)
    local to = P.STACKS[stack.beside]
    return round(to.x * kx) - round((stack.x + stack.width) * kx)
end

--- A stack member's attachment to the container before it. Its join points are left Automatic
--- (modules/Anchors_Attach.lua), so they follow the stack's growth: below the parent growing down,
--- above it growing up (bottom-left to top-left, bottom-right to top-right for a row growing left),
--- from the side its lines start; a centered call-out joins its parent's center. The gap is away from
--- the parent, along the growth. `container` is the writer's to fill with the new id.
local function memberAttach(k, up)
    local gap = math.max(1, round(GAP * k))
    if up then
        return { mode = "container", container = 0, frame = "",
            point = "BOTTOMLEFT", relativePoint = "TOPLEFT", x = 0, y = gap }
    end
    return { mode = "container", container = 0, frame = "",
        point = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = 0, y = -gap }
end

-- ---------------------------------------------------------------------------
-- The call-out block in test mode (spec section 15)
-- ---------------------------------------------------------------------------

--- Set call-out data `o` (overrides or the full stored data) to font size `size`, its stored line
--- height to what Size to fit draws that size at (modules/Style_Text.lua, fitHeight: the size and a
--- pad above and below), so the block measures the same where a line cannot be measured (the
--- headless harness) and the height stands in for it if it ever cannot be in game.
local function setSize(o, size)
    o.text.font.fontSize = size
    o.text.height = size + 2 * NS.Constants.TEXT_AUTOSIZE_PAD
end

--- The block the center stack's specs (`specs`, in order) fill in test mode at font size `size`,
--- UNLOCKED, as the preset picker opens them (spec section 15): its width (its widest container) and
--- height (each container as tall as Preview.BlockSize makes its placeholder block, the next hung
--- below it across the seam: its stored gap, the seam's own, Anchors.SeamOffset, and the room its
--- drag strip takes, one Anchors.STRIP_ROW, modules/Anchors_Attach.lua seamRoom), with the head's
--- own strip row above it all. That row is `strip`, how far the head's block starts below the
--- block's top. A call-out shows no name label (calloutLook), so no label row. The full stored data
--- is the template plus the overrides, as NS.Database.NewContainerData builds it. Read at call time:
--- modules/ load after this file.
--- @return number width, number height, number strip
local function measureCallouts(specs, size)
    local strip = NS.Anchors.STRIP_ROW
    local width, height = 0, strip
    for i, spec in ipairs(specs) do
        local cfg = merge(copy(NS.CONTAINER_TEMPLATE), spec.overrides)
        setSize(cfg, size)
        local w, h = NS.Preview.BlockSize(cfg)
        if i > 1 then
            local _, seam = NS.Anchors.SeamOffset(cfg.layout, "after")
            height = height + math.abs(cfg.attach.y or 0) + math.abs(seam) + strip
        end
        width, height = math.max(width, w), height + h
    end
    return width, height, strip
end

--- Where the call-out block may sit on a `parentH` tall parent, as offsets down from its top edge:
--- below the pickers' shared rectangle (spec section 15.1), and above the screen's bottom edge.
local function calloutRoom(parentH)
    local R = P.ROOM
    local pickersBottom = parentH * (1 - R.skinShare) + math.max(R.skinHeight, R.pickerHeight) / 2
    return pickersBottom + R.margin, parentH - R.margin
end

--- The call-outs' font size and the block's top (down from the parent's top edge) for the center
--- stack's specs on a `parentH` tall parent, and the block's width and height in test mode. The
--- largest size from CALLOUT_SIZE_MAX down to CALLOUT_SIZE_MIN whose block fits the room
--- (calloutRoom), the block centered on the screen's middle as far as the room allows: moved down
--- before the font shrinks. When none fits, the smallest, just under the pickers, and no lower
--- than keeps it on the screen. `strip` is measureCallouts': the head's block starts that far below
--- the block's top.
--- @return number size, number top, number width, number height, number strip
local function calloutLayout(specs, parentH)
    local lo, hi = calloutRoom(parentH)
    local w, h, strip
    for size = P.CALLOUT_SIZE_MAX, P.CALLOUT_SIZE_MIN, -1 do
        w, h, strip = measureCallouts(specs, size)
        if h <= hi - lo then
            local top = math.min(math.max(parentH / 2 - h / 2, lo), hi - h)
            return size, round(top), w, h, strip
        end
    end
    local top = math.max(P.ROOM.margin, math.min(lo, parentH - P.ROOM.margin - h))
    return P.CALLOUT_SIZE_MIN, round(top), w, h, strip
end

--- `parentH`, or the reference height when it cannot be read (P.Scale's fallback).
local function heightOr(parentH)
    return (P.Scale(parentH) == 1) and P.REF_H or parentH
end

--- Size and place the center stack's specs (`callouts`, in order) on a `parentH` tall parent (1080
--- when it cannot be read): every line at calloutLayout's font size, the head's top where it puts
--- the block, one strip row below the block's top (its own strip sits there while unlocked). The
--- head's spec keeps the block's unlocked test-mode size and top as `calloutBlock`.
local function placeCallouts(callouts, parentH)
    local size, top, w, h, strip = calloutLayout(callouts, heightOr(parentH))
    for _, spec in ipairs(callouts) do setSize(spec.overrides, size) end
    callouts[1].overrides.position.y = -(top + strip)
    callouts[1].calloutBlock = { width = w, height = h, top = top, fontSize = size }
end

--- The containers preset `name` in style `look` creates on a `parentW` x `parentH` parent, in creation
--- order. Each spec is { role, stack, overrides, attachTo, customKeys, calloutBlock }: `overrides`
--- is a table for NS.ContainerManager.Create; `attachTo` the index of the spec this one attaches to (nil for a
--- stack's head); `customKeys` the CUSTOM keys its states name (nil when the preset creates none);
--- `calloutBlock`, on the call-outs' head alone, their block in test mode (placeCallouts).
--- Heads hang from the parent's top edge and center line; the width only narrows the layout across
--- (P.ScaleX) on a screen too narrow for it. `picked` ([CUSTOM key] = live key, the writer's
--- resolution) narrows the reuse to those keys: without it every name match is taken as reused. An
--- unknown name or look builds nothing.
--- @param name string
--- @param look string  "bars" | "icons"
--- @param parentW number|nil
--- @param parentH number|nil
--- @param picked table|nil
--- @return table
function P.Build(name, look, parentW, parentH, picked)
    local tier = TIERS[name]
    if not (tier and IS_LOOK[look]) then return {} end
    local k, kx, withCustom = P.Scale(parentH), P.ScaleX(parentW, parentH), CREATES_CUSTOM[name] == true
    local specs, last, first, callouts = {}, {}, {}, {}
    for i, entry in ipairs(tier) do
        local stackKey, roleKey = entry[1], entry[2]
        local stack = P.STACKS[stackKey]
        local o = overridesFor(CONTAINERS[roleKey], withCustom, picked)
        o.name = ("[%d] %s"):format(i, o.name)   -- the owner's numbering, not localized (spec 17.4)
        if look == "icons" then toIcons(o, stack) end
        growthIn(o, stack)
        sizeTo(o, stack, kx)
        local spec = { role = roleKey, stack = stackKey, overrides = o }
        if last[stackKey] then
            spec.attachTo = last[stackKey]
            o.attach = memberAttach(k, stack.up)
        elseif stack.beside and first[stack.beside] then
            spec.attachTo = first[stack.beside]
            o.attach = besideAttach(o, besideGap(stack, kx))
        else
            place(o, stack, kx, k, 0)
        end
        first[stackKey] = first[stackKey] or i
        if stack.center then callouts[#callouts + 1] = spec end
        if withCustom then spec.customKeys = copy(CUSTOM_ORDER) end
        last[stackKey] = i
        specs[i] = spec
    end
    if callouts[1] then placeCallouts(callouts, parentH) end
    return specs
end

--- The center stack's test-mode rectangle for preset `name` in style `look` on a `parentW` x
--- `parentH` parent (1920 x 1080 when either cannot be read), in UIParent's own coordinates (from its
--- bottom-left corner, as Frame:GetRect reads): { left, right, top, bottom, width, height, fontSize }.
--- It is the UNLOCKED block, drag strips included (measureCallouts), as the preset picker opens it; a
--- locked block is the same less its strip rows, so it fits inside. nil for a preset with no
--- call-outs. What clears the preset picker's rectangle (spec section 15.1).
--- @return table|nil
function P.CalloutRect(name, look, parentW, parentH)
    local W = (type(parentW) == "number" and parentW > 0) and parentW or 1920
    local H = heightOr(parentH)
    for _, spec in ipairs(P.Build(name, look, W, H)) do
        local b = spec.calloutBlock
        if b then
            return {
                left = W / 2 - b.width / 2, right = W / 2 + b.width / 2,
                top = H - b.top, bottom = H - b.top - b.height,
                width = b.width, height = b.height, fontSize = b.fontSize,
            }
        end
    end
    return nil
end

--- Store each CUSTOM placeholder state in `categories` under the key it resolved to (`keys`,
--- [CUSTOM key] = live key).
local function rekey(categories, keys)
    for customKey, key in pairs(keys) do
        local state = categories[customKey]
        if state ~= nil then
            categories[customKey] = nil
            categories[key] = state
        end
    end
end

--- Hand every spec Build returned, in order, to `create(overrides) -> id | nil, message, gray`, with
--- its placeholder states rekeyed through `keys` and a member's attach naming the id `create`
--- returned for the spec above it. The one walk both writers share: modules/Presets.lua's Apply passes
--- NS.ContainerManager.Create, and core/Database.lua's first-run seeding a writer of its own over the
--- profile being prepared, so a seeded profile holds exactly what applying the preset writes. Stops at
--- the first refusal and answers it.
--- @param specs table  from P.Build
--- @param keys table|nil  [CUSTOM key] = live key
--- @param create function
--- @return number|nil created, string|nil message, boolean|nil gray
function P.Realize(specs, keys, create)
    local ids = {}
    for i, spec in ipairs(specs) do
        local o = spec.overrides
        rekey(o.filter.categories, keys or {})
        if spec.attachTo then o.attach.container = ids[spec.attachTo] end
        local id, msg, gray = create(o)
        if not id then return nil, msg, gray end
        ids[i] = id
    end
    return #ids
end
