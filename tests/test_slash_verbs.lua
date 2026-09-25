-- tests/test_slash_verbs.lua — settings/Slash.lua verb by verb, driven through the real
-- LibKa0s-Slash dispatcher as `/am …` reaches it: the help surface, the schema verbs over this
-- addon's relative and absolute paths, the host verbs, and the degradation stub. The library's own
-- parser and formatters are tested in LibKa0s (testing-§8); what is pinned here is the wiring this
-- addon owns — its rows, its seams, its annotator, its verbs and its messages.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local loadDegraded = dofile("tests/degraded_env.lua")

local function capture(mocks)
    local lines = {}
    rawset(mocks.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
        lines[#lines + 1] = tostring(msg)
    end)
    return lines
end

--- A chat line with its color codes and the [AM] tag taken off.
local function strip(s)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return (s:gsub("^%[AM%] ", ""))
end

local function plain(lines)
    local out = {}
    for i, l in ipairs(lines) do out[i] = strip(l) end
    return out
end

--- Run one `/am` line and answer what it printed, plain.
local function slash(NS2, lines, msg)
    for k in pairs(lines) do lines[k] = nil end
    NS2.Slash:OnSlash(msg)
    return plain(lines)
end

local function said(p, text)
    for _, l in ipairs(p) do if l == text then return true end end
    return false
end

local function dump(p) return "{" .. table.concat(p, " | ") .. "}" end

local function deleteAll(NS2)
    for _, c in ipairs(NS2.Database.GetContainers()) do NS2.ContainerManager.Delete(c.id) end
end

local function announcements(NS2)
    local n = { 0 }
    NS2.NewBusTarget():RegisterMessage(NS2.MSG.CONFIG_CHANGED, function() n[1] = n[1] + 1 end)
    return n
end

local MISSING_ROW = "No container exists yet — create one on Containers."

-- ── the help surface ──────────────────────────────────────────────────────────────────────────

test("slash verbs: /am help prints the alias header, then one row per NS.COMMANDS verb in order", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    local p = slash(NS2, lines, "help")
    local seen = {}
    for _, e in ipairs(NS2.COMMANDS) do
        assertNil(seen[e[1]], "verb " .. e[1] .. " is declared twice")
        seen[e[1]] = true
        assertTrue(e[2] ~= "", "verb " .. e[1] .. " has no description")
    end
    assertEqual(#p, 1 + #NS2.COMMANDS, dump(p))
    -- red under: the descriptor's slashAliases dropped (the header names no alias)
    assertEqual(p[1], "v" .. NS2.Version() .. " — slash commands (/auramaster is an alias for /am)")
    for i, e in ipairs(NS2.COMMANDS) do
        assertEqual(p[i + 1], "  /am " .. e[1] .. " — " .. e[2])
    end
end)

test("slash verbs: the landing page's rows are /am help's rows without the chat indent", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    NS2.Slash:OnSlash("help")
    local rows = NS2.Slash.LandingRows()
    assertEqual(#rows, #NS2.COMMANDS)
    for i, row in ipairs(rows) do
        local chat = lines[i + 1]:gsub("^|c%x+%[AM%]|r ", "")
        -- red under: Sl.LandingRows building its own rows, or indenting them
        assertEqual(chat, "  " .. row)
    end
end)

test("slash verbs: /am and /auramaster both reach the one dispatcher", function()
    local NS2, mocks = fresh()
    local console = mocks.LibStub("AceConsole-3.0")
    assertEqual(console.commands.am, "ACECONSOLE_AM")
    -- red under: Sl.Register dropping the long alias
    assertEqual(console.commands.auramaster, "ACECONSOLE_AURAMASTER")
    local lines = capture(mocks)
    console:__slash("auramaster", "Version")
    assertEqual(dump(plain(lines)), "{v" .. NS2.Version() .. "}", "the verb is case-insensitive")
    assertTrue(NS2.Slash.__cli ~= nil)
end)

test("slash verbs: /am options is an alias of /am config, and both open the settings panel", function()
    local NS2 = fresh()
    local opened = { 0 }
    NS2.OpenOptionsPanel = function() opened[1] = opened[1] + 1 end
    NS2.Slash:OnSlash("config")
    NS2.Slash:OnSlash("OPTIONS")
    -- red under: the descriptor's `aliases = { options = "config" }` dropped
    assertEqual(opened[1], 2)
end)

test("slash verbs: a bare or whitespace-only /am opens the settings panel through config; /am help prints the list", function()
    -- slash-commands-§4 (standard v2.50.0; LibKa0s Slash minor 11): bare /am runs the `config` verb.
    local NS2, mocks = fresh()
    local opened = { 0 }
    NS2.OpenOptionsPanel = function() opened[1] = opened[1] + 1 end
    local lines = capture(mocks)
    -- red under: the dispatcher's bare branch printing help instead of running `config`
    assertEqual(dump(slash(NS2, lines, "")), "{}", "a bare /am prints nothing of its own")
    assertEqual(opened[1], 1, "and opens the panel")
    assertEqual(dump(slash(NS2, lines, "   ")), "{}")
    assertEqual(opened[1], 2, "whitespace alone is bare too")
    local p = slash(NS2, lines, "help")
    assertEqual(#p, 1 + #NS2.COMMANDS, "help is the list: " .. dump(p))
    assertEqual(opened[1], 2, "and opens nothing")
end)

test("slash verbs: in combat a bare /am prints the same refusal /am config does", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    mocks.__lockdown = true
    local viaConfig = dump(slash(NS2, lines, "config"))
    assertTrue(viaConfig ~= "{}", "config is refused with a line")
    -- red under: a bare /am reaching anything but the config verb's own open
    assertEqual(dump(slash(NS2, lines, "")), viaConfig)
end)

test("slash verbs: /am version prints the version on its own line", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    -- red under: the version verb's handler emptied (it prints nothing)
    assertEqual(dump(slash(NS2, lines, "version")), "{v" .. NS2.Version() .. "}")
    assertTrue(lines[1]:find("[AM]", 1, true) ~= nil, "through the tagged printer: " .. lines[1])
end)

-- ── the schema verbs ──────────────────────────────────────────────────────────────────────────

test("slash verbs: get, set and reset with no path print a usage line naming /am", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    -- red under: the descriptor's `slash` naming another prefix
    assertEqual(dump(slash(NS2, lines, "get")), "{Usage: /am get <path>}")
    assertEqual(dump(slash(NS2, lines, "set")), "{Usage: /am set <path> <value>  (try /am list)}")
    assertEqual(dump(slash(NS2, lines, "reset")), "{Usage: /am reset <path>}")
end)

test("slash verbs: an unknown path, or one in the wrong case, is not found and nothing is written", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    local sent = announcements(NS2)
    assertEqual(dump(slash(NS2, lines, "get nope.path")), "{Setting not found: nope.path}")
    assertEqual(dump(slash(NS2, lines, "set nope.path 5")), "{Setting not found: nope.path}")
    assertEqual(dump(slash(NS2, lines, "reset nope.path")), "{Setting not found: nope.path}")
    -- red under: findRow folding case (a path is case-sensitive)
    assertEqual(dump(slash(NS2, lines, "set Container.bars.width 300")), "{Setting not found: Container.bars.width}")
    assertEqual(NS2.Database.FindContainer(1).bars.width, NS2.CONTAINER_TEMPLATE.bars.width)
    assertEqual(sent[1], 0)
end)

test("slash verbs: a global row reads with no note; a container row names the container it read", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    -- red under: the row annotator noting every row, not only `container.` ones
    assertEqual(dump(slash(NS2, lines, "get alpha")), "{alpha = 1}")
    NS2.State.SetActiveContainer(nil)
    assertEqual(dump(slash(NS2, lines, "get container.bars.width")), "{container.bars.width = 220  (Player buffs)}",
        "nothing selected: the first container")
    NS2.Slash:OnSlash("select 3")
    -- red under: the annotator reading a container other than the one the value came from
    assertEqual(dump(slash(NS2, lines, "get container.icons.width")),
        "{container.icons.width = " .. NS2.Database.FindContainer(3).icons.width .. "  (Target debuffs (mine))}")
end)

test("slash verbs: with no containers, get and list read a container row as nil and note nothing", function()
    local NS2, mocks = fresh()
    deleteAll(NS2)
    local lines = capture(mocks)
    -- red under: the annotator indexing a nil container
    assertEqual(dump(slash(NS2, lines, "get container.bars.width")), "{container.bars.width = nil}")
    local p = slash(NS2, lines, "list")
    assertTrue(said(p, "    container.bars.width = nil"), "list reads it the same way")
    assertTrue(said(p, "    alpha = 1"))
end)

test("slash verbs: set clamps a number to the row's range and echoes what was stored", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    NS2.State.SetActiveContainer(1)
    assertEqual(dump(slash(NS2, lines, "set container.bars.width 99999")), "{container.bars.width = 600  (Player buffs)}")
    assertEqual(NS2.Database.FindContainer(1).bars.width, 600)
    slash(NS2, lines, "set container.bars.width 1")
    -- red under: the Bars width row losing its min/max (the parser has nothing to clamp to)
    assertEqual(NS2.Database.FindContainer(1).bars.width, 40)
end)

test("slash verbs: set refuses what the row's type cannot take, and stores and announces nothing", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    local sent = announcements(NS2)
    assertEqual(dump(slash(NS2, lines, "set container.bars.width abc")),
        "{Invalid value for container.bars.width |   expected a number}")
    -- red under: the unit row's `values` dropped (every word would be accepted)
    assertEqual(dump(slash(NS2, lines, "set container.unit raid")),
        "{Invalid value for container.unit |   allowed values: player, target, focus, pet}")
    assertEqual(dump(slash(NS2, lines, "set locked maybe")),
        "{Invalid value for locked |   expected true/false/on/off/1/0/yes/no}")
    assertEqual(NS2.Database.FindContainer(1).unit, "player")
    assertTrue(NS2.db.profile.locked)
    assertEqual(sent[1], 0)
end)

test("slash verbs: set writes a color in the stored {r, g, b, a} shape; get decodes a partial one channel by channel", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    NS2.State.SetActiveContainer(1)
    assertEqual(dump(slash(NS2, lines, "set container.bars.barColor 255 0 0 0.5")),
        "{container.bars.barColor = {1.00, 0.00, 0.00, 0.50}  (Player buffs)}")
    local c = NS2.Database.FindContainer(1).bars.barColor
    -- red under: the descriptor's colorEncode storing positionally
    assertEqual(c.r, 1)
    assertEqual(c.a, 0.5)
    assertNil(c[1])
    NS2.Database.FindContainer(1).bars.barColor = { r = 0.5 }
    -- red under: colorDecode dropped (the library's fallback reads a missing channel as 0)
    assertEqual(dump(slash(NS2, lines, "get container.bars.barColor")),
        "{container.bars.barColor = {0.50, 1.00, 1.00, 1.00}  (Player buffs)}")
end)

test("slash verbs: a value the parser takes but the seam refuses prints the refusal and no echo of the unchanged value", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    NS2.Slash:OnSlash("select 2")
    NS2.Slash:OnSlash("set container.attach.mode container")
    NS2.Slash:OnSlash("set container.attach.container 1")
    NS2.Slash:OnSlash("select 1")
    NS2.Slash:OnSlash("set container.attach.mode container")
    -- red under: the descriptor's set swallowing SetByPath's answer (the unchanged value echoes)
    assertEqual(dump(slash(NS2, lines, "set container.attach.container 2")),
        "{Invalid value for container.attach.container}")
    deleteAll(NS2)
    assertEqual(dump(slash(NS2, lines, "set container.bars.width 300")),
        "{Invalid value for container.bars.width |   " .. MISSING_ROW .. "}")
end)

test("slash verbs: /am set with a refused value prints INVALID and the row's reason once each, and does not echo the unchanged value", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    NS2.State.SetActiveContainer(1)
    local before = NS2.Database.FindContainer(1).text.template
    local why = NS2.L["$%s$ appears twice — each token can be used once."]:format("spellname")
    -- red under: the host wrapper printing and returning nil
    assertEqual(dump(slash(NS2, lines, "set container.text.template $spellname$[ $spellname$]")),
        "{Invalid value for container.text.template |   " .. why .. "}")
    assertEqual(NS2.Database.FindContainer(1).text.template, before)
end)

test("slash verbs: /am reset container.name prints the library's no-default line once", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    NS2.State.SetActiveContainer(1)
    local SlashLib = mocks.LibStub("LibKa0s-Slash-1.0")
    -- red under: the host's applyDefault printing the row's reason and returning nil (an echo follows)
    assertEqual(dump(slash(NS2, lines, "reset container.name")),
        "{" .. SlashLib.STRINGS.NO_DEFAULT:format("container.name") .. "}")
    assertEqual(NS2.Database.FindContainer(1).name, "Player buffs")
end)

test("slash verbs: /am reset with no container prints the seam's reason, not the no-default line", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    deleteAll(NS2)
    local SlashLib = mocks.LibStub("LibKa0s-Slash-1.0")
    local out = dump(slash(NS2, lines, "reset container.bars.width"))
    -- red under: the descriptor's applyDefault handing the seam's refusal to CliReset as false,
    -- which prints NO_DEFAULT for a row that has a default and drops the real reason
    assertEqual(out:find(SlashLib.STRINGS.NO_DEFAULT:format("container.bars.width"), 1, true), nil, out)
    assertTrue(out:find(MISSING_ROW, 1, true) ~= nil, out)
end)

test("slash verbs: set and reset reach a session row, which never lands in the profile", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    assertEqual(dump(slash(NS2, lines, "set state.debugConsole on")), "{state.debugConsole = true}")
    assertTrue(NS2.DebugLog:IsShown())
    -- red under: writeRow's sessionOnly branch dropped (the write lands in profile.state, not set())
    assertNil(NS2.db.profile.state)
    assertEqual(dump(slash(NS2, lines, "reset state.debugConsole")), "{state.debugConsole = false}")
    assertFalse(NS2.DebugLog:IsShown())
end)

test("slash verbs: reset restores the selected container's row only, and its echo carries no note", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    NS2.SetByPath("container.bars.width", 300, 1)
    NS2.SetByPath("container.bars.width", 300, 2)
    NS2.Slash:OnSlash("select 2")
    assertEqual(dump(slash(NS2, lines, "reset container.bars.width")), "{container.bars.width = 220}")
    assertEqual(NS2.Database.FindContainer(2).bars.width, 220)
    -- red under: applyDefault writing every container
    assertEqual(NS2.Database.FindContainer(1).bars.width, 300)
end)

test("slash verbs: set on a global row writes the profile through the seam", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    local sent = announcements(NS2)
    assertEqual(dump(slash(NS2, lines, "set hideBlizzardBuffs on")), "{hideBlizzardBuffs = true}")
    assertTrue(NS2.db.profile.hideBlizzardBuffs)
    -- red under: the descriptor's set writing the table directly, around the seam
    assertEqual(sent[1], 1)
end)

test("slash verbs: /am list prints every row once, grouped by page in page order, noting container rows", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    local p = slash(NS2, lines, "list")
    assertEqual(p[1], "Available settings")
    local groups, rows = {}, {}
    for _, l in ipairs(p) do
        local g = l:match("^  %[(%a+)%]$")
        if g then
            groups[#groups + 1] = g
        end
        local path = l:match("^    (%S+) = ")
        if path then
            assertNil(rows[path], "listed twice: " .. path)
            rows[path] = l
        end
    end
    -- Containers is its own page now (N-1, batch 7), between General and Filters — the tree order.
    assertEqual(table.concat(groups, ","), "general,containers,filters,layout,bars,icons,text")
    -- red under: allRows answering fewer rows than NS.Schema
    for _, row in ipairs(NS2.Schema) do
        local l = rows[row.path]
        assertTrue(l ~= nil, "not listed: " .. row.path)
        local noted = l:find("  (Player buffs)", 1, true) ~= nil
        assertEqual(noted, row.path:find("^container%.") ~= nil, "note on " .. row.path)
    end
    assertEqual(#p, 1 + #groups + #NS2.Schema)
end)

-- ── resetall ──────────────────────────────────────────────────────────────────────────────────

test("slash verbs: /am resetall resets the profile once, with no popup, and says so", function()
    local NS2, mocks = fresh()
    local popups, resets = { 0 }, { 0 }
    mocks.StaticPopup_Show = function() popups[1] = popups[1] + 1 end
    local reset = NS2.db.ResetProfile
    NS2.db.ResetProfile = function(...) resets[1] = resets[1] + 1; return reset(...) end
    NS2.db:SetProfile("Raid")
    NS2.db:SetProfile("Default")
    local profiles = table.concat(NS2.db:GetProfiles(), ",")
    NS2.SetByPath("alpha", 0.5)
    local lines = capture(mocks)
    local p = slash(NS2, lines, "resetall")
    -- red under: runResetAll showing the confirmation instead of running the reset
    assertEqual(popups[1], 0)
    assertEqual(resets[1], 1)
    assertEqual(NS2.db.profile.alpha, 1)
    assertEqual(table.concat(NS2.db:GetProfiles(), ","), profiles, "the profile list is untouched")
    assertEqual(p[#p], "All settings reset to defaults.")
end)

test("slash verbs: /am resetall without the settings helpers says it cannot, and resets nothing", function()
    local NS2, mocks = fresh()
    NS2.SetByPath("alpha", 0.5)
    NS2.Helpers.RestoreAllDefaults = nil
    local lines = capture(mocks)
    local p = slash(NS2, lines, "resetall")
    -- red under: the acknowledgment printed outside runResetAll's guard
    assertEqual(dump(p), "{Cannot reset settings — the settings helpers failed to load.}")
    assertEqual(NS2.db.profile.alpha, 0.5)
end)

test("slash verbs: the Reset-all confirmation is options-ui-§12's wording, a Yes/No pair that waits", function()
    local _, mocks = fresh()
    local d = mocks.StaticPopupDialogs.AURAMASTER_RESET_ALL
    -- red under: the popup text re-worded per addon
    assertEqual(d.text, "Reset this profile to the addon's defaults? Everything you have configured or added in it"
        .. " is discarded — your other profiles are not affected.")
    assertEqual(d.button1, "Yes")
    assertEqual(d.button2, "No")
    assertEqual(d.timeout, 0)
    assertTrue(d.whileDead)
    assertTrue(d.hideOnEscape)
end)

-- ── lock, unlock, pick ────────────────────────────────────────────────────────────────────────

test("slash verbs: /am lock and /am unlock go through the seam: unlocked shows the handle, and live auras keep drawing (B1)", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    local inst = NS2.ContainerManager.instances[1]
    assertEqual(dump(slash(NS2, lines, "unlock")), "{locked = false}")
    assertFalse(NS2.db.profile.locked)
    assertTrue(inst.handle:IsShown(), "unlocked: the handle shows")
    -- red under: ShouldShow still reading the lock as the preview
    assertFalse(inst.previewShown, "unlocked: no placeholders")
    assertTrue(inst.engine.__enabled, "unlocked: real auras draw")
    assertEqual(dump(slash(NS2, lines, "lock")), "{locked = true}")
    assertTrue(NS2.db.profile.locked)
    -- red under: runLock writing profile.locked around the seam (no CONFIG_CHANGED, no visibility pass)
    assertFalse(inst.handle:IsShown(), "locked: the handle goes")
end)

test("slash verbs: /am enable, /am disable, /am lock, /am unlock echo the stored value in the set shape", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    local SlashLib = mocks.LibStub("LibKa0s-Slash-1.0")
    --- The line `/am get <path>` prints for `value`: the library's formatter, no private variant.
    local function setShape(path, value)
        return SlashLib.FormatKV(path, SlashLib.FormatValue(NS2.FindSchemaRow(path), value))
    end
    for _, step in ipairs({ { "disable", "enabled", false }, { "enable", "enabled", true },
                            { "unlock", "locked", false }, { "lock", "locked", true } }) do
        local verb, path, value = step[1], step[2], step[3]
        slash(NS2, lines, verb)
        assertEqual(NS2.GetSetting(path), value, "/am " .. verb .. " wrote " .. path)
        local count = #lines
        -- red under: the prose confirmation
        assertEqual(lines[count] and strip(lines[count]), strip(setShape(path, value)), "/am " .. verb)
        assertTrue(lines[count] and lines[count]:find(setShape(path, value), 1, true) ~= nil,
            "/am " .. verb .. " kept the formatter's colors: " .. tostring(lines[count]))
        assertEqual(count, 1, "/am " .. verb .. " prints one line")
    end
end)

test("slash verbs: /am test in combat refuses on one gray line and starts nothing (B1)", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    mocks.__lockdown = true
    NS2.Slash:OnSlash("test")
    -- red under: Preview.SetTestMode starting under lockdown
    assertFalse(NS2.State.testMode)
    assertEqual(#lines, 1, "one line")
    assertTrue(lines[1]:find("|cff808080", 1, true) and lines[1]:find("Test mode can't start in combat.", 1, true) ~= nil, lines[1])
end)

--- Drive the frame picker's overlay the way the client would.
local function pickOverlay(mocks)
    local target = mocks.__stubFrame()
    target.GetName = function() return "FocusFrame" end
    target.IsForbidden = function() return false end
    mocks.__foci = { target }
    local overlay = mocks.__globals.AuraMasterFramePicker
    overlay:__fire("OnUpdate")                 -- arms (no button held)
    return overlay
end

test("slash verbs: /am pick with no containers, or in combat, never starts the picker", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    mocks.__lockdown = true
    local p = slash(NS2, lines, "pick")
    -- red under: runPick without its InCombatLockdown gate
    assertFalse(NS2.FramePicker.IsActive())
    assertEqual(dump(p), "{cannot pick a frame during combat — attaching to a frame waits until combat ends}")
    assertTrue(lines[1]:find("|cff808080", 1, true) ~= nil, "gray: " .. lines[1])
    mocks.__lockdown = false
    deleteAll(NS2)
    assertEqual(dump(slash(NS2, lines, "pick")), "{No containers yet — /am new creates one}")
    assertFalse(NS2.FramePicker.IsActive())
end)

test("slash verbs: /am pick attaches the container selected when it began, even if the selection moves", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    NS2.Slash:OnSlash("select 2")
    assertEqual(dump(slash(NS2, lines, "pick")),
        "{Point at a frame and left-click to attach 'Player debuffs'. Right-click or Escape cancels.}")
    NS2.Slash:OnSlash("select 3")
    local overlay = pickOverlay(mocks)
    for k in pairs(lines) do lines[k] = nil end
    mocks.__mouseDown.LeftButton = true
    overlay:__fire("OnUpdate")
    -- red under: the pick callback writing without the id captured at the start (it follows the selection)
    assertEqual(NS2.Database.FindContainer(2).attach.frame, "FocusFrame")
    assertEqual(NS2.Database.FindContainer(2).attach.mode, "frame")
    assertEqual(NS2.Database.FindContainer(3).attach.mode, "screen")
    assertTrue(said(plain(lines), "'Player debuffs' is now attached to FocusFrame"), dump(plain(lines)))
end)

test("slash verbs: /am set on a free-text row stores every word typed after the path", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    NS2.Slash:OnSlash("select 2")
    slash(NS2, lines, "set container.name My Raid Buffs")
    -- red under: LibKa0s-Slash minor 9, whose ParseValue handed a string row its first word ("My")
    assertEqual(NS2.Database.FindContainer(2).name, "My Raid Buffs")
    slash(NS2, lines, "set container.attach.frame  Some Frame  ")
    assertEqual(NS2.Database.FindContainer(2).attach.frame, "Some Frame", "trimmed at both ends")
end)

test("slash verbs: a right-click cancels /am pick, says so, and attaches nothing", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    NS2.Slash:OnSlash("select 2")
    NS2.Slash:OnSlash("pick")
    local overlay = pickOverlay(mocks)
    for k in pairs(lines) do lines[k] = nil end
    mocks.__mouseDown.RightButton = true
    overlay:__fire("OnUpdate")
    -- red under: runPick passing no cancel callback (the player is told nothing)
    assertEqual(dump(plain(lines)), "{Frame pick canceled}")
    assertFalse(NS2.FramePicker.IsActive())
    assertEqual(NS2.Database.FindContainer(2).attach.mode, "screen")
end)

-- ── perf, debug ───────────────────────────────────────────────────────────────────────────────

test("slash verbs: /am perf prints every line the harness returns, tagged, and hands it the rest of the line", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    NS2.Slash:OnSlash("perf")
    local want = #NS2.Perf.StatusLines()
    assertEqual(#lines, want, "one printed line per returned line")
    for _, l in ipairs(lines) do assertTrue(l:find("[AM]", 1, true) ~= nil, "untagged: " .. l) end
    assertEqual(dump(slash(NS2, lines, "perf cancel")), "{no perf run to cancel}")
    NS2.Slash:OnSlash("perf start Raid Night")
    -- red under: runPerf dropping `rest` (the label would never reach the harness)
    assertTrue(tostring(NS2.Perf.label):find("Raid Night", 1, true) ~= nil, tostring(NS2.Perf.label))
    assertTrue(NS2.DebugLog:IsShown(), "a run opens the log window")
    NS2.Perf.Cancel()
end)

test("slash verbs: a bare /am debug toggles the window and leaves the flag; /am debug ON is read in any case", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    assertFalse(NS2.DebugLog:IsShown())
    NS2.Slash:OnSlash("debug")
    assertTrue(NS2.DebugLog:IsShown())
    -- red under: runDebug calling SetEnabled for the bare verb
    assertFalse(NS2.State.debug)
    NS2.Slash:OnSlash("debug")
    assertFalse(NS2.DebugLog:IsShown())
    -- red under: firstWord not lowercasing (ON would toggle the window instead)
    assertEqual(dump(slash(NS2, lines, "debug ON")), "{debug logging ON}")
    assertTrue(NS2.State.debug)
    assertFalse(NS2.DebugLog:IsShown(), "the window did not move")
    NS2.Slash:OnSlash("debug off")
end)

-- ── the container verbs ───────────────────────────────────────────────────────────────────────

test("slash verbs: /am containers marks the selection and a disabled container, and says when there are none", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    NS2.SetByPath("container.enabled", false, 2)
    NS2.Slash:OnSlash("select 3")
    local p = slash(NS2, lines, "containers")
    assertEqual(p[1], "Containers")
    assertEqual(p[2], "    Player buffs  #1 - Player - Buffs - Bars")
    -- red under: describe ignoring `enabled`
    assertEqual(p[3], "    Player debuffs  #2 - Player - Debuffs - Icons - disabled")
    assertEqual(p[4], "  > Target debuffs (mine)  #3 - Target - Debuffs - Icons")
    deleteAll(NS2)
    assertEqual(dump(slash(NS2, lines, "containers")), "{No containers yet — /am new creates one}")
end)

test("slash verbs: /am select matches a name in any case, and a miss moves nothing", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    NS2.State.SetActiveContainer(1)
    -- red under: findContainer comparing names case-sensitively
    assertEqual(dump(slash(NS2, lines, "select  PLAYER DEBUFFS ")), "{Selected Player debuffs  #2 - Player - Debuffs - Icons}")
    assertEqual(NS2.State.activeContainerId, 2)
    for _, miss in ipairs({ "select nope", "select 99", "select" }) do
        assertEqual(dump(slash(NS2, lines, miss)), "{No such container — /am containers lists them}", miss)
    end
    assertEqual(NS2.State.activeContainerId, 2)
end)

test("slash verbs: /am new reads its words in any case, and a later word overrides an earlier one", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    local p = slash(NS2, lines, "NEW Focus Debuffs Bar")
    local _, id = NS2.ActiveContainer()
    local c = NS2.Database.FindContainer(id)
    -- red under: runNew looking words up without lowercasing
    assertEqual(c.unit, "focus")
    assertEqual(c.auraType, "HARMFUL")
    assertEqual(c.style, "bars")
    assertTrue(p[1]:find("^Created " .. c.name) ~= nil, dump(p))
    NS2.Slash:OnSlash("new player target pet buffs")
    _, id = NS2.ActiveContainer()
    assertEqual(NS2.Database.FindContainer(id).unit, "pet")
    assertEqual(NS2.Database.FindContainer(id).auraType, "HELPFUL")
end)

test("slash verbs: /am delete matches a name in any case and names what it deleted; a miss deletes nothing", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    assertEqual(dump(slash(NS2, lines, "delete target DEBUFFS (mine)")), "{Deleted 'Target debuffs (mine)'}")
    assertNil(NS2.Database.FindContainer(3))
    for _, miss in ipairs({ "delete 99", "delete", "delete nope" }) do
        assertEqual(dump(slash(NS2, lines, miss)), "{No such container — /am containers lists them}", miss)
    end
    -- red under: runDelete falling through to Delete(nil) on a miss
    assertEqual(#NS2.Database.GetContainers(), #NS2.STARTER_CONTAINERS - 1)
end)

test("slash verbs: /am resetposition and /am forgettimed do their act and say so", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    NS2.ContainerManager.ResetPositions()
    local x = NS2.Database.FindContainer(1).position.x
    NS2.Database.FindContainer(1).position.x = 500
    assertEqual(dump(slash(NS2, lines, "resetposition")), "{Container positions reset}")
    -- red under: runResetPosition printing without calling ContainerManager.ResetPositions
    assertEqual(NS2.Database.FindContainer(1).position.x, x)
    NS2.db.global.timedSpells[774] = true
    assertEqual(dump(slash(NS2, lines, "forgettimed")), "{Forgot every learned timed buff; they are relearned out of combat}")
    assertNil(NS2.db.global.timedSpells[774])
end)

-- ── the minimap row: the CLI path reads in its shown sense (launcher-§3) ──────────────────────

test("slash verbs: /am get global.minimap.shown answers true while the button shows; /am set global.minimap.shown false stores hide = true", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    -- red under: the path spelled hide
    assertEqual(dump(slash(NS2, lines, "get global.minimap.shown")), "{global.minimap.shown = true}")
    assertEqual(dump(slash(NS2, lines, "set global.minimap.shown false")), "{global.minimap.shown = false}")
    -- The STORAGE did not move: LibDBIcon's own `hide`, inverted once at the seam.
    assertEqual(NS2.db.global.minimap.hide, true)
    assertEqual(NS2.Launcher:IsShown(), false)
    assertEqual(dump(slash(NS2, lines, "reset global.minimap.shown")), "{global.minimap.shown = true}")
    assertEqual(NS2.db.global.minimap.hide, false)
end)

test("slash verbs: the old path global.minimap.hide is not a setting, and nothing is written", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    local sent = announcements(NS2)
    -- red under: the path spelled hide
    assertEqual(dump(slash(NS2, lines, "get global.minimap.hide")), "{Setting not found: global.minimap.hide}")
    assertEqual(dump(slash(NS2, lines, "set global.minimap.hide true")), "{Setting not found: global.minimap.hide}")
    assertEqual(dump(slash(NS2, lines, "reset global.minimap.hide")), "{Setting not found: global.minimap.hide}")
    assertEqual(NS2.db.global.minimap.hide, false)
    assertEqual(sent[1], 0)
end)

test("slash verbs: a legacy store's minimap.hide reads through the renamed path with no migration", function()
    -- A SavedVariables file written before the rename: LibDBIcon's own table, `hide` and a drag.
    local NS2, mocks = fresh({ savedVariables = { global = { minimap = { hide = true, minimapPos = 200 } } } })
    local lines = capture(mocks)
    -- red under: the path spelled hide
    assertEqual(dump(slash(NS2, lines, "get global.minimap.shown")), "{global.minimap.shown = false}")
    assertEqual(NS2.Launcher:IsShown(), false, "the button stays hidden")
    assertEqual(NS2.db.global.minimap.minimapPos, 200, "the drag is untouched")
    slash(NS2, lines, "set global.minimap.shown true")
    slash(NS2, lines, "set global.minimap.shown false")
    -- The raw SV, not the AceDB view: no `shown` key is ever stored (anti-pattern #81).
    assertNil(_G.AuraMasterDB.global.minimap.shown)
    assertEqual(_G.AuraMasterDB.global.minimap.hide, true)
    assertEqual(_G.AuraMasterDB.global.minimap.minimapPos, 200)
end)

-- ── the degradation stub ──────────────────────────────────────────────────────────────────────

--- The degraded environment, initialized so it has a database and containers.
local function degraded()
    local NS2, mocks = loadDegraded()
    rawset(_G, "AuraMasterDB", nil)
    NS2.addon:OnInitialize()
    return NS2, mocks
end

test("slash verbs: without the library each schema verb names what is missing, and writes nothing", function()
    local NS2, mocks = degraded()
    local lines = capture(mocks)
    for _, cmd in ipairs({ "list", "get alpha", "set alpha 0.5", "reset alpha" }) do
        local verb = cmd:match("^%a+")
        local p = slash(NS2, lines, cmd)
        -- red under: a stub Cli* verb answering nothing
        assertTrue(said(p, "/am " .. verb .. " is unavailable: the LibKa0s library did not load."), cmd .. ": " .. dump(p))
    end
    assertEqual(NS2.db.profile.alpha, 1)
end)

test("slash verbs: without the library /am set on a composed row or a writeThrough path prints the one line and writes nothing", function()
    local NS2, mocks = degraded()
    local lines = capture(mocks)
    local c = NS2.ActiveContainer()
    local alpha = c.bars.barAlpha
    -- The degraded printer names the missing library once, on the first line it ever prints
    -- (core/CoreSetup.lua); spend it here so each line below stands alone.
    slash(NS2, lines, "containers")
    -- A composed row (the Bars page's BarGroup) that this build never registered, and the master
    -- switch that the host verbs still reach through writeThrough: `/am set` is the library's verb,
    -- so both answer the library-absent line (options-ui-§1), exactly once and alone.
    for _, cmd in ipairs({ "set container.bars.barAlpha 0.5", "set enabled false" }) do
        local p = slash(NS2, lines, cmd)
        -- red under: the stub's CliSet reaching the seam
        assertEqual(dump(p), "{/am set is unavailable: the LibKa0s library did not load.}", cmd)
    end
    assertEqual(c.bars.barAlpha, alpha, "the composed row is unchanged")
    assertTrue(NS2.db.profile.enabled, "the switch is unchanged")
end)

test("slash verbs: without the library a bare /am still runs config, help prints the list, aliases route, and an unknown verb says so", function()
    local NS2, mocks = degraded()
    local opened = { 0 }
    NS2.OpenOptionsPanel = function() opened[1] = opened[1] + 1 end
    local lines = capture(mocks)
    -- red under: the stub's bare branch printing help rather than running `config` (slash-commands-§4)
    assertEqual(dump(slash(NS2, lines, "")), "{}", "a bare /am prints nothing of its own")
    assertEqual(dump(slash(NS2, lines, "  ")), "{}")
    assertEqual(opened[1], 2, "a bare and a whitespace-only /am both reach config")
    local p = slash(NS2, lines, "help")
    local head = 0
    for i, l in ipairs(p) do if l == "v" .. NS2.Version() .. " — slash commands" then head = i end end
    assertTrue(head > 0, "the stub's header: " .. dump(p))
    assertEqual(#p - head, #NS2.COMMANDS, "one row per verb after it")
    assertEqual(p[head + 1], "  /am help — List available commands")
    -- red under: the stub ignoring the descriptor's aliases
    NS2.Slash:OnSlash("options")
    assertEqual(opened[1], 3)
    p = slash(NS2, lines, "frob")
    assertEqual(p[1], "Unknown command 'frob'")
    assertEqual(#p, 1 + 1 + #NS2.COMMANDS, "then the help")
end)

test("slash verbs: without the library the host verbs keep working", function()
    local NS2, mocks = degraded()
    local lines = capture(mocks)
    NS2.Slash:OnSlash("select 2")
    -- red under: the stub's OnSlash not dispatching NS.COMMANDS
    assertEqual(NS2.State.activeContainerId, 2)
    NS2.Slash:OnSlash("debug on")
    assertTrue(NS2.State.debug)
    local p = slash(NS2, lines, "perf")
    assertTrue(said(p, NS2.LIBKA0S_MISSING .. ", so performance measurement is unavailable."), dump(p))
    NS2.SetByPath("alpha", 0.5)
    p = slash(NS2, lines, "resetall")
    assertEqual(NS2.db.profile.alpha, 1, "the stub's Reset all is a profile reset")
    assertEqual(p[#p], "All settings reset to defaults.")
end)

-- ── the disabled state (slash-commands-§2) ────────────────────────────────────────────────────
--
-- Disabled means the addon stands its FEATURES down. A verb that drives those features answers on
-- one tagged line naming `/am enable` and does nothing else; everything a player needs to read and
-- repair settings, and to reach the panel, keeps answering. The gate is the LIBRARY's, closed by the
-- descriptor's `isEnabled` (settings/Slash.lua), so these cases drive the real dispatcher.
--
-- The line is the collection's, not this addon's: `<BrandName> is disabled — enable it with
-- /<slash> enable`, built by LibKa0s-Slash-1.0 from `brandName` and `slash`.

local REFUSAL = "Ka0s Aura Master is disabled — enable it with /am enable"

test("slash verbs: while disabled every feature verb refuses on ONE line naming /am enable, and acts on nothing",
function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)

    -- The state each of these verbs would move if it acted.
    local id = NS2.Database.GetContainers()[1].id
    NS2.SetByPath("container.position.x", 123, id)
    NS2.SetByPath("locked", true)
    NS2.db.global.timedSpells[12345] = true
    local before = #NS2.Database.GetContainers()

    NS2.Slash:OnSlash("disable")
    assertFalse(NS2.GetSetting("enabled"))

    for _, line in ipairs({ "new target debuffs icons", "delete " .. id, "lock", "unlock", "pick",
                            "resetposition", "forgettimed" }) do
        local p = slash(NS2, lines, line)
        -- IT SAID SO, on one line and one only: no partial work, no second line explaining the
        -- state to a player who is about to re-run the command anyway.
        assertEqual(#p, 1, "/am " .. line .. " answered " .. dump(p))
        assertEqual(p[1], REFUSAL, "/am " .. line)
    end

    -- AND IT DID NOT ACT. Reading the message alone would pass over a verb that printed the line
    -- and then went ahead, which is the failure the gate exists to prevent.
    assertEqual(#NS2.Database.GetContainers(), before, "no container was created")
    assertTrue(NS2.Database.FindContainer(id) ~= nil, "and none was deleted")
    assertEqual(NS2.GetSetting("locked"), true, "the lock never moved")
    assertFalse(NS2.FramePicker.IsActive(), "the frame picker never started")
    assertEqual(NS2.Database.FindContainer(id).position.x, 123, "no position was reset")
    assertTrue(NS2.db.global.timedSpells[12345], "no learned buff was forgotten")
end)

test("slash verbs: while disabled the live set still answers — settings stay readable and repairable",
function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    local opened = 0
    NS2.OpenOptionsPanel = function() opened = opened + 1 end
    NS2.Slash:OnSlash("disable")

    -- red under: a gate turned on the whole command surface. Nothing on slash-commands-§2's live
    -- list may ever be refused — a player must be able to read and repair settings, and reach the
    -- panel, while the addon is off, which is exactly when they are most likely to need to.
    for _, line in ipairs({ "config", "version", "list", "get alpha", "set alpha 0.5",
                            "reset alpha", "debug", "debug off", "debug diag", "perf", "containers", "select 1" }) do
        local p = slash(NS2, lines, line)
        assertFalse(said(p, REFUSAL), "/am " .. line .. " must never be refused: " .. dump(p))
    end

    -- `help` is the one live verb that carries the line, and it is NOT a refusal OF help: the index
    -- prints in full, because the player has to be able to SEE `enable` to type it. The line sits
    -- under the header, above the first row, as a heading for the state the rows are read in.
    local help = slash(NS2, lines, "help")
    assertEqual(help[2], REFUSAL, "the line follows the help header")
    assertTrue(#help > 20, "and the whole index still prints: " .. dump(help))
    assertEqual(opened, 1, "/am config still opens the panel")

    -- And `set` really WROTE: the point of keeping it live is repair, not a polite answer.
    NS2.Slash:OnSlash("set alpha 0.5")
    assertEqual(NS2.db.profile.alpha, 0.5)
    -- `enable` above all, or the pair is one-way.
    NS2.Slash:OnSlash("enable")
    assertTrue(NS2.db.profile.enabled)
end)

test("slash verbs: the disabled gate is ONE decision over the whole verb table, not a per-verb guard",
function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    -- slash-commands-§2's live list, plus the two this addon keeps live because almost every schema
    -- path here is container-relative: `containers` and `select` are how a player aims get, set and
    -- reset at the container they mean, so they read and repair settings rather than drive features.
    local LIVE = {
        help = true, config = true, version = true, enable = true, disable = true,
        debug = true, perf = true, get = true, set = true, list = true, reset = true,
        resetall = true, containers = true, select = true,
    }
    for _, entry in ipairs(NS2.COMMANDS) do
        NS2.SetByPath("enabled", false)
        local p = slash(NS2, lines, entry[1])
        -- red under: a verb added to NS.COMMANDS with no thought about the disabled state. The gate
        -- is the library's one decision over `liveVerbs`, so a new verb lands on the refusing side
        -- by default and keeping it live is a deliberate edit to one named list.
        -- `help` prints the line under its header in EITHER direction of this assertion, and that
        -- is not a refusal: the index prints in full beneath it. The case above pins that shape.
        if entry[1] ~= "help" then
            assertEqual(said(p, REFUSAL), not LIVE[entry[1]], "/am " .. entry[1] .. ": " .. dump(p))
        end
    end
end)

test("slash verbs: /am new enchants makes a player buff container showing only Weapon enchants (feedback #6)", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    slash(NS2, lines, "new target enchants icons")
    local _, id = NS2.ActiveContainer()
    local c = NS2.Database.FindContainer(id)
    -- red under: the word still writing the retired ENCHANT aura type
    assertEqual(c.auraType, "HELPFUL")
    -- red under: the unit word honored (enchants are only ever the player's)
    assertEqual(c.unit, "player")
    assertEqual(c.style, "icons")
    assertEqual(c.filter.categories.weaponEnchants, "show")
    assertEqual(c.filter.categories.defensives, "hide")
    assertEqual(c.filter.categories.uncategorized, "hide")
    NS2.Slash:OnSlash("new debuffs enchants")
    _, id = NS2.ActiveContainer()
    -- red under: an aura-type word beating the enchants word (a debuff container cannot show enchants)
    assertEqual(NS2.Database.FindContainer(id).auraType, "HELPFUL", "enchants are the player's buffs")
end)
