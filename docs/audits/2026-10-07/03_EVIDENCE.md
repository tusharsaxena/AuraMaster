# 03 — Evidence: Ka0s Aura Master (2026-10-07)

Every command below was run from the repo root at HEAD `bed2784` on 2026-10-07. Outputs are real and
trimmed only where marked. Before writing this file, every `file:line` cited in the bundle was re-read
and its text is quoted beside the citation.

**Census scope.** Unless an item says otherwise, a count starts from `git ls-files`.

- **The default authored-Lua scope** is `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'`. It includes `tests/` and `tools/` and excludes the two vendored payloads.
- **The "live tracked" scope** for doc sweeps excludes the frozen and record stores: `docs/audits`, `docs/reviews`, `docs/revendor`, `docs/superpowers`, `docs/automated-tests/2*`, `docs/perf-analysis/2*` and `docs/spell-research`. It also excludes `libs/` and `tests/_kit/`.

## E-1 — Lint

```
$ ~/.claude/dev-copilot/bin/ka0s-bounded luacheck .
...
Total: 0 warnings / 0 errors in 171 files      (exit 0)
```

The scope comes from `.luacheckrc`:

- `exclude_files = { "libs/", "tests/_kit/", "docs/audits/", "docs/reviews/", "docs/automated-tests/", "_dev/" }`. The test tree is linted.
- `files["tests/"] = { globals = { "AM_TEST" }, read_globals = { "arg" } }`.
- There is no blanket `ignore`. The one narrow ignore is `files["core/AuraMaster.lua"] = { ignore = { "212/self" } }`, with its reason written beside it.
- `grep -n 'GameTooltip\|C_Spell\|GetAddOnMetadata\|"GetSpellInfo"' .luacheckrc` prints nothing, which closes AM-28.

## E-2 — Headless suite

```
$ /usr/bin/time -v ~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua
  SKIP  diagnostics contract: an addon that opts out lands the report and leaves logging off — this addon keeps the default (Kit.diagnostics.enablesLogging is not false), so its report turns logging on; the case above holds it
2049 passed, 0 failed, 1 skipped, 2050 total (16 shards)
	User time (seconds): 34.39
	Elapsed (wall clock) time (h:mm:ss or m:ss): 0:15.99
	Exit status: 0
```

- `tests/run.lua:81` reads `jobs = "auto",`, which closes AM-27.
- `README.md:7` reads `![Tests](https://img.shields.io/badge/Tests-2049%2F2049_passing-green)`, which counts passes and excludes the one skip (testing-§5).

## E-6 — Vendored Ka0s-owned library (`diff -r` at the provenance tag)

```
$ grep -n 'Bundles \[LibKa0s\]' CLAUDE.md README.md
CLAUDE.md:36:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.70.0 (MIT).
$ git -C ../LibKa0s describe --tags --always        -> v1.70.0-5-g353f286   (HEAD NOT used)
$ git -C ../LibKa0s rev-list -n1 v1.70.0            -> 162a7fda6c46b7fdc6143eac1d219da4ec6ebda1
$ git -C ../LibKa0s archive v1.70.0 LibKa0s testkit | tar -x -C /tmp/claude-1000/am-lk170
$ diff -r /tmp/claude-1000/am-lk170/LibKa0s libs/LibKa0s ; echo exit=$?   -> exit=0
$ diff -r /tmp/claude-1000/am-lk170/testkit tests/_kit    ; echo exit=$?   -> exit=0
files: 159 (tag) / 159 (vendored)
$ grep -n 'VERSION *=' tests/_kit/framework.lua     -> 20:Kit.VERSION = 37
$ git ls-files -s tests/_kit/run-automated-tests.sh -> 100755 685cbcc… 0  tests/_kit/run-automated-tests.sh
$ grep -nE '^## (Libraries|Bundled libraries|Libraries and credits|Credits and libraries|Credits and bundled libraries)' README.md   -> (none)
$ grep -n 'WoW_Addon_Standard' README.md   -> 6:![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
```

