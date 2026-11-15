local _, NS = ...

-- defaults/Categories_Forever.lua -- GENERATED. Do not edit by hand. Part 1 of 1.
--
--   Build 1.60.1.70938 (WoW Forever), derived 2026-11-14 by tools/spell-research/forever.py emit.
--   Provenance: docs/spell-research/2026-11-14-forever/ (candidates.json, RULINGS.md); every id's ruling and
--   its reason is in tools/spell-research/forever_rulings.json. Re-run forever.py to refresh it.
--
-- WHAT THIS IS. WoW Forever's seed lists for the `spells` categories, by category key and class:
-- NS.CategorySeedsForever[key] = { CLASS = { id, ... } }. defaults/Categories.lua picks these on
-- Forever and its own inline lists on Retail, once at load (clients-§5); this file never touches
-- NS.Categories. The ids are AURA ids, and every rank of a spell ships: a filter matches one id.

NS.CategorySeedsForever = NS.CategorySeedsForever or {}

-- The `spells` categories with nothing on WoW Forever. AM-FP06's gate reads this one fact:
-- a key here does not exist on Forever (clients-§4), and a re-run that fills it ungates it.
NS.CategorySeedsForever.EMPTY = {
}

-- defensives (BUFF): 21 ids
NS.CategorySeedsForever.defensives = {
    WARRIOR = {
        12976, -- Last Stand; name-map of Retail 12975
        871,   -- Shield Wall; name-map of Retail 871
    },
    PALADIN = {
        1022,    -- Blessing of Protection (Rank 1); hand
        5599,    -- Blessing of Protection (Rank 2); hand
        10278,   -- Blessing of Protection (Rank 3); hand
        6940,    -- Blessing of Sacrifice (Rank 1); name-map of Retail 6940
        20729,   -- Blessing of Sacrifice (Rank 2); name-map of Retail 6940
        498,     -- Divine Protection (Rank 1); name-map of Retail 498
        5573,    -- Divine Protection (Rank 2); name-map of Retail 498
        642,     -- Divine Shield (Rank 1); name-map of Retail 642
        1020,    -- Divine Shield (Rank 2); name-map of Retail 642
        1311015, -- Templar's Bulwark; db2-effect
    },
    HUNTER = {
        19263, -- Deterrence; db2-effect
    },
    ROGUE = {
        5277, -- Evasion; name-map of Retail 5277
    },
    MAGE = {
        11426, -- Ice Barrier (Rank 1); name-map of Retail 11426
        13031, -- Ice Barrier (Rank 2); name-map of Retail 11426
        13032, -- Ice Barrier (Rank 3); name-map of Retail 11426
        13033, -- Ice Barrier (Rank 4); name-map of Retail 11426
        11958, -- Ice Block; name-map of Retail 45438
    },
    DRUID = {
        22812, -- Barkskin; name-map of Retail 22812
        22842, -- Frenzied Regeneration; hand
    },
}

-- activeMitigation (BUFF): 5 ids
NS.CategorySeedsForever.activeMitigation = {
    WARRIOR = {
        2565, -- Shield Block; name-map of Retail 132404
    },
    PALADIN = {
        20925,   -- Holy Shield (Rank 1); db2-effect
        20927,   -- Holy Shield (Rank 2); db2-effect
        20928,   -- Holy Shield (Rank 3); db2-effect
        1239570, -- Holy Shield (Rank 4); db2-effect
    },
}

-- raidCDs (BUFF): 4 ids
NS.CategorySeedsForever.raidCDs = {
    DRUID = {
        740,  -- Tranquility (Rank 1); name-map of Retail 740
        8918, -- Tranquility (Rank 2); name-map of Retail 740
        9862, -- Tranquility (Rank 3); name-map of Retail 740
        9863, -- Tranquility (Rank 4); name-map of Retail 740
    },
}

-- offensiveCDs (BUFF): 13 ids
NS.CategorySeedsForever.offensiveCDs = {
    WARRIOR = {
        12328, -- Death Wish; db2-effect
        1719,  -- Recklessness; name-map of Retail 1719
    },
    HUNTER = {
        19574, -- Bestial Wrath; name-map of Retail 19574
        3045,  -- Rapid Fire; hand
    },
    ROGUE = {
        13750, -- Adrenaline Rush; name-map of Retail 13750
        13877, -- Blade Flurry; hand
        14177, -- Cold Blood; hand
    },
    SHAMAN = {
        16166, -- Lightning Mastery; hand
    },
    MAGE = {
        12042, -- Arcane Power; db2-effect
        11129, -- Combustion; name-map of Retail 190319
        28682, -- Combustion; name-map of Retail 190319
        12043, -- Presence of Mind; hand
    },
    WARLOCK = {
        18288, -- Amplify Curse; db2-effect
    },
}

