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

-- The attach sides a container may store (batch 9 E2), as a set.
local KNOWN_EDGE = {}
for _, token in ipairs(NS.Constants.ATTACH_EDGES) do KNOWN_EDGE[token] = true end
local DEFAULT_EDGE = "after-start"

--- Map an unknown `attach.edge` on container `c` to after-start (batch 9 MG-1): hand-edited or
--- imported data never reaches the anchor code as a token it cannot place. Whether a KNOWN side is
--- allowed right now is never rewritten here: it depends on the chain, and Anchors.ResolvedEdge falls
--- back at runtime so undoing the change restores the side.
local function normalizeAttach(c)
    local at = c.attach
    if type(at) ~= "table" or KNOWN_EDGE[at.edge] then return end
    if NS.Debug then NS.Debug("Migrate", "container %s: unknown attach side '%s' read as %s", c.id, at.edge, DEFAULT_EDGE) end
    at.edge = DEFAULT_EDGE
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
-- The owner's 2026-09-15 filter-priority revision (spec section 6, E-8) made a Show a positive claim
-- that beats a Hide on the same aura (modules/FilterCompiler.lua's rank 3), for every category kind
-- rather than only `spells`. That is what the old "show" rows needed protecting for in the first
-- place, so the id-copying half of this lift (once `liftWhitelistSpells`, onto `filter.whitelist`) is
-- gone: the compiler now does that job itself, on every run, not just at migration time.
--
-- Only recognized aura types are touched. `Cat.For(nil)` and `Cat.For("garbage")` both fall back to
-- an empty list, as ENCHANT's did, so liftCategoryWhitelist is a no-op for them — but the string
-- compare `auraType == "ENCHANT"` that used to gate liftEnchantFlag does NOT catch nil or garbage, so
-- a container with a missing or corrupt auraType could still get a weaponEnchants row written with no
-- corresponding category list. `Database.MigrateV3` itself gates both lifts on a known aura type, so
-- neither runs for such a container: it is left untouched rather than half-converted.
local KNOWN_AURA_TYPES = { HELPFUL = true, HARMFUL = true, ENCHANT = true }

--- `def` minus any `kind == "enchant"` or `kind == "uncategorized"` entry: the categories that
--- actually filter auras AND existed under the old three-state whitelist model this lift converts.
--- See liftCategoryWhitelist's doc comment for why an enchant row must take no part in the whitelist
--- sweep, today (a no-op — the kind doesn't exist in `def` yet) or after B3 (excluded categorically).
---
--- `uncategorized` (batch 7, U-1..U-5) is excluded for a DIFFERENT reason, and it matters: unlike
--- `enchant` it DOES match auras, but the old whitelist model it predates never had an opinion about
--- it — no stored container has ever carried a `categories.uncategorized` key, "" or otherwise, so
--- neither the generic sweep NOR the `categoriesDecided` fixed-point check may treat it as an
--- ordinary filterable category.
---
--- Why the exclusion alone is not enough: leaving the key out of `filterableCategories` is right for
--- the UNWHITELISTED branch (`liftUnwhitelisted`) — leaving the key nil there is what lets the
--- ordinary backfill (defaults/Categories.lua's `DefaultStates`, via `NS.CONTAINER_TEMPLATE`) supply
--- its D3 default, Show. It is WRONG, on its own, for the WHITELISTED branch (`liftWhitelisted`): the
--- old exclusive whitelist meant "only these categories", and the longhand of that is
--- `uncategorized = "hide"` — leaving it nil there does not defer to a neutral default, it silently
--- WIDENS an already-narrowed container. Concretely: a v2 profile narrowed to "Defensive cooldowns
--- only" migrates through v3 with every OTHER category explicitly `"hide"` but `uncategorized` still
--- nil; the ordinary backfill then supplies `"show"`; `addCategoryGroups`
--- (modules/FilterCompiler.lua) sees a Show `uncategorized` category, emits its own group (the base
--- plus `excludeSpellIDs(union)`, carrying NO hidden-category exclusion) AND suppresses the catch-all
--- — so the container ends up drawing every buff not on any spell list, in place, irreversibly. That
--- is exactly the "silently WIDEN what an already-stored container draws" failure this whole lift
--- exists to prevent (the header comment above `KNOWN_AURA_TYPES`). So `liftCategoryWhitelist`
--- stamps the aura type's `uncategorized` key `"hide"` itself, in the WHITELISTED branch ONLY, using
--- the un-filtered `def` (`uncategorizedKeyOf`) since `filterableCategories` has already stripped it
--- out of `filterable`. The UNWHITELISTED branch is untouched — the key stays nil there, exactly as
--- described above.
local function filterableCategories(def)
    local out = {}
    for _, cat in ipairs(def) do
        if cat.kind ~= "enchant" and cat.kind ~= "uncategorized" then
            local n = #out
            out[n + 1] = cat
        end
    end
    return out
end

--- Whether every FILTERABLE category of `def` already carries an explicit "show" or "hide" on `cats`
--- — the fixed point this whole lift converges to, and the idempotency guard.
local function categoriesDecided(def, cats)
    for _, cat in ipairs(def) do
        local state = cats[cat.key]
        if state ~= "show" and state ~= "hide" then return false end
    end
    return true
end

--- Whether any category def in `def` is currently at "show".
local function anyShown(def, cats)
    for _, cat in ipairs(def) do
        if cats[cat.key] == "show" then return true end
    end
    return false
end

--- No category was whitelisted: only the unset "" (or missing) rows need a decision, and they become
--- "show". An explicit "hide" is left exactly as it was (see liftCategoryWhitelist's doc comment).
local function liftUnwhitelisted(def, cats)
    for _, cat in ipairs(def) do
        if cats[cat.key] ~= "hide" then cats[cat.key] = "show" end
    end
end

--- At least one category was whitelisted: every category NOT "show" becomes "hide" — the longhand of
--- the old exclusive whitelist (see liftCategoryWhitelist's doc comment for why no id copy is
--- needed any more).
local function liftWhitelisted(def, cats)
    for _, cat in ipairs(def) do
        if cats[cat.key] ~= "show" then cats[cat.key] = "hide" end
    end
end

--- The `uncategorized`-kind category's key in `def` (the UN-filtered `NS.Categories.For(auraType)`
--- list, before `filterableCategories` strips it out), or nil if this aura type carries none. What
--- `liftCategoryWhitelist` uses to give the WHITELISTED branch the one thing `filterableCategories`'s
--- categorical exclusion cannot: the longhand of "only these categories" for a key the generic sweep
--- must never touch.
--- @return string|nil
local function uncategorizedKeyOf(def)
    for _, cat in ipairs(def) do
        if cat.kind == "uncategorized" then return cat.key end
    end
    return nil
end

--- The whitelist lift: if a container had ANY category of its aura type at "show", it was an
--- exclusive whitelist under the old three-state model — so every category of that type NOT "show"
--- (an unset "" or an explicit "hide", the old model excluded both from the whitelist's one group)
--- becomes "hide", the longhand of that exclusion. With no "show" present the container already drew
--- everything except its explicit "hide" rows (the old model's default group), so only the unset ""
--- rows need a decision at all, and they become "show" — an explicit "hide" is left exactly as it was.
--- Under the current filter priority (docs/superpowers/specs/2026-09-14-feedback-batch6-design.md
--- section 6, rank 3) a Show beats a Hide on the same aura, for every category kind, so a container
--- narrowed this way keeps drawing exactly what it drew before without any id needing to be copied
--- onto `filter.whitelist` — the compiler's own category groups do that job now.
--- Idempotent: an already-migrated container has every category of its type explicitly "show" or
--- "hide" — no unset "" left, and no key still missing — which is exactly the pre-v3 shape this lift
--- exists to close. So it runs only while that gap remains; once every key already carries a decision
--- there is nothing left to convert, and it returns without touching state again. This is
--- load-bearing, not a nicety: without it, a container that started with NO "show" (the no-whitelist
--- branch) ends its first run with EVERY key at "show" — because Show is the new model's "no decision
--- needed" — and a second run would then read that as "some category is show" and misfire the
--- WHITELISTED branch on a container that was never narrowed, sweeping it to near-nothing.
--- Runs before liftEnchantFlag and only ever touches `NS.Categories.For(c.auraType)`'s FILTERABLE keys
--- (filterableCategories above) — a `kind == "enchant"` category, `weaponEnchants` once B3 adds it, is
--- excluded categorically, not because it happens not to exist in `def` yet. That is what makes the
--- order in `Database.MigrateV3` safe both before and after B3: an enchant row is a container capability ("does this
--- container have weapon-enchant slots"), not a filter over auras — it matches no aura and joins no
--- aura group (modules/FilterCompiler.lua's own `splitCategories` skips it the same way), so it must
--- never count toward "was this container narrowed", and never be swept to "hide" by that decision.
--- Without the exclusion, a container with NO `filter.categories` table at all is the sharpest case:
--- run 1 has nothing for this lift to do (no categories table yet), so liftEnchantFlag alone creates
--- the table holding only `weaponEnchants`; run 2 would then see exactly one category at "show" once
--- `weaponEnchants` is real, read that as narrowed, and sweep every other category of the container to
--- "hide" — a near-total blackout of a container the player never touched.
local function liftCategoryWhitelist(c)
    local def = NS.Categories and NS.Categories.For(c.auraType)
    local cats = type(c.filter) == "table" and c.filter.categories
    if type(def) ~= "table" or type(cats) ~= "table" then return end
    local filterable = filterableCategories(def)
    local filterableCount = #filterable
    if filterableCount == 0 or categoriesDecided(filterable, cats) then return end
    if anyShown(filterable, cats) then
        liftWhitelisted(filterable, cats)
        -- Why only this branch stamps it (see filterableCategories's doc comment): only the
        -- WHITELISTED branch stamps this, and only "hide" — Show is exactly the case the ordinary
        -- backfill already handles correctly, for a key the sweep above deliberately never reaches.
        -- UNCONDITIONAL overwrite, on the assumption `cats[uncatKey]` is nil here: true today (a v2
        -- profile cannot carry the key at all, and an already-migrated post-v3 profile early-returns
        -- above on `categoriesDecided`, since `uncategorized` is excluded from the check but every
        -- OTHER filterable key is already decided by then). Unreachable now, but worth naming: if a
        -- future batch adds another filterable category, a profile narrowed AND still at
        -- schemaVersion <= 2 AND already carrying a deliberate `uncategorized = "show"` from some
        -- other path would have that Show silently overwritten to Hide here. Nothing in this shape
        -- can construct that combination today.
        local uncatKey = uncategorizedKeyOf(def)
        if uncatKey then cats[uncatKey] = "hide" end
    else
        liftUnwhitelisted(filterable, cats)
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
--- KNOWN_AURA_TYPES check, for a container whose auraType is missing or corrupt). The
--- `weaponEnchants` category only exists for HELPFUL containers (defaults/Categories.lua); a
--- HARMFUL container has no such category, so writing `categories.weaponEnchants` there would be
--- inert garbage stored forever in real saved variables — gated out here.
local function liftEnchantFlag(c)
    if c.auraType ~= "HELPFUL" then return end
    local f = type(c.filter) == "table" and c.filter
    if not f then return end
    if type(f.categories) ~= "table" then f.categories = {} end
    if f.categories.weaponEnchants ~= nil then return end
    f.categories.weaponEnchants = f.includeEnchants and "show" or "hide"
    f.includeEnchants = nil
end

--- Schema v3 over one profile table (docs/schema.md, Migration path). A test seam as well as the
--- step's body: tests/test_database.lua runs it over raw profile tables. A container skipped for an
--- unrecognized auraType does not count toward the return value — it was not converted, so the
--- ladder's "over N container(s)" log line stays honest — and logs its own `[Migrate]` line naming it,
--- since a silently skipped container is the kind of thing only its player would ever notice missing.
--- @return number  the containers it walked (converted)
function Database.MigrateV3(p)
    if type(p) ~= "table" or type(p.containers) ~= "table" then return 0 end
    local walked = 0
    for key, c in pairs(p.containers) do
        if type(c) == "table" then
            if KNOWN_AURA_TYPES[c.auraType] then
                liftCategoryWhitelist(c)
                liftEnchantFlag(c)
                walked = walked + 1
            elseif NS.Debug then
                NS.Debug("Migrate", "v3 container '%s' skipped: unrecognized auraType %s", tostring(key), tostring(c.auraType))
            end
        end
    end
    return walked
end

--- Which stored `filter.categories` key preserves "Only these categories" for `auraType`, or nil.
--- Both HELPFUL and HARMFUL now carry an `uncategorized` category (asymmetric —
--- defaults/Categories.lua's KINDS doc — but Hide reproduces the retired toggle on either type, which
--- is all this migration ever needed). `ENCHANT` is deliberately excluded, not merely absent: an
--- ENCHANT container compiled to no aura groups at all (`FC.Compile`'s `compileEnchant`, retired with
--- the aura type at schema v5), so its `onlyShown` — however it got set — never did anything, and
--- clearing it loses nothing worth counting. Any other or unrecognized `auraType` returns nil, the
--- "lost" case — reachable in practice only for a corrupt or future `auraType`
--- (`Database.MigrateV3`'s `KNOWN_AURA_TYPES` names the same three this migration actually expects),
--- not a common one: every real HELPFUL or HARMFUL container converts.
local function uncategorizedKeyFor(auraType)
    if auraType == "HELPFUL" then return "uncategorized" end
    if auraType == "HARMFUL" then return "uncategorizedDebuffs" end
    return nil
end

--- Schema v4 over one profile table: the retired "Only these categories" toggle
--- (`container.filter.onlyShown`) becomes `categories.<uncategorized key> = "hide"` for the container's
--- aura type, or is simply lost with the key cleared for a shape that has no such category
--- (`uncategorizedKeyFor`). `lostList` names every lost container (`{ id, name, auraType }`, in
--- container-key order) so the caller can tell the player, not just the debug console — see the v4
--- step in `SCHEMA_STEPS`, which is what actually calls `NS.Print`; this function stays a pure test
--- seam, like `MigrateV2`/`MigrateV3`.
--- @return number converted, number lost, table lostList
function Database.MigrateV4(p)
    if type(p) ~= "table" or type(p.containers) ~= "table" then return 0, 0, {} end
    local converted, lost, lostList = 0, 0, {}
    local keys = {}
    for key in pairs(p.containers) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(keys) do
        local c = p.containers[key]
        if type(c) == "table" and type(c.filter) == "table" and c.filter.onlyShown == true then
            local catKey = uncategorizedKeyFor(c.auraType)
            if catKey then
                c.filter.categories = c.filter.categories or {}
                c.filter.categories[catKey] = "hide"
                converted = converted + 1
            elseif c.auraType ~= "ENCHANT" then
                lost = lost + 1
                lostList[#lostList + 1] = { id = key, name = c.name, auraType = c.auraType }
            end
            c.filter.onlyShown = nil
        end
    end
    return converted, lost, lostList
end

--- Schema v5 over one profile table (feedback #6, 2026-09-19): the Weapon enchants AURA TYPE retires,
--- and enchants are a buff category only. Every stored container with `auraType == "ENCHANT"` becomes
--- an ENCHANT-ONLY buff container: `auraType = "HELPFUL"`, `unit = "player"` (enchants are only ever
--- the player's), and `filter.categories = Cat.EnchantOnlyStates()` (every buff category Hidden but
--- Weapon enchants, Uncategorized included, the whole map replaced rather than merged). A stored
--- `filter.whitelist` is CLEARED too: `FC.Compile`'s
--- `addWhitelistGroup` draws a whitelist's spells regardless of category state, and did nothing under
--- the old `ENCHANT` aura type only because `compileEnchant` returned before any list was read — kept
--- as-is it would draw those buffs after v5, when the container never drew anything but enchants
--- before. Nothing else on `filter` (blacklist, castBy, duration) is touched: those only narrow a
--- group and add none, so they cannot make the container draw more than its enchant slots.
--- `filter.hidePermanentEnchants` and every other key — name, style, styling, position — carry over
--- untouched. One [Migrate] line per converted container, plus one more when a non-empty whitelist
--- was cleared, naming the container and how many ids it held, in key order. The profile's
--- `dispelColors.None` is cleared too: an aura with no dispel type takes the surface's own color now
--- (feedback #7), so nothing reads it. A test seam as well as the step's body, like MigrateV2..V4.
--- @return number  the containers converted
function Database.MigrateV5(p)
    if type(p) ~= "table" then return 0 end
    if type(p.dispelColors) == "table" then p.dispelColors.None = nil end
    if type(p.containers) ~= "table" then return 0 end
    local keys = {}
    for key in pairs(p.containers) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local converted = 0
    for _, key in ipairs(keys) do
        local c = p.containers[key]
        if type(c) == "table" and c.auraType == "ENCHANT" then
            c.auraType, c.unit = "HELPFUL", "player"
            if type(c.filter) ~= "table" then c.filter = {} end
            c.filter.categories = NS.Categories.EnchantOnlyStates()
            if type(c.filter.whitelist) == "table" then
                local whitelistCount = 0
                for _ in pairs(c.filter.whitelist) do
                    whitelistCount = whitelistCount + 1
                end
                if whitelistCount > 0 then
                    c.filter.whitelist = nil
                    if NS.Debug then
                        NS.Debug("Migrate", "v5 container '%s' (%s): cleared a %s-entry whitelist so it draws only Weapon enchants", tostring(key), tostring(c.name), whitelistCount)
                    end
                end
            end
            converted = converted + 1
            if NS.Debug then
                NS.Debug("Migrate", "v5 container '%s' (%s): now a player buff container showing only Weapon enchants", tostring(key), tostring(c.name))
            end
        end
    end
    return converted
end

--- v6 (issue #10 checkpoint 3, 2026-09-20): the user-category store. Stamps the two profile keys a
--- player's own categories live in -- `userCategories`, the records, and `userCategoryOrder`, the
--- declaration order that is their only ordering source -- into every stored profile, the inactive
--- ones included.
---
--- IT CONVERTS NOTHING, and that is stated rather than apologized for. Both keys are MAPS THE PLAYER
--- FILLS, the shape `Database.Backfill`'s own header at the top of this file calls empty in the
--- template, so absence and emptiness are indistinguishable and every read of them is nil-safe
--- anyway -- AceDB strips a stored value equal to its default at save time, so an untouched profile
--- may carry neither key on disk however many times this has run. The row earns its place for two
--- other reasons: toc-file-§2 requires a stored-shape change to add a ladder row in the same change,
--- and the stamp is what lets a LATER step say "a profile at v6 or later carries these keys"
--- without re-deriving it, checkpoint 5's cross-profile deletion sweep being the obvious candidate.
---
--- IDEMPOTENT about everything: it creates only what is absent, and replaces a non-table (a
--- hand-edited or corrupt leaf that later code would otherwise index) rather than leaving it. A
--- second run changes nothing.
--- @return number  the user categories the profile already holds, which is 0 for every profile this
---                 step can reach -- the count is there for the log, not for a decision
function Database.MigrateV6(p)
    if type(p) ~= "table" then return 0 end
    if type(p.userCategories) ~= "table" then p.userCategories = {} end
    if type(p.userCategoryOrder) ~= "table" then p.userCategoryOrder = {} end
    local n = 0
    for _ in pairs(p.userCategories) do n = n + 1 end
    return n
end

--- v7 (owner 2026-09-25): the Consumables category retired, and three new buff categories --
--- `groupBuffs` (split out of Support), `stances` and `racials` (auras that had no list before, bar
--- Shadowmeld out of Utility).
---
--- THE RULE IS THAT NO STORED CONTAINER DRAWS DIFFERENTLY BECAUSE OF THE UPGRADE. A new key left
--- absent would backfill as Show (`Cat.DefaultStates`), so a container that Hid Support, or that
--- Hid Uncategorized to draw only what it names (the "Player cooldowns" starter), would start
--- drawing raid buffs or stances it never drew. So each new key takes the state of where its auras
--- used to fall: `groupBuffs` Support's, `stances` and `racials` Uncategorized's. A key already
--- there is a choice and is kept; a source that is absent leaves the new key to the backfill.
--- `racialDebuffs`, the debuff-side Racials, is Hidden wherever Hard CC or Soft CC is Hidden (seven of
--- its eight ids sit in those lists too, and a Show claim beats a Hide, so a shown racial list would
--- rescue a War Stomp the container hid); otherwise it takes Show. Only a container carrying one of
--- those two debuff keys gets one.
--- `consumables` is simply dropped: its five flask ids fall to Uncategorized, like any unlisted buff.
---
--- The player's own list edits follow the ids that moved: a Support edit on a group buff, and a
--- Utility edit on Shadowmeld, move to the new category unless it already has its own. The
--- Consumables edits are dropped with the category. IDEMPOTENT: a second run changes nothing. A
--- test seam as well as the step's body, like MigrateV2..V6.
--- @return number  the containers it walked
local V7_SEEDS = { groupBuffs = "support", stances = "uncategorized", racials = "uncategorized" }
local V7_MOVED = {
    support = { to = "groupBuffs", ids = { 1459, 21562, 6673, 1126, 462854, 381748, 381732, 381741,
        381746, 381749, 381750, 381751, 381752, 381756, 381757 } },
    utility = { to = "racials", ids = { 58984 } },
}

local function moveEdits(edits)
    for from, move in pairs(V7_MOVED) do
        local src = edits[from]
        if type(src) == "table" then
            for _, id in ipairs(move.ids) do
                if src[id] ~= nil then
                    local dst = edits[move.to]
                    if type(dst) ~= "table" then dst = {}; edits[move.to] = dst end
                    if dst[id] == nil then dst[id] = src[id] end
                    src[id] = nil
                end
            end
            if next(src) == nil then edits[from] = nil end
        end
    end
end

--- One container's category states: Consumables dropped, the new keys seeded from where their
--- auras used to fall.
local function seedV7(cats)
    cats.consumables = nil
    for key, from in pairs(V7_SEEDS) do
        if cats[key] == nil and cats[from] ~= nil then cats[key] = cats[from] end
    end
    if cats.racialDebuffs == nil and (cats.hardCC ~= nil or cats.softCC ~= nil) then
        cats.racialDebuffs = (cats.hardCC == "hide" or cats.softCC == "hide") and "hide" or "show"
    end
end

function Database.MigrateV7(p)
    if type(p) ~= "table" then return 0 end
    if type(p.categorySpells) == "table" then
        p.categorySpells.consumables = nil
        moveEdits(p.categorySpells)
    end
    if type(p.containers) ~= "table" then return 0 end
    local walked = 0
    for _, c in pairs(p.containers) do
        local cats = type(c) == "table" and type(c.filter) == "table" and c.filter.categories
        if type(cats) == "table" then
            seedV7(cats)
            walked = walked + 1
        end
    end
    return walked
end

--- v8 (batch 8, owner 2026-09-25, D5/D8): the seam between a container and the container it is
--- attached to is now the child's own spacing (Anchors.SeamOffset, SS-1), and `attach.x`/`attach.y`
--- add on top as a nudge (SS-2). A container attached to another whose offsets are still the old
--- template default, 0/-4, would otherwise sit 4px further off than its own gaps, so they become
--- 0/0. An ABSENT offset is that same old default (the template carried it when the container was
--- stored, and the backfill after the ladder would otherwise hand it the new template's 0 without
--- the step saying so), so it is stamped 0 too. Any other value is the player's own and is kept, and
--- a named-frame or screen container keeps its offsets whatever they are.
---
--- The same step (D8) turns Size to fit OFF on every Text container stored before it (AS-3, D7): the
--- template's `text.autoSize` is true, and the backfill after the ladder would otherwise hand that to
--- every existing Text container and move every hand-sized layout. Text containers only (batch 9 E6:
--- Size to fit is Text-only; a bars or icons container carries no value of its own, and one switched
--- to Text later reads the template's true, and v9 removes what the earlier style-blind stamp wrote).
--- A text block that is missing or not a table is created for the stamp; a stored value is the
--- player's own and is kept. A fresh install walks no containers (the starters are seeded after the
--- ladder), so they, and every container made later, read the template's true.
---
--- IDEMPOTENT: a second run finds 0/0 and a stored autoSize, and changes nothing. Unreleased, so later
--- batch 8 tasks extend this same step (D8).
--- @return number  the containers whose offsets it reset
--- @return number  the containers Size to fit was stamped off on
local V8_OLD_X, V8_OLD_Y = 0, -4

local function resetOldSeam(at, mode)
    if type(at) ~= "table" or at.mode ~= (mode or "container") then return false end
    local x, y = at.x, at.y
    if x == nil then x = V8_OLD_X end
    if y == nil then y = V8_OLD_Y end
    if x ~= V8_OLD_X or y ~= V8_OLD_Y then return false end
    at.x, at.y = 0, 0
    return true
end

--- Stamp Size to fit off on Text container `c` unless it holds a value of its own; whether it stamped.
local function stampFitOff(c)
    if c.style ~= "text" then return false end
    if type(c.text) ~= "table" then c.text = {} end
    if c.text.autoSize ~= nil then return false end
    c.text.autoSize = false
    return true
end

function Database.MigrateV8(p)
    if type(p) ~= "table" or type(p.containers) ~= "table" then return 0, 0 end
    local reset, stamped = 0, 0
    for _, c in pairs(p.containers) do
        if type(c) == "table" then
            if resetOldSeam(c.attach) then reset = reset + 1 end
            if stampFitOff(c) then stamped = stamped + 1 end
        end
    end
    return reset, stamped
end

--- v9 (batch 9, owner 2026-09-25, MG-1). Unreleased, so later batch 9 tasks extend this same step.
---
--- 1. Size to fit is Text-only (E6). The style-blind v8 stamp that shipped on this branch wrote
---    `text.autoSize = false` on bars and icons containers too, where the Text page is disabled and
---    nothing reads it, so it is removed from every container whose style is not Text (no stored
---    style is the template's bars). The backfill after the ladder then hands it the template's
---    value, the same as a container that climbed from before v8. A Text container's value is the
---    player's own and is kept. A text block that is missing is not created.
--- 2. The attach side (E2, E5). Every container with an attach table whose `edge` is missing or not
---    one of the nine gets "after-start", exactly the points every attachment had before (a test pins
---    EdgePoints(L, "after-start") to the old DerivedPoints), so nothing moves. Every container, not
---    only container-mode ones (the D8 rationale): a later switch to Another container keeps today's
---    placement even if the template default ever changes. A known side is the player's own.
--- 3. The latent seam (findings Problem D, fix C). v8 reset the old template's 0/-4 offset only in
---    container mode; a SCREEN container still holding it reads nothing from it, until a switch to
---    Another container added the 4px back on top of the seam. The same rule (an absent offset is the
---    old default) now resets it in screen mode. A named frame reads it as its gap, and keeps it.
---
--- IDEMPOTENT: a second run finds no value to remove, every edge known and no screen 0/-4.
--- @return number  the containers Size to fit was removed from
--- @return number  the containers the attach side was stamped on
--- @return number  the screen containers whose offsets it reset
function Database.MigrateV9(p)
    if type(p) ~= "table" or type(p.containers) ~= "table" then return 0, 0, 0 end
    local removed, stamped, reset = 0, 0, 0
    for _, c in pairs(p.containers) do
        if type(c) == "table" then
            if c.style ~= "text" and type(c.text) == "table" and c.text.autoSize ~= nil then
                c.text.autoSize = nil
                removed = removed + 1
            end
            local at = c.attach
            if type(at) == "table" and not KNOWN_EDGE[at.edge] then
                at.edge = DEFAULT_EDGE
                stamped = stamped + 1
            end
            if resetOldSeam(at, "screen") then reset = reset + 1 end
        end
    end
    return removed, stamped, reset
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
    { to = 4, apply = function(db)
        -- R-8..R-11 retired; NS.Print (not just NS.Debug, which a player may never have enabled) is
        -- the one place a lost container is actually told about — one consolidated line for the whole
        -- migration pass, not one per profile, so a player with several affected containers sees a
        -- single, plain notice rather than a burst of chat spam. Structurally one-shot already: the
        -- schema-version gate below never re-runs this step once `schemaVersion` reaches 4.
        local allLost = {}
        eachProfile(db, function(p, name)
            local converted, lost, lostList = Database.MigrateV4(p)
            if NS.Debug then
                NS.Debug("Migrate", "v4 profile '%s': 'Only these categories' retired -- %s container(s) moved to Uncategorized = Hide, %s lost the capability", name, converted, lost)
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
            if NS.Debug then
                NS.Debug("Migrate", "v5 profile '%s': the Weapon enchants aura type retired -- %s container(s) now show only the Weapon enchants category", name, n)
            end
        end)
    end },
    { to = 6, apply = function(db)
        eachProfile(db, function(p, name)
            local n = Database.MigrateV6(p)
            if NS.Debug then
                NS.Debug("Migrate", "v6 profile '%s': the user-category store stamped -- %s category(ies) already stored", name, n)
            end
        end)
    end },
    { to = 7, apply = function(db)
        eachProfile(db, function(p, name)
            local n = Database.MigrateV7(p)
            if NS.Debug then
                NS.Debug("Migrate", "v7 profile '%s': Consumables retired; Group buffs, Stances and Racials seeded over %s container(s)", name, n)
            end
        end)
    end },
    { to = 8, apply = function(db)
        eachProfile(db, function(p, name)
            local n, fit = Database.MigrateV8(p)
            if NS.Debug then
                NS.Debug("Migrate", "v8 profile '%s': the old 0/-4 attach offset reset on %s container(s) attached to another; Size to fit stamped off on %s Text container(s)", name, n, fit)
            end
        end)
    end },
    { to = 9, apply = function(db)
        eachProfile(db, function(p, name)
            local removed, stamped, reset = Database.MigrateV9(p)
            if NS.Debug then
                NS.Debug("Migrate", "v9 profile '%s': Size to fit removed from %s bars or icons container(s); attach side stamped after-start on %s; the old 0/-4 offset reset on %s screen container(s)", name, removed, stamped, reset)
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
            if NS.Debug then NS.Debug("Migrate", "v%s -> v%s", g.schemaVersion, step.to) end
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
    -- PROFILE-DEPENDENT, and `MigrateV2`'s `rekeyEdits` above asks it. A v2 profile cannot contain
    -- user keys, so the answer is the same either way today -- but moving this call earlier would
    -- quietly make a v2 migration's result depend on the active profile's user categories, which is
    -- not a dependency a migration may have.
    --
    -- Before PrepareProfile, because its `backfillContainers` is what stamps the template's newly
    -- added category keys into every stored container -- exactly the mechanism `Cat.DefaultStates`'
    -- own comment (defaults/Categories.lua) promises for a key added in a later version.
    NS.Categories.SyncUserCategories(NS.db.profile)
    local seeded = Database.PrepareProfile(NS.db.profile)
    if seeded > 0 and NS.Debug then NS.Debug("Migrate", "seeded %s starter container(s)", seeded) end
end
