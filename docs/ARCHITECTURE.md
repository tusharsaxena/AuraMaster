# Architecture — Ka0s Aura Master

The engineer's hub for this addon. Each mandated section summarizes and links out; the detail lives
in the topic docs registered under [Documentation map](#documentation-map) (documentation-§3).

## Overview

Ka0s Aura Master draws player-built aura **containers**. A container is one unit (`player`,
`target`, `focus`, `pet` — `core/Constants.lua:39`), one aura type (`HELPFUL` or `HARMFUL` — `:39`;
the player's temporary weapon enchants are the buff category `weaponEnchants`, schema v5) and one style (`bars`, `icons` or
`text` — `:48`), plus its filters, placement and look. A profile holds any number of them; a fresh
profile is seeded with four (`NS.STARTER_CONTAINERS`, `defaults/Profile.lua:259`).

**The design is dictated by one client fact.** On Retail 12.1 an addon cannot read aura data while
auras are secret — combat, encounters, Mythic+ and PvP (`core/Secrets.lua`, `docs/midnight-quirks.md`).
So this addon reads no aura at all. Every container is a Blizzard **AuraContainer**
(`CreateFrame("AuraContainer", nil, anchor, "CustomAuraContainerTemplate")`,
`modules/Container.lua:219`) that registers `UNIT_AURA` for its unit, gathers, sorts, lays out and
animates its buttons in Blizzard's own code. The addon's job is to **declare** what each container
shows and **dress** each button the engine creates:

```
settings row ─► NS.SetByPath ─► CONFIG_CHANGED ─► ContainerManager.RequestApply (next frame, coalesced)
   ─► wait while auras are secret or combat lockdown is on
   ─► Container:Apply ─► FilterCompiler.Compile ─► aura groups + candidate filters
   ─► build the engine (new shape) or update it in place (same shape)
   ─► engine creates buttons ─► initializeFrame ─► Style.Element dresses them ─► engine renders
```

There is therefore **no per-aura Lua path while auras are secret**: no timer and no `OnUpdate`
driving a bar. The one aura-driven Lua path is the readable-state timed-spell scan
(`modules/TimedSpells.lua`), bracketed `timedScan`. It runs only while a container shows auras
without a duration, and only out of combat with auras readable. The full pipeline is in
`docs/data-flow.md`.

### Libraries and what this addon does with each

All vendored under `libs/`, loaded by the `# Libraries` block of `AuraMaster.toc:15-32`.

| Library | Used for |
|---|---|
| LibStub, CallbackHandler-1.0 | Library registry; AceEvent's and AceDB's callbacks |
| AceAddon-3.0 | `NS` promoted to the addon object by `NewAddon` (`core/AuraMaster.lua:17`) |
| AceEvent-3.0 | Lifecycle events and the message bus (`core/Bus.lua`) |
| AceTimer-3.0 | The color picker's drag throttle, via the options descriptor's `scheduleTimer` |
| AceConsole-3.0 | `/am` and `/auramaster` registration (`settings/Slash.lua:535-536`) |
| AceDB-3.0 | `AuraMasterDB` and its profiles (`core/Database.lua:246`) |
| AceGUI-3.0, AceGUI-3.0-SharedMediaWidgets | The settings panel body and its `LSM30_*` media dropdowns |
| AceConfig-3.0, AceDBOptions-3.0 | The Profiles sub-page only (`settings/Profiles.lua`, options-ui-§3) |
| LibSharedMedia-3.0 | Texture, border and font lookups through `LSM` (`modules/Style.lua:33`) |
| LibDataBroker-1.1, LibDBIcon-1.0 | The launcher's broker object and its minimap button (`core/LauncherSetup.lua`, launcher-§1). Both are OPTIONAL: `LibKa0s-Launcher-1.0` resolves them with `LibStub(…, true)` at Register time, so a client missing either degrades rather than raises |
| LibKa0s v1.55.0 | Twelve modules wired, one setup file each — table below |

| LibKa0s module | Setup file | Publishes |
|---|---|---|
| `LibKa0s-Media-1.0` | `core/MediaSetup.lua` | `NS.Icon`, `NS.MediaFont`, the LSM registration |
| `LibKa0s-Env-1.0` | `core/EnvSetup.lua` | `NS.Meta`, `NS.Version` |
| `LibKa0s-Core-1.0` | `core/CoreSetup.lua` | `NS.Print`, `NS.Printf`, `NS.SafeToString`, `NS.ResolveColor`, `NS.ClassColor`, `NS.MakeCloseButton` |
| `LibKa0s-Pool-1.0` | `core/PoolSetup.lua` | `NS.Pool` (preview element pools) |
| `LibKa0s-Lifecycle-1.0` | `core/LifecycleSetup.lua` | `NS.lifecycle` — the one latch; `NS.IsStoodDown`, `NS.IsDisabled`, `NS.SyncEnabled` |
| `LibKa0s-Perf-1.0` | `core/PerfSetup.lua` | `NS.Perf` (buckets, `/am perf`, and the `perf` hold on that latch) |
| `LibKa0s-DebugLog-1.0` | `core/DebugLogSetup.lua` | `NS.DebugLog`, `NS.Debug` |
| `LibKa0s-Launcher-1.0` | `core/LauncherSetup.lua` | `NS.Launcher` — the one LibDataBroker object, registered with LibDBIcon under the folder name |
| `LibKa0s-Slash-1.0` | `settings/Slash.lua` | the `/am` dispatcher over `NS.COMMANDS` |
| `LibKa0s-Compat-1.0` | `core/Compat.lua`, `core/Secrets.lua` | `NS.Compat.GetSpellInfo` (behind this addon's number-only guard) and `NS.Secrets.IsSecret` / `CanAccess` / `IsSafeKey`. Without the library the reader answers `nil` and the guards run this addon's own bodies, a deliberate duplication (a guard stub answering "nothing is secret" on a 12.x client would raise in combat) |
| `LibKa0s-Bus-1.0` | `core/Bus.lua` | `NS.MSG`, through `Bus.Catalog` only (the strict catalog); `NS.BusLib`, the resolved major or its stub. The stand-down record is not taken: `NS.NewBusTarget` stays this addon's own untracked factory (issue #20) |
| `LibKa0s-Options-1.0` | `settings/OptionsSetup.lua` | `NS.Helpers` (the panel shell, flow engine, composers, and the `ChoiceGrid` and `IdList` widgets the Filters and General pages draw) |
| `LibKa0s-Schema-1.0` | `settings/Schema.lua` | `NS.SchemaRuntime`, the one instance over `NS.Schema`: the path primitives, `NS.FindSchemaRow`, `NS.Bulk` and `NS.ValidateSchema` run on it. The write seam stays the host's `NS.SetByPath` (issue #21). Without the library the host bodies answer |

`LibKa0s-Item-1.0` and `LibKa0s-Widgets-1.0` arrive with the whole-folder copy (library-stack-§7)
and are not bound by name here; the addon handles no items. `LibKa0s-Schema-1.0` runs under the
rows but not the write seam (`docs/schema.md`, "Write seam: why AuraMaster keeps SetByPath").
Every setup file degrades to a stub when
the library is absent, exercised by `tests/degraded_env.lua`.

## Module Map

Five source folders in the TOC's load order — `locales/` → `core/` → `defaults/` → `modules/` →
`settings/` (layout-§1) — 48 authored Lua files under them: one locale, 16 core, 4 defaults, 14
modules and 13 settings. The load-bearing positions are annotated at their TOC lines:
`core/MediaSetup.lua` before `core/Constants.lua` (the monospace face), `core/CoreSetup.lua` before
anything that prints, `core/PerfSetup.lua` before every module that takes `NS.Perf` as an upvalue,
`defaults/Categories.lua` before `defaults/Profile.lua` (the template's category states) and
`defaults/UserCategories.lua` directly after it (the `NS.Categories` upvalue),
`settings/OptionsSetup.lua` before every page file (the composers run at file load), and
`settings/GeneralSpells.lua` before `settings/General.lua`, which registers its rows after its own.
The Settings tree's order is the TOC's own registration order (`N-2`): General, then Containers,
then its five sub-pages — Filters, Layout, Bars, Icons and Text, each marked with
`NS.SubPageLabel`'s indent (`D6`, `settings/OptionsSetup.lua`) — then Profiles.

The engine-facing core is four modules: `modules/FilterCompiler.lua` (settings → groups, pure; the
profile's spell-category edits reach it through `FC.ProfileContext`), `modules/Container.lua` (one
engine), `modules/ContainerManager.lua` (the registry and the deferred apply, each container's apply
guarded so one error cannot drop the rest of the pass) and `modules/Style.lua` with its three style
files (`Style_Bars.lua`, `Style_Icons.lua` and `Style_Text.lua`, chosen per container by
`Style.Styler`), plus the pure template parser the Text style draws from
(`modules/TextTemplate.lua`). Placement is `modules/Anchors.lua`. A container attached to another
continues its chain root's flow (`Anchors.EffectiveLayout`, `Anchors.DerivedPoints`), and a write to a
flow or attachment path re-applies its followers (`Anchors.Followers`). While a container previews,
the containers attached to it hang from `Preview.Extent`, a frame of ours sized to its placeholder
block (`Anchors.PlaceAttached`). Previewing is the session-only **test mode**
(`NS.State.testMode`, switched only by `Preview.SetTestMode`): every container shows its placeholder
auras. Unlocking is separate: it makes containers draggable while their live auras keep drawing,
each under its drag handle and a faint outline one element in size, so an empty container can
still be found and dragged.

Every non-vendored file, its responsibility and the full load order: `docs/module-map.md`.

## Settings Schema

`NS.Schema` holds **242** rows across seven pages: General 18 (its Dispel Colors tab's five and its
Spell Categories tab's three `enchantSlots` rows among them), Containers 5 (`N-1`, batch 7 — split
out of General's own tab), Filters 43, Layout 26, Bars 72, Icons 42 and Text 36. The
AceConfig-drawn Profiles page carries none. That is the count on a profile with no categories of the
player's own; **the schema is a live table, not a frozen one**, and each user category adds one
`container.filter.categories.<key>` row at runtime (`NS.RegisterSchemaRows(rows, beforePath)` inserts
it in schema order, `NS.UnregisterSchemaRows(pred)` takes it down again on a profile switch, and
`NS.Schema` is rebuilt in place so the live reference the options descriptor and the CLI hold stays
the same table — `docs/schema.md`). It drives the panel,
`/am list|get|set|reset` and the resets; one write seam, `NS.SetByPath` (`settings/Schema.lua:790`),
is where the panel, the CLI, the Defaults buttons and a drag handle all land. It resolves the
container, validates against it, runs the row's optional `normalize` hook, writes, reacts and
announces, in that order.
The name row's hook stores container names unique, case-insensitively. A bulk copy or reset (a page's
Defaults, Reset all, `ContainerManager.CopyFrom`, `ContainerManager.ResetPositions`) runs inside
`NS.Bulk`'s bracket: the seam mutes its per-row `[Set]` line, tallies the rows each write changed as
it stores them, and the act logs one `[Set] <act> <scope>: N rows` line. An act that an error stops
still logs that line once, ending ` (stopped by an error)`. A whole-profile reset is logged by
`NS.OnProfileReset` alone, as `[Set] reset profile '<name>' to defaults` with no row count
(debug-logging-§10 allows omitting it). A reset re-seeds the starter containers, so counting rows not
at default would overcount. AceDB also gives no hook before the wipe, so the Profiles page's reset
cannot cheaply snapshot the rows it changes (`docs/schema.md`, `docs/profiles.md`).

Almost every row belongs to one container, so container rows use a **relative path**:
`container.bars.width` resolves against the container the settings banner has selected
(`NS.State.activeContainerId`), falling back to the first one. Addon-wide rows keep absolute paths
(`enabled`, `hideBlizzardBuffs`). **One row resolves outside the profile entirely:**
`global.minimap.shown` names LibDBIcon's own key in the GLOBAL store, `global.minimap.hide`, so the
seam answers and writes it directly, inverting on the way (the path and the row say shown, the
stored key says hidden) and telling `NS.Launcher` so the button moves at once. A row's `default` is never typed in a page file —
`NS.RegisterSchemaRows` stamps it from `defaults/Profile.lua`, and `NS.ValidateSchema` proves every
path resolves. Three whole-set carve-outs (`container.filter.whitelist`, `.blacklist`, and the
profile-wide `categorySpells`) and six whole-section paths (`container.filter`, `.layout`, `.behavior`,
`.position`, `.bars`, `.icons`) are written through the same seam and normalized there. A drag, a
copy between containers, a position reset and a delete's fallback to the screen all write that way.

The addon holds one structural registry, the containers (architecture-§5). No schema row addresses
it, and none can, since a row is a leaf.

- **Storage keys:** the profile's `containers` (members keyed by numeric id, each stamped with its
  `c.id`), `containerOrder` (display order), `nextContainerId` (the id counter) and `seeded` (the
  sentinel recording that first-run seeding has run).
- **Registry writer:** `modules/ContainerManager.lua`. `ContainerManager.Create`, `.Delete` and
  `.Duplicate` (through `Create`) make every runtime membership change, and
  `Database.NewContainerData` mints the id and stamps `c.id` for it. `NewContainerData` has no
  other caller, so it is part of the writer.
- **Load pass:** `Database.PrepareProfile` (`core/Database.lua`), run from `NS.RunMigrations` at
  initialization and from `NS.OnProfileChanged` on AceDB's profile changed, copied and reset
  callbacks, and from nowhere else. It runs `seedStarters`, `normalizeKeys`, `backfillContainers`,
  the `nextContainerId` bump and `rebuildOrder`.

A member field a row addresses goes through `NS.SetByPath` with a container id even when
ContainerManager is the caller: rename, copy-from, position reset and a delete's fallback to the
screen. The per-container `container.filter.whitelist` and `.blacklist` sets, and the profile-wide
`categorySpells` set, are values the seam takes whole at its carve-out paths, not registries. Only
its named writer and load pass write the registry, so it is compliant and carries no Documented
deviations row.

The addon holds a second structural registry since issue #10, the player's own spell categories. No
schema row addresses the registry itself; the row each member GETS is an ordinary category row.

- **Storage keys:** the profile's `userCategories` (one record per category, keyed by a `user…` key
  that is minted once and never moves) and `userCategoryOrder` (declaration order, their only
  ordering source). The member's spell list is not part of the registry — it is
  `categorySpells[key]`, the same carve-out every other category's edits live in.
- **Registry writer:** `defaults/UserCategories.lua`. `Cat.CreateUserCategory`, `Cat.RenameUserCategory`,
  `Cat.DeleteUserCategory` and `Cat.ForgetUnusableUserRecords` make every membership change, and
  `Cat.NewUserKey` mints the key for `Create` and has no other caller. Nothing else writes a record,
  and **nothing anywhere writes `rec.auraType` but `Create`**, which is what makes a category's aura
  type immutable: it is the absence of an act rather than a refusal.
- **Load pass:** `Cat.SyncUserCategories(profile)`, run from `NS.RunMigrations` after the whole schema
  ladder and before `Database.PrepareProfile`, from `core/AuraMaster.lua`'s `prepareProfile` (so a
  profile switch, copy and reset all pass through it), and from each act above. It tears the previous
  set down and builds the new one as ONE act over four mirrors — the two definition lists, the
  container template's `filter.categories`, and the schema rows — because a stale definition left
  behind makes `Cat.IsSpellCategory(deadKey)` true and quietly takes ids out of the complement
  `Uncategorized` is defined against. Not at panel render: a row that existed only while the panel was
  open would be invisible to `/am get|set|list`, to a page's Defaults and to the resets.

