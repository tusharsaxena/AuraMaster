-- tests/test_style_text_icon.lua — modules/Style_Text.lua: a text line's icon, a refused icon call on a
-- live re-dress and the icon's border. Peeled out of tests/test_style_text.lua by theme.

local T = _G.AM_TEST
local spyConsole = dofile("tests/console_spy.lua")
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local B = dofile("tests/region_builder.lua")
local BS = dofile("tests/border_strips.lua")

local env
local function E()
    if not env then
        local NS, m = dofile("tests/fresh_env.lua")({ before = dofile("tests/text_apis.lua") })
        env = { NS = NS, m = m }
    end
    return env.NS, env.m
end

local function cfg(over)
    local NS = E()
    return NS.Database.Merge(NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE), over or {})
end

--- A text element dressed for `c`: the button, its regions, and every recorder the dress built.
local function dressed(c, engine, frame, made)
    local NS, m = E()
    made = made or {}
    frame = frame or B.new(made)
    B.during(m, made, function() NS.Style.Element(frame, c, engine) end)
    return frame, frame.__am, made
end

local function text(over)
    local t = { style = "text", text = over or {} }
    return cfg(t)
end

local STACKED = "$spellname$ :: $stacks$[ - $remainingduration$]"

-- ── the icon ───────────────────────────────────────────────────────────────────────────────────

test("text style: an icon on the left sits on the animated frame and the text area starts after it and its gap", function()
    local frame, am = dressed(text({ height = 16, icon = "LEFT", iconSize = 0, iconGap = 3 }), true)
    assertEqual(am.icon:__joined("SetSize"), "16,16", "size 0 is the line's height")
    local p = am.icon:__last("SetPoint")
    assertEqual(p[1], "LEFT"); assertTrue(p[2] == am.anim)
    local a = am.area:__calls("SetPoint")
    -- red under: the text area ignoring the icon (the line drawn under it)
    assertEqual(a[1][1], "TOPLEFT"); assertEqual(a[1][4], 16 + 3)
    assertEqual(a[2][1], "BOTTOMRIGHT"); assertEqual(a[2][4], 0)
    assertTrue(frame:__last("SetIcon")[1] == am.icon)
end)

test("text style: on a stacked Center, icon size 0 is ONE ROW's height, not the whole stack (fix round 1, feedback #1)", function()
    local _, am = dressed(text({ template = STACKED, justifyH = "CENTER", height = 16, icon = "LEFT", iconSize = 0 }))
    -- red under: layoutIconAndArea handing the stack's full height to IconSizeFor (the icon grows to
    -- the whole stack, "16,16" from the old un-grown box, or "40,40" from the grown one, not "12,12")
    assertEqual(am.icon:__joined("SetSize"), "12,12", "size 0 is one row's height (the 12pt font)")
    -- a taller font's row is still one row, not the two- or three-row stack
    _, am = dressed(text({ template = STACKED, justifyH = "CENTER", height = 16, icon = "LEFT", iconSize = 0,
        font = { fontSize = 20 } }))
    assertEqual(am.icon:__joined("SetSize"), "20,20")
    -- unstacked (Left), size 0 is still the box's own height, exactly as before
    _, am = dressed(text({ template = STACKED, justifyH = "LEFT", height = 16, icon = "LEFT", iconSize = 0 }))
    assertEqual(am.icon:__joined("SetSize"), "16,16")
end)

test("text style: an icon on the right insets the area's right edge; none hides it and binds nothing", function()
    local _, am = dressed(text({ icon = "RIGHT", iconSize = 12, iconGap = 2 }), true)
    local a = am.area:__calls("SetPoint")
    assertEqual(a[1][4], 0); assertEqual(a[2][4], -(12 + 2))
    local frame
    frame, am = dressed(text({ icon = "NONE" }), true)
    assertFalse(am.icon:IsShown())
    assertFalse(am.iconBorder:IsShown())
    assertTrue(am.area:__last("SetAllPoints")[1] == am.anim)
    -- red under: Bind binding the icon whatever its setting
    assertEqual(frame:__count("SetIcon"), 0)
end)

