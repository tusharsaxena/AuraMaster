local addonName, NS = ...

-- settings/PresetPicker.lua -- the first-run preset picker and the preset confirm (spec
-- docs/superpowers/specs/2026-11-14-auramaster-presets-design.md, sections 5, 6 and 7).
--
-- WHAT IT PUBLISHES
--
--   NS.PresetPickerDue()       true while the active profile has not closed the picker and the addon
--                              stands up: what the login and every profile event ask.
--   NS.MaybeShowPresetPicker() the first-run showing, when due; in combat held for
--                              PLAYER_REGEN_ENABLED (one target at most). Answers the window or nil.
--   NS.ShowPresetPicker()      `/am preset`: the window on demand, whatever the latch says; refused
--                              in combat with the combat line.
--   NS.HidePresetPicker()      takes the window down WITHOUT marking it seen, ending a preview it
--                              started with a restore, and drops a held start: the stand-down and
--                              every profile event.
--   NS.PresetPickerHolding()   true while the window is up or a start is held: core/SkinSetup.lua's
--                              skin picker waits behind it, so the two never show at once.
--   NS.ConfirmPreset(n, l, m)  apply preset `n` in style `l`, mode `m`, behind the confirm that names
--                              the count it removes (Replace) or adds (Add): `/am preset <name>` now,
--                              the Containers page's Presets tab later. With the window up, it is
--                              the player's close of it: latch set, skin picker offered once the
--                              confirm is answered.
--   NS.PresetPicker            { frame }: the window once built, for the suites.
--
-- WHEN. Once per profile, before the skin picker: addon:OnEnterWorld shows it at once (it does not
-- wait the skin picker's two seconds) and arms no skin start while it is due; every close calls
-- NS.MaybeShowSkinPicker, which shows the skin picker only now. A new, reset or copied profile is
-- offered it again after the profile event (core/AuraMaster.lua's rebuildProfile).
--
-- WHAT A PICK DOES. Nothing is previewed when the window opens: the profile already holds what it
-- holds (Simple, on a new one). A pick of a preset or a style previews it on the real screen in
-- test mode (NS.Presets.BeginPreview); a pick of Empty ends a preview and shows no test mode.
-- Apply keeps the pick (EndPreview(true, "replace"), or Apply("empty") for Empty); with nothing
-- picked it keeps what is there. Not now, the close control and Escape restore (EndPreview(false)).
-- Every close the player makes sets the latch, `presets.pickerSeen`, through NS.Presets.
--
-- THE CONFIRM. Replace asks first, naming the count it removes, except on the first-run showing
-- while the profile still holds exactly what its seed wrote (NS.Presets.SeedUntouched), where
-- nothing of the player's is lost (spec section 5). A container made, deleted or edited since, in
-- this session or before a /reload, and it asks.
--
-- BUILT FROM THE LIBRARY'S PIECES: the window's shell and close mark through core/CoreSetup.lua's
-- seams (NS.ApplySkin, NS.MakeCloseButton), the dropdown is LibKa0s-Widgets-1.0's, and every
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
local WIDTH, PAD, ROW_H, GAP = 260, 14, 22, 8
local LEFT_X = 24   -- in from the screen's left edge, clear of the preset stacks (spec section 7)

-- The dropdown's order (spec section 7): Empty first, then the four presets.
local CHOICES = { "empty", "simple", "intermediate", "advanced", "healer" }
local LABELS = {
    empty = L["Empty"], simple = L["Simple"], intermediate = L["Intermediate"],
    advanced = L["Advanced"], healer = L["Healer"],
}
local BLURBS = {
    empty = L["No containers: start from a blank screen and build your own. Test mode stays off."],
    simple = L["Your buffs, weapon enchants and debuffs in the top-right corner."],
    intermediate = L["Simple, plus your short buffs and cooldowns, your debuffs on the target, the target's cooldowns and your debuffs on focus."],
    advanced = L["Everything: cooldown call-outs in the middle, the full target stack, icon rows and two special lists you fill yourself."],
    healer = L["Simple, plus your heals and what you can dispel on target and focus, your cooldowns and raid cooldowns."],
}
local LOOK_LABELS = { bars = L["Bars"], icons = L["Icons"] }

-- The window's session state. `sel` and `look` are what the controls show; `picked` is whether the
-- player chose anything since it opened; `firstRun` whether this showing is the first-run one (no
-- confirm); `owns` whether the preview up is the one this window started.
local state = { sel = "simple", look = "bars", picked = false, firstRun = false, owns = false }
local closing = false   -- true while this file hides the window itself, so OnHide is not a close
local holdTarget        -- the one-shot PLAYER_REGEN_ENABLED target, while a start is held

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
        popup.data = { run = run, after = after }
    elseif after then
        after()
    end
    return nil
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
    local after = closesWindow and NS.MaybeShowSkinPicker or nil
    return confirmThen(name, mode, count, ask, function()
        local ok, msg, gray = NS.Presets.Apply(name, look, mode)
        if not ok then return say(msg, gray) end
        if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
        sayApplied(name, look, mode)
        return true
    end, after)
end

-- ── the window's controls ────────────────────────────────────────────────────────────────────

local refresh   -- below: repaints the controls from `state`

--- Preview the selection: a preset in its style, or, for Empty, the player's own containers back.
local function preview()
    local P = NS.Presets
    if state.sel == "empty" then
        if P.IsPreviewing() and state.owns then
            local ok, msg, gray = P.EndPreview(false)
            if not ok then say(msg, gray) end
        end
        state.owns = false
        return refresh()
    end
    local ok, msg, gray = P.BeginPreview(state.sel, state.look)
    if ok then state.owns = true else say(msg, gray) end
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

--- The player's close of any kind: the window down, the latch set, then the skin picker's turn.
local function finish()
    local f = Picker.frame
    closing = true
    if f then f:Hide() end
    closing = false
    state.picked, state.owns = false, false
    NS.Presets.MarkPickerSeen()
    if NS.MaybeShowSkinPicker then NS.MaybeShowSkinPicker() end
end

--- Not now, the close control, Escape: a preview this window started is restored.
local function dismiss()
    local P = NS.Presets
    if state.owns and P.IsPreviewing() then P.EndPreview(false) end
    finish()
end

--- What Apply keeps: the preview up, else the selection written now (a preview combat ended, or Empty).
local function keepRun()
    local P, sel, look = NS.Presets, state.sel, state.look
    if sel ~= "empty" and state.owns and P.IsPreviewing() then
        return function() return P.EndPreview(true, "replace") end
    end
    return function()
        if state.owns and P.IsPreviewing() then P.EndPreview(false) end
        return P.Apply(sel, look, "replace")
    end
end

local function apply()
    if InCombatLockdown() then
        return sayGray(L["cannot apply a preset during combat — its containers would not be drawn or placed until combat ends"])
    end
    if not state.picked then return finish() end
    local run, sel, look = keepRun(), state.sel, state.look
    local count = NS.Presets.OwnContainerCount()
    -- No confirm only on the first-run showing over the untouched seed (spec section 5).
    local ask = count > 0 and not (state.firstRun and NS.Presets.SeedUntouched())
    confirmThen(sel, "replace", count, ask, function()
        local ok, msg, gray = run()
        if not ok then return say(msg, gray) end
        state.owns = false
        if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
        sayApplied(sel, look, "replace")
        finish()
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

local function buildBody(f)
    buildDropdown(f)
    buildSwitch(f)
    f.blurb = fontString(f, "GameFontHighlightSmall")
    -- A row of its own, so the line shows and hides as one frame while a preview is up.
    f.status = CreateFrame("Frame", nil, f)
    f.status.text = fontString(f.status, "GameFontNormalSmall", "accent")
    f.status.text:SetAllPoints(f.status)
    f.status.text:SetText(L["On your screen now, filled with sample auras. Nothing is saved until Apply."])
    f.apply = textButton(f, L["Apply"], function() apply() end, { primary = true })
    f.notNow = textButton(f, L["Not now"], function() dismiss() end)
    f.footer = fontString(f, "GameFontDisableSmall", "disabled")
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
    if f.status:IsShown() then y = stack(f, y, f.status, 28) end
    local applyW = WIDTH - 2 * PAD - 90 - 6
    stack(f, y, f.apply, ROW_H, PAD, applyW)
    y = stack(f, y, f.notNow, ROW_H, PAD + applyW + 6, 90)
    y = stack(f, y, f.footer, 28)
    f:SetHeight(y + PAD - GAP)
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
    f.footer:SetText(NS.SkinPickerDue and NS.SkinPickerDue()
        and L["Change it later on Containers > Presets. The skin picker opens next."]
        or L["Change it later on Containers > Presets."])
    layout(f)
end

-- ── showing and hiding ───────────────────────────────────────────────────────────────────────

local function dropHold()
    if holdTarget then holdTarget:UnregisterAllEvents(); holdTarget = nil end
end

--- Show the window, fresh: Simple in Bars selected, nothing picked, nothing previewed. The skin
--- picker goes down first, unmarked, so the two never show at once; it comes back after the close.
local function show(firstRun)
    local f = Picker.frame or build()
    if not f:IsShown() then
        state.sel, state.look, state.picked, state.owns = "simple", "bars", false, false
        state.firstRun = firstRun
        f:ClearAllPoints()
        f:SetPoint("LEFT", UIParent, "LEFT", LEFT_X, 0)
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

function NS.HidePresetPicker()
    dropHold()
    local f = Picker.frame
    if not (f and f:IsShown()) then return end
    if state.owns and NS.Presets.IsPreviewing() then NS.Presets.EndPreview(false) end
    state.picked, state.owns = false, false
    closing = true
    f:Hide()
    closing = false
end
