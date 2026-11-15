# Aura Master on WoW Forever: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Aura Master serves Retail and WoW Forever from one codebase. Every Forever spell category is seeded from
Forever's own DB2 data, and a category with nothing on Forever does not exist there.

**Architecture:** The client is asked only through `NS.Compat` (LibKa0s-Compat). Retail's lists stay inline in
`defaults/Categories.lua`. Forever's are generated into `defaults/Categories_Forever*.lua` and `defaults/CastToAura_Forever.lua`
by the extended `tools/spell-research`, and the client's set is picked once at file load. Empty Forever categories are
gated at registration.

**Tech Stack:** Lua 5.1 (WoW), Ace3 `ac3d1225`, LibKa0s v1.98.0, the headless harness (`lua tests/run.lua`, kit profiles
`retail`/`forever`), luacheck through `ka0s-bounded`, Python 3 stdlib (`tools/spell-research`, pytest), wago.tools DB2
CSV (`wowf` 1.60.1.70938).

**Spec:** [`../specs/2026-11-14-auramaster-forever-port-design.md`](../specs/2026-11-14-auramaster-forever-port-design.md)
(the § references below point into it).

**Run tooling:** [`2026-11-14-auramaster-forever-port/`](2026-11-14-auramaster-forever-port/):
- `items.tsv` lists the items.
- `checkpoints.tsv` holds the evidence per milestone.
- `RESUME.md` says how to resume.
- `./resume-state.sh -v` shows what has landed, straight from git.

An item is done when a commit whose subject opens with `<ID>: ` exists on the run branch, or on master, of the repo
that owns it.

## Global Constraints

- **Branch:** `feat/2026-11-14-forever-port` in AuraMaster, `feat/2026-11-14-auramaster-forever-port` in
  WowAddonStandards. Work in the main checkout, never a side worktree (the game loads `GIT/AuraMaster` through a
  symlink).
- **Gate before every commit**, all green:
  - `lua tests/run.lua` and `KA0S_KIT_CLIENT=forever lua tests/run.lua` (0 failed);
  - `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` 0/0;
  - `python3 -m pytest -q tools/spell-research` whenever `tools/` changes.
- **Never edit** `libs/` or `tests/_kit/` except by the AM-FP01 re-vendor. No version bump, tag or merge.
- **Stage explicit paths only** (`git add <paths>`, never `-A`/`.`): two tasks may run in parallel in one tree.
- **Client checks only through `NS.Compat`** (`IsForever`, `IsRetail`, `ClientKey`, `ForClient`). Nothing else reads
  `WOW_PROJECT_*` or compares interface numbers (clients-§3).
- **Retail lists are byte-identical** to `master`'s: `git diff master -- defaults/Categories.lua` shows no change
  inside any class table, and `defaults/CastToAura.lua`'s Retail data is unchanged.
- **Forever seeds are their own generated lists, picked once by `ClientKey()`** (clients-§5). Never filter Retail's.
- **Every file < 1500 lines** (generated files ≤ 1400). Every function CCN ≤ 15.
- **Every new `L[...]` key** has an enUS entry. Every new event or bus receiver goes in `tests/test_disabled.lua`'s lists.
- **The date is an argument, never the clock**, in every tool run (`--date 2026-11-14`).
- **Commit messages:** `<ID>: <what changed>`, ending with the run's attribution lines.

## Review Focus

1. **A cast id that lands a different aura on Forever** (a trap, a totem, a scripted stun). The Forever list must hold
   the aura id, or the row matches nothing. Test: AM-FP04 `test_forever_maps_through_trigger`.
2. **A spell with many ranks** (Polymorph 118/12824/12825/12826, Power Word: Shield). Every rank must ship, or a
   low-level player's aura never matches. Test: AM-FP03 `test_forever_rank_closure`, and AM-FP06's
   `hardCC holds every Polymorph rank on forever`.
3. **A Retail-only class key** (DEATHKNIGHT, MONK, DEMONHUNTER, EVOKER) leaking into a Forever list or the editor's class
   grouping. Test: AM-FP04 `test_forever_class_keys`, and AM-FP06 `no Retail-only class key on forever`.
4. **A profile that names a gated key** (filter state `stances = "hide"` copied from Retail): no error, no ghost row in
   the grid, and the stored value is left alone. Test: AM-FP06 `a gated key in a stored profile is inert`.
5. **Retail regressions from the split**: the same categories, the same order, the same ids. Test: AM-FP06
   `retail categories unchanged` (keys, order and an id-count snapshot per category, taken from `master` before the
   change).

