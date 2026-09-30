-- tests/test_debug_coverage.lua — the debug-logging-§8 diagnosis lines (DL-AM-02): the state edges,
-- deferred work, refusals, dependencies and caught errors a support read of the log needs, and the
-- §9 quiet-steady-state gates on the repeating paths that used to write the same line every pass.
-- Each case records the gated sink with logging ON; docs/debug.md's Coverage section is the map.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")

--- Logging on, and every line of the tags in `tags` (a set; nil for all) recorded as `[Tag] text`.
local function record(NS, tags)
    NS.State.debug = true
    local lines = {}
    NS.Debug = function(tag, fmt, ...)
        if tags and not tags[tag] then return end
        local n, args = select("#", ...), { ... }
        for i = 1, n do args[i] = tostring(args[i]) end
        local k = #lines
        lines[k + 1] = "[" .. tag .. "] " .. fmt:format(unpack(args, 1, n))
    end
    return lines
end

local function dump(lines) return table.concat(lines, " | ") end

--- How many of `lines` contain `needle`.
local function count(lines, needle)
    local n = 0
    for _, l in ipairs(lines) do
        if l:find(needle, 1, true) then n = n + 1 end
    end
    return n
end

-- ── deferred work: the apply queue's hold ────────────────────────────────────────────────────────

