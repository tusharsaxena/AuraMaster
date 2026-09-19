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
local NOTICE = "|c" .. T.NS.Constants.NOTICE_COLOR

--- The Template dropdown (feedback #5): the built-ins and Custom. Not a schema row, found by label.
local function picker(NS, P, ws) return P.find(ws, "Dropdown", NS.L["Template"]) end

--- The Preview box (Task 20): a disabled EditBox labeled Preview, PrettyChat's own shape. Not a
--- schema row, found by label like the Template dropdown.
local function preview(NS, P, ws) return P.find(ws, "EditBox", NS.L["Preview"]) end

--- Choose `key` in the Template dropdown and answer the page as it draws after the choice.
local function pick(NS, m, P, ws, key)
    picker(NS, P, ws):__fire("OnValueChanged", key)
    m.__fireTimers()
    return P.rerender("Text")
end

--- Record every [Set] and [Apply] line, rendered `[Tag] text`, with debug on (final review; the
--- same shape as test_pages_filters.lua's captureLog, which the bulk-bracket "one line, one apply"
--- convention already tests on Show all/Hide all).
local function captureLog(NS)
    NS.State.debug = true
    local lines = {}
    NS.Debug = function(tag, fmt, ...)
        if tag ~= "Set" and tag ~= "Apply" then return end
        local args = { ... }
        for i = 1, select("#", ...) do args[i] = tostring(args[i]) end
        local n = #lines
        lines[n + 1] = ("[%s] %s"):format(tag, fmt:format(unpack(args)))
    end
    return lines
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
    local notice = NOTICE .. L["Not in use: this container is drawn as icons. Set its Style to Text on the Containers page to use these settings."]
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
    assertTrue(P.hasText(ws, NOTICE .. L["Not in use: this container is drawn as bars. Set its Style to Text on the Containers page to use these settings."]))
end)

