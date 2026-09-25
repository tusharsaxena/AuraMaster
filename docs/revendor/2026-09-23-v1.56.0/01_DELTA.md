Delta: LibKa0s v1.55.0 -> v1.56.0

Run non-interactively as item RV-AM of the 2026-09-23 review-and-audit remediation plan, on branch
`feat/2026-09-23-review-audit-remediation`, on 2026-09-24. The bundle is named for the plan's date.
Steps 0 and 2-4 of `revendor-libka0s` only (the local `../wow-addon/commands/revendor-libka0s.md`,
as amended by WA-01): resolve the tag, read the delta, copy both payloads whole, roll the
provenance line. Adoption (Steps 5-8) is not taken here: each candidate is its own M3 plan item for
this addon, named below. Step 3h finds nothing unrecorded, because AM-02 (`d937092`) wrote the
span bundle ahead of this run. Written before the copy; the post-copy verification at the end was
appended before the commit.

## Source

```sh
git -C ../LibKa0s tag --sort=-v:refname | head -1        # v1.56.0
git -C ../LibKa0s rev-parse --short 'v1.56.0^{commit}'   # 514fc0a (tag object 4622018)
git -C ../LibKa0s archive v1.56.0 LibKa0s testkit | tar -x -C <scratch>/new/
git -C ../LibKa0s archive v1.55.0 LibKa0s testkit | tar -x -C <scratch>/old/
```

The payload comes from the tag, never the working tree. The tag is local to `../LibKa0s` and not
pushed; it was read with `git archive` and never checked out there.

## Step 0. The newest bundle's base

```sh
head -1 docs/revendor/2026-09-23-v1.55.0/01_DELTA.md   # # 01 - Delta: LibKa0s v1.54.2 -> v1.55.0
# the commit that first carried v1.55.0 on the provenance line, and the line at its parent:
#   f6f3ffb, parent v1.54.2
```

The newest single-tag bundle's base (v1.54.2) is the provenance tag before `f6f3ffb`: **ok**. No
base correction is owed. The span bundle `2026-09-24-v1.35.0-v1.54.2` names two tags and is not
read as a base (Step 0's single-tag rule).

## 3a. Claimed version, and the base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 36:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.55.0 (MIT).
c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)   # f6f3ffb Re-vendor LibKa0s v1.55.0
git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+'
# Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.55.0
```

The line and the last payload commit agree: the base is **v1.55.0**. The vendored copy is
byte-identical to that tag (`diff -rq <scratch>/old/LibKa0s libs/LibKa0s` and
`diff -rq <scratch>/old/testkit tests/_kit`, both empty: `payload-matches`).

```sh
git -C ../LibKa0s log --oneline v1.55.0..v1.56.0 | wc -l            # 53
git -C ../LibKa0s diff --stat v1.55.0 v1.56.0 -- LibKa0s testkit | tail -1
# 26 files changed, 2349 insertions(+), 844 deletions(-)
```

## 3b/3c. Actual version, and the per-file minor delta

```sh
for f in $(git -C ../LibKa0s show v1.56.0:LibKa0s/LibKa0s.xml | grep -oE 'file="[^"]+\.lua"' | cut -d'"' -f2); do
  grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/"$f"
  git -C ../LibKa0s show v1.56.0:LibKa0s/"$f" | grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+'
