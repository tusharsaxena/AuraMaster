# Ka0s Aura Master: review findings (2026-09-23)

**Verdict: minor issues.** No Critical or High findings. There are four Medium findings:
- a frame leak that also reuses a global name when a container id is handed out again,
- an unfiltered `UNIT_AURA` firehose, which the standard now carves out an exemption for,
- two functions over the CCN-15 release gate,
- a host copy of the library's tabbed-page renderer.

The rest are Low: hygiene, stubs and documentation drift.

Reviewed: the whole repository on branch `feat/2026-09-23-review-audit-remediation` at `8046dfb`. The addon version is `0.1.0`, and LibKa0s v1.55.0 is vendored.

Standards cross-check: done against **Ka0s WoW Addon Standard v2.64.0 (2026-09-23)**. The remote `STANDARDS.md` fetched with `curl` is byte-identical to the local clone at `../WowAddonStandards` (`e68795f`), so the section files were read from that clone.

## Measurement run

`ka0s-bounded` is not on `PATH` in this shell. It is present at `~/.claude/wow-addon/bin/ka0s-bounded`, and every run below went through it by absolute path. Fresh output went to a scratch path outside the repo, and no committed artifact was touched.

| Suite | Result | Command (repo root unless stated) |
|---|---|---|
| luacheck | **pass**: 0 warnings / 0 errors in 110 files | `ka0s-bounded luacheck .` |
| Headless tests | **pass**: 1296 passed, 0 failed, 0 skipped, 1296 total | `ka0s-bounded lua5.1 tests/run.lua` |
| `--list` inventory | **pass**: 1296 cases, byte-identical (CR-normalized) to the committed `docs/test-cases.md` | `ka0s-bounded lua5.1 tests/run.lua --list > <scratch>/list.md` |
| Offline perf | **ran**: 10 scenarios, every assertion held | `ka0s-bounded lua5.1 tests/perf.lua` |
| Complexity | **ran**: 3348 functions, avg CCN 2.3, **2 warnings** (CCN > 15) | `ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" . > <scratch>/lizard.txt` |
| `make test` | **skipped**: there is no root `Makefile` | — |
| Vendor sync | **pass**: `libs/LibKa0s/` matches `../LibKa0s/LibKa0s/`, and `tests/_kit/` matches `../LibKa0s/testkit/` (both `diff -rq` empty). LibKa0s is at `v1.55.0-3-g46ccaa6` | `diff -rq libs/LibKa0s ../LibKa0s/LibKa0s`; `diff -rq tests/_kit ../LibKa0s/testkit` |
| Cross-addon, class 1 (slash tokens) | **clean**: 20 roots across 10 addons with no duplicate, and 0 raw `SLASH_*` in loaded source | the two loops in the review brief, run from `../` over AbsorbTracker, AuraMaster, BankLedger, ConsumableMaster, KickCD, LootHistory, MultiMeters, PanelMaster, PrettyChat, WhatGroup, TOC-derived load list |
| Cross-addon, class 2 (minors) | **clean**: one line, the same for all 10: `Bus:1 Compat:1 Core:7 DebugLog:12 Env:1 Item:1 Launcher:1 Lifecycle:1 Media:3 Options:23 Perf:12 Pool:3 Schema:1 Slash:14 Widgets:9` | `grep -rhoE 'local MAJOR, MINOR = …' <a>/libs/LibKa0s` |
| Cross-addon, class 3 (bytes) | **clean**: `diff -rq AbsorbTracker/libs/LibKa0s <a>/libs/LibKa0s` is empty for all 10 (AbsorbTracker is the reference) | as stated |
| Cross-addon, class 4 (`## Interface:`) | **clean**: `120100`, the same in all 10 | `grep -h '^## Interface:' <a>/*.toc \| tr -d '\r' \| sort -u` |

The cross-addon pass is a **measured non-finding**. The collection has moved on from the 2026-09-07 baseline table in exactly the direction a collection-wide re-vendor should:
- AuraMaster adds `am` and `auramaster`, making 20 roots.
- The minors moved up together, in lockstep.
- `## Interface:` moved from 120007 to 120100, uniformly.
- The PrettyChat CR-straggler pair is gone, so all files are byte-identical.

Nothing has diverged.

Line endings, as an observation only: over `git ls-files --eol`, 339 text files are `w/crlf`, 140 are binary, and 2 are `w/lf`. The two LF files are the `*.sh` / `*.py` carve-outs, which is correct. `.gitattributes` carries the CRLF pin, the carve-outs and the binary list.

