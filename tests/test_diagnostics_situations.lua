-- tests/test_diagnostics_situations.lua — the `/am diagnostics` [Plan] spell-list line for filter
-- situations (S2 of docs/superpowers/specs/2026-10-02-filter-situations-design.md): each container's
-- spell-list mode, the view its engine holds and the situation that picked it, read off the live
-- instance (`inst.view`, `inst.situation`), including a swap that keeps the view and an ordinary
-- setting write that updates the engine in place. Split from tests/test_diagnostics.lua to keep that
-- suite under the 1000-line on-notice band (layout-§1).

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")

--- The report's lines as "[Tag] msg", straight from the library's builder (it writes nothing).
local function build(NS)
    local out = NS.DebugLog:BuildDiagnostics()
    local lines = {}
    for i, l in ipairs(out.lines) do lines[i] = "[" .. l[1] .. "] " .. l[2] end
    return lines
end

local function has(lines, text)
    for _, l in ipairs(lines) do
        if l:find(text, 1, true) then return l end
    end
    return nil
end

local function dump(lines) return "{" .. table.concat(lines, " | ") .. "}" end

test("diag: each container's spell-list mode, the view its engine holds and the situation behind it", function()
    local NS, mocks = fresh()
    mocks.__canAssist.target = false
    local id = NS.ContainerManager.Create({ unit = "target", auraType = "HELPFUL" })
    local deb = NS.ContainerManager.Create({ unit = "player", auraType = "HARMFUL" })
    local buf = NS.ContainerManager.Create({ unit = "player", auraType = "HELPFUL" })
    mocks.__fireTimers()
    local lines = build(NS)
    -- red under: planLines without the situation (filter situations, S2), or the two-way resolver
    -- (a hostile NPC on the blizzard view whatever its NPCs setting)
    assertTrue(has(lines, "[Plan] #" .. id .. " spell lists: mode=dynamic view=every situation=npcs") ~= nil,
        dump(lines))
    assertTrue(has(lines, "[Plan] #" .. deb .. " spell lists: mode=never view=every situation=players") ~= nil,
        dump(lines))
    assertTrue(has(lines, "[Plan] #" .. buf .. " spell lists: mode=always view=ids situation=-") ~= nil,
        dump(lines))
    mocks.__isPlayer.target = true
    NS.SetByPath("container.filter.situations.players", "blizzard", id)
    lines = build(NS)
    -- red under: the view or situation read off the settings rather than the live instance
    assertTrue(has(lines, "[Plan] #" .. id .. " spell lists: mode=dynamic view=blizzard situation=players") ~= nil,
        dump(lines))
    mocks.__canAssist.target = true
    NS.ContainerManager.instances[id]:ApplyView()
    lines = build(NS)
    assertTrue(has(lines, "[Plan] #" .. id .. " spell lists: mode=dynamic view=ids situation=-") ~= nil, dump(lines))
end)

test("diag: a swap that keeps the view still names the new situation", function()
    local NS, mocks = fresh()
    mocks.__canAssist.target, mocks.__isPlayer.target = false, false
    local id = NS.ContainerManager.Create({ unit = "target", auraType = "HELPFUL",
        filter = { situations = { npcs = "every", players = "every" } } })
    mocks.__fireTimers()
    local inst = NS.ContainerManager.instances[id]
    assertEqual(inst.view, "every"); assertEqual(inst.situation, "npcs")
    mocks.__isPlayer.target = true
    assertFalse(inst:ApplyView(), "the view did not move")
    assertEqual(inst.view, "every")
    -- red under: ApplyView's unchanged-view branch leaving inst.situation alone (an enemy player
    -- reported as an NPC)
    assertEqual(inst.situation, "players")
    local lines = build(NS)
    assertTrue(has(lines, "[Plan] #" .. id .. " spell lists: mode=dynamic view=every situation=players") ~= nil,
        dump(lines))
end)

test("diag: an ordinary setting write keeps the situation the view was chosen for", function()
    local NS, mocks = fresh()
    mocks.__canAssist.target, mocks.__isPlayer.target = false, false
    local id = NS.ContainerManager.Create({ unit = "target", auraType = "HELPFUL" })
    mocks.__fireTimers()
    local inst = NS.ContainerManager.instances[id]
    assertEqual(inst.situation, "npcs")
    local engine = inst.engine
    assertTrue(NS.SetByPath("container.filter.maxDuration", 30, id))
    mocks.__fireTimers()
    assertTrue(inst.engine == engine, "updated in place, not rebuilt")
    assertEqual(inst.view, "every")
    -- red under: Container:Update passing nil for the situation to NoteView (situation=- on every)
    assertEqual(inst.situation, "npcs")
    local lines = build(NS)
    assertTrue(has(lines, "[Plan] #" .. id .. " spell lists: mode=dynamic view=every situation=npcs") ~= nil,
        dump(lines))
end)
