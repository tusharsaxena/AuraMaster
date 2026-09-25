# 01 - Delta: LibKa0s v1.59.0 -> v1.60.0

Run non-interactively as item `DR-AM-01` of the 2026-09-25 diagnostics rollout
(`Ka0sAddonsCommonTasks/docs/2026-09-25-DIAGNOSTICS_COMMAND/`), on branch
`feat/2026-09-25-diagnostics-rollout` cut from `master` at `73e2d8f` (the batch 8-11 merge, DR-OW-05),
on 2026-09-26. Steps 2-4 of `revendor-libka0s --tag v1.60.0`: resolve the tag, read the delta, copy
both payloads whole, roll the provenance line. The plan has already decided every candidate, so the
interview is answered from the plan (`03_DECISIONS.md`) and no decline issue is filed.

## Source

```sh
git -C ../LibKa0s tag --sort=-v:refname | head -1        # v1.60.0
git -C ../LibKa0s rev-parse --short 'v1.60.0^{commit}'   # bed0eb1
git -C ../LibKa0s archive v1.60.0 LibKa0s testkit | tar -x -C <scratch>/
```

The payload comes from the tag, never the working tree.

## 3a. Claimed version, and the base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 36:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.59.0 (MIT).
```

The base is **v1.59.0**, and the newest bundle (`2026-09-25-v1.59.0`) records it.

```sh
git -C ../LibKa0s log --oneline v1.59.0..v1.60.0
# bed0eb1 DR-LK-06: record the v1.60.0 release run, its ANALYSIS.md and gate line
# 2fdca6e DR-LK-06: date v1.60.0 and roll the release pointers
# db0c54a Merge feat/2026-09-25-diagnostics-rollout: v1.60.0 (unreleased) - DebugLog 14.1 diagnostics helper, Slash 16 (diagnostics live while disabled), MAX_BUFFER 3000
# c01db86 Merge feat/2026-09-25-draghandle-close: DragHandle close mark (Widgets 10.3, DragHandle minor 3), v1.59.0
# db21a1c DR-LK-05R ... 58e3794 DR-LK-01 (thirteen commits in all)
```

## 3b/3c. Actual version, and the per-file minor delta

```sh
grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua | sort   # before
grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' <scratch>/LibKa0s/*.lua | sort
```

| File | Before (v1.59.0) | After (v1.60.0) |
|---|---|---|
| `DebugLog.lua` | `MINOR` 13 | `MINOR` **14** |
| `DebugLogDiagnostics.lua` | absent | `DIAG_MINOR` **1** (new file, a secondary of `LibKa0s-DebugLog-1.0`) |
| `Slash.lua` | `MINOR` 15 | `MINOR` **16** |

Every other file keeps its minor (Core 8, Env 1, Compat 1, Lifecycle 2, Bus 2, Schema 2, Pool 3,
Item 2, Media 4, Widgets 10 + WidgetsDragHandle 3, Launcher 4, Options 24.31.4.7.4, Perf 13,
PerfPanel 5), as the LibKa0s v1.60.0 `CHANGELOG.md` block states. The tag's `LibKa0s.xml` gains
`DebugLogDiagnostics.lua` after `DebugLog.lua`; the host's `tests/run.lua` derives its library files
from that XML (`Loader.xmlFiles`), so no load list is typed by hand. No `NEEDS_*` floor rises and no
major is added. The claimed line and the minors agreed before the copy (v1.59.0). No cross-major skew
before or after.

## 3d. Both diffs, before the copy

```sh
diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s
# DebugLog.lua, LibKa0s.xml, Slash.lua differ; Only in <scratch>/LibKa0s: DebugLogDiagnostics.lua
diff -rq                     <scratch>/LibKa0s libs/LibKa0s   # the same four lines
diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit
# README.md, framework.lua differ; Only in <scratch>/testkit: test_diagnostics_contract.lua
diff -rq                     <scratch>/testkit tests/_kit     # the same three lines
```

Content and bytes agree, so there is no line-ending drift. Nothing is `Only in` the addon, so the
copy deletes nothing.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
```

