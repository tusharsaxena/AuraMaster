-- tests/test_style_text_glow.lua — a Text container's glow behind its text (text glow, TG-01..):
-- the stored leaves and their defaults, the blend and falloff choices, a container stored before
-- the glow existed, which the load backfill brings up to the template with the glow off, and the
-- render (modules/Style_TextGlow.lua): the nine-slice sets, their anchors per justify and per stacked
-- row, the falloff, blend and color, and the outline and shadow kept.
--
-- Spec: docs/superpowers/specs/2026-10-15-text-glow-design.md G1, G2, G3 and G5.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")

-- Every glow leaf under `container.text`, in G1's order.
local LEAVES = { "glow", "glowColor", "useClassColorGlow", "glowIntensity", "glowRadius", "glowBlend",
    "glowFalloff", "glowX", "glowY" }

test("text glow: every leaf sits in the text template at its G1 default, the glow off", function()
    local NS = fresh()
    local t = NS.CONTAINER_TEMPLATE.text
    -- red under: any leaf missing from CONTAINER_TEMPLATE.text, or the glow on by default
    assertEqual(t.glow, false, "off by default (owner, 2026-10-15)")
    assertEqual(t.useClassColorGlow, false)
    assertEqual(t.glowIntensity, 0.6)
    assertEqual(t.glowRadius, 6)
    assertEqual(t.glowBlend, "BLEND")
    assertEqual(t.glowFalloff, "soft")
    assertEqual(t.glowX, 0)
    assertEqual(t.glowY, 0)
    local c = t.glowColor
    -- red under: a color without alpha (the swatch has no opacity to edit) or a color other than gold
    assertTrue(type(c) == "table", "glowColor is a stored color")
    assertEqual(c.r, 1); assertEqual(c.g, 0.82); assertEqual(c.b, 0); assertEqual(c.a, 1)
end)

test("text glow: the blend and falloff choices are labeled, and each default is one of them", function()
    local NS = fresh()
    local C, t = NS.Constants, NS.CONTAINER_TEMPLATE.text
    local pairsOf = {
        { C.TEXT_GLOW_BLENDS, C.TEXT_GLOW_BLEND_LABELS, t.glowBlend, "BLEND,ADD" },
        { C.TEXT_GLOW_FALLOFFS, C.TEXT_GLOW_FALLOFF_LABELS, t.glowFalloff, "soft,hard" },
    }
    for _, p in ipairs(pairsOf) do
        local list, labels, default, want = p[1], p[2], p[3], p[4]
        -- red under: either list or its labels missing from core/Constants.lua
        assertTrue(type(list) == "table" and type(labels) == "table", "declared: " .. want)
        assertEqual(table.concat(list, ","), want, "the values, in dropdown order")
        local seen = false
        for _, v in ipairs(list) do
            -- red under: a value with no label (its dropdown entry reads blank)
            assertTrue(type(labels[v]) == "string" and labels[v] ~= "", "a label for " .. v)
            seen = seen or v == default
        end
        -- red under: a template default the dropdown cannot show
        assertTrue(seen, "the default " .. tostring(default) .. " is a choice")
    end
    assertEqual(C.TEXT_GLOW_BLEND_LABELS.BLEND, "Normal")
    assertEqual(C.TEXT_GLOW_BLEND_LABELS.ADD, "Additive")
    assertEqual(C.TEXT_GLOW_FALLOFF_LABELS.soft, "Soft")
    assertEqual(C.TEXT_GLOW_FALLOFF_LABELS.hard, "Hard")
end)

test("text glow: a container stored without the glow leaves is backfilled with the glow off", function()
    local NS = fresh()
    local c = NS.Database.FindContainer(1)
    c.style = "text"
    for _, k in ipairs(LEAVES) do c.text[k] = nil end
    c.text.glowRadius = 12
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
    assertEqual(c.text.glowRadius, 12, "a stored value survives")
end)

