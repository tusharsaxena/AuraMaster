Delta: LibKa0s v1.76.0 -> v1.77.0

# 01 — Delta (AuraMaster)

Run: 2026-10-24, item `AM-RV` of the 2026-10-24 run "keybindings (015), settings layout (020), frame
strata (030)" (Ka0sAddonsCommonTasks `docs/2026-10-24-KEYBINDS_LAYOUT_STRATA/`, milestone M2),
executed non-interactively under the run's rulings: no adoption interview, and no GitHub issue is
filed. Procedure: the installed dev-copilot 2.4.0 `/dev-copilot:wow-revendor-libka0s`. Branch
`feat/2026-10-24-keybinds-layout-strata`, created from `master` @ `c77c7fc` on a clean tree.

Source: the sibling checkout `../LibKa0s`, **local annotated tag `v1.77.0` (tag object `7380d36` ->
commit `78240f7`)**, not on `origin` (`git -C ../LibKa0s ls-remote --tags origin v1.77.0` prints
nothing). Extracted with `git -C ../LibKa0s archive v1.77.0 LibKa0s testkit tools | tar -x -C
<scratch>`, never a branch tip; `tools/` only for `prune-icons.lua`, which is never copied into the
addon. `git -C ../LibKa0s log --oneline v1.76.0..v1.77.0` lists 15 commits (LK-00 to LK-04, LK-10
to LK-13, LK-20, LK-90 and the v1.76.0 merge); `git -C ../LibKa0s diff --stat v1.76.0 v1.77.0 --
LibKa0s testkit` ends `18 files changed, 1672 insertions(+), 34 deletions(-)`.

## 3a — Claimed version, before this run

`grep -n '[Bb]undles' CLAUDE.md` -> `CLAUDE.md:36: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.76.0 (MIT).`
The last payload commit (`git log -1 --format=%H -- libs/LibKa0s tests/_kit`) is the v1.76.0
re-vendor, whose `CLAUDE.md` names v1.76.0 too. Payload check against the claimed tag: `diff -rq
<v1.76.0>/LibKa0s libs/LibKa0s` printed only the `Only in <v1.76.0>/LibKa0s/media/icons` lines for
undeclared icons, and `diff -rq <v1.76.0>/testkit tests/_kit` printed nothing.

**Base: v1.76.0.** Step 0's pre-flight for this addon: the newest single-tag bundle,
`docs/revendor/2026-10-23-v1.76.0/`, states base v1.75.2, and the provenance before `eed3996` (the
commit that vendored v1.76.0) was v1.75.2. No mismatch, no correction.

## 3b — Actual version, before this run

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` gave v1.76.0's
forty constants, and `Kit.VERSION` was 41. Claim and bytes agree.

## 3c — Per-file minor delta

The file list is the tag's `LibKa0s/LibKa0s.xml`: forty-one files (one new). Twelve constants move:

| File | v1.76.0 | v1.77.0 | What moved |
|---|---|---|---|
| `Core.lua` | 11 | **12** | `Core.RaiseStaticPopups()` |
| `DebugLog.lua` | 20 | **21** | the console is toplevel and raises shown StaticPopups on show |
| `PerfPanel.lua` | 8 | **9** | the perf panel is toplevel, same raise |
| `SimPanel.lua` | 5 | **6** | the sim panel is toplevel, same raise |
| `Widgets.lua` | 14 | **15** | the dropdown menu is clamped to screen |
| `WidgetsDragHandle.lua` | 4 | **5** | `spec.level`, `handle:ApplyLevel()`, `spec.ignoreParentAlpha` |
| `WidgetsAutocomplete.lua` | 2 | **3** | the suggestion list is clamped to screen |
| `Options.lua` | 29 | **30** | attaches `OptionsKeybinds.lua` |
| `OptionsIds.lua` | 2 | **3** | `O.__closeOwnedSuggest` (the suggestion list closes at combat start) |
| `OptionsCombat.lua` | 1 | **2** | `O.__releaseOwnedFocus` closes pullout and suggestion list both |
| `OptionsCompose.lua` | 7 | **8** | `O.StrataTooltip(values[, strings])` |
| `OptionsKeybinds.lua` | — (new) | **3** | the Keybindings tab: `O.KeybindingsTab`, `O.KeybindRows`, `O.KEYBINDS_UNCHANGED` |

Keys at the tag: Core 12, DebugLog 21.3.1, Perf 15.1.1.9, Sim 2.3.6, Widgets 15.1.5.3.3, Options
30.2.34.3.5.9.2.8.4.2.1.3. No `NEEDS_*` floor rises: seventeen majors across forty-one files
(LibKa0s `CHANGELOG.md` v1.77.0, line 13 at the tag). No cross-major skew.

## 3d — Both diffs

Before the copy, `diff -rq <scratch>/LibKa0s libs/LibKa0s` named the eleven changed files, `Only in
<scratch>/LibKa0s: OptionsKeybinds.lua`, `LibKa0s.xml`, and the undeclared-icon lines.
`diff -rq <scratch>/testkit tests/_kit` named `README.md`, `framework.lua` and `Only in` lines for
`bindings_xml.lua`, `mock_bindings.lua` and `mock_layers.lua`.

The copy is delete-then-copy of both folders. Before the prune, `diff -r --strip-trailing-cr
<scratch>/LibKa0s libs/LibKa0s`, `diff -r <scratch>/LibKa0s libs/LibKa0s` and `diff -r
<scratch>/testkit tests/_kit` printed nothing. After the prune the only difference is the
`Only in <scratch>/LibKa0s/media/icons` lines for the undeclared icons. Nothing was only on the
addon's side, so nothing was deleted from `libs/` beyond the prune.

## 3e — Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' --exclude-dir=libs
--exclude-dir=tests`: the same fourteen majors as at v1.76.0 (`docs/module-map.md`). Unbound: Item,
Glow, Sim.

