-- tests/test_presets_preview.lua -- modules/Presets.lua: a preset previewed on the real screen and the
-- exact restore that ends it (AM-PR03; spec section 6). Every case writes the registry, so each
-- builds its own environment (tests/fresh_env.lua). A fresh profile holds the starter containers and
-- no custom category of its own.

local freshEnv = dofile("tests/fresh_env.lua")

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertNil, T.assertFalse

--- A fresh environment with the first-run skin picker kept out of it (tests/test_presets_apply.lua
--- says why).
local function fresh(opts)
    local NS, mocks = freshEnv(opts)
    NS.Helpers.SkinPicker = function() return nil end
    return NS, mocks
end

--- A deterministic text of `v`, tables by sorted key, for comparing stored state whole.
local function serialize(v)
    if type(v) ~= "table" then return type(v) .. ":" .. tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. serialize(v[k]) end
    return "{" .. table.concat(out, ",") .. "}"
end

--- The stored state a preview may change and its restore must put back: the registry and the
--- custom categories, of profile `p` (the active one by default).
local function stored(NS, p)
    p = p or NS.db.profile
    return serialize({
        containers = p.containers, containerOrder = p.containerOrder, nextContainerId = p.nextContainerId,
        userCategories = p.userCategories, userCategoryOrder = p.userCategoryOrder,
        categorySpells = p.categorySpells,
    })
end

--- A player's own setup worth restoring: a custom category with a spell list, a container that shows
--- it, and a container attached to another (an attach target the restore must keep by id).
local function ownSetup(NS)
    local CM, Cat = NS.ContainerManager, NS.Categories
    local key = assert(Cat.CreateUserCategory("My procs", "HELPFUL"))
    NS.db.profile.categorySpells[key] = { [11111] = true }
    local head = assert(CM.Create({ name = "My head" }))
    local member = assert(CM.Create({ name = "My member",
        attach = { mode = "container", container = head, point = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = 0, y = -2 } }))
    return { key = key, head = head, member = member }
end