-- healing (BUFF): 73 ids
NS.CategorySeedsForever.healing = {
    PRIEST = {
        1277456, -- Contingency Plan (Rank 1); db2-effect
        1277457, -- Contingency Plan (Rank 2); db2-effect
        1277458, -- Contingency Plan (Rank 3); db2-effect
        1277459, -- Contingency Plan (Rank 4); db2-effect
        1277460, -- Contingency Plan (Rank 5); db2-effect
        1277463, -- Contingency Plan (Rank 1); db2-effect
        1277464, -- Contingency Plan (Rank 2); db2-effect
        1277465, -- Contingency Plan (Rank 3); db2-effect
        1277466, -- Contingency Plan (Rank 5); db2-effect
        1277467, -- Contingency Plan (Rank 4); db2-effect
        7001,    -- Lightwell Renew (Rank 1); db2-effect
        27873,   -- Lightwell Renew (Rank 2); db2-effect
        27874,   -- Lightwell Renew (Rank 3); db2-effect
        17,      -- Power Word: Shield (Rank 1); name-map of Retail 17
        592,     -- Power Word: Shield (Rank 2); name-map of Retail 17
        600,     -- Power Word: Shield (Rank 3); name-map of Retail 17
        3747,    -- Power Word: Shield (Rank 4); name-map of Retail 17
        6065,    -- Power Word: Shield (Rank 5); name-map of Retail 17
        6066,    -- Power Word: Shield (Rank 6); name-map of Retail 17
        10898,   -- Power Word: Shield (Rank 7); name-map of Retail 17
        10899,   -- Power Word: Shield (Rank 8); name-map of Retail 17
        10900,   -- Power Word: Shield (Rank 9); name-map of Retail 17
        10901,   -- Power Word: Shield (Rank 10); name-map of Retail 17
        139,     -- Renew (Rank 1); name-map of Retail 139
        6074,    -- Renew (Rank 2); name-map of Retail 139
        6075,    -- Renew (Rank 3); name-map of Retail 139
        6076,    -- Renew (Rank 4); name-map of Retail 139
        6077,    -- Renew (Rank 5); name-map of Retail 139
        6078,    -- Renew (Rank 6); name-map of Retail 139
        10927,   -- Renew (Rank 7); name-map of Retail 139
        10928,   -- Renew (Rank 8); name-map of Retail 139
        10929,   -- Renew (Rank 9); name-map of Retail 139
        25315,   -- Renew (Rank 10); name-map of Retail 139
    },
    DRUID = {
        8936,   -- Regrowth (Rank 1); name-map of Retail 8936
        8938,   -- Regrowth (Rank 2); name-map of Retail 8936
        8939,   -- Regrowth (Rank 3); name-map of Retail 8936
        8940,   -- Regrowth (Rank 4); name-map of Retail 8936
        8941,   -- Regrowth (Rank 5); name-map of Retail 8936
        9750,   -- Regrowth (Rank 6); name-map of Retail 8936
        9856,   -- Regrowth (Rank 7); name-map of Retail 8936
        9857,   -- Regrowth (Rank 8); name-map of Retail 8936
        9858,   -- Regrowth (Rank 9); name-map of Retail 8936
        436937, -- Regrowth (Rank 1); name-map of Retail 8936
        436938, -- Regrowth (Rank 2); name-map of Retail 8936
        436939, -- Regrowth (Rank 3); name-map of Retail 8936
        436940, -- Regrowth (Rank 4); name-map of Retail 8936
        436942, -- Regrowth (Rank 5); name-map of Retail 8936
        436943, -- Regrowth (Rank 6); name-map of Retail 8936
        436944, -- Regrowth (Rank 7); name-map of Retail 8936
        436945, -- Regrowth (Rank 8); name-map of Retail 8936
        436946, -- Regrowth (Rank 9); name-map of Retail 8936
        774,    -- Rejuvenation (Rank 1); name-map of Retail 774
        1058,   -- Rejuvenation (Rank 2); name-map of Retail 774
        1430,   -- Rejuvenation (Rank 3); name-map of Retail 774
        2090,   -- Rejuvenation (Rank 4); name-map of Retail 774
        2091,   -- Rejuvenation (Rank 5); name-map of Retail 774
        3627,   -- Rejuvenation (Rank 6); name-map of Retail 774
        8910,   -- Rejuvenation (Rank 7); name-map of Retail 774
        9839,   -- Rejuvenation (Rank 8); name-map of Retail 774
        9840,   -- Rejuvenation (Rank 9); name-map of Retail 774
        9841,   -- Rejuvenation (Rank 10); name-map of Retail 774
        25299,  -- Rejuvenation (Rank 11); name-map of Retail 774
        417057, -- Rejuvenation (Rank 1); name-map of Retail 774
        417058, -- Rejuvenation (Rank 2); name-map of Retail 774
        417059, -- Rejuvenation (Rank 3); name-map of Retail 774
        417060, -- Rejuvenation (Rank 4); name-map of Retail 774
        417061, -- Rejuvenation (Rank 5); name-map of Retail 774
        417062, -- Rejuvenation (Rank 6); name-map of Retail 774
        417063, -- Rejuvenation (Rank 7); name-map of Retail 774
        417064, -- Rejuvenation (Rank 8); name-map of Retail 774
        417065, -- Rejuvenation (Rank 9); name-map of Retail 774
        417066, -- Rejuvenation (Rank 10); name-map of Retail 774
        417068, -- Rejuvenation (Rank 11); name-map of Retail 774
    },
}

