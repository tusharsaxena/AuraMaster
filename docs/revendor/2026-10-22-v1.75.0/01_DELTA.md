Delta: LibKa0s v1.71.0 -> v1.75.0

# 01 — Delta (AuraMaster)

Run: 2026-10-22, item `AM-RV` of the 2026-10-22 run "LibKa0s issues #45-#58" (milestone M2),
executed non-interactively under the run's binding rulings: M2 holds no interview and files no GitHub
issue, and candidates are listed and recorded as "not adopted in this run". Procedure: the installed
dev-copilot 2.4.0 `/dev-copilot:wow-revendor-libka0s`. Branch `feat/2026-10-22-libka0s-issues-45-58`,
created from `master` @ `c346c27` on a clean tree.

Source: the sibling checkout `../LibKa0s`, **local annotated tag `v1.75.0` (tag object `eae0ee5` ->
commit `265a89e`)**, not on `origin`. Extracted with
`git -C ../LibKa0s archive v1.75.0 LibKa0s testkit tools | tar -x -C <scratch>`, never a branch tip;
`tools/` only for `prune-icons.lua`, which is never copied into the addon.
`git -C ../LibKa0s log --oneline v1.71.0..v1.75.0` lists 56 commits; `git -C ../LibKa0s diff --stat
v1.71.0 v1.75.0 -- LibKa0s testkit` ends `5752 files changed, 8798 insertions(+), 121 deletions(-)`,
almost all of it v1.74.0's icon art.

AuraMaster never vendored v1.72.0, v1.73.0 or v1.74.0, so there is no span bundle: their deltas are
recorded here, inside the `v1.71.0..v1.75.0` range.

## 3a — Claimed version, before this run

`grep -n '[Bb]undles' CLAUDE.md` -> `CLAUDE.md:36: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.71.0 (MIT).`
It stood alone as its own paragraph, so no provenance split was needed. The last payload commit
(`git log -1 --format=%H -- libs/LibKa0s tests/_kit`) is `b4c29ab` (RV-AM), whose `CLAUDE.md` names
v1.71.0 too. Payload check against the claimed tag: `diff -rq <v1.71.0>/LibKa0s libs/LibKa0s && diff
-rq <v1.71.0>/testkit tests/_kit` printed `payload-matches`.

**Base: v1.71.0.** Step 0's pre-flight for this addon: the newest single-tag bundle,
`docs/revendor/2026-10-07-v1.71.0/`, states base v1.70.0, and the provenance before `b4c29ab` was
v1.70.0. No mismatch, no correction.

