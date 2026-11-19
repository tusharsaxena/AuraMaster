Delta: LibKa0s v1.106.0 -> v1.107.0

Recorded before the commit. The payload was taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.107.0 LibKa0s testkit tools | tar -x -C <scratch>/new` (tag commit 5e96365). `git -C ../LibKa0s ls-remote --tags origin v1.107.0` prints nothing: the tag is local-only, which the cross-repo run expects (Ka0sAddonsCommonTasks `docs/2026-11-19-ADOPTION_FEEDBACK/`, item AF-RV-AM). This is a new re-vendor, not a refresh, because the provenance line named v1.106.0 before the copy. The run's adoption interview is skipped; its adoption item is AF-STRIP-AM (03_DECISIONS.md).

## Step 0 pre-flight (this addon)
- The newest single-tag bundle, `docs/revendor/2026-11-16-v1.105.0/`, states `Delta: LibKa0s v1.98.0 -> v1.105.0`, and the line was rolled to v1.105.0 by 68349c5 (RV-AM), whose parent named v1.98.0. The base is ok and needs no correction.
- v1.106.0 was vendored by 6917790 with no bundle. It is back-filled in `../2026-11-19-v1.106.0-v1.106.0/` (3h).

## 3a Base
- `grep -n 'Bundles' CLAUDE.md` gave `36:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.106.0 (MIT).`
- The last payload commit, `git log -1 --format=%h -- libs/LibKa0s tests/_kit`, is 6917790, and its `CLAUDE.md` names v1.106.0. The two agree.
- Before the copy, `diff -rq <scratch>/claimed/LibKa0s libs/LibKa0s` (the v1.106.0 extract) printed only `Only in <scratch>/claimed/LibKa0s/media/...` lines (the undeclared icons and the voice packs), and `diff -rq <scratch>/claimed/testkit tests/_kit` printed nothing: `payload-matches`.
- Range: `git -C ../LibKa0s log --oneline v1.106.0..v1.107.0` lists six commits (cbf3577 AF-LK-01 + #96, efbed58 AF-LK-02, f468fe7 AF-DR-LK, 24b9cea, 72653ec and 5e96365 AF-LK-03).

## 3b/3c Per-file minors that moved (old = this addon, new = v1.107.0)
Command: the spec's loop over the file list in `<scratch>/new/LibKa0s/LibKa0s.xml`, printing the rows where old and new differ.
```
WidgetsDragHandle.lua     DRAG_MINOR 14    -> 15
WidgetsDragHandleTip.lua  DRAGTIP_MINOR 1  -> 2
```
Every other file matched. There was no cross-major skew. The Widgets key moves 28.2.7.14.1.7.8.6.1.1 -> 28.2.7.15.2.7.8.6.1.1.

## 3d Diffs
After the copy and before the prune, `diff -r --strip-trailing-cr` and `diff -r` of both payloads against the v1.107.0 extract were empty in both directions, so no file removed upstream survives here. After the prune, only `Only in <scratch>/new/LibKa0s/media/icons` and `.../media/sounds` lines remain, and `diff -rq <scratch>/new/testkit tests/_kit` is empty.

## 3e Consumption map
Unchanged from the v1.105.0 bundle: Bus, Compat, Core, Skin, DebugLog, Env, Launcher, Lifecycle, Media, Perf, Pool, Widgets, Options, Schema and Slash. The moved files belong to Widgets, which `modules/Anchors.lua` looks up for `KW.DragHandle`, the one drag strip in this addon (`Anchors.BuildHandle`).

## 3f Kit
`Kit.VERSION = 57` on both sides; the kit is unchanged.

## 3g Contract delta
Read: `docs/api/Widgets/version-28.2.7.14.1.7.8.6.1.1-docs.md` against `version-28.2.7.15.2.7.8.6.1.1-docs.md`, and the v1.107.0 CHANGELOG block's *What a consumer owes at its re-vendor*. Two moves under a surface whose signature did not change:

- `spec.tooltipPlace` is accepted and no longer read (WidgetsDragHandleTip minor 2). This addon passes `NS.AnchorsTooltip.Place` (`modules/Anchors.lua:730`), which put the strip's tooltip beside the strip and, where the strip's rect reads secret, beside the nearest readable container up its attach chain. From the copy the tooltip opens centered above the strip, and the hook is dead code. Not a blocker: nothing errors, and the owner ruled the new placement (OWNER_FEEDBACK.md, *Strip tooltip*). The hook's removal is AF-STRIP-AM. The secret-rect fallback has no library equivalent (the library's own fallback is a relative point the anchor's restricted tree refuses), so an attached container under a parent holding auras can show no strip tooltip. Recorded as a known limitation in AF-STRIP-AM and in DRAG-20.
- The marks' order, pitch and tints moved (DragHandle minor 15). This addon reads the reserve through `handle:Reserve()` (`modules/Anchors.lua:908`, `:914`, `:972`), so its width code follows; four suites pinned literals and are re-pinned in this commit.

Blockers: none.

## 3i Icon declaration
`LibKa0s icons: chevron-down, chevron-up, clear, close, confirm, copy, eye, help, info, move, reset, settings, volume-high.` is kept as written. `settings` is already declared, which the v1.107.0 strip needs (the gear is on by default). The run's item list pre-decides it.

## 3j Whole-folder icon tests
`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'` finds nothing new since v1.105.0's bundle. None.
