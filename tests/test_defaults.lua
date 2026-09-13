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

test("defaults: spell categories are buff categories, and IsSpellCategory names exactly them", function()
    for _, def in ipairs(Cat.HARMFUL) do
        -- red under: a debuff spell list (Blizzard ignores spell ids for debuffs on friendly units)
        assertTrue(def.kind ~= "spells", "debuff category " .. def.key)
        assertFalse(Cat.IsSpellCategory(def.key), def.key)
    end
    local spellCats = 0
    for _, def in ipairs(Cat.HELPFUL) do
        assertEqual(Cat.IsSpellCategory(def.key), def.kind == "spells", def.key)
        if def.kind == "spells" then spellCats = spellCats + 1 end
    end
    assertTrue(spellCats > 0, "the editor has something to edit")
    assertFalse(Cat.IsSpellCategory("no such category"))
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

test("defaults: a container draws in the High strata, above the default UI's Medium layer (L-3)", function()
    -- red under: the template's strata left at MEDIUM
    assertEqual(NS.CONTAINER_TEMPLATE.layout.strata, "HIGH")
end)

test("defaults: the global schema stamp defaults to 1, never the current version", function()
    -- red under: defaulting the stamp to the current schema version — AceDB fills an absent key
    -- before NS.RunMigrations reads it, so every old database would read as already migrated
    assertEqual(NS.defaults.global.schemaVersion, 1)
    assertEqual(type(NS.defaults.global.timedSpells), "table")
    assertEqual(next(NS.defaults.global.timedSpells), nil, "nothing learned by default")
end)
