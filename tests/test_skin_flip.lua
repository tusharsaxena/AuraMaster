-- tests/test_skin_flip.lua — FS-AM-FLIP: causes D2 to D7 (Ka0sAddonsCommonTasks
-- docs/2026-11-01-FULL_SKINNING; LibKa0s Options doc, "Moving to this version"). HUD text, bar fill,
-- background, borders, text glow and shadow follow the skin, and schema v16 moves every stored
-- profile, once. What a stored value draws with its companion off is the owning suites' (they go
-- through tests/own_look.lua). Every skin-switch case reads the drawing setters, never a getter.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local R = dofile("tests/region_recorder.lua")
local BS = dofile("tests/border_strips.lua")
local B = dofile("tests/region_builder.lua")

local LEAVES_SUFFIX = "FromSkin$"

local function rgba(...)
    local t = { ... }
    for i, v in ipairs(t) do t[i] = ("%.3f"):format(v) end
    return table.concat(t, ",")
end

--- A template-shaped config on `NS`, `over` merged on.
local function cfg(NS, over)
    return NS.Database.Merge(NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE), over or {})
end

--- Dress `c`, swap the regions for recorders and dress again, so every drawing call is on record.
local function dressed(NS, c, classColor)
    local frame = R()
    NS.Style.Element(frame, c, false, classColor)
    for k in pairs(frame.__am) do frame.__am[k] = R() end
    NS.Style.Element(frame, c, false, classColor)
    return frame.__am, frame
end

--- The skin's value for `token` under skin `key`, off the library's own table.
local function tokenOf(mocks, key, token)
    return mocks.LibStub("LibKa0s-Skin-1.0"):ResolveSkin(key)[token]
end

--- A registered skin whose `token` is not Ka0s Default's.
local function skinWith(mocks, token)
    local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
    local base = Skin:ResolveSkin("ka0s")[token]
    for _, def in ipairs(Skin:Skins()) do
        local v = Skin:ResolveSkin(def.key)[token]
        if def.key ~= "ka0s" and rgba(unpack(type(v) == "table" and v or { 0 }))
            ~= rgba(unpack(type(base) == "table" and base or { 0 })) then
            return def.key
        end
    end
end

-- ── the defaults and the rows ───────────────────────────────────────────────────────────────────

test("skin flip: every listed companion is a bool row defaulting on, in the template and on the row", function()
    local NS = fresh()
    local n = 0
    for _, path in ipairs(NS.Database.SKIN_FOLLOW_LEAVES) do
        if path:find(LEAVES_SUFFIX) then
            n = n + 1
            local row = NS.FindSchemaRow("container." .. path)
            assertTrue(row ~= nil, path .. " has a row")
            assertEqual(row.type, "bool", path)
            local v = NS.CONTAINER_TEMPLATE
            for seg in path:gmatch("[^%.]+") do v = v[seg] end
            -- red under: a companion missing from defaults/Profile.lua, or defaulted off
            assertEqual(v, true, path .. " in the template")
        end
    end
    assertEqual(n, 13 + 3 * 7, "the bars' 8, the icons' 2, the text's 3 and 3 per font block")
end)

test("skin flip: no swatch carries disabledIf, and a class color has no companion", function()
    local NS = fresh()
    for _, path in ipairs({ "bars.barColor", "bars.bgColor", "bars.borderColor", "bars.iconBorderColor",
        "icons.borderColor", "text.glowColor", "text.font.fontColor", "label.font.fontColor" }) do
        assertNil(NS.FindSchemaRow("container." .. path).disabledIf, path)
    end
    assertNil(NS.FindSchemaRow("container.bars.useClassColorBarFromSkin"), "no companion on a class toggle")
end)

test("skin flip: the picks' defaults moved to the Ka0s picks; size, Show border and Scope did not", function()
    local NS = fresh()
    local D = NS.CONTAINER_TEMPLATE
    assertEqual(D.bars.barTexture, "Ka0s Default")
    assertEqual(D.bars.bgTexture, "Ka0s Default")
    for _, t in ipairs({ D.bars.name, D.bars.time, D.bars.stacks, D.icons.time, D.icons.stacks, D.text.font, D.label.font }) do
        assertEqual(t.font, "Ka0s Prototype")
    end
    assertEqual(D.bars.borderShow, false)
    assertEqual(D.icons.borderShow, true)
    assertEqual(D.icons.borderSize, 1)
    -- red under: a flip writing the Scope (the settings panel stays stock by default)
    assertEqual(NS.defaults.profile.skin.ignorePanel, true)
    assertEqual(NS.defaults.profile.skin.ignoreFonts, false)
end)