--- Every stored container has a live instance with an aura engine built (`what` names the moment).
local function assertEngines(NS, what)
    local containers = NS.Database.GetContainers()
    assertTrue(#containers > 0, what .. ": containers")
    for _, c in ipairs(containers) do
        local inst = NS.ContainerManager.instances[c.id]
        assertTrue(inst ~= nil and inst.engine ~= nil, what .. ": " .. c.name .. " has an engine")
    end
end

local function names(NS)
    local out = {}
    for _, c in ipairs(NS.Database.GetContainers()) do out[#out + 1] = c.name end
    return out
end

test("preview: snapshot and restore exact", function()
    local NS = fresh()
    local own = ownSetup(NS)
    local before = stored(NS)
    local ok, err = NS.Presets.BeginPreview("advanced", "bars")
    assertTrue(ok, tostring(err))
    assertTrue(NS.Presets.IsPreviewing())
    assertTrue(NS.State.testMode, "the preview fills with sample auras")
    assertEqual(#NS.Database.GetContainers(), 20, "the preset is on the screen")
    assertTrue(NS.db.profile.presets.previewSnapshot ~= nil, "the snapshot is stored in the profile")
    assertTrue(NS.Presets.EndPreview(false))
    -- red under: a restore that re-creates the containers (new ids) or keeps the preview's categories
    assertEqual(stored(NS), before, "ids, attach targets, categories and spell lists are back as they were")
    local member = NS.Database.FindContainer(own.member)
    assertEqual(member.attach.mode, "container")
    assertEqual(member.attach.container, own.head)
    assertFalse(NS.Presets.IsPreviewing())
    assertFalse(NS.State.testMode, "test mode is off")
    assertNil(NS.db.profile.presets.previewSnapshot)
    assertTrue(NS.Categories.Find("HELPFUL", own.key) ~= nil, "the player's own category is materialized")
    -- the live instances follow the restored registry
    for _, c in ipairs(NS.Database.GetContainers()) do
        assertTrue(NS.ContainerManager.instances[c.id] ~= nil, c.name)
    end
    assertEqual(NS.ContainerManager.Count(), #NS.db.profile.containerOrder)
end)

test("preview: swap keeps the first snapshot", function()
    local NS = fresh()
    ownSetup(NS)
    local before = stored(NS)
    assertTrue(NS.Presets.BeginPreview("simple", "bars"))
    local first = serialize(NS.db.profile.presets.previewSnapshot)
    assertTrue(NS.Presets.BeginPreview("intermediate", "icons"))
    -- red under: a second Begin snapshotting the first preview over the player's own setup
    assertEqual(serialize(NS.db.profile.presets.previewSnapshot), first)
    assertEqual(#NS.Database.GetContainers(), 8, "the swap is on the screen")
    assertTrue(NS.Presets.EndPreview(false))
    assertEqual(stored(NS), before)
end)

test("preview: keep after swap carries only the kept preset's categories", function()
    local NS = fresh()
    local own = ownSetup(NS)
    local p = NS.db.profile
    local mine = serialize(p.userCategoryOrder)
    assertTrue(NS.Presets.BeginPreview("advanced", "bars"))
    assertEqual(#p.userCategoryOrder, 3, "the preview made Advanced's two")
    assertTrue(NS.Presets.BeginPreview("simple", "bars"))
    -- red under: a swap that keeps the first snapshot but leaves the previous preview's categories
    assertEqual(serialize(p.userCategoryOrder), mine, "the swap starts from the player's own categories")
    assertTrue(NS.Presets.EndPreview(true, "replace"))
    assertEqual(serialize(p.userCategoryOrder), mine, "only the player's own category is left")
    assertEqual(#NS.Database.GetContainers(), 3, "Simple is kept")
    for _, c in ipairs(NS.Database.GetContainers()) do
        for key in pairs(c.filter.categories or {}) do
            if NS.Categories.IsUserKey(key) then
                assertEqual(key, own.key, c.name .. " stores no category the player never asked for")
            end
        end
    end
end)

test("preview: keep replace drops snapshot and test mode off", function()
    local NS = fresh()
    ownSetup(NS)
    assertTrue(NS.Presets.BeginPreview("advanced", "icons"))
    local previewed = stored(NS)
    assertTrue(NS.Presets.EndPreview(true, "replace"))
    assertEqual(stored(NS), previewed, "the preset stays as previewed")
    assertNil(NS.db.profile.presets.previewSnapshot)
    assertFalse(NS.Presets.IsPreviewing())
    assertFalse(NS.State.testMode)
end)

test("preview: keep add restores then adds", function()
    local NS = fresh()
    local own = ownSetup(NS)
    local kept = #NS.Database.GetContainers()
    assertTrue(NS.Presets.BeginPreview("simple", "bars"))
    assertTrue(NS.Presets.EndPreview(true, "add"))
    local list = NS.Database.GetContainers()
    assertEqual(#list, kept + 3, "the player's containers and the preset's")
    assertEqual(NS.Database.FindContainer(own.member).attach.container, own.head, "the player's ids are kept")
    local all = table.concat(names(NS), "|")
    assertTrue(all:find("Weapon enchants", 1, true) ~= nil, all)
    assertNil(NS.db.profile.presets.previewSnapshot)
    assertFalse(NS.State.testMode)
end)

-- AM-PR08 review fixes: an Apply over a live preview settles it first, so no snapshot outlives the
-- preset the player confirmed.
test("preview: an apply over a preview ends it first, and the applied preset survives", function()
    local NS = fresh()
    local own = #NS.Database.GetContainers()
    assertTrue(NS.Presets.BeginPreview("advanced", "bars"))
    -- red under: Apply writing over the preview and leaving the snapshot stored
    assertTrue(NS.Presets.Apply("empty", "bars", "replace"))
    assertFalse(NS.Presets.IsPreviewing(), "the preview is settled")
    assertFalse(NS.State.testMode, "test mode off")
    assertEqual(#NS.Database.GetContainers(), 0, "Empty applied")
    assertNil(NS.Presets.EndPreview(false), "nothing left for a surface's leave to restore")
    assertEqual(#NS.Database.GetContainers(), 0, "and the confirmed preset stays")
    assertTrue(own > 0)
    -- Add over a preview lands next to the player's own containers, not the preview's.
    local NS2 = fresh()
    local own2 = #NS2.Database.GetContainers()
    assertTrue(NS2.Presets.BeginPreview("healer", "bars"))
    assertTrue(NS2.Presets.Apply("simple", "bars", "add"))
    assertEqual(#NS2.Database.GetContainers(), own2 + NS2.PresetData.Count("simple"))
    -- A /reload or a crash after: the next login has no snapshot to put back over it.
    local NS3 = fresh({ savedVariables = NS2.Database.DeepCopy(_G.AuraMasterDB) })
    assertEqual(#NS3.Database.GetContainers(), own2 + NS3.PresetData.Count("simple"), "the login keeps it")
end)

test("preview: an apply over a preview is refused whole in combat", function()
    local NS, m = fresh()
    assertTrue(NS.Presets.BeginPreview("simple", "bars"))
    m.__lockdown = true
    local ok, _, gray = NS.Presets.Apply("healer", "bars", "replace")
    assertNil(ok)
    assertTrue(gray, "the combat line, gray")
    assertTrue(NS.Presets.IsPreviewing(), "nothing changed: the preview is still up")
    m.__lockdown = false
end)

test("preview: an unknown preset is refused before a snapshot is taken", function()
    local NS = fresh()
    local before = stored(NS)
    local ok, err = NS.Presets.BeginPreview("huge", "bars")
    assertNil(ok)
    assertTrue(type(err) == "string" and err ~= "")
    assertFalse(NS.Presets.IsPreviewing())
    assertFalse(NS.State.testMode)
    assertEqual(stored(NS), before)
    local ended = NS.Presets.EndPreview(false)
    assertNil(ended, "nothing to end")
end)

test("preview: refused in combat, and ending it waits for combat", function()
    local NS, mocks = fresh()
    local before = stored(NS)
    mocks.__lockdown = true
    local ok, err = NS.Presets.BeginPreview("simple", "bars")
    assertNil(ok)
    assertTrue(type(err) == "string" and err:find("during combat", 1, true) ~= nil, tostring(err))
    assertFalse(NS.Presets.IsPreviewing())
    assertEqual(stored(NS), before)
    mocks.__lockdown = false
    assertTrue(NS.Presets.BeginPreview("simple", "bars"))
    mocks.__lockdown = true
    local ended, why = NS.Presets.EndPreview(false)
    assertNil(ended)
    assertTrue(type(why) == "string" and why:find("during combat", 1, true) ~= nil, tostring(why))
    assertTrue(NS.Presets.IsPreviewing(), "the snapshot is kept for a later end")
end)

test("preview: stale snapshot restores at login", function()
    local NS = fresh()
    local own = ownSetup(NS)
    local before = stored(NS)
    assertTrue(NS.Presets.BeginPreview("advanced", "bars"))
    -- A /reload or a crash: the SavedVariables file as it stands, read by the next session.
    local saved = NS.Database.DeepCopy(_G.AuraMasterDB)
    local NS2 = fresh({ savedVariables = saved })
    -- red under: no login restore (the 20 preview containers come back as the player's own)
    assertEqual(stored(NS2), before, "the player's own containers and categories are back, ids included")
    assertEqual(NS2.Database.FindContainer(own.member).attach.container, own.head)
    assertNil(NS2.db.profile.presets.previewSnapshot, "the snapshot is cleared")
    assertFalse(NS2.Presets.IsPreviewing())
    assertFalse(NS2.State.testMode)
    for _, c in ipairs(NS2.Database.GetContainers()) do
        assertTrue(NS2.ContainerManager.instances[c.id] ~= nil, "built at login: " .. c.name)
    end
    assertTrue(NS2.Categories.Find("HELPFUL", own.key) ~= nil, "the restored category is materialized")
    for _, key in ipairs(NS2.db.profile.userCategoryOrder) do
        assertTrue(NS2.db.profile.userCategories[key].name ~= "Special player buffs", "the preview's are gone")
    end
end)

test("preview: a stale snapshot in a profile not in use is restored at login too", function()
    local NS = fresh()
    ownSetup(NS)
    local raidBefore
    NS.db:SetProfile("Raid")
    assertTrue(NS.Presets.BeginPreview("simple", "bars"))
    raidBefore = serialize(NS.db.profile.presets.previewSnapshot.containers)
    local saved = NS.Database.DeepCopy(_G.AuraMasterDB)
    -- The crash left Raid mid-preview; the next login is a character on Default.
    for key in pairs(saved.profileKeys or {}) do saved.profileKeys[key] = "Default" end
    local NS2 = fresh({ savedVariables = saved })
    assertEqual(NS2.db:GetCurrentProfile(), "Default")
    local raid = NS2.db.sv.profiles.Raid
    -- red under: a login restore that reads the active profile only
    assertNil(raid.presets.previewSnapshot, "the Raid snapshot is restored where it sits")
    assertEqual(serialize(raid.containers), raidBefore)
end)

test("preview: profile change restores the old profile first", function()
    local NS = fresh()
    local own = ownSetup(NS)
    local home = NS.db:GetCurrentProfile()
    local before = stored(NS)
    local ownOrder, ownNames = NS.Database.DeepCopy(NS.db.profile.containerOrder), {}
    for _, c in ipairs(NS.Database.GetContainers()) do ownNames[c.id] = c.name end
    assertTrue(NS.Presets.BeginPreview("advanced", "bars"))
    NS.db:SetProfile("Raid")
    local old = NS.db.sv.profiles[home]
    -- red under: restoring the snapshot into the new profile, or leaving the old one mid-preview.
    -- AceDB has stripped the defaults from the profile it left, so the ids, names and attachments
    -- are compared here, and the whole state once the switch comes back.
    assertEqual(serialize(old.containerOrder), serialize(ownOrder), "the old profile has its own ids back")
    for _, id in ipairs(old.containerOrder) do
        assertEqual(old.containers[id].name, ownNames[id], "container " .. id)
    end
    assertEqual(old.containers[own.member].attach.container, own.head)
    assertEqual(#old.userCategoryOrder, 1, "the preview's two categories are gone")
    assertNil(old.presets and old.presets.previewSnapshot, "and no snapshot left behind")
    assertNil((NS.db.profile.presets or {}).previewSnapshot, "the new profile was never previewed")
    assertFalse(NS.Presets.IsPreviewing())
    assertFalse(NS.State.testMode)
    for _, c in ipairs(NS.Database.GetContainers()) do
        assertTrue(c.name ~= "Special player buffs", "the new profile holds its own containers")
    end
    NS.db:SetProfile(home)
    assertEqual(stored(NS), before, "back on it, the player's setup is there")
end)

test("preview: a profile reached with a stale snapshot restores it", function()
    local NS = fresh()
    NS.db:SetProfile("Raid")
    local before = stored(NS)
    assertTrue(NS.Presets.BeginPreview("simple", "bars"))
    -- Left by a session that never ended the preview (a crash on another character), seen on a switch.
    local snap = NS.Database.DeepCopy(NS.db.profile.presets.previewSnapshot)
    NS.db:SetProfile("Default")
    NS.db.sv.profiles.Raid.presets.previewSnapshot = snap
    NS.db.sv.profiles.Raid.containers = {}
    NS.db.sv.profiles.Raid.containerOrder = {}
    NS.db:SetProfile("Raid")
    assertEqual(stored(NS), before)
    assertNil(NS.db.profile.presets.previewSnapshot)
end)

test("preview: combat ends preview with restore", function()
    local NS, mocks = fresh()
    ownSetup(NS)
    local before = stored(NS)
    local lines = {}
    NS.Printf = function(fmt, ...) lines[#lines + 1] = fmt:format(...) end
    assertTrue(NS.Presets.BeginPreview("advanced", "bars"))
    -- PLAYER_REGEN_DISABLED fires before lockdown: the restore runs at once.
    NS.addon:OnCombatChanged("PLAYER_REGEN_DISABLED")
    -- red under: combat turning test mode off and keeping the half-applied preset
    assertEqual(stored(NS), before)
    assertFalse(NS.Presets.IsPreviewing())
    assertFalse(NS.State.testMode)
    assertEqual(#lines, 1, "one line: " .. table.concat(lines, " / "))
    -- Lockdown begins on the next frame, when the coalescing timer fires: the restore was applied
    -- before it. red under: leaving the apply to the timer (held to combat's end, no engine at all)
    mocks.__lockdown = true
    mocks.__fireTimers()
    assertEngines(NS, "in combat")
    mocks.__lockdown = false
    NS.addon:OnCombatChanged("PLAYER_REGEN_ENABLED")
    assertEqual(#lines, 1, "combat ending adds nothing")
    -- Already locked down when the event is seen: test mode off now, the restore when combat ends.
    assertTrue(NS.Presets.BeginPreview("simple", "bars"))
    mocks.__lockdown = true
    NS.addon:OnCombatChanged("PLAYER_REGEN_DISABLED")
    assertFalse(NS.State.testMode)
    assertTrue(NS.Presets.IsPreviewing(), "held until combat ends")
    assertEqual(#lines, 2)
    mocks.__lockdown = false
    NS.addon:OnCombatChanged("PLAYER_REGEN_ENABLED")
    assertEqual(stored(NS), before)
    assertFalse(NS.Presets.IsPreviewing())
    assertEqual(#lines, 2, "one line per combat")
    assertEngines(NS, "after combat")
end)

test("preview: combat under secrecy keeps the preview until combat ends", function()
    local NS, mocks = fresh()
    ownSetup(NS)
    local before = stored(NS)
    local lines = {}
    NS.Printf = function(fmt, ...) lines[#lines + 1] = fmt:format(...) end
    assertTrue(NS.Presets.BeginPreview("advanced", "bars"))
    mocks.__fireTimers()   -- the frames before the pull: the preview is applied
    local secret = true
    NS.Compat.AurasAreSecret = function() return secret end
    NS.addon:OnCombatChanged("PLAYER_REGEN_DISABLED")
    -- red under: restoring while an apply must wait (anchors with no engine, and a line saying the
    -- containers are back)
    assertTrue(NS.Presets.IsPreviewing(), "held: the preview's containers keep showing real auras")
    assertFalse(NS.State.testMode)
    assertEqual(#lines, 1)
    assertEqual(lines[1], NS.L["Preset preview ended: combat started, and your containers come back when it ends."])
    mocks.__lockdown = true
    mocks.__fireTimers()
    assertEngines(NS, "the preview in combat")
    mocks.__lockdown, secret = false, false
    NS.addon:OnCombatChanged("PLAYER_REGEN_ENABLED")
    assertEqual(stored(NS), before)
    assertFalse(NS.Presets.IsPreviewing())
    assertEngines(NS, "after combat")
end)

test("preview: categories the preview created are removed", function()
    local NS = fresh()
    local own = ownSetup(NS)
    assertTrue(NS.Presets.BeginPreview("advanced", "bars"))
    assertEqual(#NS.db.profile.userCategoryOrder, 3, "the preview made Advanced's two")
    local made = {}
    for _, key in ipairs(NS.db.profile.userCategoryOrder) do
        if key ~= own.key then made[#made + 1] = key end
    end
    assertTrue(NS.Presets.EndPreview(false))
    assertEqual(#NS.db.profile.userCategoryOrder, 1)
    assertEqual(NS.db.profile.userCategoryOrder[1], own.key)
    for _, key in ipairs(made) do
        -- red under: a restore that puts the records back but leaves the definitions materialized
        assertNil(NS.Categories.Find("HELPFUL", key), key)
        assertNil(NS.Categories.Find("HARMFUL", key), key)
        assertNil(NS.db.profile.userCategories[key])
        assertNil(NS.CONTAINER_TEMPLATE.filter.categories[key], "the template drops it")
    end
end)

test("preview: RestoreSnapshot is the registry writer's, and the preset module writes no registry field", function()
    local NS = fresh()
    assertEqual(type(NS.ContainerManager.RestoreSnapshot), "function")
    assertEqual(type(NS.ContainerManager.Snapshot), "function")
    local f = assert(io.open("modules/Presets.lua", "r"))
    local src = f:read("*a")
    f:close()
    for _, field in ipairs({ "containers", "containerOrder", "nextContainerId", "userCategories",
        "userCategoryOrder", "categorySpells" }) do
        assertNil(src:find("%." .. field .. "%s*%[[^\n]*%]%s*=[^=]"), "no direct write to " .. field)
        assertNil(src:find("%." .. field .. "%s*=[^=]"), "no direct write to " .. field)
    end
end)

test("preview: the category half of a restore is the category registry's writer", function()
    local NS = fresh()
    assertEqual(type(NS.Categories.RestoreUserCategories), "function")
    assertEqual(type(NS.Categories.SnapshotUserCategories), "function")
    local f = assert(io.open("modules/ContainerManager.lua", "r"))
    local src = f:read("*a")
    f:close()
    -- red under: ContainerManager writing the custom-category registry or the spell edits itself
    for _, field in ipairs({ "userCategories", "userCategoryOrder", "categorySpells" }) do
        assertNil(src:find("%." .. field .. "%s*%[[^\n]*%]%s*=[^=]"), "no direct write to " .. field)
        assertNil(src:find("%." .. field .. "%s*=[^=]"), "no direct write to " .. field)
        assertNil(src:find('"' .. field .. '"', 1, true), "no snapshot field list naming " .. field)
    end
end)

test("preview: an in-play restore puts the spell edits back through the seam, exactly", function()
    local NS = fresh()
    local own = ownSetup(NS)
    local before = stored(NS)
    assertTrue(NS.Presets.BeginPreview("advanced", "bars"))
    local seen = {}
    local real = NS.SetByPath
    NS.SetByPath = function(path, ...) seen[#seen + 1] = path; return real(path, ...) end
    NS.Presets.EndPreview(false)
    NS.SetByPath = real
    -- red under: Cat.RestoreUserCategories assigning profile.categorySpells itself on the active profile
    local via = false
    for _, path in ipairs(seen) do if path == "categorySpells" then via = true end end
    assertTrue(via, "the spell edits go through NS.SetByPath's categorySpells carve-out")
    assertEqual(stored(NS), before, "the restore is still exact")
    assertTrue(NS.db.profile.categorySpells[own.key][11111], "the custom category keeps its spell")
end)

test("preview: a category restore into a profile not in use writes it and syncs nothing", function()
    local NS = fresh()
    local Cat = NS.Categories
    local other = { userCategories = {}, userCategoryOrder = {}, categorySpells = {} }
    local live = serialize(Cat.HELPFUL)
    local snap = { userCategories = { userabcdefghij = { key = "userabcdefghij", name = "Elsewhere", auraType = "HELPFUL" } },
        userCategoryOrder = { "userabcdefghij" }, categorySpells = { userabcdefghij = { [5] = true } } }
    Cat.RestoreUserCategories(snap, other, true)
    assertEqual(other.userCategories.userabcdefghij.name, "Elsewhere")
    assertEqual(other.userCategoryOrder[1], "userabcdefghij")
    assertTrue(other.categorySpells.userabcdefghij[5])
    assertTrue(other.userCategories ~= snap.userCategories, "a deep copy, so the snapshot stays the snapshot")
    assertEqual(serialize(Cat.HELPFUL), live, "a quiet restore materializes nothing")
end)
