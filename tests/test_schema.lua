-- tests/test_schema.lua — settings/Schema.lua: the rows, the container-relative path model and the
-- single write seam.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local NS = T.NS
local fresh = dofile("tests/fresh_env.lua")
local loadDegraded = dofile("tests/degraded_env.lua")
--- An environment in `build`: "live" is fresh(), with LibKa0s-Schema's instance under the rows;
--- "degraded" loads without LibKa0s and runs OnInitialize, so the host arms (ValidateSchema's loop, the
--- host index) answer. A case the library took over runs in both, so the fallback stays pinned (#21).
local function inBuild(build)
    if build == "live" then return fresh() end
    local NS2 = loadDegraded()
    rawset(_G, "AuraMasterDB", nil)
    NS2.addon:OnInitialize()
    return NS2
end

-- ── the rows ──────────────────────────────────────────────────────────────────────────────────

test("schema: every row validates against defaults/Profile.lua", function()
    assertEqual(NS.ValidateSchema(), 0)
end)

test("schema: the validator is falsifiable — an unresolvable path and a missing group each fail", function()
    -- red under: ValidateSchema no longer resolving paths, or no longer checking `group` — in
    -- either build: the live one runs LibKa0s-Schema's Validate, the degraded one the host loop.
    for _, build in ipairs({ "live", "degraded" }) do
        local NS2 = inBuild(build)
        local printed = {}
        NS2.Print = function(line)
            printed[#printed + 1] = line
        end
        assertEqual(NS2.ValidateSchema(), 0, build .. ": clean before the bad rows")
        NS2.RegisterSchemaRows({
            { path = "container.bars.noSuchLeaf", page = "bars", group = "Size", type = "number" },
            -- A path no shipped row has: LibKa0s-Schema's Validate would also count a duplicate (#21).
            { path = "container.filter.whitelist", page = "bars", type = "number" },
        })
        assertEqual(NS2.ValidateSchema(), 2, build)
        if build == "degraded" then
            assertEqual(table.concat(printed, " | "),
                "schema error: container.bars.noSuchLeaf: path does not resolve against defaults/Profile.lua"
                .. " | schema error: container.filter.whitelist: no group")
        end
    end
end)

test("schema: no path is registered twice", function()
    local seen = {}
    for _, row in ipairs(NS.Schema) do
        assertNil(seen[row.path], "duplicate schema path " .. tostring(row.path))
        seen[row.path] = true
    end
end)

test("schema: every row has a label and a group (a row without a group belongs to no tab)", function()
    for _, row in ipairs(NS.Schema) do
        assertTrue(type(row.label) == "string" and row.label ~= "", "no label on " .. row.path)
        assertTrue(type(row.group) == "string" and row.group ~= "", "no group on " .. row.path)
    end
end)

test("schema: a row's default comes from the template, never from a composer", function()
    assertEqual(NS.FindSchemaRow("container.bars.width").default, NS.CONTAINER_TEMPLATE.bars.width)
    -- The composer's own fontSize default is 12; the bar name text ships at 11.
    assertEqual(NS.FindSchemaRow("container.bars.name.fontSize").default, NS.CONTAINER_TEMPLATE.bars.name.fontSize)
    assertEqual(NS.FindSchemaRow("locked").default, NS.defaults.profile.locked)
end)

-- Palette definitions — one color per dispel type or per state — are options-ui-§17's one
-- exemption from the class-color companion.
local function isPalette(path)
    return path:find("^dispelColors%.") or path:find("%.expiringColor$") or path:find("%.pandemicColor$")
end

test("schema: every color row has its class-color companion next to it, or is a palette swatch", function()
    local rows = NS.Schema
    local checked = 0
    for i, row in ipairs(rows) do
        -- anti-pattern #74: a swatch is still read for its alpha, so it is never grayed. Other rows
        -- may dim (Layout's Anchor subsections do); a color row may not.
        if row.type == "color" then
            assertNil(row.disabledIf, "disabledIf is forbidden on a color row: " .. row.path)
        end
        if row.type == "color" and not isPalette(row.path) then
            local nxt = rows[i + 1]
            assertTrue(nxt and nxt.type == "bool" and nxt.path:find("useClassColor"),
                "no class-color companion after " .. row.path)
            -- A container's colors describe what the container tracks, so they take its unit's
            -- class (options-ui-§17); a color outside any container stays the player's.
            local whose = row.path:find("^container%.") and "unit" or "player"
            assertEqual(row.classColorSource, whose, "whose class " .. row.path .. " means")
            checked = checked + 1
        end
    end
    assertTrue(checked >= 10, "the walk found only " .. checked .. " companion pairs")
end)

test("schema: every category of both lists is a row, offered only for its aura type", function()
    for _, auraType in ipairs({ "HELPFUL", "HARMFUL" }) do
        for _, def in ipairs(NS.Categories.For(auraType)) do
            local row = NS.FindSchemaRow("container.filter.categories." .. def.key)
            assertTrue(row ~= nil, "no row for category " .. def.key)
            assertTrue(row.auraTypes[auraType], def.key .. " is offered for " .. auraType)
        end
    end
end)

test("schema: the Filters page offers the active container's categories and no others", function()
    local NS2 = fresh()
    local function has(path)
        for _, r in ipairs(NS2.SchemaForPage("filters")) do if r.path == path then return true end end
        return false
    end
    NS2.State.SetActiveContainer(1)   -- Player buffs
    assertTrue(has("container.filter.categories.defensives"))
    assertFalse(has("container.filter.categories.crowdControl"))
    NS2.State.SetActiveContainer(2)   -- Player debuffs
    assertTrue(has("container.filter.categories.crowdControl"))
    assertFalse(has("container.filter.categories.defensives"))
end)

-- ── the path model ────────────────────────────────────────────────────────────────────────────

test("schema: a container path writes the selected container and no other", function()
    local NS2 = fresh()
    NS2.State.SetActiveContainer(2)
    assertTrue(NS2.SetByPath("container.bars.width", 300))
    assertEqual(NS2.Database.FindContainer(2).bars.width, 300)
    assertEqual(NS2.Database.FindContainer(1).bars.width, NS2.CONTAINER_TEMPLATE.bars.width)
    assertEqual(NS2.GetSetting("container.bars.width"), 300)
end)

test("schema: an explicit container id overrides the selection", function()
    local NS2 = fresh()
    NS2.State.SetActiveContainer(1)
    NS2.SetByPath("container.bars.width", 111, 3)
    assertEqual(NS2.Database.FindContainer(3).bars.width, 111)
    assertEqual(NS2.GetSetting("container.bars.width", 3), 111)
    assertEqual(NS2.Database.FindContainer(1).bars.width, NS2.CONTAINER_TEMPLATE.bars.width)
end)

test("schema: with nothing selected, a container path means the first container", function()
    local NS2 = fresh()
    NS2.State.SetActiveContainer(nil)
    NS2.SetByPath("container.bars.height", 30)
    assertEqual(NS2.Database.FindContainer(1).bars.height, 30)
end)

test("schema: a container write with no containers refuses, naming why", function()
    local NS2 = fresh()
    for _, c in ipairs(NS2.Database.GetContainers()) do NS2.ContainerManager.Delete(c.id) end
    local ok, err = NS2.SetByPath("container.bars.width", 300)
    assertFalse(ok)
    assertTrue(tostring(err):find("No container", 1, true) ~= nil)
end)

test("schema: an unknown path refuses", function()
    assertFalse((NS.SetByPath("container.bars.noSuchLeaf", 1)))
end)

test("schema: every write announces CONFIG_CHANGED once, naming the container", function()
    local NS2 = fresh()
    local got = {}
    local rx = NS2.NewBusTarget()
    rx:RegisterMessage(NS2.MSG.CONFIG_CHANGED, function(_, payload)
        got[#got + 1] = payload
    end)
    NS2.State.SetActiveContainer(3)
    NS2.SetByPath("container.icons.width", 40)
    assertEqual(#got, 1)
    assertEqual(got[1].containerId, 3)
    assertEqual(got[1].section, "icons")
    assertEqual(got[1].path, "container.icons.width")
    NS2.SetByPath("alpha", 0.5)
    assertNil(got[2].containerId, "an addon-wide row names no container")
end)

test("schema: a failed validation writes nothing", function()
    local NS2 = fresh()
    local before = NS2.Database.FindContainer(1).name
    assertFalse((NS2.SetByPath("container.name", "   ", 1)))
    assertEqual(NS2.Database.FindContainer(1).name, before)
end)

test("schema: renaming to a taken name through the seam stores a unique, trimmed name", function()
    local NS2 = fresh()
    assertTrue(NS2.SetByPath("container.name", "  Player debuffs ", 1))
    -- red under: dropping the name row's normalize
    assertEqual(NS2.Database.FindContainer(1).name, "Player debuffs (2)")
    assertEqual(NS2.Database.FindContainer(2).name, "Player debuffs", "the holder keeps its name")
end)

test("schema: a session row is stored by its own set, never in the profile", function()
    local NS2 = fresh()
    NS2.SetByPath("state.debugConsole", true)
    assertTrue(NS2.DebugLog:IsShown())
    assertEqual(NS2.GetSetting("state.debugConsole"), true)
    -- red under: SetByPath writing session rows into the profile (dropping the sessionOnly branch)
    assertNil(NS2.db.profile.state)
    NS2.SetByPath("state.debugConsole", false)
end)

test("schema: a session row announces no CONFIG_CHANGED and queues no apply", function()
    local NS2, mocks = fresh()
    local CM = NS2.ContainerManager
    local requests, orig = { 0 }, CM.RequestApply
    CM.RequestApply = function(...) requests[1] = requests[1] + 1; return orig(...) end
    local announced = { 0 }
    NS2.NewBusTarget():RegisterMessage(NS2.MSG.CONFIG_CHANGED, function() announced[1] = announced[1] + 1 end)
    assertTrue(NS2.SetByPath("state.debugConsole", true))
    mocks.__fireTimers()
    -- red under: announceWrite sending for sessionOnly rows
    assertEqual(announced[1], 0, "a session row is not a setting")
    assertEqual(requests[1], 0, "and re-applies no container")
    NS2.SetByPath("state.debugConsole", false)
end)

test("schema: ApplyDefault restores the shipped value without sharing a table", function()
    local NS2 = fresh()
    NS2.State.SetActiveContainer(1)
    NS2.SetByPath("container.bars.barColor", { r = 0, g = 0, b = 0, a = 0 })
    NS2.ApplyDefault(NS2.FindSchemaRow("container.bars.barColor"))
    local stored = NS2.Database.FindContainer(1).bars.barColor
    assertEqual(stored.r, NS2.CONTAINER_TEMPLATE.bars.barColor.r)
    stored.r = 0.42
    assertTrue(NS2.CONTAINER_TEMPLATE.bars.barColor.r ~= 0.42, "the template is untouched")
end)

-- ── the carve-outs ────────────────────────────────────────────────────────────────────────────

test("schema: a spell set is written whole and normalized to positive integer ids", function()
    local NS2 = fresh()
    NS2.State.SetActiveContainer(1)
    assertTrue(NS2.SetByPath("container.filter.whitelist",
        { ["12"] = true, [0] = true, [-3] = true, [4.5] = true, [99] = false, [7] = true, x = true }))
    local set = NS2.Database.FindContainer(1).filter.whitelist
    local ids = {}
    for id in pairs(set) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    assertEqual(table.concat(ids, ","), "7,12")
    assertFalse((NS2.SetByPath("container.filter.blacklist", "12")), "a non-set is refused")
end)

test("schema: a carve-out's refusal is the locale's sentence", function()
    local NS2 = fresh()
    -- The case's own environment: its locale table is rebuilt per case, so these stand-ins end here.
    rawset(NS2.L, "Expected a set of spell ids", "ID SET REFUSED")
    rawset(NS2.L, "Expected per-category spell edits", "EDITS REFUSED")
    local ok, err = NS2.SetByPath("container.filter.whitelist", "x", 1)
    assertFalse(ok)
    -- red under: normalizeIdSet returning an English literal instead of its L key
    assertEqual(err, "ID SET REFUSED")
    ok, err = NS2.SetByPath("categorySpells", 5)
    assertFalse(ok)
    -- red under: normalizeCategoryEdits returning an English literal instead of its L key
    assertEqual(err, "EDITS REFUSED")
end)

test("schema: category spell edits keep only real spell categories", function()
    local NS2 = fresh()
    NS2.SetByPath("categorySpells", {
        defensives = { [1] = false, ["2"] = true },
        crowdControl = { [3] = true },   -- a token category: no editable spells
        nonsense = { [4] = true },
    })
    local edits = NS2.db.profile.categorySpells
    assertEqual(edits.defensives[1], false)
    assertEqual(edits.defensives[2], true)
    assertNil(edits.crowdControl)
    assertNil(edits.nonsense)
end)

test("schema: the spell lists are one profile-wide set at the absolute path categorySpells (schema v2)", function()
    local NS2 = fresh()
    -- red under: the carve-out still keyed container.filter.categorySpells
    assertTrue(NS2.SetByPath("categorySpells", { defensives = { [871] = false } }))
    assertEqual(NS2.db.profile.categorySpells.defensives[871], false)
    for _, c in ipairs(NS2.Database.GetContainers()) do
        assertNil(c.filter.categorySpells, "container " .. c.id .. " keeps no copy")
    end
    assertFalse((NS2.SetByPath("container.filter.categorySpells", {})), "the v1 per-container path is gone")
end)

test("schema: the validator resolves the profile-wide sets, and the dispel swatches are profile rows", function()
    assertEqual(type(NS.DefaultFor("categorySpells")), "table")
    assertEqual(type(NS.DefaultFor("dispelColors.Magic")), "table")
    for _, name in ipairs(NS.Constants.DISPEL_TYPES) do
        -- red under: the swatches left on container.bars.dispelColors (a path the template lost)
        assertTrue(NS.FindSchemaRow("dispelColors." .. name) ~= nil, name)
        assertNil(NS.FindSchemaRow("container.bars.dispelColors." .. name), name)
    end
end)

-- ── whole-section writes ──────────────────────────────────────────────────────────────────────

test("schema: a whole section written through the seam replaces it, backfills it, logs once and announces once", function()
    local NS2 = fresh()
    NS2.State.debug = true
    local lines = {}
    NS2.Debug = function(tag, fmt, ...)
        if tag == "Set" then
            lines[#lines + 1] = fmt:format(...)
        end
    end
    local got = {}
    NS2.NewBusTarget():RegisterMessage(NS2.MSG.CONFIG_CHANGED, function(_, p)
        got[#got + 1] = p
    end)
    local given = { point = "TOP", x = 5 }
    assertTrue(NS2.SetByPath("container.position", given, 1))
    NS2.State.debug = false
    local pos = NS2.Database.FindContainer(1).position
    assertTrue(pos ~= given, "stored as a copy, never the caller's table")
    assertEqual(pos.point, "TOP")
    assertEqual(pos.x, 5)
    assertEqual(pos.y, NS2.CONTAINER_TEMPLATE.position.y, "y backfilled from the template")
    assertEqual(pos.relativePoint, NS2.CONTAINER_TEMPLATE.position.relativePoint, "relativePoint backfilled")
    assertEqual(#lines, 1, "one [Set] line per section write")
    assertTrue(lines[1]:find("x=5", 1, true) ~= nil, "the line renders the stored table: " .. lines[1])
    assertEqual(#got, 1, "one CONFIG_CHANGED")
    assertEqual(got[1].path, "container.position")
    assertEqual(got[1].containerId, 1)
    assertEqual(got[1].section, "layout")
end)

test("schema: a section write refuses a non-section path, a non-table, and a value a row rejects", function()
    local NS2 = fresh()
    assertTrue(NS2.IsSection("container.position"))
    assertFalse(NS2.IsSection("container.attach"))
    assertFalse((NS2.SetByPath("container.bars.name", { fontSize = 20 }, 1)), "not a section")
    assertFalse((NS2.SetByPath("container.position", 5, 1)), "not a table")
    local before = NS2.Database.FindContainer(1).filter
    -- red under: writeSection skipping the carve-out normalize
    assertFalse((NS2.SetByPath("container.filter", { whitelist = "x" }, 1)), "the carve-out rejects it")
    assertTrue(NS2.Database.FindContainer(1).filter == before, "the stored section is untouched")
    assertFalse((NS2.SetByPath("container.attach", { mode = "screen" }, 1)), "attach is not a section")
end)

test("schema: a section write runs the normalize hook of every row under it, with the target id", function()
    -- No shipped row under a section has a hook today; this plants one so a future row's is honored.
    local NS2 = fresh()
    local seenId
    for _, row in ipairs(NS2.Schema) do
        if row.path == "container.layout.spacing" then
            row.normalize = function(v, id) seenId = id; return v + 1 end
        end
    end
    assertTrue(NS2.SetByPath("container.layout", { spacing = 5 }, 2))
    -- red under: writeSection skipping the rows' normalize hooks
    assertEqual(NS2.Database.FindContainer(2).layout.spacing, 6, "stored normalized")
    assertEqual(seenId, 2, "the hook saw the section's container")
end)

test("schema: CheckWrite answers what SetByPath would, and stores and announces nothing", function()
    local NS2 = fresh()
    local c1 = NS2.Database.FindContainer(1)
    local width, list = c1.bars.width, c1.filter.whitelist
    local sent = { 0 }
    NS2.NewBusTarget():RegisterMessage(NS2.MSG.CONFIG_CHANGED, function() sent[1] = sent[1] + 1 end)
    assertTrue(NS2.CheckWrite("container.bars", { width = 222 }, 1), "a section the seam takes")
    assertTrue(NS2.CheckWrite("container.unit", "focus", 1), "a row the seam takes")
    assertTrue(NS2.CheckWrite("container.filter.whitelist", { [123] = true }, 1), "a spell set")
    assertFalse((NS2.CheckWrite("container.icons", "garbage", 1)), "a section that is not a table")
    assertFalse((NS2.CheckWrite("container.filter.whitelist", "x", 1)), "a set the carve-out refuses")
    assertFalse((NS2.CheckWrite("container.name", "   ", 1)), "a value the row refuses")
    assertFalse((NS2.CheckWrite("container.bars", {}, 99)), "no such container")
    assertFalse((NS2.CheckWrite("no.such.path", 1)), "no such setting")
    -- red under: CheckWrite storing through writeSection or writeRow
    assertEqual(c1.bars.width, width, "nothing is stored")
    assertEqual(c1.unit, "player")
    assertTrue(c1.filter.whitelist == list)
    assertEqual(sent[1], 0, "and nothing is announced")
end)

test("schema: a row's own refusal reason travels as the third return of SetByPath and CheckWrite", function()
    local NS2 = fresh()
    local path = "container.text.template"
    local ok, err, why = NS2.SetByPath(path, "$nope$", 1)
    assertFalse(ok)
    assertEqual(err, NS2.L["Invalid value for %s"]:format(path))
    -- red under: writeRow calling validate for its first return only (the parser's reason dropped)
    assertEqual(why:sub(1, 14), "Unknown token ")
    local okCheck, _, whyCheck = NS2.CheckWrite(path, "$nope$", 1)
    assertFalse(okCheck)
    assertEqual(whyCheck:sub(1, 14), "Unknown token ")
    -- A bare refusal carries no reason: the name row's validate answers false alone.
    local okName, _, whyName = NS2.SetByPath("container.name", "   ", 1)
    assertFalse(okName)
    assertNil(whyName)
end)

-- ── LibKa0s-Schema-1.0 (issue #21): the primitives, registry, bracket and validator are the library's ─

--- Record every [Set] line, rendered without its tag, with debug on.
local function captureSet(NS2)
    NS2.State.debug = true
    local lines = {}
    NS2.Debug = function(tag, fmt, ...)
        if tag ~= "Set" then return end
        lines[#lines + 1] = fmt:format(...)
    end
    return lines
end

test("schema: with LibKa0s the bracket, registry and validator are the library's", function()
    local S = NS.SchemaRuntime
    -- red under: the host copies on the live path
    assertTrue(type(S) == "table", "the Schema instance is published")
    assertTrue(NS.Bulk.Begin == S.BulkBegin, "Bulk.Begin is the instance's")
    assertTrue(NS.Bulk.End == S.BulkEnd, "Bulk.End is the instance's")
    assertTrue(NS.Bulk.Run == S.BulkRun, "Bulk.Run is the instance's")
    assertTrue(S.AllRows() == NS.Schema, "the instance holds the live schema array by reference")
    for _, row in ipairs(NS.Schema) do
        assertTrue(NS.FindSchemaRow(row.path) == S.FindRow(row.path), "FindRow answers " .. row.path)
        assertTrue(S.FindRow(row.path) == row, "and it answers the row itself: " .. row.path)
    end
    assertEqual(NS.ValidateSchema(), 0)
    local errors, resolved, missing = S.Validate({ pages = { general = true } })
    assertTrue(errors > 0 and resolved == 0 and missing == 0, "the instance's Validate is the one asked")
end)

test("schema: the registry follows an insert and a removal, the library's and the host's", function()
    for _, build in ipairs({ "live", "degraded" }) do
        local NS2 = inBuild(build)
        local S = NS2.SchemaRuntime
        assertEqual(S ~= nil, build == "live", build .. ": the instance exists only with the library")
        NS2.RegisterSchemaRows({
            { path = "container.bars.width.am15", page = "bars", group = "Size", type = "number" },
        }, "container.bars.width")
        local at
        for i, row in ipairs(NS2.Schema) do
            if row.path == "container.bars.width.am15" then at = i end
        end
        assertEqual(NS2.Schema[at + 1].path, "container.bars.width", build .. ": inserted in front of beforePath")
        -- red under: the index not rebuilt after an insert (host: RegisterSchemaRows skipping reindex)
        assertTrue(NS2.FindSchemaRow("container.bars.width.am15") == NS2.Schema[at], build .. ": found after insert")
        if S then assertTrue(S.FindRow("container.bars.width.am15") == NS2.Schema[at]) end
        assertEqual(NS2.UnregisterSchemaRows(function(row) return row.path == "container.bars.width.am15" end), 1)
        -- red under: UnregisterSchemaRows not re-indexing (the removed row still answers)
        assertNil(NS2.FindSchemaRow("container.bars.width.am15"), build)
        if S then assertNil(S.FindRow("container.bars.width.am15")) end
        assertTrue(NS2.FindSchemaRow("container.bars.width") == NS2.Schema[at],
            build .. ": the row after it still answers")
    end
end)

test("schema: without LibKa0s the host arm still answers", function()
    local NS2 = loadDegraded()
    rawset(_G, "AuraMasterDB", nil)
    NS2.addon:OnInitialize()
    assertNil(NS2.SchemaRuntime, "no instance without the library")
    -- A hand-written row: the composed ones (Master controls' alpha among them) are absent from this
    -- build (options-ui-§1).
    local PATH = "hideBlizzardBuffs"
    assertTrue(NS2.SetByPath(PATH, true))
    assertEqual(NS2.db.profile[PATH], true)
    assertTrue(NS2.FindSchemaRow(PATH) ~= nil)
    local lines = captureSet(NS2)
    NS2.Bulk.Run("copy", "degraded", function()
        NS2.SetByPath(PATH, false)
        NS2.SetByPath(PATH, false)                      -- no change: not counted
    end)
    assertEqual(table.concat(lines, " | "), "copy degraded: 1 rows")
    -- The act that reset the profile says so on `info`, the library's contract (JC-9).
    NS2.Bulk.Run("reset", "whole", function(info)
        NS2.SetByPath(PATH, true)
        info.profileReset = true
    end)
    assertEqual(#lines, 1, "a profile reset act logs no bulk line")
    assertEqual(NS2.ValidateSchema(), 0)
end)

test("schema: -0 over 0 is still no change under SameValue", function()
    local NS2 = fresh()
    assertTrue(NS2.SchemaRuntime ~= nil, "the library's SameValue is the one in use")
    local CM = NS2.ContainerManager
    CM.ResetPositions()                                  -- settle: the stagger writes -0 for the first
    local c1 = NS2.Database.FindContainer(1)
    c1.position.y = 0                                    -- a plain 0 where the stagger writes -0
    local lines = captureSet(NS2)
    CM.ResetPositions()
    -- red under: numbers compared by their tostring, where "-0" ~= "0"
    assertEqual(table.concat(lines, " | "), "reset positions: 0 rows")
end)

test("schema: a path with no segment past its root reads nil, the library's Read and the host's (#21)", function()
    for _, build in ipairs({ "live", "degraded" }) do
        local NS2 = inBuild(build)
        assertTrue(NS2.Database.FindContainer(1) ~= nil, build .. ": a starter container exists")
        -- red under: the host readFrom answering the root itself when no segment is left to walk
        assertNil(NS2.GetSetting("container", 1), build .. ": `container` alone is no setting")
        assertNil(NS2.GetSetting(""), build .. ": the empty path is not the profile")
        assertNil(NS2.GetSetting("..."), build .. ": nor is a path of dots")
        assertNil(NS2.GetSetting("hideBlizzardBuffs.x"), build .. ": a walk through a scalar stops")
        assertEqual(NS2.GetSetting("hideBlizzardBuffs"), NS2.db.profile.hideBlizzardBuffs, build)
        assertEqual(NS2.GetSetting("container.bars.width", 1), NS2.Database.FindContainer(1).bars.width, build)
    end
end)

test("schema: a duplicate path answers the first row registered, and an appended row answers at once, the library's and the host's (#21)", function()
    for _, build in ipairs({ "live", "degraded" }) do
        local NS2 = inBuild(build)
        local PATH = "hideBlizzardBuffs"
        local original = NS2.FindSchemaRow(PATH)
        assertTrue(original ~= nil, build .. ": the shipped row")
        local dup = { path = PATH, page = "general", group = "Display", type = "bool" }
        NS2.RegisterSchemaRows({ dup })
        -- red under: the host index keeping the LAST row on a path (LibKa0s-Schema keeps the first)
        assertTrue(NS2.FindSchemaRow(PATH) == original, build .. ": the first row still answers")
        local late = { path = "container.bars.width.i21", page = "bars", group = "Size", type = "number" }
        NS2.RegisterSchemaRows({ late })
        assertTrue(NS2.Schema[#NS2.Schema] == late, build .. ": appended at the end")
        -- red under: an append that skips the re-index
        assertTrue(NS2.FindSchemaRow("container.bars.width.i21") == late, build .. ": found at once")
        assertEqual(NS2.UnregisterSchemaRows(function(row) return row == dup or row == late end), 2, build)
        assertTrue(NS2.FindSchemaRow(PATH) == original, build .. ": the shipped row after the removal")
        assertNil(NS2.FindSchemaRow("container.bars.width.i21"), build)
    end
end)

test("schema: the bracket nests, survives a raise and ignores a stray End, the library's and the host's (#21)", function()
    for _, build in ipairs({ "live", "degraded" }) do
        local NS2 = inBuild(build)
        local PATH = "hideBlizzardBuffs"
        NS2.SetByPath(PATH, false)
        local lines = captureSet(NS2)
        NS2.Bulk.End("reset", "stray")                     -- no bracket open
        assertEqual(#lines, 0, build .. ": a stray End logs nothing")
        NS2.Bulk.Run("reset", "outer", function()
            NS2.Bulk.Run("reset", "inner", function() NS2.SetByPath(PATH, true) end)
            NS2.SetByPath(PATH, false)
        end)
        -- red under: a level logging at its own close rather than when the depth returns to 0
        assertEqual(table.concat(lines, " | "), "reset outer: 2 rows", build)
        local ok, err = pcall(NS2.Bulk.Run, "copy", "raise", function()
            NS2.SetByPath(PATH, true)
            error("boom", 0)
        end)
        assertFalse(ok, build)
        assertEqual(err, "boom", build .. ": the raised value comes back unchanged")
        -- red under: the bracket closing unmarked, or silently, on an error
        assertEqual(lines[2], "copy raise: 1 rows (stopped by an error)", build)
        -- A number row: captureSet formats without tostring, and Lua 5.1's %s refuses a boolean.
        NS2.SetByPath("container.bars.width", 251, 1)
        -- red under: the mute stuck open after the raise
        assertEqual(lines[3], "container.bars.width = 251", build .. ": the seam logs again")
        -- JC-9: the act that reset the profile says so on `info`; a `return true` is no signal.
        NS2.Bulk.Run("reset", "whole", function(info)
            NS2.SetByPath(PATH, true)
            info.profileReset = true
        end)
        assertEqual(#lines, 3, build .. ": a profile reset act logs no bulk line")
        NS2.Bulk.Run("reset", "returned", function()
            NS2.SetByPath(PATH, false)
            return true
        end)
        assertEqual(lines[4], "reset returned: 1 rows", build)
    end
end)
