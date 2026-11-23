-- tests/test_database_restack.lua -- schema v23 (Database.RestackPresets, core/Database_PresetRestack.lua):
-- the owner's 2026-11-23 preset feedback carried into a profile the v22 builder wrote, where the
-- player has not changed it (presets restack spec section 4). The "before" is the v22 builder's own
-- output, frozen in tests/presets_v22_fixture.lua; the "after" is the current builder's.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNear = T.test, T.assertEqual, T.assertTrue, T.assertNear
local NS = T.NS
local fresh = dofile("tests/fresh_env.lua")
local FIXTURE = dofile("tests/presets_v22_fixture.lua")

-- The owner's screen: 3440 x 1440 at UI scale 1.2, a parent 1200 tall.
local OWN_W, OWN_H = 3440 / 1.2, 1200

local copy = NS.Database.DeepCopy

--- A stored profile holding fixture `key`'s containers, as an Apply of the v22 builder left it: each
--- the template with the fixture's fields over it, its id the fixture's (creation order), and a
--- marker in its spell list so a case can follow the container through the step.
local function oldProfile(key)
    local p = { containers = {}, containerOrder = {}, nextContainerId = 1 }
    for _, f in ipairs(assert(FIXTURE[key], key)) do
        local c = NS.Database.Merge(copy(NS.CONTAINER_TEMPLATE), copy(f))
        c.filter.whitelist = { [9000 + f.id] = true }
        p.containers[f.id] = c
        p.containerOrder[#p.containerOrder + 1] = f.id
        p.nextContainerId = f.id + 1
    end
    return p
end

local function byName(p, name)
    for _, id in ipairs(p.containerOrder) do
        if p.containers[id].name == name then return p.containers[id] end
    end
end

local function sameRGB(a, b)
    return math.abs(a.r - b.r) < 1e-6 and math.abs(a.g - b.g) < 1e-6 and math.abs(a.b - b.b) < 1e-6
end

--- The fill preset `name`'s new builder writes for spec `o`, as stored (the template's where it states
--- none).
local function wantFill(o)
    local D = NS.CONTAINER_TEMPLATE.bars
    local b = o.bars
    local fromSkin = b.barColorFromSkin
    if fromSkin == nil then fromSkin = D.barColorFromSkin end
    return b.colorMode, b.barColor or D.barColor, fromSkin
end

--- Profile `p`, migrated from fixture `name`@`screen`, holds what the current builder writes on that
--- screen in every field the step owns: names in containerOrder, the tower chains, the fills, and
--- 240 for every bar. `towers` = whether its towers restack (its own heads keep their placement).
local function checkAsBuilt(p, name, W, H, where)
    local specs = NS.PresetData.Build(name, "bars", W, H)
    assertEqual(#p.containerOrder, #specs, where .. ": as many containers")
    for i, spec in ipairs(specs) do
        local c = p.containers[p.containerOrder[i]]
        local o, what = spec.overrides, ("%s #%d %s"):format(where, i, spec.role)
        assertEqual(c.name, o.name, what .. ": the new name, in the new order")
        if o.style == "bars" then
            assertEqual(c.bars.width, 240, what .. ": 240 wide")
            local mode, color, fromSkin = wantFill(o)
            assertEqual(c.bars.colorMode, mode, what .. ": fill mode")
            assertTrue(sameRGB(c.bars.barColor, color), what .. ": the new fill color")
            assertEqual(c.bars.barColorFromSkin, fromSkin, what .. ": the skin does not decide it")
        end
        if spec.attachTo then
            assertEqual(c.attach.mode, "container", what .. ": attached")
            assertEqual(tonumber(c.attach.container), p.containerOrder[spec.attachTo], what .. ": to the new one below it")
            assertEqual(c.attach.childPoint, o.attach.childPoint, what .. ": by the same point")
        elseif spec.stack ~= "middle" then
            -- A stack's head is where the new builder puts it: a tower's new head takes the old head's
            -- place, and a place still the v22 builder's moves to the new one (the focus and far heads
            -- by Player debuffs' left edge, the cluster's shift). red under: the v22 place, 589 on the
            -- owner's screen where the new one is 629
            assertEqual(c.attach.mode, "screen", what .. ": the head is placed")
            assertEqual(c.position.point, o.position.point, what .. ": by the same point")
            assertEqual(c.position.x, o.position.x, what .. ": at the tower's place")
            assertEqual(c.position.y, o.position.y, what .. ": at the tower's height")
        end
    end
end

