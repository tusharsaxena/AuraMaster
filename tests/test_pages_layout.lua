-- tests/test_pages_layout.lua — settings/Layout.lua, driven through its widgets: the attach rows and
-- their cycle guard, the frame picker's two buttons, what a Growth or Frame row re-applies, and the
-- page's Defaults. How an attachment is resolved is tests/test_anchors.lua's.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")
local pages = dofile("tests/page_helpers.lua")

local function layout(opts)
    local NS, m = fresh(opts)
    local P = pages(NS, m)
    return NS, m, P, P.show("Layout")
end

--- The attach-target dropdown. The banner is labeled "Container" too, so it is excluded by identity.
local function targetDropdown(NS, P, ws)
    local banner = NS.Helpers.__containerCtx.layout.__bannerWidget
    for _, w in ipairs(P.all(ws, "Dropdown", NS.L["Container"])) do
        if w ~= banner then return w end
    end
    return nil
end

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

test("layout: Attach to the screen detaches the selected container and no other", function()
    local NS, _, P, ws = layout()
    NS.SetByPath("container.attach.mode", "frame", 1)
    NS.SetByPath("container.attach.mode", "frame", 2)
    P.find(ws, "Button", NS.L["Attach to the screen"]):__fire("OnClick")
    -- red under: the button writing a fixed container id
    assertEqual(NS.Database.FindContainer(1).attach.mode, "screen")
    assertEqual(NS.Database.FindContainer(2).attach.mode, "frame")
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
    assertEqual(dd.value, "MEDIUM")
    dd:__fire("OnValueChanged", "HIGH")
    -- red under: the strata row writing any path but layout.strata
    assertEqual(NS.Database.FindContainer(1).layout.strata, "HIGH")
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
    NS.Helpers.__containerCtx.layout.__bannerWidget:__fire("OnValueChanged", 3)
    ws = P.show("Layout")
    -- red under: the page caching the container it first drew, or losing its tab on the switch
    assertEqual(NS.Helpers.__containerCtx.layout.activeTab, NS.L["Frame"], "the tab survives the switch")
    assertEqual(P.row(ws, "container.layout.scale").value, 1.5)
end)