test("skin flip: the borders' thickness goes on the skin through the composer, the icon's on our token", function()
    local NS = fresh()
    -- A predicate (OptionsCompose minor 18): a skin's None leaves the bar's thickness the player's.
    assertEqual(type(NS.FindSchemaRow("container.bars.borderSize").disabledIf), "function")
    local row = NS.FindSchemaRow("container.icons.borderSize")
    assertEqual(row.disabledIf, "container.icons.borderStyleFromSkin")
    -- red under: the disabled row showing the library's 2 while the icon draws 1
    assertEqual(row.skinValue(row), 1, "the row shows what draws under Ka0s Default")
    for _, path in ipairs({ "container.bars.iconBorderSize", "container.text.iconBorderSize" }) do
        local beside = NS.FindSchemaRow(path)
        -- red under: NS.IconBorderSizeRow dropped from that page's icon border rows
        assertEqual(beside.skinValue(beside), 1, path)
    end
end)

-- ── what draws ──────────────────────────────────────────────────────────────────────────────────

test("skin flip: Ka0s Default keeps this addon's pixels, stored defaults or skin alike", function()
    local NS = fresh()
    local c = cfg(NS, { icons = { width = 32 } })
    local am = dressed(NS, c)
    assertEqual(rgba(unpack(am.fill:__last("SetVertexColor"))), rgba(0.20, 0.55, 0.95, 1), "the blue fill")
    assertEqual(rgba(unpack(am.bg:__last("SetVertexColor"))), rgba(0, 0, 0, 0.5), "the background")
    assertEqual(rgba(unpack(am.name:__last("SetTextColor"))), rgba(1, 1, 1, 1), "white text")
    c.style = "icons"
    local ic = dressed(NS, c)
    local strips = BS.strips(ic.border)
    assertEqual(rgba(unpack(strips[1]:__last("SetColorTexture"))), rgba(0, 0, 0, 1), "black icon border")
    -- red under: the composer's icon.borderSize, 2 under Ka0s Default
    assertEqual(strips[1]:__last("SetHeight")[1], 1, "this addon's 1 px")
end)

test("skin flip: a skin switch changes every flipped surface", function()
    local NS, mocks = fresh()
    local key = skinWith(mocks, "hud.text")
    NS.ApplySkinChoice("ka0s", key)
    local am = dressed(NS, cfg(NS))
    assertEqual(rgba(unpack(am.name:__last("SetTextColor"))), rgba(unpack(tokenOf(mocks, key, "hud.text"))), "the name")
    assertEqual(rgba(unpack(am.fill:__last("SetVertexColor"))), rgba(unpack(tokenOf(mocks, key, "bar.fill"))), "the fill")
    local c = cfg(NS, { style = "icons" })
    local ic = dressed(NS, c)
    local want = tokenOf(mocks, key, "icon.borderSize")
    assertEqual(BS.strips(ic.border)[1]:__last("SetHeight")[1], want, "the icon border's thickness")
    local stored = NS.Database.DeepCopy(c)
    assertEqual(rgba(stored.bars.barColor.r, stored.bars.barColor.g, stored.bars.barColor.b, 1), rgba(0.20, 0.55, 0.95, 1),
        "the stored value is not written")
end)

test("skin flip: the name label reads hud.label, a text line hud.text", function()
    local NS, mocks = fresh()
    local key = skinWith(mocks, "hud.label")
    NS.ApplySkinChoice("ka0s", key)
    local fs = R()
    local D = NS.CONTAINER_TEMPLATE
    NS.Style.ApplyFont(fs, NS.Database.DeepCopy(D.label.font), D.label.font, false)
    assertEqual(rgba(unpack(fs:__last("SetTextColor"))), rgba(unpack(tokenOf(mocks, key, "hud.label"))))
end)

