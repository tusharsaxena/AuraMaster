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
| 1 | Buff/debuff markers in the Category dropdown | DONE | (uncommitted) | `[Buffs] ` / `[Debuffs] ` prefix from `C.AURA_TYPE_LABELS`, padded to a common character width; explicit pullout width and LEFT-justified closed box; settings/GeneralSpells.lua |
| 2 | Category type as a first-class field | DONE | (uncommitted) | `def.auraType` stamped at load; `Cat.AuraTypeOf(defOrKey)` reads it |
| 3 | Storage + schema for user categories | TODO | | The hard half; needs a migration |
| 4 | `Uncategorized` counts user categories | TODO | | Union correctness |
| 5 | Deletion and cleanup across profiles | TODO | | Including inactive profiles |
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
- A schema migration — the stored shape is at v4 and every change so far has needed one.
- Ordering: `Uncategorized` stays last in the grid, and the compiler's group-per-shown-category order
  depends on declaration order.

**NOTE, carried forward from checkpoint 2 — `Categories.AuraTypeOf`'s KEY form must be widened
here.** Given a definition it reads `def.auraType` and answers for anything, including a user
category. Given a key it resolves through `Categories.Find`, which walks `Cat.HELPFUL` and
`Cat.HARMFUL` only, so a user category's key answers `nil`. That is harmless until this checkpoint
and a live bug the moment it lands: every caller holding a bare key out of a container's stored
`filter.categories` would type a user category as nothing. Widen the key form to the user
categories' store as part of the storage work, and cover it with a case that asks by key.

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