-- support (BUFF): 8 ids
NS.CategorySeedsForever.support = {
    PRIEST = {
        1277462, -- Contingency Plan (Rank 1); db2-effect
        1277634, -- Contingency Plan (Rank 2); db2-effect
        1277638, -- Contingency Plan (Rank 3); db2-effect
        1277639, -- Contingency Plan (Rank 4); db2-effect
        1277640, -- Contingency Plan (Rank 5); db2-effect
        6346,    -- Fear Ward; db2-effect
        10060,   -- Power Infusion; name-map of Retail 10060
    },
    DRUID = {
        29166, -- Innervate; name-map of Retail 29166
    },
}

-- groupBuffs (BUFF): 59 ids
NS.CategorySeedsForever.groupBuffs = {
    WARRIOR = {
        5242,  -- Battle Shout (Rank 2); name-map of Retail 6673
        6192,  -- Battle Shout (Rank 3); name-map of Retail 6673
        6673,  -- Battle Shout (Rank 1); name-map of Retail 6673
        11549, -- Battle Shout (Rank 4); name-map of Retail 6673
        11550, -- Battle Shout (Rank 5); name-map of Retail 6673
        11551, -- Battle Shout (Rank 6); name-map of Retail 6673
        25289, -- Battle Shout (Rank 7); name-map of Retail 6673
    },
    PALADIN = {
        20217,  -- Blessing of Kings; hand
        19740,  -- Blessing of Might (Rank 1); hand
        19834,  -- Blessing of Might (Rank 2); hand
        19835,  -- Blessing of Might (Rank 3); hand
        19836,  -- Blessing of Might (Rank 4); hand
        19837,  -- Blessing of Might (Rank 5); hand
        19838,  -- Blessing of Might (Rank 6); hand
        25291,  -- Blessing of Might (Rank 7); hand
        19742,  -- Blessing of Wisdom (Rank 1); hand
        19850,  -- Blessing of Wisdom (Rank 2); hand
        19852,  -- Blessing of Wisdom (Rank 3); hand
        19853,  -- Blessing of Wisdom (Rank 4); hand
        19854,  -- Blessing of Wisdom (Rank 5); hand
        25290,  -- Blessing of Wisdom (Rank 6); hand
        25898,  -- Greater Blessing of Kings; hand
        25782,  -- Greater Blessing of Might (Rank 1); hand
        25916,  -- Greater Blessing of Might (Rank 2); hand
        25894,  -- Greater Blessing of Wisdom (Rank 1); hand
        25918,  -- Greater Blessing of Wisdom (Rank 2); hand
        425600, -- Horn of Lordaeron; db2-effect
    },
    PRIEST = {
        14752, -- Divine Spirit (Rank 1); hand
        14818, -- Divine Spirit (Rank 2); hand
        14819, -- Divine Spirit (Rank 3); hand
        27841, -- Divine Spirit (Rank 4); hand
        1243,  -- Power Word: Fortitude (Rank 1); name-map of Retail 21562
        1244,  -- Power Word: Fortitude (Rank 2); name-map of Retail 21562
        1245,  -- Power Word: Fortitude (Rank 3); name-map of Retail 21562
        2791,  -- Power Word: Fortitude (Rank 4); name-map of Retail 21562
        10937, -- Power Word: Fortitude (Rank 5); name-map of Retail 21562
        10938, -- Power Word: Fortitude (Rank 6); name-map of Retail 21562
        21562, -- Prayer of Fortitude (Rank 1); db2-effect
        21564, -- Prayer of Fortitude (Rank 2); db2-effect
        27683, -- Prayer of Shadow Protection; db2-effect
        27681, -- Prayer of Spirit (Rank 1); db2-effect
        976,   -- Shadow Protection (Rank 1); hand
        10957, -- Shadow Protection (Rank 2); hand
        10958, -- Shadow Protection (Rank 3); hand
    },
    MAGE = {
        23028, -- Arcane Brilliance; db2-effect
        1459,  -- Arcane Intellect (Rank 1); name-map of Retail 1459
        1460,  -- Arcane Intellect (Rank 2); name-map of Retail 1459
        1461,  -- Arcane Intellect (Rank 3); name-map of Retail 1459
        10156, -- Arcane Intellect (Rank 4); name-map of Retail 1459
        10157, -- Arcane Intellect (Rank 5); name-map of Retail 1459
    },
    DRUID = {
        21849, -- Gift of the Wild (Rank 1); db2-effect
        21850, -- Gift of the Wild (Rank 2); db2-effect
        1126,  -- Mark of the Wild (Rank 1); name-map of Retail 1126
        5232,  -- Mark of the Wild (Rank 2); name-map of Retail 1126
        5234,  -- Mark of the Wild (Rank 4); name-map of Retail 1126
        6756,  -- Mark of the Wild (Rank 3); name-map of Retail 1126
        8907,  -- Mark of the Wild (Rank 5); name-map of Retail 1126
        9884,  -- Mark of the Wild (Rank 6); name-map of Retail 1126
        9885,  -- Mark of the Wild (Rank 7); name-map of Retail 1126
    },
}

