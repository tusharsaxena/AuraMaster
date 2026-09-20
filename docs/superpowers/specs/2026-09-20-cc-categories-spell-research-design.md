# Hard CC / Soft CC categories and the spell-research process

Design of record for GitHub issue #11, parts A and C. Decided 2026-09-20.

Issue #11 carries three pieces of work. This spec covers two of them:

- **Part A** — the Hard CC and Soft CC debuff categories.
- **Part C** — a repeatable spell-research process that derives category spell lists from the
  client's own data every patch, or on demand.

**Part B** — triaging the issue's ~20 candidate categories (Immunities, Bloodlust, Silences, Taunts,
…) to accepted / deferred / dropped — is explicitly **out of scope here** and keeps its own later
cycle. Part C is built so Part B consumes it rather than repeating it.

## Decisions taken

| Question | Decision |
| --- | --- |
| Scope of this cycle | Part A + Part C; Part B deferred |
| CC split | **Two** categories, Hard CC and Soft CC — not five DR groups |
| Research tool shape | An offline generator + a frozen dated bundle, not a client verb or a LibKa0s payload |
| Language and home | Python 3 under `tools/spell-research/` |
| Narrowing rule | Derive from client data, filtered to player-reachable spells; the author accepts the diff per change |
| Raw exports | Committed to the dated bundle, gzipped; never shipped to players |
| `tools/` vs the standard | Resolved **upstream** — `layout-§1` gains a `tools/` line (see *Standards ripple*) |

## Part A — Hard CC and Soft CC

### A1. The categories

Two `spells`-kind entries are added to `Cat.HARMFUL` in `defaults/Categories.lua`, placed **above**
`crowdControl` so the two editable rows read before the Blizzard token they refine:

- `hardCC` — "Hard CC". The unit loses control: stuns, incapacitates, disorients and fears, plus
  Cyclone, Banish and Mind Control.
- `softCC` — "Soft CC". The unit keeps control but moves less: roots and snares.

Both are built with the existing `spells({ CLASS = { … } })` helper, so they inherit the profile's
per-category edits (`profile.categorySpells`), the General → Spell Categories editor, the Restore
button and the `Cat.IsSpellCategory` surface with no new machinery.

**No schema bump.** `Cat.DefaultStates()` is the source of the container template's
`filter.categories`, and its header already promises that a key added in a later version reaches
every stored container through the ordinary backfill. Two new keys defaulting to `"show"` change no
stored container's behaviour.

Counts move 34 → 36 categories; debuffs 17 → 19.

### A2. The compiler fix — the load-bearing part

These are the **first** `spells`-kind categories `Cat.HARMFUL` has ever had. Today
`Cat.HARMFUL`'s categorized union is always empty, and a large amount of `modules/FilterCompiler.lua`
is written against that fact (fix round 3, 2026-09-16).

`addCategoryGroups` computes:

```lua
local hasUnion = not isEmpty(cats.union or {})
```

— from the union alone, with no knowledge of which unit the container watches. The moment `hardCC`
and `softCC` exist, `hasUnion` becomes true for debuffs and the round-3 asymmetry silently inverts.

**The concrete failure.** On a **player** debuff container with `uncategorizedDebuffs` set to Show:
`hasUnion` is now true, so that row contributes a group of its own and supersedes the catch-all. Its
only constraint is `excludeSpellIDs` of the union — and Blizzard discards spell-id filters for
debuffs on the player. The engine therefore receives a group with **no effective constraint at all**,
which draws every debuff on the unit and neuters every other Hide on the tab. That is exactly the
failure fix round 3 diagnosed and closed, re-entering through a new door.

**The fix.** The predicate is already implicit in `identityWarning`: Blizzard honours spell ids for
buffs on friendly units and debuffs on hostile ones
(`AuraContainerUtil.CanApplyIdentityCandidateFilters`). Lift it into a named, reusable surface:

```lua
--- Whether the engine honors include/exclude spell ids for this unit and aura type.
function FC.IdsHonored(unit, auraType)
```

`identityWarning` is rewritten to call it, so the warning and the compile decision can never drift
apart. `addCategoryGroups` then gates on it:

```lua
local hasUnion = FC.IdsHonored(unit, auraType) and not isEmpty(cats.union or {})
```

