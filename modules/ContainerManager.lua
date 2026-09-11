local _, NS = ...

-- modules/ContainerManager.lua — the container registry and every live container instance.
--
-- ONE WRITER. Creating, deleting, renaming, duplicating and copying between containers all happen
-- here, and this file is the only sender of CONTAINERS_CHANGED (architecture-§4). The stored data
-- itself is core/Database.lua's; the per-container settings go through the single write seam
-- (settings/Schema.lua) like every other setting.
--
-- APPLYING IS COALESCED AND DEFERRED. A settings change asks for its container to be re-applied
-- (RequestApply); the request is batched to the next frame, so a slider drag or a whole-profile reset
-- applies once. And an apply that would touch aura buttons while auras are secret — or rebuild frames
-- during combat lockdown — waits: FlushPending runs again on PLAYER_REGEN_ENABLED and on
-- ADDON_RESTRICTION_STATE_CHANGED (core/AuraMaster.lua), and the player is told once, naming the
-- cause: combat, or aura information being withheld (an encounter, a key or a match).
--
-- NOT EVERY WRITE NEEDS AN APPLY. A row may declare `effect`: "visibility" rows (the master enable,
-- visibility, lock and alpha) run the combat-legal visibility pass at once, and "none" rows (the
-- Blizzard-frame toggles, a container's name) did their whole effect in their own onChange.

NS.ContainerManager = NS.ContainerManager or {}
local CM = NS.ContainerManager

local Perf = NS.Perf
local L = NS.L

CM.instances = CM.instances or {}

local pending = {}        -- [id] = true
local pendingAll = false
local scheduled = false
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
-- may touch frames destroys it. A parked id that comes back first is revived, not rebuilt: a second
-- AuraMasterAnchor<id> global would be a second frame for the same container.
local retiring = {}       -- [id] = parked instance

--- Put a parked instance back in the registry and let it draw again at once: Park disabled its
--- engine, and the apply that re-enables it is itself deferred until combat ends.
local function revive(id, inst)
    retiring[id] = nil
    inst.parked = nil
    CM.instances[id] = inst
    inst:ApplyVisibility()
end

--- Make the live instances match the stored registry: build (or revive) one for every new container,
--- and destroy — or, under lockdown, park — the one for every container that is gone.
function CM.Sync()
    local defer = CM.MustDefer()
    local wanted = {}
    for _, c in ipairs(NS.Database.GetContainers()) do
        local id = c.id
        wanted[id] = true
        if not CM.instances[id] then
            local parked = retiring[id]
            if parked then
                revive(id, parked)
            else
                CM.instances[id] = NS.Container.New(id)
            end
        end
    end
    for id, inst in pairs(CM.instances) do
        if not wanted[id] then
            CM.instances[id] = nil
            if defer then
                inst:Park()
                retiring[id] = inst
            else
                inst:Destroy()
            end
        end
    end
end

--- Destroy every parked instance. Only called when frames may be touched.
local function destroyParked()
    for id, inst in pairs(retiring) do
        inst:Destroy()
        retiring[id] = nil
    end
end

--- The parked instances, by id (a test seam; production never reads it).
function CM.__retiring() return retiring end

--- The registry changed: follow it, re-apply everything, and tell whoever is listening.
function CM.Announce()
    CM.Sync()
    CM.RequestApply()
    NS.bus:SendMessage(NS.MSG.CONTAINERS_CHANGED)
end

-- ---------------------------------------------------------------------------
-- Applying
-- ---------------------------------------------------------------------------

--- Ask for container `id` — or every container, when `id` is nil — to be re-applied. Batched to the
--- next frame.
function CM.RequestApply(id)
    if id == nil then
        pendingAll = true
    else
        pending[id] = true
    end
    if not scheduled then
        scheduled = true
        C_Timer.After(0, CM.FlushPending)
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
--- the restriction wording already covers combat.
local function noteDeferred(edge)
    local lockdown = InCombatLockdown()
    local reason = lockdown and "combat" or "secret"
    if NS.Debug then
        NS.Debug("Apply", "deferred: secret=%s lockdown=%s edge=%s",
            NS.Compat.AurasAreSecret(), lockdown, edge or "-")
    end
    local escalate = shownReason == "combat" and reason == "secret" and edge ~= "regen"
    if shownReason == nil or escalate then
        shownReason = reason
        print_(reason == "combat" and L["Aura Master settings changes will apply when combat ends."]
            or L["Aura Master settings changes will apply once aura information is available again (after the encounter, key or match)."])
    end
end

--- Apply every container that is pending (or all of them). Returns how many were applied.
local function applyDirty(all, which)
    local applied = 0
    for _, c in ipairs(NS.Database.GetContainers()) do
        local inst = CM.instances[c.id]
        if inst and (all or which[c.id]) then
            inst:Apply()
            applied = applied + 1
        end
    end
    return applied
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
    scheduled = false
    if Perf.suspended then return 0 end   -- performance-§6: held; resume's RequestApply drains it
    if not pendingAll and next(pending) == nil and next(retiring) == nil then return 0 end
    if CM.MustDefer() then
        noteDeferred(edge)
        return 0
    end
    shownReason = nil
    destroyParked()

    local t0 = Perf.on and debugprofilestop()
    local all, which = pendingAll, pending
    pending, pendingAll = {}, false
    local applied = applyDirty(all, which)
    replaceAttached()
    if t0 then Perf.Note("applyPass", debugprofilestop() - t0) end
    if NS.Debug then NS.Debug("Apply", "applied %s container(s)", applied) end
    return applied
end

--- Re-evaluate every container's show ladder (combat started or ended, a master setting changed).
function CM.ApplyVisibility()
    local t0 = Perf.on and debugprofilestop()
    for _, inst in pairs(CM.instances) do inst:ApplyVisibility() end
    if t0 then Perf.Note("visibilityPass", debugprofilestop() - t0) end
end

--- `unit` now names someone else: every container tracking it refreshes.
function CM.RefreshUnit(unit)
    for _, inst in pairs(CM.instances) do
        local cfg = inst:Cfg()
        if cfg and cfg.unit == unit then inst:Refresh() end
    end
end

--- Turn preview mode on or off (preview-mode). Session-only.
function CM.SetPreview(on)
    if NS.State then NS.State.preview = on and true or false end
    CM.ApplyVisibility()
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
--- data and its id.
local function newContainerData(overrides)
    local c, id = NS.Database.NewContainerData(overrides)
    c.name = CM.UniqueName(c.name ~= "Container" and c.name or L["Container %d"]:format(id))
    -- Offset a new container from the center by its id, so two new ones are not stacked exactly.
    if not (overrides and overrides.position) then
        c.position.y = -((id - 1) % 8) * 30
    end
    return c, id
end

--- Create a container from the template plus `overrides`. Returns its id, or nil, a message and — for
--- a refusal the caller should print gray — true. Refused under combat lockdown: a new container
--- creates its anchor frame, which options-ui-§2 keeps out of combat. That covers `/am new`, the
--- Containers page's New and Duplicate, and any later caller.
function CM.Create(overrides)
    if InCombatLockdown() then
        return nil, L["cannot create a container during combat — a new display cannot be built until combat ends"], true
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
    for i = #p.containerOrder, 1, -1 do
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
function CM.Rename(id, name)
    local c = NS.Database.FindContainer(id)
    if not c then return false, L["No such container."] end
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if name == "" then return false, L["A container needs a name."] end
    return NS.SetByPath("container.name", name, id)
end

--- A container's name changed: every picker and handle lists names.
function CM.NotifyRenamed()
    for _, inst in pairs(CM.instances) do
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
CM.COPY_SECTIONS = { "filter", "layout", "behavior", "bars", "icons" }
-- What "everything" copies: every section, then what the container IS.
local COPY_ALL = { "unit", "auraType", "style" }
for i = #CM.COPY_SECTIONS, 1, -1 do table.insert(COPY_ALL, 1, CM.COPY_SECTIONS[i]) end

--- Write each of `keys` from `src` onto container `dstId` through the write seam, stopping at the
--- first write it rejects. Returns ok, err.
local function copyThrough(src, dstId, keys)
    for _, key in ipairs(keys) do
        if src[key] ~= nil then
            local ok, err = NS.SetByPath("container." .. key, NS.Database.DeepCopy(src[key]), dstId)
            if not ok then return false, err end
        end
    end
    return true
end

--- Copy `section` (or every copyable section, and what the container is, when nil) from container
--- `srcId` onto `dstId`. Settings writes, not a registry change: each lands through the write seam,
--- which validates it and announces it, so nothing here sends CONTAINERS_CHANGED. Returns ok, err —
--- false on the first write the seam rejects (a source is stored data, so that means corrupt data).
function CM.CopyFrom(srcId, dstId, section)
    local src, dst = NS.Database.FindContainer(srcId), NS.Database.FindContainer(dstId)
    if not (src and dst) then return false, L["No such container."] end
    if srcId == dstId then return false, L["A container cannot copy itself."] end
    local ok, err = copyThrough(src, dstId, section and { section } or COPY_ALL)
    if not ok then return false, err end
    NS.Debug("Containers", "copied %s from %s to %s", section or "all", srcId, dstId)
    return true
end

--- Put every container back at its default screen position, staggered so they do not overlap. The
--- Master controls tab's Reset position and `/am resetposition` both land here. Each position is one
--- whole-section write through the seam; the applies those writes queue coalesce into one pass.
function CM.ResetPositions()
    local template = NS.CONTAINER_TEMPLATE.position
    local containers = NS.Database.GetContainers()
    for i, c in ipairs(containers) do
        local pos = NS.Database.DeepCopy(template)
        pos.y = -(i - 1) * 30
        NS.SetByPath("container.position", pos, c.id)
        if c.attach and c.attach.mode ~= "screen" then
            NS.SetByPath("container.attach.mode", "screen", c.id)
        end
    end
    NS.Debug("Containers", "reset %s position(s)", #containers)
end

-- ---------------------------------------------------------------------------
-- Startup
-- ---------------------------------------------------------------------------

local ev

--- Build every container and start listening. Called once from core/AuraMaster.lua's OnEnable.
function CM.Init()
    if not NS.Compat.EnsureAuraContainer() then
        print_(L["This client has no aura container API (Retail 12.1 or later is required); containers will not be drawn."])
    end
    if not ev then
        ev = NS.NewBusTarget()
        -- A setting changed: run what its row's `effect` says — the visibility pass, nothing, or (the
        -- default) re-apply the container it belongs to, or all of them for an addon-wide row.
        ev:RegisterMessage(NS.MSG.CONFIG_CHANGED, function(_, payload)
            local p = type(payload) == "table" and payload or {}
            local row = p.path and NS.FindSchemaRow(p.path)
            local effect = row and row.effect
            if effect == "visibility" then CM.ApplyVisibility()
            elseif effect ~= "none" then CM.RequestApply(p.containerId) end
        end)
        ev:RegisterMessage(NS.MSG.VISIBILITY_CHANGED, function() CM.ApplyVisibility() end)
    end
    CM.Sync()
    CM.RequestApply()
    CM.FlushPending()
    if NS.TimedSpells and NS.TimedSpells.Sync then NS.TimedSpells.Sync() end
end
