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
