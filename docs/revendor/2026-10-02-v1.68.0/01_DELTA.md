# 01 - Delta: LibKa0s v1.67.0 -> v1.68.0

Run non-interactively as item `TP-AM-01` of the 2026-10-02 LibKa0s tooltip-place bundle
(`Ka0sAddonsCommonTasks/docs/2026-10-02-LIBKA0S_TOOLTIP_PLACE/`), on branch
`feat/2026-10-02-drag-attach`, on 2026-10-02. Steps 2-4 of `revendor-libka0s --tag v1.68.0`: resolve
the tag, read the delta, copy both payloads whole, roll the provenance line. The bundle's plan already
names the one new surface and assigns it to this item, so no interview was held (`02_CANDIDATES.md`).
The tag is local to the LibKa0s checkout; it has not been pushed.

## Source

```sh
git -C ../LibKa0s rev-parse --short 'v1.68.0^{commit}'     # cc9f5eb (DA-LK-07R's release record)
git -C ../LibKa0s rev-parse --short HEAD                   # cc9f5eb
git -C ../LibKa0s diff --quiet v1.68.0 -- LibKa0s testkit && echo CLEAN   # CLEAN
git -C ../LibKa0s archive v1.68.0 LibKa0s testkit | tar -x -C <scratch>/new
```

The payload comes from the tag export, never the working tree.

## Step 0 / 3a. Claimed version, and the base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 36:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.67.0 (MIT).
git -C ../LibKa0s archive v1.67.0 LibKa0s testkit | tar -x -C <scratch>/old
diff -rq <scratch>/old/LibKa0s libs/LibKa0s && diff -rq <scratch>/old/testkit tests/_kit && echo payload-matches
# payload-matches
```

The base is **v1.67.0**. The newest single-tag bundle is `2026-10-02-v1.67.0`, whose line 1 names
base v1.66.0, the tag the provenance line carried before its re-vendor: no correction is owed. Every
tag the addon vendored has a bundle, so no span bundle is owed.

```sh
git -C ../LibKa0s log --oneline v1.67.0..v1.68.0        # 12 commits: CA-LK-04/R, the census merge, DA-LK-01 .. DA-LK-07R
git -C ../LibKa0s diff --stat v1.67.0 v1.68.0 -- LibKa0s testkit
# LibKa0s/WidgetsDragHandle.lua | 84 +++++++++++++++++++++++++++++++++++--------
# 1 file changed, 69 insertions(+), 15 deletions(-)
```

## 3b/3c. Actual version, and the per-file minor delta

| File | Before (v1.67.0) | After (v1.68.0) |
|---|---|---|
| `WidgetsDragHandle.lua` | `DRAG_MINOR` 3 | **4** |

Every other file keeps its minor (CHANGELOG v1.68.0's version block). The Widgets key moves
12.1.3 -> **12.1.4**. No `NEEDS_*` floor rises, no major is added, no file is added or removed: still
fifteen majors across thirty-two files. No cross-major skew before or after.

## 3d. Both diffs, before the copy

```sh
diff -rq <scratch>/new/LibKa0s libs/LibKa0s     # WidgetsDragHandle.lua differs
diff -rq <scratch>/new/testkit tests/_kit       # nothing
```

Nothing is `Only in` the addon, so the whole-folder copy deletes nothing. After the copy both
`diff -r` runs print nothing, with or without `--strip-trailing-cr` (the tag's bytes are CRLF on
disk, as this repo's `.gitattributes` pins).

## 3e. Consumption map

| Major | Lookup site | Moved |
|---|---|---|
| Widgets | `modules/Anchors.lua:464` (`KW.DragHandle`) | WidgetsDragHandle 3 -> 4 |

## 3f. Kit revision, and the pairing rule

```sh
grep -n 'Kit.VERSION =' <scratch>/new/testkit/framework.lua tests/_kit/framework.lua   # 35 and 35
```

The kit stays at revision **35**: `testkit/` is unchanged between the two tags.

## 3g. Contract delta

Read against the v1.68.0 `CHANGELOG.md` block and `docs/api/Widgets/version-12.1.4-docs.md`
(lines 18-48, *What changed at 12.1.4*) against 12.1.3.

### Blockers

**None.** The new spec field `tooltipPlace` and the descriptor field `place` are optional (Since 4).
Without either, the widget makes minor 3's calls in minor 3's order (12.1.4 docs :44-45), so the strip
and close-mark tooltips this addon owns by `tooltipOwner = "cursor"` draw exactly as before. No member,
`DRAG_HANDLE` field or handle method moved, so the degradation path (no handle without the library)
is untouched.

### Owed by the re-vendor commit

- **Provenance.** `CLAUDE.md`, `DEPENDENCIES.md` (the vendor-sync paragraph, twice) and
  `docs/module-map.md` (the library row) name the vendored tag.
- `docs/test-cases.md` regenerated (unchanged) and the README badge checked (unchanged, 2015/2015).