test("text glow: a stored glow left on survives the backfill (savedvariables-§5)", function()
    local NS = fresh()
    local c = NS.Database.FindContainer(1)
    c.text.glow, c.text.glowBlend = true, "ADD"
    NS.Database.PrepareProfile(NS.db.profile)
    -- red under: a load pass that rewrites present leaves from the template (an unconditional copy
    -- in place of Backfill's `== nil` test), or a migration that forces a stored `glow` back off
    assertEqual(c.text.glow, true)
    assertEqual(c.text.glowBlend, "ADD")
end)

-- ── the render (TG-02, G3) ─────────────────────────────────────────────────────────────────────
-- One environment with the client's text APIs as recording stand-ins (tests/text_apis.lua), built
-- once, every element on tests/region_builder.lua's recorders, as tests/test_style_text.lua does.
-- The falloff files are the shipped C.TEXT_GLOW_TEXTURES, never planted ones (TG-05).

local B = dofile("tests/region_builder.lua")

local env
local function E()
    if not env then
        local NS, m = fresh({ before = dofile("tests/text_apis.lua") })
        env = { NS = NS, m = m }
    end
    return env.NS, env.m
end

--- The shipped file for falloff `key` ("soft" or "hard").
local function file(key)
    local files = E().Constants.TEXT_GLOW_TEXTURES
    return files and files[key]
end

--- A Text container's settings, `over` merged onto the template's text block.
local function text(over)
    local NS = E()
    local c = NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE)
    c.style = "text"
    return NS.Database.Merge(c, { text = over or {} })
end

--- Dress `frame` (a new builder when nil) for `c`; the frame and its regions.
local function dress(c, frame, engine, classColor)
    local NS, m = E()
    frame = frame or B.new({})
    B.during(m, {}, function() NS.Style.Element(frame, c, engine or false, classColor) end)
    return frame, frame.__am
end

