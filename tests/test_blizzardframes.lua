-- tests/test_blizzardframes.lua — modules/BlizzardFrames.lua: hiding Blizzard's own buff and debuff
-- frames by moving them under a hidden parent of ours, and putting them back where they were.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local R = dofile("tests/region_recorder.lua")

--- A stand-in for one of Blizzard's frames: its parent is tracked, and every SetParent is logged.
local function blizzardFrame(parent)
    local f = R()
    f.__parent = parent
    f.__answer.GetParent = function(self) return self.__parent end
    f.__answer.SetParent = function(self, p)
        self.__parent = p
        return self
    end
    return f
end

--- A fresh environment with BuffFrame and DebuffFrame planted under their own original parents.
local function env()
    local NS, mocks = fresh()
    local home = { buff = R(), debuff = R() }
    local buff, debuff = blizzardFrame(home.buff), blizzardFrame(home.debuff)
    mocks.__globals.BuffFrame, mocks.__globals.DebuffFrame = buff, debuff
    return NS, mocks, buff, debuff, home
end

test("blizzard: hiding moves the frame under a hidden parent of ours; restoring puts back the parent it had", function()
    local NS, _, buff, _, home = env()
    NS.db.profile.hideBlizzardBuffs = true
    assertTrue(NS.BlizzardFrames.Apply())
    local hider = buff.__parent
    assertTrue(hider ~= home.buff, "moved")
    -- red under: a hidden parent that is ever shown (the frame would draw again)
    assertFalse(hider:IsShown(), "under a parent that never shows")
    assertTrue(NS.BlizzardFrames.IsHidden("BuffFrame"))
    assertEqual(buff:__count("Hide"), 0, "reparented, never hidden (events-frames-taint-§3)")
    NS.db.profile.hideBlizzardBuffs = false
    NS.BlizzardFrames.Apply()
    -- red under: apply restoring to UIParent instead of the remembered parent
    assertTrue(buff.__parent == home.buff, "back where it was")
    assertFalse(NS.BlizzardFrames.IsHidden("BuffFrame"))
end)

test("blizzard: applying twice remembers the first parent, so a restore never lands on our hidden frame", function()
    local NS, _, buff, _, home = env()
    NS.db.profile.hideBlizzardBuffs = true
    NS.BlizzardFrames.Apply()
    NS.BlizzardFrames.Apply()
    NS.db.profile.hideBlizzardBuffs = false
    NS.BlizzardFrames.Apply()
    -- red under: apply overwriting originalParent on every hide (the second one reads our hidden frame)
    assertTrue(buff.__parent == home.buff)
    local moves = buff:__count("SetParent")
    NS.BlizzardFrames.Apply()
    assertEqual(buff:__count("SetParent"), moves, "once restored, a later pass moves it no more")
end)

test("blizzard: buffs and debuffs are hidden and restored independently", function()
    local NS, _, buff, debuff, home = env()
    NS.db.profile.hideBlizzardDebuffs = true
    NS.BlizzardFrames.Apply()
    -- red under: one setting driving both frames
    assertTrue(buff.__parent == home.buff, "buffs untouched")
    assertTrue(NS.BlizzardFrames.IsHidden("DebuffFrame"))
    NS.db.profile.hideBlizzardBuffs = true
    NS.db.profile.hideBlizzardDebuffs = false
    NS.BlizzardFrames.Apply()
    assertTrue(NS.BlizzardFrames.IsHidden("BuffFrame"))
    assertTrue(debuff.__parent == home.debuff, "debuffs back home")
end)

test("blizzard: a frame the setting never hid is left where it is, whoever moved it", function()
    local NS, _, buff = env()
    local elsewhere = R()
    buff.__parent = elsewhere   -- another add-on moved it
    NS.BlizzardFrames.Apply()
    -- red under: apply "restoring" a frame it never moved (it would fight another add-on)
    assertEqual(buff:__count("SetParent"), 0)
    assertTrue(buff.__parent == elsewhere)
end)

test("blizzard: a frame that had no parent is restored to UIParent", function()
    local NS, mocks, buff = env()
    buff.__parent = nil
    NS.db.profile.hideBlizzardBuffs = true
    NS.BlizzardFrames.Apply()
    NS.db.profile.hideBlizzardBuffs = false
    NS.BlizzardFrames.Apply()
    -- red under: remembering a nil parent, which reads as "never moved" and strands the frame hidden
    assertTrue(buff.__parent == mocks.UIParent)
    assertFalse(NS.BlizzardFrames.IsHidden("BuffFrame"))
end)

test("blizzard: a client without the frame, or a global that is not one, is skipped without raising", function()
    local NS, mocks = fresh()
    mocks.__globals.DebuffFrame = "not a frame"
    NS.db.profile.hideBlizzardBuffs, NS.db.profile.hideBlizzardDebuffs = true, true
    local ok, res = pcall(NS.BlizzardFrames.Apply)
    -- red under: apply calling SetParent on whatever the global holds
    assertTrue(ok, tostring(res))
    assertTrue(res, "the profile still counts as applied")
    assertFalse(NS.BlizzardFrames.IsHidden("BuffFrame"))
end)

test("blizzard: in combat nothing moves and Apply says it has to wait; with no profile, nothing is waiting", function()
    local NS, mocks, buff = env()
    NS.db.profile.hideBlizzardBuffs = true
    mocks.__lockdown = true
    -- red under: apply reparenting a Blizzard frame under lockdown (refused, and taints)
    assertEqual(NS.BlizzardFrames.Apply(), false)
    assertEqual(buff:__count("SetParent"), 0)
    mocks.__lockdown = false
    local db = NS.db
    NS.db = nil
    local res = NS.BlizzardFrames.Apply()
    NS.db = db
    assertNil(res, "nil, not false: nothing is queued for after combat")
end)

test("blizzard: a profile switch applies the new profile's choice", function()
    local NS, _, buff, _, home = env()
    assertTrue(NS.SetByPath("hideBlizzardBuffs", true))
    assertTrue(NS.BlizzardFrames.IsHidden("BuffFrame"), "the toggle applies at once")
    NS.db:SetProfile("Alt")
    -- red under: the profile callbacks not re-applying BlizzardFrames
    assertFalse(NS.db.profile.hideBlizzardBuffs, "the new profile shows Blizzard's buffs")
    assertTrue(buff.__parent == home.buff, "and they are back")
end)
