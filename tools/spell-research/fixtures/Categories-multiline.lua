local _, NS = ...

-- fixtures/Categories-multiline.lua -- a small copy of defaults/Categories.lua in its shipped layout
-- (2026-09-25 on), for the reader and writer tests: one table per class, ONE ID PER LINE, and the
-- comment on an id's line gives the spell's name, then any context after a `;`. The comments carry
-- digits on purpose (dates, "replaces 231895", "98007 is the cast") and none of them is an id. hardCC
-- keeps one LEGACY one-line class (SHAMAN) so a block mixing the two layouts is covered. A
-- commented-out id such as
--     999999,  -- Never read
-- must never be read.

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
                12975,  -- Last Stand
            },
            -- Spirit Walk (58875) is Movement only (owner 2026-09-25)
            SHAMAN = {
                108271, -- Astral Shift
            },
            EVOKER = {
                363916, -- Obsidian Scales
                374349, -- Renewing Blaze; the aura id the 2026-09-24 combat logs show; replaces 374348
            },
        }),
    },
    {
        key = "externals", kind = "token", token = "EXTERNAL_DEFENSIVE", label = "External defensives (Blizzard)",
        desc = "Defensives another player cast on the unit, as Blizzard flags them.",
    },
    {
        key = "offensiveCDs", kind = "spells", label = "Offensive cooldowns",
        desc = "Damage cooldowns.",
        spells = spells({
            WARRIOR = {
                1719,    -- Recklessness
                107574,  -- Avatar
            },
            PALADIN = {
                31884,   -- Avenging Wrath
                454351,  -- Avenging Wrath; the aura id the 2026-09-24 combat logs show; replaces 231895
            },
            SHAMAN = {
                -- 999999,  -- commented out: not an entry
                114051,  -- Ascendance
            },
        }),
    },
    {
        key = "raidCDs", kind = "spells", label = "Raid cooldowns",
        desc = "Group-wide cooldowns and haste effects.",
        spells = spells({
            SHAMAN = {
                2825,    -- Bloodlust; a Bloodlust variant (owner 2026-09-25)
                325174,  -- Spirit Link Totem; the aura; 98007 is the cast (issue #15)
            },
            ALL = {
                1243972, -- Void-touched Drums; drums any class can use; added from the 2026-09-24 combat logs
            },
        }),
    },
}

Cat.HARMFUL = {
    {
        key = "hardCC", kind = "spells", label = "Hard CC (loss of control)",
        desc = "Stuns, incapacitates, disorients and fears.",
        spells = spells({
            WARRIOR = {
                5246,    -- Intimidating Shout
                132168,  -- Shockwave
            },
            SHAMAN      = { 51514, 118905 },                        -- Hex (Frog; 211004 is the Spider), Capacitor Totem
        }),
    },
    {
        key = "boss", kind = "flag", field = "isBossAura", value = true, label = "Boss debuffs",
    },
}
