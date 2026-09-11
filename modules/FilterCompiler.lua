local _, NS = ...

-- modules/FilterCompiler.lua — turns one container's filter settings into the aura GROUPS Blizzard's
-- aura container evaluates.
--
-- WHY A COMPILER. On Retail 12.1 an addon cannot read aura data while auras are secret, which is most
-- of the time that matters (combat, encounters, keys, PvP). The engine does the reading, in its own
-- secure code, and all it takes from us is a declaration per group: a filter STRING of tokens
-- (`HELPFUL|PLAYER|!CROWD_CONTROL`) and a table of CANDIDATE FILTERS (spell ids, dispel types, a few
-- aura booleans, a maximum duration). This file is the only place that knows how a player's
-- "show Defensives, hide Consumables, only mine, under 60 s" becomes those declarations.
--
-- PURE. No frames, no database, no globals beyond math.huge: `Compile(cfg, ctx)` in, a plan out. That
-- is what makes the filtering rules testable headlessly (tests/test_filtercompiler.lua) when nothing
-- else about an aura can be.
--
-- HOW CATEGORIES COMBINE (the tri-state):
--   * No category shown  → ONE group: every aura of the type, minus every hidden category.
--   * Some shown         → one group PER shown category (their union), each minus the hidden ones
--                          and minus every shown category declared before it, so an aura matching
--                          two shown categories appears once, under the first.
--   * A whitelist        → its own group first (always shown, whatever the categories say), and every
--                          other group excludes those ids so nothing is drawn twice.
--   * A blacklist        → excluded from every group.
--
-- A group whose constraints contradict themselves (it would need both `X` and `!X`) is dropped rather
-- than handed to the engine, because it could never match anything.

NS.FilterCompiler = NS.FilterCompiler or {}
local FC = NS.FilterCompiler

