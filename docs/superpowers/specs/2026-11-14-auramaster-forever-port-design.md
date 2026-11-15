# Aura Master on WoW Forever: design

Date: 2026-11-14. Branch `feat/2026-11-14-forever-port` (AuraMaster); `feat/2026-11-14-auramaster-forever-port`
(WowAddonStandards, the roster row). Inputs: the collection's port bundles
(`Ka0sAddonsCommonTasks/docs/2026-11-07-WOW_FOREVER_PORT/`, `…_STEP5/00_CLASSIFICATION.md`, which ranks Aura Master
"high: the engine ports, the data does not"), the standard's `clients.md` (clients-§1..§6) and `skinning.md` §2, and
the measurements below. **(Claude's call)** marks a decision made while designing, under the owner's instruction to
decide and ask only when necessary.

## 1. Owner rulings (2026-11-14)

1. **Seed source: derive everything from Forever's DB2.** No combat logs exist yet. The three CC lists are derived by
   mechanic, as on Retail. The other spell categories map each Retail entry's spell *name* to the same class's Forever
   spell (every rank), plus DB2 aura-effect candidates for vanilla-only spells. CastToAura is regenerated from the
   Forever build.
2. **Claude decides** every membership call and records the reasoning in the bundle. There is no review sheet, and
   the owner checks the result only in game.
3. **Runes are excluded.** The `Engraving` (2851) and `Runes` (2853) skill lines stay out of the Forever player pool.
4. **Gate off anything empty.** A category with nothing to offer on Forever does not exist there (clients-§4: absent,
   not greyed out).
5. **Combat-log follow-up** is GitHub issue #26: re-run `logs.py` from Forever logs after max-level dungeons and raids.

## 2. Measurements (2026-11-14)

- **wago.tools serves Forever.** `https://wago.tools/api/builds` key `wowf`, newest `1.60.1.70938`. Every table
  `research.py` reads exports for that build except **`SpecializationSpells`** and **`TraitTreeLoadout`** (HTTP 400,
  "Table not found"). Forever has `Talent` (ClassID, `SpellRank_0..8`) and `TalentTab` instead.
- **Forever's class shape.** `ChrSpecialization` has one row per class (Mage 1482 … Warrior 1491; 1493 is the pet
  default). Nine classes, no Death Knight, Monk, Demon Hunter or Evoker. The class skill lines are vanilla's talent-tree
  lines (Arms 26, Fury 256, Protection 257, …), plus pet lines and the rune lines.
- **Ranks are separate ids.** Polymorph is 118, 12824, 12825, 12826 (+ 28271, 28272 for the Turtle and Pig variants)
  in `SkillLineAbility` with `SupercedesSpell = 0`, so ranks link by **same name within the class**, not by a column.
  An aura filter matches one id, so **every rank ships**.
- **The aura API is the same.** Gethe/wow-ui-source `forever` 1.60.1 (70938) against `live` 12.1.5 (70783):
  `Blizzard_AuraContainer` is byte-identical, `AuraContainerShared`/`AuraContainerUtil`/`UnitAuraShared` docs are
  identical, and `UnitAuraDocumentation` differs only by Forever's "linked rank spell" notes on the group-buff lists.
  The filter tokens and flags (`BIG_DEFENSIVE`, `IMPORTANT`, `CROWD_CONTROL`, `isBossAura`, …) are engine strings the
  docs do not list, so whether one ever matches on Forever is **measurable only in game**.
- **`BuffFrame` and `DebuffFrame` exist on Forever** (`Blizzard_BuffFrame/BuffFrame.xml`), so General's
  "hide Blizzard buffs/debuffs" ports. The two clients' `BuffFrame.lua` differ, so smoke checks it.
- **The engine is client-light.** Shipping code calls no spec, name, strata, bank or group-finder API.
  `GetSpellInfo` already goes through `NS.Compat`. Both kit profiles pass today (2358 / 0).

## 3. Design

### 3.1 Client seam (clients-§3)

`core/Compat.lua` routes `IsForever`, `IsRetail`, `ClientKey` and `ForClient` from `LibKa0s-Compat-1.0`, with the
library-absent stand-in answering Retail. No other file reads `WOW_PROJECT_*`.

### 3.2 Default skin per client (skinning-§2)

`NS.DEFAULT_SKIN = Skin:DefaultSkin()` is read once in `core/SkinSetup.lua`, falling back to `"ka0s"` without the
library. `defaults/Profile.lua`'s `skin.skin` and every stand-in fallback name it; the literal `"ka0s"` stays only as
`source`.

### 3.3 Per-client seed lists (clients-§5)

