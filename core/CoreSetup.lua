local addonName, NS = ...
NS.Util = NS.Util or {}
local Util = NS.Util

-- core/CoreSetup.lua — the LibKa0s-Core-1.0 seam: the secret-safe stringifier, the class-color
-- resolver, the shared window skin, the close-button factory and the [AM]-prefixed chat printer.
--
-- None of that is this addon's code. What is ours is which tag the lines carry and what happens when
-- the library is not there. LOAD-BEARING POSITION: after core/Namespace.lua (NS.PREFIX) and before
-- everything that prints or takes NS.Print as a load-time upvalue.

-- The one cause clause every seam uses to explain the same absence, so a degraded install says the
-- same thing about WHY and a different thing about WHAT in each place. Set here, first of the seams.
NS.LIBKA0S_MISSING = NS.L["The LibKa0s library is missing from this installation of Aura Master (expected in libs/LibKa0s)"]

local lib = LibStub and LibStub("LibKa0s-Core-1.0", true)

if not lib then
    -- Degrade, never error. Settings files do `local print = NS.Print` at load, so a nil printer
    -- would take the settings UI with it and a no-op one would make /am answer nothing. These are
    -- short working fallbacks, and "not installed" is said ONCE, on the first line printed.
    local function probeConcat(v) return table.concat({ v }) end
    local function isConcatSafe(v)
        return (pcall(probeConcat, v))
    end

    function NS.SafeToString(v)
        if v == nil then return "nil" end
        if type(v) == "boolean" then return tostring(v) end
        if isConcatSafe(v) then return tostring(v) end
        return "<secret>"
    end

    -- A unit's class color, or nil when the class does not resolve (an NPC, no such unit). The
    -- library's answer: nil is an answer, and the caller falls through to its stored swatch.
    function NS.ClassColor(unit)
        local ok, _, token = pcall(UnitClass, unit or "player")
        local c = (ok and type(token) == "string" and type(RAID_CLASS_COLORS) == "table")
            and RAID_CLASS_COLORS[token] or nil
        if type(c) ~= "table" or type(c.r) ~= "number" then return nil end
        return c.r, c.g, c.b
    end

    -- The class-color resolver, working rather than a no-op, because every colored surface calls it
    -- on each paint. The library's three rules (options-ui-§17): the stored alpha survives the mode,
    -- an unresolvable class falls through to the stored swatch, and the swatch is read under both.
    function NS.ResolveColor(stored, on, unit)
        if type(stored) ~= "table" then stored = {} end
        local r, g, b, a = stored.r or 1, stored.g or 1, stored.b or 1, stored.a or 1
        if not on then return r, g, b, a end
        local cr, cg, cb = NS.ClassColor(unit)
        if cr == nil then return r, g, b, a end
        return cr, cg, cb, a
    end

    -- The chrome degrades to NOTHING rather than to a hand-copied backdrop: Core.SKIN's values ARE the
    -- contract (standalone-windows), and a host copy is the copy that goes stale. SKIN is an empty
    -- table so a window may index it unguarded, and MakeCloseButton answers nil exactly as Core's own
    -- does where CreateFrame is unavailable.
    NS.SKIN            = {}
    NS.ApplySkin       = function() end
    NS.MakeCloseButton = function() return nil end

    local announced = false
    function NS.Print(...)
        local parts = { NS.PREFIX }
        for i = 1, select("#", ...) do parts[i + 1] = NS.SafeToString((select(i, ...))) end
        if not DEFAULT_CHAT_FRAME then return end
        if not announced then
            announced = true
            DEFAULT_CHAT_FRAME:AddMessage(NS.SafeToString(NS.PREFIX) .. " " ..
                NS.LIBKA0S_MISSING .. "; " .. NS.L["running on reduced built-in fallbacks."])
        end
        DEFAULT_CHAT_FRAME:AddMessage(table.concat(parts, " "))
    end
    Util.print = NS.Print

    -- The formatting half, with the library's contract: every argument is stringified secret-safe
    -- BEFORE format sees it, so a secret in a %s slot prints the sentinel instead of raising. Reached
    -- through NS.Print at call time, so the one-time notice above still leads.
    function NS.Printf(fmt, ...)
        local n = select("#", ...)
        if n == 0 then return NS.Print(NS.SafeToString(fmt)) end
        local parts = {}
        for i = 1, n do parts[i] = NS.SafeToString((select(i, ...))) end
        NS.Print(NS.SafeToString(fmt):format(unpack(parts, 1, n)))
    end
    Util.printf = NS.Printf

    return
end

NS.SafeToString = lib.SafeToString

-- ONE class-color resolver for the collection (options-ui-§17). Handed over by reference: it closes
-- over nothing of ours, and the memoized player color is the library's to keep.
NS.ResolveColor = lib.ResolveColor
-- The class lookup on its own, for a surface that reads a unit's class once and paints with it many
-- times (modules/Container.lua snapshots a tracked unit's class per apply).
NS.ClassColor = lib.ClassColor

-- The shared window edge: the standalone-windows skin seam, published flat for a future standalone
-- window so it reaches the edge by name rather than through a private lookalike (standalone-windows).
-- Nothing consumes it today: the addon has no standalone window, and the frame picker draws its own
-- outline rather than reading NS.SKIN.
NS.SKIN      = lib.SKIN
NS.ApplySkin = lib.ApplySkin

-- WRAPPED, TO SAY WHO IS ASKING — and this wrapper is a MUST (standalone-windows, anti-patterns
-- #64/#65). Core draws the catalog's `close` mark only when told which addon FOLDER to build the path
-- from, and a vendored library cannot work that out. A bare two-argument call to the factory draws
-- the fallback glyph with nothing raised, so EVERY close control goes through here:
--
--   grep -rn 'MakeCloseButton(' --include='*.lua' | grep -v '/libs/'
--
-- must return this definition and calls to NS.MakeCloseButton, and nothing else.
NS.MakeCloseButton = function(parent, onClick)
    return lib.MakeCloseButton(parent, onClick, addonName)
end

-- The prefix goes in as a FUNCTION: the printer is built once at load, and the function form keeps a
-- later change to NS.PREFIX from being frozen out.
local printer = lib:New({ prefix = function() return NS.PREFIX end })

-- NS.Print and NS.Util.print MUST be the SAME function object (architecture-§2, anti-pattern #36).
-- AceAddon:NewAddon(NS, …, "AceConsole-3.0") stamps AceConsole's :Print over NS.Print, and
-- core/AuraMaster.lua reclaims it by repointing NS.Print at NS.Util.print — which only restores what
-- the settings files captured because it is the identical object.
NS.Print = printer.Print
Util.print = NS.Print

-- The same rule for the formatting printer: AceConsole's mixins include :Printf too, so NS.Printf is
-- clobbered and reclaimed exactly like NS.Print. Format stringifies every argument secret-safe before
-- format() sees it, so a whole-sentence key with %s slots is formatted INSIDE the printer.
NS.Printf = printer.Format
Util.printf = NS.Printf
