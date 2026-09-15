-- tests/test_bulklog.lua — debug-logging-§10's bulk rule, act by act. A bulk copy or reset through the
-- write seam is ONE `[Set] <act> <scope>: N rows` line, N the rows it actually changed, with no per-row
-- `[Set]` line; a profile reset or copy is ONE line, from the profile-event handler, worded by the event.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")
local loadDegraded = dofile("tests/degraded_env.lua")
local unpack_ = unpack   -- Lua 5.1, as .luacheckrc's std and the harness are

-- The tags a bulk act could leak a line under: the seam's own, the profile trace, and the old
-- CopyFrom / ResetPositions summaries.
local TAGS = { Set = true, Profile = true, Containers = true }

--- Record every line logged under TAGS, rendered `[Tag] text`, with debug on.
local function capture(NS2)
    NS2.State.debug = true
    local lines = {}
    NS2.Debug = function(tag, fmt, ...)
        if not TAGS[tag] then return end
        local n, args = select("#", ...), { ... }
        for i = 1, n do args[i] = tostring(args[i]) end
        lines[#lines + 1] = ("[%s] %s"):format(tag, fmt:format(unpack_(args, 1, n)))
    end
    return lines
end

local function dump(lines) return "{" .. table.concat(lines, " | ") .. "}" end

-- A profile reset's one line carries no row count (debug-logging-§10 allows omitting it): the reset
-- re-seeds the starter containers, so "rows not at default" would overcount, and AceDB gives no hook
-- before the wipe to take that count from.
local RESET_LINE = "[Set] reset profile 'Default' to defaults"

--- The schema row at `path`, so a case can give it a raising onChange.
local function rowAt(NS2, path)
    for _, row in ipairs(NS2.Schema) do
        if row.path == path then return row end
    end
end

-- ── the library's walks: Options RestoreDefaults / RestoreAllDefaults, Slash CliResetAll ─────────

test("bulklog: a container page's Defaults is one [Set] line counting the rows it changed", function()
    local NS2 = fresh()
    NS2.State.SetActiveContainer(1)
    NS2.Helpers.RestoreDefaults("bars")               -- settle: every bars row at its default
    NS2.SetByPath("container.bars.width", 300, 1)
    NS2.SetByPath("container.bars.height", 30, 1)
    local config = { 0 }
    NS2.NewBusTarget():RegisterMessage(NS2.MSG.CONFIG_CHANGED, function() config[1] = config[1] + 1 end)
    local lines = capture(NS2)
    NS2.Helpers.RestoreDefaults("bars")
    -- red under: the seam logging one [Set] per row the walk writes
    assertEqual(#lines, 1, dump(lines))
    assertEqual(lines[1], "[Set] reset bars: 2 rows")
    local c = NS2.Database.FindContainer(1)
    assertEqual(c.bars.width, NS2.CONTAINER_TEMPLATE.bars.width, "the rows are still written")
    assertEqual(c.bars.height, NS2.CONTAINER_TEMPLATE.bars.height)
    assertTrue(config[1] >= 2, "each row still announces: only the log collapses")
    -- A row already at its default is not counted (debug-logging-§10's N).
    NS2.Helpers.RestoreDefaults("bars")
    assertEqual(#lines, 2, dump(lines))
    assertEqual(lines[2], "[Set] reset bars: 0 rows")
end)

test("bulklog: General's Defaults is one [Set] line counting the rows it changed", function()
    local NS2 = fresh()
    NS2.Helpers.RestoreDefaults("general")
    NS2.SetByPath("hideBlizzardBuffs", true)
    NS2.SetByPath("alpha", 0.5)
    local lines = capture(NS2)
    NS2.Helpers.RestoreDefaults("general")
    assertEqual(#lines, 1, dump(lines))
    assertEqual(lines[1], "[Set] reset general: 2 rows")
    assertFalse(NS2.db.profile.hideBlizzardBuffs)
end)

test("bulklog: Reset all, from /am resetall or the General popup, is one line in total — the profile handler's", function()
    local surfaces = {
        function(NS2) NS2.Slash:OnSlash("resetall") end,
        function(_, mocks) mocks.StaticPopupDialogs.AURAMASTER_RESET_ALL.OnAccept() end,
    }
    for i, surface in ipairs(surfaces) do
        local NS2, mocks = fresh()
        NS2.ContainerManager.Create({ name = "Extra" })
        NS2.SetByPath("state.preview", true)          -- a session row the walk writes, muted
        NS2.SetByPath("container.bars.width", 300, 1)
        local lines = capture(NS2)
        surface(NS2, mocks)
        -- red under: bulkEnd adding its own line beside the handler's, or the session row's [Set]
        assertEqual(#lines, 1, "surface " .. i .. ": " .. dump(lines))
        -- red under: the line carrying a count of every row the profile stores
        assertEqual(lines[1], RESET_LINE, "surface " .. i)
        assertFalse(NS2.State.preview, "the session row is still reset")
    end
end)

test("bulklog: the degraded build's Reset all is one line in total, too", function()
    local NS2 = loadDegraded()
    rawset(_G, "AuraMasterDB", nil)
    NS2.addon:OnInitialize()
    NS2.SetByPath("state.preview", true)
    local lines = capture(NS2)
    NS2.Helpers.RestoreAllDefaults()
    -- red under: the stub's own loop logging the session row, or a bulk line beside the handler's
    assertEqual(#lines, 1, dump(lines))
    assertEqual(lines[1], RESET_LINE)
    assertFalse(NS2.State.preview)
end)

test("bulklog: Slash's CliResetAll, handed the same pair, is one [Set] reset all line", function()
    local NS2 = fresh()
    local cli = NS2.Slash.__cli
    cli:CliResetAll()                                -- settle: every row at its default
    NS2.SetByPath("alpha", 0.5)
    NS2.SetByPath("container.bars.width", 300)
    local lines = capture(NS2)
    cli:CliResetAll()
    assertEqual(#lines, 1, dump(lines))
    assertEqual(lines[1], "[Set] reset all: 2 rows")
end)

-- ── the profile handlers: worded by the event ───────────────────────────────────────────────────

test("bulklog: a profile reset and a profile copy are one [Set] line each; a switch keeps its trace", function()
    local NS2 = fresh()
    local lines = capture(NS2)
    NS2.db:SetProfile("Raid")
    assertEqual(#lines, 1, dump(lines))
    assertEqual(lines[1], "[Profile] changed -> Raid", "a switch rewrites no rows and keeps its tag")
    NS2.db:SetProfile("Default")

    lines = capture(NS2)
    NS2.db:ResetProfile()
    -- red under: the three AceDB callbacks sharing the one [Profile] changed line
    assertEqual(#lines, 1, dump(lines))
    assertEqual(lines[1], RESET_LINE)
    -- A reset that changes nothing reads the same: the line never claims a count it cannot know.
    lines = capture(NS2)
    NS2.db:ResetProfile()
    assertEqual(#lines, 1, dump(lines))
    assertEqual(lines[1], RESET_LINE)

    lines = capture(NS2)
    NS2.db:CopyProfile("Raid")
    assertEqual(#lines, 1, dump(lines))
    assertTrue(lines[1]:find("^%[Set%] copied profile '.-' %-> 'Default'$") ~= nil, lines[1])
    -- Since kit revision 18 the kit's AceDB passes OnProfileCopied the SOURCE, as AceDB proper
    -- does, so the line above reads 'Raid' -> 'Default'; the pattern above does not pin the source.
    -- The handler's own contract, called directly with a source:
    lines = capture(NS2)
    NS2.OnProfileCopied("Raid")
    assertEqual(lines[1], "[Set] copied profile 'Raid' -> 'Default'")
end)

-- ── the host's own bulk acts ───────────────────────────────────────────────────────────────────

test("bulklog: CopyFrom is one [Set] line counting the rows it changed, and no [Containers] summary", function()
    local NS2 = fresh()
    local CM = NS2.ContainerManager
    assertTrue(CM.CopyFrom(2, 1))                     -- settle: the two agree on all a copy writes
    local src = NS2.Database.FindContainer(2)
    src.bars.width, src.bars.height = 333, 27
    local lines = capture(NS2)
    assertTrue(CM.CopyFrom(2, 1, "bars"))
    -- red under: one [Set] per section write plus the [Containers] copied summary
    assertEqual(#lines, 1, dump(lines))
    assertEqual(lines[1], "[Set] copy container 2->1 (bars): 2 rows")

    src.bars.width, src.icons.width = 334, 55
    lines = capture(NS2)
    assertTrue(CM.CopyFrom(2, 1))
    assertEqual(#lines, 1, dump(lines))
    assertEqual(lines[1], "[Set] copy container 2->1 (all): 2 rows")
    assertEqual(NS2.Database.FindContainer(1).icons.width, 55, "the rows are still written")
end)

test("bulklog: a refused CopyFrom logs nothing", function()
    local NS2 = fresh()
    NS2.Database.FindContainer(2).filter.whitelist = "garbage"
    local lines = capture(NS2)
    assertFalse((NS2.ContainerManager.CopyFrom(2, 1, "filter")))
    assertEqual(#lines, 0, dump(lines))
end)

test("bulklog: ResetPositions is one [Set] line counting the rows it changed", function()
    local NS2 = fresh()
    local CM = NS2.ContainerManager
    CM.ResetPositions()                              -- settle
    local c1 = NS2.Database.FindContainer(1)
    c1.position.x = 500
    c1.attach.mode = "frame"
    local lines = capture(NS2)
    CM.ResetPositions()
    -- red under: one [Set] per container's position section plus the [Containers] summary
    assertEqual(#lines, 1, dump(lines))
    assertEqual(lines[1], "[Set] reset positions: 2 rows")
    assertEqual(c1.position.x, 0)
    assertEqual(c1.attach.mode, "screen")
end)

test("bulklog: a bracket inside a bracket logs once, summed, when the outer one closes", function()
    local NS2 = fresh()
    NS2.State.SetActiveContainer(1)
    NS2.Helpers.RestoreDefaults("bars")
    NS2.Helpers.RestoreDefaults("icons")
    NS2.SetByPath("container.bars.width", 300, 1)
    NS2.SetByPath("container.icons.width", 77, 1)
    local lines = capture(NS2)
    NS2.Bulk.Run("reset", "outer", function()
        NS2.Helpers.RestoreDefaults("bars")
        NS2.Helpers.RestoreDefaults("icons")
    end)
    -- red under: each level logging at its own close rather than at depth 0
    assertEqual(#lines, 1, dump(lines))
    assertEqual(lines[1], "[Set] reset outer: 2 rows")
    -- A profile reset at any level silences the bracket: the handler's line is the only one.
    lines = capture(NS2)
    NS2.Bulk.Run("reset", "outer", function() NS2.Helpers.RestoreAllDefaults() end)
    assertEqual(#lines, 1, dump(lines))
    assertEqual(lines[1], RESET_LINE)
end)

test("bulklog: a -0 stored over 0 is not a change, so a settled ResetPositions counts none", function()
    local NS2 = fresh()
    local CM = NS2.ContainerManager
    CM.ResetPositions()                              -- settle
    for _, c in ipairs(NS2.Database.GetContainers()) do
        -- A plain 0 where the stagger writes -(i-1)*30, which is -0 for the first container.
        if c.position.y == 0 then c.position.y = 0 end
    end
    local lines = capture(NS2)
    CM.ResetPositions()
    -- red under: numbers compared by their tostring, where "-0" ~= "0"
    assertEqual(#lines, 1, dump(lines))
    assertEqual(lines[1], "[Set] reset positions: 0 rows")
end)

test("bulklog: a bulk act that raises still logs its one line, marked, and the seam logs again", function()
    local NS2 = fresh()
    NS2.SetByPath("alpha", 1)
    local lines = capture(NS2)
    local ok, err = pcall(NS2.Bulk.Run, "copy", "test", function()
        NS2.SetByPath("alpha", 0.5)                  -- stored, so counted
        error("boom", 0)
    end)
    assertFalse(ok)
    assertEqual(err, "boom", "the raised value comes back unchanged")
    -- red under: the bracket closing silently, or unmarked, on an error
    assertEqual(#lines, 1, dump(lines))
    assertEqual(lines[1], "[Set] copy test: 1 rows (stopped by an error)")
    NS2.SetByPath("alpha", 0.75)
    assertEqual(#lines, 2, dump(lines))
    assertEqual(lines[2], "[Set] alpha = 0.75", "the mute is released")
end)

-- ── the bracket's own mechanics (settings/Schema.lua's NS.Bulk) ───────────────────────────────

test("bulklog: a stray bulkEnd with no bracket open logs nothing, and the next bracket still counts itself", function()
    local NS2 = fresh()
    local lines = capture(NS2)
    NS2.Bulk.End("reset", "stray", 5, nil, nil)
    -- red under: Bulk.End without its depth == 0 guard (it logs, and the depth goes negative)
    assertEqual(#lines, 0, dump(lines))
    NS2.Bulk.Begin()
    NS2.SetByPath("alpha", 0.5)
    -- red under: N taken from bulkEnd's `count` (99) rather than the seam's own tally
    NS2.Bulk.End("reset", "real", 99)
    assertEqual(dump(lines), "{[Set] reset real: 1 rows}")
end)

test("bulklog: a spell set written in a bracket counts once when it changed and not at all when it did not", function()
    local NS2 = fresh()
    NS2.SetByPath("container.filter.whitelist", {}, 1)   -- settle
    NS2.SetByPath("container.filter.blacklist", {}, 1)
    local lines = capture(NS2)
    NS2.Bulk.Run("copy", "sets", function()
        NS2.SetByPath("container.filter.whitelist", { [5] = true }, 1)
        NS2.SetByPath("container.filter.whitelist", { [5] = true }, 1)   -- the same set again
        NS2.SetByPath("container.filter.blacklist", {}, 1)                -- already empty
    end)
    -- red under: writeCarveOut not tallying (0), or tallying every write whether it changed or not (3)
    assertEqual(dump(lines), "{[Set] copy sets: 1 rows}")
end)

test("bulklog: a section written in a bracket counts each row and spell set under it that changed, and its own line is muted", function()
    local NS2 = fresh()
    NS2.SetByPath("container.filter", {}, 1)            -- settle: the template's filter
    local lines = capture(NS2)
    NS2.Bulk.Run("copy", "section", function()
        NS2.SetByPath("container.filter", { castBy = "mine", whitelist = { [7] = true } }, 1)
    end)
    -- red under: countSectionChanges skipping the carve-outs (1), or logSection ignoring the bracket
    assertEqual(dump(lines), "{[Set] copy section: 2 rows}")
end)

test("bulklog: a session row written in a bracket is counted through its own get", function()
    local NS2 = fresh()
    NS2.SetByPath("state.preview", false)
    local lines = capture(NS2)
    NS2.Bulk.Run("reset", "session", function()
        NS2.SetByPath("state.preview", true)
        NS2.SetByPath("state.preview", true)             -- no change: get() already answers true
    end)
    -- red under: rowChanges reading the profile for a session row, or tallying unchanged writes
    assertEqual(dump(lines), "{[Set] reset session: 1 rows}")
    NS2.SetByPath("state.preview", false)
end)

test("bulklog: each act starts its own count and its own error mark", function()
    local NS2 = fresh()
    NS2.SetByPath("alpha", 1)
    local lines = capture(NS2)
    pcall(NS2.Bulk.Run, "copy", "first", function()
        NS2.SetByPath("alpha", 0.5)
        error("boom", 0)
    end)
    NS2.Bulk.Run("copy", "second", function() NS2.SetByPath("alpha", 0.25) end)
    -- red under: Bulk.Begin at depth 0 not resetting `rows` (2) or `failed` (the second line marked)
    assertEqual(dump(lines), "{[Set] copy first: 1 rows (stopped by an error) | [Set] copy second: 1 rows}")
end)

test("bulklog: an error inside a nested bracket marks the outer act's one line", function()
    local NS2 = fresh()
    NS2.SetByPath("alpha", 1)
    local lines = capture(NS2)
    NS2.Bulk.Begin()
    NS2.Bulk.Begin()
    NS2.SetByPath("alpha", 0.5)
    NS2.Bulk.End("reset", "inner", nil, "boom")
    assertEqual(#lines, 0, "the inner level logs nothing: " .. dump(lines))
    NS2.Bulk.End("reset", "outer")
    -- red under: the failure flag recorded only by the level that logs
    assertEqual(dump(lines), "{[Set] reset outer: 1 rows (stopped by an error)}")
end)

test("bulklog: Bulk.Run stays silent only when its act answers true, the profile reset's signal", function()
    local NS2 = fresh()
    NS2.SetByPath("alpha", 1)
    local lines = capture(NS2)
    NS2.Bulk.Run("reset", "whole", function()
        NS2.SetByPath("alpha", 0.5)
        return true
    end)
    -- red under: Run ignoring fn's return (the act logs beside the profile handler's line)
    assertEqual(#lines, 0, dump(lines))
    assertEqual(NS2.db.profile.alpha, 0.5, "the write still happened, muted")
    NS2.Bulk.Run("reset", "truthy", function()
        NS2.SetByPath("alpha", 0.25)
        return 1
    end)
    -- red under: `fn() == true` loosened to a truthiness test
    assertEqual(dump(lines), "{[Set] reset truthy: 1 rows}")
end)

test("bulklog: a library Defaults a row's onChange stops counts the write it stored", function()
    local NS2 = fresh()
    NS2.State.SetActiveContainer(1)
    NS2.Helpers.RestoreDefaults("bars")               -- settle: every bars row at its default
    NS2.Database.FindContainer(1).bars.width = 300    -- the one row off its default
    rowAt(NS2, "container.bars.width").onChange = function() error("boom", 0) end
    local lines = capture(NS2)
    local ok, err = pcall(NS2.Helpers.RestoreDefaults, "bars")
    assertFalse(ok)
    assertTrue(tostring(err):find("boom") ~= nil, "the library re-raises: " .. tostring(err))
    assertEqual(NS2.Database.FindContainer(1).bars.width, NS2.CONTAINER_TEMPLATE.bars.width,
        "the write was stored before onChange raised")
    -- red under: the tally taken after onChange, which never returned
    assertEqual(#lines, 1, dump(lines))
    assertEqual(lines[1], "[Set] reset bars: 1 rows (stopped by an error)")
end)
