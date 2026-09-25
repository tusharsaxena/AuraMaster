-- tests/test_pages_layout.lua — settings/Layout.lua, driven through its widgets: the attach rows and
-- their cycle guard, the frame picker's two buttons, what a Growth or Frame row re-applies, and the
-- page's Defaults. How an attachment is resolved is tests/test_anchors.lua's.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")
local pages = dofile("tests/page_helpers.lua")

--- A fresh environment with the Layout page drawn and its Anchor tab open (Frame is the first tab,
--- so the attach rows are one click away). Answers what the Anchor tab drew.
local function layout(opts)
    local NS, m = fresh(opts)
    local P = pages(NS, m)
    P.show("Layout")
    return NS, m, P, P.tab("layout", NS.L["Anchor"])
end

--- The attach-target dropdown. The banner is labeled "Container" too, so it is excluded by identity.
local function targetDropdown(NS, P, ws)
    local banner = P.banner(NS.Helpers.__pageCtx.layout)
    for _, w in ipairs(P.all(ws, "Dropdown", NS.L["Container"])) do
        if w ~= banner then return w end
    end
    return nil
end

--- layout(), with container 1 attached in `mode` first, so the Anchor tab draws that mode's
--- subsections (feedback #4: the others are not drawn at all).
local function layoutIn(mode)
    local NS, m = fresh()
    NS.SetByPath("container.attach.mode", mode, 1)
    m.__fireTimers()
    local P = pages(NS, m)
    P.show("Layout")
    return NS, m, P, P.tab("layout", NS.L["Anchor"])
end

-- The Anchor tab's subsections and the rows each one holds, in drawing order.
local SUBSECTIONS = {
    { key = "Screen", paths = { "container.position.point", "container.position.relativePoint",
                                "container.position.x", "container.position.y" } },
    { key = "Another container", paths = { "container.attach.container", "container.attach.edge" } },
    { key = "Named frame", paths = { "container.attach.frame", "container.attach.point",
                                     "container.attach.relativePoint" } },
    { key = "Offset", paths = { "container.attach.x", "container.attach.y" } },
}

--- How many widgets a render drew under each label, the banner's excepted (it is a second
--- "Container" dropdown). Counts, because Screen and Named frame both have a Point and a Relative point.
local function drawnLabels(NS, P, ws)
    local banner = P.banner(NS.Helpers.__pageCtx.layout)
    local out = {}
    for _, w in ipairs(ws) do
        local label = w.labelText
        if w ~= banner and label then out[label] = (out[label] or 0) + 1 end
    end
    return out
end

--- The subsection headings a render drew, in order.
local function headingsOf(ws)
    local out = {}
    for _, w in ipairs(ws) do
        if w.type == "Heading" then
            local n = #out
            out[n + 1] = w.text
        end
    end
    return table.concat(out, ",")
end

--- Assert which subsections `mode` draws: each row label drawn exactly as many times as the `on`
--- subsections hold it (so a row of any other subsection is not drawn at all), and Attach to once.
local function assertShown(NS, P, ws, mode, on)
    local labels = drawnLabels(NS, P, ws)
    local want = {}
    for _, sub in ipairs(SUBSECTIONS) do
        for _, path in ipairs(sub.paths) do
            local label = NS.FindSchemaRow(path).label
            want[label] = (want[label] or 0) + (on[sub.key] and 1 or 0)
        end
    end
    for label, n in pairs(want) do
        assertEqual(labels[label] or 0, n, ("%s in %s mode"):format(label, mode))
    end
    assertEqual(labels[NS.L["Attach to"]], 1, "Attach to is always drawn")
end

local ON = {
    screen    = { Screen = true },
    container = { ["Another container"] = true, Offset = true },
    frame     = { ["Named frame"] = true, Offset = true },
}

test("layout: the tabs are Frame, Anchor, Growth, Mouse, Label, in that order", function()
    local NS, _, P = layout()
    local L = NS.L
    -- red under: the Position rows declared before the Frame rows (tab order is first-seen group order)
    assertEqual(table.concat(P.tabKeys("layout"), ","),
        table.concat({ L["Frame"], L["Anchor"], L["Growth"], L["Mouse"], L["Label"] }, ","))
end)

test("layout: the Label rows write the selected container's label, dimmed while it is off but the swatch (NL-4)", function()
    local NS, m, P = layout()
    local ws = P.tab("layout", NS.L["Label"])
    assertTrue(P.row(ws, "container.label.x").disabled, "X is dimmed while the label is off")
    assertTrue(P.row(ws, "container.label.font.fontSize").disabled, "and the font")
    assertFalse(P.row(ws, "container.label.font.fontColor").disabled and true or false, "a swatch is never grayed")
    P.row(ws, "container.label.show"):__fire("OnValueChanged", true)
    m.__fireTimers()
    P.tab("layout", NS.L["Frame"])
    ws = P.tab("layout", NS.L["Label"])
    assertFalse(P.row(ws, "container.label.x").disabled and true or false, "live once it is on")
    P.row(ws, "container.label.y"):__fire("OnMouseUp", 6)
    local c1 = NS.Database.FindContainer(1)
    assertTrue(c1.label.show); assertEqual(c1.label.y, 6)
    assertFalse(NS.Database.FindContainer(2).label.show, "another container is untouched")
end)