-- movement (BUFF): 15 ids
NS.CategorySeedsForever.movement = {
    WARRIOR = {
        23881, -- Bloodthirst (Rank 1); db2-effect
        23892, -- Bloodthirst (Rank 2); db2-effect
        23893, -- Bloodthirst (Rank 3); db2-effect
        23894, -- Bloodthirst (Rank 4); db2-effect
    },
    PALADIN = {
        1044, -- Blessing of Freedom; name-map of Retail 1044
    },
    HUNTER = {
        5118,    -- Aspect of the Cheetah; name-map of Retail 186257
        13159,   -- Aspect of the Pack; db2-effect
        1317257, -- Strider Kick; db2-effect
    },
    ROGUE = {
        2983,  -- Sprint (Rank 1); name-map of Retail 2983
        8696,  -- Sprint (Rank 2); name-map of Retail 2983
        11305, -- Sprint (Rank 3); name-map of Retail 2983
    },
    SHAMAN = {
        2645,    -- Ghost Wolf; name-map of Retail 2645
        1238640, -- Ghost Wolf; name-map of Retail 2645
    },
    DRUID = {
        1850, -- Dash (Rank 1); name-map of Retail 1850
        9821, -- Dash (Rank 2); name-map of Retail 1850
    },
}

-- utility (BUFF): 20 ids
NS.CategorySeedsForever.utility = {
    HUNTER = {
        5384, -- Feign Death; name-map of Retail 5384
    },
    ROGUE = {
        1784,  -- Stealth (Rank 1); name-map of Retail 1784
        1785,  -- Stealth (Rank 2); name-map of Retail 1784
        1786,  -- Stealth (Rank 3); name-map of Retail 1784
        1787,  -- Stealth (Rank 4); name-map of Retail 1784
        11327, -- Vanish (Rank 1); db2-effect
        11329, -- Vanish (Rank 2); db2-effect
    },
    PRIEST = {
        1706, -- Levitate; name-map of Retail 111759
    },
    SHAMAN = {
        131, -- Water Breathing; db2-effect
        546, -- Water Walking; name-map of Retail 546
    },
    MAGE = {
        130, -- Slow Fall; name-map of Retail 130
    },
    WARLOCK = {
        20707, -- Soulstone Resurrection; hand
        20762, -- Soulstone Resurrection; hand
        20763, -- Soulstone Resurrection; hand
        20764, -- Soulstone Resurrection; hand
        20765, -- Soulstone Resurrection; hand
        5697,  -- Unending Breath; name-map of Retail 5697
    },
    DRUID = {
        5215, -- Prowl (Rank 1); name-map of Retail 5215
        6783, -- Prowl (Rank 2); name-map of Retail 5215
        9913, -- Prowl (Rank 3); name-map of Retail 5215
    },
}

