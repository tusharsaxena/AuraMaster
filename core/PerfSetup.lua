local addonName, NS = ...

-- core/PerfSetup.lua — the LibKa0s-Perf-1.0 seam (performance).
--
-- The probe, its record schema and the clickable step panel are the library's and shared across every
-- Ka0s addon. What is ours: which hot paths get buckets, what "suspended" means here, and where the
-- output goes.
--
-- LOAD-BEARING POSITION: the instance is built at FILE LOAD, before any module takes
-- `local Perf = NS.Perf` as a load-time upvalue (core/AuraMaster.lua, modules/Container.lua,
-- modules/ContainerManager.lua, modules/Style.lua, modules/TimedSpells.lua), so this file precedes
-- all of them in the TOC.

local lib = LibStub and LibStub("LibKa0s-Perf-1.0", true)
if not lib then
    -- Degrade, never error. The stub carries EVERY member the addon calls: the bracket gate and sink
    -- (`on` / `Note`), the probe's `suspended` view, and `OnCommand`, because `/am perf` is
    -- registered unconditionally and an honest line beats a Lua error.
    NS.Perf = {
        on        = false,
        suspended = false,
        Note      = function() end,
        OnCommand = function()
            return { NS.L["%s, so performance measurement is unavailable."]:format(NS.LIBKA0S_MISSING) }
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
    -- WHAT IS NOT HERE: the containers' aura events and timer ticks. Blizzard's aura engine owns both
    -- — it handles each container's UNIT_AURA and animates every bar and countdown in its own code.
    -- The addon has one aura-driven Lua path of its own, the readable-state timed-spell scan, and it
    -- is bracketed (`timedScan`). The rest of its cost is the configuration work below, plus the
    -- engine's own, which the capture's frame-time arms measure (performance-§7).
    buckets = {
        -- core/AuraMaster.lua: target / focus / pet changed, so every container on that unit is told
        -- to refresh. The one path that runs on ordinary combat activity.
        { key = "unitSwap" },
        -- modules/ContainerManager.lua: the coalesced pass that applies pending configuration to
        -- every dirty container.
        { key = "applyPass" },
        -- modules/Container.lua: compile, then build or update ONE container's engine, inside the pass.
        { key = "applyContainer", within = "applyPass" },
        -- modules/ContainerManager.lua: the show ladder re-evaluated for every container (combat, settings).
        { key = "visibilityPass" },
        -- modules/Style.lua: dressing one bar or icon — called by the engine's initializeFrame as it
        -- creates buttons, and by a restyle after a settings change.
        { key = "styleElement" },
        -- modules/TimedSpells.lua: one readable-state scan of the player's and pet's buffs, 0.5 s
        -- after their auras changed.
        { key = "timedScan" },
    },

    -- THE SUSPENDED ARM IS A HOLD ON THE ADDON'S LATCH, not a second teardown path
    -- (slash-commands-§7, LibKa0s-Lifecycle-1.0). This descriptor used to carry `suspend` and
    -- `resume`; those two functions are now core/LifecycleSetup.lua's `standDown` and `standUp`,
    -- MOVED rather than copied, and the probe takes the `perf` hold on that same latch. So
    -- `/am disable` during a capture and a resume at the end of one cannot contradict each other:
    -- the arm releases its own hold, and an addon the player disabled mid-run stays down.
    lifecycle = NS.lifecycle,

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
