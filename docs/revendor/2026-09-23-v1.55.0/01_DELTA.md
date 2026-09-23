# 01 - Delta: LibKa0s v1.54.2 -> v1.55.0

Run: 2026-09-23, Steps 2-4 of `/wow-addon:revendor-libka0s` taken non-interactively by the suite
standards sweep (Phase 5). Steps 5-8 (candidates, adoption) belong to a later pass and are not in
this bundle. No push. Target: this repo, branch `suite/2026-09-22-standards-sweep` @ `08fe43b`.

Source: the sibling checkout `../LibKa0s`, **tag `v1.55.0` (tag object `bb161b7` -> commit
`6f9c5e0`)**, resolved with `git -C ../LibKa0s tag --sort=-v:refname | head -1` and extracted with
`git -C ../LibKa0s archive v1.55.0 LibKa0s testkit | tar -x -C <scratch>/`, never the working tree.
The tag is local and not yet pushed; `tests/test_vendor_sync.lua` reads the sibling's tags, so
that is enough.

```
git -C ../LibKa0s log --oneline v1.54.2..v1.55.0
  6f9c5e0 Record the v1.55.0 release run
  ae48f3f Make the v1.55.0 record true after the complexity split
  244c752 Bring collectKitHoles and repoKind under the CCN 15 ceiling
  be91249 Split Schema's Set and Validate under the CCN 15 gate
  18ca82a Release v1.55.0
  c051bef Re-vendor the standards reference, and make the v1.55.0 docs true
  06b4051 Add three majors: Compat, Bus, and the Schema runtime's portable half
  2a5e06f Test-kit revision 25: the four gates standard v2.63.0 already cites

git -C ../LibKa0s diff --stat v1.54.2 v1.55.0 -- LibKa0s testkit
  LibKa0s/Bus.lua (new, 347), LibKa0s/Compat.lua (new, 298), LibKa0s/Schema.lua (new, 650),
  LibKa0s/LibKa0s.xml (+3), testkit/README.md, testkit/framework.lua,
  testkit/run-automated-tests.sh, testkit/test_eol.lua, testkit/test_layout_cap.lua (new, 737),
  testkit/test_prose.lua -- 10 files, 4574 insertions, 169 deletions
```

## 3a - Claimed version, before this run

`grep -n '[Bb]undles' CLAUDE.md` -> `CLAUDE.md:36`: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) **v1.54.2** (MIT).

## 3b - Actual version, before this run

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua`:
Core 7, DebugLog 12, Env 1, Item 1, Launcher 1, Lifecycle 1, Media 3, Options 23, OptionsCompose 7,
OptionsScroll 3, OptionsTabs 3, OptionsWidgets 30, Perf 12, PerfPanel 5, Pool 3, Slash 14,
Widgets 9, WidgetsDragHandle 2. `grep -n 'Kit.VERSION' tests/_kit/framework.lua` -> revision 24.
That is v1.54.2's version block, so the line and the bytes agreed before the copy.

## 3c - Per-file minor delta

File list read from the tag's `LibKa0s/LibKa0s.xml` (21 `<Script>` rows); each file's constant read
with the same grep on both sides.

| File | v1.54.2 | v1.55.0 |
|---|---|---|
| Core | 7 | 7 |
| Env | 1 | 1 |
| **Compat** | absent | **1** (new major `LibKa0s-Compat-1.0`) |
| Lifecycle | 1 | 1 |
| **Bus** | absent | **1** (new major `LibKa0s-Bus-1.0`) |
| **Schema** | absent | **1** (new major `LibKa0s-Schema-1.0`) |
| Pool | 3 | 3 |
| Item | 1 | 1 |
| Media | 3 | 3 |
| Widgets | 9 | 9 |
| WidgetsDragHandle | 2 | 2 |
| DebugLog | 12 | 12 |
| Slash | 14 | 14 |
| Launcher | 1 | 1 |
| Options | 23 | 23 |
| OptionsWidgets | 30 | 30 |
| OptionsTabs | 3 | 3 |
| OptionsCompose | 7 | 7 |
| OptionsScroll | 3 | 3 |
| Perf | 12 | 12 |
| PerfPanel | 5 | 5 |
| **kit revision** | **24** | **25** |

No existing file's minor moves, so there is no cross-major skew to report. The three new files each
floor on Core minor 1 and return before `NewLibrary` without it.

## 3d - Both diffs, before the copy

```
diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s
  Only in <scratch>/LibKa0s: Bus.lua, Compat.lua, Schema.lua
  Files <scratch>/LibKa0s/LibKa0s.xml and libs/LibKa0s/LibKa0s.xml differ
diff -rq <scratch>/LibKa0s libs/LibKa0s            # bytes: the same four lines
diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit
  Files differ: README.md, framework.lua, the automated-test runner script, test_eol.lua,
  test_prose.lua
  Only in <scratch>/testkit: test_layout_cap.lua
