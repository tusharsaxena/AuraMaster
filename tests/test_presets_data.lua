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
-- The side stacks, which grow up from their base (spec section 15), the focus stack among them (spec
-- section 16).
local UP = { left = true, right = true, far = true, focus = true }

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
local SIDE = { left = true, right = true, far = true, focus = true }

-- THE FOCUS COLUMN (spec section 16) hangs from the corner's edge, Player debuffs' left edge, so it
-- shares a column with the far stack (above it, kept clear of it: "the focus stack stays clear of the
-- far stack") and, on most ratios, with the right stack (FOCUS_OVER_RIGHT, below).
local SHARES_WITH_FOCUS = { far = true, right = true }

local function cornerOverSide(a, b)
    if (a == "focus" and SHARES_WITH_FOCUS[b]) or (b == "focus" and SHARES_WITH_FOCUS[a]) then return true end
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
    local last = rec[#rec]
    return last[5], inst, last[4], last[1], last[3]
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

--- A point's horizontal part: "LEFT", "RIGHT", or "" for the middle.
local function hPart(point) return point:match("LEFT$") or point:match("RIGHT$") or "" end

--- The x part `part` (hPart) sits at on span `r`.
local function xOn(r, part)
    if part == "LEFT" then return r.left end
    if part == "RIGHT" then return r.right end
    return (r.left + r.right) / 2
end

--- Fill `span`'s [left, right]: a block `w` wide whose own `point` sits at `x`, and, while unlocked,
--- the drag strip's overhang past it (`over`, Anchors' stripOverhang): the strip starts on the side
--- the auras start from and runs on along the growth (Anchors.StripPoints, placeHandle).
local function spanAcross(span, point, x, w, over, growH)
    local part = hPart(point)
    span.left = (part == "LEFT" and x) or (part == "RIGHT" and x - w) or (x - w / 2)
    span.right = span.left + w
    if over > 0 then
        if growH == "left" then span.left = span.left - over else span.right = span.right + over end
    end
end

--- Widen stack span `whole` (nil for a stack's first) to hold container span `span`.
local function union(whole, span)
    if not whole then return { top = span.top, bottom = span.bottom, left = span.left, right = span.right } end
    whole.top, whole.bottom = math.max(whole.top, span.top), math.min(whole.bottom, span.bottom)
    whole.left, whole.right = math.min(whole.left, span.left), math.max(whole.right, span.right)
    return whole
end

--- The x container `c`'s own point sits at on a W-wide parent: a member's, its parent's relative
--- point (`rel`) moved on by its placed `dx`; a head's, its stored position from TOPRIGHT or TOP.
local function pointX(parent, c, rel, dx, W)
    if parent then return xOn(parent, hPart(rel)) + dx end
    return ((c.position.relativePoint == "TOPRIGHT") and W or W / 2) + c.position.x
end

--- Each stack's test-mode span with preset `name` in style `look` applied on a W x H parent in `env`,
--- every container filled with its test-mode samples: [stack] = { top, bottom, left, right }, top and
--- bottom offsets from the parent's top (negative is down), left and right from its left edge (each
--- block as wide as Preview.BlockSize makes it, joined where its live placement puts it). A head
--- placed by a BOTTOM point starts at its base and grows up; a member hangs below the one before it growing down, above it growing up, at its live placement's
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
    local spanOf, out, each = {}, {}, {}
    for i, id in ipairs(p.containerOrder) do
        local c = p.containers[id]
        local extent = env.Preview.Extent({ Cfg = function() return c end, anchor = mocks.CreateFrame("Frame") })
        local parent = (c.attach.mode == "container") and spanOf[tonumber(c.attach.container)]
        local dy, inst, dx, point, rel = placedOffset(env, id)
        -- A disabled container (Advanced's tsteal, as the source stores it) shows nothing, test mode
        -- or not (ShouldShow): no height, and no part of its stack's span.
        local shown = c.enabled ~= false
        assertEqual(inst.stripShown == true, shown and unlocked == true, "the strip shows while unlocked")
        local span = spanFrom(parent, c, dy, shown and extent.height or 0, env.AnchorsAttach.furnitureRoom(inst))
        local over = unlocked and (inst.stripOverhang or 0) or 0
        spanAcross(span, point, pointX(parent, c, rel, dx, W), (env.Preview.BlockSize(c)), over,
            env.Anchors.EffectiveLayout(c).growH)
        spanOf[id] = span
        local stack = specs[i].stack
        if shown then
            out[stack] = union(out[stack], span)
            each[#each + 1] = { role = specs[i].role, stack = stack, span = span }
        end
    end
    env.Preview.SetTestMode(false)
    env.SetByPath("locked", true)
    mocks.__fireTimers()
    return out, each
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
                            local inset = -(P.STACKS.cornerRight.x + P.STACKS.cornerRight.width)
                            assertNear(r, W - inset * P.ScaleX(W, H), 1, where .. " sits its inset in from the right edge")
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
-- at 1080 tall, scaled by k. The focus stack's own base sits higher, over the far stack's (spec section
-- 16; "the focus stack stays clear of the far stack").
local SIDE_BASE = -740
local FOCUS_BASE = -550
local function baseOf(stack) return (stack == "focus") and FOCUS_BASE or SIDE_BASE end

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
                        local base = baseOf(spec.stack)
                        assertEqual(spec.overrides.position.y, math.floor(base * k + 0.5), where .. " on the base")
                        assertNear(H + spec.overrides.position.y, (1080 + base) * k, 1, where .. ": above the bottom")
                    end
                end
            end
        end
    end
end)

-- The column each up stack's head hangs from: the center line, but the focus column's, which hangs
-- from the corner's point (spec section 16).
local HEAD_POINT = { left = "TOP", right = "TOP", far = "TOP", focus = "TOPRIGHT" }

--- An up stack's spec on a parent `H` tall: a member's gap is above the one before; a head sits on
--- its stack's base by a BOTTOM point.
local function checkUpHead(P, spec, H, where)
    local o = spec.overrides
    if spec.attachTo then
        assertTrue(o.attach.y > 0, where .. ": its gap is above the one before")
        return
    end
    assertTrue(o.position.point:find("^BOTTOM") ~= nil, where .. " is placed by a BOTTOM point")
    assertEqual(o.position.relativePoint, HEAD_POINT[spec.stack], where)
    assertEqual(o.position.y, math.floor(baseOf(spec.stack) * P.Scale(H) + 0.5), where .. " sits on the base")
end

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
                        checkUpHead(P, spec, H, where)
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
    -- Spec section 15 moved it 80 left and 40 down; section 16 moves it further in, Player debuffs'
    -- left edge on the focus column's ("Player debuffs' left edge lines up with Focus buffs'").
    -- red under: section 15's place, Player debuffs' left edge 475 in from the right edge, and under
    -- a token move: the owner asked for one they can see ("bring them in even further"), so the
    -- distance is pinned, 45 further in than section 15's (520 in from the right edge).
    assertTrue(S.cornerLeft.x < -395 - 80, "Player debuffs' column left of section 15's")
    assertEqual(S.cornerLeft.x, -475 - 45, "and 45 further in, a move that shows")
    assertEqual(S.cornerLeft.width, 215, "Player debuffs keeps its width")
    assertEqual(S.cornerRight.width, 175, "Player buffs keeps its width")
    assertEqual(S.cornerRight.x - (S.cornerLeft.x + S.cornerLeft.width), 5, "and the gap between the two")
    assertEqual(S.cornerRight.y, -6 - 40, "40 further down")
    assertEqual(S.cornerLeft.y, -6 - 40, "40 further down")
    local simple = byRole(P.Build("simple", "bars", 1920, 1080))
    local pos = simple.pbuffs.overrides.position
    assertEqual(pos.relativePoint, "TOPRIGHT")
    assertEqual(pos.point, "TOPLEFT")
    assertEqual(pos.x, S.cornerRight.x)
    assertEqual(pos.y, -46)
    assertEqual(simple.pdebuffs.overrides.position.x, S.cornerLeft.x)
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
                    assertEqual(t.glow, true, where .. " glows (its look: the owner's glow exactly)")
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
        "far:ticoD", "far:ticoB", "focus:fdeb", "focus:fbuff",
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
            local rightOfCenter = { cornerRight = true, cornerLeft = true, right = true, far = true, focus = true }
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

-- SPEC SECTION 16, the owner's round-2 feedback: the call-outs' glow, a focus stack of its own, the
-- corner group lined up with it.

-- The owner's own call-out glow (spec section 16.1): every glow leaf the template carries. The
-- owner's list also names glowRadius = 6, glowFalloff = "soft" and glowBlend = "BLEND", the halo
-- leaves the glyph glow retired (TG-09, tests/test_style_text_glow.lua): nothing reads them, so a
-- preset stores none of them (spec section 16.5, note 1).
local OWNER_GLOW = {
    glow = true, glowColorFromSkin = false, useClassColorGlow = false,
    glowIntensity = 1, glowThickness = 2, glowX = 1, glowY = -1,
}
local RETIRED_GLOW = { "glowRadius", "glowFalloff", "glowBlend" }

--- The owner's glow on text settings `t`, for `where`: every OWNER_GLOW leaf, a black glow color,
--- and no retired leaf.
local function checkOwnerGlow(t, where)
    for key, want in pairs(OWNER_GLOW) do
        -- red under: glowThickness 6, round 1's heavy outline
        assertEqual(t[key], want, where .. " " .. key)
    end
    local c = t.glowColor
    assertTrue(type(c) == "table", where .. ": a glow color")
    assertEqual(c.r + c.g + c.b, 0, where .. ": black")
    assertEqual(c.a, 1, where .. ": opaque")
    for _, key in ipairs(RETIRED_GLOW) do assertNil(t[key], where .. ": no " .. key) end
end

test("presets data: the call-outs carry the owner's glow exactly", function()
    local P = NS.PresetData
    -- The list is the template's whole glow: a leaf it left out would come from the template.
    for key in pairs(NS.CONTAINER_TEMPLATE.text) do
        if key:find("^glow") or key == "useClassColorGlow" then
            assertTrue(OWNER_GLOW[key] ~= nil or key == "glowColor", key .. " is one of the owner's glow fields")
        end
    end
    local env = freshEnv()
    env.Helpers.SkinPicker = function() return nil end
    for _, name in ipairs({ "advanced", "healer" }) do
        for _, look in ipairs(P.LOOKS) do
            for _, e in ipairs(applied(env, name, look)) do
                if e.spec.stack == "middle" then
                    local where = name .. "/" .. look .. " " .. e.spec.role
                    local t = e.spec.overrides.text
                    -- Stated in the preset, so no template or skin default stands in for one.
                    for key in pairs(OWNER_GLOW) do assertTrue(t[key] ~= nil, where .. " states " .. key) end
                    checkOwnerGlow(t, where)
                    checkOwnerGlow(e.cfg.text, where .. ", stored")
                end
            end
        end
    end
end)

-- The roles that watch the focus, and the presets that have them (spec section 16.2).
local FOCUS_ROLES = { fdeb = true, fbuff = true, healFocus = true, dispelFocus = true }
local WITH_FOCUS = { "intermediate", "advanced", "healer" }

--- One built spec of `specs` against the focus rules; `head` is the focus head seen so far (nil before
--- it), and the head after this spec is returned.
local function checkFocusSpec(specs, spec, head, where)
    local o = spec.overrides
    -- red under: Focus debuffs (mine) in the far stack, attached to Target buffs (all)
    assertEqual(spec.stack == "focus", FOCUS_ROLES[spec.role] == true, where .. ": the focus stack is the focus roles")
    assertEqual(o.unit == "focus", spec.stack == "focus", where .. ": a focus unit in the focus stack")
    if spec.attachTo then
        assertEqual(specs[spec.attachTo].stack, spec.stack, where .. " attaches within its own stack")
    end
    if spec.stack ~= "focus" then return head end
    assertEqual(o.layout.growV, "up", where .. " grows up")
    if head then
        assertTrue(spec.attachTo ~= nil, where .. " is attached")
        assertTrue(o.attach.y > 0, where .. ": above the one before")
        return head
    end
    assertNil(spec.attachTo, where .. " heads the focus stack")
    assertEqual(o.attach.mode, "screen", where .. ": on the screen (None in the panel)")
    assertTrue(o.position.point:find("^BOTTOM") ~= nil, where .. ": placed by its base")
    return spec
end

--- Preset `name` in style `look` applied in `env`: the focus head sits on the screen, its members
--- flow by it, and nothing is attached to a container of another stack, the far column's among them.
local function checkFocusApplied(env, name, look)
    local list, stackOf, headId = applied(env, name, look), {}, nil
    for _, e in ipairs(list) do stackOf[e.cfg.id] = e.spec.stack end
    for _, e in ipairs(list) do
        local where = ("%s/%s %s"):format(name, look, e.spec.role)
        local at = e.cfg.attach
        if at.mode == "container" then
            assertEqual(stackOf[tonumber(at.container)], e.spec.stack, where .. " attaches within its stack")
        end
        if e.spec.stack == "focus" and headId then
            assertEqual(env.Anchors.FlowRoot(e.cfg).id, headId, where .. " flows by the focus head")
        elseif e.spec.stack == "focus" then
            headId = e.cfg.id
            assertEqual(at.mode, "screen", where .. " is stored on the screen")
        end
    end
    assertTrue(headId ~= nil, name .. "/" .. look .. " applies a focus stack")
end

test("presets data: focus roles form their own screen-placed stack", function()
    local P = NS.PresetData
    local has = { intermediate = true, advanced = true, healer = true }
    for _, name in ipairs(NAMES) do
        for _, look in ipairs(P.LOOKS) do
            local specs, head = P.Build(name, look, 1920, 1080), nil
            for _, spec in ipairs(specs) do
                head = checkFocusSpec(specs, spec, head, ("%s/%s %s"):format(name, look, spec.role))
            end
            assertEqual(head ~= nil, has[name] == true, name .. "/" .. look .. ": a focus stack where the preset has focus roles")
        end
    end
    local env = freshEnv()
    env.Helpers.SkinPicker = function() return nil end
    for _, name in ipairs(WITH_FOCUS) do
        for _, look in ipairs(P.LOOKS) do checkFocusApplied(env, name, look) end
    end
end)

test("presets data: no bars container is laid out horizontally after Apply", function()
    local env = freshEnv()
    env.Helpers.SkinPicker = function() return nil end
    local bars = 0
    for _, name in ipairs(NAMES) do
        for _, look in ipairs(env.PresetData.LOOKS) do
            if name ~= "empty" then
                for _, e in ipairs(applied(env, name, look)) do
                    local where = ("%s/%s %s"):format(name, look, e.spec.role)
                    local L = env.Anchors.EffectiveLayout(e.cfg)
                    if e.cfg.style == "bars" then
                        bars = bars + 1
                        -- red under: Advanced (Bars)' focus bars, in the chain Target debuffs (all)'s
                        -- icon row heads, which they flow by (Anchors.EffectiveLayout)
                        assertEqual(L.axis, "vertical", where .. ": a column of bars")
                    end
                    -- Every member is built to flow as its chain's head does, so nothing is re-flowed.
                    for _, key in ipairs({ "axis", "growH", "growV" }) do
                        assertEqual(e.cfg.layout[key], L[key], where .. " " .. key .. " is its own")
                    end
                end
            end
        end
    end
    assertTrue(bars > 0, "the case saw bars")
end)

--- The distance between rectangles `a` and `b` (from sampleSpans): the larger of the horizontal and
--- the vertical gap between their facing edges, 0 when they overlap. Never more than the straight
--- distance, so a check against it is the stricter one.
local function rectGap(a, b)
    local h = math.max(0, a.left - b.right, b.left - a.right)
    local v = math.max(0, a.bottom - b.top, b.bottom - a.top)
    return math.max(h, v)
end

-- THE FOCUS COLUMN OVER THE RIGHT STACK'S (spec section 16.3). The focus column's left edge is Player
-- debuffs', 520 in from the right edge (45 further in than section 15's 475, a move the owner can
-- see), and the right (target) column ends 520 right of center, so on a 16:9 screen the two share 80
-- across, and in Advanced (Bars) the right stack runs from its base nearly to the top edge, so their
-- heights meet wherever the focus stack sits. Recorded in docs/known-limitations.md (presets). On
-- 16:10 and the narrow ratios the right edge comes in nearer the center line and the two share more;
-- on 21:9 they share nothing.
-- An Icons row grows left from its column's right edge, so the right stack's reaches 31 further
-- left (Advanced's heights meet; Intermediate's and Healer's do not). Each entry, by look and screen
-- at 1080 tall, unlocked in test mode, is what Advanced shares, exactly, and the most any preset may;
-- a screen not named shares nothing where the heights meet.
local FOCUS_OVER_RIGHT = {
    ["bars 1920x1080"] = 80, ["icons 1920x1080"] = 111,
    ["bars 1728x1080"] = 176, ["icons 1728x1080"] = 207,
    ["bars 1440x1080"] = 194, ["icons 1440x1080"] = 209,
    ["bars 1350x1080"] = 182, ["icons 1350x1080"] = 200,
}

--- Preset `name` in style `look` on a W x 1080 parent, unlocked in test mode: where the focus and the
--- right stacks' heights meet, they share no more across than FOCUS_OVER_RIGHT records, and Advanced
--- shares exactly that.
local function checkFocusOverRight(env, mocks, name, look, W)
    local spans = sampleSpans(env, mocks, name, look, W, 1080, true)
    local f, r = spans.focus, spans.right
    local meet = f.bottom < r.top and r.bottom < f.top
    local across = meet and math.max(0, math.min(f.right, r.right) - math.max(f.left, r.left)) or 0
    local key = ("%s %dx1080"):format(look, W)
    local most, where = FOCUS_OVER_RIGHT[key] or 0, name .. "/" .. key
    assertTrue(across <= most, ("%s: the focus column shares %d with the right one, past %d"):format(where, across, most))
    if name == "advanced" then
        assertNear(across, most, 0.5, where .. ": the recorded overlap, no more and no less")
    end
end

test("presets data: the focus stack stays clear of the far stack beyond twice the snap radius", function()
    local env, mocks = freshEnv()
    env.Helpers.SkinPicker = function() return nil end
    local clear = 2 * env.Constants.SNAP_RADIUS
    for _, scr in ipairs(SCREENS) do
        local W, H = scr[1], scr[2]
        for _, look in ipairs(env.PresetData.LOOKS) do
            for _, unlocked in ipairs({ false, true }) do
                local spans = sampleSpans(env, mocks, "advanced", look, W, H, unlocked)
                local where = ("advanced/%s at %dx%d%s"):format(look, W, H, unlocked and ", unlocked" or "")
                assertTrue(spans.focus and spans.far, where .. ": both stacks")
                local gap = rectGap(spans.focus, spans.far)
                -- red under: no focus stack (the focus bars in the far stack itself)
                assertTrue(gap > clear, ("%s: the focus stack %d from the far stack, within %d"):format(where, gap, clear))
            end
        end
    end
    -- Where the focus and the right stacks' heights meet at 1080 tall, the two share no more across
    -- than FOCUS_OVER_RIGHT records.
    for _, scr in ipairs(SCREENS) do
        if scr[2] == 1080 then
            for _, name in ipairs(WITH_FOCUS) do
                for _, look in ipairs(env.PresetData.LOOKS) do checkFocusOverRight(env, mocks, name, look, scr[1]) end
            end
        end
    end
end)

test("presets data: Player debuffs' left edge lines up with Focus buffs' left edge", function()
    local P = NS.PresetData
    for _, scr in ipairs(SCREENS) do
        local W, H = scr[1], scr[2]
        for _, name in ipairs(WITH_FOCUS) do
            for _, look in ipairs(P.LOOKS) do
                local heads = {}
                for _, spec in ipairs(P.Build(name, look, W, H)) do
                    if not spec.attachTo then heads[spec.stack] = { headRect(spec, W, H) } end
                end
                local where = ("%s/%s at %dx%d"):format(name, look, W, H)
                local corner, focus = heads.cornerLeft, heads.focus
                assertTrue(corner and focus, where .. ": both columns")
                -- red under: the focus bars in the far column, 570 right of the center line
                assertNear(focus[1], corner[1], 0.001, where .. ": one left edge")
                assertNear(focus[2], corner[2], 0.001, where .. ": one right edge, one width")
                -- The column's left edge (an Icons row grows left from its right edge, so its own left
                -- edge is its row's): red under section 15's place, 475 in from the right edge.
                local kx = P.ScaleX(W, H)
                local column = W + math.floor(P.STACKS.cornerLeft.x * kx + 0.5)
                assertTrue(column < W - 475 * kx - 0.5, where .. ": left of section 15's place")
                if look == "bars" then assertNear(corner[1], column, 0.001, where .. ": a bar fills its column") end
            end
        end
    end
    -- In test mode every focus bar container starts on that one edge too, Focus buffs (mine) and
    -- Dispellable by you on focus among them, each measured by its own block, not the stack's. An
    -- environment per screen: one that applies every preset on every screen grows by each Apply's
    -- containers, and the last one built stays live after the file (the kit's leak gate).
    for _, scr in ipairs(SCREENS) do
        local W, H = scr[1], scr[2]
        local env, mocks = freshEnv()
        env.Helpers.SkinPicker = function() return nil end
        for _, name in ipairs(WITH_FOCUS) do
            local _, each = sampleSpans(env, mocks, name, "bars", W, H)
            local own, left = {}, nil
            for _, e in ipairs(each) do
                own[e.role] = e.span
                if e.role == "pdebuffs" then left = e.span.left end
            end
            local where = ("%s/bars at %dx%d"):format(name, W, H)
            assertTrue(left ~= nil, where .. ": Player debuffs shows")
            local seen = 0
            for role in pairs(FOCUS_ROLES) do
                if own[role] then
                    seen = seen + 1
                    -- red under: a member attached a few units off its head's left edge
                    assertNear(own[role].left, left, 0.5, where .. ": " .. role .. "'s left edge is Player debuffs'")
                end
            end
            assertTrue(seen > 0, where .. ": a focus container to measure")
        end
    end
end)

-- THE FOCUS STACK IN SNAP RANGE (spec section 16.2, the owner's worry that a drag "may automatically
-- anchor again"). Unlocked in test mode, as a drag happens, Snap.Nearest at C.SNAP_RADIUS, with each
-- focus container as the dragged rect and every container of another stack as a target. The far stack
-- is never in range ("the focus stack stays clear of the far stack"), nor is Player debuffs (all) above
-- it, and Bars on a 1080-tall screen, the owner's preview, has nothing in range. What is left follows
-- from section 16.3's shared strip, recorded in docs/known-limitations.md (presets): the target stack's
-- containers, which run beside and above the focus stack in that strip, on a 768-tall screen the
-- corner group's Weapon enchants above it, and the call-outs to its left (at 768, and in Icons on 4:3
-- and 5:4 at 1080 and 1440). A target outside OPEN fails.
local SNAP_OPEN = {
    [768] = { right = true, cornerRight = true, middle = true },
    [1080] = { right = true, middle = true },
    [1440] = { right = true, middle = true },
}

--- Preset `name` in style `look` on a W x H parent, unlocked in test mode: the targets of other stacks
--- a focus container would snap onto, each checked against SNAP_OPEN. Returns how many there were.
local function checkFocusSnapRange(env, mocks, name, look, W, H)
    local _, each = sampleSpans(env, mocks, name, look, W, H, true)
    local radius, hits = env.Constants.SNAP_RADIUS, 0
    for _, f in ipairs(each) do
        if f.stack == "focus" then
            for _, e in ipairs(each) do
                local hit = (e.stack ~= "focus")
                    and env.Anchors.Snap.Nearest(f.span, { { id = e.role, rect = e.span, growH = "left", growV = "up" } }, radius)
                if hit then
                    hits = hits + 1
                    local where = ("%s/%s at %dx%d: %s is %d from %s (%s)"):format(name, look, W, H, f.role,
                        hit.dist, e.role, e.stack)
                    assertTrue(SNAP_OPEN[H][e.stack] == true, where .. ", a target outside the recorded ones")
                    assertTrue(not (look == "bars" and H == 1080), where .. ": Bars at 1080 has none")
                end
            end
        end
    end
    return hits
end

test("presets data: the focus stack's snap range holds only the recorded targets", function()
    local hits = 0
    for _, scr in ipairs(SCREENS) do
        -- An environment per screen, as above (the kit's leak gate).
        local env, mocks = freshEnv()
        env.Helpers.SkinPicker = function() return nil end
        for _, name in ipairs(WITH_FOCUS) do
            for _, look in ipairs(env.PresetData.LOOKS) do
                hits = hits + checkFocusSnapRange(env, mocks, name, look, scr[1], scr[2])
            end
        end
    end
    -- The case measures something: the shared strip does put targets in range somewhere.
    assertTrue(hits > 0, "the case saw a target in range")
end)
