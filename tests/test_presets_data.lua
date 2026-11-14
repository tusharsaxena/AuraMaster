-- tests/test_presets_data.lua -- the preset data and the pure placement builder (AM-PR01; spec
-- sections 3, 3.1, 3.2 and 4). Build reads nothing but its arguments and the category lists, so these
-- cases share the runner's environment, except the one that creates the player's own categories,
-- which builds its own (tests/fresh_env.lua). Every case runs under both kit profiles, so the
-- category check is the per-client one clients-§6 asks for.

local freshEnv = dofile("tests/fresh_env.lua")

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil, assertNear =
    T.test, T.assertEqual, T.assertTrue, T.assertNil, T.assertNear
local NS = T.NS

local NAMES = { "empty", "simple", "intermediate", "advanced", "healer" }
local CUSTOM = { SPECIAL_PLAYER = true, SPECIAL_TARGET = true }

-- The 20 containers of docs/superpowers/specs/2026-11-14-presets/advanced-source.md, transcribed:
-- per role, the categories the source hides, then its filter (without the spell lists), its layout
-- (without growV, which spec section 3 turns to "down") and its behavior.
local SOURCE = {
    pbuffs = {
        unit = "player", auraType = "HELPFUL", style = "bars", enabled = true,
        hidden = { "weaponEnchants" },
        filter = { castBy = "any", durationMode = "any", hidePermanentEnchants = true, maxAuras = 0, maxDuration = 0, sortDirection = "reverse", sortMethod = "expirationOnly", situations = { npcs = "every", players = "every" }, unitFilter = { kind = "all", reaction = "all" }, zones = { arena = true, none = true, party = true, pvp = true, raid = true, scenario = true } },
        layout = { alpha = 1, axis = "vertical", growH = "right", level = 5, lineSpacing = 2, perLine = 0, scale = 1, spacing = 0, strata = "MEDIUM" },
        behavior = { cancelOnRightClick = true, clickThrough = false, tooltipAnchor = "ANCHOR_BOTTOMLEFT", tooltipInCombat = true, tooltips = true },
    },
    wpn = {
        unit = "player", auraType = "HELPFUL", style = "bars", enabled = true,
        hidden = { "SPECIAL_PLAYER", "activeMitigation", "bigDefensive", "cancelable", "castable", "defensives", "externals", "groupBuffs", "healing", "important", "movement", "offensiveCDs", "racials", "raidCDs", "stances", "stealable", "support", "uncategorized", "utility" },
        filter = { castBy = "any", durationMode = "any", hidePermanentEnchants = true, maxAuras = 0, maxDuration = 0, sortDirection = "reverse", sortMethod = "expirationOnly", situations = { npcs = "every", players = "every" }, unitFilter = { kind = "all", reaction = "all" }, zones = { arena = true, none = true, party = true, pvp = true, raid = true, scenario = true } },
        layout = { alpha = 1, axis = "vertical", growH = "right", level = 5, lineSpacing = 2, perLine = 0, scale = 1, spacing = 0, strata = "MEDIUM" },
        behavior = { cancelOnRightClick = true, clickThrough = false, tooltipAnchor = "ANCHOR_BOTTOMLEFT", tooltipInCombat = true, tooltips = true },
    },
    pdebuffs = {
        unit = "player", auraType = "HARMFUL", style = "bars", enabled = true,
        hidden = { "weaponEnchants" },
        filter = { castBy = "any", durationMode = "any", hidePermanentEnchants = true, maxAuras = 0, maxDuration = 0, sortDirection = "reverse", sortMethod = "expirationOnly", situations = { npcs = "every", players = "every" }, unitFilter = { kind = "all", reaction = "all" }, zones = { arena = true, none = true, party = true, pvp = true, raid = true, scenario = true } },
        layout = { alpha = 1, axis = "vertical", growH = "right", level = 5, lineSpacing = 2, perLine = 0, scale = 1, spacing = 0, strata = "MEDIUM" },
        behavior = { cancelOnRightClick = true, clickThrough = false, tooltipAnchor = "ANCHOR_BOTTOMLEFT", tooltipInCombat = true, tooltips = true },
    },
    pshort = {
        unit = "player", auraType = "HELPFUL", style = "bars", enabled = true,
        hidden = { "weaponEnchants" },
        filter = { castBy = "mine", durationMode = "timed", hidePermanentEnchants = true, maxAuras = 0, maxDuration = 30, sortDirection = "reverse", sortMethod = "expirationOnly", situations = { npcs = "every", players = "every" }, unitFilter = { kind = "all", reaction = "all" }, zones = { arena = true, none = true, party = true, pvp = true, raid = true, scenario = true } },
        layout = { alpha = 1, axis = "vertical", growH = "right", level = 5, lineSpacing = 2, perLine = 0, scale = 1, spacing = 0, strata = "MEDIUM" },
        behavior = { cancelOnRightClick = true, clickThrough = false, tooltipAnchor = "ANCHOR_BOTTOMLEFT", tooltipInCombat = true, tooltips = true },
    },
    tbuff = {
        unit = "target", auraType = "HELPFUL", style = "bars", enabled = true,
        hidden = { "weaponEnchants" },
        filter = { castBy = "mine", durationMode = "timed", hidePermanentEnchants = true, maxAuras = 0, maxDuration = 30, sortDirection = "reverse", sortMethod = "expirationOnly", situations = { npcs = "every", players = "every" }, unitFilter = { kind = "all", reaction = "all" }, zones = { arena = true, none = true, party = true, pvp = true, raid = true, scenario = true } },
        layout = { alpha = 1, axis = "vertical", growH = "right", level = 5, lineSpacing = 2, perLine = 0, scale = 1, spacing = 0, strata = "MEDIUM" },
        behavior = { cancelOnRightClick = true, clickThrough = false, tooltipAnchor = "ANCHOR_BOTTOMLEFT", tooltipInCombat = true, tooltips = true },
    },
    tdeb = {
        unit = "target", auraType = "HARMFUL", style = "bars", enabled = true,
        hidden = { "weaponEnchants" },
        filter = { castBy = "mine", durationMode = "timed", hidePermanentEnchants = true, maxAuras = 0, maxDuration = 30, sortDirection = "reverse", sortMethod = "expirationOnly", situations = { npcs = "every", players = "every" }, unitFilter = { kind = "all", reaction = "all" }, zones = { arena = true, none = true, party = true, pvp = true, raid = true, scenario = true } },
        layout = { alpha = 1, axis = "vertical", growH = "right", level = 5, lineSpacing = 2, perLine = 0, scale = 1, spacing = 0, strata = "MEDIUM" },
        behavior = { cancelOnRightClick = true, clickThrough = false, tooltipAnchor = "ANCHOR_BOTTOMLEFT", tooltipInCombat = true, tooltips = true },
    },
    ticoD = {
        unit = "target", auraType = "HARMFUL", style = "icons", enabled = true,
        hidden = {  },
        filter = { castBy = "any", durationMode = "any", hidePermanentEnchants = true, maxAuras = 16, maxDuration = 0, sortDirection = "normal", sortMethod = "expirationOnly", situations = { npcs = "every", players = "every" }, unitFilter = { kind = "all", reaction = "all" }, zones = { arena = true, none = true, party = true, pvp = true, raid = false, scenario = true } },
        layout = { alpha = 1, axis = "horizontal", growH = "right", level = 5, lineSpacing = 0, perLine = 8, scale = 1, spacing = 0, strata = "MEDIUM" },
        behavior = { cancelOnRightClick = true, clickThrough = false, tooltipAnchor = "ANCHOR_BOTTOMLEFT", tooltipInCombat = true, tooltips = true },
    },
    txtOff = {
        unit = "player", auraType = "HELPFUL", style = "text", enabled = true,
        hidden = { "SPECIAL_PLAYER", "activeMitigation", "bigDefensive", "cancelable", "castable", "defensives", "externals", "groupBuffs", "healing", "important", "movement", "racials", "raidCDs", "stances", "stealable", "support", "uncategorized", "utility", "weaponEnchants" },
        filter = { castBy = "any", durationMode = "any", hidePermanentEnchants = true, maxAuras = 0, maxDuration = 0, sortDirection = "normal", sortMethod = "expirationOnly", situations = { npcs = "every", players = "every" }, unitFilter = { kind = "all", reaction = "all" }, zones = { arena = true, none = true, party = true, pvp = true, raid = true, scenario = true } },
        layout = { alpha = 1, axis = "vertical", growH = "right", level = 5, lineSpacing = 2, perLine = 0, scale = 1, spacing = 2, strata = "MEDIUM" },
        behavior = { cancelOnRightClick = true, clickThrough = false, tooltipAnchor = "ANCHOR_BOTTOMLEFT", tooltipInCombat = true, tooltips = true },
    },
    txtDef = {
        unit = "player", auraType = "HELPFUL", style = "text", enabled = true,
        hidden = { "SPECIAL_PLAYER", "activeMitigation", "bigDefensive", "cancelable", "castable", "externals", "groupBuffs", "healing", "important", "movement", "offensiveCDs", "racials", "raidCDs", "stances", "stealable", "support", "uncategorized", "utility", "weaponEnchants" },
        filter = { castBy = "any", durationMode = "any", hidePermanentEnchants = true, maxAuras = 0, maxDuration = 0, sortDirection = "normal", sortMethod = "expirationOnly", situations = { npcs = "every", players = "every" }, unitFilter = { kind = "all", reaction = "all" }, zones = { arena = true, none = true, party = true, pvp = true, raid = true, scenario = true } },
        layout = { alpha = 1, axis = "vertical", growH = "right", level = 5, lineSpacing = 2, perLine = 0, scale = 1, spacing = 2, strata = "MEDIUM" },
        behavior = { cancelOnRightClick = true, clickThrough = false, tooltipAnchor = "ANCHOR_BOTTOMLEFT", tooltipInCombat = true, tooltips = true },
    },
    txtRaid = {
        unit = "player", auraType = "HELPFUL", style = "text", enabled = true,
        hidden = { "SPECIAL_PLAYER", "activeMitigation", "bigDefensive", "cancelable", "castable", "defensives", "externals", "groupBuffs", "healing", "important", "movement", "offensiveCDs", "racials", "stances", "stealable", "support", "uncategorized", "utility", "weaponEnchants" },
        filter = { castBy = "any", durationMode = "any", hidePermanentEnchants = true, maxAuras = 0, maxDuration = 0, sortDirection = "normal", sortMethod = "expirationOnly", situations = { npcs = "every", players = "every" }, unitFilter = { kind = "all", reaction = "all" }, zones = { arena = true, none = true, party = true, pvp = true, raid = true, scenario = true } },
        layout = { alpha = 1, axis = "vertical", growH = "right", level = 5, lineSpacing = 2, perLine = 0, scale = 1, spacing = 2, strata = "MEDIUM" },
        behavior = { cancelOnRightClick = true, clickThrough = false, tooltipAnchor = "ANCHOR_BOTTOMLEFT", tooltipInCombat = true, tooltips = true },
    },
    ticoB = {
        unit = "target", auraType = "HELPFUL", style = "icons", enabled = true,
        hidden = {  },
        filter = { castBy = "any", durationMode = "any", hidePermanentEnchants = true, maxAuras = 16, maxDuration = 0, sortDirection = "normal", sortMethod = "expirationOnly", situations = { npcs = "every", players = "every" }, unitFilter = { kind = "all", reaction = "all" }, zones = { arena = true, none = true, party = true, pvp = true, raid = false, scenario = true } },
        layout = { alpha = 1, axis = "horizontal", growH = "right", level = 5, lineSpacing = 0, perLine = 8, scale = 1, spacing = 0, strata = "MEDIUM" },
        behavior = { cancelOnRightClick = true, clickThrough = false, tooltipAnchor = "ANCHOR_BOTTOMLEFT", tooltipInCombat = true, tooltips = true },
    },
    tcc = {
        unit = "target", auraType = "HARMFUL", style = "bars", enabled = true,
        hidden = { "SPECIAL_TARGET", "bleed", "boss", "ccSnare", "crowdControl", "curse", "disease", "dispellable", "dispels", "fromNonPlayers", "fromPlayers", "groupDispellable", "magic", "poison", "priority", "racialDebuffs", "raid", "raidInCombat", "role", "uncategorizedDebuffs", "weaponEnchants" },
        filter = { castBy = "any", durationMode = "timed", hidePermanentEnchants = true, maxAuras = 0, maxDuration = 30, sortDirection = "reverse", sortMethod = "expirationOnly", situations = { npcs = "every", players = "every" }, unitFilter = { kind = "all", reaction = "all" }, zones = { arena = false, none = true, party = true, pvp = false, raid = true, scenario = true } },
        layout = { alpha = 1, axis = "vertical", growH = "right", level = 5, lineSpacing = 2, perLine = 0, scale = 1, spacing = 0, strata = "MEDIUM" },
        behavior = { cancelOnRightClick = true, clickThrough = false, tooltipAnchor = "ANCHOR_BOTTOMLEFT", tooltipInCombat = true, tooltips = true },
    },
    tcdp = {
        unit = "target", auraType = "HELPFUL", style = "bars", enabled = true,
        hidden = { "SPECIAL_PLAYER", "bigDefensive", "cancelable", "castable", "externals", "groupBuffs", "healing", "important", "racials", "stances", "stealable", "uncategorized", "weaponEnchants" },
        filter = { castBy = "any", durationMode = "timed", hidePermanentEnchants = true, maxAuras = 0, maxDuration = 30, sortDirection = "reverse", sortMethod = "expirationOnly", situations = { npcs = "every", players = "every" }, unitFilter = { kind = "player", reaction = "all" }, zones = { arena = false, none = true, party = true, pvp = false, raid = true, scenario = true } },
        layout = { alpha = 1, axis = "vertical", growH = "right", level = 5, lineSpacing = 2, perLine = 0, scale = 1, spacing = 0, strata = "MEDIUM" },
        behavior = { cancelOnRightClick = true, clickThrough = false, tooltipAnchor = "ANCHOR_BOTTOMLEFT", tooltipInCombat = true, tooltips = true },
    },
    pcd = {
        unit = "player", auraType = "HELPFUL", style = "bars", enabled = true,
        hidden = { "SPECIAL_PLAYER", "bigDefensive", "cancelable", "castable", "externals", "groupBuffs", "healing", "important", "racials", "stances", "stealable", "support", "uncategorized", "weaponEnchants" },
        filter = { castBy = "any", durationMode = "timed", hidePermanentEnchants = true, maxAuras = 0, maxDuration = 30, sortDirection = "reverse", sortMethod = "expirationOnly", situations = { npcs = "every", players = "every" }, unitFilter = { kind = "all", reaction = "all" }, zones = { arena = true, none = true, party = true, pvp = true, raid = true, scenario = true } },
        layout = { alpha = 1, axis = "vertical", growH = "right", level = 5, lineSpacing = 2, perLine = 0, scale = 1, spacing = 0, strata = "MEDIUM" },
        behavior = { cancelOnRightClick = true, clickThrough = false, tooltipAnchor = "ANCHOR_BOTTOMLEFT", tooltipInCombat = true, tooltips = true },
    },
    fbuff = {
        unit = "focus", auraType = "HELPFUL", style = "bars", enabled = true,
        hidden = { "weaponEnchants" },
        filter = { castBy = "mine", durationMode = "timed", hidePermanentEnchants = true, maxAuras = 0, maxDuration = 0, sortDirection = "reverse", sortMethod = "expirationOnly", situations = { npcs = "every", players = "every" }, unitFilter = { kind = "all", reaction = "all" }, zones = { arena = true, none = true, party = true, pvp = true, raid = true, scenario = true } },
        layout = { alpha = 1, axis = "vertical", growH = "right", level = 5, lineSpacing = 2, perLine = 0, scale = 1, spacing = 0, strata = "MEDIUM" },
        behavior = { cancelOnRightClick = true, clickThrough = false, tooltipAnchor = "ANCHOR_BOTTOMLEFT", tooltipInCombat = true, tooltips = true },
    },
    fdeb = {
        unit = "focus", auraType = "HARMFUL", style = "bars", enabled = true,
        hidden = { "weaponEnchants" },
        filter = { castBy = "mine", durationMode = "timed", hidePermanentEnchants = true, maxAuras = 0, maxDuration = 0, sortDirection = "reverse", sortMethod = "expirationOnly", situations = { npcs = "every", players = "every" }, unitFilter = { kind = "all", reaction = "all" }, zones = { arena = true, none = true, party = true, pvp = true, raid = true, scenario = true } },
        layout = { alpha = 1, axis = "vertical", growH = "right", level = 5, lineSpacing = 2, perLine = 0, scale = 1, spacing = 0, strata = "MEDIUM" },
        behavior = { cancelOnRightClick = true, clickThrough = false, tooltipAnchor = "ANCHOR_BOTTOMLEFT", tooltipInCombat = true, tooltips = true },
    },
    pspec = {
        unit = "player", auraType = "HELPFUL", style = "bars", enabled = true,
        hidden = { "activeMitigation", "bigDefensive", "cancelable", "castable", "defensives", "externals", "groupBuffs", "healing", "important", "movement", "offensiveCDs", "racials", "raidCDs", "stealable", "support", "uncategorized", "weaponEnchants" },
        filter = { castBy = "mine", durationMode = "any", hidePermanentEnchants = true, maxAuras = 0, maxDuration = 0, sortDirection = "reverse", sortMethod = "expirationOnly", situations = { npcs = "every", players = "every" }, unitFilter = { kind = "all", reaction = "all" }, zones = { arena = true, none = true, party = true, pvp = true, raid = true, scenario = true } },
        layout = { alpha = 1, axis = "vertical", growH = "right", level = 5, lineSpacing = 2, perLine = 0, scale = 1, spacing = 0, strata = "MEDIUM" },
        behavior = { cancelOnRightClick = true, clickThrough = false, tooltipAnchor = "ANCHOR_BOTTOMLEFT", tooltipInCombat = true, tooltips = true },
    },
    tspec = {
        unit = "target", auraType = "HARMFUL", style = "bars", enabled = true,
        hidden = { "SPECIAL_PLAYER", "activeMitigation", "bigDefensive", "bleed", "boss", "cancelable", "castable", "ccRoot", "ccSnare", "crowdControl", "curse", "defensives", "disease", "dispellable", "dispels", "externals", "fromNonPlayers", "fromPlayers", "groupBuffs", "groupDispellable", "hardCC", "healing", "important", "magic", "movement", "offensiveCDs", "poison", "priority", "racialDebuffs", "racials", "raid", "raidCDs", "raidInCombat", "role", "stances", "stealable", "support", "uncategorized", "uncategorizedDebuffs", "utility", "weaponEnchants" },
        filter = { castBy = "mine", durationMode = "any", hidePermanentEnchants = true, maxAuras = 0, maxDuration = 0, sortDirection = "reverse", sortMethod = "expirationOnly", situations = { npcs = "every", players = "every" }, unitFilter = { kind = "all", reaction = "all" }, zones = { arena = true, none = true, party = true, pvp = true, raid = true, scenario = true } },
        layout = { alpha = 1, axis = "vertical", growH = "right", level = 5, lineSpacing = 2, perLine = 0, scale = 1, spacing = 0, strata = "MEDIUM" },
        behavior = { cancelOnRightClick = true, clickThrough = false, tooltipAnchor = "ANCHOR_BOTTOMLEFT", tooltipInCombat = true, tooltips = true },
    },
    tcdn = {
        unit = "target", auraType = "HELPFUL", style = "bars", enabled = true,
        hidden = { "SPECIAL_PLAYER", "activeMitigation", "defensives", "groupBuffs", "healing", "movement", "offensiveCDs", "racials", "raidCDs", "stances", "support", "uncategorized", "utility", "weaponEnchants" },
        filter = { castBy = "any", durationMode = "timed", hidePermanentEnchants = true, maxAuras = 0, maxDuration = 0, sortDirection = "reverse", sortMethod = "expirationOnly", situations = { npcs = "every", players = "every" }, unitFilter = { kind = "npc", reaction = "all" }, zones = { arena = false, none = true, party = true, pvp = false, raid = true, scenario = true } },
        layout = { alpha = 1, axis = "vertical", growH = "right", level = 5, lineSpacing = 2, perLine = 0, scale = 1, spacing = 0, strata = "MEDIUM" },
        behavior = { cancelOnRightClick = true, clickThrough = false, tooltipAnchor = "ANCHOR_BOTTOMLEFT", tooltipInCombat = true, tooltips = true },
    },
    tsteal = {
        unit = "target", auraType = "HELPFUL", style = "bars", enabled = false,
        hidden = { "SPECIAL_PLAYER", "activeMitigation", "bigDefensive", "cancelable", "castable", "defensives", "externals", "groupBuffs", "healing", "important", "movement", "offensiveCDs", "racials", "raidCDs", "stances", "support", "uncategorized", "utility", "weaponEnchants" },
        filter = { castBy = "any", durationMode = "timed", hidePermanentEnchants = true, maxAuras = 0, maxDuration = 0, sortDirection = "reverse", sortMethod = "expirationOnly", situations = { npcs = "every", players = "every" }, unitFilter = { kind = "npc", reaction = "hostile" }, zones = { arena = false, none = true, party = true, pvp = false, raid = true, scenario = true } },
        layout = { alpha = 1, axis = "vertical", growH = "right", level = 5, lineSpacing = 2, perLine = 0, scale = 1, spacing = 0, strata = "MEDIUM" },
        behavior = { cancelOnRightClick = true, clickThrough = false, tooltipAnchor = "ANCHOR_BOTTOMLEFT", tooltipInCombat = true, tooltips = true },
    },
}

