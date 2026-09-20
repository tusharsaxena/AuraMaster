-- tests/test_defaults.lua — the shape invariants the code relies on in defaults/Profile.lua and
-- defaults/Categories.lua: the starter containers are containers, every category carries what its
-- kind needs, every default is one the settings panel can show and every leaf of the template is one
-- a row edits. Seeding and category-key uniqueness are tests/test_database.lua's.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local NS = T.NS
local C, Cat = NS.Constants, NS.Categories

local function set(list)
    local s = {}
    for _, v in ipairs(list) do s[v] = true end
    return s
end

--- Every leaf under `t` as { path, value }. A color ({ r, g, b, a }) and an empty table are leaves:
--- neither is walked into by the settings rows.
local function leaves(t, prefix, out)
    out = out or {}
    for k, v in pairs(t) do
        local p = prefix .. k
        if type(v) == "table" and next(v) ~= nil and v.r == nil then
            leaves(v, p .. ".", out)
        else
            out[#out + 1] = { p, v }
        end
    end
    return out
end

--- The choices of a row whose `values` is a table, as a set, or nil. Both shapes the options
--- library reads: an ordered `{ value, text }` list (NS.Choices) and a `value -> label` map (the
--- composers'). A values FUNCTION resolves at render time and is not judged here.
local function choices(row)
    if type(row.values) ~= "table" then return nil end
    local out = {}
    for k, item in pairs(row.values) do
        if type(item) == "table" and item.value ~= nil then
            out[item.value] = true
        else
            out[k] = true
        end
    end
    return out
end

-- The spell sets are written whole through the seam (settings/Schema.lua's carve-outs), not by row.
-- enchantSlots (schema v3, B3) got its rows in B7 (settings/GeneralSpells.lua's ENCHANT_ROWS), so it
-- is no longer exempted here.
local CARVE_OUTS = set({ "filter.whitelist", "filter.blacklist" })
local PROFILE_CARVE_OUTS = set({ "categorySpells" })

test("defaults: every starter container is a valid container whose every override the template knows", function()
    local units, types, styles = set(C.UNITS), set(C.AURA_TYPES), set(C.STYLES)
    local names, bad = {}, {}
    for i, s in ipairs(NS.STARTER_CONTAINERS) do
        assertTrue(units[s.unit] and types[s.auraType] and styles[s.style], "starter " .. i .. " is a container")
        assertFalse(names[s.name:lower()], "starter names are unique: " .. s.name)
        names[s.name:lower()] = true
        for _, leaf in ipairs(leaves(s, "")) do
            local p, v = leaf[1], leaf[2]
            local want = NS.DefaultFor("container." .. p)
            local row = NS.FindSchemaRow("container." .. p)
            local allowed = row and choices(row)
            -- red under: a starter override misspelling a key (the backfill keeps it, nothing reads it)
            if want == nil or type(want) ~= type(v) then
                bad[#bad + 1] = s.name .. ": " .. p
            elseif allowed and not allowed[v] then
                bad[#bad + 1] = s.name .. ": " .. p .. " = " .. tostring(v) .. " is not a choice"
            end
        end
    end
    assertEqual(#bad, 0, table.concat(bad, "; "))
end)

test("defaults: every category carries what its kind needs, and a label and description", function()
    local dispelTypes = set(C.DISPEL_TYPES)
    local function isId(id) return type(id) == "number" and id > 0 and id == math.floor(id) end
    local KIND = {
        token = function(d) return type(d.token) == "string" and d.token ~= "" end,
        flag = function(d) return type(d.field) == "string" and type(d.value) == "boolean" end,
        dispel = function(d)
            if type(d.types) ~= "table" or next(d.types) == nil then return false end
            for t in pairs(d.types) do if not dispelTypes[t] then return false end end
            return true
        end,
        spells = function(d)
            if type(d.spells) ~= "table" or next(d.spells) == nil then return false end
            for id, class in pairs(d.spells) do
                if not (isId(id) and type(class) == "string") then return false end
            end
            return true
        end,
        -- The odd one out (defaults/Categories.lua's KINDS doc): it matches no aura, so it carries
        -- nothing beyond the label and description every kind needs.
        enchant = function() return true end,
        -- U-1: the complement of every spells-kind category's union, not an id list of its own —
        -- like enchant, nothing beyond the label and description.
        uncategorized = function() return true end,
    }
    local bad = {}
    for _, list in ipairs({ Cat.HELPFUL, Cat.HARMFUL }) do
        for _, def in ipairs(list) do
            local check = KIND[def.kind]
            -- red under: a category whose kind the compiler has no branch for, or missing its token,
            -- field, dispel types or spell ids
            if not (check and check(def)) then
                bad[#bad + 1] = tostring(def.key) .. " (" .. tostring(def.kind) .. ")"
            end
            if type(def.label) ~= "string" or def.label == "" or type(def.desc) ~= "string" or def.desc == "" then
                bad[#bad + 1] = tostring(def.key) .. ": label or description"
            end
        end
    end
    assertEqual(#bad, 0, table.concat(bad, "; "))
end)

test("defaults: IsSpellCategory names exactly the spells-kind categories of BOTH aura types", function()
    -- Until issue #11 this case asserted the stronger "and they are all buff categories". That
    -- stopped being true with `hardCC`/`softCC`, and it was never the invariant anything depends on:
    -- `Cat.IsSpellCategory` is what settings/GeneralSpells.lua, the schema's categorySpells carve-out
    -- and modules/FilterCompiler.lua's union all key off, and what they need is that it answers the
    -- KIND, whichever list the key came from.
    local spellCats = 0
    for _, list in ipairs({ Cat.HELPFUL, Cat.HARMFUL }) do
        for _, def in ipairs(list) do
            -- red under: IsSpellCategory looking at only one aura type's list again
            assertEqual(Cat.IsSpellCategory(def.key), def.kind == "spells", def.key)
            if def.kind == "spells" then spellCats = spellCats + 1 end
        end
    end
    assertTrue(spellCats > 0, "the editor has something to edit")
    assertFalse(Cat.IsSpellCategory("no such category"))
end)

--- The shipped `spells` table of `auraType`'s `key`, failing the case if there is no such category.
local function shippedSpells(auraType, key)
    local def = Cat.Find(auraType, key)
    assertTrue(def ~= nil, key .. " is not a category of " .. auraType)
    assertEqual(def.kind, "spells", key .. " is kind " .. tostring(def.kind))
    assertTrue(type(def.spells) == "table", key .. " has no spell list")
    return def.spells, def
end

test("defaults: Hard CC and Soft CC ship as non-empty HARMFUL spell lists of positive integer ids", function()
    -- Issue #11 part A1: the first `spells`-kind categories `Cat.HARMFUL` has ever carried. Asserted
    -- against the SHIPPED data, not a fixture — the lists are curated by hand from
    -- tools/spell-research/research.py's output (docs/spell-research/2026-09-20/), so a paste slip is
    -- exactly the kind of mistake that reaches a player otherwise.
    local seen = {}
    for _, key in ipairs({ "hardCC", "softCC" }) do
        local ids, def = shippedSpells("HARMFUL", key)
        local n = 0
        for id, class in pairs(ids) do
            -- red under: a float, a string id, a negative or a 0 from a bad paste
            assertEqual(type(id), "number", key .. ": id " .. tostring(id))
            assertTrue(id > 0 and id == math.floor(id), key .. ": id " .. tostring(id))
            assertTrue(type(class) == "string" and class ~= "", key .. ": id " .. id .. " has no class")
            -- red under: the same spell in both buckets — a spell belongs to exactly ONE, so the two
            -- lists can never double-count an aura or disagree about which row claims it.
            assertTrue(seen[id] == nil, ("id %d is in both %s and %s"):format(id, tostring(seen[id]), key))
            seen[id] = key
            n = n + 1
        end
        assertTrue(n > 0, key .. " ships empty")
        assertTrue(Cat.IsSpellCategory(key), key .. " is not reachable through IsSpellCategory")
        assertEqual(Cat.DefaultStates()[key], "show", key .. " is not in DefaultStates at Show")
        assertTrue(def.desc:find("hostile", 1, true) ~= nil,
            key .. "'s desc must say the list only works on a hostile unit")
    end
    -- Canonical members, one per bucket, from the ids the research run reached directly: a list
    -- rewritten down to a stub would still satisfy every shape check above.
    local hard = shippedSpells("HARMFUL", "hardCC")
    assertEqual(hard[853], "PALADIN", "Hammer of Justice")
    assertEqual(hard[118], "MAGE", "Polymorph")
    assertEqual(hard[3355], "HUNTER", "Freezing Trap — the bridged aura id, not the cast id")
    local soft = shippedSpells("HARMFUL", "softCC")
    assertEqual(soft[339], "DRUID", "Entangling Roots")
    assertEqual(soft[1715], "WARRIOR", "Hamstring")
    -- The owner removed Wake of Ashes from these lists on 2026-09-20, and a later research run will
    -- derive it back into the hard-CC bucket: this is the assertion that makes re-adding it a red
    -- test rather than an unexplained diff. Every id of the ability -- the stun aura, the cast, the
    -- older stun aura and the ancestor's slow -- is out of BOTH rows.
    for _, id in ipairs({ 255941, 255937, 205290, 205273 }) do
        assertTrue(hard[id] == nil, "Wake of Ashes id " .. id .. " is back on hardCC")
        assertTrue(soft[id] == nil, "Wake of Ashes id " .. id .. " is back on softCC")
    end
end)

test("defaults: Hard CC and Soft CC are declared ABOVE crowdControl, the Blizzard token they refine", function()
    -- Spec A1, and not cosmetic: Cat.For's order is the order settings/Filters.lua draws the grid in
    -- and the order modules/FilterCompiler.lua's shown-group loop dedups in.
    local at = {}
    for i, def in ipairs(Cat.HARMFUL) do at[def.key] = i end
    assertTrue(at.hardCC < at.crowdControl, "hardCC is below crowdControl")
    assertTrue(at.softCC < at.crowdControl, "softCC is below crowdControl")
    assertTrue(at.hardCC < at.softCC, "hard before soft, as the descs read")
end)

test("defaults: uncategorized is declared LAST in both Cat.HELPFUL and Cat.HARMFUL (U-1, fix round 3)", function()
    -- Correctness depends on this: modules/FilterCompiler.lua's shown-group loop excludes every
    -- EARLIER shown category from a later one, so `uncategorized`'s complement-exclude (buffs) or
    -- no-op (debuffs) only correctly dedups against every other shown category if nothing is
    -- declared after it, on EITHER list — restored to HARMFUL in fix round 3 with an asymmetric
    -- meaning (Hide reproduces the retired toggle; Show is inert, defaults/Categories.lua's KINDS doc).
    local lastHelpful = Cat.HELPFUL[#Cat.HELPFUL]
    assertEqual(lastHelpful.key, "uncategorized", "red under: another category added after it")
    assertEqual(lastHelpful.kind, "uncategorized")
    local lastHarmful = Cat.HARMFUL[#Cat.HARMFUL]
    assertEqual(lastHarmful.key, "uncategorizedDebuffs", "red under: another category added after it")
    assertEqual(lastHarmful.kind, "uncategorized")
end)

test("defaults: every leaf of the container template is edited by a settings row or is a spell set", function()
    local orphans = {}
    for _, leaf in ipairs(leaves(NS.CONTAINER_TEMPLATE, "")) do
        local p = leaf[1]
        -- red under: a template key no row reaches (a default the player can never change or reset)
        if not CARVE_OUTS[p] and not NS.FindSchemaRow("container." .. p) then
            orphans[#orphans + 1] = p
        end
    end
    table.sort(orphans)
    assertEqual(#orphans, 0, "no row for: " .. table.concat(orphans, ", "))
end)

test("defaults: every profile default is a settings row, a spell set or the registry's own bookkeeping", function()
    local BOOKKEEPING = set({ "containers", "containerOrder", "nextContainerId", "seeded" })
    local orphans = {}
    for _, leaf in ipairs(leaves(NS.defaults.profile, "")) do
        local k = leaf[1]
        if not BOOKKEEPING[k] and not PROFILE_CARVE_OUTS[k] and not NS.FindSchemaRow(k) then
            orphans[#orphans + 1] = k
        end
    end
    -- red under: an addon-wide default added without its row
    assertEqual(#orphans, 0, "no row for: " .. table.concat(orphans, ", "))
end)

test("defaults: every dropdown's default is one of its choices", function()
    local bad = {}
    for _, row in ipairs(NS.Schema) do
        local allowed = choices(row)
        -- red under: a template default the dropdown cannot show (it opens on a blank)
        if allowed and row.default ~= nil and not allowed[row.default] then
            bad[#bad + 1] = row.path .. " = " .. tostring(row.default)
        end
    end
    assertEqual(#bad, 0, table.concat(bad, "; "))
end)

test("defaults: every slider's default lies inside its range", function()
    local bad = {}
    for _, row in ipairs(NS.Schema) do
        if row.type == "number" and type(row.default) == "number" and row.min and row.max then
            -- red under: a default outside the slider (the first drag snaps it somewhere else)
            if row.default < row.min or row.default > row.max then
                bad[#bad + 1] = ("%s = %s outside %s..%s"):format(row.path, row.default, row.min, row.max)
            end
        end
    end
    assertEqual(#bad, 0, table.concat(bad, "; "))
end)

test("defaults: the dispel palette covers every dispel type, and the profile holds its own copy", function()
    local palette, types = C.DEFAULT_DISPEL_COLORS, set(C.DISPEL_TYPES)
    for name in pairs(palette) do assertTrue(types[name], "palette entry for an unknown type: " .. name) end
    for name in pairs(types) do
        local want, got = palette[name], NS.defaults.profile.dispelColors[name]
        -- red under: a dispel type added to DISPEL_TYPES without its palette color (its swatch
        -- and its bar color resolve to nothing)
        assertTrue(want ~= nil and got ~= nil, "a color for " .. name)
        assertTrue(got ~= want, name .. ": the profile default is its own table, not the constant")
        assertEqual(got.r + got.g + got.b + got.a, want.r + want.g + want.b + want.a, name)
    end
end)

test("defaults: spell lists and dispel colors are profile-wide, never a container's (schema v2)", function()
    -- red under: leaving either key in the template (the load backfill would put back on every
    -- container what the v2 step just lifted to the profile)
    assertEqual(NS.CONTAINER_TEMPLATE.filter.categorySpells, nil)
    assertEqual(NS.CONTAINER_TEMPLATE.bars.dispelColors, nil)
    assertEqual(type(NS.defaults.profile.categorySpells), "table")
    assertEqual(next(NS.defaults.profile.categorySpells), nil, "no spell edits by default")
end)

test("defaults: one Healing category holds both retired healing lists, where Core healing was", function()
    local HEALING = { 774, 8936, 33763, 48438, 139, 17, 194384, 41635, 61295, 974, 119611, 124682,
        364343, 366155, 53563, 102352, 155777, 207386, 115175, 156910, 200025, 287280 }
    local def = Cat.Find("HELPFUL", "healing")
    -- red under: keeping coreHealing and lesserHealing as two categories
    assertTrue(def ~= nil and def.kind == "spells", "a healing spell category")
    assertEqual(def.label, "Healing")
    assertEqual(def.desc, "Heal-over-time effects, shields and beacons.")
    for _, id in ipairs(HEALING) do assertTrue(def.spells[id] ~= nil, "starter " .. id) end
    local n = 0
    for _ in pairs(def.spells) do n = n + 1 end
    assertEqual(n, #HEALING, "the union, nothing more")
    assertEqual(Cat.Find("HELPFUL", "coreHealing"), nil)
    assertEqual(Cat.Find("HELPFUL", "lesserHealing"), nil)
    -- red under: appending healing at the end (the editor's category order would move)
    assertEqual(Cat.HELPFUL[6].key, "offensiveCDs")
    assertTrue(Cat.HELPFUL[7] == def, "after Offensive cooldowns, where Core healing buffs sat")
end)

test("defaults: a container draws in the Medium strata, the default UI's own layer (X-3)", function()
    -- red under: the template's strata left at HIGH. Batch 5's L-3 deliberately raised this to HIGH
    -- so a container drew above the default UI's Medium layer; batch 7's X-3 reverses that choice,
    -- so MEDIUM is once again what a new container gets.
    assertEqual(NS.CONTAINER_TEMPLATE.layout.strata, "MEDIUM")
end)

test("defaults: the global schema stamp defaults to 1, never the current version", function()
    -- red under: defaulting the stamp to the current schema version — AceDB fills an absent key
    -- before NS.RunMigrations reads it, so every old database would read as already migrated
    assertEqual(NS.defaults.global.schemaVersion, 1)
    assertEqual(type(NS.defaults.global.timedSpells), "table")
    assertEqual(next(NS.defaults.global.timedSpells), nil, "nothing learned by default")
end)

test("defaults: StatesShowing hides every buff category but the ones named, and leaves the debuff ones at Show", function()
    local states = Cat.StatesShowing({ "offensiveCDs", "defensives" })
    for _, def in ipairs(Cat.HELPFUL) do
        local want = (def.key == "offensiveCDs" or def.key == "defensives") and "show" or "hide"
        -- red under: StatesShowing leaving a token or flag category (or Uncategorized) at Show
        assertEqual(states[def.key], want, def.key)
    end
    for _, def in ipairs(Cat.HARMFUL) do
        -- red under: StatesShowing hiding the debuff categories (a switch to debuffs starts all-hidden)
        assertEqual(states[def.key], "show", def.key)
    end
    assertTrue(Cat.StatesShowing({}) ~= Cat.StatesShowing({}), "a fresh table each call")
end)