`AuraMaster.toc:29` reads `libs\LibKa0s\LibKa0s.xml`, listed once, after Ace3.

## E-7 — Re-vendor bundles (AM-21)

These are the `AUDIT.md` step-4 commands, run verbatim with the `/tmp` paths renamed.

```
horizon=2026-09-12
vendored (43): v1.30.0 … v1.68.1 v1.69.0 v1.70.0
recorded (42): v1.30.0 … v1.44.0 v1.45.0 v1.46.1 … v1.68.1
UNRECORDED:
v1.69.0
v1.70.0
```

- `ls docs/revendor` holds 19 bundles. The newest is `2026-10-04-v1.68.1`, and `2026-09-24-v1.35.0-v1.54.2` covers the previous run's span.
- `git show --stat 3656914` reads "chore: re-vendor LibKa0s v1.69.0 (kit 37; adds the line chart widget)" (2026-10-06).
- `git show --stat c070393` reads "chore: re-vendor LibKa0s v1.70.0" (2026-10-07).
- v1.45.0 is recorded but not vendored here. That is not a finding.

## E-8 — Line endings

```
(a) test -f .gitattributes                         -> present
(b) .gitattributes:26:* text=auto eol=crlf
(c) .gitattributes:36:*.sh text eol=lf   /   :37:*.py text eol=lf
(d) grep -c ' binary' .gitattributes               -> 23
(e) <AUDIT.md one-liner, verbatim> | wc -l          -> 0
§5 body: diff <(head -n 84 .gitattributes | tr -d '\r') <client-bound canonical, 84 lines>  -> empty
§5 tail: tail -n +85 .gitattributes | tr -d '\r' | grep -m1 .                               -> nothing
```

`git ls-files --eol tests/page_helpers.lua` gives `i/lf w/crlf attr/text=auto eol=crlf`, which closes AM-30.

## E-9 — Packaging (AM-35, AM-40)

```
(a) NOT IGNORED — .claude
(b) UNACCOUNTED — .claude
    UNACCOUNTED — .git            (never needs a row)
(c) (nothing)
$ git ls-files .claude           -> .claude/commands/aura-spells-review.md
$ git log --diff-filter=A --format='%h %ad %s' --date=short -- .claude/commands/aura-spells-review.md
d093af8 2026-09-24 SID-9: Add the aura-spells-review command, docs and the end-to-end test
$ du -ch media/screenshots/* | tail -1    -> 26M total
```

- `.pkgmeta:12` reads `# - .claude        # ONLY in a repo that HAS a .claude/ — dev-only agent tooling, never loaded by`.
- `.pkgmeta:13` reads `#                    the client. Copied in when the directory appears, and left out until then.`
- `.superpowers` is ignored at `.pkgmeta:14`, and `.gitignore:16` ignores it in git too.

## E-10 — Complexity (AM-31)

```
$ ~/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle
AuraMaster 1.0.1 — automated tests — 20261007-155003
  complexity  pass  — 1 warnings (fun rate 0.00), 49655 NLOC / 5443 funcs, avg NLOC 8.3, avg CCN 2.3 (max 18), avg tokens 75.5 (recorded, non-gating)
  verdict: green
  record:  newest bundle 20260927-214918 measured b5208f3, 173 commit(s) behind HEAD — its figures describe a tree this one is no longer
```

`--no-bundle` prints the count but not the name. To name the warned function, the runner's own shadow
steps were replayed into a scratch directory, `/tmp/claude-1000/am-cxshadow`:

- the same `find`, piped to `lizard_sighted.lua shadow`;
- the same fixed `lizard -l lua -L 1500 -x "./libs/*" -x "./tests/_kit/*" .`, through `ka0s-bounded`;
- the same `lizard_sighted.lua parity`.

Nothing in the repo was written.

```
!!!! Warnings (cyclomatic_complexity > 15 or length > 1500 or nloc > 1000000 or parameter_count > 100) !!!!
      21     18    211      3      21 logCandidates@892-912@./modules/Anchors_Snap.lua
Total nloc 49655  Avg.NLOC 8.3  AvgCCN 2.3  Avg.token 75.5  Fun Cnt 5443  Warning cnt 1
parity: (no rows — 0 blind files)
```

