-- tests/test_timedspells.lua — modules/TimedSpells.lua: learning which buffs have a duration, for
-- the "only auras without a duration" filter the aura engine cannot express on its own.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")

local function withAuras(mocks, list)
    mocks.C_UnitAuras = {
        GetAuraDataByIndex = function(unit, i)
            if unit ~= "player" then return nil end
            return list[i]
        end,
    }
end

test("timed: nothing is needed until a container shows only timeless auras", function()
    local NS = fresh()
    assertFalse(NS.TimedSpells.Needed())
    NS.SetByPath("container.filter.durationMode", "timeless", 1)
    assertTrue(NS.TimedSpells.Needed())
end)

test("timed: it listens to UNIT_AURA for the player and pet only, and only while needed", function()
    -- red under: registering UNIT_AURA bare (every unit in a raid) instead of RegisterUnitEvent.
    local NS = fresh()
    assertTrue(NS.TimedSpells.__frame() == nil, "no frame while no container needs it")
    NS.SetByPath("container.filter.durationMode", "timeless", 1)
    local f = NS.TimedSpells.__frame()
    assertTrue(f ~= nil)
    assertEqual(table.concat(f.__unitEvents.UNIT_AURA or {}, ","), "player,pet")
    NS.SetByPath("container.filter.durationMode", "any", 1)
    assertTrue(f.__unitEvents.UNIT_AURA == nil, "unregistered once nothing needs it")
end)

test("timed: a readable scan learns every timed buff once, and skips permanent ones", function()
    local NS, mocks = fresh()
    withAuras(mocks, {
        { spellId = 11, duration = 10 }, { spellId = 22, duration = 0 }, { spellId = 33, duration = 5 },
    })
    assertEqual(NS.TimedSpells.Scan(), 2)
    assertEqual(NS.TimedSpells.Scan(), 0, "already known")
    assertTrue(NS.db.global.timedSpells[11])
    assertTrue(NS.db.global.timedSpells[22] == nil)
    assertEqual(NS.TimedSpells.Count(), 2)
end)

test("timed: while auras are secret nothing is read", function()
    local NS, mocks = fresh()
    withAuras(mocks, { { spellId = 11, duration = 10 } })
    mocks.__aurasSecret = true
    assertEqual(NS.TimedSpells.Scan(), 0)
    assertEqual(NS.TimedSpells.Count(), 0)
end)

test("timed: what was learned reaches the filter as excluded ids, and Forget clears it", function()
    local NS, mocks = fresh()
    withAuras(mocks, { { spellId = 44, duration = 30 } })
    NS.TimedSpells.Scan()
    local cfg = NS.Database.FindContainer(1)
    cfg.filter.durationMode = "timeless"
    local plan = NS.FilterCompiler.Compile(cfg, { timedSpells = NS.db.global.timedSpells })
    assertTrue(plan.groups[1].candidateFilters.excludeSpellIDs[44])
    NS.TimedSpells.Forget()
    assertEqual(NS.TimedSpells.Count(), 0)
end)
