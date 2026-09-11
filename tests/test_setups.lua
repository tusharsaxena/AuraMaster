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
    rawset(mocks.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg) lines[#lines + 1] = tostring(msg) end)
    NS2.Print("hello")
    assertEqual(#lines, 1)
    assertTrue(lines[1]:find("|cFF00FFFF[AM]|r", 1, true) ~= nil, "the tag: " .. lines[1])
    assertTrue(lines[1]:find("hello", 1, true) ~= nil)
end)

test("core: every close control goes through the one NS.MakeCloseButton wrapper", function()
    local p = io.popen("grep -rn 'MakeCloseButton(' --include='*.lua' core modules settings")
    local hits = {}
    for line in p:lines() do hits[#hits + 1] = line end
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

-- ── DebugLog ──────────────────────────────────────────────────────────────────────────────────

test("debug: the logging flag is ours, session-only, and never written to the profile", function()
    local NS2 = fresh()
    assertFalse(NS2.State.debug, "off at login")
    NS2.DebugLog:SetEnabled(true)
    assertTrue(NS2.State.debug)
    assertTrue(NS2.DebugLog:IsEnabled())
    NS2.DebugLog:SetEnabled(false)
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
