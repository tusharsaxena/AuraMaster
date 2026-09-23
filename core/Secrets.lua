-- core/Secrets.lua
--
-- THE ONLY FILE IN THIS ADDON THAT ASKS WHETHER A VALUE IS SECRET.
--
-- Retail 12.x ("Midnight") returns combat-sensitive values to tainted code — all of ours — as SECRET
-- values while an addon restriction is active. Aura payloads are the case here: fields of an AuraData
-- table (duration, expirationTime, applications, sometimes spellId and sourceUnit) can arrive secret
-- in combat, depending on the unit and the aura.
--
-- Tainted code MAY: store a secret, pass it to Lua functions, put it in a table VALUE, hand it to a
-- widget setter (FontString:SetText, StatusBar:SetValue, Cooldown setters), and call type() on it.
--
-- Tainted code MAY NOT (each raises): compare it, do arithmetic on it, boolean-test a secret boolean,
-- use it as a table KEY, apply `#` to it, or index it. `table.concat` / `string.format` on one raises
-- too, which is why every chat and debug line goes through NS.SafeToString (events-frames-taint-§8).
--
-- So every module that needs to KNOW something about an aura field — may I filter on this duration,
-- may I key a table on this spell id, may I sort these two — asks here, and a caller that gets `false`
-- takes its documented fallback instead of guessing. That is the rule the whole data layer is built on.
--
-- DEGRADATION: every function is correct when the secrets system is ABSENT (an older client, the
-- headless harness): nothing is secret and everything is comparable.
--
-- WIDGET CONSEQUENCE: a frame that has been handed a secret (StatusBar:SetValue, SetText) can itself
-- report secret geometry. Container layout is therefore computed from CONFIG, never read back off an
-- element's GetWidth / GetPoint.

local _, NS = ...

local Secrets = {}
NS.Secrets = Secrets

-- IsSecret, CanAccess and IsSafeKey are LibKa0s-Compat-1.0's guards when the library is present.
-- The bodies below are their degraded arm, and a DELIBERATE DUPLICATION: for a guard, "the library
-- is absent" is not "the client has no secrets system", so a stub answering IsSecret -> false on a
-- 12.x client would send a secret into a comparison. See LibKa0s docs/api/Compat/version-1-docs.md,
-- "Degradation". IsReadableNumber and NumberOr are this addon's own, over whichever arm is wired.
local CompatLib = LibStub and LibStub("LibKa0s-Compat-1.0", true)

--- Whether `v` is a secret value. False on a client without the secrets system.
--- @param v any
--- @return boolean
Secrets.IsSecret = CompatLib and CompatLib.IsSecret or function(v)
    local fn = _G.issecretvalue
    if not fn then return false end
    return fn(v) and true or false
end

--- Whether the current execution context may look at `v` — the question that decides whether a
--- comparison or arithmetic on it is legal. A plain value always answers true.
--- @param v any
--- @return boolean
Secrets.CanAccess = CompatLib and CompatLib.CanAccess or function(v)
    local fn = _G.canaccessvalue
    if fn then return fn(v) and true or false end
    return not Secrets.IsSecret(v)
end

--- Whether `v` is a plain, readable NUMBER right now — the gate in front of every duration or
--- expiration comparison the filter and the sorter make.
--- @param v any
--- @return boolean
function Secrets.IsReadableNumber(v)
    return type(v) == "number" and Secrets.CanAccess(v)
end

--- `v` when it is a plain, readable number, else `fallback`. The one guard in front of a GEOMETRY
--- read (a width, a frame level, an offset): a region anchored to secret geometry answers secret
--- numbers even out of combat, and arithmetic on one raises (modules/Anchors.lua, feedback E).
--- @param v any
--- @param fallback any
--- @return any
function Secrets.NumberOr(v, fallback)
    if Secrets.IsReadableNumber(v) then return v end
    return fallback
end

--- Whether `v` may be used as a TABLE KEY right now. The spell-id whitelist and blacklist are keyed
--- tables, so a spell id is checked here before it is looked up; a caller that gets false treats the
--- aura as "not on the list".
--- @param v any
--- @return boolean
Secrets.IsSafeKey = CompatLib and CompatLib.IsSafeKey or function(v)
    if v == nil then return false end
    return not Secrets.IsSecret(v)
end
