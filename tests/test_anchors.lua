-- tests/test_anchors.lua — modules/Anchors.lua (where a container sits) and modules/FramePicker.lua
-- (clicking a frame to attach to).

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")

--- A frame another addon would have created, planted under a global name.
local function plant(mocks, name, opts)
    opts = opts or {}
    local f = mocks.__stubFrame()
    f.GetName = function() return name end
    f.IsForbidden = function() return opts.forbidden == true end
    f.GetParent = function() return opts.parent end
    mocks.__globals[name] = f
    return f
end

test("anchors: a chain that would loop is detected", function()
    local NS = fresh()
    local c2 = NS.Database.FindContainer(2)
    c2.attach.mode, c2.attach.container = "container", 1
    assertTrue(NS.Anchors.WouldCycle(1, 2))
    assertFalse(NS.Anchors.WouldCycle(1, 3))
    assertTrue(NS.Anchors.WouldCycle(1, 1))
end)

test("anchors: a container attaches to another one, and a loop falls back to the screen", function()
    local NS = fresh()
    local CM = NS.ContainerManager
    local c1, c2 = NS.Database.FindContainer(1), NS.Database.FindContainer(2)
    c2.attach.mode, c2.attach.container = "container", 1
    assertEqual(NS.Anchors.Place(CM.instances[2]), "container")
    c1.attach.mode, c1.attach.container = "container", 2
    assertEqual(NS.Anchors.Place(CM.instances[1]), "screen")
end)

test("anchors: a named frame that does not exist yet waits, and attaches once it does", function()
    local NS, mocks = fresh()
    local c = NS.Database.FindContainer(1)
    c.attach.mode, c.attach.frame = "frame", "SomeAddonBar"
    local inst = NS.ContainerManager.instances[1]
    assertEqual(NS.Anchors.Place(inst), "screen")
    assertEqual(table.concat(NS.Anchors.Pending(), ","), "1")
    plant(mocks, "SomeAddonBar")
    NS.Anchors.ResolvePending()
    assertEqual(#NS.Anchors.Pending(), 0)
    assertEqual(NS.Anchors.Place(inst), "frame")
end)

test("anchors: a forbidden frame, or something that is not a frame, is never a target", function()
    local NS, mocks = fresh()
    plant(mocks, "Forbidden", { forbidden = true })
    assertNil(NS.Anchors.ResolveFrame("Forbidden"))
    mocks.__globals.NotAFrame = { 1, 2, 3 }
    assertNil(NS.Anchors.ResolveFrame("NotAFrame"))
    assertNil(NS.Anchors.ResolveFrame(""))
end)

test("anchors: a drag saves the dragged container's position, rounded, whatever is selected", function()
    local NS = fresh()
    local inst = NS.ContainerManager.instances[1]
    inst.anchor.GetPoint = function() return "TOPLEFT", nil, "BOTTOMLEFT", 12.34, -56.78 end
    NS.State.SetActiveContainer(2)
    NS.Anchors.SavePosition(inst)
    local pos = NS.Database.FindContainer(1).position
    assertEqual(pos.point, "TOPLEFT")
    assertEqual(pos.relativePoint, "BOTTOMLEFT")
    assertEqual(pos.x, 12.3)
    assertEqual(pos.y, -56.8)
    assertEqual(NS.Database.FindContainer(2).position.x, NS.STARTER_CONTAINERS[2].position.x)
end)

-- ── the frame picker ──────────────────────────────────────────────────────────────────────────

test("picker: a frame resolves to its nearest named ancestor, skipping the screen and ourselves", function()
    local NS, mocks = fresh()
    local named = plant(mocks, "PlayerFrame")
    local child = mocks.__stubFrame()
    child.GetName = function() return nil end
    child.GetParent = function() return named end
    local f, name = NS.FramePicker.NamedAncestor(child)
    assertTrue(f == named)
    assertEqual(name, "PlayerFrame")
    local ours = plant(mocks, "AuraMasterAnchor9")
    assertNil(NS.FramePicker.NamedAncestor(ours))
end)

test("picker: it arms on release, then a left-click on a named frame picks it", function()
    local NS, mocks = fresh()
    local target = plant(mocks, "TargetFrame")
    local picked, canceled
    mocks.__mouseDown.LeftButton = true   -- the click on "Pick a frame" is still held
    NS.FramePicker.Start(function(name) picked = name end, function() canceled = true end)
    local overlay = mocks.__globals.AuraMasterFramePicker
    mocks.__foci = { target }
    overlay:__fire("OnUpdate")
    assertNil(picked, "the click that started the pick cannot pick the frame behind the button")
    mocks.__mouseDown.LeftButton = false
    overlay:__fire("OnUpdate")
    mocks.__mouseDown.LeftButton = true
    overlay:__fire("OnUpdate")
    assertEqual(picked, "TargetFrame")
    assertNil(canceled)
    assertFalse(NS.FramePicker.IsActive())
end)

test("picker: combat starting mid-pick cancels it", function()
    -- red under: onUpdate no longer checking InCombatLockdown before touching the overlay.
    local NS, mocks = fresh()
    local picked, canceled
    NS.FramePicker.Start(function(name) picked = name end, function() canceled = true end)
    mocks.__lockdown = true
    mocks.__globals.AuraMasterFramePicker:__fire("OnUpdate")
    assertTrue(canceled)
    assertNil(picked)
    assertFalse(NS.FramePicker.IsActive())
end)

test("picker: Escape cancels", function()
    local NS, mocks = fresh()
    local canceled = false
    NS.FramePicker.Start(function() end, function() canceled = true end)
    mocks.__globals.AuraMasterFramePicker:__fire("OnKeyDown", "ESCAPE")
    assertTrue(canceled)
    mocks.__fireTimers()
end)