test("skin flip: a stored background, border and glow color lose to the skin's token while followed", function()
    local NS, mocks = fresh()
    local red = { r = 1, g = 0, b = 0, a = 1 }
    local c = cfg(NS, { bars = { bgColor = red, borderShow = true, borderColor = red, borderStyleFromSkin = false } })
    local am = dressed(NS, c)
    local bg, border = tokenOf(mocks, "ka0s", "bar.bg"), tokenOf(mocks, "ka0s", "bar.border")
    assertEqual(rgba(unpack(am.bg:__last("SetVertexColor"))), rgba(unpack(bg)))
    assertEqual(rgba(unpack(BS.strips(am.border)[1]:__last("SetColorTexture"))), rgba(unpack(border)))
    -- The glow's token is this addon's: its black ring under Ka0s Default, glow.color under the rest.
    local key = skinWith(mocks, "hud.text")
    local fs = R()
    local s = NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE.text)
    s.glowColor = red
    NS.Style.Text.GlowFont(fs, s, 1)
    assertEqual(rgba(unpack(fs:__last("SetTextColor"))), rgba(0, 0, 0, 0.5), "black, at the intensity")
    NS.ApplySkinChoice("ka0s", key)
    NS.Style.Text.GlowFont(fs, s, 1)
    local g = tokenOf(mocks, key, "glow.color")
    assertEqual(rgba(unpack(fs:__last("SetTextColor"))), rgba(g[1], g[2], g[3], (g[4] or 1) * 0.5), "the skin's")
end)

test("skin flip: a running-out curve returns to the skin's color on an icon and a text line", function()
    local NS, mocks = fresh({ before = dofile("tests/text_apis.lua") })
    local key = skinWith(mocks, "hud.text")
    NS.ApplySkinChoice("ka0s", key)
    local want = tokenOf(mocks, key, "hud.text")
    local function normalOf(frame)
        local n = frame:__last("SetDurationText")[2].textColor.curve:__last("AddPoint")[2]
        return rgba(n.r, n.g, n.b)
    end
    local icon = R()
    NS.Style.Element(icon, cfg(NS, { style = "icons", icons = { expiringColorOn = true } }), true)
    -- red under: Style.BindDurationText handing the curve the stored time color
    assertEqual(normalOf(icon), rgba(want[1], want[2], want[3]), "an icon's time")
    local made = {}
    local line = B.new(made)
    local c = cfg(NS, { style = "text", text = { template = "$spellname$[ - $remainingduration$]",
        expiringColorOn = true } })
    B.during(mocks, made, function() NS.Style.Element(line, c, true) end)
    -- red under: the duration binder's fallback read from the stored font color
    assertEqual(normalOf(line), rgba(want[1], want[2], want[3]), "a text line's run")
end)

test("skin flip: a placeholder's run takes the skin's color, the live curve's own fallback", function()
    local NS, mocks = fresh({ before = dofile("tests/text_apis.lua") })
    local key = skinWith(mocks, "hud.text")
    NS.ApplySkinChoice("ka0s", key)
    local made = {}
    local frame = B.new(made)
    local c = cfg(NS, { style = "text", text = { template = "$spellname$[ - $remainingduration$]",
        expiringBlink = true, expiringThreshold = 30 } })
    B.during(mocks, made, function() NS.Style.Element(frame, c, false) end)
    NS.Style.Text.FillPreview(frame, { name = "Bloodlust", icon = 1, remaining = 28, duration = 40, stacks = 1 }, c)
    local got, want = frame.__am.piece2:__last("SetTextColor"), tokenOf(mocks, key, "hud.text")
    -- red under: previewRunColor painting the stored font color
    assertEqual(rgba(got[1], got[2], got[3]), rgba(want[1], want[2], want[3]))
end)

test("skin flip: a running-out curve follows the skin, and two skins never share one curve", function()
    local NS, mocks = fresh()
    local key = skinWith(mocks, "hud.text")
    local t = NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE.bars.time)
    local D = NS.CONTAINER_TEMPLATE.bars.time
    local before = NS.Style.FontColor(t, D)
    assertTrue(before == NS.Style.FontColor(t, D), "a stable table across one look")
    NS.ApplySkinChoice("ka0s", key)
    -- red under: Followed editing its table in place, which leaves the memoized curve on the old skin
    assertTrue(before ~= NS.Style.FontColor(t, D), "a new table when the skin's color moved")
