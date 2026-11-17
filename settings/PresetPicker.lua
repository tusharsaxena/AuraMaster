local addonName, NS = ...

-- settings/PresetPicker.lua -- the first-run preset picker and the preset confirm (spec
-- docs/superpowers/specs/2026-11-14-auramaster-presets-design.md, sections 5, 6 and 7).
--
-- WHAT IT PUBLISHES
--
--   NS.PresetPickerDue()       true while the active profile or the account (spec section 18.5) has
--                              not closed the picker and the addon stands up: what the login and
--                              every profile event ask.
--   NS.MaybeShowPresetPicker() the first-run showing, when due; in combat held for
--                              PLAYER_REGEN_ENABLED (one target at most). Answers the window or nil.
--   NS.ShowPresetPicker()      `/am preset`: the window on demand, whatever the latch says; refused
--                              in combat with the combat line.
--   NS.HidePresetPicker(r)     takes the window down WITHOUT marking it seen, ending a preview it
--                              started with a restore, drops a held start and takes down an open
--                              preset confirm unanswered: the stand-down, every profile event and
--                              the logout.
--                              `r` true when the active profile was just replaced (a reset or a
--                              copy): the lock is then left as the replacement wrote it.
--   NS.RefreshPresetPicker()   repaints the window from what is on the screen: NS.Presets calls it
--                              whenever a preview ends, so one combat or another surface ended does
--                              not leave the window claiming it is still up.
--   NS.PresetPickerHolding()   true while the window is up or a start is held: core/SkinSetup.lua's
--                              skin picker waits behind it, so the two never show at once.
--   NS.ConfirmPreset(n, l, m)  apply preset `n` in style `l`, mode `m`, behind the confirm that names
--                              the count it removes (Replace) or adds (Add): `/am preset <name>`, and
--                              the Presets tab with no preview of its own up. With the window up, it
--                              is the player's close of it: latch set, skin picker offered once the
--                              confirm is answered.
--   NS.ConfirmPreview(n, l, m) the same confirm over a preview that stays up while it is open, then
--                              kept: the General page's Presets tab (settings/GeneralPresets.lua).
--   NS.PresetPicker            { frame, Placement }: the window once built, for the suites, and
--                              Placement(w, h), where it opens on a w x h UIParent (below).
--
-- WHEN. Once per profile, and once per account (spec section 18.5: a player whose profiles predate
-- the presets sees it once, on whatever profile is active), before the skin picker: addon:OnEnterWorld shows it at once (it does not
-- wait the skin picker's two seconds) and arms no skin start while it is due; every close calls
-- NS.MaybeShowSkinPicker, which shows the skin picker only now. A new, reset or copied profile is
-- offered it again after the profile event (core/AuraMaster.lua's rebuildProfile).
--
-- WHERE IT OPENS (spec section 15.1). Where the LibKa0s skin picker does: centered across, its CENTER
-- 75% of the way up UIParent (libs/LibKa0s/OptionsSkinPicker.lua place()), the bare CENTER when
-- UIParent's height cannot be read. The two never show at once (the skin picker is hidden while this
-- window is up), so they share the spot. UIParent is read each time it opens. The spot depends on no
-- preset: the builder places every preset's call-out block clear of it
-- (NS.PresetData.CalloutRect, unlocked, in test mode, under PresetData.ROOM).
--
-- THE LOCK AND TEST MODE. Opening records the lock, unlocks the containers and turns test mode on
-- (owner, 2026-11-15), the lock through the seam
-- `/am unlock` writes (NS.SetByPath "locked"). Two buttons show and flip the lock and test mode (test
-- mode through NS.Preview.SetTestMode, as `/am test`); turning test mode off while a preview is up
-- ends it with a restore, as Not now does. Apply locks and turns test mode off; Not now, the close
-- control, Escape and this addon's own hides put back the lock the window found, and turn test mode
-- off. A switch takes the window down at AceDB's OnProfileShutdown (core/AuraMaster.lua), while the
-- profile it opened on is still the active one, so its lock goes back through the seam before the
-- swap; a reset or a copy replaces the profile whole, and its hide writes no lock over what the
-- replacement holds. A logout or a /reload takes it down at AceDB's OnDatabaseShutdown, before
-- SavedVariables are written, so the lock it found (held only in `state`) is what is saved.
--
-- WHAT A PICK DOES. Nothing is previewed when the window opens: the profile already holds what it
-- holds (Simple, on a new one). A pick of a preset or a style previews it on the real screen in
-- test mode (NS.Presets.BeginPreview); Empty too, as an empty screen. Every pick leaves the
-- containers unlocked and test mode on (spec section 19). Apply keeps the pick (EndPreview(true,
-- "replace"), or Apply afresh when a preview combat ended or another pick swapped); with nothing
-- picked it keeps what is there. Not now, the close control and Escape restore (EndPreview(false)).
-- Every close the player makes sets both latches, `presets.pickerSeen` and the account's
-- `global.presets.pickerSeen`, through NS.Presets.
--
-- THE CONFIRM. Replace asks first, naming the count it removes, except on the first-run showing
-- while the profile still holds exactly what its seed wrote (NS.Presets.SeedUntouched), where
-- nothing of the player's is lost (spec section 5). A container made, deleted or edited since, in
-- this session or before a /reload, and it asks. What an answer writes is decided when it is given,
-- not when the confirm was raised: the window stays usable under it, so the preview may have been
-- swapped, restored by combat or ended since, and the answer still writes the preset the confirm
-- named. A confirm never outlives what raised it: the window's close and every hide this addon
-- makes take it down (a profile event would otherwise let it write into a profile it never counted).
--
-- BUILT FROM THE LIBRARY'S PIECES: the window's shell and close mark through core/CoreSetup.lua's
-- seams (NS.ApplySkin, NS.MakeCloseButton), the dropdown and the footer are LibKa0s-Widgets-1.0's
-- (the footer W.Footer, FOOTER.HEIGHT tall on the window's bottom edge, LibKa0s#89), and every
-- button, tab and string is painted through this owner's skin facade (NS.Skin), each member guarded
-- so the degraded facade draws stock frames. DIALOG strata, as the skin picker (frame-layering-§1);
-- toplevel, and on show it re-raises any shown StaticPopup, so it never buries a confirm
-- (frame-layering-§4, through LibKa0s-Core-1.0's RaiseStaticPopups).

local L = NS.L

NS.PresetPicker = NS.PresetPicker or {}
local Picker = NS.PresetPicker

local KW = LibStub and LibStub("LibKa0s-Widgets-1.0", true)
local KC = LibStub and LibStub("LibKa0s-Core-1.0", true)

local WINDOW = "AuraMasterPresetPicker"
local POPUP = "AURAMASTER_APPLY_PRESET"
local WIDTH, PAD, ROW_H, GAP = 300, 14, 22, 8
local FALLBACK_W, FALLBACK_H = 1920, 1080   -- UIParent's size when it cannot be read

-- The dropdown's order (spec section 7): Empty first, then the four presets.
local CHOICES = { "empty", "simple", "intermediate", "advanced", "healer" }
local LABELS = {
    empty = L["Empty"], simple = L["Simple"], intermediate = L["Intermediate"],
    advanced = L["Advanced"], healer = L["Healer"],
}
local BLURBS = {
    empty = L["No containers: start from a blank screen and build your own."],
    simple = L["Your buffs, weapon enchants and debuffs in the top-right corner."],
    intermediate = L["Simple, plus your short buffs and cooldowns, your debuffs on the target, the target's cooldowns and your debuffs on focus."],
    advanced = L["Everything: cooldown call-outs in the middle, the full target stack, icon rows and two special lists you fill yourself."],
    healer = L["Simple, plus your heals and what you can dispel on target and focus, your cooldowns and raid cooldowns."],
}
local LOOK_LABELS = { bars = L["Bars"], icons = L["Icons"] }

-- The window's session state. `sel` and `look` are what the controls show; `picked` is whether the
-- player chose anything since it opened; `firstRun` whether this showing is the first-run one (no
-- confirm); `owns` whether the preview up is the one this window started; `lockedAtOpen` the lock
-- it found, and `lockProfile` the profile it found it in (nil while the window is down); `open`
-- whether this showing has not closed yet, so its close prints the unlock hint once.
local state = { sel = "simple", look = "bars", picked = false, firstRun = false, owns = false,
    lockedAtOpen = true, lockProfile = nil, open = false }
local closing = false   -- true while this file hides the window itself, so OnHide is not a close
local holdTarget        -- the one-shot PLAYER_REGEN_ENABLED target, while a start is held
local pending           -- the open confirm's data ({ run, after }), nil while none is up

local function sayGray(msg) NS.Printf("|cff808080%s|r", msg) end

--- A refusal from NS.Presets: gray when it says so (its combat lines), plain otherwise.
local function say(msg, gray)
    if not msg then return end
    if gray then sayGray(msg) else NS.Print(msg) end
end

--- Call the skin facade's `member` when it has one (the degraded facade has no Button, Tab or Header).
local function paint(member, ...)
    local fn = NS.Skin and NS.Skin[member]
    if type(fn) == "function" then return fn(...) end
end

--- The dropdown's label for preset `name`: its name and its container count.
local function choiceLabel(name)
    local n = NS.PresetData.Count(name)
    if n == 0 then return L["%s - no containers"]:format(LABELS[name]) end
    return L["%s - %d containers"]:format(LABELS[name], n)
end

-- ── the confirm ──────────────────────────────────────────────────────────────────────────────

StaticPopupDialogs[POPUP] = {
    text         = L["Replace your %s containers with the %s preset? Your containers are deleted."],
    button1      = L["Apply"],
    button2      = L["Cancel"],
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    OnAccept     = function(_, data)
        if type(data) == "table" and type(data.run) == "function" then data.run() end
    end,
    -- Every answer hides it (Apply, Cancel, Escape): what waits on the answer runs here, once.
    OnHide       = function(self, data)
        data = data or (self and self.data)
        if data == pending then pending = nil end
        local after = type(data) == "table" and data.after or nil
        if type(after) == "function" then data.after = nil; after() end
    end,
}

--- Ask before `run` when the count is worth asking about: `count` containers the player would lose
--- (Replace) or the preset's count added (Add). `ask` false runs at once. `after`, when given, runs
--- once the question is settled: after `run`, or when the confirm hides, whatever the answer.
local function confirmThen(name, mode, count, ask, run, after)
    if not ask then
        local r = run()
        if after then after() end
        return r
    end
    local dialog = StaticPopupDialogs[POPUP]
    local a1, a2 = count, LABELS[name]
    if mode == "add" then
        dialog.text = L["Add the %s preset's %s containers next to your own?"]
        a1, a2 = LABELS[name], NS.PresetData.Count(name)
    else
        dialog.text = L["Replace your %s containers with the %s preset? Your containers are deleted."]
    end
    local popup = StaticPopup_Show(POPUP, a1, a2)
    if popup then
        pending = { run = run, after = after }
        popup.data = pending
    elseif after then
        after()
    end
    return nil
end

--- Take an open preset confirm down unanswered: what it would have run never runs, and what waits on
--- its answer is dropped too (the hide is this addon's, not the player's).
local function dropConfirm()
    local data = pending
    if not data then return end
    pending = nil
    data.run, data.after = function() end, nil
    if StaticPopup_Hide then StaticPopup_Hide(POPUP) end
end

--- The line every close of the window by the player earns, once (spec section 17.5): where unlock
--- mode is, now the window that unlocked the containers is gone.
local function sayUnlockHint()
    NS.Print(L["Type /am unlock to enter unlock mode and move your containers."])
end

--- The line a kept preset earns.
local function sayApplied(name, look, mode)
    local fmt = mode == "add" and L["Added the %s preset (%s) next to your containers."] or L["Applied the %s preset (%s)."]
    NS.Printf(fmt, LABELS[name], name == "empty" and L["Bars"] or LOOK_LABELS[look])
end

--- Apply preset `name` in style `look`, `mode` "replace" or "add", behind the confirm: Replace asks
--- when the player has containers to lose, Add always says what it adds. A preview up is ended (a
--- restore) first, so the write lands on the player's own containers. With the window up this is the
--- player's close of it: it goes down with its preview restored, the latch is set, and the skin
--- picker gets its turn once the confirm is answered (not under it). Refused in combat with Apply's
--- own line. Answers true when the write ran now, nil when it waits for the answer.
function NS.ConfirmPreset(name, look, mode)
    if InCombatLockdown() then
        return sayGray(L["cannot apply a preset during combat — its containers would not be drawn or placed until combat ends"])
    end
    if name == "empty" and mode == "add" then return NS.Print(L["The Empty preset has no containers to add."]) end
    local f = Picker.frame
    local closesWindow = f ~= nil and f:IsShown() == true
    NS.HidePresetPicker()
    if closesWindow then NS.Presets.MarkPickerSeen() end
    if NS.Presets.IsPreviewing() then NS.Presets.EndPreview(false) end
    local count = #NS.Database.GetContainers()
    local ask = mode == "add" or count > 0
    -- The window's close: the unlock hint and the skin picker once the confirm is answered.
    local after = closesWindow and function()
        sayUnlockHint()
        if NS.MaybeShowSkinPicker then NS.MaybeShowSkinPicker() end
    end or nil
    return confirmThen(name, mode, count, ask, function()
        local ok, msg, gray = NS.Presets.Apply(name, look, mode)
        if not ok then return say(msg, gray) end
        if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
        sayApplied(name, look, mode)
        return true
    end, after)
end

--- Keep the preview of preset `name` in style `look`, `mode` "replace" or "add", behind the same
--- confirm: the General page's Presets tab. The preview stays on screen while the question is
--- open; the count a Replace names is the player's own (the snapshot's). Answered, the preview is
--- kept (EndPreview(true, mode)) when it is still the one asked about; one ended or swapped since
--- (the tab left, combat) is restored and the preset applied afresh, so the answer always writes what
--- the confirm named. With no preview up this is NS.ConfirmPreset. Answers as it does.
function NS.ConfirmPreview(name, look, mode)
    local P = NS.Presets
    if not P.IsPreviewing() then return NS.ConfirmPreset(name, look, mode) end
    if InCombatLockdown() then
        return sayGray(L["cannot apply a preset during combat — its containers would not be drawn or placed until combat ends"])
    end
    local count = P.OwnContainerCount()
    return confirmThen(name, mode, count, mode == "add" or count > 0, function()
        local n, l = P.Previewed()
        local ok, msg, gray
        if n == name and l == look then
            ok, msg, gray = P.EndPreview(true, mode)
        else
            if P.IsPreviewing() then P.EndPreview(false) end
            ok, msg, gray = P.Apply(name, look, mode)
        end
        if not ok then return say(msg, gray) end
        if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
        sayApplied(name, look, mode)
        return true
    end)
end

-- ── the lock and test mode ───────────────────────────────────────────────────────────────────

local refresh   -- below: repaints the controls from `state`
local paintToggles   -- below: the lock and test-mode buttons' labels

--- Write the lock through the seam `/am lock` and `/am unlock` write (settings/Slash.lua's runLock).
local function setLock(locked)
    local ok, err = NS.SetByPath("locked", locked)
    if not ok then say(err) end
end

--- Turn test mode off, when it is on.
local function testModeOff()
    if NS.State.testMode then NS.Preview.SetTestMode(false, "preset picker") end
end

--- Record the lock the window opens on, then unlock (spec section 15) and turn test mode on (owner,
--- 2026-11-15): the window opens showing the containers as a pick would, unlocked and in test mode,
--- so the two buttons read *Containers: unlocked* and *Test mode: on* from the start.
local function openUnlocked()
    state.lockedAtOpen = NS.GetSetting("locked") and true or false
    state.lockProfile = NS.db and NS.db.profile
    setLock(false)
    if not NS.State.testMode then NS.Preview.SetTestMode(true, "preset picker") end
end

--- What every close and hide ends with: test mode off, then the lock set to `locked`, in the profile
--- the window opened on only. `replaced` (a reset or a copy, the profile's contents swapped whole)
--- writes no lock: the profile no longer holds the state the window found.
local function settle(locked, replaced)
    testModeOff()
    local same = state.lockProfile ~= nil and NS.db and NS.db.profile == state.lockProfile
    state.lockProfile = nil
    if same and not replaced then setLock(locked) end
end

local function toggleLock()
    setLock(not NS.GetSetting("locked"))
    refresh()
end

--- The test-mode button: on, or off. Off with a preview up ends it with a restore, as Not now does.
local function toggleTest()
    local P = NS.Presets
    if not NS.State.testMode then
        NS.Preview.SetTestMode(true, "preset picker")
    elseif P.IsPreviewing() then
        local ok, msg, gray = P.EndPreview(false)
        if not ok then say(msg, gray) end
    else
        testModeOff()
    end
    if not P.IsPreviewing() then state.owns = false end
    refresh()
end

-- ── the window's controls ────────────────────────────────────────────────────────────────────

--- Preview the selection on the real screen: the preset in its style, Empty as an empty screen (its
--- preview takes every container away until Apply). Every pick leaves the containers unlocked and
--- test mode on (BeginPreview turns it on), whatever the buttons were set to before it.
local function preview()
    local P = NS.Presets
    local look = (state.sel == "empty") and "bars" or state.look
    local ok, msg, gray = P.BeginPreview(state.sel, look)
    if ok then state.owns = true else say(msg, gray) end
    if NS.GetSetting("locked") then setLock(false) end
    refresh()
end

local function pickPreset(name)
    if not LABELS[name] then return end
    state.sel, state.picked = name, true
    preview()
end

local function pickLook(look)
    state.look = look
    if state.sel == "empty" then return refresh() end
    state.picked = true
    preview()
end

--- The player's close of any kind: the window down, its confirm with it, test mode off and the lock
--- set to `locked`, the latch set, the unlock hint (once per showing: `state.open`), then the skin
--- picker's turn.
local function finish(locked)
    local f = Picker.frame
    dropConfirm()
    settle(locked)
    closing = true
    if f then f:Hide() end
    closing = false
    state.picked, state.owns = false, false
    NS.Presets.MarkPickerSeen()
    if state.open then sayUnlockHint() end
    state.open = false
    if NS.MaybeShowSkinPicker then NS.MaybeShowSkinPicker() end
end

--- Not now, the close control, Escape: a preview this window started is restored.
local function dismiss()
    local P = NS.Presets
    if state.owns and P.IsPreviewing() then P.EndPreview(false) end
    finish(state.lockedAtOpen)
end

--- What Apply keeps, decided when the player answers: the preview this window started, while it is
--- still preset `sel` in style `look` (Empty matches on its name alone: it has no style); else `sel`
--- applied afresh (a preview combat ended or another pick swapped), Apply settling any preview still
--- up first.
local function keep(sel, look)
    local P = NS.Presets
    local n, l = P.Previewed()
    if state.owns and n == sel and (sel == "empty" or l == look) then
        return P.EndPreview(true, "replace")
    end
    return P.Apply(sel, look, "replace")
end

local function apply()
    if InCombatLockdown() then
        return sayGray(L["cannot apply a preset during combat — its containers would not be drawn or placed until combat ends"])
    end
    if not state.picked then return finish(true) end
    local sel, look = state.sel, state.look
    local count = NS.Presets.OwnContainerCount()
    -- No confirm only on the first-run showing over the untouched seed (spec section 5).
    local ask = count > 0 and not (state.firstRun and NS.Presets.SeedUntouched())
    confirmThen(sel, "replace", count, ask, function()
        local ok, msg, gray = keep(sel, look)
        if not ok then return say(msg, gray) end
        state.owns = false
        if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
        sayApplied(sel, look, "replace")
        finish(true)
        return true
    end)
end

-- ── building the window ──────────────────────────────────────────────────────────────────────

local function fontString(f, template, role)
    local fs = f:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    if fs.SetJustifyH then fs:SetJustifyH("LEFT") end
    if fs.SetJustifyV then fs:SetJustifyV("TOP") end
    paint("Text", fs, role or "body")
    return fs
end

local function textButton(f, text, onClick, opts)
    local btn = CreateFrame("Button", nil, f, "BackdropTemplate")
    btn:SetHeight(ROW_H)
    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("CENTER")
    fs:SetText(text)
    btn.text = fs
    btn:SetScript("OnClick", function() onClick() end)
    paint("Button", btn, opts)
    return btn
end

--- The preset dropdown: LibKa0s-Widgets-1.0's, or, without it, a button that steps through the
--- choices, so a degraded install can still pick.
local function buildDropdown(f)
    local width = WIDTH - 2 * PAD
    local options = {}
    for _, name in ipairs(CHOICES) do options[#options + 1] = { value = name, label = choiceLabel(name) } end
    local dd
    if KW and KW.Dropdown then
        dd = KW.Dropdown(f, width, { owner = addonName, chevron = NS.Icon and NS.Icon("chevron-down") or nil })
        dd:SetOptions(options)
    else
        dd = textButton(f, "", function() end)
        dd:SetWidth(width)
        dd.SetValue = function(self, _, label) self.text:SetText(label or "") end
        dd:SetScript("OnClick", function(self)
            local at = 1
            for i, name in ipairs(CHOICES) do if name == state.sel then at = i end end
            self.onSelect(CHOICES[at % #CHOICES + 1])
        end)
    end
    dd:SetHeight(ROW_H)
    dd.onSelect = function(value) pickPreset(value) end
    f.dd = dd
end

--- The Bars / Icons switch: two tabs, the selected one marked.
local function buildSwitch(f)
    local half = (WIDTH - 2 * PAD) / 2
    f.styleBars = textButton(f, L["Bars"], function() pickLook("bars") end)
    f.styleIcons = textButton(f, L["Icons"], function() pickLook("icons") end)
    for _, btn in ipairs({ f.styleBars, f.styleIcons }) do
        btn:SetWidth(half)
        paint("Tab", btn, { text = btn.text, selected = false })
    end
end

local function buildChrome(f)
    f.title = fontString(f, "GameFontNormal", "heading")
    f.title:SetText(L["Choose a preset"])
    f.close = NS.MakeCloseButton(f, function() dismiss() end)
    if f.close then
        f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    else
        f.close = textButton(f, "x", function() dismiss() end)
        f.close:SetWidth(ROW_H)
        f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    end
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -10)
    paint("Header", f, { title = f.title, right = { f.close } })
    f.owner = fontString(f, "GameFontNormal", "heading")
    f.owner:SetText("Ka0s Aura Master")
end

-- The footer's height with no library: the figure Widgets publishes (FOOTER.HEIGHT, minor 27).
local FOOTER_FALLBACK_H = 24

--- The footer's height, read where LibKa0s-Widgets-1.0 publishes it (FOOTER.HEIGHT, skin-invariant:
--- standalone-windows, *Window chrome geometry*), never copied here.
local function footerHeight()
    local F = KW and KW.FOOTER
    return type(F) == "table" and tonumber(F.HEIGHT) or FOOTER_FALLBACK_H
end

--- The window's footer (standalone-windows, *The footer*, LibKa0s#89): the library's W.Footer on the
--- window's bottom edge, no fill under a hairline in the skin's `divider`, its left line the "change
--- it later" hint in `text.muted`, painted from this addon's skin. Without the library (a degraded
--- install), a bare frame of the same height with the same `left` line and `SetLeft`, so the layout
--- and the text read the same.
local function buildFooter(f)
    if KW and type(KW.Footer) == "function" then
        f.footer = KW.Footer(f, { owner = addonName })
        return
    end
    local foot = CreateFrame("Frame", nil, f)
    foot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    foot:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    foot:SetHeight(FOOTER_FALLBACK_H)
    foot.left = fontString(foot, "GameFontHighlightSmall", "muted")
    foot.left:SetPoint("LEFT", foot, "LEFT", 8, 0)
    foot.left:SetPoint("RIGHT", foot, "RIGHT", -8, 0)
    foot.SetLeft = function(self, text) self.left:SetText(type(text) == "string" and text or "") end
    f.footer = foot
end

local function buildBody(f)
    buildDropdown(f)
    buildSwitch(f)
    f.blurb = fontString(f, "GameFontHighlightSmall")
    -- What comes after this window, on a first-run showing with the skin picker still due: a body
    -- line of its own under the blurb, not the footer's, whose one unwrapped line it would overrun
    -- (W.Footer's left line truncates; the review of AD-89-AM).
    f.nextHint = fontString(f, "GameFontHighlightSmall", "muted")
    f.nextHint:SetText(L["The skin picker opens next."])
    -- A row of its own, so the line shows and hides as one frame while a preview is up.
    f.status = CreateFrame("Frame", nil, f)
    f.status.text = fontString(f.status, "GameFontNormalSmall", "accent")
    f.status.text:SetAllPoints(f.status)
    f.status.text:SetText(L["On your screen now, filled with sample auras. Nothing is saved until Apply."])
    f.lockToggle = textButton(f, "", function() toggleLock() end)
    f.testToggle = textButton(f, "", function() toggleTest() end)
    f.apply = textButton(f, L["Apply"], function() apply() end, { primary = true })
    f.notNow = textButton(f, L["Not now"], function() dismiss() end)
    buildFooter(f)
end

local function build()
    local f = CreateFrame("Frame", WINDOW, UIParent, "BackdropTemplate")
    Picker.frame = f
    f:Hide()
    f:SetWidth(WIDTH)
    f:SetFrameStrata(NS.Constants.LAYERS.STRATA.MODAL)   -- T6, the skin picker's layer (frame-layering-§1)
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    -- Escape (UISpecialFrames) hides it: a close. A hide of UIParent (Alt-Z) fires OnHide with the
    -- window still shown, and a hide this file makes itself is not the player's: neither is a close.
    f:SetScript("OnHide", function(self)
        if closing or (self.IsShown and self:IsShown()) then return end
        dismiss()
    end)
    NS.ApplySkin(f)
    buildChrome(f)
    buildBody(f)
    local specials = _G.UISpecialFrames
    if type(specials) == "table" then table.insert(specials, WINDOW) end
    -- A lock or test mode switched elsewhere (`/am lock`, `/am test`, the launcher, combat) repaints
    -- the two buttons while the window is up.
    local ev = NS.NewBusTarget and NS.NewBusTarget()
    if ev then
        local function repaint() if f:IsShown() then paintToggles(f) end end
        ev:RegisterMessage(NS.MSG.CONFIG_CHANGED, function(_, payload)
            if type(payload) == "table" and payload.path == "locked" then repaint() end
        end)
        ev:RegisterMessage(NS.MSG.VISIBILITY_CHANGED, repaint)
    end
    return f
end

-- ── laying it out ────────────────────────────────────────────────────────────────────────────

--- One row under the last: `region` placed `h` tall, a GAP below the previous row.
local function stack(f, y, region, h, x, w)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", f, "TOPLEFT", x or PAD, -y)
    region:SetWidth(w or (WIDTH - 2 * PAD))
    region:SetHeight(h)
    return y + h + GAP
end

local function layout(f)
    local half = (WIDTH - 2 * PAD) / 2
    local y = stack(f, 34, f.owner, 16)
    y = stack(f, y, f.dd, ROW_H)
    if f.styleBars:IsShown() then
        stack(f, y, f.styleBars, ROW_H, PAD, half)
        y = stack(f, y, f.styleIcons, ROW_H, PAD + half, half)
    end
    y = stack(f, y, f.blurb, 44)
    if f.nextHint:IsShown() then y = stack(f, y, f.nextHint, 14) end
    if f.status:IsShown() then y = stack(f, y, f.status, 28) end
    stack(f, y, f.lockToggle, ROW_H, PAD, half - 3)
    y = stack(f, y, f.testToggle, ROW_H, PAD + half + 3, half - 3)
    local applyW = WIDTH - 2 * PAD - 90 - 6
    stack(f, y, f.apply, ROW_H, PAD, applyW)
    y = stack(f, y, f.notNow, ROW_H, PAD + applyW + 6, 90)
    -- The body ends a row gap above the footer, which sits on the bottom edge (W.Footer).
    f:SetHeight(y + footerHeight())
end

--- The lock and test-mode buttons say what is so now.
function paintToggles(f)
    f.lockToggle.text:SetText(NS.GetSetting("locked") and L["Containers: locked"] or L["Containers: unlocked"])
    f.testToggle.text:SetText(NS.State.testMode and L["Test mode: on"] or L["Test mode: off"])
end

function refresh()
    local f = Picker.frame
    if not f then return end
    local empty = state.sel == "empty"
    if f.dd.SetValue then f.dd:SetValue(state.sel, choiceLabel(state.sel)) end
    f.styleBars:SetShown(not empty)
    f.styleIcons:SetShown(not empty)
    paint("SetTabSelection", f.styleBars, state.look == "bars")
    paint("SetTabSelection", f.styleIcons, state.look == "icons")
    f.blurb:SetText(BLURBS[state.sel])
    f.status:SetShown(not empty and state.owns and NS.Presets.IsPreviewing())
    paintToggles(f)
    f.nextHint:SetShown((NS.SkinPickerDue and NS.SkinPickerDue()) and true or false)
    -- One short line, so it fits the footer's single unwrapped line whole (284 px on this window).
    f.footer:SetLeft(L["Change it later on General > Presets."])
    layout(f)
end

-- ── showing and hiding ───────────────────────────────────────────────────────────────────────

local function dropHold()
    if holdTarget then holdTarget:UnregisterAllEvents(); holdTarget = nil end
end

local function readable(v) return type(v) == "number" and v == v and v > 0 end

--- Where the window opens on a `parentW` x `parentH` UIParent (1920 x 1080 when either cannot be
--- read), in UIParent's own coordinates (from its bottom-left corner, as Frame:GetRect reads):
--- { left, right, top, bottom, width, height }. Centered across, its center the skin picker's share
--- (PresetData.ROOM.skinShare) of the way up, as tall as the room it is given
--- (PresetData.ROOM.pickerHeight, what its layout fits in). Pure.
--- @return table
function Picker.Placement(parentW, parentH)
    local R = NS.PresetData.ROOM
    local W = readable(parentW) and parentW or FALLBACK_W
    local H = readable(parentH) and parentH or FALLBACK_H
    local h, cy = R.pickerHeight, H * R.skinShare
    return { left = W / 2 - WIDTH / 2, right = W / 2 + WIDTH / 2, top = cy + h / 2, bottom = cy - h / 2,
        width = WIDTH, height = h }
end

--- Place the window as the skin picker's place() does, on UIParent's height as it reads now: its
--- CENTER the share of the way up from UIParent's BOTTOM, or the bare CENTER when it cannot be read.
local function place(f)
    local _, h = NS.Presets.ParentSize()
    f:ClearAllPoints()
    if readable(h) then
        f:SetPoint("CENTER", UIParent, "BOTTOM", 0, h * NS.PresetData.ROOM.skinShare)
    else
        f:SetPoint("CENTER")
    end
end

--- Show the window, fresh: Simple in Bars selected, nothing picked, nothing previewed, placed and
--- the containers unlocked. The skin picker goes down first, unmarked, so the two never show at
--- once; it comes back after the close.
local function show(firstRun)
    local f = Picker.frame or build()
    if not f:IsShown() then
        state.sel, state.look, state.picked, state.owns = "simple", "bars", false, false
        state.firstRun, state.open = firstRun, true
        place(f)
        openUnlocked()
    else
        state.firstRun = state.firstRun or firstRun
    end
    if NS.HideSkinPicker then NS.HideSkinPicker() end
    f:Show()
    refresh()
    if f.Raise then f:Raise() end
    -- A confirm shown before this window stays above it (frame-layering-§4).
    if KC and type(KC.RaiseStaticPopups) == "function" then KC.RaiseStaticPopups() end
    return f
end

function NS.PresetPickerDue()
    if not (NS.db and NS.db.profile and NS.Presets) then return false end
    if NS.IsStoodDown and NS.IsStoodDown() then return false end
    return not NS.Presets.PickerSeen()
end

function NS.PresetPickerHolding()
    local f = Picker.frame
    return holdTarget ~= nil or (f ~= nil and f:IsShown() == true)
end

function NS.MaybeShowPresetPicker()
    if not NS.PresetPickerDue() then return nil end
    if InCombatLockdown() then
        if holdTarget then return nil end
        holdTarget = NS.NewBusTarget and NS.NewBusTarget()
        if not holdTarget then return nil end
        NS.SafeRegisterEvent(holdTarget, "PLAYER_REGEN_ENABLED", function()
            dropHold()
            NS.MaybeShowPresetPicker()
        end, NS.RejectedEvents)
        return nil
    end
    return show(true)
end

function NS.ShowPresetPicker()
    if InCombatLockdown() then
        return sayGray(L["cannot open the preset picker during combat — previewing a preset rebuilds your containers"])
    end
    return show(false)
end

function NS.HidePresetPicker(replaced)
    dropHold()
    dropConfirm()
    local f = Picker.frame
    if not (f and f:IsShown()) then return end
    if state.owns and NS.Presets.IsPreviewing() then NS.Presets.EndPreview(false) end
    settle(state.lockedAtOpen, replaced)
    state.picked, state.owns, state.open = false, false, false
    closing = true
    f:Hide()
    closing = false
end

function NS.RefreshPresetPicker()
    local f = Picker.frame
    if not (f and f:IsShown()) then return end
    if not NS.Presets.IsPreviewing() then state.owns = false end
    refresh()
end
