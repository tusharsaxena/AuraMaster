-- tests/test_skin_hud.lua — the HUD follows the skin (AM-03; skinning-§6, the owner's ruling O2).
--
-- AuraMaster's HUD is dressed onto Blizzard's pooled aura buttons, so it never hands a region to a
-- recorded primitive: each font and bar texture pick resolves through the owner's facade at dress
-- time (Style.SkinKey over S.Resolve) while its "Use the skin's ..." companion is on, and one
-- OnLooksChanged listener re-applies every container on a skin change. Only texture and font follow
-- (X4): the borders take no companion (DECISIONS D1), and sizes, flags and colors stay the player's.
-- The companions default on (X3), and schema v13 sets every stored one on, once, for every player.
-- What each pick draws with its companion OFF is the owning suites' (tests/test_style*.lua,
-- tests/test_fontprimer.lua, tests/test_render_coverage.lua), which turn the companion off.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil
local fresh = dofile("tests/fresh_env.lua")

local FROM_SKIN = "@skin"

--- The table holding `path`'s last segment inside `t`, and that segment; nil when a block is absent.
local function walk(t, path)
    local parent, leaf = t, nil
    for seg in path:gmatch("[^%.]+") do
        if leaf then
            parent = parent[leaf]
            if type(parent) ~= "table" then return nil end
        end
        leaf = seg
    end
    return parent, leaf
end

