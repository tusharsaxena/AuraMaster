# Module map

Every file this repo authors, what it is for, and where it sits in load order. Vendored code —
`libs/` (Ace3, LibStub, CallbackHandler, LibSharedMedia, AceGUI-3.0-SharedMediaWidgets, LibKa0s) and
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
   `filter.categories` is built from the category lists.
5. **`modules/`** — `Style.lua` before `Style_Bars.lua` and `Style_Icons.lua`, which decorate
   `NS.Style` at file scope. The rest reach each other only at call time.
6. **`settings/`** — last. `Schema.lua` first (every page registers into it), `Slash.lua`, then
   `OptionsSetup.lua` before every page file, because the pages call the composers
   (`NS.Helpers.ColorPair`, `FontGroup`, `BorderGroup`, `BarGroup`, `MasterControls`) inside
   `NS.RegisterSchemaRows` at file load. The page files are in the order
   their Blizzard subcategories appear.

## `locales/`

| File | Responsibility |
|---|---|
| `locales/enUS.lua` | Creates `NS.L` with the key-fallback metatable (localization-§1) and lists every English string, keys equal to values |

## `core/` (TOC order)

| File | Responsibility | Load position |
|---|---|---|
| `core/Namespace.lua` | `NS.name`, the fallback `NS.version`, the cyan `[AM]` `NS.PREFIX` | **Load-bearing**: every seam below reads these |
| `core/Compat.lua` | The 17 client-API shims (aura engine enums, secrecy, formatter, color curve, mouse focus, spell info) — `docs/compat-layer.md` | Conventional: reached at call time |
| `core/MediaSetup.lua` | `LibKa0s-Media-1.0` seam: `NS.Icon`, `NS.MediaFont`, `Media.RegisterLSM` at file load | **Load-bearing**: before `Constants.lua`, which resolves `FONT_MONO` from `NS.MediaFont` |
| `core/Constants.lua` | Enum-like tables and labels (units, aura types, styles, sort methods, points, dispel colors, preview auras), fallback media, `LOGO_PATH` | Read by everything after it |
| `core/State.lua` | Session-only state: `debug`, `activeContainerId`, `preview`; `State.SetActiveContainer` | Conventional |
| `core/EnvSetup.lua` | `LibKa0s-Env-1.0` seam: `NS.Meta(field)`, `NS.Version()` | Conventional: nothing resolved at load |
| `core/CoreSetup.lua` | `LibKa0s-Core-1.0` seam: `NS.Print`, `NS.Printf`, `NS.SafeToString`, `NS.ResolveColor`, `NS.ClassColor`, `NS.SKIN`/`ApplySkin` (the skin seam, published for a future standalone window; nothing consumes it today), the `NS.MakeCloseButton` wrapper; `NS.LIBKA0S_MISSING` | **Load-bearing**: after `Namespace.lua`, before everything that prints |
| `core/Bus.lua` | The closed message bus: `NS.bus`, `NS.NewBusTarget()`, the four `NS.MSG` names | **Load-bearing**: `settings/OptionsSetup.lua` subscribes at load |
| `core/PoolSetup.lua` | `LibKa0s-Pool-1.0` seam, or a four-member local pool (`New`, `Acquire`, `ReleaseAll`, `Counts`) | Conventional |
| `core/PerfSetup.lua` | `LibKa0s-Perf-1.0` seam: `NS.Perf` with six buckets, suspend/resume, `AuraMasterPerfDB` | **Load-bearing**: before every file taking `local Perf = NS.Perf` |
| `core/Secrets.lua` | The only place that asks whether a value is secret: `IsSecret`, `CanAccess`, `IsReadableNumber`, `IsSafeKey` | Conventional |
| `core/DebugLogSetup.lua` | `LibKa0s-DebugLog-1.0` seam: `NS.DebugLog`, the gated sink `NS.Debug`, the `[Init]` summary | **Load-bearing**: after `Constants`, `State` and `CoreSetup`; before any `NS.Debug` caller |
| `core/AuraMaster.lua` | The AceAddon: `OnInitialize`, `OnEnable`, the eight lifecycle events and their handlers, `NS.OnProfileChanged` | **Load-bearing**: the AceAddon promotion; reclaims `NS.Print` from AceConsole's embed |
| `core/Database.lua` | AceDB init (with a no-AceDB fallback), `RunMigrations` and the `SCHEMA_STEPS` ladder (v2: `MigrateV2`, over every stored profile), `PrepareProfile` (the registry's load pass: repair and first-run seeding, which write the registry, `seeded`, backfilled template leaves and `c.id` stamps directly, as architecture-§5 allows a named load pass), `NewContainerData` (the id mint, called only by the registry writer), registry reads, `DeepCopy`/`Backfill`, and `Merge` (a test seam) | Conventional: called from `OnInitialize` |

## `defaults/`

| File | Responsibility |
|---|---|
| `defaults/Categories.lua` | The 16 buff and 16 debuff categories (kinds `token`, `flag`, `dispel`, `spells`), the starter spell lists, `For`/`Find`/`IsSpellCategory`/`NeutralStates` |
| `defaults/Profile.lua` | `NS.defaults` (profile and global), `NS.CONTAINER_TEMPLATE`, `NS.STARTER_CONTAINERS` — the one place a default is hardcoded |

## `modules/` (TOC order)

| File | Responsibility |
|---|---|
| `modules/TimedSpells.lua` | Learns which buff spell ids carry a duration while auras are readable, for "only auras without a duration"; listens through AceEvent only while a container needs it and auras are readable, and announces what it learned on the bus |
| `modules/FilterCompiler.lua` | Pure: one container's filter settings → aura groups (filter strings + candidate filters), enchant slots and warnings; `Signature`, `StructureKey` |
| `modules/Style.lua` | Shared dressing: LSM fetch, class color (the container's unit's, as snapshotted), text, border, guarded engine bindings, element size, mouse behavior, duration text; bucket `styleElement` |
| `modules/Style_Bars.lua` | Builds and dresses a bar button; the elapsed-time status bar with an edge-anchored fill; preview fill |
| `modules/Style_Icons.lua` | Builds and dresses an icon button: aspect-correct crop, cooldown swipe, dispel border; preview fill |
| `modules/Anchors.lua` | Places a container's anchor on the screen, another container or a named frame; cycle check; pending frame re-resolve; the drag handle |
| `modules/Preview.lua` | Placeholder elements from a pool, dressed by `Style` with `engine` false, positioned by `Preview.Offset` |
| `modules/FramePicker.lua` | The click-to-pick overlay: outlines the named frame under the cursor; left-click picks, right-click or Escape cancels |
| `modules/BlizzardFrames.lua` | Reparents `BuffFrame`/`DebuffFrame` to a hidden parent and back, out of combat only |
| `modules/Container.lua` | One live container: its anchor and handle, building, updating or retiring its engine, restyling, the per-apply class snapshot, the show ladder; bucket `applyContainer` |
| `modules/ContainerManager.lua` | The registry's one writer (create, delete, duplicate; `Database.PrepareProfile` is its load pass, and `docs/ARCHITECTURE.md` → Settings Schema names both), plus rename, copy-from and reset positions through the write seam; the coalesced and deferred apply, visibility and unit refresh (with the class re-apply on a swap); buckets `applyPass`, `visibilityPass` |

## `settings/` (TOC order)

| File | Responsibility |
|---|---|
| `settings/Schema.lua` | The path machinery: container-relative resolution, `NS.RegisterSchemaRows`, the read seam `NS.GetSetting`, the write seam `NS.SetByPath`, the carve-outs, `NS.Choices`, `NS.ValidateSchema` |
| `settings/Slash.lua` | `NS.COMMANDS` (22 verbs), the host verbs, the `LibKa0s-Slash-1.0` descriptor and its degradation stub, `/am` and `/auramaster` registration |
| `settings/OptionsSetup.lua` | The `LibKa0s-Options-1.0` descriptor and its load-completing stub; the container banner, `RenderContainerPage`, `NS.RegisterContainerPage`, `NS.OpenOptionsPage`, `NS.RequestPanelRefresh` |
| `settings/About.lua` | The landing page body: logo, the TOC Notes line, the slash command list |
| `settings/General.lua` | The General page: the composed Master controls tab and the Display tab; the Reset all popup |
| `settings/Containers.lua` | The Containers page: name, enable, unit, aura type, style; New / Duplicate / Delete / Copy settings from; the Overview tab |
| `settings/Filters.lua` | The Filters page: what to show, the generated category rows, sorting, and the bespoke Spell lists and Always / never tabs |
| `settings/Layout.lua` | The Layout page: attach and screen position, growth, frame, mouse; Pick a frame and Attach to the screen |
| `settings/Bars.lua` | The Bars page: size, the composed bar, border and font blocks, spark, background, text placement, highlights |
| `settings/Icons.lua` | The Icons page: size, the composed border and font blocks, cooldown, text placement, highlights |
| `settings/Profiles.lua` | The Profiles sub-page: AceDBOptions drawn by AceConfigDialog inside the canvas |

## `tests/`

| File | Responsibility |
|---|---|
| `tests/run.lua` | The runner: the vendored library files from `LibKa0s.xml`, the addon files from the TOC, the lifecycle kick, and the declared suite list |
| `tests/wow_mock.lua` | Thin extender over `tests/_kit/mock_base.lua`; the aura engine as an ordered call recorder |
| `tests/fresh_env.lua` | Builds a fresh, fully loaded environment for a suite that mutates state |
| `tests/degraded_env.lua` | Builds a second environment with LibKa0s absent, so every setup file takes its real fallback |
| `tests/perf.lua` | The offline performance scenario runner (outside the green gate) — `docs/performance.md` |
| `tests/page_helpers.lua` | Not a suite: drives a settings page as a player does on a fresh environment (the widgets one render drew, finding a widget by its row's label, chat capture, tab moves), for the `test_pages_*` suites |
| `tests/region_recorder.lua` | Not a suite: a stand-in frame region that records every method called on it, so the style suites can tell one region's paint from another's (the kit hands a frame back as its own texture) |
| `tests/test_*.lua` | One suite per subject, in the order `tests/run.lua` declares them; the cases are enumerated in the generated `docs/test-cases.md` |

The suites, in the order `tests/run.lua` runs them (it is the authority on the list):

| Suite | Covers |
|---|---|
| `test_loadorder.lua` | The TOC's load-bearing positions; the runners' load lists derived from the TOC and the XML |
| `test_setups.lua` | The LibKa0s seams' addon-side wiring (printer, media, env, debug flag) and a real library-absent load |
| `test_database.lua` | `core/Database.lua`: seeding once, repair of ids, order and wrong-typed sections, backfill that keeps a stored `false`, the migration runner, the no-AceDB fallback |
| `test_schema.lua` | `settings/Schema.lua`: every row resolves, class-color companions, the container-relative path model, the carve-outs |
| `test_schema_paths.lua` | `settings/Schema.lua` in depth: the write seam's order, the relative and absolute path models, registration and validation, carve-outs, whole sections, `CheckWrite`, `ApplyDefault`, the session rows |
| `test_filtercompiler.lua` | `modules/FilterCompiler.lua`: settings in, aura groups and warnings out |
| `test_container.lua` | `modules/Container.lua` against the recorded engine: call order, update in place vs rebuild, the show ladder, preview |
| `test_containermanager.lua` | `modules/ContainerManager.lua`: the registry's write side, coalesced apply, combat and secrecy deferral |
| `test_compat.lua` | `core/Compat.lua`: every shim with the client API present and absent |
| `test_secrets.lua` | `core/Secrets.lua`: the predicates degrade to "nothing is secret", answer strict booleans, and defer to `canaccessvalue` |
| `test_bus.lua` | `core/Bus.lua`: the message catalog, a target per receiver, one sender per message |
| `test_state.lua` | `core/State.lua`: session state never reaches SavedVariables; `CM.SetPreview` stores a strict boolean |
| `test_lifecycle.lua` | `core/AuraMaster.lua`: the lifecycle events and the three AceDB profile handlers, fired through AceEvent |
| `test_anchors.lua` | `modules/Anchors.lua` and `modules/FramePicker.lua`: attachment, cycles, pending and forbidden frames, the drag handle |
| `test_style.lua` | `modules/Style*.lua` and `modules/Preview.lua`: element sizes, preview layout, engine bindings |
| `test_timedspells.lua` | `modules/TimedSpells.lua`: readable-state listening, the bus announcement, learning out of combat, feeding the timeless filter |
| `test_style_bars.lua` | `modules/Style_Bars.lua`: every bar setting reaching the region it paints, icon side and gap, drain direction, texts, bindings, preview fill |
| `test_style_icons.lua` | `modules/Style_Icons.lua`: the art inside its border, the aspect crop, the cooldown swipe, the dispel border, texts, bindings, preview fill |
| `test_preview.lua` | `modules/Preview.lua`: how many placeholders are drawn and where, the pool, when they are dressed again |
| `test_blizzardframes.lua` | `modules/BlizzardFrames.lua`: reparenting `BuffFrame`/`DebuffFrame` under a hidden parent and back |
| `test_framepicker.lua` | `modules/FramePicker.lua`: the named-ancestor walk, the outline and label that track the cursor, every way a pick ends |
| `test_slash.lua` | `settings/Slash.lua`: `NS.COMMANDS` and every host verb through the real dispatcher |
| `test_slash_verbs.lua` | `settings/Slash.lua` verb by verb through the real dispatcher: the help surface, the schema verbs over relative and absolute paths, the host verbs, the degradation stub |
| `test_bulklog.lua` | debug-logging-§10's bulk rule, act by act: one `[Set]` line per bulk act counting the rows it changed; one line per profile reset or copy |
| `test_optionssetup.lua` | The panel: pages, tabs, the container banner, per-page Defaults, the global reset's blast radius, the degraded stub |
| `test_options_descriptor.lua` | `settings/OptionsSetup.lua`'s descriptor seams through real widgets and resets: the Profiles veto, the banner and picker, `RenderContainerPage`, the coalesced refresh, `OpenOptionsPage`, the stub's composers |
| `test_pages_general.lua` | `settings/General.lua` through its widgets: each Master control and Display row, the composer's two buttons, Defaults |
| `test_pages_containers.lua` | `settings/Containers.lua` through its widgets: the identity rows, Duplicate / Delete / Copy settings from, the Overview tab, the picker |
| `test_pages_filters.lua` | `settings/Filters.lua` through its widgets: the rows each aura type is offered, the two spell-set tabs, the warnings |
| `test_pages_layout.lua` | `settings/Layout.lua` through its widgets: the attach rows and their cycle guard, the picker's two buttons, what a Growth or Frame row re-applies, Defaults |
| `test_pages_bars.lua` | `settings/Bars.lua` through its widgets: tabs, the not-drawn-as-bars notice, sliders and swatches, Defaults |
| `test_pages_icons.lua` | `settings/Icons.lua` through its widgets: tabs, the not-drawn-as-icons notice, rows, Defaults |
| `test_pages_about.lua` | `settings/About.lua`: the command list, the Notes line and the logo, and when each is read |
| `test_pages_profiles.lua` | `settings/Profiles.lua`: the table it registers, how often it opens the dialog and into what, when it opts out |
| `test_envsetup.lua` | `core/EnvSetup.lua` on both arms (live and library-absent): which manifest `NS.Meta` reads, what `NS.Version` answers |
| `test_poolsetup.lua` | `core/PoolSetup.lua`: the library seam, and a library-absent fallback that recycles exactly as the library does |
| `test_defaults.lua` | `defaults/Profile.lua` and `defaults/Categories.lua`: the shape invariants the code relies on |
| `test_perf.lua` | The perf wiring: every bucket reached, a dormant probe free, suspend inert, the degraded stub |
| `test_debuglogsetup.lua` | `core/DebugLogSetup.lua`: the descriptor this addon owns (flag, `[Init]` summary, chat acknowledgment, visibility refresh) and its stub |
| `test_locale.lua` | `locales/enUS.lua` defines every routed string and nothing unused |
| `test_docs.lua` | README placeholders, US spelling (localization-§5's lists), the Documentation map both ways, every file:line citation resolving to a non-blank line |
| `test_surface_parity.lua` | Each degradation stub against the live surface it stands in for |
| `test_vendor_sync.lua` | `libs/LibKa0s/` and `tests/_kit/` against the LibKa0s tag named in `CLAUDE.md` |
| `test_lintconfig.lua` | `.luacheckrc` carries no blanket suppression, no source file carries a bare inline luacheck ignore, and no `#` shares its line with a keyword or brace lizard must see |
| `tests/_kit/test_eol.lua` | Every tracked file carries the line ending `.gitattributes` declares |

## Root and media

| File | Responsibility |
|---|---|
| `AuraMaster.toc` | Metadata (Interface 120100, version 0.1.0, `X-Standard`), SavedVariables `AuraMasterDB` and `AuraMasterPerfDB`, the load order |
| `.luacheckrc` | Lint config: Lua 5.1, excludes `libs/`, `tests/_kit/` and the frozen `docs/` bundles; the harness global in a `tests/` stanza |
| `.pkgmeta` | Packager config: no externals; ignores dev files, `docs`, `tests`, and the `.png`/`.jpg` logo sources |
| `.gitattributes` | The client-bound line-ending policy (line-endings-§5): CRLF working tree, `*.sh` LF, binaries marked |
| `.gitignore` | OS and editor clutter, agent scratch directories |
| `LICENSE` | MIT |
| `README.md`, `CLAUDE.md`, `DEPENDENCIES.md` | The three root docs (documentation-§1/§2/§7) |
| `docs/` | The engineering docs; every file is registered in `docs/ARCHITECTURE.md` → Documentation map, which also names the frozen bundle directories |
| `media/logos/auramaster.logo.tga` | The logo the client loads (landing page, `## IconTexture`); `.png` and `.jpg` beside it are the source art |