end)

test("skin flip: a class color comes first, whatever the companion says", function()
    local NS, mocks = fresh()
    NS.ApplySkinChoice("ka0s", skinWith(mocks, "bar.fill"))
    local class = { r = 0.9, g = 0.8, b = 0.7 }
    local c = cfg(NS, { bars = { barColor = { r = 0.1, g = 0.2, b = 0.3, a = 0.5 }, useClassColorBar = true } })
    local am = dressed(NS, c, class)
    assertEqual(rgba(unpack(am.fill:__last("SetVertexColor"))), rgba(0.9, 0.8, 0.7, 0.5), "the class, the stored alpha")
end)

test("skin flip: a class that does not resolve follows the skin; its toggle stays stored", function()
    local NS, mocks = fresh()
    local key = skinWith(mocks, "bar.fill")
    NS.ApplySkinChoice("ka0s", key)
    local mine = { r = 0.1, g = 0.2, b = 0.3, a = 0.5 }
    local over = { bars = { barColor = mine, useClassColorBar = true,
        name = { fontColor = mine, useClassColorFont = true } } }
    local npc = {}
    local am = dressed(NS, cfg(NS, over), npc)
    -- red under: Style.Followed standing aside for the toggle whatever the class resolved to
    assertEqual(rgba(unpack(am.fill:__last("SetVertexColor"))), rgba(unpack(tokenOf(mocks, key, "bar.fill"))), "the fill")
    assertEqual(rgba(unpack(am.name:__last("SetTextColor"))), rgba(unpack(tokenOf(mocks, key, "hud.text"))), "the text")
    local c = cfg(NS, over)
    c.bars.barColorFromSkin = false
    assertEqual(rgba(unpack(dressed(NS, c, npc).fill:__last("SetVertexColor"))), rgba(0.1, 0.2, 0.3, 0.5), "companion off")
    assertTrue(c.bars.useClassColorBar, "the toggle is not written")
    -- The name label names its class outright, outside any dress.
    local D = NS.CONTAINER_TEMPLATE
    local t = NS.Database.DeepCopy(D.label.font)
    t.fontColor, t.useClassColorFont = mine, true
    local fs = R()
    NS.Style.ApplyFont(fs, t, D.label.font, npc)
    -- red under: Style.ApplyFont not handing its class to Style.FontColor
    assertEqual(rgba(unpack(fs:__last("SetTextColor"))), rgba(unpack(tokenOf(mocks, key, "hud.label"))), "the label, an NPC")
    NS.Style.ApplyFont(fs, t, D.label.font, { r = 0.9, g = 0.8, b = 0.7 })
    assertEqual(rgba(unpack(fs:__last("SetTextColor"))), rgba(0.9, 0.8, 0.7, 0.5), "the label, a resolved class")
end)

test("skin flip: a dispel-colored bar's no-type color is the skin's, on the engine's map and a placeholder", function()
    local NS, mocks = fresh({ before = function(m)
        m.Enum = m.Enum or {}
        m.Enum.CustomAuraButtonDispelTypeTextureStyle = { Border = 31, PreserveAsset = 32 }
    end })
    local key = skinWith(mocks, "bar.fill")
    NS.ApplySkinChoice("ka0s", key)
    local red = { r = 1, g = 0, b = 0, a = 1 }
    local c = cfg(NS, { bars = { colorMode = "dispel", bgColorMode = "dispel", barColor = red, bgColor = red } })
    local fill, bg = tokenOf(mocks, key, "bar.fill"), tokenOf(mocks, key, "bar.bg")
    local rgb = function(t) return rgba(t.r or t[1], t.g or t[2], t.b or t[3]) end
    local live = R()
    NS.Style.Element(live, c, true)
    local maps = {}
    for _, call in ipairs(live:__calls("AddDispelTypeTexture")) do maps[call[1]] = call[2].customDispelColorMap end
    -- red under: Bars.Bind handing dispelTint the stored fill or background
    assertEqual(rgb(maps[live.__am.fill].None), rgb(fill), "the live fill's fallback")
    assertEqual(rgb(maps[live.__am.bg].None), rgb(bg), "the live background's fallback")
    local placeholder = R()
    NS.Style.Element(placeholder, c, false)
    -- red under: am.fillNone or am.bgNone taken from the stored color
    assertEqual(rgb(placeholder.__am.fillNone), rgb(fill), "a placeholder's fill")
    assertEqual(rgb(placeholder.__am.bgNone), rgb(bg), "a placeholder's background")
end)

