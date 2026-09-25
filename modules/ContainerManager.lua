local _, NS = ...

-- modules/ContainerManager.lua — the container registry and every live container instance.
--
-- THE REGISTRY WRITER (architecture-§5): create, delete and duplicate, with core/Database.lua's
-- NewContainerData minting the id. Only its load pass, Database.PrepareProfile, also writes it.
-- Renaming and copying between containers live here too, as settings writes through the seam
-- (settings/Schema.lua). This file is the only sender of CONTAINERS_CHANGED (architecture-§4).
--
-- APPLYING IS COALESCED AND DEFERRED. A settings change asks for its container to be re-applied
-- (RequestApply); the request is batched to the next frame, so a slider drag or a whole-profile reset
-- applies once. And an apply that would touch aura buttons while auras are secret — or rebuild frames
-- during combat lockdown — waits: FlushPending runs again on PLAYER_REGEN_ENABLED and on
-- ADDON_RESTRICTION_STATE_CHANGED (core/AuraMaster.lua), and the player is told once, naming the
-- cause: combat, or aura information being withheld (an encounter, a key or a match). Only the
-- player's own changes are announced: a request the addon makes for itself (a class-swap re-apply,
-- a learned timed spell, the startup build) waits the same way, silently.
--
-- NOT EVERY WRITE NEEDS AN APPLY. A row may declare `effect`: "visibility" rows (the master enable,
-- visibility, lock and alpha, a container's enable) run the combat-legal visibility pass at once;
-- "none" rows (the Blizzard-frame toggles, a container's name) did their whole effect in their own
-- onChange. A Blizzard-frame toggle that lockdown holds says so through CM.NoteDeferred, same rule.

NS.ContainerManager = NS.ContainerManager or {}
local CM = NS.ContainerManager

local Perf = NS.Perf
local L = NS.L

CM.instances = CM.instances or {}

local pending = {}        -- [id] = true
local pendingAll = false
local scheduled = false
local flushTimer = nil     -- the coalescing timer's handle, so a stand-down can cancel it
local userPending = false -- a pending request is the player's own, so a deferral of it is announced
local shownReason = nil   -- the cause the deferral notice last named: nil, "combat" or "secret"

local function print_(line)
    if NS.Print then NS.Print(line) end
end

--- How many containers exist.
function CM.Count()
    return #NS.Database.GetContainers()
end

-- ---------------------------------------------------------------------------
-- Instances follow the registry
-- ---------------------------------------------------------------------------

-- TEARDOWN WAITS FOR COMBAT TO END. Destroying a container hides its anchor and the engine under it,
-- which must not happen under lockdown. A container that leaves the registry while CM.MustDefer() is
-- true is PARKED instead (disabled, nothing hidden) and kept here until the next FlushPending that
-- may touch frames destroys it. A parked id that comes back first is revived, not rebuilt.
--
-- A DESTROYED INSTANCE IS KEPT, NOT DROPPED. Frames are never freed in WoW, so a destroyed container
-- is kept DORMANT under its id (engine retired, anchor hidden and unpointed), and an id that comes
-- back revives it rather than building a second anchor, engine, blocker, outline, handle and preview
-- pool over a new AuraMasterAnchor<id> global. CreateFrame("Frame", "AuraMasterAnchor"..id) so runs
-- once per id per session, however often the id leaves and returns.
--
-- A PROFILE CHANGE REUSES IDS. A reset reseeds the starters from id 1 and rewinds the id counter, and
-- a switch or copy lands on a profile with its own id 1, so an instance kept (or revived) under its
-- id may be built for a different container than the one now stored there. Under CM.MustDefer()
-- every such instance stays parked — engine disabled, nothing hidden, and ContainerClass:ShouldShow
-- keeps it off through every visibility pass — until the deferred apply rebuilds it for the new data
-- and unparks it. An instance a profile change sends to `retiring` is marked `staleData` too: a
-- reset rewinds the id counter, so a later Create or Duplicate in the same window can hand its id
-- out again. A dormant instance always comes back `staleData`: whatever its id names now, the apply
-- CM.Announce queues rebuilds it for that data, re-places and re-shows its anchor, and unparks it.
local retiring = {}       -- [id] = parked instance
local dormant = {}        -- [id] = destroyed instance, kept for its id's return
-- A profile change CM.Announce skipped while the addon was stood down. The stand-up's CM.Sync reads
-- it as its `profileChanged`, so a stand-up in combat still parks every id the switch reused.
local profileMovedWhileDown = false

--- Put a parked or dormant instance back in the registry. It draws again at once (Park disabled its
--- engine; the apply that re-enables it is itself deferred) unless it must stay parked: `hold` (a
--- profile change under MustDefer) or `staleData` (a profile change parked it, or it was dormant),
--- when the data under its id may be another container's.
local function revive(id, inst, hold)
    retiring[id] = nil
    inst.parked = (hold or inst.staleData) or nil
    CM.instances[id] = inst
    inst:ApplyVisibility()
end

--- Keep, revive (a parked or a dormant one) or build the instance for stored container `id`. `hold`
--- parks a kept one.
local function follow(id, hold)
    local inst = CM.instances[id]
    if inst then
        if hold then inst:Park() end
    elseif retiring[id] then
        revive(id, retiring[id], hold)
    elseif dormant[id] then
        local d = dormant[id]
        dormant[id] = nil
        d.staleData = true
        revive(id, d, hold)
    else
        CM.instances[id] = NS.Container.New(id)
    end
end

--- Make the live instances match the stored registry: build (or revive) one for every new container,
--- and destroy — or, under lockdown, park — the one for every container that is gone.
--- `profileChanged` (the AceDB profile callbacks) also parks every kept id while an apply must wait.
function CM.Sync(profileChanged)
    profileChanged = profileChanged or profileMovedWhileDown
    profileMovedWhileDown = false
    local defer = CM.MustDefer()
    local hold = defer and profileChanged or false
    local wanted = {}
    for _, c in ipairs(NS.Database.GetContainers()) do
        wanted[c.id] = true
        follow(c.id, hold)
    end
    for id, inst in pairs(CM.instances) do
        if not wanted[id] then
            CM.instances[id] = nil
            if defer then
                inst:Park()
                if profileChanged then inst.staleData = true end
                retiring[id] = inst
            else
                inst:Destroy()
                dormant[id] = inst
            end
        end
    end
end

--- Destroy every parked instance and keep it dormant. Only called when frames may be touched.
local function destroyParked()
    for id, inst in pairs(retiring) do
        inst:Destroy()
        retiring[id] = nil
        dormant[id] = inst
    end
end

--- The parked instances, by id (a test seam; production never reads it).
function CM.__retiring() return retiring end

--- The destroyed instances kept for their id's return, by id (a test seam; production never reads it).
function CM.__dormant() return dormant end

--- The registry changed: follow it, re-apply everything, and tell whoever is listening.
--- `profileChanged` is passed by NS.OnProfileChanged (see CM.Sync). A stood-down addon builds
--- nothing: the stand-up's own CM.Sync builds what the registry holds then, and is told of a profile
--- change made meanwhile. The message still goes out, so an open settings panel re-renders its
--- container list.
function CM.Announce(profileChanged)
    if NS.IsStoodDown() then
        profileMovedWhileDown = profileMovedWhileDown or profileChanged or false
    else
        CM.Sync(profileChanged)
        CM.RequestApply()
    end
    NS.bus:SendMessage(NS.MSG.CONTAINERS_CHANGED)
end

-- ---------------------------------------------------------------------------
-- Applying
-- ---------------------------------------------------------------------------

--- Ask for container `id` — or every container, when `id` is nil — to be re-applied. Batched to the
--- next frame. `system` marks a request the addon makes for itself, not for a change the player
--- made: it waits like any other, but its deferral prints no notice (see noteDeferred).
function CM.RequestApply(id, system)
    -- A stood-down addon arms no timer (slash-commands-§7): the coalescing C_Timer is exactly the
    -- shape anti-pattern #85 names -- a repaint that keeps re-arming and then finds nothing to paint.
    -- Nothing is lost by dropping the request, because the stand-up re-applies everything from the
    -- settings as they are then. The stand-up's own call gets through: LibKa0s-Lifecycle-1.0 empties
    -- the hold set BEFORE it calls `standUp`, so the latch is already up by the time this is reached.
    if NS.IsStoodDown() then return end
    if id == nil then
        pendingAll = true
    else
        pending[id] = true
    end
    if not system then userPending = true end
    if not scheduled then
        scheduled = true
        flushTimer = C_Timer.NewTimer(0, function()
            flushTimer = nil
            CM.FlushPending()
        end)
    end
end

--- Whether an apply has to wait: aura buttons are locked while auras are secret, and an aura engine's
--- ancestry must not be rebuilt under combat lockdown.
function CM.MustDefer()
    return NS.Compat.AurasAreSecret() or InCombatLockdown()
end

--- Say ONCE per blocked stretch why a change is waiting — not once per change. The one escalation:
--- a stretch announced as combat that is still held after combat, by secrecy, says so once more.
--- Never on the PLAYER_REGEN_ENABLED edge itself (`edge == "regen"`): the order of that event and
--- ADDON_RESTRICTION_STATE_CHANGED is unverified, and a momentary secret reading there after an
--- ordinary fight must not print a false restriction line. Secret then combat prints nothing more:
--- the restriction wording already covers combat. `quiet` (nothing held is the player's own change)
--- traces the deferral and prints nothing.
local function noteDeferred(edge, quiet)
    local lockdown = InCombatLockdown()
    local reason = lockdown and "combat" or "secret"
    if NS.Debug then
        NS.Debug("Apply", "deferred: secret=%s lockdown=%s edge=%s",
            NS.Compat.AurasAreSecret(), lockdown, edge or "-")
    end
    if quiet then return end
    local escalate = shownReason == "combat" and reason == "secret" and edge ~= "regen"
    if shownReason == nil or escalate then
        shownReason = reason
        print_(reason == "combat" and L["Aura Master settings changes will apply when combat ends."]
            or L["Aura Master settings changes will apply once aura information is available again (after the encounter, key or match)."])
    end
end

--- A settings write outside the apply queue had to wait as well — a Blizzard-frame toggle under
--- lockdown, which BlizzardFrames.Apply catches up on PLAYER_REGEN_ENABLED (core/AuraMaster.lua).
--- Say so under the same once-per-stretch rule, so one fight never prints the line twice.
function CM.NoteDeferred()
    noteDeferred()
end

-- The container being applied, handed to runApply through an upvalue: Lua 5.1's xpcall passes no
-- arguments to the function it calls, and a closure per container would allocate on every pass.
local applying

local function runApply()
    return applying:Apply()
end

--- A container's apply raised. The client's error handler gets it (BugSack shows it) and the pass
--- goes on. A client without one (the headless harness) keeps the FIRST error for FlushPending to
--- raise once the pass has finished, so a failure is never swallowed. Returns the error to keep.
local function reportApplyError(err, first)
    local handler = type(geterrorhandler) == "function" and geterrorhandler()
    if handler then
        handler(err)
        return first
    end
    if first == nil then return err end
    return first
end

--- Apply every container that is pending (or all of them). Each apply is guarded (B-5): one that
--- raises is reported with its stack (Style.WithStack, as Style.Element reports a styler) and never
--- stops the rest of the pass. Returns how many applied cleanly, and an error still to be raised.
local function applyDirty(all, which)
    local applied, failed = 0, nil
    for _, c in ipairs(NS.Database.GetContainers()) do
        local inst = CM.instances[c.id]
        if inst and (all or which[c.id]) then
            applying = inst
            local ok, err = xpcall(runApply, NS.Style.WithStack)
            applying = nil
            if ok then
                applied = applied + 1
            else
                failed = reportApplyError(err, failed)
            end
        end
    end
    return applied, failed
end

--- A rebuilt engine is a NEW frame, so every container attached to one re-anchors to it. Re-placing
--- every container-attached container is cheap and needs no dependency tracking.
local function replaceAttached()
    for _, c in ipairs(NS.Database.GetContainers()) do
        local inst = CM.instances[c.id]
        if inst and c.attach and c.attach.mode == "container" then NS.Anchors.Place(inst) end
    end
end

--- Destroy what was parked, then apply everything pending — unless it has to wait. Returns how many
--- containers were applied. `edge` names the event that asked ("regen" for PLAYER_REGEN_ENABLED);
--- the coalescing timer passes nothing.
function CM.FlushPending(edge)
    -- A flush run directly (the startup build, an event edge) makes the queued one redundant: cancel
    -- it, so `flushTimer` always names the one live coalescing timer, the one a stand-down cancels.
    if flushTimer then
        flushTimer:Cancel()
        flushTimer = nil
    end
    scheduled = false
    -- The latch, not a flag of this file's own: a stood-down addon applies nothing, for either
    -- reason it is down (slash-commands-§7). Stand-up's own RequestApply drains the queue.
    if NS.IsStoodDown() then return 0 end
    local idle = not pendingAll and next(pending) == nil and next(retiring) == nil
    if CM.MustDefer() then
        if not idle then noteDeferred(edge, not userPending) end
        return 0
    end
    -- Nothing is held any longer, even when the queue is empty: a stretch CM.NoteDeferred announced
    -- for a write outside the queue (a Blizzard-frame toggle) ends here too.
    shownReason = nil
    if idle then return 0 end
    destroyParked()

    local t0 = Perf.on and debugprofilestop()
    local all, which = pendingAll, pending
    pending, pendingAll, userPending = {}, false, false
    local applied, failed = applyDirty(all, which)
    replaceAttached()
    if t0 then Perf.Note("applyPass", debugprofilestop() - t0) end
    if NS.Debug then NS.Debug("Apply", "applied %s container(s)", applied) end
    if failed ~= nil then error(failed, 0) end
    return applied
end

--- Re-evaluate every container's show ladder (combat started or ended, a master setting changed).
--- Answers `false` when combat refused part of the pass -- hiding a stood-down container's anchor is
--- hiding an aura engine's ancestry, which lockdown forbids, so core/LifecycleSetup.lua holds that
--- half pending and finishes it on PLAYER_REGEN_ENABLED.
function CM.ApplyVisibility()
    local t0 = Perf.on and debugprofilestop()
    local done = true
    for _, inst in pairs(CM.instances) do
        local _, _, deferred = inst:ApplyVisibility()
        if deferred then done = false end
    end
    if t0 then Perf.Note("visibilityPass", debugprofilestop() - t0) end
    return done
end

--- Whether `unit`'s class differs from the one `inst`'s last apply painted with. Two unresolved
--- classes (an NPC, no such unit) are the same. Read only while an apply may run, as SnapshotClass is.
local function classChanged(inst, unit)
    local snap = inst.classColor
    if not snap then return true end
    local r, g, b = NS.Container.ClassOf(unit)
    return snap.r ~= r or snap.g ~= g or snap.b ~= b
end

--- `unit` now names someone else: every container tracking it refreshes. One that paints a class
--- color also re-applies when the new unit's class differs, so its class snapshot follows the unit
--- (modules/Container.lua's SnapshotClass); a same-class swap costs no apply. The request is the
--- addon's own (`system`), so if combat starts before it flushes it waits with no deferral notice:
--- nothing the player changed is being held. While an apply has to wait the class is not read: the
--- container is marked stale SILENTLY, with no request. ReapplyStaleClass catches up.
function CM.RefreshUnit(unit)
    for _, inst in pairs(CM.instances) do
        local cfg = inst:Cfg()
        if cfg and cfg.unit == unit then
            inst:Refresh()
            if inst.usesClass then
                if CM.MustDefer() then
                    inst.classStale = true
                elseif classChanged(inst, unit) then
                    CM.RequestApply(inst.id, true)
                end
            end
        end
    end
end

--- Re-apply every container whose class snapshot went stale during combat or aura secrecy. Called on
--- the same edges as FlushPending (core/AuraMaster.lua), and a no-op while an apply still has to wait.
function CM.ReapplyStaleClass()
    if CM.MustDefer() then return end
    for id, inst in pairs(CM.instances) do
        if inst.classStale then
            inst.classStale = nil
            CM.RequestApply(id, true)
        end
    end
end

-- ---------------------------------------------------------------------------
-- The registry, write side
-- ---------------------------------------------------------------------------

local function profile() return NS.db and NS.db.profile end

--- A name no other container is using: `base`, or `base (2)`, `base (3)`, … Names that differ
--- only in case count as taken, because `/am select|delete <name>` matches case-insensitively.
function CM.UniqueName(base, exceptId)
    base = (type(base) == "string" and base ~= "") and base or "Container"
    local taken = {}
    for _, c in ipairs(NS.Database.GetContainers()) do
        if c.id ~= exceptId and type(c.name) == "string" then taken[c.name:lower()] = true end
    end
    if not taken[base:lower()] then return base end
    for n = 2, 999 do
        local name = ("%s (%d)"):format(base, n)
        if not taken[name:lower()] then return name end
    end
    return base
end

--- A new container's stored data: the template plus `overrides`, with a unique name. Returns the
--- data and its id. Its Fill is the one its style suits (B5, C.STYLE_FILL_AXIS), as switching the
--- Style row sets it, unless `overrides` carries a Fill of its own: a duplicate does (the source's
--- whole layout), so it keeps the source's.
local function newContainerData(overrides)
    local c, id = NS.Database.NewContainerData(overrides)
    local axis = NS.Constants.STYLE_FILL_AXIS[c.style]
    if axis and not (overrides and overrides.layout and overrides.layout.axis ~= nil) then c.layout.axis = axis end
    c.name = CM.UniqueName(c.name ~= "Container" and c.name or L["Container %d"]:format(id))
    -- Offset a new container from the center by its id, so two new ones are not stacked exactly.
    if not (overrides and overrides.position) then
        c.position.y = -((id - 1) % 8) * 30
    end
    return c, id
end

--- Create a container from the template plus `overrides`. Returns its id, or nil, a message and — for
--- a refusal the caller should print gray — true. Refused under combat lockdown (options-ui-§2): its
--- apply, which places the anchor and builds the engine, waits for combat to end (CM.MustDefer), so
--- it would not draw until then. That covers `/am new`, Containers' New and Duplicate, and
--- any later caller.
function CM.Create(overrides)
    if InCombatLockdown() then
        return nil, L["cannot create a container during combat — it would not be drawn or placed until combat ends"], true
    end
    local p = profile()
    if not p then return nil, L["No profile is loaded."] end
    local c, id = newContainerData(overrides)
    p.containers[id] = c
    p.containerOrder[#p.containerOrder + 1] = id
    NS.Debug("Containers", "created %s '%s'", id, c.name)
    CM.Announce()
    return id
end

--- Delete container `id`. Any container attached to it falls back to the screen.
function CM.Delete(id)
    local p = profile()
    if not (p and p.containers[id]) then return false, L["No such container."] end
    p.containers[id] = nil
    local last = #p.containerOrder
    for i = last, 1, -1 do
        if p.containerOrder[i] == id then table.remove(p.containerOrder, i) end
    end
    for _, c in pairs(p.containers) do
        if c.attach and c.attach.mode == "container" and tonumber(c.attach.container) == id then
            NS.SetByPath("container.attach.mode", "screen", c.id)
        end
    end
    if NS.State and NS.State.activeContainerId == id then NS.State.SetActiveContainer(nil) end
    NS.Debug("Containers", "deleted %s", id)
    CM.Announce()
    return true
end

--- Rename container `id`, through the write seam so the change is logged and announced like any
--- other setting. The name row (settings/Containers.lua) makes the name unique in its normalize and
--- calls CM.NotifyRenamed in its onChange, so a rename typed into the panel or `/am set
--- container.name` lands the same way. The two checks here only give a caller a specific refusal.
--- A test seam: tests/test_containermanager.lua calls it; no production path does.
function CM.Rename(id, name)
    local c = NS.Database.FindContainer(id)
    if not c then return false, L["No such container."] end
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if name == "" then return false, L["A container needs a name."] end
    return NS.SetByPath("container.name", name, id)
end

--- A container's name changed: every picker, handle and name label shows names.
function CM.NotifyRenamed()
    for _, inst in pairs(CM.instances) do
        inst:RefreshLabelText()
        if inst.handle and inst.handle:IsShown() then NS.Anchors.UpdateHandle(inst, true) end
    end
    NS.bus:SendMessage(NS.MSG.CONTAINERS_CHANGED)
end

--- A copy of container `id` with every setting, a fresh id and a new name. Returns the new id.
function CM.Duplicate(id)
    local src = NS.Database.FindContainer(id)
    if not src then return nil, L["No such container."] end
    local overrides = NS.Database.DeepCopy(src)
    overrides.id = nil
    overrides.name = L["%s (copy)"]:format(src.name)
    if overrides.attach and overrides.attach.mode == "screen" then
        overrides.position.x = (tonumber(overrides.position.x) or 0) + 20
        overrides.position.y = (tonumber(overrides.position.y) or 0) - 20
    end
    return CM.Create(overrides)
end

-- What "copy settings from" copies. Identity (name), placement (position, attach) and the registry's
-- own id are never copied: copying a container onto another is about how it looks and what it shows.
CM.COPY_SECTIONS = { "filter", "layout", "behavior", "label", "bars", "icons", "text" }
-- What "everything" copies: what the container IS, then every section. Identity first, because the
-- Style row's onChange resets Fill (B5, settings/Containers.lua): the copied layout lands after that
-- reset, so the copy keeps the source's Fill.
local COPY_ALL = { "unit", "auraType", "style" }
for _, key in ipairs(CM.COPY_SECTIONS) do
    local n = #COPY_ALL
    COPY_ALL[n + 1] = key
end

--- Write each of `keys` from `src` onto container `dstId` through the write seam — all of them or
--- none. Every write is checked first (NS.CheckWrite: the seam's own checks, nothing stored), and
--- nothing is written unless every one passes, so a refusal leaves `dstId` untouched and announces
--- nothing. A checked write cannot then be refused: SetByPath runs those same checks. The writes are
--- one bulk copy, `scope` naming it: one [Set] line counting the rows they changed
--- (debug-logging-§10). A refused copy logs nothing. Returns ok, err.
local function copyThrough(src, dstId, keys, scope)
    for _, key in ipairs(keys) do
        if src[key] ~= nil then
            local ok, err = NS.CheckWrite("container." .. key, src[key], dstId)
            if not ok then return false, err end
        end
    end
    NS.Bulk.Run("copy", scope, function()
        for _, key in ipairs(keys) do
            if src[key] ~= nil then
                NS.SetByPath("container." .. key, NS.Database.DeepCopy(src[key]), dstId)
            end
        end
    end)
    return true
end

--- Copy `section` (or every copyable section, and what the container is, when nil) from container
--- `srcId` onto `dstId`. Settings writes, not a registry change: each lands through the write seam,
--- which validates it and announces it, so nothing here sends CONTAINERS_CHANGED. All or nothing:
--- returns ok, err — false, with nothing copied, when the seam would refuse any one of the writes
--- (a source is stored data, so that means corrupt data).
function CM.CopyFrom(srcId, dstId, section)
    local src, dst = NS.Database.FindContainer(srcId), NS.Database.FindContainer(dstId)
    if not (src and dst) then return false, L["No such container."] end
    if srcId == dstId then return false, L["A container cannot copy itself."] end
    local scope = ("container %s->%s (%s)"):format(srcId, dstId, section or "all")
    local ok, err = copyThrough(src, dstId, section and { section } or COPY_ALL, scope)
    if not ok then return false, err end
    return true
end

--- Put every container back at its default screen position, staggered so they do not overlap. The
--- Master controls tab's Reset position and `/am resetposition` both land here. Each position is one
--- whole-section write through the seam; the applies those writes queue coalesce into one pass. The
--- whole act is one bulk reset: one `[Set] reset positions: N rows` line (debug-logging-§10).
function CM.ResetPositions()
    local template = NS.CONTAINER_TEMPLATE.position
    NS.Bulk.Run("reset", "positions", function()
        for i, c in ipairs(NS.Database.GetContainers()) do
            local pos = NS.Database.DeepCopy(template)
            pos.y = -(i - 1) * 30
            NS.SetByPath("container.position", pos, c.id)
            if c.attach and c.attach.mode ~= "screen" then
                NS.SetByPath("container.attach.mode", "screen", c.id)
            end
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Startup
-- ---------------------------------------------------------------------------

local ev

--- A write that moves a container's flow or its attachment moves every container following it too
--- (L-6): they continue its flow and anchor at points derived from it, so each is re-applied.
local function requestFollowers(p)
    if not (p.containerId and NS.Anchors.MovesFollowers(p.path)) then return end
    for _, id in ipairs(NS.Anchors.Followers(p.containerId)) do CM.RequestApply(id) end
end

--- Subscribe to the bus. Separate from CM.Init because the stand-down UNREGISTERS these three
--- (slash-commands-§7) and the stand-up has to put them back -- a handler left registered and gated
--- on a flag is the draw gate the section exists to end (anti-pattern #85).
function CM.StartListening()
    if not ev then
        ev = NS.NewBusTarget()
        -- A setting changed: run what its row's `effect` says — the visibility pass, nothing, or (the
        -- default) re-apply the container it belongs to, or all of them for an addon-wide row.
        ev:RegisterMessage(NS.MSG.CONFIG_CHANGED, function(_, payload)
            local p = type(payload) == "table" and payload or {}
            local row = p.path and NS.FindSchemaRow(p.path)
            local effect = row and row.effect
            if effect == "visibility" then CM.ApplyVisibility()
            elseif effect ~= "none" then
                CM.RequestApply(p.containerId)
                requestFollowers(p)
            end
        end)
        ev:RegisterMessage(NS.MSG.VISIBILITY_CHANGED, function() CM.ApplyVisibility() end)
        -- The learned timed-spell set changed: every container's excluded ids may have moved. A
        -- scan's news is the addon's own request; `/am forgettimed` marks its payload `byPlayer`.
        ev:RegisterMessage(NS.MSG.TIMED_SPELLS_CHANGED, function(_, payload)
            CM.RequestApply(nil, not (type(payload) == "table" and payload.byPlayer))
        end)
    end
end

--- Drop every subscription this file owns, the queue behind them, and the coalescing timer that would
--- have flushed it: canceled, not left armed to wake up and find the latch (slash-commands-§7).
--- `scheduled` goes down with it, or the stand-up's own RequestApply(nil, true) would be swallowed.
--- What was pending is not kept: the stand-up rebuilds from the settings AS THEY ARE THEN, never
--- from a snapshot taken on the way down (performance-§6).
function CM.StopListening()
    if ev then
        ev:UnregisterAllMessages()
        ev = nil
    end
    if flushTimer then
        flushTimer:Cancel()
        flushTimer = nil
    end
    scheduled = false
    pending, pendingAll, userPending = {}, false, false
end

--- Whether this file is subscribed (a test seam).
function CM.__listening() return ev ~= nil end

--- Build every container and start listening. Called once from core/AuraMaster.lua's OnEnable; it
--- builds and subscribes only when the addon is actually running. A stood-down addon subscribes to
--- nothing and builds no frame: the stand-up (core/LifecycleSetup.lua) syncs the registry then.
function CM.Init()
    if not NS.Compat.EnsureAuraContainer() then
        print_(L["This client has no aura container API (Retail 12.1 or later is required); containers will not be drawn."])
    end
    if NS.IsStoodDown() then
        if NS.TimedSpells and NS.TimedSpells.Sync then NS.TimedSpells.Sync() end
        return
    end
    CM.StartListening()
    CM.Sync()
    CM.RequestApply(nil, true)   -- the startup build: a reload in combat changed no setting
    CM.FlushPending()
    if NS.TimedSpells and NS.TimedSpells.Sync then NS.TimedSpells.Sync() end
end
