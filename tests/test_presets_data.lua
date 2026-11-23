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
-- section 16). The far pair grows down from [18] Target buffs (all)'s top since the owner's second
-- 2026-11-23 change ("presets data: the far pair hangs Target debuffs (all) under Target buffs (all)").
local UP = { left = true, right = true, focus = true }

-- THE OWNER'S SMOKETEST BASELINE (their WoW Forever SmokeTest profile, 2026-11-17, on a parent 1200
-- units tall, in reference units x 0.9): the corner, player and target heads placed by their middle
-- on the screen's CENTER (`mid` stacks), every stack member flush on the one before it but the
-- call-outs (the roles' bar colors are tests/test_presets_look.lua's).
local MID = { cornerRight = 441, left = -153, right = -153 }

--- The join a stack member's built attach must be (defaults/Presets.lua memberAttach): a bar centered
--- on its parent's far side along the growth and an icon row on the side its icons start, both flush
--- (x and y 0); a call-out Automatic, flush as well (the owner's 2026-11-17 follow-up).
local function checkMemberJoin(o, where)
    local a, up = o.attach, o.layout.growV == "up"
    assertEqual(a.mode, "container", where .. ": attached to a container")
    assertEqual(a.x, 0, where .. ": flush across")
    if o.style == "text" then
        assertNil(a.childPoint, where .. ": a call-out keeps Automatic")
        assertNil(a.relPoint, where .. ": a call-out keeps Automatic")
        -- red under: the 6-unit gap, the owner's Y 0 on Defensive and Raid cooldowns
        assertEqual(a.y, 0, where .. ": flush under the one before")
        return
    end
    -- red under: the pre-baseline gap of 6 reference units and Automatic corners
    assertEqual(a.y, 0, where .. ": flush along, the seam leaves the gap")
    local h = ""
    if o.style == "icons" then h = (o.layout.growH == "left") and "RIGHT" or "LEFT" end
    assertEqual(a.childPoint, (up and "BOTTOM" or "TOP") .. h, where .. ": its own point")
    assertEqual(a.relPoint, (up and "TOP" or "BOTTOM") .. h, where .. ": its parent's point")
end

--- A `mid` stack's head on a W x H parent (the owner's baseline): by its middle on the screen's
--- CENTER, MID[stack] reference units up, a bar or a line by its CENTER on its column's middle, an
--- icon row by the middle of the edge it grows from.
local function checkMidHead(P, spec, W, H, where)
    local pos, o = spec.overrides.position, spec.overrides
    local col = P.Columns(W, H)[spec.stack]
    local kx = P.ScaleX(W, H)
    assertEqual(pos.relativePoint, "CENTER", where .. ": from the screen's center")
    assertEqual(pos.y, math.floor(MID[spec.stack] * P.Scale(H) + 0.5), where .. ": its middle at the owner's height")
    if o.style == "icons" then
        local fromRight = o.layout.growH == "left"
        assertEqual(pos.point, fromRight and "RIGHT" or "LEFT", where .. ": by the edge its row grows from")
        -- The column's middle scaled, its half-width not (presets restack spec section 3).
        -- red under: the column's scaled edge
        local half = fromRight and col.width / 2 or -col.width / 2
        assertEqual(pos.x, math.floor((col.x + col.width / 2) * kx + half + 0.5), where .. ": on that column edge")
    else
        assertEqual(pos.point, "CENTER", where .. ": by its own center")
        assertEqual(pos.x, math.floor((col.x + col.width / 2) * kx + 0.5), where .. ": on the column's middle")
    end
end

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

local PS = dofile("tests/presets_spans.lua")
local SCREENS, headRect, sampleSpans, rectGap = PS.SCREENS, PS.headRect, PS.sampleSpans, PS.rectGap
local fits, columnEdges = PS.fits, PS.columnEdges