**Materialized into the shipped lists, deliberately.** A stored record becomes an ordinary
`spells`-kind definition inside `Cat.HELPFUL` or `Cat.HARMFUL`, inserted in front of that aura type's
Weapon enchants or Uncategorized row. Every reader was then already correct for it: `Cat.Find` and
therefore `Cat.AuraTypeOf`'s key form, `modules/FilterCompiler.lua`'s `categorizedUnion`,
`settings/Filters.lua`'s grids, the CLI. The alternative — a parallel path per reader — would have
been five places to keep in agreement rather than one rebuild per profile change. **The keys live in a
reserved `user` namespace** (`Cat.IsUserKey`) that no shipped key may take, asserted by
`tests/test_defaults.lua`; a stored record outside it is refused rather than materialized, because a
record keyed `healing` is a claim on a shipped category's identity and the next sync's teardown would
take the SHIPPED category's container-template entry down with it.

The surfaces this added, all read by name rather than duplicated:

| Surface | Answers |
|---|---|
| `Cat.AuraTypeOf(defOrKey)` | Which aura type a category holds, from `def.auraType` or through `Cat.Find` |
| `Cat.LabelOf(def)` | A category's name AS SHOWN — a shipped label routed through `NS.L`, a user label never. THE labeling rule; every drawing site asks it, and the panel's `(yours)` marker wraps it rather than copying it |
| `Cat.IsUserCategory(defOrKey)` / `Cat.IsUserKey(key)` | Whether the player made it; whether a key sits in the reserved namespace (structural, not a guess at how the key was made) |
| `Cat.CreateUserCategory` / `RenameUserCategory` / `DeleteUserCategory` | The three acts, each refusing anything without a stored record and anything outside the namespace |
| `Cat.UnusableUserRecords` / `Cat.ForgetUnusableUserRecords` | The records the sync refuses, and the way to be rid of them |
| `Cat.SanitizeUserName` / `Cat.CharCount` / `Cat.USER_NAME_MAX` | The stored form of a player-supplied name, capped in CHARACTERS — the same count `EditBox:SetMaxLetters` applies, so the box and the store cannot disagree |
| `Cat.SyncUserCategories` / `Cat.UserCategoryOrder` / `Cat.HasUserRecord` / `Cat.UserKeysInUse` / `Cat.NewUserKey` / `Cat.UserCategoryNameTaken` | The load pass, the order reconcile, the record test `settings/Schema.lua` asks before a `categorySpells` write, and the key machinery |
| `Database.EachProfile(db, fn)` | Every stored profile, the inactive ones included — the schema ladder's own walk, published so the delete sweep reaches the same set rather than growing a second walk that drifts |
| `NS.CategoryRow(def)` | One category's Show/Hide row, exported by `settings/Filters.lua` so the runtime rows are built by the same function as the shipped ones |
| `NS.RegisterSchemaRows(rows, beforePath)` / `NS.UnregisterSchemaRows(pred)` | Insert rows in schema order, and remove them again |
| `FC.ClaimingCategories(Cat, auraType, filter, edits, id)` | Which categories hold a spell id — `ExplainSpell`'s own answer, published so the overlap guardrail cannot drift from it |
| `NS.GeneralSpells.MarkedName` / `.RestoreStarters` / `.Select` | The one `(yours)` marker, muted gold included, that both surfaces read, the restore ACT behind the button's absence, and the Filters page's per-row link |

The addon holds two pieces of named non-setting state (architecture-§5). The first is learned
data that no control sets and no row addresses.

