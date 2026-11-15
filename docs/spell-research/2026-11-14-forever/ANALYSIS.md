# Analysis — WoW Forever seed lists, 2026-11-14

Build `1.60.1.70938` (WoW Forever, product `wowf`). Written by hand for AM-FP05. Every candidate, its
ruling and its one-line reason is in `RULINGS.md` (generated) and `tools/spell-research/forever_rulings.json`.
This file is the reading of those numbers.

## How the run went

1. `research.py --client forever --bundle docs/spell-research/2026-11-14-forever --date 2026-11-14`
   froze the raw tables, `SOURCES.md`, `derived.json` and `DIFF.md`. The coverage gate passed
   (7 Forever sentinels).
2. `forever.py derive` proposed **710 candidates** across the 15 `spells` categories. They come from
   five sources: `cc-mechanic`, `name-map`, `db2-effect`, `bridge` (none this run) and `hand`, which
   is new in this task (see "Tool changes").
3. Five rulers each took one group of categories, and an auditor then reviewed each group against
   the DB2 tables. The disputes and the missed-spell lists the audits raised were settled here (see
   below). All 710 candidates are ruled: **452 accepted, 258 rejected**. `derive` reports 0 unruled
   and 0 stale.
4. `forever.py emit` wrote `defaults/Categories_Forever.lua` (one part, 659 lines) and
   `defaults/CastToAura_Forever.lua` (648 lines). Both are CRLF and under the 1400-line cap. Emit
   dropped no conflicts: every accepted id is in one category, apart from the allowed `racialDebuffs`
   overlap with War Stomp 20549.

## Per category

