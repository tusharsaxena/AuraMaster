-- tests/wow_mock.lua — Ka0s Aura Master's WoW-API mock: the shared base (tests/_kit/mock_base.lua)
-- plus the handful of APIs that are genuinely this addon's own.
--
-- Returns a builder, so each environment is fresh and isolated. What lives here, and why:
--
--   * THE AURA ENGINE. Blizzard's AuraContainer does all the aura work in the client; headlessly it
--     is a RECORDER. Every method modules/Container.lua calls on it is logged in order on
--     `engine.__calls`, because the contract this addon keeps with the engine is an ORDER (anchor
--     before the first group, the unit last) and a call count (an unchanged filter is not re-sent).
--     A test hands it frames to restyle through `engine.__frames[groupKey]`.
--   * The engine's enums, so Compat.HasAuraContainer answers true as it does on a 12.1 client.
--   * C_Secrets, driven by `M.__aurasSecret`, so the defer-while-secret path is reachable.
--   * The frame picker's cursor, buttons and focus stack.
--   * AceGUI:Release, which the base kit does not model; the chrome band releases its widgets.

local base = dofile("tests/_kit/mock_base.lua")

-- Every engine method modules/Container.lua and modules/Style*.lua reach for. Recorded rather than
-- no-opped (fidelity rule 3): the metatable's blanket "return the frame" would let an order bug pass.
local ENGINE_METHODS = {
    "SetFlowLayoutAxis", "SetFlowLayoutAnchorPoint", "SetFlowLayoutGrowthDirection",
    "SetFlowLayoutPadding", "SetFlowLayoutMaximumLineSize",
    "AddAuraGroup", "SetAuraGroupFilterString", "SetAuraGroupCandidateFilters",
    "SetAuraGroupSortMethod", "SetAuraGroupMaxFrameCount", "SetAuraGroupLayout",
    "SetItemEnchantmentSortMethod", "SetItemEnchantmentLayout",
    "SetUnit", "UpdateAllAuras", "SetPoint", "ClearAllPoints",
}

