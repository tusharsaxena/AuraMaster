-- tests/test_container_twins.lua — a Text container's glow twins (text glow, TG-11): the
-- C.TEXT_GLOW_TWINS twin engines modules/Container_Twins.lua builds beside a glowing container's main
-- engine, with the main's content, each on its own holder at the ring offset and a frame level below
-- the main.
--
-- What is held: built only for a text container with the glow on; anchored, sized and leveled before
-- the first group and given the unit last, like the main; the main's groups, flow and enchant slots
-- with only the button init different; every update path the main takes mirrored in the same pass
-- (an update, a view switch, a unit refresh, every hide path through ApplyLive with the Unit type
-- gate among them, a flip, a park and a delete); a toggle rebuilds, a thickness or offset change
-- re-points the holders and builds nothing, and a toggle in combat or while secret waits for the
-- flush; a twin that cannot be made ends the build; and the twins kept off every interactive,
-- geometry and count path (the mouse, the hang frame, the empty watch, the blocker, the Diagnostics
-- counts).
--
-- Spec: docs/superpowers/specs/2026-10-16-text-glow-addendum-glyph-glow.md (Rendering, Live: twin
-- engines); design note: docs/superpowers/research/2026-10-16-text-glow-twins-design.md, sections 1,
-- 2, 5 and 6. The engine recorder (tests/wow_mock.lua) records each engine's level and size in its
-- call order, stamps every frame's creation, level write and logged engine call on one clock, and
-- logs a plain frame's points, so a holder and its twin can be told apart in time.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")

-- The text starter, "Player cooldowns" (defaults/Profile.lua).
local TEXT = 4

