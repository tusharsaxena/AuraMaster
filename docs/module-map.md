# Module map

Every file this repo authors, what it is for, and where it sits in load order. Vendored code —
`libs/` (Ace3, LibStub, CallbackHandler, LibSharedMedia, AceGUI-3.0-SharedMediaWidgets,
LibDataBroker-1.1, LibDBIcon-1.0, LibKa0s) and
`tests/_kit/` (the LibKa0s testkit) — is out of scope: it is documented upstream and never edited
here.

## Load order and why

The client reads `AuraMaster.toc` top to bottom. The folders load in the order layout-§1 fixes,
`libs/` → `locales/` → `core/` → `defaults/` → `modules/` → `settings/`, and within each folder the
order is dependency-correct. Positions marked **load-bearing** below carry a comment at their TOC line
naming what resolves at load (toc-file-§5); the rest are conventional and free to move.

1. **Libraries.** Ace3 first, then `libs\LibKa0s\LibKa0s.xml` as one line (every LibKa0s module
   depends on LibStub and some on Ace-free Core only), then LibSharedMedia and its AceGUI widgets.
2. **`locales/enUS.lua`** — first after the libraries because it creates `NS.L`, which everything
   below may read at file load.
3. **`core/`** — namespace, then the seams in the order their consumers need them (below).
4. **`defaults/`** — `Categories.lua` before `Profile.lua`, because the container template's
   `filter.categories` is built from the category lists, and `UserCategories.lua` directly after
   `Categories.lua`, because it takes the `NS.Categories` table as a file-scope upvalue.
5. **`modules/`** — `TextTemplate.lua` before `Style_Text.lua` (a file-scope upvalue), and
   `Style.lua` before `Style_Bars.lua`, `Style_Icons.lua` and `Style_Text.lua`, which decorate
   `NS.Style` at file scope. The rest reach each other only at call time.
