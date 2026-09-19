-- tests/test_compat.lua — core/Compat.lua: every client API the addon reaches that is new in 12.x,
-- version-variant, or an enum the engine publishes. Each wrapper has a rung for the API present and
-- a rung for it absent, and a case drives both.
--
-- One private environment, built on first use and shared by these cases. Compat reads every global
-- at call time through `_G`, which tests/wow_mock.lua's proxy answers from the mock, so a case sets a
-- mock key, calls the wrapper, and `with` puts the key back even when an assertion fails.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")

local env
local function E()
    if not env then
        local NS, mocks = fresh()
        env = { NS = NS, mocks = mocks }
    end
    return env.NS, env.mocks
end

--- Run `fn(NS, mocks)` with each `{ key, value }` of `patch` set on the mock, then restore every key
--- and re-raise the case's own failure.
local function with(patch, fn)
    local NS, mocks = E()
    local saved = {}
    for i, kv in ipairs(patch) do
        saved[i] = mocks[kv[1]]
        mocks[kv[1]] = kv[2]
    end
    local ok, err = pcall(fn, NS, mocks)
    for i, kv in ipairs(patch) do mocks[kv[1]] = saved[i] end
    if not ok then error(err, 0) end
end

-- ── the aura engine ──────────────────────────────────────────────────────────────────────────

test("compat: the aura engine counts as present only with its sort enum and CreateFrame", function()
    with({}, function(NS)
        assertTrue(NS.Compat.HasAuraContainer(), "a 12.1 client")
    end)
    -- red under: HasAuraContainer answering true without reading AuraContainerSortMethod
    with({ { "AuraContainerSortMethod", nil } }, function(NS)
        assertFalse(NS.Compat.HasAuraContainer(), "Blizzard_AuraContainer not loaded")
    end)
    -- red under: dropping HasAuraContainer's CreateFrame check
    with({ { "CreateFrame", nil } }, function(NS)
        assertFalse(NS.Compat.HasAuraContainer())
    end)
end)

