#!/usr/bin/env python3
"""tools/spell-research/forever.py — WoW Forever's seed lists for every `spells` category (AM-FP04).

WHAT THIS IS
    research.py --client forever derives the three CC buckets from Forever's DB2 by mechanic, as on
    Retail. Every OTHER `spells`-kind category of defaults/Categories.lua (Defensive cooldowns,
    Stances, Group buffs, Racials, ...) is a hand-curated Retail list, and nothing in DB2 names
    those categories. This tool builds Forever's version of each in three steps, and never edits
    defaults/Categories.lua:

    1. CANDIDATES (`derive`). Four sources, each candidate labelled with where it came from:
         name-map    a Retail entry's spell NAME, matched to the same class's Forever spells, every
                     rank. Forever keeps vanilla's ranks as separate ids (Battle Shout 6673, 5242,
                     ...), so a name maps to several. A cast that applies no aura of its own is
                     followed along EffectTriggerSpell to the aura it lands (the Freezing Trap
                     shape, research.triggered_auras): the addon filters on the AURA's id.
         db2-effect  a Forever spell whose own aura effects fit the category: SPELL_AURA_MOD_
                     SHAPESHIFT (36) on yourself for Stances, a raid or party aura for Group buffs,
                     and so on. DB2_RULES below spells out every rule. This is what finds the
                     vanilla-only spells no Retail entry names.
         cc-mechanic research.derive's hardCC / ccRoot / ccSnare buckets, unchanged (`bridge` for
                     the family-bridged ones).
         hand        HAND_CANDIDATES below: the ids no table edge reaches (a totem's aura, an
                     item's or an enchant's proc, a scripted racial), each with its reason.
    2. RULINGS (`rule`). Every candidate is accepted or rejected, with a one-line reason, into
       forever_rulings.json. `rule` is the only writer of that file. A name match is a candidate,
       never a conclusion: NPC copies share a player spell's name and family.
    3. EMIT (`emit`). The accepted ids are written into defaults/Categories_Forever*.lua as
       NS.CategorySeedsForever, plus NS.CategorySeedsForever.EMPTY (the categories with nothing on
       Forever, which AM-FP06 gates off), and defaults/CastToAura_Forever.lua. `emit` refuses to
       run while any candidate is unruled, so a re-derive that finds something new can never ship
       it silently. The rulings are data, so a re-run reproduces the shipped lists exactly.

    Design of record: docs/superpowers/specs/2026-11-14-auramaster-forever-port-design.md, §3.3 to
    §3.5. Plan: docs/superpowers/plans/2026-11-14-auramaster-forever-port.md, AM-FP04.

ONE CATEGORY PER ID
    Within one aura type an id ships in ONE category: the first in the order defaults/Categories.lua
    declares them (SPELL_CATEGORIES). A later accepted duplicate is dropped at emit and recorded as
    a conflict in RULINGS.md. The one exception is the Retail file's own: Racials (racialDebuffs)
    "only groups" racial debuffs that "stay in CC Loss of Control, CC Root and CC Snare as well"
    (its comment), so those pairs may overlap (ALLOWED_OVERLAPS).

USAGE
    python3 tools/spell-research/research.py --client forever --bundle docs/spell-research/2026-11-14-forever --date 2026-11-14
    python3 tools/spell-research/forever.py derive --bundle docs/spell-research/2026-11-14-forever --date 2026-11-14
    python3 tools/spell-research/forever.py rule --key defensives:871 --ruling accept --reason "Shield Wall: the warrior's"
    python3 tools/spell-research/forever.py emit --bundle docs/spell-research/2026-11-14-forever --date 2026-11-14
    python3 tools/spell-research/forever.py derive --bundle docs/spell-research/2026-11-14-forever --date 2026-11-14 --replay

    `derive` reads research.py's frozen raw/ tables from the bundle and adds the three it needs
    beyond them (EXTRA_TABLES), fetched once into the same raw/ and replayed from there after.

Python 3 and its standard library only, like research.py.
"""

from __future__ import annotations

import argparse
import gzip
import json
import re
import shutil
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import NamedTuple

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import research  # noqa: E402
import sid_db2  # noqa: E402

CLIENT = "forever"

# ---------------------------------------------------------------------------
# AUTHORED INPUTS
# ---------------------------------------------------------------------------

# Every `kind = "spells"` category of defaults/Categories.lua, IN THE ORDER THAT FILE DECLARES THEM,
# with its aura type (Cat.HELPFUL -> BUFF, Cat.HARMFUL -> DEBUFF). The order is the precedence (one
# category per id within an aura type) and the emit order. test_forever.py checks it against the
# real file, so a category added there fails the suite until it is added here.
SPELL_CATEGORIES = (
    ("defensives", "BUFF"),
    ("activeMitigation", "BUFF"),
    ("raidCDs", "BUFF"),
    ("offensiveCDs", "BUFF"),
    ("healing", "BUFF"),
    ("support", "BUFF"),
    ("groupBuffs", "BUFF"),
    ("movement", "BUFF"),
    ("utility", "BUFF"),
    ("stances", "BUFF"),
    ("racials", "BUFF"),
    ("hardCC", "DEBUFF"),
    ("ccRoot", "DEBUFF"),
    ("ccSnare", "DEBUFF"),
    ("racialDebuffs", "DEBUFF"),
)
CATEGORY_KEYS = tuple(key for key, _aura in SPELL_CATEGORIES)
AURA_TYPE = dict(SPELL_CATEGORIES)
CATEGORY_RANK = {key: index for index, key in enumerate(CATEGORY_KEYS)}

# The CC buckets come from research.derive by mechanic and are never name-mapped.
CC_KEYS = research.BUCKET_ORDER

# Pairs of categories an id may share. Only the Retail file's own: Racials (racialDebuffs) groups
# racial debuffs that also stay in the three CC categories (defaults/Categories.lua, its comment).
ALLOWED_OVERLAPS = frozenset(frozenset(("racialDebuffs", key)) for key in CC_KEYS)

# Never a Forever class key (spec §2: nine classes). A Retail entry under one of these is unmapped.
RETAIL_ONLY_CLASSES = frozenset(("DEATHKNIGHT", "MONK", "DEMONHUNTER", "EVOKER"))
CLASS_KEYS = research.FOREVER_CLASS_TOKENS | {"ALL"}
CLASS_ORDER = tuple(token for token in research.CLASS_EMIT_ORDER if token in CLASS_KEYS)

SOURCES = ("name-map", "db2-effect", "cc-mechanic", "bridge", "hand")
SOURCE_RANK = {source: index for index, source in enumerate(SOURCES)}

