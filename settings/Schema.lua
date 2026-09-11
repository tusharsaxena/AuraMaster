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
    for segment in tostring(path):gmatch("[^%.]+") do parts[#parts + 1] = segment end
    splitCache[path] = parts
    return parts
end

local function readFrom(root, parts, first)
    local node = root
    for i = first, #parts do
        if type(node) ~= "table" then return nil end
        node = node[parts[i]]
    end
    return node
end

local function writeInto(root, parts, first, value)
    local node = root
    for i = first, #parts - 1 do
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
    if type(value) ~= "table" then return nil, "expected a set of spell ids" end
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
    if type(value) ~= "table" then return nil, "expected per-category spell edits" end
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

--- Whether `path` is one of the whole-set carve-outs (a test seam and a CLI aid).
function NS.IsCarveOut(path)
    return CARVE_OUTS[path] ~= nil
end

-- ---------------------------------------------------------------------------
-- The write seam
-- ---------------------------------------------------------------------------

--- The tail every write shares: log once, announce once, re-sync an open panel in place. A session
--- row announces nothing: it is not a setting, its own set() already did everything it does, and a
--- CONFIG_CHANGED would re-apply every container for a toggle that changes none of them.
local function announceWrite(section, containerId, path, value, sessionOnly)
    -- Logged ONCE, here, with the format deferred into the sink (debug-logging-§10).
    if NS.Debug then NS.Debug("Set", "%s = %s", path, value) end
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

--- Write one setting. THE single write seam: the panel's widgets, `/am set`, `/am reset`, the
--- Defaults buttons and a drag handle all land here. `containerId` targets a specific container
--- instead of the active one.
---
--- Order is load-bearing: write, react, log once, announce. Reacting before the write would hand a
--- reactor the old value; logging in the reactor would log it once per subscriber.
--- @return boolean ok, string|nil err
function NS.SetByPath(path, value, containerId)
    if type(path) ~= "string" then return false, L["Setting not found: %s"]:format(tostring(path)) end

    local normalize = CARVE_OUTS[path]
    if normalize then
        local v, err = normalize(value)
        if not v then return false, err end
        local parts = splitPath(path)
        local root, first, id = resolveRoot(parts, containerId)
        if not root then return false, NO_CONTAINER end
        writeInto(root, parts, first, v)
        announceWrite("filters", id, path, v, false)
        return true
    end

    local row = index[path]
    if not row then return false, L["Setting not found: %s"]:format(path) end
    if row.validate and not row.validate(value) then
        return false, L["Invalid value for %s"]:format(path)
    end

    local id
    if row.sessionOnly then
        -- No database write by definition; the row's own set() IS its storage.
        if row.set then row.set(value) end
    else
        local parts = splitPath(path)
        local root, first, rid = resolveRoot(parts, containerId)
        if not root then return false, NO_CONTAINER end
        id = rid
        -- copy() on the way in: a color table handed straight from a widget or from a row's
        -- default would otherwise be shared, and editing one container would edit another.
        writeInto(root, parts, first, copy(value))
    end

    if row.onChange then row.onChange(value, id) end
    announceWrite(row.page, id, path, value, row.sessionOnly)
    return true
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
