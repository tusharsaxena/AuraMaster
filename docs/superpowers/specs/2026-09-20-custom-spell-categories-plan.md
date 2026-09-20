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
| 5 | Deletion and cleanup across profiles | DONE | 7aab1c5 | `Cat.DeleteUserCategory`; cleanup is EAGER across every stored profile through the published `Database.EachProfile`; a profile holding its OWN record under the key (a profile copy) is skipped |
| 6 | UX: create / rename / delete + predefined lock | DONE | 7aab1c5 | The block on General -> Spell Categories (named `Your categories` here, renamed `This category` at 7R2); the lock is enforced by the ACTS, and a shipped category draws a sentence instead of disabled controls |
| 7 | Overlap guardrail | DONE | 7aab1c5 | Inform, do not block; `FC.ClaimingCategories` published out of `ExplainSpell` and read by the panel for both the add-time line and the per-entry note |
| 7R | Review round four: the owner's findings on 5-7 | DONE | 7aab1c5 | Restore is not drawn for a user category and `RestoreStarters` refuses one; the enchant entry gets its own sentence; a `(yours)` marker on the dropdown and the Filters grid; the two name boxes separated by heading, label and pre-fill; every act of the block answers in the panel; the eight low findings |
| 7R2 | Review round five: the UX findings on the block, and two correctness ones | DONE | (uncommitted) | Headings agree with their blocks (`This category`, `Weapon slots`); the answer line's lifetime is stamped and enforced at the draw; the unreadable-record strings read at a count of one; the overlap note and its chat line carry `(yours)`; Weapon enchants gains a picker lead-in; `.luacheckrc` counts four popups; `Cat.DeleteUserCategory` returns the refused-profile count and the confirmation says so |
| 8 | Docs, counts, scope, smoke tests | DONE | (uncommitted) | `scope.md` (the count is now "what ships plus the player's own"), `schema.md` (the two profile keys, the runtime rows, `to = 7` for the next rung), `settings-panel.md` (the block, the create form, the marker, the answer line, Restore's absence, the row counts), `ARCHITECTURE.md` (the second structural registry, the materialize decision, the surface table, the LOCALE EXEMPTION in a section of its own, two Known Limitations), `module-map.md`, `common-tasks.md` (the create recipe), `smoke-tests.md` section V (checks 167-177), README (one paragraph and one FAQ row, de-AI pass run). Counts verified by loading the addon headlessly: 242 schema rows, 36 shipped categories (17 buff, 19 debuff), five dispel swatches (module-map said six) |

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

**DECIDED: EAGER, at the delete, across every stored profile.** `Cat.DeleteUserCategory` removes the
record, lets the ordinary `Cat.UserCategoryOrder` reconcile drop the order entry, deletes
`categorySpells[key]`, and clears `filter.categories.<key>` from every container of every profile in
`Database.EachProfile` -- the walk the schema ladder uses, published for this. The sync then takes
the definition, the schema row and the container-template entry down together, as it always did, so
nothing is left for a later pass to find.

Why not lazy, in full in the comment above `forgetUserKey` (defaults/Categories.lua): there is no
pruning pass to write it into (`Database.Backfill` only ever fills), a load-path pruner would be a
new destructive pass that cannot tell a not-yet-materialized key from a dead one, and it would never
reach the inactive profiles that actually hold the debris. The validator is never asked to tolerate
a transient state, which is the strongest form of the plan's condition rather than a use of the
allowance it made.

**The one hazard eager has, and its answer:** AceDB's profile COPY duplicates `userCategories`, so
two profiles can legitimately hold a record under one key. The sweep therefore SKIPS any profile
that still holds a record of its own, and the owner's record is removed first so the owner profile
is itself eligible. Both halves are pinned in tests/test_database.lua and both were verified to fail
when reverted.

### 6. UX

**Review round four (owner, 2026-09-21) changed five things about this block and the picker line
above it. Each is settled here as well as in the code, because the code's comment says how and this
says why the alternative was not taken.**

- **Restore is NOT DRAWN for a category the player made** — the owner's option (a). Its starter list
  is `{}`, so the one act behind that label empties the category, silently, one row above a Delete
  that stops to ask for precisely that loss. Option (b) — relabel and confirm — was declined: a
  one-click empty buys nothing the list's own X and the Delete do not already give, and it would
  make the picker line mean two different things depending on which category is picked. The ACT
  refuses it too (`restoreStarters`, published as `NS.GeneralSpells.RestoreStarters`), so the
  drawing rule is a courtesy and never the enforcement; the lead-in sentence drops its Restore
  clause on the same categories.
- **Weapon enchants gets its own sentence.** The shipped one promises a spell list, Restore and
  add/remove; that entry draws three slot toggles and has none of them.
- **A category the player made is marked `(yours)`** wherever it is listed — the Category dropdown
  and the Filters → Categories grid — in checkpoint 1's grammar. A SUFFIX on the name, because the
  aura-type marker is a padded prefix and anything in front of the name would move the column that
  padding bought. One definition (`NS.GeneralSpells.MarkedName`), read by both surfaces; the SCHEMA
  row keeps the bare name, since that name is the row's identity in `/am list` and the write log.
- **The two Enter-committing name boxes are told apart three ways**: different headings (the create
  form moved under `Make a new category`), labels naming ACTS rather than the noun they shared
  (`Rename this category` / `New category's name`), and only one of them ever pre-filled — the
  rename box is redrawn from the store every render. A rename that goes through now says the OLD
  name back, which is the only undo a rename has.
- **Every act of the block answers IN THE PANEL**, one `H.TextRow` under the heading, as well as in
  chat: empty name, duplicate name, create, rename, delete, and the restore refusal. Picking another
  category clears the line.

The low findings of the same round, all fixed here: the rename gained the reserved-namespace guard
the delete had (both now pinned by a test that fails when either guard is removed); the delete's
profile sweep is per-profile inside a pcall and the sync runs unconditionally, so the failure is
RECOVERABLE rather than atomic and says so; a record the sync cannot read is reachable at last
(`Cat.UnusableUserRecords` / `Cat.ForgetUnusableUserRecords`, drawn as a line and a confirmed button
in the block, and `Cat.DeleteUserCategory` no longer refuses a corrupt record inside the namespace);
the duplicate-name line prints the SANITIZED name; `Cat.SanitizeUserName` caps in CHARACTERS
(`Cat.CharCount`), which is what `SetMaxLetters` counts; the delete confirmation says that anything
the category was hiding becomes visible again through Uncategorized; and the delete now states that
it happened, since the tab jumps to another category.

**DELIVERED as the 'This category' block on General -> Spell Categories**, between the Category
picker and the spell list: a name box and a Delete for a category the player made, a one-sentence
explanation instead of them for a shipped one, and a create form (name, aura type, Create) always.
Four controls, all of them ordinary AceGUI widgets in `H.RenderGrid` pairs -- the grammar the picker
line and the Filters page's act rows already use. The full justification is the comment above the
block in settings/GeneralSpells.lua.

- **Naming rules.** Non-empty after `Cat.SanitizeUserName` (which also strips `|` and control
  characters and caps at `Cat.USER_NAME_MAX`, now published so the boxes stop where the store
  would); a DUPLICATE is allowed and reported in chat, never refused -- the key is identity.
- **Rename is the name box itself**, committed on Enter, never per keystroke. The key never moves.
- **Delete asks first**, through `StaticPopupDialogs.AURAMASTER_DELETE_CATEGORY`, and the
  confirmation says what is lost: the spell list, and every container's Show/Hide in every profile.
  The popup carries the KEY, so a popup that outlives its render cannot act on a stale definition.
- **The lock is enforced by the ACTS**, not by the drawing rule: `Cat.RenameUserCategory` and
  `Cat.DeleteUserCategory` refuse a key with no stored record, and the aura type has no setter at
  all -- `Cat.CreateUserCategory` is its only writer in the addon. tests/test_database.lua asserts
  all three, including that no `NS.Categories` member other than `AuraTypeOf` names an aura type.

### Review round five (owner, 2026-09-21)

Five UX findings and two correctness ones, all on the uncommitted 5-7 tree, all closed here.

- **Each block sits under its own heading.** `renderEnchant` is called after `renderManage`, and a
  heading owns everything under it until the next one, so on Weapon enchants the slot lead-in and
  the three slot checkboxes were drawn beneath **Make a new category** and read as part of the
  create form. The SLOTS got a heading (`Weapon slots`) rather than the call order being inverted:
  the block above them is the same block that sits above every other category's spell list, and it
  belongs in one place on both.
- **The answer line's lifetime is decided and enforced at the draw.** It was cleared by exactly one
  thing -- the Category dropdown's `OnValueChanged` -- so it outlived a panel close and reopen, a
  page switch and a PROFILE switch. THE RULE: the line belongs to the state it was said in, which is
  the profile, the category it is about, and the visit. `settleNotice` drops it on the first draw
  whose profile or category does not match the stamp; `endVisit` hooks the panel's own OnHide and
  drops it there too, with a structural refresh beside it, because a hidden page is not re-rendered
  on its next show unless something marks it dirty. A delete stamps NO key -- the category it names
  is gone -- and the next draw adopts the one shown in its place. A hop to another TAB of this page
  and back deliberately keeps the line: the panel never left the screen and the sentence is still
  about the category on it.
- **The heading names the block's subject, not one of its two cases.** `Your categories` stood over
  a body whose usual sentence is that the selected category is NOT yours -- ten of the twelve shipped
  entries, and everything a player who has made none ever sees. It is now `This category`, which is
  true in both cases and stays put as the dropdown moves; a heading that changes its words sitting
  directly under the control that changes them is not a landmark. Creating is the act that is about
  categories in the plural, and it already had its own heading.
- **The unreadable-record strings read at a count of one**, which is the common count: two whole
  strings and a branch, this repo's own idiom for a count-dependent line (settings/Text.lua's
  `centerNote`), for the block's line, the confirmation and the answer. A StaticPopup holds one
  `text`, so the branch writes the sentence it needs onto the dialog a line before showing it.