## 3b — Actual version, before this run

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` gave v1.71.0's
thirty-four constants, and `Kit.VERSION` was 38. Claim and bytes agree.

## 3c — Per-file minor delta

The file list is the tag's `LibKa0s/LibKa0s.xml`, which gains `Glow.lua`, `MediaIcons.lua`,
`OptionsDrawer.lua`, `Sim.lua`, `SimTimeline.lua` and `SimPanel.lua` against v1.71.0's (forty files
now). Old is this addon's copy before the run; new is the tag.

| File | v1.71.0 | v1.75.0 | Release that moved it |
|---|---|---|---|
| `Core.lua` | 10 | **11** | v1.75.0 (comment-only, #57) |
| `Item.lua` | 2 | **3** | v1.75.0 (`Item.BonusIDsFromLink`, #51) |
| `Glow.lua` | (new) | **1** | v1.75.0 (new major `LibKa0s-Glow-1.0`, #56) |
| `Media.lua` | 4 | **5** | v1.74.0 (three icon sets, `ICON_SETS`, `IconAuthor`) |
| `MediaIcons.lua` | (new) | **1** | v1.74.0 (generated catalog) |
| `Widgets.lua` | 12 | **13** | v1.75.0 (`W.SearchBox` #52, `W.TestStrip` #48) |
| `DebugLog.lua` | 19 | **20** | v1.75.0 (comment-only, #57) |
| `DebugLogDiagnostics.lua` | 2 | **3** | v1.75.0 (identity header names Glow and Sim) |
| `Options.lua` | 28 | **29** | v1.73.0 (drawer attach; structural refresh keeps the scroll offset) |
| `OptionsIdList.lua` | 4 | **5** | v1.75.0 (comment-only, #57) |
| `OptionsTabs.lua` | 8 | **9** | v1.75.0 (`O.__releaseChrome` removed, #45) |
| `OptionsDrawer.lua` | (new) | **1** | v1.73.0 (`O.Drawer`) |
| `Perf.lua` | 14 | **15** | v1.72.0 (`Perf.Note` top-level `false`) |
| `PerfPanel.lua` | 6 | **7** | v1.75.0 (comment-only; the step panel stays Sim-private, #53) |
| `Sim.lua` | (new) | **1** | v1.75.0 (new major `LibKa0s-Sim-1.0`, #54) |
| `SimTimeline.lua` | (new) | **1** | v1.75.0 |
| `SimPanel.lua` | (new) | **1** | v1.75.0 |

Unchanged: `Env` 2, `Compat` 1, `Lifecycle` 3, `Bus` 2, `Schema` 2, `Pool` 3, `WidgetsReorder` 1,
`WidgetsDragHandle` 4, `WidgetsLineChart` 3, `WidgetsAutocomplete` 2, `DebugLogGates` 1, `Slash` 20,
`SlashParse` 2, `Launcher` 5, `OptionsRegistry` 2, `OptionsWidgets` 34, `OptionsIds` 2,
`OptionsCombat` 1, `OptionsCompose` 7, `OptionsScroll` 4, `OptionsNav` 2, `PerfSampler` 1,
`PerfCommands` 1. Keys at the tag: Core 11, Item 3, Glow 1, Media 5.1, Widgets 13.1.4.3.2, DebugLog
20.3.1, Options 29.2.34.2.5.9.1.7.4.2.1, Perf 15.1.1.7, Sim 1.1.1. No `NEEDS_*` floor rises.
Seventeen majors across forty files (LibKa0s `CHANGELOG.md` v1.75.0, lines 13-34 at the tag). No
cross-major skew: every file was behind by whole releases, and the copy replaces all of them.

`W.StepPanel` / `WidgetsStepPanel.lua` is **not** in the tag (LK-11 outcome B): the step panel is
library-internal inside `SimPanel.lua`.

## 3d — Both diffs

Before the copy, `diff -rq <scratch>/LibKa0s libs/LibKa0s` named the thirteen moved files above, the
six new files, and 119 `Only in <scratch>/LibKa0s` lines under `media/icons` (the 111 new Open Iconic
marks and the `phosphor/` and `game-icons/` folders). `diff -rq <scratch>/testkit tests/_kit` named
`README.md`, `framework.lua`, `inventory.lua`, `mock_base.lua`, `mock_record.lua`,
`run-automated-tests.sh`, `vendor_sync.lua` and `Only in <scratch>/testkit: latch.lua`. Nothing was
only on the addon's side.

The copy is delete-then-copy of both folders. Before the prune, `diff -r --strip-trailing-cr
<scratch>/LibKa0s libs/LibKa0s`, `diff -r <scratch>/LibKa0s libs/LibKa0s` and `diff -r
<scratch>/testkit tests/_kit` printed nothing. After the prune the only difference is the `Only in
<scratch>/LibKa0s/media/icons` lines for the undeclared icons, which is the declaration working.

## 3e — Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep
-v '/tests/'`: the same fourteen majors as at v1.71.0 (`docs/module-map.md`, the module table):
Compat (`core/Compat.lua:9`, `core/Secrets.lua:38`), Media (`core/MediaSetup.lua:18`), Env
(`core/EnvSetup.lua:17`), Lifecycle (`core/LifecycleSetup.lua:168`), Core (`core/CoreSetup.lua:16`),
Launcher (`core/LauncherSetup.lua:44`), Bus (`core/Bus.lua:25`), DebugLog
(`core/DebugLogSetup.lua:13`), Perf (`core/PerfSetup.lua:14`), Pool (`core/PoolSetup.lua:15`),
Widgets (`modules/Anchors.lua:464`), Schema (`settings/Schema.lua:66`), Options
(`settings/OptionsSetup.lua:98`) and Slash (`settings/Slash.lua:26`). Unbound: Item (as before),
Glow and Sim (new).

Moved and consumed: **Core, Media, Widgets, DebugLog, Options, Perf**. Within those, AuraMaster calls
none of the new or changed members: no `SearchBox`, `TestStrip`, `Drawer`, `ICON_SETS`,
`IconAuthor` or `Perf.Note(..., false)` in `core/`, `modules/` or `settings/`. Core, DebugLog,
OptionsIdList and PerfPanel move on comments only.

## 3f — Kit revision, and the pairing rule

