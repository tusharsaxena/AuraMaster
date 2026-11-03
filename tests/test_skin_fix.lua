-- tests/test_skin_fix.lua — FS-AM-FIX: this addon's half of causes A3, L2, L5 and L8
-- (Ka0sAddonsCommonTasks docs/2026-11-01-FULL_SKINNING): the gloss, a tooltip line a settings page
-- writes, the typed colors on the General page and the frame picker's label. Each reads what is drawn.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local R = dofile("tests/region_recorder.lua")

--- A registered skin other than Ka0s Default, whose `sem.info` is not Ka0s Default's.
local function colorSkin(mocks)
    local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
    local base = Skin:ResolveSkin("ka0s")["sem.info"]
    for _, def in ipairs(Skin:Skins()) do
        local c = Skin:ResolveSkin(def.key)["sem.info"]
        if def.key ~= "ka0s" and (c[1] ~= base[1] or c[2] ~= base[2]) then return def.key end
    end
end

--- `body(sheen, gloss)` on a bar element dressed on the kit's paint recorder: the base mock's bars are
--- no StatusBar, so S.BarGloss would return with nothing drawn and every case here would pass empty.
local function withGloss(NS, mocks, c, body)
    local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
    local restore = dofile("tests/_kit/mock_paint.lua")(mocks)
    local saved = rawget(_G, "CreateFrame")
    rawset(_G, "CreateFrame", mocks.CreateFrame)
    local ok, err = pcall(function()
        local frame = mocks.CreateFrame("Frame")
        local function dress() NS.Style.Element(frame, c, false) end
        dress()
        local sheen = frame.__am.sheen
        body(sheen, function()
            local rec = Skin.painted[sheen]
            return rec and rec.regions.gloss
        end, dress)
        Skin:Untrack(sheen)
    end)
    rawset(_G, "CreateFrame", saved)
    restore()
    if not ok then error(err, 0) end
end

test("gloss: Glass shines the bar that lies over the drawn fill; Ka0s Default and a player's texture do not", function()
    local NS, mocks = fresh()
    local c = NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE)
    withGloss(NS, mocks, c, function(_, gloss, dress)
        assertNil(gloss(), "Ka0s Default has none")
        NS.ApplySkinChoice("ka0s", "glass")
        dress()
        assertTrue(gloss() ~= nil, "Glass has it")
        assertEqual(gloss():IsShown(), true, "the layer shows")
        c.bars.barTextureFromSkin = false
        dress()
        assertEqual(gloss():IsShown(), false, "the player's own texture stays plain")
        -- red under: a call that omits the companion, which a replay would shine again
        NS.ApplySkinChoice("ka0s", "obsidian")
        NS.ApplySkinChoice("ka0s", "glass")
        assertEqual(gloss():IsShown(), false, "and through a skin switch's replay")
        c.bars.barTextureFromSkin = true
        dress()
        assertEqual(gloss():IsShown(), true, "the companion back on")
        NS.ApplySkinChoice("ka0s", "ka0s")
        assertEqual(gloss():IsShown(), false, "a switch away takes it off")
    end)
end)

test("gloss: the sheen is a clear, full bar anchored to the visible fill, never the engine's elapsed bar", function()
    local NS = fresh()
    local c = NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE)
    local given = {}
    local keep = NS.Skin.BarGloss
    NS.Skin.BarGloss = function(bar, fromSkin) given[#given + 1] = { bar, fromSkin } end
    local frame = R()
    local ok, err = pcall(NS.Style.Element, frame, c, false)
    NS.Skin.BarGloss = keep
    assertTrue(ok, tostring(err))
    local am = frame.__am
    -- red under: am.bar, whose fill Texture is the invisible elapsed part
    assertTrue(given[1][1] == am.sheen, "the sheen, not the engine's bar")
    assertTrue(am.sheen ~= am.bar)
    assertEqual(given[1][2], true, "the texture companion goes with it")
end)

test("tooltip line: a spell list's overlap line takes gtip.line, and the client's color on an ignored panel", function()
    local NS, mocks = fresh()
    local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
    NS.ApplySkinIgnore(false, nil)
    NS.ApplySkinChoice("ka0s", colorSkin(mocks))
    local want = Skin:Token("AuraMaster", "gtip.line")
    local r, g, b = NS.PanelTipLine()
    assertEqual(("%.3f,%.3f,%.3f"):format(r, g, b), ("%.3f,%.3f,%.3f"):format(want[1], want[2], want[3]))
    NS.ApplySkinIgnore(true, nil)
    assertNil(NS.PanelTipLine(), "stock while the panel is")
end)

--- The drawn text of `value` in the row at `path`, off the stored list.
local function choice(NS, path, value)
    for _, e in ipairs(NS.FindSchemaRow(path).values) do
        if e.value == value then return e.text end
    end
end

test("typed colors: Unit, Aura type and Style values keep today's bytes on Ka0s Default and on an ignored panel", function()
    local NS, mocks = fresh()
    local C = NS.Constants
    assertTrue(choice(NS, "container.unit", "focus"):find("^|c" .. C.UNIT_COLORS.focus) ~= nil)
    NS.ApplySkinChoice("ka0s", colorSkin(mocks))
    NS.ApplySkinIgnore(true, nil)
    -- red under: the list left at the skin's escape behind a stock panel
    assertTrue(choice(NS, "container.style", "bars"):find("^|c" .. C.STYLE_COLORS.bars) ~= nil)
end)

test("typed colors: with the Scope cleared a skin switch rewrites each value's escape, the label kept", function()
    local NS, mocks = fresh()
    local before = choice(NS, "container.unit", "player")
    NS.ApplySkinIgnore(false, nil)
    local moved = false
    for _, def in ipairs(mocks.LibStub("LibKa0s-Skin-1.0"):Skins()) do
        NS.ApplySkinChoice("ka0s", def.key)
        local after = choice(NS, "container.unit", "player")
        moved = moved or after ~= before
        assertEqual(after, NS.SkinEscape("am.unitPlayer") .. NS.L["Player"] .. "|r", def.key)
        assertEqual(choice(NS, "container.auraType", "HARMFUL"), NS.SkinEscape("am.auraHarmful") .. NS.L["Debuffs"] .. "|r", def.key)
    end
    assertTrue(moved, "a list built at file load still follows")
end)

test("frame picker: the label goes through the skin's Font, so a face and Ignore fonts reach it", function()
    local NS = fresh()
    local seen = 0
    local keep = NS.Skin.Font
    NS.Skin.Font = function(fs, ...) seen = seen + 1; return keep(fs, ...) end
    NS.FramePicker.Start(function() end, function() end)
    NS.FramePicker.Stop()
    NS.Skin.Font = keep
    -- red under: the label left on GameFontNormalLarge's face
    assertEqual(seen, 1)
end)

test("skin gate: every allow row names a cause of the run's SKIN_CAUSES.md, or MC", function()
    -- red under: an id such as FS-AM-01, which the kit's shape check takes and no document defines.
    local f = assert(io.open("tests/skin_gate.lua", "rb"))
    local src = f:read("*a")
    f:close()
    local count = 0
    for cause in src:gmatch('cause = "([^"]+)"') do
        count = count + 1
        assertTrue(cause == "MC" or cause:find("^[LDA]%d+$") ~= nil, cause .. " is no cause id")
    end
    assertTrue(count > 0, "the rows were read")
end)
