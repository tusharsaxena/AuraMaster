-- tests/test_anchors_label.lua - the per-container name label (batch 8 NL-1..NL-4, owner feedback #8,
-- decision D6). An optional label, off by default, showing the container's name where its drag strip
-- sits, locked or unlocked. While unlocked BOTH show: the strip moves out past the label by the
-- label's height plus the strip gap, on the same side (as KickCD's strip sits above its Text Label).
-- Its own suite because tests/test_anchors.lua sits near layout-§1's 1500-line cap.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")

local RECORDED = { "SetPoint", "SetSize", "SetText", "SetFont", "SetTextColor", "SetJustifyH",
    "EnableMouse", "SetBackdrop", "SetWordWrap" }

--- Record the setters above on every frame created from here on (the kit hands a font string back as
--- its own frame, so a label's host and its text land on one record).
local function recordFrames(mocks)
    local real = mocks.CreateFrame
    mocks.CreateFrame = function(...)
        local f = real(...)
        f.__rec = {}
        for _, m in ipairs(RECORDED) do
            rawset(f, m, function(self, ...)
                local log = self.__rec[m] or {}
                self.__rec[m] = log
                log[#log + 1] = { ... }
                return true
            end)
        end
        return f
    end
end

local function calls(f, method) return (f.__rec and f.__rec[method]) or {} end
local function last(f, method)
    local log = calls(f, method)
    return log[#log]
end

--- The last SetPoint `f` made against `relativeTo` (the label's host is pointed at the anchor, its
--- text at the host: on one record in the kit).
local function lastPointOn(f, relativeTo)
    local log = calls(f, "SetPoint")
    local n = #log
    for i = n, 1, -1 do
        if log[i][2] == relativeTo then return log[i] end
    end
    return nil
end

--- Record SetPoint on an existing frame (the strip, built before any case can hook CreateFrame).
local function recordPoints(f)
    local rec = {}
    rawset(f, "SetPoint", function(_, ...)
        local n = #rec
        rec[n + 1] = { ... }
    end)
    return rec
end

--- A fresh environment recording every new frame, with container `id`'s label turned on.
local function withLabel(id, opts)
    local NS, mocks = fresh(opts)
    recordFrames(mocks)
    id = id or 1
    NS.SetByPath("container.label.show", true, id)
    mocks.__fireTimers()
    return NS, mocks, NS.ContainerManager.instances[id]
end

local STRIP_H, STRIP_GAP = 18, 2

-- ── the stored shape (NL-1) ───────────────────────────────────────────────────────────────────

test("label: the template carries label = { show = false, justifyH = AUTO, x = 0, y = 0, font = gold Friz 12 OUTLINE }", function()
    local NS = fresh()
    local lb = NS.CONTAINER_TEMPLATE.label
    -- red under: no label block in the template
    assertTrue(lb ~= nil, "a label block")
    assertFalse(lb.show); assertEqual(lb.x, 0); assertEqual(lb.y, 0)
    -- red under: a template with no justify leaf (the row's path would not resolve, architecture-5)
    assertEqual(lb.justifyH, NS.Constants.LABEL_JUSTIFY_AUTO, "no pick: the style default (B9 E7)")
    local f = lb.font
    assertEqual(f.font, "Friz Quadrata TT"); assertEqual(f.fontSize, 12); assertEqual(f.fontFlags, "OUTLINE")
    assertFalse(f.fontShadow); assertFalse(f.useClassColorFont)
    assertEqual(f.fontColor.r, 1); assertEqual(f.fontColor.g, 0.82); assertEqual(f.fontColor.b, 0); assertEqual(f.fontColor.a, 1)
    for _, c in ipairs(NS.Database.GetContainers and NS.Database.GetContainers() or {}) do
        assertFalse(c.label.show, "every starter container backfills the label off")
    end
end)

test("label: a stored container without a label gains the whole block, and a stored one survives the backfill", function()
    local NS = fresh()
    local p = NS.db.profile
    local version = NS.SCHEMA_VERSION
    local c1, c2 = p.containers[1], p.containers[2]
    c1.label = nil
    c2.label = { show = true, font = { fontColor = { r = 0, g = 1, b = 0, a = 1 } } }
    NS.Database.PrepareProfile(p)
    assertFalse(c1.label.show); assertEqual(c1.label.font.fontSize, 12)
    assertTrue(c2.label.show); assertEqual(c2.label.font.fontColor.g, 1); assertEqual(c2.label.x, 0)
    assertEqual(NS.SCHEMA_VERSION, version, "an added key needs no schema step")
end)

-- ── drawing and showing (NL-2, NL-3) ──────────────────────────────────────────────────────────

test("label: off by default, no label frame is ever built", function()
    local NS = fresh()
    for _, inst in pairs(NS.ContainerManager.instances) do
        assertNil(inst.label, "container " .. inst.id)
    end
end)

test("label: on and locked, the name shows in a plain, mouse-less frame; turned off it hides", function()
    local NS, mocks, inst = withLabel(1)
    local host = inst.label
    assertTrue(host ~= nil, "built on the first apply with the label on")
    assertTrue(host:IsShown(), "shown while locked")
    assertEqual(last(inst.labelText, "SetText")[1], NS.Database.FindContainer(1).name)
    assertTrue(#calls(inst.labelText, "SetFont") > 0, "the font is applied")
    assertFalse(last(host, "EnableMouse")[1], "it takes no mouse: the strip does the grabbing")
    assertEqual(#calls(host, "SetBackdrop"), 0, "never a backdrop (a secret size under an attached anchor)")
    assertFalse(last(inst.labelText, "SetWordWrap")[1], "one line")
    NS.SetByPath("container.label.show", false, 1)
    mocks.__fireTimers()
    assertFalse(host:IsShown())
end)

test("label: unlocked, the label AND the strip both show, the strip moved out past the label (D6)", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    local rec = recordPoints(inst.handle)
    NS.Anchors.UpdateHandle(inst, true)
    local before = rec[#rec]
    recordFrames(mocks)
    NS.SetByPath("container.label.show", true, 1)
    mocks.__fireTimers()
    -- red under: the old "the strip takes the label's place" rule
    assertTrue(inst.label:IsShown(), "the label shows while unlocked")
    assertTrue(inst.handle:IsShown(), "and so does the strip")
    local after = rec[#rec]
    assertEqual(after[1], before[1]); assertEqual(after[3], before[3])
    -- player buffs grow down: the strip sits above, so out past the label is further up
    assertEqual(after[5] - before[5], STRIP_H + STRIP_GAP, "pushed out by the label's height and the gap")
    assertEqual(after[4], before[4])
    NS.SetByPath("container.label.show", false, 1)
    mocks.__fireTimers()
    assertEqual(rec[#rec][5], before[5], "the label off, the strip comes back to the anchor")
end)

test("label: the strip's clamp reaches over the label too while both show", function()
    local NS, mocks, inst = withLabel(1)
    local insets = {}
    rawset(inst.anchor, "SetClampRectInsets", function(_, l, r, t, b) insets = { l, r, t, b } end)
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    -- red under: the clamp reaching over the strip's own height only
    assertEqual(insets[3], 2 * (STRIP_H + STRIP_GAP), "growing down, the top inset spans label and strip")
end)

test("label: test mode shows it, locked or not; visibility never, disabled and the stand-down hide it", function()
    local NS, mocks, inst = withLabel(1)
    NS.Preview.SetTestMode(true)
    mocks.__fireTimers()
    assertTrue(inst.label:IsShown(), "test mode while locked")
    NS.Preview.SetTestMode(false)
    NS.SetByPath("visibility", "never")
    mocks.__fireTimers()
    assertFalse(inst.label:IsShown(), "visibility never")
    NS.SetByPath("visibility", "always")
    mocks.__fireTimers()
    assertTrue(inst.label:IsShown())
    NS.SetByPath("container.enabled", false, 1)
    mocks.__fireTimers()
    assertFalse(inst.label:IsShown(), "a disabled container")
end)

test("label: Park and Destroy hide it", function()
    local _, _, inst = withLabel(1)
    inst:Park()
    assertFalse(inst.label:IsShown(), "parked")
    inst.label:Show()
    inst:Destroy()
    assertFalse(inst.label:IsShown(), "destroyed")
end)

test("label: a visibility pass under lockdown moves a placed label not at all; a never-placed one is placed once", function()
    local _, mocks, inst = withLabel(1)
    local n = #calls(inst.label, "SetPoint")
    mocks.__lockdown = true
    inst:ApplyVisibility()
    -- red under: placing the label on every visibility pass (layout work beside the engine in combat)
    assertEqual(#calls(inst.label, "SetPoint"), n, "no SetPoint on a placed label under lockdown")
    inst.label.placed = nil
    inst:ApplyVisibility()
    assertTrue(#calls(inst.label, "SetPoint") > n, "a never-placed label is placed on its first show")
    local m = #calls(inst.label, "SetPoint")
    inst:ApplyVisibility()
    assertEqual(#calls(inst.label, "SetPoint"), m, "and only once")
    mocks.__lockdown = false
end)

-- ── placement (NL-2) ──────────────────────────────────────────────────────────────────────────

-- An icons container (B9 E7): its label's default justify is toward the element, LEFT unless its
-- auras grow left. Bars and Text center it (the cases after this loop).
local GROWTHS = {
    { "right", "down", "BOTTOMLEFT", "TOPLEFT", STRIP_GAP, "LEFT" },
    { "left", "down", "BOTTOMRIGHT", "TOPRIGHT", STRIP_GAP, "RIGHT" },
    { "right", "up", "TOPLEFT", "BOTTOMLEFT", -STRIP_GAP, "LEFT" },
    { "left", "up", "TOPRIGHT", "BOTTOMRIGHT", -STRIP_GAP, "RIGHT" },
}

for _, g in ipairs(GROWTHS) do
    test(("label: growing %s and %s it sits where the strip does, plus its X/Y, text justified %s"):format(g[1], g[2], g[6]), function()
        local NS, mocks, inst = withLabel(1)
        NS.SetByPath("container.style", "icons", 1)
        NS.SetByPath("container.layout.growH", g[1], 1)
        NS.SetByPath("container.layout.growV", g[2], 1)
        NS.SetByPath("container.label.x", 5, 1)
        NS.SetByPath("container.label.y", -3, 1)
        mocks.__fireTimers()
        local away, toward, x, y = NS.Anchors.StripPoints(NS.Database.FindContainer(1))
        assertEqual(away, g[3]); assertEqual(toward, g[4]); assertEqual(x, 0); assertEqual(y, g[5])
        local p = lastPointOn(inst.label, inst.anchor)
        -- red under: the label at the anchor's own corner, or ignoring its offsets
        assertEqual(p[1], g[3]); assertEqual(p[3], g[4]); assertEqual(p[4], 5); assertEqual(p[5], g[5] - 3)
        assertEqual(last(inst.labelText, "SetJustifyH")[1], g[6])
        assertEqual(last(inst.label, "SetSize")[2], STRIP_H)
        -- the strip with no label shown sits on the same spot (placeHandle reads StripPoints)
        local rec = recordPoints(inst.handle)
        inst.labelShown = false
        NS.Anchors.UpdateHandle(inst, true)
        assertEqual(rec[#rec][1], g[3]); assertEqual(rec[#rec][3], g[4]); assertEqual(rec[#rec][5], g[5])
    end)
end

-- ── justify (B9 LJ-1, E7) ─────────────────────────────────────────────────────────────────────

--- The text's point on its host, and the justify it was given, after the last apply.
local function textPlacement(inst)
    local p = lastPointOn(inst.labelText, inst.label)
    return p, last(inst.labelText, "SetJustifyH")[1]
end

test("label justify: with no pick, Bars and Text center the name on its host, whatever the growth", function()
    for _, style in ipairs({ "bars", "text" }) do
        for _, growH in ipairs({ "right", "left" }) do
            local NS, mocks, inst = withLabel(1)
            NS.SetByPath("container.style", style, 1)
            NS.SetByPath("container.layout.growH", growH, 1)
            mocks.__fireTimers()
            local p, j = textPlacement(inst)
            local what = style .. " growing " .. growH
            -- red under: the old rule (justified toward the first element for every style)
            assertEqual(j, "CENTER", what)
            assertEqual(p[1], "CENTER", what); assertEqual(p[3], "CENTER", what); assertEqual(p[4], 0, what)
            assertEqual(NS.Anchors.LabelJustify(NS.Database.FindContainer(1)), "CENTER", what)
        end
    end
end)

test("label justify: a pick wins over the style default, Left and Right inset 4, Center none", function()
    local NS, mocks, inst = withLabel(1)
    local want = { LEFT = 4, RIGHT = -4, CENTER = 0 }
    for _, pick in ipairs({ "LEFT", "RIGHT", "CENTER" }) do
        assertTrue(NS.SetByPath("container.label.justifyH", pick, 1), pick)
        mocks.__fireTimers()
        local p, j = textPlacement(inst)
        -- red under: PlaceLabel ignoring the stored justify
        assertEqual(j, pick); assertEqual(p[1], pick); assertEqual(p[3], pick); assertEqual(p[4], want[pick], pick)
        assertEqual(NS.Database.FindContainer(1).label.justifyH, pick, "stored as picked")
    end
end)

test("label justify: an icons pick holds when the growth flips; AUTO goes back to the style default", function()
    local NS, mocks, inst = withLabel(1)
    NS.SetByPath("container.style", "icons", 1)
    NS.SetByPath("container.label.justifyH", "CENTER", 1)
    NS.SetByPath("container.layout.growH", "left", 1)
    mocks.__fireTimers()
    local _, j = textPlacement(inst)
    assertEqual(j, "CENTER", "the pick, not the growth's side")
    NS.SetByPath("container.label.justifyH", NS.Constants.LABEL_JUSTIFY_AUTO, 1)
    mocks.__fireTimers()
    _, j = textPlacement(inst)
    assertEqual(j, "RIGHT", "no pick again: icons growing left")
end)

test("label justify: LabelJustify answers the style default for nil, AUTO and an unknown stored value", function()
    local NS = fresh()
    local cfg = NS.Database.FindContainer(1)
    for _, v in ipairs({ false, "AUTO", "SIDEWAYS" }) do
        cfg.label.justifyH = v or nil
        -- red under: a stored value used without checking it is one of the three
        assertEqual(NS.Anchors.LabelJustify(cfg), "CENTER", tostring(v))
    end
    assertTrue(NS.Anchors.LabelJustify(nil) ~= nil, "no container: still an answer")
    assertFalse(NS.SetByPath("container.label.justifyH", "SIDEWAYS", 1), "the seam refuses an unknown value")
end)

--- Container 2 (icons) attached to container 1 (a column growing right and down), the label on 2,
--- unlocked.
local function follower()
    local NS, mocks = fresh()
    recordFrames(mocks)
    local L = NS.Database.FindContainer(1).layout
    L.axis, L.growH, L.growV = "vertical", "right", "down"
    NS.SetByPath("container.style", "icons", 2)
    NS.SetByPath("container.attach.container", 1, 2)
    NS.SetByPath("container.attach.mode", "container", 2)
    NS.SetByPath("container.label.show", true, 2)
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    return NS, mocks, NS.ContainerManager.instances[2]
end

test("label: a container attached to another puts its label on its own block's before side, like a root's; the strip moves out past it", function()
    local NS, _, inst = follower()
    local p = lastPointOn(inst.label, inst.anchor)
    -- red under: batch 9's label beside the first element (TOPRIGHT on TOPLEFT, far left of the column)
    assertEqual(p[1], "BOTTOMLEFT"); assertEqual(p[3], "TOPLEFT"); assertEqual(p[4], 0); assertEqual(p[5], STRIP_GAP)
    assertEqual(last(inst.labelText, "SetJustifyH")[1], "LEFT", "an icons label toward the element it names")
    local rec = recordPoints(inst.handle)
    NS.Anchors.UpdateHandle(inst, true)
    local h = rec[#rec]
    assertEqual(h[1], "BOTTOMLEFT"); assertEqual(h[3], "TOPLEFT")
    assertEqual(h[5], STRIP_GAP + STRIP_H + STRIP_GAP, "out past the label: strip, label, block")
end)

test("label: a follower's follower makes room for its own strip, not for its parent's label and strip", function()
    local NS, mocks = follower()
    NS.SetByPath("container.attach.x", 0, 3)
    NS.SetByPath("container.attach.y", 0, 3)
    NS.SetByPath("container.attach.container", 2, 3)
    NS.SetByPath("container.attach.mode", "container", 3)
    mocks.__fireTimers()
    local three = NS.ContainerManager.instances[3]
    local rec = {}
    rawset(three.anchor, "SetPoint", function(_, ...)
        local n = #rec
        rec[n + 1] = { ... }
    end)
    NS.Anchors.Place(three)
    local spacing = NS.Database.FindContainer(3).layout.spacing
    -- red under: batch 9's room for the parent's label and strip beside the seam
    assertEqual(rec[#rec][5], -(spacing + STRIP_H + STRIP_GAP), "its seam and its own strip's row")
end)

-- ── the name, the class color and the rest of the wiring ──────────────────────────────────────

test("label: a rename lands on the label at once, also under lockdown, with no apply queued", function()
    local NS, mocks, inst = withLabel(1)
    mocks.__lockdown = true
    NS.SetByPath("container.name", "Renamed Label", 1)
    -- red under: NotifyRenamed refreshing the strips alone
    assertEqual(last(inst.labelText, "SetText")[1], "Renamed Label")
    mocks.__lockdown = false
end)

test("label: Copy settings copies the label section and not the name; Everything includes it", function()
    local NS = fresh()
    local CM = NS.ContainerManager
    NS.SetByPath("container.label.show", true, 1)
    NS.SetByPath("container.label.x", 7, 1)
    local name2 = NS.Database.FindContainer(2).name
    assertTrue(CM.CopyFrom(1, 2, "label"))
    local c2 = NS.Database.FindContainer(2)
    assertTrue(c2.label.show); assertEqual(c2.label.x, 7); assertEqual(c2.name, name2)
    local found = false
    for _, k in ipairs(CM.COPY_SECTIONS) do found = found or k == "label" end
    assertTrue(found, "a copy section, so Everything takes it too")
    assertTrue(NS.IsSection("container.label"), "a whole section of the write seam")
end)

test("label: its class color makes a tracked container re-apply on a unit swap, only while the label shows", function()
    local NS = fresh()
    local cfg = NS.Database.FindContainer(1)
    cfg.label.font.useClassColorFont = true
    assertFalse(NS.Style.UsesClassColor(cfg), "the label off")
    cfg.label.show = true
    -- red under: UsesClassColor scanning the active style block alone
    assertTrue(NS.Style.UsesClassColor(cfg))
end)

test("label: ApplyFont paints an explicit class, falls back to the swatch for none, and keeps its three-argument path", function()
    local NS = fresh()
    local fs = { SetFont = function() return true end, SetShadowOffset = function() end,
        SetShadowColor = function() end }
    local got
    fs.SetTextColor = function(_, r, g, b, a) got = { r, g, b, a } end
    local t = { fontSize = 12, fontFlags = "OUTLINE", fontColor = { r = 1, g = 0.82, b = 0, a = 1 },
        useClassColorFont = true }
    NS.Style.ApplyFont(fs, t, t, { r = 0.1, g = 0.2, b = 0.3 })
    assertEqual(table.concat(got, ","), "0.1,0.2,0.3,1", "the tracked unit's class")
    NS.Style.ApplyFont(fs, t, t, { r = nil })
    assertEqual(table.concat(got, ","), "1,0.82,0,1", "an NPC: the swatch")
    t.useClassColorFont = false
    NS.Style.ApplyFont(fs, t, t)
    assertEqual(table.concat(got, ","), "1,0.82,0,1", "the old call is unchanged")
end)
