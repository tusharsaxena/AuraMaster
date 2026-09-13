-- tests/test_render_coverage.lua — every Bars and Icons setting reaches a drawn region (B-5).
--
-- For each row of the Bars and Icons pages, on a container drawn in that style: write a value that
-- differs from the one in force, flush the apply, and compare what the dressed regions recorded
-- before and after the write. Twice: on a LIVE engine button, dressed the way the client dresses one
-- (Container:Restyle over the engine's frames), and on the PREVIEW placeholders (Preview.Show). A row
-- whose write changes nothing on one of them is a setting that silently does not apply there, and
-- the suite names it by path.
--
-- A row may declare `coverage = "engine-only"` or `coverage = "preview-only"`, with a comment saying
-- why, when the other side cannot show it by nature. An exemption is checked too: a row that does
-- reach the side it is exempt from has an exemption it no longer needs. Any other gap is a failure.
--
-- THE BASELINE turns on the toggles that gate other rows (the two borders, the running-out color),
-- so the rows they gate can show a change; each gate is itself tested by turning it off. The mock
-- formatter and curves record their inputs as plain data, so a binding handed one carries what it
-- was built from.

local T = _G.AM_TEST
local test, assertTrue, assertEqual = T.test, T.assertTrue, T.assertEqual
local R = dofile("tests/region_recorder.lua")
local fresh = dofile("tests/fresh_env.lua")

-- ── the environment ───────────────────────────────────────────────────────────────────────────

local FORMATTER_METHODS = { "SetDefaultAbbreviation", "SetRounding", "SetMinInterval", "SetCanRoundUpLastUnit",
    "SetCanRoundUpIntervals", "SetMaxInterval", "SetMaxIntervalCurve", "SetDesiredUnitCount" }

--- A plain table whose every listed method appends its arguments to `calls`: an object the
--- serializer below reads as the data it was built from.
local function recordingObject(methods)
    local o = { calls = {} }
    for _, name in ipairs(methods) do
        o[name] = function(self, ...)
            local n = #self.calls
            self.calls[n + 1] = { name, ... }
        end
    end
    return o
end

local function env()
    return fresh({ before = function(m)
        m.Enum = m.Enum or {}
        local E = m.Enum
        E.StatusBarTimerDirection = { ElapsedTime = 11, RemainingTime = 12 }
        E.StatusBarInterpolation = { Immediate = 21, ExponentialEaseOut = 22 }
        E.CustomAuraButtonDispelTypeTextureStyle = { Border = 31, PreserveAsset = 32 }
        E.SecondsFormatterInterval = { Seconds = 1, Minutes = 2, Hours = 3, Days = 4 }
        E.SecondsFormatterAbbreviation = { OneLetter = 1 }
        E.SecondsFormatterRounding = { RoundUp = 0, Truncate = 1 }
        E.DurationTextBindingProperty = { RemainingDuration = 1 }
        E.LuaCurveType = { Step = 1 }
        m.C_StringUtil = { CreateSecondsFormatter = function()
            local f = recordingObject(FORMATTER_METHODS)
            -- A placeholder's text reads the formatter it was built as: each format its own words.
            f.Format = function(self, seconds)
                local words = {}
                for i, c in ipairs(self.calls) do words[i] = c[1] .. tostring(c[2]) end
                return table.concat(words, "+") .. "@" .. tostring(seconds)
            end
            return f
        end }
        local function curve() return recordingObject({ "SetType", "AddPoint" }) end
        m.C_CurveUtil = { CreateCurve = curve, CreateColorCurve = curve }
        -- The harness loads no LibSharedMedia, so every media key would fall back to one path and a
        -- texture, font or border choice could never show. A registry of two keys per type, each its
        -- own path (Style.lua registers "Solid" into it at load).
        local media = {
            font = { ["Friz Quadrata TT"] = "Fonts\\FRIZQT__.TTF", ["Arial Narrow"] = "Fonts\\ARIALN.TTF" },
            statusbar = { Blizzard = "Interface\\TargetingFrame\\UI-StatusBar", Flat = "Interface\\Buttons\\WHITE8X8" },
            border = { None = "Interface\\None" },
        }
        m.__libs["LibSharedMedia-3.0"] = {
            Register = function(_, kind, key, path)
                media[kind] = media[kind] or {}
                media[kind][key] = path
            end,
            Fetch = function(_, kind, key) return media[kind] and media[kind][key] end,
            HashTable = function(_, kind) return media[kind] or {} end,
        }
    end })
end

-- ── recording ─────────────────────────────────────────────────────────────────────────────────

--- One argument as stable text: a named recorder by its name, a plain table by its contents (keys
--- sorted), any other object (a kit frame, whose state moves with things this suite does not write)
--- as "<obj>". Functions are skipped: a closure is a new value on every dress.
local function ser(v, names, depth)
    local t = type(v)
    if t ~= "table" then return t == "function" and "fn" or tostring(v) end
    if names[v] then return names[v] end
    if getmetatable(v) or depth > 5 then return "<obj>" end
    local keys = {}
    for k, x in pairs(v) do
        if type(x) ~= "function" then keys[#keys + 1] = k end
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for i, k in ipairs(keys) do parts[i] = tostring(k) .. "=" .. ser(v[k], names, depth + 1) end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function serLog(r, names)
    local out = {}
    for i, e in ipairs(r.__log) do
        local args = {}
        for j = 1, e.args.n do args[j] = ser(e.args[j], names, 0) end
        out[i] = e.name .. "(" .. table.concat(args, ",") .. ")"
    end
    return table.concat(out, ";")
end

--- Every recorder that belongs to one dressed element: the element, its regions, a bar's edge.
local function recordersOf(frame)
    local list = { frame }
    for _, r in pairs(frame.__am or {}) do
        if type(r) == "table" then
            list[#list + 1] = r
            local edge = rawget(r, "__edge")
            if edge then list[#list + 1] = edge end
        end
    end
    return list
end

--- Swap each region of a dressed element for a recorder, in place (the table stays the one
--- Style.RegionsFor knows), and name every recorder for the serializer.
local function adopt(frame, prefix, names)
    names[frame] = prefix
    for k, v in pairs(frame.__am) do
        if type(v) == "table" then
            local r = R()
            frame.__am[k] = r
            names[r] = prefix .. "." .. k
        end
    end
end

--- What one element recorded, as one string, regions in a fixed order.
local function signature(frame, names)
    local keys = {}
    for k, v in pairs(frame.__am or {}) do
        if type(v) == "table" then
            keys[#keys + 1] = k
            local edge = rawget(v, "__edge")
            if edge and not names[edge] then names[edge] = names[v] .. ".edge" end
        end
    end
    table.sort(keys)
    local parts = { "frame:" .. serLog(frame, names) }
    for _, k in ipairs(keys) do
        local r = frame.__am[k]
        parts[#parts + 1] = k .. ":" .. serLog(r, names)
        local edge = rawget(r, "__edge")
        if edge then parts[#parts + 1] = k .. ".edge:" .. serLog(edge, names) end
    end
    return table.concat(parts, "\n")
end

-- ── the rig: one container of the page's style, a live button and its placeholders ────────────

local function rig(style)
    local NS = env()
    local c
    for _, k in ipairs(NS.Database.GetContainers()) do
        if k.style == style then
            c = k
            break
        end
    end
    assertTrue(c ~= nil, "a starter container drawn as " .. style)
    local inst = NS.ContainerManager.instances[c.id]
    local k = { NS = NS, c = c, inst = inst, style = style, names = {}, button = R() }
    inst.previewFactory = function() return R() end
    return k
end

--- Hand the live button to the engine the container holds now, so Restyle dresses it.
local function plant(k)
    local engine = k.inst.engine
    for _, g in ipairs(k.inst.plan.groups) do engine.__frames[g.key] = {} end
    engine.__frames[k.inst.plan.groups[1].key] = { k.button }
    return engine
end

local function placeholders(k)
    return k.inst.previewPools[k.style].active
end

--- One apply, then one preview dress. Raises when the apply raised or the engine was rebuilt (the
--- button would then be dressed by nobody, and every row would read as reaching nothing).
local function applyAndDress(k)
    local NS = k.NS
    local engine = plant(k)
    NS.ContainerManager.RequestApply(k.c.id)
    NS.ContainerManager.FlushPending()
    assertTrue(k.inst.engine == engine, "the engine was updated, not rebuilt")
    k.inst.previewDirty = true
    NS.Preview.Show(k.inst)
end

--- The first dress builds each element's regions; they are swapped for recorders once, here.
local function prime(k)
    applyAndDress(k)
    adopt(k.button, "live", k.names)
    for i, f in ipairs(placeholders(k)) do adopt(f, "preview" .. i, k.names) end
end

local function clearLogs(k)
    local frames = { k.button }
    for _, f in ipairs(placeholders(k)) do frames[#frames + 1] = f end
    for _, f in ipairs(frames) do
        for _, r in ipairs(recordersOf(f)) do r.__log = {} end
    end
end

--- What the live button and the placeholders record over one apply.
local function record(k)
    clearLogs(k)
    applyAndDress(k)
    local live = signature(k.button, k.names)
    assertTrue(live:find("SetSize", 1, true) ~= nil, "the live button was dressed")
    local prev = {}
    for i, f in ipairs(placeholders(k)) do prev[i] = signature(f, k.names) end
    return live, table.concat(prev, "\n--\n")
end

-- ── values ────────────────────────────────────────────────────────────────────────────────────

--- The keys a string row offers, sorted: an NS.Choices list, a plain map, or a function of either.
local function choices(row)
    local v = row.values
    if type(v) == "function" then v = v() end
    local out = {}
    for key, x in pairs(v or {}) do
        out[#out + 1] = (type(x) == "table" and x.value ~= nil) and x.value or key
    end
    table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
    return out
end

local DISTINCT = { r = 0.13, g = 0.57, b = 0.31, a = 0.66 }

--- A legal value for `row` that differs from `cur`.
local function differing(row, cur)
    if row.type == "bool" then return not cur end
    if row.type == "number" then
        if cur ~= row.max then return row.max end
        return row.min
    end
    if row.type == "color" then return DISTINCT end
    for _, v in ipairs(choices(row)) do
        if v ~= cur then return v end
    end
    return nil
end

-- The toggles other rows only show under. On in the baseline; each is tested by turning it off.
local GATES = {
    bars = { borderShow = true, iconBorderShow = true, expiringColorOn = true },
    icons = { borderShow = true, expiringColorOn = true },
}

--- Every row of `page` whose write leaves a side unchanged, as "<path> (<side>)", plus exemptions
--- the row no longer needs.
local function gaps(page)
    local k = rig(page)
    local NS = k.NS
    local baseline = NS.Database.Merge(NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE[page]), GATES[page])
    prime(k)
    local out = {}
    local rows = NS.SchemaForPage(page)
    assertTrue(#rows > 0, page .. " has rows")
    for _, row in ipairs(rows) do
        k.c[page] = NS.Database.DeepCopy(baseline)
        local liveA, prevA = record(k)
        local value = differing(row, NS.GetSetting(row.path, k.c.id))
        assertTrue(value ~= nil, row.path .. ": a value to write")
        assertTrue(NS.SetByPath(row.path, value, k.c.id), row.path .. ": the write is accepted")
        local liveB, prevB = record(k)
        local cov = row.coverage
        assertTrue(cov == nil or cov == "engine-only" or cov == "preview-only", row.path .. ": a known coverage")
        local liveMoved, prevMoved = liveA ~= liveB, prevA ~= prevB
        if not liveMoved and cov ~= "preview-only" then out[#out + 1] = row.path .. " (live)" end
        if not prevMoved and cov ~= "engine-only" then out[#out + 1] = row.path .. " (preview)" end
        if cov == "engine-only" and prevMoved then out[#out + 1] = row.path .. " (reaches the preview; drop engine-only)" end
        if cov == "preview-only" and liveMoved then out[#out + 1] = row.path .. " (reaches the engine; drop preview-only)" end
    end
    return out, #rows
end

-- red under: any Style* path that reads a bars leaf without drawing it (a row the page offers and
-- no region shows), e.g. applySurfaces dropping the spark's SetVertexColor
test("coverage: every Bars row reaches a drawn region, on a live button and on the preview", function()
    local out, n = gaps("bars")
    assertTrue(n >= 50, "the whole Bars page was walked")
    assertEqual(table.concat(out, "; "), "", "rows that reach no region")
end)

-- red under: any Style* path that reads an icons leaf without drawing it, e.g. applyCooldown
-- dropping SetReverse
test("coverage: every Icons row reaches a drawn region, on a live button and on the preview", function()
    local out, n = gaps("icons")
    assertTrue(n >= 30, "the whole Icons page was walked")
    assertEqual(table.concat(out, "; "), "", "rows that reach no region")
end)
