# Corrections — 2026-09-24

Proposals against entries already in a `spells` category, in review order (most-applied first). **replace**: the listed id is never applied by the class while a same-name aura is. **add**: a same-name aura under another id is applied too. **move**: the entry's observed behaviour matches another category's rule (medium confidence at most). The evidence bar is 20 applications from 3 players; anything already ruled in decisions.json is not repeated.

38 proposals: 3 replace, 24 add, 11 move.

1. Healing → Support · PRIEST · Prayer of Mending — listed 41635 (Holy, 39645 apps / 51 players; Discipline, 8948 apps / 28 players) — move — medium
   - Reason: 82% of applications go to one other player (Blizzard's EXTERNAL_DEFENSIVE tag is not readable offline, so an external defensive is not excluded) → Support.
   - Rule: R5
   - Key: `move|support|PRIEST|prayer of mending|41635`

2. Offensive cooldowns · HUNTER · Bestial Wrath — listed 19574 (Beast Mastery, 5650 apps / 117 players) → 186254 (Beast Mastery, 11307 apps / 117 players), 1235388 (Beast Mastery, 5285 apps / 35 players), 1285912 (Beast Mastery, 5595 apps / 116 players) — add — high
   - Reason: HUNTER applied Bestial Wrath 22187 times under 186254, 1235388, 1285912, which is not listed.
   - Rule: evidence
   - Key: `add|offensiveCDs|HUNTER|bestial wrath|186254,1235388,1285912`

3. Soft CC (roots & snares) · DEATHKNIGHT · Chains of Ice — listed 45524 (Blood, 319 apps / 11 players; Unholy, 27 apps / 14 players; Frost, 1 app / 1 player) → 444826 (Unholy, 8395 apps / 73 players; Frost, 482 apps / 3 players; Blood, 6 apps / 1 player) — add — high
   - Reason: DEATHKNIGHT applied Chains of Ice 8883 times under 444826, which is not listed.
   - Rule: evidence
   - Key: `add|softCC|DEATHKNIGHT|chains of ice|444826`

4. Healing → Raid cooldowns · PALADIN · Beacon of Virtue — listed 200025 (Holy, 7833 apps / 27 players) — move — medium
   - Reason: 82% of applications land on 5+ players at once (1289 bursts) and DB2 says it reduces damage taken → Raid cooldowns.
   - Rule: R2
   - Key: `move|raidCDs|PALADIN|beacon of virtue|200025`

5. Healing · PRIEST · Power Word: Shield — listed 17 (Discipline, 1664 apps / 29 players; Shadow, 884 apps / 43 players) → 1246768 (Holy, 4910 apps / 30 players) — add — high
   - Reason: PRIEST applied Power Word: Shield 4910 times under 1246768, which is not listed.
   - Rule: evidence
   - Key: `add|healing|PRIEST|power word: shield|1246768`

6. Soft CC (roots & snares) · DEATHKNIGHT · Heart Strike — listed 206930 (Blood, 34142 apps / 73 players) → 460501 (Blood, 4545 apps / 64 players) — add — high
   - Reason: DEATHKNIGHT applied Heart Strike 4545 times under 460501, which is not listed.
   - Rule: evidence
   - Key: `add|softCC|DEATHKNIGHT|heart strike|460501`

7. Healing → Support · PRIEST · Atonement — listed 194384 (Discipline, 4186 apps / 29 players) — move — medium
   - Reason: 74% of applications go to one other player (Blizzard's EXTERNAL_DEFENSIVE tag is not readable offline, so an external defensive is not excluded) → Support.
   - Rule: R5
   - Key: `move|support|PRIEST|atonement|194384`

8. Movement · DRUID · Stampeding Roar — listed 106898 (Restoration, 1491 apps / 35 players; Balance, 1007 apps / 43 players; Guardian, 42 apps / 5 players; Feral, 28 apps / 4 players) → 77761 (Guardian, 2104 apps / 48 players; Balance, 3 apps / 1 player), 77764 (Feral, 477 apps / 25 players; Restoration, 278 apps / 23 players; Balance, 38 apps / 15 players; Guardian, 16 apps / 6 players) — add — high
   - Reason: DRUID applied Stampeding Roar 2916 times under 77761, 77764, which is not listed.
   - Rule: evidence
   - Key: `add|movement|DRUID|stampeding roar|77761,77764`

9. Offensive cooldowns → Defensive cooldowns · WARRIOR · Avatar — listed 107574 (Arms, 1300 apps / 72 players; Protection, 888 apps / 37 players; Fury, 653 apps / 26 players) — move — medium
   - Reason: 100% self-applied and DB2 says it reduces damage taken → Defensive cooldowns.
   - Rule: R1
   - Key: `move|defensives|WARRIOR|avatar|107574`

10. Active mitigation → Defensive cooldowns · WARRIOR · Ignore Pain — listed 190456 (Protection, 2706 apps / 37 players; Arms, 3 apps / 1 player) — move — medium
   - Reason: 100% self-applied and DB2 says it absorbs damage → Defensive cooldowns.
   - Rule: R1
   - Key: `move|defensives|WARRIOR|ignore pain|190456`

11. Healing · EVOKER · Reversion — listed 366155 (Preservation, 1636 apps / 22 players) → 367364 (Preservation, 2582 apps / 22 players) — add — high
   - Reason: EVOKER applied Reversion 2582 times under 367364, which is not listed.
   - Rule: evidence
   - Key: `add|healing|EVOKER|reversion|367364`

12. Movement · PALADIN · Divine Steed — listed 221886 (Protection, 1232 apps / 28 players; Retribution, 683 apps / 48 players; Holy, 342 apps / 28 players) → 221883 (Retribution, 501 apps / 44 players; Protection, 266 apps / 17 players; Holy, 104 apps / 15 players), 221885 (Protection, 95 apps / 6 players; Retribution, 33 apps / 4 players), 221887 (Retribution, 32 apps / 2 players; Protection, 19 apps / 1 player; Holy, 14 apps / 1 player), 254471 (Holy, 73 apps / 4 players; Retribution, 51 apps / 5 players; Protection, 37 apps / 2 players), 254472 (Retribution, 76 apps / 6 players), 254474 (Retribution, 140 apps / 8 players; Protection, 73 apps / 5 players; Holy, 13 apps / 1 player), 276111 (Retribution, 101 apps / 7 players; Holy, 92 apps / 9 players; Protection, 84 apps / 6 players), 276112 (Holy, 253 apps / 2 players; Protection, 81 apps / 5 players; Retribution, 49 apps / 5 players), 294133 (Retribution, 79 apps / 7 players; Holy, 14 apps / 1 player; Protection, 13 apps / 1 player), 363608 (Holy, 40 apps / 4 players; Protection, 28 apps / 2 players; Retribution, 20 apps / 3 players), 453804 (Retribution, 67 apps / 4 players; Holy, 21 apps / 1 player; Protection, 16 apps / 1 player) — add — high
   - Reason: PALADIN applied Divine Steed 2485 times under 221883, 221885, 221887, 254471, 254472, 254474, 276111, 276112, 294133, 363608, 453804, which is not listed.
   - Rule: evidence
   - Key: `add|movement|PALADIN|divine steed|221883,221885,221887,254471,254472,254474,276111,276112,294133,363608,453804`

13. Defensive cooldowns · DEMONHUNTER · Metamorphosis — listed 187827 (Vengeance, 593 apps / 30 players) → 162264 (Havoc, 2178 apps / 47 players) — add — high
   - Reason: DEMONHUNTER applied Metamorphosis 2178 times under 162264, which is not listed.
   - Rule: evidence
   - Key: `add|defensives|DEMONHUNTER|metamorphosis|162264`

14. Offensive cooldowns · PALADIN · Avenging Wrath — listed 231895 (never applied) → 454351 (Retribution, 2102 apps / 61 players) — replace — high
   - Reason: 231895 never applied by any PALADIN player, while 454351 applied Avenging Wrath 2102 times.
   - Rule: evidence
   - Key: `replace|offensiveCDs|PALADIN|avenging wrath|454351`

15. Offensive cooldowns · SHAMAN · Ascendance — listed 114051 (Enhancement, 106 apps / 13 players) → 114052 (Restoration, 1126 apps / 53 players), 1219480 (Elemental, 693 apps / 73 players; Restoration, 2 apps / 1 player) — add — high
   - Reason: SHAMAN applied Ascendance 1821 times under 114052, 1219480, which is not listed.
   - Rule: evidence
   - Key: `add|offensiveCDs|SHAMAN|ascendance|114052,1219480`

16. Defensive cooldowns · WARRIOR · Spell Reflection — listed 23920 (Arms, 592 apps / 59 players; Protection, 448 apps / 33 players; Fury, 303 apps / 25 players) → 385391 (Arms, 592 apps / 59 players; Protection, 448 apps / 33 players; Fury, 303 apps / 25 players) — add — high
   - Reason: WARRIOR applied Spell Reflection 1343 times under 385391, which is not listed.
   - Rule: evidence
   - Key: `add|defensives|WARRIOR|spell reflection|385391`

17. Defensive cooldowns · PALADIN · Divine Protection — listed 498 (Holy, 524 apps / 61 players) → 403876 (Retribution, 1268 apps / 139 players) — add — high
   - Reason: PALADIN applied Divine Protection 1268 times under 403876, which is not listed.
   - Rule: evidence
   - Key: `add|defensives|PALADIN|divine protection|403876`

18. Movement → Support · PALADIN · Blessing of Freedom — listed 1044 (Retribution, 545 apps / 100 players; Protection, 402 apps / 46 players; Holy, 246 apps / 41 players) — move — medium
   - Reason: 85% of applications go to one other player (Blizzard's EXTERNAL_DEFENSIVE tag is not readable offline, so an external defensive is not excluded) → Support.
   - Rule: R5
   - Key: `move|support|PALADIN|blessing of freedom|1044`

19. Offensive cooldowns → Support · PRIEST · Power Infusion — listed 10060 (Shadow, 436 apps / 47 players; Holy, 420 apps / 49 players; Discipline, 204 apps / 25 players) — move — medium
   - Reason: 100% of applications go to one other player (Blizzard's EXTERNAL_DEFENSIVE tag is not readable offline, so an external defensive is not excluded) → Support.
   - Rule: R5
   - Key: `move|support|PRIEST|power infusion|10060`

20. Healing · MONK · Soothing Mist — listed 115175 (Mistweaver, 4454 apps / 31 players) → 1260617 (Mistweaver, 948 apps / 7 players) — add — high
   - Reason: MONK applied Soothing Mist 948 times under 1260617, which is not listed.
   - Rule: evidence
   - Key: `add|healing|MONK|soothing mist|1260617`

21. Movement · HUNTER · Aspect of the Cheetah — listed 186257 (Beast Mastery, 521 apps / 104 players; Survival, 161 apps / 29 players; Marksmanship, 92 apps / 20 players) → 186258 (Beast Mastery, 520 apps / 104 players; Survival, 160 apps / 29 players; Marksmanship, 89 apps / 20 players) — add — high
   - Reason: HUNTER applied Aspect of the Cheetah 769 times under 186258, which is not listed.
   - Rule: evidence
   - Key: `add|movement|HUNTER|aspect of the cheetah|186258`

22. Healing · DRUID · Lifebloom — listed 33763 (Restoration, 3773 apps / 64 players) → 1227806 (Restoration, 740 apps / 16 players) — add — high
   - Reason: DRUID applied Lifebloom 740 times under 1227806, which is not listed.
   - Rule: evidence
   - Key: `add|healing|DRUID|lifebloom|1227806`

23. Soft CC (roots & snares) · MONK · Disable — listed 116095 (Windwalker, 877 apps / 29 players; Mistweaver, 46 apps / 1 player; Brewmaster, 37 apps / 1 player) → 116706 (Windwalker, 678 apps / 28 players) — add — high
   - Reason: MONK applied Disable 678 times under 116706, which is not listed.
   - Rule: evidence
   - Key: `add|softCC|MONK|disable|116706`

24. Raid cooldowns → Movement · EVOKER · Zephyr — listed 374227 (Augmentation, 367 apps / 20 players; Devastation, 181 apps / 14 players; Preservation, 99 apps / 9 players) — move — medium
   - Reason: DB2 says it raises movement speed → Movement.
   - Rule: R4
   - Key: `move|movement|EVOKER|zephyr|374227`

25. Offensive cooldowns · DEMONHUNTER · Metamorphosis — listed 162264 (Havoc, 2178 apps / 47 players) → 187827 (Vengeance, 593 apps / 30 players) — add — high
   - Reason: DEMONHUNTER applied Metamorphosis 593 times under 187827, which is not listed.
   - Rule: evidence
   - Key: `add|offensiveCDs|DEMONHUNTER|metamorphosis|187827`

26. Defensive cooldowns · EVOKER · Renewing Blaze — listed 374348 (never applied) → 374349 (Augmentation, 245 apps / 27 players; Preservation, 161 apps / 20 players; Devastation, 160 apps / 23 players) — replace — high
   - Reason: 374348 never applied by any EVOKER player, while 374349 applied Renewing Blaze 566 times.
   - Rule: evidence
   - Key: `replace|defensives|EVOKER|renewing blaze|374349`

27. Hard CC (loss of control) · ROGUE · Blind — listed 2094 (Subtlety, 32 apps / 14 players; Assassination, 24 apps / 13 players; Outlaw, 22 apps / 6 players) → 427773 (Outlaw, 229 apps / 4 players; Assassination, 184 apps / 14 players; Subtlety, 132 apps / 8 players) — add — high
   - Reason: ROGUE applied Blind 545 times under 427773, which is not listed.
   - Rule: evidence
   - Key: `add|hardCC|ROGUE|blind|427773`

28. Defensive cooldowns · PALADIN · Guardian of Ancient Kings — listed 86659 (Protection, 1279 apps / 60 players) → 212641 (Protection, 72 apps / 7 players), 393108 (Protection, 438 apps / 57 players) — add — high
   - Reason: PALADIN applied Guardian of Ancient Kings 510 times under 212641, 393108, which is not listed.
   - Rule: evidence
   - Key: `add|defensives|PALADIN|guardian of ancient kings|212641,393108`

29. Healing · SHAMAN · Earth Shield — listed 974 (Restoration, 325 apps / 40 players; Elemental, 104 apps / 22 players; Enhancement, 3 apps / 2 players) → 383648 (Restoration, 295 apps / 34 players; Elemental, 155 apps / 48 players; Enhancement, 40 apps / 17 players) — add — high
   - Reason: SHAMAN applied Earth Shield 490 times under 383648, which is not listed.
   - Rule: evidence
   - Key: `add|healing|SHAMAN|earth shield|383648`

30. Healing → Support · SHAMAN · Earth Shield — listed 974 (Restoration, 325 apps / 40 players; Elemental, 104 apps / 22 players; Enhancement, 3 apps / 2 players) — move — medium
   - Reason: 100% of applications go to one other player (Blizzard's EXTERNAL_DEFENSIVE tag is not readable offline, so an external defensive is not excluded) → Support.
   - Rule: R5
   - Key: `move|support|SHAMAN|earth shield|974`

31. Hard CC (loss of control) · PRIEST · Holy Word: Chastise — listed 200200 (Holy, 4 apps / 1 player) → 200196 (Holy, 400 apps / 38 players) — add — high
   - Reason: PRIEST applied Holy Word: Chastise 400 times under 200196, which is not listed.
   - Rule: evidence
   - Key: `add|hardCC|PRIEST|holy word: chastise|200196`

32. Support · EVOKER · Blessing of the Bronze — listed 381748 (Augmentation, 33 apps / 17 players; Devastation, 32 apps / 13 players; Preservation, 24 apps / 12 players) → 381732 (Augmentation, 25 apps / 8 players; Devastation, 14 apps / 8 players; Preservation, 12 apps / 8 players), 381741 (Augmentation, 21 apps / 8 players; Devastation, 15 apps / 6 players; Preservation, 8 apps / 5 players), 381746 (Augmentation, 43 apps / 8 players; Preservation, 13 apps / 4 players; Devastation, 7 apps / 4 players), 381749 (Augmentation, 20 apps / 8 players; Preservation, 14 apps / 6 players; Devastation, 7 apps / 4 players), 381750 (Preservation, 17 apps / 8 players; Augmentation, 11 apps / 3 players; Devastation, 4 apps / 3 players), 381751 (Devastation, 13 apps / 4 players; Augmentation, 10 apps / 4 players; Preservation, 1 app / 1 player), 381752 (Augmentation, 14 apps / 8 players; Devastation, 11 apps / 7 players; Preservation, 6 apps / 4 players), 381756 (Devastation, 16 apps / 7 players; Augmentation, 9 apps / 4 players; Preservation, 3 apps / 2 players), 381757 (Augmentation, 39 apps / 8 players; Preservation, 20 apps / 9 players; Devastation, 7 apps / 3 players) — add — high
   - Reason: EVOKER applied Blessing of the Bronze 380 times under 381732, 381741, 381746, 381749, 381750, 381751, 381752, 381756, 381757, which is not listed.
   - Rule: evidence
   - Key: `add|support|EVOKER|blessing of the bronze|381732,381741,381746,381749,381750,381751,381752,381756,381757`

33. Soft CC (roots & snares) · DEMONHUNTER · The Hunt — listed 323996 (never applied) → 370970 (Havoc, 166 apps / 41 players; Devourer, 97 apps / 11 players) — replace — high
   - Reason: 323996 never applied by any DEMONHUNTER player, while 370970 applied The Hunt 263 times.
   - Rule: evidence
   - Key: `replace|softCC|DEMONHUNTER|the hunt|370970`

34. Defensive cooldowns · MONK · Touch of Karma — listed 125174 (Windwalker, 171 apps / 26 players) → 122470 (Windwalker, 238 apps / 41 players) — add — high
   - Reason: MONK applied Touch of Karma 238 times under 122470, which is not listed.
   - Rule: evidence
   - Key: `add|defensives|MONK|touch of karma|122470`

35. Hard CC (loss of control) · HUNTER · Intimidation — listed 24394 (Marksmanship, 46 apps / 11 players) → 1258508 (Marksmanship, 201 apps / 9 players) — add — high
   - Reason: HUNTER applied Intimidation 201 times under 1258508, which is not listed.
   - Rule: evidence
   - Key: `add|hardCC|HUNTER|intimidation|1258508`

36. Healing → Support · PALADIN · Beacon of Faith — listed 156910 (Holy, 50 apps / 26 players) — move — medium
   - Reason: 92% of applications go to one other player (Blizzard's EXTERNAL_DEFENSIVE tag is not readable offline, so an external defensive is not excluded) → Support.
   - Rule: R5
   - Key: `move|support|PALADIN|beacon of faith|156910`

37. Healing → Support · PALADIN · Beacon of Light — listed 53563 (Holy, 46 apps / 22 players) — move — medium
   - Reason: 87% of applications go to one other player (Blizzard's EXTERNAL_DEFENSIVE tag is not readable offline, so an external defensive is not excluded) → Support.
   - Rule: R5
   - Key: `move|support|PALADIN|beacon of light|53563`

38. Offensive cooldowns · DRUID · Incarnation: Avatar of Ashamane — listed 102543 (Feral, 32 apps / 3 players) → 252071 (Feral, 32 apps / 3 players) — add — high
   - Reason: DRUID applied Incarnation: Avatar of Ashamane 32 times under 252071, which is not listed.
   - Rule: evidence
   - Key: `add|offensiveCDs|DRUID|incarnation: avatar of ashamane|252071`
