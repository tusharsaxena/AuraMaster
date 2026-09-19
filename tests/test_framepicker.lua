-- tests/test_framepicker.lua — modules/FramePicker.lua: pointing at a frame on screen to attach a
-- container to it. The named-ancestor walk, the outline and label that track the cursor, and every
-- way a pick ends.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local BS = dofile("tests/border_strips.lua")

--- A frame another addon would have created, planted under a global name.
local function plant(mocks, name, parent)
    local f = mocks.__stubFrame()
    f.GetName = function() return name end
    f.IsForbidden = function() return false end
    f.GetParent = function() return parent end
    if name then mocks.__globals[name] = f end
    return f
end

--- Start a pick in a fresh environment, and hand back the overlay and the outline it built. The
--- label is a font string of the overlay's, which the kit hands back as the overlay itself, so its
--- text and point are recorded on the overlay.
local function picking(opts)
    opts = opts or {}
    local NS, mocks = fresh()
    local made = {}
    local real = mocks.CreateFrame
    mocks.CreateFrame = function(...)
        local f = real(...)
        made[#made + 1] = f
        if opts.textures then BS.recorderTextures(f) end
        return f
    end
    local state = { picked = nil, canceled = 0 }
    NS.FramePicker.Start(function(name) state.picked = name end, function() state.canceled = state.canceled + 1 end)
    mocks.CreateFrame = real
    local overlay = mocks.__globals.AuraMasterFramePicker
    for _, f in ipairs(made) do
        if f.__parent == overlay then state.outline = f end
    end
    local log = { text = {}, points = {}, propagate = {}, covers = {} }
    --- Append one entry to one of the logs above.
    local function push(list, v)
        local n = #list
        list[n + 1] = v
    end
    rawset(overlay, "SetText", function(_, s) push(log.text, s) end)
    rawset(overlay, "SetPoint", function(_, ...) push(log.points, { ... }) end)
    rawset(overlay, "SetPropagateKeyboardInput", function(_, v) push(log.propagate, v) end)
    rawset(state.outline, "SetAllPoints", function(_, target)
        if opts.refuse then error("Anchoring disallowed") end
        log.covers[#log.covers + 1] = target
    end)
    state.overlay, state.log = overlay, log
    if opts.armed ~= false then overlay:__fire("OnUpdate") end   -- both buttons up: armed
    return NS, mocks, state
end

-- ── the walk ──────────────────────────────────────────────────────────────────────────────────

test("picker: the screen and the world are never a target, and the walk ends there", function()
    local NS, mocks = fresh()
    local screen = plant(mocks, "UIParent")
    local world = plant(mocks, "WorldFrame")
    -- red under: an empty REJECT list (a container attached to UIParent is just a screen container)
    assertNil(NS.FramePicker.NamedAncestor(plant(mocks, nil, screen)), "a child of the screen")
    assertNil(NS.FramePicker.NamedAncestor(world), "the world frame")
    assertNil(NS.FramePicker.NamedAncestor(nil), "nothing under the cursor")
end)

test("picker: the walk climbs past one of this addon's own frames to a named frame above it", function()
    local NS, mocks = fresh()
    local bar = plant(mocks, "SomeAddonBar")
    local ours = plant(mocks, "AuraMasterAnchor3", bar)
    local f, name = NS.FramePicker.NamedAncestor(ours)
    -- red under: the walk ending at the first own frame instead of skipping it
    assertTrue(f == bar)
    assertEqual(name, "SomeAddonBar")
end)

test("picker: the walk gives up after thirty-two unnamed frames", function()
    local NS, mocks = fresh()
    local top = plant(mocks, "FarAway")
    local f = top
    for _ = 1, 40 do f = plant(mocks, nil, f) end
    -- red under: the walk without its hop limit (a looping parent chain would never end)
    assertNil(NS.FramePicker.NamedAncestor(f))
    local near = top
    for _ = 1, 5 do near = plant(mocks, nil, near) end
    assertTrue(NS.FramePicker.NamedAncestor(near) == top, "a short chain still reaches it")
end)

-- ── tracking ──────────────────────────────────────────────────────────────────────────────────

test("picker: hovering a named frame outlines it and names it beside the cursor", function()
    local NS, mocks, s = picking()
    local target = plant(mocks, "TargetFrame")
    mocks.__foci = { plant(mocks, nil, target) }
    s.overlay:__fire("OnUpdate")
    -- red under: onUpdate outlining the unnamed frame under the cursor instead of its named ancestor
    assertTrue(s.log.covers[1] == target, "the outline covers the named frame")
    assertTrue(s.outline:IsShown())
    local text = s.log.text[#s.log.text]
    assertEqual(text:sub(1, #"TargetFrame\n"), "TargetFrame\n", text)
    assertTrue(text:find(NS.L["Left-click to attach, right-click to cancel"], 1, true) ~= nil, text)
    local p = s.log.points[#s.log.points]
    -- red under: the label placed without dividing the cursor by the UI scale, or without its offset
    assertEqual(p[1], "BOTTOMLEFT"); assertTrue(p[2] == mocks.UIParent); assertEqual(p[3], "BOTTOMLEFT")
    assertEqual(p[4], 100 + 16); assertEqual(p[5], 100 + 16)
    assertEqual(s.picked, nil, "hovering picks nothing")
end)

test("picker: the label follows the cursor at the UI's scale", function()
    local _, mocks, s = picking()
    mocks.UIParent.GetEffectiveScale = function() return 2 end
    s.overlay:__fire("OnUpdate")
    local p = s.log.points[#s.log.points]
    -- red under: the label placed at raw cursor coordinates
    assertEqual(p[4], 100 / 2 + 16); assertEqual(p[5], 100 / 2 + 16)
end)

test("picker: over nothing named the outline hides and the label says what to do", function()
    local NS, mocks, s = picking()
    mocks.__foci = { plant(mocks, "TargetFrame") }
    s.overlay:__fire("OnUpdate")
    mocks.__foci = {}
    s.overlay:__fire("OnUpdate")
    -- red under: the outline left on the last frame when the cursor moves off it
    assertFalse(s.outline:IsShown())
    assertEqual(s.log.text[#s.log.text], "|cffaaaaaa" .. NS.L["Point at a named frame. Right-click to cancel."] .. "|r")
end)

test("picker: a frame the outline may not anchor to hides the outline instead of raising", function()
    local _, mocks, s = picking({ refuse = true })
    mocks.__foci = { plant(mocks, "RestrictedFrame") }
    local ok, err = pcall(s.overlay.__fire, s.overlay, "OnUpdate")
    -- red under: SetAllPoints called unguarded (an error every frame, for as long as the cursor stays)
    assertTrue(ok, tostring(err))
    assertFalse(s.outline:IsShown())
end)

test("picker: the outline over a frame of secret size draws strips and never raises", function()
    local _, mocks, s = picking({ textures = true })
    local o = s.outline
    -- red under: a BackdropTemplate outline (2px WHITE8X8 edge, SetBackdropBorderColor 0.2,0.8,1,1)
    assertNil(o.backdropInfo, "no backdrop")
    assertTrue(o.__template:find("BackdropTemplate,", 1, true) == nil, o.__template)
    assertFalse(o:IsShown(), "built hidden")
    -- Covering a frame whose size reads secret (an aura container, a laid-out button) makes the
    -- outline's own size secret; the client then runs its OnSizeChanged.
    local target = plant(mocks, "SomeAddonAuraFrame")
    mocks.__layOut(target)
    mocks.__layOut(o)
    mocks.__foci = { target }
    local ok, err = pcall(s.overlay.__fire, s.overlay, "OnUpdate")
    assertTrue(ok, tostring(err))
    assertTrue(o:IsShown(), "it outlines the frame")
    BS.assertSolid(o, 2, "0.2,0.8,1,1", "the picker outline")
    -- red under: BackdropTemplate's size script (Backdrop.lua:226 on the secret size)
    assertNil(o:GetScript("OnSizeChanged"), "no size script on the outline")
    local fired, ferr = pcall(o.__fire, o, "OnSizeChanged")
    assertTrue(fired, tostring(ferr))
end)

test("picker: the outline carries the template that lets it outline an aura container", function()
    local _, _, s = picking()
    -- red under: a plain BackdropTemplate outline (anchoring to another addon's aura container raises)
    assertTrue(s.outline.__template:find("DisableUntrustedLayoutScriptsTemplate", 1, true) ~= nil, s.outline.__template)
end)

-- ── how a pick ends ───────────────────────────────────────────────────────────────────────────

test("picker: a right-click cancels, and nothing is picked", function()
    local NS, mocks, s = picking()
    mocks.__foci = { plant(mocks, "TargetFrame") }
    mocks.__mouseDown.RightButton = true
    s.overlay:__fire("OnUpdate")
    -- red under: onUpdate never reading the right button
    assertEqual(s.canceled, 1)
    assertNil(s.picked)
    assertFalse(NS.FramePicker.IsActive())
end)

test("picker: a left-click over nothing named keeps the pick going", function()
    local NS, mocks, s = picking()
    mocks.__foci = {}
    mocks.__mouseDown.LeftButton = true
    s.overlay:__fire("OnUpdate")
    -- red under: onUpdate picking on any left-click, named frame or not
    assertNil(s.picked)
    assertEqual(s.canceled, 0)
    assertTrue(NS.FramePicker.IsActive())
end)

test("picker: Escape keeps its key from the game for that press only, and cancels", function()
    local NS, mocks, s = picking()
    s.overlay:__fire("OnKeyDown", "ESCAPE")
    assertEqual(s.canceled, 1)
    assertFalse(NS.FramePicker.IsActive())
    -- red under: Escape propagating (it would also open the game menu)
    assertEqual(s.log.propagate[1], false)
    mocks.__fireTimers()
    -- red under: propagation left off after the pick (every key afterwards is swallowed)
    assertEqual(s.log.propagate[#s.log.propagate], true)
end)

test("picker: any other key passes through and the pick continues", function()
    local NS, _, s = picking()
    s.overlay:__fire("OnKeyDown", "W")
    -- red under: OnKeyDown canceling on any key
    assertEqual(s.canceled, 0)
    assertTrue(NS.FramePicker.IsActive())
    assertEqual(#s.log.propagate, 0, "the key reached the game")
end)

test("picker: a new pick waits for the buttons to be released again before it can pick", function()
    local NS, mocks, s = picking()
    mocks.__foci = { plant(mocks, "TargetFrame") }
    mocks.__mouseDown.LeftButton = true
    s.overlay:__fire("OnUpdate")
    assertEqual(s.picked, "TargetFrame")
    local second
    NS.FramePicker.Start(function(name) second = name end, function() end)
    s.overlay:__fire("OnUpdate")   -- the same left button is still held
    -- red under: Start without resetting `armed` (the click that started it picks the frame behind it)
    assertNil(second)
    assertTrue(NS.FramePicker.IsActive())
end)
