# 03 — Evidence: Ka0s Aura Master (2026-09-23)

## How this evidence was gathered

**Location.** Every command ran from the repo root, `/mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster`,
at HEAD `8046dfb`.

**Bounded runs.** Tool runs went through `~/.claude/wow-addon/bin/ka0s-bounded`, called by absolute path
because it is not on `PATH`.

**Census scope.** Unless an item says otherwise, every census starts from `git ls-files` and leaves out
`libs/` and `tests/_kit/`, which is `layout-§1`'s denominator. Each item states its scope.

**Quoted lines.** Every `file:line` below was re-read while this bundle was written, and the text it
quotes is what sits on that line.

---

## E-1 — Lint

```
$ ~/.claude/wow-addon/bin/ka0s-bounded luacheck .
…
Total: 0 warnings / 0 errors in 110 files          (exit 0)
```

**Scope.** The run covers 110 files. That equals the authored-Lua census (E-12), because `.luacheckrc:9`
excludes only `libs/`, `tests/_kit/`, `docs/audits/`, `docs/reviews/`, `docs/automated-tests/` and `_dev/`,
none of which holds authored Lua. The test tree is in scope, and `AM_TEST` is declared in `files["tests/"]`
(`.luacheckrc:41-44`).

**The dead-entry probe (AM-28).** A copy of `.luacheckrc` was written to the scratch area with the four
unused entries removed. Nothing in the repo was changed. The result is unchanged at 0/0:

```
$ sed -e 's/"GameTooltip", //; s/"C_Spell", //; s/"GetAddOnMetadata", //; s/"GetSpellInfo",//' .luacheckrc > <scratch>/lc_probe.lua
$ ~/.claude/wow-addon/bin/ka0s-bounded luacheck --config <scratch>/lc_probe.lua .
Total: 0 warnings / 0 errors in 110 files
```

**Reference count for each `read_globals` name** over `core/ modules/ settings/ defaults/ locales/`, with
comment lines and member accesses (`.X`, `:X`) dropped. Every name was counted; only the zeros are shown:

```
GameTooltip 0
C_Spell 0
GetAddOnMetadata 0
GetSpellInfo 0
```

`.luacheckrc:11-12` says: "Each entry is a name some file under core/, modules/ or settings/ actually
references; a name nothing reads comes off the list."

## E-2 — Headless suite

```
$ time ~/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua
…
  PASS  eol: every tracked file carries the terminator .gitattributes declares for it
  PASS  eol: .gitattributes is line-endings-5's canonical body for this repo kind
  PASS  layoutcap: every authored file over the 1500-line cap is named in the census
…
1296 passed, 0 failed, 0 skipped, 1296 total                  (exit 0)
36.42s user 13.12s system 28% cpu 2:54.16 total
```

- `docs/test-cases.md` ends `| **Total** | **1296** |`.
- The README badge reads `Tests-1296%2F1296_passing` (`README.md:7`).
- `tests/run.lua:57-115` calls `Kit.run{ dir = "tests/", suites = { … } }` and sets no `jobs` field
  (AM-27).
- The kit suites are declared by (name, directory) pairs: `tests/run.lua:108` for `test_prose`, `:112`
  for `test_eol` and `:113` for `test_layout_cap`.

## E-3 — Register read and issue store

**The register** is `docs/ARCHITECTURE.md:821-841`. It holds six rows, followed by the census.

| Line | Rule | Decided | Status this run |
|---|---|---|---|
| `:825` | `options-ui-§17` | 2026-09-12 | Its evidence `docs/audits/2026-09-11 AM-03` resolves. Neither trigger has fired. **Accepted (AM-03).** |
| `:826` | `documentation-§1` | 2026-09-12 | Its Why cell reads: "the TOC now carries `X-Curse-Project-ID: 1698345` (AuraMaster.toc:13), so the 'first publish' half of the re-check trigger has fired and item 5 has become a MUST". The trigger has **fired**. "Item 5" is now item 4 (v2.45.0 renumbering). Issue #3 resolves (OPEN, `state:triaged`). **Not accepted → AM-20.** |
| `:827-830` | `layout-§1` ×4 | 2026-09-23 | Each Why cell ends "this row itself awaits the owner's ratification". Each trigger ends "…and so does the next standards audit if nothing grows it first" → **AM-32**. |