-- The nine pieces of a set: each key, the part of the texture it samples (left, right, top, bottom)
-- and its anchors as { point, "L" or "R", the font string's point }, as G3 lays them out.
local PARTS = {
    { "topLeft",     "0,0.5,0,0.5",     { { "BOTTOMRIGHT", "L", "TOPLEFT" } } },
    { "topRight",    "0.5,1,0,0.5",     { { "BOTTOMLEFT", "R", "TOPRIGHT" } } },
    { "bottomLeft",  "0,0.5,0.5,1",     { { "TOPRIGHT", "L", "BOTTOMLEFT" } } },
    { "bottomRight", "0.5,1,0.5,1",     { { "TOPLEFT", "R", "BOTTOMRIGHT" } } },
    { "top",    "0.5,0.5,0,0.5", { { "BOTTOMLEFT", "L", "TOPLEFT" }, { "BOTTOMRIGHT", "R", "TOPRIGHT" } } },
    { "bottom", "0.5,0.5,0.5,1", { { "TOPLEFT", "L", "BOTTOMLEFT" }, { "TOPRIGHT", "R", "BOTTOMRIGHT" } } },
    { "left",   "0,0.5,0.5,0.5", { { "TOPRIGHT", "L", "TOPLEFT" }, { "BOTTOMRIGHT", "L", "BOTTOMLEFT" } } },
    { "right",  "0.5,1,0.5,0.5", { { "TOPLEFT", "R", "TOPRIGHT" }, { "BOTTOMLEFT", "R", "BOTTOMRIGHT" } } },
    { "center", "0.5,0.5,0.5,0.5", { { "TOPLEFT", "L", "TOPLEFT" }, { "BOTTOMRIGHT", "R", "BOTTOMRIGHT" } } },
}

--- The SetPoint calls `tex` took since its last ClearAllPoints, oldest first; nil with none.
local function sinceClear(tex)
    local out
    for _, e in ipairs(tex.__log) do
        if e.name == "ClearAllPoints" then
            out = {}
        elseif e.name == "SetPoint" and out then
            out[#out + 1] = e.args
        end
    end
    return out
end

--- Assert set `set` is shown and anchored to font strings `left` and `right`, offset by x/y, `r` deep.
local function assertSet(set, left, right, x, y, r, label)
    assertTrue(type(set) == "table", label .. ": the set is built")
    for _, part in ipairs(PARTS) do
        local tex, name = set[part[1]], label .. " " .. part[1]
        assertTrue(tex ~= nil and tex:IsShown(), name .. " shown")
        assertEqual(tex:__joined("SetTexCoord"), part[2], name .. " samples its slice")
        local points = sinceClear(tex)
        assertTrue(points ~= nil, name .. " re-anchored on the dress")
        assertEqual(#points, #part[3], name .. " anchor count")
        for i, want in ipairs(part[3]) do
            local pt = points[i]
            local to = want[2] == "L" and left or right
            assertEqual(pt[1], want[1], name .. " point " .. i)
            assertTrue(pt[2] == to, name .. " anchored to the " .. want[2] .. " font string")
            assertEqual(pt[3], want[3], name .. " relative point " .. i)
            assertEqual(pt[4], x, name .. " x"); assertEqual(pt[5], y, name .. " y")
        end
    end
    assertEqual(set.topLeft:__joined("SetSize"), r .. "," .. r, label .. ": a corner is r x r")
    assertEqual(set.top:__joined("SetHeight"), tostring(r), label .. ": the top edge r tall")
    assertEqual(set.left:__joined("SetWidth"), tostring(r), label .. ": the left edge r wide")
    assertEqual(set.center:__count("SetSize") + set.center:__count("SetWidth") + set.center:__count("SetHeight"),
        0, label .. ": the center takes its size from its anchors")
end

--- Every texture of `set` hidden (true for a set never built).
local function allHidden(set)
    if set == nil then return true end
    for _, part in ipairs(PARTS) do
        if set[part[1]]:IsShown() then return false end
    end
    return true
end

local function pieces(am)
    local out = {}
    for i = 1, am.pieceCount do out[i] = am["piece" .. i] end
    return out
end

test("text glow: each falloff names a texture the client ships, by an extensionless path (TG-05)", function()
    local NS = E()
    local files = NS.Constants.TEXT_GLOW_TEXTURES
    -- red under: no C.TEXT_GLOW_TEXTURES in core/Constants.lua (every glow row draws nothing in game)
    assertTrue(type(files) == "table", "C.TEXT_GLOW_TEXTURES is defined")
    for _, key in ipairs(NS.Constants.TEXT_GLOW_FALLOFFS) do
        local path = files[key]
        -- red under: a falloff with no file (that choice hides the glow)
        assertTrue(type(path) == "string" and path ~= "", "a file for " .. key)
        -- red under: addon-owned media (layout-§3 keeps a generic texture out of media/), or a path
        -- spelled with its extension
        assertFalse(path:lower():find("interface\\addons\\", 1, true) ~= nil, key .. " is a client file")
        assertFalse(path:lower():find("%.%a+$") ~= nil, key .. " has no extension")
    end
    assertEqual(files.soft, "Interface\\GLUES\\Models\\UI_Draenei\\GenericGlow64")
    assertEqual(files.hard, "Interface\\CharacterFrame\\TempPortraitAlphaMask")
end)

test("text glow: off builds no glow set; turned off after drawing, every set is hidden", function()
    local c = text({ template = "$spellname$ - $stacks$" })
    local frame, am = dress(c)
    -- red under: a set built (and shown) while the glow is off, its default
    assertNil(am.glow1, "no set built while off")
    c.text.glow = true
    dress(c, frame)
    assertFalse(allHidden(am.glow1), "on draws the set")
    c.text.glow = false
    dress(c, frame)
    -- red under: an off dress that returns before hiding what an earlier dress drew
    assertTrue(allHidden(am.glow1), "turned off, the set is hidden")
end)

test("text glow: a Left line gets one set from piece 1's edges to the last piece's, offset and r deep", function()
    local c = text({ template = "$spellname$ - $stacks$", justifyH = "LEFT", glow = true, glowRadius = 9,
        glowX = 3, glowY = -2 })
    local _, am = dress(c)
    local p = pieces(am)
    -- red under: a set anchored to the area or the chain (it would hug the box, not the text), a
    -- piece anchored with no offset, or a radius taken from the template
    assertSet(am.glow1, p[1], p[3], 3, -2, 9, "Left")
    assertNil(am.glow2, "one set for a line")
    for _, part in ipairs(PARTS) do
        local tex = am.glow1[part[1]]
        -- red under: the textures on the text area (a child frame of anim, so they draw over the icon)
        -- or on the chain (over the text)
        assertTrue(tex.parent == am.anim, part[1] .. " is a texture of the animated frame")
        -- red under: ARTWORK or above, where the icon (anim's ARTWORK) no longer covers them
        assertEqual(tex.args[2], "BACKGROUND", part[1] .. " on BACKGROUND")
    end
    assertTrue(am.icon.parent == am.anim and am.icon.args[2] == "ARTWORK",
        "the icon is anim's ARTWORK, a layer above the glow")
end)

test("text glow: Right and a one-piece Center line keep L = piece 1 and R = the last piece", function()
    local c = text({ template = "$spellname$ - $stacks$", justifyH = "RIGHT", glow = true })
    local _, am = dress(c)
    local p = pieces(am)
    -- red under: L and R taken from the chain's head and tail (a Right line's head is the last piece)
    assertSet(am.glow1, p[1], p[3], 0, 0, 6, "Right")
    c = text({ template = "$spellname$", justifyH = "CENTER", glow = true })
    _, am = dress(c)
    p = pieces(am)
    -- red under: a one-piece Center treated as stacked (no set) or given a set per row
    assertSet(am.glow1, p[1], p[1], 0, 0, 6, "Center single")
    assertNil(am.glow2)
end)

test("text glow: a stacked Center line gets a set per name or duration row, none for stacks, dispel or literals", function()
    local NS = E()
    local c = text({ template = "$spellname$ :: $stacks$ ($dispeltype$)[ - $remainingduration$]",
        justifyH = "CENTER", glow = true, glowX = 1, glowY = 1, glowRadius = 4 })
    local frame, am = dress(c)
    local p = pieces(am)
    local rows = 0
    for i, piece in ipairs(NS.Style.Text.Compiled(c.text).pieces) do
        if piece.kind == "name" or piece.kind == "duration" then
            rows = rows + 1
            -- red under: one set over the whole stack (L = piece 1, R = the last) or a set per piece
            assertSet(am["glow" .. rows], p[i], p[i], 1, 1, 4, "row " .. rows)
        end
    end
    assertEqual(rows, 2, "the name row and the duration row")
    -- red under: a set on the stacks or dispel row, which the engine writes empty below 2 stacks or
    -- with no type, and whose zero-width string the corners would ring as a glowing dot
    assertNil(am.glow3, "no set for the stacks, dispel or literal rows")
    c.text.justifyH = "LEFT"
    dress(c, frame)
    -- red under: the sets past the ones a dress uses left as the stacked dress drew them
    assertSet(am.glow1, p[1], p[#p], 1, 1, 4, "back to a line")
    assertTrue(allHidden(am.glow2), "the extra set hidden")
end)

test("text glow: a line of only stacks or dispel fields gets no set, a duration-only line one (TG-05)", function()
    for _, template in ipairs({ "$stacks$", "[x$stacks$]", "$dispeltype$", "$stacks$$dispeltype$" }) do
        local c = text({ template = template, justifyH = "LEFT", glow = true })
        local _, am = dress(c)
        -- red under: a set around fields the engine writes empty (a glowing dot where no text is)
        assertTrue(allHidden(am.glow1), template .. " draws no glow")
    end
    local c = text({ template = "$stacks$ stacks", justifyH = "LEFT", glow = true })
    local _, am = dress(c)
    -- red under: plain text beside a stacks field dropped with it (the literal always draws)
    assertFalse(allHidden(am.glow1), "a literal beside the field keeps the set")
    c = text({ template = "$remainingduration$", justifyH = "LEFT", glow = true })
    _, am = dress(c)
    -- red under: the duration skipped like the stacks (it is only empty on a timeless aura)
    assertFalse(allHidden(am.glow1), "a duration-only line keeps the set")
end)

test("text glow: a new template shape re-anchors the set to the new chain's pieces", function()
    local c = text({ template = "$spellname$ $stacks$", glow = true })
    local frame, am = dress(c)
    c.text.template = "$stacks$ - $spellname$ ($dispeltype$)"
    dress(c, frame)
    local p = pieces(am)
    -- red under: a set still anchored to the stashed chain's strings (hidden with it, so no glow)
    assertSet(am.glow1, p[1], p[#p], 0, 0, 6, "new shape")
end)

test("text glow: each texture carries the falloff's file and the blend mode", function()
    local c = text({ template = "$spellname$", glow = true })
    local frame, am = dress(c)
    for _, part in ipairs(PARTS) do
        local tex = am.glow1[part[1]]
        -- red under: the default falloff or blend not applied (a white box, or a blend left unset)
        assertEqual(tex:__joined("SetTexture"), file("soft"), part[1] .. " soft")
        assertEqual(tex:__joined("SetBlendMode"), "BLEND", part[1] .. " Normal")
    end
    c.text.glowFalloff, c.text.glowBlend = "hard", "ADD"
    dress(c, frame)
    for _, part in ipairs(PARTS) do
        local tex = am.glow1[part[1]]
        -- red under: the falloff or blend leaf ignored after the first dress
        assertEqual(tex:__joined("SetTexture"), file("hard"), part[1] .. " hard")
        assertEqual(tex:__joined("SetBlendMode"), "ADD", part[1] .. " Additive")
    end
    c.text.glowFalloff, c.text.glowBlend = "fuzzy", "MOD"
    dress(c, frame)
    -- red under: a hand-written choice outside the lists handed to the client as is
    assertEqual(am.glow1.center:__joined("SetTexture"), file("soft"), "an unknown falloff draws the default")
    assertEqual(am.glow1.center:__joined("SetBlendMode"), "BLEND", "an unknown blend draws the default")
end)

test("text glow: with no file for the falloff, nothing is drawn", function()
    local NS = E()
    local c = text({ template = "$spellname$", glow = true })
    local frame, am = dress(c)
    local saved = NS.Constants.TEXT_GLOW_TEXTURES
    NS.Constants.TEXT_GLOW_TEXTURES = nil
    local ok, err = pcall(dress, c, frame)
    NS.Constants.TEXT_GLOW_TEXTURES = saved
    -- red under: a dress that indexes the missing table (the whole element left half-dressed)
    assertTrue(ok, tostring(err))
    -- red under: a set drawn with no file (a flat, untextured box behind the text)
    assertTrue(allHidden(am.glow1), "hidden without a file")
end)

test("text glow: the vertex color is the glow color, its alpha times the intensity", function()
    local c = text({ template = "$spellname$", glow = true, glowIntensity = 0.5,
        glowColor = { r = 0.1, g = 0.2, b = 0.3, a = 0.8 } })
    local _, am = dress(c)
    for _, part in ipairs(PARTS) do
        -- red under: the intensity dropped (alpha 0.8) or applied to the color channels too
        assertEqual(am.glow1[part[1]]:__joined("SetVertexColor"), "0.1,0.2,0.3,0.4", part[1])
    end
end)

test("text glow: the class-color companion paints the container's class, its alpha kept", function()
    local class = { r = 0.2, g = 0.4, b = 0.6 }
    local c = text({ template = "$spellname$", glow = true, glowIntensity = 0.5, useClassColorGlow = true,
        glowColor = { r = 1, g = 1, b = 1, a = 1 } })
    local _, am = dress(c, nil, false, class)
    -- red under: the companion ignored (white), or the class read off the player, not the snapshot
    assertEqual(am.glow1.center:__joined("SetVertexColor"), "0.2,0.4,0.6,0.5")
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

test("text glow: the font's outline and shadow are still applied with the glow on", function()
    local c = text({ template = "$spellname$ $stacks$", glow = true,
        font = { fontFlags = "OUTLINE", fontShadow = true } })
    local _, am = dress(c)
    for i, fs in ipairs(pieces(am)) do
        -- red under: a glow that replaces the outline or the shadow (owner: it adds to them)
        assertEqual(fs:__last("SetFont")[3], "OUTLINE", "piece " .. i .. " outline")
        assertEqual(fs:__joined("SetShadowOffset"), "1,-1", "piece " .. i .. " shadow")
    end
    assertFalse(allHidden(am.glow1))
end)

test("text glow: the glow is dressed after the engine bindings, so a refused call cannot unbind a field", function()
    local c = text({ template = "$spellname$", glow = true })
    local frame, am = dress(c, nil, true)
    -- red under: the glow dressed before Text.Bind (its client calls ahead of the engine's bindings)
    assertTrue(am.glow1.center:__lastSeq("SetVertexColor") > frame:__lastSeq("SetSpellName"))
end)

test("text glow: the docs name every glow leaf on the Font tab row and the halo's limits", function()
    local function read(path)
        local f = assert(io.open(path, "r"), "cannot open " .. path)
        local body = f:read("*a")
        f:close()
        return (body:gsub("\r", ""))
    end
    local fontRow = read("docs/settings-panel.md"):match("\n| Font | ([^\n]*)")
    assertTrue(fontRow ~= nil, "docs/settings-panel.md has the Text section's Font row")
    for _, key in ipairs(LEAVES) do
        -- red under: the Font row without its Glow paths (spec G6)
        assertTrue(fontRow:find("`" .. key .. "`", 1, true) ~= nil, "the Font row names " .. key)
    end
    local bullet = read("docs/known-limitations.md"):match("\n%- %*%*A Text line's glow(.-)\n%- ")
    -- red under: docs/known-limitations.md without the glow's bullet (spec G6)
    assertTrue(bullet ~= nil, "docs/known-limitations.md has the glow's bullet")
    -- red under: the glow's bullet silent on its shape (no per-glyph glow, and why)
    assertTrue(bullet:find("glyph", 1, true) ~= nil, "no per-glyph glow, and why")
    for _, word in ipairs({ "hand-set", "Width", "Height", "wherever it reaches past the box" }) do
        -- red under: the glow's bullet without its clip on every side under a hand-set Width and Height
        assertTrue(bullet:find(word, 1, true) ~= nil, "the halo's clip names " .. word)
    end
end)