--- Every path under `t` whose value is the FROM_SKIN sentinel, joined.
local function sentinels(t, prefix, out)
    out = out or {}
    for k, v in pairs(t) do
        local p = (prefix or "") .. tostring(k)
        if v == FROM_SKIN then out[#out + 1] = p end
        if type(v) == "table" then sentinels(v, p .. ".", out) end
    end
    return out
end

--- A fresh environment whose LibSharedMedia stand-in answers a path for every key ("<kind>:<key>"):
--- the harness loads no media library, so every pick would otherwise fetch the one fallback and a
--- skin's key could not be told from the stored one.
local function mediaEnv()
    return fresh({ before = function(m)
        local lsm = setmetatable({ MediaType = { FONT = "font", STATUSBAR = "statusbar", BORDER = "border",
            BACKGROUND = "background", SOUND = "sound" } },
            { __index = function() return function() return {} end end })
        function lsm.Register() return true end
        function lsm.Fetch(_, kind, key) return kind .. ":" .. tostring(key) end
        m.__libs["LibSharedMedia-3.0"] = lsm
    end })
end

--- A registered skin other than Ka0s Default.
local function otherSkin(mocks)
    for _, def in ipairs(mocks.LibStub("LibKa0s-Skin-1.0"):Skins()) do
        if def.key ~= "ka0s" then return def.key end
    end
end

--- A fresh stub that records the last SetTexture made on it (the kit's CreateTexture returns the
--- frame itself, so the fill and the background are one table until each is swapped for one).
local function recorder(mocks)
    local r = mocks.__stubFrame()
    r.__calls = {}
    rawset(r, "SetTexture", function(_, ...) r.__calls.SetTexture = { ... } end)
    return r
end

-- ── the defaults and the rows ───────────────────────────────────────────────────────────────────

test("skin hud: every font block and both bar textures follow the skin by default; no border does", function()
    local NS = fresh()
    local D = NS.CONTAINER_TEMPLATE
    local named = {}
    for _, path in ipairs(NS.Database.SKIN_PICKS) do
        local parent, leaf = walk(D, path)
        -- red under: a companion left out of defaults/Profile.lua, or defaulted off (X3)
        assertEqual(parent and parent[leaf .. "FromSkin"], true, path)
        named[path] = true
    end
    -- Every font block in the template is one of the picks, so a text block added later is reset too.
    local function blocks(t, prefix)
        for k, v in pairs(t) do
            if type(v) == "table" then
                if type(v.font) == "string" and v.fontSize ~= nil then
                    assertTrue(named[prefix .. k .. ".font"], prefix .. k .. ".font is not in SKIN_PICKS")
                end
                blocks(v, prefix .. k .. ".")
            end
        end
    end
    blocks(D, "")
    -- red under: a border companion (every skin's bar.borderStyle is None: D1)
    for _, key in ipairs({ "borderStyleFromSkin", "iconBorderStyleFromSkin" }) do
        assertNil(D.bars[key], "bars." .. key)
        assertNil(D.icons[key], "icons." .. key)
        assertNil(D.text[key], "text." .. key)
    end
end)

test("skin hud: each companion is a schema row defaulting on, and its picker shows the skin's value while it is on", function()
    local NS = fresh()
    local c = NS.ActiveContainer()
    for _, path in ipairs(NS.Database.SKIN_PICKS) do
        local row = NS.FindSchemaRow("container." .. path .. "FromSkin")
        -- red under: a composer without `fromSkin = true` (no row: /am set cannot reach the companion)
        assertTrue(row ~= nil, path .. "FromSkin has no row")
        assertEqual(row.type, "bool", path)
        assertEqual(row.default, true, path .. ": the row's default is the template's")
        local picker = NS.FindSchemaRow("container." .. path)
        assertTrue(type(picker.skinValue) == "function", path .. ": the picker is governed")
        local token = path:find("Texture$") and "bar.texture" or "hud.font"
        local parent, leaf = walk(c, path)
        parent[leaf .. "FromSkin"] = true
        assertEqual(picker.skinValue(picker), NS.Skin.Token(token), path .. ": the skin's value, shown")
        parent[leaf .. "FromSkin"] = false
        assertNil(picker.skinValue(picker), path .. ": the stored pick, shown")
    end
end)

test("skin hud: the name label's face picker dims for the label off or the skin's face on", function()
    local NS = fresh()
    local c = NS.ActiveContainer()
    local picker = NS.FindSchemaRow("container.label.font.font")
    local cond = picker.disabledIf
    assertTrue(type(cond) == "function", "both reasons in one predicate")
    c.label.show, c.label.font.fontFromSkin = false, false
    assertTrue(cond(picker), "the label off")
    c.label.show = true
    -- red under: settings/Layout.lua's labelOff overwriting the composer's governing companion
    c.label.font.fontFromSkin = true
    assertTrue(cond(picker), "the skin's face on")
    c.label.font.fontFromSkin = false
    assertTrue(not cond(picker), "the label on and its own face")
end)

-- ── what the HUD draws ─────────────────────────────────────────────────────────────────────────

test("skin hud: a font block draws the skin's hud.font while its companion is on, its own face when off", function()
    local NS = mediaEnv()
    local S, C, D = NS.Style, NS.Constants, NS.CONTAINER_TEMPLATE.bars.name
    local t = NS.Database.DeepCopy(D)
    t.font = "Friz Quadrata TT"
    local skinPath = S.Fetch("font", NS.Skin.Token("hud.font"), C.FALLBACK_FONT)
    local ownPath = S.Fetch("font", "Friz Quadrata TT", C.FALLBACK_FONT)
    assertTrue(skinPath ~= ownPath, "the skin's face is not the stored one, so the case can tell them apart")
    -- red under: Style.FontKey fetching t.font unresolved
    assertEqual((S.FontKey(t, D)), skinPath, "on")
    t.fontFromSkin = false
    assertEqual((S.FontKey(t, D)), ownPath, "off")
    t.fontFromSkin = nil
    assertEqual((S.FontKey(t, D)), skinPath, "a block stored before the companion reads the template's")
end)

test("skin hud: Ignore fonts keeps every font block on its stored face, over the skin and a font override", function()
    -- The library's Resolve and Token never read ignoreFonts (only P.font, the primitives' path,
    -- does), so the HUD asks NS.SkinFontsIgnored itself, as AbsorbTracker does. red under: a
    -- Style.SkinKey that resolves hud.font through the skin while Ignore fonts is on.
    local NS, mocks = mediaEnv()
    local S, C, D = NS.Style, NS.Constants, NS.CONTAINER_TEMPLATE.bars.name
    local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
    local t = NS.Database.DeepCopy(D)
    t.font = "Friz Quadrata TT"
    local ownPath = S.Fetch("font", "Friz Quadrata TT", C.FALLBACK_FONT)
    assertEqual(NS.SkinFontsIgnored(), false, "fonts follow the skin by default")
    local ok, err = pcall(function()
        Skin:SetIgnore("AuraMaster", nil, true)
        assertEqual(NS.SkinFontsIgnored(), true, "the applied exception reads back")
        assertEqual((S.FontKey(t, D)), ownPath, "ignored fonts draw the stored face")
        Skin:SetOverride("AuraMaster", "Override Face", nil)
        assertEqual((S.FontKey(t, D)), ownPath, "a font override is not drawn while fonts are ignored")
        assertEqual(S.SkinKey("bar.texture", "Stored", true), NS.Skin.Resolve("bar.texture", "Stored", true),
            "Ignore fonts leaves the textures alone")
    end)
    Skin:SetOverride("AuraMaster", false, nil)
    Skin:SetIgnore("AuraMaster", nil, false)
    if not ok then error(err, 0) end
    assertTrue(S.FontKey(t, D) ~= ownPath, "unticked, the skin's face is back")
end)

test("skin hud: a bar's fill and background draw the skin's bar.texture while each companion is on", function()
    local NS, mocks = mediaEnv()
    local S, FALLBACK = NS.Style, NS.Constants.FALLBACK_TEXTURE
    local c = NS.Database.Merge(NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE), { style = "bars",
        bars = { barTexture = "Blizzard", bgTexture = "Blizzard" } })
    local function dress()
        local frame = mocks.__stubFrame()
        S.Element(frame, c, false)
        frame.__am.fill, frame.__am.bg = recorder(mocks), recorder(mocks)
        S.Element(frame, c, false)
        return frame.__am.fill.__calls.SetTexture[1], frame.__am.bg.__calls.SetTexture[1]
    end
    local skin = S.Fetch("statusbar", NS.Skin.Token("bar.texture"), FALLBACK)
    local own = S.Fetch("statusbar", "Blizzard", FALLBACK)
    assertTrue(skin ~= own, "the skin's texture is not the stored one")
    local fill, bg = dress()
    -- red under: modules/Style_Bars.lua fetching the stored keys unresolved
    assertEqual(fill, skin, "fill on")
    assertEqual(bg, skin, "background on")
    c.bars.barTextureFromSkin = false
    fill, bg = dress()
    assertEqual(fill, own, "fill off")
    assertEqual(bg, skin, "the background keeps its own companion")
    c.bars.bgTextureFromSkin = false
    fill, bg = dress()
    assertEqual(fill, own, "fill still off")
    assertEqual(bg, own, "background off")
end)

