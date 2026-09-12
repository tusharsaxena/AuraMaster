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

NS.Schema = NS.Schema or {}

local CONTAINER = "container"
local L = NS.L
local NO_CONTAINER = L["No container exists yet — create one on the Containers page."]

-- ---------------------------------------------------------------------------
-- Path plumbing
-- ---------------------------------------------------------------------------

-- Memoized: the set of paths is closed (the schema's own plus whatever the CLI is handed), while a
-- slider drag re-resolves one path many times a second.
local splitCache = {}

local function splitPath(path)
    local parts = splitCache[path]
    if parts then return parts end
    parts = {}
    for segment in tostring(path):gmatch("[^%.]+") do
        parts[#parts + 1] = segment
    end
    splitCache[path] = parts
    return parts
end

local function readFrom(root, parts, first)
    local node = root
    local last = #parts
    for i = first, last do
        if type(node) ~= "table" then return nil end
        node = node[parts[i]]
    end
    return node
end

local function writeInto(root, parts, first, value)
    local node = root
    local last = #parts - 1
    for i = first, last do
        local key = parts[i]
        if type(node[key]) ~= "table" then node[key] = {} end
        node = node[key]
    end
    node[parts[#parts]] = value
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

--- The shipped default for `path` — from the container template for a `container.` path, from the
--- profile defaults otherwise. A deep copy, so a caller can never mutate the template.
function NS.DefaultFor(path)
    local parts = splitPath(path)
    if parts[1] == CONTAINER then
        return copy(readFrom(NS.CONTAINER_TEMPLATE, parts, 2))
    end
    return copy(readFrom(NS.defaults and NS.defaults.profile, parts, 1))
end

-- ---------------------------------------------------------------------------
-- The index and registration
-- ---------------------------------------------------------------------------

local index = {}

local function reindex()
    for k in pairs(index) do index[k] = nil end
    for _, row in ipairs(NS.Schema) do index[row.path] = row end
end

function NS.FindSchemaRow(path)
    if type(path) ~= "string" then return nil end
    return index[path]
end

--- Append a page's rows. Every non-session row's `default` is stamped from defaults/Profile.lua
--- here, overwriting whatever a composer supplied, so the one hardcoded default is the template's.
function NS.RegisterSchemaRows(rows)
    if type(rows) ~= "table" then return end
    for _, row in ipairs(rows) do
        if not row.sessionOnly and type(row.path) == "string" then
            local d = NS.DefaultFor(row.path)
            if d ~= nil then row.default = d end
        end
        NS.Schema[#NS.Schema + 1] = row
    end
    reindex()
end

--- Whether `row` applies to container `cfg`. A row may name the aura types it means something for
--- (`auraTypes = { HELPFUL = true }`): the buff categories are not offered on a debuff container.
local function rowApplies(row, cfg)
    if row.auraTypes then
        return cfg ~= nil and row.auraTypes[cfg.auraType] == true
    end
    return true
end

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
    local row = index[path]
    if row and row.sessionOnly then
        if row.get then return row.get() end
        return nil
    end
    local parts = splitPath(path)
    local root, first = resolveRoot(parts, containerId)
    if not root then return nil end
    return readFrom(root, parts, first)
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
local function normalizeCategoryEdits(value)
    if type(value) ~= "table" then return nil, L["Expected per-category spell edits"] end
    local out = {}
    for key, edits in pairs(value) do
        if type(key) == "string" and NS.Categories.IsSpellCategory(key) and type(edits) == "table" then
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

local CARVE_OUTS = {
    ["container.filter.whitelist"]      = normalizeIdSet,
    ["container.filter.blacklist"]      = normalizeIdSet,
    ["container.filter.categorySpells"] = normalizeCategoryEdits,
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
local bulk = { depth = 0, rows = 0, profileReset = false, failed = false }

local Bulk = {}
NS.Bulk = Bulk

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

--- Run `fn` as one bulk act under the host's own bracket (CopyFrom, ResetPositions, the degraded
--- Reset all). A begun bracket always closes, so the mute cannot stick: `fn` runs under pcall, End
--- runs once, then an error is re-raised unchanged. `fn` returns true when it reset the profile.
function Bulk.Run(act, scope, fn)
    local info = { profileReset = false }
    Bulk.Begin()
    local ok, err = pcall(function() info.profileReset = fn() == true end)
    Bulk.End(act, scope, nil, err, info)
    if not ok then error(err, 0) end
end

--- Whether storing `new` over `old` changes the stored value. This is the bracket's tally test.
--- Numbers compare by `==`, so -0 over 0 is no change; Signature's tostring would call them
--- different, and CM.ResetPositions' stagger writes -0 for the first container.
local function changes(old, new)
    if type(old) == "number" and type(new) == "number" then return old ~= new end
    local Sig = NS.FilterCompiler.Signature
    return Sig(old) ~= Sig(new)
end

--- Whether storing `value` in `row` changes it. A session row reads through its own get().
local function rowChanges(row, root, parts, first, value)
    if row.sessionOnly then return changes(row.get and row.get(), value) end
    return changes(readFrom(root, parts, first), value)
end

--- Inside a bracket, add `n` changed rows to the tally. Called where a write stores, so the tally
--- is what was stored. Outside a bracket it does nothing.
local function tally(n)
    if bulk.depth > 0 then bulk.rows = bulk.rows + n end
end

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
    if NS.Debug and not (logged or bulk.depth > 0) then NS.Debug("Set", "%s = %s", path, value) end
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

--- A carve-out: the whole set, normalized by its CARVE_OUTS entry, written, then announced.
local function writeCarveOut(path, value, containerId)
    local v, err = CARVE_OUTS[path](value)
    if not v then return false, err end
    local parts = splitPath(path)
    local root, first, id = resolveRoot(parts, containerId)
    if not root then return false, NO_CONTAINER end
    local changed = bulk.depth > 0 and changes(readFrom(root, parts, first), v)
    writeInto(root, parts, first, v)
    if changed then tally(1) end
    announceWrite("filters", id, path, v, false, false)
    return true
end

-- The sections a caller may write whole, each with the CONFIG_CHANGED section it announces as.
-- `container.attach` is deliberately absent: no caller writes it whole, and its `.container`
-- validator checks cycles against the ACTIVE container, not the target id.
local SECTIONS = {
    ["container.filter"]   = "filters",
    ["container.layout"]   = "layout",
    ["container.behavior"] = "layout",
    ["container.position"] = "layout",
    ["container.bars"]     = "bars",
    ["container.icons"]    = "icons",
}

--- Whether `path` is one of the whole-section paths (a test seam: tests/test_schema.lua).
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

--- Validate every row under `section` against its leaf in `v`. Returns an error or nil.
local function validateSectionRows(section, v, depth)
    for _, row in ipairs(NS.Schema) do
        if row.validate and isUnder(row.path, section)
            and not row.validate(readFrom(v, splitPath(row.path), depth + 1)) then
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
            if Sig(readFrom(old, parts, depth + 1)) ~= Sig(leaf) then row.onChange(leaf, id) end
        end
    end
end

--- `{k=v, sub={…}}` with sorted keys: what a section write's [Set] line shows.
local function renderSection(v)
    local keys = {}
    for k in pairs(v) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for i, k in ipairs(keys) do
        local x = v[k]
        keys[i] = tostring(k) .. "=" .. (type(x) == "table" and "{…}" or tostring(x))
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
    if bulk.depth > 0 then return end
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
    local err = normalizeSectionCarveOuts(path, v, depth) or validateSectionRows(path, v, depth)
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
    if bulk.depth > 0 then tally(countSectionChanges(path, old, v, depth)) end
    fireSectionChanges(path, old, v, depth, id)
    logSection(path, v)
    announceWrite(sec, id, path, nil, false, true)
    return true
end

--- A schema row's storage step: validate the raw value, resolve the container, normalize, store.
--- `row.normalize(value, id)` is an optional hook that runs after the id is known, so a row can
--- rewrite a valid value against its container (the name row makes it unique). It returns ok,
--- err|nil, the container id, and the value as stored (what onChange and the announcement see).
--- Inside a bulk bracket it tallies the row here, once stored, so an onChange that raises
--- afterwards cannot drop a stored write from the count.
local function writeRow(row, path, value, containerId)
    if row.validate and not row.validate(value) then
        return false, L["Invalid value for %s"]:format(path)
    end
    local parts, root, first, id
    if not row.sessionOnly then
        parts = splitPath(path)
        root, first, id = resolveRoot(parts, containerId)
        if not root then return false, NO_CONTAINER end
    end
    if row.normalize then value = row.normalize(value, id) end
    local changed = bulk.depth > 0 and rowChanges(row, root, parts, first, value)
    if row.sessionOnly then
        -- No database write by definition; the row's own set() IS its storage.
        if row.set then row.set(value) end
    else
        -- copy() on the way in: a color table handed straight from a widget or from a row's
        -- default would otherwise be shared, and editing one container would edit another.
        writeInto(root, parts, first, copy(value))
    end
    if changed then tally(1) end
    return true, nil, id, value
end

--- Write one setting. THE single write seam: the panel's widgets, `/am set`, `/am reset`, the
--- Defaults buttons and a drag handle all land here. `containerId` targets a specific container
--- instead of the active one.
---
--- Order is load-bearing: validate, resolve, normalize, write, react, log once, announce. Reacting
--- before the write would hand a reactor the old value; logging in the reactor would log it once
--- per subscriber.
--- @return boolean ok, string|nil err
function NS.SetByPath(path, value, containerId)
    if type(path) ~= "string" then return false, L["Setting not found: %s"]:format(tostring(path)) end
    if CARVE_OUTS[path] then return writeCarveOut(path, value, containerId) end
    local sec = SECTIONS[path]
    if sec then return writeSection(path, value, containerId, sec) end

    local row = index[path]
    if not row then return false, L["Setting not found: %s"]:format(path) end
    local ok, err, id, stored = writeRow(row, path, value, containerId)
    if not ok then return false, err end

    if row.onChange then row.onChange(stored, id) end
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

--- Whether a row write would be stored: the row exists, its validate accepts the value, and (for a
--- stored row) the container exists. A row's normalize never refuses, so it is not run.
local function checkRow(path, value, containerId)
    local row = index[path]
    if not row then return false, L["Setting not found: %s"]:format(path) end
    if row.validate and not row.validate(value) then
        return false, L["Invalid value for %s"]:format(path)
    end
    if not row.sessionOnly and not resolveRoot(splitPath(path), containerId) then
        return false, NO_CONTAINER
    end
    return true
end

--- Whether NS.SetByPath(path, value, containerId) would store the value: the same checks, run on a
--- copy, with nothing stored, no onChange and nothing announced. Not a second write seam — it
--- writes nothing. It lets a caller that writes several paths as one act (ContainerManager.CopyFrom)
--- refuse all of them when any one would be refused.
--- @return boolean ok, string|nil err
function NS.CheckWrite(path, value, containerId)
    if type(path) ~= "string" then return false, L["Setting not found: %s"]:format(tostring(path)) end
    if CARVE_OUTS[path] then return checkCarveOut(path, value, containerId) end
    if SECTIONS[path] then
        local v, err = prepareSection(path, value, containerId)
        if not v then return false, err end
        return true
    end
    return checkRow(path, value, containerId)
end

--- Restore one row to its shipped default, through the same seam everything else writes through.
function NS.ApplyDefault(row)
    if type(row) ~= "table" or row.path == nil or row.default == nil then return end
    NS.SetByPath(row.path, copy(row.default))
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
    profiles = true,
}
local VALID_TYPES = { bool = true, number = true, string = true, color = true }

--- Prove the schema against the defaults. Returns the number of failing rows — 0 on a healthy
--- load, which is what the headless suite asserts.
---
--- Three checks per row: a known `page` and `type`, a `group` (a row without one belongs to no tab,
--- options-ui-§13), and — unless session-only — a `path` that resolves against the container
--- template or the profile defaults. A path that does not resolve is a setting whose writes land
--- on a key nothing reads, and nothing anywhere would say so.
--- @return number
function NS.ValidateSchema()
    local out = NS.Print
    local failed = 0
    local function fail(row, why)
        failed = failed + 1
        if out then out(("schema error: %s: %s"):format(tostring(row.path), why)) end
    end
    for _, row in ipairs(NS.Schema) do
        if not VALID_PAGES[row.page] then fail(row, "unknown page " .. tostring(row.page)) end
        if not VALID_TYPES[row.type] then fail(row, "unknown type " .. tostring(row.type)) end
        if type(row.group) ~= "string" or row.group == "" then fail(row, "no group") end
        if not row.sessionOnly and NS.DefaultFor(row.path) == nil then
            fail(row, "path does not resolve against defaults/Profile.lua")
        end
    end
    return failed
end
