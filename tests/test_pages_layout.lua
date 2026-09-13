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
    local banner = NS.Helpers.__pageCtx.layout.__bannerWidget
    for _, w in ipairs(P.all(ws, "Dropdown", NS.L["Container"])) do
        if w ~= banner then return w end
    end
    return nil
end

-- The Anchor tab's subsections and the rows each one holds, in drawing order.
local SUBSECTIONS = {
    { key = "Screen", paths = { "container.position.point", "container.position.relativePoint",
                                "container.position.x", "container.position.y" } },
    { key = "Another container", paths = { "container.attach.container" } },
    { key = "Named frame", paths = { "container.attach.frame", "container.attach.point",
                                     "container.attach.relativePoint" } },
    { key = "Offset", paths = { "container.attach.x", "container.attach.y" } },
}

--- The widget each Anchor row drew, by path. Two rows share the label "Point" (and two
--- "Relative point"), so a label's nth widget belongs to that label's nth row in schema order; the
--- banner is dropped first, because it is a second "Container" dropdown.
local function anchorWidgets(NS, ws)
    local banner = NS.Helpers.__pageCtx.layout.__bannerWidget
    local byLabel = {}
    for _, w in ipairs(ws) do
        local label = w.labelText or w.text
        if w ~= banner and label then
            byLabel[label] = byLabel[label] or {}
            table.insert(byLabel[label], w)
        end
    end
    local out, seen = {}, {}
    for _, row in ipairs(NS.SchemaForPage("layout")) do
        if row.group == NS.L["Anchor"] then
            seen[row.label] = (seen[row.label] or 0) + 1
            out[row.path] = (byLabel[row.label] or {})[seen[row.label]]
        end
    end
    return out
end

--- Assert which subsections read enabled for `mode`: every row of an `on` subsection enabled, every
--- other one disabled, and the Attach to row itself always live.
local function assertDimming(widgets, mode, on)
    for _, sub in ipairs(SUBSECTIONS) do
        for _, path in ipairs(sub.paths) do
            local w = widgets[path]
            assertTrue(w ~= nil, "no widget for " .. path)
            local want = not on[sub.key]
            assertEqual(w.disabled and true or false, want,
                ("%s in %s mode (%s)"):format(path, mode, sub.key))
        end
    end
    assertTrue(not widgets["container.attach.mode"].disabled, "Attach to is never dimmed")
end

local ON = {
    screen    = { Screen = true },
    container = { ["Another container"] = true, Offset = true },
    frame     = { ["Named frame"] = true, Offset = true },
}

test("layout: the tabs are Frame, Anchor, Growth, Mouse, in that order", function()
    local NS, _, P = layout()
    local L = NS.L
    -- red under: the Position rows declared before the Frame rows (tab order is first-seen group order)
    assertEqual(table.concat(P.tabKeys("layout"), ","),
        table.concat({ L["Frame"], L["Anchor"], L["Growth"], L["Mouse"] }, ","))
end)

test("layout: the Anchor tab is broken into Screen, Another container, Named frame and Offset", function()
    local NS, _, _, ws = layout()
    local heads = {}
    for _, w in ipairs(ws) do
        if w.type == "Heading" then
            local n = #heads
            heads[n + 1] = w.text
        end
    end
    -- red under: a row left without its subgroup, or a subgroup out of order (a heading repeats)
    assertEqual(table.concat(heads, ","), table.concat({ NS.L["Screen"], NS.L["Another container"],
        NS.L["Named frame"], NS.L["Offset"] }, ","))
end)

test("layout: Pick a frame sits beside Frame name in Named frame, and there is no Attach to the screen", function()
    local NS, _, P, ws = layout()
    local box = P.row(ws, "container.attach.frame")
    local line
    for _, w in ipairs(ws) do
        if w.children and w.children[1] == box then line = w end
    end
    assertTrue(line ~= nil, "Frame name is on a line of its own group")
    local pick = line.children[2]
    -- red under: Pick drawn by an afterGroup (its own line after Offset) instead of paired with Frame name
    assertTrue(pick ~= nil and pick.type == "Button" and pick.text == NS.L["Pick a frame…"],
        "Pick a frame… is Frame name's right half")
    -- red under: the redundant Attach to the screen button still drawn (the dropdown does the same)
    assertEqual(P.find(ws, "Button", "Attach to the screen"), nil)
end)

for _, mode in ipairs({ "screen", "container", "frame" }) do
    test("layout: in " .. mode .. " mode only the subsections that apply are enabled", function()
        local NS, _, P = layout()
        NS.SetByPath("container.attach.mode", mode, 1)
        local ws = P.rerender("Layout")
        -- red under: a subsection's rows without their disabledIf, or onlyIn naming the wrong mode
        assertDimming(anchorWidgets(NS, ws), mode, ON[mode])
        -- A pick switches the mode to frame itself, so the button is a way into Named frame from any mode.
        assertTrue(not P.find(ws, "Button", NS.L["Pick a frame…"]).disabled, "Pick a frame… stays live")
    end)
