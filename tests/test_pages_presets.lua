-- tests/test_pages_presets.lua -- settings/ContainersPresets.lua: the Containers page's Presets tab
-- (AM-PR06; spec docs/superpowers/specs/2026-11-14-auramaster-presets-design.md, sections 6 and 8).
-- That the tab sits after General, that a pick of a preset or a style previews it on the real screen,
-- that Apply preset... confirms with the count it replaces or adds and keeps the preview, that Stop
-- preview, leaving the tab (a tab click or a rail click) and closing the panel each restore the
-- player's own containers, and that Empty is not offered. Every case writes the profile, so each
-- builds its own environment (tests/fresh_env.lua); a fresh profile holds the harness's four
-- starter containers.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local pages = dofile("tests/page_helpers.lua")

local POPUP = "AURAMASTER_APPLY_PRESET"

--- The ids of the profile's containers, in order, as text.
local function ids(NS)
    local out = {}
    for _, c in ipairs(NS.Database.GetContainers()) do out[#out + 1] = tostring(c.id) end
    return table.concat(out, ",")
end

--- Record StaticPopup_Show calls with both format arguments; each popup a table, as the client's is.
local function popups(m)
    local shown = {}
    m.StaticPopup_Show = function(which, a1, a2)
        local popup = { which = which, a1 = a1, a2 = a2 }
        shown[#shown + 1] = popup
        return popup
    end
    return shown
end

--- A fresh environment with the Containers page drawn and its Presets tab clicked: the widgets that
--- tab drew, and the page's helpers.
local function presetsTab(opts)
    local NS, m = fresh(opts)
    local P = pages(NS, m)
    P.show("Containers")
    local ws = P.tab("containers", "Presets")
    return NS, m, P, ws
end

local function control(NS, P, ws, label)
    local w = P.find(ws, "Dropdown", NS.L[label]) or P.find(ws, "Button", NS.L[label])
    assert(w, "the Presets tab drew no " .. label)
    return w
end

test("presets tab: listed after General", function()
    local NS, m = fresh()
    local P = pages(NS, m)
    P.show("Containers")
    -- red under: a Presets tab missing from the General section, or drawn ahead of General
    assertEqual(table.concat(P.tabKeys("containers"), ","), NS.L["General"] .. ",Presets")
    local tabs = P.drawnTabs(NS.Helpers.__pageCtx.containers)
    assertEqual(tabs[2].label, NS.L["Presets"])
    assertFalse(NS.Presets.IsPreviewing(), "opening the page previews nothing")
end)

test("presets tab: drawn with no containers too", function()
    local NS, m = fresh()
    for _, c in ipairs(NS.Database.GetContainers()) do NS.ContainerManager.Delete(c.id) end
    local P = pages(NS, m)
    P.show("Containers")
    local ws = P.tab("containers", "Presets")
    -- red under: the tab hidden or empty while the profile has no container to edit
    assertTrue(P.find(ws, "Dropdown", NS.L["Preset"]) ~= nil, "the preset choice is drawn")
    assertTrue(P.find(ws, "Button", NS.L["Apply preset…"]) ~= nil, "and Apply preset…")
end)

test("presets tab: no empty option", function()
    local NS, _, P, ws = presetsTab()
    local dd = control(NS, P, ws, "Preset")
    -- red under: Empty offered on the panel, a one-click wipe of every container (spec section 8)
    assertNil(dd.list.empty, "Empty is not on the tab")
    assertEqual(table.concat(dd.order, ","), "simple,intermediate,advanced,healer")
    assertEqual(dd.list.advanced, NS.L["%s - %d containers"]:format(NS.L["Advanced"], 20))
    local style = control(NS, P, ws, "Style")
    assertEqual(table.concat(style.order, ","), "bars,icons")
    local mode = control(NS, P, ws, "When applied")
    assertEqual(table.concat(mode.order, ","), "replace,add")
end)

test("presets tab: pick previews", function()
    local NS, m, P, ws = presetsTab()
    local before = ids(NS)
    control(NS, P, ws, "Preset"):__fire("OnValueChanged", "intermediate")
    -- red under: a pick that writes nothing, or writes without test mode
    assertTrue(NS.Presets.IsPreviewing(), "a pick previews")
    assertTrue(NS.State.testMode, "in test mode")
    assertEqual(#NS.Database.GetContainers(), NS.PresetData.Count("intermediate"))
    control(NS, P, ws, "Style"):__fire("OnValueChanged", "icons")
    assertTrue(NS.Presets.IsPreviewing(), "a style pick swaps the preview")
    assertEqual(NS.Database.GetContainers()[1].style, "icons")
    -- The redraw the pick asked for: the status line and the list name the preview.
    m.__fireTimers()
    local again = P.show("Containers")
    assertTrue(P.hasText(again, NS.L["Player buffs, short"]), "the list names what the preset creates")
    assertTrue(P.hasText(again, "Nothing is saved until Apply"), "the status line says a preview is up")
    P.find(again, "Button", NS.L["Stop preview"]):__fire("OnClick")
    assertFalse(NS.Presets.IsPreviewing(), "Stop preview restores")
    assertFalse(NS.State.testMode, "and turns test mode off")
    assertEqual(ids(NS), before, "the player's own containers, ids included")
end)

test("presets tab: apply replace confirms and keeps", function()
    local NS, m, P, ws = presetsTab()
    local shown = popups(m)
    control(NS, P, ws, "Preset"):__fire("OnValueChanged", "intermediate")
    control(NS, P, ws, "Apply preset…"):__fire("OnClick")
    -- red under: a Replace that writes before asking, or asks naming the preview's count
    assertEqual(#shown, 1, "Replace asks first")
    assertEqual(shown[1].which, POPUP)
    assertEqual(shown[1].a1, 4, "naming the player's own count, not the preview's")
    assertEqual(shown[1].a2, NS.L["Intermediate"])
    assertTrue(NS.Presets.IsPreviewing(), "the preview stays up while the confirm is open")
    shown[1].data.run()
    assertFalse(NS.Presets.IsPreviewing(), "kept: the snapshot is dropped")
    assertFalse(NS.State.testMode, "test mode off")
    assertEqual(#NS.Database.GetContainers(), 8)
    assertEqual(NS.Database.GetContainers()[4].name, NS.L["Player buffs, short"])
end)

test("presets tab: add keeps player containers", function()
    local NS, m, P, ws = presetsTab()
    local before = ids(NS)
    local shown = popups(m)
    control(NS, P, ws, "When applied"):__fire("OnValueChanged", "add")
    assertFalse(NS.Presets.IsPreviewing(), "the mode alone previews nothing")
    control(NS, P, ws, "Preset"):__fire("OnValueChanged", "healer")
    control(NS, P, ws, "Apply preset…"):__fire("OnClick")
    assertEqual(#shown, 1, "Add says what it adds")
    assertEqual(shown[1].a1, NS.L["Healer"])
    assertEqual(shown[1].a2, 9)
    shown[1].data.run()
    -- red under: Add over the preview (the player's containers gone), or a Replace
    assertFalse(NS.Presets.IsPreviewing())
    local list = NS.Database.GetContainers()
    assertEqual(#list, 4 + 9, "the player's four, then the preset's nine")
    local own = {}
    for i = 1, 4 do own[i] = tostring(list[i].id) end
    assertEqual(table.concat(own, ","), before, "the player's containers kept, ids included")
end)

test("presets tab: apply with nothing previewed applies the selection", function()
    local NS, m, P, ws = presetsTab()
    local shown = popups(m)
    control(NS, P, ws, "Apply preset…"):__fire("OnClick")
    assertEqual(#shown, 1)
    assertEqual(shown[1].a2, NS.L["Simple"], "the selection the tab opened on")
    shown[1].data.run()
    assertEqual(#NS.Database.GetContainers(), 3)
end)

test("presets tab: leaving the tab restores", function()
    local NS, _, P, ws = presetsTab()
    local before = ids(NS)
    control(NS, P, ws, "Preset"):__fire("OnValueChanged", "advanced")
    assertTrue(NS.Presets.IsPreviewing())
    P.tab("containers", NS.L["General"])
    -- red under: a preview left on screen (and in the profile) after the player moved on
    assertFalse(NS.Presets.IsPreviewing(), "a tab click away restores")
    assertFalse(NS.State.testMode)
    assertEqual(ids(NS), before)
    -- And a rail click away, from a fresh preview.
    ws = P.tab("containers", "Presets")
    control(NS, P, ws, "Preset"):__fire("OnValueChanged", "healer")
    assertTrue(NS.Presets.IsPreviewing())
    P.rail("filters")
    assertFalse(NS.Presets.IsPreviewing(), "a rail click away restores")
    assertEqual(ids(NS), before)
    -- A redraw of the tab itself (the pick's own refresh) keeps the preview.
    -- Back on General, the section keeps the tab it was left on: Presets.
    ws = P.rail("containers")
    assertEqual(NS.Helpers.__pageCtx.containers.activeTab, "Presets")
    control(NS, P, ws, "Preset"):__fire("OnValueChanged", "simple")
    P.rerender("Containers")
    assertTrue(NS.Presets.IsPreviewing(), "redrawing the Presets tab is not leaving it")
end)

test("presets tab: panel hide restores", function()
    local NS, _, P, ws = presetsTab()
    local before = ids(NS)
    control(NS, P, ws, "Preset"):__fire("OnValueChanged", "intermediate")
    assertTrue(NS.Presets.IsPreviewing())
    NS.Helpers.__pageCtx.containers.panel:__fire("OnHide")
    -- red under: closing the settings window with the preview still written into the profile
    assertFalse(NS.Presets.IsPreviewing(), "closing the panel restores")
    assertFalse(NS.State.testMode)
    assertEqual(ids(NS), before)
end)

test("presets tab: a preview the tab did not start is not its to end", function()
    local NS, _, P, ws = presetsTab()
    NS.Presets.BeginPreview("healer", "bars")   -- the first-run picker's, say
    P.tab("containers", NS.L["General"])
    -- red under: leaving the tab ending a preview another surface owns
    assertTrue(NS.Presets.IsPreviewing(), "the tab ends only its own preview")
    assertTrue(ws ~= nil)
end)

test("presets tab: refused in combat", function()
    local NS, m, P, ws = presetsTab()
    local lines = P.chat()
    m.__lockdown = true
    control(NS, P, ws, "Preset"):__fire("OnValueChanged", "advanced")
    assertFalse(NS.Presets.IsPreviewing(), "no preview in combat")
    control(NS, P, ws, "Apply preset…"):__fire("OnClick")
    local said = false
    for _, l in ipairs(lines) do said = said or l:find("during combat", 1, true) ~= nil end
    assertTrue(said, "the combat line")
    m.__lockdown = false
end)
