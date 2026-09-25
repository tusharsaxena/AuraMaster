-- tests/test_style_text_autosize.lua — a Text container's Size to fit (batch 8, AS-1..AS-3):
-- Style.ElementSize answering the size the line's content needs, from the font, the icon, a stacked
-- Center's rows, the bounce and the widest line the placeholders draw, measured on our own hidden
-- string (Style.__measurer), never on an engine-written one. Off, it answers the stored size, as it
-- did before the option existed.
--
-- Its own suite rather than more cases in tests/test_style_text.lua: the measure is a seam of its
-- own, and that file is already near a thousand lines. Every case builds a fresh environment whose measurer is a recorder answering a width of
-- `fontSize / 2` per character plus 2 of padding, so a 12pt string is 6 per character plus 2.

local T = _G.AM_TEST
local test, assertEqual, assertTrue =
    T.test, T.assertEqual, T.assertTrue
local B = dofile("tests/region_builder.lua")
local fresh = dofile("tests/fresh_env.lua")

--- The characters and the font size the measuring string was last given.
local function measured(fs)
    local s = fs:__last("SetText")[1]
    local font = fs:__last("SetFont")
    return s:len(), font and font[2] or 12
end

--- A fresh environment measuring on a recorder; `answer(fs)` replaces the width it answers. Answers
--- NS, the mock, the measuring string, and textCfg(over), a container drawn as text whose text block
--- is the template's merged with `over`.
-- A width the client hands back secret: a sentinel number its issecretvalue names.
local SECRET = 123.25

local function env(answer, before)
    local textApis = dofile("tests/text_apis.lua")
    local NS, m = fresh({ before = function(mocks)
        textApis(mocks)
        mocks.issecretvalue = function(v) return v == SECRET end
        if before then before(mocks) end
    end })
    local fs = dofile("tests/region_recorder.lua")()
    fs.__answer.GetStringWidth = answer or function(self)
        local n, size = measured(self)
        return n * size / 2 + 2
    end
    NS.Style.__measurer = function() return fs end
    local function textCfg(over, auraType)
        return NS.Database.Merge(NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE),
            { style = "text", auraType = auraType or "HELPFUL", text = over or {} })
    end
    return NS, m, fs, textCfg
end

-- "Power Word: Fortitude", the longest buff placeholder: 21 characters, 128 at 12pt.
local LONGEST_BUFF = 21 * 6 + 2

-- ── on and off ─────────────────────────────────────────────────────────────────────────────────

test("autosize: off, the element keeps its stored size, and a stacked Center still grows (AS-3)", function()
    local NS, _, fs, textCfg = env()
    -- red under: ElementSize autosizing whatever the toggle says (a migrated layout moves)
    local w, h = NS.Style.ElementSize(textCfg({ autoSize = false, width = 250, height = 18 }))
    assertEqual(w, 250); assertEqual(h, 18)
    assertEqual(fs:__count("SetText"), 0, "nothing measured while off")
    local _, stacked = NS.Style.ElementSize(textCfg({ autoSize = false, height = 16,
        template = "$spellname$[$remainingduration$]", justifyH = "CENTER" }))
    assertEqual(stacked, 2 * 12 + 2, "the stack growth stands")
end)

test("autosize: the template turns it on; a new container reads the template's true (AS-1, AS-3)", function()
    local NS = env()
    -- red under: no autoSize leaf in CONTAINER_TEMPLATE.text
    assertEqual(NS.CONTAINER_TEMPLATE.text.autoSize, true)
end)

test("autosize: on, the width is the widest placeholder line plus |x| and 2, the height the font plus padding (AS-2)", function()
    local NS, _, _, textCfg = env()
    local w, h = NS.Style.ElementSize(textCfg({ template = "$spellname$", x = 0, width = 300, height = 30 }))
    -- red under: ElementSize ignoring autoSize (the stored 300 x 30)
    assertEqual(w, LONGEST_BUFF + 2)
    assertEqual(h, 12 + 2 * NS.Constants.TEXT_AUTOSIZE_PAD, "12pt reads 16, the old default height")
    w = NS.Style.ElementSize(textCfg({ template = "$spellname$", x = -5 }))
    assertEqual(w, LONGEST_BUFF + 5 + 2, "the offset either way")
    local big, bigH = NS.Style.ElementSize(textCfg({ template = "$spellname$", x = 0, font = { fontSize = 20 } }))
    -- red under: the measure taken in the template's font whatever the line's is
    assertEqual(big, 21 * 10 + 2 + 2, "a bigger font widens it")
    assertEqual(bigH, 20 + 4)
    local long = NS.Style.ElementSize(textCfg({ template = "$spellname$ <<<>>>", x = 0 }))
    assertEqual(long, (21 + 7) * 6 + 2 + 2, "a longer template widens it")
end)