-- Every warning a plan can carry, as one whole sentence each: the settings panel prints them
-- through NS.L (settings/OptionsSetup.lua's RenderWarnings), so each must be a single literal the
-- locale file can list and tests/test_locale.lua can find.
FC.WARN = {
    ENCHANT_UNIT     = "Weapon enchants only exist on your own character; this container shows the player's enchants whatever its unit is set to.",
    MAX_WITH_TIMELESS = "Max duration is ignored while showing only auras without a duration.",
    NEVER_MATCHES    = "These filters can never match anything.",
    TIMELESS_BUFFS_ONLY = "Only auras without a duration works for buffs only; this container shows every duration.",
    IDS_OWN_DEBUFFS  = "Spell lists are ignored for debuffs on your own character or pet: Blizzard does not allow spell-id filtering there.",
    IDS_HOSTILE_ONLY = "Spell lists only apply while the unit is hostile.",
    IDS_FRIENDLY_ONLY = "Spell lists only apply while the unit is friendly.",
}

local HUGE = math.huge

-- ---------------------------------------------------------------------------
-- A constraint set: tokens + candidate filters, with conflict detection
-- ---------------------------------------------------------------------------

local function newCon()
    return { tokens = {}, tokenSet = {}, cand = {}, conflict = false }
end

local function copySet(s)
    local out = {}
    for k, v in pairs(s) do out[k] = v end
    return out
end

local function cloneCon(con)
    local out = newCon()
    for i, t in ipairs(con.tokens) do out.tokens[i] = t end
    out.tokenSet = copySet(con.tokenSet)
    for k, v in pairs(con.cand) do
        out.cand[k] = (type(v) == "table") and copySet(v) or v
    end
    out.conflict = con.conflict
    return out
end

local function addToken(con, token)
    if con.tokenSet[token] then return end
    local opposite = (token:sub(1, 1) == "!") and token:sub(2) or ("!" .. token)
    if con.tokenSet[opposite] then con.conflict = true return end
    con.tokenSet[token] = true
    con.tokens[#con.tokens + 1] = token
end

--- Set a boolean candidate filter. `soft` marks a NEGATION of an earlier category: when it collides
--- with a positive requirement on the same field the two categories are already disjoint, so the
--- negation is simply unnecessary rather than a contradiction.
local function setFlag(con, field, value, soft)
    local current = con.cand[field]
    if current == nil then
        con.cand[field] = value
    elseif current ~= value and not soft then
        con.conflict = true
    end
end

local function addToSet(con, field, set)
    con.cand[field] = con.cand[field] or {}
    for k in pairs(set) do con.cand[field][k] = true end
end

-- ---------------------------------------------------------------------------
-- Categories
-- ---------------------------------------------------------------------------

--- The effective spell set of one spell category: the shipped starter list with the container's own
--- edits layered on (true adds an id, false removes one).
--- @return table  [spellId] = true
function FC.CategorySpells(def, cfg)
    local out = {}
    for id in pairs(def.spells or {}) do out[id] = true end
    local edits = cfg and cfg.filter and cfg.filter.categorySpells and cfg.filter.categorySpells[def.key]
    if type(edits) == "table" then
        for id, on in pairs(edits) do
            id = tonumber(id)
            if id then
                if on then out[id] = true else out[id] = nil end
            end
        end
    end
    return out
end

local function isEmpty(t) return next(t) == nil end

--- Apply category `def` to `con`, positively ("show") or negatively (as an exclusion).
local function applyCategory(con, def, cfg, positive)
    local kind = def.kind
    if kind == "token" then
        addToken(con, positive and def.token or ("!" .. def.token))
    elseif kind == "flag" then
        if positive then
            setFlag(con, def.field, def.value, false)
        else
            setFlag(con, def.field, not def.value, true)
        end
    elseif kind == "dispel" then
        addToSet(con, positive and "includeDispelTypes" or "excludeDispelTypes", def.types)
    elseif kind == "spells" then
        local set = FC.CategorySpells(def, cfg)
        if positive then
            -- A shown spell category with no ids left would pass NOTHING — including it as an empty
            -- include-map is what the engine would honor, and an empty group is honest about that.
            if isEmpty(set) then con.conflict = true return end
            addToSet(con, "includeSpellIDs", set)
        elseif not isEmpty(set) then
            addToSet(con, "excludeSpellIDs", set)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Warnings: what the engine will silently not do
-- ---------------------------------------------------------------------------

--- Blizzard only honors spell-id filters for buffs on friendly units and debuffs on hostile ones
--- (AuraContainerUtil.CanApplyIdentityCandidateFilters). Say so when a container relies on one where
--- it will be ignored, instead of letting the filter look broken.
local function identityWarning(unit, auraType)
    if auraType == "HARMFUL" and (unit == "player" or unit == "pet") then
        return FC.WARN.IDS_OWN_DEBUFFS
    elseif auraType == "HARMFUL" then
        return FC.WARN.IDS_HOSTILE_ONLY
    elseif auraType == "HELPFUL" and (unit == "target" or unit == "focus") then
        return FC.WARN.IDS_FRIENDLY_ONLY
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Compile
-- ---------------------------------------------------------------------------

local function sortKey(v, allowed, fallback)
    if type(v) == "string" and allowed[v] ~= nil then return v end
    return fallback
end

local function spellSet(map)
    local out = {}
    for id, on in pairs(map or {}) do
        id = tonumber(id)
        if id and on then out[id] = true end
    end
    return out
end

--- Build the engine-facing plan for one container.
---
--- @param cfg table  the container's stored table (defaults/Profile.lua CONTAINER_TEMPLATE shape)
--- @param ctx table|nil  { categories = NS.Categories, timedSpells = { [id] = true } }
--- @return table  plan = { groups = { {key, filter, candidateFilters, sortMethod, sortDirection,
---                maxFrameCount, label} }, enchants = { slots, hidePermanent } | nil, warnings = {} }
function FC.Compile(cfg, ctx)
    ctx = ctx or {}
    local Categories = ctx.categories or NS.Categories
    local C = NS.Constants
    local filter = cfg.filter or {}
    local plan = { groups = {}, warnings = {}, enchants = nil }

    local sortMethod = sortKey(filter.sortMethod, C.SORT_METHOD_ENGINE, "default")
    local sortDirection = (filter.sortDirection == "reverse") and "reverse" or "normal"
    local maxFrameCount = (tonumber(filter.maxAuras) or 0) > 0 and math.floor(filter.maxAuras) or HUGE

    local auraType = cfg.auraType
    if auraType == "ENCHANT" then
        if cfg.unit ~= "player" then
            plan.warnings[#plan.warnings + 1] = FC.WARN.ENCHANT_UNIT
        end
        plan.enchants = { slots = { "mainHand", "offHand", "ranged" },
            hidePermanent = filter.hidePermanentEnchants ~= false }
        return plan
    end
    if auraType ~= "HARMFUL" then auraType = "HELPFUL" end

    -- ── The base every group starts from ────────────────────────────────────────────────────
    local base = newCon()
    addToken(base, auraType)
    if filter.castBy == "mine" then
        addToken(base, "PLAYER")
    elseif filter.castBy == "others" then
        addToken(base, "!PLAYER")
    end

    local usesSpellIds = false
    local mode = filter.durationMode
    local maxDuration = tonumber(filter.maxDuration) or 0
    -- Timeless is built from learned BUFF durations (modules/TimedSpells.lua scans buffs only), and a
    -- spell-id exclusion is not honored for debuffs on friendly units anyway: on a debuff container
    -- the mode means nothing, so it is reported and treated as "any".
    if mode == "timeless" and auraType ~= "HELPFUL" then
        plan.warnings[#plan.warnings + 1] = FC.WARN.TIMELESS_BUFFS_ONLY
        mode = "any"
    end
    if mode == "timeless" then
        -- No engine filter selects "no duration". The workaround: exclude every spell we have SEEN
        -- carry one (modules/TimedSpells.lua learns them while auras are readable). A maxDuration
        -- would drop the very auras this mode is for, so it is ignored here and the player is told.
        local timed = ctx.timedSpells or {}
        if not isEmpty(timed) then
            addToSet(base, "excludeSpellIDs", timed)
            usesSpellIds = true
        end
        if maxDuration > 0 then
            plan.warnings[#plan.warnings + 1] = FC.WARN.MAX_WITH_TIMELESS
        end
    elseif maxDuration > 0 then
        base.cand.maxDuration = maxDuration
    elseif mode == "timed" then
        -- The engine drops permanent auras whenever maxDuration is set, which is exactly "timed".
        base.cand.maxDuration = HUGE
    end

    local blacklist = spellSet(filter.blacklist)
    local whitelist = spellSet(filter.whitelist)
    for id in pairs(blacklist) do whitelist[id] = nil end     -- "never" beats "always"
    if not isEmpty(blacklist) then
        addToSet(base, "excludeSpellIDs", blacklist)
        usesSpellIds = true
    end

    -- ── Categories: shown and hidden, in declaration order ───────────────────────────────────
    local shown, hidden = {}, {}
    local states = filter.categories or {}
    for _, def in ipairs(Categories.For(auraType)) do
        local state = states[def.key]
        if state == "show" then
            shown[#shown + 1] = def
        elseif state == "hide" then
            hidden[#hidden + 1] = def
        end
        if (state == "show" or state == "hide") and def.kind == "spells" then usesSpellIds = true end
    end

    local function finish(con, label)
        if con.conflict then return end
        local cand = con.cand
        local groupCount = #plan.groups + 1
        plan.groups[groupCount] = {
            key              = "g" .. groupCount,
            label            = label,
            filter           = table.concat(con.tokens, "|"),
            candidateFilters = next(cand) and cand or nil,
            sortMethod       = sortMethod,
            sortDirection    = sortDirection,
            maxFrameCount    = maxFrameCount,
        }
    end

    -- The whitelist group: the aura type, the ids, nothing else.
    if not isEmpty(whitelist) then
        local wl = newCon()
        addToken(wl, auraType)
        addToSet(wl, "includeSpellIDs", whitelist)
        finish(wl, "Always shown")
        usesSpellIds = true
    end

    local function withExclusions(con)
        for _, def in ipairs(hidden) do applyCategory(con, def, cfg, false) end
        if not isEmpty(whitelist) then addToSet(con, "excludeSpellIDs", whitelist) end
        return con
    end

    if #shown == 0 then
        finish(withExclusions(cloneCon(base)), "All")
    else
        for i, def in ipairs(shown) do
            local con = cloneCon(base)
            applyCategory(con, def, cfg, true)
            for j = 1, i - 1 do applyCategory(con, shown[j], cfg, false) end
            finish(withExclusions(con), def.label)
        end
    end

    -- ── Weapon enchants appended to a player buff container ─────────────────────────────────
    if auraType == "HELPFUL" and filter.includeEnchants and cfg.unit == "player" then
        plan.enchants = { slots = { "mainHand", "offHand", "ranged" },
            hidePermanent = filter.hidePermanentEnchants ~= false }
    end

    if usesSpellIds then
        local w = identityWarning(cfg.unit, auraType)
        if w then plan.warnings[#plan.warnings + 1] = w end
    end
    if #plan.groups == 0 then
        plan.warnings[#plan.warnings + 1] = FC.WARN.NEVER_MATCHES
    end

    return plan
end

--- A deterministic string for any plain value — tables serialized with sorted keys — so two candidate
--- filter tables can be compared for equality. modules/Container.lua uses it to call the engine's
--- SetAuraGroupCandidateFilters only when something actually changed, because that call clears and
--- re-gathers the group's auras.
--- @return string
function FC.Signature(v)
    local t = type(v)
    if t ~= "table" then return t .. ":" .. tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for i, k in ipairs(keys) do parts[i] = tostring(k) .. "=" .. FC.Signature(v[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
end

--- A structural fingerprint of a plan: what cannot be changed on a live engine container without
--- rebuilding it (the number of groups, whether enchant slots exist, and whether they hide permanent
--- enchants — AddItemEnchantment takes that flag only at creation). Filter strings, candidate
--- filters, sorting and caps are all live-editable, so they are deliberately NOT part of it.
--- @return string
function FC.StructureKey(plan)
    local e = plan.enchants and (plan.enchants.hidePermanent and "E" or "e") or "-"
    return ("%d:%s"):format(#plan.groups, e)
end
