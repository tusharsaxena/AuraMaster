-- tests/test_clients.lua — the client seam (core/Compat.lua, clients-§3) and the default skin per
-- client (core/SkinSetup.lua, skinning-§2). Every case asserts against the ACTIVE kit profile
-- (`KA0S_KIT_CLIENT=retail|forever`, retail the default), so the same suite answers both ways and a
-- run under each profile is the per-client test clients-§6 asks for.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")

local PROFILE = os.getenv("KA0S_KIT_CLIENT") or "retail"
local IS_FOREVER = PROFILE == "forever"
-- The skin a new profile wears on this profile's client (LibKa0s Skin.CLIENT_DEFAULTS).
local CLIENT_SKIN = IS_FOREVER and "forever" or "ka0s"

local env
local function E()
    if not env then env = fresh({ clientSkin = true }) end
    return env
end

-- ── the client questions ─────────────────────────────────────────────────────────────────────

test("clients: ClientKey names the kit profile's client", function()
    local NS = E()
    -- red under: a ClientKey that answers a constant, or one not routed to LibKa0s-Compat-1.0
    assertEqual(NS.Compat.ClientKey(), PROFILE)
end)

test("clients: IsForever and IsRetail answer the kit profile's client, exactly one true", function()
    local NS = E()
    assertEqual(NS.Compat.IsForever(), IS_FOREVER, "IsForever")
    assertEqual(NS.Compat.IsRetail(), not IS_FOREVER, "IsRetail")
end)

test("clients: ForClient serves a Retail-only declaration on retail only, and nil on both", function()
    local NS = E()
    -- red under: ForClient ignoring the declaration, or a nil that means neither client
    assertEqual(NS.Compat.ForClient({ "retail" }), not IS_FOREVER, "{ retail }")
    assertEqual(NS.Compat.ForClient({ "forever" }), IS_FOREVER, "{ forever }")
    assertTrue(NS.Compat.ForClient(nil), "nil serves both clients")
    assertTrue(NS.Compat.ForClient("both"), "\"both\" serves both clients")
end)

test("clients: without LibKa0s the stand-in answers Retail on either profile", function()
    local NS2 = dofile("tests/degraded_env.lua")()
    -- red under: a stand-in reading WOW_PROJECT_* (clients-§3 keeps that read in the library), or
    -- one answering nil, which would gate every Retail-only feature off a client that is Retail
    assertEqual(NS2.Compat.ClientKey(), "retail")
    assertTrue(NS2.Compat.IsRetail(), "IsRetail")
    assertFalse(NS2.Compat.IsForever(), "IsForever")
    assertTrue(NS2.Compat.ForClient(nil), "nil")
    assertTrue(NS2.Compat.ForClient("both"), "\"both\"")
    assertTrue(NS2.Compat.ForClient({ "retail" }), "{ retail }")
    assertTrue(NS2.Compat.ForClient({ "both" }), "{ both }")
    assertFalse(NS2.Compat.ForClient({ "forever" }), "{ forever }")
    -- an unknown token is a programming error on every client, as the library's is
    assertFalse(pcall(NS2.Compat.ForClient, { "retial" }), "an unknown token raises")
end)

-- ── the default skin ─────────────────────────────────────────────────────────────────────────

test("clients: the default skin is the client's, WoW Forever on forever and Ka0s Default on retail", function()
    local NS = E()
    -- red under: NS.DEFAULT_SKIN not read from Skin:DefaultSkin(), or a fixed "ka0s"
    assertEqual(NS.DEFAULT_SKIN, CLIENT_SKIN)
end)

test("clients: a fresh profile wears the default skin, from the Ka0s source", function()
    local NS = fresh({ clientSkin = true })
    -- red under: defaults/Profile.lua writing the literal "ka0s" as the skin choice
    assertEqual(NS.defaults.profile.skin.skin, NS.DEFAULT_SKIN, "the shipped default")
    assertEqual(NS.db.profile.skin.skin, CLIENT_SKIN, "the stored profile")
    assertEqual(NS.db.profile.skin.source, "ka0s", "the source stays Ka0s's own skins")
    local source, skin = NS.SkinChoice()
    assertEqual(source, "ka0s")
    assertEqual(skin, CLIENT_SKIN)
end)

test("clients: before the profile store exists the read answers the client's default skin", function()
    local NS = fresh({ clientSkin = true })
    local db = NS.db
    NS.db = nil
    local ok, source, skin = pcall(NS.SkinChoice)
    NS.db = db
    assertTrue(ok, "NS.SkinChoice raised without a store: " .. tostring(source))
    assertEqual(source, "ka0s")
    assertEqual(skin, CLIENT_SKIN)
end)

test("clients: without LibKa0s the default skin stays Ka0s Default", function()
    local NS2 = dofile("tests/degraded_env.lua")()
    -- red under: a degraded default naming a skin the degraded facade cannot draw
    assertEqual(NS2.DEFAULT_SKIN, "ka0s")
    assertEqual(NS2.defaults.profile.skin.skin, "ka0s")
    local source, skin = NS2.SkinChoice()
    assertEqual(source, "ka0s")
    assertEqual(skin, "ka0s")
end)
