-- tests/test_pages_about.lua — settings/About.lua, the landing page's body: the command list, the
-- Notes line and the logo, and when each is read.

local T = _G.AM_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local fresh = dofile("tests/fresh_env.lua")
local pages = dofile("tests/page_helpers.lua")

local function landing(NS, m)
    local P = pages(NS, m)
    return P, P.during(function() m.__mainPanel:__fire("OnShow") end)
end

test("about: the landing page lists every slash command, in /am help's own words", function()
    local NS, m = fresh()
    local P, ws = landing(NS, m)
    local rows = NS.Slash:LandingRows()
    assertTrue(#rows >= 20, "the command table has " .. #rows .. " rows")
    local drawn = {}
    for _, t in ipairs(P.texts(ws)) do drawn[t] = true end
    -- red under: a landing list typed out by hand, or a section whose rows skip LandingRows
    for _, row in ipairs(rows) do assertTrue(drawn[row], "missing: " .. row) end
    assertTrue(P.find(ws, nil, NS.L["Slash Commands"]) ~= nil, "under its heading")
end)

test("about: the Notes line is read from this addon's TOC when the page is drawn", function()
    local NS, m = fresh()
    -- Planted AFTER the load: a Notes read at file load would find no reader and draw nothing.
    m.C_AddOns = { GetAddOnMetadata = function(name, field)
        if field == "Notes" then return "Notes of " .. name end
    end }
    local P, ws = landing(NS, m)
    -- red under: SPEC.notes evaluated at declaration, or asked of any folder but this addon's
    assertTrue(P.hasText(ws, "Notes of AuraMaster"))
end)

test("about: the logo is this addon's own art, shipped as a texture the client can load", function()
    local NS = fresh()
    local path = NS.Constants.LOGO_PATH
    -- red under: a logo path pointing outside the folder, or at art that does not ship
    assertEqual(path, "Interface\\AddOns\\AuraMaster\\media\\logos\\auramaster.logo.tga")
    local f = io.open("media/logos/auramaster.logo.tga", "rb")
    assertTrue(f ~= nil, "the .tga ships in media/logos/")
    f:close()
end)
