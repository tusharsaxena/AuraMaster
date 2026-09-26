-- tests/test_anchors_handle.lua — the drag handle modules/Anchors.lua builds on every container
-- through LibKa0s-Widgets-1.0's DragHandle: its look (the strip, the gold edge, the label, the help
-- mark), where it sits and how wide it is, the anchor's clamp rect, lockdown, the tooltip, drag and
-- click, the secret-geometry guards (feedback E), the TEST tag (feedback #8), the right-click to the
-- Containers page (feedback #9) and the attached container's gray name.
-- Peeled from tests/test_anchors.lua on its case seams (AM-ATS-02), which had reached 1481 lines
-- against layout-§1's 1500-line cap; the cases moved unchanged.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local BS = dofile("tests/border_strips.lua")
local HR = dofile("tests/handle_recorder.lua")
local recordedHandle, last = HR.recordedHandle, HR.last

-- ── the drag handle ───────────────────────────────────────────────────────────────────────────

--- Measure every handle label as `width` wide. The seam moved with the strip: the widget measures on
--- a detached font string of its own (`lib.__DragHandleMeasurer`), never on the label, whose width can
--- read secret (feedback E). One lib table per environment, so a replacement here leaks nowhere.
local function measureAs(mocks, width)
    mocks.LibStub("LibKa0s-Widgets-1.0").__DragHandleMeasurer = function()
        return { SetText = function() end, GetStringWidth = function() return width end }
    end
end

--- What the widget keeps clear on EACH side of the label: the mark's inset, its frame less the gutter
--- its art is centered in, and the clearance in front of that art (`lib.DRAG_HANDLE.RESERVE`). The
--- strip's natural width is the measured label plus twice this. It replaced this file's own
--- `HANDLE_PAD + HANDLE_HELP * 2` (24 + 28 = 52), and it is 58: the mark's click target grew to the
--- strip's full height while its art shrank to 8px, which is the widget's correction, not a drift.
--- It is 94 since batch 8 CX-3: the strip carries a close mark left of the "?", and the widget grows
--- the reserve by that mark's frame (HELP_HIT, 18) on BOTH sides so the label stays centered:
--- 2 * (29 + 18). The widget answers it as handle:Reserve().
local RESERVE2 = 94

test("handle: a dark strip with a 1px gold edge, a gold label and the catalog help mark", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local h = recordedHandle(mocks, NS, inst)
    -- red under: a BackdropTemplate strip (its OnSizeChanged runs Backdrop.lua:226 on a secret size)
    assertNil(h.__template, "a plain button, never a BackdropTemplate")
    assertNil(h.__rec.SetBackdrop, "no backdrop")
    assertEqual(last(h, "SetHeight")[1], 18)
    -- The fill: one texture under everything, covering the strip, black at 0.75 (the old backdrop's
    -- bgFile and SetBackdropColor).
    local bg = h.bg
    assertTrue(bg ~= nil and bg ~= h, "a fill texture of its own")
    assertEqual(bg.__layer, "BACKGROUND")
    assertTrue(bg:__last("SetAllPoints")[1] == h, "the fill covers the strip")
    assertEqual(bg:__joined("SetColorTexture"), "0,0,0,0.75")
    -- The edge: Style.ApplyBorder's four Solid strips, 1px, gold at 0.6 (the old edgeFile, edgeSize
    -- and SetBackdropBorderColor), read once the strip shows.
    measureAs(mocks, 60)
    NS.Anchors.UpdateHandle(inst, true)
    BS.assertSolid(h, 1, "1,0.82,0,0.6", "the handle's edge")
    assertEqual(table.concat(last(h, "SetTextColor"), ","), "1,0.82,0")
    -- The mark is an ART SIZE INSIDE A FRAME SIZE and they are two numbers (lib.DRAG_HANDLE): the
    -- Button is the strip's full height, so the only right-click affordance on the strip stays easy
    -- to hit, and the "?" is 8px of ink centered in it, about the chevron's weight beside the small
    -- label face. The kit hands a texture back as its frame, so both land on `help` in order.
    local help = h.help
    local sizes = help.__rec.SetSize
    assertEqual(table.concat(sizes[1], ","), "18,18", "the click target: the strip's full height")
    assertEqual(table.concat(sizes[2], ","), "8,8", "the art inside it")
    local points = help.__rec.SetPoint
    local p = points[1]
    assertEqual(p[1], "RIGHT"); assertTrue(p[2] == h); assertEqual(p[3], "RIGHT")
    assertEqual(p[4], -4); assertEqual(p[5], 0)
    assertEqual(points[2][1], "CENTER", "the art is centered in its gutter, not stretched over it")
    assertTrue(NS.Icon("help") ~= nil, "the vendored catalog carries the help mark")
    assertEqual(last(help, "SetTexture")[1], NS.Icon("help"))
    local _, covers = last(h, "SetAllPoints")
    -- red under: restoring SetAllPoints(anchor) in BuildHandle
    assertEqual(covers, 0, "the handle never covers the anchor")
end)

test("handle: under a secret anchor size it builds, resizes and draws its edge without arithmetic", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local cfg = NS.Database.FindContainer(1)
    -- A container attached to another frame (or container) inherits that frame's secret geometry,
    -- and so does every frame of ours built under its anchor (tests/wow_mock.lua's __layOut).
    mocks.__layOut(inst.anchor)
    local built, berr = pcall(NS.Anchors.BuildHandle, inst)
    -- red under: SetBackdrop on the strip (arithmetic on the secret size, Backdrop.lua:226)
    assertTrue(built, tostring(berr))
    local ok, h = pcall(recordedHandle, mocks, NS, inst)
    assertTrue(ok, tostring(h))
    assertTrue(h.__secretRect, "the strip's own size reads secret")
    measureAs(mocks, 60)
    local placed, err = pcall(NS.Anchors.UpdateHandle, inst, true)
    assertTrue(placed, tostring(err))
    assertTrue(h:IsShown())
    -- The client runs the strip's OnSizeChanged when UpdateHandle resizes it.
    -- red under: BackdropTemplate's size script (it re-runs the arithmetic on every resize)
    assertNil(h:GetScript("OnSizeChanged"), "no size script on the strip")
    local fired, ferr = pcall(h.__fire, h, "OnSizeChanged")
    assertTrue(fired, tostring(ferr))
    cfg.layout.growV = "up"
    placed, err = pcall(NS.Anchors.UpdateHandle, inst, true)
    assertTrue(placed, tostring(err))
    BS.assertSolid(h, 1, "1,0.82,0,0.6", "a secret strip's edge")
    assertEqual(h.bg:__joined("SetColorTexture"), "0,0,0,0.75")
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
    assertEqual(last(h, "SetWidth")[1], math.max(RESERVE2, w), "an empty label")
    measureAs(mocks, w + 100)
    NS.Anchors.UpdateHandle(inst, true)
    -- B11-T11: a bar wide enough for the marks and a readable label caps the strip at its width (the
    -- name is shortened, tests/test_anchors_width.lua); a narrower element keeps the natural width
    assertEqual(last(h, "SetWidth")[1], w, "a label wider than the element: capped at it")
    cfg.bars.width = 100
    NS.Anchors.UpdateHandle(inst, true)
    assertEqual(last(h, "SetWidth")[1], w + 100 + RESERVE2, "too narrow to cap: the label with its marks")
end)

test("handle: while shown the anchor's clamp rect takes it in; hidden, or in combat, the rect is left alone", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local cfg = NS.Database.FindContainer(1)
    local h = recordedHandle(mocks, NS, inst)
    local insets
    rawset(inst.anchor, "SetClampRectInsets", function(_, l, r, t, b) insets = table.concat({ l, r, t, b }, ",") end)
    cfg.bars.width = 100   -- too narrow to cap (B11-T11), so the strip runs past it
    local w = NS.Style.ElementSize(cfg)
    measureAs(mocks, w + 100)
    local over = 100 + RESERVE2
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
    -- red under: dropping the InCombatLockdown gate in UpdateHandle
    assertNil(insets, "the anchor parents an aura engine: no layout work on it in combat")
end)

test("handle: under lockdown a changed layout does not re-place the handle; the next pass after it does", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local cfg = NS.Database.FindContainer(1)
    local h = recordedHandle(mocks, NS, inst)
    cfg.layout.growV, cfg.layout.growH = "down", "right"
    NS.Anchors.UpdateHandle(inst, true)
    local _, clears = last(h, "ClearAllPoints")
    local _, points = last(h, "SetPoint")
    local _, widths = last(h, "SetWidth")
    cfg.layout.growV = "up"
    mocks.__lockdown = true
    NS.Anchors.UpdateHandle(inst, true)
    -- red under: dropping the InCombatLockdown gate in UpdateHandle
    assertEqual(select(2, last(h, "ClearAllPoints")), clears, "no ClearAllPoints under lockdown")
    assertEqual(select(2, last(h, "SetPoint")), points, "no SetPoint under lockdown")
    assertEqual(select(2, last(h, "SetWidth")), widths, "no SetWidth under lockdown")
    assertTrue(h:IsShown(), "showing still happens under lockdown")
    NS.Anchors.UpdateHandle(inst, false)
    assertFalse(h:IsShown(), "and so does hiding")
    mocks.__lockdown = false
    NS.Anchors.UpdateHandle(inst, true)
    local p = last(h, "SetPoint")
    assertEqual(p[1], "TOPLEFT", "after lockdown the handle moves below the anchor")
    assertEqual(p[3], "BOTTOMLEFT")
end)

test("handle: a handle first shown under lockdown is placed once; the anchor's clamp still waits", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local h = recordedHandle(mocks, NS, inst)
    local insets = 0
    rawset(inst.anchor, "SetClampRectInsets", function() insets = insets + 1 end)
    -- The label's own SetPoint("CENTER") is recorded on the strip (the kit stub hands a font string
    -- back as its frame), so count from what BuildHandle already logged.
    local _, before = last(h, "SetPoint")
    mocks.__lockdown = true
    NS.Anchors.UpdateHandle(inst, true)
    local p, points = last(h, "SetPoint")
    -- red under: gating the first placement on InCombatLockdown like every later one
    assertEqual(points, before + 1, "a never-placed handle gets its points, even under lockdown")
    assertEqual(p[2], inst.anchor, "placed against the container's anchor")
    assertTrue(h:IsShown())
    NS.Anchors.UpdateHandle(inst, true)
    assertEqual(select(2, last(h, "SetPoint")), before + 1, "and only once: a later pass under lockdown keeps it")
    mocks.__lockdown = false
    assertEqual(insets, 0, "the anchor's clamp is not touched under lockdown")
end)

test("handle: a visibility pass that changes nothing re-sets no clamp insets", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    recordedHandle(mocks, NS, inst)
    local calls = 0
    rawset(inst.anchor, "SetClampRectInsets", function() calls = calls + 1 end)
    NS.Anchors.UpdateHandle(inst, false)
    NS.Anchors.UpdateHandle(inst, false)
    NS.Anchors.UpdateHandle(inst, false)
    -- red under: clampToHandle setting the insets on every pass instead of only when they change
    assertTrue(calls <= 1, "three locked passes re-set the clamp at most once, got " .. calls)
    NS.Anchors.UpdateHandle(inst, true)
    local shown = calls
    assertTrue(shown > 0, "showing the handle extends the clamp")
    NS.Anchors.UpdateHandle(inst, true)
    assertEqual(calls, shown, "an unchanged shown handle re-sets nothing")
    NS.Anchors.UpdateHandle(inst, false)
    assertEqual(calls, shown + 1, "hiding restores the insets, once")
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
    local opened = {}
    NS.OpenOptionsPage = function(key)
        local n = #opened
        opened[n + 1] = key
    end
    NS.State.SetActiveContainer(1)
    h.help:__fire("OnClick", "RightButton")
    -- red under: the right-click opening the main panel, not the Containers page (feedback #9)
    assertEqual(table.concat(opened, ","), "containers")
    assertEqual(NS.State.activeContainerId, 2)
end)

test("handle: the tooltip follows the cursor, owned by UIParent, never anchored to the strip or the mark", function()
    -- Every anchor inherits DisableUntrustedLayoutScriptsTemplate, so the strip and its help mark sit in
    -- a restricted layout chain, and the client refuses GameTooltip:SetOwner on either: "Anchoring
    -- disallowed as dependent object would inherit forbidden aspects: UntrustedLayoutScriptExecution".
    -- red under: showTooltip owning the tooltip by the hovered frame (the old SetOwner(owner, "ANCHOR_TOP")).
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[2]
    local h = recordedHandle(mocks, NS, inst)
    local owners = {}
    rawset(mocks.GameTooltip, "SetOwner", function(_, owner, anchor)
        owners[#owners + 1] = { owner = owner, anchor = anchor }
    end)
    h:__fire("OnEnter")
    h.help:__fire("OnEnter")
    assertEqual(#owners, 2, "the strip and the help mark both show the tooltip")
    for i, o in ipairs(owners) do
        assertTrue(o.owner == mocks.UIParent, "hover " .. i .. " is owned by UIParent")
        assertEqual(o.anchor, "ANCHOR_CURSOR", "hover " .. i .. " follows the cursor")
    end
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

test("handle: with no media catalog the help mark falls back to Blizzard's information icon", function()
    -- The ladder is the widget's last rung now, reached by handing it no `helpIcon` at all. A client
    -- that unzipped LibKa0s without its media, or a catalog that stops carrying `help`, still gets a
    -- mark rather than an invisible button.
    local NS, mocks = fresh()
    NS.Icon = function() return nil end
    local inst = NS.ContainerManager.instances[1]
    local h = recordedHandle(mocks, NS, inst)
    assertEqual(last(h.help, "SetTexture")[1], [[Interface\FriendsFrame\InformationIcon]])
end)

test("handle: with LibKa0s absent a container has no handle at all, and every pass over it is a no-op", function()
    -- The strip is LibKa0s-Widgets-1.0's, so the vendored folder going missing takes it with it --
    -- the case the old degraded-environment test used to reach. BuildHandle answers nil rather than
    -- half a strip, and nothing downstream may raise on that nil.
    local NS2, mocks2 = dofile("tests/degraded_env.lua")()
    assertNil(mocks2.LibStub("LibKa0s-Widgets-1.0", true), "no widget library in a degraded client")
    local inst = { id = 1, anchor = mocks2.CreateFrame("Frame"), Cfg = function() return nil end }
    -- red under: BuildHandle calling KW.DragHandle without checking the library resolved
    local ok, handle = pcall(NS2.Anchors.BuildHandle, inst)
    assertTrue(ok, tostring(handle))
    assertNil(handle, "no widget, no handle")
    inst.handle = handle
    local shown, err = pcall(NS2.Anchors.UpdateHandle, inst, true)
    assertTrue(shown, tostring(err))
end)

-- ── the strip's name, tooltip, drag and clicks ────────────────────────────────────────────────

test("handle: the strip names its container, and a container whose settings are gone hides it", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local h = recordedHandle(mocks, NS, inst)
    local texts = {}
    -- The label is the strip in the kit (a font string comes back as its frame).
    rawset(h, "SetText", function(_, s)
        texts[#texts + 1] = s
    end)
    NS.Anchors.UpdateHandle(inst, true)
    assertEqual(texts[#texts], NS.Database.FindContainer(1).name)
    assertTrue(h:IsShown())
    inst.Cfg = function() return nil end
    local ok, err = pcall(NS.Anchors.UpdateHandle, inst, true)
    -- red under: UpdateHandle placing a handle for a container with no settings (it raises)
    assertTrue(ok, tostring(err))
    assertFalse(h:IsShown(), "nothing to drag")
    assertEqual(texts[#texts], "")
end)

test("handle: an attached container's tooltip says where its offsets are set; a screen one does not", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local h = recordedHandle(mocks, NS, inst)
    local lines = {}
    rawset(mocks.GameTooltip, "AddLine", function(_, s)
        lines[#lines + 1] = s
    end)
    h:__fire("OnEnter")
    assertEqual(#lines, 1, "a screen container: how to drag, nothing more")
    NS.Database.FindContainer(1).attach.mode = "frame"
    NS.Database.FindContainer(1).attach.frame = "PlayerFrame"
    lines = {}
    h:__fire("OnEnter")
    -- red under: "Drag to move" on a container a drag cannot move (owner, 2026-09-26)
    assertEqual(lines[1], NS.L["Anchored to '%s', so it cannot be dragged. Right-click for settings."]:format("PlayerFrame"))
    -- red under: showTooltip without its attached line (the player drags and nothing moves)
    assertEqual(lines[2], NS.L["Attached — set its offsets in the Layout section."])
end)

test("handle: an attached container, or one in combat, does not move on a drag, and a stray drag stop stores nothing", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local h = recordedHandle(mocks, NS, inst)
    local moved, writes = 0, 0
    rawset(inst.anchor, "StartMoving", function() moved = moved + 1 end)
    NS.NewBusTarget():RegisterMessage(NS.MSG.CONFIG_CHANGED, function() writes = writes + 1 end)
    inst.anchor.GetPoint = function() return "TOP", nil, "TOP", 1, 1 end
    NS.Database.FindContainer(1).attach.mode = "container"
    h:__fire("OnDragStart")
    h:__fire("OnDragStop")
    -- red under: the drag start without its screen-mode check (an attached container is dragged off its target)
    assertEqual(moved, 0, "attached")
    assertEqual(writes, 0, "and no position is stored for it")
    NS.Database.FindContainer(1).attach.mode = "screen"
    mocks.__lockdown = true
    h:__fire("OnDragStart")
    mocks.__lockdown = false
    -- red under: the drag start without its lockdown check (the anchor parents an aura engine)
    assertEqual(moved, 0, "in combat")
    h:__fire("OnDragStop")
    assertEqual(writes, 0, "a drag stop with no drag in progress")
end)

test("handle: the strip sits fifty levels above its anchor, over the container's elements", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local h = recordedHandle(mocks, NS, inst)
    -- red under: BuildHandle leaving the strip at the anchor's level (the first element draws over it)
    assertEqual(h:GetFrameLevel(), inst.anchor:GetFrameLevel() + 50)
    -- red under: Apply never reaching anchor:SetFrameLevel (the mock's own default would still be
    -- above 0 and pass a bare ">0" check)
    assertEqual(inst.anchor:GetFrameLevel(), NS.CONTAINER_TEMPLATE.layout.level, "the anchor's level was applied first")
end)

test("handle: a left click on the strip opens nothing; a right click opens this container's settings", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[3]
    local h = recordedHandle(mocks, NS, inst)
    local opened = 0
    NS.OpenOptionsPage = function() opened = opened + 1 end
    h:__fire("OnClick", "LeftButton")
    -- red under: the strip's OnClick ignoring the button (every drag's click would open the panel)
    assertEqual(opened, 0)
    h:__fire("OnClick", "RightButton")
    assertEqual(opened, 1)
    assertEqual(NS.State.activeContainerId, 3)
end)

-- ── secret geometry (feedback E, 2026-09-19) ──────────────────────────────────────────────────
-- An anchor attached to an engine container, or to a frame anchored to one, inherits its secret
-- geometry, and so does everything anchored under it: the strip, its label. The client then answers
-- a width or a frame level as a secret number, and arithmetic on one raises ("attempt to perform
-- arithmetic on a secret number value", modules/Anchors.lua:452 before the fix). The harness cannot
-- make a number raise, so a case plants the client's issecretvalue on a sentinel number, and makes
-- the label's own GetStringWidth raise the client's error outright.

local SECRET = 41.5

--- A fresh environment whose client calls SECRET a secret number.
local function secretEnv()
    local NS, mocks = fresh()
    mocks.issecretvalue = function(v) return v == SECRET end
    return NS, mocks
end

test("handle: the width comes from a detached measuring string, never the label, which may sit on secret geometry (E)", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local h = recordedHandle(mocks, NS, inst)
    NS.Database.FindContainer(1).bars.width = 100   -- natural width, not capped (B11-T11)
    local w = NS.Style.ElementSize(NS.Database.FindContainer(1))
    -- The label is the strip in the kit (a font string comes back as its frame).
    rawset(h, "GetStringWidth", function() error("attempt to perform arithmetic on a secret number value") end)
    local measured = {}
    mocks.LibStub("LibKa0s-Widgets-1.0").__DragHandleMeasurer = function()
        return {
            SetText = function(_, s)
                local n = #measured
                measured[n + 1] = s
            end,
            GetStringWidth = function() return w + 100 end,
        }
    end
    local ok, err = pcall(NS.Anchors.UpdateHandle, inst, true)
    -- red under: placeHandle reading handle.label:GetStringWidth() (the reported error)
    assertTrue(ok, tostring(err))
    assertEqual(last(h, "SetWidth")[1], w + 100 + RESERVE2, "the measured width sizes the strip")
    assertEqual(measured[#measured], NS.Database.FindContainer(1).name, "the label's own text is measured")
end)

test("handle: a measured width that reads secret falls back to the element's width, never raising (E)", function()
    local NS, mocks = secretEnv()
    local inst = NS.ContainerManager.instances[2]   -- a 32px icon row: the floor and the label differ
    local h = recordedHandle(mocks, NS, inst)
    mocks.LibStub("LibKa0s-Widgets-1.0").__DragHandleMeasurer = function()
        return { SetText = function() end, GetStringWidth = function() return SECRET end }
    end
    NS.Anchors.UpdateHandle(inst, true)
    -- red under: labelWidth without its NumberOr guard (41.5 + 52 = 93.5 in the harness; a raise in
    -- the client)
    assertEqual(last(h, "SetWidth")[1], math.max(RESERVE2, NS.Style.ElementSize(NS.Database.FindContainer(2))))
end)

test("handle: an anchor whose frame level reads secret places the strip from the stored level (E)", function()
    local NS, mocks = secretEnv()
    local inst = NS.ContainerManager.instances[1]
    local h = recordedHandle(mocks, NS, inst)
    rawset(inst.anchor, "GetFrameLevel", function() return SECRET end)
    local ok, err = pcall(NS.Anchors.UpdateHandle, inst, true)
    assertTrue(ok, tostring(err))
    -- red under: handleLevel adding HANDLE_LEVEL to the unguarded read (41.5 + 50)
    assertEqual(h:GetFrameLevel(), NS.CONTAINER_TEMPLATE.layout.level + 50)
end)

test("handle: an attached container's strip falls back to the stored level when its target's frame level reads secret (E)", function()
    local NS, mocks = secretEnv()
    NS.SetByPath("container.attach.container", 1, 2)
    NS.SetByPath("container.attach.mode", "container", 2)
    NS.SetByPath("locked", false)
    NS.Preview.SetTestMode(true)
    mocks.__fireTimers()
    local CM = NS.ContainerManager
    local one, two = CM.instances[1], CM.instances[2]
    rawset(one.anchor, "GetFrameLevel", function() return SECRET end)
    local ok, err = pcall(NS.Anchors.UpdateHandle, two, true)
    assertTrue(ok, tostring(err))
    local stored = NS.CONTAINER_TEMPLATE.layout.level
    -- red under: handleLevel's target read back to (target.anchor:GetFrameLevel() or 0), which lets
    -- 1's secret level (41.5) into "or 0"'s arithmetic instead of falling back through levelOf
    assertEqual(two.handle:GetFrameLevel(), math.max(two.anchor:GetFrameLevel() + 50, stored + 51))
end)

test("anchors: a drag whose offsets read secret saves nothing (E)", function()
    local NS = secretEnv()
    local inst = NS.ContainerManager.instances[1]
    inst.anchor.GetPoint = function() return "TOP", nil, "TOP", SECRET, -30 end
    local writes = 0
    NS.NewBusTarget():RegisterMessage(NS.MSG.CONFIG_CHANGED, function() writes = writes + 1 end)
    local ok, err = pcall(NS.Anchors.SavePosition, inst)
    assertTrue(ok, tostring(err))
    -- red under: SavePosition rounding and storing a secret offset
    assertEqual(writes, 0)
    assertEqual(NS.Database.FindContainer(1).position.x, NS.STARTER_CONTAINERS[1].position.x)
end)

-- ── the TEST marker (feedback #8) ─────────────────────────────────────────────────────────────

test("handle: while test mode is on the label carries an orange TEST tag after the name; off, the name alone (feedback #8)", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local h = recordedHandle(mocks, NS, inst)
    local texts = {}
    rawset(h, "SetText", function(_, s)
        local n = #texts
        texts[n + 1] = s
    end)
    local name = NS.Database.FindContainer(1).name
    NS.Anchors.UpdateHandle(inst, true)
    assertEqual(texts[#texts], name, "no tag outside test mode")
    NS.Preview.SetTestMode(true)
    mocks.__fireTimers()
    -- red under: UpdateHandle writing the bare name whatever the mode (no marker on the placeholders)
    assertEqual(texts[#texts], name .. "  |c" .. NS.Constants.TEST_TAG_COLOR .. NS.L["TEST"] .. "|r")
    assertEqual(NS.Constants.TEST_TAG_COLOR, "ffff8000", "orange")
    NS.Preview.SetTestMode(false)
    mocks.__fireTimers()
    -- red under: a tag left behind once test mode ends
    assertEqual(texts[#texts], name, "the tag goes when test mode does")
end)

-- ── right-click the "?" → the Containers page (feedback #9) ──────────────────────────────────────────────

test("handle: a right-click on the ? opens the Containers page with this container selected in its band (feedback #9)", function()
    local opened = {}
    local NS, mocks = fresh({ before = function(m)
        m.Settings.OpenToCategory = function(id)
            local n = #opened
            opened[n + 1] = id
        end
    end })
    local P = dofile("tests/page_helpers.lua")(NS, mocks)
    P.show("Containers")                          -- built once, on container 1
    local inst = NS.ContainerManager.instances[2]
    local h = recordedHandle(mocks, NS, inst)
    h.help:__fire("OnClick", "RightButton")
    -- red under: the click reaching the main panel's open (no category switch at all)
    assertEqual(#opened, 1, "one category switch")
    assertEqual(NS.State.activeContainerId, 2)
    P.show("Containers")
    -- red under: the Containers page opening on the container it was last drawn for
    assertEqual(P.banner(NS.Helpers.__pageCtx.containers).value, 2, "the band's picker names container 2")
end)

test("handle: under combat lockdown the right-click is refused in gray and selects nothing (feedback #9)", function()
    local opened = 0
    local NS, mocks = fresh({ before = function(m)
        m.Settings.OpenToCategory = function() opened = opened + 1 end
    end })
    local inst = NS.ContainerManager.instances[2]
    local h = recordedHandle(mocks, NS, inst)
    local lines = {}
    rawset(mocks.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
        local n = #lines
        lines[n + 1] = tostring(msg)
    end)
    NS.State.SetActiveContainer(1)
    mocks.__lockdown = true
    h.help:__fire("OnClick", "RightButton")
    mocks.__lockdown = false
    -- red under: the category switch called under lockdown (it taints the panel for the session)
    assertEqual(opened, 0)
    -- red under: the selection moved by a click that opened nothing
    assertEqual(NS.State.activeContainerId, 1)
    assertTrue(table.concat(lines, "\n"):find("cannot open settings during combat", 1, true) ~= nil, table.concat(lines, " | "))
end)

test("handle: an attached container's name is a desaturated gray, to the screen it keeps the plain color (owner, 2026-09-26)", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[2]
    local h = recordedHandle(mocks, NS, inst)
    local texts = {}
    rawset(h, "SetText", function(_, s)
        local n = #texts
        texts[n + 1] = s
    end)
    local name = NS.Database.FindContainer(2).name
    local dim = "|c" .. NS.Constants.ATTACHED_NAME_COLOR .. name .. "|r"
    -- red under: the dim gold of the first cut, which the owner found not muted enough
    assertEqual(NS.Constants.ATTACHED_NAME_COLOR, "ff8c8a84", "a warm gray, not a gold")
    NS.Anchors.UpdateHandle(inst, true)
    assertEqual(texts[#texts], name, "on the screen: the name as it was")
    NS.SetByPath("container.attach.container", 1, 2)
    NS.SetByPath("container.attach.mode", "container", 2)
    mocks.__fireTimers()
    NS.Anchors.UpdateHandle(inst, true)
    -- red under: handleText writing the bare name whatever the attachment
    assertEqual(texts[#texts], dim, "attached to another container: gray")
    NS.SetByPath("container.attach.mode", "frame", 2)
    mocks.__fireTimers()
    NS.Anchors.UpdateHandle(inst, true)
    assertEqual(texts[#texts], dim, "attached to a named frame: gray")
    NS.Preview.SetTestMode(true)
    mocks.__fireTimers()
    NS.Anchors.UpdateHandle(inst, true)
    assertEqual(texts[#texts], dim .. "  |c" .. NS.Constants.TEST_TAG_COLOR .. NS.L["TEST"] .. "|r",
        "the TEST tag still follows in orange")
    NS.Preview.SetTestMode(false)
    NS.SetByPath("container.attach.mode", "screen", 2)
    mocks.__fireTimers()
    NS.Anchors.UpdateHandle(inst, true)
    assertEqual(texts[#texts], name, "back on the screen: plain again")
end)
