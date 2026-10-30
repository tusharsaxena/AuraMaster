-- tests/test_skin_flags.lua — the font settings minimum set with From skin flags, and the HUD size
-- scale (LibKa0s v1.82.0; AM-01 of Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK,
-- rulings D-07 and D-09, Addendum 01).
--
-- Every text block's font setting is the library's FontGroup{ fromSkin, flagsFromSkin }: face with
-- "Use the skin's font", size, color with class color, flags led by From skin ("@skin", the default),
-- and shadow. Style.FontKey draws From skin through S.FontFlags (the Skin tab's Font outline) and a
-- picked flag as picked. Schema v14 moves a stored flag equal to the old default ("OUTLINE") onto From
-- skin, once, in every profile; any other flag counts as the player's pick and stays. While a block
-- uses the skin's face it draws at S.HudFontSize(stored), the stored size scaled by the skin's HUD size;
-- the stored value is never rewritten.

local T = _G.AM_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local fresh = dofile("tests/fresh_env.lua")

local FROM_SKIN = "@skin"

--- The table at container-relative `path` inside `c`, or nil.
local function block(c, path)
    local t = c
    for seg in path:gmatch("[^%.]+") do
        t = type(t) == "table" and t[seg] or nil
    end
    return t
end

--- A v13 profile: two containers whose text blocks store the old default flags, and one pick each.
local function v13profile()
    local function font(flags) return { font = "Friz Quadrata TT", fontSize = 12, fontFlags = flags } end
    return {
        containers = {
            [1] = { name = "Bars", style = "bars",
                bars = { name = font("OUTLINE"), time = font("THICKOUTLINE"), stacks = font("OUTLINE") },
                label = { font = font("OUTLINE") } },
            [2] = { name = "Text", style = "text",
                text = { font = font("MONOCHROME") }, icons = { time = font(""), stacks = font("OUTLINE") } },
        },
    }
end

-- ── the rows ─────────────────────────────────────────────────────────────────────────────────

test("skin flags: every font block's setting is the minimum set, its flags led by From skin", function()
    local NS = fresh()
    for _, path in ipairs(NS.Database.FLAG_BLOCKS) do
        local p = "container." .. path .. "."
        for _, leaf in ipairs({ "font", "fontFromSkin", "fontSize", "fontColor", "useClassColorFont",
            "fontFlags", "fontShadow" }) do
            assertTrue(NS.FindSchemaRow(p .. leaf) ~= nil, p .. leaf .. " has no row")
        end
        local row = NS.FindSchemaRow(p .. "fontFlags")
        -- red under: a FontGroup without `flagsFromSkin = true` (the old list, OUTLINE by default)
        assertEqual(row.default, FROM_SKIN, path .. ": From skin is the default")
        assertTrue(row.values[FROM_SKIN] ~= nil, path .. ": From skin is offered")
        assertEqual(row.sorting[1], FROM_SKIN, path .. ": and offered first")
        assertEqual(block(NS.CONTAINER_TEMPLATE, path).fontFlags, FROM_SKIN, path .. ": the template's")
    end
end)

test("skin flags: /am set takes From skin and a picked flag, and the HUD draws each", function()
    local NS = fresh()
    assertTrue(NS.SetByPath("container.bars.name.fontFlags", "THICKOUTLINE", 1))
    local D = NS.CONTAINER_TEMPLATE
    local c = NS.Database.FindContainer(1)
    assertEqual(select(3, NS.Style.FontKey(c.bars.name, D.bars.name)), "THICKOUTLINE", "picked wins")
    assertTrue(NS.SetByPath("container.bars.name.fontFlags", FROM_SKIN, 1))
    assertEqual(select(3, NS.Style.FontKey(c.bars.name, D.bars.name)), "OUTLINE", "All text: OUTLINE")
end)

-- ── schema v14 ───────────────────────────────────────────────────────────────────────────────

test("skin flags: v14 moves the old default OUTLINE onto From skin in every profile, keeping each pick", function()
    local NS = fresh({ savedVariables = { profiles = { Default = v13profile(), Raid = v13profile() },
        global = { schemaVersion = 13 } } })
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
    -- Raid is never activated in this load, so what it holds is the step's alone.
    for _, name in ipairs({ "Default", "Raid" }) do
        local cs = NS.db.sv.profiles[name].containers
        -- red under: no v14 step, or one that runs on the active profile alone
        assertEqual(cs[1].bars.name.fontFlags, FROM_SKIN, name .. ": the old default moves")
        assertEqual(cs[1].bars.stacks.fontFlags, FROM_SKIN, name)
        assertEqual(cs[1].label.font.fontFlags, FROM_SKIN, name)
        assertEqual(cs[2].icons.stacks.fontFlags, FROM_SKIN, name)
        -- red under: a step that moves every flag (a player's pick is not the old default)
        assertEqual(cs[1].bars.time.fontFlags, "THICKOUTLINE", name .. ": a pick stays")
        assertEqual(cs[2].text.font.fontFlags, "MONOCHROME", name)
        assertEqual(cs[2].icons.time.fontFlags, "", name .. ": a picked None stays")
    end
end)

test("skin flags: v14 runs once, so an OUTLINE the player picks afterwards stays OUTLINE", function()
    local NS = fresh({ savedVariables = { profiles = { Default = v13profile() }, global = { schemaVersion = 13 } } })
    assertTrue(NS.SetByPath("container.bars.name.fontFlags", "OUTLINE", 1), "the panel's write")
    local NS2 = fresh({ savedVariables = _G.AuraMasterDB })
    assertEqual(NS2.Database.FindContainer(1).bars.name.fontFlags, "OUTLINE")
end)

test("skin flags: the v14 body leaves an absent block and an absent flag alone", function()
    local NS = fresh()
    local p = { containers = { [1] = { bars = { name = { fontSize = 12 } } }, [2] = "junk" } }
    assertEqual(NS.Database.MigrateV14(p), 0)
    assertEqual(p.containers[1].bars.name.fontFlags, nil)
    assertTrue(p.containers[1].icons == nil, "no block created")
    assertEqual(NS.Database.MigrateV14(nil), 0)
end)

-- ── the HUD size scale (D-09) ────────────────────────────────────────────────────────────────

test("skin flags: a block on the skin's face stored at 12 draws at 13 under Obsidian; its own face, and Ignore fonts, at 12", function()
    local NS, mocks = fresh()
    local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
    local D = NS.CONTAINER_TEMPLATE
    local t = { font = "Friz Quadrata TT", fontFromSkin = true, fontSize = 12, fontFlags = FROM_SKIN }
    assertEqual(select(2, NS.Style.FontKey(t, D.bars.name)), 12, "Ka0s Default is the baseline")
    NS.SetByPath("skin.skin", "obsidian")
    -- red under: Style.FontKey drawing the stored size (Obsidian's face is wider at 12)
    assertEqual(select(2, NS.Style.FontKey(t, D.bars.name)), 13, "scaled by Obsidian's HUD size")
    assertEqual(t.fontSize, 12, "the stored size is never rewritten")
    t.fontFromSkin = false
    assertEqual(select(2, NS.Style.FontKey(t, D.bars.name)), 12, "its own face: as stored")
    t.fontFromSkin = true
    Skin:SetIgnore("AuraMaster", nil, true)
    assertEqual(select(2, NS.Style.FontKey(t, D.bars.name)), 12, "Ignore fonts: as stored")
    Skin:SetIgnore("AuraMaster", nil, false)
    assertEqual(NS.Database.FindContainer(1).bars.name.fontSize, D.bars.name.fontSize, "no stored size moved")
end)
