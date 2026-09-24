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
-- userCategories and userCategoryOrder (issue #10 checkpoint 3) join categorySpells here for the
-- same reason: they are maps the PLAYER fills, written by defaults/UserCategories.lua's create and
-- rename acts rather than by a settings row, so there is no row for a row-shaped test to find.
local PROFILE_CARVE_OUTS = set({ "categorySpells", "userCategories", "userCategoryOrder" })

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

test("defaults: every shipped category answers its own aura type through AuraTypeOf, by def and by key", function()
    -- Issue #10 checkpoint 2. Before it, a category's aura type was readable only as "which list did
    -- this come out of" -- `Cat.AuraTypeOf` is the one question the dropdown markers and every later
    -- checkpoint ask of a single definition, so it is asserted against the SHIPPED lists, both ways
    -- of asking, every row.
    local seen = {}
    for _, auraType in ipairs({ "HELPFUL", "HARMFUL" }) do
        local n = 0
        for _, def in ipairs(Cat.For(auraType)) do
            -- red under: the load-time stamp dropped, or stamping only one of the two lists
            assertEqual(Cat.AuraTypeOf(def), auraType, def.key .. " (by def)")
            -- red under: the key form searching only HELPFUL, the bug Cat.IsSpellCategory once had
            assertEqual(Cat.AuraTypeOf(def.key), auraType, def.key .. " (by key)")
            assertEqual(def.auraType, auraType, def.key .. ": the field itself")
            n = n + 1
        end
        assertTrue(n > 0, auraType .. " ships no categories")
        seen[auraType] = n
    end
    -- red under: an accessor that happens to work because only one aura type was exercised
    assertTrue(seen.HELPFUL ~= nil and seen.HARMFUL ~= nil, "both aura types were covered")
    -- The two rows the marker design turns on: the enchant row is buff-side though it is no spell
    -- list, and issue #11's debuff lists are the reason the dropdown is no longer buff-only.
    assertEqual(Cat.AuraTypeOf("weaponEnchants"), "HELPFUL")
    assertEqual(Cat.AuraTypeOf("hardCC"), "HARMFUL")
end)

test("defaults: AuraTypeOf is total — nil for an unknown key and for anything that is not a definition", function()
    -- A stored container may name a category this build does not have (a retired key, and once user
    -- categories can be deleted, a key whose category is gone), so the accessor must answer rather
    -- than fail -- exactly as Cat.Find already leaves the decision to its caller.
    assertEqual(Cat.AuraTypeOf("no such category"), nil)
    assertEqual(Cat.AuraTypeOf(nil), nil)
    assertEqual(Cat.AuraTypeOf(42), nil)
    -- red under: reading the field off the def being skipped for a lookup by key — a user category
    -- (checkpoint 3) is a def that is in NEITHER shipped list and must still answer.
    assertEqual(Cat.AuraTypeOf({ key = "notShipped", auraType = "HARMFUL" }), "HARMFUL")
    assertEqual(Cat.AuraTypeOf({ key = "notShipped" }), nil, "a def with no stamp says so")
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

test("defaults: the global schema stamp defaults to 0, never the current version", function()
    -- red under: defaulting the stamp to 1 or to the current schema version. AceDB fills an absent
    -- key before NS.RunMigrations reads it (a current-version default reads every old database as
    -- already migrated), and strips a stored value equal to its default at logout (a stamp equal
    -- to a non-zero default is lost). 0 is safe against both (savedvariables-§1, v2.65.0).
    assertEqual(NS.defaults.global.schemaVersion, 0)
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

-- ── user categories (issue #10 checkpoint 3) ──────────────────────────────────────────────────
--
-- Every case below builds its own environment: materializing a user category MUTATES Cat.HELPFUL,
-- the container template and NS.Schema, and the shared environment tests/run.lua builds is read by
-- every other suite.

local fresh = dofile("tests/fresh_env.lua")

--- A fresh environment holding `n` user categories, created through the real act. Returns the NS and
--- the keys in creation order.
local function withUserCategories(specs)
    local NS2 = fresh()
    local keys = {}
    for i, spec in ipairs(specs) do
        local key = NS2.Categories.CreateUserCategory(spec[1], spec[2])
        keys[i] = key
    end
    return NS2, keys
end

test("defaults: no shipped category key sits in the reserved 'user' namespace", function()
    -- red under: a category added to defaults/Categories.lua with a key like `userFavorites`. The
    -- prefix is what guarantees a generated user key can never shadow a shipped one, so it is a
    -- promise about THIS file, not about the generator (defaults/UserCategories.lua's Cat.NewUserKey).
    for _, list in ipairs({ Cat.HELPFUL, Cat.HARMFUL }) do
        for _, def in ipairs(list) do
            assertTrue(def.key:find("^user") == nil, def.key .. " takes the reserved user namespace")
        end
    end
end)

test("defaults: SanitizeUserName strips the escape character and control characters, trims and caps", function()
    local s = Cat.SanitizeUserName
    -- red under: storing a name that can open a color, texture or hyperlink escape in the grid row
    -- and the tooltip the label reaches (defaults/UserCategories.lua's note above the function).
    assertEqual(s("|cffff0000Mine|r"), "cffff0000Miner")
    assertEqual(s("Big\tCDs"), "BigCDs")
    assertEqual(s("  Raid cooldowns  "), "Raid cooldowns")
    assertEqual(s("100% uptime"), "100% uptime", "a percent sign is an ordinary character in a name")
    assertTrue(s("   ") == nil, "whitespace alone is not a name")
    assertTrue(s("") == nil)
    assertTrue(s(nil) == nil)
    assertTrue(s(42) == nil)
    local long = s(("x"):rep(200))
    assertEqual(#long, 40, "capped, so a grid row stays a row")
end)

test("defaults: NewUserKey is namespaced and terminates against a generator that always collides", function()
    local key = Cat.NewUserKey({})
    assertEqual(key:sub(1, 4), "user")
    assertEqual(#key, 14, "the prefix plus ten base-36 characters")
    assertTrue(key:find("^user[0-9a-z]+$") ~= nil, key)
    -- A degenerate generator answers the same character for ever, so every attempt produces the same
    -- ten characters; the attempt counter appended past the fifth try is what makes termination a
    -- property of the loop rather than of the generator.
    local stuck = function() return 1 end
    local base = Cat.NewUserKey({}, stuck)
    local taken = { [base] = true }
    for i = 6, 9 do taken[base .. i] = true end
    local escaped = Cat.NewUserKey(taken, stuck)
    -- red under: the loop returning a key that is already taken, or spinning for ever
    assertTrue(taken[escaped] == nil, escaped .. " was already taken")
    assertEqual(escaped, base .. "10")
end)

test("defaults: the key generator is the client's own, not the shared unseeded math.random", function()
    -- The justification for a random key over a counter is that two categories created
    -- independently cannot collide. `math.random` alone did not earn it: nothing in the addon ever
    -- called `math.randomseed`, so in Lua 5.1 every client walks the SAME sequence from its first
    -- draw and two players making their first category would have been handed one key between them.
    --
    -- Both halves are pinned by SEEDING THE SHARED GENERATOR IDENTICALLY first. That is what a fresh
    -- client looks like from inside one test process: two clients cannot be two processes here, and
    -- consecutive `math.random` draws differ within one process however unseeded it is, so a naive
    -- "these two sequences differ" case would pass over the bug it is meant to catch.
    local function firstKey(guid)
        math.randomseed(1)
        local NS2 = fresh({ before = function(mocks) mocks.__playerGUID = guid end })
        return NS2.Categories.NewUserKey({})
    end
    -- red under: `rand = rand or math.random`. Two clients whose shared generator is in the same
    -- state draw the same key unless the addon's own seed distinguishes them -- and the player GUID
    -- is the ingredient that does.
    assertTrue(firstKey("Player-1234-0AAAAAA1") ~= firstKey("Player-5678-0BBBBBB2"),
        "two characters, two keys")

    local NS3 = fresh()
    math.randomseed(1)
    local one = NS3.Categories.NewUserKey({})
    math.randomseed(1)
    local two = NS3.Categories.NewUserKey({})
    -- red under the same revert, from the other side: reseeding the SHARED generator must not rewind
    -- this addon's keys. The client runs every addon in one Lua state, so the generator has to be
    -- this file's own -- which is also why nothing here calls `math.randomseed` itself.
    assertTrue(one ~= two, "the shared generator's state does not decide our keys")
    for _, key in ipairs({ one, two }) do
        assertTrue(key:find("^user[0-9a-z]+$") ~= nil, key)
        assertEqual(#key, 14, "the prefix plus ten base-36 characters")
    end

    -- A client that answers no GUID -- the seed's one genuinely distinguishing ingredient is absent
    -- until the player is in the world -- still produces well-formed, distinct keys off the rest.
    local NS4 = fresh({ before = function(mocks) mocks.__playerGUID = false end })
    local a, b = NS4.Categories.NewUserKey({}), NS4.Categories.NewUserKey({})
    assertTrue(a:find("^user[0-9a-z]+$") ~= nil, a)
    assertTrue(a ~= b)
end)

test("defaults: a user category materializes among the spell lists, above Weapon enchants, Uncategorized still last", function()
    local NS2, keys = withUserCategories({ { "My cooldowns", "HELPFUL" }, { "Their nonsense", "HARMFUL" } })
    local C2 = NS2.Categories
    local at = {}
    for i, def in ipairs(C2.HELPFUL) do at[def.key] = i end
    -- red under: appending a user definition after Weapon enchants or after Uncategorized (U-1)
    assertTrue(at[keys[1]] < at.weaponEnchants, "a user category sits above Weapon enchants")
    assertTrue(at.consumables < at[keys[1]], "and below the shipped spell lists it is a sibling of")
    assertEqual(C2.HELPFUL[#C2.HELPFUL].key, "uncategorized", "U-1 survives materialization")
    assertEqual(C2.HARMFUL[#C2.HARMFUL].key, "uncategorizedDebuffs")
    local def = C2.Find("HELPFUL", keys[1])
    assertTrue(def ~= nil and def.kind == "spells", "an ordinary spells-kind definition")
    assertEqual(def.label, "My cooldowns")
    assertEqual(def.auraType, "HELPFUL")
    assertTrue(def.userCategory, "the one marker that tells a user definition from a shipped one")
    assertEqual(next(def.spells), nil, "an EMPTY starter list: the list IS categorySpells[key]")
    assertTrue(C2.IsSpellCategory(keys[1]), "so General -> Spell Categories can edit it")
    assertEqual(C2.DefaultStates()[keys[1]], "show")
    -- The debuff one landed on the other list, and only on the other list.
    assertTrue(C2.Find("HARMFUL", keys[2]) ~= nil)
    assertTrue(C2.Find("HELPFUL", keys[2]) == nil)
end)

test("defaults: schema order tracks Cat.For order per aura type, user categories included", function()
    local NS2 = withUserCategories({ { "Mine", "HELPFUL" }, { "Also mine", "HELPFUL" }, { "Theirs", "HARMFUL" } })
    local index = {}
    for i, row in ipairs(NS2.Schema) do
        if index[row.path] == nil then index[row.path] = i end
    end
    -- settings/Filters.lua's renderCategories draws each grid in SCHEMA order, not in Cat.For order,
    -- so this equality is what keeps Uncategorized last on screen. red under: a user row appended to
    -- the end of NS.Schema instead of inserted before the aura type's enchant/uncategorized row.
    for _, auraType in ipairs({ "HELPFUL", "HARMFUL" }) do
        local previous, previousKey = 0, "(none)"
        for _, def in ipairs(NS2.Categories.For(auraType)) do
            local i = index["container.filter.categories." .. def.key]
            assertTrue(i ~= nil, def.key .. " has no schema row")
            assertTrue(i > previous, def.key .. " is registered before " .. previousKey)
            previous, previousKey = i, def.key
        end
    end
end)

test("defaults: a user category's name is unrouted by design, and its description is not", function()
    -- The locale exemption tests/test_locale.lua makes, proved from the other side: the NAME cannot
    -- have an enUS line (it is the player's text and no build could ship one), and the DESCRIPTION
    -- must, which is exactly why the exemption is one FIELD of one flagged definition kind rather
    -- than the whole definition.
    local NS2, keys = withUserCategories({ { "Affixes I care about", "HELPFUL" } })
    local fh = io.open("locales/enUS.lua", "r")
    assertTrue(fh ~= nil, "cannot open locales/enUS.lua (tests run from the repo root)")
    local body = fh:read("*a")
    fh:close()
    local defined = {}
    for key in body:gmatch('\nL%["(.-)"%] = ') do defined[key] = true end
    local def = NS2.Categories.Find("HELPFUL", keys[1])
    assertTrue(defined[def.label] == nil, "a player's own name must never be a locale key")
    -- red under: building the description out of the name, which would drag the player's text into
    -- the one field the guard still checks
    assertTrue(defined[def.desc], "the description is a shipped string and stays routed: " .. def.desc)
end)

test("defaults: a sync canonicalizes a stored user name in the store, not only at the draw", function()
    -- A characterization (AM-13, before Cat.SyncUserCategories was split into phases): the
    -- materialize phase writes the sanitized name back to the record and stamps its key.
    local NS2 = fresh()
    local p = NS2.db.profile
    p.userCategories = { userpadded = { name = "  Padded  ", auraType = "HARMFUL" } }
    p.userCategoryOrder = { "userpadded" }
    assertEqual(NS2.Categories.SyncUserCategories(p), 1)
    -- red under: sanitizing only the definition's label, which leaves two versions of one name
    assertEqual(p.userCategories.userpadded.name, "Padded", "the stored name is canonical")
    assertEqual(p.userCategories.userpadded.key, "userpadded", "and the record carries its key")
    assertEqual(NS2.Categories.Find("HARMFUL", "userpadded").label, "Padded")
    assertEqual(NS2.FindSchemaRow("container.filter.categories.userpadded").label, "Padded")
    assertEqual(NS2.CONTAINER_TEMPLATE.filter.categories.userpadded, "show")
    assertEqual(NS2.ValidateSchema(), 0)
end)

test("defaults: a corrupt user record is skipped and left on disk, never coerced", function()
    local NS2 = fresh()
    local p = NS2.db.profile
    p.userCategories = {
        usergood   = { key = "usergood", name = "Fine", auraType = "HELPFUL" },
        usernoType = { key = "usernoType", name = "Fine too", auraType = "BOTH" },
        usernoName = { key = "usernoName", name = "   ", auraType = "HELPFUL" },
        usernotATable = 7,
    }
    p.userCategoryOrder = { "usergood", "usernoType", "usernoName", "usernotATable" }
    local made = NS2.Categories.SyncUserCategories(p)
    assertEqual(made, 1, "one usable record of four")
    -- red under: coercing an unknown aura type to HELPFUL, which silently moves the category between
    -- two grids and orphans every container's stored state for it (the immutability decision).
    assertTrue(NS2.Categories.Find("HELPFUL", "usernoType") == nil)
    assertTrue(NS2.Categories.Find("HARMFUL", "usernoType") == nil)
    assertTrue(NS2.Categories.Find("HELPFUL", "usernoName") == nil)
    assertTrue(NS2.Categories.Find("HELPFUL", "usergood") ~= nil)
    -- Skipped, not deleted: the records are still on disk for the player to fix or remove.
    assertTrue(p.userCategories.usernoType ~= nil, "a skipped record is left alone")
    assertTrue(p.userCategories.usernoName ~= nil)
    assertEqual(NS2.ValidateSchema(), 0, "and no row is left over from the ones that were skipped")
end)

test("defaults: a record outside the reserved namespace cannot hijack a shipped category", function()
    -- The most damaging shape a hand-edited or corrupt SavedVariables file can take: a record keyed
    -- with a SHIPPED category's key. It is refused for the same reason an unknown aura type is --
    -- it is not a user category with a bad field, it is a claim on another category's identity.
    local NS2 = fresh()
    local C2, p = NS2.Categories, NS2.db.profile
    assertTrue(C2.Find("HELPFUL", "healing") ~= nil, "healing is a shipped category (the premise)")
    p.userCategories = {
        healing = { key = "healing", name = "Mine", auraType = "HELPFUL" },
        userok  = { key = "userok", name = "Also mine", auraType = "HELPFUL" },
    }
    p.userCategoryOrder = { "healing", "userok" }
    -- red under: usableName checking the RECORD and never the KEY, which materialized the record
    -- into Cat.HELPFUL beside the shipped healing -- two definitions under one key.
    assertEqual(C2.SyncUserCategories(p), 1, "the namespaced record only")
    local n = 0
    for _, def in ipairs(C2.HELPFUL) do
        if def.key == "healing" then n = n + 1 end
    end
    assertEqual(n, 1, "exactly one definition is keyed healing, and it is the shipped one")
    assertTrue(C2.IsUserCategory("healing") == false, "the shipped definition is the survivor")
    assertEqual(C2.Find("HELPFUL", "healing").label, "Healing", "with the shipped label intact")
    assertTrue(p.userCategories.healing ~= nil, "and the record is left on disk, not deleted")

    -- THE CONSEQUENCE, which is what makes this worth a guard rather than a shrug. Teardown finds a
    -- user definition BY KEY, so a materialized `healing` takes the SHIPPED healing's entry out of
    -- the container template with it at the very next sync -- a profile switch, a copy or a reset --
    -- and never puts it back. NS.DefaultFor then answers nil for a row the player never touched.
    C2.SyncUserCategories({})
    assertEqual(NS2.CONTAINER_TEMPLATE.filter.categories.healing, "show",
        "the shipped key survives a later sync")
    assertEqual(NS2.DefaultFor("container.filter.categories.healing"), "show")
    assertEqual(NS2.ValidateSchema(), 0, "so no shipped row is left without a default")
end)

test("defaults: a user category's name is shown as typed even when it is a shipped locale key", function()
    -- NS.L hands back any key it has no line for, so an unguarded `L[def.label]` is invisible on
    -- enUS for most names and WRONG for the handful that collide with a real shipped line. "Healing"
    -- is one: it is the enUS text of the shipped `healing` category's label key.
    local NS2, keys = withUserCategories({ { "Healing", "HELPFUL" } })
    local def = NS2.Categories.Find("HELPFUL", keys[1])
    -- red under: any category-labeling site indexing NS.L with a user def's label. Only the shipped
    -- definition's label is a key; the user one's is the player's text and is returned untouched.
    assertEqual(NS2.Categories.LabelOf(def), "Healing")
    assertEqual(NS2.Categories.LabelOf(NS2.Categories.Find("HELPFUL", "healing")), "Healing")
    -- The two are indistinguishable on enUS by design, so the guard is proved on the OTHER side:
    -- a locale line that translates the shipped key must not reach the player's category.
    NS2.L["Healing"] = "Heilung"
    assertEqual(NS2.Categories.LabelOf(def), "Healing", "the player's own text, whatever locale says")
    assertEqual(NS2.Categories.LabelOf(NS2.Categories.Find("HELPFUL", "healing")), "Heilung")
    assertEqual(NS2.FindSchemaRow("container.filter.categories." .. keys[1]).label, "Healing",
        "and the schema row, built at the moment of creation, carries the same text")
end)

test("defaults: userCategoryOrder is reconciled the way containerOrder is", function()
    local NS2 = fresh()
    local p = NS2.db.profile
    p.userCategories = {
        usera = { key = "usera", name = "A", auraType = "HELPFUL" },
        userb = { key = "userb", name = "B", auraType = "HELPFUL" },
        userc = { key = "userc", name = "C", auraType = "HELPFUL" },
    }
    -- A dangling key, a duplicate, and two records with no entry at all.
    p.userCategoryOrder = { "userb", "gone", "userb" }
    local order = NS2.Categories.UserCategoryOrder(p)
    -- red under: leaving group order to `pairs` over userCategories, which varies between logins and
    -- rebuilds every container that has anything Hidden (FC.StructureKey counts groups).
    assertEqual(table.concat(order, ","), "userb,usera,userc",
        "dangling and duplicate dropped, orphans appended sorted")
    assertEqual(table.concat(p.userCategoryOrder, ","), "userb,usera,userc", "and written back")
    NS2.Categories.SyncUserCategories(p)
    local seen = {}
    for _, def in ipairs(NS2.Categories.HELPFUL) do
        if def.userCategory then
            seen[#seen + 1] = def.key
        end
    end
    assertEqual(table.concat(seen, ","), "userb,usera,userc",
        "declaration order follows the reconciled order")
end)
