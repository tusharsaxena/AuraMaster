-- tests/test_diagnostics.lua — modules/Diagnostics.lua: `/am debug diag`, the one-shot diagnostic
-- report written to the debug console (batch 8 DG-1..DG-4, docs/debug.md). Driven through the real
-- slash dispatcher where the verb matters, and through NS.Diagnostics.Build where only the lines do.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")
local loadDegraded = dofile("tests/degraded_env.lua")

local function capture(mocks)
    local lines = {}
    rawset(mocks.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
        local n = #lines
        lines[n + 1] = tostring(msg)
    end)
    return lines
end

--- `list` keyed "unit:FILTER"; `spy.n` counts every read.
local function withAuras(mocks, byKey, spy)
    mocks.C_UnitAuras = {
        GetAuraDataByIndex = function(unit, i, filter)
            if spy then spy.n = spy.n + 1 end
            local list = byKey[tostring(unit) .. ":" .. tostring(filter)]
            return list and list[i]
        end,
    }
end

local function aura(inst, id, name, extra)
    local a = {
        auraInstanceID = inst, spellId = id, name = name, dispelName = nil, sourceUnit = "player",
        isFromPlayerOrPlayerPet = true, duration = 60, expirationTime = 0, applications = 0,
        isBossAura = false, isStealable = false,
    }
    for k, v in pairs(extra or {}) do a[k] = v end
    return a
end

--- The report's lines as "[Tag] msg", straight from the builder.
local function build(NS)
    local out = NS.Diagnostics.Build()
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

local function count(lines, text)
    local n = 0
    for _, l in ipairs(lines) do
        if l:find(text, 1, true) then n = n + 1 end
    end
    return n
end

local function dump(lines) return "{" .. table.concat(lines, " | ") .. "}" end

-- ── the verb and the sink (DG-1) ───────────────────────────────────────────────────────────────

