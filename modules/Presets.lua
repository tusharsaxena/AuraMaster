local _, NS = ...

-- modules/Presets.lua -- applying a container preset (spec
-- docs/superpowers/specs/2026-11-14-auramaster-presets-design.md, sections 3 and 5).
--
-- ONE WRITER, AND IT WRITES NOTHING ITSELF (architecture-§5). defaults/Presets.lua's pure builder says
-- what a preset creates; this file turns that into registry writes through the registry's own
-- writers: NS.ContainerManager.Create and Delete for the containers, NS.Categories.CreateUserCategory
-- for Advanced's two custom categories. It never assigns into the profile's containers, its order, its
-- id counter or its custom categories (tests/test_presets_apply.lua holds it to that).
--
-- REPLACE AND ADD. Replace deletes every container, then creates the preset's; Add creates them after
-- the player's own, ContainerManager.Create giving a name already in use a " (2)" suffix. A stack
-- member attaches to the id Create returned for the container above it, so Add over a profile that
-- already holds those names still chains to the new containers. Empty in Replace deletes every
-- container; Empty in Add is refused (it would add nothing).
--
-- CUSTOM CATEGORIES ARE REUSED. The builder states Advanced's two custom categories under the
-- placeholder keys SPECIAL_PLAYER and SPECIAL_TARGET; ResolveCustom maps each to a custom category of
-- the same name and aura type the profile already has, or creates it, and the writer stores the real
-- key. Re-applying Advanced keeps the categories and the spell lists the player filled. The builder is
-- handed the keys chosen, so a second category of the same name is hidden like any other custom one
-- in a container that shows only some categories.
--
-- Refused in combat before anything is written: a Replace that deleted first and then met Create's own
-- refusal would leave the profile half-changed. Peers are reached at call time.

NS.Presets = NS.Presets or {}
local Presets = NS.Presets

local L = NS.L

local MODES = { replace = true, add = true }

local function debug(fmt, ...)
    if NS.Debug then NS.Debug("Presets", fmt, ...) end
end

--- Whether `name` is a preset and `look` one of its styles.
local function known(name, look)
    local Data = NS.PresetData
    local isName, isLook = false, false
    for _, n in ipairs(Data.NAMES) do isName = isName or n == name end
    for _, l in ipairs(Data.LOOKS) do isLook = isLook or l == look end
    return isName and isLook
end