local function byRole(specs)
    local out = {}
    for i, spec in ipairs(specs) do out[spec.role] = spec; spec.index = i end
    return out
end

local function hiddenSet(categories)
    local out = {}
    for key, state in pairs(categories or {}) do
        if state == "hide" then out[key] = true end
    end
    return out
end

local function sameSet(got, list, what)
    local want = {}
    for _, k in ipairs(list) do want[k] = true end
    for k in pairs(want) do assertTrue(got[k], what .. ": " .. k .. " should be hidden") end
    for k in pairs(got) do assertTrue(want[k], what .. ": " .. k .. " should not be hidden") end
end

--- Every leaf of `want` equals the same leaf of `got`.
local function sameLeaves(got, want, what)
    for k, v in pairs(want) do
        if type(v) == "table" then
            assertTrue(type(got[k]) == "table", what .. "." .. k .. " is a table")
            sameLeaves(got[k], v, what .. "." .. k)
        else
            assertEqual(got[k], v, what .. "." .. k)
        end
    end
end

--- Two tables equal leaf for leaf, both ways.
local function deepEqual(a, b, what)
    sameLeaves(a, b, what)
    sameLeaves(b, a, what)
end

test("presets: counts", function()
    local P = NS.PresetData
    assertTrue(type(P) == "table", "NS.PresetData exists")
    assertEqual(P.Count("empty"), 0)
    assertEqual(P.Count("simple"), 3)
    assertEqual(P.Count("intermediate"), 8)
    assertEqual(P.Count("advanced"), 20)
    assertEqual(P.Count("healer"), 9)
    for _, n in ipairs(NAMES) do
        assertEqual(#P.Build(n, "bars", 1920, 1080), P.Count(n), n)
        assertEqual(#P.Build(n, "icons", 1920, 1080), P.Count(n), n .. " icons")
    end
    assertEqual(#P.Build("nope", "bars", 1920, 1080), 0, "unknown preset")
    assertEqual(#P.Build("advanced", "lines", 1920, 1080), 0, "unknown look")
end)

test("presets: advanced matches its source", function()
    local specs = byRole(NS.PresetData.Build("advanced", "bars", 1920, 1080))
    local n = 0
    for role, want in pairs(SOURCE) do
        n = n + 1
        local spec = specs[role]
        assertTrue(spec ~= nil, "advanced has " .. role)
        local o = spec.overrides
        assertEqual(o.unit, want.unit, role .. " unit")
        assertEqual(o.auraType, want.auraType, role .. " auraType")
        assertEqual(o.style, want.style, role .. " style")
        assertEqual(o.enabled, want.enabled, role .. " enabled")
        assertEqual(o.enabled, role ~= "tsteal", role .. ": only Target stealable starts off")
        sameSet(hiddenSet(o.filter.categories), want.hidden, role)
        local filter = {}
        for k, v in pairs(o.filter) do
            if k ~= "categories" and k ~= "whitelist" and k ~= "blacklist" then filter[k] = v end
        end
        deepEqual(filter, want.filter, role .. ".filter")
        assertEqual(next(o.filter.whitelist), nil, role .. ": no spell ids")
        assertEqual(next(o.filter.blacklist), nil, role .. ": no spell ids")
        local layout = {}
        for k, v in pairs(o.layout) do if k ~= "growV" then layout[k] = v end end
        deepEqual(layout, want.layout, role .. ".layout")
        assertEqual(o.layout.growV, "down", role .. " grows away from its head")
        deepEqual(o.behavior, want.behavior, role .. ".behavior")
    end
    assertEqual(n, 20)
end)

test("presets: every category key exists on this client", function()
    local P = NS.PresetData
    for _, name in ipairs(NAMES) do
        for _, look in ipairs(P.LOOKS) do
            for i, spec in ipairs(P.Build(name, look, 1920, 1080)) do
                local customs = {}
                for _, k in ipairs(spec.customKeys or {}) do customs[k] = true end
                for key in pairs(spec.overrides.filter.categories or {}) do
                    local where = ("%s/%s #%d: %s"):format(name, look, i, key)
                    if CUSTOM[key] then
                        assertEqual(name, "advanced", where .. ": only Advanced names a custom category")
                        assertTrue(customs[key], where .. " is listed in customKeys")
                        assertTrue(P.CUSTOM[key] ~= nil, where .. " is one the preset creates")
                    else
                        assertTrue(NS.Categories.Find("HELPFUL", key) or NS.Categories.Find("HARMFUL", key),
                            where .. " exists on this client")
                    end
                end
            end
        end
    end
    assertEqual(NS.PresetData.CUSTOM.SPECIAL_PLAYER.auraType, "HELPFUL")
    assertEqual(NS.PresetData.CUSTOM.SPECIAL_TARGET.auraType, "HARMFUL")
end)

-- The screen sizes spec section 11 names: three heights, each at 16:9, 16:10 and 21:9.
local SCREENS = {}
for _, h in ipairs({ 768, 1080, 1440 }) do
    for _, ratio in ipairs({ 16 / 9, 16 / 10, 21 / 9 }) do SCREENS[#SCREENS + 1] = { h * ratio, h } end
end

--- A head's span on a W x H parent, out of its stored position and size alone: [left, right] and top
--- (a negative offset from the parent's top edge). A text head's is its stored width, the column: its
--- lines size to fit from the column's left edge (defaults/Presets.lua, sizeTo).
local function headRect(spec, W, H)
    local o, P = spec.overrides, NS.PresetData
    local pos = o.position
    local ax = (pos.relativePoint == "TOPRIGHT") and W or (W / 2)
    assertTrue(pos.relativePoint == "TOPRIGHT" or pos.relativePoint == "TOP", "a head hangs from TOP or TOPRIGHT")
    local w
    if o.style == "bars" then
        w = o.bars.width
    elseif o.style == "icons" then
        w = o.layout.perLine * (o.icons.width + o.layout.spacing)
    else
        w = o.text.width
        assertNear(w, P.STACKS[spec.stack].width * P.Scale(H), 0.5, "a text head is its column wide")
    end
    local x = ax + pos.x
    if pos.point == "TOPRIGHT" then return x - w, x, pos.y end
    assertEqual(pos.point, "TOPLEFT", "a head is placed by a top corner")
    return x, x + w, pos.y
end

-- The pairs of stacks the placement check lets share a column (see the check): a side stack under a
-- corner one. At 1080 the far stack runs 5 units under cornerRight and 210 under cornerLeft on 16:9,
-- 101 and 114 on 16:10, where the right stack also runs 51 under cornerLeft; on 21:9 nothing shares.
local UNDER_CORNER = {}
for _, pair in ipairs({ { "cornerRight", "far" }, { "cornerLeft", "far" }, { "cornerLeft", "right" } }) do
    UNDER_CORNER[pair[1] .. ":" .. pair[2]] = true
    UNDER_CORNER[pair[2] .. ":" .. pair[1]] = true
end

test("presets: placement at 768/1080/1440 x 16:9, 16:10, 21:9", function()
    local P = NS.PresetData
    for _, scr in ipairs(SCREENS) do
        local W, H = scr[1], scr[2]
        local k = P.Scale(H)
        for _, name in ipairs(NAMES) do
            for _, look in ipairs(P.LOOKS) do
                local heads = {}
                for _, spec in ipairs(P.Build(name, look, W, H)) do
                    if not spec.attachTo then
                        local where = ("%s/%s %s at %dx%d"):format(name, look, spec.stack, W, H)
                        assertEqual(spec.overrides.attach.mode, "screen", where)
                        local l, r, top = headRect(spec, W, H)
                        assertTrue(l >= 0, where .. ": left edge on screen (" .. l .. ")")
                        assertTrue(r <= W + 0.001, where .. ": right edge on screen (" .. r .. ")")
                        assertTrue(top >= -0.6 * H, where .. ": above 60% of the height")
                        if spec.stack == "cornerRight" then assertNear(r, W, 1, where .. " hugs the right edge") end
                        heads[#heads + 1] = { l = l, r = r, top = top, stack = spec.stack }
                    end
                end
                -- No two stacks share a column, with one exception the spec's reference numbers make
                -- and the owner has yet to rule on (AM-PR01 review): on 16:9 and 16:10 a side stack
                -- (from y = 330) sits under a corner column (from y = 6). Those pairs alone may share,
                -- and only with that vertical room.
                for i = 1, #heads do
                    for j = i + 1, #heads do
                        local a, b = heads[i], heads[j]
                        local overlap = a.l < b.r and b.l < a.r
                        local what = ("%s/%s: %s and %s share a column at %dx%d"):format(name, look, a.stack,
                            b.stack, W, H)
                        if overlap and UNDER_CORNER[a.stack .. ":" .. b.stack] then
                            assertTrue(math.abs(a.top - b.top) >= 300 * k, what)
                        else
                            assertTrue(not overlap, what)
                        end
                    end
                end
            end
        end
    end
end)

test("presets: members chain", function()
    local P = NS.PresetData
    for _, name in ipairs(NAMES) do
        for _, look in ipairs(P.LOOKS) do
            local last = {}
            for i, spec in ipairs(P.Build(name, look, 1920, 1080)) do
                local a = spec.overrides.attach
                assertTrue(a.mode ~= "frame", name .. " #" .. i .. ": never a frame")
                assertTrue(a.frame == nil or a.frame == "", name .. " #" .. i .. ": no frame name")
                if last[spec.stack] then
                    assertEqual(spec.attachTo, last[spec.stack], name .. " #" .. i .. " attaches to the one above")
                    assertEqual(a.mode, "container")
                    assertNil(spec.overrides.position, name .. " #" .. i .. ": a member is not placed")
                    assertTrue(a.y < 0, "a small gap below the one above")
                else
                    assertNil(spec.attachTo, name .. " #" .. i .. " heads its stack")
                    assertTrue(spec.overrides.position ~= nil, "a head is placed")
                end
                last[spec.stack] = i
            end
        end
    end
end)

test("presets: advanced stacks follow the mockup", function()
    local want = {
        "cornerRight:pbuffs", "cornerRight:wpn", "cornerLeft:pdebuffs",
        "middle:txtOff", "middle:txtDef", "middle:txtRaid",
        "left:pshort", "left:pcd", "left:pspec",
        "right:tdeb", "right:tbuff", "right:tcc", "right:tcdp", "right:tcdn", "right:tspec", "right:tsteal",
        "far:ticoD", "far:ticoB", "far:fdeb", "far:fbuff",
    }
    local got = {}
    for i, spec in ipairs(NS.PresetData.Build("advanced", "bars", 1920, 1080)) do got[i] = spec.stack .. ":" .. spec.role end
    assertEqual(table.concat(got, ","), table.concat(want, ","))
end)

test("presets: scale fallback", function()
    local P = NS.PresetData
    assertEqual(P.REF_H, 1080)
    assertEqual(P.Scale(nil), 1)
    assertEqual(P.Scale(0), 1)
    assertEqual(P.Scale("tall"), 1)
    assertEqual(P.Scale(1080), 1)
    assertNear(P.Scale(768), 0.711, 0.001)
    -- The fallback places at 1080: a nil height builds what a 1080-tall parent builds.
    local a, b = P.Build("simple", "bars", nil, nil), P.Build("simple", "bars", 1920, 1080)
    deepEqual(a[1].overrides.position, b[1].overrides.position, "fallback")
end)

test("presets: icons variant", function()
    local P = NS.PresetData
    local bars = byRole(P.Build("advanced", "bars", 1920, 1080))
    local icons = byRole(P.Build("advanced", "icons", 1920, 1080))
    for role, b in pairs(bars) do
        local i = icons[role]
        if b.overrides.style == "bars" then
            assertEqual(i.overrides.style, "icons", role)
            assertEqual(i.overrides.layout.axis, "horizontal", role)
            assertTrue(i.overrides.layout.perLine >= 1, role .. " fills its column")
            local wantH = (b.stack == "cornerRight" or b.stack == "cornerLeft") and "left" or "right"
            assertEqual(i.overrides.layout.growH, wantH, role .. " grows away from the edge it sits nearest")
            deepEqual(i.overrides.filter, b.overrides.filter, role .. " keeps its filter")
        end
    end
    for _, role in ipairs({ "txtOff", "txtDef", "txtRaid", "ticoD", "ticoB" }) do
        deepEqual(icons[role].overrides, bars[role].overrides, role .. " is the same in both")
    end
end)

test("presets: names follow the data", function()
    local P = NS.PresetData
    for _, name in ipairs(NAMES) do
        local seen = {}
        for _, spec in ipairs(P.Build(name, "bars", 1920, 1080)) do
            local o = spec.overrides
            assertTrue(type(o.name) == "string" and o.name ~= "", name .. ": named")
            assertTrue(not seen[o.name], name .. ": " .. o.name .. " is used once")
            seen[o.name] = true
            if o.name:find("(mine)", 1, true) then
                assertEqual(o.filter.castBy, "mine", name .. ": " .. o.name)
            end
            if o.name:find("(all)", 1, true) then
                assertEqual(o.filter.castBy, "any", name .. ": " .. o.name)
            end
        end
    end
end)

test("presets: intermediate's target cooldowns merge Advanced's two", function()
    local P = NS.PresetData
    local adv = byRole(P.Build("advanced", "bars", 1920, 1080))
    local tcd = byRole(P.Build("intermediate", "bars", 1920, 1080)).tcd
    assertTrue(tcd ~= nil, "intermediate has tcd")
    local f = tcd.overrides.filter
    assertEqual(f.unitFilter.kind, "all")
    for zone, on in pairs(f.zones) do assertTrue(on, "zone " .. zone .. " on") end
    -- The union of what the two show is the intersection of what they hide.
    local hp, hn = hiddenSet(adv.tcdp.overrides.filter.categories), hiddenSet(adv.tcdn.overrides.filter.categories)
    local want = {}
    for key in pairs(hp) do if hn[key] and not CUSTOM[key] then want[#want + 1] = key end end
    sameSet(hiddenSet(f.categories), want, "tcd")
end)

test("presets: healer's category states (spec 3.1)", function()
    local P = NS.PresetData
    local h = byRole(P.Build("healer", "bars", 1920, 1080))
    local adv = byRole(P.Build("advanced", "bars", 1920, 1080))
    for _, role in ipairs({ "healTarget", "healFocus" }) do
        local o = h[role].overrides
        assertEqual(o.auraType, "HELPFUL", role)
        assertEqual(o.filter.castBy, "mine", role)
        assertEqual(next(hiddenSet(o.filter.categories)), nil, role .. " shows every category")
    end
    assertEqual(h.healTarget.overrides.unit, "target")
    assertEqual(h.healFocus.overrides.unit, "focus")
    for _, role in ipairs({ "dispelTarget", "dispelFocus" }) do
        local o = h[role].overrides
        assertEqual(o.auraType, "HARMFUL", role)
        assertEqual(o.filter.castBy, "any", role)
        for _, def in ipairs(NS.Categories.For("HARMFUL")) do
            if not def.userCategory then
                assertEqual(o.filter.categories[def.key], def.key == "raid" and "show" or "hide", role .. " " .. def.key)
            end
        end
    end
    local hidden = hiddenSet(h.pcdHealer.overrides.filter.categories)
    assertNil(hidden.healing, "healer cooldowns show healing")
    assertNil(hidden.raidCDs, "healer cooldowns show raid cooldowns")
    for key in pairs(hiddenSet(adv.pcd.overrides.filter.categories)) do
        if key ~= "healing" and key ~= "raidCDs" and not CUSTOM[key] then assertTrue(hidden[key], key) end
    end
    deepEqual(h.txtRaid.overrides.filter, (function()
        local f = {}
        for k, v in pairs(adv.txtRaid.overrides.filter) do f[k] = v end
        local cats = {}
        for key, state in pairs(f.categories) do if not CUSTOM[key] then cats[key] = state end end
        f.categories = cats
        return f
    end)(), "healer's raid cooldowns are Advanced's")
end)

test("presets: a build is a fresh copy", function()
    local P = NS.PresetData
    local a = P.Build("simple", "bars", 1920, 1080)
    a[1].overrides.filter.castBy = "others"
    a[1].overrides.filter.categories.weaponEnchants = "show"
    local b = P.Build("simple", "bars", 1920, 1080)
    assertEqual(b[1].overrides.filter.castBy, "any")
    assertEqual(b[1].overrides.filter.categories.weaponEnchants, "hide")
end)

-- A key a container does not hold reads as Show (modules/FilterCompiler.lua, splitCategories), so a
-- role that shows only some categories must hide the player's own as well, as the source hid the
-- owner's. A leftover Special player buffs (an earlier Advanced) is the player's own to every other
-- preset; Advanced reuses it and leaves it to SPECIAL_PLAYER.
test("presets: a role that shows only some categories hides the player's own", function()
    local E = freshEnv()
    local procs = E.Categories.CreateUserCategory("My procs", "HELPFUL")
    local marks = E.Categories.CreateUserCategory("My marks", "HARMFUL")
    local special = E.Categories.CreateUserCategory("Special player buffs", "HELPFUL")
    assertTrue(procs and marks and special, "three custom categories")
    local P = E.PresetData
    for _, look in ipairs(P.LOOKS) do
        local adv = byRole(P.Build("advanced", look, 1920, 1080))
        local function state(role, key) return adv[role].overrides.filter.categories[key] end
        for _, role in ipairs({ "wpn", "txtOff", "txtDef", "txtRaid", "pcd", "pspec", "tcdp", "tcdn", "tsteal" }) do
            assertEqual(state(role, procs), "hide", look .. " " .. role .. " hides My procs")
            assertNil(state(role, special), look .. " " .. role .. ": the reused category is SPECIAL_PLAYER's")
        end
        for _, role in ipairs({ "tcc", "tspec" }) do
            assertEqual(state(role, marks), "hide", look .. " " .. role .. " hides My marks")
        end
        for _, role in ipairs({ "pbuffs", "pshort", "tbuff", "ticoB", "fbuff" }) do
            assertTrue(state(role, procs) ~= "hide", look .. " " .. role .. " shows My procs")
        end
        for _, role in ipairs({ "pdebuffs", "tdeb", "ticoD", "fdeb" }) do
            assertTrue(state(role, marks) ~= "hide", look .. " " .. role .. " shows My marks")
        end
        assertEqual(state("pspec", "SPECIAL_PLAYER"), "show", look .. ": Player special shows its own")
        assertEqual(state("wpn", "SPECIAL_PLAYER"), "hide", look .. ": Weapon enchants hides it")
        assertEqual(P.CustomKeyOf(E.Categories.Find("HELPFUL", special)), "SPECIAL_PLAYER")
        assertNil(P.CustomKeyOf(E.Categories.Find("HELPFUL", procs)), "My procs is the player's")

        local simple = byRole(P.Build("simple", look, 1920, 1080))
        assertEqual(simple.wpn.overrides.filter.categories[special], "hide",
            look .. ": a leftover Special player buffs hides in Simple's Weapon enchants")
        assertTrue(simple.pbuffs.overrides.filter.categories[special] ~= "hide", look .. ": and shows in its buffs")
        assertEqual(byRole(P.Build("intermediate", look, 1920, 1080)).tcd.overrides.filter.categories[procs],
            "hide", look .. ": Intermediate's Target cooldowns hides My procs")

        local heal = byRole(P.Build("healer", look, 1920, 1080))
        for _, role in ipairs({ "dispelTarget", "dispelFocus" }) do
            local cats = heal[role].overrides.filter.categories
            assertEqual(cats[marks], "hide", look .. " " .. role .. " hides My marks")
            assertEqual(cats.raid, "show", look .. " " .. role .. " shows raid")
        end
        assertEqual(heal.pcdHealer.overrides.filter.categories[special], "hide", look .. ": healer cooldowns")
        assertTrue(heal.healTarget.overrides.filter.categories[procs] ~= "hide", look .. ": heals show every category")
    end
end)
