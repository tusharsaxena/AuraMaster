-- tests/test_container.lua — modules/Container.lua: how one container drives Blizzard's aura engine.
--
-- The engine is a recorder in tests/wow_mock.lua, and the contract kept with it is an ORDER and a
-- COUNT: anchored before the first group, the unit set last, an unchanged filter never re-sent, and
-- nothing touched while auras are secret.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")

local function lastIndex(engine, name)
    local idx
    for i, c in ipairs(engine.__calls) do if c[1] == name then idx = i end end
    return idx
end

test("container: the engine is anchored before its first group and given its unit last", function()
    local NS = fresh()
    local e = NS.ContainerManager.instances[1].engine
    assertTrue(e ~= nil, "the starter container built an engine")
    assertTrue(e:__firstCall("SetPoint") < e:__firstCall("AddAuraGroup"),
        "AddAuraGroup forbids anchoring the container afterwards")
    local unitAt = e:__firstCall("SetUnit")
    assertTrue(unitAt > lastIndex(e, "AddAuraGroup"))
    assertTrue(unitAt > lastIndex(e, "AddItemEnchantment"))
    assertEqual(e:__callsTo("SetUnit")[1][2], "player")
end)

test("container: a player buff container with enchants adds all three enchant slots", function()
    local NS = fresh()
    assertEqual(#NS.ContainerManager.instances[1].engine:__callsTo("AddItemEnchantment"), 3)
    assertEqual(#NS.ContainerManager.instances[2].engine:__callsTo("AddItemEnchantment"), 0)
end)

test("container: a filter change is applied in place, sending only what changed", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local e = inst.engine
    NS.SetByPath("container.filter.castBy", "mine", 1)
    mocks.__fireTimers()
    assertTrue(inst.engine == e, "the same engine: a live-editable change needs no rebuild")
    local sent = e:__callsTo("SetAuraGroupFilterString")
    assertEqual(#sent, 1)
    assertEqual(sent[1][3], "HELPFUL|PLAYER")
    assertEqual(#e:__callsTo("SetAuraGroupCandidateFilters"), 0,
        "unchanged candidate filters are not re-sent (the engine re-gathers on every call)")
end)

test("container: a change of shape retires the engine and builds a new one", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local old = inst.engine
    NS.SetByPath("container.filter.categories.defensives", "show", 1)
    NS.SetByPath("container.filter.categories.bigDefensive", "show", 1)
    mocks.__fireTimers()
    assertTrue(inst.engine ~= old)
    assertFalse(old.__enabled, "the old engine is disabled, not left drawing")
    assertEqual(#inst.retired, 1)
    assertEqual(#inst.engine:__callsTo("AddAuraGroup"), 2)
end)

test("container: toggling hide-permanent rebuilds the engine with the new flag", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local old = inst.engine
    NS.SetByPath("container.filter.hidePermanentEnchants", false, 1)
    mocks.__fireTimers()
    assertTrue(inst.engine ~= old, "hidePermanent is fixed at AddItemEnchantment, so only a new engine takes it")
    assertEqual(#inst.retired, 1)
    local added = inst.engine:__callsTo("AddItemEnchantment")
    assertEqual(#added, 3)
    for _, c in ipairs(added) do assertEqual(c[3].hidePermanent, false) end
end)

test("container: a sort-direction change reaches the enchant sort in place", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local e = inst.engine
    local before = #e:__callsTo("SetItemEnchantmentSortMethod")
    NS.SetByPath("container.filter.sortDirection", "reverse", 1)
    mocks.__fireTimers()
    assertTrue(inst.engine == e, "the same engine: the enchant sort is live-editable")
    local sent = e:__callsTo("SetItemEnchantmentSortMethod")
    assertEqual(#sent, before + 1)
    assertEqual(sent[#sent][3], NS.Compat.SortDirection("reverse"))
    -- red under: updateEnchants not recording self.enchantDir after re-sending
    NS.SetByPath("container.bars.width", 300, 1)
    mocks.__fireTimers()
    assertEqual(#e:__callsTo("SetItemEnchantmentSortMethod"), before + 1,
        "an unrelated write does not re-send the enchant sort")
end)

test("container: a restyle re-dresses every button the engine has made", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local button = mocks.__stubFrame()
    inst.engine.__frames.g1 = { button }
    NS.SetByPath("container.bars.width", 300, 1)
    mocks.__fireTimers()
    assertTrue(button.__am ~= nil, "the button was dressed")
end)

test("container: nothing touches the engine while auras are secret, and it catches up after", function()
    local NS, mocks = fresh()
    local e = NS.ContainerManager.instances[1].engine
    mocks.__aurasSecret = true
    NS.SetByPath("container.filter.castBy", "others", 1)
    mocks.__fireTimers()
    assertEqual(#e:__callsTo("SetAuraGroupFilterString"), 0)
    mocks.__aurasSecret = false
    NS.addon:OnRestrictionChanged()
    local sent = e:__callsTo("SetAuraGroupFilterString")
    assertEqual(#sent, 1)
    assertEqual(sent[1][3], "HELPFUL|!PLAYER")
end)

test("container: the show ladder — suspend, the master switch, the container switch, visibility", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    assertTrue((inst:ShouldShow()))
    NS.Perf.suspended = true
    assertFalse((inst:ShouldShow()), "step 0 is the perf probe's suspend")
    NS.Perf.suspended = false
    NS.db.profile.enabled = false
    assertFalse((inst:ShouldShow()))
    NS.db.profile.enabled = true
    NS.Database.FindContainer(1).enabled = false
    assertFalse((inst:ShouldShow()))
    NS.Database.FindContainer(1).enabled = true
    NS.db.profile.visibility = "inCombat"
    assertFalse((inst:ShouldShow()))
    mocks.__inCombat = true
    assertTrue((inst:ShouldShow()))
    NS.db.profile.visibility = "never"
    assertFalse((inst:ShouldShow()))
end)

test("container: unlocking previews placeholders through the style code and disables the engine", function()
    local NS = fresh()
    local inst = NS.ContainerManager.instances[1]
    NS.SetByPath("locked", false)
    local enabled = inst.engine:__callsTo("SetEnabled")
    assertEqual(enabled[#enabled][2], false, "real auras do not draw over the placeholders")
    local _, active = NS.Pool.Counts(inst.previewPool)
    assertEqual(active, #NS.Constants.PREVIEW_AURAS)
    assertTrue(inst.previewPool.active[1].__am ~= nil, "dressed by the same Style code")
    NS.SetByPath("locked", true)
    local _, after = NS.Pool.Counts(inst.previewPool)
    assertEqual(after, 0)
end)

test("container: a visibility pass re-dresses no preview element unless the settings changed", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    local dressed = 0
    local element = NS.Style.Element
    NS.Style.Element = function(f, c, engine)
        if not engine then dressed = dressed + 1 end
        return element(f, c, engine)
    end
    NS.ContainerManager.ApplyVisibility()
    -- red under: Preview.Show without its early return
    assertEqual(dressed, 0, "the look did not change, so the placeholders are not dressed again")
    NS.SetByPath("container.bars.width", 250, 1)
    mocks.__fireTimers()
    local _, active = NS.Pool.Counts(inst.previewPool)
    assertTrue(active > 0)
    assertEqual(dressed, active, "an applied setting re-dresses every placeholder of that container, once")
end)

test("container: a new target refreshes only the containers tracking the target", function()
    local NS = fresh()
    NS.addon:OnUnitSwap("PLAYER_TARGET_CHANGED")
    assertEqual(#NS.ContainerManager.instances[3].engine:__callsTo("UpdateAllAuras"), 1)
    assertEqual(#NS.ContainerManager.instances[1].engine:__callsTo("UpdateAllAuras"), 0)
end)

test("container: Blizzard's load-on-demand aura container is loaded before the first engine", function()
    -- red under: CM.Init checking HasAuraContainer without loading the add-on first.
    local loaded = {}
    local NS, mocks = fresh({ before = function(m)
        m.C_AddOns = {
            IsAddOnLoaded = function() return false end,
            LoadAddOn = function(name) loaded[#loaded + 1] = name end,
        }
    end })
    assertEqual(loaded[1], "Blizzard_AuraContainer")
    assertTrue(#mocks.__engines > 0)
    assertTrue(NS.ContainerManager.instances[1].engine ~= nil)
end)

test("container: on a client without the aura engine nothing is built and preview still works", function()
    local NS, mocks = fresh({ before = function(m) m.AuraContainerSortMethod = nil end })
    assertEqual(#mocks.__engines, 0)
    assertNil(NS.ContainerManager.instances[1].engine)
    NS.SetByPath("locked", false)
    local _, active = NS.Pool.Counts(NS.ContainerManager.instances[1].previewPool)
    assertTrue(active > 0)
end)

test("container: deleting a container disables its engine and hides its anchor", function()
    local NS = fresh()
    local inst = NS.ContainerManager.instances[2]
    local e = inst.engine
    -- Kit frames start hidden: show it first, or the IsShown assertion below could never fail.
    inst.anchor:Show()
    NS.ContainerManager.Delete(2)
    assertFalse(e.__enabled)
    -- red under: Destroy not hiding the anchor
    assertFalse(inst.anchor:IsShown())
    assertNil(NS.ContainerManager.instances[2])
end)

test("container: an anchor is movable but never saved by the client's layout cache", function()
    local NS = fresh()
    -- A position the client saved would be restored at login over the stored one.
    assertTrue(NS.ContainerManager.instances[1].anchor.__dontSavePosition == true)
end)
