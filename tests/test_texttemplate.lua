-- tests/test_texttemplate.lua — modules/TextTemplate.lua: the Text style's template language. Every
-- refusal rule with its exact message, the escapes, case, and the pieces a template compiles to.
-- The parser is pure, so the shared environment is read and never written.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local NS = T.NS
local TT = NS.TextTemplate
local L = NS.L

--- The refusal `template` compiles to; fails the case when it compiles.
local function refusal(template)
    local r = TT.Compile(template)
    assertFalse(r.ok, "refused: " .. tostring(template))
    return r.err
end

--- The pieces `template` compiles to, as one line: kind, then each field that kind carries.
local function shape(template)
    local r = TT.Compile(template)
    assertTrue(r.ok, tostring(template) .. ": " .. tostring(r.err))
    local out = {}
    for i, p in ipairs(r.pieces) do
        local parts = { p.kind }
        if p.kind == "literal" then parts[2] = "<" .. p.text .. ">" end
        if p.kind == "stacks" or p.kind == "dispel" or p.kind == "duration" then
            parts[2] = "<" .. p.pre .. ">"
            parts[3] = "<" .. p.post .. ">"
        end
        if p.format then
            local n = #parts
            parts[n + 1] = "<" .. p.format .. ">"
        end
        out[i] = table.concat(parts, " ")
    end
    return table.concat(out, " | ")
end

-- ── the rules, each with its message (spec 3.2) ──────────────────────────────────────────────

test("template: an unknown token is refused, naming it and every known token (rule 1)", function()
    -- red under: lexToken treating an unknown name as literal text
    assertEqual(refusal("$spellname$ $foo$"), L["Unknown token $%s$. Known: %s"]:format("foo",
        "$spellname$, $stacks$, $dispeltype$, $remainingduration$, $maxduration$, $elapsedduration$, "
        .. "$remainingpercent$, $elapsedpercent$"))
end)

test("template: a lone $ with no closing $ is literal text (rule 1)", function()
    -- red under: lexOne refusing a $ that opens no token
    assertEqual(shape("$spellname$ costs $5"), "name | literal < costs $5>")
    assertEqual(shape("$ $spellname$"), "literal <$ > | name")
end)

test("template: a token used twice is refused (rule 2)", function()
    -- red under: checkOnce keyed on the typed spelling rather than the lower-case key
    assertEqual(refusal("$stacks$ $SPELLNAME$ $Stacks$"),
        L["$%s$ appears twice — each token can be used once."]:format("stacks"))
end)

test("template: a token between two duration tokens is refused, naming it (rule 3)", function()
    -- red under: checkRun scanning only the first duration token's neighbors
    assertEqual(refusal("$remainingduration$ $spellname$ $maxduration$"),
        L["Duration tokens must sit together — $%s$ splits them."]:format("spellname"))
end)

test("template: nested and unmatched brackets are refused (rule 4)", function()
    assertEqual(refusal("$spellname$[ [x$stacks$]]"), L["Brackets can't be nested."])
    -- red under: groupItems accepting a close with nothing open
    assertEqual(refusal("$spellname$ x$stacks$]"), L["Unmatched [ or ]."])
    -- red under: groupItems forgetting a group left open at the end
    assertEqual(refusal("$spellname$[ x$stacks$"), L["Unmatched [ or ]."])
end)

test("template: a [ ] group holds exactly one of stacks, dispel type or the duration run (rule 4)", function()
    local msg = L["A [ ] group must hold exactly one of $stacks$, $dispeltype$ or the duration tokens."]
    assertEqual(refusal("[$spellname$]"), msg, "the name alone")
    assertEqual(refusal("$spellname$[ text]"), msg, "text alone")
    -- red under: unitsIn counting the duration run once per token instead of once
    assertEqual(refusal("$spellname$[$stacks$ $dispeltype$]"), msg, "two units")
    assertEqual(refusal("[$spellname$ x$stacks$]"), msg, "the name beside a unit")
end)

test("template: a bracket around the duration run must hold all of it (rule 5)", function()
    -- red under: checkGroups accepting a duration group that holds part of the run
    assertEqual(refusal("$spellname$[ $remainingduration$] / $maxduration$"),
        L["Put all the duration tokens inside the same [ ]."])
end)

test("template: { and } are refused inside the duration run and its bracket, allowed elsewhere (rule 6)", function()
    local msg = L["{ and } can't be used next to duration tokens."]
    assertEqual(refusal("$remainingduration$ {of} $maxduration$"), msg, "between two duration tokens")
    -- red under: checkBraces reading only the flat run and not the group around it
    assertEqual(refusal("$spellname$[ {$remainingduration$}]"), msg, "inside the duration's group")
    assertEqual(shape("{$spellname$}"), "literal <{> | name | literal <}>")
end)

test("template: an empty template, or one with no token, is refused (rule 7)", function()
    local msg = L["Use at least one $token$."]
    assertEqual(refusal(""), msg)
    assertEqual(refusal("just text"), msg)
    -- red under: TT.Compile indexing a stored value that is not a string
    assertEqual(refusal(nil), msg)
    assertEqual(refusal(42), msg)
end)