# The tables this tool reads beyond research.py's Forever set. Fetched into the bundle's raw/ on
# the first `derive` and replayed from there after; research.py's own table set is untouched.
EXTRA_TABLES = (
    ("Spell", "NameSubtext_lang: the 'Rank N' a vanilla rank carries, for the comment and the ruling"),
    ("SpellCooldowns", "RecoveryTime / CategoryRecoveryTime: the long-recast fence of DB2_RULES"),
    ("SpellMisc", "Attributes_0 bit 0x40 (SPELL_ATTR0_PASSIVE): a passive is flagged for the ruling"),
)
PASSIVE_ATTRIBUTE = 0x40

# SpellEffect.Effect values that put an aura on something (sid_db2's set: 6 APPLY_AURA, 35
# APPLY_AREA_AURA_PARTY, 119 APPLY_AREA_AURA_PET, 128 APPLY_AREA_AURA_FRIEND). Forever's paladin
# auras are 35 (Devotion Aura 465), so research.APPLY_AURA_EFFECT alone would miss them. The same
# set research.derive_cast_aura uses for Forever's cast table.
AURA_EFFECTS = research.FOREVER_AURA_EFFECTS

# SpellEffect.ImplicitTarget_0/_1 values (the client's Targets enum, TrinityCore's numbering),
# measured on 1.60.1.70938: Shield Wall 871 is 1, Renew 139 is 21, Power Word: Shield 17 is 57,
# Battle Shout 6673 and Arcane Brilliance 23028 are 56, War Stomp 20549 is 18 + 16.
SELF = frozenset({1})                   # UNIT_CASTER
ALLY = frozenset({21, 57})              # UNIT_TARGET_ALLY, UNIT_TARGET_PARTY (one member)
GROUP = frozenset({20, 33, 37, 56, 61})  # caster/src/last-target area party, caster area raid, raid class
ENEMY = frozenset({6, 15, 16, 24})      # UNIT_TARGET_ENEMY, src/dest area enemy, cone enemy
FRIENDLY = SELF | ALLY | GROUP
ANY_AURA = frozenset()

# A cooldown category's recast fence: a minute or more is a cooldown, under it is a rotation button.
LONG_RECAST_MS = 60000

# Generated files stay under the 1500-line cap with headroom (plan, Global Constraints).
FILE_LINE_CAP = 1400
SEEDS_TABLE = "NS.CategorySeedsForever"
CAST_TABLE = "NS.CastToAuraForever"
CAST_PATH = "defaults/CastToAura_Forever.lua"
SELECTOR = 'if NS.Compat.ClientKey() == "forever" then NS.CastToAura = NS.CastToAuraForever end'

RULINGS_PATH = HERE / "forever_rulings.json"
RULINGS = ("accept", "reject")
CANDIDATE_KEY = re.compile(r"^(?P<category>\w+):(?P<id>\d+)$")
RANK_TEXT = re.compile(r"^Rank \d+$")


@dataclass(frozen=True)
class EffectRule:
    """One aura effect a category's spell may carry. `auras` empty means any aura type; `sign` is
    what EffectBasePointsF must be (-1 negative, 0 any, +1 positive); `misc` limits
    EffectMiscValue_0 (the mechanic, for SPELL_AURA_MECHANIC_IMMUNITY 77)."""
    auras: frozenset
    sign: int
    targets: frozenset
    effects: frozenset = AURA_EFFECTS
    misc: frozenset | None = None

    def matches(self, row: "EffectRow") -> bool:
        if row.effect not in self.effects or not (row.targets & self.targets):
            return False
        if self.auras and row.aura not in self.auras:
            return False
        if self.misc is not None and row.misc not in self.misc:
            return False
        return self.sign == 0 or (row.points > 0 if self.sign > 0 else row.points < 0)


@dataclass(frozen=True)
class CategoryRule:
    """A category's DB2 candidate rule: any effect matching any EffectRule, within the recast
    window ("long" >= LONG_RECAST_MS, "short" under it, None either), over the class pool or the
    racial skill lines."""
    effects: tuple
    recast: str | None
    pool: str
    why: str

    def recast_ok(self, recast_ms: int) -> bool:
        if self.recast == "long":
            return recast_ms >= LONG_RECAST_MS
        if self.recast == "short":
            return recast_ms < LONG_RECAST_MS
        return True


def _rule(auras, sign, targets, **kw) -> EffectRule:
    return EffectRule(frozenset(auras), sign, frozenset(targets), **kw)


# THE DB2 CANDIDATE RULES, one per category. The aura ids are SpellEffect.EffectAura (the
# SPELL_AURA_* enum). Broad on purpose: a rule proposes, the ruling decides. The CC buckets have no
# rule here; they are research.derive's, by mechanic.
DB2_RULES = {
    # 87 MOD_DAMAGE_PERCENT_TAKEN below zero (Shield Wall 871: -60), 39/40 school or damage immunity
    # (Divine Shield 642, Ice Block 11958), 69 SCHOOL_ABSORB, 49 MOD_DODGE_PERCENT (Evasion 5277),
    # on yourself, on a recast of a minute or more.
    "defensives": CategoryRule((_rule({87}, -1, SELF), _rule({39, 40}, 0, SELF), _rule({69}, 0, SELF),
                                _rule({49}, 1, SELF)), "long", "class",
                               "damage taken down, immunity, absorb or dodge on yourself, recast >= 1 min"),
    # 51 MOD_BLOCK_PERCENT (Shield Block 2565), 47 MOD_PARRY_PERCENT, 49 dodge, on yourself, short.
    "activeMitigation": CategoryRule((_rule({51, 47, 49}, 1, SELF),), "short", "class",
                                     "block, parry or dodge up on yourself, recast under 1 min"),
    # Any aura on a raid or party area, on a long recast: the group-wide cooldowns.
    "raidCDs": CategoryRule((_rule(ANY_AURA, 0, GROUP),), "long", "class",
                            "an aura on a party or raid area, recast >= 1 min"),
    # 79 MOD_DAMAGE_PERCENT_DONE, 108 ADD_PCT_MODIFIER (Arcane Power 12042), 290/52 crit (Recklessness
    # 1719), 65/193 haste, 99 MOD_ATTACK_POWER, positive, on yourself, long recast.
    "offensiveCDs": CategoryRule((_rule({79, 108, 290, 52, 65, 193, 99}, 1, SELF),), "long", "class",
                                 "damage, crit, haste or attack power up on yourself, recast >= 1 min"),
    # 8 PERIODIC_HEAL (Renew 139) on anyone friendly; 69 absorb on another (Power Word: Shield 17).
    "healing": CategoryRule((_rule({8}, 0, FRIENDLY), _rule({69}, 0, ALLY | GROUP)), None, "class",
                            "a heal over time, or an absorb on another player"),
    # Any aura on one other player on a long recast (Power Infusion 10060, Innervate 29166).
    "support": CategoryRule((_rule(ANY_AURA, 0, ALLY),), "long", "class",
                            "an aura on one other player, recast >= 1 min"),
    # Any aura on a raid or party area on a short recast (Battle Shout 6673, Arcane Brilliance 23028).
    "groupBuffs": CategoryRule((_rule(ANY_AURA, 0, GROUP),), "short", "class",
                               "an aura on a party or raid area, recast under 1 min"),
    # 31 MOD_INCREASE_SPEED / 129 MOD_SPEED_ALWAYS positive (Sprint 2983), or 77 MECHANIC_IMMUNITY
    # to rooted (7) or snared (11) (Blessing of Freedom 1044).
    "movement": CategoryRule((_rule({31, 129}, 1, FRIENDLY), _rule({77}, 0, FRIENDLY, misc=frozenset({7, 11}))),
                             None, "class", "speed up, or immunity to roots and snares"),
    # 16 MOD_STEALTH, 18 MOD_INVISIBILITY, 66 FEIGN_DEATH, 82 WATER_BREATHING, 104 WATER_WALK,
    # 144 SAFE_FALL.
    "utility": CategoryRule((_rule({16, 18, 66, 82, 104, 144}, 0, FRIENDLY),), None, "class",
                            "stealth, invisibility, feign death, water breathing or walking, slow fall"),
    # 36 MOD_SHAPESHIFT on yourself (Battle Stance 2457, Cat Form 768), and an area party or raid
    # aura cast on yourself (effect 35: Devotion Aura 465; effect 65: Fire Resistance Aura 19891),
    # the paladin auras Retail's Stances also holds.
    "stances": CategoryRule((_rule({36}, 0, SELF), _rule(ANY_AURA, 0, SELF, effects=frozenset({35, 65}))),
                            None, "class", "a shapeshift or stance, or a paladin-style party aura"),
    # The racial skill lines ("Racial - Human", "Dwarven Racial"), split by who the aura lands on.
    "racials": CategoryRule((_rule(ANY_AURA, 0, FRIENDLY),), None, "racial",
                            "a racial skill line's aura on yourself or a friend"),
    "racialDebuffs": CategoryRule((_rule(ANY_AURA, 0, ENEMY),), None, "racial",
                                  "a racial skill line's aura on an enemy"),
}