done
```

In the tag's `LibKa0s.xml` load order:

| File | Constant | Before | Tag |
|---|---|---|---|
| Core.lua | MINOR | 7 | **8** |
| Env.lua | MINOR | 1 | 1 |
| Compat.lua | MINOR | 1 | 1 |
| Lifecycle.lua | MINOR | 1 | **2** |
| Bus.lua | MINOR | 1 | **2** |
| Schema.lua | MINOR | 1 | **2** |
| Pool.lua | MINOR | 3 | 3 |
| Item.lua | MINOR | 1 | **2** |
| Media.lua | MINOR | 3 | **4** |
| Widgets.lua | MINOR | 9 | **10** |
| WidgetsDragHandle.lua | DRAG_MINOR | 2 | 2 |
| DebugLog.lua | MINOR | 12 | **13** |
| Slash.lua | MINOR | 14 | **15** |
| Launcher.lua | MINOR | 1 | **2** |
| Options.lua | MINOR | 23 | **24** |
| OptionsWidgets.lua | WIDGETS_MINOR | 30 | **31** |
| OptionsTabs.lua | TABS_MINOR | 3 | **4** |
| OptionsCompose.lua | COMPOSE_MINOR | 7 | 7 |
| OptionsScroll.lua | SCROLL_MINOR | 3 | **4** |
| Perf.lua | MINOR | 12 | **13** |
| PerfPanel.lua | PANEL_MINOR | 5 | 5 |

Fifteen files move a minor. No file is new and none is removed. The claim (v1.55.0) and the bytes
agree before the copy, and the whole-folder copy moves every file together, so there is **no
cross-major skew** before or after. No `NEEDS_*` floor rises and no major changes (LibKa0s
`CHANGELOG.md`, the v1.56.0 block).

## 3d. Both diffs, before the copy

```sh
diff -rq --strip-trailing-cr <scratch>/new/LibKa0s libs/LibKa0s
diff -rq                     <scratch>/new/LibKa0s libs/LibKa0s
diff -rq --strip-trailing-cr <scratch>/new/testkit tests/_kit
diff -rq                     <scratch>/new/testkit tests/_kit
```

Content and bytes report the same set, so nothing here is a line-ending disagreement:

- library: differs: `Bus.lua`, `Core.lua`, `DebugLog.lua`, `Item.lua`, `Launcher.lua`,
  `Lifecycle.lua`, `Media.lua`, `Options.lua`, `OptionsScroll.lua`, `OptionsTabs.lua`,
  `OptionsWidgets.lua`, `Perf.lua`, `Schema.lua`, `Slash.lua`, `Widgets.lua`. No `Only in` line on
  either side; `media/` is identical.
- kit: `Only in <tag>`: `asserts.lua`, `mock_events.lua`, `prose_lists.lua`; differs: `README.md`,
  `framework.lua`, `mock_base.lua`, `mock_record.lua`, `run-automated-tests.sh`, `test_eol.lua`,
  `test_layout_cap.lua`, `test_prose.lua`.
- No `Only in libs/LibKa0s` or `Only in tests/_kit` line: nothing was removed upstream, so the copy
  deletes nothing.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' \
  | grep -v 'libs/' | grep -v 'tests/'
```

| Major | Lookup site | Minor moved in this range |
|---|---|---|
| Core | `core/CoreSetup.lua:16` | 7 -> 8 |
| Env | `core/EnvSetup.lua:17` | no |
| Compat | `core/Compat.lua:9`, `core/Secrets.lua:38` | no |
| Lifecycle | `core/LifecycleSetup.lua:118` | 1 -> 2 |
| Bus | `core/Bus.lua:25` | 1 -> 2 |
| Pool | `core/PoolSetup.lua:15` | no |
| Media | `core/MediaSetup.lua:18` | 3 -> 4 |
| DebugLog | `core/DebugLogSetup.lua:13` | 12 -> 13 |
| Launcher | `core/LauncherSetup.lua:42` | 1 -> 2 |
| Perf | `core/PerfSetup.lua:14` | 12 -> 13 (PerfPanel stays 5) |
| Widgets | `modules/Anchors.lua:323` | 9 -> 10 |
| Options | `settings/OptionsSetup.lua:98` | key 23.30.3.7.3 -> 24.31.4.7.4 |
| Slash | `settings/Slash.lua:26` | 14 -> 15 |

Thirteen majors consumed. Unadopted in the payload: **Item** (reached only through Options'
item rows) and **Schema** (tracked as AuraMaster#21; Schema minor 2 adds `SetMany`, `row.normalize`
and `writeThrough`, and adoption is plan item AM-15).

## 3f. Kit revision, and the pairing rule

```sh
grep -n 'Kit.VERSION' <scratch>/new/testkit/framework.lua tests/_kit/framework.lua
# <scratch>/new/testkit/framework.lua:20:Kit.VERSION = 26
# tests/_kit/framework.lua:20:Kit.VERSION = 25
```

Revision **25 -> 26**. A consumer taking LibKa0s v1.9.0 or newer takes kit revision 11 or newer in
the same commit; both payloads are copied whole in one commit, so the pairing holds by
construction, and `tests/test_vendor_sync.lua` compares both against the tag the provenance line
names, which is why they move together.

## 3g. Contract delta

