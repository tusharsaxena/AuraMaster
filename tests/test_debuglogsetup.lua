-- tests/test_debuglogsetup.lua — core/DebugLogSetup.lua: the LibKa0s-DebugLog-1.0 descriptor this
-- addon owns (debug-logging-§4, §5, §7): where the flag lives, what the [Init] summary says, where
-- the chat acknowledgment goes, what the window's visibility refreshes, and the stub a load without
-- the library takes. The console itself is tested in LibKa0s (testing-§8).

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local loadDegraded = dofile("tests/degraded_env.lua")

local function capture(mocks)
    local lines = {}
    rawset(mocks.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
        lines[#lines + 1] = tostring(msg)
    end)
    return lines
end

--- The console line after its "HH:MM:SS | " stamp.
local function unstamped(line) return (tostring(line):gsub("^%d%d:%d%d:%d%d | ", "")) end

test("debuglog: enabling logging writes the [Init] summary — name, version, schema, profile and container count", function()
    local NS2 = fresh()
    NS2.DebugLog:SetEnabled(true)
    -- red under: initSummary dropping a field, or NS.SafeToString of a missing field answering "nil"
    assertEqual(unstamped(NS2.DebugLog:LastLine()),
        "[Init] AuraMaster v" .. NS2.Version() .. ", schema v1, profile 'Default', 3 container(s)")
    NS2.DebugLog:SetEnabled(false)
    NS2.db:SetProfile("Raid")
    NS2.ContainerManager.Create({})
    NS2.DebugLog:SetEnabled(true)
    -- red under: the summary built once at load rather than read at each enable
    assertEqual(unstamped(NS2.DebugLog:LastLine()),
        "[Init] AuraMaster v" .. NS2.Version() .. ", schema v1, profile 'Raid', 4 container(s)")
    NS2.DebugLog:SetEnabled(false)
end)

test("debuglog: the flag is NS.State.debug itself — the sink and IsEnabled read it live", function()
    local NS2 = fresh()
    local before = NS2.DebugLog:BufferSize()
    NS2.Debug("Probe", "quiet %s", 1)
    -- red under: the sink ungated (a trace lands with logging off)
    assertEqual(NS2.DebugLog:BufferSize(), before)
    NS2.State.debug = true
    -- red under: isEnabled answering a copy the library keeps instead of reading NS.State.debug
    assertTrue(NS2.DebugLog:IsEnabled())
    NS2.Debug("Probe", "loud %s", 2)
    assertEqual(unstamped(NS2.DebugLog:LastLine()), "[Probe] loud 2")
    NS2.State.debug = false
    assertFalse(NS2.DebugLog:IsEnabled())
end)

test("debuglog: the chat acknowledgment goes through the addon's tagged printer; the console brackets both ends", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    NS2.DebugLog:SetEnabled(true)
    -- red under: the descriptor's `print` dropped (the library falls back to an untagged chat line)
    assertEqual(lines[1], NS2.PREFIX .. " debug logging |cff40ff40ON|r")
    assertTrue(NS2.DebugLog:FindLine("[Debug] logging enabled") ~= nil)
    NS2.DebugLog:SetEnabled(false)
    assertEqual(lines[2], NS2.PREFIX .. " debug logging |cffff4040OFF|r")
    assertTrue(NS2.DebugLog:FindLine("[Debug] logging disabled") ~= nil, "the disable line lands after the flag is off")
    assertNil(NS2.db.profile.debug, "never the profile")
end)

test("debuglog: showing or hiding the console refreshes open panels, so the Master controls row follows it", function()
    local NS2, mocks = fresh()
    local refreshes = { 0 }
    local refresh = NS2.Helpers.RefreshAllPanels
    NS2.Helpers.RefreshAllPanels = function(...) refreshes[1] = refreshes[1] + 1; return refresh(...) end
    NS2.DebugLog:Show()
    -- The library hooks the window's OnShow / OnHide; the client fires them, so the case does too.
    local window = mocks.__globals.AuraMasterDebugWindow
    window:__fire("OnShow")
    -- red under: onVisibilityChanged dropped from the descriptor
    assertEqual(refreshes[1], 1)
    NS2.DebugLog:Hide()
    window:__fire("OnHide")
    assertEqual(refreshes[1], 2)
end)

test("debuglog: the Debug console row shows and hides the window and never touches the logging flag", function()
    local NS2, mocks = fresh()
    assertTrue(NS2.SetByPath("state.debugConsole", true))
    assertTrue(NS2.DebugLog:IsShown())
    assertTrue(NS2.GetSetting("state.debugConsole"))
    -- red under: the row's set bound to SetEnabled instead of the console checkbox's set
    assertFalse(NS2.State.debug)
    -- The window is named from the folder name, so two addons cannot clobber each other's globals.
    assertTrue(mocks.__globals.AuraMasterDebugWindow ~= nil)
    assertTrue(mocks.__globals.AuraMasterDebugWindow:IsShown())
    assertTrue(NS2.SetByPath("state.debugConsole", false))
    assertFalse(NS2.DebugLog:IsShown())
end)

test("debuglog: Reset all closes an open console, because the console row carries a default", function()
    -- options-ui-§12 names the debug console among the session rows a global reset MUST restore.
    -- red under: the console row without `default = false` (settings/General.lua) — the reset's
    -- session sweep has no value to write, and the window stays open
    local NS2 = fresh()
    assertTrue(NS2.SetByPath("state.debugConsole", true))
    assertTrue(NS2.DebugLog:IsShown())
    NS2.Helpers.RestoreAllDefaults()
    assertFalse(NS2.DebugLog:IsShown())
end)

-- ── the stub ──────────────────────────────────────────────────────────────────────────────────

--- The degraded build's chat lines, minus the Core stub's one-time "running on reduced fallbacks".
local function degradedLines(mocks)
    local all = capture(mocks)
    return function()
        local out = {}
        for _, l in ipairs(all) do
            if not l:find("running on reduced built-in fallbacks", 1, true) then
                out[#out + 1] = l
            end
        end
        return out
    end
end

test("debuglog: without the library, SetEnabled still flips the flag and acks, and says once that the window is gone", function()
    local NS2, mocks = loadDegraded()
    local lines = degradedLines(mocks)
    local missing = NS2.LIBKA0S_MISSING .. ", so the debug console window is unavailable."
    NS2.DebugLog:SetEnabled(true)
    assertTrue(NS2.State.debug)
    assertTrue(NS2.DebugLog:IsEnabled())
    local got = lines()
    assertEqual(#got, 2, table.concat(got, " | "))
    assertTrue(got[1]:find("|cff40ff40Debug logging on.|r", 1, true) ~= nil, got[1])
    assertTrue(got[2]:find(missing, 1, true) ~= nil, got[2])
    NS2.DebugLog:SetEnabled(false)
    NS2.DebugLog:SetEnabled(true)
    NS2.DebugLog:Toggle()
    NS2.DebugLog:Show()
    NS2.DebugLog:ShowCopy()
    got = lines()
    -- red under: the stub's sayOnce latch dropped (the notice repeats per call)
    assertEqual(#got, 4, table.concat(got, " | "))
    assertTrue(got[3]:find("|cffff4040Debug logging off.|r", 1, true) ~= nil, got[3])
    assertFalse(NS2.DebugLog:IsShown())
    NS2.Debug("Probe", "%s", "no error")
    assertEqual(NS2.DebugLog:BufferSize(), 0)
end)

test("debuglog: without the library the console row is honest — never checked, and its tooltip says why", function()
    local NS2, mocks = loadDegraded()
    local lines = degradedLines(mocks)
    local spec = NS2.DebugLog:ConsoleCheckbox()
    assertEqual(spec.label, "Debug console")
    -- red under: the stub's checkbox tooltip not naming the missing library
    assertEqual(spec.tooltip, NS2.LIBKA0S_MISSING .. ", so the debug console window is unavailable.")
    assertFalse(spec.get())
    spec.set(true)
    spec.set(true)
    assertEqual(#lines(), 1, "the notice, once")
    assertFalse(NS2.State.debug, "the window row never touches the flag")
end)