- **Storage key:** `global.timedSpells` (`db.global.timedSpells`), `[spellId] = true` for every buff
  seen carrying a duration. It is account-wide, so a profile switch, copy or reset never touches it.
- **Owner:** `modules/TimedSpells.lua`.
- **Writers:** `TS.Scan` adds the id of each newly seen timed buff. The readable-state scan reaches
  it: `scanTick`, 0.5 s after a player or pet `UNIT_AURA` or after the readable gate reopens.
  `TS.Forget` replaces the set with `{}`, and `/am forgettimed` reaches it (`runForgetTimed` in
  `settings/Slash.lua`). That is the owner's forget operation. Nothing else writes it. `store()`
  lazily creates the empty table on first read and is not a writer, and neither is the load pass
  (`NS.RunMigrations` backfills it, as does the no-AceDB fallback in `NS.InitDB`). The two compile
  sites in `modules/Container.lua` and `settings/OptionsSetup.lua` hand it to `FilterCompiler.Compile`,
  which only reads it.

The second is recorded data that a vendored library writes into a key the addon hands it: the perf
capture ring. No control sets it and no row addresses it.

- **Storage key:** `AuraMasterPerfDB`, a SavedVariables global of its own (`AuraMaster.toc:7`),
  outside the AceDB tree, so a profile switch, copy or reset never touches it (performance-§5).
- **Owner:** `core/PerfSetup.lua`, which hands the key to `LibKa0s-Perf-1.0` as the descriptor's
  `sv`.
- **Writers:** the library's `P.Save`, and nothing else. `/am perf finish` reaches it. It appends the
  finished capture, drops the oldest record once the ring holds more than ten (the library's
  `DEFAULT_RING`, since this addon sets no `ring`), and discards a ring stored under an older record
  schema. No addon code writes it, and no verb clears it.

SavedVariables shape, every default and the migration path: `docs/schema.md`.

## Locale routing, and its one exemption

Every user-visible string routes through `NS.L`, the key being the English text itself
(localization-§2), and `tests/test_locale.lua` fails the build twice over: on a routed string with no
`locales/enUS.lua` line, and on an `enUS` line nothing routes. A label routed BY VALUE — a
`core/Constants.lua` `*_LABELS` entry, a category's `label` and `desc` — still needs its own line,
because `NS.Choices` and the drawing sites look them up with `L[…]`.

**A user category's name is the one exemption** (issue #10), and it is written here so the guard test
can be read from it. The name is the PLAYER'S OWN TEXT: it is data, no `enUS` line can exist for it,
and none should. The exemption is exactly one FIELD of exactly one flagged definition kind —
`def.label` on a definition carrying `userCategory = true`. Its `desc` is still checked, and a user
category's description is a fixed shipped string precisely so that it can be; if that description ever
has to name the category, the name is a `%s` ARGUMENT to a routed format string and never concatenated
into one, because a `%` inside a player-supplied name is an ordinary character.

The exemption is enforced at the draw by `Cat.LabelOf`, which is why every site that shows a category
name asks it rather than indexing `NS.L`. This is not tidiness: `NS.L` answers its own miss path, so
`L[def.label]` looks correct for a user category right up until a player names one "Healing" — at
which point the lookup finds a real shipped line and the panel shows the shipped string instead of the
name that was typed. Invisible on enUS, plainly wrong on any translated client. The guard proves the
exemption narrow from both sides: `tests/test_locale.lua` asserts that NO shipped definition claims it
on the shipped load, and `tests/test_defaults.lua` asserts that a user definition's name is unrouted
while its description is not.

## Filter priority

`modules/FilterCompiler.lua` decides whether one container draws a given aura by one order, highest
rank first (revised by the owner 2026-09-15). `FC.ExplainSpell` answers the same question for a
single spell id, under the same order, and is what the settings panel reads it from — the per-entry
notes under Filters → Overrides' Whitelist and Blacklist (K-3), and the warnings `FilterCompiler.Compile`
attaches to the container.

| Rank | Rule | Outcome |
|---|---|---|
| 1 | On the Overrides **whitelist** | **Shown.** Always, whatever anything else says |
| 2 | On the Overrides **blacklist** | **Hidden**, unless rank 1 already claimed it |
| 3 | In **at least one** category set to Show | **Shown**, even if it is also in a category set to Hide |
| 4 | In one or more categories, **all** of them set to Hide | **Hidden** |
| 5 | In **no** category at all | **Shown** — nothing removed it |

Stated as one sentence: an aura is hidden when the blacklist names it, or when every category it
belongs to says Hide; everything else is drawn, and the whitelist overrides both. A category set to
Show is a positive claim, not merely the absence of a Hide, so rank 3 rescues an aura from a Hide
elsewhere — a Defensive that is also Cancelable is not dropped just because Cancelable says Hide.