test("autosize: the width is clamped to the Width row's range", function()
    local NS, _, _, textCfg = env()
    local C = NS.Constants
    assertEqual(C.TEXT_WIDTH_MIN, 40); assertEqual(C.TEXT_WIDTH_MAX, 600)
    -- red under: no clamp (a one-word line narrower than any hand-set width, a long one past 600)
    assertEqual(NS.Style.ElementSize(textCfg({ template = "$stacks$", x = 0 })), C.TEXT_WIDTH_MIN)
    assertEqual(NS.Style.ElementSize(textCfg({ template = "$spellname$" .. ("W"):rep(100), x = 0 })), C.TEXT_WIDTH_MAX)
    -- the Width row takes its range from the same constants
    local row = NS.FindSchemaRow("container.text.width")
    assertEqual(row.min, C.TEXT_WIDTH_MIN); assertEqual(row.max, C.TEXT_WIDTH_MAX)
end)

test("autosize: a debuff container measures the debuff placeholders, a buff one the buffs", function()
    local NS, _, _, textCfg = env()
    -- "Shadow Word: Pain", the longest debuff placeholder: 17 characters
    -- red under: the sample set ignoring the aura type (a debuff line sized to a buff's name)
    assertEqual(NS.Style.ElementSize(textCfg({ template = "$spellname$", x = 0 }, "HARMFUL")), 17 * 6 + 2 + 2)
    assertEqual(NS.Style.ElementSize(textCfg({ template = "$spellname$", x = 0 }, "HELPFUL")), LONGEST_BUFF + 2)
end)

test("autosize: a placeholder's name is the client's own when it has one", function()
    local NS, _, _, textCfg = env(nil, function(m)
        m.__spells[21562] = { name = "Power Word: Fortitude of the Ages", iconID = 135987 }
    end)
    -- red under: measuring the fixed English fallbacks while the preview draws the client's names
    assertEqual(NS.Style.ElementSize(textCfg({ template = "$spellname$", x = 0 })), 33 * 6 + 2 + 2)
end)

test("autosize: the worst-case duration is measured, not only the placeholders' short ones", function()
    local NS, _, fs, textCfg = env()
    NS.Style.ElementSize(textCfg({}))
    local seen = false
    for _, args in ipairs(fs:__calls("SetText")) do
        if tostring(args[1]):find("863999", 1, true) then seen = true end
    end
    -- red under: the sample set without Style.TIME_SAMPLES (an hours or days aura is cut short)
    assertTrue(seen, "the longest time sample was measured")
end)

-- ── the icon and the bounce ────────────────────────────────────────────────────────────────────

test("autosize: an icon beside the line sets the height at its size and widens the box by it and its gap", function()
    local NS, _, _, textCfg = env()
    local w, h = NS.Style.ElementSize(textCfg({ template = "$spellname$", x = 0, icon = "LEFT", iconSize = 24, iconGap = 3 }))
    -- red under: the icon left out of either sum (the text cut short, the icon clipped)
    assertEqual(h, 24)
    assertEqual(w, LONGEST_BUFF + 24 + 3 + 2)
    local nw, nh = NS.Style.ElementSize(textCfg({ template = "$spellname$", x = 0, icon = "NONE", iconSize = 24 }))
    assertEqual(nh, 16, "no icon, no height"); assertEqual(nw, LONGEST_BUFF + 2)
end)

test("autosize: bounce headroom follows the vertical justify, and a line-height icon is inset by the FINAL height", function()
    local NS, _, _, textCfg = env()
    local function size(v, over)
        local t = { template = "$spellname$", x = 0, anim = "bounce", animBounce = 3, justifyV = v }
        for k, x in pairs(over or {}) do t[k] = x end
        return NS.Style.ElementSize(textCfg(t))
    end
    -- red under: a flat animBounce of headroom (a centered bounce still clips at its top)
    assertEqual(select(2, size("MIDDLE")), 16 + 2 * 3)
    assertEqual(select(2, size("BOTTOM")), 16 + 3)
    assertEqual(select(2, size("TOP")), 16, "TOP: pinned to the top edge, extra height cannot help")
    local w, h = size("MIDDLE", { icon = "LEFT", iconSize = 0, iconGap = 2 })
    assertEqual(h, 22)
    -- red under: the inset taken from the height before the bounce (the text area comes out 6 short)
    assertEqual(w, LONGEST_BUFF + 22 + 2 + 2)
end)

test("autosize: a stacked Center is its rows tall and as wide as its widest ROW", function()
    local NS, _, _, textCfg = env()
    local w, h = NS.Style.ElementSize(textCfg({ template = "$spellname$[$remainingduration$]",
        justifyH = "CENTER", x = 0 }))
    assertEqual(h, 2 * 12 + 2, "two rows and one row gap")
    -- red under: the newline-joined rows measured as one string (the name and the time added up)
    assertEqual(w, LONGEST_BUFF + 2)
end)

-- ── failure and the memo ───────────────────────────────────────────────────────────────────────

test("autosize: a measure that fails keeps the stored size, is not remembered, and a later one autosizes", function()
    local NS, _, fs, textCfg = env(function() return 0 end)
    local c = textCfg({ template = "$spellname$", x = 0, width = 250, height = 18 })
    -- red under: a string the client has not laid out yet (width 0) autosized to the clamp floor
    local w, h = NS.Style.ElementSize(c)
    assertEqual(w, 250); assertEqual(h, 18, "the stored height too")
    fs.__answer.GetStringWidth = function() return SECRET end
    w, h = NS.Style.ElementSize(c)
    assertEqual(w, 250, "an unreadable width: the stored size"); assertEqual(h, 18)
    fs.__raise.GetStringWidth = true
    -- red under: the measure unguarded (a raise aborts every dress)
    w = NS.Style.ElementSize(c)
    assertEqual(w, 250, "a raise: the stored size")
    fs.__raise.GetStringWidth = nil
    fs.__answer.GetStringWidth = function(self) return measured(self) * 6 + 2 end
    -- red under: a failed measure remembered for good
    w, h = NS.Style.ElementSize(c)
    assertEqual(w, LONGEST_BUFF + 2); assertEqual(h, 16)
end)

test("autosize: the size is remembered per style signature; a changed font size measures again", function()
    local NS, _, fs, textCfg = env()
    local c = textCfg({ template = "$spellname$" })
    NS.Style.ElementSize(c)
    local n = fs:__count("SetText")
    assertTrue(n > 0, "measured once")
    NS.Style.ElementSize(c)
    -- red under: no memo (every dressed button measures every sample)
    assertEqual(fs:__count("SetText"), n, "remembered")
    NS.Style.ElementSize(textCfg({ template = "$spellname$", font = { fontSize = 14 } }))
    assertTrue(fs:__count("SetText") > n, "a new font size is a new signature")
end)

-- ── every consumer reads it ────────────────────────────────────────────────────────────────────

test("autosize: the dressed element, the flow layout and the preview offset all take the autosized size", function()
    local NS, m, _, textCfg = env()
    local c = textCfg({ template = "$spellname$", x = 0, width = 300, height = 30 })
    local made = {}
    local frame = B.new(made)
    B.during(m, made, function() NS.Style.Element(frame, c, false) end)
    -- red under: Text.Apply sizing the frame from the stored width
    assertEqual(frame:__joined("SetSize"), ("%d,%d"):format(LONGEST_BUFF + 2, 16))
    c.layout.perLine = 2
    c.layout.axis = "horizontal"
    c.layout.spacing = 4
    local flow = NS.Container.FlowSettings(c)
    assertEqual(flow.maxLineSize, 2 * (LONGEST_BUFF + 2) + 4, "the engine's line length")
    local _, x = NS.Preview.Offset(c, 2)
    assertEqual(math.abs(x), LONGEST_BUFF + 2 + 4, "the second placeholder one autosized pitch along")
end)
