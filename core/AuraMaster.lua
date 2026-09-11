local addonName, NS = ...

-- core/AuraMaster.lua — the AceAddon, its lifecycle, and the handful of game events the addon itself
-- has to hear.
--
-- Most aura events are NOT handled here, and that is the design rather than an omission: each
-- container's Blizzard aura engine registers UNIT_AURA for its own unit and processes it in secure
-- code. What the engine does not do is notice that `target`, `focus` or `pet` now names a different
-- unit, or that aura secrecy lifted so a deferred rebuild can run — those are the events below.

-- The perf probe, taken as a load-time upvalue (core/PerfSetup.lua loads earlier), so a dormant
-- bracket costs one upvalue read and one field read.
local Perf = NS.Perf

-- AceAddon promotion (architecture-§2): NS is passed in, so the namespace and the addon are one table.
local AceAddon = LibStub("AceAddon-3.0")
local addon = AceAddon:NewAddon(NS, addonName, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")
NS.addon = addon

-- Reclaim NS.Print and NS.Printf from AceConsole's embed, which stamps its own :Print and :Printf
-- over ours (architecture-§2, anti-pattern #36). core/CoreSetup.lua stashed the real printers at
-- NS.Util.print and NS.Util.printf, the same objects.
if NS.Util and NS.Util.print then NS.Print = NS.Util.print end
if NS.Util and NS.Util.printf then NS.Printf = NS.Util.printf end

function addon:OnInitialize()
    NS:InitDB()
    if NS.Slash and NS.Slash.Register then NS.Slash:Register() end
end

-- PLAYER_LOGIN timing. Containers are built here rather than at load: the engine applies its access
-- restrictions to aura buttons at PLAYER_ENTERING_WORLD, and building before that gives every button's
-- initializeFrame an unrestricted window (Blizzard_AuraContainerUtil.ApplyAccessRestrictions).
function addon:OnEnable()
    self:RegisterLifecycleEvents()
    if NS.ContainerManager and NS.ContainerManager.Init then NS.ContainerManager.Init() end
    if NS.BlizzardFrames and NS.BlizzardFrames.Apply then NS.BlizzardFrames.Apply() end
    if NS.CreateOptionsPanel then NS.CreateOptionsPanel() end
end

--- Every event the addon registers. Extracted so the perf probe's resume restores exactly what suspend
--- removed (core/PerfSetup.lua), instead of a hand-kept copy of this list.
function addon:RegisterLifecycleEvents()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnterWorld")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatChanged")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatChanged")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnUnitSwap")
    self:RegisterEvent("PLAYER_FOCUS_CHANGED", "OnUnitSwap")
    self:RegisterEvent("UNIT_PET", "OnUnitPet")
    self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")
    -- Fires when aura secrecy starts or stops; a rebuild queued while auras were secret runs here.
    self:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED", "OnRestrictionChanged")
end

function addon:UnregisterLifecycleEvents()
    for _, event in ipairs({
        "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_PET", "ADDON_LOADED",
        "ADDON_RESTRICTION_STATE_CHANGED",
    }) do
        self:UnregisterEvent(event)
    end
end

function addon:OnEnterWorld()
    NS.Debug("World", "entering world")
    NS.bus:SendMessage(NS.MSG.VISIBILITY_CHANGED)
    if NS.ContainerManager then NS.ContainerManager.FlushPending() end
end

function addon:OnCombatChanged(event)
    NS.bus:SendMessage(NS.MSG.VISIBILITY_CHANGED)
    if event == "PLAYER_REGEN_ENABLED" then
        -- "regen": the deferral notice never escalates on this edge (modules/ContainerManager.lua).
        -- Then a container whose unit swapped during combat re-applies for its new unit's class.
        if NS.ContainerManager then
            NS.ContainerManager.FlushPending("regen")
            NS.ContainerManager.ReapplyStaleClass()
        end
        if NS.BlizzardFrames and NS.BlizzardFrames.Apply then NS.BlizzardFrames.Apply() end
        -- A frame an add-on created during combat could not be resolved then (OnAddonLoaded).
        if NS.Anchors and NS.Anchors.ResolvePending then NS.Anchors.ResolvePending() end
    end
end

-- The engine keeps showing the OLD unit's auras after `target` or `focus` starts naming someone else
-- until told to refresh (AuraContainerSharedMixin:UpdateAllAuras is "exposed to allow external events
-- to trigger refreshes where needed (e.g. target changes)").
function addon:OnUnitSwap(event)
    local t0 = Perf.on and debugprofilestop()
    local unit = (event == "PLAYER_FOCUS_CHANGED") and "focus" or "target"
    if NS.ContainerManager then NS.ContainerManager.RefreshUnit(unit) end
    if t0 then Perf.Note("unitSwap", debugprofilestop() - t0) end
end

function addon:OnUnitPet(_, unit)
    if unit ~= "player" then return end
    local t0 = Perf.on and debugprofilestop()
    if NS.ContainerManager then NS.ContainerManager.RefreshUnit("pet") end
    if t0 then Perf.Note("unitSwap", debugprofilestop() - t0) end
end

-- A container attached to a frame another add-on creates cannot find that frame until the add-on
-- loads; re-resolve pending frame anchors each time one does.
function addon:OnAddonLoaded()
    if NS.Anchors and NS.Anchors.ResolvePending then NS.Anchors.ResolvePending() end
end

function addon:OnRestrictionChanged()
    if NS.ContainerManager then
        NS.ContainerManager.FlushPending()
        NS.ContainerManager.ReapplyStaleClass()
    end
end

--- AceDB profile callback (core/Database.lua): the new profile gets its registry prepared, every
--- container is rebuilt from it, and an open settings panel re-renders.
function NS.OnProfileChanged()
    if NS.Database and NS.db then NS.Database.PrepareProfile(NS.db.profile) end
    if NS.State then NS.State.SetActiveContainer(nil) end
    NS.Debug("Profile", "changed -> %s",
        (NS.db and NS.db.GetCurrentProfile and NS.db:GetCurrentProfile()) or "?")
    if NS.ContainerManager and NS.ContainerManager.Announce then NS.ContainerManager.Announce() end
    if NS.BlizzardFrames and NS.BlizzardFrames.Apply then NS.BlizzardFrames.Apply() end
    if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
end
