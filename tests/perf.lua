-- tests/perf.lua — the offline performance runner (performance-§9).
--
--   lua tests/perf.lua [--out path] [--label text]
--
-- DELIBERATELY OUTSIDE THE GREEN GATE. `lua tests/run.lua` does not invoke this, and no commit
-- depends on it; the vendored tests/_kit/run-automated-tests.sh records it as the non-gating `perf`
-- suite. Wall-clock numbers on a developer machine are printed for orientation only.
--
-- What it ASSERTS is the deterministic half: how many times the aura engine is called, how many
-- apply passes a burst of changes costs, and that a dormant probe changes neither the calls nor the
-- allocation of a pass compared with the same code with no probe at all. Loops run with the GC
-- stopped and the engine mock counting calls without logging them, so bytes/iter is the addon's own
-- allocation. Those are machine-independent, so a real regression — a filter re-sent on
-- every apply, a coalescing throttle broken, a bracket written without its gate — fails here while
-- a busy CPU never does.
--
-- WHAT THIS CANNOT MEASURE is the engine's own per-aura work: Blizzard's AuraContainer handles
-- UNIT_AURA and animates every bar in its own code, and headlessly it is a recorder. That cost is
-- what the in-game capture's frame-time arms measure (docs/performance.md).

local Loader     = dofile("tests/_kit/loader.lua")
local buildMocks = dofile("tests/wow_mock.lua")
Loader.addonName = "AuraMaster"

local opts = { out = nil, label = "offline" }
do
    local i = 1
    while arg and arg[i] do
        local a = arg[i]
        if a == "--out" then opts.out = arg[i + 1]; i = i + 2
        elseif a == "--label" then opts.label = arg[i + 1] or opts.label; i = i + 2
        else
            io.stderr:write("unknown argument: " .. tostring(a) .. "\n")
            io.stderr:write("usage: lua tests/perf.lua [--out path] [--label text]\n")
            os.exit(2)
        end
    end
end

-- ── environment ─────────────────────────────────────────────────────────────────────────────
-- Derived from the TOC and from the vendored XML, never copied (testing-§9): this runner is the
-- ungated list, which is exactly the one that rots while its figures are still trusted.