# THE HAND CANDIDATES (AM-FP05): ids no source above can reach, each with the reason it is
# proposed. They are candidates like any other and still need a ruling; a hand entry that is not
# an aura on this build (no SpellName row, or no aura effect of its own) is listed with the
# unmapped entries instead, so a re-run on a later build shows what fell out. Each is a
# shape the DB2 tables cannot cross: an aura applied through a summoned object (the totems), an
# item or a weapon enchant (Soulstone, Frostbrand), a script (Cannibalize), a racial the
# class-only CC derivation never sees (War Stomp), or a category the rules above do not propose
# (Retail's own owner precedent, or the vanilla analogue of what a Retail list holds).
# (category, id, class key, why). Evidence for each: the bundle's ANALYSIS.md.
HAND_CANDIDATES = (
    # Blessing of Protection: an external like Blessing of Sacrifice 6940, which Retail's owner
    # put in Defensives "not in Support"; the support rule proposes it, so it is added here too.
    ("defensives", 1022, "PALADIN", "external immunity, Retail owner places externals in Defensives"),
    ("defensives", 5599, "PALADIN", "external immunity, Retail owner places externals in Defensives"),
    ("defensives", 10278, "PALADIN", "external immunity, Retail owner places externals in Defensives"),
    ("defensives", 22842, "DRUID", "bear 3 min self heal-over-time, aura 23 not in the defensives rule"),
    ("offensiveCDs", 3045, "HUNTER", "5 min ranged haste, aura 140 not in the offensive rule"),
    ("offensiveCDs", 13877, "ROGUE", "2 min melee haste talent, aura 319 not in the offensive rule"),
    ("offensiveCDs", 14177, "ROGUE", "3 min next-strike crit talent, aura 107 not in the offensive rule"),
    ("offensiveCDs", 12043, "MAGE", "3 min instant-cast talent, a negative 108 the rule skips"),
    ("offensiveCDs", 16166, "SHAMAN", "3 min Lightning Bolt cast-time cut, no Chain Lightning cooldown"),
    # The paladin blessings and the single-target priest buffs: the vanilla group buffs. Their
    # single-target ranks land on one ally (target 21) and the Greater ones on a class (153), which
    # the groupBuffs GROUP fence does not hold; Power Word: Fortitude reaches the list by name.
) + tuple(("groupBuffs", spell, "PALADIN", "paladin blessing, the vanilla group buff")
          for spell in (19740, 19834, 19835, 19836, 19837, 19838, 25291, 25782, 25916,
                        19742, 19850, 19852, 19853, 19854, 25290, 25894, 25918, 20217, 25898)) + tuple(
    ("groupBuffs", spell, "PRIEST", "single-target twin of an accepted Prayer buff")
    for spell in (976, 10957, 10958, 14752, 14818, 14819, 27841)) + tuple(
    ("utility", spell, "WARLOCK", "Soulstone aura (Retail lists 20707), cast by the soulstone item")
    for spell in (20707, 20762, 20763, 20764, 20765)) + (
    ("racials", 20578, "ALL", "Cannibalize's regen aura; the racial cast 20577 is a dummy effect"),
    ("hardCC", 20549, "ALL", "War Stomp: Retail ships it in hardCC under ALL as well as Racials"),
    ("ccSnare", 3600, "SHAMAN", "Earthbind, Earthbind Totem 2484's aura (Retail ships it by hand)"),
) + tuple(("ccSnare", spell, "SHAMAN", "Frostbrand Attack, the Frostbrand Weapon enchant's snare proc")
          for spell in (8034, 8037, 10458, 16352, 16353))

# Forever's racial lines are named both ways: "Racial - Human" and "Dwarven Racial".
RACIAL_PREFIX = sid_db2.RACIAL_LINE_PREFIX
RACIAL_SUFFIX = " Racial"


# ---------------------------------------------------------------------------
# The Forever data
# ---------------------------------------------------------------------------

class EffectRow(NamedTuple):
    effect: int
    aura: int
    points: float
    misc: int
    targets: frozenset


def _as_float(value: str | None) -> float:
    try:
        return float(value) if value else 0.0
    except ValueError:
        return 0.0


