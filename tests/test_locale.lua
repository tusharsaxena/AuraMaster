-- tests/test_locale.lua — locales/enUS.lua carries every string the addon routes through NS.L, and
-- nothing it does not (localization-§1/§3).
--
-- Two directions, both read out of the source rather than out of NS.L: the metatable answers the
-- key for ANY lookup, so `NS.L[anything]` is truthy and a case built on it would assert nothing.
--
--   * every `L["…"]` subscript in core/, modules/, settings/ and defaults/ is defined in enUS.lua;
--   * every key enUS.lua defines is used — either as a literal subscript, or as a string routed by
--     VALUE (a Constants label table, a category label or description, a filter warning), which is
--     found as a string literal somewhere in the addon's own source.

local T = _G.AM_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function readFile(path)
    local f = io.open(path, "r")
    assertTrue(f ~= nil, "cannot open " .. path)
    local s = f:read("*a")
    f:close()
    return s
end

local function sources()
    local out, p = {}, io.popen("ls -1 core/*.lua modules/*.lua settings/*.lua defaults/*.lua 2>/dev/null")
    for line in p:lines() do
        out[#out + 1] = line
    end
    p:close()
    return out
end

local function defined()
    local keys, n = {}, 0
    for key in readFile("locales/enUS.lua"):gmatch('\nL%["(.-)"%] = ') do
        keys[key] = true
        n = n + 1
    end
    return keys, n
end

test("locale: every L[...] subscript in the source is defined in enUS.lua", function()
    local keys, n = defined()
    assertTrue(n > 200, "read only " .. n .. " keys out of enUS.lua")
    local missing = {}
    for _, path in ipairs(sources()) do
        for key in readFile(path):gmatch('%f[%w_]L%[%s*"(.-)"%s*%]') do
            if not keys[key] then
                missing[#missing + 1] = path .. ": " .. key
            end
        end
    end
    assertEqual(#missing, 0, "used but not defined: " .. table.concat(missing, "; "))
end)

test("locale: every key enUS.lua defines is used somewhere in the source", function()
    local keys = defined()
    local corpus = {}
    for _, path in ipairs(sources()) do
        corpus[#corpus + 1] = readFile(path)
    end
    local all = table.concat(corpus, "\n")
    local dead = {}
    for key in pairs(keys) do
        if not all:find('"' .. key .. '"', 1, true) then
            dead[#dead + 1] = key
        end
    end
    table.sort(dead)
    assertEqual(#dead, 0, "defined but never used: " .. table.concat(dead, "; "))
end)

--- Every `L[...] = ...` line of enUS.lua as { key, value, line }; `value` is nil where the right-hand
--- side is not one plain string literal.
local function definitions()
    local out, n = {}, 0
    for line in readFile("locales/enUS.lua"):gmatch("[^\n]+") do
        n = n + 1
        line = line:gsub("\r$", "")
        if line:find('^L%[') then
            local key, value = line:match('^L%["(.-)"%] = "(.*)"$')
            local def = { key = key or line, value = value, line = n }
            out[#out + 1] = def
        end
    end
    return out
end

test("locale: no key is defined twice in enUS.lua", function()
    local seen, dupes = {}, {}
    for _, d in ipairs(definitions()) do
        if seen[d.key] then
            dupes[#dupes + 1] = ("%s (lines %d and %d)"):format(d.key, seen[d.key], d.line)
        end
        seen[d.key] = seen[d.key] or d.line
    end
    -- red under: a second definition of a key (the later one silently wins)
    assertEqual(#dupes, 0, table.concat(dupes, "; "))
end)

test("locale: every enUS value is its own key, so the English build shows the source string", function()
    local drift = {}
    for _, d in ipairs(definitions()) do
        if d.value ~= d.key then
            drift[#drift + 1] = ("line %d: %s"):format(d.line, d.key)
        end
    end
    -- red under: an English value edited away from its key (localization-§2: the key IS the
    -- English source string, and a translator copies this file)
    assertEqual(#drift, 0, table.concat(drift, "; "))
end)

test("locale: every string routed by value has its key — Constants labels, categories, filter warnings", function()
    local NS = T.NS
    local keys = defined()
    local missing = {}
    local function need(where, s)
        if type(s) == "string" and not keys[s] then
            missing[#missing + 1] = where .. ": " .. s
        end
    end
    for name, tbl in pairs(NS.Constants) do
        if type(name) == "string" and name:find("_LABELS$") and type(tbl) == "table" then
            for k, label in pairs(tbl) do need(name .. "." .. tostring(k), label) end
        end
    end
    for _, list in ipairs({ NS.Categories.HELPFUL, NS.Categories.HARMFUL }) do
        for _, def in ipairs(list) do
            need("category " .. def.key, def.label)
            need("category " .. def.key, def.desc)
        end
    end
    for k, w in pairs(NS.FilterCompiler.WARN) do need("warning " .. k, w) end
    table.sort(missing)
    -- red under: a label added to a Constants table, a category or a warning without its enUS line
    -- (the literal-subscript scan above cannot see a key routed through a variable)
    assertEqual(#missing, 0, "routed but not defined: " .. table.concat(missing, "; "))
end)
