-- tests/test_slash.lua — settings/Slash.lua: NS.COMMANDS and the host verbs, driven through the
-- real LibKa0s-Slash dispatcher exactly as `/am …` reaches it.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local NS = T.NS
local fresh = dofile("tests/fresh_env.lua")

local function capture(mocks)
    local lines = {}
    rawset(mocks.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
        lines[#lines + 1] = tostring(msg)
    end)
    return lines
end

local function said(lines, fragment)
    for _, l in ipairs(lines) do if l:find(fragment, 1, true) then return true end end
    return false
end

--- The last line printed, or "" when nothing was (an assertion's message).
local function lastLine(lines)
    local count = #lines
    return lines[count] or ""
end

test("slash: every command is a positional {name, desc, fn} triple", function()
    for i, e in ipairs(NS.COMMANDS) do
        assertTrue(type(e[1]) == "string" and type(e[2]) == "string" and type(e[3]) == "function",
            "NS.COMMANDS[" .. i .. "]")
    end
end)

test("slash: the reserved verbs are all present", function()
    local have = {}
    for _, e in ipairs(NS.COMMANDS) do have[e[1]] = true end
    for _, v in ipairs({ "help", "config", "list", "get", "set", "reset", "resetall", "debug", "perf", "version" }) do
        assertTrue(have[v], "reserved verb " .. v)
    end
end)

test("slash: /am new creates the described container and selects it", function()
    local NS2 = fresh()
    NS2.Slash:OnSlash("new target debuffs icons")
    local _, id = NS2.ActiveContainer()
    local c = NS2.Database.FindContainer(id)
    assertEqual(c.unit, "target")
    assertEqual(c.auraType, "HARMFUL")
    assertEqual(c.style, "icons")
    assertEqual(#NS2.Database.GetContainers(), #NS2.STARTER_CONTAINERS + 1)
end)

test("slash: /am new text creates a text-style container", function()
    local NS2 = fresh()
    NS2.Slash:OnSlash("new player buffs text")
    local _, id = NS2.ActiveContainer()
    local c = NS2.Database.FindContainer(id)
    -- red under: NEW_WORDS without "text" (the verb refuses the word and creates nothing)
    assertEqual(c.style, "text")
    assertEqual(c.auraType, "HELPFUL")
    assertEqual(#NS2.Database.GetContainers(), #NS2.STARTER_CONTAINERS + 1)
end)

test("slash: /am new gives the new container the Fill its style suits (B5)", function()
    local NS2 = fresh()
    for word, axis in pairs({ icons = "horizontal", bars = "vertical", text = "vertical" }) do
        NS2.Slash:OnSlash("new target debuffs " .. word)
        local _, id = NS2.ActiveContainer()
        -- red under: CM.Create keeping the template's Fill whatever the style (an icon row in Columns)
        assertEqual(NS2.Database.FindContainer(id).layout.axis, axis, word)
    end
end)

test("slash: /am new with a word it does not know creates nothing and says why", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    NS2.Slash:OnSlash("new target sparkles")
    assertEqual(#NS2.Database.GetContainers(), #NS2.STARTER_CONTAINERS)
    assertTrue(said(lines, "sparkles"))
end)

test("slash: /am select takes an id or a name; /am containers marks the selection", function()
    local NS2, mocks = fresh()
    NS2.Slash:OnSlash("select player debuffs")
    assertEqual(NS2.State.activeContainerId, 2)
    NS2.Slash:OnSlash("select 3")
    assertEqual(NS2.State.activeContainerId, 3)
    local lines = capture(mocks)
    NS2.Slash:OnSlash("containers")
    assertTrue(said(lines, "Target debuffs (mine)"))
end)

test("slash: /am set writes the selected container through the seam", function()
    local NS2, mocks = fresh()
    NS2.Slash:OnSlash("select 2")
    NS2.Slash:OnSlash("set container.icons.width 48")
    assertEqual(NS2.Database.FindContainer(2).icons.width, 48)
    assertEqual(NS2.Database.FindContainer(1).icons.width, NS2.CONTAINER_TEMPLATE.icons.width)
    local lines = capture(mocks)
    NS2.Slash:OnSlash("get container.icons.width")
    assertTrue(said(lines, "Player debuffs"), "a container value names the container it read")
end)

test("slash: lock and unlock drive the same setting the panel does", function()
    local NS2 = fresh()
    NS2.Slash:OnSlash("unlock")
    assertFalse(NS2.db.profile.locked)
    NS2.Slash:OnSlash("lock")
    assertTrue(NS2.db.profile.locked)
end)

test("slash: /am preview is an unknown verb; /am test switches test mode and leaves the lock alone (B1)", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    NS2.Slash:OnSlash("preview on")
    assertTrue(said(lines, "command 'preview'"), lastLine(lines))
    NS2.Slash:OnSlash("test")
    -- red under: NS.COMMANDS without its {"test", ...} entry
    assertTrue(NS2.State.testMode, "/am test toggles it on")
    assertTrue(said(lines, "Test mode on"), lastLine(lines))
    NS2.Slash:OnSlash("test off")
    assertFalse(NS2.State.testMode)
    NS2.Slash:OnSlash("test on")
    assertTrue(NS2.State.testMode)
    assertTrue(NS2.db.profile.locked, "the lock is untouched")
    NS2.Slash:OnSlash("test sideways")
    assertTrue(said(lines, "Usage: /am test [on|off]"), lastLine(lines))
end)

test("slash: /am help and the landing page list test, and not preview (B1)", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    NS2.Slash:OnSlash("help")
    local help, rows = table.concat(lines, "\n"), table.concat(NS2.Slash.LandingRows(), "\n")
    -- The verb, then anything but a letter: a help row closes the verb's color code right after it.
    local function listed(text, verb) return text:find("/am " .. verb .. "[^%w]") ~= nil end
    -- red under: NS.COMMANDS without its {"test", ...} row
    assertTrue(listed(help, "test") and listed(rows, "test"), "test is listed")
    assertFalse(listed(help, "preview") or listed(rows, "preview"), "no preview verb")
    -- red under: the unlock row still promising placeholder auras
    assertFalse(help:find("shows placeholder auras", 1, true) ~= nil, "unlock no longer previews")
end)

local function grayLine(lines, fragment)
    for _, l in ipairs(lines) do
        if l:find("|cff808080", 1, true) and l:find(fragment, 1, true) then return true end
    end
    return false
end

--- Wrap NS2.SetByPath so a case can see what the verb handed the seam; the real seam still runs
--- unless `answer` stands in for it.
local function recordSeam(NS2, answer)
    local calls, real = {}, NS2.SetByPath
    NS2.SetByPath = function(path, value, id)
        calls[#calls + 1] = { path = path, value = value }
        if answer then return answer(path, value, id) end
        return real(path, value, id)
    end
    return calls
end

--- Every live container's engine, enabled or not (the visibility pass's visible outcome).
local function enginesEnabled(NS2)
    local on, off = 0, 0
    for _, inst in pairs(NS2.ContainerManager.instances) do
        if inst.engine then
            if inst.engine.__enabled then on = on + 1 else off = off + 1 end
        end
    end
    return on, off
end

test("slash: /am disable and /am enable write the master switch through the seam and say so", function()
    local NS2, mocks = fresh()
    local calls = recordSeam(NS2)
    local lines = capture(mocks)
    assertTrue(NS2.db.profile.enabled, "the shipped profile starts enabled")
    NS2.Slash:OnSlash("disable")
    assertEqual(calls[1] and calls[1].path, "enabled")
    assertEqual(calls[1] and calls[1].value, false)
    assertFalse(NS2.db.profile.enabled)
    -- The set shape (slash-commands-§5), read back through the library's CliGet.
    assertTrue(said(lines, "enabled|r = |cFFFFFFFFfalse|r"), lastLine(lines))
    local on, off = enginesEnabled(NS2)
    assertTrue(on == 0 and off > 0, "the visibility pass disabled every engine")
    NS2.Slash:OnSlash("enable")
    assertEqual(calls[2] and calls[2].path, "enabled")
    assertEqual(calls[2] and calls[2].value, true)
    assertTrue(NS2.db.profile.enabled, "disable then enable round-trips")
    assertTrue(said(lines, "enabled|r = |cFFFFFFFFtrue|r"), lastLine(lines))
    on, off = enginesEnabled(NS2)
    assertTrue(on > 0 and off == 0, "the visibility pass re-enabled every engine")
end)

test("slash: /am disable in combat is not refused; the master switch is a visibility write", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    mocks.__lockdown = true
    NS2.Slash:OnSlash("disable")
    assertFalse(NS2.db.profile.enabled)
    -- red under: runEnabled refusing in gray under InCombatLockdown
    assertFalse(grayLine(lines, "during combat"), lastLine(lines))
    local on = enginesEnabled(NS2)
    assertEqual(on, 0, "engines disabled in combat through their own SetEnabled")
end)

test("slash: /am enable prints the seam's error instead of the success line", function()
    local NS2, mocks = fresh()
    recordSeam(NS2, function() return false, "the seam said no" end)
    local lines = capture(mocks)
    NS2.Slash:OnSlash("enable")
    assertTrue(said(lines, "the seam said no"), lastLine(lines))
    -- red under: runEnabled printing the success line whatever the seam answered
    assertFalse(said(lines, "enabled|r = "), lastLine(lines))
    assertEqual(#lines, 1, "one line: the error")
end)

test("slash: enable and disable are listed by /am help and on the landing page", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    NS2.Slash:OnSlash("help")
    local rows = table.concat(NS2.Slash.LandingRows(), "\n")
    -- The verb, then anything but a letter: a help row closes the verb's color code right after it.
    local function listed(text, verb) return text:find("/am " .. verb .. "[^%w]") ~= nil end
    for _, verb in ipairs({ "enable", "disable" }) do
        assertTrue(listed(table.concat(lines, "\n"), verb), "help row for " .. verb)
        assertTrue(listed(rows, verb), "landing row for " .. verb)
    end
end)

--- The library-absent environment, initialized so it has a database and containers.
local function degraded()
    local NS2, mocks = dofile("tests/degraded_env.lua")()
    rawset(_G, "AuraMasterDB", nil)
    NS2.addon:OnInitialize()
    return NS2, mocks
end

test("slash: the degraded stub's /am disable and /am enable store the switch through writeThrough", function()
    local NS2, mocks = degraded()
    -- No composed row in this build: the path is reached through NS.WRITE_THROUGH alone.
    assertNil(NS2.FindSchemaRow("enabled"), "the stub composer registered no enabled row")
    local lines = capture(mocks)
    NS2.Slash:OnSlash("disable")
    -- red under: writeThrough absent (Setting not found)
    assertFalse(NS2.db.profile.enabled, "disable stored false")
    assertFalse(said(lines, "Setting not found"), lastLine(lines))
    assertTrue(NS2.IsStoodDown(), "the latch followed the stored switch")
    NS2.Slash:OnSlash("enable")
    assertTrue(NS2.db.profile.enabled, "enable stored true")
    assertFalse(NS2.IsStoodDown(), "the latch followed it back up")
    assertTrue(said(lines, "Aura Master enabled"), lastLine(lines))
    local rows = table.concat(NS2.Slash.LandingRows(), "\n")
    assertTrue(rows:find("/am disable", 1, true) ~= nil, "the stub lists the verb")
end)

test("slash: the degraded stub's /am lock and /am unlock store the lock through writeThrough", function()
    local NS2, mocks = degraded()
    assertNil(NS2.FindSchemaRow("locked"), "the stub composer registered no locked row")
    local lines = capture(mocks)
    NS2.Slash:OnSlash("unlock")
    -- red under: writeThrough absent (Setting not found)
    assertFalse(NS2.db.profile.locked, "unlock stored false")
    NS2.Slash:OnSlash("lock")
    assertTrue(NS2.db.profile.locked, "lock stored true")
    assertFalse(said(lines, "Setting not found"), lastLine(lines))
    assertTrue(said(lines, "Containers locked"), lastLine(lines))
end)

test("slash: /am delete removes a container by id", function()
    local NS2 = fresh()
    NS2.Slash:OnSlash("delete 3")
    assertNil(NS2.Database.FindContainer(3))
    assertEqual(#NS2.Database.GetContainers(), #NS2.STARTER_CONTAINERS - 1)
end)

test("slash: a name two containers share is refused, not guessed", function()
    local NS2, mocks = fresh()
    -- A legacy profile: stored straight into the database, around the seam that now keeps names unique.
    NS2.Database.FindContainer(1).name = "Dup"
    NS2.Database.FindContainer(2).name = "dup"
    NS2.State.SetActiveContainer(3)
    local lines = capture(mocks)
    NS2.Slash:OnSlash("delete dup")
    -- red under: findContainer returning the first match
    assertEqual(#NS2.Database.GetContainers(), #NS2.STARTER_CONTAINERS, "both containers remain")
    assertTrue(said(lines, "More than one container is called 'dup'"), lastLine(lines))
    NS2.Slash:OnSlash("select DUP")
    assertEqual(NS2.State.activeContainerId, 3, "the selection does not move")
    assertTrue(said(lines, "More than one container is called 'DUP'"), lastLine(lines))
end)

test("slash: /am delete in combat refuses in gray and keeps the container", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    mocks.__lockdown = true
    NS2.Slash:OnSlash("delete 3")
    -- red under: runDelete without its InCombatLockdown gate
    assertTrue(NS2.Database.FindContainer(3) ~= nil, "the container survives")
    assertEqual(#NS2.Database.GetContainers(), #NS2.STARTER_CONTAINERS)
    assertTrue(grayLine(lines, "cannot delete a container during combat"), lastLine(lines))
end)

local function counted(frame, method)
    local n, orig = { 0 }, frame[method]
    frame[method] = function(self, ...)
        n[1] = n[1] + 1
        return orig(self, ...)
    end
    return n
end

--- Reset all under lockdown, from `surface`. It must be the act Profiles → Reset Profile performs,
--- db:ResetProfile() (options-ui-§12), and the container the reset drops must be parked, never
--- hidden, then torn down once combat ends.
local function resetsUnderLockdown(surface)
    local NS2, mocks = fresh()
    local CM = NS2.ContainerManager
    local id = CM.Create({})
    mocks.__fireTimers()
    local inst = CM.instances[id]
    assertTrue(inst.engine ~= nil, "built out of lockdown")
    inst.anchor:Show()
    local hides, clears = counted(inst.anchor, "Hide"), counted(inst.anchor, "ClearAllPoints")
    local engineHides = counted(inst.engine, "Hide")
    local resets, reset = { 0 }, NS2.db.ResetProfile
    NS2.db.ResetProfile = function(...)
        resets[1] = resets[1] + 1
        return reset(...)
    end
    local lines = capture(mocks)
    mocks.__lockdown = true
    surface(NS2, mocks)
    -- red under: the surface keeping an InCombatLockdown refusal in front of RestoreAllDefaults
    assertEqual(resets[1], 1, "db:ResetProfile(), once: the same act as Reset Profile")
    assertFalse(grayLine(lines, "during combat"), "no refusal: " .. lastLine(lines))
    assertTrue(said(lines, "All settings reset to defaults."), lastLine(lines))
    assertEqual(#NS2.Database.GetContainers(), #NS2.STARTER_CONTAINERS, "the shipped set is back")
    -- red under: CM.Sync destroying instead of parking under MustDefer
    assertEqual(hides[1], 0)
    assertEqual(clears[1], 0)
    assertEqual(engineHides[1], 0)
    assertTrue(inst.anchor:IsShown(), "the anchor is not hidden under lockdown")
    assertFalse(inst.engine.__enabled, "its engine is disabled, which is combat-legal")
    assertTrue(CM.__retiring()[id] == inst, "parked until combat ends")
    mocks.__lockdown = false
    CM.FlushPending()
    assertTrue(hides[1] >= 1 and clears[1] >= 1, "torn down after combat")
    assertNil(next(CM.__retiring()), "nothing left parked")
end

test("slash: /am resetall in combat resets the profile and parks what it drops (options-ui-§12)", function()
    resetsUnderLockdown(function(NS2) NS2.Slash:OnSlash("resetall") end)
end)

test("slash: the General Reset-all popup in combat resets the profile and parks what it drops (options-ui-§12)", function()
    resetsUnderLockdown(function(_, mocks) mocks.StaticPopupDialogs.AURAMASTER_RESET_ALL.OnAccept() end)
end)

test("slash: /am new in combat refuses in gray and creates nothing", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    mocks.__lockdown = true
    NS2.Slash:OnSlash("new target debuffs icons")
    assertEqual(#NS2.Database.GetContainers(), #NS2.STARTER_CONTAINERS)
    -- red under: runNew printing a refused err through the plain printer
    assertTrue(grayLine(lines,
        "cannot create a container during combat — it would not be drawn or placed until combat ends"),
        lastLine(lines))
    assertEqual(#lines, 1, "one line, not a gray one and a plain one")
end)

test("slash: /am pick starts the frame picker for the selected container", function()
    local NS2, mocks = fresh()
    NS2.Slash:OnSlash("select 2")
    NS2.Slash:OnSlash("pick")
    assertTrue(NS2.FramePicker.IsActive())
    local target = mocks.__stubFrame()
    target.GetName = function() return "FocusFrame" end
    target.IsForbidden = function() return false end
    mocks.__foci = { target }
    local overlay = mocks.__globals.AuraMasterFramePicker
    overlay:__fire("OnUpdate")                 -- arms (no button held)
    mocks.__mouseDown.LeftButton = true
    overlay:__fire("OnUpdate")
    local c = NS2.Database.FindContainer(2)
    assertEqual(c.attach.mode, "frame")
    assertEqual(c.attach.frame, "FocusFrame")
end)

test("slash: /am resetall and the General reset print the same line", function()
    local NS2, mocks = fresh()
    local fromSlash = capture(mocks)
    NS2.Slash:OnSlash("resetall")
    local fromPage = capture(mocks)
    mocks.StaticPopupDialogs.AURAMASTER_RESET_ALL.OnAccept()
    local slashCount, pageCount = #fromSlash, #fromPage
    assertTrue(slashCount >= 1 and pageCount >= 1, "both surfaces acknowledged the reset")
    assertEqual(fromSlash[#fromSlash], fromPage[#fromPage])
    assertTrue(said(fromPage, "All settings reset to defaults."), fromPage[#fromPage])
end)

test("slash: /am debug on and off flip the session flag; it never reaches the profile", function()
    local NS2 = fresh()
    NS2.Slash:OnSlash("debug on")
    assertTrue(NS2.State.debug)
    NS2.Slash:OnSlash("debug off")
    assertFalse(NS2.State.debug)
    -- red under: DebugLogSetup's setEnabled writing NS.db.profile.debug (reached via /am debug off)
    assertNil(NS2.db.profile.debug)
end)

test("slash: the dispatcher's isEnabled is NS.EnabledStored", function()
    -- A descriptor spy: the same load fresh_env.lua does, with LibKa0s-Slash's New wrapped between
    -- the library and the TOC, so the descriptor settings/Slash.lua builds is the one inspected.
    local Loader     = dofile("tests/_kit/loader.lua")
    local buildMocks = dofile("tests/wow_mock.lua")
    Loader.addonName = "AuraMaster"
    local mocks, NS2 = buildMocks(), {}
    rawset(_G, "AuraMasterDB", nil)
    Loader.loadAll(Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml"), NS2, mocks)
    local lib = (mocks.LibStub or _G.LibStub)("LibKa0s-Slash-1.0")
    local realNew, seen = lib.New, nil
    lib.New = function(self, d)
        if d and d.slash == "/am" then seen = d end
        return realNew(self, d)
    end
    local ok, err = pcall(Loader.loadAll, Loader.tocFiles("AuraMaster.toc"), NS2, mocks)
    lib.New = realNew
    if not ok then error(err, 0) end
    assertTrue(seen ~= nil, "settings/Slash.lua built its dispatcher through LibKa0s-Slash:New")
    assertTrue(type(NS2.EnabledStored) == "function", "core/LifecycleSetup.lua publishes NS.EnabledStored")
    -- red under: a second, private isEnabled in settings/Slash.lua
    assertTrue(seen.isEnabled == NS2.EnabledStored, "one enabled predicate, not two")
    -- Before InitDB the stored read answers nil, and nil is enabled.
    assertTrue(NS2.EnabledStored())
end)
