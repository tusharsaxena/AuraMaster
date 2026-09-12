-- tests/test_setups.lua — the six LibKa0s seams' addon-side wiring: each descriptor does what the
-- addon relies on, and each degradation stub answers when the library is absent — proved by a real
-- load without it (tests/degraded_env.lua), never by a hand-written stub (testing-§8).

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local NS = T.NS
local fresh = dofile("tests/fresh_env.lua")
local loadDegraded = dofile("tests/degraded_env.lua")

-- ── Core ──────────────────────────────────────────────────────────────────────────────────────

test("core: NS.Print is reclaimed from AceConsole and prints with the cyan [AM] tag", function()
    local NS2, mocks = fresh()
    assertTrue(NS2.Print == NS2.Util.print, "one function object (architecture-§2)")
    local lines = {}
    rawset(mocks.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
        lines[#lines + 1] = tostring(msg)
    end)
    NS2.Print("hello")
    assertEqual(#lines, 1)
    assertTrue(lines[1]:find("|cFF00FFFF[AM]|r", 1, true) ~= nil, "the tag: " .. lines[1])
    assertTrue(lines[1]:find("hello", 1, true) ~= nil)
end)

test("core: NS.Printf is reclaimed from AceConsole and formats inside the secret-safe printer", function()
    local NS2, mocks = fresh()
    -- red under: dropping the Printf reclaim in core/AuraMaster.lua
    assertTrue(NS2.Printf == NS2.Util.printf, "one function object, reclaimed like NS.Print")
    local lines = {}
    rawset(mocks.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
        lines[#lines + 1] = tostring(msg)
    end)
    NS2.Printf("x %s", "y")
    assertEqual(#lines, 1)
    assertTrue(lines[1]:find("|cFF00FFFF[AM]|r", 1, true) ~= nil, "the tag: " .. lines[1])
    assertTrue(lines[1]:find("x y", 1, true) ~= nil, "formatted inside the printer: " .. lines[1])
end)

test("core: every close control goes through the one NS.MakeCloseButton wrapper", function()
    local p = io.popen("grep -rn 'MakeCloseButton(' --include='*.lua' core modules settings")
    local hits = {}
    for line in p:lines() do
        hits[#hits + 1] = line
    end
    p:close()
    for _, h in ipairs(hits) do
        assertTrue(h:find("^core/CoreSetup%.lua") or h:find("NS%.MakeCloseButton%("),
            "a bare factory call draws the fallback glyph: " .. h)
    end
end)

-- ── Media ─────────────────────────────────────────────────────────────────────────────────────

test("media: icons and the monospace face resolve inside this addon's folder", function()
    local icon = NS.Icon("close")
    assertTrue(type(icon) == "string" and icon:find("AuraMaster", 1, true) ~= nil, tostring(icon))
    local mono = NS.MediaFont("JetBrains Mono")
    assertEqual(NS.Constants.FONT_MONO, mono, "Constants read the seam, so it loaded first")
    assertTrue(mono ~= NS.Constants.FALLBACK_FONT)
end)

-- ── Env ───────────────────────────────────────────────────────────────────────────────────────

test("env: the version falls back to NS.version where the TOC cannot be read", function()
    assertEqual(NS.Version(), "0.1.0")
    assertEqual(NS.version, "0.1.0")
end)

test("env: the metadata reader never calls the deprecated global", function()
    -- red under: re-adding the global fallback in NS.Meta
    -- Source half: every GetAddOnMetadata( call in the addon's own code is qualified (Env., C_AddOns.).
    local p = io.popen("grep -rn 'GetAddOnMetadata(' --include='*.lua' core modules settings")
    for line in p:lines() do
        local code = line:match("^[^:]+:%d+:(.*)$") or line
        local from = 1
        while true do
            local s = code:find("GetAddOnMetadata(", from, true)
            if not s then break end
            assertTrue(s > 1 and code:sub(s - 1, s - 1) == ".", "a bare deprecated call: " .. line)
            from = s + 1
        end
    end
    p:close()
    -- Behavioral half: a degraded load (LibKa0s-Env absent) with no C_AddOns reader answers nil and
    -- never reaches a global GetAddOnMetadata. The degraded env's mock table is its own, so nothing
    -- planted here outlives the case.
    local NS2, mocks2 = loadDegraded()
    mocks2.C_AddOns = { GetAddOnMetadata = function(_, field) return "c:" .. field end }
    assertEqual(NS2.Meta("Version"), "c:Version", "the degraded reader reaches C_AddOns")
    mocks2.C_AddOns = false
    mocks2.GetAddOnMetadata = function() error("the deprecated global was called", 2) end
    local ok, v = pcall(NS2.Meta, "Version")
    assertTrue(ok, "NS.Meta raised: " .. tostring(v))
    assertNil(v)
end)

-- ── DebugLog ──────────────────────────────────────────────────────────────────────────────────

test("debug: the logging flag is ours, session-only, and never written to the profile", function()
    local NS2 = fresh()
    assertFalse(NS2.State.debug, "off at login")
    NS2.DebugLog:SetEnabled(true)
    assertTrue(NS2.State.debug)
    assertTrue(NS2.DebugLog:IsEnabled())
    NS2.DebugLog:SetEnabled(false)
    -- red under: DebugLogSetup's setEnabled writing NS.db.profile.debug
    assertNil(NS2.db.profile.debug)
    assertEqual(type(NS2.Debug), "function")
end)

-- ── the degraded load ─────────────────────────────────────────────────────────────────────────

test("degraded: without LibKa0s the addon still loads and every seam answers", function()
    local NS2 = loadDegraded()
    assertEqual(type(NS2.Print), "function")
    assertEqual(NS2.SafeToString(nil), "nil")
    assertNil(NS2.Icon("close"), "no library, no path — never a guessed one")
    assertEqual(NS2.Constants.FONT_MONO, NS2.Constants.FALLBACK_FONT, "a real client font")
    NS2.DebugLog:SetEnabled(true)
    assertTrue(NS2.State.debug, "the flag still works; only the window is gone")
    assertEqual(NS2.Version(), "0.1.0")
    local r, g, b, a = NS2.ResolveColor({ r = 0.1, g = 0.2, b = 0.3, a = 0.4 }, false)
    assertEqual(r + g + b + a, 1.0)
end)

-- ── the seams, one behavior each ──────────────────────────────────────────────────────────────

--- Capture an environment's chat into a list.
local function chat(m)
    local lines = {}
    rawset(m.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
        lines[#lines + 1] = tostring(msg)
    end)
    return lines
end

test("media: the shipped face and bar textures reach LibSharedMedia, from this addon's folder", function()
    local registered = {}
    local _, m = fresh({ before = function(mk)
        mk.__libs["LibSharedMedia-3.0"] = {
            MediaType = { FONT = "font", STATUSBAR = "statusbar" },
            Register = function(_, kind, name, path)
                registered[#registered + 1] = { kind = kind, name = name, path = path }
            end,
            HashTable = function() return {} end,
            Fetch = function() return nil end,
            List = function() return {} end,
            IsValid = function() return false end,
        }
    end })
    local media = m.LibStub("LibKa0s-Media-1.0")
    local fonts, bars, textures = {}, 0, 0
    for _, r in ipairs(registered) do
        if r.kind == "font" then fonts[r.name] = r.path end
        if r.kind == "statusbar" then bars = bars + 1 end
    end
    for _ in pairs(media.TEXTURES) do textures = textures + 1 end
    -- red under: dropping core/MediaSetup.lua's RegisterLSM call (no Ka0s face or texture in any
    -- dropdown, and a stored "JetBrains Mono" resolving to nothing)
    local mono = fonts["JetBrains Mono"]
    assertTrue(mono ~= nil, "the monospace face is registered")
    assertTrue(mono:find("AddOns\\AuraMaster\\", 1, true) ~= nil, "from this addon's folder: " .. mono)
    assertEqual(bars, textures, "every shipped bar texture")
end)

test("core: the degraded printer names the missing library once, on the first line it prints", function()
    local NS2, m2 = loadDegraded()
    local lines = chat(m2)
    NS2.Print("one")
    NS2.Print("two")
    -- red under: the one-time notice printed on every line, or never
    assertEqual(#lines, 3)
    assertTrue(lines[1]:find(NS2.LIBKA0S_MISSING, 1, true) ~= nil, lines[1])
    for i = 2, 3 do
        assertTrue(lines[i]:find(NS2.PREFIX, 1, true) == 1, "tagged: " .. lines[i])
        assertFalse(lines[i]:find(NS2.LIBKA0S_MISSING, 1, true), "said once: " .. lines[i])
    end
    assertTrue(lines[3]:find("two", 1, true) ~= nil)
end)

test("core: the degraded Printf stringifies every argument before it formats", function()
    local NS2, m2 = loadDegraded()
    local lines = chat(m2)
    NS2.Print("warm up")   -- the one-time notice, out of the way
    local ok, err = pcall(NS2.Printf, "%s|%s|%s", nil, false, 5)
    -- red under: formatting the raw arguments (Lua 5.1's format raises on a nil for %s)
    assertTrue(ok, tostring(err))
    local last = lines[#lines]
    assertTrue(last:find("nil|false|5", 1, true) ~= nil, last)
end)

test("core: the degraded color resolver keeps the stored alpha, and falls through for a unit with no class", function()
    local NS2, m2 = loadDegraded()
    m2.UnitClass = function(unit)
        if unit == "player" then return "Mage", "MAGE" end
    end
    local stored = { r = 0.1, g = 0.2, b = 0.3, a = 0.4 }
    local r, g, b, a = NS2.ResolveColor(stored, true, "player")
    local mage = m2.RAID_CLASS_COLORS.MAGE
    -- red under: the class color replacing the stored alpha (options-ui-§17's first rule)
    assertEqual(r, mage.r, "the class color")
    assertEqual(g, mage.g)
    assertEqual(b, mage.b)
    assertEqual(a, 0.4, "with the stored alpha")
    r, g, b, a = NS2.ResolveColor(stored, true, "target")
    assertEqual(r, 0.1, "no class: the swatch as stored")
    assertEqual(g, 0.2)
    assertEqual(b, 0.3)
    assertEqual(a, 0.4)
end)

test("core: every close button is built with this addon's folder, so it can draw the catalog mark", function()
    local NS2, m2 = fresh()
    local core = m2.LibStub("LibKa0s-Core-1.0")
    local real, seen = core.MakeCloseButton, nil
    core.MakeCloseButton = function(parent, onClick, addon)
        seen = addon
        return real(parent, onClick, addon)
    end
    NS2.MakeCloseButton(m2.UIParent, function() end)
    core.MakeCloseButton = real
    -- red under: the wrapper calling the factory with two arguments (the × glyph, silently)
    assertEqual(seen, "AuraMaster")
end)

test("namespace: NS is private — no global — and carries the folder name and the [AM] tag", function()
    assertEqual(NS.name, "AuraMaster")
    -- red under: publishing the namespace as _G[addonName] (architecture-§1)
    assertNil(rawget(_G, "AuraMaster"))
    assertEqual(NS.PREFIX, "|cFF00FFFF[AM]|r")
end)
