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
-- HOW CATEGORIES COMBINE (filter priority, revised 2026-09-15 — docs/superpowers/specs/
-- 2026-09-14-feedback-batch6-design.md section 6). A category is Show or Hide, and now Show is a
-- POSITIVE claim on an aura, not merely the absence of a Hide. The priority, highest first:
--
--   1. Overrides -> Whitelist.  Always drawn, in its own group, whatever anything else says.
--   2. Overrides -> Blacklist.  Never drawn, unless rule 1 already claimed it.
--   3. Category  -> Show.       Drawn, even if it is also in a category set to Hide.
--   4. Category  -> Hide.       Not drawn, if every category the aura belongs to says Hide.
--   5. No category at all.      Drawn — nothing removed it.
--
-- HOW THAT COMPILES. The engine ANDs the constraints inside one group and ORs the groups, so "in ANY
-- shown category" is a union: it needs one group per shown category.
--
--   * No category Hidden -> exactly ONE group: the base, minus the whitelist (rule 5 needs nothing
--     rescued, so the extra groups would be pure cost — this keeps a default container at one group).
--   * At least one Hidden -> one group PER SHOWN category (the base plus that category's positive
--     constraint, minus every earlier shown category and the whitelist, so no aura is drawn twice),
--     followed by a catch-all: the base, minus every hidden AND every shown category, minus the
--     whitelist (rule 5 — an aura in no category).
--   * "Only these categories" (a per-container toggle) drops the catch-all: the container then draws
--     only the whitelist plus its shown categories, and the one-group optimization above does not
--     apply even when nothing is Hidden — the shown groups ARE the container.
--
-- The blacklist applies to the base, so it reaches the shown groups and the catch-all, but never the
-- whitelist group. Kind `enchant` takes part in neither the shown groups nor the exclusions — it
-- matches no aura.
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
    ONLY_SHOWN_NONE  = "Only the categories set to Show are drawn, and no category is set to Show.",
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

