-- tests/test_debug_library_lines.lua — the lines LibKa0s v1.65.0 writes into THIS addon's debug log
-- (DG-AM-01, the 2026-09-30 debug-gaps run): a Slash refusal, a Lifecycle edge, an Options combat
-- refusal, the Launcher's state lines through the at-enable queue, and the console's change gates
-- re-armed by a Clear. Each reads the real console (NS.DebugLog's buffer), not a spy on NS.Debug, so
-- a case proves the line landed where a player's pasted log comes from, and that it landed ONCE:
-- the host writes no second copy of a line the library owns (debug-logging-§4). docs/debug.md's
-- Coverage section names which tags are the library's.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertNil
local fresh = dofile("tests/fresh_env.lua")

--- The console's lines since `from` (a buffer index), as written.
local function since(NS, from)
    local out, buf = {}, NS.DebugLog.buffer
    for i = (from or 0) + 1, #buf do out[#out + 1] = buf[i] end
    return out
end

local function dump(lines) return table.concat(lines, " | ") end

--- How many of `lines` contain `needle` (plain).
local function count(lines, needle)
    local n = 0
    for _, l in ipairs(lines) do
        if l:find(needle, 1, true) then n = n + 1 end
    end
    return n
end

--- A fresh environment with logging on and the console emptied: what a case writes is all it holds.
local function logging()
    local NS, mocks = fresh()
    NS.DebugLog:SetEnabled(true)
    NS.DebugLog:Clear()
    return NS, mocks
end

-- ── Slash (LibKa0s-Slash-1.0 18) ─────────────────────────────────────────────────────────────────

test("library lines: an unknown verb is one [Cmd] refusal line in this addon's log", function()
    local NS = logging()
    NS.Slash:OnSlash("frobnicate")
    local lines = since(NS)
    -- red under: settings/Slash.lua's descriptor without `debug` (the refusal reaches chat only)
    assertEqual(count(lines, "[Cmd] refused frobnicate: unknown verb"), 1, dump(lines))
    assertEqual(count(lines, "frobnicate"), 1, "written once: " .. dump(lines))
end)

test("library lines: the disabled gate's refusal is one [Cmd] line, and no host line beside it", function()
    local NS = logging()
    NS.Slash:OnSlash("disable")
    local from = #NS.DebugLog.buffer
    NS.Slash:OnSlash("lock")
    local lines = since(NS, from)
    -- red under: no `debug` on the dispatcher, or a host line matching the gate's chat line
    -- (AbsorbTracker's DisabledLine shape) written as well
    assertEqual(count(lines, "[Cmd] refused lock: disabled"), 1, dump(lines))
    assertEqual(#lines, 1, "the refusal alone: " .. dump(lines))
    NS.Slash:OnSlash("enable")
end)

test("library lines: a get / set usage refusal names the verb and the guard", function()
    local NS = logging()
    NS.Slash:OnSlash("set")
    NS.Slash:OnSlash("get no.such.path")
    local lines = since(NS)
    assertEqual(count(lines, "[Cmd] refused set: usage"), 1, dump(lines))
    assertEqual(count(lines, "[Cmd] refused get no.such.path: not found"), 1, dump(lines))
end)

-- ── Lifecycle (LibKa0s-Lifecycle-1.0 3) ──────────────────────────────────────────────────────────

test("library lines: a stand-down and a stand-up are one [Lifecycle] line each, and no [State] edge line", function()
    local NS = logging()
    NS.Slash:OnSlash("disable")
    NS.Slash:OnSlash("enable")
    local lines = since(NS)
    -- red under: core/LifecycleSetup.lua's descriptor without `debug`
    assertEqual(count(lines, "[Lifecycle] stood down: added disabled (holds: disabled)"), 1, dump(lines))
    assertEqual(count(lines, "[Lifecycle] stood up: released disabled (holds: none)"), 1, dump(lines))
    -- red under: the host's own edge line kept beside the library's (two lines for one edge)
    assertEqual(count(lines, "stood down"), 1, dump(lines))
    assertEqual(count(lines, "stood up"), 1, dump(lines))
    assertEqual(count(lines, "[State]"), 0, dump(lines))
end)

test("library lines: a call that moves no edge writes no [Lifecycle] line", function()
    local NS = logging()
    NS.SyncEnabled()
    NS.lifecycle:Reevaluate()
    assertEqual(count(since(NS), "[Lifecycle]"), 0, dump(since(NS)))
end)

-- ── Options combat lock (LibKa0s-Options-1.0 27) ─────────────────────────────────────────────────

test("library lines: a write the combat lock refuses is one [Cfg] line per combat", function()
    local NS, mocks = logging()
    mocks.__lockdown = true
    -- The seam every locked write asks (a widget's commit, Defaults, a tab switch).
    assertTrue(NS.Helpers.__combatRefused("write", "scale"))
    assertTrue(NS.Helpers.__combatRefused("write", "scale"))
    mocks.__lockdown = false
    local lines = since(NS)
    -- red under: settings/OptionsSetup.lua's descriptor without `debug`, or a line per commit
    assertEqual(count(lines, "[Cfg] write scale refused (in combat)"), 1, dump(lines))
end)

-- ── Launcher and the at-enable queue (Launcher 5, DebugLogGates 1) ───────────────────────────────

test("library lines: the Launcher's dependency line, written at OnEnable with logging off, lands when logging is turned on, once", function()
    local NS = fresh()   -- the harness loads no LibDataBroker-1.1
    assertEqual(count(NS.DebugLog.buffer, "[Launcher]"), 0, "gated off at load")
    NS.DebugLog:SetEnabled(true)
    local lines = since(NS)
    -- red under: core/LauncherSetup.lua without `debugAtEnable` (the line went to the gated sink at
    -- OnEnable, with logging off, and never landed: gap G4)
    assertEqual(count(lines, "[Launcher] LibDataBroker-1.1 absent; no launcher"), 1, dump(lines))
    local init, dep
    for i, l in ipairs(lines) do
        if l:find("[Init]", 1, true) then init = i end
        if l:find("[Launcher]", 1, true) then dep = i end
    end
    assertTrue(init and dep and init < dep, "after the [Init] summary: " .. dump(lines))
    NS.DebugLog:SetEnabled(false)
    local from = #NS.DebugLog.buffer
    NS.DebugLog:SetEnabled(true)
    -- red under: the queue flushed on every enable edge rather than once
    assertEqual(count(since(NS, from), "[Launcher]"), 0, dump(since(NS, from)))
    NS.DebugLog:SetEnabled(false)
end)

-- ── the change gates, re-armed by a Clear (DebugLog 18, DebugLogGates 1) ─────────────────────────

test("library lines: a caught error is said once, and again after a Clear", function()
    local NS = logging()
    NS.DebugOnce("Probe", "site", "boom\nstack")
    NS.DebugOnce("Probe", "site", "boom\nstack")
    assertEqual(count(since(NS), "[Probe] site failed: boom"), 1, dump(since(NS)))
    NS.DebugLog:Clear()
    NS.DebugOnce("Probe", "site", "boom\nstack")
    -- red under: NS.DebugOnce keeping a table of its own (a Clear never re-armed it: gap G2)
    assertEqual(count(since(NS), "[Probe] site failed: boom"), 1, dump(since(NS)))
end)

test("library lines: with logging off a caught error is not spent, so it is said once logging is on", function()
    local NS = fresh()
    NS.DebugOnce("Probe", "site", "quiet")
    NS.DebugLog:SetEnabled(true)
    NS.DebugOnce("Probe", "site", "quiet")
    assertEqual(count(since(NS), "[Probe] site failed: quiet"), 1, dump(since(NS)))
    NS.DebugLog:SetEnabled(false)
end)

test("library lines: the apply queue's hold trace is re-armed by a Clear (the onClear hook)", function()
    local NS, mocks = logging()
    local CM = NS.ContainerManager
    mocks.__aurasSecret = true
    CM.RequestApply(1)
    CM.FlushPending("regen")
    CM.FlushPending("regen")
    assertEqual(count(since(NS), "[Apply] deferred:"), 1, dump(since(NS)))
    NS.DebugLog:Clear()
    CM.FlushPending("regen")
    -- red under: core/DebugLogSetup.lua without `onClear` (the hold stayed unsaid after a Clear)
    assertEqual(count(since(NS), "[Apply] deferred:"), 1, dump(since(NS)))
    mocks.__aurasSecret = false
    CM.FlushPending()
end)

test("library lines: a screen fallback is said again after a Clear", function()
    local NS = logging()
    local CM = NS.ContainerManager
    local c = NS.Database.FindContainer(1)
    c.attach.mode, c.attach.frame = "frame", "MissingBar"
    NS.Anchors.Place(CM.instances[1])
    NS.Anchors.Place(CM.instances[1])
    assertEqual(count(since(NS), "screen fallback"), 1, dump(since(NS)))
    NS.DebugLog:Clear()
    NS.Anchors.Place(CM.instances[1])
    -- red under: the fallback's gate kept on the container (a Clear left it shut)
    assertEqual(count(since(NS), "screen fallback"), 1, dump(since(NS)))
    assertNil(rawget(CM.instances[1], "fallbackNoted"), "no gate of the host's own is left on the container")
end)
