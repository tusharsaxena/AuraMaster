# Custom spell categories — plan of record

GitHub issue #10, plus the owner's four additional requirements and the buff/debuff dropdown
markers. Started 2026-09-20 on `feat/custom-spell-categories`.

**This file is the resumable ledger.** Each checkpoint is independently green-gated and committed on
its own. To resume: read the status table, find the first row that is not `DONE`, and continue from
its notes. Do not rely on conversation context — everything needed is here or in the commit it names.

## Status

| # | Checkpoint | Status | Commit | Notes |
| --- | --- | --- | --- | --- |
| 0 | Plan of record | DONE | this file | — |
| 1 | Buff/debuff markers in the Category dropdown | DONE | b520ecd | `[Buffs] ` / `[Debuffs] ` prefix from `C.AURA_TYPE_LABELS`, padded to a common character width; explicit pullout width and LEFT-justified closed box; settings/GeneralSpells.lua |
| 2 | Category type as a first-class field | DONE | b520ecd | `def.auraType` stamped at load; `Cat.AuraTypeOf(defOrKey)` reads it |
| 3 | Storage + schema for user categories | DONE | 0a2004b | Records in `userCategories`/`userCategoryOrder`, materialized into `Cat.HELPFUL`/`Cat.HARMFUL` by `Cat.SyncUserCategories`; random `user…` keys; schema v6; `NS.RegisterSchemaRows(rows, beforePath)` + `NS.UnregisterSchemaRows` |
| 4 | `Uncategorized` counts user categories | DONE | 0a2004b | No compiler change needed, and proven so from a compiled plan (tests/test_filtercompiler.lua) |
| 5 | Deletion and cleanup across profiles | WIP | | Including inactive profiles |
| 6 | UX: create / rename / delete + predefined lock | TODO | | |
| 7 | Overlap guardrail | TODO | | Inform, do not block |
| 8 | Docs, counts, scope, smoke tests | TODO | | |

Status values: `TODO`, `WIP`, `DONE`, `BLOCKED` (with the blocker named).

## Requirements

From issue #10:

1. A player can create a category, name it, fill it with spells, and Show/Hide it per container like
   any shipped one.

From the owner, 2026-09-20:

2. Every entry in the General → Spell Categories **Category dropdown** carries a buff or debuff
   marker.
3. Every category is tagged buff **or** debuff. A category holds one aura type, never both.
4. Guardrails when a spell is already in another category.
5. Creating and removing custom categories is simple and obvious.
6. **Predefined categories cannot be edited or deleted** — the category object is locked. Its spell
   list stays fully editable, including Restore.

## Decisions taken up front

**The overlap guardrail informs, it does not block.** An aura legitimately belongs to two sets — a
defensive that is also an immunity — and the compiler already resolves overlap by drawing the aura
once, under the first Show (`docs/ARCHITECTURE.md` → Filter priority). Blocking would make correct
configurations impossible. So: at add time, and in the list, say which other categories already
claim the id. Never refuse.

**"Cannot edit a predefined category" means the category object, not its contents.** No rename, no
delete, no aura-type change, no reordering. Adding and removing spells, and Restore, are unchanged —
that is what `profile.categorySpells` has always been for.

**A user category's name is data, not a translatable string.** Every user-visible string in this
addon routes through `NS.L` and a guard test fails on anything unrouted. A player-supplied name
cannot route through a locale table, so it needs an **explicit, documented exemption** rather than a
quiet special case — the exemption is named in the test and in `docs/ARCHITECTURE.md`, so the guard
keeps its meaning for every other string.

**Aura type is immutable after creation.** The compiler groups by aura type and a container's stored
Show/Hide is keyed by category key; letting a category change type would orphan stored state and
silently move a category between two different grids. Changing type means delete and re-create.

## Feasibility, established before planning

- **The schema is a live table, not a frozen one.** `NS.RegisterSchemaRows` appends and calls
  `reindex()` (`settings/Schema.lua:195-205`), so rows can be registered after load. This is the
  fact issue #10's "dynamic schema rows" trap turns on, and it is friendlier than the issue assumed.
- **Category rows are generated from `Cat.For(auraType)`** (`settings/Filters.lua:128-143`), one row
  per category at `container.filter.categories.<key>`, with `label = L[def.label]` — that `L[...]`
  is exactly where the locale exemption has to land.
- **`Cat.DefaultStates()`** (`defaults/Categories.lua:629`) stamps a state for every key into the
  container template, and its header already promises that a key added later reaches stored
  containers through the ordinary backfill. A user category must reach them the same way.

## Checkpoints

### 1. Buff/debuff markers in the Category dropdown

The dropdown at General → Spell Categories lists every editable category with no indication of which
aura type it filters. Add a marker per entry. Purely presentational; no stored shape changes. Ships
first because it de-risks the type model the rest depends on.

### 2. Category type as a first-class field

Shipped categories get their type implicitly from which list they live in (`Cat.HELPFUL` /
`Cat.HARMFUL`). Make it explicit and readable per definition, so one accessor answers "what type is
this category" for shipped and user categories alike, and checkpoint 1's marker reads from it.

### 3. Storage + schema for user categories

The hard half:

