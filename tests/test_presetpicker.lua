-- tests/test_presetpicker.lua -- settings/PresetPicker.lua: the first-run preset picker (AM-PR05; spec
-- sections 5, 6 and 7). When it is due (a new profile, once, the addon standing up), that it shows
-- before the skin picker and holds it until it closes, what a pick, Apply, Empty, Not now, the close
-- control and Escape each do to the profile, and that combat holds it. Every case writes the profile,
-- so each builds its own environment (tests/fresh_env.lua). A fresh profile holds the harness's
-- starter containers and has not seen the picker.

local freshEnv = dofile("tests/fresh_env.lua")

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

--- A fresh environment whose skin picker is a recorder (`calls`, one spec per showing), with chat
--- captured in `lines`.
local function fresh(opts)
    local NS, m = freshEnv(opts)
    local calls = {}
    NS.Helpers.SkinPicker = function(spec)
        calls[#calls + 1] = spec
        return { spy = true }
    end
    local lines = {}
    rawset(m.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg) lines[#lines + 1] = tostring(msg) end)
    return NS, m, calls, lines
end

--- Record StaticPopup_Show calls; each popup a table, as the client's is.
local function popups(m)
    local shown = {}
    m.StaticPopup_Show = function(which, a1, a2)
        local popup = { which = which, a1 = a1, a2 = a2 }
        shown[#shown + 1] = popup
        return popup
    end
    return shown
end

--- The ids of the profile's containers, in order, as text.
local function ids(NS)
    local out = {}
    for _, c in ipairs(NS.Database.GetContainers()) do out[#out + 1] = tostring(c.id) end
    return table.concat(out, ",")
end

local WINDOW = "AuraMasterPresetPicker"

local function anyLine(lines, needle)
    for _, l in ipairs(lines) do if l:find(needle, 1, true) then return true end end
    return false
end

-- ── when it is due ───────────────────────────────────────────────────────────────────────────

test("picker: due on new profile only", function()
    local NS = fresh()
    -- red under: a picker due on a profile that has closed it, or never due on a new one
    assertTrue(NS.PresetPickerDue(), "a fresh install's profile has not seen it")
    NS.Presets.MarkPickerSeen()
    assertFalse(NS.PresetPickerDue(), "a profile that closed it")
    local migrated = fresh({ savedVariables = {
        profiles = { Default = { seeded = true, nextContainerId = 2,
            containers = { [1] = { name = "Mine", unit = "player", auraType = "HELPFUL", style = "bars" } },
            containerOrder = { 1 } } },
        global = { schemaVersion = 18 },
    } })
    assertFalse(migrated.PresetPickerDue(), "a profile migrated from v18 never sees it")
    local NS3 = fresh()
    NS3.SetByPath("enabled", false)
    NS3.SyncEnabled()
    assertFalse(NS3.PresetPickerDue(), "a stood-down addon offers no picker")
    assertNil(NS3.MaybeShowPresetPicker())
end)

test("picker: shows before skin picker", function()
    local NS, m, calls = fresh()
    m.__fireEvent("PLAYER_ENTERING_WORLD")
    local f = NS.PresetPicker.frame
    -- red under: the login arming the skin picker's two-second start while the preset picker is due
    assertTrue(f ~= nil and f:IsShown(), "the world entry shows the preset picker at once")
    for _, t in ipairs(m.__timers()) do
        if t.delay == 2 then t.fn() end
    end
    assertEqual(#calls, 0, "no skin picker while the preset picker is up")
    assertEqual(NS.MaybeShowSkinPicker(), nil, "a direct ask is held too")
    assertEqual(#calls, 0)
    f.notNow:__fire("OnClick")
    assertFalse(f:IsShown())
    assertEqual(#calls, 1, "closing the preset picker shows the skin picker next")
    m.__fireEvent("PLAYER_ENTERING_WORLD")
    assertFalse(f:IsShown(), "a second loading screen shows nothing")
end)

test("picker: a profile that has seen it arms the skin picker's start as before", function()
    local NS, m, calls = fresh()
    NS.Presets.MarkPickerSeen()
    m.__fireEvent("PLAYER_ENTERING_WORLD")
    assertTrue(NS.PresetPicker.frame == nil or not NS.PresetPicker.frame:IsShown())
    local armed = 0
    for _, t in ipairs(m.__timers()) do
        if t.delay == 2 then armed = armed + 1; t.fn() end
    end
    assertEqual(armed, 1)
    assertEqual(#calls, 1)
end)

-- ── the window ───────────────────────────────────────────────────────────────────────────────

test("picker: the window is a movable, clamped DIALOG on the left, closed by Escape", function()
    local NS, m = fresh()
    -- The window's build, recorded: the kit's frames answer these setters with no record.
    local rec, real = {}, m.CreateFrame
    m.CreateFrame = function(kind, name, parent, template)
        local f = real(kind, name, parent, template)
        if name == WINDOW then
            rawset(f, "SetFrameStrata", function(self, v) rec.strata = v; return self end)
            rawset(f, "SetToplevel", function(self, v) rec.toplevel = v; return self end)
            rawset(f, "SetClampedToScreen", function(self, v) rec.clamped = v; return self end)
            rawset(f, "SetMovable", function(self, v) rec.movable = v; return self end)
            rawset(f, "SetPoint", function(self, ...)
                -- The window's own anchor: the one placed on UIParent (the kit's font strings are
                -- the frame itself, so their points land here too).
                if select(2, ...) == m.UIParent then rec.anchor = { ... } end
                return self
            end)
        end
        return f
    end
    local f = NS.MaybeShowPresetPicker()
    assertTrue(f ~= nil and f:IsShown())
    assertEqual(rec.strata, "DIALOG", "frame-layering: the skin picker's layer")
    assertTrue(rec.movable and rec.clamped and rec.toplevel, "movable, clamped and toplevel")
    assertEqual(rec.anchor[1], "LEFT")
    assertEqual(rec.anchor[4], 24, "24 in from the left edge")
    local listed = false
    for _, n in ipairs(m.UISpecialFrames) do listed = listed or n == WINDOW end
    assertTrue(listed, "Escape closes it (UISpecialFrames)")
    assertTrue(f.close ~= nil and f.apply ~= nil and f.notNow ~= nil and f.dd ~= nil)
    assertFalse(f.status:IsShown(), "nothing is previewed until a pick")
end)

test("picker: pick previews, close restores, latch set", function()
    local NS = fresh()
    local before = ids(NS)
    local f = NS.MaybeShowPresetPicker()
    f.dd.onSelect("intermediate")
    -- red under: a pick that writes nothing, or writes without test mode
    assertTrue(NS.Presets.IsPreviewing(), "a pick previews")
    assertTrue(NS.State.testMode, "in test mode")
    assertEqual(#NS.Database.GetContainers(), NS.PresetData.Count("intermediate"))
    assertTrue(f.status:IsShown(), "the preview line shows")
    f.styleIcons:__fire("OnClick")
    assertTrue(NS.Presets.IsPreviewing(), "a style pick swaps the preview")
    assertEqual(NS.Database.GetContainers()[1].style, "icons")
    f.close:__fire("OnClick")
    assertFalse(f:IsShown())
    assertFalse(NS.Presets.IsPreviewing(), "the close control restores")
    assertFalse(NS.State.testMode, "and turns test mode off")
    assertEqual(ids(NS), before, "the player's own containers, ids included")
    assertTrue(NS.Presets.PickerSeen(), "every close sets the latch")
    assertFalse(NS.PresetPickerDue())
end)

test("picker: Escape restores like Not now", function()
    local NS = fresh()
    local before = ids(NS)
    local f = NS.MaybeShowPresetPicker()
    f.dd.onSelect("healer")
    assertTrue(NS.Presets.IsPreviewing())
    f:Hide()
    f:__fire("OnHide")   -- Escape: the client hides a UISpecialFrames window, then OnHide
    assertFalse(NS.Presets.IsPreviewing())
    assertEqual(ids(NS), before)
    assertTrue(NS.Presets.PickerSeen())
end)

test("picker: apply keeps", function()
    local NS, m = fresh()
    local shown = popups(m)
    local f = NS.MaybeShowPresetPicker()
    f.dd.onSelect("advanced")
    f.apply:__fire("OnClick")
    -- red under: a first-run Apply that asks (nothing of the player's is lost on a new profile)
    assertEqual(#shown, 0, "the first-run picker does not ask")
    assertFalse(f:IsShown())
    assertFalse(NS.Presets.IsPreviewing(), "kept: the snapshot is dropped")
    assertFalse(NS.State.testMode, "test mode off")
    assertEqual(#NS.Database.GetContainers(), 20)
    assertTrue(NS.Presets.PickerSeen())
end)

test("picker: Apply with nothing picked keeps what the profile holds", function()
    local NS = fresh()
    local before = ids(NS)
    local f = NS.MaybeShowPresetPicker()
    f.apply:__fire("OnClick")
    assertFalse(f:IsShown())
    assertEqual(ids(NS), before, "no pick, nothing written")
    assertTrue(NS.Presets.PickerSeen())
end)

test("picker: empty applies no containers", function()
    local NS = fresh()
    local before = ids(NS)
    local f = NS.MaybeShowPresetPicker()
    f.dd.onSelect("simple")
    assertTrue(NS.Presets.IsPreviewing())
    f.dd.onSelect("empty")
    -- red under: Empty previewed in test mode, or the style switch left showing for it
    assertFalse(NS.Presets.IsPreviewing(), "Empty ends the preview")
    assertFalse(NS.State.testMode, "and shows no test mode")
    assertEqual(ids(NS), before, "the player's own containers are back until Apply")
    assertFalse(f.styleBars:IsShown(), "no Bars / Icons switch for Empty")
    f.apply:__fire("OnClick")
    assertEqual(#NS.Database.GetContainers(), 0, "Empty applied: no containers")
    assertFalse(f:IsShown())
end)

test("picker: refused in combat holds", function()
    local NS, m, calls = fresh()
    m.__lockdown = true
    assertNil(NS.MaybeShowPresetPicker(), "nothing shows in combat")
    NS.MaybeShowPresetPicker()
    assertTrue(NS.PresetPicker.frame == nil or not NS.PresetPicker.frame:IsShown())
    assertEqual(NS.MaybeShowSkinPicker(), nil, "the skin picker waits behind a held preset picker")
    m.__lockdown = false
    m.__fireEvent("PLAYER_REGEN_ENABLED")
    local f = NS.PresetPicker.frame
    assertTrue(f ~= nil and f:IsShown(), "the combat edge shows it")
    assertEqual(#calls, 0, "and still no skin picker")
    m.__lockdown = true
    f.dd.onSelect("simple")
    assertFalse(NS.Presets.IsPreviewing(), "a pick in combat is refused")
end)

test("picker: on demand it asks before replacing the player's containers", function()
    local NS, m = fresh()
    NS.Presets.MarkPickerSeen()
    local shown = popups(m)
    local f = NS.ShowPresetPicker()
    assertTrue(f ~= nil and f:IsShown(), "/am preset's window shows whatever the latch says")
    f.dd.onSelect("simple")
    f.apply:__fire("OnClick")
    assertEqual(#shown, 1, "Replace asks first")
    assertEqual(shown[1].which, "AURAMASTER_APPLY_PRESET")
    assertEqual(shown[1].a1, 4, "naming the count it removes: the player's own four, not the preview's")
    assertTrue(f:IsShown(), "the window waits for the answer")
    m.StaticPopupDialogs.AURAMASTER_APPLY_PRESET.OnAccept(shown[1], shown[1].data)
    assertFalse(f:IsShown())
    assertFalse(NS.Presets.IsPreviewing())
    assertEqual(#NS.Database.GetContainers(), 3)
end)

test("picker: a profile event takes it down with a restore, then offers it to the new profile", function()
    local NS = fresh()
    local f = NS.MaybeShowPresetPicker()
    f.dd.onSelect("advanced")
    NS.db:SetProfile("PickerProbe")
    assertFalse(NS.db.sv.profiles.Default.presets.previewSnapshot ~= nil, "restored into the profile left")
    assertEqual(#NS.db.sv.profiles.Default.containerOrder, 4, "the old profile's own four")
    assertTrue(f:IsShown(), "the new profile has not seen it: shown again, fresh")
    assertFalse(NS.Presets.IsPreviewing())
    assertFalse(NS.db.sv.profiles.Default.presets.pickerSeen, "a profile event is not the player's close")
end)

test("picker: HidePresetPicker restores, unmarked", function()
    local NS, _, _, lines = fresh()
    local before = ids(NS)
    local f = NS.MaybeShowPresetPicker()
    f.dd.onSelect("simple")
    NS.HidePresetPicker()
    assertFalse(f:IsShown())
    assertEqual(ids(NS), before)
    assertFalse(NS.Presets.PickerSeen(), "this addon's own hide writes no latch")
    assertFalse(anyLine(lines, "error"))
end)