---

## M0: design and plan

### AM-FP00: Commit the design, this plan and the run tooling
- [ ] `git add docs/superpowers/specs/2026-11-14-auramaster-forever-port-design.md docs/superpowers/plans/2026-11-14-auramaster-forever-port.md docs/superpowers/plans/2026-11-14-auramaster-forever-port/` and commit `AM-FP00: …`.

## M1: groundwork (Lua)

### AM-FP01: Re-vendor LibKa0s v1.98.0
**Files:** `libs/LibKa0s/`, `tests/_kit/` (copied whole from `../LibKa0s` at tag `v1.98.0`), `CLAUDE.md` (provenance
line and `LibKa0s icons:` declaration kept), `media/icons/` (pruned with the tag's `tools/prune-icons.lua`), README
icon credits if they change, and `docs/revendor/2026-11-14-v1.98.0/` (the delta: per-file LibStub minors, kit revision,
the majors Aura Master consumes, contract changes, and **candidates, all deferred** with one line each).
- [ ] Copy, prune and roll the provenance line, following `/dev-copilot:wow-revendor-libka0s`'s steps without its interview.
- [ ] Run the gate under both profiles. Fix only call sites the new library breaks; a contract change that needs more is a stop-and-report.
- [ ] Commit `AM-FP01: Re-vendor LibKa0s v1.98.0 …`.

### AM-FP02: Client seam and default skin per client
**Files:** `core/Compat.lua`, `core/SkinSetup.lua`, `defaults/Profile.lua`, any stand-in fallback that writes `"ka0s"` as
the skin choice, `tests/test_compat.lua`, `tests/test_defaults.lua` (or a new `tests/test_clients.lua`).

**Produces:** `NS.Compat.IsForever() -> bool`, `NS.Compat.IsRetail() -> bool`, `NS.Compat.ClientKey() -> "retail"|"forever"|nil`,
`NS.Compat.ForClient(clients: table|nil) -> bool` (nil serves both), each routed to `CompatLib`, with a library-absent
stand-in answering Retail (`ClientKey` "retail", `ForClient` true for nil/`both`/`retail`). `NS.DEFAULT_SKIN` (string).
- [ ] Tests: on each profile, `ClientKey()` equals `os.getenv("KA0S_KIT_CLIENT") or "retail"`. `ForClient({"retail"})` is true on retail and false on forever, and `ForClient(nil)` is true on both. A fresh profile's `skin.skin` equals `NS.DEFAULT_SKIN`, which is `"forever"` on the forever profile and `"ka0s"` on retail. The degraded env keeps `"ka0s"`.
- [ ] Implement; gate both profiles; commit `AM-FP02: …`.

## M2: Forever derivation tooling (Python; runs in parallel with M1)

### AM-FP03: `research.py --client forever`
**Files:** `tools/spell-research/research.py`, `tools/spell-research/sid_db2.py` (if the table loader is there),
`tools/spell-research/test_research_forever.py` (new, with small CSV fixtures under `fixtures/forever/`).

**Produces:**
- `CLIENTS = {"retail": {"product": "wow", ...}, "forever": {"product": "wowf", ...}}`.
- `tables_for(client) -> tuple`: Forever drops `SpecializationSpells` and `TraitTreeLoadout` and adds `Talent` and `TalentTab`.
- `build_pool_forever(tables) -> {spell_id: set(class_tokens)}`: class-mask and class-skill-line rows of `SkillLineAbility`, minus skill lines 2851 and 2853 and the `Pet - ` lines, plus `Talent.SpellRank_0..8` by `ClassID`.
- `rank_closure(pool, names, class_of) -> pool`: adds every spell with the same name and the same class.
- `--client` (default `retail`) on every mode, `--emit`/`--diff`/`--bundle`/`--replay` included. The Forever coverage gate uses `SENTINELS_FOREVER`: 118, 853, 5782, 122, 339, 1715, 408. Bundles record the client in `SOURCES.md` and `derived.json`.
- [ ] Tests:
  - `test_forever_tables` covers the table set.
  - `test_forever_pool_excludes_runes_and_pets`.
  - `test_forever_rank_closure`: the fixture Polymorph 118 reaches 12824/12825/12826 under MAGE.
  - `test_forever_talent_pool`: a `Talent` row's ranks join with its class.
  - `test_retail_default_unchanged`: a bare run still resolves product `wow` and the 14 Retail tables.
  - Every existing test still passes.
- [ ] Implement; `pytest -q tools/spell-research`; commit `AM-FP03: …`.

### AM-FP04: `forever.py`, the non-CC categories and the emitters
**Files:** `tools/spell-research/forever.py` (new), `tools/spell-research/forever_rulings.json` (new, `{}` until
AM-FP05), `tools/spell-research/test_forever.py` (new, with fixtures).

**Consumes:** AM-FP03's pool, `rank_closure` and table loader; `sid_db2`'s `Categories.lua` reader.

**Produces:**
- `map_retail_entries(retail_cats, retail_names, forever_tables, pool) -> [Candidate]`. Each candidate carries the Forever id, the category key, the class, `source` (`name-map`, `db2-effect`, `cc-mechanic` or `bridge`), the Retail origin id if any, the name and the rank. Trigger and CastToAura-style edges resolve to the aura id.
- `db2_candidates(category_key, forever_tables, pool) -> [Candidate]`, one effect rule per category. Stances: aura 36 on self. Movement: speed auras. Defensives: damage-taken reduction, immunity or absorb, with a long recast. Racials: the `Racial - ` skill lines. The rule table is a constant with a comment per row.
- `emit_categories_forever(accepted, empty_keys, build, date) -> [(path, text)]`. It writes `NS.CategorySeedsForever` (`[key] = { CLASS = { id, -- name (rank) … } }`) and `NS.CategorySeedsForever.EMPTY = { key = true, … }`, CRLF, one id per line, split at category boundaries into `defaults/Categories_Forever.lua`, `defaults/Categories_Forever_2.lua` and so on, each ≤ 1400 lines.
- `emit_cast_to_aura_forever(build, date) -> text`. It writes `defaults/CastToAura_Forever.lua` with the same REWRITE/CHOICES shape as Retail, published as `NS.CastToAuraForever`, and ends with the one-time selector: `if NS.Compat.ClientKey() == "forever" then NS.CastToAura = NS.CastToAuraForever end`. Retail's `CastToAura.lua` keeps `NS.CastToAura` as it is.
- CLI: `forever.py derive --bundle DIR --date D [--replay]`, `forever.py emit --bundle DIR --date D`, and `forever.py rule --key K --ruling accept|reject --reason R` (the only writer of `forever_rulings.json`). An unruled candidate is reported and never emitted. `emit` fails if any candidate is unruled.
- [ ] Tests:
  - `test_forever_maps_through_trigger`.
  - `test_forever_class_keys`: only the nine classes and `ALL`.
  - `test_unruled_blocks_emit`.
  - `test_emit_splits_under_cap`.
  - `test_emit_crlf_and_shape`: the emitted Lua loads with `luac -p`, if available, or the existing harness parse check.
  - `test_empty_keys_listed`.
- [ ] Implement; pytest; commit `AM-FP04: …`.

## M3: the Forever data and its wiring

### AM-FP05: Run, rule, freeze, emit
**Files:** `docs/spell-research/2026-11-14-forever/` (`raw/*.csv.gz`, `SOURCES.md`, `derived.json`, `RULINGS.md`, `ANALYSIS.md`),
`tools/spell-research/forever_rulings.json`, `defaults/Categories_Forever*.lua`, `defaults/CastToAura_Forever.lua`.
- [ ] `research.py --client forever --bundle docs/spell-research/2026-11-14-forever --date 2026-11-14`, then `forever.py derive`. The coverage gate must PASS.
- [ ] Rule **every** candidate through `forever.py rule`, each with a reason. Accept what a player of that class can have as that aura and what fits the category's meaning in the Retail list. Reject NPC copies, items, runes, passives that never show as an aura, and duplicates across categories (one category per id, the same precedence as Retail's lists). Never accept a spell only because its name matches.
  - Known traps from AM-FP03's review: (a) source `rank` candidates include NPC copies that carry the player class's spell family (Blast Wave 15091/17145/…, Mind Flay 16568/…, Frostbolt 13439, Intimidating Shout 19134/29544, Charge 22911, Banish 457569/465352) — reject them, keep the real ranks; (b) the trigger closure is not fenced, so pet-line-only abilities reach the buckets via hunter Beast Training learn spells (Web 1265843/1265878/1265880/1265881/1265883 ccRoot, Pinch 1264735-1264742 and Tendon Rip 1265038-1265042 ccSnare, Intimidation 24394 hardCC) — rule each explicitly; keep Intimidation 24394 (a hunter CC aura), decide Web/Pinch/Tendon Rip on whether the player sees them as auras on their target.
