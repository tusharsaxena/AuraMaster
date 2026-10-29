-- tests/test_skin_picker.lua — the first-run skin picker and the AceGUI widgets this addon acquires
-- itself, on the skin seam (core/SkinSetup.lua; LibKa0s OptionsSkinPicker 1, SkinAce; owner ruling
-- O3, decision X6 of the skinning rollout).
--
-- What this addon owes the picker, and nothing the library pins itself: the spec it hands
-- O.SkinPicker (its owner, its two seams, General's Skin tab, the eye, the close); WHEN it shows (a
-- profile whose `skin.pickerSeen` is false, once after the first world entry and after every
-- profile event, never while the addon stands down, held through combat); that only the player's
-- close marks it seen; and that the eye starts test mode. Then the widgets: every hand-acquired one
-- and the Profiles page's AceConfigDialog tree painted for this owner, and the seam's degraded arm.
-- Every case builds a fresh environment, so no shown picker, queue entry or skin leaks between them.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")
local degraded = dofile("tests/degraded_env.lua")

local OWNER = "AuraMaster"
local PATH = "skin.pickerSeen"

--- Run `fn` with chat silenced.
local function quietly(m, fn)
    local cf = m.DEFAULT_CHAT_FRAME
    local add = rawget(cf, "AddMessage")
    rawset(cf, "AddMessage", function() end)
    local ok, err = pcall(fn)
    rawset(cf, "AddMessage", add)
    if not ok then error(err, 0) end
end

