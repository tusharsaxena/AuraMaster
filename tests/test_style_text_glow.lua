-- tests/test_style_text_glow.lua — a Text container's glow behind its text (text glow, TG-01..):
-- the stored leaves and their defaults, the removed leaves and tables gone and the twins' ring in
-- their place (TG-09), a container stored before the glow existed, which the load backfill brings up
-- to the template with the glow off, and the glyph glow's dress (TG-10, modules/Style_TextGlow.lua):
-- Text.GlowFont's color, flags and paired shadow, a twin button dressed through the same Text.Apply
-- as its main with only the look changed, a placeholder's ring of copy strings, and the docs (TG-12).
--
-- Spec: docs/superpowers/specs/2026-10-16-text-glow-addendum-glyph-glow.md (Rendering), which
-- supersedes the halo of docs/superpowers/specs/2026-10-15-text-glow-design.md; the design note is
-- docs/superpowers/research/2026-10-16-text-glow-twins-design.md, sections 3 and 4.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")

-- Every glow leaf under `container.text`, in the addendum's order.
local LEAVES = { "glow", "glowColor", "useClassColorGlow", "glowIntensity", "glowThickness", "glowX", "glowY" }

test("text glow: every leaf sits in the text template at its addendum default, the glow off", function()
    local NS = fresh()
    local t = NS.CONTAINER_TEMPLATE.text
    -- red under: any leaf missing from CONTAINER_TEMPLATE.text, or the glow on by default
    assertEqual(t.glow, false, "off by default (owner, 2026-10-15)")
    assertEqual(t.useClassColorGlow, false)
    -- red under: any leaf off the owner's defaults (2026-10-16: 50%, 4 px, X -4, Y 0)
    assertEqual(t.glowIntensity, 0.5)
    assertEqual(t.glowThickness, 4)
    assertEqual(t.glowX, -4)
    assertEqual(t.glowY, 0)
    local c = t.glowColor
    -- red under: a color without alpha (the swatch has no opacity to edit) or a color other than black
    assertTrue(type(c) == "table", "glowColor is a stored color")
    assertEqual(c.r, 0); assertEqual(c.g, 0); assertEqual(c.b, 0); assertEqual(c.a, 1)
end)

test("text glow: the old radius, blend and falloff are gone, leaves, tables and rows (TG-09)", function()
    local NS = fresh()
    local C, t = NS.Constants, NS.CONTAINER_TEMPLATE.text
    for _, key in ipairs({ "glowRadius", "glowBlend", "glowFalloff" }) do
        -- red under: a halo leaf left in the template (the backfill would plant it in every container)
        assertNil(t[key], key .. " is not a leaf")
        -- red under: a halo row left registered (the panel draws a control that changes nothing)
        assertNil(NS.FindSchemaRow("container.text." .. key), key .. " has no row")
    end
    for _, name in ipairs({ "TEXT_GLOW_BLENDS", "TEXT_GLOW_BLEND_LABELS", "TEXT_GLOW_FALLOFFS",
        "TEXT_GLOW_FALLOFF_LABELS", "TEXT_GLOW_TEXTURES" }) do
        -- red under: a halo table left in core/Constants.lua (a FontString has no blend mode or file)
        assertNil(C[name], "C." .. name .. " is gone")
    end
end)

test("text glow: the twins' ring is eight unit directions, four twins under shadow pairing (TG-09)", function()
    local NS = fresh()
    local C = NS.Constants
    -- red under: pairing off, or a twin count other than the owner's twin4s pick (four twins, each
    -- with its shadow on the opposite point, look the same as eight)
    assertEqual(C.TEXT_GLOW_PAIRED, true)
    assertEqual(C.TEXT_GLOW_TWINS, 4)
    local ring = C.TEXT_GLOW_RING
    -- red under: no ring, or a ring of other than the eight directions of a square
    assertTrue(type(ring) == "table", "C.TEXT_GLOW_RING is defined")
    assertEqual(#ring, 8, "eight directions")
    local seen = {}
    for k, d in ipairs(ring) do
        local x, y = d[1], d[2]
        -- red under: a direction off the unit square, or the center itself
        assertTrue((x == -1 or x == 0 or x == 1) and (y == -1 or y == 0 or y == 1), "direction " .. k)
        assertFalse(x == 0 and y == 0, "direction " .. k .. " is not the center")
        local key = ("%d,%d"):format(x, y)
        -- red under: a direction listed twice (a ring point never drawn)
        assertNil(seen[key], "direction " .. k .. " is new")
        seen[key] = k
    end
    -- Only under pairing do the twins' opposites belong to the shadows; with pairing off all eight
    -- are twins, and the flip stays the pins above alone.
    if C.TEXT_GLOW_PAIRED then
        for k = 1, C.TEXT_GLOW_TWINS do
            local d = ring[k]
            local opposite = seen[("%d,%d"):format(-d[1], -d[2])]   -- %d: no "-0" key for a zero
            -- red under: two opposite directions among the first four (a twin and its shadow would
            -- draw the same two points, and one opposite pair of the ring would be missing)
            assertTrue(opposite > C.TEXT_GLOW_TWINS, "twin " .. k .. "'s opposite is a shadow, not a twin")
        end
    end
end)

