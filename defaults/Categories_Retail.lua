local _, NS = ...

-- defaults/Categories_Retail.lua — Retail's seed lists for the `spells` categories (clients-§5).
--
-- WHAT THIS IS. One list per `kind = "spells"` category of defaults/Categories.lua, by class:
-- NS.CategorySeedsRetail[key] = { CLASS = { id, ... } }. defaults/Categories.lua defines the
-- categories (key, label, description, order) and picks this file's lists on Retail and
-- defaults/Categories_Forever*.lua's on WoW Forever, once at load. This file never touches
-- NS.Categories. The ids are AURA ids: the filter matches the id of the aura on the unit, not the
-- cast (tools/spell-research/README.md, "The crux").
--
-- HAND-CURATED, TOOL-CHECKED. Unlike the Forever files this one is not generated: the comments
-- carry the owner's rulings and the reason each id is here. Three tools read and write it, and only
-- in the shape below:
--   tools/spell-research/research.py   --diff, --check-shipped (reads)
--   tools/spell-research/retail.py     the wago.tools re-validation; `apply` inserts accepted ids
--   tools/spell-research/logs.py       the combat-log review; `apply`/`ingest` edit class tables
-- Rulings live in tools/spell-research/retail_rulings.json and decisions.json; the dated bundles
-- under docs/spell-research/ are the evidence.
--
-- THE SHAPE THE TOOLS ANCHOR ON. Each list opens on a line of its own,
--     seed("<key>", "<HELPFUL|HARMFUL>", {
-- and closes on the first line after it that starts with `})`. Inside, one table per class and ONE
-- ID PER LINE, the comment giving the spell's name, then any context after a `;`. Ids are only ever
-- read from code, never from a comment. The aura type on the opening line must match the list the
-- category sits in (Cat.HELPFUL or Cat.HARMFUL); tests/test_categories_clients.lua checks it.

local SEEDS = {}
NS.CategorySeedsRetail = SEEDS

--- Record one category's Retail list. The aura type is for the tools and the test; the runtime
--- takes it from where defaults/Categories.lua declares the category.
local function seed(key, _auraType, list)
    SEEDS[key] = list
end

-- Defensive cooldowns (Cat.HELPFUL)
seed("defensives", "HELPFUL", {
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
        47788,  -- Guardian Spirit; added from the 2026-11-15 wago.tools re-validation (12.1.5.70783)
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
        22842,  -- Frenzied Regeneration; added from the 2026-11-15 wago.tools re-validation (12.1.5.70783)
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
})

-- Active mitigation (Cat.HELPFUL)
seed("activeMitigation", "HELPFUL", {
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
})

-- Raid cooldowns (Cat.HELPFUL)
seed("raidCDs", "HELPFUL", {
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
})

-- Offensive cooldowns (Cat.HELPFUL)
seed("offensiveCDs", "HELPFUL", {
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
        442726,  -- Malevolence; added from the 2026-11-15 wago.tools re-validation (12.1.5.70783)
    },
    DRUID = {
        194223,  -- Celestial Alignment
        102560,  -- Incarnation: Chosen of Elune
        106951,  -- Berserk
        102543,  -- Incarnation: Avatar of Ashamane
        252071,  -- Incarnation: Avatar of Ashamane; the aura id the 2026-09-24 combat logs show
        50334,   -- Berserk; added from the 2026-11-15 wago.tools re-validation (12.1.5.70783)
        102558,  -- Incarnation: Guardian of Ursoc; added from the 2026-11-15 wago.tools re-validation (12.1.5.70783)
    },
    HUNTER = {
        288613,  -- Trueshot
        19574,   -- Bestial Wrath
        360952,  -- Coordinated Assault
        186254,  -- Bestial Wrath; the aura id the 2026-09-24 combat logs show
        1235388, -- Bestial Wrath; the aura id the 2026-09-24 combat logs show
        1285912, -- Bestial Wrath; the aura id the 2026-09-24 combat logs show
        1250646, -- Takedown; added from the 2026-11-15 wago.tools re-validation (12.1.5.70783)
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
        123904,  -- Invoke Xuen, the White Tiger; added from the 2026-11-15 wago.tools re-validation (12.1.5.70783)
    },
    SHAMAN = {
        114051,  -- Ascendance
        114052,  -- Ascendance; the aura id the 2026-09-24 combat logs show
        1219480, -- Ascendance; the aura id the 2026-09-24 combat logs show
        191634,  -- Stormkeeper; added from the 2026-11-15 wago.tools re-validation (12.1.5.70783)
    },
    EVOKER = {
        375087,  -- Dragonrage
        431698,  -- Temporal Burst; added from the 2026-09-24 combat logs
    },
})

-- Healing (Cat.HELPFUL)
seed("healing", "HELPFUL", {
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
})

-- Support (Cat.HELPFUL)
seed("support", "HELPFUL", {
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
})

-- Group buffs (Cat.HELPFUL)
seed("groupBuffs", "HELPFUL", {
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
})

-- Movement (Cat.HELPFUL)
seed("movement", "HELPFUL", {
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
})

-- Utility (Cat.HELPFUL)
seed("utility", "HELPFUL", {
    DEATHKNIGHT = {
        3714,   -- Path of Frost; added from the 2026-11-15 wago.tools re-validation (12.1.5.70783)
    },
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
        110960, -- Greater Invisibility; added from the 2026-11-15 wago.tools re-validation (12.1.5.70783)
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
})

-- Stances (Cat.HELPFUL)
seed("stances", "HELPFUL", {
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
})

-- Racials (Cat.HELPFUL)
seed("racials", "HELPFUL", {
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
})

-- CC Loss of Control (Cat.HARMFUL)
seed("hardCC", "HARMFUL", {
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
})

-- CC Root (Cat.HARMFUL)
seed("ccRoot", "HARMFUL", {
    HUNTER = {
        64803,   -- Entrapment
        162480,  -- Steel Trap
        190925,  -- Harpoon
    },
    PRIEST = {
        114404,  -- Void Tendrils
    },
    SHAMAN = {
        64695,   -- Earthgrab; the aura of Earthgrab Totem; added by hand, owner 2026-10-04
    },
    MAGE = {
        122,     -- Frost Nova
        157997,  -- Ice Nova
        378760,  -- Frostbite
    },
    MONK = {
        324382,  -- Clash
        116706,  -- Disable; the aura id the 2026-09-24 combat logs show
    },
    DRUID = {
        339,     -- Entangling Roots
        102359,  -- Mass Entanglement
    },
    DEMONHUNTER = {
        370970,  -- The Hunt; the aura id the 2026-09-24 combat logs show; replaces 323996
    },
    EVOKER = {
        355689,  -- Landslide
    },
})

-- CC Snare (Cat.HARMFUL)
seed("ccSnare", "HARMFUL", {
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
        135299,  -- Tar Trap
        186387,  -- Bursting Shot
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
        3600,    -- Earthbind; the aura of Earthbind Totem (2484); added by hand, owner 2026-10-04
        1251059, -- Stormbind
    },
    MAGE = {
        31589,   -- Slow
        157981,  -- Blast Wave
        212792,  -- Cone of Cold
        236299,  -- Chrono Shift
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
        392983,  -- Strike of the Windlord
    },
    DRUID = {
        58180,   -- Infected Wounds
        61391,   -- Typhoon
        127797,  -- Ursol's Vortex; the aura; 102793 is the cast
        164812,  -- Moonfire
    },
    DEMONHUNTER = {
        198813,  -- Vengeful Retreat
        204843,  -- Sigil of Chains
        213405,  -- Master of the Glaive
    },
    EVOKER = {
        357214,  -- Wing Buffet; racial (Dracthyr); also in Racials (debuffs)
        368970,  -- Tail Swipe; racial (Dracthyr); also in Racials (debuffs)
        370898,  -- Permeating Chill
    },
    ALL = {
        260369,  -- Arcane Pulse; racial (Nightborne); also in Racials (debuffs)
    },
})

-- Racials (Cat.HARMFUL)
seed("racialDebuffs", "HARMFUL", {
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
})
