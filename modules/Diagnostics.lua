local _, NS = ...

-- modules/Diagnostics.lua — `/am diagnostics` and `/am debug diagnostics`: a one-shot diagnostic
-- report in the debug console
-- (batch 8 DG-1..DG-4; docs/debug.md is the reader's guide).
--
-- WHAT IT IS FOR. "My settings did not apply" and "this container shows the wrong auras" are the two
-- reports this addon gets, and both need the same picture: the auras the client holds, what every
-- container was told to draw, whether that is still what its settings say, and what it drew. The
-- report writes that picture, one line per fact, where the Copy button can hand it back.
--
-- THE FRAME IS THE LIBRARY'S (debug-logging-§14, DR-AM-02). LibKa0s's diagnostics helper
-- (DebugLog 14.1, DebugLogDiagnostics.lua) owns everything around the sections: the branded begin
-- and end markers, the identity header (this addon's initSummary, the client, locale, the debug
-- flag, the two combat reads, the running LibKa0s minors), one pcall per section, the secret-safe
-- formatting and escape stripping, the cap (lib.DIAG_MAX_LINES clamped below the console buffer)
-- with its truncated line, the ungated append that never clears and never touches the flag, the
-- reveal and the one chat line. core/DebugLogSetup.lua hands the helper Diag.Sections through the
-- descriptor's `diagnostics`; the dispatcher calls NS.DebugLog:RunDiagnostics(). The body lines
-- are diagnostic English, not routed through NS.L, like every trace and the [Init] summary.
--
-- SECRET-SAFE (DG-3, B9 DX-1). While auras are secret (Compat.AurasAreSecret: any combat, an
-- encounter, a key, a match) every aura read raises and so does touching an engine button, so the
-- report makes NO aura API call and NO per-button call then; it reads the engine's per-group frame
-- count alone. "Auras are not secret" does NOT mean "an engine button is readable": out of combat a
-- button's IsShown can still answer a SECRET boolean (docs/midnight-quirks.md, "An engine button's
-- shown state is secret out of combat"), so every value read off a button is tested with
-- Secrets.CanAccess before it is compared, and an unknowable one prints `?`. The writer stringifies
-- every argument through NS.SafeToString before a format sees it, every number is tested with
-- Secrets.IsReadableNumber before arithmetic, and every plan group, every group's button listing and
-- the predictions run under their own out:section pcall, so one failure costs one line.
--
-- CAPPED (DG-4). The helper caps the whole report; this file caps its own lists: MAX_AURAS per unit
-- and filter, MAX_IDS per id list. A list cap that bites sets the writer's per-list flag
-- (`out.capsHit`), which the helper's `truncated` line reports.
--
-- READ-ONLY. No settings write, no apply request, no Set/Add/Clear on a button (each one re-runs the
-- engine's ApplyAuraInstance).

NS.Diagnostics = NS.Diagnostics or {}
local Diag = NS.Diagnostics

Diag.MAX_AURAS = 100
Diag.MAX_IDS = 40

local FILTERS = { "HELPFUL", "HARMFUL" }

-- The auras each run read, keyed "unit:FILTER", so the predictions reuse what the aura section read.
-- Keyed weakly by the run's writer (`out`), so a cache lives exactly as long as its report and a run
-- can never see another's reads, however its sections were handed to the helper.
local auraCaches = setmetatable({}, { __mode = "k" })

local function str(v)
    return NS.SafeToString(v)
end

local function yesno(v)
    return v and "yes" or "no"
end

--- A list cap bit: the helper's truncated line reports it as `per-list caps hit=yes`.
local function flagCap(out)
    out.capsHit = true
end

-- ---------------------------------------------------------------------------
-- Readers
-- ---------------------------------------------------------------------------

local function unitExists(unit)
    local fn = _G.UnitExists
    if type(fn) ~= "function" then return unit == "player" end
    local ok, yes = pcall(fn, unit)
    return ok and yes == true
end

--- The unit's auras under `filter`, capped at MAX_AURAS, or nil and why not. Never called while
--- auras are secret: the caller has already said so, and this checks again rather than trust it.
local function readAuras(out, unit, filter)
    if NS.Compat.AurasAreSecret() then return nil, "secret" end
    local api = _G.C_UnitAuras
    if not (api and api.GetAuraDataByIndex) then return nil, "unavailable" end
    local list = {}
    for i = 1, Diag.MAX_AURAS + 1 do
        local ok, a = pcall(api.GetAuraDataByIndex, unit, i, filter)
        if not ok then return nil, "read failed: " .. str(a) end
        if type(a) ~= "table" then break end
        if i > Diag.MAX_AURAS then
            flagCap(out)
            break
        end
        list[i] = a
    end
    return list
end

--- readAuras, remembered for this run, so the predictions reuse what the aura section read.
local function cachedAuras(out, unit, filter)
    local cache = auraCaches[out]
    if not cache then
        cache = {}
        auraCaches[out] = cache
    end
    local key = unit .. ":" .. filter
    local hit = cache[key]
    if hit then return hit.list, hit.why end
    local list, why = readAuras(out, unit, filter)
    cache[key] = { list = list, why = why }
    return list, why
end

local function spellName(id)
    local ok, name = pcall(NS.Compat.GetSpellInfo, id)
    if ok and type(name) == "string" then return name end
    return "?"
end

local function countKeys(t)
    local n = 0
    if type(t) == "table" then
        for _ in pairs(t) do n = n + 1 end
    end
    return n
end

-- ---------------------------------------------------------------------------
-- The state section. The helper's identity header comes first: version, schema, profile and
-- container count from initSummary, then the client, locale, debug flag and combat reads.
-- ---------------------------------------------------------------------------

local function profileOf()
    local db = NS.db
    return (db and db.profile) or {}
end

--- The held stand-down keys, comma-joined ("perf"), "-" for none, or "?" without the lifecycle
--- library.
local function holdsText()
    local lc = NS.lifecycle
    if not (lc and lc.Holds) then return "?" end
    local text = table.concat(lc:Holds(), ",")
    if text == "" then return "-" end
    return text
end

--- The combat reads are the helper header's, each pcall'd there, so they are not repeated here.
local function stateLine(out)
    local p = profileOf()
    local _, selected = NS.ActiveContainer()
    out:add("Diag", "state: enabled=%s stoodDown=%s disabledHold=%s holds=%s locked=%s testMode=%s "
        .. "visibility=%s aurasSecret=%s selected=#%s",
        NS.EnabledStored(), NS.IsStoodDown(), NS.IsDisabled(), holdsText(), p.locked, NS.State.testMode,
        p.visibility, NS.Compat.AurasAreSecret(), selected)
end

--- Why the addon is not running, in plain words, or nil while it runs (batch 10 F8).
local function downReason()
    if NS.IsDisabled() then return "addon disabled" end
    if NS.IsStoodDown() then return "addon stood down (holds: " .. holdsText() .. ")" end
    return nil
end

--- Whether any container has an applied plan: a login made while down built none.
local function anyBuilt()
    for _, inst in pairs(NS.ContainerManager.instances) do
        if inst.plan then return true end
    end
    return false
end

--- One plain line while the addon is not running (batch 10 F8): the state flags alone read like a bug.
local function downLine(out)
    local why = downReason()
    if not why then return end
    if anyBuilt() then
        out:add("Diag", "%s: containers are hidden and not updated; the plan lines are from the last apply", why)
    else
        out:add("Diag", "%s: containers are not built; predictions only", why)
    end
end

local function queueLine(out)
    local q = NS.ContainerManager.QueueSnapshot()
    local ids = {}
    for i, id in ipairs(q.ids) do ids[i] = str(id) end
    out:add("Diag", "apply queue: all=%s ids=[%s] scheduled=%s notice=%s mustDefer=%s",
        q.all, table.concat(ids, ","), q.scheduled, q.notice or "-", q.mustDefer)
end

local function countsLine(out)
    local db = NS.db
    local g = (db and db.global) or {}
    local p = profileOf()
    local slots = {}
    for slot, on in pairs(type(p.enchantSlots) == "table" and p.enchantSlots or {}) do
        if on then
            local n = #slots
            slots[n + 1] = str(slot)
        end
    end
    table.sort(slots)
    out:add("Diag", "timed spells learned=%s, category spell edits in %s list(s), user categories=%s, "
        .. "enchant slots=%s", countKeys(g.timedSpells), countKeys(p.categorySpells),
        countKeys(p.userCategories), table.concat(slots, ","))
end

function Diag.Header(out)
    stateLine(out)
    downLine(out)
    queueLine(out)
    countsLine(out)
end

-- ---------------------------------------------------------------------------
-- Non-default settings
-- ---------------------------------------------------------------------------

--- A value as `/am get` prints it. Its color and texture escapes are left in: the writer strips
--- every part it joins, so the Copy text is plain either way.
local function formatValue(row, v)
    local fmt = NS.Slash and NS.Slash.FormatValue
    if type(fmt) == "function" then
        local ok, s = pcall(fmt, row, v)
        if ok then return str(s) end
    end
    return str(v)
end

local function differs(path, containerId)
    local Sig = NS.FilterCompiler.Signature
    local v = NS.GetSetting(path, containerId)
    return Sig(v) ~= Sig(NS.DefaultFor(path)), v
end

local function isProfileRow(row)
    return type(row.path) == "string" and not row.sessionOnly and not row.hidden
        and row.path:find("container.", 1, true) ~= 1
end

function Diag.ProfileConfig(out)
    local parts = {}
    for _, row in ipairs(NS.Schema) do
        if isProfileRow(row) then
            local changed, v = differs(row.path)
            if changed then
                local n = #parts
                parts[n + 1] = row.path .. "=" .. formatValue(row, v)
            end
        end
    end
    out:joined("Cfg", "profile non-default:", parts)
end

-- ---------------------------------------------------------------------------
-- Auras
-- ---------------------------------------------------------------------------

local function leftOf(exp)
    local S = NS.Secrets
    if not S.IsReadableNumber(exp) then return "-" end
    local now = GetTime()
    if not S.IsReadableNumber(now) or exp <= 0 then return "-" end
    return ("%.1f"):format(exp - now)
end

local function auraLine(out, unit, filter, i, a)
    -- helpful/harmful from the filter queried, never from a test of a possibly secret isHelpful.
    local sign = (filter == "HARMFUL") and "-" or "+"
    out:add("Aura", '%s%s #%s inst=%s id=%s "%s" dispel=%s src=%s mine=%s dur=%s left=%s stacks=%s '
        .. "boss=%s steal=%s", unit, sign, i, a.auraInstanceID, a.spellId, a.name, a.dispelName,
        a.sourceUnit, a.isFromPlayerOrPlayerPet, a.duration, leftOf(a.expirationTime), a.applications,
        a.isBossAura, a.isStealable)
end

local function unitAuras(out, unit, secret)
    if not unitExists(unit) then
        out:add("Unit", "%s: none", unit)
        return
    end
    if secret then
        out:add("Unit", "%s: unreadable (auras are secret - run /am diagnostics out of combat)", unit)
        return
    end
    for _, filter in ipairs(FILTERS) do
        local list, why = cachedAuras(out, unit, filter)
        if not list then
            out:add("Unit", "%s %s: %s", unit, filter, why)
        else
            local n = #list
            out:add("Unit", "%s %s: %s aura(s)", unit, filter, n)
            for i, a in ipairs(list) do auraLine(out, unit, filter, i, a) end
        end
    end
end

function Diag.Auras(out)
    local secret = NS.Compat.AurasAreSecret()
    for _, unit in ipairs(NS.Constants.UNITS) do
        out:section("auras " .. unit, unitAuras, unit, secret)
    end
end

-- ---------------------------------------------------------------------------
-- Containers: identity and flags
-- ---------------------------------------------------------------------------

--- A follower's join (batch 11 G7): the two points in effect, each "(auto)" or "(picked)", and the
--- pair's classification, one of the nine sides (modules/Anchors.lua's AttachEdge) or "free".
local function joinOf(c)
    local A = NS.Anchors
    local point, rel, pointAuto, relAuto = A.AttachPoints(c)
    local token = A.AttachEdge(c)
    return ("point=%s(%s) relPoint=%s(%s) join=%s"):format(str(point), pointAuto and "auto" or "picked",
        str(rel), relAuto and "auto" or "picked", str(token or "free"))
end

local function attachOf(c)
    local a = type(c.attach) == "table" and c.attach or {}
    if a.mode == "container" then return "container#" .. str(a.container) .. " " .. joinOf(c) end
    if a.mode == "frame" then return "frame:" .. str(a.frame) end
    return str(a.mode or "screen")
end

local function instFlags(x)
    local inst, CM = x.inst, NS.ContainerManager
    if not inst then return "instance=none" end
    local ok, show = pcall(inst.ShouldShow, inst)
    local retiredList, enchantList = inst.retired or {}, inst.enchantFrames or {}
    local retired = #retiredList
    local enchants = #enchantList
    return ("engine=%s shows=%s parked=%s staleData=%s classStale=%s retired=%s enchantFrames=%s "
        .. "dormant=%s retiring=%s"):format(yesno(inst.engine), ok and yesno(show) or "?",
        yesno(inst.parked), yesno(inst.staleData), yesno(inst.classStale), retired, enchants,
        yesno(CM.__dormant()[x.id]), yesno(CM.__retiring()[x.id]))
end

local function contLine(out, x)
    local c = x.c
    out:add("Cont", '#%s "%s" unit=%s %s style=%s enabled=%s attach=%s | %s', c.id, c.name, c.unit,
        c.auraType, c.style, c.enabled, attachOf(c), instFlags(x))
end

-- ---------------------------------------------------------------------------
-- Containers: filters, in full
-- ---------------------------------------------------------------------------

local function sortedIds(set)
    local ids = {}
    for id in pairs(type(set) == "table" and set or {}) do
        if type(id) == "number" then
            local n = #ids
            ids[n + 1] = id
        end
    end
    table.sort(ids)
    return ids
end

local function listLine(out, id, name, set)
    local ids = sortedIds(set)
    local named = {}
    for i, spell in ipairs(ids) do
        if i > Diag.MAX_IDS then
            flagCap(out)
            break
        end
        named[i] = str(spell) .. " " .. spellName(spell)
    end
    local total = #ids
    out:add("Filt", "#%s %s(%s)=[%s]", id, name, total, table.concat(named, ", "))
end

local function categoryLine(out, c, f)
    local states = type(f.categories) == "table" and f.categories or {}
    local hide, show = {}, 0
    for _, def in ipairs(NS.Categories.For(c.auraType)) do
        if states[def.key] == "hide" then
            local n = #hide
            hide[n + 1] = NS.Categories.LabelOf(def)
        else
            show = show + 1
        end
    end
    out:add("Filt", "#%s categories hide=[%s] show=%s other(s)", c.id, table.concat(hide, ", "), show)
end

local function filtLines(out, x)
    local c = x.c
    local f = c.filter
    out:add("Filt", "#%s castBy=%s duration=%s maxDuration=%s sort=%s/%s maxAuras=%s "
        .. "hidePermanentEnchants=%s", c.id, f.castBy, f.durationMode, f.maxDuration, f.sortMethod,
        f.sortDirection, f.maxAuras, f.hidePermanentEnchants)
    categoryLine(out, c, f)
    listLine(out, c.id, "whitelist", f.whitelist)
    listLine(out, c.id, "blacklist", f.blacklist)
end

-- ---------------------------------------------------------------------------
-- Containers: the applied plan, and whether it is stale
-- ---------------------------------------------------------------------------

--- Why container `x` has no applied plan (batch 10 F8): the addon is down, the client has no aura
--- engine, the manager holds no instance for it, or its first apply has not run.
local function notBuiltReason(x)
    if NS.IsDisabled() then return "addon disabled" end
    if NS.IsStoodDown() then return "addon stood down: " .. holdsText() end
    if not NS.Compat.HasAuraContainer() then return "no aura container API" end
    if not x.inst then return "no instance" end
    return "not applied yet"
end

--- The staleness verdict: the queue (every deferred change) against the plan comparison (the filter
--- dimension). DRIFT is the one that points at a real bug: the settings moved, nothing was queued.
local function verdictOf(x, fresh)
    local inst, q = x.inst, x.q
    if not (inst and inst.plan) then return "not built (" .. notBuiltReason(x) .. ")" end
    local Sig = NS.FilterCompiler.Signature
    if Sig(inst.plan) == Sig(fresh) then return "plan in sync" end
    if q.all or q.idSet[x.id] then
        return "PENDING (" .. (q.notice or (q.mustDefer and "deferred") or "scheduled") .. ")"
    end
    return "DRIFT: settings changed but no apply was requested"
end

local function numText(v)
    if v == math.huge then return "inf" end
    return str(v)
end

local function candSummary(cand)
    if type(cand) ~= "table" then return "-" end
    local parts = {}
    for k, v in pairs(cand) do
        local s = (type(v) == "table") and (str(k) .. ":" .. countKeys(v)) or (str(k) .. "=" .. numText(v))
        local n = #parts
        parts[n + 1] = s
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end

--- `frame:method()`, the member index included, so a pcall around this covers a button whose
--- every index raises (a forbidden object), not the call alone.
local function callMethod(frame, method)
    return frame[method](frame)
end

--- Whether an engine button is shown: true, false, or nil when that cannot be known. Out of combat
--- an engine button's IsShown can answer a SECRET boolean even while auras are not secret, and
--- comparing one raises in tainted code, so the answer is tested before it meets `==`.
local function frameShown(frame)
    local ok, v = pcall(callMethod, frame, "IsShown")
    if not ok or not NS.Secrets.CanAccess(v) then return nil end
    return v == true
end

--- The `shown=` text: the count, `?` when no button could be read, else `<shown>+<unknowable>?`.
local function shownText(n, shown, unknown)
    if unknown == 0 then return shown end
    if unknown >= n then return "?" end
    return str(shown) .. "+" .. str(unknown) .. "?"
end

--- The group's frame count and how many of them are shown. While secret only the count is read.
local function frameCounts(x, key)
    local engine = x.inst and x.inst.engine
    if not engine then return "-", "-" end
    local ok, n = pcall(engine.GetAuraGroupFrameCount, engine, key)
    if not ok or not NS.Secrets.IsReadableNumber(n) then return "?", "?" end
    if x.secret then return n, "?" end
    local shown, unknown = 0, 0
    for i = 1, n do
        local okF, frame = pcall(engine.GetAuraGroupFrame, engine, key, i)
        local s = okF and type(frame) == "table" and frameShown(frame)
        if s == true then
            shown = shown + 1
        elseif s == nil then
            unknown = unknown + 1
        end
    end
    return n, shownText(n, shown, unknown)
end

--- A plan group's key for a section name, read raw: the name is built outside the section's pcall.
local function groupKey(g)
    return type(g) == "table" and str(rawget(g, "key")) or "?"
end

local function groupLine(out, x, g)
    local frames, shown = frameCounts(x, g.key)
    out:add("Plan", '#%s %s "%s" filter=%s cand=%s sort=%s/%s max=%s frames=%s shown=%s', x.id, g.key,
        g.label, g.filter, candSummary(g.candidateFilters), g.sortMethod, g.sortDirection,
        g.maxFrameCount, frames, shown)
end

local function planLines(out, x)
    local FC = NS.FilterCompiler
    local fresh = FC.Compile(x.c, FC.ProfileContext())
    out:add("Plan", "#%s %s", x.id, verdictOf(x, fresh))
    local plan = x.inst and x.inst.plan
    if not plan then return end
    for _, g in ipairs(plan.groups or {}) do
        out:section("plan #" .. str(x.id) .. " " .. groupKey(g), groupLine, x, g)
    end
    for _, w in ipairs(x.inst.warnings or {}) do out:add("Plan", "#%s warning: %s", x.id, w) end
end

-- ---------------------------------------------------------------------------
-- Containers: non-default settings
-- ---------------------------------------------------------------------------

local function isContainerRow(row, c)
    local path = row.path
    if type(path) ~= "string" or row.sessionOnly or row.hidden then return false end
    if path:find("container.", 1, true) ~= 1 or path == "container.name" then return false end
    if path:find("container.filter.", 1, true) == 1 then return false end
    return NS.RowApplies(row, c)
end

--- Whether a row's `shownWhen` selector holds for container `c`, read the way the options library's
--- shownNow reads it: `equals` is a value or a list of them, and a read that raises counts as held.
local function selectorHolds(sw, c)
    if type(sw) ~= "table" or sw.path == nil then return true end
    local ok, value = pcall(NS.GetSetting, sw.path, c.id)
    if not ok then return true end
    local want = sw.equals
    if type(want) ~= "table" then return value == want end
    for _, w in ipairs(want) do
        if value == w then return true end
    end
    return false
end

--- Whether a row's stored value does anything for container `c` (B9 DX-2): its switched subsection
--- is the one drawn (a screen position on an attached container is not), and its page is not one
--- the container's style disables (the Text page on a bars container). The page gate is each page's
--- own `disabledFor`, recorded by NS.RegisterContainerPage.
local function inUse(row, c)
    if not selectorHolds(row.shownWhen, c) then return false end
    local gates = NS.ContainerPageDisabledFor or {}
    local disabledFor = gates[row.page]
    if type(disabledFor) ~= "function" then return true end
    local ok, off = pcall(disabledFor, c)
    return not (ok and off)
end

--- The non-default rows in use, then the inert ones on their own line (only when there are any):
--- a stale attach offset comes back into use on a mode switch, so it is shown, not dropped.
local function cfgLines(out, x)
    local parts, inert = {}, {}
    for _, row in ipairs(NS.Schema) do
        if isContainerRow(row, x.c) then
            local changed, v = differs(row.path, x.id)
            if changed then
                local into = inUse(row, x.c) and parts or inert
                local n = #into
                into[n + 1] = row.path:sub(11) .. "=" .. formatValue(row, v)
            end
        end
    end
    out:joined("Cfg", "#" .. str(x.id) .. " non-default:", parts)
    if inert[1] then out:joined("Cfg", "#" .. str(x.id) .. " inert:", inert) end
end

-- ---------------------------------------------------------------------------
-- Containers: what it shows
-- ---------------------------------------------------------------------------

--- An instance id the engine may expose, as `inst=`/`id=` text, or nil.
local function probeInstance(frame)
    for _, method in ipairs({ "GetAuraInstanceID", "GetAuraInstance" }) do
        local fn = frame[method]
        if type(fn) == "function" then
            local ok, v = pcall(fn, frame)
            if ok and type(v) == "number" then return "inst=" .. str(v) end
            if ok and type(v) == "table" and v.auraInstanceID ~= nil then
                return "inst=" .. str(v.auraInstanceID) .. " id=" .. str(v.spellId)
            end
        end
    end
    return nil
end

--- What our own regions say: the name the engine bound, else the icon.
local function probeRegions(frame)
    local am = frame.__am
    if type(am) ~= "table" then return nil end
    if type(am.name) == "table" then
        local ok, text = pcall(am.name.GetText, am.name)
        if ok and type(text) == "string" then return 'name="' .. str(text) .. '"' end
    end
    if type(am.icon) == "table" then
        local ok, tex = pcall(am.icon.GetTexture, am.icon)
        if ok and (type(tex) == "number" or type(tex) == "string") then return "icon=" .. str(tex) end
    end
    return nil
end

local function probe(frame)
    return probeInstance(frame) or probeRegions(frame) or "id=?"
end

--- The button's name for a [Shown] line; a probe that raises (a forbidden object) says so instead.
local function identify(frame)
    local ok, text = pcall(probe, frame)
    if ok then return text end
    return "id=? (probe failed: " .. str(text) .. ")"
end

--- One [Shown] line per shown button, and per button whose shown state cannot be known (`shown=?`,
--- so a secret IsShown loses no button from the listing).
local function groupButtons(out, x, g)
    local engine = x.inst.engine
    local ok, n = pcall(engine.GetAuraGroupFrameCount, engine, g.key)
    if not ok or not NS.Secrets.IsReadableNumber(n) then return end
    local listed = 0
    for i = 1, n do
        local okF, frame = pcall(engine.GetAuraGroupFrame, engine, g.key, i)
        local shown = okF and type(frame) == "table" and frameShown(frame)
        if shown ~= false then
            listed = listed + 1
            if listed > Diag.MAX_IDS then
                flagCap(out)
                return
            end
            out:add("Shown", "#%s %s btn%s %s%s", x.id, g.key, i, shown and "" or "shown=? ", identify(frame))
        end
    end
end

local RANK_NAMES = { "whitelist", "blacklist", "category", "category", "no category" }

local function explainText(result)
    local labels = {}
    for i, cat in ipairs(result.categories or {}) do labels[i] = str(cat.label) end
    local why = RANK_NAMES[result.rank] or "?"
    if labels[1] then why = table.concat(labels, ", ") end
    return str(result.verdict) .. " (rank " .. str(result.rank) .. " " .. why .. ")"
end

--- The PREDICTED verdict for every readable aura on the container's unit and type. Approximate:
--- ExplainSpell reasons about spell-list categories only; the engine decides the rest.
local function predictions(out, x)
    local c = x.c
    if not unitExists(c.unit) then return end
    local filter = (c.auraType == "HARMFUL") and "HARMFUL" or "HELPFUL"
    local list = cachedAuras(out, c.unit, filter)
    local FC, ctx, listed = NS.FilterCompiler, NS.FilterCompiler.ProfileContext(), 0
    for _, a in ipairs(list or {}) do
        local id = a.spellId
        if NS.Secrets.IsSafeKey(id) and type(id) == "number" then
            if listed >= Diag.MAX_IDS then
                flagCap(out)
                return
            end
            listed = listed + 1
            out:add("Shown", "#%s predicted: %s %s -> %s", x.id, id, spellName(id),
                explainText(FC.ExplainSpell(c, id, ctx)))
        end
    end
end

local function shownLines(out, x)
    if x.secret then
        out:add("Shown", "#%s skipped: auras are secret, so no button is read", x.id)
        return
    end
    local inst = x.inst
    if inst and inst.engine and inst.plan then
        for _, g in ipairs(inst.plan.groups or {}) do
            out:section("shown #" .. str(x.id) .. " " .. groupKey(g), groupButtons, x, g)
        end
    end
    out:section("predictions #" .. str(x.id), predictions, x)
end

local CONTAINER_SECTIONS = {
    { "container", contLine },
    { "filters",   filtLines },
    { "plan",      planLines },
    { "config",    cfgLines },
    { "shown",     shownLines },
}

function Diag.Containers(out)
    local CM = NS.ContainerManager
    local q = CM.QueueSnapshot()
    local secret = NS.Compat.AurasAreSecret()
    for _, c in ipairs(NS.Database.GetContainers()) do
        local x = { c = c, id = c.id, inst = CM.instances[c.id], q = q, secret = secret }
        for _, s in ipairs(CONTAINER_SECTIONS) do
            out:section(s[1] .. " #" .. str(c.id), s[2], x)
        end
    end
end

-- ---------------------------------------------------------------------------
-- The sections the helper runs
-- ---------------------------------------------------------------------------

--- The report's sections, in order, for the descriptor's `diagnostics` (core/DebugLogSetup.lua).
--- The helper calls this once per report, at run time.
--- @return table  { { name, fn(out) }, ... }
function Diag.Sections()
    return {
        { "state",          Diag.Header },
        { "profile config", Diag.ProfileConfig },
        { "auras",          Diag.Auras },
        { "containers",     Diag.Containers },
    }
end