test("text glow: a container stored without the glow leaves is backfilled with the glow off", function()
    local NS = fresh()
    local c = NS.Database.FindContainer(1)
    c.style = "text"
    for _, k in ipairs(LEAVES) do c.text[k] = nil end
    c.text.glowThickness = 5
    NS.Database.PrepareProfile(NS.db.profile)
    -- red under: a leaf the load backfill does not reach (the renderer would index a nil), or a
    -- missing `glow` filled as on (every stored text container would light up after the update)
    assertFalse(c.text.glow, "a stored container draws no glow")
    for _, k in ipairs(LEAVES) do
        assertTrue(c.text[k] ~= nil, "backfilled: " .. k)
    end
    assertTrue(c.text.glowColor ~= NS.CONTAINER_TEMPLATE.text.glowColor,
        "the backfilled color is the container's own table, never the template's")
    -- red under: a backfill that overwrites a present leaf (Database.Backfill tests `== nil`)
    assertEqual(c.text.glowThickness, 5, "a stored value survives")
end)

test("text glow: a stored glow left on survives the backfill (savedvariables-§5)", function()
    local NS = fresh()
    local c = NS.Database.FindContainer(1)
    c.text.glow, c.text.glowThickness = true, 4
    NS.Database.PrepareProfile(NS.db.profile)
    -- red under: a load pass that rewrites present leaves from the template (an unconditional copy
    -- in place of Backfill's `== nil` test), or a migration that forces a stored `glow` back off
    assertEqual(c.text.glow, true)
    assertEqual(c.text.glowThickness, 4)
end)

-- ── the glow dress (TG-10) ─────────────────────────────────────────────────────────────────────
-- One environment with the client's text APIs as recording stand-ins (tests/text_apis.lua), built
-- once, every element on tests/region_builder.lua's recorders, as tests/test_style_text.lua does.

local B = dofile("tests/region_builder.lua")
local R = dofile("tests/region_recorder.lua")

local env
local function E()
    if not env then
        local NS, m = fresh({ before = dofile("tests/text_apis.lua") })
        env = { NS = NS, m = m }
    end
    return env.NS, env.m
end

--- A Text container's settings, `over` merged onto the template's text block.
local function text(over)
    local NS = E()
    local c = NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE)
    c.style = "text"
    return NS.Database.Merge(c, { text = over or {} })
end

--- Dress `frame` (a new builder when nil) for `c`, as twin `twin` when given; the frame and its regions.
local function dress(c, frame, engine, classColor, twin)
    local NS, m = E()
    frame = frame or B.new({})
    B.during(m, {}, function() NS.Style.Element(frame, c, engine or false, classColor, twin) end)
    return frame, frame.__am
end

local function pieces(am)
    local out = {}
    for i = 1, am.pieceCount do out[i] = am["piece" .. i] end
    return out
end

--- Font string `fs`'s last SetPoint, its anchor frame left out: "point,relPoint,x,y".
local function pointOf(fs)
    local p = fs:__last("SetPoint")
    return ("%s,%s,%s,%s"):format(tostring(p[1]), tostring(p[3]), tostring(p[4]), tostring(p[5]))
end

--- Whether every copy of `set` is hidden (true for a set never built).
local function allHidden(set)
    if set == nil then return true end
    for _, copy in ipairs(set) do
        if copy:IsShown() then return false end
    end
    return true
end

test("text glow: GlowFont paints the glow color with its alpha times the intensity", function()
    local NS = E()
    local fs = R()
    NS.Style.Text.GlowFont(fs, text({ glowIntensity = 0.5, glowColor = { r = 0.1, g = 0.2, b = 0.3, a = 0.8 } }).text, 1)
    -- red under: the font's own color kept (white), the intensity dropped (alpha 0.8), or applied to the
    -- color channels too
    assertEqual(fs:__joined("SetTextColor"), "0.1,0.2,0.3,0.4")
end)