test("v23: the frozen names are the v22 builder's, and the new order the current builder's", function()
    local R = NS.Database.PRESET_RESTACK
    -- Every bars container the v22 builder named, in any preset on either screen, is one v23 knows.
    local known = {}
    for _, name in ipairs(R.BarsNames()) do known[name] = true end
    local n = 0
    for key, list in pairs(FIXTURE) do
        for _, c in ipairs(list) do
            if c.style == "bars" then
                n = n + 1
                -- red under: a role the frozen list leaves out, whose 266 would stay
                assertTrue(known[c.name], key .. " " .. c.name .. " is a v22 preset bar")
            end
        end
    end
    assertTrue(n > 0, "the fixture holds bars")
    -- Every tower's old chain is one the v22 builder wrote; its new chain the current builder's.
    for _, tower in ipairs(R.Towers()) do
        local p = oldProfile(tower.preset .. "@1080")
        for k, name in ipairs(tower.oldNames) do
            local c = byName(p, name)
            assertTrue(c ~= nil, tower.preset .. ": " .. name .. " in the v22 build")
            if k > 1 then assertEqual(c.attach.container, byName(p, tower.oldNames[k - 1]).id, name .. " on the one before") end
        end
        local specs, built = NS.PresetData.Build(tower.preset, "bars", 1920, 1080), {}
        for _, spec in ipairs(specs) do built[spec.overrides.name] = true end
        for _, name in ipairs(tower.newNames) do assertTrue(built[name], tower.preset .. ": " .. name .. " is built") end
    end
end)

test("v23: a v22 Advanced, Intermediate, Healer and Simple become what the presets build now", function()
    for _, scr in ipairs({ { "1080", 1920, 1080 }, { "1200", OWN_W, OWN_H }, { "1440", 2560, 1440 } }) do
        for _, name in ipairs({ "simple", "intermediate", "advanced", "healer" }) do
            local where = name .. "@" .. scr[1]
            local p = oldProfile(where)
            local before = {}
            for id, c in pairs(p.containers) do before[id] = next(c.filter.whitelist) end
            local n = NS.Database.RestackPresets(p, scr[2], scr[3])
            -- red under: no step, or one that misses a field
            if name ~= "simple" then assertTrue(n > 0, where .. ": changed") end
            checkAsBuilt(p, name, scr[2], scr[3], where)
            -- Each container kept its id and everything else: its spell list followed it.
            for id, c in pairs(p.containers) do
                assertEqual(c.id, id, where .. ": the id")
                assertEqual(next(c.filter.whitelist), before[id], where .. " " .. c.name .. ": its own spells")
            end
            -- Once: a second run changes nothing.
            assertEqual(NS.Database.RestackPresets(p, scr[2], scr[3]), 0, where .. ": idempotent")
        end
    end
    -- The roles keep their identity: Player buffs, short is the same container, now on top.
    local p = oldProfile("advanced@1080")
    local short = byName(p, "[07] " .. NS.L["Player buffs, short"])
    NS.Database.RestackPresets(p, 1920, 1080)
    assertEqual(short.name, "[09] " .. NS.L["Player buffs, short"], "renumbered, the same table")
    assertEqual(next(short.filter.whitelist), 9007, "with its spells")
end)

test("v23: the frozen v22 placement is the v22 builder's on every screen", function()
    local R = NS.Database.PRESET_RESTACK
    local n = 0
    for key, list in pairs(FIXTURE) do
        local W, H = 1920, 1080
        if key:find("@1200") then W, H = OWN_W, OWN_H elseif key:find("@1440") then W, H = 2560, 1440 end
        for _, c in ipairs(list) do
            local stack = R.HeadStack(c.name)
            if stack and c.attach.mode == "screen" then
                n = n + 1
                local want = R.OldPlace(stack, c.style, "right", W, H)
                -- red under: a frozen layout that drifted from the v22 arithmetic
                for _, f in ipairs({ "point", "relativePoint", "x", "y" }) do
                    assertEqual(want[f], c.position[f], key .. " " .. c.name .. " " .. f)
                end
            end
        end
    end
    assertTrue(n > 0, "the case saw heads")
end)

test("v23: a head the player moved stays where they put it", function()
    local L = NS.L
    local p = oldProfile("advanced@1200")
    local fdeb, far = byName(p, "[19] " .. L["Focus debuffs (mine)"]), byName(p, "[17] " .. L["Target debuffs (all)"])
    assertEqual(fdeb.position.x, 589, "the v22 place on the owner's screen")
    fdeb.position.x = 600
    local _, notes = NS.Database.RestackPresets(p, OWN_W, OWN_H)
    -- red under: a step that writes the new place over the player's own
    assertEqual(fdeb.position.x, 600, "a moved head stays")
    assertEqual(far.position.x, 629, "an unmoved one goes to the new place")
    local noted = false
    for _, note in ipairs(notes) do noted = noted or (note.field == "place" and note.name == fdeb.name) end
    assertTrue(noted, "the kept place is noted")
    -- No screen to read: the v22 place was 1080's, so a 589 is the player's.
    local q = oldProfile("advanced@1200")
    NS.Database.RestackPresets(q, nil, nil)
    assertEqual(byName(q, "[19] " .. L["Focus debuffs (mine)"]).position.x, 589, "no parent: left alone")
end)

