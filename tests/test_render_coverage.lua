-- tests/test_render_coverage.lua — every Bars, Icons and Text setting reaches a drawn region (B-5).
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
-- THE BASELINE turns on the toggles that gate other rows (the two borders, the running-out color, the
-- text glow), so the rows they gate can show a change; each gate is itself tested by turning it off.
-- The mock formatter and curves record their inputs as plain data, so a binding handed one carries
-- what it was built from. A text glow set is a plain array of copy strings, each swapped and read as
-- a region of its own.
--
-- A TEXT CONTAINER'S LIVE SIDE is its main button and one twin button (the glyph glow's twin engines,
-- modules/Style_TextGlow.lua), the twin dressed here as twin 1 until the container builds its twins
-- (TG-11). Three glow rows reach the live side only through the twin ENGINES themselves, not a twin
-- button's dress: `glow` rebuilds them and `glowX` / `glowY` move their holders. They are listed in
-- TWIN_ENGINE_ONLY below, held to exactly that list.

local T = _G.AM_TEST
local test, assertTrue, assertEqual = T.test, T.assertTrue, T.assertEqual
local R = dofile("tests/region_recorder.lua")
local fresh = dofile("tests/fresh_env.lua")

--- Append `v` to list `t`. The length sits on a line of its own: lizard reads a `#` as a comment,
--- a blind spot the vendored kit's test_lizard_sighted gate covers.
local function push(t, v)
    local n = #t
    t[n + 1] = v
end

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
        -- The client's dispel palette, so a debuff placeholder can tint its dispel edge
        -- (NS.Compat.SetAuraBorderColor) and the Icons dispel toggle reaches the preview.
        m.DebuffTypeColor = { Magic = { r = 0.2, g = 0.6, b = 1 }, Curse = { r = 0.6, g = 0, b = 1 },
            Disease = { r = 0.6, g = 0.4, b = 0 }, Poison = { r = 0, g = 0.6, b = 0 } }
        E.SecondsFormatterInterval = { Seconds = 1, Minutes = 2, Hours = 3, Days = 4 }
        E.SecondsFormatterAbbreviation = { OneLetter = 1 }
        E.SecondsFormatterRounding = { RoundUp = 0, Truncate = 1 }
        E.DurationTextBindingProperty = { RemainingDuration = 1, TotalDuration = 2, ElapsedDuration = 3,
            RemainingPercent = 4, ElapsedPercent = 5 }
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
        -- The Text style's rule formatters and prebuilt duration bindings record what they were
        -- built with, like the seconds formatter above.
        m.C_StringUtil.CreateNumericRuleFormatter = function() return recordingObject({ "SetBreakpoints" }) end
        m.C_DurationUtil = { CreateDurationTextBinding = function()
            return recordingObject({ "SetZeroDurationText", "SetExpiredText", "SetUpdateInterval" })
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
        if type(x) ~= "function" then push(keys, k) end
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

--- Whether `v` is one of this suite's recorders. A text element also keeps plain client objects on
--- `__am` (its prebuilt duration bindings); only what records is read.
local function isRecorder(v)
    return type(v) == "table" and rawget(v, "__log") ~= nil
end

--- The recorders a region owns beside itself, each with the suffix it is named by: a bar's moving
--- edge, and a border's four Solid strips (modules/Style_Border.lua's ApplyBorder, B2-3).
local function ownedBy(r)
    local out = {}
    local edge = rawget(r, "__edge")
    if edge then push(out, { ".edge", edge }) end
    for i, strip in ipairs(rawget(r, "__amStrips") or {}) do
        if isRecorder(strip) then push(out, { ".strip" .. i, strip }) end
    end
    return out
end

--- Whether `k`, `v` on `__am` is one of the text glow's sets (modules/Style_TextGlow.lua): a plain
--- array of one piece's copy strings under `glow1`, `glow2`, ..., each copy a region of its own.
local function isGlowSet(k, v)
    return type(k) == "string" and k:match("^glow%d+$") ~= nil and type(v) == "table" and not isRecorder(v)
end

--- A glow set's copies, in ring order, each as { suffix, recorder }.
local function glowParts(set)
    local out = {}
    for j, r in ipairs(set) do
        if isRecorder(r) then push(out, { "." .. j, r }) end
    end
    return out
end

--- Every recorder that belongs to one dressed element: the element, its regions and what they own,
--- and the copies of its glow sets.
local function recordersOf(frame)
    local list = { frame }
    for k, r in pairs(frame.__am or {}) do
        if isRecorder(r) then
            push(list, r)
            for _, o in ipairs(ownedBy(r)) do push(list, o[2]) end
        elseif isGlowSet(k, r) then
            for _, o in ipairs(glowParts(r)) do push(list, o[2]) end
        end
    end
    return list
