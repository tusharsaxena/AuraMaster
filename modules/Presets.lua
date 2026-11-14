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