-- THE COLUMNS THE HEADS SHARE (spec section 17, the right-hand cluster lined up). Player debuffs
-- (all) is no head: it joins Player buffs (all)'s left side, so the corner group is one head, and
-- the focus and far stacks hang under it on Player debuffs' column, the focus stack above the far
-- one and kept clear of it ("the focus stack stays clear of the far stack"). The target column sits
-- TARGET_GAP left of theirs. On 16:10 and narrower it reaches the call-out column, the overlap section
-- 17 allows and the case "the call-out block's overlap with the target column is the recorded one"
-- measures (docs/known-limitations.md, presets). Every other pair of head columns stays disjoint.
-- The corner stacks grow down from y = 46 and the side stacks grow up from their base at y = 740
-- (spec section 15.1), so every corner stack must end above every side stack's base. The check
-- measures that at the test-mode sample count: every container of the preset applied, each as tall
-- as Preview.Extent makes its placeholder block, each stack member hung from the one before by its
-- gap, below it growing down and above it growing up. In play a corner stack may grow further down
-- (docs/known-limitations.md, presets).
local CORNER = { cornerRight = true, cornerLeft = true }
local SIDE = { left = true, right = true, far = true, focus = true }
-- Since the owner's 2026-11-17 baseline the player column reaches the call-out column too, as the
-- target column does, mirrored: 14 reference units into its stored 400, which its lines, sized to
-- fit, do not fill.
local SHARED_COLUMNS = { ["far|focus"] = true, ["middle|right"] = true, ["left|middle"] = true }

local function columnsShared(a, b)
    local key = (a < b) and (a .. "|" .. b) or (b .. "|" .. a)
    return SHARED_COLUMNS[key] == true
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
-- samples; the seventh, tsteal, is stored off) included: 10 under the top edge unlocked. But one,
-- recorded in docs/known-limitations.md (presets) for the owner's call: that stack cannot fit a
-- 768-tall screen above the base, 92 over its top locked and 192 unlocked (4 more since AM-PR17 put
-- tsteal, numbered 15, under Target special: its empty link keeps its gap). Each entry is the most it
-- may run over, so the overshoot cannot grow unnoticed, and the case fails too once the stack fits.
local OFF_TOP = { ["advanced/bars right 768"] = 92 }
local OFF_TOP_UNLOCKED = { ["advanced/bars right 768"] = 192 }

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

--- Heads `a` and `b` on one screen: disjoint columns, or two of SHARED_COLUMNS.
local function checkColumns(a, b, what)
    if not (a.l < b.r and b.l < a.r) then return end
    assertTrue(columnsShared(a.stack, b.stack), what .. " (only the recorded columns may share)")
end

--- Player buffs' head on a W x H parent, its right edge `r`: at the cluster's place, the mirror's end
--- or moved left, and at least 10 in (spec sections 17 and 18). Since 2026-11-23 a bar is 240 wide on
--- every screen (presets restack spec section 3): the head's middle is placed by the scale, its
--- half-width not. red under: the scaled half-width (the corner off the edge under 1080 tall)
local function checkCornerEdge(P, r, W, H, where)
    local col = P.Columns(W, H).cornerRight
    local edge = W / 2 + (col.x + col.width / 2) * P.ScaleX(W, H) + col.width / 2
    assertNear(r, edge, 1, where .. " ends the cluster")
    assertTrue(r <= W - 10 + 0.5, where .. ": at least 10 in (" .. (W - r) .. ")")
    if P.ClusterShift(W, H) < 0 then
        assertNear(W - r, 10, 1, where .. ": moved left just enough, 10 in")
    end
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
                        if spec.stack == "cornerRight" then checkCornerEdge(P, r, W, H, where) end
                        heads[#heads + 1] = { l = l, r = r, stack = spec.stack }
                        placedY[spec.stack] = y
                    end
                end
                -- Where the 240-wide columns do not fit (PS.fits) they meet: recorded, not checked.
                local pairsOf = #heads
                if not fits(W, H) then pairsOf = 0 end
                for i = 1, pairsOf do
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
                    if UP[spec.stack] and not spec.attachTo and not MID[spec.stack] then
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

-- The point each up stack's head hangs from: the center line, for the far and focus columns; the
-- player and target heads are `mid` heads (checkMidHead).
local HEAD_POINT = { far = "TOP", focus = "TOP" }

--- An up stack's spec on a parent `H` tall (16:9): a member joins the one before (checkMemberJoin);
--- a head sits on its stack's base by a BOTTOM point, or is a `mid` head.
local function checkUpHead(P, spec, H, where)
    local o = spec.overrides
    if spec.attachTo then
        checkMemberJoin(o, where)
        return
    end
    if MID[spec.stack] then
        checkMidHead(P, spec, H * 16 / 9, H, where)
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
    -- Applied, each member joins the top of the one before it: a bar centered, an icon row from the side
    -- its stack's lines start (the owner's baseline).
    for _, name in ipairs({ "intermediate", "advanced", "healer" }) do
        for _, look in ipairs(P.LOOKS) do
            for _, e in ipairs(applied(env, name, look)) do
                if UP[e.spec.stack] and e.spec.attachTo then
                    local point, rel = env.Anchors.AttachPoints(e.cfg)
                    -- A member flows as its stack's head does (Anchors.EffectiveLayout).
                    local h = (env.Anchors.EffectiveLayout(e.cfg).growH == "left") and "RIGHT" or "LEFT"
                    if e.cfg.style == "bars" then h = "" end
                    local where = name .. "/" .. look .. " " .. e.spec.role
                    assertEqual(point, "BOTTOM" .. h, where .. ": its bottom (center for a bar, a corner for a row)")
                    assertEqual(rel, "TOP" .. h, where .. ": to the same on the top of the one before")
                    assertEqual(env.Anchors.AttachEdge(e.cfg), (h == "") and "after-center" or "after-start", where)
                end
            end
        end
    end