--- A registered skin other than Ka0s Default whose `icon.borderSize` is 2 and whose style is Solid:
--- not the stored 5 of the cases below, Ka0s Default's 1 or the bar family's 1.
local function thickIconSkin(mocks)
    local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
    for _, def in ipairs(Skin:Skins()) do
        local t = Skin:ResolveSkin(def.key)
        if def.key ~= "ka0s" and t["icon.borderSize"] == 2 and t["icon.borderStyle"] == "Solid" then return def.key end
    end
end

test("skin flip: an icon's inset and dispel edge take the skin's thickness, not the stored one", function()
    local NS, mocks = fresh()
    local key = thickIconSkin(mocks)
    NS.ApplySkinChoice("ka0s", key)
    local want = tokenOf(mocks, key, "icon.borderSize")
    local am = dressed(NS, cfg(NS, { style = "icons", icons = { borderSize = 5 } }))
    -- red under: layoutIcon reading ic.borderSize
    assertEqual(am.icon:__last("SetPoint")[4], -want, "the art's inset")
    -- red under: dispelSizeOf reading ic.borderSize
    assertEqual(am.dispelTop:__last("SetHeight")[1], want, "the dispel edge lies over the border")
end)

test("skin flip: the icon beside a bar or a text line draws the icon family, not the bar's", function()
    local NS, mocks = fresh({ before = dofile("tests/text_apis.lua") })
    local key = thickIconSkin(mocks)
    NS.ApplySkinChoice("ka0s", key)
    local size = tokenOf(mocks, key, "icon.borderSize")
    -- No shipped skin parts the two colors, so the bar family's answers apart here.
    local color = { 0.1, 0.2, 0.3, 1 }
    local skinColor = NS.Skin.Color
    NS.Skin.Color = function(token)
        if token == "icon.border" then return unpack(color) end
        return skinColor(token)
    end
    local beside = { icon = "LEFT", iconBorderShow = true, iconBorderSize = 5 }
    local am = dressed(NS, cfg(NS, { bars = beside }))
    local strips = BS.strips(am.iconBorder)
    -- red under: BORDER_BESIDE's sizeToken or colorToken on the bar family
    assertEqual(strips[1]:__last("SetHeight")[1], size, "a bar's side icon, the thickness")
    assertEqual(rgba(unpack(strips[1]:__last("SetColorTexture"))), rgba(unpack(color)), "a bar's side icon, the color")
    local made = {}
    local line = B.new(made)
    local c = cfg(NS, { style = "text", text = beside })
    B.during(mocks, made, function() NS.Style.Element(line, c, false) end)
    strips = BS.strips(line.__am.iconBorder)
    assertEqual(strips[1]:__last("SetHeight")[1], size, "a text line's icon, the thickness")
    assertEqual(rgba(unpack(strips[1]:__last("SetColorTexture"))), rgba(unpack(color)), "a text line's icon, the color")
end)

test("skin flip: a live switch to WoW Default keeps a laid-out icon's border drawn, flat, in the skin's values", function()
    local NS, mocks = fresh()
    local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
    local key
    for _, def in ipairs(Skin:Skins()) do
        if Skin:ResolveSkin(def.key)["icon.borderStyle"] ~= "Solid" then key = key or def.key end
    end
    assertTrue(key ~= nil, "the one skin that is not Solid")
    local c = cfg(NS, { style = "icons" })
    local am, frame = dressed(NS, c)
    mocks.__layOut(am.border)
    NS.ApplySkinChoice("ka0s", key)
    NS.Style.Element(frame, c, false)
    -- red under: ApplyBorder hiding the strips while the backdrop was refused
    BS.assertSolid(am.border, tokenOf(mocks, key, "icon.borderSize"),
        table.concat(tokenOf(mocks, key, "icon.border"), ","), "the strips stand in")
end)

