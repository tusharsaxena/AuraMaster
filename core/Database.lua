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
            Database.Backfill(c, NS.CONTAINER_TEMPLATE, true)
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

-- ---------------------------------------------------------------------------
-- Schema v2: profile-wide spell lists and dispel colors, the Healing merge, strata High
-- ---------------------------------------------------------------------------
--
-- Pure functions over ONE raw profile table. A profile that has never been activated is stored as
-- the SavedVariables file had it (AceDB merges its defaults only on activation), so nothing here
-- assumes a key exists. Each rule's old keys are deleted only after their values are written to the
-- new home.

-- The two healing lists v1 shipped, and the one list v2 ships in their place.
local HEALING_V1 = { coreHealing = true, lesserHealing = true }
local HEALING_V2 = "healing"

--- A profile's containers in display order: `containerOrder` first (a numeric or a numeric-string
--- id), then any container the order misses, by id. Table entries only, each once. The keys are
--- numeric by now (Database.MigrateV2 applies normalizeKeys first).
local function orderedContainers(p)
    local containers = type(p.containers) == "table" and p.containers or {}
    local out, seen = {}, {}
    local function take(key)
        local c = key ~= nil and containers[key]
        if type(c) == "table" and not seen[c] then
            seen[c] = true
            out[#out + 1] = c
        end
    end
    for _, id in ipairs(type(p.containerOrder) == "table" and p.containerOrder or {}) do
        take(tonumber(id))
    end
    local rest = {}
    for key in pairs(containers) do
        rest[#rest + 1] = key
    end
    table.sort(rest)
    for _, key in ipairs(rest) do take(key) end
    return out
end

--- Fold one stored edit set into `into`: an id either set adds beats the other's removal.
local function foldEdits(into, set)
    for id, on in pairs(set) do
        id = tonumber(id)
        if id and id > 0 and id == math.floor(id) then
            into[id] = (on and true) or into[id] == true
        end
    end
end

--- One editor's spell edits re-keyed to v2: the two healing lists fold into `healing`, and a key
--- that is no spell category of this build, or an empty set, is dropped.
local function rekeyEdits(src)
    local out = {}
    if type(src) ~= "table" then return out end
    for key, set in pairs(src) do
        local k = HEALING_V1[key] and HEALING_V2 or key
        if type(set) == "table" and type(k) == "string" and NS.Categories.IsSpellCategory(k) then
            out[k] = out[k] or {}
            foldEdits(out[k], set)
            if next(out[k]) == nil then out[k] = nil end
        end
    end
    return out
end

--- Count, per category, its editors, every id any of them added and how many removed each id.
local function tallyEditors(editors)
    local t = { editors = {}, adds = {}, removes = {} }
    for _, ed in ipairs(editors) do
        for key, set in pairs(ed) do
            t.editors[key] = (t.editors[key] or 0) + 1
            t.adds[key] = t.adds[key] or {}
            t.removes[key] = t.removes[key] or {}
            for id, on in pairs(set) do
                if on then
                    t.adds[key][id] = true
                else
                    t.removes[key][id] = (t.removes[key][id] or 0) + 1
                end
            end
        end
    end
    return t
end

--- The profile-wide edits (spec §7): an id any editor added is added; a starter is removed only
--- when every editor of that category removed it. An editor with no edit for a category has no say.
local function mergeEditors(editors)
    local t = tallyEditors(editors)
    local out = {}
    for key, n in pairs(t.editors) do
        local e = {}
        for id, count in pairs(t.removes[key]) do
            if count == n then e[id] = false end
        end
        for id in pairs(t.adds[key]) do e[id] = true end
        if next(e) ~= nil then out[key] = e end
    end
    return out
end

--- Lift every container's spell edits to `profile.categorySpells`, then delete the containers'
--- copies. The profile's own set, if any, is one more editor, so a second run changes nothing.
local function liftSpellEdits(p, list)
    local editors = { rekeyEdits(p.categorySpells) }
    for _, c in ipairs(list) do
        local f = type(c.filter) == "table" and c.filter or {}
        editors[#editors + 1] = rekeyEdits(f.categorySpells)
    end
    p.categorySpells = mergeEditors(editors)
    for _, c in ipairs(list) do
        if type(c.filter) == "table" then c.filter.categorySpells = nil end
    end
end

--- The strongest of two category states: show beats hide beats neutral.
local function strongerState(a, b)
    if a == "show" or b == "show" then return "show" end
    if a == "hide" or b == "hide" then return "hide" end
    return ""
end

--- One container's coreHealing and lesserHealing states become its `healing` state.
local function mergeHealingStates(c)
    local cats = type(c.filter) == "table" and c.filter.categories
    if type(cats) ~= "table" or (cats.coreHealing == nil and cats.lesserHealing == nil) then return end
    cats[HEALING_V2] = strongerState(strongerState(cats.coreHealing, cats.lesserHealing), cats[HEALING_V2])
    for old in pairs(HEALING_V1) do cats[old] = nil end
end

--- The palette to lift: the first container in display order colored by dispel type, else the
--- first container that carries a palette at all, else nil.
local function sourceDispelColors(list)
    local first
    for _, c in ipairs(list) do
        local b = c.bars
        if type(b) == "table" and type(b.dispelColors) == "table" then
            if b.colorMode == "dispel" then return b.dispelColors end
            first = first or b.dispelColors
        end
    end
    return first
end

--- Lift a container's palette to `profile.dispelColors`, completed from the defaults, then delete
--- every container's copy. With none to lift, the profile keeps what it has (a second run).
local function liftDispelColors(p, list)
    local src = sourceDispelColors(list)
    if src then
        p.dispelColors = copy(src)
    elseif type(p.dispelColors) ~= "table" then
        p.dispelColors = {}
    end
    Database.Backfill(p.dispelColors, NS.defaults.profile.dispelColors, true)
    for _, c in ipairs(list) do
        if type(c.bars) == "table" then c.bars.dispelColors = nil end
    end
end

--- Stored MEDIUM, the v1 default, rises to HIGH (the v2 default). Any other strata was a choice.
local function raiseStrata(list)
    for _, c in ipairs(list) do
        if type(c.layout) == "table" and c.layout.strata == "MEDIUM" then c.layout.strata = "HIGH" end
    end
end

--- Schema v2 over one profile table (docs/schema.md, Migration path). A test seam as well as the
--- step's body: tests/test_database.lua runs it over raw v1 tables.
--- @return number  the containers it walked
function Database.MigrateV2(p)
    if type(p) ~= "table" then return 0 end
    -- The key rules PrepareProfile applies, applied first: a string twin of a numeric id and a
    -- non-numeric key are dropped there, so neither may supply a palette or an editor here.
    if type(p.containers) == "table" then normalizeKeys(p) end
    local list = orderedContainers(p)
    liftSpellEdits(p, list)
    liftDispelColors(p, list)
    local walked = 0
    for _, c in ipairs(list) do
        mergeHealingStates(c)
        walked = walked + 1
    end
    raiseStrata(list)
    return walked
end

-- ---------------------------------------------------------------------------
-- Schema v3: Show/Hide categories, weaponEnchants
-- ---------------------------------------------------------------------------
--
-- B1 collapsed the three-state category model ("" no effect / "show" whitelist / "hide" exclude) to
-- two: Show / Hide, where Show contributes nothing (defaults/Categories.lua). The old "show" state
-- meant "draw ONLY the categories set to show" — a state that no longer exists. Mapping "" -> "show"
-- verbatim would silently WIDEN what an already-stored container draws, so the old intent is written
-- out longhand instead (liftCategoryWhitelist), before the unrelated enchant-flag lift runs.
--
-- Only recognized aura types are touched. `Cat.For(nil)` and `Cat.For("garbage")` both fall back to
-- the (empty) ENCHANT list, so liftCategoryWhitelist is already a no-op for them — but the string
-- compare `auraType == "ENCHANT"` that used to gate liftEnchantFlag does NOT catch nil or garbage, so
-- a container with a missing or corrupt auraType could still get a weaponEnchants row written with no
-- corresponding category list. `Database.MigrateV3` itself gates both lifts on a known aura type, so
-- neither runs for such a container: it is left untouched rather than half-converted.
local KNOWN_AURA_TYPES = { HELPFUL = true, HARMFUL = true, ENCHANT = true }

--- Categories are not a partition of the aura space, so "hide everything the container did not
--- whitelist" cannot fully reproduce the old exclusive whitelist: an aura that also matched a NOW
--- hidden category would stop being drawn, when the old whitelist group drew it regardless. This
--- copies the ids of every "show" spell category onto `filter.whitelist` (Overrides, rank 2 in
--- modules/FilterCompiler.lua — it beats a category Hide) so those auras keep being drawn exactly as
--- before. Merges into any existing whitelist; an id already on `filter.blacklist` (rank 1, a
--- player's explicit never) is left there alone — a migration must not overturn it.
--- `shown` is the container's "show" category defs for its aura type, gathered by the caller before
--- the sweep below converts every non-"show" row to "hide".
local function liftWhitelistSpells(p, c, shown)
    local ids = {}
    for _, cat in ipairs(shown) do
        if cat.kind == "spells" then
            for id in pairs(NS.FilterCompiler.CategorySpells(cat, p.categorySpells)) do
                ids[id] = true
            end
        end
    end
    if not next(ids) then return end
    local f = c.filter
    local blacklist = type(f.blacklist) == "table" and f.blacklist or {}
    if type(f.whitelist) ~= "table" then f.whitelist = {} end
    for id in pairs(ids) do
        if not blacklist[id] then f.whitelist[id] = true end
    end
end

--- The whitelist lift: if a container had ANY category of its aura type at "show", it was an
--- exclusive whitelist under the old three-state model — so every category of that type NOT "show"
--- (an unset "" or an explicit "hide", the old model excluded both from the whitelist's one group)
--- becomes "hide", the longhand of that exclusion, and the "show" spell categories' ids are copied to
--- `filter.whitelist` (liftWhitelistSpells) to cover the half of that exclusion a pure category sweep
--- cannot reproduce. With no "show" present the container already drew everything except its explicit
--- "hide" rows (the old model's default group), so only the unset "" rows need a decision at all, and
--- they become "show" — an explicit "hide" is left exactly as it was.
--- Idempotent: an already-migrated container has every category of its type explicitly "show" or
--- "hide" — no unset "" left, and no key still missing — which is exactly the pre-v3 shape this lift
--- exists to close. So it runs only while that gap remains; once every key already carries a decision
--- there is nothing left to convert, and it returns without touching state OR copying ids again. This
--- is load-bearing, not a nicety: without it, a container that started with NO "show" (the no-whitelist
--- branch) ends its first run with EVERY key at "show" — because Show is the new model's "no decision
--- needed" — and a second run would then read that as "some category is show" and misfire the
--- WHITELISTED branch on a container that was never narrowed, sweeping it to near-nothing and copying
--- every spell category's ids onto its whitelist.
--- Runs before liftEnchantFlag and only ever touches `NS.Categories.For(c.auraType)`'s current keys:
--- weaponEnchants is not one of them yet (B3 adds it), so THIS STEP as shipped today cannot reach it.
--- Do not read that as "safe in either order forever" — once B3 adds weaponEnchants as a real
--- category, this lift WOULD walk and write it, and running the enchant lift first would then have
--- its "show" already stamped here as one more unset row the lift is free to convert, sweeping a
--- container that whitelisted nothing to hide even its enchants. The order below stays required, and
--- B3 must confirm how a `kind == "enchant"` category (see modules/FilterCompiler.lua's own
--- `kind == "enchant"` skip) interacts with this sweep before schema v3 can be considered settled.
--- Whether every category of `def` already carries an explicit "show" or "hide" on `cats` — the
--- fixed point this whole lift converges to, and the idempotency guard.
local function categoriesDecided(def, cats)
    for _, cat in ipairs(def) do
        local state = cats[cat.key]
        if state ~= "show" and state ~= "hide" then return false end
    end
    return true
end

--- The category defs currently at "show", in declaration order.
local function shownCategories(def, cats)
    local shown = {}
    for _, cat in ipairs(def) do
        if cats[cat.key] == "show" then
            local n = #shown
            shown[n + 1] = cat
        end
    end
    return shown
end

--- No category was whitelisted: only the unset "" (or missing) rows need a decision, and they become
--- "show". An explicit "hide" is left exactly as it was (see liftCategoryWhitelist's doc comment).
local function liftUnwhitelisted(def, cats)
    for _, cat in ipairs(def) do
        if cats[cat.key] ~= "hide" then cats[cat.key] = "show" end
    end
end

--- At least one category was whitelisted: every category NOT "show" becomes "hide", and the shown
--- spell categories' ids are copied onto filter.whitelist (liftWhitelistSpells).
local function liftWhitelisted(p, c, def, cats, shown)
    for _, cat in ipairs(def) do
        if cats[cat.key] ~= "show" then cats[cat.key] = "hide" end
    end
    liftWhitelistSpells(p, c, shown)
end

local function liftCategoryWhitelist(p, c)
    local def = NS.Categories and NS.Categories.For(c.auraType)
    local cats = type(c.filter) == "table" and c.filter.categories
    if type(def) ~= "table" or type(cats) ~= "table" then return end
    local defCount = #def
    if defCount == 0 or categoriesDecided(def, cats) then return end
    local shown = shownCategories(def, cats)
    local shownCount = #shown
    if shownCount == 0 then
        liftUnwhitelisted(def, cats)
    else
        liftWhitelisted(p, c, def, cats, shown)
    end
end

--- The old `filter.includeEnchants` boolean becomes the `weaponEnchants` category row, and the old
--- key is cleared. Runs AFTER liftCategoryWhitelist (see its comment above for the ordering risk).
--- Idempotent: a second run finds `categories.weaponEnchants` already set (not nil, whichever way the
--- first run decided it) and does nothing — a guard against `filter.includeEnchants` already being
--- nil by then, which would otherwise unconditionally re-stamp "hide" and silently drop a container
--- that had migrated to "show" (a restored backup, a profile copy, a re-applied step). A container
--- whose old key was never set at all (never touched includeEnchants, or a pre-B2 profile with no
--- weaponEnchants row yet) still converts once, to "hide" — the old default.
--- ENCHANT containers never read the old flag and are left alone (also gated by MigrateV3's
--- KNOWN_AURA_TYPES check, for a container whose auraType is missing or corrupt).
local function liftEnchantFlag(c)
    if c.auraType == "ENCHANT" then return end
    local f = type(c.filter) == "table" and c.filter
    if not f then return end
    if type(f.categories) ~= "table" then f.categories = {} end
    if f.categories.weaponEnchants ~= nil then return end
    f.categories.weaponEnchants = f.includeEnchants and "show" or "hide"
    f.includeEnchants = nil
end

--- Schema v3 over one profile table (docs/schema.md, Migration path). A test seam as well as the
--- step's body: tests/test_database.lua runs it over raw profile tables.
--- @return number  the containers it walked
function Database.MigrateV3(p)
    if type(p) ~= "table" or type(p.containers) ~= "table" then return 0 end
    local walked = 0
    for _, c in pairs(p.containers) do
        if type(c) == "table" then
            if KNOWN_AURA_TYPES[c.auraType] then
                liftCategoryWhitelist(p, c)
                liftEnchantFlag(c)
            end
            walked = walked + 1
        end
    end
    return walked
end

--- Run `fn(profile, name)` over every stored profile: AceDB's raw store (`db.sv.profiles`, the
--- inactive ones included), or the no-AceDB fallback's one profile. Sorted, so the log is stable.
local function eachProfile(db, fn)
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

-- The account-wide schema ladder, in order, one row per version. v1 is the shape the addon shipped
-- with; each stored-shape change adds a row here in the same change (toc-file-§2). Containers live in
-- every profile, so a step walks them all, not only the active one.
local SCHEMA_STEPS = {
    { to = 2, apply = function(db)
        eachProfile(db, function(p, name)
            local n = Database.MigrateV2(p)
            if NS.Debug then
                NS.Debug("Migrate", "v2 profile '%s': spell lists, dispel colors, healing and strata over %s container(s)", name, n)
            end
        end)
    end },
    { to = 3, apply = function(db)
        eachProfile(db, function(p, name)
            local n = Database.MigrateV3(p)
            if NS.Debug then
                NS.Debug("Migrate", "v3 profile '%s': category whitelist lift and weaponEnchants over %s container(s)", name, n)
            end
        end)
    end },
}

--- Current schema version: the last step's `to`, or 1. A test seam: tests/test_database.lua calls
--- it; production (NS.RunMigrations) walks SCHEMA_STEPS directly.
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