**Committed artifacts that disagree with today's run:**
- **`docs/automated-tests/RESULTS.md`** is stale. It is the newest bundle, `20260916-184324`, at git `a326ed7`. It records 943/943 tests, max CCN 15, 0 warnings, 2 files in the 1000–1500 band and 0 over the cap. Today there are 1296 tests and max CCN **25** with **2** warnings. There are **4** files over 1500 lines: `settings/GeneralSpells.lua` 1528, `tests/test_database.lua` 1702, `tests/test_filtercompiler.lua` 1567 and `tests/test_pages_general.lua` 1761. There are 4 in the 1000–1500 band: `defaults/Categories.lua` 1478, `tests/test_anchors.lua` 1384, `tests/test_style.lua` 1170 and `tests/test_pages_filters.lua` 1019. The census scope was `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | xargs wc -l`, which is tracked, authored Lua with `tests/` included. Its watch list names neither CCN warning (see F-003). This is stale, not non-compliant: it is regenerated at release.
- **`docs/performance.md`** has stale line citations (F-012). Its scenario table still matches the runner. It carries no figures to compare against.
- **`docs/test-cases.md`**: no drift.

Fresh offline perf, for orientation only; compare within this run:

```
compile        2000 iters  0.07458 ms  0.0 api  22200.0 B
applyPass       200        1.26208     30.0     117715.2
restyle         200        0.46050      0.0      51413.9
restyleText     200        0.26020      0.0      30960.6
visibilityPass 1000        0.00921      4.0        384.0
unitSwap       1000        0.00154      1.0          0.0
probeOverheadOff 1000      0.01204      5.0        384.0
probeOverheadOn  1000      0.01054      5.0        384.5
probeAbsent      1000      0.01231      5.0        384.0
unitAuraOther    1000      0.00013      0.0          0.0
```

`probeOverheadOff` equals `probeAbsent` in both engine calls (5) and bytes (384), so the zero-overhead claim is pinned. There are **no in-client captures**: `docs/perf-analysis/` holds only its `README.md`. Every in-game cost claim below is therefore unverified in-client, and `03_SMOKE_TESTS.md` carries the capture.

---

## Medium

### F-003: Two functions are above CCN 15, and the next tag's release gate will refuse them
`[complexity]`

- **Where:** `defaults/Categories.lua:1112` `function Cat.SyncUserCategories(profile)`. Fresh lizard gives lines 1112–1194, NLOC 64, **CCN 25**. Also `settings/Filters.lua:500` `local function renderCategories(ctx, cfg, rows)`, lines 500–543, **CCN 16**.
- **Problem:** Both functions crossed the threshold after the last recorded run. The committed watch list (`20260916-184324`, max CCN 15) names neither.
- **Impact:** `automated-tests-§3` *The release gate* requires zero functions above CCN 15 for the tag, so `/wow-addon:bump-version` will refuse the next release until they are fixed or ruled on.
- **What drives the score:**
  - `SyncUserCategories` is real control flow, not dense defaulting. It is four sequential phases in one body: tear down the definitions and template keys, compute the insert points, materialize the records, register the rows. That makes nine loops and branches, plus the `and`/`or` defaulting on lines 1113–1117.
  - `renderCategories` is a three-way branch on the grid kind. Five of its decisions sit in the `custom` arm.
- **Reachability:** Maintainers and the release process only. There is no runtime effect.
- **Coverage:** Both functions are heavily covered: `tests/test_defaults.lua`, `tests/test_database.lua` (user categories) and `tests/test_pages_filters.lua`. A refactor therefore has characterization cases to lean on.

### F-001: A reused container id builds a second `AuraMasterAnchor<id>` and leaks the first
`[frames]` `[design]`

- **Where:**
  - `modules/Container.lua:43` `self.anchor = CreateFrame("Frame", "AuraMasterAnchor" .. id, UIParent,`
  - `modules/ContainerManager.lua:85` `CM.instances[id] = NS.Container.New(id)`
  - `modules/ContainerManager.lua:107-108` `else` / `inst:Destroy()`
  - `modules/ContainerManager.lua:54-55`, a comment that claims *"a second AuraMasterAnchor<id> global would be a second frame for the same container"* is avoided.
- **Problem:** The revive path only covers instances **parked** under `CM.MustDefer()`. Out of combat with auras readable, a container that leaves the registry is **destroyed**. Its anchor, engine, retired engines, blocker, outline, drag handle and preview pool stay alive, because frames are never freed, but nothing references them any more. A later build for the same id then goes through `NS.Container.New(id)` again. That builds a whole new frame set and overwrites `_G.AuraMasterAnchor<id>`.
- **How ids come back:**
  - A profile switch where A has ids 1–5 and B has ids 1–2. Ids 3–5 are destroyed on A→B and rebuilt fresh on B→A.
  - A profile reset (`db:ResetProfile` rewinds `nextContainerId`) followed by a Create.
  - A profile copy.
