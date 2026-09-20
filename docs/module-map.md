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
   `filter.categories` is built from the category lists.
5. **`modules/`** — `TextTemplate.lua` before `Style_Text.lua` (a file-scope upvalue), and
   `Style.lua` before `Style_Bars.lua`, `Style_Icons.lua` and `Style_Text.lua`, which decorate
   `NS.Style` at file scope. The rest reach each other only at call time.
6. **`settings/`** — last. `Schema.lua` first (every page registers into it), `Slash.lua`, then
   `OptionsSetup.lua` before every page file, because the pages call the composers
   (`NS.Helpers.ColorPair`, `FontGroup`, `BorderGroup`, `BarGroup`, `MasterControls`) inside
   `NS.RegisterSchemaRows` at file load. The page files are in the order their Blizzard subcategories
   appear (**load-bearing** for the tree order, N-2): `General.lua`, then `Containers.lua`, then its
   five sub-pages `Filters.lua`, `Layout.lua`, `Bars.lua`, `Icons.lua`, `Text.lua` (each marked with
   `NS.SubPageLabel`'s indent, D6), then `Profiles.lua`. `GeneralSpells.lua` loads before
   `General.lua` (**load-bearing**): it publishes its rows and tab renderers, and `General.lua`
   registers those rows after its own, so the Spell Categories and Dispel Colors tabs follow Display.

## `locales/`

| File | Responsibility |
|---|---|
| `locales/enUS.lua` | Creates `NS.L` with the key-fallback metatable (localization-§1) and lists every English string, keys equal to values |

## `core/` (TOC order)

| File | Responsibility | Load position |
|---|---|---|
| `core/Namespace.lua` | `NS.name`, the fallback `NS.version`, the cyan `[AM]` `NS.PREFIX` | **Load-bearing**: every seam below reads these |
| `core/Compat.lua` | The 21 client-API shims (aura engine enums, secrecy, formatters, color curves, the duration text binding, mouse focus, spell info) — `docs/compat-layer.md` | Conventional: reached at call time |
| `core/MediaSetup.lua` | `LibKa0s-Media-1.0` seam: `NS.Icon`, `NS.MediaFont`, `Media.RegisterLSM` at file load | **Load-bearing**: before `Constants.lua`, which resolves `FONT_MONO` from `NS.MediaFont` |
| `core/Constants.lua` | Enum-like tables and labels (units, aura types, styles, sort methods, points, dispel colors, preview auras), fallback media, `LOGO_PATH` | Read by everything after it |
| `core/State.lua` | Session-only state: `debug`, `activeContainerId`, `testMode`; `State.SetActiveContainer` | Conventional |
| `core/EnvSetup.lua` | `LibKa0s-Env-1.0` seam: `NS.Meta(field)`, `NS.Version()` | Conventional: nothing resolved at load |
| `core/CoreSetup.lua` | `LibKa0s-Core-1.0` seam: `NS.Print`, `NS.Printf`, `NS.SafeToString`, `NS.ResolveColor`, `NS.ClassColor`, `NS.SKIN`/`ApplySkin` (the skin seam, published for a future standalone window; nothing consumes it today), the `NS.MakeCloseButton` wrapper; `NS.LIBKA0S_MISSING` | **Load-bearing**: after `Namespace.lua`, before everything that prints |
| `core/Bus.lua` | The closed message bus: `NS.bus`, `NS.NewBusTarget()`, the four `NS.MSG` names | **Load-bearing**: `settings/OptionsSetup.lua` subscribes at load |
| `core/PoolSetup.lua` | `LibKa0s-Pool-1.0` seam, or a four-member local pool (`New`, `Acquire`, `ReleaseAll`, `Counts`) | Conventional |
| `core/LifecycleSetup.lua` | `LibKa0s-Lifecycle-1.0` seam: the ONE latch behind both reasons to be inert — `NS.lifecycle`, `NS.IsStoodDown`, `NS.IsDisabled`, `NS.SyncEnabled`, and the `standDown` / `standUp` pair the whole addon goes down and comes back up through | **Load-bearing**: before `core/PerfSetup.lua`, which takes the instance as its `lifecycle` field |
| `core/PerfSetup.lua` | `LibKa0s-Perf-1.0` seam: `NS.Perf` with six buckets, the `perf` hold on that latch, `AuraMasterPerfDB` | **Load-bearing**: before every file taking `local Perf = NS.Perf` |
| `core/Secrets.lua` | The only place that asks whether a value is secret: `IsSecret`, `CanAccess`, `IsReadableNumber`, `IsSafeKey` | Conventional |
| `core/DebugLogSetup.lua` | `LibKa0s-DebugLog-1.0` seam: `NS.DebugLog`, the gated sink `NS.Debug`, the `[Init]` summary | **Load-bearing**: after `Constants`, `State` and `CoreSetup`; before any `NS.Debug` caller |
| `core/LauncherSetup.lua` | `LibKa0s-Launcher-1.0` seam: `NS.Launcher`, the one broker object behind both the minimap button and a broker display. Left-click toggles test mode (rung (b)), right-click opens the panel | Conventional: `Register()` is called from `OnInitialize` after `InitDB`, and every click resolves at call time |
| `core/AuraMaster.lua` | The AceAddon: `OnInitialize`, `OnEnable`, the eight lifecycle events and their handlers, `NS.OnProfileChanged` | **Load-bearing**: the AceAddon promotion; reclaims `NS.Print` from AceConsole's embed |
| `core/Database.lua` | AceDB init (with a no-AceDB fallback), the container accessors (`GetContainers` in display order, `GetContainersByName` for the pickers), `RunMigrations` and the `SCHEMA_STEPS` ladder (v2: `MigrateV2`; v3: `MigrateV3`, the Show/Hide
category collapse and the `weaponEnchants` category row — both over every stored profile; v4: `MigrateV4`, which folds the retired `filter.onlyShown` toggle into the `uncategorized` categories' Hide), `PrepareProfile` (the registry's load pass: repair and first-run seeding, which write the registry, `seeded`, backfilled template leaves and `c.id` stamps directly, as architecture-§5 allows a named load pass), `NewContainerData` (the id mint, called only by the registry writer), registry reads, `DeepCopy`/`Backfill`, and `Merge` (a test seam) | Conventional: called from `OnInitialize` |

## `defaults/`

| File | Responsibility |
|---|---|
| `defaults/Categories.lua` | The 17 buff and 17 debuff categories (kinds `token`, `flag`, `dispel`, `spells`, `enchant` for `weaponEnchants`, and `uncategorized` for `uncategorized` and `uncategorizedDebuffs`), the starter spell lists, `For`/`Find`/`IsSpellCategory`/`DefaultStates` |
| `defaults/Profile.lua` | `NS.defaults` (profile and global), `NS.CONTAINER_TEMPLATE`, `NS.STARTER_CONTAINERS` — the one place a default is hardcoded |

## `modules/` (TOC order)

| File | Responsibility |
|---|---|
| `modules/TimedSpells.lua` | Learns which buff spell ids carry a duration while auras are readable, for "only auras without a duration"; listens through AceEvent only while a container needs it and auras are readable, and announces what it learned on the bus |
| `modules/FilterCompiler.lua` | Pure: one container's filter settings → aura groups (filter strings + candidate filters), enchant slots and warnings, with the profile's spell-category edits handed in through `ctx` (`FC.ProfileContext`); `Signature`, `StructureKey`; the two identity-gate predicates `FC.IdsHonored` (can the engine EVER honor spell ids on this unit and aura type — what `identityWarning` picks its sentence from) and `FC.IdsAlwaysHonored` (are they CERTAIN to be applied — buffs on the player and pet alone, the gate an `uncategorized` Show group must clear in both `Compile` and `ExplainSpell`) |
| `modules/TextTemplate.lua` | Pure: the Text style's template language. `TT.Compile` turns a template into ordered pieces (literal, name, stacks, dispel, duration run), memoized; `TT.Validate` is the Template row's `validate`; `TT.ForDraw` draws a refused stored template as the default |
| `modules/Style.lua` | Shared dressing: LSM fetch, class color (the container's unit's, as snapshotted), text in a box its justify can act in, border (a plain frame, `NewBorder`: Solid as four strips, another style a backdrop applied only while its size reads plain, `ApplyBorder`, guarded by `GuardedBorder`; the same strips as a plain frame's edge, `DrawEdge`), guarded engine bindings (the additive ones cleared first, `ClearAdditiveBindings`), a caught dress error reported once per message (`ReportError`), one region set per style on a frame (`RegionsFor`), element size, mouse behavior and hover (`TakesHover`), duration text and a placeholder's time text (`PreviewTime`), the profile's dispel palette (`DispelColorMap`); the style dispatch (`StyleKey`, `Styler`, `StructureKey`), the shared icon helpers (`IconSizeFor`, `IconInset`, `LayoutIcon`), a Text duration run's `textFormat` and binding, the measured time-text width (`TimeTextWidth`), the measured padding a Text chain pulls each piece back by (`PiecePadding`); bucket `styleElement` |
| `modules/Style_Bars.lua` | Builds and dresses a bar button; the elapsed-time status bar with an edge-anchored fill; the icon and its border; the spark, clipped to the elapsed region when timeless auras show none; preview fill |
| `modules/Style_Icons.lua` | Builds and dresses an icon button: aspect-correct crop, cooldown swipe, the dispel border on its own frame above ours (`dispelHost`), in Blizzard's own colors; preview fill |
| `modules/Style_Text.lua` | Builds and dresses a text button: clip, animation and text-area frames, one chain of font strings per template shape, the Left/Right/Center chain anchors (each piece justified to its side, pulled back by the measured padding), the line's font, the three loops (played at dress time), each piece's engine binding (rule formatter, dispel text map, duration `textFormat` with a prebuilt binding and the blink curve), the optional icon; preview fill |
| `modules/Anchors.lua` | Places a container's anchor on the screen, another container or a named frame; cycle check; the flow a container attached to another inherits (`FlowRoot`, `EffectiveLayout`, `DerivedPoints`, `Followers`); re-placing those attached to a previewing container onto its extent (`PlaceAttached`); pending frame re-resolve; the drag handle (a plain button: a fill texture and `Style.DrawEdge` strips), `HANDLE_LEVEL` above its anchor and above an attached target's |
| `modules/Preview.lua` | Placeholder elements from one pool per style (`container.previewPools[style]`), dressed by `Style` with `engine` false, positioned by `Preview.Offset`; the extent the containers attached to this one hang from while it previews (`Preview.Extent`); the test mode switch (`Preview.SetTestMode`) |
| `modules/FramePicker.lua` | The click-to-pick overlay: outlines the named frame under the cursor (a plain frame, `Style.DrawEdge` strips); left-click picks, right-click or Escape cancels |
| `modules/BlizzardFrames.lua` | Reparents `BuffFrame`/`DebuffFrame` to a hidden parent and back, out of combat only |
| `modules/Container.lua` | One live container: its anchor, handle and unlocked outline (a plain frame, `Style.DrawEdge` strips), building, updating or retiring its engine, restyling, the per-apply class snapshot, the show ladder; bucket `applyContainer` |
| `modules/ContainerManager.lua` | The registry's one writer (create, delete, duplicate; `Database.PrepareProfile` is its load pass, and `docs/ARCHITECTURE.md` → Settings Schema names both), plus rename, copy-from and reset positions through the write seam; the coalesced and deferred apply (each container's apply guarded, so an error is reported once and the pass goes on), a flow or attachment write re-applying the containers that follow it, visibility and unit refresh (with the class re-apply on a swap); buckets `applyPass`, `visibilityPass` |

## `settings/` (TOC order)

| File | Responsibility |
|---|---|
| `settings/Schema.lua` | The path machinery: container-relative resolution, `NS.RegisterSchemaRows`, the read seam `NS.GetSetting`, the write seam `NS.SetByPath`, the carve-outs, `NS.Choices`, `NS.ValidateSchema` |
| `settings/Slash.lua` | `NS.COMMANDS` (22 verbs), the host verbs, the `LibKa0s-Slash-1.0` descriptor and its degradation stub, `/am` and `/auramaster` registration |
| `settings/OptionsSetup.lua` | The `LibKa0s-Options-1.0` descriptor (its `get` shows a row's `panelGet`) and its load-completing stub; the container banner and the Containers chrome block (`ContainerHeader`); `RenderTabbedPage` (schema-group tabs, then bespoke tabs, each optionally `before` another; a page-wide disable with its notice, `disabledFor` and `disabledNotice`; `pairWith`) and `RenderContainerPage`; `NS.RegisterContainerPage`, `NS.OpenOptionsPage`, `NS.RequestPanelRefresh` |
| `settings/About.lua` | The landing page body: logo, the TOC Notes line, the slash command list |
| `settings/GeneralSpells.lua` | General → Spell Categories (one spell category's ID list over the profile's `categorySpells` and its restore, or — for the Weapon enchants entry — the profile-wide `enchantSlots` toggles) and General → Dispel Colors (the six profile-wide `dispelColors.<type>` rows); registers nothing itself, `settings/General.lua` registers its rows and draws its tabs |
| `settings/General.lua` | The General page: the composed Master controls tab and the Display tab; registers the Dispel Colors rows after its own and draws the Spell Categories and Dispel Colors tabs; the Reset all popup |
| `settings/Containers.lua` | The top-level Containers page (`N-1`, batch 7): the picker and New container in the band above the strip (`Helpers.ContainerHeader`), and one tab, General: the name, enable, unit, aura type and style rows, Duplicate / Delete / Copy settings from |
| `settings/Filters.lua` | The Filters page, a sub-page of Containers (`N-2`, D6): what to show, the generated Show/Hide category rows (drawn as grids with a `See spells` link by a bespoke Categories tab), the five-rank priority block at the foot of What to show, sorting, and the bespoke Overrides tab (placed `before` Sorting) (two ID lists, each entry's verdict note from `FC.ExplainSpell`) |
| `settings/Layout.lua` | The Layout page, a sub-page of Containers (`N-2`, D6): frame, anchor (Screen / Another container / Named frame / Offset, drawn by attach mode), growth, mouse; Pick a frame |
| `settings/Bars.lua` | The Bars page, a sub-page of Containers (`N-2`, D6): size, the composed bar, border and font blocks, spark, the icon and its composed border, background, text placement, the pandemic window (time color and highlight); disabled for any other style |
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
| `tests/perf.lua` | The offline performance scenario runner (outside the green gate) — `docs/performance.md` |
| `tests/page_helpers.lua` | Not a suite: drives a settings page as a player does on a fresh environment (the widgets one render drew, finding a widget by its row's label, chat capture, tab moves, and `P.suggestions()`, which reads the ID lists' suggestion dropdown), for the `test_pages_*` suites |
| `tests/region_recorder.lua` | Not a suite: a stand-in frame region that records every method called on it, so the style suites can tell one region's paint from another's (the kit hands a frame back as its own texture) |
| `tests/engine_recorder.lua` | Not a suite: makes a recorder button answer its dispel bindings the way the client's `CustomAuraButton` does (every `Set*` / `Add*` binding ends in a full apply pass; `ClearDispelTypeTextures` only empties the list) |
| `text_apis.lua` | Not a suite: the Text style's client APIs as recording stand-ins, installed from a fresh environment's `before` |
| `region_builder.lua` | Not a suite: a recorder that builds recorders, so each piece of a chain records its own calls |
| `tests/border_strips.lua` | Not a suite: reads an element border as `Style.ApplyBorder` draws it, its four Solid strips and its backdrop frame (B2-3); gives a kit frame recorder textures (`recorderTextures`) so the outline's and the handle's strips read apart |
| `tests/test_*.lua` | One suite per subject, in the order `tests/run.lua` declares them; the cases are enumerated in the generated `docs/test-cases.md` |

The suites, in the order `tests/run.lua` runs them (it is the authority on the list):

| Suite | Covers |
|---|---|
| `test_loadorder.lua` | The TOC's load-bearing positions; the runners' load lists derived from the TOC and the XML |
| `test_setups.lua` | The LibKa0s seams' addon-side wiring (printer, media, env, debug flag) and a real library-absent load |
| `test_database.lua` | `core/Database.lua`: seeding once, repair of ids, order and wrong-typed sections, backfill that keeps a stored `false`, the migration runner and schema v2 over every stored profile, the no-AceDB fallback |
| `test_schema.lua` | `settings/Schema.lua`: every row resolves, class-color companions, the container-relative path model, the carve-outs |
| `test_schema_paths.lua` | `settings/Schema.lua` in depth: the write seam's order, the relative and absolute path models, registration and validation, carve-outs, whole sections, `CheckWrite`, `ApplyDefault`, the session rows |
| `test_filtercompiler.lua` | `modules/FilterCompiler.lua`: settings in, aura groups and warnings out |
| `test_container.lua` | `modules/Container.lua` against the recorded engine: call order, update in place vs rebuild (the growth corner included), the show ladder, preview |
| `test_containermanager.lua` | `modules/ContainerManager.lua`: the registry's write side, coalesced apply, an apply error that leaves the rest of the pass running, followers re-applied, combat and secrecy deferral |
| `test_compat.lua` | `core/Compat.lua`: every shim with the client API present and absent |
| `test_secrets.lua` | `core/Secrets.lua`: the predicates degrade to "nothing is secret", answer strict booleans, and defer to `canaccessvalue` |
| `test_bus.lua` | `core/Bus.lua`: the message catalog, a target per receiver, one sender per message |
| `test_state.lua` | `core/State.lua`: session state never reaches SavedVariables; test mode is session-only and unlocking keeps real auras drawing |
| `test_lifecycle.lua` | `core/AuraMaster.lua`: the lifecycle events and the three AceDB profile handlers, fired through AceEvent |
| `test_disabled.lua` | The stand-down conformance suite (slash-commands-§7): the registration set, the live timer set, the shown frames, the SavedVariables writes and the printed lines, before and after the switch — plus the slash surface, the launcher's two buttons and the two-hold latch |
| `test_anchors.lua` | `modules/Anchors.lua` and `modules/FramePicker.lua`: attachment, cycles, the derived points and inherited flow, the preview extent, pending and forbidden frames, the drag handle |
| `test_style.lua` | `modules/Style*.lua` and `modules/Preview.lua`: element sizes, preview layout, engine bindings |
| `test_timedspells.lua` | `modules/TimedSpells.lua`: readable-state listening, the bus announcement, learning out of combat, feeding the timeless filter |
| `test_style_bars.lua` | `modules/Style_Bars.lua`: every bar setting reaching the region it paints, icon side and gap, drain direction, texts, bindings, preview fill |
| `test_style_icons.lua` | `modules/Style_Icons.lua`: the art inside its border, the aspect crop, the cooldown swipe, the dispel border, texts, bindings, preview fill |
| `test_style_text.lua` | `modules/Style_Text.lua`: the nested frames, the chain's anchors per justify, the measured padding and each piece's justify, the Center fallback, each piece's binding and options, the blink, the loops, the icon, a refused stored template, the chain per shape, the preview fill |
| `test_texttemplate.lua` | `modules/TextTemplate.lua`: every template rule with its message, the escapes, case, the compiled pieces, `ForDraw` |
| `test_preview.lua` | `modules/Preview.lua`: how many placeholders are drawn and where, the pool per style, when they are dressed again |
| `test_render_coverage.lua` | Every Bars, Icons and Text schema row, written to a value other than the one in force, reaches a drawn region on a live button and on a placeholder, unless it declares `coverage` |
| `test_blizzardframes.lua` | `modules/BlizzardFrames.lua`: reparenting `BuffFrame`/`DebuffFrame` under a hidden parent and back |
| `test_framepicker.lua` | `modules/FramePicker.lua`: the named-ancestor walk, the outline and label that track the cursor, every way a pick ends |
| `test_slash.lua` | `settings/Slash.lua`: `NS.COMMANDS` and every host verb through the real dispatcher |
| `test_slash_verbs.lua` | `settings/Slash.lua` verb by verb through the real dispatcher: the help surface, the schema verbs over relative and absolute paths, the host verbs, the degradation stub |
| `test_bulklog.lua` | debug-logging-§10's bulk rule, act by act: one `[Set]` line per bulk act counting the rows it changed; one line per profile reset or copy |
| `test_optionssetup.lua` | The panel: pages, tabs, the container banner, per-page Defaults, the global reset's blast radius, the degraded stub |
| `test_options_descriptor.lua` | `settings/OptionsSetup.lua`'s descriptor seams through real widgets and resets: the Profiles veto, the banner and picker, `RenderTabbedPage` and `RenderContainerPage`, the coalesced refresh, `OpenOptionsPage`, the stub's composers |
| `test_pages_general.lua` | `settings/General.lua` and `settings/GeneralSpells.lua` through their widgets: the Spell Categories ID list and its restore, the Dispel Colors rows; each Master control and Display row, the composer's two buttons, Defaults; the tab strip with Containers gone from it and no page keyed `containers` to `general`'s rows |
| `test_pages_containers.lua` | `settings/Containers.lua` through its widgets: the picker and New in the band above the strip, its identity rows, Duplicate / Delete / Copy settings from, a Delete that keeps the picker, Defaults (the name kept), and that the page registers on its own (N-1) |
| `test_pages_filters.lua` | `settings/Filters.lua` through its widgets: the rows each aura type is offered, the category grids, the Overrides ID lists, the warnings |
| `test_pages_layout.lua` | `settings/Layout.lua` through its widgets: the tab order, the attach rows, the subsections drawn per mode and their cycle guard, Pick a frame, the inherited Growth rows, the Point rows' first-aura wording and the facing-growth hint, what a Growth or Frame row re-applies, Defaults |
| `test_pages_bars.lua` | `settings/Bars.lua` through its widgets: tabs (the Icon tab among them), the not-drawn-as-bars notice with every control disabled, sliders and swatches, Defaults |
| `test_pages_icons.lua` | `settings/Icons.lua` through its widgets: tabs, the not-drawn-as-icons notice with every control disabled, rows, Defaults |
| `test_pages_text.lua` | `settings/Text.lua` through its widgets: the tabs, the notice and disabled rows for another style, the Template box and its refusal text (panel and `/am set`), the cheat sheet, the Justify note, the centering note, the rows the effect and the template dim, Defaults |
| `test_pages_about.lua` | `settings/About.lua`: the command list, the Notes line and the logo, and when each is read |
| `test_pages_profiles.lua` | `settings/Profiles.lua`: the table it registers, how often it opens the dialog and into what, when it opts out |
| `test_envsetup.lua` | `core/EnvSetup.lua` on both arms (live and library-absent): which manifest `NS.Meta` reads, what `NS.Version` answers |
| `test_poolsetup.lua` | `core/PoolSetup.lua`: the library seam, and a library-absent fallback that recycles exactly as the library does |
| `test_defaults.lua` | `defaults/Profile.lua` and `defaults/Categories.lua`: the shape invariants the code relies on |
| `test_perf.lua` | The perf wiring: every bucket reached, a dormant probe free, suspend inert, the degraded stub |
| `test_debuglogsetup.lua` | `core/DebugLogSetup.lua`: the descriptor this addon owns (flag, `[Init]` summary, chat acknowledgment, visibility refresh) and its stub |
| `test_launcher.lua` | The launcher (launcher-§1..§5): one object registered twice under the folder name, the icon file's own TGA header, rung (b)'s left click driving the lock through the seam, right-click opening the panel, the Minimap button row's inverting get/set, the two reserved verbs, and three degraded hosts |
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
| `media/logos/auramaster.logo.tga` | The landing-page logo, drawn at 300×300 (options-ui-§5) |
| `media/logos/auramaster.logo.128.tga` | The ICON logo, 128×128 and uncompressed 32-bit (layout-§4): `## IconTexture`, the minimap button and the broker row. Regenerated from the `.png`, never hand-edited |
| `media/logos/auramaster.logo.png`, `….jpg` | The 2000×2000 source art and its render; shipped but never loaded — the client reads neither format |
