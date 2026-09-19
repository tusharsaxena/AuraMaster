-- tests/test_style_text.lua — modules/Style_Text.lua: how one aura is dressed as a LINE OF TEXT. The
-- nested clip, animation and text-area frames, the chain's anchors for every justify, each piece's
-- engine binding and its options, the blink, the loops, the icon, a refused stored template, the
-- chain kept per template shape, and the preview fill.
--
-- One environment with the client's text APIs as recording stand-ins (tests/text_apis.lua), built
-- once: every element is built on tests/region_builder.lua's recorders, so each piece records its
-- own calls, and nothing below writes to the environment.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
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

--- The pieces of `am`'s current chain, in order.
local function pieces(am)
    local out = {}
    for i = 1, am.pieceCount do out[i] = am["piece" .. i] end
    return out
end

local function text(over)
    local t = { style = "text", text = over or {} }
    return cfg(t)
end

-- ── the frames ─────────────────────────────────────────────────────────────────────────────────

test("text style: the element takes its size; clip, animation and text-area frames nest inside it", function()
    local frame, am = dressed(text({ width = 250, height = 18 }))
    assertEqual(frame:__joined("SetSize"), "250,18")
    -- red under: build without the clip frame (a bounce or a long line drawn over a neighbor)
    assertTrue(am.clip.parent == frame)
    assertEqual(am.clip:__joined("SetClipsChildren"), "true")
    assertTrue(am.clip:__last("SetAllPoints")[1] == frame)
    assertTrue(am.anim.parent == am.clip, "the animated frame inside the clip")
    assertTrue(am.area.parent == am.anim and am.icon.parent == am.anim, "the icon and the text move together")
    -- red under: the text area left unclipped (a long line runs under the icon)
    assertEqual(am.area:__joined("SetClipsChildren"), "true")
    assertTrue(am.chain.parent == am.area)
end)

-- ── the chain ──────────────────────────────────────────────────────────────────────────────────

test("text style: Left lays the first piece at the area's left and each next piece against the previous one", function()
    local _, am = dressed(text({ template = "$spellname$ - $stacks$", justifyH = "LEFT", justifyV = "MIDDLE", x = 3, y = -1 }))
    local p = pieces(am)
    assertEqual(#p, 3)
    local first = p[1]:__last("SetPoint")
    assertEqual(first[1], "LEFT"); assertTrue(first[2] == am.area); assertEqual(first[3], "LEFT")
    assertEqual(first[4], 3); assertEqual(first[5], -1)
    for i = 2, 3 do
        local pt = p[i]:__last("SetPoint")
        -- red under: a piece anchored to the area instead of the previous piece (pieces overlap)
        assertEqual(pt[1], "LEFT"); assertTrue(pt[2] == p[i - 1]); assertEqual(pt[3], "RIGHT")
        assertEqual(pt[4], 0); assertEqual(pt[5], 0)
    end
    for _, fs in ipairs(p) do
        -- red under: a piece given a width (the client auto-sizes an engine-written string)
        assertEqual(fs:__count("SetWidth"), 0)
        assertEqual(fs:__count("SetPoint"), 1, "single-anchored")
        assertEqual(fs:__joined("SetWordWrap"), "false")
    end
end)

test("text style: Right lays the last piece at the area's right and each earlier piece against the next", function()
    local _, am = dressed(text({ template = "$spellname$ - $stacks$", justifyH = "RIGHT", x = -2, y = 0 }))
    local p = pieces(am)
    local last = p[3]:__last("SetPoint")
    -- red under: layoutChain ignoring the justify (a Right line laid from the left)
    assertEqual(last[1], "RIGHT"); assertTrue(last[2] == am.area); assertEqual(last[3], "RIGHT"); assertEqual(last[4], -2)
    for i = 1, 2 do
        local pt = p[i]:__last("SetPoint")
        assertEqual(pt[1], "RIGHT"); assertTrue(pt[2] == p[i + 1]); assertEqual(pt[3], "LEFT")
    end
end)

test("text style: the vertical justify picks the top, middle or bottom anchor points", function()
    for v, want in pairs({ TOP = "TOPLEFT", MIDDLE = "LEFT", BOTTOM = "BOTTOMLEFT" }) do
        local _, am = dressed(text({ template = "$spellname$ $stacks$", justifyV = v }))
        local p = pieces(am)
        -- red under: V_PREFIX missing a justify, or the links anchored at the middle whatever it says
        assertEqual(p[1]:__last("SetPoint")[1], want, v)
        assertEqual(p[2]:__last("SetPoint")[3], want:gsub("LEFT", "RIGHT"), v .. " link")
    end
    local _, am = dressed(text({ template = "$spellname$ $stacks$", justifyH = "RIGHT", justifyV = "TOP" }))
    assertEqual(pieces(am)[2]:__last("SetPoint")[1], "TOPRIGHT")
end)

-- ── the padding between pieces (smoke batch 2, item 8) ─────────────────────────────────────────

--- How many characters the measuring string was last given.
local function chars(fs)
    return fs:__last("SetText")[1]:len()
end

--- A fresh environment whose padding is measured on a recorder answering 6 per character plus 2 of
--- padding per string, so W("a") + W("b") - W("ab") is 2; `answer` replaces the width it answers.
local function padded(answer)
    local NS, m = dofile("tests/fresh_env.lua")({ before = dofile("tests/text_apis.lua") })
    local fs = dofile("tests/region_recorder.lua")()
    fs.__answer.GetStringWidth = answer or function(self)
        return chars(self) * 6 + 2
    end
    NS.Style.__measurer = function() return fs end
    local function dress(c)
        local made = {}
        local frame = B.new(made)
        B.during(m, made, function() NS.Style.Element(frame, c) end)
        return frame.__am
    end
    local function textCfg(over)
        return NS.Database.Merge(NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE), { style = "text", text = over })
    end
    return NS, fs, dress, textCfg
