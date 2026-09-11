local _, NS = ...

-- modules/BlizzardFrames.lua — hiding Blizzard's own buff and debuff frames, for a player who has
-- replaced them with containers.
--
-- REPARENTED, NEVER HIDDEN (events-frames-taint-§3). Blizzard's buff display is an Edit Mode system:
-- Hide() does not stick, and hiding a Blizzard frame from addon code spreads taint. Moving it under a
-- frame that is never shown keeps it off screen without fighting anything, and putting it back is the
-- same call. The player's temporary weapon enchants live inside BuffFrame, so they go with it.
--
-- Out of combat only: reparenting a Blizzard frame during combat lockdown is refused. A change made
-- in combat is applied on PLAYER_REGEN_ENABLED (core/AuraMaster.lua), and the toggle's onChange
-- (settings/General.lua) tells the player it is waiting.

NS.BlizzardFrames = NS.BlizzardFrames or {}
local BF = NS.BlizzardFrames

local hiddenParent
local originalParent = {}   -- [frame] = the parent it had before we moved it

local function hidden()
    if not hiddenParent then
        hiddenParent = CreateFrame("Frame", nil, UIParent)
        hiddenParent:Hide()
    end
    return hiddenParent
end

local function apply(name, hide)
    local f = _G[name]
    if type(f) ~= "table" or not f.SetParent then return end
    if hide then
        if originalParent[f] == nil then originalParent[f] = f.GetParent and f:GetParent() or UIParent end
        f:SetParent(hidden())
    elseif originalParent[f] ~= nil then
        f:SetParent(originalParent[f])
        originalParent[f] = nil
    end
end

--- Apply the profile's two settings. Returns true when applied, false when it has to wait for
--- combat to end, and nil when no profile is loaded (nothing to apply, and nothing waiting).
function BF.Apply()
    if InCombatLockdown() then return false end
    local p = NS.db and NS.db.profile
    if not p then return nil end
    apply("BuffFrame", p.hideBlizzardBuffs)
    apply("DebuffFrame", p.hideBlizzardDebuffs)
    return true
end

--- Whether `name`'s frame is currently moved away by us (a test seam).
function BF.IsHidden(name)
    local f = _G[name]
    return f ~= nil and originalParent[f] ~= nil
end
