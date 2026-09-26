# 01 - Delta: LibKa0s v1.61.0 -> v1.62.0

Run non-interactively as item `AM-ATS-RV` of the 2026-09-26 automated-tests sweep
(`Ka0sAddonsCommonTasks/docs/2026-09-26-AUTOMATED_TESTS_SWEEP/`, traces `ATS-20` and `ATS-21`), on
branch `feat/2026-09-26-automated-tests-sweep`, on 2026-09-26. Steps 2-4 of
`revendor-libka0s --tag v1.62.0`: resolve the tag, read the delta, copy both payloads whole, roll the
provenance line. The sweep plan puts the candidate-adoption interview out of scope, so this run
records no adoption and files no decline issue (`03_DECISIONS.md`). The tag is local to the LibKa0s
checkout; it has not been pushed.

## Source

```sh
git -C ../LibKa0s rev-parse --short 'v1.62.0^{}'          # 5dc9f5d (LK-ATS-10's second commit)
git -C ../LibKa0s archive v1.62.0 LibKa0s testkit | tar -x -C <scratch>/
```

The payload comes from the tag, never the working tree.

## 3a. Claimed version, and the base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 36:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.61.0 (MIT).
```

The base is **v1.61.0**, and the newest bundle (`2026-09-26-v1.61.0`) records it.

```sh
git -C ../LibKa0s log --oneline v1.61.0..v1.62.0
# 5dc9f5d LK-ATS-10: v1.62.0 release run, analysis, dispositions and gate line
# e636e9d LK-ATS-10: date v1.62.0 and roll the release pointers
# 17d72bc LK-ATS-09: The runner's band table leaves out Kit.layoutCap.exempt's generated files (kit revision 31)
# a2a53aa LK-ATS-08: The runner prints None. under an empty watch-list table in RESULTS.md (kit revision 30)
# b515211 LK-ATS-07: Split testkit/test_prose.lua below 1000 into prose_coverage.lua and prose_selftests.lua (kit revision 29)
# db458f8 LK-ATS-06: Split test_widgets, test_slash, test_options_tabs and test_options_idsuggest below 1000 on case seams
# fa2fa13 LK-ATS-05: Peel the suite inventory out of testkit/framework.lua into testkit/inventory.lua (kit revision 28)
# 2061be6 LK-ATS-04: Peel the page registry and its combat park out of Options.lua into OptionsRegistry.lua
# fad47e9 LK-ATS-03: Peel the combat lock's page chrome out of OptionsTabs.lua into OptionsCombat.lua
# 389b92f LK-ATS-02R: Retire the stale over-the-cap claims about test_options_widgets.lua in suite headers
# 304c2d8 LK-ATS-02: Split the rest of test_options_widgets.lua into choicegrid, flow and landing suites
# 3d39ae7 LK-ATS-01: Peel the id surface out of OptionsWidgets.lua into OptionsIds.lua and OptionsIdList.lua
# adb8d24 LK-ATS-00: Record the 2026-09-26 automated-tests sweep run (20260926-160448)
# cf38896 Merge feat/2026-09-26-settings-redesign: v1.61.0, OptionsNav minor 1 ...
```

## 3b/3c. Actual version, and the per-file minor delta

```sh
grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/Options*.lua | sort   # before and after
```

| File | Before (v1.61.0) | After (v1.62.0) | Lines after |
|---|---|---|---|
| `Options.lua` | `MINOR` 25 | `MINOR` **26** | 1261 |
| `OptionsWidgets.lua` | `WIDGETS_MINOR` 31 | `WIDGETS_MINOR` **32** | 1422 |
| `OptionsTabs.lua` | `TABS_MINOR` 5 | `TABS_MINOR` **6** | 1293 |
| `OptionsRegistry.lua` | absent | `REGISTRY_MINOR` **1** (new) | 263 |
| `OptionsIds.lua` | absent | `IDS_MINOR` **1** (new) | 1358 |
| `OptionsIdList.lua` | absent | `IDLIST_MINOR` **1** (new) | 1193 |
| `OptionsCombat.lua` | absent | `COMBAT_MINOR` **1** (new) | 249 |

`LibKa0s-Options-1.0` moves from key 25.31.5.7.4.1 to **26.1.32.1.1.6.1.7.4.1**, ten files. Every
other file keeps its minor (Core 8, Env 1, Compat 1, Lifecycle 2, Bus 2, Schema 2, Pool 3, Item 2,
Media 4, Widgets 10 + WidgetsDragHandle 3, DebugLog 14 + DebugLogDiagnostics 1, Slash 16, Launcher 4,
OptionsCompose 7, OptionsScroll 4, OptionsNav 1, Perf 13 + PerfPanel 5), as the LibKa0s v1.62.0
`CHANGELOG.md` block states. The library is fifteen majors across twenty-seven files.

The tag's `LibKa0s.xml` gains four rows: `OptionsRegistry.lua` after `Options.lua`, `OptionsIds.lua`
and `OptionsIdList.lua` after `OptionsWidgets.lua`, and `OptionsCombat.lua` after `OptionsTabs.lua`.
The host's `tests/run.lua` derives its library files from that XML, and the TOC loads the XML, so no
load list is typed by hand. No `NEEDS_*` floor rises and no major is added. No cross-major skew
before or after.

## 3d. Both diffs, before the copy

```sh
diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s
# LibKa0s.xml, Options.lua, OptionsTabs.lua, OptionsWidgets.lua differ;
# Only in <scratch>/LibKa0s: OptionsCombat.lua, OptionsIdList.lua, OptionsIds.lua, OptionsRegistry.lua
diff -rq                     <scratch>/LibKa0s libs/LibKa0s   # the same eight lines
diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit
# README.md, framework.lua, run-automated-tests.sh, test_layout_cap.lua, test_prose.lua differ;
# Only in <scratch>/testkit: inventory.lua, prose_coverage.lua, prose_selftests.lua
diff -rq                     <scratch>/testkit tests/_kit     # the same eight lines
```

Content and bytes agree, so there is no line-ending drift (`run-automated-tests.sh` stays LF, its
shebang carve-out). Nothing is `Only in` the addon, so the whole-folder copy deletes nothing. After
the copy both `diff -rq` runs print nothing.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-Options-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
# settings/OptionsSetup.lua:54
```