test("layout: Label > Justify shows the justify in effect with no pick, stores a pick, and Defaults clears it (B9 LJ-1)", function()
    local NS, m, P = layout()
    local L, AUTO = NS.L, NS.Constants.LABEL_JUSTIFY_AUTO
    NS.SetByPath("container.label.show", true, 1)
    m.__fireTimers()
    local ws = P.tab("layout", L["Label"])
    local dd = P.row(ws, "container.label.justifyH")
    -- red under: no Justify row on the Label tab
    assertTrue(dd ~= nil, "a Justify dropdown")
    assertEqual(table.concat(dd.order, ","), "LEFT,CENTER,RIGHT", "Left, Center, Right and nothing else")
    -- red under: the panel showing the stored AUTO (a blank dropdown) instead of what is in effect
    assertEqual(dd.value, "CENTER", "container 1 draws as Bars: centered")
    assertEqual(NS.GetSetting("container.label.justifyH", 1), AUTO, "while nothing is picked")
    dd:__fire("OnValueChanged", "RIGHT")
    m.__fireTimers()
    assertEqual(NS.Database.FindContainer(1).label.justifyH, "RIGHT")
    NS.SetByPath("container.label.justifyH", AUTO, 1)
    NS.SetByPath("container.style", "icons", 1)
    NS.SetByPath("container.layout.growH", "left", 1)
    m.__fireTimers()
    P.tab("layout", L["Frame"])
    ws = P.tab("layout", L["Label"])
    assertEqual(P.row(ws, "container.label.justifyH").value, "RIGHT", "icons growing left, no pick")
    NS.SetByPath("container.label.justifyH", "CENTER", 1)
    -- red under: the row with no default (Defaults could never go back to the style's own)
    assertTrue(NS.ApplyDefault(NS.FindSchemaRow("container.label.justifyH")))
    assertEqual(NS.Database.FindContainer(1).label.justifyH, AUTO, "the reset is back to no pick")
end)

test("layout: the Label Justify row is dimmed while the label is off", function()
    local NS, _, P = layout()
    local ws = P.tab("layout", NS.L["Label"])
    assertTrue(P.row(ws, "container.label.justifyH").disabled)
end)

test("layout: the Anchor tab draws only the chosen mode's subsections, each under its heading (feedback #4)", function()
    local L = T.NS.L
    local want = {
        screen    = L["Screen"],
        container = L["Another container"] .. "," .. L["Offset"],
        frame     = L["Named frame"] .. "," .. L["Offset"],
    }
    for mode, heads in pairs(want) do
        local _, _, _, ws = layoutIn(mode)
        -- red under: the rows without shownWhen (every subsection drawn, dimmed), or a hidden
        -- subsection's heading drawn over nothing
        assertEqual(headingsOf(ws), heads, mode)
    end
end)

test("layout: Pick a frame sits beside Frame name in Named frame, and there is no Attach to the screen", function()
    local NS, _, P, ws = layoutIn("frame")
    local box = P.row(ws, "container.attach.frame")
    local line
    for _, w in ipairs(ws) do
        if w.children and w.children[1] == box then line = w end
    end
    assertTrue(line ~= nil, "Frame name is on a line of its own group")
    local pick = line.children[2]
    -- red under: Pick drawn by an afterGroup (its own line after Offset) instead of paired with Frame name
    assertTrue(pick ~= nil and pick.type == "Button" and pick.text == NS.L["Pick a frame..."],
        "Pick a frame... is Frame name's right half")
    -- red under: the redundant Attach to the screen button still drawn (the dropdown does the same)
    assertEqual(P.find(ws, "Button", "Attach to the screen"), nil)
end)

for _, mode in ipairs({ "screen", "container", "frame" }) do
    test("layout: in " .. mode .. " mode only the subsections that apply are drawn (feedback #4)", function()
        local NS, _, P = layout()
        NS.SetByPath("container.attach.mode", mode, 1)
        local ws = P.rerender("Layout")
        -- red under: a subsection's rows without their shownWhen, or naming the wrong mode
        assertShown(NS, P, ws, mode, ON[mode])
        -- Pick a frame is Frame name's partner, so it is drawn with Named frame alone.
        assertEqual(P.find(ws, "Button", NS.L["Pick a frame..."]) ~= nil, mode == "frame", "Pick a frame...")
    end)
end

test("layout: changing Attach to redraws the tab on the next frame with the chosen subsections (feedback #4)", function()
    local NS, m, P, ws = layout()
    NS.Helpers.__pageCtx.layout.panel:Show()
    assertShown(NS, P, ws, "screen", ON.screen)
    local during = P.during(function() P.row(ws, "container.attach.mode"):__fire("OnValueChanged", "frame") end)
    -- red under: the tab redrawn inside the dropdown's own callback (it would release the dropdown)
    assertEqual(#during, 0, "nothing drawn inside the callback")
    local redrawn = P.during(function() m.__fireTimers() end)
    -- red under: no selector watch (the tab keeps showing the Screen rows)
    assertShown(NS, P, redrawn, "frame", ON.frame)
    redrawn = P.during(function()
        P.row(redrawn, "container.attach.mode"):__fire("OnValueChanged", "container")
        m.__fireTimers()
    end)
    assertShown(NS, P, redrawn, "container", ON.container)
end)

test("layout: Attach to writes the mode and redraws an open page on the next frame", function()
    local NS, m, P, ws = layout()
    NS.Helpers.__pageCtx.layout.panel:Show()
    local dd = P.row(ws, "container.attach.mode")
    assertEqual(table.concat(dd.order, ","), "screen,container,frame")
    dd:__fire("OnValueChanged", "container")
    assertEqual(NS.Database.FindContainer(1).attach.mode, "container")
    local redrawn = P.during(function() m.__fireTimers() end)
    -- red under: the mode row's rows without shownWhen (nothing watches the selector, so a scalar
    -- refresh draws nothing new)
    assertTrue(#redrawn > 0, "the page was drawn again")
end)

test("layout: the Container dropdown offers None and every other container, never the selected one", function()
    local NS, m, P = layout()
    NS.SetByPath("container.attach.mode", "container", 2)
    m.__fireTimers()
    NS.Helpers.SelectContainer(2)
    local ws = P.show("Layout")
    local dd = targetDropdown(NS, P, ws)
    -- red under: attachTargets listing the selected container (a container attached to itself)
    -- None first, then by name (B2-2): Player buffs, Player cooldowns, Target debuffs (mine)
    assertEqual(table.concat(dd.order, ","), "0,1,4,3")
    assertEqual(dd.list[0], NS.L["None"])
    assertEqual(dd.list[3], "Target debuffs (mine)")
    -- Mixed case (B2-2), written straight to the store: red under a byte sort (Zeta, alpha, beta)
    local cs = NS.db.profile.containers
    cs[1].name, cs[3].name, cs[4].name = "beta", "Zeta", "alpha"
    dd = targetDropdown(NS, P, P.rerender("Layout"))
    assertEqual(table.concat(dd.order, ","), "0,4,1,3")
end)

test("layout: a target that would close a loop is refused; any other, or None, is stored", function()
    local NS, _, P, ws = layoutIn("container")
    -- 2 follows 1, attached with 2 selected: the row's cycle check reads the selection.
    NS.State.SetActiveContainer(2)
    NS.SetByPath("container.attach.container", 1)
    NS.SetByPath("container.attach.mode", "container")
    NS.State.SetActiveContainer(1)
    assertEqual(NS.Database.FindContainer(2).attach.container, 1, "the setup attachment held")
    local dd = targetDropdown(NS, P, ws)
    dd:__fire("OnValueChanged", 2)
    -- red under: dropping the row's WouldCycle validate (1 follows 2 follows 1)
    assertEqual(NS.Database.FindContainer(1).attach.container, 0, "the loop was refused")
    -- 4 flows as 1 does, so no growth-conflict popup (GC-1) stands between the pick and the store.
    dd:__fire("OnValueChanged", 4)
    assertEqual(NS.Database.FindContainer(1).attach.container, 4)
    dd:__fire("OnValueChanged", 0)
    assertEqual(NS.Database.FindContainer(1).attach.container, 0, "None is always allowed")
end)

test("layout: Frame name stores the typed name for the selected container", function()
    local NS, _, P, ws = layoutIn("frame")
    local box = P.row(ws, "container.attach.frame")
    assertEqual(box.type, "EditBox")
    box:__fire("OnEnterPressed", "PlayerFrame")
    -- red under: the frame row writing any container but the selection
    assertEqual(NS.Database.FindContainer(1).attach.frame, "PlayerFrame")
    assertEqual(NS.Database.FindContainer(2).attach.frame, "")
end)

test("layout: Pick a frame in combat refuses in gray and starts nothing", function()
    local NS, m, P, ws = layoutIn("frame")
    local started = 0
    NS.FramePicker.Start = function() started = started + 1 end
    local lines = P.chat()
    m.__lockdown = true
    P.find(ws, "Button", NS.L["Pick a frame..."]):__fire("OnClick")
    -- red under: pickFrame without its InCombatLockdown gate
    assertEqual(started, 0)
    assertEqual(m.__settingsClosed, 0, "the settings stay open")
    assertEqual(#lines, 1)
    assertTrue(lines[1]:find("|cff808080cannot pick a frame during combat", 1, true) ~= nil, lines[1])
end)

test("layout: a pick attaches the container selected when it began, and reopens the page", function()
    local NS, m, P, ws = layoutIn("frame")
    local onPick, onCancel
    NS.FramePicker.Start = function(pick, cancel) onPick, onCancel = pick, cancel end
    local opened = {}
    NS.OpenOptionsPage = function(page)
        opened[#opened + 1] = page
    end
    P.find(ws, "Button", NS.L["Pick a frame..."]):__fire("OnClick")
    assertEqual(m.__settingsClosed, 1, "the settings window got out of the way")
    assertTrue(onPick ~= nil, "the picker started")
    NS.State.SetActiveContainer(2)   -- the selection moves while the player is picking
    onPick("TargetFrame")
    -- red under: the pick writing the active container instead of the one it was started for
    local c1 = NS.Database.FindContainer(1)
    assertEqual(c1.attach.frame, "TargetFrame")
    assertEqual(c1.attach.mode, "frame")
    assertEqual(NS.Database.FindContainer(2).attach.mode, "screen")
    assertEqual(opened[1], "layout")
    onCancel()
    assertEqual(opened[2], "layout", "a cancel also brings the player back")
end)

test("layout: a Growth write re-applies only the selected container", function()
    local NS, _, P = layout()
    NS.Helpers.SelectContainer(2)
    P.show("Layout")
    local ws = P.tab("layout", NS.L["Growth"])
    local calls = {}
    local real = NS.ContainerManager.RequestApply
    NS.ContainerManager.RequestApply = function(id, ...)
        calls[#calls + 1] = id
        return real(id, ...)
    end
    local slider = P.row(ws, "container.layout.spacing")
    assertEqual(slider.type, "Slider")
    slider:__fire("OnMouseUp", 6)
    -- red under: the row carrying an effect that skips the apply, or resolving the wrong container
    assertEqual(NS.Database.FindContainer(2).layout.spacing, 6)
    assertEqual(#calls, 1)
    assertEqual(calls[1], 2)
end)

test("layout: Strata offers the five layers in order and stores the one chosen", function()
    local NS, _, P = layout()
    P.show("Layout")
    local ws = P.tab("layout", NS.L["Frame"])
    local dd = P.row(ws, "container.layout.strata")
    assertEqual(table.concat(dd.order, ","), table.concat(NS.Constants.STRATA, ","))
    assertEqual(dd.value, "MEDIUM")
    dd:__fire("OnValueChanged", "DIALOG")
    -- red under: the strata row writing any path but layout.strata
    assertEqual(NS.Database.FindContainer(1).layout.strata, "DIALOG")
end)

test("layout: the Mouse tab's rows write the selected container's behavior", function()
    local NS, _, P = layout()
    P.show("Layout")
    local ws = P.tab("layout", NS.L["Mouse"])
    P.row(ws, "container.behavior.clickThrough"):__fire("OnValueChanged", true)
    P.row(ws, "container.behavior.tooltipAnchor"):__fire("OnValueChanged", "ANCHOR_CURSOR")
    local b = NS.Database.FindContainer(1).behavior
    -- red under: a Mouse row pointing at another section
    assertTrue(b.clickThrough)
    assertEqual(b.tooltipAnchor, "ANCHOR_CURSOR")
    assertFalse(NS.Database.FindContainer(2).behavior.clickThrough)
end)

test("layout: Defaults restores the selected container's placement and arrangement, and not its look", function()
    local NS, _ = layout()
    NS.SetByPath("container.layout.spacing", 9, 1)
    NS.SetByPath("container.attach.mode", "frame", 1)
    NS.SetByPath("container.bars.width", 300, 1)
    NS.SetByPath("container.layout.spacing", 9, 2)
    NS.State.SetActiveContainer(1)
    NS.Helpers.__pageCtx.layout.panel.defaultsOnClick()
    local c1 = NS.Database.FindContainer(1)
    -- red under: the Defaults button resetting another page's rows, or another container
    assertEqual(c1.layout.spacing, NS.CONTAINER_TEMPLATE.layout.spacing)
    assertEqual(c1.attach.mode, "screen")
    assertEqual(c1.bars.width, 300, "a Bars row is not a Layout row")
    assertEqual(NS.Database.FindContainer(2).layout.spacing, 9)
end)

test("layout: after the banner moves, the page draws the newly selected container's values", function()
    local NS, _, P = layout()
    NS.SetByPath("container.layout.scale", 1.5, 3)
    P.show("Layout")
    local ws = P.tab("layout", NS.L["Frame"])
    assertEqual(P.row(ws, "container.layout.scale").value, 1, "container 1's scale")
    P.banner(NS.Helpers.__pageCtx.layout):__fire("OnValueChanged", 3)
    ws = P.show("Layout")
    -- red under: the page caching the container it first drew, or losing its tab on the switch
    assertEqual(NS.Helpers.__pageCtx.layout.activeTab, NS.L["Frame"], "the tab survives the switch")
    assertEqual(P.row(ws, "container.layout.scale").value, 1.5)
end)

-- ── inherited flow (L-6) ──────────────────────────────────────────────────────────────────────

--- Container 2 attached to container 1, whose flow (columns growing right and up) differs from 2's
--- own (rows growing left and down) on every inherited row; 2 selected and the Layout page drawn.
local function attachedChild()
    local NS, m, P = layout()
    NS.SetByPath("container.layout.growV", "up", 1)
    NS.SetByPath("container.attach.container", 1, 2)
    NS.SetByPath("container.attach.mode", "container", 2)
    NS.Helpers.SelectContainer(2)
    P.show("Layout")
    return NS, m, P
end

local INHERITED = { axis = "vertical", growH = "right", growV = "up" }

test("layout: an attached container's Fill and growth are dimmed and show its parent's", function()
    local NS, _, P = attachedChild()
    local ws = P.tab("layout", NS.L["Growth"])
    for key, want in pairs(INHERITED) do
        local w = P.row(ws, "container.layout." .. key)
        -- red under: the inherited rows without their disabledIf
        assertTrue(w.disabled, key .. " is dimmed")
        -- red under: the panel descriptor reading the stored value instead of the row's panelGet
        assertEqual(w.value, want, key .. " shows the parent's value")
    end
    for _, key in ipairs({ "perLine", "spacing", "lineSpacing" }) do
        -- red under: dimming every Growth row (per row and spacing stay the child's own)
        assertFalse(P.row(ws, "container.layout." .. key).disabled and true or false, key .. " stays live")
    end
    -- red under: the Growth tab without its follow line
    assertTrue(P.hasText(ws, NS.L["Fill and growth follow '%s' because this container is attached to it."]:format("Player buffs")), "the follow line")
    -- red under: panelGet reached by every reader (/am get and the apply path read what is stored)
    assertEqual(NS.GetSetting("container.layout.axis"), "horizontal")
    assertEqual(NS.Database.FindContainer(2).layout.growH, "left")
end)

test("layout: a screen or frame container's growth rows are its own and live, with no follow line", function()
    for _, mode in ipairs({ "screen", "frame" }) do
        local NS, _, P = attachedChild()
        NS.SetByPath("container.attach.mode", mode, 2)
        P.show("Layout")
        local ws = P.tab("layout", NS.L["Growth"])
        local axis = P.row(ws, "container.layout.axis")
        -- red under: the inherited-row predicate dimming every attached mode
        assertFalse(axis.disabled and true or false, mode .. ": Fill is live")
        assertEqual(axis.value, "horizontal", mode .. ": 2's own rows")
        assertFalse(P.hasText(ws, NS.L["Fill and growth follow '%s' because this container is attached to it."]:format("Player buffs")), mode .. ": no line")
    end
end)

test("layout: the follow line is dim gold, says why, and has a gap below it (F6)", function()
    local NS, _, P = attachedChild()
    local H = NS.Helpers
    P.tab("layout", NS.L["Growth"])
    local want = "|c" .. NS.Constants.SECONDARY_GOLD
        .. NS.L["Fill and growth follow '%s' because this container is attached to it."]:format("Player buffs") .. "|r"
    -- red under: the gold as the addon's muted secondary gold, not the bright heading gold
    assertEqual(NS.Constants.SECONDARY_GOLD, "ffd9b861")
    local kids = H.EnsureScroll(H.__pageCtx.layout).children
    local at
    for i, w in ipairs(kids) do
        if w.type == "Label" and w.text == want then at = i end
    end
    -- red under: the line drawn plain, or in the old words without the reason
    assertTrue(at ~= nil, "the follow line in dim gold")
    local spacer = kids[at + 1]
    -- red under: the line followed straight by the first Growth row
    assertEqual(spacer and spacer.type, "SimpleGroup")
    assertEqual(spacer and spacer.height, H.ROW_VSPACER)
end)

test("layout: the follow line is drawn on the Growth tab only", function()
    local NS, _, P = attachedChild()
    local line = NS.L["Fill and growth follow '%s' because this container is attached to it."]:format("Player buffs")
    for _, key in ipairs({ NS.L["Frame"], NS.L["Anchor"], NS.L["Mouse"] }) do
        local ws = (NS.Helpers.__pageCtx.layout.activeTab == key) and P.rerender("Layout") or P.tab("layout", key)
        assertTrue(#ws > 0, key .. " drew")
        -- red under: the intro drawn above every tab
        assertFalse(P.hasText(ws, line), key .. " carries no follow line")
    end
    assertTrue(P.hasText(P.tab("layout", NS.L["Growth"]), line), "Growth does")
end)

test("layout: Another container names the derived points and the container it is attached to", function()
    local NS, m, P = attachedChild()
    -- layout() opened the Anchor tab and the show kept it, and a click on the active tab draws
    -- nothing: draw it again instead.
    assertEqual(NS.Helpers.__pageCtx.layout.activeTab, NS.L["Anchor"])
    local ws = P.rerender("Layout")
    assertTrue(#ws > 0, "the Anchor tab drew")
    local PL = NS.Constants.POINT_LABELS
    local want = NS.L["Its %s joins the %s of '%s'"]
    -- 1 fills columns growing right and up: 2 sits on top of it.
    -- red under: the Container dropdown without its pairWith line
    assertTrue(P.hasText(ws, want:format(PL.BOTTOMLEFT, PL.TOPLEFT, "Player buffs")), "the derived line")
    NS.Helpers.__pageCtx.layout.panel:Show()   -- a hidden kit panel only marks itself dirty
    -- 2's own flow made 3's (rows growing right and down), so no growth-conflict popup (GC-1) stands
    -- between the pick and the store.
    NS.SetByPath("container.layout.growH", "right", 2)
    -- Run any refresh the setup queued now, so the only one left to run is the target row's own.
    local settled = P.during(function() m.__fireTimers() end)
    local settledCount = #settled
    local dd = targetDropdown(NS, P, (settledCount > 0) and settled or ws)
    dd:__fire("OnValueChanged", 3)
    -- red under: the target row without its structural onChange (the line would name the old target)
    local redrawn = P.during(function() m.__fireTimers() end)
    assertTrue(P.hasText(redrawn, want:format(PL.TOPLEFT, PL.BOTTOMLEFT, "Target debuffs (mine)")),
        "3 fills rows growing right and down: 2 stacks below it")
    NS.SetByPath("container.attach.mode", "frame", 2)
    ws = P.during(function() NS.Helpers.RefreshAllPanels() end)
    assertTrue(#ws > 0, "the open page drew again")
    -- red under: the line drawn for a container that follows nothing
    assertFalse(P.hasText(ws, "Target debuffs (mine)"), "no line outside container mode")
end)

-- ── the Side row (batch 9 AP-3, E2) ────────────────────────────────────────────────────────────

--- The Side dropdown the Anchor tab drew for container 2 attached to 1 (growing right and up, one
--- column), with 2 one aura wide and on `edge`.
local function sideRow(edge)
    local NS, m, P = attachedChild()
    NS.SetByPath("container.layout.perLine", 0, 2)
    if edge then NS.SetByPath("container.attach.edge", edge, 2) end
    m.__fireTimers()
    local ws = P.rerender("Layout")
    return NS, m, P, P.row(ws, "container.attach.edge"), ws
end

test("layout: Side lists every allowed side by its absolute name for the chain's growth", function()
    local NS, _, _, dd = sideRow()
    -- red under: no Side row (AP-3)
    assertTrue(dd ~= nil, "the Side row is drawn in container mode")
    assertEqual(table.concat(dd.order, ","), table.concat(NS.Anchors.EDGES, ","), "one wide: all nine")
    -- 1 grows right and up, so after is the top and lines start from the left.
    assertEqual(dd.list["after-start"], NS.L["Top left"])
    assertEqual(dd.list["after-center"], NS.L["Top"])
    assertEqual(dd.list["after-end"], NS.L["Top right"])
    assertEqual(dd.list["ahead-start"], NS.L["Right, bottom"])
    assertEqual(dd.list["ahead-center"], NS.L["Right, middle"])
    assertEqual(dd.list["behind-end"], NS.L["Left, top"])
end)

test("layout: Side names mirror with the chain's growth, and no entry names the side it grows away from", function()
    for _, g in ipairs({ { "right", "down" }, { "left", "down" }, { "right", "up" }, { "left", "up" } }) do
        local NS, m, P = attachedChild()
        NS.SetByPath("container.layout.perLine", 0, 2)
        NS.SetByPath("container.layout.growH", g[1], 1)
        NS.SetByPath("container.layout.growV", g[2], 1)
        m.__fireTimers()
        local dd = P.row(P.rerender("Layout"), "container.attach.edge")
        local what = g[1] .. "/" .. g[2]
        local away = (g[2] == "down") and "Top" or "Bottom"
        local startSide = (g[1] == "right") and "left" or "right"
        -- red under: labels fixed to one growth
        assertEqual(dd.list["after-start"], NS.L[((g[2] == "down") and "Bottom " or "Top ") .. startSide], what)
        for _, v in ipairs(dd.order) do
            assertFalse(dd.list[v]:find("^" .. away) ~= nil, what .. ": " .. dd.list[v])
        end
    end
end)

test("layout: Side offers no behind entry to a child more than one aura wide", function()
    local NS, _, P = sideRow("after-start")
    NS.SetByPath("container.layout.perLine", 3, 2)
    local dd = P.row(P.rerender("Layout"), "container.attach.edge")
    -- red under: an unfiltered list
    assertEqual(table.concat(dd.order, ","),
        "after-start,after-center,after-end,ahead-start,ahead-center,ahead-end")
end)

test("layout: a stored side not allowed now stays listed as unavailable, with a note saying where the child sits", function()
    local NS, _, P = sideRow("behind-start")
    NS.SetByPath("container.layout.perLine", 3, 2)
    local ws = P.rerender("Layout")
    local dd = P.row(ws, "container.attach.edge")
    local n = #dd.order
    -- red under: a stored value missing from the list (the dropdown would show blank)
    assertEqual(dd.order[n], "behind-start")
    assertTrue(dd.list["behind-start"]:find(NS.L[" (unavailable)"], 1, true) ~= nil, dd.list["behind-start"])
    local note = NS.L["'%s' needs this container to be one aura wide (Fill: Columns, Per row or column: 0). It sits %s until then."]
        :format(NS.L["Left, bottom"], NS.L["Top left"])
    -- red under: no edgeFallbackNote
    assertTrue(P.hasText(ws, note), "the fallback note")
    NS.SetByPath("container.layout.perLine", 0, 2)
    ws = P.rerender("Layout")
    assertFalse(P.hasText(ws, note), "back to one wide: no note")
end)

test("layout: the attachment line names the chosen side's points", function()
    local NS, _, P = sideRow("ahead-center")
    local ws = P.rerender("Layout")
    local PL = NS.Constants.POINT_LABELS
    -- red under: attachedText reading the old fixed points
    assertTrue(P.hasText(ws, NS.L["Its %s joins the %s of '%s'"]:format(PL.LEFT, PL.RIGHT, "Player buffs")))
end)

-- ── the Point rows and the facing-growth hint (smoke feedback 2, item 1, D-3) ────────────────────

test("layout: every Point and Relative point row places the first aura, since the container's full size is secret", function()
    local NS = T.NS
    for _, path in ipairs({ "container.position.point", "container.position.relativePoint",
                            "container.attach.point", "container.attach.relativePoint" }) do
        -- red under: the old wording ("the corner of this container that is attached")
        assertTrue(NS.FindSchemaRow(path).desc:find("first aura", 1, true) ~= nil, path)
    end
    assertTrue(NS.FindSchemaRow("container.attach.point").desc:find("secret", 1, true) ~= nil,
        "Point says why the container itself cannot be anchored")
end)

--- The Anchor tab of container 1 in Named frame mode with its Point and growth set: whether it drew
--- the facing-growth hint, and the widgets it drew.
local function hintFor(point, growH, growV, mode)
    local NS, _, P = layoutIn(mode or "frame")
    NS.SetByPath("container.attach.point", point, 1)
    NS.SetByPath("container.position.point", point, 1)
    NS.SetByPath("container.layout.growH", growH, 1)
    NS.SetByPath("container.layout.growV", growV, 1)
    local ws = P.rerender("Layout")
    assertTrue(#ws > 0, "the Anchor tab drew")
    return P.hasText(ws, "grow back over"), ws, NS, P
end

test("layout: the facing-growth hint shows exactly when Point's side and the growth point at each other", function()
    local cases = {
        -- vertical: a BOTTOM point sits above the frame, a TOP point below it
        { "BOTTOMLEFT", "right", "down", true }, { "BOTTOM", "right", "down", true },
        { "BOTTOMRIGHT", "left", "down", true }, { "TOP", "right", "up", true },
        { "TOPRIGHT", "left", "up", true },
        { "BOTTOMLEFT", "right", "up", false }, { "TOPLEFT", "right", "down", false },
        { "BOTTOMRIGHT", "left", "up", false },
        -- horizontal: a LEFT point sits right of the frame, a RIGHT point left of it
        { "LEFT", "left", "down", true }, { "RIGHT", "right", "down", true },
        { "TOPLEFT", "left", "down", true }, { "BOTTOMRIGHT", "right", "up", true },
        { "LEFT", "right", "down", false }, { "RIGHT", "left", "up", false },
        -- CENTER has no side
        { "CENTER", "right", "down", false }, { "CENTER", "left", "up", false },
    }
    for _, c in ipairs(cases) do
        local shown = hintFor(c[1], c[2], c[3])
        -- red under: the hint missing, or its side test inverted or on the wrong axis
        assertEqual(shown, c[4], ("%s growing %s/%s"):format(c[1], c[2], c[3]))
    end
end)

test("layout: the hint names the growth to pick instead, one line per facing axis", function()
    local L = T.NS.L
    local PL, GV, GH = T.NS.Constants.POINT_LABELS, T.NS.Constants.GROW_V_LABELS, T.NS.Constants.GROW_H_LABELS
    local V = L["Point is %s and Grow vertically is %s, so the auras grow back over the frame this container is attached to. Set Grow vertically to %s on the Growth tab instead."]
    local H = L["Point is %s and Grow horizontally is %s, so the auras grow back over the frame this container is attached to. Set Grow horizontally to %s on the Growth tab instead."]
    local _, ws, _, P = hintFor("BOTTOMLEFT", "left", "down")
    -- red under: one combined line, or the growth to pick named wrong
    assertTrue(P.hasText(ws, V:format(PL.BOTTOMLEFT, GV.down, GV.up)), "the vertical line")
    assertTrue(P.hasText(ws, H:format(PL.BOTTOMLEFT, GH.left, GH.right)), "the horizontal line")
    _, ws = hintFor("TOP", "right", "up")
    assertTrue(P.hasText(ws, V:format(PL.TOP, GV.up, GV.down)))
    assertFalse(P.hasText(ws, "Grow horizontally is"), "no horizontal line for a point with no side")
end)

test("layout: the hint is Named frame's alone — the screen has no frame to grow over, and a follower's points are derived", function()
    for _, mode in ipairs({ "screen", "container" }) do
        -- red under: the hint drawn in every attach mode
        assertFalse((hintFor("BOTTOMLEFT", "right", "down", mode)), mode)
    end
end)

test("layout: choosing a facing Point redraws the tab with the hint on the next frame", function()
    local NS, m, P, ws = layoutIn("frame")
    NS.Helpers.__pageCtx.layout.panel:Show()
    P.during(function() m.__fireTimers() end)
    assertFalse(P.hasText(ws, "grow back over"), "the default Top left point grows away from the frame")
    P.row(ws, "container.attach.point"):__fire("OnValueChanged", "BOTTOMLEFT")
    local redrawn = P.during(function() m.__fireTimers() end)
    -- red under: Point without its structural onChange (the tab keeps its old hint state)
    assertTrue(P.hasText(redrawn, "grow back over"))
end)

test("layout: the Container row's help points at the Side row, not at points set for you (batch 9 AP-3)", function()
    local NS = fresh()
    local desc = NS.FindSchemaRow("container.attach.container").desc
    -- red under: the pre-batch-9 help, which says the points are chosen for the player
    assertTrue(desc:find("points are set for you", 1, true) == nil, desc)
    assertTrue(desc:find(NS.L["Side"], 1, true) ~= nil, desc)
end)

-- ── growth conflicts on attach (batch 9 GC-1, E3) ─────────────────────────────────────────────

--- Container 2 (rows growing left and down) in container mode with no target yet, selected, the
--- Layout page drawn on its Anchor tab and open; popups recorded. Answers what the tab drew too.
local function conflictPage()
    local NS, m, P = layout()
    NS.SetByPath("container.attach.mode", "container", 2)
    m.__fireTimers()
    NS.Helpers.SelectContainer(2)
    local ws = P.show("Layout")
    NS.Helpers.__pageCtx.layout.panel:Show()
    m.__fireTimers()
    return NS, m, P, ws, P.popups()
end

--- The popup text for 2 attaching to 1: 1 fills columns growing right.
local function promptFor(NS, followers)
    local L, C = NS.L, NS.Constants
    local flow = L["Fill"] .. ": " .. L[C.AXIS_LABELS.vertical] .. ", "
        .. L["Grow horizontally"] .. ": " .. L[C.GROW_H_LABELS.right]
    local text = L["Attach '%s' to '%s'? '%s' will fill and grow like '%s' (%s). Its own Growth settings are kept and come back if you detach it."]
        :format("Player debuffs", "Player buffs", "Player debuffs", "Player buffs", flow)
    if followers then text = text .. L[" %d container(s) attached to it follow too."]:format(followers) end
    return text
end

test("layout: a Container pick whose chain flows differently asks first and stores nothing (GC-1)", function()
    local NS, m, P, ws, popups = conflictPage()
    targetDropdown(NS, P, ws):__fire("OnValueChanged", 1)
    -- red under: no confirmWrite intercept (the write is stored at once)
    assertEqual(#popups, 1, "one popup")
    assertEqual(popups[1].which, "AURAMASTER_ATTACH_FLOW")
    assertEqual(popups[1].text, promptFor(NS), "names both, and the flow it takes")
    assertEqual(NS.Database.FindContainer(2).attach.container, 0, "nothing stored yet")
    local data = popups[1].data
    assertEqual(data.path .. "|" .. tostring(data.value) .. "|" .. tostring(data.id), "container.attach.container|1|2")
    -- red under: no refresh (the dropdown would keep showing the unconfirmed pick)
    local redrawn = P.during(function() m.__fireTimers() end)
    assertTrue(#redrawn > 0, "the page is drawn again, back on the stored value")
    assertEqual(P.row(redrawn, "container.attach.mode").value, "container")
end)

test("layout: accepting the attach popup attaches and keeps the child's own Growth settings (E3)", function()
    local NS, m, _, ws, popups = conflictPage()
    local P = pages(NS, m)
    local chat = P.chat()
    targetDropdown(NS, P, ws):__fire("OnValueChanged", 1)
    local dialog = m.StaticPopupDialogs.AURAMASTER_ATTACH_FLOW
    -- red under: no AURAMASTER_ATTACH_FLOW dialog
    assertEqual(dialog.button1, NS.L["Attach"])
    assertEqual(dialog.button2, NS.L["Cancel"])
    dialog.OnAccept(popups[1], popups[1].data)
    local cfg = NS.Database.FindContainer(2)
    assertEqual(cfg.attach.container, 1, "attached")
    assertEqual(cfg.layout.axis .. cfg.layout.growH, "horizontalleft", "its own flow is kept")
    assertEqual(NS.Anchors.FlowRoot(cfg).id, 1, "and it follows 1")
    -- red under: the /am set chat line printed for a write the player just confirmed
    assertEqual(#chat, 0, "the popup said it; no chat line")
end)

test("layout: canceling the attach popup stores nothing, and accepting it in combat is refused", function()
    local NS, m, P, ws, popups = conflictPage()
    targetDropdown(NS, P, ws):__fire("OnValueChanged", 1)
    local dialog = m.StaticPopupDialogs.AURAMASTER_ATTACH_FLOW
    m.__fireTimers()
    dialog.OnCancel(popups[1], popups[1].data)
    assertEqual(NS.Database.FindContainer(2).attach.container, 0, "cancel stores nothing")
    local redrawn = P.during(function() m.__fireTimers() end)
    assertTrue(#redrawn > 0, "cancel redraws the page")
    local chat = P.chat()
    m.__lockdown = true
    dialog.OnAccept(popups[1], popups[1].data)
    -- red under: OnAccept without its InCombatLockdown gate
    assertEqual(NS.Database.FindContainer(2).attach.container, 0, "refused in combat")
    assertEqual(#chat, 1, "one refusal")
    assertTrue(chat[1]:find("|cff808080", 1, true) ~= nil, "gray: " .. chat[1])
    m.__lockdown = false
end)

test("layout: the attach popup counts the containers attached to the child", function()
    local NS, _, P, ws, popups = conflictPage()
    NS.SetByPath("container.attach.container", 2, 3)
    NS.SetByPath("container.attach.mode", "container", 3)
    targetDropdown(NS, P, ws):__fire("OnValueChanged", 1)
    -- red under: the followers sentence left out
    assertEqual(popups[1].text, promptFor(NS, 1))
end)

test("layout: no popup when the flow matches, for None, or outside container mode", function()
    local NS, m, P, ws, popups = conflictPage()
    local dd = targetDropdown(NS, P, ws)
    dd:__fire("OnValueChanged", 0)
    assertEqual(#popups, 0, "None")
    -- 4 already fills columns growing right and down, as 1 does.
    NS.Helpers.SelectContainer(4)
    NS.SetByPath("container.attach.mode", "container", 4)
    m.__fireTimers()
    local redraw = function() return P.during(function() NS.Helpers.RefreshAllPanels() end) end
    dd = targetDropdown(NS, P, redraw())
    dd:__fire("OnValueChanged", 1)
    assertEqual(#popups, 0, "the same flow")
    assertEqual(NS.Database.FindContainer(4).attach.container, 1, "stored at once")
    -- Screen mode: the Attach to row with no usable target stored.
    NS.Helpers.SelectContainer(3)
    local ws3 = redraw()
    P.row(ws3, "container.attach.mode"):__fire("OnValueChanged", "container")
    assertEqual(#popups, 0, "a mode write with container None")
    assertEqual(NS.Database.FindContainer(3).attach.mode, "container")
end)

test("layout: switching Attach to into container mode with a differing target stored asks first", function()
    local NS, m, P = layout()
    NS.SetByPath("container.attach.container", 1, 2)   -- stored while 2 sits on the screen
    NS.Helpers.SelectContainer(2)
    local ws = P.show("Layout")
    local popups = P.popups()
    P.row(ws, "container.attach.mode"):__fire("OnValueChanged", "container")
    -- red under: the mode row without its confirmWrite (the stale target attaches unasked)
    assertEqual(#popups, 1, "one popup")
    assertEqual(NS.Database.FindContainer(2).attach.mode, "screen", "nothing stored yet")
    m.StaticPopupDialogs.AURAMASTER_ATTACH_FLOW.OnAccept(popups[1], popups[1].data)
    assertEqual(NS.Database.FindContainer(2).attach.mode, "container", "accepted")
end)

test("layout: /am set attaches without asking and prints one line; a differing detach prints one", function()
    local NS, _, P = layout()
    local popups = P.popups()
    local chat = P.chat()
    NS.SetByPath("container.attach.mode", "container", 2)
    NS.SetByPath("container.attach.container", 1, 2)
    assertEqual(#popups, 0, "no popup off the panel")
    assertEqual(NS.Database.FindContainer(2).attach.container, 1, "written")
    -- red under: no chat line for a written growth change
    assertEqual(#chat, 1, "one line")
    assertTrue(chat[1]:find(NS.L["'%s' now grows like '%s'; its own Growth settings are kept."]
        :format("Player debuffs", "Player buffs"), 1, true) ~= nil, chat[1])
    NS.SetByPath("container.attach.container", 1, 4)   -- 4 flows like 1: nothing to say
    NS.SetByPath("container.attach.mode", "container", 4)
    assertEqual(#chat, 1, "a matching flow prints nothing")
    NS.SetByPath("container.attach.mode", "screen", 2)
    -- red under: no detach line
    assertEqual(#chat, 2, "the detach line")
    assertTrue(chat[2]:find(NS.L["'%s' is no longer attached to '%s' and fills and grows by its own Growth settings again."]
        :format("Player debuffs", "Player buffs"), 1, true) ~= nil, chat[2])
end)

test("layout: a chain root's Growth tab says how many containers follow its fill and growth", function()
    local NS, _, P = layout()
    NS.SetByPath("container.attach.container", 1, 2)
    NS.SetByPath("container.attach.mode", "container", 2)
    local ws = P.tab("layout", NS.L["Growth"])
    -- red under: growthIntro silent on a root
    assertTrue(P.hasText(ws, NS.L["%d container(s) attached to this one follow its fill and growth."]:format(1)))
end)