end)

test("presets data: both towers in the owner's 2026-11-23 order", function()
    local P = NS.PresetData
    -- The tier's first role sits nearest the base. Since the owner's 2026-11-23 restack, top to
    -- bottom: [09] Player buffs, short, [08] Player cooldowns, [07] Player special (mine); and [15]
    -- Target buffs (mine), [14] Target debuffs (mine), [13] Target cooldowns, NPCs, [12] Target
    -- cooldowns, players, [11] Target crowd control, [10] Target special (mine), stealable last.
    local adv = byRole(P.Build("advanced", "bars", 1920, 1080))
    -- red under: the pre-restack player tower, Player buffs, short at the base
    assertNil(adv.pspec.attachTo, "Player special (mine) is the player stack's base")
    assertEqual(adv.pspec.index, 7, "numbered 07")
    assertEqual(adv.pcd.attachTo, adv.pspec.index, "Player cooldowns sits on it")
    assertEqual(adv.pcd.index, 8, "numbered 08")
    assertEqual(adv.pshort.attachTo, adv.pcd.index, "Player buffs, short on that")
    assertEqual(adv.pshort.index, 9, "numbered 09")
    assertNil(adv.tspec.attachTo, "Target special (mine) is the target stack's base")
    assertEqual(adv.tspec.index, 10, "numbered 10")
    -- red under: the pre-restack target tower, Target debuffs (mine) on Target special (mine)
    local chain = { "tspec", "tcc", "tcdp", "tcdn", "tdeb", "tbuff", "tsteal" }
    for i = 2, #chain do
        assertEqual(adv[chain[i]].attachTo, adv[chain[i - 1]].index, chain[i] .. " sits on " .. chain[i - 1])
        assertEqual(adv[chain[i]].index, 9 + i, chain[i] .. " numbered " .. (9 + i))
    end
    -- Intermediate the same way: its cooldowns under its short buffs, its target cooldowns under its
    -- target debuffs (presets restack spec section 3).
    local int = byRole(P.Build("intermediate", "bars", 1920, 1080))
    assertNil(int.pcd.attachTo, "Intermediate: Player cooldowns is the player stack's base")
    assertEqual(int.pshort.attachTo, int.pcd.index, "Intermediate: Player buffs, short on it")
    assertNil(int.tcd.attachTo, "Intermediate: Target cooldowns is the target stack's base")
    assertEqual(int.tdeb.attachTo, int.tcd.index, "Intermediate: Target debuffs (mine) on it")
end)

