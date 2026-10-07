local _, NS = ...

-- core/Database.lua — AceDB, the schema migration runner, and the pure data helpers over the
-- container registry. Called from core/AuraMaster.lua's OnInitialize and headlessly by the harness.
-- The step bodies the ladder runs (Database.MigrateV2 .. MigrateV12) are core/Database_Migrations.lua.
--
-- NOTHING HERE TOUCHES A FRAME. The registry's CRUD with its messages and live instances is
-- modules/ContainerManager.lua; this file only knows what a container looks like on disk.

NS.Database = NS.Database or {}
local Database = NS.Database

--- Recursive copy. A table default must never be handed out by reference, or two containers reset to
--- one default would share a color table and editing one would repaint the other.
function Database.DeepCopy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = Database.DeepCopy(x) end
    return out
end
local copy = Database.DeepCopy

--- Fill every key `template` has and `dst` lacks, recursively. Tested with `== nil`, never `or`, so a
--- stored `false`, `0` or empty string is the player's choice and survives (savedvariables-§5).
--- A template table whose shape is a MAP the player fills (categories, spell lists) is empty in the
--- template, so there is nothing to fill into it and the player's entries are never touched.
---
--- `repair`, for the LOAD path only: a stored value that is not a table where the template holds a
--- section (a hand-edited `position = "junk"`) is replaced by the template's section. Nothing a player
--- sets through the addon can produce one, and left in place it survived the load and raised later
--- (ContainerManager.Duplicate indexed it). A whole-section WRITE backfills without it, so a malformed
--- section handed to NS.SetByPath is still validated and refused rather than silently repaired.
--- @return number  how many leaves were filled or repaired
function Database.Backfill(dst, template, repair)
    local filled = 0
    for k, tv in pairs(template) do
        local dv = dst[k]
        if dv == nil then
            dst[k] = copy(tv)
            filled = filled + 1
        elseif type(tv) == "table" then
            if type(dv) == "table" then
                filled = filled + Database.Backfill(dv, tv, repair)
            elseif repair then
                dst[k] = copy(tv)
                filled = filled + 1
            end
        end
    end
    return filled
end

--- Deep-merge `overrides` onto `dst` (overrides win). For the starter containers, whose declarations
--- name only what differs from the template.
local function merge(dst, overrides)
    for k, v in pairs(overrides or {}) do
        if type(v) == "table" and type(dst[k]) == "table" then
            merge(dst[k], v)
        else
            dst[k] = copy(v)
        end
    end
    return dst
end
-- A test seam: tests/test_style.lua and tests/test_filtercompiler.lua call it; production uses the
-- local `merge`.
Database.Merge = merge

-- ---------------------------------------------------------------------------
-- The registry, read side
-- ---------------------------------------------------------------------------

local function profile()
    return NS.db and NS.db.profile
end