- `modules/Anchors_Snap.lua:892` reads `local function logCandidates(dragged, when, what)`, and `:893` reads `if not (NS.State and NS.State.debug and NS.Debug) then return end`.
- `git log -3 -- modules/Anchors_Snap.lua` includes `cb766da 2026-10-03 DD-21: log what the snap sees at each drag's start and drop`.

`docs/automated-tests/RESULTS.md` shows the recorded side:

- The newest row is `20260927-214918 | b5208f3 | clean | 1.0.0 → 1.0.1 | … | 41031 | 4472 | … | 15 | 0 | green`.
- The band table lists 10 files, all with *Accepted* dispositions.
- `docs/automated-tests/20260927-214918/manifest.json` has no `"blindFiles"` key, so the run was unsighted.

## E-11 — Disabled-state registration census

The census runs over `git ls-files '*.lua' ':!libs' ':!tests' ':!tools'`. The load-list scope is
narrowed to shipped source because only the TOC's files can register at runtime.

| Registration | Undone by |
|---|---|
| `core/AuraMaster.lua:84` `NS.SafeRegisterEvent(self, e[1], e[2], NS.RejectedEvents)` (12 lifecycle events) | `:90` `self:UnregisterEvent(e[1])`, from `standDown` → `UnregisterLifecycleEvents` |
| `core/LifecycleSetup.lua:95` pending `PLAYER_REGEN_ENABLED` | `:74` `addon:UnregisterEvent(PENDING_EVENT)`. Sanctioned survivor, released when it fires |
| `modules/ContainerManager.lua:824-825` `SafeRegisterUnitEvent(f…)` / `(p…)` | `:902` `if CM.viewFrame then CM.viewFrame:UnregisterAllEvents() end`, plus `:903` for the player frame |
| `modules/ContainerManager.lua:866/879/882` bus messages | `:899` `ev:UnregisterAllMessages()` |
| `modules/EmptyWatch.lua:357-368` unit frames and four events | `:373-382` `UnregisterAllEvents` and `UnregisterEvent` by name |
| `modules/TimedSpells.lua:157` unit frame, `:186` three events, `:203-204` bus | `:146` `TS.unitFrame:UnregisterAllEvents()`, `:172` `events:UnregisterAllEvents()`, `:213` `bus:UnregisterAllMessages()` |
| `settings/OptionsSetup.lua:405` `ev:RegisterMessage(NS.MSG.CONTAINERS_CHANGED, …)` | **Not undone.** The panel's own refresh subscription, which open-evolutions records as open, so it is not filed |

Every timer is canceled on stand-down:

- `modules/ContainerManager.lua:339` and `:905` read `flushTimer:Cancel()`.
- `:530` reads `if enchantTimer then enchantTimer:Cancel() end`.
- `modules/EmptyWatch.lua:391-392` cancel `passTimer` and `expiryTimer`.
- `modules/FontPrimer.lua:310-311` cancel `holdTimer` and `refreshTimer`.
- `modules/TimedSpells.lua:175` reads `scanTimer:Cancel()`.

`git ls-files … | xargs grep -n 'C_Timer.After'` returns only `modules/FramePicker.lua:99` (Escape
handling inside a player-started pick) and `settings/OptionsSetup.lua:395` (the coalesced panel
refresh). Both are player-initiated.

The suite is `tests/run.lua:142` `"test_disabled",`, with 18 cases. One example is
`tests/test_disabled.lua:206` `test("disabled: every registration the addon owns is UNREGISTERED, not gated", …`.

## E-12 — Counts

