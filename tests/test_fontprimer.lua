-- tests/test_fontprimer.lua - modules/FontPrimer.lua (issue #24): every font the containers draw in is
-- drawn once on a shown frame before any container text is, because WoW loads an addon's font file
-- lazily and text first drawn before the load stays empty until it is written again
-- (docs/superpowers/research/2026-09-27-blank-bar-names-findings.md, "Correction"). The mock cannot
-- show a font loading; these cases pin what is primed, how, when, and the one follow-up refresh.
-- The effect itself is the owner's smoke check.
--
-- The harness loads no LibSharedMedia, so every font would resolve to the built-in fallback and be
-- skipped. Each environment here gets a stand-in that knows three fonts: two addon fonts and the
-- client's Friz Quadrata, which the starter containers use and the primer must skip.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local R = dofile("tests/region_recorder.lua")

local PROTO = "Interface\\AddOns\\SharedMedia_MyMedia\\font\\Ka0s Prototype.ttf"
local KAIT = "Interface\\AddOns\\SharedMedia_MyMedia\\font\\Ka0s Kait.ttf"
local FRIZ = "Fonts\\FRIZQT__.TTF"

-- The delays, spelled out rather than read back off the module (a suite that asked the code under
-- test for the expected answer would pass on any value at all). HOLD and REFRESH are a priming
-- during play; WORLD_HOLD and WORLD_REFRESH count from PLAYER_ENTERING_WORLD (FP-06).
local HOLD, REFRESH = 1.0, 0.5
local WORLD_HOLD, WORLD_REFRESH = 2.0, 1.5

--- A fresh environment, settled, with the media stand-in. The starter containers are 1 (player
--- bars), 2 (player icons), 3 (target icons) and 4 (player text), every font Friz Quadrata. The
--- harness's fresh environment stops at PLAYER_LOGIN, so this one then enters the world through the
--- addon's own handler, as the client does; with `atLogin` it stays under the loading screen, before
--- the first PLAYER_ENTERING_WORLD.
local function env(atLogin)
    local NS2, mocks = fresh({ before = function(m)
        local media = { ["Ka0s Prototype"] = PROTO, ["Ka0s Kait"] = KAIT, ["Friz Quadrata TT"] = FRIZ,
            ["Arial Narrow"] = "Fonts\\ARIALN.TTF" }
        local lsm = setmetatable({ MediaType = { FONT = "font", STATUSBAR = "statusbar", BORDER = "border",
            BACKGROUND = "background", SOUND = "sound" } },
            { __index = function() return function() return {} end end })
        function lsm.Register() return true end
        function lsm.Fetch(_, kind, key)
            if kind == "font" then return media[key] end
            return nil
        end
        m.__libs["LibSharedMedia-3.0"] = lsm
    end })
    mocks.__fireTimers(); mocks.__fireTimers()
    if not atLogin then
        mocks.__fireEvent("PLAYER_ENTERING_WORLD")
        mocks.__fireTimers()
    end
    return NS2, mocks, NS2.FontPrimer, NS2.ContainerManager
end

--- Container `id`'s stored table.
local function cfgOf(NS2, id) return NS2.Database.FindContainer(id) end

--- The primer's frame, built as a recorder: every call on it and on each font string it creates is
--- logged. Installed around CreateFrame until the primer has built its frame, which starts HIDDEN, as
--- a real frame parented to nothing shown would not answer IsShown for the primer. With `refuse`, each
--- font string answers SetFont with false (a font the client did not accept). Answers the list of
--- font strings, filled as they are created, and the frame once built.
local function recordFrame(mocks, refuse)
    local strings, got = {}, {}
    local real = mocks.CreateFrame
    mocks.CreateFrame = function(kind, name, parent, template)
        if parent ~= mocks.UIParent then return real(kind, name, parent, template) end
        mocks.CreateFrame = real
        local f = R()
        f.__shown = false
        f.__answer.CreateFontString = function(self)
            local fs = R()
            fs.parent = self
            if refuse then fs.__answer.SetFont = function() return false end end
            strings[#strings + 1] = fs
            return fs
        end
        got.frame, got.kind, got.parent = f, kind, parent
        return f
    end
    return strings, got
end

--- The live timers armed with `delay`.
local function armed(mocks, delay)
    local n = 0
    for _, t in ipairs(mocks.__timers()) do
        if t.delay == delay then n = n + 1 end
    end
    return n
end

--- Run the live C_Timer handles armed with `delay`, and only those; each is canceled first, so it
--- leaves the live set as a timer that has fired does.
local function fire(mocks, delay)
    for _, t in ipairs(mocks.__timers()) do
        if t.delay == delay and t.Cancel then
            t.Cancel()
            t.fn()
        end
    end
end

--- The primed triples as "path|size|flags", in priming order.
local function primed(FP)
    local out = {}
    for i, e in ipairs(FP.DiagState().primed) do
        out[i] = ("%s|%s|%s"):format(e.path, tostring(e.size), e.flags)
    end
    return table.concat(out, ",")
end

-- -- what is primed -------------------------------------------------------------------------------

test("fontprimer: the starter profile draws only in the client's own font, so nothing is primed", function()
    local _, mocks, FP = env()
    FP.PrimeAll()
    -- red under: the Fonts\ skip dropped (Friz Quadrata primed on every login)
    assertEqual(primed(FP), "")
    assertEqual(armed(mocks, HOLD) + armed(mocks, REFRESH), 0, "no timer for nothing primed")
end)

test("fontprimer: the triples come from every text block of every container, deduplicated", function()
    local NS2, _, FP = env()
    local c1, c2, c3, c4 = cfgOf(NS2, 1), cfgOf(NS2, 2), cfgOf(NS2, 3), cfgOf(NS2, 4)
    c1.bars.name.font, c1.bars.name.fontSize = "Ka0s Prototype", 10
    c1.bars.time.font, c1.bars.time.fontSize = "Ka0s Prototype", 11
    c1.bars.stacks.font, c1.bars.stacks.fontSize = "Ka0s Prototype", 10      -- the name's triple
    c2.icons.time.font, c2.icons.time.fontSize = "Ka0s Kait", 14
    c2.icons.stacks.font, c2.icons.stacks.fontSize = "Ka0s Kait", 15
    c3.enabled = false                                                         -- primed all the same
    c3.label.font.font, c3.label.font.fontSize = "Ka0s Kait", 16
    c4.text.font.font, c4.text.font.fontSize = "Ka0s Kait", 17
    c4.text.font.fontFlags = "THICKOUTLINE"
    FP.PrimeAll()
    -- red under: any block left out of the walk, a disabled container skipped, or no dedup
    assertEqual(primed(FP), table.concat({
        PROTO .. "|10|OUTLINE", PROTO .. "|11|OUTLINE", KAIT .. "|14|OUTLINE", KAIT .. "|15|OUTLINE",
        KAIT .. "|16|OUTLINE", KAIT .. "|17|THICKOUTLINE" }, ","))
end)

test("fontprimer: a font under Fonts\\ is built into the client and skipped", function()
    local NS2, mocks, FP = env()
    cfgOf(NS2, 1).bars.name.fontSize = 30      -- a new size, still Friz Quadrata
    cfgOf(NS2, 2).icons.time.font = "Arial Narrow"   -- another client font, not the fallback
    FP.PrimeAll()
    -- red under: the skip matching only the fallback path rather than any Fonts\ path
    assertEqual(primed(FP), "")
    assertEqual(armed(mocks, HOLD), 0)
end)

test("fontprimer: the primed triple is the one Style.ApplyFont sets, flags and fallback included", function()
    local NS2, _, FP = env()
    local t = cfgOf(NS2, 1).bars.name
    t.font, t.fontSize, t.fontFlags = "Ka0s Prototype", 12, "MONOCHROMEOUTLINE"
    local fs = R()
    NS2.Style.ApplyFont(fs, t, NS2.CONTAINER_TEMPLATE.bars.name)
    local set = fs:__last("SetFont")
    FP.PrimeAll()
    -- red under: a flag map of the primer's own (the setting's name, not the client's flag string)
    assertEqual(primed(FP), ("%s|%s|%s"):format(set[1], tostring(set[2]), set[3]))
    assertEqual(set[3], "MONOCHROME,OUTLINE")

    -- A size left unset falls back to the template's, as ApplyFont's does.
    local s = cfgOf(NS2, 1).bars.stacks
    s.font, s.fontSize = "Ka0s Kait", nil
    FP.PrimeAll()
    assertEqual(FP.DiagState().primed[2].size, NS2.CONTAINER_TEMPLATE.bars.stacks.fontSize)

    -- A font the media library no longer lists draws in the fallback, which is built in.
    local n = #FP.DiagState().primed
    cfgOf(NS2, 2).icons.time.font = "Uninstalled Pack Font"
    FP.PrimeAll()
    -- red under: Style.Fetch bypassed (the unlisted name primed as if it were a path)
    assertEqual(#FP.DiagState().primed, n)
end)

test("fontprimer: a font the client refuses is not counted, listed, traced or refreshed for", function()
    local NS2, mocks, FP = env()
    local strings = recordFrame(mocks, true)
    local lines = {}
    local debug = NS2.Debug
    NS2.Debug = function(tag)
        local n = #lines
        if tag == "Fonts" then lines[n + 1] = tag end
    end
    local t = cfgOf(NS2, 1).bars.name
    t.font, t.fontSize = "Ka0s Prototype", 10
    local n = FP.PrimeAll()
    NS2.Debug = debug
    assertEqual(#strings, 1, "the font was tried")
    -- red under: SetFont's answer ignored (a refused font reported as primed and refreshed for)
    assertEqual(n, 0)
    assertEqual(primed(FP), "")
    assertEqual(armed(mocks, HOLD) + armed(mocks, REFRESH), 0)
    assertEqual(#lines, 0)
end)

-- -- how it primes -----------------------------------------------------------------------------------

test("fontprimer: one shown 1x1 frame on UIParent draws each new triple, and hides after HOLD", function()
    local NS2, mocks, FP = env()
    local strings, got = recordFrame(mocks)
    local t = cfgOf(NS2, 1).bars.name
    t.font, t.fontSize = "Ka0s Prototype", 10
    FP.PrimeAll()
    local f = got.frame
    assertTrue(f ~= nil, "no frame was built")
    assertEqual(got.parent, mocks.UIParent)
    assertEqual(table.concat(f:__last("SetSize"), ","), "1,1")
    local at = f:__last("SetPoint")
    -- red under: the frame placed on screen (the sample drawn where the player can see it)
    assertEqual(("%s|%s|%s|%s"):format(at[1], tostring(at[2] == mocks.UIParent), at[3], tostring(at[4])),
        "BOTTOMLEFT|true|TOPLEFT|0")
    assertTrue(at[5] > 0, "above the top edge")
    -- red under: priming on a hidden frame (the client does not load a font for it)
    assertTrue(f:IsShown(), "the frame is shown while priming")
    assertEqual(#strings, 1)
    assertEqual(table.concat(strings[1]:__last("SetFont"), "|"), PROTO .. "|10|OUTLINE")
    local sample = strings[1]:__last("SetText")[1]
    assertEqual(sample, FP.SAMPLE)
    for _, probe in ipairs({ "A", "Z", "a", "z", "0", "9", ".", ",", ":", "-", "%(", "%)", "%%", "!", "?" }) do
        assertTrue(sample:find(probe) ~= nil, "the sample lacks " .. probe)
    end
    assertEqual(armed(mocks, HOLD), 1)

    fire(mocks, HOLD)
    -- red under: the hold never hiding the frame (a shown frame kept for the whole session)
    assertFalse(f:IsShown(), "the frame is hidden after HOLD")
end)

test("fontprimer: a second PrimeAll primes nothing new, shows nothing and arms no timer", function()
    local NS2, mocks, FP = env()
    local strings, got = recordFrame(mocks)
    local t = cfgOf(NS2, 1).bars.name
    t.font, t.fontSize = "Ka0s Prototype", 10
    FP.PrimeAll()
    fire(mocks, HOLD); fire(mocks, REFRESH)
    assertEqual(armed(mocks, HOLD) + armed(mocks, REFRESH), 0, "settled")
    FP.PrimeAll()
    -- red under: the primed set not kept (every CONFIG_CHANGED would re-show the frame and refresh)
    assertEqual(#strings, 1)
    assertFalse(got.frame:IsShown())
    assertEqual(armed(mocks, HOLD) + armed(mocks, REFRESH), 0)
    assertEqual(#FP.DiagState().primed, 1)
end)

test("fontprimer: a font change primes only the new triple and arms one refresh", function()
    local NS2, mocks, FP = env()
    local strings, got = recordFrame(mocks)
    local t = cfgOf(NS2, 1).bars.name
    t.font, t.fontSize = "Ka0s Prototype", 10
    FP.PrimeAll()
    fire(mocks, HOLD); fire(mocks, REFRESH)
    assertFalse(got.frame:IsShown(), "hidden after the first hold")
    -- Through the write seam, as the settings panel writes it: CONFIG_CHANGED primes.
    NS2.SetByPath("container.bars.name.font", "Ka0s Kait", 1)
    -- red under: a later triple primed without showing the frame again (a hidden frame loads nothing)
    assertTrue(got.frame:IsShown(), "shown again for the new triple")
    assertEqual(#strings, 2)
    assertEqual(table.concat(strings[2]:__last("SetFont"), "|"), KAIT .. "|10|OUTLINE")
    assertEqual(armed(mocks, REFRESH), 1)
    -- Re-arming restarts the one refresh: a second new triple leaves one armed, not two.
    NS2.SetByPath("container.bars.name.fontSize", 11, 1)
    -- red under: a second NewTimer without canceling the first
    assertEqual(armed(mocks, REFRESH), 1)
    assertEqual(armed(mocks, HOLD), 1)
    assertTrue(FP.DiagState().refresh, "the diagnostics state reads the refresh as armed")
end)

-- -- the follow-up refresh ------------------------------------------------------------------------

--- A stand-in instance whose Refresh is counted.
local function fakeInst(over)
    local inst = { engine = {}, refreshed = 0 }
    function inst.ShouldShow() return true, false end
    function inst.Refresh(self) self.refreshed = self.refreshed + 1 end
    for k, v in pairs(over) do inst[k] = v end
    return inst
end

test("fontprimer: the refresh reaches only live, shown, non-previewing instances", function()
    local NS2, mocks, FP, CM = env()
    local live = CM.instances[1]
    local before = live.engine.__counts.UpdateAllAuras or 0
    local fakes = {
        noEngine = fakeInst({ engine = false }),
        parked = fakeInst({ parked = true }),
        stale = fakeInst({ staleData = true }),
        hidden = fakeInst({ ShouldShow = function() return false, false end }),
        previewing = fakeInst({ ShouldShow = function() return true, true end }),
        eligible = fakeInst({}),
    }
    local ids = {}
    for name, inst in pairs(fakes) do
        local id = 900 + #ids + 1
        ids[#ids + 1] = id
        CM.instances[id] = inst
        inst.name = name
    end
    local t = cfgOf(NS2, 1).bars.name
    t.font, t.fontSize = "Ka0s Prototype", 10
    FP.PrimeAll()
    assertEqual((live.engine.__counts.UpdateAllAuras or 0), before, "nothing before REFRESH")
    fire(mocks, REFRESH)
    -- red under: any one gate dropped (a previewing or hidden engine would clear its auras)
    for name, inst in pairs(fakes) do
        assertEqual(inst.refreshed, name == "eligible" and 1 or 0, name)
    end
    assertEqual(live.engine.__counts.UpdateAllAuras or 0, before + 1, "the real bars container")
    assertFalse(FP.DiagState().refresh, "one-shot: idle once it has run")
    for _, id in ipairs(ids) do CM.instances[id] = nil end
end)

test("fontprimer: the refresh re-applies, so a name label drawn in the font is written again", function()
    local NS2, mocks, FP, CM = env()
    local c = cfgOf(NS2, 1)
    c.label.show = true
    c.label.font.font, c.label.font.fontSize = "Ka0s Prototype", 12
    FP.PrimeAll()
    CM.RequestApply(1)
    fire(mocks, 0)                          -- the apply, in the just-primed font
    local inst = CM.instances[1]
    assertTrue(inst.labelText ~= nil, "the label was built")
    local writes, text = 0, nil
    local set = inst.labelText.SetText
    inst.labelText.SetText = function(self, v)
        writes, text = writes + 1, v
        return set(self, v)
    end
    fire(mocks, REFRESH)
    fire(mocks, 0)
    -- red under: a refresh that reaches only the engine (UpdateAllAuras never rewrites the label)
    assertEqual(writes, 1)
    assertEqual(text, c.name)
end)

test("fontprimer: in test mode the refresh re-applies the previewing container, never its engine", function()
    local NS2, mocks, _, CM = env()
    NS2.Preview.SetTestMode(true)
    mocks.__fireTimers()
    local inst = CM.instances[1]
    local updates = inst.engine.__counts.UpdateAllAuras or 0
    local applies = 0
    local apply = inst.Apply
    inst.Apply = function(self)
        applies = applies + 1
        return apply(self)
    end
    NS2.SetByPath("container.bars.name.font", "Ka0s Prototype", 1)
    fire(mocks, 0)                          -- the write's own apply
    assertEqual(applies, 1)
    fire(mocks, REFRESH)
    fire(mocks, 0)
    inst.Apply = nil
    -- red under: previewing containers left out of the refresh (the placeholders stay as first drawn)
    assertEqual(applies, 2)
    assertEqual(inst.engine.__counts.UpdateAllAuras or 0, updates, "a previewing engine is not refreshed")
end)

test("fontprimer: a refresh timer that fires on a stood-down addon does nothing", function()
    local NS2, mocks, FP, CM = env()
    -- The stand-down runs the visibility pass over every instance, this one included.
    local eligible = fakeInst({ ApplyVisibility = function() return false, false, false end })
    CM.instances[901] = eligible
    local t = cfgOf(NS2, 1).bars.name
    t.font, t.fontSize = "Ka0s Prototype", 10
    FP.PrimeAll()
    local handle
    for _, h in ipairs(mocks.__timers()) do
        if h.delay == REFRESH then handle = h end
    end
    assertTrue(handle ~= nil, "a refresh was armed")
    NS2.SetByPath("enabled", false)
    handle.fn()
    CM.instances[901] = nil
    -- red under: the refresh without its stood-down gate
    assertEqual(eligible.refreshed, 0)
    assertEqual(#mocks.__timers(), 0, "nothing re-armed")
end)

-- -- stand-down --------------------------------------------------------------------------------------

test("fontprimer: Stop cancels both timers and hides the frame, and the primed set survives", function()
    local NS2, mocks, FP = env()
    local _, got = recordFrame(mocks)
    local t = cfgOf(NS2, 1).bars.name
    t.font, t.fontSize = "Ka0s Prototype", 10
    FP.PrimeAll()
    assertEqual(armed(mocks, HOLD) + armed(mocks, REFRESH), 2)
    FP.Stop()
    -- red under: Stop leaving either handle armed to wake up on a stood-down addon
    assertEqual(armed(mocks, HOLD) + armed(mocks, REFRESH), 0)
    assertFalse(got.frame:IsShown())
    assertFalse(FP.DiagState().refresh)
    assertEqual(#FP.DiagState().primed, 1)
end)

test("fontprimer: disabling the addon stops the primer, and nothing primes while stood down", function()
    local NS2, mocks, FP, CM = env()
    local t = cfgOf(NS2, 1).bars.name
    t.font, t.fontSize = "Ka0s Prototype", 10
    FP.PrimeAll()
    local frame = FP.__frame()
    assertTrue(frame:IsShown())
    NS2.SetByPath("enabled", false)
    -- red under: CM.StopListening without FontPrimer.Stop (the kit frame left on screen, two timers live)
    assertFalse(frame:IsShown(), "the primer frame is hidden")
    for _, f in ipairs(mocks.__shownFrames()) do assertTrue(f ~= frame, "the primer frame is on screen") end
    assertEqual(#mocks.__timers(), 0, "a live timer survived the stand-down")

    t.fontSize = 20
    FP.PrimeAll()
    -- red under: PrimeAll without its stood-down gate
    assertEqual(#FP.DiagState().primed, 1)
    assertFalse(frame:IsShown())
    assertEqual(#mocks.__timers(), 0)

    -- The stand-up primes (CM.StartListening) before it builds (CM.Sync).
    local sync, seen = CM.Sync, nil
    CM.Sync = function(...)
        seen = seen or #FP.DiagState().primed
        return sync(...)
    end
    NS2.SetByPath("enabled", true)
    CM.Sync = sync
    -- red under: no PrimeAll in CM.StartListening
    assertEqual(seen, 2)
end)

-- -- the loading screen (FP-06) -------------------------------------------------------------------
-- Nothing is drawn under the loading screen, so a font primed at PLAYER_LOGIN is not loaded by the
-- priming: the frame stays shown through the loading screen and the hide and the refresh count from
-- PLAYER_ENTERING_WORLD instead (docs/superpowers/plans/2026-09-27-font-primer-addendum-loading-screen.md).

test("fontprimer: a login priming waits for the world, then refreshes at WORLD_REFRESH and hides at WORLD_HOLD", function()
    local NS2, mocks, FP, CM = env(true)
    local _, got = recordFrame(mocks)
    -- PLAYER_ENTERING_WORLD runs the visibility pass over every instance, this one included.
    local eligible = fakeInst({ ApplyVisibility = function() return false, false, false end })
    CM.instances[901] = eligible
    local live = CM.instances[1]
    local before = live.engine.__counts.UpdateAllAuras or 0
    local t = cfgOf(NS2, 1).bars.name
    t.font, t.fontSize = "Ka0s Prototype", 10
    FP.PrimeAll()                           -- as CM.Init's, under the loading screen
    assertTrue(got.frame:IsShown(), "shown through the loading screen")
    -- red under: the login priming arming its short hide and refresh (both run under the loading screen)
    assertEqual(armed(mocks, HOLD) + armed(mocks, REFRESH), 0)
    assertEqual(#mocks.__timers(), 0, "nothing armed before the world")

    mocks.__fireEvent("PLAYER_ENTERING_WORLD")
    -- red under: no FontPrimer.OnEnterWorld in addon:OnEnterWorld
    assertEqual(armed(mocks, WORLD_HOLD), 1)
    assertEqual(armed(mocks, WORLD_REFRESH), 1)
    assertEqual(armed(mocks, HOLD) + armed(mocks, REFRESH), 0)
    assertTrue(got.frame:IsShown())
    fire(mocks, WORLD_REFRESH)
    assertEqual(eligible.refreshed, 1)
    assertEqual(live.engine.__counts.UpdateAllAuras or 0, before + 1, "the real bars container")
    assertTrue(got.frame:IsShown(), "still shown after the refresh")
    fire(mocks, WORLD_HOLD)
    assertFalse(got.frame:IsShown(), "hidden at WORLD_HOLD")
    CM.instances[901] = nil
end)

test("fontprimer: a later loading screen with nothing newly primed arms nothing", function()
    local NS2, mocks, FP = env(true)
    local _, got = recordFrame(mocks)
    local t = cfgOf(NS2, 1).bars.name
    t.font, t.fontSize = "Ka0s Prototype", 10
    FP.PrimeAll()
    mocks.__fireEvent("PLAYER_ENTERING_WORLD")
    fire(mocks, WORLD_REFRESH); fire(mocks, WORLD_HOLD)
    mocks.__fireTimers()
    mocks.__fireEvent("PLAYER_ENTERING_WORLD")
    -- red under: the mark never cleared (every zone change re-shows the frame and refreshes)
    assertEqual(armed(mocks, WORLD_HOLD) + armed(mocks, WORLD_REFRESH), 0)
    assertFalse(got.frame:IsShown())
end)

test("fontprimer: a font change during play keeps the short path, never the world timers", function()
    local NS2, mocks = env()
    NS2.SetByPath("container.bars.name.font", "Ka0s Prototype", 1)
    -- red under: every priming waiting for a PLAYER_ENTERING_WORLD that is not coming
    assertEqual(armed(mocks, HOLD), 1)
    assertEqual(armed(mocks, REFRESH), 1)
    assertEqual(armed(mocks, WORLD_HOLD) + armed(mocks, WORLD_REFRESH), 0)
end)

test("fontprimer: Stop cancels the world timers, and ends the wait for the world", function()
    local NS2, mocks, FP = env(true)
    local _, got = recordFrame(mocks)
    local t = cfgOf(NS2, 1).bars.name
    t.font, t.fontSize = "Ka0s Prototype", 10
    FP.PrimeAll()
    mocks.__fireEvent("PLAYER_ENTERING_WORLD")
    assertEqual(armed(mocks, WORLD_HOLD) + armed(mocks, WORLD_REFRESH), 2)
    FP.Stop()
    -- red under: Stop canceling only the short timers
    assertEqual(armed(mocks, WORLD_HOLD) + armed(mocks, WORLD_REFRESH), 0)
    assertFalse(got.frame:IsShown())
end)

test("fontprimer: a login stood down takes the short path on a stand-up in play", function()
    -- A stood-down addon hears no PLAYER_ENTERING_WORLD, so the primer cannot wait for one.
    local NS2, mocks = env(true)
    NS2.SetByPath("enabled", false)
    cfgOf(NS2, 1).bars.name.font = "Ka0s Prototype"
    NS2.SetByPath("enabled", true)
    -- red under: the stand-up's priming waiting for the world (the frame shown and no refresh, for good)
    assertEqual(armed(mocks, HOLD), 1)
    assertEqual(armed(mocks, REFRESH), 1)
end)

test("fontprimer: DiagState names which refresh is armed, or that it waits for the world", function()
    local NS2, mocks, FP = env(true)
    assertEqual(FP.DiagState().state, "idle")
    local t = cfgOf(NS2, 1).bars.name
    t.font, t.fontSize = "Ka0s Prototype", 10
    FP.PrimeAll()
    -- red under: DiagState without a state (the report cannot tell a waiting priming from an idle one)
    assertEqual(FP.DiagState().state, "awaiting-world")
    assertFalse(FP.DiagState().refresh)
    mocks.__fireEvent("PLAYER_ENTERING_WORLD")
    assertEqual(FP.DiagState().state, "armed-world")
    assertTrue(FP.DiagState().refresh)
    fire(mocks, WORLD_REFRESH)
    assertEqual(FP.DiagState().state, "idle")
    NS2.SetByPath("container.bars.name.fontSize", 11, 1)
    assertEqual(FP.DiagState().state, "armed")
end)

-- -- wiring ------------------------------------------------------------------------------------------

test("fontprimer: a settings write primes before its apply is requested", function()
    local NS2, _, FP, CM = env()
    local request, seen = CM.RequestApply, nil
    CM.RequestApply = function(...)
        seen = seen or #FP.DiagState().primed
        return request(...)
    end
    NS2.SetByPath("container.bars.name.font", "Ka0s Prototype", 1)
    CM.RequestApply = request
    -- red under: no PrimeAll in the CONFIG_CHANGED handler, or one after RequestApply
    assertEqual(seen, 1)
end)

test("fontprimer: a profile switch primes the new profile's fonts before it builds", function()
    local NS2, _, FP, CM = env()
    cfgOf(NS2, 2).icons.time.font = "Ka0s Kait"
    local sync, seen = CM.Sync, nil
    CM.Sync = function(...)
        seen = seen or #FP.DiagState().primed
        return sync(...)
    end
    NS2.OnProfileChanged()
    CM.Sync = sync
    -- red under: no PrimeAll in CM.Announce (a switch sends no CONFIG_CHANGED)
    assertEqual(seen, 1)
end)

-- -- trace ---------------------------------------------------------------------------------------------

test("fontprimer: one Fonts debug line per PrimeAll that primed something, and none otherwise", function()
    local NS2, _, FP = env()
    local lines = {}
    local debug = NS2.Debug
    NS2.Debug = function(tag, fmt, ...)
        if tag ~= "Fonts" then return end
        local n = #lines
        lines[n + 1] = string.format(fmt, ...)
    end
    FP.PrimeAll()
    assertEqual(#lines, 0, "nothing primed, nothing said")
    local c1 = cfgOf(NS2, 1)
    c1.bars.name.font, c1.bars.time.font = "Ka0s Prototype", "Ka0s Kait"
    FP.PrimeAll()
    FP.PrimeAll()
    NS2.Debug = debug
    -- red under: a line per triple, or a line for a PrimeAll that primed nothing
    assertEqual(#lines, 1)
    assertEqual(lines[1], "primed 2 new font(s)")
    assertNil(lines[2])
end)
