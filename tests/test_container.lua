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
    -- A whitelist draws its own group ahead of the one category group — schema v3 (Show/Hide) no
    -- longer grows a group per shown category, so a whitelist is the shape change left to exercise.
    NS.SetByPath("container.filter.whitelist", { [642] = true }, 1)
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
    -- Step 0 is the LATCH, not a flag of the perf module's own: `P.suspended` reads through to
    -- `lc:IsHeld("perf")` and refuses assignment, so the hold is taken rather than a boolean set.
    NS.lifecycle:Hold(NS.HOLD_PERF)
    assertFalse((inst:ShouldShow()), "step 0 is the latch — here, the perf hold")
    NS.lifecycle:Release(NS.HOLD_PERF)
    NS.lifecycle:Hold(NS.HOLD_DISABLED)
    assertFalse((inst:ShouldShow()), "step 0 is the latch — here, the disabled hold")
    NS.lifecycle:Release(NS.HOLD_DISABLED)
    -- The master switch reaches the ladder ONLY through that latch: the stored path is not a second
    -- rung (slash-commands-§7 wants a latch, not a draw gate), so it is driven through the write seam.
    NS.SetByPath("enabled", false)
    assertFalse((inst:ShouldShow()), "the master switch, through the latch")
    NS.SetByPath("enabled", true)
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

