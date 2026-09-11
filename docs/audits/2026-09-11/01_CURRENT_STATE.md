# 01 — Current state: Ka0s Aura Master

- **Run date:** 2026-09-11 (first audit of this repo, so there is no prior bundle and no prior IDs to carry)
- **Deviation-ID prefix assigned:** `AM-` (Aura Master)
- **Audited commit:** `83c559e Scaffold Ka0s Aura Master v0.1.0` (branch `master`, working tree clean)
- **Addon version:** 0.1.0 (`AuraMaster.toc:5`)
- **Standard audited against:** Ka0s WoW Addon Standard **v2.42.0 (2026-09-10)**. This is the heading of
  `standards/STANDARDS.md`, fetched verbatim with `curl -fsSL` from
  `https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master` together with `AUDIT.md`
  and all 26 section files the Sections list links. None failed to resolve.
- **Rule set used:** the **addon** rule set. The repo carries `AuraMaster.toc`, so `AUDIT.md` step 1's
  library-repo switch (library-stack-§7's applicability lists) does not apply.
- **Read-only:** this bundle is the only write the run made.

Evidence for each claim is in `03_EVIDENCE.md` (the E-numbers); the deviations are in
`02_DEVIATIONS.md`.

---

## 1. Layout (`layout`)

- Source lives only under `core/` (14 files), `defaults/` (2), `locales/` (1), `modules/` (11) and
  `settings/` (11). There are no loose `.lua` files at the root.
- Folder load order is libs → locales → core → defaults → modules → settings (`AuraMaster.toc:15-98`).
- The largest authored `.lua` file is `locales/enUS.lua` at 447 lines. Nothing is in the 1000–1500
  band or over the cap (E-11).
- `media/` holds only `media/logos/` (the `.tga` plus its `.png`/`.jpg` sources). There is no private
  copy of shared art (E-14).
- `_dev/PLAN.md` is untracked (it is in `.gitignore:18`) and ignored by `.pkgmeta:16`.

## 2. TOC (`toc-file`)

- The fields are in canonical order: Interface `120100`, Title `Ka0s Aura Master`, Notes, Author,
  Version, IconTexture, SavedVariables (`AuraMasterDB, AuraMasterPerfDB`), OptionalDeps, DefaultState,
  Category-enUS, X-License MIT, X-Standard (`AuraMaster.toc:1-12`).
- `X-Curse-Project-ID` is omitted, and in its position the TOC has the comment
  `# X-Curse-Project-ID: not published on CurseForge yet (toc-file-§1: omitted, never a placeholder id)`
  (`AuraMaster.toc:13`). That is **compliant** per toc-file-§1, so nothing is filed.
- Section headers run Libraries → Locales → Core → Defaults → Modules → Settings, and the file ends in
  one CRLF (E-12).
- `libs\LibKa0s\LibKa0s.xml` is listed exactly once, after Ace3 (`AuraMaster.toc:27`).
- **Load-bearing positions** were checked by reading the seam files and `core/Constants.lua`:
  - Namespace (`:36`), MediaSetup→Constants (`:40-43`), CoreSetup (`:48`), Bus (`:51`), PerfSetup
    (`:55`), DebugLogSetup (`:58`), AuraMaster (`:61`), Categories→Profile (`:66-69`),
    Style→Style_Bars/Style_Icons (`:74`), Schema (`:86`) and OptionsSetup (`:89`) are annotated. Each
    comment names what resolves, so the MUST is met.
  - Conventional positions are marked for Compat, State, EnvSetup and PoolSetup only. `core\Secrets.lua`
    (`:57`), `core\Database.lua` (`:63`), the rest of the Modules group and the Settings pages carry no
    mark. That is the per-group SHOULD, filed as AM-15.

## 3. Libraries (`library-stack`)

- Vendored under `libs/` and all reachable: LibStub, CallbackHandler-1.0, AceAddon/Event/Timer/Console/
  DB/GUI/Config/DBOptions-3.0, LibSharedMedia-3.0, AceGUI-3.0-SharedMediaWidgets and LibKa0s.
- `.pkgmeta` has no `externals:` block (`.pkgmeta:1-24`).
- **LibKa0s v1.29.0**, per the provenance line at `CLAUDE.md:35`. Against the sibling
  `../LibKa0s` checked out at tag `v1.29.0`, `diff -r` is **empty** for both the ship payload and
  `tests/_kit/` (E-6). The payload is the whole folder: fourteen `.lua` files plus `media/`.
- **Wired modules and their setup files** (the descriptor and the stub are what this audit read; the
  library itself is not re-audited):

  | Major | Setup file | Lookup | Stub coverage |
  |---|---|---|---|
  | `LibKa0s-Media-1.0` | `core/MediaSetup.lua` | `:18` `LibStub and LibStub("LibKa0s-Media-1.0", true)` | `NS.Icon` / `NS.MediaFont` answer `nil` (`:23-34`); `RegisterLSM(addonName)` is called once, at file load (`:39`) |
  | `LibKa0s-Env-1.0` | `core/EnvSetup.lua` | `:16` | falls back to the C_AddOns → global → nil ladder (`:22-39`). This is where AM-10 is |
  | `LibKa0s-Core-1.0` | `core/CoreSetup.lua` | `:16` | the stub answers `IsConcatSafe`, `SafeToString`, `ResolveColor`, `SKIN`, `ApplySkin`, `MakeCloseButton` and `Print` (`:18-71`) |
  | `LibKa0s-Pool-1.0` | `core/PoolSetup.lua` | `:14` | a local `New`/`Acquire`/`ReleaseAll`/`Counts` (`:16-42`) |
  | `LibKa0s-Perf-1.0` | `core/PerfSetup.lua` | `:13` | `on`, `suspended`, `Note` and `OnCommand` (`:18-26`) |
  | `LibKa0s-DebugLog-1.0` | `core/DebugLogSetup.lua` | `:13` | every member the addon calls, `ConsoleCheckbox` included (`:29-63`) |
  | `LibKa0s-Slash-1.0` | `settings/Slash.lua` | `:22` | `Cli*`, `PrintHelp`, `LandingRows`, `OnSlash` and `SetRowAnnotator`. Host verbs keep working (`:239-274`) |
  | `LibKa0s-Options-1.0` | `settings/OptionsSetup.lua` | `:28` | **load-completing** (hollow composers, `LSMValues`, a real `RestoreAllDefaults`). This is the one documented exception (options-ui-§1) and is correct as written (`:82-181`) |

  Stub parity is pinned by four cases in `tests/test_surface_parity.lua`, all green (E-2).
- No hand-rolled console, widget makers, dispatcher or test framework exists in the addon's own
  source. The one AceGUI re-registration goes through the library: `lib.__PatchLSM30Border()`
  (`settings/OptionsSetup.lua:189`, library-stack-§9 / anti-pattern #76). **Compliant.**

## 4. Patterns (`architecture`, `savedvariables`, `compat`)

- **Namespace:** `NS` is private and there is no `_G[addonName]` (`core/Namespace.lua:3-6`). The addon
  exposes no public API, so `public-api` does not apply.
- **AceAddon:** `NewAddon(NS, addonName, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")`
  (`core/AuraMaster.lua:17`), and `NS.Print` is reclaimed from `NS.Util.print` at `:22`.
- **Bus:** three messages, each named `Ka0s_AuraMaster_*` (`core/Bus.lua:30-41`). Every receiver uses
  its own `NS.NewBusTarget()` (`settings/OptionsSetup.lua:236`, `modules/ContainerManager.lua:299`,
  `modules/TimedSpells.lua:106`). There are several peer direct calls, filed as AM-17.
- **Schema as the single source:** 192 rows. `NS.SetByPath` is the single write seam
  (`settings/Schema.lua:271`), defaults are stamped from `defaults/Profile.lua` (`:145-155`), and
  `NS.ValidateSchema` (`:347`) is run through the options descriptor's `validate`.
- **SavedVariables:** AceDB `AuraMasterDB` (`core/Database.lua:172`); `schemaVersion` defaults to 1 in
  `global` (`defaults/Profile.lua:52`). The runner is `SCHEMA_STEPS` (`core/Database.lua:196`), empty
  as expected at v1. Backfill tests with `== nil` (`core/Database.lua:31`). The render path re-types
  some defaults, filed as AM-12.
- **Compat:** `core/Compat.lua` publishes 17 shims (E-17). The degraded `EnvSetup` branch calls the
  deprecated global directly, filed as AM-10.

## 5. Settings panel (`options-ui`)

- **Pages and tabs**, from the schema's `group` values in declaration order:
  - General: `Master controls`, `Display`
  - Containers: `General` plus the bespoke `Overview` tab
  - Filters: `What to show`, `Categories`, `Sorting` plus the bespoke `Spell lists` and
    `Always / never` tabs
  - Layout: `Position`, `Growth`, `Frame`, `Mouse`
  - Bars: `Size`, `Bar`, `Background & border`, `Name text`, `Time text`, `Stack text`, `Highlights`
  - Icons: `Size`, `Border`, `Cooldown`, `Time text`, `Stack text`, `Highlights`
  - Landing page and Profiles: exempt from the strip, as options-ui-§13 requires.

  Every per-container page renders a strip, including a one-tab strip on an empty registry
  (`settings/OptionsSetup.lua:389-405`).
- **Master controls** is composed (`settings/General.lua:25-33`) with the full canonical set, since
  containers are movable (`modules/Container.lua:41`). `visibility` has been a four-value string since
  v0.1.0, so no stored boolean was ever shipped and no migration is owed.
- **Chrome band:**
  - Per-container pages use the library `PageBanner` picker (`settings/OptionsSetup.lua:270-286`).
  - Containers puts the picker and `New container` on one row (`settings/Containers.lua:210-219`),
    with every other act on the first tab, named `General`. That is the v2.40.0 escape, and all
    three conditions hold.
  - There is no second box around the band.
- **Composers:** font, border and bar groups are composed (`settings/Bars.lua:49-59,83-85,92-94`,
  `settings/Icons.lua:35-41,58-60`). The Bars `Background` subgroup is the exception, filed as AM-05.
- **Class color:** every composed color row carries its companion, and the rows stamp
  `classColorSource` from `classColor = { source = "player" }`. Choosing `player` for unit-scoped
  containers is filed as AM-03.
- **Palette exemptions:** the `dispelColors`, `expiringColor` and `pandemicColor` swatches claim the
  palette exemption (`settings/Bars.lua:129,139`, `settings/Icons.lua:92`). Each identifies a state
  or a dispel type, not a player, so this audit reads them as inside the exemption and files nothing.
- There is no `disabledIf` on a color row, and no reorder arrows or ordering control.
- **Global reset:** `db:ResetProfile()` through `resetProfile` (`settings/OptionsSetup.lua:48-51`).
  The veto is shared with the stub (`:23-26`), the popup text is verbatim (`settings/General.lua:92`)
  with Yes/No, `timeout 0`, `whileDead` and `hideOnEscape`, and the blast-radius case exists
  (`tests/test_optionssetup.lua:106-128`).
- **Combat:** the library gates the panel open. `NS.OpenOptionsPage` refuses too
  (`settings/OptionsSetup.lua:207-211`), but not with the canonical wording (AM-19).
- **Wrapped strip:** the vendored library measures the pitch once, from the inactive art
  (`libs/LibKa0s/OptionsWidgets.lua:411-452`). The suite has no invariant case, filed as AM-06.

## 6. Slash (`slash-commands`)

- `/am` plus the `/auramaster` alias, registered through AceConsole (`settings/Slash.lua:327-330`),
  with an ordered `NS.COMMANDS` of 20 positional triples (`:29-70`) and `options` aliased to `config`
  (`:284`).
- The reserved verbs are all present. `NS.PREFIX = "|cFF00FFFF[AM]|r"` (`core/Namespace.lua:16`).
- The descriptor routes `set` and `applyDefault` through the write seam (`settings/Slash.lua:291-297`).

## 7. Debug (`debug-logging`)

- `lib:New` gets `name`, `addonName`, `title`, `font = NS.Constants.FONT_MONO`, `slash`, the flag
  callbacks, call-time `print` and `safeToString` forwarders, `initSummary` and `onVisibilityChanged`
  (`core/DebugLogSetup.lua:68-104`).
- `NS.Debug` is bound bare (`:107`). The flag is session-only (`core/State.lua:17`).
- Every write is logged once, at the seam (`settings/Schema.lua:252`).
- Tracing of the no-op and deferral decisions is thin, filed as AM-16.

## 8. Performance (`performance`)

- The harness is wired (`core/PerfSetup.lua:29-105`) with five buckets, `applyContainer` declared
  `within` `applyPass` and observed at the call site (`modules/Container.lua:273`).
- Brackets are Shape A with upvalue gates (`core/AuraMaster.lua:81,84`, `modules/Container.lua:247`,
  `modules/ContainerManager.lua:129,141`, `modules/Style.lua:128`).
- There is no `decorate` hook (`core/PerfSetup.lua:103-104`).
- `perf` is registered by the addon (`settings/Slash.lua:66-67`).
- The offline runner's zero-overhead scenario is at `tests/perf.lua:133-139`.
- Suspend: the show ladder refuses at step 0 (`modules/Container.lua:295`), but suspend neither
  cancels nor gates the queued apply, filed as AM-11.
- `docs/perf-analysis/README.md` has every mandated section, and its capture index is empty.
- The performance-§12 exemption does not apply: the harness is wired.

## 9. Tests, lint, automated record (`testing`, `lint`, `automated-tests`)

- `lua tests/run.lua` gives **154 passed, 0 failed, 0 skipped** (E-2). `luacheck .` gives
  **0 warnings / 0 errors in 62 files** (E-1).
- `.luacheckrc`:
  - excludes `libs/`, `tests/_kit/`, `docs/audits|reviews|automated-tests/` and `_dev/`
    (`.luacheckrc:9`), with `tests/` itself in scope;
  - declares the harness global in a `files["tests/"]` stanza (`:37-40`);
  - has no top-level `ignore`, and one narrowed `212/self` for `core/AuraMaster.lua` (`:31-33`).
- The kit is **revision 15** (`tests/_kit/framework.lua:20`), so `test_eol.lua` is present. The load
  lists derive from the TOC and the XML (`tests/run.lua:21,24`), and the suite inventory is asserted
  both ways because `dir` is explicit (`tests/run.lua:50-73`, `tests/_kit/framework.lua:886`).
- The runner is recorded as `100755`. No gate asserts that, filed as AM-18.
- `docs/automated-tests/{README.md,RESULTS.md}` exist, with one bundle (`20260911-141809`, today). The
  watch list is empty and there is no `docs/complexity.md`.
- The `lizard` measurement run today matches the bundle exactly (E-10).

## 10. Packaging and `.gitattributes`

- `.pkgmeta` ignores every named dev entry and accounts for every root dot-entry. `.git` is the only
  unaccounted one, and it is exempt (E-8).
- `.gitattributes` pin, verbatim: `* text=auto eol=crlf` (`.gitattributes:26`), plus `*.sh text eol=lf`
  (`:34`) and 20 `binary` lines.
- The first 81 lines diff empty against the canonical client-bound body, and nothing follows them.
  Zero tracked files disagree with the pin (E-7).

## 11. Root docs (`documentation-§1/§2/§7`)

- **README.md:**
  - H1, then four badges: WoW `Midnight_12.1.0` matching Interface 120100, License, the **bare**
    Standard badge (`README.md:5`), and Tests `154/154` matching the run.
  - Logo, description, Usage (prose, ending on one configuration line), `How the containers work`,
    FAQ, Troubleshooting, Issues, Version History, and a `## Credits` with external credit only
    (TinyBuffBars).
  - No library inventory and no provenance line (E-6).
  - No `## Screenshots`, filed as AM-20.
- **CLAUDE.md:** a stub with the title, the adherence line, `## Standards compliance (read first)`,
  the docs pointers, the green-gate line and the provenance line
  `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.29.0 (MIT).` (`CLAUDE.md:35`).
- **DEPENDENCIES.md:** runtime / development / release sections, WSL2 commands (pipx for lizard), and
  verification commands. Two citations are wrong, filed as AM-08.

## 12. `docs/` shape (`documentation-§3`)

- **Tier 1:** all six are present under their canonical names.
- **Tier 2:**
  - Present, each with its trigger satisfied: `perf-analysis/README.md` (harness wired),
    `slash-dispatch.md` (20 commands), `midnight-quirks.md` (12.1 workarounds), `compat-layer.md`
    (17 shims) and `profiles.md` (Profiles sub-page).
  - Correct *Not applicable* rows: `message-bus.md` (3 messages) and `debug.md` (only the default
    console).
- `## Documentation map` (`docs/ARCHITECTURE.md:210-253`) has four tables in order, with six rows in
  *Verification and record*. It covers every `.md` under `docs/` exactly once, with no dangling rows.
  This is also pinned by `tests/test_docs.lua`.
- No non-canonical filenames, no `file-index.md` / `conventions.md` / `complexity.md`, and no
  `docs/perf-runs/` or `docs/pending/`.
- **Hub shape:** 257 lines, and no mandated section exceeds about 60 lines.
- Many `file:line` citations across `docs/` have drifted, filed as AM-07.

## 13. Deviation register and issue store (`audit-review-history`)

- `## Documented deviations` reads **"None."** (`docs/ARCHITECTURE.md:255-257`). With no rows there
  are no triggers to evaluate and no evidence IDs to resolve.
- `gh issue list --state all` shows two open issues, both labeled `state:triaged` and `enhancement`:
  - #1 party units, `severity:medium`;
  - #2 Text style, `severity:low`.

  Both are feature deferrals, not rule declines, so neither owes a register row. No title carries a
  `[status]` prefix, and there is no `docs/pending/LEDGER.md` (E-5).
- **Reasoned decisions with no register row:**
  - the player-only class color, reasoned in `docs/ARCHITECTURE.md:205-206` and
    `docs/scope.md:81-82` (AM-03);
  - TimedSpells' unit-filtered raw event frame, reasoned at `modules/TimedSpells.lua:75-76` (AM-04).

  A reasoning trail with no register row is not ratified. Each is therefore filed against its rule,
  with "file the register row" as one of the two fix directions.

## 14. Shared art, close controls, taint

- The close-button grep returns only the wrapper definition at `core/CoreSetup.lua:94` (E-13).
- There are no standalone windows. No `SetAtlas` appears, and no control draws a word or glyph
  outside the settings panel, which is out of scope here.
- `modules/Style_Bars.lua:46` uses the Blizzard `UI-CastingBar-Spark` for the bar spark. The catalog
  has no spark, and this is a bar texture rather than a control mark.
- The monospace face comes from the payload (`core/Constants.lua:22`). **Compliant.**
- **Taint:**
  - Blizzard buff and debuff frames are reparented, never hidden, and replayed on
    `PLAYER_REGEN_ENABLED` (`modules/BlizzardFrames.lua:28-48`, `core/AuraMaster.lua:73`).
  - Structural applies wait on `CM.MustDefer` (`modules/ContainerManager.lua:86-88`).
  - Two paths bypass the combat discipline: AM-01 and AM-02.
