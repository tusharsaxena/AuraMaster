local _, NS = ...

-- defaults/Categories.lua — the aura CATEGORIES a container's filter can show or hide.
--
-- A category is one of six KINDS, and the kind decides how modules/FilterCompiler.lua turns it into
-- something Blizzard's aura container evaluates in its own secure code (we never see aura data in
-- combat, so every filter has to be declared up front — see docs/data-flow.md):
--
-- Show is the absence of a decision (schema v3) in the sense that it never NARROWS what draws: it is
-- the default every key starts at (`DefaultStates` below). It is not inert, though (batch 6's filter-
-- priority revision, modules/FilterCompiler.lua) — a Show is a POSITIVE claim that beats a Hide on
-- the same aura, and once any category is Hidden the compiler emits one group PER Show category
-- (plus a catch-all), not the single group a container with nothing Hidden still gets. Only Hide
-- writes a constraint, an exclusion, and only on the group(s) it actually reaches.
--
--   token          an aura filter token (`BIG_DEFENSIVE`, `CROWD_CONTROL`, …). Hiding it adds the
--                  negation `!TOKEN` to the group's filter string.
--   flag           a boolean candidate filter on the aura (`isBossAura`, `isRoleAura`, …). Hiding it
--                  asks for `not value`.
--   dispel         a set of dispel types. Hiding it adds to `excludeDispelTypes`.
--   spells         a curated list of spell ids. Hiding it adds to `excludeSpellIDs`. Blizzard only
--                  honors spell ids for BUFFS ON FRIENDLY UNITS and DEBUFFS ON HOSTILE ONES, so a
--                  buff category's list bites on the player, the pet and a friendly target or focus,
--                  and a debuff category's list bites on a HOSTILE target or focus and nowhere else
--                  (issue #11 gave `Cat.HARMFUL` its first two, `hardCC` and `softCC`). The Filters
--                  page and General -> Spell Categories say so where it matters (docs/scope.md,
--                  "What the engine cannot do").
--   enchant        the player's temporary weapon enchants. The odd one out: it matches no aura and
--                  joins no aura group. Hide takes the container's enchant slots away, Show gives
--                  them back (modules/FilterCompiler.lua's Compile, not its group builder).
--   uncategorized  batch 7, `U-1`..`U-5` (docs/superpowers/specs/2026-09-15-feedback-batch7-design.md
--                  section 4): "in none of the profile's SPELL-LIST (kind `spells`) categories" —
--                  Blizzard token/flag/dispel categories do NOT count toward being categorized. It has
--                  no id list of its own; it is the COMPLEMENT of every `spells`-kind category's
--                  effective ids, so modules/FilterCompiler.lua handles it with dedicated logic rather
--                  than the generic per-kind include/exclude every other kind shares. Drawn LAST in the
--                  grid, default Show. There is no General -> Spell Categories entry for it: it has no
--                  list to edit.
--
--                  ONE ROW PER AURA TYPE, ASYMMETRIC (fix round 3, 2026-09-16 — the owner restored the
--                  debuff row round 1 dropped; issue #11's part A2 re-derived the asymmetry from the
--                  UNIT rather than from the aura type). Both rows' unions are now genuine subsets —
--                  `Cat.HELPFUL` has always had `spells`-kind categories and `Cat.HARMFUL` gained
--                  `hardCC` and `softCC` below — so what decides whether a Show row may contribute a
--                  group of its own is no longer "is the union empty" but "is the one constraint that
--                  group would carry CERTAIN to be applied". Its only constraint is an
--                  `excludeSpellIDs` of the union, and the engine discards spell ids except for buffs
--                  on friendly units and debuffs on hostile ones — so the gate is
--                  `modules/FilterCompiler.lua`'s `FC.IdsAlwaysHonored(unit, auraType)`, TRUE ONLY for
--                  buffs on the player and the pet, the two units that cannot turn hostile. It is a
--                  gate of its own, NOT the `FC.IdsHonored` the identity warning reads and not
--                  computed from it: the warning answers the weaker "can the engine EVER honor ids
--                  here", where a `target` or `focus` is true for both aura types (A2a ruling 1).
--
--                  So the row SUPERSEDES the catch-all only where that gate holds. There: Show
--                  excludes the union (rescuing an unlisted buff from another category's Hide) and
--                  Hide contributes nothing of its own, since there is no id list of "every other
--                  spell" to subtract. Everywhere else — every debuff container, and a `target` or
--                  `focus` buff container whose unit may be hostile when the engine looks — Show
--                  contributes NOTHING and the ordinary catch-all runs as if the row were not there,
--                  while Hide still suppresses the catch-all outright, reproducing the retired "Only
--                  these categories" toggle exactly. Concretely proven (fix round 3, and again in A2):
--                  a Show group whose one `excludeSpellIDs` the engine throws away carries no
--                  candidate filter at all, draws EVERY aura of the type regardless of any other
--                  category's Hide, and neuters them all — the owner's original complaint reborn.
--
-- THE SPELL LISTS ARE A STARTER SET, WRITTEN FOR THIS ADDON. They were assembled from public spell
-- data for Retail 12.x and are meant to be edited: the Filters page lets a player add or remove any
-- id per category, and those edits live in the profile (profile.categorySpells, shared by every
-- container since schema v2), never here.
-- An id that does not exist in the current client simply never matches, so a stale entry costs
-- nothing but a row in the editor. Consumables change every expansion and are the list most likely to
-- need a player's own additions.
--
-- PROVENANCE (issue #11 part C, spec section C6). `hardCC` and `softCC` below are the first lists
-- here that were DERIVED rather than hand-assembled: `tools/spell-research/research.py` reads the
-- client's own DB2 tables, closes the player-reachable spell pool over `EffectTriggerSpell` (the
-- addon filters on the AURA's id, not the cast's), buckets by spell mechanic, and diffs the result
-- against this file — it never writes it. Each list records the build and date it was derived
-- against on its own definition, so a stale list is visible HERE and not only in the frozen bundle
-- under docs/spell-research/. Re-run the tool to refresh one; the accept step stays the author's.
--
-- `class` on a spell is only for grouping the editor by class; the filter ignores it.

NS.Categories = NS.Categories or {}
local Cat = NS.Categories

local function spells(list)
    local out = {}
    for class, ids in pairs(list) do
        for _, id in ipairs(ids) do out[id] = class end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Buff categories
-- ---------------------------------------------------------------------------

Cat.HELPFUL = {
    {
        key = "defensives", kind = "spells", label = "Defensive cooldowns",
        desc = "Personal defensive cooldowns.",
        spells = spells({
            WARRIOR     = { 118038, 184364, 871, 23920, 12975 },
            PALADIN     = { 642, 498, 31850, 86659, 184662, 205191 },
            HUNTER      = { 186265, 264735 },
            ROGUE       = { 5277, 31224, 1966 },
            PRIEST      = { 47585, 19236 },
            DEATHKNIGHT = { 48792, 48707, 55233, 49039 },
            SHAMAN      = { 108271 },
            MAGE        = { 45438, 342246 },
            WARLOCK     = { 104773, 108416 },
            MONK        = { 120954, 122278, 122783, 125174 },
            DRUID       = { 22812, 61336 },
            DEMONHUNTER = { 212800, 196555, 187827 },
            EVOKER      = { 363916, 374348 },
        }),
    },
    {
        key = "bigDefensive", kind = "token", token = "BIG_DEFENSIVE", label = "Big defensives (Blizzard)",
        desc = "Auras Blizzard itself flags as big defensives.",
    },
    {
        key = "externals", kind = "token", token = "EXTERNAL_DEFENSIVE", label = "External defensives (Blizzard)",
        desc = "Defensives another player cast on the unit, as Blizzard flags them.",
    },
    {
        key = "activeMitigation", kind = "spells", label = "Active mitigation",
        desc = "Short, frequently refreshed tank mitigation.",
        spells = spells({
            WARRIOR     = { 132404, 190456 },
            PALADIN     = { 132403 },
            DEATHKNIGHT = { 77535, 195181 },
            DRUID       = { 192081 },
            DEMONHUNTER = { 203819 },
            MONK        = { 215479 },
        }),
    },
    {
        key = "raidCDs", kind = "spells", label = "Raid cooldowns",
        desc = "Group-wide cooldowns and haste effects.",
        spells = spells({
            WARRIOR     = { 97463 },
            PALADIN     = { 31821 },
            DEATHKNIGHT = { 145629 },
            DEMONHUNTER = { 209426 },
            PRIEST      = { 81782 },
            SHAMAN      = { 2825, 32182, 325174 },   -- 325174 is the AURA; 98007 is the cast (issue #15)
            MAGE        = { 80353 },
            HUNTER      = { 264667 },
            EVOKER      = { 390386, 374227 },
        }),
    },
    {
        key = "offensiveCDs", kind = "spells", label = "Offensive cooldowns",
        desc = "Damage cooldowns.",
        spells = spells({
            WARRIOR     = { 1719, 107574 },
            PALADIN     = { 31884, 231895 },
            DEATHKNIGHT = { 51271, 207289 },
            DRUID       = { 194223, 102560, 106951, 102543 },
            HUNTER      = { 288613, 19574, 360952 },
            MAGE        = { 190319, 12472, 365362 },
            ROGUE       = { 121471, 13750, 185422 },
            DEMONHUNTER = { 162264 },
            PRIEST      = { 194249, 10060 },
            MONK        = { 137639 },
            SHAMAN      = { 114051 },
            EVOKER      = { 375087 },
        }),
    },
    {
        -- One list since schema v2: the former coreHealing and lesserHealing, united (core/Database.lua's
        -- MigrateV2 merges a player's edits and category states of the two).
        key = "healing", kind = "spells", label = "Healing",
        desc = "Heal-over-time effects, shields and beacons.",
        spells = spells({
            DRUID   = { 774, 8936, 33763, 48438, 102352, 155777, 207386 },
            PRIEST  = { 139, 17, 194384, 41635 },
            SHAMAN  = { 61295, 974 },
            MONK    = { 119611, 124682, 115175 },
            EVOKER  = { 364343, 366155 },
            PALADIN = { 53563, 156910, 200025, 287280 },
        }),
    },
    {
        key = "support", kind = "spells", label = "Support",
        desc = "Raid buffs and buffs cast on other players.",
        spells = spells({
            MAGE    = { 1459 },
            PRIEST  = { 21562 },
            WARRIOR = { 6673 },
            DRUID   = { 1126, 29166 },
            EVOKER  = { 381748, 369459 },
            SHAMAN  = { 462854 },
        }),
    },
    {
        key = "movement", kind = "spells", label = "Movement",
        desc = "Speed and freedom effects.",
        spells = spells({
            ROGUE   = { 2983 },
            DRUID   = { 1850, 106898 },
            PALADIN = { 1044, 221886 },
            MONK    = { 116841 },
            HUNTER  = { 186257 },
            SHAMAN  = { 192082, 79206, 2645 },
            PRIEST  = { 121557, 65081 },
            WARLOCK = { 111400 },
            EVOKER  = { 358267 },
        }),
    },
    {
        key = "utility", kind = "spells", label = "Utility",
        desc = "Soulstones, stealth, water walking and similar.",
        spells = spells({
            WARLOCK = { 20707, 5697 },
            PRIEST  = { 111759 },   -- the AURA; 1706 is the cast (issue #15)
            SHAMAN  = { 546 },
            MAGE    = { 130, 32612 },
            HUNTER  = { 5384 },
            ROGUE   = { 1784 },
            DRUID   = { 5215 },
            ALL     = { 58984 },
        }),
    },
    {
        key = "consumables", kind = "spells", label = "Consumables",
        desc = "Flasks and similar. Changes every expansion — add your own ids.",
        spells = spells({
            ALL = { 431971, 431972, 431973, 431974, 432021 },
        }),
    },
    {
        key = "important", kind = "token", token = "IMPORTANT", label = "Important (Blizzard)",
        desc = "Auras Blizzard flags as important, the ones enemy nameplates show.",
    },
    {
        key = "castable", kind = "token", token = "RAID", label = "Castable by you",
        desc = "Buffs of a kind you can apply yourself.",
    },
    {
        key = "cancelable", kind = "token", token = "CANCELABLE", label = "Cancelable",
        desc = "Buffs the player is able to cancel.",
    },
    {
        key = "stealable", kind = "flag", field = "isStealable", value = true, label = "Stealable / purgeable",
        desc = "Buffs that can be stolen or purged — most useful on an enemy target.",
    },
    {
        key = "weaponEnchants", kind = "enchant", label = "Weapon enchants",
        desc = "Your temporary weapon enchants, drawn after the buffs. Only on a container showing your own buffs; which weapon slots count is set on General -> Spell Categories.",
    },
    {
        -- U-1: last in the grid, on purpose (renderCategories draws categoryRows() in Cat.For order).
        key = "uncategorized", kind = "uncategorized", label = "Uncategorized",
        desc = "Not in any of the Spell Categories lists above (Blizzard categories do not count). On a container watching you or your pet, Show rescues an unlisted buff from a Hidden Blizzard category; on a target or focus Blizzard may discard the spell list that rescue is built from, so Show simply changes nothing there. Hide removes the aura along with everything else this container has no other reason to draw, on every unit.",
    },
}

-- ---------------------------------------------------------------------------
-- Debuff categories
-- ---------------------------------------------------------------------------
--
-- Every category here but the first two is something the engine can evaluate for ANY unit. `hardCC`
-- and `softCC` are `spells`-kind (issue #11 part A) and so are not: Blizzard honors spell ids for
-- debuffs on HOSTILE units only, and discards them on the player, the pet and any friendly unit. The
-- two rows are still worth shipping — the question they answer ("is my sheep on the target", "is it
-- rooted") is asked of a hostile target or focus, which is exactly where the ids do bite — and every
-- surface that can mislead says so: their own descs below, the Filters page's Categories tab, the
-- General -> Spell Categories blurb, and the per-container orange warning
-- (`FC.WARN.IDS_HOSTILE_ONLY` / `IDS_OWN_DEBUFFS`, modules/FilterCompiler.lua).

local ALL_DISPELS = { Magic = true, Curse = true, Disease = true, Poison = true, Bleed = true }

-- DERIVED AGAINST BUILD 12.1.0.69875, 2026-09-20 (spec C6). Both lists below came out of
-- `python3 tools/spell-research/research.py`, which is what regenerates them; its frozen bundle for
-- this pair is docs/spell-research/2026-09-20/ (derived.json, DIFF.md, ANALYSIS.md and the gzipped
-- raw DB2 exports). Roll this line, and the two curation notes' numbers, whenever a later run is
-- accepted — the tool never writes this file, so a list can only go stale silently if nobody is
-- told which build it was true for.

Cat.HARMFUL = {
    {
        -- ABOVE `crowdControl` on purpose: these two editable rows read before the Blizzard token
        -- they refine, which is the order a player reasons in (spec A1).
        --
        -- CURATED, not the generator's raw output, and curated BY HAND. The 2026-09-20 run bucketed
        -- 215 ids here; what ships is 59. No mechanical filter over derived.json reproduces those 59
        -- and this note does not pretend one does. Three things govern, in order:
        --   1. ONE ID PER ABILITY A PLAYER LANDS ON A TARGET, and it is the id whose mechanic and DR
        --      the TARGET carries — not the cast id, not a legacy rank, not a sibling aura out of an
        --      older id block. The one stated exception is below: a spec-split ability.
        --   2. EVERY CLASS SHIPS ITS SIGNATURE CC, for every spec that has one. A class or spec
        --      opening this list and finding its own CC missing is the failure the list exists to
        --      avoid, so a hole here outranks any amount of tidiness.
        --   3. BEYOND THAT THE LONG TAIL IS THE CURATOR'S JUDGMENT. Said in as many words because
        --      it is true: which of the remaining ids earn a row is a call, not a derivation, and a
        --      later curator may call it differently. It is a defensible call because nothing is
        --      lost — the exhaustive derived set (215 hard, 212 soft for build 12.1.0.69875) is
        --      frozen in docs/spell-research/2026-09-20/, and General -> Spell Categories lets a
        --      player add any id out of it. These two rows are A STARTER SET meant to be edited,
        --      exactly what this file says of every other list it ships.
        --
        -- WHAT THE JUDGMENT LOOKED LIKE — illustrations, not a closed list of exclusions. Out under
        -- rule 1 go duplicate ranks and variants of an ability already represented: of the 77 ids the
        -- mechanic graph reached directly, 17 are named Polymorph and 9 Hex, one of each ships, so 16
        -- and 8 of them came out (across the whole 215 those two names are 38 and 20). Out too go
        -- encounter and trinket effects that reached the pool through a trait or spec row no player
        -- casts (Hammer of Retribution 405397, Victor's Presence 1276084, Ensorcelled by Flame
        -- 1276097, Jailer's Judgment 162056, Insanity 312678, Ancient Aftershock 325886), and stuns
        -- incidental to a damage ability rather than CC anyone tracks (Fists of Fury 120086, Infernal
        -- Awakening 22703). Rule 2 pulls ids back IN from the bridged entries — the canonical CC the
        -- mechanic graph cannot reach because the ability is cast as one spell and applies its aura
        -- as another (Freezing Trap, Storm Bolt, Shockwave, Ring of Frost, Blinding Light, Holy Word:
        -- Chastise, Capacitor Totem, Intimidation), the six the domain review named as holes a player
        -- of that class notices on sight (Asphyxiate 108194, Sigil of Misery, Song of Chi-Ji, Maim
        -- and Shield Charge; the sixth was Wake of Ashes, removed — see below), and the last three
        -- the per-class sweep found: Lightning
        -- Lasso 204437 (Shaman shipped only Hex and Capacitor Totem), Rake 163505 (the Feral stealth
        -- opener's stun) and Void Nova 1234195.
        --
        -- VOID NOVA SHIPS, and it is a player ability rather than an encounter or trinket effect:
        -- 1234195 has no SkillLineAbility row at all and reaches the pool as TraitDefinition 137090,
        -- whose entry 132289 maps through node 107347 onto TraitTree 854 — the demon hunter class
        -- tree, loaded by all three DH specs (577, 581, 1480). Five files under
        -- docs/spell-research/2026-09-20/raw/ carry that chain end to end: TraitDefinition.csv.gz,
        -- TraitNodeEntry.csv.gz, TraitNodeXTraitNodeEntry.csv.gz, TraitNode.csv.gz and
        -- TraitTreeLoadout.csv.gz. Note that derived.json files this id's class as "skillline"
        -- anyway — the generator stamps that source whenever a class was reached by ANY route, so
        -- the two do not actually disagree.
        --
        -- Every id added was read out of derived.json first for name, mechanic and DR. Class was
        -- verified too, but by hand wherever derived.json is unreliable on it (see `softCC`).
        --
        -- THE ONE EXCEPTION TO RULE 1: an ability the client SPEC-SPLITS, shipping a live id per
        -- specialization rather than an old rank and a new one. Asphyxiate is the only
        -- one in this run and both ids ship — 221562 is the Blood id (the run reaches it through
        -- TraitDefinition), 108194 the Frost/Unholy one (reached through the family bridge) — because
        -- a Frost death knight watching only for 221562 would never see the stun land. The rule
        -- drops ranks and variants of ONE ability; it does not merge two live abilities that share
        -- a name, and the first draft misapplied it here.
        --
        -- WAKE OF ASHES IS DELIBERATELY ABSENT FROM BOTH ROWS. The owner removed it on 2026-09-20.
        -- It shipped here as a stun (255941) until then, and this file carried the argument for
        -- filing it as one; that argument is gone with the id, because the decision was not that the
        -- research was wrong. No id of the ability belongs on either list — not 255941, not 255937
        -- (the cast), not 205290 (the older stun aura) and not 205273 (the ancestor's slow, which
        -- `softCC` has never shipped; Paladin's Soft CC row is Judgment of Justice). A later research
        -- run WILL derive the ability into the hard-CC bucket again: leaving it out is the intended
        -- diff, not an oversight to helpfully correct. A player who wants it adds the id on
        -- General -> Spell Categories.
        --
        -- MAIM ships on 203123, not 203126. Both are aura-applying spells named Maim in this build,
        -- and the one a Feral target carries is 203123 — mechanic 12 (stunned) on DiminishType 4,
        -- the stun DR, matching the finisher's own DR category. 203126 is mechanic 14
        -- (incapacitated) on DiminishType 16, a different DR entirely. The cast, 22570, applies no
        -- aura of its own and so is not a debuff id at all.
        --
        -- KNOWN GAPS, recorded rather than papered over, because a player who notices one missing
        -- should find the reason in this file. Five abilities are absent and stay absent:
        --   * Repentance (20066), hard CC. The research run's SENTINELS_UNREACHABLE records why —
        --     its id appears in none of the four pool sources for this build, so the client grants
        --     it by a route the pipeline cannot see.
        --   * Axe Toss (89766) and Seduction (6358), hard CC, the warlock's pet CC. Both sit on a
        --     PET skill line with ClassMask 0, and the pool keeps a ClassMask-0 row only on one of
        --     the thirteen class lines — the same test that keeps professions and mounts out.
        --   * Earthbind Totem (2484), soft CC. In the pool, but it carries no mechanic and its aura
        --     is named "Earthbind", so neither the mechanic match nor the bridge's exact-name test
        --     can cross to it.
        --   * Earthgrab Totem (64695), soft CC — found while closing this review, and recorded ONLY
        --     here: the bundle under docs/spell-research/ is frozen and its ANALYSIS.md does not
        --     name it. The id is in NEITHER derived bucket, which is why Shaman ships no root at
        --     all. Same shape as Earthbind: the talent 51485 is in the pool but carries mechanic 0,
        --     and the root aura 64695 ("Earthgrab", mechanic 7) is triggered only by 116943, the
        --     totem's own pulse, which the pool never reaches.
        -- A player who wants any of the five adds it by id on General -> Spell Categories.
        key = "hardCC", kind = "spells", label = "Hard CC (loss of control)",
        desc = "Stuns, incapacitates, disorients and fears, plus Cyclone, Banish and Mind Control — the unit is not in control of itself. Only works on a hostile target or focus: Blizzard discards spell lists for debuffs on you or on a friendly unit.",
        spells = spells({
            WARRIOR     = { 5246, 132168, 132169, 385954 },          -- Intimidating Shout, Shockwave, Storm Bolt, Shield Charge
            PALADIN     = { 853, 10326, 105421 },                    -- Hammer of Justice, Turn Evil, Blinding Light
            HUNTER      = { 1513, 3355, 24394, 117526, 213691 },     -- Scare Beast, Freezing Trap, Intimidation, Binding Shot, Scatter Shot
            ROGUE       = { 408, 1776, 1833, 2094, 6770 },           -- Kidney Shot, Gouge, Cheap Shot, Blind, Sap
            PRIEST      = { 605, 8122, 9484, 64044, 200200, 205364 }, -- Mind Control, Psychic Scream, Shackle Horror, Psychic Horror, Holy Word: Chastise, Dominate Mind
            DEATHKNIGHT = { 108194, 111673, 207167, 221562 },        -- Asphyxiate (Frost/Unholy), Control Undead, Blinding Sleet, Asphyxiate (Blood)
            SHAMAN      = { 51514, 118905, 204437 },                 -- Hex, Capacitor Totem, Lightning Lasso
            MAGE        = { 118, 31661, 82691, 383121 },             -- Polymorph, Dragon's Breath, Ring of Frost, Mass Polymorph
            WARLOCK     = { 710, 1098, 5484, 118699, 6789, 30283 },  -- Banish, Subjugate Demon, Howl of Terror, Fear (the AURA; 5782 is the cast), Mortal Coil, Shadowfury
            MONK        = { 115078, 119381, 198909 },                -- Paralysis, Leg Sweep, Song of Chi-Ji
            DRUID       = { 99, 2637, 5211, 33786, 163505, 203123 }, -- Incapacitating Roar, Hibernate, Mighty Bash, Cyclone, Rake, Maim
            DEMONHUNTER = { 179057, 207685, 211881, 217832, 1234195 }, -- Chaos Nova, Sigil of Misery, Fel Eruption, Imprison, Void Nova
            EVOKER      = { 360806, 372245 },                        -- Sleep Walk, Terror of the Skies
            ALL         = { 20549, 107079, 287712 },                 -- War Stomp, Quaking Palm, Haymaker (racials)
        }),
    },
    {
        -- CURATED BY HAND, by the same three rules `hardCC` above states: 212 derived, 54 shipped,
        -- and no mechanical filter over derived.json reproduces those 54 either. Rule 1 picks the id
        -- the target carries — VOID TENDRILS ships on 114404, the aura, not on 108920, the cast:
        -- 114404 is the APPLY_AURA row carrying SpellCategories mechanic 7 on the root DR, while
        -- 108920 has no effect row at all in this build's export and is in neither derived bucket.
        -- Rule 2 brings back from the bridge what a class would miss: Tar Trap, Entrapment, Grip of
        -- the Dead, the five the domain review named (Void Tendrils, Steel Trap, Clash, Cone of
        -- Cold, Judgment of Justice), and the four the last per-class sweep found — Landslide 355689
        -- (the Evoker's only root, and the row shipped none), Sigil of Chains 204843 (demon hunter),
        -- Strike of the Windlord 392983 (monk) and Stormbind 1251059 (shaman), the last two the same
        -- shape as the shipped Keg Smash 121253 and Ice Strike 470194.
        --
        -- WHAT RULE 1 MEANS FOR A ROUTINE SLOW, because the first draft had this backwards: it
        -- dropped five ids as "passive procs and damage riders nobody tracks as crowd control" while
        -- shipping six of exactly that kind. A snare is a snare ON THE TARGET. If the client records
        -- a soft-CC mechanic on a debuff a player applies, the id ships, however routine the ability
        -- carrying it — the question this row answers is "can it get away from me", and a Keg Smash
        -- slow answers it as well as a Frost Nova does. So the five that were cut are back in
        -- (Moonfire 164812's talent-only snare, Chrono Shift 236299, Blast Wave 157981, Fatal
        -- Flourish 35546, Truth's Wake 403695), beside the six kept anyway (Mind Flay 15407, Heart
        -- Strike 206930, Keg Smash 121253, Ice Strike 470194, Infected Wounds 58180, Permeating
        -- Chill 370898).
        --
        -- WHAT CAME OUT, again as illustrations and not a closed list: another id for an ability
        -- already listed (Infected Wounds 345209, The Hunt 370970, Bursting Shot 224729), retired
        -- covenant and legacy rows (Fae Tendrils 342373), and most of the rest of the 212, which the
        -- run's own ANALYSIS.md reads as self-buffs' incidental slows rather than anything landed on
        -- a target. Most, not all: past rules 1 and 2 this is rule 3, judgment, and what makes that
        -- safe to say out loud is that the frozen bundle and the Spell Categories editor put every
        -- id one paste away.
        --
        -- The 40 ids the run emitted under `ALL` because it could not resolve a class were hand-keyed
        -- to the class that actually casts them where one exists — the run's own ANALYSIS.md calls
        -- grouping them under `ALL` a cosmetic lie, and `ALL` here means a racial, nothing else. The
        -- complete set of hand-keyings across BOTH rows, so the note matches what was done: Slow,
        -- Frostbite, Mass Slow, Chrono Shift and Blast Wave to MAGE, Apathy to PRIEST, Ice Strike to
        -- SHAMAN, Bursting Shot and Entrapment to HUNTER, and on `hardCC` above Scatter Shot to
        -- HUNTER, Fel Eruption to DEMONHUNTER and Psychic Horror (64044) to PRIEST. Wing Buffet
        -- (357214) is keyed to EVOKER too, though the run had it as `ALL` off a skill line rather
        -- than as unresolved. CLASS IS THE ONE FIELD derived.json IS NOT TRUSTED ON: its
        -- `classSource == "skillline"` rows are noisy — it files Frostbolt Volley 141425 under
        -- WARRIOR and Fae Tendrils 342373 under MAGE, neither of which ships — so name, mechanic and
        -- DR come from derived.json and every shipped id's class was verified by hand.
        --
        -- ABILITIES WITH BOTH A HARD AND A SOFT MECHANIC are not rare — 13 names appear in both
        -- derived buckets, seven of them with an id shipped across the two rows (Blast Wave, Blinding
        -- Sleet, Bursting Shot, Clash, Mind Flay, Ring of Frost, The Hunt). Each ships
        -- ONCE, on the id whose mechanic is the one the target actually carries, because a spell
        -- belongs to exactly one bucket and the two lists must never double-count an aura. The Hunt
        -- ships here on its root id (323996 rooted; 333762 is the stun): a demon hunter watching The
        -- Hunt on a target is watching the root that pins them. Wake of Ashes was the eighth such
        -- name and went to `hardCC`; the owner removed it from both rows on 2026-09-20, and `hardCC`
        -- says so.
        key = "softCC", kind = "spells", label = "Soft CC (roots & snares)",
        desc = "Roots and snares — the unit keeps control of itself but cannot move freely. Only works on a hostile target or focus: Blizzard discards spell lists for debuffs on you or on a friendly unit.",
        spells = spells({
            WARRIOR     = { 1715, 12323 },                           -- Hamstring, Piercing Howl
            PALADIN     = { 403695, 408383 },                        -- Truth's Wake, Judgment of Justice
            HUNTER      = { 5116, 64803, 135299, 162480, 186387, 190925, 195645 }, -- Concussive Shot, Entrapment, Tar Trap, Steel Trap, Bursting Shot, Harpoon, Wing Clip
            -- 35546 IS THE CAST AND ITS AURA IS UNKNOWN (issue #15). It applies no aura of its
            -- own and has no EffectTriggerSpell edge, so the data cannot name one; the owner's
            -- live probe could not observe one either, reporting it as a proc that fires and
            -- vanishes rather than an aura that sits on a unit. It is left as the cast id
            -- KNOWINGLY: a row that matches nothing is no worse than a row that is gone, and
            -- removing it would lose the record that this slow exists. Settle it by watching a
            -- real target while an Outlaw rogue has the talent, then swap in what lands.
            ROGUE       = { 3409, 35546, 185763 },                   -- Crippling Poison, Fatal Flourish (cast; aura unknown), Pistol Shot
            PRIEST      = { 15407, 114404, 390669 },                 -- Mind Flay, Void Tendrils, Apathy
            DEATHKNIGHT = { 45524, 206930, 273977 },                 -- Chains of Ice, Heart Strike, Grip of the Dead
            SHAMAN      = { 51490, 196840, 470194, 1251059 },        -- Thunderstorm, Frost Shock, Ice Strike, Stormbind
            MAGE        = { 122, 31589, 157981, 157997, 212792, 236299, 378760, 391104 }, -- Frost Nova, Slow, Blast Wave, Ice Nova, Cone of Cold, Chrono Shift, Frostbite, Mass Slow
            WARLOCK     = { 334275, 384069 },                        -- Curse of Exhaustion, Shadowflame
            MONK        = { 116095, 121253, 123586, 324382, 392983 }, -- Disable, Keg Smash, Flying Serpent Kick, Clash, Strike of the Windlord
            DRUID       = { 339, 58180, 61391, 102359, 127797, 164812 }, -- Entangling Roots, Infected Wounds, Typhoon, Mass Entanglement, Ursol's Vortex (the AURA; 102793 is the cast), Moonfire
            DEMONHUNTER = { 198813, 204843, 213405, 323996 },        -- Vengeful Retreat, Sigil of Chains, Master of the Glaive, The Hunt
            EVOKER      = { 355689, 357214, 368970, 370898 },        -- Landslide, Wing Buffet, Tail Swipe, Permeating Chill
            ALL         = { 260369 },                                -- Arcane Pulse (racial)
        }),
    },
    {
        key = "crowdControl", kind = "token", token = "CROWD_CONTROL", label = "Crowd control",
        desc = "Stuns, fears, roots and similar, as Blizzard flags them.",
    },
    {
        key = "boss", kind = "flag", field = "isBossAura", value = true, label = "Boss debuffs",
        desc = "Debuffs applied by a boss.",
    },
    {
        key = "role", kind = "flag", field = "isRoleAura", value = true, label = "Role debuffs",
        desc = "Debuffs Blizzard flags as relevant to your role.",
    },
    {
        -- `priority`, not `important`: every category key is unique across BOTH lists, because a
        -- container's category states are one map and a container can change its aura type.
        key = "priority", kind = "flag", field = "isPriorityAura", value = true, label = "Priority",
        desc = "Debuffs Blizzard flags as priority.",
    },
    {
        key = "raid", kind = "token", token = "RAID", label = "Raid (you can dispel)",
        desc = "Debuffs you are able to dispel.",
    },
    {
        key = "raidInCombat", kind = "token", token = "RAID_IN_COMBAT", label = "Raid in combat",
        desc = "Debuffs Blizzard shows on raid frames during combat.",
    },
    {
        key = "groupDispellable", kind = "token", token = "RAID_PLAYER_DISPELLABLE", label = "Dispellable by your group",
        desc = "Debuffs someone in your group can dispel.",
    },
    {
        key = "dispellable", kind = "token", token = "DISPELLABLE", label = "Dispellable by anyone",
        desc = "Debuffs any class can dispel.",
    },
    {
        key = "dispels", kind = "dispel", types = ALL_DISPELS, label = "Has a dispel type",
        desc = "Magic, curse, disease, poison or bleed.",
    },
    { key = "magic",   kind = "dispel", types = { Magic = true },   label = "Magic",   desc = "Magic debuffs." },
    { key = "curse",   kind = "dispel", types = { Curse = true },   label = "Curse",   desc = "Curses." },
    { key = "disease", kind = "dispel", types = { Disease = true }, label = "Disease", desc = "Diseases." },
    { key = "poison",  kind = "dispel", types = { Poison = true },  label = "Poison",  desc = "Poisons." },
    { key = "bleed",   kind = "dispel", types = { Bleed = true },   label = "Bleed",   desc = "Bleeds." },
    {
        key = "fromNonPlayers", kind = "flag", field = "isFromPlayerOrPlayerPet", value = false,
        label = "From non-players", desc = "Debuffs applied by creatures rather than players.",
    },
    {
        key = "fromPlayers", kind = "flag", field = "isFromPlayerOrPlayerPet", value = true,
        label = "From any player", desc = "Debuffs applied by any player or their pet.",
    },
    {
        -- Fix round 3 (2026-09-16): restored, asymmetric with the buff row — see the KINDS doc above.
        -- Hide reproduces the retired "Only these categories" toggle exactly (drops the catch-all, so
        -- only what is explicitly Shown is drawn). Show is a plain default that must NOT contribute a
        -- group of its own, and since issue #11's A2 that is a fact about the UNIT, not about this
        -- file: `hardCC` and `softCC` above give the debuff union real content, so the old reason
        -- ("there is nothing to be outside of") is dead. The live reason is that the group a Show
        -- would contribute carries one constraint, an `excludeSpellIDs` of that union, and the engine
        -- discards spell ids on every debuff container there is — on the player and pet outright, on
        -- a target or focus the moment the unit is friendly. What the engine would receive is an
        -- unrestricted HARMFUL group: every debuff drawn, every other Hide on the tab defeated.
        -- `modules/FilterCompiler.lua` gates it on `FC.IdsAlwaysHonored(unit, auraType)` — false for
        -- all four debuff units and for a `target`/`focus` buff container too — so this stays a
        -- general rule keyed on whether ids are CERTAIN to be honored, not a debuff-only special case.
        key = "uncategorizedDebuffs", kind = "uncategorized", label = "Uncategorized",
        desc = "Hide draws only what you have explicitly set to Show on this tab (the retired 'Only these categories' toggle, exactly). Show is the default and changes nothing by itself: Hard CC and Soft CC are the only debuff spell lists, and Blizzard never lets a debuff container use a spell list to rescue an aura, so there is no rescue for this row to perform.",
    },
}

-- ---------------------------------------------------------------------------
-- Aura type, stamped onto every definition (issue #10 checkpoint 2)
-- ---------------------------------------------------------------------------
--
-- From here on every definition above carries its own aura type in `def.auraType`, written once at
-- load out of the list it was declared in. Until now the type was purely IMPLICIT: a def was a buff
-- category because it sat in `Cat.HELPFUL` and a debuff one because it sat in `Cat.HARMFUL`, so
-- nothing holding a single def could ask which it was without also remembering which table handed
-- it over. The Category dropdown's buff/debuff markers (settings/GeneralSpells.lua, the same
-- issue's checkpoint 1) need exactly that question answered per def, and so does every later
-- checkpoint of issue #10.
--
-- STAMPED AT LOAD, NOT DERIVED BY LOOKUP, and the reason is the user categories checkpoint 3 brings
-- rather than tidiness. An accessor that derived the answer could only do it by searching
-- `Cat.HELPFUL` and `Cat.HARMFUL` for the key -- which answers NOTHING for a def that was never in
-- either list, and a user category is precisely that: a definition built out of the player's stored
-- data, whose aura type is their choice at creation. Deriving would leave two ways to ask the same
-- question, one for shipped categories and another for user ones, which is the split the single
-- accessor below exists to prevent. With a field, a user category simply arrives already stamped
-- and `Cat.AuraTypeOf` never learns the difference. The price is one write per def at load.
--
-- AURA TYPE IS IMMUTABLE AFTER CREATION (the plan of record's decision, 2026-09-20,
-- docs/superpowers/specs/2026-09-20-custom-spell-categories-plan.md). Nothing rewrites
-- `def.auraType` afterwards -- not this file, not the settings panel, not a migration.
-- modules/FilterCompiler.lua groups by aura type and a container's stored Show/Hide is keyed by
-- category key, so a category that changed type would orphan every container's stored state for it
-- and silently move between two different grids. Changing a user category's type means deleting it
-- and creating another.
for _, auraType in ipairs({ "HELPFUL", "HARMFUL" }) do
    for _, def in ipairs(Cat[auraType]) do def.auraType = auraType end
end

-- The list an aura type this build does not know gets: none (a stored ENCHANT container predates schema
-- v5, which turns it into a buff container before anything reads its categories).
local NONE = {}

--- The ordered category list for an aura type, never nil.
--- @param auraType string  "HELPFUL" | "HARMFUL"
--- @return table
function Cat.For(auraType)
    if auraType == "HELPFUL" or auraType == "HARMFUL" then return Cat[auraType] end
    return NONE
end

--- One category definition by aura type and key, or nil.
--- @return table|nil
function Cat.Find(auraType, key)
    for _, def in ipairs(Cat.For(auraType)) do
        if def.key == key then return def end
    end
    return nil
end

--- Whether `key` names a spell-list category (the only kind whose spells a player can edit).
--- @return boolean
function Cat.IsSpellCategory(key)
    local def = Cat.Find("HELPFUL", key) or Cat.Find("HARMFUL", key)
    return def ~= nil and def.kind == "spells"
end

--- The aura type a category filters: "HELPFUL" or "HARMFUL". Reads the field stamped above. It
--- takes EITHER a definition or a key, so a caller holding one asks the same way as a caller
--- holding the other: settings/GeneralSpells.lua's dropdown holds defs, while everything walking a
--- container's stored `filter.categories` holds a bare key.
---
--- BOTH FORMS ARE TOTAL OVER LIVE DEFINITIONS, shipped and user alike. Given a def it reads
--- `def.auraType`, so any definition the addon built answers -- shipped ones from the load-time
--- stamp, and a user category from the same field out of its stored shape. Given a KEY it finds the
--- def through `Cat.Find`, which walks `Cat.HELPFUL` and `Cat.HARMFUL`; since checkpoint 3
--- materializes every usable user record INTO those two lists (`Cat.SyncUserCategories`), a user
--- category's key reaches its def there like any other and answers with the aura type it was created
--- under. So a caller holding a bare key out of a stored `filter.categories` types a user category
--- correctly, which is what the callers walking stored state need.
---
--- THE WIDENING CAME FOR FREE, and that is the point worth recording: nothing in this accessor
--- changed. It followed from materializing user defs into the shipped lists rather than keeping them
--- in a store of their own, which is the same decision that lets `Cat.For`, `Cat.Find`,
--- `Cat.IsSpellCategory`, `Cat.DefaultStates` and settings/Filters.lua's grids stay single-path.
---
--- A key nothing knows answers nil rather than failing, the same as `Cat.Find`. A stored container
--- can perfectly well name a category this build does not have -- an older profile's retired key, a
--- user category belonging to a DIFFERENT profile than the live one, and after checkpoint 5 a
--- deleted user category -- so the caller decides what that means.
---
--- Aura type is IMMUTABLE after creation; the note above the stamping loop says why.
--- @param defOrKey table|string  a category definition, or a category key
--- @return string|nil
function Cat.AuraTypeOf(defOrKey)
    local def = defOrKey
    if type(def) == "string" then def = Cat.Find("HELPFUL", def) or Cat.Find("HARMFUL", def) end
    if type(def) ~= "table" then return nil end
    return def.auraType
end

--- Every category key across both lists, each mapped to "show" — the default state (schema v3:
--- Show is the absence of a decision, so it excludes nothing). The container template's
--- `filter.categories` is built from this, so a key added in a later version reaches every stored
--- container through the ordinary backfill and resolves for the schema validator.
--- @return table
function Cat.DefaultStates()
    local out = {}
    for _, list in ipairs({ Cat.HELPFUL, Cat.HARMFUL }) do
        for _, def in ipairs(list) do out[def.key] = "show" end
    end
    return out
end

--- The default states with every BUFF category Hidden except `keys`, which stay Show: a container
--- that draws only the buffs those categories claim (the "Player cooldowns" starter,
--- defaults/Profile.lua). That hides every Blizzard token and flag category, Weapon enchants and
--- Uncategorized too, so an unlisted buff has no Show left to draw it. The debuff categories keep
--- Show: inert on a buff container, and a later switch to debuffs does not start all-hidden.
--- @param keys table  category keys of Cat.HELPFUL
--- @return table
function Cat.StatesShowing(keys)
    local out = Cat.DefaultStates()
    for _, def in ipairs(Cat.HELPFUL) do out[def.key] = "hide" end
    for _, key in ipairs(keys) do out[key] = "show" end
    return out
end

--- The states of an ENCHANT-ONLY buff container (schema v5, feedback #6): every buff category Hidden
--- but Weapon enchants, Uncategorized included, so the container draws the player's temporary weapon
--- enchants and no aura at all. The v5 migration (core/Database.lua) and `/am new enchants`
--- (settings/Slash.lua) both build one from this.
--- @return table
function Cat.EnchantOnlyStates()
    return Cat.StatesShowing({ "weaponEnchants" })
end

-- ---------------------------------------------------------------------------
-- User categories (issue #10, checkpoint 3)
-- ---------------------------------------------------------------------------
--
-- A category the player made is STORED as a small record and MATERIALIZED as an ordinary definition
-- in the two lists above. That one decision is what makes this checkpoint small: `Cat.For`,
-- `Cat.Find`, `Cat.IsSpellCategory`, `Cat.DefaultStates`, `Cat.StatesShowing`, `Cat.AuraTypeOf`'s
-- KEY form (the note above it, carried forward from checkpoint 2, is satisfied by this and nothing
-- else), settings/Filters.lua's `gridOf` and its `See spells` link, settings/GeneralSpells.lua's
-- category dropdown, and modules/FilterCompiler.lua's `categorizedUnion`, `splitCategories`,
-- `includeCategory`/`excludeCategory` and `FC.ClaimingCategories` all go on working with no edit at
-- all, because none of them can tell a user definition from a shipped one. `def.userCategory` is
-- the ONE marker that can, and only three things read it: the teardown below, the schema row's own
-- `userCategory` flag (so the rows can be found again), and tests/test_locale.lua's exemption.
--
-- THE STORED SHAPE, in the profile (defaults/Profile.lua, schema v6):
--
--   userCategories    = { [key] = { key = key, name = "<player text>", auraType = "HELPFUL"|"HARMFUL" } }
--   userCategoryOrder = { key, key, ... }
--
-- and NOT the spell list, which reuses `profile.categorySpells[key]` like every other category's
-- edits. `FC.CategorySpells(def, spellEdits)` is defined as the definition's own starters UNIONED
-- with the profile's per-key edits, so a user definition carrying `spells = {}` has, as its entire
-- list, exactly the `true` entries of `categorySpells[key]`. No new merge rule, no second store and
-- no second editor -- settings/GeneralSpells.lua's `entriesFor`, `editCategory` and `editsOf`, and
-- settings/Schema.lua's `categorySpells` carve-out, are already the right code.
--
-- The price of that reuse is named rather than hidden: the carve-out's normalizer DROPS every key it
-- does not recognize and writes the set WHOLE, so a user key whose definition had failed to
-- materialize would have its entire spell list deleted by the next unrelated edit of any other
-- category. `Cat.HasUserRecord` below is what settings/Schema.lua asks instead, so the stored RECORD
-- alone protects the list even when the definition is missing.

local L = NS.L

-- The reserved key namespace. Every user category's key begins with it and no shipped key ever may;
-- tests/test_defaults.lua asserts that, so a category added to the lists above in some later version
-- cannot quietly take a namespace a player's saved data already lives in.
local USER_PREFIX = "user"
local USER_PREFIX_LENGTH = #USER_PREFIX
local USER_KEY_CHARS = "0123456789abcdefghijklmnopqrstuvwxyz"
local USER_KEY_LENGTH = 10

-- The description every user category carries. FIXED, and routed through the locale like any other
-- shipped string -- which is precisely why the locale exemption (tests/test_locale.lua) can be one
-- FIELD of one flagged definition kind rather than the whole definition: only `label` is the
-- player's own text. If this ever needs to name the category it must be a format string taking the
-- name as a `%s` ARGUMENT, never a concatenation: a name is data, and a `%` inside it read as a
-- directive is the same class of bug as the `|` the sanitizer below strips.
local USER_DESC = "Your own category. Edit its spells on General -> Spell Categories."

-- Long enough for "Mythic+ affixes I care about", short enough that a grid row stays a row.
local NAME_MAX = 40

--- The cap `Cat.SanitizeUserName` applies, published so the panel's name boxes can stop the player
--- at the same number the store would silently trim them to (settings/GeneralSpells.lua). One
--- constant, two readers: a box that let 60 characters be typed and then stored 40 would be a
--- control that lies about what it did.
---
--- IT IS A COUNT OF CHARACTERS AT BOTH READERS. `EditBox:SetMaxLetters` counts what the player
--- typed, not what it encodes to, so a byte cap at the store would disagree with the boxes on every
--- name with a non-ASCII character in it -- and disagree by cutting one in half, which is how a
--- name ends in a lone continuation byte the font draws as a replacement glyph.
Cat.USER_NAME_MAX = NAME_MAX

--- `s`'s length in CHARACTERS rather than bytes: a UTF-8 continuation byte (binary 10xxxxxx) is the
--- rest of the character before it and is not counted, so this is what a player would count.
--- Published because the cap below and the Category dropdown's marker padding
--- (settings/GeneralSpells.lua) both have to count the same thing.
--- @param s string
--- @return number
function Cat.CharCount(s)
    return select(2, tostring(s):gsub("[^\128-\191]", ""))
end

--- `s` cut to at most `max` CHARACTERS, never mid-sequence: the cut is taken at the byte before the
--- lead byte of the character that would be the (max + 1)th.
local function truncateChars(s, max)
    local bytes = #s
    local count, cut = 0, bytes
    for i = 1, bytes do
        local b = s:byte(i)
        if b < 128 or b > 191 then
            count = count + 1
            if count > max then
                cut = i - 1
                break
            end
        end
    end
    return s:sub(1, cut)
end

--- A player-supplied category name as it is STORED: the escape character `|` and every control
--- character removed, trimmed, and capped at NAME_MAX CHARACTERS -- `Cat.CharCount`'s count, which
--- is the one the panel's boxes enforce. nil when nothing is left.
---
--- SANITIZED ONCE, AT THE WRITE, NEVER AT THE DRAW. `def.label` reaches `NS.L[def.label]` and from
--- there a FontString, and a FontString reads `|c`, `|T` and `|H` as color, texture and hyperlink
--- escapes -- so a bare `|` in a name could recolor the grid row it sits in, paint a texture over it
--- or turn it into a link, in the tooltip as well as the row. Escaping at render instead would mean
--- every reader had to remember to, and the one that forgot would be the hole; one canonical stored
--- value leaves nothing to remember. `%` is deliberately KEPT -- it is an ordinary character in a
--- name, and the rule that protects it is the one above USER_DESC: a name is only ever a format
--- ARGUMENT.
--- @param name string
--- @return string|nil
function Cat.SanitizeUserName(name)
    if type(name) ~= "string" then return nil end
    local clean = name:gsub("|", ""):gsub("%c", "")
    clean = clean:match("^%s*(.-)%s*$")
    if Cat.CharCount(clean) > NAME_MAX then
        clean = truncateChars(clean, NAME_MAX):match("^%s*(.-)%s*$")
    end
    if clean == "" then return nil end
    return clean
end

--- Whether `key` sits in the reserved user-category namespace: the `user` prefix every generated key
--- carries and no shipped key ever may (tests/test_defaults.lua asserts the second half).
---
--- STRUCTURAL, not a guess at how the key was made, and the sync below REFUSES a stored record whose
--- key falls outside it exactly as it refuses one with an unknown aura type. A record keyed `healing`
--- -- hand-edited, or left by a corrupt write -- would otherwise be materialized into `Cat.HELPFUL`
--- beside the shipped `healing`, two definitions under one key. The next sync's teardown then finds
--- the user def BY KEY and takes `healing` out of the container template with it, so the SHIPPED
--- category's row has no default for the rest of the session: `NS.DefaultFor` answers nil and
--- `NS.ValidateSchema` fails on a row the player never touched.
--- @param key string|nil
--- @return boolean
function Cat.IsUserKey(key)
    return type(key) == "string" and key:sub(1, USER_PREFIX_LENGTH) == USER_PREFIX
end

-- The key generator: a Lehmer (MINSTD) sequence of this file's own, seeded ONCE on first use.
--
-- `math.random` alone was not enough, and the reason is worth stating plainly: nothing in this addon
-- ever called `math.randomseed`, so in Lua 5.1 every client walks the SAME sequence from its first
-- draw. Two players who each made their first category would have been handed the same key, which is
-- precisely the collision the random scheme was chosen to avoid.
--
-- SEEDED ONCE, LAZILY, RATHER THAN MIXED PER CALL. The entropy the client offers is a wall clock in
-- SECONDS, so mixing it into every draw would make two keys created in the same minute share most of
-- their bits; drawing from a sequence seeded once gives ten independent characters per key however
-- fast they are made. Lazily rather than at load because the one ingredient that actually
-- distinguishes two clients -- the player GUID -- is not there until the player is in the world,
-- while `Cat.NewUserKey` runs only when somebody creates a category, long after.
--
-- ITS OWN STATE, NOT `math.randomseed`. The client runs every addon in ONE Lua state, so reseeding
-- the shared generator would reach into whatever any other addon is drawing from.
local RNG_MODULUS = 2147483647
local rngState

--- Fold every byte of `s` into `seed`. Not a hash with any property worth naming: it only has to
--- carry the whole string into the seed rather than the first few characters of it.
local function mixString(seed, s)
    local length = #s
    for i = 1, length do
        seed = (seed * 31 + s:byte(i)) % RNG_MODULUS
    end
    return seed
end

--- The seed, from what the client can say about THIS session that another client would not say.
--- The GUID is the load-bearing one -- Blizzard-unique per character, so two players do not share a
--- sequence even if they create a category in the same second; the clock and the profiler separate
--- two characters of one account, and cover a client that answers no GUID at all. Every source is
--- optional, because the headless harness has only some of them and a future client may move one.
local function seedValue()
    local seed = 7757  -- an arbitrary non-zero start: MINSTD is degenerate at zero
    if type(UnitGUID) == "function" then
        local guid = UnitGUID("player")
        if type(guid) == "string" then seed = mixString(seed, guid) end
    end
    if type(time) == "function" then seed = (seed + (tonumber(time()) or 0)) % RNG_MODULUS end
    if type(debugprofilestop) == "function" then
        seed = (seed + math.floor(tonumber(debugprofilestop()) or 0)) % RNG_MODULUS
    end
    if seed == 0 then seed = 1 end
    return seed
end

--- `math.random(low, high)`'s shape, off the sequence above. The HIGH bits decide the answer: a
--- Lehmer generator's low bits are the weak ones, and `% n` would read exactly those.
local function defaultRand(low, high)
    rngState = ((rngState or seedValue()) * 16807) % RNG_MODULUS
    return low + math.floor(rngState / RNG_MODULUS * (high - low + 1))
end

--- A fresh user-category key: `user` followed by ten lowercase base-36 characters.
---
--- RANDOM, NOT DERIVED FROM THE NAME AND NOT A COUNTER, and both halves earn their place.
--- Not derived: a rename is then a pure `rec.name` write and nothing in the rename path touches the
--- key, which makes "renaming orphans every container's stored Show/Hide" -- the trap issue #10
--- names -- structurally impossible rather than merely avoided.
--- Not a counter: keys LEAVE their profile. modules/ContainerManager.lua's CopyFrom copies a
--- container's `filter.categories`, AceDB's OnProfileCopied copies a whole profile, and import and
--- export (#9) will carry them between accounts. A per-profile counter guarantees that two profiles
--- that each created a first category both own `user1`, with different names, different aura types
--- and different spell lists -- a collision no code can detect and that a copy resolves silently and
--- wrongly. With a random key, two categories created independently under the SAME NAME are two
--- categories, which is the right answer: the name is a label, the key is identity.
---
--- WHAT THE RANDOMNESS ACTUALLY BUYS, AND WHAT IT DOES NOT. Within the account it is a GUARANTEE and
--- it is not the generator's doing: `taken` is every key in use ACCOUNT-WIDE (`Cat.UserKeysInUse`),
--- so the loop below simply refuses to hand back a key this account already holds, and a copy between
--- profiles cannot land two categories on one key however the draws fall. ACROSS accounts there is
--- NO guarantee, only a very small probability -- the generator is seeded per client (see
--- `seedValue` above), the draw is ten base-36 characters, and nothing can check a key an account
--- has never seen. So the import half of #9 must REKEY a record whose key the importing account
--- already holds rather than trust that keys cannot collide; this generator makes that case rare,
--- not impossible, and the earlier version of this comment claimed more than the code delivers.
---
--- `rand` is a test seam: the generator above unless a case hands in one that collides on purpose.
--- @param taken table|nil  [key] = true
--- @param rand function|nil
--- @return string
function Cat.NewUserKey(taken, rand)
    taken = type(taken) == "table" and taken or {}
    rand = rand or defaultRand
    local attempt = 0
    while true do
        attempt = attempt + 1
        local key = USER_PREFIX
        for _ = 1, USER_KEY_LENGTH do
            local i = rand(1, #USER_KEY_CHARS)
            key = key .. USER_KEY_CHARS:sub(i, i)
        end
        -- Ten base-36 characters is about 52 bits, so a second attempt is already unreachable in
        -- practice and the fifth is a formality. Past it the attempt counter is appended, which
        -- makes TERMINATION a property of this loop rather than a property of the generator: a
        -- degenerate `rand` that answers the same number forever still runs out of collisions.
        if attempt > 5 then key = key .. attempt end
        if not taken[key] then return key end
    end
end

--- Every user-category key stored anywhere in the account: each profile of AceDB's raw store, the
--- active profile, and the no-AceDB fallback's single one. ACCOUNT-WIDE on purpose (see
--- `Cat.NewUserKey`); it costs one walk per creation, which is as rare an act as this addon has.
--- @param db table|nil  defaults to NS.db
--- @return table  [key] = true
function Cat.UserKeysInUse(db)
    local out = {}
    local function harvest(p)
        if type(p) ~= "table" or type(p.userCategories) ~= "table" then return end
        for key in pairs(p.userCategories) do
            if type(key) == "string" then out[key] = true end
        end
    end
    db = db or NS.db
    if type(db) == "table" then
        harvest(db.profile)
        local store = type(db.sv) == "table" and db.sv.profiles
        if type(store) == "table" then
            for _, p in pairs(store) do harvest(p) end
        end
    end
    return out
end

--- Whether `defOrKey` names a category the player made. The definition form reads the marker the
--- sync stamps; the key form resolves through `Cat.Find`, so it answers only while the category is
--- materialized -- which is every moment after NS.RunMigrations except inside the sync itself.
--- @return boolean
function Cat.IsUserCategory(defOrKey)
    local def = defOrKey
    if type(def) == "string" then def = Cat.Find("HELPFUL", def) or Cat.Find("HARMFUL", def) end
    return type(def) == "table" and def.userCategory == true
end

--- A category definition's label AS IT IS SHOWN: a shipped label is a locale key and goes through
--- `NS.L`, a user label is the player's own text and never does. EVERY site that draws a category
--- name asks this rather than indexing `NS.L` itself -- the settings grids, the Spell Categories
--- dropdown and modules/FilterCompiler.lua's `ExplainSpell` notes.
---
--- Not a tidiness rule. `NS.L` answers its own miss path, handing back any key it has no line for,
--- so `L[def.label]` LOOKS correct for a user category right up until a player names one "Healing"
--- or "Movement" -- at which point the lookup finds a real shipped line and the panel shows the
--- shipped string in place of the name that was typed. Invisible on enUS, where the line and the key
--- read the same; plainly wrong on any translated client. The locale exemption tests/test_locale.lua
--- makes is that a user name is DATA; this is the half of it that lives at the draw.
--- @param def table  a category definition
--- @return string
function Cat.LabelOf(def)
    if type(def) ~= "table" or type(def.label) ~= "string" then return "" end
    if def.userCategory then return def.label end
    return L[def.label]
end

--- Whether `profile` STORES a user category under `key`, materialized or not. The distinction is
--- load-bearing in exactly one place, and it is a data-loss one: settings/Schema.lua's
--- `categorySpells` normalizer drops every key that is not an editable category and writes the set
--- WHOLE, so a key whose definition failed to materialize would have its entire spell list deleted
--- by the next unrelated edit of any other category. The stored record alone protects the list.
--- @return boolean
function Cat.HasUserRecord(key, profile)
    profile = profile or (NS.db and NS.db.profile)
    if type(profile) ~= "table" or type(key) ~= "string" then return false end
    local recs = profile.userCategories
    return type(recs) == "table" and recs[key] ~= nil
end

--- `profile.userCategoryOrder` reconciled against `profile.userCategories`, exactly the way
--- core/Database.lua's `rebuildOrder` reconciles `containerOrder`: dangling keys dropped, duplicates
--- dropped, records with no order entry appended in key order. WRITTEN BACK, so the reconciliation
--- happens at the sync rather than at every read.
---
--- Declaration order is the ONLY ordering source. `pairs` over `userCategories` is nondeterministic,
--- so an order derived from it would vary between logins -- and since modules/FilterCompiler.lua
--- emits one engine group per shown category in declaration order, and `FC.StructureKey` rebuilds a
--- live container whenever the group count or shape moves, that variance would be visible in game
--- and not merely in a table dump.
--- @return table  the reconciled order
function Cat.UserCategoryOrder(profile)
    if type(profile) ~= "table" then return {} end
    local recs = type(profile.userCategories) == "table" and profile.userCategories or {}
    local stored = type(profile.userCategoryOrder) == "table" and profile.userCategoryOrder or {}
    local seen, order = {}, {}
    for _, key in ipairs(stored) do
        if type(key) == "string" and recs[key] ~= nil and not seen[key] then
            seen[key] = true
            order[#order + 1] = key
        end
    end
    local orphans = {}
    for key in pairs(recs) do
        if type(key) == "string" and not seen[key] then
            orphans[#orphans + 1] = key
        end
    end
    table.sort(orphans)
    for _, key in ipairs(orphans) do
        order[#order + 1] = key
    end
    profile.userCategoryOrder = order
    return order
end

--- One stored record's usable name, or nil plus why it has none. A record is NEVER coerced into
--- validity: an unknown aura type coerced to HELPFUL would silently move the category between the
--- two grids and orphan every container's stored state for it, which is exactly what the
--- immutability decision above forbids. A record that does not answer is SKIPPED and left on disk,
--- for the player to fix or delete rather than for this to guess at.
---
--- THE KEY IS CHECKED FIRST, and refusing a key outside the reserved namespace is the same kind of
--- refusal as refusing an unknown aura type: a record keyed `healing` is not a user category with a
--- bad field, it is a claim on a SHIPPED category's identity, and materializing it puts two
--- definitions under one key and costs the shipped one its container-template entry at the next
--- sync (`Cat.IsUserKey`).
local function usableName(key, rec)
    if not Cat.IsUserKey(key) then
        return nil, "the key is outside the reserved '" .. USER_PREFIX .. "' namespace"
    end
    if type(rec) ~= "table" then return nil, "the record is not a table" end
    if rec.auraType ~= "HELPFUL" and rec.auraType ~= "HARMFUL" then
        return nil, "unknown aura type " .. tostring(rec.auraType)
    end
    local name = Cat.SanitizeUserName(rec.name)
    if not name then return nil, "no usable name" end
    return name
end

--- Every record `profile` stores that `usableName` refuses, as { key =, why = } in key order.
---
--- SKIPPING SUCH A RECORD IS RIGHT AND LEAVING IT AT THAT IS NOT. The sync will not guess at a
--- missing aura type or an unusable name, because guessing moves a category between the two grids
--- or renames it behind the player's back -- so a record that does not answer is left on disk "for
--- the player to fix or delete". But there was nothing to press: an unmaterialized record is in no
--- dropdown, so no Delete reaches it, and `forgetUserKey` skips any profile that still holds a
--- record under the key, so its own debris could never be swept either. A record like that was
--- permanently stuck. This is what the panel reads to offer a way out
--- (settings/GeneralSpells.lua's 'Your categories' block).
---
--- A record under a non-string key is debris of the same kind and is reported too, keyed by what
--- `tostring` makes of it, so the count the player is shown is the whole of what will go.
--- @param profile table|nil
--- @return table
function Cat.UnusableUserRecords(profile)
    profile = profile or (NS.db and NS.db.profile)
    local out = {}
    local recs = type(profile) == "table" and profile.userCategories
    if type(recs) ~= "table" then return out end
    for key, rec in pairs(recs) do
        if type(key) ~= "string" then
            out[#out + 1] = { key = key, why = "the key is not a string" }
        else
            local name, why = usableName(key, rec)
            if not name then
                local at = #out
                out[at + 1] = { key = key, why = why }
            end
        end
    end
    table.sort(out, function(a, b) return tostring(a.key) < tostring(b.key) end)
    return out
end

--- The index a user definition is inserted at: immediately before the aura type's Weapon enchants
--- row (buffs) or its Uncategorized row (debuffs) -- the first definition whose kind is `enchant` or
--- `uncategorized`. So settings/Filters.lua's `custom` grid reads shipped spell lists, then the
--- player's own lists, then Weapon enchants, then Uncategorized: Uncategorized stays LAST (U-1), and
--- a user category sits among the shipped lists it is a sibling of rather than stranded after the
--- enchant row. No shipped definition moves relative to any other, so no shipped ordering claim --
--- A1's two CC rows above `crowdControl`, U-1 itself -- changes.
local function userInsertIndex(list)
    for i, def in ipairs(list) do
        if def.kind == "enchant" or def.kind == "uncategorized" then return i end
    end
    return #list + 1
end

--- Bring `Cat.HELPFUL`, `Cat.HARMFUL`, the container template's `filter.categories` and the schema
--- rows into agreement with `profile`'s stored user categories. THE ONE SEAM: core/Database.lua's
--- NS.RunMigrations calls it after the whole schema ladder and before Database.PrepareProfile,
--- core/AuraMaster.lua's prepareProfile calls it before its own PrepareProfile (so a switch, a copy
--- and a reset all pass through it), and the create and rename acts below call it so a category is
--- live the instant it is made. NOT at panel render: a row that existed only while the panel was
--- open would be invisible to `/am get|set|list`, to a page's Defaults and to the resets, which is
--- the whole reason these rows are in the schema at all.
---
--- IT TEARS DOWN BEFORE IT BUILDS, and the four mirrors move in ONE act. A stale row left behind by
--- a profile switch fails NS.ValidateSchema (the template no longer carries the key, so
--- NS.DefaultFor answers nil) and answers `/am get` for a category this profile does not have; but
--- the severe one is a stale DEFINITION, which makes `Cat.IsSpellCategory(deadKey)` true, so
--- `categorizedUnion` reads the NEW profile's `categorySpells` under a key that belonged to the OLD
--- profile's category and quietly takes ids out of the complement `uncategorized` is defined
--- against. Definitions, rows and template keys are therefore never torn down one without the other.
---
--- Rebuilt whole rather than diffed: the cost is one array rebuild per profile change, and what it
--- buys is that the function has one path, is trivially idempotent, and cannot leave a half-applied
--- state behind if a record in the middle of the list turns out to be corrupt.
--- @param profile table|nil
--- @return number  the categories materialized (a skipped record is not one)
function Cat.SyncUserCategories(profile)
    local recs = (type(profile) == "table" and type(profile.userCategories) == "table")
        and profile.userCategories or {}
    local order = Cat.UserCategoryOrder(profile)
    local template = NS.CONTAINER_TEMPLATE and NS.CONTAINER_TEMPLATE.filter
        and NS.CONTAINER_TEMPLATE.filter.categories

    for _, auraType in ipairs({ "HELPFUL", "HARMFUL" }) do
        local list = Cat[auraType]
        local last = #list
        for i = last, 1, -1 do
            if list[i].userCategory then
                if template then template[list[i].key] = nil end
                table.remove(list, i)
            end
        end
    end
    if NS.UnregisterSchemaRows then
        NS.UnregisterSchemaRows(function(row) return row.userCategory == true end)
    end

    -- Where each aura type's rows are inserted, read BEFORE anything is materialized: the path of
    -- the row the definitions are being inserted in front of. Schema order has to track `Cat.For`
    -- order per aura type, because settings/Filters.lua's renderCategories draws each grid in SCHEMA
    -- order and not in `Cat.For` order -- so a row merely APPENDED would draw below Uncategorized
    -- and break U-1 outright, and a row inserted before Uncategorized alone would still draw below
    -- Weapon enchants while its definition sat above it.
    local before, built = {}, { HELPFUL = {}, HARMFUL = {} }
    for _, auraType in ipairs({ "HELPFUL", "HARMFUL" }) do
        local list = Cat[auraType]
        local at = list[userInsertIndex(list)]
        before[auraType] = at and ("container.filter.categories." .. at.key) or nil
    end

    local made = 0
    for _, key in ipairs(order) do
        local rec = recs[key]
        local name, why = usableName(key, rec)
        if not name then
            if NS.Debug then
                NS.Debug("Migrate", "user category '%s' skipped and left on disk: %s",
                    tostring(key), tostring(why))
            end
        else
            if rec.name ~= name then
                -- Canonicalized in the STORE, not merely rendered safely, so there stays exactly one
                -- stored value and `Cat.SanitizeUserName`'s "never at the draw" rule holds. This is
                -- not coercion of the kind the aura-type rule forbids: a name is a label and nothing
                -- reads it, while an aura type decides which grid and which engine group the
                -- category belongs to.
                if NS.Debug then
                    NS.Debug("Set", "user category '%s': name canonicalized to '%s'", tostring(key), name)
                end
                rec.name = name
            end
            rec.key = key
            local list = Cat[rec.auraType]
            local def = {
                key = key, kind = "spells", label = name, desc = USER_DESC,
                -- An EMPTY starter list, which is the whole reuse argument: FC.CategorySpells
                -- resolves starters-plus-edits, so this category's list IS categorySpells[key].
                spells = {},
                auraType = rec.auraType, userCategory = true,
            }
            table.insert(list, userInsertIndex(list), def)
            if template then template[key] = "show" end
            local b = built[rec.auraType]
            b[#b + 1] = def
            made = made + 1
        end
    end

    -- The rows LAST, because NS.RegisterSchemaRows stamps each row's `default` out of the container
    -- template and the template only carries the key from the loop above.
    if NS.RegisterSchemaRows and NS.CategoryRow then
        for _, auraType in ipairs({ "HELPFUL", "HARMFUL" }) do
            local rows = {}
            for i, def in ipairs(built[auraType]) do rows[i] = NS.CategoryRow(def) end
            if rows[1] then NS.RegisterSchemaRows(rows, before[auraType]) end
        end
    end
    return made
end

--- Whether another user category of `profile` already carries `name` (case-insensitively), ignoring
--- `exceptKey`. For checkpoint 6's warning, which INFORMS and does not block: the key is identity,
--- so two categories called the same thing are two categories and refusing that would be refusing
--- something harmless.
--- @return boolean
function Cat.UserCategoryNameTaken(profile, name, exceptKey)
    local clean = Cat.SanitizeUserName(name)
    if not clean or type(profile) ~= "table" or type(profile.userCategories) ~= "table" then
        return false
    end
    clean = clean:lower()
    for key, rec in pairs(profile.userCategories) do
        if key ~= exceptKey and type(rec) == "table" and type(rec.name) == "string"
            and rec.name:lower() == clean then
            return true
        end
    end
    return false
end

--- Create a user category and return its key, or nil plus a player-facing reason.
---
--- The category is LIVE the instant this returns: the sync materializes the definition, stamps the
--- container template and registers the schema row, so `/am get container.filter.categories.<key>`
--- answers at once and the next compile counts its spells. Its spell list needs no creation of its
--- own -- it is `profile.categorySpells[key]`, empty until the player adds to it on General ->
--- Spell Categories, exactly like every other category's edits.
---
--- THE STORED CONTAINERS GET THE KEY HERE TOO, through Database.PrepareProfile's ordinary backfill
--- -- the same mechanism `Cat.DefaultStates`' comment above promises for a key added in a later
--- version, run one act earlier rather than waited for. The compiler would not have noticed the
--- difference (`splitCategories` reads an absent state as Show, which is the default anyway), but
--- the settings panel would: a ChoiceGrid cell lights by comparing the STORED value against its
--- column, so until the key exists in the container a brand-new category would draw with neither
--- Show nor Hide lit. PrepareProfile is idempotent, so calling it here costs a walk and nothing else.
--- @param name string
--- @param auraType string  "HELPFUL" | "HARMFUL"
--- @param profile table|nil  defaults to NS.db.profile
--- @param db table|nil  defaults to NS.db, for the account-wide key scan
--- @return string|nil key, string|nil reason
function Cat.CreateUserCategory(name, auraType, profile, db)
    profile = profile or (NS.db and NS.db.profile)
    -- No profile is not a refusal a player can act on and never reaches one: every caller runs after
    -- NS.InitDB. It answers nil with no reason rather than inventing a sentence to show.
    if type(profile) ~= "table" then return nil, nil end
    if auraType ~= "HELPFUL" and auraType ~= "HARMFUL" then
        return nil, L["A category holds buffs or debuffs, and the choice cannot be changed later."]
    end
    local clean = Cat.SanitizeUserName(name)
    if not clean then return nil, L["A category needs a name."] end
    if type(profile.userCategories) ~= "table" then profile.userCategories = {} end
    if type(profile.userCategoryOrder) ~= "table" then profile.userCategoryOrder = {} end
    local key = Cat.NewUserKey(Cat.UserKeysInUse(db or NS.db))
    profile.userCategories[key] = { key = key, name = clean, auraType = auraType }
    local count = #profile.userCategoryOrder
    profile.userCategoryOrder[count + 1] = key
    Cat.SyncUserCategories(profile)
    if NS.Database and NS.Database.PrepareProfile then NS.Database.PrepareProfile(profile) end
    if NS.Debug then
        NS.Debug("Set", "user category '%s' created: %s (%s)", key, clean, auraType)
    end
    return key, nil
end

--- Rename a user category.
---
--- THE KEY DOES NOT MOVE, which is the entire point of the keying scheme: every container's stored
--- `filter.categories.<key>`, the schema row, and `categorySpells[key]` all go on naming the same
--- category, so a rename cannot orphan one stored value. A duplicate name is ALLOWED -- see
--- `Cat.UserCategoryNameTaken` -- and an empty or whitespace-only one is refused. A shipped category
--- is refused outright: the plan of record's lock is on the category OBJECT, never on its contents.
---
--- THE RESERVED NAMESPACE IS CHECKED HERE TOO, exactly as `Cat.DeleteUserCategory` checks it and
--- for the same reason: a record keyed `healing` -- hand-edited, imported, or left by a corrupt
--- write -- is not a user category with a bad field, it is a claim on a SHIPPED category's identity.
--- Renaming it would succeed, store a name under a shipped key and leave the store holding a record
--- the sync refuses to materialize, which is exactly the shape `usableName` exists to refuse.
--- @return boolean|nil ok, string|nil reason
function Cat.RenameUserCategory(key, name, profile)
    profile = profile or (NS.db and NS.db.profile)
    if type(profile) ~= "table" then return nil, nil end
    local recs = type(profile.userCategories) == "table" and profile.userCategories or {}
    local rec = type(key) == "string" and Cat.IsUserKey(key) and recs[key]
    if type(rec) ~= "table" then
        return nil, L["Only a category you made can be renamed."]
    end
    local clean = Cat.SanitizeUserName(name)
    if not clean then return nil, L["A category needs a name."] end
    local was = rec.name
    rec.name = clean
    Cat.SyncUserCategories(profile)
    if NS.Debug then
        NS.Debug("Set", "user category '%s' renamed: %s -> %s", key, tostring(was), clean)
    end
    return true, nil
end

-- ---------------------------------------------------------------------------
-- Deletion (issue #10 checkpoint 5)
-- ---------------------------------------------------------------------------
--
-- CLEANUP IS EAGER: everything a deleted category leaves behind goes at the moment of the delete,
-- across every STORED profile, the ones nobody is logged into included. The plan of record allowed
-- either eager or lazy if the choice was documented and the validator tolerated the transient
-- state; this is the choice and these are the reasons.
--
-- 1. THERE IS NO LAZY PRUNER TO WRITE IT INTO. `Database.Backfill` only ever fills -- its own header
--    says so -- and `Database.PrepareProfile` is fill-and-reconcile throughout, so lazy would mean a
--    NEW destructive pass over stored containers that runs on every load and every profile switch,
--    deleting keys it decides are unknown. That pass is the dangerous thing here, not the debris: it
--    would run while `Cat.SyncUserCategories` is the thing that decides what is known, and a load in
--    which the sync half ran -- a corrupt record, an error mid-list -- would hand it a set of
--    "unknown" keys that are merely not materialized YET, and it would delete the player's stored
--    Show/Hide for categories that still exist. Eager cleanup runs in one act, on a key the player
--    just named, and cannot mistake a half-built session for a dead category.
-- 2. LAZY CANNOT REACH THE PROFILES THAT ACTUALLY HOLD THE DEBRIS. A pruner on the load path only
--    ever sees the profile being loaded, so debris in an inactive profile survives until the player
--    happens to switch to it -- and `Cat.UserKeysInUse` is account-wide precisely because these keys
--    travel (CopyFrom, OnProfileCopied, and #9's import). Eager walks `Database.EachProfile`, which
--    is the same set of profiles the schema ladder migrates.
-- 3. THE VALIDATOR IS NEVER ASKED TO TOLERATE ANYTHING. `NS.ValidateSchema` fails a row whose path
--    does not resolve against the container template, and the sync tears the row, the definition and
--    the template key down together -- so after an eager delete there is no row, no def, no template
--    key and no stored leaf anywhere, and the validator is clean at every instant rather than clean
--    once something later tidies up.
--
-- THE ONE THING EAGER MUST NOT DO is delete another category's data, and one case makes that real:
-- AceDB's profile COPY duplicates `userCategories` wholesale, so two profiles can legitimately hold
-- a record under the SAME key, with their own names, their own spell lists and their own containers.
-- Deleting in one of them must leave the other entirely alone. So the sweep skips any profile that
-- still holds a record of its own under the key -- `forgetUserKey`'s first test -- and the owner's
-- record is removed BEFORE the sweep, which is what makes the owner profile eligible for it.

--- Clear every trace of category `key` from ONE stored profile: its spell list and the stored
--- Show/Hide in each of its containers. A profile that holds a RECORD under the key owns a category
--- of its own there (a profile copy) and is left untouched -- see the note above.
--- @return number  the leaves cleared, for the log
local function forgetUserKey(p, key)
    if type(p) ~= "table" then return 0 end
    if type(p.userCategories) == "table" and p.userCategories[key] ~= nil then return 0 end
    local cleared = 0
    if type(p.categorySpells) == "table" and p.categorySpells[key] ~= nil then
        p.categorySpells[key] = nil
        cleared = cleared + 1
    end
    if type(p.containers) == "table" then
        for _, c in pairs(p.containers) do
            local cats = type(c) == "table" and type(c.filter) == "table" and c.filter.categories
            if type(cats) == "table" and cats[key] ~= nil then
                cats[key] = nil
                cleared = cleared + 1
            end
        end
    end
    return cleared
end

--- Sweep category `key` out of every stored profile of `db`, `profile` first and by identity.
---
--- PER PROFILE, INSIDE ITS OWN pcall, and that is the whole of the atomicity answer. By the time
--- this runs the record is already gone, so the definition, the schema row and the container
--- template's entry MUST come down with it: a raise part way through the walk would otherwise leave
--- a LIVE category no record owns -- a schema row resolving against a template key nothing will
--- write again, and a dropdown entry whose Delete now refuses. Making the sweep atomic would mean
--- copying every stored profile and swapping them in, which is the whole saved-variables table;
--- making the FAILURE recoverable costs one pcall per profile. So this is RECOVERABLE, NOT ATOMIC,
--- and the difference is said plainly: a profile whose stored table is malformed costs only its own
--- leaves, every other profile is still swept, the caller's `Cat.SyncUserCategories` runs either
--- way, and what survives is an inert Show/Hide value under a key no category answers to -- read by
--- nothing, written by nothing, and cleared the next time that key is swept.
---
--- The owner profile goes first and BY IDENTITY, because it may not be in the store at all: the
--- headless harness and every test hand a bare profile table in, and `Database.EachProfile`'s
--- fallback branch answers `db.profile`, which is a DIFFERENT table from the one being deleted from.
--- The `seen` set is what keeps a profile reachable both ways from being swept twice -- harmless,
--- but it would double the count in the log line and make the log a lie.
--- @return number cleared, number failed
local function sweepUserKey(profile, key, db)
    local cleared, failed, seen = 0, 0, {}
    local function sweep(p)
        if type(p) ~= "table" or seen[p] then return end
        seen[p] = true
        local ok, n = pcall(forgetUserKey, p, key)
        if ok then cleared = cleared + n else failed = failed + 1 end
    end
    sweep(profile)
    db = db or NS.db
    if type(db) == "table" and NS.Database and NS.Database.EachProfile then
        if not pcall(NS.Database.EachProfile, db, sweep) then failed = failed + 1 end
    end
    return cleared, failed
end

--- Delete a user category and everything it owns, and answer whether it went.
---
--- THE REFUSAL IS THE ACT'S, NOT THE PANEL'S. A shipped category is refused here, by the same test
--- the rename uses -- it has no stored record -- so hiding the button is a courtesy to the reader
--- and never the enforcement. The lock is on the category OBJECT: nothing in this file can delete,
--- rename or retype `healing`, while `categorySpells.healing` stays the player's to edit and to
--- Restore. A key outside the reserved namespace is refused for the same reason `usableName`
--- refuses one: a record keyed `healing` is a claim on a shipped category's identity, and honoring
--- it here would sweep the SHIPPED category's stored state out of every profile in the account.
---
--- WHAT IS DISCARDED, in the order this does it: the record, the order entry (through the ordinary
--- reconcile, which drops a dangling key), the player's spell list for it, and every container's
--- stored Show/Hide for it in every stored profile. The definition, the schema row and the container
--- template's entry are the sync's, and it tears all three down as one act.
--- THE PARTIAL SWEEP IS PART OF THE ANSWER (owner, 2026-09-21). The sweep is recoverable and not
--- atomic on purpose -- see `sweepUserKey` -- so a stored profile whose table is malformed keeps its
--- own leaves while every other profile is cleaned. That is a real outcome and not a failure of the
--- delete: the record is gone, the definition is gone, and what survives is inert. But it used to
--- reach `NS.Debug` and nothing else, so the player was told "deleted" and never told that one
--- profile kept its debris. The count of refusing profiles is now RETURNED, third, so a caller can
--- say so; settings/GeneralSpells.lua's confirmation does.
--- @param key string
--- @param profile table|nil  the profile that OWNS the category; defaults to NS.db.profile
--- @param db table|nil  the store to sweep; defaults to NS.db
--- @return boolean|nil ok, string|nil reason, number|nil failed  profiles that refused the sweep
function Cat.DeleteUserCategory(key, profile, db)
    profile = profile or (NS.db and NS.db.profile)
    if type(profile) ~= "table" then return nil, nil end
    local recs = type(profile.userCategories) == "table" and profile.userCategories or {}
    local rec
    if type(key) == "string" and Cat.IsUserKey(key) then rec = recs[key] end
    if rec == nil then
        return nil, L["Only a category you made can be deleted."]
    end
    -- A record that is not a TABLE is a corrupt one, and it is deleted rather than refused. Refusing
    -- it is what made it permanently undeletable: the sync will not materialize it, so it is in no
    -- dropdown and no other act can reach it (`Cat.UnusableUserRecords`). The namespace test above
    -- is the one that still has to hold, because that is the one protecting a shipped category's
    -- stored state; the shape of the record protects nothing.
    local name = type(rec) == "table" and rec.name or nil
    recs[key] = nil
    Cat.UserCategoryOrder(profile)

    local cleared, failed = sweepUserKey(profile, key, db)

    Cat.SyncUserCategories(profile)
    if NS.Debug then
        NS.Debug("Set",
            "user category '%s' (%s) deleted: %s stored leaf(s) cleared across the account, %s profile(s) refused the sweep",
            key, tostring(name), cleared, failed)
    end
    return true, nil, failed
end

--- Forget every record `Cat.UnusableUserRecords` names, and answer how many went.
---
--- ONE ACT RATHER THAN A LOOP OF DELETES, because `Cat.DeleteUserCategory` cannot reach these: it
--- refuses a key outside the reserved namespace, and a record keyed `healing` is exactly the shape
--- that gets stuck. The namespace test is still honored where it actually matters -- the RECORD goes
--- whatever its key, but the STORED LEAVES are swept only for a key inside the namespace, because a
--- leaf under a shipped key is the shipped category's Show/Hide and is none of this act's business.
---
--- Nothing here can be repaired automatically, and nothing tries: a record with no usable aura type
--- or no usable name holds a spell list that cannot be attributed to either grid, and guessing is
--- the thing `usableName` exists to refuse. This is the player's decision, taken behind the panel's
--- own confirmation (settings/GeneralSpells.lua).
--- @param profile table|nil
--- @param db table|nil
--- @return number  the records forgotten
function Cat.ForgetUnusableUserRecords(profile, db)
    profile = profile or (NS.db and NS.db.profile)
    if type(profile) ~= "table" then return 0 end
    local bad = Cat.UnusableUserRecords(profile)
    if not bad[1] then return 0 end
    local recs = type(profile.userCategories) == "table" and profile.userCategories or {}
    local cleared = 0
    for _, entry in ipairs(bad) do
        recs[entry.key] = nil
        if Cat.IsUserKey(entry.key) then
            cleared = cleared + sweepUserKey(profile, entry.key, db)
        end
    end
    Cat.UserCategoryOrder(profile)
    Cat.SyncUserCategories(profile)
    if NS.Debug then
        NS.Debug("Set", "%s unreadable user category record(s) forgotten: %s stored leaf(s) cleared",
            #bad, cleared)
    end
    return #bad
end
