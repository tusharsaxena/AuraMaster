local addonName, NS = ...

-- core/LifecycleSetup.lua — the LibKa0s-Lifecycle-1.0 seam: ONE latch, two named holds, and the
-- addon's single way down and single way back up (slash-commands-§7).
--
-- WHY A LATCH AND NOT A BOOLEAN. There are two independent reasons for this addon to be inert — the
-- player unticked "Enable Aura Master", and the perf harness is measuring its suspended arm — and
-- the interesting state is the one a boolean cannot hold: both at once. A resume that wrote `false`
-- would stand the addon back up under a player who had switched it off, and a `/am enable` mid-run
-- would resurrect it inside the capture. Holds do not have that failure: releasing `perf` leaves
-- `disabled` taken, the set is still non-empty, and nothing is rebuilt.
--
-- ONE MECHANISM, NOT TWO. The suspend/resume pair core/PerfSetup.lua used to carry IS this file's
-- `standDown` / `standUp`, moved rather than copied. A second teardown path beside the perf one is
-- anti-pattern #85's last clause: two mechanisms that both mean "inert" must agree about what inert
-- means, and they diverge on the first module added after the second one was written.
--
-- DISABLED IS TOTAL, NOT A DRAW GATE. `standDown` UNREGISTERS every event and message this addon
-- owns rather than gating a handler on a flag. A handler that early-returns did not stop watching,
-- it stopped reacting: the client still walks the registration list on every event, still builds
-- the argument frame, still enters Lua — which is exactly the cost a player switching the addon off
-- is trying to stop paying.
--
-- LOAD-BEARING POSITION: before core/PerfSetup.lua, which takes this instance as its `lifecycle`
-- descriptor field and raises without one.

--- Is the addon enabled, from the stored path? EXPLICITLY false only: before core/Database.lua
--- builds NS.db the read answers nil, and reading nil as "off" would hold the addon down on a load
--- that has not finished. Published: settings/Slash.lua hands this same function to the dispatcher
--- as its `isEnabled`, asked at dispatch time, so the gate and the stand-down read one predicate.
function NS.EnabledStored()
    return NS.GetSetting("enabled") ~= false
end
local enabledStored = NS.EnabledStored

-- ---------------------------------------------------------------------------
-- The secure half, which combat can refuse
-- ---------------------------------------------------------------------------
--
-- Two things a stand-down has to do are refused under combat lockdown: reparenting Blizzard's buff
-- and debuff frames back where they belong, and hiding a container's anchor, which is an aura
-- engine's ancestry (events-frames-taint-§2). Neither may be attempted in combat, so the stand-down
-- holds them PENDING and finishes on PLAYER_REGEN_ENABLED — the one registration slash-commands-§7
-- permits a disabled addon to keep, released the moment it fires.

local PENDING_EVENT = "PLAYER_REGEN_ENABLED"
local pendingHeld = false

local function releasePending()
    if not pendingHeld then return end
    pendingHeld = false
    local addon = NS.addon
    if addon and addon.UnregisterEvent then addon:UnregisterEvent(PENDING_EVENT) end
end

--- Do the combat-restricted half, and answer whether it finished. `false` means combat refused it.
local function applySecure()
    local done = true
    if NS.BlizzardFrames and NS.BlizzardFrames.Apply then
        if NS.BlizzardFrames.Apply() == false then done = false end
    end
    if NS.ContainerManager and NS.ContainerManager.ApplyVisibility then
        if NS.ContainerManager.ApplyVisibility() == false then done = false end
    end
    return done
end

local function holdPending()
    if pendingHeld then return end
    local addon = NS.addon
    if not (addon and addon.RegisterEvent) then return end
    -- Held only if the registration took. A client that refused the name leaves the hold untaken
    -- (the name is in NS.RejectedEvents), and the secure half is retried on the next stand-down or up.
    pendingHeld = NS.SafeRegisterEvent(addon, PENDING_EVENT, function()
        -- Released FIRST: the registration is permitted only while work is owed, and a handler that
        -- unregistered itself after re-arming would keep a registration nothing is waiting on.
        releasePending()
        if NS.IsStoodDown() and not applySecure() then holdPending() end
    end, NS.RejectedEvents)
end

-- ---------------------------------------------------------------------------
-- The two edges
-- ---------------------------------------------------------------------------

--- EMPTY -> NON-EMPTY: the addon stops. Every registration it owns is gone, not gated; every timer
--- it can cancel is canceled; the show ladder answers no at its source (modules/Container.lua's
--- ShouldShow reads the latch as step 0), so a combat transition or a settings change cannot re-show
--- a container behind the latch's back.
local function standDown()
    local addon = NS.addon
    if addon and addon.UnregisterLifecycleEvents then addon:UnregisterLifecycleEvents() end
    if NS.TimedSpells and NS.TimedSpells.StandDown then NS.TimedSpells.StandDown() end
    -- Its unit frames and swap events, closed by hand (modules/EmptyWatch.lua).
    if NS.EmptyWatch and NS.EmptyWatch.Stop then NS.EmptyWatch.Stop() end
    if NS.ContainerManager and NS.ContainerManager.StopListening then NS.ContainerManager.StopListening() end
    -- The frame picker's overlay runs an OnUpdate; a stood-down addon runs none.
    if NS.FramePicker and NS.FramePicker.Stop then NS.FramePicker.Stop() end
    if not applySecure() then holdPending() end
