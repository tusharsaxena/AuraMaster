-- tests/test_anchors_teststrip.lua - the test-mode strip on each container (AD-88-AM, LibKa0s#88;
-- WowAddonStandards v2.110.0, preview-mode's *Where the strip sits*). While test mode fills a
-- container with placeholder auras, LibKa0s-Widgets-1.0's amber mode strip docks on the top edge of
-- its placeholder block (`dock = "hud"`, the preview extent), outside it, stacked beyond the drag
-- strip or the name label, and the library places it. A container whose top edge another joins
-- carries none (modules/Anchors.lua, WHICH CONTAINERS), and the seam does not move (SS-3,
-- tests/test_anchors_strip.lua).

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")

--- Every container grows `growV`, one aura wide, so a chain is one column.
local function flow(NS, growV)
    for id = 1, 4 do
        local L = NS.Database.FindContainer(id).layout
        L.axis, L.perLine, L.growH, L.growV = "vertical", 0, "right", growV
    end
end

--- Container `id` joined to container `to` on its after side, straight into the store.
local function join(NS, id, to)
    local c = NS.Database.FindContainer(id)
    c.attach.mode, c.attach.container, c.attach.x, c.attach.y = "container", to, 0, 0
    c.attach.childPoint, c.attach.relPoint = nil, nil
end

local function inst(NS, id) return NS.ContainerManager.instances[id] end

--- Test mode on, the timers run: every container previews.
local function testMode(NS, mocks, on)
    NS.Preview.SetTestMode(on ~= false)
    mocks.__fireTimers()
end

--- The points the library gives the strip when it places it again, as "POINT target|other REL x y".
local function points(strip, relTo)
    local out = {}
    local set = strip.SetPoint
    rawset(strip, "SetPoint", function(self, p, rel, rp, x, y)
        out[#out + 1] = table.concat({ tostring(p), rel == relTo and "target" or "other", tostring(rp),
            tostring(x), tostring(y) }, " ")
        return set(self, p, rel, rp, x, y)
    end)
    strip:Place()
    rawset(strip, "SetPoint", nil)
    if strip.SetPoint ~= set then rawset(strip, "SetPoint", set) end
    return out
end

