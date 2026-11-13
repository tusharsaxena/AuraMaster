local _, NS = ...

-- fixtures/forever_categories/Categories.lua -- a small Retail Categories.lua in the shipped shape,
-- for test_forever.py: the Retail entries forever.py maps by name onto the Forever fixture tables.

NS.Categories = NS.Categories or {}
local Cat = NS.Categories

local function spells(list)
    local out = {}
    for class, ids in pairs(list) do
        for _, id in ipairs(ids) do out[id] = class end
    end
    return out
end

Cat.HELPFUL = {
    {
        key = "defensives", kind = "spells", label = "Defensive cooldowns",
        desc = "Personal defensive cooldowns.",
        spells = spells({
            WARRIOR = {
                871,    -- Shield Wall
            },
            HUNTER = {
                186265, -- Aspect of the Turtle; no such spell on Forever
            },
            MONK = {
                115203, -- Fortifying Brew; a Retail-only class
            },
        }),
    },
    {
        key = "activeMitigation", kind = "spells", label = "Active mitigation",
        desc = "Short, frequently refreshed tank mitigation.",
        spells = spells({
            WARRIOR = {
                132404, -- Shield Block
            },
        }),
    },
    {
        key = "offensiveCDs", kind = "spells", label = "Offensive cooldowns",
        desc = "Damage cooldowns.",
        spells = spells({
            WARRIOR = {
                1719,   -- Recklessness
            },
        }),
    },
    {
        key = "healing", kind = "spells", label = "Healing",
        desc = "Heal-over-time effects, shields and beacons.",
        spells = spells({
            PRIEST = {
                139,    -- Renew
            },
        }),
    },
    {
        key = "groupBuffs", kind = "spells", label = "Group buffs",
        desc = "Raid-wide buffs.",
        spells = spells({
            WARRIOR = {
                6673,   -- Battle Shout
            },
            MAGE = {
                1459,   -- Arcane Intellect
            },
        }),
    },
    {
        key = "movement", kind = "spells", label = "Movement",
        desc = "Speed and freedom effects.",
        spells = spells({
            ROGUE = {
                2983,   -- Sprint
            },
        }),
    },
    {
        key = "utility", kind = "spells", label = "Utility",
        desc = "Soulstones, stealth, water walking and similar.",
        spells = spells({
            HUNTER = {
                199483, -- Fixture Flare; cast as one id, lands as another on Forever
            },
        }),
    },
    {
        key = "stances", kind = "spells", label = "Stances",
        desc = "Warrior stances, druid forms and paladin auras.",
        spells = spells({
            WARRIOR = {
                386164, -- Battle Stance
            },
            PALADIN = {
                465,    -- Devotion Aura
            },
        }),
    },
    {
        key = "racials", kind = "spells", label = "Racials",
        desc = "Buffs from racial abilities.",
        spells = spells({
            ALL = {
                65116,  -- Stoneform; Dwarf
            },
        }),
    },
    {
        key = "important", kind = "token", token = "IMPORTANT", label = "Important (Blizzard)",
    },
}

Cat.HARMFUL = {
    {
        key = "hardCC", kind = "spells", label = "CC Loss of Control",
        desc = "Stuns and the like; derived by mechanic, never mapped by name.",
        spells = spells({
            WARRIOR = {
                5246,   -- Intimidating Shout
            },
        }),
    },
    {
        key = "racialDebuffs", kind = "spells", label = "Racials",
        desc = "Debuffs from racial abilities.",
        spells = spells({
            ALL = {
                20549,  -- War Stomp; Tauren
            },
        }),
    },
}