class ForeverDB:
    """Forever's DB2 facts this tool reads, each loaded once from `tables` ({table: path})."""

    def __init__(self, tables: dict[str, Path]):
        self.tables = tables
        self._cache: dict[str, object] = {}

    def _once(self, key: str, load):
        if key not in self._cache:
            self._cache[key] = load()
        return self._cache[key]

    @property
    def names(self) -> dict[int, str]:
        return self._once("names", lambda: research.read_names(self.tables["SpellName"]))

    @property
    def by_name(self) -> dict[str, list[int]]:
        def load():
            out: dict[str, list[int]] = defaultdict(list)
            for spell, name in self.names.items():
                if name:
                    out[name].append(spell)
            return out
        return self._once("by_name", load)

    def _effects(self) -> tuple[dict[int, list[EffectRow]], dict[int, set[int]]]:
        def load():
            rows: dict[int, list[EffectRow]] = defaultdict(list)
            triggers: dict[int, set[int]] = defaultdict(set)
            for row in research.iter_csv(self.tables["SpellEffect"]):
                spell = research.as_int(row.get("SpellID"))
                if not spell or not research.base_difficulty(row):
                    continue
                triggered = research.as_int(row.get("EffectTriggerSpell"))
                if triggered:
                    triggers[spell].add(triggered)
                effect = research.as_int(row.get("Effect"))
                if effect in AURA_EFFECTS:
                    targets = frozenset(t for t in (research.as_int(row.get("ImplicitTarget_0")),
                                                    research.as_int(row.get("ImplicitTarget_1"))) if t)
                    rows[spell].append(EffectRow(effect, research.as_int(row.get("EffectAura")),
                                                 _as_float(row.get("EffectBasePointsF")),
                                                 research.as_int(row.get("EffectMiscValue_0")), targets))
            return dict(rows), dict(triggers)
        return self._once("effects", load)

    @property
    def effects(self) -> dict[int, list[EffectRow]]:
        return self._effects()[0]

    @property
    def triggers(self) -> dict[int, set[int]]:
        return self._effects()[1]

    @property
    def appliers(self) -> set[int]:
        """Every spell with an aura effect of its own: the ids an aura can carry."""
        return self._once("appliers", lambda: set(self.effects))

    @property
    def subtexts(self) -> dict[int, str]:
        return self._once("subtexts", lambda: {
            research.as_int(r.get("ID")): (r.get("NameSubtext_lang") or "").strip()
            for r in research.iter_csv(self.tables["Spell"])})

    @property
    def recasts(self) -> dict[int, int]:
        def load():
            out: dict[int, int] = {}
            for row in research.iter_csv(self.tables["SpellCooldowns"]):
                spell = research.as_int(row.get("SpellID"))
                if spell and research.base_difficulty(row):
                    out[spell] = max(research.as_int(row.get("RecoveryTime")),
                                     research.as_int(row.get("CategoryRecoveryTime")))
            return out
        return self._once("recasts", load)

    @property
    def passives(self) -> set[int]:
        return self._once("passives", lambda: {
            research.as_int(r.get("SpellID")) for r in research.iter_csv(self.tables["SpellMisc"])
            if research.base_difficulty(r) and research.as_int(r.get("Attributes_0")) & PASSIVE_ATTRIBUTE})

    @property
    def racial(self) -> set[int]:
        """Every spell on a racial skill line, closed over EffectTriggerSpell."""
        def load():
            lines = set()
            for row in research.iter_csv(self.tables["SkillLine"]):
                name = (row.get("DisplayName_lang") or "").strip()
                if name.startswith(RACIAL_PREFIX) or name.endswith(RACIAL_SUFFIX):
                    lines.add(research.as_int(row.get("ID")))
            pool = {research.as_int(r.get("Spell")) for r in research.iter_csv(self.tables["SkillLineAbility"])
                    if research.as_int(r.get("SkillLine")) in lines} - {0}
            research.close_over_triggers(pool, defaultdict(set), self.triggers)
            return pool
        return self._once("racial", load)

    def rank(self, spell: int) -> str:
        """`Rank N` when Spell.NameSubtext_lang says so, else ''."""
        text = self.subtexts.get(spell, "")
        return text if RANK_TEXT.match(text) else ""

    def notes(self, spell: int) -> list[str]:
        return ["passive"] if spell in self.passives else []


def as_db(forever_tables) -> ForeverDB:
    return forever_tables if isinstance(forever_tables, ForeverDB) else ForeverDB(forever_tables)


def forever_pool(forever_tables) -> dict[int, set[str]]:
    """The Forever player pool `{spell: set(class tokens)}`: research.py's pool, closed over trigger
    edges and ranks to a fixed point (research.derive's steps 4 and the rank closure; the family
    bridge is CC-only and stays there)."""
    db = as_db(forever_tables)
    pool, classes = research.pool_for(db.tables, CLIENT)
    fence = research.load_forever_fence(db.tables)
    families = research.read_spell_families(db.tables["SpellClassOptions"])
    while True:
        grew = research.close_over_triggers(pool, classes, db.triggers)
        ranks = research.apply_rank_closure(pool, classes, db.names, families, fence)
        if not grew and not ranks:
            break
    return {spell: set(classes.get(spell, ())) & research.FOREVER_CLASS_TOKENS for spell in pool}


# ---------------------------------------------------------------------------
# Candidates
# ---------------------------------------------------------------------------

@dataclass
class Candidate:
    """One Forever id proposed for one category. `klass` is the emitted class key; `origin` the
    Retail id it was mapped from (name-map only); `via` the cast whose trigger edge landed it."""
    id: int
    category: str
    klass: str
    source: str
    origin: int | None
    name: str
    rank: str
    via: int | None = None
    notes: list = field(default_factory=list)

    @property
    def key(self) -> str:
        return "%s:%d" % (self.category, self.id)

    def to_json(self) -> dict:
        return {"key": self.key, "id": self.id, "category": self.category, "class": self.klass,
                "source": self.source, "origin": self.origin, "name": self.name, "rank": self.rank,
                "via": self.via, "notes": list(self.notes)}

    @classmethod
    def from_json(cls, data: dict) -> "Candidate":
        return cls(data["id"], data["category"], data["class"], data["source"], data.get("origin"),
                   data["name"], data.get("rank", ""), data.get("via"), list(data.get("notes", ())))


def sort_key(c: Candidate) -> tuple:
    return (CATEGORY_RANK.get(c.category, len(CATEGORY_RANK)), CLASS_ORDER.index(c.klass)
            if c.klass in CLASS_ORDER else len(CLASS_ORDER), c.name.lower(), c.id)


def _castable_by(spell: int, klass: str, pool: dict[int, set[str]], db: ForeverDB) -> bool:
    if klass == "ALL":
        return spell in pool or spell in db.racial
    return klass in pool.get(spell, ())


def _miss(key: str, klass: str, retail_id: int, name: str, why: str) -> dict:
    return {"category": key, "class": klass, "retail": retail_id, "name": name, "why": why}


