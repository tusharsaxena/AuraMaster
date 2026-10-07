Delta: LibKa0s v1.70.0 -> v1.71.0

# 01 — Delta (AuraMaster)

Run: 2026-10-07, item `RV-AM` of the 2026-10-07 review and standards-audit remediation, executed
non-interactively per the owner's scope ruling (OWNER_SCOPE 5: the re-vendor is mechanical, and
candidates the plan does not require are listed as "not adopted in this run", with no interview and no
GitHub issue). Branch `feat/2026-10-07-review-audit-remediation` @ `20a39d6`, clean tree.

Source: the sibling checkout `../LibKa0s`, **local tag `v1.71.0` (tag object `3bf1b97` -> commit
`cb274a4`)**, which exists locally only and is not on `origin`. The payloads were extracted with
`git -C ../LibKa0s archive v1.71.0 LibKa0s testkit | tar -x -C <scratch>/new`, never a branch tip.
`git -C ../LibKa0s diff --stat v1.70.0 v1.71.0 -- LibKa0s testkit` names ten files: six under
`LibKa0s/` (`Env.lua`, `OptionsIdList.lua`, `Slash.lua`, `SlashParse.lua`, `WidgetsAutocomplete.lua`,
`WidgetsLineChart.lua`) and four under `testkit/` (`README.md`, `framework.lua`, `inventory.lua`, and
the new `secrets.lua`).

## 3a — Claimed version, before this run

`CLAUDE.md:36` -> `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.70.0 (MIT).` The last
payload commit, `c070393`, rolled the line to v1.70.0, so the two agree. Payload check against the
claimed tag: `diff -rq --strip-trailing-cr <v1.70.0>/LibKa0s libs/LibKa0s && diff -rq
--strip-trailing-cr <v1.70.0>/testkit tests/_kit` printed `payload-matches-v1.70.0`. The tag is
restated at `DEPENDENCIES.md:85`, `DEPENDENCIES.md:92` and `docs/module-map.md:293`, and those move
with it.

**Base: v1.70.0.**

## 3b — Actual version, before this run

34 minor constants on each side (`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+'`),
v1.70.0's, and `Kit.VERSION` is 37. Claim and bytes agree.

## 3c — Per-file minor delta

Six files move a minor; `LibKa0s.xml` is byte-identical, so no file is added or removed:

| File | v1.70.0 | v1.71.0 | Major's key at v1.71.0 |
|---|---|---|---|
| `Env.lua` | 1 | **2** | `LibKa0s-Env-1.0` 2 |
| `Slash.lua` | 19 | **20** | `LibKa0s-Slash-1.0` key **20.2** |
| `SlashParse.lua` | 1 | **2** | (Slash, above) |
| `WidgetsLineChart.lua` | 2 | **3** | `LibKa0s-Widgets-1.0` key **12.1.4.3.2** (`Widgets` 12, `WidgetsReorder` 1, `WidgetsDragHandle` 4, `WidgetsLineChart` 3, `WidgetsAutocomplete` 2) |
| `WidgetsAutocomplete.lua` | 1 | **2** | (Widgets, above) |
| `OptionsIdList.lua` | 3 | **4** | `LibKa0s-Options-1.0` key **28.2.34.2.4.8.1.7.4.2** |

Every other file stays at its v1.70.0 minor: `Core` 10, `Compat` 1, `Lifecycle` 3, `Bus` 2, `Schema` 2,
`Pool` 3, `Item` 2, `Media` 4, `DebugLog` key 19.2.1, `Launcher` 5, `Perf` key 14.1.1.6. No `NEEDS_*`
floor rises, no major is added, no member is removed (CHANGELOG v1.71.0, lines 13-30 at the tag).
Fifteen majors across thirty-four files, as before.

## 3d — Both diffs

Before the copy, `diff -rq <scratch>/new/LibKa0s libs/LibKa0s` names the six files above, and
`diff -rq <scratch>/new/testkit tests/_kit` names `README.md`, `framework.lua`, `inventory.lua` and
`Only in <scratch>/new/testkit: secrets.lua`. Nothing is only on the addon's side, so nothing is
deleted. The copy is delete-then-copy of both folders; after it, `diff -r libs/LibKa0s
<scratch>/new/LibKa0s` and `diff -r tests/_kit <scratch>/new/testkit` print nothing.

