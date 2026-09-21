#!/usr/bin/env python3
"""tools/spell-research/research.py — derive AuraMaster's CC spell lists from the client's own data.

WHAT THIS IS
    The repeatable half of GitHub issue #11 (design of record:
    docs/superpowers/specs/2026-09-20-cc-categories-spell-research-design.md, Part C). It reads
    Blizzard's own DB2 tables for one pinned retail build, works out which spells a player can
    actually cast (or be reached by), buckets them by the crowd-control MECHANIC the client itself
    stamps on them, and prints either a diff against what `defaults/Categories.lua` ships today or a
    paste-ready Lua fragment in that file's own shape.

    It NEVER writes `defaults/Categories.lua`. Part C's narrowing rule is that the author accepts the
    diff per change (spec, "Decisions taken"): a generator that edits the shipped file would turn a
    judgment call into a rubber stamp, and C7's honest limitations are exactly the cases where that
    judgment is the only thing standing between the addon and a wrong list.

WHY THE TRIGGER-SPELL CLOSURE EXISTS — THE CRUX (spec C1)
    AuraMaster's filters match THE AURA'S spell id. `modules/FilterCompiler.lua` hands Blizzard's
    aura container `includeSpellIDs` / `excludeSpellIDs`, and the engine compares those against the
    id of the aura sitting on the unit — not against the id of the spell that was cast.

    Plenty of crowd control is cast as one spell and lands as another. Freezing Trap is the canonical
    case: the hunter casts the trap, the trap's effect triggers a second spell, and it is THAT
    second spell's id that appears on the target. A list built from cast ids looks completely
    populated in the General -> Spell Categories editor and silently never matches anything in game
    — the worst possible failure, because nothing anywhere reports it.

    So step 4 of the pipeline closes the player-spell pool transitively over
    `SpellEffect.EffectTriggerSpell` BEFORE any mechanic is matched, carrying the class set across
    each edge. This is the single easiest thing in the whole design to get wrong and the hardest to
    notice in play, which is also why the coverage gate below exists.

    AND THAT CLOSURE IS NOT ENOUGH ON ITS OWN. A great deal of player CC hands off to something the
    spell graph simply does not describe, and there are three distinct shapes of that handoff, all
    verified against build 12.1.0.69875:

      * A GROUND EFFECT. Freezing Trap — the spec's own canonical case — is cast as 187650, whose
        effect 32 triggers 187651, whose single effect is CREATE_AREATRIGGER (effect 179) naming
        AreaTriggerCreateProperties 4424. The aura the target gets, 3355, hangs off that area
        trigger's action set, and AreaTriggerCreateProperties is `ID,ShapeType,StartShapeID,
        SoundKitID` — it has no spell column at all. There is no edge to follow.
      * A SUMMONED CREATURE. Capacitor Totem is cast as 192058, whose effect 28 SUMMON names
        creature 61245. The totem casts the stun, 118905. Which spells a creature casts is server
        data; no DB2 table here carries it.
      * A SERVER SPELL SCRIPT. Storm Bolt is cast as 107570 (effect 2 damage, effect 3 DUMMY) and
        the stun aura is 132169. Blinding Light 115750 -> 105421 and Holy Word: Chastise 88625 ->
        200200 are the same shape. `EffectTriggerSpell` is 0 on every one of those effects: the
        aura is applied by a script that exists only in the server binary.

    So step 5 adds ONE more edge, and the question is what evidence it may rest on. The client does
    carry a real relationship here, just not a directed one: `SpellClassOptions.SpellClassSet` is the
    spell FAMILY — the grouping the game's own talent and set-bonus modifiers are written against.
    Every pair above shares a family (Storm Bolt 107570/132169 are both family 4, Ring of Frost
    113724/82691 both 3, Blinding Light 115750/105421 both 10, Holy Word: Chastise 88625/200200 both
    6, Capacitor Totem 192058/118905 both 11, Freezing Trap 187651/3355 both 9), and every NPC and
    encounter copy that merely SHARES A NAME with one of them sits in family 0.

    The bridge is therefore: a pool spell bridges to a spell with the SAME EXACT NAME and the SAME
    NON-ZERO SPELL FAMILY that carries a bucket mechanic. Family is the foreign key; the name is what
    picks one ability out of the family. Measured on build 12.1.0.69875 that adds 298 ids, and the
    names it adds read as a list of player crowd control — Freezing Trap, Ring of Frost, Storm Bolt,
    Shockwave, Capacitor Totem, Sigil of Misery, Ursol's Vortex, Imprison, Hex, Blinding Sleet.

    WHY NOT NAME ALONE, AND WHY NOT AN EFFECT FENCE. Name alone adds 1,763 ids, most of them
    encounter scripts that happen to reuse a word. The fence this bridge REPLACED was "only spells
    that create an area trigger may bridge", which was fitted to the one case (Freezing Trap) that
    had failed, and by construction could not see the summon or the spell-script shapes: it left
    Storm Bolt, Ring of Frost, Blinding Light, Holy Word: Chastise and Capacitor Totem out of the
    derived pool while the coverage gate reported PASS. Generalising that fence to effects 179, 28
    and 3 would have caught them, but at 547 ids of mostly noise, because DUMMY is not evidence of
    anything. Family is evidence. The lesson is the reason the sentinel list below is chosen from
    what a player would name, never from what the tool already prints.

    Every bridged id is still labelled `"source": "bridge"` in derived.json, called out in the diff
    and commented in the emitted Lua, because a shared name inside a shared family is still weaker
    than a directed edge and the author prunes at the diff (spec C3 step 5).

THE PIPELINE
    1. Resolve the build — `https://wago.tools/api/builds`, key "wow" is retail, newest first — or
       take `--build` to pin one explicitly (a bundle must be reproducible, and "latest" is not).
    2. Fetch the fourteen DB2 tables as CSV to a cache OUTSIDE git (`--cache-dir`, default
       `tools/spell-research/.cache`, which `tools/spell-research/.gitignore` excludes). Re-runs
       reuse the cache; `--refresh` forces a re-download. SpellEffect is ~57 MB, so every table is
       streamed to disk in chunks and then read row by row — the raw text is never held in memory.
    3. Build the player pool — every spell a player can reach — from SkillLineAbility (class masks
       and class skill lines), SpecializationSpells and TraitDefinition. Each step below measurably
       added coverage when the approach was validated; none of them is redundant.
    4. Close that pool over EffectTriggerSpell (see above).
    5. Bridge within the spell family by name (see above), the one edge DB2 does not give us
       directed. Steps 4 and 5 then ALTERNATE TO A FIXED POINT: a bridged aura can itself trigger a
       further spell, and a triggered spell can itself be the ability whose family sibling carries
       the mechanic, so running each exactly once would make the order of two steps load-bearing and
       leave whichever ran first unfinished. Iterating removes the ordering question entirely.
    6. Union the spell-level mechanic (`SpellCategories.Mechanic`) with every effect-level mechanic
       (`SpellEffect.EffectMechanic`) per spell, and bucket against BUCKET_MECHANICS.
    7. Run the coverage gate (SENTINELS). A miss exits non-zero and names what is missing.
    8. Report: `--diff` against the shipped lists, `--emit` a Lua fragment, `--bundle` a frozen
       dated directory under `docs/spell-research/`.

    Rows are read at `DifficultyID == 0` wherever that column exists, so raid-difficulty variants of
    the same spell do not multiply the set.

REQUIREMENTS
    Python 3 and its standard library only — urllib, csv, gzip, json, argparse. No pip packages, by
    design: `DEPENDENCIES.md` would otherwise have to grow a package manager for a tool that runs a
    handful of times per expansion. Network access is needed for a NEW run; a past run replays with
    `--replay docs/spell-research/<date>`, which reads that bundle's own gzipped exports and touches
    neither the network nor the cache (spec C7).

USAGE
    python3 tools/spell-research/research.py --diff
    python3 tools/spell-research/research.py --emit --date 2026-09-20   # --emit requires a date
    python3 tools/spell-research/research.py --bundle docs/spell-research/2026-09-20
    python3 tools/spell-research/research.py --build 12.1.0.69875 --refresh --diff --emit
    python3 tools/spell-research/research.py --replay docs/spell-research/2026-09-20 --diff

See tools/spell-research/README.md for the walkthrough and the honest limitations.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import json
import os
import re
import shutil
import sys
import urllib.error
import urllib.request
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

# ---------------------------------------------------------------------------
# AUTHORED INPUTS — the only hand-written data in this file
# ---------------------------------------------------------------------------
#
# Everything below this block is DERIVED. Everything in it is a judgment call that a human made and
# that a reviewer can argue with, which is precisely why it sits at the top of the file rather than
# buried where the code happens to need it (spec C3 step 4: "this bucket -> mechanic map is the one
# authored, reviewable input").

# Bucket -> SpellMechanic ids. The ids are `SpellMechanic.ID`; the names beside them are that
# table's own `StateName_lang` for the pinned build, so a patch that renumbers a mechanic shows up as
# a name that no longer reads correctly (and, far more loudly, as a failed sentinel).
#
# The split follows Part A's definition of the two categories, not Blizzard's DR groups: Hard CC is
# "the unit loses control", Soft CC is "the unit keeps control but moves less". That is a deliberate
# two-way split rather than the five DR categories — see the spec's "Decisions taken".
BUCKET_MECHANICS = {
    "hardCC": {
        1: "Charmed",
        2: "Disoriented",
        5: "Fleeing",
        10: "Asleep",
        12: "Stunned",
        13: "Frozen",
        14: "Incapacitated",
        17: "Polymorphed",
        18: "Banished",
        20: "Shackled",
        23: "Turned",
        24: "Horrified",
        30: "Sapped",
    },
    "softCC": {
        7: "Rooted",
        8: "Slowed",
        11: "Snared",
        27: "Dazed",
    },
}

# Bucket order everywhere this tool prints or writes, so a diff of two runs' output is a diff of the
# data and not of dict ordering.
BUCKET_ORDER = ("hardCC", "softCC")

# The category `name` Part A gives each bucket in `defaults/Categories.lua`. Used to LABEL each
# emitted block: `--emit` prints the two `spells({ ... })` tables back to back, each a hundred lines
# long, and the fragment is pasted into a file where putting the hard-CC ids under the soft-CC key
# is both silent and catastrophic — the editor would look right and every filter would be wrong.
# A block that names its own bucket and category key cannot be pasted into the wrong one by accident.
BUCKET_TITLES = {"hardCC": "Hard CC", "softCC": "Soft CC"}

# THE COVERAGE GATE (spec C4). A checked-in set of spells that MUST land in a given bucket.
#
# This is not belt-and-braces. Silent under-coverage was demonstrated three separate times while the
# approach was being validated: a first cut matched 32 hard-CC spells, a second 66, and only a third
# — after class skill lines were added to the pool — reached 81 and finally picked up Hammer of
# Justice, Entangling Roots and Leg Sweep. Every one of those intermediate runs produced a
# plausible-looking list that a reviewer would have accepted.
#
# AND THEN THE GATE ITSELF FAILED, WHICH IS WHY THIS LIST LOOKS THE WAY IT DOES. Its first version
# held ten hard-CC and six soft-CC names, and every one of them was a name the implementation of the
# day already produced. A gate assembled that way can only ever report PASS; it certifies that the
# tool still does what it did, which is not the question. It duly reported PASS over a derived set
# missing Storm Bolt, Ring of Frost, Blinding Light, Holy Word: Chastise and Capacitor Totem — five
# of the most recognisable stuns in the game — because the area-trigger fence on the name bridge
# could not see them (see the module docstring). A gate that cannot fail is worse than no gate: no
# gate leaves a reviewer suspicious, a passing gate buys their trust with nothing behind it.
#
# So this list is built the other way round, and MUST KEEP BEING BUILT THAT WAY. Write down what a
# player would name as that class's crowd control — from the game, from a PvP talent row, from
# memory of being on the receiving end — and only then make the pipeline satisfy it. If a name here
# is missing from a run, the answer is to fix the pipeline or to move the name to
# SENTINELS_UNREACHABLE below with a reason. The answer is never to delete it quietly, and it is
# never to bend BUCKET_MECHANICS until it passes: bending the map to satisfy its own test is the one
# thing this gate must never be allowed to cause.
#
# Grouped by class so a gap is legible as a gap. Matching is by NAME (`SpellName.Name_lang`),
# case-insensitively, against the derived bucket. Names are used rather than ids on purpose: an id is
# exactly the thing a patch is allowed to change, and a sentinel that silently stopped existing would
# defeat the gate it is part of.
SENTINELS = {
    "hardCC": (
        # Warrior
        "Storm Bolt", "Shockwave", "Intimidating Shout",
        # Paladin
        "Hammer of Justice",   # the third validation run's canary
        "Blinding Light", "Turn Evil",
        # Hunter
        "Freezing Trap",       # THE C1 case: cast id != aura id, and the bridge's canary
        "Intimidation", "Binding Shot", "Scatter Shot",
        # Rogue
        "Kidney Shot", "Cheap Shot", "Sap", "Blind",
        # Priest
        "Psychic Scream", "Mind Control", "Dominate Mind", "Holy Word: Chastise",
        # Death Knight
        "Asphyxiate", "Blinding Sleet",
        # Shaman
        "Hex", "Capacitor Totem",
        # Mage
        "Polymorph", "Dragon's Breath", "Ring of Frost",
        # Warlock
        "Fear", "Howl of Terror", "Mortal Coil", "Banish", "Shadowfury",
        # Monk
        "Leg Sweep", "Paralysis",
        # Druid
        "Mighty Bash", "Cyclone", "Incapacitating Roar", "Maim",
        # Demon Hunter
        "Imprison", "Chaos Nova", "Fel Eruption", "Sigil of Misery",
        # Evoker
        "Sleep Walk",
        # Racials — these reach every class's version of this list, and they are `ALL` in the
        # emitted fragment, so a pool step that loses racials loses them for thirteen classes at once.
        "War Stomp", "Quaking Palm", "Haymaker",
    ),
    "softCC": (
        # ENTANGLING ROOTS IS A SOFT-CC SENTINEL, DELIBERATELY. The design's Part C prose names it
        # among the spells the third validation run finally reached, which is a statement about POOL
        # COVERAGE, and it was easy to read that as a statement about its BUCKET. It is not: Part A
        # defines Soft CC as "the unit keeps control but moves less: roots and snares", and the
        # client agrees — Entangling Roots (339) carries mechanic 7, Rooted, and nothing else.
        # Warrior
        "Hamstring", "Piercing Howl",
        # Hunter
        "Concussive Shot", "Tar Trap",
        # Rogue
        "Crippling Poison",
        # Priest
        "Void Tendrils", "Mind Flay",
        # Death Knight
        "Chains of Ice", "Grip of the Dead",
        # Shaman
        "Frost Shock", "Thunderstorm",
        # Mage
        "Frost Nova",          # roots; lands in soft CC because its mechanic is Rooted, not Stunned
        "Cone of Cold", "Slow",
        # Warlock
        "Curse of Exhaustion",
        # Monk
        "Disable",
        # Druid
        "Entangling Roots", "Mass Entanglement", "Ursol's Vortex", "Typhoon",
        # Demon Hunter
        "Sigil of Chains",
        # Evoker
        "Landslide",
    ),
}

# SENTINELS THE CLIENT'S OWN DATA CANNOT REACH, and why. This register exists so that the gate above
# stays a list of names picked from the game rather than a list of names picked from the output: a
# name that belongs on it but cannot pass has to be written down HERE, with the reason, instead of
# being dropped and forgotten. A reader can then audit the gate's honesty by reading two lists.
#
# Nothing here is checked at run time — a gate that fails on every run is a gate that gets ignored —
# but each line is a real coverage gap and each is mirrored in README.md's "Limitations".
SENTINELS_UNREACHABLE = {
    # Verified against build 12.1.0.69875: the string "20066" does not occur in SkillLineAbility,
    # SpecializationSpells, TraitDefinition or TraitNodeEntry, no SpellEffect row has 20066 as its
    # EffectTriggerSpell, and every one of the eighteen spells named "Repentance" sits outside the
    # pool. Repentance carries mechanic 14 (Incapacitated) and is unquestionably a paladin ability,
    # so the client is granting it by a route none of the four pool sources describes. It is the one
    # hard-CC name on the domain list that no amount of pipeline work reached.
    "hardCC": {
        "Repentance": "in none of the four pool sources for the pinned build",
        # PET CC. Axe Toss (89766) and Seduction (6358) ARE in SkillLineAbility, with ClassMask 0 and
        # a pet skill line — 761 and 931 for the felguard, 205 for the succubus — and `build_pool`
        # keeps a ClassMask-0 row only when its skill line is one of the thirteen CLASS lines. That
        # test is what keeps professions, mounts and racial trade skills out, and relaxing it to
        # admit pet lines would admit all of those too. A warlock's pet stun is real CC on a real
        # player frame, so this is a genuine gap rather than a definitional one; closing it means
        # teaching the pool about pet skill lines specifically, which is its own change.
        "Axe Toss": "pet skill line 761/931; the pool keeps ClassMask-0 rows only on class lines",
        "Seduction": "pet skill line 205; same test",
    },
    "softCC": {
        # Earthbind Totem (2484) IS in the pool, but it carries no mechanic and the aura it lands is
        # named "Earthbind", not "Earthbind Totem" — so neither the mechanic match nor the family
        # bridge, which requires an exact name match, can cross from the totem to its snare.
        "Earthbind Totem": "the totem's aura is named 'Earthbind'; the family bridge needs an exact "
                           "name match",
    },
}

# `SkillLineAbility.ClassMask` bits -> the class token `defaults/Categories.lua` groups by. These are
# the same tokens the `spells({ CLASS = { ... } })` helper takes and the same ones the General ->
# Spell Categories editor groups rows under (`class` is display-only there; the filter ignores it).
CLASS_MASK_BITS = (
    (1 << 0, "WARRIOR"),
    (1 << 1, "PALADIN"),
    (1 << 2, "HUNTER"),
    (1 << 3, "ROGUE"),
    (1 << 4, "PRIEST"),
    (1 << 5, "DEATHKNIGHT"),
    (1 << 6, "SHAMAN"),
    (1 << 7, "MAGE"),
    (1 << 8, "WARLOCK"),
    (1 << 9, "MONK"),
    (1 << 10, "DRUID"),
    (1 << 11, "DEMONHUNTER"),
    (1 << 12, "EVOKER"),
)

# `ChrSpecialization.ClassID` -> class token. ClassID is 1-based in exactly the order CLASS_MASK_BITS
# encodes (ClassID 1 is WARRIOR and ClassMask bit 0 is WARRIOR, all the way to 13 / bit 12 EVOKER),
# so this is derived from that tuple rather than typed out a second time and left to drift.
CLASS_BY_CLASS_ID = {index + 1: token for index, (_bit, token) in enumerate(CLASS_MASK_BITS)}

# `SkillLine.DisplayName_lang` -> class token, for the class skill lines. The ids are NOT hard-coded:
# they are looked up at run time out of SkillLine, keeping only rows with `CategoryID == 7` (the
# class category) and `ParentSkillLineID == 0` (the class itself, not one of its specializations).
# Specialization skill lines — the children of those rows — inherit their parent's class token, which
# is where a fair number of talent-granted abilities are reachable from.
#
# WHY THIS MATTERS: a share of class abilities carry `ClassMask == 0` and are reachable only through
# their skill line. Leaving this step out is what produced the 66-spell second cut described above;
# adding it is what produced 81 and the three canary spells. It is NOT where the bulk of modern class
# CC lives, though — measured against build 12.1.0.69875 the thirteen class skill lines carry only
# 17 to 122 ability rows each, and Mind Control, Banish, Psychic Scream and Incapacitating Roar are
# in none of them. Those come from SpecializationSpells and the talent trees, which is why
# ChrSpecialization is fetched: measured while the pool was being built out, without it 106 of the
# 184 spells that cut derived had no class at all and collapsed into `ALL`. (That 184 is the set of
# the day, before the family bridge; the 2026-09-20 run derives 427 and puts 46 under `ALL`.) An
# emitted fragment that files Banish under `ALL` is not one anybody would paste.
CLASS_SKILL_LINE_NAMES = {
    "Warrior": "WARRIOR",
    "Paladin": "PALADIN",
    "Hunter": "HUNTER",
    "Rogue": "ROGUE",
    "Priest": "PRIEST",
    "Death Knight": "DEATHKNIGHT",
    "Shaman": "SHAMAN",
    "Mage": "MAGE",
    "Warlock": "WARLOCK",
    "Monk": "MONK",
    "Druid": "DRUID",
    "Demon Hunter": "DEMONHUNTER",
    "Evoker": "EVOKER",
}

# How many distinct classes a spell has to be reachable by before it is emitted as `ALL` rather than
# listed under each class in turn.
#
# THE THRESHOLD, AND WHY IT IS 7. A real class ability reaches one class, or two or three when a
# ClassMask covers a shared tree. The things that reach many classes are not class abilities at all:
# racials (War Stomp, Shadowmeld — 58984 is already filed under `ALL` in defaults/Categories.lua),
# trinket and item effects, and profession or covenant leftovers. Nothing sits in between, so any
# threshold in the middle of the range separates the two populations cleanly; 7 is a simple majority
# of the 13 classes and reads as "most of the game can do this", which is what `ALL` means in that
# file. Spells over the line are emitted once under `ALL` instead of thirteen times.
ALL_CLASS_THRESHOLD = 7

# `SpellClassOptions.SpellClassSet` is the spell FAMILY — the client's own grouping of "these
# spells are the same class ability", the thing talent and set-bonus modifiers are written against
# (`EffectSpellClassMask_0..3` indexes into it). It is the foreign key the family bridge rests on;
# see the module docstring for the three handoff shapes that make a bridge necessary at all and for
# the measurements behind choosing family over a name match or an effect fence.
#
# Family 0 means "no family", which is where every NPC and encounter script lives. A bridge FROM a
# family-0 spell, or TO one, is therefore never taken: that single condition is what keeps the
# bridge at 298 ids instead of the 1,763 a bare name match produces.
NO_SPELL_FAMILY = 0

# The class-key order `defaults/Categories.lua` writes its `spells({ ... })` tables in. `ALL` goes
# last there too (see `consumables`), so the emitted fragment drops straight in.
CLASS_EMIT_ORDER = (
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN",
    "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER", "ALL",
)

# ---------------------------------------------------------------------------
# Source data
# ---------------------------------------------------------------------------

BUILDS_URL = "https://wago.tools/api/builds"
CSV_URL = "https://wago.tools/db2/{table}/csv?build={build}"

# wago.tools rejects urllib's default User-Agent with HTTP 403, so every request carries one that
# says who is asking. This is not a workaround for a rate limit — the site serves the export happily,
# it just declines anonymous library defaults.
USER_AGENT = "AuraMaster-spell-research/1.0 (+https://github.com/tusharsaxena/AuraMaster)"

# The fourteen tables, with why each one is needed. This tuple IS the fetch list and the list SOURCES.md
# records, so the bundle can never claim a table the run did not actually read.
TABLES = (
    ("SpellCategories", "spell-level Mechanic, and DiminishType for provenance"),
    ("SpellEffect", "effect-level EffectMechanic, and EffectTriggerSpell for the C1 closure"),
    ("SpellName", "names, for the trailing comments, the diff and the coverage gate"),
    ("SkillLineAbility", "ClassMask and SkillLine -> the player pool and its class keys"),
    ("SkillLine", "resolves class skill lines for rows whose ClassMask is 0"),
    ("SpecializationSpells", "spec-granted abilities — where most modern class CC actually lives"),
    ("ChrSpecialization", "SpecID -> ClassID, the class key for every spec-granted ability"),
    ("TraitDefinition", "talent-tree-granted abilities (SpellID, VisibleSpellID)"),
    ("TraitNodeEntry", "TraitDefinitionID -> node entry, step 1 of the talent -> class join"),
    ("TraitNodeXTraitNodeEntry", "node entry -> node, step 2"),
    ("TraitNode", "node -> TraitTreeID, step 3"),
    ("TraitTreeLoadout", "TraitTreeID -> ChrSpecializationID, step 4 — and thence to a class"),
    ("SpellClassOptions", "SpellClassSet — the spell family the family bridge rests on"),
    ("SpellMechanic", "the mechanic id -> name table BUCKET_MECHANICS is written against"),
)

DOWNLOAD_CHUNK = 1 << 20  # 1 MiB; SpellEffect is ~57 MB and must never be read into a string

# The emitted Lua's line terminator. The repo is pinned `* text=auto eol=crlf`, and a generated
# file lands in the working tree where tests/_kit's eol suite reads it.
NEWLINE = "\r\n"


def log(msg: str) -> None:
    """Progress goes to stderr so `--emit` can be piped straight into a file."""
    print(msg, file=sys.stderr, flush=True)


def http_get(url: str, accept: str = "*/*"):
    """Open a wago.tools URL with the identifying User-Agent, or die with something readable."""
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": accept})
    try:
        return urllib.request.urlopen(req, timeout=300)
    except urllib.error.HTTPError as err:  # a 403 here is almost always the User-Agent
        raise SystemExit("HTTP %s fetching %s: %s" % (err.code, url, err.reason))
    except urllib.error.URLError as err:
        raise SystemExit("Could not reach %s: %s (a new run needs network access — spec C7)"
                         % (url, err.reason))


def resolve_build(explicit: str | None) -> str:
    """The build to pin the run to: `--build` if given, else the newest retail build.

    The builds API returns one list per product; "wow" is retail (the others are PTR, beta, classic
    and so on), newest first. A run is pinned to ONE build on purpose: the bundle records it, and a
    diff between two bundles is then a diff of the game rather than of when someone happened to run
    the tool.
    """
    if explicit:
        return explicit
    log("Resolving the live retail build from %s ..." % BUILDS_URL)
    data = json.load(http_get(BUILDS_URL, accept="application/json"))
    builds = data.get("wow") or []
    if not builds:
        raise SystemExit("The builds API returned no 'wow' (retail) builds; pass --build explicitly.")
    version = builds[0]["version"]
    log("  build %s (created %s)" % (version, builds[0].get("created_at", "?")))
    return version


def replay_provenance(replay_dir: Path, explicit_build: str | None) -> tuple[str, str]:
    """The build and fetch time a past bundle recorded, for a `--replay` run to inherit.

    A replay derives from bytes somebody else downloaded, so both facts belong to THAT run and are
    read back out of the bundle's `derived.json` rather than re-established: the build because the
    live one has moved on since (see the comment at the call site), and the fetch time because a
    bundle re-frozen from a replay must not claim the CSVs were pulled from wago.tools the moment it
    was written. The inherited time is suffixed with where it came from so a reader of SOURCES.md can
    tell a first-hand download from a re-derivation without diffing two directories.

    `--build` still overrides, and a bundle with no readable derived.json is not fatal as long as the
    caller pins one — the raw/ members are the only thing a replay strictly needs.
    """
    meta: dict = {}
    manifest = replay_dir / "derived.json"
    if manifest.exists():
        try:
            meta = json.loads(manifest.read_text(encoding="utf-8"))
        except ValueError:
            meta = {}
    build = explicit_build or meta.get("build")
    if not build:
        raise SystemExit(
            "--replay %s has no readable derived.json to take its build from; pass --build.\n"
            "The build is not guessable here and must not be taken from the live builds API: a\n"
            "replay would then stamp today's build onto numbers derived from older bytes."
            % replay_dir)
    fetched_at = meta.get("fetchedAt", "unknown")
    return build, "%s (replayed from %s)" % (fetched_at, replay_dir.as_posix())


def fetch_table(table: str, build: str, cache_dir: Path, refresh: bool,
                replay_dir: Path | None = None) -> Path:
    """Download one DB2 table's CSV export into the cache, streaming it to disk.

    With `replay_dir` set (`--replay`), nothing is downloaded at all: the table is read straight out
    of `<bundle>/raw/<Table>.csv.gz`, the gzipped copy `write_bundle` froze. That is what makes spec
    C7's "a past run replays from its bundle offline" a fact about the code rather than a claim in a
    docstring — the bundle carries every byte the run read, so re-deriving from it needs no network
    and no cache, and the gzipped member is handed to `iter_csv` as-is (it opens `.gz` itself) rather
    than being expanded into the cache, because a replay should not leave 70 MB of uncompressed CSV
    behind for a build the caller may never run against again.

    A missing member is a hard error naming the file. A bundle with a table missing is a bundle that
    cannot reproduce its own numbers, and silently deriving from thirteen of fourteen tables would
    report a confidently wrong, half-covered list — the same failure the `.part` rename below exists
    to prevent.

    The cache lives OUTSIDE git (`tools/spell-research/.gitignore` excludes `.cache/`) because these
    exports total ~70 MB per build and only the gzipped copies inside a dated bundle are meant to be
    committed. The file name carries the build, so two builds coexist and a re-run against a build
    already fetched costs nothing.

    The download goes through `shutil.copyfileobj` into a `.part` file that is renamed only once the
    transfer finishes: an interrupted run then re-downloads rather than parsing half a table and
    reporting a confidently wrong, half-covered list.
    """
    if replay_dir is not None:
        member = replay_dir / "raw" / ("%s.csv.gz" % table)
        if not member.exists():
            raise SystemExit(
                "--replay %s is missing raw/%s.csv.gz. A bundle that cannot hand back every table\n"
                "it read cannot reproduce its own numbers; re-run against the live build instead."
                % (replay_dir, table))
        log("  %-22s replayed (%.1f MB gzipped)" % (table, member.stat().st_size / 1e6))
        return member
    cache_dir.mkdir(parents=True, exist_ok=True)
    dest = cache_dir / ("%s-%s.csv" % (table, build))
    if dest.exists() and not refresh:
        log("  %-22s cached (%.1f MB)" % (table, dest.stat().st_size / 1e6))
        return dest
    url = CSV_URL.format(table=table, build=build)
    tmp = dest.with_suffix(".csv.part")
    log("  %-22s fetching %s" % (table, url))
    with http_get(url, accept="text/csv") as response, tmp.open("wb") as handle:
        shutil.copyfileobj(response, handle, DOWNLOAD_CHUNK)
    tmp.replace(dest)
    log("  %-22s %.1f MB" % (table, dest.stat().st_size / 1e6))
    return dest


def iter_csv(path: Path):
    """Yield each row of a cached export as a dict, one row at a time.

    `csv.DictReader` over an open file handle keeps exactly one row in memory, which is the whole
    reason SpellEffect (~57 MB, well over a million rows) is affordable here. `newline=""` is the
    documented way to hand a file to the csv module; without it a field containing a newline — spell
    descriptions have them — is split across two rows.

    A path ending `.csv.gz` is a bundle member being replayed (`--replay`), and is opened through
    `gzip.open` in text mode. Decompressing on the fly keeps the streaming property that makes the
    replay affordable at all: gzip yields the same one-row-at-a-time handle to `csv.DictReader`, so
    a 57 MB SpellEffect never exists on disk uncompressed or in memory whole.
    """
    if path.suffix == ".gz":
        with gzip.open(path, "rt", encoding="utf-8", newline="") as handle:
            for row in csv.DictReader(handle):
                yield row
        return
    with path.open("r", encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            yield row


def as_int(value: str | None) -> int:
    """A DB2 CSV integer field, tolerating the empty cell an optional column leaves behind."""
    if not value:
        return 0
    try:
        return int(value)
    except ValueError:
        # Some columns are floats in the export (EffectBasePointsF and friends). None of the columns
        # this tool reads should land here, so truncating rather than raising keeps a table-shape
        # change from masquerading as a crash — the coverage gate is what reports the damage.
        try:
            return int(float(value))
        except ValueError:
            return 0


def base_difficulty(row: dict) -> bool:
    """True when the row is the base-difficulty variant (or the table has no difficulty column).

    Spec C2: rows are read at `DifficultyID == 0`. Raid difficulties duplicate a spell's categories
    and effects, and counting them would inflate every bucket without adding a single new spell.
    """
    value = row.get("DifficultyID")
    return value is None or as_int(value) == 0


# ---------------------------------------------------------------------------
# Step 3 — the player pool
# ---------------------------------------------------------------------------

def classes_from_mask(mask: int) -> set[str]:
    """The class tokens a `ClassMask` names."""
    return {token for bit, token in CLASS_MASK_BITS if mask & bit}


def load_class_skill_lines(path: Path) -> dict[int, str]:
    """`SkillLine.ID` -> class token, for class skill lines and their specialization children.

    Class lines are the rows with `CategoryID == 7` and `ParentSkillLineID == 0` whose display name
    is one of the thirteen classes. Their children (the specialization lines) inherit the parent's
    token, so an ability reachable only through, say, the Frost Mage line still carries MAGE.

    The names are read out of the export rather than the ids being hard-coded, so a build that moves
    a skill line id is handled silently and a build that renames a class is caught loudly, below.
    """
    rows = [row for row in iter_csv(path)]
    lines: dict[int, str] = {}
    for row in rows:
        if as_int(row.get("CategoryID")) == 7 and as_int(row.get("ParentSkillLineID")) == 0:
            token = CLASS_SKILL_LINE_NAMES.get((row.get("DisplayName_lang") or "").strip())
            if token:
                lines[as_int(row["ID"])] = token
    missing = set(CLASS_SKILL_LINE_NAMES.values()) - set(lines.values())
    if missing:
        # Not fatal by itself — the coverage gate is the real verdict — but a class whose skill line
        # vanished will take a chunk of that class's abilities with it, and saying so here names the
        # cause instead of leaving a bare sentinel failure to be diagnosed from scratch.
        log("  WARNING: no class skill line found for %s (localized export, or a renamed class?)"
            % ", ".join(sorted(missing)))
    for row in rows:
        parent = lines.get(as_int(row.get("ParentSkillLineID")))
        if parent:
            lines.setdefault(as_int(row["ID"]), parent)
    return lines


def build_pool(cache: dict[str, Path]) -> tuple[set[int], dict[int, set[str]]]:
    """The set of player-reachable spell ids, and the class set each one was reached by.

    Three sources, each of which measurably added coverage when the approach was validated — none is
    subsumed by another:

      a. `SkillLineAbility` rows with a non-zero `ClassMask` OR a class skill line. This is the bulk
         of it, and it is the only source that carries class information.
      b. `SpecializationSpells.SpellID` — abilities a specialization grants directly.
      c. `TraitDefinition.SpellID` and `VisibleSpellID` — abilities a talent tree grants. The visible
         id is the one the tooltip (and often the aura) uses, so both are taken.

    (b) carries its class through `ChrSpecialization.ClassID` — see `spec_class` below.

    (c) carries its class the long way round — `trait_classes` below walks TraitDefinition ->
    TraitNodeEntry -> TraitNodeXTraitNodeEntry -> TraitNode -> TraitTreeLoadout -> ChrSpecialization.
    Four extra tables for one column looks like a lot until you measure it: (c) is where modern class
    CC actually lives. Mind Control (605), Banish (710), Psychic Scream (8122) and Incapacitating
    Roar (99) are in NEITHER SkillLineAbility NOR SpecializationSpells for build 12.1.0.69875 — they
    reach the pool only as talents, and without this join 105 of the 184 spells derived at the time
    landed in `ALL`. The 2026-09-20 run derives 427 and puts 46 there.
    An emitted fragment that files Banish under `ALL` is not one anybody would paste.

    Anything still left with no class after all three — a trait outside any loadout's tree, an aura
    reached only across a trigger edge from an unclassed spell — is emitted under `ALL` and flagged
    `classSource: "unknown"` in derived.json, where the author sees it and decides. That is a
    documented limitation, not an accident (README, "Limitations").
    """
    class_lines = load_class_skill_lines(cache["SkillLine"])
    pool: set[int] = set()
    classes: dict[int, set[str]] = defaultdict(set)

    for row in iter_csv(cache["SkillLineAbility"]):
        spell = as_int(row.get("Spell"))
        if not spell:
            continue
        mask = as_int(row.get("ClassMask"))
        line_class = class_lines.get(as_int(row.get("SkillLine")))
        if not mask and not line_class:
            continue  # a profession, a mount, a racial trade skill — not a class ability
        pool.add(spell)
        classes[spell] |= classes_from_mask(mask)
        if line_class:
            classes[spell].add(line_class)

    # SpecID -> class token, so a spec-granted ability carries the class that can cast it. This is
    # the join that makes the emitted fragment's class grouping worth anything (see the note on
    # CLASS_SKILL_LINE_NAMES for the measurement that forced it).
    spec_class = {as_int(row["ID"]): CLASS_BY_CLASS_ID.get(as_int(row.get("ClassID")))
                  for row in iter_csv(cache["ChrSpecialization"])}

    for row in iter_csv(cache["SpecializationSpells"]):
        spell = as_int(row.get("SpellID"))
        if not spell:
            continue
        pool.add(spell)
        token = spec_class.get(as_int(row.get("SpecID")))
        if token:
            classes[spell].add(token)

    definition_classes = trait_definition_classes(cache, spec_class)
    for row in iter_csv(cache["TraitDefinition"]):
        tokens = definition_classes.get(as_int(row.get("ID")), set())
        for column in ("SpellID", "VisibleSpellID"):
            spell = as_int(row.get(column))
            if spell:
                pool.add(spell)
                classes[spell] |= tokens

    return pool, classes


def trait_definition_classes(cache: dict[str, Path],
                             spec_class: dict[int, str | None]) -> dict[int, set[str]]:
    """`TraitDefinition.ID` -> the class tokens whose talent trees contain it.

    The chain, each link being one small table (every one of them under a megabyte):

        TraitDefinition.ID
          <- TraitNodeEntry.TraitDefinitionID          (which node entry grants it)
          <- TraitNodeXTraitNodeEntry.TraitNodeEntryID (which node that entry sits on)
          -> TraitNode.TraitTreeID                     (which tree that node belongs to)
          <- TraitTreeLoadout.TraitTreeID              (which specs load that tree)
          -> ChrSpecialization.ClassID                 (and therefore which class)

    A class tree is shared by every spec of that class, so the several specs a tree resolves to
    collapse to one token — which is exactly the grouping `defaults/Categories.lua` wants. A hero
    talent tree shared by two classes resolves to both, and that is correct too.

    See `build_pool`'s docstring for why this join is worth four tables.
    """
    entry_to_definition = {as_int(row["ID"]): as_int(row.get("TraitDefinitionID"))
                           for row in iter_csv(cache["TraitNodeEntry"])}
    node_to_entries: dict[int, list[int]] = defaultdict(list)
    for row in iter_csv(cache["TraitNodeXTraitNodeEntry"]):
        node_to_entries[as_int(row.get("TraitNodeID"))].append(as_int(row.get("TraitNodeEntryID")))
    tree_of_node = {as_int(row["ID"]): as_int(row.get("TraitTreeID"))
                    for row in iter_csv(cache["TraitNode"])}
    tree_classes: dict[int, set[str]] = defaultdict(set)
    for row in iter_csv(cache["TraitTreeLoadout"]):
        token = spec_class.get(as_int(row.get("ChrSpecializationID")))
        if token:
            tree_classes[as_int(row.get("TraitTreeID"))].add(token)

    definition_classes: dict[int, set[str]] = defaultdict(set)
    for node, entries in node_to_entries.items():
        tokens = tree_classes.get(tree_of_node.get(node, 0))
        if not tokens:
            continue
        for entry in entries:
            definition = entry_to_definition.get(entry)
            if definition:
                definition_classes[definition] |= tokens
    return definition_classes


# ---------------------------------------------------------------------------
# Step 4 and 5 — the trigger closure and the mechanic union
# ---------------------------------------------------------------------------

def read_spell_effect(path: Path) -> tuple[dict[int, set[int]], dict[int, set[int]]]:
    """One streaming pass over SpellEffect for the two things it is needed for.

    Returns `(effect_mechanics, triggers)`:
      * `effect_mechanics[spell]` — every non-zero `EffectMechanic` on that spell's effects. A great
        many CC spells carry their mechanic at the EFFECT level and nothing at all at the spell
        level, so reading only `SpellCategories.Mechanic` misses them.
      * `triggers[spell]` — every non-zero `EffectTriggerSpell`, i.e. the edges of the graph the
        pool is closed over in `close_over_triggers`. THIS IS THE C1 CRUX; see the module docstring.

    Both are collected in one pass because this is by far the biggest table in the set (~57 MB,
    ~630k rows) and a second traversal would double the slowest part of the run for no benefit.

    An earlier cut also collected every spell carrying effect 179, CREATE_AREATRIGGER, to fence the
    name bridge to ground effects. That fence is gone — it was fitted to the one case that had
    failed and silently excluded the summon and spell-script shapes (module docstring) — so this
    pass no longer looks at `Effect` at all.
    """
    effect_mechanics: dict[int, set[int]] = defaultdict(set)
    triggers: dict[int, set[int]] = defaultdict(set)
    rows = 0
    for row in iter_csv(path):
        rows += 1
        if not base_difficulty(row):
            continue
        spell = as_int(row.get("SpellID"))
        if not spell:
            continue
        mechanic = as_int(row.get("EffectMechanic"))
        if mechanic:
            effect_mechanics[spell].add(mechanic)
        triggered = as_int(row.get("EffectTriggerSpell"))
        if triggered:
            triggers[spell].add(triggered)
    log("  SpellEffect: %d rows, %d spells with an effect mechanic, %d with a trigger edge"
        % (rows, len(effect_mechanics), len(triggers)))
    return effect_mechanics, triggers


def read_spell_families(path: Path) -> dict[int, int]:
    """`SpellClassOptions.SpellID` -> `SpellClassSet`, the spell family.

    Spells absent from the table, and spells whose family is 0, are both "no family" and are simply
    never returned — `families.get(spell, NO_SPELL_FAMILY)` then reads the same for either, which is
    what the bridge wants. See NO_SPELL_FAMILY for what family 0 means and why it is the fence.
    """
    families: dict[int, int] = {}
    for row in iter_csv(path):
        family = as_int(row.get("SpellClassSet"))
        spell = as_int(row.get("SpellID"))
        if spell and family:
            families[spell] = family
    return families


def bridge_spell_families(pool: set[int], classes: dict[int, set[str]], names: dict[int, str],
                          families: dict[int, int], mechanics_of,
                          cc_mechanics: set[int]) -> set[int]:
    """Add the auras a pool ability applies through a handoff the spell graph does not describe.

    A pool spell bridges to every spell that shares its EXACT NAME and its NON-ZERO SPELL FAMILY and
    carries a bucket mechanic. Returns the ids it added.

    WHY THIS EDGE EXISTS AT ALL, and why it is family-scoped rather than an effect-scoped name match:
    the module docstring, at length, with the three handoff shapes (ground effect, summoned creature,
    server spell script) and the measurements — 298 ids here, against 1,763 for a bare name match and
    547 for the effects-179/28/3 fence that the bare name match's predecessor would have grown into.
    The short version is that `SpellClassOptions.SpellClassSet` is a real relationship the client
    maintains for its own modifier system, and family 0 — where every encounter copy lives — is not a
    family but the absence of one.

    Both ends of the edge are fenced:
      * the source must be in the pool and carry a family, so nothing bridges out of family 0;
      * the candidate must carry a bucket mechanic and the SAME family, so a same-named cosmetic,
        tooltip or encounter spell is never pulled in;
      * every bridged id is returned, and the caller labels it `"source": "bridge"` in derived.json,
        calls it out in the diff and comments it in the emitted Lua, so the author prunes it
        knowingly rather than inheriting a guess.

    It is deliberately NOT deduplicated down to one id per name. A name like "Freezing Trap" covers
    several ids inside its own family — the live aura plus legacy copies — and there is no column in
    this data that reliably says which is live. Guessing (lowest id, say) is a SILENT wrong answer,
    and silent under-coverage is this design's stated failure mode (spec C4); a surplus id is a
    visible one that costs a row in the editor and never matches (defaults/Categories.lua's own
    header says exactly that about stale ids). The author prunes at the diff, which is where spec C3
    step 5 puts the judgment anyway.
    """
    by_key: dict[tuple[str, int], list[int]] = defaultdict(list)
    for spell, name in names.items():
        family = families.get(spell, NO_SPELL_FAMILY)
        if name and family and (mechanics_of(spell) & cc_mechanics):
            by_key[(name, family)].append(spell)
    bridged: set[int] = set()
    for spell in sorted(pool):
        name = names.get(spell)
        family = families.get(spell, NO_SPELL_FAMILY)
        if not name or not family:
            continue
        for candidate in by_key.get((name, family), ()):
            if candidate in pool:
                continue
            pool.add(candidate)
            bridged.add(candidate)
            # The handoff is the caster's ability, so the aura it lands is the caster's class — the
            # same reasoning as the trigger closure, and the same reason the emitted fragment groups
            # correctly instead of dumping every trap and totem under ALL.
            classes[candidate] |= classes.get(spell, set())
    return bridged


def close_over_triggers(pool: set[int], classes: dict[int, set[str]],
                        triggers: dict[int, set[int]]) -> int:
    """Grow the pool along `EffectTriggerSpell` edges until it stops growing. Returns how many
    spells the closure added.

    WHY (spec C1, and the module docstring at length): the addon filters on the AURA's id. Freezing
    Trap is cast as one spell and applies its aura as another, and so are a large number of the CC
    effects players actually care about. Without this step the derived list looks fully populated and
    never matches anything in game.

    The class set propagates across the edge — the aura a hunter's trap applies is a hunter aura,
    whatever table it happens to live in — which is what keeps the emitted fragment grouped the way
    `defaults/Categories.lua` groups things. The traversal is transitive (a trigger that itself
    triggers) and a breadth-first frontier rather than recursion, because these chains are shallow but
    the graph has cycles and Python's recursion limit is not a good place to discover that.
    """
    added = 0
    frontier = list(pool)
    while frontier:
        nxt: list[int] = []
        for spell in frontier:
            inherited = classes.get(spell)
            for triggered in triggers.get(spell, ()):
                grew = triggered not in pool
                if grew:
                    pool.add(triggered)
                    added += 1
                before = len(classes.get(triggered, ()))
                if inherited:
                    classes[triggered] |= inherited
                # Re-walk a spell only when it actually learned something: either it is new, or its
                # class set grew and that growth has to reach whatever IT triggers. Without the second
                # condition a trap's aura would keep the class it was first reached by and drop the
                # rest; without the guard as a whole, a cycle never terminates.
                if grew or len(classes.get(triggered, ())) != before:
                    nxt.append(triggered)
        frontier = nxt
    return added


def read_spell_categories(path: Path) -> tuple[dict[int, int], dict[int, int]]:
    """`SpellCategories` at base difficulty: spell -> `Mechanic`, and spell -> `DiminishType`.

    `DiminishType` is not used to bucket anything — Part A is a two-way Hard/Soft split, not the five
    DR groups (spec, "Decisions taken"). It is carried into derived.json purely as provenance, so the
    author accepting a diff can see at a glance that a spell the tool calls Hard CC is also something
    the client diminishes.
    """
    mechanics: dict[int, int] = {}
    diminish: dict[int, int] = {}
    for row in iter_csv(path):
        if not base_difficulty(row):
            continue
        spell = as_int(row.get("SpellID"))
        if not spell:
            continue
        mechanic = as_int(row.get("Mechanic"))
        if mechanic:
            mechanics[spell] = mechanic
        dim = as_int(row.get("DiminishType"))
        if dim:
            diminish[spell] = dim
    return mechanics, diminish


def read_names(path: Path) -> dict[int, str]:
    """`SpellName.ID` -> `Name_lang`. Only named spells survive into a bucket: an unnamed id is an
    internal placeholder that would show as a blank row in the General -> Spell Categories editor."""
    return {as_int(row["ID"]): (row.get("Name_lang") or "").strip() for row in iter_csv(path)}


def read_mechanic_names(path: Path) -> dict[int, str]:
    """`SpellMechanic.ID` -> `StateName_lang`, used to label matches in derived.json and to
    cross-check BUCKET_MECHANICS against the build actually being read."""
    return {as_int(row["ID"]): (row.get("StateName_lang") or "").strip() for row in iter_csv(path)}


def derive(cache: dict[str, Path]) -> dict:
    """Run the whole pipeline over a fetched cache and return the derived result.

    The return value is the shape `derived.json` is written in and the shape every consumer below
    (diff, emit, bundle, the coverage gate) reads, so there is exactly one description of what a run
    produced.
    """
    log("Building the player pool ...")
    pool, classes = build_pool(cache)
    log("  %d spells from skill lines, specializations and traits" % len(pool))

    log("Reading SpellEffect (the big one) ...")
    effect_mechanics, triggers = read_spell_effect(cache["SpellEffect"])

    spell_mechanics, diminish = read_spell_categories(cache["SpellCategories"])
    names = read_names(cache["SpellName"])
    mechanic_names = read_mechanic_names(cache["SpellMechanic"])
    families = read_spell_families(cache["SpellClassOptions"])

    def mechanics_of(spell: int) -> set[int]:
        """Every mechanic id on a spell: the spell-level one unioned with every effect-level one.

        Both levels are needed and neither subsumes the other. Verified on build 12.1.0.69875:
        Entangling Roots (339) carries Rooted at the spell level and nothing at the effect level,
        while Dragon's Breath (31661) carries Disoriented at the effect level and nothing at the
        spell level. Reading either column alone loses a whole class of CC.
        """
        mechs = set(effect_mechanics.get(spell, ()))
        spell_mechanic = spell_mechanics.get(spell)
        if spell_mechanic:
            mechs.add(spell_mechanic)
        return mechs

    cc_mechanics = set()
    for mapping in BUCKET_MECHANICS.values():
        cc_mechanics |= set(mapping)

    # STEPS 4 AND 5, ALTERNATED TO A FIXED POINT.
    #
    # Each step feeds the other. The closure walks EffectTriggerSpell, and a spell it reaches may be
    # the one whose family sibling carries the mechanic — that is exactly the Ring of Frost chain,
    # 113724 -> (trigger) 136511 -> (family bridge) 82691, which needs the closure to run before the
    # bridge. The bridge adds auras, and a bridged aura may itself trigger something further — a trap
    # whose aura refreshes a second spell — which needs the bridge to run before the closure.
    #
    # Running each exactly once would therefore make the ORDER of two steps load-bearing, and leave
    # whichever ran first holding a pool it had not finished walking. Nothing in the file said which
    # order was right, because there is no right one. Iterating until neither step adds anything
    # removes the question: the result is the same set whichever step goes first, and a future edit
    # cannot break it by reordering two lines. The loop terminates because both steps only ever ADD
    # to a pool bounded by the number of spells in the build.
    log("Closing over EffectTriggerSpell (spec C1) and bridging spell families, to a fixed point ...")
    added = 0
    bridged: set[int] = set()
    passes = 0
    while True:
        passes += 1
        grew = close_over_triggers(pool, classes, triggers)
        newly = bridge_spell_families(pool, classes, names, families, mechanics_of, cc_mechanics)
        added += grew
        bridged |= newly
        log("  pass %d: +%d triggered, +%d bridged; pool is now %d"
            % (passes, grew, len(newly), len(pool)))
        if not grew and not newly:
            break
    log("  fixed point after %d passes: +%d triggered, +%d bridged; pool is %d"
        % (passes, added, len(bridged), len(pool)))

    # Cross-check the authored bucket map against the build being read. A mechanic whose name has
    # moved is not fatal — ids are what match — but it is the loudest early warning available that
    # BUCKET_MECHANICS needs a human to look at it.
    for bucket, expected in BUCKET_MECHANICS.items():
        for mid, expected_name in expected.items():
            actual = mechanic_names.get(mid, "")
            if actual.lower() != expected_name.lower():
                log("  WARNING: %s mechanic %d is %r in this build, BUCKET_MECHANICS says %r"
                    % (bucket, mid, actual, expected_name))

    buckets: dict[str, dict[int, dict]] = {name: {} for name in BUCKET_ORDER}
    for spell in sorted(pool):
        name = names.get(spell, "")
        if not name:
            continue  # unnamed internal ids would be blank rows in the editor
        mechs = mechanics_of(spell)
        if not mechs:
            continue
        for bucket in BUCKET_ORDER:
            matched = sorted(mechs & set(BUCKET_MECHANICS[bucket]))
            if not matched:
                continue
            reached = sorted(classes.get(spell, ()))
            buckets[bucket][spell] = {
                "id": spell,
                "name": name,
                "classes": reached,
                "class": emit_class_key(reached),
                "classSource": "skillline" if reached else "unknown",
                "source": "bridge" if spell in bridged else "pool",
                "mechanics": [{"id": m, "name": mechanic_names.get(m, "?")} for m in matched],
                "diminishType": diminish.get(spell, 0),
            }
            # A spell matching mechanics in both buckets is Hard CC: losing control is the stronger
            # statement, and Part A's two rows are meant to be read as a hierarchy rather than as
            # overlapping sets. BUCKET_ORDER puts hardCC first, so breaking here is that rule.
            break
    return {
        "poolSize": len(pool),
        "triggerClosureAdded": added,
        "familyBridgeAdded": len(bridged),
        "buckets": buckets,
    }


def emit_class_key(reached: list[str]) -> str:
    """The single class key a spell is emitted under.

    One class -> that class. Several but under the threshold -> the first in emit order, so the id
    appears exactly once rather than thirteen times (the editor's grouping is cosmetic; the filter
    ignores `class` entirely, see defaults/Categories.lua's header). At or over the threshold, or
    with no class at all, -> `ALL`. See ALL_CLASS_THRESHOLD for why 7.
    """
    if not reached or len(reached) >= ALL_CLASS_THRESHOLD:
        return "ALL"
    for token in CLASS_EMIT_ORDER:
        if token in reached:
            return token
    return "ALL"


# ---------------------------------------------------------------------------
# Step 6 — the coverage gate
# ---------------------------------------------------------------------------

def check_sentinels(result: dict) -> list[str]:
    """Return the sentinels that did NOT appear in their bucket. Empty means the gate passed.

    See SENTINELS for why this exists at all. The caller exits non-zero on any miss: a run that
    cannot prove it found Hammer of Justice has no business printing a Lua fragment.
    """
    missing: list[str] = []
    for bucket in BUCKET_ORDER:
        have = {entry["name"].lower() for entry in result["buckets"][bucket].values()}
        for sentinel in SENTINELS.get(bucket, ()):
            if sentinel.lower() not in have:
                missing.append("%s: %s" % (bucket, sentinel))
    return missing


# ---------------------------------------------------------------------------
# Step 7 — diff, emit, bundle
# ---------------------------------------------------------------------------

# `key = "hardCC"` ... up to the closing `}),` of its `spells({ ... })` table. Deliberately narrow:
# the tool only ever READS this file, and a parser that guesses would be a parser that could be wrong
# about what is currently shipped, which is the one thing the diff must not be wrong about.
CATEGORY_BLOCK = re.compile(
    r"""key\s*=\s*"(?P<key>%s)".*?spells\s*=\s*spells\(\{(?P<body>.*?)\}\)""" % "|".join(BUCKET_ORDER),
    re.DOTALL,
)
CLASS_ENTRY = re.compile(r"(?P<class>[A-Z]+)\s*=\s*\{(?P<ids>[^}]*)\}", re.DOTALL)


def read_shipped(path: Path) -> dict[str, dict[int, str]]:
    """The ids `defaults/Categories.lua` currently ships per bucket, as `{id: class}`.

    A bucket the file does not have yet is an empty dict, which makes the first run's diff read as
    "everything is an addition" — which is exactly what it is (spec C3 step 5). A missing file is the
    same thing, not an error: the tool is usable before Part A lands.
    """
    shipped: dict[str, dict[int, str]] = {bucket: {} for bucket in BUCKET_ORDER}
    if not path.exists():
        return shipped
    text = path.read_text(encoding="utf-8")
    for block in CATEGORY_BLOCK.finditer(text):
        entries: dict[int, str] = {}
        for entry in CLASS_ENTRY.finditer(block.group("body")):
            for token in re.findall(r"\d+", re.sub(r"--[^\n]*", "", entry.group("ids"))):
                entries[int(token)] = entry.group("class")
        shipped[block.group("key")] = entries
    return shipped


def format_diff(result: dict, shipped: dict[str, dict[int, str]], categories_path: Path) -> str:
    """The per-bucket added / removed / moved report, as Markdown (it is both printed and written
    into the bundle's DIFF.md, and one text keeps the two from drifting).

    "Moved" is the rename-ish case this data actually produces: the id is on both sides but the class
    it groups under changed, usually because a talent moved between trees. A genuine rename — same id,
    different name — cannot be detected against the shipped file, which stores no names; it shows up
    in the derived.json of two consecutive bundles instead, which is what the bundles are for.
    """
    lines: list[str] = []
    for bucket in BUCKET_ORDER:
        derived_entries = result["buckets"][bucket]
        old = shipped.get(bucket, {})
        added = sorted(set(derived_entries) - set(old))
        removed = sorted(set(old) - set(derived_entries))
        moved = sorted(i for i in set(old) & set(derived_entries)
                       if old[i] != derived_entries[i]["class"])
        lines.append("## %s" % bucket)
        lines.append("")
        lines.append("Shipped: %d | derived: %d | added: %d | removed: %d | regrouped: %d"
                     % (len(old), len(derived_entries), len(added), len(removed), len(moved)))
        lines.append("")
        if added:
            lines.append("### Added")
            lines.append("")
            for spell in added:
                entry = derived_entries[spell]
                # A bridged id is a name match inside a shared spell family, which is weaker than
                # a directed edge (see bridge_spell_families), so it says so in the one place the
                # author decides whether to keep it.
                lines.append("- `%d` %s — %s (%s)%s" % (
                    spell, entry["name"], entry["class"],
                    ", ".join(m["name"] for m in entry["mechanics"]),
                    " **[family bridge — name match inside the family, check it]**"
                    if entry["source"] == "bridge" else ""))
            lines.append("")
        if removed:
            lines.append("### Removed — shipped today, NOT derived from this build")
            lines.append("")
            lines.append("Each of these is a judgment call, not an automatic deletion: a CC with no")
            lines.append("mechanic flag is invisible to this tool (spec C7).")
            lines.append("")
            for spell in removed:
                lines.append("- `%d` — %s" % (spell, old[spell]))
            lines.append("")
        if moved:
            lines.append("### Regrouped — same id, different class key")
            lines.append("")
            for spell in moved:
                lines.append("- `%d` %s — %s -> %s"
                             % (spell, derived_entries[spell]["name"], old[spell],
                                derived_entries[spell]["class"]))
            lines.append("")
        if not (added or removed or moved):
            lines.append("No change.")
            lines.append("")
    lines.append("Compared against `%s`. This tool never writes that file." % categories_path)
    lines.append("")
    return "\n".join(lines)


def format_lua(result: dict, build: str, date: str) -> str:
    """The paste-ready fragment, in `defaults/Categories.lua`'s own shape.

    One id per line with the spell name as a trailing comment: the existing spell lists are short
    enough to sit on one line, but a hard-CC list of eighty ids is not reviewable that way, and a
    reviewer accepting a diff has to be able to read what each id IS. The `spells({ CLASS = { ... } })`
    call, the class key order and the indentation are the file's.

    The provenance comment above each block is spec C6: a stale list should be visible in the file
    itself, not only in a bundle nobody opens.

    WHY THE BRIDGED IDS SIT IN THEIR OWN RUN INSIDE EACH CLASS. The derived set is majority
    name-bridged (138 of 215 hardCC, 160 of 212 softCC on build 12.1.0.69875) and the bridge is by
    design a weaker edge than the mechanic graph: it matches on an exact name inside a shared spell
    family, so it drags in rank and encounter variants — twenty-one ids named Polymorph, forty-three
    named Mind Flay. That is the design contract (see the family-bridge note at the top of this file,
    spec C3 step 5), not a defect, and the tool must not quietly drop any of them: the author decides
    what to cut, at the diff, with the names in front of them.

    What the tool CAN do is make that decision cheap. Each class key emits the directly-derived ids
    first, then a `-- family bridge` marker, then the bridged ones, so the block a reviewer can
    accept wholesale is physically separate from the block they have to read line by line, and a
    run of twenty near-identical names is obviously one family rather than twenty findings. The
    per-block header carries the same split as a count, so the size of the reading job is known
    before the reading starts. Every id still ships; only the order and the labelling changed.
    """
    out: list[str] = []
    for bucket in BUCKET_ORDER:
        entries = result["buckets"][bucket]
        by_class: dict[str, list[dict]] = defaultdict(list)
        for entry in entries.values():
            by_class[entry["class"]].append(entry)
        bridged = sum(1 for entry in entries.values() if entry["source"] == "bridge")
        # The FIRST header line answers "which block is this, and how big is the reading job?" on
        # its own — title, category key, and the derived/bridged split — so the lines under it are
        # only ever elaboration. See BUCKET_TITLES.
        out.append("        -- ===== %s — category key `%s`: %d ids = %d derived + %d family-bridged ====="
                   % (BUCKET_TITLES[bucket], bucket, len(entries), len(entries) - bridged, bridged))
        out.append("        -- Derived by tools/spell-research/research.py from build %s on %s"
                   % (build, date))
        out.append("        -- Derived = the mechanic graph named the spell. Family-bridged = an exact")
        out.append("        -- name match inside the spell family, which also catches rank and encounter")
        out.append("        -- variants: read those, keep what a player would name, cut the rest.")
        out.append("        -- Re-derive with --diff and accept the changes by hand.")
        out.append("        spells = spells({")
        for token in CLASS_EMIT_ORDER:
            rows = sorted(by_class.get(token, []), key=lambda e: e["name"].lower())
            if not rows:
                continue
            direct = [entry for entry in rows if entry["source"] != "bridge"]
            bridge_rows = [entry for entry in rows if entry["source"] == "bridge"]
            out.append("            %-11s = {  -- %d derived, %d bridged"
                       % (token, len(direct), len(bridge_rows)))
            # The id column is padded to the widest id in THIS class block — both runs share one
            # width — so the `-- Name` comments line up: ids run from three digits to seven in the
            # same list, and an unaligned column is unreadable at eighty rows. `defaults/Categories.lua`
            # aligns its own columns the same way (see the one-line dispel categories at the bottom
            # of Cat.HARMFUL). The width is taken over `rows` rather than per run so the two runs do
            # not sit at two different indents inside one class key.
            width = max(len(str(entry["id"])) for entry in rows)
            for entry in direct:
                out.append("                %s, -- %s" % (str(entry["id"]).rjust(width), entry["name"]))
            if bridge_rows:
                # The marker repeats per class key rather than being stated once per block because
                # the author reads these one class at a time, and a rule stated eighty lines above
                # the ids it governs is a rule nobody applies.
                out.append("                -- family bridge (name match inside the family) — verify:")
                for entry in bridge_rows:
                    out.append("                %s, -- %s  (family bridge)"
                               % (str(entry["id"]).rjust(width), entry["name"]))
            out.append("            },")
        out.append("        }),")
        out.append("")
    return "\n".join(out)


def write_repo_text(path: Path, text: str) -> None:
    """Write a text file into the bundle with CRLF terminators.

    `.gitattributes` pins this repo's working tree to CRLF (`* text=auto eol=crlf`, line-endings-§2)
    because it is client-bound, and `tests/_kit/test_eol.lua` fails the whole suite when a tracked file
    disagrees with `git check-attr eol`. A generator writing "\n" through `Path.write_text` produces
    exactly that disagreement: the index is right, the disk is wrong, `git diff` shows nothing, and
    `git add --renormalize` does not fix it — the file has to be deleted and checked out again.
    Since a bundle is committed the moment it is produced, the generator writes what the repo
    expects instead of leaving the author a green gate that fails on a file they did not edit.

    Bytes rather than `newline="\r\n"` so this does not depend on a Python version.
    """
    path.write_bytes(text.replace("\r\n", "\n").replace("\n", "\r\n").encode("utf-8"))


def write_bundle(bundle_dir: Path, date: str, build: str, cache: dict[str, Path],
                 result: dict, diff_text: str, fetched_at: str) -> None:
    """Freeze the run into `docs/spell-research/<date>/` (spec C5).

    Same convention as `docs/audits/`, `docs/reviews/` and `docs/automated-tests/`: a dated directory
    that is never edited afterwards. `docs` is already `.pkgmeta`-ignored, so none of it reaches a
    player. The raw exports are gzipped (~10-15 MB a run) so that a PAST run stays replayable offline
    even though a new one needs wago.tools.

    The date is an argument rather than `datetime.now()` on purpose: the caller decides what a bundle
    is called, and a run that straddles midnight, or a re-run of yesterday's numbers, must not
    silently land in a different directory than the one it was asked for.
    """
    bundle_dir.mkdir(parents=True, exist_ok=True)
    raw_dir = bundle_dir / "raw"
    raw_dir.mkdir(exist_ok=True)
    for table, _why in TABLES:
        source = cache[table]
        target = raw_dir / ("%s.csv.gz" % table)
        if source.suffix == ".gz":
            # Replaying one bundle into another (`--replay OLD --bundle NEW`): the member is already
            # gzipped, so it is copied byte for byte rather than decompressed and recompressed. That
            # keeps the new bundle's raw/ bit-identical to the old one's, which is the property that
            # makes two bundles comparable at all (see the --diff note above: a diff between bundles
            # should be a diff of the game, never of how the bytes were re-packed).
            if source.resolve() != target.resolve():
                shutil.copyfile(source, target)
        else:
            with source.open("rb") as src, gzip.open(target, "wb", compresslevel=9) as dst:
                shutil.copyfileobj(src, dst, DOWNLOAD_CHUNK)
        log("  bundled %-22s %.1f MB gzipped" % (table, target.stat().st_size / 1e6))

    sources = [
        "# Sources — spell research, %s" % date,
        "",
        "Generated by `tools/spell-research/research.py`. Frozen: this directory is never edited",
        "after the run (the `docs/audits/` convention).",
        "",
        "| Field | Value |",
        "| --- | --- |",
        "| Build | `%s` |" % build,
        "| Fetched | %s |" % fetched_at,
        "| Builds API | <%s> |" % BUILDS_URL,
        "| Player pool | %d spells |" % result["poolSize"],
        "| Added by the EffectTriggerSpell closure | %d (spec C1) |" % result["triggerClosureAdded"],
        "| Added by the spell-family name bridge | %d |" % result["familyBridgeAdded"],
        "",
        "## Tables",
        "",
        "| Table | Why | URL |",
        "| --- | --- | --- |",
    ]
    for table, why in TABLES:
        sources.append("| `%s` | %s | <%s> |" % (table, why, CSV_URL.format(table=table, build=build)))
    sources += [
        "",
        "The gzipped exports are in `raw/`. This run replays offline from them with",
        "`--replay docs/spell-research/%s`; a NEW run needs network access to wago.tools" % date,
        "(spec C7).",
        "",
        "## Derived counts",
        "",
        "| Bucket | Spells |",
        "| --- | --- |",
    ]
    sources[-2] = "| Bucket | Spells | Of those, bridged |"
    sources[-1] = "| --- | --- | --- |"
    for bucket in BUCKET_ORDER:
        entries = result["buckets"][bucket]
        bridged = sum(1 for e in entries.values() if e["source"] == "bridge")
        sources.append("| `%s` | %d | %d |" % (bucket, len(entries), bridged))
    sources.append("")
    write_repo_text(bundle_dir / "SOURCES.md", "\n".join(sources))

    payload = {
        "build": build,
        "date": date,
        "fetchedAt": fetched_at,
        "poolSize": result["poolSize"],
        "triggerClosureAdded": result["triggerClosureAdded"],
        "familyBridgeAdded": result["familyBridgeAdded"],
        "bucketMechanics": {b: {str(k): v for k, v in m.items()}
                            for b, m in BUCKET_MECHANICS.items()},
        "buckets": {b: [result["buckets"][b][i] for i in sorted(result["buckets"][b])]
                    for b in BUCKET_ORDER},
    }
    write_repo_text(bundle_dir / "derived.json",
                    json.dumps(payload, indent=2, ensure_ascii=False) + "\n")

    write_repo_text(bundle_dir / "DIFF.md",
                    "# Diff — spell research, %s (build %s)\n\n%s" % (date, build, diff_text))
    log("Bundle written to %s" % bundle_dir)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def repo_root() -> Path:
    """The addon root, from this file's own location (`<root>/tools/spell-research/`)."""
    return Path(__file__).resolve().parent.parent.parent


DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


# ---------------------------------------------------------------------------
# The cast -> aura table (issue #15)
# ---------------------------------------------------------------------------
#
# A DIFFERENT QUESTION FROM THE REST OF THIS FILE, sharing its tables. Everything above derives
# which spells belong in a CC bucket. This derives which spells a player can type into the editor
# and get an id that never matches, plus what the aura actually is when the data can say.
#
# THE PROBLEM. Aura Master filters on the id the AURA carries. Many abilities are cast as one id
# and land as another, and the editor resolves a typed NAME through the client, which answers the
# id in the spellbook -- the CAST one. The entry then draws perfectly, with the right icon and the
# right name, and matches nothing. Nothing in the client's Lua can tell the panel otherwise
# (docs/scope.md), so the answer has to be carried.
#
# THE RULE FOR "CAN NEVER MATCH": a spell with no APPLY_AURA effect of its own. Effect 6 is
# SPELL_EFFECT_APPLY_AURA, and a spell that has one puts an aura carrying its own id on something.
# A spell with none does not, whatever else it does.
APPLY_AURA_EFFECT = 6

# How far to walk EffectTriggerSpell looking for something that applies an aura. Shallow on purpose:
# these chains are a cast triggering its aura, not a graph to explore, and a long walk starts
# collecting the unrelated. close_over_triggers above walks to a fixed point because it is growing a
# POOL; this is answering "what does this one cast land", which is a different question.
TRIGGER_DEPTH = 3


def read_aura_appliers(path: Path) -> set[int]:
    """Every spell with an APPLY_AURA effect of its own, i.e. every id that can BE an aura.

    Its own streaming pass over SpellEffect rather than a third return from read_spell_effect,
    because it is wanted by one caller for one mode and that function is already doing two jobs for
    the main pipeline. The cost is one more read of the big table in a mode that is not the default.
    """
    out: set[int] = set()
    for row in iter_csv(path):
        if not base_difficulty(row):
            continue
        if as_int(row.get("Effect")) == APPLY_AURA_EFFECT:
            spell = as_int(row.get("SpellID"))
            if spell:
                out.add(spell)
    return out


def triggered_auras(spell: int, triggers: dict[int, set[int]], appliers: set[int]) -> list[int]:
    """Aura-applying spells reachable from `spell` along EffectTriggerSpell, breadth first.

    Stops at the first depth that finds any: the nearest aura is the one the cast applies, and
    anything past it is what THAT aura goes on to trigger.
    """
    seen = {spell}
    frontier = [spell]
    for _ in range(TRIGGER_DEPTH):
        found, nxt = set(), []
        for node in frontier:
            for edge in triggers.get(node, ()):
                if edge in seen:
                    continue
                seen.add(edge)
                if edge in appliers:
                    found.add(edge)
                else:
                    nxt.append(edge)
        if found:
            return sorted(found)
        frontier = nxt
        if not frontier:
            break
    return []


def derive_cast_aura(cache: dict[str, Path]) -> dict:
    """The cast -> aura table: every player-castable id that can never match, with what it means.

    Only ids the panel can SAY SOMETHING USEFUL ABOUT are emitted -- a spell that applies no aura
    and has no candidate aura either is left out (the owner's coverage decision, 2026-09-21). Such a
    spell is overwhelmingly a passive talent or a proc nobody types into an aura filter, and
    carrying all of them would multiply the shipped table roughly sevenfold to warn about ids that
    are never entered.

    Two ways to find the aura, in this order:

      a. THE TRIGGER EDGE, `EffectTriggerSpell`. Real data, and the Freezing Trap shape: the cast's
         effect triggers a second spell and it is THAT spell's aura which lands.
      b. THE SAME NAME. Many links are server-side script with NO row behind them at all -- Renewing
         Mist is the case that proved it, whose only SpellEffect row is a dummy with no trigger --
         and for those the only thing the data still agrees on is the name. An aura-applying spell
         called exactly what the cast is called is a candidate, never a conclusion.

    A candidate set of exactly one is a REWRITE; anything else is a CHOICE the panel offers and
    never resolves. The class-family fence (SpellClassOptions.SpellClassSet, the same fence the
    bucket bridge rests on) is applied to the name candidates first, because a name is shared across
    the whole game -- six unrelated spells called "Fear" -- and the family narrows it to the one
    class's. It narrows; it does not always settle. Renewing Mist has seven same-named auras and
    five survive the fence, so it stays a choice.
    """
    log("Building the player pool ...")
    pool, _classes = build_pool(cache)
    log("  %d player-castable spells" % len(pool))

    log("Reading SpellEffect for APPLY_AURA ...")
    appliers = read_aura_appliers(cache["SpellEffect"])
    log("  %d spells apply an aura of their own id" % len(appliers))

    log("Reading SpellEffect for trigger edges ...")
    _mechanics, triggers = read_spell_effect(cache["SpellEffect"])

    names = read_names(cache["SpellName"])
    families = read_spell_families(cache["SpellClassOptions"])

    by_name: dict[str, list[int]] = defaultdict(list)
    for spell, name in names.items():
        if name and spell in appliers:
            by_name[name].append(spell)

    entries: dict[int, dict] = {}
    dead_no_candidate = 0
    for spell in sorted(pool):
        if spell in appliers:
            continue                      # it applies its own aura; nothing to say
        name = names.get(spell, "")
        found = triggered_auras(spell, triggers, appliers)
        source = "trigger"
        if not found:
            siblings = [s for s in by_name.get(name, ()) if s != spell]
            family = families.get(spell)
            fenced = [s for s in siblings if family and families.get(s) == family]
            found = sorted(fenced or siblings)
            source = "name"
        if not found:
            dead_no_candidate += 1
            continue
        # ONLY A TRIGGER EDGE MAY BECOME A REWRITE. A name match is a candidate and never a
        # conclusion -- the docstring above says so and the first cut of this function did not
        # honour it, which produced 215 confident rewrites of spells that apply no aura at all:
        # Purge to 33625, Remove Curse to 147635, Pick Pocket to 319470. Each is a DIFFERENT
        # spell that happens to reuse the name, and storing one would be the exact silent wrong
        # id this whole table exists to prevent. A lone name candidate is still offered as a
        # choice, because the WARNING that the typed id can never match is true either way.
        unique = found[0] if (len(found) == 1 and source == "trigger") else None
        entries[spell] = {"name": name, "auras": found, "source": source, "unique": unique}

    unique = sum(1 for e in entries.values() if e["unique"])
    by_name_only = sum(1 for e in entries.values() if e["source"] == "name")
    log("Cast -> aura: %d entries (%d rewritten from a trigger edge, %d offered as a choice, "
        "%d of those found by name alone); %d more apply no aura and have no candidate, and are "
        "not emitted"
        % (len(entries), unique, len(entries) - unique, by_name_only, dead_no_candidate))
    return {"entries": entries, "pool": len(pool), "appliers": len(appliers),
            "dead_no_candidate": dead_no_candidate}


def format_cast_aura_lua(result: dict, build: str, date: str) -> str:
    """`defaults/CastToAura.lua`, whole. Written by this tool and never edited by hand."""
    entries = result["entries"]
    unique = {s: e["unique"] for s, e in entries.items() if e["unique"]}
    choices = {s: e["auras"] for s, e in entries.items() if not e["unique"]}
    out: list[str] = []
    w = out.append
    w("local _, NS = ...")
    w("")
    w("-- defaults/CastToAura.lua -- GENERATED. Do not edit by hand.")
    w("--")
    w("--   Build %s, derived %s by tools/spell-research/research.py --emit-cast-aura." % (build, date))
    w("--   Re-run the tool to refresh it; the bundle it came from is under docs/spell-research/.")
    w("--")
    w("-- WHAT THIS IS. Aura Master filters on the id an AURA carries, and many abilities are CAST as")
    w("-- one id and land as another. A player who types a spell name gets the id the client knows --")
    w("-- the cast one -- and the entry then draws perfectly and matches nothing (issue #15). Nothing")
    w("-- in the client's Lua answers the mapping (docs/scope.md), so it is carried here.")
    w("--")
    w("-- Only ids the panel can say something USEFUL about are here. A spell that applies no aura and")
    w("-- has no candidate aura either is left out: %d such ids exist in the player-castable pool and" % result["dead_no_candidate"])
    w("-- are overwhelmingly passives and procs nobody types into an aura filter.")
    w("--")
    w("-- REWRITES: the data resolves exactly one aura, so the panel stores that instead and says so.")
    w("-- CHOICES:  more than one candidate survives; the panel lists them and never guesses.")
    w("--")
    w("-- Derived over %d player-castable spells. %d ids in the whole game apply an aura of their" % (result["pool"], result["appliers"]))
    w("-- own -- that second number is the game, not this pool, and is here only to say what the")
    w("-- membership test was run against.")
    w("")
    w("NS.CastToAura = NS.CastToAura or {}")
    w("")
    w("-- [cast id] = the one aura it applies.")
    w("NS.CastToAura.REWRITE = {")
    for spell in sorted(unique):
        w("    [%d] = %d,%s" % (spell, unique[spell], _trail(entries[spell], unique[spell])))
    w("}")
    w("")
    w("-- [cast id] = { every aura id that could be the one }, ascending.")
    w("NS.CastToAura.CHOICES = {")
    for spell in sorted(choices):
        ids = ", ".join(str(i) for i in choices[spell])
        w("    [%d] = { %s },%s" % (spell, ids, _trail(entries[spell], None)))
    w("}")
    # A trailing terminator and no more. The caller writes this to stdout with sys.stdout.write
    # rather than print(), because print() would append a bare LF to a CRLF file and leave it
    # mixed -- which tests/_kit's eol suite reads out of the working tree and fails on.
    return NEWLINE.join(out) + NEWLINE


def _trail(entry: dict, target: int | None) -> str:
    """The trailing `-- Name` comment on an emitted row, naming how the answer was reached."""
    name = entry.get("name") or "?"
    how = "trigger" if entry.get("source") == "trigger" else "name"
    if target is not None:
        return "   -- %s (%s)" % (name, how)
    n = len(entry.get("auras") or ())
    return "   -- %s (%s, %d candidate%s)" % (name, how, n, "" if n == 1 else "s")


def parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="research.py",
        description="Derive AuraMaster's Hard CC / Soft CC spell lists from Blizzard's DB2 exports.",
        epilog="This tool never writes defaults/Categories.lua. See tools/spell-research/README.md.",
    )
    parser.add_argument("--build", help="pin a build (e.g. 12.1.0.69875); default is live retail")
    parser.add_argument("--cache-dir", type=Path,
                        default=Path(__file__).resolve().parent / ".cache",
                        help="where the CSV exports are cached; outside git by default")
    parser.add_argument("--refresh", action="store_true",
                        help="re-download every table even when it is cached")
    parser.add_argument("--replay", type=Path, metavar="DIR",
                        help="re-derive offline from a past bundle's raw/*.csv.gz, e.g. "
                             "docs/spell-research/2026-09-20 (no network, no cache)")
    parser.add_argument("--categories", type=Path, default=repo_root() / "defaults" / "Categories.lua",
                        help="the defaults file to diff against (read-only, always)")
    parser.add_argument("--diff", action="store_true",
                        help="report added / removed / regrouped against the shipped lists (default)")
    parser.add_argument("--emit", action="store_true",
                        help="print a paste-ready Lua fragment on stdout")
    parser.add_argument("--emit-cast-aura", action="store_true",
                        help="print defaults/CastToAura.lua on stdout (issue #15). A different "
                             "question from --emit over the same tables: which player-castable ids "
                             "apply no aura of their own, and what aura they actually land")
    parser.add_argument("--bundle", type=Path, metavar="DIR",
                        help="freeze the run into DIR, e.g. docs/spell-research/2026-09-20")
    parser.add_argument("--date", metavar="YYYY-MM-DD",
                        help="the run's date; defaults to --bundle's directory name. Required with "
                             "--emit, which never invents one from the clock (spec C6)")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if not (args.diff or args.emit or args.emit_cast_aura or args.bundle):
        args.diff = True  # a bare run reports; it never emits something that looks authoritative

    date = args.date
    if date and not DATE_RE.match(date):
        raise SystemExit("--date must be YYYY-MM-DD; got %r." % date)
    if args.bundle and not date:
        candidate = args.bundle.name
        if not DATE_RE.match(candidate):
            raise SystemExit("--bundle's directory name is not a YYYY-MM-DD date; pass --date.")
        date = candidate
    if (args.emit or args.emit_cast_aura) and not date:
        # NO `datetime.now()` FALLBACK, AND THIS IS THE REASON. The date reaches the shipped tree:
        # it is spec C6's provenance, printed in the comment above each emitted block and pasted
        # verbatim into defaults/Categories.lua, where it is read afterwards as "the day this list
        # was derived". A clock reading is not that. It is the day somebody happened to run --emit,
        # which may be weeks after the bundle the ids actually came from, and once pasted there is
        # nothing left to contradict it — the file would carry a provenance date belonging to no
        # recorded run, and the bundle it should point at would be unfindable.
        #
        # So the date is always the caller's, and the two ways to give it both tie the fragment to
        # something real: --bundle names the directory this very run freezes, and --date names a
        # bundle already on disk that the fragment is being re-emitted from.
        raise SystemExit(
            "--emit needs a date for its provenance comment (spec C6), and this tool will not\n"
            "invent one from the clock: the comment is pasted into defaults/Categories.lua and has\n"
            "to name a run that exists. Pass --date YYYY-MM-DD naming the bundle these ids came\n"
            "from (see docs/spell-research/), or --bundle DIR to freeze this run and use its date.")

    if args.replay:
        # REPLAY RESOLVES ITS BUILD FROM THE BUNDLE, NOT FROM THE BUILDS API. `resolve_build` is a
        # network call, and a replay whose whole point is running without network must not make one;
        # worse, the live build moves, so asking the API during a replay would stamp today's build
        # number onto numbers derived from last month's bytes. The bundle's own derived.json records
        # the build it read, and that is the only honest answer. `--build` still wins when the caller
        # insists, for the case of a hand-assembled bundle with no derived.json.
        build, fetched_at = replay_provenance(args.replay, args.build)
        log("Replaying %d tables from %s (build %s, fetched %s) ..."
            % (len(TABLES), args.replay, build, fetched_at))
    else:
        build = resolve_build(args.build)
        log("Fetching %d tables for build %s ..." % (len(TABLES), build))
        fetched_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    cache = {table: fetch_table(table, build, args.cache_dir, args.refresh, args.replay)
             for table, _why in TABLES}

    if args.emit_cast_aura:
        # ITS OWN PIPELINE, AND IT RETURNS HERE. The CC derivation below answers a different
        # question and its coverage gate is about CC sentinels, so running it would gate this
        # emit on something that has nothing to do with it.
        sys.stdout.write(format_cast_aura_lua(derive_cast_aura(cache), build, date))
        return 0

    result = derive(cache)
    for bucket in BUCKET_ORDER:
        entries = result["buckets"][bucket]
        bridged = sum(1 for e in entries.values() if e["source"] == "bridge")
        log("Derived %s: %d spells (%d from the mechanic graph, %d bridged by name)"
            % (bucket, len(entries), len(entries) - bridged, bridged))

    missing = check_sentinels(result)
    if missing:
        log("")
        log("COVERAGE GATE FAILED — %d sentinel(s) missing from the derived set:" % len(missing))
        for item in missing:
            log("  - %s" % item)
        log("")
        log("A missing sentinel means the pool or the bucket map lost coverage, NOT that the spell")
        log("stopped existing. Do not ship the derived list until this passes (spec C4).")
        return 1
    log("Coverage gate: PASS (%d sentinels)" % sum(len(s) for s in SENTINELS.values()))

    shipped = read_shipped(args.categories)
    diff_text = format_diff(result, shipped, args.categories)
    if args.diff:
        print(diff_text)
    if args.emit:
        print(format_lua(result, build, date))
    if args.bundle:
        write_bundle(args.bundle, date, build, cache, result, diff_text, fetched_at)
    return 0


if __name__ == "__main__":
    sys.exit(main())