**The issue store:**

```
$ gh issue list --state all --limit 200 --json number,title,state,labels
21 OPEN   enhancement,state:triaged,severity:medium   Adopt LibKa0s-Schema-1.0's primitives, …
20 CLOSED enhancement,state:will-not-do,severity:low  Adopt the LibKa0s-Bus-1.0 stand-down record for bus receivers
19 OPEN   enhancement,state:untriaged,severity:low    Split the category-editing suites out of tests/test_pages_general.lua (1761 lines, …)
18 OPEN   … Split the user-category suites out of tests/test_filtercompiler.lua (1567 lines, …)
17 OPEN   … Split the user-category suites out of tests/test_database.lua (1702 lines, …)
16 OPEN   … Peel Dispel Colors out of settings/GeneralSpells.lua (1528 lines, …)
15 OPEN   bug,state:untriaged,severity:high           Add a spell can store a cast id whose aura id is different, …
…
10 CLOSED enhancement,state:triaged,severity:medium   Let players create their own spell categories, …   ← AM-36
 3 OPEN   enhancement,state:triaged,severity:low      Capture screenshots and add ## Screenshots before first publish
```

**What the store shows:**

- All 21 issues carry a `state:` label and a `severity:` label. No title starts with `[status]`.
- `docs/pending/` does not exist.
- Issue #16's body names the seam: "The `-- Dispel Colors` section at `settings/GeneralSpells.lua:1458`".
- Issues #17, #18 and #19 name their seams in their titles and bodies.
- Issue #20 declines an adoption that v2.64.0 permits outright (library-stack-§7), so it owes no register row.

## E-4 — The `docs/` tier model

In-scope `.md` files:

```
$ git ls-files 'docs/*.md' 'docs/**/*.md' | grep -vE '^docs/(audits|reviews|revendor|superpowers|investigations)/|^docs/automated-tests/[0-9]|^docs/perf-analysis/[0-9]'
docs/ARCHITECTURE.md  docs/automated-tests/README.md  docs/automated-tests/RESULTS.md  docs/common-tasks.md
docs/compat-layer.md  docs/data-flow.md  docs/midnight-quirks.md  docs/module-map.md  docs/perf-analysis/README.md
docs/performance.md  docs/profiles.md  docs/schema.md  docs/scope.md  docs/settings-panel.md  docs/slash-dispatch.md
docs/smoke-tests.md  docs/spell-research/2026-09-20/ANALYSIS.md  docs/spell-research/2026-09-20/DIFF.md
docs/spell-research/2026-09-20/SOURCES.md  docs/test-cases.md  docs/testing.md
```

**Tier 1.** All six are present.

**Tier 2 triggers, measured against the code:**

| Doc | Measurement | Result |
|---|---|---|
| `slash-dispatch.md` | `awk '/^NS.COMMANDS = \{/,/^\}/' settings/Slash.lua \| grep -cE '^\s+\{"'` → **22** | trigger fired; present |
| `compat-layer.md` | `grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua` → **21** (E-16) | trigger fired; present |
| `message-bus.md` | 4 messages | *Not applicable*, and the row says so |
| `profiles.md` | the Profiles sub-page exists | present |
| `debug.md` | `runDebug` (`settings/Slash.lua:331-338`) only toggles the library console or calls `SetEnabled`; there is no surface of the addon's own | *Not applicable* is correct |
| `midnight-quirks.md` | 12.1 aura secrecy workarounds | present |
| `perf-analysis/README.md` | the harness is wired | present |

**The map.** It is `docs/ARCHITECTURE.md:776-819`: four tables, in order. Verification and record holds
exactly six rows (`:810-815`).

**The orphan (AM-26).** `docs/spell-research/2026-09-20/*.md` appears in no table. The prose at `:779-781`
names `docs/spell-research/<date>/` as out of scope, but documentation-§3's list does not contain it.
`### Addon-specific` reads "None." (`:819`).

