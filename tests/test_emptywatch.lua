-- tests/test_emptywatch.lua - modules/EmptyWatch.lua: whether a container is predicted EMPTY, and the
-- placeholder hang that answer gates (batch 9 HG-1, E1 as amended by the owner on 2026-09-25).
-- While unlocked and not in test mode, a follower hangs from its parent's one-element slot, and the
-- parent's placeholder outline shows, only while the parent is predicted empty (true). Not empty
-- (false) and not knowable (nil) hang it from the engine with the outline hidden. The prediction is
-- re-read by one throttled pass after UNIT_AURA, heard only while unlocked, out of test mode, out of
-- combat and while auras are readable.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")

local HUGE = math.huge

-- -- the prediction, on a hand-built container -----------------------------------------------

--- A container shaped as EmptyWatch.Predict reads one: a plan, an engine answering its pool size per
--- group key (1 unless `pool` says otherwise), and its stored settings.
local function fakeInst(cfg, plan, pool)
    local engine = {
        GetAuraGroupFrameCount = function(_, key)
            local n = pool and pool[key]
            if n == nil then return 1 end
            return n
        end,
    }
    return { plan = plan, engine = engine, Cfg = function() return cfg end }
end

local function group(filter, cand)
    return { key = "g1", filter = filter, candidateFilters = cand }
end

