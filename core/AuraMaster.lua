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
    -- THE HOLD IS TAKEN FROM THE STORED PATH, here, before anything registers or draws. Not a
    -- special case: it is the same NS.SyncEnabled call the checkbox, the two verbs and the profile
    -- callbacks make (core/LifecycleSetup.lua). Surviving a /reload is the whole point of the
    -- setting, which is why this hold is the persisted one and `perf` is not.
    NS.SyncEnabled()
    if NS.Slash and NS.Slash.Register then NS.Slash:Register() end
    -- AFTER InitDB, never before: the launcher is handed `db.global.minimap`, which AceDB
    -- materializes from the declared default there. Idempotent, so a later caller may repeat it.
    if NS.Launcher then NS.Launcher:Register() end
end

-- PLAYER_LOGIN timing. Containers are built here rather than at load: the engine applies its access
-- restrictions to aura buttons at PLAYER_ENTERING_WORLD, and building before that gives every button's
-- initializeFrame an unrestricted window (Blizzard_AuraContainerUtil.ApplyAccessRestrictions).
function addon:OnEnable()
    -- The panel and the dispatcher are SETUP and come up in either state; everything else is a
    -- FEATURE and comes up only if the addon is actually running (slash-commands-§7). A disabled
    -- addon that registered its events at login and unregistered them a moment later would still
    -- have been watching for that moment, and would draw a container before hiding it. CM.Init reads
    -- the latch itself: a disabled login builds no container frame, and the stand-up builds them.
    if not NS.IsStoodDown() then
        self:RegisterLifecycleEvents()
        if NS.BlizzardFrames and NS.BlizzardFrames.Apply then NS.BlizzardFrames.Apply() end
    end
    if NS.ContainerManager and NS.ContainerManager.Init then NS.ContainerManager.Init() end
    if NS.CreateOptionsPanel then NS.CreateOptionsPanel() end
end

--- Every event the addon itself registers, and the method each is registered to. ONE list, read by
--- both the stand-up and the stand-down, so the two cannot drift apart.
local LIFECYCLE_EVENTS = {
    { "PLAYER_ENTERING_WORLD", "OnEnterWorld" },
    -- The loading screen's end, which PLAYER_ENTERING_WORLD is not: the font primer times from it.
    { "LOADING_SCREEN_DISABLED", "OnLoadingScreenEnd" },
    { "PLAYER_REGEN_DISABLED", "OnCombatChanged" },
    { "PLAYER_REGEN_ENABLED", "OnCombatChanged" },
    { "PLAYER_TARGET_CHANGED", "OnUnitSwap" },
    { "PLAYER_FOCUS_CHANGED", "OnUnitSwap" },
    { "UNIT_PET", "OnUnitPet" },
    { "ADDON_LOADED", "OnAddonLoaded" },
    -- Fires when aura secrecy starts or stops; a rebuild queued while auras were secret runs here.
    { "ADDON_RESTRICTION_STATE_CHANGED", "OnRestrictionChanged" },
    -- An item's data arrived: an equipped weapon's redraws the enchant names (SP-AMX-01). Both, as
    -- either may carry it; the reset they arm is debounced to one (modules/ContainerManager.lua).
    { "ITEM_DATA_LOAD_RESULT", "OnItemDataLoaded" },
    { "GET_ITEM_INFO_RECEIVED", "OnItemDataLoaded" },
    -- A border crossing into another kind of place with no loading screen: the zone gate's visibility
    -- pass (filter situations, S3). PLAYER_ENTERING_WORLD covers every loading screen.
    { "ZONE_CHANGED_NEW_AREA", "OnZoneChanged" },
}

--- Register the lifecycle events. Extracted so the stand-up restores exactly what the stand-down
--- removed (core/LifecycleSetup.lua). Each goes through NS.SafeRegisterEvent: a name this client
--- does not know costs only itself and is recorded in NS.RejectedEvents (events-frames-taint-§1).
function addon:RegisterLifecycleEvents()
    for _, e in ipairs(LIFECYCLE_EVENTS) do
        NS.SafeRegisterEvent(self, e[1], e[2], NS.RejectedEvents)
    end
