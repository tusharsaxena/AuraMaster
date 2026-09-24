"""DB2 signals and shipped-category readers for the combat-log spell research.

What the logs cannot say, the client's own tables can: which class and spec a specialization id
is, what an aura DOES (reduces damage taken, absorbs, raises haste, ...), which spells a player can
cast at all, and which aura ids share one cast. This module reads those facts through research.py's
cached DB2 exports and readers (it never changes research.py), plus the two shipped Lua files the
proposals are checked against: defaults/Categories.lua and defaults/CastToAura.lua.

Everything here is a pure read. Python 3.8+ standard library only.
"""

import re
from collections import defaultdict
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Set, Tuple

import research

# --- effect aura types -> signals ---------------------------------------------------------------

# SpellEffect.Effect values that put an aura on something: 6 SPELL_EFFECT_APPLY_AURA, and the area
# auras 35 APPLY_AREA_AURA_PARTY, 119 APPLY_AREA_AURA_PET, 128 APPLY_AREA_AURA_FRIEND. Any other
# effect (DUMMY, SCHOOL_DAMAGE, TRIGGER_SPELL, ...) carries an EffectAura column that means nothing.
APPLY_AURA_EFFECTS = frozenset({research.APPLY_AURA_EFFECT, 35, 119, 128})

# SpellEffect.EffectAura -> (signal, sign). The keys are the client's AuraType enum (the
# SPELL_AURA_* constants, as numbered in TrinityCore's SpellAuraDefines.h and wago.tools'
# AuraType); `sign` is what EffectBasePointsF must be for the aura to be the signal:
# -1 negative, +1 positive, 0 any value.
AURA_SIGNALS = {
    8: ("periodic_heal", 0),          # SPELL_AURA_PERIODIC_HEAL
    31: ("speed_up", 1),              # SPELL_AURA_MOD_INCREASE_SPEED (a snare is 33, not this)
    39: ("immunity", 0),              # SPELL_AURA_SCHOOL_IMMUNITY (Divine Shield 642, Ice Block)
    40: ("immunity", 0),              # SPELL_AURA_DAMAGE_IMMUNITY
    52: ("crit_up", 1),               # SPELL_AURA_MOD_CRIT_PERCENT
    56: ("transform", 0),             # SPELL_AURA_TRANSFORM
    65: ("haste_up", 1),              # SPELL_AURA_MOD_CASTING_SPEED_NOT_STACK
    69: ("absorb", 0),                # SPELL_AURA_SCHOOL_ABSORB
    79: ("damage_up", 1),             # SPELL_AURA_MOD_DAMAGE_PERCENT_DONE
    87: ("damage_taken_down", -1),    # SPELL_AURA_MOD_DAMAGE_PERCENT_TAKEN (Astral Shift: -40)
    129: ("speed_up", 1),             # SPELL_AURA_MOD_SPEED_ALWAYS
    # Both speed rows need positive points: Blessing of Protection 1022, Sacrifice 6940 and Freedom
    # 1044 carry a 31 row at 0 (a talent fills it in), which is no speed increase (SID-10).
    137: ("stat_pct_up", 1),          # SPELL_AURA_MOD_TOTAL_STAT_PERCENTAGE
    189: ("rating_up", 1),            # SPELL_AURA_MOD_RATING (crit/haste/mastery/versatility)
    193: ("haste_up", 1),             # SPELL_AURA_MELEE_SLOW, all haste (Bloodlust: +30)
    290: ("crit_up", 1),              # SPELL_AURA_MOD_CRIT_PCT
}

# Spell modifiers: (EffectAura, EffectMiscValue_0 = SpellModOp) -> signal, positive values only.
# 107 SPELL_AURA_ADD_FLAT_MODIFIER on SpellModOp 7 (CritChance) is how Recklessness (1719) grants
# "+20% critical strike chance to your abilities"; without it the spell carries no R3 signal at all.
SPELL_MOD_SIGNALS = {
    (107, 7): "crit_up",
}

_SIGN_OK = {
    -1: lambda v: v < 0,
    0: lambda v: True,
    1: lambda v: v > 0,
}


def _as_float(value: Optional[str]) -> float:
    """EffectBasePointsF is a float column ("-40", "0.5"); research.as_int would truncate 0.5."""
    try:
        return float(value) if value else 0.0
    except ValueError:
        return 0.0


def _row_signal(row: dict) -> Optional[str]:
    aura = research.as_int(row.get("EffectAura"))
    points = _as_float(row.get("EffectBasePointsF"))
    mod = SPELL_MOD_SIGNALS.get((aura, research.as_int(row.get("EffectMiscValue_0"))))
    if mod:
        return mod if points > 0 else None
    entry = AURA_SIGNALS.get(aura)
    if entry and _SIGN_OK[entry[1]](points):
        return entry[0]
    return None


