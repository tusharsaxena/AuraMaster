-- tests/test_skin_verb.lua — the reserved `skin` verb (LibKa0s v1.82.0, OptionsSkinPicker minor 3's
-- O.SkinVerb; AM-01 of Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-16):
-- a `skin` row right after `config` runs NS.RunSkinVerb, which hands O.SkinVerb the first-run spec
-- (NS.SkinPickerSpec), so `/am skin` shows the picker a new profile shows whatever skin.pickerSeen
-- says. Refused while the addon is disabled (the dispatcher's gate), a gray line on every call in
-- combat (the library's), and the library-absent line without LibKa0s.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")
local degraded = dofile("tests/degraded_env.lua")

local REFUSAL = "Ka0s Aura Master is disabled — enable it with /am enable"

--- Every chat line from now on, color codes and the [AM] prefix stripped.
local function capture(mocks)
    local lines = {}
    rawset(mocks.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
        local s = tostring(msg):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        lines[#lines + 1] = (s:gsub("^%[AM%] ", ""))
    end)
    return lines
end

local function anyLine(lines, fragment)
    for _, l in ipairs(lines) do if l:find(fragment, 1, true) then return true end end
    return false
end

local function strings(mocks) return mocks.LibStub("LibKa0s-Options-1.0").SKIN_PICKER_STRINGS end

--- Logged in, with the first-run picker closed on this profile, so only the verb can bring it back.
local function seenProfile()
    local NS, mocks = fresh()
    NS.HideSkinPicker()
    NS.SetByPath("skin.pickerSeen", true)
    return NS, mocks
end

test("skin verb: the row sits right after config, with the library's help words", function()
    local NS, mocks = fresh()
    local at
    for i, c in ipairs(NS.COMMANDS) do
        if c[1] == "skin" then at = i end
    end
    -- red under: no skin row
    assertTrue(at ~= nil, "a skin row")
    assertEqual(NS.COMMANDS[at - 1][1], "config", "after config")
    assertEqual(NS.COMMANDS[at][2], strings(mocks).VERB_HELP, "one wording for every host")
end)

test("skin verb: /am skin shows the picker on a profile that has closed it", function()
    -- red under: no skin row (the dispatcher answers "unknown command"), or a verb that asks
    -- NS.MaybeShowSkinPicker, which a seen profile refuses.
    local NS, mocks = seenProfile()
    local lines = capture(mocks)
    local shown
    local live = NS.Helpers.SkinVerb
    NS.Helpers.SkinVerb = function(spec)
        local win, why = live(spec)
        shown = win
        return win, why
    end
    NS.Slash:OnSlash("skin")
    NS.Helpers.SkinVerb = live
    assertFalse(anyLine(lines, "Unknown command"), "a known verb")
    assertTrue(type(shown) == "table", "the picker's frame")
    assertTrue(shown:IsShown(), "and it is up")
    NS.HideSkinPicker()
end)

test("skin verb: NS.RunSkinVerb hands O.SkinVerb this addon's first-run spec", function()
    local NS = seenProfile()
    local live, seen = NS.Helpers.SkinVerb, nil
    NS.Helpers.SkinVerb = function(spec) seen = spec; return nil, "queued" end
    local win, why = NS.RunSkinVerb()
    NS.Helpers.SkinVerb = live
    assertEqual(seen.owner, "AuraMaster")
    assertTrue(rawequal(seen.set, NS.WriteSkinChoice), "the write seam, as the first-run start's")
    assertEqual(seen.page, "general"); assertEqual(seen.tab, "Appearance")
    assertTrue(win == nil, "nothing shown")
    assertEqual(why, "queued", "the library's reason, passed on")
end)

test("skin verb: in combat every call prints the library's gray line and shows nothing", function()
    local NS, mocks = seenProfile()
    local lines = capture(mocks)
    mocks.__lockdown = true
    local first, why = NS.RunSkinVerb()
    local n = #lines
    NS.RunSkinVerb()
    mocks.__lockdown = false
    assertTrue(first == nil, "no picker mid-combat")
    assertEqual(why, "combat")
    local gray = strings(mocks).VERB_COMBAT:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    assertTrue(anyLine(lines, gray), "the first call says why")
    assertTrue(#lines > n and lines[#lines]:find(gray, 1, true) ~= nil, "and so does the second")
end)

test("skin verb: refused while the addon is disabled, and no picker shows", function()
    local NS, mocks = seenProfile()
    local calls = 0
    local live = NS.Helpers.SkinVerb
    NS.Helpers.SkinVerb = function(spec) calls = calls + 1; return live(spec) end
    NS.SetByPath("enabled", false)
    local lines = capture(mocks)
    NS.Slash:OnSlash("skin")
    NS.Helpers.SkinVerb = live
    assertEqual(#lines, 1, "one refusal line")
    assertEqual(lines[1], REFUSAL)
    assertEqual(calls, 0, "the picker is never asked")
end)

test("skin verb: without LibKa0s the verb prints the library-absent line", function()
    local NS2, mocks2 = degraded()
    local lines = capture(mocks2)
    local win, why = NS2.RunSkinVerb()
    assertTrue(win == nil)
    assertEqual(why, "absent")
    assertTrue(anyLine(lines, "/am skin is unavailable: the LibKa0s library did not load."), "names the verb")
end)
