-- tests/test_state.lua — core/State.lua: session-only runtime state. Nothing in it may reach
-- SavedVariables, a reload starts it clean, and there is no preview flag: unlocking is the preview.

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

test("state: there is no preview flag and no preview toggle; unlocking is the preview", function()
    -- The user removed test mode outright: nothing but the lock shows the placeholders.
    local NS = fresh()
    -- red under: core/State.lua still declaring `preview`
    assertNil(NS.State.preview, "no preview flag")
    -- red under: modules/ContainerManager.lua still defining SetPreview
    assertNil(NS.ContainerManager.SetPreview, "no preview toggle")
    local e = NS.ContainerManager.instances[1].engine
    assertTrue(e.__enabled, "locked by default: real auras draw")
    assertTrue(NS.SetByPath("locked", false))
    assertFalse(e.__enabled, "unlocked: the placeholders take the engine's place")
    assertTrue(NS.SetByPath("locked", true))
    assertTrue(e.__enabled, "locked again: real auras are back")
end)