**Retired and forbidden docs:**

```
$ git ls-files | grep -iE 'todo\.md|CHANGELOG|agent-context|file-index|conventions\.md|complexity\.md|perf-runs|LEDGER'
(no output)
```

## E-5 — README and CLAUDE.md greps

```
$ grep -n 'Bundles \[LibKa0s\]' CLAUDE.md
36:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.55.0 (MIT).
$ grep -n 'Bundles \[LibKa0s\]' README.md                       → (none)
$ grep -nE '^## (Libraries|Bundled libraries|Libraries and credits|Credits and libraries|Credits and bundled libraries)' README.md → (none)
$ grep -n 'WoW_Addon_Standard' README.md
6:![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)        ← bare, compliant
$ grep -nE '!\[.*\]\(media/|<img' README.md                      → (none)
$ grep -nE '<[a-zA-Z][^>]*>' README.md | grep -v '<br>'          → (none)
```

**Screenshots (AM-20).** `README.md:26-29` reads:

> ## Screenshots
>
> No screenshots yet. They'll come before the first release, taken in the game itself: a bar container, an icon container, an unlocked container with its handle, and each settings page.

`README.md:156` reads `| 0.1.0 | 2026-09-11 | - First release: …`.

`AuraMaster.toc:13` reads `## X-Curse-Project-ID: 1698345`:

```
$ git log -S'X-Curse-Project-ID: 1698345' --format='%h %ad %s' --date=short -- AuraMaster.toc
a326ed7 2026-09-16 Aura Master has a CurseForge project id
```

`docs/ARCHITECTURE.md:744-745` reads: "**Unpublished; README `## Screenshots` is a placeholder, and its
images are owed before first publish** — see Documented deviations and issue tusharsaxena/AuraMaster#3."

## E-6 — Vendored LibKa0s drift

```
$ git -C ../LibKa0s describe --tags --always     → v1.55.0-3-g46ccaa6   (sibling HEAD, NOT used)
$ git -C ../LibKa0s rev-parse --short v1.55.0     → bb161b7
$ git -C ../LibKa0s archive v1.55.0 LibKa0s testkit | tar -x -C <scratch>/lk155
$ diff -r <scratch>/lk155/LibKa0s libs/LibKa0s && echo "LIBKA0S DIFF EMPTY"   → LIBKA0S DIFF EMPTY
$ diff -r <scratch>/lk155/testkit tests/_kit && echo "TESTKIT DIFF EMPTY"     → TESTKIT DIFF EMPTY
$ ls <scratch>/lk155/LibKa0s | wc -l → 24 ;  ls libs/LibKa0s | wc -l → 24
$ git ls-files -s tests/_kit/run-automated-tests.sh
100755 31ff9b3e429dbb85d52d336bfb286b94bedd838b 0	tests/_kit/run-automated-tests.sh
```

- The diff runs against the tag named in the provenance line (`CLAUDE.md:36`), not against the sibling's HEAD.
- `git archive` applies LibKa0s's own `eol=crlf` pin, so both sides are working-tree representations.
- The TOC lists the aggregate XML once: `AuraMaster.toc:29` → `libs\LibKa0s\LibKa0s.xml`.

## E-7 — Re-vendor bundle coverage (AM-21)

These commands are run exactly as `AUDIT.md` step 4 gives them. The scratch files replace `/tmp`.

```
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)   → 2026-09-12
git log --since=2026-09-12 --format=%H -- libs/LibKa0s | wc -l → 27 commits
vendored (read from CLAUDE.md at each commit):
  v1.33.0 v1.34.0 v1.35.0 v1.36.0 v1.36.1 v1.36.2 v1.37.0 v1.38.0 v1.39.0 v1.42.0 v1.44.0 v1.46.1
  v1.47.0 v1.48.0 v1.48.1 v1.49.0 v1.49.1 v1.50.0 v1.51.0 v1.52.0 v1.53.0 v1.55.0        (22)
recorded (folder tag, else first line of 01_DELTA.md):
  v1.30.0 v1.31.0 v1.32.0 v1.33.0 v1.34.0 v1.55.0                                        (6)
vendored, in scope, unrecorded:
  v1.35.0 v1.36.0 v1.36.1 v1.36.2 v1.37.0 v1.38.0 v1.39.0 v1.42.0 v1.44.0 v1.46.1 v1.47.0
  v1.48.0 v1.48.1 v1.49.0 v1.49.1 v1.50.0 v1.51.0 v1.52.0 v1.53.0                        (19)
```

