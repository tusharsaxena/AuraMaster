-- tests/test_pages_containers.lua — settings/Containers.lua, driven through its widgets: the identity
-- rows and what each writes, the acts on the selected container (Duplicate, Delete, Copy settings
-- from), the Overview tab and the band's picker. The registry behavior under those acts is
-- tests/test_containermanager.lua's; this suite proves the page reaches it, on the right container.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local pages = dofile("tests/page_helpers.lua")

local function containers(opts)
    local NS, m = fresh(opts)
    local P = pages(NS, m)
    return NS, m, P, P.show("Containers")
end

local function ids(NS)
    local out = {}
    for i, c in ipairs(NS.Database.GetContainers()) do out[i] = c.id end
    return table.concat(out, ",")
end

test("containers: the Name box renames the selected container, trimmed, and no other", function()
    local NS, _, P = containers()
    NS.Helpers.SelectContainer(2)
    local ws = P.rerender("Containers")
    local box = P.row(ws, "container.name")
    assertEqual(box.type, "EditBox")
    assertEqual(box.text, "Player debuffs", "the box reads the selected container")
    box:__fire("OnEnterPressed", "  Raid debuffs  ")
    -- red under: the name row's normalize not trimming, or the write missing the selection
    assertEqual(NS.Database.FindContainer(2).name, "Raid debuffs")
    assertEqual(NS.Database.FindContainer(1).name, "Player buffs")
end)

test("containers: a blank name is refused and the container keeps its name", function()
    local NS, _, P, ws = containers()
    local msgs = P.messages()
    P.row(ws, "container.name"):__fire("OnEnterPressed", "   ")
    -- red under: dropping the name row's validate (a container nobody can /am select by name)
    assertEqual(NS.Database.FindContainer(1).name, "Player buffs")
    assertEqual(msgs.config, 0, "a refused write announces nothing")
end)

test("containers: a rename re-lists every picker and re-applies no container", function()
    local NS, _, P, ws = containers()
    local msgs = P.messages()
    local applies = 0
    local real = NS.ContainerManager.RequestApply
    NS.ContainerManager.RequestApply = function(...) applies = applies + 1; return real(...) end
    P.row(ws, "container.name"):__fire("OnEnterPressed", "Buffs")
    -- red under: the name row losing NotifyRenamed (the banners keep the old name) or its
    -- `effect = "none"` (Container:Apply never reads the name)
    assertEqual(msgs.containers, 1, "one CONTAINERS_CHANGED")
    assertEqual(applies, 0)
end)

test("containers: the Unit dropdown offers the four units in order and writes the selected container", function()
    local NS, _, P, ws = containers()
    local dd = P.row(ws, "container.unit")
    assertEqual(table.concat(dd.order, ","), table.concat(NS.Constants.UNITS, ","))
    assertEqual(dd.list.focus, NS.L["Focus"], "each unit carries its label")
    dd:__fire("OnValueChanged", "focus")
    -- red under: the row writing an absolute path, or the active container not being the target
    assertEqual(NS.Database.FindContainer(1).unit, "focus")
    assertEqual(NS.Database.FindContainer(3).unit, "target", "another container is untouched")
end)

test("containers: changing the aura type redraws an open Filters page for the new type, on the next frame", function()
    local NS, m, P, ws = containers()
    P.show("Filters")
    m.__subcategories.Filters:Show()   -- on screen, so only a STRUCTURAL refresh re-renders it
    local function hasSpellTab()
        for _, k in ipairs(P.tabKeys("filters")) do if k == "spellLists" then return true end end
        return false
    end
    assertTrue(hasSpellTab(), "a buff container has the spell-list tab")
    P.row(ws, "container.auraType"):__fire("OnValueChanged", "HARMFUL")
    assertEqual(NS.Database.FindContainer(1).auraType, "HARMFUL")
    assertTrue(hasSpellTab(), "never inside the dropdown's own callback")
    m.__fireTimers()
    -- red under: the aura type row losing its structural onChange (the page keeps offering the
    -- buff categories and the spell lists on a debuff container)
    assertFalse(hasSpellTab(), "redrawn for a debuff container")
end)