end

--- Swap each region of a dressed element for a recorder, in place (the table stays the one
--- Style.RegionsFor knows), and name every recorder for the serializer. A glow set stays the set it
--- is, and each of its copies is swapped instead.
local function adopt(frame, prefix, names)
    names[frame] = prefix
    for k, v in pairs(frame.__am) do
        if isGlowSet(k, v) then
            for part in pairs(v) do
                local r = R()
                v[part] = r
                names[r] = prefix .. "." .. k .. "." .. part
            end
        elseif type(v) == "table" then
            local r = R()
            frame.__am[k] = r
            names[r] = prefix .. "." .. k
        end
    end
end

--- What one element recorded, as one string, regions in a fixed order, a glow set's copies each
--- under its set's key.
local function signature(frame, names)
    local keys = {}
    for k, v in pairs(frame.__am or {}) do
        if isGlowSet(k, v) then
            for _, o in ipairs(glowParts(v)) do
                if not names[o[2]] then names[o[2]] = k .. o[1] end
                push(keys, k .. o[1])
            end
        elseif isRecorder(v) then
            push(keys, k)
            for _, o in ipairs(ownedBy(v)) do
                if not names[o[2]] then names[o[2]] = names[v] .. o[1] end
            end
        end
    end
    table.sort(keys)
    local parts = { "frame:" .. serLog(frame, names) }
    for _, k in ipairs(keys) do
        local set, part = k:match("^(glow%d+)%.(.+)$")
        local r = set and frame.__am[set][tonumber(part)] or frame.__am[k]
        push(parts, k .. ":" .. serLog(r, names))
        for _, o in ipairs(ownedBy(r)) do push(parts, k .. o[1] .. ":" .. serLog(o[2], names)) end
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
    local k = { NS = NS, c = c, inst = inst, style = style, names = {}, button = R(),
        twin = style == "text" and R() or nil }
    inst.previewFactory = function() return R() end
    if style == "text" then
        -- A measurer that reads, so Size to fit can size the line (the harness's own font string
        -- answers no width, and every autosize would fall back to the stored size).
        local fs = R()
        fs.__answer.GetStringWidth = function(self)
            local last = self:__last("SetText")
            return (last and tostring(last[1]):len() or 0) * 6 + 2
        end
        NS.Style.__measurer = function() return fs end
    end
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

--- Whether structure key `s` has the text glow on (Style.StructureKey).
local function glowsIn(s)
    return tostring(s):find(":glow", 1, true) ~= nil
end

--- One apply, then one preview dress. Raises when the apply raised or the engine was rebuilt for
--- anything but the glow toggle (the button would then be dressed by nobody, and every row would read
--- as reaching nothing). The toggle rebuilds by design (its twins, modules/Container_Twins.lua): the
--- new engine dresses each button it creates, which handing the button to it and restyling stands for.
local function applyAndDress(k)
    local NS = k.NS
    local engine = plant(k)
    local was = k.inst.structure
    NS.ContainerManager.RequestApply(k.c.id)
    NS.ContainerManager.FlushPending()
    if k.inst.engine ~= engine and glowsIn(was) ~= glowsIn(k.inst.structure) then
        plant(k)
        k.inst:Restyle(k.c)
    end
    assertTrue(k.inst.engine == engine or glowsIn(was) ~= glowsIn(k.inst.structure),
        "the engine was updated, not rebuilt")
    if k.twin then NS.Style.Element(k.twin, k.c, true, k.inst.classColor, 1) end
    k.inst.previewDirty = true
    NS.Preview.Show(k.inst)
end

--- The first dress builds each element's regions; they are swapped for recorders once, here.
local function prime(k)
    applyAndDress(k)
    adopt(k.button, "live", k.names)
    if k.twin then adopt(k.twin, "twin", k.names) end
    for i, f in ipairs(placeholders(k)) do adopt(f, "preview" .. i, k.names) end
end

local function clearLogs(k)
    local frames = { k.button, k.twin }
    for _, f in ipairs(placeholders(k)) do push(frames, f) end
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
    if k.twin then live = live .. "\n--twin--\n" .. signature(k.twin, k.names) end
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
        push(out, (type(x) == "table" and x.value ~= nil) and x.value or key)
    end
    table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
    return out
end

local DISTINCT = { r = 0.13, g = 0.57, b = 0.31, a = 0.66 }

-- A free-text row has no list to pick from, so it names the value it is walked with: the Text
-- baseline's template (GATES below), with its bracket text changed and its shape kept (a new shape
-- builds a new chain of font strings, which a recorder swapped in by `adopt` would never see).
local SAMPLES = { ["container.text.template"] = "$spellname$[ y$stacks$][ <$dispeltype$>][ ~ $remainingduration$]" }