```
$ git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | wc -l        -> 171   (110 under tests/, 3 under tools/)
  … | xargs wc -l | sort -n | awk '$1>=1000'                             -> 12 files 1016–1490; none >1500
      top: 1490 tests/test_anchors_drag.lua, 1406 core/Database.lua, 1344 defaults/Categories.lua,
           1311 tests/test_filtercompiler.lua, 1205 tests/test_style.lua, 1194 tests/test_database.lua,
           1184 tests/test_pages_filters.lua, 1126 modules/Anchors_Snap.lua, 1074 tests/test_containermanager.lua,
           1057 settings/Schema.lua, 1024 modules/Style.lua, 1023 tests/test_style_text.lua
$ for d in locales core defaults modules settings; do git ls-files "$d/*.lua" | wc -l; done -> 1 16 4 22 15 (58)
$ grep -cE '^(locales|core|defaults|modules|settings)\\' AuraMaster.toc -> 58
$ awk 'NR>=39 && NR<=95' settings/Slash.lua | grep -cE '^\s*\{"[a-z]+"'  -> 25
$ grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua    -> 26
$ git ls-files '*.lua' ':!libs' ':!tests' | xargs grep -n 'LibStub("LibKa0s-[A-Za-z]*-1.0"' | … | uniq -c
  Bus 1, Compat 2, Core 1, DebugLog 1, Env 1, Launcher 1, Lifecycle 1, Media 1, Options 1, Perf 1, Pool 1, Schema 1, Slash 1, Widgets 1   (14 majors)
$ git ls-files '*.py' '*.sh' | grep -vE '^(libs/|tests/_kit/)'          -> 18, all under tools/spell-research/
```

## E-13 — Close-button grep

```
$ grep -rn 'MakeCloseButton(' --include='*.lua' . | grep -v '/libs/' | grep -v '/tests/'
core/CoreSetup.lua:169:    return lib.MakeCloseButton(parent, onClick, addonName)
```

That is the one wrapper body; `core/CoreSetup.lua:168` reads `NS.MakeCloseButton = function(parent, onClick)`.
The stub twin is `:74`, `NS.MakeCloseButton = function() return nil end`. The other output lines
were vendored `libs/LibKa0s` definitions, which the second `grep -v` should drop and are not addon code.

## E-14 — Write paths, settings window, slash stub

- The direct-write grep `git ls-files '*.lua' ':!libs' ':!tests' ':!tools' | xargs grep -nE '(db\.(profile|global|char)|NS\.db\.(profile|global))[A-Za-z0-9_.\[\]"]*\s*=[^=]'` prints nothing.
- The drag-attach drop writes through the seam:
  - `settings/Layout.lua:215` reads `local ok = NS.SetByPath(ATTACH_SECTION, section, id)`.
  - `modules/Anchors_Snap.lua:1057` reads `NS.SetByPath("container.attach", section, container.id)`.
- The settings window is touched in two places, each behind a combat refusal:
  - `settings/Layout.lua:568` reads `if SettingsPanel and SettingsPanel.Close then pcall(SettingsPanel.Close, SettingsPanel, true) end`. It runs only after `FP.PickFor` returns true, and that function refuses in combat at `modules/FramePicker.lua:143` (`if InCombatLockdown() then`).
  - `settings/OptionsSetup.lua:382` reads `Settings.OpenToCategory(cat:GetID())`, behind `:368` `if InCombatLockdown() then`.
- **AM-38.** `settings/Slash.lua:423` reads `SlashLib = { FormatRow = function(cmd, desc) return cmd .. " — " .. desc end }`, and `:441` reads `out[#out + 1] = SlashLib.FormatRow("/am " .. e[1], e[2])`. The library's own row, at `libs/LibKa0s/Slash.lua:137`, is `return ("|cFFFFFF00%s|r \226\128\148 |cFFFFFFFF%s|r"):format(...)`, where `\226\128\148` is the em dash. The rule is slash-commands-§1: "In particular it MUST NOT copy `FormatRow`. A degraded help row prints `cmd  desc` plainly, with no gold command and no em dash."
- **AM-39.**
  - `core/Database.lua:1377` reads `if NS.Debug then NS.Debug("Migrate", "v%s -> v%s", g.schemaVersion, step.to) end`.
  - `:1405` reads `if seeded > 0 and NS.Debug then NS.Debug("Migrate", "seeded %s starter container(s)", seeded) end`.
  - The step lines are `:1252`, `:1260`, `:1274`, `:1290`, `:1298`, `:1306`, `:1314`, `:1322`, `:1330`, `:1338` and `:1346`, each `NS.Debug("Migrate", "vN profile '%s': …")`.
  - The only caller is `core/Database.lua:292`, `NS.RunMigrations()`, inside `InitDB`, which `core/AuraMaster.lua:27` (`NS:InitDB()`) calls from `addon:OnInitialize`.
  - The flag starts off: `core/State.lua:19` reads `State.debug = false`.
  - `git ls-files '*.lua' ':!libs' ':!tests' | xargs grep -n 'DebugAtEnable'` finds only the stub (`core/DebugLogSetup.lua:60`) and the Launcher forwarder (`core/LauncherSetup.lua:142`).