**The base of the newest re-vendor.** Three consecutive commits, with the provenance tag each one's `CLAUDE.md` carries:

```
$ git log --since=2026-09-19 --format='%h %ad %s' --date=short -- libs/LibKa0s | head -3
f6f3ffb 2026-09-23 Re-vendor LibKa0s v1.55.0          (CLAUDE.md → v1.55.0)
f6f61d3 2026-09-22 Re-vendor LibKa0s v1.53.0          (CLAUDE.md → v1.53.0)
f434521 2026-09-22 Re-vendor v1.52.0: …               (CLAUDE.md → v1.52.0)
```

The newest bundle nevertheless records its base as v1.54.2. `docs/revendor/2026-09-23-v1.55.0/01_DELTA.md:1`
reads `# 01 - Delta: LibKa0s v1.54.2 -> v1.55.0`.

The bare-dated `docs/revendor/2026-09-12/01_DELTA.md:1` reads `# 01 — Delta: LibKa0s v1.29.0 → v1.30.0`.
Its tag is read from the file, as the grandfathering rule requires.

## E-8 — Line endings

**Checks (a) to (d), the pin and the carve-outs:**

```
$ test -f .gitattributes || echo MISSING                          → (present)
$ grep -n '^\* text=auto eol=\(crlf\|lf\)$' .gitattributes | tr -d '\r'
26:* text=auto eol=crlf
$ grep -nE '^\*\.(sh|py) text eol=lf' .gitattributes | tr -d '\r'
36:*.sh text eol=lf
37:*.py text eol=lf
$ grep -c ' binary' .gitattributes                                → 23
```

**The §5 body diff.** The canonical client-bound body is 84 lines, taken from `line-endings.md:166-249`.
The working tree is CRLF, so CR is stripped before comparing:

```
$ diff <(head -n 84 .gitattributes | tr -d '\r') <canonical> && echo BODY-IDENTICAL   → BODY-IDENTICAL
$ tail -n +85 .gitattributes | tr -d '\r' | grep -m1 .                                → (nothing; no appendix)
```

**Check (e), the working tree.** This is the exact one-liner from `AUDIT.md`. It covers the whole tracked
set, 481 files, and excludes nothing:

```
$ git ls-files -z | xargs -0 -I{} sh -c '…' 2>/dev/null | wc -l
1
```

The one file, with its CR and LF counts:

```
tests/page_helpers.lua cr=272 lf=271
$ grep -n $'\r[^\n]' tests/page_helpers.lua | cat -A
80:    --- A structural refresh, then the next show: the page draws again from the current state.^M^M$
$ git ls-files --eol tests/page_helpers.lua tests/run.lua
i/-text w/-text attr/text=auto eol=crlf	tests/page_helpers.lua      ← classified binary, stored un-normalized
i/lf    w/crlf  attr/text=auto eol=crlf	tests/run.lua              ← the normal state
$ git show HEAD:tests/page_helpers.lua | tr -dc '\r' | wc -c   → 272   (CRLF inside the blob)
```

The kit's EOL gate is green (E-2).

## E-9 — Packaging

`AUDIT.md`'s three checks, run under `bash` so the word list splits:

```
(a) NOT IGNORED   → (none)
(b) UNACCOUNTED   → .git        (exempt by the playbook)
(c) FALSE CLAIM   → .claude ignored, no such directory        ← AM-35
```

- `.pkgmeta:12` reads `  - .claude          # dev-only: agent tooling; never loaded by the client`.
- `ls -la` at the root shows no `.claude`.
- `tools` is ignored at `.pkgmeta:16`. It carries no `externals:` block and no `enable-toc-creation`.

## E-10 — Complexity (AM-31)