--- A fresh environment with container `id` (the text starter by default) a text container with the
--- glow on, applied.
local function glowing(opts, id)
    local NS, mocks = fresh(opts)
    id = id or TEXT
    if id ~= TEXT then assertTrue(NS.SetByPath("container.style", "text", id)) end
    assertTrue(NS.SetByPath("container.text.glow", true, id))
    mocks.__fireTimers()
    local inst = NS.ContainerManager.instances[id]
    assertEqual(#(inst.twins or {}), NS.Constants.TEXT_GLOW_TWINS, "container " .. id .. " glows")
    return NS, mocks, inst
end

local function twinsOf(inst) return inst.twins or {} end

--- The [Cont] line's twin count.
local function Count(NS, inst) return NS.ContainerTwins.Count(inst) end

--- The main engine, then each twin.
local function enginesOf(inst)
    local out = { inst.engine }
    for _, t in ipairs(twinsOf(inst)) do out[#out + 1] = t end
    return out
end

--- Forget every engine's recorded calls, so a case reads only what follows.
local function forget(inst)
    for _, e in ipairs(enginesOf(inst)) do e.__calls = {} end
end

local function lastIndex(engine, name)
    local idx
    for i, c in ipairs(engine.__calls) do if c[1] == name then idx = i end end
    return idx
end

--- A value as a string, tables by sorted key, functions as "fn" (so two sends can be compared).
local function ser(v)
    if type(v) == "function" then return "fn" end
    if type(v) ~= "table" then return tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. ser(v[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
end

--- Every call to `name` on `engine`, its arguments serialized, joined.
local function sends(engine, name)
    local out = {}
    for _, c in ipairs(engine:__callsTo(name)) do out[#out + 1] = ser({ select(2, unpack(c)) }) end
    return table.concat(out, " | ")
end

--- Group `opts` without its initializeFrame, serialized.
local function groupOpts(opts)
    local copy = {}
    for k, v in pairs(opts) do if k ~= "initializeFrame" then copy[k] = v end end
    return ser(copy)
end

-- ── the build ───────────────────────────────────────────────────────────────────────────────

test("twins: a text container with the glow on builds C.TEXT_GLOW_TWINS twins beside its main, none while off", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[TEXT]
    -- red under: twins built with the glow off (the default)
    assertEqual(#twinsOf(inst), 0, "no twin while off")
    local before = #mocks.__engines
    assertTrue(NS.SetByPath("container.text.glow", true, TEXT))
    mocks.__fireTimers()
    local C = NS.Constants
    -- red under: ContainerClass:Build without its Twins.Build call
    assertEqual(#twinsOf(inst), C.TEXT_GLOW_TWINS)
    -- red under: the glow toggle left out of the structure key (an update in place builds nothing)
    assertEqual(#mocks.__engines - before, 1 + C.TEXT_GLOW_TWINS, "a new main and its twins")
    for k, t in ipairs(inst.twins) do
        assertTrue(t ~= inst.engine, "twin " .. k .. " is its own engine")
        assertEqual(t.__frameType, "AuraContainer")
        assertEqual(t.__template, "CustomAuraContainerTemplate")
        local h = inst.holders[k]
        -- red under: a twin parented to the anchor (no holder to carry its offset)
        assertTrue(h ~= nil and t.__parent == h, "twin " .. k .. " hangs from holder " .. k)
        assertTrue(h.__parent == inst.anchor, "holder " .. k .. " is the anchor's child")
        assertEqual(h.__template, "DisableUntrustedLayoutScriptsTemplate")
    end
end)

test("twins: a bars or icons container with a true glow leaf builds no twin and writes no main level", function()
    local NS = fresh()
    for _, id in ipairs({ 1, 2 }) do
        NS.Database.FindContainer(id).text.glow = true
        local inst = NS.ContainerManager.instances[id]
        inst:Retire()
        inst:Apply()
        -- red under: Twins.On reading the leaf alone, without the text style
        assertEqual(#twinsOf(inst), 0, "container " .. id)
        -- red under: LevelMain writing the main's level whatever the style
        assertEqual(#inst.engine:__callsTo("SetFrameLevel"), 0, "container " .. id .. "'s main level")
    end
end)

test("twins: each twin is anchored, sized and leveled before its first group, its unit last", function()
    local _, _, inst = glowing()
    for k, t in ipairs(inst.twins) do
        local first = t:__firstCall("AddAuraGroup")
        assertTrue(first ~= nil, "twin " .. k .. " has groups")
        for _, name in ipairs({ "SetFlowLayoutAnchorPoint", "ClearAllPoints", "SetPoint", "SetSize", "SetFrameLevel" }) do
            -- red under: a twin anchored or leveled after AddAuraGroup (which forbids it from then on)
            assertTrue((t:__firstCall(name) or math.huge) < first, ("twin %d: %s before its first group"):format(k, name))
        end
        local unitAt = t:__firstCall("SetUnit")
        -- red under: a twin's unit sent before its groups
        assertTrue(unitAt ~= nil and unitAt > lastIndex(t, "AddAuraGroup"), "twin " .. k .. ": the unit last")
        assertEqual(t:__callsTo("SetUnit")[1][2], "player")
        assertEqual(sends(t, "SetSize"), "{1=1,2=1}", "the main's provisional size")
    end
    -- The main is complete, its unit sent last, before the first twin is made.
    local mainUnit = inst.engine:__callsTo("SetUnit")[1]
    -- red under: Twins.Build called before the main's populate (twin 1 made before the main's unit)
    assertTrue(mainUnit ~= nil and mainUnit.at < inst.twins[1].__bornAt, "the main's unit before twin 1")
end)

test("twins: a twin that cannot be made ends the build, so no live twin is out of reach", function()
    local made, fail = 0, nil
    local NS, mocks = fresh({ before = function(m)
        local create = m.CreateFrame
        m.CreateFrame = function(frameType, ...)
            if frameType == "AuraContainer" and fail then
                made = made + 1
                if made == fail then return nil end
            end
            return create(frameType, ...)
        end
    end })
    -- The main is creation 1 under the toggle's rebuild, so creation 3 is twin 2.
    fail = 3
    assertTrue(NS.SetByPath("container.text.glow", true, TEXT))
    mocks.__fireTimers()
    local inst = NS.ContainerManager.instances[TEXT]
    -- red under: Twins.Build going on past the failed twin (twins 3 and 4 live behind a hole)
    assertEqual(made, 3, "no engine made after the failure")
    assertEqual(#twinsOf(inst), 1, "twin 1 alone")
    assertEqual(Count(NS, inst), 1, "the [Cont] count")
    local held = 0
    for _, e in ipairs(mocks.__engines) do
        for _, h in ipairs(inst.holders) do
            if e.__parent == h then
                held = held + 1
                assertTrue(e == inst.twins[1], "every twin engine made is reachable")
            end
        end
    end
    assertEqual(held, 1, "one twin engine made")
end)

test("twins: each twin takes the main's flow and groups, only the button init differing", function()
    local _, _, inst = glowing()
    local main = inst.engine
    local mainGroups = main:__callsTo("AddAuraGroup")
    assertTrue(#mainGroups > 0)
    for k, t in ipairs(inst.twins) do
        for _, name in ipairs({ "SetFlowLayoutAxis", "SetFlowLayoutAnchorPoint", "SetFlowLayoutGrowthDirection",
            "SetFlowLayoutPadding", "SetFlowLayoutMaximumLineSize" }) do
            -- red under: a twin built without applyFlow
            assertEqual(sends(t, name), sends(main, name), ("twin %d: %s"):format(k, name))
        end
        local groups = t:__callsTo("AddAuraGroup")
        assertEqual(#groups, #mainGroups, "twin " .. k .. ": every group")
        for i, g in ipairs(groups) do
            local m = mainGroups[i]
            assertEqual(g[2], m[2], "the key")
            assertEqual(ser(g[3]), ser(m[3]), "the filter string in the same view")
            -- red under: a twin's group built with its own sort, cap or layout
            assertEqual(groupOpts(g[4]), groupOpts(m[4]), ("twin %d group %d's options"):format(k, i))
            -- red under: a twin's buttons dressed by the main's init (a second, live main)
            assertTrue(g[4].initializeFrame ~= m[4].initializeFrame, "its own init")
        end
    end
end)

test("twins: a glowing container with weapon enchants gives each twin the slots, kept apart from the main's", function()
    local _, _, inst = glowing(nil, 1)
    local main = inst.engine
    assertEqual(#main:__callsTo("AddItemEnchantment"), 3)
    for k, t in ipairs(inst.twins) do
        -- red under: a twin built without the enchant slots (the main's weapon names have no glow)
        assertEqual(sends(t, "SetItemEnchantmentSortMethod"), sends(main, "SetItemEnchantmentSortMethod"))
        assertEqual(sends(t, "SetItemEnchantmentLayout"), sends(main, "SetItemEnchantmentLayout"))
        assertEqual(#t:__callsTo("AddItemEnchantment"), 3, "twin " .. k)
        assertEqual(#inst.twinEnchantFrames[k], 3, "twin " .. k .. "'s frames kept")
    end
    -- red under: a twin's enchant frames counted with the main's (ResetEnchants and the [Cont] line)
    assertEqual(#inst.enchantFrames, 3, "the main's own three")
end)

test("twins: holder k sits at thickness x d_k + (X, Y) from the anchor, twin k at the main's own point on it", function()
    local NS, mocks = fresh()
    assertTrue(NS.SetByPath("container.text.glowX", 3, TEXT))
    assertTrue(NS.SetByPath("container.text.glowY", -1, TEXT))
    assertTrue(NS.SetByPath("container.text.glow", true, TEXT))
    mocks.__fireTimers()
    local inst, C = NS.ContainerManager.instances[TEXT], NS.Constants
    local mp = inst.engine:__callsTo("SetPoint")[1]
    for k, h in ipairs(inst.holders) do
        local d = C.TEXT_GLOW_RING[k]
        local x, y = 2 * d[1] + 3, 2 * d[2] - 1
        local log = h.__pointLog or {}
        -- red under: a holder pinned at the anchor's rect with no ring offset, or by one point only
        assertEqual(#log, 2, "holder " .. k .. " is pinned by two points")
        assertEqual(ser(log[1]), ser({ "TOPLEFT", inst.anchor, "TOPLEFT", x, y }), "holder " .. k .. " TOPLEFT")
        assertEqual(ser(log[2]), ser({ "BOTTOMRIGHT", inst.anchor, "BOTTOMRIGHT", x, y }), "holder " .. k .. " BOTTOMRIGHT")
        local tp = inst.twins[k]:__callsTo("SetPoint")[1]
        -- red under: the ring offset applied to the twin's own point too (twice the offset)
        assertEqual(ser({ tp[2], tp[4], tp[5], tp[6] }), ser({ mp[2], mp[4], mp[5], mp[6] }), "twin " .. k)
        assertTrue(tp[3] == h, "twin " .. k .. " is pinned to its holder")
    end
end)

-- ── frame levels ────────────────────────────────────────────────────────────────────────────

test("twins: the main's level is written before its first group, max(anchor + 1, 4), and only with the glow on", function()
    for _, case in ipairs({ { 5, 6 }, { 1, 4 }, { 2, 4 } }) do
        local NS, mocks = fresh()
        assertTrue(NS.SetByPath("container.layout.level", case[1], TEXT))
        assertTrue(NS.SetByPath("container.text.glow", true, TEXT))
        mocks.__fireTimers()
        local e = NS.ContainerManager.instances[TEXT].engine
        local writes = e:__callsTo("SetFrameLevel")
        -- red under: the main's level left to the client (parent + 1 puts the twins' text over the icon)
        assertEqual(#writes, 1, "level " .. case[1])
        assertEqual(writes[1][2], case[2], "level " .. case[1])
        -- red under: the raise taken in Twins.Build, after the main's groups
        assertTrue(e:__firstCall("SetFrameLevel") < e:__firstCall("AddAuraGroup"), "before the first group")
    end
    local NS = fresh()
    -- red under: a level write with the glow off
    assertEqual(#NS.ContainerManager.instances[TEXT].engine:__callsTo("SetFrameLevel"), 0, "glow off")
end)

test("twins: a refused main level write falls back to the main's level as read", function()
    local refuse = false
    local NS, mocks = fresh({ before = function(m)
        local create = m.CreateFrame
        m.CreateFrame = function(frameType, ...)
            local f = create(frameType, ...)
            if frameType == "AuraContainer" and refuse then
                refuse = false
                f.__level = 9
                rawset(f, "SetFrameLevel", function() error("refused") end)
            end
            return f
        end
    end })
    assertTrue(NS.SetByPath("container.layout.level", 1, TEXT))
    assertTrue(NS.SetByPath("container.text.glow", true, TEXT))
    refuse = true
    mocks.__fireTimers()
    local inst = NS.ContainerManager.instances[TEXT]
    -- red under: E kept at the computed 4 after the refusal (the twins then level against a main at 9)
    for k, t in ipairs(inst.twins) do
        assertEqual(t:__callsTo("SetFrameLevel")[1][2], 6, "twin " .. k .. " at 9 - 3")
        -- red under: the same, with Twins.Place not re-leveling the holders after the build
        assertEqual(inst.holders[k].__level, 5, "holder " .. k .. " at 9 - 4")
    end
end)

test("twins: holder k is leveled before twin k is made, twin k at E - 3 and holder k at E - 4", function()
    local _, _, inst = glowing()
    for k, t in ipairs(inst.twins) do
        local h = inst.holders[k]
        local first = (h.__levels or {})[1]
        assertTrue(first ~= nil, "holder " .. k .. " is leveled")
        assertEqual(first[1], 2, "holder " .. k .. " at E - 4")
        -- red under: the twin created (and leveled) before its holder is lowered
        assertTrue(first[2] < t.__bornAt, "holder " .. k .. " leveled before twin " .. k .. " is made")
        local writes = t:__callsTo("SetFrameLevel")
        assertEqual(#writes, 1)
        assertEqual(writes[1][2], 3, "twin " .. k .. " at E - 3")
    end
end)

-- ── mirrored on every update path ───────────────────────────────────────────────────────────

test("twins: a filter change sends every twin the main's own calls, in place", function()
    local NS, mocks, inst = glowing()
    local engines = enginesOf(inst)
    forget(inst)
    assertTrue(NS.SetByPath("container.filter.castBy", "mine", TEXT))
    mocks.__fireTimers()
    local main = inst.engine
    assertTrue(main == engines[1], "the same main")
    assertTrue(#main:__callsTo("SetAuraGroupFilterString") > 0)
    for k, t in ipairs(inst.twins) do
        assertTrue(t == engines[k + 1], "twin " .. k .. " kept")
        -- red under: Update sending the main only
        for _, name in ipairs({ "SetAuraGroupFilterString", "SetAuraGroupCandidateFilters", "SetAuraGroupLayout",
            "SetFlowLayoutAxis" }) do
            assertEqual(sends(t, name), sends(main, name), ("twin %d: %s"):format(k, name))
        end
    end
end)

test("twins: a sort, cap or layout change reaches every twin as it reaches the main", function()
    local NS, mocks, inst = glowing()
    for _, w in ipairs({ { "container.filter.sortMethod", "name" }, { "container.filter.maxAuras", 5 },
        { "container.layout.spacing", 7 } }) do
        forget(inst)
        assertTrue(NS.SetByPath(w[1], w[2], TEXT))
        mocks.__fireTimers()
        local main = inst.engine
        for k, t in ipairs(inst.twins) do
            for _, name in ipairs({ "SetAuraGroupSortMethod", "SetAuraGroupMaxFrameCount", "SetAuraGroupLayout" }) do
                -- red under: a twin left on the old sort, cap or layout
                assertEqual(sends(t, name), sends(main, name), ("%s, twin %d: %s"):format(w[1], k, name))
            end
        end
    end
end)

test("twins: an enchant sort-direction change reaches every twin, not the main alone", function()
    local NS, mocks, inst = glowing(nil, 1)
    forget(inst)
    assertTrue(NS.SetByPath("container.filter.sortDirection", "reverse", 1))
    mocks.__fireTimers()
    local main = inst.engine
    assertEqual(#main:__callsTo("SetItemEnchantmentSortMethod"), 1, "the main's sort")
    for k, t in ipairs(inst.twins) do
        -- red under: the direction recorded after the main's send (the twins then see no change)
        assertEqual(sends(t, "SetItemEnchantmentSortMethod"), sends(main, "SetItemEnchantmentSortMethod"), "twin " .. k)
        assertEqual(sends(t, "SetItemEnchantmentLayout"), sends(main, "SetItemEnchantmentLayout"), "twin " .. k)
    end
end)

test("twins: a unit change reaches every twin, its own engine kept", function()
    -- Player debuffs as a glowing text container: no enchant slots, so a unit change keeps the shape.
    local NS, mocks, inst = glowing(nil, 2)
    local engines = enginesOf(inst)
    forget(inst)
    assertTrue(NS.SetByPath("container.unit", "focus", 2))
    mocks.__fireTimers()
    assertTrue(inst.engine == engines[1], "updated in place")
    assertEqual(sends(inst.engine, "SetUnit"), "{1=focus}")
    for k, t in ipairs(inst.twins) do
        assertTrue(t == engines[k + 1])
        -- red under: self.unit written after the main's send (the twins then see no change)
        assertEqual(sends(t, "SetUnit"), "{1=focus}", "twin " .. k)
    end
end)

test("twins: a view switch sends every twin the main's setters, and a twin's refusal keeps the view stale", function()
    local NS, _, inst = glowing()
    forget(inst)
    inst.viewStale = true
    -- red under: ApplyView switching the main only
    assertEqual(NS.ContainerManager.ApplyViews(inst.unit), 1)
    local main = inst.engine
    assertTrue(#main:__callsTo("SetAuraGroupFilterString") > 0)
    for k, t in ipairs(inst.twins) do
        assertEqual(sends(t, "SetAuraGroupFilterString"), sends(main, "SetAuraGroupFilterString"), "twin " .. k)
        assertEqual(sends(t, "SetAuraGroupCandidateFilters"), sends(main, "SetAuraGroupCandidateFilters"), "twin " .. k)
    end
    assertTrue(inst.viewStale == nil, "every send went through")
    rawset(inst.twins[2], "SetAuraGroupFilterString", function() error("refused") end)
    inst.viewStale = true
    NS.ContainerManager.ApplyViews(inst.unit)
    -- red under: ok taken from the main alone (a twin left on an unknown view is never resent)
    assertTrue(inst.viewStale, "a twin's refusal leaves the view stale")
end)

test("twins: a unit refresh tells every twin to re-read its unit", function()
    local NS, _, inst = glowing()
    forget(inst)
    NS.ContainerManager.RefreshUnit("player")
    assertEqual(#inst.engine:__callsTo("UpdateAllAuras"), 1)
    for k, t in ipairs(inst.twins) do
        -- red under: Refresh calling the main only (the twin shows the last target's auras)
        assertEqual(#t:__callsTo("UpdateAllAuras"), 1, "twin " .. k)
    end
end)

--- Whether every engine of `inst` is enabled as `on`.
local function allEnabled(inst, on, what)
    for i, e in ipairs(enginesOf(inst)) do
        assertEqual(e.__enabled, on, ("%s: engine %d"):format(what, i))
    end
end

test("twins: every hide path disables the twins with the main, and the show path enables them", function()
    local NS, mocks, inst = glowing()
    local CM = NS.ContainerManager
    allEnabled(inst, true, "shown")
    -- red under: ApplyLive enabling or disabling the main only
    NS.Preview.SetTestMode(true)
    allEnabled(inst, false, "test mode")
    NS.Preview.SetTestMode(false)
    allEnabled(inst, true, "test mode off")
    NS.Database.FindContainer(TEXT).filter.zones.none = false
    mocks.__context.inInstance, mocks.__context.instanceType = false, "none"
    CM.ApplyVisibility()
    allEnabled(inst, false, "the zone gate")
    NS.Database.FindContainer(TEXT).filter.zones.none = true
    CM.ApplyVisibility()
    allEnabled(inst, true, "the zone gate open")
    NS.db.profile.visibility = "never"
    CM.ApplyVisibility()
    allEnabled(inst, false, "General visibility")
    NS.db.profile.visibility = "always"
    assertTrue(NS.SetByPath("container.enabled", false, TEXT))
    mocks.__fireTimers()
    allEnabled(inst, false, "a disabled container")
    assertTrue(NS.SetByPath("container.enabled", true, TEXT))
    mocks.__fireTimers()
    allEnabled(inst, true, "enabled again")
    NS.Perf.Suspend()
    allEnabled(inst, false, "the stand-down")
    NS.Perf.Resume()
    allEnabled(inst, true, "resumed")
end)

test("twins: the Unit type gate disables the twins with the main on a unit it is set against", function()
    -- Player debuffs as a glowing target container: no enchant slots, so the unit change keeps the shape.
    local NS, mocks, inst = glowing(nil, 2)
    assertTrue(NS.SetByPath("container.unit", "target", 2))
    mocks.__fireTimers()
    mocks.__unitExists.target, mocks.__isPlayer.target, mocks.__reaction.target = true, false, 2
    mocks.__fireEvent("PLAYER_TARGET_CHANGED")
    allEnabled(inst, true, "an NPC under All")
    assertTrue(NS.SetByPath("container.filter.unitFilter.kind", "player", 2))
    -- red under: ApplyLive disabling the main only (the twins draw a hidden container's glow)
    allEnabled(inst, false, "Players on an NPC")
    mocks.__isPlayer.target, mocks.__reaction.target = true, 1
    mocks.__fireEvent("PLAYER_TARGET_CHANGED")
    allEnabled(inst, true, "Players on a player")
end)

test("twins: a flip turns every twin off and on after the main, and ResetEnchants flips them too", function()
    local _, _, inst = glowing(nil, 1)
    forget(inst)
    assertTrue(inst:Flip())
    for i, e in ipairs(enginesOf(inst)) do
        -- red under: Flip sending the main only (a twin keeps a stale frame the main dropped)
        assertEqual(sends(e, "SetEnabled"), "{1=false} | {1=true}", "engine " .. i)
    end
    forget(inst)
    assertTrue(inst:ResetEnchants())
    for i, e in ipairs(enginesOf(inst)) do
        assertEqual(sends(e, "SetEnabled"), "{1=false} | {1=true}", "reset, engine " .. i)
    end
end)

test("twins: a park disables every twin", function()
    local _, _, inst = glowing()
    inst:Park()
    -- red under: Park disabling the main only
    allEnabled(inst, false, "parked")
end)

test("twins: a delete retires the twins apart from the main, disabled and hidden", function()
    local NS, mocks, inst = glowing()
    local twins, retired = enginesOf(inst), #inst.retired
    table.remove(twins, 1)
    NS.ContainerManager.Delete(TEXT)
    mocks.__fireTimers()
    for k, t in ipairs(twins) do
        -- red under: Retire leaving a twin enabled or shown
        assertFalse(t.__enabled, "twin " .. k .. " disabled")
        assertFalse(t:IsShown(), "twin " .. k .. " hidden")
    end
    -- red under: twins appended to `retired` (whose count means main engines)
    assertEqual(#inst.retired, retired + 1, "only the main among the retired")
    assertEqual(#(inst.retiredTwins or {}), #twins)
    assertEqual(#twinsOf(inst), 0, "no live twin left")
end)

-- ── the lifecycle ───────────────────────────────────────────────────────────────────────────

test("twins: the glow toggle rebuilds, retiring the twins and keeping the holders for the next build", function()
    local NS, mocks, inst = glowing()
    local old, holders = enginesOf(inst), {}
    for k, h in ipairs(inst.holders) do holders[k] = h end
    assertTrue(NS.SetByPath("container.text.glow", false, TEXT))
    mocks.__fireTimers()
    -- red under: the toggle applied in place (the twins would draw on with the glow off)
    assertTrue(inst.engine ~= old[1], "a new main")
    assertEqual(#twinsOf(inst), 0, "no twin while off")
    for i = 2, #old do
        assertFalse(old[i].__enabled, "old twin " .. (i - 1) .. " disabled")
        assertFalse(old[i]:IsShown(), "old twin " .. (i - 1) .. " hidden")
    end
    assertTrue(NS.SetByPath("container.text.glow", true, TEXT))
    mocks.__fireTimers()
    assertEqual(#twinsOf(inst), NS.Constants.TEXT_GLOW_TWINS)
    for k, t in ipairs(inst.twins) do
        -- red under: a new holder per build (frames are never freed)
        assertTrue(inst.holders[k] == holders[k], "holder " .. k .. " kept")
        assertTrue(t.__parent == holders[k])
    end
end)

test("twins: a thickness, X or Y change re-points the holders and builds nothing", function()
    local NS, mocks, inst = glowing()
    local engines, count, C = enginesOf(inst), #mocks.__engines, NS.Constants
    for _, w in ipairs({ { "glowThickness", 3 }, { "glowX", 2 }, { "glowY", -4 } }) do
        assertTrue(NS.SetByPath("container.text." .. w[1], w[2], TEXT))
    end
    mocks.__fireTimers()
    -- red under: the ring's leaves in the structure key (five new engines per slider step)
    assertEqual(#mocks.__engines, count, "no engine built")
    for i, e in ipairs(enginesOf(inst)) do assertTrue(e == engines[i], "engine " .. i .. " kept") end
    for k, h in ipairs(inst.holders) do
        local d = C.TEXT_GLOW_RING[k]
        local x, y = 3 * d[1] + 2, 3 * d[2] - 4
        -- red under: the holders placed only when built
        assertEqual(ser(h.__pointLog[1]), ser({ "TOPLEFT", inst.anchor, "TOPLEFT", x, y }), "holder " .. k)
        assertEqual(ser(h.__pointLog[2]), ser({ "BOTTOMRIGHT", inst.anchor, "BOTTOMRIGHT", x, y }), "holder " .. k)
    end
end)

test("twins: a frame level change re-levels every holder from the main's current level and writes no engine", function()
    local NS, mocks, inst = glowing()
    local engines = enginesOf(inst)
    forget(inst)
    -- A client that re-bases the main on its anchor's change (the design note's unprobed risk).
    inst.engine.__level = 21
    assertTrue(NS.SetByPath("container.layout.level", 20, TEXT))
    mocks.__fireTimers()
    for k, h in ipairs(inst.holders) do
        -- red under: Twins.Place leaving the holders where Build put them (the glow over the text)
        assertEqual(h.__level, 17, "holder " .. k .. " at the main's 21 - 4")
    end
    for i, e in ipairs(enginesOf(inst)) do
        assertTrue(e == engines[i], "engine " .. i .. " kept")
        -- red under: a level written to a live engine
        assertEqual(#e:__callsTo("SetFrameLevel"), 0, "engine " .. i)
    end
end)

test("twins: a color or intensity change re-dresses each twin's buttons in place as that twin", function()
    local NS, mocks, inst = glowing()
    local key = inst.plan.groups[1].key
    for _, t in ipairs(inst.twins) do t.__frames[key] = { mocks.__stubFrame(), mocks.__stubFrame() } end
    inst.engine.__frames[key] = { mocks.__stubFrame() }
    local seen = {}
    local element = NS.Style.Element
    NS.Style.Element = function(frame, cfg, engine, classColor, twin)
        seen[frame] = twin or 0
        return element(frame, cfg, engine, classColor, twin)
    end
    local engines = enginesOf(inst)
    assertTrue(NS.SetByPath("container.text.glowColor", { r = 0, g = 1, b = 0, a = 1 }, TEXT))
    assertTrue(NS.SetByPath("container.text.glowIntensity", 0.8, TEXT))
    mocks.__fireTimers()
    NS.Style.Element = element
    for i, e in ipairs(enginesOf(inst)) do assertTrue(e == engines[i], "engine " .. i .. " kept") end
    assertEqual(seen[inst.engine.__frames[key][1]], 0, "the main's button as the main")
    for k, t in ipairs(inst.twins) do
        for j, f in ipairs(t.__frames[key]) do
            -- red under: Restyle walking the main's buttons only (a twin keeps the old color)
            assertEqual(seen[f], k, ("twin %d button %d re-dressed as twin %d"):format(k, j, k))
        end
    end
    -- red under: Restyle's count taking in the twins' buttons (perf's restyle figures)
    assertEqual(inst:Restyle(NS.Database.FindContainer(TEXT)), 1, "the main's count")
end)

test("twins: a color change re-dresses each twin's enchant frames in place as that twin", function()
    local NS, mocks, inst = glowing(nil, 1)
    local seen = {}
    local element = NS.Style.Element
    NS.Style.Element = function(frame, cfg, engine, classColor, twin)
        seen[frame] = twin or 0
        return element(frame, cfg, engine, classColor, twin)
    end
    assertTrue(NS.SetByPath("container.text.glowColor", { r = 0, g = 1, b = 0, a = 1 }, 1))
    mocks.__fireTimers()
    NS.Style.Element = element
    for j, f in ipairs(inst.enchantFrames) do
        assertEqual(seen[f], 0, "the main's enchant frame " .. j .. " as the main")
    end
    for k in ipairs(inst.twins) do
        for j, f in ipairs(inst.twinEnchantFrames[k]) do
            -- red under: Restyle walking the twins' group frames only (a twin's weapon names keep the old color)
            assertEqual(seen[f], k, ("twin %d enchant frame %d re-dressed as twin %d"):format(k, j, k))
        end
    end
end)

test("twins: a glow toggle in combat or while auras are secret waits for the flush", function()
    for _, hold in ipairs({ "__lockdown", "__aurasSecret" }) do
        local NS, mocks = fresh()
        local inst = NS.ContainerManager.instances[TEXT]
        mocks[hold] = true
        assertTrue(NS.SetByPath("container.text.glow", true, TEXT))
        mocks.__fireTimers()
        -- red under: a twin built under the hold (an aura engine's ancestry made in lockdown)
        assertEqual(#twinsOf(inst), 0, hold)
        mocks[hold] = false
        NS.ContainerManager.FlushPending("regen")
        assertEqual(#twinsOf(inst), NS.Constants.TEXT_GLOW_TWINS, hold .. " lifted")
    end
end)

test("twins: the structure key carries the glow, so a toggle rebuilds and nothing else of the glow does", function()
    local NS = fresh()
    local S = NS.Style
    local c = NS.Database.FindContainer(TEXT)
    local off = S.StructureKey(c)
    c.text.glow = true
    -- red under: StructureKey without the glow
    assertEqual(S.StructureKey(c), off .. ":glow")
    c.text.glowThickness, c.text.glowX, c.text.glowIntensity = 5, 9, 0.3
    assertEqual(S.StructureKey(c), off .. ":glow", "the ring and the look are not structure")
    local bars = NS.Database.FindContainer(1)
    bars.text.glow = true
    assertEqual(S.StructureKey(bars), "bars", "a bars container's key ignores a stale leaf")
end)

-- ── kept apart ──────────────────────────────────────────────────────────────────────────────

test("twins: a twin's buttons take no mouse, no click and no cancel", function()
    local B = dofile("tests/region_builder.lua")
    local NS, mocks, inst = glowing({ before = dofile("tests/text_apis.lua") })
    NS.Database.FindContainer(TEXT).behavior.cancelOnRightClick = true
    for k, t in ipairs(inst.twins) do
        local init = t:__callsTo("AddAuraGroup")[1][4].initializeFrame
        local frame = B.new({})
        B.during(mocks, {}, function() init(frame) end)
        -- red under: a twin's init dressing its button as a main (the frame picker and the hover)
        assertEqual(frame:__joined("SetMouseMotionEnabled"), "false", "twin " .. k)
        assertEqual(frame:__joined("SetMouseClickEnabled"), "false", "twin " .. k)
        assertEqual(frame:__joined("SetCancelAuraButtons"), "nil", "twin " .. k)
    end
end)

test("twins: the hang frame and the mouse blocker are the main's, never a twin", function()
    local NS, _, inst = glowing()
    -- red under: a twin taken as the container's engine for a follower to hang from
    assertTrue(NS.Anchors.HangFrame(inst) == inst.engine)
    assertTrue(inst.blocker.__allPointsTo == inst.engine, "the blocker covers the main")
    assertEqual(inst.blocker.__level, inst.engine.__level - 1, "one below the main")
end)

test("twins: Diagnostics' frame, shown and button counts read the main, never a twin", function()
    local NS, mocks, inst = glowing()
    local key = inst.plan.groups[1].key
    local a, b, hidden = mocks.__stubFrame(), mocks.__stubFrame(), mocks.__stubFrame()
    hidden:Hide()
    inst.engine.__frames[key] = { a, b, hidden }
    for _, t in ipairs(inst.twins) do
        t.__frames[key] = { mocks.__stubFrame(), mocks.__stubFrame(), mocks.__stubFrame(), mocks.__stubFrame(),
            mocks.__stubFrame() }
    end
    local out = NS.DebugLog:BuildDiagnostics()
    local plan, buttons = nil, 0
    for _, l in ipairs(out.lines) do
        if l[1] == "Plan" and l[2]:find("#" .. TEXT .. " " .. key .. " ", 1, true) then plan = l[2] end
        if l[1] == "Shown" and l[2]:find("#" .. TEXT .. " " .. key .. " btn", 1, true) then buttons = buttons + 1 end
    end
    -- red under: frameCounts reading a twin's pool (a twin's five buttons reported as the group's)
    assertTrue(plan ~= nil and plan:find("frames=3 shown=2", 1, true) ~= nil, tostring(plan))
    -- red under: groupButtons reading a twin's pool (a twin's buttons listed as shown auras)
    assertEqual(buttons, 2, "the main's two shown buttons")
end)

test("twins: the empty watch reads the main's pool only", function()
    local NS, mocks, inst = glowing()
    local reads = 0
    mocks.C_UnitAuras = {
        GetAuraSlots = function() reads = reads + 1; return nil, 1 end,
        GetAuraDataBySlot = function() return { spellId = 774, name = "Rejuvenation" } end,
    }
    local key = inst.plan.groups[1].key
    for _, t in ipairs(inst.twins) do t.__frames[key] = { mocks.__stubFrame() } end
    -- An empty main pool is empty without a read, whatever the twins hold.
    -- red under: poolOf reading a twin's pool (a filled twin would send the main's empty pool to a read)
    assertTrue(NS.EmptyWatch.Predict(inst) == true, "predicted empty")
    assertEqual(reads, 0, "no aura read")
end)