end

function addon:UnregisterLifecycleEvents()
    for _, e in ipairs(LIFECYCLE_EVENTS) do
        self:UnregisterEvent(e[1])
    end
end

-- THE [Event] TRACE: one line per event that changes what the addon may do (world entry, the loading
-- screen, combat, aura secrecy), each ending in the three reads every apply decision turns on —
-- whether auras are secret, lockdown, and what is queued. Written BEFORE the handler acts, so the
-- queue is the one the event found; the [Apply] line that follows says what the flush did. Built
-- only while logging is on (debug-logging-§4): QueueSnapshot allocates. Target, focus and pet swaps
-- and ADDON_LOADED are deliberately left out (owner, 2026-09-29): they fire too often in a key.
local function traceEvent(event, fmt, ...)
    if not (NS.State and NS.State.debug) then return end
    local CM = NS.ContainerManager
    local q = CM and CM.QueueSnapshot and CM.QueueSnapshot()
    local queued = "-"
    if q then
        local n = #q.ids
        queued = q.all and "all" or tostring(n)
    end
    -- The sink stringifies every argument (LibKa0s-DebugLog's D.Debug), so booleans go in raw; the
    -- event's own fields come last because only a trailing `...` passes all of its values.
    NS.Debug("Event", "%s secret=%s lockdown=%s queued=%s" .. (fmt or ""), event,
        NS.Compat.AurasAreSecret(), InCombatLockdown() and true or false, queued, ...)
end

function addon:OnEnterWorld(event, isLogin, isReload)
    traceEvent(event, " login=%s reload=%s", isLogin and true or false, isReload and true or false)
    NS.bus:SendMessage(NS.MSG.VISIBILITY_CHANGED)
    if NS.ContainerManager then NS.ContainerManager.FlushPending() end
    -- The loading screen is still up here; the primer notes the time (issue #24, FP-06).
    if NS.FontPrimer then NS.FontPrimer.OnEnterWorld() end
end

-- The player may now be in another kind of place: re-run the visibility pass, which reads it
-- (modules/Container.lua zoneAllows). Untraced, like the unit swaps: it fires on every border.
function addon:OnZoneChanged()
    NS.bus:SendMessage(NS.MSG.VISIBILITY_CHANGED)
end

-- The loading screen is gone: a font primed under it is drawn only now (issue #24, FP-06), and the
-- weapon-enchant names are redrawn a moment later, whatever the primer did (SP-AMX-01).
function addon:OnLoadingScreenEnd(event)
    traceEvent(event)
    if NS.FontPrimer then NS.FontPrimer.OnLoadingScreenEnd() end
    if NS.ContainerManager then NS.ContainerManager.RequestEnchantReset("world") end
end

-- An item's data arrived. Untraced: GET_ITEM_INFO_RECEIVED fires for every item the client loads;
-- the reset an equipped weapon's arms writes its own [Apply] line.
function addon:OnItemDataLoaded(_, itemID, success)
    if NS.ContainerManager then NS.ContainerManager.OnWeaponItemData(itemID, success) end
end

function addon:OnCombatChanged(event)
    traceEvent(event)
    -- First, so the visibility pass below predicts nothing at the pull: PLAYER_REGEN_DISABLED fires
    -- before lockdown, the last moment every follower can still move onto its engine (batch 9 HG-1).
    if NS.EmptyWatch then NS.EmptyWatch.SetCombat(event == "PLAYER_REGEN_DISABLED") end
    -- Test mode ends when combat starts, while secure writes are still allowed (preview-mode): no
    -- placeholder covers real auras in a fight.
    if event == "PLAYER_REGEN_DISABLED" and NS.State.testMode then NS.Preview.SetTestMode(false, "combat started") end
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
-- to trigger refreshes where needed (e.g. target changes)"). The new unit's reaction picks the view of
-- each plan the engine holds (spell-list views, V2), so the view is switched FIRST: one refresh then
-- draws the new unit in the right view, never the old unit's view for a frame.
function addon:OnUnitSwap(event)
    local t0 = Perf.on and debugprofilestop()
    local unit = (event == "PLAYER_FOCUS_CHANGED") and "focus" or "target"
    local CM = NS.ContainerManager
    if CM then
        CM.ApplyViews(unit, true)   -- quiet: EmptyWatch's own swap handler re-predicts
        CM.RefreshUnit(unit)
    end
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

function addon:OnRestrictionChanged(event, restrictionType, active)
    traceEvent(event, " type=%s active=%s", restrictionType, active)
    if NS.ContainerManager then
        NS.ContainerManager.FlushPending()
        NS.ContainerManager.ReapplyStaleClass()
    end
    -- Secret auras make every prediction nil, so followers move onto their engines; readable again,
    -- they are predicted again.
    if NS.EmptyWatch then NS.EmptyWatch.Refresh() end
end

-- The three AceDB profile callbacks (core/Database.lua). Each prepares the new profile's registry,
-- traces the event ONCE in its own words, then rebuilds every container and re-renders an open
-- panel. A reset or a copy is AceDB replacing the profile whole, not a write through the seam, so it
-- is one [Set] line here and no bulk bracket adds a second (debug-logging-§10). A switch rewrites no
-- rows and keeps its [Profile] trace.

local function currentProfile()
    return (NS.db and NS.db.GetCurrentProfile and NS.db:GetCurrentProfile()) or "?"
end

--- Before the trace, so the trace follows the registry the new profile will run with.
local function prepareProfile()
    -- THE USER CATEGORIES FIRST, for the same reason NS.RunMigrations syncs before it prepares
    -- (issue #10 checkpoint 3): until the sync swaps them, the container template still carries the
    -- PREVIOUS profile's user keys, so PrepareProfile's backfill would write those dead keys into
    -- every container of the new profile while missing the new profile's own. Both call sites are
    -- edited together or the ordering holds in one path and not the other.
    if NS.Categories and NS.Categories.SyncUserCategories and NS.db then
        NS.Categories.SyncUserCategories(NS.db.profile)
    end
    if NS.Database and NS.db then NS.Database.PrepareProfile(NS.db.profile) end
    if NS.State then NS.State.SetActiveContainer(nil) end
    -- A PROFILE SWITCH CAN FLIP THE ENABLE PATH with no checkbox and no verb touched, so the latch
    -- is re-read from the new profile before anything rebuilds against it. `enabled` is a stored
    -- setting like any other, and a player switching to a profile where the addon is on expects it
    -- to come up (slash-commands-§7). This is the one reason a disabled addon MUST keep AceDB's
    -- three profile callbacks.
    NS.SyncEnabled()
end

local function rebuildProfile()
    -- The registry still follows the new profile while the addon is down -- its containers are the
    -- ones the stand-up will build -- but nothing below the panel refresh draws, builds or registers,
    -- because the show ladder and CM.Announce both read the latch.
    if NS.ContainerManager and NS.ContainerManager.Announce then NS.ContainerManager.Announce(true) end
    if NS.BlizzardFrames and NS.BlizzardFrames.Apply then NS.BlizzardFrames.Apply() end
    if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
end

--- OnProfileChanged: a switch.
function NS.OnProfileChanged()
    prepareProfile()
    NS.Debug("Profile", "changed -> %s", currentProfile())
    rebuildProfile()
end

--- OnProfileReset: the profile back to the addon's defaults (Reset all, Profiles → Reset Profile).
--- The line carries no row count, as debug-logging-§10 allows. A reset re-seeds the starter
--- containers, so counting the rows not at default would overcount. AceDB also gives no hook before
--- the wipe, so the Profiles page's Reset Profile cannot cheaply snapshot the rows it is about to
--- change.
function NS.OnProfileReset()
    prepareProfile()
    NS.Debug("Set", "reset profile '%s' to defaults", currentProfile())
    rebuildProfile()
end

--- OnProfileCopied: profile `source` copied into the active one.
function NS.OnProfileCopied(source)
    prepareProfile()
    NS.Debug("Set", "copied profile '%s' -> '%s'", tostring(source), currentProfile())
    rebuildProfile()
end