| Major | Lookup site | Minor moved in this range |
|---|---|---|
| Options | `settings/OptionsSetup.lua:54` | Options 25 -> 26, OptionsWidgets 31 -> 32, OptionsTabs 5 -> 6; OptionsRegistry, OptionsIds, OptionsIdList, OptionsCombat new at 1 |

Every member AuraMaster calls (`RegisterOptionsPage`, `CreateOptionsPanel`, `OpenOptionsPanel`,
`IdList`, `IdInput`, `ResolveId`, `UnnamedCandidates` and the rest) is still on the instance, in the
same order, attached from its new file.

## 3f. Kit revision, and the pairing rule

```sh
grep -n 'Kit.VERSION =' <scratch>/testkit/framework.lua tests/_kit/framework.lua   # 31 and 27
```

The kit moves **27 -> 31** (28 the suite inventory peel, 29 the prose gate peel, 30 `None.` under an
empty watch-list table for `ATS-20`, 31 generated files out of the band table for `ATS-21`).
`tests/test_vendor_sync.lua` compares both payloads against the tag the provenance line names, and
passed against `v1.62.0`.

## 3g. Contract delta

Read against the LibKa0s v1.62.0 `CHANGELOG.md` block: "A consumer re-vendors both payloads whole,
`libs/LibKa0s/` and `tests/_kit/`, rolls its provenance line, and changes nothing else."

### Blockers

**None.** No public member, descriptor field, row field, kit case, mock or `manifest.json` field
changes. The four new files are peels that attach the same members to the same instance in the same
order.

### Owed by the re-vendor commit

- **Surface parity.** `tests/test_surface_parity.lua` pins the library-absent Options stub in
  `settings/OptionsSetup.lua` against the live instance by name. No public member was added or
  removed, and the new seams (`__AttachIds`, `__AttachIdList`, `__AttachRegistry`, `__AttachCombat`
  and their minors) are `__`-prefixed, outside parity. The stub needs no change, and the case passed
  after the copy.
- **Kit inventory.** The kit's new files (`inventory.lua`, `prose_coverage.lua`,
  `prose_selftests.lua`) are loaded by the kit from its own folder and are not `test_*` suites, so
  `tests/run.lua`'s suite list does not change and the case count is unchanged.
- **Provenance.** `CLAUDE.md`, `DEPENDENCIES.md` (the vendor-sync paragraph, twice) and
  `docs/module-map.md` (the library row) name the vendored tag.