```
$ ~/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .     (lizard 1.24.0; exit 1 = warnings present)
!!!! Warnings (cyclomatic_complexity > 15 or length > 1000 or nloc > 1000000 or parameter_count > 100) !!!!
      64     25    476      1      83 Cat.SyncUserCategories@1112-1194@./defaults/Categories.lua
      38     16    315      3      44 renderCategories@500-543@./settings/Filters.lua
Total nloc   Avg.NLOC  AvgCCN  Avg.token   Fun Cnt  Warning cnt
     30336       8.1     2.3       70.5     3348            2
```

**The recorded run** (`docs/automated-tests/RESULTS.md`, newest row):

```
| 20260916-184324 | 0.1.0 | 0/0 | 95 | 943/0/943 | pass | 21163 | 2446 | 7.9 | 2.2 | 15 | 0 | green |
```

**How old that run is:**

```
$ git log --format='%h %ad' --date=short -1 -- docs/automated-tests/20260916-184324   → 7b0ed39 2026-09-16
$ git rev-list --count 7b0ed39..HEAD                                                   → 129
```

The row carries no commit-SHA cell. It predates revision 25, so the commit it measured is unknown; that is
not a finding.

**What the two warned functions are:**

- `Cat.SyncUserCategories` is four sequential phases: teardown (`:1119-1131`), anchor lookup
  (`:1139-1144`), a materialize loop with nested branches (`:1146-1184`) and registration (`:1186-1191`).
  This is real control flow, not `or`-defaulting.
- `renderCategories` dispatches on `g.key` over three branches inside a loop (`settings/Filters.lua:510-541`).

**The watch list.** Two entries, both "Accepted", both carried for two runs. They were never carried
across three release runs, because there has been no release since 0.1.0. The band table lists
`tests/test_database.lua` at 1037 lines; the tree has 1702.

## E-11 — Disabled-state census (slash-commands-§7)

**Scope.** These are TOC-loaded authored files, `git ls-files '*.lua' ':!libs' ':!tests'`.

**What the addon registers:**

```
$ … | xargs grep -nE 'Register(Unit)?Event|RegisterMessage|RegisterBucketEvent'
core/AuraMaster.lua:58-66      8 × self:RegisterEvent (RegisterLifecycleEvents)
core/LifecycleSetup.lua:71     addon:RegisterEvent(PENDING_EVENT, …)      ← sanctioned combat-deferred survivor
modules/ContainerManager.lua:535,545,548   3 × ev:RegisterMessage
modules/TimedSpells.lua:121    events:RegisterEvent("UNIT_AURA", onUnitAura)
modules/TimedSpells.lua:140-142 3 × events:RegisterEvent
modules/TimedSpells.lua:158-159 2 × bus:RegisterMessage
settings/OptionsSetup.lua:396  ev:RegisterMessage(NS.MSG.CONTAINERS_CHANGED, …)   ← panel refresh; open-evolutions, not filed
```

**What it unregisters or cancels:**

```
$ … | xargs grep -nE 'Unregister(All)?Events?|UnregisterMessage|…|SetScript\("OnUpdate", *nil\)'  (plus UnregisterAll)
core/AuraMaster.lua:75         self:UnregisterEvent(event)          (UnregisterLifecycleEvents, :69-77)
core/LifecycleSetup.lua:51     addon:UnregisterEvent(PENDING_EVENT)
modules/FramePicker.lua:45     overlay:SetScript("OnUpdate", nil)
modules/TimedSpells.lua:125,132  UnregisterEvent("UNIT_AURA"), UnregisterAllEvents()
modules/TimedSpells.lua:167    bus:UnregisterAllMessages()
modules/ContainerManager.lua:559  ev:UnregisterAllMessages()
```

**The stand-down itself** is `core/LifecycleSetup.lua:87-95`:

```
    if addon and addon.UnregisterLifecycleEvents then addon:UnregisterLifecycleEvents() end
    if NS.TimedSpells and NS.TimedSpells.StandDown then NS.TimedSpells.StandDown() end
    if NS.ContainerManager and NS.ContainerManager.StopListening then NS.ContainerManager.StopListening() end
    if NS.FramePicker and NS.FramePicker.Stop then NS.FramePicker.Stop() end
    if not applySecure() then holdPending() end
```