test("skin flip: a player's own values draw with the companions off, under any skin", function()
    local NS, mocks = fresh()
    NS.ApplySkinChoice("ka0s", skinWith(mocks, "bar.fill"))
    local mine = { r = 0.1, g = 0.2, b = 0.3, a = 1 }
    local am = dressed(NS, cfg(NS, { bars = { barColor = mine, barColorFromSkin = false } }))
    assertEqual(rgba(unpack(am.fill:__last("SetVertexColor"))), rgba(0.1, 0.2, 0.3, 1))
end)

--- The shadow a string draws, off the setters: "x,y,r,g,b,a".
local function shadowOf(fs)
    return rgba(unpack(fs:__last("SetShadowOffset"))) .. "|" .. rgba(unpack(fs:__last("SetShadowColor")))
end

test("skin flip: a shadow follows the skin and goes when the skin's goes, on a string already drawn", function()
    local NS, mocks = fresh()
    local key = skinWith(mocks, "hud.shadow")
    local D = NS.CONTAINER_TEMPLATE.bars.name
    local t, fs = NS.Database.DeepCopy(D), R()
    NS.Style.ApplyFont(fs, t, D)
    assertEqual(shadowOf(fs), rgba(0, 0) .. "|" .. rgba(0, 0, 0, 0), "Ka0s Default says no shadow")
    NS.ApplySkinChoice("ka0s", key)
    NS.Style.ApplyFont(fs, t, D)
    local x, y, r, g, b, a = NS.Skin.HudShadow()
    assertEqual(shadowOf(fs), rgba(x, y) .. "|" .. rgba(r, g, b, a), "the skin's")
    NS.ApplySkinChoice("ka0s", "ka0s")
    NS.Style.ApplyFont(fs, t, D)
    -- red under: an off arm that skips the calls and keeps the last skin's shadow
    assertEqual(shadowOf(fs), rgba(0, 0) .. "|" .. rgba(0, 0, 0, 0), "and back")
end)

test("skin flip: with the shadow's companion off the stored shadow draws under every skin", function()
    local NS, mocks = fresh()
    local D = NS.CONTAINER_TEMPLATE.bars.name
    local t, fs = NS.Database.DeepCopy(D), R()
    t.fontShadow, t.fontShadowFromSkin = true, false
    NS.ApplySkinChoice("ka0s", skinWith(mocks, "hud.shadow"))
    NS.Style.ApplyFont(fs, t, D)
    assertEqual(shadowOf(fs), rgba(1, -1) .. "|" .. rgba(0, 0, 0, 1))
end)

