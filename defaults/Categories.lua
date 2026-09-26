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
--                  ONE ROW PER AURA TYPE, ASYMMETRIC (2026-09-16 — the owner restored the debuff
--                  row an earlier pass dropped; issue #11's part A2 re-derived the asymmetry from the
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
--                  these categories" toggle exactly. Concretely proven (2026-09-16, and again in A2):
--                  a Show group whose one `excludeSpellIDs` the engine throws away carries no
--                  candidate filter at all, draws EVERY aura of the type regardless of any other
--                  category's Hide, and neuters them all — the owner's original complaint reborn.
--
-- THE SPELL LISTS ARE A STARTER SET, WRITTEN FOR THIS ADDON. They were assembled from public spell
-- data for Retail 12.x and are meant to be edited: General -> Spell Categories lets a player add or remove any
-- id per category, and those edits live in the profile (profile.categorySpells, shared by every
-- container since schema v2), never here.
-- ONE ID PER LINE, and the comment on that line gives the spell's name in the 12.1 client data
-- followed by any context: which class, race or appearance the id belongs to when a spell has
-- several, where it came from (the 2026-09-24 combat logs, via tools/spell-research), and the
-- owner's rulings that placed it. A comment above a class or a category explains more than one id.
-- An id that does not exist in the current client simply never matches, so a stale entry costs
-- nothing but a row in the editor.
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
            WARRIOR = {
                118038, -- Die by the Sword
                184364, -- Enraged Regeneration
                871,    -- Shield Wall
                23920,  -- Spell Reflection
                12975,  -- Last Stand
                385391, -- Spell Reflection; the aura id the 2026-09-24 combat logs show
            },
            PALADIN = {
                642,    -- Divine Shield
                498,    -- Divine Protection
                31850,  -- Ardent Defender
                86659,  -- Guardian of Ancient Kings
                184662, -- Shield of Vengeance
                205191, -- Eye for an Eye
                403876, -- Divine Protection; the aura id the 2026-09-24 combat logs show
                212641, -- Guardian of Ancient Kings; the aura id the 2026-09-24 combat logs show
                393108, -- Guardian of Ancient Kings; the aura id the 2026-09-24 combat logs show
                389539, -- Sentinel; added from the 2026-09-24 combat logs
                6940,   -- Blessing of Sacrifice; from the 2026-09-24 combat logs; owner review placed it here, not in Support
            },
            HUNTER = {
                186265, -- Aspect of the Turtle
                264735, -- Survival of the Fittest
            },
            ROGUE = {
                5277,   -- Evasion
                31224,  -- Cloak of Shadows
                1966,   -- Feint
            },
            PRIEST = {
                47585,  -- Dispersion
                19236,  -- Desperate Prayer
                33206,  -- Pain Suppression; from the 2026-09-24 combat logs; owner review placed it here, not in Support
            },
            DEATHKNIGHT = {
                48792,  -- Icebound Fortitude
                48707,  -- Anti-Magic Shell
                55233,  -- Vampiric Blood
                49039,  -- Lichborne
            },
            SHAMAN = {
                108271, -- Astral Shift
            },
            MAGE = {
                45438,  -- Ice Block
                342246, -- Alter Time
                235450, -- Prismatic Barrier; added from the 2026-09-24 combat logs
                11426,  -- Ice Barrier; added from the 2026-09-24 combat logs
                414658, -- Ice Cold; added from the 2026-09-24 combat logs
                235313, -- Blazing Barrier; added from the 2026-09-24 combat logs
            },
            WARLOCK = {
                104773, -- Unending Resolve
                108416, -- Dark Pact
            },
            MONK = {
                120954, -- Fortifying Brew
                122278, -- Dampen Harm
                122783, -- Diffuse Magic
                125174, -- Touch of Karma
                122470, -- Touch of Karma; the aura id the 2026-09-24 combat logs show
                132578, -- Invoke Niuzao, the Black Ox; added from the 2026-09-24 combat logs
                116849, -- Life Cocoon; from the 2026-09-24 combat logs; owner review placed it here, not in Support
            },
            DRUID = {
                22812,  -- Barkskin
                61336,  -- Survival Instincts
                102342, -- Ironbark; from the 2026-09-24 combat logs; owner review placed it here, not in Support
            },
            -- Metamorphosis (162264, 187827) is Offensive cooldowns only (owner 2026-09-25)
            DEMONHUNTER = {
                212800, -- Blur
                196555, -- Netherwalk
                207771, -- Fiery Brand; added from the 2026-09-24 combat logs
            },
            EVOKER = {
                363916, -- Obsidian Scales
                374349, -- Renewing Blaze; the aura id the 2026-09-24 combat logs show; replaces 374348
                357170, -- Time Dilation; from the 2026-09-24 combat logs; owner review placed it here, not in Support
            },
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
        -- Owner 2026-09-25: Blood Shield (77535), Shuffle (215479) and Rushing Jade Wind (116847) are
        -- not active mitigation, so Monk has no entry here.
        spells = spells({
            WARRIOR = {
                132404, -- Shield Block
                190456, -- Ignore Pain
            },
            PALADIN = {
                132403, -- Shield of the Righteous
            },
            DEATHKNIGHT = {
                195181, -- Bone Shield
            },
            DRUID = {
                192081, -- Ironfur
            },
            DEMONHUNTER = {
                203819, -- Demon Spikes
            },
        }),
    },
    {
        key = "raidCDs", kind = "spells", label = "Raid cooldowns",
        desc = "Group-wide cooldowns and haste effects.",
        spells = spells({
            ALL = {
                1243972, -- Void-touched Drums; a Bloodlust variant (owner 2026-09-25); drums any class can use; added from the 2026-09-24 combat logs
                444257,  -- Thunderous Drums; a Bloodlust variant (owner 2026-09-25); last expansion's drums, seen in the logs
            },
            WARRIOR = {
                97463,   -- Rallying Cry
            },
            PALADIN = {
                31821,   -- Aura Mastery
            },
            DEATHKNIGHT = {
                145629,  -- Anti-Magic Zone
            },
            DRUID = {
                740,     -- Tranquility; a raid cooldown (owner 2026-09-25); from the 2026-09-24 combat logs; owner review placed it here, not in Defensive cooldowns
            },
            DEMONHUNTER = {
                209426,  -- Darkness
            },
            PRIEST = {
                81782,   -- Power Word: Barrier
            },
            SHAMAN = {
                2825,    -- Bloodlust; a Bloodlust variant (owner 2026-09-25)
                32182,   -- Heroism; a Bloodlust variant (owner 2026-09-25)
                325174,  -- Spirit Link Totem; the aura; 98007 is the cast (issue #15)
            },
            MAGE = {
                80353,   -- Time Warp; a Bloodlust variant (owner 2026-09-25)
            },
            HUNTER = {
                264667,  -- Primal Rage; a Bloodlust variant (owner 2026-09-25); the pet ability
                466904,  -- Harrier's Cry; a Bloodlust variant (owner 2026-09-25); added from the 2026-09-24 combat logs
            },
            EVOKER = {
                390386,  -- Fury of the Aspects; a Bloodlust variant (owner 2026-09-25)
                374227,  -- Zephyr; also in Movement (owner 2026-09-25)
            },
        }),
    },
    {
        key = "offensiveCDs", kind = "spells", label = "Offensive cooldowns",
        desc = "Damage cooldowns.",
        spells = spells({
            WARRIOR = {
                1719,    -- Recklessness
                107574,  -- Avatar
                436358,  -- Demolish; from the 2026-09-24 combat logs; owner review placed it here, not in Defensive cooldowns
            },
            PALADIN = {
                31884,   -- Avenging Wrath
                454351,  -- Avenging Wrath; the aura id the 2026-09-24 combat logs show; replaces 231895
            },
            DEATHKNIGHT = {
                51271,   -- Pillar of Frost
                207289,  -- Unholy Assault
            },
            WARLOCK = {
                1276767, -- Tyrant's Oblation; added from the 2026-09-24 combat logs
            },
            DRUID = {
                194223,  -- Celestial Alignment
                102560,  -- Incarnation: Chosen of Elune
                106951,  -- Berserk
                102543,  -- Incarnation: Avatar of Ashamane
                252071,  -- Incarnation: Avatar of Ashamane; the aura id the 2026-09-24 combat logs show
            },
            HUNTER = {
                288613,  -- Trueshot
                19574,   -- Bestial Wrath
                360952,  -- Coordinated Assault
                186254,  -- Bestial Wrath; the aura id the 2026-09-24 combat logs show
                1235388, -- Bestial Wrath; the aura id the 2026-09-24 combat logs show
                1285912, -- Bestial Wrath; the aura id the 2026-09-24 combat logs show
            },
            MAGE = {
                190319,  -- Combustion
                12472,   -- Icy Veins
                365362,  -- Arcane Surge
            },
            ROGUE = {
                121471,  -- Shadow Blades
                13750,   -- Adrenaline Rush
                185422,  -- Shadow Dance
            },
            DEMONHUNTER = {
                162264,  -- Metamorphosis; Havoc; Offensive cooldowns only (owner 2026-09-25)
                187827,  -- Metamorphosis; Vengeance; Offensive cooldowns only (owner 2026-09-25); the aura id the 2026-09-24 combat logs show
            },
            PRIEST = {
                194249,  -- Voidform
                373316,  -- Idol of Y'Shaarj; added from the 2026-09-24 combat logs
            },
            MONK = {
                137639,  -- Storm, Earth, and Fire
            },
            SHAMAN = {
                114051,  -- Ascendance
                114052,  -- Ascendance; the aura id the 2026-09-24 combat logs show
                1219480, -- Ascendance; the aura id the 2026-09-24 combat logs show
            },
            EVOKER = {
                375087,  -- Dragonrage
                431698,  -- Temporal Burst; added from the 2026-09-24 combat logs
            },
        }),
    },
    {
        -- One list since schema v2: the former coreHealing and lesserHealing, united (core/Database.lua's
        -- MigrateV2 merges a player's edits and category states of the two).
        key = "healing", kind = "spells", label = "Healing",
        desc = "Heal-over-time effects, shields and beacons.",
        spells = spells({
            DRUID = {
                774,     -- Rejuvenation
                8936,    -- Regrowth
                33763,   -- Lifebloom
                48438,   -- Wild Growth
                102352,  -- Cenarion Ward
                155777,  -- Rejuvenation (Germination)
                207386,  -- Spring Blossoms
                1227806, -- Lifebloom; the aura id the 2026-09-24 combat logs show
            },
            PRIEST = {
                139,     -- Renew
                17,      -- Power Word: Shield
                194384,  -- Atonement
                41635,   -- Prayer of Mending
                1246768, -- Power Word: Shield; the aura id the 2026-09-24 combat logs show
                77489,   -- Echo of Light; added from the 2026-09-24 combat logs
                1253593, -- Void Shield; from the 2026-09-24 combat logs; owner review placed it here, not in Support
            },
            SHAMAN = {
                61295,   -- Riptide
                974,     -- Earth Shield
                383648,  -- Earth Shield; the aura id the 2026-09-24 combat logs show
                382024,  -- Earthliving Weapon; added from the 2026-09-24 combat logs
            },
            MONK = {
                119611,  -- Renewing Mist
                124682,  -- Enveloping Mist
                115175,  -- Soothing Mist
                1260617, -- Soothing Mist; the aura id the 2026-09-24 combat logs show
                443113,  -- Strength of the Black Ox; from the 2026-09-24 combat logs; owner review placed it here, not in Raid cooldowns
                406220,  -- Chi Cocoon; from the 2026-09-24 combat logs; owner review placed it here, not in Raid cooldowns
                1260681, -- Chi Cocoon; from the 2026-09-24 combat logs; owner review placed it here, not in Raid cooldowns
            },
            EVOKER = {
                364343,  -- Echo
                366155,  -- Reversion
                367364,  -- Reversion; the aura id the 2026-09-24 combat logs show
                373862,  -- Temporal Anomaly; from the 2026-09-24 combat logs; owner review placed it here, not in Raid cooldowns
                355941,  -- Dream Breath; from the 2026-09-24 combat logs; owner review placed it here, not in Raid cooldowns
                1291636, -- Temporal Barrier; from the 2026-09-24 combat logs; owner review placed it here, not in Raid cooldowns
                376788,  -- Dream Breath; from the 2026-09-24 combat logs; owner review placed it here, not in Raid cooldowns
                409895,  -- Verdant Embrace; from the 2026-09-24 combat logs; owner review placed it here, not in Raid cooldowns
                409678,  -- Chrono Ward; from the 2026-09-24 combat logs; owner review placed it here, not in Raid cooldowns
                363534,  -- Rewind; from the 2026-09-24 combat logs; owner review placed it here, not in Raid cooldowns
                373267,  -- Lifebind; from the 2026-09-24 combat logs; owner review placed it here, not in Support
            },
            PALADIN = {
                53563,   -- Beacon of Light
                156910,  -- Beacon of Faith
                200025,  -- Beacon of Virtue
                287280,  -- Glimmer of Light
                1245369, -- Beacon of the Savior; from the 2026-09-24 combat logs; owner review placed it here, not in Support
                1244893, -- Beacon of the Savior; from the 2026-09-24 combat logs; owner review placed it here, not in Support
                156322,  -- Eternal Flame; from the 2026-09-24 combat logs; owner review placed it here, not in Support
            },
        }),
    },
    {
        key = "support", kind = "spells", label = "Support",
        desc = "Buffs cast on other players.",
        spells = spells({
            HUNTER = {
                34477,   -- Misdirection; added from the 2026-09-24 combat logs
            },
            ROGUE = {
                57934,   -- Tricks of the Trade; added from the 2026-09-24 combat logs
                115834,  -- Shroud of Concealment; added from the 2026-09-24 combat logs
                1224098, -- Tricks of the Trade; added from the 2026-09-24 combat logs
            },
            DEATHKNIGHT = {
                454863,  -- Lesser Anti-Magic Shell; added from the 2026-09-24 combat logs
                474754,  -- Symbiotic Relationship; added from the 2026-09-24 combat logs
            },
            -- Void Shield (Unfolding Vision) 1300009 removed (owner 2026-09-25)
            PRIEST = {
                10060,   -- Power Infusion; moved here from Offensive cooldowns (owner review 2026-09-25)
            },
            DRUID = {
                29166,   -- Innervate
                474750,  -- Symbiotic Relationship; added from the 2026-09-24 combat logs
            },
            EVOKER = {
                369459,  -- Source of Magic
                413984,  -- Shifting Sands; added from the 2026-09-24 combat logs
                360827,  -- Blistering Scales; added from the 2026-09-24 combat logs
                375253,  -- Time Spiral; the Paladin buff; one aura per class; added from the 2026-09-24 combat logs
                375230,  -- Time Spiral; the Druid buff; one aura per class; added from the 2026-09-24 combat logs
                375226,  -- Time Spiral; the Death Knight buff; one aura per class; added from the 2026-09-24 combat logs
                375229,  -- Time Spiral; the Demon Hunter buff; one aura per class; added from the 2026-09-24 combat logs
                375257,  -- Time Spiral; the Warlock buff; one aura per class; added from the 2026-09-24 combat logs
                406789,  -- Spatial Paradox; added from the 2026-09-24 combat logs
                375256,  -- Time Spiral; the Shaman buff; one aura per class; added from the 2026-09-24 combat logs
                375234,  -- Time Spiral; the Evoker buff; one aura per class
                375238,  -- Time Spiral; the Hunter buff; one aura per class
                375240,  -- Time Spiral; the Mage buff; one aura per class
                375252,  -- Time Spiral; the Monk buff; one aura per class
                375254,  -- Time Spiral; the Priest buff; one aura per class
                375255,  -- Time Spiral; the Rogue buff; one aura per class
                375258,  -- Time Spiral; the Warrior buff; one aura per class
            },
        }),
    },
    {
        -- Split out of Support (owner 2026-09-25): the raid-wide buffs every group member carries.
        -- Blessing of the Bronze has one aura per class; the ids are the ones the 2026-09-24 combat
        -- logs saw (docs/spell-research/2026-09-24-logs).
        key = "groupBuffs", kind = "spells", label = "Group buffs",
        desc = "Raid-wide buffs such as Mark of the Wild, Arcane Intellect and Battle Shout.",
        spells = spells({
            MAGE = {
                1459,   -- Arcane Intellect
            },
            PRIEST = {
                21562,  -- Power Word: Fortitude
            },
            WARRIOR = {
                6673,   -- Battle Shout
            },
            DRUID = {
                1126,   -- Mark of the Wild
            },
            SHAMAN = {
                462854, -- Skyfury
            },
            EVOKER = {
                381748, -- Blessing of the Bronze; the Evoker buff; one aura per class
                381732, -- Blessing of the Bronze; the Death Knight buff; one aura per class
                381741, -- Blessing of the Bronze; the Demon Hunter buff; one aura per class
                381746, -- Blessing of the Bronze; the Druid buff; one aura per class
                381749, -- Blessing of the Bronze; the Hunter buff; one aura per class
                381750, -- Blessing of the Bronze; the Mage buff; one aura per class
                381751, -- Blessing of the Bronze; the Monk buff; one aura per class
                381752, -- Blessing of the Bronze; the Paladin buff; one aura per class
                381753, -- Blessing of the Bronze; the Priest buff; one aura per class
                381754, -- Blessing of the Bronze; the Rogue buff; one aura per class
                381756, -- Blessing of the Bronze; the Shaman buff; one aura per class
                381757, -- Blessing of the Bronze; the Warlock buff; one aura per class
                381758, -- Blessing of the Bronze; the Warrior buff; one aura per class
            },
        }),
    },
    {
        key = "movement", kind = "spells", label = "Movement",
        desc = "Speed and freedom effects.",
        spells = spells({
            WARRIOR = {
                202164,  -- Bounding Stride; added from the 2026-09-24 combat logs
                446044,  -- Relentless Pursuit; added from the 2026-09-24 combat logs
                1244157, -- Piercing Howl; added from the 2026-09-24 combat logs
            },
            ROGUE = {
                2983,    -- Sprint
                36554,   -- Shadowstep; added from the 2026-09-24 combat logs
            },
            DEATHKNIGHT = {
                48265,   -- Death's Advance; added from the 2026-09-24 combat logs
                444347,  -- Death Charge; added from the 2026-09-24 combat logs
                434029,  -- Vampiric Speed; added from the 2026-09-24 combat logs
                212552,  -- Wraith Walk; added from the 2026-09-24 combat logs
            },
            -- Travel and Mount Form are Stances (owner 2026-09-25)
            DRUID = {
                1850,    -- Dash
                106898,  -- Stampeding Roar
                77761,   -- Stampeding Roar; the aura id the 2026-09-24 combat logs show
                77764,   -- Stampeding Roar; the aura id the 2026-09-24 combat logs show
                400126,  -- Forestwalk; added from the 2026-09-24 combat logs
                252216,  -- Tiger Dash; added from the 2026-09-24 combat logs
            },
            PALADIN = {
                1044,    -- Blessing of Freedom
                221886,  -- Divine Steed; Thalassian Charger (Blood Elf; Horde Glyph of the Trusted Steed)
                221883,  -- Divine Steed; default Charger (Human and unlisted races; Alliance Glyph of the Trusted Steed); the aura id the 2026-09-24 combat logs show
                221885,  -- Divine Steed; Great Sunwalker Kodo (Tauren); the aura id the 2026-09-24 combat logs show
                221887,  -- Divine Steed; Great Exarch's Elekk (Draenei); the aura id the 2026-09-24 combat logs show
                254471,  -- Divine Steed; Highlord's Valorous Charger (bridle); the aura id the 2026-09-24 combat logs show
                254472,  -- Divine Steed; Highlord's Vengeful Charger (bridle); the aura id the 2026-09-24 combat logs show
                254473,  -- Divine Steed; Highlord's Vigilant Charger (bridle)
                254474,  -- Divine Steed; Highlord's Golden Charger (bridle); the aura id the 2026-09-24 combat logs show
                276111,  -- Divine Steed; Dawnforge Ram (Dwarf); the aura id the 2026-09-24 combat logs show
                276112,  -- Divine Steed; Darkforge Ram (Dark Iron Dwarf); the aura id the 2026-09-24 combat logs show
                294133,  -- Divine Steed; Crusader's Direhorn (Zandalari Troll); the aura id the 2026-09-24 combat logs show
                363608,  -- Divine Steed; Lightforged Ruinstrider (Lightforged Draenei); the aura id the 2026-09-24 combat logs show
                453804,  -- Divine Steed; Earthen Ordinant's Ramolith (Earthen); the aura id the 2026-09-24 combat logs show
                1289616, -- Divine Steed; pre-12.0.1 Charger model; in the 12.1 data, not yet seen in logs
                1289617, -- Divine Steed; pre-12.0.1 Thalassian Charger model; in the 12.1 data, not yet seen in logs
                394454,  -- Echoing Freedom; added from the 2026-09-24 combat logs
            },
            MONK = {
                116841,  -- Tiger's Lust
                443569,  -- Chi-Ji's Swiftness; added from the 2026-09-24 combat logs
                450552,  -- Jade Walk; added from the 2026-09-24 combat logs
                119085,  -- Chi Torpedo; added from the 2026-09-24 combat logs
            },
            HUNTER = {
                186257,  -- Aspect of the Cheetah
                186258,  -- Aspect of the Cheetah; the aura id the 2026-09-24 combat logs show
            },
            SHAMAN = {
                192082,  -- Wind Rush
                79206,   -- Spiritwalker's Grace
                2645,    -- Ghost Wolf
                260881,  -- Spirit Wolf; from the 2026-09-24 combat logs; owner review placed it here, not in Defensive cooldowns
                454025,  -- Electroshock; added from the 2026-09-24 combat logs
                58875,   -- Spirit Walk; added from the 2026-09-24 combat logs
                468226,  -- Lightning Conduit; added from the 2026-09-24 combat logs
            },
            PRIEST = {
                121557,  -- Angelic Feather
                65081,   -- Body and Soul
                73325,   -- Leap of Faith; from the 2026-09-24 combat logs; owner review placed it here, not in Support
            },
            WARLOCK = {
                111400,  -- Burning Rush
                387633,  -- Soulburn: Demonic Circle; added from the 2026-09-24 combat logs
            },
            EVOKER = {
                358267,  -- Hover
                374227,  -- Zephyr; also in Raid cooldowns: the review moved it here, the owner kept it in both (2026-09-25)
                442204,  -- Breath of Eons; added from the 2026-09-24 combat logs
            },
        }),
    },
    {
        key = "utility", kind = "spells", label = "Utility",
        desc = "Soulstones, stealth, water walking and similar.",
        spells = spells({
            WARLOCK = {
                20707,  -- Soulstone
                5697,   -- Unending Breath
            },
            PRIEST = {
                111759, -- Levitate; the aura; 1706 is the cast (issue #15)
            },
            SHAMAN = {
                546,    -- Water Walking
            },
            MAGE = {
                130,    -- Slow Fall
                32612,  -- Invisibility
            },
            HUNTER = {
                5384,   -- Feign Death
            },
            ROGUE = {
                1784,   -- Stealth
            },
            DRUID = {
                5215,   -- Prowl
            },
        }),
    },
    {
        -- Owner 2026-09-25. Travel Form and Mount Form are here only, not in Movement; Ghost Wolf stays
        -- in Movement.
        key = "stances", kind = "spells", label = "Stances",
        desc = "Warrior stances, druid forms and paladin auras.",
        spells = spells({
            WARRIOR = {
                386164, -- Battle Stance
                386196, -- Berserker Stance
                386208, -- Defensive Stance
            },
            DRUID = {
                5487,   -- Bear Form
                768,    -- Cat Form
                24858,  -- Moonkin Form
                114282, -- Treant Form
                165961, -- Travel Form; Stances only, not Movement (owner 2026-09-25)
                1066,   -- Travel Form; an alternate Travel Form aura, seen in the 2026-09-24 logs
                40120,  -- Travel Form; an alternate Travel Form aura, seen in the 2026-09-24 logs
                210053, -- Mount Form; Stances only, not Movement (owner 2026-09-25)
            },
            PALADIN = {
                465,    -- Devotion Aura
                317920, -- Concentration Aura
                32223,  -- Crusader Aura
            },
            PRIEST = {
                232698, -- Shadowform; owner 2026-09-25
            },
        }),
    },
    {
        -- Owner 2026-09-25. The buffs of the DB2 "Racial - <race>" skill lines' active abilities and
        -- procs (build 12.1.0.69875), passives left out; every id here but four was seen as a player
        -- buff in the 2026-09-24 combat logs (not seen: 28880, 121093, 370626 Gift of the Naaru and
        -- 281954 Pterrordax Swoop). The racial DEBUFFS are the debuff list `racialDebuffs` below.
        key = "racials", kind = "spells", label = "Racials",
        desc = "Buffs from racial abilities, such as Stoneform, Berserking and Blood Fury.",
        spells = spells({
            ALL = {
                65116,   -- Stoneform; Dwarf
                26297,   -- Berserking; Troll
                20572,   -- Blood Fury; Orc; attack power
                33697,   -- Blood Fury; Orc; attack and spell power
                33702,   -- Blood Fury; Orc; spell power
                274739,  -- Rictus of the Laughing Skull; Mag'har Orc
                274740,  -- Zeal of the Burning Blade; Mag'har Orc
                274741,  -- Ferocity of the Frostwolf; Mag'har Orc
                274742,  -- Might of the Blackrock; Mag'har Orc
                273104,  -- Fireblood; Dark Iron Dwarf
                58984,   -- Shadowmeld; Night Elf; moved here from Utility (owner 2026-09-25)
                28880,   -- Gift of the Naaru; Draenei Warrior; one aura per class
                59542,   -- Gift of the Naaru; Draenei Paladin; one aura per class
                59543,   -- Gift of the Naaru; Draenei Hunter; one aura per class
                59544,   -- Gift of the Naaru; Draenei Priest; one aura per class
                59545,   -- Gift of the Naaru; Draenei Death Knight; one aura per class
                59547,   -- Gift of the Naaru; Draenei Shaman; one aura per class
                59548,   -- Gift of the Naaru; Draenei Mage; one aura per class
                121093,  -- Gift of the Naaru; Draenei Monk; one aura per class
                370626,  -- Gift of the Naaru; Draenei Rogue; one aura per class
                416250,  -- Gift of the Naaru; Draenei Warlock; one aura per class
                7744,    -- Will of the Forsaken; Undead
                59752,   -- Will to Survive; Human
                68992,   -- Darkflight; Worgen
                87840,   -- Running Wild; Worgen
                406087,  -- Calm the Wolf; Worgen (owner 2026-09-25)
                360022,  -- Chosen Identity; Dracthyr (owner 2026-09-25)
                1289789, -- Battle Visage; Dracthyr (owner 2026-09-25)
                256948,  -- Spatial Rift; Void Elf
                256374,  -- Entropic Embrace; Void Elf; a frequent proc, kept (owner 2026-09-25)
                291944,  -- Regeneratin'; Zandalari Troll
                281954,  -- Pterrordax Swoop; Zandalari Troll; not yet seen in logs
                255654,  -- Bull Rush; Highmountain Tauren
                291843,  -- Brush It Off; Kul Tiran
                436344,  -- Azerite Surge; Earthen
                461063,  -- Quiet Contemplation; Earthen
                1238467, -- Thorn Bloom; Haranir; a frequent proc, kept (owner 2026-09-25)
            },
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
-- surface that can mislead says so: their own descs below, the Filters section's Categories tab, the
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
            WARRIOR = {
                5246,    -- Intimidating Shout
                132168,  -- Shockwave
                132169,  -- Storm Bolt
                385954,  -- Shield Charge
            },
            PALADIN = {
                853,     -- Hammer of Justice
                10326,   -- Turn Evil
                105421,  -- Blinding Light
            },
            HUNTER = {
                1513,    -- Scare Beast
                3355,    -- Freezing Trap
                24394,   -- Intimidation
                117526,  -- Binding Shot
                213691,  -- Scatter Shot
                1258508, -- Intimidation; the aura id the 2026-09-24 combat logs show
            },
            ROGUE = {
                408,     -- Kidney Shot
                1776,    -- Gouge
                1833,    -- Cheap Shot
                2094,    -- Blind
                6770,    -- Sap
                427773,  -- Blind; the aura id the 2026-09-24 combat logs show
            },
            PRIEST = {
                605,     -- Mind Control
                8122,    -- Psychic Scream
                9484,    -- Shackle Horror
                64044,   -- Psychic Horror
                200200,  -- Holy Word: Chastise
                205364,  -- Dominate Mind
                200196,  -- Holy Word: Chastise; the aura id the 2026-09-24 combat logs show
            },
            DEATHKNIGHT = {
                108194,  -- Asphyxiate; Frost and Unholy
                111673,  -- Control Undead
                207167,  -- Blinding Sleet
                221562,  -- Asphyxiate; Blood
            },
            SHAMAN = {
                51514,   -- Hex
                118905,  -- Capacitor Totem
                204437,  -- Lightning Lasso
            },
            MAGE = {
                118,     -- Polymorph
                31661,   -- Dragon's Breath
                82691,   -- Ring of Frost
                383121,  -- Mass Polymorph
            },
            WARLOCK = {
                710,     -- Banish
                1098,    -- Subjugate Demon
                5484,    -- Howl of Terror
                118699,  -- Fear; the aura; 5782 is the cast
                6789,    -- Mortal Coil
                30283,   -- Shadowfury
            },
            MONK = {
                115078,  -- Paralysis
                119381,  -- Leg Sweep
                198909,  -- Song of Chi-Ji
            },
            DRUID = {
                99,      -- Incapacitating Roar
                2637,    -- Hibernate
                5211,    -- Mighty Bash
                33786,   -- Cyclone
                163505,  -- Rake
                203123,  -- Maim
            },
            DEMONHUNTER = {
                179057,  -- Chaos Nova
                207685,  -- Sigil of Misery
                211881,  -- Fel Eruption
                217832,  -- Imprison
                1234195, -- Void Nova
            },
            EVOKER = {
                360806,  -- Sleep Walk
                372245,  -- Terror of the Skies
            },
            ALL = {
                20549,   -- War Stomp; racial (Tauren); also in Racials (debuffs)
                107079,  -- Quaking Palm; racial (Pandaren); also in Racials (debuffs)
                287712,  -- Haymaker; racial (Kul Tiran); also in Racials (debuffs)
            },
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
            WARRIOR = {
                1715,    -- Hamstring
                12323,   -- Piercing Howl
            },
            PALADIN = {
                403695,  -- Truth's Wake
                408383,  -- Judgment of Justice
            },
            HUNTER = {
                5116,    -- Concussive Shot
                64803,   -- Entrapment
                135299,  -- Tar Trap
                162480,  -- Steel Trap
                186387,  -- Bursting Shot
                190925,  -- Harpoon
                195645,  -- Wing Clip
            },
            -- 35546 IS THE CAST AND ITS AURA IS UNKNOWN (issue #15). It applies no aura of its
            -- own and has no EffectTriggerSpell edge, so the data cannot name one; the owner's
            -- live probe could not observe one either, reporting it as a proc that fires and
            -- vanishes rather than an aura that sits on a unit. It is left as the cast id
            -- KNOWINGLY: a row that matches nothing is no worse than a row that is gone, and
            -- removing it would lose the record that this slow exists. Settle it by watching a
            -- real target while an Outlaw rogue has the talent, then swap in what lands.
            ROGUE = {
                3409,    -- Crippling Poison
                35546,   -- Fatal Flourish; the CAST; its aura is unknown (see above)
                185763,  -- Pistol Shot
            },
            PRIEST = {
                15407,   -- Mind Flay
                114404,  -- Void Tendrils
                390669,  -- Apathy
            },
            DEATHKNIGHT = {
                45524,   -- Chains of Ice
                206930,  -- Heart Strike
                273977,  -- Grip of the Dead
                444826,  -- Chains of Ice; the aura id the 2026-09-24 combat logs show
                460501,  -- Heart Strike; the aura id the 2026-09-24 combat logs show
            },
            SHAMAN = {
                51490,   -- Thunderstorm
                196840,  -- Frost Shock
                470194,  -- Ice Strike
                1251059, -- Stormbind
            },
            MAGE = {
                122,     -- Frost Nova
                31589,   -- Slow
                157981,  -- Blast Wave
                157997,  -- Ice Nova
                212792,  -- Cone of Cold
                236299,  -- Chrono Shift
                378760,  -- Frostbite
                391104,  -- Mass Slow
            },
            WARLOCK = {
                334275,  -- Curse of Exhaustion
                384069,  -- Shadowflame
            },
            MONK = {
                116095,  -- Disable
                121253,  -- Keg Smash
                123586,  -- Flying Serpent Kick
                324382,  -- Clash
                392983,  -- Strike of the Windlord
                116706,  -- Disable; the aura id the 2026-09-24 combat logs show
            },
            DRUID = {
                339,     -- Entangling Roots
                58180,   -- Infected Wounds
                61391,   -- Typhoon
                102359,  -- Mass Entanglement
                127797,  -- Ursol's Vortex; the aura; 102793 is the cast
                164812,  -- Moonfire
            },
            DEMONHUNTER = {
                198813,  -- Vengeful Retreat
                204843,  -- Sigil of Chains
                213405,  -- Master of the Glaive
                370970,  -- The Hunt; the aura id the 2026-09-24 combat logs show; replaces 323996
            },
            EVOKER = {
                355689,  -- Landslide
                357214,  -- Wing Buffet; racial (Dracthyr); also in Racials (debuffs)
                368970,  -- Tail Swipe; racial (Dracthyr); also in Racials (debuffs)
                370898,  -- Permeating Chill
            },
            ALL = {
                260369,  -- Arcane Pulse; racial (Nightborne); also in Racials (debuffs)
            },
        }),
    },
    {
        -- Owner 2026-09-25: the debuffs of the DB2 "Racial - <race>" skill lines, every one seen in the
        -- 2026-09-24 combat logs. They stay in Hard CC and Soft CC as well; this list only groups them.
        -- Mechagnome's Recently Failed (313015) is left out: a lockout on yourself, where Blizzard
        -- discards a debuff spell list anyway. A key of its own, not `racials`: a key names one
        -- category across both aura types (`Cat.AuraTypeOf`).
        key = "racialDebuffs", kind = "spells", label = "Racials",
        desc = "Debuffs from racial abilities, such as War Stomp and Quaking Palm. Only works on a hostile target or focus: Blizzard discards spell lists for debuffs on you or on a friendly unit.",
        spells = spells({
            ALL = {
                20549,   -- War Stomp; Tauren
                107079,  -- Quaking Palm; Pandaren
                287712,  -- Haymaker; Kul Tiran
                260369,  -- Arcane Pulse; Nightborne
                357214,  -- Wing Buffet; Dracthyr
                368970,  -- Tail Swipe; Dracthyr
                255723,  -- Bull Rush; Highmountain Tauren
                1238474, -- Thorn Bloom; Haranir
            },
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
        -- Restored 2026-09-16, asymmetric with the buff row — see the KINDS doc above.
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