test("template: longer than 200 characters is refused (rule 8)", function()
    local long = "$spellname$" .. ("x"):rep(189)
    assertTrue(TT.Compile(long).ok, "200 characters")
    -- red under: validate skipping the length check
    assertEqual(refusal(long .. "y"), L["A template can be at most %d characters."]:format(200))
end)

test("template: the first broken rule is the one reported", function()
    -- rule 1 before rule 2, rule 2 before rule 4
    assertEqual(refusal("$stacks$ $stacks$ $foo$"):sub(1, 14), "Unknown token ")
    assertEqual(refusal("[$stacks$ $stacks$"),
        L["$%s$ appears twice — each token can be used once."]:format("stacks"))
    -- rule 4 (an earlier group's rule-4 break) before rule 5 (a later group's rule-5 break) — the
    -- reverse: a LATER group's rule-4 break must still outrank an EARLIER group's rule-5 break.
    -- red under: checkGroups checking 4c then 5 per group, in group order, instead of one pass each
    assertEqual(refusal("$spellname$[ $remainingduration$] $maxduration$[ text]"),
        L["A [ ] group must hold exactly one of $stacks$, $dispeltype$ or the duration tokens."])
end)

-- ── escapes and case ───────────────────────────────────────────────────────────────────────────

test("template: [[, ]] and $$ write a literal [, ] and $", function()
    -- red under: ESCAPES missing a pair (the [ would open a group)
    assertEqual(shape("[[$spellname$]] $$"), "literal <[> | name | literal <] $>")
end)

test("template: an odd run of [ opens with its first, an even run is all escapes (]] ]  mirror)", function()
    -- red under: lexOne treating a run's first pair as an escape, leaving the last [ to open —
    -- the bracket text would then land outside the group instead of as its pre/post
    assertEqual(shape("[[[$stacks$]]]"), "stacks <[> <]> <[%d]>")
    assertEqual(shape("[[$spellname$]]"), "literal <[> | name | literal <]>")
    assertEqual(shape("[[[[$spellname$]] x"), "literal <[[> | name | literal <] x>")
end)

test("template: tokens are case-insensitive", function()
    assertEqual(shape("$SpellName$ $STACKS$"), "name | literal < > | stacks <> <> <%d>")
end)

-- ── pieces (spec 3.3) ──────────────────────────────────────────────────────────────────────────

test("template: the default template folds its bracket text into the stacks and duration pieces", function()
    -- The template default (defaults/Profile.lua, Task 6) is this string.
    local DEFAULT = "$spellname$[ x$stacks$][ - $remainingduration$]"
    local r = TT.Compile(DEFAULT)
    assertTrue(r.ok)
    -- red under: groupPiece leaving the bracket text as literal pieces of their own
    assertEqual(shape(DEFAULT),
        "name | stacks < x> <> < x%d> | duration < - > <> < - {}>")
    assertEqual(r.shape, "name|stacks|duration")
    assertTrue(r.hasDuration)
    assertFalse(r.single)
end)

test("template: the name alone is one piece, and single", function()
    local r = TT.Compile("$spellname$")
    assertEqual(#r.pieces, 1)
    assertTrue(r.single, "a one-piece template may be centered")
    assertFalse(r.hasDuration)
end)

test("template: a duration run keeps its inner text in the format, one component per token", function()
    local r = TT.Compile("$spellname$ $remainingduration$ / $maxduration$ ($remainingpercent$)")
    assertEqual(shape("$spellname$ $remainingduration$ / $maxduration$ ($remainingpercent$)"),
        "name | literal < > | duration <> <> <{} / {} ({}> | literal <)>")
    local comps = r.pieces[3].components
    -- red under: addComponent recording the key instead of the engine property
    assertEqual(comps[1].prop, "RemainingDuration"); assertEqual(comps[1].fmt, "time")
    assertEqual(comps[2].prop, "TotalDuration"); assertEqual(comps[2].fmt, "time")
    assertEqual(comps[3].prop, "RemainingPercent"); assertEqual(comps[3].fmt, "percent")
end)

test("template: a bracketed duration run carries the bracket text in its format", function()
    assertEqual(shape("$spellname$[ ($elapsedduration$ of $maxduration$)]"),
        "name | duration < (> <)> < ({} of {})>")
end)

test("template: a % in a stacks bracket is doubled in the rule format and kept in pre/post", function()
    -- red under: groupPiece writing the stacks format without escapePercent
    assertEqual(shape("$spellname$[ %$stacks$%]"), "name | stacks < %> <%> < %%%d%%>")
end)

test("template: a dispel type keeps its bracket text as pre and post", function()
    assertEqual(shape("$spellname$[ ($dispeltype$)]"), "name | dispel < (> <)>")
end)

test("template: adjacent literals merge into one piece, and none is empty", function()
    -- red under: flush pushing an empty literal, or not merging an escape into its neighbors
    assertEqual(shape("(( $$ )) $spellname$"), "literal <(( $ )) > | name")
end)

test("template: compiled results are memoized per template string", function()
    -- red under: TT.Compile rebuilding on every dress (every button, every restyle)
    assertTrue(TT.Compile("$spellname$ x") == TT.Compile("$spellname$ x"))
end)

test("template: Validate answers true, or false and the refusal", function()
    assertTrue(TT.Validate("$spellname$"))
    local ok, why = TT.Validate("$nope$")
    assertFalse(ok)
    assertEqual(why:sub(1, 14), "Unknown token ")
end)
