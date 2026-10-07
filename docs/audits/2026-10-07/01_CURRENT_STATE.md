# 01 — Current state: Ka0s Aura Master (2026-10-07)

## Run header

| | |
|---|---|
| Standard audited against | **Ka0s WoW Addon Standard v2.76.1 (2026-10-07)**, fetched with `curl -fsSL` from `raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`: `AUDIT.md`, `standards/STANDARDS.md`, `standards/ADDONS.md` and all 27 section files the Sections list links. Every fetch succeeded. |
| Repo kind | **Addon.** `dev-copilot-profile` reports `profile=wow`, `kind=addon` (`reason=toc:## Interface`). `standards/ADDONS.md:20` lists *Ka0s Aura Master* in the in-scope addon table with launcher menu entries **Enabled · Locked · Test mode**. The detector and the table agree, so the whole addon rule set applies. |
| Tree | `/mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster`, branch `feat/2026-10-07-review-audit-remediation`, HEAD `bed2784` (merge of `feat/2026-10-06-revendor-libka0s-v1.69.0`). The tracked tree was clean. One untracked folder, `docs/reviews/2026-10-07/`, belongs to a concurrent review run; this audit neither read nor touched it. |
| Deviation-ID prefix | **`AM-`**, reused from `docs/audits/2026-09-11/` and `docs/audits/2026-09-23/`. Recurring gaps keep their IDs. New IDs start at `AM-37`. |
| Bounded runner | `~/.claude/dev-copilot/bin/ka0s-bounded`. Every `luacheck`, `lua tests/run.lua` and complexity run went through it. |
| Prior bundle | `docs/audits/2026-09-23/` (standard v2.64.0): 19 roots and 20 entries in total. Its status this run is in *Prior deviations* below. |

## Layout (`layout`)

- The five source folders hold **58 authored Lua files**: 1 locale, 16 core, 4 defaults, 22 modules and 15 settings. `docs/ARCHITECTURE.md:46-48` gives the same figures, and the TOC lists the same 58 (E-12).
- The authored-Lua census uses `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'`. It finds **171 files**, of which 110 are under `tests/` and 3 under `tools/`. **No file is over the 1500-line cap.** Twelve files are in the 1000–1500 band. The largest is `tests/test_anchors_drag.lua` at 1490 lines, 10 lines under the cap (E-12).
- The census heading `### Files over the 1500-line cap` sits under `## Documented deviations` and reads "No authored file is over the cap" (`docs/ARCHITECTURE.md:424-426`). That matches the tree. The kit gate `{ name = "test_layout_cap", dir = "tests/_kit/" }` is wired (`tests/run.lua:177`) and green.
- Generators are `tools/spell-research/*.py`: 9 programs plus 9 `test_*.py`, all under `tools/`. No TOC line loads them, and `.pkgmeta` ignores `tools`.
- `media/` holds `logos/` and `screenshots/` and duplicates nothing in the shared payload. `media/screenshots/` is 26 MB and is not ignored by `.pkgmeta` (AM-40, Info).

## TOC (`toc-file`)

- The field order matches toc-file-§1. `## Interface: 120100` (`AuraMaster.toc:1`) matches the README badge `Midnight_12.1.0`.
- `## IconTexture` (`:6`) names `media\logos\auramaster.logo.128.tga`. The TGA header bytes read type **2**, width **128**, height **128** and depth **32**, so the file is the right artifact (E-18).
- `## X-Curse-Project-ID: 1698345` (`:13`) is a real project id.
- `# Libraries` lists `libs\LibKa0s\LibKa0s.xml` once, after Ace3 (`:29`).
- `test_loadorder` pins the load-bearing and conventional annotations: "every addon file in the TOC is covered by a LOAD-BEARING or Conventional note".

## Libraries (`library-stack`)