end

test("text style: each chained piece is pulled back over the previous one by the measured padding (item 8)", function()
    local _, _, dress, textCfg = padded()
    local am = dress(textCfg({ template = "$spellname$-$stacks$", justifyH = "LEFT", x = 0 }))
    local p = pieces(am)
    -- red under: layoutChain chaining at offset 0 (the client's padding between every two pieces)
    assertEqual(p[1]:__last("SetPoint")[4], 0, "the head keeps the line's x")
    for i = 2, 3 do assertEqual(p[i]:__last("SetPoint")[4], -2, "piece " .. i) end
    am = dress(textCfg({ template = "$spellname$-$stacks$", justifyH = "RIGHT" }))
    p = pieces(am)
    -- a Right line is laid from its last piece back: each earlier piece moves right by the padding
    for i = 1, 2 do assertEqual(p[i]:__last("SetPoint")[4], 2, "piece " .. i) end
end)

test("text style: a padding that cannot be measured chains at 0, and is measured again later (item 8)", function()
    local width = 0
    local NS, fs = padded(function(self)
        if width > 0 then return chars(self) * width + 3 end
        return width
    end)
    local t, tdef = { fontSize = 12 }, NS.CONTAINER_TEMPLATE.text.font
    -- red under: a string not yet laid out (every width 0) cached as a padding of 0 for good
    assertEqual(NS.Style.PiecePadding(t, tdef), 0)
    width = 5
    assertEqual(NS.Style.PiecePadding(t, tdef), 3, "measured once it answers")
    fs.__answer.GetStringWidth = function() return nil end
    assertEqual(NS.Style.PiecePadding({ fontSize = 13 }, tdef), 0, "no number: 0")
    fs.__raise.GetStringWidth = true
    -- red under: measurePadding unguarded (the raise aborts the dress)
    assertEqual(NS.Style.PiecePadding({ fontSize = 14 }, tdef), 0, "a raise: 0")
    fs.__raise.GetStringWidth = nil
    fs.__answer.GetStringWidth = function(self) return chars(self) * 6 - 1 end
    assertEqual(NS.Style.PiecePadding({ fontSize = 15 }, tdef), 0, "kerned tighter than its parts: never negative")
end)

test("text style: the padding is measured once per font, size and flags (item 8)", function()
    local NS, fs = padded()
    local tdef = NS.CONTAINER_TEMPLATE.text.font
    assertEqual(NS.Style.PiecePadding({ fontSize = 12 }, tdef), 2)
    local measured = fs:__count("SetText")
    NS.Style.PiecePadding({ fontSize = 12 }, tdef)
    -- red under: PiecePadding measuring on every dress
    assertEqual(fs:__count("SetText"), measured, "cached")
    NS.Style.PiecePadding({ fontSize = 12, fontFlags = "OUTLINE" }, tdef)
    assertTrue(fs:__count("SetText") > measured, "new flags measure again")
end)

test("text style: every piece is justified to its side of the chain; a stacked row is centered (item 8)", function()
    for side, want in pairs({ LEFT = "LEFT", RIGHT = "RIGHT", CENTER = "CENTER" }) do
        local _, am = dressed(text({ template = "$spellname$-$stacks$", justifyH = side }))
        -- red under: pieces left at the client's default justify (padding on both sides of each)
        for i, fs in ipairs(pieces(am)) do
            local j = fs:__last("SetJustifyH")
            assertEqual(j and j[1], want, side .. " piece " .. i)
        end
    end
    local _, am = dressed(text({ template = "$spellname$", justifyH = "CENTER" }))
    local j = pieces(am)[1]:__last("SetJustifyH")
    assertEqual(j and j[1], "CENTER", "a one-piece Center line")
end)

test("text style: Center centers a one-piece template as one line, exactly as before (feedback #1)", function()
    local _, am = dressed(text({ template = "$spellname$", justifyH = "CENTER", justifyV = "MIDDLE" }))
    local pt = pieces(am)[1]:__last("SetPoint")
    assertEqual(pt[1], "CENTER"); assertEqual(pt[3], "CENTER")
    _, am = dressed(text({ template = "$spellname$", justifyH = "CENTER", justifyV = "TOP" }))
    assertEqual(pieces(am)[1]:__last("SetPoint")[1], "TOP")
    local NS = E()
    -- A one-piece template is a one-row stack: nothing to stack, no growth.
    assertEqual(NS.Style.Text.StackHeight({ template = "$spellname$", justifyH = "CENTER" }), 0)
end)

-- A four-piece line: name, a literal, stacks, and a bracketed duration run.
local STACKED = "$spellname$ :: $stacks$[ - $remainingduration$]"

test("text style: Center stacks a multi-piece template, each field a row centered under the last; literals are not drawn (feedback #1)", function()
    local _, am = dressed(text({ template = STACKED, justifyH = "CENTER", justifyV = "TOP", x = 3, y = -1 }))
    local p = pieces(am)
    local pitch = 12 + 2   -- the template's 12pt font, then C.TEXT_ROW_GAP
    local rows = { p[1], p[3], p[4] }
    for i, fs in ipairs(rows) do
        local pt = fs:__last("SetPoint")
        -- red under: the old chain (LEFT to the previous piece's RIGHT) for a centered multi-piece line
        assertEqual(pt[1], "TOP", "row " .. i)
        assertTrue(pt[2] == am.area, "row " .. i .. " hangs from the text area")
        assertEqual(pt[3], "TOP", "row " .. i)
        assertEqual(pt[4], 3, "row " .. i .. ": x nudges the stack")
        assertEqual(pt[5], -1 - (i - 1) * pitch, "row " .. i .. ": one pitch under the last")
        assertTrue(fs:IsShown(), "row " .. i)
    end
    -- red under: the literal drawn between two rows (it has nothing to sit between)
    assertFalse(p[2]:IsShown(), "the literal ' :: ' is not drawn")
    assertEqual(p[2]:__last("SetPoint"), nil, "and is anchored nowhere")
end)

test("text style: a stacked line's element grows to its rows; Left and Right keep the stored height (feedback #1)", function()
    local NS = E()
    local rows3 = 3 * 12 + 2 * 2
    -- red under: ElementSize ignoring the stack (rows overflowing a 16px box)
    assertEqual(select(2, NS.Style.ElementSize(text({ template = STACKED, justifyH = "CENTER", height = 16 }))), rows3)
    assertEqual(select(2, NS.Style.ElementSize(text({ template = STACKED, justifyH = "CENTER", height = 60 }))), 60,
        "a taller box keeps its height")
    assertEqual(select(2, NS.Style.ElementSize(text({ template = STACKED, justifyH = "LEFT", height = 16 }))), 16)
    assertEqual(select(2, NS.Style.ElementSize(text({ template = STACKED, justifyH = "CENTER", height = 16,
        font = { fontSize = 20 } }))), 3 * 20 + 2 * 2, "the rows follow the font size")
    local frame = dressed(text({ template = STACKED, justifyH = "CENTER", height = 16, width = 200 }))
    assertEqual(frame:__joined("SetSize"), "200," .. rows3, "the element is sized to it")
end)

test("text style: the vertical justify places the stack at the top, middle or bottom of a taller box (feedback #1)", function()
    local stack = 3 * 12 + 2 * 2
    for v, top in pairs({ TOP = 0, MIDDLE = (60 - stack) / 2, BOTTOM = 60 - stack }) do
        local _, am = dressed(text({ template = STACKED, justifyH = "CENTER", justifyV = v, height = 60, x = 0, y = 0 }))
        -- red under: STACK_TOP ignoring the justify (every stack at the top of its box)
        assertEqual(pieces(am)[1]:__last("SetPoint")[5], -top, v)
    end
end)

test("text style: a line moved off Center draws its literals again (feedback #1)", function()
    local c = text({ template = STACKED, justifyH = "CENTER" })
    local frame, am = dressed(c)
    assertFalse(pieces(am)[2]:IsShown())
    c.text.justifyH = "LEFT"
    local NS, m = E()
    B.during(m, {}, function() NS.Style.Element(frame, c, false) end)
    -- red under: a stacked dress's Hide left on the literal once the line is a chain again
    assertTrue(pieces(am)[2]:IsShown())
    assertEqual(pieces(am)[2]:__last("SetPoint")[1], "LEFT")
end)

test("text style: every piece takes the line's font; a literal takes its text", function()
    local _, am = dressed(text({ template = "$spellname$ :: $stacks$", font = { fontSize = 15, fontFlags = "NONE",
        fontColor = { r = 0.5, g = 0.6, b = 0.7, a = 1 } } }))
    local p = pieces(am)
    for i, fs in ipairs(p) do
        -- red under: dressPieces skipping the literal pieces (plain text in the default font)
        assertEqual(fs:__last("SetFont")[2], 15, "piece " .. i)
        assertEqual(fs:__joined("SetTextColor"), "0.5,0.6,0.7,1", "piece " .. i)
        assertTrue(fs:IsShown())
    end
    assertEqual(p[2]:__last("SetText")[1], " :: ")
    assertNil(p[1]:__last("SetText"), "the engine writes the name, never the dress")
end)

-- ── the engine ─────────────────────────────────────────────────────────────────────────────────

test("text style: each engine piece is bound to its own field, a literal to none", function()
    local frame, am = dressed(text({ template = "$spellname$ :: [ x$stacks$][ ($dispeltype$)][ - $remainingduration$]" }), true)
    local p = pieces(am)
    -- red under: BINDERS missing a kind, or binding the wrong string
    assertTrue(frame:__last("SetSpellName")[1] == p[1])
    assertTrue(frame:__last("SetApplicationCount")[1] == p[3])
    assertTrue(frame:__last("SetDispelTypeText")[1] == p[4])
    assertTrue(frame:__last("SetDurationText")[1] == p[5])
    assertEqual(frame:__count("SetSpellName") + frame:__count("SetApplicationCount")
        + frame:__count("SetDispelTypeText") + frame:__count("SetDurationText"), 4, "one binding per field")
end)

test("text style: stacks bind a rule formatter that hides one stack and folds the bracket text", function()
    local frame = dressed(text({ template = "$spellname$[ x$stacks$%]" }), true)
    local opts = frame:__last("SetApplicationCount")[2]
    local bp = opts.formatter:__last("SetBreakpoints")[1]
    -- red under: stackOptionsFor without the zero breakpoint (a single stack reads " x1%")
    assertEqual(bp[1].threshold, 0); assertEqual(bp[1].format, "")
    assertEqual(bp[2].threshold, 2); assertEqual(bp[2].format, " x%d%%")
    local again = dressed(text({ template = "$spellname$[ x$stacks$%]" }), true)
    assertTrue(again:__last("SetApplicationCount")[2] == opts, "built once per format")
end)

test("text style: dispel type binds a text map of every type in the bracket text, nothing without a type", function()
    local NS = E()
    local frame = dressed(text({ template = "$spellname$[ <$dispeltype$>]" }), true)
    local opts = frame:__last("SetDispelTypeText")[2]
    assertTrue(opts.showWhenHarmful and opts.showWhenHelpful, "buffs and debuffs")
    -- red under: showWithoutDispelType left on (a typeless aura shows the engine's own text)
    assertFalse(opts.showWithoutDispelType)
    for _, t in ipairs(NS.Constants.TEXT_DISPEL_TYPES) do
        assertEqual(opts.customDispelTextMap[t], " <" .. NS.L[NS.Constants.TEXT_DISPEL_LABELS[t]] .. ">", t)
    end
    assertNil(opts.customDispelTextMap.None)
end)

test("text style: the duration run binds its format, components and a prebuilt binding that writes nothing when timeless", function()
    local NS = E()
    local frame, am = dressed(text({ template = "$spellname$[ - $remainingduration$ / $maxduration$]", timeFormat = "short" }), true)
    local call = frame:__last("SetDurationText")
    local opts = call[2]
    assertEqual(opts.textFormat.formatString, " - {} / {}")
    assertEqual(#opts.textFormat.components, 2)
    -- red under: the binding left off (a timeless aura shows the engine's zero text and the " - ")
    assertTrue(opts.binding ~= nil and opts.binding == am.binding)
    assertEqual(opts.binding:__last("SetZeroDurationText")[1], "")
    assertEqual(opts.binding:__last("SetExpiredText")[1], "")
    assertEqual(opts.binding:__count("SetUpdateInterval"), 0, "no fast refresh without the blink")
    assertNil(opts.textColor)
    assertTrue(opts.textFormat == NS.Style.DurationTextFormat(NS.TextTemplate.Compile(
        "$spellname$[ - $remainingduration$ / $maxduration$]").pieces[2], "short"))
end)

test("text style: blink binds the blinking curve and a 0.1 s refresh; off, neither", function()
    local frame, am = dressed(text({ expiringColorOn = true, expiringBlink = true, expiringThreshold = 2 }), true)
    local opts = frame:__last("SetDurationText")[2]
    -- red under: bindingFor ignoring the blink (the curve steps between the engine's slow updates)
    assertTrue(opts.binding == am.blinkBinding)
    assertEqual(opts.binding:__last("SetUpdateInterval")[1], 0.1)
    assertEqual(opts.textColor.curve:__count("AddPoint"), 2 / 0.25 + 1)
    frame = dressed(text({ expiringColorOn = true, expiringBlink = false, expiringThreshold = 2 }), true)
    opts = frame:__last("SetDurationText")[2]
    assertEqual(opts.binding:__count("SetUpdateInterval"), 0)
    assertEqual(opts.textColor.curve:__count("AddPoint"), 2, "the plain running-out step")
end)

--- Two buttons of one container dressed live for `c` with the container's class snapshot `class`.
local function twoButtons(c, class)
    local NS, m = E()
    local made = {}
    local a, b = B.new(made), B.new(made)
    B.during(m, made, function()
        NS.Style.Element(a, c, true, class)
        NS.Style.Element(b, c, true, class)
    end)
    return a, b
end

test("text style: with the font's class color on, the running-out curves return to the class color, one curve per container", function()
    local class = { r = 0.2, g = 0.4, b = 0.6 }
    local c = text({ template = "$spellname$[ - $remainingduration$]", expiringColorOn = true, expiringThreshold = 2,
        font = { fontColor = { r = 1, g = 1, b = 1, a = 0.8 }, useClassColorFont = true } })
    local a, b = twoButtons(c, class)
    local curve = a:__last("SetDurationText")[2].textColor
    local normal = curve.curve:__last("AddPoint")[2]
    -- red under: the curve's normal read from the raw font color (white above the threshold)
    assertEqual(("%s,%s,%s,%s"):format(normal.r, normal.g, normal.b, normal.a), "0.2,0.4,0.6,0.8")
    -- red under: a fresh color table per dress (one curve built per button)
    assertTrue(b:__last("SetDurationText")[2].textColor == curve, "two buttons of one container share one curve")
    c.text.expiringColorOn, c.text.expiringBlink = false, true
    a = twoButtons(c, class)
    local blink = a:__last("SetDurationText")[2].textColor.curve
    -- red under: a blink with the recolor off blinking the raw font color
    local firstPoint
    for _, call in ipairs(blink.calls) do
        if call.name == "AddPoint" and not firstPoint then firstPoint = call end
    end
    assertEqual(firstPoint[2].r, 0.2, "the blink itself in the class color")
    assertEqual(blink:__last("AddPoint")[2].g, 0.4, "and back to the class color above the threshold")
end)

test("text style: a class snapshot that changes in place builds a new curve, never reuses the old class's", function()
    local class = { r = 0.2, g = 0.4, b = 0.6 }
    local c = text({ template = "$spellname$[ - $remainingduration$]", expiringColorOn = true,
        font = { useClassColorFont = true } })
    local first = twoButtons(c, class):__last("SetDurationText")[2].textColor
    class.r, class.g, class.b = 0.9, 0.8, 0.7
    local second = twoButtons(c, class):__last("SetDurationText")[2].textColor
    -- red under: the snapshot table itself used as the memo key (Container reuses it across unit swaps)
    assertTrue(second ~= first)
    assertEqual(second.curve:__last("AddPoint")[2].r, 0.9)
end)

test("text style: a loop setter that raises cannot cost the engine bindings: the fields are bound first", function()
    local NS, m = E()
    local made = {}
    local frame = B.new(made)
    B.during(m, made, function() NS.Style.Element(frame, text({}), false) end)
    frame.__am.pulse.__raise.SetToAlpha = true
    local ok = pcall(B.during, m, made, function() NS.Style.Element(frame, text({}), true) end)
    frame.__am.pulse.__raise.SetToAlpha = nil
    assertFalse(ok, "the raise still reaches the dress's caller")
    -- red under: applyLoops run before Text.Bind (a button built in combat would be left unbound)
    assertTrue(frame:__last("SetSpellName")[1] == frame.__am.piece1)
    assertEqual(frame:__count("SetDurationText"), 1)
end)

test("text style: two buttons of one container get distinct prebuilt duration bindings", function()
    local a, b = twoButtons(text({ template = "$spellname$[ - $remainingduration$]" }))
    local ba, bb = a:__last("SetDurationText")[2].binding, b:__last("SetDurationText")[2].binding
    -- red under: bindingFor memoized across buttons (one binding shared by two buttons)
    assertTrue(ba ~= nil and bb ~= nil)
    assertTrue(ba ~= bb)
    assertTrue(ba == a.__am.binding and bb == b.__am.binding)
end)

test("text style: a live re-dress for a new shape binds the new chain's strings, not the parked chain's", function()
    local made = {}
    local frame = B.new(made)
    local _, am = dressed(text({ template = "$spellname$[ - $remainingduration$]" }), true, frame, made)
    local oldName, oldTime = am.piece1, am.piece2
    dressed(text({ template = "$spellname$[ x$stacks$][ - $remainingduration$]" }), true, frame, made)
    -- red under: useChain keeping the old shape's strings, or Bind reading a stale piece key
    assertTrue(am.piece1 ~= oldName and am.piece3 ~= oldTime)
    assertTrue(frame:__last("SetSpellName")[1] == am.piece1)
    assertTrue(frame:__last("SetApplicationCount")[1] == am.piece2)
    assertTrue(frame:__last("SetDurationText")[1] == am.piece3)
end)

test("text style: a template without a duration token binds no duration text", function()
    local frame = dressed(text({ template = "$spellname$[ x$stacks$]" }), true)
    -- red under: Bind binding a duration text the template does not use
    assertEqual(frame:__count("SetDurationText"), 0)
end)

test("text style: a preview dress binds nothing", function()
    local frame = dressed(text({}), false)
    assertEqual(frame:__count("SetSpellName") + frame:__count("SetDurationText") + frame:__count("SetIcon"), 0)
end)

-- ── the loops ──────────────────────────────────────────────────────────────────────────────────

test("text style: the three loops are built once, looping as each effect needs, and None plays none", function()
    local _, am, made = dressed(text({ anim = "none" }))
    local groups = B.children(made, "AnimationGroup", am.anim)
    assertEqual(#groups, 3)
    assertEqual(am.pulseGroup:__joined("SetLooping"), "BOUNCE")
    assertEqual(am.blinkGroup:__joined("SetLooping"), "REPEAT")
    assertEqual(am.bounceGroup:__joined("SetLooping"), "BOUNCE")
    assertEqual(am.pulse.args[1], "Alpha"); assertEqual(am.blink.args[1], "Alpha")
    -- red under: a Scale loop (glyphs scaled past their boxes overlap the next piece)
    assertEqual(am.bounce.args[1], "Translation")
    for _, g in ipairs(groups) do
        assertTrue(g:__count("Stop") >= 1, "every loop stopped")
        -- red under: applyLoops playing a loop for None
        assertEqual(g:__count("Play"), 0)
    end
end)

test("text style: each effect plays its own loop with the speed, fade and height set", function()
    local frame = B.new({})
    local _, am = dressed(text({ anim = "pulse", animSpeed = 2, animIntensity = 0.4, animBounce = 5 }), false, frame)
    assertEqual(am.pulseGroup:__count("Play"), 1)
    assertEqual(am.blinkGroup:__count("Play") + am.bounceGroup:__count("Play"), 0)
    assertEqual(am.pulse:__last("SetToAlpha")[1], 0.4)
    assertEqual(am.pulse:__last("SetDuration")[1], 1, "half a cycle each way")
    _, am = dressed(text({ anim = "blink", animSpeed = 2, animIntensity = 0.4 }), false, frame)
    -- red under: the loop keyed to the wrong group
    assertEqual(am.blinkGroup:__count("Play"), 1)
    assertEqual(am.blink:__last("SetStartDelay")[1], 1)
    assertEqual(am.blink:__last("SetEndDelay")[1], 1)
    assertTrue(am.pulseGroup:__lastSeq("Stop") > am.pulseGroup:__lastSeq("Play"), "the old loop stopped")
    _, am = dressed(text({ anim = "bounce", animSpeed = 2, animBounce = 5 }), false, frame)
    assertEqual(am.bounceGroup:__count("Play"), 1)
    assertEqual(am.bounce:__joined("SetOffset"), "0,5")
end)

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
    NS.Debug = function(tag, fmt, ...)
        local n = #lines
        lines[n + 1] = tag .. ":" .. fmt:format(...)
    end
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

test("text style: the same refusal on every re-dress reaches the error handler once, and the debug log each time", function()
    local got = refusedRedress("iconBorder", "Show", 3)
    assertTrue(got.ok, tostring(got.err))
    -- red under: geterrorhandler called on every re-dress (a restyle of 40 buttons floods BugSack)
    assertEqual(#got.reported, 1)
    assertEqual(matching(got.lines, "Show refused"), 3)
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

-- ── the template ───────────────────────────────────────────────────────────────────────────────

test("text style: a refused stored template draws the default one and logs it once", function()
    local NS = E()
    local lines = {}
    local debug = NS.Debug
    NS.Debug = function(tag, fmt, ...)
        local n = #lines
        lines[n + 1] = tag .. ":" .. fmt:format(...)
    end
    local _, am = dressed(text({ template = "$broken$" }))
    dressed(text({ template = "$broken$" }))
    NS.Debug = debug
    -- red under: Compiled handing the refusal to the dresser (a raise, or an element with no pieces)
    assertEqual(am.shape, NS.TextTemplate.Compile(NS.CONTAINER_TEMPLATE.text.template).shape)
    assertEqual(#lines, 1, "said once: " .. table.concat(lines, " | "))
end)

test("text style: a template edit that keeps the shape re-dresses the same strings; a new shape swaps chains", function()
    local made = {}
    local frame = B.new(made)
    local _, am = dressed(text({ template = "$spellname$ - $stacks$" }), false, frame, made)
    local chain1, first = am.chain, am.piece1
    dressed(text({ template = "$spellname$ ~ $stacks$" }), false, frame, made)
    -- red under: useChain rebuilding on every template change (a string per dress, never freed)
    assertTrue(am.chain == chain1 and am.piece1 == first, "same shape, same strings")
    assertEqual(am.piece2:__last("SetText")[1], " ~ ")
    dressed(text({ template = "$spellname$" }), false, frame, made)
    -- red under: useChain re-dressing old strings for a new shape (a stale binding writes into one)
    assertTrue(am.chain ~= chain1, "a new shape, a new chain")
    assertFalse(chain1:IsShown(), "the old chain is hidden")
    assertEqual(am.pieceCount, 1)
    assertNil(am.piece2, "the old shape's keys are gone")
    dressed(text({ template = "$spellname$ - $stacks$" }), false, frame, made)
    assertTrue(am.chain == chain1 and chain1:IsShown(), "back to the first shape: its chain again")
end)

test("text style: the structure key carries the template's shape, so a live shape change gets new buttons", function()
    local NS = E()
    local S = NS.Style
    assertEqual(S.StructureKey(cfg({ style = "bars" })), "bars")
    assertEqual(S.StructureKey(text({ template = "$spellname$" })), "text:name")
    -- red under: StructureKey leaving the shape out (Container:Apply would restyle, not rebuild)
    assertEqual(S.StructureKey(text({ template = "$spellname$[ x$stacks$]" })), "text:name|stacks")
    assertEqual(S.StructureKey(text({ template = "$spellname$[ y$stacks$]" })), "text:name|stacks", "same shape")
end)

test("text style: Style.Element dresses a text container through Style.Text, bound and unbound, without raising", function()
    -- A kit frame, as a live button is: the dispatch, not the builder, is what this case pins.
    local NS, m = E()
    local S = NS.Style
    local c = text({ template = "$spellname$[ x$stacks$][ - $remainingduration$]" })
    -- red under: Styler answering nil or Style.Bars for "text"
    assertTrue(S.Styler(c) == S.Text)
    for _, engine in ipairs({ false, true }) do
        local frame = m.__stubFrame()
        S.Element(frame, c, engine)
        assertEqual(frame.__am.style, "text")
        assertEqual(frame.__am.pieceCount, 3)
    end
end)

test("text style: bars, then text, then bars again keeps each style's regions, hidden while the other draws", function()
    -- A kit frame, not a builder: the bar's build does frame-level arithmetic a recorder cannot answer.
    local NS, m = E()
    local frame = m.__stubFrame()
    local c = cfg({ style = "bars" })
    NS.Style.Element(frame, c, false)
    local bars = frame.__am
    bars.bar:Show()
    c.style = "text"
    NS.Style.Element(frame, c, false)
    local am = frame.__am
    assertEqual(am.style, "text")
    assertFalse(bars.bar:IsShown(), "the bar is hidden")
    am.clip:Show()
    c.style = "bars"
    NS.Style.Element(frame, c, false)
    assertTrue(frame.__am == bars)
    -- red under: RegionsFor not hiding the text regions under the bar
    assertFalse(am.clip:IsShown())
end)

-- ── the preview ────────────────────────────────────────────────────────────────────────────────

--- Fill a dressed placeholder with `aura` and answer each piece's text.
local function filled(over, aura)
    local NS = E()
    local c = text(over)
    local frame, am = dressed(c, false)
    NS.Style.Text.FillPreview(frame, aura, c)
    local out = {}
    for i, fs in ipairs(pieces(am)) do out[i] = (fs:__last("SetText") or {})[1] end
    return out, am
end

local AURA = { name = "Bloodlust", icon = 1, remaining = 28, duration = 40, stacks = 3, dispel = "Magic" }

test("text style: a placeholder fills each piece as the engine would", function()
    local NS = E()
    local out = filled({ template = "$spellname$[ x$stacks$][ ($dispeltype$)][ - $remainingduration$ / $maxduration$ ($remainingpercent$)]" }, AURA)
    assertEqual(out[1], "Bloodlust")
    -- red under: the stacks piece filled without its bracket text
    assertEqual(out[2], " x3")
    assertEqual(out[3], " (" .. NS.L["Magic"] .. ")")
    -- tests/text_apis.lua's formatter writes whole seconds as "<n>s"; a percent is a bare number
    -- (feedback #5: the player types the %)
    assertEqual(out[4], " - 28s / 40s (70)")
end)

test("text style: a stacked line previews as its field rows, one per line, without its literals (feedback #1)", function()
    local NS = E()
    local aura = { name = "Ignore Pain", icon = 1, remaining = 11, duration = 12, stacks = 3 }
    -- red under: PreviewLine joining a stacked line as one line, literal included
    assertEqual(NS.Style.Text.PreviewLine({ template = STACKED, justifyH = "CENTER" }, aura), "Ignore Pain\n3\n - 11s")
    assertEqual(NS.Style.Text.PreviewLine({ template = STACKED, justifyH = "LEFT" }, aura), "Ignore Pain :: 3 - 11s")
end)

test("text style: a placeholder's percent is the nearest whole number, as the engine's step rule rounds it (feedback #5)", function()
    local out = filled({ template = "$remainingpercent$" }, { name = "Ignore Pain", icon = 1, remaining = 11, duration = 12, stacks = 0 })
    -- red under: math.floor truncating 91.67 to 91 (the live rule rounds to the nearest)
    assertEqual(out[1], "92")
end)

test("text style: a placeholder hides a single stack, a missing dispel type and a timeless duration with their bracket text", function()
    local aura = { name = "Well Fed", icon = 1, remaining = 0, duration = 0, stacks = 1 }
    local out = filled({ template = "$spellname$[ x$stacks$][ ($dispeltype$)][ - $remainingduration$]" }, aura)
    -- red under: PREVIEW.stacks writing "1" (the engine's rule formatter writes nothing below 2)
    assertEqual(out[2], "")
    assertEqual(out[3], "")
    assertEqual(out[4], "", "a timeless aura writes nothing, bracket text included")
end)

test("text style: a placeholder running out takes the running-out color on its duration piece only", function()
    local red = { r = 1, g = 0, b = 0, a = 1 }
    local _, am = filled({ template = "$spellname$[ - $remainingduration$]", expiringColorOn = true,
        expiringThreshold = 30, expiringColor = red }, AURA)
    -- red under: previewDuration ignoring the threshold
    assertEqual(am.piece2:__joined("SetTextColor"), "1,0,0,1")
    assertEqual(am.piece1:__count("SetTextColor"), 1, "the name keeps the font color the dress set")
end)

-- ── color by dispel type (feedback #7) ────────────────────────────────────────────────────────

-- The default Magic color (C.DEFAULT_DISPEL_COLORS: 0.2, 0.6, 1) as a font-string escape.
local MAGIC_CODE = "|cff3399ff"

test("text style: Color the dispel type writes each word in its palette color inside the bracket text (feedback #7)", function()
    local NS = E()
    local frame = dressed(text({ template = "$spellname$[ <$dispeltype$>]", dispelTypeColor = true }), true)
    local opts = frame:__last("SetDispelTypeText")[2]
    local map = opts.customDispelTextMap
    -- red under: the words left plain (the escape inside the map's text is the one engine path that
    -- colors a font string by dispel type)
    assertEqual(map.Magic, " <" .. MAGIC_CODE .. NS.L["Magic"] .. "|r>")
    -- Enrage has no palette color: its word keeps the font color
    assertEqual(map.Enrage, " <" .. NS.L["Enrage"] .. ">")
    assertNil(map.None)
    assertFalse(opts.showWithoutDispelType)
    local off = dressed(text({ template = "$spellname$[ <$dispeltype$>]" }), true)
    assertEqual(off:__last("SetDispelTypeText")[2].customDispelTextMap.Magic, " <" .. NS.L["Magic"] .. ">", "off: plain")
end)

test("text style: a colored dispel map is built once per look, and a new palette color rebuilds it (feedback #7)", function()
    local NS = E()
    local c = text({ template = "$spellname$[ ($dispeltype$)]", dispelTypeColor = true })
    local first = dressed(c, true):__last("SetDispelTypeText")[2]
    assertTrue(dressed(c, true):__last("SetDispelTypeText")[2] == first, "one options table per look")
    local dc = NS.db.profile.dispelColors
    local old = dc.Curse
    dc.Curse = { r = 1, g = 0, b = 0, a = 1 }   -- a settings write stores a new table (Style.lua's memo note)
    local again = dressed(c, true):__last("SetDispelTypeText")[2]
    dc.Curse = old
    -- red under: the memo keyed by the bracket text alone (a new Curse color never reaches the line)
    assertEqual(again.customDispelTextMap.Curse, " (|cffff0000" .. NS.L["Curse"] .. "|r)")
end)

test("text style: the dispel tint map is built once per look, and a new palette color rebuilds it too (feedback #7, fix round 1)", function()
    local NS = E()
    local c = text({ dispelBackdrop = true })
    local first = dressed(c, true):__last("AddDispelTypeTexture")[2].customDispelColorMap
    assertTrue(dressed(c, true):__last("AddDispelTypeTexture")[2].customDispelColorMap == first, "one map per look")
    local dc = NS.db.profile.dispelColors
    local old = dc.Curse
    dc.Curse = { r = 1, g = 0, b = 0, a = 1 }   -- a settings write stores a new table (Style.lua's memo note)
    local again = dressed(c, true):__last("AddDispelTypeTexture")[2].customDispelColorMap
    dc.Curse = old
    -- red under: the tint memo ignoring a palette write (a memo keyed on something other than the map)
    assertTrue(again ~= first, "a new palette leaf rebuilds the tint map")
    assertEqual(table.concat({ again.Curse.r, again.Curse.g, again.Curse.b, again.Curse.a }, ","), "1,0,0,1")
end)

test("text style: the dispel backdrop fills the text area and is tinted through the engine, for a typed aura only (feedback #7)", function()
    local NS = E()
    local frame, am = dressed(text({ dispelBackdrop = true, dispelBackdropAlpha = 0.4 }), true)
    -- red under: no backdrop region
    assertTrue(am.backdrop ~= nil and am.backdrop.parent == am.area, "in the text area, under the chain")
    assertTrue(am.backdrop:__last("SetAllPoints")[1] == am.area)
    assertEqual(am.backdrop:__joined("SetTexture"), NS.Constants.WHITE_TEXTURE)
    assertEqual(am.backdrop:__joined("SetAlpha"), "0.4")
    local add = frame:__last("AddDispelTypeTexture")
    -- red under: no backdrop binding
    assertTrue(add ~= nil and add[1] == am.backdrop, "the backdrop is the engine's to tint")
    assertEqual(frame:__count("AddDispelTypeTexture"), 1, "no edge while it is off")
    local o = add[2]
    assertTrue(o.showWhenHarmful and o.showWhenHelpful, "buffs and debuffs, as the word")
    assertFalse(o.showAlways)
    assertFalse(o.showWithoutDispelType)
    local map = o.customDispelColorMap
    local m = NS.db.profile.dispelColors.Magic
    assertEqual(table.concat({ map.Magic.r, map.Magic.g, map.Magic.b, map.Magic.a }, ","),
        table.concat({ m.r, m.g, m.b, 1 }, ","), "the profile's palette, at full alpha")
    -- red under: Enrage taking the fallback's opaque white instead of no visible tint at all (fix
    -- round 1, controller ruling: an out-of-palette type shows nothing, like a typeless aura)
    assertEqual(map.Enrage.a, 0, "no palette color for Enrage: fully transparent, not Blizzard's white")
    assertTrue(frame:__lastSeq("ClearDispelTypeTextures") < frame:__lastSeq("AddDispelTypeTexture"), "cleared first")
    am.backdrop:Show()   -- the engine showed it for a typed aura
    local off = dressed(text({}), true, frame)
    assertEqual(off:__count("AddDispelTypeTexture"), 1, "off by default: no second binding")
    -- red under: a dress leaving a switched-off backdrop as the engine last drew it (the Clear
    -- restores nothing)
    assertFalse(am.backdrop:IsShown())
end)

test("text style: the dispel edge is four strips of its thickness around the text area, each tinted through the engine (feedback #7)", function()
    local frame, am = dressed(text({ dispelEdge = true, dispelEdgeSize = 2 }), true)
    local adds = frame:__calls("AddDispelTypeTexture")
    -- red under: no edge
    assertEqual(#adds, 4, "one binding per strip")
    local want = {
        edgeTop = { "TOPLEFT", "TOPRIGHT", "SetHeight" }, edgeBottom = { "BOTTOMLEFT", "BOTTOMRIGHT", "SetHeight" },
        edgeLeft = { "TOPLEFT", "BOTTOMLEFT", "SetWidth" }, edgeRight = { "TOPRIGHT", "BOTTOMRIGHT", "SetWidth" },
    }
    local bound = {}
    for _, a in ipairs(adds) do bound[a[1]] = a[2] end
    for key, w in pairs(want) do
        local strip = am[key]
        assertTrue(strip ~= nil and strip.parent == am.area, key)
        local pts = strip:__calls("SetPoint")
        assertEqual(pts[1][1] .. "," .. pts[2][1], w[1] .. "," .. w[2], key)
        assertTrue(pts[1][2] == am.area and pts[2][2] == am.area, key .. " on the area's edge")
        assertEqual(strip:__joined(w[3]), "2", key)
        assertTrue(bound[strip] ~= nil and bound[strip] == adds[1][2], key .. " bound with the backdrop's options")
    end
end)

test("text style: a placeholder with a dispel type shows the backdrop and edge in its palette color; one without shows neither (feedback #7)", function()
    local NS = E()
    local m = NS.db.profile.dispelColors.Magic
    local magic = table.concat({ m.r, m.g, m.b, 1 }, ",")
    local _, am = filled({ dispelBackdrop = true, dispelEdge = true }, AURA)
    -- red under: FillPreview leaving the tints to an engine a placeholder does not have
    assertTrue(am.backdrop:IsShown())
    assertEqual(am.backdrop:__joined("SetVertexColor"), magic)
    for _, key in ipairs({ "edgeTop", "edgeBottom", "edgeLeft", "edgeRight" }) do
        assertTrue(am[key]:IsShown(), key)
        assertEqual(am[key]:__joined("SetVertexColor"), magic, key)
    end
    local _, typeless = filled({ dispelBackdrop = true, dispelEdge = true },
        { name = "Well Fed", icon = 1, remaining = 0, duration = 0, stacks = 0 })
    assertFalse(typeless.backdrop:IsShown(), "no type, no backdrop")
    assertFalse(typeless.edgeTop:IsShown(), "no type, no edge")
    local _, off = filled({}, AURA)
    assertFalse(off.backdrop:IsShown(), "off: nothing, even for a typed aura")
end)

test("text style: an Enrage aura shows no visible backdrop or edge, live or in the preview (fix round 1, feedback #7)", function()
    E()
    local ENRAGE = { name = "Enrage Effect", icon = 1, remaining = 10, duration = 10, stacks = 0, dispel = "Enrage" }
    -- Live: Enrage has a dispelName, so the engine still shows the texture; only a transparent tint
    -- keeps it invisible.
    local frame = dressed(text({ dispelBackdrop = true, dispelEdge = true }), true)
    local map = frame:__last("AddDispelTypeTexture")[2].customDispelColorMap
    -- red under: Enrage mapped to the fallback's opaque white (a visible white box and edge in game)
    assertEqual(map.Enrage.a, 0, "Enrage: no palette color, so no visible tint")
    -- Preview: previewTints must read the SAME map the engine gets, so the two cannot disagree.
    local _, am = filled({ dispelBackdrop = true, dispelEdge = true }, ENRAGE)
    -- red under: the preview showing a white backdrop/edge for Enrage where the live button would too
    assertFalse(am.backdrop:IsShown(), "Enrage: no palette color, no visible backdrop")
    assertFalse(am.edgeTop:IsShown(), "Enrage: no palette color, no visible edge")
end)

test("text style: a placeholder's and the Preview box's dispel word take its palette color when the option is on (feedback #7)", function()
    local NS = E()
    local s = { template = "$spellname$[ ($dispeltype$)]", dispelTypeColor = true }
    local out = filled(s, AURA)
    -- red under: the preview fill ignoring the option (the live line colored, the placeholder not)
    assertEqual(out[2], " (" .. MAGIC_CODE .. NS.L["Magic"] .. "|r)")
    assertEqual(NS.Style.Text.PreviewLine(s, AURA), "Bloodlust (" .. MAGIC_CODE .. NS.L["Magic"] .. "|r)")
end)
