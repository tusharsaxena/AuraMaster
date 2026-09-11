local addonName, NS = ...

-- core/PerfSetup.lua — the LibKa0s-Perf-1.0 seam (performance).
--
-- The probe, its record schema and the clickable step panel are the library's and shared across every
-- Ka0s addon. What is ours: which hot paths get buckets, what "suspended" means here, and where the
-- output goes.
--
-- LOAD-BEARING POSITION: the instance is built at FILE LOAD, before any module takes
-- `local Perf = NS.Perf` as a load-time upvalue (core/AuraMaster.lua, modules/Container.lua,
-- modules/ContainerManager.lua, modules/Style.lua), so this file precedes all of them in the TOC.

local lib = LibStub and LibStub("LibKa0s-Perf-1.0", true)
if not lib then
    -- Degrade, never error. The stub carries EVERY member the addon calls: the bracket gate and sink
    -- (`on` / `Note`), the show-decision ladder's `suspended`, and `OnCommand`, because `/am perf` is
    -- registered unconditionally and an honest line beats a Lua error.
    NS.Perf = {
        on        = false,
        suspended = false,
        Note      = function() end,
        OnCommand = function()
            return { NS.LIBKA0S_MISSING .. ", " .. NS.L["so performance measurement is unavailable."] }
        end,
    }
    return
end

NS.Perf = lib:New({
    name      = addonName,
    -- THE FOLDER NAME, passed explicitly: the panel builds its close mark's texture path from it.
    addonName = addonName,
    title     = "Aura Master",
    slash     = "/am",
    version   = NS.version,
    sv        = "AuraMasterPerfDB",

    -- Declared in report order, with nesting DECLARED rather than explained (performance-§3). Every
    -- nested bracket also supplies its parent at the Perf.Note call, so the record carries observed
    -- containment rather than this table's claim.
    -- WHAT IS NOT HERE: aura events and timer ticks. Blizzard's aura engine owns both — it handles
    -- UNIT_AURA and animates every bar and countdown in its own code — so this addon has no per-aura
    -- Lua path at all to bracket. Its cost is the configuration work below, plus the engine's own,
    -- which the capture's frame-time arms measure (performance-§7).
    buckets = {
        -- core/AuraMaster.lua: target / focus / pet changed, so every container on that unit is told
        -- to refresh. The one path that runs on ordinary combat activity.
        { key = "unitSwap" },
        -- modules/ContainerManager.lua: the coalesced pass that applies pending configuration to
        -- every dirty container.
        { key = "applyPass" },
        -- modules/Container.lua: compile, then build or update ONE container's engine, inside the pass.
        { key = "applyContainer", within = "applyPass" },
        -- modules/Container.lua: the show ladder re-evaluated for every container (combat, settings).
        { key = "visibilityPass" },
        -- modules/Style.lua: dressing one bar or icon — called by the engine's initializeFrame as it
        -- creates buttons, and by a restyle after a settings change.
        { key = "styleElement" },
    },

    --- Make the addon inert without a /reload (performance-§6). Every event unregistered and every
    --- container's engine disabled; visibility is refused AT THE SOURCE — modules/Container.lua's show
    --- ladder checks NS.Perf.suspended as step 0, so nothing can re-enable an engine behind suspend's
    --- back.
    suspend = function()
        local addon = NS.addon
        if addon and addon.UnregisterLifecycleEvents then addon:UnregisterLifecycleEvents() end
        if NS.TimedSpells and NS.TimedSpells.Stop then NS.TimedSpells.Stop() end
        if NS.ContainerManager and NS.ContainerManager.ApplyVisibility then
            NS.ContainerManager.ApplyVisibility()
        end
    end,

    --- Restore from CURRENT state: re-register, then re-evaluate every container's visibility and
    --- apply anything that changed while suspended.
    resume = function()
        local addon = NS.addon
        if addon and addon.RegisterLifecycleEvents then addon:RegisterLifecycleEvents() end
        if NS.TimedSpells and NS.TimedSpells.Sync then NS.TimedSpells.Sync() end
        if NS.ContainerManager then
            if NS.ContainerManager.ApplyVisibility then NS.ContainerManager.ApplyVisibility() end
            if NS.ContainerManager.RequestApply then NS.ContainerManager.RequestApply() end
        end
    end,

    -- Perf output is not gated on the debug flag: a run is explicit user action.
    log = function(line)
        if NS.DebugLog and NS.DebugLog.Add then
            NS.DebugLog:Add("Perf", line)
        else
            NS.Print(line)
        end
    end,

    print = function(line) NS.Print(line) end,

    showLog = function()
        if NS.DebugLog and NS.DebugLog.Show and not NS.DebugLog:IsShown() then
            NS.DebugLog:Show()
        end
    end,

    -- NO `decorate`: the library's panel draws its own close control from `addonName`, so it matches
    -- the debug console with nothing wired here (performance-§4, anti-pattern #65).
})