test("v23: a profile the current presets built is left as it is", function()
    for _, name in ipairs({ "simple", "intermediate", "advanced", "healer" }) do
        local p = { containers = {}, containerOrder = {} }
        NS.PresetData.Realize(NS.PresetData.Build(name, "bars", OWN_W, OWN_H), nil, function(o)
            local id = #p.containerOrder + 1
            local c = NS.Database.Merge(copy(NS.CONTAINER_TEMPLATE), o)
            c.id = id
            p.containers[id], p.containerOrder[id] = c, id
            return id
        end)
        -- red under: an old name the new presets reuse ([08] Player cooldowns, [10] Target special
        -- (mine), [05] Player cooldowns) read as the old role and changed again
        assertEqual(NS.Database.RestackPresets(p, OWN_W, OWN_H), 0, name)
    end
end)

test("v23: what the player changed stays, field by field", function()
    local L = NS.L
    local p = oldProfile("advanced@1200")
    local short, pcd = byName(p, "[07] " .. L["Player buffs, short"]), byName(p, "[08] " .. L["Player cooldowns"])
    local tcdn = byName(p, "[15] " .. L["Target cooldowns, NPCs"])
    short.bars.barColor = { r = 1, g = 0, b = 0, a = 1 }
    pcd.bars.width = 300
    tcdn.bars.barColorFromSkin = true
    local _, notes = NS.Database.RestackPresets(p, OWN_W, OWN_H)
    -- red under: a step that writes the new value over the player's own
    assertTrue(sameRGB(short.bars.barColor, { r = 1, g = 0, b = 0 }), "a picked color stays")
    assertEqual(pcd.bars.width, 300, "a typed width stays")
    assertTrue(tcdn.bars.barColorFromSkin, "a fill put on the skin stays")
    assertTrue(not sameRGB(tcdn.bars.barColor, { r = 230 / 255, g = 204 / 255, b = 128 / 255 }), "and is not recolored")
    -- The rest of the profile still moves: the towers restack, the other widths go to 240.
    assertEqual(short.name, "[09] " .. L["Player buffs, short"], "an edited color does not hold the tower")
    assertEqual(byName(p, "[14] " .. L["Target debuffs (mine)"]).bars.width, 240)
    assertTrue(sameRGB(pcd.bars.barColor, { r = 230 / 255, g = 204 / 255, b = 128 / 255 }), "Player cooldowns tan")
    -- Every field left alone is noted, for the replay's report.
    local seen = {}
    for _, note in ipairs(notes) do seen[note.field .. " " .. note.name] = true end
    assertTrue(seen["color [09] " .. L["Player buffs, short"]], "the color note")
    assertTrue(seen["width [08] " .. L["Player cooldowns"]], "the width note")
end)

test("v23: a width written on another screen, or with no screen to read, stays", function()
    local p = oldProfile("advanced@1200")
    -- red under: a step that sets every width to 240, the player's own 266 included
    NS.Database.RestackPresets(p, nil, nil)
    assertEqual(byName(p, "[08] " .. NS.L["Player cooldowns"]).bars.width, 266, "no parent: only 240 is the preset's")
    local q = oldProfile("advanced@1200")
    NS.Database.RestackPresets(q, 2560, 1440)
    assertEqual(byName(q, "[08] " .. NS.L["Player cooldowns"]).bars.width, 266, "1440 tall wrote 320, not 266")
    local r = oldProfile("advanced@1200")
    NS.Database.RestackPresets(r, OWN_W, OWN_H)
    assertEqual(byName(r, "[19] " .. NS.L["Focus debuffs (mine)"]).bars.width, 240, "267, a rounding of 1200 tall's")
end)

