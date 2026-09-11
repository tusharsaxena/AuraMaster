local _, NS = ...

-- core/Database.lua — AceDB, the schema migration runner, and the pure data helpers over the
-- container registry. Called from core/AuraMaster.lua's OnInitialize and headlessly by the harness.
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
--- @return number  how many leaves were filled
function Database.Backfill(dst, template)
    local filled = 0
    for k, tv in pairs(template) do
        local dv = dst[k]
        if dv == nil then
            dst[k] = copy(tv)
            filled = filled + 1
        elseif type(tv) == "table" and type(dv) == "table" then
            filled = filled + Database.Backfill(dv, tv)
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
--- numbers, so it is dropped (one gated [Migrate] line each).
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
        p.containers[tonumber(k)] = p.containers[k]
        p.containers[k] = nil
    end
    for _, k in ipairs(drops) do
        p.containers[k] = nil
        if NS.Debug then NS.Debug("Migrate", "dropped container key %s", k) end
    end
end

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

--- Backfill every stored container from the template and stamp its id from its key. An entry that
--- is not a table is dropped: clearing a key while `pairs` walks the table is allowed in Lua, only
--- adding one is not.
--- @return number  the largest id kept, or 0
local function backfillContainers(p)
    local maxId = 0
    for id, c in pairs(p.containers) do
        if type(c) == "table" then
            Database.Backfill(c, NS.CONTAINER_TEMPLATE)
            c.id = id
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
            NS.db.RegisterCallback(NS, "OnProfileCopied", function() NS.OnProfileChanged() end)
            NS.db.RegisterCallback(NS, "OnProfileReset", function() NS.OnProfileChanged() end)
        end
    end
    -- Soft fallback when AceDB is absent: a db-shaped table over the raw SavedVariables global, so
    -- the addon still loads and still answers its CLI (savedvariables-§1).
    if not NS.db then
        AuraMasterDB = AuraMasterDB or {}
        AuraMasterDB.profile = AuraMasterDB.profile or {}
        AuraMasterDB.global = AuraMasterDB.global or {}
        Database.Backfill(AuraMasterDB.profile, NS.defaults.profile)
        Database.Backfill(AuraMasterDB.global, NS.defaults.global)
        NS.db = { profile = AuraMasterDB.profile, global = AuraMasterDB.global }
    end
    NS.RunMigrations()
end

-- The account-wide schema ladder, in order, one row per version. v1 is the shape this file was born
-- with, so the ladder is empty; the runner exists from day one because a migration is a from-day-one
-- concern (toc-file-§2), and the next stored-shape change adds a row here in the same change.
local SCHEMA_STEPS = {}

--- Current schema version: the last step's `to`, or 1.
function Database.CurrentSchemaVersion()
    local last = SCHEMA_STEPS[#SCHEMA_STEPS]
    return last and last.to or 1
end

function NS.RunMigrations()
    local g = NS.db and NS.db.global
    if not g then return end
    g.schemaVersion = g.schemaVersion or 1
    for _, step in ipairs(SCHEMA_STEPS) do
        if g.schemaVersion < step.to then
            step.apply(NS.db)
            if NS.Debug then NS.Debug("Migrate", "v%s -> v%s", g.schemaVersion, step.to) end
            g.schemaVersion = step.to
        end
    end
    g.timedSpells = g.timedSpells or {}
    local seeded = Database.PrepareProfile(NS.db.profile)
    if seeded > 0 and NS.Debug then NS.Debug("Migrate", "seeded %s starter container(s)", seeded) end
end
