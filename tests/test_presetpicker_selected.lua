-- tests/test_presetpicker_selected.lua -- the preset picker's dropdown marks its selected preset in
-- a color of its own (FB2-AM-01, Ka0sAddonsCommonTasks docs/2026-11-24-FEEDBACK_BATCH,
-- R2_SMOKE_FEEDBACK.md decision D3; WowAddonStandards v2.120.0 skinning-§4, *A selected entry reads
-- apart*).
--
-- The owner, 2026-11-24, of Loot History's character dropdown: "make the current selected always be
-- a different color than the other texts - e.g. gold in ka0s default, etc - Check this for all addons
-- that have a similar pattern". The picker's dropdown (settings/PresetPicker.lua `buildDropdown`) is
-- the one LibKa0s-Widgets-1.0 Dropdown this addon builds; every other dropdown is an AceGUI pullout
-- on a settings page, which the rule leaves out (it keeps AceGUI's check mark). Up to LibKa0s
-- v1.112.0 the shared menu painted a selected row in the raw `menu.textSel`, which under Azeroth is
-- a gold accent within 20 CIEDE2000 of its parchment text. From v1.113.0 (WidgetsDropdown minor 4,
-- as the owner ruled on round 2, 2026-11-24: "leave it as gold") the selected row paints
-- `W.SelectedColor(owner)`, which is Ka0s Default's gold in every skin (WoW Forever's tan accent
-- included); only a skin whose `menu.text` sits under 20 CIEDE2000 off the gold would take its own
-- `menu.textSel`, and none of the shipped skins does. These cases hold the picker to that under every
-- shipped skin. Its rows carry no value color (no class, no quality), so the selection has nothing
-- else to stand apart from.

local freshEnv = dofile("tests/fresh_env.lua")

local T = _G.AM_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "AuraMaster"
local GOLD = "1.000,0.820,0.000"

local function rgb(r, g, b) return ("%.3f,%.3f,%.3f"):format(r, g, b) end

--- A fresh environment with the picker shown; answers NS, the mock, the window and the widgets.
local function shown()
    local NS, m = freshEnv()
    NS.Helpers.SkinPicker = function() return { spy = true } end
    rawset(m.DEFAULT_CHAT_FRAME, "AddMessage", function() end)
    local f = NS.MaybeShowPresetPicker()
    assertTrue(f ~= nil and f:IsShown(), "the picker shows")
    return NS, m, f, m.LibStub("LibKa0s-Widgets-1.0")
end

--- Open the picker's dropdown and answer the shared menu: the first frame built while it opens,
--- kept in `state` for the opens after it. The kit's paint recorder is on while it opens, so the
--- rows keep the colors they were given.
local function open(m, f, state)
    local restore = dofile("tests/_kit/mock_paint.lua")(m)
    local saved = m.CreateFrame
    m.CreateFrame = function(...)
        local fr = saved(...)
        state.menu = state.menu or fr
        return fr
    end
    f.dd:__fire("OnClick")
    m.CreateFrame = saved
    restore()
    assertTrue(state.menu ~= nil and state.menu.buttons ~= nil, "the dropdown opens the shared menu")
    return state.menu
end

--- The selected row's index in the picker's dropdown: the option whose value the dropdown holds.
--- The menu lays its rows out in option order, so row i is option i.
local function selectedIndex(dd)
    for i, opt in ipairs(dd._options or {}) do
        if opt.value == dd._value then return i end
    end
    error("the dropdown holds no option's value: " .. tostring(dd._value))
end

test("preset picker selected: under every shipped skin the selected preset paints W.SelectedColor, gold, apart from the rest", function()
    local NS, m, f, W = shown()
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    local skins, state = Skin:Skins(), {}
    assertTrue(#skins >= 9, "every shipped skin walked, got " .. #skins)
    local at = selectedIndex(f.dd)
    for _, def in ipairs(skins) do
        NS.ApplySkinChoice("ka0s", def.key)
        local menu = open(m, f, state)
        local sel = rgb(menu.buttons[at].fs:GetTextColor())
        -- red under: WidgetsDropdown 3, Azeroth's selection at its own accent, within 20 ΔE00 of its text
        assertEqual(sel, rgb(W.SelectedColor(OWNER)), def.key .. ": the selected preset is W.SelectedColor")
        -- red under: round 2's rule, a skin's accent kept while 20 ΔE00 off its text (Forever's tan)
        assertEqual(sel, GOLD, def.key .. ": the selected preset is Ka0s Default's gold")
        local text = rgb(NS.Skin.Color("menu.text"))
        for i, b in ipairs(menu.buttons) do
            if b:IsShown() and i ~= at then
                local plain = rgb(b.fs:GetTextColor())
                assertEqual(plain, text, def.key .. ": a plain preset is menu.text, row " .. i)
                assertTrue(plain ~= sel, def.key .. ": the selected preset reads apart from row " .. i)
            end
        end
        W.CloseMenu()
    end
    NS.ApplySkinChoice("ka0s", "ka0s")
end)

test("preset picker selected: Azeroth's selection is Ka0s Default's gold, and it follows a new pick", function()
    local NS, m, f, W = shown()
    local state = {}
    NS.ApplySkinChoice("ka0s", "azeroth")
    f.dd.onSelect("advanced")
    local menu = open(m, f, state)
    local at = selectedIndex(f.dd)
    assertEqual(f.dd._options[at].value, "advanced", "the dropdown holds the pick")
    -- red under: a pick that leaves the old preset marked, or Azeroth's raw accent on the selection
    assertEqual(rgb(menu.buttons[at].fs:GetTextColor()), GOLD, "the picked preset is the fallback gold")
    for i, b in ipairs(menu.buttons) do
        if b:IsShown() and i ~= at then
            assertTrue(rgb(b.fs:GetTextColor()) ~= GOLD, "row " .. i .. ": not marked")
        end
    end
    W.CloseMenu()
    NS.ApplySkinChoice("ka0s", "ka0s")
end)

test("preset picker selected: the picker's rows carry no value color for the selection to fight", function()
    local _, m, f = shown()
    local menu = open(m, f, {})
    -- red under: a row given opt.color (a class or quality hue), which the selection must replace
    for _, opt in ipairs(f.dd._options or {}) do
        assertTrue(opt.color == nil, tostring(opt.label) .. ": no value color")
    end
    assertTrue(#menu.buttons >= 5, "every preset is a row")
    m.LibStub("LibKa0s-Widgets-1.0").CloseMenu()
end)
