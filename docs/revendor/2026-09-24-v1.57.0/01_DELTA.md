# 01 - Delta: LibKa0s v1.56.0 -> v1.57.0

Run non-interactively as item M5-AM of the 2026-09-23 review-and-audit remediation plan (milestone
M5, the always-on launcher status tooltip), on branch `feat/2026-09-23-review-audit-remediation`,
on 2026-09-24. Steps 0 and 2-4 of `revendor-libka0s` (the local
`../wow-addon/commands/revendor-libka0s.md`): resolve the tag, read the delta, copy both payloads
whole, roll the provenance line. The one adoption this release owes (`launcher-§1`'s descriptor
fields) is the M5-AM item itself and lands in the same commit; it is recorded in `05_SUMMARY.md`.
Written before the copy; the post-copy verification at the end was appended before the commit.

## Source

```sh
git -C ../LibKa0s tag --sort=-v:refname | head -1        # v1.57.0
git -C ../LibKa0s rev-parse --short 'v1.57.0^{commit}'   # aa37bc9 (tag object d03e836)
git -C ../LibKa0s archive v1.57.0 LibKa0s testkit | tar -x -C <scratch>/new/
git -C ../LibKa0s archive v1.56.0 LibKa0s testkit | tar -x -C <scratch>/old/
```

The payload comes from the tag, never the working tree. The tag is local to `../LibKa0s` and not
pushed; it was read with `git archive` and never checked out there.

## Step 0. The newest bundle's base

```sh
head -1 docs/revendor/2026-09-23-v1.56.0/01_DELTA.md   # # 01 - Delta: LibKa0s v1.55.0 -> v1.56.0
# the commit that first carried v1.56.0 on the provenance line, and the line at its parent:
#   0fc5248 (RV-AM), parent v1.55.0
```

The newest single-tag bundle's base (v1.55.0) is the provenance tag before `0fc5248`: **ok**. No
base correction is owed.

## 3a. Claimed version, and the base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 36:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.56.0 (MIT).
git log -1 --format=%h -- libs/LibKa0s tests/_kit   # 0fc5248 RV-AM: Re-vendor LibKa0s v1.56.0
```

The line and the last payload commit agree: the base is **v1.56.0**. The vendored copy is
byte-identical to that tag (`diff -rq <scratch>/old/LibKa0s libs/LibKa0s` and
`diff -rq <scratch>/old/testkit tests/_kit`, both empty: `payload-matches`).

```sh
git -C ../LibKa0s log --oneline v1.56.0..v1.57.0 | wc -l            # 2
git -C ../LibKa0s diff --stat v1.56.0 v1.57.0 -- LibKa0s testkit | tail -1
# 1 file changed, 109 insertions(+), 4 deletions(-)
```

## 3b/3c. Actual version, and the per-file minor delta

One file moves a minor: **Launcher.lua, MINOR 2 -> 3**. Every other file keeps the minor the
v1.56.0 bundle's table records (Core 8, Env 1, Compat 1, Lifecycle 2, Bus 2, Schema 2, Pool 3,
Item 2, Media 4, Widgets 10, WidgetsDragHandle 2, DebugLog 13, Slash 15, Options 24,
OptionsWidgets 31, OptionsTabs 4, OptionsCompose 7, OptionsScroll 4, Perf 13, PerfPanel 5), which
the LibKa0s v1.57.0 `CHANGELOG.md` version block states too. No file is new or removed, no
`NEEDS_*` floor rises (Launcher still needs Core 1) and no major changes. No cross-major skew
before or after.

## 3d. Both diffs, before the copy

```sh
diff -rq <scratch>/new/LibKa0s libs/LibKa0s   # Files …/Launcher.lua and libs/LibKa0s/Launcher.lua differ
diff -rq <scratch>/new/testkit tests/_kit     # empty
```

Content and bytes report the same single file. The kit is byte-identical to v1.56.0's, and
nothing was removed upstream, so the copy deletes nothing.

## 3e. Consumption map

Unchanged from the v1.56.0 bundle: thirteen majors consumed. The one that moves:

| Major | Lookup site | Minor moved in this range |
|---|---|---|
| Launcher | `core/LauncherSetup.lua:43` | 2 -> 3 |

## 3f. Kit revision, and the pairing rule

`Kit.VERSION = 26` in both the tag and `tests/_kit/framework.lua`: no revision change. Both
payloads are still copied whole in one commit, so `tests/test_vendor_sync.lua` compares both
against the tag the provenance line names.

## 3g. Contract delta

Read against the LibKa0s v1.57.0 `CHANGELOG.md` block ("What a consumer owes on re-vendoring
v1.57.0"), `docs/api/Launcher/version-3-docs.md` at the tag, and
`git -C ../LibKa0s diff v1.56.0 v1.57.0 -- LibKa0s/Launcher.lua`.

### Blockers

**None.** The one change of meaning is `onTooltipShow`: through minor 2 it was handed to the LDB
object as the whole tooltip, and from minor 3 it is appended inside the library's block. This
addon's descriptor passed no `onTooltipShow` before the copy (`core/LauncherSetup.lua` at
`8e369e3`), so there is no host-drawn title or click hint to be doubled (anti-pattern #89), and no
host test called the object's `OnTooltipShow`.

### Arrives without being asked for

The button answers a hover with the library's status tooltip, enabled or disabled: the label,
`Enabled: Yes|No` (from the `isEnabled` this addon already passes since AM-09), and the two click
hints. The disabled hint reads `/am enable` out of the `disabledLine` it already passes.

### Owed by launcher-§1 (the M5-AM adoption)

`version`, `leftClickLabel` for rung (b), and `isLocked` / `isTestMode`, since this addon has both
states (the Lock frame row's `locked`, the Test mode row's `state.testMode`). Taken in the same
commit; see `05_SUMMARY.md`.

## 3h. Tags vendored and never recorded

Vendored since the horizon and not recorded by a bundle: **none**. v1.56.0 has
`2026-09-23-v1.56.0`, and v1.57.0 is this bundle.

## After the copy (Step 4)

```sh
rm -rf libs/LibKa0s tests/_kit
cp -r <scratch>/new/LibKa0s/. libs/LibKa0s/
cp -r <scratch>/new/testkit/. tests/_kit/
chmod +x tests/_kit/run-automated-tests.sh
diff -r <scratch>/new/LibKa0s libs/LibKa0s    # empty
diff -r <scratch>/new/testkit tests/_kit      # empty
```

Content and bytes clean in both payloads, and the runner keeps mode 100755. The provenance line in
`CLAUDE.md` rolls v1.56.0 -> v1.57.0 in the same commit, and so do the two places that name the
vendored tag (`DEPENDENCIES.md`'s vendor-sync paragraph, `docs/module-map.md`'s library row).

Gate (`ka0s-bounded luacheck .`, `ka0s-bounded lua5.1 tests/run.lua`,
`ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .`, from the repo root):

| | Tests | Lint | Complexity |
|---|---|---|---|
| Before (v1.56.0) | 1350 passed, 0 failed, 0 skipped | 0 warnings / 0 errors in 119 files | not run |
| After the copy alone (v1.57.0) | 1350 passed, 0 failed, 0 skipped | not run | not run |
| After the adoption | 1355 passed, 0 failed, 0 skipped | 0 warnings / 0 errors in 119 files | 0 functions above CCN 15 |
