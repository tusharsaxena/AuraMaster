-- tests/test_style_icons.lua — modules/Style_Icons.lua: how one aura is dressed as an ICON. The art
-- inside its border and cropped to the element's shape, the cooldown swipe, the dispel border, the
-- texts, the engine bindings, and the preview fill.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local NS = T.NS
local R = dofile("tests/region_recorder.lua")
local fresh = dofile("tests/fresh_env.lua")
local D = NS.CONTAINER_TEMPLATE

local function cfg(over)
    local c = NS.Database.Merge(NS.Database.DeepCopy(D), over or {})
    c.style = "icons"
    return c
end

--- Dress an icon element for `c`, swap each of its regions for a recorder, and dress it again, so
--- every call a region receives is its own. The element itself is a recorder too: engine bindings
--- land in its log.
local function dressed(c, engine, classColor, ns)
    ns = ns or NS
    local frame = R()
    ns.Style.Element(frame, c, engine, classColor)
    for k in pairs(frame.__am) do frame.__am[k] = R() end
    frame.__log = {}
    ns.Style.Element(frame, c, engine, classColor)
    return frame, frame.__am
end

-- ── the art ───────────────────────────────────────────────────────────────────────────────────

test("icons: the art sits inside a shown border, inset by the border's size", function()
    local frame, am = dressed(cfg({ icons = { borderShow = true, borderStyle = "Solid", borderSize = 3 } }))
    local p = am.icon:__calls("SetPoint")
    -- red under: layoutIcon without its border inset (a thick border covers the art)
    assertEqual(p[1][1], "TOPLEFT"); assertTrue(p[1][2] == frame); assertEqual(p[1][4], 3); assertEqual(p[1][5], -3)
    assertEqual(p[2][1], "BOTTOMRIGHT"); assertEqual(p[2][4], -3); assertEqual(p[2][5], 3)
end)

test("icons: a hidden border, or the None style, leaves the art edge to edge", function()
    local _, am = dressed(cfg({ icons = { borderShow = false, borderSize = 3 } }))
    -- red under: the inset read from borderSize alone
    assertEqual(am.icon:__calls("SetPoint")[1][4], 0, "a hidden border")
    _, am = dressed(cfg({ icons = { borderShow = true, borderStyle = "None", borderSize = 3 } }))
    assertEqual(am.icon:__calls("SetPoint")[1][4], 0, "the None style")
end)

test("icons: a square icon is zoomed evenly from every side", function()
    local _, am = dressed(cfg({ icons = { width = 30, height = 30, zoom = 0.1 } }))
    assertEqual(am.icon:__joined("SetTexCoord"), "0.1,0.9,0.1,0.9")
end)

test("icons: a wide icon is cropped top and bottom, a tall one left and right, never squashed", function()
    local _, am = dressed(cfg({ icons = { width = 40, height = 20, zoom = 0.1 } }))
    local tc = am.icon:__last("SetTexCoord")
    -- red under: layoutIcon cropping evenly whatever the aspect (a 2:1 icon draws its art squashed)
    T.assertNear(tc[1], 0.1, 1e-9, "left"); T.assertNear(tc[2], 0.9, 1e-9, "right")
    T.assertNear(tc[3], 0.3, 1e-9, "top: half of the unused height"); T.assertNear(tc[4], 0.7, 1e-9, "bottom")
    _, am = dressed(cfg({ icons = { width = 20, height = 40, zoom = 0.1 } }))
    tc = am.icon:__last("SetTexCoord")
    T.assertNear(tc[1], 0.3, 1e-9, "tall: left"); T.assertNear(tc[2], 0.7, 1e-9, "tall: right")
    T.assertNear(tc[3], 0.1, 1e-9, "tall: top"); T.assertNear(tc[4], 0.9, 1e-9, "tall: bottom")
end)