**How that compiles.** The engine ANDs the constraints inside one group and ORs the groups, so "in
ANY shown category" is a union and needs a group per Shown category. With nothing Hidden, exactly
one group is emitted (the base minus the whitelist) — a Show cannot rescue anything when nothing is
hiding, so the extra groups would be pure cost. Once anything is Hidden, one group per Shown category
is emitted, followed by a catch-all group that draws an aura in no category at all (rank 5). A
container with anything Hidden therefore compiles to roughly 15 groups on buffs and 17 on debuffs,
not one, and the "Max auras"
cap applies **per group**, not to the container as a whole (`container.filter.maxAuras`,
`docs/schema.md`). The catch-all is skipped instead of joined whenever an `uncategorized` category
exists for the aura type (batch 7 `U-1`..`U-5`; both HELPFUL and HARMFUL carry one as of fix round 3)
and its state actually supersedes the catch-all: Hide always does, on either aura type — that row's
Hide IS the catch-all, made controllable, reproducing the retired **"only these categories"** toggle
exactly. Show does too, but only where `FC.IdsAlwaysHonored(unit, auraType)` holds — buffs on the
`player` and `pet`, and nowhere else (issue #11, 2026-09-20). There the row's own group is a real
rescue, already a strict superset of what the catch-all would draw. Everywhere else Show contributes
NO group of its own and the catch-all runs normally, because the row's only constraint is
`excludeSpellIDs` and the engine discards spell ids for buffs on a hostile unit and for debuffs on a
friendly one: the group would carry no effective constraint at all, drawing every aura of its type
and defeating every other category's Hide. That reaches further than the debuff case issue #11
added — a hostile `target`/`focus` **buff** container has always been able to emit exactly that
group, which is why the gate asks the unit rather than the aura type. The per-container **"only these
categories"** toggle that used to drop the catch-all a different way (`container.filter.onlyShown`)
is RETIRED (batch 7 fix round 2): once `uncategorized`'s Hide correctly reproduces it on both aura
types (fix round 3 restored the debuff row after fix round 1 dropped it), the toggle had nothing left
to do. A schema v4 migration (`docs/schema.md` → Migration path) converts a stored
`onlyShown = true` accordingly on either aura type; only a container of some other, unrecognized
shape has no category to migrate onto and loses the narrowing, logged and told to the player
directly (`NS.Print`), not silently. Full detail: `docs/data-flow.md` → Step 4.

## Message Bus

A closed bus on AceEvent messages (`core/Bus.lua`, architecture-§4). Every receiver subscribes on its
own target from `NS.NewBusTarget()`, so no two receivers can clobber each other. The catalog below
is declared through `LibKa0s-Bus-1.0`'s `Catalog`, which validates the four wire names at load and
hands back a strict copy: a mistyped `NS.MSG` key raises at the call site, for a publisher as well
as a subscriber. Without the library the same table is used plain, and a mistyped key reads nil
(the one thing a degraded install loses here). `NS.NewBusTarget()` stays this addon's own untracked
factory, not the major's stand-down record: every receiver stands down in its own module (issue #20). There is
deliberately **no aura-data message**: the engine owns `UNIT_AURA` and nothing here reads an aura to
pass on.

| Message | Sender | Payload | Consumers |
|---|---|---|---|
| `Ka0s_AuraMaster_ContainersChanged` (`NS.MSG.CONTAINERS_CHANGED`) | `modules/ContainerManager.lua` — create, delete, rename, duplicate, profile change (copy-from and reset positions are settings writes, announced by `CONFIG_CHANGED`) | none | `settings/OptionsSetup.lua:384` — `NS.RequestPanelRefresh`, a coalesced panel re-render (every banner lists containers); `modules/TimedSpells.lua:204` — `TS.Sync`, which starts or stops the timed-spell scan (a container added or removed can change whether any needs it) |
| `Ka0s_AuraMaster_ConfigChanged` (`NS.MSG.CONFIG_CHANGED`) | `settings/Schema.lua:539` — the write seam, once per write; never for a session row | `{ section, containerId, path }`; `containerId` nil for an addon-wide row, `path` the row written | `modules/ContainerManager.lua:561` — by the row's `effect`: `"visibility"` runs `ApplyVisibility()` at once, `"none"` queues nothing, otherwise `RequestApply(containerId)` (nil re-applies all), and a write to a flow or attachment path also re-applies every container following that one (`Anchors.Followers`); `modules/TimedSpells.lua:203` — `TS.Sync`, the same re-sync (a filter write can change whether any container needs the scan) |
| `Ka0s_AuraMaster_VisibilityChanged` (`NS.MSG.VISIBILITY_CHANGED`) | `core/AuraMaster.lua` — entering the world, combat start and end | none | `modules/ContainerManager.lua:584` — `ApplyVisibility()` over every container |
| `Ka0s_AuraMaster_TimedSpellsChanged` (`NS.MSG.TIMED_SPELLS_CHANGED`) | `modules/TimedSpells.lua` — a scan learned timed spells, or `/am forgettimed` emptied the set | none from a scan; `{ byPlayer = true }` from `/am forgettimed` | `modules/ContainerManager.lua` `CM.Init` — `RequestApply(nil, system)` over every container (their excluded ids moved); a scan's request is the addon's own, so a deferral of it prints no notice |

Four messages, well under the more-than-ten trigger for a separate `message-bus.md`.

## Slash Commands

`/am` with `/auramaster` as the long alias, dispatched by `LibKa0s-Slash-1.0` over the addon's own
ordered `NS.COMMANDS` (`settings/Slash.lua:33`). Twenty-two verbs; `options` is an alias of `config`.
A bare `/am` runs `config`, opening the settings panel on its landing page (slash-commands-§4); `/am
help` prints the list.
`/am test` is the test mode's verb (preview-mode): unlocking no longer previews, so the placeholders
have a switch of their own, shared with the Master controls *Test mode* checkbox and the minimap
button's left click.

| Command | What it does |
|---|---|
| `/am help` | List available commands |
| `/am config` | Open the settings panel (a bare `/am` does the same) |
| `/am enable` | Turn Aura Master on (every enabled container shows again) |
| `/am disable` | Turn Aura Master off (hides every container) |
| `/am list` | List every setting and its current value (container settings read the selected container) |
| `/am get path` | Print a setting's current value |
| `/am set path value` | Set a setting |
| `/am reset path` | Reset one setting to its default |
| `/am resetall` | Reset every setting to defaults (a profile reset) |
| `/am containers` | List your containers; the selected one is marked |
| `/am select id-or-name` | Choose the container settings apply to |
| `/am new [unit] [type] [style]` | Create a container (`player`/`target`/`focus`/`pet`, `buffs`/`debuffs`/`enchants`, `bars`/`icons`/`text`) |
| `/am delete id-or-name` | Delete a container |
| `/am lock` | Lock every container in place |
| `/am unlock` | Unlock containers so they can be dragged |
| `/am test [on\|off]` | Toggle test mode: placeholder auras on every container; refused in combat |
| `/am pick` | Attach the selected container to a frame by clicking it |
| `/am resetposition` | Move every container back to its default screen position |
| `/am forgettimed` | Forget which buffs were learned to have a duration |
| `/am debug [on\|off]` | Toggle the debug console; `on`/`off` enable or disable logging |
| `/am perf …` | Measure performance — bare `/am perf` opens the workflow |
| `/am version` | Print the addon version |

**While the addon is disabled** the eight verbs that drive its features — `new`, `delete`, `lock`,
`unlock`, `test`, `pick`, `resetposition`, `forgettimed` — answer on one tagged line naming `/am enable` and
do nothing else (slash-commands-§2). Everything else keeps working, the bare `/am` included: it
opens the settings panel, which is the surface a player switches the addon back on from by hand. The
gate is `LibKa0s-Slash-1.0`'s, closed by the descriptor's `isEnabled` in `settings/Slash.lua` with
`liveVerbs` naming the live set as data; a verb added to `NS.COMMANDS` refuses by default.
The Master controls **Test mode** checkbox and the launcher's left click refuse a start the same way,
on the same line; turning test mode off stays allowed.

Dispatch, the host verbs, the container-relative paths and the degraded path: `docs/slash-dispatch.md`.

`enable` and `disable` are **aliases, not state**: both write the Master controls Enable row's own
path through `NS.SetByPath`, so the verb and the checkbox cannot disagree. The dispatcher is
registered in `OnInitialize` and is never torn down, so every verb — `enable` above all — still
answers while the addon is disabled (slash-commands-§2). What disabling *does* do is
`## The disabled state`, below.

## Launcher

**One object, registered twice** (launcher-§1). `core/LauncherSetup.lua` owns it: it builds a single
LibDataBroker-1.1 object of `type = "launcher"` through `LibKa0s-Launcher-1.0` and hands that very
object to LibDBIcon-1.0, so the minimap button and any broker display (Titan Panel, ElvUI data
texts, Bazooka) draw from one icon, one label and one `OnClick`. `NS.Launcher:Register()` is called
from `OnInitialize` after `InitDB`, and is idempotent.

| | |
|---|---|
| Owner | `core/LauncherSetup.lua` → `NS.Launcher` |
| Registered as | `AuraMaster` — the **folder name**, on both registrations, because LibDBIcon keys the button's saved position by it |
| Icon | `C.LOGO_ICON_PATH`, the same file `## IconTexture` names (launcher-§4) |
| Label | `Ka0s Aura Master` — the **brand name in plain text** (launcher-§1). What a broker display prints in its row, beside the other ten Ka0s addons, so it is spelled the way they are. Deliberately not the TOC `## Title` (a Title may carry color escapes) and not the folder name |
| Left click | **Rung (b)**: toggles test mode, by calling `NS.Slash.ToggleTestMode` — the same host verb a bare `/am test` runs, which switches it through `Preview.SetTestMode`. The launcher holds no copy of the mode. **While the addon is disabled** the left click is refused by `LibKa0s-Launcher-1.0`'s own gate (minor 2), fed by the descriptor's `isEnabled` and `disabledLine` (the dispatcher's refusal line); right-click is never gated |
| Right click | Always `NS.OpenOptionsPanel()`. Neither button is reassignable and there is no setting for either |
| Visibility | The **Minimap button** row. Its CLI path is `global.minimap.shown`, which answers true while the button shows; its storage is LibDBIcon's own `global.minimap.hide`, in the global store, never a second `shown` key (launcher-§3, anti-pattern #81, `docs/settings-panel.md`) |
| Survives every reset | A per-installation display preference, like the button's position, so **no** reset the panel runs may move it — neither *Reset all settings* nor the General page's **Defaults** button. The one veto is `vetoedFromPanelReset` in the options descriptor's `applyDefault`, the library's single reset seam. `/am reset global.minimap.shown` is deliberately **not** vetoed: that is the player naming this one row |

**Rung (b) because the addon has a test mode.** This addon has no primary window; its preview is
the session-only test mode, switched by the Master controls *Test mode* checkbox (unlocking no
longer previews: live auras keep drawing while containers are unlocked). The left button therefore
spends itself on that switch, which it can because the panel is already on the right button.

**Both broker libraries are optional.** `LibKa0s-Launcher-1.0` resolves them with
`LibStub(…, true)` at Register time, so a client with LibDataBroker but no LibDBIcon gets the
broker plugin and no button, one with neither gets a line naming what is missing, and one without
LibKa0s at all gets this file's stub. In every case the stored `hide` is still written, so the
checkbox reflects what the player chose and a later reload draws the button where they left it.

## Event Subscriptions

| Event | Registered by | Handler → effect |
|---|---|---|
| `PLAYER_ENTERING_WORLD` | `core/AuraMaster.lua:59` (AceEvent, through `NS.SafeRegisterEvent`) | `OnEnterWorld` → `VISIBILITY_CHANGED`, `ContainerManager.FlushPending` |
| `PLAYER_REGEN_DISABLED` | `core/AuraMaster.lua:60` | `OnCombatChanged` → `VISIBILITY_CHANGED` |
| `PLAYER_REGEN_ENABLED` | `core/AuraMaster.lua:61` | `OnCombatChanged` → `VISIBILITY_CHANGED`, `FlushPending`, `ReapplyStaleClass`, `BlizzardFrames.Apply`, `Anchors.ResolvePending` (a frame that appeared during combat) |
| `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED` | `core/AuraMaster.lua:62-63` | `OnUnitSwap` → `RefreshUnit` → the engine's `UpdateAllAuras` (bucket `unitSwap`); re-applies the class-colored containers of that unit when the new unit's class differs, or marks them stale, silently, while an apply must wait |
| `UNIT_PET` | `core/AuraMaster.lua:64` | `OnUnitPet` (player only) → `RefreshUnit("pet")` (bucket `unitSwap`); re-applies the class-colored pet containers when the pet's class differs, or marks them stale while an apply must wait |
| `ADDON_LOADED` | `core/AuraMaster.lua:65` | `OnAddonLoaded` → `Anchors.ResolvePending` (frame-attached containers) |
| `ADDON_RESTRICTION_STATE_CHANGED` | `core/AuraMaster.lua:67` | `OnRestrictionChanged` → `FlushPending`, `ReapplyStaleClass` (a deferred apply runs when secrecy lifts) |
| `UNIT_AURA` for `player` and `pet` | `modules/TimedSpells.lua` — the module's one private frame, `TS.unitFrame` (events-frames-taint-§1's carve-out: the vendored AceEvent has no `RegisterUnitEvent`), through `NS.SafeRegisterUnitEvent`; built once and reused, registered only while a container uses "without a duration", the addon is not suspended, and auras are readable (no combat lockdown, not secret), and unregistered by hand in `TS.Stop` | the frame's one `OnEvent` → `onUnitAura`: the client delivers only `player` and `pet`; the handler still proves the unit a safe key and compares it (defense in depth), then schedules a scan 0.5 s later (bucket `timedScan`). A scan that comes due after the gate closed is dropped too |
| `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`, `ADDON_RESTRICTION_STATE_CHANGED` | `modules/TimedSpells.lua` (AceEvent, on its own target) — while a container uses "without a duration" and the addon is not suspended | `syncAuraListen`: `PLAYER_REGEN_DISABLED` closes the readable gate by itself (it fires before combat lockdown begins); the other two re-check it, dropping or restoring `UNIT_AURA`; reopening schedules one scan |
| AceDB `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset` | `core/Database.lua:249-253` | `NS.OnProfileChanged` / `NS.OnProfileCopied` / `NS.OnProfileReset` → re-prepare the registry, trace the event once in its own words (a switch `[Profile] changed -> X`; a copy or a reset one `[Set]` line, debug-logging-§10), rebuild, re-render |

Each container's own `UNIT_AURA` belongs to the engine (`SetUnit`, `modules/Container.lua:264`) and
is not addon code. The eight `core/AuraMaster.lua` registrations are one module-level list,
`LIFECYCLE_EVENTS`, which `RegisterLifecycleEvents` and `UnregisterLifecycleEvents` both walk, so the
stand-down and the stand-up remove and restore the same list.

**Every registration goes through one helper** (events-frames-taint-§1): `NS.SafeRegisterEvent`, which
is `LibKa0s-Core-1.0`'s `SafeRegisterEvent`, published by `core/CoreSetup.lua`. That covers every row
above and the stand-down's pending `PLAYER_REGEN_ENABLED`, except the unit frame's `UNIT_AURA`, which
goes through its unit-event twin, `NS.SafeRegisterUnitEvent`. A name the client does not know costs only
itself: the rest of the block still registers, and the name is appended once to `NS.RejectedEvents`.
Where a player sees it: the `[Init]` line that `/am debug` writes adds `rejected events: A, B` when
the list is not empty (`core/DebugLogSetup.lua`), and a name refused while logging is on is traced as
`[Init] event <NAME> rejected by this client` when it happens. What a refused name costs is written
up in `docs/midnight-quirks.md` ("An unknown event name raises").

**Every row in this table is gone while the addon is stood down** — unregistered, not gated. The one
exception is `PLAYER_REGEN_ENABLED`, which a stand-down that combat refused re-registers on its own
handler until the combat-restricted half finishes; see below.

## The disabled state

**Disabled means the addon is not running.** Not hidden, not quiet, not skipping a repaint — not
running (slash-commands-§7). Unticking *Enable Aura Master*, or `/am disable`, or a profile switch to
a profile where the path is false, all land on the same seam and all produce the same outcome.

**One latch, two named holds.** `core/LifecycleSetup.lua` builds one `LibKa0s-Lifecycle-1.0`
instance. `disabled` is taken from the stored `enabled` path and is persisted; `perf` is taken by
`LibKa0s-Perf-1.0` for a capture's suspended arm and is session-only. The addon is down whenever at
least one hold is taken and comes back only when the last one is released, so `/am enable` during a
capture does not resurrect it mid-run and a resume at the end of one does not stand up an addon the
player switched off. There is no `StandUp()` to call; the only route out is releasing a hold.

**What stands down**, in the same turn as the write:

| | |
|---|---|
| The eight lifecycle events | `addon:UnregisterLifecycleEvents()` — unregistered, not gated |
| `modules/TimedSpells.lua` | `TS.StandDown()`: its unit frame's `UNIT_AURA` (unregistered by hand; the frame is kept for the next stand-up), its gate events, its two bus subscriptions, and a queued scan timer, canceled |
| `modules/ContainerManager.lua` | `CM.StopListening()`: its three bus subscriptions, and the pending queue behind them |
| The coalescing apply timer | canceled by `CM.StopListening`; `CM.RequestApply` returns immediately, so nothing re-arms |
| `modules/FramePicker.lua` | `FP.Stop()` — the overlay's `OnUpdate` cleared |
| Every container | `ContainerClass:ShouldShow` answers no at **step 0**, so the engine is disabled, the preview and handle hidden and the anchor hidden |
| Blizzard's buff and debuff frames | reparented back where they belong: an addon that is not running must not still be hiding them |

**What survives, because it is setup and not a feature:** the chat command registration, the
dispatcher and `NS.COMMANDS`; the settings-category registration and the panel body; the AceDB
handle, `NS.SetByPath` and AceDB's three profile callbacks; the launcher's registration. The slash
surface is unchanged — see *Slash Commands* above.

**The combat carve-out.** Hiding a container's anchor is hiding an aura engine's ancestry, and
reparenting a Blizzard frame is refused under lockdown, so neither is attempted in combat. The
stand-down holds that half pending and finishes it on `PLAYER_REGEN_ENABLED` — the one registration a
disabled addon keeps — releasing it the moment it fires.

**Standing up rebuilds from current state**, never from a snapshot taken on the way down: a setting
changed while the addon was off is reflected when it comes back.

**A stood-down addon builds no container frame.** A login with the addon disabled builds none
(`CM.Init` reads the latch before `CM.Sync`), and neither does a profile switch, copy or reset made
while it is down (`CM.Announce` skips its sync, but still sends `CONTAINERS_CHANGED` so an open panel
re-renders). The stand-up calls `CM.Sync` before its visibility pass, so it builds, or revives, every
container the registry holds at that moment and draws them in the same turn. A profile change made
while down is remembered and passed to that sync, so a stand-up in combat parks every id the switch
reused, exactly as `CM.Announce(true)` would have, until the deferred apply rebuilds it.

**Not a draw gate.** A handler that early-returns has not stopped watching, it has stopped reacting,
and the client still walks the registration list and still enters Lua on every event
(anti-pattern #85). `tests/test_disabled.lua` therefore asserts on the registration set, the live
timer set, the shown frames, the SavedVariables writes and the printed lines — never on a handler's
return value.

## Taint Notes

- **No secure template of our own.** The only protected machinery is Blizzard's aura engine. Each
  container's anchor (`AuraMasterAnchor<id>`) inherits `DisableUntrustedLayoutScriptsTemplate`,
  Blizzard's opt-in for a frame anchored to an aura container (`modules/Container.lua:41-44`).
- **Nothing under an anchor may own a tooltip.** The template's restriction reaches every frame
  anchored under the anchor, the drag handle and its help mark included, and the client refuses
  `GameTooltip:SetOwner` on any of them ("Anchoring disallowed as dependent object would inherit
  forbidden aspects: UntrustedLayoutScriptExecution"). The handle's tooltip is therefore owned by
  `UIParent` and follows the cursor (`modules/Anchors.lua`, `showTooltip`).
- **Anchors stay out of the client's layout cache.** An anchor is movable (a handle drag moves it
  with `StartMoving`), and the client saves a movable frame's position and restores it at login.
  `Container.New` calls `SetDontSavePosition(true)`, so the stored `container.position` is the only
  position an anchor ever has.
- **The drag handle sits outside the anchor and never re-anchors anything.** It is our own strip,
  placed against the anchor on the side the auras do not grow into; the anchor, the engine and the
  preview stay where they are. While it shows, the anchor's clamp rect is widened over it
  (`SetClampRectInsets`). Placing the strip and widening the clamp both happen only out of combat,
  because the anchor parents an aura engine: under lockdown the handle keeps its last placement and
  only shows or hides, except that a handle never placed (first shown in combat) is placed once so
  it draws. The next visibility pass after combat catches both up.
- **The engine is anchored before its first `AddAuraGroup`**; after that an addon can no longer
  anchor it (`modules/Container.lua:223-227`).
- **No structural work while auras are secret or under combat lockdown.** `ContainerManager.MustDefer`
  (`modules/ContainerManager.lua:196`) holds every build, update and restyle; aura buttons refuse addon
  access while auras are secret.
- **Visibility in combat goes through the engine's `SetEnabled`**, never `Show`/`Hide` on an aura
  button's ancestry (`modules/Container.lua:446`).
- **Blizzard's `BuffFrame` and `DebuffFrame` are reparented, never hidden**, and only out of combat
  (`modules/BlizzardFrames.lua`, events-frames-taint-§3).
- **Protected opens are refused, not deferred.** The options panel (the library, options-ui-§2),
  `NS.OpenOptionsPage` (`settings/OptionsSetup.lua:367`), the frame picker and a handle drag all
  refuse under `InCombatLockdown()`.
- **A settings page shown in combat is locked, never closed** (LibKa0s v1.46.1, options-ui-§2). A
  page reached in combat (the AddOns sidebar), or open when combat starts, is covered whole — header
  band, the container band and the tab strip included — by the library's gray "Settings are locked
  during combat." cover; nothing renders, and every write through the options surface (a control,
  Defaults, a library-drawn button, a tab click) is refused with one gray notice per combat, until
  `PLAYER_REGEN_ENABLED` lifts the cover and draws the page from current state. Nothing of ours
  touches Blizzard's settings window in combat (closing it from addon code ran its commit path
  tainted). This addon keeps no page-level lock of its own; its act-level gates stay, since each also
  serves a slash verb: `CM.Create` (New, Duplicate, `/am new`), the Delete popup (`/am delete`) and
  the frame picker (`/am pick`), which closes the settings window only out of combat.
