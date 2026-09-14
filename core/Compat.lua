local _, NS = ...
NS.Compat = NS.Compat or {}
local Compat = NS.Compat

-- core/Compat.lua — every client API this addon reaches that is new in 12.x, version-variant, or
-- an enum the engine publishes (compat). Feature modules call these wrappers, never the globals, so a
-- renamed enum or a moved function is a one-file fix and a headless run degrades to plain answers.
--
-- Retail only: these shim cross-PATCH differences, never game flavors. docs/compat-layer.md lists
-- each shim and why it exists.

-- ---------------------------------------------------------------------------
-- The aura container engine (Blizzard_AuraContainer, 12.1)
-- ---------------------------------------------------------------------------

--- Whether this client has the native aura container. Without it the addon cannot show anything, and
--- says so once instead of erroring on every render.
--- @return boolean
function Compat.HasAuraContainer()
    return _G.AuraContainerSortMethod ~= nil and type(_G.CreateFrame) == "function"
end

--- Load Blizzard's aura container, then answer HasAuraContainer. Blizzard_AuraContainer is a
--- LOAD-ON-DEMAND add-on: until it is loaded neither CustomAuraContainerTemplate nor the enums this
--- file reads exist, and CreateFrame("AuraContainer", …) has nothing to build from. EllesmereUI's
--- aura kit loads it the same way, immediately before its first container.
--- @return boolean
function Compat.EnsureAuraContainer()
    local ca = _G.C_AddOns
    if ca and ca.IsAddOnLoaded and ca.LoadAddOn and not ca.IsAddOnLoaded("Blizzard_AuraContainer") then
        pcall(ca.LoadAddOn, "Blizzard_AuraContainer")
    end
    return Compat.HasAuraContainer()
end

--- Whether aura data is secret right now — combat, an encounter, a keystone, a PvP match or a
--- restricted map. While it is, aura buttons refuse addon access, so structural rebuilds and restyles
--- wait (modules/ContainerManager.lua). Answers false when the client has no secrets system.
--- @return boolean
function Compat.AurasAreSecret()
    local api = _G.C_Secrets
    if api and api.ShouldAurasBeSecret then
        local ok, secret = pcall(api.ShouldAurasBeSecret)
        if ok then return secret and true or false end
    end
    return false
end

local function enumValue(enumTable, member, fallback)
    local t = _G[enumTable]
    if type(t) == "table" and t[member] ~= nil then return t[member] end
    return fallback
end

--- AuraContainerSortMethod value for one of our sort keys (core/Constants.lua SORT_METHOD_ENGINE).
function Compat.SortMethod(key)
    local member = NS.Constants.SORT_METHOD_ENGINE[key] or "Default"
    return enumValue("AuraContainerSortMethod", member, 0)
end

--- AuraContainerSortDirection value for "normal" | "reverse".
function Compat.SortDirection(key)
    return enumValue("AuraContainerSortDirection", key == "reverse" and "Reverse" or "Normal",
        key == "reverse" and 1 or 0)
end

--- AuraContainerItemEnchantmentSlot value for "mainHand" | "offHand" | "ranged".
function Compat.EnchantSlot(key)
    local member = NS.Constants.ENCHANT_SLOT_ENGINE[key] or "MainHand"
    local fallback = ({ MainHand = 0, OffHand = 1, Ranged = 2 })[member]
    return enumValue("AuraContainerItemEnchantmentSlot", member, fallback)
end

--- AuraContainerItemEnchantmentSortMethod.Duration, for enchant ordering.
function Compat.EnchantSortByDuration()
    return enumValue("AuraContainerItemEnchantmentSortMethod", "Duration", 1)
end

--- CustomAuraContainerItemEnchantmentPlacement value: enchants after the aura groups.
function Compat.EnchantPlacementAfter()
    return enumValue("CustomAuraContainerItemEnchantmentPlacement", "AfterAuraGroups", 1)
end

--- AnchorUtil.FlowLayoutAxis value for "horizontal" | "vertical".
function Compat.FlowAxis(axis)
    local au = _G.AnchorUtil
    local t = au and au.FlowLayoutAxis
    if type(t) == "table" then
        return axis == "vertical" and t.Vertical or t.Horizontal
    end
    return axis
end

--- AnchorUtil.FlowDirection value for "right" | "left" | "up" | "down".
function Compat.FlowDirection(dir)
    local au = _G.AnchorUtil
    local t = au and au.FlowDirection
    if type(t) == "table" then
        local member = ({ right = "Right", left = "Left", up = "Up", down = "Down" })[dir]
        if member and t[member] ~= nil then return t[member] end
    end
    return dir
end

--- Enum.StatusBarTimerDirection value. "remaining" drains; "elapsed" fills.
function Compat.TimerDirection(which)
    local e = _G.Enum and _G.Enum.StatusBarTimerDirection
    if e then return which == "elapsed" and e.ElapsedTime or e.RemainingTime end
    return nil
end

--- Enum.StatusBarInterpolation value: smoothed or immediate.
function Compat.Interpolation(smooth)
    local e = _G.Enum and _G.Enum.StatusBarInterpolation
    if e then return smooth and e.ExponentialEaseOut or e.Immediate end
    return nil
end

--- Enum.CustomAuraButtonDispelTypeTextureStyle value by member name ("Border", "PreserveAsset", …).
function Compat.DispelStyle(member)
    local e = _G.Enum and _G.Enum.CustomAuraButtonDispelTypeTextureStyle
    if e and e[member] ~= nil then return e[member] end
    return nil
end