-- stances (BUFF): 33 ids
NS.CategorySeedsForever.stances = {
    WARRIOR = {
        2457, -- Battle Stance; name-map of Retail 386164
        2458, -- Berserker Stance; name-map of Retail 386196
        71,   -- Defensive Stance; name-map of Retail 386208
    },
    PALADIN = {
        19746, -- Concentration Aura; name-map of Retail 317920
        465,   -- Devotion Aura (Rank 1); name-map of Retail 465
        643,   -- Devotion Aura (Rank 3); name-map of Retail 465
        1032,  -- Devotion Aura (Rank 5); name-map of Retail 465
        10290, -- Devotion Aura (Rank 2); name-map of Retail 465
        10291, -- Devotion Aura (Rank 4); name-map of Retail 465
        10292, -- Devotion Aura (Rank 6); name-map of Retail 465
        10293, -- Devotion Aura (Rank 7); name-map of Retail 465
        19891, -- Fire Resistance Aura (Rank 1); db2-effect
        19899, -- Fire Resistance Aura (Rank 2); db2-effect
        19900, -- Fire Resistance Aura (Rank 3); db2-effect
        19888, -- Frost Resistance Aura (Rank 1); db2-effect
        19897, -- Frost Resistance Aura (Rank 2); db2-effect
        19898, -- Frost Resistance Aura (Rank 3); db2-effect
        7294,  -- Retribution Aura (Rank 1); db2-effect
        10298, -- Retribution Aura (Rank 2); db2-effect
        10299, -- Retribution Aura (Rank 3); db2-effect
        10300, -- Retribution Aura (Rank 4); db2-effect
        10301, -- Retribution Aura (Rank 5); db2-effect
        20218, -- Sanctity Aura; db2-effect
        19876, -- Shadow Resistance Aura (Rank 1); db2-effect
        19895, -- Shadow Resistance Aura (Rank 2); db2-effect
        19896, -- Shadow Resistance Aura (Rank 3); db2-effect
    },
    PRIEST = {
        15473, -- Shadowform; name-map of Retail 232698
    },
    DRUID = {
        1066,  -- Aquatic Form; db2-effect
        5487,  -- Bear Form; name-map of Retail 5487
        768,   -- Cat Form; name-map of Retail 768
        9634,  -- Dire Bear Form; db2-effect
        24858, -- Moonkin Form; name-map of Retail 24858
        783,   -- Travel Form; name-map of Retail 165961
    },
}

-- racials (BUFF): 19 ids
NS.CategorySeedsForever.racials = {
    ALL = {
        20554,   -- Berserking; name-map of Retail 26297
        20572,   -- Blood Fury; name-map of Retail 20572
        20578,   -- Cannibalize; hand
        1259688, -- Elemental Blessing; db2-effect
        1259799, -- Elune's Light; db2-effect
        1270842, -- Energized; db2-effect
        20589,   -- Escape Artist; db2-effect
        1259812, -- Eureka!; db2-effect
        1259813, -- Eureka!; db2-effect
        1259817, -- Eureka!; db2-effect
        1259821, -- Eureka!; db2-effect
        1259823, -- Eureka!; db2-effect
        20600,   -- Perception; db2-effect
        1260270, -- Rapid Regeneration; db2-effect
        20580,   -- Shadowmeld; name-map of Retail 58984
        1299026, -- Shatter Curse; db2-effect
        20594,   -- Stoneform; name-map of Retail 65116
        1259416, -- Walk on Air; db2-effect
        7744,    -- Will of the Forsaken; name-map of Retail 7744
    },
}