- **Teardown under lockdown is parked, never hidden.** A container that leaves the registry while
  `MustDefer` is true is parked (`Container:Park`): its engine is disabled through `SetEnabled`, its
  preview and handle (our own frames) are hidden, and the anchor and engine ancestry are left alone.
  The next `FlushPending` that may touch frames destroys it; if its id comes back first, the same
  instance is revived and no second `AuraMasterAnchor<id>` is created.
- **A destroyed instance is kept dormant under its id.** Frames are never freed, so `CM.Sync` (and
  the parked teardown after combat) keeps every destroyed instance in a dormant table instead of
  dropping it. An id that comes back out of combat (a profile switch between profiles with different
  container counts, a copy, or a reset that rewinds the id counter) revives that instance marked
  `staleData`, and the apply `CM.Announce` queues rebuilds it for the data now stored there, re-places
  and re-shows its anchor, and unparks it. `CreateFrame("Frame", "AuraMasterAnchor"..id)` runs once
  per id per session.
- **A profile change in combat parks every reused id.** Ids are reused across profiles (a reset
  reseeds the starters from id 1), so an instance kept or revived under its id by a switch, copy or
  reset may be built for another container. Under `MustDefer`, `CM.Sync(true)` parks each one
  (engine disabled, nothing hidden); `Container:ShouldShow` keeps a parked instance off through every
  visibility pass, and the deferred apply rebuilds it for the new data and unparks it. An instance a
  profile change parks because the new profile lacks its id is marked `staleData`, so a later Create
  or Duplicate that reuses the id (a reset rewinds the counter) revives it still parked too.