test("icons: the border takes its style, size and color, and the dress's class when asked", function()
    local _, am = dressed(cfg({ icons = { borderShow = true, borderStyle = "Solid", borderSize = 2,
        borderColor = { r = 0.1, g = 0.2, b = 0.3, a = 0.4 }, useClassColorBorder = true } }), false,
        { r = 0.9, g = 0.8, b = 0.7 })
    assertTrue(am.border:IsShown())
    assertEqual(am.border:__last("SetBackdrop")[1].edgeSize, 2)
    -- red under: Icons.Apply dropping useClassColorBorder
    assertEqual(am.border:__joined("SetBackdropBorderColor"), "0.9,0.8,0.7,0.4")
end)

test("icons: a missing border size paints the template's, so the border and the art's inset still show", function()
    local c = cfg({ icons = { borderShow = true, borderStyle = "Solid" } })
    c.icons.borderSize = nil
    local frame, am = dressed(c)
    -- red under: Icons.Apply handing ApplyBorder the raw borderSize (a missing size hides the template's border)
    assertTrue(am.border:IsShown(), "the template's border shows")
    assertEqual(am.border:__last("SetBackdrop")[1].edgeSize, D.icons.borderSize)
    local p = am.icon:__calls("SetPoint")
    -- red under: layoutIcon's inset falling back to 0 rather than the template's size
    assertTrue(p[1][2] == frame)
    assertEqual(p[1][4], D.icons.borderSize, "inset by the template's size")
    assertEqual(p[2][4], -D.icons.borderSize)
end)

-- ── the cooldown swipe ────────────────────────────────────────────────────────────────────────

test("icons: the cooldown draws a swipe in the configured opacity, its edge and direction on their settings", function()
    local _, am = dressed(cfg({ icons = { cooldown = true, cooldownReverse = true, cooldownEdge = false,
        swipeAlpha = 0.35 } }))
    local cd = am.cd
    assertTrue(cd:IsShown())
    assertEqual(cd:__joined("SetDrawSwipe"), "true")
    -- red under: applyCooldown hard-coding the swipe direction or the edge
    assertEqual(cd:__joined("SetReverse"), "true", "reverse")
    assertEqual(cd:__joined("SetDrawEdge"), "false", "edge")
    assertEqual(cd:__joined("SetSwipeColor"), "0,0,0,0.35", "a black swipe at the configured opacity")
    local c = cfg()
    c.icons.swipeAlpha = nil
    _, am = dressed(c)
    assertEqual(am.cd:__last("SetSwipeColor")[4], D.icons.swipeAlpha, "a missing opacity is the template's")
end)

test("icons: the cooldown turned off hides the swipe and never binds it to the engine", function()
    local frame, am = dressed(cfg({ icons = { cooldown = false } }), true)
    -- red under: applyCooldown ignoring the setting
    assertFalse(am.cd:IsShown())
    assertEqual(am.cd:__joined("SetDrawSwipe"), "false")
    -- red under: Icons.Bind binding the cooldown whatever the setting
    assertEqual(frame:__count("SetDurationCooldown"), 0)
    frame, am = dressed(cfg({ icons = { cooldown = true } }), true)
    assertTrue(frame:__last("SetDurationCooldown")[1] == am.cd, "on: the engine drives our cooldown")
end)

test("icons: Blizzard's countdown numbers show only when asked for", function()
    local _, am = dressed(cfg({ icons = { blizzardNumbers = false } }))
    assertEqual(am.cd:__joined("SetHideCountdownNumbers"), "true", "hidden: our own time text reads it")
    _, am = dressed(cfg({ icons = { blizzardNumbers = true } }))
    -- red under: SetHideCountdownNumbers handed the setting un-negated
    assertEqual(am.cd:__joined("SetHideCountdownNumbers"), "false")
end)

-- ── texts ─────────────────────────────────────────────────────────────────────────────────────

test("icons: the time and stack texts are laid against the icon's frame and show on their own settings", function()
    local frame, am = dressed(cfg({ icons = { time = { point = "TOP", x = 1, y = 2 }, stacks = { show = false } } }))
    local p = am.time:__calls("SetPoint")[1]
    assertTrue(p[2] == frame)
    assertEqual(p[1], "TOP"); assertEqual(p[4], 1); assertEqual(p[5], 2)
    assertTrue(am.time:IsShown())
    -- red under: Icons.Apply showing the stack count whatever its block says
    assertFalse(am.stacks:IsShown())
end)

test("icons: the time and stack texts are boxed to the icon's width less their offsets", function()
    local _, am = dressed(cfg({ icons = { width = 40, height = 20 } }))
    -- red under: Icons.Apply handing the texts no box (their justification has nothing to align within)
    assertEqual(am.time:__last("SetWidth")[1], 40, "time, at no offset")
    assertEqual(am.stacks:__last("SetWidth")[1], 40 - 1, "stacks, 1px in")
end)

test("icons: a hidden text is never handed to the engine; a shown one is, as its own region", function()
    local frame = dressed(cfg({ icons = { time = { show = false }, stacks = { show = false } } }), true)
    -- red under: Icons.Bind binding the texts whatever their show setting
    assertEqual(frame:__count("SetDurationText"), 0, "time")
    assertEqual(frame:__count("SetApplicationCount"), 0, "stacks")
    local am
    frame, am = dressed(cfg(), true)
    assertTrue(frame:__last("SetDurationText")[1] == am.time)
    assertTrue(frame:__last("SetApplicationCount")[1] == am.stacks)
    assertTrue(frame:__last("SetIcon")[1] == am.icon)
end)

-- ── dispel border and pandemic ────────────────────────────────────────────────────────────────

test("icons: the dispel border is the engine's debuff art on harmful auras only", function()
    local NS2 = dofile("tests/fresh_env.lua")({ before = function(m)
        m.Enum = m.Enum or {}
        m.Enum.CustomAuraButtonDispelTypeTextureStyle = { Border = 31, PreserveAsset = 32 }
    end })
    local c = NS2.Database.Merge(NS2.Database.DeepCopy(NS2.CONTAINER_TEMPLATE), { style = "icons",
        icons = { dispelBorder = true } })
    local frame, am = dressed(c, true, nil, NS2)
    local add = frame:__last("AddDispelTypeTexture")
    assertTrue(add[1] == am.dispel)
    -- red under: the icon asking for PreserveAsset, which tints the whole icon instead of its border
    assertEqual(add[2].style, 31, "Blizzard's border art")
    assertTrue(add[2].showWhenHarmful, "debuffs show their type")
    assertFalse(add[2].showWhenHelpful, "buffs do not")
end)

test("icons: the dispel border turned off is hidden and never bound", function()
    local frame, am = dressed(cfg({ icons = { dispelBorder = false } }), true)
    -- red under: Icons.Apply leaving a previously shown dispel border drawn
    assertFalse(am.dispel:IsShown())
    assertEqual(am.dispel:__count("Hide"), 1)
    assertEqual(frame:__count("AddDispelTypeTexture"), 0)
    assertEqual(frame:__count("ClearDispelTypeTextures"), 1, "an earlier binding is cleared")
end)

test("icons: turning the dispel border off on a live button keeps it hidden (B-4)", function()
    local NS2 = fresh({ before = function(m)
        m.Enum = m.Enum or {}
        m.Enum.CustomAuraButtonDispelTypeTextureStyle = { Border = 31, PreserveAsset = 32 }
    end })
    local c = NS2.Database.Merge(NS2.Database.DeepCopy(NS2.CONTAINER_TEMPLATE), { style = "icons",
        icons = { dispelBorder = true } })
    local frame = R()
    NS2.Style.Element(frame, c, true)
    for k in pairs(frame.__am) do frame.__am[k] = R() end
    dofile("tests/engine_recorder.lua")(frame, { tint = { 1, 1, 1, 1 }, aura = true })
    NS2.Style.Element(frame, c, true)
    assertTrue(frame.__am.dispel:IsShown(), "on: the engine shows it")
    c.icons.dispelBorder = false
    NS2.Style.Element(frame, c, true)
    -- red under: Icons.Bind clearing the dispel texture after SetIcon, whose apply pass shows it again
    assertFalse(frame.__am.dispel:IsShown())
end)

test("icons: the refresh-window highlight is bound only when on, in the pandemic color", function()
    local frame, am = dressed(cfg({ icons = { pandemic = true, pandemicColor = { r = 1, g = 0, b = 1, a = 0.5 } } }), true)
    assertTrue(frame:__last("AddPandemicRegion")[1] == am.pandemic)
    assertEqual(am.pandemic:__joined("SetVertexColor"), "1,0,1,0.5")
    frame = dressed(cfg({ icons = { pandemic = false } }), true)
    -- red under: Icons.Bind adding the highlight whatever the setting
    assertEqual(frame:__count("AddPandemicRegion"), 0)
    assertEqual(frame:__count("ClearPandemicRegions"), 1)
end)

test("icons: an icon's buttons get the shared mouse behavior", function()
    local frame = dressed(cfg({ unit = "player", auraType = "HELPFUL",
        behavior = { tooltipAnchor = "ANCHOR_TOPRIGHT", cancelOnRightClick = true } }), true)
    -- red under: Icons.Bind without its Style.ApplyBehavior call
    assertEqual(frame:__last("SetTooltipAnchorPoint")[1], "ANCHOR_TOPRIGHT")
    assertEqual(frame:__last("SetCancelAuraButtons")[1], "RightButtonUp")
end)

-- ── built once ────────────────────────────────────────────────────────────────────────────────

test("icons: a restyle re-dresses the regions it built, and builds none", function()
    -- Its own environment: CreateFrame is counted there, never on the shared mock.
    local NS2, m2 = fresh()
    local made = 0
    local real = m2.CreateFrame
    m2.CreateFrame = function(...)
        made = made + 1
        return real(...)
    end
    local frame = R()
    NS2.Style.Element(frame, cfg(), false)
    local built, am = made, frame.__am
    assertTrue(built > 0, "the first dress builds the regions")
    NS2.Style.Element(frame, cfg({ icons = { width = 50 } }), false)
    -- red under: Icons.Apply building regions on every dress (a locked button cannot take new children)
    assertEqual(made, built, "no new frames on a restyle")
    assertTrue(frame.__am == am, "the same regions")
    assertEqual(frame:__joined("SetSize"), "50,32", "and the new look reached them")
end)

-- ── preview fill ──────────────────────────────────────────────────────────────────────────────

test("icons: a preview icon's cooldown starts as long ago as its placeholder has run", function()
    -- Its own environment: the clock is set there, never on the shared mock.
    local NS2, m2 = fresh()
    local frame, am = dressed(cfg(), false, nil, NS2)
    m2.__now = 1000
    NS2.Style.Icons.FillPreview(frame, { name = "Bloodlust", icon = 5, remaining = 28, duration = 40, stacks = 0 })
    -- red under: SetCooldown(GetTime(), duration), which draws every placeholder full
    assertEqual(am.cd:__joined("SetCooldown"), "988,40")
    assertEqual(am.time:__last("SetText")[1], "28s")
    assertEqual(am.stacks:__last("SetText")[1], "")
    assertEqual(am.icon:__last("SetTexture")[1], 5)
end)

test("icons: a timeless preview icon clears its cooldown and shows no time", function()
    local frame, am = dressed(cfg(), false)
    NS.Style.Icons.FillPreview(frame, { name = "Well Fed", icon = 1, remaining = 0, duration = 0, stacks = 4 })
    -- red under: FillPreview starting a zero-length cooldown for a timeless aura
    assertEqual(am.cd:__count("SetCooldown"), 0)
    assertEqual(am.cd:__count("Clear"), 1)
    assertEqual(am.time:__last("SetText")[1], "")
    assertEqual(am.stacks:__last("SetText")[1], "4")
end)

test("icons: filling a preview icon that was never dressed does nothing and raises nothing", function()
    local ok, err = pcall(NS.Style.Icons.FillPreview, R(), NS.Constants.PREVIEW_AURAS[1])
    -- red under: FillPreview without its missing-regions guard
    assertTrue(ok, tostring(err))
    assertNil(err)
end)