--- Set a boolean candidate filter. Every caller (a Hide's negation via `excludeCategory`, or now a
--- Show's positive requirement via `includeCategory`, R-6) sets one field on ONE group at a time, so
--- two calls landing on the same field within a group are always a genuine contradiction — two
--- categories hiding the same flag to opposite values (fromPlayers and fromNonPlayers, both on
--- isFromPlayerOrPlayerPet, say), or a Show's positive value colliding with an earlier exclusion —
--- reported via `con.conflict` rather than swallowed.
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

--- Exclude category `def` from `con`: a Hide, or an earlier Show being kept out of a later shown
--- group so an aura matching two shown categories is drawn once, under the first. Kind `enchant`
--- never reaches here — it matches no aura at all, deciding only whether the container's weapon-
--- enchant slots exist (splitCategories skips it categorically).
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

--- Include category `def` in `con`: a Show's positive constraint (R-6), the sibling `excludeCategory`
--- lost when categories became a pure exclusion and now regains. An empty spell category can never
--- match anything — an empty `includeSpellIDs` map IS what the engine would honor, and a group that
--- can never match is dropped rather than handed to it, so this is reported as a conflict instead.
local function includeCategory(con, def, spellEdits)
    local kind = def.kind
    if kind == "token" then
        addToken(con, def.token)
    elseif kind == "flag" then
        setFlag(con, def.field, def.value)
    elseif kind == "dispel" then
        addToSet(con, "includeDispelTypes", def.types)
    elseif kind == "spells" then
        local set = FC.CategorySpells(def, spellEdits)
        if isEmpty(set) then
            con.conflict = true
        else
            addToSet(con, "includeSpellIDs", set)
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

local function warn(plan, w)
    plan.warnings[#plan.warnings + 1] = w
end

local ENCHANT_SLOTS = { "mainHand", "offHand", "ranged" }

--- The enchant block: which weapon slots the container draws, and whether a permanent enchant is
--- skipped. The slots are the profile's (General -> Spell Categories); a profile with none, or with
--- every slot unticked, falls back to all three, because a container showing enchants and no slots
--- would draw nothing with nothing to explain it.
local function enchantBlock(filter, enchantSlots)
    local slots = {}
    for _, name in ipairs(ENCHANT_SLOTS) do
        if not enchantSlots or enchantSlots[name] then
            slots[#slots + 1] = name
        end
    end
    local slotCount = #slots
    if slotCount == 0 then
        slots = { "mainHand", "offHand", "ranged" }
    end
    return { slots = slots, hidePermanent = filter.hidePermanentEnchants ~= false }
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
local function compileEnchant(plan, cfg, filter, ctx)
    if cfg.unit ~= "player" then
        warn(plan, FC.WARN.ENCHANT_UNIT)
    end
    plan.enchants = enchantBlock(filter, ctx.enchantSlots)
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

--- The whitelist and the blacklist as id sets; the blacklist goes on the base. R-2: the whitelist now
--- beats the blacklist — an id on both is removed from the BLACKLIST, not the whitelist, so rank 1
--- (whitelist) wins over rank 2 (blacklist) rather than the old "never beats always".
--- @return table whitelist, boolean usesSpellIds
local function applyLists(base, filter)
    local blacklist = spellSet(filter.blacklist)
    local whitelist = spellSet(filter.whitelist)
    for id in pairs(whitelist) do blacklist[id] = nil end     -- the whitelist wins (R-2)
    if isEmpty(blacklist) then return whitelist, false end
    addToSet(base, "excludeSpellIDs", blacklist)
    return whitelist, true
end

--- The categories set to Show and to Hide, in declaration order. Kind `enchant` is skipped
--- categorically (R-6): it never narrows an aura group, it decides whether the container has enchant
--- slots (compileEnchant / Compile). Every other category is either Hide or Show — the default state
--- (defaults/Categories.lua's `DefaultStates`) stamps every key "show" — so this is a true partition.
--- @return table shown, table hidden
local function splitCategories(Categories, auraType, states)
    local shown, hidden = {}, {}
    for _, def in ipairs(Categories.For(auraType)) do
        if def.kind ~= "enchant" then
            if states[def.key] == "hide" then
                hidden[#hidden + 1] = def
            else
                shown[#shown + 1] = def
            end
        end
    end
    return shown, hidden
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

--- The category groups (R-3, R-4, R-5, R-9). `cats` = { shown, hidden, whitelist, spellEdits,
--- onlyShown }. Every group excludes the whitelist (it has its own group and must not be drawn
--- twice); the whitelist itself is never touched by the blacklist (R-7 — it lives on `base`).
---
---   * No category Hidden and the toggle off (R-3): exactly ONE group, the base minus the whitelist.
---     A Show cannot rescue anything when nothing is hiding, so the per-shown-category groups below
---     would be pure cost — this is what keeps a default container at one group.
---   * Otherwise (R-4, R-9): one group per SHOWN category — the base plus that category's positive
---     constraint (`includeCategory`), minus every earlier shown category (`excludeCategory`, so an
---     aura in two shown categories is drawn once, under the first) and the whitelist — followed by
---     the catch-all (R-5) unless the toggle is on (R-9): the base minus every hidden AND every shown
---     category and the whitelist, which is what draws an aura in no category at all.
---
--- @return boolean usesSpellIds
local function addCategoryGroups(plan, base, cats, look)
    local edits = cats.spellEdits
    local usesSpellIds = false
    local function excludeDef(con, def)
        excludeCategory(con, def, edits)
        if def.kind == "spells" then usesSpellIds = true end
    end
    local function withoutWhitelist(con)
        if not isEmpty(cats.whitelist) then addToSet(con, "excludeSpellIDs", cats.whitelist) end
        return con
    end

    local hiddenCount = #cats.hidden
    if hiddenCount == 0 and not cats.onlyShown then
        addGroup(plan, withoutWhitelist(cloneCon(base)), "All", look)
        return usesSpellIds
    end

    for i, def in ipairs(cats.shown) do
        local con = cloneCon(base)
        includeCategory(con, def, edits)
        if def.kind == "spells" then usesSpellIds = true end
        for j = 1, i - 1 do excludeDef(con, cats.shown[j]) end
        addGroup(plan, withoutWhitelist(con), def.label, look)
    end

    if not cats.onlyShown then
        local con = cloneCon(base)
        for _, def in ipairs(cats.hidden) do excludeDef(con, def) end
        for _, def in ipairs(cats.shown) do excludeDef(con, def) end
        addGroup(plan, withoutWhitelist(con), "All", look)
    end

    return usesSpellIds
end

--- The warnings that depend on the finished plan. R-11: an empty container under "only these
--- categories" with nothing shown and nothing whitelisted is a legitimate configuration to arrive at
--- by accident, so it carries its own warning rather than the generic NEVER_MATCHES.
local function finishWarnings(plan, unit, auraType, usesSpellIds, onlyShownEmpty)
    if usesSpellIds then
        local w = identityWarning(unit, auraType)
        if w then
            warn(plan, w)
        end
    end
    local groupCount = #plan.groups
    if groupCount == 0 then
        warn(plan, onlyShownEmpty and FC.WARN.ONLY_SHOWN_NONE or FC.WARN.NEVER_MATCHES)
    end
end

--- Appends the weapon-enchant block to a player buff container, in place. The weaponEnchants
--- category row, not a group: kind `enchant` matches no aura (splitCategories skips it), so Show is
--- simply "this container has enchant slots".
local function appendEnchants(plan, cfg, filter, ctx, auraType)
    local enchantState = (filter.categories or {}).weaponEnchants
    if auraType == "HELPFUL" and cfg.unit == "player" and enchantState ~= "hide" then
        plan.enchants = enchantBlock(filter, ctx.enchantSlots)
    end
end

--- The context both compile sites hand Compile: the learned timed spells (account-wide), the
--- profile's spell-list edits (schema v2), and the profile's enchant slots (schema v3). Any of them
--- is nil before the database exists.
--- @return table
function FC.ProfileContext()
    local db = NS.db
    return {
        timedSpells    = db and db.global and db.global.timedSpells,
        categorySpells = db and db.profile and db.profile.categorySpells,
        enchantSlots   = db and db.profile and db.profile.enchantSlots,
    }
end

--- Build the engine-facing plan for one container.
---
--- @param cfg table  the container's stored table (defaults/Profile.lua CONTAINER_TEMPLATE shape)
--- @param ctx table|nil  { categories = NS.Categories, timedSpells = { [id] = true },
---                  categorySpells = the profile's spell-list edits (schema v2),
---                  enchantSlots = the profile's weapon-enchant slots (schema v3) }
--- @return table  plan = { groups = { {key, filter, candidateFilters, sortMethod, sortDirection,
---                maxFrameCount, label} }, enchants = { slots, hidePermanent } | nil, warnings = {} }
function FC.Compile(cfg, ctx)
    ctx = ctx or {}
    local Categories = ctx.categories or NS.Categories
    local filter = cfg.filter or {}
    local plan = { groups = {}, warnings = {}, enchants = nil }
    local look = lookOf(filter)

    local auraType = cfg.auraType
    if auraType == "ENCHANT" then return compileEnchant(plan, cfg, filter, ctx) end
    if auraType ~= "HARMFUL" then auraType = "HELPFUL" end

    -- ── The base every group starts from ────────────────────────────────────────────────────
    local base = baseFor(auraType, filter.castBy)
    local timedIds = applyDuration(base, plan, filter, auraType, ctx.timedSpells)
    local whitelist, blacklisted = applyLists(base, filter)

    -- ── Categories: the whitelist group, then one per shown category, then the catch-all ────
    local shown, hidden = splitCategories(Categories, auraType, filter.categories or {})
    local whitelisted = addWhitelistGroup(plan, auraType, whitelist, look)
    local onlyShown = filter.onlyShown == true
    local categoryIds = addCategoryGroups(plan, base,
        { shown = shown, hidden = hidden, whitelist = whitelist, spellEdits = ctx.categorySpells,
          onlyShown = onlyShown }, look)

    -- ── Weapon enchants appended to a player buff container ─────────────────────────────────
    appendEnchants(plan, cfg, filter, ctx, auraType)

    local shownCount = #shown
    local onlyShownEmpty = onlyShown and shownCount == 0 and isEmpty(whitelist)
    finishWarnings(plan, cfg.unit, auraType, timedIds or blacklisted or categoryIds or whitelisted, onlyShownEmpty)
    return plan
end

--- Explain why one spell id will or will not be drawn by container `cfg`, under the same five-rank
--- priority `Compile` follows (docs/superpowers/specs/2026-09-14-feedback-batch6-design.md section
--- 6): the Overrides whitelist beats the blacklist, a category set to Show beats one set to Hide,
--- and an aura in no category is drawn unless `onlyShown` says otherwise. Pure, like `Compile`: no
--- frames, no database, `cfg`/`id`/`ctx` in, a table out — `FC.ProfileContext()` is the seam a
--- caller hands it the profile's spell-list edits through.
---
--- Reasons about `spells`-kind categories ONLY. A `token`, `flag` or `dispel` category matches
--- auras by a property the addon cannot look up from a bare spell id (an aura's own boss/role/
--- dispel flags, decided by the engine in its own secure code once auras are unreadable) — naming
--- one here would be a guess, and a confident guess is worse than silence. `categories` therefore
--- always lists only the spells-kind categories of this aura type that carry `id`, in declaration
--- order, each `{ key, label, state }` — `label` already routed through `NS.L`.
---
--- @param cfg table  the container's stored table (defaults/Profile.lua CONTAINER_TEMPLATE shape)
--- @param id number  the spell id to explain
--- @param ctx table|nil  as `Compile` takes: `{ categories, categorySpells }`
--- The spells-kind categories of `auraType` that claim `id`, in declaration order, each `{ key,
--- label, state }` — and whether any of them is a Show. Split out of `ExplainSpell` to keep both
--- under the file's complexity ceiling.
--- @return table claiming, boolean anyShow
local function claimingCategories(Categories, auraType, filter, categorySpells, id)
    local claiming, anyShow = {}, false
    for _, def in ipairs(Categories.For(auraType)) do
        if def.kind == "spells" and FC.CategorySpells(def, categorySpells)[id] then
            local state = ((filter.categories or {})[def.key] == "hide") and "hide" or "show"
            claiming[#claiming + 1] = { key = def.key, label = NS.L[def.label], state = state }
            anyShow = anyShow or (state == "show")
        end
    end
    return claiming, anyShow
end

--- @return table  { verdict = "shown"|"hidden", rank = 1..5, categories = { { key, label, state } } }
function FC.ExplainSpell(cfg, id, ctx)
    ctx = ctx or {}
    local filter = cfg.filter or {}
    if spellSet(filter.whitelist)[id] then
        return { verdict = "shown", rank = 1, categories = {} }
    end
    if spellSet(filter.blacklist)[id] then
        return { verdict = "hidden", rank = 2, categories = {} }
    end

    local Categories = ctx.categories or NS.Categories
    local auraType = (cfg.auraType == "HARMFUL") and "HARMFUL" or "HELPFUL"
    local claiming, anyShow = claimingCategories(Categories, auraType, filter, ctx.categorySpells, id)

    if isEmpty(claiming) then
        local hiddenByToggle = filter.onlyShown == true
        return { verdict = hiddenByToggle and "hidden" or "shown", rank = 5, categories = claiming }
    end
    if anyShow then
        return { verdict = "shown", rank = 3, categories = claiming }
    end
    return { verdict = "hidden", rank = 4, categories = claiming }
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