- **Registry verbs that create or destroy frames are refused in combat** with a gray line
  (options-ui-§2): `/am new`, `/am delete`, and Containers' New container, Duplicate and
  Delete popup. `ContainerManager.Create` refuses itself, so every creating caller is covered.
- **Reset all is Profiles → Reset Profile, in combat as well (options-ui-§12).** `/am resetall` and
  the General page's Reset-all popup both run `db:ResetProfile()`, the same call AceDBOptions' button
  makes, and neither is refused. In combat all three take the parked teardown above: a container the
  reset drops draws nothing until combat ends and is torn down then. Ours also restore the session
  rows, so the debug console closes and test mode ends; AceDBOptions' button leaves them alone. The
  reset profile is locked, so the handles and outlines go through `ApplyVisibility` (combat-safe).
- **Test mode ends when combat starts.** `PLAYER_REGEN_DISABLED` switches it off before the
  visibility pass (`addon:OnCombatChanged`), so no placeholder covers real auras in a fight, and
  `Preview.SetTestMode` refuses a start under `InCombatLockdown()` with one gray line. Unlocking
  keeps the live engine drawing under the drag handle and a faint outline, a frame of ours under the
  anchor that takes no mouse.
- **A profile switch, copy or reset in combat may create anchor frames.** Those are plain frames,
  which is combat-legal; their engines are built by the deferred apply once combat ends.
- **Every engine and button binding is `pcall`-guarded** (`callEngine`, `Style.Bind`), so a binding
  the client rejects costs that binding, never the engine's frame batch. A live re-dress is guarded
  per button (`Container:Restyle`), and a Text line's icon block per dress, so a refusal there costs
  the button, or only the icon; neither is silent: `Style.ReportError` writes a `[Style]` debug line
  every time and hands the error to the client's error handler once per session per message.
- **No aura-button border reads its size** (B2-3). A laid-out engine button's size reads secret, and
  so does every frame anchored to it, while Blizzard's Backdrop does arithmetic on the frame's size on
  every `SetBackdrop` and from `BackdropTemplate`'s `OnSizeChanged` (line 226 of Blizzard's
  `Backdrop.lua`). Every border frame is a plain frame (`Style.NewBorder`); Solid, the default, is
  drawn with four strip textures, and any other style with a backdrop on a plain frame that mixes in
  `BackdropTemplateMixin` without the template's size script, applied only while its size reads plain
  and recolored otherwise (`Style.ApplyBorder`). The Icons and Bars border steps run through
  `Style.GuardedBorder`, so a refused border never costs the engine bindings after it
  (docs/midnight-quirks.md). The unlocked outline, the drag handle (both under the anchor, whose
  geometry reads secret when the container is attached to a secret frame) and the frame picker's
  outline are plain frames too, their edges the same strips (`Style.DrawEdge`) and the handle's fill a
  texture of its own, so none of them runs Backdrop arithmetic when built or resized.
- **Secret values never reach a string operation.** Only `modules/TimedSpells.lua` reads aura data,
  only while `Compat.AurasAreSecret()` is false, and through the `core/Secrets.lua` gates; chat and
  debug lines go through `NS.SafeToString`.
- **Right-click cancel uses one click phase** (`RightButtonUp`) so a button reassigned between press
  and release cannot cancel the wrong aura (`modules/Style.lua:823-825`).
- **Animations on engine buttons are set up at dress time only.** `modules/Style_Text.lua` builds its
  three AnimationGroups with the regions and calls `Stop`/`Play` only in a dress (initializeFrame or a
  restyle while auras are readable), each through `Style.Bind`, so a refusal costs one call and is
  logged. There is no Scale loop: glyphs scaled past their anchored boxes overlap the next piece.

## Known Limitations

- **Units are player, target, focus and pet.** Party units 1–5 are deferred and tracked as a GitHub
  issue.
- **A profile copy or reset discards the player's own spell categories, without asking.** Profiles
  → Copy From and Reset Profile replace the profile wholesale, and `userCategories`,
  `userCategoryOrder` and `categorySpells` go with it. That is how those two acts have always
  worked and issue #10 did not change them — but it did change what is lost, from a set of
  Show/Hide states to categories the player named and filled themselves. Reviewed and **accepted by
  the owner on 2026-09-21**: the acts say what they do, and adding a confirmation to one of them and
  not the other would be worse than neither. Revisit if a player reports losing work this way.
- **The create form sits between the category picker and its spell list.** A player who only came to
  edit spells passes "Make a new category" on every visit. Accepted by the owner on 2026-09-21: the
  alternative is below the list, where sixty entries would hide it.
- **A claimed spell's `(also in N)` can be truncated away on the narrowest panel.** The claim now
  rides the entry's own row — `(X) [icon] Renewing Mist (119611) (also in 1)`, LibKa0s v1.49.0's
  entry `suffix` — with the claiming categories named in the entry's tooltip. At two columns word
  wrap is off and the client cuts the tail, and the library's truncation order is the suffix first,
  then the id, then the name's tail. The budget is real: `0.43 × 520 − 16 = 207.6px` of label at the
  icon style's 520px floor, which at LibKa0s's published rule of thumb of ~4.5px a character (its
  figure; nothing here measures a font) is about 46 characters, while a long row such as
  `Ancestral Protection Totem (207399) (also in 1)` is 47. So at the floor that row shows
  no `(also in 1)`. **Accepted**: this is the library's documented degradation and the tooltip still
  names every claiming category. A wider panel buys it back at about 8 characters per 100px.
- **Categories are created only on General → Spell Categories.** Filters → Categories, where a player
  is most likely to be thinking about categories, shows them and links to their spells but offers no
  way to make one. Accepted by the owner on 2026-09-21.
