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

test("text page: General holds Size, the Template box, the cheat sheet, then Placement", function()
    local NS, _, P, ws = textPage()
    local L = NS.L
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
    -- The cheat sheet sits between the Template box and the Placement rows.
    local at = {}
    for i, w in ipairs(ws) do
        if w == box then at.box = i end
        if w.type == "Label" and w.text and w.text:find("$spellname$", 1, true) and not at.sheet then at.sheet = i end
        if w.labelText == NS.FindSchemaRow(P_ .. "justifyH").label then at.justify = i end
    end
    assertTrue(at.box < at.sheet and at.sheet < at.justify, "box, then cheat sheet, then Placement")
end)

test("text page: a valid template is stored; a refused one is not, and the panel prints why", function()
    local NS, _, P, ws = textPage()
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
