-- tests/test_skinsetup.lua — the LibKa0s-Skin-1.0 seam (core/SkinSetup.lua, skinning-§1, §2, §3).
--
-- What this addon owes the skin engine, and nothing the library pins itself: the owner is
-- registered under the folder name with this addon's read and write seams and its own tokens; the
-- skin.* keys default to Ka0s Default and are skip-render schema rows on General's Appearance group;
-- the Skin tab is last on General; the profile's skin is applied right after AceDB exists and on
-- every profile event; one pick, from this addon's tab or another addon's copy, is ONE effective
-- SetChoice (one OnLooksChanged), however many store writes follow it; and the owner reaches the
-- library factories this addon calls. Every case builds a fresh environment (its own LibStub), so
-- no listener or applied choice leaks between cases.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil
local H = dofile("tests/general_page_helpers.lua")
local general = H.general
local fresh = dofile("tests/fresh_env.lua")

local OWNER = "AuraMaster"

--- A fresh environment, its Skin major, and a counter of this owner's OnLooksChanged.
local function skinEnv(opts)
    local NS, m = fresh(opts)
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    local n = { looks = 0, reloads = 0 }
    NS.Skin.OnLooksChanged(function() n.looks = n.looks + 1 end)
    Skin:OnReloadRequest(OWNER, function() n.reloads = n.reloads + 1 end)
    return NS, m, Skin, n
end

--- Run `fn` with chat silenced.
local function quietly(m, fn)
    local cf = m.DEFAULT_CHAT_FRAME
    local add = rawget(cf, "AddMessage")
    rawset(cf, "AddMessage", function() end)
    local ok, err = pcall(fn)
    rawset(cf, "AddMessage", add)
    if not ok then error(err, 0) end
end

-- ── the owner ────────────────────────────────────────────────────────────────────────────────

test("Skin seam: the owner is the folder name, and NS.Skin is its facade", function()
    local NS, _, Skin = skinEnv()
    -- red under: registering under the brand or a typo (the library keys every frame and every
    -- listener by owner), or publishing a facade of some other owner.
    assertTrue(Skin:IsOwner(OWNER), "core/SkinSetup.lua did not register the owner")
    assertTrue(rawequal(NS.Skin, Skin:For(OWNER)), "NS.Skin is not Skin:For(\"AuraMaster\")")
    assertEqual(NS.Skin.owner, OWNER)
    assertEqual(Skin:OwnerLabel(OWNER), "Ka0s Aura Master", "the copy confirmation names the addon by its brand")
end)

test("Skin seam: the read answers Ka0s Default before the profile store exists", function()
    -- RegisterOwner calls `get` at FILE LOAD, before NS:InitDB; a getter that raised there would be a
    -- visible Lua error on every login.
    local NS = skinEnv()
    local db = NS.db
    NS.db = nil
    local ok, source, skin = pcall(NS.SkinChoice)
    local okO, font, texture = pcall(NS.SkinOverride)
    NS.db = db
    assertTrue(ok, "NS.SkinChoice raised without a store: " .. tostring(source))
    assertEqual(source, "ka0s")
    assertEqual(skin, "ka0s")
    assertTrue(okO, "NS.SkinOverride raised without a store")
    assertEqual(font, false)
    assertEqual(texture, false)
end)

test("Skin seam: every owner token draws today's color on Ka0s Default, and follows a library role", function()
    -- skinning-§1 (owner tokens), decisions X1, X2, X12: the exact value drawn today, a name in the
    -- addon's own namespace, a follow that is a library color token every skin resolves.
    local NS, _, Skin = skinEnv()
    local base = Skin:ResolveSkin("ka0s")
    local n = 0
    for name, def in pairs(NS.SKIN_TOKENS) do
        n = n + 1
        assertEqual(name:sub(1, 3), "am.", name .. ": the owner's namespace")
        local r, g, b, a = NS.Skin.Color(name)
        assertTrue(r ~= nil, name .. ": the library refused the owner token")
        local want = def.default
        for i, v in ipairs({ r, g, b, a }) do
            assertTrue(math.abs(v - (want[i] or 1)) < 1e-6, ("%s[%d]: %s, today %s"):format(name, i, v, want[i] or 1))
        end
        assertTrue(type(base[def.follow]) == "table", name .. " follows " .. tostring(def.follow) .. ", not a library color")
    end
    assertTrue(n >= 9, "the owner tokens are missing")
end)