--- Why `name`, `look`, `mode` cannot be applied now, or nil when they can. The message is a
--- player-facing line; `gray` marks a refusal the caller prints gray (ContainerManager.Create's shape).
--- @return string|nil message, boolean|nil gray
local function refusal(name, look, mode)
    if InCombatLockdown() then
        debug("apply %s refused (in combat)", tostring(name))
        return L["cannot apply a preset during combat — its containers would not be drawn or placed until combat ends"], true
    end
    if not (NS.db and NS.db.profile) then return L["No profile is loaded."] end
    if not known(name, look) then return L["No such preset."] end
    if not MODES[mode] then return L["A preset either replaces your containers or adds to them."] end
    if name == "empty" and mode == "add" then return L["The Empty preset has no containers to add."] end
    return nil
end

--- The key of the custom category placeholder `customKey` (NS.PresetData.CUSTOM) stands for: a custom
--- category of the same name (any case) and aura type the profile already has, used as is with its
--- spell list, or else one created through the custom-category writer. Nil for a key that is not a
--- placeholder, or when the writer refuses (then with its reason).
--- @param customKey string
--- @return string|nil key, string|nil reason
function Presets.ResolveCustom(customKey)
    local Data = NS.PresetData
    local spec = Data.CUSTOM[customKey]
    if not spec then return nil end
    for _, def in ipairs(NS.Categories.For(spec.auraType)) do
        if def.userCategory and Data.CustomKeyOf(def) == customKey then
            debug("%s reuses custom category '%s'", customKey, def.key)
            return def.key
        end
    end
    local key, reason = NS.Categories.CreateUserCategory(L[spec.nameKey], spec.auraType)
    if key then debug("%s created custom category '%s'", customKey, key) end
    return key, reason
end

--- Every placeholder preset `name` names, resolved: [placeholder] = key. Nil and a reason when one
--- cannot be.
local function resolveAll(name)
    local keys = {}
    if not NS.PresetData.CreatesCustom(name) then return keys end
    local order = {}
    for customKey in pairs(NS.PresetData.CUSTOM) do order[#order + 1] = customKey end
    table.sort(order)   -- SPECIAL_PLAYER, then SPECIAL_TARGET: created in a stable order
    for _, customKey in ipairs(order) do
        local key, reason = Presets.ResolveCustom(customKey)
        if not key then return nil, reason or L["No profile is loaded."] end
        keys[customKey] = key
    end
    return keys
end

--- Delete every container through the registry writer, the last created first, so a stack's members
--- go before the container they attach to. Answers how many it deleted.
local function deleteAll()
    local ids = {}
    for _, c in ipairs(NS.Database.GetContainers()) do ids[#ids + 1] = c.id end
    for i = #ids, 1, -1 do NS.ContainerManager.Delete(ids[i]) end
    return #ids
end

--- Store each placeholder state in `categories` under the key it resolved to.
local function rekey(categories, keys)
    for customKey, key in pairs(keys) do
        local state = categories[customKey]
        if state ~= nil then
            categories[customKey] = nil
            categories[key] = state
        end
    end
end

--- The parent's size, as the builder reads it: nil when UIParent cannot be read.
local function parentSize()
    local parent = _G.UIParent
    if not (parent and parent.GetWidth and parent.GetHeight) then return nil, nil end
    return parent:GetWidth(), parent:GetHeight()
end

--- Create every spec in order. A member's attach names the id Create returned for the spec above it.
--- @return number|nil created, string|nil message
local function createAll(specs, keys)
    local ids = {}
    for i, spec in ipairs(specs) do
        local o = spec.overrides
        rekey(o.filter.categories, keys)
        if spec.attachTo then o.attach.container = ids[spec.attachTo] end
        local id, msg = NS.ContainerManager.Create(o)
        if not id then return nil, msg end
        ids[i] = id
    end
    return #ids
end

--- Apply preset `name` in style `look`: `mode` "replace" deletes every container first, "add" keeps
--- them. Returns true, or nil, a player-facing message and (for the combat refusal) true, the gray
--- flag ContainerManager.Create answers with. A refusal changes nothing.
--- @param name string  one of NS.PresetData.NAMES
--- @param look string  "bars" | "icons"
--- @param mode string  "replace" | "add"
--- @return boolean|nil ok, string|nil message, boolean|nil gray
function Presets.Apply(name, look, mode)
    local why, gray = refusal(name, look, mode)
    if why then return nil, why, gray end
    local keys, reason = resolveAll(name)
    if not keys then return nil, reason end
    local deleted = (mode == "replace") and deleteAll() or 0
    local w, h = parentSize()
    local specs = NS.PresetData.Build(name, look, w, h, keys)
    local created, msg = createAll(specs, keys)
    if not created then return nil, msg end
    debug("applied %s (%s, %s): %d deleted, %d created", name, look, mode, deleted, created)
    return true
end

-- ---------------------------------------------------------------------------
-- Preview on the real screen (spec section 6)
-- ---------------------------------------------------------------------------
--
-- WRITE AND SNAPSHOT. A preview is a Replace written into the profile, with test mode on so every
-- container fills with sample auras. Before the first one the registry and the custom categories are
-- snapshotted (ContainerManager.Snapshot) into the profile's own `presets.previewSnapshot`, so a
-- /reload, a disconnect or a crash mid-preview still gives the player their containers back: the next
-- login restores every snapshot it finds before the migration ladder runs, so a snapshot left in a
-- profile nobody is logged into is migrated with its profile. Picking again swaps the preset and keeps
-- the first snapshot, restoring it before the new preset is written, so each preview starts from the
-- player's own containers and categories and a kept one carries nothing of the last. Ending it unkept restores the snapshot exactly, ids included, through the
-- registry's own restore writer; keeping it in Replace drops the snapshot, and keeping it in Add
-- restores the snapshot and then adds the preset on top.
--
-- EVERY OTHER END RESTORES. A profile switch restores the profile just left, by the table the
-- preview was taken in, before anything rebuilds for the new one, so the snapshot never lands in the
-- new profile; a profile arrived at with a snapshot in it was interrupted and is restored too. Combat ends a preview by restoring: the
-- PLAYER_REGEN_DISABLED edge comes before lockdown, so the restore is applied in that handler; when
-- an apply would have to wait anyway (lockdown already up, auras secret) it is held to
-- PLAYER_REGEN_ENABLED, with test mode off at once either way.

-- The preset on the screen in this session: { name, look, profile }, for an Add that keeps it and a
-- profile event that must restore the profile it was taken in. Nil when no preview is up; a snapshot
-- from an earlier session is restored at login, so the two agree.
local onScreen = nil
-- A preview combat started that could not be restored under lockdown: restored at combat's end.
local heldForCombat = false

--- The profile's `presets` table, this module's own key (spec section 9). defaults/Profile.lua gives
--- it `pickerSeen` and no `previewSnapshot` (present only while a preview is up); the table is made
--- here as well, so a profile AceDB has not backfilled yet still has somewhere to keep a snapshot.
local function profilePresets()
    local p = NS.db and NS.db.profile
    if not p then return nil end
    if type(p.presets) ~= "table" then p.presets = {} end
    return p.presets
end

local function stopTestMode(why)
    if NS.State and NS.State.testMode then NS.Preview.SetTestMode(false, why) end
end

--- Restore `store`'s snapshot into profile `p` and forget it. `quiet` as ContainerManager.RestoreSnapshot.
local function restoreInto(p, store, quiet)
    NS.ContainerManager.RestoreSnapshot(store.previewSnapshot, p, quiet)
    store.previewSnapshot = nil
end

--- Whether a preset is being previewed: the active profile holds a snapshot.
--- @return boolean
function Presets.IsPreviewing()
    local store = NS.db and NS.db.profile and NS.db.profile.presets
    return type(store) == "table" and store.previewSnapshot ~= nil
end

--- Show preset `name` in style `look` on the real screen, in test mode, snapshotting the player's own
--- containers first. A second call restores that snapshot, keeps it, and writes the new preset. Refused, with
--- nothing changed, on the same grounds as Apply; a preset that fails part-way is undone by restoring.
--- @return boolean|nil ok, string|nil message, boolean|nil gray
function Presets.BeginPreview(name, look)
    local why, gray = refusal(name, look, "replace")
    if why then return nil, why, gray end
    local store = profilePresets()
    if store.previewSnapshot == nil then
        store.previewSnapshot = NS.ContainerManager.Snapshot()
    else
        -- A swap starts from the player's own state, so a kept preset carries none of the previous
        -- preview's custom categories. The snapshot is restored by copy and stays stored.
        NS.ContainerManager.RestoreSnapshot(store.previewSnapshot, NS.db.profile)
    end
    local ok, msg, mgray = Presets.Apply(name, look, "replace")
    if not ok then
        restoreInto(NS.db.profile, store)
        onScreen = nil
        stopTestMode("preset preview failed")
        return nil, msg, mgray
    end
    onScreen = { name = name, look = look, profile = NS.db.profile }
    NS.Preview.SetTestMode(true, "preset preview")
    debug("previewing %s (%s)", name, look)
    return true
end

--- End the preview. `keep` with `mode` "replace" keeps the preset as previewed; with "add" the
--- player's containers come back and the preset is added after them; not `keep` restores. Every
--- branch turns test mode off and clears the snapshot. Refused in combat (the restore and the add
--- rebuild frames), and with nothing previewed.
--- @return boolean|nil ok, string|nil message, boolean|nil gray
function Presets.EndPreview(keep, mode)
    if not Presets.IsPreviewing() then return nil, L["No preset is being previewed."] end
    if InCombatLockdown() then
        debug("end preview refused (in combat)")
        return nil, L["cannot end a preset preview during combat — your containers would not be rebuilt until combat ends"], true
    end
    if keep and not MODES[mode] then return nil, L["A preset either replaces your containers or adds to them."] end
    local shown, store = onScreen, profilePresets()
    if keep and mode == "add" and not shown then return nil, L["No preset is being previewed."] end
    if keep and mode == "replace" then store.previewSnapshot = nil else restoreInto(NS.db.profile, store) end
    onScreen, heldForCombat = nil, false
    stopTestMode("preset preview ended")
    debug("preview ended (%s)", keep and mode or "restored")
    if keep and mode == "add" then return Presets.Apply(shown.name, shown.look, "add") end
    return true
end

--- Login: restore every snapshot a profile still holds, a preview a /reload or a crash interrupted.
--- Called by NS.RunMigrations before the ladder (core/Database.lua), so a snapshot taken under an
--- older schema is migrated with its profile, and before any container is built. Quiet: the sync
--- and the prepare that follow the ladder materialize and backfill what came back.
function Presets.RestoreStaleSnapshots()
    if not NS.db then return end
    NS.Database.EachProfile(NS.db, function(p, profileName)
        if type(p.presets) == "table" and p.presets.previewSnapshot ~= nil then
            restoreInto(p, p.presets, true)
            debug("restored the preview snapshot left in profile '%s'", tostring(profileName))
        end
    end)
end

--- A profile event (a switch, a copy or a reset), before anything rebuilds for the profile now
--- active. A preview this session showed is restored into the profile it was taken in: after a
--- switch that is the profile just left (AceDB keeps its table), so the snapshot never lands in the
--- new one; after a reset or a copy the snapshot went with the old contents and there is nothing to
--- put back. Then a snapshot the active profile arrived holding (a preview another session never
--- ended) is restored too. Quiet: core/AuraMaster.lua's prepareProfile syncs, prepares and rebuilds
--- after it.
function Presets.RestoreStaleSnapshot()
    local shown = onScreen
    onScreen, heldForCombat = nil, false
    if shown then
        stopTestMode("profile changed")
        local left = shown.profile
        if left ~= NS.db.profile and type(left.presets) == "table" and left.presets.previewSnapshot ~= nil then
            restoreInto(left, left.presets, true)
            debug("preview restored into the profile it was taken in")
        end
    end
    if not Presets.IsPreviewing() then return end
    restoreInto(NS.db.profile, NS.db.profile.presets, true)
    debug("restored the preview snapshot left in profile '%s'", tostring(NS.db:GetCurrentProfile()))
end

--- Combat started (PLAYER_REGEN_DISABLED) with a preview up: restore now, or, when an apply would
--- have to wait, at combat's end. Test mode goes off at once either way. One line in chat.
--- The restore is APPLIED here, in the same handler, not left to the coalescing timer: that timer
--- fires on the next frame, when lockdown has begun and the apply is held to PLAYER_REGEN_ENABLED,
--- so the restored containers would be anchors with no engine for the whole fight. When an apply
--- must wait even now (lockdown already up, or auras secret), nothing is restored: the preview's
--- containers keep showing real auras through the fight and the restore runs when it ends.
function Presets.OnCombatStart()
    if not Presets.IsPreviewing() then return end
    local CM = NS.ContainerManager
    if not CM.MustDefer() and Presets.EndPreview(false) then
        CM.FlushPending()
        NS.Printf("%s", L["Preset preview ended: combat started, and your containers are back."])
        return
    end
    heldForCombat = true
    stopTestMode("combat started")
    NS.Printf("%s", L["Preset preview ended: combat started, and your containers come back when it ends."])
end

--- Combat ended (PLAYER_REGEN_ENABLED): a restore combat held runs now. core/AuraMaster.lua calls
--- this before its own regen flush, which applies what the restore queued.
function Presets.OnCombatEnd()
    if not heldForCombat then return end
    heldForCombat = false
    if Presets.IsPreviewing() then Presets.EndPreview(false) end
end