test("test strip: a locked test mode docks the library's amber strip on each root's placeholder block", function()
    local NS, mocks = fresh()
    -- The paint recorder, so the strip's font string keeps its text (tests/_kit/mock_paint.lua).
    local restore = dofile("tests/_kit/mock_paint.lua")(mocks)
    flow(NS, "down")
    testMode(NS, mocks)
    for id = 1, 4 do
        local i = inst(NS, id)
        if i and i.previewShown then
            local s = i.testStrip
            -- red under: no strip at all (the containers were unmarked, anti-pattern #97)
            assertTrue(s ~= nil, "container " .. id .. " carries a strip")
            assertTrue(s:IsShown(), "shown while it previews")
            assertEqual(s.kind, "test", "the amber flavor: no simulator here")
            assertTrue(type(s.Place) == "function" and type(s.IsFlipped) == "function", "docked by the library")
            assertTrue(s:IsIgnoringParentAlpha(), "a faded container still reads as a test")
            assertEqual(s.text:GetText(), NS.L["Test mode - /am test ends it."])
            local pts = points(s, i.previewExtent)
            assertEqual(#pts, 2, "two points: it spans the block")
            assertTrue(pts[1]:find("^BOTTOMLEFT target TOPLEFT 0") ~= nil, "on the block's top edge: " .. pts[1])
            assertTrue(pts[2]:find("^BOTTOMRIGHT target TOPRIGHT 0") ~= nil, "both corners: " .. pts[2])
        end
    end
    restore()
end)

test("test strip: test mode off hides it, and a container never previewed builds none", function()
    local NS, mocks = fresh()
    for id = 1, 4 do
        assertTrue(inst(NS, id) == nil or inst(NS, id).testStrip == nil, "no strip before a test mode")
    end
    testMode(NS, mocks)
    local i = inst(NS, 1)
    assertTrue(i.testStrip:IsShown())
    testMode(NS, mocks, false)
    -- red under: the strip left up over live auras
    assertFalse(i.testStrip:IsShown(), "hidden with the placeholders")
    assertFalse(i.testStripShown)
end)

test("test strip: growing down, an after follower carries none and the chain's root carries it", function()
    local NS, mocks = fresh()
    flow(NS, "down")
    join(NS, 2, 1)
    NS.ContainerManager.RequestApply()
    testMode(NS, mocks)
    assertTrue(NS.Anchors.CarriesTestStrip(inst(NS, 1)), "the root, on the chain's top")
    -- red under: a strip on the seam, over the parent's last row (D-14's complaint)
    assertFalse(NS.Anchors.CarriesTestStrip(inst(NS, 2)), "its top edge is its parent's seam")
    assertTrue(inst(NS, 1).testStrip:IsShown())
    assertFalse(inst(NS, 2).testStrip ~= nil and inst(NS, 2).testStrip:IsShown(), "no strip shown on the follower")
end)

test("test strip: growing up, the chain's top carries it and a container with an after follower above carries none", function()
    local NS, mocks = fresh()
    flow(NS, "up")
    join(NS, 2, 1)
    NS.ContainerManager.RequestApply()
    testMode(NS, mocks)
    -- red under: the root's strip between it and the follower above it
    assertFalse(NS.Anchors.CarriesTestStrip(inst(NS, 1)), "the follower sits on its top edge")
    assertTrue(NS.Anchors.CarriesTestStrip(inst(NS, 2)), "the follower is the chain's top")
    NS.Database.FindContainer(2).enabled = false
    assertTrue(NS.Anchors.CarriesTestStrip(inst(NS, 1)), "a disabled follower draws nothing above it")
end)

test("test strip: it stacks beyond the drag strip unlocked and beyond the name label locked", function()
    local NS, mocks = fresh()
    flow(NS, "down")
    NS.Database.FindContainer(1).label.show = true
    NS.ContainerManager.RequestApply()
    testMode(NS, mocks)
    local i = inst(NS, 1)
    -- red under: the strip docked with no clear frame, over the label
    assertEqual(i.testStripClear, i.label, "locked: the label is the outermost furniture")
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    assertEqual(i.testStripClear, i.handle, "unlocked: the drag strip sits outside the label")
    NS.Database.FindContainer(1).label.show = false
    NS.SetByPath("locked", true)
    mocks.__fireTimers()
    assertEqual(i.testStripClear, false, "locked with no label: nothing to clear")
end)

test("test strip: a pass that moves nothing re-places it and docks nothing", function()
    local NS, mocks = fresh()
    testMode(NS, mocks)
    local i = inst(NS, 1)
    local docks, places = 0, 0
    local W = mocks.LibStub("LibKa0s-Widgets-1.0")
    local dock = W.DockTestStrip
    W.DockTestStrip = function(...) docks = docks + 1; return dock(...) end
    local place = i.testStrip.Place
    i.testStrip.Place = function(s) places = places + 1; return place(s) end
    i:ApplyVisibility()
    W.DockTestStrip = dock
    -- red under: a re-dock (a spec table) on every visibility pass
    assertEqual(docks, 0, "no re-dock")
    assertEqual(places, 1, "placed again, as a move needs")
end)

test("test strip: the drop of a drag places it again, and a parked container hides it", function()
    local NS, mocks = fresh()
    testMode(NS, mocks)
    local i = inst(NS, 1)
    local places = 0
    local place = i.testStrip.Place
    i.testStrip.Place = function(s) places = places + 1; return place(s) end
    i.dragging = true
    NS.Anchors.Snap.Drop(i)
    -- red under: the flip never read again after a move, which fires no script
    assertEqual(places, 1, "re-placed after the drop")
    i:Park()
    assertFalse(i.testStrip:IsShown(), "parked: hidden")
    assertFalse(i.testStripShown)
end)

-- A block anchored to secret geometry (a container on a frame that holds an aura engine) answers its
-- edges as secret numbers, even out of combat, and the library's placement does arithmetic on them.
-- The harness cannot make a number raise, so the client's issecretvalue names a sentinel secret
-- (tests/test_anchors_handle.lua's pattern) and the block answers it for its top.
local SECRET = 41.5

test("test strip: a block whose edges read secret shows no strip, and none is docked on it", function()
    local NS, mocks = fresh()
    mocks.issecretvalue = function(v) return v == SECRET end
    testMode(NS, mocks)
    local i = inst(NS, 1)
    assertTrue(i.testStrip:IsShown(), "plain edges: the strip is up")
    rawset(i.previewExtent, "GetTop", function() return SECRET end)
    local docks = 0
    local W = mocks.LibStub("LibKa0s-Widgets-1.0")
    local dock, place = W.DockTestStrip, i.testStrip.Place
    W.DockTestStrip = function(...) docks = docks + 1; return dock(...) end
    i.testStrip.Place = function() error("attempt to perform arithmetic on a secret number value") end
    i:ApplyVisibility()
    W.DockTestStrip, i.testStrip.Place = dock, place
    -- red under: the library placing the strip from a secret top (a raise in the client)
    assertFalse(i.testStrip:IsShown(), "no strip over secret geometry")
    assertFalse(i.testStripShown)
    assertEqual(docks, 0, "nothing docked on it")
end)