--- A fresh environment with NS.Helpers.SkinPicker replaced by a recorder: each call's spec, in order.
local function spied()
    local NS, m = fresh()
    local calls = {}
    NS.Helpers.SkinPicker = function(spec)
        calls[#calls + 1] = spec
        return { spy = true }
    end
    return NS, m, calls
end

--- The timers queued now with `delay`.
local function timersAt(m, delay)
    local out = {}
    for _, t in ipairs(m.__timers()) do
        if t.delay == delay then out[#out + 1] = t end
    end
    return out
end

-- ── the spec ─────────────────────────────────────────────────────────────────────────────────

test("Skin picker: the spec names this owner, its seams, General's Skin tab and the eye", function()
    -- red under: a set that is not the write seam (Apply would never reach the profile), or a page
    -- or tab key O.SelectTab does not know (the gear would open the panel on the wrong tab).
    local NS = fresh()
    local spec = NS.SkinPickerSpec()
    assertEqual(spec.owner, OWNER)
    assertTrue(rawequal(spec.get, NS.SkinChoice), "get is the read seam")
    assertTrue(rawequal(spec.set, NS.WriteSkinChoice), "set is the write seam")
    assertEqual(spec.page, "general", "X6: the gear opens General")
    assertEqual(spec.tab, "Appearance", "the key settings/General.lua gives O.AppearanceTab")
    assertEqual(type(spec.onPreview), "function", "X6: AuraMaster has a test mode, so the eye is offered")
    assertEqual(type(spec.onClose), "function")
end)

-- ── when it shows ────────────────────────────────────────────────────────────────────────────

test("Skin picker: an unseen profile shows it; a seen one does not", function()
    local NS, _, calls = spied()
    NS.MaybeShowSkinPicker()
    assertEqual(#calls, 1, "skin.pickerSeen false: the picker shows")
    assertEqual(calls[1].owner, OWNER)
    NS.SetByPath(PATH, true)
    NS.MaybeShowSkinPicker()
    assertEqual(#calls, 1, "skin.pickerSeen true: it does not show again")
end)

test("Skin picker: the first world entry arms one two-second start; later entries arm none", function()
    -- red under: no call from addon:OnEnterWorld, a start on every loading screen, or one lit for a
    -- profile that has already closed the picker.
    local _, m, calls = spied()
    assertEqual(#timersAt(m, 2), 0, "nothing armed before the world")
    m.__fireEvent("PLAYER_ENTERING_WORLD")
    local armed = timersAt(m, 2)
    assertEqual(#armed, 1, "the first world entry armed no two-second start")
    armed[1].fn()
    assertEqual(#calls, 1, "the login start shows the picker")
    m.__fireEvent("PLAYER_ENTERING_WORLD")
    assertEqual(#timersAt(m, 2), 1, "a second loading screen armed a second start")
end)

test("Skin picker: a profile that has closed it arms nothing at the world entry", function()
    local NS, m = spied()
    NS.SetByPath(PATH, true)
    m.__fireEvent("PLAYER_ENTERING_WORLD")
    assertEqual(#timersAt(m, 2), 0, "a seen profile armed a start")
end)

test("Skin picker: in combat a start waits for PLAYER_REGEN_ENABLED, once", function()
    local NS, m, calls = spied()
    m.__lockdown = true
    assertEqual(NS.MaybeShowSkinPicker(), nil)
    NS.MaybeShowSkinPicker()
    assertEqual(#calls, 0, "nothing shows in combat")
    m.__lockdown = false
    m.__fireEvent("PLAYER_REGEN_ENABLED")
    assertEqual(#calls, 1, "the combat edge shows it, once for two held starts")
    m.__fireEvent("PLAYER_REGEN_ENABLED")
    assertEqual(#calls, 1, "the one-shot target is gone")
end)

test("Skin picker: a held start is dropped by HideSkinPicker", function()
    local NS, m, calls = spied()
    m.__lockdown = true
    NS.MaybeShowSkinPicker()
    NS.HideSkinPicker()
    m.__lockdown = false
    m.__fireEvent("PLAYER_REGEN_ENABLED")
    assertEqual(#calls, 0, "a dropped start must not fire on the combat edge")
end)

test("Skin picker: never while the addon is switched off", function()
    local NS, m, calls = spied()
    quietly(m, function()
        NS.SetByPath("enabled", false)
        NS.SyncEnabled()
    end)
    assertTrue(NS.IsStoodDown(), "the switch stood the addon down")
    NS.MaybeShowSkinPicker()
    assertEqual(#calls, 0, "a disabled addon shows no picker")
end)

test("Skin picker: a new profile and a reset profile show it again; a seen one does not", function()
    -- Both start from the defaults, skin.pickerSeen false (O3). red under: no call on the profile
    -- path, or one before the latch re-reads the new profile's switch.
    local NS, m, calls = spied()
    local db = NS.db
    NS.SetByPath(PATH, true)
    quietly(m, function()
        db:SetProfile("PickerProbe")
        assertEqual(#calls, 1, "a new profile shows the picker")
        NS.SetByPath(PATH, true)
        db:ResetProfile()
        assertEqual(#calls, 2, "a reset profile shows it again")
        NS.SetByPath(PATH, true)
        db:SetProfile("Default")
        assertEqual(#calls, 2, "back on a profile that has seen it: no picker")
    end)
end)

-- ── the real window ──────────────────────────────────────────────────────────────────────────

test("Skin picker: the player's close marks it seen; this addon's own hide does not", function()
    local NS = fresh()
    local f = NS.MaybeShowSkinPicker()
    assertTrue(f ~= nil and f:IsShown(), "the library's picker did not show")
    NS.HideSkinPicker()
    assertFalse(f:IsShown())
    assertEqual(NS.GetSetting(PATH), false, "this addon's hide is not the player's close")
    f = NS.MaybeShowSkinPicker()
    assertTrue(f ~= nil and f:IsShown(), "it shows again while unseen")
    assertTrue(f.close ~= nil, "the window has a close control")
    f.close:__fire("OnClick")
    assertFalse(f:IsShown(), "the close control closes the window")
    assertEqual(NS.GetSetting(PATH), true, "the player's close sets skin.pickerSeen")
    assertEqual(NS.MaybeShowSkinPicker(), nil, "and it does not show again")
end)

test("Skin picker: the stand-down takes a shown picker down, unmarked", function()
    local NS, m = fresh()
    local f = NS.MaybeShowSkinPicker()
    assertTrue(f ~= nil and f:IsShown())
    quietly(m, function()
        NS.SetByPath("enabled", false)
        NS.SyncEnabled()
    end)
    assertFalse(f:IsShown(), "the stand-down left the picker up")
    assertEqual(NS.GetSetting(PATH), false, "a stand-down is not the player's close")
end)

test("Skin picker: a profile that has seen it takes a shown picker down, unmarked", function()
    local NS, m = fresh()
    local f = NS.MaybeShowSkinPicker()
    assertTrue(f ~= nil and f:IsShown())
    quietly(m, function()
        NS.db:SetProfile("PickerSeen")
        NS.SetByPath(PATH, true)
        NS.db:SetProfile("Default")
        NS.SetByPath(PATH, true)
        NS.db:SetProfile("PickerSeen")
    end)
    assertFalse(f:IsShown(), "the picker stayed up on a profile that has seen it")
end)

test("Skin picker: the eye starts test mode, and leaves a running one alone", function()
    local NS, m = fresh()
    quietly(m, function() NS.SkinPickerSpec().onPreview() end)
    assertTrue(NS.State.testMode == true, "the eye did not start test mode")
    quietly(m, function() NS.SkinPickerSpec().onPreview() end)
    assertTrue(NS.State.testMode == true, "a second press turned test mode off")
end)

test("Skin picker: the eye in combat starts nothing", function()
    -- Preview.SetTestMode refuses in combat with its own line; the eye adds no path around it.
    local NS, m = fresh()
    m.__lockdown = true
    quietly(m, function() NS.SkinPickerSpec().onPreview() end)
    m.__lockdown = false
    assertFalse(NS.State.testMode == true, "the eye started test mode in combat")
end)

-- ── the AceGUI widgets this addon acquires ───────────────────────────────────────────────────

--- A fresh environment wearing Obsidian with the settings panel in the Scope (a new profile leaves
--- the panel the client's: skin.ignorePanel defaults to true), and the Skin major.
local function obsidian()
    local NS, m = fresh()
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    quietly(m, function()
        NS.WriteSkinChoice("ka0s", "obsidian", { panel = false, fonts = false })
        NS.ApplySkinChoice()
    end)
    return NS, m, Skin
end

local function ownerOf(Skin, w)
    local st = Skin.__ace and Skin.__ace[w]
    return st and st.owner
end

test("Skin widgets: a hand-built dropdown is painted for this owner", function()
    -- red under: NS.CreateDropdown handing back a widget no painter reached (AM-G1 left open).
    local NS, _, Skin = obsidian()
    local dd = NS.CreateDropdown()
    assertEqual(ownerOf(Skin, dd), OWNER)
end)

test("Skin widgets: SkinPaintAce paints a widget acquired past the proxy, for this owner", function()
    -- AceConfigDialog's widgets (the Profiles page) come from AceGUI itself, not the owner proxy.
    local NS, m, Skin = obsidian()
    local AceGUI = m.LibStub("AceGUI-3.0")
    local btn = AceGUI:Create("Button")
    assertTrue(NS.SkinPaintAce(btn), "PaintAce did not paint a stock Button")
    assertEqual(ownerOf(Skin, btn), OWNER)
    local group = AceGUI:Create("SimpleGroup")
    group:AddChild(AceGUI:Create("Button"))
    assertTrue(NS.SkinPaintAceTree(group) >= 1, "PaintAceTree painted nothing under the group")
end)

test("Skin widgets: with the settings panel ignored (the new-profile default) nothing is painted", function()
    -- red under: a host paint that bypasses the Scope (PaintAce honors ignorePanel itself).
    local NS, m = fresh()
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    quietly(m, function() NS.ApplySkinChoice("ka0s", "obsidian") end)
    assertEqual(NS.GetSetting("skin.ignorePanel"), true)
    local dd = NS.CreateDropdown()
    assertTrue(ownerOf(Skin, dd) == nil, "a dropdown was painted with the panel ignored")
end)

test("Skin widgets: the release chain runs the host's work and the skin's restore", function()
    local NS, m, Skin = obsidian()
    local AceGUI = m.LibStub("AceGUI-3.0")
    local btn = AceGUI:Create("Button")
    NS.SkinPaintAce(btn)
    local ran = 0
    NS.SkinOnRelease(btn, function() ran = ran + 1 end)
    AceGUI:Release(btn)
    assertEqual(ran, 1, "the host's release work did not run")
    assertTrue(ownerOf(Skin, btn) == nil, "the release did not put the widget back stock")
end)

test("Skin widgets: the Profiles page paints the dialog's tree after every open", function()
    -- red under: no NS.SkinPaintAceTree after AceConfigDialog:Open (the page stays stock under every
    -- skin), or one before it (it paints the previous render's released rows).
    local order = {}
    local NS, m = fresh({ before = function(mk)
        mk.__libs["AceDBOptions-3.0"] = { GetOptionsTable = function() return { type = "group", args = {} } end }
        mk.__libs["AceConfig-3.0"] = { RegisterOptionsTable = function() end }
        mk.__libs["AceConfigDialog-3.0"] = { Open = function() order[#order + 1] = "open" end }
    end })
    local painted
    NS.SkinPaintAceTree = function(c) order[#order + 1] = "paint"; painted = c; return 0 end
    local P = dofile("tests/page_helpers.lua")(NS, m)
    P.show("Profiles")
    assertEqual(table.concat(order, ","), "open,paint")
    assertTrue(painted ~= nil and painted.type == "SimpleGroup", "the page's own container was painted")
end)

test("Skin widgets: without the library nothing is painted, and release work takes the callback", function()
    local NS2 = degraded()
    assertEqual(NS2.SkinPaintAce({ frame = {} }), false)
    assertEqual(NS2.SkinPaintAceTree({ frame = {} }), 0)
    local set = {}
    local w = { SetCallback = function(_, name, fn) set[name] = fn end }
    local ran = 0
    NS2.SkinOnRelease(w, function() ran = ran + 1 end)
    assertEqual(type(set.OnRelease), "function", "no OnRelease callback was set")
    set.OnRelease(w)
    assertEqual(ran, 1)
    assertEqual(NS2.MaybeShowSkinPicker(), nil, "no picker without the library")
end)
