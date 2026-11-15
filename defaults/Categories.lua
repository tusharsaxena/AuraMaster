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
--                  honors spell ids for BUFFS ON UNITS YOU CAN ASSIST and DEBUFFS ON UNITS YOU CANNOT,
--                  so a buff category's list bites on the player, the pet and an assistable target or
--                  focus, and a debuff category's list on a target or focus you cannot assist and
--                  nowhere else
--                  (issue #11 gave `Cat.HARMFUL` its first, `hardCC` and the `softCC` the 2026-10-04 split made
--                  `ccRoot` and `ccSnare`). The Filters
--                  page and the General page > Spell categories say so where it matters (docs/scope.md,
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
--                  grid, default Show. There is no entry for it on the General page > Spell categories: it has no
--                  list to edit.
--
--                  ONE ROW PER AURA TYPE, ASYMMETRIC (2026-09-16 — the owner restored the debuff
--                  row an earlier pass dropped; issue #11's part A2 re-derived the asymmetry from the
--                  UNIT rather than from the aura type). Both rows' unions are now genuine subsets —
--                  `Cat.HELPFUL` has always had `spells`-kind categories and `Cat.HARMFUL` gained
--                  `hardCC`, `ccRoot` and `ccSnare` below — so what decides whether a Show row may contribute a
--                  group of its own is no longer "is the union empty" but "is the one constraint that
--                  group would carry CERTAIN to be applied". Its only constraint is an
--                  `excludeSpellIDs` of the union, and the engine discards spell ids except for buffs
--                  on units you can assist and debuffs on units you cannot — so the gate is
--                  `modules/FilterCompiler.lua`'s `FC.IdsMode(unit, auraType)`, "always" ONLY for
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
--                  these categories" toggle exactly. Concretely proven (2026-09-16, and again in A2):
--                  a Show group whose one `excludeSpellIDs` the engine throws away carries no
--                  candidate filter at all, draws EVERY aura of the type regardless of any other
--                  category's Hide, and neuters them all — the owner's original complaint reborn.
--
-- WHERE THE LISTS ARE. A `spells` definition below carries no ids: Retail's lists are in
-- defaults/Categories_Retail.lua and WoW Forever's in defaults/Categories_Forever*.lua, picked once at
-- the end of this file. The notes above a definition describe its list there. Everything below about
-- the lists (one id per line, provenance) is about Retail's file.
--
-- THE SPELL LISTS ARE A STARTER SET, WRITTEN FOR THIS ADDON. They were assembled from public spell
-- data for Retail 12.x and are meant to be edited: the General page > Spell categories lets a player add or remove any
-- id per category, and those edits live in the profile (profile.categorySpells, shared by every
-- container since schema v2), never here.
-- ONE ID PER LINE, and the comment on that line gives the spell's name in the 12.1 client data
-- followed by any context: which class, race or appearance the id belongs to when a spell has
-- several, where it came from (the 2026-09-24 combat logs, via tools/spell-research), and the
-- owner's rulings that placed it. A comment above a class or a category explains more than one id.
-- An id that does not exist in the current client simply never matches, so a stale entry costs
-- nothing but a row in the editor.
--
-- PROVENANCE (issue #11 part C, spec section C6). `hardCC` and `ccRoot`/`ccSnare` below (one `softCC`
-- row until the 2026-10-04 split) are the first lists
-- here that were DERIVED rather than hand-assembled: `tools/spell-research/research.py` reads the
-- client's own DB2 tables, closes the player-reachable spell pool over `EffectTriggerSpell` (the
-- addon filters on the AURA's id, not the cast's), buckets by spell mechanic, and diffs the result
-- against the seed file — it never writes it. Each list records the build and date it was derived
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
        -- Owner 2026-09-25: Blood Shield (77535), Shuffle (215479) and Rushing Jade Wind (116847) are
        -- not active mitigation, so Monk has no entry here.
    },
    {
        key = "raidCDs", kind = "spells", label = "Raid cooldowns",
        desc = "Group-wide cooldowns and haste effects.",
    },
    {
        key = "offensiveCDs", kind = "spells", label = "Offensive cooldowns",
        desc = "Damage cooldowns.",
    },
    {
        -- One list since schema v2: the former coreHealing and lesserHealing, united
        -- (core/Database_Migrations.lua's MigrateV2 merges a player's edits and states of the two).
        key = "healing", kind = "spells", label = "Healing",
        desc = "Heal-over-time effects, shields and beacons.",
    },
    {
        key = "support", kind = "spells", label = "Support",
        desc = "Buffs cast on other players.",
    },
    {
        -- Split out of Support (owner 2026-09-25): the raid-wide buffs every group member carries.
        -- Blessing of the Bronze has one aura per class; the ids are the ones the 2026-09-24 combat
        -- logs saw (docs/spell-research/2026-09-24-logs).
        key = "groupBuffs", kind = "spells", label = "Group buffs",
        desc = "Raid-wide buffs such as Mark of the Wild, Arcane Intellect and Battle Shout.",
    },
    {
        key = "movement", kind = "spells", label = "Movement",
        desc = "Speed and freedom effects.",
    },
    {
        key = "utility", kind = "spells", label = "Utility",
        desc = "Soulstones, stealth, water walking and similar.",
    },
    {
        -- Owner 2026-09-25. Travel Form and Mount Form are here only, not in Movement; Ghost Wolf stays
        -- in Movement.
        key = "stances", kind = "spells", label = "Stances",
        desc = "Warrior stances, druid forms and paladin auras.",
    },
    {
        -- Owner 2026-09-25. The buffs of the DB2 "Racial - <race>" skill lines' active abilities and
        -- procs (build 12.1.0.69875), passives left out; every id here but four was seen as a player
        -- buff in the 2026-09-24 combat logs (not seen: 28880, 121093, 370626 Gift of the Naaru and
        -- 281954 Pterrordax Swoop). The racial DEBUFFS are the debuff list `racialDebuffs` below.
        key = "racials", kind = "spells", label = "Racials",
        desc = "Buffs from racial abilities, such as Stoneform, Berserking and Blood Fury.",
    },
    {
        key = "important", kind = "token", token = "IMPORTANT", label = "Important (Blizzard)",
        desc = "Auras Blizzard flags as important, the ones enemy nameplates show.",
    },
    {
        key = "castable", kind = "token", token = "RAID", label = "Castable/Dispellable by you",
        desc = "Blizzard's RAID filter: helpful auras the player can apply and harmful auras the player can dispel. On an enemy this includes buffs you can dispel or remove, such as an Enrage you can soothe or tranquilize.",
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
        desc = "Your temporary weapon enchants, drawn after the buffs. Only on a container showing your own buffs; which weapon slots count is set on the General page > Spell categories.",
    },
    {
        -- U-1: last in the grid, on purpose (renderCategories draws categoryRows() in Cat.For order).
        key = "uncategorized", kind = "uncategorized", label = "Uncategorized",
        desc = "Not in any of the Spell categories lists above (Blizzard categories do not count). On a container watching you or your pet, Show rescues an unlisted buff from a Hidden Blizzard category; on a target or focus Blizzard may discard the spell list that rescue is built from, so Show simply changes nothing there. Hide removes the aura along with everything else this container has no other reason to draw, on every unit.",
    },
}

