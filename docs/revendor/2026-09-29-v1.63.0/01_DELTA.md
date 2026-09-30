# 01 - Delta: LibKa0s v1.62.0 -> v1.63.0

Run non-interactively as item `SP-AM-02` of the 2026-09-29 smoke-rework and profile-verb run
(`Ka0sAddonsCommonTasks/docs/2026-09-29-SMOKE_REWORK_AND_PROFILE_VERB/`, spec section S3), on branch
`feat/2026-09-29-smoke-and-profile`, on 2026-09-29. Steps 2-4 of `revendor-libka0s --tag v1.63.0`:
resolve the tag, read the delta, copy both payloads whole, roll the provenance line. The run's spec
names the one surface this addon adopts (the Slash minor 17 profile verb, in the item's second
commit), so no candidate interview was held and no decline issue is filed (`03_DECISIONS.md`). The
tag is local to the LibKa0s checkout; it has not been pushed.

## Source

```sh
git -C ../LibKa0s rev-parse --short 'v1.63.0^{}'          # dd7a774 (SP-LIB-01R's final commit)
git -C ../LibKa0s archive v1.63.0 LibKa0s testkit | tar -x -C <scratch>/
```

The payload comes from the tag, never the working tree.

## 3a. Claimed version, and the base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 36:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.62.0 (MIT).
```

The base is **v1.62.0**, and the newest bundle (`2026-09-26-v1.62.0`) records it.

```sh
git -C ../LibKa0s log --oneline v1.62.0..v1.63.0
# dd7a774 SP-LIB-01R: v1.63.0 release run re-taken on the final tree, so the tag has a record to sit on
# ac61f37 SP-LIB-01R: pin the profile list's case-insensitive order with a name byte order would move
# 5568e7a SP-LIB-01R: v1.63.0 release run re-taken after the doc fix
# 626aec0 SP-LIB-01R: v1.63.0 migration docs name both stub members and the real parity mechanism
# c53705c SP-LIB-01: v1.63.0 release run, analysis and gate line
# 576576e SP-LIB-01: Slash minor 17, the shared profile verb (CliProfile, ProfileSwitch, ProfileNames)
# 40886b6 README: plain-language pass for readers
# 8fd7498 Merge feat/2026-09-26-automated-tests-sweep: ...
# 95e6457 LK-ATS-SDR: Correct stale comment citations (owner-approved sync-docs follow-up)
# 662da79 LK-ATS-SD: Sync docs to the tree after the automated-tests sweep
# d70c0c1 LK-ATS-99: Final automated-tests sweep run (20260926-193105)
```

## 3b/3c. Actual version, and the per-file minor delta

```sh
grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/Slash.lua   # before and after
```

| File | Before (v1.62.0) | After (v1.63.0) | Lines after |
|---|---|---|---|
| `Slash.lua` | `MINOR` 16 | `MINOR` **17** | 995 (866 before) |

Every other file keeps its minor, as the LibKa0s v1.63.0 `CHANGELOG.md` block states: Core 8, Env 1,
Compat 1, Lifecycle 2, Bus 2, Schema 2, Pool 3, Item 2, Media 4, Widgets 10 + WidgetsDragHandle 3,
DebugLog 14 + DebugLogDiagnostics 1, Launcher 4, Options key 26.1.32.1.1.6.1.7.4.1, Perf 13 +
PerfPanel 5. `LibKa0s.xml` is unchanged. No `NEEDS_*` floor rises, no major is added, and no file is
added or removed: fifteen majors across twenty-seven files. No cross-major skew before or after.

## 3d. Both diffs, before the copy

```sh
diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s     # Slash.lua differs
diff -rq                     <scratch>/LibKa0s libs/LibKa0s     # the same line
diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit       # nothing
diff -rq                     <scratch>/testkit tests/_kit       # nothing
```

Content and bytes agree, so there is no line-ending drift. Nothing is `Only in` the addon, so the
whole-folder copy deletes nothing. After the copy both `diff -rq` runs print nothing.

## 3e. Consumption map

```sh
git grep -n 'LibStub("LibKa0s-Slash-1.0"' -- '*.lua' ':!libs' ':!tests'
# settings/Slash.lua:26
```

| Major | Lookup site | Minor moved in this range |
|---|---|---|
| Slash | `settings/Slash.lua:26` | Slash 16 -> 17 |

Every member AuraMaster calls on the dispatcher (`OnSlash`, `PrintHelp`, `LandingRows`, `CliList`,
`CliGet`, `CliSet`, `CliReset`, `DisabledLine`, `SetRowAnnotator`) is unchanged. Minor 17 adds the
descriptor field `profiles`, the instance members `CliProfile` and `ProfileSwitch`, the lib-level
`ProfileNames`, and nine `PROFILE_*` strings in `lib.STRINGS`. `lib.LIVE_VERBS` is unchanged.

## 3f. Kit revision, and the pairing rule

```sh
grep -n 'Kit.VERSION =' <scratch>/testkit/framework.lua tests/_kit/framework.lua   # 31 and 31
```

The kit stays at revision **31**; its payload is byte-identical to v1.62.0's.
`tests/test_vendor_sync.lua` compares both payloads against the tag the provenance line names, and
passed against `v1.63.0`.

## 3g. Contract delta

Read against the LibKa0s v1.63.0 `CHANGELOG.md` block and
`docs/api/Slash/version-17-docs.md` (*Compatibility*).

### Blockers

**None.** No existing member, descriptor field or string changes meaning. A host that passes no
`profiles` and registers no `profile` row sees no change in the client.

### Owed by the re-vendor commit

- **Surface parity.** `tests/test_surface_parity.lua` checks the library-absent Slash stub by name
  (`T.assertSurfaceParity(NS2.Slash.__cli, "LibKa0s-Slash-1.0", ...)`) against the live dispatcher
  instance. The copy alone turned it red, as the version 17 document predicts:

  ```text
  LibKa0s-Slash-1.0: the degraded stub diverges from the live surface in 2 place(s) —
  CliProfile is missing (live: function); ProfileSwitch is missing (live: function)
  ```

  The re-vendor commit adds both members to the stub in `settings/Slash.lua` (route (b): each prints
  `/am profile is unavailable: the LibKa0s library did not load.` and switches nothing;
  `ProfileSwitch` answers `false`), with a case in `tests/test_slash_verbs.lua` pinning that.
- **Provenance.** `CLAUDE.md`, `DEPENDENCIES.md` (the vendor-sync paragraph, twice) and
  `docs/module-map.md` (the library row) name the vendored tag.
