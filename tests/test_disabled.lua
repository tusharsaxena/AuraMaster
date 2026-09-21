-- tests/test_disabled.lua — the stand-down conformance suite (slash-commands-§7).
--
-- WHAT THIS SUITE IS FOR, AND WHAT IT REFUSES TO ASSERT ON. Disabled means the addon is NOT RUNNING
-- — not hidden, not quiet, not skipping a repaint. Eleven addons in this collection, this one among
-- them, used to implement it as a DRAW GATE: a stored boolean read as one rung of a show ladder,
-- handlers that early-return, and every event, message and bucket still registered underneath. From
-- outside those two are indistinguishable, which is how the draw gate survived eleven audits, and a
-- case written as "call the handler and assert it returned early" CANNOT tell them apart — an early
-- return is exactly what a draw gate does. Such a case would certify the bug it exists to catch.
--
-- So every negative assertion here is made against the kit's REGISTRATION SET (`__registrations`),
-- its LIVE TIMER SET (`__timers()`), its SHOWN FRAMES, its SavedVariables writes and its printed
-- lines. Those five lose entries when the addon gives something up, which is the half that matters.
-- Nothing below asserts on a return value.
--
-- The one seam it drives is the one a player drives: `NS.SetByPath("enabled", …)`, the addon's
-- single write seam (architecture-§5), which is what the Master controls checkbox and `/am enable`
-- both go through. A case calling `standDown()` directly would be testing a function rather than
-- the switch.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")

-- ---------------------------------------------------------------------------
-- Reading the five records
-- ---------------------------------------------------------------------------

--- The registration set as a COUNTED MULTISET keyed `kind:event`, so two subscribers to one message
--- are two entries. Counted rather than a plain set because the interesting failure is a partial
--- stand-down: one of the two CONFIG_CHANGED subscriptions dropped and the other left alive reads
--- as "still registered" either way, and only the count says which.
local function regs(mocks)
    local out = {}
    for _, r in ipairs(mocks.__registrations()) do
        local key = r.kind .. ":" .. tostring(r.event) .. (r.unit and (":" .. r.unit) or "")
        out[key] = (out[key] or 0) + 1
    end
    return out
end

local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do
        local n = #keys
        keys[n + 1] = k
    end
    table.sort(keys)
    return keys
end

local function dumpRegs(t)
    local out = {}
    for _, k in ipairs(sortedKeys(t)) do
        local n = #out
        out[n + 1] = k .. "x" .. t[k]
    end
    return "{" .. table.concat(out, " | ") .. "}"
end

local function sameRegs(a, b)
    local na = #sortedKeys(a)
    local nb = #sortedKeys(b)
    if na ~= nb then return false end
    for k, n in pairs(a) do if b[k] ~= n then return false end end
    return true
end

--- Every registration whose target is `target`, by name.
local function regsOn(mocks, target)
    local out = {}
    for _, r in ipairs(mocks.__registrations()) do
        if r.target == target then
            local n = #out
            out[n + 1] = r.kind .. ":" .. tostring(r.event)
        end
    end
    table.sort(out)
    return out
end

