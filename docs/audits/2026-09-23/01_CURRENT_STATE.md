# 01 — Current state: Ka0s Aura Master (2026-09-23)

## Run header

| | |
|---|---|
| Standard audited against | **Ka0s WoW Addon Standard v2.64.0 (2026-09-23)**, fetched from `raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master` with `curl -fsSL`: `AUDIT.md`, `standards/STANDARDS.md`, `standards/ADDONS.md` and all 27 section files the Sections list links. `tiered-layout.md` appears only in the changelog (retired v2.0.0) and 404s, as expected. |
| Repo kind | **Addon.** It has a `.toc` (`AuraMaster.toc`), and `standards/ADDONS.md` lists it in *In-scope addons* with launcher rung **(b) test mode**. The whole addon rule set applies. |
| Tree | `/mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster`, branch `feat/2026-09-23-review-audit-remediation`, HEAD `8046dfb` (merge of `suite/2026-09-22-standards-sweep`). The working tree was clean apart from an untracked `docs/reviews/2026-09-23/`, which a concurrent review run is writing. This audit ignored that folder and did not touch it. |
| Deviation-ID prefix | **`AM-`**, reused from `docs/audits/2026-09-11/`. Recurring gaps keep their IDs. New IDs start at `AM-21`. |
| Bounded runner | `ka0s-bounded` is not on `PATH` in this shell, but it is installed at `~/.claude/wow-addon/bin/ka0s-bounded`. Every `luacheck`, `lua tests/run.lua` and `lizard` run went through it by absolute path. No `timeout 900` fallback was needed. |
| Prior bundle | `docs/audits/2026-09-11/` (standard v2.42.0): 17 roots and 20 entries in total. Its status this run is in *Prior deviations* below. |

## Layout (`layout`)

- The five source folders are all present, plus `media/`, `libs/`, `tests/`, `docs/` and `tools/`. There are **47 authored source Lua files**: 1 locale, 16 core, 3 defaults, 14 modules and 13 settings. `docs/ARCHITECTURE.md:77-79` says the same.
- Authored-Lua census from `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'`: **110 files, 44,017 lines** (E-12). Four files are over the 1500-line cap:
  - `settings/GeneralSpells.lua`, 1528 lines;
  - `tests/test_database.lua`, 1702;
  - `tests/test_filtercompiler.lua`, 1567;
  - `tests/test_pages_general.lua`, 1761.
- Four files sit in the 1000–1500 band: `tests/test_pages_filters.lua` (1019), `tests/test_style.lua` (1170), `tests/test_anchors.lua` (1384) and `defaults/Categories.lua` (1478).
- The census heading `### Files over the 1500-line cap` sits under `## Documented deviations` (`docs/ARCHITECTURE.md:832-841`). It names all four over-cap files. Each one's terminal state is an open issue that names the peel seam: #16, #17, #18 and #19.
- The kit's gate `tests/_kit/test_layout_cap.lua` is wired as `{ name = "test_layout_cap", dir = "tests/_kit/" }` (`tests/run.lua:113`) and is green.
- The one authored generator is `tools/spell-research/research.py`. It sits under `tools/`, no TOC line loads it, and `.pkgmeta:16` ignores it. It writes `defaults/CastToAura.lua` (680 lines, GENERATED header at `:3-6`). The TOC loads that output, so the generated-data carve-out does not exempt it; it is under the cap anyway.
- `media/` holds only `media/logos/`, and none of it duplicates the shared media.

## TOC (`toc-file`)

- The field order matches `toc-file-§1` (`AuraMaster.toc:1-13`).
- `## Interface: 120100` matches the README badge `Midnight_12.1.0` (`README.md:3`).
- `## IconTexture` points at `media/logos/auramaster.logo.128.tga`. Its header reads type 2, 128×128, 32 bpp (E-18).
- `## SavedVariables` declares `AuraMasterDB` and `AuraMasterPerfDB`.
- `## X-Curse-Project-ID: 1698345` has been present since commit `a326ed7` (2026-09-16). That id is what AM-20 turns on.
- The `# Libraries` block lists `libs\LibKa0s\LibKa0s.xml` once, after Ace3 (`:29`).
- Section headers run Libraries → Locales → Core → Defaults → Modules → Settings. Every load-bearing position carries a comment naming what resolves, and every conventional group is marked. That closes prior `AM-15`.
- The file ends in a single CRLF.

