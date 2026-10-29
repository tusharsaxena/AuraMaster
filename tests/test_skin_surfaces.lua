-- tests/test_skin_surfaces.lua — the unlock furniture follows the skin (AM-02; skinning-§1, §7).
--
-- AuraMaster has no window of its own; what it draws outside the HUD is the unlock furniture: the
-- drag strip's own edge (the host painter's, which the widget never repaints), its label's markup
-- (an attached container's gray name, the TEST tag), the strip and close-mark tooltip lines, the
-- unlocked outline, the drag-to-attach mark, the frame picker and the TEST marker. Each reads its
-- color from the skin when it paints, and each is repainted by an OnLooksChanged listener when the
-- skin changes. Ka0s Default's pixels are pinned by the suites that own each surface
-- (tests/test_anchors_*.lua, tests/test_container.lua, tests/test_framepicker.lua,
-- tests/test_preview.lua); this suite switches to another skin and proves each one moved to it.

local T = _G.AM_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local fresh = dofile("tests/fresh_env.lua")
local BS = dofile("tests/border_strips.lua")
local HR = dofile("tests/handle_recorder.lua")

local function joined(r, g, b, a) return table.concat({ r, g, b, a }, ",") end

--- A fresh environment with two shown screen containers, each strip rebuilt under the recorder,
--- and `switch()`: a skin switch after which each token in `tokens` answers a color no skin draws.
---
--- WHY A SENTINEL. Several furniture tokens (sem.warn, chart.crosshair, ...) hold the same value in
--- every registered skin, so a real switch alone could not tell a surface that follows from one that
--- never did. `switch` lays a distinct color over each named token in this owner's facade (every
--- surface reads NS.Skin.Color or NS.SkinEscape, which reads it, at paint time) and then switches to
--- another registered skin, which fires the OnLooksChanged listeners. Ka0s Default's real pixels are
--- the owning suites' to pin.
local function env(tokens)
    local NS, mocks = fresh()
    while #NS.Database.GetContainers() < 2 do NS.ContainerManager.Create({}) end
    mocks.__fireTimers()
    for _, c in ipairs(NS.Database.GetContainers()) do
        c.enabled, c.attach.mode = true, "screen"
        local inst = NS.ContainerManager.instances[c.id]
        inst.anchor:Show()
        HR.recordedHandle(mocks, NS, inst):Show()
    end
    local other
    for _, def in ipairs(mocks.LibStub("LibKa0s-Skin-1.0"):Skins()) do
        if def.key ~= "ka0s" then other = other or def.key end
    end
    local function switch()
        local color, sentinel = NS.Skin.Color, {}
        for i, name in ipairs(tokens) do sentinel[name] = { 0.04 * i, 0.5, 0.25, 0.75 } end
        rawset(NS.Skin, "Color", function(name)
            local c = sentinel[name]
            if c then return c[1], c[2], c[3], c[4] end
            return color(name)
        end)
        NS.ApplySkinChoice("ka0s", other)
    end
    return NS, mocks, switch
end

--- How `strip`'s own four edge strips were last painted, "size r,g,b,a" (tests/drag_helpers.lua).
local function stripEdge(strip)
    local s = BS.strips(strip)
    if #s ~= 4 then return #s .. " strips" end
    local seen = {}
    for i, setter in ipairs({ "SetHeight", "SetHeight", "SetWidth", "SetWidth" }) do
        local last = s[i]:__last(setter)
        seen[i] = (last and last[1] or "?") .. " " .. (s[i]:__joined("SetColorTexture") or "?")
    end
    for i = 2, 4 do
        if seen[i] ~= seen[1] then return table.concat(seen, " | ") end
    end
    return seen[1]
end

test("skin surfaces: a skin switch repaints each strip's own edge in the new skin's handle.edge", function()
    local NS, _, switch = env({ "handle.edge" })
    local strip = NS.ContainerManager.instances[1].handle
    assertEqual(stripEdge(strip), "1 " .. joined(NS.Skin.Color("handle.edge")), "built: Ka0s Default's gold")
    switch()
    -- red under: no Anchors.Reskin listener (the widget repaints its fill and label, never a host edge)
    assertEqual(stripEdge(strip), "1 " .. joined(NS.Skin.Color("handle.edge")), "switched: the new skin's edge")
end)