local function capture(mocks)
    local lines = {}
    rawset(mocks.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
        lines[#lines + 1] = tostring(msg)
    end)
    return lines
end

local function strip(s)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return (s:gsub("^%[AM%] ", ""))
end

local function plain(lines)
    local out = {}
    for i, l in ipairs(lines) do out[i] = strip(l) end
    return out
end

local function clear(lines)
    for k in pairs(lines) do lines[k] = nil end
end

local function dump(p) return "{" .. table.concat(p, " | ") .. "}" end

--- Run one `/am` line and answer what it printed, plain.
local function slash(NS, lines, msg)
    clear(lines)
    NS.Slash:OnSlash(msg)
    return plain(lines)
end

local function said(p, text)
    for _, l in ipairs(p) do if l == text then return true end end
    return false
end

-- The collection's one refusal line, as LibKa0s-Slash-1.0 builds it from `brandName` and `slash`
-- (slash-commands-§7). Spelled out rather than read back off the dispatcher: a suite that asked the
-- code under test for the expected answer would pass on any wording at all.
local REFUSAL = "Ka0s Aura Master is disabled — enable it with /am enable"

--- Bring the addon up enabled and take the three baseline snapshots step 1 asks for. `broker`
--- installs the LibDataBroker / LibDBIcon fakes so the launcher's OnClick can be driven.
local function baseline(broker)
    local rec = { objects = {} }
    local opts = broker and { before = function(mocks)
        local LDB = mocks.LibStub:NewLibrary("LibDataBroker-1.1", 4)
        LDB.NewDataObject = function(_, name, obj) rec.objects[name] = obj; return obj end
        LDB.GetDataObjectByName = function(_, name) return rec.objects[name] end
        local Icon = mocks.LibStub:NewLibrary("LibDBIcon-1.0", 45)
        Icon.Register, Icon.Show, Icon.Hide = function() end, function() end, function() end
        Icon.IsRegistered = function() return true end
    end } or nil
    local NS, mocks = fresh(opts)
    mocks.__fireTimers()
    return NS, mocks, regs(mocks), mocks.__timers(), mocks.__shownFrames(), rec
end

--- Disable through the SINGLE WRITE SEAM — never by calling the teardown directly. The checkbox and
--- the verb both take this route, and a case that took a shorter one would leave the route the
--- player takes untested.
local function disable(NS) NS.SetByPath("enabled", false) end
local function enable(NS) NS.SetByPath("enabled", true) end

-- ---------------------------------------------------------------------------
-- 1-3. The registration set
-- ---------------------------------------------------------------------------

test("disabled: enabled, the addon registers a non-empty set", function()
    local NS, mocks, R_on = baseline()
    assertTrue(#sortedKeys(R_on) > 0, "an addon that registers nothing when enabled would pass every later case trivially")
    -- Named, so the baseline cannot silently shrink to one row and keep this case green.
    assertEqual(#regsOn(mocks, NS.addon), 8, "the eight lifecycle events: " .. dump(regsOn(mocks, NS.addon)))
    assertTrue(#regsOn(mocks, NS.TimedSpells.__bus()) == 2, "TimedSpells' two subscriptions")
end)

test("disabled: every registration the addon owns is UNREGISTERED, not gated", function()
    local NS, mocks = baseline()
    disable(NS)

    -- red under: drop the UnregisterLifecycleEvents in core/LifecycleSetup.lua's standDown, or put
    -- the disabled check back inside the handlers as an early return. THIS IS THE ASSERTION THE
    -- WHOLE SUITE EXISTS FOR — it is what tells a stand-down apart from a draw gate, because a
    -- handler that early-returns leaves every one of these rows in place.
    assertEqual(#regsOn(mocks, NS.addon), 0,
        "the addon target still watches " .. dump(regsOn(mocks, NS.addon)))
    assertEqual(#regsOn(mocks, NS.TimedSpells.__events()), 0,
        "TimedSpells still watches " .. dump(regsOn(mocks, NS.TimedSpells.__events())))
    assertEqual(#regsOn(mocks, NS.TimedSpells.__bus()), 0,
        "TimedSpells is still subscribed " .. dump(regsOn(mocks, NS.TimedSpells.__bus())))
    assertFalse(NS.ContainerManager.__listening(), "ContainerManager is still subscribed")

    -- And by COUNT over the whole build: what is left is the SETUP that slash-commands-§7 names,
    -- and nothing else. The settings panel keeps one subscription so the tree it is listed in stays
    -- correct while the addon is off; that is the whole of the survivor list here.
    assertEqual(dumpRegs(regs(mocks)), "{message:Ka0s_AuraMaster_ContainersChangedx1}")
end)

test("disabled: what MUST survive does — the dispatcher, the panel, AceDB and the launcher", function()
    local NS, mocks = baseline()
    local lines = capture(mocks)
    disable(NS)

    -- The switch has to go both ways, so none of these is a feature.
    assertTrue(type(NS.Slash.OnSlash) == "function", "the dispatcher")
    assertTrue(type(NS.addon.RegisterChatCommand) == "function", "the chat command registration")
    assertTrue(#NS.COMMANDS > 0, "the COMMANDS table")
    assertTrue(NS.db ~= nil and NS.db.profile ~= nil, "the AceDB handle")
    assertTrue(type(NS.Launcher.Object) == "function", "the launcher")
    assertTrue(NS.OpenOptionsPanel ~= nil, "the settings panel opener")
    -- The panel is still reachable, which is what replaces nothing here: `config` answers too.
    local opened = 0
    NS.OpenOptionsPanel = function() opened = opened + 1 end
    slash(NS, lines, "config")
    assertEqual(opened, 1)
end)

-- ---------------------------------------------------------------------------
-- 4-5. Timers and frames
-- ---------------------------------------------------------------------------

test("disabled: nothing is left armed, and nothing arms itself afterwards", function()
    local NS, mocks = baseline()
    disable(NS)
    -- Drain whatever one-shot was already in flight when the switch flipped: C_Timer.After hands
    -- back no handle, so a tick already queued cannot be canceled, only made to find nothing.
    mocks.__fireTimers()

    -- red under: drop the NS.IsStoodDown guard at the top of CM.RequestApply, which re-arms the
    -- coalescing C_Timer — the shape anti-pattern #85 names as the most expensive of the family.
    assertEqual(#mocks.__timers(), 0, "something is still going to wake up")

    -- Ten frames of a raid's worth of pushing, through the seams that would arm one.
    NS.ContainerManager.RequestApply()
    NS.ContainerManager.RequestApply(NS.Database.GetContainers()[1].id)
    NS.bus:SendMessage(NS.MSG.VISIBILITY_CHANGED)
    NS.bus:SendMessage(NS.MSG.CONFIG_CHANGED, { path = "alpha" })
    assertEqual(#mocks.__timers(), 0, "a stood-down addon armed a timer")
end)

test("disabled: every frame that was shown is hidden, at the source", function()
    local NS, mocks, _, _, F_on = baseline()
    assertTrue(#F_on > 0, "the baseline draws something")
    disable(NS)

    for _, f in ipairs(F_on) do
        assertFalse(f.__shown and true or false, "a frame shown at baseline is still shown")
    end
    assertEqual(#mocks.__shownFrames(), 0, "something of ours is still on screen")

    -- AT THE SOURCE, not imperatively: a hidden frame comes back on a combat transition or a target
    -- swap unless the show ladder itself answers no. red under: make standDown hide the anchors
    -- itself and leave ContainerClass:ShouldShow reading `p.enabled` alone.
    for _, inst in pairs(NS.ContainerManager.instances) do
        assertFalse((inst:ShouldShow()), "the show ladder says yes while the addon is off")
        inst:ApplyVisibility()
    end
    assertEqual(#mocks.__shownFrames(), 0, "a visibility pass re-showed a container")
end)

-- ---------------------------------------------------------------------------
-- 6. Fire everything anyway
-- ---------------------------------------------------------------------------

test("disabled: firing every baseline event writes nothing, says nothing and shows nothing", function()
    local NS, mocks, R_on = baseline()
    local lines = capture(mocks)
    disable(NS)
    mocks.__fireTimers()
    mocks.__resetSvWrites()
    clear(lines)

    -- THE HARNESS CAN STILL DISPATCH. Without this the case below is a claim about the suite rather
    -- than about the addon: __fire over an empty registry runs nothing whether the addon stood down
    -- or the mock lost the ability to fire at all.
    local heard = 0
    local spy = {}
    mocks.LibStub("AceEvent-3.0"):Embed(spy)
    spy:RegisterEvent("PLAYER_REGEN_DISABLED", function() heard = heard + 1 end)
    assertEqual(mocks.__fire("PLAYER_REGEN_DISABLED"), 1, "the mock can still dispatch")
    assertEqual(heard, 1)
    spy:UnregisterAllEvents()

    -- red under: leave any RegisterEvent in place and gate its handler instead. Combat entry is
    -- named explicitly: it is the event that caught an addon in this collection writing
    -- `locked = true` and printing to chat while it was switched off.
    for key in pairs(R_on) do
        local kind, event = key:match("^(%a+):(.+)$")
        if kind == "event" or kind == "frame" or kind == "unit" then
            assertEqual(mocks.__fire(event), 0, event .. " still reached a handler")
        end
    end
    assertEqual(mocks.__fire("PLAYER_REGEN_DISABLED"), 0, "combat entry still reached a handler")
    assertEqual(mocks.__fire("PLAYER_REGEN_ENABLED"), 0)
    assertEqual(mocks.__fire("UNIT_AURA", "player"), 0)

    assertEqual(#mocks.__svWrites(), 0, "a game event wrote SavedVariables while the addon was off")
    assertEqual(#plain(lines), 0, "a game event printed while the addon was off: " .. dump(plain(lines)))
    assertEqual(#mocks.__shownFrames(), 0, "a game event showed a frame while the addon was off")
end)

-- ---------------------------------------------------------------------------
-- 7. The slash surface — NOT the stand-down
-- ---------------------------------------------------------------------------
--
-- Green here says NOTHING about whether the addon is inert; the six cases above are that. What this
-- pins is the surface, which v2.57.0 restored after v2.56.0 narrowed it: every reserved verb
-- answers, the schema CLI reads and repairs, and the BARE `/am` opens the panel — the case that
-- settled it, because the panel is the surface a player switches the addon back on from by hand.

test("disabled: every reserved verb answers, and the bare /am opens the panel", function()
    local NS, mocks = baseline()
    local lines = capture(mocks)
    local opened = 0
    NS.OpenOptionsPanel = function() opened = opened + 1 end
    disable(NS)

    for _, line in ipairs({ "config", "version", "list", "get alpha", "set alpha 0.5",
                            "reset alpha", "debug", "debug off", "perf", "enable", "disable" }) do
        local p = slash(NS, lines, line)
        assertFalse(said(p, REFUSAL), "/am " .. line .. " was refused: " .. dump(p))
    end

    -- THE BARE COMMAND. It runs `config`, in either state.
    opened = 0
    slash(NS, lines, "")
    assertEqual(opened, 1, "the bare /am must open the panel")

    -- `help` prints the index IN FULL, with the line under its header rather than instead of it:
    -- the player has to be able to SEE `enable` to type it.
    local help = slash(NS, lines, "help")
    assertEqual(help[2], REFUSAL, "the line follows the help header: " .. dump(help))
    assertTrue(#help > 20, "and the whole index still prints")

    -- EVERY ENTRY in NS.COMMANDS, through the real dispatcher (slash-commands-§7 step 7), so a verb
    -- added later is classified here rather than skipped. The live set is SPELLED OUT, not read back
    -- off settings/Slash.lua: the twelve reserved verbs plus `containers` and `select`, which aim the
    -- schema CLI. Disabled again before each verb, because `enable` and `resetall` legitimately turn
    -- the addon back on, and a walk without that would test the rest of the table enabled.
    local LIVE = {}
    for _, v in ipairs({ "help", "config", "version", "enable", "disable", "debug", "perf", "get",
                         "set", "list", "reset", "resetall", "containers", "select" }) do LIVE[v] = true end
    local refused = {}
    for _, e in ipairs(NS.COMMANDS) do
        local verb = e[1]
        disable(NS)
        local p = slash(NS, lines, verb == "debug" and "debug off" or verb)
        if LIVE[verb] then
            if verb ~= "help" then assertFalse(said(p, REFUSAL), "/am " .. verb .. " was refused: " .. dump(p)) end
        else
            assertEqual(#p, 1, "/am " .. verb .. " answered " .. dump(p))
            assertEqual(p[1], REFUSAL, "/am " .. verb)
            refused[#refused + 1] = verb
        end
    end
    assertEqual(table.concat(refused, ","), "new,delete,lock,unlock,test,pick,resetposition,forgettimed",
        "exactly the feature verbs refuse")

    -- And `set` really wrote. The point of keeping the schema CLI live is repair, not politeness.
    disable(NS)
    slash(NS, lines, "set alpha 0.25")
    assertEqual(NS.db.profile.alpha, 0.25)
end)

test("disabled: this addon's own feature verbs refuse on one line and reach no write seam", function()
    local NS, mocks = baseline()
    local lines = capture(mocks)
    local id = NS.Database.GetContainers()[1].id
    NS.SetByPath("locked", true)
    disable(NS)
    mocks.__resetSvWrites()

    -- This addon ADOPTS §2's SHOULD, so the suite pins that choice: a later pass that quietly let
    -- the feature verbs act would redden here rather than drift.
    for _, line in ipairs({ "new target debuffs icons", "delete " .. id, "lock", "unlock", "pick",
                            "resetposition", "forgettimed" }) do
        local p = slash(NS, lines, line)
        assertEqual(#p, 1, "/am " .. line .. " answered " .. dump(p))
        assertEqual(p[1], REFUSAL, "/am " .. line)
    end
    assertEqual(#mocks.__svWrites(), 0, "a refused verb still wrote: " .. dump(plain(lines)))
    assertEqual(NS.GetSetting("locked"), true, "the lock moved behind a refusal")
    assertFalse(NS.FramePicker.IsActive(), "the frame picker started behind a refusal")
end)

-- ---------------------------------------------------------------------------
-- 8. The launcher
-- ---------------------------------------------------------------------------

test("disabled: the launcher's left-click is refused and its right-click still opens the panel", function()
    local NS, mocks, _, _, _, rec = baseline(true)
    local lines = capture(mocks)
    local opened = 0
    NS.OpenOptionsPanel = function() opened = opened + 1 end
    disable(NS)
    mocks.__resetSvWrites()
    clear(lines)

    -- The BUTTON stays: `minimap.hide` is a per-installation display preference and says nothing
    -- about whether the addon is running (launcher-§3). What the click does is what changes.
    local obj = rec.objects.AuraMaster
    assertTrue(obj ~= nil and obj.OnClick ~= nil, "the launcher stays registered while disabled")

    -- red under: drop the NS.IsDisabled guard in core/LauncherSetup.lua's onClick. Rung (b)'s left
    -- button drives the preview switch, which is a feature — and a click with no gate at all
    -- rewrites the stored tree of an addon the player switched off.
    obj.OnClick(obj, "LeftButton")
    local p_ = plain(lines)
    assertEqual(#p_, 1, "the left click answered " .. dump(p_))
    assertEqual(p_[1], REFUSAL)
    assertEqual(#mocks.__svWrites(), 0, "a disabled launcher click wrote SavedVariables")
    assertEqual(#mocks.__shownFrames(), 0, "a disabled launcher click showed a frame")
    assertEqual(opened, 0)

    -- RIGHT-CLICK IS UNCHANGED in either state: it opens the panel, which slash-commands-§7 lists
    -- among the things that survive a stand-down.
    obj.OnClick(obj, "RightButton")
    assertEqual(opened, 1, "right-click must still open the panel")
end)

-- ---------------------------------------------------------------------------
-- 9. Re-enabling, from CURRENT state
-- ---------------------------------------------------------------------------

test("disabled: re-enabling restores the registration set, from the settings as they are NOW", function()
    local NS, mocks, R_on = baseline()

    disable(NS)
    enable(NS)
    mocks.__fireTimers()
    assertTrue(sameRegs(regs(mocks), R_on),
        "the set came back as " .. dumpRegs(regs(mocks)) .. ", not " .. dumpRegs(R_on))

    -- A SETTING CHANGED WHILE IT WAS OFF. The rebuild must reflect it, never a snapshot taken on the
    -- way down (performance-§6). Every container deleted while disabled means TimedSpells has
    -- nothing to scan for, so its UNIT_AURA gate stays shut on the way back up — a difference the
    -- registration set shows and a snapshot-restoring stand-up would hide.
    disable(NS)
    for _, c in ipairs(NS.Database.GetContainers()) do NS.ContainerManager.Delete(c.id) end
    enable(NS)
    mocks.__fireTimers()
    assertEqual(#regsOn(mocks, NS.addon), 8, "the lifecycle events come back either way")
    assertEqual(#regsOn(mocks, NS.TimedSpells.__events()), 0,
        "with no container left, nothing to listen for: " .. dump(regsOn(mocks, NS.TimedSpells.__events())))
end)

-- ---------------------------------------------------------------------------
-- 10. The latch — two holds, one way down
-- ---------------------------------------------------------------------------

test("disabled: releasing one hold does not stand up an addon the other still holds down", function()
    local NS, mocks = baseline()

    -- red under: give the perf arm its own `resume` that stands the addon up directly, instead of
    -- releasing its hold on the one latch. That resurrects the addon mid-capture under a player who
    -- disabled it, which is the trap this major exists to prevent.
    NS.lifecycle:Hold(NS.HOLD_PERF)
    disable(NS)
    NS.lifecycle:Release(NS.HOLD_PERF)
    assertTrue(NS.IsStoodDown(), "the disabled hold is still taken")
    assertEqual(#regsOn(mocks, NS.addon), 0, "the addon stood back up mid-capture")

    enable(NS)
    mocks.__fireTimers()
    assertFalse(NS.IsStoodDown())
    assertEqual(#regsOn(mocks, NS.addon), 8)

    -- The other order, which fails the same way for the mirror-image reason: a `disable` that calls
    -- a bare stand-up on its way out ruins a run just as thoroughly.
    disable(NS)
    NS.lifecycle:Hold(NS.HOLD_PERF)
    enable(NS)
    assertTrue(NS.IsStoodDown(), "the perf hold is still taken")
    assertEqual(#regsOn(mocks, NS.addon), 0, "the addon stood back up inside a capture")
    NS.lifecycle:Release(NS.HOLD_PERF)
    mocks.__fireTimers()
    assertFalse(NS.IsStoodDown())
    assertEqual(#regsOn(mocks, NS.addon), 8)
end)

test("disabled: a profile switch to an enabled profile stands the addon back up", function()
    local NS, mocks = baseline()
    disable(NS)
    assertEqual(#regsOn(mocks, NS.addon), 0)

    -- A profile switch can flip the enable path with nothing else touched, which is why a disabled
    -- addon MUST keep AceDB's three callbacks. The new profile's `enabled` defaults to true.
    NS.db:SetProfile("elsewhere")
    NS.OnProfileChanged()
    mocks.__fireTimers()
    assertFalse(NS.IsStoodDown(), "the new profile has the addon enabled")
    assertEqual(#regsOn(mocks, NS.addon), 8)
end)