test("v23: a tower the player rebuilt keeps its order and its numbers", function()
    local L = NS.L
    local cases = {
        -- red under: a restack that moves a member the player moved off the chain
        moved = function(p) byName(p, "[08] " .. L["Player cooldowns"]).attach = { mode = "screen", container = 0, frame = "" } end,
        -- red under: a restack that leaves the player's own extra hanging mid-tower
        extra = function(p)
            local id = p.nextContainerId
            p.containers[id] = NS.Database.Merge(copy(NS.CONTAINER_TEMPLATE), { id = id, name = "Mine",
                attach = { mode = "container", container = byName(p, "[08] " .. L["Player cooldowns"]).id } })
            p.containerOrder[#p.containerOrder + 1] = id
        end,
        -- red under: identity by position or by role name alone
        -- red under: a check that reads `container` alone, missing a frame typed by its global name
        byFrame = function(p)
            local id = p.nextContainerId
            p.containers[id] = NS.Database.Merge(copy(NS.CONTAINER_TEMPLATE), { id = id, name = "Mine",
                attach = { mode = "frame", container = 0,
                    frame = "AuraMasterAnchor" .. byName(p, "[08] " .. L["Player cooldowns"]).id } })
            p.containerOrder[#p.containerOrder + 1] = id
        end,
        renamed = function(p) byName(p, "[09] " .. L["Player special (mine)"]).name = "[09] Procs" end,
        twice = function(p)
            local id = p.nextContainerId
            p.containers[id] = NS.Database.Merge(copy(NS.CONTAINER_TEMPLATE), { id = id,
                name = "[09] " .. L["Player special (mine)"] })
            p.containerOrder[#p.containerOrder + 1] = id
        end,
    }
    for what, edit in pairs(cases) do
        local p = oldProfile("advanced@1080")
        edit(p)
        local _, notes = NS.Database.RestackPresets(p, 1920, 1080)
        assertTrue(byName(p, "[07] " .. L["Player buffs, short"]) ~= nil, what .. ": the player tower keeps its numbers")
        assertEqual(byName(p, "[08] " .. L["Player cooldowns"]).attach.childPoint == "BOTTOM"
            or what == "moved", true, what .. ": its links")
        -- The target tower, untouched by the edit, still restacks.
        assertTrue(byName(p, "[11] " .. L["Target crowd control"]) ~= nil, what .. ": the target tower restacks")
        local noted = false
        for _, note in ipairs(notes) do noted = noted or note.field == "tower" end
        assertTrue(noted, what .. ": the kept tower is noted")
    end
    -- A display order the player changed keeps theirs; the tower restacks.
    local p = oldProfile("advanced@1080")
    local order = p.containerOrder
    order[7], order[8] = order[8], order[7]
    local mine = { unpack(order) }
    NS.Database.RestackPresets(p, 1920, 1080)
    -- red under: a refill that ignores the player's order
    for i = 7, 9 do assertEqual(p.containerOrder[i], mine[i], "order #" .. i .. " kept") end
    assertEqual(byName(p, "[07] " .. L["Player special (mine)"]).attach.mode, "screen", "restacked")
end)

test("v23: an untouched seed stays untouched for the first-run picker", function()
    local p = oldProfile("simple@1200")
    p.presets = { seedPrint = NS.Presets.Fingerprint(p.containers, p.containerOrder) }
    assertTrue(NS.Database.RestackPresets(p, OWN_W, OWN_H) > 0, "the widths moved")
    -- red under: a seed the step changed read as the player's own work
    assertEqual(p.presets.seedPrint, NS.Presets.Fingerprint(p.containers, p.containerOrder), "re-recorded")
    local q = oldProfile("simple@1200")
    q.presets = { seedPrint = 12345 }
    NS.Database.RestackPresets(q, OWN_W, OWN_H)
    assertEqual(q.presets.seedPrint, 12345, "a seed the player had changed stays changed")
end)

test("v23: the ladder runs it over every stored profile on the parent's size", function()
    local saved = { global = { schemaVersion = 22 }, profiles = {} }
    for _, name in ipairs({ "Default", "Parked" }) do
        local p = oldProfile("advanced@1200")
        p.seeded, p.presets = true, { pickerSeen = true }
        saved.profiles[name] = p
    end
    local NSx = fresh({ savedVariables = saved, before = function(m)
        rawset(m.UIParent, "GetWidth", function() return OWN_W end)
        rawset(m.UIParent, "GetHeight", function() return OWN_H end)
    end })
    for _, name in ipairs({ "Default", "Parked" }) do
        local p = NSx.db.sv.profiles[name]
        -- red under: no v23 step, or one that walks the active profile alone
        assertTrue(byName(p, "[09] " .. NS.L["Player buffs, short"]) ~= nil, name .. ": restacked")
        assertEqual(byName(p, "[08] " .. NS.L["Player cooldowns"]).bars.width, 240, name .. ": 266 to 240")
    end
    assertEqual(NSx.db.global.schemaVersion, 23)
    assertNear(OWN_H / 1080 * 240, 266.67, 0.01, "the owner's screen wrote 266 and 267")
end)
