# AuraMaster — principal review, 2026-10-07

**Verdict: minor issues.** No Critical or High findings. One function is now over the release gate's CCN 15 limit, one source file is 94 lines from the 1500-line cap, and the vendored test kit's inventory total disagrees with the badge rule.

**Resolved scope:** the whole repository (`all`) at `bed2784` on `feat/2026-10-07-review-audit-remediation`, with a clean tree. That covers authored source in `core/`, `defaults/`, `modules/`, `settings/` and `locales/`, plus `tests/` (excluding `_kit/`), `tools/spell-research/`, the TOC, `.pkgmeta` and the lint config. `libs/` and `tests/_kit/` are vendored, and they were reviewed only for upstream findings. Profile: `profile=wow kind=addon` (dev-copilot-profile 2.0.1).

**Standards cross-check:** done against Ka0s WoW Addon Standard **v2.76.1 (2026-10-07)**. `STANDARDS.md` came from `raw.githubusercontent.com/.../master`. The fetch of the section files stalled partway, so they were read from the local `../WowAddonStandards` checkout instead. Its header is also v2.76.1, and `git log master..HEAD` is empty there.

## Measurement run

All runs used `~/.claude/dev-copilot/bin/ka0s-bounded` from the repo root. Output went to a scratch path, nothing was written into the repo, and the tree was confirmed clean afterwards.

| Suite | Result | Command |
|---|---|---|
| luacheck | **pass**: 0 warnings / 0 errors in 171 files | `ka0s-bounded luacheck .` |
| Headless suite | **pass**: 2049 passed, 0 failed, 1 skipped, 2050 total (16 shards) | `ka0s-bounded lua5.1 tests/run.lua` |
| `--list` inventory | **pass**: byte-identical to committed `docs/test-cases.md` once CR is stripped (`diff` empty) | `ka0s-bounded lua5.1 tests/run.lua --list > $scratch/list.md` |
| Offline perf | **ran**: 11 scenarios. `probeOverheadOff` 384.0 B/iter and 5.0 api/iter, `probeAbsent` 384.0 B/iter and 5.0 api/iter, so a dormant bracket allocates nothing extra. `applyPass` 30.0 engine calls per pass over 4 containers. | `ka0s-bounded lua5.1 tests/perf.lua` |
| Complexity (sighted, kit 37) | **pass, non-gating**: **1 warning**, max CCN **18**, 49655 NLOC / 5443 funcs, avg CCN 2.3, no blind files reported | `ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` |
| Warned function | `./modules/Anchors_Snap.lua:892: warning: logCandidates has 21 NLOC, 18 CCN` | sighted shadow (`lizard_sighted.lua shadow`), then `ka0s-bounded lizard -l lua -L 1500 -w .` inside it |
| `make test` | **not applicable**: no root `Makefile` | — |
| Python tooling (`tools/spell-research`) | **pass**: 400 tests OK | `timeout 300 python3 -B -m unittest discover -p 'test_*.py'` (from `tools/spell-research/`) |
| Vendor sync | **pass**: `diff -r libs/LibKa0s/ ../LibKa0s/LibKa0s/` and `diff -r tests/_kit/ ../LibKa0s/testkit/` both empty. LibKa0s is at tag `v1.70.0`, which matches the `CLAUDE.md` provenance line. | as shown |
| Cross-addon class 1 (slash tokens) | **clean**: 22 roots across 11 addons, `uniq -d` empty, and 0 raw `SLASH_*` in loaded source. Scope is each addon's TOC-derived load list. | the two loops in the overlay's *Slash-token distinctness* |
| Cross-addon class 2 (minors) | **clean**: one line, `Bus:2 Compat:1 Core:10 DebugLog:19 Env:1 Item:2 Launcher:5 Lifecycle:3 Media:4 Options:28 Perf:14 Pool:3 Schema:2 Slash:19 Widgets:12` | the class-2 loop |
| Cross-addon class 3 (payload bytes) | **clean**: `diff -rq AbsorbTracker/libs/LibKa0s <each>/libs/LibKa0s` printed nothing for any of the 11 (reference: AbsorbTracker) | the class-3 loop |
| Cross-addon class 4 (`## Interface:`) | **clean**: `120100` in every one of the 11 | the class-4 loop |

The cross-addon baseline in the brief was recorded at v1.56.0. The tag is now v1.70.0, so the gap is a stale brief rather than drift. All four classes are clean at today's figures.

**Committed artifacts that disagree with today's run:**

- `docs/automated-tests/RESULTS.md`. The newest bundle is `20260927-214918`, measured at `b5208f3`, which the runner reports as *173 commit(s) behind HEAD*. It records max CCN **15** and **0** CCN warnings over 4472 funcs, and its test count is 1702. Today's run finds max CCN **18**, **1** warning (`logCandidates`, F-001) over 5443 funcs, and 2049 passing. The record is stale, which is not a compliance problem, because regenerating it is the next release's job.
- `docs/test-cases.md` `**Total** | **2050**` against the README badge `Tests-2049%2F2049_passing`. The inventory is current (diff empty), but its own header says the badge "must agree with it", and with one skip it cannot. See F-003.
- `docs/performance.md`: no disagreement. Its bucket citations still resolve. For example, `modules/Container.lua:576` reads `Perf.Note("applyContainer", ..., "applyPass")` and `modules/Style.lua:853` reads `Perf.Note("styleElement", ...)`. Declared buckets {unitSwap, applyPass, applyContainer, visibilityPass, styleElement, timedScan, emptyPass} equal the set of `Perf.Note("<key>"` keys in authored source.

