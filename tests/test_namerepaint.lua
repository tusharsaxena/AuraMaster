-- tests/test_namerepaint.lua - the blank bar name repaint (issue #24): which containers show a name
-- the aura engine writes (Style.ShowsEngineName), so only those are ever repainted. The engine writes
-- a bar's spell name on assign or update only, and a name still nil on first sighting stays blank
-- (docs/superpowers/research/2026-09-27-blank-bar-names-findings.md).

local T = _G.AM_TEST
local test, assertTrue, assertFalse = T.test, T.assertTrue, T.assertFalse
local NS = T.NS

local function cfg(over)
    return NS.Database.Merge(NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE), over or {})
end

-- -- the predicate -----------------------------------------------------------------------------

test("names: a bars container shows the engine's name by default", function()
    -- red under: the bars arm answering false (no bar container is ever repainted)
    assertTrue(NS.Style.ShowsEngineName(cfg({ style = "bars" })))
end)

test("names: a bars container with its name hidden shows none", function()
    -- red under: the bars arm ignoring bars.name.show (a no-name container repainted for nothing)
    assertFalse(NS.Style.ShowsEngineName(cfg({ style = "bars", bars = { name = { show = false } } })))
end)

test("names: an unknown style counts as bars, as Style.StyleKey draws it", function()
    -- red under: matching cfg.style == "bars" instead of Style.StyleKey (a removed style never repainted)
    assertTrue(NS.Style.ShowsEngineName(cfg({ style = "retired" })))
    assertFalse(NS.Style.ShowsEngineName(cfg({ style = "retired", bars = { name = { show = false } } })))
end)

test("names: an icons container never shows a name", function()
    -- red under: icons falling through to the bars arm (every icons container repainted)
    assertFalse(NS.Style.ShowsEngineName(cfg({ style = "icons" })))
end)

test("names: a text container shows a name only when its template has the name token", function()
    -- red under: the text arm answering true for any template (a name-free line repainted)
    assertTrue(NS.Style.ShowsEngineName(cfg({ style = "text", text = { template = "$spellname$ x$stacks$" } })))
    assertFalse(NS.Style.ShowsEngineName(cfg({ style = "text", text = { template = "x$stacks$" } })))
end)

test("names: an escaped $$spellname$$ is literal text, not the name token", function()
    -- red under: a string search for "spellname" instead of the compiled pieces
    assertFalse(NS.Style.ShowsEngineName(cfg({ style = "text", text = { template = "$$spellname$$ $stacks$" } })))
end)

test("names: the name token is found in any case", function()
    -- red under: a case-sensitive search for "$spellname$"
    assertTrue(NS.Style.ShowsEngineName(cfg({ style = "text", text = { template = "$SpellName$[ x$stacks$]" } })))
end)

test("names: a refused text template draws the default, which has a name", function()
    -- red under: Style.Text compiled with TT.Compile instead of Text.Compiled (a refusal has no pieces)
    local c = cfg({ style = "text", text = { template = "x$stacks$ $foo$" } })
    assertFalse(NS.TextTemplate.Compile(c.text.template).ok, "the template is refused")
    assertTrue(NS.Style.ShowsEngineName(c))
    c.text = nil
    assertTrue(NS.Style.ShowsEngineName(c), "an absent text block draws the default too")
end)
