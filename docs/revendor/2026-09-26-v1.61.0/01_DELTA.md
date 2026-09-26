# 01 - Delta: LibKa0s v1.60.0 -> v1.61.0

Run non-interactively as item `SR-AM-01` of the 2026-09-26 settings redesign (#6)
(`Ka0sAddonsCommonTasks/docs/2026-09-26-SETTINGS_REDESIGN/`), on branch
`feat/2026-09-26-settings-redesign` (the spec at `3fdc667`), on 2026-09-26. Steps 2-4 of
`revendor-libka0s --tag v1.61.0`: resolve the tag, read the delta, copy both payloads whole, roll the
provenance line. The plan has already decided the one candidate, so the interview is answered from the
plan (`03_DECISIONS.md`) and no decline issue is filed. The tag is local to the LibKa0s checkout; it
has not been pushed.

## Source

```sh
git -C ../LibKa0s rev-parse --short 'v1.61.0^{}'          # c6183bd (SR-LK-03's second commit)
git -C ../LibKa0s archive v1.61.0 LibKa0s testkit | tar -x -C <scratch>/
```

The payload comes from the tag, never the working tree.

## 3a. Claimed version, and the base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 36:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.60.0 (MIT).
```

The base is **v1.60.0**, and the newest bundle (`2026-09-26-v1.60.0`) records it.

```sh
git -C ../LibKa0s log --oneline v1.60.0..v1.61.0
# c6183bd SR-LK-03: v1.61.0 release run, analysis and gate line
# 7cbe02c SR-LK-03: date v1.61.0 and roll the release pointers
# 9394dff SR-LK-02: recount for OptionsNav.lua: six Options files, twenty-three in all
# f88730e SR-LK-01R: NavRail re-anchors a live scroll on a bannerless page; ...
# 2cd217b SR-LK-01: OptionsNav minor 1, the nav rail; Options 25 and OptionsTabs 5 read its one inset
```

## 3b/3c. Actual version, and the per-file minor delta

```sh
grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/Options*.lua | sort   # before
grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' <scratch>/LibKa0s/Options*.lua | sort
```

| File | Before (v1.60.0) | After (v1.61.0) |
|---|---|---|
| `Options.lua` | `MINOR` 24 | `MINOR` **25** |
| `OptionsTabs.lua` | `TABS_MINOR` 4 | `TABS_MINOR` **5** |
| `OptionsNav.lua` | absent | `NAV_MINOR` **1** (new file, a sixth file of `LibKa0s-Options-1.0`) |

`LibKa0s-Options-1.0` moves from key 24.31.4.7.4 to **25.31.5.7.4.1**. Every other file keeps its
minor (Core 8, Env 1, Compat 1, Lifecycle 2, Bus 2, Schema 2, Pool 3, Item 2, Media 4, Widgets 10 +
WidgetsDragHandle 3, DebugLog 14 + DebugLogDiagnostics 1, Slash 16, Launcher 4, OptionsWidgets 31,
OptionsCompose 7, OptionsScroll 4, Perf 13, PerfPanel 5), as the LibKa0s v1.61.0 `CHANGELOG.md` block
states. The tag's `LibKa0s.xml` gains `OptionsNav.lua` after `OptionsScroll.lua`; the host's
`tests/run.lua` derives its library files from that XML, so no load list is typed by hand. No
`NEEDS_*` floor rises and no major is added. No cross-major skew before or after.

## 3d. Both diffs, before the copy

```sh
diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s
# LibKa0s.xml, Options.lua, OptionsTabs.lua differ; Only in <scratch>/LibKa0s: OptionsNav.lua
diff -rq                     <scratch>/LibKa0s libs/LibKa0s   # the same four lines
diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit     # no output
diff -rq                     <scratch>/testkit tests/_kit     # no output
```

Content and bytes agree, so there is no line-ending drift. Nothing is `Only in` the addon, so the
copy deletes nothing. The kit is identical, so `tests/_kit/` does not change.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-Options-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
# settings/OptionsSetup.lua:99
```

| Major | Lookup site | Minor moved in this range |
|---|---|---|
| Options | `settings/OptionsSetup.lua:99` | Options 24 -> 25, OptionsTabs 4 -> 5, OptionsNav new at 1 |

AuraMaster calls no `NavRail` yet; SR-AM-03 adopts it.

## 3f. Kit revision, and the pairing rule

```sh
grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua   # 27 and 27
```

The kit stays at **27**. `tests/test_vendor_sync.lua` compares both payloads against the tag the
provenance line names.

## 3g. Contract delta

Read against the LibKa0s v1.61.0 `CHANGELOG.md` block ("What a consumer owes on re-vendoring
v1.61.0").

### Blockers

**None.** With no rail drawn, `lib.__railInset(ctx)` answers 0, so the strip's placement, the content
panel's left edge and the scroll's left anchor compute v1.60.0's numbers on every AuraMaster page.

### Owed by the re-vendor commit (not a blocker, but red without it)

- **Surface parity.** `tests/test_surface_parity.lua` pins the library-absent Options stub in
  `settings/OptionsSetup.lua` against the live instance by name. The live instance gains `NavRail`,
  so the stub's no-op list gains `"NavRail"`. The `__`-prefixed seams (`__railTop`, `__railEntryY`,
  `__navArtHeight`, `__resetNavArtHeight`, `__railInset`) are outside parity.
