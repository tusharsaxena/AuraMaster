local _, NS = ...

-- settings/Schema.lua — THE PATH MACHINERY behind every setting, and the one read seam and the one
-- write seam the panel, the CLI and the resets all land on (architecture-§5).
--
-- THE CONTAINER-RELATIVE PATH MODEL
-- ---------------------------------
-- Almost every setting in this addon belongs to ONE container, and containers are created by the
-- player at runtime. Written out absolutely a container row's path would be `containers.<id>.bars.
-- width` — dynamic, unknowable at file load, and impossible to express in the flat path model the
-- CLI and the panel both read. So a container row's path is RELATIVE and spelled
-- `container.bars.width`: it resolves against the ACTIVE container (NS.State.activeContainerId,
-- which the settings banner moves), falling back to the first container in display order. Global
-- rows keep absolute paths (`enabled`, `hideBlizzardBuffs`) and resolve against the profile.
--
-- What that buys: ONE schema, ONE write seam, and `/am set container.bars.width 300` means "the
-- container I am editing" on the CLI exactly as it does in the panel. The banner retargets every
-- row on four pages by moving one integer of session state. A caller that must write to a
-- SPECIFIC container — a drag handle saving its own position — passes the id as SetByPath's third
-- argument instead of moving the pointer under the panel.
--
-- ONE SOURCE FOR EVERY DEFAULT
-- ----------------------------
-- A row's `default` is never typed in a page file. RegisterSchemaRows stamps it from
-- defaults/Profile.lua — the container template for a `container.` row, the profile defaults for a
-- global one — so the widget's reset and a fresh profile cannot disagree (savedvariables-§2), and
-- the composers' own built-in defaults can never leak in. The validator below proves every path
-- resolves.
--
-- THE CARVE-OUTS: SPELL SETS
-- --------------------------
-- The always/never lists and the per-category spell edits are SETS the player grows, and a path
-- model has no vocabulary for "add id 12345". They are written WHOLE through this same seam — the
-- page builds the set it wants and hands all of it over — and normalized here, so a hand-edited
-- SavedVariables file or a `/am set` cannot plant a non-numeric id the filter compiler would trip
-- on. They take the same debug line and the same CONFIG_CHANGED every scalar write takes.
--
-- WHOLE SECTIONS
-- --------------
-- A position saved by a drag, or a filter copied from another container, is one act across many
-- leaves. Written leaf by leaf it would announce once per leaf, and a rejection halfway would leave
-- half of it moved. So a closed list of sections (SECTIONS below) can be written whole through this
-- same seam: backfilled from the template, carve-outs normalized, every row under it validated, and
-- only then stored — all of it or none — with one debug line and one CONFIG_CHANGED.
--
-- WHAT IS THE LIBRARY'S AND WHAT IS NOT (issue #21)
-- -------------------------------------------------
-- With LibKa0s present, LibKa0s-Schema-1.0 supplies the machinery under the rows: the path
-- primitives (SplitPath, Read, Write), the registry (FindRow, AddRows, Reindex), the bulk bracket
-- (BulkBegin, BulkEnd, BulkRun, BulkAdd, InBulk), SameValue as the tally's change test, and Validate.
-- The WRITE SEAM stays this file's: NS.SetByPath, not the library's Set, because its front branches
-- (the minimap inversion, the spell-set carve-outs, the all-or-nothing whole-section writes, and
-- NS.CheckWrite's dry run that mirrors them) have no row-shaped equivalent there, and a library-less
-- build keeps this seam anyway (docs/schema.md, "Write seam: why AuraMaster keeps SetByPath"). The
-- host bodies of everything the library now supplies stay below as the library-absent arm, which
-- tests/degraded_env.lua exercises.

NS.Schema = NS.Schema or {}

-- THE WRITE-THROUGH PATHS (options-ui-§1, route (a)). Data only: the paths a HOST VERB writes
-- (`/am enable`/`disable`, `/am lock`/`unlock`) whose rows the Master controls composer declares.
-- Without LibKa0s that composer answers no rows, so these two paths have no row, and NS.SetByPath
-- stores them raw rather than refusing them as unknown. A path with a row always takes the row.
NS.WRITE_THROUGH = { enabled = true, locked = true }

local SchemaLib = LibStub and LibStub("LibKa0s-Schema-1.0", true)

-- ONE instance per addon, over the live NS.Schema array by reference (both the Options and Slash
-- descriptors hold that same array). No resolveRoot and no announce: nothing here calls S.Set or
-- S.Get. `debug` and `print` are read at call time, so a sink installed later (or a test's capture)
-- is the one that speaks.
local S = SchemaLib and SchemaLib:New({
    rows  = NS.Schema,
    -- The same list, handed to the library in its own array shape, so a future adoption of S.Set
    -- inherits it (LibKa0s-Schema's `writeThrough`, read once here). Nothing calls S.Set today.
    writeThrough = (function()
        local out = {}
        for path in pairs(NS.WRITE_THROUGH) do
            table.insert(out, path)
        end
        table.sort(out)
        return out
    end)(),
    debug = function(...) if NS.Debug then return NS.Debug(...) end end,
    print = function(line) if NS.Print then NS.Print(line) end end,
})
-- The instance, or nil in a library-less build: a test seam (tests/test_schema.lua).
NS.SchemaRuntime = S

local CONTAINER = "container"
local L = NS.L
local NO_CONTAINER = L["No container exists yet — create one on Containers."]

-- THE MINIMAP ROW IS THE ONE PATH THAT IS NOT THE PROFILE'S (launcher-§3).
--
-- Every other absolute path in this schema resolves against `db.profile`, which is why resolveRoot
-- needs no root argument. This one resolves against `db.global`, and its path is spelled
-- `global.minimap.shown` VERBATIM -- the composer takes the path unprefixed for exactly that reason.
-- The scope is the decision: a minimap button belongs to the installation, so a profile switch must
-- not move it and Reset all settings, a profile reset, must not un-hide one the player deliberately hid.
--
-- THE PATH IS A NAME, NOT A STORAGE ADDRESS, AND THE SENSE INVERTS BETWEEN THEM. The row is labeled
-- "Minimap button" and its path, the CLI name, reads in the row's own sense: `global.minimap.shown`
-- answers true while the button shows (launcher-§3). The stored key is LibDBIcon's own
-- `db.global.minimap.hide`, which the library writes too when the player uses its menu, and it does
-- not move: storing the library's key is what keeps there being ONE record of one state
-- (anti-pattern #81), so no `shown` key is ever stored and no SavedVariables migration exists. The
-- inversion is the whole cost of that, and it is paid HERE, once, in the read seam and the write
-- seam, rather than at each of the three places that reach it (the checkbox, `/am set`, `/am reset`).
--
-- Published as NS.MINIMAP_PATH because this file loads before settings/OptionsSetup.lua and
-- settings/General.lua, which read it rather than spelling the path a second and third time.
local MINIMAP_PATH = "global.minimap.shown"
NS.MINIMAP_PATH = MINIMAP_PATH

--- LibDBIcon's table inside the global store, or nil before core/Database.lua has built NS.db.
local function minimapStore()
    local g = NS.db and NS.db.global
    return type(g) == "table" and type(g.minimap) == "table" and g.minimap or nil
end

--- Whether the button is SHOWN -- the row's sense, inverted off the stored `hide`. A store that does
--- not exist yet answers `true`, the shipped default, never nil: a checkbox handed nil draws unset
--- and would tell the player the button is off while it is on screen.
local function minimapShown()
    local t = minimapStore()
    if not t then return true end
    return not t.hide
end

-- ---------------------------------------------------------------------------
-- Path plumbing
-- ---------------------------------------------------------------------------

-- The host bodies below are the library-absent arm; with LibKa0s the three locals after them are
-- the library's SplitPath, Read and Write (Write takes the value before `first`, hence the shim).
-- The host Read and Write answer the library's edge cases too: nil, or a no-op, for a root that is
-- not a table and for a path with no segment at or past `first` (#21).
--
-- Memoized: the set of paths is closed (the schema's own plus whatever the CLI is handed), while a
-- slider drag re-resolves one path many times a second.
local splitCache = {}

local function hostSplitPath(path)
    local parts = splitCache[path]
    if parts then return parts end
    parts = {}
    for segment in tostring(path):gmatch("[^%.]+") do
        parts[#parts + 1] = segment
    end
    splitCache[path] = parts
    return parts
end

local function hostReadFrom(root, parts, first)
    if type(root) ~= "table" then return nil end
    local last = #parts
    if last < first then return nil end   -- no setting is stored AT a root (LibKa0s-Schema's Read)
    local node = root
    for i = first, last do
        if type(node) ~= "table" then return nil end
        node = node[parts[i]]
    end
    return node
end

local function hostWriteInto(root, parts, first, value)
    if type(root) ~= "table" then return end
    local last = #parts
    if last < first then return end       -- a no-op, as LibKa0s-Schema's Write
    local node = root
    for i = first, last - 1 do
        local key = parts[i]
        if type(node[key]) ~= "table" then node[key] = {} end
        node = node[key]
    end
    node[parts[last]] = value
end

local splitPath = SchemaLib and SchemaLib.SplitPath or hostSplitPath
local readFrom = SchemaLib and SchemaLib.Read or hostReadFrom
local writeInto = hostWriteInto
if SchemaLib then
    local libWrite = SchemaLib.Write
    writeInto = function(root, parts, first, value) return libWrite(root, parts, value, first) end
end

local function copy(v) return NS.Database.DeepCopy(v) end

-- ---------------------------------------------------------------------------
-- Container resolution
-- ---------------------------------------------------------------------------

--- The container a `container.` path resolves against: the banner's selection, or the first
--- container in display order when nothing is selected (a fresh login, where the CLI has no banner
--- to consult and `/am get container.unit` must still mean something).
--- @return table|nil container, number|nil id
function NS.ActiveContainer()
    local Database = NS.Database
    if not Database then return nil, nil end
    local id = NS.State and NS.State.activeContainerId
    if id ~= nil then
        local c = Database.FindContainer(id)
        if c then return c, id end
    end
    local first = Database.GetContainers()[1]
    if first then return first, first.id end
    return nil, nil
end

--- Where a path lives: its root table, the index of its first segment in that root, and the id of
--- the container it landed in (nil for a global row).
local function resolveRoot(parts, containerId)
    if parts[1] == CONTAINER then
        if containerId ~= nil then
            local c = NS.Database.FindContainer(containerId)
            return c, 2, c and containerId or nil
        end
        local c, id = NS.ActiveContainer()
        return c, 2, id
    end
    return NS.db and NS.db.profile or nil, 1, nil
end

-- AN AUTOMATIC ROW (`nilAs`). A row may store nil for "no pick" and name, as `nilAs`, the value that
-- nil reads as everywhere a row is shown or written: the panel and `/am get` read `nilAs` for a
-- stored nil, the row's default IS `nilAs` (so Defaults and `/am reset` answer), and the row's own
-- normalize turns `nilAs` back into nil on the way in. The template declares no key, because a
-- backfilled value would be a pick; the two anchor-point rows are the ones (settings/Layout.lua,
-- batch 11 G2), where nil is Automatic and modules/Anchors.lua reads the store directly.

--- A row's `nilAs`, or nil. Before NS.FindSchemaRow is defined only RegisterSchemaRows asks, and it
--- reads the row it holds.
local function nilAsFor(path)
    local row = NS.FindSchemaRow and NS.FindSchemaRow(path)
    return row and row.nilAs
end

--- The shipped default for `path` — from the container template for a `container.` path, from the
--- profile defaults otherwise, and an automatic row's `nilAs` where the template declares nothing.
--- A deep copy, so a caller can never mutate the template.
function NS.DefaultFor(path)
    -- Inverted off the ONE declaration, defaults/Profile.lua's stored `global.minimap.hide = false`,
    -- rather than typed as `true` here: one hardcoded default, as for every other row.
    if path == MINIMAP_PATH then
        local g = NS.defaults and NS.defaults.global
        local t = type(g) == "table" and g.minimap or nil
        if type(t) ~= "table" then return nil end
        return not t.hide
    end
    local parts = splitPath(path)
    local d
    if parts[1] == CONTAINER then
        d = readFrom(NS.CONTAINER_TEMPLATE, parts, 2)
    else
        d = readFrom(NS.defaults and NS.defaults.profile, parts, 1)
    end
    if d == nil then return nilAsFor(path) end
    return copy(d)
end

-- ---------------------------------------------------------------------------
-- The index and registration
-- ---------------------------------------------------------------------------

-- The host index is the library-absent arm; with LibKa0s the instance's FindRow and Reindex answer.
-- Like the library's, it keeps the FIRST row on a duplicate path, which NS.ValidateSchema reports.
local index = {}

local function hostReindex()
    for k in pairs(index) do index[k] = nil end
    for _, row in ipairs(NS.Schema) do
        local path = row.path
        if type(path) == "string" and path ~= "" and index[path] == nil then index[path] = row end
    end
end

local function hostFindRow(path)
    if type(path) ~= "string" then return nil end
    return index[path]
end

local reindex = S and S.Reindex or hostReindex
local findRow = S and S.FindRow or hostFindRow

function NS.FindSchemaRow(path)
    return findRow(path)
end

--- The position of the row at `path` in NS.Schema, or nil when no row has it.
local function indexOf(path)
    if type(path) ~= "string" then return nil end
    for i, row in ipairs(NS.Schema) do
        if row.path == path then return i end
    end
    return nil
end

--- Add a page's rows. Every non-session row's `default` is stamped from defaults/Profile.lua here,
--- overwriting whatever a composer supplied, so the one hardcoded default is the template's.
---
--- APPENDS, unless `beforePath` names a row already registered, in which case the new rows are
--- INSERTED in front of it in order. The insert exists for issue #10's user categories
--- (defaults/UserCategories.lua's Cat.SyncUserCategories) and it is not a convenience: settings/
--- Filters.lua's renderCategories draws each grid in SCHEMA order, not in `Cat.For` order, and
--- `weaponEnchants` and `uncategorized` share the `custom` grid with every spell-list row -- so a
--- user category's row appended to the end of NS.Schema would draw BELOW Uncategorized and break
--- U-1 outright. The invariant the argument preserves is that schema order tracks `Cat.For`
--- declaration order per aura type, and tests/test_defaults.lua asserts it.
---
--- A `beforePath` naming nothing appends, rather than failing: the rows still exist, still resolve
--- and still answer the CLI, and the ordering test is what reports the mistake.
--- @param rows table
--- @param beforePath string|nil
function NS.RegisterSchemaRows(rows, beforePath)
    if type(rows) ~= "table" then return end
    local at = indexOf(beforePath)
    for _, row in ipairs(rows) do
        if not row.sessionOnly and type(row.path) == "string" then
            local d = NS.DefaultFor(row.path)
            if d == nil then d = row.nilAs end
            if d ~= nil then row.default = d end
        end
    end
    if S then
        S.AddRows(rows, at)   -- `at` nil appends; AddRows re-indexes
        return
    end
    for _, row in ipairs(rows) do
        if at then
            table.insert(NS.Schema, at, row)
            at = at + 1
        else
            NS.Schema[#NS.Schema + 1] = row
        end
    end
    reindex()
end

--- Remove every row `pred` answers true for, and return how many went.
---
--- THE SCHEMA HAD NO REMOVAL PATH UNTIL ISSUE #10, and it needs one for exactly one reason: a
--- profile switch replaces one set of user categories with another, and a row left behind from the
--- old set is not merely untidy. NS.ValidateSchema fails it (the container template no longer
--- carries the key, so NS.DefaultFor answers nil), `/am list` and `/am get` answer for a category
--- this profile does not have, and the Filters section draws a live Show/Hide row whose click WRITES
--- "show" or "hide" into a real stored container under a key nothing will ever compile -- permanent
--- garbage in the player's saved variables, one key per switch.
---
--- REBUILT IN PLACE, same table identity. settings/OptionsSetup.lua and settings/Slash.lua both hold
--- `allRows = function() return NS.Schema end`, a live reference handed to the library once at
--- registration; replacing the table would leave both of them reading the old array forever.
--- @param pred function  row -> boolean
--- @return number
function NS.UnregisterSchemaRows(pred)
    if type(pred) ~= "function" then return 0 end
    local kept, removed = {}, 0
    for _, row in ipairs(NS.Schema) do
        if pred(row) then
            removed = removed + 1
        else
            kept[#kept + 1] = row
        end
    end
    if removed == 0 then return 0 end
    local last = #NS.Schema
    for i = last, 1, -1 do
        NS.Schema[i] = nil
    end
    for i, row in ipairs(kept) do
        NS.Schema[i] = row
    end
    reindex()
    return removed
end

--- Whether `row` applies to container `cfg`. A row may name the aura types it means something for
--- (`auraTypes = { HELPFUL = true }`): the buff categories are not offered on a debuff container.
local function rowApplies(row, cfg)
    if row.auraTypes then
        return cfg ~= nil and row.auraTypes[cfg.auraType] == true
    end
    return true
end
-- Published for modules/Diagnostics.lua's non-default listing.
NS.RowApplies = rowApplies

--- The rows of one page, in declaration order, as they apply to the active container. `filter` is
--- the options library's ctx.unit, passed through and unused: this addon does not filter rows per
--- instance, it MOVES the instance every row resolves against.
function NS.SchemaForPage(pageKey, filter)   -- luacheck: ignore 212/filter
    local cfg = NS.ActiveContainer()
    local rows = {}
    for _, row in ipairs(NS.Schema) do
        if row.page == pageKey and not row.hidden and rowApplies(row, cfg) then
            rows[#rows + 1] = row
        end
    end
    return rows
end

-- ---------------------------------------------------------------------------
-- The read seam
-- ---------------------------------------------------------------------------

--- The current value of `path` for the active container (or container `containerId`). Also answers
--- paths that are not rows — `container.filter.whitelist`, a sub-table — because `/am get` is a
--- debugging tool as much as a settings reader.
function NS.GetSetting(path, containerId)
    if type(path) ~= "string" then return nil end
    if path == MINIMAP_PATH then return minimapShown() end
    local row = findRow(path)
    if row and row.sessionOnly then
        if row.get then return row.get() end
        return nil
    end
    local parts = splitPath(path)
    local root, first = resolveRoot(parts, containerId)
    if not root then return nil end
    local v = readFrom(root, parts, first)
    if v == nil and row then return row.nilAs end
    return v
end

-- ---------------------------------------------------------------------------
-- The carve-outs
-- ---------------------------------------------------------------------------

--- A set of spell ids: positive integer keys, `true` values. Anything else is dropped rather than
--- stored, because the filter compiler hands these keys to the aura engine as they are.
local function normalizeIdSet(value)
    if type(value) ~= "table" then return nil, L["Expected a set of spell ids"] end
    local out = {}
    for k, v in pairs(value) do
        local id = tonumber(k)
        if id and id > 0 and id == math.floor(id) and v then out[id] = true end
    end
    return out
end

--- Per-category spell edits: [categoryKey] = { [spellId] = true (added) | false (removed) }. A key
--- that is not a spell category of this build is dropped, and an empty edit set is not stored.
---
--- A USER CATEGORY IS RECOGNIZED BY ITS STORED RECORD, NOT BY ITS DEFINITION (issue #10 checkpoint
--- 3), and the widening is a data-loss guard rather than a courtesy. This set is written WHOLE on
--- every edit of ANY category, so if a user key's definition were missing at the moment of one such
--- write -- a load-order slip, an error inside Cat.SyncUserCategories, a profile switch that half
--- ran -- that single unrelated write would permanently delete the player's entire spell list for
--- it. `Cat.HasUserRecord` asks the profile, which is the thing that cannot be half-built.
local function isEditableCategory(key)
    return NS.Categories.IsSpellCategory(key) or NS.Categories.HasUserRecord(key)
end

local function normalizeCategoryEdits(value)
    if type(value) ~= "table" then return nil, L["Expected per-category spell edits"] end
    local out = {}
    for key, edits in pairs(value) do
        if type(key) == "string" and isEditableCategory(key) and type(edits) == "table" then
            local e = {}
            for k, on in pairs(edits) do
                local id = tonumber(k)
                if id and id > 0 and id == math.floor(id) then e[id] = on and true or false end
            end
            if next(e) then out[key] = e end
        end
    end
    return out
end

-- The always/never lists are a container's. The spell-category edits are the profile's (schema v2:
-- one set every container shares), so theirs is an absolute path, resolved against the profile, and
-- its write announces no container id: every container re-applies.
local CARVE_OUTS = {
    ["container.filter.whitelist"] = normalizeIdSet,
    ["container.filter.blacklist"] = normalizeIdSet,
    ["categorySpells"]             = normalizeCategoryEdits,
}

-- ---------------------------------------------------------------------------
-- The bulk bracket (debug-logging-§10)
-- ---------------------------------------------------------------------------
--
-- A bulk copy or reset through the seam (a page's Defaults, Reset all, ContainerManager.CopyFrom,
-- ContainerManager.ResetPositions) is ONE `[Set] <act> <scope>: N rows` line, never a [Set] per
-- row. Validation, each row's onChange and CONFIG_CHANGED still run per write: only the log
-- collapses.
--
-- While a bracket is open, the seam's two log sites (announceWrite, logSection) are muted, and
-- each write tallies the rows it CHANGED at the moment it stores them. N is the rows the act
-- actually wrote, so a row already at its default is not counted, which is why N comes from here
-- and not from the library's bulkEnd `count` (that counts every applyDefault that returned).
-- Tallying at the store, before any onChange runs, keeps N equal to what was stored even when an
-- onChange raises. The mute is a depth counter: a bracket inside a bracket, such as a host act
-- wrapping a library reset, sums into the outer one, and the act logs once, when the depth returns
-- to 0. An act an error stopped still logs its one line, ending " (stopped by an error)". If any
-- level reports `info.profileReset`, AceDB replaced the profile whole and NS.OnProfileReset
-- (core/AuraMaster.lua) logs it, so the bracket logs nothing.
--
-- With LibKa0s, NS.Bulk is the Schema instance's own BulkBegin / BulkEnd / BulkRun, the tally is its
-- BulkAdd and the mute test its InBulk: the same contract, one copy of it in the collection. The host
-- bracket below is the library-absent arm, and it keeps the library's shape exactly, `info` included:
-- a Run act that reset the profile sets `info.profileReset = true`.
local bulk = { depth = 0, rows = 0, profileReset = false, failed = false }

local Bulk = {}

--- Open a bracket. The Options and Slash descriptors' `bulkBegin`.
function Bulk.Begin()
    if bulk.depth == 0 then bulk.rows, bulk.profileReset, bulk.failed = 0, false, false end
    bulk.depth = bulk.depth + 1
end

--- Close a bracket and, at depth 0, log the act's one line. The descriptors' `bulkEnd`. Its `count`
--- is ignored (see above). A non-nil `err` marks the line; re-raising it is the caller's job.
function Bulk.End(act, scope, _, err, info)
    if bulk.depth == 0 then return end
    bulk.depth = bulk.depth - 1
    if type(info) == "table" and info.profileReset then bulk.profileReset = true end
    if err ~= nil then bulk.failed = true end
    if bulk.depth > 0 or bulk.profileReset then return end
    if NS.Debug then
        NS.Debug("Set", "%s %s: %s rows%s", act, scope, bulk.rows, bulk.failed and " (stopped by an error)" or "")
    end
end

--- Run `fn(info)` as one bulk act under the bracket (CopyFrom, ResetPositions, the degraded Reset
--- all). A begun bracket always closes, so the mute cannot stick: `fn` runs under pcall, End runs
--- once, then an error is re-raised unchanged. `fn` sets `info.profileReset = true` when it reset
--- the profile (the library's BulkRun contract); what it returns is ignored.
function Bulk.Run(act, scope, fn)
    local info = { profileReset = false }
    Bulk.Begin()
    local ok, err = pcall(fn, info)
    local mark = nil
    if not ok then mark = err == nil and true or err end
    Bulk.End(act, scope, nil, mark, info)
    if not ok then error(err, 0) end
end

NS.Bulk = S and { Begin = S.BulkBegin, End = S.BulkEnd, Run = S.BulkRun } or Bulk

--- Whether a bulk bracket is open: the seam's mute test and its cue to tally.
local inBulk = S and S.InBulk or function() return bulk.depth > 0 end

-- Stored-value equality: `==` first, so -0 over 0 is no change, then tables by content, both
-- directions, recursively. With LibKa0s it is the library's SameValue; the host port below is the
-- library-absent arm and the same algorithm, so the two builds count the same N on the same act
-- (#21). The spell-id sets compare correctly by content because normalizeIdSet has integer-keyed
-- them before any write compares them.
local function hostSameValue(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do
        if not hostSameValue(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end
local SameValue = SchemaLib and SchemaLib.SameValue or hostSameValue

--- Whether storing `new` over `old` changes the stored value. This is the bracket's tally test.
--- CM.ResetPositions' stagger writes -0 for the first container, and SameValue's `==` calls that
--- no change, where FilterCompiler.Signature's tostring would not.
local function changes(old, new)
    return not SameValue(old, new)
end

--- Whether storing `value` in `row` changes it. A session row reads through its own get().
local function rowChanges(row, root, parts, first, value)
    if row.sessionOnly then return changes(row.get and row.get(), value) end
    return changes(readFrom(root, parts, first), value)
end

--- Inside a bracket, add `n` changed rows to the tally. Called where a write stores, so the tally
--- is what was stored. Outside a bracket it does nothing. With LibKa0s it is the instance's BulkAdd.
local function hostTally(n)
    if bulk.depth > 0 then bulk.rows = bulk.rows + n end
end
local tally = S and S.BulkAdd or hostTally

-- ---------------------------------------------------------------------------
-- The write seam
-- ---------------------------------------------------------------------------

--- The tail every write shares: log once, announce once, re-sync an open panel in place. A session
--- row announces nothing: it is not a setting, its own set() already did everything it does, and a
--- CONFIG_CHANGED would re-apply every container for a toggle that changes none of them.
--- `logged` says the caller already wrote the [Set] line (a section write renders its own).
local function announceWrite(section, containerId, path, value, sessionOnly, logged)
    -- Logged ONCE, here, with the format deferred into the sink (debug-logging-§10). Inside a bulk
    -- bracket it is muted: the write was tallied where it stored, and the act logs one line.
    if NS.Debug and not (logged or inBulk()) then NS.Debug("Set", "%s = %s", path, value) end
    -- The ONE sender of CONFIG_CHANGED (architecture-§4). `containerId` is nil for a global row;
    -- `path` lets modules/ContainerManager.lua read the row's `effect` and skip an apply it needs not.
    if NS.bus and not sessionOnly then
        NS.bus:SendMessage(NS.MSG.CONFIG_CHANGED,
            { section = section, containerId = containerId, path = path })
    end
    -- Scalar, never structural: rebuilding the page under a slider mid-drag is what writing a value
    -- emphatically does not need.
    local H = NS.Helpers
    if H and H.RefreshScalars then H.RefreshScalars() end
end

--- The minimap row: the one write in this schema that lands in `db.global`, and the one that
--- INVERTS (launcher-§3). It is a real write through this seam like every other row -- it tallies
--- inside a bulk bracket, it runs the row's onChange and it announces -- and it takes exactly two
--- liberties, both forced by whose key it is:
---
---   * it stores `not value`, because the row says SHOWN and LibDBIcon's key says HIDDEN; and
---   * it tells the launcher, so the button follows the checkbox NOW rather than at the next
---     reload. The store is written FIRST, so a SetShown that cannot reach LibDBIcon (no library,
---     a broker display only) still leaves the player's choice on disk.
---
--- Refused before the database exists rather than writing into a table AceDB is about to replace.
local function writeMinimap(value)
    local t = minimapStore()
    if not t then return false, L["Setting not found: %s"]:format(MINIMAP_PATH) end
    local row = findRow(MINIMAP_PATH)
    value = not not value
    local changed = inBulk() and t.hide ~= (not value)
    t.hide = not value
    if NS.Launcher then NS.Launcher:SetShown(value) end
    if changed then tally(1) end
    if row and row.onChange then row.onChange(value, nil) end
    announceWrite(row and row.page, nil, MINIMAP_PATH, value, false, false)
    return true
end

--- A carve-out: the whole set, normalized by its CARVE_OUTS entry, written, then announced.
local function writeCarveOut(path, value, containerId)
    local v, err = CARVE_OUTS[path](value)
    if not v then return false, err end
    local parts = splitPath(path)
    local root, first, id = resolveRoot(parts, containerId)
    if not root then return false, NO_CONTAINER end
    local changed = inBulk() and changes(readFrom(root, parts, first), v)
    writeInto(root, parts, first, v)
    if changed then tally(1) end
    announceWrite("filters", id, path, v, false, false)
    return true
end

-- The sections a caller may write whole, each with the CONFIG_CHANGED section it announces as.
-- `container.attach` is deliberately absent: no caller writes it whole.
local SECTIONS = {
    ["container.filter"]   = "filters",
    ["container.layout"]   = "layout",
    ["container.behavior"] = "layout",
    ["container.label"]    = "layout",
    ["container.position"] = "layout",
    ["container.bars"]     = "bars",
    ["container.icons"]    = "icons",
    ["container.text"]     = "text",
}

--- Whether `path` is one of the whole-section paths (a test seam: tests/test_schema.lua).
--- Test-only today: the only readers are tests/test_schema.lua:334-335,
--- tests/test_schema_paths.lua:438,443 and tests/test_anchors_label.lua:375. Kept deliberately; not a deletion candidate.
function NS.IsSection(path)
    return SECTIONS[path] ~= nil
end

local function isUnder(p, section)
    return p:sub(1, #section + 1) == section .. "."
end

--- Run every carve-out under `section` over its sub-key of `v`, in place. Returns an error or nil.
local function normalizeSectionCarveOuts(section, v, depth)
    for cpath, normalize in pairs(CARVE_OUTS) do
        if isUnder(cpath, section) then
            local cparts = splitPath(cpath)
            local n = normalize(readFrom(v, cparts, depth + 1))
            if not n then return L["Invalid value for %s"]:format(cpath) end
            writeInto(v, cparts, depth + 1, n)
        end
    end
    return nil
end

--- Validate every row under `section` against its leaf in `v`, each handed the target container's
--- id as a row write hands it. Returns an error or nil.
local function validateSectionRows(section, v, depth, id)
    for _, row in ipairs(NS.Schema) do
        if row.validate and isUnder(row.path, section)
            and not row.validate(readFrom(v, splitPath(row.path), depth + 1), id) then
            return L["Invalid value for %s"]:format(row.path)
        end
    end
    return nil
end

--- Run the `normalize(value, id)` hook of every row under `section` over its leaf of `v`, in place,
--- after validation — the order writeRow uses — so a section write stores what a row write would.
local function normalizeSectionRows(section, v, depth, id)
    for _, row in ipairs(NS.Schema) do
        if row.normalize and isUnder(row.path, section) then
            local parts = splitPath(row.path)
            writeInto(v, parts, depth + 1, row.normalize(readFrom(v, parts, depth + 1), id))
        end
    end
end

--- The onChange of every row under `section` whose leaf actually changed between `old` and `v`.
local function fireSectionChanges(section, old, v, depth, id)
    local Sig = NS.FilterCompiler.Signature
    for _, row in ipairs(NS.Schema) do
        if row.onChange and isUnder(row.path, section) then
            local parts = splitPath(row.path)
            local leaf = readFrom(v, parts, depth + 1)
            local was = readFrom(old, parts, depth + 1)
            if Sig(was) ~= Sig(leaf) then row.onChange(leaf, id, was) end
        end
    end
end

--- `{k=v, sub={...}}` with sorted keys: what a section write's [Set] line shows.
local function renderSection(v)
    local keys = {}
    for k in pairs(v) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for i, k in ipairs(keys) do
        local x = v[k]
        keys[i] = tostring(k) .. "=" .. (type(x) == "table" and "{...}" or tostring(x))
    end
    return "{" .. table.concat(keys, ", ") .. "}"
end

--- Whether the leaf at `p` differs between two copies of a section, `depth` deep.
local function leafChanged(p, old, v, depth)
    local parts = splitPath(p)
    return changes(readFrom(old, parts, depth + 1), readFrom(v, parts, depth + 1))
end

--- How many rows, and spell-set carve-outs, under `section` differ between `old` and `v`. This is
--- what a section write counts inside a bulk bracket.
local function countSectionChanges(section, old, v, depth)
    if type(old) ~= "table" then old = {} end
    local n = 0
    for _, row in ipairs(NS.Schema) do
        if isUnder(row.path, section) and leafChanged(row.path, old, v, depth) then n = n + 1 end
    end
    for cpath in pairs(CARVE_OUTS) do
        if isUnder(cpath, section) and leafChanged(cpath, old, v, depth) then n = n + 1 end
    end
    return n
end

--- The section's one [Set] line, built only when the debug flag is on (debug-logging-§4, §9).
--- Inside a bulk bracket it logs nothing: writeSection tallied the write where it stored.
local function logSection(path, v)
    if inBulk() then return end
    if NS.State and NS.State.debug and NS.Debug then
        NS.Debug("Set", "%s = %s", path, renderSection(v))
    end
end

--- The checks a whole-section write runs before it stores anything: a deep copy of `value`,
--- backfilled, carve-outs normalized, rows validated. Returns the copy, the root, the path's parts,
--- the first index and the container id — or nil and the refusal. Nothing is stored.
local function prepareSection(path, value, containerId)
    if type(value) ~= "table" then return nil, L["Invalid value for %s"]:format(path) end
    local parts = splitPath(path)
    local root, first, id = resolveRoot(parts, containerId)
    if not root then return nil, NO_CONTAINER end
    local v = copy(value)
    NS.Database.Backfill(v, readFrom(NS.CONTAINER_TEMPLATE, parts, 2))
    local depth = #parts
    local err = normalizeSectionCarveOuts(path, v, depth) or validateSectionRows(path, v, depth, id)
    if err then return nil, err end
    return v, root, parts, first, id
end

--- A whole section: prepareSection's checked copy, its rows normalized, then stored in one write.
--- All or nothing: nothing is stored unless every check passes.
local function writeSection(path, value, containerId, sec)
    local v, root, parts, first, id = prepareSection(path, value, containerId)
    if not v then return false, root end   -- `root` carries the refusal here
    local depth = #parts
    normalizeSectionRows(path, v, depth, id)
    local old = readFrom(root, parts, first)
    writeInto(root, parts, first, v)
    if inBulk() then tally(countSectionChanges(path, old, v, depth)) end
    fireSectionChanges(path, old, v, depth, id)
    logSection(path, v)
    announceWrite(sec, id, path, nil, false, true)
    return true
end

--- What `row` holds before a write: the stored leaf, or a session row's own get(). Handed to the
--- row's `onChange` as its third argument, so a reaction can tell a real change from a re-write of
--- the same value (the Style row's Fill reset, B5).
local function previousValue(row, root, parts, first)
    if row.sessionOnly then return row.get and row.get() end
    return readFrom(root, parts, first)
end

--- A schema row's storage step: resolve the container, validate the raw value, normalize, store.
--- `row.validate(value, id)` and the optional `row.normalize(value, id)` are both handed the id the
--- write targets (nil for a global or session row, or when no container resolves), so a row can
--- check or rewrite a value against ITS container: the attach row refuses a loop from the container
--- written, the name row makes a name unique. A bad value is refused before a missing container, so
--- the refusal names the value. A `validate` may answer false AND a reason (the Text template's
--- parser does); the reason travels on as the refusal's third return. It returns ok, err|nil, a third
--- slot that is the container id on success and the row's refusal reason (or nil) on a refusal, then
--- the value as stored and the value it replaced (what onChange and the announcement see).
--- Inside a bulk bracket it tallies the row here, once stored, so an onChange that raises
--- afterwards cannot drop a stored write from the count.
local function writeRow(row, path, value, containerId)
    local parts, root, first, id
    if not row.sessionOnly then
        parts = splitPath(path)
        root, first, id = resolveRoot(parts, containerId)
    end
    if row.validate then
        local ok, why = row.validate(value, id)
        if not ok then return false, L["Invalid value for %s"]:format(path), why end
    end
    if parts and not root then return false, NO_CONTAINER end
    if row.normalize then value = row.normalize(value, id) end
    local changed = inBulk() and rowChanges(row, root, parts, first, value)
    local old = previousValue(row, root, parts, first)
    if row.sessionOnly then
        -- No database write by definition; the row's own set() IS its storage.
        if row.set then row.set(value) end
    else
        -- copy() on the way in: a color table handed straight from a widget or from a row's
        -- default would otherwise be shared, and editing one container would edit another.
        writeInto(root, parts, first, copy(value))
    end
    if changed then tally(1) end
    return true, nil, id, value, old
end

--- A declared NS.WRITE_THROUGH path with no row (the library-absent build): stored raw, a copy, with
--- no validate, normalize or onChange because there is no row to carry them; tallied inside a
--- bracket, logged and announced like any other write. The caller reacts (settings/Slash.lua's
--- runEnabled syncs the latch). Mirrors LibKa0s-Schema's writeThrough rows for this addon's seam.
local function writeThrough(path, value, containerId)
    local parts = splitPath(path)
    local root, first = resolveRoot(parts, containerId)
    if not root then return false, L["Setting not found: %s"]:format(path) end
    local changed = inBulk() and changes(readFrom(root, parts, first), value)
    writeInto(root, parts, first, copy(value))
    if changed then tally(1) end
    announceWrite(nil, nil, path, value, false, false)
    return true
end

--- Write one setting. THE single write seam: the panel's widgets, `/am set`, `/am reset`, the
--- Defaults buttons and a drag handle all land here. `containerId` targets a specific container
--- instead of the active one.
---
--- Order is load-bearing: resolve, validate against the resolved container, normalize, write, react,
--- log once, announce. A bad value is refused before a missing container. Reacting before the write
--- would hand a reactor the old value; logging in the reactor would log it once per subscriber.
--- A refused row write may carry a third return, the row's own reason (the Text template's parser
--- message), which the panel and `/am set` print under `err` (settings/OptionsSetup.lua,
--- settings/Slash.lua).
--- @return boolean ok, string|nil err, string|nil why
function NS.SetByPath(path, value, containerId)
    if type(path) ~= "string" then return false, L["Setting not found: %s"]:format(tostring(path)) end
    if path == MINIMAP_PATH then return writeMinimap(value) end
    if CARVE_OUTS[path] then return writeCarveOut(path, value, containerId) end
    local sec = SECTIONS[path]
    if sec then return writeSection(path, value, containerId, sec) end

    local row = findRow(path)
    if not row then
        if NS.WRITE_THROUGH[path] then return writeThrough(path, value, containerId) end
        return false, L["Setting not found: %s"]:format(path)
    end
    local ok, err, id, stored, old = writeRow(row, path, value, containerId)
    if not ok then return false, err, id end

    if row.onChange then row.onChange(stored, id, old) end
    announceWrite(row.page, id, path, stored, row.sessionOnly, false)
    return true
end

--- Whether a spell set would be stored: the carve-out's normalizer accepts it and the container exists.
local function checkCarveOut(path, value, containerId)
    local v, err = CARVE_OUTS[path](value)
    if not v then return false, err end
    if not resolveRoot(splitPath(path), containerId) then return false, NO_CONTAINER end
    return true
end

--- Whether a row write would be stored: the row exists, its validate accepts the value (handed the id
--- the write targets, as writeRow hands it), and (for a stored row) the container exists. A row's
--- normalize never refuses, so it is not run.
local function checkRow(path, value, containerId)
    local row = findRow(path)
    if not row then
        -- A row-less write-through path is stored whenever its root resolves, as NS.SetByPath stores it.
        if NS.WRITE_THROUGH[path] and resolveRoot(splitPath(path), containerId) then return true end
        return false, L["Setting not found: %s"]:format(path)
    end
    local root, id
    if not row.sessionOnly then
        local _
        root, _, id = resolveRoot(splitPath(path), containerId)
    end
    if row.validate then
        local ok, why = row.validate(value, id)
        if not ok then return false, L["Invalid value for %s"]:format(path), why end
    end
    if not row.sessionOnly and not root then return false, NO_CONTAINER end
    return true
end

--- Whether NS.SetByPath(path, value, containerId) would store the value: the same checks, run on a
--- copy, with nothing stored, no onChange and nothing announced. Not a second write seam — it
--- writes nothing. It lets a caller that writes several paths as one act (ContainerManager.CopyFrom)
--- refuse all of them when any one would be refused. A refused row check carries the row's own
--- reason as the third return, as NS.SetByPath's does.
--- @return boolean ok, string|nil err, string|nil why
function NS.CheckWrite(path, value, containerId)
    if type(path) ~= "string" then return false, L["Setting not found: %s"]:format(tostring(path)) end
    -- Stored once the database exists; the value is a bool and nothing about it can be refused.
    if path == MINIMAP_PATH then
        if not minimapStore() then return false, L["Setting not found: %s"]:format(MINIMAP_PATH) end
        return true
    end
    if CARVE_OUTS[path] then return checkCarveOut(path, value, containerId) end
    if SECTIONS[path] then
        local v, err = prepareSection(path, value, containerId)
        if not v then return false, err end
        return true
    end
    return checkRow(path, value, containerId)
end

--- Restore one row to its shipped default, through the same seam everything else writes through.
--- A row flagged `noReset` has no meaningful default (a container's name): no reset restores it —
--- not a page's Defaults, not `/am reset` — and it answers false, which `/am reset` prints as the
--- library's NO_DEFAULT line. Its template value still backfills a new container.
--- @return boolean|nil ok, string|nil err, string|nil why
function NS.ApplyDefault(row)
    if type(row) ~= "table" or row.path == nil then return false end
    if row.noReset then return false end
    if row.default == nil then return false end
    return NS.SetByPath(row.path, copy(row.default))
end

-- ---------------------------------------------------------------------------
-- Dropdown values
-- ---------------------------------------------------------------------------

--- An ordered `{ value, text }` list from one of core/Constants.lua's key arrays and its labels,
--- localized. The ordered-array shape keeps the declared order in the dropdown.
function NS.Choices(keys, labels)
    local out = {}
    for i, k in ipairs(keys) do out[i] = { value = k, text = L[labels[k] or tostring(k)] } end
    return out
end

-- ---------------------------------------------------------------------------
-- Validation
-- ---------------------------------------------------------------------------

local VALID_PAGES = {
    general = true, containers = true, filters = true, layout = true, bars = true, icons = true,
    text = true, profiles = true,
}
local VALID_TYPES = { bool = true, number = true, string = true, color = true }

--- Where a row's path resolves in the defaults, for the library's Validate: the container template
--- for a `container.` row, the global defaults for a `global.` row, the profile defaults otherwise.
--- The minimap row answers through NS.DefaultFor, because its path is a name and not the stored key
--- (the stored key is LibDBIcon's inverted `hide`), so it is handed a one-key root holding the
--- inverted default, read at the path's last segment. An automatic row (`nilAs`) is handed the same
--- one-key root holding its `nilAs`: the template declares no key for it, by design.
local function defaultsRoot(parts, row)
    if row.path == MINIMAP_PATH then
        local last = #parts
        return { [parts[last]] = NS.DefaultFor(MINIMAP_PATH) }, last
    end
    if row.nilAs ~= nil then
        local last = #parts
        return { [parts[last]] = row.nilAs }, last
    end
    local defaults = NS.defaults
    if parts[1] == CONTAINER then return NS.CONTAINER_TEMPLATE, 2 end
    if parts[1] == "global" then return defaults, 1 end
    return defaults and defaults.profile, 1
end

--- Prove the schema against the defaults. Returns the number of failing rows — 0 on a healthy
--- load, which is what the headless suite asserts. With LibKa0s it is the instance's Validate (its
--- shape errors plus its unresolved paths, a duplicate path included); the loop below is the
--- library-absent arm.
---
--- Four checks per row: a known `page` and `type`, a `group` (a row without one belongs to no tab,
--- options-ui-§13), and — unless session-only — a `path` that resolves against the container
--- template or the profile defaults. A path that does not resolve is a setting whose writes land
--- on a key nothing reads, and nothing anywhere would say so.
--- And a path no earlier row holds: NS.FindSchemaRow answers the first of two, so the second is dead.
--- @return number
function NS.ValidateSchema()
    if S then
        local errors, _, missing = S.Validate({
            types = VALID_TYPES, pages = VALID_PAGES, defaultsRoot = defaultsRoot,
        })
        return errors + missing
    end
    local out = NS.Print
    local failed = 0
    local function fail(row, why)
        failed = failed + 1
        if out then out(("schema error: %s: %s"):format(tostring(row.path), why)) end
    end
    local seen = {}
    for i, row in ipairs(NS.Schema) do
        if not VALID_PAGES[row.page] then fail(row, "unknown page " .. tostring(row.page)) end
        if not VALID_TYPES[row.type] then fail(row, "unknown type " .. tostring(row.type)) end
        if type(row.group) ~= "string" or row.group == "" then fail(row, "no group") end
        local path = row.path
        if type(path) == "string" and path ~= "" then
            if seen[path] then
                fail(row, ("duplicate path (first used by row #%d)"):format(seen[path]))
            else
                seen[path] = i
            end
        end
        if not row.sessionOnly and NS.DefaultFor(row.path) == nil then
            fail(row, "path does not resolve against defaults/Profile.lua")
        end
    end
    return failed
end
