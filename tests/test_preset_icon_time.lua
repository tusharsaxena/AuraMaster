-- tests/test_preset_icon_time.lua -- the presets' icon rows draw no time text (the owner's 2026-11-26
-- request, spec docs/superpowers/specs/2026-11-26-preset-icon-time-text-design.md): the builder writes
-- icons.time.show = false on every icon container (defaults/Presets.lua, sizeTo), and schema v25
-- (Database.HidePresetIconTime, core/Database_PresetRestack.lua) hides it on the ones an older preset
-- wrote where the stored value is still the preset's. Every case runs under both kit profiles.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil
local NS = T.NS
local fresh = dofile("tests/fresh_env.lua")
local FIXTURE = dofile("tests/presets_v22_fixture.lua")

local NAMES = { "simple", "intermediate", "advanced", "healer" }
local SCREENS = { { 1920, 1080 }, { 3440 / 1.2, 1200 } }
local copy = NS.Database.DeepCopy

--- A stored profile holding what preset `name` in `look` wrote before this change: the current
--- builder's containers, each the template with its overrides over it, Show put back on.
local function oldProfile(name, look, W, H)
    local p = { containers = {}, containerOrder = {}, nextContainerId = 1 }
    for i, spec in ipairs(NS.PresetData.Build(name, look, W, H)) do
        local c = NS.Database.Merge(copy(NS.CONTAINER_TEMPLATE), copy(spec.overrides))
        c.icons.time.show = true
        c.id = i
        p.containers[i] = c
        p.containerOrder[i] = i
        p.nextContainerId = i + 1
    end
    return p
end

--- One container of style `style` named `name`, as the template plus those two.
local function container(id, name, style)
    local c = NS.Database.Merge(copy(NS.CONTAINER_TEMPLATE), { name = name, style = style })
    c.id = id
    return c
end