## E-15 — Docs: citations, hub shape, drift (AM-25, AM-37)

**Citation re-read.** Every `` `path:line` `` in `docs/ARCHITECTURE.md` (24 distinct) and
`DEPENDENCIES.md` (19 distinct) resolves to the claimed text. Some samples:

- `core/AuraMaster.lua:59` reads `{ "PLAYER_ENTERING_WORLD", "OnEnterWorld" },`.
- `settings/Schema.lua:603` reads `NS.bus:SendMessage(NS.MSG.CONFIG_CHANGED,`.
- `settings/OptionsSetup.lua:405` reads `ev:RegisterMessage(NS.MSG.CONTAINERS_CHANGED, …`.
- `modules/ContainerManager.lua:931` reads `print_(L["This client has no aura container API …"])`.
- `core/Constants.lua:32` reads `C.LOGO_ICON_PATH = …auramaster.logo.128.tga`.

AM-07 and AM-08 are closed.

**Hub shape.** `awk` over the `## ` headings of `docs/ARCHITECTURE.md`:

```
   6-  43   38  ## Overview
  44- 137   94  ## Module Map
 138- 155   18  ## Settings Schema
 189- 209   21  ## Message Bus
 210- 264   55  ## Slash Commands
 278- 335   58  ## Event Subscriptions
 345- 357   13  ## Taint Notes
 358- 368   11  ## Known Limitations
 369- 417   49  ## Documentation map
 418- 426    9  ## Documented deviations
wc -l docs/ARCHITECTURE.md -> 426
```

`:136` reads "Every non-vendored file, its responsibility and the full load order: `docs/module-map.md`."
That is the link. `:73-134` is the drag/snap narrative.

**Stale launcher claims (AM-37).** Found by grepping the live tracked scope for "left[- ]click":

- `docs/ARCHITECTURE.md:217-218`: "…shared with the Master controls *Test mode* checkbox and the minimap / button's left click."
- `docs/ARCHITECTURE.md:268` contradicts it: "Left click opens the settings / panel; right click opens the library's context menu with three entries, *Enabled*, *Locked* and *Test mode*".
- `docs/settings-panel.md:148-149`: "`Preview.SetTestMode`, the one writer `/am test` and the minimap button's / left click also use".
- `modules/Preview.lua:27`: "--- checkbox, `/am test` and the launcher's left-click all come through here."
- `settings/General.lua:31-32`: "-- NS.State.testMode through modules/Preview.lua's Preview.SetTestMode, the one writer `/am test` and / -- the launcher's left-click also use."
- `settings/General.lua:117`: "-- same refusal `/am test` and the launcher's left click answer: the dispatcher's one line,"
- What the code actually does: `core/LauncherSetup.lua:109` reads `openSettings = function() NS.OpenOptionsPanel() end,`, and `:133` reads `toggleTestMode = function() NS.Slash.ToggleTestMode() end,`.
- `docs/ARCHITECTURE.md:384` reads "| `settings-panel.md` | The `Tab \| Covers` table, …". The doc's own table, at `docs/settings-panel.md:12`, is `| Page | Tabs | Covers |`.
- `tests/test_render_coverage.lua:24-25` reads "lizard reads a `#` as a comment / --- (tests/test_lintconfig.lua)." But `tests/test_lintconfig.lua:205` reads "-- The length-operator scanner that once lived here is retired: the vendored kit's".

