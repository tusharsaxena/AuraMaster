-- tests/test_schema_paths.lua — settings/Schema.lua in depth: the write seam's order, the
-- container-relative and absolute path models, registration and validation, the carve-outs, the
-- whole sections, CheckWrite, ApplyDefault and the session rows. tests/test_schema.lua keeps the
-- shipped rows' shape; the bulk bracket is tests/test_bulklog.lua.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local fresh = dofile("tests/fresh_env.lua")
local loadDegraded = dofile("tests/degraded_env.lua")
local unpack_ = unpack   -- Lua 5.1, as .luacheckrc's std and the harness are

--- Every CONFIG_CHANGED payload, in order.
local function busLog(NS2)
    local got = {}
    NS2.NewBusTarget():RegisterMessage(NS2.MSG.CONFIG_CHANGED, function(_, p)
        got[#got + 1] = p
    end)
    return got
end

--- Every [Set] line, rendered, with debug on. Arguments go through tostring first: Lua 5.1's %s
--- raises on a table, and a color or a spell set is logged as one.
local function setLines(NS2)
    NS2.State.debug = true
    local lines = {}
    NS2.Debug = function(tag, fmt, ...)
        if tag ~= "Set" then return end
        local n, args = select("#", ...), { ... }
        for i = 1, n do args[i] = tostring(args[i]) end
        lines[#lines + 1] = fmt:format(unpack_(args, 1, n))
    end
    return lines
end

local function deleteAll(NS2)
    for _, c in ipairs(NS2.Database.GetContainers()) do NS2.ContainerManager.Delete(c.id) end
end

-- ── the write seam's order ────────────────────────────────────────────────────────────────────

test("schema paths: the seam validates before it resolves, so a bad value names the value, not the container", function()
    local NS2 = fresh()
    local ok, err = NS2.SetByPath("container.name", "   ", 99)
    assertFalse(ok)
    -- red under: writeRow refusing a missing container before running row.validate
    assertEqual(err, "Invalid value for container.name")
end)

test("schema paths: normalize is handed the resolved id, so a container keeps its own name in any case", function()
    local NS2 = fresh()
    assertTrue(NS2.SetByPath("container.name", "PLAYER BUFFS", 1))
    -- red under: writeRow calling row.normalize before the id is resolved (its own name reads as taken)
    assertEqual(NS2.Database.FindContainer(1).name, "PLAYER BUFFS")
    assertTrue(NS2.SetByPath("container.name", "player buffs", 2))
    assertEqual(NS2.Database.FindContainer(2).name, "player buffs (2)", "unique case-insensitively")
    NS2.State.SetActiveContainer(3)
    assertTrue(NS2.SetByPath("container.name", "Player Buffs"))
    assertEqual(NS2.Database.FindContainer(3).name, "Player Buffs (3)", "the id the active container resolved to")
end)

test("schema paths: the seam writes, then reacts, then logs, then announces — each seeing the stored value", function()
    local NS2 = fresh()
    local order = {}
    local row = NS2.FindSchemaRow("container.bars.width")
    row.onChange = function(v, id)
        order[#order + 1] = ("react %s %s read=%s"):format(v, id, NS2.GetSetting("container.bars.width", id))
    end
    NS2.State.debug = true
    NS2.Debug = function(tag, _, path, v)
        if tag == "Set" then
            order[#order + 1] = ("log %s=%s"):format(path, tostring(v))
        end
    end
    NS2.NewBusTarget():RegisterMessage(NS2.MSG.CONFIG_CHANGED, function(_, p)
        order[#order + 1] = "announce " .. p.path
    end)
    assertTrue(NS2.SetByPath("container.bars.width", 300, 2))
    -- red under: onChange called before writeInto (it reads the old 220), or the log/announce order swapped
    assertEqual(table.concat(order, " | "),
        "react 300 2 read=300 | log container.bars.width=300 | announce container.bars.width")
end)

test("schema paths: onChange, the [Set] line and CONFIG_CHANGED all see the normalized value", function()
    local NS2 = fresh()
    local seen
    NS2.FindSchemaRow("container.name").onChange = function(v) seen = v end
    local lines = setLines(NS2)
    local got = busLog(NS2)
    assertTrue(NS2.SetByPath("container.name", "  Player debuffs  ", 1))
    -- red under: SetByPath handing onChange / announceWrite the raw value instead of writeRow's stored one
    assertEqual(seen, "Player debuffs (2)")
    assertEqual(lines[1], "container.name = Player debuffs (2)")
    assertEqual(#got, 1)
    assertEqual(got[1].containerId, 1)
end)

test("schema paths: a refused write reacts to nothing, logs nothing and announces nothing", function()
    local NS2 = fresh()
    local reacted = 0
    NS2.FindSchemaRow("container.name").onChange = function() reacted = reacted + 1 end
    local lines = setLines(NS2)
    local got = busLog(NS2)
    assertFalse((NS2.SetByPath("container.name", "", 1)), "a value validate refuses")
    local ok, err = NS2.SetByPath("container.bars.noSuchLeaf", 5)
    assertFalse(ok)
    assertEqual(err, "Setting not found: container.bars.noSuchLeaf")
    -- red under: announceWrite reached on the refusal path
    assertEqual(reacted, 0)
    assertEqual(#lines, 0)
    assertEqual(#got, 0)
end)

test("schema paths: a path that is not a string is refused by every seam, naming what was passed", function()
    local NS2 = fresh()
    local ok, err = NS2.SetByPath(nil, 1)
    assertFalse(ok)
    -- red under: SetByPath's type guard dropped (splitPath(nil) would read "nil" as a path)
    assertEqual(err, "Setting not found: nil")
    ok, err = NS2.SetByPath(5, 1)
    assertFalse(ok)
    assertEqual(err, "Setting not found: 5")
    ok, err = NS2.CheckWrite({}, 1)
    assertFalse(ok)
    assertTrue(err:find("^Setting not found: table") ~= nil, err)
    assertNil(NS2.GetSetting(5))
    assertNil(NS2.FindSchemaRow(nil))
end)

-- ── the path models ───────────────────────────────────────────────────────────────────────────

test("schema paths: a selection naming a container that no longer exists falls back to the first", function()
    local NS2 = fresh()
    NS2.State.activeContainerId = 99
    local c, id = NS2.ActiveContainer()
    -- red under: ActiveContainer returning nil when FindContainer misses
    assertEqual(id, 1)
    assertTrue(c == NS2.Database.FindContainer(1))
    assertTrue(NS2.SetByPath("container.bars.width", 301))
    assertEqual(NS2.Database.FindContainer(1).bars.width, 301)
end)

test("schema paths: an explicit container id that does not exist is refused, never redirected to the selection", function()
    local NS2 = fresh()
    NS2.State.SetActiveContainer(1)
    local ok, err = NS2.SetByPath("container.bars.width", 300, 42)
    assertFalse(ok)
    assertEqual(err, "No container exists yet — create one on General -> Containers.")
    -- red under: resolveRoot falling back to NS.ActiveContainer when FindContainer(id) misses
    assertEqual(NS2.Database.FindContainer(1).bars.width, NS2.CONTAINER_TEMPLATE.bars.width)
    assertNil(NS2.GetSetting("container.bars.width", 42))
end)

test("schema paths: an absolute path writes the profile whatever container is named or selected", function()
    local NS2 = fresh()
    local got = busLog(NS2)
    NS2.State.SetActiveContainer(2)
    assertTrue(NS2.SetByPath("alpha", 0.3, 2))
    assertEqual(NS2.db.profile.alpha, 0.3)
    -- red under: resolveRoot treating every path as container-relative when an id is passed
    assertNil(NS2.Database.FindContainer(2).alpha)
    assertEqual(NS2.GetSetting("alpha", 3), 0.3)
    assertNil(got[1].containerId, "an addon-wide write names no container")
    assertEqual(got[1].section, "general")
end)

test("schema paths: GetSetting reads paths that are not rows, and a container path reads nil with no containers", function()
    local NS2 = fresh()
    NS2.State.SetActiveContainer(2)
    local c2 = NS2.Database.FindContainer(2)
    assertTrue(NS2.GetSetting("container.filter.whitelist") == c2.filter.whitelist, "a carve-out's set")
    assertTrue(NS2.GetSetting("container.bars") == c2.bars, "a whole section")
    assertTrue(NS2.GetSetting("containerOrder") == NS2.db.profile.containerOrder, "a profile key no row names")
    assertNil(NS2.GetSetting("container.bars.noSuchLeaf"))
    assertNil(NS2.GetSetting("container.bars.width.deeper"), "a path through a number")
    deleteAll(NS2)
    -- red under: resolveRoot answering the profile for a container path when no container exists
    assertNil(NS2.GetSetting("container.bars.width"))
    assertEqual(NS2.GetSetting("alpha"), 1, "a global row still answers")
end)

test("schema paths: a table value is stored as a copy, so the caller's table can never edit the container", function()
    local NS2 = fresh()
    local mine = { r = 0.1, g = 0.2, b = 0.3, a = 1 }
    assertTrue(NS2.SetByPath("container.bars.barColor", mine, 1))
    local stored = NS2.Database.FindContainer(1).bars.barColor
    -- red under: writeRow storing `value` instead of copy(value)
    assertTrue(stored ~= mine)
    mine.r = 0.9
    assertEqual(stored.r, 0.1)
    assertTrue(NS2.Database.FindContainer(2).bars.barColor ~= stored, "and no two containers share one")
end)

test("schema paths: a row's validate runs at the seam — the attach target refuses a non-number and a cycle", function()
    local NS2 = fresh()
    NS2.State.SetActiveContainer(2)
    assertTrue(NS2.SetByPath("container.attach.mode", "container"))
    assertFalse((NS2.SetByPath("container.attach.container", "abc")), "not a number")
    assertTrue(NS2.SetByPath("container.attach.container", 0), "0 is none")
    assertTrue(NS2.SetByPath("container.attach.container", 1), "2 follows 1")
    NS2.State.SetActiveContainer(1)
    assertTrue(NS2.SetByPath("container.attach.mode", "container"))
    local ok, err = NS2.SetByPath("container.attach.container", 2)
    -- red under: writeRow skipping row.validate
    assertFalse(ok, "1 following 2 would close a loop")
    assertEqual(err, "Invalid value for container.attach.container")
    assertEqual(NS2.Database.FindContainer(1).attach.container, 0)
end)

test("schema paths: an explicit-id attach write is checked for a loop from the container it writes", function()
    local NS2 = fresh()
    NS2.State.SetActiveContainer(1)
    -- red under: the attach validator checking the SELECTED container (1 following 1 reads as a loop)
    assertTrue(NS2.CheckWrite("container.attach.container", 1, 3), "CheckWrite agrees: 3 may follow 1")
    assertTrue(NS2.SetByPath("container.attach.container", 1, 3), "3 follows 1 while 1 is selected")
    assertEqual(NS2.Database.FindContainer(3).attach.container, 1)
    assertEqual(NS2.Database.FindContainer(1).attach.container, 0, "the selected container is untouched")
end)

test("schema paths: an explicit-id attach write that would loop is refused, whatever is selected", function()
    local NS2 = fresh()
    local c2 = NS2.Database.FindContainer(2)
    c2.attach.mode, c2.attach.container = "container", 3
    NS2.State.SetActiveContainer(1)
    -- red under: the attach validator checking the SELECTED container (1 is on no loop, so it passes)
    local ok, err = NS2.SetByPath("container.attach.container", 2, 3)
    assertFalse(ok, "3 following 2 closes 2 → 3 → 2")
    assertEqual(err, "Invalid value for container.attach.container")
    assertFalse((NS2.CheckWrite("container.attach.container", 2, 3)), "CheckWrite agrees")
    assertFalse((NS2.SetByPath("container.attach.container", 3, 3)), "3 following itself")
    assertEqual(NS2.Database.FindContainer(3).attach.container, 0)
end)

test("schema paths: an attach write through the selection still checks the selected container", function()
    local NS2 = fresh()
    local c2 = NS2.Database.FindContainer(2)
    c2.attach.mode, c2.attach.container = "container", 3
    NS2.State.SetActiveContainer(3)
    -- red under: the attach validator handed no container when the write targets the selection
    assertFalse((NS2.SetByPath("container.attach.container", 2)), "3 following 2 closes 2 → 3 → 2")
    assertTrue(NS2.SetByPath("container.attach.container", 1), "3 following 1 is no loop")
    assertEqual(NS2.Database.FindContainer(3).attach.container, 1)
end)

-- ── defaults, registration, validation ────────────────────────────────────────────────────────

test("schema paths: DefaultFor answers the template or the profile defaults, as a copy, never the stored value", function()
    local NS2 = fresh()
    NS2.SetByPath("container.bars.width", 333, 1)
    -- red under: DefaultFor resolving a container path against the active container
    assertEqual(NS2.DefaultFor("container.bars.width"), NS2.CONTAINER_TEMPLATE.bars.width)
    assertEqual(NS2.DefaultFor("locked"), NS2.defaults.profile.locked)
    assertNil(NS2.DefaultFor("container.bars.noSuchLeaf"))
    assertNil(NS2.DefaultFor("noSuchKey"))
    local color = NS2.DefaultFor("container.bars.barColor")
    -- red under: DefaultFor returning the template's own table
    assertTrue(color ~= NS2.CONTAINER_TEMPLATE.bars.barColor)
    color.r = 0.42
    assertTrue(NS2.CONTAINER_TEMPLATE.bars.barColor.r ~= 0.42, "the template is untouched")
end)

test("schema paths: RegisterSchemaRows stamps a resolvable row's default, and leaves session and unresolved rows alone", function()
    local NS2 = fresh()
    local count = #NS2.Schema
    NS2.RegisterSchemaRows("not a table")
    assertEqual(#NS2.Schema, count, "a non-table is ignored")
    NS2.RegisterSchemaRows({
        { path = "nextContainerId", page = "general", group = "G", type = "number", default = 42 },
        { path = "locked", page = "general", group = "G", type = "string", sessionOnly = true, default = "mine" },
        { path = "container.bars.noSuchLeaf", page = "bars", group = "G", type = "number", default = 7 },
    })
    assertEqual(#NS2.Schema, count + 3)
    -- red under: RegisterSchemaRows keeping the composer's default
    assertEqual(NS2.FindSchemaRow("nextContainerId").default, NS2.defaults.profile.nextContainerId)
    -- red under: RegisterSchemaRows stamping session rows too (this one's path resolves: it would read true)
    assertEqual(NS2.FindSchemaRow("locked").default, "mine")
    -- red under: stamping `d` even when DefaultFor answers nil
    assertEqual(NS2.FindSchemaRow("container.bars.noSuchLeaf").default, 7, "nothing to stamp from")
end)

test("schema paths: ValidateSchema fails an unknown page, an unknown type and an empty group, and says which", function()
    local NS2 = fresh()
    local printed = {}
    NS2.Print = function(line)
        printed[#printed + 1] = line
    end
    NS2.RegisterSchemaRows({
        { path = "nextContainerId", page = "nope", group = "G", type = "number" },
        { path = "seeded", page = "general", group = "G", type = "table" },
        { path = "enabled", page = "general", group = "", type = "bool" },
        -- Neither of these is a failure: a session row need not resolve, and profiles is a page.
        { path = "state.unresolved", page = "general", group = "G", type = "bool", sessionOnly = true },
        { path = "hideBlizzardBuffs", page = "profiles", group = "G", type = "bool" },
    })
    -- red under: any one of the three checks dropped, or the sessionOnly exemption dropped
    assertEqual(NS2.ValidateSchema(), 3)
    assertEqual(table.concat(printed, " | "), "schema error: nextContainerId: unknown page nope"
        .. " | schema error: seeded: unknown type table | schema error: enabled: no group")
end)

test("schema paths: SchemaForPage keeps declaration order and drops hidden rows and rows the container's type does not take", function()
    local NS2 = fresh()
    local function paths(page)
        local out = {}
        for _, r in ipairs(NS2.SchemaForPage(page)) do
            out[#out + 1] = r.path
        end
        return out
    end
    local want = {}
    for _, r in ipairs(NS2.Schema) do
        if r.page == "bars" then
            want[#want + 1] = r.path
        end
    end
    assertEqual(table.concat(paths("bars"), ","), table.concat(want, ","), "declaration order")
    NS2.FindSchemaRow("container.filter.castBy").hidden = true
    local function has(path)
        for _, p in ipairs(paths("filters")) do if p == path then return true end end
        return false
    end
    -- red under: SchemaForPage ignoring row.hidden
    assertFalse(has("container.filter.castBy"))
    local id = NS2.ContainerManager.Create({ auraType = "ENCHANT" })
    NS2.State.SetActiveContainer(id)
    for _, r in ipairs(NS2.SchemaForPage("filters")) do
        assertTrue(not r.auraTypes or r.auraTypes.ENCHANT, "an enchant container is offered " .. r.path)
    end
    assertTrue(has("container.filter.hidePermanentEnchants"), "a typed row that takes enchants")
    assertFalse(has("container.filter.sortMethod"), "a buffs-and-debuffs row")
    assertTrue(has("container.filter.sortDirection"), "an untyped row still applies")
    deleteAll(NS2)
    -- red under: rowApplies admitting a typed row when there is no container to read a type from
    for _, r in ipairs(NS2.SchemaForPage("filters")) do assertNil(r.auraTypes, "no container, yet " .. r.path) end
    assertTrue(has("container.filter.sortDirection"))
end)

test("schema paths: Choices keeps the key order and localizes each label, falling back to the key", function()
    local NS2 = fresh()
    rawset(NS2.L, "Alpha label", "ALPHA")
    local list = NS2.Choices({ "a", "b" }, { a = "Alpha label" })
    assertEqual(#list, 2)
    assertEqual(list[1].value, "a")
    assertEqual(list[1].text, "ALPHA")
    -- red under: Choices dropping the tostring(k) fallback for a key with no label
    assertEqual(list[2].value, "b")
    assertEqual(list[2].text, "b")
end)

-- ── the carve-outs ────────────────────────────────────────────────────────────────────────────

test("schema paths: a spell set goes to the container it names, announced as filters and logged once", function()
    local NS2 = fresh()
    NS2.State.SetActiveContainer(1)
    local lines = setLines(NS2)
    local got = busLog(NS2)
    assertTrue(NS2.SetByPath("container.filter.whitelist", { [774] = true }, 3))
    assertTrue(NS2.Database.FindContainer(3).filter.whitelist[774])
    assertNil(NS2.Database.FindContainer(1).filter.whitelist[774], "not the selected one")
    assertEqual(#got, 1)
    -- red under: writeCarveOut announcing under another section, or dropping the id
    assertEqual(got[1].section, "filters")
    assertEqual(got[1].containerId, 3)
    assertEqual(got[1].path, "container.filter.whitelist")
    assertEqual(#lines, 1)
    assertTrue(lines[1]:find("^container%.filter%.whitelist = ") ~= nil, lines[1])
end)

test("schema paths: a spell set or a section with no container to land in is refused, naming why", function()
    local NS2 = fresh()
    local function refused(path, value, id)
        local ok, err = NS2.SetByPath(path, value, id)
        assertFalse(ok, path)
        assertEqual(err, "No container exists yet — create one on General -> Containers.", path)
    end
    refused("container.filter.blacklist", { [1] = true }, 42)
    refused("container.position", { x = 1 }, 42)
    deleteAll(NS2)
    -- red under: writeCarveOut / writeSection writing into a nil root
    refused("container.filter.blacklist", { [1] = true })
    refused("container.layout", { spacing = 1 })
end)

test("schema paths: category edits drop an empty edit set and store a truthy edit as true", function()
    local NS2 = fresh()
    assertTrue(NS2.SetByPath("categorySpells", {
        defensives = {},
        externals = "not a set",
        movement = { ["10"] = "yes", [11] = false, [0] = true },
    }))
    local edits = NS2.db.profile.categorySpells
    -- red under: normalizeCategoryEdits storing an empty edit set
    assertNil(edits.defensives)
    assertNil(edits.externals)
    assertEqual(edits.movement[10], true, "a truthy non-boolean is an add")
    assertEqual(edits.movement[11], false, "false is a removal")
    assertNil(edits.movement[0], "a non-positive id is dropped")
end)

-- ── whole sections ────────────────────────────────────────────────────────────────────────────

test("schema paths: exactly the six documented sections are whole-writable", function()
    local NS2 = fresh()
    for _, p in ipairs({ "container.filter", "container.layout", "container.behavior",
            "container.position", "container.bars", "container.icons" }) do
        assertTrue(NS2.IsSection(p), p)
    end
    -- red under: SECTIONS gaining container.attach (its validator reads the active container)
    for _, p in ipairs({ "container.attach", "container.name", "container", "container.filter.whitelist",
            "bars", "container.bars.name" }) do
        assertFalse(NS2.IsSection(p), p)
    end
end)

test("schema paths: a section write fires onChange only for the leaves it changed, with the target id", function()
    local NS2 = fresh()
    local fired = {}
    NS2.FindSchemaRow("container.bars.width").onChange = function(v, id)
        fired[#fired + 1] = ("width %s %s"):format(v, id)
    end
    NS2.FindSchemaRow("container.bars.height").onChange = function(v, id)
        fired[#fired + 1] = ("height %s %s"):format(v, id)
    end
    NS2.State.SetActiveContainer(1)
    assertTrue(NS2.SetByPath("container.bars", { width = 300 }, 2))
    -- red under: fireSectionChanges calling every row's onChange, or passing no id
    assertEqual(table.concat(fired, ","), "width 300 2")
end)

test("schema paths: a row under a section that refuses its leaf refuses the whole section — CheckWrite says the same", function()
    local NS2 = fresh()
    NS2.FindSchemaRow("container.layout.spacing").validate = function(v) return v ~= 13 end
    local got = busLog(NS2)
    local before = NS2.Database.FindContainer(1).layout
    local ok, err = NS2.SetByPath("container.layout", { spacing = 13, axis = "horizontal" }, 1)
    assertFalse(ok)
    assertEqual(err, "Invalid value for container.layout.spacing")
    -- red under: validateSectionRows skipped (the section is stored with the refused leaf)
    assertTrue(NS2.Database.FindContainer(1).layout == before, "nothing stored")
    assertEqual(before.axis, "vertical")
    assertEqual(#got, 0, "nothing announced")
    local cok, cerr = NS2.CheckWrite("container.layout", { spacing = 13 }, 1)
    assertFalse(cok)
    assertEqual(cerr, err, "the dry run refuses with the same sentence")
end)

test("schema paths: a section write backfills a copy, so the caller's table comes back as it went in", function()
    local NS2 = fresh()
    local given = { x = 5 }
    assertTrue(NS2.SetByPath("container.position", given, 1))
    local keys = 0
    for _ in pairs(given) do keys = keys + 1 end
    -- red under: prepareSection backfilling `value` instead of its copy
    assertEqual(keys, 1)
    assertNil(given.point)
end)

test("schema paths: a section replaces the stored one from the template, not merges into it, and normalizes its spell sets", function()
    local NS2 = fresh()
    local c3 = NS2.Database.FindContainer(3)
    assertEqual(c3.filter.castBy, "mine", "the starter differs from the template here")
    assertTrue(NS2.SetByPath("container.filter", { whitelist = { ["5"] = true, [-1] = true } }, 3))
    -- red under: backfilling the section from the stored one rather than the template
    assertEqual(c3.filter.castBy, NS2.CONTAINER_TEMPLATE.filter.castBy)
    local ids = {}
    for id in pairs(c3.filter.whitelist) do
        ids[#ids + 1] = tostring(id)
    end
    -- red under: normalizeSectionCarveOuts skipped (the string key and the negative id survive)
    assertEqual(table.concat(ids, ","), "5")
end)

test("schema paths: a section's [Set] line renders the stored table with sorted keys and nested tables elided", function()
    local NS2 = fresh()
    local lines = setLines(NS2)
    assertTrue(NS2.SetByPath("container.position", { point = "TOP", x = 5 }, 1))
    -- red under: renderSection unsorted, or rendering the caller's table instead of the backfilled copy
    assertEqual(lines[1], "container.position = {point=TOP, relativePoint=CENTER, x=5, y=0}")
    assertTrue(NS2.SetByPath("container.bars", {}, 1))
    assertTrue(lines[2]:find("name={...}", 1, true) ~= nil, lines[2])
    assertEqual(#lines, 2, "one line per section write")
end)

test("schema paths: a section's [Set] line is not even built while debug is off", function()
    local NS2 = fresh()
    NS2.State.debug = false
    local calls = {}
    NS2.Debug = function(tag, _, path)
        calls[#calls + 1] = tag .. " " .. tostring(path)
    end
    assertTrue(NS2.SetByPath("container.position", { x = 9 }, 1))
    -- red under: logSection without its NS.State.debug gate (the render runs on every drag)
    assertEqual(#calls, 0, table.concat(calls, ","))
    assertTrue(NS2.SetByPath("container.bars.width", 250, 1))
    assertEqual(#calls, 1, "a row write leaves the gate to the sink")
end)

-- ── CheckWrite, ApplyDefault, the session rows ────────────────────────────────────────────────

test("schema paths: with no containers CheckWrite refuses a container row and passes a global one", function()
    local NS2 = fresh()
    deleteAll(NS2)
    -- red under: checkRow skipping its resolveRoot check
    local ok, err = NS2.CheckWrite("container.bars.width", 300)
    assertFalse(ok)
    assertEqual(err, "No container exists yet — create one on General -> Containers.")
    assertTrue(NS2.CheckWrite("alpha", 0.5), "a global row needs none")
end)

test("schema paths: ApplyDefault is a no-op for nothing, a row with no path, and a row with no default", function()
    local NS2 = fresh()
    local got = busLog(NS2)
    NS2.SetByPath("alpha", 0.4)
    NS2.ApplyDefault(nil)
    NS2.ApplyDefault({ default = 1 })
    NS2.ApplyDefault({ path = "alpha" })
    -- red under: ApplyDefault writing nil (or the path's default) when the row carries none
    assertEqual(NS2.db.profile.alpha, 0.4)
    assertEqual(#got, 1, "only the setup write announced")
end)

test("schema paths: ApplyDefault restores a session row through its own set", function()
    local NS2 = fresh()
    NS2.SetByPath("state.preview", true)
    assertTrue(NS2.State.preview)
    NS2.ApplyDefault(NS2.FindSchemaRow("state.preview"))
    -- red under: ApplyDefault skipping sessionOnly rows
    assertFalse(NS2.State.preview)
end)

test("schema paths: a session row needs no database — it checks and writes before InitDB has run", function()
    local NS2 = loadDegraded()                        -- nothing has called OnInitialize: no NS.db
    assertNil(NS2.db)
    local stored = {}
    NS2.RegisterSchemaRows({
        { path = "state.probe", page = "general", group = "G", type = "bool", sessionOnly = true,
          get = function() return stored.v end, set = function(v) stored.v = v end },
    })
    -- red under: checkRow resolving a root for a session row (there is no profile root yet)
    assertTrue(NS2.CheckWrite("state.probe", true))
    -- red under: writeRow resolving a root for a session row
    assertTrue(NS2.SetByPath("state.probe", true))
    assertTrue(stored.v)
    assertEqual(NS2.GetSetting("state.probe"), true)
    assertFalse((NS2.CheckWrite("alpha", 0.5)), "a profile row does need the database")
end)

test("schema paths: a session row's validate still guards it", function()
    local NS2 = fresh()
    deleteAll(NS2)
    assertTrue(NS2.SetByPath("state.preview", true))
    assertTrue(NS2.State.preview)
    local row = NS2.FindSchemaRow("state.preview")
    row.validate = function(v) return v == false end
    local ok, err = NS2.SetByPath("state.preview", "yes")
    assertFalse(ok)
    assertEqual(err, "Invalid value for state.preview")
    assertTrue(NS2.State.preview, "the refused value never reached set()")
end)

test("schema paths: a session row with no get reads nil, never the profile", function()
    local NS2 = fresh()
    NS2.db.profile.state = { probe = "from the profile" }
    NS2.RegisterSchemaRows({
        { path = "state.probe", page = "general", group = "G", type = "string", sessionOnly = true },
    })
    -- red under: GetSetting falling through to the path read for a session row with no get
    assertNil(NS2.GetSetting("state.probe"))
end)