def _map_one(db: ForeverDB, pool, key: str, klass: str, retail_id: int, name: str,
             unmapped: list) -> list[Candidate]:
    if klass in RETAIL_ONLY_CLASSES:
        unmapped.append(_miss(key, klass, retail_id, name, "a Retail-only class"))
        return []
    matches = [s for s in db.by_name.get(name, ()) if _castable_by(s, klass, pool, db)] if name else []
    if not matches:
        why = "no Forever spell of that name for the class" if name else "no name beside the Retail id"
        unmapped.append(_miss(key, klass, retail_id, name, why))
        return []
    out: list[Candidate] = []
    for spell in sorted(matches):
        auras = [spell] if spell in db.appliers else research.triggered_auras(spell, db.triggers, db.appliers)
        if not auras:
            unmapped.append(_miss(key, klass, retail_id, name,
                                  "Forever %d applies no aura and triggers none" % spell))
            continue
        for aura in auras:
            out.append(Candidate(aura, key, klass, "name-map", retail_id, db.names.get(aura, ""),
                                 db.rank(aura), None if aura == spell else spell, db.notes(aura)))
    return out


def map_retail_entries(retail_cats: list[dict], retail_names: dict[int, str], forever_tables,
                       pool: dict[int, set[str]], unmapped: list | None = None) -> list[Candidate]:
    """Each Retail entry of a non-CC `spells` category, mapped by name to the same class's Forever
    spells (every rank), resolved to the aura id through the trigger edge where the cast applies
    none. `retail_cats` is sid_db2.shipped_categories' shape; `retail_names` is {Retail id: name}.
    Entries that map to nothing are appended to `unmapped` with the reason."""
    db = as_db(forever_tables)
    unmapped = [] if unmapped is None else unmapped
    out: list[Candidate] = []
    seen: set[str] = set()
    for cat in retail_cats:
        key = cat["key"]
        if key not in AURA_TYPE:
            raise ValueError("Categories.lua has a spells category %r forever.py does not know; add it "
                             "to SPELL_CATEGORIES in its declared place" % key)
        if key in CC_KEYS:
            continue
        for klass, ids in cat["classes"].items():
            for retail_id in ids:
                for cand in _map_one(db, pool, key, klass, retail_id, retail_names.get(retail_id, ""), unmapped):
                    if cand.key not in seen:
                        seen.add(cand.key)
                        out.append(cand)
    return out


def db2_candidates(category_key: str, forever_tables, pool: dict[int, set[str]]) -> list[Candidate]:
    """The Forever spells whose own aura effects fit `category_key` (DB2_RULES), ascending by id."""
    rule = DB2_RULES.get(category_key)
    if rule is None:
        return []
    db = as_db(forever_tables)
    racial = rule.pool == "racial"
    out: list[Candidate] = []
    for spell in sorted(db.racial if racial else pool):
        name = db.names.get(spell, "")
        if not name or not rule.recast_ok(db.recasts.get(spell, 0)):
            continue
        if not any(r.matches(row) for row in db.effects.get(spell, ()) for r in rule.effects):
            continue
        klass = "ALL" if racial else research.emit_class_key(sorted(pool.get(spell, ())))
        out.append(Candidate(spell, category_key, klass, "db2-effect", None, name, db.rank(spell),
                             None, db.notes(spell)))
    return out


def cc_candidates(cc_result: dict, forever_tables) -> list[Candidate]:
    """research.derive's three buckets as candidates: `cc-mechanic`, or `bridge` when family-bridged."""
    db = as_db(forever_tables)
    out: list[Candidate] = []
    for bucket in CC_KEYS:
        for spell, entry in sorted(cc_result["buckets"][bucket].items(), key=lambda kv: int(kv[0])):
            notes = ["rank closure"] if entry["source"] == "rank" else []
            notes.append("mechanic " + ", ".join(m["name"] for m in entry["mechanics"]))
            out.append(Candidate(int(spell), bucket, entry["class"],
                                 "bridge" if entry["source"] == "bridge" else "cc-mechanic", None,
                                 entry["name"], db.rank(int(spell)), None, notes + db.notes(int(spell))))
    return out


def hand_candidates(forever_tables, unmapped: list, entries=HAND_CANDIDATES) -> list[Candidate]:
    """HAND_CANDIDATES as `hand` candidates. An unknown category or a non-Forever class key is an
    authoring error (SystemExit); an id that is not an aura on this build joins `unmapped`."""
    db = as_db(forever_tables)
    out: list[Candidate] = []
    for category, spell, klass, why in entries:
        if category not in AURA_TYPE or klass not in CLASS_KEYS:
            raise SystemExit("hand candidate %s:%d [%s] has an unknown category or class" % (category, spell, klass))
        name = db.names.get(spell, "")
        if not name or spell not in db.appliers:
            unmapped.append(_miss(category, klass, spell, name, "hand id %d is not an aura on this build" % spell))
            continue
        out.append(Candidate(spell, category, klass, "hand", None, name, db.rank(spell), None,
                             db.notes(spell) + ["hand: " + why]))
    return out


def annotate_overlaps(candidates: list[Candidate]) -> None:
    """Note on each candidate the other categories of its aura type that also propose its id."""
    where: dict[tuple[str, int], list[str]] = defaultdict(list)
    for c in candidates:
        where[(AURA_TYPE[c.category], c.id)].append(c.category)
    for c in candidates:
        others = sorted(set(where[(AURA_TYPE[c.category], c.id)]) - {c.category}, key=CATEGORY_RANK.get)
        if others:
            c.notes.append("also proposed for " + ", ".join(others))


def gather_candidates(db: ForeverDB, retail_cats: list[dict], retail_names: dict[int, str],
                      cc_result: dict, unmapped: list) -> list[Candidate]:
    """Every candidate, one per (category, id): CC first, then name-map, then db2-effect, then hand."""
    pool = forever_pool(db)
    merged: dict[str, Candidate] = {}
    found = cc_candidates(cc_result, db) + map_retail_entries(retail_cats, retail_names, db, pool, unmapped)
    for key in CATEGORY_KEYS:
        found += db2_candidates(key, db, pool)
    found += hand_candidates(db, unmapped)
    for cand in found:
        held = merged.get(cand.key)
        if held is None:
            merged[cand.key] = cand
        elif cand.source not in held.notes and cand.source != held.source:
            held.notes.append("also " + cand.source)
    out = sorted(merged.values(), key=sort_key)
    annotate_overlaps(out)
    return out


# ---------------------------------------------------------------------------
# Rulings
# ---------------------------------------------------------------------------