## E-16 — Standard-citation sweep

The sweep covers the live tracked `.lua`, `.md` and `.toc` files, 197 in all.

```
$ … | xargs grep -ohE '\b[a-z-]+-§[0-9]+' | sort | uniq -c       -> 81 distinct citations
  each checked against grep -cE '^### [0-9]+\.' <fetched section file>   -> 0 out of range, 0 unknown files
$ … | xargs grep -nE '(^|[^a-z-])§[0-9]+\.[0-9]+' | wc -l          -> 0
```

## E-17 — Register, issue store, prior closures

**The register.**

- `docs/ARCHITECTURE.md:420-422` holds one row: `options-ui-§17`, decided `2026-09-12`.
- The cited clause still exists: `options-ui.md:428` reads "**One resolver.**".
- The trigger's guard is still in place: `modules/ContainerManager.lua:116` reads `local defer = CM.MustDefer()`.
- The evidence id resolves: `docs/audits/2026-09-11/02_DEVIATIONS.md:76` reads `### AM-03 — \`options-ui-§17\``.

**The issue store** (`gh issue list --state all --limit 200 --json number,title,state,labels`):

```
25 OPEN   enhancement,state:untriaged,severity:medium  Presets…
24 CLOSED bug,state:done,severity:high                 Bar names are blank…
22 CLOSED enhancement,state:untriaged,severity:low     Drag-and-drop container attachment …   <- AM-36
21 CLOSED …state:done…   20 CLOSED …state:will-not-do…   19–15 CLOSED …state:done…
10 CLOSED enhancement,state:done,severity:medium       Let players create their own spell categories…
 8 CLOSED state:will-not-do   5 CLOSED state:will-not-do   1/7/9/12/13/14 OPEN triaged/untriaged
```

**Prior closures.**

| ID | Evidence |
|---|---|
| AM-13 | `core/DebugLogSetup.lua:41` `NS.L["%s, so the debug console window is unavailable."]:format(NS.LIBKA0S_MISSING)`; likewise `core/LauncherSetup.lua:52`, `core/PerfSetup.lua:24`, `core/CoreSetup.lua:84` |
| AM-20 | `README.md:23-40`: four captioned screenshots; the register row is gone |
| AM-22 | `settings/OptionsSetup.lua` stub: `local function noRows() return {} end` / `Helpers.ColorPair = noRows` … |
| AM-23 | `core/AuraMaster.lua:84` `NS.SafeRegisterEvent(self, e[1], e[2], NS.RejectedEvents)`; `core/CoreSetup.lua:142-144` |
| AM-24 | E-11's timer list |
| AM-26 | `docs/ARCHITECTURE.md:416` `| \`spell-research/\` | Frozen per-build derivation bundles … |` |
| AM-27 | `tests/run.lua:81` `jobs = "auto",` |
| AM-28 | E-1 |
| AM-29 | `settings/Slash.lua:211-214` `echo(path, prose)` → `cli:CliGet(path)` |
| AM-30 | E-8 |
| AM-32 | `docs/ARCHITECTURE.md:418-422`: one row only |
| AM-33 | `docs/ARCHITECTURE.md:151` "`global.minimap.minimapPos` (owner `core/LauncherSetup.lua`; writer LibDBIcon-1.0)" |
| AM-34 | `DEPENDENCIES.md:14` Release / assets row naming Python and Pillow, "Not needed to build, run or test." |

## E-18 — Logo

```
$ od -A d -t u1 -N 18 media/logos/auramaster.logo.128.tga
0000000   0   0   2   0   0   0   0   0   0   0   0   0 128   0 128   0
0000016  32   8
```

Byte 2 is **2** (uncompressed), the width and height are **128 × 128**, and the depth is **32**.
`AuraMaster.toc:6` reads `## IconTexture: Interface\AddOns\AuraMaster\media\logos\auramaster.logo.128.tga`.
