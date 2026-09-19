-- tests/test_state.lua — core/State.lua: session-only runtime state. Nothing in it may reach
-- SavedVariables, a reload starts it clean, and test mode is session state apart from the lock.

local T = _G.AM_TEST
local test, assertTrue, assertFalse, assertNil =
    T.test, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")

--- Every key stored anywhere under `t`, so a case can ask whether a name was ever written.
local function keysUnder(t, out, seen)
    out, seen = out or {}, seen or {}
    if seen[t] then return out end
    seen[t] = true
    for k, v in pairs(t) do
        out[k] = true
        if type(v) == "table" then keysUnder(v, out, seen) end
    end
    return out
end

test("state: the session flags start off, are never saved, and a reload starts them clean", function()
    local NS = fresh()
    assertNil(NS.State.activeContainerId)
    NS.State.SetActiveContainer(2)
    local sv = _G.AuraMasterDB
    local stored = keysUnder(sv)
    -- red under: a session field moved into the profile (it would come back after a reload)
    assertNil(stored.activeContainerId, "the selection is session-only")
    local NS2 = fresh({ savedVariables = sv })
    assertNil(NS2.State.activeContainerId, "a reload selects nothing")
end)

test("state: test mode is session-only and off at login; unlocking keeps real auras drawing (B1)", function()
    local NS = fresh()
    assertFalse(NS.State.testMode, "off at login")
    -- red under: modules/ContainerManager.lua growing a second preview switch
    assertNil(NS.ContainerManager.SetPreview, "one switch: Preview.SetTestMode")
    local e = NS.ContainerManager.instances[1].engine
    assertTrue(e.__enabled, "locked by default: real auras draw")
    assertTrue(NS.SetByPath("locked", false))
    -- red under: ShouldShow still reading the lock as the preview
    assertTrue(e.__enabled, "unlocked: real auras keep drawing")
    NS.Preview.SetTestMode(true)
    assertFalse(e.__enabled, "test mode: the placeholders take the engine's place")
    NS.Preview.SetTestMode(false)
    assertTrue(e.__enabled, "test mode off: real auras are back")
    assertNil(rawget(NS.db.profile, "testMode"), "never saved")
end)