test("text glow: GlowFont drops the outline and keeps MONOCHROME, in the font's own face and size", function()
    local NS = E()
    local want = { NONE = "", OUTLINE = "", THICKOUTLINE = "", MONOCHROME = "MONOCHROME",
        MONOCHROMEOUTLINE = "MONOCHROME" }
    for stored, flags in pairs(want) do
        local s = text({ font = { fontFlags = stored, fontSize = 17 } }).text
        local fs = R()
        NS.Style.Text.GlowFont(fs, s, 1)
        local path, size = NS.Style.FontKey(s.font, NS.CONTAINER_TEMPLATE.text.font)
        local got = fs:__last("SetFont")
        -- red under: the outline kept (the Slug outline is black and takes no color: a dark ring)
        assertEqual(got[3], flags, stored)
        -- red under: MONOCHROME dropped with the outline, or the face or size not the main's
        assertEqual(got[1], path, stored .. " face")
        assertEqual(got[2], size, stored .. " size")
    end
end)

test("text glow: under pairing, copy k's shadow is the glow color at -2 x thickness x d_k", function()
    local NS = E()
    local C = NS.Constants
    local s = text({ glowThickness = 3, glowIntensity = 0.5, glowColor = { r = 0.1, g = 0.2, b = 0.3, a = 0.8 },
        font = { fontShadow = true } }).text
    for k = 1, C.TEXT_GLOW_TWINS do
        local fs = R()
        NS.Style.Text.GlowFont(fs, s, k)
        local d = C.TEXT_GLOW_RING[k]
        local want = ("%d,%d"):format(-6 * d[1], -6 * d[2])
        -- red under: the font's own shadow (1, -1) reaching the twin, the offset at +2td (the shadow
        -- on the twin's own side), or at -td (the main's point, not the ring's opposite one)
        assertEqual(fs:__joined("SetShadowOffset"), want, "copy " .. k)
        -- red under: a black shadow (the font's), or one at the color's full alpha
        assertEqual(fs:__joined("SetShadowColor"), "0.1,0.2,0.3,0.4", "copy " .. k .. " color")
    end
end)

test("text glow: with pairing off, a copy draws no shadow", function()
    local NS = E()
    local C = NS.Constants
    local s = text({ glowThickness = 3, font = { fontShadow = true } }).text
    C.TEXT_GLOW_PAIRED = false
    local fs = R()
    local ok, err = pcall(NS.Style.Text.GlowFont, fs, s, 5)
    C.TEXT_GLOW_PAIRED = true
    assertTrue(ok, tostring(err))
    -- red under: the pairing flag read once at load (the flip would change nothing), or the font's own
    -- shadow taken when pairing is off
    assertEqual(fs:__joined("SetShadowOffset"), "0,0")
    assertEqual(fs:__count("SetShadowColor"), 0)
end)

test("text glow: a twin is laid out as its main: the same size and the same piece points", function()
    local c = text({ template = "$spellname$[ x$stacks$][ - $remainingduration$]", icon = "LEFT",
        justifyH = "LEFT", x = 3, y = -2 })
    local main, mam = dress(c, nil, true)
    local twin, tam = dress(c, nil, true, nil, 1)
    -- red under: a twin given a size of its own (a button with no size is never placed, owner probe)
    assertEqual(twin:__joined("SetSize"), main:__joined("SetSize"))
    local mp, tp = pieces(mam), pieces(tam)
    assertEqual(#tp, #mp)
    for i = 1, #mp do
        -- red under: a twin chain laid out by other code than the main's (layoutChain), or the icon's
        -- room dropped from the twin's text area (its text would sit an icon's width to the left)
        assertEqual(pointOf(tp[i]), pointOf(mp[i]), "piece " .. i)
    end
    local ma, ta = mam.area:__calls("SetPoint"), tam.area:__calls("SetPoint")
    assertEqual(#ta, #ma, "the area's points")
    for i = 1, #ma do assertEqual(ta[i][4], ma[i][4], "area point " .. i .. " x") end
end)

test("text glow: a twin's chain is pulled back by the padding of the un-outlined font it draws", function()
    -- A fresh environment (the padding cache is per load) measuring 6 per character plus a padding of
    -- 4 per string in an outlined font and 1 without, so the outlined pull is 4 and the twin's 1.
    local NS, m = fresh({ before = dofile("tests/text_apis.lua") })
    local fs = R()
    fs.__answer.GetStringWidth = function()
        local flags = tostring(fs:__last("SetFont")[3])
        return fs:__last("SetText")[1]:len() * 6 + (flags:find("OUTLINE") and 4 or 1)
    end
    NS.Style.__measurer = function() return fs end
    local c = NS.Database.Merge(NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE), { style = "text",
        text = { template = "$spellname$ - $remainingduration$", justifyH = "LEFT", fontFlags = "OUTLINE" } })
    local function chained(twin)
        local frame = B.new({})
        B.during(m, {}, function() NS.Style.Element(frame, c, true, nil, twin) end)
        return pieces(frame.__am)
    end
    local main, twin = chained(nil), chained(1)
    assertEqual(#twin, 3, "three pieces")
    for i = 2, 3 do
        assertEqual(main[i]:__last("SetPoint")[4], -4, "main piece " .. i .. ": the outlined padding")
        -- red under: a twin pulled by the main's outlined padding (each piece off its main text by
        -- the difference, accumulating along the line, twins design note risk R1)
        assertEqual(twin[i]:__last("SetPoint")[4], -1, "twin piece " .. i .. ": the un-outlined padding")
    end
end)

test("text glow: a twin's icon is laid out but hidden and never bound; the main's is bound", function()
    local c = text({ template = "$spellname$", icon = "LEFT", iconBorderShow = true })
    local main, mam = dress(c, nil, true)
    local twin, tam = dress(c, nil, true, nil, 1)
    assertEqual(main:__count("SetIcon"), 1, "the main binds its icon")
    -- red under: the twin binding SetIcon (the engine would show a second icon under the main's)
    assertEqual(twin:__count("SetIcon"), 0)
    -- red under: the twin's icon or border left shown by the layout
    assertFalse(tam.icon:IsShown(), "the icon hidden")
    assertFalse(tam.iconBorder:IsShown(), "the border hidden")
    -- red under: the icon skipped on the twin rather than laid out and hidden (Text.Apply's one path)
    assertTrue(mam.icon:__joined("SetSize") ~= nil, "the main's icon is sized")
    assertEqual(tam.icon:__joined("SetSize"), mam.icon:__joined("SetSize"), "the icon laid out")
end)

test("text glow: a twin takes no dispel tints and a dispel word with no color escape", function()
    local c = text({ template = "$spellname$[ ($dispeltype$)]", dispelBackdrop = true, dispelEdge = true,
        dispelTypeColor = true })
    local main = dress(c, nil, true)
    local twin = dress(c, nil, true, nil, 1)
    assertTrue(main:__count("AddDispelTypeTexture") > 0, "the main hands its tints over")
    -- red under: the twin handing its backdrop or edge to the engine (a tinted box under the glow)
    assertEqual(twin:__count("AddDispelTypeTexture"), 0)
    local mainMap = main:__last("SetDispelTypeText")[2].customDispelTextMap
    local map = twin:__last("SetDispelTypeText")[2].customDispelTextMap
    local colored = false
    for _, word in pairs(mainMap) do colored = colored or word:find("|c", 1, true) ~= nil end
    assertTrue(colored, "the main's words are colored")
    for t, word in pairs(map) do
        -- red under: the twin's map built from the line's palette (a |c escape paints the glow word)
        assertTrue(word:find("|c", 1, true) == nil, t .. " plain")
    end
end)

test("text glow: a twin's duration is bound with no time color and the plain binding, in the same format", function()
    local c = text({ template = "$spellname$[ - $remainingduration$]", expiringColorOn = true,
        expiringBlink = true })
    local main = dress(c, nil, true)
    local twin, tam = dress(c, nil, true, nil, 1)
    local m, t = main:__last("SetDurationText"), twin:__last("SetDurationText")
    assertTrue(m[2].textColor ~= nil, "the main's run turns red and blinks")
    -- red under: the twin handed the line's curve (the engine would turn the glow red, and blink it)
    assertNil(t[2].textColor)
    -- red under: the blink's refreshing binding on the twin (it has no blink to refresh)
    assertTrue(t[2].binding == tam.binding, "the plain binding")
    -- red under: another text format on the twin (its digits would not match the main's)
    assertTrue(t[2].textFormat == m[2].textFormat, "the same text format")
    assertTrue(t[1] == pieces(tam)[2], "bound to the twin's own duration piece")
end)

test("text glow: a twin takes no mouse, cancels nothing and binds no tooltip", function()
    local NS = E()
    local c = text({ template = "$spellname$" })
    c.unit, c.auraType = "player", "HELPFUL"
    c.behavior.cancelOnRightClick = true
    local main = dress(c, nil, true)
    assertEqual(main:__joined("SetCancelAuraButtons"), "RightButtonUp", "the main cancels")
    local twin = dress(c, nil, true, nil, 1)
    -- red under: the twin dressed with Style.ApplyBehavior (it would hold the hover and the right-click)
    assertEqual(twin:__joined("SetMouseMotionEnabled"), "false")
    assertEqual(twin:__joined("SetMouseClickEnabled"), "false")
    assertEqual(twin:__joined("SetCancelAuraButtons"), "nil")
    assertEqual(twin:__count("SetTooltipAnchorPoint") + twin:__count("SetHideTooltipInCombat"), 0)
    assertTrue(NS.Style.TakesHover(c), "the main's container takes the hover")
end)

test("text glow: a twin's pieces wear the glow (class color from the snapshot), a literal its text, the loop the main's", function()
    local class = { r = 0.2, g = 0.4, b = 0.6 }
    local c = text({ template = "$spellname$ :: $stacks$", justifyH = "LEFT", anim = "pulse", glowIntensity = 0.5,
        useClassColorGlow = true, glowColor = { r = 1, g = 1, b = 1, a = 1 }, font = { fontFlags = "OUTLINE" } })
    local _, am = dress(c, nil, true, class, 2)
    for i, fs in ipairs(pieces(am)) do
        -- red under: the twin dressed through Style.ApplyFont (the font color, with the outline), or
        -- the class read off the player and not the container's snapshot
        assertEqual(fs:__joined("SetTextColor"), "0.2,0.4,0.6,0.5", "piece " .. i)
        assertEqual(fs:__last("SetFont")[3], "", "piece " .. i .. " flags")
    end
    -- red under: a literal skipped on the twin (the ring would miss the line's plain text)
    assertEqual(pieces(am)[2]:__joined("SetText"), " :: ")
    -- red under: no loop on the twin (the main pulses while its glow stands still)
    assertEqual(am.pulseGroup:__count("Play"), 1)
end)

test("text glow: a main button keeps the font's outline and shadow with the glow on, and builds no copies", function()
    local c = text({ template = "$spellname$ $stacks$", glow = true,
        font = { fontFlags = "OUTLINE", fontShadow = true } })
    local _, am = dress(c, nil, true)
    for i, fs in ipairs(pieces(am)) do
        -- red under: a glow that replaces the main's outline or shadow (owner: it adds to them)
        assertEqual(fs:__last("SetFont")[3], "OUTLINE", "piece " .. i .. " outline")
        assertEqual(fs:__joined("SetShadowOffset"), "1,-1", "piece " .. i .. " shadow")
    end
    -- red under: copy strings on a live button (it cannot copy the engine's secret text; its glow is
    -- the twins')
    assertNil(am.glow1, "no copies on an engine button")
end)

-- ── the preview copies (TG-10) ─────────────────────────────────────────────────────────────────

local AURA = { name = "Renew", icon = 135953, remaining = 2, duration = 10, stacks = 3, dispel = "Magic" }

--- Dress a placeholder for `c` and fill it with `aura`; the frame and its regions.
local function preview(c, frame, aura, made)
    local NS, m = E()
    frame = frame or B.new(made or {})
    B.during(m, made or {}, function()
        NS.Style.Element(frame, c, false)
        NS.Style.Text.FillPreview(frame, aura or AURA, c)
    end)
    return frame, frame.__am
end

test("text glow: a placeholder gets a ring of copies per piece on anim's BACKGROUND, under the icon", function()
    local NS = E()
    local C = NS.Constants
    local c = text({ template = "$spellname$[ x$stacks$]", glow = true, icon = "LEFT" })
    local _, am = preview(c)
    for i = 1, am.pieceCount do
        local set = am["glow" .. i]
        -- red under: no copies built, or a count other than the twins' (the preview and the live look
        -- would differ)
        assertTrue(type(set) == "table", "piece " .. i .. " has copies")
        assertEqual(#set, C.TEXT_GLOW_TWINS, "piece " .. i .. " copy count")
        for j, copy in ipairs(set) do
            local name = ("piece %d copy %d"):format(i, j)
            -- red under: copies on the chain or the area (over the icon, cut at the text box) or above
            -- BACKGROUND
            assertTrue(copy.parent == am.anim, name .. " on anim")
            assertEqual(copy.args[2], "BACKGROUND", name .. " created on BACKGROUND")
            -- red under: the layer left to the create call (CreateFontString takes no sublevel; the
            -- last string created would draw on top)
            assertEqual(copy:__joined("SetDrawLayer"), "BACKGROUND,0", name .. " SetDrawLayer")
            assertTrue(copy:IsShown(), name .. " shown")
        end
    end
    assertEqual(am.glowCount, am.pieceCount)
    assertTrue(am.icon.parent == am.anim and am.icon.args[2] == "ARTWORK", "the icon a layer above")
end)

test("text glow: copy j sits on its piece's rect moved by thickness x d_j + (X, Y), dressed as twin j", function()
    local NS = E()
    local C = NS.Constants
    local c = text({ template = "$spellname$[ x$stacks$]", justifyH = "RIGHT", glow = true, glowThickness = 3,
        glowX = 4, glowY = -5, glowIntensity = 0.5, glowColor = { r = 0.1, g = 0.2, b = 0.3, a = 0.8 } })
    local _, am = preview(c)
    for i, fs in ipairs(pieces(am)) do
        for j, copy in ipairs(am["glow" .. i]) do
            local d = C.TEXT_GLOW_RING[j]
            local x, y = 3 * d[1] + 4, 3 * d[2] - 5
            local pts = copy:__calls("SetPoint")
            local name = ("piece %d copy %d"):format(i, j)
            -- red under: copies anchored to the area or the chain (the box, not the letters), the ring
            -- offset dropped, or the X/Y shift left out
            assertEqual(#pts, 2, name .. " two points")
            assertTrue(pts[1][2] == fs and pts[2][2] == fs, name .. " on its own piece")
            assertEqual(("%s,%s,%s,%s"):format(pts[1][1], pts[1][3], pts[1][4], pts[1][5]),
                ("TOPLEFT,TOPLEFT,%d,%d"):format(x, y), name .. " top left")
            assertEqual(("%s,%s,%s,%s"):format(pts[2][1], pts[2][3], pts[2][4], pts[2][5]),
                ("BOTTOMRIGHT,BOTTOMRIGHT,%d,%d"):format(x, y), name .. " bottom right")
            -- red under: a copy justified otherwise than its piece (its text would sit apart)
            assertEqual(copy:__joined("SetJustifyH"), "RIGHT", name .. " justify")
            -- red under: copies dressed by other code than the twins' (GlowFont): the font's color
            assertEqual(copy:__joined("SetTextColor"), "0.1,0.2,0.3,0.4", name .. " color")
            assertEqual(copy:__joined("SetShadowOffset"), ("%d,%d"):format(-6 * d[1], -6 * d[2]), name .. " shadow")
        end
    end
end)

test("text glow: copies take their piece's text, the dispel word uncolored, never the run color", function()
    local c = text({ template = "$spellname$[ ($dispeltype$)][ - $remainingduration$]", glow = true,
        dispelTypeColor = true, expiringColorOn = true, expiringThreshold = 5 })
    local _, am = preview(c)
    local p = pieces(am)
    for i, fs in ipairs(p) do
        for j, copy in ipairs(am["glow" .. i]) do
            local text1 = fs:__joined("SetText")
            if i == 2 then
                -- red under: the dispel copies given the colored word (a |c escape paints the glow)
                assertTrue(text1:find("|c", 1, true) ~= nil, "the piece's word is colored")
                assertEqual(copy:__joined("SetText"), text1:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""),
                    "copy " .. j .. " plain word")
            else
                -- red under: a copy left without its piece's text (the preview would show no ring)
                assertEqual(copy:__joined("SetText"), text1, ("piece %d copy %d"):format(i, j))
            end
        end
    end
    -- red under: the run color applied to the copies (previewRunColor), as the live twin never has it
    local glowColor = am.glow3[1]:__joined("SetTextColor")
    assertTrue(p[3]:__joined("SetTextColor") ~= glowColor, "the piece took the running-out color")
    for j, copy in ipairs(am.glow3) do assertEqual(copy:__count("SetTextColor"), 1, "copy " .. j) end
end)

test("text glow: copies are hidden while off, on an engine button, past the pieces and on a stacked literal", function()
    local NS = E()
    local c = text({ template = "$spellname$ :: $stacks$ - $remainingduration$", justifyH = "LEFT", glow = true })
    local frame, am = preview(c)
    assertEqual(am.glowCount, 5)
    c.text.glow = false
    preview(c, frame)
    for i = 1, 5 do
        -- red under: an off dress that returns before hiding what an earlier dress drew
        assertTrue(allHidden(am["glow" .. i]), "off: piece " .. i)
    end
    c.text.glow = true
    c.text.justifyH = "CENTER"
    preview(c, frame)
    for i, piece in ipairs(NS.Style.Text.Compiled(c.text).pieces) do
        local hidden = allHidden(am["glow" .. i])
        -- red under: copies left on a stacked line's hidden literal (a glowing " :: " with no text over it)
        assertEqual(hidden, piece.kind == "literal", "stacked piece " .. i)
    end
    c.text.template = "$spellname$[ x$stacks$]"
    preview(c, frame)
    assertTrue(not allHidden(am.glow1) and not allHidden(am.glow2), "the new shape's pieces")
    for i = 3, 5 do
        -- red under: copies past the new pieceCount left as the old shape drew them
        assertTrue(allHidden(am["glow" .. i]), "past the pieces: " .. i)
    end
    dress(c, frame, true)
    -- red under: an engine dress that leaves a placeholder's copies shown (a pooled frame reused)
    for i = 1, am.glowCount do assertTrue(allHidden(am["glow" .. i]), "engine: " .. i) end
end)

test("text glow: a new template shape re-anchors the copies to the new chain's strings", function()
    local c = text({ template = "$spellname$ $stacks$", glow = true })
    local frame, am = preview(c)
    local old = am.piece1
    c.text.template = "$stacks$ - $spellname$ ($dispeltype$)"
    preview(c, frame)
    assertTrue(am.piece1 ~= old, "a new chain")
    for i, fs in ipairs(pieces(am)) do
        for j, copy in ipairs(am["glow" .. i]) do
            -- red under: copies still anchored to the stashed chain's strings (hidden with it)
            assertTrue(copy:__last("SetPoint")[2] == fs, ("piece %d copy %d"):format(i, j))
        end
    end
end)

test("text glow: a container with only the glow's class-color companion on is class-colored", function()
    local NS = E()
    local c = text({ useClassColorGlow = true })
    c.text.font.useClassColorFont = false
    -- red under: a UsesClassColor that skipped the text block's own flags (a unit swap would never
    -- re-dress the glow); this pins existing Style behavior, so it is green before TG-02 too
    assertTrue(NS.Style.UsesClassColor(c), "the companion alone")
    c.text.useClassColorGlow = false
    assertFalse(NS.Style.UsesClassColor(c), "and nothing else in the block is")
end)

--- `path`'s text with CR stripped, so a match never trips on the repo's CRLF.
local function readDoc(path)
    local f = assert(io.open(path, "r"), "cannot open " .. path)
    local body = f:read("*a")
    f:close()
    return (body:gsub("\r", ""))
end

test("text glow: the docs name every glow leaf on the Font tab row and the twins' limits", function()
    local fontRow = readDoc("docs/settings-panel.md"):match("\n| Font | ([^\n]*)")
    assertTrue(fontRow ~= nil, "docs/settings-panel.md has the Text section's Font row")
    for _, key in ipairs(LEAVES) do
        -- red under: the Font row without its Glow paths (spec G6)
        assertTrue(fontRow:find("`" .. key .. "`", 1, true) ~= nil, "the Font row names " .. key)
    end
    local bullet = readDoc("docs/known-limitations.md"):match("\n%- %*%*A glowing Text container(.-)\n%- ")
    -- red under: docs/known-limitations.md still on the halo's bullet (the glyph glow addendum's limits)
    assertTrue(bullet ~= nil, "docs/known-limitations.md has the twins' bullet")
    -- red under: a limit of the addendum's four left out (twin cost, sort tie, loop phase, the clip)
    for _, word in ipairs({ "C.TEXT_GLOW_TWINS", "UNIT_AURA", "perf", "sort", "phase", "hand-set", "Width",
        "shadow" }) do
        assertTrue(bullet:find(word, 1, true) ~= nil, "the twins' bullet names " .. word)
    end
    -- red under: the paired shadow's cut said to grow with Offset X or Y (the offset moves the
    -- twin's box with its shadow, so the cut stays at twice the Thickness)
    local flat = bullet:gsub("%s+", " ")
    assertTrue(flat:find("Thickness (12 px at 6) plus", 1, true) == nil, "the shadow's cut is 2t")
    -- red under: fd0a5a2's clip sentence, which said the shadow's cut grows by the offset and the ring
    -- is cut wherever it reaches past the box (a twin's box moves with it, so only the paired shadows
    -- are cut, and the live trim is lopsided)
    assertTrue(flat:find("add nothing to that cut", 1, true) ~= nil, "the offsets add nothing to the cut")
    assertTrue(flat:find("lopsided", 1, true) ~= nil, "the bullet says the live trim is lopsided")
    -- red under: f1d31b0's bullet, silent on Blink (twins design note Q2: the glow stays lit)
    assertTrue(flat:find("Blink", 1, true) ~= nil and flat:find("ghost of the digits", 1, true) ~= nil,
        "the bullet says the glow stays lit under Blink")
    local limits = readDoc("docs/ARCHITECTURE.md"):match("\n## Known Limitations\n(.-)\n## ")
    -- red under: ARCHITECTURE's summary still calling the glow a halo around the text's bounds
    assertTrue(limits ~= nil and limits:find("twin engines", 1, true) ~= nil, "ARCHITECTURE names the twins")
end)

test("text glow: no living doc still describes the removed glow textures", function()
    local docs = { "README.md" }
    local p = io.popen("ls docs/*.md")
    for path in p:lines() do
        -- docs/test-cases.md is generated from case names, and a removal case names what it removed
        if path ~= "docs/test-cases.md" then docs[#docs + 1] = path end
    end
    p:close()
    -- red under: a glob that found nothing (the scan would pass blind)
    assertTrue(#docs > 10, "docs/*.md listed")
    local stale = { "halo", "nine-slice", "genericglow", "glowradius", "glowblend", "glowfalloff",
        "text_glow_textures", "text_glow_blends", "text_glow_falloffs", "falloff", "blend mode" }
    local hits = {}
    for _, path in ipairs(docs) do
        local n = 0
        for line in (readDoc(path) .. "\n"):gmatch("([^\n]*)\n") do
            n = n + 1
            local low = line:lower()
            for _, word in ipairs(stale) do
                if low:find(word, 1, true) then hits[#hits + 1] = ("%s:%d %s"):format(path, n, word) end
            end
        end
    end
    -- red under: a doc still on the rejected halo (the glyph glow addendum removed it, TG-12)
    assertEqual(table.concat(hits, ", "), "", "no doc describes the halo")
end)

test("text glow: docs/midnight-quirks.md records the 12.1 glow probe", function()
    local section = readDoc("docs/midnight-quirks.md"):match("\n## A glyph glow needs twin engines(.-)\n## ")
    -- red under: no section for the owner's AMGlowProbe facts (the glyph glow addendum)
    assertTrue(section ~= nil, "docs/midnight-quirks.md has the glow section")
    for _, word in ipairs({ "Slug", "black", "sublevel", "SetDrawLayer", "SetSize", "GetSize", "secret",
        "shadow", "C.TEXT_GLOW_TWINS", "modules/Container_Twins.lua" }) do
        -- red under: a probe fact left out (the outline's color, the layer, placement, secret size, pairing)
        assertTrue(section:find(word, 1, true) ~= nil, "the glow section names " .. word)
    end
    local open = (section .. "\n"):match("\n%*%*Not yet probed%*%*(.-)\n\n")
    -- red under: the open questions without the fixed-level holders the design note names (twins
    -- design R2: the outcome of SetFixedFrameLevel on the holders is recorded here)
    assertTrue(open ~= nil and open:find("SetFixedFrameLevel", 1, true) ~= nil,
        "the fixed flag is open")
end)

test("text glow: the glyph glow's smoke checks are written and wait for the owner", function()
    local body = readDoc("docs/smoke-tests.md")
    -- red under: the index or the pending list still ending at TEXT-34 (the twins' checks missing)
    assertTrue(body:find("| TEXT-1 to TEXT-36 |", 1, true) ~= nil, "the index runs to TEXT-36")
    assertTrue(body:find("\n- TEXT-30 to TEXT-36 ", 1, true) ~= nil, "TEXT-30 to TEXT-36 are pending")
    for id = 30, 36 do
        local check = body:match("\n%*%*TEXT%-" .. id .. "%. (.-)\n\n")
        -- red under: a glow check missing, or marked passed before the owner ran it
        assertTrue(check ~= nil, "TEXT-" .. id .. " is written")
        assertTrue(check:match("Result:%s*$") ~= nil, "TEXT-" .. id .. " has an empty Result line")
    end
    local level = body:match("\n%*%*TEXT%-35%. (.-)\n\n")
    -- red under: TEXT-35 running only the re-level path (twins design R2: with and without the
    -- fixed flag)
    assertTrue(level:find("SetFixedFrameLevel", 1, true) ~= nil,
        "TEXT-35 runs the fixed-flag variant")
end)