- **A Text line of several pieces cannot be centered as one line.** A line is a chain of font strings
  the engine writes secret, so the chain's width is never readable, and no addon code runs when the
  engine rewrites a piece in combat. A multi-piece template set to Center is therefore STACKED: one
  centered row per field, its plain literal pieces not drawn, the rows fixed in place (an empty field
  keeps its row) and the box grown to fit them (`Style.Text.Stacked`, `Style.Text.StackHeight`;
  feedback #1). The Text page says so under Placement.
- **A Text line cannot be colored by its aura's dispel type.** No engine binding colors a font string by
  dispel type (`SetDispelTypeText`, `SetSpellName`, `SetApplicationCount` take no color;
  `SetDurationText`'s color curve runs over time), the dispel-keyed color map exists only on
  `AddDispelTypeTexture`, which takes a Texture, and addon code can neither read the type nor touch a
  button in combat. The Text page offers three opt-in stand-ins instead (Font → Dispel type,
  feedback #7): the `$dispeltype$` word colored by a `|c` escape in the engine's own text map, and a
  backdrop and an edge the engine tints (`modules/Style_Text.lua`).
- **A border style other than Solid redraws a live button only when the button is rebuilt.** Its
  backdrop does arithmetic on the button's size, which reads secret once the engine has laid the button
  out, so a new texture or thickness is applied on a new button, a rebuild or a `/reload`; its color
  changes at once, and Solid redraws at once (`Style.ApplyBorder`, B2-3). The Border style tooltip says
  so.
- **A Text token can be used once, the duration tokens must sit together, and there is no caster
  token.** The engine has one binding per field (one spell name, one stack count, one dispel type, one
  duration text whose format holds every duration value); it has none for the caster
  (`modules/TextTemplate.lua`).
- **A Text animation cannot start, stop or change in combat.** Every call on an engine button's
  objects is refused in combat; loops are built and played at dress time and keep running, and a
  change made in combat applies with the deferred restyle (`docs/midnight-quirks.md`).
- **Spell-id filters are honored only for buffs on friendly units and debuffs on hostile units** (the
  engine's identity gate). `FilterCompiler` emits a warning per container where that bites
  (`identityWarning`, `modules/FilterCompiler.lua:417`, choosing its sentence from `FC.IdsHonored`),
  rendered in orange on the Filters page.
- **On a target or focus BUFF container, Uncategorized set to Show no longer rescues an unlisted
  aura.** That row's group carries an `excludeSpellIDs` of the categorized union as its only
  constraint whenever another category is Hidden, and a target's hostility is dynamic while the plan
  is compiled once — on a hostile target the engine discards the ids and the group degenerates into
  "every buff", superseding the catch-all and defeating every Hide on the tab. The compiler
  therefore emits the group only where the ids are CERTAIN (`FC.IdsAlwaysHonored`: buffs on the
  player and pet), and the same gate runs in `FC.ExplainSpell` so the Filters page never claims a
  rescue the plan does not contain. Accepted deliberately by the owner (issue #11, 2026-09-20):
  losing a niche rescue on one unit beats defeating every Hide by default. The debuff side answers
  false on every unit for the same reason, which is what keeps issue #11's `hardCC`/`softCC` from
  re-opening fix round 3's failure.
- **Five crowd-control spells are missing from the shipped `hardCC`/`softCC` lists.** Both lists are
  derived by `tools/spell-research/research.py` from the client's own DB2 tables, and five abilities
  sit where that pipeline cannot reach: Repentance (20066), in none of the four pool sources for the
  build; Axe Toss (89766) and Seduction (6358), on a pet skill line with ClassMask 0, which the same
  test that excludes professions and mounts throws away; and Earthbind Totem (2484) and Earthgrab
  Totem (64695), whose root auras carry no mechanic and no matching name, so Shaman ships no root at
  all. The KNOWN GAPS comment above `hardCC` records each one and why (`defaults/Categories.lua:360-378`)
  rather than papering over it. A player who
  wants any of the five adds it by id on General → Spell Categories, which is a profile-wide edit
  every container picks up.
- **"Only auras without a duration" is learned, not filtered.** The engine has no such filter; the
  addon excludes every spell it has seen carry a duration, learned from player and pet buffs while
  auras are readable (`modules/TimedSpells.lua`). A timed buff never seen out of combat shows once;
  the set only grows until `/am forgettimed`. Because only buffs are scanned, the mode narrows
  nothing on a debuff container.
- **Settings changes wait for secrecy and lockdown to lift.** The player is told once per deferral,
  and the line names the cause: "…will apply when combat ends." under lockdown, or "…will apply once
  aura information is available again (after the encounter, key or match)." when secrecy alone holds
  the change. A stretch announced as combat that secrecy still holds afterwards says so once more, on
  the next held change and never on the `PLAYER_REGEN_ENABLED` edge itself, whose order against
  `ADDON_RESTRICTION_STATE_CHANGED` is unverified. Writes that apply no container never wait: the
  master enable, visibility, lock and alpha run the visibility pass at once, and a rename and the
  session toggles queue nothing. The Blizzard-frame toggles queue nothing either, but reparenting
  waits for lockdown to lift: a toggle in combat prints the combat line, under the same
  once-per-stretch rule, and applies on `PLAYER_REGEN_ENABLED`. The notice is only for the
  player's changes. What the addon queues for itself waits just the same but prints nothing: a
  class-swap re-apply, a learned timed spell, the startup build after a reload in combat, a perf
  resume (`RequestApply(id, true)`).
- **A container deleted or switched away in combat, or while aura information is withheld (an
  encounter, key or match), draws nothing until that ends, and is torn down then.** Its frames stay
  parked in the meantime. Creating and deleting from our own surfaces are refused in combat instead;
  Reset all, like Reset Profile, takes this parked path.
- **After a profile switch, copy or reset in combat, a container whose id the new profile shares
  draws nothing until combat ends** (or, while aura information is withheld, until that ends). Its
  engine was built for the old container, so it stays parked rather than show stale auras under the
  new container's name, and the deferred apply rebuilds it. The same goes for a container a Create
  or Duplicate adds under an id the profile change just retired: while aura information is withheld
  out of combat it draws nothing until that ends.
- **The schema v3 migration can widen what an already-narrowed container draws.** A container that
  used the old three-state model's exclusive Whitelist (only Defensive cooldowns shown, say) keeps drawing
  only Defensive cooldowns after migration — every other category of its aura type becomes Hide (`E-8`,
  `docs/schema.md` → Migration path). But an aura in **no category at all** now shows too (rank 5),
  where the old exclusive Whitelist excluded it, because the two-state model has no way to express
  "only the categories I named" on its own. The fix is `Uncategorized = Hide` (batch 7, `U-1`..`U-5`,
  restored to debuffs in fix round 3) — a player who notices new, uncategorized auras appear in a
  container that used to be narrow should look at Filters → Categories and set that row to Hide. On a
  debuff container this row means only that: its Show side does not contribute a group of its own, so
  it is Hide-only in practice, exactly reproducing the retired per-container **"only these
  categories"** toggle it replaced (batch 7 fix round 2). The reason is no longer "`Cat.HARMFUL` has
  no `spells`-kind category" — it carries `hardCC` and `softCC` as of issue #11 — but that
  `FC.IdsAlwaysHonored` is false for every debuff container: the engine discards debuff spell ids on
  the player and pet outright, and may discard them on a `target` or `focus` the moment the unit is
  friendly, so the group that Show would contribute could arrive carrying nothing at all.
- **A change of shape rebuilds the engine.** A different group count, enchant slots appearing or
  going, toggling hide-permanent enchants, a style switch, or a growth change that moves the corner
  the engine is pinned at (Grow horizontally or vertically, its own or inherited from the container
  it follows; the engine cannot be re-anchored after its first group) retires the old engine and
  creates a new one; WoW never frees a frame, so
  each such change leaves one hidden frame for the session.
- **Preview elements are addon-owned frames**, dressed by the same `Style` code but laid out by
  `Preview.Offset`'s arithmetic rather than by the engine. Like the live buttons, they hold the
  mouse's hover unless the container is click-through or shows no tooltips (`Style.TakesHover`), and
  they take no clicks. A world unit's tooltip appears only when no mouse-enabled frame is under the
  cursor, and the aura tooltip is the engine's own `AuraButtonTooltip`, not `GameTooltip`. So only
  the hover stops that bleed; strata cannot (L-3).
- **Class colors follow the container's unit, snapshotted per apply.** After a target, focus or pet
  swap under combat lockdown or while auras are secret, a class-colored container keeps the previous
  unit's class until it re-applies. Under lockdown alone (open world, auras readable) that happens
  on `PLAYER_REGEN_ENABLED` (`ReapplyStaleClass`). While auras are secret it happens when the
  restriction lifts, since engine buttons cannot be re-dressed until then. That residual is ratified
  by the `options-ui-§17` row in Documented deviations.
- **A user category's key is unique within the account, not across accounts.** `Cat.NewUserKey` draws
  ten base-36 characters from a Lehmer sequence seeded per client from the player GUID, the clock and
  the profiler, and then refuses any key `Cat.UserKeysInUse` finds anywhere in the account — so within
  the account uniqueness is a guarantee and it is the scan's doing, not the generator's. Across
  accounts nothing can check a key an account has never seen, so it is a very small probability rather
  than an impossibility. Keys travel: a container copy, an AceDB profile copy, and import/export when
  it exists (issue #9). The import half of #9 must therefore RE-KEY a record whose key the importing
  account already holds rather than trust that keys cannot collide.
- **Deleting a user category sweeps the stored profiles one at a time, and is recoverable rather than
  atomic.** `Cat.DeleteUserCategory` clears `filter.categories.<key>` and the spell list from every
  container of every stored profile through `Database.EachProfile`, each profile inside its own
  `pcall`, and runs the sync unconditionally afterwards. A profile whose stored table is malformed
  therefore keeps its own leaves while every other profile is cleaned. That is a real outcome and not
  a failed delete — the record, the definition, the schema row and the template key are all gone, and
  what survives is inert — so the act returns the refusing-profile count third and the panel's
  confirmation says so, leading with what went. A profile holding a record of its OWN under the key (a
  profile copy) is skipped deliberately, which is what keeps a copy's category alive when the original
  is deleted. `Cat.ForgetUnusableUserRecords` does not yet carry that count out the same way: it sums
  the leaves cleared and discards each sweep's failure count, so a profile that refuses ITS sweep
  reaches `NS.Debug` and nothing else.
- **Unpublished; README `## Screenshots` is a placeholder, and its images are owed before first
  publish** — see Documented deviations and issue tusharsaxena/AuraMaster#3.
- **A frame anchor needs a global name.** The picker walks up to the nearest named ancestor
  (`FP.NamedAncestor`, `modules/FramePicker.lua:26`); an unnamed frame cannot be re-found after a `/reload`.
- **While unlocked, a container flush with the screen edge on its handle's side is pushed in.** The
  anchor's clamp rect takes the handle in, so the handle can never be dragged off the screen
  (`Anchors.UpdateHandle`). A container dragged against the top edge that grows down therefore sits
  20px lower (the 18px strip and its 2px gap) until `/am lock`, and a handle wider than one element
  pushes a container off the side edge it runs toward the same way. Locking puts it back, and the
  stored position never changes.
- **In test mode, a container attached to another hangs from that container's preview extent.** A
  previewing container's engine is disabled and keeps a stale rect, so a container attached to it is
  re-placed onto a frame of ours sized to its placeholder block (`Preview.Extent`), where it sits as
  it would beside real auras; ending test mode puts it back on the engine. Its handle lies toward
  its parent, so the strip is raised above every one of the parent's placeholders. That raise is a frame level:
  a parent set to a higher strata still draws over it. Test mode ending in combat re-places nothing
  (events-frames-taint-§2): the attached container stays where it was until the first visibility
  pass after combat.
- **With "Show the spark on auras without a duration" off, a timed bar's spark sits just inside its
  moving edge, not centered on it.** No binding can tell a region whether its aura has a duration,
  and the duration is secret, so the spark is clipped to the elapsed region, which a timeless aura
  leaves empty (`docs/midnight-quirks.md`). The spark must sit wholly on the elapsed side to be
  clipped, so it moves half its width off center. With the option on (the default) the spark is
  centered, as before. That a zero-duration bar leaves the region empty is still an in-game check
  (`docs/smoke-tests.md`, checks 26 and 63). Moving the spark off the fill onto the elapsed
  background also moves it onto a different backdrop — the elapsed side's background defaults to
  half-opaque and lets whatever sits behind the frame bleed through — so `wireSpark`
  (`modules/Style_Bars.lua`) blends the spark normally there instead of additively, or that bleed-
  through reads as "a random yellow-golden spark" (owner report 2026-09-14, `SP-1`); centered mode
  keeps the additive blend, since its backdrop is the opaque fill. Verified in-game only
  (`docs/smoke-tests.md`, check 85).

## Documentation map

Every `.md` under `docs/` appears in exactly one table below (documentation-§3). Frozen and
generated directories are named once and never enumerated: `docs/audits/`, `docs/reviews/`,
`docs/automated-tests/<run>/`, `docs/perf-analysis/<run>/`, `docs/revendor/<date>/`,
`docs/spell-research/<date>/`, `docs/superpowers/`.

### Required (documentation-§3, Tier 1)

| Doc | Covers |
|---|---|
| `scope.md` | What the addon does, and what it deliberately does not |
| `module-map.md` | Every non-vendored file, its one-line responsibility, and the TOC load order and why |
| `schema.md` | The profile and global SavedVariables shape, the container template, every default, the migration path |
| `settings-panel.md` | The `Tab \| Covers` table, the page → tab → row tree, per-option behavior and schema keys |
| `data-flow.md` | Settings → filter plan → aura groups → the engine renders; lifecycle and deferral |
| `common-tasks.md` | Recipes for the changes made most often here, naming real files |

### Conditional (documentation-§3, Tier 2)

| Doc | Status | Trigger |
|---|---|---|
| `perf-analysis/README.md` | Present | The performance harness is wired (`core/PerfSetup.lua`) |
| `slash-dispatch.md` | Present | 22 commands in `NS.COMMANDS`, over the eight-or-more threshold |
| `midnight-quirks.md` | Present | Client-version workarounds of the addon's own: 12.1 aura secrecy and the aura container engine |
| `compat-layer.md` | Present | 21 shims in `core/Compat.lua`, over the three-or-more threshold |
| `message-bus.md` | Not applicable | 4 messages in `NS.MSG`; the trigger is more than ten. The table lives in `## Message Bus` above |
| `profiles.md` | Present | AceDB profiles are user-visible: the Profiles sub-page is a profile control in the options UI |
| `debug.md` | Not applicable | Only the LibKa0s default console (`core/DebugLogSetup.lua`); no debug surface of the addon's own |

### Verification and record (documentation-§3)

| Doc | Covers |
|---|---|
| `testing.md` | How to run the harness and lint; the green commit gate; the four suites and their checkpoints |
| `smoke-tests.md` | The in-game smoke-test suite |
| `test-cases.md` | The generated case inventory (authoritative pass count) |
| `performance.md` | The addon performance page |
| `automated-tests/README.md` | What the automated-test record is and how to produce it |
| `automated-tests/RESULTS.md` | One row per run; generated by the runner, never hand-edited apart from the watch list's `Disposition` column (automated-tests-§4) |

### Addon-specific (documentation-§3, Tier 3)

None.

## Documented deviations

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `options-ui-§17` | The "One resolver" clause: a unit-scoped container caches another unit's class. Each apply snapshots it (`ContainerClass:SnapshotClass` / `ResolveUnitClass`) and `Style.Color` paints from that snapshot, so after a target, focus or pet swap while auras are secret or under combat lockdown the container keeps the previous unit's class until it re-applies. Under lockdown alone (open world, auras readable) `ReapplyStaleClass` catches up on `PLAYER_REGEN_ENABLED`; while auras are secret it catches up when the restriction lifts (`ADDON_RESTRICTION_STATE_CHANGED`) | While auras are secret a re-dress is impossible: the engine dresses buttons in initializeFrame and forbids restyling them (DenyTaintedAccessWhenAurasAreSecret). Under combat lockdown alone, with auras readable, the wait is the addon's choice: `ContainerManager.MustDefer` holds every apply until combat ends, because an apply re-places the anchor and may retire and rebuild the engine, structural work that events-frames-taint-§2 keeps out of combat. Conforming there would take a second, restyle-only path that runs in combat beside the deferred apply, only to repaint a swatch that `ReapplyStaleClass` corrects on `PLAYER_REGEN_ENABLED`; audit docs/audits/2026-09-11 AM-03. Ratified by the owner 2026-09-12. | 2026-09-12 | The secret-auras half ends when the aura engine offers a class-color binding it resolves per button itself, or addon restyling of engine buttons becomes legal while auras are secret; the lockdown-only half ends when a restyle-only path may run under combat lockdown (`ContainerManager.MustDefer` stops holding a class-only re-dress). The row is retired when both halves have ended |
| `documentation-§1` | README's `## Screenshots` section (item 5) is a placeholder with no captioned images | Screenshots can only be captured in a live client and none exist yet, so the section says so in one line and shows nothing; the addon was unpublished when this was decided (no CurseForge id in the TOC), so item 5 was still a SHOULD; the TOC now carries `X-Curse-Project-ID: 1698345` (AuraMaster.toc:13), so the "first publish" half of the re-check trigger has fired and item 5 has become a MUST — the row stands until the owner re-decides it; images are never fabricated; audit docs/audits/2026-09-11 AM-20; the capture is tracked as issue tusharsaxena/AuraMaster#3. Ratified by the owner 2026-09-12. | 2026-09-12 | The first in-client capture session or the first publish (item 5 becomes a MUST), whichever comes first; the row is retired when captioned images land in the section |
| `layout-§1` | `settings/GeneralSpells.lua` is 1528 lines, 28 over the cap | The file holds both tabs of the General page's shared sets: Spell Categories (the dropdown, restore, rename, delete, create, the overlap guardrail, Weapon enchants) and Dispel Colors. It grew past the cap through issue #10's checkpoints. The seam is the `-- Dispel Colors` section at the foot of the file, which reads nothing from the Spell Categories code above it and would move to a sibling `settings/GeneralDispel.lua`. Recorded 2026-09-23 by the suite standards sweep, when LibKa0s v1.55.0 (test-kit revision 25) brought layout-§1's cap gate into this repo; the peel is mechanical but is its own change, not part of a re-vendor. Issue #16, filed 2026-09-23 and naming the same seam, is the file's layout-§1 terminal state until the peel lands; this row itself awaits the owner's ratification. | 2026-09-23 | The next change that grows this file carries the peel along the seam named here, and so does the next standards audit if nothing grows it first. The row is retired when the peel lands and the file is back under 1500 lines |
| `layout-§1` | `tests/test_database.lua` is 1702 lines, 202 over the cap | A test suite: its cases are independent, and the file grew through schema v2 and issue #10's user-category checkpoints. The seam is the `-- ── user categories: storage, keying, dynamic rows` banner, which starts two self-contained sections that would move to a sibling suite `tests/test_database_categories.lua`. Recorded 2026-09-23 by the suite standards sweep, when LibKa0s v1.55.0 (test-kit revision 25) brought layout-§1's cap gate into this repo; the peel is mechanical but is its own change, not part of a re-vendor. Issue #17, filed 2026-09-23 and naming the same seam, is the file's layout-§1 terminal state until the peel lands; this row itself awaits the owner's ratification. | 2026-09-23 | The next change that grows this file carries the peel along the seam named here, and so does the next standards audit if nothing grows it first. The row is retired when the peel lands and the file is back under 1500 lines |
| `layout-§1` | `tests/test_filtercompiler.lua` is 1567 lines, 67 over the cap | A test suite of independent cases. The seam is the `-- ── user categories and the categorized union` banner, which starts the user-category, overlap-guardrail and single-shown-category sections that would move to a sibling suite `tests/test_filtercompiler_categories.lua`. Recorded 2026-09-23 by the suite standards sweep, when LibKa0s v1.55.0 (test-kit revision 25) brought layout-§1's cap gate into this repo; the peel is mechanical but is its own change, not part of a re-vendor. Issue #18, filed 2026-09-23 and naming the same seam, is the file's layout-§1 terminal state until the peel lands; this row itself awaits the owner's ratification. | 2026-09-23 | The next change that grows this file carries the peel along the seam named here, and so does the next standards audit if nothing grows it first. The row is retired when the peel lands and the file is back under 1500 lines |
| `layout-§1` | `tests/test_pages_general.lua` is 1761 lines, 261 over the cap | A test suite for the General page. The seam is the `-- ── 'Your categories': create, rename, delete and the shipped lock` banner: the sections from there to the Weapon enchants block cover the Spell Categories tab's editing flows and would move to a sibling suite `tests/test_pages_general_categories.lua`. Recorded 2026-09-23 by the suite standards sweep, when LibKa0s v1.55.0 (test-kit revision 25) brought layout-§1's cap gate into this repo; the peel is mechanical but is its own change, not part of a re-vendor. Issue #19, filed 2026-09-23 and naming the same seam, is the file's layout-§1 terminal state until the peel lands; this row itself awaits the owner's ratification. | 2026-09-23 | The next change that grows this file carries the peel along the seam named here, and so does the next standards audit if nothing grows it first. The row is retired when the peel lands and the file is back under 1500 lines |

### Files over the 1500-line cap

The layout-§1 census, enforced by the kit's `tests/_kit/test_layout_cap.lua`. Line counts are from `wc -l` over `git ls-files '*.lua'`, leaving out `libs/` and `tests/_kit/`, on 2026-09-23. Each file's terminal state is an open issue naming the seam a peel would follow, one of layout-§1's three; the `layout-§1` rows above record the same breaches, and none of them is ratified yet.

| File | Lines | Terminal state |
|---|---|---|
| `settings/GeneralSpells.lua` | 1528 | Open issue #16, naming the peel seam: Dispel Colors. The `layout-§1` row above records the same breach and awaits the owner's ratification |
| `tests/test_database.lua` | 1702 | Open issue #17, naming the peel seam: user categories. The `layout-§1` row above records the same breach and awaits the owner's ratification |
| `tests/test_filtercompiler.lua` | 1567 | Open issue #18, naming the peel seam: user categories. The `layout-§1` row above records the same breach and awaits the owner's ratification |
| `tests/test_pages_general.lua` | 1761 | Open issue #19, naming the peel seam: Your categories. The `layout-§1` row above records the same breach and awaits the owner's ratification |
