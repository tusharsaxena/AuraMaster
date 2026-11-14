-- tests/test_presets_data.lua -- the preset data and the pure placement builder (AM-PR01; spec
-- sections 3, 3.1, 3.2 and 4). Build reads nothing but its arguments and the category lists, so these
-- cases share the runner's environment, except the one that creates the player's own categories
-- and the placement check, which applies each preset to measure its stacks in test mode; each builds
-- its own (tests/fresh_env.lua). Every case runs under both kit profiles, so the
-- category check is the per-client one clients-§6 asks for.

local freshEnv = dofile("tests/fresh_env.lua")

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil, assertNear =
    T.test, T.assertEqual, T.assertTrue, T.assertNil, T.assertNear
local NS = T.NS

local NAMES = { "empty", "simple", "intermediate", "advanced", "healer" }
local CUSTOM = { SPECIAL_PLAYER = true, SPECIAL_TARGET = true }
-- The side stacks, which grow up from their base (spec section 15).
local UP = { left = true, right = true, far = true }

-- The 20 containers of docs/superpowers/specs/2026-11-14-presets/advanced-source.md, transcribed:
-- per role, the categories the source hides, then its filter (without the spell lists), its layout
-- (without growV, which spec sections 3 and 15 turn away from the stack's head) and its behavior.
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
        assertEqual(o.layout.growV, UP[spec.stack] and "up" or "down", role .. " grows away from its head")
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

-- The screen sizes: three heights, each at the ratios spec section 11 names (16:9, 16:10, 21:9) and
-- the narrow ones (4:3, 5:4; 1024 x 768 is a UI-scale-off 4:3).
local SCREENS = {}
for _, h in ipairs({ 768, 1080, 1440 }) do
    for _, ratio in ipairs({ 16 / 9, 16 / 10, 21 / 9, 4 / 3, 5 / 4 }) do SCREENS[#SCREENS + 1] = { h * ratio, h } end
end

--- A head's span on a W x H parent, out of its stored position and size alone: [left, right] and the
--- y it is placed at (a negative offset from the parent's top edge): its top, or for an up stack's head
--- its bottom, the column's base. A text head's is its stored width, the column, centered on the
--- center line it hangs from by its TOP (defaults/Presets.lua, sizeTo and place).
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
        assertNear(w, P.STACKS[spec.stack].width * P.ScaleX(W, H), 1, "a text head is its column wide")
    end
    local x = ax + pos.x
    if pos.point == "TOP" then return x - w / 2, x + w / 2, pos.y end
    if pos.point:find("RIGHT$") then return x - w, x, pos.y end
    assertTrue(pos.point == "TOPLEFT" or pos.point == "BOTTOMLEFT", "a head is placed by a corner")
    return x, x + w, pos.y
end

-- A CORNER COLUMN MAY RUN OVER A SIDE COLUMN (spec sections 4, 11 and 15, the plan's ruling on the
-- AM-PR01 review). By the spec 4 numbers the far stack sits under both corner columns on 16:9, the
-- right stack under cornerLeft on 16:10 as well, and on 4:3 and 5:4 the right and far stacks run under
-- the corners entirely. The corner stacks grow down from y = 46 and the side stacks grow up from
-- their base at y = 740 (spec section 15.1), so every corner stack must end above every side
-- stack's base. The check measures that at the test-mode sample count: every container of the preset
-- applied, each as tall as
-- Preview.Extent makes its placeholder block, each stack member hung from the one before by its gap,
-- below it growing down and above it growing up. Every other pair of columns stays disjoint. A tall
-- side stack (Advanced's target stack) may reach up into a corner column, and in play a corner stack
-- may grow further down (docs/known-limitations.md, presets).
local CORNER = { cornerRight = true, cornerLeft = true }
local SIDE = { left = true, right = true, far = true }

local function cornerOverSide(a, b)
    return (CORNER[a] and SIDE[b]) or (CORNER[b] and SIDE[a]) or false
end

--- The y offset container `id`'s anchor is placed at from what it hangs from, read off the live
--- placement (Anchors.Place): the stored gap plus the seam and, while unlocked, the drag strip's room
--- (modules/Anchors_Attach.lua seamRoom).
local function placedOffset(env, id)
    local inst = env.ContainerManager.instances[id]
    local rec = {}
    rawset(inst.anchor, "SetPoint", function(_, ...) rec[#rec + 1] = { ... } end)
    env.Anchors.Place(inst)
    rawset(inst.anchor, "SetPoint", nil)
    return rec[#rec][5], inst
end

--- One container's span from what it hangs from (`parent`, nil for a head), its stored data `c`, its
--- placed y offset `dy` and its test-mode block's height `h`; while `unlocked`, `room` is its own
--- strip row, which sits on the side its auras start from (Anchors.StripPoints). A head's room is
--- added to the span (a member's is already in its offset, between it and its parent).
local function spanFrom(parent, c, dy, h, room)
    local up = c.layout.growV == "up"
    local edge
    if parent then
        edge, room = up and parent.top + dy or parent.bottom + dy, 0
    else
        edge = c.position.y
    end
    if up then return { top = edge + h, bottom = edge - room } end
    return { top = edge + room, bottom = edge - h }
end

--- Each stack's test-mode span with preset `name` in style `look` applied on a W x H parent in `env`,
--- every container filled with its test-mode samples: [stack] = { top, bottom }, offsets from the
--- parent's top (negative is down). A head placed by a BOTTOM point starts at its base and grows up;
--- a member hangs below the one before it growing down, above it growing up, at its live placement's
--- offset. `unlocked` measures with the containers unlocked, their drag strips shown, as the preset
--- picker opens them (spec section 15); otherwise locked.
local function sampleSpans(env, mocks, name, look, W, H, unlocked)
    env.Presets.ParentSize = function() return W, H end
    assertTrue(env.Presets.Apply(name, look, "replace"), name .. "/" .. look .. " applies")
    env.SetByPath("locked", not unlocked)
    env.Preview.SetTestMode(true)
    mocks.__fireTimers()
    local specs, p = env.PresetData.Build(name, look, W, H), env.db.profile
    assertEqual(#p.containerOrder, #specs, "one container per spec, in creation order")
    local spanOf, out = {}, {}
    for i, id in ipairs(p.containerOrder) do
        local c = p.containers[id]
        local extent = env.Preview.Extent({ Cfg = function() return c end, anchor = mocks.CreateFrame("Frame") })
        local parent = (c.attach.mode == "container") and spanOf[tonumber(c.attach.container)]
        local dy, inst = placedOffset(env, id)
        -- A disabled container (Advanced's tsteal, as the source stores it) shows nothing, test mode
        -- or not (ShouldShow): no height, and no part of its stack's span.
        local shown = c.enabled ~= false
        assertEqual(inst.stripShown == true, shown and unlocked == true, "the strip shows while unlocked")
        local span = spanFrom(parent, c, dy, shown and extent.height or 0, env.AnchorsAttach.furnitureRoom(inst))
        spanOf[id] = span
        local stack = specs[i].stack
        local whole = out[stack] or (shown and { top = span.top, bottom = span.bottom })
        if shown then
            whole.top, whole.bottom = math.max(whole.top, span.top), math.min(whole.bottom, span.bottom)
        end
        out[stack] = whole
    end
    env.Preview.SetTestMode(false)
    env.SetByPath("locked", true)
    mocks.__fireTimers()
    return out
end

--- Every corner stack ends above every side stack's base in test mode (`spans`, from sampleSpans;
--- `heads`, each head's placed y by stack).
local function checkCornersAboveBases(spans, heads, what)
    for corner in pairs(CORNER) do
        for side in pairs(SIDE) do
            if spans[corner] and heads[side] then
                local why = "%s: %s must end above %s's base (corner bottom %d, side base %d)"
                assertTrue(spans[corner].bottom > heads[side], why:format(what, corner, side,
                    spans[corner].bottom, heads[side]))
            end
        end
    end
end

-- THE TOP EDGE (the AM-PR09 review, tightened on AM-PR12 to the lower base of spec section 15.1).
-- Every stack's test-mode span, locked and unlocked (as the preset picker opens the containers, each
-- drag strip adding its room), stays on the screen: at or under its top edge. At 1080 tall that now
-- holds for every stack, Advanced's Bars target stack (six shown containers about 620 tall with their
-- samples; the seventh, tsteal, is stored off) included: 16 under the top edge unlocked. But one,
-- recorded in docs/known-limitations.md (presets) for the owner's call: that stack cannot fit a
-- 768-tall screen above the base, 88 over its top locked and 188 unlocked. Each entry is the most it
-- may run over, so the overshoot cannot grow unnoticed, and the case fails too once the stack fits.
local OFF_TOP = { ["advanced/bars right 768"] = 88 }
local OFF_TOP_UNLOCKED = { ["advanced/bars right 768"] = 188 }

--- Every stack in `spans` (sampleSpans; `unlocked` as it was measured) ends at or under the top edge,
--- but those its OFF_TOP table names.
local function checkTopEdge(spans, name, look, W, H, unlocked)
    local off = unlocked and OFF_TOP_UNLOCKED or OFF_TOP
    for stack, span in pairs(spans) do
        local key, where = ("%s/%s %s %d"):format(name, look, stack, H), ("%s/%s %s at %dx%d%s"):format(name,
            look, stack, W, H, unlocked and ", unlocked" or "")
        if off[key] then
            assertTrue(span.top > 0, where .. " now fits under the top edge: drop it from OFF_TOP and the limitation")
            assertTrue(span.top <= off[key], ("%s runs %d over the top edge, past its recorded %d"):format(where,
                span.top, off[key]))
        else
            assertTrue(span.top <= 0, where .. ": its test-mode top is on screen (" .. span.top .. ")")
        end
    end
end

--- Heads `a` and `b` on one screen: disjoint columns, or a corner column over a side one.
local function checkColumns(a, b, what)
    if not (a.l < b.r and b.l < a.r) then return end
    assertTrue(cornerOverSide(a.stack, b.stack), what .. " (only a corner over a side column may share)")
end

test("presets: placement at 768/1080/1440 x 16:9, 16:10, 21:9, 4:3, 5:4", function()
    local P = NS.PresetData
    local env, mocks = freshEnv()
    env.Helpers.SkinPicker = function() return nil end
    for _, scr in ipairs(SCREENS) do
        local W, H = scr[1], scr[2]
        for _, name in ipairs(NAMES) do
            for _, look in ipairs(P.LOOKS) do
                local heads, placedY = {}, {}
                for _, spec in ipairs(P.Build(name, look, W, H)) do
                    if not spec.attachTo then
                        local where = ("%s/%s %s at %dx%d"):format(name, look, spec.stack, W, H)
                        assertEqual(spec.overrides.attach.mode, "screen", where)
                        local l, r, y = headRect(spec, W, H)
                        assertTrue(l >= 0, where .. ": left edge on screen (" .. l .. ")")
                        assertTrue(r <= W + 0.001, where .. ": right edge on screen (" .. r .. ")")
                        assertTrue(y <= 0, where .. ": head or base below the top edge")
                        assertTrue(y >= -0.7 * H, where .. ": above 70% of the height")
                        if spec.stack == "cornerRight" then
                            assertNear(r, W - 80 * P.ScaleX(W, H), 1, where .. " sits 80 in from the right edge")
                        end
                        heads[#heads + 1] = { l = l, r = r, stack = spec.stack }
                        placedY[spec.stack] = y
                    end
                end
                for i = 1, #heads do
                    for j = i + 1, #heads do
                        local a, b = heads[i], heads[j]
                        checkColumns(a, b, ("%s/%s: %s and %s share a column at %dx%d"):format(name, look,
                            a.stack, b.stack, W, H))
                    end
                end
                if #heads > 0 then
                    local spans = sampleSpans(env, mocks, name, look, W, H)
                    checkTopEdge(spans, name, look, W, H)
                    checkTopEdge(sampleSpans(env, mocks, name, look, W, H, true), name, look, W, H, true)
                    if placedY.cornerRight and (placedY.left or placedY.right or placedY.far) then
                        checkCornersAboveBases(spans, placedY, ("%s/%s at %dx%d"):format(name, look, W, H))
                    end
                end
            end
        end
    end
end)

-- SPEC SECTION 15, the owner's round-1 feedback: the side stacks grow up from their base, the corner
-- group sits further in, the call-outs are centered and colored like the owner's.

--- Each container of preset `name` in style `look`, applied on a 1920 x 1080 parent in `env`, with
--- its spec: { cfg, spec } in creation order.
local function applied(env, name, look)
    env.Presets.ParentSize = function() return 1920, 1080 end
    assertTrue(env.Presets.Apply(name, look, "replace"), name .. "/" .. look .. " applies")
    local specs, p, out = env.PresetData.Build(name, look, 1920, 1080), env.db.profile, {}
    for i, id in ipairs(p.containerOrder) do out[i] = { cfg = p.containers[id], spec = specs[i] } end
    return out
end

-- The base (spec section 15.1): about 340 reference units above the bottom edge, y = -740 from the top
-- at 1080 tall, scaled by k.
local SIDE_BASE = -740

test("presets data: side stacks sit on the lower base", function()
    local P = NS.PresetData
    for _, H in ipairs({ 768, 1080, 1440 }) do
        local k = P.Scale(H)
        for _, name in ipairs(NAMES) do
            for _, look in ipairs(P.LOOKS) do
                for _, spec in ipairs(P.Build(name, look, H * 16 / 9, H)) do
                    if UP[spec.stack] and not spec.attachTo then
                        local where = ("%s/%s %s at %d"):format(name, look, spec.role, H)
                        -- red under: the AM-PR09 base, 640 down
                        assertEqual(spec.overrides.position.y, math.floor(SIDE_BASE * k + 0.5), where .. " on the base")
                        assertNear(H + spec.overrides.position.y, 340 * k, 1, where .. ": 340 above the bottom")
                    end
                end
            end
        end
    end
end)

test("presets data: side stacks grow up from their base", function()
    local env = freshEnv()
    env.Helpers.SkinPicker = function() return nil end
    local P = env.PresetData
    for _, H in ipairs({ 768, 1080, 1440 }) do
        for _, name in ipairs(NAMES) do
            for _, look in ipairs(P.LOOKS) do
                for _, spec in ipairs(P.Build(name, look, H * 16 / 9, H)) do
                    local o, where = spec.overrides, ("%s/%s %s at %d"):format(name, look, spec.role, H)
                    if UP[spec.stack] then
                        assertEqual(o.layout.growV, "up", where .. " grows up")
                        if spec.attachTo then
                            assertTrue(o.attach.y > 0, where .. ": its gap is above the one before")
                        else
                            assertTrue(o.position.point:find("^BOTTOM") ~= nil, where .. " is placed by a BOTTOM point")
                            assertEqual(o.position.relativePoint, "TOP", where)
                            assertEqual(o.position.y, math.floor(SIDE_BASE * P.Scale(H) + 0.5), where .. " sits on the base")
                        end
                    else
                        assertEqual(o.layout.growV, "down", where .. " grows down")
                    end
                end
            end
        end
    end
    -- Applied, each member joins the top of the one before it, from the side its stack's lines start.
    for _, name in ipairs({ "intermediate", "advanced", "healer" }) do
        for _, look in ipairs(P.LOOKS) do
            for _, e in ipairs(applied(env, name, look)) do
                if UP[e.spec.stack] and e.spec.attachTo then
                    local point, rel = env.Anchors.AttachPoints(e.cfg)
                    -- A member flows as its stack's head does (Anchors.EffectiveLayout).
                    local h = (env.Anchors.EffectiveLayout(e.cfg).growH == "left") and "RIGHT" or "LEFT"
                    local where = name .. "/" .. look .. " " .. e.spec.role
                    assertEqual(point, "BOTTOM" .. h, where .. ": its bottom corner")
                    assertEqual(rel, "TOP" .. h, where .. ": to the top corner of the one before")
                end
            end
        end
    end
    -- The tier's first role sits nearest the base: Advanced's player stack starts with its short buffs.
    local adv = byRole(P.Build("advanced", "bars", 1920, 1080))
    assertNil(adv.pshort.attachTo, "Player buffs, short is the player stack's base")
    assertEqual(adv.pcd.attachTo, adv.pshort.index, "Player cooldowns sits on it")
end)

test("presets data: the corner group sits left of and below its old place", function()
    local P = NS.PresetData
    local S = P.STACKS
    assertEqual(S.cornerRight.x, -175 - 80, "Player buffs' column 80 further left")
    assertEqual(S.cornerLeft.x, -395 - 80, "Player debuffs' column 80 further left")
    assertEqual(S.cornerRight.y, -6 - 40, "40 further down")
    assertEqual(S.cornerLeft.y, -6 - 40, "40 further down")
    local simple = byRole(P.Build("simple", "bars", 1920, 1080))
    local pos = simple.pbuffs.overrides.position
    assertEqual(pos.relativePoint, "TOPRIGHT")
    assertEqual(pos.point, "TOPLEFT")
    assertEqual(pos.x, -255)
    assertEqual(pos.y, -46)
    assertEqual(simple.pdebuffs.overrides.position.x, -475)
    -- Still a corner group: it grows down, and the members hang below their heads.
    assertEqual(simple.wpn.overrides.layout.growV, "down")
    assertTrue(simple.wpn.overrides.attach.y < 0, "Weapon enchants hangs below Player buffs")
end)

local CALLOUT_COLORS = {
    txtOff = { 0.1, 1, 0.1 }, txtDef = { 1, 0.125, 0.125 }, txtRaid = { 1, 0.486, 0.04 },
}

test("presets data: the call-outs are centered and colored like the owner's", function()
    local P = NS.PresetData
    for _, name in ipairs({ "advanced", "healer" }) do
        for _, look in ipairs(P.LOOKS) do
            local first
            for _, spec in ipairs(P.Build(name, look, 1920, 1080)) do
                if spec.stack == "middle" then
                    local t, where = spec.overrides.text, name .. "/" .. look .. " " .. spec.role
                    local want = CALLOUT_COLORS[spec.role]
                    assertTrue(want ~= nil, where .. " is a call-out")
                    assertEqual(t.justifyH, "CENTER", where .. " centered")
                    assertEqual(t.template, "$spellname$", where .. ": the name alone")
                    assertEqual(t.font.fontColorFromSkin, false, where .. ": its own color")
                    assertEqual(t.font.useClassColorFont, false, where)
                    assertNear(t.font.fontColor.r, want[1], 0.0001, where .. " red")
                    assertNear(t.font.fontColor.g, want[2], 0.0001, where .. " green")
                    assertNear(t.font.fontColor.b, want[3], 0.0001, where .. " blue")
                    assertEqual(t.glow, true, where .. " glows")
                    assertEqual(t.glowColor.r + t.glowColor.g + t.glowColor.b, 0, where .. ": a black glow")
                    assertEqual(t.glowColorFromSkin, false, where)
                    assertEqual(t.glowThickness, 6, where .. ": radius 6")
                    assertEqual(t.glowX, 1, where)
                    assertEqual(t.glowY, -1, where)
                    assertEqual(spec.overrides.label.show, false, where .. ": no label")
                    assertTrue(t.font.fontSize >= 24 and t.font.fontSize <= 36, where .. ": 24 to 36")
                    if first then
                        assertEqual(t.font.fontSize, first.overrides.text.font.fontSize, where .. ": one size")
                    else
                        first = spec
                        local pos = spec.overrides.position
                        assertEqual(pos.point, "TOP", where .. " hangs by its top")
                        assertEqual(pos.relativePoint, "TOP", where)
                        assertEqual(pos.x, 0, where .. ": on the center line")
                    end
                end
            end
            assertTrue(first ~= nil, name .. " has call-outs")
        end
    end
    -- Nothing else carries a look of its own.
    for _, spec in ipairs(P.Build("advanced", "bars", 1920, 1080)) do
        if spec.stack ~= "middle" then
            assertNil(spec.overrides.text, spec.role .. ": no text look")
            assertNil(spec.overrides.label, spec.role .. ": no label look")
        end
    end
    -- Applied, the look is stored, and each call-out joins the one above it at its center.
    local env = freshEnv()
    env.Helpers.SkinPicker = function() return nil end
    local seen = 0
    for _, e in ipairs(applied(env, "advanced", "bars")) do
        if e.spec.stack == "middle" then
            seen = seen + 1
            local t = e.cfg.text
            assertEqual(t.justifyH, "CENTER", e.spec.role .. " stored centered")
            assertNear(t.font.fontColor.r, CALLOUT_COLORS[e.spec.role][1], 0.0001, e.spec.role .. " stored color")
            assertEqual(e.cfg.label.show, false)
            if e.spec.attachTo then
                local point, rel = env.Anchors.AttachPoints(e.cfg)
                assertEqual(point, "TOP", e.spec.role .. " joins by its top center")
                assertEqual(rel, "BOTTOM", e.spec.role .. " to the bottom center of the one above")
            end
        end
    end
    assertEqual(seen, 3, "three call-outs")
end)

--- The room the call-out block may take on a `H` tall parent (spec section 15.1): from a margin below
--- the pickers' shared rectangle (centered `skinShare` of the way up, as tall as the taller of the
--- two) down to a margin above the bottom edge, as offsets from the top edge.
local function calloutRoom(P, H)
    local R = P.ROOM
    return H * (1 - R.skinShare) + math.max(R.skinHeight, R.pickerHeight) / 2 + R.margin, H - R.margin
end

test("presets data: the call-out block takes the largest font that fits, centered as far as it can", function()
    -- Its own environment: the case narrows the size range to probe the next size up.
    local P = freshEnv().PresetData
    assertEqual(P.CALLOUT_SIZE_MAX, 36, "the owner's size")
    assertEqual(P.CALLOUT_SIZE_MIN, 24)
    assertNil(P.CalloutRect("simple", "bars", 1920, 1080), "Simple has no call-outs")
    assertNil(P.CalloutRect("intermediate", "icons", 1920, 1080), "nor Intermediate")
    local max, min = P.CALLOUT_SIZE_MAX, P.CALLOUT_SIZE_MIN
    for _, H in ipairs({ 768, 1080, 1440 }) do
        for _, name in ipairs({ "advanced", "healer" }) do
            local W, where = H * 16 / 9, ("%s at %d"):format(name, H)
            local r = P.CalloutRect(name, "bars", W, H)
            local lo, hi = calloutRoom(P, H)
            local top, bottom = H - r.top, H - r.bottom
            assertNear(r.height, bottom - top, 0.001, where .. ": the rect is the block")
            assertNear((r.left + r.right) / 2, W / 2, 0.001, where .. ": centered across")
            assertTrue(top >= 0 and bottom <= H, where .. ": on the screen")
            -- The size above the one chosen does not fit (falsifiable: the room decides the size).
            if r.fontSize < max then
                P.CALLOUT_SIZE_MAX, P.CALLOUT_SIZE_MIN = r.fontSize + 1, r.fontSize + 1
                local bigger = P.CalloutRect(name, "bars", W, H)
                P.CALLOUT_SIZE_MAX, P.CALLOUT_SIZE_MIN = max, min
                assertTrue(bigger.height > hi - lo, where .. ": one size larger would not fit")
            end
            if r.height <= hi - lo then
                assertTrue(top >= lo - 0.5, where .. ": below the pickers")
                assertTrue(bottom <= hi + 0.5, where .. ": above the bottom edge")
                local want = math.min(math.max(H / 2 - r.height / 2, lo), hi - r.height)
                assertNear(top, want, 0.5, where .. ": as near the middle as the room allows")
            else
                assertEqual(r.fontSize, min, where .. ": nothing fits, so the smallest")
            end
        end
    end
    -- Healer's one call-out fits at the owner's size on a 1080-tall screen, centered on its middle.
    local heal = P.CalloutRect("healer", "bars", 1920, 1080)
    assertEqual(heal.fontSize, 36)
    -- A build in either look places the block the same.
    local bars, icons = P.CalloutRect("advanced", "bars", 1920, 1080), P.CalloutRect("advanced", "icons", 1920, 1080)
    assertEqual(bars.top, icons.top)
    assertEqual(bars.fontSize, icons.fontSize)
    -- The fallback places at 1920 x 1080.
    local fb = P.CalloutRect("healer", "bars", nil, nil)
    assertEqual(fb.top, heal.top)
    assertEqual(fb.left, heal.left)
end)

-- The rect is the block the preset picker opens on: unlocked, each drag strip shown (the AM-PR09
-- review: a locked measure left out a strip row above the head and one per member, 60 at 1080 for
-- Advanced). Measured off the live placement, so a seam or a strip the builder misses shows here.
test("presets data: the call-out rect is what the applied containers fill in test mode, unlocked", function()
    local env, mocks = freshEnv()
    env.Helpers.SkinPicker = function() return nil end
    local P = env.PresetData
    for _, H in ipairs({ 768, 1080, 1440 }) do
        for _, name in ipairs({ "advanced", "healer" }) do
            local W, where = H * 16 / 9, ("%s at %d"):format(name, H)
            local r = P.CalloutRect(name, "bars", W, H)
            local open = sampleSpans(env, mocks, name, "bars", W, H, true).middle
            assertNear(r.top, H + open.top, 0.5, where .. ": the block's top, the head's strip")
            assertNear(r.bottom, H + open.bottom, 0.5, where .. ": the block's bottom")
            -- red under: the strip rows left out (the rect 20 short above and 20 per member below)
            local shut = sampleSpans(env, mocks, name, "bars", W, H).middle
            local rows = (P.Count(name) == 20) and 3 or 1
            assertNear(open.top - shut.top, env.Anchors.STRIP_ROW, 0.5, where .. ": one strip row above")
            assertNear((open.top - open.bottom) - (shut.top - shut.bottom), rows * env.Anchors.STRIP_ROW, 0.5,
                where .. ": a strip row per container")
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
                    if UP[spec.stack] then
                        assertTrue(a.y > 0, "a small gap above the one before")
                    else
                        assertTrue(a.y < 0, "a small gap below the one above")
                    end
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

test("presets: the layout narrows across only on a narrow screen", function()
    local P = NS.PresetData
    -- 16:10 and wider: across follows the height alone.
    for _, h in ipairs({ 768, 1080, 1440 }) do
        for _, ratio in ipairs({ 16 / 10, 16 / 9, 21 / 9 }) do
            assertEqual(P.ScaleX(h * ratio, h), P.Scale(h), ("%dx%d"):format(h * ratio, h))
        end
    end
    -- 4:3 at 1080: the far column (570 + 220 right of center) ends 10 units in from the edge.
    local kx = P.ScaleX(1440, 1080)
    assertTrue(kx < 1, "4:3 narrows")
    assertNear(720 + 790 * kx, 1440 - 10 * kx, 0.001, "the far column ends at the edge's margin")
    assertEqual(P.ScaleX(nil, 1080), 1, "an unreadable width does not narrow")
    assertEqual(P.ScaleX(0, nil), 1)
    -- Down is never narrowed: the heads' tops are the same on 4:3 as on 16:9.
    local narrow, wide = P.Build("advanced", "bars", 1440, 1080), P.Build("advanced", "bars", 1920, 1080)
    for i, spec in ipairs(narrow) do
        if spec.overrides.position then
            assertEqual(spec.overrides.position.y, wide[i].overrides.position.y, spec.role .. " top")
        end
    end
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
            -- Right of center grows left, the rest right (spec section 3.2). red under: the right
            -- and far stacks growing toward the right edge they sit nearest
            local rightOfCenter = { cornerRight = true, cornerLeft = true, right = true, far = true }
            local wantH = rightOfCenter[b.stack] and "left" or "right"
            assertEqual(i.overrides.layout.growH, wantH, role .. " grows away from the edge it sits nearest")
            if not b.attachTo and wantH == "left" then
                assertEqual(i.overrides.position.point, UP[b.stack] and "BOTTOMRIGHT" or "TOPRIGHT",
                    role .. " hangs from its column's right edge")
            end
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
