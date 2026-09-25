# 01 - Delta: LibKa0s v1.58.0 -> v1.59.0

Run non-interactively as task P9 of the 2026-09-25 feedback batch 8 plan
(`docs/superpowers/plans/2026-09-25-feedback-batch8.md`), on branch `feat/2026-09-25-feedback-batch8`,
on 2026-09-25. Steps 2-4 of `revendor-libka0s`: resolve the tag, read the delta, copy both payloads
whole, roll the provenance line. The one adoption this release was cut for (spec `CX-3`, the close
mark on the unlock strip) is owner-decided (spec D3) and lands in a second `B8-P9` commit; see
`05_SUMMARY.md`.

## Source

```sh
git -C ../LibKa0s tag --sort=-v:refname | head -1        # v1.59.0
git -C ../LibKa0s rev-parse --short 'v1.59.0^{commit}'   # 53c141a (tag object 080ee07)
git -C ../LibKa0s archive v1.59.0 LibKa0s testkit | tar -x -C <scratch>/
```

The payload comes from the tag, never the working tree. The tag is local to `../LibKa0s` (spec D3:
local tag only) and was read with `git archive`, never checked out.

## 3a. Claimed version, and the base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 36:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.58.0 (MIT).
git log -1 --format=%h -- libs/LibKa0s tests/_kit   # d25ca55 (the v1.58.0 re-vendor, M6-AM)
```

The base is **v1.58.0**, and the newest bundle (`2026-09-25-v1.58.0`) records it.

```sh
git -C ../LibKa0s log --oneline v1.58.0..v1.59.0
# 53c141a B8-P8: record the v1.59.0 release run, its ANALYSIS.md and gate line
# e8faa5d B8-P8: WidgetsDragHandle minor 3 - an opt-in close mark beside the help mark
```

## 3b/3c. Actual version, and the per-file minor delta

```sh
grep -HoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua   # before and after
```

One file moves a minor: **WidgetsDragHandle.lua, DRAG_MINOR 2 -> 3** (`LibKa0s-Widgets-1.0` 10.2 ->
10.3). Every other file keeps its minor (Core 8, Env 1, Compat 1, Lifecycle 2, Bus 2, Schema 2,
Pool 3, Item 2, Media 4, Widgets 10, DebugLog 13, Slash 15, Launcher 4, Options 24, OptionsWidgets
31, OptionsTabs 4, OptionsCompose 7, OptionsScroll 4, Perf 13, PerfPanel 5), as the LibKa0s v1.59.0
`CHANGELOG.md` version block states. No file is new or removed, no `NEEDS_*` floor rises and no
major changes. No cross-major skew before or after.

## 3d. Both diffs, before the copy

```sh
diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s   # Files .../WidgetsDragHandle.lua and libs/LibKa0s/WidgetsDragHandle.lua differ
diff -rq                     <scratch>/LibKa0s libs/LibKa0s   # the same single file
diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit     # empty
diff -rq                     <scratch>/testkit tests/_kit     # empty
```

Content and bytes report the same single file. The kit is byte-identical, and nothing was removed
upstream, so the copy deletes nothing.

## 3e. Consumption map

Unchanged from the v1.58.0 bundle. The one major that moves:

| Major | Lookup site | Minor moved in this range |
|---|---|---|
| Widgets | `modules/Anchors.lua:379` (`KW.DragHandle` at `:472`) | WidgetsDragHandle 2 -> 3 |

## 3f. Kit revision, and the pairing rule

```sh
grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua   # 26 and 26
```

No revision change. Both payloads are still copied whole in one commit, so
`tests/test_vendor_sync.lua` compares both against the tag the provenance line names.

## 3g. Contract delta

Read against the LibKa0s v1.59.0 `CHANGELOG.md` block ("What a consumer owes on re-vendoring
v1.59.0") and
`diff <(git show v1.58.0:docs/api/Widgets/version-10.2-docs.md) <(git show v1.59.0:docs/api/Widgets/version-10.3-docs.md)`.

### Blockers

**None.** Every changed sentence in the 10.3 document is either a `Since 3` addition (`onClose`,
`closeIcon`, `closeTooltip`, `DRAG_HANDLE.CLOSE_GAP`, `handle:Reserve()`, `handle.close`) or a
restatement that holds unchanged for a spec without `onClose` (`RESERVE` "on a strip without a close
mark", `Measure()` "= labelWidth + handle:Reserve() * 2", the label bounds at `+/-handle:Reserve()`).
The 10.3 document (`version-10.3-docs.md` "What changed at 10.3") states a spec with no `onClose` is
exactly 10.2's strip, pinned as literals by the library suite. `members-10.3.json` equals
`members-10.2.json`. AuraMaster supplies no `__Attach*` member to the Widgets major.

## After the copy (Step 4)

```sh
cp -r <scratch>/LibKa0s/. libs/LibKa0s/
cp -r <scratch>/testkit/. tests/_kit/
diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s   # empty
diff -rq                     <scratch>/LibKa0s libs/LibKa0s   # empty
diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit     # empty
diff -rq                     <scratch>/testkit tests/_kit     # empty
```

Content and bytes clean in both payloads. The provenance line in `CLAUDE.md` rolls v1.58.0 ->
v1.59.0 in the same commit, and so do the two other places that name the vendored tag
(`DEPENDENCIES.md`'s vendor-sync paragraph, `docs/module-map.md`'s library row).

Gate (`ka0s-bounded lua tests/run.lua`, `ka0s-bounded luacheck .`,
`ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .`, from the repo root):

| | Tests | Lint | Complexity |
|---|---|---|---|
| Before (v1.58.0) | 1422 passed, 0 failed, 0 skipped | 0 warnings / 0 errors in 126 files | 0 functions above CCN 15 |
| After the copy alone (v1.59.0) | 1422 passed, 0 failed, 0 skipped | 0 warnings / 0 errors in 126 files | 0 functions above CCN 15 |

The copy alone is green, as the 3g read predicts: AuraMaster passes no `onClose` yet, so its strip is
10.2's to the pixel.
