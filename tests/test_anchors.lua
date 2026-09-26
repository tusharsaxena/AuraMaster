-- tests/test_anchors.lua — modules/Anchors.lua (where a container sits) and modules/FramePicker.lua
-- (clicking a frame to attach to). The drag handle's own cases live in tests/test_anchors_handle.lua
-- (AM-ATS-02); the one inherited-flow case here that reads the handle records it through
-- tests/handle_recorder.lua.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local HR = dofile("tests/handle_recorder.lua")
local recordedHandle, last = HR.recordedHandle, HR.last

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

test("anchors: a frame that appears during combat is attached when combat ends", function()
    local NS, mocks = fresh()
    local CM = NS.ContainerManager
    NS.SetByPath("container.attach.frame", "LateFrame", 1)
    NS.SetByPath("container.attach.mode", "frame", 1)
    mocks.__fireTimers()
    assertEqual(table.concat(NS.Anchors.Pending(), ","), "1", "pending: the frame does not exist yet")
    mocks.__lockdown = true
    local late = plant(mocks, "LateFrame")
    NS.addon:OnAddonLoaded()
    assertEqual(table.concat(NS.Anchors.Pending(), ","), "1", "an add-on loading in combat resolves nothing")
    -- Nothing is queued, so FlushPending cannot re-place it: only ResolvePending can.
    local requests, realRequest = 0, CM.RequestApply
    CM.RequestApply = function(...) requests = requests + 1; return realRequest(...) end
    local anchor, relTo = CM.instances[1].anchor, nil
    rawset(anchor, "SetPoint", function(_, _, rel) relTo = rel end)
    mocks.__lockdown = false
    NS.addon:OnCombatChanged("PLAYER_REGEN_ENABLED")
    rawset(anchor, "SetPoint", nil)
    CM.RequestApply = realRequest
    -- red under: removing the ResolvePending call in OnCombatChanged
    assertEqual(#NS.Anchors.Pending(), 0)
    assertTrue(relTo == late, "anchored to LateFrame")
    assertEqual(requests, 0)
end)

test("anchors: a screen fallback and a skipped resolve are traced", function()
    local NS, mocks = fresh()
    local lines = {}
    NS.Debug = function(tag, fmt, ...)
        if tag == "Anchor" then
            lines[#lines + 1] = fmt:format(...)
        end
    end
    local CM = NS.ContainerManager
    NS.Anchors.Place(CM.instances[2])
    -- red under: tracing a screen container's placement as a fallback
    assertEqual(#lines, 0, "a container set to the screen is not a fallback")
    local c = NS.Database.FindContainer(1)
    c.attach.mode, c.attach.frame = "frame", "MissingBar"
    assertEqual(NS.Anchors.Place(CM.instances[1]), "screen")
    -- red under: dropping the Place trace
    assertEqual(#lines, 1, "one fallback line")
    assertTrue(lines[1]:find("screen fallback", 1, true) ~= nil, lines[1])
    mocks.__lockdown = true
    NS.Anchors.ResolvePending()
    mocks.__lockdown = false
    assertEqual(#lines, 2, "one skip line")
    assertTrue(lines[2]:find("lockdown", 1, true) ~= nil, lines[2])
end)

test("anchors: a forbidden frame, or something that is not a frame, is never a target", function()
    local NS, mocks = fresh()
    plant(mocks, "Forbidden", { forbidden = true })
    assertNil(NS.Anchors.ResolveFrame("Forbidden"))
    mocks.__globals.NotAFrame = { 1, 2, 3 }
    assertNil(NS.Anchors.ResolveFrame("NotAFrame"))
    assertNil(NS.Anchors.ResolveFrame(""))
end)

test("anchors: a forbidden frame falls back to the screen without waiting, so an add-on load never re-places it", function()
    local NS, mocks = fresh()
    local lines = {}
    NS.Debug = function(tag, fmt, ...)
        if tag == "Anchor" then
            lines[#lines + 1] = fmt:format(...)
        end
    end
    plant(mocks, "LockedBar", { forbidden = true })
    local c = NS.Database.FindContainer(1)
    c.attach.mode, c.attach.frame = "frame", "LockedBar"
    local CM = NS.ContainerManager
    assertEqual(NS.Anchors.Place(CM.instances[1]), "screen", "the screen fallback")
    assertEqual(#lines, 1, "the fallback is traced as any other")
    assertTrue(lines[1]:find("screen fallback", 1, true) ~= nil, lines[1])
    -- red under: targetFor queuing every frame name that does not resolve, the forbidden one included
    assertEqual(#NS.Anchors.Pending(), 0, "a forbidden frame never becomes a target, so nothing waits")
    local placed = {}
    local place = NS.Anchors.Place
    NS.Anchors.Place = function(inst)
        placed[#placed + 1] = inst.id
        return place(inst)
    end
    NS.addon:OnAddonLoaded()
    NS.Anchors.Place = place
    assertEqual(#placed, 0, "an add-on load re-places nothing")
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

test("anchors: a drag saves the position in one write", function()
    local NS = fresh()
    local inst = NS.ContainerManager.instances[1]
    inst.anchor.GetPoint = function() return "TOP", nil, "TOP", 5, -30 end
    local writes, paths = 0, {}
    NS.NewBusTarget():RegisterMessage(NS.MSG.CONFIG_CHANGED, function(_, p)
        writes = writes + 1
        paths[#paths + 1] = p.path
    end)
    NS.Anchors.SavePosition(inst)
    -- red under: four leaf writes
    assertEqual(writes, 1, table.concat(paths, ","))
    assertEqual(paths[1], "container.position")
end)

-- ── the frame picker ──────────────────────────────────────────────────────────────────────────

test("picker: a frame resolves to its nearest named ancestor, skipping the screen and ourselves", function()
    local NS, mocks = fresh()
    local named = plant(mocks, "PlayerFrame")
    local child = mocks.__stubFrame()
    child.GetName = function() return nil end
    child.IsForbidden = function() return false end   -- the kit stub answers any method truthy
    child.GetParent = function() return named end
    local f, name = NS.FramePicker.NamedAncestor(child)
    assertTrue(f == named)
    assertEqual(name, "PlayerFrame")
    local ours = plant(mocks, "AuraMasterAnchor9")
    assertNil(NS.FramePicker.NamedAncestor(ours))
end)

test("picker: a forbidden frame under the cursor ends the walk without calling its methods", function()
    -- red under: calling GetName before the IsForbidden check.
    local NS = fresh()
    local stub = {
        IsForbidden = function() return true end,
        GetName = function() error("forbidden") end,
        GetParent = function() error("forbidden") end,
    }
    local ok, f = pcall(NS.FramePicker.NamedAncestor, stub)
    assertTrue(ok)
    assertNil(f)
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

-- ── placement ─────────────────────────────────────────────────────────────────────────────────

--- Record every SetPoint, ClearAllPoints and SetSize made on a container's anchor. `refuse(rel)`
--- makes a SetPoint against `rel` raise, as the client does for a restricted target.
local function recordAnchor(inst, refuse)
    local rec = { points = {}, clears = 0 }
    rawset(inst.anchor, "SetPoint", function(_, ...)
        local rel = select(2, ...)
        if refuse and refuse(rel) then error("Anchoring disallowed") end
        local n = #rec.points
        rec.points[n + 1] = { ... }
    end)
    rawset(inst.anchor, "ClearAllPoints", function() rec.clears = rec.clears + 1 end)
    rawset(inst.anchor, "SetSize", function(_, w, h) rec.size = w .. "," .. h end)
    return rec
end

test("anchors: a screen container sits at its stored point on UIParent, sized to one element", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local c = NS.Database.FindContainer(1)
    c.position = { point = "TOPRIGHT", relativePoint = "BOTTOMRIGHT", x = 12, y = -7 }
    local rec = recordAnchor(inst)
    assertEqual(NS.Anchors.Place(inst), "screen")
    local w, h = NS.Style.ElementSize(c)
    assertEqual(rec.size, w .. "," .. h, "one element in size")
    assertEqual(#rec.points, 1)
    local p = rec.points[1]
    -- red under: toScreen reading the template's position rather than the stored one
    assertEqual(p[1], "TOPRIGHT"); assertTrue(p[2] == mocks.UIParent); assertEqual(p[3], "BOTTOMRIGHT")
    assertEqual(p[4], 12); assertEqual(p[5], -7)
    c.position = { point = "LEFT", x = 1 }
    rec = recordAnchor(inst)
    NS.Anchors.Place(inst)
    p = rec.points[1]
    -- red under: a missing relative point filled from the template (CENTER) instead of the point itself
    assertEqual(p[3], "LEFT", "no relative point: the same point on the screen")
    assertEqual(p[5], 0, "a missing offset is 0")
end)

test("anchors: a container attaches to its target's engine frame at the derived points, or to its anchor before it has one", function()
    local NS = fresh()
    local CM = NS.ContainerManager
    local c2 = NS.Database.FindContainer(2)
    c2.attach = { mode = "container", container = 1, point = "TOPRIGHT", relativePoint = "TOPLEFT", x = -3, y = 4 }
    local rec = recordAnchor(CM.instances[2])
    assertEqual(NS.Anchors.Place(CM.instances[2]), "container")
    local p = rec.points[1]
    -- red under: targetFor anchoring to the target's anchor (a container would not follow its target's growth)
    assertTrue(p[2] == CM.instances[1].engine, "the target's engine frame")
    -- Container 1 fills columns growing right and down, so 2 continues below it (L-6).
    -- red under: Place handing SetPoint the stored attach.point in container mode
    assertEqual(p[1], "TOPLEFT"); assertEqual(p[3], "BOTTOMLEFT")
    -- red under: the derived points dropping the stored offsets (they nudge on top of one of 2's
    -- spacings below 1's block: SS-1, SS-2), plus the engine's one-unit lead taken back across (the engine lead)
    assertEqual(p[4], -3 + 1); assertEqual(p[5], 4 - c2.layout.spacing)
    local engine = CM.instances[1].engine
    CM.instances[1].engine = nil
    rec = recordAnchor(CM.instances[2])
    NS.Anchors.Place(CM.instances[2])
    CM.instances[1].engine = engine
    assertTrue(rec.points[1][2] == CM.instances[1].anchor, "no engine yet: the target's anchor")
end)

test("anchors: a container never attaches to itself or to one that does not exist", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local c = NS.Database.FindContainer(1)
    c.attach.mode, c.attach.container = "container", 1
    local rec = recordAnchor(inst)
    -- red under: targetFor without its self check
    assertEqual(NS.Anchors.Place(inst), "screen", "itself")
    assertTrue(rec.points[1][2] == mocks.UIParent)
    c.attach.container = 99
    assertEqual(NS.Anchors.Place(inst), "screen", "a container that does not exist")
    assertEqual(#NS.Anchors.Pending(), 0, "and neither waits for anything")
end)

test("anchors: a frame target takes the stored attach point, relative point and offsets", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local target = plant(mocks, "PlayerFrame")
    NS.Database.FindContainer(1).attach = { mode = "frame", frame = "PlayerFrame", point = "LEFT",
        relativePoint = "RIGHT", x = 5, y = 6 }
    local rec = recordAnchor(inst)
    assertEqual(NS.Anchors.Place(inst), "frame")
    local p = rec.points[1]
    -- red under: Place handing SetPoint the template's attach point instead of the stored one
    assertTrue(p[2] == target)
    assertEqual(p[1], "LEFT"); assertEqual(p[3], "RIGHT"); assertEqual(p[4], 5); assertEqual(p[5], 6)
end)

test("anchors: a frame that refuses the anchor falls back to the screen, cleanly re-placed", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local target = plant(mocks, "RestrictedBar")
    NS.Database.FindContainer(1).attach = { mode = "frame", frame = "RestrictedBar" }
    local rec = recordAnchor(inst, function(rel) return rel == target end)
    local ok, mode = pcall(NS.Anchors.Place, inst)
    -- red under: SetPoint against the target unguarded (a restricted frame raises on every apply)
    assertTrue(ok, tostring(mode))
    assertEqual(mode, "screen")
    -- red under: the fallback without its ClearAllPoints (a half-set point would pull on the anchor)
    assertEqual(rec.clears, 2, "cleared before placing, and again after the refusal")
    assertTrue(rec.points[1][2] == mocks.UIParent)
    assertEqual(#NS.Anchors.Pending(), 0, "the frame exists: nothing to wait for")
end)

test("anchors: an empty frame name is a screen fallback that waits on nothing", function()
    local NS = fresh()
    local inst = NS.ContainerManager.instances[1]
    NS.Database.FindContainer(1).attach = { mode = "frame", frame = "" }
    assertEqual(NS.Anchors.Place(inst), "screen")
    -- red under: targetFor marking every unresolved frame pending, the unnamed one included
    assertEqual(#NS.Anchors.Pending(), 0)
end)

test("anchors: a waiting container set back to the screen stops waiting", function()
    local NS = fresh()
    local inst = NS.ContainerManager.instances[1]
    local c = NS.Database.FindContainer(1)
    c.attach.mode, c.attach.frame = "frame", "NotYetLoaded"
    NS.Anchors.Place(inst)
    assertEqual(table.concat(NS.Anchors.Pending(), ","), "1")
    c.attach.mode = "screen"
    NS.Anchors.Place(inst)
    -- red under: Place without its pending reset (a screen container re-placed on every add-on load)
    assertEqual(#NS.Anchors.Pending(), 0)
end)

test("anchors: a waiting container deleted before its frame appears is dropped from the wait", function()
    local NS, mocks = fresh()
    local CM = NS.ContainerManager
    local c = NS.Database.FindContainer(1)
    c.attach.mode, c.attach.frame = "frame", "NotYetLoaded"
    NS.Anchors.Place(CM.instances[1])
    assertTrue(CM.Delete(1))
    mocks.__fireTimers()
    assertNil(CM.instances[1], "the container is gone")
    local ok, err = pcall(NS.Anchors.ResolvePending)
    assertTrue(ok, tostring(err))
    -- red under: ResolvePending keeping an id whose container no longer exists
    assertEqual(#NS.Anchors.Pending(), 0)
end)

test("anchors: an add-on loading re-places only the containers still waiting", function()
    local NS, mocks = fresh()
    local CM = NS.ContainerManager
    local c = NS.Database.FindContainer(2)
    c.attach.mode, c.attach.frame = "frame", "LateBar"
    NS.Anchors.Place(CM.instances[2])
    local placed = {}
    local place = NS.Anchors.Place
    NS.Anchors.Place = function(inst)
        placed[#placed + 1] = inst.id
        return place(inst)
    end
    plant(mocks, "LateBar")
    NS.addon:OnAddonLoaded()
    NS.Anchors.Place = place
    -- red under: ResolvePending re-placing every container on every add-on load
    assertEqual(table.concat(placed, ","), "2")
    assertEqual(#NS.Anchors.Pending(), 0, "and it no longer waits")
end)

test("anchors: a loop among other containers is refused, and the walk still ends", function()
    local NS = fresh()
    local c2, c3 = NS.Database.FindContainer(2), NS.Database.FindContainer(3)
    c2.attach.mode, c2.attach.container = "container", 3
    c3.attach.mode, c3.attach.container = "container", 2
    -- red under: WouldCycle answering false at the hop limit (a looping chain anchors in a circle)
    assertTrue(NS.Anchors.WouldCycle(1, 2))
    local c1 = NS.Database.FindContainer(1)
    c1.attach.mode, c1.attach.container = "container", 2
    assertEqual(NS.Anchors.Place(NS.ContainerManager.instances[1]), "screen")
end)

test("anchors: a chain that ends at a screen container is no loop; one that returns to the start is", function()
    local NS = fresh()
    local c3 = NS.Database.FindContainer(3)
    c3.attach.mode, c3.attach.container = "container", 2
    -- red under: WouldCycle following a chain past a container that is not attached to another
    assertFalse(NS.Anchors.WouldCycle(1, 3), "3 → 2 → the screen")
    assertTrue(NS.Anchors.WouldCycle(2, 3), "2 → 3 → 2")
    assertFalse(NS.Anchors.WouldCycle(1, 99), "a container that does not exist")
end)

test("anchors: a real, unforbidden frame resolves, even one without IsForbidden; a name that is not a string never does", function()
    local NS, mocks = fresh()
    -- A plain table, not the kit stub: the stub answers every PascalCase method, IsForbidden included.
    local f = { GetObjectType = function() return "Frame" end }
    mocks.__globals.OldAddonFrame = f
    -- red under: ResolveFrame calling IsForbidden unguarded
    assertTrue(NS.Anchors.ResolveFrame("OldAddonFrame") == f)
    assertNil(NS.Anchors.ResolveFrame(42))
    assertNil(NS.Anchors.ResolveFrame(nil))
    assertNil(NS.Anchors.ResolveFrame("NoSuchFrame"))
end)

test("anchors: a drag with no relative point stores the point for both, and each offset to one decimal", function()
    local NS = fresh()
    local inst = NS.ContainerManager.instances[1]
    inst.anchor.GetPoint = function() return "TOP", nil, nil, -12.36, nil end
    NS.Anchors.SavePosition(inst)
    local pos = NS.Database.FindContainer(1).position
    -- red under: SavePosition storing a nil relative point (the anchor would pin to the template's)
    assertEqual(pos.relativePoint, "TOP")
    assertEqual(pos.x, -12.4, "rounded to the nearest tenth, downward for a negative")
    assertEqual(pos.y, 0, "a missing offset stores 0")
end)

test("anchors: an anchor that reads back no point writes nothing", function()
    local NS = fresh()
    local inst = NS.ContainerManager.instances[1]
    inst.anchor.GetPoint = function() return nil end
    local writes = 0
    NS.NewBusTarget():RegisterMessage(NS.MSG.CONFIG_CHANGED, function() writes = writes + 1 end)
    NS.Anchors.SavePosition(inst)
    -- red under: SavePosition without its no-point guard (a nil point would be stored)
    assertEqual(writes, 0)
    assertEqual(NS.Database.FindContainer(1).position.point, NS.STARTER_CONTAINERS[1].position.point)
end)

-- ── inherited flow (L-6) ──────────────────────────────────────────────────────────────────────

-- Every parent axis and growth, and the points that attach its child: the child stacks below (or
-- above, growing up) its parent whatever the parent fills (IA-1).
local DERIVED = {
    { axis = "vertical",   growH = "right", growV = "down", p = "TOPLEFT",     rp = "BOTTOMLEFT" },
    { axis = "vertical",   growH = "left",  growV = "down", p = "TOPRIGHT",    rp = "BOTTOMRIGHT" },
    { axis = "vertical",   growH = "right", growV = "up",   p = "BOTTOMLEFT",  rp = "TOPLEFT" },
    { axis = "vertical",   growH = "left",  growV = "up",   p = "BOTTOMRIGHT", rp = "TOPRIGHT" },
    { axis = "horizontal", growH = "right", growV = "down", p = "TOPLEFT",     rp = "BOTTOMLEFT" },
    { axis = "horizontal", growH = "right", growV = "up",   p = "BOTTOMLEFT",  rp = "TOPLEFT" },
    { axis = "horizontal", growH = "left",  growV = "down", p = "TOPRIGHT",    rp = "BOTTOMRIGHT" },
    { axis = "horizontal", growH = "left",  growV = "up",   p = "BOTTOMRIGHT", rp = "TOPRIGHT" },
}
for _, c in ipairs(DERIVED) do
    test(("anchors: derived points continue a %s/%s/%s parent"):format(c.axis, c.growH, c.growV), function()
        local NS = fresh()
        local p, rp = NS.Anchors.DerivedPoints({ axis = c.axis, growH = c.growH, growV = c.growV })
        -- red under: the old axis branch putting a row parent's child beside it
        assertEqual(p, c.p)
        assertEqual(rp, c.rp)
    end)
end

test("anchors: derived points do not depend on the parent's fill axis", function()
    local NS = fresh()
    for _, h in ipairs({ "right", "left" }) do
        for _, v in ipairs({ "down", "up" }) do
            local cp, crp = NS.Anchors.DerivedPoints({ axis = "vertical", growH = h, growV = v })
            local rowP, rowRp = NS.Anchors.DerivedPoints({ axis = "horizontal", growH = h, growV = v })
            local noP, noRp = NS.Anchors.DerivedPoints({ growH = h, growV = v })
            -- red under: the old axis branch (a row parent's child beside it, not below)
            assertEqual(rowP, cp, h .. "/" .. v .. " rows: the column point")
            assertEqual(rowRp, crp, h .. "/" .. v .. " rows: the column relative point")
            assertEqual(noP, cp, h .. "/" .. v .. " no axis")
            assertEqual(noRp, crp, h .. "/" .. v .. " no axis")
        end
    end
end)

test("anchors: a container attached to an icon row stacks below it, on the side its rows start from", function()
    local NS = fresh()
    local CM = NS.ContainerManager
    local L3 = NS.Database.FindContainer(3).layout
    L3.axis, L3.growH, L3.growV = "horizontal", "right", "down"
    local c2 = NS.Database.FindContainer(2)
    c2.attach = { mode = "container", container = 3, x = 0, y = -4 }
    local rec = recordAnchor(CM.instances[2])
    assertEqual(NS.Anchors.Place(CM.instances[2]), "container")
    local p = rec.points[1]
    -- red under: rows placing the child beside the parent (TOPLEFT to TOPRIGHT)
    assertEqual(p[1], "TOPLEFT"); assertTrue(p[2] == CM.instances[3].engine, "3's engine")
    -- The chain stacks vertically, so the seam is one of 2's line spacings, the stored -4 on top;
    -- across, the engine's one-unit lead is taken back (the engine lead).
    assertEqual(p[3], "BOTTOMLEFT"); assertEqual(p[4], 1); assertEqual(p[5], -4 - c2.layout.lineSpacing)
    L3.growH = "left"
    rec = recordAnchor(CM.instances[2])
    NS.Anchors.Place(CM.instances[2])
    p = rec.points[1]
    -- red under: a left-growing row putting its child to its left
    assertEqual(p[1], "TOPRIGHT"); assertEqual(p[3], "BOTTOMRIGHT")
end)

--- Container 1 set to fill columns growing left and up: a flow no starter container has, so an
--- inherited value can never be mistaken for a container's own.
local function oddParent(NS)
    local L = NS.Database.FindContainer(1).layout
    L.axis, L.growH, L.growV = "vertical", "left", "up"
    return L
end

local function attach(NS, id, to)
    local c = NS.Database.FindContainer(id)
    c.attach.mode, c.attach.container = "container", to
    return c
end

test("anchors: an attached container flows as its parent does, and its own flow stays stored", function()
    local NS = fresh()
    local c1, c2 = NS.Database.FindContainer(1), NS.Database.FindContainer(2)
    -- red under: EffectiveLayout copying the layout of a container that follows nothing
    assertTrue(NS.Anchors.EffectiveLayout(c1) == c1.layout, "a screen container reads its own table, uncopied")
    oddParent(NS)
    c2.layout.perLine, c2.layout.spacing = 4, 7
    attach(NS, 2, 1)
    local L = NS.Anchors.EffectiveLayout(c2)
    -- red under: EffectiveLayout answering the child's own layout in container mode
    assertEqual(L.axis, "vertical"); assertEqual(L.growH, "left"); assertEqual(L.growV, "up")
    -- red under: the copy taking the parent's per-line count and spacing (those stay the child's)
    assertEqual(L.perLine, 4); assertEqual(L.spacing, 7)
    -- red under: inheriting by writing the parent's values into the child's stored layout
    assertTrue(L ~= c2.layout, "a copy")
    assertEqual(c2.layout.axis, "horizontal"); assertEqual(c2.layout.growH, "left"); assertEqual(c2.layout.growV, "down")
    assertTrue(NS.Anchors.FlowRoot(c2) == c1)
    assertEqual(NS.Anchors.FlowRoot(c1), nil, "a screen container follows nothing")
end)

test("anchors: a chain inherits its root's flow; a broken or looping chain stops where it breaks", function()
    local NS = fresh()
    oddParent(NS)
    local c2 = attach(NS, 2, 1)
    local c3 = attach(NS, 3, 2)
    local L = NS.Anchors.EffectiveLayout(c3)
    -- red under: the walk stopping at the immediate parent (3 would take 2's rows growing left)
    assertEqual(L.axis, "vertical"); assertEqual(L.growH, "left"); assertEqual(L.growV, "up")
    assertTrue(NS.Anchors.FlowRoot(c3) == NS.Database.FindContainer(1), "the root names the flow's owner")
    c2.attach.container = 99
    L = NS.Anchors.EffectiveLayout(c3)
    -- red under: following a link whose target does not exist (2 sits on the screen with its own flow)
    assertEqual(L.axis, "horizontal"); assertEqual(L.growH, "left"); assertEqual(L.growV, "down")
    c2.attach.container = 3
    -- red under: FlowRoot without its WouldCycle guard (the capped walk inherits a flow from inside the loop)
    assertTrue(NS.Anchors.EffectiveLayout(c3) == c3.layout, "3 → 2 → 3 falls back to its own flow")
    c3.attach.container = 3
    assertTrue(NS.Anchors.EffectiveLayout(c3) == c3.layout, "attached to itself")
end)

test("anchors: a container attached to another takes derived points from the parent's flow", function()
    local NS = fresh()
    local CM = NS.ContainerManager
    oddParent(NS)
    local c2 = attach(NS, 2, 1)
    c2.attach.point, c2.attach.relativePoint, c2.attach.x, c2.attach.y = "CENTER", "CENTER", 6, -2
    local rec = recordAnchor(CM.instances[2])
    NS.Anchors.Place(CM.instances[2])
    local p = rec.points[1]
    -- red under: Place reading the stored attach points in container mode
    assertEqual(p[1], "BOTTOMRIGHT"); assertEqual(p[3], "TOPRIGHT")
    -- Growing up, the seam gap (2's spacing) is upward and the stored -2 nudges on top of it; growing
    -- left, the engine's one-unit lead is taken back leftward (the engine lead).
    assertEqual(p[4], 6 - 1); assertEqual(p[5], -2 + c2.layout.spacing)
end)

test("anchors: a frame-attached container keeps its stored points", function()
    local NS, mocks = fresh()
    oddParent(NS)
    plant(mocks, "PlayerFrame")
    local inst = NS.ContainerManager.instances[2]
    NS.Database.FindContainer(2).attach = { mode = "frame", frame = "PlayerFrame", container = 1,
        point = "CENTER", relativePoint = "LEFT", x = 1, y = 2 }
    local rec = recordAnchor(inst)
    NS.Anchors.Place(inst)
    -- red under: deriving points in every attached mode (a frame target has no flow to continue)
    assertEqual(rec.points[1][1], "CENTER"); assertEqual(rec.points[1][3], "LEFT")
end)

test("anchors: the engine's flow, the placeholders and the handle all read the inherited flow", function()
    local NS, mocks = fresh()
    oddParent(NS)
    local c2 = attach(NS, 2, 1)
    local flow = NS.Container.FlowSettings(c2)
    -- red under: FlowSettings reading cfg.layout
    assertEqual(flow.axis, "vertical"); assertEqual(flow.growH, "left"); assertEqual(flow.growV, "up")
    assertEqual(flow.anchorPoint, "BOTTOMRIGHT")
    -- red under: Preview.Offset reading cfg.layout (placeholders laid out in the child's own rows)
    local point, x, y = NS.Preview.Offset(c2, 2)
    local _, h = NS.Style.ElementSize(c2)
    assertEqual(point, "BOTTOMRIGHT")
    assertEqual(x, 0)
    assertEqual(y, h + c2.layout.spacing, "the second placeholder stacks up the column")
    local inst = NS.ContainerManager.instances[2]
    local hdl = recordedHandle(mocks, NS, inst)
    local left, right, bottom
    rawset(inst.anchor, "SetClampRectInsets", function(_, l, r, _, b) left, right, bottom = l, r, b end)
    NS.Anchors.UpdateHandle(inst, true)
    local p = last(hdl, "SetPoint")
    -- red under: placeHandle reading cfg.layout (2's own rows grow left and down: the strip would be
    -- above it). Before its own block in its own column (batch 10 F1): below it, growing up, lined
    -- up with the right edge its lines start from.
    assertEqual(p[1], "TOPRIGHT"); assertEqual(p[3], "BOTTOMRIGHT")
    -- red under: clampToHandle reading cfg.layout (2's own growth runs right and reaches up)
    assertEqual(right, 0, "never right: its lines run left"); assertTrue(left <= 0)
    assertTrue(bottom < 0, "it reaches down over the strip")
end)

--- The anchor point the engine was last told for container `id`.
local function engineAnchorPoint(NS, id)
    local calls = NS.ContainerManager.instances[id].engine.__calls
    local n = #calls
    for i = n, 1, -1 do
        if calls[i][1] == "SetFlowLayoutAnchorPoint" then return calls[i][2] end
    end
    return nil
end

test("anchors: detaching a container restores its own stored flow at the next apply", function()
    local NS, mocks = fresh()
    oddParent(NS)
    NS.SetByPath("container.attach.container", 1, 2)
    NS.SetByPath("container.attach.mode", "container", 2)
    mocks.__fireTimers()
    -- red under: the apply path reading 2's stored flow while it follows 1
    assertEqual(engineAnchorPoint(NS, 2), "BOTTOMRIGHT", "attached: 1's columns growing left and up")
    NS.SetByPath("container.attach.mode", "screen", 2)
    mocks.__fireTimers()
    -- red under: inheriting by overwriting the stored flow (it could never come back)
    assertEqual(engineAnchorPoint(NS, 2), "TOPRIGHT", "detached: 2's own rows growing left and down")
end)

test("anchors: a write that moves a container's flow re-applies every container following it", function()
    local NS, mocks = fresh()
    attach(NS, 2, 1)
    attach(NS, 3, 2)
    mocks.__fireTimers()
    local CM = NS.ContainerManager
    local asked = {}
    local real = CM.RequestApply
    CM.RequestApply = function(id, ...)
        asked[#asked + 1] = tostring(id)
        return real(id, ...)
    end
    local function run(path, value, id)
        asked = {}
        NS.SetByPath(path, value, id)
        table.sort(asked)
        return table.concat(asked, ",")
    end
    -- red under: the CONFIG_CHANGED handler re-applying only the written container
    assertEqual(run("container.layout.growH", "left", 1), "1,2,3", "a parent's growth moves the whole chain")
    assertEqual(run("container.layout", NS.Database.FindContainer(3).layout, 1), "1,2,3", "a whole-layout write too")
    -- Before the detach below, while 2 and 3 still follow 1.
    -- red under: MovesFollowers answering true for every path
    assertEqual(run("container.layout.spacing", 5, 1), "1", "spacing moves no follower")
    -- red under: FLOW_PATHS without the attach paths (a detach would leave 3 on 1's flow)
    -- 1 too since batch 9 AP-4: a parent's strip side depends on which sides its followers take.
    assertEqual(run("container.attach.mode", "screen", 2), "1,2,3", "3 now follows 2's own flow, and 1 lost 2")
    CM.RequestApply = real
    mocks.__fireTimers()
    assertEqual(engineAnchorPoint(NS, 3), "TOPRIGHT", "3 follows 2's rows growing left and down")
end)

test("anchors: a parent's growth flip rebuilds its follower's engine, pinned at the derived corner, and re-anchors it to the parent's new engine", function()
    local NS, mocks = fresh()
    local CM = NS.ContainerManager
    NS.SetByPath("container.attach.container", 1, 2)
    NS.SetByPath("container.attach.mode", "container", 2)
    mocks.__fireTimers()
    local parentOld, childOld = CM.instances[1].engine, CM.instances[2].engine
    local rec = recordAnchor(CM.instances[2])
    NS.SetByPath("container.layout.growV", "up", 1)
    mocks.__fireTimers()
    local child = CM.instances[2].engine
    -- red under: the structure key without the (inherited) growth corner: 2 keeps its engine, pinned
    -- TOPLEFT while its auras now grow up
    assertTrue(child ~= childOld, "the follower got a new engine")
    assertFalse(childOld.__enabled, "and retired the old one")
    local at = child:__firstCall("SetPoint")
    -- 1 fills columns growing right and up, so 2 does too: its auras start at the bottom left.
    assertEqual(child.__calls[at][2], "BOTTOMLEFT")
    assertTrue(at < child:__firstCall("AddAuraGroup"), "pinned before the first group")
    local parent = CM.instances[1].engine
    assertTrue(parent ~= parentOld, "the parent was rebuilt too")
    local p = rec.points[#rec.points]
    -- red under: the follower left hanging from the parent's retired engine
    assertTrue(p[2] == parent, "attached to the parent's new engine")
    assertEqual(p[1], "BOTTOMLEFT"); assertEqual(p[3], "TOPLEFT")
end)

-- ── an attached container while its parent previews (L-4) ────────────────────────────────────
-- The cause, confirmed with a recorder: while container 1 previews, its engine is disabled and holds
-- only its provisional 1x1 rect (Container:Build's SetSize(1, 1); no layout pass replaces it), and 2
-- hung TOPLEFT → BOTTOMLEFT from that engine: on 1's first placeholder, 2's handle among them.

--- Container 2 attached to container 1, unlocked (the handles show), in test mode and flushed: 1
--- previews, its engine off.
local function previewPair()
    local NS, mocks = fresh()
    NS.SetByPath("container.attach.container", 1, 2)
    NS.SetByPath("container.attach.mode", "container", 2)
    NS.SetByPath("locked", false)
    NS.Preview.SetTestMode(true)
    mocks.__fireTimers()
    return NS, mocks, NS.ContainerManager
end

--- The frame a recorded anchor was last pointed at.
local function lastTarget(rec)
    local n = #rec.points
    return rec.points[n] and rec.points[n][2]
end

test("anchors: while its parent previews, an attached container hangs from the parent's preview extent, not its engine (L-4)", function()
    local NS, _, CM = previewPair()
    local one, two = CM.instances[1], CM.instances[2]
    assertFalse(one.engine.__enabled, "the parent's engine is off while it previews")
    local at = NS.Database.FindContainer(2).attach
    at.point, at.relativePoint = "CENTER", "CENTER"   -- stored points no derived pair has
    local rec = recordAnchor(two)
    NS.Anchors.Place(two)
    -- red under: targetFor answering the target's engine while the target previews
    assertTrue(one.previewExtent ~= nil and lastTarget(rec) == one.previewExtent, "the parent's preview extent")
    -- red under: the extent path skipping the derived points (1 fills columns right and down)
    assertEqual(rec.points[1][1], "TOPLEFT"); assertEqual(rec.points[1][3], "BOTTOMLEFT")
    NS.SetByPath("container.attach.container", 2, 3)
    NS.SetByPath("container.attach.mode", "container", 3)
    local rec3 = recordAnchor(CM.instances[3])
    NS.Anchors.Place(CM.instances[3])
    -- red under: an extent built only for a container nothing else is attached to
    assertTrue(two.previewExtent ~= nil and lastTarget(rec3) == two.previewExtent, "a chain: 3 hangs from 2's extent")
end)

test("anchors: ending test mode re-anchors an attached container off the extent, and starting it back to the extent (L-4)", function()
    local NS, mocks, CM = previewPair()
    local one, two = CM.instances[1], CM.instances[2]
    local rec = recordAnchor(two)
    NS.Preview.SetTestMode(false)
    mocks.__fireTimers()
    -- red under: ApplyVisibility leaving the followers where the preview put them
    -- previewPair is unlocked, so 1's followers hang from its one-element anchor (EO-1)
    assertTrue(lastTarget(rec) == one.anchor, "test mode off, unlocked: the anchor its outline marks")
    NS.Preview.SetTestMode(true)
    mocks.__fireTimers()
    assertTrue(lastTarget(rec) == one.previewExtent, "test mode on: the extent again")
    local placed = #rec.points
    CM.ApplyVisibility()
    -- red under: re-placing the followers on every visibility pass (a pass that changes nothing moves nothing)
    assertEqual(#rec.points, placed)
end)

test("anchors: under lockdown ending test mode leaves an attached container where it is; the pass after combat moves it (L-4)", function()
    local NS, mocks, CM = previewPair()
    local rec = recordAnchor(CM.instances[2])
    mocks.__lockdown = true
    NS.Preview.SetTestMode(false)
    mocks.__fireTimers()
    -- red under: re-placing a follower under lockdown (its anchor parents an aura engine:
    -- events-frames-taint-§2)
    assertEqual(#rec.points, 0, "the last placement stands")
    mocks.__lockdown = false
    NS.addon:OnCombatChanged("PLAYER_REGEN_ENABLED")
    -- red under: recording the followers as placed when lockdown skipped them
    assertTrue(lastTarget(rec) == CM.instances[1].anchor, "combat over, unlocked: onto the anchor (EO-1)")
end)

test("handle: an attached container's strip sits above every placeholder of the container it is attached to (L-4)", function()
    local NS, mocks, CM = previewPair()
    NS.SetByPath("container.layout.level", 100, 1)
    NS.SetByPath("container.layout.level", 1, 2)
    mocks.__fireTimers()
    local one, two = CM.instances[1], CM.instances[2]
    -- red under: the strip's level set only in BuildHandle, before the first apply set its anchor's
    assertEqual(one.handle:GetFrameLevel(), one.anchor:GetFrameLevel() + 50, "a screen container: fifty above its anchor")
    -- Every placeholder of 1, inner frames included, stacks under 1's own strip (fifty above its
    -- anchor), so 2's strip clears them by sitting above that.
    -- red under: an attached strip at its own anchor + 50 (51, under 1's placeholders at 101 and up)
    assertTrue(two.handle:GetFrameLevel() > one.anchor:GetFrameLevel() + 50, "above 1's placeholders")
    NS.SetByPath("container.attach.mode", "screen", 2)
    mocks.__fireTimers()
    -- red under: the raise kept after a detach
    assertEqual(two.handle:GetFrameLevel(), two.anchor:GetFrameLevel() + 50, "detached: its own anchor's again")
end)
