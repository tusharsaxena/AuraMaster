-- tests/test_presetpicker_titlebar.lua -- the preset picker's title bar (settings/PresetPicker.lua),
-- the one window this addon draws itself with controls on its title band. Smoke round 1 of
-- Ka0sAddonsCommonTasks docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS (SR1_SMOKE_ROUND1.md, rulings 3 and
-- 4; item SR-AM): every title-bar control shows a one-line tooltip on hover, in this owner's
-- `gtip.title`, above it; at rest it paints the skin's `icon.tint`, and a close X takes `close.hot`
-- under the pointer. The picker's title bar holds one control, the close X, built through
-- NS.MakeCloseButton (core/CoreSetup.lua), so it is LibKa0s-Core-1.0's close with its tooltip and
-- colors; these cases hold this window to them, under Ka0s Default and another skin.

local freshEnv = dofile("tests/fresh_env.lua")

local T = _G.AM_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "AuraMaster"

--- Every control on the picker's title band, by name, so a control added later is held here too.
local function titleControls(f)
    return { close = f.close }
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