-- hardCC (DEBUFF): 82 ids
NS.CategorySeedsForever.hardCC = {
    WARRIOR = {
        7922,  -- Charge Stun; cc-mechanic
        12809, -- Concussion Blow; cc-mechanic
        20253, -- Intercept Stun (Rank 1); cc-mechanic
        20614, -- Intercept Stun (Rank 2); cc-mechanic
        20615, -- Intercept Stun (Rank 3); cc-mechanic
        5246,  -- Intimidating Shout; cc-mechanic
        20511, -- Intimidating Shout; cc-mechanic
    },
    PALADIN = {
        853,   -- Hammer of Justice (Rank 1); cc-mechanic
        5588,  -- Hammer of Justice (Rank 2); cc-mechanic
        5589,  -- Hammer of Justice (Rank 3); cc-mechanic
        10308, -- Hammer of Justice (Rank 4); cc-mechanic
        20066, -- Repentance; cc-mechanic
        20170, -- Stun (Rank 1); cc-mechanic
        2878,  -- Turn Undead (Rank 1); cc-mechanic
        5627,  -- Turn Undead (Rank 2); cc-mechanic
        10326, -- Turn Undead (Rank 3); cc-mechanic
    },
    HUNTER = {
        3355,  -- Freezing Trap (Rank 1); cc-mechanic
        14308, -- Freezing Trap (Rank 2); cc-mechanic
        14309, -- Freezing Trap (Rank 3); cc-mechanic
        19410, -- Improved Concussive Shot; cc-mechanic
        24394, -- Intimidation; cc-mechanic
        1513,  -- Scare Beast (Rank 1); cc-mechanic
        14326, -- Scare Beast (Rank 2); cc-mechanic
        14327, -- Scare Beast (Rank 3); cc-mechanic
        19503, -- Scatter Shot; cc-mechanic
    },
    ROGUE = {
        2094,  -- Blind; cc-mechanic
        1833,  -- Cheap Shot; cc-mechanic
        1776,  -- Gouge (Rank 1); cc-mechanic
        1777,  -- Gouge (Rank 2); cc-mechanic
        8629,  -- Gouge (Rank 3); cc-mechanic
        11285, -- Gouge (Rank 4); cc-mechanic
        11286, -- Gouge (Rank 5); cc-mechanic
        408,   -- Kidney Shot (Rank 1); cc-mechanic
        8643,  -- Kidney Shot (Rank 2); cc-mechanic
        2070,  -- Sap (Rank 2); cc-mechanic
        6770,  -- Sap (Rank 1); cc-mechanic
        11297, -- Sap (Rank 3); cc-mechanic
    },
    PRIEST = {
        15269,   -- Blackout (Rank 1); cc-mechanic
        1277455, -- Confounding Flash; cc-mechanic
        605,     -- Mind Control (Rank 1); cc-mechanic
        10911,   -- Mind Control (Rank 2); cc-mechanic
        10912,   -- Mind Control (Rank 3); cc-mechanic
        8122,    -- Psychic Scream (Rank 1); cc-mechanic
        8124,    -- Psychic Scream (Rank 2); cc-mechanic
        10888,   -- Psychic Scream (Rank 3); cc-mechanic
        10890,   -- Psychic Scream (Rank 4); cc-mechanic
        9484,    -- Shackle Undead (Rank 1); cc-mechanic
        9485,    -- Shackle Undead (Rank 2); cc-mechanic
        10955,   -- Shackle Undead (Rank 3); cc-mechanic
    },
    MAGE = {
        12355, -- Impact; cc-mechanic
        118,   -- Polymorph (Rank 1); cc-mechanic
        12824, -- Polymorph (Rank 2); cc-mechanic
        12825, -- Polymorph (Rank 3); cc-mechanic
        12826, -- Polymorph (Rank 4); cc-mechanic
        28271, -- Polymorph; cc-mechanic
        28272, -- Polymorph; cc-mechanic
        28270, -- Polymorph: Cow; cc-mechanic
    },
    WARLOCK = {
        710,   -- Banish (Rank 1); cc-mechanic
        18647, -- Banish (Rank 2); cc-mechanic
        6789,  -- Death Coil (Rank 1); cc-mechanic
        17925, -- Death Coil (Rank 2); cc-mechanic
        17926, -- Death Coil (Rank 3); cc-mechanic
        5782,  -- Fear (Rank 1); cc-mechanic
        6213,  -- Fear (Rank 2); cc-mechanic
        6215,  -- Fear (Rank 3); cc-mechanic
        5484,  -- Howl of Terror (Rank 1); cc-mechanic
        17928, -- Howl of Terror (Rank 2); cc-mechanic
        18093, -- Pyroclasm; cc-mechanic
        1098,  -- Subjugate Demon (Rank 1); cc-mechanic
        11725, -- Subjugate Demon (Rank 2); cc-mechanic
        11726, -- Subjugate Demon (Rank 3); cc-mechanic
    },
    DRUID = {
        5211,  -- Bash (Rank 1); cc-mechanic
        6798,  -- Bash (Rank 2); cc-mechanic
        8983,  -- Bash (Rank 3); cc-mechanic
        2637,  -- Hibernate (Rank 1); cc-mechanic
        18657, -- Hibernate (Rank 2); cc-mechanic
        18658, -- Hibernate (Rank 3); cc-mechanic
        9005,  -- Pounce (Rank 1); cc-mechanic
        9823,  -- Pounce (Rank 2); cc-mechanic
        9827,  -- Pounce (Rank 3); cc-mechanic
        16922, -- Starfire Stun; cc-mechanic
    },
    ALL = {
        20549, -- War Stomp; hand
    },
}

