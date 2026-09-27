-- tests/test_namerepaint.lua - the blank bar name repaint (issue #24): which containers show a name
-- the aura engine writes (Style.ShowsEngineName), so only those are ever repainted. The engine writes
-- a bar's spell name on assign or update only, and a name still nil on first sighting stays blank
-- (docs/superpowers/research/2026-09-27-blank-bar-names-findings.md).

local T = _G.AM_TEST
local test, assertTrue, assertFalse = T.test, T.assertTrue, T.assertFalse
local NS = T.NS

local function cfg(over)
    return NS.Database.Merge(NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE), over or {})
end

-- -- the predicate -----------------------------------------------------------------------------

test("names: a bars container shows the engine's name by default", function()
    -- red under: the bars arm answering false (no bar container is ever repainted)
    assertTrue(NS.Style.ShowsEngineName(cfg({ style = "bars" })))
end)

test("names: a bars container with its name hidden shows none", function()
    -- red under: the bars arm ignoring bars.name.show (a no-name container repainted for nothing)
    assertFalse(NS.Style.ShowsEngineName(cfg({ style = "bars", bars = { name = { show = false } } })))
end)

test("names: an unknown style counts as bars, as Style.StyleKey draws it", function()
    -- red under: matching cfg.style == "bars" instead of Style.StyleKey (a removed style never repainted)
    assertTrue(NS.Style.ShowsEngineName(cfg({ style = "retired" })))
    assertFalse(NS.Style.ShowsEngineName(cfg({ style = "retired", bars = { name = { show = false } } })))
end)

test("names: an icons container never shows a name", function()
    -- red under: icons falling through to the bars arm (every icons container repainted)
    assertFalse(NS.Style.ShowsEngineName(cfg({ style = "icons" })))
end)

test("names: a text container shows a name only when its template has the name token", function()
    -- red under: the text arm answering true for any template (a name-free line repainted)
    assertTrue(NS.Style.ShowsEngineName(cfg({ style = "text", text = { template = "$spellname$ x$stacks$" } })))
    assertFalse(NS.Style.ShowsEngineName(cfg({ style = "text", text = { template = "x$stacks$" } })))
end)

test("names: an escaped $$spellname$$ is literal text, not the name token", function()
    -- red under: a string search for "spellname" instead of the compiled pieces
    assertFalse(NS.Style.ShowsEngineName(cfg({ style = "text", text = { template = "$$spellname$$ $stacks$" } })))
end)

test("names: the name token is found in any case", function()
    -- red under: a case-sensitive search for "$spellname$"
    assertTrue(NS.Style.ShowsEngineName(cfg({ style = "text", text = { template = "$SpellName$[ x$stacks$]" } })))
end)

test("names: a refused text template draws the default, which has a name", function()
    -- red under: Style.Text compiled with TT.Compile instead of Text.Compiled (a refusal has no pieces)
    local c = cfg({ style = "text", text = { template = "x$stacks$ $foo$" } })
    assertFalse(NS.TextTemplate.Compile(c.text.template).ok, "the template is refused")
    assertTrue(NS.Style.ShowsEngineName(c))
    c.text = nil
    assertTrue(NS.Style.ShowsEngineName(c), "an absent text block draws the default too")
end)

-- -- the repaint: listening, timers and the pass (modules/NameRepaint.lua) -----------------------
-- Wired: CM.FlushPending and CM.ApplyVisibility end in NameRepaint.Sync, so a settings write that is
-- flushed is already synced. A case that calls Sync itself is running it early on purpose.

local fresh = dofile("tests/fresh_env.lua")
local assertEqual, assertNil = T.assertEqual, T.assertNil

--- A fresh environment on the starter containers (1: player bars, 2: player icons, 3: target icons,
--- 4: player text with the name token), settled: the startup flush has synced. `before` is fresh_env's.
local function env(before)
    local NS2, mocks = fresh({ before = before })
    mocks.__fireTimers(); mocks.__fireTimers()
    return NS2, mocks, NS2.NameRepaint, NS2.ContainerManager
end

