-- tests/test_skin_glow_restore.lua — schema v15, the owner's own faces back (AM-03 of
-- Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-15; image-36, image-37).
--
-- The skinning rollout's v13 turned "Use the skin's font" on for every stored text block (O2), so the
-- owner's three Text containers stopped drawing their stored Ka0s Kait and drew the skin's HUD face,
-- and the glow behind the text, tuned against Kait, smeared (inputs/inventory/H_AURAMASTER.md 9b: the
-- glow code never changed). v15 turns the companion back OFF, once, in every profile, on every text
-- block whose stored face is a pick of the player's own: a face that is neither the profile's skin's
-- own HUD face nor the template's starting face (Friz Quadrata TT, which no player picked). The stored
-- face, and with it the earlier glow, comes back; the glow code does not change.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")

local KAIT, PROTO, FRIZ = "Ka0s Kait", "Ka0s Prototype", "Friz Quadrata TT"

--- One stored text block, on the skin's face (v13 left every companion on).
local function font(face) return { font = face, fontFromSkin = true, fontSize = 36, fontFlags = "THICKOUTLINE" } end

--- A v14 profile like the owner's: three Text containers on Ka0s Kait with the glow on, one bars
--- container on Ka0s Prototype (Ka0s Default's own HUD face) and Friz Quadrata (the template's), and
--- one block the player already took off the skin. `skin` is the profile's skin key, nil for none
--- stored (Ka0s Default).
local function v14profile(skin)
    local function textC(name)
        return { name = name, style = "text", text = { glow = true, glowThickness = 4, glowX = -4, font = font(KAIT) },
            label = { font = font(FRIZ) } }
    end
    return {
        skin = skin and { skin = skin } or { pickerSeen = true },
        containers = {
            [13] = textC("[4] PLYR TXT Offensive CD"),
            [14] = textC("[5] PLYR TXT Defensive CD"),
            [15] = textC("[6] PLYR TXT Raid CD"),
            [1] = { name = "Bars", style = "bars",
                bars = { name = font(PROTO), time = font(FRIZ), stacks = { font = "Morpheus", fontFromSkin = false } } },
        },
    }
end

--- A v14 account loaded on this build, with a LibSharedMedia stand-in that answers a path for every
--- key ("font:<key>"), so the skin's face and a stored one can be told apart (the harness loads no
--- media library, and every face would otherwise fetch the one fallback).
local function load(profiles)
    return fresh({ savedVariables = { profiles = profiles, global = { schemaVersion = 14 } },
        before = function(m)
            local lsm = setmetatable({ MediaType = { FONT = "font", STATUSBAR = "statusbar", BORDER = "border",
                BACKGROUND = "background", SOUND = "sound" } },
                { __index = function() return function() return {} end end })
            function lsm.Register() return true end
            function lsm.Fetch(_, kind, key) return kind .. ":" .. tostring(key) end
            m.__libs["LibSharedMedia-3.0"] = lsm
        end })
end

test("glow restore: v15 takes the owner's Ka0s Kait picks off the skin's face in every profile", function()
    local NS = load({ Default = v14profile(), Raid = v14profile() })
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
    -- Raid is never activated in this load, so what it holds is the step's alone.
    for _, name in ipairs({ "Raid", "Default" }) do
        local cs = NS.db.sv.profiles[name].containers
        for _, id in ipairs({ 13, 14, 15 }) do
            -- red under: no v15 step, or one gated to the active profile
            assertFalse(cs[id].text.font.fontFromSkin, name .. " #" .. id .. ": Kait is a pick of its own")
            assertEqual(cs[id].text.font.font, KAIT, name .. " #" .. id .. ": the stored face is kept")
            assertTrue(cs[id].label.font.fontFromSkin, name .. " #" .. id .. ": the template's Friz still follows")
        end
        -- red under: a step that turns off every companion (the skin's own face is no pick)
        assertTrue(cs[1].bars.name.fontFromSkin, name .. ": Ka0s Prototype is Ka0s Default's own HUD face")
        assertTrue(cs[1].bars.time.fontFromSkin, name .. ": the template's face is no pick")
        assertFalse(cs[1].bars.stacks.fontFromSkin, name .. ": an off stays off")
        -- Nothing else moves: the glow and the flags are the player's.
        assertEqual(cs[13].text.glowX, -4); assertEqual(cs[13].text.glowThickness, 4)
        assertEqual(cs[13].text.font.fontFlags, "THICKOUTLINE")
        assertEqual(cs[13].text.font.fontSize, 36)
    end
end)

test("glow restore: the Text container then draws Kait at its stored size, and the glow follows it", function()
    local NS = load({ Default = v14profile() })
    local c = NS.Database.FindContainer(13)
    local D = NS.CONTAINER_TEMPLATE.text.font
    local path, size = NS.Style.FontKey(c.text.font, D)
    -- red under: the companion still on (the skin's HUD face, scaled by HudFontSize)
    assertEqual(path, "font:" .. KAIT, "the stored face")
    assertEqual(size, 36, "its own face: the stored size, never scaled")
    assertEqual((NS.Style.Text.GlowFontKey(c.text)), path, "the glow's copies draw the same face, no glow code changed")
end)

test("glow restore: the skin's own HUD face is the profile's skin's, not Ka0s Default's", function()
    local NS = load({ Default = v14profile("obsidian") })
    local cs = NS.db.profile.containers
    -- Obsidian's HUD face is Ka0s Expressway, so a Ka0s Prototype pick is the player's own there.
    assertFalse(cs[1].bars.name.fontFromSkin, "Prototype is not Obsidian's face")
    assertFalse(cs[13].text.font.fontFromSkin, "nor is Kait")
end)

test("glow restore: v15 runs once, so the companion ticked again afterwards stays on", function()
    local NS = load({ Default = v14profile() })
    assertTrue(NS.SetByPath("container.text.font.fontFromSkin", true, 13), "the panel's write")
    local NS2 = fresh({ savedVariables = _G.AuraMasterDB })
    assertTrue(NS2.Database.FindContainer(13).text.font.fontFromSkin, "the player's tick kept")
end)

test("glow restore: the v15 body leaves absent blocks alone and answers how many blocks moved", function()
    local NS = fresh()
    local p = v14profile()
    assertEqual(NS.Database.MigrateV15(p, PROTO), 3, "the three Kait text blocks")
    assertEqual(NS.Database.MigrateV15(p, PROTO), 0, "idempotent")
    assertEqual(NS.Database.MigrateV15({ containers = { [1] = "junk", [2] = { bars = {} } } }, PROTO), 0)
    assertEqual(NS.Database.MigrateV15(nil, PROTO), 0)
end)
