-- tests/test_pages_text.lua — settings/Text.lua, driven through its widgets: the four tabs, the
-- notice and disabled rows on a container not drawn as text, the Template box and its refusals
-- (panel and /am set), the token cheat sheet, the centering note and the rows the loop effect and
-- the template dim. How the stored look is drawn is tests/test_style_text.lua's.
-- Every case builds a fresh environment, because every case writes something.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")
local pages = dofile("tests/page_helpers.lua")

local P_ = "container.text."
local GOLD = "|c" .. T.NS.Constants.NOTICE_COLOR

--- The Template dropdown (feedback #5): the built-ins and Custom. Not a schema row, found by label.
local function picker(NS, P, ws) return P.find(ws, "Dropdown", NS.L["Template"]) end

--- Choose `key` in the Template dropdown and answer the page as it draws after the choice.
local function pick(NS, m, P, ws, key)
    picker(NS, P, ws):__fire("OnValueChanged", key)
    m.__fireTimers()
    return P.rerender("Text")
end

--- The Animation tab as the current settings draw it: a structural re-render, then a click on the
--- tab unless it is already the active one (a click on the active tab draws nothing).
local function animationTab(NS, P)
    local ws = P.rerender("Text")
    if NS.Helpers.__pageCtx.text.activeTab == NS.L["Animation"] then return ws end
    return P.tab("text", NS.L["Animation"])
end

--- The Text page drawn for container 1, switched to the text style first.
local function textPage(opts)
    local NS, m = fresh(opts)
    local P = pages(NS, m)
    NS.SetByPath("container.style", "text", 1)
    NS.State.SetActiveContainer(1)
    return NS, m, P, P.show("Text")
end

test("text page: the four tabs are drawn in order", function()
    local NS, _, P = textPage()
    local L = NS.L
    -- red under: a row registered in a group of its own (a stray fifth tab), or the tabs reordered
    assertEqual(table.concat(P.tabKeys("text"), ","),
        table.concat({ L["General"], L["Font"], L["Icon"], L["Animation"] }, ","))
end)

test("text page: a bars or icons container sees every row disabled under the note naming its style", function()
    local NS, _, P = textPage()
    local L = NS.L
    NS.Helpers.SelectContainer(2)
    local notice = GOLD .. L["Not in use: this container is drawn as icons. Set its Style to Text on the Containers page to use these settings."]
    P.eachTab("Text", "text", function(key, tabWs)
        -- red under: the Text spec's disabledNotice answering the bars wording for an icons container
        assertTrue(P.hasText(tabWs, notice), key .. " carries the note")
        local rows = P.rowWidgets(tabWs, "text", key)
        assertTrue(rows[1] ~= nil, key .. " drew its rows")
        for _, w in ipairs(rows) do
            -- red under: the Text spec without disabledFor, or the bespoke General tab dropping the
            -- page's disable (renderBespoke's ctx.__renderDisabled)
            assertTrue(w.disabled, key .. ": " .. w.labelText)
        end
    end)
    NS.SetByPath("container.style", "bars", 2)
    local ws = P.rerender("Text")
    assertTrue(P.hasText(ws, GOLD .. L["Not in use: this container is drawn as bars. Set its Style to Text on the Containers page to use these settings."]))
end)

test("text page: the Bars and Icons pages name the text style on a text container", function()
    local NS, _, P = textPage()
    local L = NS.L
    -- red under: the Bars notice still claiming every other container is drawn as icons
    assertTrue(P.hasText(P.show("Bars"), GOLD .. L["Not in use: this container is drawn as text. Set its Style to Bars on the Containers page to use these settings."]))
    assertTrue(P.hasText(P.show("Icons"), GOLD .. L["Not in use: this container is drawn as text. Set its Style to Icons on the Containers page to use these settings."]))
end)