- **Retail's lists do not move.** They stay inline in `defaults/Categories.lua`, where `logs.py apply/ingest` and
  `research.py --check-shipped` already read and write them. This keeps the Retail list byte-identical and the
  Retail tooling working. **(Claude's call.)**
- **Forever's lists are generated** into `defaults/Categories_Forever*.lua`, loaded **before**
  `defaults/Categories.lua`. They publish `NS.CategorySeedsForever = { [categoryKey] = { CLASS = { ids… } } }` and never
  touch `Cat`. The emitter splits them by category boundary so that no file exceeds 1400 lines (the 1500 cap minus
  headroom).
- **Picked once.** `defaults/Categories.lua` reads `local FOREVER_SEEDS = NS.Compat.ClientKey() == "forever" and
  NS.CategorySeedsForever or nil` once at file load. Each `spells`-kind definition's list goes through one helper,
  `seeded(key, retailList)`, which answers `spells(FOREVER_SEEDS[key])` on Forever and `spells(retailList)` on
  Retail. No consumer of `Cat` asks which client it is on.
- **CastToAura** keeps the same shape. `defaults/CastToAura.lua` (Retail, generated) and
  `defaults/CastToAura_Forever.lua` (generated) each publish a client table; a short selector at the end of the
  second file sets `NS.CastToAura` from `ClientKey()` once. `modules/CastAura.lua` is unchanged.

### 3.4 Gating (clients-§4, owner ruling 4)

- A definition may carry `clients = { "retail" }`. `defaults/Categories.lua` builds `Cat.HELPFUL` and `Cat.HARMFUL`
  through `NS.Compat.ForClient(def.clients)`, so a gated definition **never enters the lists**: not the Filters grid,
  not the General > Spell categories editor, not `DefaultStates`, not the schema rows, not the compiler.
- **A `spells` category whose Forever list is empty is gated `retail`.** The generator writes the set of empty keys
  as `NS.CategorySeedsForever.EMPTY`, and the gate reads that one fact. So a re-run that fills a category ungates it
  with no code change. **(Claude's call:** a hand-written `clients` field would drift from the data.)
- **Token and flag categories stay on both clients.** The API is identical (§2), and whether a token matches anything
  on Forever cannot be measured offline. Each gets a Forever smoke check. A token the owner finds never matches is
  gated `retail` as a follow-up with that smoke result as evidence. **(Claude's call,** within ruling 4: "empty" is
  decided by evidence, and for tokens the evidence is in game.)
- `weaponEnchants` (kind `enchant`) and both `uncategorized` rows serve both clients. Forever has temporary weapon
  enchants (oils, stones), as ConsumableMaster's port measured.
- Profile data for a key absent on the running client (a profile copied from the other client by hand; saved
  variables live per client folder) is tolerated, never read as a category and never a crash. The stored state is
  kept, not dropped: its Show/Hide state and spell edits stay in the profile and are never read as a category
  (amended 2026-11-14 to match the implementation, `tests/test_categories_clients.lua` "a gated key in a stored
  profile is inert"), and that is recorded in `docs/known-limitations.md`.

### 3.5 Forever derivation (tools/spell-research)

- `research.py --client retail|forever` (default `retail`, so every existing command is unchanged). The client picks
  the wago product key (`wow` / `wowf`), the table set and the pool builder. The cache and bundles are keyed by build,
  so the two clients never mix.
- **The Forever pool:** `SkillLineAbility` rows by class mask or class skill line (rune lines 2851 and 2853 excluded;
  pet lines excluded, as on Retail), plus `Talent.SpellRank_0..8` by `ClassID`. Then the existing trigger closure and
  family bridge, then the **rank closure**: every spell with the same name and the same class as a pool spell joins
  it. Class keys are the nine Forever class tokens.
- **The CC buckets** use the existing mechanic map unchanged. The coverage gate gets **Forever sentinels**, chosen from
  the game: Polymorph 118, Hammer of Justice 853, Fear 5782, Frost Nova 122, Entangling Roots 339, Hamstring 1715 and
  Kidney Shot 408 must derive.
- **The other spell categories:** `tools/spell-research/forever.py` maps each Retail entry (`Categories.lua` class
  tables, read by the existing `sid_db2` reader) by `SpellName` to the same class's Forever spells, with every rank,
  following trigger and CastToAura edges to the aura id. It adds DB2 candidates per category from aura effect types:
  shapeshift/stance (`SPELL_AURA_MOD_SHAPESHIFT` 36) for Stances, raid/party buffs for Group buffs, damage-taken
  reduction/immunity/absorb on self for Defensives, movement speed for Movement, racial skill lines for Racials, and
  so on. The map is spelled out in the tool.
- **Rulings are data.** `tools/spell-research/forever_rulings.json` holds Claude's accept/reject per candidate, with a
  one-line reason. The emitter reads it, so a re-run reproduces the shipped lists exactly, and a new candidate is
  reported as unruled and is never shipped silently. `forever.py` never edits `defaults/Categories.lua`.
- **The bundle** `docs/spell-research/2026-11-14-forever/` holds the raw `*.csv.gz`, `SOURCES.md`, `derived.json`,
  `RULINGS.md` (every candidate, its ruling and its reason) and `ANALYSIS.md` (written by hand). `--replay` re-derives
  it offline.

### 3.6 Port surface (wave pattern)

- The TOC becomes `## Interface: 120105, 16001`. That arms the kit's Forever missing-globals suite.
- The README badge and opening sentence become "Supports Retail and WoW Forever." and the test badge matches.
- `DEPENDENCIES.md` names both clients.
- `docs/ARCHITECTURE.md` gains the per-client feature table: the categories gated by the Forever seed data, and the
  default skin.
- `CLAUDE.md` and `docs/testing.md` run both profiles in the green gate.
- `docs/smoke-tests.md` gains a WoW Forever theme.
- `docs/test-cases.md` is regenerated.
- `docs/known-limitations.md` gains the offline-seed limitation (#26), the unmeasured tokens and the cross-client
  profile copy.
- `tools/spell-research/README.md` gains a Forever section.
- The roster row flips to `Retail · Forever` (clients-§2).

## 4. Non-goals

No version bump, tag, release or merge without the owner's go-ahead. `logs.py` does not learn Forever in this run
(#26). Retail's lists, CastToAura and behavior are unchanged. No LibKa0s adoption beyond what the port needs.