## Libraries (`library-stack`)

- Vendored under `libs/`: LibStub, CallbackHandler-1.0, AceAddon/Event/Timer/Console/DB/GUI/Config/DBOptions, LibDataBroker-1.1, LibDBIcon-1.0, LibKa0s, LibSharedMedia-3.0 and AceGUI-3.0-SharedMediaWidgets.
- Provenance: `CLAUDE.md:36`, `Bundles [LibKa0s](…) v1.55.0 (MIT).` The line is in `CLAUDE.md` only, not in `README.md`.
- `diff -r` against the sibling `../LibKa0s` at tag `v1.55.0` (commit `bb161b7`, extracted with `git archive`) is **empty for both payloads**: `LibKa0s/` against `libs/LibKa0s` (24 entries each side) and `testkit/` against `tests/_kit`. The sibling's own HEAD is `v1.55.0-3-g46ccaa6`, which was not used (E-6).
- `tests/_kit/run-automated-tests.sh` is recorded as `100755`.
- Twelve LibKa0s majors are wired, one setup file each (`docs/ARCHITECTURE.md:54-67`). `Item`, `Widgets` and `Schema` arrive unwired. Not wiring `Schema` is permitted at v2.64.0 and is tracked as issue #21. The Bus stand-down record was declined (#20, `state:will-not-do`); that is also permitted and needs no register row (library-stack-§7).

## Shared-subsystem wiring: descriptors and degradation stubs

| Module | Setup file | Lookup, then stub branch |
|---|---|---|
| Core | `core/CoreSetup.lua` | `:16` `LibStub("LibKa0s-Core-1.0", true)`; stub at `:18-91` holds the guarded stringifier and printer (the sanctioned degraded twin); `NS.MakeCloseButton` wrapper at `:117-119` |
| Env | `core/EnvSetup.lua` | `:17`; falls back to `C_AddOns.GetAddOnMetadata` (`:26-27`), never the deprecated global |
| Media | `core/MediaSetup.lua` | `NS.Icon`/`NS.MediaFont` pass `addonName`; one `RegisterLSM(addonName)` |
| Lifecycle | `core/LifecycleSetup.lua` | `:118`; stub at `:120-131` answers from the stored path; one latch with two holds (`:136-160`) |
| Perf | `core/PerfSetup.lua` | silent lookup, guarded; six buckets with one `within`; `lifecycle = NS.lifecycle` |
| DebugLog | `core/DebugLogSetup.lua` | descriptor carries `addonName`; the stub carries every member the surface-parity gate lists |
| Launcher | `core/LauncherSetup.lua` | label `Ka0s Aura Master`; rung-(b) `onClick` refuses while disabled; right-click opens settings |
| Bus / Compat | `core/Bus.lua`, `core/Compat.lua`, `core/Secrets.lua` | Bus: `Catalog` only, untracked factory kept, stub carries `Catalog` and says why it omits `New`. Compat: reader and guard arms |
| Options | `settings/OptionsSetup.lua` | `:193` stub. Load-completing, but its composers reproduce the composed blocks' stored surface (AM-22) |
| Slash | `settings/Slash.lua` | `COMMANDS` at `:33` (22 verbs); `isEnabled`, `liveVerbs` and `brandName` descriptor fields; `RegisterChatCommand` at `:523-524` |

- The close-button grep returns the one wrapper (`core/CoreSetup.lua:118`) and nothing else outside `libs/` and `tests/` (E-13).

## Architecture patterns (`architecture`)