-- ccRoot (DEBUFF): 36 ids
NS.CategorySeedsForever.ccRoot = {
    WARRIOR = {
        23694, -- Improved Hamstring; cc-mechanic
    },
    HUNTER = {
        25999,   -- Boar Charge; cc-mechanic
        19306,   -- Counterattack (Rank 1); cc-mechanic
        20909,   -- Counterattack (Rank 3); cc-mechanic
        20910,   -- Counterattack (Rank 4); cc-mechanic
        1242634, -- Counterattack (Rank 2); cc-mechanic
        19185,   -- Entrapment; cc-mechanic
        19229,   -- Improved Wing Clip; cc-mechanic
        1265843, -- Web (Rank 1); cc-mechanic
        1265878, -- Web (Rank 2); cc-mechanic
        1265880, -- Web (Rank 3); cc-mechanic
        1265881, -- Web (Rank 4); cc-mechanic
        1265883, -- Web (Rank 5); cc-mechanic
    },
    PRIEST = {
        1277331, -- Chastise (Rank 1); cc-mechanic
        1277332, -- Chastise (Rank 2); cc-mechanic
        1277333, -- Chastise (Rank 3); cc-mechanic
        1277334, -- Chastise (Rank 4); cc-mechanic
        1277335, -- Chastise (Rank 5); cc-mechanic
    },
    MAGE = {
        122,   -- Frost Nova (Rank 1); cc-mechanic
        865,   -- Frost Nova (Rank 2); cc-mechanic
        6131,  -- Frost Nova (Rank 3); cc-mechanic
        10230, -- Frost Nova (Rank 4); cc-mechanic
        12494, -- Frostbite; cc-mechanic
    },
    DRUID = {
        339,   -- Entangling Roots (Rank 1); cc-mechanic
        1062,  -- Entangling Roots (Rank 2); cc-mechanic
        5195,  -- Entangling Roots (Rank 3); cc-mechanic
        5196,  -- Entangling Roots (Rank 4); cc-mechanic
        9852,  -- Entangling Roots (Rank 5); cc-mechanic
        9853,  -- Entangling Roots (Rank 6); cc-mechanic
        19970, -- Entangling Roots (Rank 6); cc-mechanic
        19971, -- Entangling Roots (Rank 5); cc-mechanic
        19972, -- Entangling Roots (Rank 4); cc-mechanic
        19973, -- Entangling Roots (Rank 3); cc-mechanic
        19974, -- Entangling Roots (Rank 2); cc-mechanic
        19975, -- Entangling Roots (Rank 1); cc-mechanic
        19675, -- Feral Charge; cc-mechanic
    },
}

