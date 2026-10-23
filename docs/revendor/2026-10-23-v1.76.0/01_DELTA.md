Delta: LibKa0s v1.75.2 -> v1.76.0

# 01 — Delta (AuraMaster)

Run: 2026-10-23, item `AM-RV` of the 2026-10-23 run "sim auto-run, QC preview selector, mode strips,
MM/KCD simulators" (Ka0sAddonsCommonTasks `docs/2026-10-23-SIM_PREVIEW_MODE_STRIPS/`, milestone M2),
executed non-interactively under the run's rulings: candidates are listed, not interviewed or
adopted, and no GitHub issue is filed. Procedure: the installed dev-copilot 2.4.0
`/dev-copilot:wow-revendor-libka0s`. Branch `feat/2026-10-23-sim-preview-mode-strips`, created from
`master` @ `9ea3e82` on a clean tree.

Source: the sibling checkout `../LibKa0s`, **local annotated tag `v1.76.0` (tag object `546e284` ->
commit `9949368`)**, not on `origin`. Extracted with
`git -C ../LibKa0s archive v1.76.0 LibKa0s testkit tools | tar -x -C <scratch>`, never a branch tip;
`tools/` only for `prune-icons.lua`, which is never copied into the addon.
`git -C ../LibKa0s log --oneline v1.75.2..v1.76.0` lists 8 commits (LK-00, LK-01, LK-10, LK-25,
LK-90 and the v1.75.2 merge); `git -C ../LibKa0s diff --stat v1.75.2 v1.76.0 -- LibKa0s testkit`
ends `3 files changed, 148 insertions(+), 53 deletions(-)`.

## 3a — Claimed version, before this run

`grep -n '[Bb]undles' CLAUDE.md` -> `CLAUDE.md:36: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.75.2 (MIT).`
The last payload commit (`git log -1 --format=%H -- libs/LibKa0s tests/_kit`) is `34772b4`, whose
`CLAUDE.md` names v1.75.2 too. Payload check against the claimed tag: `diff -rq <v1.75.2>/LibKa0s
libs/LibKa0s` printed only the `Only in <v1.75.2>/LibKa0s/media/icons` lines for undeclared icons
(the declaration working), and `diff -rq <v1.75.2>/testkit tests/_kit` printed nothing.

**Base: v1.75.2.** Step 0's pre-flight for this addon: the newest single-tag bundle,
`docs/revendor/2026-10-22-v1.75.0/`, states base v1.71.0, and the provenance before `99623f7` (the
commit that vendored v1.75.0) was v1.71.0. No mismatch, no correction. v1.75.1 and v1.75.2 were
vendored without a bundle; see 3h.

## 3b — Actual version, before this run

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` gave v1.75.2's
forty constants (`SIM_PANEL_MINOR = 4`), and `Kit.VERSION` was 41. Claim and bytes agree.

## 3c — Per-file minor delta

The file list is the tag's `LibKa0s/LibKa0s.xml` (forty files, unchanged from v1.75.2). Only three
constants differ:

| File | v1.75.2 | v1.76.0 | What moved |
|---|---|---|---|
| `Widgets.lua` | 13 | **14** | `W.TestStrip` takes `opts.kind = "sim"` (cyan) and answers `strip.kind` |
| `SimTimeline.lua` | 2 | **3** | a verb start or restart plays the run on its own; Run all removed |
| `SimPanel.lua` | 4 | **5** | controls are Pause/Resume, Restart and Stop; `RUN_ALL` leaves `Sim.STRINGS` |

Keys at the tag: Widgets 14.1.4.3.2, Sim 2.3.5 (`Sim` 2 unchanged). Every other file keeps its
v1.75.2 minor. No `NEEDS_*` floor rises, no major is added: seventeen majors across forty files
(LibKa0s `CHANGELOG.md` v1.76.0, line 13 at the tag). No cross-major skew.

## 3d — Both diffs

Before the copy, `diff -rq <scratch>/LibKa0s libs/LibKa0s` named `Widgets.lua`, `SimTimeline.lua`,
`SimPanel.lua` and the `Only in <scratch>/LibKa0s/media/icons` lines for the undeclared icons.
`diff -rq <scratch>/testkit tests/_kit` printed nothing (kit bytes unchanged).

The copy is delete-then-copy of both folders. Before the prune, `diff -r --strip-trailing-cr
<scratch>/LibKa0s libs/LibKa0s`, `diff -r <scratch>/LibKa0s libs/LibKa0s` and `diff -r
<scratch>/testkit tests/_kit` printed nothing. After the prune the only difference is the
`Only in <scratch>/LibKa0s/media/icons` lines for the undeclared icons. Nothing was only on the
addon's side.

## 3e — Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep
-v '/tests/'`: the same fourteen majors as at v1.75.0 (`docs/module-map.md`). Unbound: Item, Glow,
Sim.

