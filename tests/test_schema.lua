-- tests/test_schema.lua — settings/Schema.lua: the rows, the container-relative path model and the
-- single write seam.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local NS = T.NS
local fresh = dofile("tests/fresh_env.lua")

-- ── the rows ──────────────────────────────────────────────────────────────────────────────────

test("schema: every row validates against defaults/Profile.lua", function()
    assertEqual(NS.ValidateSchema(), 0)
end)

test("schema: the validator is falsifiable — an unresolvable path and a missing group each fail", function()
    -- red under: ValidateSchema no longer resolving paths, or no longer checking `group`.
    local NS2 = fresh()
    NS2.RegisterSchemaRows({
        { path = "container.bars.noSuchLeaf", page = "bars", group = "Size", type = "number" },
        { path = "container.bars.width", page = "bars", type = "number" },
    })
    assertEqual(NS2.ValidateSchema(), 2)
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
    return path:find("%.dispelColors%.") or path:find("%.expiringColor$") or path:find("%.pandemicColor$")
end

test("schema: every color row has its class-color companion next to it, or is a palette swatch", function()
    local rows = NS.Schema
    local checked = 0
    for i, row in ipairs(rows) do
        assertNil(row.disabledIf, "disabledIf is forbidden on any row here: " .. row.path)
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
    rx:RegisterMessage(NS2.MSG.CONFIG_CHANGED, function(_, payload) got[#got + 1] = payload end)
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
    NS2.SetByPath("state.preview", true)
    assertTrue(NS2.State.preview)
    assertEqual(NS2.GetSetting("state.preview"), true)
    -- red under: SetByPath writing session rows into the profile (dropping the sessionOnly branch)
    assertNil(NS2.db.profile.state)
    NS2.SetByPath("state.preview", false)
end)

test("schema: a session row announces no CONFIG_CHANGED and queues no apply", function()
    local NS2, mocks = fresh()
    local CM = NS2.ContainerManager
    local requests, orig = { 0 }, CM.RequestApply
    CM.RequestApply = function(...) requests[1] = requests[1] + 1; return orig(...) end
    local announced = { 0 }
    NS2.NewBusTarget():RegisterMessage(NS2.MSG.CONFIG_CHANGED, function() announced[1] = announced[1] + 1 end)
    assertTrue(NS2.SetByPath("state.preview", true))
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
    for id in pairs(set) do ids[#ids + 1] = id end
    table.sort(ids)
    assertEqual(table.concat(ids, ","), "7,12")
    assertFalse((NS2.SetByPath("container.filter.blacklist", "12")), "a non-set is refused")
end)

test("schema: category spell edits keep only real spell categories", function()
    local NS2 = fresh()
    NS2.State.SetActiveContainer(1)
    NS2.SetByPath("container.filter.categorySpells", {
        defensives = { [1] = false, ["2"] = true },
        crowdControl = { [3] = true },   -- a token category: no editable spells
        nonsense = { [4] = true },
    })
    local edits = NS2.Database.FindContainer(1).filter.categorySpells
    assertEqual(edits.defensives[1], false)
    assertEqual(edits.defensives[2], true)
    assertNil(edits.crowdControl)
    assertNil(edits.nonsense)
end)

-- ── whole-section writes ──────────────────────────────────────────────────────────────────────

test("schema: a whole section written through the seam replaces it, backfills it, logs once and announces once", function()
    local NS2 = fresh()
    NS2.State.debug = true
    local lines = {}
    NS2.Debug = function(tag, fmt, ...)
        if tag == "Set" then lines[#lines + 1] = fmt:format(...) end
    end
    local got = {}
    NS2.NewBusTarget():RegisterMessage(NS2.MSG.CONFIG_CHANGED, function(_, p) got[#got + 1] = p end)
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
