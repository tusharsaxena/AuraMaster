-- tests/settings_pin_snapshot.lua — the stored-settings snapshot tests/test_settings_pin.lua compares
-- against tests/settings_pin.lua (item 020, AM-LY): one line per schema row naming its stored path,
-- type, shipped default, range and choice keys, and one line per leaf of the shipped profile defaults
-- and the container template. A settings-LAYOUT change moves, regroups and relabels rows; it never
-- changes one of these, so any difference here is a key, default, range or choice-set drift.
--
-- Not a suite (tests/run.lua does not list it): a helper the pin suite dofiles.

--- A deterministic rendering of `v`: tables with their keys sorted, functions as "fn".
local function render(v)
    local t = type(v)
    if t == "table" then
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        local parts = {}
        for i, k in ipairs(keys) do parts[i] = tostring(k) .. "=" .. render(v[k]) end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    if t == "function" then return "fn" end
    if t == "string" then return ("%q"):format(v) end
    return tostring(v)
end

--- The keys of a row's `values` (a table, or a function the page builds the list from).
local function choiceKeys(values)
    if type(values) ~= "table" then return values and "fn" or "-" end
    local keys = {}
    for k in pairs(values) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    return table.concat(keys, "|")
end

--- Every leaf under `t` as "<prefix><path>=<value>", appended to `out`.
local function leaves(t, prefix, out)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
        local v, p = t[k], prefix .. tostring(k)
        if type(v) == "table" and next(v) ~= nil then
            leaves(v, p .. ".", out)
        else
            out[#out + 1] = p .. "=" .. render(v)
        end
    end
end

return function(NS)
    local out = {}
    for _, row in ipairs(NS.Schema) do
        if type(row.path) == "string" then
            out[#out + 1] = ("row %s type=%s default=%s min=%s max=%s step=%s values=%s session=%s"):format(
                row.path, tostring(row.type), render(row.default), tostring(row.min), tostring(row.max),
                tostring(row.step), choiceKeys(row.values), tostring(row.sessionOnly and true or false))
        end
    end
    table.sort(out)
    local defaults = {}
    leaves(NS.defaults and NS.defaults.profile or {}, "profile.", defaults)
    leaves(NS.defaults and NS.defaults.global or {}, "global.", defaults)
    leaves(NS.CONTAINER_TEMPLATE or {}, "container.", defaults)
    for _, line in ipairs(defaults) do out[#out + 1] = "default " .. line end
    return out
end