- Provenance: `CLAUDE.md:36`, `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.70.0 (MIT).` The line is not in `README.md`.
- `diff -r` against `../LibKa0s` at tag **`v1.70.0`** (commit `162a7fd`, extracted with `git archive`; the sibling's HEAD is `v1.70.0-5-g353f286` and was not used) is **empty for both payloads**. `LibKa0s/` against `libs/LibKa0s` has 159 files on each side, and `testkit/` against `tests/_kit` is also empty (E-6). The kit is revision **37** (`tests/_kit/framework.lua:20`).
- Fourteen LibKa0s majors are looked up by name, one setup site each: Bus, Compat (two sites), Core, DebugLog, Env, Launcher, Lifecycle, Media, Options, Perf, Pool, Schema, Slash and Widgets (E-12). `Item` arrives unwired. That agrees with `docs/ARCHITECTURE.md:40`, "fourteen modules bound by name".
- v1.70.0 is above every adoption floor this run checks: the v1.42.0 Lifecycle floor, v1.58.0 for the launcher clicks, v1.60.0 for diagnostics, v1.64.0 for the diagnostics enable, v1.65.0 for library debug lines and v1.67.0 for the Options `addonName`. Kit 37 is past revision 35, so the sighted complexity gate applies.

## Shared-subsystem wiring: descriptors and degradation stubs

| Module | Setup file | What was checked |
|---|---|---|
| Core | `core/CoreSetup.lua` | `:16` lookup. The stub (`:30-135`) carries a guarded stringifier, the printer, `ResolveColor`/`ClassColor`, an empty `SKIN`, a nil `MakeCloseButton` and the three one-rung `SafeRegister*` bodies. The live branch publishes `SafeRegisterEvent`/`UnitEvent`/`Events` (`:142-144`) and the one `MakeCloseButton` wrapper (`:168-170`). |
| DebugLog | `core/DebugLogSetup.lua` | `:13` lookup. The stub (`:51-106`) carries every member called, `RunDiagnostics` with the library-absent line, and the four gates. The descriptor passes `addonName`, `brandName = "Ka0s Aura Master"`, `diagnostics` and `onClear` (`:131-198`). |
| Launcher | `core/LauncherSetup.lua` | `label = "Ka0s Aura Master"` (`:102`), `openSettings` (`:109`), the three menu pairs (`:125-133`), `debug` and `debugAtEnable` (`:138-142`). There is no host `onTooltipShow`. |
| Lifecycle | `core/LifecycleSetup.lua` | One latch with the `disabled` and `perf` holds, built at `:199-207`. `debug` is passed. A host line (`traceEdge`) restates only the secure-half detail the library cannot know. |
| Perf | `core/PerfSetup.lua` | Seven buckets with one `within`, and `lifecycle = NS.lifecycle` (`:76`). There is no `decorate` hook. The stub answers `on`, `suspended`, `Note` and `OnCommand`. |
| Options | `settings/OptionsSetup.lua` | The descriptor passes `addonName = addonName` (v2.75.0 MUST) and `debug`. The stub's composers answer `{}` (`noRows`), which closes prior AM-22. |
| Slash | `settings/Slash.lua` | `NS.COMMANDS` has **25** verbs (`:39-95`, E-12). `liveVerbs` is built on `SlashLib.LIVE_VERBS` plus `containers`, `select`, `diagnostics` and `profile` (`:142-152`). `debug` is passed. The library-absent stub's help row copies `FormatRow`'s em-dash shape (`:423`, AM-38). |

The close-button grep returns the one wrapper (`core/CoreSetup.lua:169`) and nothing else outside `libs/` and `tests/` (E-13).

## Architecture (`architecture`), events (`events-frames-taint`)

- The closed bus has four messages. `docs/ARCHITECTURE.md:208` marks `message-bus.md` *Not applicable* against a four-message count.
- **Every event registration goes through the library's `SafeRegister*` family**, with `NS.RejectedEvents` as the caller-owned list. That list surfaces in the `[Init]` summary (`core/DebugLogSetup.lua:176-180`), which closes prior AM-23.
- Five private unit-filter frames are each held on their module and unregistered by hand:
  - `TS.unitFrame`;
  - `EW.unitFrames[1]` and `EW.unitFrames[2]`;
  - `CM.viewFrame` and `CM.viewPlayerFrame`.

  Each registers `UNIT_*` events only, through `SafeRegisterUnitEvent`. The two ContainerManager frames each filter **two** `UNIT_*` events (`UNIT_FACTION`, `UNIT_FLAGS`) for the same units. This run reads the carve-out as permitting that, because it says "filter `UNIT_*` events" (plural), and files nothing. The ambiguity is noted in `02_DEVIATIONS.md` *Checked and not filed*.
- The write-path grep for direct `db.profile` / `db.global` assignments outside the seam returns nothing (E-14). The drag-attach drop writes through `NS.AttachByDrop` → `NS.SetByPath` (`settings/Layout.lua:215`, `modules/Anchors_Snap.lua:1057`).

## Settings (`options-ui`)

- Pages: the landing page; General (Master controls · Display · Spell Categories · Dispel Colors); Containers, with a **nav rail** of General · Filters · Layout · the container's own style section (#6); and Profiles.
- Master controls is composed through `H.MasterControls` (`settings/General.lua:53-63`) and includes `minimapPath = NS.MINIMAP_PATH`. The minimap row's path is `global.minimap.shown` (launcher-§3, v2.65.0).
- The rail's selection lives on the page context (`ctx.activeSection`, `settings/OptionsSetup.lua:593-657`). It is session state, not a profile write.
- No `disabledIf` sits on a color row (`settings/Text.lua:437-440` is the palette swatch, left undimmed on purpose; `settings/Layout.lua:556` and `settings/Text.lua:420` skip `color` rows).
- Blizzard's settings window is touched twice:
  - the frame picker's close, behind `FP.PickFor`'s `InCombatLockdown()` refusal (`modules/FramePicker.lua:143-147`);
  - the page jump, behind `NS.OpenOptionsPage`'s refusal (`settings/OptionsSetup.lua:368-372`), with `cat:GetID()` (`:382`).

## Slash and the disabled state (`slash-commands-§2`, `§7`)

- `enable`/`disable`/`lock`/`unlock` write through `NS.SetByPath` and echo through `cli:CliGet(path)` in the `set` shape (`settings/Slash.lua:206-227`, `:319-323`). That closes prior AM-29.
- **The teardown** is the Lifecycle latch's `standDown`/`standUp` (`core/LifecycleSetup.lua:116-162`). There is no second teardown.
- **The registration census** (E-11) found every registration undone except two:
  - the settings panel's own refresh subscription, `settings/OptionsSetup.lua:405`. open-evolutions records this as open, so it is not filed;
  - the sanctioned pending `PLAYER_REGEN_ENABLED` (`core/LifecycleSetup.lua:95`).
- **Timers.** Every timer is now a `C_Timer.NewTimer` handle and is canceled on stand-down. That closes prior AM-24. The two remaining `C_Timer.After(0)` sites are player-initiated UI one-shots (`modules/FramePicker.lua:99`, `settings/OptionsSetup.lua:395`).
- **The suite.** `tests/test_disabled.lua` is in `tests/run.lua:142` and has 18 cases, including "every registration the addon owns is UNREGISTERED, not gated" and "a queued apply and a queued scan are canceled, not left armed".
- **Diagnostics.** There is one `diagnostics` row (`settings/Slash.lua:89`). `runDebug` tests `diagnostics` first (`:396`). There is no alias, and `diagnostics` is live while disabled. `docs/debug.md:10-25` states that the run turns logging on.

## Debug (`debug-logging`)

- `Slash`, `Options`, `Launcher` and `Lifecycle` all receive `debug`. The Launcher also receives `debugAtEnable`.
- The change gates are the console's: `DebugOnce` and `DebugChanged` are used by `modules/Anchors.lua`, `modules/FontPrimer.lua` and others. The host's own hold trace is re-armed from `onClear`.
- The schema migration ladder's `[Migrate]` lines are written through the gated sink at `OnInitialize`, while the session flag is `false`. They never land (AM-39).

## Tests, lint, complexity (`testing`, `lint`, `automated-tests`, `performance`)

- `luacheck .` gives **0 warnings / 0 errors in 171 files**. `exclude_files` narrows to `libs/`, `tests/_kit/` and the frozen and record stores. `AM_TEST` is declared in `files["tests/"]` (E-1).
- `lua tests/run.lua` gives **2049 passed, 0 failed, 1 skipped, 2050 total (16 shards)**. It took 15.99 s wall. `jobs = "auto"` is set (`tests/run.lua:81`), which closes prior AM-27. The one skip is the kit's diagnostics opt-out case, which does not apply to an addon that keeps the default. The README badge `2049/2049` therefore counts passes and leaves the skip out, as testing-§5 requires.
- **Complexity** (sighted, kit 37), measured with `bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`:
  - **49,655 NLOC / 5,443 functions, 1 warning, max CCN 18**. Parity flagged no blind files.
  - The warned function is `logCandidates` (`modules/Anchors_Snap.lua:892-912`), CCN 18.
  - The newest record, `20260927-214918` (`b5208f3`), is **173 commits behind HEAD**, predates the sighted kit, and its manifest carries no `blindFiles` (AM-31).
- `test_lizard_sighted`, `test_eol`, `test_prose`, `test_layout_cap`, `test_vendor_sync` and `test_surface_parity` are all wired (`tests/run.lua:172-179`).

## Packaging, line endings, root docs

- **`.gitattributes`.** The pin is `* text=auto eol=crlf` (`:26`), with `*.sh text eol=lf` and `*.py text eol=lf` (`:36-37`) and 23 `binary` marks. The first 84 lines diff **clean** against line-endings-§5's client-bound body, and there is no appendix. Check (e) prints **0** (E-8), which closes prior AM-30.
- **`.pkgmeta`** has no externals. It ignores the dotfiles, `docs`, `tests`, `tools`, `_dev`, `.superpowers` and the logo PNG/JPG. **`.claude/` exists and is tracked** (`.claude/commands/aura-spells-review.md`, added in `d093af8`), but its ignore line is commented out (`.pkgmeta:12-13`). Check (b) prints `UNACCOUNTED — .claude` (AM-35).
- **`README.md`** follows the canonical order.
  - The Standard badge is the bare image.
  - There is no logo, no library inventory and no numbered list.
  - `## Screenshots` carries four captioned images, which closes prior AM-20.
  - `## Reporting a bug` is verbatim, and Troubleshooting carries its row.
- **`CLAUDE.md`** is the compliant stub: H1, the adherence line, `## Standards compliance (read first)`, the docs pointers, the gate line and the provenance line.
- **`DEPENDENCIES.md`** puts Python and Pillow under *Release / assets* (`:14`), which closes prior AM-34. All 19 of its `file:line` citations resolve (E-15).

## `docs/`

- **Tier 1:** all six docs present.
- **Tier 2:**
  - `slash-dispatch.md`: present, for 25 commands.
  - `midnight-quirks.md`: present.
  - `compat-layer.md`: present, for **26** shims by the documentation-§3 grep.
  - `profiles.md`, `debug.md` and `perf-analysis/README.md`: present.
  - `message-bus.md`: *Not applicable*, for 4 messages.
- **Verification and record:** exactly six rows. **Tier 3:** `known-limitations.md`, and `spell-research/` registered as one store row.
- The out-of-scope directory list (`docs/ARCHITECTURE.md:371-375`) names only stores documentation-§3 lists. No orphans and no dangling rows.
- There are no non-canonical filenames and no retired docs (`file-index.md`, `conventions.md`, `complexity.md` or `docs/perf-runs/`). There is no `docs/pending/`, `TODO.md` or `CHANGELOG.md`.
- **The hub is 426 lines.** *Module Map* spans 94 lines (`:44-137`), past the ~60-line spill rule (AM-25). Every other mandated section is at or under 58 lines.
- All 24 `file:line` citations in the hub resolve to the claimed content (E-15), which closes prior AM-07. Six live sites still describe the launcher's left-click as switching test mode, and the Documentation map's `settings-panel.md` row names a `Tab | Covers` table (AM-37).
- `docs/perf-analysis/` holds three frozen bundles, each with `report.md`, `dump.json` and `ANALYSIS.md`, indexed in its README.
- Standard citations: 81 distinct `filename-§N` references across 197 live tracked files all resolve in range, and the retired `§N.M` sweep returns **0** (E-16).

## Register and issue store

- `## Documented deviations` holds **one** row, `options-ui-§17` (decided 2026-09-12). Its cited clause, "One resolver", still exists (`options-ui.md:428`). Its evidence id, `docs/audits/2026-09-11` AM-03, resolves. Neither of its triggers has fired. The four unratified `layout-§1` rows that prior AM-32 filed are gone.
- `gh issue list --state all` returns 25 issues. Every one carries a `state:` and a `severity:` label, and none has a `[status]` prefix. The `state:will-not-do` issues are #5 and #8 (features declined) and #20 (the Bus stand-down record, which v2.64.0 permits). None of them owes a register row. **#22 is closed but labelled `state:untriaged`** (AM-36).

## Prior deviations (2026-09-23), status this run

| ID | Status |
|---|---|
| AM-07, AM-08 | **Closed.** All hub and `DEPENDENCIES.md` citations resolve. New drift of a different kind is AM-37. |
| AM-13, AM-20, AM-22, AM-23, AM-24, AM-26, AM-27, AM-28, AM-29, AM-30, AM-32, AM-33, AM-34 | **Closed** (evidence in E-17) |
| AM-21 | **Recurs**, narrower: v1.69.0 and v1.70.0 are unrecorded |
| AM-25 | **Recurs**, narrower: *Module Map* is 94 lines and the hub is 426 |
| AM-31 | **Recurs**: the record is 173 commits stale and unsighted, and one function is over CCN 15 |
| AM-35 | **Recurs, inverted**: `.claude/` now exists and is not ignored |
| AM-36 | **Recurs**: #22 is closed but still labelled `state:untriaged` |
| AM-03 | **Recorded** (register row, 2026-09-12) |