test("text style: a left icon with its border on draws the border at its edge size and color, the art inset inside it (item 6)", function()
    local _, am = dressed(text({ height = 20, icon = "LEFT", iconSize = 20, iconBorderShow = true,
        iconBorderStyle = "Solid", iconBorderSize = 3, iconBorderColor = { r = 1, g = 0, b = 0, a = 1 },
        useClassColorIconBorder = false }), true)
    -- red under: nothing painting am.iconBorder on a Text line (the Icon border rows reach no region)
    BS.assertSolid(am.iconBorder, 3, "1,0,0,1", "the icon border")
    assertEqual(am.iconBorder:__joined("SetSize"), "20,20", "the border takes the icon's whole box")
    local b = am.iconBorder:__last("SetPoint")
    assertEqual(b[1], "LEFT"); assertTrue(b[2] == am.anim)
    -- red under: the art laid at the box's full size under a thick border
    assertEqual(am.icon:__joined("SetSize"), "14,14")
    local p = am.icon:__last("SetPoint")
    assertEqual(p[1], "LEFT"); assertTrue(p[2] == am.anim); assertEqual(p[4], 3)
end)

-- ── a refused icon call on a live re-dress (smoke batch 2, item 7) ─────────────────────────────

--- A live Text element with a bordered left icon, dressed once, then re-dressed live with `region`'s
--- `method` raising (am.iconBorder:Show, am.icon:SetSize), in a fresh environment whose client
--- error handler and debug log record. Every log is emptied before the re-dress, so they hold it alone.
--- `times` re-dresses that many times (default 1).
local function refusedRedress(region, method, times)
    local reported, lines = {}, {}
    local NS, m = dofile("tests/fresh_env.lua")({ before = function(mocks)
        dofile("tests/text_apis.lua")(mocks)
        mocks.geterrorhandler = function() return function(err)
            local n = #reported
            reported[n + 1] = tostring(err)
        end end
    end })
    NS.State.debug = true
    spyConsole(NS, function(tag, fmt, ...)
        local n = #lines
        lines[n + 1] = tag .. ":" .. fmt:format(...)
    end)
    local c = NS.Database.Merge(NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE), { style = "text", text = {
        icon = "LEFT", iconSize = 14, iconGap = 2, iconBorderShow = true, iconBorderStyle = "Solid",
        iconBorderSize = 2 } })
    local made = {}
    local frame = B.new(made)
    B.during(m, made, function() NS.Style.Element(frame, c, true) end)
    local am = frame.__am
    am[region].__raise[method] = true
    frame.__log = {}
    for _, r in ipairs(made) do r.__log = {} end
    local ok, err = true, nil
    for _ = 1, times or 1 do
        ok, err = pcall(B.during, m, made, function() NS.Style.Element(frame, c, true) end)
        if not ok then break end
    end
    am[region].__raise[method] = nil
    return { ok = ok, err = err, frame = frame, am = am, reported = reported, lines = lines }
end

--- The anchor points `r` took after its last ClearAllPoints, in order.
local function anchorsSinceClear(r)
    local out = {}
    for _, e in ipairs(r.__log) do
        if e.name == "ClearAllPoints" then out = {} end
        if e.name == "SetPoint" then
            local n = #out
            out[n + 1] = e.args[1]
        end
    end
    return out
end

--- The earliest call order stamp across `regions`' logs (nil when none was called).
local function firstSeq(regions)
    local low
    for _, r in ipairs(regions) do
        for _, e in ipairs(r.__log) do
            if not low or e.seq < low then low = e.seq end
        end
    end
    return low
end

--- How many of `lines` carry `needle`.
local function matching(lines, needle)
    local n = 0
    for _, l in ipairs(lines) do
        if l:find(needle, 1, true) then n = n + 1 end
    end
    return n
end