local mocks = buildMocks()
local NS = {}
rawset(_G, "AuraMasterDB", nil)
Loader.loadAll(Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml"), NS, mocks)
Loader.loadAll(Loader.tocFiles("AuraMaster.toc"), NS, mocks)
-- The hidden measuring string answers a readable width, as the client's does once its font is in.
-- A stub answers none, and every measure would then fail and never be remembered, so each pass would
-- re-measure: a text starter's Size to fit (batch 8, AS-2) most of all, with a line per placeholder
-- and time sample. The loops below measure the path a player runs, not that login-only one.
local measured = 0
local measureFS = { SetFont = function() return true end,
    SetText = function(self, t) measured = measured + 1; self.text = t end,
    GetStringWidth = function(self) return tostring(self.text):len() * 6 + 2 end }
NS.Style.__measurer = function() return measureFS end
NS.addon:OnInitialize()
NS.addon:OnEnable()
mocks.__fireTimers()

local CM = NS.ContainerManager

-- Every engine call, across every container, since the last reset. Read from the mock's by-name
-- counters, which the measured loops keep without allocating (tests/wow_mock.lua `record`).
local function engineCalls()
    local n = 0
    for _, e in ipairs(mocks.__engines) do
        for _, c in pairs(e.__counts) do n = n + c end
    end
    return n
end
-- Zeroed in place rather than replaced, so a name already seen costs no allocation when a
-- measured loop counts it again.
local function resetEngineCalls()
    for _, e in ipairs(mocks.__engines) do
        e.__calls = {}
        for name in pairs(e.__counts) do e.__counts[name] = 0 end
    end
end
local function callsNamed(name)
    local n = 0
    for _, e in ipairs(mocks.__engines) do n = n + (e.__counts[name] or 0) end
    return n
end

local results, failures = {}, {}
local function assert_(cond, msg)
    if not cond then
        failures[#failures + 1] = msg
    end
end

-- The loop runs with the collector stopped, so bytes/iter is what the loop allocated and never what
-- a collection happened to free mid-loop, and with the engine mock counting only, so the recorder's
-- own garbage is not charged to the addon.
local function measure(name, iterations, fn)
    resetEngineCalls()
    collectgarbage("collect"); collectgarbage("collect")
    mocks.__countOnly = true
    collectgarbage("stop")
    local kb0 = collectgarbage("count")
    local t0 = os.clock()
    for i = 1, iterations do fn(i) end
    local elapsed = os.clock() - t0
    local kb1 = collectgarbage("count")
    collectgarbage("restart")
    mocks.__countOnly = false
    local r = {
        name = name, iterations = iterations,
        totalMs = elapsed * 1000, msPerIter = elapsed * 1000 / iterations,
        apiPerIter = engineCalls() / iterations,
        bytesPerIter = (kb1 - kb0) * 1024 / iterations,
    }
    results[#results + 1] = r
    return r
end

local containers = #NS.Database.GetContainers()

-- 1. Coalescing: a burst of settings writes (a slider drag, a profile switch) is ONE apply pass.
local BURST = 200
local timersBefore = #mocks.__timers
for i = 1, BURST do NS.SetByPath("container.bars.width", 200 + (i % 50), 1) end
local armed = #mocks.__timers - timersBefore
mocks.__fireTimers()
assert_(armed == 1, ("coalescing: %d writes armed %d apply passes, expected 1"):format(BURST, armed))

-- 2. Compile: the pure filter compiler for one container.
local cfg1 = NS.Database.FindContainer(1)
measure("compile", 2000, function() NS.FilterCompiler.Compile(cfg1, { timedSpells = {} }) end)

-- 3. An unchanged apply of every container: live-editable, so nothing that re-gathers auras may be
--    re-sent — a filter string or candidate filters sent again costs the engine a full re-scan.
local applyPass = measure("applyPass", 200, function()
    CM.RequestApply()
    CM.FlushPending()
end)
assert_(callsNamed("SetAuraGroupFilterString") == 0, "an unchanged apply re-sent filter strings")
assert_(callsNamed("SetAuraGroupCandidateFilters") == 0, "an unchanged apply re-sent candidate filters")
assert_(callsNamed("AddAuraGroup") == 0, "an unchanged apply rebuilt an engine")

-- 4. A restyle of one container with ten live buttons.
local inst1 = CM.instances[1]
inst1.engine.__frames.g1 = {}
for i = 1, 10 do inst1.engine.__frames.g1[i] = mocks.__stubFrame() end
measure("restyle", 200, function() inst1:Restyle(cfg1) end)

-- 4b. A restyle of the text starter with ten live buttons: a same-shape re-dress, which builds no font
--     string, no frame and no animation group, and re-binds each field once per button.
local textCfg
for _, c in ipairs(NS.Database.GetContainers()) do
    if c.style == "text" then textCfg = c end
end
assert_(textCfg ~= nil, "restyleText: no text container among the starters")
if textCfg then
    local instText = CM.instances[textCfg.id]
    local key = instText.plan.groups[1].key
    instText.engine.__frames[key] = {}
    for i = 1, 10 do instText.engine.__frames[key][i] = mocks.__stubFrame() end
    instText:Restyle(textCfg)   -- the first dress builds the regions; the loop measures the re-dress
    local frames = 0
    local create = mocks.CreateFrame
    mocks.CreateFrame = function(...) frames = frames + 1; return create(...) end
    local measuredBefore = measured
    measure("restyleText", 200, function() instText:Restyle(textCfg) end)
    mocks.CreateFrame = create
    -- red under: Size to fit without its memo (every dressed button re-measures every sample line)
    assert_(measured == measuredBefore,
        ("restyleText: a same-settings re-dress measured %d string(s)"):format(measured - measuredBefore))
    -- red under: useChain rebuilding the chain on every dress
    assert_(frames == 0, ("restyleText: a same-shape re-dress built %d frame(s)"):format(frames))
end

-- 5. The visibility pass every combat transition runs.
local visibility = measure("visibilityPass", 1000, function() CM.ApplyVisibility() end)
assert_(visibility.apiPerIter == containers,
    ("visibilityPass makes %.1f engine calls, expected %d (one SetEnabled per container)")
        :format(visibility.apiPerIter, containers))

-- 6. A target swap: the one path ordinary combat activity drives.
local targets = 0
for _, c in ipairs(NS.Database.GetContainers()) do if c.unit == "target" then targets = targets + 1 end end
local swap = measure("unitSwap", 1000, function() NS.addon:OnUnitSwap("PLAYER_TARGET_CHANGED") end)
assert_(swap.apiPerIter == targets,
    ("unitSwap makes %.1f engine calls, expected %d (one UpdateAllAuras per target container)")
        :format(swap.apiPerIter, targets))

-- 7. Probe overhead: the instrumentation must be free when capture is off. "Free" is measured
--    against the same bodies with no brackets at all (performance-§9): probeAbsent is exactly
--    CM.ApplyVisibility plus addon:OnUnitSwap("PLAYER_TARGET_CHANGED") minus their brackets.
local off = measure("probeOverheadOff", 1000, function() CM.ApplyVisibility(); NS.addon:OnUnitSwap("PLAYER_TARGET_CHANGED") end)
NS.Perf.on = true
local on = measure("probeOverheadOn", 1000, function() CM.ApplyVisibility(); NS.addon:OnUnitSwap("PLAYER_TARGET_CHANGED") end)
NS.Perf.on = false
local absent = measure("probeAbsent", 1000, function()
    for _, inst in pairs(CM.instances) do inst:ApplyVisibility() end
    CM.RefreshUnit("target")
end)
assert_(off.apiPerIter == on.apiPerIter, "the probe changed how many engine calls a pass makes")
assert_(off.apiPerIter == absent.apiPerIter,
    ("a dormant bracket changed the engine calls: %.1f vs %.1f with no bracket")
        :format(off.apiPerIter, absent.apiPerIter))
-- red under: a table built beside the dormant `t0` in CM.ApplyVisibility.
assert_(off.bytesPerIter <= absent.bytesPerIter,
    ("a dormant bracket allocated: %.1f B/iter vs %.1f with no bracket")
        :format(off.bytesPerIter, absent.bytesPerIter))

-- 8. TimedSpells hears UNIT_AURA on its own frame, registered with RegisterUnitEvent for player and
--    pet only (events-frames-taint-§1's carve-out). The client applies that filter before Lua runs,
--    so `deliver` below does the same from the frame's recorded unit list: a nameplate's UNIT_AURA
--    must never reach the handler, and the player's (with its scan already queued, so the loop
--    measures the latched path) must allocate nothing.
NS.SetByPath("container.filter.durationMode", "timeless", 1)
mocks.__fireTimers(); mocks.__fireTimers()
local unitFrame = NS.TimedSpells.unitFrame
local auraUnits = unitFrame and unitFrame.__unitEvents.UNIT_AURA
assert_(auraUnits ~= nil, "unitAuraFiltered: TimedSpells did not register UNIT_AURA on its unit frame")
if auraUnits then
    assert_(table.concat(auraUnits, ",") == "player,pet",
        ("unitAuraFiltered: UNIT_AURA registered for {%s}, expected {player,pet}"):format(table.concat(auraUnits, ",")))
    local onEvent = unitFrame.__scripts.OnEvent
    local reached = 0
    local function handler(f, event, unit) reached = reached + 1; return onEvent(f, event, unit) end
    -- The client's dispatch: the OnEvent script runs only for a unit the registration names.
    local nUnits = #auraUnits
    local function deliver(unit)
        for i = 1, nUnits do
            if auraUnits[i] == unit then return handler(unitFrame, "UNIT_AURA", unit) end
        end
    end
    for _ = 1, 1000 do deliver("nameplate1") end
    assert_(reached == 0, ("unitAuraFiltered: a nameplate's UNIT_AURA reached the handler %d time(s)"):format(reached))
    deliver("player")   -- queue the one scan; the measured loop is the latched path
    local timersBeforeAura = #mocks.__timers
    local filtered = measure("unitAuraFiltered", 1000, function() deliver("player") end)
    assert_(#mocks.__timers == timersBeforeAura,
        ("unitAuraFiltered: repeated player UNIT_AURA armed %d more timer(s)"):format(#mocks.__timers - timersBeforeAura))
    -- red under: a table built at the top of TimedSpells' onUnitAura or its frame's OnEvent.
    assert_(filtered.bytesPerIter == 0,
        ("unitAuraFiltered: a player UNIT_AURA allocated %.1f B/iter"):format(filtered.bytesPerIter))
    mocks.__fireTimers()
end

for _, r in ipairs(results) do
    assert_(r.bytesPerIter >= 0, ("%s reports negative bytes per iteration (%.1f)"):format(r.name, r.bytesPerIter))
end

-- ── report ──────────────────────────────────────────────────────────────────────────────────

print(("Ka0s Aura Master — offline perf  (v%s, label '%s')"):format(NS.version, opts.label))
print(("%d writes coalesced into %d apply pass%s; %d containers"):format(BURST, armed,
    armed == 1 and "" or "es", containers))
print()
print(("%-18s %10s %12s %12s %12s"):format("scenario", "iters", "ms/iter", "api/iter", "bytes/iter"))
for _, r in ipairs(results) do
    print(("%-18s %10d %12.5f %12.1f %12.1f"):format(r.name, r.iterations, r.msPerIter, r.apiPerIter, r.bytesPerIter))
end
print()
print("timings are for orientation only — compare scenarios within a run, never across machines")
print(("applyPass: %.1f engine calls per pass over %d containers"):format(applyPass.apiPerIter, containers))

local failed = #failures
if failed > 0 then
    print()
    print(("%d assertion%s FAILED:"):format(failed, failed == 1 and "" or "s"))
    for _, f in ipairs(failures) do print("  - " .. f) end
end

if opts.out then
    local buckets = {}
    for _, r in ipairs(results) do
        buckets[r.name] = { calls = r.iterations, totalMs = r.totalMs, maxMs = r.msPerIter,
            apiPerIter = r.apiPerIter, bytesPerIter = r.bytesPerIter }
    end
    local record = {
        schema = NS.Perf.SCHEMA, addon = "AuraMaster", source = "offline", version = NS.version,
        interface = 0, timestamp = os.time(), label = opts.label, buckets = buckets,
        fps = {
            active    = { seconds = 0, frames = 0, avgFps = 0, msPerFrame = 0 },
            suspended = { seconds = 0, frames = 0, avgFps = 0, msPerFrame = 0 },
            deltaMsPerFrame = 0,
        },
        coalescing = { events = BURST, repaints = armed },
        failures = failures,
    }
    local fh, err = io.open(opts.out, "w")
    if not fh then
        io.stderr:write("cannot write " .. opts.out .. ": " .. tostring(err) .. "\n")
        os.exit(2)
    end
    fh:write(NS.Perf.EncodeJSON(record), "\n")
    fh:close()
    print("wrote " .. opts.out)
end

os.exit(failed == 0 and 0 or 1)
