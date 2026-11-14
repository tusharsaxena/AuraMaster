local _, NS = ...

-- defaults/Presets.lua -- the container presets as data, and the pure builder that turns one into
-- container overrides for a given screen height and style (spec
-- docs/superpowers/specs/2026-11-14-auramaster-presets-design.md, sections 3 and 4).
--
-- WHAT A PRESET IS. A list of { stack, role } pairs in creation order (TIERS). A role (CONTAINERS) is
-- one container's name, unit, aura type, style, enabled state, the categories it hides and the
-- filter and layout fields that differ from the shared base. A stack (STACKS) is a column on the
-- screen: its head is placed on UIParent, and every other container in it attaches to the one created
-- just before it, so a filling container pushes the rest of its stack down.
--
-- WHAT IT IS NOT. No appearance media and no spell ids (spec section 3): bars, icons, text and label
-- settings come from NS.CONTAINER_TEMPLATE and the skin, except the column width (a bar's width, an
-- icon row's icon size), so a stack's containers line up. Whitelists and blacklists are empty.
--
-- THE SOURCE. Advanced is the owner's Retail Default profile, container by container, transcribed from
-- docs/superpowers/specs/2026-11-14-presets/advanced-source.md with the section 3 changes: plain
-- names, growV "down", no attach or position (placed here instead), empty spell lists, and the two
-- personal custom categories renamed SPECIAL_PLAYER and SPECIAL_TARGET. tests/test_presets_data.lua
-- holds every role to that document field by field.
--
-- PURE. Build reads its arguments and, for a role that shows only some categories, the live category
-- lists (NS.Categories, at call time). It writes nothing: applying a preset is modules/Presets.lua's,
-- through the registry writers (architecture-§5).

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

-- The two custom categories Advanced creates (spec section 3): empty, for the player to fill. The
-- writer resolves `nameKey` through NS.L and maps each key below to the category it created or reused.
P.CUSTOM = {
    SPECIAL_PLAYER = { nameKey = "Special player buffs", auraType = "HELPFUL" },
    SPECIAL_TARGET = { nameKey = "Special target debuffs", auraType = "HARMFUL" },
}
local CUSTOM_ORDER = { "SPECIAL_PLAYER", "SPECIAL_TARGET" }
-- The presets that create them. Every other preset drops a custom key from its states.
local CREATES_CUSTOM = { advanced = true }

-- The columns, in reference units (spec section 4, the mockup's layout). `anchor` is the UIParent
-- point the head hangs from; `x` is the column's LEFT edge from that point (from the right edge for
-- TOPRIGHT, from the center line for TOP) and `y` its top; `iconsGrowH` is the way an Icons row grows,
-- away from the screen edge the column sits nearest.
P.STACKS = {
    cornerRight = { anchor = "TOPRIGHT", x = -175, y = -6,   width = 175, iconsGrowH = "left" },
    cornerLeft  = { anchor = "TOPRIGHT", x = -395, y = -6,   width = 215, iconsGrowH = "left" },
    middle      = { anchor = "TOP",      x = -240, y = -200, width = 480, iconsGrowH = "right" },
    left        = { anchor = "TOP",      x = -520, y = -330, width = 240, iconsGrowH = "right" },
    right       = { anchor = "TOP",      x = 280,  y = -330, width = 240, iconsGrowH = "right" },
    far         = { anchor = "TOP",      x = 570,  y = -330, width = 220, iconsGrowH = "right" },
}

-- The gap a stack member leaves below the container above it, in reference units, and the icon a
-- bars role turned into an Icons row is sized near (a column fits floor(width / ICON_REF) of them).
local GAP = 6
local ICON_REF = 28

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

-- ---------------------------------------------------------------------------
-- The roles
-- ---------------------------------------------------------------------------
-- name, unit, auraType, style; `enabled` false only where the source stores it off; `hide` the keys
-- the source hides (every other key shows); `showOnly` instead hides every live category of the aura
-- type but those; `filter` and `layout` the fields that differ from the base above.

local CONTAINERS = {
    -- Simple's three (Advanced 1 to 3): the corner, where Blizzard puts buffs.
    pbuffs = { name = L["Player buffs (all)"], unit = "player", auraType = "HELPFUL", style = "bars",
        hide = HIDE_ENCHANTS },
    wpn = { name = L["Weapon enchants"], unit = "player", auraType = "HELPFUL", style = "bars",
        hide = except({ ALL_BUFFS }, { "weaponEnchants" }) },
    pdebuffs = { name = L["Player debuffs (all)"], unit = "player", auraType = "HARMFUL", style = "bars",
        hide = HIDE_ENCHANTS },

    -- The screen-middle call-outs.
    txtOff = { name = L["Offensive cooldowns"], unit = "player", auraType = "HELPFUL", style = "text",
        hide = except({ ALL_BUFFS }, { "offensiveCDs" }),
        filter = { sortDirection = "normal" }, layout = { spacing = 2 } },
    txtDef = { name = L["Defensive cooldowns"], unit = "player", auraType = "HELPFUL", style = "text",
        hide = except({ ALL_BUFFS }, { "defensives" }),
        filter = { sortDirection = "normal" }, layout = { spacing = 2 } },
    txtRaid = { name = L["Raid cooldowns"], unit = "player", auraType = "HELPFUL", style = "text",
        hide = except({ ALL_BUFFS }, { "raidCDs" }),
        filter = { sortDirection = "normal" }, layout = { spacing = 2 } },

    -- The player stack.
    pshort = { name = L["Player buffs, short"], unit = "player", auraType = "HELPFUL", style = "bars",
        hide = HIDE_ENCHANTS, filter = MINE_SHORT },
    pcd = { name = L["Player cooldowns"], unit = "player", auraType = "HELPFUL", style = "bars",
        hide = { "SPECIAL_PLAYER", "bigDefensive", "cancelable", "castable", "externals", "groupBuffs",
            "healing", "important", "racials", "stances", "stealable", "support", "uncategorized",
            "weaponEnchants" },
        filter = TIMED_30 },
    pspec = { name = L["Player special (mine)"], unit = "player", auraType = "HELPFUL", style = "bars",
        hide = except({ ALL_BUFFS }, { "SPECIAL_PLAYER", "stances", "utility" }),
        filter = { castBy = "mine" } },

    -- The target stack.
    tdeb = { name = L["Target debuffs (mine)"], unit = "target", auraType = "HARMFUL", style = "bars",
        hide = HIDE_ENCHANTS, filter = MINE_SHORT },
    tbuff = { name = L["Target buffs (mine)"], unit = "target", auraType = "HELPFUL", style = "bars",
        hide = HIDE_ENCHANTS, filter = MINE_SHORT },
    tcc = { name = L["Target crowd control"], unit = "target", auraType = "HARMFUL", style = "bars",
        hide = except({ ALL_DEBUFFS, HIDE_ENCHANTS }, { "hardCC", "ccRoot" }),
        filter = { durationMode = "timed", maxDuration = 30, zones = NO_PVP } },
    tcdp = { name = L["Target cooldowns, players"], unit = "target", auraType = "HELPFUL", style = "bars",
        hide = { "SPECIAL_PLAYER", "bigDefensive", "cancelable", "castable", "externals", "groupBuffs",
            "healing", "important", "racials", "stances", "stealable", "uncategorized", "weaponEnchants" },
        filter = { durationMode = "timed", maxDuration = 30, unitFilter = { kind = "player" }, zones = NO_PVP } },
    tcdn = { name = L["Target cooldowns, NPCs"], unit = "target", auraType = "HELPFUL", style = "bars",
        hide = { "SPECIAL_PLAYER", "activeMitigation", "defensives", "groupBuffs", "healing", "movement",
            "offensiveCDs", "racials", "raidCDs", "stances", "support", "uncategorized", "utility",
            "weaponEnchants" },
        filter = { durationMode = "timed", unitFilter = { kind = "npc" }, zones = NO_PVP } },
    tspec = { name = L["Target special (mine)"], unit = "target", auraType = "HARMFUL", style = "bars",
        hide = except({ ALL_BUFFS, ALL_DEBUFFS }, { "SPECIAL_TARGET" }),
        filter = { castBy = "mine" } },
    tsteal = { name = L["Target stealable"], unit = "target", auraType = "HELPFUL", style = "bars",
        enabled = false,
        hide = except({ ALL_BUFFS }, { "stealable" }),
        filter = { durationMode = "timed", unitFilter = { kind = "npc", reaction = "hostile" }, zones = NO_PVP } },

    -- The far stack: the target's icon rows, then focus.
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
    name = L["Target cooldowns"], unit = "target", auraType = "HELPFUL", style = "bars",
    hide = intersect(CONTAINERS.tcdp.hide, CONTAINERS.tcdn.hide),
    filter = { durationMode = "timed" },
}

-- Healer's Player cooldowns: Advanced's, with Healing and Raid cooldowns shown as well (spec 3.1).
CONTAINERS.pcdHealer = {
    name = CONTAINERS.pcd.name, unit = "player", auraType = "HELPFUL", style = "bars",
    hide = except({ CONTAINERS.pcd.hide }, { "healing", "raidCDs" }),
    filter = TIMED_30,
}

-- The presets, each a list of { stack, role } in creation order (spec section 3's table, the mockup's
-- stacks). A stack's first entry is its head.
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
        { "far", "fdeb" },
    }),
    advanced = simplePlus({
        { "middle", "txtOff" }, { "middle", "txtDef" }, { "middle", "txtRaid" },
        { "left", "pshort" }, { "left", "pcd" }, { "left", "pspec" },
        { "right", "tdeb" }, { "right", "tbuff" }, { "right", "tcc" }, { "right", "tcdp" },
        { "right", "tcdn" }, { "right", "tspec" }, { "right", "tsteal" },
        { "far", "ticoD" }, { "far", "ticoB" }, { "far", "fdeb" }, { "far", "fbuff" },
    }),
    healer = simplePlus({
        { "middle", "txtRaid" },
        { "left", "pcdHealer" },
        { "right", "healTarget" }, { "right", "dispelTarget" },
        { "far", "healFocus" }, { "far", "dispelFocus" },
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

--- A role's category states. Hidden keys read "hide". A preset that creates the custom categories
--- states both in every container, so the writer's order of creation cannot change what shows; any
--- other preset names neither.
local function categoriesFor(role, withCustom)
    local out = {}
    if role.showOnly then
        for _, def in ipairs(NS.Categories.For(role.auraType)) do
            if not def.userCategory then out[def.key] = "hide" end
        end
        for _, key in ipairs(role.showOnly) do
            if out[key] then out[key] = "show" end
        end
    end
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
local function overridesFor(role, withCustom)
    local o = {
        name = role.name, unit = role.unit, auraType = role.auraType, style = role.style,
        enabled = role.enabled ~= false,
        filter = merge(copy(FILTER), role.filter),
        layout = merge(copy(LAYOUT), role.layout),
        behavior = copy(BEHAVIOR),
    }
    o.filter.categories = categoriesFor(role, withCustom)
    return o
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

--- The column width, scaled: a bar's width, or an icon row's icon size (its line fills the column).
local function sizeTo(o, stack, k)
    local w = stack.width * k
    if o.style == "bars" then
        o.bars = { width = round(w) }
    elseif o.style == "icons" then
        local perLine = (o.layout.perLine > 0) and o.layout.perLine or 1
        local px = math.max(1, math.floor(w / perLine) - o.layout.spacing)
        o.icons = { width = px, height = px }
    end
end

--- A head's screen placement. A row growing left hangs by its top-right corner from the column's
--- right edge, so it fills toward the screen; every other head by its top-left from the left edge.
local function place(o, stack, k)
    local left = o.layout.growH == "left"
    local x = left and (stack.x + stack.width) or stack.x
    o.position = {
        point = left and "TOPRIGHT" or "TOPLEFT", relativePoint = stack.anchor,
        x = round(x * k), y = round(stack.y * k),
    }
    o.attach = { mode = "screen", container = 0, frame = "" }
end

--- A stack member's attachment to the container above it. Its join points are left Automatic
--- (modules/Anchors_Attach.lua): below the parent, from the side its lines start, which is top-left to
--- bottom-left under the stack's growth. `container` is the writer's to fill with the new id.
local function memberAttach(k)
    return {
        mode = "container", container = 0, frame = "",
        point = "TOPLEFT", relativePoint = "BOTTOMLEFT",
        x = 0, y = -math.max(1, round(GAP * k)),
    }
end

--- The containers preset `name` in style `look` creates on a parent `parentH` units tall, in creation
--- order. Each spec is { role, stack, overrides, attachTo, customKeys }: `overrides` is a table for
--- NS.ContainerManager.Create; `attachTo` the index of the spec this one attaches to (nil for a
--- stack's head); `customKeys` the CUSTOM keys its states name (nil when the preset creates none).
--- The width is not read: heads hang from the parent's top edge and center line, so they follow any
--- width. An unknown name or look builds nothing.
--- @param name string
--- @param look string  "bars" | "icons"
--- @param _ number|nil  parentW (unused)
--- @param parentH number|nil
--- @return table
function P.Build(name, look, _, parentH)
    local tier = TIERS[name]
    if not (tier and IS_LOOK[look]) then return {} end
    local k, withCustom = P.Scale(parentH), CREATES_CUSTOM[name] == true
    local specs, last = {}, {}
    for i, entry in ipairs(tier) do
        local stackKey, roleKey = entry[1], entry[2]
        local stack = P.STACKS[stackKey]
        local o = overridesFor(CONTAINERS[roleKey], withCustom)
        if look == "icons" then toIcons(o, stack) end
        sizeTo(o, stack, k)
        local spec = { role = roleKey, stack = stackKey, overrides = o }
        if last[stackKey] then
            spec.attachTo = last[stackKey]
            o.attach = memberAttach(k)
        else
            place(o, stack, k)
        end
        if withCustom then spec.customKeys = copy(CUSTOM_ORDER) end
        last[stackKey] = i
        specs[i] = spec
    end
    return specs
end
