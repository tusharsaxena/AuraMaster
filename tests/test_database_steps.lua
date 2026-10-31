-- tests/test_database_steps.lua — core/Database_Migrations.lua: schema v4 and v5, each step's stored
-- shapes and the starters they touch. Peeled out of tests/test_database.lua by theme. Each case
-- builds its own environment.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil
local fresh = dofile("tests/fresh_env.lua")

-- ---------------------------------------------------------------------------
-- Schema v4: "Only these categories" retired -> categories.<uncategorized key> = "hide"
-- ---------------------------------------------------------------------------

test("v4: a HELPFUL container with the toggle on ends up with Uncategorized hidden, and the dead key cleared", function()
    local NS = fresh()
    local p = { containers = { { auraType = "HELPFUL",
        filter = { onlyShown = true, categories = { defensives = "show" } } } } }
    local converted, lost = NS.Database.MigrateV4(p)
    assertEqual(converted, 1)
    assertEqual(lost, 0)
    local c = p.containers[1]
    assertEqual(c.filter.categories.uncategorized, "hide", "the toggle's old effect, preserved")
    assertNil(c.filter.onlyShown, "the dead key is cleared")
    -- untouched otherwise — the migration does not narrate a decision about defensives
    assertEqual(c.filter.categories.defensives, "show")
end)

-- Fix round 3: the owner restored the debuff row, with Hide reproducing the retired toggle exactly
-- (modules/FilterCompiler.lua's `hasUnion` gate — the compiler-side proof lives in
-- tests/test_filtercompiler.lua). A HARMFUL container now converts too, the same as HELPFUL.
test("v4: a HARMFUL container with the toggle on ends up with Uncategorized (debuffs) hidden, and the dead key cleared", function()
    local NS = fresh()
    local p = { containers = { { auraType = "HARMFUL",
        filter = { onlyShown = true, categories = { crowdControl = "hide" } } } } }
    local converted, lost = NS.Database.MigrateV4(p)
    assertEqual(converted, 1)
    assertEqual(lost, 0)
    local c = p.containers[1]
    assertEqual(c.filter.categories.uncategorizedDebuffs, "hide", "the toggle's old effect, preserved")
    assertNil(c.filter.onlyShown, "the dead key is cleared")
    assertEqual(c.filter.categories.crowdControl, "hide")
end)

test("v4: a container with the toggle off or absent is untouched", function()
    local NS = fresh()
    local p = { containers = {
        { auraType = "HELPFUL", filter = { onlyShown = false, categories = { defensives = "show" } } },
        { auraType = "HELPFUL", filter = { categories = { defensives = "show" } } },
    } }
    local before = NS.Database.DeepCopy(p)
    local converted, lost = NS.Database.MigrateV4(p)
    assertEqual(converted, 0)
    assertEqual(lost, 0)
    local Sig = NS.FilterCompiler.Signature
    assertEqual(Sig(p), Sig(before), "off or absent: not even the dead key is touched")
end)

