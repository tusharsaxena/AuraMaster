# Analysis — Retail re-validation, 2026-11-15 (build 12.1.5.70783)

GitHub issue #27. The first run of `tools/spell-research/retail.py`. It re-checks every Retail seed
list in `defaults/Categories_Retail.lua`, and `defaults/CastToAura.lua`, against the live Retail
build on wago.tools (product `wow`, 12.1.5.70783). The previous derivation was the 2026-09-20 run
on 12.1.0.69875, corrected from the 2026-09-24 combat logs. Every candidate and flag the run
raised is ruled in `tools/spell-research/retail_rulings.json`, and `RULINGS.md` beside this file
lists each ruling with its reason. The owner asked Claude to make the rulings (2026-11-15), the
same arrangement as the Forever run.

## What changed in the game between the two builds

Very little that touches these lists:

| Check | 12.1.0.69875 | 12.1.5.70783 |
| --- | --- | --- |
| CC buckets (`hardCC` / `ccRoot` / `ccSnare`) | 215 / 40 / 172 | identical: the same ids, buckets and classes |
| Coverage gate | PASS, 71 sentinels | PASS, 71 sentinels |
| Shipped ids the build does not name | 0 | 0 |
| Shipped ids whose name disagrees with the comment | 0 | 0 |
| Shipped ids with no aura of their own | 1 (35546 Fatal Flourish, issue #15) | the same 1 |
| Player reach (pool + racials + derived CC) | 8233 | 8241 |

The reach delta is 10 ids added and 2 removed. None of the removed ids ships. `414659` Ice Cold
gave way to `414658`, which the list already carries from the combat logs. The added ids are
`1319011` Blood Fletching (a Hunter passive, not proposed by any rule) and the 12.1 Delves curios
(Viperwind Idol, Dusty Loa Totem and six others), which appear under `ALL` and are not class
abilities. `defaults/CastToAura.lua` changes in two rows: Frost Strike gains candidate 1305700 and
Chomp gains 1310257.

## What the run proposed

559 candidates and 1 flag:

| Source | Count | Ruled |
| --- | --- | --- |
| `bridge` + `cc-mechanic` (the CC buckets) | 308 | all rejected |
| `db2-effect` (sid_seeds.DB2_RULES) | 249 | 8 accepted |
| `hand` (`HAND_CANDIDATES`) | 2 | 2 accepted |
| `shipped:no-aura` flag (35546) | 1 | kept |

### The CC carry-overs: 308 rejected

The derived CC set is the same on 12.1.5 as it was on 12.1.0, so every one of the 308 was already
in front of the 2026-09-20 curation, which deliberately shipped a starter set (the note above
`hardCC` in `defaults/Categories.lua`, rules 1 to 3). Each was rejected under that curation:

- 182 are a variant, rank or older id of an ability that already ships under the same name (rule 1);
- 114 are the long tail the curation left out (rule 3): 109 family-bridged name matches (Charge,
  Kidney Shot and Polymorph copies on NPC ids) and 5 from the mechanic graph;
- 8 are the encounter, trinket and incidental effects the curation note names (Hammer of
  Retribution, Victor's Presence, Fists of Fury and others);
- 3 are Wake of Ashes, which the owner removed on 2026-09-20;
- 1 is The Hunt's root, which the owner deleted on 2026-09-25 (review sheet R0058).

Until now these rejections existed only as prose, so every `research.py --diff` showed all 308
as additions. Recorded as data, they leave a later run's `retail.py check` showing only CC ids
that are new on that build.

### The other categories: 10 accepted

The DB2 rules are deliberately broad (`sid_seeds.DB2_RULES`): they propose, and the ruling
decides. The evidence used for each ruling was the spell's own effects and cooldown on this build,
plus the 2026-09-24 combat logs (`docs/spell-research/2026-09-24-logs/evidence.json`: 102 million
lines, 2026-02-14 to 2026-09-24). The logs show whether real players get the aura at all. Every
accepted id was seen there as a player buff:

| Category | Id | Spell | Class | Why |
| --- | --- | --- | --- | --- |
| Defensive cooldowns | 47788 | Guardian Spirit | Priest | Holy's external. The owner files externals in Defensives (Pain Suppression, Ironbark, Blessing of Sacrifice); hand candidate, since the support rule proposed it under Support |
| Defensive cooldowns | 22842 | Frenzied Regeneration | Druid | The druid self-heal cooldown, 189 druids in the logs. Forever ships it in Defensives; hand candidate, since the rules proposed it as a stance |
| Offensive cooldowns | 1250646 | Takedown | Hunter | Survival's 90 s damage cooldown |
| Offensive cooldowns | 191634 | Stormkeeper | Shaman | Elemental's 1 min cooldown, 75 shamans in the logs |
| Offensive cooldowns | 442726 | Malevolence | Warlock | The Hellcaller hero talent's 1 min cooldown |
| Offensive cooldowns | 123904 | Invoke Xuen, the White Tiger | Monk | Windwalker's 2 min cooldown, beside Storm, Earth, and Fire |
| Offensive cooldowns | 102558 | Incarnation: Guardian of Ursoc | Druid | The Guardian twin of the Feral and Balance Incarnations already shipped |
| Offensive cooldowns | 50334 | Berserk | Druid | Guardian's Berserk, the twin of Feral's 106951 |
| Utility | 3714 | Path of Frost | Death Knight | Group water walking, beside Water Walking 546 |
| Utility | 110960 | Greater Invisibility | Mage | The mage's other invisibility, beside 32612 |

The 241 rejections follow the owner's precedent in these lists. In order of how many each covers:

- **Passive auras**: always on, which the owner leaves out of the lists.
- **Racials' flight, glide and camp auras.**
- **Shadowlands covenant abilities** that never appear in the logs (Ravenous Frenzy, Weapons of
  Order, Flagellation and others).
- **Item, delve and NPC copies** filed under `ALL`.
- **Abilities in the wrong category**: Convoke the Spirits, Lunar Beam and Emerald Communion.
- **Twelve ids the owner already rejected or deleted** in the 2026-09-25 combat-log review: a
  ruling carried over, never re-litigated.

### The flag: 35546 kept

Fatal Flourish 35546 is the cast and applies no aura of its own. The file has carried it knowingly
since issue #15, so it is kept.

## What a later run should re-check

- **Proc-shaped accepts:** Stormkeeper and Malevolence are short-recast buffs. If a player finds
  either noisy in an offensive-cooldown container, remove it on the General page > Spell
  categories, or rule the id out on the next run.
- **Hero-talent cooldowns:** Takedown and Malevolence are new to Midnight. Their aura ids are the
  ones the logs show; a hero-talent rework is the likeliest place for an id to move.
- **Bundle size:** the raw tables are 24 MB because the DB2 rules read `Spell` (rank text) and
  `SpellMisc` (passive flag) alongside research.py's set. The size is acceptable for one bundle
  per patch, but worth revisiting if bundles accumulate.

## Reproducing this run

```sh
python3 tools/spell-research/retail.py derive --bundle docs/spell-research/2026-11-15-retail --date 2026-11-15 --previous docs/spell-research/2026-09-20 --replay
python3 tools/spell-research/retail.py check --bundle docs/spell-research/2026-11-15-retail
python3 tools/spell-research/research.py --replay docs/spell-research/2026-11-15-retail --emit-cast-aura --date 2026-11-15
```

`apply` was run once before this note was written. A second `apply` changes nothing, and that
idempotency is pinned by `test_retail.py`.