--- C_UnitAuras answering `auras` (a list of AuraData tables) for `unit`, slot i being aura i.
--- Records every GetAuraSlots call as { unit, filter, maxCount }.
local function withAuras(mocks, unit, auras)
    local calls = {}
    mocks.C_UnitAuras = {
        GetAuraSlots = function(u, filter, maxCount)
            calls[#calls + 1] = { u, filter, maxCount }
            if u ~= unit then return nil end
            local n = #auras
            if maxCount then n = math.min(n, maxCount) end
            local slots = {}
            for i = 1, n do slots[i] = i end
            return nil, unpack(slots, 1, n)
        end,
        GetAuraDataBySlot = function(u, slot)
            if u ~= unit then return nil end
            return auras[slot]
        end,
    }
    return calls
end

local function noEnchants(mocks)
    mocks.GetWeaponEnchantInfo = function() return false, 0, 0, 0, false, 0, 0, 0, false, 0, 0, 0 end
end

local PLAYER_BUFFS = { unit = "player", auraType = "HELPFUL" }

test("empty: a token-only group holding an aura is not empty, asked with a count of one", function()
    local NS, mocks = fresh()
    local calls = withAuras(mocks, "player", { { spellId = 1 } })
    local inst = fakeInst(PLAYER_BUFFS, { groups = { group("HELPFUL|PLAYER") } })
    -- red under: a prediction that never reads the unit's auras
    assertFalse(NS.EmptyWatch.Predict(inst))
    assertEqual(calls[1][1], "player"); assertEqual(calls[1][2], "HELPFUL|PLAYER"); assertEqual(calls[1][3], 1)
end)

test("empty: a token-only group with nothing to show is empty", function()
    local NS, mocks = fresh()
    withAuras(mocks, "player", {})
    assertTrue(NS.EmptyWatch.Predict(fakeInst(PLAYER_BUFFS, { groups = { group("HELPFUL") } })))
end)

test("empty: a unit that does not exist is empty without reading an aura", function()
    local NS, mocks = fresh()
    mocks.C_UnitAuras = { GetAuraSlots = function() error("read an absent unit") end }
    mocks.__unitExists.target = false
    local inst = fakeInst({ unit = "target", auraType = "HARMFUL" }, { groups = { group("HARMFUL|PLAYER") } })
    assertTrue(NS.EmptyWatch.Predict(inst))
end)

test("empty: a readable pool of 0 is empty without reading an aura", function()
    local NS, mocks = fresh()
    mocks.C_UnitAuras = { GetAuraSlots = function() error("read past an empty pool") end }
    local inst = fakeInst(PLAYER_BUFFS, { groups = { group("HELPFUL") } }, { g1 = 0 })
    -- red under: the pool fast path missing (the read raises, which answers nil)
    assertTrue(NS.EmptyWatch.Predict(inst))
end)

test("empty: an include id hits and misses", function()
    local NS, mocks = fresh()
    local plan = { groups = { group("HELPFUL", { includeSpellIDs = { [100] = true } }) } }
    withAuras(mocks, "player", { { spellId = 200 }, { spellId = 100 } })
    assertFalse(NS.EmptyWatch.Predict(fakeInst(PLAYER_BUFFS, plan)), "100 is on the list")
    withAuras(mocks, "player", { { spellId = 200 } })
    -- red under: the include list ignored (any buff counted)
    assertTrue(NS.EmptyWatch.Predict(fakeInst(PLAYER_BUFFS, plan)), "200 is not")
end)

test("empty: spell ids are ignored where the engine holds a no-ids view, as the engine ignores them", function()
    local NS, mocks = fresh()
    mocks.__unitExists.target = true
    mocks.__canAssist.target = false
    withAuras(mocks, "target", { { spellId = 200 } })
    local cfg = { unit = "target", auraType = "HELPFUL" }
    local g = group("HELPFUL", { includeSpellIDs = { [100] = true } })
    -- Both no-ids views as modules/FilterViews.lua really builds them: the stripped group, keeping the
    -- base's own excludes (the blacklist, Timeless's learned ids). Aura 200 is on that exclude, so the
    -- prediction turns on whether the id test runs at all.
    local kept = { excludeSpellIDs = { [200] = true } }
    g.views = { blizzard = { filter = "HELPFUL", candidateFilters = kept },
                every = { filter = "HELPFUL", candidateFilters = kept } }
    local plan = { groups = { g } }
    local inst = fakeInst(cfg, plan)
    for _, view in ipairs({ "blizzard", "every" }) do
        inst.view = view
        -- red under: ids applied in every view (a hostile target's buff list is not honored)
        assertFalse(NS.EmptyWatch.Predict(inst), view .. ": every buff counts")
    end
    inst.view = "ids"
    assertTrue(NS.EmptyWatch.Predict(inst), "the ids view: the list applies")
    inst.view = nil
    -- red under: a container not yet noted read as a no-ids view (it starts on ids, Blizzard's default)
    assertTrue(NS.EmptyWatch.Predict(inst), "no view noted yet: the ids view")
end)

test("empty: whether ids apply is the view the engine holds (inst.view), never a re-resolve", function()
    -- Filter situations (S2): the view now turns on the container's own Situations settings, so a
    -- resolver asked with the unit and aura type alone could disagree with the engine. EmptyWatch
    -- reads inst.view, which ApplyView, Build and Update set to what they sent.
    local NS, mocks = fresh()
    mocks.__unitExists.target = true
    mocks.__canAssist.target = true   -- NS.Compat.IdsApply would answer "ids apply" for buffs
    withAuras(mocks, "target", { { spellId = 200 } })
    local g = group("HELPFUL", { includeSpellIDs = { [100] = true } })
    g.views = { blizzard = { filter = "HELPFUL" }, every = { filter = "HELPFUL" } }
    local inst = fakeInst({ unit = "target", auraType = "HELPFUL" }, { groups = { g } })
    inst.view = "every"
    -- red under: idsApply re-resolving from NS.Compat.IdsApply (assistable reads "ids apply", so 200
    -- misses the list: empty)
    assertFalse(NS.EmptyWatch.Predict(inst))
    mocks.__canAssist.target = false
    inst.view = "ids"
    -- red under: the same re-resolve the other way (not assistable reads "ids ignored": not empty)
    assertTrue(NS.EmptyWatch.Predict(inst))
end)

test("empty: the prediction reads the ACTIVE view's groups", function()
    local NS, mocks = fresh()
    withAuras(mocks, "player", { { spellId = 100 } })
    local g = group("HELPFUL", { includeSpellIDs = { [100] = true } })
    g.views = { blizzard = { filter = "HELPFUL", candidateFilters = { includeDispelTypes = {} } },
        every = { filter = "HELPFUL" } }
    local inst = fakeInst(PLAYER_BUFFS, { groups = { g } })
    assertFalse(NS.EmptyWatch.Predict(inst), "the ids view: 100 is on the list")
    inst.view = "blizzard"
    -- red under: predicting from the ids view whatever the engine holds (the NEVER group drawn as full)
    assertTrue(NS.EmptyWatch.Predict(inst), "the blizzard view: the NEVER group matches nothing")
    -- red under: an activeView that knows only the blizzard view (filter situations, S1), reading the
    -- every view's group as the ids view's
    withAuras(mocks, "player", { { spellId = 200 } })
    inst.view = "every"
    assertFalse(NS.EmptyWatch.Predict(inst), "the every view: an unconstrained group draws 200")
    -- A blizzard view's filter string is the one asked for, too.
    inst.view = "blizzard"
    g.candidateFilters, g.views.blizzard = nil, { filter = "HELPFUL|RAID" }
    local calls = withAuras(mocks, "player", { { spellId = 1 } })
    NS.EmptyWatch.Predict(inst)
    -- red under: the ids view's filter string sent to GetAuraSlots
    assertEqual(calls[1][2], "HELPFUL|RAID")
end)

test("empty: a max duration drops a permanent aura and one that runs longer", function()
    local NS, mocks = fresh()
    local timed = { groups = { group("HELPFUL", { maxDuration = HUGE }) } }
    withAuras(mocks, "player", { { spellId = 1, duration = 0 } })
    -- red under: a permanent aura (duration 0) counted under maxDuration
    assertTrue(NS.EmptyWatch.Predict(fakeInst(PLAYER_BUFFS, timed)), "permanent: dropped")
    withAuras(mocks, "player", { { spellId = 1, duration = 30 } })
    assertFalse(NS.EmptyWatch.Predict(fakeInst(PLAYER_BUFFS, timed)), "timed: kept")
    local short = { groups = { group("HELPFUL", { maxDuration = 10 }) } }
    assertTrue(NS.EmptyWatch.Predict(fakeInst(PLAYER_BUFFS, short)), "30 s over a 10 s cap: dropped")
end)

test("empty: dispel types include and exclude", function()
    local NS, mocks = fresh()
    local cfg = { unit = "player", auraType = "HARMFUL" }
    withAuras(mocks, "player", { { spellId = 1, dispelName = "Curse" } })
    local magic = { groups = { group("HARMFUL", { includeDispelTypes = { Magic = true } }) } }
    assertTrue(NS.EmptyWatch.Predict(fakeInst(cfg, magic)))
    local noCurse = { groups = { group("HARMFUL", { excludeDispelTypes = { Curse = true } }) } }
    assertTrue(NS.EmptyWatch.Predict(fakeInst(cfg, noCurse)))
    withAuras(mocks, "player", { { spellId = 1, dispelName = "Magic" } })
    assertFalse(NS.EmptyWatch.Predict(fakeInst(cfg, magic)))
end)

test("empty: a flag the aura data does not carry is not knowable", function()
    local NS, mocks = fresh()
    local plan = { groups = { group("HELPFUL", { isRoleAura = true }) } }
    withAuras(mocks, "player", { { spellId = 1 } })
    -- red under: a missing field read as false (a wrong 'empty' overlaps the parent)
    assertNil(NS.EmptyWatch.Predict(fakeInst(PLAYER_BUFFS, plan)))
    withAuras(mocks, "player", { { spellId = 1, isRoleAura = true } })
    assertFalse(NS.EmptyWatch.Predict(fakeInst(PLAYER_BUFFS, plan)))
end)

test("empty: a read that raises, a secret field and secret auras are not knowable", function()
    local secretId = false
    local NS, mocks = fresh({ before = function(m)
        m.issecretvalue = function(v) return secretId and v == 777 end
    end })
    local inst = fakeInst(PLAYER_BUFFS, { groups = { group("HELPFUL", { excludeSpellIDs = { [5] = true } }) } })
    mocks.C_UnitAuras = { GetAuraSlots = function() error("unknown filter token") end }
    assertNil(NS.EmptyWatch.Predict(inst), "a raising read")
    withAuras(mocks, "player", { { spellId = 777 } })
    secretId = true
    -- red under: a secret spell id used as a table key
    assertNil(NS.EmptyWatch.Predict(inst), "a secret spell id")
    secretId = false
    mocks.__aurasSecret = true
    assertNil(NS.EmptyWatch.Predict(inst), "auras secret")
end)

test("empty: weapon enchants present, absent, and permanent under Hide permanent", function()
    local NS, mocks = fresh()
    local function enchantPlan(hidePermanent)
        return { groups = {}, enchants = { slots = { "mainHand", "offHand" }, hidePermanent = hidePermanent } }
    end
    local mh, mhExp, oh = false, 0, false
    mocks.GetWeaponEnchantInfo = function() return mh, mhExp, 0, 0, oh, 0, 0, 0, false, 0, 0, 0 end
    assertTrue(NS.EmptyWatch.Predict(fakeInst(PLAYER_BUFFS, enchantPlan(true))), "no enchant")
    mh, mhExp = true, 60000
    assertFalse(NS.EmptyWatch.Predict(fakeInst(PLAYER_BUFFS, enchantPlan(true))), "an oil on the main hand")
    mh, mhExp = false, 0
    oh = true
    -- red under: a permanent (no expiration) enchant counted under Hide permanent
    assertTrue(NS.EmptyWatch.Predict(fakeInst(PLAYER_BUFFS, enchantPlan(true))), "permanent, hidden")
    assertFalse(NS.EmptyWatch.Predict(fakeInst(PLAYER_BUFFS, enchantPlan(false))), "permanent, shown")
    mocks.GetWeaponEnchantInfo = nil
    assertNil(NS.EmptyWatch.Predict(fakeInst(PLAYER_BUFFS, enchantPlan(true))), "no enchant API")
end)

test("empty: an enchant on a container with no aura is not empty even when its unit's auras are unknowable", function()
    local NS, mocks = fresh()
    mocks.GetWeaponEnchantInfo = function() return true, 60000, 0, 0 end
    mocks.C_UnitAuras = nil
    local plan = { groups = { group("HELPFUL") }, enchants = { slots = { "mainHand" }, hidePermanent = true } }
    assertFalse(NS.EmptyWatch.Predict(fakeInst(PLAYER_BUFFS, plan)))
end)

-- -- the hang and the outline, on a live chain ------------------------------------------------

local function recordAnchor(inst)
    local rec = { points = {} }
    rawset(inst.anchor, "SetPoint", function(_, ...) table.insert(rec.points, { ... }) end)
    rawset(inst.anchor, "ClearAllPoints", function() end)
    return rec
end

local function lastTarget(rec)
    local p = rec.points[#rec.points]
    return p and p[2]
end

local function attach(NS, id, to)
    NS.SetByPath("container.attach.x", 0, id)
    NS.SetByPath("container.attach.y", 0, id)
    NS.SetByPath("container.attach.container", to, id)
    NS.SetByPath("container.attach.mode", "container", id)
end

--- Container 2 attached to container 1 (the player's buffs), unlocked, test mode off, flushed, with
--- no weapon enchant and no aura on the player.
local function unlockedPair()
    local NS, mocks = fresh()
    noEnchants(mocks)
    withAuras(mocks, "player", {})
    attach(NS, 2, 1)
    NS.SetByPath("locked", false)
    mocks.__fireTimers(); mocks.__fireTimers()
    return NS, mocks, NS.ContainerManager
end

--- Give container `inst` one live button in each group, so its pool is no longer 0.
local function populate(mocks, inst)
    for _, g in ipairs(inst.plan.groups) do inst.engine.__frames[g.key] = { mocks.__stubFrame() } end
end

--- The player-and-pet watcher frame's OnEvent, called as the client calls it.
local function fireAura(NS, unit)
    local f = NS.EmptyWatch.unitFrames[1]
    f.__scripts.OnEvent(f, "UNIT_AURA", unit or "player")
end

local function outlineShown(inst)
    return inst.outline ~= nil and inst.outline:IsShown()
end

test("empty: unlocked and predicted empty, the follower hangs from the slot and the placeholder shows", function()
    local _, _, CM = unlockedPair()
    local one = CM.instances[1]
    assertTrue(one.predictedEmpty == true, "predicted empty")
    assertEqual(one.hangMode, "slot")
    assertTrue(outlineShown(one), "the placeholder outline shows")
end)

test("empty: a parent that gains an aura moves its follower onto the engine and hides its placeholder; losing it moves it back", function()
    local NS, mocks, CM = unlockedPair()
    local one, two = CM.instances[1], CM.instances[2]
    local rec = recordAnchor(two)
    populate(mocks, one)
    withAuras(mocks, "player", { { spellId = 1, duration = 30, isFromPlayerOrPlayerPet = true } })
    fireAura(NS)
    mocks.__fireTimers()
    -- red under: hangModeFor ignoring the prediction (slot whenever unlocked)
    assertTrue(lastTarget(rec) == one.engine, "not empty: the engine, past the last aura")
    assertEqual(one.hangMode, "engine")
    assertFalse(outlineShown(one), "the placeholder hides")
    withAuras(mocks, "player", {})
    fireAura(NS)
    mocks.__fireTimers()
    assertTrue(lastTarget(rec) == one.anchor, "empty again: the slot")
    assertTrue(outlineShown(one))
end)

test("empty: a prediction that is not knowable hangs from the engine with the placeholder hidden", function()
    local NS, mocks, CM = unlockedPair()
    local one = CM.instances[1]
    populate(mocks, one)
    mocks.C_UnitAuras = nil
    fireAura(NS)
    mocks.__fireTimers()
    assertNil(one.predictedEmpty)
    assertEqual(one.hangMode, "engine")
    assertFalse(outlineShown(one))
end)

test("empty: 50 UNIT_AURA events cost one pass", function()
    local NS, mocks, CM = unlockedPair()
    local one = CM.instances[1]
    local passes = 0
    local predict = NS.EmptyWatch.Predict
    NS.EmptyWatch.Predict = function(inst)
        if inst == one then passes = passes + 1 end
        return predict(inst)
    end
    for _ = 1, 50 do fireAura(NS) end
    -- red under: a pass per event (no coalescing)
    assertEqual(passes, 0, "nothing runs inside the handler")
    assertEqual(mocks.__fireTimers(), 1, "one timer for the burst")
    assertEqual(passes, 1, "one prediction for the burst")
    NS.EmptyWatch.Predict = predict
end)

test("empty: PLAYER_REGEN_DISABLED puts every follower on the engine before lockdown, and combat's end brings the slot back", function()
    local NS, mocks, CM = unlockedPair()
    local one, two = CM.instances[1], CM.instances[2]
    local rec = recordAnchor(two)
    -- The client fires PLAYER_REGEN_DISABLED before its lockdown begins (docs/midnight-quirks.md).
    mocks.__inCombat = true
    NS.addon:OnCombatChanged("PLAYER_REGEN_DISABLED")
    -- red under: the prediction still read at the combat edge
    assertTrue(lastTarget(rec) == one.engine, "combat: the engine")
    assertFalse(outlineShown(one))
    assertNil(NS.EmptyWatch.unitFrames[1].__unitEvents.UNIT_AURA, "UNIT_AURA dropped for combat")
    mocks.__inCombat = false
    NS.addon:OnCombatChanged("PLAYER_REGEN_ENABLED")
    assertTrue(lastTarget(rec) == one.anchor, "after combat: the slot")
end)

test("empty: under lockdown nothing is re-placed, whatever the prediction", function()
    local _, mocks, CM = unlockedPair()
    local one = CM.instances[1]
    local rec = recordAnchor(CM.instances[2])
    mocks.__lockdown = true
    populate(mocks, one)
    CM.ApplyVisibility()
    mocks.__fireTimers()
    -- red under: PlaceAttached running under lockdown
    assertEqual(#rec.points, 0)
end)

test("empty: an oil on the weapon arms one pass at its expiry, and the lapse brings the placeholder back", function()
    local NS, mocks, CM = unlockedPair()
    local one = CM.instances[1]
    assertTrue(one.plan.enchants ~= nil, "the starter player-buffs container shows weapon enchants")
    local oil = true
    mocks.GetWeaponEnchantInfo = function() return oil, 60000, 0, 0, false, 0, 0, 0, false, 0, 0, 0 end
    fireAura(NS)
    mocks.__fireTimers()
    assertEqual(one.predictedEmpty, false, "an oil: not empty")
    local expiry   -- the longest timer queued: the pass is 0.2 s, the expiry about a minute
    for _, t in ipairs(mocks.__timers) do
        if not expiry or t.delay > expiry.delay then expiry = t end
    end
    -- red under: no timer at the expiry (an enchant that lapses fires no UNIT_AURA)
    assertTrue(expiry ~= nil and expiry.delay > 59 and expiry.delay < 61, "a pass at the expiry")
    oil = false
    mocks.__fireTimers()
    mocks.__fireTimers()
    assertTrue(one.predictedEmpty == true, "lapsed: empty again")
    assertEqual(one.hangMode, "slot")
end)

-- -- when it listens ---------------------------------------------------------------------------

local function auraUnits(NS, i)
    local f = NS.EmptyWatch.unitFrames and NS.EmptyWatch.unitFrames[i]
    return f and f.__unitEvents.UNIT_AURA
end

test("empty: UNIT_AURA is heard only while unlocked, and a lock drops it", function()
    local NS, mocks = fresh()
    noEnchants(mocks)
    -- red under: a registration made at load or while locked
    assertNil(auraUnits(NS, 1), "locked: nothing registered")
    NS.SetByPath("locked", false)
    assertEqual(table.concat(auraUnits(NS, 1) or {}, ","), "player,pet")
    NS.SetByPath("locked", true)
    assertNil(auraUnits(NS, 1), "locked again: dropped")
end)

test("empty: target and focus are heard on a second frame only while a target or focus container shows", function()
    local NS, mocks = fresh()
    noEnchants(mocks)
    NS.SetByPath("locked", false)
    -- Container 3 is the starter "Target debuffs (mine)".
    assertEqual(table.concat(auraUnits(NS, 2) or {}, ","), "target,focus")
    NS.SetByPath("container.enabled", false, 3)
    mocks.__fireTimers()
    assertNil(auraUnits(NS, 2), "no target or focus container shows")
end)

test("empty: test mode, secret auras and a stand-down each drop UNIT_AURA", function()
    local NS, mocks = fresh()
    noEnchants(mocks)
    NS.SetByPath("locked", false)
    NS.Preview.SetTestMode(true)
    assertNil(auraUnits(NS, 1), "test mode")
    NS.Preview.SetTestMode(false)
    assertTrue(auraUnits(NS, 1) ~= nil, "back after test mode")
    mocks.__aurasSecret = true
    NS.addon:OnRestrictionChanged()
    assertNil(auraUnits(NS, 1), "secret")
    mocks.__aurasSecret = false
    NS.addon:OnRestrictionChanged()
    assertTrue(auraUnits(NS, 1) ~= nil, "readable again")
    NS.SetByPath("enabled", false)
    assertNil(auraUnits(NS, 1), "stood down")
    assertFalse(NS.EmptyWatch.__pending(), "no pass or expiry timer left to wake up")
end)

test("empty: the player frame filters UNIT_AURA alone; pet and inventory changes ride AceEvent", function()
    local NS, mocks = fresh()
    noEnchants(mocks)
    NS.SetByPath("locked", false)
    local ue = NS.EmptyWatch.unitFrames[1].__unitEvents
    -- red under: UNIT_PET and UNIT_INVENTORY_CHANGED on the unit-filter frame, whose only permitted
    -- job is its one filtered event (events-frames-taint section 1, the unit-filter frame carve-out)
    assertNil(ue.UNIT_PET, "UNIT_PET is not on the unit-filter frame")
    assertNil(ue.UNIT_INVENTORY_CHANGED, "UNIT_INVENTORY_CHANGED is not on the unit-filter frame")
    mocks.__fireTimers()
    assertFalse(NS.EmptyWatch.__pending(), "settled")
    mocks.__fireEvent("UNIT_PET", "party1")
    mocks.__fireEvent("UNIT_INVENTORY_CHANGED", "party1")
    assertFalse(NS.EmptyWatch.__pending(), "another unit's pet or gear changes nothing")
    mocks.__fireEvent("UNIT_PET", "player")
    assertTrue(NS.EmptyWatch.__pending(), "the player's pet: a pass is due")
    mocks.__fireTimers()
    mocks.__fireEvent("UNIT_INVENTORY_CHANGED", "player")
    assertTrue(NS.EmptyWatch.__pending(), "the player's gear: a pass is due")
    NS.SetByPath("locked", true)
    mocks.__fireEvent("UNIT_PET", "player")
    assertFalse(NS.EmptyWatch.__pending(), "locked: UNIT_PET dropped")
end)

test("empty: a target switch re-predicts at once, so no follower hangs from the emptied engine in between", function()
    local NS, mocks = fresh()
    noEnchants(mocks)
    mocks.__unitExists.target = true
    local held = { { spellId = 1, duration = 30, isFromPlayerOrPlayerPet = true } }
    withAuras(mocks, "target", held)
    NS.SetByPath("container.unit", "target", 1)
    attach(NS, 2, 1)
    NS.SetByPath("locked", false)
    local CM = NS.ContainerManager
    local one, two = CM.instances[1], CM.instances[2]
    mocks.__fireTimers(); mocks.__fireTimers()
    populate(mocks, one)
    local f = NS.EmptyWatch.unitFrames[2]
    f.__scripts.OnEvent(f, "UNIT_AURA", "target")
    mocks.__fireTimers()
    assertEqual(one.hangMode, "engine", "the old target holds an aura")
    local rec = recordAnchor(two)
    withAuras(mocks, "target", {})
    mocks.__fireEvent("PLAYER_TARGET_CHANGED")
    -- red under: PLAYER_TARGET_CHANGED only marking the 0.2 s pass due, while the engine has already
    -- emptied to its 1x1 rect, so the follower jumps to that corner and back (owner, 2026-09-26)
    assertEqual(one.hangMode, "slot", "re-predicted inside the event, before any timer")
    assertTrue(lastTarget(rec) == one.anchor, "the follower goes straight to the slot")
end)

test("empty: a target switch folds a pass already due into its own, leaving no timer behind", function()
    local NS, mocks = fresh()
    noEnchants(mocks)
    mocks.__unitExists.target = true
    withAuras(mocks, "target", {})
    NS.SetByPath("container.unit", "target", 1)
    attach(NS, 2, 1)
    NS.SetByPath("locked", false)
    mocks.__fireTimers(); mocks.__fireTimers()
    local f = NS.EmptyWatch.unitFrames[2]
    f.__scripts.OnEvent(f, "UNIT_AURA", "target")
    mocks.__fireEvent("PLAYER_TARGET_CHANGED")
    -- red under: the switch running its pass beside the pending timer instead of canceling it
    assertEqual(mocks.__fireTimers(), 0, "the due pass was folded into the switch")
end)

-- -- the prediction follows the view the engine holds (spell-list views, V3; SV-03R) -----------

--- A target buff container showing Defensive cooldowns alone (a spell category: one group, NEVER in the
--- blizzard view), watched (unlocked), its group's pool live, while the target holds one listed buff and
--- cannot be assisted, so the engine holds the blizzard view and the prediction is empty. Answers NS,
--- mocks and the instance. Both Situations settings are "blizzard" unless `situations` says otherwise
--- (filter situations, S2: the default "every" draws the target's every buff through the remainder).
local function hostileSpellListTarget(situations)
    local NS, mocks = fresh()
    noEnchants(mocks)
    mocks.__unitExists.target = true
    mocks.__canAssist.target = false
    withAuras(mocks, "target", {})
    local categories = {}
    for _, def in ipairs(NS.Categories.For("HELPFUL")) do
        categories[def.key] = (def.key == "defensives") and "show" or "hide"
    end
    local CM = NS.ContainerManager
    local id = CM.Create({ unit = "target", auraType = "HELPFUL", filter = { categories = categories,
        situations = situations or { npcs = "blizzard", players = "blizzard" } } })
    NS.SetByPath("locked", false)
    mocks.__fireTimers(); mocks.__fireTimers()
    local inst = CM.instances[id]
    populate(mocks, inst)
    local listed = next(inst.plan.groups[1].candidateFilters.includeSpellIDs)
    withAuras(mocks, "target", { { spellId = listed, duration = 10 } })
    mocks.__fireTimers()
    return NS, mocks, inst
end

test("empty: a target swap EmptyWatch hears before OnUnitSwap predicts from the new unit's view", function()
    local NS, mocks, inst = hostileSpellListTarget()
    assertEqual(inst.view, "blizzard", "hostile: the blizzard view")
    assertTrue(inst.predictedEmpty == true, "the NEVER group draws nothing")
    -- AceEvent walks its handlers with next(), so either may run first. Silence OnUnitSwap to make
    -- EmptyWatch's handler the one that runs, as it does when it comes first.
    NS.addon:UnregisterEvent("PLAYER_TARGET_CHANGED")
    mocks.__canAssist.target = true
    mocks.__fireEvent("PLAYER_TARGET_CHANGED")
    -- red under: onUnitSwitch predicting from inst.view before OnUnitSwap's ApplyViews moved it (the
    -- old target's NEVER group reads empty while the engine, about to switch, draws the listed buff)
    assertEqual(inst.view, "ids", "EmptyWatch's handler moved the view itself")
    assertTrue(inst.predictedEmpty == false, "the listed buff draws: not empty")
end)

test("empty: a hostile NPC on the every view predicts from the remainder slot", function()
    local NS, mocks, inst = hostileSpellListTarget({ npcs = "every", players = "blizzard" })
    -- red under: the every view never resolved at run time (the engine left on the blizzard view)
    assertEqual(inst.view, "every")
    withAuras(mocks, "target", { { spellId = 999999, duration = 10, isStealable = false } })
    NS.EmptyWatch.Reevaluate()
    -- red under: activeView reading the ids or blizzard view while the engine holds every (the listed
    -- group's NEVER, and the remainder's NEVER there, both read empty)
    assertTrue(inst.predictedEmpty == false, "the remainder draws an unlisted buff: not empty")
    -- A buff only in the Hidden Stealable row: the remainder's every view excludes it (isStealable =
    -- false), so nothing draws.
    withAuras(mocks, "target", { { spellId = 999998, duration = 10, isStealable = true } })
    NS.EmptyWatch.Reevaluate()
    -- red under: the every view falling back to each group's ids view (the Defensives group, its id
    -- list skipped where ids do not apply, would count the stealable buff and ignore the Hidden row)
    assertTrue(inst.predictedEmpty == true, "a buff only in a Hidden Blizzard row: empty")
    withAuras(mocks, "target", { { spellId = 999999, duration = 10, isStealable = false } })
    NS.EmptyWatch.Reevaluate()
    assertTrue(inst.predictedEmpty == false)
    NS.SetByPath("container.filter.situations.npcs", "blizzard", inst.id)
    assertEqual(inst.view, "blizzard", "the view effect moved it")
    -- red under: the view effect not telling EmptyWatch (the prediction kept the every view's answer)
    assertTrue(inst.predictedEmpty == true, "the blizzard view draws nothing here: empty")
end)

test("empty: a target swap OnUnitSwap hears first still costs one pass, in the new unit's view", function()
    local NS, mocks, inst = hostileSpellListTarget()
    local passes = 0
    local reevaluate = NS.EmptyWatch.Reevaluate
    NS.EmptyWatch.Reevaluate = function(...)
        passes = passes + 1
        return reevaluate(...)
    end
    mocks.__canAssist.target = true
    -- AceEvent walks its handlers with next(), so either may run first. Run OnUnitSwap by hand, then
    -- fire the event with only EmptyWatch's handler left, as when OnUnitSwap comes first.
    NS.addon:UnregisterEvent("PLAYER_TARGET_CHANGED")
    NS.addon:OnUnitSwap("PLAYER_TARGET_CHANGED")
    mocks.__fireEvent("PLAYER_TARGET_CHANGED")
    NS.EmptyWatch.Reevaluate = reevaluate
    assertEqual(inst.view, "ids", "OnUnitSwap moved the view")
    -- red under: OnUnitSwap's ApplyViews telling EmptyWatch as well (a pass inside the swap, then
    -- EmptyWatch's own swap pass: two per swap)
    assertEqual(passes, 1, "one pass per swap, whichever handler runs first")
    assertTrue(inst.predictedEmpty == false, "the listed buff draws: not empty")
end)

test("empty: UNIT_FLAGS flipping the view on the same target re-predicts at once", function()
    local _, mocks, inst = hostileSpellListTarget()
    assertTrue(inst.predictedEmpty == true)
    mocks.__canAssist.target = true
    mocks.__fire("UNIT_FLAGS", "target")
    assertEqual(inst.view, "ids", "a duel starting: the ids view")
    -- red under: CM.ApplyViews never telling EmptyWatch (the prediction stays at the old view's answer
    -- until some unrelated UNIT_AURA)
    assertTrue(inst.predictedEmpty == false, "re-predicted inside the event, before any timer")
    mocks.__canAssist.target = false
    mocks.__fire("UNIT_FACTION", "target")
    assertTrue(inst.predictedEmpty == true, "hostile again: empty again")
end)
