-- tests/test_presetpicker_titlebar.lua -- the preset picker's title bar (settings/PresetPicker.lua),
-- the one window this addon draws itself with controls on its title band. Smoke round 1 of
-- Ka0sAddonsCommonTasks docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS (SR1_SMOKE_ROUND1.md, rulings 3 and
-- 4; item SR-AM): every title-bar control shows a one-line tooltip on hover, in this owner's
-- `gtip.title`, above it; at rest it paints the skin's `icon.tint`, and a close X takes `close.hot`
-- under the pointer. Since AD-86-AM (LibKa0s#86, standalone-windows *Title-bar controls*) the marks
-- are LibKa0s-Widgets-1.0's HeaderButtons, left to right settings · close: the close is still
-- LibKa0s-Core-1.0's (MakeCloseButton with three arguments), and the settings mark lights
-- `text.link` under the pointer and opens Aura Master's settings through the launcher's opener,
-- closing the picker first as Not now does (the picker's MODAL strata would cover the panel). These
-- cases hold this window to all of it, under Ka0s Default and another skin.

local freshEnv = dofile("tests/fresh_env.lua")

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local OWNER = "AuraMaster"

--- Every control on the picker's title band, by name, so a control added later is held here too.
local function titleControls(f)
    return { settings = f.settings, close = f.close }
end

--- A fresh environment wearing skin `skin` (nil: Ka0s Default), the picker shown, and the skin facade.
local function shown(skin)
    local NS, m = freshEnv()
    NS.Helpers.SkinPicker = function() return { spy = true } end
    rawset(m.DEFAULT_CHAT_FRAME, "AddMessage", function() end)
    if skin then NS.SetByPath("skin.skin", skin) end
    -- The paint recorder, so the close's art keeps its colors; installed before the window builds.
    local restore = dofile("tests/_kit/mock_paint.lua")(m)
    local f = NS.MaybeShowPresetPicker()
    restore()
    assertTrue(f ~= nil and f:IsShown(), "the picker shows")
    return NS, m, f, m.LibStub("LibKa0s-Skin-1.0"):For(OWNER)
end

--- Hover `btn` and answer what GameTooltip was told: its words, color and first point.
local function hover(m, btn)
    local seen = {}
    local tip = m.GameTooltip
    rawset(tip, "SetText", function(_, words, r, g, b)
        seen.words, seen.color = words, { r, g, b }
    end)
    rawset(tip, "SetPoint", function(_, ...) seen.point = seen.point or { ... } end)
    btn:__fire("OnEnter")
    btn:__fire("OnLeave")
    return seen
end

local function sameColor(got, want, what)
    assertTrue(type(want) == "table", what .. ": the skin answers the token")
    for i = 1, 3 do assertEqual(got[i], want[i], what .. " [" .. i .. "]") end
end

--- The art's color now: the close control's icon (a texture) or its glyph (a font string), read
--- off the kit's paint recorder (tests/_kit/mock_paint.lua), which keeps what each region was given.
local function artColor(btn)
    if btn.icon then return { btn.icon:GetVertexColor() } end
    return { btn.glyph:GetTextColor() }
end

for _, skin in ipairs({ "ka0s", "azeroth" }) do
    test("preset picker title bar (" .. skin .. "): every control has a tooltip, in gtip.title, above it", function()
        local _, m, f, S = shown(skin ~= "ka0s" and skin or nil)
        for name, btn in pairs(titleControls(f)) do
            assertTrue(btn ~= nil, name .. ": built")
            local seen = hover(m, btn)
            -- red under: a title-bar control with no tooltip (smoke round 1, ruling 3)
            assertTrue(type(seen.words) == "string" and seen.words ~= "", name .. ": a non-empty tooltip")
            sameColor(seen.color, S.Token("gtip.title"), name .. ": its line in gtip.title")
            -- red under: an attached tooltip anchored below its control (ruling 2): its BOTTOM is
            -- placed, on the control's TOP or at an absolute spot above it.
            assertTrue(seen.point ~= nil and tostring(seen.point[1]):find("BOTTOM", 1, true) == 1,
                name .. ": placed by its bottom, above the control")
        end
        assertEqual(hover(m, f.close).words, "Close", "the close says Close")
        assertEqual(hover(m, f.settings).words, "Open settings", "the settings mark says Open settings")
    end)

    test("preset picker title bar (" .. skin .. "): the settings mark rests in icon.tint and lights text.link", function()
        local _, _, f, S = shown(skin ~= "ka0s" and skin or nil)
        local btn = f.settings
        -- red under: a picker with no settings mark (LibKa0s#86)
        assertTrue(btn ~= nil and btn.icon ~= nil, "the settings mark draws its catalog art")
        sameColor(artColor(btn), S.Token("icon.tint"), "at rest")
        btn:__fire("OnEnter")
        sameColor(artColor(btn), S.Token("text.link"), "under the pointer")
        btn:__fire("OnLeave")
        sameColor(artColor(btn), S.Token("icon.tint"), "back at rest")
    end)

    test("preset picker title bar (" .. skin .. "): the close rests in icon.tint and lights close.hot", function()
        local _, _, f, S = shown(skin ~= "ka0s" and skin or nil)
        local btn = f.close
        -- red under: a close X at rest in its own gray, apart from the other title-bar controls (ruling 4)
        sameColor(artColor(btn), S.Token("icon.tint"), "at rest")
        sameColor(S.Token("close.rest"), S.Token("icon.tint"), "close.rest follows icon.tint")
        btn:__fire("OnEnter")
        sameColor(artColor(btn), S.Token("close.hot"), "under the pointer")
        btn:__fire("OnLeave")
        sameColor(artColor(btn), S.Token("icon.tint"), "back at rest")
    end)
end

test("preset picker title bar: Azeroth's close colors differ from Ka0s Default's, so the cases above can tell them apart", function()
    local _, _, _, S = shown()
    local kd = { rest = S.Token("icon.tint"), hot = S.Token("close.hot") }
    local _, _, _, S2 = shown("azeroth")
    local differs = false
    for i = 1, 3 do
        differs = differs or kd.rest[i] ~= S2.Token("icon.tint")[i] or kd.hot[i] ~= S2.Token("close.hot")[i]
    end
    assertTrue(differs, "the second skin pins something the first does not")
end)

test("preset picker title bar: the marks are HeaderButtons', left to right settings · close, in the corner", function()
    local NS, _, f = shown()
    local hb = f.headerButtons
    -- red under: the close placed by hand, alone (the picker before AD-86-AM)
    assertTrue(type(hb) == "table", "the window's marks are W.HeaderButtons'")
    assertEqual(table.concat(hb.order, ","), "settings,close", "left to right settings, close")
    assertTrue(hb.close == f.close and hb.settings == f.settings, "the window keeps both marks")
    assertEqual(hb.optOut, nil, "the picker does not opt out of the settings mark")
    assertEqual(hb.offsets.close, -6, "the close PAD in from the corner")
    assertEqual(hb.offsets.settings, -30, "the settings mark one 18 px slot and a 6 px gap inward")
    assertTrue(NS.Icon("settings") ~= nil, "the vendored catalog carries the settings art")
end)

test("preset picker title bar: the settings mark closes the picker as Not now does, then opens the settings", function()
    local NS, _, f = shown()
    local before = {}
    for _, c in ipairs(NS.Database.GetContainers()) do before[#before + 1] = c.id end
    f.dd.onSelect("intermediate")
    assertTrue(NS.Presets.IsPreviewing(), "a pick previews")
    local opened, upAtOpen = 0, nil
    NS.OpenOptionsPanel = function()
        opened = opened + 1
        upAtOpen = f:IsShown()
    end
    f.settings:__fire("OnClick", "LeftButton")
    -- red under: a settings mark that opens nothing, or the panel under a picker still up
    assertEqual(opened, 1, "the launcher's opener ran once")
    assertEqual(upAtOpen, false, "the picker was down before the panel opened")
    assertFalse(f:IsShown(), "the picker is down")
    assertFalse(NS.Presets.IsPreviewing(), "its preview restored, as Not now")
    local after = {}
    for _, c in ipairs(NS.Database.GetContainers()) do after[#after + 1] = c.id end
    assertEqual(table.concat(after, ","), table.concat(before, ","), "the player's containers kept")
    assertTrue(NS.Presets.PickerSeen(), "a close the player made: the latch is set")
end)

test("preset picker title bar: the client's OnHide on the settings click closes the picker once", function()
    local NS, m, f = shown()
    local lines = {}
    rawset(m.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg) lines[#lines + 1] = tostring(msg) end)
    local skins = 0
    NS.OpenOptionsPanel = function() end
    NS.MaybeShowSkinPicker = function() skins = skins + 1 end
    -- The client fires OnHide inside Hide; the kit's frame does not, so this case does it the client's way.
    local raw, hide = rawget(f, "Hide"), f.Hide
    rawset(f, "Hide", function(self) hide(self); self:__fire("OnHide") end)
    f.settings:__fire("OnClick", "LeftButton")
    rawset(f, "Hide", raw)
    -- red under: hideOnSettings's OnHide and the settings click each finishing the close
    assertEqual(#lines, 1, "one unlock hint: " .. table.concat(lines, " | "))
    -- Re-pinned in the AD-86-AM review fixes: the skin picker is MODAL too, so a close made to reach
    -- the settings offers it not now (it would cover the panel just asked for); it stays due and is
    -- offered at the next showing. Before, this case pinned one offer.
    -- red under: the settings mark offering the skin picker over the panel it opens
    assertEqual(skins, 0, "the skin picker is not offered over the settings")
end)

test("preset picker title bar: the settings mark leaves the skin picker due, and Not now still offers it", function()
    local NS, _, f = shown()
    local skins = 0
    NS.OpenOptionsPanel = function() end
    NS.MaybeShowSkinPicker = function() skins = skins + 1 end
    f.settings:__fire("OnClick", "LeftButton")
    assertEqual(skins, 0, "no skin picker over the settings (the kit's Hide fires no OnHide)")
    assertTrue(NS.SkinPickerDue(), "the skin picker is still due: nothing marked it seen")
    -- red under: the settings click's skip leaking into the next close
    NS.ShowPresetPicker()
    assertTrue(f:IsShown(), "the picker opens again")
    f.notNow:__fire("OnClick")
    assertEqual(skins, 1, "a Not now close offers the skin picker, as before")
end)

test("preset picker title bar: a Core with no close still gets both marks on HeaderButtons, not overlapping", function()
    local NS, m = freshEnv()
    NS.Helpers.SkinPicker = function() return { spy = true } end
    rawset(m.DEFAULT_CHAT_FRAME, "AddMessage", function() end)
    -- The Core-absent stub (core/CoreSetup.lua): MakeCloseButton answers nil.
    NS.MakeCloseButton = function() return nil end
    local f = NS.MaybeShowPresetPicker()
    assertTrue(f ~= nil and f:IsShown(), "the picker shows")
    local hb = f.headerButtons
    -- red under: HeaderButtons placing the gear in the corner and a hand-built X on the same point
    assertTrue(hb.close ~= nil and hb.close == f.close, "the fallback close is HeaderButtons' close")
    assertEqual(table.concat(hb.order, ","), "settings,close", "left to right settings, close")
    assertEqual(hb.offsets.close, -6, "the close in the corner")
    assertTrue(hb.offsets.settings < hb.offsets.close - 18, "the gear inward of the close, not on it")
    assertEqual(#hb.right, 2, "the title keeps room for both marks")
    local opened = 0
    NS.OpenOptionsPanel = function() opened = opened + 1 end
    f.close:__fire("OnClick")
    assertFalse(f:IsShown(), "the fallback close still dismisses")
    assertEqual(opened, 0, "and opens nothing")
end)
