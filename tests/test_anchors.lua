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

-- ── the drag handle ───────────────────────────────────────────────────────────────────────────

-- Every setter the handle's look and placement go through, recorded in call order per frame.
local RECORDED = {
    "SetPoint", "SetAllPoints", "ClearAllPoints", "SetWidth", "SetHeight", "SetSize",
    "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetTextColor", "SetTexture",
    "RegisterForDrag",
}

--- Rebuild container `inst`'s handle under a CreateFrame that records every frame it makes.
--- Font strings and textures come back as their frame from the kit stub, so a label's or an icon's
--- setters land on the frame that made it.
local function recordedHandle(mocks, NS, inst)
    local real = mocks.CreateFrame
    mocks.CreateFrame = function(...)
        local f = real(...)
        f.__rec = {}
        for _, m in ipairs(RECORDED) do
            rawset(f, m, function(self, ...)
                local log = self.__rec[m] or {}
                self.__rec[m] = log
                log[#log + 1] = { ... }
                return self
            end)
        end
        return f
    end
    local handle = NS.Anchors.BuildHandle(inst)
    mocks.CreateFrame = real
    inst.handle = handle
    return handle
end

local function last(f, method)
    local log = f.__rec[method] or {}
    return log[#log], #log
end

test("handle: a dark WHITE8X8 strip with a 1px gold edge, a gold label and the catalog help mark", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local h = recordedHandle(mocks, NS, inst)
    assertEqual(h.__template, "BackdropTemplate")
    assertEqual(last(h, "SetHeight")[1], 18)
    local bd = last(h, "SetBackdrop")[1]
    assertEqual(bd.bgFile, [[Interface\Buttons\WHITE8X8]])
    assertEqual(bd.edgeFile, [[Interface\Buttons\WHITE8X8]])
    assertEqual(bd.edgeSize, 1)
    assertEqual(table.concat(last(h, "SetBackdropColor"), ","), "0,0,0,0.75")
    assertEqual(table.concat(last(h, "SetBackdropBorderColor"), ","), "1,0.82,0,0.6")
    assertEqual(table.concat(last(h, "SetTextColor"), ","), "1,0.82,0")
    local help = h.help
    assertEqual(table.concat(last(help, "SetSize"), ","), "14,14")
    local p = last(help, "SetPoint")
    assertEqual(p[1], "RIGHT"); assertTrue(p[2] == h); assertEqual(p[3], "RIGHT")
    assertEqual(p[4], -4); assertEqual(p[5], 0)
    assertTrue(NS.Icon("help") ~= nil, "the vendored catalog carries the help mark")
    assertEqual(last(help, "SetTexture")[1], NS.Icon("help"))
    local _, covers = last(h, "SetAllPoints")
    -- red under: restoring SetAllPoints(anchor) in BuildHandle
    assertEqual(covers, 0, "the handle never covers the anchor")
end)

test("handle: above the anchor when auras grow down, below when up, edge-aligned where they start", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local cfg = NS.Database.FindContainer(1)
    local h = recordedHandle(mocks, NS, inst)
    local cases = {
        { "down", "right", "BOTTOMLEFT", "TOPLEFT", 2 },
        { "down", "left", "BOTTOMRIGHT", "TOPRIGHT", 2 },
        { "up", "right", "TOPLEFT", "BOTTOMLEFT", -2 },
        { "up", "left", "TOPRIGHT", "BOTTOMRIGHT", -2 },
    }
    local anchorMoves = 0
    rawset(inst.anchor, "SetPoint", function() anchorMoves = anchorMoves + 1 end)
    rawset(inst.anchor, "ClearAllPoints", function() anchorMoves = anchorMoves + 1 end)
    local engineMoves = inst.engine.__counts.SetPoint or 0
    for _, c in ipairs(cases) do
        cfg.layout.growV, cfg.layout.growH = c[1], c[2]
        NS.Anchors.UpdateHandle(inst, true)
        local p = last(h, "SetPoint")
        local what = c[1] .. "/" .. c[2]
        assertEqual(p[1], c[3], what)
        assertTrue(p[2] == inst.anchor, what)
        assertEqual(p[3], c[4], what)
        assertEqual(p[4], 0, what)
        assertEqual(p[5], c[5], what)
    end
    assertTrue(h:IsShown())
    -- red under: re-placing the anchor from UpdateHandle to make room for the handle
    assertEqual(anchorMoves, 0, "the anchor, and so every element, stays where it is")
    -- red under: re-anchoring the engine from UpdateHandle
    assertEqual(inst.engine.__counts.SetPoint or 0, engineMoves, "the engine is never re-anchored")
end)

test("handle: at least as wide as its container's element, and as its label with room for the help mark", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local cfg = NS.Database.FindContainer(1)
    local h = recordedHandle(mocks, NS, inst)
    local w = NS.Style.ElementSize(cfg)
    NS.Anchors.UpdateHandle(inst, true)
    assertEqual(last(h, "SetWidth")[1], math.max(24 + 14 * 2, w), "an empty label")
    rawset(h, "GetStringWidth", function() return w + 100 end)   -- the label is the handle's font string
    NS.Anchors.UpdateHandle(inst, true)
    assertEqual(last(h, "SetWidth")[1], w + 100 + 24 + 14 * 2, "a label wider than the element")
end)

test("handle: while shown the anchor's clamp rect takes it in; hidden, or in combat, the rect is left alone", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local cfg = NS.Database.FindContainer(1)
    local h = recordedHandle(mocks, NS, inst)
    local insets
    rawset(inst.anchor, "SetClampRectInsets", function(_, l, r, t, b) insets = table.concat({ l, r, t, b }, ",") end)
    local w = NS.Style.ElementSize(cfg)
    rawset(h, "GetStringWidth", function() return w + 100 end)
    local over = 100 + 24 + 14 * 2
    cfg.layout.growV, cfg.layout.growH = "down", "right"
    NS.Anchors.UpdateHandle(inst, true)
    assertEqual(insets, "0," .. over .. ",20,0", "down/right: above, reaching right")
    cfg.layout.growV, cfg.layout.growH = "up", "left"
    NS.Anchors.UpdateHandle(inst, true)
    assertEqual(insets, -over .. ",0,0,-20", "up/left: below, reaching left")
    NS.Anchors.UpdateHandle(inst, false)
    -- red under: leaving the insets extended when the handle hides
    assertEqual(insets, "0,0,0,0")
    assertFalse(h:IsShown())
    insets = nil
    mocks.__lockdown = true
    NS.Anchors.UpdateHandle(inst, true)
    mocks.__lockdown = false
    -- red under: dropping the InCombatLockdown gate before SetClampRectInsets
    assertNil(insets, "the anchor parents an aura engine: no layout work on it in combat")
end)

test("handle: the help mark carries the tooltip and right-click opens the settings on this container", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[2]
    local h = recordedHandle(mocks, NS, inst)
    local lines = {}
    local function add(_, s)
        lines[#lines + 1] = s
    end
    rawset(mocks.GameTooltip, "SetText", add)
    rawset(mocks.GameTooltip, "AddLine", add)
    h.help:__fire("OnEnter")
    assertEqual(lines[1], NS.Database.FindContainer(2).name)
    assertEqual(lines[2], NS.L["Drag to move. Right-click for settings."])
    local opened = 0
    NS.OpenOptionsPanel = function() opened = opened + 1 end
    NS.State.SetActiveContainer(1)
    h.help:__fire("OnClick", "RightButton")
    assertEqual(opened, 1)
    assertEqual(NS.State.activeContainerId, 2)
end)

test("handle: a left-drag that starts on the help mark moves the container as one on the strip does", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    assertEqual(NS.Database.FindContainer(1).attach.mode, "screen")
    local h = recordedHandle(mocks, NS, inst)
    assertEqual(table.concat(last(h.help, "RegisterForDrag") or {}, ","), "LeftButton",
        "the help mark takes a left-drag")
    local moved, stopped = 0, 0
    rawset(inst.anchor, "StartMoving", function() moved = moved + 1 end)
    rawset(inst.anchor, "StopMovingOrSizing", function() stopped = stopped + 1 end)
    inst.anchor.GetPoint = function() return "TOP", nil, "TOP", 7, -40 end
    h.help:__fire("OnDragStart")
    h.help:__fire("OnDragStop")
    assertEqual(moved, 1, "the drag moves the anchor")
    assertEqual(stopped, 1)
    local pos = NS.Database.FindContainer(1).position
    assertEqual(pos.x, 7, "and the position is stored")
    assertEqual(pos.y, -40)
    assertTrue(h.help:GetScript("OnDragStart") == h:GetScript("OnDragStart"), "one drag function, not a copy")
end)

test("handle: without the media library the help mark falls back to Blizzard's information icon", function()
    local NS2, mocks2 = dofile("tests/degraded_env.lua")()
    assertNil(NS2.Icon("help"))
    local inst = { id = 1, anchor = mocks2.CreateFrame("Frame"), Cfg = function() return nil end }
    local h = recordedHandle(mocks2, NS2, inst)
    assertEqual(last(h.help, "SetTexture")[1], [[Interface\FriendsFrame\InformationIcon]])
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