**The timers (AM-24):**

- `modules/ContainerManager.lua:155` → `        C_Timer.After(0, CM.FlushPending)`
- `modules/ContainerManager.lua:253` → `    if NS.IsStoodDown() then return 0 end`
- `modules/TimedSpells.lua:106` → `    C_Timer.After(0.5, scanTick)`
- `modules/TimedSpells.lua:163-164` → `--- TS.Sync last opened. A scan already queued is dropped by scanTick's
  \`listening\` guard rather than` / `--- canceled -- C_Timer.After hands back no handle to cancel.`
- `CM.RequestApply` refuses to arm while stood down: `modules/ContainerManager.lua:146` →
  `    if NS.IsStoodDown() then return end`.

**The launcher.** It refuses left-click while disabled (`core/LauncherSetup.lua`, `onClick`:
`if NS.IsDisabled and NS.IsDisabled() then … NS.Print(NS.Slash.DisabledLine()) … return end`), and
right-click reaches `openSettings`.

**The suite.** `tests/test_disabled.lua:11-14` asserts against `__registrations`, `__timers()`, shown
frames, SavedVariables writes and printed lines. It carries `red under:` comments at `:164`, `:212`,
`:235`, `:267`, `:387` and `:437`.

## E-12 — Authored-Lua LOC census (layout-§1)

**Scope.** Authored Lua, `libs/` and `tests/_kit/` excluded. There are no declared generated-data
exemptions.

```
$ git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | wc -l            → 110
$ git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | xargs wc -l | sort -n | tail
   1019 tests/test_pages_filters.lua   1170 tests/test_style.lua   1384 tests/test_anchors.lua
   1478 defaults/Categories.lua        1528 settings/GeneralSpells.lua   1567 tests/test_filtercompiler.lua
   1702 tests/test_database.lua        1761 tests/test_pages_general.lua    44017 total
```

The census (`docs/ARCHITECTURE.md:836-841`) names the same four files over the cap, with the same counts.

## E-13 — The close-button grep (standalone-windows)

```
$ grep -rn 'MakeCloseButton(' --include='*.lua' . | grep -v '/libs/' | grep -v '/tests/'
./core/CoreSetup.lua:118:    return lib.MakeCloseButton(parent, onClick, addonName)
```

This is the one wrapper. `core/CoreSetup.lua:117` reads `NS.MakeCloseButton = function(parent, onClick)`.

## E-14 — Bus message constants

```
$ grep -rnE '(Send|Register)Message\("Ka0s_' --include='*.lua' . | grep -v -e '/libs/' -e '/tests/_kit/'   → (none)
$ grep -rnoE '"Ka0s_[A-Za-z]+_[A-Za-z0-9_]+"' --include='*.lua' . | grep -v -e '/libs/' -e '/tests/_kit/'
core/Bus.lua:50:"Ka0s_AuraMaster_ContainersChanged"   core/Bus.lua:54:"Ka0s_AuraMaster_ConfigChanged"
core/Bus.lua:57:"Ka0s_AuraMaster_VisibilityChanged"   core/Bus.lua:62:"Ka0s_AuraMaster_TimedSpellsChanged"
tests/test_bus.lua:52-55,81,94  (the bus suite's own assertions)
```

All four tails are PascalCase. The declaration is `core/Bus.lua:46`, `NS.MSG = Bus.Catalog(addonName, {`.

## E-15 — Citation resolution (AM-07 and AM-08)

**Scope.** Every distinct `` `path:line` `` citation in `docs/ARCHITECTURE.md` (35) and every distinct
full `path:line` in `DEPENDENCIES.md` (25). Shorthand `:N` continuations and all other docs were not swept
this run.

**Mismatches in `docs/ARCHITECTURE.md`:**

