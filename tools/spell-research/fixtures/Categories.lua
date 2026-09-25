local _, NS = ...

-- fixtures/Categories.lua -- a small copy of defaults/Categories.lua in the shipped shape, for the
-- sid_db2 / sid_propose / sid_decide tests. Two HELPFUL `spells` categories, one HELPFUL token
-- category, and one HARMFUL `spells` category. A commented-out line such as
--     key = "notACategory", kind = "spells", label = "Never read",
-- must never be read as a category.

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
            WARRIOR     = { 871, 12975 },
            SHAMAN      = { 108271 },
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
            WARRIOR     = { 1719, 107574 },
            -- SHAMAN = { 999999 }, a commented-out line is not an entry
            SHAMAN      = { 114051 },   -- Ascendance (Enhancement; Restoration is 114052)
        }),
    },
}

Cat.HARMFUL = {
    {
        key = "hardCC", kind = "spells", label = "Hard CC (loss of control)",
        desc = "Stuns, incapacitates, disorients and fears.",
        spells = spells({
            WARRIOR     = { 5246, 132168 },                         -- Intimidating Shout, Shockwave
            SHAMAN      = { 51514, 118905 },                        -- Hex, Capacitor Totem
        }),
    },
    {
        key = "boss", kind = "flag", field = "isBossAura", value = true, label = "Boss debuffs",
    },
}