test("Skin seam: the owner tokens draw on Ka0s Default the pixels the surfaces drew before AM-02", function()
    -- The constants the surfaces read before they read the tokens (C.ATTACHED_NAME_COLOR,
    -- C.SNAP_COLOR, C.DETACH_COLOR, C.SECONDARY_GOLD) are gone; their values are pinned here, so the
    -- switch moved nothing on Ka0s Default. An "aarrggbb" string or an { r, g, b } triple.
    local NS = skinEnv()
    local function channels(c)
        if type(c) == "string" then
            return tonumber(c:sub(3, 4), 16) / 255, tonumber(c:sub(5, 6), 16) / 255, tonumber(c:sub(7, 8), 16) / 255
        end
        return c[1], c[2], c[3]
    end
    for name, c in pairs({
        ["am.attachedName"] = "ff8c8a84",
        ["am.attach"]       = { 0.25, 0.90, 0.35 },
        ["am.detach"]       = { 0.95, 0.25, 0.25 },
        ["am.goldMuted"]    = "ffd9b861",
        ["am.pick"]         = { 0.2, 0.8, 1 },
    }) do
        local r, g, b = NS.SkinColor(name)
        local cr, cg, cb = channels(c)
        for i, pair in ipairs({ { r, cr }, { g, cg }, { b, cb } }) do
            assertTrue(math.abs(pair[1] - pair[2]) < 1e-6, ("%s[%d]: token %s, before %s"):format(name, i, pair[1], pair[2]))
        end
    end
end)

test("Skin seam: SkinEscape rounds a token back to the byte the markup wrote", function()
    local NS = skinEnv()
    assertEqual(NS.SkinEscape("am.note"), "|cff888888")
    assertEqual(NS.SkinEscape("am.noteAlt"), "|cffbbbbbb")
    assertEqual(NS.SkinEscape("am.planWarn"), "|cffffa040")
    assertEqual(NS.SkinEscape("am.link"), "|cff6699ff")
    assertNil(NS.SkinEscape("no.such"), "a token the skin leaves alone answers nil")
end)

-- ── the keys and the rows ────────────────────────────────────────────────────────────────────

test("Skin seam: the skin keys default to Ka0s Default, as skip-render rows of General's Appearance group", function()
    local NS = skinEnv()
    local d = NS.defaults.profile.skin
    -- red under: a default other than today's look, or the Scope's owner call (panel ignored, fonts
    -- skinned) moved; pickerSeen false on every profile (O3).
    assertEqual(d.source, "ka0s")
    assertEqual(d.skin, "ka0s")
    assertEqual(d.ignorePanel, true)
    assertEqual(d.ignoreFonts, false)
    assertEqual(d.font, "")
    assertEqual(d.texture, "")
    assertEqual(d.pickerSeen, false)
    for _, key in ipairs({ "source", "skin", "ignorePanel", "ignoreFonts", "font", "texture", "pickerSeen" }) do
        local path = "skin." .. key
        local row = NS.FindSchemaRow(path)
        assertTrue(row ~= nil, path .. " is not a schema row")
        assertEqual(row.page, "general", path .. ": page")
        assertEqual(row.group, "Appearance", path .. ": group")
        assertTrue(row.skipRender == true, path .. ": the tab draws it, so it must be skipRender")
        assertEqual(row.effect, "none", path .. ": a skin write re-applies no container")
    end
end)