- **Impact:** Every out-of-combat round trip through a profile with fewer containers leaks one anchor, one engine and its buttons per missing id. Two frames then answer `GetName()` with the same string.
- **Reachability:** Any player with two or more profiles holding different container counts who switches between them out of combat, or who resets or copies a profile and then creates a container. The frame cost grows over a long session with frequent profile switching (spec/role profiles). Nothing visible breaks.
- **Coverage:** `tests/test_containermanager.lua` covers the **deferred** half only, in the cases at `:488` and `:510` (*"revived, not rebuilt"*, `spyCreate(mocks, "AuraMasterAnchor5")`). No case drives the out-of-combat destroy → same-id rebuild. That is why the comment's claim reads as tested.

### F-002: `UNIT_AURA` is registered for every unit while a "without a duration" container exists
`[perf]` `[events]`

- **Where:**
  - `modules/TimedSpells.lua:121` `events:RegisterEvent("UNIT_AURA", onUnitAura)`
  - `modules/TimedSpells.lua:111-113`, where `onUnitAura` discards all but player and pet.
  - `modules/TimedSpells.lua:14-15`, the rationale: *"The vendored AceEvent has no RegisterUnitEvent, so UNIT_AURA arrives for every unit"*.
- **Problem:** The addon routes a two-unit listen through AceEvent's shared frame. The client therefore dispatches every raid member's and nameplate's `UNIT_AURA` into Lua just to reject it. The file's rationale is now stale: `events-frames-taint-§1` has a named carve-out for exactly this case. It permits a private frame whose only job is `RegisterUnitEvent("UNIT_AURA", "player", "pet")`, and the standard's own text cites this addon's firehose as the reason the carve-out exists.
- **Impact:** Out of combat in a populated zone, a city or a raid between pulls, every aura change on every visible unit pays client dispatch plus one `IsSafeKey` and a compare. The offline scenario `unitAuraOther` shows the Lua side is small: 0.00013 ms/iter and 0 B/iter. The dispatch half cannot be measured offline, and there is no in-client capture, so its size is **unverified**.
- **Reachability:** Only players who set a container's duration filter to *"only auras without a duration"*. No starter container does (`defaults/Profile.lua:255-279`, and `durationMode` defaults to `"any"` at `:145`). Registration is also closed in combat and while auras are secret.

### F-004: The host re-implements the library's tabbed-page render and page-banner chrome
`[design]`, with an additive upstream route

- **Where:**
  - `settings/OptionsSetup.lua:659` `function Helpers.RenderTabbedPage(ctx, pageKey, spec, chrome)`, with `collectTabs` at `:560`, `settleActiveTab` at `:583` and `renderActiveTab` at `:624`.
  - `settings/OptionsSetup.lua:480-504` `buildContainerHeader`, which is raw `NS.AceGUI:Create("Dropdown")` at `:484` and `Create("Button")` at `:497`.
  - It sits beside `libs/LibKa0s/OptionsWidgets.lua:3861` `function O.RenderTabbedSchema(ctx, pageKey, afterGroup, pairWith)` and `libs/LibKa0s/OptionsTabs.lua:1029` `function O.PageBanner(ctx, spec)`.
