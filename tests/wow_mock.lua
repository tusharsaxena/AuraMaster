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

    -- Every recorded engine call goes through here. `__counts` (calls by name) is always kept and
    -- allocates nothing once a name has been seen; the `__calls` log allocates a table per call, so
    -- tests/perf.lua sets `M.__countOnly` around its measured loops to keep the mock's own garbage
    -- out of the addon's bytes-per-iteration figure.
    local function record(self, name, ...)
        self.__counts[name] = (self.__counts[name] or 0) + 1
        if not M.__countOnly then
            self.__calls[#self.__calls + 1] = { name, ... }
        end
    end

    local function makeEngine(f)
        f.__calls = {}
        f.__counts = {}
        f.__frames = {}
        for _, name in ipairs(ENGINE_METHODS) do
            f[name] = function(self, ...)
                record(self, name, ...)
                return self
            end
        end
        -- SetEnabled is recorded AND tracked, so both "was it called" and "is it enabled" answer.
        function f:SetEnabled(v)
            record(self, "SetEnabled", v)
            self.__enabled = not not v
            return self
        end
        function f:AddItemEnchantment(slot, opts)
            record(self, "AddItemEnchantment", slot, opts)
            local frame = M.__stubFrame()
            frame.__enchantSlot = slot
            return frame
        end
        function f:GetAuraGroupFrameCount(key)
            local frames = self.__frames[key] or {}
            return #frames
        end
        function f:GetAuraGroupFrame(key, i) return (self.__frames[key] or {})[i] end
        --- Every call to `name`, in order (a test helper; not engine API).
        function f:__callsTo(name)
            local out = {}
            for _, c in ipairs(self.__calls) do
                if c[1] == name then
                    out[#out + 1] = c
                end
            end
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

    -- Opt-in live geometry. The kit answers GetWidth/GetHeight with 0 until a test arms a frame, and
    -- the tab strip's pitch is measured on a probe texture the library builds for itself, which no
    -- test can reach to arm by hand. Setting `M.__armGeometry = true` in a fresh env's `before` arms
    -- every frame created after that, and every texture each of those frames creates, so the probe's
    -- SetAtlas measures. Off by default, because every other suite leans on the zeros.
    M.__armGeometry = false
    local function armGeometry(f)
        f:__setGeom()
        local create = f.CreateTexture
        rawset(f, "CreateTexture", function(self, ...)
            local tex = create(self, ...)
            if type(tex) == "table" and tex.__setGeom and not tex.__geomLive then tex:__setGeom() end
            return tex
        end)
    end

    local baseCreate = M.CreateFrame
    M.CreateFrame = function(frameType, name, parent, template)
        local f = baseCreate(frameType, name, parent, template)
        if M.__armGeometry then armGeometry(f) end
        -- Frame level is arithmetic in production (the drag handle sits 50 above its anchor), so it
        -- answers a real number (fidelity rule 2) and records what was set. The default below — a
        -- frame with no explicit level sits one above its parent's CURRENT level at creation — is
        -- this mock's ASSUMPTION about the client, not a verified fact (review round 2, B-9): nothing
        -- in this repo establishes it, and it replaced an earlier flat 0 that made a production write
        -- look load-bearing when it was not. It is also NOT re-derived when a parent's level changes
        -- later — real or assumed, the client does not re-base existing descendants either — so no
        -- test may rely on a child's level tracking a parent's level past the moment it was created.
        -- Anything that must hold across a later re-level (Container.lua's ApplyBlocker) reads the
        -- other frame's CURRENT level itself rather than trusting this default to still apply.
        f.__level = (parent and parent.__level or 0) + 1
        function f:SetFrameLevel(v) self.__level = v; return self end
        function f:GetFrameLevel() return self.__level end
        -- The client's layout cache: recorded so a test can see an anchor opt out of it.
        function f:SetDontSavePosition(v) self.__dontSavePosition = v; return self end
        -- The container's mouse blocker (modules/Container.lua's ApplyBlocker) covers whatever engine
        -- currently exists with SetAllPoints and is gated with SetMouseMotionEnabled /
        -- SetMouseClickEnabled, exactly like a live button (Style.ApplyBehavior). All three branch
        -- production behavior, so they are recorded rather than no-opped (fidelity rule 3).
        function f:SetAllPoints(target) self.__allPointsTo = target; return self end
        function f:SetMouseMotionEnabled(v) self.__mouseMotionOn = not not v; return self end
        function f:SetMouseClickEnabled(v) self.__mouseClickOn = not not v; return self end
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

    -- AceGUI:Release, AceConsole's Printf and AceEvent's event half on an embed are the kit's
    -- (kit revision 16, tusharsaxena/LibKa0s#27, #29, #30); this file once shimmed all three.

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