-- ccSnare (DEBUFF): 63 ids
NS.CategorySeedsForever.ccSnare = {
    WARRIOR = {
        1715,  -- Hamstring (Rank 1); cc-mechanic
        7372,  -- Hamstring (Rank 2); cc-mechanic
        7373,  -- Hamstring (Rank 3); cc-mechanic
        12323, -- Piercing Howl; cc-mechanic
    },
    HUNTER = {
        5116,    -- Concussive Shot; cc-mechanic
        13810,   -- Frost Trap; cc-mechanic
        1264735, -- Pinch (Rank 1); cc-mechanic
        1264736, -- Pinch (Rank 2); cc-mechanic
        1264739, -- Pinch (Rank 3); cc-mechanic
        1264741, -- Pinch (Rank 4); cc-mechanic
        1264742, -- Pinch (Rank 5); cc-mechanic
        1265038, -- Tendon Rip (Rank 1); cc-mechanic
        1265039, -- Tendon Rip (Rank 2); cc-mechanic
        1265040, -- Tendon Rip (Rank 3); cc-mechanic
        1265041, -- Tendon Rip (Rank 4); cc-mechanic
        1265042, -- Tendon Rip (Rank 5); cc-mechanic
        2974,    -- Wing Clip (Rank 1); cc-mechanic
        14267,   -- Wing Clip (Rank 2); cc-mechanic
        14268,   -- Wing Clip (Rank 3); cc-mechanic
    },
    ROGUE = {
        3409,  -- Crippling Poison (Rank 1); cc-mechanic
        11201, -- Crippling Poison (Rank 2); cc-mechanic
    },
    PRIEST = {
        15407, -- Mind Flay (Rank 1); cc-mechanic
        17311, -- Mind Flay (Rank 2); cc-mechanic
        17312, -- Mind Flay (Rank 3); cc-mechanic
        17313, -- Mind Flay (Rank 4); cc-mechanic
        17314, -- Mind Flay (Rank 5); cc-mechanic
        18807, -- Mind Flay (Rank 6); cc-mechanic
    },
    SHAMAN = {
        3600,  -- Earthbind; hand
        8056,  -- Frost Shock (Rank 1); cc-mechanic
        8058,  -- Frost Shock (Rank 2); cc-mechanic
        10472, -- Frost Shock (Rank 3); cc-mechanic
        10473, -- Frost Shock (Rank 4); cc-mechanic
        8034,  -- Frostbrand Attack (Rank 1); hand
        8037,  -- Frostbrand Attack (Rank 2); hand
        10458, -- Frostbrand Attack (Rank 3); hand
        16352, -- Frostbrand Attack (Rank 4); hand
        16353, -- Frostbrand Attack (Rank 5); hand
    },
    MAGE = {
        11113, -- Blast Wave (Rank 1); cc-mechanic
        13018, -- Blast Wave (Rank 2); cc-mechanic
        13019, -- Blast Wave (Rank 3); cc-mechanic
        13020, -- Blast Wave (Rank 4); cc-mechanic
        13021, -- Blast Wave (Rank 5); cc-mechanic
        6136,  -- Chilled (Rank 1); cc-mechanic
        7321,  -- Chilled (Rank 1); cc-mechanic
        12484, -- Chilled; cc-mechanic
        120,   -- Cone of Cold (Rank 1); cc-mechanic
        8492,  -- Cone of Cold (Rank 2); cc-mechanic
        10159, -- Cone of Cold (Rank 3); cc-mechanic
        10160, -- Cone of Cold (Rank 4); cc-mechanic
        10161, -- Cone of Cold (Rank 5); cc-mechanic
        116,   -- Frostbolt (Rank 1); cc-mechanic
        205,   -- Frostbolt (Rank 2); cc-mechanic
        837,   -- Frostbolt (Rank 3); cc-mechanic
        7322,  -- Frostbolt (Rank 4); cc-mechanic
        8406,  -- Frostbolt (Rank 5); cc-mechanic
        8407,  -- Frostbolt (Rank 6); cc-mechanic
        8408,  -- Frostbolt (Rank 7); cc-mechanic
        10179, -- Frostbolt (Rank 8); cc-mechanic
        10180, -- Frostbolt (Rank 9); cc-mechanic
        10181, -- Frostbolt (Rank 10); cc-mechanic
        25304, -- Frostbolt (Rank 11); cc-mechanic
    },
    WARLOCK = {
        18118, -- Aftermath; cc-mechanic
        18223, -- Curse of Exhaustion; cc-mechanic
    },
}

-- racialDebuffs (DEBUFF): 1 id
NS.CategorySeedsForever.racialDebuffs = {
    ALL = {
        20549, -- War Stomp; name-map of Retail 20549
    },
}