test("text page: General holds Size, the Template dropdown and box, the cheat sheet, then Placement", function()
    local NS, m, P, ws = textPage()
    local L = NS.L
    ws = pick(NS, m, P, ws, "custom")
    local box = P.row(ws, P_ .. "template")
    -- red under: the template row without dialogControl = "EditBox" (a dropdown that opens on nothing)
    assertEqual(box.type, "EditBox")
    assertEqual(box.text, NS.CONTAINER_TEMPLATE.text.template)
    local texts = P.texts(ws)
    local joined = table.concat(texts, "\n")
    for _, def in ipairs(NS.Constants.TEXT_TOKENS) do
        -- red under: cheatSheet skipping a token
        assertTrue(joined:find("$" .. def.key .. "$", 1, true) ~= nil, "cheat sheet names $" .. def.key .. "$")
    end
    assertTrue(P.hasText(ws, L["To write a literal [, ] or $, type it twice: [[, ]] or $$."]))
    -- red under: the cheat sheet leaving out how an odd run of [ combines an escape and a bracket
    assertTrue(P.hasText(ws, L["Escapes and brackets combine: [[[$stacks$]]] shows [3] only when stacked."]))
    -- red under: the cheat sheet without the bracketed-duration example (feedback #5)
    assertTrue(P.hasText(ws, "[ ($remainingpercent$%)] hides with the time"))
    -- The cheat sheet sits between the Template box and the Placement rows.
    local at = {}
    for i, w in ipairs(ws) do
        if w == box then at.box = i end
        if w.type == "Label" and w.text and w.text:find("$spellname$", 1, true) and not at.sheet then at.sheet = i end
        if w.labelText == NS.FindSchemaRow(P_ .. "justifyH").label then at.justify = i end
    end
    assertTrue(at.box < at.sheet and at.sheet < at.justify, "box, then cheat sheet, then Placement")
    local dd = picker(NS, P, ws)
    for i, w in ipairs(ws) do
        if w == dd then at.picker = i end
    end
    -- red under: the dropdown drawn under the box (the spec puts it above the template box)
    assertTrue(at.picker < at.box, "the Template dropdown, then the box")
end)

test("text page: a valid template is stored; a refused one is not, and the panel prints why", function()
    local NS, m, P, ws = textPage()
    ws = pick(NS, m, P, ws, "custom")
    local lines = P.chat()
    local box = P.row(ws, P_ .. "template")
    box:__fire("OnEnterPressed", "$spellname$ $remainingduration$")
    assertEqual(NS.Database.FindContainer(1).text.template, "$spellname$ $remainingduration$")
    box:__fire("OnEnterPressed", "$spellname$ $bogus$")
    -- red under: the template row without validate (a template the parser refuses is stored)
    assertEqual(NS.Database.FindContainer(1).text.template, "$spellname$ $remainingduration$")
    local said = table.concat(lines, "\n")
    -- red under: the Options descriptor's set dropping SetByPath's third return
    assertTrue(said:find("Invalid value for container.text.template", 1, true) ~= nil, said)
    assertTrue(said:find("  Unknown token $bogus$.", 1, true) ~= nil, said)
end)

test("text page: /am set refuses a bad template with the parser's reason, indented under the refusal", function()
    local NS, _, P = textPage()
    local lines = P.chat()
    NS.Slash:OnSlash("set container.text.template $spellname$[ $spellname$]")
    local said = table.concat(lines, "\n")
    -- red under: the Slash descriptor's set printing only the bare refusal
    assertTrue(said:find("Invalid value for container.text.template", 1, true) ~= nil, said)
    assertTrue(said:find("  " .. NS.L["$%s$ appears twice — each token can be used once."]:format("spellname"), 1, true) ~= nil, said)
    assertEqual(NS.Database.FindContainer(1).text.template, NS.CONTAINER_TEMPLATE.text.template)
    NS.Slash:OnSlash("set container.text.template $spellname$ ($stacks$)")
    assertEqual(NS.Database.FindContainer(1).text.template, "$spellname$ ($stacks$)")
end)

test("text page: Center on a multi-piece template draws the note naming the piece count", function()
    local NS, _, P = textPage()
    local note = NS.L["Center needs a one-piece template; this one has %d pieces, so it lines up Left."]
    NS.SetByPath(P_ .. "justifyH", "CENTER", 1)
    local ws = P.rerender("Text")
    -- red under: centerNote reading the stored template's piece count wrong, or not drawn
    assertTrue(P.hasText(ws, note:format(3)), "the default template has three pieces")
    NS.SetByPath(P_ .. "template", "$spellname$", 1)
    ws = P.rerender("Text")
    assertFalse(P.hasText(ws, note:sub(1, 30)), "a one-piece template centers, so no note")
    NS.SetByPath(P_ .. "justifyH", "LEFT", 1)
    NS.SetByPath(P_ .. "template", "$spellname$ $stacks$", 1)
    ws = P.rerender("Text")
    assertFalse(P.hasText(ws, note:sub(1, 30)), "Left needs no note")
end)

test("text page: each loop row is live only for the effects that use it", function()
    local NS, _, P = textPage()
    local function states(anim)
        NS.SetByPath(P_ .. "anim", anim, 1)
        local ws = animationTab(NS, P)
        local out = {}
        for _, key in ipairs({ "animSpeed", "animIntensity", "animBounce" }) do
            local n = #out
            out[n + 1] = key .. "=" .. tostring(P.row(ws, P_ .. key).disabled and true or false)
        end
        return table.concat(out, " ")
    end
    -- red under: a loop row's disabledIf naming the wrong effect
    assertEqual(states("none"), "animSpeed=true animIntensity=true animBounce=true")
    assertEqual(states("pulse"), "animSpeed=false animIntensity=false animBounce=true")
    assertEqual(states("blink"), "animSpeed=false animIntensity=false animBounce=true")
    assertEqual(states("bounce"), "animSpeed=false animIntensity=true animBounce=false")
end)

test("text page: without a duration token the running-out rows dim, except the swatch, under a note", function()
    local NS, _, P = textPage()
    local L = NS.L
    local note = L["Running out needs a duration token, such as $remainingduration$, in the template."]
    local ws = animationTab(NS, P)
    assertFalse(P.hasText(ws, note), "the default template has one")
    assertFalse(P.row(ws, P_ .. "expiringBlink").disabled and true or false)
    NS.SetByPath(P_ .. "template", "$spellname$[ x$stacks$]", 1)
    ws = animationTab(NS, P)
    -- red under: the Animation tab's afterGroup note not drawn
    assertTrue(P.hasText(ws, note))
    for _, key in ipairs({ "expiringColorOn", "expiringThreshold", "expiringBlink" }) do
        -- red under: a running-out row without the noDuration predicate
        assertTrue(P.row(ws, P_ .. key).disabled, key)
    end
    -- anti-pattern #74: a color swatch is never grayed
    assertFalse(P.row(ws, P_ .. "expiringColor").disabled and true or false, "the swatch stays live")
end)

test("text page: the blink row is engine-only, and the Font tab carries the composed font block and time format", function()
    local NS = textPage()
    local L = NS.L
    assertEqual(NS.FindSchemaRow(P_ .. "expiringBlink").coverage, "engine-only")
    local paths = {}
    for _, row in ipairs(NS.SchemaForPage("text")) do
        if row.group == L["Font"] then
            local n = #paths
            paths[n + 1] = row.path
        end
    end
    -- red under: the font block on a prefix other than text.font., or the time format elsewhere
    assertEqual(table.concat(paths, ","), table.concat({ P_ .. "font.font", P_ .. "font.fontSize",
        P_ .. "font.fontColor", P_ .. "font.useClassColorFont", P_ .. "font.fontFlags",
        P_ .. "font.fontShadow", P_ .. "timeFormat" }, ","))
    assertEqual(NS.FindSchemaRow(P_ .. "font.fontColor").classColorSource, "unit")
end)

test("text page: Defaults restores the selected container's text look and nothing else", function()
    local NS = textPage()
    NS.SetByPath(P_ .. "width", 300, 1)
    NS.SetByPath(P_ .. "template", "$spellname$", 1)
    NS.SetByPath("container.bars.width", 111, 1)
    NS.Helpers.__pageCtx.text.panel.defaultsOnClick()
    local c1 = NS.Database.FindContainer(1)
    -- red under: the Text Defaults reaching the Bars page's rows
    assertEqual(c1.text.width, NS.CONTAINER_TEMPLATE.text.width)
    assertEqual(c1.text.template, NS.CONTAINER_TEMPLATE.text.template)
    assertEqual(c1.bars.width, 111)
end)

-- ── built-in templates, Custom and the Preview (feedback #5) ──────────────────────────────────

test("text page: the Template dropdown lists the aura type's built-ins, then Custom (feedback #5)", function()
    local NS, _, P, ws = textPage()
    local C = NS.Constants
    local function expected(auraType)
        local out = {}
        for i, key in ipairs(C.TEXT_BUILTIN_SETS[auraType]) do out[i] = key end
        local n = #out
        out[n + 1] = "custom"
        return table.concat(out, ",")
    end
    local dd = picker(NS, P, ws)
    -- red under: no Template dropdown, or the buff page offering the debuff built-ins
    assertEqual(table.concat(dd.order, ","), expected("HELPFUL"))
    assertEqual(dd.list.nameTime, NS.L["Name + time"])
    assertEqual(dd.value, "nameStacksTime", "the default template is a built-in")
    NS.SetByPath("container.style", "text", 2)
    NS.Helpers.SelectContainer(2)
    ws = P.rerender("Text")
    -- red under: the debuff page without Name (type) and Name, type, time
    assertEqual(table.concat(picker(NS, P, ws).order, ","), expected("HARMFUL"))
end)

test("text page: picking a built-in writes its template, and the centered one Center; the box stays hidden (feedback #5)", function()
    local NS, m, P, ws = textPage()
    local s = NS.Database.FindContainer(1).text
    -- red under: the box drawn for a template that is a built-in
    assertEqual(P.row(ws, P_ .. "template"), nil, "a built-in shows no box")
    ws = pick(NS, m, P, ws, "timeOfMax")
    assertEqual(s.template, "$spellname$[ $remainingduration$ / $maxduration$]")
    assertEqual(s.justifyH, "LEFT")
    ws = pick(NS, m, P, ws, "centered")
    -- red under: the centered built-in writing its template and leaving Justify alone
    assertEqual(s.template, "$spellname$[ - $remainingduration$]")
    assertEqual(s.justifyH, "CENTER")
    assertEqual(picker(NS, P, ws).value, "centered", "Name + time with Center reads as the centered one")
    ws = pick(NS, m, P, ws, "name")
    -- red under: a plain built-in leaving the line centered (Center is the centered built-in's)
    assertEqual(s.justifyH, "LEFT")
    assertEqual(picker(NS, P, ws).value, "name")
end)

test("text page: Custom reveals the box with the current template; an unmatched template reads as Custom (feedback #5)", function()
    local NS, m, P, ws = textPage()
    ws = pick(NS, m, P, ws, "custom")
    local box = P.row(ws, P_ .. "template")
    -- red under: Custom not opening the box, or opening it empty
    assertTrue(box ~= nil, "Custom shows the box")
    assertEqual(box.text, NS.CONTAINER_TEMPLATE.text.template, "seeded with the current template")
    assertEqual(picker(NS, P, ws).value, "custom")
    assertEqual(NS.Database.FindContainer(1).text.template, NS.CONTAINER_TEMPLATE.text.template, "choosing Custom writes nothing")
    -- Another container, whose stored template is no built-in: Custom, with its box, unasked.
    NS.SetByPath("container.style", "text", 3)
    NS.SetByPath(P_ .. "template", "$spellname$ $stacks$", 3)
    NS.Helpers.SelectContainer(3)
    ws = P.rerender("Text")
    -- red under: a template that matches nothing read as the first built-in
    assertEqual(picker(NS, P, ws).value, "custom")
    assertTrue(P.row(ws, P_ .. "template") ~= nil, "and its box is drawn")
end)

test("text page: the Preview line renders the sample aura, brackets filled and empty ones hidden (feedback #5)", function()
    local NS, m, P, ws = textPage()
    local L = NS.L
    -- The buff sample: Ignore Pain, 3 stacks, 11 of 12 s, no dispel type. The harness has no seconds
    -- formatter, so a time reads as whole seconds ("11s").
    -- red under: no Preview line, or one not filled from the sample
    assertTrue(P.hasText(ws, L["Preview: %s"]:format("Ignore Pain x3 - 11s")))
    NS.SetByPath(P_ .. "template", "$spellname$[ ($remainingpercent$%)][ ($dispeltype$)]", 1)
    m.__fireTimers()
    ws = P.rerender("Text")
    -- red under: an empty bracket drawn (the dispel type of a typeless aura), or a percent carrying
    -- its own "%" beside the one typed
    assertTrue(P.hasText(ws, L["Preview: %s"]:format("Ignore Pain (92%)")))
    -- The debuff sample: Shadow Word: Pain, no stacks, a Magic type.
    NS.SetByPath("container.style", "text", 2)
    NS.Helpers.SelectContainer(2)
    ws = P.rerender("Text")
    ws = pick(NS, m, P, ws, "nameTypeTime")
    assertTrue(P.hasText(ws, L["Preview: %s"]:format("Shadow Word: Pain (" .. L["Magic"] .. ") - 11s")))
    ws = pick(NS, m, P, ws, "nameStacksTime")
    assertTrue(P.hasText(ws, L["Preview: %s"]:format("Shadow Word: Pain - 11s")), "no stacks, so no ' x'")
end)
