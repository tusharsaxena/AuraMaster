-- tests/test_database_categories.lua — core/Database.lua's user-category store: storage, keying,
-- the dynamic category rows, and deletion with its cross-profile cleanup (issue #10). Peeled out of
-- tests/test_database.lua along its user-categories seam (issue #17). Each case that writes builds its
-- own environment.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")

-- ── user categories: storage, keying, dynamic rows (issue #10 checkpoint 3) ────────────────────
--
-- This is the checkpoint that can corrupt stored player data -- a spell list silently deleted by an
-- unrelated write, a dead category key written into every container of every profile -- so the cases
-- below are as much the deliverable as the code is.

--- The saved variables a session left behind, fed to a new one: a genuine reload, not a second read
--- of the same live tables.
local function reload()
    local saved = _G.AuraMasterDB
    local copy = {}
    local function deep(v)
        if type(v) ~= "table" then return v end
        local out = {}
        for k, item in pairs(v) do out[k] = deep(item) end
        return out
    end
    for k, v in pairs(saved or {}) do copy[k] = deep(v) end
    return fresh({ savedVariables = copy })
end

test("v6: MigrateV6 stamps the user-category store, and a second run changes nothing", function()
    local NS = fresh()
    local p = {}
    assertEqual(NS.Database.MigrateV6(p), 0)
    assertEqual(type(p.userCategories), "table")
    assertEqual(type(p.userCategoryOrder), "table")
    p.userCategories.userabcdefghij = { key = "userabcdefghij", name = "Mine", auraType = "HELPFUL" }
    p.userCategoryOrder[1] = "userabcdefghij"
    -- red under: a step that recreates or clears what it already stamped
    assertEqual(NS.Database.MigrateV6(p), 1, "the second run counts what is there and converts nothing")
    assertEqual(#p.userCategoryOrder, 1)
    assertEqual(p.userCategories.userabcdefghij.name, "Mine")
    -- A hand-edited or corrupt leaf is REPLACED rather than left for later code to index.
    p.userCategories = "junk"
    NS.Database.MigrateV6(p)
    assertEqual(type(p.userCategories), "table")
    assertEqual(NS.Database.MigrateV6(nil), 0, "a non-table profile is not an error")
end)

test("v6: a profile that predates user categories climbs the ladder and stays valid", function()
    local function raw()
        return {
            seeded = true, nextContainerId = 2, containerOrder = { 1 },
            containers = { [1] = { name = "Mine", unit = "player", auraType = "HELPFUL", style = "bars" } },
        }
    end
    local NS = fresh({ savedVariables = { profiles = { Default = raw(), Raid = raw() }, global = { schemaVersion = 5 } } })
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
    for _, name in ipairs({ "Default", "Raid" }) do
        local p = NS.db.sv.profiles[name]
        -- red under: the step touching the active profile only, as every step before it must not
        assertEqual(type(p.userCategories), "table", name)
        assertEqual(type(p.userCategoryOrder), "table", name)
        assertEqual(next(p.userCategories), nil, name .. " invented a category")
    end
    assertEqual(NS.ValidateSchema(), 0, "and every schema row still resolves")
end)

test("v7: MigrateV7 retires Consumables and seeds the new categories from where their auras fell", function()
    local NS = fresh()
    local p = {
        categorySpells = {
            consumables = { [431971] = false, [900001] = true },
            support = { [1459] = false, [10060] = false },   -- a group buff, and a Support starter that stays
            utility = { [58984] = false },                   -- Shadowmeld, now a racial
            groupBuffs = { [21562] = true },
        },
        containers = {
            [1] = { filter = { categories = { support = "hide", uncategorized = "hide", consumables = "show" } } },
            [2] = { filter = { categories = { support = "show", uncategorized = "show" } } },
            [3] = { filter = { categories = { support = "hide", groupBuffs = "show" } } },
            [4] = { name = "no filter" },
        },
    }
    assertEqual(NS.Database.MigrateV7(p), 3)
    local c1, c2, c3 = p.containers[1].filter.categories, p.containers[2].filter.categories,
        p.containers[3].filter.categories
    -- red under: leaving the retired key behind
    assertNil(c1.consumables)
    -- red under: leaving the new keys to the backfill's Show, which would draw raid buffs and
    -- stances on a container that hid Support or Uncategorized
    assertEqual(c1.groupBuffs, "hide", "Group buffs takes Support's state")
    assertEqual(c1.stances, "hide", "Stances takes Uncategorized's")
    assertEqual(c1.racials, "hide", "and so does Racials")
    assertEqual(c2.groupBuffs, "show")
    assertEqual(c2.racials, "show")
    -- red under: overwriting a state already stored
    assertEqual(c3.groupBuffs, "show", "a stored state is a choice")
    assertNil(c3.stances, "an absent source leaves the key to the backfill")
    local spellEdits = p.categorySpells
    assertNil(spellEdits.consumables, "Consumables edits go with the category")
    -- red under: the player's edits staying on the list their ids left
    assertEqual(spellEdits.groupBuffs[1459], false, "a Support edit on a group buff follows it")
    assertEqual(spellEdits.groupBuffs[21562], true, "beside what Group buffs already held")
    assertNil(spellEdits.support[1459])
    assertEqual(spellEdits.support[10060], false, "a Support edit on an id that stayed is kept")
    assertEqual(spellEdits.racials[58984], false, "Shadowmeld's Utility edit follows it to Racials")
    assertNil(spellEdits.utility, "a list left with no edits is not stored")
end)

test("v7: the debuff-side Racials is Hidden wherever Hard CC or Soft CC is", function()
    local NS = fresh()
    local p = { containers = {
        [1] = { filter = { categories = { hardCC = "hide", softCC = "show" } } },
        [2] = { filter = { categories = { hardCC = "show", softCC = "hide" } } },
        [3] = { filter = { categories = { hardCC = "show", softCC = "show" } } },
        [4] = { filter = { categories = { hardCC = "show", racialDebuffs = "show", softCC = "hide" } } },
        [5] = { filter = { categories = { defensives = "show" } } },
    } }
    NS.Database.MigrateV7(p)
    local function state(i) return p.containers[i].filter.categories.racialDebuffs end
    -- red under: leaving it to the backfill's Show, whose claim would beat Hard CC's Hide and draw a
    -- War Stomp the container hid
    assertEqual(state(1), "hide")
    assertEqual(state(2), "hide")
    assertEqual(state(3), "show")
    assertEqual(state(4), "show", "a stored state is a choice")
    assertNil(state(5), "a buff container gets no debuff key")
end)

test("v7: a second MigrateV7 run changes nothing, and a new key's stored edit wins over a moved one", function()
    local NS = fresh()
    local p = {
        categorySpells = { support = { [6673] = false }, groupBuffs = { [6673] = true } },
        containers = { [1] = { filter = { categories = { support = "hide", uncategorized = "show" } } } },
    }
    NS.Database.MigrateV7(p)
    -- red under: a moved edit overwriting one the new category already had
    assertEqual(p.categorySpells.groupBuffs[6673], true)
    assertNil(p.categorySpells.support)
    local cats = p.containers[1].filter.categories
    local snapshot = {}
    for k, v in pairs(cats) do snapshot[k] = v end
    p.containers[1].filter.categories.support = "show"   -- a later change of Support's state
    NS.Database.MigrateV7(p)
    -- red under: re-seeding from the source on every run
    assertEqual(cats.groupBuffs, snapshot.groupBuffs, "the seed happens once")
    assertEqual(cats.stances, "show")
end)

test("v7: a v6 profile climbs to v7 with every schema row still resolving", function()
    local function raw()
        return {
            seeded = true, nextContainerId = 2, containerOrder = { 1 }, userCategories = {}, userCategoryOrder = {},
            containers = { [1] = { name = "Mine", unit = "player", auraType = "HELPFUL", style = "bars",
                filter = { categories = { support = "hide", uncategorized = "hide", consumables = "hide" } } } },
        }
    end
    local NS = fresh({ savedVariables = { profiles = { Default = raw(), Raid = raw() }, global = { schemaVersion = 6 } } })
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
    for _, name in ipairs({ "Default", "Raid" }) do
        local cats = NS.db.sv.profiles[name].containers[1].filter.categories
        -- red under: the step touching the active profile only
        assertNil(cats.consumables, name)
        assertEqual(cats.groupBuffs, "hide", name)
        assertEqual(cats.racials, "hide", name)
    end
    assertEqual(NS.ValidateSchema(), 0, "and every schema row still resolves")
end)

test("user categories: one round-trips through a reload, with its spells", function()
    local NS = fresh()
    local key = NS.Categories.CreateUserCategory("Affixes", "HELPFUL")
    assertTrue(key ~= nil, "created")
    NS.SetByPath("categorySpells", { [key] = { [424242] = true, [424243] = true } })
    -- The list is categorySpells[key] like every other category's edits: no second store.
    assertEqual(NS.db.profile.categorySpells[key][424242], true)

    local NS2 = reload()
    local def = NS2.Categories.Find("HELPFUL", key)
    -- red under: the record surviving but the definition not being rebuilt at load
    assertTrue(def ~= nil, "the definition is materialized again at load")
    assertEqual(def.label, "Affixes")
    assertEqual(def.auraType, "HELPFUL")
    local spells = NS2.FilterCompiler.CategorySpells(def, NS2.db.profile.categorySpells)
    assertEqual(spells[424242], true)
    assertEqual(spells[424243], true)
    assertEqual(NS2.ValidateSchema(), 0)
end)

test("user categories: the sync runs BEFORE PrepareProfile, so a stored one reaches every container", function()
    -- THE ORDER IN NS.RunMigrations IS LOAD-BEARING (core/Database.lua). PrepareProfile's
    -- backfillContainers is what stamps the container template's category keys into every stored
    -- container, and the template only carries a user category's key once the sync has materialized
    -- it. Run the two the other way round and the backfill walks a template that does not yet know
    -- the key, so the stored container carries NO state for it.
    --
    -- A category created in this session hides the bug -- Cat.CreateUserCategory runs its own
    -- PrepareProfile -- so the shape that exposes it is a record already on disk whose key no
    -- container has yet: a profile written by another client, or an import (#9).
    local K = "userabcdefghij"
    local NS = fresh({ savedVariables = { global = { schemaVersion = 6 }, profiles = { Default = {
        seeded = true, nextContainerId = 2, containerOrder = { 1 },
        containers = { [1] = { name = "Mine", unit = "player", auraType = "HELPFUL", style = "bars" } },
        userCategories = { [K] = { key = K, name = "Affixes", auraType = "HELPFUL" } },
        userCategoryOrder = { K },
    } } } })
    assertTrue(NS.Categories.Find("HELPFUL", K) ~= nil, "materialized at load (the premise)")
    local con = NS.db.profile.containers[1]
    -- red under: swapping the two lines in NS.RunMigrations. The compiler would not notice
    -- (splitCategories reads an absent state as Show, the default anyway), but the settings panel
    -- would: a ChoiceGrid cell lights by comparing the STORED value against its column, so the row
    -- draws with neither Show nor Hide lit until something else writes it.
    assertEqual(con.filter.categories[K], "show", "the stored container was backfilled with the key")
    assertEqual(NS.ValidateSchema(), 0)
end)

test("user categories: the schema row resolves, and the seam reads and writes it per container", function()
    local NS = fresh()
    local key = NS.Categories.CreateUserCategory("Affixes", "HELPFUL")
    local path = "container.filter.categories." .. key
    local row = NS.FindSchemaRow(path)
    -- red under: registering the definition without its row, which would leave the category
    -- invisible to /am get|set|list, to a page's Defaults and to every reset
    assertTrue(row ~= nil, "a schema row exists for a key that did not exist at load")
    assertEqual(row.default, "show", "stamped from the container template, like every other row")
    assertEqual(row.grid, "custom")
    assertEqual(row.type, "string")
    assertTrue(row.auraTypes.HELPFUL, "offered on buff containers")
    assertTrue(row.auraTypes.HARMFUL == nil, "and not on debuff ones")
    assertEqual(row.label, "Affixes", "the player's own text, straight through NS.L's miss path")
    assertEqual(NS.DefaultFor(path), "show")
    assertEqual(NS.CONTAINER_TEMPLATE.filter.categories[key], "show")

    local id = NS.Database.GetContainers()[1].id
    assertEqual(NS.GetSetting(path, id), "show", "the backfill stamped it into every stored container")
    NS.SetByPath(path, "hide", id)
    assertEqual(NS.GetSetting(path, id), "hide")
    assertEqual(NS.ValidateSchema(), 0)
end)

test("user categories: Cat.AuraTypeOf answers for a user category KEY, not only for its definition", function()
    -- Checkpoint 2 left the key form answering for the SHIPPED lists only and said so in its own doc
    -- comment; this is the case that closes it. It answers because the definition is materialized
    -- INTO those lists, which is the whole reason materialization was chosen over a side list.
    local NS = fresh()
    local buffs = NS.Categories.CreateUserCategory("Mine", "HELPFUL")
    local debuffs = NS.Categories.CreateUserCategory("Theirs", "HARMFUL")
    assertEqual(NS.Categories.AuraTypeOf(buffs), "HELPFUL")
    assertEqual(NS.Categories.AuraTypeOf(debuffs), "HARMFUL")
    assertEqual(NS.Categories.AuraTypeOf(NS.Categories.Find("HARMFUL", debuffs)), "HARMFUL")
    -- red under: the key form answering for a key nothing knows, which a stored container may well
    -- name (a retired key, and after checkpoint 5 a deleted user category)
    assertTrue(NS.Categories.AuraTypeOf("userffffffffff") == nil)
end)

test("user categories: a profile switch swaps the set and leaves no stale definition, row or template key", function()
    local NS = fresh()
    local key = NS.Categories.CreateUserCategory("Only in Default", "HELPFUL")
    local path = "container.filter.categories." .. key
    assertTrue(NS.FindSchemaRow(path) ~= nil)

    NS.db:SetProfile("Raid")
    -- red under: NS.Schema having only an append path, so the old profile's row survives. The severe
    -- consequence is not the failing validator but the stale DEFINITION below: categorizedUnion
    -- would read the NEW profile's categorySpells under the OLD profile's key and quietly take ids
    -- out of the complement `uncategorized` is defined against.
    assertTrue(NS.Categories.Find("HELPFUL", key) == nil, "the definition went")
    assertTrue(NS.FindSchemaRow(path) == nil, "and the row with it")
    assertTrue(NS.CONTAINER_TEMPLATE.filter.categories[key] == nil, "and the template key")
    assertFalse(NS.Categories.IsSpellCategory(key), "so nothing compiles against it")
    assertEqual(NS.ValidateSchema(), 0)

    NS.db:SetProfile("Default")
    assertTrue(NS.Categories.Find("HELPFUL", key) ~= nil, "and it all comes back on the way home")
    assertTrue(NS.FindSchemaRow(path) ~= nil)
    assertEqual(NS.ValidateSchema(), 0)
end)

test("user categories: a new key collides with nothing shipped and with nothing in any stored profile", function()
    local NS = fresh()
    local mine = NS.Categories.CreateUserCategory("Mine", "HELPFUL")
    -- A key living in a profile this session is not running: exactly the case a per-profile counter
    -- cannot see, and the reason the scan is account-wide (defaults/UserCategories.lua's Cat.NewUserKey).
    NS.db.sv.profiles.Elsewhere = { userCategories = { userzzzzzzzzzz = { key = "userzzzzzzzzzz", name = "Theirs", auraType = "HARMFUL" } } }
    local taken = NS.Categories.UserKeysInUse(NS.db)
    assertTrue(taken[mine], "the active profile's key")
    assertTrue(taken.userzzzzzzzzzz, "and an inactive profile's")
    for _ = 1, 50 do
        local key = NS.Categories.NewUserKey(taken)
        assertTrue(taken[key] == nil, key .. " collides with a stored key")
        assertTrue(NS.Categories.Find("HELPFUL", key) == nil, key .. " collides with a shipped key")
        assertTrue(NS.Categories.Find("HARMFUL", key) == nil, key .. " collides with a shipped key")
    end
end)

test("user categories: a rename keeps the key, so a container's stored Show/Hide survives it", function()
    local NS = fresh()
    local key = NS.Categories.CreateUserCategory("Frist draft", "HELPFUL")
    local path = "container.filter.categories." .. key
    local id = NS.Database.GetContainers()[1].id
    NS.SetByPath(path, "hide", id)
    NS.SetByPath("categorySpells", { [key] = { [424242] = true } })

    assertTrue(NS.Categories.RenameUserCategory(key, "  First draft  "))
    -- red under: a rename that re-keys, which orphans every container's stored state, the schema row
    -- and the spell list in one act. This is the failure mode issue #10 names by name.
    assertEqual(NS.db.profile.userCategories[key].name, "First draft", "trimmed, and stored canonically")
    assertEqual(NS.Categories.Find("HELPFUL", key).label, "First draft", "the label follows")
    assertEqual(NS.FindSchemaRow(path).label, "First draft", "and so does the row's")
    assertEqual(NS.GetSetting(path, id), "hide", "the container's own decision is untouched")
    assertEqual(NS.db.profile.categorySpells[key][424242], true, "and so is the list")
    assertEqual(NS.ValidateSchema(), 0)

    -- The refusals. A shipped category is not the player's to rename, and a name has to be a name.
    assertTrue(NS.Categories.RenameUserCategory("defensives", "Mine") == nil)
    assertTrue(NS.Categories.RenameUserCategory(key, "   ") == nil)
    assertEqual(NS.Categories.Find("HELPFUL", key).label, "First draft", "a refused rename changes nothing")
    -- A duplicate name is allowed and merely reported: the key is identity, and two categories called
    -- the same thing are two categories (checkpoint 6 warns, it does not block).
    local other = NS.Categories.CreateUserCategory("First draft", "HELPFUL")
    assertTrue(other ~= nil and other ~= key)
    assertTrue(NS.Categories.UserCategoryNameTaken(NS.db.profile, "first draft", other))
    assertFalse(NS.Categories.UserCategoryNameTaken(NS.db.profile, "Nobody's", nil))
end)

test("user categories: a stored record alone protects its spell list from the categorySpells write", function()
    -- THE DATA-LOSS GUARD. settings/Schema.lua's normalizer drops every key it does not recognize
    -- and the set is written WHOLE on every edit of ANY category, so a user key whose definition had
    -- failed to materialize would have its entire list deleted by one unrelated write. The record is
    -- the thing that cannot be half-built, so the record is what the normalizer asks about.
    local NS = fresh()
    local key = "userdeadbeef0"
    NS.db.profile.userCategories[key] = { key = key, name = "Unmaterialized", auraType = "HELPFUL" }
    assertTrue(NS.Categories.Find("HELPFUL", key) == nil, "no definition: the sync has not run")
    NS.SetByPath("categorySpells", { [key] = { [424242] = true } })
    -- red under: normalizeCategoryEdits asking only Cat.IsSpellCategory
    assertEqual(NS.db.profile.categorySpells[key][424242], true, "the list survived the write")
    -- And a key with neither a definition nor a record is still dropped, as it always was.
    NS.SetByPath("categorySpells", { [key] = { [424242] = true }, nonsense = { [1] = true } })
    assertTrue(NS.db.profile.categorySpells.nonsense == nil)
    assertEqual(NS.db.profile.categorySpells[key][424242], true)
end)

-- ── user categories: deletion and cleanup (issue #10 checkpoint 5) ─────────────────────────────
--
-- Cleanup is EAGER, across every stored profile, and the argument is in defaults/UserCategories.lua
-- above `forgetUserKey`. These cases are the other half of it: eager is only correct if it reaches
-- the profiles nobody is logged into AND leaves everything that is not this category alone.

--- A stored profile that is not the active one, carrying `key` in a container and in its spell
--- edits -- the debris shape a container copy or a profile copy leaves behind.
local function inactiveProfileWith(NS, name, key, record)
    NS.db.sv.profiles[name] = {
        seeded = true, nextContainerId = 2, containerOrder = { 1 },
        containers = { [1] = { id = 1, name = "Theirs", unit = "player", auraType = "HELPFUL",
            filter = { categories = { [key] = "hide", defensives = "hide" } } } },
        categorySpells = { [key] = { [424242] = true }, defensives = { [871] = false } },
        userCategories = record and { [key] = record } or {},
        userCategoryOrder = record and { key } or {},
    }
    return NS.db.sv.profiles[name]
end

test("user categories: deleting one clears the record, the list and every container's state, in the active profile and in an inactive one", function()
    local NS = fresh()
    local key = NS.Categories.CreateUserCategory("Affixes", "HELPFUL")
    local keep = NS.Categories.CreateUserCategory("Kept", "HELPFUL")
    local path = "container.filter.categories." .. key
    local keepPath = "container.filter.categories." .. keep
    local id = NS.Database.GetContainers()[1].id
    NS.SetByPath(path, "hide", id)
    NS.SetByPath(keepPath, "hide", id)
    NS.SetByPath("categorySpells", { [key] = { [424242] = true }, [keep] = { [424243] = true },
        defensives = { [871] = false } })
    local other = inactiveProfileWith(NS, "Raid", key)

    assertTrue(NS.Categories.DeleteUserCategory(key), "the act answers true")

    -- The record, the order entry and the player's list for it.
    assertTrue(NS.db.profile.userCategories[key] == nil, "the record went")
    assertEqual(table.concat(NS.db.profile.userCategoryOrder, ","), keep, "and its order entry")
    assertTrue(NS.db.profile.categorySpells[key] == nil, "and the spell list it owned")
    -- The three mirrors the sync owns.
    assertTrue(NS.Categories.Find("HELPFUL", key) == nil, "the definition went")
    assertTrue(NS.FindSchemaRow(path) == nil, "and the schema row")
    assertTrue(NS.CONTAINER_TEMPLATE.filter.categories[key] == nil, "and the container template key")
    -- The stored leaf in the ACTIVE profile's container...
    assertTrue(NS.db.profile.containers[id].filter.categories[key] == nil, "the active container's state")
    -- ...and in a profile nobody is logged into. red under: a delete that only walks db.profile, or
    -- a lazy prune that waits for the player to switch to that profile.
    assertTrue(other.containers[1].filter.categories[key] == nil, "an inactive profile's container too")
    assertTrue(other.categorySpells[key] == nil, "and its spell edits")

    -- NOTHING ELSE MOVED. The other user category keeps its record, its row, its list and the
    -- container's own decision about it; so does a shipped one, in both profiles.
    assertTrue(NS.db.profile.userCategories[keep] ~= nil)
    assertEqual(NS.GetSetting(keepPath, id), "hide", "the other category's stored state is untouched")
    assertEqual(NS.db.profile.categorySpells[keep][424243], true)
    assertEqual(NS.GetSetting("container.filter.categories.defensives", id), "show")
    assertEqual(NS.db.profile.categorySpells.defensives[871], false)
    assertEqual(other.containers[1].filter.categories.defensives, "hide", "in the inactive profile too")
    assertEqual(other.categorySpells.defensives[871], false)
    assertEqual(NS.ValidateSchema(), 0, "and the validator is clean the moment the act returns")
end)

test("user categories: deleting one leaves a COPY of it in another profile entirely alone", function()
    -- AceDB's profile copy duplicates userCategories wholesale, so two profiles can legitimately hold
    -- a record under ONE key, each with its own name, list and containers. The eager sweep therefore
    -- skips any profile that still holds a record of its own (defaults/UserCategories.lua's
    -- forgetUserKey). red under: sweeping by key alone, which would silently gut the other profile's
    -- category and leave its record pointing at nothing.
    local NS = fresh()
    local key = NS.Categories.CreateUserCategory("Affixes", "HELPFUL")
    local twin = inactiveProfileWith(NS, "Raid", key,
        { key = key, name = "Affixes", auraType = "HELPFUL" })

    assertTrue(NS.Categories.DeleteUserCategory(key))
    assertTrue(NS.db.profile.userCategories[key] == nil, "gone here")
    assertTrue(twin.userCategories[key] ~= nil, "and untouched there")
    assertEqual(twin.containers[1].filter.categories[key], "hide", "with its container's decision")
    assertEqual(twin.categorySpells[key][424242], true, "and its spell list")

    -- And switching to that profile brings the category back, whole.
    NS.db:SetProfile("Raid")
    local def = NS.Categories.Find("HELPFUL", key)
    assertTrue(def ~= nil and def.label == "Affixes", "the copy is materialized like any record")
    assertEqual(NS.ValidateSchema(), 0)
end)

test("user categories: delete and rename are refused at the ACT for a shipped category, and the aura type has no setter at all", function()
    -- THE LOCK IS THE ACT'S, NOT THE PANEL'S (issue #10 checkpoint 6). Hiding the controls is a
    -- courtesy to the reader; a stale panel, a future slash verb or an import must meet the same
    -- refusal. red under: a delete that tests only `Cat.IsUserKey`, or one that trusts the caller.
    local NS = fresh()
    local id = NS.Database.GetContainers()[1].id
    NS.SetByPath("container.filter.categories.defensives", "hide", id)
    NS.SetByPath("categorySpells", { defensives = { [424242] = true } })

    local ok, why = NS.Categories.DeleteUserCategory("defensives")
    assertTrue(ok == nil, "a shipped category is not the player's to delete")
    assertEqual(why, NS.L["Only a category you made can be deleted."])
    assertTrue(NS.Categories.RenameUserCategory("defensives", "Mine") == nil, "nor to rename")
    assertTrue(NS.Categories.DeleteUserCategory("uncategorized") == nil, "nor the complement row")
    assertTrue(NS.Categories.DeleteUserCategory("weaponEnchants") == nil, "nor the enchant row")
    assertTrue(NS.Categories.DeleteUserCategory("userffffffffff") == nil, "nor a key nothing stores")
    -- Nothing the refusals touched: the definition, the row, the container's decision, the list.
    assertTrue(NS.Categories.Find("HELPFUL", "defensives") ~= nil)
    assertEqual(NS.Categories.Find("HELPFUL", "defensives").label, "Defensive cooldowns")
    assertEqual(NS.GetSetting("container.filter.categories.defensives", id), "hide")
    assertEqual(NS.db.profile.categorySpells.defensives[424242], true,
        "the spell list stays fully the player's -- the lock is on the category OBJECT")

    -- THE AURA TYPE IS IMMUTABLE BECAUSE NOTHING CAN WRITE IT. Create is the only writer in the
    -- addon, and a rename does not take a type, so there is no act to refuse -- which is the
    -- strongest form the lock can take. red under: a later checkpoint adding a "change type" act
    -- without deciding what happens to every container's stored state for the key.
    local key = NS.Categories.CreateUserCategory("Mine", "HELPFUL")
    for name in pairs(NS.Categories) do
        assertTrue(not (name:find("AuraType") and name ~= "AuraTypeOf"),
            "NS.Categories." .. name .. " looks like an aura-type setter")
    end
    assertTrue(NS.Categories.RenameUserCategory(key, "Mine again", nil, "HARMFUL"))
    assertEqual(NS.db.profile.userCategories[key].auraType, "HELPFUL", "a rename cannot retype")
    assertEqual(NS.Categories.AuraTypeOf(key), "HELPFUL")
end)

test("user categories: the reserved namespace is what BOTH the rename and the delete rest on", function()
    -- A record keyed with a SHIPPED key is not a user category with a bad field: it is a claim on
    -- that category's identity, and either act honoring it reaches the shipped category's own data.
    -- red under: dropping `Cat.IsUserKey` from either guard -- the delete sweeps the SHIPPED
    -- category's stored Show/Hide and spell list out of every profile in the account, and the rename
    -- stores a name under a key the sync then refuses to materialize.
    local NS = fresh()
    local id = NS.Database.GetContainers()[1].id
    NS.SetByPath("container.filter.categories.healing", "hide", id)
    NS.SetByPath("categorySpells", { healing = { [424242] = true } })
    NS.db.profile.userCategories.healing = { key = "healing", name = "Forged", auraType = "HELPFUL" }

    local ok, why = NS.Categories.RenameUserCategory("healing", "Mine")
    assertTrue(ok == nil, "the rename refuses it")
    assertEqual(why, NS.L["Only a category you made can be renamed."])
    assertEqual(NS.db.profile.userCategories.healing.name, "Forged", "and changes nothing")
    assertTrue(NS.Categories.DeleteUserCategory("healing") == nil, "the delete refuses it")
    assertTrue(NS.db.profile.userCategories.healing ~= nil, "and discards nothing")

    -- What the guard protects, said out loud: the SHIPPED category's own stored state.
    assertEqual(NS.GetSetting("container.filter.categories.healing", id), "hide")
    assertEqual(NS.db.profile.categorySpells.healing[424242], true)
    assertEqual(NS.Categories.Find("HELPFUL", "healing").label, "Healing")
    assertEqual(NS.ValidateSchema(), 0)
end)

test("user categories: a record the sync cannot read can still be got rid of, and taking it leaves a shipped category alone", function()
    -- THE WAY OUT. `usableName` refuses to guess at a record with no usable aura type, no usable
    -- name or a key outside the namespace -- right, because guessing moves a category between the
    -- two grids or renames it behind the player's back. But a record like that has no definition, so
    -- it is in no dropdown, and `forgetUserKey` skips a profile that still holds a record under the
    -- key, so even its debris could never be swept. red under: `DeleteUserCategory` refusing a
    -- non-table record, and nothing at all reaching a forged shipped-key one.
    local NS = fresh()
    local id = NS.Database.GetContainers()[1].id
    local good = NS.Categories.CreateUserCategory("Kept", "HELPFUL")
    NS.SetByPath("container.filter.categories.healing", "hide", id)
    NS.db.profile.userCategories["userbadbad00"] = { key = "userbadbad00", name = "No type" }
    NS.db.profile.userCategories["userbadbad01"] = "not a table at all"
    NS.db.profile.userCategories.healing = { key = "healing", name = "Forged", auraType = "HELPFUL" }
    NS.db.profile.categorySpells = NS.db.profile.categorySpells or {}
    NS.db.profile.categorySpells["userbadbad00"] = { [424242] = true }

    assertEqual(#NS.Categories.UnusableUserRecords(NS.db.profile), 3, "all three are named")
    assertTrue(NS.Categories.DeleteUserCategory("userbadbad01"), "a corrupt record inside the namespace deletes")
    assertEqual(NS.Categories.ForgetUnusableUserRecords(), 2, "and the rest go together")

    assertNil(NS.db.profile.userCategories["userbadbad00"])
    assertNil(NS.db.profile.userCategories.healing)
    assertNil(NS.db.profile.categorySpells["userbadbad00"], "its debris went with it")
    -- red under: sweeping the LEAVES of a record keyed with a shipped key, which is the shipped
    -- category's own Show/Hide and none of this act's business.
    assertEqual(NS.GetSetting("container.filter.categories.healing", id), "hide")
    assertTrue(NS.Categories.Find("HELPFUL", "healing") ~= nil)
    assertTrue(NS.db.profile.userCategories[good] ~= nil, "a readable category is untouched")
    assertEqual(NS.Categories.Find("HELPFUL", good).label, "Kept")
    assertEqual(NS.ValidateSchema(), 0)
end)

test("user categories: a profile the sweep raises on costs its own leaves and nothing else", function()
    -- THE DELETE IS RECOVERABLE, NOT ATOMIC, and this pins which. The record goes first, so the
    -- definition, the schema row and the container template key MUST come down with it however the
    -- sweep goes -- otherwise a raise leaves a LIVE category no record owns, whose Delete then
    -- refuses. red under: the walk running outside a pcall, where one malformed stored profile
    -- strands the category and takes the rest of the sweep with it.
    local NS = fresh()
    local key = NS.Categories.CreateUserCategory("Affixes", "HELPFUL")
    local path = "container.filter.categories." .. key
    local id = NS.Database.GetContainers()[1].id
    NS.SetByPath(path, "hide", id)
    local other = inactiveProfileWith(NS, "Raid", key)
    local broken = inactiveProfileWith(NS, "Broken", key)
    broken.containers[1] = setmetatable({}, { __index = function() error("stored table is broken") end })

    local ok, why, failed = NS.Categories.DeleteUserCategory(key)
    assertTrue(ok, "the act still answers true")
    assertNil(why)
    -- THE CALLER CAN TELL, which is the whole of this line's point: `true` alone said the delete
    -- went and said nothing about the profile that kept its debris, so the difference reached
    -- NS.Debug and never the player. red under: the third return dropped, or counting profiles that
    -- were merely SKIPPED (one holding a record of its own) as refusals.
    assertEqual(failed, 1, "the profile that raised is counted back to the caller")
    -- The category is gone in every sense the panel and the validator can see.
    assertTrue(NS.db.profile.userCategories[key] == nil)
    assertTrue(NS.Categories.Find("HELPFUL", key) == nil, "the definition went")
    assertTrue(NS.FindSchemaRow(path) == nil, "and the schema row")
    assertTrue(NS.CONTAINER_TEMPLATE.filter.categories[key] == nil, "and the template key")
    assertEqual(NS.ValidateSchema(), 0)
    -- Every OTHER profile was still swept.
    assertTrue(NS.db.profile.containers[id].filter.categories[key] == nil)
    assertTrue(other.containers[1].filter.categories[key] == nil, "the good inactive profile too")
    assertTrue(other.categorySpells[key] == nil)
    -- And the broken one lost only what could be reached without touching its broken container.
    assertTrue(broken.categorySpells[key] == nil, "its spell list still went")
end)

test("user categories: the name cap counts characters, so a non-ASCII name is never cut mid-sequence", function()
    -- red under: a BYTE cap at the store (`#clean`, `clean:sub`) against a CHARACTER cap at both of
    -- the panel's boxes (`SetMaxLetters`). A name of two-byte characters typed up to the box's limit
    -- was stored at half its length with the last character cut in half -- a lone continuation byte
    -- the font draws as a replacement glyph.
    local NS = fresh()
    local max = NS.Categories.USER_NAME_MAX
    local accented = string.rep("\195\169", max + 5)
    local clean = NS.Categories.SanitizeUserName(accented)
    assertEqual(NS.Categories.CharCount(clean), max, "capped at the number the boxes enforce")
    assertEqual(#clean, max * 2, "and every character survived whole")
    assertEqual(NS.Categories.CharCount(string.rep("a", max + 5)), max + 5, "the counter counts characters")
    assertEqual(#NS.Categories.SanitizeUserName(string.rep("a", max + 5)), max, "ASCII is unchanged")
    local key = NS.Categories.CreateUserCategory(accented, "HELPFUL")
    assertEqual(NS.Categories.Find("HELPFUL", key).label, clean, "and the category stores that name")
end)

test("user categories: a deleted category is gone from the grid and from the union, and Uncategorized is still last", function()
    -- Checkpoint 4's invariant, re-asserted across a create AND a delete: `uncategorized` compiles as
    -- the complement of the union of every spells-kind category, so a category that is created must
    -- join that union and one that is deleted must leave it -- otherwise the complement goes on being
    -- drawn against a list nothing owns any more.
    local NS = fresh()
    local MINE = 987654
    local key = NS.Categories.CreateUserCategory("Affixes", "HELPFUL")
    NS.SetByPath("categorySpells", { [key] = { [MINE] = true } })
    -- `unit = "player"` is where FC.IdsAlwaysHonored is true, and a HIDDEN SHIPPED category is what
    -- keeps the Uncategorized rescue group in the plan after the user category is gone -- without it
    -- the group would vanish with the delete and the negative below would pass for the wrong reason.
    local con = NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE)
    con.unit, con.auraType = "player", "HELPFUL"
    con.filter.categories.defensives = "hide"

    local function excluded()
        local plan = NS.FilterCompiler.Compile(con, NS.FilterCompiler.ProfileContext())
        for _, g in ipairs(plan.groups) do
            if g.label == "Uncategorized" then
                return g.candidateFilters and g.candidateFilters.excludeSpellIDs or {}
            end
        end
        return nil
    end
    assertEqual(NS.Categories.HELPFUL[#NS.Categories.HELPFUL].key, "uncategorized", "U-1 after create")
    local before = excluded()
    assertTrue(before ~= nil and before[MINE], "the new category's id joined the union (the premise)")

    assertTrue(NS.Categories.DeleteUserCategory(key))
    assertEqual(NS.Categories.HELPFUL[#NS.Categories.HELPFUL].key, "uncategorized", "U-1 after delete")
    local after = excluded()
    -- red under: a delete that tears the record down but leaves the definition materialized, which
    -- would go on taking the id out of the complement `uncategorized` is defined against.
    assertTrue(after ~= nil, "the rescue group is still there (the hidden shipped category keeps it)")
    assertTrue(after[MINE] == nil, "and the deleted category's id left the union with it")
    assertEqual(NS.ValidateSchema(), 0)
end)
