-- tests/test_container_zones.lua — where a container shows (filter situations, S3 of
-- docs/superpowers/specs/2026-10-02-filter-situations-design.md): `filter.zones` gating
-- ContainerClass:ShouldShow by NS.Compat.InstanceType(), IsInInstance()'s instance type, as
-- `(not p.locked) or previewing or (visibilityAllows(p.visibility) and zoneAllows(cfg))`.
--
-- An unticked kind of place hides a LOCKED container there, through the combat-legal path the
-- General visibility rule takes (ApplyLive: the engine's SetEnabled and our own blocker), never the
-- anchor under lockdown. An unlocked or test-mode container still shows, so it can be found. A type
-- with no checkbox, or one that cannot be read, is allowed. PLAYER_ENTERING_WORLD and
-- ZONE_CHANGED_NEW_AREA re-run the visibility pass, and the first pass after a /reload already reads
-- the place. A follower of a zone-hidden parent re-seams as it does for a visibility-hidden one.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")

--- Put the player in a `kind` of place (IsInInstance's second value; the kit's mock answers from
--- its context). `nil` is a type the client did not give.
local function place(mocks, kind)
    mocks.__context.inInstance = kind ~= nil and kind ~= "none"
    mocks.__context.instanceType = kind
end

--- Untick zone `kind` on container `id` through the write seam, and let it apply.
local function untick(NS, mocks, id, kind)
    assertTrue(NS.SetByPath("container.filter.zones." .. kind, false, id))
    mocks.__fireTimers()
end

-- ── the gate ────────────────────────────────────────────────────────────────────────────────

test("zones: a locked container is hidden in each unticked kind of place and shown in the others", function()
    for _, kind in ipairs({ "none", "party", "scenario", "raid", "pvp", "arena" }) do
        local NS, mocks = fresh()
        local inst = NS.ContainerManager.instances[1]
        untick(NS, mocks, 1, kind)
        for _, other in ipairs({ "none", "party", "scenario", "raid", "pvp", "arena" }) do
            place(mocks, other)
            NS.ContainerManager.ApplyVisibility()
            -- red under: ShouldShow without the zone gate (every place shows the container)
            assertEqual((inst:ShouldShow()), other ~= kind, kind .. " unticked, in " .. other)
            assertEqual(inst.engine.__enabled, other ~= kind, "the engine follows, " .. other)
            assertEqual(inst.blocker:IsShown(), other ~= kind, "and the blocker, " .. other)
        end
        assertTrue((NS.ContainerManager.instances[2]:ShouldShow()), "another container keeps its own zones")
    end
end)

test("zones: a type with no checkbox, no type and an unreadable answer are all allowed", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    for _, kind in ipairs({ "none", "party", "scenario", "raid", "pvp", "arena" }) do
        NS.Database.FindContainer(1).filter.zones[kind] = false
    end
    place(mocks, "neighborhood")
    -- red under: an unknown type read as Open world (housing hidden with Open world unticked)
    assertTrue((inst:ShouldShow()), "a type with no checkbox")
    place(mocks, nil)
    assertTrue((inst:ShouldShow()), "no type")
    mocks.IsInInstance = function() error("refused") end
    -- red under: an unguarded IsInInstance (the error escapes the show ladder)
    assertTrue((inst:ShouldShow()), "an unreadable answer")
end)

test("zones: unlocked or in test mode, a container shows in an unticked place, so it can be found", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    untick(NS, mocks, 1, "party")
    place(mocks, "party")
    NS.ContainerManager.ApplyVisibility()
    assertFalse((inst:ShouldShow()), "locked: hidden")
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    -- red under: the zone gate ANDed outside the lock (an unlocked container could not be found)
    assertTrue((inst:ShouldShow()), "unlocked: shown")
    assertTrue(inst.engine.__enabled, "its live auras drawing")
    NS.SetByPath("locked", true)
    NS.Preview.SetTestMode(true)
    mocks.__fireTimers()
    local show, previewing = inst:ShouldShow()
    -- red under: the zone gate ANDed outside test mode
    assertTrue(show, "test mode: shown")
    assertTrue(previewing)
end)

test("zones: the zone gate sits beside General visibility, both must allow", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    place(mocks, "raid")
    NS.db.profile.visibility = "never"
    -- red under: the zone gate ORed with visibility (an allowed zone re-showing a "never" container)
    assertFalse((inst:ShouldShow()), "visibility never in an allowed place")
    NS.db.profile.visibility = "always"
    assertTrue((inst:ShouldShow()))
end)

-- ── combat legality ─────────────────────────────────────────────────────────────────────────

test("zones: a place change under lockdown disables the engine and never hides the anchor", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    untick(NS, mocks, 1, "party")
    mocks.__lockdown, mocks.__inCombat = true, true
    place(mocks, "party")
    mocks.__fireEvent("ZONE_CHANGED_NEW_AREA")
    -- red under: hiding through the anchor (the aura engine's ancestry, blocked under lockdown)
    assertTrue(inst.anchor:IsShown(), "the anchor stays shown")
    assertFalse(inst.engine.__enabled, "the engine is off")
    assertFalse(inst.blocker:IsShown(), "and its blocker")
end)

-- ── the events and the first pass ───────────────────────────────────────────────────────────

test("zones: ZONE_CHANGED_NEW_AREA and PLAYER_ENTERING_WORLD each re-run the visibility pass", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    untick(NS, mocks, 1, "party")
    place(mocks, "party")
    mocks.__fireEvent("ZONE_CHANGED_NEW_AREA")
    -- red under: ZONE_CHANGED_NEW_AREA not registered (a border crossing never re-runs the pass)
    assertFalse(inst.engine.__enabled, "into a dungeon: hidden")
    place(mocks, "none")
    mocks.__fireEvent("ZONE_CHANGED_NEW_AREA")
    assertTrue(inst.engine.__enabled, "back in the open world: shown")
    place(mocks, "party")
    mocks.__fireEvent("PLAYER_ENTERING_WORLD")
    assertFalse(inst.engine.__enabled, "a loading screen into a dungeon: hidden")
end)

test("zones: the first visibility pass after a /reload inside an unticked place already hides it", function()
    local NS, mocks = fresh()
    untick(NS, mocks, 1, "party")
    local saved = _G.AuraMasterDB
    local NS2 = fresh({ savedVariables = saved, before = function(m) place(m, "party") end })
    local inst = NS2.ContainerManager.instances[1]
    assertEqual(NS2.Database.FindContainer(1).filter.zones.party, false, "the reload kept the setting")
    -- red under: the place read only at PLAYER_ENTERING_WORLD (a /reload in a dungeon showed it until then)
    assertFalse(inst.engine.__enabled, "hidden before any PLAYER_ENTERING_WORLD")
    assertFalse(inst.blocker:IsShown())
end)

-- ── followers ───────────────────────────────────────────────────────────────────────────────

local STRIP_H, STRIP_GAP = 18, 2

--- A column chain: container 2 joined ahead-start to container 1, whose name label shows. Locked.
local function sideChain(setup)
    local NS, mocks = fresh({ before = setup })
    for id = 1, 2 do
        local L = NS.Database.FindContainer(id).layout
        L.axis, L.perLine = "vertical", 0
    end
    local c = NS.Database.FindContainer(2)
    c.attach.mode, c.attach.container, c.attach.x, c.attach.y = "container", 1, 0, 0
    c.attach.childPoint, c.attach.relPoint = NS.Anchors.EdgePoints(NS.Anchors.EffectiveLayout(c), "ahead-start")
    NS.Database.FindContainer(1).label.show = true
    NS.ContainerManager.RequestApply()
    mocks.__fireTimers()
    return NS, mocks
end

--- The y offset container 2 was last placed with.
local function followerY(NS)
    local rec = {}
    local two = NS.ContainerManager.instances[2]
    rawset(two.anchor, "SetPoint", function(_, ...) rec[#rec + 1] = { ... } end)
    NS.Anchors.Place(two)
    rawset(two.anchor, "SetPoint", nil)
    return rec[#rec][5]
end

test("zones: a follower of a zone-hidden parent re-seams as it does for a visibility-hidden one", function()
    local NS, mocks = sideChain()
    local one = NS.ContainerManager.instances[1]
    assertEqual(followerY(NS), -(STRIP_H + STRIP_GAP) - 1, "shown: past the parent's label row")
    untick(NS, mocks, 1, "party")
    place(mocks, "party")
    mocks.__fireEvent("ZONE_CHANGED_NEW_AREA")
    -- red under: the zone gate outside ShouldShow (the parent's label kept its row over the follower)
    assertFalse(one.label:IsShown(), "the parent's label hides with it")
    local zoneY = followerY(NS)
    assertEqual(zoneY, -1, "the label row given back")

    local NS2 = sideChain()
    NS2.SetByPath("visibility", "never")
    NS2.ContainerManager.ApplyVisibility()
    assertEqual(followerY(NS2), zoneY, "the same seam as a visibility-hidden parent")
    place(mocks, "none")
    mocks.__fireEvent("ZONE_CHANGED_NEW_AREA")
    assertEqual(followerY(NS), -(STRIP_H + STRIP_GAP) - 1, "shown again: the row comes back")
end)
