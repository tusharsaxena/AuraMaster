local _, NS = ...

-- defaults/Categories.lua — the aura CATEGORIES a container's filter can show or hide.
--
-- A category is one of four KINDS, and the kind decides how modules/FilterCompiler.lua turns it into
-- something Blizzard's aura container evaluates in its own secure code (we never see aura data in
-- combat, so every filter has to be declared up front — see docs/data-flow.md):
--
--   token   an aura filter token (`BIG_DEFENSIVE`, `CROWD_CONTROL`, …). Showing it adds the token to
--           the group's filter string; hiding it adds the negation `!TOKEN`.
--   flag    a boolean candidate filter on the aura (`isBossAura`, `isRoleAura`, …). Showing it asks
--           for `value`; hiding it asks for `not value`.
--   dispel  a set of dispel types. Showing it is `includeDispelTypes`; hiding it `excludeDispelTypes`.
--   spells  a curated list of spell ids. Showing it is `includeSpellIDs`; hiding it `excludeSpellIDs`.
--           Blizzard only honors spell ids for BUFFS ON FRIENDLY UNITS and DEBUFFS ON HOSTILE ONES,
--           so every spell category here is a buff category; the Filters page says so where it
--           matters (docs/scope.md, "What the engine cannot do").
--
-- THE SPELL LISTS ARE A STARTER SET, WRITTEN FOR THIS ADDON. They were assembled from public spell
-- data for Retail 12.x and are meant to be edited: the Filters page lets a player add or remove any
-- id per category, and those edits live in the profile (container.filter.categorySpells), never here.
-- An id that does not exist in the current client simply never matches, so a stale entry costs
-- nothing but a row in the editor. Consumables change every expansion and are the list most likely to
-- need a player's own additions.
--
-- `class` on a spell is only for grouping the editor by class; the filter ignores it.

NS.Categories = NS.Categories or {}
local Cat = NS.Categories

local function spells(list)
    local out = {}
    for class, ids in pairs(list) do
        for _, id in ipairs(ids) do out[id] = class end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Buff categories
-- ---------------------------------------------------------------------------

