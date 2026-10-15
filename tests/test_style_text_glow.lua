-- tests/test_style_text_glow.lua — a Text container's glow behind its text (text glow, TG-01..):
-- the stored leaves and their defaults, the blend and falloff choices, and a container stored
-- before the glow existed, which the load backfill brings up to the template with the glow off.
--
-- Spec: docs/superpowers/specs/2026-10-15-text-glow-design.md G1, G2 and G5.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
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
    -- red under: a backfill written with `or` against the template, which stamps the default back
    assertEqual(c.text.glow, true)
    assertEqual(c.text.glowBlend, "ADD")
end)