test("presets data: the corner group ends the cluster, Player buffs at least 10 in", function()
    local P = NS.PresetData
    local S = P.STACKS
    -- Spec section 18: the corner group ends the right-hand cluster, which hangs from the center line,
    -- moved left where Player buffs' right edge is not at least 10 in from the screen edge (the cluster
    -- case "the cluster moves left just enough to fit on narrower screens"). Since the owner's
    -- baseline its head is placed by its CENTER at 892.8, 441 from the screen's center (992, 490 on
    -- their 1200-tall screen), its right edge 1012.8 right of the center line. red under: section 18's
    -- TOPLEFT on the center line's TOP, 46 down, ending at 1015.
    assertNear(S.cornerRight.x + S.cornerRight.width, 1012.8, 1e-9, "Player buffs' right edge, from the center line")
    assertEqual(S.cornerRight.anchor, "CENTER", "the cluster's corner hangs from the screen's center")
    assertEqual(S.cornerRight.width, 240, "as wide as Player cooldowns (spec section 17.2)")
    assertEqual(S.cornerLeft.width, 240, "and Player debuffs")
    assertNear(S.cornerRight.x - (S.cornerLeft.x + S.cornerLeft.width), 2.8, 1e-9, "the gap between the two")
    assertEqual(S.cornerLeft.beside, "cornerRight", "Player debuffs' column joins Player buffs'")
    assertEqual(S.cornerRight.mid, 441, "its middle 441 over the screen's center, the owner's")
    local simple = byRole(P.Build("simple", "bars", 1920, 1080))
    local pos = simple.pbuffs.overrides.position
    assertEqual(pos.relativePoint, "CENTER")
    assertEqual(pos.point, "CENTER")
    -- At 1920 x 1080 the cluster's end, 960 + 1012.8, is past the edge: moved 62.8 left, 10 in.
    assertNear(P.ClusterShift(1920, 1080), -62.8, 1e-9, "1920 x 1080 moves the cluster 62.8 left")
    assertEqual(pos.x, math.floor(892.8 - 62.8 + 0.5))
    assertEqual(960 + pos.x + S.cornerRight.width / 2, 1910, "10 in from the right edge")
    assertEqual(pos.y, 441)
    -- On the owner's own screen it lands where they put it.
    local own = byRole(P.Build("simple", "bars", 3440 / 1.2, 1200)).pbuffs.overrides.position
    assertEqual(own.x, 992, "the owner's x on their 1200-tall screen")
    assertEqual(own.y, 490, "the owner's y")
    assertNil(simple.pdebuffs.overrides.position, "Player debuffs is not placed: it joins Player buffs")
    -- Still a corner group: it grows down, and the members hang below their heads.
    assertEqual(simple.wpn.overrides.layout.growV, "down")
    checkMemberJoin(simple.wpn.overrides, "Weapon enchants hangs below Player buffs")
    assertEqual(simple.pdebuffs.overrides.attach.x, 0, "Player debuffs flush beside Player buffs (the seam's gap)")
    assertEqual(simple.wpn.attachTo, simple.pbuffs.index, "Weapon enchants stays under Player buffs")
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

--- The room the call-out block may take on a `H` tall parent (spec section 18.3): from the preset
--- picker's top (centered `skinShare` of the way up, `pickerHeight` tall), no nearer the top edge than
--- a margin, down to a margin above the bottom edge, as offsets from the top edge.
local function calloutRoom(P, H)
    local R = P.ROOM
    return math.max(R.margin, H * (1 - R.skinShare) - R.pickerHeight / 2), H - R.margin
end

