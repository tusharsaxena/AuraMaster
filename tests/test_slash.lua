-- tests/test_slash.lua — settings/Slash.lua: NS.COMMANDS and the host verbs, driven through the
-- real LibKa0s-Slash dispatcher exactly as `/am …` reaches it.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local NS = T.NS
local fresh = dofile("tests/fresh_env.lua")

local function capture(mocks)
    local lines = {}
    rawset(mocks.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg) lines[#lines + 1] = tostring(msg) end)
    return lines
end

local function said(lines, fragment)
    for _, l in ipairs(lines) do if l:find(fragment, 1, true) then return true end end
    return false
end

test("slash: every command is a positional {name, desc, fn} triple", function()
    for i, e in ipairs(NS.COMMANDS) do
        assertTrue(type(e[1]) == "string" and type(e[2]) == "string" and type(e[3]) == "function",
            "NS.COMMANDS[" .. i .. "]")
    end
end)

test("slash: the reserved verbs are all present", function()
    local have = {}
    for _, e in ipairs(NS.COMMANDS) do have[e[1]] = true end
    for _, v in ipairs({ "help", "config", "list", "get", "set", "reset", "resetall", "debug", "perf", "version" }) do
        assertTrue(have[v], "reserved verb " .. v)
    end
end)

test("slash: /am new creates the described container and selects it", function()
    local NS2 = fresh()
    NS2.Slash:OnSlash("new target debuffs icons")
    local _, id = NS2.ActiveContainer()
    local c = NS2.Database.FindContainer(id)
    assertEqual(c.unit, "target")
    assertEqual(c.auraType, "HARMFUL")
    assertEqual(c.style, "icons")
    assertEqual(#NS2.Database.GetContainers(), 4)
end)

test("slash: /am new with a word it does not know creates nothing and says why", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    NS2.Slash:OnSlash("new target sparkles")
    assertEqual(#NS2.Database.GetContainers(), 3)
    assertTrue(said(lines, "sparkles"))
end)

test("slash: /am select takes an id or a name; /am containers marks the selection", function()
    local NS2, mocks = fresh()
    NS2.Slash:OnSlash("select player debuffs")
    assertEqual(NS2.State.activeContainerId, 2)
    NS2.Slash:OnSlash("select 3")
    assertEqual(NS2.State.activeContainerId, 3)
    local lines = capture(mocks)
    NS2.Slash:OnSlash("containers")
    assertTrue(said(lines, "Target debuffs (mine)"))
end)

test("slash: /am set writes the selected container through the seam", function()
    local NS2, mocks = fresh()
    NS2.Slash:OnSlash("select 2")
    NS2.Slash:OnSlash("set container.icons.width 48")
    assertEqual(NS2.Database.FindContainer(2).icons.width, 48)
    assertEqual(NS2.Database.FindContainer(1).icons.width, NS2.CONTAINER_TEMPLATE.icons.width)
    local lines = capture(mocks)
    NS2.Slash:OnSlash("get container.icons.width")
    assertTrue(said(lines, "Player debuffs"), "a container value names the container it read")
end)

test("slash: lock, unlock and preview drive the same settings the panel does", function()
    local NS2 = fresh()
    NS2.Slash:OnSlash("unlock")
    assertFalse(NS2.db.profile.locked)
    NS2.Slash:OnSlash("lock")
    assertTrue(NS2.db.profile.locked)
    NS2.Slash:OnSlash("preview on")
    assertTrue(NS2.State.preview)
    NS2.Slash:OnSlash("preview off")
    assertFalse(NS2.State.preview)
end)

test("slash: /am delete removes a container by id", function()
    local NS2 = fresh()
    NS2.Slash:OnSlash("delete 3")
    assertNil(NS2.Database.FindContainer(3))
    assertEqual(#NS2.Database.GetContainers(), 2)
end)

test("slash: /am pick starts the frame picker for the selected container", function()
    local NS2, mocks = fresh()
    NS2.Slash:OnSlash("select 2")
    NS2.Slash:OnSlash("pick")
    assertTrue(NS2.FramePicker.IsActive())
    local target = mocks.__stubFrame()
    target.GetName = function() return "FocusFrame" end
    target.IsForbidden = function() return false end
    mocks.__foci = { target }
    local overlay = mocks.__globals.AuraMasterFramePicker
    overlay:__fire("OnUpdate")                 -- arms (no button held)
    mocks.__mouseDown.LeftButton = true
    overlay:__fire("OnUpdate")
    local c = NS2.Database.FindContainer(2)
    assertEqual(c.attach.mode, "frame")
    assertEqual(c.attach.frame, "FocusFrame")
end)

test("slash: /am resetall and the General reset print the same line", function()
    local NS2, mocks = fresh()
    local fromSlash = capture(mocks)
    NS2.Slash:OnSlash("resetall")
    local fromPage = capture(mocks)
    mocks.StaticPopupDialogs.AURAMASTER_RESET_ALL.OnAccept()
    assertTrue(#fromSlash >= 1 and #fromPage >= 1, "both surfaces acknowledged the reset")
    assertEqual(fromSlash[#fromSlash], fromPage[#fromPage])
    assertTrue(said(fromPage, "All settings reset to defaults."), fromPage[#fromPage])
end)

test("slash: /am debug on and off flip the session flag; it never reaches the profile", function()
    local NS2 = fresh()
    NS2.Slash:OnSlash("debug on")
    assertTrue(NS2.State.debug)
    NS2.Slash:OnSlash("debug off")
    assertFalse(NS2.State.debug)
    assertNil(NS2.db.profile.debug)
end)