- **Problem:** The host owns a second copy of the group→tab partition, the stale-tab heal, the tab-switch re-render and the page-banner picker. The library's version lacks four things this addon needs:
  - bespoke (non-row) tabs,
  - a per-container disabled notice,
  - a chrome hook,
  - a banner carrying a picker plus a create button (`options-ui-§14`'s one-row band).
- **Impact:** A fix to the library's renderer (its `#groups == 0` report, the one-group strip rule, a future combat-lock change) does not reach these seven pages until someone ports it by hand. This is the forking shape `anti-patterns` #47 names. The same shape recurs in several consumers, all of which build `TabStrip` pages by hand: AbsorbTracker `settings/UnitPanel.lua:327`, KickCD `settings/Panel_Render.lua:208`, ConsumableMaster `settings/General.lua:402` (and three more files), and MultiMeters `settings/Columns.lua:321`.
- **Reachability:** Maintainers. There is no player-visible defect today.
- **Fix direction:** An **additive** field on `RenderTabbedSchema` and `PageBanner` upstream, weighed against `anti-patterns` #55 in LibKa0s, then adoption here. Never a local patch to `libs/`.

---

## Low

### F-005: Lifecycle event registration is not isolated per event
`[events]`

- **Where:** `core/AuraMaster.lua:57-67` (`function addon:RegisterLifecycleEvents()` … `self:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED", "OnRestrictionChanged")`) and `modules/TimedSpells.lua:140-142`.
- **Problem:** These are bare sequential `RegisterEvent` calls. `events-frames-taint-§1` (*"An unknown event name raises, and takes the rest of the block with it"*) requires a `pcall`-isolated helper that records the names it rejected.
- **Impact:** None on 12.1. If a future patch retires or renames `ADDON_RESTRICTION_STATE_CHANGED`, the addon stops hearing that the restriction has lifted. It is last in both blocks, so only it would be lost. Held applies would then wait for the next `PLAYER_REGEN_ENABLED` or world entry.
- **Reachability:** Nobody on the shipping 12.1 client. A future client only.

### F-006: `CM.Init` and `CM.Announce` build container frames while the addon is stood down, and a comment says otherwise
`[design]` `[naming]`

- **Where:**
  - `core/AuraMaster.lua:51` `if NS.ContainerManager and NS.ContainerManager.Init then NS.ContainerManager.Init() end`, which runs whatever the latch says.
  - `modules/ContainerManager.lua:568-569` *"Called once … and only when the addon is actually running"*.
  - `modules/ContainerManager.lua:575` `CM.Sync()`.
- **Problem:** A player who logs in with the addon disabled, or switches to a profile while it is disabled, gets an anchor and a drag handle created per container. The anchors are left in `CreateFrame`'s default shown state, because the stand-down ran before they existed.
- **Impact:** The frames are empty and invisible, so nothing draws. The doc comment misstates the contract, and the "disabled draws nothing" suite only covers enabled→disabled.
- **Reachability:** Any player who has the addon disabled at login.

### F-007: The degraded Lifecycle stub is level-triggered where the library is edge-triggered
`[design]`

- **Where:** `core/LifecycleSetup.lua:128-130` `function NS.SyncEnabled()` / `if NS.IsStoodDown() then standDown() else standUp() end`
- **Problem:** Without the library, every `SyncEnabled` call runs the whole `standUp`. That happens in `OnInitialize` before `PLAYER_LOGIN`, and on every profile switch. `standUp` re-registers events, arms an apply timer and re-reparents the Blizzard frames. The library fires `standUp` only on a hold-set edge.
- **Impact:** A redundant apply pass. The startup build is attempted before `OnEnable`'s. No incorrect state was found.
- **Reachability:** Only installs where `libs/LibKa0s` failed LibStub's floor.

### F-008: Degradation stubs copy library behavior that will go stale
`[design]`

- **Where:**
  - `core/PoolSetup.lua:17-49`: a full `New` / `Acquire` / `ReleaseAll` / `Counts`, including the backward-release ordering.
  - `settings/Slash.lua:388-391`: `stub.DisabledLine` re-spells the library's refusal sentence.
  - `settings/OptionsSetup.lua:198-279`: the composers' leaf lists (`FontGroup`, `BorderGroup`, `BarGroup`, `MasterControls`) retyped.
- **Problem:** Each stub is described as *"spelled as the library spells it"*. That makes it the copy that drifts when the library moves (`library-stack-§7`, `anti-patterns` #56).
- **What is justified:** The `MasterControls` rows are load-bearing even degraded, because `/am enable|disable` write `enabled` through the seam. The Pool copy is defensible because a pool-less preview leaks.
- **What is not:** The leaf-order detail of the three style composers, and the literal refusal line, earn nothing on a build whose panel and CLI are already announced as unavailable.
- **Reachability:** Degraded installs only.

### F-009: The panel's Test mode checkbox is accepted while the addon is disabled; `/am test` and the launcher refuse
`[ux]`

- **Where:** `settings/General.lua:107-114` binds the row straight to `NS.Preview.SetTestMode`. Compare `settings/Slash.lua:124-133` (`test` is not a live verb) and `core/LauncherSetup.lua:118-122` (left-click refused).
- **Problem:** The same switch has three doors, and one of them has no disabled gate. Ticking it while disabled silently sets `NS.State.testMode = true`. Nothing shows, and the addon then comes back up in test mode when it is enabled again.
- **Impact:** This is surprising but harmless: session state only, with no SavedVariables write.
- **Reachability:** A player who disables the addon and then ticks Test mode in the panel.

### F-010: `.luacheckrc` declares read-globals that nothing references
`[lint]`

- **Where:** `.luacheckrc:14` `"GameTooltip"` and `.luacheckrc:15` `"C_Spell", "GetAddOnMetadata", "GetSpellInfo"`.
- **Problem:** The file's own header says *"Each entry is a name some file … actually references; a name nothing reads comes off the list."* After the v1.55.0 Compat wiring, these four appear in shipped source only inside comments or as table fields: `NS.Compat.GetSpellInfo` and `C_AddOns.GetAddOnMetadata`. The census was `grep` over `git ls-files 'core/*.lua' 'modules/*.lua' 'settings/*.lua' 'defaults/*.lua' 'locales/*.lua'`, with comment lines dropped.
- **Impact:** A future bare `GetSpellInfo(...)` (the removed global) would lint clean.
- **Reachability:** Lint only.

### F-011: Comment hygiene: misplaced doc blocks, a merged line, and history narration
`[naming]`

- **Misplaced:** `core/Database.lua:508` starts `categoriesDecided`'s doc (*"Whether every FILTERABLE category of `def` already carries…"*) inside a 60-line block that sits above `filterableCategories` at `:539`. Three functions' docs are fused above the wrong one.
- **Merged line:** `modules/Container.lua:414-415`. Two sentences run together on a 150-character line (*"…so step 0 is the one question. A parked container (Park) shows nothing either: its engine may still be"*).
- **History narration:** `core/Database.lua:521` *"CORRECTION (review, after this shipped once already wrong)"*, plus *"fix round 3"* and *"review round 2"* throughout. These record how the code got here, not why it is this way, and that belongs in commit messages.
- **Reachability:** A comment; no runtime effect.

### F-012: Stale documentation citations and a README row that no longer describes the addon
`[docs]`

- **`docs/performance.md:51`** cites `` `core/AuraMaster.lua:107`, `:98` `` for `unitSwap`. The second bracket is at `core/AuraMaster.lua:115` (`local t0 = Perf.on and debugprofilestop()` in `OnUnitPet`).
- **`docs/performance.md:55`** cites `` `modules/Style.lua:772-780` ``. `Style.Element` is at `:774-784`.
- **`README.md:156`** describes 0.1.0 as *"buff, debuff and weapon enchant containers … drawn as bars or icons … and a preview mode"*. The weapon enchant aura type is retired (schema v5), the text style exists, and the UI calls it *Test mode*.
- **Reachability:** Documentation only.

### F-013: A duplicated predicate, and production exports kept only for tests
`[design]`

- **Duplicated predicate:** `core/LifecycleSetup.lua:30-32` `enabledStored()` and `settings/Slash.lua:109-111` `isEnabled()` are the same `NS.GetSetting("enabled") ~= false`, each with its own copy of the "nil is not off" comment.
- **Test-only exports:**
  - `modules/ContainerManager.lua:415-422` `CM.Rename`, described as *"A test seam … no production path does"*.
  - `core/Database.lua:66` `Database.Merge`.
  - `settings/Schema.lua:523` `NS.IsSection`.
- **Dead fallback:** `core/Compat.lua:314` falls back to `_G.GetMouseFocus`, which was removed in 11.0. That is dead on a 120100-only TOC.
- **Reachability:** Maintainers only.

### F-014: Two copies of the frame-pick flow, and a needlessly named picker overlay
`[design]` `[frames]`

- **Two copies:** `settings/Slash.lua:303-317` `runPick` and `settings/Layout.lua:217-232` `pickFrame` each do the same things: resolve the active container, refuse in combat, start `FramePicker`, then make the same two `SetByPath` writes. Only the completion message and panel re-open differ.
- **Named overlay:** `modules/FramePicker.lua:88` names its overlay `"AuraMasterFramePicker"`. Nothing reads that global.
- **Reachability:** Maintainers. The name is one `_G` entry.

---

## Tests: what the evidence says

- **No unfalsifiable case found in the sampled suites.** The samples were `test_disabled.lua`, the `test_containermanager.lua` revive cases and the `perf.lua` assertions. `red under:` notes are pervasive: 1350 lines across 50 test files (`cat tests/*.lua | grep -c 'red under'`). The central disabled assertion reads the mock's registration set by count and by name (`tests/test_disabled.lua:160-181`).
- **Coverage gap under a Medium finding:** F-001's destroy → same-id rebuild path has no case (see F-001).
- **Load lists** are TOC-derived: `tests/run.lua:24` and `tests/perf.lua:48` both call `Loader.tocFiles("AuraMaster.toc")`. `tests/perf.lua` makes no wall-clock assertion, and its `os.clock` use is print-only.