test("containers: the Style dropdown offers bars and icons and writes the selected container", function()
    local NS, _, P, ws = containers()
    local dd = P.row(ws, "container.style")
    assertEqual(table.concat(dd.order, ","), "bars,icons")
    dd:__fire("OnValueChanged", "icons")
    -- red under: the style row writing the wrong path
    assertEqual(NS.Database.FindContainer(1).style, "icons")
end)

test("containers: New and Duplicate in combat refuse in gray and create nothing", function()
    local NS, m, P, ws = containers()
    local lines = P.chat()
    m.__lockdown = true
    P.find(ws, "Button", NS.L["Duplicate"]):__fire("OnClick")
    NS.Helpers.__containerCtx.containers.__chromeWidgets[2]:__fire("OnClick")   -- New container
    -- red under: sayError printing a refusal plain, or a page act bypassing the combat refusal
    assertEqual(#NS.Database.GetContainers(), 3)
    assertEqual(#lines, 2, "one refusal each")
    for _, l in ipairs(lines) do
        assertTrue(l:find("|cff808080cannot create a container during combat", 1, true) ~= nil, l)
    end
end)

test("containers: Duplicate copies the selected container and selects the copy", function()
    local NS, _, P = containers()
    NS.SetByPath("container.icons.width", 44, 2)
    NS.Helpers.SelectContainer(2)
    local ws = P.rerender("Containers")
    P.find(ws, "Button", NS.L["Duplicate"]):__fire("OnClick")
    local _, id = NS.ActiveContainer()
    -- red under: doDuplicate copying something other than the selection, or not selecting the copy
    assertEqual(#NS.Database.GetContainers(), 4)
    assertTrue(id ~= 2 and id == NS.db.profile.containerOrder[4], "the copy is selected")
    local copy = NS.Database.FindContainer(id)
    assertEqual(copy.name, "Player debuffs (copy)")
    assertEqual(copy.icons.width, 44, "every setting came with it")
end)

test("containers: Delete asks first, naming the container, and deletes it only on Yes", function()
    local NS, m, P = containers()
    local popups = P.popups()
    NS.Helpers.SelectContainer(2)
    local ws = P.rerender("Containers")
    P.find(ws, "Button", NS.L["Delete"]):__fire("OnClick")
    -- red under: doDelete deleting without the popup, or the popup not carrying the id
    assertEqual(#popups, 1)
    assertEqual(popups[1].which, "AURAMASTER_DELETE_CONTAINER")
    assertEqual(popups[1].text, "Player debuffs", "the popup names what it will delete")
    assertEqual(popups[1].data, 2)
    assertEqual(#NS.Database.GetContainers(), 3, "nothing deleted before the answer")
    m.StaticPopupDialogs.AURAMASTER_DELETE_CONTAINER.OnAccept(popups[1], popups[1].data)
    assertEqual(ids(NS), "1,3")
    local _, active = NS.ActiveContainer()
    assertEqual(active, 1, "the selection falls back to the first container")
end)

test("containers: the copy block offers every other container and copies only the chosen section", function()
    local NS, _, P, ws = containers()
    NS.SetByPath("container.bars.width", 123, 2)
    NS.SetByPath("container.layout.spacing", 9, 2)
    local source = P.find(ws, "Dropdown", NS.L["Source container"])
    local what = P.find(ws, "Dropdown", NS.L["What to copy"])
    -- red under: the source list including the selected container (a copy onto itself)
    assertEqual(table.concat(source.order, ","), "2,3")
    assertEqual(table.concat(what.order, ","), "all,filter,layout,behavior,bars,icons")
    source:__fire("OnValueChanged", 2)
    what:__fire("OnValueChanged", "bars")
    P.find(ws, "Button", NS.L["Copy onto this container"]):__fire("OnClick")
    local c1 = NS.Database.FindContainer(1)
    assertEqual(c1.bars.width, 123, "the chosen section came across")
    assertEqual(c1.layout.spacing, NS.CONTAINER_TEMPLATE.layout.spacing, "and nothing else did")
end)

test("containers: copying Everything takes what the source is, never its name or position", function()
    local NS, _, P, ws = containers()
    P.find(ws, "Dropdown", NS.L["Source container"]):__fire("OnValueChanged", 3)
    P.find(ws, "Button", NS.L["Copy onto this container"]):__fire("OnClick")
    local c1 = NS.Database.FindContainer(1)
    -- red under: passing "all" through to CopyFrom rather than nil, which copies nothing at all
    assertEqual(c1.unit, "target")
    assertEqual(c1.auraType, "HARMFUL")
    assertEqual(c1.style, "icons")
    assertEqual(c1.filter.castBy, "mine")
    assertEqual(c1.name, "Player buffs")
    assertEqual(c1.position.x, -240, "the position stays")
end)

test("containers: with one container the page offers Duplicate and Delete but no copy block", function()
    local NS, _, P = containers()
    NS.ContainerManager.Delete(2)
    NS.ContainerManager.Delete(3)
    local ws = P.rerender("Containers")
    assertTrue(P.find(ws, "Button", NS.L["Duplicate"]) ~= nil)
    assertTrue(P.find(ws, "Button", NS.L["Delete"]) ~= nil)
    -- red under: afterGeneral drawing the copy block with nothing to copy from
    assertNil(P.find(ws, "Dropdown", NS.L["Source container"]))
    assertNil(P.find(ws, "Button", NS.L["Copy onto this container"]))
end)

test("containers: Overview describes every container and where it is attached; Select selects it", function()
    local NS, _, P = containers()
    -- The target row's cycle check reads the SELECTED container (settings/Schema.lua's SECTIONS
    -- note), so the attachment is made with 3 selected, as the page itself would make it.
    NS.State.SetActiveContainer(3)
    NS.SetByPath("container.attach.container", 1)
    NS.SetByPath("container.attach.mode", "container")
    NS.State.SetActiveContainer(1)
    NS.SetByPath("container.attach.frame", "PlayerFrame", 2)
    NS.SetByPath("container.attach.mode", "frame", 2)
    NS.SetByPath("container.enabled", false, 2)
    P.show("Containers")
    local ws = P.tab("containers", "overview")
    local lines = P.texts(ws)
    assertEqual(#lines, 3, "one line per container")
    assertTrue(lines[1]:find("Player buffs", 1, true) and lines[1]:find("the screen", 1, true), lines[1])
    assertTrue(lines[1]:find("Player · Buffs · Bars", 1, true) ~= nil, "unit, type and style: " .. lines[1])
    -- red under: describe() reading the attach target by a string id, or ignoring the mode
    assertTrue(lines[2]:find("PlayerFrame", 1, true) ~= nil, lines[2])
    assertTrue(lines[2]:find("|cff888888", 1, true) == 1, "a disabled container is grayed")
    assertTrue(lines[3]:find("attached to 'Player buffs'", 1, true) ~= nil, lines[3])
    local selects = P.all(ws, "Button", NS.L["Select"])
    assertEqual(#selects, 3)
    selects[3]:__fire("OnClick")
    local _, active = NS.ActiveContainer()
    assertEqual(active, 3)
end)

test("containers: the band's picker lists every container, and choosing one retargets the page", function()
    local NS, _, P = containers()
    local picker = NS.Helpers.__containerCtx.containers.__bannerWidget
    assertEqual(picker.type, "Dropdown")
    assertEqual(table.concat(picker.order, ","), "1,2,3")
    assertTrue(picker.list[2]:find("Player debuffs", 1, true) ~= nil, picker.list[2])
    assertTrue(picker.list[2]:find("(Player debuffs, icons)", 1, true) ~= nil, "what it shows: " .. picker.list[2])
    picker:__fire("OnValueChanged", 3)
    -- red under: the picker not writing the shared selection, or the page not re-reading it
    local ws = P.show("Containers")
    assertEqual(P.row(ws, "container.name").text, "Target debuffs (mine)")
    assertEqual(P.row(ws, "container.unit").value, "target")
end)
