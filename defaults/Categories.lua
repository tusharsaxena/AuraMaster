local _, NS = ...

-- defaults/Categories.lua — the aura CATEGORIES a container's filter can show or hide.
--
-- A category is one of six KINDS, and the kind decides how modules/FilterCompiler.lua turns it into
-- something Blizzard's aura container evaluates in its own secure code (we never see aura data in
-- combat, so every filter has to be declared up front — see docs/data-flow.md):
--
-- Show is the absence of a decision (schema v3) in the sense that it never NARROWS what draws: it is
-- the default every key starts at (`DefaultStates` below). It is not inert, though (batch 6's filter-
-- priority revision, modules/FilterCompiler.lua) — a Show is a POSITIVE claim that beats a Hide on
-- the same aura, and once any category is Hidden the compiler emits one group PER Show category
-- (plus a catch-all), not the single group a container with nothing Hidden still gets. Only Hide
-- writes a constraint, an exclusion, and only on the group(s) it actually reaches.
--
--   token          an aura filter token (`BIG_DEFENSIVE`, `CROWD_CONTROL`, …). Hiding it adds the
--                  negation `!TOKEN` to the group's filter string.
--   flag           a boolean candidate filter on the aura (`isBossAura`, `isRoleAura`, …). Hiding it
--                  asks for `not value`.
--   dispel         a set of dispel types. Hiding it adds to `excludeDispelTypes`.
--   spells         a curated list of spell ids. Hiding it adds to `excludeSpellIDs`. Blizzard only
--                  honors spell ids for BUFFS ON FRIENDLY UNITS and DEBUFFS ON HOSTILE ONES, so every
--                  spell category here is a buff category; the Filters page says so where it matters
--                  (docs/scope.md, "What the engine cannot do").
--   enchant        the player's temporary weapon enchants. The odd one out: it matches no aura and
--                  joins no aura group. Hide takes the container's enchant slots away, Show gives
--                  them back (modules/FilterCompiler.lua's Compile, not its group builder).
--   uncategorized  batch 7, `U-1`..`U-5` (docs/superpowers/specs/2026-09-15-feedback-batch7-design.md
--                  section 4): "in none of the profile's SPELL-LIST (kind `spells`) categories" —
--                  Blizzard token/flag/dispel categories do NOT count toward being categorized. It has
--                  no id list of its own; it is the COMPLEMENT of every `spells`-kind category's
--                  effective ids, so modules/FilterCompiler.lua handles it with dedicated logic rather
--                  than the generic per-kind include/exclude every other kind shares. Drawn LAST in the
--                  grid, default Show. There is no General -> Spell Categories entry for it: it has no
--                  list to edit.
--
--                  ONE ROW PER AURA TYPE, ASYMMETRIC (fix round 3, 2026-09-16 — the owner restored the
--                  debuff row round 1 dropped). `Cat.HELPFUL` has real `spells`-kind categories, so its
--                  row's union is a genuine subset: Show excludes that union (rescuing an unlisted buff
--                  from another category's Hide) and Hide contributes nothing of its own, but either
--                  way the row SUPERSEDES the catch-all (a Show's group is a strict superset of what
--                  the catch-all would draw; a Hide's only possible catch-all contribution would be a
--                  dead group — see modules/FilterCompiler.lua's top-of-file comment). `Cat.HARMFUL`
--                  has NO `spells`-kind category, so its union is always EMPTY — every debuff is
--                  trivially "not on any spell list" and there is nothing to rescue. Concretely proven
--                  (fix round 3): if the debuff row's Show contributed a group the way the buff row's
--                  does, that group would carry no candidate filter at all and would draw EVERY debuff
--                  regardless of any other category's Hide — neutering them all, the owner's original
--                  complaint reborn. So on HARMFUL, Show contributes NOTHING (as if the row did not
--                  exist — the ordinary catch-all runs normally) while Hide still suppresses the
--                  catch-all outright, reproducing the retired "Only these categories" toggle exactly.
--                  `modules/FilterCompiler.lua`'s `hasUnion` flag (already computed for the identity
--                  warning) is what gates this: a Show-kind-`uncategorized` category contributes its
--                  own group, and therefore supersedes the catch-all, only when `hasUnion` is true.
--
-- THE SPELL LISTS ARE A STARTER SET, WRITTEN FOR THIS ADDON. They were assembled from public spell
-- data for Retail 12.x and are meant to be edited: the Filters page lets a player add or remove any
-- id per category, and those edits live in the profile (profile.categorySpells, shared by every
-- container since schema v2), never here.
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
        -- One list since schema v2: the former coreHealing and lesserHealing, united (core/Database.lua's
        -- MigrateV2 merges a player's edits and category states of the two).
        key = "healing", kind = "spells", label = "Healing",
        desc = "Heal-over-time effects, shields and beacons.",
        spells = spells({
            DRUID   = { 774, 8936, 33763, 48438, 102352, 155777, 207386 },
            PRIEST  = { 139, 17, 194384, 41635 },
            SHAMAN  = { 61295, 974 },
            MONK    = { 119611, 124682, 115175 },
            EVOKER  = { 364343, 366155 },
            PALADIN = { 53563, 156910, 200025, 287280 },
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
    {
        key = "weaponEnchants", kind = "enchant", label = "Weapon enchants",
        desc = "Your temporary weapon enchants, drawn after the buffs. Only on a container showing your own buffs; which weapon slots count is set on General -> Spell Categories.",
    },
    {
        -- U-1: last in the grid, on purpose (renderCategories draws categoryRows() in Cat.For order).
        key = "uncategorized", kind = "uncategorized", label = "Uncategorized",
        desc = "Not in any of the Spell Categories lists above (Blizzard categories do not count). Show rescues an unlisted buff from a Hidden Blizzard category; Hide removes it along with everything else this container has no other reason to draw.",
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
    {
        -- Fix round 3 (2026-09-16): restored, asymmetric with the buff row — see the KINDS doc above.
        -- Hide reproduces the retired "Only these categories" toggle exactly (drops the catch-all, so
        -- only what is explicitly Shown is drawn). Show is a plain default: debuffs have no spell
        -- lists to be outside of, so there is nothing for it to rescue, and it must NOT contribute a
        -- group of its own — an unrestricted debuff group would draw everything and defeat every
        -- other Hide on the tab. `modules/FilterCompiler.lua` gates that on `hasUnion` (always false
        -- here), not on aura type, so this is a general rule, not a debuff-only special case.
        key = "uncategorizedDebuffs", kind = "uncategorized", label = "Uncategorized",
        desc = "Hide draws only what you have explicitly set to Show on this tab (the retired 'Only these categories' toggle, exactly). Show is the default and changes nothing by itself: debuffs have no spell lists, so there is nothing here for it to rescue from another category's Hide.",
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

--- Every category key across both lists, each mapped to "show" — the default state (schema v3:
--- Show is the absence of a decision, so it excludes nothing). The container template's
--- `filter.categories` is built from this, so a key added in a later version reaches every stored
--- container through the ordinary backfill and resolves for the schema validator.
--- @return table
function Cat.DefaultStates()
    local out = {}
    for _, list in ipairs({ Cat.HELPFUL, Cat.HARMFUL }) do
        for _, def in ipairs(list) do out[def.key] = "show" end
    end
    return out
end

--- The default states with every BUFF category Hidden except `keys`, which stay Show: a container
--- that draws only the buffs those categories claim (the "Player cooldowns" starter,
--- defaults/Profile.lua). That hides every Blizzard token and flag category, Weapon enchants and
--- Uncategorized too, so an unlisted buff has no Show left to draw it. The debuff categories keep
--- Show: inert on a buff container, and a later switch to debuffs does not start all-hidden.
--- @param keys table  category keys of Cat.HELPFUL
--- @return table
function Cat.StatesShowing(keys)
    local out = Cat.DefaultStates()
    for _, def in ipairs(Cat.HELPFUL) do out[def.key] = "hide" end
    for _, key in ipairs(keys) do out[key] = "show" end
    return out
end