**Coverage cross-check.** No Critical or High findings, so nothing needed checking against the inventory. Spot checks for unfalsifiable cases: `tests/test_disabled.lua` asserts on the mock's registration set (`:206` "every registration the addon owns is UNREGISTERED, not gated"), and `tests/test_vendor_sync.lua` reports a missing sibling as a SKIP. Neither is vacuous. This was a sample, not a full sweep of the 2050 cases.

**Areas read with no finding.** Disabled stand-down and stand-up: `core/LifecycleSetup.lua`, `core/AuraMaster.lua`, the CM timers and FontPrimer timers (all cancelled in `CM.StopListening`), and a stranded drag (`modules/Anchors_Snap.lua:761` `strandedDrag` and its cancel). Degradation stubs against the members actually called: DebugLog, Perf, Pool, Launcher, Core, Slash. Secret-value gates in `modules/EmptyWatch.lua`. `CM` apply/defer and park/dormant. Schema v12 migration. Perf buckets against brackets. Container show ladder. In each case the code matches its comments and the tests pin it.

---

## Medium

### F-001 — `logCandidates` is at CCN 18, above the release gate's limit of 15 `[complexity]`
- **Where:** `modules/Anchors_Snap.lua:892`, which reads `local function logCandidates(dragged, when, what)`. It was introduced by `cb766da` ("DD-21: log what the snap sees at each drag's start and drop").
- **Problem:** today's sighted run reports `logCandidates has 21 NLOC, 18 CCN`. That is the only function above 15 in the tree. The committed record (`20260927-214918`) predates it and shows max CCN 15 with 0 warnings, so this was not over the limit when last recorded.
- **Impact:** the release gate requires zero functions above CCN 15 (`automated-tests-§3`, *The release gate*), so the next `/dev-copilot:bump-version` will refuse the tag. Most of the count is `and`/`or` defaulting, not tangled control flow: the logging gate, `own ... and ... or "no rect"`, the ineligible/rect pick per target, `what and (...) or ""`, and `#parts > 0 and ... or "none"`.
- **Reachability:** No player is affected at runtime, because the body runs only while debug logging is on (line 893's gate). It blocks the owner's next release tag.
- **Measured:** sighted lizard run, today.

### F-002 — `core/Database.lua` is 1406 lines, and every schema step adds to it `[design]`
- **Where:** `core/Database.lua` (1406 lines). It was 924 lines at the 2026-09-23 review (`0ede122`), so it has grown by 482 lines. Schema steps v11 (`:1125` `function Database.MigrateV11(p)`) and v12 (`:1194` `function Database.MigrateV12(p)`) and their frozen id tables account for most of the recent growth.
- **Problem:** the file is in `layout-§1`'s 1000–1500 on-notice band, and its main source of growth is the migration ladder, which gains a step with each stored-shape change (`toc-file-§2`). It holds three different things: AceDB init, the registry's read helpers, and eleven migration step bodies (`MigrateV2`..`MigrateV12`). Only the runner itself is required to live here (`savedvariables-§1`: "ship a migration runner in `core/Database.lua`").
- **Impact:** one or two more steps of the v11/v12 size will push it over the 1500-line cap, and the split would then have to happen under deadline, inside a schema change.
- **Reachability:** Maintainers only; no runtime effect.
- **Census:** `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | tr '\n' '\0' | xargs -0 wc -l | awk '$2!="total" && $1>1000'`. The scope is authored Lua including `tests/`, excluding vendored code (171 files). It finds **12** files in the band and **0** over the cap. The source files among them are `core/Database.lua` 1406, `defaults/Categories.lua` 1344, `modules/Anchors_Snap.lua` 1126, `settings/Schema.lua` 1057 and `modules/Style.lua` 1024. The test files are `tests/test_anchors_drag.lua` 1490 (see F-004), `test_filtercompiler.lua` 1311, `test_style.lua` 1205, `test_database.lua` 1194, `test_pages_filters.lua` 1184, `test_containermanager.lua` 1074 and `test_style_text.lua` 1023.

### F-003 — `[upstream]` The kit's `--list` Total counts skipped cases, so the inventory cannot match the badge `[tests]`
- **Where:** vendored `tests/_kit/framework.lua:569`, which reads `out(string.format("| **Total** | **%d** |", #tests))`. The header the same renderer writes, `:576`–`:577`, reads "The `## Totals` table below is the **authoritative pass count** — the README test badge and any count quoted in the docs must agree with it." The owning file is `LibKa0s/testkit/framework.lua`, at kit revision 37.
- **Problem:** `#tests` includes cases registered with `Kit.skip`. `testing-§5` says a skip "**MUST NOT** be folded into either the passed count or the total". As a result, AuraMaster's inventory reads **2050** while its correctly computed badge reads **2049/2049**, and the generated header says they must agree.
- **Impact:** the "authoritative pass count" is off by the number of skipped cases in every consumer that has one. Measured today: AuraMaster has 1 skip (Total 2050, badge 2049/2049). AbsorbTracker has 1 (Total 877, badge 876/876). KickCD has 1 (Total 1303, badge 1302/1302). Commands: `grep -c '(skipped:' docs/test-cases.md`, `tail -1 docs/test-cases.md` and `grep -o 'Tests-[0-9]*%2F[0-9]*' README.md` in each repo. AuraMaster's skip is the kit's own diagnostics-contract opt-out case (`docs/test-cases.md:2334`).
- **Reachability:** Only the test inventory. The shipped addon is correct, so severity is capped at Medium.
- **Fix direction:** fix it upstream in LibKa0s `testkit/framework.lua`, bump `Kit.VERSION`, and re-vendor the whole `tests/_kit/` folder into every consumer as its own commit, regenerating `docs/test-cases.md` in that commit. **Do not edit `tests/_kit/` here.**

## Low

### F-004 — `tests/test_anchors_drag.lua` is 10 lines below the 1500-line cap `[design]`
- **Where:** `tests/test_anchors_drag.lua` (1490 lines; same census as F-002).
- **Problem:** `layout-§1` caps authored test files too. The next drag case added here will breach the cap.
- **Impact:** a breach would have to be split during unrelated feature work.
- **Reachability:** Maintainers only; no runtime effect.

### F-005 — A container named with a bare number cannot be reached by name `[ux]`
- **Where:** `settings/Slash.lua:169`–`:170`, which read `local id = tonumber(arg)` / `if id then return NS.Database.FindContainer(id) end`. The name row's validation (`settings/Containers.lua:59`, `validate = function(v) return type(v) == "string" and v:match("%S") ~= nil end`) accepts names like `"3"`.
- **Problem:** `/am select <arg>` and `/am delete <arg>` treat any numeric argument as an id, so a container named `3` can never be matched by name. Worse, `/am delete 3` deletes container **#3**, which is a different container from the one called "3". `docs/slash-dispatch.md:52` documents these verbs as taking "id-or-name" without mentioning the precedence.
- **Impact:** the wrong container is selected or deleted. Delete is destructive. AceDB keeps no undo, although profile copies exist.
- **Reachability:** Only a player who gives a container a bare-number name and then addresses it by that name on the CLI.

### F-006 — Translated labels are lowercased with byte-wise `string.lower` `[locale]`
- **Where:** `settings/OptionsSetup.lua:419`–`:420`, which read `L[C.AURA_TYPE_LABELS[...] ...]:lower(),` / `L[C.STYLE_LABELS[...] ...]:lower())`.
- **Problem:** this changes the casing of a translated string after translation. `string.lower` is byte-wise, so non-ASCII capitals such as `Ü` are left unchanged, and some locales (deDE) capitalize nouns on purpose.
- **Impact:** once a non-enUS locale ships, the container picker would mix cases or decapitalize German nouns.
- **Reachability:** No effect today, because `locales/` holds only `enUS.lua`. It becomes real the day a second locale lands.

### F-007 — The help row and container listing punctuation differ from the standard and the docs `[ux]`
- **Where:** `settings/Slash.lua:87` reads `{"debug", L["Toggle the debug console - on/off enable or disable logging"],`. The standard's row (`slash-commands.md:72`) reads "Toggle the debug console — `on`/`off` enable/disable logging", and every other AuraMaster help row uses an em dash. `settings/Slash.lua:192` (`L["#%s - %s - %s - %s"]`) prints `#id - unit - type - style`, while `docs/slash-dispatch.md:51` documents `name #id · unit · type · style`.
- **Problem:** the separators drift between the help text, the standard's template and the docs.
- **Impact:** cosmetic only, and the docs misdescribe the actual output.
- **Reachability:** Any player who types `/am` or `/am containers`; nothing breaks.

---

### Upstream findings (grouped)

| ID | Owning repo / file | Remediation |
|---|---|---|
| F-003 | LibKa0s, `testkit/framework.lua` (`renderTotals`) | Fix upstream, bump `Kit.VERSION`, then re-vendor `tests/_kit/` into all 11 addons (and LibKa0s's own inventory). **Not a local edit.** |

### Checked and not a finding

- **`.claude/` missing from `.pkgmeta`'s `ignore` list.** The packager skips dotfiles by default: BigWigsMods `release.sh` says "Dotfiles and any files matching the ignore pattern are skipped." Nothing ships.
- **Stale `softCC` mentions in `modules/FilterCompiler.lua:98` and `:714`.** These describe what issue #11 did at the time, so they are accurate history.
- **Pool degradation stub reimplementing Acquire/ReleaseAll** (`core/PoolSetup.lua:17`). This is deliberate and documented, and the alternative would leak on the degraded path.