## 3e — Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua'`, outside `libs/` and
`tests/`: Compat (`core/Compat.lua:9`, `core/Secrets.lua:38`), Media (`core/MediaSetup.lua:18`), Env
(`core/EnvSetup.lua:17`), Lifecycle (`core/LifecycleSetup.lua:168`), Core (`core/CoreSetup.lua:16`),
Launcher (`core/LauncherSetup.lua:44`), Bus (`core/Bus.lua:25`), DebugLog (`core/DebugLogSetup.lua:13`),
Perf (`core/PerfSetup.lua:14`), Pool (`core/PoolSetup.lua:15`), Widgets (`modules/Anchors.lua:464`),
Schema (`settings/Schema.lua:66`), Options (`settings/OptionsSetup.lua:98`) and Slash
(`settings/Slash.lua:26`): fourteen majors, every one but Item. Moved and consumed: **Env, Slash,
Widgets, Options**. Within those, AuraMaster calls no `LineChart`, `ChartMath`, `Autocomplete` or
`O.IdList` (no match in `core/`, `modules/`, `settings/`), so the Widgets and Options moves reach
files it loads but never drives.

## 3f — Kit revision, and the pairing rule

`grep -n 'Kit.VERSION =' <scratch>/new/testkit/framework.lua tests/_kit/framework.lua` -> **37 -> 38**.
The pairing rule (a consumer on v1.9.0 or newer takes kit revision 11 or newer in the same commit) is
satisfied by construction: both payloads are copied whole, in one commit.

Revision 38 changes the `--list` Totals (`docs/api/testkit/version-38-docs.md`, at the tag): a
declared skip is counted on its own `| Skipped | N |` row and **Total** is the cases that run. This
addon has one declared skip (the diagnostics contract's opt-out case), so `docs/test-cases.md` is
regenerated in the copy commit: `test_diagnostics_contract.lua` 9 -> 8, a `Skipped | 1` row, Total
2050 -> **2049**, which now equals the README badge (2049/2049) without moving it. Revision 38 also
adds `testkit/secrets.lua` (`Kit.secret` and siblings), opt-in; nothing installs `issecretvalue` by
default. No prose outside the payload and frozen bundles names the kit revision this addon holds
(`tests/test_lintconfig.lua:206` dates the sighted complexity gate to revision 35 and stays).

## 3g — Contract delta

Contract changes under signatures that did not move, against the four moved-and-consumed majors:

- **Slash 20.2, `lib.ParseValue` refuses `nan`, `inf`, `-inf` and overflowing literals on a number
  row** with `ERR_NUMBER` (`docs/api/Slash/version-20.2-docs.md:47-60`). AuraMaster's `/am set`
  reaches it through the descriptor's `set` seam (`settings/Slash.lua:562`, `NS.SetByPath`), and the
  schema has 44 number rows. No AuraMaster path relies on storing a non-finite number, and no suite
  pins its acceptance (`grep -n 'nan\|inf' tests/test_slash*.lua` finds none). The change closes a
  hole rather than removing a behavior. **Not a blocker.**
- **Env 2, `GetAddOnMetadata` never reads the bare global** (`docs/api/Env/version-2-docs.md:20-29`).
  `core/EnvSetup.lua:25-27` calls `Env.GetAddOnMetadata` and, degraded, `C_AddOns.GetAddOnMetadata`
  only, never the bare global. **Not a blocker.**
- **Widgets 12.1.4.3.2** (chart clip, hover re-sync, autocomplete re-hook, `maxRows` floor) and
  **Options `OptionsIdList` 4** (help-art guard via `C_AddOns.IsAddOnLoaded` only): AuraMaster calls
  neither surface (3e). **Not a blocker.**

`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` finds no
site. The headless suite after the copy: 2049 passed, 0 failed, 1 skipped (the declared opt-out).

**No blockers.**

## 3h — Tags vendored and never recorded

The listing (run before the copy) prints `v1.69.0` and `v1.70.0`: both vendored (`3656914`,
`c070393`) and never recorded. They are recorded in the consolidated span bundle written beside this
one, `docs/revendor/2026-10-07-v1.69.0-v1.70.0/`.