test("diag: /am debug diag writes the report to the console ungated, opens it, and says so once", function()
    local NS, mocks = fresh()
    local chat = capture(mocks)
    assertFalse(NS.State.debug)
    local before = #NS.DebugLog.buffer
    NS.Slash:OnSlash("debug diag")
    local buf = NS.DebugLog.buffer
    local total = #buf
    -- red under: routing through the gated NS.Debug (the flag is off, so nothing would land)
    assertTrue(total > before + 5, "the report did not reach the buffer")
    assertTrue(buf[before + 1]:find("[Diag] ==== Aura Master diagnostic begin ====", 1, true) ~= nil, buf[before + 1])
    local last = buf[total]
    local n = last:match("==== end: (%d+) line%(s%) ====")
    assertTrue(n ~= nil, "no end marker: " .. last)
    assertEqual(tonumber(n), total - before, "the end marker counts every line of the report")
    assertTrue(NS.DebugLog:IsShown(), "the console was not revealed")
    assertFalse(NS.State.debug, "the diagnostic must not switch logging on")
    assertEqual(#chat, 1, dump(chat))
    assertTrue(chat[1]:find(n .. " lines", 1, true) ~= nil, chat[1])
end)

test("diag: bare /am debug and /am debug on|off keep their meaning; DIAG is read in any case", function()
    local NS, mocks = fresh()
    capture(mocks)
    NS.Slash:OnSlash("debug")
    assertTrue(NS.DebugLog:IsShown())
    assertFalse(NS.State.debug)
    NS.Slash:OnSlash("debug")
    assertFalse(NS.DebugLog:IsShown())
    NS.Slash:OnSlash("debug on")
    assertTrue(NS.State.debug)
    NS.Slash:OnSlash("debug off")
    assertFalse(NS.State.debug)
    local before = #NS.DebugLog.buffer
    NS.Slash:OnSlash("debug DIAG")
    local buf = NS.DebugLog.buffer
    assertTrue(buf[before + 1]:find("diagnostic begin", 1, true) ~= nil, "DIAG did not run the report")
end)

test("diag: it answers while the addon is disabled, and the state line says so", function()
    local NS, mocks = fresh()
    local chat = capture(mocks)
    NS.Slash:OnSlash("disable")
    for k in pairs(chat) do chat[k] = nil end
    local before = #NS.DebugLog.buffer
    NS.Slash:OnSlash("debug diag")
    local buf = NS.DebugLog.buffer
    assertTrue(#buf > before, "refused while disabled: " .. dump(chat))
    local text = table.concat(buf, "\n", before + 1)
    assertTrue(text:find("enabled=false stoodDown=true", 1, true) ~= nil, text)
end)

test("diag: without LibKa0s it prints the unavailable line and raises nothing", function()
    local NS2, mocks2 = loadDegraded()
    local chat = capture(mocks2)
    assertEqual(NS2.Diagnostics.Run(), 0)
    assertTrue(has(chat, "so the diagnostic report is unavailable.") ~= nil, dump(chat))
end)

-- ── the header and the auras (DG-2, DG-3) ─────────────────────────────────────────────────────

test("diag: the header names version, schema, profile, state and the apply queue", function()
    local NS = fresh()
    local lines = build(NS)
    local head = has(lines, "[Diag] Aura Master v")
    assertTrue(head ~= nil and head:find("schema v", 1, true) ~= nil, dump(lines))
    assertTrue(has(lines, "state: enabled=true") ~= nil, dump(lines))
    assertTrue(has(lines, "apply queue: all=false ids=[]") ~= nil, dump(lines))
end)

test("diag: the profile section lists non-default rows only, with no color escape", function()
    local NS = fresh()
    NS.SetByPath("alpha", 0.5)
    local lines = build(NS)
    local cfg = has(lines, "[Cfg] profile non-default:")
    assertTrue(cfg ~= nil and cfg:find("alpha=", 1, true) ~= nil, dump(lines))
    assertTrue(cfg:find("scale=", 1, true) == nil, "an untouched row was listed: " .. cfg)
end)

test("diag: auras on the player are dumped per filter with every field", function()
    local NS, mocks = fresh()
    mocks.__now = 100
    withAuras(mocks, {
        ["player:HELPFUL"] = { aura(11, 774, "Rejuvenation", { expirationTime = 130, applications = 2 }),
                               aura(12, 1459, "Arcane Intellect") },
        ["player:HARMFUL"] = { aura(21, 8050, "Flame Shock", { dispelName = "Magic", sourceUnit = "target",
                                                               isFromPlayerOrPlayerPet = false }) },
    })
    local lines = build(NS)
    assertTrue(has(lines, "[Unit] player HELPFUL: 2 aura(s)") ~= nil, dump(lines))
    assertTrue(has(lines, "[Unit] player HARMFUL: 1 aura(s)") ~= nil, dump(lines))
    local rejuv = has(lines, 'id=774 "Rejuvenation"')
    assertTrue(rejuv ~= nil, dump(lines))
    for _, want in ipairs({ "inst=11", "dispel=nil", "src=player", "mine=true", "dur=60", "left=30.0", "stacks=2" }) do
        assertTrue(rejuv:find(want, 1, true) ~= nil, want .. " missing: " .. rejuv)
    end
    local shock = has(lines, '"Flame Shock"')
    assertTrue(shock:find("dispel=Magic", 1, true) ~= nil and shock:find("player-", 1, true) ~= nil, shock)
end)

test("diag: a secret aura field prints as secret, never compares, and is left out of predictions", function()
    local NS, mocks = fresh()
    mocks.issecretvalue = function(v) return v == mocks.__SECRET end
    local S = mocks.__SECRET
    withAuras(mocks, {
        ["player:HELPFUL"] = { aura(11, S, "Hidden", { duration = S, expirationTime = S, applications = S }) },
    })
    -- red under: arithmetic or format on a raw secret field (the sentinel raises on both)
    local lines = build(NS)
    local line = has(lines, '"Hidden"')
    assertTrue(line ~= nil, dump(lines))
    assertTrue(line:find("left=-", 1, true) ~= nil, line)
    assertTrue(line:find("secret", 1, true) ~= nil, line)
    assertTrue(has(lines, "section") == nil or has(lines, "failed") == nil, dump(lines))
    assertTrue(has(lines, "predicted: <secret") == nil, "a secret id was explained")
end)

test("diag: while auras are secret no aura API is called and no button is touched", function()
    local NS, mocks = fresh()
    local spy = { n = 0 }
    withAuras(mocks, { ["player:HELPFUL"] = { aura(1, 774, "Rejuvenation") } }, spy)
    mocks.__unitExists.target = true
    local engine = NS.ContainerManager.instances[1].engine
    local key = NS.ContainerManager.instances[1].plan.groups[1].key
    local touched = 0
    local f = mocks.__stubFrame()
    rawset(f, "IsShown", function() touched = touched + 1; error("secret button") end)
    engine.__frames[key] = { f }
    mocks.__aurasSecret = true
    local lines = build(NS)
    assertEqual(spy.n, 0, "an aura API was called while secret")
    assertEqual(touched, 0, "a button was touched while secret")
    assertTrue(has(lines, "[Unit] player: unreadable") ~= nil, dump(lines))
    assertTrue(has(lines, "[Unit] target: unreadable") ~= nil, dump(lines))
    assertTrue(has(lines, "[Unit] focus: none") ~= nil, dump(lines))
    assertTrue(has(lines, "shown=?") ~= nil, dump(lines))
    assertTrue(has(lines, "[Shown] #1 skipped") ~= nil, dump(lines))
    assertTrue(has(lines, "frames=1") ~= nil, "the frame count is still read: " .. dump(lines))
end)

test("diag: a raising aura read is reported and the containers still report", function()
    local NS, mocks = fresh()
    mocks.C_UnitAuras = { GetAuraDataByIndex = function() error("boom") end }
    local lines = build(NS)
    assertTrue(has(lines, "read failed") ~= nil, dump(lines))
    assertTrue(has(lines, "[Cont] #1") ~= nil, dump(lines))
end)

test("diag: absent units read none, and a pet that exists is dumped", function()
    local NS, mocks = fresh()
    withAuras(mocks, { ["pet:HELPFUL"] = { aura(5, 774, "Rejuvenation") } })
    local lines = build(NS)
    for _, u in ipairs({ "target", "focus", "pet" }) do
        assertTrue(has(lines, "[Unit] " .. u .. ": none") ~= nil, u .. ": " .. dump(lines))
    end
    mocks.__unitExists.pet = true
    lines = build(NS)
    assertTrue(has(lines, "[Unit] pet HELPFUL: 1 aura(s)") ~= nil, dump(lines))
end)

-- ── the containers (DG-2) ──────────────────────────────────────────────────────────────────────

test("diag: every container gets a line and a full filter block, lists sorted and named", function()
    local NS, mocks = fresh()
    mocks.__spells[1459] = { name = "Arcane Intellect", iconID = 1 }
    local c1 = NS.Database.FindContainer(1)
    c1.filter.whitelist[1459] = true
    c1.filter.whitelist[774] = true
    c1.filter.blacklist[21562] = true
    local lines = build(NS)
    for _, c in ipairs(NS.Database.GetContainers()) do
        local id = tostring(c.id)
        assertTrue(has(lines, "[Cont] #" .. id .. ' "' .. c.name .. '"') ~= nil, id .. ": " .. dump(lines))
        assertTrue(has(lines, "[Filt] #" .. id .. " castBy=") ~= nil, id .. ": " .. dump(lines))
        assertTrue(has(lines, "[Filt] #" .. id .. " categories") ~= nil, id .. ": " .. dump(lines))
    end
    assertTrue(has(lines, "whitelist(2)=[774 Rejuvenation, 1459 Arcane Intellect]") ~= nil, dump(lines))
    assertTrue(has(lines, "blacklist(1)=[21562 ?]") ~= nil, dump(lines))
end)

test("diag: a container's non-default rows are listed, with no color escape, untouched rows absent", function()
    local NS = fresh()
    NS.SetByPath("container.bars.width", 250, 1)
    NS.SetByPath("container.bars.expiringColor", { r = 0.1, g = 0.2, b = 0.3, a = 1 }, 1)
    local lines = build(NS)
    local cfg = has(lines, "[Cfg] #1 non-default:")
    assertTrue(cfg ~= nil and cfg:find("bars.width=250", 1, true) ~= nil, dump(lines))
    assertTrue(cfg:find("bars.expiringColor=", 1, true) ~= nil, cfg)
    -- red under: formatValue's raw output (a color swatch escape lands verbatim in the Copy text)
    assertTrue(cfg:find("|c", 1, true) == nil and cfg:find("|T", 1, true) == nil, cfg)
    assertTrue(cfg:find("bars.height", 1, true) == nil, "an untouched row was listed: " .. cfg)
    -- A formatted value that carries escapes (a printLabel row's gray, a swatch) is stripped.
    local format = NS.Slash.FormatValue
    NS.Slash.FormatValue = function(row, v) return "|cff808080" .. format(row, v) .. "|r|Tx:0|t" end
    cfg = has(build(NS), "[Cfg] #1 non-default:")
    NS.Slash.FormatValue = format
    assertTrue(cfg:find("bars.width=250", 1, true) ~= nil, cfg)
    assertTrue(cfg:find("|c", 1, true) == nil and cfg:find("|r", 1, true) == nil and cfg:find("|T", 1, true) == nil, cfg)
end)

test("diag: a row scoped to an aura type is not listed for a container of the other type", function()
    local NS = fresh()
    local row
    for _, r in ipairs(NS.Schema) do
        if r.path == "container.icons.width" then row = r end
    end
    assertTrue(row ~= nil, "no icons.width row")
    row.auraTypes = { HELPFUL = true }
    NS.SetByPath("container.icons.width", 50, 2)
    NS.SetByPath("container.icons.width", 50, 1)
    local lines = build(NS)
    assertTrue(has(lines, "[Cfg] #1 non-default:"):find("icons.width=50", 1, true) ~= nil, dump(lines))
    local two = has(lines, "[Cfg] #2 non-default:") or ""
    -- red under: cfgLines ignoring NS.RowApplies
    assertTrue(two:find("icons.width", 1, true) == nil, two)
end)

test("diag: the plan verdict reads in sync, PENDING, DRIFT or not built", function()
    local NS, mocks = fresh()
    local lines = build(NS)
    assertTrue(has(lines, "[Plan] #1 plan in sync") ~= nil, dump(lines))

    mocks.__aurasSecret = true
    NS.SetByPath("container.filter.castBy", "mine", 1)
    mocks.__fireTimers()
    local snap = NS.ContainerManager.QueueSnapshot()
    assertTrue(snap.idSet[1] == true, "the change was not queued")
    lines = build(NS)
    assertTrue(has(lines, "[Plan] #1 PENDING (") ~= nil, dump(lines))

    mocks.__aurasSecret = false
    NS.ContainerManager.FlushPending()
    NS.Database.FindContainer(2).filter.castBy = "mine"
    lines = build(NS)
    assertTrue(has(lines, "[Plan] #1 plan in sync") ~= nil, dump(lines))
    assertTrue(has(lines, "[Plan] #2 DRIFT: settings changed but no apply was requested") ~= nil, dump(lines))

    NS.ContainerManager.instances[3].plan = nil
    lines = build(NS)
    assertTrue(has(lines, "[Plan] #3 not built") ~= nil, dump(lines))
end)

test("diag: plan groups report the engine's frame and shown counts, or ? when unreadable", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local key = inst.plan.groups[1].key
    local a, b, c = mocks.__stubFrame(), mocks.__stubFrame(), mocks.__stubFrame()
    c:Hide()
    inst.engine.__frames[key] = { a, b, c }
    local lines = build(NS)
    assertTrue(has(lines, "[Plan] #1 " .. key) ~= nil, dump(lines))
    local g = has(lines, "[Plan] #1 " .. key)
    assertTrue(g:find("frames=3 shown=2", 1, true) ~= nil, g)
    rawset(inst.engine, "GetAuraGroupFrameCount", function() error("forbidden") end)
    lines = build(NS)
    g = has(lines, "[Plan] #1 " .. key)
    assertTrue(g:find("frames=? shown=?", 1, true) ~= nil, g)
end)

test("diag: shown buttons are identified by instance, then by our own regions, else id=?", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local key = inst.plan.groups[1].key
    local byId = mocks.__stubFrame()
    rawset(byId, "GetAuraInstanceID", function() return 4242 end)
    local byName = mocks.__stubFrame()
    local fs = mocks.__stubFrame()
    rawset(fs, "GetText", function() return "Rejuvenation" end)
    byName.__am = { name = fs }
    local bare = mocks.__stubFrame()
    inst.engine.__frames[key] = { byId, byName, bare }
    local lines = build(NS)
    assertTrue(has(lines, "btn1 inst=4242") ~= nil, dump(lines))
    assertTrue(has(lines, 'btn2 name="Rejuvenation"') ~= nil, dump(lines))
    assertTrue(has(lines, "btn3 id=?") ~= nil, dump(lines))
end)

test("diag: predictions come from ExplainSpell over the unit's readable auras", function()
    local NS, mocks = fresh()
    mocks.__spells[1459] = { name = "Arcane Intellect", iconID = 1 }
    withAuras(mocks, { ["player:HELPFUL"] = { aura(1, 774, "Rejuvenation"), aura(2, 1459, "Arcane Intellect") } })
    local c1 = NS.Database.FindContainer(1)
    c1.filter.whitelist[774] = true
    c1.filter.blacklist[1459] = true
    local lines = build(NS)
    assertTrue(has(lines, "[Shown] #1 predicted: 774 Rejuvenation -> shown (rank 1") ~= nil, dump(lines))
    assertTrue(has(lines, "[Shown] #1 predicted: 1459 Arcane Intellect -> hidden (rank 2") ~= nil, dump(lines))
    -- The debuff container reads the HARMFUL set, which is empty here.
    assertTrue(has(lines, "[Shown] #2 predicted: 774") == nil, dump(lines))
end)

-- ── robustness and the caps (DG-3, DG-4) ──────────────────────────────────────────────────────

test("diag: a failing section is reported and the next container still reports", function()
    local NS = fresh()
    NS.Database.FindContainer(1).filter = 5
    local lines = build(NS)
    assertTrue(has(lines, "section") ~= nil and has(lines, "failed") ~= nil, dump(lines))
    assertTrue(has(lines, "[Filt] #2 castBy=") ~= nil, dump(lines))
    assertTrue(has(lines, "==== end:") ~= nil, dump(lines))
end)

test("diag: the report is capped below the console buffer and says it was truncated", function()
    local NS, mocks = fresh()
    for _ = 1, 60 do NS.ContainerManager.Create({ unit = "player", auraType = "HELPFUL", style = "bars" }) end
    local many = {}
    for i = 1, 150 do many[i] = aura(i, 774, "Rejuvenation") end
    withAuras(mocks, { ["player:HELPFUL"] = many, ["player:HARMFUL"] = many })
    local lines = build(NS)
    local max = NS.Diagnostics.MAX_LINES
    assertTrue(max <= 1200, "cap above 1200")
    local total = #lines
    assertTrue(total <= max, "the report ran to " .. total .. " lines")
    assertTrue(has(lines, "[Diag] truncated:") ~= nil, "no truncated line")
    assertEqual(count(lines, "[Aura] player+"), NS.Diagnostics.MAX_AURAS, "per-unit aura cap")
    local before = #NS.DebugLog.buffer
    NS.Diagnostics.Run()
    local copy = NS.DebugLog:CopyText()
    assertTrue(copy:find("diagnostic begin", 1, true) ~= nil, "the begin marker was evicted")
    assertTrue(#NS.DebugLog.buffer - before <= max, "more lines reached the console than the cap")
end)

test("diag: QueueSnapshot hands out copies, never the live queue", function()
    local NS, mocks = fresh()
    mocks.__aurasSecret = true
    NS.SetByPath("container.filter.castBy", "mine", 1)
    mocks.__fireTimers()
    local snap = NS.ContainerManager.QueueSnapshot()
    assertEqual(snap.ids[1], 1)
    snap.ids[1], snap.idSet[1] = nil, nil
    assertTrue(NS.ContainerManager.QueueSnapshot().idSet[1] == true, "the live queue was handed out")
end)
