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
-- HOW CATEGORIES COMBINE (schema v3). A category is Show or Hide, and Show is the absence of a
-- decision. There is always exactly ONE category group: every aura of the type, minus every
-- category set to Hide, minus the Overrides whitelist (which has its own group, so nothing is
-- drawn twice). The priority, highest first:
--
--   1. Overrides -> Blacklist.  Never drawn. Beats everything, the Overrides whitelist included.
--   2. Overrides -> Whitelist.  Always drawn, in its own group, whatever the categories say.
--   3. Category  -> Hide.       Not drawn, unless rule 2 already claimed it.
--   4. Category  -> Show.       Drawn, because nothing removed it. Contributes no constraint.
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

--- Set a boolean candidate filter. Two categories asking for opposite values on the same field is a
--- genuine contradiction — every remaining caller is a Hide negation (schema v3 deleted the positive
--- path), so there is no "soft" collision left to forgive.
local function setFlag(con, field, value)
    local current = con.cand[field]
    if current == nil then
        con.cand[field] = value
    elseif current ~= value then
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

--- The effective spell set of one spell category: the shipped starter list with the profile's edits
--- layered on (true adds an id, false removes one). `spellEdits` is the profile-wide
--- `categorySpells` map (schema v2: one set every container shares), or nil for the starters alone.
--- @return table  [spellId] = true
function FC.CategorySpells(def, spellEdits)
    local out = {}
    for id in pairs(def.spells or {}) do out[id] = true end
    local edits = type(spellEdits) == "table" and spellEdits[def.key]
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

--- Exclude category `def` from `con`. Categories are a pure exclusion filter since schema v3: a row
--- is Hide, which removes what it matches, or Show, which is the absence of a decision and reaches
--- this function never. Kind `enchant` matches no aura at all — it decides whether the container's
--- weapon-enchant slots exist — so it contributes nothing here.
local function excludeCategory(con, def, spellEdits)
    local kind = def.kind
    if kind == "token" then
        addToken(con, "!" .. def.token)
    elseif kind == "flag" then
        setFlag(con, def.field, not def.value)
    elseif kind == "dispel" then
        addToSet(con, "excludeDispelTypes", def.types)
    elseif kind == "spells" then
        local set = FC.CategorySpells(def, spellEdits)
        if not isEmpty(set) then addToSet(con, "excludeSpellIDs", set) end
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