- **Two smaller ones.** Weapon enchants was the only entry whose picker had no lead-in; it has one.
  And the overlap note and its chat line now carry `(yours)` through `markedName`, so a claimed-by
  note can no longer name a category the player made without saying it is theirs.
- **`.luacheckrc` counted three StaticPopupDialogs registrations; there are four.** Corrected.
- **A partial sweep reaches the player.** `Cat.DeleteUserCategory` answered `true` whether or not a
  stored profile refused the sweep, so the difference reached `NS.Debug` and nothing else. It now
  returns the refusing-profile count third, and the confirmation's line says so -- leading with what
  went, because the delete itself did not fail.

### 7. Overlap guardrail

**DELIVERED, inform-only.** `FC.ClaimingCategories` -- `ExplainSpell`'s own private local until now
-- is published and read by the panel, so the guardrail and the Overrides notes cannot drift into
two answers to one question. Asked with an EMPTY filter, because it is a statement about the
category set and not about any one container.

- At the add: one chat line naming the other categories that hold the id, and what the compiler does
  about it. The add itself always goes through.
- In the list: `Also in: <categories>` under the entry, drawn through the library's own `entry.note`.
- Scoped to the SAME aura type, because a buff list and a debuff list never meet in one container.
- Every name drawn comes from `Cat.LabelOf` by way of the compiler's answer, so a user category's
  name is never routed through `NS.L`.