Moved and consumed: **Widgets** only (`modules/Anchors.lua:464`, for `DragHandle`). AuraMaster calls
no `TestStrip` (`grep -rn TestStrip core modules settings` is empty). Sim moved and is not consumed.

## 3f — Kit revision, and the pairing rule

`grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua` -> **41 -> 41**;
the kit's bytes are unchanged. The pairing rule (a consumer on v1.9.0 or newer takes kit revision 11
or newer in the same commit) is satisfied by construction: both payloads are copied whole, in one
commit.

## 3g — Contract delta

`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` finds no
site, so no host-supplied member's call site can have moved.

- **Widgets 14** (`docs/api/Widgets/version-14.1.4.3.2-docs.md:27`, `:33`): `opts.kind` and
  `strip.kind` are additive; the members manifest lists the same names as 13, so
  `tests/test_surface_parity.lua` needs no stub change. The `Widgets.lua` code diff touches
  `TestStrip` alone (`STRIP_FILL` keyed by kind); `DragHandle`, the one Widgets surface AuraMaster
  calls, is untouched.
- **SimTimeline 3 / SimPanel 5** (`docs/api/Sim/version-2.3.5-docs.md`): behaviour change under a
  major AuraMaster does not consume. CHANGELOG v1.76.0 *What a consumer owes*: re-true suites that
  typed `start` then ran, and reword docs and strings that name Run all; `grep -rn 'RUN_ALL\|Run all'
  core modules settings locales` is empty, and no suite drives a simulator. Nothing to re-true.

**Blockers: none.**

## 3h — Tags vendored and never recorded

The listing, run before the copy, printed `v1.75.1` and `v1.75.2`: both were carried by plain
re-vendor commits (`4d425cc`, `34772b4`) with no bundle. One consolidated span bundle is written
beside this one: `docs/revendor/2026-10-23-v1.75.1-v1.75.2/`.

## 3i — The icon declaration

`grep -n 'LibKa0s icons:' CLAUDE.md` -> `CLAUDE.md:37: LibKa0s icons: clear, close, copy, help,
info.`, the next non-blank line under the provenance line. Kept as it stands: v1.76.0 adds no
library-drawn icon (CHANGELOG v1.76.0 *What a consumer owes*: "Nothing for the strip"), and
AuraMaster draws no new name. No provenance split needed.

## 3j — Tests that assume the whole icon folder, and the prune

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'` finds only
`tests/test_optionssetup.lua:482-483` (the declared `info.tga`), already narrowed to the declaration
at v1.75.0. No blocker.

`lua <scratch>/tools/prune-icons.lua <AuraMaster>` (the tag's own tool, run after the provenance
line was rolled) ended `5 icon(s) declared; kept 6 file(s), removed 5834`, the same split as at
v1.75.0: `libs/LibKa0s/media/icons/` holds `clear.tga`, `close.tga`, `copy.tga`, `help.tga`,
`info.tga` and `LICENSE-open-iconic.txt`. The README credits are unchanged: only Open Iconic ships.

`grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` is empty: no
dead stub mirror.