- `NS` becomes the AceAddon (`core/AuraMaster.lua:17`). `NS.Print` and `NS.Printf` are reclaimed after the AceConsole embed (`:23-24`).
- The closed bus has four messages declared once through `Bus.Catalog` (`core/Bus.lua:46-63`). No `Ka0s_` literal appears at any call site, and every tail is PascalCase (E-14). Each receiver owns its own target.
- The two structural registries (containers and user categories) are named with their writers and load passes (`docs/ARCHITECTURE.md:145-186`). Named non-setting state covers `global.timedSpells` and `AuraMasterPerfDB` (`:216-241`); LibDBIcon's `minimapPos` is not named there (AM-33).
- The write seam is `NS.SetByPath` (`settings/Schema.lua:711`).

## Settings (`options-ui`)

- Pages: a landing page (`settings/About.lua`), then General (Master controls, Display, Spell Categories, Dispel Colors), Containers, Filters, Layout, Bars, Icons, Text and Profiles.
- `tests/test_schema.lua:34` pins that every row carries a `group`. Master controls is composed from `H.MasterControls`, with all ten canonical rows (`settings/General.lua:5-11`, `:51-61`).
- Font, border, bar and colour-pair blocks are composed. That closes prior `AM-05`: the Bars background is `H.BarGroup`, `settings/Bars.lua:83`.
- The wrap-stability case exists (`tests/test_optionssetup.lua:295`), closing prior `AM-06`.
- No `disabledIf` sits on a colour row (`settings/Text.lua:437` excludes colour rows explicitly). There are no arrow-button reorders.
- Blizzard's settings window is touched in only two places, both outside combat: the frame picker's close behind an `InCombatLockdown` refusal (`settings/Layout.lua:220-224`), and a subcategory page jump behind the canonical refusal (`settings/OptionsSetup.lua:366-373`). That closes prior `AM-19`.
- The global reset popup text is verbatim (`settings/General.lua:143-149`).

## Slash (`slash-commands`)

- `/am`, with `/auramaster` as alias. 22 verbs, including the reserved set plus `enable`, `disable`, `lock`, `unlock` and `test`.
- While disabled, eight feature verbs refuse on one line through the library's gate (`settings/Slash.lua:109-133`, `:447-457`). `containers` and `select` stay live, with the reason written at `:113-123`.
- `enable`, `disable`, `lock` and `unlock` write through `NS.SetByPath`, but confirm with custom sentences rather than in §5's `set` shape (AM-29).

## The disabled state (`slash-commands-§7`)

- **The teardown** is the Lifecycle latch, with `disabled` and `perf` holds. There is no second teardown.
- **The registration census** is E-11. Of 19 registrations, all are undone by `standDown` except two:
  - the settings panel's own refresh subscription (`settings/OptionsSetup.lua:396`). open-evolutions records this as open, so it is not filed;
  - the `PLAYER_REGEN_ENABLED` pending hold (`core/LifecycleSetup.lua:71`), which is the sanctioned survivor and is released when it fires.
- **Timers.** `CM.RequestApply` arms nothing while stood down. Two one-shot `C_Timer.After` callbacks armed *before* a stand-down cannot be canceled, and wake once to find the latch (AM-24).
- **Writes.** No SavedVariables write comes from a game event while disabled: `UNIT_AURA` is unregistered, so `TS.Scan` cannot run.
- **Launcher.** Left-click is refused and right-click opens the panel.
- **The suite.** `tests/test_disabled.lua` asserts on the kit's recording registry and timer set. Negatives carry `red under:` comments. Step 7 follows the v2.57.0 surface.
- **Adoption.** LibKa0s v1.55.0 is at or above the v1.42.0 floor.

## Events and taint (`events-frames-taint`)

- The eight lifecycle events are registered by bare `self:RegisterEvent` calls (`core/AuraMaster.lua:57-67`), and TimedSpells registers three more the same way (`modules/TimedSpells.lua:140-142`). There is no per-event `pcall` helper and no record of rejected names (AM-23).
- TimedSpells now listens through AceEvent rather than a private frame, which closes prior `AM-04`.
- Combat handling: parked teardown, `Anchors.ResolvePending` replayed on `PLAYER_REGEN_ENABLED` (`core/AuraMaster.lua:99`), and create/delete refused in combat. That closes prior `AM-01` and `AM-02`.

## Debug (`debug-logging`)