--- Every container in display order, as an array of their stored tables (each carries its `id`).
--- @return table
function Database.GetContainers()
    local p = profile()
    local out = {}
    if not p then return out end
    for _, id in ipairs(p.containerOrder or {}) do
        local c = p.containers and p.containers[id]
        if c then
            out[#out + 1] = c
        end
    end
    return out
end

--- Every container sorted for a picker (smoke batch 2, B2-2): by name, case-insensitively, the id
--- breaking a tie. A new array: the display order (`containerOrder`) is never touched.
--- @return table
function Database.GetContainersByName()
    local out = Database.GetContainers()
    table.sort(out, function(a, b)
        local an, bn = tostring(a.name):lower(), tostring(b.name):lower()
        if an ~= bn then return an < bn end
        return a.id < b.id
    end)
    return out
end

--- One container's stored table by id, or nil.
function Database.FindContainer(id)
    local p = profile()
    if not (p and p.containers and id ~= nil) then return nil end
    return p.containers[id]
end

--- A new container table built from the template plus `overrides`, with a fresh id taken from the
--- profile's counter. It is NOT inserted: ContainerManager.Create does that and announces it.
--- @return table container, number id
function Database.NewContainerData(overrides)
    local p = profile()
    local id = (p and p.nextContainerId) or 1
    if p then p.nextContainerId = id + 1 end
    local c = merge(copy(NS.CONTAINER_TEMPLATE), overrides)
    c.id = id
    return c, id
end

--- Keys come back from SavedVariables as numbers, but a hand-edited file or an old export can carry
--- string ids; normalize so FindContainer(3) and FindContainer("3") cannot disagree. A key that is
--- neither a number nor a numeric string has no id to become, and every later pass compares ids as
--- numbers, so it is dropped (one gated [Migrate] line each). A numeric string whose id is already
--- stored as a number is dropped the same way: the numeric key is the form this addon writes, so the
--- string twin is the stale copy and never overwrites it.
--- Collected first, then moved: assigning a new key while `pairs` walks the same table is
--- undefined in Lua and raises "invalid key to 'next'".
local function normalizeKeys(p)
    local renames, drops = {}, {}
    for k in pairs(p.containers) do
        if type(k) ~= "number" then
            if tonumber(k) then
                renames[#renames + 1] = k
            else
                drops[#drops + 1] = k
            end
        end
    end
    for _, k in ipairs(renames) do
        local id = tonumber(k)
        if p.containers[id] == nil then
            p.containers[id] = p.containers[k]
            p.containers[k] = nil
        else
            drops[#drops + 1] = k
        end
    end
    for _, k in ipairs(drops) do
        p.containers[k] = nil
        if NS.Debug then NS.Debug("Migrate", "dropped container key %s", k) end
    end
end

-- Published for core/Database_Migrations.lua: MigrateV2 normalizes the keys before it reads them.
Database.NormalizeKeys = normalizeKeys

--- Seed the starter containers into a brand-new profile, once. An unseeded profile with no
--- containers gets every starter, numbered from its own counter; an unseeded profile is then marked
--- seeded either way, so deleting every container never brings the starters back.
--- @return number  containers seeded
local function seedStarters(p)
    if p.seeded then return 0 end
    local seeded = 0
    if next(p.containers) == nil then
        for _, spec in ipairs(NS.STARTER_CONTAINERS or {}) do
            local id = p.nextContainerId or 1
            p.nextContainerId = id + 1
            local c = merge(copy(NS.CONTAINER_TEMPLATE), spec)
            c.id = id
            p.containers[id] = c
            p.containerOrder[#p.containerOrder + 1] = id
            seeded = seeded + 1
        end
    end
    p.seeded = true
    return seeded
end

-- The nine WoW points, as a set.
local KNOWN_POINT = {}
for _, point in ipairs(NS.Constants.POINTS) do KNOWN_POINT[point] = true end
local POINT_KEYS = { "childPoint", "relPoint" }

--- Drop a stored attach point on container `c` that is not one of the nine WoW points (batch 11
--- G2): hand-edited or imported data reads as Automatic rather than reaching SetPoint.
local function normalizeAttach(c)
    local at = c.attach
    if type(at) ~= "table" then return end
    for _, key in ipairs(POINT_KEYS) do
        local v = at[key]
        if v ~= nil and not KNOWN_POINT[v] then
            if NS.Debug then NS.Debug("Migrate", "container %s: unknown attach %s '%s' read as Automatic", c.id, key, tostring(v)) end
            at[key] = nil
        end
    end
end

--- Backfill every stored container from the template and stamp its id from its key. An entry that
--- is not a table is dropped: clearing a key while `pairs` walks the table is allowed in Lua, only
--- adding one is not.
--- @return number  the largest id kept, or 0
local function backfillContainers(p)
    local maxId = 0
    for id, c in pairs(p.containers) do
        if type(c) == "table" then
            Database.Backfill(c, NS.CONTAINER_TEMPLATE, true)
            c.id = id
            normalizeAttach(c)
            if id > maxId then maxId = id end
        else
            p.containers[id] = nil
        end
    end
    return maxId
end

--- Rebuild `containerOrder` to hold exactly the ids that exist: dangling and duplicate ids dropped,
--- orphans appended in id order.
local function rebuildOrder(p)
    local seen, order = {}, {}
    for _, id in ipairs(p.containerOrder) do
        id = tonumber(id)
        if id and p.containers[id] and not seen[id] then
            seen[id] = true
            order[#order + 1] = id
        end
    end
    local orphans = {}
    for id in pairs(p.containers) do
        if not seen[id] then
            orphans[#orphans + 1] = id
        end
    end
    table.sort(orphans)
    for _, id in ipairs(orphans) do
        order[#order + 1] = id
    end
    p.containerOrder = order
end

--- Put a profile's registry into a shape every reader can trust: every stored container backfilled
--- from the template, `containerOrder` holding exactly the ids that exist (orphans appended, dangling
--- ids dropped), and — on a brand-new profile — the starter containers seeded once.
--- Idempotent: a second call changes nothing.
--- @return number  containers seeded by this call
function Database.PrepareProfile(p)
    if type(p) ~= "table" then return 0 end
    p.containers = p.containers or {}
    p.containerOrder = p.containerOrder or {}

    local seeded = seedStarters(p)
    normalizeKeys(p)
    local maxId = backfillContainers(p)
    if (p.nextContainerId or 1) <= maxId then p.nextContainerId = maxId + 1 end
    rebuildOrder(p)
    return seeded
end

-- ---------------------------------------------------------------------------
-- AceDB and migrations
-- ---------------------------------------------------------------------------

function NS.InitDB()
    local AceDB = LibStub and LibStub("AceDB-3.0", true)
    if AceDB then
        NS.db = AceDB:New("AuraMasterDB", NS.defaults, true)
        -- A profile switch, copy or reset re-prepares the registry and rebuilds every container.
        if NS.db.RegisterCallback then
            NS.db.RegisterCallback(NS, "OnProfileChanged", function() NS.OnProfileChanged() end)
            -- Each is traced by its own handler, in the event's words (debug-logging-§10). AceDB
            -- hands OnProfileCopied the SOURCE profile's key.
            NS.db.RegisterCallback(NS, "OnProfileCopied", function(_, _, source) NS.OnProfileCopied(source) end)
            NS.db.RegisterCallback(NS, "OnProfileReset", function() NS.OnProfileReset() end)
        end
    end
    -- Soft fallback when AceDB is absent: a db-shaped table over the raw SavedVariables global, so
    -- the addon still loads and still answers its CLI (savedvariables-§1).
    if not NS.db then
        AuraMasterDB = AuraMasterDB or {}
        AuraMasterDB.profile = AuraMasterDB.profile or {}
        AuraMasterDB.global = AuraMasterDB.global or {}
        Database.Backfill(AuraMasterDB.profile, NS.defaults.profile, true)
        Database.Backfill(AuraMasterDB.global, NS.defaults.global, true)
        NS.db = { profile = AuraMasterDB.profile, global = AuraMasterDB.global }
    end
    NS.RunMigrations()
end

--- Run `fn(profile, name)` over every stored profile: AceDB's raw store (`db.sv.profiles`, the
--- inactive ones included), or the no-AceDB fallback's one profile. Sorted, so the log is stable.
---
--- PUBLISHED because the schema ladder is no longer its only caller (issue #10 checkpoint 5).
--- `Cat.DeleteUserCategory` has to reach the same set of profiles a migration does -- a deleted
--- category's `filter.categories.<key>` sits in the containers of profiles nobody is logged into --
--- and a second walk written to look like this one would drift on exactly the case that matters:
--- the fallback branch below, which is the whole of the headless harness and of a client whose
--- AceDB failed to load. The local name is kept so the ladder's steps read as they did.
--- @param db table  NS.db, or anything carrying `sv.profiles` or `profile`
--- @param fn function  fn(profile, name)
function Database.EachProfile(db, fn)
    local store = type(db.sv) == "table" and db.sv.profiles
    if type(store) ~= "table" then
        if type(db.profile) == "table" then fn(db.profile, "Default") end
        return
    end
    local names = {}
    for name in pairs(store) do
        names[#names + 1] = name
    end
    table.sort(names, function(a, b) return tostring(a) < tostring(b) end)
    for _, name in ipairs(names) do
        if type(store[name]) == "table" then fn(store[name], name) end
    end
end

local eachProfile = Database.EachProfile

-- The account-wide schema ladder, in order, one row per version. v1 is the shape the addon shipped
-- with; each stored-shape change adds a row here in the same change (toc-file-§2). Containers live in
-- every profile, so a step walks them all, not only the active one: that is savedvariables-§1's
-- per-profile rule (v2.65.0), a profile-scoped step runs over every stored profile in the raw
-- `db.sv.profiles` and is never gated by the account-wide stamp alone. Every step is also
-- idempotent against a fresh default profile, because a fresh install (stamp 0) runs all of them,
-- and so does an account whose stamp AceDB stripped at logout for equalling the default.
--
-- THE LADDER LOGS THROUGH NS.DebugLog.DebugAtEnable, NOT THE GATED NS.Debug. The runner runs only
-- from NS:InitDB at OnInitialize, while NS.State.debug is still false, so a gated line here never
-- lands; the at-enable queue holds it and writes it after the [Init] summary when logging is turned
-- on (debug-logging-§8 Lifecycle coverage: a schema migration is a MUST line). Only the per-step,
-- per-profile summaries, the stamp line and the starter seed go there: the per-container lines in
-- the MigrateVn bodies stay on NS.Debug, because a large profile would overflow the queue's bound
-- (lib.AT_ENABLE_MAX) and each step's summary already counts them.
local SCHEMA_STEPS = {
    { to = 2, apply = function(db)
        eachProfile(db, function(p, name)
            local n = Database.MigrateV2(p)
            if NS.DebugLog then
                NS.DebugLog.DebugAtEnable("Migrate", "v2 profile '%s': spell lists, dispel colors, healing and strata over %s container(s)", name, n)
            end
        end)
    end },
    { to = 3, apply = function(db)
        eachProfile(db, function(p, name)
            local n = Database.MigrateV3(p)
            if NS.DebugLog then
                NS.DebugLog.DebugAtEnable("Migrate", "v3 profile '%s': category whitelist lift and weaponEnchants over %s container(s)", name, n)
            end
        end)
    end },
    { to = 4, apply = function(db)
        -- R-8..R-11 retired; NS.Print (not just NS.Debug, which a player may never have enabled) is
        -- the one place a lost container is actually told about — one consolidated line for the whole
        -- migration pass, not one per profile, so a player with several affected containers sees a
        -- single, plain notice rather than a burst of chat spam. Structurally one-shot already: the
        -- schema-version gate below never re-runs this step once `schemaVersion` reaches 4.
        local allLost = {}
        eachProfile(db, function(p, name)
            local converted, lost, lostList = Database.MigrateV4(p)
            if NS.DebugLog then
                NS.DebugLog.DebugAtEnable("Migrate", "v4 profile '%s': 'Only these categories' retired -- %s container(s) moved to Uncategorized = Hide, %s lost the capability", name, converted, lost)
            end
            for _, entry in ipairs(lostList) do
                allLost[#allLost + 1] = ("%s (%s, profile '%s')"):format(
                    tostring(entry.name or entry.id), tostring(entry.auraType), tostring(name))
            end
        end)
        local lostCount = #allLost
        if lostCount > 0 and NS.Print then
            NS.Print(NS.L["The retired 'Only these categories' setting could not be carried over for: %s. These containers now draw their ordinary catch-all again, the same as any container that never used it."]:format(table.concat(allLost, ", ")))
        end
    end },
    { to = 5, apply = function(db)
        eachProfile(db, function(p, name)
            local n = Database.MigrateV5(p)
            if NS.DebugLog then
                NS.DebugLog.DebugAtEnable("Migrate", "v5 profile '%s': the Weapon enchants aura type retired -- %s container(s) now show only the Weapon enchants category", name, n)
            end
        end)
    end },
    { to = 6, apply = function(db)
        eachProfile(db, function(p, name)
            local n = Database.MigrateV6(p)
            if NS.DebugLog then
                NS.DebugLog.DebugAtEnable("Migrate", "v6 profile '%s': the user-category store stamped -- %s category(ies) already stored", name, n)
            end
        end)
    end },
    { to = 7, apply = function(db)
        eachProfile(db, function(p, name)
            local n = Database.MigrateV7(p)
            if NS.DebugLog then
                NS.DebugLog.DebugAtEnable("Migrate", "v7 profile '%s': Consumables retired; Group buffs, Stances and Racials seeded over %s container(s)", name, n)
            end
        end)
    end },
    { to = 8, apply = function(db)
        eachProfile(db, function(p, name)
            local n, fit = Database.MigrateV8(p)
            if NS.DebugLog then
                NS.DebugLog.DebugAtEnable("Migrate", "v8 profile '%s': the old 0/-4 attach offset reset on %s container(s) attached to another; Size to fit stamped off on %s Text container(s)", name, n, fit)
            end
        end)
    end },
    { to = 9, apply = function(db)
        eachProfile(db, function(p, name)
            local removed, stamped, reset = Database.MigrateV9(p)
            if NS.DebugLog then
                NS.DebugLog.DebugAtEnable("Migrate", "v9 profile '%s': Size to fit removed from %s bars or icons container(s); attach side stamped after-start on %s; the old 0/-4 offset reset on %s screen container(s)", name, removed, stamped, reset)
            end
        end)
    end },
    { to = 10, apply = function(db)
        eachProfile(db, function(p, name)
            local stamped, reset = Database.MigrateV10(p)
            if NS.DebugLog then
                NS.DebugLog.DebugAtEnable("Migrate", "v10 profile '%s': attach side stamped after-start on %s container(s); the old 0/-4 offset reset on %s screen container(s)", name, stamped, reset)
            end
        end)
    end },
    { to = 11, apply = function(db)
        eachProfile(db, function(p, name)
            local dropped, converted = Database.MigrateV11(p)
            if NS.DebugLog then
                NS.DebugLog.DebugAtEnable("Migrate", "v11 profile '%s': attach side dropped to Automatic on %s container(s); converted to points on %s", name, dropped, converted)
            end
        end)
    end },
    { to = 12, apply = function(db)
        eachProfile(db, function(p, name)
            local n = Database.MigrateV12(p)
            if NS.DebugLog then
                NS.DebugLog.DebugAtEnable("Migrate", "v12 profile '%s': Soft CC split into CC Root and CC Snare on %s container(s)", name, n)
            end
        end)
    end },
}

--- Current schema version: the last step's `to`, or 0 (the defaults' "never migrated" stamp).
function Database.CurrentSchemaVersion()
    local last = SCHEMA_STEPS[#SCHEMA_STEPS]
    return last and last.to or 0
end

--- The runner's target (savedvariables-§1): the stamp a fully migrated account carries.
NS.SCHEMA_VERSION = Database.CurrentSchemaVersion()

--- Climb the ladder from `g.schemaVersion`. The runner owns the stamp and advances it only past a
--- step that returned without raising: a step that raises stops the climb with the stamp where it
--- was, prints one line, and the next load retries from that step. Answers true when every step
--- the stamp had not passed ran clean.
local function climbLadder(g)
    -- 0, not the current version: AceDB backfills the declared default onto a legacy account with
    -- no stamp and strips a stored stamp equal to it at logout, and 0 is safe against both.
    g.schemaVersion = g.schemaVersion or 0
    for _, step in ipairs(SCHEMA_STEPS) do
        if g.schemaVersion < step.to then
            local ok, err = pcall(step.apply, NS.db)
            if not ok then
                NS.Printf(NS.L["%s: migration to schema v%s failed; your settings were left as they were. %s"],
                    NS.name, step.to, err)
                return false
            end
            if NS.DebugLog then NS.DebugLog.DebugAtEnable("Migrate", "v%s -> v%s", g.schemaVersion, step.to) end
            g.schemaVersion = step.to
        end
    end
    return true
end

function NS.RunMigrations()
    local g = NS.db and NS.db.global
    if not g then return end
    -- A failed step leaves the stamp alone, and the rest of the load still runs below, so the addon
    -- loads on whatever the completed steps left.
    climbLadder(g)
    g.timedSpells = g.timedSpells or {}
    -- THE USER-CATEGORY SYNC RUNS AFTER THE WHOLE LADDER AND BEFORE PrepareProfile, and neither half
    -- of that is cosmetic (issue #10 checkpoint 3).
    --
    -- After the ladder, because materializing user definitions makes `Cat.IsSpellCategory`
    -- PROFILE-DEPENDENT, and `MigrateV2`'s `rekeyEdits` (core/Database_Migrations.lua) asks it. A v2
    -- profile cannot contain user keys, so the answer is the same either way today -- but moving this
    -- call earlier would quietly make a v2 migration's result depend on the active profile's user
    -- categories, which is not a dependency a migration may have.
    --
    -- Before PrepareProfile, because its `backfillContainers` is what stamps the template's newly
    -- added category keys into every stored container -- exactly the mechanism `Cat.DefaultStates`'
    -- own comment (defaults/Categories.lua) promises for a key added in a later version.
    NS.Categories.SyncUserCategories(NS.db.profile)
    local seeded = Database.PrepareProfile(NS.db.profile)
    if seeded > 0 and NS.DebugLog then NS.DebugLog.DebugAtEnable("Migrate", "seeded %s starter container(s)", seeded) end
end