return function()
    local M = base()

    -- ── the aura engine ─────────────────────────────────────────────────────────────────────
    M.AuraContainerSortMethod = {
        Default = 0, Expiration = 1, ExpirationOnly = 2, Name = 3, NameOnly = 4, BigDefensive = 5,
        ImportantOnly = 6, UnitFrameDebuff = 7, AuraInstanceIDOnly = 8,
    }
    M.AuraContainerSortDirection = { Normal = 0, Reverse = 1 }
    M.AuraContainerItemEnchantmentSlot = { MainHand = 0, OffHand = 1, Ranged = 2 }
    M.AuraContainerItemEnchantmentSortMethod = { Duration = 1 }
    M.CustomAuraContainerItemEnchantmentPlacement = { AfterAuraGroups = 1 }

    M.__engines = {}

    local function makeEngine(f)
        f.__calls = {}
        f.__frames = {}
        for _, name in ipairs(ENGINE_METHODS) do
            f[name] = function(self, ...)
                self.__calls[#self.__calls + 1] = { name, ... }
                return self
            end
        end
        -- SetEnabled is recorded AND tracked, so both "was it called" and "is it enabled" answer.
        function f:SetEnabled(v)
            self.__calls[#self.__calls + 1] = { "SetEnabled", v }
            self.__enabled = not not v
            return self
        end
        function f:AddItemEnchantment(slot, opts)
            self.__calls[#self.__calls + 1] = { "AddItemEnchantment", slot, opts }
            local frame = M.__stubFrame()
            frame.__enchantSlot = slot
            return frame
        end
        function f:GetAuraGroupFrameCount(key) return #(self.__frames[key] or {}) end
        function f:GetAuraGroupFrame(key, i) return (self.__frames[key] or {})[i] end
        --- Every call to `name`, in order (a test helper; not engine API).
        function f:__callsTo(name)
            local out = {}
            for _, c in ipairs(self.__calls) do if c[1] == name then out[#out + 1] = c end end
            return out
        end
        --- The index of the first call to `name`, or nil.
        function f:__firstCall(name)
            for i, c in ipairs(self.__calls) do if c[1] == name then return i end end
            return nil
        end
        M.__engines[#M.__engines + 1] = f
        return f
    end

    -- Named frames land in __globals so a test can plant a frame another addon would have created
    -- and modules/Anchors.lua can find it through _G (the loader resolves the mock before _G).
    M.__globals = {}
    local baseCreate = M.CreateFrame
    M.CreateFrame = function(frameType, name, parent, template)
        local f = baseCreate(frameType, name, parent, template)
        -- Frame level is arithmetic in production (the drag handle sits 50 above its anchor), so it
        -- answers a real number (fidelity rule 2) and records what was set.
        f.__level = 0
        function f:SetFrameLevel(v) self.__level = v; return self end
        function f:GetFrameLevel() return self.__level end
        if frameType == "AuraContainer" then makeEngine(f) end
        if type(name) == "string" then M.__globals[name] = f end
        return f
    end
    -- The frame picker divides the cursor position by the UI scale.
    M.UIParent.GetEffectiveScale = function() return 1 end

    -- ── secrets ─────────────────────────────────────────────────────────────────────────────
    M.__aurasSecret = false
    M.C_Secrets = { ShouldAurasBeSecret = function() return M.__aurasSecret end }

    -- ── combat lockdown, settable (the base answers false forever) ─────────────────────────
    M.__lockdown = false
    M.InCombatLockdown = function() return M.__lockdown end

    -- ── spells ──────────────────────────────────────────────────────────────────────────────
    M.__spells = { [774] = { name = "Rejuvenation", iconID = 136081 } }
    M.C_Spell = {
        GetSpellInfo = function(id)
            local s = M.__spells[id]
            if not s then return nil end
            return { name = s.name, iconID = s.iconID }
        end,
    }

    -- ── the frame picker ───────────────────────────────────────────────────────────────────
    M.__mouseDown = {}
    M.IsMouseButtonDown = function(button) return M.__mouseDown[button] == true end
    M.GetCursorPosition = function() return 100, 100 end
    M.__foci = {}
    M.GetMouseFoci = function() return M.__foci end

    -- ── class colors (LibKa0s-Core's resolver reads RAID_CLASS_COLORS) ─────────────────────
    M.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }

    -- ── AceGUI:Release ─────────────────────────────────────────────────────────────────────
    -- The kit's factory never takes a widget back; the chrome block releases its own. Modeled on
    -- the real one's observable effect plus a recorder, and reported upstream rather than patched
    -- into the vendored kit.
    local aceGUI = M.__libs["AceGUI-3.0"]
    aceGUI.__released = {}
    function aceGUI:Release(widget)
        if not widget then return end
        widget.__released = true
        if widget.frame then widget.frame:Hide() end
        self.__released[#self.__released + 1] = widget
    end

    -- ── AceConsole's Printf ────────────────────────────────────────────────────────────────
    -- The LibKa0s v1.29.0 kit's NewAddon stamps Print but not Printf; delete on the re-vendor that
    -- adds it. The real AceConsole-3.0 Embed stamps both mixins, so NS.Printf is clobbered exactly as
    -- NS.Print is, and core/AuraMaster.lua must reclaim both. Mirrored as the real one behaves when
    -- called bare (`NS.Printf(fmt, …)`): the format string lands in `self`, green with a trailing
    -- colon, and the rest are formatted without it.
    local aceAddon = M.__libs["AceAddon-3.0"]
    local kitNewAddon = aceAddon.NewAddon
    aceAddon.NewAddon = function(lib, target, ...)
        target = kitNewAddon(lib, target, ...)
        target.Printf = function(selfOrFmt, ...)
            local body = select("#", ...) > 0 and string.format(...) or ""
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. tostring(selfOrFmt) .. "|r: " .. body)
            end
        end
        return target
    end

    -- ── AceEvent's event half on an embed ──────────────────────────────────────────────────
    -- The LibKa0s v1.29.0 kit's AceEvent Embed has no RegisterEvent; delete this on the re-vendor
    -- that adds it. The real Embed stamps RegisterEvent, UnregisterEvent and UnregisterAllEvents on
    -- every target, and a module's own target from NS.NewBusTarget() registers game events on it.
    -- Recorded rather than no-opped, so a test can see what is registered right now and fire a
    -- handler as CallbackHandler would: `handler(event, ...)`. Cleared in place, so a table a test
    -- captured stays the live one.
    local aceEvent = M.__libs["AceEvent-3.0"]
    local kitEmbed = aceEvent.Embed
    aceEvent.Embed = function(lib, obj)
        obj = kitEmbed(lib, obj)
        obj.__events = {}
        obj.RegisterEvent = function(self, event, handler)
            self.__events[event] = handler or true
            return self
        end
        obj.UnregisterEvent = function(self, event)
            self.__events[event] = nil
            return self
        end
        obj.UnregisterAllEvents = function(self)
            for k in pairs(self.__events) do self.__events[k] = nil end
            return self
        end
        return obj
    end

    -- ── _G ──────────────────────────────────────────────────────────────────────────────────
    -- The loader resolves a bare global against the mock first, but `_G.X` in addon code reads the
    -- `_G` KEY — which the mock did not have, so it fell through to the harness process's own global
    -- table and every `_G.C_Secrets` / `_G.AuraContainerSortMethod` in core/Compat.lua saw nothing.
    -- This proxy answers the planted named frames, then the mock, then the process globals; writes
    -- land in the process globals exactly as the loader's own __newindex does.
    local realG = _G
    M._G = setmetatable({}, {
        __index = function(_, k)
            local v = M.__globals[k]
            if v ~= nil then return v end
            v = M[k]
            if v ~= nil then return v end
            return realG[k]
        end,
        __newindex = function(_, k, v) rawset(realG, k, v) end,
    })

    return M
end