This requires threading `unit` into `addCategoryGroups` (available on `cfg.unit` at the `FC.Compile`
call site).

The union is still **computed** regardless — a Hide's `excludeSpellIDs` costs nothing when the engine
ignores it, and suppressing it would change no outcome. What the gate governs is narrower and
precise: whether an `uncategorized` row may contribute a group of its own and supersede the
catch-all. This preserves round 3's rule exactly as its comments state it — a general rule keyed on
whether ids mean anything for this container, never a per-aura-type special case.

The file's top-of-file comment and `Cat.HARMFUL`'s `uncategorizedDebuffs` comment both assert "the
union is always empty" for debuffs. Both become false and **must** be rewritten to state the real
rule.

### A3. UI and truthfulness

- `settings/GeneralSpells.lua:298` reads "Blizzard only honors spell lists for buffs on friendly
  units." That becomes actively wrong the moment debuff spell lists exist → "…for buffs on friendly
  units and debuffs on hostile ones."
- The Filters page's debuff Categories tab gains the same limitation note its buff sibling and the
  Overrides whitelist (`settings/Filters.lua:600`) already carry: these two rows do nothing on a
  container watching the player or pet.
- New strings land in `locales/enUS.lua` (source locale).

### A4. Testing

TDD, regression first:

1. **The round-3 regression** — a `player` / `HARMFUL` container, `hardCC` Hidden and
   `uncategorizedDebuffs` Shown, asserting no unconstrained group is emitted and the catch-all
   behaves as it did before the categories existed. This fails against today's compiler the moment
   A1 lands, which is the point.
2. **Hostile-target behaviour** — Show and Hide for each new row on a `target` container, asserting
   `includeSpellIDs` / `excludeSpellIDs` as the other `spells` categories are asserted.
3. **`FC.IdsHonored`** — direct unit/aura-type truth table.
4. Existing count and parity suites: `test_defaults`, `test_pages_filters`, `test_locale`,
   `test_schema`.

### A5. Doc ripple

- `docs/scope.md:22` — 34 categories → 36.
- `docs/module-map.md:68` — "17 buff and 17 debuff categories" → 17 and 19.
- `docs/settings-panel.md:148` — "the nine spell categories" → eleven, with the two new keys listed.
- `docs/ARCHITECTURE.md` — the categories table and the filter-priority section.
- `docs/scope.md` "Out of reach" — the spell-id bullet stays true but now has a live debuff consumer.

## Part C — the spell-research process

### C1. The crux: aura ids, not cast ids

The addon's filters match **the aura's** spell id. Many CC abilities are cast as one spell and apply
their aura as another — Freezing Trap is the canonical case. A list built from cast ids would look
fully populated in the editor and **silently never match anything** in game.

The pipeline therefore closes the player-spell pool transitively over
`SpellEffect.EffectTriggerSpell` before matching mechanics. This is the single easiest thing to get
wrong in the whole design and the hardest to notice in play.

### C2. Source data

`wago.tools` DB2 CSV exports, pinned to one build. `https://wago.tools/api/builds` gives the live
retail version (`wow`); at authoring time that was **12.1.0.69875**.

| Table | Why |
| --- | --- |
| `SpellCategories` | spell-level `Mechanic`, and `DiminishType` for provenance |
| `SpellEffect` | effect-level `EffectMechanic`, and `EffectTriggerSpell` for the C1 closure |
| `SpellName` | names, for the `-- Name` comments and the diff's readability |
| `SkillLineAbility` | `ClassMask` and `SkillLine` → the player pool and its class keys |
| `SkillLine` | resolves class skill lines for rows whose `ClassMask` is 0 |
| `SpecializationSpells` | spec-granted abilities |
| `TraitDefinition` | talent-tree-granted abilities (`SpellID`, `VisibleSpellID`) |
| `SpellMechanic` | the mechanic id → name table the bucket map is written against |

Rows are read at `DifficultyID == 0` — the base difficulty — so raid-difficulty variants do not
multiply the set.

### C3. Pipeline

1. **Resolve build** — query the builds API for the live `wow` version, or take `--build` explicitly.
2. **Fetch** the eight tables, to a cache outside git.
3. **Player pool** — union of `SkillLineAbility` rows with a non-zero `ClassMask` **or** a class
   skill line, `SpecializationSpells.SpellID`, and `TraitDefinition.SpellID` / `VisibleSpellID`;
   then closed transitively over `EffectTriggerSpell` (C1). Each id keeps the class set that reached
   it, which is exactly the `spells({ CLASS = … })` grouping the defaults file wants.
