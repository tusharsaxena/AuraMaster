-- tests/test_state.lua — core/State.lua: session-only runtime state. Nothing in it may reach
-- SavedVariables, a reload starts it clean, and CM.SetPreview (preview's one toggle) stores a strict
-- boolean and runs the visibility pass at once.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
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
    assertEqual(NS.State.preview, false)
    assertNil(NS.State.activeContainerId)
    NS.ContainerManager.SetPreview(true)
    NS.State.SetActiveContainer(2)
    local sv = _G.AuraMasterDB
    local stored = keysUnder(sv)
    -- red under: a session field moved into the profile (it would come back after a reload)
    assertNil(stored.preview, "preview is session-only")
    assertNil(stored.activeContainerId, "the selection is session-only")
    local NS2 = fresh({ savedVariables = sv })
    assertEqual(NS2.State.preview, false, "a reload starts preview off")
    assertNil(NS2.State.activeContainerId, "and selects nothing")
end)

test("state: preview's toggle stores a strict boolean and hides or restores the engines at once", function()
    local NS = fresh()
    local e = NS.ContainerManager.instances[1].engine
    assertTrue(e.__enabled)
    NS.ContainerManager.SetPreview(1)
    -- red under: SetPreview storing the caller's value as it came
    assertEqual(NS.State.preview, true)
    -- red under: SetPreview without its visibility pass
    assertFalse(e.__enabled, "real auras do not draw under the placeholders")
    NS.ContainerManager.SetPreview(nil)
    assertEqual(NS.State.preview, false)
    assertTrue(e.__enabled)
end)