test("v4: an ENCHANT container with the toggle on is neither converted nor lost — it compiles to no groups, so nothing was ever lost", function()
    -- red under: counting an ENCHANT container as `lost`, which docs/schema.md and the [Migrate]
    -- line would then overstate — FC.Compile's compileEnchant (retired at schema v5) never read filter.onlyShown at all.
    local NS = fresh()
    local p = { containers = { { auraType = "ENCHANT",
        filter = { onlyShown = true, categories = {} } } } }
    local converted, lost, lostList = NS.Database.MigrateV4(p)
    assertEqual(converted, 0)
    assertEqual(lost, 0)
    assertEqual(#lostList, 0)
    assertNil(p.containers[1].filter.onlyShown, "the dead key is still cleared, just not counted")
end)

test("v4: an unrecognized auraType with the toggle on is genuinely lost, named in lostList, and its dead key still cleared", function()
    -- The honest answer for a shape that carries no Uncategorized category and is not ENCHANT
    -- either (a corrupt or future auraType this migration cannot predict): counted, named, and the
    -- SCHEMA_STEPS v4 step turns this into a plain NS.Print notice — nothing invented, nothing silent.
    local NS = fresh()
    local p = { containers = { [7] = { auraType = "BOGUS", name = "Weird One",
        filter = { onlyShown = true, categories = {} } } } }
    local converted, lost, lostList = NS.Database.MigrateV4(p)
    assertEqual(converted, 0)
    assertEqual(lost, 1)
    assertEqual(#lostList, 1)
    assertEqual(lostList[1].id, 7)
    assertEqual(lostList[1].name, "Weird One")
    assertEqual(lostList[1].auraType, "BOGUS")
    assertNil(p.containers[7].filter.onlyShown, "the dead key is cleared even though nothing could be preserved")
end)

test("v4: MigrateV4 is idempotent", function()
    local NS = fresh()
    local function scenario()
        return { containers = {
            { auraType = "HELPFUL", filter = { onlyShown = true, categories = { defensives = "show" } } },
            { auraType = "HARMFUL", filter = { onlyShown = true, categories = { crowdControl = "hide" } } },
            { auraType = "ENCHANT", filter = { onlyShown = true, categories = {} } },
            { auraType = "BOGUS", filter = { onlyShown = true, categories = {} } },
            { auraType = "HELPFUL", filter = { categories = { defensives = "show" } } },
        } }
    end
    local once = scenario()
    NS.Database.MigrateV4(once)
    local twice = NS.Database.DeepCopy(once)
    local converted, lost, lostList = NS.Database.MigrateV4(twice)
    -- red under: a second run re-counting or re-touching a container the first run already decided
    assertEqual(converted, 0, "nothing left at onlyShown == true to convert again")
    assertEqual(lost, 0)
    assertEqual(#lostList, 0)
    local Sig = NS.FilterCompiler.Signature
    assertEqual(Sig(twice), Sig(once), "a second run is a true no-op")
end)

-- Item 3, fix round 3: NS.Debug alone is not enough — it is gated on a flag off by default, so a
-- player who never turned on debug logging would see NOTHING about a container that just silently
-- lost a capability. NS.Print is ungated: it always reaches the chat frame.
test("v4: a genuinely lost container's notice reaches NS.Print, not just NS.Debug (item 3)", function()
    local lines = {}
    local NS = fresh({
        savedVariables = { profiles = { Default = {
            seeded = true, nextContainerId = 2, containerOrder = { 1 },
            containers = { [1] = { name = "Weird One", unit = "player", auraType = "BOGUS", style = "bars",
                filter = { onlyShown = true, categories = {} } } },
        } }, global = { schemaVersion = 3 } },
        before = function(mocks)
            rawset(mocks.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
                lines[#lines + 1] = tostring(msg)
            end)
        end,
    })
    assertEqual(NS.db.global.schemaVersion, NS.Database.CurrentSchemaVersion())
    local found = false
    for _, l in ipairs(lines) do
        -- red under: the debug flag being off (the default) swallowing the only notice a player gets
        if l:find("Weird One", 1, true) and l:find("could not be carried over", 1, true) then found = true end
    end
    assertTrue(found, "NS.Print names the lost container plainly: " .. table.concat(lines, " | "))
end)

test("v4: no notice is printed when nothing was lost", function()
    local lines = {}
    local NS = fresh({
        savedVariables = { profiles = { Default = {
            seeded = true, nextContainerId = 2, containerOrder = { 1 },
            containers = { [1] = { name = "Mine", unit = "player", auraType = "HELPFUL", style = "bars",
                filter = { onlyShown = true, categories = { defensives = "show" } } } },
        } }, global = { schemaVersion = 3 } },
        before = function(mocks)
            rawset(mocks.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
                lines[#lines + 1] = tostring(msg)
            end)
        end,
    })
    assertEqual(NS.db.global.schemaVersion, NS.Database.CurrentSchemaVersion())
    for _, l in ipairs(lines) do
        assertTrue(l:find("could not be carried over", 1, true) == nil, "no lost-capability notice: " .. l)
    end
end)

test("database: a fresh profile seeds the Player cooldowns text container last, showing only two buff lists", function()
    local NS = fresh()
    local list = NS.Database.GetContainers()
    local n = #NS.STARTER_CONTAINERS
    assertEqual(#list, n)
    local c = list[n]
    -- red under: the starter list without its fourth entry, or seeded in another style
    assertEqual(c.name, "Player cooldowns")
    assertEqual(c.style, "text")
    assertEqual(c.unit, "player"); assertEqual(c.auraType, "HELPFUL")
    assertEqual(c.filter.categories.offensiveCDs, "show")
    assertEqual(c.filter.categories.defensives, "show")
    assertEqual(c.filter.categories.uncategorized, "hide")
    assertEqual(c.filter.categories.bigDefensive, "hide")
    assertEqual(c.text.template, NS.CONTAINER_TEMPLATE.text.template, "the rest is the template's")
end)

-- ---------------------------------------------------------------------------
-- Schema v5: the Weapon enchants aura type retires (feedback #6)
-- ---------------------------------------------------------------------------

--- A v4 container with the ENCHANT aura type, styled and placed as a player would have left it.
local function enchantContainer()
    return {
        name = "My enchants", enabled = true, unit = "target", auraType = "ENCHANT", style = "icons",
        filter = { hidePermanentEnchants = false, categories = { defensives = "show" }, sortDirection = "reverse" },
        position = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 12, y = -34 },
        icons = { width = 40, height = 40 },
    }
end

test("v5: an ENCHANT container becomes a player buff container showing only Weapon enchants, its look kept (feedback #6)", function()
    local NS = fresh()
    local p = { containers = { [7] = enchantContainer() } }
    local converted = NS.Database.MigrateV5(p)
    local c = p.containers[7]
    assertEqual(converted, 1)
    -- red under: the aura type left as ENCHANT (C.AURA_TYPES no longer offers it)
    assertEqual(c.auraType, "HELPFUL")
    -- red under: the unit carried over (enchants are only ever the player's)
    assertEqual(c.unit, "player")
    local cats = c.filter.categories
    assertEqual(cats.weaponEnchants, "show")
    for _, def in ipairs(NS.Categories.For("HELPFUL")) do
        if def.key ~= "weaponEnchants" then
            -- red under: a buff category left at Show (the container would draw auras too)
            assertEqual(cats[def.key], "hide", def.key)
        end
    end
    assertEqual(cats.uncategorized, "hide", "Uncategorized is hidden too")
    -- red under: the migration resetting what the player set
    assertEqual(c.filter.hidePermanentEnchants, false, "hide-permanent carries over")
    assertEqual(c.filter.sortDirection, "reverse")
    assertEqual(c.style, "icons"); assertEqual(c.icons.width, 40)
    assertEqual(c.position.x, 12); assertEqual(c.name, "My enchants")
end)

test("v5: a whitelist on the ENCHANT container is cleared, so the migrated container draws no buffs (fix round 1, review Important #1)", function()
    local NS = fresh()
    local c = enchantContainer()
    c.filter.whitelist = { [500] = true, [600] = true }
    local p = { containers = { [9] = c } }
    NS.Database.MigrateV5(p)
    -- red under: the whitelist kept, so FC.Compile's addWhitelistGroup still draws those buffs
    assertTrue(p.containers[9].filter.whitelist == nil, "the whitelist is cleared, not merely left empty")
    local plan = NS.FilterCompiler.Compile(p.containers[9], NS.FilterCompiler.ProfileContext())
    assertEqual(#plan.groups, 0, "no group at all -- only the enchant slots")
end)

test("v5: a container with no filter table at all still converts cleanly (review Minor #2)", function()
    local NS = fresh()
    local p = { containers = { [1] = { name = "Bare", unit = "target", auraType = "ENCHANT" } } }
    -- red under: MigrateV5 indexing a nil filter instead of building one
    assertEqual(NS.Database.MigrateV5(p), 1)
    local c = p.containers[1]
    assertEqual(c.auraType, "HELPFUL"); assertEqual(c.unit, "player")
    assertEqual(c.filter.categories.weaponEnchants, "show")
end)

test("v5: only ENCHANT containers are touched, and a second run changes nothing (feedback #6)", function()
    local NS = fresh()
    local buff = { name = "Buffs", unit = "target", auraType = "HELPFUL", filter = { categories = { defensives = "hide" } } }
    local p = { containers = { [1] = buff, [2] = enchantContainer() } }
    NS.Database.MigrateV5(p)
    -- red under: every container rewritten as an enchant container
    assertEqual(buff.unit, "target"); assertEqual(buff.filter.categories.defensives, "hide")
    assertTrue(buff.filter.categories.weaponEnchants == nil, "a buff container's categories are its own")
    local Sig = NS.FilterCompiler.Signature
    local once = Sig(p)
    -- red under: a second run re-stamping categories or re-counting a container it already converted
    assertEqual(NS.Database.MigrateV5(p), 0, "nothing left to convert")
    assertEqual(Sig(p), once)
end)

test("v5: RunMigrations converts every stored profile, and the result draws enchants only (feedback #6)", function()
    local function raw()
        return { seeded = true, nextContainerId = 3, containerOrder = { 2 }, containers = { [2] = enchantContainer() } }
    end
    local NS = fresh({ savedVariables = { profiles = { Default = raw(), Raid = raw() }, global = { schemaVersion = 4 } } })
    assertEqual(NS.db.global.schemaVersion, NS.Database.CurrentSchemaVersion())
    for _, name in ipairs({ "Default", "Raid" }) do
        local c = NS.db.sv.profiles[name].containers[2]
        -- red under: the step migrating the active profile only
        assertEqual(c.auraType, "HELPFUL", name)
        assertEqual(c.filter.categories.weaponEnchants, "show", name)
    end
    local plan = NS.FilterCompiler.Compile(NS.db.sv.profiles.Default.containers[2], NS.FilterCompiler.ProfileContext())
    local slotCount, groupCount, warnCount = #plan.enchants.slots, #plan.groups, #plan.warnings
    assertEqual(slotCount, 3, "the three enchant slots")
    assertEqual(groupCount, 0, "and no aura group")
    -- red under: finishWarnings calling an enchant-only container one that can never match
    assertEqual(warnCount, 0, table.concat(plan.warnings, " | "))
end)

test("v5: MigrateV5 logs one [Migrate] line per converted container, naming it (feedback #6)", function()
    local NS = fresh()
    local lines = {}
    NS.Debug = function(tag, fmt, ...)
        if tag == "Migrate" then
            local n = #lines
            lines[n + 1] = fmt:format(...)
        end
    end
    NS.Database.MigrateV5({ containers = { [3] = enchantContainer(), [4] = { auraType = "HARMFUL" }, [5] = enchantContainer() } })
    -- red under: the migration silent per container, or logging the untouched debuff one
    assertEqual(table.concat(lines, " | "), "v5 container '3' (My enchants): now a player buff container showing only Weapon enchants"
        .. " | v5 container '5' (My enchants): now a player buff container showing only Weapon enchants")
end)

test("v5: the profile's retired dispelColors.None leaf is cleared (feedback #7)", function()
    local NS = fresh()
    local p = { dispelColors = { Magic = { r = 0.2, g = 0.6, b = 1, a = 1 }, None = { r = 0.8, g = 0, b = 0, a = 1 } },
        containers = {} }
    NS.Database.MigrateV5(p)
    -- red under: MigrateV5 leaving a color nothing reads in every old profile
    assertEqual(p.dispelColors.None, nil)
    assertEqual(p.dispelColors.Magic.r, 0.2, "the palette's colors stay")
end)

-- smoke batch 2, B2-2: the pickers list containers by name, case-insensitively, the id breaking a
-- tie. Names are unique regardless of case (CM.UniqueName), so a tie is written straight to the store.
test("database: GetContainersByName sorts by name, case-insensitively, the id breaking a tie; display order untouched (B2-2)", function()
    local NS = fresh()
    local cs = NS.db.profile.containers
    cs[1].name, cs[2].name, cs[3].name, cs[4].name = "zeta", "Alpha", "beta", "ALPHA"
    local ids = {}
    for i, c in ipairs(NS.Database.GetContainersByName()) do ids[i] = c.id end
    -- red under: display order (1,2,3,4), or a byte sort (4,2,3,1: "ALPHA" sorts before "Alpha")
    assertEqual(table.concat(ids, ","), "2,4,3,1")
    ids = {}
    for i, c in ipairs(NS.Database.GetContainers()) do ids[i] = c.id end
    assertEqual(table.concat(ids, ","), "1,2,3,4", "GetContainers keeps the display order")
    assertEqual(table.concat(NS.db.profile.containerOrder, ","), "1,2,3,4", "and the store is untouched")
end)