local function warn(plan, w)
    plan.warnings[#plan.warnings + 1] = w
end

local function enchantBlock(filter)
    return { slots = { "mainHand", "offHand", "ranged" },
        hidePermanent = filter.hidePermanentEnchants ~= false }
end

--- How every group sorts and caps: the same for each group a container compiles to.
local function lookOf(filter)
    local C = NS.Constants
    return {
        sortMethod    = sortKey(filter.sortMethod, C.SORT_METHOD_ENGINE, "default"),
        sortDirection = (filter.sortDirection == "reverse") and "reverse" or "normal",
        maxFrameCount = (tonumber(filter.maxAuras) or 0) > 0 and math.floor(filter.maxAuras) or HUGE,
    }
end

--- A weapon-enchant container: the three slots and no aura groups.
local function compileEnchant(plan, cfg, filter)
    if cfg.unit ~= "player" then
        warn(plan, FC.WARN.ENCHANT_UNIT)
    end
    plan.enchants = enchantBlock(filter)
    return plan
end

--- The base every group starts from: the aura type, and who cast it.
local function baseFor(auraType, castBy)
    local base = newCon()
    addToken(base, auraType)
    if castBy == "mine" then
        addToken(base, "PLAYER")
    elseif castBy == "others" then
        addToken(base, "!PLAYER")
    end
    return base
end

--- The duration mode and the max duration, applied to the base.
--- @return boolean  whether the base now filters by spell id
local function applyDuration(base, plan, filter, auraType, timedSpells)
    local usesSpellIds = false
    local mode = filter.durationMode
    local maxDuration = tonumber(filter.maxDuration) or 0
    -- Timeless is built from learned BUFF durations (modules/TimedSpells.lua scans buffs only), and a
    -- spell-id exclusion is not honored for debuffs on friendly units anyway: on a debuff container
    -- the mode means nothing, so it is reported and treated as "any".
    if mode == "timeless" and auraType ~= "HELPFUL" then
        warn(plan, FC.WARN.TIMELESS_BUFFS_ONLY)
        mode = "any"
    end
    if mode == "timeless" then
        -- No engine filter selects "no duration". The workaround: exclude every spell we have SEEN
        -- carry one (modules/TimedSpells.lua learns them while auras are readable). A maxDuration
        -- would drop the very auras this mode is for, so it is ignored here and the player is told.
        local timed = timedSpells or {}
        if not isEmpty(timed) then
            addToSet(base, "excludeSpellIDs", timed)
            usesSpellIds = true
        end
        if maxDuration > 0 then
            warn(plan, FC.WARN.MAX_WITH_TIMELESS)
        end
    elseif maxDuration > 0 then
        base.cand.maxDuration = maxDuration
    elseif mode == "timed" then
        -- The engine drops permanent auras whenever maxDuration is set, which is exactly "timed".
        base.cand.maxDuration = HUGE
    end
    return usesSpellIds
end

--- The whitelist and the blacklist as id sets; the blacklist goes on the base.
--- @return table whitelist, boolean usesSpellIds
local function applyLists(base, filter)
    local blacklist = spellSet(filter.blacklist)
    local whitelist = spellSet(filter.whitelist)
    for id in pairs(blacklist) do whitelist[id] = nil end     -- "never" beats "always"
    if isEmpty(blacklist) then return whitelist, false end
    addToSet(base, "excludeSpellIDs", blacklist)
    return whitelist, true
end

--- The categories set to Hide, in declaration order. Kind `enchant` is skipped: it never narrows an
--- aura group, it decides whether the container has enchant slots (compileEnchant / Compile).
--- @return table hidden, boolean usesSpellIds
local function splitCategories(Categories, auraType, states)
    local hidden, usesSpellIds = {}, false
    for _, def in ipairs(Categories.For(auraType)) do
        if states[def.key] == "hide" and def.kind ~= "enchant" then
            hidden[#hidden + 1] = def
            if def.kind == "spells" then usesSpellIds = true end
        end
    end
    return hidden, usesSpellIds
end

--- One engine group for `con`, unless it is a contradiction.
local function addGroup(plan, con, label, look)
    if con.conflict then return end
    local cand = con.cand
    local groupCount = #plan.groups + 1
    plan.groups[groupCount] = {
        key              = "g" .. groupCount,
        label            = label,
        filter           = table.concat(con.tokens, "|"),
        candidateFilters = next(cand) and cand or nil,
        sortMethod       = look.sortMethod,
        sortDirection    = look.sortDirection,
        maxFrameCount    = look.maxFrameCount,
    }
end

--- The whitelist group: the aura type, the ids, nothing else.
--- @return boolean  whether a group was added
local function addWhitelistGroup(plan, auraType, whitelist, look)
    if isEmpty(whitelist) then return false end
    local wl = newCon()
    addToken(wl, auraType)
    addToSet(wl, "includeSpellIDs", whitelist)
    addGroup(plan, wl, "Always shown", look)
    return true
end

--- The one category group: the base, minus every hidden category, minus the Overrides whitelist
--- (which has its own group and must not be drawn twice).
local function addCategoryGroup(plan, base, cats, look)
    local con = cloneCon(base)
    for _, def in ipairs(cats.hidden) do excludeCategory(con, def, cats.spellEdits) end
    if not isEmpty(cats.whitelist) then addToSet(con, "excludeSpellIDs", cats.whitelist) end
    addGroup(plan, con, "All", look)
end

--- The warnings that depend on the finished plan.
local function finishWarnings(plan, unit, auraType, usesSpellIds)
    if usesSpellIds then
        local w = identityWarning(unit, auraType)
        if w then
            warn(plan, w)
        end
    end
    local groupCount = #plan.groups
    if groupCount == 0 then
        warn(plan, FC.WARN.NEVER_MATCHES)
    end
end

--- The context both compile sites hand Compile: the learned timed spells (account-wide) and the
--- profile's spell-list edits (schema v2). Either is nil before the database exists.
--- @return table
function FC.ProfileContext()
    local db = NS.db
    return {
        timedSpells    = db and db.global and db.global.timedSpells,
        categorySpells = db and db.profile and db.profile.categorySpells,
    }
end

--- Build the engine-facing plan for one container.
---
--- @param cfg table  the container's stored table (defaults/Profile.lua CONTAINER_TEMPLATE shape)
--- @param ctx table|nil  { categories = NS.Categories, timedSpells = { [id] = true },
---                  categorySpells = the profile's spell-list edits (schema v2) }
--- @return table  plan = { groups = { {key, filter, candidateFilters, sortMethod, sortDirection,
---                maxFrameCount, label} }, enchants = { slots, hidePermanent } | nil, warnings = {} }
function FC.Compile(cfg, ctx)
    ctx = ctx or {}
    local Categories = ctx.categories or NS.Categories
    local filter = cfg.filter or {}
    local plan = { groups = {}, warnings = {}, enchants = nil }
    local look = lookOf(filter)

    local auraType = cfg.auraType
    if auraType == "ENCHANT" then return compileEnchant(plan, cfg, filter) end
    if auraType ~= "HARMFUL" then auraType = "HELPFUL" end

    -- ── The base every group starts from ────────────────────────────────────────────────────
    local base = baseFor(auraType, filter.castBy)
    local timedIds = applyDuration(base, plan, filter, auraType, ctx.timedSpells)
    local whitelist, blacklisted = applyLists(base, filter)

    -- ── Categories: the one group, minus everything set to Hide ─────────────────────────────
    local hidden, categoryIds = splitCategories(Categories, auraType, filter.categories or {})
    local whitelisted = addWhitelistGroup(plan, auraType, whitelist, look)
    addCategoryGroup(plan, base,
        { hidden = hidden, whitelist = whitelist, spellEdits = ctx.categorySpells }, look)

    -- ── Weapon enchants appended to a player buff container ─────────────────────────────────
    if auraType == "HELPFUL" and filter.includeEnchants and cfg.unit == "player" then
        plan.enchants = enchantBlock(filter)
    end

    finishWarnings(plan, cfg.unit, auraType, timedIds or blacklisted or categoryIds or whitelisted)
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
    for k in pairs(v) do
        keys[#keys + 1] = k
    end
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