The two majors that move, and where AuraMaster looks them up:

| Major | Lookup sites | Minor moved in this range |
|---|---|---|
| DebugLog | `core/DebugLogSetup.lua:13`, `modules/Diagnostics.lua:40` | DebugLog 13 -> 14, DebugLogDiagnostics new at 1 (key 13 -> 14.1) |
| Slash | `settings/Slash.lua` | Slash 15 -> 16 |

## 3f. Kit revision, and the pairing rule

```sh
grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua   # 27 and 26
```

The kit moves **26 -> 27** (the shared `test_diagnostics_contract.lua`). Both payloads are copied
whole in one commit with the provenance line, so `tests/test_vendor_sync.lua` compares both against
the tag the line names.

## 3g. Contract delta

Read against the LibKa0s v1.60.0 `CHANGELOG.md` block ("What a consumer owes on re-vendoring
v1.60.0"), and

```sh
diff <(git -C ../LibKa0s show v1.60.0:docs/api/DebugLog/version-13-docs.md) \
     <(git -C ../LibKa0s show v1.60.0:docs/api/DebugLog/version-14.1-docs.md)
diff <(git -C ../LibKa0s show v1.60.0:docs/api/Slash/version-15-docs.md) \
     <(git -C ../LibKa0s show v1.60.0:docs/api/Slash/version-16-docs.md)
```

### Blockers

**None.** What moved under an existing surface, and why none of it breaks AuraMaster:

- **The buffer: 1500 -> 3000 kept lines, slack 64 -> 128** (`version-14.1-docs.md`, *Compatibility*).
  No AuraMaster suite writes or asserts a literal 1500 or 64 against the console
  (`grep -rn '1500\|MAX_BUFFER\|BUFFER_SLACK' --include='*.lua'` outside `libs/` and `tests/_kit/`
  finds only layout-§1 file-cap comments, one comment in `core/DebugLogSetup.lua:5`, and
  `modules/Diagnostics.lua:41`). `modules/Diagnostics.lua:41-43` reads `lib.MAX_BUFFER` at load and
  takes `math.min(1200, BUFFER - 100)`, which stays 1200. The `core/DebugLogSetup.lua:5` comment
  ("the 1500-line buffer") is a doc ripple owned by `DR-AM-05`, not a blocker.
- **`Add` split into an internal `append`** (DebugLog 14): `Add`'s behavior is unchanged, and the
  report in `modules/Diagnostics.lua` writes through the public `NS.DebugLog:Add`.
- **Slash `LIVE_VERBS` gains `diagnostics`** (`version-16-docs.md`, rows at `:136`, `:143`).
  `settings/Slash.lua:127-137` builds `liveVerbs` from `SlashLib.LIVE_VERBS` and already adds
  `diagnostics` itself, so the set is the same; the duplicate entry is harmless because the library
  folds the array into a set (`Slash.lua:504-507`).
- AuraMaster supplies no `__Attach*` member to either major.

### Owed by the re-vendor commit (not blockers, but red without them)

- **Surface parity.** `tests/test_surface_parity.lua:29` pins the library-absent DebugLog stub in
  `core/DebugLogSetup.lua` against the live instance. The live instance gains `RunDiagnostics`,
  `BuildDiagnostics` and `DebugVerb` (`version-14.1-docs.md:524`, *Compatibility*), so the stub gains
  all three: `RunDiagnostics` prints the collection's placeholder line (`"%s is unavailable: the
  LibKa0s library did not load."` with `/am diagnostics`, a key `locales/enUS.lua` already carries),
  writes nothing and returns 0; `BuildDiagnostics` returns an empty report; `DebugVerb` answers
  `false` so the host keeps its own fallback.
- **The kit's new suite.** `tests/run.lua`'s suites list gains
  `{ name = "test_diagnostics_contract", dir = "tests/_kit/" }`. With `Kit.diagnostics` unset it is
  one declared skip until `DR-AM-02` wires it. `docs/test-cases.md` is regenerated.
