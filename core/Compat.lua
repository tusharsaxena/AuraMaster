local _, NS = ...
NS.Compat = NS.Compat or {}
local Compat = NS.Compat

-- LibKa0s-Compat-1.0 carries the version-variant readers two or more Ka0s addons wrote alike. Of
-- the members here, only GetSpellInfo is one of them (the secret guards it also carries are wired in
-- core/Secrets.lua); every other shim in this file is this addon's alone. Absent, a reader answers
-- the major's documented no-rung value (LibKa0s docs/api/Compat/version-1-docs.md, "Degradation").
local CompatLib = LibStub and LibStub("LibKa0s-Compat-1.0", true)

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
-- The text style (issue #2)
-- ---------------------------------------------------------------------------

--- Enum.DurationTextBindingProperty[member] ("RemainingDuration", "TotalDuration", ...), or nil on a
--- client without it. Each {} of a duration text's format reads the property its component names.
--- @param member string
--- @return number|nil
function Compat.DurationProperty(member)
    local e = _G.Enum and _G.Enum.DurationTextBindingProperty
    if e and e[member] ~= nil then return e[member] end
    return nil
end

--- A numeric rule formatter for CustomAuraButton:SetApplicationCount's `formatter` and a duration
--- component's: a count is written through the format of the highest breakpoint it reaches, so
--- `{ { threshold = 0, format = "" }, { threshold = 2, format = " x%d" } }` hides a single stack.
--- Nil on a client without C_StringUtil.CreateNumericRuleFormatter, or when it refuses the list.
--- @param breakpoints table  { { threshold = number, format = string }, ... }
--- @return table|nil
function Compat.CreateRuleFormatter(breakpoints)
    local su = _G.C_StringUtil
    if not (su and su.CreateNumericRuleFormatter) then return nil end
    local ok, f = pcall(su.CreateNumericRuleFormatter)
    if not ok or not f then return nil end
    if not pcall(f.SetBreakpoints, f, breakpoints) then return nil end
    return f
end

--- A prebuilt duration text binding for SetDurationText's `binding` option, the only way to reach
--- its setters. A timeless or expired aura writes nothing (SetZeroDurationText and SetExpiredText
--- ""), so a Text style's whole duration piece, its bracket text included, is empty. `interval`, when
--- given, is SetUpdateInterval's refresh in seconds, which a blinking run needs to blink smoothly;
--- without it the engine keeps its own cadence. Nil on a client without C_DurationUtil, or when a
--- setter refuses.
--- @param interval number|nil
--- @return table|nil
function Compat.CreateDurationBinding(interval)
    local du = _G.C_DurationUtil
    if not (du and du.CreateDurationTextBinding) then return nil end
    local ok, b = pcall(du.CreateDurationTextBinding)
    if not ok or not b then return nil end
    local built = pcall(function()
        b:SetZeroDurationText("")
        b:SetExpiredText("")
        if interval then b:SetUpdateInterval(interval) end
    end)
    return built and b or nil
end

-- The blink: below the threshold the running-out color alternates between its own alpha and
-- BLINK_LOW every BLINK_STEP seconds (the stepped curve the 2026-09-18 probe measured).
local BLINK_STEP, BLINK_LOW = 0.25, 0.1

--- The blink's points on `curve`: `blink` at full and low alpha in turn from 0 up to `threshold`,
--- then `normal` from the threshold up.
local function addBlinkPoints(curve, E, threshold, blink, normal)
    if curve.SetType and E.LuaCurveType then curve:SetType(E.LuaCurveType.Step) end
    local r, g, b, a = blink.r or 1, blink.g or 0, blink.b or 0, blink.a or 1
    local steps = math.floor(threshold / BLINK_STEP)
    for i = 0, steps - 1 do
        curve:AddPoint(i * BLINK_STEP, _G.CreateColor(r, g, b, (i % 2 == 0) and a or BLINK_LOW))
    end
    curve:AddPoint(threshold, _G.CreateColor(normal.r or 1, normal.g or 1, normal.b or 1, normal.a or 1))
end

--- The `textColor` option for a BLINKING running-out text: a step color curve over REMAINING time
--- that alternates `blink` between its own alpha and a tenth of it every quarter second below
--- `threshold` seconds, and is `normal` above it. Nil without the curve API, or when the curve
--- refuses a point, which leaves the text its font color, as ExpiringTextColor does.
--- @param threshold number  seconds
--- @param blink table       {r,g,b,a}
--- @param normal table      {r,g,b,a}
--- @return table|nil  { curve = …, property = … }
function Compat.BlinkTextColor(threshold, blink, normal)
    local cu = _G.C_CurveUtil
    local prop = Compat.DurationProperty("RemainingDuration")
    if not (cu and cu.CreateColorCurve and prop and _G.CreateColor) then return nil end
    local ok, curve = pcall(cu.CreateColorCurve)
    if not ok or not curve then return nil end
    if not pcall(addBlinkPoints, curve, _G.Enum, threshold, blink, normal) then return nil end
    return { curve = curve, property = prop }
end

-- ---------------------------------------------------------------------------
-- Everything else
-- ---------------------------------------------------------------------------

--- The frame under the cursor. GetMouseFocus was removed in 11.0 in favor of GetMouseFoci, which
--- returns every frame under the cursor; the first is the topmost. There is no pre-11.0 rung: the
--- TOC is 120100 only, and every client it loads on has GetMouseFoci.
--- @return table|nil
function Compat.GetMouseFocus()
    if _G.GetMouseFoci then
        local foci = _G.GetMouseFoci()
        return foci and foci[1] or nil
    end
    return nil
end

--- Blizzard's debuff border art for `dispelType` on `region`, as the aura engine's Border style draws
--- it: AuraUtil.SetAuraBorderAtlas, then untinted white, because the art is already colored
--- (docs/superpowers/research/2026-09-13-aura-engine-notes.md). Without AuraUtil it sets the per-type
--- `-noicon` atlas itself, or the default one when the client has no art for that type (as
--- DEBUFF_DISPLAY_INFO's None does). For a PREVIEW icon, which has no engine to draw it (TD-4).
--- @return boolean  whether the art was set
function Compat.SetAuraBorderAtlas(region, dispelType)
    if type(dispelType) ~= "string" or type(region) ~= "table" then return false end
    local AU = _G.AuraUtil
    if AU and AU.SetAuraBorderAtlas then
        AU.SetAuraBorderAtlas(region, dispelType, false)
    elseif region.SetAtlas then
        local atlas = "ui-debuff-border-" .. string.lower(dispelType) .. "-noicon"
        local CT = _G.C_Texture
        if CT and CT.GetAtlasInfo and not CT.GetAtlasInfo(atlas) then atlas = "ui-debuff-border-default-noicon" end
        region:SetAtlas(atlas, true)
    else
        return false
    end
    region:SetVertexColor(1, 1, 1, 1)
    return true
end

--- A spell's name and icon first, or one nil. LibKa0s-Compat-1.0's reader: C_Spell on Retail, the
--- pre-11.0 global (its rank dropped) as the fallback. A hit answers six values, `name, iconID,
--- castTime, minRange, maxRange, spellID`, and every caller here reads the first. This addon keeps
--- its number-only domain in front of the call (the major also takes a name or a link). Without the
--- library it answers nil, the major's documented no-rung value.
--- @param id number
--- @return string|nil name, number|nil icon
function Compat.GetSpellInfo(id)
    if type(id) ~= "number" then return nil end
    if CompatLib then return CompatLib.GetSpellInfo(id) end
    return nil
end
