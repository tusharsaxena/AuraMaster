local _, NS = ...

-- modules/FilterCompiler.lua — turns one container's filter settings into the aura GROUPS Blizzard's
-- aura container evaluates.
--
-- WHY A COMPILER. On Retail 12.1 an addon cannot read aura data while auras are secret, which is most
-- of the time that matters (combat, encounters, keys, PvP). The engine does the reading, in its own
-- secure code, and all it takes from us is a declaration per group: a filter STRING of tokens
-- (`HELPFUL|PLAYER|!CROWD_CONTROL`) and a table of CANDIDATE FILTERS (spell ids, dispel types, a few
-- aura booleans, a maximum duration). This file is the only place that knows how a player's
-- "show Defensive cooldowns, hide Consumables, only mine, under 60 s" becomes those declarations.
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
--     whitelist (rule 5 — an aura in no category). The catch-all is skipped instead whenever an
--     `uncategorized` category ACTUALLY SUPERSEDES it for this compile (below, `supersedesCatchAll`)
--     — not merely whenever one exists for the aura type: a Hide always supersedes it, but a Show
--     only does when `hasUnion` is true (fix round 3's asymmetry — where the union is empty, or the
--     engine might discard the ids that group is made of, the Show contributes no group of its own
--     and leaves the catch-all exactly as if the category did not exist).
--
-- Fix round 2 (batch 7): the per-container "Only these categories" toggle (`D8`/`R-8`..`R-11`) is
-- RETIRED. It once dropped the catch-all so a container drew only its whitelist plus its shown
-- categories; once `uncategorized`'s own group correctly supersedes the catch-all in both of its
-- states (fix round 1), the toggle had nothing left to drop — `uncategorized = "hide"` IS what it
-- used to mean, on buffs. The owner chose one concept over two controls that needed explaining
-- against each other. `core/Database.lua`'s schema step 4 migrates a stored `onlyShown = true` to
-- `categories.uncategorized = "hide"` so an existing container keeps drawing only what it
-- categorized rather than silently widening.
--
-- The blacklist applies to the base, so it reaches the shown groups and the catch-all, but never the
-- whitelist group. Kind `enchant` takes part in neither the shown groups nor the exclusions — it
-- matches no aura.
--
-- `uncategorized` (batch 7, docs/superpowers/specs/2026-09-15-feedback-batch7-design.md section 4,
-- ONE ROW PER AURA TYPE, ASYMMETRIC as of fix round 3, GATED ON THE UNIT as of issue #11 —
-- defaults/Categories.lua's KINDS doc has the full reasoning): "in none of the profile's SPELL-LIST
-- (kind `spells`) categories" — token/flag/dispel categories do not count toward being categorized.
-- `hasUnion` is what the asymmetry turns on, and it asks TWO questions, not one:
--
--     local hasUnion = FC.IdsAlwaysHonored(unit, auraType) and not isEmpty(cats.union or {})
--
-- because this row's Show has no positive constraint to offer. Its group's ONLY constraint is an
-- `excludeSpellIDs` of that union, so the group is worth emitting only where such a filter both
-- EXISTS and is CERTAIN to be applied. `FC.IdsAlwaysHonored` is that second half: the engine applies
-- include/exclude spell ids to buffs on friendly units and debuffs on hostile ones and discards them
-- everywhere else (AuraContainerUtil.CanApplyIdentityCandidateFilters), so the only containers where
-- a plan compiled today is CERTAIN of the answer are buffs on the player and the pet — the two units
-- that cannot turn hostile. A `target` or `focus` is whichever it happens to be when the engine
-- looks, which is not a thing the compiler can know at compile time.
--
-- The sibling predicate `FC.IdsHonored` answers the weaker "can the engine EVER honor ids here",
-- where `target`/`focus` are TRUE for both aura types, and is what `identityWarning` chooses its
-- sentence with. Two predicates, deliberately: conflating them is what produced a single gate that
-- called target/HARMFUL honored (emitting a group the engine discards the moment the target is
-- friendly) and target/HELPFUL unhonored (dropping the group fix round 1 exists for) in one breath.
--
--   * `hasUnion` true: Show compiles to its own group like any other shown category, but as an
--     EXCLUDE of that union (there is no id list of "every other spell" to include), carrying no
--     hidden-category exclusion of its own — that is what rescues a cancelable-but-unlisted buff from
--     a Hidden `Cancelable` (the defect fix round 1 fixed). Hide has no negative way to express "not
--     uncategorized" (no id list to subtract), so it contributes nothing of its own.
--   * `hasUnion` false: Show contributes NO group at all. With an empty union the group would carry
--     no `excludeSpellIDs` in the first place; where the engine may discard ids it carries one that
--     can be thrown away before evaluation. Both paths end in the same place — an unrestricted
--     "every aura not otherwise Shown" group that draws right through every category's Hide, since
--     every aura is then trivially "not on any spell list" (proven concretely, fix round 3: shipping
--     it produced a single group with no candidate filter, matching everything). Hide still
--     contributes nothing of its own either, for the same "no id list to subtract" reason as the
--     true side.
--
-- WHICH CONTAINERS LAND ON WHICH SIDE, and why the unit half is not a formality. Through fix round 3
-- the gate was the union alone, and on debuffs that was indistinguishable from the rule above for
-- exactly one reason: `Cat.HARMFUL` carried no `spells`-kind category at all, so the debuff union was
-- empty on every container ever compiled and the two questions could not disagree there. Issue #11
-- adds `hardCC` and `softCC` to `Cat.HARMFUL` and ends that. A PLAYER debuff container then has a
-- non-empty union AND an engine that discards debuff ids on the player: the union test alone would
-- say "emit the group", the engine would strip that group's one constraint, and the container would
-- draw every debuff — neutering every Hide on the tab. That is fix round 3's failure arriving through
-- a new door, which is why the gate is written against the general question (is a spell-id filter on
-- THIS container CERTAIN to be applied?) and never against the aura type.
--
-- A `target` or `focus` debuff container lands on the same side as the player one, and that is the
-- point rather than an oversight: the target's hostility is dynamic, the plan is compiled once and
-- long before anyone looks at the unit, and the moment the target is FRIENDLY the engine throws that
-- group's `excludeSpellIDs` away and the group draws every debuff. For the `uncategorized` row, a
-- group that is harmless on a hostile target and unconstrained on a friendly one is a group that
-- cannot ship, so MAY-discard is treated exactly like WILL-discard. Read that as a rule about THIS
-- ROW and nothing wider: the gate does not, and deliberately must not, make a degenerate group
-- impossible in general — see THE ACCEPTED RESIDUAL below, which is exactly that shape, shipping on
-- purpose, under the same uncertainty.
--
-- THIS ALSO CLOSES A LATENT BUG THAT PREDATES ISSUE #11 — verified against the tree at HEAD, not
-- inferred: with the gate written as the union alone, a HOSTILE `target` or `focus` BUFF container
-- with `uncategorized` (the buff row) Shown and any other category Hidden (the R-4 branch — R-3
-- emits one group and never reaches the gate) has always emitted exactly that degenerate group:
-- `Cat.HELPFUL`'s nine `spells`-kind categories make its union non-empty on every profile,
-- `includeCategory` gives the row nothing but the complement `excludeSpellIDs`, and the engine
-- discards buff ids on a hostile unit — leaving a group constrained by the base token alone, which
-- draws every buff AND suppressed the catch-all on its way in. The union test never asked the unit.
--
-- THE ACCEPTED COST of closing both, ruled on by the owner (issue #11, 2026-09-20) and pinned by a
-- test rather than left to drift: on a FRIENDLY `target`/`focus` BUFF container, Uncategorized Show
-- no longer rescues an unlisted buff from another category's Hide the way it does on the player. That
-- rescue was real and is genuinely lost. It is a niche rescue on one unit weighed against defeating
-- every Hide on the tab by default on the same unit, and the niche rescue loses.
--
-- THE ACCEPTED RESIDUAL, ruled on by the owner in the same breath (issue #11, 2026-09-20) and also
-- pinned by a test: a `spells`-kind SHOWN category still compiles to a group whose only constraint
-- beyond the base aura-type token is an `includeSpellIDs` of its list (`includeCategory`, the
-- `spells` branch), and on a `target` or `focus` the engine MAY discard exactly that. Once `hardCC`
-- ships, a TARGET debuff container with Hard CC Shown draws every debuff the moment it is FRIENDLY —
-- structurally the same degenerate shape the gate above now forbids the `uncategorized` row. This is
-- KNOWN, ACCEPTED and deliberately NOT suppressed, for three reasons:
--
--   * Suppressing it would delete the feature's primary use case. `hardCC` and `softCC` exist to
--     answer "is my sheep / my stun on the target", and in that scenario the target is HOSTILE, which
--     is precisely where the ids do bite. A filter that refuses to work in the case it was built for
--     is worse than one that is over-broad in a case nobody sets it up for.
--   * It is the engine limitation this addon already documents and already warns about, per
--     container: docs/scope.md's "Out of reach on this client" -> "Spell-id filtering everywhere",
--     and `FC.WARN.IDS_HOSTILE_ONLY` / `IDS_FRIENDLY_ONLY` through `identityWarning`. The warning
--     genuinely fires on this path and is not a hope: `addShownGroups` sets `usesSpellIds` for a
--     `spells`-kind Show, and `finishWarnings` prints the sentence off that flag. So the player is
--     told "spell lists only apply while the unit is hostile" on the very container that has it.
--   * It differs from the `uncategorized` case IN KIND, not merely in degree, and that is the whole
--     reason one is closed and the other is not. An `uncategorized` Show SUPERSEDES the catch-all, so
--     when its group degenerates it has already REMOVED the one group carrying every Hidden
--     category's negations — the tab loses its Hides. An over-broad `spells` Show group sits BESIDE
--     the other groups and removes nothing: the catch-all and every other shown group compile
--     exactly as they would have, so the failure is "this one group matched more than the player
--     meant" and not "the container stopped filtering".
--
-- The union is still COMPUTED either way, and a Hide's `excludeSpellIDs` still ships even where the
-- engine ignores it: an ignored exclude costs nothing, suppressing it would change no outcome, and
-- the profile's other containers may point the same categories at a unit where it bites. What the
-- gate governs is narrower and exact — whether an `uncategorized` row may contribute a group of its
-- own and thereby supersede the catch-all.
--
-- Either way `uncategorized`'s presence SUPERSEDES the catch-all rather than sitting beside it, but
-- only in the states where it actually replaces what the catch-all would do:
--   * Show with `hasUnion` true: `uncategorized`'s own group carries no hidden-category exclusion
--     (the whole point), while the catch-all DOES, on top of the same shown-category exclusions — so
--     the catch-all's constraints are a strict SUBSET of `uncategorized`'s group's, and shipping both
--     would draw the same aura twice. Suppressed.
--   * Show with `hasUnion` false: `uncategorized` contributes no group (above), so there is nothing
--     to supersede the catch-all with — it must stay, unsuppressed, exactly as if this category did
--     not exist. This is the fix round 3 correction: round 1 suppressed it unconditionally on Show,
--     which is only safe when `hasUnion` is true.
--   * Hide, either `hasUnion`: the only possible catch-all contribution would be an INCLUDE
--     restricted to the union — but the catch-all already EXCLUDES every one of those same ids (each
--     spells-kind category is in `shown` or `hidden`, both swept into its exclusions), so that INCLUDE
--     could never match anything (`hasUnion` true), or is simply moot (`hasUnion` false — the union
--     is empty, or the engine would throw the ids away unread). Either way Hide suppresses the
--     catch-all outright — on a player debuff container this reproduces the retired "Only these
--     categories" toggle exactly (fix round 2).
--
-- A group whose constraints contradict themselves (it would need both `X` and `!X`) is dropped rather
-- than handed to the engine, because it could never match anything.

NS.FilterCompiler = NS.FilterCompiler or {}
local FC = NS.FilterCompiler

-- Every warning a plan can carry, as one whole sentence each: the settings panel prints them
-- through NS.L (settings/OptionsSetup.lua's RenderWarnings), so each must be a single literal the
-- locale file can list and tests/test_locale.lua can find.
FC.WARN = {
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

--- The union of every SPELLS-kind category's EFFECTIVE ids for `auraType` (`FC.CategorySpells`, so
--- the profile's own edits count, not just the shipped starters). This union IS what `uncategorized`
--- is defined against (D3, docs/superpowers/specs/2026-09-15-feedback-batch7-design.md section 4):
--- an aura is "uncategorized" when its id is outside it. Blizzard token/flag/dispel categories never
--- contribute — they do not count toward being categorized.
--- @return table [spellId] = true
local function categorizedUnion(Categories, auraType, spellEdits)
    local union = {}
    for _, def in ipairs(Categories.For(auraType)) do
        if def.kind == "spells" then
            for id in pairs(FC.CategorySpells(def, spellEdits)) do union[id] = true end
        end
    end
    return union
end

--- Exclude category `def` from `con`: a Hide, or an earlier Show being kept out of a later shown
--- group so an aura matching two shown categories is drawn once, under the first. Kind `enchant`
--- never reaches here — it matches no aura at all, deciding only whether the container's weapon-
--- enchant slots exist (splitCategories skips it categorically). Kind `uncategorized` never reaches
--- here either, despite taking part in the shown/hidden partition (unlike `enchant`, it DOES match
--- auras) — it has no id list of its own to negate. It can also never be an "earlier shown category"
--- since it is always last (U-1). `excludeGuarded` (below `addShownGroups`) is what actually guards
--- the call — see `addCategoryGroups`'s `supersedesCatchAll` for when its Hide or Show state removes
--- the catch-all entirely rather than merely being excluded from it.
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
--- Kind `uncategorized` (U-3) is the one exception to "positive constraint": there is no id list to
--- hand the engine as "everything outside every spell list", so its Show is expressed as its own
--- negative — `excludeSpellIDs` of `union`, the complement `categorizedUnion` computed — carrying NO
--- other exclusion (not even an empty-union conflict: an empty union means nothing is categorized, so
--- every aura passes, which is exactly what an absent `excludeSpellIDs` already means).
local function includeCategory(con, def, spellEdits, union)
    local kind = def.kind
    if kind == "token" then
        addToken(con, def.token)
    elseif kind == "flag" then
        setFlag(con, def.field, def.value)
    elseif kind == "dispel" then
        addToSet(con, "includeDispelTypes", def.types)
    elseif kind == "uncategorized" then
        if union and not isEmpty(union) then addToSet(con, "excludeSpellIDs", union) end
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

--- Whether the engine can EVER honor include/exclude spell ids for this unit and aura type. Blizzard
--- applies them to buffs on friendly units and debuffs on hostile ones, and discards them everywhere
--- else (AuraContainerUtil.CanApplyIdentityCandidateFilters). `target` and `focus` therefore answer
--- TRUE for BOTH aura types: whichever the unit turns out to be, one of the two aura types bites
--- there, and this predicate asks only whether the filter is capable of doing anything at all. Only
--- the player and the pet are pinned: they are never hostile to you, so their DEBUFF ids are
--- discarded outright and no play can change that.
---
--- This is the WARNING predicate, and deliberately only that. `identityWarning` (below) is its one
--- caller inside this file, and "can this ever do anything?" is exactly the right question for a
--- sentence on the Filters page: a `target` buff list is worth keeping and worth a caveat, not worth
--- calling dead. It is the WRONG question for the compile gate, because a plan is compiled today for
--- a unit nobody has looked at yet, and a CAN-ever that is only sometimes true is a group the engine
--- may silently strip. `FC.IdsAlwaysHonored` is that second, stricter question. The two were ONE
--- predicate when issue #11's gate was first written, and conflating them is precisely what made it
--- self-contradictory: target/HARMFUL "honored" (emitting a group the engine discards the moment the
--- target is friendly) and target/HELPFUL "not honored" (dropping the very group fix round 1 exists
--- for) — the same conditionality, opposite treatment, in one function.
--- @param unit string|nil  the container's unit (core/Constants.lua C.UNITS)
--- @param auraType string  "HELPFUL" or "HARMFUL"
--- @return boolean
function FC.IdsHonored(unit, auraType)
    if auraType == "HARMFUL" then
        return not (unit == "player" or unit == "pet")
    end
    return true
end

--- Whether the engine UNCONDITIONALLY honors include/exclude spell ids for this unit and aura type —
--- true for buffs on the player and the pet, and false everywhere else. Every `target`/`focus` answer
--- is FALSE however plausible the common case looks, because hostility is dynamic and the plan is
--- compiled long before anyone looks at the unit; HARMFUL on player/pet is false for the blunter
--- reason that ids are never honored there at all.
---
--- This is the GATE predicate. Two call sites read it and MUST stay in lockstep — `addCategoryGroups`
--- (what the plan actually contains) and the `FC.ExplainSpell` path into `explainUncategorized` (what
--- the Filters page says the plan contains). WHY IT IS THE STRICTER QUESTION: an `uncategorized` Show
--- group carries an `excludeSpellIDs` of the categorized union as its ONLY constraint beyond the base
--- aura-type token (`includeCategory`, U-3) — there is no id list of "every other spell" to include.
--- Wherever the engine MAY discard that exclude, the group degenerates into "every aura of this type"
--- and, because its presence supersedes the catch-all, defeats every Hide on the tab. MAY is enough
--- to sink it: a group that is correct while the unit points one way and unconstrained the moment it
--- points the other cannot ship (buffs on a hostile target, debuffs on a friendly one — the two cases
--- a compile cannot rule out). So the row may contribute a group of its own only where ids are
--- CERTAIN. Note the scope of that "cannot ship": it is about THIS row, whose group supersedes the
--- catch-all and therefore takes the tab's Hides down with it. A `spells`-kind Show degenerates under
--- the same uncertainty and ships anyway, on purpose — the top-of-file comment's ACCEPTED RESIDUAL
--- has that ruling and why the two cases differ in kind.
---
--- KNOWN LIMITATION, accepted deliberately by the owner (issue #11, 2026-09-20): on a FRIENDLY target
--- or focus BUFF container, Uncategorized Show no longer rescues an unlisted buff from another
--- category's Hide the way fix round 1 made it do on the player. The rescue is genuinely lost, and
--- losing a niche rescue beats defeating every Hide by default. The top-of-file comment carries the
--- same note, along with the latent pre-#11 bug this closes on a hostile target.
--- @param unit string|nil  the container's unit (core/Constants.lua C.UNITS)
--- @param auraType string  "HELPFUL" or "HARMFUL"
--- @return boolean
function FC.IdsAlwaysHonored(unit, auraType)
    return auraType == "HELPFUL" and (unit == "player" or unit == "pet")
end

--- When a container relies on a spell-id filter the engine will not honor, say so instead of letting
--- the filter look broken. This chooses only the SENTENCE, and it chooses it from `FC.IdsHonored` —
--- the CAN-ever predicate, never the gate one — so the three sentences a container can print are the
--- same three, for the same units, as before issue #11 split the predicate in two. Three of them,
--- because a player's own debuffs are discarded outright while a target's or focus's are merely
--- conditional on which way the unit points, and a player who cannot tell those apart cannot fix
--- either: the first is a setting that will never do anything, the second is one that will do
--- something later.
local function identityWarning(unit, auraType)
    if not FC.IdsHonored(unit, auraType) then
        -- Only HARMFUL on player/pet reaches here: the one combination the engine refuses outright.
        return FC.WARN.IDS_OWN_DEBUFFS
    end
    if auraType == "HARMFUL" then
        return FC.WARN.IDS_HOSTILE_ONLY
    end
    if unit == "target" or unit == "focus" then
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
--- slots (Compile). Kind `uncategorized` is NOT skipped — unlike `enchant` it DOES
--- match auras (U-1) — it partitions like every other category; only ITS group logic differs
--- (`includeCategory`/`addCategoryGroups`), because it has no id list of its own, only the complement
--- of every `spells`-kind category's union. Every other category is either Hide or Show — the default
--- state (defaults/Categories.lua's `DefaultStates`) stamps every key "show" — so this is a true
--- partition.
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

--- Whether any def in `list` carries kind `kind`.
--- @return boolean
local function anyKind(list, kind)
    for _, def in ipairs(list) do
        if def.kind == kind then return true end
    end
    return false
end

--- Exclude `def` from `con` unless it is kind `uncategorized` — it has no id list to subtract (see
--- the top-of-file comment): a Hide of it is handled by suppressing the catch-all outright, not by
--- contributing an exclusion here, and it can never be an "earlier shown category" either, since it
--- is always declared last (U-1). Shared by `addShownGroups`' dedup and `addCatchAllGroup`.
--- @return boolean usedSpellIds
local function excludeGuarded(con, def, edits)
    if def.kind == "uncategorized" then return false end
    excludeCategory(con, def, edits)
    return def.kind == "spells"
end

--- One group per SHOWN category (R-4): the base plus that category's positive constraint
--- (`includeCategory`), minus every earlier shown category (`excludeGuarded`, so an aura in two shown
--- categories is drawn once, under the first) and the whitelist. `uncategorized` (U-3) rides this
--- loop like any other shown category when `hasUnion` — `includeCategory` gives it the complement
--- exclude instead of a positive include, and needs no special dedup of its own since it is always
--- last (U-1) — but contributes NO group at all when `hasUnion` is false (fix round 3, generalized to
--- the unit by issue #11): with no union, or with a unit whose spell-id filters the engine may
--- discard, the group's one constraint is absent or thrown away, every aura trivially qualifies, and
--- the unrestricted group left over would draw everything and defeat every other category's Hide (the
--- top-of-file comment has the concrete proof for both paths). Skipping it here is
--- what makes it behave as if the row did not exist in that case, catch-all included — see
--- `addCategoryGroups`.
--- @return boolean usesSpellIds
local function addShownGroups(plan, base, cats, look, hasUnion)
    local edits, union = cats.spellEdits, cats.union or {}
    local usesSpellIds = false
    for i, def in ipairs(cats.shown) do
        if not (def.kind == "uncategorized" and not hasUnion) then
            local con = cloneCon(base)
            includeCategory(con, def, edits, union)
            if def.kind == "spells" or def.kind == "uncategorized" then usesSpellIds = true end
            for j = 1, i - 1 do
                usesSpellIds = excludeGuarded(con, cats.shown[j], edits) or usesSpellIds
            end
            if not isEmpty(cats.whitelist) then addToSet(con, "excludeSpellIDs", cats.whitelist) end
            -- The RAW `def.label`, not `NS.Categories.LabelOf(def)`: a plan group's label is an
            -- internal name nothing draws, so it stays the locale KEY for a shipped category. Do
            -- not "fix" this into a lookup -- routing it is what would drag a player's own category
            -- name through NS.L, which is the one thing the name must never go through.
            addGroup(plan, con, def.label, look)
        end
    end
    return usesSpellIds
end

--- The catch-all group (R-5): the base minus every hidden AND every shown category, minus the
--- whitelist — what draws an aura in no category at all. The caller (`addCategoryGroups`) skips this
--- entirely whenever `uncategorized` ACTUALLY supersedes it (`supersedesCatchAll`) — see the
--- top-of-file comment for why shipping both would either double-draw what `uncategorized`'s own
--- group already covers, or ship a group that could never match. That is not every time an
--- `uncategorized` category exists for the aura type, though: wherever `hasUnion` is false with it
--- Shown (an empty union, or a unit whose ids the engine is not CERTAIN to apply — fix round 3,
--- generalized to the unit by issue #11), it does NOT supersede the catch-all, so `cats.shown`
--- genuinely can contain that kind here — `excludeGuarded`'s own no-op guard is what keeps this
--- group correct in that case (it contributes no exclusion, exactly as a category with no id list
--- of its own should).
--- @return boolean usesSpellIds
local function addCatchAllGroup(plan, base, cats, look)
    local edits = cats.spellEdits
    local usesSpellIds = false
    local con = cloneCon(base)
    for _, def in ipairs(cats.hidden) do
        usesSpellIds = excludeGuarded(con, def, edits) or usesSpellIds
    end
    for _, def in ipairs(cats.shown) do
        usesSpellIds = excludeGuarded(con, def, edits) or usesSpellIds
    end
    if not isEmpty(cats.whitelist) then addToSet(con, "excludeSpellIDs", cats.whitelist) end
    addGroup(plan, con, "All", look)
    return usesSpellIds
end

--- The category groups (R-3, R-4, R-5). `cats` = { shown, hidden, whitelist, spellEdits, union }.
--- Every group excludes the whitelist (it has its own group and must not be drawn twice); the
--- whitelist itself is never touched by the blacklist (R-7 — it lives on `base`).
---
---   * No category Hidden (R-3): exactly ONE group, the base minus the whitelist. A Show cannot
---     rescue anything when nothing is hiding, so the per-shown-category groups below would be pure
---     cost — this is what keeps a default container at one group.
---   * Otherwise (R-4): `addShownGroups` plus `addCatchAllGroup` (R-5) — unless `uncategorized`
---     actually supersedes the catch-all for this compile (fix round 1, corrected fix round 3): Hide
---     always does (whatever `hasUnion` is); Show does only when `hasUnion` is true, since a Show
---     that contributes no group of its own (`addShownGroups`) has nothing to supersede the catch-all
---     WITH. Fix round 2 retired the per-container "Only these categories" toggle (`D8`) that used to
---     drop the catch-all on its own: once `uncategorized` does that correctly, the toggle had
---     nothing left to do.
---
--- `unit` and `auraType` are here for `hasUnion` alone (below, via `FC.IdsAlwaysHonored`) — no
--- group's constraints depend on them; `base` already carries the aura type as a token.
--- @return boolean usesSpellIds
local function addCategoryGroups(plan, base, cats, look, unit, auraType)
    local hiddenCount = #cats.hidden
    if hiddenCount == 0 then
        local con = cloneCon(base)
        if not isEmpty(cats.whitelist) then addToSet(con, "excludeSpellIDs", cats.whitelist) end
        addGroup(plan, con, "All", look)
        return false
    end

    -- BOTH halves, and the first one is the one that is easy to drop. `uncategorized`'s Show group is
    -- made of nothing but an `excludeSpellIDs` of the union, so a union the engine MIGHT discard buys
    -- exactly as little as no union at all — it ships a group with no effective constraint, which
    -- draws every aura and neuters every Hide on the tab (fix round 3's failure; issue #11's `hardCC`
    -- and `softCC` are what let a debuff container reach it, and a hostile-target BUFF container has
    -- reached it since long before #11). Hence `IdsAlwaysHonored`, the CERTAIN predicate, and not the
    -- CAN-ever `IdsHonored` the warning prints from: on a `target` the answer changes under the
    -- compiler's feet, and a group that is safe one second and unconstrained the next cannot ship.
    -- This gate governs ONLY whether an `uncategorized` row may contribute its own group and
    -- supersede the catch-all: the union is computed regardless and a Hide's exclusions still ship,
    -- because an exclude the engine ignores costs nothing and suppressing it would change no outcome.
    local hasUnion = FC.IdsAlwaysHonored(unit, auraType) and not isEmpty(cats.union or {})
    local usesSpellIds = addShownGroups(plan, base, cats, look, hasUnion)

    local supersedesCatchAll = anyKind(cats.hidden, "uncategorized")
        or (hasUnion and anyKind(cats.shown, "uncategorized"))
    if not supersedesCatchAll then
        usesSpellIds = addCatchAllGroup(plan, base, cats, look) or usesSpellIds
    end

    return usesSpellIds
end

--- The warnings that depend on the finished plan.
local function finishWarnings(plan, unit, auraType, usesSpellIds)
    if usesSpellIds then
        local w = identityWarning(unit, auraType)
        if w then
            warn(plan, w)
        end
    end
    -- A buff container showing only Weapon enchants (schema v5) draws its enchant slots and no aura
    -- group: that is what it is for, not a filter that can never match.
    local groupCount = #plan.groups
    if groupCount == 0 and not plan.enchants then
        warn(plan, FC.WARN.NEVER_MATCHES)
    end
end

--- Appends the weapon-enchant block to a player buff container, in place. Kind-driven, like
--- `splitCategories`: whichever category (or categories) of this aura type carry kind `enchant`
--- decide it, not the literal key `weaponEnchants` — so a second enchant-kind category could not be
--- silently ignored here while `splitCategories` still skips it. Kind `enchant` matches no aura
--- (splitCategories skips it), so Show is simply "this container has enchant slots"; any one of
--- them set to Hide is enough to drop the block.
local function appendEnchants(plan, cfg, filter, ctx, auraType, Categories)
    if not (auraType == "HELPFUL" and cfg.unit == "player") then return end
    local states = filter.categories or {}
    for _, def in ipairs(Categories.For(auraType)) do
        if def.kind == "enchant" and states[def.key] == "hide" then
            return
        end
    end
    plan.enchants = enchantBlock(filter, ctx.enchantSlots)
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
    if auraType ~= "HARMFUL" then auraType = "HELPFUL" end

    -- ── The base every group starts from ────────────────────────────────────────────────────
    local base = baseFor(auraType, filter.castBy)
    local timedIds = applyDuration(base, plan, filter, auraType, ctx.timedSpells)
    local whitelist, blacklisted = applyLists(base, filter)

    -- ── Categories: the whitelist group, then one per shown category, then the catch-all ────
    local shown, hidden = splitCategories(Categories, auraType, filter.categories or {})
    local whitelisted = addWhitelistGroup(plan, auraType, whitelist, look)
    local union = categorizedUnion(Categories, auraType, ctx.categorySpells)
    local categoryIds = addCategoryGroups(plan, base,
        { shown = shown, hidden = hidden, whitelist = whitelist, spellEdits = ctx.categorySpells,
          union = union }, look, cfg.unit, auraType)

    -- ── Weapon enchants appended to a player buff container ─────────────────────────────────
    appendEnchants(plan, cfg, filter, ctx, auraType, Categories)

    finishWarnings(plan, cfg.unit, auraType, timedIds or blacklisted or categoryIds or whitelisted)
    return plan
end

--- The spells-kind categories of `auraType` that claim `id`, in declaration order, each `{ key,
--- label, state }` — and whether any of them is a Show. Split out of `ExplainSpell` to keep both
--- under the file's complexity ceiling.
--- @return table claiming, boolean anyShow
local function claimingCategories(Categories, auraType, filter, categorySpells, id)
    local claiming, anyShow = {}, false
    for _, def in ipairs(Categories.For(auraType)) do
        if def.kind == "spells" and FC.CategorySpells(def, categorySpells)[id] then
            local state = ((filter.categories or {})[def.key] == "hide") and "hide" or "show"
            -- NS.Categories, not the injected `Categories`: `LabelOf` is a pure function of one
            -- definition, so it does not belong to whichever category SET a caller handed in.
            local label = NS.Categories.LabelOf(def)
            claiming[#claiming + 1] = { key = def.key, label = label, state = state }
            anyShow = anyShow or (state == "show")
        end
    end
    return claiming, anyShow
end

--- `auraType`'s `uncategorized` category def, or nil (a future aura type that never gets one). Both
--- HELPFUL and HARMFUL carry one as of fix round 3 (defaults/Categories.lua's KINDS doc). Unlike
--- `token`/`flag`/`dispel`, this one needs no guess: whether `id` is on any `spells`-kind list is
--- exactly what `claimingCategories` (empty `claiming`) already answers, so `ExplainSpell` can report
--- it with the same confidence as a spells-kind category.
--- @return table|nil
local function uncategorizedDef(Categories, auraType)
    for _, def in ipairs(Categories.For(auraType)) do
        if def.kind == "uncategorized" then return def end
    end
    return nil
end

--- `ExplainSpell`'s rank-5 case: `id` is on no `spells`-kind list. Mirrors `addCategoryGroups`'
--- asymmetry (fix round 3) exactly, because the two must never disagree about what the compiled plan
--- actually draws:
---   * Hide, whatever `hasUnion` is: rank 4 — `addCategoryGroups` suppresses the catch-all outright
---     on Hide regardless, so nothing is left to draw an aura that reaches here.
---   * Show with `hasUnion` true: rank 3 — a real rescuing group, same as any other Show.
---   * Show with `hasUnion` false, or no `uncategorized` category at all (should not arise
---     post round 3, but a future shape might): the row contributes NO group of its own
---     (`addShownGroups`) and does not supersede the catch-all (`addCategoryGroups`), so it decides
---     nothing — this falls through to the ordinary rank 5, exactly as if the row did not exist. No
---     category is named in either rank-5 branch (a `token`/`flag`/`dispel` guess is never made —
---     see `ExplainSpell`'s comment).
---
--- THE APPROXIMATION (review, item 6): the Hide branch's "hidden, rank 4" is confident about
--- `uncategorized` itself, but NOT about the aura as a whole — `id` might still genuinely belong to a
--- Shown `token`/`flag`/`dispel` category the addon cannot check from a bare id (the same silence
--- `ExplainSpell`'s own comment already names), in which case rank 3 there would actually draw it and
--- this "hidden" verdict would be wrong. An Overrides note built on this can therefore claim the
--- whitelist "overrode" a Hide that, in the real compiled plan, never removed anything to begin with.
--- This is not new to `uncategorized` — every rank-4 verdict `ExplainSpell` reports already carries
--- the same silent gap — but it is worth naming here specifically, since a Hide `uncategorized`
--- verdict looks unusually definite (one row decided it) when it is really no more certain than any
--- other rank 4.
--- @return table  { verdict, rank, categories }
local function explainUncategorized(Categories, auraType, filter, hasUnion)
    local def = uncategorizedDef(Categories, auraType)
    if def then
        local hidden = (filter.categories or {})[def.key] == "hide"
        if hidden then
            local entry = { { key = def.key, label = NS.Categories.LabelOf(def), state = "hide" } }
            return { verdict = "hidden", rank = 4, categories = entry }
        end
        if hasUnion then
            local entry = { { key = def.key, label = NS.Categories.LabelOf(def), state = "show" } }
            return { verdict = "shown", rank = 3, categories = entry }
        end
    end
    return { verdict = "shown", rank = 5, categories = {} }
end

--- Explain why one spell id will or will not be drawn by container `cfg`, under the same five-rank
--- priority `Compile` follows (docs/superpowers/specs/2026-09-14-feedback-batch6-design.md section
--- 6): the Overrides whitelist beats the blacklist, a category set to Show beats one set to Hide, and
--- an aura in no category is drawn — nothing removed it — unless the aura type carries its own
--- `uncategorized` category, whose own state then decides it instead (`explainUncategorized`) — a
--- real rescue on Show only under the same `hasUnion` the compiler gates on, both halves of it
--- (fix round 3's asymmetry, gated on the unit by issue #11): a container whose union is empty, or
--- whose unit and aura type leave the engine free to discard spell ids, compiles no rescuing group,
--- and an explanation that named one would describe a group the plan does not contain. Pure,
--- like `Compile`: no frames, no database, `cfg`/`id`/`ctx` in, a table out — `FC.ProfileContext()`
--- is the seam a caller hands it the profile's spell-list edits through.
---
--- Reasons about `spells`-kind categories, and `uncategorized` (`explainUncategorized`), ONLY. A
--- `token`, `flag` or `dispel` category matches auras by a property the addon cannot look up from a
--- bare spell id (an aura's own boss/role/dispel flags, decided by the engine in its own secure code
--- once auras are unreadable) — naming one here would be a guess, and a confident guess is worse than
--- silence. `categories` therefore always lists only the spells-kind categories of this aura type
--- that carry `id` (plus, when `id` is on none of them, `uncategorized`'s own entry), in declaration
--- order, each `{ key, label, state }` — `label` already routed through `NS.L`.
---
--- @param cfg table  the container's stored table (defaults/Profile.lua CONTAINER_TEMPLATE shape)
--- @param id number  the spell id to explain
--- @param ctx table|nil  as `Compile` takes: `{ categories, categorySpells }`
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
        -- The same two-part `hasUnion` `addCategoryGroups` computes, for the same reason and from the
        -- same predicate — `IdsAlwaysHonored`, the gate one, never the CAN-ever `IdsHonored`. These
        -- two sites must never disagree: this one only describes the plan the other one built, and an
        -- explanation naming a rescuing group the plan does not contain is worse than no explanation.
        local hasUnion = FC.IdsAlwaysHonored(cfg.unit, auraType)
            and not isEmpty(categorizedUnion(Categories, auraType, ctx.categorySpells))
        return explainUncategorized(Categories, auraType, filter, hasUnion)
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