| Citation | Claimed | Line text now | Actual location |
|---|---|---|---|
| `settings/Schema.lua:377` | `CONFIG_CHANGED` sender | `-- collapses.` | `:460` `NS.bus:SendMessage(NS.MSG.CONFIG_CHANGED,` |
| `modules/ContainerManager.lua:520` | `CONFIG_CHANGED` receiver | `--- A write that moves a container's flow …` | `:535` `ev:RegisterMessage(NS.MSG.CONFIG_CHANGED, …` |
| `modules/ContainerManager.lua:543` | `VISIBILITY_CHANGED` receiver | `            end` | `:545` `ev:RegisterMessage(NS.MSG.VISIBILITY_CHANGED, …` |
| `settings/OptionsSetup.lua:380` | `CONTAINERS_CHANGED` receiver | `-- which rows exist — is run on the NEXT frame…` | `:396` `ev:RegisterMessage(NS.MSG.CONTAINERS_CHANGED, …` |
| `modules/Style.lua:823-825` | one click phase, `RightButtonUp` | `local cancel = cancelEnabled(cfg, b)` | `:826-828`, with `RightButtonUp` at `:828` |

**Mismatches in `DEPENDENCIES.md`:**

| Citation | Claimed | Line text now | Actual location |
|---|---|---|---|
| `core/Constants.lua:25` | `C.LOGO_PATH` | a comment | `:26` `C.LOGO_PATH = …` |
| `core/Constants.lua:31` | `C.LOGO_ICON_PATH` | a comment | `:32` `C.LOGO_ICON_PATH = …` |
| `modules/ContainerManager.lua:568` | the no-engine notice | `--- Build every container and start listening…` | `:572` `print_(L["This client has no aura container API …"])` |

The other 30 hub citations and 22 dependency citations resolve to the claimed text. Examples:
`core/Database.lua:246` → `NS.db = AceDB:New("AuraMasterDB", NS.defaults, true)` and
`settings/Slash.lua:523-524` → `NS.addon:RegisterChatCommand("am", …)`.

## E-16 — Compat

```
$ grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua   → 21
$ git ls-files 'core/*.lua' 'modules/*.lua' 'settings/*.lua' 'defaults/*.lua' 'locales/*.lua' \
    | xargs grep -nE '\bGetAddOnMetadata\b|[^.]GetSpellInfo\(|GetMouseFocus|GetSpecialization|IsAddOnLoaded|WOW_PROJECT_ID' \
    | grep -v 'Compat\.' | grep -v '^core/Compat.lua'
core/EnvSetup.lua:9,20   (comments)   core/EnvSetup.lua:25-27  Env.GetAddOnMetadata / C_AddOns.GetAddOnMetadata
```

No deprecated global is called outside `core/Compat.lua`.

## E-17 — Event-name robustness (AM-23)

```
$ git ls-files '*.lua' ':!libs' ':!tests' | xargs grep -n 'IsEventValid\|pcall(.*RegisterEvent\|__badEvents'  → (none)
$ git ls-files 'tests/*.lua' ':!tests/_kit' | xargs grep -ln '__badEvents'                                    → (none)
```

The registration block is `core/AuraMaster.lua:57-67`. It runs from `function addon:RegisterLifecycleEvents()`
to eight `self:RegisterEvent(…)` calls; line 66 is
`self:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED", "OnRestrictionChanged")`.

## E-18 — The 128 icon

```
$ od -A d -t u1 -N 18 media/logos/auramaster.logo.128.tga
0000000   0   0   2   0   0   0   0   0   0   0   0   0 128   0 128   0
0000016  32   8
```

Byte 2 is 2, so the image is uncompressed. Width and height are 128 each, and the bit depth is 32.

## E-19 — The Options stub (AM-22)

`settings/OptionsSetup.lua:189-190` says the stub's composers reproduce the stored surface: "The composers
reproduce the STORED SURFACE only — one row per canonical leaf at the path the live composer derives, with
its type."

| Member | Line |
|---|---|
| `local function composeBlock(leaves, spec)` | `:198` |
| `Helpers.ColorPair` | `:221` |
| `Helpers.FontGroup` | `:227` |
| `Helpers.BorderGroup` | `:234` |
| `Helpers.BarGroup` | `:243` |
| `Helpers.MasterControls` | `:253`, which ends `return rows, function() end` at `:278` |