test("skin flip: the shadow lands on a font object where the client has CreateFont", function()
    -- A 12.0.7 client draws only a font object's shadow. red under: a host's own SetShadow* on the string.
    local NS, mocks = fresh()
    local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
    NS.ApplySkinChoice("ka0s", skinWith(mocks, "hud.shadow"))
    local made
    local saved = rawget(_G, "CreateFont")
    rawset(_G, "CreateFont", function() made = R(); return made end)
    local D = NS.CONTAINER_TEMPLATE.bars.name
    local fs = R()
    local ok, err = pcall(NS.Style.ApplyFont, fs, NS.Database.DeepCopy(D), D)
    rawset(_G, "CreateFont", saved)
    Skin.__hudFonts[fs] = nil
    assertTrue(ok, tostring(err))
    assertTrue(made ~= nil, "a font object was made")
    assertEqual(fs:__last("SetFontObject")[1], made)
    local x, y = NS.Skin.HudShadow()
    assertEqual(rgba(unpack(made:__last("SetShadowOffset"))), rgba(x, y))
    assertEqual(#fs:__calls("SetShadowOffset"), 0, "nothing on the string itself")
end)

test("skin flip: a skin switch re-dresses a shown container through the one listener", function()
    local NS, mocks = fresh()
    local asks = 0
    local request = NS.ContainerManager.RequestApply
    NS.ContainerManager.RequestApply = function(...) asks = asks + 1; return request(...) end
    NS.ApplySkinChoice("ka0s", skinWith(mocks, "hud.text"))
    NS.ContainerManager.RequestApply = request
    assertTrue(asks >= 1, "the HUD is asked to re-dress")
end)

test("skin flip: with no library a followed value is the stored one, the owner tokens included", function()
    local NS2 = fresh()
    NS2.SkinDegraded = true
    local mine = { r = 0.1, g = 0.2, b = 0.3, a = 1 }
    -- red under: the degraded facade's owner default drawn over the player's stored color
    assertTrue(NS2.Style.Followed(mine, true, "am.textGlow") == mine, "the stored color is the fallback")
    assertEqual(NS2.Style.SkinKey("am.iconBorderSize", 3, true), 3)
end)

-- ── the step ────────────────────────────────────────────────────────────────────────────────────

local KAIT = "Ka0s Kait"

--- A stored profile: some companions false, some absent, a color with one key, a block missing.
local function partial()
    return {
        seeded = true, nextContainerId = 3, containerOrder = { 1, 2 },
        skin = { ignorePanel = false, ignoreFonts = true },
        containers = {
            [1] = { name = "Bars", style = "bars",
                bars = { barTexture = "Smooth", barTextureFromSkin = false, barColor = { r = 0.3 }, useClassColorBar = true,
                    bgColor = { r = 0.1, g = 0.2, b = 0.3, a = 0.4 }, borderStyle = "Blizzard Tooltip", borderSize = 3,
                    borderColor = { r = 1, g = 0, b = 0, a = 1 }, expiringColor = { r = 1, g = 0, b = 0, a = 1 },
                    name = { font = KAIT, fontFromSkin = false, fontColor = { r = 0.5, g = 0.5, b = 0.5, a = 1 },
                        fontFlags = "THICKOUTLINE", fontShadow = true } },
                label = { font = { font = KAIT } } },
            [2] = { name = "Lines", style = "text",
                text = { glowColor = { r = 0, g = 1, b = 0, a = 1 }, useClassColorGlow = true,
                    font = { font = KAIT, fontColorFromSkin = false } } },
        },
    }
end

local function ran(profiles, global)
    return fresh({ savedVariables = { profiles = profiles, global = global or { schemaVersion = 15 } } })
end

test("skin flip: v16 sets every listed companion in every profile and keeps each stored value", function()
    local NS = ran({ Default = partial(), Raid = partial() })
    local want = partial()
    for _, name in ipairs({ "Default", "Raid" }) do
        local p = NS.db.sv.profiles[name]
        assertEqual(p.skin.fullSkinReset, true, name)
        local c1, c2 = p.containers[1], p.containers[2]
        -- red under: paths built with numeric ids through Skin.FollowOnce's string walk, which skip
        -- every container and still write the record
        assertEqual(c1.bars.barTextureFromSkin, true, name .. " a stored false moves")
        assertEqual(c1.bars.name.fontFromSkin, true, name .. " the player's face follows (the ruling)")
        assertEqual(c1.bars.name.fontColorFromSkin, true, name .. " an absent one is written")
        assertEqual(c2.text.font.fontColorFromSkin, true, name)
        assertEqual(c2.text.glowColorFromSkin, true, name)
        assertEqual(c1.bars.name.fontFlags, "@skin", name .. " Font flags: on S.FontFlags")
        assertEqual(c1.bars.barColor.r, 0.3, name .. " a one-key color keeps its key (the backfill fills the rest)")
        assertEqual(c1.bars.barTexture, want.containers[1].bars.barTexture, name)
        assertEqual(c1.bars.borderStyle, want.containers[1].bars.borderStyle, name)
        assertEqual(c1.bars.borderSize, 3, name .. " a thickness is not listed")
        assertEqual(c1.bars.name.font, KAIT, name)
        assertEqual(c1.bars.name.fontShadow, true, name)
        assertEqual(c1.bars.bgColor.a, 0.4, name)
        -- A class color, its toggle, a running-out tint and the Scope.
        assertEqual(c1.bars.useClassColorBar, true, name)
        assertEqual(c1.bars.expiringColor.g, 0, name)
        assertEqual(c2.text.useClassColorGlow, true, name)
        assertEqual(p.skin.ignorePanel, false, name)
        assertEqual(p.skin.ignoreFonts, true, name)
    end
end)

test("skin flip: v16 writes no sentinel but the flags and makes no stray skin table", function()
    local NS = ran({ Default = partial() })
    local function walk(t, prefix)
        for k, v in pairs(t) do
            if v == "@skin" then assertEqual(k, "fontFlags", prefix .. tostring(k)) end
            if type(v) == "table" then walk(v, prefix .. tostring(k) .. ".") end
        end
    end
    local p = NS.db.sv.profiles.Default
    walk(p.containers, "")
    for id, c in pairs(p.containers) do
        -- red under: FollowOnce called once per container with that container's table
        assertNil(c.skin, "container " .. tostring(id))
    end
end)

test("skin flip: a second run writes nothing, and a companion turned off afterwards stays off", function()
    local NS = ran({ Default = partial() })
    local p = NS.db.sv.profiles.Default
    p.containers[1].bars.barColorFromSkin = false
    assertEqual(NS.Database.FollowSkin(p), false, "already recorded")
    NS.db.global.schemaVersion = 15
    NS.RunMigrations()
    assertEqual(p.containers[1].bars.barColorFromSkin, false, "the ladder again")
    NS.OnProfileChanged()
    assertEqual(p.containers[1].bars.barColorFromSkin, false, "a profile event")
end)

test("skin flip: every Defaults path keeps the record", function()
    local NS = ran({ Default = partial() })
    local p = NS.db.profile
    assertEqual(p.skin.fullSkinReset, true)
    -- red under: a schema row for the record, which General's Defaults would put back to false
    assertNil(NS.FindSchemaRow("skin.fullSkinReset"), "no row")
    p.containers[1].bars.barColorFromSkin = false
    NS.Helpers.RestoreDefaults("general", {})
    assertEqual(p.skin.fullSkinReset, true, "General's Defaults")
    NS.Helpers.RestoreAllDefaults()
    assertEqual(NS.db.profile.skin.fullSkinReset, true, "Reset all, the step run again or the record kept")
end)

test("skin flip: a profile reset runs the step against defaults, which writes nothing a player sees", function()
    local NS = fresh()
    local p = NS.db.profile
    p.skin.fullSkinReset = false
    assertEqual(NS.Database.FollowSkin(p), true)
    local c = NS.Database.FindContainer(p.containerOrder[1])
    assertEqual(c.bars.barColorFromSkin, true)
end)

test("skin flip: the step is the same write with the library absent, and creates only the skin table", function()
    local NS, mocks = fresh()
    local p = partial()
    p.skin = nil
    p.containers[1].label = nil
    local lib = NS.Database
    -- The no-Skin-major arm: a copy with no FollowOnce answers the same as no library.
    local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
    local keep = Skin.FollowOnce
    Skin.FollowOnce = nil
    local ok, err = pcall(lib.FollowSkin, p)
    assertTrue(ok, tostring(err))
    assertEqual(p.skin.fullSkinReset, true, "the record, by hand")
    assertEqual(p.containers[1].bars.barTextureFromSkin, true)
    assertEqual(p.containers[1].bars.name.fontFlags, "@skin")
    assertNil(p.containers[1].label, "no table on the way")
    assertNil(p.containers[1].icons, "no table on the way")
    assertEqual(lib.FollowSkin(p), false, "the record gates")
    Skin.FollowOnce = keep
end)

test("skin flip: v16 on a stored profile with no skin table keeps the record, so the step runs once", function()
    local bare = partial()
    bare.skin = nil
    local NS = ran({ Default = partial(), Parked = bare })
    local p = NS.db.sv.profiles.Parked
    -- red under: FollowSkin not carrying the view's skin table back, which loses the record
    assertEqual(type(p.skin), "table", "the table persists")
    assertEqual(p.skin.fullSkinReset, true, "and the record in it")
    assertEqual(p.containers[1].bars.barTextureFromSkin, true, "the step ran")
    p.containers[1].bars.barTextureFromSkin = false
    assertEqual(NS.Database.FollowSkin(p), false, "the record gates a second run")
    assertEqual(p.containers[1].bars.barTextureFromSkin, false)
end)

test("skin flip: the ladder walks every stored profile, and a new profile takes the step on load", function()
    local NS = ran({ Default = partial(), Parked = partial() })
    assertEqual(NS.db.sv.profiles.Parked.skin.fullSkinReset, true, "an inactive profile")
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertEqual(NS.SCHEMA_VERSION, 16)
end)