--- The item-7 assertions shared by both refusals: the text survives, the icon alone is lost.
local function assertTextSurvives(got, needle)
    local am = got.am
    -- red under: the refusal escaping the icon block (Text.Apply stops, the caller's pcall drops it)
    assertTrue(got.ok, tostring(got.err))
    -- red under: the area's anchors cleared and laid after the icon (a raise leaves an unanchored area)
    assertEqual(table.concat(anchorsSinceClear(am.area), ","), "TOPLEFT,BOTTOMRIGHT", "the text area keeps both anchors")
    assertEqual(am.area:__calls("SetPoint")[1][4], 14 + 2, "still beside the icon's box")
    -- red under: the icon block run before the text area is anchored
    assertTrue(am.area:__lastSeq("SetPoint") < firstSeq({ am.icon, am.iconBorder }), "the area is anchored first")
    local head = am.piece1:__last("SetPoint")
    assertTrue(head ~= nil and head[2] == am.area, "the chain head is anchored in the area")
    assertTrue(got.frame:__last("SetSpellName")[1] == am.piece1, "the text binding is still bound")
    assertFalse(am.icon:IsShown(), "the icon is what the refusal costs")
    -- red under: the refusal swallowed (Style.Bind's pattern without the report)
    assertEqual(#got.reported, 1, "handed to the client's error handler")
    assertTrue(got.reported[1]:find(needle, 1, true) ~= nil, got.reported[1])
    assertEqual(matching(got.lines, needle), 1, "one debug line: " .. table.concat(got.lines, " | "))
end

test("text style: an icon border the client refuses on a live re-dress costs the icon, never the text, and is reported", function()
    assertTextSurvives(refusedRedress("iconBorder", "Show"), "Show refused")
end)

test("text style: an icon whose SetSize is refused on a live re-dress costs the icon, never the text, and is reported", function()
    assertTextSurvives(refusedRedress("icon", "SetSize"), "SetSize refused")
end)

test("text style: the same refusal on every re-dress reaches the error handler once, and the debug log once", function()
    local got = refusedRedress("iconBorder", "Show", 3)
    assertTrue(got.ok, tostring(got.err))
    -- red under: geterrorhandler called on every re-dress (a restyle of 40 buttons floods BugSack)
    assertEqual(#got.reported, 1)
    -- red under: Style.ReportError writing its debug line per failure rather than once per distinct
    -- error (debug-logging-§8, "Errors caught"; three re-dresses that fail the same way are one line)
    assertEqual(matching(got.lines, "Show refused"), 1)
end)

-- ── the icon border on a live button (B2-3) ────────────────────────────────────────────────────
-- Last batch's empty boxes: with the icon border on, a live re-dress (a Width change) raised in
-- Backdrop.lua:226 on the border's secret size, and the icon block's guard hid the icon. The border is
-- strips now, and reads no size.

test("text style: a live re-dress with the icon border on under secret geometry draws the border and reports nothing (B2-3)", function()
    local reported, lines = {}, {}
    local NS, m = dofile("tests/fresh_env.lua")({ before = function(mocks)
        dofile("tests/text_apis.lua")(mocks)
        mocks.geterrorhandler = function() return function(err)
            local n = #reported
            reported[n + 1] = tostring(err)
        end end
    end })
    NS.Debug = function(tag, fmt, ...)
        local n = #lines
        lines[n + 1] = tag .. ":" .. fmt:format(...)
    end
    local function c(width)
        return NS.Database.Merge(NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE), { style = "text", text = {
            width = width, icon = "LEFT", iconSize = 14, iconBorderShow = true, iconBorderStyle = "Solid",
            iconBorderSize = 2, iconBorderColor = { r = 0, g = 1, b = 0, a = 1 } } })
    end
    local made = {}
    local frame = B.new(made)
    B.during(m, made, function() NS.Style.Element(frame, c(200), true) end)
    local am = frame.__am
    m.__layOut(frame)
    for _, r in ipairs(made) do m.__layOut(r) end
    frame.__log = {}
    for _, r in ipairs(made) do r.__log = {} end
    local ok, err = pcall(B.during, m, made, function() NS.Style.Element(frame, c(260), true) end)
    assertTrue(ok, tostring(err))
    -- red under: SetBackdrop on the laid-out icon border (the raise the icon block's guard reported)
    assertEqual(#reported, 0, table.concat(reported, " | "))
    assertEqual(matching(lines, "text icon"), 0, table.concat(lines, " | "))
    assertTrue(am.icon:IsShown(), "the icon shows")
    BS.assertSolid(am.iconBorder, 2, "0,1,0,1", "the icon border")
    assertTrue(frame:__last("SetSpellName")[1] == am.piece1, "the text is bound")
end)