Cat.HELPFUL = {
    {
        key = "defensives", kind = "spells", label = "Defensives",
        desc = "Personal defensive cooldowns.",
        spells = spells({
            WARRIOR     = { 118038, 184364, 871, 23920, 12975 },
            PALADIN     = { 642, 498, 31850, 86659, 184662, 205191 },
            HUNTER      = { 186265, 264735 },
            ROGUE       = { 5277, 31224, 1966 },
            PRIEST      = { 47585, 19236 },
            DEATHKNIGHT = { 48792, 48707, 55233, 49039 },
            SHAMAN      = { 108271 },
            MAGE        = { 45438, 342246 },
            WARLOCK     = { 104773, 108416 },
            MONK        = { 120954, 122278, 122783, 125174 },
            DRUID       = { 22812, 61336 },
            DEMONHUNTER = { 212800, 196555, 187827 },
            EVOKER      = { 363916, 374348 },
        }),
    },
    {
        key = "bigDefensive", kind = "token", token = "BIG_DEFENSIVE", label = "Big defensives (Blizzard)",
        desc = "Auras Blizzard itself flags as big defensives.",
    },
    {
        key = "externals", kind = "token", token = "EXTERNAL_DEFENSIVE", label = "External defensives (Blizzard)",
        desc = "Defensives another player cast on the unit, as Blizzard flags them.",
    },
    {
        key = "activeMitigation", kind = "spells", label = "Active mitigation",
        desc = "Short, frequently refreshed tank mitigation.",
        spells = spells({
            WARRIOR     = { 132404, 190456 },
            PALADIN     = { 132403 },
            DEATHKNIGHT = { 77535, 195181 },
            DRUID       = { 192081 },
            DEMONHUNTER = { 203819 },
            MONK        = { 215479 },
        }),
    },
    {
        key = "raidCDs", kind = "spells", label = "Raid cooldowns",
        desc = "Group-wide cooldowns and haste effects.",
        spells = spells({
            WARRIOR     = { 97463 },
            PALADIN     = { 31821 },
            DEATHKNIGHT = { 145629 },
            DEMONHUNTER = { 209426 },
            PRIEST      = { 81782 },
            SHAMAN      = { 2825, 32182, 98007 },
            MAGE        = { 80353 },
            HUNTER      = { 264667 },
            EVOKER      = { 390386, 374227 },
        }),
    },
    {
        key = "offensiveCDs", kind = "spells", label = "Offensive cooldowns",
        desc = "Damage cooldowns.",
        spells = spells({
            WARRIOR     = { 1719, 107574 },
            PALADIN     = { 31884, 231895 },
            DEATHKNIGHT = { 51271, 207289 },
            DRUID       = { 194223, 102560, 106951, 102543 },
            HUNTER      = { 288613, 19574, 360952 },
            MAGE        = { 190319, 12472, 365362 },
            ROGUE       = { 121471, 13750, 185422 },
            DEMONHUNTER = { 162264 },
            PRIEST      = { 194249, 10060 },
            MONK        = { 137639 },
            SHAMAN      = { 114051 },
            EVOKER      = { 375087 },
        }),
    },
    {
        key = "coreHealing", kind = "spells", label = "Core healing buffs",
        desc = "The main heal-over-time effects and shields.",
        spells = spells({
            DRUID  = { 774, 8936, 33763, 48438 },
            PRIEST = { 139, 17, 194384, 41635 },
            SHAMAN = { 61295, 974 },
            MONK   = { 119611, 124682 },
            EVOKER = { 364343, 366155 },
            PALADIN = { 53563 },
        }),
    },
    {
        key = "lesserHealing", kind = "spells", label = "Lesser healing buffs",
        desc = "Secondary heal-over-time effects and beacons.",
        spells = spells({
            DRUID   = { 102352, 155777, 207386 },
            MONK    = { 115175 },
            PALADIN = { 156910, 200025, 287280 },
        }),
    },
    {
        key = "support", kind = "spells", label = "Support",
        desc = "Raid buffs and buffs cast on other players.",
        spells = spells({
            MAGE    = { 1459 },
            PRIEST  = { 21562 },
            WARRIOR = { 6673 },
            DRUID   = { 1126, 29166 },
            EVOKER  = { 381748, 369459 },
            SHAMAN  = { 462854 },
        }),
    },
    {
        key = "movement", kind = "spells", label = "Movement",
        desc = "Speed and freedom effects.",
        spells = spells({
            ROGUE   = { 2983 },
            DRUID   = { 1850, 106898 },
            PALADIN = { 1044, 221886 },
            MONK    = { 116841 },
            HUNTER  = { 186257 },
            SHAMAN  = { 192082, 79206, 2645 },
            PRIEST  = { 121557, 65081 },
            WARLOCK = { 111400 },
            EVOKER  = { 358267 },
        }),
    },
    {
        key = "utility", kind = "spells", label = "Utility",
        desc = "Soulstones, stealth, water walking and similar.",
        spells = spells({
            WARLOCK = { 20707, 5697 },
            PRIEST  = { 1706 },
            SHAMAN  = { 546 },
            MAGE    = { 130, 32612 },
            HUNTER  = { 5384 },
            ROGUE   = { 1784 },
            DRUID   = { 5215 },
            ALL     = { 58984 },
        }),
    },
    {
        key = "consumables", kind = "spells", label = "Consumables",
        desc = "Flasks and similar. Changes every expansion — add your own ids.",
        spells = spells({
            ALL = { 431971, 431972, 431973, 431974, 432021 },
        }),
    },
    {
        key = "important", kind = "token", token = "IMPORTANT", label = "Important (Blizzard)",
        desc = "Auras Blizzard flags as important, the ones enemy nameplates show.",
    },
    {
        key = "castable", kind = "token", token = "RAID", label = "Castable by you",
        desc = "Buffs of a kind you can apply yourself.",
    },
    {
        key = "cancelable", kind = "token", token = "CANCELABLE", label = "Cancelable",
        desc = "Buffs the player is able to cancel.",
    },
    {
        key = "stealable", kind = "flag", field = "isStealable", value = true, label = "Stealable / purgeable",
        desc = "Buffs that can be stolen or purged — most useful on an enemy target.",
    },
}

-- ---------------------------------------------------------------------------
-- Debuff categories
-- ---------------------------------------------------------------------------
--
-- No spell lists here: Blizzard ignores spell ids for debuffs on the player and on any friendly unit.
-- Every debuff category is something the engine can evaluate for any unit.