test("presets data: the call-out block takes the largest font that fits under the picker's top", function()
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
                assertNear(top, lo, 0.5, where .. ": at the picker's top")
                assertTrue(bottom <= hi + 0.5, where .. ": above the bottom edge")
            else
                assertEqual(r.fontSize, min, where .. ": nothing fits, so the smallest")
            end
        end
    end
    -- Healer's one call-out fits at the owner's size on a 1080-tall screen.
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
            local last, specs = {}, P.Build(name, look, 1920, 1080)
            for i, spec in ipairs(specs) do
                local a = spec.overrides.attach
                assertTrue(a.mode ~= "frame", name .. " #" .. i .. ": never a frame")
                assertTrue(a.frame == nil or a.frame == "", name .. " #" .. i .. ": no frame name")
                local beside = P.STACKS[spec.stack].beside
                if spec.stack == "far" then
                    -- The far pair, [17] under [18]: tests/test_presets_cluster.lua's own case.
                    assertTrue(spec.role == "ticoD" or spec.role == "ticoB", name .. " #" .. i)
                elseif not last[spec.stack] and beside and last[beside] then
                    -- Player debuffs (all) joins Player buffs (all)'s left side (spec section 17).
                    assertEqual(spec.role, "pdebuffs", name .. " #" .. i)
                    assertEqual(specs[spec.attachTo].role, "pbuffs", name .. " #" .. i .. " joins Player buffs")
                    assertEqual(a.mode, "container")
                    assertNil(spec.overrides.position, name .. " #" .. i .. ": a member is not placed")
                    assertEqual(a.y, 0, name .. " #" .. i .. ": top to top")
                elseif last[spec.stack] then
                    assertEqual(spec.attachTo, last[spec.stack], name .. " #" .. i .. " attaches to the one above")
                    assertEqual(a.mode, "container")
                    assertNil(spec.overrides.position, name .. " #" .. i .. ": a member is not placed")
                    assertEqual(spec.overrides.layout.growV, UP[spec.stack] and "up" or "down", name .. " #" .. i)
                    checkMemberJoin(spec.overrides, name .. " #" .. i)
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
        "left:pspec", "left:pcd", "left:pshort",
        "right:tspec", "right:tcc", "right:tcdp", "right:tcdn", "right:tdeb", "right:tbuff", "right:tsteal",
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
    -- 4:3 at 1080: the places narrow across, so every head stays on the screen (the placement case),
    -- but since the owner's 2026-11-23 feedback the columns' 240 does not (presets restack spec section
    -- 3): the right-hand cluster, moved left until Player buffs is 10 in, is wider than the room right
    -- of the center line and the target column crosses it (PS.fits; docs/known-limitations.md).
    local kx = P.ScaleX(1440, 1080)
    assertTrue(kx < 1, "4:3 narrows")
    assertEqual(P.STACKS.right.x, 186, "the target column's reference place, the mirror (the owner's baseline)")
    assertTrue(not fits(1440, 1080), "4:3 at 1080 is a screen the 240-wide columns do not fit")
    local left = columnEdges("right", 1440, 1080)
    -- red under: the scaled columns, whose cluster kept 10 right of the center line
    assertTrue(left < 10, "the target column reaches past the center's margin (" .. left .. ")")
    assertTrue(left > -240, "but keeps most of itself right of the center line")
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
                -- A `mid` head (the owner's baseline) by the middle of its right edge.
                local want = MID[b.stack] and "RIGHT" or (UP[b.stack] and "BOTTOMRIGHT" or "TOPRIGHT")
                assertEqual(i.overrides.position.point, want, role .. " hangs from its column's right edge")
            end
            -- About the owner's 24, sized so the row fills its column.
            assertTrue(math.abs(i.overrides.icons.width - 24) <= 3, role .. ": about 24 (" .. i.overrides.icons.width .. ")")
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
        local to = specs[spec.attachTo].stack
        assertTrue(to == spec.stack or to == NS.PresetData.STACKS[spec.stack].beside,
            where .. " attaches within its own stack, or beside the one its stack joins")
    end
    if spec.stack ~= "focus" then return head end
    assertEqual(o.layout.growV, "up", where .. " grows up")
    if head then
        assertTrue(spec.attachTo ~= nil, where .. " is attached")
        checkMemberJoin(o, where)
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
            local to = stackOf[tonumber(at.container)]
            assertTrue(to == e.spec.stack or to == env.PresetData.STACKS[e.spec.stack].beside,
                where .. " attaches within its stack, or beside the one its stack joins")
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

-- THE FOCUS COLUMN BESIDE THE TARGET COLUMN (spec section 17). The target column now sits 104 left of
-- the focus column, so the two share nothing across (section 16 had them share 80 to 194 at 1080).
-- On a 4:3 or 5:4 screen 768 tall, unlocked, a focus icon row's drag strip, longer than the narrowed
-- row, overhung it to the left into the target column until an icon row's strip took its row's width
-- (Anchors.RowSpan, 2026-11-17), so nothing is left. Each entry, by look and screen, unlocked in test mode, is what
-- Advanced shares, exactly, and the most any preset may; a screen not named shares nothing where the
-- heights meet.
-- Since the owner's 2026-11-23 feedback the columns keep their 240 where only their places scale
-- (presets restack spec section 3), so where the scale is under 1 the focus column reaches the target
-- column again (PS.fits; docs/known-limitations.md, presets).
local FOCUS_OVER_RIGHT = {
    ["bars 1024x768"] = 127, ["bars 1228x768"] = 65, ["bars 1350x1080"] = 14, ["bars 1365x768"] = 64,
    ["bars 1792x768"] = 65, ["bars 960x768"] = 149, ["icons 1024x768"] = 31, ["icons 960x768"] = 53,
}
-- How near the focus stack comes to the far stack, unlocked, where the columns do not fit: the far
-- stack's rows keep the owner's 24 there now (they were sized down with the column), one short of
-- twice the snap radius.
local FAR_NEAR_CRAMPED = 47

--- Preset `name` in style `look` on a W x H parent, unlocked in test mode: where the focus and the
--- right stacks' heights meet, they share no more across than FOCUS_OVER_RIGHT records, and Advanced
--- shares exactly that.
local function checkFocusOverRight(env, mocks, name, look, W, H)
    local spans = sampleSpans(env, mocks, name, look, W, H, true)
    local f, r = spans.focus, spans.right
    local meet = f.bottom < r.top and r.bottom < f.top
    local across = meet and math.max(0, math.min(f.right, r.right) - math.max(f.left, r.left)) or 0
    local key = ("%s %dx%d"):format(look, W, H)
    local most, where = FOCUS_OVER_RIGHT[key] or 0, name .. "/" .. key
    -- red under: section 16's layout, the focus column over the target column's right end
    assertTrue(across <= most + 0.5, ("%s: the focus column shares %d with the right one, past %d"):format(where, across, most))
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
                local least = (unlocked and not fits(W, H)) and (FAR_NEAR_CRAMPED - 0.5) or clear
                assertTrue(gap > least, ("%s: the focus stack %d from the far stack, within %d"):format(where, gap, least))
            end
        end
    end
    -- Where the focus and the right stacks' heights meet, the two share no more across than
    -- FOCUS_OVER_RIGHT records. An environment per screen (the kit's leak gate).
    for _, scr in ipairs(SCREENS) do
        local e, m = freshEnv()
        e.Helpers.SkinPicker = function() return nil end
        for _, name in ipairs(WITH_FOCUS) do
            for _, look in ipairs(e.PresetData.LOOKS) do checkFocusOverRight(e, m, name, look, scr[1], scr[2]) end
        end
    end
end)

--- The left edge of column `stack` on a W x H parent (from the center line, the cluster's move
--- included: P.Columns), as `place` rounds a head's offset.
local function columnLeft(P, stack, W, H)
    return W / 2 + math.floor(P.Columns(W, H)[stack].x * P.ScaleX(W, H) + 0.5)
end

--- Preset `name` in style `look` built on a W x H parent: the focus and far heads' edges are Player
--- debuffs' column's. An Icons row grows left from its column's right edge, so its own left edge is
--- its full row's, each icon's size rounded down: up to a pixel per icon in from the column's; the far
--- stack's rows grow right from the left edge, so their right edge is the one that falls short.
local function checkColumnHeads(P, name, look, W, H)
    local heads = {}
    for _, spec in ipairs(P.Build(name, look, W, H)) do
        if not spec.attachTo then heads[spec.stack] = { headRect(spec, W, H) } end
    end
    local where = ("%s/%s at %dx%d"):format(name, look, W, H)
    local column = columnLeft(P, "cornerLeft", W, H)
    assertTrue(heads.focus ~= nil, where .. ": a focus head")
    -- red under: the far column 570 right of the center line
    for _, stack in ipairs({ "focus", "far" }) do
        local h, perIcon = heads[stack], P.STACKS[stack].width / 24 + 1
        if h then
            local slack = (look == "icons") and perIcon or 0.001
            assertTrue(h[1] >= column - 0.001 and h[1] <= column + slack,
                ("%s: %s's left edge %d, the column's %d"):format(where, stack, h[1], column))
            -- A column is as wide on every screen (presets restack spec section 3).
            local right = column + P.STACKS[stack].width
            if stack == "far" then
                -- The far stack's rows, eight of the owner's 24 (fewer pixels where the column is
                -- narrower), grow right from the column's left edge and stay inside it.
                assertTrue(h[2] <= right + 1, ("%s: far's right edge %d, inside the column's %d"):format(where, h[2], right))
            else
                assertTrue(math.abs(h[2] - right) <= 1,
                    ("%s: %s's right edge %d, the column's %d"):format(where, stack, h[2], right))
            end
        end
    end
    assertTrue(column < W - 475 - 0.5, where .. ": left of section 15's place")
end

-- The containers that start on Player debuffs' left edge in test mode: the focus bars and the far
-- stack's icon rows (which grow right from the column's left edge).
local LINED = { fdeb = true, fbuff = true, healFocus = true, dispelFocus = true, ticoD = true, ticoB = true }

--- Preset `name` (Bars) applied on a W x H parent in `env`, in test mode: Player debuffs on its
--- column, and every LINED container on Player debuffs' left edge, each by its own block.
local function checkColumnSpans(env, mocks, name, W, H)
    local _, each = sampleSpans(env, mocks, name, "bars", W, H)
    local own, left = {}, nil
    for _, e in ipairs(each) do
        own[e.role] = e.span
        if e.role == "pdebuffs" then left = e.span.left end
    end
    local where = ("%s/bars at %dx%d"):format(name, W, H)
    assertTrue(left ~= nil, where .. ": Player debuffs shows")
    -- red under: Player debuffs joined a few units off its column
    -- Flush beside Player buffs (the owner's x 0): the seam's 2 pixels stand for the 2.8 reference
    -- units between the columns, so up to 2 pixels off on a 1440-tall screen.
    assertNear(left, columnLeft(env.PresetData, "cornerLeft", W, H), 2, where .. ": Player debuffs on its column")
    local seen = 0
    for role in pairs(LINED) do
        if own[role] then
            seen = seen + 1
            -- red under: a member attached a few units off its head's left edge
            assertNear(own[role].left, left, 2, where .. ": " .. role .. "'s left edge is Player debuffs' (within the seam's rounding)")
        end
    end
    assertTrue(seen > 0, where .. ": a focus container to measure")
end

test("presets data: the focus, far and Player debuffs left edges line up", function()
    local P = NS.PresetData
    -- The columns: the focus and far stacks hang on Player debuffs' column (spec sections 16 and 17).
    assertEqual(P.STACKS.focus.x, P.STACKS.cornerLeft.x, "the focus column is Player debuffs'")
    assertEqual(P.STACKS.far.x, P.STACKS.cornerLeft.x, "and so is the far column")
    for _, scr in ipairs(SCREENS) do
        for _, name in ipairs(WITH_FOCUS) do
            for _, look in ipairs(P.LOOKS) do checkColumnHeads(P, name, look, scr[1], scr[2]) end
        end
    end
    -- In test mode, measured where the live placement puts each one, in Bars only: an Icons Player
    -- debuffs joins the left end of Player buffs' row, which moves with its icon count, so it is on
    -- the column only while that row is full (docs/known-limitations.md, presets). An environment per
    -- screen: one that applies every preset on every screen grows by each Apply's containers, and the
    -- last one built stays live after the file (the kit's leak gate).
    for _, scr in ipairs(SCREENS) do
        local env, mocks = freshEnv()
        env.Helpers.SkinPicker = function() return nil end
        for _, name in ipairs(WITH_FOCUS) do checkColumnSpans(env, mocks, name, scr[1], scr[2]) end
    end
end)

-- THE FOCUS STACK IN SNAP RANGE (spec section 16.2, the owner's worry that a drag "may automatically
-- anchor again"). Unlocked in test mode, as a drag happens, Snap.Nearest at C.SNAP_RADIUS, with each
-- focus container as the dragged rect and every container of another stack as a target. The far stack
-- is never in range ("the focus stack stays clear of the far stack"), nor is Player debuffs (all) above
-- it. With the target column 50 left of the focus column (spec section 17), nothing is in range on a
-- 1080 or a 1440-tall screen. What is left is on a 768-tall one, where the layout shrinks and the bars
-- do not, recorded in docs/known-limitations.md (presets): in Bars, Player buffs (all) and Weapon
-- enchants beside the focus stack's top, and since the owner's 2026-11-17 baseline lowered the corner
-- group, Player debuffs (all). Icons reaches nothing since an icon row's drag strip spans its row
-- (Anchors.RowSpan) instead of running past it into the target rows and the call-outs. A target
-- outside OPEN fails.
-- Since the owner's 2026-11-23 feedback (presets restack spec section 3) the columns keep their 240,
-- so on every screen they do not fit (PS.fits) the target column and the call-outs come in range too.
local SNAP_OPEN = { cornerRight = true, cornerLeft = true, right = true, middle = true }

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
                    assertTrue(SNAP_OPEN[e.stack] == true, where .. ", a target outside the recorded ones")
                    assertTrue(not fits(W, H), where .. ": only a screen the columns do not fit has any")
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

-- The bar look and the numbered names (spec section 17.3-4) are tests/test_presets_look.lua's.
