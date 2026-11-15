#!/usr/bin/env python3
"""tools/spell-research/sid_seeds.py — the client-neutral half of the seed tools (issue #27).

forever.py (WoW Forever's generated lists) and retail.py (the Retail re-validation) share the same
machinery, and it lives here so the two cannot drift: the `spells` categories and their aura types,
the DB2 candidate rules (DB2_RULES) and the reader they run over (SeedDB), the Candidate record,
and rulings as data (load_rulings / save_rulings / split_by_ruling / read_tsv). Each tool keeps
its own rulings file, its own sources and its own writer. Moved out of forever.py unchanged apart
from the class name (ForeverDB, which forever.py still exports) and db2_candidates' parameter.

Python 3 and its standard library only, like research.py.
"""

from __future__ import annotations

import json
import re
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


# Forever's racial lines are named both ways: "Racial - Human" and "Dwarven Racial".
RACIAL_PREFIX = sid_db2.RACIAL_LINE_PREFIX


RACIAL_SUFFIX = " Racial"


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


class SeedDB:
    """One build's DB2 facts the seed tools read, each loaded once from `tables` ({table: path}).
    Client-neutral: forever.py and retail.py both build one."""

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


@dataclass
class Candidate:
    """One id proposed for one category. `klass` is the emitted class key; `origin` the
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


def db2_candidates(category_key: str, tables, pool: dict[int, set[str]]) -> list[Candidate]:
    """The pool spells whose own aura effects fit `category_key` (DB2_RULES), ascending by id.
    `tables` is a SeedDB or its {table: path}."""
    rule = DB2_RULES.get(category_key)
    if rule is None:
        return []
    db = tables if isinstance(tables, SeedDB) else SeedDB(tables)
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


def load_rulings(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def save_rulings(path: Path, rulings: dict) -> None:
    research.write_repo_text(path, json.dumps(rulings, indent=2, sort_keys=True, ensure_ascii=False) + "\n")


def split_by_ruling(candidates: list[Candidate], rulings: dict) -> tuple[list, list, list]:
    """`(accepted, unruled, stale ruling keys)`; stale = ruled keys no candidate carries."""
    keys = {c.key for c in candidates}
    accepted = [c for c in candidates if rulings.get(c.key, {}).get("ruling") == "accept"]
    unruled = [c for c in candidates if c.key not in rulings]
    stale = sorted(k for k in rulings if k not in keys)
    return accepted, unruled, stale


def write_json(path: Path, doc: dict) -> None:
    research.write_repo_text(path, json.dumps(doc, indent=1, sort_keys=True, ensure_ascii=False) + "\n")


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