- The console comes from the library. Tracing covers deferrals and anchor fallbacks: `tests/test_anchors.lua` has "a screen fallback and a skipped resolve are traced", which closes prior `AM-16`.

## Tests and lint (`testing`, `lint`)

- `luacheck .` gives **0 warnings / 0 errors in 110 files**. `exclude_files` narrows the test tree to `tests/_kit/`, and `AM_TEST` is declared in `files["tests/"]`. Four `read_globals` entries are referenced by no file (AM-28).
- `lua tests/run.lua` gives **1296 passed, 0 failed, 0 skipped, 1296 total**. The run took 2m54s wall and 36.4s user CPU (28% utilization), serial (AM-27).
- This matches `docs/test-cases.md` (Total 1296) and the README badge `1296/1296`.
- The kit gates `test_prose`, `test_eol` and `test_layout_cap` are declared with `dir = "tests/_kit/"` (`tests/run.lua:108-113`). `test_vendor_sync` and `test_surface_parity` are present.

## Performance and complexity (`performance`, `automated-tests`)

- The harness is wired, `tests/perf.lua` derives its load list, and `docs/perf-analysis/README.md` exists with an empty capture index.
- `lizard 1.24.0` over the verbatim invocation: **30,336 NLOC, 3,348 functions, average CCN 2.3, 2 warnings**. The two warned functions are `Cat.SyncUserCategories` (CCN 25) and `renderCategories` (CCN 16).
- The newest recorded run is `20260916-184324`, 129 commits behind HEAD: 21,163 NLOC, 2,446 functions, 0 warnings. That drift is AM-31.

## Packaging, line endings, root docs

- `.pkgmeta` carries no externals and ignores `tools`, `docs`, `tests`, `_dev` and the dotfiles. It also ignores `.claude`, which does not exist (AM-35).
- `.gitattributes` pin, verbatim:

  ```
  * text=auto eol=crlf
  *.sh text eol=lf
  *.py text eol=lf
  ```

  The body is byte-identical to line-endings-§5's client-bound canonical file once the working tree's CR is stripped, with no appendix. The working-tree check (e) counts **1** file (AM-30).
- `README.md` follows the canonical order. The Standard badge is bare, there is no logo image and no library inventory, and `## Credits` is external only. `## Screenshots` is still a placeholder (AM-20).
- `CLAUDE.md` is a compliant stub. `DEPENDENCIES.md` exists; see AM-08 and AM-34.

## `docs/`

- Tier 1: all six docs present.
- Tier 2: slash-dispatch (22 commands), midnight-quirks, compat-layer (21 shims by the documentation-§3 grep), profiles and perf-analysis are all present. message-bus (4 messages) and debug are marked *Not applicable*.
- Verification-and-record table: exactly six rows.
- Tier 3: "None". But `docs/spell-research/2026-09-20/*.md` is registered nowhere (AM-26).
- The hub is 841 lines (AM-25).
- No retired docs, no `docs/pending/`, no `TODO.md`, no `CHANGELOG.md`.

## Issue store

`gh issue list --state all` returns 21 issues. All carry `state:` and `severity:` labels, and none has a `[status]` title prefix. #10 is closed but labelled `state:triaged` (AM-36).

## Prior deviations (2026-09-11), status this run

| ID | Status |
|---|---|
| AM-01, AM-02, AM-04, AM-05, AM-06, AM-09, AM-10, AM-11 (the latch now gates FlushPending, `modules/ContainerManager.lua:253`), AM-12 (spot check: the remaining fallbacks are neutral 0/1 identities or template reads), AM-14, AM-15, AM-16, AM-17 (master rows go through `CONFIG_CHANGED` effects, `settings/General.lua:70-77`), AM-18, AM-19 | **Closed** |
| AM-03 | **Recorded**: the `options-ui-§17` register row, ratified 2026-09-12 (`docs/ARCHITECTURE.md:825`) |
| AM-07 / AM-08 | **Recur**, 8 citations |
| AM-13 | **Recurs**, narrower |
| AM-20 | **Recurs**: the register row's trigger has fired |