test("container: test mode previews placeholders through the style code and disables the engine", function()
    local NS = fresh()
    local inst = NS.ContainerManager.instances[1]
    NS.Preview.SetTestMode(true)
    local enabled = inst.engine:__callsTo("SetEnabled")
    assertEqual(enabled[#enabled][2], false, "real auras do not draw over the placeholders")
    local _, active = NS.Pool.Counts(inst.previewPools.bars)
    assertEqual(active, #NS.Constants.PREVIEW_AURAS)
    assertTrue(inst.previewPools.bars.active[1].__am ~= nil, "dressed by the same Style code")
    NS.Preview.SetTestMode(false)
    local _, after = NS.Pool.Counts(inst.previewPools.bars)
    assertEqual(after, 0)
end)

test("container: unlocked, a container shows whatever its visibility rule, its engine drawing, under an outline (B1)", function()
    local NS = fresh()
    local inst = NS.ContainerManager.instances[1]
    NS.SetByPath("visibility", "never")
    assertFalse(inst.engine.__enabled, "locked and set to never: nothing draws")
    NS.SetByPath("locked", false)
    -- red under: ShouldShow applying the visibility rule while unlocked (an in-combat-only
    -- container could never be found and moved out of combat)
    assertTrue(inst.engine.__enabled, "unlocked: shown, its live auras drawing")
    assertTrue(inst.handle:IsShown(), "and its handle")
    -- red under: ApplyVisibility without the outline (an empty container has nothing to grab)
    assertTrue(inst.outline ~= nil and inst.outline:IsShown(), "an outline marks even an empty container")
    NS.Preview.SetTestMode(true)
    assertFalse(inst.outline:IsShown(), "test mode: the placeholders are there instead")
    NS.Preview.SetTestMode(false)
    NS.SetByPath("locked", true)
    assertFalse(inst.outline:IsShown(), "locked: no outline")
end)

test("container: test mode shows the placeholders while locked, whatever the visibility rule (B1)", function()
    local NS = fresh()
    local inst = NS.ContainerManager.instances[1]
    NS.SetByPath("visibility", "never")
    assertTrue(NS.db.profile.locked, "locked")
    NS.Preview.SetTestMode(true)
    -- red under: ShouldShow applying the visibility rule while previewing (options-ui-§15: test mode
    -- shows the display without an unlock)
    assertTrue(inst.previewShown, "test mode: the placeholders show")
    assertTrue((inst:ShouldShow()), "shown")
    assertFalse(inst.engine.__enabled, "and real auras do not draw over them")
end)

test("container: test mode off, a locked container set to never is hidden again (B1)", function()
    local NS = fresh()
    local inst = NS.ContainerManager.instances[1]
    NS.SetByPath("visibility", "never")
    NS.Preview.SetTestMode(true)
    NS.Preview.SetTestMode(false)
    assertFalse(inst.previewShown, "the placeholders go")
    assertFalse((inst:ShouldShow()), "hidden")
    assertFalse(inst.engine.__enabled, "nothing draws")
end)

test("container: a visibility pass re-dresses no preview element unless the settings changed", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    NS.Preview.SetTestMode(true)
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
    local _, active = NS.Pool.Counts(inst.previewPools.bars)
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
            LoadAddOn = function(name)
                loaded[#loaded + 1] = name
            end,
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
    NS.Preview.SetTestMode(true)
    local _, active = NS.Pool.Counts(NS.ContainerManager.instances[1].previewPools.bars)
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

-- ── the flow layout ──────────────────────────────────────────────────────────────────────────

--- A container built from the shipped template plus `over` (read-only use of the shared env).
local function tpl(over)
    local Database = T.NS.Database
    return Database.Merge(Database.DeepCopy(T.NS.CONTAINER_TEMPLATE), over or {})
end

test("container: a line holds perLine elements and the spacing between them; 0 per line is unbounded", function()
    local FS = T.NS.Container.FlowSettings
    local bars = { width = 200, height = 20 }
    local rows = FS(tpl({ style = "bars", bars = bars, layout = { axis = "horizontal", perLine = 3, spacing = 2 } }))
    -- red under: maxLineSize counting a spacing per element instead of per gap
    assertEqual(rows.maxLineSize, 3 * 200 + 2 * 2, "rows measure element widths")
    local cols = FS(tpl({ style = "bars", bars = bars, layout = { axis = "vertical", perLine = 3, spacing = 2 } }))
    -- red under: FlowSettings measuring a column by element width
    assertEqual(cols.maxLineSize, 3 * 20 + 2 * 2, "columns measure element heights")
    assertEqual(cols.axis, "vertical")
    assertEqual(FS(tpl({ layout = { perLine = 0 } })).maxLineSize, math.huge)
end)

test("container: growth normalizes to right and down, and the anchor corner is the one auras grow away from", function()
    local C = T.NS.Container
    local cases = {
        { "right", "down", "TOPLEFT" }, { "left", "down", "TOPRIGHT" },
        { "right", "up", "BOTTOMLEFT" }, { "left", "up", "BOTTOMRIGHT" },
        { "sideways", "nowhere", "TOPLEFT" },
    }
    for _, c in ipairs(cases) do
        local f = C.FlowSettings(tpl({ layout = { growH = c[1], growV = c[2] } }))
        -- red under: AnchorPoint starting auras that grow up at the TOP
        assertEqual(f.anchorPoint, c[3], c[1] .. "/" .. c[2])
    end
    local h, v = C.Growth({ growH = "sideways", growV = "nowhere" })
    assertEqual(h .. "/" .. v, "right/down", "an unknown growth is the default")
end)

-- ── update in place ──────────────────────────────────────────────────────────────────────────

local function sent(e, name)
    local calls = e:__callsTo(name)
    return #calls
end
local function lastSent(e, name)
    local calls = e:__callsTo(name)
    return calls[#calls]
end

test("container: a changed candidate filter is re-sent on the live engine; the filter string is not", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local e = inst.engine
    local filters, cands = sent(e, "SetAuraGroupFilterString"), sent(e, "SetAuraGroupCandidateFilters")
    assertTrue(NS.SetByPath("container.filter.maxDuration", 60, 1))
    mocks.__fireTimers()
    assertTrue(inst.engine == e, "a live-editable change")
    -- red under: Update never re-sending candidate filters (the Signature compare inverted)
    assertEqual(sent(e, "SetAuraGroupCandidateFilters"), cands + 1)
    assertEqual(lastSent(e, "SetAuraGroupCandidateFilters")[3].maxDuration, 60)
    -- red under: Update re-sending the filter string unconditionally
    assertEqual(sent(e, "SetAuraGroupFilterString"), filters)
end)

test("container: clearing the last candidate filter sends the engine an empty table, not nil", function()
    local NS, mocks = fresh()
    local e = NS.ContainerManager.instances[1].engine
    assertTrue(NS.SetByPath("container.filter.maxDuration", 60, 1))
    mocks.__fireTimers()
    assertTrue(NS.SetByPath("container.filter.maxDuration", 0, 1))
    mocks.__fireTimers()
    local last = lastSent(e, "SetAuraGroupCandidateFilters")
    -- red under: Update passing the plan's nil candidate filters straight to the engine
    assertEqual(type(last[3]), "table")
    assertNil(next(last[3]), "every filter cleared")
end)

test("container: sort, cap and layout changes each send only their own setter", function()
    local NS, mocks = fresh()
    local e = NS.ContainerManager.instances[1].engine
    local sort0, max0 = sent(e, "SetAuraGroupSortMethod"), sent(e, "SetAuraGroupMaxFrameCount")
    local layout0, filter0 = sent(e, "SetAuraGroupLayout"), sent(e, "SetAuraGroupFilterString")
    assertTrue(NS.SetByPath("container.layout.spacing", 7, 1))
    mocks.__fireTimers()
    assertEqual(sent(e, "SetAuraGroupLayout"), layout0 + 1, "one group, one layout")
    assertEqual(lastSent(e, "SetAuraGroupLayout")[3].elementSpacing, 7)
    -- red under: Update re-sending the sort and the cap whatever changed
    assertEqual(sent(e, "SetAuraGroupSortMethod"), sort0)
    assertEqual(sent(e, "SetAuraGroupMaxFrameCount"), max0)
    assertTrue(NS.SetByPath("container.filter.sortMethod", "name", 1))
    mocks.__fireTimers()
    assertEqual(sent(e, "SetAuraGroupSortMethod"), sort0 + 1)
    assertEqual(lastSent(e, "SetAuraGroupSortMethod")[3], mocks.AuraContainerSortMethod.Name, "the engine's enum value")
    assertTrue(NS.SetByPath("container.filter.maxAuras", 5, 1))
    mocks.__fireTimers()
    -- red under: Update never re-sending a changed cap
    assertEqual(lastSent(e, "SetAuraGroupMaxFrameCount")[3], 5)
    assertEqual(sent(e, "SetAuraGroupSortMethod"), sort0 + 1, "the cap did not re-send the sort")
    assertEqual(sent(e, "SetAuraGroupFilterString"), filter0, "and nothing re-sent the filter string")
end)

test("container: a unit change is sent to the live engine once", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[2]   -- Player debuffs
    local e = inst.engine
    local units = sent(e, "SetUnit")
    assertTrue(NS.SetByPath("container.unit", "focus", 2))
    mocks.__fireTimers()
    assertTrue(inst.engine == e, "the same shape, so the same engine")
    -- red under: Update skipping SetUnit when the unit moved
    assertEqual(sent(e, "SetUnit"), units + 1)
    assertEqual(lastSent(e, "SetUnit")[2], "focus")
    assertTrue(NS.SetByPath("container.icons.width", 40, 2))
    mocks.__fireTimers()
    -- red under: Update re-sending SetUnit on every apply
    assertEqual(sent(e, "SetUnit"), units + 1, "an unchanged unit is not re-sent")
end)

test("container: switching style rebuilds the engine even when the filter plan keeps its shape", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[2]
    local old = inst.engine
    assertTrue(NS.SetByPath("container.style", "bars", 2))
    mocks.__fireTimers()
    -- red under: the structure key leaving out cfg.style (icon buttons would be redressed as bars)
    assertTrue(inst.engine ~= old, "a new style gets new buttons")
    assertFalse(old.__enabled)
end)

test("container: a text template of a new shape rebuilds the engine; one of the same shape restyles it", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    assertTrue(NS.SetByPath("container.style", "text", 1))
    mocks.__fireTimers()
    local e = inst.engine
    assertTrue(NS.SetByPath("container.text.template", "$spellname$[ y$stacks$][ ~ $remainingduration$]", 1))
    mocks.__fireTimers()
    assertTrue(inst.engine == e, "the same shape: the same engine, restyled")
    assertTrue(NS.SetByPath("container.text.template", "$spellname$", 1))
    mocks.__fireTimers()
    -- red under: the structure key without Style.StructureKey (a stale binding writes into a hidden string)
    assertTrue(inst.engine ~= e, "a new shape gets new buttons")
    assertFalse(e.__enabled)
end)

-- ── weapon enchants and engine refusals ──────────────────────────────────────────────────────

test("container: a weapon-enchant container shows the player's enchants in the engine's three slots, whatever its unit", function()
    local NS, mocks = fresh()
    local id = NS.ContainerManager.Create({ auraType = "ENCHANT", unit = "target" })
    mocks.__fireTimers()
    local inst = NS.ContainerManager.instances[id]
    local e = inst.engine
    assertEqual(sent(e, "AddAuraGroup"), 0)
    local slots = {}
    for i, c in ipairs(e:__callsTo("AddItemEnchantment")) do slots[i] = c[2] end
    local E = mocks.AuraContainerItemEnchantmentSlot
    assertEqual(table.concat(slots, ","), table.concat({ E.MainHand, E.OffHand, E.Ranged }, ","))
    assertEqual(#inst.enchantFrames, 3, "kept for the restyle")
    -- red under: Build handing an enchant container's own unit to SetUnit
    assertEqual(lastSent(e, "SetUnit")[2], "player")
    assertTrue(NS.SetByPath("container.unit", "focus", id))
    mocks.__fireTimers()
    assertTrue(inst.engine == e)
    -- red under: Update sending an enchant container's own unit
    assertEqual(lastSent(e, "SetUnit")[2], "player")
end)

--- Make every aura engine created from now on raise from `method` whenever `refuse(...)` says so.
local function refusing(mocks, method, refuse)
    local create = mocks.CreateFrame
    mocks.CreateFrame = function(frameType, ...)
        local f = create(frameType, ...)
        if frameType == "AuraContainer" then
            local orig = f[method]
            f[method] = function(self, ...)
                if refuse(...) then error(method .. " refused") end
                return orig(self, ...)
            end
        end
        return f
    end
end

test("container: an enchant slot the engine refuses costs that slot, not the build", function()
    local NS, mocks = fresh()
    refusing(mocks, "AddItemEnchantment", function(slot)
        return slot == mocks.AuraContainerItemEnchantmentSlot.OffHand
    end)
    local id = NS.ContainerManager.Create({ auraType = "ENCHANT" })
    mocks.__fireTimers()
    local inst = NS.ContainerManager.instances[id]
    -- red under: Build calling AddItemEnchantment without pcall
    assertEqual(#inst.enchantFrames, 2, "main hand and ranged")
    assertEqual(lastSent(inst.engine, "SetUnit")[2], "player", "the build still reached the unit")
end)

test("container: an engine call that raises is traced, and the build carries on to the unit", function()
    local NS, mocks = fresh()
    local lines = {}
    NS.Debug = function(tag, fmt, ...)
        local n = #lines
        lines[n + 1] = "[" .. tag .. "] " .. fmt:format(...)
    end
    refusing(mocks, "AddAuraGroup", function() return true end)
    local id = NS.ContainerManager.Create({})
    mocks.__fireTimers()
    -- red under: callEngine calling the engine without pcall
    assertEqual(lastSent(NS.ContainerManager.instances[id].engine, "SetUnit")[2], "player")
    local traced = false
    for _, l in ipairs(lines) do
        if l:find("[Engine] AddAuraGroup failed", 1, true) then traced = true end
    end
    assertTrue(traced, "the refusal is traced")
end)

test("container: a restyle dresses every group button and every enchant frame, and skips a lookup the engine refuses", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]   -- buffs, with the three enchant slots
    local cfg = inst:Cfg()
    inst.engine.__frames.g1 = { mocks.__stubFrame(), mocks.__stubFrame() }
    -- red under: Restyle leaving the enchant frames out
    assertEqual(inst:Restyle(cfg), 5, "two buttons and three enchant frames")
    rawset(inst.engine, "GetAuraGroupFrameCount", function() error("forbidden") end)
    -- red under: Restyle asking the engine for its frames without pcall
    assertEqual(inst:Restyle(cfg), 3)
end)

test("container: an instance whose container is gone applies nothing and touches no engine", function()
    local NS = fresh()
    local inst = NS.ContainerManager.instances[2]
    local e = inst.engine
    local calls = #e.__calls
    NS.db.profile.containers[2] = nil   -- the data left before the registry followed
    -- red under: Apply without its missing-container guard (the compiler is handed nil)
    assertNil(inst:Apply())
    assertEqual(#e.__calls, calls)
end)

-- ── scale, alpha, visibility ─────────────────────────────────────────────────────────────────

--- Record the arguments of every `method` call on `frame`, still returning the frame.
local function recording(frame, method)
    local got = {}
    rawset(frame, method, function(self, ...)
        got[#got + 1] = { ... }
        return self
    end)
    return got
end

test("container: the anchor's scale is the container's times the master's, never below a tenth", function()
    local NS = fresh()
    local inst = NS.ContainerManager.instances[1]
    local scales = recording(inst.anchor, "SetScale")
    NS.db.profile.scale = 1.5
    NS.Database.FindContainer(1).layout.scale = 2
    inst:Apply()
    -- red under: Apply ignoring the master scale
    assertEqual(scales[#scales][1], 3)
    NS.Database.FindContainer(1).layout.scale = 0.01
    inst:Apply()
    -- red under: Apply without its 0.1 floor
    assertEqual(scales[#scales][1], 0.1)
end)

test("container: the anchor's alpha is the container's times the master's", function()
    local NS = fresh()
    local inst = NS.ContainerManager.instances[1]
    local alphas = recording(inst.anchor, "SetAlpha")
    NS.db.profile.alpha = 0.5
    NS.Database.FindContainer(1).layout.alpha = 0.5
    inst:ApplyVisibility()
    -- red under: ApplyVisibility ignoring the master alpha
    assertEqual(alphas[#alphas][1], 0.25)
end)

test("container: out-of-combat visibility shows out of combat and hides in it", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    NS.db.profile.visibility = "outOfCombat"
    -- red under: visibilityAllows letting every value but "never" show
    assertTrue((inst:ShouldShow()))
    mocks.__inCombat = true
    assertFalse((inst:ShouldShow()))
end)

-- ── the class snapshot ───────────────────────────────────────────────────────────────────────

--- A fresh environment whose target is a priest; everyone else is a mage.
local function freshWithPriestTarget()
    return fresh({ before = function(m)
        m.UnitClass = function(u)
            if u == "target" then return "Priest", "PRIEST" end
            return "Mage", "MAGE"
        end
        m.RAID_CLASS_COLORS.PRIEST = { r = 1, g = 1, b = 1 }
    end })
end

test("container: the class snapshot is the tracked unit's, and nothing for the player or for enchants", function()
    local NS, mocks = freshWithPriestTarget()
    local CM = NS.ContainerManager
    local ench = CM.Create({ auraType = "ENCHANT", unit = "target", style = "icons" })
    mocks.__fireTimers()
    for _, id in ipairs({ 2, 3, ench }) do
        assertTrue(NS.SetByPath("container.icons.useClassColorBorder", true, id))
    end
    mocks.__fireTimers()
    assertTrue(CM.instances[3].usesClass)
    assertEqual(CM.instances[3].classColor.r, 1, "painted for the priest")
    -- red under: SnapshotClass resolving a class for the player's own container
    assertNil(CM.instances[2].classColor, "the player's container paints the player's class itself")
    assertFalse(CM.instances[2].usesClass, "so no unit swap re-applies it")
    -- red under: SnapshotClass reading an enchant container's own unit
    assertNil(CM.instances[ench].classColor, "enchants are the player's")
    assertFalse(CM.instances[ench].usesClass)
end)

test("container: a class the client withholds resolves to no class instead of raising", function()
    local NS, mocks = fresh({ before = function(m)
        m.UnitClass = function(u)
            if u == "target" then return "Target", "WITHHELD" end
            return "Mage", "MAGE"
        end
    end })
    -- A withheld token raises where the library indexes RAID_CLASS_COLORS with it.
    mocks.RAID_CLASS_COLORS = setmetatable({ MAGE = mocks.RAID_CLASS_COLORS.MAGE }, {
        __index = function(_, k) error("secret key " .. tostring(k)) end,
    })
    -- red under: ClassOf calling NS.ClassColor without pcall
    assertNil((NS.Container.ClassOf("target")))
    assertTrue(NS.SetByPath("container.icons.useClassColorBorder", true, 3))
    mocks.__fireTimers()
    assertNil(NS.ContainerManager.instances[3].classColor.r, "the swatch paints instead")
end)

test("container: a button the engine creates is dressed with the container's class snapshot", function()
    local NS, mocks = freshWithPriestTarget()
    assertTrue(NS.SetByPath("container.style", "bars", 3))   -- a new engine, built after the snapshot
    assertTrue(NS.SetByPath("container.bars.useClassColorBar", true, 3))
    mocks.__fireTimers()
    local inst = NS.ContainerManager.instances[3]
    local init = inst.engine:__callsTo("AddAuraGroup")[1][4].initializeFrame
    local got
    local element = NS.Style.Element
    NS.Style.Element = function(frame, cfg, engine, class)
        got = class
        return element(frame, cfg, engine, class)
    end
    init(mocks.__stubFrame())
    NS.Style.Element = element
    -- red under: InitFrame dressing without the snapshot (a button made mid-combat would show the swatch)
    assertTrue(got ~= nil and got == inst.classColor and got.r == 1, "the priest's color")
end)

-- ── the mouse blocker (owner's 2026-09-14 double-tooltip report, L-3 continued) ─────────────────

-- red under: no blocker at all — the gaps between bars and the container's own padding leave the
-- world unit behind them moused over, drawing its GameTooltip beside the aura's own
-- AuraButtonTooltip.
test("container: a live container has a mouse blocker covering its engine, below its buttons", function()
    local NS = fresh()
    local inst = NS.ContainerManager.instances[1]
    assertTrue(inst.blocker ~= nil)
    -- red under: the blocker covering only the small anchor frame (one element's size) rather than
    -- the engine's real, grown extent
    assertTrue(inst.blocker.__allPointsTo == inst.engine, "it covers the engine's whole extent")
    -- red under: the blocker's frame level left equal to (or above) the engine's, which would put it
    -- between the mouse and a button instead of beneath every one of them
    assertTrue(inst.blocker:GetFrameLevel() < inst.engine:GetFrameLevel())
end)

-- red under: a rebuild (a shape change) leaving the blocker covering the retired engine instead of
-- the replacement.
test("container: a shape change re-anchors the blocker to the new engine", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local oldEngine = inst.engine
    NS.SetByPath("container.filter.whitelist", { [642] = true }, 1)
    mocks.__fireTimers()
    assertTrue(inst.engine ~= oldEngine)
    assertTrue(inst.blocker.__allPointsTo == inst.engine)
    assertTrue(inst.blocker:GetFrameLevel() < inst.engine:GetFrameLevel())
end)

-- red under: deriving the blocker's level from the anchor (or from anything read once, at creation)
-- instead of the engine's own CURRENT level every apply — a later apply can raise layout.level
-- without the already-built engine following it (the mock does not re-base descendants, and neither
-- does the client), which would put the blocker at or above the engine and eat the buttons' own
-- tooltips: the inverse of the reported bug (review round 2).
test("container: raising the anchor's level after the engine exists leaves the blocker strictly below it", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local engine = inst.engine
    local raised = inst.anchor:GetFrameLevel() + 10
    assertTrue(NS.SetByPath("container.layout.level", raised, 1))
    mocks.__fireTimers()
    assertTrue(inst.engine == engine, "a live-editable change: no rebuild")
    assertEqual(inst.anchor:GetFrameLevel(), raised, "the anchor's level did rise")
    assertTrue(inst.blocker:GetFrameLevel() < inst.engine:GetFrameLevel())
end)

-- red under: the blocker ignoring TakesHover and taking the mouse (or clicks) whatever the
-- container's own settings say — a click-through container exists to pass its clicks AND its hover
-- to whatever is behind it, gaps included.
test("container: the blocker follows TakesHover and never takes clicks, matching the live buttons", function()
    local NS, mocks = fresh()
    local function blockerFor(behaviorOver)
        local id = NS.ContainerManager.Create({ behavior = behaviorOver })
        mocks.__fireTimers()
        return NS.ContainerManager.instances[id].blocker
    end
    local on = blockerFor({ tooltips = true, clickThrough = false })
    assertEqual(on.__mouseMotionOn, true)
    assertEqual(on.__mouseClickOn, false)

    local through = blockerFor({ clickThrough = true })
    assertEqual(through.__mouseMotionOn, false)
    assertEqual(through.__mouseClickOn, false)

    local quiet = blockerFor({ tooltips = false })
    assertEqual(quiet.__mouseMotionOn, false)
    assertEqual(quiet.__mouseClickOn, false)
end)

-- red under: a live setting flip (no rebuild) never reaching the blocker, so a container switched to
-- click-through in place keeps blocking the gaps until its next shape change.
test("container: a live click-through flip re-gates the blocker without a rebuild", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local engine = inst.engine
    assertEqual(inst.blocker.__mouseMotionOn, true)
    NS.SetByPath("container.behavior.clickThrough", true, 1)
    mocks.__fireTimers()
    assertTrue(inst.engine == engine, "a live-editable change: no rebuild")
    assertEqual(inst.blocker.__mouseMotionOn, false)
end)

-- red under: ApplyVisibility disabling the engine but leaving the blocker shown — an invisible
-- mouse-blocking rect sitting over the world where nothing is drawn (the inverse of the reported
-- bug, review round 1, B-9).
test("container: a hidden container hides its blocker along with its engine, and Park hides it too", function()
    local NS = fresh()
    local inst = NS.ContainerManager.instances[1]
    assertTrue(inst.blocker:IsShown(), "shown to start")
    NS.db.profile.visibility = "never"
    inst:ApplyVisibility()
    assertFalse(inst.blocker:IsShown(), "hidden along with the engine")
    NS.db.profile.visibility = "always"
    inst:ApplyVisibility()
    assertTrue(inst.blocker:IsShown(), "shown again once visible")
    -- red under: Park leaving the blocker up under combat lockdown
    inst:Park()
    assertFalse(inst.blocker:IsShown())
end)

test("container: on a client without the aura engine a container is deleted without error", function()
    local NS, mocks = fresh({ before = function(m) m.AuraContainerSortMethod = nil end })
    local inst = NS.ContainerManager.instances[3]
    inst.anchor:Show()
    -- red under: Retire without its no-engine guard
    assertTrue(NS.ContainerManager.Delete(3))
    assertFalse(inst.anchor:IsShown(), "torn down all the same")
    assertEqual(#mocks.__engines, 0)
end)

-- red under: ApplyBlocker's unguarded "engineLevel - 1" (feedback E): an engine attached to secret
-- geometry can answer its frame level secret, and the client raises on the arithmetic.
test("container: an engine whose frame level reads secret leaves the blocker at level 0, never raising (E)", function()
    local NS, mocks = fresh()
    local SECRET = 41.5
    mocks.issecretvalue = function(v) return v == SECRET end
    local inst = NS.ContainerManager.instances[1]
    rawset(inst.engine, "GetFrameLevel", function() return SECRET end)
    local ok, err = pcall(inst.ApplyBlocker, inst, inst:Cfg())
    assertTrue(ok, tostring(err))
    assertEqual(inst.blocker:GetFrameLevel(), 0)
end)
