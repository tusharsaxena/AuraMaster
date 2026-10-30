-- tests/test_skin_outline.lua — the Font outline (LibKa0s v1.82.0, Skin minor 9; AM-01 of
-- Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-06): stored as skin.outline
-- ("all", the default, "hud", "off"), written only through the skin write seam (NS.WriteSkinChoice's
-- `media.outline`, the Skin tab's and another addon's copy), and applied with Skin:SetOutline at
-- load, on every profile event and on the row's own write. LibKa0sSkinTester 7d736c2 is the
-- reference.

local T = _G.AM_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local fresh = dofile("tests/fresh_env.lua")
local degraded = dofile("tests/degraded_env.lua")

local OWNER = "AuraMaster"

local function lib(mocks) return mocks.LibStub("LibKa0s-Skin-1.0") end

test("outline: a fresh profile stores All text, the library's default, and applies it", function()
    local NS, mocks = fresh()
    assertEqual(NS.db.profile.skin.outline, "all")
    assertEqual(NS.db.profile.skin.outline, lib(mocks).OUTLINE_DEFAULT)
    assertEqual(lib(mocks):GetOutline(OWNER), "all")
    assertEqual(NS.SkinOutline(), "all")
end)

test("outline: the schema row offers the library's three modes, in its order, drawn by the Skin tab", function()
    local NS, mocks = fresh()
    local row = NS.FindSchemaRow("skin.outline")
    -- red under: no row (/am set skin.outline could not reach it, and no reset would)
    assertTrue(row ~= nil, "a skin.outline row")
    assertTrue(row.skipRender == true, "the Skin tab draws it")
    assertEqual(row.effect, "none", "a skin write re-applies no container")
    local got = {}
    for _, opt in ipairs(row.values) do got[#got + 1] = opt.value end
    assertEqual(table.concat(got, ","), table.concat(lib(mocks).OUTLINE_MODES, ","))
end)

test("outline: the write seam stores media.outline, and leaves it alone when it is nil", function()
    -- red under: WriteSkinChoice dropping media.outline (the Skin tab's Font outline and the copy
    -- would move the look and never store it).
    local NS = fresh()
    NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false, outline = "hud" })
    assertEqual(NS.db.profile.skin.outline, "hud")
    NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false })
    assertEqual(NS.db.profile.skin.outline, "hud", "a media without outline leaves it")
    NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false, outline = "off" })
    assertEqual(NS.db.profile.skin.outline, "off")
end)

test("outline: another addon's copy reaches the store through WriteChoice", function()
    local NS, mocks = fresh()
    lib(mocks):WriteChoice(OWNER, "ka0s", "ember", nil, { font = false, texture = false, outline = "off" })
    assertEqual(NS.db.profile.skin.outline, "off")
end)

test("outline: the row's write applies the mode live, and the HUD's From skin flags follow it", function()
    local NS, mocks = fresh()
    NS.SetByPath("skin.outline", "hud")
    assertEqual(lib(mocks):GetOutline(OWNER), "hud")
    assertEqual(NS.Skin.Token("font.outline"), "", "window text loses its outline")
    assertEqual(NS.Skin.Token("hud.outline"), "OUTLINE", "the HUD keeps it")
    local D = NS.CONTAINER_TEMPLATE
    assertEqual(select(3, NS.Style.FontKey({ fontFlags = "@skin" }, D.bars.name)), "OUTLINE")
    NS.SetByPath("skin.outline", "off")
    assertEqual(NS.Skin.Token("hud.outline"), "", "Off takes both")
    -- red under: Style.FontKey drawing "@skin" through FLAG_MAP (as an unknown flag) and not S.FontFlags
    assertEqual(select(3, NS.Style.FontKey({ fontFlags = "@skin" }, D.bars.name)), "", "From skin: none")
    assertEqual(select(3, NS.Style.FontKey({ fontFlags = "THICKOUTLINE" }, D.bars.name)), "THICKOUTLINE",
        "a picked flag wins")
    NS.SetByPath("skin.outline", "all")
    assertEqual(NS.Skin.Token("font.outline"), "OUTLINE")
end)

test("outline: /am set refuses a mode the library does not know", function()
    local NS = fresh()
    NS.Slash:OnSlash("set skin.outline thick")
    assertEqual(NS.db.profile.skin.outline, "all")
end)

test("outline: the stored mode is applied at load", function()
    -- red under: ApplySkinChoice's whole-pair path not applying the stored outline.
    local first = fresh()
    first.SetByPath("skin.outline", "off")
    local sv = _G.AuraMasterDB
    local _, mocks = fresh({ savedVariables = sv })
    assertEqual(lib(mocks):GetOutline(OWNER), "off")
end)

test("outline: a profile switch applies the incoming profile's mode, and back", function()
    local NS, mocks = fresh()
    NS.SetByPath("skin.outline", "hud")
    NS.db:SetProfile("Alt")
    assertEqual(lib(mocks):GetOutline(OWNER), "all", "Alt keeps the default")
    NS.db:SetProfile("Default")
    assertEqual(lib(mocks):GetOutline(OWNER), "hud", "Default's is back")
end)

test("outline: without LibKa0s the apply is a quiet no-op and From skin draws OUTLINE", function()
    local NS2 = degraded()
    assertEqual(NS2.ApplySkinOutline(), false)
    assertEqual(NS2.Skin.FontFlags("@skin"), "OUTLINE")
    assertEqual(NS2.Skin.FontFlags(nil), "OUTLINE")
    assertEqual(NS2.Skin.FontFlags(""), "", "a picked None stays")
    assertEqual(NS2.Skin.HudFontSize(36, true), 36, "never scaled without the library")
    assertEqual(NS2.Skin.HudFontSize(nil), 12)
end)
