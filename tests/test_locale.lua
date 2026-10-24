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
    -- THE ONE EXEMPTION (issue #10, checkpoint 3). A user category's `label` is the PLAYER'S OWN
    -- NAME -- data, not a translatable string -- so no enUS line can exist for it and none should.
    -- The exemption is exactly one FIELD of exactly one flagged definition kind: `desc` is still
    -- checked, and a user category's description is a fixed shipped string precisely so that it can
    -- be. If that description ever has to name the category, the name is a `%s` ARGUMENT to a routed
    -- format string, never concatenated into one -- see defaults/UserCategories.lua's USER_DESC.
    -- Written out in full, with why Cat.LabelOf is what enforces it at the draw, in
    -- docs/common-tasks.md -> Locale routing, and its one exemption.
    local exempted = 0
    for _, list in ipairs({ NS.Categories.HELPFUL, NS.Categories.HARMFUL }) do
        for _, def in ipairs(list) do
            if def.userCategory then
                exempted = exempted + 1
            else
                need("category " .. def.key, def.label)
            end
            need("category " .. def.key, def.desc)
        end
    end
    -- red under: a SHIPPED definition acquiring `userCategory` to dodge the guard. The shared
    -- environment holds no profile with user categories, so the correct count here is zero -- the
    -- exemption is proven narrow by never firing on the shipped load at all. That it EXISTS, and
    -- that `desc` is still checked, is proven from the other side in tests/test_defaults.lua.
    assertEqual(exempted, 0, "a shipped category claimed the user-category exemption")
    for k, w in pairs(NS.FilterCompiler.WARN) do need("warning " .. k, w) end
    table.sort(missing)
    -- red under: a label added to a Constants table, a category or a warning without its enUS line
    -- (the literal-subscript scan above cannot see a key routed through a variable)
    assertEqual(#missing, 0, "routed but not defined: " .. table.concat(missing, "; "))
end)

-- Owner ruling T-1 (batch 7), widened by the owner's call of 2026-10-24 ("Widen T1", item AM-OC1):
-- a locale VALUE is ASCII apart from exactly two glyphs that draw correctly in the owner's font --
-- the em dash (U+2014, UTF-8 0xE2 0x80 0x94) and the horizontal ellipsis (U+2026, UTF-8 0xE2 0x80
-- 0xA6), the second so that a button opening a confirmation can end in '…' (options-ui-§21). Every
-- other multi-byte (>= 0x80) sequence fails: the font draws most such glyphs as a box (screenshot,
-- batch 7 T-1): "General -> Spell Categories" (as it read then) rendered as "General [box] Spell
-- Categories".
local T1_ALLOWED = { "\226\128\148", "\226\128\166" }

--- True when `value` carries a non-ASCII byte outside T-1's allowed glyphs.
local function breaksT1(value)
    for _, glyph in ipairs(T1_ALLOWED) do
        value = value:gsub(glyph, "")
    end
    return value:find("[\128-\255]") ~= nil
end

test("locale: every value is ASCII, the em dash and the ellipsis excepted (T-1, widened 2026-10-24)", function()
    -- red under: a non-ASCII byte (an arrow, a middot, a section mark, ...) reappearing in a locale
    -- VALUE. The two allowed glyphs are excluded on purpose, not silently allowed.
    local bad = {}
    for _, d in ipairs(definitions()) do
        if d.value and breaksT1(d.value) then
            bad[#bad + 1] = ("line %d: %s"):format(d.line, d.key)
        end
    end
    assertEqual(#bad, 0, "non-ASCII byte outside the em dash and the ellipsis: " .. table.concat(bad, "; "))
end)

test("locale: T-1 allows only the em dash and the ellipsis, nothing else non-ASCII", function()
    -- red under: the allowed set growing past the owner's two glyphs, or the scrub eating more than them
    assertTrue(not breaksT1("Delete container\226\128\166"), "the ellipsis is allowed")
    assertTrue(not breaksT1("a \226\128\148 b"), "the em dash is allowed")
    for _, glyph in ipairs({ "\226\134\146", "\194\183", "\194\167", "\226\128\147", "\195\169",
        "\226\128\153", "\226\128" }) do
        assertTrue(breaksT1("x" .. glyph .. "y"), "still refused: byte sequence of #" .. #glyph)
    end
end)

test("locale: the three buttons that open a confirmation end in the ellipsis (options-ui-§21)", function()
    -- red under: one of the labels losing its '…' (U+2026), or its enUS line going missing
    local keys = defined()
    for _, label in ipairs({ "Delete container\226\128\166", "Delete this category\226\128\166",
        "Forget unreadable categories\226\128\166" }) do
        assertTrue(keys[label] == true, "enUS defines " .. label)
        assertEqual(label:sub(-3), "\226\128\166", "ends in U+2026")
    end
    for _, plain in ipairs({ "Delete container", "Delete this category", "Forget unreadable categories" }) do
        assertTrue(not keys[plain], "the bare label is gone: " .. plain)
    end
end)

test("locale: no library-missing line joins a routed fragment", function()
    -- red under: the concatenation at the four sites (CoreSetup, DebugLogSetup, LauncherSetup,
    -- PerfSetup). localization-§1: a sentence is one key with a placeholder, never NS.LIBKA0S_MISSING
    -- glued to an unrouted ", " / "; " and a separately routed fragment a translator cannot reorder.
    local bad = {}
    local p = io.popen("ls -1 core/*.lua 2>/dev/null")
    for path in p:lines() do
        local n = 0
        for line in (readFile(path) .. "\n"):gmatch("(.-)\n") do
            n = n + 1
            if line:find("LIBKA0S_MISSING%s*%.%.") then
                bad[#bad + 1] = ("%s:%d"):format(path, n)
            end
        end
    end
    p:close()
    assertEqual(#bad, 0, "library-missing line concatenated at: " .. table.concat(bad, ", "))
end)

-- #6 folded the Filters, Layout, Bars, Icons and Text sub-pages into sections of the Containers page
-- (#23). General, Containers and Profiles are still pages.
test("locale: no string a player reads names a retired sub-page; they are sections now (#23)", function()
    local stale = {}
    for key in pairs((defined())) do
        for _, name in ipairs({ "Filters", "Layout", "Bars", "Icons", "Text" }) do
            if key:find(name .. " page", 1, true) then
                stale[#stale + 1] = key
            end
        end
    end
    table.sort(stale)
    -- red under: the Aura type desc's "The Filters page" and the attached handle's "the Layout page"
    assertEqual(#stale, 0, "names a retired page: " .. table.concat(stale, "; "))
end)
