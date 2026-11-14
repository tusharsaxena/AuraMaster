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

--- Record StaticPopup_Show calls; each popup a table, as the client's is. StaticPopup_Hide hides
--- each shown one of that kind, running its OnHide once, as the client's does.
local function popups(m)
    local shown = {}
    m.StaticPopup_Show = function(which, a1, a2)
        local popup = { which = which, a1 = a1, a2 = a2 }
        shown[#shown + 1] = popup
        return popup
    end
    m.StaticPopup_Hide = function(which)
        for _, popup in ipairs(shown) do
            if popup.which == which and not popup.hidden then
                popup.hidden = true
                m.StaticPopupDialogs[which].OnHide(popup, popup.data)
            end
        end
    end
    return shown
end

--- The player's Apply on popup `popup`: OnAccept, then the hide every answer makes.
local function accept(m, popup)
    local dialog = m.StaticPopupDialogs.AURAMASTER_APPLY_PRESET
    if popup.hidden then return end
    dialog.OnAccept(popup, popup.data)
    if not popup.hidden then popup.hidden = true; dialog.OnHide(popup, popup.data) end
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

test("picker: the latch is a settings row, written through the seam", function()
    local NS = fresh()
    local row = NS.FindSchemaRow("presets.pickerSeen")
    -- red under: a latch with no row (`/am get|set|reset` cannot reach it), or written beside the seam
    assertTrue(row ~= nil, "a schema row, as skin.pickerSeen has")
    assertTrue(row.skipRender == true and row.effect == "none", "drawn by nothing, re-applies nothing")
    local writes, real = {}, NS.SetByPath
    NS.SetByPath = function(path, ...) writes[#writes + 1] = path; return real(path, ...) end
    NS.Presets.MarkPickerSeen()
    NS.SetByPath = real
    assertEqual(writes[1], "presets.pickerSeen", "MarkPickerSeen writes through the seam")
    assertTrue(NS.GetSetting("presets.pickerSeen"))
    NS.Slash:OnSlash("reset presets.pickerSeen")
    assertTrue(NS.PresetPickerDue(), "a reset of the row offers the picker again")
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

test("picker: the window is a movable, clamped DIALOG, closed by Escape", function()
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
    local NS, m = fresh({ simple = true })
    local shown = popups(m)
    local f = NS.MaybeShowPresetPicker()
    f.dd.onSelect("advanced")
    f.apply:__fire("OnClick")
    -- red under: a first-run Apply that asks (nothing of the player's is lost on an untouched seed)
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
    local NS = fresh({ simple = true })
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
    -- AceDB strips what equals its defaults from the profile it leaves, the whole presets table too.
    local left = NS.db.sv.profiles.Default.presets or {}
    assertFalse(left.previewSnapshot ~= nil, "restored into the profile left")
    assertEqual(#NS.db.sv.profiles.Default.containerOrder, 4, "the old profile's own four")
    assertTrue(f:IsShown(), "the new profile has not seen it: shown again, fresh")
    assertFalse(NS.Presets.IsPreviewing())
    assertFalse(left.pickerSeen, "a profile event is not the player's close")
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

-- ── the untouched seed (review fixes: the first-run Replace asks once the seed has changed) ───

test("picker: a first-run Apply asks once the player has made a container", function()
    local NS, m = fresh({ simple = true })
    local shown = popups(m)
    local f = NS.MaybeShowPresetPicker()
    assertTrue(NS.Presets.SeedUntouched(), "the seed as written")
    NS.Slash:OnSlash("new")
    -- red under: the no-confirm path keyed on how the window opened, not on the profile
    assertFalse(NS.Presets.SeedUntouched(), "a container made with the window up")
    f.dd.onSelect("simple")
    f.apply:__fire("OnClick")
    assertEqual(#shown, 1, "Replace asks: the player's container would be lost")
    assertEqual(shown[1].a1, NS.PresetData.Count("simple") + 1, "naming the player's own count")
    assertTrue(f:IsShown(), "the window waits for the answer")
end)

test("picker: an edited seed asks too, and an untouched one survives a reload", function()
    local NS = fresh({ simple = true })
    local sv = NS.Database.DeepCopy(NS.db.sv)
    local first = NS.Database.GetContainers()[1]
    local name = first.name
    first.name = "Renamed"
    assertFalse(NS.Presets.SeedUntouched(), "an edited field moves the fingerprint")
    first.name = name
    assertTrue(NS.Presets.SeedUntouched(), "and putting it back restores it")
    -- A /reload with the picker still due: the record is read back from the saved profile.
    local NS2, m2 = fresh({ simple = true, savedVariables = sv })
    local shown = popups(m2)
    assertTrue(NS2.PresetPickerDue())
    assertTrue(NS2.Presets.SeedUntouched(), "the seed reads back the same")
    local f = NS2.MaybeShowPresetPicker()
    f.dd.onSelect("healer")
    f.apply:__fire("OnClick")
    assertEqual(#shown, 0)
    assertFalse(f:IsShown())
end)

test("picker: a profile with no seed record always asks", function()
    local NS, m = fresh()   -- the harness's four: containers the seed never wrote
    local shown = popups(m)
    assertFalse(NS.Presets.SeedUntouched())
    local f = NS.MaybeShowPresetPicker()
    f.dd.onSelect("simple")
    f.apply:__fire("OnClick")
    assertEqual(#shown, 1)
    assertEqual(shown[1].a1, 4)
end)

-- ── /am preset with the first-run window up (review fixes) ───────────────────────────────────

test("picker: /am preset simple with the first-run window up is the player's close", function()
    local NS, m, calls = fresh()
    local shown = popups(m)
    m.__fireEvent("PLAYER_ENTERING_WORLD")
    local f = NS.PresetPicker.frame
    assertTrue(f ~= nil and f:IsShown())
    NS.Slash:OnSlash("preset simple")
    assertFalse(f:IsShown(), "the window goes down")
    -- red under: the slash taking it down through the profile-event hide (no latch, no skin picker)
    assertTrue(NS.Presets.PickerSeen(), "the latch is set")
    assertEqual(#shown, 1, "the player's four: Replace asks")
    assertEqual(#calls, 0, "no skin picker over the confirm")
    local dialog = m.StaticPopupDialogs.AURAMASTER_APPLY_PRESET
    dialog.OnAccept(shown[1], shown[1].data)
    dialog.OnHide(shown[1], shown[1].data)
    assertEqual(#calls, 1, "the skin picker is offered once the confirm is answered")
    dialog.OnHide(shown[1], shown[1].data)
    assertEqual(#calls, 1, "once")
    assertEqual(#NS.Database.GetContainers(), NS.PresetData.Count("simple"))
end)

test("picker: /am preset with the window up offers the skin picker on a Cancel too", function()
    local NS, m, calls = fresh()
    local shown = popups(m)
    NS.MaybeShowPresetPicker()
    NS.Slash:OnSlash("preset advanced")
    assertTrue(NS.Presets.PickerSeen())
    m.StaticPopupDialogs.AURAMASTER_APPLY_PRESET.OnHide(shown[1], shown[1].data)   -- Cancel
    assertEqual(#calls, 1)
    assertEqual(#NS.Database.GetContainers(), 4, "nothing written")
end)

test("picker: /am preset with the window down leaves the latch alone", function()
    local NS, m, calls = fresh()
    local shown = popups(m)
    NS.Slash:OnSlash("preset simple")
    m.StaticPopupDialogs.AURAMASTER_APPLY_PRESET.OnHide(shown[1], shown[1].data)
    assertFalse(NS.Presets.PickerSeen(), "no window closed: the first-run picker is still owed")
    assertEqual(#calls, 0)
end)

-- ── frame-layering-§4: a confirm shown first stays above the window ──────────────────────────

test("picker: showing re-raises a shown StaticPopup", function()
    local NS, m = fresh()
    local raised = {}
    local function popupFrame(name, isShown)
        return { IsShown = function() return isShown end, Raise = function() raised[#raised + 1] = name end }
    end
    m.StaticPopup1 = popupFrame("StaticPopup1", true)
    m.StaticPopup2 = popupFrame("StaticPopup2", false)
    -- red under: show() raising its own window and nothing else
    NS.ShowPresetPicker()
    assertEqual(#raised, 1, "the shown popup, not the hidden one")
    assertEqual(raised[1], "StaticPopup1")
    m.StaticPopup1, m.StaticPopup2 = nil, nil
end)

-- ── the confirm is answered as things stand when it is answered (AM-PR08 review fixes) ───────

test("picker: a pick made under the confirm still applies what the confirm named", function()
    local NS, m, _, lines = fresh()
    NS.Presets.MarkPickerSeen()
    local shown = popups(m)
    local f = NS.ShowPresetPicker()
    f.dd.onSelect("advanced")
    f.apply:__fire("OnClick")
    assertEqual(shown[1].a2, "Advanced")
    f.dd.onSelect("simple")   -- the window stays usable under the confirm
    accept(m, shown[1])
    -- red under: the keep decided at the click (Simple's preview kept, Advanced announced)
    assertEqual(#NS.Database.GetContainers(), NS.PresetData.Count("advanced"), "what the confirm named")
    assertTrue(anyLine(lines, "Applied the Advanced preset"))
    assertFalse(NS.Presets.IsPreviewing(), "no snapshot left behind")
    assertFalse(f:IsShown())
end)

test("picker: combat under the confirm restores, and the answer still applies", function()
    local NS, m, _, lines = fresh()
    NS.Presets.MarkPickerSeen()
    local shown = popups(m)
    local f = NS.ShowPresetPicker()
    f.dd.onSelect("simple")
    f.apply:__fire("OnClick")
    NS.addon:OnCombatChanged("PLAYER_REGEN_DISABLED")
    assertFalse(NS.Presets.IsPreviewing(), "combat restored the preview")
    -- red under: a window repainted only by its own clicks (the preview line left showing)
    assertFalse(f.status:IsShown(), "the window no longer claims a preview")
    NS.addon:OnCombatChanged("PLAYER_REGEN_ENABLED")
    accept(m, shown[1])
    -- red under: EndPreview(true) on no preview ("No preset is being previewed.", nothing written)
    assertFalse(anyLine(lines, "No preset is being previewed."))
    assertEqual(#NS.Database.GetContainers(), NS.PresetData.Count("simple"))
    assertFalse(f:IsShown())
end)

test("picker: Not now under the confirm takes the confirm down with it", function()
    local NS, m = fresh()
    NS.Presets.MarkPickerSeen()
    local shown = popups(m)
    local before = ids(NS)
    local f = NS.ShowPresetPicker()
    f.dd.onSelect("healer")
    f.apply:__fire("OnClick")
    f.notNow:__fire("OnClick")
    -- red under: a confirm that outlives the window that raised it
    assertTrue(shown[1].hidden, "the confirm goes down with the window")
    m.StaticPopupDialogs.AURAMASTER_APPLY_PRESET.OnAccept(shown[1], shown[1].data)
    assertEqual(ids(NS), before, "a late answer writes nothing")
end)

test("picker: a profile event takes an open preset confirm down unanswered", function()
    local NS, m, calls = fresh()
    local shown = popups(m)
    NS.Slash:OnSlash("preset healer")
    assertEqual(shown[1].a1, 4)
    NS.db:SetProfile("ConfirmProbe")
    -- red under: the confirm left up, its Replace then run on a profile it never counted
    assertTrue(shown[1].hidden, "the profile event hides it")
    local held = #NS.Database.GetContainers()
    m.StaticPopupDialogs.AURAMASTER_APPLY_PRESET.OnAccept(shown[1], shown[1].data)
    assertEqual(#NS.Database.GetContainers(), held, "nothing written into the new profile")
    assertEqual(#NS.db.sv.profiles.Default.containerOrder, 4, "nor the old one")
    assertEqual(#calls, 0, "a hide this addon makes offers no skin picker")
end)

-- ── placed centered, opened unlocked, lock and test mode on the window (AM-PR10; spec section 15) ──

--- Record the window's own anchor on UIParent (`rec.anchor`) and the heights its layout sets
--- (`rec.heights`), as the shape case records its setters.
local function recordWindow(m)
    local rec, real = { heights = {} }, m.CreateFrame
    m.CreateFrame = function(kind, name, parent, template)
        local f = real(kind, name, parent, template)
        if name == WINDOW then
            rawset(f, "SetPoint", function(self, ...)
                if select(2, ...) == m.UIParent then rec.anchor = { ... } end
                return self
            end)
            rawset(f, "SetHeight", function(self, v) rec.heights[#rec.heights + 1] = v; return self end)
        end
        return f
    end
    return rec
end

--- Whether two { left, right, top, bottom } rectangles share any area.
local function intersects(a, b)
    return a.left < b.right and b.left < a.right and a.bottom < b.top and b.bottom < a.top
end

--- The LibKa0s skin picker's rectangle on a W x H parent: centered across, its center `skinShare` of
--- the way up (libs/LibKa0s/OptionsSkinPicker.lua's place()), the size PresetData.ROOM gives it.
local function skinRect(R, W, H)
    local cy = H * R.skinShare
    return { left = W / 2 - R.skinWidth / 2, right = W / 2 + R.skinWidth / 2,
        top = cy + R.skinHeight / 2, bottom = cy - R.skinHeight / 2 }
end

--- Record what the lock and test-mode buttons say (the kit's font strings are the frame itself and
--- keep no text), then repaint the window so both say it now: `label(btn)` reads the last one.
local function recordLabels(NS, f)
    for _, btn in ipairs({ f.lockToggle, f.testToggle }) do
        rawset(btn.text, "SetText", function(self, v) rawset(self, "__label", v); return self end)
    end
    NS.RefreshPresetPicker()
end

local function label(btn) return rawget(btn.text, "__label") end

test("picker: opens centered below the call-outs", function()
    local NS, m = fresh()
    local rec = recordWindow(m)
    local R = NS.PresetData.ROOM
    NS.Presets.ParentSize = function() return 2560, 1440 end
    local f = NS.MaybeShowPresetPicker()
    local place = NS.PresetPicker.Placement(2560, 1440)
    -- red under: the window on the left edge, vertically centered (LEFT, 24, 0), over the call-outs
    assertEqual(rec.anchor[1], "TOP", "placed by its top")
    assertEqual(rec.anchor[3], "BOTTOM", "on UIParent's bottom edge")
    assertEqual(rec.anchor[4], 0, "centered across")
    assertEqual(rec.anchor[5], place.top, "at the placement's top")
    assertEqual((place.left + place.right) / 2, 1280, "the placement is centered across")
    for _, name in ipairs({ "advanced", "healer" }) do
        for _, look in ipairs(NS.PresetData.LOOKS) do
            local block = NS.PresetData.CalloutRect(name, look, 2560, 1440)
            assertTrue(place.top <= block.bottom - R.margin, name .. "/" .. look .. ": under the call-out block")
        end
    end
    assertTrue(place.bottom >= R.margin, "above the bottom edge")
    -- The window's laid-out height fits the room the call-outs leave it, in every state it shows.
    f.dd.onSelect("advanced")
    for _, h in ipairs(rec.heights) do assertTrue(h <= R.pickerHeight, "laid out within its room: " .. h) end
    f.notNow:__fire("OnClick")
    -- UIParent unreadable: placed for 1920 x 1080.
    NS.Presets.ParentSize = function() return 0, 0 end
    NS.ShowPresetPicker()
    assertEqual(rec.anchor[5], NS.PresetPicker.Placement(1920, 1080).top, "the fallback")
end)

-- Advanced's three call-outs do not fit between the skin picker and the picker at 1080: at the
-- smallest size (24) the unlocked test-mode block is 520 tall, and the room under the skin picker
-- holds less than that plus the picker's. The picker then sits at the bottom edge, over the block's
-- lower lines; docs/known-limitations.md records it for the owner's call (AM-PR10).
local OVERLAPS_AT_1080 = { advanced = true }

test("presets data: the call-out block, the picker and the skin picker do not intersect at 1080", function()
    local NS = fresh()
    local D, R = NS.PresetData, NS.PresetData.ROOM
    -- 16:9, 16:10, 21:9, 4:3 and 5:4 at 1080 tall.
    for _, W in ipairs({ 1920, 1728, 2520, 1440, 1350 }) do
        local place, skin = NS.PresetPicker.Placement(W, 1080), skinRect(R, W, 1080)
        assertFalse(intersects(place, skin), W .. ": the picker clear of the skin picker")
        assertTrue(place.bottom >= R.margin and place.left >= 0 and place.right <= W, W .. ": the picker on the screen")
        for _, name in ipairs({ "advanced", "healer" }) do
            for _, look in ipairs(D.LOOKS) do
                local block, where = D.CalloutRect(name, look, W, 1080), ("%s/%s at %d"):format(name, look, W)
                assertFalse(intersects(block, skin), where .. ": the call-outs clear of the skin picker")
                if OVERLAPS_AT_1080[name] then
                    -- The exception is forced, not chosen: the smallest block and the picker's room
                    -- do not fit under the skin picker together.
                    assertEqual(block.fontSize, D.CALLOUT_SIZE_MIN, where .. ": already the smallest size")
                    assertTrue(block.height + R.pickerHeight + 3 * R.margin > skin.bottom, where .. ": no room for both")
                    assertEqual(place.bottom, R.margin, where .. ": the picker as low as it goes")
                else
                    -- red under: a placement that ignores the call-outs (the screen's middle, centered)
                    assertFalse(intersects(block, place), where .. ": the call-outs clear of the picker")
                end
            end
        end
    end
end)

test("picker: opening unlocks and remembers the lock", function()
    local NS = fresh()
    assertTrue(NS.GetSetting("locked"), "a new profile is locked")
    local writes, real = {}, NS.SetByPath
    NS.SetByPath = function(path, ...) writes[#writes + 1] = path; return real(path, ...) end
    local f = NS.MaybeShowPresetPicker()
    NS.SetByPath = real
    -- red under: a window that opens over locked containers
    assertFalse(NS.GetSetting("locked"), "opening unlocks")
    assertEqual(writes[1], "locked", "through the seam /am unlock writes")
    NS.ShowPresetPicker()
    f.notNow:__fire("OnClick")
    assertTrue(NS.GetSetting("locked"), "the lock it found, back")
    -- Opened over unlocked containers, it leaves them unlocked.
    NS.SetByPath("locked", false)
    f = NS.ShowPresetPicker()
    assertFalse(NS.GetSetting("locked"))
    f.notNow:__fire("OnClick")
    assertFalse(NS.GetSetting("locked"), "unlocked at the open, unlocked after")
end)

test("picker: the lock button flips the lock", function()
    local NS = fresh()
    local f = NS.MaybeShowPresetPicker()
    assertTrue(f.lockToggle ~= nil, "a lock button")
    recordLabels(NS, f)
    assertEqual(label(f.lockToggle), NS.L["Containers: unlocked"], "it says the lock")
    f.lockToggle:__fire("OnClick")
    -- red under: a button that writes nothing, or a label that keeps the old state
    assertTrue(NS.GetSetting("locked"), "locked")
    assertEqual(label(f.lockToggle), NS.L["Containers: locked"])
    f.lockToggle:__fire("OnClick")
    assertFalse(NS.GetSetting("locked"), "unlocked again")
    -- /am lock while the window is up repaints it.
    NS.Slash:OnSlash("lock")
    assertEqual(label(f.lockToggle), NS.L["Containers: locked"], "a lock made elsewhere shows")
end)

test("picker: the test button flips test mode, and turning it off ends a preview", function()
    local NS = fresh()
    local before = ids(NS)
    local f = NS.MaybeShowPresetPicker()
    assertTrue(f.testToggle ~= nil, "a test-mode button")
    recordLabels(NS, f)
    assertEqual(label(f.testToggle), NS.L["Test mode: off"])
    f.testToggle:__fire("OnClick")
    assertTrue(NS.State.testMode, "on")
    assertEqual(label(f.testToggle), NS.L["Test mode: on"])
    assertFalse(NS.Presets.IsPreviewing(), "test mode alone previews nothing")
    f.testToggle:__fire("OnClick")
    assertFalse(NS.State.testMode, "off")
    f.dd.onSelect("advanced")
    assertTrue(NS.Presets.IsPreviewing() and NS.State.testMode)
    assertEqual(label(f.testToggle), NS.L["Test mode: on"], "a pick's test mode shows")
    f.testToggle:__fire("OnClick")
    -- red under: test mode off with the preset's containers left in the profile
    assertFalse(NS.State.testMode)
    assertFalse(NS.Presets.IsPreviewing(), "the preview ends, as Not now ends it")
    assertEqual(ids(NS), before, "the player's own containers back")
    assertFalse(f.status:IsShown(), "the window no longer claims a preview")
    assertTrue(f:IsShown(), "and stays up")
end)

test("picker: apply leaves containers locked and test mode off", function()
    local NS = fresh({ simple = true })
    NS.SetByPath("locked", false)
    local f = NS.MaybeShowPresetPicker()
    f.dd.onSelect("advanced")
    f.apply:__fire("OnClick")
    -- red under: Apply putting back the unlocked state the window found
    assertFalse(f:IsShown())
    assertEqual(#NS.Database.GetContainers(), 20)
    assertTrue(NS.GetSetting("locked"), "locked")
    assertFalse(NS.State.testMode, "test mode off")
    -- Nothing picked, test mode on by the button: Apply still locks and turns it off.
    f = NS.ShowPresetPicker()
    f.testToggle:__fire("OnClick")
    assertTrue(NS.State.testMode)
    f.apply:__fire("OnClick")
    assertTrue(NS.GetSetting("locked"))
    assertFalse(NS.State.testMode)
end)

test("picker: not now, close and escape put the lock back and test mode off", function()
    local routes = {
        ["not now"] = function(f) f.notNow:__fire("OnClick") end,
        close = function(f) f.close:__fire("OnClick") end,
        escape = function(f) f:Hide(); f:__fire("OnHide") end,
    }
    for route, close in pairs(routes) do
        for _, lockedAtOpen in ipairs({ true, false }) do
            local NS = fresh()
            NS.SetByPath("locked", lockedAtOpen)
            local before = ids(NS)
            local f = NS.MaybeShowPresetPicker()
            f.dd.onSelect("healer")
            f.lockToggle:__fire("OnClick")
            f.lockToggle:__fire("OnClick")
            f.lockToggle:__fire("OnClick")   -- left locked, whatever it opened on
            close(f)
            local where = ("%s, opened %s"):format(route, lockedAtOpen and "locked" or "unlocked")
            assertEqual(NS.GetSetting("locked") == true, lockedAtOpen, where .. ": the lock it found")
            assertFalse(NS.State.testMode, where .. ": test mode off")
            assertEqual(ids(NS), before, where .. ": restored as before")
        end
    end
    -- Test mode the button turned on, with nothing picked, goes off too.
    local NS = fresh()
    local f = NS.MaybeShowPresetPicker()
    f.testToggle:__fire("OnClick")
    f.notNow:__fire("OnClick")
    assertFalse(NS.State.testMode)
    assertTrue(NS.GetSetting("locked"))
end)

test("picker: /am preset opens unlocked too", function()
    local NS = fresh()
    NS.Presets.MarkPickerSeen()
    NS.Slash:OnSlash("preset")
    local f = NS.PresetPicker.frame
    assertTrue(f ~= nil and f:IsShown())
    assertFalse(NS.GetSetting("locked"), "unlocked")
    f.close:__fire("OnClick")
    assertTrue(NS.GetSetting("locked"))
end)

test("picker: a hide this addon makes puts the lock back and test mode off", function()
    local NS = fresh()
    local f = NS.MaybeShowPresetPicker()
    f.testToggle:__fire("OnClick")
    NS.HidePresetPicker()
    assertTrue(NS.GetSetting("locked"), "the stand-down's hide puts the lock back")
    assertFalse(NS.State.testMode)
    assertFalse(f:IsShown())
end)

-- ── the review fixes: a profile event, `/am preset <name>` and a drag under the preview (AM-PR10) ──

test("picker: a profile switch puts the lock back in the profile it opened on", function()
    local NS = fresh()
    local f = NS.MaybeShowPresetPicker()
    local default = NS.db.profile
    assertFalse(NS.GetSetting("locked"), "opened unlocked")
    NS.db:SetProfile("LockProbe")
    -- red under: the lock written only while the profile is still the active one, after the swap
    -- AceDB strips a value equal to its default from the profile it leaves: nil reads locked.
    assertTrue(default.locked ~= false, "the profile left is locked, as it was found")
    assertTrue(f:IsShown(), "offered again to the new profile")
    assertFalse(NS.GetSetting("locked"), "the new profile's own lock, taken off by its showing")
    NS.db:SetProfile("Default")
    assertTrue(NS.db.sv.profiles.LockProbe.locked ~= false, "the probe profile back to locked too")
    assertTrue(f:IsShown(), "Default has not closed it: shown again")
    f.notNow:__fire("OnClick")
    assertTrue(NS.GetSetting("locked"), "Not now on Default: the lock it found there")
    -- An unlocked profile stays unlocked through the same round trip.
    NS.SetByPath("locked", false)
    NS.ShowPresetPicker()
    NS.db:SetProfile("LockProbe")
    assertTrue(default.locked == false, "unlocked when found, unlocked when left")
end)

test("picker: a profile reset under the window keeps the reset's lock", function()
    local NS = fresh()
    NS.SetByPath("locked", false)
    local f = NS.MaybeShowPresetPicker()
    NS.db:ResetProfile()
    -- red under: the hide writing the lock the window found over the reset's default
    assertTrue(f:IsShown(), "a reset profile is offered it again")
    f.notNow:__fire("OnClick")
    assertTrue(NS.GetSetting("locked"), "the default lock, as the reset wrote it")
end)

test("picker: /am preset <name> with the window up puts the lock back and test mode off", function()
    for _, lockedAtOpen in ipairs({ true, false }) do
        local NS, m = fresh()
        local shown = popups(m)
        NS.SetByPath("locked", lockedAtOpen)
        local f = NS.MaybeShowPresetPicker()
        f.dd.onSelect("advanced")
        assertTrue(NS.State.testMode)
        NS.Slash:OnSlash("preset healer")
        local where = lockedAtOpen and "opened locked" or "opened unlocked"
        -- red under: the window going down with the containers left as it set them
        assertFalse(f:IsShown(), where .. ": the window down")
        assertEqual(NS.GetSetting("locked") == true, lockedAtOpen, where .. ": the lock it found")
        assertFalse(NS.State.testMode, where .. ": test mode off")
        accept(m, shown[1])
        assertEqual(NS.GetSetting("locked") == true, lockedAtOpen, where .. ": the answer keeps it")
        assertFalse(NS.State.testMode, where .. ": still off")
        assertTrue(NS.Presets.PickerSeen(), where .. ": a close of the window")
    end
end)

test("picker: a container dragged under the preview keeps its drop on Apply", function()
    local NS = fresh({ simple = true })
    local f = NS.MaybeShowPresetPicker()
    f.dd.onSelect("advanced")
    local id = NS.Database.GetContainers()[1].id
    local drop = { point = "CENTER", relativePoint = "CENTER", x = 123.4, y = -56.7 }
    -- What a drag stop stores (modules/Anchors.lua, SavePosition): the whole section, on this container.
    assertTrue(NS.SetByPath("container.position", drop, id))
    f.apply:__fire("OnClick")
    -- red under: Apply rebuilding the preset from its data over the drop
    assertFalse(f:IsShown())
    assertFalse(NS.Presets.IsPreviewing())
    local kept = NS.GetSetting("container.position", id)
    assertEqual(kept.point, "CENTER")
    assertEqual(kept.x, 123.4, "where it was dragged to")
    assertEqual(kept.y, -56.7)
    assertTrue(NS.GetSetting("locked"), "locked")
    assertFalse(NS.State.testMode, "test mode off")
end)