test("coverage: a held apply is traced once while the hold lasts, however many edges flush it (quiet steady state)", function()
    local NS, mocks = fresh()
    local CM = NS.ContainerManager
    local lines = record(NS, { Apply = true })
    mocks.__aurasSecret = true
    CM.RequestApply(1)
    -- Every combat end of a key flushes on PLAYER_REGEN_ENABLED, and each restriction flip again.
    for _ = 1, 8 do CM.FlushPending("regen") end
    CM.FlushPending()
    -- red under: traceHold's change gate dropped (one identical deferred line per edge, the pair the
    -- 060 key log showed on every combat edge, debug-logging-§9)
    assertEqual(#lines, 1, dump(lines))
    assertEqual(lines[1], "[Apply] deferred: secret=true lockdown=false edge=regen queued=1")
    CM.RequestApply(2)
    CM.FlushPending("regen")
    -- red under: the gate comparing nothing but the reads (a grown queue would go unsaid)
    assertEqual(#lines, 2, dump(lines))
    assertEqual(lines[2], "[Apply] deferred: secret=true lockdown=false edge=regen queued=2")
    mocks.__aurasSecret = false
    CM.FlushPending()
    -- red under: the flush that ends the hold writing nothing (a hold with no flush line after it
    -- reads as held forever, debug-logging-§8)
    assertEqual(lines[3], "[Apply] applied 2 container(s)")
    mocks.__aurasSecret = true
    CM.RequestApply(1)
    CM.FlushPending("regen")
    mocks.__aurasSecret = false
    -- red under: the gate never re-armed by the flush (the next key's hold would go unsaid)
    assertEqual(#lines, 4, dump(lines))
    assertEqual(lines[4], "[Apply] deferred: secret=true lockdown=false edge=regen queued=1")
end)

test("coverage: with logging off a hold builds and records nothing, so turning logging on traces it", function()
    local NS, mocks = fresh()
    local CM = NS.ContainerManager
    local lines = record(NS, { Apply = true })
    NS.State.debug = false
    mocks.__aurasSecret = true
    CM.RequestApply(1)
    CM.FlushPending("regen")
    NS.State.debug = true
    CM.FlushPending("regen")
    mocks.__aurasSecret = false
    -- red under: the gate's memory written behind a closed gate (the first hold seen with logging
    -- on would be swallowed as "no change")
    assertEqual(#lines, 1, dump(lines))
end)

-- ── errors caught ────────────────────────────────────────────────────────────────────────────────

test("coverage: a container apply that raises is one [Apply] line per distinct error, naming the container", function()
    local NS = fresh({ before = function(m) m.geterrorhandler = function() return function() end end end })
    local CM = NS.ContainerManager
    local lines = record(NS, { Apply = true })
    rawset(CM.instances[1], "Apply", function() error("boom", 0) end)
    for _ = 1, 3 do
        CM.RequestApply(1)
        CM.FlushPending()
    end
    -- red under: applyDirty's failure branch without NS.DebugOnce (the error reached BugSack and
    -- nothing in a pasted log), or the line written per pass
    assertEqual(count(lines, "failed"), 1, dump(lines))
    assertTrue(lines[1]:find("[Apply] container #1 failed: boom", 1, true) ~= nil, lines[1])
end)

-- ── refusals, with the guard named ───────────────────────────────────────────────────────────────

test("coverage: every combat refusal writes one line naming the guard", function()
    local NS, mocks = fresh()
    local lines = record(NS)
    mocks.__lockdown = true
    assertNil(NS.ContainerManager.Create({}))
    NS.Slash:OnSlash("delete 1")
    assertFalse(NS.Preview.SetTestMode(true, "/am test"))
    assertFalse(NS.FramePicker.PickFor(function() end))
    NS.OpenOptionsPage("containers")
    mocks.__lockdown = false
    -- red under: any one guard returning without its line (the report is "nothing happened", and the
    -- guard is the answer, debug-logging-§8)
    assertEqual(count(lines, "[Containers] create refused (in combat)"), 1, dump(lines))
    assertEqual(count(lines, "[Containers] delete refused (in combat)"), 1, dump(lines))
    assertEqual(count(lines, "[Preview] test mode refused (in combat)"), 1, dump(lines))
    assertEqual(count(lines, "[Anchor] frame pick refused (in combat)"), 1, dump(lines))
    assertEqual(count(lines, "[Cfg] open containers refused (in combat)"), 1, dump(lines))
end)

-- ── state edges ──────────────────────────────────────────────────────────────────────────────────

test("coverage: test mode switched outside the seam says who switched it; the checkbox's row does not repeat its [Set] line", function()
    local NS = fresh()
    local lines = record(NS, { Preview = true })
    NS.Slash:OnSlash("test on")
    NS.addon:OnCombatChanged("PLAYER_REGEN_DISABLED")
    NS.addon:OnCombatChanged("PLAYER_REGEN_ENABLED")
    NS.Preview.SetTestMode(true)
    NS.Preview.SetTestMode(false)
    -- red under: SetTestMode's switch line dropped (a pasted log never says why placeholders drew or
    -- vanished), or written for the checkbox too, a second line beside its [Set] (debug-logging-§10)
    assertEqual(dump(lines), "[Preview] test mode on (/am test) | [Preview] test mode off (combat started)")
end)

test("coverage: the stand-down and the stand-up are one [State] line each, naming the holds", function()
    local NS = fresh()
    local lines = record(NS, { State = true })
    NS.Slash:OnSlash("disable")
    NS.Slash:OnSlash("enable")
    NS.lifecycle:Hold(NS.HOLD_PERF)
    NS.lifecycle:Release(NS.HOLD_PERF)
    -- red under: standDown or standUp without traceEdge (the addon's own enable and stand-down
    -- transitions are debug-logging-§8 state edges), or the holds left out
    assertEqual(#lines, 4, dump(lines))
    assertEqual(lines[1], "[State] stood down: events and timers off, containers hidden (holds: disabled)")
    assertEqual(lines[2], "[State] stood up: events on, every container re-applied (holds: none)")
    assertEqual(lines[3], "[State] stood down: events and timers off, containers hidden (holds: perf)")
end)

test("coverage: a stand-down combat holds says so, and its finish after combat is traced", function()
    local NS, mocks = fresh()
    local lines = record(NS, { State = true })
    mocks.__lockdown = true
    NS.Slash:OnSlash("disable")
    mocks.__lockdown = false
    mocks.__fireEvent("PLAYER_REGEN_ENABLED")
    -- red under: holdPending's flush writing nothing (a held-then-never-flushed stand-down must be
    -- visible, debug-logging-§8 deferred work)
    assertEqual(#lines, 2, dump(lines))
    assertEqual(lines[1], "[State] stood down: events and timers off; hiding held until combat ends (holds: disabled)")
    assertEqual(lines[2], "[State] stand-down finished after combat: Blizzard frames and anchors restored (holds: disabled)")
end)

-- ── dependencies, at enable ──────────────────────────────────────────────────────────────────────

test("coverage: the [Init] line names a missing optional library and a stand-down, once per enable", function()
    local NS = fresh()   -- the harness loads no LibSharedMedia
    NS.DebugLog:SetEnabled(true)
    local line = NS.DebugLog:LastLine()
    -- red under: initNotes dropped (a log from a client with no media library reads as healthy)
    assertTrue(line:find(", LibSharedMedia-3.0 missing (media-pack fonts and textures fall back)", 1, true) ~= nil, line)
    assertNil(line:find("stood down", 1, true), line)
    NS.DebugLog:SetEnabled(false)
    NS.lifecycle:Hold(NS.HOLD_PERF)
    NS.DebugLog:SetEnabled(true)
    line = NS.DebugLog:LastLine()
    NS.DebugLog:SetEnabled(false)
    NS.lifecycle:Release(NS.HOLD_PERF)
    -- red under: the stand-down note missing from the line a pasted log opens with
    assertTrue(line:find(", stood down (holds: perf)", 1, true) ~= nil, line)
end)
