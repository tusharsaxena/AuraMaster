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
-- ADDON_RESTRICTION_STATE_CHANGED (core/AuraMaster.lua), and the player is told once that their
-- change will land after combat.

NS.ContainerManager = NS.ContainerManager or {}
local CM = NS.ContainerManager

local Perf = NS.Perf
local L = NS.L

CM.instances = CM.instances or {}

local pending = {}        -- [id] = true
local pendingAll = false
local scheduled = false
local deferNoticeShown = false

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

--- Make the live instances match the stored registry: build one for every new container, destroy the
--- one for every container that is gone.
function CM.Sync()
    local wanted = {}
    for _, c in ipairs(NS.Database.GetContainers()) do
        wanted[c.id] = true
        if not CM.instances[c.id] then CM.instances[c.id] = NS.Container.New(c.id) end
    end
    for id, inst in pairs(CM.instances) do
        if not wanted[id] then
            inst:Destroy()
            CM.instances[id] = nil
        end
    end
end

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

--- Say ONCE per blocked stretch that a change will land after combat — not once per change.
local function noteDeferred()
    if deferNoticeShown then return end
    deferNoticeShown = true
    print_(NS.L["Aura Master settings changes will apply when combat ends."])
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

--- Apply everything pending, unless it has to wait. Returns how many containers were applied.
function CM.FlushPending()
    scheduled = false
    if not pendingAll and next(pending) == nil then return 0 end
    if CM.MustDefer() then
        noteDeferred()
        return 0
    end
    deferNoticeShown = false

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

--- A name no other container is using: `base`, or `base (2)`, `base (3)`, …
function CM.UniqueName(base, exceptId)
    base = (type(base) == "string" and base ~= "") and base or "Container"
    local taken = {}
    for _, c in ipairs(NS.Database.GetContainers()) do
        if c.id ~= exceptId then taken[c.name] = true end
    end
    if not taken[base] then return base end
    for n = 2, 999 do
        local name = ("%s (%d)"):format(base, n)
        if not taken[name] then return name end
    end
    return base
end

--- Create a container from the template plus `overrides`. Returns its id.
function CM.Create(overrides)
    local p = profile()
    if not p then return nil, L["No profile is loaded."] end
    local c, id = NS.Database.NewContainerData(overrides)
    c.name = CM.UniqueName(c.name ~= "Container" and c.name or ("Container " .. id))
    -- Offset a new container from the center by its id, so two new ones are not stacked exactly.
    if not (overrides and overrides.position) then
        c.position.y = -((id - 1) % 8) * 30
    end
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
            c.attach.mode = "screen"
        end
    end
    if NS.State and NS.State.activeContainerId == id then NS.State.SetActiveContainer(nil) end
    NS.Debug("Containers", "deleted %s", id)
    CM.Announce()
    return true
end

--- Rename container `id`, through the write seam so the change is logged and announced like any
--- other setting. The name row's onChange (settings/Containers.lua) calls CM.NotifyRenamed, so a
--- rename typed into the panel or `/am set container.name` announces the same way.
function CM.Rename(id, name)
    local c = NS.Database.FindContainer(id)
    if not c then return false, L["No such container."] end
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if name == "" then return false, L["A container needs a name."] end
    return NS.SetByPath("container.name", CM.UniqueName(name, id), id)
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
    overrides.name = src.name .. " (copy)"
    if overrides.attach and overrides.attach.mode == "screen" then
        overrides.position.x = (tonumber(overrides.position.x) or 0) + 20
        overrides.position.y = (tonumber(overrides.position.y) or 0) - 20
    end
    return CM.Create(overrides)
end

-- What "copy settings from" copies. Identity (name), placement (position, attach) and the registry's
-- own id are never copied: copying a container onto another is about how it looks and what it shows.
CM.COPY_SECTIONS = { "filter", "layout", "behavior", "bars", "icons" }

--- Copy `section` (or every copyable section when nil) from container `srcId` onto `dstId`.
function CM.CopyFrom(srcId, dstId, section)
    local src, dst = NS.Database.FindContainer(srcId), NS.Database.FindContainer(dstId)
    if not (src and dst) then return false, L["No such container."] end
    if srcId == dstId then return false, L["A container cannot copy itself."] end
    local sections = section and { section } or CM.COPY_SECTIONS
    for _, key in ipairs(sections) do
        if src[key] ~= nil then dst[key] = NS.Database.DeepCopy(src[key]) end
    end
    if not section then
        dst.unit, dst.auraType, dst.style = src.unit, src.auraType, src.style
    end
    NS.Debug("Containers", "copied %s from %s to %s", section or "all", srcId, dstId)
    -- A wholesale replacement, not a setting: CONFIG_CHANGED has one sender (the write seam), so
    -- this applies its own container and announces on the registry's message.
    CM.RequestApply(dstId)
    NS.bus:SendMessage(NS.MSG.CONTAINERS_CHANGED)
    return true
end

--- Put every container back at its default screen position, staggered so they do not overlap. The
--- Master controls tab's Reset position and `/am resetposition` both land here.
function CM.ResetPositions()
    local template = NS.CONTAINER_TEMPLATE.position
    for i, c in ipairs(NS.Database.GetContainers()) do
        c.position = NS.Database.DeepCopy(template)
        c.position.y = -(i - 1) * 30
        if c.attach then c.attach.mode = "screen" end
    end
    CM.RequestApply()
    NS.bus:SendMessage(NS.MSG.CONTAINERS_CHANGED)
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
        -- A setting changed: re-apply the container it belongs to, or all of them for an addon-wide row.
        ev:RegisterMessage(NS.MSG.CONFIG_CHANGED, function(_, payload)
            local id = type(payload) == "table" and payload.containerId or nil
            CM.RequestApply(id)
        end)
        ev:RegisterMessage(NS.MSG.VISIBILITY_CHANGED, function() CM.ApplyVisibility() end)
    end
    CM.Sync()
    CM.RequestApply()
    CM.FlushPending()
    if NS.TimedSpells and NS.TimedSpells.Sync then NS.TimedSpells.Sync() end
end