local function profileOf(list)
    local p = { containers = {}, containerOrder = {}, nextContainerId = #list + 1 }
    for i, c in ipairs(list) do
        p.containers[c.id] = c
        p.containerOrder[i] = c.id
    end
    return p
end

--- Whether `a` and `b` hold the same values, deep.
local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do
        if not same(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

-- ── the builder ────────────────────────────────────────────────────────────────────────────────

test("preset icon time: every icon container a preset builds hides its time text", function()
    local P, seen = NS.PresetData, 0
    for _, name in ipairs(NAMES) do
        for _, look in ipairs(P.LOOKS) do
            for _, wh in ipairs(SCREENS) do
                for _, spec in ipairs(P.Build(name, look, wh[1], wh[2])) do
                    local o, what = spec.overrides, ("%s/%s@%d %s"):format(name, look, wh[2], spec.role)
                    if o.style == "icons" then
                        seen = seen + 1
                        -- red under: the template's Show on reaching a preset icon row
                        assertEqual(o.icons.time and o.icons.time.show, false, what .. ": time text hidden")
                        assertNil(o.icons.stacks, what .. ": the stack count keeps the template's")
                    else
                        assertNil(o.icons, what .. ": a " .. o.style .. " container states no icon section")
                    end
                end
            end
        end
    end
    assertTrue(seen > 0, "the case saw icon containers")
    -- The far pair is icons in the Bars look as well.
    local far = 0
    for _, spec in ipairs(P.Build("advanced", "bars", 1920, 1080)) do
        if spec.role == "ticoD" or spec.role == "ticoB" then
            far = far + 1
            assertEqual(spec.overrides.icons.time.show, false, spec.role)
        end
    end
    assertEqual(far, 2, "Advanced in Bars builds the far pair")
end)

test("preset icon time: applied, the far pair stores Show off; a hand-made icon container keeps it on", function()
    local env = fresh()
    env.Helpers.SkinPicker = function() return nil end
    assertTrue(env.Presets.Apply("advanced", "bars", "replace"))
    local found = 0
    for _, c in ipairs(env.Database.GetContainers()) do
        if c.style == "icons" then
            found = found + 1
            assertEqual(c.icons.time.show, false, c.name)
            assertEqual(c.icons.stacks.show, NS.CONTAINER_TEMPLATE.icons.stacks.show, c.name .. ": stacks untouched")
        end
    end
    assertEqual(found, 2, "[17] and [18]")
    -- red under: the template changed instead of the builder
    assertEqual(NS.CONTAINER_TEMPLATE.icons.time.show, true, "the template keeps Show on")
    local id = env.ContainerManager.Create({ name = "Mine", style = "icons" })
    assertEqual(env.Database.FindContainer(id).icons.time.show, true, "a container made by hand")
end)

-- ── schema v25 ─────────────────────────────────────────────────────────────────────────────────

test("v25: hides the time text on every icon container an older preset wrote", function()
    for _, name in ipairs(NAMES) do
        for _, look in ipairs(NS.PresetData.LOOKS) do
            for _, wh in ipairs(SCREENS) do
                local p, what = oldProfile(name, look, wh[1], wh[2]), ("%s/%s@%d"):format(name, look, wh[2])
                local before, icons = copy(p), 0
                local n = NS.Database.HidePresetIconTime(p)
                for id, c in pairs(p.containers) do
                    if c.style == "icons" then
                        icons = icons + 1
                        -- red under: a role or number the step's frozen list lacks
                        assertEqual(c.icons.time.show, false, what .. " " .. c.name)
                        c.icons.time.show = true
                    end
                    -- Nothing else moved: put the one field back and compare the whole container.
                    assertTrue(same(c, before.containers[id]), what .. " " .. c.name .. ": nothing else moved")
                end
                assertEqual(n, icons, what .. ": one field per icon container")
            end
        end
    end
end)

test("v25: matches the v22 builder's numbering", function()
    local seen = {}
    for _, list in pairs(FIXTURE) do
        for _, f in ipairs(list) do
            if f.style ~= "text" then seen[f.name] = true end
        end
    end
    local list, id = {}, 0
    for name in pairs(seen) do
        id = id + 1
        list[#list + 1] = container(id, name, "icons")
    end
    assertTrue(#list > 20, "the fixture's names")
    local p = profileOf(list)
    assertEqual(NS.Database.HidePresetIconTime(p), #list, "every v22 name, as an icon row")
    for _, c in pairs(p.containers) do assertEqual(c.icons.time.show, false, c.name) end
end)

-- The first numbered builder (9937767, 2026-11-15, to the 2026-11-17 rebuild ea19dd4) numbered each
-- tier in creation order, "[%d]" until 3edb6ac and "[%02d]" after: Advanced's target stack ran
-- tdeb 10 .. tspec 16. Its every non-text role, frozen from 3edb6ac's TIERS (Healer's pcdHealer is
-- named Player cooldowns).
local FIRST_NUMBERED = {
    { 1, "Player buffs (all)" }, { 2, "Weapon enchants" }, { 3, "Player debuffs (all)" },
    { 4, "Player buffs, short" }, { 5, "Player cooldowns" }, { 6, "Target debuffs (mine)" },
    { 7, "Target cooldowns" }, { 8, "Focus debuffs (mine)" },
    { 7, "Player buffs, short" }, { 8, "Player cooldowns" }, { 9, "Player special (mine)" },
    { 10, "Target debuffs (mine)" }, { 11, "Target buffs (mine)" }, { 12, "Target crowd control" },
    { 13, "Target cooldowns, players" }, { 14, "Target cooldowns, NPCs" }, { 15, "Target stealable" },
    { 16, "Target special (mine)" }, { 17, "Target debuffs (all)" }, { 18, "Target buffs (all)" },
    { 19, "Focus debuffs (mine)" }, { 20, "Focus buffs (mine)" },
    { 6, "Your heals on target" }, { 7, "Dispellable by you on target" },
    { 8, "Your heals on focus" }, { 9, "Dispellable by you on focus" },
}

test("v25: matches the first numbered builder's names, one digit and two", function()
    local list = {}
    for _, e in ipairs(FIRST_NUMBERED) do
        for _, fmt in ipairs({ "[%02d] %s", "[%d] %s" }) do
            list[#list + 1] = container(#list + 1, fmt:format(e[1], NS.L[e[2]]), "icons")
        end
    end
    local p = profileOf(list)
    -- red under: the step without the 2026-11-15..17 numbers, or without the one-digit form
    assertEqual(NS.Database.HidePresetIconTime(p), #list, "every name of that build, as an icon row")
    for _, c in pairs(p.containers) do assertEqual(c.icons.time.show, false, c.name) end
    -- a one-digit number is still checked against its role
    local q = profileOf({ container(1, "[3] " .. NS.L["Target debuffs (all)"], "icons") })
    assertEqual(NS.Database.HidePresetIconTime(q), 0, "a number no builder gave that role")
end)

test("v25: leaves bars, hand-made, renamed and explicitly hidden containers alone", function()
    local L = NS.L
    local far = "[17] " .. L["Target debuffs (all)"]
    local bars = container(1, far, "bars")
    local mine = container(2, "My icons", "icons")
    local renamed = container(3, "[17] Debuffs", "icons")
    local wrongNumber = container(4, "[03] " .. L["Target debuffs (all)"], "icons")
    local off = container(5, "[18] " .. L["Target buffs (all)"], "icons")
    off.icons.time.show = false
    local copy2 = container(6, far .. " (2)", "icons")
    local missing = container(7, "[01] " .. L["Player buffs (all)"], "icons")
    missing.icons.time.show = nil
    local noTime = container(8, "[02] " .. L["Weapon enchants"], "icons")
    noTime.icons.time = "junk"
    local text = container(9, "[04] " .. L["Offensive cooldowns"], "icons")
    local p = profileOf({ bars, mine, renamed, wrongNumber, off, copy2, missing, noTime, text })
    -- red under: a step keyed on style alone, on the name without its number, or one writing false over false
    assertEqual(NS.Database.HidePresetIconTime(p), 2, "the (2) copy and the missing key")
    assertEqual(bars.icons.time.show, true, "a bars container of a preset name")
    assertEqual(mine.icons.time.show, true, "a container made by hand")
    assertEqual(renamed.icons.time.show, true, "a renamed preset row")
    assertEqual(wrongNumber.icons.time.show, true, "a number no builder gave that role")
    assertEqual(off.icons.time.show, false, "already off")
    assertEqual(copy2.icons.time.show, false, "an add apply's (2) copy")
    assertEqual(missing.icons.time.show, false, "a missing key reads as the template's on")
    assertEqual(noTime.icons.time, "junk", "a non-table time section is skipped")
    assertEqual(text.icons.time.show, true, "a text role's name, never an icon row a preset made")
end)

test("v25: idempotent, and the ladder runs it once over every stored profile", function()
    local p = oldProfile("advanced", "icons", 1920, 1080)
    assertTrue(NS.Database.HidePresetIconTime(p) > 0, "first run")
    assertEqual(NS.Database.HidePresetIconTime(p), 0, "second run")
    local saved = { global = { schemaVersion = 24 }, profiles = {} }
    for _, name in ipairs({ "Default", "Parked" }) do
        local q = oldProfile("advanced", "bars", 1920, 1080)
        q.seeded, q.presets = true, { pickerSeen = true }
        saved.profiles[name] = q
    end
    local NSx = fresh({ savedVariables = saved })
    for _, name in ipairs({ "Default", "Parked" }) do
        for _, c in pairs(NSx.db.sv.profiles[name].containers) do
            if c.style == "icons" then assertEqual(c.icons.time.show, false, name .. " " .. c.name) end
        end
    end
    assertEqual(NSx.db.global.schemaVersion, 25)
    assertEqual(NSx.SCHEMA_VERSION, 25)
end)