test("skin hud: without the library's facade answering, a pick draws the stored key", function()
    local NS = fresh()
    local S = NS.Style
    local live = NS.Skin
    NS.Skin = { Resolve = function() return nil end }
    local key = S.SkinKey("bar.texture", "Stored", true)
    NS.Skin = live
    -- red under: Style.SkinKey handing nil on, which every Fetch then reads as the fallback
    assertEqual(key, "Stored")
    assertEqual(S.SkinKey("bar.texture", "Stored", false), "Stored", "the companion off never asks")
end)

test("skin hud: a skin switch primes the fonts, then asks one system apply of every container, and rewrites nothing", function()
    local NS, mocks = fresh()
    local CM, FP = NS.ContainerManager, NS.FontPrimer
    local seen = {}
    local prime, request = FP.PrimeAll, CM.RequestApply
    FP.PrimeAll = function(...)
        seen[#seen + 1] = "prime"
        return prime(...)
    end
    CM.RequestApply = function(id, system)
        seen[#seen + 1] = ("apply %s %s"):format(tostring(id), tostring(system))
        return request(id, system)
    end
    local before = NS.Database.DeepCopy(NS.db.profile.containers)
    NS.ApplySkinChoice("ka0s", otherSkin(mocks))
    FP.PrimeAll, CM.RequestApply = prime, request
    -- red under: no OnLooksChanged listener (the HUD keeps the old skin until a setting changes), or
    -- one that requests before it primes (a skin's face is a lazily loaded addon font: issue #24)
    assertEqual(table.concat(seen, ","), "prime,apply nil true")
    -- red under: a switch that writes the skin's values into the stored picks
    assertEqual(#sentinels(NS.db.profile.containers), 0, "no sentinel stored")
    for id, c in pairs(before) do
        local now = NS.Database.FindContainer(id)
        assertEqual(now.bars.barTexture, c.bars.barTexture, id .. ": bar texture kept")
        assertEqual(now.bars.name.font, c.bars.name.font, id .. ": face kept")
        assertEqual(now.bars.barColor.r, c.bars.barColor.r, id .. ": colors are the player's (X4)")
    end
end)

-- ── the one-time reset (schema v13) ────────────────────────────────────────────────────────────

--- A profile as a v12 account stored it: no companion anywhere, a pick of the player's own on each
--- followed key, one block absent (container 2 has no icons block) and one companion an early build
--- stored off (container 1's bar time text).
local function v12profile()
    return {
        seeded = true, nextContainerId = 3, containerOrder = { 1, 2 },
        containers = {
            [1] = { name = "Bars", unit = "player", auraType = "HELPFUL", style = "bars",
                label = { font = { font = "Morpheus" } },
                bars = { barTexture = "Smooth", bgTexture = "Minimalist", borderStyle = "Solid",
                    name = { font = "Arial Narrow" }, time = { font = "Arial Narrow", fontFromSkin = false } },
                icons = { time = { font = "Skurri" }, stacks = { font = "Skurri" } },
                text = { font = { font = "Morpheus" } } },
            [2] = { name = "Lines", unit = "player", auraType = "HELPFUL", style = "text",
                text = { font = { font = "Skurri" } } },
        },
    }
end

test("skin hud: v13 puts every stored pick back on the skin in every profile, keeping each pick", function()
    local NS = fresh({ savedVariables = { profiles = { Default = v12profile(), Raid = v12profile() },
        global = { schemaVersion = 12 } } })
    assertEqual(NS.db.global.schemaVersion, 13)
    -- Raid is never activated in this load, so the load backfill never reaches it: what it holds is
    -- the step's alone.
    for _, name in ipairs({ "Raid", "Default" }) do
        local cs = NS.db.sv.profiles[name].containers
        local c1, c2 = cs[1], cs[2]
        -- red under: no v13 row, or a step gated to the active profile
        for _, path in ipairs(NS.Database.SKIN_PICKS) do
            local parent, leaf = walk(c1, path)
            if parent then assertEqual(parent[leaf .. "FromSkin"], true, name .. " #1 " .. path) end
        end
        assertEqual(c1.bars.time.fontFromSkin, true, name .. ": a stored off is reset (O2)")
        assertEqual(c2.text.font.fontFromSkin, true, name .. " #2")
        -- red under: ResetToSkin handed a pick with no companion beside it (it writes "@skin" in)
        assertEqual(#sentinels(cs), 0, name .. ": " .. table.concat(sentinels(cs), ", "))
        assertEqual(c1.bars.barTexture, "Smooth", name .. ": the pick is kept")
        assertEqual(c1.bars.bgTexture, "Minimalist", name)
        assertEqual(c1.bars.name.font, "Arial Narrow", name)
        assertEqual(c1.label.font.font, "Morpheus", name)
        assertEqual(c1.bars.borderStyle, "Solid", name .. ": the border is not reset (D1)")
        assertNil(c1.bars.borderStyleFromSkin, name .. ": and gets no companion")
    end
    assertNil(NS.db.sv.profiles.Raid.containers[2].icons, "an absent block is not created by the step")
end)

test("skin hud: v13 runs once, so a player's later pick survives the next load", function()
    local NS = fresh({ savedVariables = { profiles = { Default = v12profile() }, global = { schemaVersion = 12 } } })
    assertTrue(NS.SetByPath("container.bars.barTextureFromSkin", false, 1), "the panel's write")
    assertTrue(NS.SetByPath("container.bars.name.fontFromSkin", false, 1), "the panel's write")
    local sv = _G.AuraMasterDB
    local NS2 = fresh({ savedVariables = sv })
    assertEqual(NS2.db.global.schemaVersion, 13)
    local c = NS2.Database.FindContainer(1)
    -- red under: a step that re-runs each load (an unstamped reset), or a backfill that forces true
    assertEqual(c.bars.barTextureFromSkin, false, "the texture pick kept")
    assertEqual(c.bars.name.fontFromSkin, false, "the face pick kept")
    assertEqual(c.bars.bgTextureFromSkin, true, "the rest still follow")
end)

test("skin hud: the v13 body seeds each companion before ResetToSkin, and sets them itself without it", function()
    local NS, mocks = fresh()
    local Database, Skin = NS.Database, mocks.LibStub("LibKa0s-Skin-1.0")
    -- Without the library: the companions are set directly.
    local p = v12profile()
    assertEqual(Database.MigrateV13(p, nil), 2, "both containers moved")
    assertEqual(p.containers[1].bars.barTextureFromSkin, true)
    assertEqual(p.containers[2].text.font.fontFromSkin, true)
    assertEqual(#sentinels(p), 0)
    -- With it: every companion is a bool before the call, so ResetToSkin takes its companion branch.
    p = v12profile()
    local named, unseeded = {}, {}
    Database.MigrateV13(p, function(c, keys)
        for _, path in ipairs(keys) do
            named[#named + 1] = path
            local parent, leaf = walk(c, path)
            if type(parent[leaf .. "FromSkin"]) ~= "boolean" then unseeded[#unseeded + 1] = path end
        end
        return Skin.ResetToSkin(c, keys)
    end)
    -- red under: an unseeded companion reaching ResetToSkin
    assertEqual(table.concat(unseeded, ","), "")
    assertTrue(#named > 0, "the picks were named")
    assertEqual(p.containers[1].bars.barTextureFromSkin, true, "ResetToSkin set the companion")
    assertEqual(p.containers[1].bars.barTexture, "Smooth", "and kept the pick")
    -- A second run moves nothing.
    assertEqual(Database.MigrateV13(p, nil), 0, "idempotent")
end)
