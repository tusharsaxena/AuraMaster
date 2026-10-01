# 01 - Delta: LibKa0s v1.65.0 -> v1.66.0

Run non-interactively as item `GI-AM-RV` of the 2026-10-01 GitHub issue pass
(`Ka0sAddonsCommonTasks/docs/2026-10-01-GITHUB_ISSUE_PASS/`, spec section S4), on branch
`feat/2026-10-01-github-issue-pass`, on 2026-10-01. Steps 2-4 of `revendor-libka0s --tag v1.66.0`:
resolve the tag, read the delta, copy both payloads whole, roll the provenance line. The run's spec
says adoption candidates are **not** interviewed this cycle: they are listed in `02_CANDIDATES.md`
for the LibKa0s consumer census (`GI-LK-13`), and no decline issue is filed (`03_DECISIONS.md`). The
tag is local to the LibKa0s checkout; it has not been pushed.

## Source

```sh
git -C ../LibKa0s rev-parse --short 'v1.66.0^{commit}'     # e4c5ef7 (GI-LK-12's release record)
git -C ../LibKa0s archive v1.66.0 LibKa0s testkit | tar -x -C <scratch>/
```

The payload comes from the tag, never the working tree.

## 3a. Claimed version, and the base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 36:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.65.0 (MIT).
git -C ../LibKa0s archive v1.65.0 LibKa0s testkit | tar -x -C <scratch>/old
diff -rq <scratch>/old/LibKa0s libs/LibKa0s && diff -rq <scratch>/old/testkit tests/_kit && echo payload-matches
# payload-matches
```

The base is **v1.65.0**. The store's newest single-tag bundle is `2026-09-29-v1.63.0`: v1.64.0 and
v1.65.0 were vendored with no bundle, and are recorded by the span bundle written beside this one,
`docs/revendor/2026-10-01-v1.64.0-v1.65.0/` (Step 3h). No frozen bundle misstates its base.

```sh
git -C ../LibKa0s log --oneline v1.65.0..v1.66.0        # 24 commits, GI-LK-01 .. GI-LK-12 and their R fixes
git -C ../LibKa0s diff --stat v1.65.0 v1.66.0 -- LibKa0s testkit
# 20 files changed, 2693 insertions(+), 1651 deletions(-)
```

## 3b/3c. Actual version, and the per-file minor delta

The file list from the tag's `LibKa0s/LibKa0s.xml`, each file's constant by the skill's grep:

| File | Before (v1.65.0) | After (v1.66.0) | Lines after |
|---|---|---|---|
| `Widgets.lua` | `MINOR` 11 | **12** | 655 |
| `WidgetsReorder.lua` | (new) | `REORDER_MINOR` **1** | 680 |
| `DebugLog.lua` | `MINOR` 18 | **19** | 999 |
| `Slash.lua` | `MINOR` 18 | **19** | 877 |
| `SlashParse.lua` | (new) | `PARSE_MINOR` **1** | 195 |
| `OptionsWidgets.lua` | `WIDGETS_MINOR` 33 | **34** | 1444 |
| `OptionsTabs.lua` | `TABS_MINOR` 7 | **8** | 1349 |
| `Perf.lua` | `MINOR` 13 | **14** | 975 |
| `PerfSampler.lua` | (new) | `SAMPLER_MINOR` **1** | 418 |
| `PerfCommands.lua` | (new) | `COMMANDS_MINOR` **1** | 230 |

Every other file keeps its minor: Core 9, Env 1, Compat 1, Lifecycle 3, Bus 2, Schema 2, Pool 3,
Item 2, Media 4, WidgetsDragHandle 3, DebugLogDiagnostics 2, DebugLogGates 1, Launcher 5, Options 27,
OptionsRegistry 2, OptionsIds 2, OptionsIdList 2, OptionsCombat 1, OptionsCompose 7, OptionsScroll 4,
OptionsNav 2, PerfPanel 6. No `NEEDS_*` floor rises and no major is added; four files are added, so
the payload is fifteen majors across thirty-two files. No cross-major skew before or after.

`AuraMaster.toc` loads the library through `libs\LibKa0s\LibKa0s.xml` alone, and `tests/run.lua`
loads it in `LibKa0s.xml` order, so the four new files need no TOC or harness row.

## 3d. Both diffs, before the copy

```sh
diff -rq <scratch>/LibKa0s libs/LibKa0s     # 7 files differ; Only in the tag: PerfCommands.lua, PerfSampler.lua, SlashParse.lua, WidgetsReorder.lua
diff -rq <scratch>/testkit tests/_kit       # 7 files differ; Only in the tag: lizard_sighted.lua, test_lizard_sighted.lua
```

The `--strip-trailing-cr` runs print the same lines, so there is no line-ending drift. Nothing is
`Only in` the addon, so the whole-folder copy deletes nothing. After the copy both `diff -r` runs
print nothing.

## 3e. Consumption map

```sh
git grep -n 'LibStub("LibKa0s-[A-Za-z]*-1.0"' -- '*.lua' ':!libs' ':!tests'
```

Fourteen majors are bound by name (`docs/module-map.md`). The ones whose minor moved in this range:

| Major | Lookup site | Moved |
|---|---|---|
| Widgets | `modules/Anchors.lua:449` | 11 -> 12 (`ReorderList` peeled; AuraMaster calls `DragHandle` only) |
| DebugLog | `core/DebugLogSetup.lua:13` | 18 -> 19 (`lib:New`'s field checks moved to helpers, behavior unchanged) |
| Slash | `settings/Slash.lua:26` | 18 -> 19 (+ SlashParse 1) |
| Options | `settings/OptionsSetup.lua:98` | Widgets 33 -> 34, Tabs 7 -> 8 |
| Perf | `core/PerfSetup.lua:14` | 13 -> 14 (+ PerfSampler 1, PerfCommands 1) |

## 3f. Kit revision, and the pairing rule

```sh
grep -n 'Kit.VERSION =' <scratch>/testkit/framework.lua tests/_kit/framework.lua   # 35 and 34
```

The kit moves to revision **35** in the same commit as the library, as the pairing rule requires.
It adds `lizard_sighted.lua` and the fifth kit suite `test_lizard_sighted.lua`, which the
inventory gate refuses to leave unwired: `tests/run.lua` declares
`{ name = "test_lizard_sighted", dir = "tests/_kit/" }` in the re-vendor commit.

## 3g. Contract delta

Read against the LibKa0s v1.66.0 `CHANGELOG.md` block and `docs/api/testkit/version-35-docs.md`.

### Blockers

**None.** Every new field is opt-in and no member, string or floor moves. The two behavior changes
under an unchanged surface were checked against this addon:

- `O.RenderGrid`: a wide item whose `make` raised, or answered exactly `false`, is now released with
  no spacer. AuraMaster's cells (`settings/Containers.lua:165`/`:185`, `settings/GeneralSpells.lua:529`
  /`:596`, `settings/GeneralUserCategories.lua:360`) never answer `false`, so nothing it draws moves.
- Slash minor 19 hands the host `L` to the parse refusals. `settings/Slash.lua`'s `L` carries none of
  `ERR_BOOL`, `ERR_NUMBER`, `ERR_STRING`, `ERR_ALLOWED`, `ERR_COLOR`, `ERR_TYPE` or `NONE`, so the
  library's own wording still prints.

### Owed by the re-vendor commit

- **The kit's fifth suite**, wired in `tests/run.lua` (above).
- **The complexity command.** `docs/testing.md` and `DEPENDENCIES.md` quoted the raw
  `lizard -l lua -x ...` command, the blind one; both now name
  `bash tests/_kit/run-automated-tests.sh --suite complexity`. `CLAUDE.md`'s green-gate line quotes no
  lizard command.
- **Provenance.** `CLAUDE.md`, `DEPENDENCIES.md` (the vendor-sync paragraph, twice) and
  `docs/module-map.md` (the library row) name the vendored tag. `DEPENDENCIES.md`'s line citations
  into `tests/_kit/run-automated-tests.sh` move with the runner (`:167` -> `:168`, and so on).
- `docs/test-cases.md` regenerated and the README badge rolled for the eight new kit cases.