The suite pins degraded and live counts as equal: `tests/test_optionssetup.lua:369` →
`assertEqual(#NS2.Schema, #NS.Schema, "the degraded schema has every row the live one has")`.

## E-20 — The settings window grep (options-ui-§2)

```
$ grep -rnE 'SettingsPanel|HideUIPanel|ToggleGameMenu|OpenToCategory' --include='*.lua' . | grep -v -e '/libs/' -e '/tests/'
settings/Layout.lua:224:    if SettingsPanel and SettingsPanel.Close then pcall(SettingsPanel.Close, SettingsPanel, true) end
settings/OptionsSetup.lua:372-373:  … Settings.OpenToCategory(cat:GetID())
```

- `settings/Layout.lua:220-222` refuses under `InCombatLockdown()` before the close.
- `settings/OptionsSetup.lua:367-369` refuses in combat with the canonical text before the page jump.
- `cat` is the subcategory returned by the builder (`:356-357`).

## E-21 — Localization joins (AM-13)

| Site | Code |
|---|---|
| `core/CoreSetup.lua:72` | `NS.LIBKA0S_MISSING .. "; " .. NS.L["running on reduced built-in fallbacks."])` |
| `core/DebugLogSetup.lua:19` | `local missing = NS.LIBKA0S_MISSING .. ", " .. NS.L["so the debug console window is unavailable."]` |
| `core/LauncherSetup.lua:50` | `local missing = NS.LIBKA0S_MISSING .. ", " .. NS.L["so the minimap button is unavailable."]` |
| `core/PerfSetup.lua:24` | `return { NS.LIBKA0S_MISSING .. ", " .. NS.L["so performance measurement is unavailable."] }` |
| **Contrast:** `settings/OptionsSetup.lua:194` | `NS.Printf(L["%s, so the settings panel is unavailable."], NS.LIBKA0S_MISSING)` |

## E-22 — Enable and lock confirmations (AM-29)

`settings/Slash.lua:192-194`:

```
    local ok, err = NS.SetByPath("enabled", on)
    if not ok then return print(err) end
    print(on and L["Aura Master enabled"] or L["Aura Master disabled — /am enable turns it back on"])
```

`settings/Slash.lua:284` → `    print(locked and L["Containers locked"] or L["Containers unlocked — drag a container by its handle"])`

## E-23 — Hub shape (AM-25)

```
$ wc -l docs/ARCHITECTURE.md   → 841
$ awk '/^## /{…}' docs/ARCHITECTURE.md
## Overview 6-74 (69)   ## Module Map 75-106 (32)   ## Settings Schema 107-244 (138)
## Locale routing… 245-269 (25)   ## Filter priority 270-319 (50)   ## Message Bus 320-340 (21)
## Slash Commands 341-390 (50)   ## Launcher 391-420 (30)   ## Event Subscriptions 421-443 (23)
## The disabled state 444-487 (44)   ## Taint Notes 488-585 (98)   ## Known Limitations 586-775 (190)
## Documentation map 776-820 (45)   ## Documented deviations 821-841 (21)
```

## E-24 — Named state: `minimapPos` (AM-33)

- `docs/ARCHITECTURE.md:216` → "The addon holds two pieces of named non-setting state (architecture-§5)."
  The two are `global.timedSpells` (`:219`) and `AuraMasterPerfDB` (`:234`).
- `docs/schema.md:39` → "`minimapPos` is written by LibDBIcon when the player drags the button." No owner
  module is named.

## E-25 — DEPENDENCIES groups (AM-34)

- `DEPENDENCIES.md:13` → Development: "… **Python 3** only if you run the spell-research generator."
- `DEPENDENCIES.md:14` → `| Release / assets | Nobody, locally | None. |`
- `DEPENDENCIES.md:123-133` → "**Pillow regenerates the 128 icon, and is NOT required…**", followed by a
  `python3 -c "from PIL import Image; …"` recipe with no install line.
- `defaults/CastToAura.lua:3-6` → "GENERATED. … derived 2026-09-20 by tools/spell-research/research.py --emit-cast-aura."