def aura_signals(spell_effect_csv: Path, spell_ids: Iterable[int]) -> Dict[int, Set[str]]:
    """The signal names each requested spell carries, from its base-difficulty aura effects.

    Every requested id is in the result (an empty set when it carries none). Streams SpellEffect
    (~57 MB) one row at a time through research.iter_csv.
    """
    wanted = set(spell_ids)
    out: Dict[int, Set[str]] = {spell: set() for spell in wanted}
    for row in research.iter_csv(spell_effect_csv):
        spell = research.as_int(row.get("SpellID"))
        if spell not in wanted or not research.base_difficulty(row):
            continue
        if research.as_int(row.get("Effect")) not in APPLY_AURA_EFFECTS:
            continue
        signal = _row_signal(row)
        if signal:
            out[spell].add(signal)
    return out


def cc_spell_ids(spell_effect_csv: Path, spell_categories_csv: Path,
                 spell_ids: Iterable[int]) -> Set[int]:
    """The requested spells DB2 gives a crowd-control mechanic, for the cc_unlisted cross-check.

    research.py's own method: the base-difficulty mechanic at the effect level
    (SpellEffect.EffectMechanic) or the spell level (SpellCategories.Mechanic), matched against
    every mechanic in research.BUCKET_MECHANICS (hard and soft CC alike).
    """
    wanted = set(spell_ids)
    cc = set()  # type: Set[int]
    for mapping in research.BUCKET_MECHANICS.values():
        cc |= set(mapping)
    out: Set[int] = set()
    for path, column in ((spell_effect_csv, "EffectMechanic"), (spell_categories_csv, "Mechanic")):
        for row in research.iter_csv(path):
            spell = research.as_int(row.get("SpellID"))
            if (spell in wanted and research.base_difficulty(row)
                    and research.as_int(row.get(column)) in cc):
                out.add(spell)
    return out


# --- specs, names, player pool --------------------------------------------------------------------

def load_spec_map(chr_spec_csv: Path) -> Dict[int, dict]:
    """ChrSpecialization: {spec_id: {"class": token, "name": Name_lang, "role": Role}}.

    Role is the client's: 0 tank, 1 healer, 2 damage (verified against build 12.1.0.69875:
    Protection Warrior 0, Restoration Shaman 1, Elemental Shaman 2).
    """
    out: Dict[int, dict] = {}
    for row in research.iter_csv(chr_spec_csv):
        spec = research.as_int(row.get("ID"))
        if not spec:
            continue
        out[spec] = {
            "class": research.CLASS_BY_CLASS_ID.get(research.as_int(row.get("ClassID"))),
            "name": (row.get("Name_lang") or "").strip(),
            "role": research.as_int(row.get("Role")),
        }
    return out


def names(spell_name_csv: Path) -> Dict[int, str]:
    """SpellName: {spell_id: name}."""
    return research.read_names(spell_name_csv)


def castable(cache: Dict[str, Path]) -> Tuple[Set[int], Dict[str, Set[str]]]:
    """(ids, names by class): what rule R8 counts as a class spell rather than an item effect.

    ids: research.build_pool's pool (the spells a player can learn), closed over
    SpellEffect.EffectTriggerSpell with research.close_over_triggers (the aura a class spell
    triggers, e.g. Dancing Rune Weapon 49028 -> 81256), plus every spell with a non-zero
    SpellClassOptions.SpellClassSet (a class spell family: procs and talent auras such as Bone
    Shield 195181; family 0 is where items, potions and enchants live).
    names: {class token: lower-cased names of that class's pooled spells}, for an aura that reaches
    none of those edges but carries the name of a spell its own class can cast (Whirling Dragon
    Punch's aura 196742).

    The bare build_pool holds learnable ids only; on the owner's logs (SID-10) it left 1,532
    above-bar class procs outside the pool, and R8 filed every one of them as a consumable.
    """
    pool, classes = research.build_pool(cache)
    classes = defaultdict(set, {spell: set(tokens) for spell, tokens in classes.items()})
    _mechanics, triggers = research.read_spell_effect(cache["SpellEffect"])
    research.close_over_triggers(pool, classes, triggers)
    by_class: Dict[str, Set[str]] = defaultdict(set)
    spell_names = research.read_names(cache["SpellName"]) if "SpellName" in cache else {}
    for spell in pool:
        name = spell_names.get(spell)
        if name:
            for token in classes.get(spell, ()):
                by_class[token].add(name.lower())
    ids = set(pool) | set(research.read_spell_families(cache["SpellClassOptions"]))
    return ids, dict(by_class)


def player_pool(cache: Dict[str, Path]) -> Set[int]:
    """castable()'s ids: every class spell id, for rule R8."""
    return castable(cache)[0]


# --- the DB2 cache ---------------------------------------------------------------------------------

_SPELL_NAME_FILE = re.compile(r"^SpellName-(?P<build>\d+(?:\.\d+)*)\.csv$")


def newest_cached_build(db2_cache: Path) -> Optional[str]:
    """The newest build with a SpellName-<build>.csv in the cache, compared as a version."""
    if not db2_cache.is_dir():
        return None
    builds = [m.group("build") for m in (_SPELL_NAME_FILE.match(p.name) for p in db2_cache.iterdir())
              if m]
    if not builds:
        return None
    return max(builds, key=lambda b: tuple(int(part) for part in b.split(".")))