end

--- NON-EMPTY -> EMPTY: the addon comes back, rebuilt from the settings AS THEY ARE NOW rather than
--- from a snapshot taken on the way down (performance-§6). A setting changed while the addon was off
--- is what the player expects to see when it comes back on.
local function standUp()
    releasePending()
    local addon = NS.addon
    if addon and addon.RegisterLifecycleEvents then addon:RegisterLifecycleEvents() end
    if NS.ContainerManager and NS.ContainerManager.StartListening then NS.ContainerManager.StartListening() end
    if NS.TimedSpells and NS.TimedSpells.StandUp then NS.TimedSpells.StandUp() end
    -- A combat edge missed while down (its events were unregistered) is settled from the state now.
    if NS.EmptyWatch and NS.EmptyWatch.SetCombat then NS.EmptyWatch.SetCombat(InCombatLockdown()) end
    if NS.BlizzardFrames and NS.BlizzardFrames.Apply then NS.BlizzardFrames.Apply() end
    if NS.ContainerManager then
        -- Build (or revive) what a disabled login or a profile switch made while down never built,
        -- before the visibility pass that shows it.
        if NS.ContainerManager.Sync then NS.ContainerManager.Sync() end
        if NS.ContainerManager.ApplyVisibility then NS.ContainerManager.ApplyVisibility() end
        -- The addon's own request: a player change held by the stand-down keeps its notice.
        if NS.ContainerManager.RequestApply then NS.ContainerManager.RequestApply(nil, true) end
    end
end

-- ---------------------------------------------------------------------------
-- The latch
-- ---------------------------------------------------------------------------

local Lifecycle = LibStub and LibStub("LibKa0s-Lifecycle-1.0", true)

if not Lifecycle then
    -- Degrade, never error. Without the library there is no hold registry, so a local one-hold
    -- latch, fed from the stored path by SyncEnabled, answers the one question the rest of the
    -- addon asks — which keeps the show ladder honest and leaves modules/Container.lua's step 0
    -- reading the same seam on every build.
    --
    -- EDGE-TRIGGERED, LIKE THE LIBRARY. `down` is the stub's one-hold latch and starts where the
    -- library's empty latch starts, up: the load-time SyncEnabled of an enabled install is then a
    -- no-op, as it is with LibKa0s-Lifecycle, and a profile switch that agrees with the old one
    -- costs nothing. A stub that ran standUp on every call re-registered every event and armed an
    -- apply pass each time. This mirrors the member's edge semantics as a correctness property of
    -- the degraded path; it is not a library-stack-§7 copy of the member. The two readers answer
    -- from `down`, not the store, so the show ladder and the last edge always agree.
    NS.lifecycle = nil
    NS.HOLD_DISABLED, NS.HOLD_PERF = "disabled", "perf"
    local down = false
    function NS.IsStoodDown() return down end
    function NS.IsDisabled() return down end
    function NS.SyncEnabled()
        local want = not enabledStored()
        if want == down then return end
        down = want
        if want then standDown() else standUp() end
    end
    return
end

NS.HOLD_DISABLED, NS.HOLD_PERF = Lifecycle.HOLD_DISABLED, Lifecycle.HOLD_PERF

NS.lifecycle = Lifecycle:New({
    name      = addonName,
    standDown = standDown,
    standUp   = standUp,
    print     = function(line) NS.Print(line) end,
})

--- Is the addon inert right now, for ANY reason — the player's switch or a perf capture's suspended
--- arm. This is what the show ladder reads: step 0 asks whether the addon is running at all, and it
--- must not care WHY it is not.
function NS.IsStoodDown() return NS.lifecycle:IsDown() end

--- Is the addon inert because the PLAYER switched it off. The refusal line names `/am enable`, so
--- only this hold may print it: a perf capture is not something `/am enable` fixes.
function NS.IsDisabled() return NS.lifecycle:IsHeld(NS.HOLD_DISABLED) end

--- Take or release the `disabled` hold from the stored path. Every surface that can flip it — the
--- Master controls checkbox, `/am enable`, `/am disable`, `/am set enabled`, a profile switch and
--- the load-time read — lands here, so there is one branch rather than six.
function NS.SyncEnabled()
    NS.lifecycle:Set(NS.HOLD_DISABLED, not enabledStored())
    -- For a profile switch, where the path can move with nothing else being touched: fires a
    -- callback only on an actual edge, so agreeing profiles cost nothing.
    NS.lifecycle:Reevaluate()
end
