# Rulings — WoW Forever seed lists, 2026-11-14

Written by `tools/spell-research/forever.py emit` from `candidates.json` (build `1.60.1.70938`) and
`tools/spell-research/forever_rulings.json`. Regenerated on every emit; never edited by hand.

## `defensives` (BUFF): 35 candidates, 21 accepted

| Id | Name | Rank | Class | Source | Origin | Ruling | Reason |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 12976 | Last Stand |  | WARRIOR | name-map | 12975 | accept | Last Stand health aura on self, triggered by WARRIOR Protection talent cast 12975 (cast applies no aura; 12976 is what shows) |
| 871 | Shield Wall |  | WARRIOR | name-map | 871 | accept | Shield Wall, WARRIOR Protection SkillLineAbility, 60% damage-taken reduction aura on self, 15 min recast |
| 15062 | Shield Wall |  | WARRIOR | name-map | 871 | reject | NPC copy of Shield Wall: no SkillLineAbility/Talent/grant edge, 75% value and no recast, unlike the player's 871 |
| 29061 | Shield Wall |  | WARRIOR | name-map | 871 | reject | NPC copy of Shield Wall: no SkillLineAbility/Talent/grant edge, 75% value and 30 s recast |
| 1277424 | Shield Wall |  | WARRIOR | name-map | 871 | reject | NPC copy of Shield Wall: no SkillLineAbility/Talent/grant edge, 75% value and no recast |
| 1022 | Blessing of Protection | Rank 1 | PALADIN | hand |  | accept | rank 1 of Blessing of Protection, PALADIN Protection SkillLineAbility, physical-immunity aura (A39 + Mechanic 25) on a party member, 5 min recast; an external, so Defensives by the Retail owner precedent |
| 5599 | Blessing of Protection | Rank 2 | PALADIN | hand |  | accept | rank 2 of Blessing of Protection, PALADIN Protection SkillLineAbility, physical-immunity aura on a party member, 5 min recast; external, Defensives by owner precedent |
| 10278 | Blessing of Protection | Rank 3 | PALADIN | hand |  | accept | rank 3 of Blessing of Protection, PALADIN Protection SkillLineAbility, physical-immunity aura on a party member, 5 min recast; external, Defensives by owner precedent |
| 6940 | Blessing of Sacrifice | Rank 1 | PALADIN | name-map | 6940 | accept | rank 1 of Blessing of Sacrifice, PALADIN Protection SkillLineAbility, damage-transfer aura on a party member (Retail owner placed it in Defensives) |
| 20729 | Blessing of Sacrifice | Rank 2 | PALADIN | name-map | 6940 | accept | rank 2 of Blessing of Sacrifice, PALADIN Protection SkillLineAbility, damage-transfer aura on a party member |
| 498 | Divine Protection | Rank 1 | PALADIN | name-map | 498 | accept | rank 1 of Divine Protection, PALADIN Protection SkillLineAbility, immunity aura on self, 5 min recast |
| 5573 | Divine Protection | Rank 2 | PALADIN | name-map | 498 | accept | rank 2 of Divine Protection, PALADIN Protection SkillLineAbility, immunity aura on self, 5 min recast |
| 458312 | Divine Protection | Rank 1 | PALADIN | name-map | 498 | reject | rune ability: 50% Divine Protection granted only by the Malleable Protection rune (458318 override; Engrave Belt 426175), no SkillLineAbility |
| 458371 | Divine Protection | Rank 2 | PALADIN | name-map | 498 | reject | rune ability: rank 2 of the Malleable Protection rune's Divine Protection (458318 override), no SkillLineAbility |
| 642 | Divine Shield | Rank 1 | PALADIN | name-map | 642 | accept | rank 1 of Divine Shield, PALADIN Protection SkillLineAbility, immunity aura on self, 5 min recast |
| 1020 | Divine Shield | Rank 2 | PALADIN | name-map | 642 | accept | rank 2 of Divine Shield, PALADIN Protection SkillLineAbility, immunity aura on self, 5 min recast |
| 9799 | Eye for an Eye |  | PALADIN | name-map | 205191 | reject | Eye for an Eye is a passive Retribution talent (SPELL_ATTR0_PASSIVE, permanent hidden proc aura), never a visible cooldown aura |
| 1311015 | Templar's Bulwark |  | PALADIN | db2-effect |  | accept | Templar's Bulwark, PALADIN Protection SkillLineAbility and Forever talent tree 1100, max-health absorb aura on self, 5 min recast |
| 19263 | Deterrence |  | HUNTER | db2-effect |  | accept | Deterrence, HUNTER Survival talent (Talent + SkillLineAbility), +25% dodge/parry aura on self, 5 min recast |
| 26064 | Shell Shield | Rank 1 | HUNTER | db2-effect |  | reject | Shell Shield is a pet-line ability (Pet - Turtle 251), cast by and on the pet, not a hunter personal defensive; pet lines are out of the pool |
| 1310612 | Trickster's Dance | Rank 1 | HUNTER | db2-effect |  | reject | Trickster's Dance is a pet-line ability (Pet - Fox 3016), dodge aura on the pet, not a hunter personal defensive; pet lines are out of the pool |
| 5277 | Evasion |  | ROGUE | name-map | 5277 | accept | Evasion, ROGUE Combat SkillLineAbility, +50% dodge aura on self, 5 min recast |
| 15087 | Evasion |  | ROGUE | name-map | 5277 | reject | NPC copy of Evasion: no SkillLineAbility/Talent/grant edge and no recast; the player's is 5277 |
| 457437 | Vanish |  | ROGUE | db2-effect |  | reject | item effect: Magic damage reduction granted by the S03 T1 Rogue Tank 4P set bonus (457440 override), named Vanish, no SkillLineAbility |
| 459702 | Desperate Prayer |  | PRIEST | name-map | 19236 | reject | hidden passive that grants the Desperate Prayer ability (override aura 332, attr hidden); Forever's Desperate Prayer 19236 is an instant heal with no aura |
| 11426 | Ice Barrier | Rank 1 | MAGE | name-map | 11426 | accept | rank 1 of Ice Barrier, MAGE Frost talent (Talent + SkillLineAbility), absorb aura on self |
| 13031 | Ice Barrier | Rank 2 | MAGE | name-map | 11426 | accept | rank 2 of Ice Barrier, MAGE Frost SkillLineAbility, absorb aura on self |
| 13032 | Ice Barrier | Rank 3 | MAGE | name-map | 11426 | accept | rank 3 of Ice Barrier, MAGE Frost SkillLineAbility, absorb aura on self |
| 13033 | Ice Barrier | Rank 4 | MAGE | name-map | 11426 | accept | rank 4 of Ice Barrier, MAGE Frost SkillLineAbility, absorb aura on self |
| 1213278 | Ice Barrier | Rank 4 | MAGE | name-map | 11426 | reject | duplicate Ice Barrier Rank 4 with old tooltip, no SkillLineAbility/Talent/grant edge: not player-reachable (the player's rank 4 is 13033) |
| 11958 | Ice Block |  | MAGE | name-map | 45438 | accept | Ice Block, MAGE Frost talent (Talent + SkillLineAbility), immunity aura on self, 5 min recast |
| 27619 | Ice Block |  | MAGE | name-map | 45438 | reject | NPC copy of Ice Block: no SkillLineAbility/Talent/grant edge; the player's is 11958 |
| 22812 | Barkskin |  | DRUID | name-map | 22812 | accept | Barkskin, DRUID Balance SkillLineAbility, damage-reduction aura on self, 1 min recast |
| 428713 | Barkskin |  | DRUID | name-map | 22812 | reject | rune ability: ally-targeted Barkskin granted only by the Improved Barkskin rune (431388 override; Engrave Helm 431449) |
| 22842 | Frenzied Regeneration |  | DRUID | hand |  | accept | Frenzied Regeneration, DRUID Feral Combat SkillLineAbility, rage-to-health periodic aura (A23) on self in bear form, 3 min recast: the bear's personal defensive |

## `activeMitigation` (BUFF): 21 candidates, 5 accepted

| Id | Name | Rank | Class | Source | Origin | Ruling | Reason |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 16462 | Deflection |  | WARRIOR | db2-effect |  | reject | Deflection is a passive WARRIOR talent (+parry), never a visible aura |
| 2565 | Shield Block |  | WARRIOR | name-map | 132404 | accept | Shield Block, WARRIOR Protection SkillLineAbility, short block-chance aura on self, 5 s recast: the Retail Shield Block analogue |
| 12298 | Shield Specialization |  | WARRIOR | db2-effect |  | reject | Shield Specialization is a passive WARRIOR talent (+block), never a visible aura |
| 20060 | Deflection |  | PALADIN | db2-effect |  | reject | Deflection is a passive PALADIN talent (+parry), never a visible aura |
| 20925 | Holy Shield | Rank 1 | PALADIN | db2-effect |  | accept | rank 1 of Holy Shield, PALADIN Protection talent (Talent + SkillLineAbility), 10 s block-chance aura on self: frequently refreshed tank mitigation |
| 20927 | Holy Shield | Rank 2 | PALADIN | db2-effect |  | accept | rank 2 of Holy Shield, PALADIN Protection SkillLineAbility, 10 s block-chance aura on self |
| 20928 | Holy Shield | Rank 3 | PALADIN | db2-effect |  | accept | rank 3 of Holy Shield, PALADIN Protection SkillLineAbility, 10 s block-chance aura on self |
| 1239570 | Holy Shield | Rank 4 | PALADIN | db2-effect |  | accept | rank 4 of Holy Shield (Forever-added rank), PALADIN Protection SkillLineAbility, 10 s block-chance aura on self |
| 13163 | Aspect of the Monkey |  | HUNTER | db2-effect |  | reject | Aspect of the Monkey is a persistent hunter aspect (one-aspect stance-like buff, no duration/recast), not short refreshed tank mitigation |
| 19295 | Deflection |  | HUNTER | db2-effect |  | reject | Deflection is a passive HUNTER talent (+parry), never a visible aura |
| 13713 | Deflection |  | ROGUE | db2-effect |  | reject | Deflection is a passive ROGUE talent (+parry), never a visible aura |
| 15087 | Evasion |  | ROGUE | db2-effect |  | reject | NPC copy of Evasion (no SkillLineAbility/Talent/grant edge); the player's Evasion 5277 is a personal defensive anyway |
| 14278 | Ghostly Strike |  | ROGUE | db2-effect |  | reject | Ghostly Strike's 7 s dodge is a side effect of a rogue damage strike; rogues are not tanks on Forever outside runes, so not tank mitigation |
| 13712 | Lightning Reflexes |  | ROGUE | db2-effect |  | reject | Lightning Reflexes is a passive ROGUE talent (+dodge), never a visible aura |
| 16254 | Anticipation |  | SHAMAN | db2-effect |  | reject | Anticipation is a passive SHAMAN talent (+dodge), never a visible aura |
| 16253 | Shield Specialization | Rank 1 | SHAMAN | db2-effect |  | reject | rank 1 of Shield Specialization, passive SHAMAN talent (+block), never a visible aura |
| 16298 | Shield Specialization | Rank 2 | SHAMAN | db2-effect |  | reject | rank 2 of Shield Specialization, passive SHAMAN talent (+block), never a visible aura |
| 16299 | Shield Specialization | Rank 3 | SHAMAN | db2-effect |  | reject | rank 3 of Shield Specialization, passive SHAMAN talent (+block), never a visible aura |
| 16300 | Shield Specialization | Rank 4 | SHAMAN | db2-effect |  | reject | rank 4 of Shield Specialization, passive SHAMAN talent (+block), never a visible aura |
| 16301 | Shield Specialization | Rank 5 | SHAMAN | db2-effect |  | reject | rank 5 of Shield Specialization, passive SHAMAN talent (+block), never a visible aura |
| 17002 | Feral Swiftness |  | DRUID | db2-effect |  | reject | Feral Swiftness is a passive DRUID talent (+dodge/speed in cat form), never a visible aura |

## `raidCDs` (BUFF): 8 candidates, 4 accepted

| Id | Name | Rank | Class | Source | Origin | Ruling | Reason |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 461475 | Valor of Azeroth |  | WARRIOR | db2-effect |  | reject | rune ability: Valor of Azeroth is a Season of Discovery warrior rune (AcquireMethod 3 on Protection, in neither Talent nor the Forever talent tree) |
| 740 | Tranquility | Rank 1 | DRUID | name-map | 740 | accept | rank 1 of Tranquility, DRUID Restoration SkillLineAbility, party-area heal aura on group members, 5 min recast (Retail owner placed it in Raid cooldowns) |
| 8918 | Tranquility | Rank 2 | DRUID | name-map | 740 | accept | rank 2 of Tranquility, DRUID Restoration SkillLineAbility, party-area heal aura on group members, 5 min recast |
| 9862 | Tranquility | Rank 3 | DRUID | name-map | 740 | accept | rank 3 of Tranquility, DRUID Restoration SkillLineAbility, party-area heal aura on group members, 5 min recast |
| 9863 | Tranquility | Rank 4 | DRUID | name-map | 740 | accept | rank 4 of Tranquility, DRUID Restoration SkillLineAbility, party-area heal aura on group members, 5 min recast |
| 21791 | Tranquility |  | DRUID | name-map | 740 | reject | NPC copy of Tranquility: no SkillLineAbility/Talent/grant edge, no recast, fixed non-player heal value |
| 25817 | Tranquility |  | DRUID | name-map | 740 | reject | NPC copy of Tranquility: no SkillLineAbility/Talent/grant edge, no recast, 5847 heal value |
| 1253568 | Tranquility |  | DRUID | name-map | 740 | reject | NPC copy of Tranquility: no SkillLineAbility/Talent/grant edge, area-source targets (22/30) unlike the player's party aura |

## `offensiveCDs` (BUFF): 23 candidates, 13 accepted

| Id | Name | Rank | Class | Source | Origin | Ruling | Reason |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 12328 | Death Wish |  | WARRIOR | db2-effect |  | accept | Death Wish, WARRIOR Fury talent (Talent + SkillLineAbility), +20% physical damage aura on self, 3 min recast |
| 1259813 | Eureka! |  | WARRIOR | db2-effect |  | reject | Eureka! is the Gnome racial (Racial - Gnome skill line, race mask 64): belongs in Racials, like Retail's racial cooldowns |
| 1719 | Recklessness |  | WARRIOR | name-map | 1719 | accept | Recklessness, WARRIOR Fury SkillLineAbility, crit aura on self, 30 min recast |
| 13847 | Recklessness |  | WARRIOR | name-map | 1719 | reject | NPC copy of Recklessness (all attacks crit, armor reduced): no SkillLineAbility/Talent/grant edge |
| 407788 | Avenging Wrath |  | PALADIN | name-map | 31884 | reject | rune ability: Avenging Wrath is granted only through the rune override 409934 (AcquireMethod 3, not in the Forever paladin talent tree 1100) |
| 407957 | Avenging Wrath |  | PALADIN | name-map | 31884 | reject | hidden ally-targeted dummy aura of the SoD Avenging Wrath rune, no SkillLineAbility; not a player cooldown aura |
| 409934 | Avenging Wrath |  | PALADIN | name-map | 31884 | reject | passive rune override that grants Avenging Wrath 407788 (aura 332), never a cooldown aura |
| 19574 | Bestial Wrath |  | HUNTER | name-map | 19574 | accept | Bestial Wrath, HUNTER Beast Mastery talent (Talent + SkillLineAbility), +50% damage enrage aura on the hunter's pet, 2 min recast |
| 3045 | Rapid Fire |  | HUNTER | hand |  | accept | Rapid Fire, HUNTER Marksmanship SkillLineAbility, +ranged haste aura (A140) on self, 5 min recast: the hunter's damage cooldown |
| 13750 | Adrenaline Rush |  | ROGUE | name-map | 13750 | accept | Adrenaline Rush, ROGUE Combat talent (Talent + SkillLineAbility), energy-regen aura on self, 5 min recast |
| 13877 | Blade Flurry |  | ROGUE | hand |  | accept | Blade Flurry, ROGUE Combat talent (Talent + SkillLineAbility), melee haste and cleave aura on self, 2 min recast |
| 14177 | Cold Blood |  | ROGUE | hand |  | accept | Cold Blood, ROGUE Assassination talent (Talent + SkillLineAbility), next-ability crit aura (A107) on self, 3 min recast |
| 1259812 | Eureka! |  | ROGUE | db2-effect |  | reject | Eureka! is the Gnome racial (Racial - Gnome skill line, race mask 64): belongs in Racials |
| 1259823 | Eureka! |  | PRIEST | db2-effect |  | reject | Eureka! is the Gnome racial (Racial - Gnome skill line, race mask 64): belongs in Racials |
| 16166 | Lightning Mastery |  | SHAMAN | hand |  | accept | Lightning Mastery 16166, SHAMAN Elemental talent, 3 min self aura: Lightning Bolt cast time reduced and no Chain Lightning cooldown (A107/A108 on caster); ranks 16579-16582 are the passive talent |
| 12042 | Arcane Power |  | MAGE | db2-effect |  | accept | Arcane Power, MAGE Arcane talent (Talent + SkillLineAbility), +30% spell damage aura on self, 3 min recast |
| 11129 | Combustion |  | MAGE | name-map | 190319 | accept | Combustion, MAGE Fire talent (Talent + SkillLineAbility), the charge-holding Combustion buff on self, 3 min recast |
| 28682 | Combustion |  | MAGE | name-map | 190319 | accept | Combustion crit-stack aura on self, triggered by the MAGE Fire talent 11129 (EffectTriggerSpell), shows beside the cast's buff |
| 1259817 | Eureka! |  | MAGE | db2-effect |  | reject | Eureka! is the Gnome racial (Racial - Gnome skill line, race mask 64): belongs in Racials |
| 12043 | Presence of Mind |  | MAGE | hand |  | accept | Presence of Mind, MAGE Arcane talent (Talent + SkillLineAbility), next-spell instant-cast aura (A108) on self, 3 min recast, a burst cooldown like Arcane Power |
| 18288 | Amplify Curse |  | WARLOCK | db2-effect |  | accept | Amplify Curse, WARLOCK Affliction talent (Talent + SkillLineAbility), curse-amplify aura on self, 3 min recast: the warlock's damage cooldown |
| 1259821 | Eureka! |  | WARLOCK | db2-effect |  | reject | Eureka! is the Gnome racial (Racial - Gnome skill line, race mask 64): belongs in Racials |
| 20554 | Berserking |  | ALL | db2-effect |  | reject | Berserking is the Troll racial (Racial - Troll skill line): belongs in Racials, where Retail lists Berserking 26297 |

## `healing` (BUFF): 117 candidates, 73 accepted

| Id | Name | Rank | Class | Source | Origin | Ruling | Reason |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 16488 | Blood Craze |  | WARRIOR | db2-effect |  | reject | Blood Craze talent proc (16487, WARRIOR Fury talent) self-only passive regen, not a heal-over-time placed on allies as the Retail list uses |
| 412020 | Flash of Light |  | PALADIN | db2-effect |  | reject | Flash of Light HoT granted by the Sacred Shield rune (412019, Engrave Boots - Sacred Shield); rune ability, owner ruling excludes |
| 1277456 | Contingency Plan | Rank 1 | PRIEST | db2-effect |  | accept | rank 1 of Contingency Plan heal-over-time (aura 8 on ally), triggered by PRIEST Discipline-line ward 1277462/1277634..; not a rune |
| 1277457 | Contingency Plan | Rank 2 | PRIEST | db2-effect |  | accept | rank 2 of Contingency Plan heal-over-time (aura 8 on ally), triggered by PRIEST Discipline-line ward 1277462/1277634..; not a rune |
| 1277458 | Contingency Plan | Rank 3 | PRIEST | db2-effect |  | accept | rank 3 of Contingency Plan heal-over-time (aura 8 on ally), triggered by PRIEST Discipline-line ward 1277462/1277634..; not a rune |
| 1277459 | Contingency Plan | Rank 4 | PRIEST | db2-effect |  | accept | rank 4 of Contingency Plan heal-over-time (aura 8 on ally), triggered by PRIEST Discipline-line ward 1277462/1277634..; not a rune |
| 1277460 | Contingency Plan | Rank 5 | PRIEST | db2-effect |  | accept | rank 5 of Contingency Plan heal-over-time (aura 8 on ally), triggered by PRIEST Discipline-line ward 1277462/1277634..; not a rune |
| 1277463 | Contingency Plan | Rank 1 | PRIEST | db2-effect |  | accept | rank 1 of Contingency Plan absorb shield (aura 69 on ally), triggered by PRIEST Discipline-line ward; not a rune |
| 1277464 | Contingency Plan | Rank 2 | PRIEST | db2-effect |  | accept | rank 2 of Contingency Plan absorb shield (aura 69 on ally), triggered by PRIEST Discipline-line ward; not a rune |
| 1277465 | Contingency Plan | Rank 3 | PRIEST | db2-effect |  | accept | rank 3 of Contingency Plan absorb shield (aura 69 on ally), triggered by PRIEST Discipline-line ward; not a rune |
| 1277466 | Contingency Plan | Rank 5 | PRIEST | db2-effect |  | accept | rank 5 of Contingency Plan absorb shield (aura 69 on ally), triggered by PRIEST Discipline-line ward; not a rune |
| 1277467 | Contingency Plan | Rank 4 | PRIEST | db2-effect |  | accept | rank 4 of Contingency Plan absorb shield (aura 69 on ally), triggered by PRIEST Discipline-line ward; not a rune |
| 22009 | Greater Heal |  | PRIEST | db2-effect |  | reject | Greater Heal HoT from 'Greater Heal Renew' 22010, an item set bonus with no class skill line; item effect |
| 7001 | Lightwell Renew | Rank 1 | PRIEST | db2-effect |  | accept | rank 1 Lightwell Renew, PRIEST Holy SkillLineAbility (Lightwell talent), periodic heal aura on the ally who clicks |
| 27873 | Lightwell Renew | Rank 2 | PRIEST | db2-effect |  | accept | rank 2 Lightwell Renew, PRIEST Holy SkillLineAbility (Lightwell talent rank), periodic heal aura on ally |
| 27874 | Lightwell Renew | Rank 3 | PRIEST | db2-effect |  | accept | rank 3 Lightwell Renew, PRIEST Holy SkillLineAbility (Lightwell talent rank), periodic heal aura on ally |
| 17 | Power Word: Shield | Rank 1 | PRIEST | name-map | 17 | accept | rank 1 of Power Word: Shield, PRIEST Discipline SkillLineAbility, absorb aura (69) on ally |
| 592 | Power Word: Shield | Rank 2 | PRIEST | name-map | 17 | accept | rank 2 of Power Word: Shield, PRIEST Discipline SkillLineAbility, absorb aura (69) on ally |
| 600 | Power Word: Shield | Rank 3 | PRIEST | name-map | 17 | accept | rank 3 of Power Word: Shield, PRIEST Discipline SkillLineAbility, absorb aura (69) on ally |
| 3747 | Power Word: Shield | Rank 4 | PRIEST | name-map | 17 | accept | rank 4 of Power Word: Shield, PRIEST Discipline SkillLineAbility, absorb aura (69) on ally |
| 6065 | Power Word: Shield | Rank 5 | PRIEST | name-map | 17 | accept | rank 5 of Power Word: Shield, PRIEST Discipline SkillLineAbility, absorb aura (69) on ally |
| 6066 | Power Word: Shield | Rank 6 | PRIEST | name-map | 17 | accept | rank 6 of Power Word: Shield, PRIEST Discipline SkillLineAbility, absorb aura (69) on ally |
| 10898 | Power Word: Shield | Rank 7 | PRIEST | name-map | 17 | accept | rank 7 of Power Word: Shield, PRIEST Discipline SkillLineAbility, absorb aura (69) on ally |
| 10899 | Power Word: Shield | Rank 8 | PRIEST | name-map | 17 | accept | rank 8 of Power Word: Shield, PRIEST Discipline SkillLineAbility, absorb aura (69) on ally |
| 10900 | Power Word: Shield | Rank 9 | PRIEST | name-map | 17 | accept | rank 9 of Power Word: Shield, PRIEST Discipline SkillLineAbility, absorb aura (69) on ally |
| 10901 | Power Word: Shield | Rank 10 | PRIEST | name-map | 17 | accept | rank 10 of Power Word: Shield, PRIEST Discipline SkillLineAbility, absorb aura (69) on ally |
| 27607 | Power Word: Shield | Rank 10 | PRIEST | name-map | 17 | reject | Power Word: Shield duplicate 'Rank 10' (bp 942) with no SkillLineAbility or trigger; NPC copy of the player spell 10901 |
| 1236154 | Power Word: Shield | Rank 10 | PRIEST | name-map | 17 | reject | Power Word: Shield 18000-point copy with no SkillLineAbility or trigger; NPC/encounter copy |
| 139 | Renew | Rank 1 | PRIEST | name-map | 139 | accept | rank 1 of Renew, PRIEST Holy SkillLineAbility, periodic heal aura (8) on ally |
| 6074 | Renew | Rank 2 | PRIEST | name-map | 139 | accept | rank 2 of Renew, PRIEST Holy SkillLineAbility, periodic heal aura (8) on ally |
| 6075 | Renew | Rank 3 | PRIEST | name-map | 139 | accept | rank 3 of Renew, PRIEST Holy SkillLineAbility, periodic heal aura (8) on ally |
| 6076 | Renew | Rank 4 | PRIEST | name-map | 139 | accept | rank 4 of Renew, PRIEST Holy SkillLineAbility, periodic heal aura (8) on ally |
| 6077 | Renew | Rank 5 | PRIEST | name-map | 139 | accept | rank 5 of Renew, PRIEST Holy SkillLineAbility, periodic heal aura (8) on ally |
| 6078 | Renew | Rank 6 | PRIEST | name-map | 139 | accept | rank 6 of Renew, PRIEST Holy SkillLineAbility, periodic heal aura (8) on ally |
| 10927 | Renew | Rank 7 | PRIEST | name-map | 139 | accept | rank 7 of Renew, PRIEST Holy SkillLineAbility, periodic heal aura (8) on ally |
| 10928 | Renew | Rank 8 | PRIEST | name-map | 139 | accept | rank 8 of Renew, PRIEST Holy SkillLineAbility, periodic heal aura (8) on ally |
| 10929 | Renew | Rank 9 | PRIEST | name-map | 139 | accept | rank 9 of Renew, PRIEST Holy SkillLineAbility, periodic heal aura (8) on ally |
| 25315 | Renew | Rank 10 | PRIEST | name-map | 139 | accept | rank 10 of Renew, PRIEST Holy SkillLineAbility, periodic heal aura (8) on ally |
| 27606 | Renew | Rank 9 | PRIEST | name-map | 139 | reject | Renew duplicate 'Rank 9' with no SkillLineAbility or trigger; NPC copy of player 10929 |
| 28807 | Renew |  | PRIEST | name-map | 139 | reject | Renew mana-cost passive (aura 108 on self, item set bonus), never a heal aura on a unit |
| 425268 | Renew | Rank 1 | PRIEST | name-map | 139 | reject | Renew rank 1 override installed by Empowered Renew 425266 (aura 332 action-bar override); rune ability variant, owner ruling excludes |
| 425269 | Renew | Rank 2 | PRIEST | name-map | 139 | reject | Renew rank 2 override installed by Empowered Renew 425266 (aura 332 action-bar override); rune ability variant, owner ruling excludes |
| 425270 | Renew | Rank 3 | PRIEST | name-map | 139 | reject | Renew rank 3 override installed by Empowered Renew 425266 (aura 332 action-bar override); rune ability variant, owner ruling excludes |
| 425271 | Renew | Rank 4 | PRIEST | name-map | 139 | reject | Renew rank 4 override installed by Empowered Renew 425266 (aura 332 action-bar override); rune ability variant, owner ruling excludes |
| 425272 | Renew | Rank 5 | PRIEST | name-map | 139 | reject | Renew rank 5 override installed by Empowered Renew 425266 (aura 332 action-bar override); rune ability variant, owner ruling excludes |
| 425273 | Renew | Rank 6 | PRIEST | name-map | 139 | reject | Renew rank 6 override installed by Empowered Renew 425266 (aura 332 action-bar override); rune ability variant, owner ruling excludes |
| 425274 | Renew | Rank 7 | PRIEST | name-map | 139 | reject | Renew rank 7 override installed by Empowered Renew 425266 (aura 332 action-bar override); rune ability variant, owner ruling excludes |
| 425275 | Renew | Rank 8 | PRIEST | name-map | 139 | reject | Renew rank 8 override installed by Empowered Renew 425266 (aura 332 action-bar override); rune ability variant, owner ruling excludes |
| 425276 | Renew | Rank 9 | PRIEST | name-map | 139 | reject | Renew rank 9 override installed by Empowered Renew 425266 (aura 332 action-bar override); rune ability variant, owner ruling excludes |
| 425277 | Renew | Rank 10 | PRIEST | name-map | 139 | reject | Renew rank 10 override installed by Empowered Renew 425266 (aura 332 action-bar override); rune ability variant, owner ruling excludes |
| 1236151 | Renew | Rank 9 | PRIEST | name-map | 139 | reject | Renew 2500-point copy with no SkillLineAbility or trigger; NPC/encounter copy |
| 1289450 | Renew | Rank 9 | PRIEST | name-map | 139 | reject | Renew 'Rank 9' copy (bp 35) with no SkillLineAbility, trigger or override edge; not reachable by a player priest |
| 412214 | Fire Ward | Rank 1 | MAGE | db2-effect |  | reject | Fire Ward rank 1 friendly-target override from the Advanced Warding rune 412115 (aura 332); rune ability, excluded |
| 412218 | Fire Ward | Rank 2 | MAGE | db2-effect |  | reject | Fire Ward rank 2 friendly-target override from the Advanced Warding rune 412115 (aura 332); rune ability, excluded |
| 412230 | Fire Ward | Rank 3 | MAGE | db2-effect |  | reject | Fire Ward rank 3 friendly-target override from the Advanced Warding rune 412115 (aura 332); rune ability, excluded |
| 412231 | Fire Ward | Rank 4 | MAGE | db2-effect |  | reject | Fire Ward rank 4 friendly-target override from the Advanced Warding rune 412115 (aura 332); rune ability, excluded |
| 412232 | Fire Ward | Rank 5 | MAGE | db2-effect |  | reject | Fire Ward rank 5 friendly-target override from the Advanced Warding rune 412115 (aura 332); rune ability, excluded |
| 412202 | Frost Ward | Rank 1 | MAGE | db2-effect |  | reject | Frost Ward rank 1 friendly-target override from the Advanced Warding rune 412115 (aura 332); rune ability, excluded |
| 412205 | Frost Ward | Rank 2 | MAGE | db2-effect |  | reject | Frost Ward rank 2 friendly-target override from the Advanced Warding rune 412115 (aura 332); rune ability, excluded |
| 412207 | Frost Ward | Rank 3 | MAGE | db2-effect |  | reject | Frost Ward rank 3 friendly-target override from the Advanced Warding rune 412115 (aura 332); rune ability, excluded |
| 412209 | Frost Ward | Rank 4 | MAGE | db2-effect |  | reject | Frost Ward rank 4 friendly-target override from the Advanced Warding rune 412115 (aura 332); rune ability, excluded |
| 412210 | Frost Ward | Rank 5 | MAGE | db2-effect |  | reject | Frost Ward rank 5 friendly-target override from the Advanced Warding rune 412115 (aura 332); rune ability, excluded |
| 412116 | Mana Shield | Rank 1 | MAGE | db2-effect |  | reject | Mana Shield rank 1 friendly-target override from the Advanced Warding rune 412115 (aura 332); rune ability, excluded |
| 412118 | Mana Shield | Rank 2 | MAGE | db2-effect |  | reject | Mana Shield rank 2 friendly-target override from the Advanced Warding rune 412115 (aura 332); rune ability, excluded |
| 412120 | Mana Shield | Rank 3 | MAGE | db2-effect |  | reject | Mana Shield rank 3 friendly-target override from the Advanced Warding rune 412115 (aura 332); rune ability, excluded |
| 412121 | Mana Shield | Rank 4 | MAGE | db2-effect |  | reject | Mana Shield rank 4 friendly-target override from the Advanced Warding rune 412115 (aura 332); rune ability, excluded |
| 412122 | Mana Shield | Rank 5 | MAGE | db2-effect |  | reject | Mana Shield rank 5 friendly-target override from the Advanced Warding rune 412115 (aura 332); rune ability, excluded |
| 412123 | Mana Shield | Rank 6 | MAGE | db2-effect |  | reject | Mana Shield rank 6 friendly-target override from the Advanced Warding rune 412115 (aura 332); rune ability, excluded |
| 8936 | Regrowth | Rank 1 | DRUID | name-map | 8936 | accept | rank 1 of Regrowth, DRUID Restoration SkillLineAbility, direct heal plus periodic heal aura (8) on ally |
| 8938 | Regrowth | Rank 2 | DRUID | name-map | 8936 | accept | rank 2 of Regrowth, DRUID Restoration SkillLineAbility, direct heal plus periodic heal aura (8) on ally |
| 8939 | Regrowth | Rank 3 | DRUID | name-map | 8936 | accept | rank 3 of Regrowth, DRUID Restoration SkillLineAbility, direct heal plus periodic heal aura (8) on ally |
| 8940 | Regrowth | Rank 4 | DRUID | name-map | 8936 | accept | rank 4 of Regrowth, DRUID Restoration SkillLineAbility, direct heal plus periodic heal aura (8) on ally |
| 8941 | Regrowth | Rank 5 | DRUID | name-map | 8936 | accept | rank 5 of Regrowth, DRUID Restoration SkillLineAbility, direct heal plus periodic heal aura (8) on ally |
| 9750 | Regrowth | Rank 6 | DRUID | name-map | 8936 | accept | rank 6 of Regrowth, DRUID Restoration SkillLineAbility, direct heal plus periodic heal aura (8) on ally |
| 9856 | Regrowth | Rank 7 | DRUID | name-map | 8936 | accept | rank 7 of Regrowth, DRUID Restoration SkillLineAbility, direct heal plus periodic heal aura (8) on ally |
| 9857 | Regrowth | Rank 8 | DRUID | name-map | 8936 | accept | rank 8 of Regrowth, DRUID Restoration SkillLineAbility, direct heal plus periodic heal aura (8) on ally |
| 9858 | Regrowth | Rank 9 | DRUID | name-map | 8936 | accept | rank 9 of Regrowth, DRUID Restoration SkillLineAbility, direct heal plus periodic heal aura (8) on ally |
| 28744 | Regrowth |  | DRUID | name-map | 8936 | reject | Regrowth passive item-set bonus (aura 112 on self), never shows as a heal aura |
| 436937 | Regrowth | Rank 1 | DRUID | name-map | 8936 | accept | Regrowth rank 1 override from Enhanced Restoration 417123 (DRUID Restoration SkillLineAbility, not a rune), periodic heal aura on ally |
| 436938 | Regrowth | Rank 2 | DRUID | name-map | 8936 | accept | Regrowth rank 2 override from Enhanced Restoration 417123 (DRUID Restoration SkillLineAbility, not a rune), periodic heal aura on ally |
| 436939 | Regrowth | Rank 3 | DRUID | name-map | 8936 | accept | Regrowth rank 3 override from Enhanced Restoration 417123 (DRUID Restoration SkillLineAbility, not a rune), periodic heal aura on ally |
| 436940 | Regrowth | Rank 4 | DRUID | name-map | 8936 | accept | Regrowth rank 4 override from Enhanced Restoration 417123 (DRUID Restoration SkillLineAbility, not a rune), periodic heal aura on ally |
| 436942 | Regrowth | Rank 5 | DRUID | name-map | 8936 | accept | Regrowth rank 5 override from Enhanced Restoration 417123 (DRUID Restoration SkillLineAbility, not a rune), periodic heal aura on ally |
| 436943 | Regrowth | Rank 6 | DRUID | name-map | 8936 | accept | Regrowth rank 6 override from Enhanced Restoration 417123 (DRUID Restoration SkillLineAbility, not a rune), periodic heal aura on ally |
| 436944 | Regrowth | Rank 7 | DRUID | name-map | 8936 | accept | Regrowth rank 7 override from Enhanced Restoration 417123 (DRUID Restoration SkillLineAbility, not a rune), periodic heal aura on ally |
| 436945 | Regrowth | Rank 8 | DRUID | name-map | 8936 | accept | Regrowth rank 8 override from Enhanced Restoration 417123 (DRUID Restoration SkillLineAbility, not a rune), periodic heal aura on ally |
| 436946 | Regrowth | Rank 9 | DRUID | name-map | 8936 | accept | Regrowth rank 9 override from Enhanced Restoration 417123 (DRUID Restoration SkillLineAbility, not a rune), periodic heal aura on ally |
| 774 | Rejuvenation | Rank 1 | DRUID | name-map | 774 | accept | rank 1 of Rejuvenation, DRUID Restoration SkillLineAbility, periodic heal aura (8) on ally |
| 1058 | Rejuvenation | Rank 2 | DRUID | name-map | 774 | accept | rank 2 of Rejuvenation, DRUID Restoration SkillLineAbility, periodic heal aura (8) on ally |
| 1430 | Rejuvenation | Rank 3 | DRUID | name-map | 774 | accept | rank 3 of Rejuvenation, DRUID Restoration SkillLineAbility, periodic heal aura (8) on ally |
| 2090 | Rejuvenation | Rank 4 | DRUID | name-map | 774 | accept | rank 4 of Rejuvenation, DRUID Restoration SkillLineAbility, periodic heal aura (8) on ally |
| 2091 | Rejuvenation | Rank 5 | DRUID | name-map | 774 | accept | rank 5 of Rejuvenation, DRUID Restoration SkillLineAbility, periodic heal aura (8) on ally |
| 3627 | Rejuvenation | Rank 6 | DRUID | name-map | 774 | accept | rank 6 of Rejuvenation, DRUID Restoration SkillLineAbility, periodic heal aura (8) on ally |
| 8910 | Rejuvenation | Rank 7 | DRUID | name-map | 774 | accept | rank 7 of Rejuvenation, DRUID Restoration SkillLineAbility, periodic heal aura (8) on ally |
| 9839 | Rejuvenation | Rank 8 | DRUID | name-map | 774 | accept | rank 8 of Rejuvenation, DRUID Restoration SkillLineAbility, periodic heal aura (8) on ally |
| 9840 | Rejuvenation | Rank 9 | DRUID | name-map | 774 | accept | rank 9 of Rejuvenation, DRUID Restoration SkillLineAbility, periodic heal aura (8) on ally |
| 9841 | Rejuvenation | Rank 10 | DRUID | name-map | 774 | accept | rank 10 of Rejuvenation, DRUID Restoration SkillLineAbility, periodic heal aura (8) on ally |
| 25299 | Rejuvenation | Rank 11 | DRUID | name-map | 774 | accept | rank 11 of Rejuvenation, DRUID Restoration SkillLineAbility, periodic heal aura (8) on ally |
| 28716 | Rejuvenation |  | DRUID | name-map | 774 | reject | Rejuvenation passive item-set bonus (aura 112 on self), never shows as a heal aura |
| 417057 | Rejuvenation | Rank 1 | DRUID | name-map | 774 | accept | Rejuvenation rank 1 override from Enhanced Restoration 417123 (DRUID Restoration SkillLineAbility, not a rune), periodic heal aura on ally |
| 417058 | Rejuvenation | Rank 2 | DRUID | name-map | 774 | accept | Rejuvenation rank 2 override from Enhanced Restoration 417123 (DRUID Restoration SkillLineAbility, not a rune), periodic heal aura on ally |
| 417059 | Rejuvenation | Rank 3 | DRUID | name-map | 774 | accept | Rejuvenation rank 3 override from Enhanced Restoration 417123 (DRUID Restoration SkillLineAbility, not a rune), periodic heal aura on ally |
| 417060 | Rejuvenation | Rank 4 | DRUID | name-map | 774 | accept | Rejuvenation rank 4 override from Enhanced Restoration 417123 (DRUID Restoration SkillLineAbility, not a rune), periodic heal aura on ally |
| 417061 | Rejuvenation | Rank 5 | DRUID | name-map | 774 | accept | Rejuvenation rank 5 override from Enhanced Restoration 417123 (DRUID Restoration SkillLineAbility, not a rune), periodic heal aura on ally |
| 417062 | Rejuvenation | Rank 6 | DRUID | name-map | 774 | accept | Rejuvenation rank 6 override from Enhanced Restoration 417123 (DRUID Restoration SkillLineAbility, not a rune), periodic heal aura on ally |
| 417063 | Rejuvenation | Rank 7 | DRUID | name-map | 774 | accept | Rejuvenation rank 7 override from Enhanced Restoration 417123 (DRUID Restoration SkillLineAbility, not a rune), periodic heal aura on ally |
| 417064 | Rejuvenation | Rank 8 | DRUID | name-map | 774 | accept | Rejuvenation rank 8 override from Enhanced Restoration 417123 (DRUID Restoration SkillLineAbility, not a rune), periodic heal aura on ally |
| 417065 | Rejuvenation | Rank 9 | DRUID | name-map | 774 | accept | Rejuvenation rank 9 override from Enhanced Restoration 417123 (DRUID Restoration SkillLineAbility, not a rune), periodic heal aura on ally |
| 417066 | Rejuvenation | Rank 10 | DRUID | name-map | 774 | accept | Rejuvenation rank 10 override from Enhanced Restoration 417123 (DRUID Restoration SkillLineAbility, not a rune), periodic heal aura on ally |
| 417068 | Rejuvenation | Rank 11 | DRUID | name-map | 774 | accept | Rejuvenation rank 11 override from Enhanced Restoration 417123 (DRUID Restoration SkillLineAbility, not a rune), periodic heal aura on ally |
| 740 | Tranquility | Rank 1 | DRUID | db2-effect |  | reject | rank 1 of Tranquility (DRUID Restoration); the Retail list places Tranquility in raidCDs (owner 2026-09-25), so it belongs there, not here |
| 8918 | Tranquility | Rank 2 | DRUID | db2-effect |  | reject | rank 2 of Tranquility (DRUID Restoration); the Retail list places Tranquility in raidCDs (owner 2026-09-25), so it belongs there, not here |
| 9862 | Tranquility | Rank 3 | DRUID | db2-effect |  | reject | rank 3 of Tranquility (DRUID Restoration); the Retail list places Tranquility in raidCDs (owner 2026-09-25), so it belongs there, not here |
| 9863 | Tranquility | Rank 4 | DRUID | db2-effect |  | reject | rank 4 of Tranquility (DRUID Restoration); the Retail list places Tranquility in raidCDs (owner 2026-09-25), so it belongs there, not here |
| 21791 | Tranquility |  | DRUID | db2-effect |  | reject | Tranquility copy with no SkillLineAbility or trigger (fixed 374 heal); NPC copy |
| 25817 | Tranquility |  | DRUID | db2-effect |  | reject | Tranquility copy with no SkillLineAbility or trigger (5847 heal); NPC/encounter copy |
| 1253568 | Tranquility |  | DRUID | db2-effect |  | reject | Tranquility copy with no SkillLineAbility or trigger (aura effect 6, not the player channel); NPC copy |

## `support` (BUFF): 13 candidates, 8 accepted

| Id | Name | Rank | Class | Source | Origin | Ruling | Reason |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1022 | Blessing of Protection | Rank 1 | PALADIN | db2-effect |  | reject | ruled into defensives (one category per id): Blessing of Protection is an external like Blessing of Sacrifice 6940/20729 (same Protection line, party target 57), and Retail's owner puts externals in Defensives, not Support |
| 5599 | Blessing of Protection | Rank 2 | PALADIN | db2-effect |  | reject | ruled into defensives (one category per id): Blessing of Protection is an external like Blessing of Sacrifice 6940/20729 (same Protection line, party target 57), and Retail's owner puts externals in Defensives, not Support |
| 10278 | Blessing of Protection | Rank 3 | PALADIN | db2-effect |  | reject | ruled into defensives (one category per id): Blessing of Protection is an external like Blessing of Sacrifice 6940/20729 (same Protection line, party target 57), and Retail's owner puts externals in Defensives, not Support |
| 1277462 | Contingency Plan | Rank 1 | PRIEST | db2-effect |  | accept | rank 1 of Contingency Plan, PRIEST Discipline SkillLineAbility (Gnome race mask), ward aura cast on an ally (T21) |
| 1277634 | Contingency Plan | Rank 2 | PRIEST | db2-effect |  | accept | rank 2 of Contingency Plan, PRIEST Discipline SkillLineAbility, ward aura cast on an ally |
| 1277638 | Contingency Plan | Rank 3 | PRIEST | db2-effect |  | accept | rank 3 of Contingency Plan, PRIEST Discipline SkillLineAbility, ward aura cast on an ally |
| 1277639 | Contingency Plan | Rank 4 | PRIEST | db2-effect |  | accept | rank 4 of Contingency Plan, PRIEST Discipline SkillLineAbility, ward aura cast on an ally |
| 1277640 | Contingency Plan | Rank 5 | PRIEST | db2-effect |  | accept | rank 5 of Contingency Plan, PRIEST Discipline SkillLineAbility, ward aura cast on an ally |
| 6346 | Fear Ward |  | PRIEST | db2-effect |  | accept | Fear Ward, PRIEST Holy SkillLineAbility (all races), fear-immunity ward aura cast on a friendly target, 3 min recast |
| 10060 | Power Infusion |  | PRIEST | name-map | 10060 | accept | Power Infusion, PRIEST Discipline talent (Talent + SkillLineAbility), +20% spell damage/healing aura cast on an ally (Retail lists it in Support) |
| 428713 | Barkskin |  | DRUID | db2-effect |  | reject | rune ability: ally-targeted Barkskin granted only by the Improved Barkskin rune (431388 override; Engrave Helm 431449) |
| 29166 | Innervate |  | DRUID | name-map | 29166 | accept | Innervate, DRUID Restoration SkillLineAbility, mana-regen aura cast on an ally (T21), 6 min recast (Retail lists it in Support) |
| 456195 | Innervate |  | DRUID | name-map | 29166 | reject | self-targeted Innervate copy with no SkillLineAbility/Talent/grant edge and no recast: not the player's (29166 is) |

## `groupBuffs` (BUFF): 73 candidates, 59 accepted

| Id | Name | Rank | Class | Source | Origin | Ruling | Reason |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 5242 | Battle Shout | Rank 2 | WARRIOR | name-map | 6673 | accept | rank 2 of Battle Shout, WARRIOR Fury SkillLineAbility, attack-power aura (99) on party/raid |
| 6192 | Battle Shout | Rank 3 | WARRIOR | name-map | 6673 | accept | rank 3 of Battle Shout, WARRIOR Fury SkillLineAbility, attack-power aura (99) on party/raid |
| 6673 | Battle Shout | Rank 1 | WARRIOR | name-map | 6673 | accept | rank 1 of Battle Shout, WARRIOR Fury SkillLineAbility, attack-power aura (99) on party/raid |
| 11549 | Battle Shout | Rank 4 | WARRIOR | name-map | 6673 | accept | rank 4 of Battle Shout, WARRIOR Fury SkillLineAbility, attack-power aura (99) on party/raid |
| 11550 | Battle Shout | Rank 5 | WARRIOR | name-map | 6673 | accept | rank 5 of Battle Shout, WARRIOR Fury SkillLineAbility, attack-power aura (99) on party/raid |
| 11551 | Battle Shout | Rank 6 | WARRIOR | name-map | 6673 | accept | rank 6 of Battle Shout, WARRIOR Fury SkillLineAbility, attack-power aura (99) on party/raid |
| 25289 | Battle Shout | Rank 7 | WARRIOR | name-map | 6673 | accept | rank 7 of Battle Shout, WARRIOR Fury SkillLineAbility, attack-power aura (99) on party/raid |
| 27578 | Battle Shout | Rank 6 | WARRIOR | name-map | 6673 | reject | Battle Shout duplicate 'Rank 6' (bp 185, party-only target) with no SkillLineAbility or trigger; NPC copy |
| 20217 | Blessing of Kings |  | PALADIN | hand |  | accept | Blessing of Kings, PALADIN Protection talent (Talent + SkillLineAbility), +10% stats buff on one ally: the paladin's maintained group buff |
| 19740 | Blessing of Might | Rank 1 | PALADIN | hand |  | accept | rank 1 of Blessing of Might, PALADIN Retribution SkillLineAbility, 5 min buff on one ally (T21): the paladin's maintained group buff, the vanilla analogue of Battle Shout |
| 19834 | Blessing of Might | Rank 2 | PALADIN | hand |  | accept | rank 2 of Blessing of Might, PALADIN Retribution SkillLineAbility, 5 min buff on one ally (T21): the paladin's maintained group buff, the vanilla analogue of Battle Shout |
| 19835 | Blessing of Might | Rank 3 | PALADIN | hand |  | accept | rank 3 of Blessing of Might, PALADIN Retribution SkillLineAbility, 5 min buff on one ally (T21): the paladin's maintained group buff, the vanilla analogue of Battle Shout |
| 19836 | Blessing of Might | Rank 4 | PALADIN | hand |  | accept | rank 4 of Blessing of Might, PALADIN Retribution SkillLineAbility, 5 min buff on one ally (T21): the paladin's maintained group buff, the vanilla analogue of Battle Shout |
| 19837 | Blessing of Might | Rank 5 | PALADIN | hand |  | accept | rank 5 of Blessing of Might, PALADIN Retribution SkillLineAbility, 5 min buff on one ally (T21): the paladin's maintained group buff, the vanilla analogue of Battle Shout |
| 19838 | Blessing of Might | Rank 6 | PALADIN | hand |  | accept | rank 6 of Blessing of Might, PALADIN Retribution SkillLineAbility, 5 min buff on one ally (T21): the paladin's maintained group buff, the vanilla analogue of Battle Shout |
| 25291 | Blessing of Might | Rank 7 | PALADIN | hand |  | accept | rank 7 of Blessing of Might, PALADIN Retribution SkillLineAbility, 5 min buff on one ally (T21): the paladin's maintained group buff, the vanilla analogue of Battle Shout |
| 19742 | Blessing of Wisdom | Rank 1 | PALADIN | hand |  | accept | rank 1 of Blessing of Wisdom, PALADIN Holy SkillLineAbility, 5 min buff on one ally (T21): the paladin's maintained group buff, the vanilla analogue of Battle Shout |
| 19850 | Blessing of Wisdom | Rank 2 | PALADIN | hand |  | accept | rank 2 of Blessing of Wisdom, PALADIN Holy SkillLineAbility, 5 min buff on one ally (T21): the paladin's maintained group buff, the vanilla analogue of Battle Shout |
| 19852 | Blessing of Wisdom | Rank 3 | PALADIN | hand |  | accept | rank 3 of Blessing of Wisdom, PALADIN Holy SkillLineAbility, 5 min buff on one ally (T21): the paladin's maintained group buff, the vanilla analogue of Battle Shout |
| 19853 | Blessing of Wisdom | Rank 4 | PALADIN | hand |  | accept | rank 4 of Blessing of Wisdom, PALADIN Holy SkillLineAbility, 5 min buff on one ally (T21): the paladin's maintained group buff, the vanilla analogue of Battle Shout |
| 19854 | Blessing of Wisdom | Rank 5 | PALADIN | hand |  | accept | rank 5 of Blessing of Wisdom, PALADIN Holy SkillLineAbility, 5 min buff on one ally (T21): the paladin's maintained group buff, the vanilla analogue of Battle Shout |
| 25290 | Blessing of Wisdom | Rank 6 | PALADIN | hand |  | accept | rank 6 of Blessing of Wisdom, PALADIN Holy SkillLineAbility, 5 min buff on one ally (T21): the paladin's maintained group buff, the vanilla analogue of Battle Shout |
| 25898 | Greater Blessing of Kings |  | PALADIN | hand |  | accept | Greater Blessing of Kings, PALADIN SkillLineAbility, 15 min class-wide buff (T153): the paladin's raid buff |
| 25782 | Greater Blessing of Might | Rank 1 | PALADIN | hand |  | accept | rank 1 of Greater Blessing of Might, PALADIN SkillLineAbility, 15 min class-wide buff (T153): the paladin's raid buff |
| 25916 | Greater Blessing of Might | Rank 2 | PALADIN | hand |  | accept | rank 2 of Greater Blessing of Might, PALADIN SkillLineAbility, 15 min class-wide buff (T153): the paladin's raid buff |
| 25894 | Greater Blessing of Wisdom | Rank 1 | PALADIN | hand |  | accept | rank 1 of Greater Blessing of Wisdom, PALADIN SkillLineAbility, 15 min class-wide buff (T153): the paladin's raid buff |
| 25918 | Greater Blessing of Wisdom | Rank 2 | PALADIN | hand |  | accept | rank 2 of Greater Blessing of Wisdom, PALADIN SkillLineAbility, 15 min class-wide buff (T153): the paladin's raid buff |
| 425600 | Horn of Lordaeron |  | PALADIN | db2-effect |  | accept | Horn of Lordaeron, PALADIN Holy SkillLineAbility (not a rune name), Strength/Agility aura on party members; the paladin's shout-style group buff |
| 24597 | Furious Howl | Rank 4 | HUNTER | db2-effect |  | reject | Furious Howl rank 4 is a wolf pet ability (Pet - Wolf line via Beast Training 2459x); a short pet buff, not a maintained raid buff |
| 24603 | Furious Howl | Rank 3 | HUNTER | db2-effect |  | reject | Furious Howl rank 3 is a wolf pet ability (Pet - Wolf line via Beast Training 2459x); a short pet buff, not a maintained raid buff |
| 24604 | Furious Howl | Rank 1 | HUNTER | db2-effect |  | reject | Furious Howl rank 1 is a wolf pet ability (Pet - Wolf line via Beast Training 2459x); a short pet buff, not a maintained raid buff |
| 24605 | Furious Howl | Rank 2 | HUNTER | db2-effect |  | reject | Furious Howl rank 2 is a wolf pet ability (Pet - Wolf line via Beast Training 2459x); a short pet buff, not a maintained raid buff |
| 14752 | Divine Spirit | Rank 1 | PRIEST | hand |  | accept | rank 1 of Divine Spirit, PRIEST Discipline talent line, Spirit buff on one ally: single-target twin of the accepted Prayer of Spirit 27681 |
| 14818 | Divine Spirit | Rank 2 | PRIEST | hand |  | accept | rank 2 of Divine Spirit, PRIEST Discipline talent line, Spirit buff on one ally: single-target twin of the accepted Prayer of Spirit 27681 |
| 14819 | Divine Spirit | Rank 3 | PRIEST | hand |  | accept | rank 3 of Divine Spirit, PRIEST Discipline talent line, Spirit buff on one ally: single-target twin of the accepted Prayer of Spirit 27681 |
| 27841 | Divine Spirit | Rank 4 | PRIEST | hand |  | accept | rank 4 of Divine Spirit, PRIEST Discipline talent line, Spirit buff on one ally: single-target twin of the accepted Prayer of Spirit 27681 |
| 1243 | Power Word: Fortitude | Rank 1 | PRIEST | name-map | 21562 | accept | rank 1 of Power Word: Fortitude, PRIEST Discipline SkillLineAbility, Stamina aura (29) on ally |
| 1244 | Power Word: Fortitude | Rank 2 | PRIEST | name-map | 21562 | accept | rank 2 of Power Word: Fortitude, PRIEST Discipline SkillLineAbility, Stamina aura (29) on ally |
| 1245 | Power Word: Fortitude | Rank 3 | PRIEST | name-map | 21562 | accept | rank 3 of Power Word: Fortitude, PRIEST Discipline SkillLineAbility, Stamina aura (29) on ally |
| 2791 | Power Word: Fortitude | Rank 4 | PRIEST | name-map | 21562 | accept | rank 4 of Power Word: Fortitude, PRIEST Discipline SkillLineAbility, Stamina aura (29) on ally |
| 10937 | Power Word: Fortitude | Rank 5 | PRIEST | name-map | 21562 | accept | rank 5 of Power Word: Fortitude, PRIEST Discipline SkillLineAbility, Stamina aura (29) on ally |
| 10938 | Power Word: Fortitude | Rank 6 | PRIEST | name-map | 21562 | accept | rank 6 of Power Word: Fortitude, PRIEST Discipline SkillLineAbility, Stamina aura (29) on ally |
| 23947 | Power Word: Fortitude | Rank 5 | PRIEST | name-map | 21562 | reject | Power Word: Fortitude copy (target 25, $M1 text) with no SkillLineAbility or trigger; NPC copy |
| 23948 | Power Word: Fortitude | Rank 6 | PRIEST | name-map | 21562 | reject | Power Word: Fortitude copy (target 25, $M1 text) with no SkillLineAbility or trigger; NPC copy |
| 21562 | Prayer of Fortitude | Rank 1 | PRIEST | db2-effect |  | accept | rank 1 of Prayer of Fortitude, PRIEST Discipline SkillLineAbility, Stamina aura on party/raid |
| 21564 | Prayer of Fortitude | Rank 2 | PRIEST | db2-effect |  | accept | rank 2 of Prayer of Fortitude, PRIEST Discipline SkillLineAbility, Stamina aura on party/raid |
| 27683 | Prayer of Shadow Protection |  | PRIEST | db2-effect |  | accept | Prayer of Shadow Protection, PRIEST Shadow Magic SkillLineAbility, shadow-resistance aura on party/raid |
| 27681 | Prayer of Spirit | Rank 1 | PRIEST | db2-effect |  | accept | rank 1 of Prayer of Spirit, PRIEST Discipline SkillLineAbility, Spirit aura on party/raid |
| 976 | Shadow Protection | Rank 1 | PRIEST | hand |  | accept | rank 1 of Shadow Protection, PRIEST Shadow Magic SkillLineAbility, shadow-resist buff on one ally: single-target twin of the accepted Prayer of Shadow Protection 27683 |
| 10957 | Shadow Protection | Rank 2 | PRIEST | hand |  | accept | rank 2 of Shadow Protection, PRIEST Shadow Magic SkillLineAbility, shadow-resist buff on one ally: single-target twin of the accepted Prayer of Shadow Protection 27683 |
| 10958 | Shadow Protection | Rank 3 | PRIEST | hand |  | accept | rank 3 of Shadow Protection, PRIEST Shadow Magic SkillLineAbility, shadow-resist buff on one ally: single-target twin of the accepted Prayer of Shadow Protection 27683 |
| 23028 | Arcane Brilliance |  | MAGE | db2-effect |  | accept | Arcane Brilliance, MAGE Arcane SkillLineAbility, Intellect aura (29) on party/raid |
| 1459 | Arcane Intellect | Rank 1 | MAGE | name-map | 1459 | accept | rank 1 of Arcane Intellect, MAGE Arcane SkillLineAbility, Intellect aura (29) on ally |
| 1460 | Arcane Intellect | Rank 2 | MAGE | name-map | 1459 | accept | rank 2 of Arcane Intellect, MAGE Arcane SkillLineAbility, Intellect aura (29) on ally |
| 1461 | Arcane Intellect | Rank 3 | MAGE | name-map | 1459 | accept | rank 3 of Arcane Intellect, MAGE Arcane SkillLineAbility, Intellect aura (29) on ally |
| 10156 | Arcane Intellect | Rank 4 | MAGE | name-map | 1459 | accept | rank 4 of Arcane Intellect, MAGE Arcane SkillLineAbility, Intellect aura (29) on ally |
| 10157 | Arcane Intellect | Rank 5 | MAGE | name-map | 1459 | accept | rank 5 of Arcane Intellect, MAGE Arcane SkillLineAbility, Intellect aura (29) on ally |
| 13326 | Arcane Intellect |  | MAGE | name-map | 1459 | reject | Arcane Intellect copy (30-min index, 'an ally' text) with no SkillLineAbility or trigger; NPC copy |
| 16876 | Arcane Intellect | Rank 5 | MAGE | name-map | 1459 | reject | Arcane Intellect area copy (target 22/30, $M1 text) with no SkillLineAbility or trigger; NPC copy |
| 364161 | Arcane Intellect | Rank 2 | MAGE | name-map | 1459 | reject | Arcane Intellect duplicate 'Rank 2' with no SkillLineAbility, trigger or override edge; not player-reachable |
| 21849 | Gift of the Wild | Rank 1 | DRUID | db2-effect |  | accept | rank 1 of Gift of the Wild, DRUID Restoration SkillLineAbility, armor/stats/resist aura on party/raid |
| 21850 | Gift of the Wild | Rank 2 | DRUID | db2-effect |  | accept | rank 2 of Gift of the Wild, DRUID Restoration SkillLineAbility, armor/stats/resist aura on party/raid |
| 1126 | Mark of the Wild | Rank 1 | DRUID | name-map | 1126 | accept | rank 1 of Mark of the Wild, DRUID Restoration SkillLineAbility, armor/stats aura on ally |
| 5232 | Mark of the Wild | Rank 2 | DRUID | name-map | 1126 | accept | rank 2 of Mark of the Wild, DRUID Restoration SkillLineAbility, armor/stats aura on ally |
| 5234 | Mark of the Wild | Rank 4 | DRUID | name-map | 1126 | accept | rank 4 of Mark of the Wild, DRUID Restoration SkillLineAbility, armor/stats aura on ally |
| 6756 | Mark of the Wild | Rank 3 | DRUID | name-map | 1126 | accept | rank 3 of Mark of the Wild, DRUID Restoration SkillLineAbility, armor/stats aura on ally |
| 8907 | Mark of the Wild | Rank 5 | DRUID | name-map | 1126 | accept | rank 5 of Mark of the Wild, DRUID Restoration SkillLineAbility, armor/stats aura on ally |
| 9884 | Mark of the Wild | Rank 6 | DRUID | name-map | 1126 | accept | rank 6 of Mark of the Wild, DRUID Restoration SkillLineAbility, armor/stats aura on ally |
| 9885 | Mark of the Wild | Rank 7 | DRUID | name-map | 1126 | accept | rank 7 of Mark of the Wild, DRUID Restoration SkillLineAbility, armor/stats aura on ally |
| 24752 | Mark of the Wild | Rank 7 | DRUID | name-map | 1126 | reject | Mark of the Wild 'Rank 7' copy (target 25, aura 558) with no SkillLineAbility or trigger; NPC copy |
| 364163 | Mark of the Wild | Rank 6 | DRUID | name-map | 1126 | reject | Mark of the Wild duplicate 'Rank 6' with no SkillLineAbility, trigger or override edge; not player-reachable |
| 1291335 | Mark of the Wild | Rank 7 | DRUID | name-map | 1126 | reject | Mark of the Wild 'Rank 7' self-target copy (no cast attributes) with no SkillLineAbility or trigger; NPC/item copy |
| 1310503 | Mark of the Wild | Rank 7 | DRUID | name-map | 1126 | reject | Mark of the Wild 'Rank 7' area copy (target 22/30) with no SkillLineAbility or trigger; NPC copy |

## `movement` (BUFF): 39 candidates, 15 accepted

| Id | Name | Rank | Class | Source | Origin | Ruling | Reason |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 23881 | Bloodthirst | Rank 1 | WARRIOR | db2-effect |  | accept | rank 1 of Bloodthirst, WARRIOR Fury SkillLineAbility/talent; on Forever it also applies a 10% self speed aura (31) under this id, like Retail's Relentless Pursuit |
| 23892 | Bloodthirst | Rank 2 | WARRIOR | db2-effect |  | accept | rank 2 of Bloodthirst, WARRIOR Fury SkillLineAbility/talent; on Forever it also applies a 10% self speed aura (31) under this id, like Retail's Relentless Pursuit |
| 23893 | Bloodthirst | Rank 3 | WARRIOR | db2-effect |  | accept | rank 3 of Bloodthirst, WARRIOR Fury SkillLineAbility/talent; on Forever it also applies a 10% self speed aura (31) under this id, like Retail's Relentless Pursuit |
| 23894 | Bloodthirst | Rank 4 | WARRIOR | db2-effect |  | accept | rank 4 of Bloodthirst, WARRIOR Fury SkillLineAbility/talent; on Forever it also applies a 10% self speed aura (31) under this id, like Retail's Relentless Pursuit |
| 411684 | Charge |  | WARRIOR | db2-effect |  | reject | Charge variant (411xxx) with no SkillLineAbility or Talent: rune/scripted copy, not the player Charge |
| 438538 | Charge |  | WARRIOR | db2-effect |  | reject | Charge copy with no SkillLineAbility or Talent, triggered only by NPC copy 438541 |
| 438541 | Charge |  | WARRIOR | db2-effect |  | reject | Charge copy with no SkillLineAbility or Talent: NPC/scripted duplicate |
| 12323 | Piercing Howl |  | WARRIOR | name-map | 1244157 | reject | Piercing Howl on Forever is a snare on enemies (aura 33, mechanic daze), not Retail's ally speed buff 1244157; it belongs in ccSnare |
| 23600 | Piercing Howl |  | WARRIOR | name-map | 1244157 | reject | Piercing Howl NPC copy, no SkillLineAbility or Talent; enemy snare anyway |
| 1044 | Blessing of Freedom |  | PALADIN | name-map | 1044 | accept | Blessing of Freedom, PALADIN Protection SkillLineAbility, snare/root immunity aura (77) on a friendly target, Retail lists it in Movement |
| 26022 | Pursuit of Justice |  | PALADIN | db2-effect |  | reject | Pursuit of Justice, passive and hidden talent aura, never shows as a buff |
| 5118 | Aspect of the Cheetah |  | HUNTER | name-map | 186257 | accept | Aspect of the Cheetah, HUNTER Beast Mastery SkillLineAbility, self speed aura (31), Retail lists it in Movement |
| 13159 | Aspect of the Pack |  | HUNTER | db2-effect |  | accept | Aspect of the Pack, HUNTER Beast Mastery SkillLineAbility, party-area speed aura (31); a speed effect, so Movement not Stances (Retail has no hunter stances) |
| 23099 | Dash | Rank 1 | HUNTER | db2-effect |  | reject | pet Dash, only on Pet - * skill lines (taught via Beast Training), an aura on the hunter pet, not a player-class aura |
| 23109 | Dash | Rank 2 | HUNTER | db2-effect |  | reject | pet Dash, only on Pet - * skill lines (taught via Beast Training), an aura on the hunter pet, not a player-class aura |
| 23110 | Dash | Rank 3 | HUNTER | db2-effect |  | reject | pet Dash, only on Pet - * skill lines (taught via Beast Training), an aura on the hunter pet, not a player-class aura |
| 23145 | Dive | Rank 1 | HUNTER | db2-effect |  | reject | pet Dive, only on Pet - * skill lines (taught via Beast Training), an aura on the hunter pet, not a player-class aura |
| 23147 | Dive | Rank 2 | HUNTER | db2-effect |  | reject | pet Dive, only on Pet - * skill lines (taught via Beast Training), an aura on the hunter pet, not a player-class aura |
| 23148 | Dive | Rank 3 | HUNTER | db2-effect |  | reject | pet Dive, only on Pet - * skill lines (taught via Beast Training), an aura on the hunter pet, not a player-class aura |
| 1317257 | Strider Kick |  | HUNTER | db2-effect |  | accept | Strider Kick, HUNTER Survival SkillLineAbility (not an Engrave rune), attack that applies a self speed aura (31) under the same id |
| 30918 | Improved Sprint |  | ROGUE | db2-effect |  | reject | Improved Sprint trigger: hidden-attribute 1s snare/root immunity from the talent proc, not shown as an aura |
| 2983 | Sprint | Rank 1 | ROGUE | name-map | 2983 | accept | rank 1 of Sprint, ROGUE Combat SkillLineAbility, self speed aura (31) |
| 8696 | Sprint | Rank 2 | ROGUE | name-map | 2983 | accept | rank 2 of Sprint, ROGUE Combat SkillLineAbility, self speed aura (31) |
| 11305 | Sprint | Rank 3 | ROGUE | name-map | 2983 | accept | rank 3 of Sprint, ROGUE Combat SkillLineAbility, self speed aura (31) |
| 18461 | Vanish Purge |  | ROGUE | db2-effect |  | reject | Vanish Purge, hidden-attribute 1s immunity triggered by Vanish, never shows as an aura |
| 2645 | Ghost Wolf |  | SHAMAN | name-map | 2645 | accept | Ghost Wolf, SHAMAN Enhancement SkillLineAbility, shapeshift plus speed aura (31); Retail keeps Ghost Wolf in Movement, not Stances |
| 415233 | Ghost Wolf |  | SHAMAN | name-map | 2645 | reject | Ghost Wolf variant referenced only by Greater Ghost Wolf 415813 (Season-of-Discovery rune line), no player SkillLineAbility; runes excluded |
| 1238640 | Ghost Wolf |  | SHAMAN | name-map | 2645 | accept | Ghost Wolf as cast with the SHAMAN Improved Ghost Wolf talent 16262 (Talent + Enhancement SkillLineAbility), whose override (aura 332) swaps 2645 for 1238640: self wolf form (36) and +40% speed (31), shown under this id |
| 1953 | Blink |  | MAGE | db2-effect |  | reject | Blink, MAGE Arcane: a teleport whose only aura is a 1s mechanic-immunity flash; Retail's Movement list leaves Blink out |
| 14514 | Blink |  | MAGE | db2-effect |  | reject | Blink copy with no SkillLineAbility, Talent or trigger path for a player: an NPC/scripted duplicate of 1953 |
| 21655 | Blink |  | MAGE | db2-effect |  | reject | Blink copy with no SkillLineAbility, Talent or trigger path for a player: an NPC/scripted duplicate of 1953 |
| 28391 | Blink |  | MAGE | db2-effect |  | reject | Blink copy with no SkillLineAbility, Talent or trigger path for a player: an NPC/scripted duplicate of 1953 |
| 29208 | Blink |  | MAGE | db2-effect |  | reject | Blink copy with no SkillLineAbility, Talent or trigger path for a player: an NPC/scripted duplicate of 1953 |
| 29209 | Blink |  | MAGE | db2-effect |  | reject | Blink copy with no SkillLineAbility, Talent or trigger path for a player: an NPC/scripted duplicate of 1953 |
| 29210 | Blink |  | MAGE | db2-effect |  | reject | Blink copy with no SkillLineAbility, Talent or trigger path for a player: an NPC/scripted duplicate of 1953 |
| 29211 | Blink |  | MAGE | db2-effect |  | reject | Blink copy with no SkillLineAbility, Talent or trigger path for a player: an NPC/scripted duplicate of 1953 |
| 1236175 | Blink |  | MAGE | db2-effect |  | reject | Blink copy with no SkillLineAbility, Talent or trigger path for a player: an NPC/scripted duplicate of 1953 |
| 1850 | Dash | Rank 1 | DRUID | name-map | 1850 | accept | rank 1 of Dash, DRUID Feral Combat SkillLineAbility, self speed aura (31) |
| 9821 | Dash | Rank 2 | DRUID | name-map | 1850 | accept | rank 2 of Dash, DRUID Feral Combat SkillLineAbility, self speed aura (31) |

## `utility` (BUFF): 35 candidates, 20 accepted

| Id | Name | Rank | Class | Source | Origin | Ruling | Reason |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 5384 | Feign Death |  | HUNTER | name-map | 5384 | accept | Feign Death, HUNTER Survival SkillLineAbility, self feign-death aura (66), Retail lists it in Utility |
| 24450 | Prowl | Rank 1 | HUNTER | db2-effect |  | reject | pet Prowl, only on Pet - Cat (taught via Beast Training), an aura on the hunter pet, not a player-class aura |
| 24452 | Prowl | Rank 2 | HUNTER | db2-effect |  | reject | pet Prowl, only on Pet - Cat (taught via Beast Training), an aura on the hunter pet, not a player-class aura |
| 24453 | Prowl | Rank 3 | HUNTER | db2-effect |  | reject | pet Prowl, only on Pet - Cat (taught via Beast Training), an aura on the hunter pet, not a player-class aura |
| 1860 | Safe Fall |  | ROGUE | db2-effect |  | reject | Safe Fall, passive fall-damage reduction, never shows as an aura |
| 1784 | Stealth | Rank 1 | ROGUE | name-map | 1784 | accept | rank 1 of Stealth, ROGUE Subtlety SkillLineAbility, self stealth aura (16), Retail lists Stealth in Utility |
| 1785 | Stealth | Rank 2 | ROGUE | name-map | 1784 | accept | rank 2 of Stealth, ROGUE Subtlety SkillLineAbility, self stealth aura (16), Retail lists Stealth in Utility |
| 1786 | Stealth | Rank 3 | ROGUE | name-map | 1784 | accept | rank 3 of Stealth, ROGUE Subtlety SkillLineAbility, self stealth aura (16), Retail lists Stealth in Utility |
| 1787 | Stealth | Rank 4 | ROGUE | name-map | 1784 | accept | rank 4 of Stealth, ROGUE Subtlety SkillLineAbility, self stealth aura (16), Retail lists Stealth in Utility |
| 450667 | Stealth | Rank 1 | ROGUE | name-map | 1784 | reject | Stealth copy with only a dummy aura (4) and no SkillLineAbility, Talent or trigger path for a player |
| 1256867 | Stealth | Rank 1 | ROGUE | name-map | 1784 | reject | Stealth copy with no SkillLineAbility, Talent or trigger path; the player Stealth is 1784-1787 |
| 1287162 | Stealth |  | ROGUE | name-map | 1784 | reject | Stealth copy with only a dummy aura (4) and no SkillLineAbility, Talent or trigger path for a player |
| 1290708 | Stealth | Rank 1 | ROGUE | name-map | 1784 | reject | Stealth copy with only a dummy aura (4) and no SkillLineAbility, Talent or trigger path for a player |
| 1318151 | Stealth |  | ROGUE | name-map | 1784 | reject | Stealth copy with only a dummy aura (4) and no SkillLineAbility, Talent or trigger path for a player |
| 1326175 | Stealth |  | ROGUE | name-map | 1784 | reject | Stealth copy with only a dummy aura (4) and no SkillLineAbility, Talent or trigger path for a player |
| 11327 | Vanish | Rank 1 | ROGUE | db2-effect |  | accept | Vanish rank 1's improved-stealth aura (16), triggered by ROGUE Vanish 1856; the cast leaves no aura, this is what shows |
| 11329 | Vanish | Rank 2 | ROGUE | db2-effect |  | accept | Vanish rank 2's improved-stealth aura (16), triggered by ROGUE Vanish 1857 |
| 1285372 | Vanish | Rank 3 | ROGUE | db2-effect |  | reject | Vanish 'rank 3' with no SkillLineAbility, Talent or teaching spell: unreachable for a player on this build |
| 1706 | Levitate |  | PRIEST | name-map | 111759 | accept | Levitate, PRIEST Discipline SkillLineAbility; on Forever the cast itself applies the levitate/water-walk auras (105/106/104), no separate 111759 aura |
| 461329 | Levitate |  | PRIEST | name-map | 111759 | reject | Levitate copy with no SkillLineAbility, Talent or trigger path; the player Levitate is 1706 |
| 27827 | Spirit of Redemption |  | PRIEST | db2-effect |  | reject | Spirit of Redemption, the death-state form from the passive talent 20711; Retail lists it in neither Utility nor Stances |
| 131 | Water Breathing |  | SHAMAN | db2-effect |  | accept | Water Breathing, SHAMAN Enhancement SkillLineAbility, water-breathing aura (82) on a friendly target, the same kind as Unending Breath |
| 546 | Water Walking |  | SHAMAN | name-map | 546 | accept | Water Walking, SHAMAN Enhancement SkillLineAbility, water-walk aura (104) on a friendly target, Retail lists it in Utility |
| 130 | Slow Fall |  | MAGE | name-map | 130 | accept | Slow Fall, MAGE Arcane SkillLineAbility, slow-fall aura (105), Retail lists it in Utility |
| 20707 | Soulstone Resurrection |  | WARLOCK | hand |  | accept | Soulstone Resurrection (Minor), the stored-soul aura on an ally (T21) cast from the WARLOCK's soulstone item (Create Soulstone, Demonology); Retail lists 20707 in Utility |
| 20762 | Soulstone Resurrection |  | WARLOCK | hand |  | accept | Soulstone Resurrection (Lesser), the stored-soul aura on an ally (T21) cast from the WARLOCK's soulstone item (Create Soulstone, Demonology); Retail lists 20707 in Utility |
| 20763 | Soulstone Resurrection |  | WARLOCK | hand |  | accept | Soulstone Resurrection (plain), the stored-soul aura on an ally (T21) cast from the WARLOCK's soulstone item (Create Soulstone, Demonology); Retail lists 20707 in Utility |
| 20764 | Soulstone Resurrection |  | WARLOCK | hand |  | accept | Soulstone Resurrection (Greater), the stored-soul aura on an ally (T21) cast from the WARLOCK's soulstone item (Create Soulstone, Demonology); Retail lists 20707 in Utility |
| 20765 | Soulstone Resurrection |  | WARLOCK | hand |  | accept | Soulstone Resurrection (Major), the stored-soul aura on an ally (T21) cast from the WARLOCK's soulstone item (Create Soulstone, Demonology); Retail lists 20707 in Utility |
| 5697 | Unending Breath |  | WARLOCK | name-map | 5697 | accept | Unending Breath, WARLOCK Demonology SkillLineAbility, water-breathing aura (82) on a friendly target, Retail lists it in Utility |
| 5421 | Aquatic Form (Passive) |  | DRUID | db2-effect |  | reject | Aquatic Form (Passive), a passive part of the form, never shows as its own aura |
| 20719 | Feline Grace |  | DRUID | db2-effect |  | reject | Feline Grace, passive fall-damage reduction, never shows as an aura |
| 5215 | Prowl | Rank 1 | DRUID | name-map | 5215 | accept | rank 1 of Prowl, DRUID Feral Combat SkillLineAbility, self stealth aura (16), Retail lists Prowl in Utility |
| 6783 | Prowl | Rank 2 | DRUID | name-map | 5215 | accept | rank 2 of Prowl, DRUID Feral Combat SkillLineAbility, self stealth aura (16), Retail lists Prowl in Utility |
| 9913 | Prowl | Rank 3 | DRUID | name-map | 5215 | accept | rank 3 of Prowl, DRUID Feral Combat SkillLineAbility, self stealth aura (16), Retail lists Prowl in Utility |

## `stances` (BUFF): 66 candidates, 33 accepted

| Id | Name | Rank | Class | Source | Origin | Ruling | Reason |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2457 | Battle Stance |  | WARRIOR | name-map | 386164 | accept | Battle Stance, WARRIOR Arms SkillLineAbility, a warrior stance |
| 2458 | Berserker Stance |  | WARRIOR | name-map | 386196 | accept | Berserker Stance, WARRIOR Fury SkillLineAbility, a warrior stance |
| 71 | Defensive Stance |  | WARRIOR | name-map | 386208 | accept | Defensive Stance, WARRIOR Protection SkillLineAbility, a warrior stance |
| 19746 | Concentration Aura |  | PALADIN | name-map | 317920 | accept | Concentration Aura, PALADIN Protection SkillLineAbility, party area aura on self, a paladin aura |
| 465 | Devotion Aura | Rank 1 | PALADIN | name-map | 465 | accept | rank 1 of Devotion Aura, PALADIN Protection SkillLineAbility, party area armor aura, a paladin aura |
| 643 | Devotion Aura | Rank 3 | PALADIN | name-map | 465 | accept | rank 3 of Devotion Aura, PALADIN Protection SkillLineAbility, party area armor aura, a paladin aura |
| 1032 | Devotion Aura | Rank 5 | PALADIN | name-map | 465 | accept | rank 5 of Devotion Aura, PALADIN Protection SkillLineAbility, party area armor aura, a paladin aura |
| 10290 | Devotion Aura | Rank 2 | PALADIN | name-map | 465 | accept | rank 2 of Devotion Aura, PALADIN Protection SkillLineAbility, party area armor aura, a paladin aura |
| 10291 | Devotion Aura | Rank 4 | PALADIN | name-map | 465 | accept | rank 4 of Devotion Aura, PALADIN Protection SkillLineAbility, party area armor aura, a paladin aura |
| 10292 | Devotion Aura | Rank 6 | PALADIN | name-map | 465 | accept | rank 6 of Devotion Aura, PALADIN Protection SkillLineAbility, party area armor aura, a paladin aura |
| 10293 | Devotion Aura | Rank 7 | PALADIN | name-map | 465 | accept | rank 7 of Devotion Aura, PALADIN Protection SkillLineAbility, party area armor aura, a paladin aura |
| 407804 | Divine Sacrifice |  | PALADIN | db2-effect |  | reject | Divine Sacrifice, Season-of-Discovery-era id (acquire method 3), a timed damage-redirect, not a stance |
| 19891 | Fire Resistance Aura | Rank 1 | PALADIN | db2-effect |  | accept | rank 1 of Fire Resistance Aura, PALADIN Protection SkillLineAbility, raid-area aura (effect 65) on self and party: a paladin aura, which Retail's Stances holds |
| 19899 | Fire Resistance Aura | Rank 2 | PALADIN | db2-effect |  | accept | rank 2 of Fire Resistance Aura, PALADIN Protection SkillLineAbility, raid-area aura (effect 65) on self and party: a paladin aura, which Retail's Stances holds |
| 19900 | Fire Resistance Aura | Rank 3 | PALADIN | db2-effect |  | accept | rank 3 of Fire Resistance Aura, PALADIN Protection SkillLineAbility, raid-area aura (effect 65) on self and party: a paladin aura, which Retail's Stances holds |
| 19888 | Frost Resistance Aura | Rank 1 | PALADIN | db2-effect |  | accept | rank 1 of Frost Resistance Aura, PALADIN Protection SkillLineAbility, raid-area aura (effect 65) on self and party: a paladin aura, which Retail's Stances holds |
| 19897 | Frost Resistance Aura | Rank 2 | PALADIN | db2-effect |  | accept | rank 2 of Frost Resistance Aura, PALADIN Protection SkillLineAbility, raid-area aura (effect 65) on self and party: a paladin aura, which Retail's Stances holds |
| 19898 | Frost Resistance Aura | Rank 3 | PALADIN | db2-effect |  | accept | rank 3 of Frost Resistance Aura, PALADIN Protection SkillLineAbility, raid-area aura (effect 65) on self and party: a paladin aura, which Retail's Stances holds |
| 7294 | Retribution Aura | Rank 1 | PALADIN | db2-effect |  | accept | rank 1 of Retribution Aura, PALADIN Retribution SkillLineAbility, party area damage-shield aura, a paladin aura |
| 10298 | Retribution Aura | Rank 2 | PALADIN | db2-effect |  | accept | rank 2 of Retribution Aura, PALADIN Retribution SkillLineAbility, party area damage-shield aura, a paladin aura |
| 10299 | Retribution Aura | Rank 3 | PALADIN | db2-effect |  | accept | rank 3 of Retribution Aura, PALADIN Retribution SkillLineAbility, party area damage-shield aura, a paladin aura |
| 10300 | Retribution Aura | Rank 4 | PALADIN | db2-effect |  | accept | rank 4 of Retribution Aura, PALADIN Retribution SkillLineAbility, party area damage-shield aura, a paladin aura |
| 10301 | Retribution Aura | Rank 5 | PALADIN | db2-effect |  | accept | rank 5 of Retribution Aura, PALADIN Retribution SkillLineAbility, party area damage-shield aura, a paladin aura |
| 20218 | Sanctity Aura |  | PALADIN | db2-effect |  | accept | Sanctity Aura, PALADIN Retribution talent, party area holy-damage aura, a paladin aura |
| 19876 | Shadow Resistance Aura | Rank 1 | PALADIN | db2-effect |  | accept | rank 1 of Shadow Resistance Aura, PALADIN Protection SkillLineAbility, raid-area aura (effect 65) on self and party: a paladin aura, which Retail's Stances holds |
| 19895 | Shadow Resistance Aura | Rank 2 | PALADIN | db2-effect |  | accept | rank 2 of Shadow Resistance Aura, PALADIN Protection SkillLineAbility, raid-area aura (effect 65) on self and party: a paladin aura, which Retail's Stances holds |
| 19896 | Shadow Resistance Aura | Rank 3 | PALADIN | db2-effect |  | accept | rank 3 of Shadow Resistance Aura, PALADIN Protection SkillLineAbility, raid-area aura (effect 65) on self and party: a paladin aura, which Retail's Stances holds |
| 1310897 | Voice of Truth |  | PALADIN | db2-effect |  | reject | Voice of Truth, a timed silence/interrupt immunity buff (duration 6s), not a stance or paladin aura |
| 13159 | Aspect of the Pack |  | HUNTER | db2-effect |  | reject | Aspect of the Pack is a speed aura; ruled into Movement (one category per id) |
| 20043 | Aspect of the Wild | Rank 1 | HUNTER | db2-effect |  | reject | Aspect of the Wild rank 1: a hunter party aura/aspect, not a stance in Retail's sense (warrior stances, druid forms, paladin auras); the hunter aspects are not ruled as stances (Monkey, Hawk none) |
| 20190 | Aspect of the Wild | Rank 2 | HUNTER | db2-effect |  | reject | Aspect of the Wild rank 2: a hunter party aura/aspect, not a stance in Retail's sense (warrior stances, druid forms, paladin auras); the hunter aspects are not ruled as stances (Monkey, Hawk none) |
| 19506 | Trueshot Aura | Rank 3 | HUNTER | db2-effect |  | reject | Trueshot Aura rank 3: a hunter party aura/aspect, not a stance in Retail's sense (warrior stances, druid forms, paladin auras); the hunter aspects are not ruled as stances (Monkey, Hawk none) |
| 20905 | Trueshot Aura | Rank 4 | HUNTER | db2-effect |  | reject | Trueshot Aura rank 4: a hunter party aura/aspect, not a stance in Retail's sense (warrior stances, druid forms, paladin auras); the hunter aspects are not ruled as stances (Monkey, Hawk none) |
| 20906 | Trueshot Aura | Rank 5 | HUNTER | db2-effect |  | reject | Trueshot Aura rank 5: a hunter party aura/aspect, not a stance in Retail's sense (warrior stances, druid forms, paladin auras); the hunter aspects are not ruled as stances (Monkey, Hawk none) |
| 1299346 | Trueshot Aura | Rank 1 | HUNTER | db2-effect |  | reject | Trueshot Aura rank 1: a hunter party aura/aspect, not a stance in Retail's sense (warrior stances, druid forms, paladin auras); the hunter aspects are not ruled as stances (Monkey, Hawk none) |
| 1299348 | Trueshot Aura | Rank 2 | HUNTER | db2-effect |  | reject | Trueshot Aura rank 2: a hunter party aura/aspect, not a stance in Retail's sense (warrior stances, druid forms, paladin auras); the hunter aspects are not ruled as stances (Monkey, Hawk none) |
| 1329326 | Ghostly Strike |  | ROGUE | db2-effect |  | reject | Ghostly Strike's triggered proc buff (next Ambush/Garrote without Stealth), not a stance |
| 1784 | Stealth | Rank 1 | ROGUE | db2-effect |  | reject | Stealth rank: Retail places Stealth in Utility, one category per id |
| 1785 | Stealth | Rank 2 | ROGUE | db2-effect |  | reject | Stealth rank: Retail places Stealth in Utility, one category per id |
| 1786 | Stealth | Rank 3 | ROGUE | db2-effect |  | reject | Stealth rank: Retail places Stealth in Utility, one category per id |
| 1787 | Stealth | Rank 4 | ROGUE | db2-effect |  | reject | Stealth rank: Retail places Stealth in Utility, one category per id |
| 1256867 | Stealth | Rank 1 | ROGUE | db2-effect |  | reject | Stealth copy with no SkillLineAbility, Talent or trigger path; Stealth belongs in Utility anyway |
| 15473 | Shadowform |  | PRIEST | name-map | 232698 | accept | Shadowform, PRIEST Shadow talent/SkillLineAbility, self shapeshift aura (36), Retail lists it in Stances |
| 27827 | Spirit of Redemption |  | PRIEST | db2-effect |  | reject | Spirit of Redemption, the death-state form from the passive talent 20711; Retail lists it in neither Stances nor Utility |
| 8230 | Flametongue Totem | Rank 1 | SHAMAN | db2-effect |  | reject | rank 1 of Flametongue Totem: the totem's own passive area aura (SPELL_ATTR0_PASSIVE), not a player stance or form |
| 8250 | Flametongue Totem | Rank 2 | SHAMAN | db2-effect |  | reject | rank 2 of Flametongue Totem: the totem's own passive area aura (SPELL_ATTR0_PASSIVE), not a player stance or form |
| 10521 | Flametongue Totem | Rank 3 | SHAMAN | db2-effect |  | reject | rank 3 of Flametongue Totem: the totem's own passive area aura (SPELL_ATTR0_PASSIVE), not a player stance or form |
| 15036 | Flametongue Totem | Rank 4 | SHAMAN | db2-effect |  | reject | rank 4 of Flametongue Totem: the totem's own passive area aura (SPELL_ATTR0_PASSIVE), not a player stance or form |
| 2645 | Ghost Wolf |  | SHAMAN | db2-effect |  | reject | Ghost Wolf: Retail keeps it in Movement, not Stances (owner 2026-09-25) |
| 415233 | Ghost Wolf |  | SHAMAN | db2-effect |  | reject | Ghost Wolf: Retail keeps it in Movement, not Stances (owner 2026-09-25) |
| 1238640 | Ghost Wolf |  | SHAMAN | db2-effect |  | reject | Ghost Wolf: Retail keeps it in Movement, not Stances (owner 2026-09-25) |
| 8178 | Grounding Totem | Rank 1 | SHAMAN | db2-effect |  | reject | Grounding Totem's aura on the totem itself (spell redirect), not a player stance or form |
| 1066 | Aquatic Form |  | DRUID | db2-effect |  | accept | Aquatic Form, DRUID Feral Combat SkillLineAbility, self shapeshift aura (36), a druid form |
| 5487 | Bear Form |  | DRUID | name-map | 5487 | accept | Bear Form, DRUID Feral Combat SkillLineAbility, self shapeshift aura (36), a druid form |
| 768 | Cat Form |  | DRUID | name-map | 768 | accept | Cat Form, DRUID Feral Combat SkillLineAbility, self shapeshift aura (36), a druid form |
| 9634 | Dire Bear Form |  | DRUID | db2-effect |  | accept | Dire Bear Form, DRUID Feral Combat SkillLineAbility, self shapeshift aura (36), a druid form |
| 24932 | Leader of the Pack |  | DRUID | db2-effect |  | reject | Leader of the Pack is the hidden party aura of a passive feral talent, no SkillLineAbility; the cat/bear forms are the stances |
| 24907 | Moonkin Aura |  | DRUID | db2-effect |  | reject | Moonkin Aura is the party crit aura Moonkin Form 24858 triggers; the form itself is the stance (one form, one id) |
| 24858 | Moonkin Form |  | DRUID | name-map | 24858 | accept | Moonkin Form, DRUID Balance talent SkillLineAbility, self shapeshift aura (36), a druid form |
| 740 | Tranquility | Rank 1 | DRUID | db2-effect |  | reject | Tranquility rank, DRUID Restoration: a channelled area heal, not a stance; belongs in raidCDs/healing |
| 8918 | Tranquility | Rank 2 | DRUID | db2-effect |  | reject | Tranquility rank, DRUID Restoration: a channelled area heal, not a stance; belongs in raidCDs/healing |
| 9862 | Tranquility | Rank 3 | DRUID | db2-effect |  | reject | Tranquility rank, DRUID Restoration: a channelled area heal, not a stance; belongs in raidCDs/healing |
| 9863 | Tranquility | Rank 4 | DRUID | db2-effect |  | reject | Tranquility rank, DRUID Restoration: a channelled area heal, not a stance; belongs in raidCDs/healing |
| 21791 | Tranquility |  | DRUID | db2-effect |  | reject | Tranquility NPC copy, no SkillLineAbility or Talent; and a heal channel, not a stance |
| 25817 | Tranquility |  | DRUID | db2-effect |  | reject | Tranquility NPC copy, no SkillLineAbility or Talent; and a heal channel, not a stance |
| 783 | Travel Form |  | DRUID | name-map | 165961 | accept | Travel Form, DRUID Feral Combat SkillLineAbility, self shapeshift aura (36), a druid form |

## `racials` (BUFF): 43 candidates, 19 accepted

| Id | Name | Rank | Class | Source | Origin | Ruling | Reason |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1259719 | Artisan's Precision |  | ALL | db2-effect |  | reject | Artisan's Precision, a passive racial trait, never shows as a buff (Retail list leaves passives out) |
| 20557 | Beast Slaying |  | ALL | db2-effect |  | reject | Beast Slaying, a passive racial trait, never shows as a buff (Retail list leaves passives out) |
| 20554 | Berserking |  | ALL | name-map | 26297 | accept | Berserking, Racial - Troll active, self haste aura; Retail keeps Berserking in Racials |
| 1259721 | Big Game Hunter |  | ALL | db2-effect |  | reject | Big Game Hunter, a passive racial trait, never shows as a buff (Retail list leaves passives out) |
| 20572 | Blood Fury |  | ALL | name-map | 20572 | accept | Blood Fury, Orc Racial active, self AP/SP aura; Retail lists it in Racials |
| 20578 | Cannibalize |  | ALL | hand |  | accept | Cannibalize's health/mana regen aura on self; the Undead racial cast 20577 (Racial - Undead) is a dummy effect that applies it |
| 20575 | Command |  | ALL | db2-effect |  | reject | Command, a passive racial trait, never shows as a buff (Retail list leaves passives out) |
| 20576 | Command |  | ALL | db2-effect |  | reject | Command, a passive racial trait, never shows as a buff (Retail list leaves passives out) |
| 21563 | Command |  | ALL | db2-effect |  | reject | Command, a passive racial trait, never shows as a buff (Retail list leaves passives out) |
| 1259688 | Elemental Blessing |  | ALL | db2-effect |  | accept | Elemental Blessing, the speed buff triggered by Skyborne racial Skysight 1259686; a racial buff, so Racials (as Retail's Darkflight) |
| 1259707 | Elemental Insight |  | ALL | db2-effect |  | reject | Elemental Insight, a passive racial trait, never shows as a buff (Retail list leaves passives out) |
| 1259799 | Elune's Light |  | ALL | db2-effect |  | accept | Elune's Light, Night Elf Racial active, self crit aura |
| 20550 | Endurance |  | ALL | db2-effect |  | reject | Endurance, a passive racial trait, never shows as a buff (Retail list leaves passives out) |
| 1270842 | Energized |  | ALL | db2-effect |  | accept | Energized, the regen buff triggered by Skyborne racial Read Leyline 1259705 |
| 20593 | Engineering Specialization |  | ALL | db2-effect |  | reject | Engineering Specialization, a passive racial trait, never shows as a buff (Retail list leaves passives out) |
| 20589 | Escape Artist |  | ALL | db2-effect |  | accept | Escape Artist, Racial - Gnome active, self snare/root immunity aura (77) |
| 1259812 | Eureka! |  | ALL | db2-effect |  | accept | Eureka!, Racial - Gnome per-class (ROGUE mask) timed self buff (cost/damage mods); a racial buff, Racials by Retail's precedence |
| 1259813 | Eureka! |  | ALL | db2-effect |  | accept | Eureka!, Racial - Gnome per-class (WARRIOR mask) timed self buff (cost/damage mods); a racial buff, Racials by Retail's precedence |
| 1259817 | Eureka! |  | ALL | db2-effect |  | accept | Eureka!, Racial - Gnome per-class (MAGE mask) timed self buff (cost/damage mods); a racial buff, Racials by Retail's precedence |
| 1259821 | Eureka! |  | ALL | db2-effect |  | accept | Eureka!, Racial - Gnome per-class (WARLOCK mask) timed self buff (cost/damage mods); a racial buff, Racials by Retail's precedence |
| 1259823 | Eureka! |  | ALL | db2-effect |  | accept | Eureka!, Racial - Gnome per-class (PRIEST mask) timed self buff (cost/damage mods); a racial buff, Racials by Retail's precedence |
| 20591 | Expansive Mind |  | ALL | db2-effect |  | reject | Expansive Mind, a passive racial trait, never shows as a buff (Retail list leaves passives out) |
| 1259802 | Expansive Mind |  | ALL | db2-effect |  | reject | Expansive Mind, a passive racial trait, never shows as a buff (Retail list leaves passives out) |
| 1259803 | Expansive Mind |  | ALL | db2-effect |  | reject | Expansive Mind, a passive racial trait, never shows as a buff (Retail list leaves passives out) |
| 2481 | Find Treasure |  | ALL | db2-effect |  | reject | Find Treasure, a tracking aura (45) shown on the minimap tracker, not a buff |
| 20573 | Hardiness |  | ALL | db2-effect |  | reject | Hardiness, a passive racial trait, never shows as a buff (Retail list leaves passives out) |
| 20600 | Perception |  | ALL | db2-effect |  | accept | Perception, Racial - Human active, self stealth-detection aura |
| 1259918 | Plainsrunning |  | ALL | db2-effect |  | reject | Plainsrunning, a passive racial trait, never shows as a buff (Retail list leaves passives out) |
| 20582 | Quickness |  | ALL | db2-effect |  | reject | Quickness, a passive racial trait, never shows as a buff (Retail list leaves passives out) |
| 21009 | Quickness Passive |  | ALL | db2-effect |  | reject | Quickness Passive, a passive racial trait, never shows as a buff (Retail list leaves passives out) |
| 1260270 | Rapid Regeneration |  | ALL | db2-effect |  | accept | Rapid Regeneration, Racial - Troll active, self periodic heal aura |
| 20555 | Regeneration |  | ALL | db2-effect |  | reject | Regeneration, a passive racial trait, never shows as a buff (Retail list leaves passives out) |
| 20597 | Ruthless |  | ALL | db2-effect |  | reject | Ruthless, a passive racial trait, never shows as a buff (Retail list leaves passives out) |
| 20580 | Shadowmeld |  | ALL | name-map | 58984 | accept | Shadowmeld, Night Elf Racial active, self stealth aura; Retail keeps Shadowmeld in Racials |
| 1299026 | Shatter Curse |  | ALL | db2-effect |  | accept | Shatter Curse, Orc Racial active, self magic damage reduction aura |
| 20594 | Stoneform |  | ALL | name-map | 65116 | accept | Stoneform, Dwarven Racial active, self immunity/armor aura; Retail lists it in Racials |
| 20598 | The Human Spirit |  | ALL | db2-effect |  | reject | The Human Spirit, a passive racial trait, never shows as a buff (Retail list leaves passives out) |
| 1260189 | Touch of the Grave |  | ALL | db2-effect |  | reject | Touch of the Grave, a passive racial trait, never shows as a buff (Retail list leaves passives out) |
| 1260201 | Touch of the Grave |  | ALL | db2-effect |  | reject | Touch of the Grave, a passive racial trait, never shows as a buff (Retail list leaves passives out) |
| 5227 | Underwater Breathing |  | ALL | db2-effect |  | reject | Underwater Breathing, a passive racial trait, never shows as a buff (Retail list leaves passives out) |
| 1259416 | Walk on Air |  | ALL | db2-effect |  | accept | Walk on Air, Skyborne Racial active, self glide aura (105) |
| 7744 | Will of the Forsaken |  | ALL | name-map | 7744 | accept | Will of the Forsaken, Racial - Undead active, self charm/fear/sleep immunity aura; Retail lists it in Racials |
| 1259710 | Wind Blessed |  | ALL | db2-effect |  | reject | Wind Blessed, a passive racial trait, never shows as a buff (Retail list leaves passives out) |

## `hardCC` (DEBUFF): 114 candidates, 82 accepted

| Id | Name | Rank | Class | Source | Origin | Ruling | Reason |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 22911 | Charge |  | WARRIOR | cc-mechanic |  | reject | NPC Charge copy: no WARRIOR SkillLineAbility/Talent row; the player's Charge stun aura is 7922 |
| 1235538 | Charge |  | WARRIOR | cc-mechanic |  | reject | NPC Charge copy: no WARRIOR SkillLineAbility/Talent row and not triggered by any player spell; player stun aura is 7922 |
| 7922 | Charge Stun |  | WARRIOR | cc-mechanic |  | accept | Charge Stun, stun aura (APPLY_AURA 12, mech stunned) on the enemy, triggered by player Charge ranks 100/6178/11578 |
| 411688 | Charge Stun |  | WARRIOR | cc-mechanic |  | reject | Charge Stun copy triggered only by 411684, a Charge with no SkillLineAbility/Talent row (rune/variant), not class-reachable |
| 12809 | Concussion Blow |  | WARRIOR | cc-mechanic |  | accept | Concussion Blow, WARRIOR Protection talent, stun aura (mech stunned) on enemy |
| 22427 | Concussion Blow |  | WARRIOR | cc-mechanic |  | reject | NPC Concussion Blow copy: no SkillLineAbility/Talent row, DR 0 |
| 20253 | Intercept Stun | Rank 1 | WARRIOR | cc-mechanic |  | accept | Intercept Stun rank 1, stun aura on enemy triggered by player Intercept 20252 |
| 20614 | Intercept Stun | Rank 2 | WARRIOR | cc-mechanic |  | accept | Intercept Stun rank 2, stun aura on enemy triggered by player Intercept 20616 |
| 20615 | Intercept Stun | Rank 3 | WARRIOR | cc-mechanic |  | accept | Intercept Stun rank 3, stun aura on enemy triggered by player Intercept 20617 |
| 5246 | Intimidating Shout |  | WARRIOR | cc-mechanic |  | accept | Intimidating Shout, WARRIOR SkillLineAbility, fear aura (MOD_FEAR) on nearby enemies; Retail ships 5246 |
| 19134 | Intimidating Shout |  | WARRIOR | cc-mechanic |  | reject | NPC Intimidating Shout copy (known trap): no SkillLineAbility/Talent row, DR 0 |
| 20511 | Intimidating Shout |  | WARRIOR | cc-mechanic |  | accept | Intimidating Shout cower stun aura on the primary target, triggered by player 5246 |
| 29544 | Intimidating Shout |  | WARRIOR | cc-mechanic |  | reject | Intimidating Shout cower aura triggered only by NPC copies 19134/1213465/1270811, not by the player's 5246 |
| 1213465 | Intimidating Shout |  | WARRIOR | cc-mechanic |  | reject | NPC Intimidating Shout copy: no SkillLineAbility/Talent row, DR 0 |
| 1270811 | Intimidating Shout |  | WARRIOR | cc-mechanic |  | reject | NPC Intimidating Shout copy: no SkillLineAbility/Talent row, DR 0 |
| 853 | Hammer of Justice | Rank 1 | PALADIN | cc-mechanic |  | accept | rank 1 of Hammer of Justice, PALADIN SkillLineAbility, stun aura on enemy; Retail ships 853 |
| 5588 | Hammer of Justice | Rank 2 | PALADIN | cc-mechanic |  | accept | rank 2 of Hammer of Justice, PALADIN SkillLineAbility, stun aura on enemy |
| 5589 | Hammer of Justice | Rank 3 | PALADIN | cc-mechanic |  | accept | rank 3 of Hammer of Justice, PALADIN SkillLineAbility, stun aura on enemy |
| 10308 | Hammer of Justice | Rank 4 | PALADIN | cc-mechanic |  | accept | rank 4 of Hammer of Justice, PALADIN SkillLineAbility, stun aura on enemy |
| 20066 | Repentance |  | PALADIN | cc-mechanic |  | accept | Repentance, PALADIN Retribution talent, incapacitate aura (mech incapacitated) on enemy |
| 20170 | Stun | Rank 1 | PALADIN | cc-mechanic |  | accept | Seal of Justice stun proc, stun aura (mech stunned) on enemy triggered by player Seal of Justice 20164 |
| 2878 | Turn Undead | Rank 1 | PALADIN | cc-mechanic |  | accept | rank 1 of Turn Undead, PALADIN SkillLineAbility, fear aura (mech turned) on enemy undead |
| 5627 | Turn Undead | Rank 2 | PALADIN | cc-mechanic |  | accept | rank 2 of Turn Undead, PALADIN SkillLineAbility, fear aura (mech turned) on enemy undead |
| 10326 | Turn Undead | Rank 3 | PALADIN | cc-mechanic |  | accept | rank 3 of Turn Undead, PALADIN SkillLineAbility, fear aura on enemy; same id Retail ships as Turn Evil |
| 3355 | Freezing Trap | Rank 1 | HUNTER | cc-mechanic |  | accept | rank 1 Freezing Trap effect, frozen stun aura on enemy applied by the hunter trap; Retail ships 3355 |
| 14308 | Freezing Trap | Rank 2 | HUNTER | cc-mechanic |  | accept | rank 2 Freezing Trap effect, frozen stun aura on enemy applied by the hunter trap |
| 14309 | Freezing Trap | Rank 3 | HUNTER | cc-mechanic |  | accept | rank 3 Freezing Trap effect, frozen stun aura on enemy applied by the hunter trap |
| 19410 | Improved Concussive Shot |  | HUNTER | cc-mechanic |  | accept | Improved Concussive Shot stun aura on enemy, triggered by HUNTER talent 19407 (SkillLineAbility+Talent) |
| 24394 | Intimidation |  | HUNTER | cc-mechanic |  | accept | Intimidation stun aura on the pet's target, triggered by HUNTER BM talent 19577; Retail ships 24394 |
| 1513 | Scare Beast | Rank 1 | HUNTER | cc-mechanic |  | accept | rank 1 of Scare Beast, HUNTER SkillLineAbility, fear aura on enemy beast; Retail ships 1513 |
| 14326 | Scare Beast | Rank 2 | HUNTER | cc-mechanic |  | accept | rank 2 of Scare Beast, HUNTER SkillLineAbility, fear aura on enemy beast |
| 14327 | Scare Beast | Rank 3 | HUNTER | cc-mechanic |  | accept | rank 3 of Scare Beast, HUNTER SkillLineAbility, fear aura on enemy beast |
| 19503 | Scatter Shot |  | HUNTER | cc-mechanic |  | accept | Scatter Shot, HUNTER Marksmanship talent, disorient aura (MOD_CONFUSE) on enemy |
| 23601 | Scatter Shot |  | HUNTER | cc-mechanic |  | reject | NPC Scatter Shot copy: no SkillLineAbility/Talent row, mechanic 0 |
| 2094 | Blind |  | ROGUE | cc-mechanic |  | accept | Blind, ROGUE SkillLineAbility, disorient aura on enemy; Retail ships 2094 |
| 1833 | Cheap Shot |  | ROGUE | cc-mechanic |  | accept | Cheap Shot, ROGUE SkillLineAbility, stun aura on enemy; Retail ships 1833 |
| 14902 | Cheap Shot |  | ROGUE | cc-mechanic |  | reject | NPC Cheap Shot copy: no SkillLineAbility/Talent row |
| 1776 | Gouge | Rank 1 | ROGUE | cc-mechanic |  | accept | rank 1 of Gouge, ROGUE SkillLineAbility, incapacitate aura on enemy; Retail ships 1776 |
| 1777 | Gouge | Rank 2 | ROGUE | cc-mechanic |  | accept | rank 2 of Gouge, ROGUE SkillLineAbility, incapacitate aura on enemy |
| 8629 | Gouge | Rank 3 | ROGUE | cc-mechanic |  | accept | rank 3 of Gouge, ROGUE SkillLineAbility, incapacitate aura on enemy |
| 11285 | Gouge | Rank 4 | ROGUE | cc-mechanic |  | accept | rank 4 of Gouge, ROGUE SkillLineAbility, incapacitate aura on enemy |
| 11286 | Gouge | Rank 5 | ROGUE | cc-mechanic |  | accept | rank 5 of Gouge, ROGUE SkillLineAbility, incapacitate aura on enemy |
| 408 | Kidney Shot | Rank 1 | ROGUE | cc-mechanic |  | accept | rank 1 of Kidney Shot, ROGUE SkillLineAbility, stun aura on enemy; Retail ships 408 |
| 8643 | Kidney Shot | Rank 2 | ROGUE | cc-mechanic |  | accept | rank 2 of Kidney Shot, ROGUE SkillLineAbility, stun aura on enemy |
| 27615 | Kidney Shot | Rank 2 | ROGUE | cc-mechanic |  | reject | NPC Kidney Shot copy: no SkillLineAbility/Talent row, single stun effect |
| 2070 | Sap | Rank 2 | ROGUE | cc-mechanic |  | accept | rank 2 of Sap, ROGUE SkillLineAbility, incapacitate aura (mech sapped) on enemy |
| 6770 | Sap | Rank 1 | ROGUE | cc-mechanic |  | accept | rank 1 of Sap, ROGUE SkillLineAbility, incapacitate aura on enemy; Retail ships 6770 |
| 11297 | Sap | Rank 3 | ROGUE | cc-mechanic |  | accept | rank 3 of Sap, ROGUE SkillLineAbility, incapacitate aura on enemy |
| 15269 | Blackout | Rank 1 | PRIEST | cc-mechanic |  | accept | Blackout stun aura on enemy, triggered by PRIEST Shadow talent ranks 15268/15323-15326 |
| 1277455 | Confounding Flash |  | PRIEST | cc-mechanic |  | accept | Confounding Flash, PRIEST Discipline SkillLineAbility (gnome race mask), AoE confuse aura on enemies; aura of cast 1277662 |
| 605 | Mind Control | Rank 1 | PRIEST | cc-mechanic |  | accept | rank 1 of Mind Control, PRIEST SkillLineAbility, MOD_CHARM aura on the enemy; Retail ships 605 |
| 10911 | Mind Control | Rank 2 | PRIEST | cc-mechanic |  | accept | rank 2 of Mind Control, PRIEST SkillLineAbility, MOD_CHARM aura on enemy |
| 10912 | Mind Control | Rank 3 | PRIEST | cc-mechanic |  | accept | rank 3 of Mind Control, PRIEST SkillLineAbility, MOD_CHARM aura on enemy |
| 26044 | Mind Flay |  | PRIEST | cc-mechanic |  | reject | NPC Mind Flay copy (no SkillLineAbility/Talent) and a snare/DoT, not loss of control |
| 474268 | Mind Flay |  | PRIEST | cc-mechanic |  | reject | NPC Mind Flay copy (no SkillLineAbility/Talent) and a snare/DoT, not loss of control |
| 8122 | Psychic Scream | Rank 1 | PRIEST | cc-mechanic |  | accept | rank 1 of Psychic Scream, PRIEST SkillLineAbility, fear aura on nearby enemies; Retail ships 8122 |
| 8124 | Psychic Scream | Rank 2 | PRIEST | cc-mechanic |  | accept | rank 2 of Psychic Scream, PRIEST SkillLineAbility, fear aura on nearby enemies |
| 10888 | Psychic Scream | Rank 3 | PRIEST | cc-mechanic |  | accept | rank 3 of Psychic Scream, PRIEST SkillLineAbility, fear aura on nearby enemies |
| 10890 | Psychic Scream | Rank 4 | PRIEST | cc-mechanic |  | accept | rank 4 of Psychic Scream, PRIEST SkillLineAbility, fear aura on nearby enemies |
| 15398 | Psychic Scream |  | PRIEST | cc-mechanic |  | reject | NPC Psychic Scream copy (single-target stun): no SkillLineAbility/Talent row, DR 0 |
| 27610 | Psychic Scream | Rank 4 | PRIEST | cc-mechanic |  | reject | NPC duplicate of Psychic Scream rank 4: no SkillLineAbility/Talent row; player rank 4 is 10890 |
| 9484 | Shackle Undead | Rank 1 | PRIEST | cc-mechanic |  | accept | rank 1 of Shackle Undead, PRIEST SkillLineAbility, shackle stun aura on enemy undead; Retail ships 9484 |
| 9485 | Shackle Undead | Rank 2 | PRIEST | cc-mechanic |  | accept | rank 2 of Shackle Undead, PRIEST SkillLineAbility, shackle aura on enemy undead |
| 10955 | Shackle Undead | Rank 3 | PRIEST | cc-mechanic |  | accept | rank 3 of Shackle Undead, PRIEST SkillLineAbility, shackle aura on enemy undead |
| 15091 | Blast Wave |  | MAGE | cc-mechanic |  | reject | NPC Blast Wave copy (known trap): no SkillLineAbility/Talent row; player Blast Wave is a daze snare, not hard CC |
| 15744 | Blast Wave |  | MAGE | cc-mechanic |  | reject | NPC Blast Wave copy (known trap): no SkillLineAbility/Talent row; snare aura only |
| 16046 | Blast Wave |  | MAGE | cc-mechanic |  | reject | NPC Blast Wave copy (known trap): no SkillLineAbility/Talent row; snare aura only |
| 17145 | Blast Wave |  | MAGE | cc-mechanic |  | reject | NPC Blast Wave copy (known trap): no SkillLineAbility/Talent row; snare aura only |
| 17277 | Blast Wave |  | MAGE | cc-mechanic |  | reject | NPC Blast Wave copy (known trap): no SkillLineAbility/Talent row; snare aura only |
| 22424 | Blast Wave |  | MAGE | cc-mechanic |  | reject | NPC Blast Wave copy (known trap): no SkillLineAbility/Talent row; snare aura only |
| 23039 | Blast Wave |  | MAGE | cc-mechanic |  | reject | NPC Blast Wave copy (known trap): no SkillLineAbility/Talent row; snare aura only |
| 23113 | Blast Wave |  | MAGE | cc-mechanic |  | reject | NPC Blast Wave copy (known trap): no SkillLineAbility/Talent row; snare aura only |
| 25049 | Blast Wave |  | MAGE | cc-mechanic |  | reject | NPC Blast Wave copy (known trap): no SkillLineAbility/Talent row; snare aura only |
| 469161 | Blast Wave |  | MAGE | cc-mechanic |  | reject | NPC Blast Wave copy (known trap): no SkillLineAbility/Talent row; snare aura only |
| 1235318 | Blast Wave |  | MAGE | cc-mechanic |  | reject | NPC Blast Wave copy (known trap): no SkillLineAbility/Talent row; snare aura only |
| 11958 | Ice Block |  | MAGE | cc-mechanic |  | reject | Ice Block is a self-cast immunity buff on the mage, not CC on a hostile unit; belongs in defensives (candidate defensives:11958) |
| 27619 | Ice Block |  | MAGE | cc-mechanic |  | reject | NPC Ice Block copy: no SkillLineAbility/Talent row, self buff, not hostile CC |
| 12355 | Impact |  | MAGE | cc-mechanic |  | accept | Impact stun aura on enemy, MAGE Fire SkillLineAbility, triggered by talent 11103 |
| 118 | Polymorph | Rank 1 | MAGE | cc-mechanic |  | accept | rank 1 of Polymorph, MAGE SkillLineAbility, polymorph aura (MOD_CONFUSE+transform) on enemy; Retail ships 118 |
| 12824 | Polymorph | Rank 2 | MAGE | cc-mechanic |  | accept | rank 2 of Polymorph, MAGE SkillLineAbility, polymorph aura on enemy |
| 12825 | Polymorph | Rank 3 | MAGE | cc-mechanic |  | accept | rank 3 of Polymorph, MAGE SkillLineAbility, polymorph aura on enemy |
| 12826 | Polymorph | Rank 4 | MAGE | cc-mechanic |  | accept | rank 4 of Polymorph, MAGE SkillLineAbility, polymorph aura on enemy |
| 28271 | Polymorph |  | MAGE | cc-mechanic |  | accept | Polymorph (Turtle), MAGE Arcane SkillLineAbility (tome-learned), polymorph aura on enemy |
| 28272 | Polymorph |  | MAGE | cc-mechanic |  | accept | Polymorph (Pig), MAGE Arcane SkillLineAbility (tome-learned), polymorph aura on enemy |
| 28270 | Polymorph: Cow |  | MAGE | cc-mechanic |  | accept | Polymorph: Cow, MAGE Arcane SkillLineAbility row identical to Turtle/Pig, polymorph aura on enemy |
| 710 | Banish | Rank 1 | WARLOCK | cc-mechanic |  | accept | rank 1 of Banish, WARLOCK SkillLineAbility, banish aura (stun+immunity) on enemy; Retail ships 710 |
| 18647 | Banish | Rank 2 | WARLOCK | cc-mechanic |  | accept | rank 2 of Banish, WARLOCK SkillLineAbility, banish aura on enemy |
| 457569 | Banish | Rank 1 | WARLOCK | cc-mechanic |  | reject | NPC Banish copy (known trap): no SkillLineAbility/Talent row, implicit target 25 not the player's enemy target |
| 465352 | Banish | Rank 2 | WARLOCK | cc-mechanic |  | reject | NPC Banish copy (known trap): no SkillLineAbility/Talent row, implicit target 25 not the player's enemy target |
| 6789 | Death Coil | Rank 1 | WARLOCK | cc-mechanic |  | accept | rank 1 of Death Coil, WARLOCK SkillLineAbility, horror aura (MOD_FEAR, mech horrified) on enemy; Retail ships 6789 |
| 17925 | Death Coil | Rank 2 | WARLOCK | cc-mechanic |  | accept | rank 2 of Death Coil, WARLOCK SkillLineAbility, horror aura on enemy |
| 17926 | Death Coil | Rank 3 | WARLOCK | cc-mechanic |  | accept | rank 3 of Death Coil, WARLOCK SkillLineAbility, horror aura on enemy |
| 28412 | Death Coil |  | WARLOCK | cc-mechanic |  | reject | NPC Death Coil copy: no SkillLineAbility/Talent row, extra non-player effect |
| 5782 | Fear | Rank 1 | WARLOCK | cc-mechanic |  | accept | rank 1 of Fear, WARLOCK SkillLineAbility, applies its own MOD_FEAR aura on enemy (Retail's separate aura id does not exist here) |
| 6213 | Fear | Rank 2 | WARLOCK | cc-mechanic |  | accept | rank 2 of Fear, WARLOCK SkillLineAbility, fear aura on enemy |
| 6215 | Fear | Rank 3 | WARLOCK | cc-mechanic |  | accept | rank 3 of Fear, WARLOCK SkillLineAbility, fear aura on enemy |
| 5484 | Howl of Terror | Rank 1 | WARLOCK | cc-mechanic |  | accept | rank 1 of Howl of Terror, WARLOCK SkillLineAbility, AoE fear aura on enemies; Retail ships 5484 |
| 17928 | Howl of Terror | Rank 2 | WARLOCK | cc-mechanic |  | accept | rank 2 of Howl of Terror, WARLOCK SkillLineAbility, AoE fear aura on enemies |
| 18093 | Pyroclasm |  | WARLOCK | cc-mechanic |  | accept | Pyroclasm stun aura on enemy, WARLOCK Destruction SkillLineAbility (talent proc from Rain of Fire/Hellfire) |
| 1098 | Subjugate Demon | Rank 1 | WARLOCK | cc-mechanic |  | accept | rank 1 of Subjugate Demon (Enslave Demon), WARLOCK SkillLineAbility, MOD_POSSESS aura on enemy demon; Retail ships 1098 |
| 11725 | Subjugate Demon | Rank 2 | WARLOCK | cc-mechanic |  | accept | rank 2 of Subjugate Demon, WARLOCK SkillLineAbility, possess aura on enemy demon |
| 11726 | Subjugate Demon | Rank 3 | WARLOCK | cc-mechanic |  | accept | rank 3 of Subjugate Demon, WARLOCK SkillLineAbility, possess aura on enemy demon |
| 20882 | Subjugate Demon |  | WARLOCK | cc-mechanic |  | reject | NPC Subjugate Demon copy: no SkillLineAbility/Talent row, DR 0 |
| 5211 | Bash | Rank 1 | DRUID | cc-mechanic |  | accept | rank 1 of Bash, DRUID SkillLineAbility, stun aura on enemy; Retail ships 5211 |
| 6798 | Bash | Rank 2 | DRUID | cc-mechanic |  | accept | rank 2 of Bash, DRUID SkillLineAbility, stun aura on enemy |
| 8983 | Bash | Rank 3 | DRUID | cc-mechanic |  | accept | rank 3 of Bash, DRUID SkillLineAbility, stun aura on enemy |
| 2637 | Hibernate | Rank 1 | DRUID | cc-mechanic |  | accept | rank 1 of Hibernate, DRUID SkillLineAbility, sleep aura on enemy; Retail ships 2637 |
| 18657 | Hibernate | Rank 2 | DRUID | cc-mechanic |  | accept | rank 2 of Hibernate, DRUID SkillLineAbility, sleep aura on enemy |
| 18658 | Hibernate | Rank 3 | DRUID | cc-mechanic |  | accept | rank 3 of Hibernate, DRUID SkillLineAbility, sleep aura on enemy |
| 9005 | Pounce | Rank 1 | DRUID | cc-mechanic |  | accept | rank 1 of Pounce, DRUID SkillLineAbility, stun aura on enemy (bleed is separate 9007) |
| 9823 | Pounce | Rank 2 | DRUID | cc-mechanic |  | accept | rank 2 of Pounce, DRUID SkillLineAbility, stun aura on enemy |
| 9827 | Pounce | Rank 3 | DRUID | cc-mechanic |  | accept | rank 3 of Pounce, DRUID SkillLineAbility, stun aura on enemy |
| 16922 | Starfire Stun |  | DRUID | cc-mechanic |  | accept | Starfire Stun aura on enemy, triggered by DRUID Balance talent Improved Starfire 16850 |
| 20549 | War Stomp |  | ALL | hand |  | accept | War Stomp, Tauren racial (Tauren Racial SkillLineAbility), area stun aura (A12, Mechanic 12) on enemies; Retail ships it in hardCC under ALL as well as Racials (allowed overlap) |

## `ccRoot` (DEBUFF): 36 candidates, 36 accepted

| Id | Name | Rank | Class | Source | Origin | Ruling | Reason |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 23694 | Improved Hamstring |  | WARRIOR | cc-mechanic |  | accept | Improved Hamstring proc aura, triggered by WARRIOR Arms talent 12289 (Talent tab 161), APPLY_AURA ROOT on enemy target |
| 25999 | Boar Charge |  | HUNTER | cc-mechanic |  | accept | Boar Charge immobilize aura, triggered by hunter pet Charge 7371+ (taught via Beast Training 7370, ClassMask 4), ROOT aura on the hunter target |
| 19306 | Counterattack | Rank 1 | HUNTER | cc-mechanic |  | accept | rank 1 of Counterattack, HUNTER Survival SkillLineAbility (ClassMask 4), APPLY_AURA ROOT mechanic 7 on enemy target |
| 20909 | Counterattack | Rank 3 | HUNTER | cc-mechanic |  | accept | rank 3 of Counterattack, HUNTER Survival SkillLineAbility (ClassMask 4), APPLY_AURA ROOT mechanic 7 on enemy target |
| 20910 | Counterattack | Rank 4 | HUNTER | cc-mechanic |  | accept | rank 4 of Counterattack, HUNTER Survival SkillLineAbility (ClassMask 4), APPLY_AURA ROOT mechanic 7 on enemy target |
| 1242634 | Counterattack | Rank 2 | HUNTER | cc-mechanic |  | accept | rank 2 of Counterattack, HUNTER Survival SkillLineAbility (ClassMask 4), APPLY_AURA ROOT mechanic 7 on enemy target |
| 19185 | Entrapment |  | HUNTER | cc-mechanic |  | accept | Entrapment root aura of HUNTER Survival talent 19184 (Talent tab 362), in Survival SkillLineAbility, ROOT on trapped enemies |
| 19229 | Improved Wing Clip |  | HUNTER | cc-mechanic |  | accept | Improved Wing Clip root aura, triggered by HUNTER Survival talent 19228 (Talent tab 362), ROOT on enemy target |
| 1265843 | Web | Rank 1 | HUNTER | cc-mechanic |  | accept | rank 1 of hunter pet Web (Pet - Spider, taught by Beast Training learn spell, ClassMask 4), ROOT+DoT aura on the hunter target, visible on target frame |
| 1265878 | Web | Rank 2 | HUNTER | cc-mechanic |  | accept | rank 2 of hunter pet Web (Pet - Spider, taught by Beast Training learn spell, ClassMask 4), ROOT+DoT aura on the hunter target, visible on target frame |
| 1265880 | Web | Rank 3 | HUNTER | cc-mechanic |  | accept | rank 3 of hunter pet Web (Pet - Spider, taught by Beast Training learn spell, ClassMask 4), ROOT+DoT aura on the hunter target, visible on target frame |
| 1265881 | Web | Rank 4 | HUNTER | cc-mechanic |  | accept | rank 4 of hunter pet Web (Pet - Spider, taught by Beast Training learn spell, ClassMask 4), ROOT+DoT aura on the hunter target, visible on target frame |
| 1265883 | Web | Rank 5 | HUNTER | cc-mechanic |  | accept | rank 5 of hunter pet Web (Pet - Spider, taught by Beast Training learn spell, ClassMask 4), ROOT+DoT aura on the hunter target, visible on target frame |
| 1277331 | Chastise | Rank 1 | PRIEST | cc-mechanic |  | accept | rank 1 of Chastise, PRIEST Holy SkillLineAbility (ClassMask 16, Dwarf race mask), APPLY_AURA ROOT mechanic 7 on enemy target |
| 1277332 | Chastise | Rank 2 | PRIEST | cc-mechanic |  | accept | rank 2 of Chastise, PRIEST Holy SkillLineAbility (ClassMask 16, Dwarf race mask), APPLY_AURA ROOT mechanic 7 on enemy target |
| 1277333 | Chastise | Rank 3 | PRIEST | cc-mechanic |  | accept | rank 3 of Chastise, PRIEST Holy SkillLineAbility (ClassMask 16, Dwarf race mask), APPLY_AURA ROOT mechanic 7 on enemy target |
| 1277334 | Chastise | Rank 4 | PRIEST | cc-mechanic |  | accept | rank 4 of Chastise, PRIEST Holy SkillLineAbility (ClassMask 16, Dwarf race mask), APPLY_AURA ROOT mechanic 7 on enemy target |
| 1277335 | Chastise | Rank 5 | PRIEST | cc-mechanic |  | accept | rank 5 of Chastise, PRIEST Holy SkillLineAbility (ClassMask 16, Dwarf race mask), APPLY_AURA ROOT mechanic 7 on enemy target |
| 122 | Frost Nova | Rank 1 | MAGE | cc-mechanic |  | accept | rank 1 of Frost Nova, MAGE Frost SkillLineAbility (ClassMask 128), AoE APPLY_AURA ROOT mechanic 7 on enemies (freeze) |
| 865 | Frost Nova | Rank 2 | MAGE | cc-mechanic |  | accept | rank 2 of Frost Nova, MAGE Frost SkillLineAbility (ClassMask 128), AoE APPLY_AURA ROOT mechanic 7 on enemies (freeze) |
| 6131 | Frost Nova | Rank 3 | MAGE | cc-mechanic |  | accept | rank 3 of Frost Nova, MAGE Frost SkillLineAbility (ClassMask 128), AoE APPLY_AURA ROOT mechanic 7 on enemies (freeze) |
| 10230 | Frost Nova | Rank 4 | MAGE | cc-mechanic |  | accept | rank 4 of Frost Nova, MAGE Frost SkillLineAbility (ClassMask 128), AoE APPLY_AURA ROOT mechanic 7 on enemies (freeze) |
| 12494 | Frostbite |  | MAGE | cc-mechanic |  | accept | Frostbite freeze aura, triggered by MAGE Frost talent 11071 (Talent tab 61), ROOT mechanic 7 on enemy target |
| 339 | Entangling Roots | Rank 1 | DRUID | cc-mechanic |  | accept | rank 1 of Entangling Roots, DRUID Balance SkillLineAbility (ClassMask 1024), APPLY_AURA ROOT mechanic 7 on enemy target |
| 1062 | Entangling Roots | Rank 2 | DRUID | cc-mechanic |  | accept | rank 2 of Entangling Roots, DRUID Balance SkillLineAbility (ClassMask 1024), APPLY_AURA ROOT mechanic 7 on enemy target |
| 5195 | Entangling Roots | Rank 3 | DRUID | cc-mechanic |  | accept | rank 3 of Entangling Roots, DRUID Balance SkillLineAbility (ClassMask 1024), APPLY_AURA ROOT mechanic 7 on enemy target |
| 5196 | Entangling Roots | Rank 4 | DRUID | cc-mechanic |  | accept | rank 4 of Entangling Roots, DRUID Balance SkillLineAbility (ClassMask 1024), APPLY_AURA ROOT mechanic 7 on enemy target |
| 9852 | Entangling Roots | Rank 5 | DRUID | cc-mechanic |  | accept | rank 5 of Entangling Roots, DRUID Balance SkillLineAbility (ClassMask 1024), APPLY_AURA ROOT mechanic 7 on enemy target |
| 9853 | Entangling Roots | Rank 6 | DRUID | cc-mechanic |  | accept | rank 6 of Entangling Roots, DRUID Balance SkillLineAbility (ClassMask 1024), APPLY_AURA ROOT mechanic 7 on enemy target |
| 19970 | Entangling Roots | Rank 6 | DRUID | cc-mechanic |  | accept | Entangling Roots rank 6 aura of Nature's Grasp 17329 (DRUID Balance talent/SkillLineAbility), ROOT mechanic 7 on the attacker |
| 19971 | Entangling Roots | Rank 5 | DRUID | cc-mechanic |  | accept | Entangling Roots rank 5 aura of Nature's Grasp 16813 (DRUID Balance talent/SkillLineAbility), ROOT mechanic 7 on the attacker |
| 19972 | Entangling Roots | Rank 4 | DRUID | cc-mechanic |  | accept | Entangling Roots rank 4 aura of Nature's Grasp 16812 (DRUID Balance talent/SkillLineAbility), ROOT mechanic 7 on the attacker |
| 19973 | Entangling Roots | Rank 3 | DRUID | cc-mechanic |  | accept | Entangling Roots rank 3 aura of Nature's Grasp 16811 (DRUID Balance talent/SkillLineAbility), ROOT mechanic 7 on the attacker |
| 19974 | Entangling Roots | Rank 2 | DRUID | cc-mechanic |  | accept | Entangling Roots rank 2 aura of Nature's Grasp 16810 (DRUID Balance talent/SkillLineAbility), ROOT mechanic 7 on the attacker |
| 19975 | Entangling Roots | Rank 1 | DRUID | cc-mechanic |  | accept | Entangling Roots rank 1 aura of Nature's Grasp 16689 (DRUID Balance talent/SkillLineAbility), ROOT mechanic 7 on the attacker |
| 19675 | Feral Charge |  | DRUID | cc-mechanic |  | accept | Feral Charge immobilize aura, triggered by DRUID Feral Charge 16979/1238122 (Feral Combat talent), ROOT mechanic 7 on enemy target |

## `ccSnare` (DEBUFF): 86 candidates, 63 accepted

| Id | Name | Rank | Class | Source | Origin | Ruling | Reason |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1715 | Hamstring | Rank 1 | WARRIOR | cc-mechanic |  | accept | rank 1 of Hamstring, WARRIOR Arms SkillLineAbility (ClassMask 1), MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 7372 | Hamstring | Rank 2 | WARRIOR | cc-mechanic |  | accept | rank 2 of Hamstring, WARRIOR Arms SkillLineAbility (ClassMask 1), MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 7373 | Hamstring | Rank 3 | WARRIOR | cc-mechanic |  | accept | rank 3 of Hamstring, WARRIOR Arms SkillLineAbility (ClassMask 1), MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 27584 | Hamstring | Rank 3 | WARRIOR | cc-mechanic |  | reject | NPC copy of Hamstring: not in SkillLineAbility or Talent, triggered by no player spell |
| 1236177 | Hamstring | Rank 3 | WARRIOR | cc-mechanic |  | reject | NPC copy of Hamstring (duration 28 differs from player ranks): not in SkillLineAbility or Talent, no player trigger |
| 12705 | Long Daze | Rank 1 | WARRIOR | cc-mechanic |  | reject | Long Daze is triggered only by Improved Pummel 12288/12707/12708, which is in no Talent row on Forever (unused talent), so no player can apply it |
| 12323 | Piercing Howl |  | WARRIOR | cc-mechanic |  | accept | Piercing Howl, WARRIOR Fury talent (Talent tab 256 SkillLineAbility), AoE MOD_DECREASE_SPEED mechanic 11 on enemies |
| 23600 | Piercing Howl |  | WARRIOR | cc-mechanic |  | reject | NPC copy of Piercing Howl ("near the warrior" text): not in SkillLineAbility or Talent, no player trigger |
| 5116 | Concussive Shot |  | HUNTER | cc-mechanic |  | accept | Concussive Shot, HUNTER Marksmanship SkillLineAbility (ClassMask 4), MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 13810 | Frost Trap |  | HUNTER | cc-mechanic |  | accept | Frost Trap Aura, the slow applied to enemies by the ice slick that HUNTER Frost Trap 13809 (Survival, ClassMask 4) summons; persistent area MOD_DECREASE_SPEED |
| 1264735 | Pinch | Rank 1 | HUNTER | cc-mechanic |  | accept | rank 1 of hunter pet Pinch (Pet - Crab, taught by Beast Training learn spell, ClassMask 4), MOD_DECREASE_SPEED on the hunter target, visible on target frame |
| 1264736 | Pinch | Rank 2 | HUNTER | cc-mechanic |  | accept | rank 2 of hunter pet Pinch (Pet - Crab, taught by Beast Training learn spell, ClassMask 4), MOD_DECREASE_SPEED on the hunter target, visible on target frame |
| 1264739 | Pinch | Rank 3 | HUNTER | cc-mechanic |  | accept | rank 3 of hunter pet Pinch (Pet - Crab, taught by Beast Training learn spell, ClassMask 4), MOD_DECREASE_SPEED on the hunter target, visible on target frame |
| 1264741 | Pinch | Rank 4 | HUNTER | cc-mechanic |  | accept | rank 4 of hunter pet Pinch (Pet - Crab, taught by Beast Training learn spell, ClassMask 4), MOD_DECREASE_SPEED on the hunter target, visible on target frame |
| 1264742 | Pinch | Rank 5 | HUNTER | cc-mechanic |  | accept | rank 5 of hunter pet Pinch (Pet - Crab, taught by Beast Training learn spell, ClassMask 4), MOD_DECREASE_SPEED on the hunter target, visible on target frame |
| 1265038 | Tendon Rip | Rank 1 | HUNTER | cc-mechanic |  | accept | rank 1 of hunter pet Tendon Rip (Pet - Hyena, taught by Beast Training learn spell, ClassMask 4), snare+bleed aura on the hunter target |
| 1265039 | Tendon Rip | Rank 2 | HUNTER | cc-mechanic |  | accept | rank 2 of hunter pet Tendon Rip (Pet - Hyena, taught by Beast Training learn spell, ClassMask 4), snare+bleed aura on the hunter target |
| 1265040 | Tendon Rip | Rank 3 | HUNTER | cc-mechanic |  | accept | rank 3 of hunter pet Tendon Rip (Pet - Hyena, taught by Beast Training learn spell, ClassMask 4), snare+bleed aura on the hunter target |
| 1265041 | Tendon Rip | Rank 4 | HUNTER | cc-mechanic |  | accept | rank 4 of hunter pet Tendon Rip (Pet - Hyena, taught by Beast Training learn spell, ClassMask 4), snare+bleed aura on the hunter target |
| 1265042 | Tendon Rip | Rank 5 | HUNTER | cc-mechanic |  | accept | rank 5 of hunter pet Tendon Rip (Pet - Hyena, taught by Beast Training learn spell, ClassMask 4), snare+bleed aura on the hunter target |
| 2974 | Wing Clip | Rank 1 | HUNTER | cc-mechanic |  | accept | rank 1 of Wing Clip, HUNTER Survival SkillLineAbility (ClassMask 4), MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 14267 | Wing Clip | Rank 2 | HUNTER | cc-mechanic |  | accept | rank 2 of Wing Clip, HUNTER Survival SkillLineAbility (ClassMask 4), MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 14268 | Wing Clip | Rank 3 | HUNTER | cc-mechanic |  | accept | rank 3 of Wing Clip, HUNTER Survival SkillLineAbility (ClassMask 4), MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 27633 | Wing Clip | Rank 3 | HUNTER | cc-mechanic |  | reject | NPC/later-expansion copy of Wing Clip: not in SkillLineAbility or Talent, no player trigger |
| 1310180 | Wing Clip |  | HUNTER | cc-mechanic |  | reject | unranked Wing Clip copy: not in SkillLineAbility or Talent, no player trigger |
| 3409 | Crippling Poison | Rank 1 | ROGUE | cc-mechanic |  | accept | Crippling Poison rank 1 debuff, applied by the ROGUE poison weapon coating (Snare Poison 6645 trigger), MOD_DECREASE_SPEED mechanic 11 on enemy; Retail ships 3409 |
| 11201 | Crippling Poison | Rank 2 | ROGUE | cc-mechanic |  | accept | Crippling Poison II debuff (rank 2 of the ROGUE poison), MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 25809 | Crippling Poison | Rank 1 | ROGUE | cc-mechanic |  | reject | Crippling Poison copy with no description: not in SkillLineAbility or Talent and triggered by nothing, not the rogue poison aura (3409/11201) |
| 15407 | Mind Flay | Rank 1 | PRIEST | cc-mechanic |  | accept | rank 1 of Mind Flay, PRIEST Shadow talent (Shadow Magic SkillLineAbility, ClassMask 16), channel DoT+MOD_DECREASE_SPEED on enemy target |
| 16568 | Mind Flay |  | PRIEST | cc-mechanic |  | reject | NPC copy of Mind Flay (rank closure via priest family): unranked, not in SkillLineAbility or Talent, no player trigger |
| 17165 | Mind Flay |  | PRIEST | cc-mechanic |  | reject | NPC copy of Mind Flay (rank closure via priest family): unranked, not in SkillLineAbility or Talent, no player trigger |
| 17311 | Mind Flay | Rank 2 | PRIEST | cc-mechanic |  | accept | rank 2 of Mind Flay, PRIEST Shadow Magic SkillLineAbility (ClassMask 16), DoT+MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 17312 | Mind Flay | Rank 3 | PRIEST | cc-mechanic |  | accept | rank 3 of Mind Flay, PRIEST Shadow Magic SkillLineAbility (ClassMask 16), DoT+MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 17313 | Mind Flay | Rank 4 | PRIEST | cc-mechanic |  | accept | rank 4 of Mind Flay, PRIEST Shadow Magic SkillLineAbility (ClassMask 16), DoT+MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 17314 | Mind Flay | Rank 5 | PRIEST | cc-mechanic |  | accept | rank 5 of Mind Flay, PRIEST Shadow Magic SkillLineAbility (ClassMask 16), DoT+MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 18807 | Mind Flay | Rank 6 | PRIEST | cc-mechanic |  | accept | rank 6 of Mind Flay, PRIEST Shadow Magic SkillLineAbility (ClassMask 16), DoT+MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 22919 | Mind Flay |  | PRIEST | cc-mechanic |  | reject | NPC copy of Mind Flay (rank closure via priest family): unranked, not in SkillLineAbility or Talent, no player trigger |
| 23953 | Mind Flay |  | PRIEST | cc-mechanic |  | reject | NPC copy of Mind Flay (rank closure via priest family): unranked, not in SkillLineAbility or Talent, no player trigger |
| 26143 | Mind Flay |  | PRIEST | cc-mechanic |  | reject | NPC copy of Mind Flay (rank closure via priest family): unranked, not in SkillLineAbility or Talent, no player trigger |
| 28310 | Mind Flay |  | PRIEST | cc-mechanic |  | reject | NPC copy of Mind Flay (rank closure via priest family): unranked, not in SkillLineAbility or Talent, no player trigger |
| 29407 | Mind Flay |  | PRIEST | cc-mechanic |  | reject | NPC copy of Mind Flay (rank closure via priest family): unranked, not in SkillLineAbility or Talent, no player trigger |
| 412526 | Mind Flay |  | PRIEST | cc-mechanic |  | reject | NPC copy of Mind Flay (rank closure via priest family): unranked, not in SkillLineAbility or Talent, no player trigger |
| 474204 | Mind Flay |  | PRIEST | cc-mechanic |  | reject | NPC copy of Mind Flay (rank closure via priest family): unranked, not in SkillLineAbility or Talent, no player trigger |
| 1215740 | Mind Flay |  | PRIEST | cc-mechanic |  | reject | NPC copy of Mind Flay (rank closure via priest family): unranked, not in SkillLineAbility or Talent, no player trigger |
| 3600 | Earthbind |  | SHAMAN | hand |  | accept | Earthbind, the -50% speed aura (A33, Mechanic 11) on enemies near Earthbind Totem 2484 (SHAMAN Elemental Combat SkillLineAbility) via its passive 6474; Retail ships it by hand on ccSnare |
| 8056 | Frost Shock | Rank 1 | SHAMAN | cc-mechanic |  | accept | rank 1 of Frost Shock, SHAMAN Elemental Combat SkillLineAbility (ClassMask 64), MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 8058 | Frost Shock | Rank 2 | SHAMAN | cc-mechanic |  | accept | rank 2 of Frost Shock, SHAMAN Elemental Combat SkillLineAbility (ClassMask 64), MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 10472 | Frost Shock | Rank 3 | SHAMAN | cc-mechanic |  | accept | rank 3 of Frost Shock, SHAMAN Elemental Combat SkillLineAbility (ClassMask 64), MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 10473 | Frost Shock | Rank 4 | SHAMAN | cc-mechanic |  | accept | rank 4 of Frost Shock, SHAMAN Elemental Combat SkillLineAbility (ClassMask 64), MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 8034 | Frostbrand Attack | Rank 1 | SHAMAN | hand |  | accept | rank 1 of Frostbrand Attack, the SHAMAN Frostbrand Weapon enchant's proc: -speed aura (A33) on the shaman's target |
| 8037 | Frostbrand Attack | Rank 2 | SHAMAN | hand |  | accept | rank 2 of Frostbrand Attack, the SHAMAN Frostbrand Weapon enchant's proc: -speed aura (A33) on the shaman's target |
| 10458 | Frostbrand Attack | Rank 3 | SHAMAN | hand |  | accept | rank 3 of Frostbrand Attack, the SHAMAN Frostbrand Weapon enchant's proc: -speed aura (A33) on the shaman's target |
| 16352 | Frostbrand Attack | Rank 4 | SHAMAN | hand |  | accept | rank 4 of Frostbrand Attack, the SHAMAN Frostbrand Weapon enchant's proc: -speed aura (A33) on the shaman's target |
| 16353 | Frostbrand Attack | Rank 5 | SHAMAN | hand |  | accept | rank 5 of Frostbrand Attack, the SHAMAN Frostbrand Weapon enchant's proc: -speed aura (A33) on the shaman's target |
| 11113 | Blast Wave | Rank 1 | MAGE | cc-mechanic |  | accept | rank 1 of Blast Wave, MAGE Fire talent/SkillLineAbility (ClassMask 128), AoE Dazed MOD_DECREASE_SPEED on enemies |
| 13018 | Blast Wave | Rank 2 | MAGE | cc-mechanic |  | accept | rank 2 of Blast Wave, MAGE Fire talent/SkillLineAbility (ClassMask 128), AoE Dazed MOD_DECREASE_SPEED on enemies |
| 13019 | Blast Wave | Rank 3 | MAGE | cc-mechanic |  | accept | rank 3 of Blast Wave, MAGE Fire talent/SkillLineAbility (ClassMask 128), AoE Dazed MOD_DECREASE_SPEED on enemies |
| 13020 | Blast Wave | Rank 4 | MAGE | cc-mechanic |  | accept | rank 4 of Blast Wave, MAGE Fire talent/SkillLineAbility (ClassMask 128), AoE Dazed MOD_DECREASE_SPEED on enemies |
| 13021 | Blast Wave | Rank 5 | MAGE | cc-mechanic |  | accept | rank 5 of Blast Wave, MAGE Fire talent/SkillLineAbility (ClassMask 128), AoE Dazed MOD_DECREASE_SPEED on enemies |
| 6136 | Chilled | Rank 1 | MAGE | cc-mechanic |  | accept | Chilled aura of MAGE Frost Armor (all player ranks trigger it), MOD_DECREASE_SPEED+attack slow on the enemy that strikes the mage |
| 7321 | Chilled | Rank 1 | MAGE | cc-mechanic |  | accept | Chilled aura of MAGE Ice Armor 7302/7320/10219/10220, MOD_DECREASE_SPEED+attack slow on the enemy that strikes the mage |
| 12484 | Chilled |  | MAGE | cc-mechanic |  | accept | Chilled aura of MAGE Frost talent Improved Blizzard 11185 (Frost SkillLineAbility ClassMask 128), MOD_DECREASE_SPEED on enemies in Blizzard; 12485/12486 have no effects |
| 16927 | Chilled |  | MAGE | cc-mechanic |  | reject | NPC copy of Chilled: not in SkillLineAbility or Talent and triggered by no player spell (player armor procs are 6136/7321) |
| 120 | Cone of Cold | Rank 1 | MAGE | cc-mechanic |  | accept | rank 1 of Cone of Cold, MAGE Frost SkillLineAbility (ClassMask 128), cone MOD_DECREASE_SPEED mechanic 11 on enemies |
| 8492 | Cone of Cold | Rank 2 | MAGE | cc-mechanic |  | accept | rank 2 of Cone of Cold, MAGE Frost SkillLineAbility (ClassMask 128), cone MOD_DECREASE_SPEED mechanic 11 on enemies |
| 10159 | Cone of Cold | Rank 3 | MAGE | cc-mechanic |  | accept | rank 3 of Cone of Cold, MAGE Frost SkillLineAbility (ClassMask 128), cone MOD_DECREASE_SPEED mechanic 11 on enemies |
| 10160 | Cone of Cold | Rank 4 | MAGE | cc-mechanic |  | accept | rank 4 of Cone of Cold, MAGE Frost SkillLineAbility (ClassMask 128), cone MOD_DECREASE_SPEED mechanic 11 on enemies |
| 10161 | Cone of Cold | Rank 5 | MAGE | cc-mechanic |  | accept | rank 5 of Cone of Cold, MAGE Frost SkillLineAbility (ClassMask 128), cone MOD_DECREASE_SPEED mechanic 11 on enemies |
| 116 | Frostbolt | Rank 1 | MAGE | cc-mechanic |  | accept | rank 1 of Frostbolt, MAGE Frost SkillLineAbility (ClassMask 128), MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 205 | Frostbolt | Rank 2 | MAGE | cc-mechanic |  | accept | rank 2 of Frostbolt, MAGE Frost SkillLineAbility (ClassMask 128), MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 837 | Frostbolt | Rank 3 | MAGE | cc-mechanic |  | accept | rank 3 of Frostbolt, MAGE Frost SkillLineAbility (ClassMask 128), MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 7322 | Frostbolt | Rank 4 | MAGE | cc-mechanic |  | accept | rank 4 of Frostbolt, MAGE Frost SkillLineAbility (ClassMask 128), MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 8406 | Frostbolt | Rank 5 | MAGE | cc-mechanic |  | accept | rank 5 of Frostbolt, MAGE Frost SkillLineAbility (ClassMask 128), MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 8407 | Frostbolt | Rank 6 | MAGE | cc-mechanic |  | accept | rank 6 of Frostbolt, MAGE Frost SkillLineAbility (ClassMask 128), MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 8408 | Frostbolt | Rank 7 | MAGE | cc-mechanic |  | accept | rank 7 of Frostbolt, MAGE Frost SkillLineAbility (ClassMask 128), MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 10179 | Frostbolt | Rank 8 | MAGE | cc-mechanic |  | accept | rank 8 of Frostbolt, MAGE Frost SkillLineAbility (ClassMask 128), MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 10180 | Frostbolt | Rank 9 | MAGE | cc-mechanic |  | accept | rank 9 of Frostbolt, MAGE Frost SkillLineAbility (ClassMask 128), MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 10181 | Frostbolt | Rank 10 | MAGE | cc-mechanic |  | accept | rank 10 of Frostbolt, MAGE Frost SkillLineAbility (ClassMask 128), MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 13439 | Frostbolt |  | MAGE | cc-mechanic |  | reject | NPC/proc copy of Frostbolt: unranked, not in SkillLineAbility or Talent, triggered by no player spell |
| 25304 | Frostbolt | Rank 11 | MAGE | cc-mechanic |  | accept | rank 11 of Frostbolt, MAGE Frost SkillLineAbility (ClassMask 128), MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 350025 | Frostbolt |  | MAGE | cc-mechanic |  | reject | NPC/proc copy of Frostbolt: unranked, not in SkillLineAbility or Talent, triggered by no player spell |
| 1293790 | Frostbolt |  | MAGE | cc-mechanic |  | reject | NPC/proc copy of Frostbolt: unranked, not in SkillLineAbility or Talent, triggered by no player spell |
| 1298416 | Frostbolt |  | MAGE | cc-mechanic |  | reject | NPC/proc copy of Frostbolt: unranked, not in SkillLineAbility or Talent, triggered by no player spell |
| 18118 | Aftermath |  | WARLOCK | cc-mechanic |  | accept | Aftermath slow aura, triggered by WARLOCK Destruction talent 18119 (Talent tab 301) on Conflagrate, MOD_DECREASE_SPEED on enemy target |
| 18223 | Curse of Exhaustion |  | WARLOCK | cc-mechanic |  | accept | Curse of Exhaustion, WARLOCK Affliction talent/SkillLineAbility, MOD_DECREASE_SPEED mechanic 11 on enemy target |
| 414923 | Feral Charge |  | DRUID | cc-mechanic |  | reject | Feral Charge (Cat) Daze: SoD-era id with no SkillLineAbility, no Talent and no player trigger on Forever, so unreachable |

## `racialDebuffs` (DEBUFF): 1 candidates, 1 accepted

| Id | Name | Rank | Class | Source | Origin | Ruling | Reason |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 20549 | War Stomp |  | ALL | name-map | 20549 | accept | War Stomp, Tauren Racial active, stun aura (12) on enemies; racialDebuffs may overlap a CC key |

## Precedence conflicts

None.

## Retail entries with no Forever candidate

- `defensives` WARRIOR 118038 Die by the Sword: no Forever spell of that name for the class
- `defensives` WARRIOR 184364 Enraged Regeneration: no Forever spell of that name for the class
- `defensives` WARRIOR 23920 Spell Reflection: no Forever spell of that name for the class
- `defensives` WARRIOR 12975 Last Stand: Forever 12975 applies no aura and triggers none
- `defensives` WARRIOR 385391 Spell Reflection: no Forever spell of that name for the class
- `defensives` PALADIN 31850 Ardent Defender: no Forever spell of that name for the class
- `defensives` PALADIN 86659 Guardian of Ancient Kings: no Forever spell of that name for the class
- `defensives` PALADIN 184662 Shield of Vengeance: no Forever spell of that name for the class
- `defensives` PALADIN 205191 Eye for an Eye: Forever 25997 applies no aura and triggers none
- `defensives` PALADIN 212641 Guardian of Ancient Kings: no Forever spell of that name for the class
- `defensives` PALADIN 393108 Guardian of Ancient Kings: no Forever spell of that name for the class
- `defensives` PALADIN 389539 Sentinel: no Forever spell of that name for the class
- `defensives` HUNTER 186265 Aspect of the Turtle: no Forever spell of that name for the class
- `defensives` HUNTER 264735 Survival of the Fittest: no Forever spell of that name for the class
- `defensives` ROGUE 31224 Cloak of Shadows: no Forever spell of that name for the class
- `defensives` ROGUE 1966 Feint: Forever 1966 applies no aura and triggers none
- `defensives` ROGUE 1966 Feint: Forever 6768 applies no aura and triggers none
- `defensives` ROGUE 1966 Feint: Forever 8637 applies no aura and triggers none
- `defensives` ROGUE 1966 Feint: Forever 11303 applies no aura and triggers none
- `defensives` ROGUE 1966 Feint: Forever 25302 applies no aura and triggers none
- `defensives` PRIEST 47585 Dispersion: no Forever spell of that name for the class
- `defensives` PRIEST 19236 Desperate Prayer: Forever 13908 applies no aura and triggers none
- `defensives` PRIEST 19236 Desperate Prayer: Forever 19236 applies no aura and triggers none
- `defensives` PRIEST 19236 Desperate Prayer: Forever 19238 applies no aura and triggers none
- `defensives` PRIEST 19236 Desperate Prayer: Forever 19240 applies no aura and triggers none
- `defensives` PRIEST 19236 Desperate Prayer: Forever 19241 applies no aura and triggers none
- `defensives` PRIEST 19236 Desperate Prayer: Forever 19242 applies no aura and triggers none
- `defensives` PRIEST 19236 Desperate Prayer: Forever 19243 applies no aura and triggers none
- `defensives` PRIEST 33206 Pain Suppression: no Forever spell of that name for the class
- `defensives` DEATHKNIGHT 48792 Icebound Fortitude: a Retail-only class
- `defensives` DEATHKNIGHT 48707 Anti-Magic Shell: a Retail-only class
- `defensives` DEATHKNIGHT 55233 Vampiric Blood: a Retail-only class
- `defensives` DEATHKNIGHT 49039 Lichborne: a Retail-only class
- `defensives` SHAMAN 108271 Astral Shift: no Forever spell of that name for the class
- `defensives` MAGE 342246 Alter Time: no Forever spell of that name for the class
- `defensives` MAGE 235450 Prismatic Barrier: no Forever spell of that name for the class
- `defensives` MAGE 414658 Ice Cold: no Forever spell of that name for the class
- `defensives` MAGE 235313 Blazing Barrier: no Forever spell of that name for the class
- `defensives` WARLOCK 104773 Unending Resolve: no Forever spell of that name for the class
- `defensives` WARLOCK 108416 Dark Pact: no Forever spell of that name for the class
- `defensives` MONK 120954 Fortifying Brew: a Retail-only class
- `defensives` MONK 122278 Dampen Harm: a Retail-only class
- `defensives` MONK 122783 Diffuse Magic: a Retail-only class
- `defensives` MONK 125174 Touch of Karma: a Retail-only class
- `defensives` MONK 122470 Touch of Karma: a Retail-only class
- `defensives` MONK 132578 Invoke Niuzao, the Black Ox: a Retail-only class
- `defensives` MONK 116849 Life Cocoon: a Retail-only class
- `defensives` DRUID 61336 Survival Instincts: no Forever spell of that name for the class
- `defensives` DRUID 102342 Ironbark: no Forever spell of that name for the class
- `defensives` DEMONHUNTER 212800 Blur: a Retail-only class
- `defensives` DEMONHUNTER 196555 Netherwalk: a Retail-only class
- `defensives` DEMONHUNTER 207771 Fiery Brand: a Retail-only class
- `defensives` EVOKER 363916 Obsidian Scales: a Retail-only class
- `defensives` EVOKER 374349 Renewing Blaze: a Retail-only class
- `defensives` EVOKER 357170 Time Dilation: a Retail-only class
- `activeMitigation` WARRIOR 190456 Ignore Pain: no Forever spell of that name for the class
- `activeMitigation` PALADIN 132403 Shield of the Righteous: no Forever spell of that name for the class
- `activeMitigation` DEATHKNIGHT 195181 Bone Shield: a Retail-only class
- `activeMitigation` DRUID 192081 Ironfur: no Forever spell of that name for the class
- `activeMitigation` DEMONHUNTER 203819 Demon Spikes: a Retail-only class
- `raidCDs` ALL 1243972 Void-touched Drums: no Forever spell of that name for the class
- `raidCDs` ALL 444257 Thunderous Drums: no Forever spell of that name for the class
- `raidCDs` WARRIOR 97463 Rallying Cry: no Forever spell of that name for the class
- `raidCDs` PALADIN 31821 Aura Mastery: no Forever spell of that name for the class
- `raidCDs` DEATHKNIGHT 145629 Anti-Magic Zone: a Retail-only class
- `raidCDs` DEMONHUNTER 209426 Darkness: a Retail-only class
- `raidCDs` PRIEST 81782 Power Word: Barrier: no Forever spell of that name for the class
- `raidCDs` SHAMAN 2825 Bloodlust: no Forever spell of that name for the class
- `raidCDs` SHAMAN 32182 Heroism: no Forever spell of that name for the class
- `raidCDs` SHAMAN 325174 Spirit Link Totem: no Forever spell of that name for the class
- `raidCDs` MAGE 80353 Time Warp: no Forever spell of that name for the class
- `raidCDs` HUNTER 264667 Primal Rage: no Forever spell of that name for the class
- `raidCDs` HUNTER 466904 Harrier's Cry: no Forever spell of that name for the class
- `raidCDs` EVOKER 390386 Fury of the Aspects: a Retail-only class
- `raidCDs` EVOKER 374227 Zephyr: a Retail-only class
- `offensiveCDs` WARRIOR 107574 Avatar: no Forever spell of that name for the class
- `offensiveCDs` WARRIOR 436358 Demolish: no Forever spell of that name for the class
- `offensiveCDs` DEATHKNIGHT 51271 Pillar of Frost: a Retail-only class
- `offensiveCDs` DEATHKNIGHT 207289 Unholy Assault: a Retail-only class
- `offensiveCDs` WARLOCK 1276767 Tyrant's Oblation: no Forever spell of that name for the class
- `offensiveCDs` DRUID 194223 Celestial Alignment: no Forever spell of that name for the class
- `offensiveCDs` DRUID 102560 Incarnation: Chosen of Elune: no Forever spell of that name for the class
- `offensiveCDs` DRUID 106951 Berserk: no Forever spell of that name for the class
- `offensiveCDs` DRUID 102543 Incarnation: Avatar of Ashamane: no Forever spell of that name for the class
- `offensiveCDs` DRUID 252071 Incarnation: Avatar of Ashamane: no Forever spell of that name for the class
- `offensiveCDs` HUNTER 288613 Trueshot: no Forever spell of that name for the class
- `offensiveCDs` HUNTER 360952 Coordinated Assault: no Forever spell of that name for the class
- `offensiveCDs` MAGE 12472 Icy Veins: no Forever spell of that name for the class
- `offensiveCDs` MAGE 365362 Arcane Surge: no Forever spell of that name for the class
- `offensiveCDs` ROGUE 121471 Shadow Blades: no Forever spell of that name for the class
- `offensiveCDs` ROGUE 185422 Shadow Dance: no Forever spell of that name for the class
- `offensiveCDs` DEMONHUNTER 162264 Metamorphosis: a Retail-only class
- `offensiveCDs` DEMONHUNTER 187827 Metamorphosis: a Retail-only class
- `offensiveCDs` PRIEST 194249 Voidform: no Forever spell of that name for the class
- `offensiveCDs` PRIEST 373316 Idol of Y'Shaarj: no Forever spell of that name for the class
- `offensiveCDs` MONK 137639 Storm, Earth, and Fire: a Retail-only class
- `offensiveCDs` SHAMAN 114051 Ascendance: no Forever spell of that name for the class
- `offensiveCDs` SHAMAN 114052 Ascendance: no Forever spell of that name for the class
- `offensiveCDs` SHAMAN 1219480 Ascendance: no Forever spell of that name for the class
- `offensiveCDs` EVOKER 375087 Dragonrage: a Retail-only class
- `offensiveCDs` EVOKER 431698 Temporal Burst: a Retail-only class
- `healing` DRUID 33763 Lifebloom: no Forever spell of that name for the class
- `healing` DRUID 48438 Wild Growth: no Forever spell of that name for the class
- `healing` DRUID 102352 Cenarion Ward: no Forever spell of that name for the class
- `healing` DRUID 155777 Rejuvenation (Germination): no Forever spell of that name for the class
- `healing` DRUID 207386 Spring Blossoms: no Forever spell of that name for the class
- `healing` DRUID 1227806 Lifebloom: no Forever spell of that name for the class
- `healing` PRIEST 194384 Atonement: no Forever spell of that name for the class
- `healing` PRIEST 41635 Prayer of Mending: no Forever spell of that name for the class
- `healing` PRIEST 77489 Echo of Light: no Forever spell of that name for the class
- `healing` PRIEST 1253593 Void Shield: no Forever spell of that name for the class
- `healing` SHAMAN 61295 Riptide: no Forever spell of that name for the class
- `healing` SHAMAN 974 Earth Shield: no Forever spell of that name for the class
- `healing` SHAMAN 383648 Earth Shield: no Forever spell of that name for the class
- `healing` SHAMAN 382024 Earthliving Weapon: no Forever spell of that name for the class
- `healing` MONK 119611 Renewing Mist: a Retail-only class
- `healing` MONK 124682 Enveloping Mist: a Retail-only class
- `healing` MONK 115175 Soothing Mist: a Retail-only class
- `healing` MONK 1260617 Soothing Mist: a Retail-only class
- `healing` MONK 443113 Strength of the Black Ox: a Retail-only class
- `healing` MONK 406220 Chi Cocoon: a Retail-only class
- `healing` MONK 1260681 Chi Cocoon: a Retail-only class
- `healing` EVOKER 364343 Echo: a Retail-only class
- `healing` EVOKER 366155 Reversion: a Retail-only class
- `healing` EVOKER 367364 Reversion: a Retail-only class
- `healing` EVOKER 373862 Temporal Anomaly: a Retail-only class
- `healing` EVOKER 355941 Dream Breath: a Retail-only class
- `healing` EVOKER 1291636 Temporal Barrier: a Retail-only class
- `healing` EVOKER 376788 Dream Breath: a Retail-only class
- `healing` EVOKER 409895 Verdant Embrace: a Retail-only class
- `healing` EVOKER 409678 Chrono Ward: a Retail-only class
- `healing` EVOKER 363534 Rewind: a Retail-only class
- `healing` EVOKER 373267 Lifebind: a Retail-only class
- `healing` PALADIN 53563 Beacon of Light: no Forever spell of that name for the class
- `healing` PALADIN 156910 Beacon of Faith: no Forever spell of that name for the class
- `healing` PALADIN 200025 Beacon of Virtue: no Forever spell of that name for the class
- `healing` PALADIN 287280 Glimmer of Light: no Forever spell of that name for the class
- `healing` PALADIN 1245369 Beacon of the Savior: no Forever spell of that name for the class
- `healing` PALADIN 1244893 Beacon of the Savior: no Forever spell of that name for the class
- `healing` PALADIN 156322 Eternal Flame: no Forever spell of that name for the class
- `support` HUNTER 34477 Misdirection: no Forever spell of that name for the class
- `support` ROGUE 57934 Tricks of the Trade: no Forever spell of that name for the class
- `support` ROGUE 115834 Shroud of Concealment: no Forever spell of that name for the class
- `support` ROGUE 1224098 Tricks of the Trade: no Forever spell of that name for the class
- `support` DEATHKNIGHT 454863 Lesser Anti-Magic Shell: a Retail-only class
- `support` DEATHKNIGHT 474754 Symbiotic Relationship: a Retail-only class
- `support` DRUID 474750 Symbiotic Relationship: no Forever spell of that name for the class
- `support` EVOKER 369459 Source of Magic: a Retail-only class
- `support` EVOKER 413984 Shifting Sands: a Retail-only class
- `support` EVOKER 360827 Blistering Scales: a Retail-only class
- `support` EVOKER 375253 Time Spiral: a Retail-only class
- `support` EVOKER 375230 Time Spiral: a Retail-only class
- `support` EVOKER 375226 Time Spiral: a Retail-only class
- `support` EVOKER 375229 Time Spiral: a Retail-only class
- `support` EVOKER 375257 Time Spiral: a Retail-only class
- `support` EVOKER 406789 Spatial Paradox: a Retail-only class
- `support` EVOKER 375256 Time Spiral: a Retail-only class
- `support` EVOKER 375234 Time Spiral: a Retail-only class
- `support` EVOKER 375238 Time Spiral: a Retail-only class
- `support` EVOKER 375240 Time Spiral: a Retail-only class
- `support` EVOKER 375252 Time Spiral: a Retail-only class
- `support` EVOKER 375254 Time Spiral: a Retail-only class
- `support` EVOKER 375255 Time Spiral: a Retail-only class
- `support` EVOKER 375258 Time Spiral: a Retail-only class
- `groupBuffs` SHAMAN 462854 Skyfury: no Forever spell of that name for the class
- `groupBuffs` EVOKER 381748 Blessing of the Bronze: a Retail-only class
- `groupBuffs` EVOKER 381732 Blessing of the Bronze: a Retail-only class
- `groupBuffs` EVOKER 381741 Blessing of the Bronze: a Retail-only class
- `groupBuffs` EVOKER 381746 Blessing of the Bronze: a Retail-only class
- `groupBuffs` EVOKER 381749 Blessing of the Bronze: a Retail-only class
- `groupBuffs` EVOKER 381750 Blessing of the Bronze: a Retail-only class
- `groupBuffs` EVOKER 381751 Blessing of the Bronze: a Retail-only class
- `groupBuffs` EVOKER 381752 Blessing of the Bronze: a Retail-only class
- `groupBuffs` EVOKER 381753 Blessing of the Bronze: a Retail-only class
- `groupBuffs` EVOKER 381754 Blessing of the Bronze: a Retail-only class
- `groupBuffs` EVOKER 381756 Blessing of the Bronze: a Retail-only class
- `groupBuffs` EVOKER 381757 Blessing of the Bronze: a Retail-only class
- `groupBuffs` EVOKER 381758 Blessing of the Bronze: a Retail-only class
- `movement` WARRIOR 202164 Bounding Stride: no Forever spell of that name for the class
- `movement` WARRIOR 446044 Relentless Pursuit: no Forever spell of that name for the class
- `movement` ROGUE 36554 Shadowstep: no Forever spell of that name for the class
- `movement` DEATHKNIGHT 48265 Death's Advance: a Retail-only class
- `movement` DEATHKNIGHT 444347 Death Charge: a Retail-only class
- `movement` DEATHKNIGHT 434029 Vampiric Speed: a Retail-only class
- `movement` DEATHKNIGHT 212552 Wraith Walk: a Retail-only class
- `movement` DRUID 106898 Stampeding Roar: no Forever spell of that name for the class
- `movement` DRUID 77761 Stampeding Roar: no Forever spell of that name for the class
- `movement` DRUID 77764 Stampeding Roar: no Forever spell of that name for the class
- `movement` DRUID 400126 Forestwalk: no Forever spell of that name for the class
- `movement` DRUID 252216 Tiger Dash: no Forever spell of that name for the class
- `movement` PALADIN 221886 Divine Steed: no Forever spell of that name for the class
- `movement` PALADIN 221883 Divine Steed: no Forever spell of that name for the class
- `movement` PALADIN 221885 Divine Steed: no Forever spell of that name for the class
- `movement` PALADIN 221887 Divine Steed: no Forever spell of that name for the class
- `movement` PALADIN 254471 Divine Steed: no Forever spell of that name for the class
- `movement` PALADIN 254472 Divine Steed: no Forever spell of that name for the class
- `movement` PALADIN 254473 Divine Steed: no Forever spell of that name for the class
- `movement` PALADIN 254474 Divine Steed: no Forever spell of that name for the class
- `movement` PALADIN 276111 Divine Steed: no Forever spell of that name for the class
- `movement` PALADIN 276112 Divine Steed: no Forever spell of that name for the class
- `movement` PALADIN 294133 Divine Steed: no Forever spell of that name for the class
- `movement` PALADIN 363608 Divine Steed: no Forever spell of that name for the class
- `movement` PALADIN 453804 Divine Steed: no Forever spell of that name for the class
- `movement` PALADIN 1289616 Divine Steed: no Forever spell of that name for the class
- `movement` PALADIN 1289617 Divine Steed: no Forever spell of that name for the class
- `movement` PALADIN 394454 Echoing Freedom: no Forever spell of that name for the class
- `movement` MONK 116841 Tiger's Lust: a Retail-only class
- `movement` MONK 443569 Chi-Ji's Swiftness: a Retail-only class
- `movement` MONK 450552 Jade Walk: a Retail-only class
- `movement` MONK 119085 Chi Torpedo: a Retail-only class
- `movement` SHAMAN 192082 Wind Rush: no Forever spell of that name for the class
- `movement` SHAMAN 79206 Spiritwalker's Grace: no Forever spell of that name for the class
- `movement` SHAMAN 260881 Spirit Wolf: no Forever spell of that name for the class
- `movement` SHAMAN 454025 Electroshock: no Forever spell of that name for the class
- `movement` SHAMAN 58875 Spirit Walk: no Forever spell of that name for the class
- `movement` SHAMAN 468226 Lightning Conduit: no Forever spell of that name for the class
- `movement` PRIEST 121557 Angelic Feather: no Forever spell of that name for the class
- `movement` PRIEST 65081 Body and Soul: no Forever spell of that name for the class
- `movement` PRIEST 73325 Leap of Faith: no Forever spell of that name for the class
- `movement` WARLOCK 111400 Burning Rush: no Forever spell of that name for the class
- `movement` WARLOCK 387633 Soulburn: Demonic Circle: no Forever spell of that name for the class
- `movement` EVOKER 358267 Hover: a Retail-only class
- `movement` EVOKER 374227 Zephyr: a Retail-only class
- `movement` EVOKER 442204 Breath of Eons: a Retail-only class
- `utility` WARLOCK 20707 Soulstone: no Forever spell of that name for the class
- `utility` MAGE 32612 Invisibility: no Forever spell of that name for the class
- `stances` DRUID 114282 Treant Form: no Forever spell of that name for the class
- `stances` DRUID 210053 Mount Form: no Forever spell of that name for the class
- `stances` PALADIN 32223 Crusader Aura: no Forever spell of that name for the class
- `racials` ALL 274739 Rictus of the Laughing Skull: no Forever spell of that name for the class
- `racials` ALL 274740 Zeal of the Burning Blade: no Forever spell of that name for the class
- `racials` ALL 274741 Ferocity of the Frostwolf: no Forever spell of that name for the class
- `racials` ALL 274742 Might of the Blackrock: no Forever spell of that name for the class
- `racials` ALL 273104 Fireblood: no Forever spell of that name for the class
- `racials` ALL 28880 Gift of the Naaru: no Forever spell of that name for the class
- `racials` ALL 59542 Gift of the Naaru: no Forever spell of that name for the class
- `racials` ALL 59543 Gift of the Naaru: no Forever spell of that name for the class
- `racials` ALL 59544 Gift of the Naaru: no Forever spell of that name for the class
- `racials` ALL 59545 Gift of the Naaru: no Forever spell of that name for the class
- `racials` ALL 59547 Gift of the Naaru: no Forever spell of that name for the class
- `racials` ALL 59548 Gift of the Naaru: no Forever spell of that name for the class
- `racials` ALL 121093 Gift of the Naaru: no Forever spell of that name for the class
- `racials` ALL 370626 Gift of the Naaru: no Forever spell of that name for the class
- `racials` ALL 416250 Gift of the Naaru: no Forever spell of that name for the class
- `racials` ALL 59752 Will to Survive: Forever 1259718 applies no aura and triggers none
- `racials` ALL 68992 Darkflight: no Forever spell of that name for the class
- `racials` ALL 87840 Running Wild: no Forever spell of that name for the class
- `racials` ALL 406087 Calm the Wolf: no Forever spell of that name for the class
- `racials` ALL 360022 Chosen Identity: no Forever spell of that name for the class
- `racials` ALL 1289789 Battle Visage: no Forever spell of that name for the class
- `racials` ALL 256948 Spatial Rift: no Forever spell of that name for the class
- `racials` ALL 256374 Entropic Embrace: no Forever spell of that name for the class
- `racials` ALL 291944 Regeneratin': no Forever spell of that name for the class
- `racials` ALL 281954 Pterrordax Swoop: no Forever spell of that name for the class
- `racials` ALL 255654 Bull Rush: no Forever spell of that name for the class
- `racials` ALL 291843 Brush It Off: no Forever spell of that name for the class
- `racials` ALL 436344 Azerite Surge: no Forever spell of that name for the class
- `racials` ALL 461063 Quiet Contemplation: no Forever spell of that name for the class
- `racials` ALL 1238467 Thorn Bloom: no Forever spell of that name for the class
- `racialDebuffs` ALL 107079 Quaking Palm: no Forever spell of that name for the class
- `racialDebuffs` ALL 287712 Haymaker: no Forever spell of that name for the class
- `racialDebuffs` ALL 260369 Arcane Pulse: no Forever spell of that name for the class
- `racialDebuffs` ALL 357214 Wing Buffet: no Forever spell of that name for the class
- `racialDebuffs` ALL 368970 Tail Swipe: no Forever spell of that name for the class
- `racialDebuffs` ALL 255723 Bull Rush: no Forever spell of that name for the class
- `racialDebuffs` ALL 1238474 Thorn Bloom: no Forever spell of that name for the class

## Stale rulings (no such candidate this run)

None.