test("skin surfaces: the strip label's attached gray and TEST tag are the new skin's", function()
    local NS, mocks, switch = env({ "am.attachedName", "sem.warn" })
    local inst = NS.ContainerManager.instances[2]
    local labels = {}
    local set = inst.handle.SetLabel
    rawset(inst.handle, "SetLabel", function(self, text)
        labels[#labels + 1] = text
        return set(self, text)
    end)
    NS.SetByPath("container.attach.container", 1, 2)
    NS.SetByPath("container.attach.mode", "container", 2)
    NS.Preview.SetTestMode(true)
    mocks.__fireTimers()
    switch()
    local text = labels[#labels]
    -- red under: handleParts reading C.ATTACHED_NAME_COLOR / C.TEST_TAG_COLOR, or no relabel on the switch
    assertTrue(text:find(NS.SkinEscape("am.attachedName"), 1, true) == 1, "the attached gray: " .. text)
    assertTrue(text:find(NS.SkinEscape("sem.warn") .. NS.L["TEST"], 1, true) ~= nil, "the TEST tag: " .. text)
    NS.Preview.SetTestMode(false)
end)

test("skin surfaces: the strip and close-mark tooltip lines take the skin's gtip colors on each hover", function()
    local NS, mocks, switch = env({ "gtip.title", "gtip.value" })
    local lib = mocks.LibStub("LibKa0s-Widgets-1.0")
    local build, spec = lib.DragHandle, nil
    lib.DragHandle = function(parent, s)
        spec = s
        return build(parent, s)
    end
    NS.Anchors.BuildHandle(NS.ContainerManager.instances[1])
    lib.DragHandle = build
    local function color(entry) return joined(entry[2], entry[3], entry[4]) end
    local function want(name)
        local r, g, b = NS.Skin.Color(name)
        return joined(r, g, b)
    end
    for _, skin in ipairs({ "Ka0s Default", "switched" }) do
        if skin == "switched" then switch() end
        -- red under: a title or body line with no color of its own (the widget's literal gold and white)
        assertEqual(color(spec.tooltip.title), want("gtip.title"), skin .. ": the strip title")
        assertEqual(color(spec.tooltip.body[1]), want("gtip.value"), skin .. ": the how-to line")
        assertEqual(color(spec.tooltip.body[2]), want("gtip.title"), skin .. ": the attached line")
        assertEqual(color(spec.closeTooltip.title), want("gtip.title"), skin .. ": the close-mark title")
        assertEqual(color(spec.closeTooltip.body[1]), want("gtip.value"), skin .. ": the close-mark line")
    end
end)

test("skin surfaces: the unlocked outline is repainted in the new skin's guide color", function()
    local NS, mocks, switch = env({ "chart.crosshair" })
    local inst = NS.ContainerManager.instances[1]
    local real = mocks.CreateFrame
    mocks.CreateFrame = function(...)
        local f = real(...)
        if select(3, ...) == inst.anchor then BS.recorderTextures(f) end
        return f
    end
    NS.SetByPath("locked", false)
    mocks.CreateFrame = real
    mocks.__fireTimers()
    local o = inst.outline
    assertTrue(o ~= nil, "unlocked: the outline is built")
    switch()
    -- red under: the outline drawn once in the literal white at OUTLINE_ALPHA and never repainted
    BS.assertSolid(o, 1, joined(NS.Skin.Color("chart.crosshair")), "switched: the outline")
    NS.SetByPath("locked", true)
end)

test("skin surfaces: the drag-to-attach mark's colors are the skin's, refreshed in place on a switch", function()
    local NS, _, switch = env({ "am.attach", "am.detach" })
    local COLOR = NS.Anchors.Snap.COLOR
    local attach, detach = COLOR.attach, COLOR.detach
    switch()
    -- the same tables, so the highlight's identity check still skips a repaint within one state
    assertTrue(COLOR.attach == attach and COLOR.detach == detach, "refreshed in place")
    -- red under: Snap reading C.SNAP_COLOR / C.DETACH_COLOR, or no refresh on the switch
    assertEqual(joined(attach.r, attach.g, attach.b, attach.a), joined(NS.Skin.Color("am.attach")), "attach")
    assertEqual(joined(detach.r, detach.g, detach.b, detach.a), joined(NS.Skin.Color("am.detach")), "detach")
end)

test("skin surfaces: the frame picker's outline, name and hint are the skin's", function()
    local NS, mocks, switch = env({ "am.pick", "text.accent", "cover.text" })
    local made = {}
    local real = mocks.CreateFrame
    mocks.CreateFrame = function(...)
        local f = real(...)
        made[#made + 1] = f
        BS.recorderTextures(f)
        return f
    end
    NS.FramePicker.Start(function() end, function() end)
    mocks.CreateFrame = real
    local overlay = mocks.__globals.AuraMasterFramePicker
    local outline
    for _, f in ipairs(made) do
        if f.__parent == overlay then outline = f end
    end
    local colors = {}
    rawset(overlay, "SetTextColor", function(_, r, g, b) colors[#colors + 1] = joined(r, g, b) end)
    local texts = {}
    rawset(overlay, "SetText", function(_, s) texts[#texts + 1] = s end)
    switch()
    -- red under: the outline's literal blue (0.2, 0.8, 1) drawn once at build
    assertEqual(stripEdge(outline), "2 " .. joined(NS.Skin.Color("am.pick")), "switched: the picker's outline")
    local r, g, b = NS.Skin.Color("text.accent")
    assertEqual(colors[#colors], joined(r, g, b), "switched: the frame name in text.accent")
    overlay:__fire("OnUpdate")
    overlay:__fire("OnUpdate")
    -- red under: the hint's literal |cffaaaaaa
    assertTrue(texts[#texts]:find(NS.SkinEscape("cover.text"), 1, true) == 1, "the hint: " .. tostring(texts[#texts]))
    overlay:__fire("OnKeyDown", "ESCAPE")
end)

test("skin surfaces: a shown TEST marker is retold in the new skin's sem.warn", function()
    local NS, mocks, switch = env({ "sem.warn" })
    NS.Preview.SetTestMode(true)
    mocks.__fireTimers()
    local inst
    for _, i in pairs(NS.ContainerManager.instances) do
        if i.testMarker and i.testMarker:IsShown() then inst = i end
    end
    assertTrue(inst ~= nil, "a locked test mode shows a marker")
    local texts = {}
    rawset(inst.testMarkerText, "SetText", function(_, s) texts[#texts + 1] = s end)
    switch()
    -- red under: the marker's text built once, in the literal orange
    assertEqual(texts[#texts], NS.SkinEscape("sem.warn") .. NS.L["TEST"] .. "|r")
    NS.Preview.SetTestMode(false)
end)