test("Skin seam: the skin row's values are every registered skin, in the library's order", function()
    local NS, _, Skin = skinEnv()
    local values = NS.FindSchemaRow("skin.skin").values
    local skins = Skin:Skins()
    assertEqual(#values, #skins, "one value per registered skin")
    for i, def in ipairs(skins) do assertEqual(values[i].value, def.key, "value " .. i) end
    assertEqual(values[1].value, "ka0s", "Ka0s Default first")
end)

test("Skin seam: /am set refuses a skin that is not registered and applies one that is", function()
    local NS, m, Skin, n = skinEnv()
    quietly(m, function()
        NS.Slash:OnSlash("set skin.skin no-such-skin")
        assertEqual(NS.db.profile.skin.skin, "ka0s", "an unknown skin was stored")
        assertEqual(n.looks, 0, "a refused set repainted")
        NS.Slash:OnSlash("set skin.skin obsidian")
    end)
    assertEqual(NS.db.profile.skin.skin, "obsidian", "a registered skin was refused")
    local _, applied = Skin:GetChoice(OWNER)
    assertEqual(applied, "obsidian", "a bare set must move the applied skin (the row's onChange)")
    assertEqual(n.looks, 1, "one set, one repaint")
end)

test("Skin seam: /am set reaches an exception and an override, each only its own half", function()
    local NS, m, Skin = skinEnv()
    quietly(m, function()
        NS.Slash:OnSlash("set skin.ignoreFonts true")
        NS.Slash:OnSlash("set skin.font Oxanium")
    end)
    local panel, fonts = Skin:GetIgnore(OWNER)
    assertEqual(fonts, true, "the exception applied")
    assertEqual(panel, true, "the other half untouched")
    local font, texture = Skin:GetOverride(OWNER)
    assertEqual(font, "Oxanium", "the font override applied")
    assertNil(texture, "the texture override untouched")
    assertEqual(NS.db.profile.skin.font, "Oxanium")
end)

-- ── the write seam ───────────────────────────────────────────────────────────────────────────

test("Skin seam: another addon's copy to every Ka0s addon repaints AuraMaster once", function()
    -- The library's copy calls SetChoice for this owner, then WriteChoice, which reaches this addon's
    -- registered setter (NS.WriteSkinChoice); each row's onChange then finds its half applied.
    -- red under: an onChange that re-applies the whole stored pair (two repaints, the first to a
    -- half-written skin), or a seam that writes the profile around NS.SetByPath.
    local NS, _, Skin, n = skinEnv()
    local seen = {}
    local set = NS.SetByPath
    NS.SetByPath = function(path, ...) seen[#seen + 1] = path; return set(path, ...) end
    Skin:SetChoice(OWNER, "ka0s", "ember")
    Skin:SetIgnore(OWNER, false, true)
    Skin:SetOverride(OWNER, "Oxanium", false)
    local okW = Skin:WriteChoice(OWNER, "ka0s", "ember", { panel = false, fonts = true }, { font = "Oxanium", texture = false })
    NS.SetByPath = set
    assertTrue(okW, "the copy's write did not reach this addon's setter")
    assertEqual(n.looks, 3, "one repaint each for the skin, the exceptions and the overrides, none for the writes")
    local p = NS.db.profile.skin
    assertEqual(p.skin, "ember", "the copy did not land in the profile")
    assertEqual(p.ignorePanel, false)
    assertEqual(p.ignoreFonts, true)
    assertEqual(p.font, "Oxanium")
    assertEqual(p.texture, "", "false is stored as the skin's own")
    assertEqual(table.concat(seen, ","),
        "skin.source,skin.skin,skin.ignorePanel,skin.ignoreFonts,skin.font,skin.texture",
        "every half goes through the one write seam")
end)

-- ── the tab ──────────────────────────────────────────────────────────────────────────────────

test("Skin seam: General's Skin tab is last (the page has no Keybindings tab)", function()
    local _, _, P = general()
    local keys = P.tabKeys("general")
    -- skinning-§3: the library's O.AppearanceTab, keyed by the Appearance group, labeled Skin.
    assertEqual(keys[#keys], "Appearance")
end)

test("Skin seam: one tab pick is one effective SetChoice, one repaint and no reload", function()
    local NS, m, P = general()
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    local looks, reloads = 0, 0
    NS.Skin.OnLooksChanged(function() looks = looks + 1 end)
    Skin:OnReloadRequest(OWNER, function() reloads = reloads + 1 end)
    local ws = P.tab("general", "Appearance")
    local cb
    for _, w in ipairs(ws) do
        if w.type == "CheckBox" and tostring(w.labelText or ""):sub(-#"Obsidian") == "Obsidian" then cb = w end
    end
    assertTrue(cb ~= nil, "the Skin tab drew no Obsidian choice")
    cb:SetValue(true); cb:__fire("OnValueChanged", true)
    assertEqual(looks, 1, "one pick must repaint exactly once")
    assertEqual(reloads, 0, "a Ka0s-to-Ka0s pick asks for no reload")
    local source, skin = Skin:GetChoice(OWNER)
    assertEqual(source, "ka0s")
    assertEqual(skin, "obsidian", "the pick did not move the applied skin")
end)

-- ── the profile events ───────────────────────────────────────────────────────────────────────

test("Skin seam: the profile's stored skin, exceptions and overrides are applied at login", function()
    -- addon:OnInitialize calls NS.ApplySkinChoice() right after NS:InitDB.
    -- red under: no apply at all (the owner stays on the Ka0s Default it registered with), or the
    -- stored pair applied without the exceptions or the overrides.
    local NS, _, Skin = skinEnv({ savedVariables = {
        profiles = { Default = { seeded = true, skin = {
            source = "ka0s", skin = "glass", ignorePanel = false, ignoreFonts = true, font = "Oxanium",
        } } },
        global = { schemaVersion = 1 },
    } })
    assertEqual(NS.db:GetCurrentProfile(), "Default")
    local _, skin = Skin:GetChoice(OWNER)
    assertEqual(skin, "glass", "the stored skin was not applied")
    local panel, fonts = Skin:GetIgnore(OWNER)
    assertEqual(panel, false, "the stored panel exception")
    assertEqual(fonts, true, "the stored fonts exception")
    assertEqual((Skin:GetOverride(OWNER)), "Oxanium", "the stored font override")
end)

test("Skin seam: a profile switch, copy and reset each apply that profile's skin", function()
    local NS, _, Skin, n = skinEnv()
    local db = NS.db
    db:SetProfile("SkinProbe")
    NS.SetByPath("skin.skin", "glass")
    db:SetProfile("Default")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "ka0s", "back on Default, Default's skin")
    n.looks = 0
    db:SetProfile("SkinProbe")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "glass", "the switch did not move the applied skin")
    assertEqual(n.looks, 1, "one switch, one repaint")
    db:ResetProfile()
    assertEqual(select(2, Skin:GetChoice(OWNER)), "ka0s", "a reset goes back to Ka0s Default")
    db:SetProfile("Default")
    db:CopyProfile("SkinProbe")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "ka0s", "a copy applies the copied skin")
end)

-- ── the owner, handed to the factories ───────────────────────────────────────────────────────

test("Skin seam: NS.ApplySkin hands the library this addon's owner", function()
    local NS, m = skinEnv()
    local lib = m.LibStub("LibKa0s-Core-1.0")
    local real, got = lib.ApplySkin, nil
    lib.ApplySkin = function(_, _, owner) got = owner end
    NS.ApplySkin({}, nil)
    lib.ApplySkin = real
    assertEqual(got, OWNER, "a factory that takes an owner is given one (skinning-§1)")
end)

test("Skin seam: the drag strip is built for this addon's owner", function()
    -- DragHandle minor 6: the strip's fill, label and marks read the owner's skin; without `owner`
    -- they stay Ka0s Default's under every skin.
    local NS, m = skinEnv()
    local KW = m.LibStub("LibKa0s-Widgets-1.0")
    local real, got = KW.DragHandle, nil
    KW.DragHandle = function(anchor, spec) got = spec and spec.owner; return real(anchor, spec) end
    local ok, err = pcall(NS.Anchors.BuildHandle, NS.ContainerManager.instances[1])
    KW.DragHandle = real
    if not ok then error(err, 0) end
    assertEqual(got, OWNER)
end)