`grep -n 'Kit.VERSION =' <scratch>/testkit/framework.lua tests/_kit/framework.lua` -> **38 -> 41**.
Revision 39 (v1.72.0): `M.__fireUnconditional` reaches method-name and function handlers, and
`Kit.assertLatchHoldOrder` in the new `latch.lua`. Revision 40 (carried by 41): `vendor_sync.lua`
holds `media/icons/` to the `CLAUDE.md` `LibKa0s icons:` declaration and publishes the parser.
Revision 41: `Kit.__deviationRows` / `Kit.__declineFor` no longer exported (#45), a lizard crash is a
complexity `fail` with a `crashedFiles` bucket (#46, #47). The pairing rule (a consumer on v1.9.0 or
newer takes kit revision 11 or newer in the same commit) is satisfied by construction: both payloads
are copied whole, in one commit.

## 3g — Contract delta, and the blockers fixed in the copy commit

`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` finds no
site, so no host-supplied member's call site can have moved.

### Blockers

- **a. Options-stub parity (v1.73.0, `O.Drawer`).** `tests/test_surface_parity.lua:46`
  (`assertSurfaceParity(NS2.Helpers, "LibKa0s-Options-1.0", ...)`) goes red until the
  library-absent stub in `settings/OptionsSetup.lua` names `Drawer`. Added beside `IdList` under
  `-- renderers and widget makers` (`settings/OptionsSetup.lua:310`). The contract: Options
  `docs/api/Options/version-29.2.34.2.4.8.1.7.4.2.1-docs.md` (the CHANGELOG v1.73.0 "Surface-parity
  churn" bullet). `__releaseChrome` is **not** added: AuraMaster's stub never carried it
  (`grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` is empty),
  so LibKa0s#45's removal needs no deletion here.
- **e. A test that pinned the info art on disk without the declaration.**
  `tests/test_optionssetup.lua` `options: the info art the descriptor routes to is vendored on disk`
  is rewritten as `options: the info art the descriptor routes to is declared on the LibKa0s icons
  line and vendored on disk`: it parses `CLAUDE.md` with the kit's own
  `dofile("tests/_kit/vendor_sync.lua").iconDeclaration(doc)`, asserts mode `list` and that `info`
  is named, and keeps the `io.open` check on `libs/LibKa0s/media/icons/info.tga`. Red under `info`
  dropped from the line (checked: it fails with "`info` is declared on the LibKa0s icons line", and
  the kit's vendor gate fails on the shipped-but-undeclared `info.tga`).
- **f. A new test holding the declaration to the draws.** `tests/test_setups.lua`, Media block:
  `media: the LibKa0s icons line declares exactly the marks this addon and its library hosts draw`
  collects every literal `NS.Icon("<name>")` in `core/`, `modules/` and `settings/` (an `io.popen`
  grep, the pattern of the close-button scan above it), adds the library-drawn set this addon wires
  (close, copy, clear for the debug console; info for the IdList help mark), and asserts the set
  equals the parsed declaration's names. Red under a new `NS.Icon("x")` with `x` undeclared, or a
  stale extra name (checked with `info` dropped: "declared == drawn (expected clear, close, copy,
  help, info, got clear, close, copy, help)").

### Not blockers (verified)

- **b. Kit 39's `__fireUnconditional` reach.** `grep -rn 'fireUnconditional\|__kitEver' tests
  --include='*.lua' | grep -v '/_kit/'` -> 0 hits. No stand-down case of this addon fires
  unconditionally, so none can newly reach a handler.
- **c. Options 29's structural refresh keeps the scroll offset.** No page test pins a scroll reset
  (`grep -rln 'GetVerticalScroll\|SetVerticalScroll\|scrollOffset\|FixScroll' tests` outside `_kit`
  is empty). A behavior change on every page, nothing to change.
- **d. Whole-catalog icon tests (3j).** `grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests
  --include='*.lua' | grep -v '/_kit/'` finds only the `info.tga` check above (fixed as e). No suite
  iterates the catalog. `tests/test_anchors_handle.lua` (help), `tests/test_anchors_close.lua` and
  `tests/test_setups.lua` (close) name declared marks and stay as they are.
- **g. Stale kit-revision mentions.** None names kit 38 as current; historical mentions (for example
  `tests/test_bulklog.lua`, "Since kit revision 18") stay. `tests/test_vendor_sync.lua`'s header
  gains one sentence: since kit revision 40 `media/icons/` is held to the `LibKa0s icons:`
  declaration rather than to the whole tag.
- **Media 5.1.** `Media.Icon` still answers a path for any catalog name, and pruned names draw
  blank. The addon's two `NS.Icon` names are declared (3i).
- **Core 11 / DebugLog 20 / OptionsIdList 5 / PerfPanel 7.** Comment-only.
- **Perf 15.** `false` is a new value of an existing argument; AuraMaster passes no `false`.

## 3h — Tags vendored and never recorded

The listing (run before the copy) prints nothing: the only tag vendored since the store's horizon
without a single-tag bundle was already covered (`2026-10-07-v1.69.0-v1.70.0`), and v1.71.0 has its
bundle. No span bundle is written.

## 3i — The icon declaration

`grep -n 'LibKa0s icons:' CLAUDE.md` before the run: no line (the transition state, gated as a
whole-folder copy). Pre-decided by the run's item spec, so recorded here as decided, not re-asked:

`LibKa0s icons: clear, close, copy, help, info.`

written as the next line under the provenance line (`CLAUDE.md:37`). Every name is Open Iconic
(unprefixed); all five are in the tag's `LibKa0s/media/icons/`.

| Name | Drawn by | Evidence |
|---|---|---|
| `help` | the host seam `NS.Icon` | `core/MediaSetup.lua:30` (`NS.Icon`), called at `modules/Anchors.lua:667` (`helpIcon = NS.Icon("help")`, the container handle's ? mark via `KW.DragHandle`) |
| `close` | the host seam, and the library | `modules/Anchors.lua:668` (`closeIcon = NS.Icon("close")`, the handle's X); library-drawn by `Core.MakeCloseButton` for the DebugLog console (`core/DebugLogSetup.lua` passes `addonName`) and the perf panel (`core/PerfSetup.lua` passes `addonName`). `NS.MakeCloseButton` (`core/CoreSetup.lua`) has no host caller today and draws the same name |
| `copy`, `clear` | the library | the DebugLog console's title-bar buttons (`core/DebugLogSetup.lua`, the `addonName` field and its comment) |
| `info` | the library | `O.IdList`'s help mark (the Options descriptor's `addonName`, `settings/OptionsSetup.lua`); both IdList calls, `settings/Filters.lua:809` and `settings/GeneralSpells.lua:857`, pass no `helpIcon` (`grep -rn helpIcon settings` is empty) |

The library-drawn set is taken from the tag: `docs/releasing.md:312` ("Library-drawn icons are the
host's to declare") and CHANGELOG v1.75.0 *What a consumer owes*: close, copy, clear, info. No data
table or constant names a catalog icon (a grep of `core/ modules/ settings/ defaults/ locales/` for
`ICONS` or media icon paths finds only `core/MediaSetup.lua`'s comment). AuraMaster hosts no
`W.TestStrip`, `W.SearchBox`, Glow or Sim, so no host-passed name joins. Not `all`: no icon picker.

Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup
`tests/test_mediasetup.lua:19`). Here the new `tests/test_setups.lua` case holds the line to the
`NS.Icon` literals, and the owner's in-client smoke (SM-AM-2 to SM-AM-5) is the backstop for the
library-drawn half, which no headless gate can see.

## 3j — The prune

`lua <scratch>/tools/prune-icons.lua <AuraMaster>` (the tag's own tool, run after both `CLAUDE.md`
lines were written) ended `5 icon(s) declared; kept 6 file(s), removed 5834`:

| Set | Removed |
|---|---|
| Open Iconic (unprefixed) | 219 marks (224 at the tag, 5 kept) |
| Phosphor (`phosphor/`) | 1,434 marks + `LICENSE-phosphor.txt` |
| Game-icons (`game-icons/`) | 4,178 marks + `LICENSE-game-icons.txt` + `AUTHORS.txt` |

`libs/LibKa0s/media/icons/` now holds `clear.tga`, `close.tga`, `copy.tga`, `help.tga`, `info.tga`
and `LICENSE-open-iconic.txt`. `media/fonts/` and `media/textures/` are untouched. Against the
v1.71.0 copy (113 marks, 192,650 bytes) the folder drops 108 marks; against an unpruned v1.75.0 copy
(28 MB) it is about 28 MB smaller.

## Pre-existing, not changed here

Comment citations into the vendored payload in `settings/GeneralSpells.lua` and `settings/Filters.lua`
(for example `libs/LibKa0s/OptionsIdList.lua:666`, `:44`, `:849-851`, `libs/LibKa0s/Options.lua:45`)
had already drifted against v1.71.0 (`ID_ICON_SIZE` sat at line 47 there, not 44). v1.75.0 shifts
`OptionsIdList.lua` by 2 to 4 lines and `Options.lua` by 1 to 3. They are left for a sync-docs
comment-citation pass; this item changes no comment outside its own scope. `DEPENDENCIES.md`'s two
`tests/_kit/vendor_sync.lua` citations, which the docs gate checks, were moved to the kit 41 lines
(`:409`, `git -C … show`; `:644`, `git ls-files -s`).