test("compat: EnsureAuraContainer loads Blizzard_AuraContainer only when it is not loaded yet", function()
    local loads = {}
    local function addOns(loaded)
        return {
            IsAddOnLoaded = function() return loaded end,
            LoadAddOn = function(name)
                local n = #loads
                loads[n + 1] = name
            end,
        }
    end
    with({ { "C_AddOns", addOns(true) } }, function(NS)
        assertTrue(NS.Compat.EnsureAuraContainer())
        -- red under: EnsureAuraContainer calling LoadAddOn without asking IsAddOnLoaded
        assertEqual(#loads, 0, "an add-on already loaded is not loaded again")
    end)
    with({ { "C_AddOns", addOns(false) } }, function(NS)
        assertTrue(NS.Compat.EnsureAuraContainer())
        assertEqual(table.concat(loads, ","), "Blizzard_AuraContainer")
    end)
end)

test("compat: a LoadAddOn that raises, or no C_AddOns at all, still answers from the enums", function()
    local raising = {
        IsAddOnLoaded = function() return false end,
        LoadAddOn = function() error("the add-on is disabled") end,
    }
    with({ { "C_AddOns", raising } }, function(NS)
        -- red under: EnsureAuraContainer calling LoadAddOn without pcall
        assertTrue(NS.Compat.EnsureAuraContainer(), "the enums are there, so the engine is")
    end)
    with({ { "C_AddOns", nil }, { "AuraContainerSortMethod", nil } }, function(NS)
        assertFalse(NS.Compat.EnsureAuraContainer(), "nothing to load it with, and no enums")
    end)
end)

test("compat: AurasAreSecret answers a strict boolean, and false when the client cannot say", function()
    with({ { "C_Secrets", nil } }, function(NS)
        assertEqual(NS.Compat.AurasAreSecret(), false, "a client without the secrets system")
    end)
    with({ { "C_Secrets", { ShouldAurasBeSecret = function() error("not yet") end } } }, function(NS)
        -- red under: AurasAreSecret calling ShouldAurasBeSecret without pcall
        assertEqual(NS.Compat.AurasAreSecret(), false)
    end)
    with({ { "C_Secrets", { ShouldAurasBeSecret = function() return 1 end } } }, function(NS)
        -- red under: AurasAreSecret returning the client's value as it came
        assertEqual(NS.Compat.AurasAreSecret(), true)
    end)
    with({ { "C_Secrets", { ShouldAurasBeSecret = function() return nil end } } }, function(NS)
        assertEqual(NS.Compat.AurasAreSecret(), false)
    end)
end)

-- ── the engine's enums ───────────────────────────────────────────────────────────────────────

test("compat: every sort key reaches a distinct member of the engine's sort enum", function()
    with({}, function(NS, mocks)
        local C = NS.Constants
        local seen, distinct = {}, 0
        for _, key in ipairs(C.SORT_METHODS) do
            local want = mocks.AuraContainerSortMethod[C.SORT_METHOD_ENGINE[key]]
            -- red under: a member name in SORT_METHOD_ENGINE the client's enum does not have
            assertTrue(want ~= nil, "sort key " .. key .. " names no engine member")
            assertEqual(NS.Compat.SortMethod(key), want, key)
            if not seen[want] then seen[want], distinct = true, distinct + 1 end
        end
        assertEqual(distinct, #C.SORT_METHODS, "no two sort keys land on one engine method")
        assertEqual(NS.Compat.SortMethod("nonsense"), mocks.AuraContainerSortMethod.Default)
    end)
    with({ { "AuraContainerSortMethod", nil } }, function(NS)
        assertEqual(NS.Compat.SortMethod("name"), 0, "no enum: the client's Default")
    end)
end)

test("compat: sort direction reads the engine enum, else 1 for reverse and 0 for normal", function()
    with({ { "AuraContainerSortDirection", { Normal = 5, Reverse = 6 } } }, function(NS)
        -- red under: SortDirection answering its fallback while the enum is present
        assertEqual(NS.Compat.SortDirection("reverse"), 6)
        assertEqual(NS.Compat.SortDirection("normal"), 5)
        assertEqual(NS.Compat.SortDirection(nil), 5, "anything but reverse is normal")
    end)
    with({ { "AuraContainerSortDirection", nil } }, function(NS)
        assertEqual(NS.Compat.SortDirection("reverse"), 1)
        assertEqual(NS.Compat.SortDirection("normal"), 0)
    end)
end)

test("compat: enchant slots read the engine enum by member, with the client's numbering as fallback", function()
    with({ { "AuraContainerItemEnchantmentSlot", { MainHand = 10, OffHand = 11, Ranged = 12 } } }, function(NS)
        -- red under: EnchantSlot answering its fallback while the enum is present
        assertEqual(NS.Compat.EnchantSlot("mainHand"), 10)
        assertEqual(NS.Compat.EnchantSlot("offHand"), 11)
        assertEqual(NS.Compat.EnchantSlot("ranged"), 12)
        assertEqual(NS.Compat.EnchantSlot("bogus"), 10, "an unknown slot is the main hand")
    end)
    with({ { "AuraContainerItemEnchantmentSlot", nil } }, function(NS)
        assertEqual(NS.Compat.EnchantSlot("mainHand"), 0)
        assertEqual(NS.Compat.EnchantSlot("offHand"), 1)
        assertEqual(NS.Compat.EnchantSlot("ranged"), 2)
    end)
end)

test("compat: the enchant sort and placement read their enums, else 1", function()
    with({ { "AuraContainerItemEnchantmentSortMethod", { Duration = 4 } },
           { "CustomAuraContainerItemEnchantmentPlacement", { AfterAuraGroups = 3 } } }, function(NS)
        -- red under: either wrapper reading the wrong enum or member
        assertEqual(NS.Compat.EnchantSortByDuration(), 4)
        assertEqual(NS.Compat.EnchantPlacementAfter(), 3)
    end)
    with({ { "AuraContainerItemEnchantmentSortMethod", nil },
           { "CustomAuraContainerItemEnchantmentPlacement", nil } }, function(NS)
        assertEqual(NS.Compat.EnchantSortByDuration(), 1)
        assertEqual(NS.Compat.EnchantPlacementAfter(), 1)
    end)
end)

test("compat: flow axis and direction use AnchorUtil's enums, else pass the name through", function()
    local anchorUtil = {
        FlowLayoutAxis = { Horizontal = 20, Vertical = 21 },
        FlowDirection = { Right = 30, Left = 31, Up = 32, Down = 33 },
    }
    with({ { "AnchorUtil", anchorUtil } }, function(NS)
        local C = NS.Compat
        -- red under: FlowAxis answering Horizontal for "vertical"
        assertEqual(C.FlowAxis("vertical"), 21)
        assertEqual(C.FlowAxis("horizontal"), 20)
        -- red under: a mistyped member in FlowDirection's map
        assertEqual(C.FlowDirection("right"), 30)
        assertEqual(C.FlowDirection("left"), 31)
        assertEqual(C.FlowDirection("up"), 32)
        assertEqual(C.FlowDirection("down"), 33)
        assertEqual(C.FlowDirection("sideways"), "sideways", "an unknown direction is passed on")
    end)
    with({ { "AnchorUtil", nil } }, function(NS)
        assertEqual(NS.Compat.FlowAxis("vertical"), "vertical")
        assertEqual(NS.Compat.FlowDirection("left"), "left")
    end)
end)

test("compat: the status-bar and dispel-style enums answer nil on a client without them", function()
    local enum = {
        StatusBarTimerDirection = { RemainingTime = 0, ElapsedTime = 1 },
        StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 },
        CustomAuraButtonDispelTypeTextureStyle = { Border = 2 },
    }
    with({ { "Enum", enum } }, function(NS)
        local C = NS.Compat
        -- red under: TimerDirection answering ElapsedTime for "remaining"
        assertEqual(C.TimerDirection("elapsed"), 1)
        assertEqual(C.TimerDirection("remaining"), 0)
        assertEqual(C.Interpolation(true), 1)
        assertEqual(C.Interpolation(false), 0)
        assertEqual(C.DispelStyle("Border"), 2)
        assertNil(C.DispelStyle("NoSuchStyle"))
    end)
    with({ { "Enum", nil } }, function(NS)
        assertNil(NS.Compat.TimerDirection("elapsed"))
        assertNil(NS.Compat.Interpolation(true))
        assertNil(NS.Compat.DispelStyle("Border"))
    end)
end)

-- ── duration text ────────────────────────────────────────────────────────────────────────────

-- The real client has RoundUp = 0 and Truncate = 1 (SecondsFormatterSharedDocumentation.lua); these
-- stand-ins are distinct from every other enum value here, so a swapped member cannot pass.
local FORMATTER_ENUM = {
    SecondsFormatterAbbreviation = { OneLetter = 1 },
    SecondsFormatterRounding = { RoundUp = 9, Truncate = 2 },
    SecondsFormatterInterval = { Seconds = 3, Minutes = 4, Hours = 5, Days = 6 },
    LuaCurveType = { Step = 7 },
}

--- A SecondsFormatter stand-in that records the arguments of every setter it is given.
local function recordingFormatter()
    local calls = {}
    return setmetatable({ __calls = calls }, { __index = function(_, k)
        return function(_, ...) calls[k] = { ... } end
    end })
end

--- A C_CurveUtil whose plain curves record their type and points; `refuse` makes AddPoint raise.
local function plainCurveUtil(refuse)
    return {
        CreateCurve = function()
            local curve = { points = {} }
            function curve:SetType(t) self.type = t end
            function curve:AddPoint(x, y)
                if refuse then error("bad point") end
                self.points[#self.points + 1] = { x, y }
            end
            return curve
        end,
    }
end

test("compat: no duration formatter without C_StringUtil, or when creation fails", function()
    with({ { "C_StringUtil", nil }, { "Enum", FORMATTER_ENUM } }, function(NS)
        assertNil(NS.Compat.CreateSecondsFormatter("short"))
    end)
    with({ { "C_StringUtil", { CreateSecondsFormatter = function() error("no formatter") end } },
           { "Enum", FORMATTER_ENUM } }, function(NS)
        -- red under: calling C_StringUtil.CreateSecondsFormatter without pcall
        assertNil(NS.Compat.CreateSecondsFormatter("short"))
    end)
end)

test("compat: a detailed formatter shows two units with a carry, a short one a single unit", function()
    local last
    local su = { CreateSecondsFormatter = function() last = recordingFormatter(); return last end }
    with({ { "C_StringUtil", su }, { "Enum", FORMATTER_ENUM } }, function(NS)
        local long = NS.Compat.CreateSecondsFormatter("long")
        assertTrue(long == last, "the client's formatter is handed back")
        -- red under: the long and short branches swapped
        assertEqual(long.__calls.SetDesiredUnitCount[1], 2)
        assertEqual(long.__calls.SetCanRoundUpLastUnit[1], false, "1:59:59 reads 1h 59m, not 1h 60m")
        assertEqual(long.__calls.SetMaxInterval[1], FORMATTER_ENUM.SecondsFormatterInterval.Days)
        local short = NS.Compat.CreateSecondsFormatter("short")
        assertEqual(short.__calls.SetDesiredUnitCount[1], 1)
        assertEqual(short.__calls.SetCanRoundUpLastUnit[1], true)
        assertEqual(short.__calls.SetMinInterval[1], FORMATTER_ENUM.SecondsFormatterInterval.Seconds)
    end)
end)

test("compat: every time format rounds a fractional second up, as the cooldown countdown does (I-2)", function()
    local su = { CreateSecondsFormatter = function() return recordingFormatter() end }
    with({ { "C_StringUtil", su }, { "Enum", FORMATTER_ENUM }, { "C_CurveUtil", plainCurveUtil(false) } }, function(NS)
        for _, fmt in ipairs({ "blizzard", "short", "long" }) do
            local f = NS.Compat.CreateSecondsFormatter(fmt)
            assertTrue(f ~= nil, fmt .. " has a formatter of its own")
            -- red under: SetRounding(Truncate) (12.7 s reads 12 while the countdown reads 13)
            assertEqual(f.__calls.SetRounding[1], FORMATTER_ENUM.SecondsFormatterRounding.RoundUp, fmt)
        end
    end)
end)

test("compat: the Blizzard format copies the engine's default formatter, rounding up (I-2)", function()
    local su = { CreateSecondsFormatter = function() return recordingFormatter() end }
    local I = FORMATTER_ENUM.SecondsFormatterInterval
    with({ { "C_StringUtil", su }, { "Enum", FORMATTER_ENUM }, { "C_CurveUtil", plainCurveUtil(false) } }, function(NS)
        local f = NS.Compat.CreateSecondsFormatter("blizzard")
        -- red under: CreateSecondsFormatter answering nil for "blizzard" (the engine's truncating default)
        assertTrue(f ~= nil, "a formatter of our own")
        local c = f.__calls
        assertEqual(c.SetDefaultAbbreviation[1], FORMATTER_ENUM.SecondsFormatterAbbreviation.OneLetter)
        assertEqual(c.SetCanRoundUpLastUnit[1], true)
        assertEqual(c.SetMinInterval[1], I.Seconds)
        assertEqual(c.SetDesiredUnitCount[1], 1)
        -- red under: the Blizzard format given the short one's flat Days maximum
        assertNil(c.SetMaxInterval, "the largest unit steps with the time left instead")
        local curve = c.SetMaxIntervalCurve[1]
        assertEqual(curve.type, FORMATTER_ENUM.LuaCurveType.Step)
        -- Blizzard_AuraContainerShared.lua: each unit holds to 1.5x the next (90 s, 90 m, 36 h).
        local want = { { 0, I.Seconds }, { 91, I.Minutes }, { 5401, I.Hours }, { 129601, I.Days } }
        assertEqual(#curve.points, #want)
        for i, p in ipairs(want) do
            -- red under: a step point off by the multiplier's 1 s margin, or a unit out of order
            assertEqual(curve.points[i][1], p[1], "point " .. i)
            assertEqual(curve.points[i][2], p[2], "unit " .. i)
        end
    end)
end)

test("compat: without the curve API, or with a curve that refuses a point, the Blizzard format tops out at days", function()
    local su = { CreateSecondsFormatter = function() return recordingFormatter() end }
    local days = FORMATTER_ENUM.SecondsFormatterInterval.Days
    for _, cu in ipairs({ false, plainCurveUtil(true) }) do
        with({ { "C_StringUtil", su }, { "Enum", FORMATTER_ENUM }, { "C_CurveUtil", cu or nil } }, function(NS)
            local f = NS.Compat.CreateSecondsFormatter("blizzard")
            -- red under: handing the formatter a curve it could not finish, or none and no maximum
            assertNil(f.__calls.SetMaxIntervalCurve)
            assertEqual(f.__calls.SetMaxInterval[1], days)
            assertEqual(f.__calls.SetDesiredUnitCount[1], 1, "the rest of the setup still runs")
        end)
    end
end)

local CURVE_ENUM = {
    DurationTextBindingProperty = { RemainingDuration = 7 },
    LuaCurveType = { Step = 2 },
}

--- A C_CurveUtil whose curves record their type and points; `refuse` makes AddPoint raise.
local function curveUtil(refuse)
    return {
        CreateColorCurve = function()
            local curve = { points = {} }
            function curve:SetType(t) self.type = t end
            function curve:AddPoint(x, color)
                if refuse then error("bad point") end
                self.points[#self.points + 1] = { x = x, color = color }
            end
            return curve
        end,
    }
end

test("compat: the expiring text color is a step curve from the expiring color to the normal one at the threshold", function()
    with({ { "C_CurveUtil", curveUtil(false) }, { "Enum", CURVE_ENUM } }, function(NS)
        local tc = NS.Compat.ExpiringTextColor(5, { r = 1, g = 0.2, b = 0 }, { r = 0.9, g = 0.9, b = 0.9, a = 0.5 })
        assertEqual(tc.property, 7, "bound to the remaining duration")
        assertEqual(tc.curve.type, 2, "a step, not a blend")
        local p = tc.curve.points
        assertEqual(#p, 2)
        -- red under: the two points swapped (the text would turn the expiring color above the threshold)
        assertEqual(p[1].x, 0)
        assertEqual(p[1].color.g, 0.2)
        assertEqual(p[1].color.a, 1, "a missing alpha is opaque")
        assertEqual(p[2].x, 5)
        assertEqual(p[2].color.a, 0.5)
    end)
end)

test("compat: no curve API, or a curve that refuses a point, gives no text color", function()
    with({ { "C_CurveUtil", nil }, { "Enum", CURVE_ENUM } }, function(NS)
        assertNil(NS.Compat.ExpiringTextColor(5, {}, {}))
    end)
    with({ { "C_CurveUtil", curveUtil(true) }, { "Enum", CURVE_ENUM } }, function(NS)
        -- red under: ExpiringTextColor handing back a curve it could not finish building
        assertNil(NS.Compat.ExpiringTextColor(5, {}, {}))
    end)
end)

-- ── the text style (issue #2) ────────────────────────────────────────────────────────────────

--- The Text style's client APIs as recording stand-ins (tests/text_apis.lua), planted on a scratch
--- table and handed to `with` key by key.
local function textApis()
    local t = {}
    dofile("tests/text_apis.lua")(t)
    return t
end

test("compat: a duration property reads the engine enum by member, and nil without it", function()
    local apis = textApis()
    with({ { "Enum", apis.Enum } }, function(NS)
        -- red under: DurationProperty answering the member name instead of the enum's value
        assertEqual(NS.Compat.DurationProperty("TotalDuration"), apis.Enum.DurationTextBindingProperty.TotalDuration)
        assertNil(NS.Compat.DurationProperty("NoSuchProperty"))
    end)
    with({ { "Enum", nil } }, function(NS)
        assertNil(NS.Compat.DurationProperty("RemainingDuration"))
    end)
end)

test("compat: a rule formatter is built with its breakpoints, and nil without the API or when refused", function()
    local apis = textApis()
    local breakpoints = { { threshold = 0, format = "" }, { threshold = 2, format = " x%d" } }
    with({ { "C_StringUtil", apis.C_StringUtil } }, function(NS)
        local f = NS.Compat.CreateRuleFormatter(breakpoints)
        -- red under: CreateRuleFormatter never calling SetBreakpoints
        assertTrue(f ~= nil and f.kind == "rule", "the client's formatter")
        assertTrue(f:__last("SetBreakpoints")[1] == breakpoints)
    end)
    with({ { "C_StringUtil", nil } }, function(NS)
        assertNil(NS.Compat.CreateRuleFormatter(breakpoints))
    end)
    local refusing = { CreateNumericRuleFormatter = function()
        return { SetBreakpoints = function() error("bad breakpoints") end }
    end }
    with({ { "C_StringUtil", refusing } }, function(NS)
        -- red under: SetBreakpoints called without pcall
        assertNil(NS.Compat.CreateRuleFormatter(breakpoints))
    end)
end)

test("compat: a duration binding writes nothing for a timeless or expired aura, and refreshes only when asked", function()
    local apis = textApis()
    with({ { "C_DurationUtil", apis.C_DurationUtil } }, function(NS)
        local b = NS.Compat.CreateDurationBinding(nil)
        assertEqual(b.kind, "binding")
        -- red under: a timeless aura writing the engine's own zero text
        assertEqual(b:__last("SetZeroDurationText")[1], "")
        assertEqual(b:__last("SetExpiredText")[1], "")
        -- red under: every binding paying a 0.1 s refresh, blink or not
        assertEqual(b:__count("SetUpdateInterval"), 0)
        local blink = NS.Compat.CreateDurationBinding(0.1)
        assertEqual(blink:__last("SetUpdateInterval")[1], 0.1)
    end)
    with({ { "C_DurationUtil", nil } }, function(NS)
        assertNil(NS.Compat.CreateDurationBinding(nil))
    end)
    local refusing = { CreateDurationTextBinding = function()
        return { SetZeroDurationText = function() error("refused") end }
    end }
    with({ { "C_DurationUtil", refusing } }, function(NS)
        assertNil(NS.Compat.CreateDurationBinding(nil))
    end)
end)

test("compat: the blink curve alternates the running-out color's alpha every quarter second, then the normal color", function()
    local apis = textApis()
    with({ { "C_CurveUtil", apis.C_CurveUtil }, { "Enum", apis.Enum } }, function(NS)
        local tc = NS.Compat.BlinkTextColor(1, { r = 1, g = 0.2, b = 0, a = 0.8 }, { r = 0.9, g = 0.9, b = 0.9, a = 1 })
        assertEqual(tc.property, apis.Enum.DurationTextBindingProperty.RemainingDuration)
        local curve = tc.curve
        assertEqual(curve:__last("SetType")[1], apis.Enum.LuaCurveType.Step, "a step, not a blend")
        local points = {}
        for _, c in ipairs(curve.calls) do
            if c.name == "AddPoint" then
                local n = #points
                points[n + 1] = c[1] .. "=" .. c[2].a
            end
        end
        -- red under: a curve that dims from the threshold down instead of alternating
        assertEqual(table.concat(points, ","), "0=0.8,0.25=0.1,0.5=0.8,0.75=0.1,1=1")
    end)
    with({ { "C_CurveUtil", nil }, { "Enum", apis.Enum } }, function(NS)
        assertNil(NS.Compat.BlinkTextColor(5, {}, {}))
    end)
end)

-- ── everything else ──────────────────────────────────────────────────────────────────────────

test("compat: the mouse focus is the topmost frame GetMouseFoci returns, else the legacy global", function()
    local top, under, legacy = {}, {}, {}
    with({ { "GetMouseFoci", function() return { top, under } end } }, function(NS)
        -- red under: GetMouseFocus answering the last frame GetMouseFoci returns
        assertTrue(NS.Compat.GetMouseFocus() == top)
    end)
    with({ { "GetMouseFoci", function() return {} end } }, function(NS)
        assertNil(NS.Compat.GetMouseFocus(), "nothing under the cursor")
    end)
    with({ { "GetMouseFoci", nil }, { "GetMouseFocus", function() return legacy end } }, function(NS)
        assertTrue(NS.Compat.GetMouseFocus() == legacy, "a pre-11.0 client")
    end)
    with({ { "GetMouseFoci", nil }, { "GetMouseFocus", nil } }, function(NS)
        assertNil(NS.Compat.GetMouseFocus())
    end)
end)

test("compat: spell info comes from C_Spell, and the pre-11.0 global only when C_Spell is absent", function()
    local legacy = function(id)
        if id == 774 or id == 1 then return "Legacy", "Rank 1", 999 end
    end
    with({ { "GetSpellInfo", legacy } }, function(NS)
        local name, icon = NS.Compat.GetSpellInfo(774)
        assertEqual(name, "Rejuvenation")
        assertEqual(icon, 136081)
        -- red under: falling through to the legacy global when C_Spell knows no such spell
        assertNil((NS.Compat.GetSpellInfo(1)), "C_Spell answered: no such spell")
        assertNil((NS.Compat.GetSpellInfo("774")), "a spell id is a number")
    end)
    with({ { "C_Spell", nil }, { "GetSpellInfo", legacy } }, function(NS)
        local name, icon = NS.Compat.GetSpellInfo(774)
        assertEqual(name, "Legacy")
        -- red under: reading the legacy global's second return (the rank) as the icon
        assertEqual(icon, 999)
    end)
end)
