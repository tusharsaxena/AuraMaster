-- tests/drag_helpers.lua - the drag cases' fixtures and the mark's readers, shared by
-- tests/test_anchors_drag.lua (the drag lifecycle and its highlight) and tests/test_anchors_attach.lua
-- (the detach leeway), which was peeled out of it at layout-§1's 1500-line cap (AM-04). Moved
-- verbatim; each suite binds the names it uses to locals of the same name.
--
-- Not a suite (tests/run.lua does not list it) and not part of the vendored kit.
--
--     local DH = dofile("tests/drag_helpers.lua")
--     local plant, env = DH.plant, DH.env

local T = _G.AM_TEST
local assertEqual, assertTrue, assertNil = T.assertEqual, T.assertTrue, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local BS = dofile("tests/border_strips.lua")
local HR = dofile("tests/handle_recorder.lua")
local newRegion = dofile("tests/region_recorder.lua")

--- Plant a rect on `frame`, in its own units at effective scale `scale` (1 when nil).
local function plant(frame, l, b, r, t, scale)
    rawset(frame, "GetLeft", function() return l end)
    rawset(frame, "GetBottom", function() return b end)
    rawset(frame, "GetRight", function() return r end)
    rawset(frame, "GetTop", function() return t end)
    rawset(frame, "GetEffectiveScale", function() return scale or 1 end)
    return frame
end

--- A fresh environment with at least `n` containers, all enabled, on the screen, and shown, each
--- with its handle rebuilt under the recorder (tests/handle_recorder.lua) and shown, as an unlocked
--- profile shows it: a drag starts from a visible strip, and one whose strip hides is canceled.
local function env(n)
    local NS, mocks = fresh()
    while #NS.Database.GetContainers() < (n or 2) do NS.ContainerManager.Create({}) end
    mocks.__fireTimers()
    for _, c in ipairs(NS.Database.GetContainers()) do
        c.enabled, c.attach.mode = true, "screen"
        local inst = NS.ContainerManager.instances[c.id]
        inst.anchor:Show()
        inst.hangMode = "engine"
        HR.recordedHandle(mocks, NS, inst):Show()
    end
    return NS, mocks
end

--- Record the anchor's moves: every StartMoving, and its points as ClearAllPoints and SetPoint
--- leave them (`anchor.__points`, the last SetPoint's arguments; `anchor.__moves`, the log in
--- order, "clear", "point" and "start").
local function recordAnchor(anchor)
    anchor.__moves = {}
    rawset(anchor, "ClearAllPoints", function(self) self.__moves[#self.__moves + 1] = "clear" end)
    rawset(anchor, "SetPoint", function(self, ...)
        self.__points = { ... }
        self.__moves[#self.__moves + 1] = "point"
    end)
    rawset(anchor, "StartMoving", function(self) self.__moves[#self.__moves + 1] = "start" end)
    rawset(anchor, "StopMovingOrSizing", function() end)
    return anchor
end

--- Make every frame created under UIParent (or under one of those) a region recorder from now on, so
--- the highlight and its marker log every call they receive, each with its parent on `__parentFrame`,
--- and each listed on `mocks.__overlays` (so a case can show none is anchored to a strip, A6).
--- Returns a restore.
local function recordOverlays(mocks)
    local real = mocks.CreateFrame
    mocks.__overlays = {}
    mocks.CreateFrame = function(kind, name, parent, ...)
        if parent and (parent == mocks.UIParent or parent.__overlay) then
            local f = newRegion()
            f.__overlay, f.__shown, f.__parentFrame = true, true, parent
            mocks.__overlays[#mocks.__overlays + 1] = f
            return f
        end
        return real(kind, name, parent, ...)
    end
    return function() mocks.CreateFrame = real end
end

--- `col` ({ r, g, b, a }) as SetColorTexture's joined arguments.
local function rgba(col) return table.concat({ col.r, col.g, col.b, col.a }, ",") end

--- How `strip`'s OWN four edge strips (the widget's edge, painted with Style.DrawEdge on the handle)
--- were last painted, as "size r,g,b,a": GOLD is the widget's own 1px gold, "2 <color>" the mark's
--- (A6). Strips that disagree come back each listed, so a half-repainted edge fails by name.
--- @return string
local function stripEdge(strip)
    local s = BS.strips(strip)
    if #s ~= 4 then return #s .. " strips" end
    local function size(i, setter)
        local last = s[i]:__last(setter)
        return last and last[1] or "?"
    end
    local seen = {}
    for i, setter in ipairs({ "SetHeight", "SetHeight", "SetWidth", "SetWidth" }) do
        seen[i] = size(i, setter) .. " " .. (s[i]:__joined("SetColorTexture") or "?")
    end
    for i = 2, 4 do
        if seen[i] ~= seen[1] then return table.concat(seen, " | ") end
    end
    return seen[1]
end

--- Assert no frame of ours (every overlay recordOverlays made) is anchored to `strip` (A6: the client
--- voids an anchor into the restricted tree a strip hangs in, which is why A5's overlay never showed).
local function assertNothingHungOn(mocks, strip, what)
    for _, f in ipairs(mocks.__overlays or {}) do
        for _, m in ipairs({ "SetAllPoints", "SetPoint" }) do
            for _, args in ipairs(f:__calls(m)) do
                for i = 1, args.n do
                    assertTrue(args[i] ~= strip, what .. ": no frame of ours is anchored to the strip (" .. m .. ")")
                end
            end
        end
    end
end

--- Assert the mark is on strip `strip` in `col` (A6): the strip's OWN four edge strips repainted 2px in
--- the mark's color, the strip the mark says it painted, and no frame of ours hung on it.
local function assertEdgeOn(NS, mocks, strip, col, what)
    local Snap = NS.Anchors.Snap
    assertEqual(stripEdge(strip), "2 " .. rgba(col), what .. ": the strip's own edge, 2px in the mark's color")
    assertTrue(Snap.MarkedStrip and Snap.MarkedStrip() == strip, what .. ": the strip the mark painted")
    assertNil(Snap.stripEdge, what .. ": no overlay frame (A5's) is built")
    assertNothingHungOn(mocks, strip, what)
end

--- The last SetPoint of dot `dot` as "POINT x,y", after checking it is centered and hung from UIParent.
local function dotAt(mocks, dot, what)
    local p = dot:__last("SetPoint")
    assertTrue(p ~= nil, what .. ": placed")
    assertEqual(p[1], "CENTER", what .. ": centered")
    assertTrue(p[2] == mocks.UIParent, what .. ": hung from UIParent")
    return p[3] .. " " .. p[4] .. "," .. p[5]
end

--- One end of line `line` (`which` "SetStartPoint" or "SetEndPoint") as "POINT x,y", after checking it
--- is set against UIParent.
local function lineEnd(mocks, line, which)
    local p = line:__last(which)
    assertTrue(p ~= nil, which .. " set")
    assertTrue(p[2] == mocks.UIParent, which .. ": in UIParent units")
    return p[1] .. " " .. p[3] .. "," .. p[4]
end

return {
    plant = plant, env = env, recordAnchor = recordAnchor, recordOverlays = recordOverlays,
    rgba = rgba, stripEdge = stripEdge, assertNothingHungOn = assertNothingHungOn,
    assertEdgeOn = assertEdgeOn, dotAt = dotAt, lineEnd = lineEnd,
}