-- ---------------------------------------------------------------------------
-- Duration text
-- ---------------------------------------------------------------------------

-- The largest unit of Blizzard's own DefaultAuraDurationFormatter (Blizzard_AuraContainerShared.lua)
-- steps with the time left, each unit held to 1.5x the next: seconds to 90 s, minutes to 90 m,
-- hours to 36 h, then days.
local MAX_INTERVAL_STEPS = { { 0, "Seconds" }, { 91, "Minutes" }, { 5401, "Hours" }, { 129601, "Days" } }

--- That step curve as a C_CurveUtil curve, or nil when the client lacks the API or refuses a point.
local function maxIntervalCurve(E)
    local cu = _G.C_CurveUtil
    if not (cu and cu.CreateCurve and E.LuaCurveType) then return nil end
    local ok, curve = pcall(cu.CreateCurve)
    if not ok or not curve then return nil end
    local built = pcall(function()
        curve:SetType(E.LuaCurveType.Step)
        for _, step in ipairs(MAX_INTERVAL_STEPS) do
            curve:AddPoint(step[1], E.SecondsFormatterInterval[step[2]])
        end
    end)
    return built and curve or nil
end

--- The unit setup of one format. "long" is two units and a carry, so 1:59:59 reads "1h 59m" rather
--- than "1h 60m"; the others are one unit, and "blizzard" steps its largest unit like the engine's.
local function setUnits(f, E, format)
    local days = E.SecondsFormatterInterval.Days
    if format == "long" then
        f:SetCanRoundUpLastUnit(false)
        f:SetCanRoundUpIntervals(true)
        f:SetMaxInterval(days)
        f:SetDesiredUnitCount(2)
        return
    end
    f:SetCanRoundUpLastUnit(true)
    f:SetDesiredUnitCount(1)
    local curve = format == "blizzard" and maxIntervalCurve(E)
    if not (curve and pcall(f.SetMaxIntervalCurve, f, curve)) then f:SetMaxInterval(days) end
end

--- A SecondsFormatter for one of our TIME_FORMATS, or nil on a client without C_StringUtil. The
--- formatter is handed to the engine, which applies it to a secret duration we never see. Every
--- format rounds a fractional second UP, as the cooldown countdown does; the engine's own default
--- truncates, so 12.7 s would read "12" beside a countdown of 13 (I-2). "blizzard" is therefore not
--- the engine's default but a copy of it that rounds up.
--- @param format string  "blizzard" | "short" | "long"
--- @return table|nil
function Compat.CreateSecondsFormatter(format)
    local su = _G.C_StringUtil
    local E = _G.Enum
    if not (su and su.CreateSecondsFormatter and E and E.SecondsFormatterInterval) then return nil end
    local ok, f = pcall(su.CreateSecondsFormatter)
    if not ok or not f then return nil end
    pcall(function()
        f:SetDefaultAbbreviation(E.SecondsFormatterAbbreviation.OneLetter)
        f:SetRounding(E.SecondsFormatterRounding.RoundUp)
        f:SetMinInterval(E.SecondsFormatterInterval.Seconds)
        setUnits(f, E, format)
    end)
    return f
end

--- The `textColor` option for CustomAuraButton:SetDurationText — a step color curve over REMAINING
--- time that turns the text `expiring` below `threshold` seconds and `normal` above it. Nil when the
--- client lacks the curve API, which simply leaves the text its font color.
--- @param threshold number  seconds
--- @param expiring table    {r,g,b,a}
--- @param normal table      {r,g,b,a}
--- @return table|nil  { curve = …, property = … }
function Compat.ExpiringTextColor(threshold, expiring, normal)
    local cu = _G.C_CurveUtil
    local E = _G.Enum
    local prop = E and E.DurationTextBindingProperty and E.DurationTextBindingProperty.RemainingDuration
    if not (cu and cu.CreateColorCurve and prop and _G.CreateColor) then return nil end
    local ok, curve = pcall(cu.CreateColorCurve)
    if not ok or not curve then return nil end
    local built = pcall(function()
        if curve.SetType and E.LuaCurveType then curve:SetType(E.LuaCurveType.Step) end
        curve:AddPoint(0, _G.CreateColor(expiring.r or 1, expiring.g or 0, expiring.b or 0, expiring.a or 1))
        curve:AddPoint(threshold, _G.CreateColor(normal.r or 1, normal.g or 1, normal.b or 1, normal.a or 1))
    end)
    if not built then return nil end
    return { curve = curve, property = prop }
end

-- ---------------------------------------------------------------------------
-- Everything else
-- ---------------------------------------------------------------------------

--- The frame under the cursor. GetMouseFocus was removed in 11.0 in favor of GetMouseFoci, which
--- returns every frame under the cursor; the first is the topmost.
--- @return table|nil
function Compat.GetMouseFocus()
    if _G.GetMouseFoci then
        local foci = _G.GetMouseFoci()
        return foci and foci[1] or nil
    end
    if _G.GetMouseFocus then return _G.GetMouseFocus() end
    return nil
end

--- A spell's name and icon, or nil. C_Spell on Retail; the pre-11.0 global as the fallback.
--- @param id number
--- @return string|nil name, number|string|nil icon
function Compat.GetSpellInfo(id)
    if type(id) ~= "number" then return nil end
    local cs = _G.C_Spell
    if cs and cs.GetSpellInfo then
        local info = cs.GetSpellInfo(id)
        if info then return info.name, info.iconID end
        return nil
    end
    if _G.GetSpellInfo then
        local name, _, icon = _G.GetSpellInfo(id)
        return name, icon
    end
    return nil
end