end

test("layout: changing Attach to re-dims the same widgets before any redraw", function()
    local NS, m, _, ws = layout()
    m.__subcategories.Layout:Show()
    local widgets = anchorWidgets(NS, ws)
    assertDimming(widgets, "screen", ON.screen)
    widgets["container.attach.mode"]:__fire("OnValueChanged", "frame")
    -- red under: dimming fixed at render (a disabled flag, not a predicate re-read on RefreshScalars)
    assertDimming(widgets, "frame", ON.frame)
    widgets["container.attach.mode"]:__fire("OnValueChanged", "container")
    assertDimming(widgets, "container", ON.container)
end)

test("layout: Attach to writes the mode and redraws an open page on the next frame", function()
    local NS, m, P, ws = layout()
    m.__subcategories.Layout:Show()
    local dd = P.row(ws, "container.attach.mode")
    assertEqual(table.concat(dd.order, ","), "screen,container,frame")
    dd:__fire("OnValueChanged", "container")
    assertEqual(NS.Database.FindContainer(1).attach.mode, "container")
    local redrawn = P.during(function() m.__fireTimers() end)
    -- red under: the mode row losing its structural onChange (a scalar refresh draws nothing new)
    assertTrue(#redrawn > 0, "the page was drawn again")
end)

test("layout: the Container dropdown offers None and every other container, never the selected one", function()
    local NS, _, P = layout()
    NS.Helpers.SelectContainer(2)
    local ws = P.show("Layout")
    local dd = targetDropdown(NS, P, ws)
    -- red under: attachTargets listing the selected container (a container attached to itself)
    assertEqual(table.concat(dd.order, ","), "0,1,3")
    assertEqual(dd.list[0], NS.L["None"])
    assertEqual(dd.list[3], "Target debuffs (mine)")
end)

test("layout: a target that would close a loop is refused; any other, or None, is stored", function()
    local NS, _, P, ws = layout()
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
    dd:__fire("OnValueChanged", 3)
    assertEqual(NS.Database.FindContainer(1).attach.container, 3)
    dd:__fire("OnValueChanged", 0)
    assertEqual(NS.Database.FindContainer(1).attach.container, 0, "None is always allowed")
end)

test("layout: Frame name stores the typed name for the selected container", function()
    local NS, _, P, ws = layout()
    local box = P.row(ws, "container.attach.frame")
    assertEqual(box.type, "EditBox")
    box:__fire("OnEnterPressed", "PlayerFrame")
    -- red under: the frame row writing any container but the selection
    assertEqual(NS.Database.FindContainer(1).attach.frame, "PlayerFrame")
    assertEqual(NS.Database.FindContainer(2).attach.frame, "")
end)

test("layout: Pick a frame in combat refuses in gray and starts nothing", function()
    local NS, m, P, ws = layout()
    local started = 0
    NS.FramePicker.Start = function() started = started + 1 end
    local lines = P.chat()
    m.__lockdown = true
    P.find(ws, "Button", NS.L["Pick a frame…"]):__fire("OnClick")
    -- red under: pickFrame without its InCombatLockdown gate
    assertEqual(started, 0)
    assertEqual(m.__settingsClosed, 0, "the settings stay open")
    assertEqual(#lines, 1)
    assertTrue(lines[1]:find("|cff808080cannot pick a frame during combat", 1, true) ~= nil, lines[1])
end)

test("layout: a pick attaches the container selected when it began, and reopens the page", function()
    local NS, m, P, ws = layout()
    local onPick, onCancel
    NS.FramePicker.Start = function(pick, cancel) onPick, onCancel = pick, cancel end
    local opened = {}
    NS.OpenOptionsPage = function(page)
        opened[#opened + 1] = page
    end
    P.find(ws, "Button", NS.L["Pick a frame…"]):__fire("OnClick")
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
    assertEqual(dd.value, "HIGH")
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
    local NS, m = layout()
    NS.SetByPath("container.layout.spacing", 9, 1)
    NS.SetByPath("container.attach.mode", "frame", 1)
    NS.SetByPath("container.bars.width", 300, 1)
    NS.SetByPath("container.layout.spacing", 9, 2)
    NS.State.SetActiveContainer(1)
    m.__subcategories.Layout.defaultsOnClick()
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
    NS.Helpers.__pageCtx.layout.__bannerWidget:__fire("OnValueChanged", 3)
    ws = P.show("Layout")
    -- red under: the page caching the container it first drew, or losing its tab on the switch
    assertEqual(NS.Helpers.__pageCtx.layout.activeTab, NS.L["Frame"], "the tab survives the switch")
    assertEqual(P.row(ws, "container.layout.scale").value, 1.5)
end)