- [ ] `forever.py emit`; check the line caps; write `ANALYSIS.md`: per category the count, notable inclusions and rejections, which categories are empty (and so gated), and what #26's logs should re-check.
- [ ] `forever.py derive --replay` reproduces `derived.json`. Commit `AM-FP05: …` (the gate stays green: the files are not in the TOC yet).

### AM-FP06: Wire the seeds, CastToAura and the gate
**Files:** `AuraMaster.toc` (the generated files before `defaults\Categories.lua`, and `CastToAura_Forever.lua` after
`CastToAura.lua`), `defaults/Categories.lua` (the `seeded(key, retailList)` helper and the gate around the two lists;
class tables untouched), any consumer that assumed a fixed key set (`defaults/Profile.lua` templates,
`settings/Schema.lua` rows, `defaults/UserCategories.lua`'s collision check, `modules/FilterCompiler.lua`), and
`tests/test_categories_clients.lua` (new).

**Consumes:** AM-FP02's `ClientKey`/`ForClient`, and AM-FP05's `NS.CategorySeedsForever` (with `.EMPTY`) and `NS.CastToAuraForever`.
- [ ] Tests (both profiles):
  - `retail categories unchanged`: keys, order and per-category id count equal a snapshot from `master`.
  - `forever seeds picked`: every `spells` category's ids on forever equal `NS.CategorySeedsForever[key]`.
  - `empty forever category absent`: an `.EMPTY` key is missing from `Cat.HELPFUL`/`Cat.HARMFUL`, `Cat.Find`, `Cat.DefaultStates()` and the schema rows on forever, and present on retail.
  - `hardCC holds every Polymorph rank on forever`.
  - `no Retail-only class key on forever`.
  - `a gated key in a stored profile is inert`.
  - `CastToAura selects per client`.
  - `user categories still materialize on forever`.
- [ ] Implement, with the client read once at file load. Gate both profiles; commit `AM-FP06: …`.

## M4: port surface and roster

### AM-FP07: The port surface (§3.6)
**Files:** `AuraMaster.toc` (`## Interface: 120105, 16001`), `README.md`, `DEPENDENCIES.md`, `docs/ARCHITECTURE.md`
(per-client feature table; Documented deviations untouched unless one arises), `CLAUDE.md` and `docs/testing.md` (both
profiles in the gate), `docs/smoke-tests.md` (a FOREVER theme), `docs/known-limitations.md`, `docs/test-cases.md`
(regenerated), `tools/spell-research/README.md` (a Forever section).

The smoke theme names its client on every check, owner-run, with blank `Result:` lines. It covers:
- install and load on Forever;
- the default skin on a fresh profile;
- a buff container on the player, showing a rank-1 spell's aura;
- each token and flag category on Forever: does it ever match? (Big defensives on Shield Wall, Crowd control on Polymorph, Boss debuffs in a dungeon, and so on);
- a gated category is absent from the Filters grid and General > Spell categories;
- hiding the Blizzard buff and debuff frames;
- weapon enchants (an oil or a stone);
- CastToAura rewriting a typed Forever cast id;
- Retail regression: the categories and lists are unchanged.
- [ ] With the second interface number in place, the kit's Forever missing-globals suite must pass. Fix any hit through `NS.Compat`.
- [ ] Gate both profiles, plus inventory and badge parity (the kit's doc checks); commit `AM-FP07: …`.

### WS-FP01: Roster row
- [ ] In WowAddonStandards on its branch, `standards/ADDONS.md`: Aura Master `Retail (port pending)` → `Retail · Forever`. Run `check-standard.sh`; commit `WS-FP01: Roster: Aura Master ships Retail · Forever`.

## M5: review and record

### AM-FP08: Whole-branch review and the automated-test record
- [ ] An independent whole-branch review (most capable model), against the spec and the standard's clients-§1..§6 and skinning-§2. Fix the findings in `AM-FP08: Review fixes: …` commits.
- [ ] Record an automated-test bundle (`docs/automated-tests/<stamp>/`, following the AUTOMATED_TESTS playbook: both profiles, lint, perf scenarios, lizard). Log the `checkpoints.tsv` row and push both branches.

**After M5:** the owner runs the smoke on both clients. Merge only on the owner's go-ahead (`/dev-copilot:finalize`), then
delete the run branches (local and origin), stashes and worktrees.
