-- tests/test_pages_profiles.lua — settings/Profiles.lua: which table the page registers, how often
-- it opens the dialog and into what, and when it opts out. That the container it fills is SHOWN is
-- pinned in tests/test_optionssetup.lua.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local pages = dofile("tests/page_helpers.lua")

--- A fresh environment with the three AceConfig libraries faked. `omit` names one to leave out.
local function withProfiles(omit)
    local rec = { opened = {} }
    local NS, m = fresh({ before = function(mk)
        local libs = {
            ["AceDBOptions-3.0"] = { GetOptionsTable = function(_, db)
                rec.db = db
                rec.options = { type = "group", args = {} }
                return rec.options
            end },
            ["AceConfig-3.0"] = { RegisterOptionsTable = function(_, app, options)
                rec.app, rec.registered = app, options
            end },
            ["AceConfigDialog-3.0"] = { Open = function(_, app, container)
                rec.opened[#rec.opened + 1] = { app = app, container = container }
            end },
        }
        for name, lib in pairs(libs) do
            if name ~= omit then mk.__libs[name] = lib end
        end
    end })
    return NS, m, rec
end

test("profiles: the page registers this database's AceDBOptions table under its own app name", function()
    local NS, m, rec = withProfiles()
    local panel = m.__subcategories.Profiles
    assertTrue(panel ~= nil)
    -- red under: the options table built for another database, or registered under another name
    assertTrue(rec.db == NS.db, "the options are this addon's database")
    assertEqual(rec.app, "AuraMaster-Profiles")
    assertTrue(rec.registered == rec.options)
    assertNil(panel.defaultsOnClick, "a profile page has no Defaults: its reset is AceDBOptions' own")
end)

test("profiles: every render re-opens the dialog into the one container it built", function()
    local NS, m, rec = withProfiles()
    local P = pages(NS, m)
    local first = P.show("Profiles")
    P.rerender("Profiles")
    -- red under: opening only on the first show (a switched profile draws stale), or a fresh
    -- AceGUI group per render (one leaked per show)
    assertEqual(#rec.opened, 2)
    assertTrue(rec.opened[1].container == rec.opened[2].container)
    assertEqual(#P.all(first, "SimpleGroup"), 1, "one container, created on the first show")
end)

test("profiles: without AceConfigDialog the page opts out instead of failing on first show", function()
    local _, m = withProfiles("AceConfigDialog-3.0")
    -- red under: dropping AceConfigDialog from the builder's guard
    assertNil(m.__subcategories.Profiles)
end)
