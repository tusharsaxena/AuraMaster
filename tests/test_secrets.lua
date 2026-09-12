-- tests/test_secrets.lua — core/Secrets.lua: the only file that asks whether a value is secret. Its
-- predicates must degrade to "nothing is secret" on a client without the secrets system, answer
-- strict booleans, and let canaccessvalue (the context's own answer) decide over the plain test.
--
-- A plain Lua value cannot be secret, so a case names a few sentinel numbers secret by planting the
-- client's issecretvalue and canaccessvalue on a private environment's mock, restored after.

local T = _G.AM_TEST
local test, assertEqual = T.test, T.assertEqual
local fresh = dofile("tests/fresh_env.lua")

local env
local function E()
    if not env then
        local NS, mocks = fresh()
        env = { NS = NS, mocks = mocks }
    end
    return env.NS, env.mocks
end

--- Run `fn(NS)` with each `{ key, value }` of `patch` set on the mock, then restore every key and
--- re-raise the case's own failure.
local function with(patch, fn)
    local NS, mocks = E()
    local saved = {}
    for i, kv in ipairs(patch) do
        saved[i] = mocks[kv[1]]
        mocks[kv[1]] = kv[2]
    end
    local ok, err = pcall(fn, NS)
    for i, kv in ipairs(patch) do mocks[kv[1]] = saved[i] end
    if not ok then error(err, 0) end
end

local SECRET, READABLE_SECRET = 41.5, 42.5

test("secrets: without the client's secrets system nothing is secret and every value is readable", function()
    with({ { "issecretvalue", nil }, { "canaccessvalue", nil } }, function(NS)
        local S = NS.Secrets
        for _, v in ipairs({ 1, "text", {}, false }) do
            assertEqual(S.IsSecret(v), false)
            assertEqual(S.CanAccess(v), true)
        end
        assertEqual(S.IsReadableNumber(3), true)
        -- red under: IsReadableNumber accepting any readable value
        assertEqual(S.IsReadableNumber("3"), false, "a numeric string is not a number")
        assertEqual(S.IsReadableNumber(nil), false)
        -- red under: IsSafeKey dropping its nil check (t[nil] = x raises)
        assertEqual(S.IsSafeKey(nil), false)
        assertEqual(S.IsSafeKey(0), true)
    end)
end)

test("secrets: issecretvalue alone decides access when canaccessvalue is absent, as a strict boolean", function()
    local issecret = function(v)
        if v == SECRET then return 1 end
        return nil
    end
    with({ { "issecretvalue", issecret }, { "canaccessvalue", nil } }, function(NS)
        local S = NS.Secrets
        -- red under: IsSecret returning the client's truthy value as it came
        assertEqual(S.IsSecret(SECRET), true)
        assertEqual(S.IsSecret(7), false)
        -- red under: CanAccess answering true whenever canaccessvalue is absent
        assertEqual(S.CanAccess(SECRET), false)
        assertEqual(S.IsReadableNumber(SECRET), false, "a secret number cannot be compared")
        assertEqual(S.IsReadableNumber(7), true)
        assertEqual(S.IsSafeKey(SECRET), false, "a secret spell id is never a table key")
    end)
end)

test("secrets: canaccessvalue, when the client has it, overrides the secret test", function()
    local issecret = function(v) return v == SECRET or v == READABLE_SECRET end
    local canaccess = function(v) return v ~= SECRET end
    with({ { "issecretvalue", issecret }, { "canaccessvalue", canaccess } }, function(NS)
        local S = NS.Secrets
        -- red under: CanAccess consulting issecretvalue before canaccessvalue
        assertEqual(S.CanAccess(READABLE_SECRET), true, "this context may read it")
        assertEqual(S.IsReadableNumber(READABLE_SECRET), true)
        assertEqual(S.CanAccess(SECRET), false)
        assertEqual(S.IsReadableNumber(SECRET), false)
    end)
end)