### 8. Docs and counts

`docs/scope.md`, `docs/schema.md`, `docs/settings-panel.md`, `docs/ARCHITECTURE.md`,
`docs/module-map.md`, `docs/common-tasks.md`, the smoke-test checklist, and every count claim the
change moves. The locale exemption gets written down where the guard test can be understood from it.

**DONE (uncommitted).** What actually landed, and the two judgment calls in it:

- **The category count is no longer a number.** `docs/scope.md` said "36 categories"; it now says the
  shipped set plus the player's own, with 36 (17 buff, 19 debuff) given as what ships *as this is
  written* rather than as the count of what a player has. Same treatment for
  `docs/settings-panel.md`'s "36 generated rows" and `NS.Schema`'s 242: 242 is the count with no user
  categories, and each one adds a row at runtime. Every number was re-counted by loading the addon
  headlessly, not read off the old doc.
- **The locale exemption has a home**: `docs/ARCHITECTURE.md` → *Locale routing, and its one
  exemption*, which states what it covers (one FIELD of one flagged definition kind), why
  `Cat.LabelOf` enforces it at the draw, and that it is proven narrow from both sides.
  `tests/test_locale.lua` points at that section, so a reader of the guard finds the reasoning
  rather than reconstructing it.
- **User categories are written up as the addon's SECOND structural registry** (architecture-§5), with
  the storage keys, the named writer and the load pass the rule asks for, and a table of every surface
  the issue published. That is a conformance claim, not a deviation: nothing new went into
  *Documented deviations*.
- Two counts were stale and are corrected on the way past: `docs/module-map.md` said
  `settings/GeneralSpells.lua` drew "six" `dispelColors` rows (there are five since schema v5 dropped
  `None`), and `docs/schema.md`'s migration recipe still told the next change to append `to = 5` (the
  ladder ends at 6, so the next rung is 7 — `docs/common-tasks.md` already said so).
- `docs/smoke-tests.md` gained section V, checks 167-177: create, the category being real in the grid
  and the CLI, that it filters, the overlap note on both sides, rename, the shipped lock and the
  Weapon enchants wording, the answer line's three scopes, empty and duplicate names, delete with its
  confirmation, that a deleted category stops filtering, and that categories belong to the profile.
- README was edited, because a player-facing claim moved: the Usage paragraph now says you can make
  your own categories, and the FAQ has a row for it. The de-AI pass was run on both.

## Out of scope

- **Import/export (#9).** A shared container naming a custom category the importing player lacks
  needs a defined answer, but #9 does not exist yet; note the interaction and move on.
- **Group count (#7).** Each Show category compiles to its own aura group, so user categories add to
  the count. Existing behavior, not this issue's to solve.

## Green gate

`lua tests/run.lua` and `luacheck .` (0/0) before every commit, both through
`/home/tushar/.claude/wow-addon/bin/ka0s-bounded`.