- Where user categories live in the profile, and their stored shape.
- Registering a schema row for a key that did not exist at load.
- Key generation: stable, collision-free against shipped keys and each other, and surviving a rename
  (so rename must not re-key, or every container's stored state orphans).
- A schema migration — the stored shape is at **v5**, not v4, so the new step is **v6**. (`SCHEMA_STEPS`
  ended at `{ to = 5 }` when this was planned, the Weapon-enchants aura-type retirement of feedback #6, 2026-09-19; checkpoint 3 added `{ to = 6 }`, so it ends there now. The "v4"
  written here and in issue #10 was stale when it was written; corrected 2026-09-20, checkpoint 3.)
- Ordering: `Uncategorized` stays last in the grid, and the compiler's group-per-shown-category order
  depends on declaration order.

**NOTE, carried forward from checkpoint 2 — `Categories.AuraTypeOf`'s KEY form must be widened
here.** Given a definition it reads `def.auraType` and answers for anything, including a user
category. Given a key it resolves through `Categories.Find`, which walks `Cat.HELPFUL` and
`Cat.HARMFUL` only, so a user category's key answers `nil`. That is harmless until this checkpoint
and a live bug the moment it lands: every caller holding a bare key out of a container's stored
`filter.categories` would type a user category as nothing. Widen the key form to the user
categories' store as part of the storage work, and cover it with a case that asks by key.

**CLOSED in checkpoint 3.** Nothing widened `Cat.AuraTypeOf` itself, and nothing needed to: user
categories are MATERIALIZED into `Cat.HELPFUL`/`Cat.HARMFUL`, so `Cat.Find` -- and therefore the key
form -- finds them like any shipped definition. Covered by "user categories: Cat.AuraTypeOf answers
for a user category KEY, not only for its definition" (tests/test_database.lua).

The accessor's own doc comment said the opposite for a while: it still claimed the key form "answers
for the SHIPPED lists only" and that user categories "do not exist until checkpoint 3", which this
checkpoint falsified the moment it landed. Rewritten in the checkpoint 3/4 review pass — it now
states what the code does, and records that the widening came for free from materializing user defs
into the shipped lists rather than from any change to the accessor.

### Checkpoint 3/4 review pass

Five findings from the review of the uncommitted checkpoint 3/4 tree, all fixed on the same tree:

1. **A record whose key is outside the reserved namespace is refused** (`Cat.IsUserKey`, consulted by
   `usableName`). A stored record keyed `healing` was materialized beside the shipped `healing` --
   two definitions under one key -- and the next sync's teardown, which finds a user def BY KEY, then
   took the SHIPPED category's entry out of the container template for the rest of the session, so
   `NS.DefaultFor` answered `nil` and `NS.ValidateSchema` failed on a row nobody had touched. Both
   the refusal and that consequence are pinned in tests/test_defaults.lua.
2. **The key generator is seeded.** Nothing ever called `math.randomseed`, so every client walked the
   same sequence and two players' first categories got the same key -- which is exactly the collision
   the random scheme was chosen to prevent. `Cat.NewUserKey` now draws from this file's own Lehmer
   sequence, seeded once on first use from `UnitGUID("player")`, the clock and the profiler.
   **The design claim is weakened to what is delivered:** within the account, uniqueness is a
   guarantee and always was the `taken` scan's doing, not the generator's; ACROSS accounts it is now
   a small probability rather than the impossibility the old comment implied, so the import half of
   #9 must REKEY a record whose key the importing account already holds.
3. **`Cat.AuraTypeOf`'s doc comment** — above.
4. **A user category's name never goes through `NS.L`.** `Cat.LabelOf(def)` is now the single site
   rule: a shipped label is a locale key and is routed, a user label is the player's text and is not.
   Before it, a category named "Healing" or "Movement" drew the shipped translation instead of the
   name that was typed — invisible on enUS, wrong on any translated client. Callers: the Filters
   grids, the Spell Categories dropdown and `ExplainSpell`'s notes.
5. **The sync/`PrepareProfile` order in `NS.RunMigrations` is pinned by a test.** Inverting the two
   lines left the whole suite green while genuinely breaking a stored-but-not-yet-backfilled user
   category: its containers carried no state for the key, so its grid row drew with neither Show nor
   Hide lit. tests/test_database.lua now fails on the inversion.

### 4. `Uncategorized` counts user categories

`uncategorized` compiles as the complement of the union of every `spells`-kind category's effective
ids. A user category must join that union — otherwise an aura in it is *also* uncategorized, and
rank 3 rescues it exactly when the player hid it deliberately. `categorizedUnion`
(`modules/FilterCompiler.lua`) walks `Categories.For(auraType)`, so this follows from checkpoint 3
if user categories appear there — which must be **verified by a test**, not assumed.

### 5. Deletion and cleanup

Deleting a category leaves `filter.categories.<key>` in every container of every stored profile,
including profiles not currently loaded, plus its `categorySpells[key]` edits. Decide and document
whether cleanup is eager (at delete, across all profiles) or lazy (ignored keys pruned on load), and
make the schema validator tolerate the transient state either way.

### 6. UX

Create, rename, delete, with the predefined lock. Naming rules (length, duplicates, empty). Deletion
confirmation, since it discards a list the player built.

### 7. Overlap guardrail

Per the decision above: show which other categories already claim an id, at add time and in the list.

### 8. Docs and counts

`docs/scope.md`, `docs/schema.md`, `docs/settings-panel.md`, `docs/ARCHITECTURE.md`,
`docs/module-map.md`, `docs/common-tasks.md`, the smoke-test checklist, and every count claim the
change moves. The locale exemption gets written down where the guard test can be understood from it.

## Out of scope

- **Import/export (#9).** A shared container naming a custom category the importing player lacks
  needs a defined answer, but #9 does not exist yet; note the interaction and move on.
- **Group count (#7).** Each Show category compiles to its own aura group, so user categories add to
  the count. Existing behavior, not this issue's to solve.

## Green gate

`lua tests/run.lua` and `luacheck .` (0/0) before every commit, both through
`/home/tushar/.claude/wow-addon/bin/ka0s-bounded`.