Moved and consumed: **Core**, **DebugLog**, **Perf**, **Widgets** (`modules/Anchors.lua:664`,
`DragHandle`) and **Options**.

## 3f — Kit revision, and the pairing rule

`grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua` -> **41 -> 42**.
The pairing rule (a consumer on v1.9.0 or newer takes kit revision 11 or newer in the same commit) is
satisfied by construction: both payloads are copied whole, in one commit. Revision 42's new files
(`mock_bindings.lua`, `mock_layers.lua`, `bindings_xml.lua`) are opt-in; `bindings_xml.lua` is
loaded by `framework.lua` and asserts nothing until a suite calls it.

## 3g — Contract delta

`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` finds no
site, so no host-supplied member's call site can have moved.

- **Options 30 / OptionsCompose 8 / OptionsKeybinds 3**
  (`docs/api/Options/version-30.2.34.3.5.9.2.8.4.2.1.3-docs.md`; LibKa0s `CHANGELOG.md` v1.77.0,
  *What a consumer owes*): the live instance gains four members, `KeybindingsTab`, `KeybindRows`,
  `KEYBINDS_UNCHANGED` and `StrataTooltip`. `Kit.assertSurfaceParity` compares the addon's
  library-absent stub (`settings/OptionsSetup.lua`) against the live instance, so the copy turned
  `tests/test_surface_parity.lua` red: "the degraded stub diverges from the live surface in 4
  place(s) — KEYBINDS_UNCHANGED is missing (live: string); KeybindRows is missing (live: function);
  KeybindingsTab is missing (live: function); StrataTooltip is missing (live: function)".
- **WidgetsDragHandle 5** (`docs/api/Widgets/version-15.1.5.3.3-docs.md`): both new fields are
  opt-in; without `level` the strip is minor 4's exactly. AuraMaster's own L+50 re-level
  (`modules/Anchors.lua`, `HANDLE_LEVEL`) is untouched here and is AM-ZS's to replace.
- **Core 12, DebugLog 21, PerfPanel 9**: toplevel tool windows and the StaticPopup raise take effect
  with the copy; no host member is read. **OptionsIds 3 / OptionsCombat 2**: `__`-prefixed, owed by
  no stub.

**Blockers: one, resolved in the copy commit.** The Options degradation stub gains `KeybindingsTab`,
`KeybindRows` and `StrataTooltip` as no-ops (the stub's existing "every other function member, as a
no-op" list) and `KEYBINDS_UNCHANGED = ""` (the inert answer: a library-absent build draws no
Defaults tooltip to end with it). The stub's five-line growth shifted three `settings/OptionsSetup.lua`
citations (`docs/ARCHITECTURE.md:148`, `docs/midnight-quirks.md:788`, `settings/GeneralSpells.lua`
comment), which the docs-citation suite caught; each is moved +5 to the same line it named.

## 3h — Tags vendored and never recorded

The listing, run before the copy, printed nothing: every tag vendored since the store's horizon has a
bundle (the 2026-09-12 bundle records v1.30.0 by its line 1). No span bundle.

## 3i — The icon declaration

`grep -n 'LibKa0s icons:' CLAUDE.md` -> `CLAUDE.md:37: LibKa0s icons: clear, close, copy, help,
info.`, the next non-blank line under the provenance line. Kept as it stands: v1.77.0 adds no
library-drawn icon (CHANGELOG v1.77.0 *What a consumer owes*), and this item draws no new name. No
provenance split needed.

## 3j — Tests that assume the whole icon folder, and the prune

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'` finds only
`tests/test_optionssetup.lua:482-483` (the declared `info.tga`) and a comment in
`tests/test_vendor_sync.lua:10`. No blocker.

`lua <scratch>/tools/prune-icons.lua <AuraMaster>` (the tag's own tool, run after the provenance
line was rolled) ended `5 icon(s) declared; kept 6 file(s), removed 5834`: `libs/LibKa0s/media/icons/`
holds `clear.tga`, `close.tga`, `copy.tga`, `help.tga`, `info.tga` and `LICENSE-open-iconic.txt`,
byte-identical to before. The README credits are unchanged: only Open Iconic ships.

`grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` is empty: no
dead stub mirror.

## Citations into the payload

The copy moved lines in three library files that `settings/GeneralSpells.lua` comments cite by
line. Each was re-pointed at the same line by a `difflib` map of the old file onto the new:
`OptionsIds.lua:50-58` -> `:52-60`, `:124` -> `:126`, `:382` -> `:384`, `:522-524` -> `:524-526`;
`Options.lua:45-83` -> `:46-84`, `:513-519` -> `:514-520`; `WidgetsDragHandle.lua:492 and :168` ->
`:495 and :171`. `OptionsIdList.lua` did not change, so its citations stand.