6. **`settings/`** — last. `Schema.lua` first (every page registers into it), `Slash.lua`, then
   `OptionsSetup.lua` before every page file, because the pages call the composers
   (`NS.Helpers.ColorPair`, `FontGroup`, `BorderGroup`, `BarGroup`, `MasterControls`) inside
   `NS.RegisterSchemaRows` at file load. The page files are in the order their Blizzard subcategories
   appear (**load-bearing** for the tree order, N-2): `General.lua`, then `Containers.lua`, then its
   five sub-pages `Filters.lua`, `Layout.lua`, `Bars.lua`, `Icons.lua`, `Text.lua` (each marked with
   `NS.SubPageLabel`'s indent, D6), then `Profiles.lua`. `GeneralSpells.lua`, then
   `GeneralDispel.lua`, load before `General.lua` (**load-bearing**): `GeneralDispel.lua` reads
   `GeneralSpells.lua`'s published bullet constants at file load, each publishes its rows and tab
   renderer, and `General.lua` registers those rows after its own, so the Spell Categories and
   Dispel Colors tabs follow Display.

## `locales/`

| File | Responsibility |
|---|---|
| `locales/enUS.lua` | Creates `NS.L` with the key-fallback metatable (localization-§1) and lists every English string, keys equal to values |

## `core/` (TOC order)

| File | Responsibility | Load position |
|---|---|---|
| `core/Namespace.lua` | `NS.name`, the fallback `NS.version`, the cyan `[AM]` `NS.PREFIX` | **Load-bearing**: every seam below reads these |
| `core/Compat.lua` | The 22 client-API shims (aura engine enums, secrecy, formatters, color curves, the duration text binding, mouse focus, spell info, debuff border art) — `docs/compat-layer.md` | Conventional: reached at call time |
| `core/MediaSetup.lua` | `LibKa0s-Media-1.0` seam: `NS.Icon`, `NS.MediaFont`, `Media.RegisterLSM` at file load | **Load-bearing**: before `Constants.lua`, which resolves `FONT_MONO` from `NS.MediaFont` |
| `core/Constants.lua` | Enum-like tables and labels (units, aura types, styles, sort methods, points, dispel colors, preview auras), fallback media, `LOGO_PATH` | Read by everything after it |
| `core/State.lua` | Session-only state: `debug`, `activeContainerId`, `testMode`; `State.SetActiveContainer` | Conventional |
| `core/EnvSetup.lua` | `LibKa0s-Env-1.0` seam: `NS.Meta(field)`, `NS.Version()` | Conventional: nothing resolved at load |
| `core/CoreSetup.lua` | `LibKa0s-Core-1.0` seam: `NS.Print`, `NS.Printf`, `NS.SafeToString`, `NS.ResolveColor`, `NS.ClassColor`, `NS.SKIN`/`ApplySkin` (the skin seam, published for a future standalone window; nothing consumes it today), the `NS.MakeCloseButton` wrapper; `NS.LIBKA0S_MISSING` | **Load-bearing**: after `Namespace.lua`, before everything that prints |
| `core/Bus.lua` | The closed message bus: `NS.bus`, `NS.NewBusTarget()`, the four `NS.MSG` names (strict, through `LibKa0s-Bus-1.0`'s `Catalog`), `NS.BusLib` | **Load-bearing**: `settings/OptionsSetup.lua` subscribes at load |
| `core/PoolSetup.lua` | `LibKa0s-Pool-1.0` seam, or a four-member local pool (`New`, `Acquire`, `ReleaseAll`, `Counts`) | Conventional |
| `core/LifecycleSetup.lua` | `LibKa0s-Lifecycle-1.0` seam: the ONE latch behind both reasons to be inert — `NS.lifecycle`, `NS.IsStoodDown`, `NS.IsDisabled`, `NS.SyncEnabled`, and the `standDown` / `standUp` pair the whole addon goes down and comes back up through | **Load-bearing**: before `core/PerfSetup.lua`, which takes the instance as its `lifecycle` field |
| `core/PerfSetup.lua` | `LibKa0s-Perf-1.0` seam: `NS.Perf` with six buckets, the `perf` hold on that latch, `AuraMasterPerfDB` | **Load-bearing**: before every file taking `local Perf = NS.Perf` |
| `core/Secrets.lua` | The only place that asks whether a value is secret: `IsSecret`, `CanAccess`, `IsSafeKey` (`LibKa0s-Compat-1.0`'s guards, this file's bodies their library-absent arm), `IsReadableNumber`, `NumberOr` | Conventional |
| `core/DebugLogSetup.lua` | `LibKa0s-DebugLog-1.0` seam: `NS.DebugLog`, the gated sink `NS.Debug`, the `[Init]` summary | **Load-bearing**: after `Constants`, `State` and `CoreSetup`; before any `NS.Debug` caller |
| `core/LauncherSetup.lua` | `LibKa0s-Launcher-1.0` seam: `NS.Launcher`, the one broker object behind both the minimap button and a broker display. Left-click opens the panel; right-click opens the options menu (*Enabled*, *Locked*, *Test mode*, each the slash verb's own handler) | Conventional: `Register()` is called from `OnInitialize` after `InitDB`, and every click resolves at call time |
| `core/AuraMaster.lua` | The AceAddon: `OnInitialize`, `OnEnable`, the eight lifecycle events and their handlers, `NS.OnProfileChanged` | **Load-bearing**: the AceAddon promotion; reclaims `NS.Print` from AceConsole's embed |
| `core/Database.lua` | AceDB init (with a no-AceDB fallback), the container accessors (`GetContainers` in display order, `GetContainersByName` for the pickers), `RunMigrations` and the `SCHEMA_STEPS` ladder (v2: `MigrateV2`; v3: `MigrateV3`, the Show/Hide
category collapse and the `weaponEnchants` category row — both over every stored profile; v4: `MigrateV4`, which folds the retired `filter.onlyShown` toggle into the `uncategorized` categories' Hide; v5: `MigrateV5`, the Weapon enchants aura type retired; v6: `MigrateV6`, the user-category store stamped), `Database.EachProfile` (every stored profile, the inactive ones included — the ladder's own walk, published for `Cat.DeleteUserCategory`'s cross-profile sweep), `PrepareProfile` (the registry's load pass: repair and first-run seeding, which write the registry, `seeded`, backfilled template leaves and `c.id` stamps directly, as architecture-§5 allows a named load pass), `NewContainerData` (the id mint, called only by the registry writer), registry reads, `DeepCopy`/`Backfill`, and `Merge` (a test seam) | Conventional: called from `OnInitialize` |

## `defaults/`

| File | Responsibility |
|---|---|
| `defaults/Categories.lua` | The 19 buff and 20 debuff categories (kinds `token`, `flag`, `dispel`, `spells`, `enchant` for `weaponEnchants`, and `uncategorized` for `uncategorized` and `uncategorizedDebuffs`), the starter spell lists — fourteen `spells`-kind categories, eleven buff and three debuff (`hardCC` and `softCC` from issue #11, derived by `tools/spell-research/research.py` against build 12.1.0.69875, and `racialDebuffs` from schema v7) — and `For`/`Find`/`IsSpellCategory`/`AuraTypeOf`/`DefaultStates`/`StatesShowing`/`EnchantOnlyStates` |
| `defaults/UserCategories.lua` | The user-category registry (issue #10), extending `NS.Categories`: the records' load pass `SyncUserCategories` (four phases: teardown, insertion anchors, materialize, register rows), the acts `CreateUserCategory`/`RenameUserCategory`/`DeleteUserCategory`/`ForgetUnusableUserRecords`, the key machinery `NewUserKey`/`IsUserKey`/`UserKeysInUse`/`UserCategoryOrder`/`HasUserRecord`/`UnusableUserRecords`, `LabelOf` (THE labeling rule: a shipped label routed through `NS.L`, a player's own name never) and the name rules `SanitizeUserName`/`CharCount`/`USER_NAME_MAX` |
| `defaults/CastToAura.lua` | **Generated** by `tools/spell-research/research.py --emit-cast-aura` against build 12.1.0.69875, never hand-edited: `NS.CastToAura.REWRITE`, the 58 cast ids whose aura the DB2 data names outright, and `NS.CastToAura.CHOICES`, the 590 whose candidates are only name matches and are never resolved for the player. Ids the panel can say nothing useful about are left out |
| `defaults/Profile.lua` | `NS.defaults` (profile and global), `NS.CONTAINER_TEMPLATE`, `NS.STARTER_CONTAINERS` — the one place a default is hardcoded |

## `modules/` (TOC order)

| File | Responsibility |
|---|---|
| `modules/CastAura.lua` | Reads `defaults/CastToAura.lua` for the add boxes: `CA.Resolve` (nothing, a rewrite, or a list to choose from), `CA.ForAdd` (the id to store plus the chat line owed, the one seam both the Spell Categories tab and the Filters Overrides lists add through), and what a row says for itself — `CA.SuggestTag`, `CA.Help` and `CA.Note`. It informs and never refuses: the add always happens |
| `modules/TimedSpells.lua` | Learns which buff spell ids carry a duration while auras are readable, for "only auras without a duration"; listens (gate events through AceEvent, `UNIT_AURA` on its one player/pet unit frame) only while a container needs it and auras are readable, and announces what it learned on the bus |
| `modules/FilterCompiler.lua` | Pure: one container's filter settings → aura groups (filter strings + candidate filters), enchant slots and warnings, with the profile's spell-category edits handed in through `ctx` (`FC.ProfileContext`); `Signature`, `StructureKey`; the two identity-gate predicates `FC.IdsHonored` (can the engine EVER honor spell ids on this unit and aura type — what `identityWarning` picks its sentence from) and `FC.IdsAlwaysHonored` (are they CERTAIN to be applied — buffs on the player and pet alone, the gate an `uncategorized` Show group must clear in both `Compile` and `ExplainSpell`); `FC.ClaimingCategories`, `ExplainSpell`'s own answer to "which categories hold this id", published for the panel's overlap guardrail |
| `modules/TextTemplate.lua` | Pure: the Text style's template language. `TT.Compile` turns a template into ordered pieces (literal, name, stacks, dispel, duration run), memoized; `TT.Validate` is the Template row's `validate`; `TT.ForDraw` draws a refused stored template as the default |
| `modules/Style.lua` | Shared dressing: LSM fetch, class color (the container's unit's, as snapshotted), text in a box its justify can act in, border (a plain frame, `NewBorder`: Solid as four strips, another style a backdrop applied only while its size reads plain, `ApplyBorder`, guarded by `GuardedBorder`; the same strips as a plain frame's edge, `DrawEdge`), guarded engine bindings (the additive ones cleared first, `ClearAdditiveBindings`), a caught dress error reported once per message (`ReportError`), one region set per style on a frame (`RegionsFor`), element size, mouse behavior and hover (`TakesHover`), duration text and a placeholder's time text (`PreviewTime`), the profile's dispel palette (`DispelColorMap`); the style dispatch (`StyleKey`, `Styler`, `StructureKey`), the shared icon helpers (`IconSizeFor`, `IconInset`, `LayoutIcon`), a Text duration run's `textFormat` and binding, the measured time-text width (`TimeTextWidth`), the measured padding a Text chain pulls each piece back by (`PiecePadding`); bucket `styleElement` |
| `modules/Style_Bars.lua` | Builds and dresses a bar button; the elapsed-time status bar with an edge-anchored fill; the icon and its border; the spark, clipped to the elapsed region when timeless auras show none; preview fill |
| `modules/Style_Icons.lua` | Builds and dresses an icon button: aspect-correct crop, cooldown swipe, the dispel border: four strips in our Solid shape on a frame of their own above ours (`dispelHost`), tinted by the engine in Blizzard's own colors; preview fill |
| `modules/Style_Text.lua` | Builds and dresses a text button: clip, animation and text-area frames, one chain of font strings per template shape, the Left/Right/Center chain anchors (each piece justified to its side, pulled back by the measured padding), the line's font, the three loops (played at dress time), each piece's engine binding (rule formatter, dispel text map, duration `textFormat` with a prebuilt binding and the blink curve), the optional icon; preview fill |
| `modules/Anchors.lua` | Places a container's anchor on the screen, another container or a named frame; cycle check; the flow a container attached to another inherits (`FlowRoot`, `EffectiveLayout`, `DerivedPoints`, `Followers`); what those attached to a container hang from, its preview extent, its one-element anchor or its engine (`HangMode`, from the instance's `hangMode`, which `ContainerClass:ApplyVisibility` records, and the room left for its strip, from `stripShown`), re-placed when that changes (`PlaceAttached`); pending frame re-resolve; the drag handle (LibKa0s-Widgets-1.0's `DragHandle`, handed this addon's strings, `Style.DrawEdge` painter, `NS.Secrets.NumberOr` guard and callbacks, among them the close mark's `disableContainer`, which turns the container off through `NS.SetByPath`), `HANDLE_LEVEL` above its anchor and above an attached target's |
| `modules/Preview.lua` | Placeholder elements from one pool per style (`container.previewPools[style]`), dressed by `Style` with `engine` false, positioned by `Preview.Offset`; the placeholder set per aura type (`Preview.AurasFor`: debuffs of every dispel type, or buffs), their names and icons from the client by spell id once per session; the extent the containers attached to this one hang from while it previews (`Preview.Extent`); the test mode switch (`Preview.SetTestMode`) |
| `modules/FramePicker.lua` | The click-to-pick overlay: outlines the named frame under the cursor (a plain frame, `Style.DrawEdge` strips); left-click picks, right-click or Escape cancels. `FP.PickFor` is the one pick flow `/am pick` and Layout's Pick a frame... share: active-container resolve, combat refusal and the two attach writes |
| `modules/BlizzardFrames.lua` | Reparents `BuffFrame`/`DebuffFrame` to a hidden parent and back, out of combat only |
| `modules/Container.lua` | One live container: its anchor, handle and unlocked outline (a plain frame, `Style.DrawEdge` strips), building, updating or retiring its engine, restyling, the per-apply class snapshot, the show ladder; bucket `applyContainer` |
| `modules/ContainerManager.lua` | The registry's one writer (create, delete, duplicate; `Database.PrepareProfile` is its load pass, and `docs/schema.md` → *Settings schema, registries and named non-setting state* names both), plus rename, copy-from and reset positions through the write seam; the coalesced and deferred apply (each container's apply guarded, so an error is reported once and the pass goes on), a flow or attachment write re-applying the containers that follow it, visibility and unit refresh (with the class re-apply on a swap); buckets `applyPass`, `visibilityPass` |

## `settings/` (TOC order)

| File | Responsibility |
|---|---|
| `settings/Schema.lua` | The path machinery: container-relative resolution, `NS.RegisterSchemaRows` (appending, or inserting before a named path so a runtime category row lands in schema order), `NS.UnregisterSchemaRows` (the removal path issue #10 needed, rebuilding `NS.Schema` in place), the read seam `NS.GetSetting`, the write seam `NS.SetByPath`, the carve-outs, `NS.Choices`, `NS.ValidateSchema` |
| `settings/Slash.lua` | `NS.COMMANDS` (22 verbs), the host verbs, the `LibKa0s-Slash-1.0` descriptor and its degradation stub, `/am` and `/auramaster` registration |
| `settings/OptionsSetup.lua` | The `LibKa0s-Options-1.0` descriptor (its `get` shows a row's `panelGet`) and its load-completing stub; the container banner (`ContainerBanner`, with the Containers page's New container as the library `PageBanner`'s `action`); `RenderPage`, which maps a page spec (its own tabs filtered by aura type, `intro`, `disabledFor` and the muted-red `disabledNotice`, `afterGroup`, `pairWith`) onto the library's `O.RenderTabbedSchema`, and `RenderContainerPage`; `NS.RegisterContainerPage`, `NS.OpenOptionsPage`, `NS.RequestPanelRefresh` |
| `settings/About.lua` | The landing page body: logo, the TOC Notes line, the slash command list |
| `settings/GeneralSpells.lua` | General → Spell Categories (one spell category's ID list over the profile's `categorySpells` and its restore, or — for the Weapon enchants entry — the profile-wide `enchantSlots` toggles), the rename and Delete under the picker plus the *Make a new category* block, which create, rename and delete a player's own category and offer a way out of a record the sync cannot read, and the overlap marks off `FC.ClaimingCategories` (a count on the entry's row, the names in its tooltip); publishes `MarkedName` (the one `(yours)` marker and its muted gold, read by the Filters grid too), `RestoreStarters`, `Select` and the `BULLET` / `BULLET_GAP` constants `settings/GeneralDispel.lua` reads; registers nothing itself, `settings/General.lua` registers its rows and draws its tab |
| `settings/GeneralDispel.lua` | General → Dispel Colors (issue #16's peel out of `GeneralSpells.lua`): the five profile-wide `dispelColors.<type>` rows and the tab's lead-in and four bullets; publishes `NS.GeneralDispel` (`ROWS`, `TAB`); registers nothing itself, `settings/General.lua` registers its rows and draws its tab |
| `settings/General.lua` | The General page: the composed Master controls tab and the Display tab; registers the enchant-slot and Dispel Colors rows after its own and draws the Spell Categories and Dispel Colors tabs (`GeneralSpells.TABS[1]`, `GeneralDispel.TAB`); the Reset all popup |
| `settings/Containers.lua` | The top-level Containers page (`N-1`, batch 7): the picker and New container in the band above the strip (`Helpers.ContainerBanner` with a `PageBanner` `action`), and one tab, General: the name, enable, unit, aura type and style rows, Duplicate / Delete / Copy settings from |
| `settings/Filters.lua` | The Filters page, a sub-page of Containers (`N-2`, D6): what to show, the generated Show/Hide category rows (drawn as grids with a `See spells` link by a bespoke Categories tab; `NS.CategoryRow` is exported so `Cat.SyncUserCategories` builds a user category's row with the same function, and a user category's grid label is marked `(yours)` on a per-render copy), the five-rank priority block at the foot of General, sorting, and the bespoke Overrides tab (placed `before` Sorting) (two ID lists, each entry's verdict from `FC.ExplainSpell` and its never-matches sentence from `CastAura`, both in the entry's "?" help mark) |
| `settings/Layout.lua` | The Layout page, a sub-page of Containers (`N-2`, D6): frame, anchor (Screen / Another container / Named frame / Offset, drawn by attach mode), growth, mouse; Pick a frame |
| `settings/Bars.lua` | The Bars page, a sub-page of Containers (`N-2`, D6): size, the composed bar and spark, background and border, the three text blocks, then the icon and its composed border, then the pandemic window (time color and highlight) -- tab order is each group's first declaration, so the Icon block sits between the stack text and the pandemic rows on purpose (owner, 2026-09-20); disabled for any other style |
| `settings/Icons.lua` | The Icons page, a sub-page of Containers (`N-2`, D6): size, the composed border and font blocks, cooldown, text placement, the pandemic window (time color and highlight); disabled for any other style |
| `settings/Text.lua` | The Text page, a sub-page of Containers (`N-2`, D6): size, the Template box with its token cheat sheet (a bespoke General tab), placement with the Justify note and the centering note, the composed font block and time format, the icon and its composed border, the pandemic-window rows and the loop; disabled for a bars or icons container |
| `settings/Profiles.lua` | The Profiles sub-page: AceDBOptions drawn by AceConfigDialog inside the canvas |

## `tests/`

| File | Responsibility |
|---|---|
| `tests/run.lua` | The runner: the vendored library files from `LibKa0s.xml`, the addon files from the TOC, the lifecycle kick, and the declared suite list |
| `tests/wow_mock.lua` | Thin extender over `tests/_kit/mock_base.lua`; the aura engine as an ordered call recorder; a secret-number sentinel with `__layOut` (a laid-out button's size reads secret) and Blizzard's backdrop arithmetic on that size (B2-3) |
| `tests/fresh_env.lua` | Builds a fresh, fully loaded environment for a suite that mutates state |
| `tests/degraded_env.lua` | Builds a second environment with LibKa0s absent, so every setup file takes its real fallback |
| `tests/mock_menu.lua` | A headless `MenuUtil` stand-in, modeled on LibKa0s's repo-local one, so the launcher's right-click menu can be opened and clicked |
| `tests/perf.lua` | The offline performance scenario runner (outside the green gate) — `docs/performance.md` |
| `tests/filtercompiler_helpers.lua` | Not a suite: the plan readers (`setOf`, `hasWarning`) that `test_filtercompiler` and `test_filtercompiler_categories` share |
| `tests/general_page_helpers.lua` | Not a suite: the General page readers (`general`, `spells`, the Spell Categories list walkers `entry` / `entryHelp` / `entryTooltip`, the `marked` label builder, the `spyApply` / `spyPaths` spies) that `test_pages_general` and `test_pages_general_categories` share |
| `tests/page_helpers.lua` | Not a suite: drives a settings page as a player does on a fresh environment (the widgets one render drew, finding a widget by its row's label, chat capture, tab moves, and `P.suggestions()`, which reads the ID lists' suggestion dropdown), for the `test_pages_*` suites |
| `tests/region_recorder.lua` | Not a suite: a stand-in frame region that records every method called on it, so the style suites can tell one region's paint from another's (the kit hands a frame back as its own texture) |
| `tests/engine_recorder.lua` | Not a suite: makes a recorder button answer its dispel bindings the way the client's `CustomAuraButton` does (every `Set*` / `Add*` binding ends in a full apply pass; `ClearDispelTypeTextures` only empties the list) |
| `tests/text_apis.lua` | Not a suite: the Text style's client APIs as recording stand-ins, installed from a fresh environment's `before` |
| `tests/region_builder.lua` | Not a suite: a recorder that builds recorders, so each piece of a chain records its own calls |
| `tests/prose_waivers.lua` | Not a suite: the per-file, per-word waivers the kit's US-English prose gate (`tests/_kit/test_prose.lua`) reads; today it skips the frozen `docs/spell-research/` bundles |
| `tests/border_strips.lua` | Not a suite: reads an element border as `Style.ApplyBorder` draws it, its four Solid strips and its backdrop frame (B2-3); gives a kit frame recorder textures (`recorderTextures`) so the outline's and the handle's strips read apart |
| `tests/test_*.lua` | One suite per subject, in the order `tests/run.lua` declares them; the cases are enumerated in the generated `docs/test-cases.md` |

The suites, in the order `tests/run.lua` runs them (it is the authority on the list):

| Suite | Covers |
|---|---|
| `test_loadorder.lua` | The TOC's load-bearing positions; the runners' load lists derived from the TOC and the XML |
| `test_setups.lua` | The LibKa0s seams' addon-side wiring (printer, media, env, debug flag) and a real library-absent load |
| `test_launcher.lua` | The launcher (launcher-§1..§5): one object registered twice under the folder name, the icon file's own TGA header, left-click opening the panel, the right-click menu's three entries each reaching its slash verb's handler (through `tests/mock_menu.lua`), the Minimap button row's inverting get/set, the two reserved verbs, and three degraded hosts |
| `test_database.lua` | `core/Database.lua`: seeding once, repair of ids, order and wrong-typed sections, backfill that keeps a stored `false`, the migration runner and schema v2 over every stored profile and the no-AceDB fallback |
| `test_database_categories.lua` | `core/Database.lua`'s user-category store, peeled out of `test_database.lua` (issue #17): the v6 stamp, round trip through a reload, sync order, profile switches, key collisions, rename and the reserved namespace both acts rest on, the cross-profile delete sweep and the profile copy it skips |
| `test_migrations.lua` | `core/Database.lua`'s `NS.RunMigrations` against savedvariables-§1: `NS.SCHEMA_VERSION` is the last step's target, a legacy account with no stamp runs every step, a stored stamp survives the logout strip, every step is idempotent on a fresh default profile, a step that raises leaves the stamp where it was, and an inactive profile is migrated too |
| `test_schema.lua` | `settings/Schema.lua`: every row resolves, class-color companions, the container-relative path model, the carve-outs |
| `test_schema_paths.lua` | `settings/Schema.lua` in depth: the write seam's order, the relative and absolute path models, registration and validation, carve-outs, whole sections, `CheckWrite`, `ApplyDefault`, the session rows |
| `test_filtercompiler.lua` | `modules/FilterCompiler.lua`: settings in, aura groups and warnings out |
| `test_filtercompiler_categories.lua` | `modules/FilterCompiler.lua` against the player's own categories, peeled out of `test_filtercompiler.lua` (issue #18): a user category in the categorized union, `ClaimingCategories` (the overlap guardrail's one question), and a user category as the only shown category |
| `test_container.lua` | `modules/Container.lua` against the recorded engine: call order, update in place vs rebuild (the growth corner included), the show ladder, preview |
| `test_containermanager.lua` | `modules/ContainerManager.lua`: the registry's write side, coalesced apply, an apply error that leaves the rest of the pass running, followers re-applied, combat and secrecy deferral |
| `test_compat.lua` | `core/Compat.lua`: every shim with the client API present and absent |
| `test_secrets.lua` | `core/Secrets.lua`: the predicates degrade to "nothing is secret", answer strict booleans, and defer to `canaccessvalue`; one pinned matrix over the library arm and the degraded one |
| `test_bus.lua` | `core/Bus.lua`: the message catalog (strict live, plain degraded), a target per receiver, one sender per message |
| `test_state.lua` | `core/State.lua`: session state never reaches SavedVariables; test mode is session-only and unlocking keeps real auras drawing |
| `test_lifecycle.lua` | `core/AuraMaster.lua`: the lifecycle events and the three AceDB profile handlers, fired through AceEvent |
| `test_anchors.lua` | `modules/Anchors.lua` and `modules/FramePicker.lua`: attachment, cycles, the derived points and inherited flow, the preview extent, pending and forbidden frames, the drag handle |
| `test_anchors_hang.lua` | `modules/Anchors.lua`: what a follower hangs from, test mode, unlocked or locked (EO-1), re-placed on lock, unlock and after combat, and the room a chain leaves so no two strips overlap (EO-2) |
| `test_anchors_close.lua` | `modules/Anchors.lua`: the close mark on the drag handle (CX-3): the catalog X left of the "?" at its size, its fallback art, a left click disabling that container alone through the write seam with one chat line, in combat too, right-click opening the settings, and its cursor-owned tooltip |
| `test_texttemplate.lua` | `modules/TextTemplate.lua`: every template rule with its message, the escapes, case, the compiled pieces, `ForDraw` |
| `test_style.lua` | `modules/Style*.lua` and `modules/Preview.lua`: element sizes, preview layout, engine bindings |
| `test_castaura.lua` | `modules/CastAura.lua`: the resolve of a cast id to its aura or its candidates, the one add seam both add boxes use, and the tag, help and note a row wears |
| `test_timedspells.lua` | `modules/TimedSpells.lua`: readable-state listening, the bus announcement, learning out of combat, feeding the timeless filter |
| `test_style_bars.lua` | `modules/Style_Bars.lua`: every bar setting reaching the region it paints, icon side and gap, drain direction, texts, bindings, preview fill |
| `test_style_icons.lua` | `modules/Style_Icons.lua`: the art inside its border, the aspect crop, the cooldown swipe, the dispel border, texts, bindings, preview fill |
| `test_style_text_autosize.lua` | `modules/Style_Text.lua`'s Size to fit (batch 8 AS-2): off keeps the stored size, the measured width over the placeholders, the sample and the worst-case durations, the clamp, the icon and bounce height and inset, a stacked Center's widest row, a failed measure never remembered, the memo, and every consumer reading it |
| `test_style_text.lua` | `modules/Style_Text.lua`: the nested frames, the chain's anchors per justify, the measured padding and each piece's justify, the Center fallback, each piece's binding and options, the blink, the loops, the icon, a refused stored template, the chain per shape, the preview fill |
| `test_preview.lua` | `modules/Preview.lua`: how many placeholders are drawn and where, the pool per style, when they are dressed again |
| `test_render_coverage.lua` | Every Bars, Icons and Text schema row, written to a value other than the one in force, reaches a drawn region on a live button and on a placeholder, unless it declares `coverage` |
| `test_blizzardframes.lua` | `modules/BlizzardFrames.lua`: reparenting `BuffFrame`/`DebuffFrame` under a hidden parent and back |
| `test_framepicker.lua` | `modules/FramePicker.lua`: the named-ancestor walk, the outline and label that track the cursor, every way a pick ends, and `PickFor`'s refusals and writes |
| `test_disabled.lua` | The stand-down conformance suite (slash-commands-§7): the registration set, the live timer set, the shown frames, the SavedVariables writes and the printed lines, before and after the switch — plus the slash surface, the launcher's two buttons and the two-hold latch |
| `test_slash.lua` | `settings/Slash.lua`: `NS.COMMANDS` and every host verb through the real dispatcher |
| `test_slash_verbs.lua` | `settings/Slash.lua` verb by verb through the real dispatcher: the help surface, the schema verbs over relative and absolute paths, the host verbs, the degradation stub |
| `test_bulklog.lua` | debug-logging-§10's bulk rule, act by act: one `[Set]` line per bulk act counting the rows it changed; one line per profile reset or copy |
| `test_optionssetup.lua` | The panel: pages, tabs, the container banner, per-page Defaults, the global reset's blast radius, the degraded stub |
| `test_options_descriptor.lua` | `settings/OptionsSetup.lua`'s descriptor seams through real widgets and resets: the Profiles veto, the banner and picker, `RenderPage` and `RenderContainerPage`, the coalesced refresh, `OpenOptionsPage`, the stub's composers |
| `test_pages_general.lua` | `settings/General.lua`, `settings/GeneralSpells.lua` and `settings/GeneralDispel.lua` through their widgets: the Spell Categories ID list and its restore, the Dispel Colors rows; each Master control and Display row, the composer's two buttons, Defaults; the tab strip with Containers gone from it and no page keyed `containers` to `general`'s rows |
| `test_pages_general_categories.lua` | `settings/GeneralSpells.lua`'s category editing through its widgets, peeled out of `test_pages_general.lua` (issue #19): the 'Your categories' block (create, rename, delete, the shipped lock), the overlap guardrail's claimed-by marks, the headings, answer line and counts, and the add line's suggestions while typing |
| `test_pages_containers.lua` | `settings/Containers.lua` through its widgets: the picker and New in the band above the strip, its identity rows, Duplicate / Delete / Copy settings from, a Delete that keeps the picker, Defaults (the name kept), and that the page registers on its own (N-1) |
| `test_pages_filters.lua` | `settings/Filters.lua` through its widgets: the rows each aura type is offered, the category grids, the Overrides ID lists, the warnings |
| `test_pages_layout.lua` | `settings/Layout.lua` through its widgets: the tab order, the attach rows, the subsections drawn per mode and their cycle guard, Pick a frame, the inherited Growth rows, the Point rows' first-aura wording and the facing-growth hint, what a Growth or Frame row re-applies, Defaults |
| `test_pages_bars.lua` | `settings/Bars.lua` through its widgets: tabs (the Icon tab among them), the not-drawn-as-bars notice with every control disabled, sliders and swatches, Defaults |
| `test_pages_icons.lua` | `settings/Icons.lua` through its widgets: tabs, the not-drawn-as-icons notice with every control disabled, rows, Defaults |
| `test_pages_text.lua` | `settings/Text.lua` through its widgets: the tabs, the notice and disabled rows for another style, the Template box and its refusal text (panel and `/am set`), the cheat sheet, the Justify note, the centering note, the rows the effect and the template dim, Defaults |
| `test_pages_tabs.lua` | Every tabbed page's render from the outside, across the seven pages: the strip's tab keys and labels in order, the active tab healing after a container switch, the muted-red notice above disabled rows, the Filters warnings above the rows, the empty registry's placeholder tab and line, the Containers picker+create band, and the live Dropdown and Button counts staying flat across re-renders |
| `test_pages_about.lua` | `settings/About.lua`: the command list, the Notes line and the logo, and when each is read |
| `test_pages_profiles.lua` | `settings/Profiles.lua`: the table it registers, how often it opens the dialog and into what, when it opts out |
| `test_envsetup.lua` | `core/EnvSetup.lua` on both arms (live and library-absent): which manifest `NS.Meta` reads, what `NS.Version` answers |
| `test_poolsetup.lua` | `core/PoolSetup.lua`: the library seam, and a library-absent fallback that recycles exactly as the library does |
| `test_defaults.lua` | `defaults/Profile.lua`, `defaults/Categories.lua` and `defaults/UserCategories.lua`: the shape invariants the code relies on, the user-category namespace, key generator and name rules, and where a materialized definition sits in its list |
| `test_perf.lua` | The perf wiring: every bucket reached, a dormant probe free, suspend inert, the degraded stub |
| `test_debuglogsetup.lua` | `core/DebugLogSetup.lua`: the descriptor this addon owns (flag, `[Init]` summary, chat acknowledgment, visibility refresh) and its stub |
| `test_locale.lua` | `locales/enUS.lua` defines every routed string and nothing unused |
| `test_docs.lua` | README placeholders, the Documentation map both ways and its Tier 2 rows against `docs/`, and every file:line citation resolving to a non-blank, non-comment line within 3 lines of a name its own sentence gives |
| `tests/_kit/test_prose.lua` | The US-English prose gate (localization-§5) over every tracked authored file, with this repo's waivers from `tests/prose_waivers.lua` |
| `test_surface_parity.lua` | Each degradation stub against the live surface it stands in for |
| `test_vendor_sync.lua` | `libs/LibKa0s/` and `tests/_kit/` against the LibKa0s tag named in `CLAUDE.md` |
| `test_lintconfig.lua` | `.luacheckrc` carries no blanket suppression, no source file carries a bare inline luacheck ignore, and no `#` shares its line with a keyword or brace lizard must see |
| `tests/_kit/test_eol.lua` | Every tracked file carries the line ending `.gitattributes` declares, and `.gitattributes` is the canonical body |
| `tests/_kit/test_layout_cap.lua` | The layout-§1 cap census in `docs/ARCHITECTURE.md` agrees with the tree |

## Root and media

| File | Responsibility |
|---|---|
| `AuraMaster.toc` | Metadata (Interface 120100, version 0.1.0, `X-Standard`), SavedVariables `AuraMasterDB` and `AuraMasterPerfDB`, the load order |
| `.luacheckrc` | Lint config: Lua 5.1, excludes `libs/`, `tests/_kit/` and the frozen `docs/` bundles; the harness global in a `tests/` stanza |
| `.pkgmeta` | Packager config: no externals; ignores dev files, `docs`, `tests`, `tools` (the committed generators, never loaded in game), `_dev`, and the `.png`/`.jpg` logo sources |
| `.gitattributes` | The client-bound line-ending policy (line-endings-§5): CRLF working tree, `*.sh` LF, binaries marked |
| `.gitignore` | OS and editor clutter, agent scratch directories; `.claude/` is ignored except `.claude/commands/` (the project's slash commands) |
| `LICENSE` | MIT |
| `README.md`, `CLAUDE.md`, `DEPENDENCIES.md` | The three root docs (documentation-§1/§2/§7) |
| `docs/` | The engineering docs; every file is registered in `docs/ARCHITECTURE.md` → Documentation map, which also names the frozen bundle directories |
| `tools/spell-research/research.py` | The CC spell-list generator (issue #11 Part C): reads Blizzard's DB2 exports for one pinned build, buckets spells by the crowd-control mechanic the client stamps, and prints a diff or a paste-ready Lua fragment. Never writes `defaults/Categories.lua` — the author accepts each change. Python 3.8+, standard library only, needs the network on a run that is not a `--replay` |
| `tools/spell-research/logs.py` | The combat-log evidence CLI (`scan`, `propose`, `decide`, `apply`): mines the owner's combat logs for the aura ids players of each spec apply, writes the `docs/spell-research/<date>-logs/` bundle (the per-spec dictionary and the review set), records rulings in `decisions.json`, and is the only writer of `defaults/Categories.lua`, for ruled proposals only. Python 3.8+, standard library only |
| `tools/spell-research/sid_scan.py`, `sid_cache.py`, `sid_db2.py`, `sid_propose.py`, `sid_artifacts.py`, `sid_decide.py` | `logs.py`'s stages: log parsing and the player filter; the per-log cache (outside the repo) and merge; DB2 signals and the shipped categories; proposals and the category rules; the bundle files; decisions and the `Categories.lua` line rewriter |
| `tools/spell-research/test_sid_*.py`, `fixtures/` | The `unittest` suite for `logs.py` (one module per stage plus `test_sid_e2e.py`, the scan-to-apply acceptance run) and its fixtures: a hand-written combat log with fictional names, tiny DB2 CSVs, and small `Categories.lua` / `CastToAura.lua` copies |
| `tools/spell-research/decisions.json` | The owner's durable rulings on combat-log proposals, one entry per proposal key; written only by `logs.py decide` (created on the first review) |
| `tools/spell-research/README.md` | How to run both tools: `research.py`'s `--diff`, `--emit --date`, `--bundle`, `--replay` and the limitations that make the diff a judgment call; `logs.py`'s commands, thresholds, artifacts and privacy |
| `.claude/commands/aura-spells-review.md` | The `/aura-spells-review` slash command: scan, propose, walk each proposal with the owner, record rulings, apply, gate and commit |
| `tools/spell-research/.gitignore` | Keeps the ~75 MB export cache (`.cache/`) and `__pycache__/` out of the repo; only a bundle's gzipped `raw/` copies are committed |
| `media/logos/auramaster.logo.tga` | The landing-page logo, drawn at 300×300 (options-ui-§5) |
| `media/logos/auramaster.logo.128.tga` | The ICON logo, 128×128 and uncompressed 32-bit (layout-§4): `## IconTexture`, the minimap button and the broker row. Regenerated from the `.png`, never hand-edited |
| `media/logos/auramaster.logo.png`, `….jpg` | The 2000×2000 source art and its render; shipped but never loaded — the client reads neither format |

## Libraries

All vendored under `libs/`, loaded by the `# Libraries` block of `AuraMaster.toc:15-32`.

| Library | Used for |
|---|---|
| LibStub, CallbackHandler-1.0 | Library registry; AceEvent's and AceDB's callbacks |
| AceAddon-3.0 | `NS` promoted to the addon object by `NewAddon` (`core/AuraMaster.lua:17`) |
| AceEvent-3.0 | Lifecycle events and the message bus (`core/Bus.lua`) |
| AceTimer-3.0 | The color picker's drag throttle, via the options descriptor's `scheduleTimer` |
| AceConsole-3.0 | `/am` and `/auramaster` registration (`settings/Slash.lua:546-547`) |
| AceDB-3.0 | `AuraMasterDB` and its profiles (`core/Database.lua:246`) |
| AceGUI-3.0, AceGUI-3.0-SharedMediaWidgets | The settings panel body and its `LSM30_*` media dropdowns |
| AceConfig-3.0, AceDBOptions-3.0 | The Profiles sub-page only (`settings/Profiles.lua`, options-ui-§3) |
| LibSharedMedia-3.0 | Texture, border and font lookups through `LSM` (`modules/Style.lua:33`) |
| LibDataBroker-1.1, LibDBIcon-1.0 | The launcher's broker object and its minimap button (`core/LauncherSetup.lua`, launcher-§1). Both are OPTIONAL: `LibKa0s-Launcher-1.0` resolves them with `LibStub(…, true)` at Register time, so a client missing either degrades rather than raises |
| LibKa0s v1.59.0 | Fourteen modules bound by name — table below |

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
| `LibKa0s-Widgets-1.0` | `modules/Anchors.lua` | Nothing on `NS`: the container drag handle's strip (`DragHandle`), wearing this addon's strings, painter and callbacks. Without the library no handle is built |

`LibKa0s-Item-1.0` arrives with the whole-folder copy (library-stack-§7) and is not bound by name
here; the addon handles no items. `LibKa0s-Schema-1.0` runs under the
rows but not the write seam (`docs/schema.md`, "Write seam: why AuraMaster keeps SetByPath").
Every setup file degrades to a stub when
the library is absent, exercised by `tests/degraded_env.lua`.