test("text page: the Bars and Icons pages name the text style on a text container", function()
    local NS, _, P = textPage()
    local L = NS.L
    -- red under: the Bars notice still claiming every other container is drawn as icons
    assertTrue(P.hasText(P.show("Bars"), NOTICE .. L["Not in use: this container is drawn as text. Set its Style to Bars on the Containers page to use these settings."]))
    assertTrue(P.hasText(P.show("Icons"), NOTICE .. L["Not in use: this container is drawn as text. Set its Style to Icons on the Containers page to use these settings."]))
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
    -- red under: the Tokens/Rules cheat sheet (Task 20) without either heading
    assertTrue(P.hasText(ws, L["Tokens"]))
    assertTrue(P.hasText(ws, L["Rules"]))
    assertTrue(P.hasText(ws, L["To write a literal [, ] or $, type it twice:"]))
    assertTrue(P.hasText(ws, L["[[, ]] or $$."]))
    -- red under: the cheat sheet leaving out how an odd run of [ combines an escape and a bracket
    assertTrue(P.hasText(ws, L["Escapes and brackets combine:"]))
    assertTrue(P.hasText(ws, L["[[[$stacks$]]] shows [3] only when stacked."]))
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

test("text page: the section is named Text Template (Task 20, owner: rename this section)", function()
    local NS, _, P, ws = textPage()
    -- red under: the subgroup still reading "What each line says"
    assertEqual(NS.FindSchemaRow(P_ .. "template").subgroup, NS.L["Text Template"])
    -- the subgroup heading is an AceGUI Heading, not a Label, so P.hasText (Label-only) misses it
    assertTrue(P.find(ws, "Heading", NS.L["Text Template"]) ~= nil, "the heading reads Text Template")
    assertTrue(P.find(ws, "Heading", "What each line says") == nil, "the old heading is gone")
end)

test("text page: the Preview is a disabled EditBox labeled Preview, PrettyChat's own shape (Task 20)", function()
    local NS, _, P, ws = textPage()
    local box = preview(NS, P, ws)
    -- red under: no Preview EditBox, or a Label in its place
    assertTrue(box ~= nil, "the Preview box is drawn")
    assertEqual(box.type, "EditBox")
    assertEqual(box.labelText, NS.L["Preview"])
    -- red under: an editable Preview (PrettyChat's previewInput is SetDisabled(true))
    assertTrue(box.disabled, "the Preview is read-only")
    assertTrue(box.fullWidth, "the Preview spans the pane")
    -- red under: the Preview showing anything but Text.PreviewLine's own rendering
    local sample = NS.Constants.TEXT_SAMPLE_AURAS.HELPFUL
    local raw = NS.Style.Text.PreviewLine(NS.Database.FindContainer(1).text, sample)
    assertTrue(box.text:find(raw, 1, true) ~= nil, box.text)
end)

test("text page: the Preview box refreshes after a template change (Task 20)", function()
    local NS, m, P, ws = textPage()
    -- red under: the box seeded once and never rebuilt (nothing to refresh FROM)
    assertTrue(preview(NS, P, ws).text:find("Ignore Pain x3", 1, true) ~= nil, "the default template's line")
    NS.SetByPath(P_ .. "template", "$spellname$", 1)
    m.__fireTimers()
    ws = P.rerender("Text")
    local sample = NS.Constants.TEXT_SAMPLE_AURAS.HELPFUL
    local raw = NS.Style.Text.PreviewLine(NS.Database.FindContainer(1).text, sample)
    -- red under: the Preview box built once and never rebuilt on a structural refresh
    assertTrue(preview(NS, P, ws).text:find(raw, 1, true) ~= nil, preview(NS, P, ws).text)
    assertFalse(preview(NS, P, ws).text:find("x3", 1, true) ~= nil, "the stacks field is gone from the new template")
end)

test("text page: the cheat sheet has a Tokens heading, a Rules heading and one bullet per token (Task 20)", function()
    local NS, _, P, ws = textPage()
    local tokenBullets = 0
    for _, t in ipairs(P.texts(ws)) do
        for _, def in ipairs(NS.Constants.TEXT_TOKENS) do
            if t:find("$" .. def.key .. "$", 1, true) and t:sub(1, 2) == "- " then
                tokenBullets = tokenBullets + 1
            end
        end
    end
    -- red under: a token folded onto another's line, or drawn twice
    assertEqual(tokenBullets, #NS.Constants.TEXT_TOKENS)
    assertTrue(P.hasText(ws, NS.L["Tokens"]))
    assertTrue(P.hasText(ws, NS.L["Rules"]))
    -- red under: the Rules list without the separator advice (smoke batch 2, item 8)
    assertTrue(P.hasText(ws, NS.L["Put a separator inside the brackets of the field it leads, so an empty field takes it along:"]))
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

test("text page: Center on a multi-piece template draws the note naming its rows (feedback #1)", function()
    local NS, _, P = textPage()
    local note = NS.L["Center stacks this template in %d rows, one per field; text outside [ ] is not drawn."]
    NS.SetByPath(P_ .. "justifyH", "CENTER", 1)
    local ws = P.rerender("Text")
    -- red under: centerNote still saying Center lines a multi-piece template up Left
    assertTrue(P.hasText(ws, note:format(3)), "the default template has three fields")
    -- red under: the Preview not showing the stack it will draw, or joining its rows with a raw
    -- "\n" (final review: a single-line EditBox does not lay a newline out as a break) instead of a
    -- visible " / " separator
    assertTrue(preview(NS, P, ws).text:find("Ignore Pain /  x3 /  - 11s", 1, true) ~= nil, preview(NS, P, ws).text)
    assertFalse(preview(NS, P, ws).text:find("\n", 1, true) ~= nil, "no raw newline reaches the EditBox")
    NS.SetByPath(P_ .. "template", "$spellname$ :: $stacks$", 1)
    ws = P.rerender("Text")
    assertTrue(P.hasText(ws, note:format(2)), "a literal is not a row")
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

--- The Icon tab as the current settings draw it, as animationTab draws the Animation tab.
local function iconTab(NS, P)
    local ws = P.rerender("Text")
    if NS.Helpers.__pageCtx.text.activeTab == NS.L["Icon"] then return ws end
    return P.tab("text", NS.L["Icon"])
end

-- The Icon tab's rows that draw nothing while Icon position is None (smoke batch 2, item 6).
local ICON_ROWS = { "iconSize", "iconGap", "iconZoom", "iconBorderShow", "iconBorderStyle", "iconBorderSize",
    "useClassColorIconBorder" }

test("text page: with Icon position None every Icon row but the position dims, the swatch excepted, under a note (item 6)", function()
    local NS, _, P = textPage()
    local note = NS.L["Set Icon position to show the icon."]
    assertEqual(NS.db.profile.containers[1].text.icon, "NONE", "the template's default: no icon")
    local ws = iconTab(NS, P)
    -- red under: the Icon tab's afterGroup note not drawn
    assertTrue(P.hasText(ws, note), "the note")
    assertFalse(P.row(ws, P_ .. "icon").disabled and true or false, "Icon position stays live")
    for _, key in ipairs(ICON_ROWS) do
        -- red under: an Icon row without the noIcon predicate (it looks live and draws nothing)
        assertTrue(P.row(ws, P_ .. key).disabled, key)
    end
    -- anti-pattern #74: a color swatch is never grayed
    assertFalse(P.row(ws, P_ .. "iconBorderColor").disabled and true or false, "the swatch stays live")
    -- red under: Icon position without its structural redraw (the note and the dim outlive the change)
    assertTrue(NS.FindSchemaRow(P_ .. "icon").onChange ~= nil, "a position change redraws the page")
    NS.SetByPath(P_ .. "icon", "LEFT", 1)
    ws = iconTab(NS, P)
    assertFalse(P.hasText(ws, note), "no note with an icon")
    for _, key in ipairs(ICON_ROWS) do
        assertFalse(P.row(ws, P_ .. key).disabled and true or false, key .. " is live on Left")
    end
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
    -- (fix round 1: no " - " separator — the stacked second row would read " - 11s")
    assertEqual(s.template, "$spellname$[$remainingduration$]")
    assertEqual(s.justifyH, "CENTER")
    assertEqual(picker(NS, P, ws).value, "centered", "Name + time with Center reads as the centered one")
    ws = pick(NS, m, P, ws, "name")
    -- red under: a plain built-in leaving the line centered (Center is the centered built-in's)
    assertEqual(s.justifyH, "LEFT")
    assertEqual(picker(NS, P, ws).value, "name")
end)

test("text page: picking a built-in that also moves Justify writes and applies once (final review)", function()
    local NS, m, P, ws = textPage()
    ws = pick(NS, m, P, ws, "timeOfMax")   -- Left; picking Centered next must also move justifyH
    local lines = captureLog(NS)
    local inst = NS.ContainerManager.instances[1]
    local applies = 0
    local apply = inst.Apply
    inst.Apply = function(...) applies = applies + 1; return apply(...) end
    picker(NS, P, ws):__fire("OnValueChanged", "centered")
    m.__fireTimers()
    inst.Apply = apply
    local s = NS.Database.FindContainer(1).text
    assertEqual(s.template, "$spellname$[$remainingduration$]")
    assertEqual(s.justifyH, "CENTER")
    -- red under: the template and justify writes each queuing their own apply pass (two, not one)
    assertEqual(applies, 1, "one apply pass for both writes")
    -- red under: no NS.Bulk.Run bracket, so each write logs its own [Set] line
    assertEqual(#lines, 2, "one [Set] line and one [Apply] line: " .. table.concat(lines, " | "))
    assertTrue(lines[1]:find("^%[Set%] pick built%-in", 1) ~= nil, lines[1])
    assertTrue(lines[2]:find("^%[Apply%] applied", 1) ~= nil, lines[2])
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

test("text page: the Preview box renders the sample aura, brackets filled and empty ones hidden (feedback #5)", function()
    local NS, m, P, ws = textPage()
    local L = NS.L
    -- The buff sample: Ignore Pain, 3 stacks, 11 of 12 s, no dispel type. The harness has no seconds
    -- formatter, so a time reads as whole seconds ("11s").
    -- red under: no Preview box, or one not filled from the sample
    assertTrue(preview(NS, P, ws).text:find("Ignore Pain x3 - 11s", 1, true) ~= nil)
    NS.SetByPath(P_ .. "template", "$spellname$[ ($remainingpercent$%)][ ($dispeltype$)]", 1)
    m.__fireTimers()
    ws = P.rerender("Text")
    -- red under: an empty bracket drawn (the dispel type of a typeless aura), or a percent carrying
    -- its own "%" beside the one typed
    assertTrue(preview(NS, P, ws).text:find("Ignore Pain (92%)", 1, true) ~= nil)
    -- The debuff sample: Shadow Word: Pain, no stacks, a Magic type.
    NS.SetByPath("container.style", "text", 2)
    NS.Helpers.SelectContainer(2)
    ws = P.rerender("Text")
    ws = pick(NS, m, P, ws, "nameTypeTime")
    assertTrue(preview(NS, P, ws).text:find("Shadow Word: Pain (" .. L["Magic"] .. ") - 11s", 1, true) ~= nil)
    ws = pick(NS, m, P, ws, "nameStacksTime")
    assertTrue(preview(NS, P, ws).text:find("Shadow Word: Pain - 11s", 1, true) ~= nil, "no stacks, so no ' x'")
end)

test("text page: the centered built-in's Preview joins its two rows with a visible separator (final review)", function()
    local NS, m, P, ws = textPage()
    ws = pick(NS, m, P, ws, "centered")
    -- red under: the stacked rows still joined by a raw "\n" (a single-line EditBox swallows it)
    -- instead of the controller's " / " separator
    assertTrue(preview(NS, P, ws).text:find("Ignore Pain / 11s", 1, true) ~= nil, preview(NS, P, ws).text)
    assertFalse(preview(NS, P, ws).text:find("\n", 1, true) ~= nil, "no raw newline reaches the EditBox")
end)

-- ── escapeStrayPipes (final review: no direct test existed) ──────────────────────────────────────

test("text page: a literal | in a custom template is doubled in the Preview box, not left to break it (final review)", function()
    local NS, m, P, ws = textPage()
    ws = pick(NS, m, P, ws, "custom")
    local box = P.row(ws, P_ .. "template")
    box:__fire("OnEnterPressed", "$spellname$|extra")
    ws = P.rerender("Text")
    -- red under: escapeStrayPipes leaving a lone "|" from the player's own template text undoubled
    assertTrue(preview(NS, P, ws).text:find("Ignore Pain||extra", 1, true) ~= nil, preview(NS, P, ws).text)
end)

test("text page: an already-doubled || in a custom template still doubles each pipe (final review)", function()
    local NS, m, P, ws = textPage()
    ws = pick(NS, m, P, ws, "custom")
    local box = P.row(ws, P_ .. "template")
    box:__fire("OnEnterPressed", "$spellname$||extra")
    ws = P.rerender("Text")
    -- red under: escapeStrayPipes treating an existing "||" as already-escaped and leaving it alone
    -- (each of the two literal pipes must double on its own, to "||||")
    assertTrue(preview(NS, P, ws).text:find("Ignore Pain||||extra", 1, true) ~= nil, preview(NS, P, ws).text)
end)

test("text page: a colored dispel word's |cff...|r run survives escapeStrayPipes intact (final review)", function()
    local NS, m, P = textPage()
    NS.SetByPath("container.style", "text", 2)
    NS.Helpers.SelectContainer(2)
    local ws = P.rerender("Text")
    pick(NS, m, P, ws, "nameType")
    NS.SetByPath(P_ .. "dispelTypeColor", true, 2)
    ws = P.rerender("Text")
    local sample = NS.Constants.TEXT_SAMPLE_AURAS.HARMFUL
    local raw = NS.Style.Text.PreviewLine(NS.Database.FindContainer(2).text, sample)
    local run = raw:match("|cff%x%x%x%x%x%x.-|r")
    assertTrue(run ~= nil, raw)
    -- red under: escapeStrayPipes doubling the protected color run instead of restoring it whole
    assertTrue(preview(NS, P, ws).text:find(run, 1, true) ~= nil, preview(NS, P, ws).text)
    -- red under: a naive blind-double leaving a doubled copy of the run in the box instead
    assertFalse(preview(NS, P, ws).text:find((run:gsub("|", "||")), 1, true) ~= nil)
end)

-- ── color by dispel type (feedback #7) ────────────────────────────────────────────────────────

test("text page: Animation carries the three dispel-type options, all off, each dimmed until it can show (feedback #7)", function()
    local NS, _, P = textPage()
    local L = NS.L
    local D = NS.CONTAINER_TEMPLATE.text
    -- red under: any of the three on by default (owner, 2026-09-19: all opt-in, all off)
    assertFalse(D.dispelTypeColor)
    assertFalse(D.dispelBackdrop)
    assertFalse(D.dispelEdge)
    local ws = animationTab(NS, P)
    for _, key in ipairs({ "dispelTypeColor", "dispelBackdrop", "dispelBackdropAlpha", "dispelEdge", "dispelEdgeSize" }) do
        local row = NS.FindSchemaRow(P_ .. key)
        -- red under: no row
        assertTrue(row ~= nil and row.group == L["Animation"] and row.subgroup == L["Dispel type"], key)
        assertTrue(P.row(ws, P_ .. key) ~= nil, key .. " is drawn")
    end
    -- The default template has no $dispeltype$, so there is no word to color.
    assertTrue(P.row(ws, P_ .. "dispelTypeColor").disabled, "the word needs the token")
    assertTrue(P.row(ws, P_ .. "dispelBackdropAlpha").disabled, "the opacity waits for the backdrop")
    assertTrue(P.row(ws, P_ .. "dispelEdgeSize").disabled, "the thickness waits for the edge")
    NS.SetByPath(P_ .. "template", "$spellname$[ ($dispeltype$)]", 1)
    NS.SetByPath(P_ .. "dispelBackdrop", true, 1)
    NS.SetByPath(P_ .. "dispelEdge", true, 1)
    ws = animationTab(NS, P)
    for _, key in ipairs({ "dispelTypeColor", "dispelBackdropAlpha", "dispelEdgeSize" }) do
        -- red under: a predicate reading the wrong leaf
        assertFalse(P.row(ws, P_ .. key).disabled and true or false, key .. " is live")
    end
end)
