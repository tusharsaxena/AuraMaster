# Analysis — spell research, 2026-09-20 (build 12.1.0.69875)

The first frozen run of `tools/spell-research/research.py` (GitHub issue #11, Part C; design of
record `docs/superpowers/specs/2026-09-20-cc-categories-spell-research-design.md`). It is also the
first run of the pipeline after the coverage gate was rebuilt, and the two facts are related: the
run that would have been frozen a few hours earlier reported PASS over a list missing five of the
most recognisable stuns in the game.

## What the run produced

| Bucket | Spells | From the mechanic graph | Added by the family bridge |
| --- | --- | --- | --- |
| `hardCC` | 215 | 77 | 138 |
| `softCC` | 212 | 52 | 160 |

Player pool 8,204 spells: 7,020 from skill lines, specializations and talent trees, +886 from the
`EffectTriggerSpell` closure, +298 from the spell-family bridge, settled after three passes of the
two steps alternating. Class keys: 46 of the 427 derived ids fall to `ALL`, and 40 carry
`classSource: "unknown"`.

Mechanic mix — `hardCC` is 87 stunned, 59 polymorphed, 18 disoriented, 13 fleeing, 9 incapacitated,
8 frozen, 5 charmed, 5 sapped, 4 banished, 3 asleep, 2 horrified, 2 turned, 1 shackled. `softCC` is
170 snared, 40 rooted, 2 dazed. The polymorphed count is the shape to expect: every Polymorph
variant in the mage family is a separate id, and all of them are live.

## Why this run is not the run that was nearly frozen

The previous cut fenced the name bridge to spells carrying effect 179, `CREATE_AREATRIGGER`. That
fence was fitted to the one case that had failed — Freezing Trap — and by construction could not see
the two other shapes of handoff the client uses. It excluded, with the gate reporting PASS
throughout:

| Spell | Aura id | How the client gets there |
| --- | --- | --- |
| Storm Bolt | 132169 | 107570 is damage + `DUMMY`; the stun comes from a server spell script |
| Ring of Frost | 82691 | 113724 summons creature 44199 and triggers 136511; the stun hangs off the ring |
| Blinding Light | 105421 | 115750 is a `DUMMY`; same shape as Storm Bolt |
| Holy Word: Chastise | 200200 | 88625 is damage + `DUMMY`; the stun is the Censure variant |
| Capacitor Totem | 118905 | 192058 summons creature 61245; the totem casts the stun |
| Repentance | 20066 | not reachable at all — see below |

All five of the first group are in this run, each labelled `"source": "bridge"`. The bridge now
rests on `SpellClassOptions.SpellClassSet`, the client's own spell *family*, rather than on an
effect id: a pool spell bridges to a spell with the same exact name **and** the same non-zero
family. Measured on this build that is 298 ids, against 1,763 for a bare name match and 547 for a
fence generalised to effects 179, 28 and 3. `tools/spell-research/README.md` has the reasoning and
the per-pair family numbers.

## The gate

66 sentinels, grouped by class, chosen by writing down what a player would name as each class's
crowd control and *then* making the pipeline satisfy them — the opposite of how the first list was
assembled. Verified to still fail: removing mechanics 12 (Stunned) and 13 (Frozen) from
`BUCKET_MECHANICS` exits 1 and names 18 missing sentinels.

Two names on the domain list are in `SENTINELS_UNREACHABLE` rather than in the gate, with their
reasons recorded in code and in the README:

- **Repentance (20066).** The string `20066` occurs in none of `SkillLineAbility`,
  `SpecializationSpells`, `TraitDefinition` or `TraitNodeEntry` for this build, no `SpellEffect` row
  names it as an `EffectTriggerSpell`, and all eighteen spells named "Repentance" sit outside the
  pool. It carries mechanic 14 and is unquestionably a paladin ability, so the client grants it by a
  route none of the four pool sources describes. This is the one hard-CC name on the domain list
  that no amount of pipeline work reached.
- **Pet CC — Axe Toss (89766), Seduction (6358).** Both are in `SkillLineAbility` with `ClassMask` 0
  on a pet skill line (761/931 felguard, 205 succubus), and the pool keeps a `ClassMask`-0 row only
  on one of the thirteen class lines — the same test that keeps professions and mounts out.
- **Earthbind Totem (2484)** is in the pool but carries no mechanic, and its aura is named
  "Earthbind": neither the mechanic match nor the family bridge's exact-name test can cross to it.

## For the author accepting the diff

`DIFF.md` reads as all additions, because `defaults/Categories.lua` has no `hardCC` or `softCC` keys
yet (Part A). The judgment to exercise before pasting anything:

1. **The 298 bridged ids are name matches inside a family**, not directed edges. Each is flagged in
   all three outputs. Several names cover more than one live-looking id; the tool deliberately does
   not guess which is current, because guessing is silent and a surplus id is merely visible.
2. **`softCC` is 170 snared ids.** Part A's definition is "the unit keeps control but moves less",
   and a good share of those are self-buffs' incidental slows rather than crowd control anybody
   tracks. That list wants pruning more than `hardCC` does.
3. **The 40 `classSource: "unknown"` ids** are emitted under `ALL`. They are real, but grouping them
   under `ALL` in the editor is a cosmetic lie; check whether any of them deserve a class key by
   hand.

Nothing here has been pasted into `defaults/Categories.lua`. The tool never writes it, and this
bundle is the input to that decision, not the decision.