--- A legal value for `row` that differs from `cur`.
local function differing(row, cur)
    if SAMPLES[row.path] then return SAMPLES[row.path] end
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

-- The toggles other rows only show under. On in the baseline; each is tested by turning it off. The
-- "Use the skin's ..." companions (AM-03) are the other way about: OFF in the baseline, so the font
-- and texture pickers they govern draw the stored pick and show a change; each companion is tested
-- by turning it on, which draws the skin's face or texture in place of that pick.
-- Each stored value below is one no skin draws, so a companion turned on shows as a change: the
-- template's own picks and colors are now Ka0s Default's.
local MINE = { r = 0.3, g = 0.4, b = 0.5, a = 1 }
local OWN_FONT = { font = "Friz Quadrata TT", fontFromSkin = false, fontColor = MINE, fontColorFromSkin = false,
    fontShadow = true, fontShadowFromSkin = false }
local GATES = {
    bars = { borderShow = true, iconBorderShow = true, expiringColorOn = true,
        barTexture = "Blizzard", bgTexture = "Blizzard", barColor = MINE, bgColor = MINE,
        barTextureFromSkin = false, bgTextureFromSkin = false, barColorFromSkin = false, bgColorFromSkin = false,
        borderSize = 3, borderColor = MINE, borderStyleFromSkin = false, borderColorFromSkin = false,
        iconBorderSize = 3, iconBorderColor = MINE, iconBorderStyleFromSkin = false, iconBorderColorFromSkin = false,
        name = OWN_FONT, time = OWN_FONT, stacks = OWN_FONT },
    icons = { borderShow = true, expiringColorOn = true, borderSize = 3, borderColor = MINE,
        borderStyleFromSkin = false, borderColorFromSkin = false, time = OWN_FONT, stacks = OWN_FONT },
    -- Right, so Center (a multi-piece template stacks in rows, feedback #1) still moves the chain;
    -- an icon, so its rows reach one; a $dispeltype$ piece, so coloring its word has a word to color
    -- (feedback #7). Size to fit off, so Width and Height reach the element; turning it on then shows
    -- through the measurer rig() installs (batch 8, AS-1). The glow on, so its rows reach its sets
    -- (TG-03).
    text = { autoSize = false, icon = "LEFT", iconBorderShow = true, expiringColorOn = true, justifyH = "RIGHT",
        iconBorderSize = 3, iconBorderColor = MINE, iconBorderStyleFromSkin = false, iconBorderColorFromSkin = false,
        glowColor = MINE, glowColorFromSkin = false, glow = true, font = OWN_FONT,
        template = "$spellname$[ x$stacks$][ ($dispeltype$)][ - $remainingduration$]" },
}

-- The glow rows that reach the live side through the twin engines alone, never a button's dress (the
-- header's TEXT CONTAINER'S LIVE SIDE): no live gap is reported for them, and one whose write does move
-- a live button is reported, so the list cannot outlive its reason.
local TWIN_ENGINE_ONLY = { ["container.text.glow"] = true, ["container.text.glowX"] = true,
    ["container.text.glowY"] = true }

--- Every row of `page` whose write leaves a side unchanged, as "<path> (<side>)", plus exemptions
--- the row no longer needs.
local function gaps(page)
    local k = rig(page)
    local NS = k.NS
    local baseline = NS.Database.Merge(NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE[page]), GATES[page])
    -- Primed on the baseline, applied once first: a baseline template of another shape than the
    -- stored one rebuilds the engine (Style.StructureKey), which prime's apply would refuse.
    k.c[page] = NS.Database.DeepCopy(baseline)
    NS.ContainerManager.RequestApply(k.c.id)
    NS.ContainerManager.FlushPending()
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
        local twinOnly = TWIN_ENGINE_ONLY[row.path]
        if twinOnly and liveMoved then push(out, row.path .. " (moves a live button; drop TWIN_ENGINE_ONLY)") end
        if not liveMoved and cov ~= "preview-only" and not twinOnly then push(out, row.path .. " (live)") end
        if not prevMoved and cov ~= "engine-only" then push(out, row.path .. " (preview)") end
        if cov == "engine-only" and prevMoved then push(out, row.path .. " (reaches the preview; drop engine-only)") end
        if cov == "preview-only" and liveMoved then push(out, row.path .. " (reaches the engine; drop preview-only)") end
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

-- red under: any Style* path that reads a text leaf without drawing it, e.g. applyLoops dropping
-- the bounce's SetOffset, or dressPieces skipping the literal pieces' font
test("coverage: every Text row reaches a drawn region, on a live button and on the preview", function()
    local out, n = gaps("text")
    assertTrue(n >= 30, "the whole Text page was walked")
    assertEqual(table.concat(out, "; "), "", "rows that reach no region")
end)