def open_db2(db2_cache: Path, build: Optional[str]) -> Dict[str, Path]:
    """{table: path} for every table in research.TABLES, fetched into the cache when missing.

    `build` defaults to the newest build already in the cache, then to the live build
    (research.resolve_build, which needs the network).
    """
    build = build or newest_cached_build(db2_cache) or research.resolve_build(None)
    return {table: research.fetch_table(table, build, db2_cache, refresh=False)
            for table, _why in research.TABLES}


# --- defaults/Categories.lua ------------------------------------------------------------------------

# A category's opening line: `key = "...", kind = "spells", label = "..."`. Anchored at the start of a
# line so a commented-out one (`-- key = ...`) is never read.
_SPELLS_CATEGORY = re.compile(
    r'^[ \t]*key\s*=\s*"(?P<key>\w+)"\s*,\s*kind\s*=\s*"spells"\s*,\s*label\s*=\s*"(?P<label>[^"]*)"',
    re.MULTILINE)
_ANY_KEY = re.compile(r'^[ \t]*key\s*=\s*"', re.MULTILINE)
_HARMFUL = re.compile(r"^Cat\.HARMFUL\s*=", re.MULTILINE)


def shipped_categories(categories_lua: Path) -> List[dict]:
    """Every `kind = "spells"` category, in file order.

    [{"key", "label", "aura": "BUFF"|"DEBUFF", "classes": {CLASS: [ids in line order]}}], aura from
    whether the category sits in Cat.HELPFUL or Cat.HARMFUL. research.read_shipped_named reads the
    same class lines but drops which category they are in, so this walks each category's own
    `spells({ ... })` block with research's ANY_SPELLS_BLOCK and SHIPPED_LINE (one class line
    each, commented-out lines skipped, trailing comments ignored).
    """
    if not categories_lua.exists():
        return []
    text = categories_lua.read_text(encoding="utf-8")
    harmful = _HARMFUL.search(text)
    harmful_at = harmful.start() if harmful else len(text)
    out: List[dict] = []
    for cat in _SPELLS_CATEGORY.finditer(text):
        block = research.ANY_SPELLS_BLOCK.search(text, cat.end())
        following = _ANY_KEY.search(text, cat.end())
        if not block or (following and following.start() < block.start()):
            continue  # no spells table of its own: not something this tool can read
        classes: Dict[str, List[int]] = {}
        for line in research.SHIPPED_LINE.finditer(block.group("body")):
            ids = [int(t) for t in re.findall(r"\d+", line.group("ids"))]
            classes.setdefault(line.group("class"), []).extend(ids)
        out.append({
            "key": cat.group("key"),
            "label": cat.group("label"),
            "aura": "DEBUFF" if cat.start() > harmful_at else "BUFF",
            "classes": classes,
        })
    return out


# --- defaults/CastToAura.lua -----------------------------------------------------------------------

_TABLE = r"^NS\.CastToAura\.%s\s*=\s*\{(?P<body>.*?)^\}"
_REWRITE_TABLE = re.compile(_TABLE % "REWRITE", re.MULTILINE | re.DOTALL)
_CHOICES_TABLE = re.compile(_TABLE % "CHOICES", re.MULTILINE | re.DOTALL)
_REWRITE_ENTRY = re.compile(r"^\s*\[(?P<cast>\d+)\]\s*=\s*(?P<aura>\d+)\s*,", re.MULTILINE)
_CHOICES_ENTRY = re.compile(r"^\s*\[(?P<cast>\d+)\]\s*=\s*\{(?P<ids>[^}]*)\}", re.MULTILINE)


def cast_aura_candidates(cast_to_aura_lua: Path) -> Dict[int, List[int]]:
    """{cast id: [candidate aura ids]}: REWRITE (`[cast] = aura`) and CHOICES (`[cast] = {...}`)."""
    text = cast_to_aura_lua.read_text(encoding="utf-8")
    out: Dict[int, List[int]] = {}
    table = _REWRITE_TABLE.search(text)
    if table:
        for entry in _REWRITE_ENTRY.finditer(table.group("body")):
            out[int(entry.group("cast"))] = [int(entry.group("aura"))]
    table = _CHOICES_TABLE.search(text)
    if table:
        for entry in _CHOICES_ENTRY.finditer(table.group("body")):
            out[int(entry.group("cast"))] = [int(t) for t in re.findall(r"\d+", entry.group("ids"))]
    return out


def aura_to_family(candidates: Dict[int, List[int]]) -> Dict[int, Set[int]]:
    """{aura id: every aura id sharing a cast with it, itself included}.

    An aura two casts can land belongs to both families (the union). Cast ids are not keys.
    """
    out: Dict[int, Set[int]] = defaultdict(set)
    for auras in candidates.values():
        for aura in auras:
            out[aura] |= set(auras)
    return dict(out)