Read against the LibKa0s v1.56.0 `CHANGELOG.md` block ("What a consumer owes on re-vendoring
v1.56.0"), the Slash.lua diff over the range, and the release bundle's dry run
(`git -C ../LibKa0s show v1.56.0:docs/automated-tests/20260924-040553/ANALYSIS.md`, the AuraMaster
row at `0ede122`), for the majors 3c and 3e intersect.

```sh
grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit   # empty
git -C ../LibKa0s diff v1.55.0 v1.56.0 -- LibKa0s/Slash.lua
```

### Blockers

**None.** No host-supplied member's call site moved under a surface this addon hands over:

- **Slash minor 15**: `CliSet` now prints a refusal when the host's `set` answers `false, reason`,
  and `CliReset` prints `NO_DEFAULT` when `applyDefault` answers exactly `false`; nil or true still
  mean the write landed. This addon's `set` and `applyDefault` (`settings/Slash.lua:467-478`) print
  their own refusal and answer nothing, which still reads as success, so the behavior is the same
  as at minor 14. Returning the seam's answer and letting the library print is plan item AM-11.
- **Options minor 24**: `CreateOptionsPanel` parks in combat and replays at `PLAYER_REGEN_ENABLED`.
  This addon calls it from `OnEnable` (`core/AuraMaster.lua:52`) and keeps no park of its own, so
  the park arrives for free. `OpenOptionsPanel`'s new boolean answer is additive; the host's
  wrappers (`settings/OptionsSetup.lua:360-361`) discard it.
- **OptionsTabs minor 4**: `RenderTabbedSchema` moves into `OptionsTabs.lua` behind
  `lib.__AttachTabs`, and the four-argument call is unchanged. `PageBanner`'s `Dropdown` is now
  Released by the library under a private key; `ctx.__bannerWidget` stays the host's, which this
  addon writes itself (`settings/OptionsSetup.lua:443`, `:495`, `:521`) and never Releases for the
  banner, so there is no double release. `PageHeader` now hands back one frame per page; the host's
  builder still Releases its own widgets after the next render (`settings/OptionsSetup.lua:520-529`).
  The fifth `opts` argument and `PageBanner`'s `action` are opt-ins (AM-17).
- **OptionsWidgets minor 31**: the drag throttles keep their own armed flag. This addon's
  `scheduleTimer` answers AceTimer's handle (`settings/OptionsSetup.lua:160`), so nothing changes.
- **Core minor 8**, **Launcher minor 2**: the `SafeRegisterEvent` family, `isEnabled` and
  `disabledLine` are additive (AM-07, AM-09).

### Kit flips (revision 26)

The dry run of this payload against `0ede122` reported five reds for this addon: three stand-down
cases seeing the container frames that kit 26 now creates shown, the docs citation gate on
`DEPENDENCIES.md`'s `tests/_kit/framework.lua:631-643` (moved by kit 26's peel), and the lone-CR
`test_eol` case on `tests/page_helpers.lua:80`. Plan item AM-01 (`6bb7027`, `63e7d55`) cleared all
five ahead of this commit, so the suite is expected green; the result is below. The kit's case
names now carry the section sign, so `docs/test-cases.md` is out of step with the runner until plan
item AM-DOCS regenerates it; this commit does not touch it.

## 3h. Tags vendored and never recorded

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)   # 2026-09-12
# the audit's walk plus the provenance rolls, less every bundle's recorded tag (the procedure's script)
```

Vendored since the horizon: v1.30.0 through v1.55.0 (28 tags). Unrecorded: **none**. The span
bundle `2026-09-24-v1.35.0-v1.54.2` (AM-02, `d937092`) closed the gap, so no span bundle is written
here.

## After the copy (Step 4)

```sh
rm -rf libs/LibKa0s tests/_kit
cp -r <scratch>/new/LibKa0s/. libs/LibKa0s/
cp -r <scratch>/new/testkit/. tests/_kit/
chmod +x tests/_kit/run-automated-tests.sh
diff -r --strip-trailing-cr <scratch>/new/LibKa0s libs/LibKa0s    # empty
diff -r                     <scratch>/new/LibKa0s libs/LibKa0s    # empty
diff -r --strip-trailing-cr <scratch>/new/testkit tests/_kit      # empty
diff -r                     <scratch>/new/testkit tests/_kit      # empty
```

Content and bytes both clean in both payloads; nothing deleted inside `libs/` or `tests/_kit/`
beyond what the whole-folder replace put back, and the runner keeps mode 100755. The provenance
line in `CLAUDE.md` rolls v1.55.0 -> v1.56.0 in the same commit; `README.md` carries no provenance
line.

Gate, before and after (`ka0s-bounded luacheck .`, `ka0s-bounded lua5.1 tests/run.lua`,
`ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .`, from the repo root):

| | Tests | Lint | Complexity |
|---|---|---|---|
| Before (v1.55.0, kit 25) | 1296 passed, 0 failed, 0 skipped | 0 warnings / 0 errors in 110 files | not run |
| After (v1.56.0, kit 26) | 1296 passed, 0 failed, 0 skipped | 0 warnings / 0 errors in 110 files | 2 functions above CCN 15 |

The two complexity warnings are the addon's own and predate this run: `Cat.SyncUserCategories`
(`defaults/Categories.lua:1112`, CCN 25) and `renderCategories` (`settings/Filters.lua:500`,
CCN 16). Plan item AM-13 splits both. `.luacheckrc` excludes `libs/` and `tests/_kit/`, so lint does
not see the payload either way. `tests/test_vendor_sync.lua` passes against v1.56.0.
