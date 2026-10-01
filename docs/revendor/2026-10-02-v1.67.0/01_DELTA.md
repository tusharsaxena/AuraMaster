# 01 - Delta: LibKa0s v1.66.0 -> v1.67.0

Run non-interactively as item `CA-AM-RV` of the 2026-10-02 LibKa0s census adoption
(`Ka0sAddonsCommonTasks/docs/2026-10-02-LIBKA0S_CENSUS_ADOPTION/`), on branch
`feat/2026-10-02-libka0s-census-adoption`, on 2026-10-02. Steps 2-4 of `revendor-libka0s --tag v1.67.0`:
resolve the tag, read the delta, copy both payloads whole, roll the provenance line. The run's design
(`01_DESIGN.md` D1, D2) already assigns every new surface to an item, so no interview was held
(`02_CANDIDATES.md`). The tag is local to the LibKa0s checkout; it has not been pushed.

## Source

```sh
git -C ../LibKa0s rev-parse --short 'v1.67.0^{commit}'     # 0bccf4c (CA-LK-03's release record)
git -C ../LibKa0s rev-parse --short HEAD                   # 0bccf4c, tree clean
git -C ../LibKa0s archive v1.67.0 LibKa0s testkit | tar -x -C <scratch>/new
```

The payload comes from the tag export, never the working tree.

## 3a. Claimed version, and the base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 36:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.66.0 (MIT).
git -C ../LibKa0s archive v1.66.0 LibKa0s testkit | tar -x -C <scratch>/old
diff -rq <scratch>/old/LibKa0s libs/LibKa0s && diff -rq <scratch>/old/testkit tests/_kit && echo payload-matches
# payload-matches   (byte-identical, without --strip-trailing-cr)
```

The base is **v1.66.0**, and the newest single-tag bundle is `2026-10-01-v1.66.0`, so no tag went
unrecorded and no span bundle is owed.

```sh
git -C ../LibKa0s log --oneline v1.66.0..v1.67.0        # 5 commits: GI-LK-13's census, CA-LK-01 .. CA-LK-03
git -C ../LibKa0s diff --stat v1.66.0 v1.67.0 -- LibKa0s testkit
# 3 files changed, 125 insertions(+), 36 deletions(-)
```

## 3b/3c. Actual version, and the per-file minor delta

| File | Before (v1.66.0) | After (v1.67.0) | Lines after |
|---|---|---|---|
| `Core.lua` | `MINOR` 9 | **10** | 789 |
| `Options.lua` | `MINOR` 27 | **28** | 1288 |
| `OptionsIdList.lua` | `IDLIST_MINOR` 2 | **3** | 1246 |

Every other file keeps its minor: Env 1, Compat 1, Lifecycle 3, Bus 2, Schema 2, Pool 3, Item 2,
Media 4, Widgets 12, WidgetsReorder 1, WidgetsDragHandle 3, DebugLog 19, DebugLogDiagnostics 2,
DebugLogGates 1, Slash 19, SlashParse 1, Launcher 5, OptionsRegistry 2, OptionsIds 2, OptionsWidgets 34,
OptionsTabs 8, OptionsCombat 1, OptionsCompose 7, OptionsScroll 4, OptionsNav 2, Perf 14, PerfSampler 1,
PerfCommands 1, PerfPanel 6. The Options key moves 27.2.34.2.2.8.1.7.4.2 -> **28.2.34.2.3.8.1.7.4.2**.
No `NEEDS_*` floor rises, no major is added, no file is added or removed: still fifteen majors across
thirty-two files. No cross-major skew before or after.

## 3d. Both diffs, before the copy

```sh
diff -rq <scratch>/new/LibKa0s libs/LibKa0s     # Core.lua, Options.lua, OptionsIdList.lua differ
diff -rq <scratch>/new/testkit tests/_kit       # nothing
```

Nothing is `Only in` the addon, so the whole-folder copy deletes nothing. The vendored files keep the
repo's convention exactly as `GI-AM-RV` did: the tag's bytes, CRLF on disk, the index normalized by
`.gitattributes`. After the copy both `diff -r` runs print nothing, with or without
`--strip-trailing-cr`.

## 3e. Consumption map

| Major | Lookup site | Moved |
|---|---|---|
| Core | `core/CoreSetup.lua:16` | 9 -> 10. AuraMaster calls no `MakeResizable` itself; the library's own console, copy window and perf panel call it with none of the new fields, so nothing it draws moves |
| Options | `settings/OptionsSetup.lua:98` | 27 -> 28, IdList 2 -> 3. The Filters and General pages draw `O.IdList` entries that carry `help` (`settings/Filters.lua`, `settings/GeneralSpells.lua`) |

## 3f. Kit revision, and the pairing rule

```sh
grep -n 'Kit.VERSION =' <scratch>/new/testkit/framework.lua tests/_kit/framework.lua   # 35 and 35
```

The kit stays at revision **35**: `testkit/` is unchanged between the two tags. Nothing to wire in
`tests/run.lua`.

## 3g. Contract delta

Read against the LibKa0s v1.67.0 `CHANGELOG.md` block, `docs/api/Core/version-10-docs.md` and
`docs/api/Options/version-28.2.34.2.3.8.1.7.4.2-docs.md`.

### Blockers

**None.** The Core fields are opt-in. The IdList change sits under an unchanged surface and was
checked against this addon:

- `settings/OptionsSetup.lua` passes no `addonName` on the Options descriptor (its first vararg is
  discarded, `local _, NS = ...`). The help marks therefore drew the client glyph on v1.66.0 and still
  do on v1.67.0: nothing visible moves. What is new: with logging on, each helped id list now writes
  one `[Cfg] help art: no addonName on the Options descriptor; drawing the client glyph` line.
  `CA-AM-NM` passes the name and retires the line.

### Owed by the re-vendor commit

- **Provenance.** `CLAUDE.md`, `DEPENDENCIES.md` (the vendor-sync paragraph, twice) and
  `docs/module-map.md` (the library row) name the vendored tag.
- **`docs/debug.md`**: the `Cfg` row names Options 28 and OptionsIdList 3, and lists the new library line.
- `docs/test-cases.md` regenerated (unchanged) and the README badge checked (unchanged, 1788).