4. **Match mechanics** — union the spell-level and effect-level mechanic ids per spell, and bucket:
   - **Hard CC**: charmed (1), disoriented (2), fleeing (5), asleep (10), stunned (12), frozen (13),
     incapacitated (14), polymorphed (17), banished (18), shackled (20), turned (23), horrified (24),
     sapped (30).
   - **Soft CC**: rooted (7), slowed (8), snared (11), dazed (27).

   This bucket → mechanic map is **the one authored, reviewable input**. Everything downstream is
   derived.
5. **Diff** the derived set against the ids shipped in `defaults/Categories.lua` — added, removed,
   renamed — each line carrying id, name and class. The tool **never overwrites** the defaults file.
6. **Emit** the accepted set as a paste-ready Lua fragment in the defaults file's own shape.

### C4. The coverage gate

Silent under-coverage is this design's real failure mode, and it was demonstrated three separate
times while the approach was being validated: a first cut matched 32 hard-CC spells, a second 66, and
only a third — after class skill lines were added — reached 81 and picked up Hammer of Justice,
Entangling Roots and Leg Sweep. Every one of those intermediate runs produced a plausible-looking
list.

So the tool ships a **sentinel list**: a checked-in set of spells that must appear in a given bucket
(Hammer of Justice, Entangling Roots, Leg Sweep, Freezing Trap, Polymorph, Hamstring, Kidney Shot,
Fear and peers). If any sentinel is missing from the derived set, the tool **fails loudly and exits
non-zero**. A thin list then cannot ship by accident, and a patch that restructures a DB2 table
announces itself instead of quietly halving a category.

### C5. The bundle

`docs/spell-research/<YYYY-MM-DD>/`, matching the existing `docs/audits/`, `docs/reviews/` and
`docs/automated-tests/` convention:

- the raw exports, **gzipped** (~10–15 MB per run)
- `SOURCES.md` — build id, table list, source URLs, fetch timestamp
- `derived.json` — the full derived set with names, classes and the mechanics that matched
- `DIFF.md` — the diff against the shipped lists, and which changes were accepted
- `ANALYSIS.md` — the write-up

`docs/` is already `.pkgmeta`-ignored, so none of it reaches a player.

### C6. Provenance

`defaults/Categories.lua` records, per researched list, the build it was last derived against and the
date — so a stale list is visible in the file rather than only in a bundle.

### C7. Honest limitations

- A CC with **no mechanic flag** — a scripted root, an aura that only applies a movement-speed
  modifier — will not be derived. The author's accept step stays a real judgment, not a rubber stamp.
- The player pool is broad by construction; a derived list can contain a spell no player casts in
  practice. Removing it is a diff decision, and the removal is recorded.
- The tool needs network access at run time. The bundle's gzipped exports make any past run
  replayable offline; a *new* run needs wago.tools.

## Standards ripple

`standards/standards/layout.md` §1 draws the repo skeleton and states source lives under the five
named folders, "never loose at the root". It contemplates committed generators — "any generator
committed here is itself authored, and is capped like any other file" — but never says where one
lives. That gap is the standard's, not AuraMaster's: any addon needing a generator hits it.

Decided route: **change the standard upstream.** `layout-§1` gains a `tools/` line in the skeleton
and a sentence placing committed generators there, with the version bump and changelog entry that
implies in `WowAddonStandards`. AuraMaster then plainly conforms, and no deviation row is needed in
`docs/ARCHITECTURE.md`.

Local ripple: `.pkgmeta` gains `tools`; `DEPENDENCIES.md` gains the Python 3 requirement for the
generator.

## Build order

Part C lands first so Part A's spell ids are generated rather than hand-typed.

1. Standards upstream — `layout-§1` gains `tools/`.
2. `tools/spell-research/` and its bundle; the first research run.
3. The compiler fix (`FC.IdsHonored` and the `hasUnion` gate) with its regression test — **before**
   the categories exist, so the test is written against the hazard rather than after it.
4. The two categories, from Part C's accepted output.
5. UI strings, locale, docs.

Green gate before every commit: `lua tests/run.lua` and `luacheck .` (0/0).
