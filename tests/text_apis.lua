-- tests/text_apis.lua — the client APIs the Text style reaches, as RECORDING stand-ins: the duration
-- property enum, the seconds and numeric-rule formatters, the prebuilt duration text binding and the
-- color curves. The kit's mock has none of them, so without this every Compat wrapper answers nil
-- headlessly and a binding's options could never be seen.
--
-- Not a suite (tests/run.lua does not list it) and not part of the vendored kit. Install it from a
-- fresh environment's `before`, which runs after the mock is built and before anything loads:
--
--     local NS, m = dofile("tests/fresh_env.lua")({ before = dofile("tests/text_apis.lua") })
--
-- Every stand-in records each PascalCase call on `calls`, in order, as { name = ..., n = ..., ... },
-- and answers itself (fidelity rule 3: recorded, never no-opped). `obj:__last(name)` is the last
-- call's argument list, `obj:__count(name)` how many there were; `kind` names what it stands in for.
-- A seconds formatter's Format writes whole seconds ("12s"), so a placeholder's text is predictable.

--- The enum's members, each its own number so a swapped property cannot pass.
local PROPS = { RemainingDuration = 101, RemainingPercent = 102, ElapsedDuration = 103,
    ElapsedPercent = 104, TotalDuration = 105, StartTime = 106, EndTime = 107 }

local helpers = {}

function helpers.__last(self, name)
    local hit
    for _, c in ipairs(self.calls) do
        if c.name == name then hit = c end
    end
    return hit
end

function helpers.__count(self, name)
    local n = 0
    for _, c in ipairs(self.calls) do
        if c.name == name then n = n + 1 end
    end
    return n
end

--- A recording stand-in for one client object.
local function recording(kind)
    return setmetatable({ kind = kind, calls = {} }, { __index = function(_, k)
        if helpers[k] then return helpers[k] end
        if type(k) ~= "string" or not k:match("^%u") then return nil end
        return function(self, ...)
            local n = #self.calls
            self.calls[n + 1] = { name = k, n = select("#", ...), ... }
            return self
        end
    end })
end

local function secondsFormatter()
    local f = recording("seconds")
    f.Format = function(_, seconds) return ("%ds"):format(seconds) end
    return f
end

return function(m)
    m.Enum = m.Enum or {}
    local E = m.Enum
    E.DurationTextBindingProperty = PROPS
    E.LuaCurveType = { Step = 1, Linear = 2 }
    E.SecondsFormatterInterval = { Seconds = 1, Minutes = 2, Hours = 3, Days = 4 }
    E.SecondsFormatterAbbreviation = { OneLetter = 1 }
    E.SecondsFormatterRounding = { RoundUp = 0, Truncate = 1 }
    m.C_StringUtil = {
        CreateSecondsFormatter = secondsFormatter,
        CreateNumericRuleFormatter = function() return recording("rule") end,
    }
    m.C_DurationUtil = { CreateDurationTextBinding = function() return recording("binding") end }
    m.C_CurveUtil = {
        CreateCurve = function() return recording("curve") end,
        CreateColorCurve = function() return recording("colorCurve") end,
    }
end
