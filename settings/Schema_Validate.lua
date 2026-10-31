local _, NS = ...

-- settings/Schema_Validate.lua — proves the schema against the defaults at load (NS.ValidateSchema).
-- Peeled out of settings/Schema.lua, which loads first and owns the rows and the runtime.

local S = NS.SchemaRuntime
local MINIMAP_PATH = NS.MINIMAP_PATH
local CONTAINER = "container"

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