diff -rq <scratch>/testkit tests/_kit                # bytes: the same six lines
```

Content and bytes disagree on exactly the same files, so this is a genuine version gap, not a
line-ending disagreement. There is no `Only in libs/LibKa0s` or `Only in tests/_kit` line: nothing
was removed upstream, so the copy deletes nothing. The extracted tree is CRLF (`file` on
`<scratch>/LibKa0s/Core.lua`), which is what `git check-attr eol` declares for both payloads here.

## 3e - Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'`:

| Major | Lookup site |
|---|---|
| Core | `core/CoreSetup.lua:16` |
| Env | `core/EnvSetup.lua:17` |
| Media | `core/MediaSetup.lua:18` |
| DebugLog | `core/DebugLogSetup.lua:13` |
| Lifecycle | `core/LifecycleSetup.lua:118` |
| Launcher | `core/LauncherSetup.lua:42` |
| Pool | `core/PoolSetup.lua:15` |
| Perf | `core/PerfSetup.lua:14` |
| Widgets | `modules/Anchors.lua:323` |
| Options | `settings/OptionsSetup.lua:98` |
| Slash | `settings/Slash.lua:26` |

Unconsumed majors in the payload: Item (reached only through Options), and the three new ones,
**Compat, Bus and Schema**. This addon carries its own `core/Compat.lua`, `core/Secrets.lua`, a
message catalog and a settings schema runtime, so all three new majors are Step 5 class C
candidates for the adoption pass, not for this one. Standard v2.64.0 (`library-stack-§7`'s
adoption carve-out) says a host copy written before adoption is not anti-pattern #47 until a later
version of the standard makes adoption a requirement.

## 3f - Kit revision, and the pairing rule

```
grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua
  <scratch>/testkit/framework.lua:20:Kit.VERSION = 25
  tests/_kit/framework.lua:20:Kit.VERSION = 24
```

v1.55.0 pairs with kit revision 25, and both payloads move in one commit. That is the pairing rule
(v1.9.0 and newer take revision 11 or newer together), satisfied by the whole-folder copy.

## 3g - Contract delta

**LibKa0s majors: nothing to read.** 3c moves no existing minor, so the intersection of "a minor
moved" with 3e's consumed set is empty. `grep -rn '__Attach[A-Za-z]*' . --include='*.lua'
--exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit` finds no host-supplied `__Attach*` site
outside tests, so no host member's call site can have moved. The three new majors are additive
and no code here looks them up.

**The kit: two contract changes that reach this repo's runner.** Kit revision 25's document
(`git -C ../LibKa0s show v1.55.0:docs/api/testkit/version-25-docs.md`) says no member a suite calls
is removed, renamed or resignatured, but the suite inventory behaves differently:

1. **`test_layout_cap.lua` arrives undeclared.** `Kit.assertSuiteInventory` fails a kit suite on
   disk that the runner does not declare, and it fails from `Kit.run`, so the whole harness aborts
   on the copy. **Blocker, fixed in the vendor commit:** `tests/run.lua` declares
   `{ name = "test_layout_cap", dir = "tests/_kit/" }`, the pair form `testing-§9` prescribes. The
   gate reads the hub `docs/ARCHITECTURE.md` (the default, so no `Kit.layoutCap` is set) and needs
   a `### Files over the 1500-line cap` census under `## Documented deviations`; that census landed
   one commit earlier (`08fe43b`), with a terminal state for each of the four over-cap files.
2. **Declarations are keyed by the pair (basename, directory).** A bare `"test_prose"` beside a
   local `tests/test_prose.lua` is now a collision. This runner already declares both kit suites in
   the pair form (`{ name = "test_prose", dir = "tests/_kit/" }` and
   `{ name = "test_eol", dir = "tests/_kit/" }`) and has no local `test_prose.lua`,
   `test_eol.lua` or `test_layout_cap.lua`, so no shadow exists. Nothing to fix.

**Other kit changes that reach this repo without a runner edit:**

- `test_eol.lua` gains a `.gitattributes` body case (`line-endings-§5`/`§7`). This repo's
  `.gitattributes` already matches the canonical body, including `*.py text eol=lf`.
- `test_prose.lua` now refuses a declared narrowing that a TOC loads or that `.pkgmeta` does not
  ignore, and discloses what each narrowing suppressed. This repo's one narrowing,
  `skipDirs = { "docs/spell-research/" }` in `tests/prose_waivers.lua`, is under `docs`, which
  `.pkgmeta` ignores and no TOC loads.
- The automated-test runner script adds generated `Commit` and `Tree` cells to `RESULTS.md` rows
  and widens the table once on its next run; earlier rows carry `unknown`.

**One consumer-side doc drift the copy causes, fixed in the vendor commit:** `DEPENDENCIES.md`
cites kit line numbers that revision 25 moved (`tests/_kit/test_eol.lua`, the automated-test
runner script and several `tests/_kit/framework.lua` lines), which this repo's
`tests/test_docs.lua` checks.

No blocker needs a decision rather than an edit, so the copy goes ahead.
