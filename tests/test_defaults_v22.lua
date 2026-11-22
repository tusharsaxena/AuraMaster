-- tests/test_defaults_v22.lua -- the owner's override of 2026-11-22: six colors keep their own values
-- under every skin (SF-AM-2's background and SF-AM-3, restored over U-8, U-9 and R-2). Schema v21, which
-- put them on the skin, is retired; v22 takes back what it wrote (Database.RestoreOwnColors).
-- A collection-wide follow-the-skin pass does not change these pins: only the owner naming them does.

local T = _G.AM_TEST
local test, assertEqual, assertNil = T.test, T.assertEqual, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local R = dofile("tests/region_recorder.lua")

local OWN = {
    "bars.barColorFromSkin", "bars.bgColorFromSkin", "bars.iconBorderColorFromSkin",
    "icons.borderColorFromSkin", "text.iconBorderColorFromSkin", "text.font.fontColorFromSkin",
}

local function at(t, path)
    for seg in path:gmatch("[^%.]+") do
        if type(t) ~= "table" then return nil end
        t = t[seg]
    end
    return t
end

local function put(t, path, v)
    local parent, leaf = path:match("^(.*)%.([^%.]+)$")
    at(t, parent)[leaf] = v
end

--- A stored container with all six companions at `on`, beside the template's colors.
local function container(NS, on)
    local c = NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE)
    for _, path in ipairs(OWN) do put(c, path, on) end
    return c
end

local function profile(c, moved)
    return { seeded = true, nextContainerId = 2, containerOrder = { 1 }, containers = { [1] = c },
        skin = { fullSkinReset = true, defaultsFollow = moved or nil } }
end

test("v22: the six colors default off the skin, in the template and on the rows (owner 2026-11-22)", function()
    local NS = fresh()
    for _, path in ipairs(OWN) do
        -- red under: any pass flipping one onto the skin (the regression of 99b5b02)
        assertEqual(at(NS.CONTAINER_TEMPLATE, path), false, path)
        assertEqual(NS.FindSchemaRow("container." .. path).default, false, path .. " row default agrees")
    end
end)

test("v22: every preset, in each look, stores the six off the skin", function()
    local NS = fresh({ clientSkin = true })
    NS.Helpers.SkinPicker = function() return nil end
    for _, name in ipairs({ "simple", "intermediate", "advanced", "healer" }) do
        for _, look in ipairs({ "bars", "icons" }) do
            NS.Presets.Apply(name, look, "replace")
            for _, c in ipairs(NS.Database.GetContainers()) do
                for _, path in ipairs(OWN) do
                    -- red under: a preset's containers born following the skin
                    assertEqual(at(c, path), false, name .. "/" .. look .. " " .. c.name .. " " .. path)
                end
            end
        end
    end
end)

test("v22: a default bar draws blue on a dark background under WoW Forever's skin", function()
    local NS, mocks = fresh()
    mocks.LibStub("LibKa0s-Skin-1.0"):SetChoice("AuraMaster", "ka0s", "forever")
    mocks.__fireTimers()
    local frame, c = R(), NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE)
    NS.Style.Element(frame, c, false)
    for k in pairs(frame.__am) do frame.__am[k] = R() end
    NS.Style.Element(frame, c, false)
    local function drew(region)
        local v = { unpack(frame.__am[region]:__last("SetVertexColor")) }
        return ("%.2f,%.2f,%.2f"):format(v[1], v[2], v[3])
    end
    -- red under: the skin's brown bar.fill, which is what the owner saw
    assertEqual(drew("fill"), "0.20,0.55,0.95", "the fill")
    assertEqual(drew("bg"), "0.00,0.00,0.00", "the background")
end)

test("v22: an account still at v20 is never put on the skin, in any profile", function()
    local NS0 = fresh()
    local NS = fresh({ savedVariables = { global = { schemaVersion = 20 }, profiles = {
        Default = profile(container(NS0, false)), Parked = profile(container(NS0, false)),
    } } })
    for _, name in ipairs({ "Default", "Parked" }) do
        local p = NS.db.sv.profiles[name]
        -- red under: v21 still moving, at the ladder or from PrepareProfile
        for _, path in ipairs(OWN) do assertEqual(at(p.containers[1], path), false, name .. " " .. path) end
        assertNil(p.skin.defaultsFollow, name)
    end
end)

test("v22: a profile v21 moved gets its six back, active or parked", function()
    local NS0 = fresh()
    local NS = fresh({ savedVariables = { global = { schemaVersion = 21 }, profiles = {
        Default = profile(container(NS0, true), true), Parked = profile(container(NS0, true), true),
    } } })
    for _, name in ipairs({ "Default", "Parked" }) do
        local p = NS.db.sv.profiles[name]
        -- red under: no restore, or one that walks the active profile alone
        for _, path in ipairs(OWN) do assertEqual(at(p.containers[1], path), false, name .. " " .. path) end
        assertNil(p.skin.defaultsFollow, name .. " the retired record is cleared")
    end
    assertEqual(NS.db.global.schemaVersion, 22)
end)

test("v22: only what v21 could have written moves back, and once", function()
    local NS = fresh()
    local picked = container(NS, true)
    picked.bars.barColor = { r = 0.9, g = 0.1, b = 0.1, a = 1 }
    local partial = { bars = { barColorFromSkin = true, bgColorFromSkin = true, bgColor = { r = 0 } } }
    local other = { bars = { borderColorFromSkin = true }, text = { glowColorFromSkin = true } }
    local p = { skin = { defaultsFollow = true }, containers = { picked, partial, other } }
    assertEqual(NS.Database.RestoreOwnColors(p), 5 + 2)
    -- red under: a companion ticked beside a color v21 never moved, switched off
    assertEqual(picked.bars.barColorFromSkin, true)
    assertEqual(picked.bars.bgColorFromSkin, false)
    assertEqual(partial.bars.barColorFromSkin, false, "no swatch stored draws the template's")
    assertEqual(partial.bars.bgColorFromSkin, false, "a missing channel takes the template's")
    assertEqual(other.bars.borderColorFromSkin, true, "not one of the six")
    assertEqual(other.text.glowColorFromSkin, true, "not one of the six")
    picked.bars.bgColorFromSkin = true
    -- red under: a step that undoes the player's own tick afterwards
    assertEqual(NS.Database.RestoreOwnColors(p), 0)
    assertEqual(picked.bars.bgColorFromSkin, true)
end)

test("v22: a profile v21 never reached keeps the player's ticks", function()
    local NS = fresh()
    local c = container(NS, true)
    -- red under: a restore that is not gated on v21's record
    assertEqual(NS.Database.RestoreOwnColors({ skin = {}, containers = { c } }), 0)
    for _, path in ipairs(OWN) do assertEqual(at(c, path), true, path) end
end)