--- A settings write, flushed: the flush ends in Sync.
local function write(NS2, mocks, path, value, id)
    NS2.SetByPath(path, value, id)
    mocks.__fireTimers(); mocks.__fireTimers()
end

local function auraUnits(NR, i)
    local f = NR.unitFrames and NR.unitFrames[i]
    local units = f and f.__unitEvents.UNIT_AURA
    return units and table.concat(units, ",") or nil
end

--- Frame `i`'s OnEvent, called as the client calls it.
local function fireAura(NR, i, unit)
    local f = NR.unitFrames[i]
    f.__scripts.OnEvent(f, "UNIT_AURA", unit)
end

--- The timers still waiting, canceled ones left out (the kit's live set, in arming order).
local function queued(mocks)
    return mocks.__timers()
end

local function delays(mocks)
    local out = {}
    for i, t in ipairs(queued(mocks)) do
        out[i] = tostring(t.delay)
    end
    return table.concat(out, ",")
end

--- Each live container's UpdateAllAuras count, by id.
local function paintCounts(CM)
    local out = {}
    for id, inst in pairs(CM.instances) do
        out[id] = inst.engine and (inst.engine.__counts.UpdateAllAuras or 0) or 0
    end
    return out
end

--- The ids whose UpdateAllAuras count rose since `before`, sorted and joined.
local function repainted(CM, before)
    local ids = {}
    for id, n in pairs(paintCounts(CM)) do
        if n > (before[id] or 0) then
            ids[#ids + 1] = id
        end
    end
    table.sort(ids)
    return table.concat(ids, ",")
end

-- Sync

test("repaint: the player frame registers only the units a name-showing container tracks", function()
    local _, _, NR = env()
    -- red under: Sync registering both units of a frame whatever is wanted (the pet heard for nothing)
    assertEqual(auraUnits(NR, 1), "player", "player bars and text; no pet container")
    -- red under: an icons container counted as wanted (the starter target icons open the second frame)
    assertNil(auraUnits(NR, 2), "the target container is icons: nothing on the second frame")
end)

test("repaint: a name-showing target or focus container opens the second frame, and its loss closes it", function()
    local NS2, mocks, NR = env()
    write(NS2, mocks, "container.style", "bars", 3)
    assertEqual(auraUnits(NR, 2), "target")
    write(NS2, mocks, "container.unit", "focus", 2)
    write(NS2, mocks, "container.style", "bars", 2)
    assertEqual(auraUnits(NR, 2), "target,focus")
    write(NS2, mocks, "container.enabled", false, 3)
    assertEqual(auraUnits(NR, 2), "focus", "a disabled container is not wanted")
    write(NS2, mocks, "container.style", "icons", 2)
    -- red under: a frame left registered once no unit of its pair is wanted
    assertNil(auraUnits(NR, 2), "closed")
end)

test("repaint: Sync is idempotent and registers again only when a frame's pair changes", function()
    local NS2, mocks, NR = env()
    local f = NR.unitFrames[1]
    local calls, register = 0, f.RegisterUnitEvent
    rawset(f, "RegisterUnitEvent", function(...) calls = calls + 1; return register(...) end)
    for _ = 1, 5 do NR.Sync() end
    -- red under: Sync re-registering on every call (it runs on every visibility pass)
    assertEqual(calls, 0, "unchanged pair: nothing registered")
    write(NS2, mocks, "container.unit", "pet", 2)
    write(NS2, mocks, "container.style", "bars", 2)
    assertEqual(calls, 1, "pet joined: registered once")
    assertEqual(auraUnits(NR, 1), "player,pet")
end)

test("repaint: each frame is created hidden", function()
    local NS2, mocks, NR = env()
    write(NS2, mocks, "container.style", "bars", 3)
    -- red under: a frame left shown (the kit counts a shown parentless frame as on screen)
    assertFalse(NR.unitFrames[1]:IsShown())
    assertFalse(NR.unitFrames[2]:IsShown())
end)

test("repaint: while stood down Sync closes both frames and arms nothing", function()
    local NS2, mocks, NR = env()
    fireAura(NR, 1, "player")
    NS2.SetByPath("enabled", false)
    NR.Sync()
    -- red under: Sync without the stood-down gate (the stand-down's own visibility pass reopens it)
    assertNil(auraUnits(NR, 1), "closed")
    assertEqual(#queued(mocks), 0, "the armed timer canceled")
end)

--- Stub the stand-down latch on `NS2` without the Stop a stand-down runs, so the frames stay held
--- and each gate is reached on its own. Returns the restore.
local function standDown(NS2)
    local real = NS2.IsStoodDown
    NS2.IsStoodDown = function() return true end
    return function() NS2.IsStoodDown = real end
end

test("repaint: while stood down Arm and OnEnterWorld arm nothing, even with the frames still held", function()
    local NS2, mocks, NR = env()
    local restore = standDown(NS2)
    assertEqual(auraUnits(NR, 1), "player", "held: listened() alone would let it through")
    NR.Arm("player")
    NR.OnEnterWorld()
    restore()
    -- red under: Arm or OnEnterWorld with no stood-down gate
    assertEqual(#queued(mocks), 0, "nothing arms while stood down")
end)

test("repaint: a QUICK or SETTLE that fires after a stand-down repaints nothing and rearms nothing", function()
    local NS2, mocks, NR, CM = env()
    fireAura(NR, 1, "player")
    local restore = standDown(NS2)
    local before = paintCounts(CM)
    assertEqual(mocks.__fireTimers(), 1)
    restore()
    -- red under: onFirst without the stood-down gate (a queued QUICK repaints and arms SETTLE)
    assertEqual(repainted(CM, before), "")
    assertEqual(#queued(mocks), 0, "QUICK: no SETTLE")
    fireAura(NR, 1, "player")
    mocks.__fireTimers()
    fireAura(NR, 1, "player")
    restore = standDown(NS2)
    before = paintCounts(CM)
    assertEqual(mocks.__fireTimers(), 1)
    restore()
    -- red under: onSettle without the stood-down gate (a dirty SETTLE repaints and rearms)
    assertEqual(repainted(CM, before), "")
    assertEqual(#queued(mocks), 0, "SETTLE: not rearmed")
end)

test("repaint: Stop closes both frames and cancels every timer, and the next Sync starts clean", function()
    local NS2, mocks, NR = env()
    write(NS2, mocks, "container.style", "bars", 3)
    fireAura(NR, 1, "player"); fireAura(NR, 1, "player"); fireAura(NR, 2, "target")
    NR.Stop()
    -- red under: Stop leaving a frame registered or a timer armed
    assertNil(auraUnits(NR, 1)); assertNil(auraUnits(NR, 2))
    assertEqual(mocks.__fireTimers(), 0, "no timer left to wake up")
    NR.Sync()
    fireAura(NR, 1, "player")
    mocks.__fireTimers()
    -- red under: Stop canceling a timer but keeping its handle (the next UNIT_AURA only marks dirty)
    assertEqual(delays(mocks), "2", "QUICK fired: one SETTLE")
    mocks.__fireTimers()
    assertEqual(#queued(mocks), 0, "quiet: done")
end)

test("repaint: a unit that stops being wanted loses its armed timer", function()
    local NS2, mocks, NR = env()
    write(NS2, mocks, "container.style", "bars", 3)
    fireAura(NR, 2, "target")
    assertEqual(delays(mocks), "0.5", "the target timer is armed")
    -- The write is stored at once and its flush queued (delay 0); Sync runs here, ahead of that flush.
    NS2.SetByPath("container.style", "icons", 3)
    NR.Sync()
    -- red under: Sync closing the frame but leaving the unit's timer armed
    assertNil(delays(mocks):find("0.5", 1, true), "only the queued flush is left: " .. delays(mocks))
end)

test("repaint: a refused UNIT_AURA registration leaves the unit unheard and unarmed, and the next Sync retries", function()
    local NS2, mocks, NR = env()
    fireAura(NR, 1, "player")
    assertEqual(delays(mocks), "0.5", "player armed before the refusal")
    local f = NR.unitFrames[1]
    local register = f.RegisterUnitEvent
    rawset(f, "RegisterUnitEvent", function() error('Attempt to register unknown event "UNIT_AURA"') end)
    write(NS2, mocks, "container.unit", "pet", 2)
    write(NS2, mocks, "container.style", "bars", 2)
    -- red under: setFrame storing the wanted units whatever the registration answered (a frame that
    -- hears nothing reported as listening, and Sync never trying again)
    assertNil(auraUnits(NR, 1), "nothing registered")
    assertEqual(#NR.DiagState().listening, 0, "the report names no unit")
    assertEqual(#NR.DiagState().armed, 0, "the player's armed timer canceled")
    local seen = 0
    for _, name in ipairs(NS2.RejectedEvents) do
        if name == "UNIT_AURA" then seen = seen + 1 end
    end
    assertEqual(seen, 1, "UNIT_AURA recorded once")
    NR.Arm("player")
    assertEqual(#queued(mocks), 0, "an unheard unit arms nothing")
    rawset(f, "RegisterUnitEvent", register)
    NR.Sync()
    assertEqual(auraUnits(NR, 1), "player,pet", "the next Sync retried")
end)

-- the handler

test("repaint: a UNIT_AURA burst arms one QUICK timer per unit, and nothing runs inside the handler", function()
    local _, mocks, NR, CM = env()
    local before = paintCounts(CM)
    for _ = 1, 20 do fireAura(NR, 1, "player") end
    -- red under: a timer per event (no coalescing), or a repaint inside the handler
    assertEqual(delays(mocks), "0.5")
    assertEqual(repainted(CM, before), "")
    assertEqual(mocks.__fireTimers(), 1)
    assertEqual(delays(mocks), "2", "QUICK fired: one SETTLE")
    assertEqual(mocks.__fireTimers(), 1)
    -- red under: onFirst keeping the QUICK-window dirty mark (the burst rearms SETTLE after it fires)
    assertEqual(#queued(mocks), 0, "a burst inside QUICK: QUICK, one SETTLE, done")
end)

test("repaint: a unit outside the frame's registered pair arms nothing", function()
    local NS2, mocks, NR = env()
    write(NS2, mocks, "container.style", "bars", 3)
    -- red under: the handler trusting the unit argument (the kit's __fire does not filter by unit)
    fireAura(NR, 1, "nameplate1")
    fireAura(NR, 1, "target")
    fireAura(NR, 1, "pet")
    fireAura(NR, 2, "focus")
    assertEqual(#queued(mocks), 0)
end)

test("repaint: an unreadable unit argument schedules the units that frame registered", function()
    local SECRET = {}
    local NS2, mocks, NR = env(function(m) m.issecretvalue = function(v) return v == SECRET end end)
    write(NS2, mocks, "container.style", "bars", 3)
    write(NS2, mocks, "container.unit", "focus", 2)
    write(NS2, mocks, "container.style", "bars", 2)
    fireAura(NR, 2, SECRET)
    -- red under: a secret unit used as a key, or dropped (a secret unit arms nothing)
    assertEqual(delays(mocks), "0.5,0.5", "target and focus")
    fireAura(NR, 2, nil)
    assertEqual(#queued(mocks), 2, "a nil unit is unreadable too, and folds into the armed timers")
end)

-- the timers

test("repaint: QUICK repaints and always arms SETTLE; a quiet SETTLE repaints once more and stops", function()
    local _, mocks, NR, CM = env()
    fireAura(NR, 1, "player")
    local before = paintCounts(CM)
    assertEqual(mocks.__fireTimers(), 1)
    -- red under: QUICK not repainting, or reaching the icons container 2
    assertEqual(repainted(CM, before), "1,4", "player bars and text")
    -- red under: SETTLE armed only when dirty (a late name after QUICK never caught)
    assertEqual(delays(mocks), "2")
    before = paintCounts(CM)
    assertEqual(mocks.__fireTimers(), 1)
    assertEqual(repainted(CM, before), "1,4", "SETTLE repaints too")
    -- red under: SETTLE rearming unconditionally (a quiet unit repainted every 2 s forever)
    assertEqual(#queued(mocks), 0, "quiet: done")
end)

test("repaint: a unit that goes dirty while SETTLE is armed gets another SETTLE", function()
    local _, mocks, NR = env()
    fireAura(NR, 1, "player")
    mocks.__fireTimers()
    fireAura(NR, 1, "player"); fireAura(NR, 1, "player")
    -- red under: an event while armed arming a second timer
    assertEqual(delays(mocks), "2", "only marked dirty")
    mocks.__fireTimers()
    -- red under: the dirty mark ignored when SETTLE fires
    assertEqual(delays(mocks), "2", "rearmed")
    mocks.__fireTimers()
    assertEqual(#queued(mocks), 0, "quiet since: done")
end)

test("repaint: OnEnterWorld arms ENTER for every listened unit, replacing any armed timer", function()
    local NS2, mocks, NR, CM = env()
    write(NS2, mocks, "container.style", "bars", 3)
    fireAura(NR, 1, "player")
    NR.OnEnterWorld()
    -- red under: ENTER beside the armed QUICK instead of replacing it
    assertEqual(delays(mocks), "3,3", "player and target, at ENTER")
    local before = paintCounts(CM)
    assertEqual(mocks.__fireTimers(), 2)
    assertEqual(repainted(CM, before), "1,3,4")
    -- red under: ENTER not following the SETTLE path
    assertEqual(delays(mocks), "2,2")
end)

test("repaint: Arm is bounded to the listened units", function()
    local _, mocks, NR = env()
    NR.Arm("target")
    NR.Arm("nameplate1")
    -- red under: Arm accepting a unit no frame listens for
    assertEqual(#queued(mocks), 0)
    NR.Arm("player")
    assertEqual(delays(mocks), "0.5")
end)

-- the pass

test("repaint: a pass reaches only shown, live, name-showing containers on its unit", function()
    local NS2, mocks, NR, CM = env()
    local before = paintCounts(CM)
    assertEqual(NR.Repaint("player"), 2)
    assertEqual(repainted(CM, before), "1,4")
    write(NS2, mocks, "container.bars.name.show", false, 1)
    before = paintCounts(CM)
    NR.Repaint("player")
    -- red under: the pass ignoring ShowsEngineName (a no-name bars container repainted)
    assertEqual(repainted(CM, before), "4")
    write(NS2, mocks, "container.enabled", false, 4)
    before = paintCounts(CM)
    -- red under: the pass skipping ShouldShow (a disabled engine would clear its auras)
    assertEqual(NR.Repaint("player"), 0)
    assertEqual(repainted(CM, before), "")
end)

test("repaint: a parked, stale, previewing or engine-less container is never repainted", function()
    local NS2, mocks, NR, CM = env()
    local one, four = CM.instances[1], CM.instances[4]
    one.parked = true
    four.staleData = true
    local before = paintCounts(CM)
    -- red under: the staleData gate missing (container 4 repainted). A parked container is also
    -- refused by ShouldShow, so container 1 here does not pin the parked gate; the next case does.
    assertEqual(NR.Repaint("player"), 0)
    assertEqual(repainted(CM, before), "")
    one.parked, four.staleData = nil, nil
    NS2.Preview.SetTestMode(true)
    -- red under: a previewing container repainted (its engine is disabled)
    assertEqual(NR.Repaint("player"), 0, "test mode")
    NS2.Preview.SetTestMode(false)
    mocks.__fireTimers()
    local engine = four.engine
    four.engine = nil
    -- red under: the engine gate missing (Refresh would do nothing, but the pass counts it)
    assertEqual(NR.Repaint("player"), 1, "only the bars container has an engine")
    four.engine = engine
end)

test("repaint: a parked container is skipped even when ShouldShow would answer yes", function()
    local _, _, NR, CM = env()
    local one = CM.instances[1]
    one.parked = true
    rawset(one, "ShouldShow", function() return true, false end)
    local before = paintCounts(CM)
    -- red under: eligible() without its own parked gate (only ShouldShow standing between a parked
    -- container and UpdateAllAuras)
    assertEqual(NR.Repaint("player"), 1, "only the text container")
    assertEqual(repainted(CM, before), "4")
    one.parked, one.ShouldShow = nil, nil
end)

test("repaint: the pass still runs in combat lockdown and while auras are secret", function()
    local NS2, mocks, NR, CM = env()
    mocks.__lockdown = true
    mocks.__aurasSecret = true
    NS2.addon:OnRestrictionChanged()
    NR.Sync()
    assertEqual(auraUnits(NR, 1), "player", "the listener stays open")
    fireAura(NR, 1, "player")
    local before = paintCounts(CM)
    mocks.__fireTimers()
    -- red under: a combat or secrecy gate on the pass (first sightings happen mostly in combat)
    assertEqual(repainted(CM, before), "1,4")
end)

test("repaint: one Names debug line per pass and none per event", function()
    local NS2, mocks, NR = env()
    local lines = {}
    local debug = NS2.Debug
    NS2.Debug = function(tag, fmt, ...)
        if tag == "Names" then
            lines[#lines + 1] = string.format(fmt, ...)
        end
    end
    for _ = 1, 10 do fireAura(NR, 1, "player") end
    -- red under: a trace line per UNIT_AURA
    assertEqual(#lines, 0)
    mocks.__fireTimers()
    assertEqual(#lines, 1)
    assertTrue(lines[1]:find("player", 1, true) ~= nil, lines[1])
    assertTrue(lines[1]:find("quick", 1, true) ~= nil, lines[1])
    assertTrue(lines[1]:find("2", 1, true) ~= nil, "the container count: " .. lines[1])
    mocks.__fireTimers()
    assertEqual(#lines, 2)
    assertTrue(lines[2]:find("settle", 1, true) ~= nil, lines[2])
    NS2.Debug = debug
end)

-- the wiring (NR-03)

test("repaint: a settings flush and a visibility pass each end in Sync", function()
    local NS2, mocks, NR, CM = env()
    NS2.SetByPath("container.style", "bars", 3)
    mocks.__fireTimers()
    -- red under: CM.FlushPending without NameRepaint.Sync (a new name-showing unit never heard)
    assertEqual(auraUnits(NR, 2), "target", "the flush synced")
    NR.Stop()
    CM.ApplyVisibility()
    -- red under: CM.ApplyVisibility without NameRepaint.Sync (standUp would never reopen the frames)
    assertEqual(auraUnits(NR, 1), "player", "the visibility pass synced")
    assertEqual(auraUnits(NR, 2), "target")
end)

test("repaint: disable closes both frames and cancels every timer, even with no visibility pass after", function()
    local NS2, mocks, NR, CM = env()
    write(NS2, mocks, "container.style", "bars", 3)
    fireAura(NR, 1, "player"); fireAura(NR, 2, "target")
    -- The stand-down's own visibility pass would Stop through Sync's gate; take it away, so only the
    -- stand-down's direct Stop is left to do it.
    local visibility = CM.ApplyVisibility
    CM.ApplyVisibility = function() return true end
    NS2.SetByPath("enabled", false)
    CM.ApplyVisibility = visibility
    -- red under: standDown without NameRepaint.Stop (core/LifecycleSetup.lua)
    assertNil(auraUnits(NR, 1)); assertNil(auraUnits(NR, 2))
    assertEqual(#queued(mocks), 0, "no timer left to wake up")
end)

test("repaint: while down a visibility pass, and a pending PLAYER_REGEN_ENABLED, leave both frames closed", function()
    local NS2, mocks, NR, CM = env()
    write(NS2, mocks, "container.style", "bars", 3)
    mocks.__lockdown = true
    NS2.SetByPath("enabled", false)
    assertNil(auraUnits(NR, 1), "closed by the stand-down")
    CM.ApplyVisibility()
    -- red under: Sync without its stood-down gate (the pass reopens what the stand-down closed)
    assertNil(auraUnits(NR, 1)); assertNil(auraUnits(NR, 2))
    mocks.__lockdown = false
    mocks.__fireEvent("PLAYER_REGEN_ENABLED")
    assertTrue(NS2.IsStoodDown())
    assertNil(auraUnits(NR, 1), "the pending secure half's visibility pass reopened nothing")
    assertNil(auraUnits(NR, 2))
    assertEqual(#queued(mocks), 0)
end)

test("repaint: after disable no NameRepaint frame is shown", function()
    local NS2, mocks, NR = env()
    write(NS2, mocks, "container.style", "bars", 3)
    NS2.SetByPath("enabled", false)
    -- red under: a frame shown on the way down (the kit counts a shown parentless frame as on screen)
    assertFalse(NR.unitFrames[1]:IsShown())
    assertFalse(NR.unitFrames[2]:IsShown())
end)

test("repaint: disable then enable brings the registrations back", function()
    local NS2, mocks, NR = env()
    write(NS2, mocks, "container.style", "bars", 3)
    NS2.SetByPath("enabled", false)
    assertNil(auraUnits(NR, 1))
    NS2.SetByPath("enabled", true)
    -- red under: standUp's visibility pass not reaching Sync (the repaint deaf until the next write)
    assertEqual(auraUnits(NR, 1), "player")
    assertEqual(auraUnits(NR, 2), "target")
    fireAura(NR, 1, "player")
    assertTrue(delays(mocks):find("0.5", 1, true) ~= nil, "and it arms again: " .. delays(mocks))
end)

test("repaint: PLAYER_ENTERING_WORLD arms ENTER for every listened unit", function()
    local NS2, mocks, NR = env()
    write(NS2, mocks, "container.style", "bars", 3)
    assertEqual(#queued(mocks), 0, "settled")
    mocks.__fireEvent("PLAYER_ENTERING_WORLD")
    -- red under: addon:OnEnterWorld without NameRepaint.OnEnterWorld (login blanks kept to /reload)
    assertEqual(delays(mocks), "3,3", "player and target")
    NS2.SetByPath("enabled", false)
    NR.OnEnterWorld()
    assertEqual(#queued(mocks), 0, "nothing arms while stood down")
end)

test("repaint: a target swap arms target, and its pass reaches only target containers", function()
    local NS2, mocks, NR, CM = env()
    write(NS2, mocks, "container.style", "bars", 3)
    mocks.__fireEvent("PLAYER_TARGET_CHANGED")
    -- red under: OnUnitSwap without NameRepaint.Arm (an NPC's static buff never repainted)
    assertEqual(delays(mocks), "0.5")
    local before = paintCounts(CM)
    mocks.__fireTimers()
    assertEqual(repainted(CM, before), "3")
    assertEqual(NR.Repaint("focus"), 0, "no focus container")
end)

test("repaint: a focus swap arms focus alone, and its pass reaches only focus containers", function()
    local NS2, mocks, NR, CM = env()
    write(NS2, mocks, "container.style", "bars", 3)
    write(NS2, mocks, "container.unit", "focus", 2)
    write(NS2, mocks, "container.style", "bars", 2)
    assertEqual(auraUnits(NR, 2), "target,focus", "both listened: a wrong unit would arm too")
    mocks.__fireEvent("PLAYER_FOCUS_CHANGED")
    -- red under: OnUnitSwap arming target on every swap, or dropping the focus branch
    local armed = NR.DiagState().armed
    assertEqual(table.concat(armed, ","), "focus:quick")
    local before = paintCounts(CM)
    mocks.__fireTimers()
    assertEqual(repainted(CM, before), "2")
end)

test("repaint: a pet swap arms pet", function()
    local NS2, mocks = env()
    write(NS2, mocks, "container.unit", "pet", 2)
    write(NS2, mocks, "container.style", "bars", 2)
    mocks.__fireEvent("UNIT_PET", "target")
    assertEqual(#queued(mocks), 0, "another unit's pet changed")
    mocks.__fireEvent("UNIT_PET", "player")
    -- red under: OnUnitPet without NameRepaint.Arm
    assertEqual(delays(mocks), "0.5")
    local CM = NS2.ContainerManager
    local before = paintCounts(CM)
    mocks.__fireTimers()
    assertEqual(repainted(CM, before), "2")
end)