local ALL_DISPELS = { Magic = true, Curse = true, Disease = true, Poison = true, Bleed = true }

Cat.HARMFUL = {
    {
        key = "crowdControl", kind = "token", token = "CROWD_CONTROL", label = "Crowd control",
        desc = "Stuns, fears, roots and similar, as Blizzard flags them.",
    },
    {
        key = "boss", kind = "flag", field = "isBossAura", value = true, label = "Boss debuffs",
        desc = "Debuffs applied by a boss.",
    },
    {
        key = "role", kind = "flag", field = "isRoleAura", value = true, label = "Role debuffs",
        desc = "Debuffs Blizzard flags as relevant to your role.",
    },
    {
        -- `priority`, not `important`: every category key is unique across BOTH lists, because a
        -- container's category states are one map and a container can change its aura type.
        key = "priority", kind = "flag", field = "isPriorityAura", value = true, label = "Priority",
        desc = "Debuffs Blizzard flags as priority.",
    },
    {
        key = "raid", kind = "token", token = "RAID", label = "Raid (you can dispel)",
        desc = "Debuffs you are able to dispel.",
    },
    {
        key = "raidInCombat", kind = "token", token = "RAID_IN_COMBAT", label = "Raid in combat",
        desc = "Debuffs Blizzard shows on raid frames during combat.",
    },
    {
        key = "groupDispellable", kind = "token", token = "RAID_PLAYER_DISPELLABLE", label = "Dispellable by your group",
        desc = "Debuffs someone in your group can dispel.",
    },
    {
        key = "dispellable", kind = "token", token = "DISPELLABLE", label = "Dispellable by anyone",
        desc = "Debuffs any class can dispel.",
    },
    {
        key = "dispels", kind = "dispel", types = ALL_DISPELS, label = "Has a dispel type",
        desc = "Magic, curse, disease, poison or bleed.",
    },
    { key = "magic",   kind = "dispel", types = { Magic = true },   label = "Magic",   desc = "Magic debuffs." },
    { key = "curse",   kind = "dispel", types = { Curse = true },   label = "Curse",   desc = "Curses." },
    { key = "disease", kind = "dispel", types = { Disease = true }, label = "Disease", desc = "Diseases." },
    { key = "poison",  kind = "dispel", types = { Poison = true },  label = "Poison",  desc = "Poisons." },
    { key = "bleed",   kind = "dispel", types = { Bleed = true },   label = "Bleed",   desc = "Bleeds." },
    {
        key = "fromNonPlayers", kind = "flag", field = "isFromPlayerOrPlayerPet", value = false,
        label = "From non-players", desc = "Debuffs applied by creatures rather than players.",
    },
    {
        key = "fromPlayers", kind = "flag", field = "isFromPlayerOrPlayerPet", value = true,
        label = "From any player", desc = "Debuffs applied by any player or their pet.",
    },
}

-- Weapon enchants have no categories: the engine draws them per slot.
Cat.ENCHANT = {}

--- The ordered category list for an aura type, never nil.
--- @param auraType string  "HELPFUL" | "HARMFUL" | "ENCHANT"
--- @return table
function Cat.For(auraType)
    return Cat[auraType] or Cat.ENCHANT
end

--- One category definition by aura type and key, or nil.
--- @return table|nil
function Cat.Find(auraType, key)
    for _, def in ipairs(Cat.For(auraType)) do
        if def.key == key then return def end
    end
    return nil
end

--- Whether `key` names a spell-list category (the only kind whose spells a player can edit).
--- @return boolean
function Cat.IsSpellCategory(key)
    local def = Cat.Find("HELPFUL", key) or Cat.Find("HARMFUL", key)
    return def ~= nil and def.kind == "spells"
end

--- Every category key across both lists, each mapped to "" — the neutral state. The container
--- template's `filter.categories` is built from this, so a key added in a later version reaches
--- every stored container through the ordinary backfill and resolves for the schema validator.
--- @return table
function Cat.NeutralStates()
    local out = {}
    for _, list in ipairs({ Cat.HELPFUL, Cat.HARMFUL }) do
        for _, def in ipairs(list) do out[def.key] = "" end
    end
    return out
end