| Category | Candidates | Accepted | Rejected | Accepted, by spell |
| --- | ---: | ---: | ---: | --- |
| defensives | 35 | 21 | 14 | Shield Wall, Last Stand 12976; Divine Shield, Divine Protection, Blessing of Protection, Blessing of Sacrifice (every rank), Templar's Bulwark; Deterrence; Evasion; Ice Block, Ice Barrier (4); Barkskin, Frenzied Regeneration |
| activeMitigation | 21 | 5 | 16 | Shield Block; Holy Shield (4, including Forever's rank 4 1239570) |
| raidCDs | 8 | 4 | 4 | Tranquility (4 ranks) |
| offensiveCDs | 23 | 13 | 10 | Recklessness, Death Wish; Bestial Wrath, Rapid Fire; Adrenaline Rush, Blade Flurry, Cold Blood; Arcane Power, Combustion (11129 + 28682), Presence of Mind; Lightning Mastery 16166; Amplify Curse |
| healing | 117 | 73 | 44 | Renew (10), Power Word: Shield (10), Lightwell Renew (3), Contingency Plan heal-over-time and absorb (10); Rejuvenation (22), Regrowth (18). The druid counts include the 20 Enhanced Restoration overrides (see #26) |
| support | 13 | 8 | 5 | Power Infusion, Fear Ward, Contingency Plan ward (5 ranks); Innervate |
| groupBuffs | 73 | 59 | 14 | Battle Shout (7); Power Word: Fortitude (6), Prayer of Fortitude (2), Shadow Protection (3), Prayer of Shadow Protection, Divine Spirit (4), Prayer of Spirit; Arcane Intellect (5), Arcane Brilliance; Mark of the Wild (7), Gift of the Wild (2); Blessings of Might (7), Wisdom (6), Kings, Greater Blessings of Might (2), Wisdom (2), Kings; Horn of Lordaeron |
| movement | 39 | 15 | 24 | Sprint (3); Dash (2); Aspect of the Cheetah, Aspect of the Pack, Strider Kick; Blessing of Freedom; Ghost Wolf 2645 and 1238640; Bloodthirst's speed aura (4) |
| utility | 35 | 20 | 15 | Stealth (4), Vanish (2); Prowl (3); Feign Death; Slow Fall; Levitate; Water Walking, Water Breathing; Unending Breath; Soulstone Resurrection (5) |
| stances | 66 | 33 | 33 | Battle, Defensive and Berserker Stance; Devotion (7), Retribution (5), Concentration, Sanctity, Fire, Frost and Shadow Resistance Aura (3 each); Bear, Dire Bear, Cat, Travel, Aquatic and Moonkin Form; Shadowform |
| racials | 43 | 19 | 24 | Stoneform, Escape Artist, Shadowmeld, Will of the Forsaken, Cannibalize, Berserking, Blood Fury, Perception, Eureka! (5 class variants) and Forever's racial actives (Elune's Light, Elemental Blessing, Energized, Rapid Regeneration, Shatter Curse, Walk on Air) |
| hardCC | 114 | 82 | 32 | Every rank of Polymorph (6, plus Cow), Hammer of Justice (4), Fear, Psychic Scream (4), Gouge (5), Sap (3), Kidney Shot (2), Intercept Stun (3) and the rest; War Stomp under ALL |
| ccRoot | 36 | 36 | 0 | Entangling Roots (12, including Nature's Grasp), Frost Nova (4), Frostbite, Improved Hamstring, Improved Wing Clip, Entrapment, Counterattack (4), Feral Charge, Chastise (5), and the hunter pet abilities Web (5) and Boar Charge |
| ccSnare | 86 | 63 | 23 | Hamstring (3), Piercing Howl, Frostbolt (11), Cone of Cold (5), Blast Wave (5), Chilled (3), Mind Flay (6), Frost Shock (4), Earthbind, Frostbrand Attack (5), Wing Clip (3), Concussive Shot, Frost Trap, Crippling Poison (2), Aftermath, Curse of Exhaustion, pet Pinch (5) and Tendon Rip (5) |
| racialDebuffs | 1 | 1 | 0 | War Stomp |
| **Total** | **710** | **452** | **258** | |

**No category is empty.** `NS.CategorySeedsForever.EMPTY` is `{}`, so AM-FP06's gate removes nothing.
The thinnest lists are `racialDebuffs` (1 id: War Stomp, Forever's only racial debuff) and `raidCDs`
(4 ids, all Tranquility). Vanilla has no Bloodlust, Rallying Cry, Aura Mastery or Barrier, so both lists
stand on what is real. Neither was padded to avoid an empty list.

## Notable rejections, by kind

- **NPC copies.** These ids carry a player spell's name, and often its class family, but have no
  SkillLineAbility row, no Talent row and no trigger or override edge from a player spell. Examples:
  Shield Wall 15062/29061/1277424, Evasion 15087, Ice Block 27619, Recklessness 13847, Tranquility
  21791/25817/1253568, Ice Barrier 1213278, Mind Flay 16568 and its siblings, Frostbolt
  13439/350025/1293790/1298416, Blast Wave 15091/17145/…, Intimidating Shout 19134/29544, Charge
  22911, Banish 457569/465352, and the duplicate Battle Shout, Fortitude, Arcane Intellect and Mark
  of the Wild ranks. These are the AM-FP03 "known traps" (a), and every one is rejected.
- **Runes (owner ruling 3).** These reach a player only through an override (aura 332) installed by
  an Engraving rune or a set bonus. Examples: Malleable Protection 458312/458371, Improved Barkskin
  428713, the Avenging Wrath rune 407788/409934, the Empowered Renew overrides 425268–425277, the
  Advanced Warding Mana Shield and Ward copies 412116–412232, Sacred Shield 412020, Valor of Azeroth
  461475, Divine Sacrifice 407804 and the rune Ghost Wolf 415233.
- **Passives.** These have the `SPELL_ATTR0_PASSIVE` flag or are hidden talent procs, so they never
  show as an aura: Deflection, Shield Specialization, Anticipation, Lightning Reflexes, Feral
  Swiftness, Eye for an Eye, Feline Grace, Safe Fall, the passive racial traits and the Flametongue
  Totem passives.
- **Pet-line abilities.** Shell Shield and Trickster's Dance are pet buffs; hunter pet Dash, Dive and
  Prowl are pet movement. They are rejected because the pet line is out of the pool and the Retail
  lists hold no pet buffs. The hunter pet CC (Web, Pinch, Tendon Rip, Boar Charge, Intimidation 24394)
  is **accepted**: it lands on the hunter's target, which is what a CC filter shows (AM-FP03 trap b).
- **The wrong category.** Each such id is kept in one place only: Tranquility in `raidCDs` (the
  Retail owner's 2026-09-25 placement), Eureka! and Berserking in `racials`, Aspect of the Pack in
  `movement`, Stealth and Prowl in `utility`, Ice Block in `defensives`, and Blessing of Protection in
  `defensives` (see the disputes below).
- **Hunter aspects and party auras in Stances.** Trueshot Aura (5), Aspect of the Wild (2), Moonkin
  Aura 24907 and Leader of the Pack 24932 are rejected from Stances. Retail's Stances means warrior
  stances, druid forms and paladin auras. The druid forms that carry those party auras are already
  accepted, and the hunter aspects are not treated as stances (Monkey and Hawk are not in any list
  either). This is a judgment call for the owner's smoke run.

## Disputes settled (from the audits)

1. **Blessing of Protection 1022/5599/10278: moved from `support` to `defensives`.** The DB2 shape is
   the same as Blessing of Sacrifice 6940/20729, which was already accepted in Defensives: both are
   on Protection line 267 with ClassMask 2 and target a party member (ImplicitTarget 57). BoP also
   carries the A39 school immunity with Mechanic 25. The Retail owner put the big externals (Blessing
   of Sacrifice, Pain Suppression, Ironbark, Life Cocoon, Time Dilation) in Defensives "not in
   Support". The `support:` keys are now rejected, and new `hand` candidates `defensives:*` are
   accepted.
2. **Ghost Wolf 1238640 in `movement`: rejected, now accepted.** The first ruling said no player
   could reach it. That is wrong: the Improved Ghost Wolf talent 16262 (Talent 605, Enhancement
   SkillLineAbility) has an override (aura 332) with MiscValue 2645 and BasePoints 1238640. A talented
   shaman therefore wears 1238640 in place of 2645, with the same wolf form (36) and +40% speed (31).
   The `stances:1238640` reject stands (Retail keeps Ghost Wolf in Movement). The rune copy 415233
   stays rejected.
3. **Earthbind 3600 in `ccSnare`: a missing candidate, now added by hand and accepted.** Earthbind is
   an A33 −50% speed aura with Mechanic 11 on area enemies, triggered only by Earthbind Totem Passive
   6474 on the totem that 2484 summons (Elemental Combat, ClassMask 64). The trigger closure cannot
   cross a summon. Retail ships 3600 by hand for the same reason (owner 2026-10-04).

The other audits (G2 healing and buffs, G4 hardCC, G5 roots and snares, apart from Earthbind) found
nothing they could refute from the DB2 tables. Their open questions are carried to #26 below.

## Missed spells the tool did not surface: verified, and what was done

The auditors listed spells no source proposed. Each was checked in the DB2 tables (SkillLineAbility
or Talent reachability, the aura effect and the target). The ones that fit a category were added as
`hand` candidates (`forever.py` HAND_CANDIDATES) and then ruled like any other candidate:

| Added and accepted | Category | Why no source found it |
| --- | --- | --- |
| Blessing of Protection 1022, 5599, 10278 | defensives | the support rule proposed it; the dispute above moved it |
| Frenzied Regeneration 22842 (bear, 3 min) | defensives | aura 23 (periodic trigger) is not in the defensives rule |
| Rapid Fire 3045, Blade Flurry 13877, Cold Blood 14177, Presence of Mind 12043, Lightning Mastery 16166 | offensiveCDs | auras 140, 319, 107 and a negative 108 are outside the offensive rule; all are 2–5 min damage cooldowns at the bar the accepted Arcane Power and Amplify Curse set |
| Blessing of Might (7), Wisdom (6), Kings 20217; Greater Blessing of Might (2), Wisdom (2), Kings 25898 | groupBuffs | they target one ally (21) or a class (153), outside the GROUP fence; these are the paladin's maintained group buffs on vanilla |
| Shadow Protection 976/10957/10958, Divine Spirit 14752/14818/14819/27841 | groupBuffs | single-target twins of the accepted Prayer buffs (like Power Word: Fortitude beside Prayer of Fortitude) |
| Soulstone Resurrection 20707, 20762–20765 | utility | cast by the soulstone item, so no class edge; Retail lists 20707 |
| Cannibalize 20578 | racials | the racial cast 20577 is a dummy effect that applies the aura by script |
| War Stomp 20549 (ALL) | hardCC | the CC derivation is class-only; Retail ships it in hardCC and Racials (allowed overlap) |
| Earthbind 3600 | ccSnare | the dispute above |
| Frostbrand Attack 8034, 8037, 10458, 16352, 16353 | ccSnare | the Frostbrand Weapon enchant procs it, and the enchant is not in the tables |
| Fire, Frost and Shadow Resistance Aura (3 ranks each) | stances | a tool bug: effect 65 (APPLY_AREA_AURA_RAID) was not an aura effect. Fixed, so `db2-effect` now finds them |

Checked and **not** added, with the reason:

- **Mana Shield, Fire Ward, Frost Ward, Shadow Ward.** These are rotational absorbs with no recast or a
  30 s one, not personal defensive cooldowns. Retail's mage list holds the big ones.
- **Retaliation 20230.** A counter-attack buff, not damage reduction, so it fits no Retail category's
  meaning. Left for the owner.
- **Sweeping Strikes 12292** (30 s recast) and **Berserker Rage 18499** (30 s fear immunity). These
  are rotation buttons.
- **Inner Focus 14751, Divine Favor 20216, Nature's Swiftness 16188/17116.** Mana, heal-crit and
  instant-cast buttons used for healing, not damage cooldowns.
- **Sacrifice 7812/19438–19443 (Voidwalker) and Seduction 6358 (Succubus).** These sit on pet skill
  lines, which are fenced out of the pool (spec §3.5). Retail records the same gap for Seduction.
- **Mend Pet.** A heal over time on the pet. The Retail Healing list holds no pet heals.
- **Blessing of Salvation, Light and Sanctuary.** The paladin SkillLineAbility rows exist (1038, 19977,
  19979, 25890, 20911, 25895, 25899), but none of those ids has a SpellName, Spell or SpellEffect row in
  the 1.60.1.70938 export, so there is no aura to ship. The only "Blessing of Light" with spell rows is
  the NPC id 26650. Absent from the client data is not proven unreachable on the server; #26 checks.
- **Black Arrow 3674/14296.** It is a −70% snare (A33) on the target, in the HUNTER pool through a
  Marksmanship SkillLineAbility row (ClassMask 4, AcquireMethod 0). But it has Mechanic 0, so the CC
  derivation does not bucket it, and no spell teaches or triggers it. It reads like vanilla's unused
  beta hunter spell rather than something a trainer sells, so it is not added. #26 should check.

## The 266 Retail entries with no Forever candidate

These are listed in `RULINGS.md` under "Retail entries with no Forever candidate".

- **91 are under a Retail-only class** (Death Knight, Monk, Demon Hunter, Evoker). Forever has nine
  classes.
- **160 have no Forever spell of that name for the class.** These are later-expansion abilities:
  Die by the Sword, Spell Reflection, Ardent Defender, Aspect of the Turtle, Cloak of Shadows, Pain
  Suppression, Astral Shift, Bloodlust/Heroism/Time Warp, Rallying Cry, Avatar, Trueshot, Icy Veins,
  Lifebloom, Wild Growth, Prayer of Mending, Riptide, Earth Shield, Beacon of Light, Misdirection,
  Tricks of the Trade, Divine Steed (15 ids), Stampeding Roar, Shadowstep, Gift of the Naaru (10),
  the Allied-race racials, and so on.
- **15 have a Forever spell of that name that applies no aura and triggers none.** Last Stand 12975
  (its aura 12976 is found by name and accepted), Eye for an Eye 25997 (a dummy-effect proc), Feint (5 ranks,
  a threat dump with no aura on Forever), Desperate Prayer (7 ranks, an instant heal on Forever),
  and Will to Survive 1259718.

No HAND_CANDIDATES entry fell out on this build: all of them are auras here.

## Tool changes in this task

- `research.FOREVER_AURA_EFFECTS` gains **65 APPLY_AREA_AURA_RAID**. Vanilla's resistance auras,
  Trueshot Aura, Aspect of the Wild and Moonkin Aura are effect 65 alone. Without it, none of them
  counted as an aura (Stances could not see them, and the cast table marked them "can never match").
  `derived.json` (CC buckets) is unchanged by this. `CastToAura_Forever.lua` reflects it. Retail is
  untouched (effect 6 alone, and `sid_db2` keeps its own set).
- `forever.py`: the stances rule's area aura now accepts effects 35 and 65. There is a new `hand`
  source, `HAND_CANDIDATES`, with one reason per id. A hand id that is not an aura on the build goes
  to `unmapped`, so a later build shows what fell out. An unknown category or a non-Forever class is
  an error.
- Tests: `test_hand_candidates_join_and_miss` and `test_raid_area_auras_count` in `test_forever.py`.

## Reproducibility

- `forever.py derive --replay` on a temporary copy of this bundle reproduces `candidates.json`
  byte for byte, offline.
- `emit` from that copy reproduces `CastToAura_Forever.lua` and `RULINGS.md` byte for byte.
  `Categories_Forever.lua` matches apart from its provenance line, which names the bundle path.
- `research.py --replay docs/spell-research/2026-11-14-forever --client forever --diff` runs offline
  and the coverage gate passes.

## What issue #26's combat-log run should re-check

1. **The two G2 rune suspects.** Enhanced Restoration 417123, which gates the 20 accepted
   Rejuvenation and Regrowth overrides, and Horn of Lordaeron 425600 (groupBuffs). Both are on class
   lines with AcquireMethod 3, alongside known runes. Neither has an Engrave spell or a slot wrapper.
   If the logs never show them on a non-rune character, reject them.
2. **Polymorph: Cow 28270.** Its SkillLineAbility is identical to Turtle's, but only Pig 28272 has a
   learn spell. Check whether it is obtainable.
3. **Proc auras** (Blackout 15269, Impact 12355, Pyroclasm 18093, Starfire Stun 16922, the Seal of
   Justice stun 20170, Improved Concussive Shot 19410, Frostbite, Aftermath, Frostbrand Attack).
   Confirm each shows under the accepted id. Also check whether any hunter can learn and cast Black
   Arrow 3674/14296. It is left out for now; if one can, add it to `ccSnare`.
4. **The hand additions without a class edge.** Soulstone Resurrection (each soulstone rank),
   Cannibalize 20578, Earthbind 3600, Frostbrand Attack and Ghost Wolf 1238640 (talented). Confirm
   the aura id the client reports.
5. **The judgment calls.** The paladin Blessings in Group buffs (not Support), Blessing of Protection
   in Defensives, the hunter aspects, Trueshot Aura, Moonkin Aura and Leader of the Pack left out of
   Stances, and Find Treasure 2481 (a tracking aura; whether it shows as a buff is a client question).
6. **The cast table's name-only choices.** `CastToAura_Forever.lua` CHOICES offers same-named ids,
   some of them rune or NPC ids (for example Flash of Light → 412020, Charge → its NPC copies). These
   are suggestions only, never rewrites, but the logs can confirm the real aura for each cast.
7. **Spells with a SkillLineAbility row but no spell rows.** Blessing of Salvation, Light and
   Sanctuary, and Frenzied Regeneration ranks 2 and 3 (22895, 22896). 1127 class-line ids are in this
   state in the export. If the logs show any of them, add it to its category.