-- ---------------------------------------------------------------------------
-- Debuff categories
-- ---------------------------------------------------------------------------
--
-- Every category here but the four spell lists is something the engine can evaluate for ANY unit.
-- `hardCC`, `ccRoot`, `ccSnare` and `racialDebuffs` are `spells`-kind (issue #11 part A) and so are
-- not: Blizzard honors spell ids for debuffs only on units you CANNOT assist (UnitCanAssist, so
-- neutral units too), and discards them on the player, the pet and any unit you can assist. The rows are still worth shipping — the question
-- they answer ("is my sheep on the target", "is it rooted") is asked of an enemy target or focus,
-- which is exactly where the ids do bite — and every
-- surface that can mislead says so: their own descs below, the Filters section's Categories tab, the
-- blurb on the General page > Spell categories, and the per-container orange warning
-- (`FC.WARN.IDS_ASSISTABLE` / `IDS_OWN_DEBUFFS`, modules/FilterCompiler.lua).

local ALL_DISPELS = { Magic = true, Curse = true, Disease = true, Poison = true, Bleed = true }

-- DERIVED AGAINST BUILD 12.1.0.69875, 2026-09-20 (spec C6). Both lists below came out of
-- `python3 tools/spell-research/research.py`, which is what regenerates them; its frozen bundle for
-- this pair is docs/spell-research/2026-09-20/ (derived.json, DIFF.md, ANALYSIS.md and the gzipped
-- raw DB2 exports). Roll this line, and the two curation notes' numbers, whenever a later run is
-- accepted — the tool never writes this file, so a list can only go stale silently if nobody is
-- told which build it was true for.

Cat.HARMFUL = {
    {
        -- ABOVE `crowdControl` on purpose: these three editable CC rows read before the Blizzard token
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
        --      frozen in docs/spell-research/2026-09-20/, and the General page > Spell categories lets a
        --      player add any id out of it. These CC rows are A STARTER SET meant to be edited,
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
        -- verified too, but by hand wherever derived.json is unreliable on it (see `ccSnare`).
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
        -- `ccSnare` has never shipped; Paladin's CC Snare row is Judgment of Justice). A later research
        -- run WILL derive the ability into the hard-CC bucket again: leaving it out is the intended
        -- diff, not an oversight to helpfully correct. A player who wants it adds the id on
        -- the General page > Spell categories.
        --
        -- MAIM ships on 203123, not 203126. Both are aura-applying spells named Maim in this build,
        -- and the one a Feral target carries is 203123 — mechanic 12 (stunned) on DiminishType 4,
        -- the stun DR, matching the finisher's own DR category. 203126 is mechanic 14
        -- (incapacitated) on DiminishType 16, a different DR entirely. The cast, 22570, applies no
        -- aura of its own and so is not a debuff id at all.
        --
        -- KNOWN GAPS, recorded rather than papered over, because a player who notices one missing
        -- should find the reason in this file. Three abilities are absent and stay absent (two more
        -- the research run cannot reach, the Shaman totems, now ship by hand):
        --   * Repentance (20066), hard CC. The research run's SENTINELS_UNREACHABLE records why —
        --     its id appears in none of the four pool sources for this build, so the client grants
        --     it by a route the pipeline cannot see.
        --   * Axe Toss (89766) and Seduction (6358), hard CC, the warlock's pet CC. Both sit on a
        --     PET skill line with ClassMask 0, and the pool keeps a ClassMask-0 row only on one of
        --     the thirteen class lines — the same test that keeps professions and mounts out.
        --   * Earthbind Totem (2484) — SHIPPED BY HAND on `ccSnare` as its aura, Earthbind 3600
        --     (owner 2026-10-04, from the in-game tooltip: "Movement speed reduced by 30%."). The
        --     research run cannot derive it: the totem carries no mechanic and its aura is named
        --     "Earthbind", so neither the mechanic match nor the bridge's exact-name test crosses.
        --   * Earthgrab Totem — SHIPPED BY HAND on `ccRoot` as its aura, Earthgrab 64695 (owner
        --     2026-10-04, tooltip "Rooted."). Same shape as Earthbind and in NEITHER derived bucket:
        --     the talent 51485 is in the pool but carries mechanic 0, and the root aura 64695
        --     (mechanic 7) is triggered only by 116943, the totem's own pulse, which the pool never
        --     reaches. A later research run's diff will propose dropping both; keep them.
        -- A player who wants any of the three adds it by id on the General page > Spell categories.
        key = "hardCC", kind = "spells", label = "CC Loss of Control",
        desc = "Stuns, incapacitates, disorients and fears, plus Cyclone, Banish and Mind Control — the unit is not in control of itself. Only works on a target or focus you can't assist: Blizzard discards spell lists for debuffs on you or on a unit you can assist.",
    },
    {
        -- CC ROOT and CC SNARE (owner 2026-10-04) are the two halves of what shipped until then as one
        -- `softCC` row, "Soft CC (roots & snares)". The owner split it because "is it pinned" and "is
        -- it slowed" are different questions: a root stops the unit moving at all, a snare only slows
        -- it. Schema v12 (core/Database_Migrations.lua) gives every container that stored a Soft CC
        -- state BOTH new keys with that same state, and moves the player's Soft CC list edits to
        -- whichever half ships the id (an id in neither goes to both), so none draws differently.
        --
        -- THE SPLIT IS THE CLIENT'S OWN, and it fell out cleanly: every id the `softCC` row shipped
        -- carries exactly one of the two in build 12.1.0.69875 — SpellMechanic 7 (rooted) on a
        -- MOD_ROOT_2 aura (455), or SpellMechanic 11 (snared) on a MOD_DECREASE_SPEED aura (33) —
        -- and the tooltip of every one reads the same way ("Rooted.", "Frozen in place.",
        -- "Immobilized." against "Movement speed reduced by $s1%."). Nothing was added or dropped:
        -- 13 ids moved here, the rest to `ccSnare`, and the two rows together were the old row exactly;
        -- the owner then added the Shaman totems' Earthgrab (here) and Earthbind (`ccSnare`) by hand.
        -- A FREEZE is a root (Frost Nova, Ice Nova, Frostbite): the unit is held in place but keeps
        -- control of itself, which is what SpellMechanic 7 records, unlike the stun-like Frozen (13)
        -- that `hardCC` buckets.
        --
        -- The old row's curation still governs both halves — one id per ability, the id the TARGET
        -- carries (Void Tendrils on its aura 114404, not the cast 108920; The Hunt on its root, the
        -- 2026-09-24 combat logs' 370970) and every class's signature root or snare shipped. An
        -- ability that lands BOTH a snare and a root ships each on its own id, in its own row: Disable
        -- snares on 116095 and roots on 116706 (the 2026-09-24 combat logs' aura id) when it is
        -- reapplied to a snared target. The research tool (tools/spell-research/research.py) buckets
        -- the two by mechanic, a root winning over a snare on a spell that carries both.
        --
        -- Shaman's root is Earthgrab 64695, shipped by hand: the `hardCC` KNOWN GAPS note says why.
        key = "ccRoot", kind = "spells", label = "CC Root",
        desc = "Roots and freezes — the unit keeps control of itself but cannot move. Only works on a target or focus you can't assist: Blizzard discards spell lists for debuffs on you or on a unit you can assist.",
    },
    {
        -- The snare half of the 2026-10-04 split; `ccRoot` above says why and how. What follows is the
        -- old `softCC` row's own curation record, unchanged but for the ids that went to `ccRoot`: where
        -- it names a root (Void Tendrils, Steel Trap, Clash, Landslide, Entrapment, The Hunt) that id now
        -- ships there, and its "212 derived, 54 shipped" counts the row before the split.
        --
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
        -- safe to say out loud is that the frozen bundle and the Spell categories editor put every
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
        -- ships on its root id (323996 rooted, since 370970; 333762 is the stun), in `ccRoot` since
        -- the split: a demon hunter watching The Hunt on a target is watching the root that pins
        -- them. Wake of Ashes was the eighth such
        -- name and went to `hardCC`; the owner removed it from both rows on 2026-09-20, and `hardCC`
        -- says so.
        key = "ccSnare", kind = "spells", label = "CC Snare",
        desc = "Snares and slows — the unit keeps control of itself but moves more slowly. Only works on a target or focus you can't assist: Blizzard discards spell lists for debuffs on you or on a unit you can assist.",
    },
    {
        -- Owner 2026-09-25: the debuffs of the DB2 "Racial - <race>" skill lines, every one seen in the
        -- 2026-09-24 combat logs. They stay in CC Loss of Control, CC Root and CC Snare as well; this list only groups them.
        -- Mechagnome's Recently Failed (313015) is left out: a lockout on yourself, where Blizzard
        -- discards a debuff spell list anyway. A key of its own, not `racials`: a key names one
        -- category across both aura types (`Cat.AuraTypeOf`).
        key = "racialDebuffs", kind = "spells", label = "Racials",
        desc = "Debuffs from racial abilities, such as War Stomp and Quaking Palm. Only works on a target or focus you can't assist: Blizzard discards spell lists for debuffs on you or on a unit you can assist.",
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
        -- Restored 2026-09-16, asymmetric with the buff row — see the KINDS doc above.
        -- Hide reproduces the retired "Only these categories" toggle exactly (drops the catch-all, so
        -- only what is explicitly Shown is drawn). Show is a plain default that must NOT contribute a
        -- group of its own, and since issue #11's A2 that is a fact about the UNIT, not about this
        -- file: `hardCC`, `ccRoot` and `ccSnare` above give the debuff union real content, so the old reason
        -- ("there is nothing to be outside of") is dead. The live reason is that the group a Show
        -- would contribute carries one constraint, an `excludeSpellIDs` of that union, and the engine
        -- discards spell ids on every debuff container there is — on the player and pet outright, on
        -- a target or focus the moment the unit is friendly. What the engine would receive is an
        -- unrestricted HARMFUL group: every debuff drawn, every other Hide on the tab defeated.
        -- `modules/FilterCompiler.lua` gates it on `FC.IdsMode(unit, auraType) == "always"` — false for
        -- all four debuff units and for a `target`/`focus` buff container too — so this stays a
        -- general rule keyed on whether ids are CERTAIN to be honored, not a debuff-only special case.
        key = "uncategorizedDebuffs", kind = "uncategorized", label = "Uncategorized",
        desc = "Hide draws only what you have explicitly set to Show on this tab (the retired 'Only these categories' toggle, exactly). Show is the default and changes nothing by itself: Blizzard never lets a debuff container use a spell list to rescue an aura, so there is no rescue for this row to perform.",
    },
}

-- ---------------------------------------------------------------------------
-- The client's seeds and the client gate (clients-§5, clients-§4; AM-FP06)
-- ---------------------------------------------------------------------------
--
-- TWO LISTS, PICKED ONCE. Retail's lists are in defaults/Categories_Retail.lua
-- (NS.CategorySeedsRetail, hand-curated; tools/spell-research's `retail.py`, `logs.py` and
-- `research.py --check-shipped` read and write them there). WoW Forever's are generated into
-- defaults/Categories_Forever*.lua (NS.CategorySeedsForever). Both load before this file and publish
-- [key] = { CLASS = { ids } }. The client is read HERE, once; nothing that reads `Cat` ever asks which
-- client it is on. Forever's list is its own, never Retail's filtered: a Retail list with the ids
-- Forever lacks taken out is a guess with holes in it (clients-§5). The definitions above carry no
-- list of their own, so a `spells` category is the same definition on both clients.
--
-- THE GATE. A definition may carry `clients = { "retail" }` (or any clients-§1 token list), and the
-- two lists are rebuilt through NS.Compat.ForClient, so a gated category NEVER ENTERS THEM: not the
-- Filters grid, not the General page > Spell categories, not DefaultStates, not the schema rows, not
-- the compiler. A `spells` category the Forever data declares empty (NS.CategorySeedsForever.EMPTY,
-- the generator's one fact about it) is declared Retail-only here, so a re-run that fills it ungates
-- it with no code change. A profile that still names a gated key (copied by hand from the other
-- client) keeps its value; nothing reads it as a category.
local IS_FOREVER = NS.Compat.ClientKey() == "forever"
local SEEDS = (IS_FOREVER and NS.CategorySeedsForever or NS.CategorySeedsRetail) or {}
local FOREVER_EMPTY = (IS_FOREVER and NS.CategorySeedsForever and NS.CategorySeedsForever.EMPTY) or {}
local RETAIL_ONLY = { "retail" }

local function servedHere(list)
    local out = {}
    for _, def in ipairs(list) do
        if def.kind == "spells" then
            if FOREVER_EMPTY[def.key] then def.clients = RETAIL_ONLY end
            def.spells = spells(SEEDS[def.key] or {})
        end
        if NS.Compat.ForClient(def.clients) then out[#out + 1] = def end
    end
    return out
end

Cat.HELPFUL = servedHere(Cat.HELPFUL)
Cat.HARMFUL = servedHere(Cat.HARMFUL)

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
    -- A key the running client gates off (clients-§4) is in neither list, so it gets no state.
    for _, key in ipairs(keys) do
        if out[key] then out[key] = "show" end
    end
    return out
end

--- The states of an ENCHANT-ONLY buff container (schema v5, feedback #6): every buff category Hidden
--- but Weapon enchants, Uncategorized included, so the container draws the player's temporary weapon
--- enchants and no aura at all. The v5 migration (core/Database_Migrations.lua) and
--- `/am new enchants` (settings/Slash.lua) both build one from this.
--- @return table
function Cat.EnchantOnlyStates()
    return Cat.StatesShowing({ "weaponEnchants" })
end