def load_rulings(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def save_rulings(path: Path, rulings: dict) -> None:
    research.write_repo_text(path, json.dumps(rulings, indent=2, sort_keys=True, ensure_ascii=False) + "\n")


def set_ruling(rulings: dict, key: str, ruling: str, reason: str) -> None:
    """Record one ruling; a malformed key, ruling or reason is a SystemExit naming it."""
    match = CANDIDATE_KEY.match(key)
    if not match or match.group("category") not in AURA_TYPE:
        raise SystemExit("--key %r is not <category>:<id> with a known category." % key)
    if ruling not in RULINGS:
        raise SystemExit("--ruling must be accept or reject; got %r." % ruling)
    reason = (reason or "").strip()
    if not reason or "\n" in reason:
        raise SystemExit("--reason for %s must be one non-empty line." % key)
    rulings[key] = {"ruling": ruling, "reason": reason}


def split_by_ruling(candidates: list[Candidate], rulings: dict) -> tuple[list, list, list]:
    """`(accepted, unruled, stale ruling keys)`; stale = ruled keys no candidate carries."""
    keys = {c.key for c in candidates}
    accepted = [c for c in candidates if rulings.get(c.key, {}).get("ruling") == "accept"]
    unruled = [c for c in candidates if c.key not in rulings]
    stale = sorted(k for k in rulings if k not in keys)
    return accepted, unruled, stale


def resolve_precedence(accepted: list[Candidate]) -> tuple[list[Candidate], list[dict]]:
    """One category per id within an aura type: the first in SPELL_CATEGORIES order keeps it.
    Returns `(kept, conflicts)`; ALLOWED_OVERLAPS pairs are not conflicts."""
    held: dict[tuple[str, int], list[str]] = defaultdict(list)
    kept: list[Candidate] = []
    conflicts: list[dict] = []
    for cand in sorted(accepted, key=sort_key):
        slot = (AURA_TYPE[cand.category], cand.id)
        blocking = [k for k in held[slot] if frozenset((k, cand.category)) not in ALLOWED_OVERLAPS]
        if blocking:
            conflicts.append({"id": cand.id, "name": cand.name, "kept": blocking[0], "dropped": cand.category})
            continue
        held[slot].append(cand.category)
        kept.append(cand)
    return kept, conflicts


def empty_keys_for(kept: list[Candidate]) -> list[str]:
    have = {c.category for c in kept}
    return [key for key in CATEGORY_KEYS if key not in have]


# ---------------------------------------------------------------------------
# Emitters
# ---------------------------------------------------------------------------

def _comment(c: Candidate) -> str:
    text = c.name + (" (%s)" % c.rank if c.rank else "") + "; " + c.source
    if c.origin:
        text += " of Retail %d" % c.origin
    if c.via:
        text += ", the aura cast %d lands" % c.via
    return text


def _category_lines(key: str, cands: list[Candidate]) -> list[str]:
    by_class: dict[str, list[Candidate]] = defaultdict(list)
    for c in cands:
        by_class[c.klass].append(c)
    count = "%d id%s" % (len(cands), "" if len(cands) == 1 else "s")
    out = ["-- %s (%s): %s" % (key, AURA_TYPE[key], count), "%s.%s = {" % (SEEDS_TABLE, key)]
    for klass in CLASS_ORDER:
        rows = sorted(by_class.get(klass, ()), key=lambda c: (c.name.lower(), c.id))
        if not rows:
            continue
        width = max(len(str(c.id)) + 1 for c in rows)
        out.append("    %s = {" % klass)
        out += ["        %s -- %s" % (("%d," % c.id).ljust(width), _comment(c)) for c in rows]
        out.append("    },")
    out += ["}", ""]
    return out


def _empty_lines(empty_keys: list[str]) -> list[str]:
    out = ["-- The `spells` categories with nothing on WoW Forever. AM-FP06's gate reads this one fact:",
           "-- a key here does not exist on Forever (clients-§4), and a re-run that fills it ungates it.",
           "%s.EMPTY = {" % SEEDS_TABLE]
    out += ["    %s = true," % key for key in empty_keys]
    return out + ["}", ""]


def _header(path: str, part: int, parts: int, build: str, date: str, bundle: str) -> list[str]:
    return [
        "local _, NS = ...",
        "",
        "-- %s -- GENERATED. Do not edit by hand. Part %d of %d." % (path, part, parts),
        "--",
        "--   Build %s (WoW Forever), derived %s by tools/spell-research/forever.py emit." % (build, date),
        "--   Provenance: %s (candidates.json, RULINGS.md); every id's ruling and" % bundle,
        "--   its reason is in tools/spell-research/forever_rulings.json. Re-run forever.py to refresh it.",
        "--",
        "-- WHAT THIS IS. WoW Forever's seed lists for the `spells` categories, by category key and class:",
        "-- %s[key] = { CLASS = { id, ... } }. defaults/Categories.lua picks these on" % SEEDS_TABLE,
        "-- Forever and its own inline lists on Retail, once at load (clients-§5); this file never touches",
        "-- NS.Categories. The ids are AURA ids, and every rank of a spell ships: a filter matches one id.",
        "",
        "%s = %s or {}" % (SEEDS_TABLE, SEEDS_TABLE),
        "",
    ]


def seeds_path(part: int) -> str:
    return "defaults/Categories_Forever.lua" if part == 1 else "defaults/Categories_Forever_%d.lua" % part


def emit_categories_forever(accepted: list[Candidate], empty_keys: list[str], build: str, date: str,
                            bundle: str = "docs/spell-research/", cap: int = FILE_LINE_CAP) -> list[tuple[str, str]]:
    """`[(repo path, CRLF text)]` for defaults/Categories_Forever*.lua: NS.CategorySeedsForever and
    its EMPTY set, split at category boundaries so that no file exceeds `cap` lines.

    `accepted` must already be precedence-resolved (resolve_precedence): a (category, id) twice, an
    id in two categories of one aura type outside ALLOWED_OVERLAPS, a Retail-only class, or a key
    both accepted and empty is a ValueError, never a file."""
    by_key: dict[str, list[Candidate]] = defaultdict(list)
    _check_emit(accepted, empty_keys)
    for c in accepted:
        by_key[c.category].append(c)
    blocks = [_empty_lines([k for k in CATEGORY_KEYS if k in set(empty_keys)])]
    blocks += [_category_lines(key, by_key[key]) for key in CATEGORY_KEYS if by_key.get(key)]
    head = len(_header("", 1, 1, build, date, bundle))
    files: list[list[str]] = [[]]
    for block in blocks:
        if head + len(block) > cap:
            raise ValueError("one category needs %d lines, over the %d-line cap" % (head + len(block), cap))
        if files[-1] and head + len(files[-1]) + len(block) > cap:
            files.append([])
        files[-1] += block
    parts = len(files)
    return [(seeds_path(n), research.NEWLINE.join(_header(seeds_path(n), n, parts, build, date, bundle)
                                                  + body) + research.NEWLINE)
            for n, body in enumerate((b[:-1] if b and b[-1] == "" else b for b in files), start=1)]


def _check_emit(accepted: list[Candidate], empty_keys: list[str]) -> None:
    seen: set[str] = set()
    slots: dict[tuple[str, int], list[str]] = defaultdict(list)
    for c in accepted:
        if c.key in seen:
            raise ValueError("%s is accepted twice" % c.key)
        if c.klass not in CLASS_KEYS:
            raise ValueError("%s has class key %r, which is not a Forever class" % (c.key, c.klass))
        if c.category in empty_keys:
            raise ValueError("%s is accepted but its category is listed empty" % c.key)
        seen.add(c.key)
        slot = (AURA_TYPE[c.category], c.id)
        for other in slots[slot]:
            if frozenset((other, c.category)) not in ALLOWED_OVERLAPS:
                raise ValueError("%d is in both %s and %s; resolve_precedence first" % (c.id, other, c.category))
        slots[slot].append(c.category)


def emit_cast_to_aura_forever(result: dict, build: str, date: str) -> str:
    """defaults/CastToAura_Forever.lua: research.derive_cast_aura's Forever table in Retail's
    REWRITE/CHOICES shape, published as NS.CastToAuraForever, then the one-time client selector."""
    entries = {int(spell): entry for spell, entry in result["entries"].items()}
    text = research.format_cast_aura_lua(dict(result, entries=entries), build + " (WoW Forever)", date,
                                         table=CAST_TABLE, path=CAST_PATH,
                                         how="tools/spell-research/forever.py emit")
    tail = [
        "",
        "-- THE CLIENT SELECTOR. defaults/CastToAura.lua publishes Retail's table as NS.CastToAura; on",
        "-- WoW Forever this file's table replaces it, once, at load (clients-§5). NS.Compat loads before",
        "-- defaults/ in the TOC, and modules/CastAura.lua reads NS.CastToAura without asking the client.",
        SELECTOR,
    ]
    return text + research.NEWLINE.join(tail) + research.NEWLINE


def _ruling_rows(rows: list[Candidate], rulings: dict) -> list[str]:
    out = ["| Id | Name | Rank | Class | Source | Origin | Ruling | Reason |",
           "| --- | --- | --- | --- | --- | --- | --- | --- |"]
    for c in rows:
        r = rulings.get(c.key, {})
        source = c.source + (" via %d" % c.via if c.via else "")
        out.append("| %d | %s | %s | %s | %s | %s | %s | %s |" % (
            c.id, c.name.replace("|", "/"), c.rank, c.klass, source, c.origin or "",
            r.get("ruling", "UNRULED"), r.get("reason", "").replace("|", "/")))
    return out + [""]


def format_rulings_md(candidates: list[Candidate], rulings: dict, conflicts: list[dict],
                      unmapped: list[dict], stale: list[str], build: str, date: str) -> str:
    """The bundle's RULINGS.md: every candidate with its ruling and reason, per category."""
    out = ["# Rulings — WoW Forever seed lists, %s" % date, "",
           "Written by `tools/spell-research/forever.py emit` from `candidates.json` (build `%s`) and" % build,
           "`tools/spell-research/forever_rulings.json`. Regenerated on every emit; never edited by hand.", ""]
    for key in CATEGORY_KEYS:
        rows = [c for c in candidates if c.category == key]
        accepted = sum(1 for c in rows if rulings.get(c.key, {}).get("ruling") == "accept")
        out += ["## `%s` (%s): %d candidates, %d accepted" % (key, AURA_TYPE[key], len(rows), accepted), ""]
        out += _ruling_rows(rows, rulings) if rows else ["No candidate.", ""]
    out += ["## Precedence conflicts", ""]
    out += ["- %d %s: kept in `%s`, dropped from `%s`" % (x["id"], x["name"], x["kept"], x["dropped"])
            for x in conflicts] or ["None."]
    out += ["", "## Retail entries with no Forever candidate", ""]
    out += ["- `%s` %s %s %s: %s" % (m["category"], m["class"], m["retail"], m["name"], m["why"])
            for m in unmapped] or ["None."]
    out += ["", "## Stale rulings (no such candidate this run)", ""]
    out += ["- `%s`" % key for key in stale] or ["None."]
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------------------
# The bundle and the CLI
# ---------------------------------------------------------------------------

def read_retail(categories_lua: Path) -> tuple[list[dict], dict[int, str]]:
    """Retail's spells categories (sid_db2.shipped_categories) and {id: the name beside it}."""
    cats = sid_db2.shipped_categories(categories_lua)
    names: dict[int, str] = {}
    for cat in research.read_spells_categories(categories_lua.read_text(encoding="utf-8")):
        for rec in cat["records"]:
            if rec["comment"] and rec["id"] not in names:
                names[rec["id"]] = rec["comment"]
    return cats, names


def bundle_tables(bundle: Path, replay: bool, cache_dir: Path) -> tuple[dict[str, Path], str]:
    """`({table: raw path}, build)`: research.py's Forever tables from the bundle, plus EXTRA_TABLES,
    fetched once into raw/ unless `replay`, where a missing one is fatal."""
    if not (bundle / "derived.json").exists():
        raise SystemExit("%s has no derived.json: run research.py --client forever --bundle %s first."
                         % (bundle, bundle))
    research.check_replay_client(bundle, CLIENT)
    build, _fetched = research.replay_provenance(bundle, None)
    tables = {t: research.fetch_table(t, build, cache_dir, False, bundle) for t, _w in research.tables_for(CLIENT)}
    for table, _why in EXTRA_TABLES:
        member = bundle / "raw" / ("%s.csv.gz" % table)
        if not member.exists():
            if replay:
                raise SystemExit("--replay: %s is missing raw/%s.csv.gz; run derive once without --replay."
                                 % (bundle, table))
            source = research.fetch_table(table, build, cache_dir, False)
            with source.open("rb") as src, gzip.open(member, "wb", compresslevel=9) as dst:
                shutil.copyfileobj(src, dst, research.DOWNLOAD_CHUNK)
        tables[table] = member
    return tables, build


def derive_bundle(tables: dict[str, Path], build: str, date: str, categories_lua: Path) -> dict:
    """The whole derivation, as candidates.json's document."""
    db = ForeverDB(tables)
    cc_result = research.derive(tables, CLIENT)
    missing = research.check_sentinels(cc_result, research.SENTINELS_FOREVER)
    if missing:
        raise SystemExit("Forever coverage gate FAILED: %s. Fix the pool before ruling anything."
                         % "; ".join(missing))
    retail_cats, retail_names = read_retail(categories_lua)
    unmapped: list[dict] = []
    candidates = gather_candidates(db, retail_cats, retail_names, cc_result, unmapped)
    cast = research.derive_cast_aura(tables, CLIENT)
    counts = {key: sum(1 for c in candidates if c.category == key) for key in CATEGORY_KEYS}
    return {
        "client": CLIENT, "build": build, "date": date, "tool": "tools/spell-research/forever.py derive",
        "counts": counts,
        "candidates": [c.to_json() for c in candidates],
        "unmapped": unmapped,
        "castToAura": {"entries": {str(k): v for k, v in sorted(cast["entries"].items())},
                       "pool": cast["pool"], "appliers": cast["appliers"],
                       "dead_no_candidate": cast["dead_no_candidate"]},
    }


def write_json(path: Path, doc: dict) -> None:
    research.write_repo_text(path, json.dumps(doc, indent=1, sort_keys=True, ensure_ascii=False) + "\n")


def load_candidates(bundle: Path) -> dict:
    path = bundle / "candidates.json"
    if not path.exists():
        raise SystemExit("%s has no candidates.json: run forever.py derive first." % bundle)
    return json.loads(path.read_text(encoding="utf-8"))


def cmd_derive(args) -> int:
    tables, build = bundle_tables(args.bundle, args.replay, args.cache_dir)
    doc = derive_bundle(tables, build, args.date, args.categories)
    write_json(args.bundle / "candidates.json", doc)
    candidates = [Candidate.from_json(c) for c in doc["candidates"]]
    _accepted, unruled, stale = split_by_ruling(candidates, load_rulings(args.rulings))
    for key in CATEGORY_KEYS:
        research.log("  %-17s %d candidates" % (key, doc["counts"][key]))
    research.log("%d candidates, %d unruled, %d stale rulings; %d Retail entries unmapped"
                 % (len(candidates), len(unruled), len(stale), len(doc["unmapped"])))
    return 0


def write_emitted(out_root: Path, files: list[tuple[str, str]]) -> None:
    """Write the emitted files under `out_root` and delete numbered parts a smaller emit no longer has."""
    for rel, text in files:
        target = out_root / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(text.encode("utf-8"))
    parts = len([rel for rel, _t in files if rel.startswith("defaults/Categories_Forever")])
    for stale in (out_root / "defaults").glob("Categories_Forever_*.lua"):
        number = re.match(r"^Categories_Forever_(\d+)\.lua$", stale.name)
        if number and int(number.group(1)) > parts:
            stale.unlink()


def cmd_emit(args) -> int:
    doc = load_candidates(args.bundle)
    candidates = [Candidate.from_json(c) for c in doc["candidates"]]
    rulings = load_rulings(args.rulings)
    accepted, unruled, stale = split_by_ruling(candidates, rulings)
    if unruled:
        research.log("emit refused: %d candidate(s) are unruled. Rule each with forever.py rule:" % len(unruled))
        for c in unruled:
            research.log("  %s  %s %s [%s, %s]" % (c.key, c.name, c.rank, c.klass, c.source))
        return 1
    for key in stale:
        research.log("  WARNING: stale ruling %s (no such candidate this run)" % key)
    kept, conflicts = resolve_precedence(accepted)
    empty = empty_keys_for(kept)
    try:
        bundle_rel = args.bundle.resolve().relative_to(research.repo_root()).as_posix()
    except ValueError:
        bundle_rel = args.bundle.as_posix()
    files = emit_categories_forever(kept, empty, doc["build"], args.date, bundle_rel + "/")
    files.append((CAST_PATH, emit_cast_to_aura_forever(doc["castToAura"], doc["build"], args.date)))
    write_emitted(args.out_root, files)
    research.write_repo_text(args.bundle / "RULINGS.md", format_rulings_md(
        candidates, rulings, conflicts, doc["unmapped"], stale, doc["build"], args.date))
    research.log("Emitted %d files: %d ids kept, %d conflicts dropped, empty: %s"
                 % (len(files), len(kept), len(conflicts), ", ".join(empty) or "none"))
    return 0


def read_tsv(path: Path) -> list[tuple[str, str, str]]:
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) != 3:
            raise SystemExit("%s: a ruling line is key<TAB>ruling<TAB>reason; got %r" % (path, line))
        out.append((parts[0].strip(), parts[1].strip(), parts[2].strip()))
    return out


def cmd_rule(args) -> int:
    todo = [(key, args.ruling, args.reason) for key in (args.key or ())]
    if args.tsv:
        todo += read_tsv(args.tsv)
    if not todo:
        raise SystemExit("rule needs --key (with --ruling and --reason) or --tsv.")
    known = None
    if args.bundle:
        known = {c["key"] for c in load_candidates(args.bundle)["candidates"]}
    rulings = load_rulings(args.rulings)
    for key, ruling, reason in todo:
        if known is not None and key not in known:
            raise SystemExit("%s is not a candidate in %s/candidates.json." % (key, args.bundle))
        set_ruling(rulings, key, ruling, reason)
    save_rulings(args.rulings, rulings)
    research.log("Recorded %d ruling(s) in %s" % (len(todo), args.rulings))
    return 0


def _date(value: str) -> str:
    if not research.DATE_RE.match(value):
        raise argparse.ArgumentTypeError("--date must be YYYY-MM-DD; got %r" % value)
    return value


def parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(prog="forever.py", description=__doc__.split("\n\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)
    derive = sub.add_parser("derive", help="write the bundle's candidates.json")
    emit = sub.add_parser("emit", help="write defaults/Categories_Forever*.lua and CastToAura_Forever.lua")
    for p in (derive, emit):
        p.add_argument("--bundle", type=Path, required=True, help="a research.py --client forever bundle")
        p.add_argument("--date", type=_date, required=True, help="the run's date, YYYY-MM-DD (never the clock)")
        p.add_argument("--rulings", type=Path, default=RULINGS_PATH)
    derive.add_argument("--replay", action="store_true", help="offline: every table must be in raw/")
    derive.add_argument("--categories", type=Path, default=research.repo_root() / "defaults" / "Categories.lua",
                        help="the Retail Categories.lua whose entries are mapped by name (read-only)")
    derive.add_argument("--cache-dir", type=Path, default=HERE / ".cache")
    emit.add_argument("--out-root", type=Path, default=research.repo_root(),
                      help="the tree the defaults/ files are written under")
    rule = sub.add_parser("rule", help="record accept/reject rulings (the only writer of the rulings file)")
    rule.add_argument("--key", action="append", help="<category>:<id>; repeat for several")
    rule.add_argument("--ruling", choices=RULINGS)
    rule.add_argument("--reason")
    rule.add_argument("--tsv", type=Path, help="key<TAB>ruling<TAB>reason per line")
    rule.add_argument("--bundle", type=Path, help="check each key against this bundle's candidates.json")
    rule.add_argument("--rulings", type=Path, default=RULINGS_PATH)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    return {"derive": cmd_derive, "emit": cmd_emit, "rule": cmd_rule}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
