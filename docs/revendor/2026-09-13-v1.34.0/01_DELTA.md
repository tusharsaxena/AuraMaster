# 01 — Delta: LibKa0s v1.33.0 → v1.34.0

Run: 2026-09-13, the steps of `/wow-addon:revendor-libka0s` taken non-interactively by the
orchestrating session. No filing and no push. Target: this repo, branch `test/2026-09-12-coverage` @ `84173d6`.

Source: the sibling checkout `../LibKa0s`, **tag `v1.34.0` (tag object `9165044` → commit `33bae81`)**
on branch `feat/2026-09-13-v1.34.0`, extracted with
`git -C ../LibKa0s archive v1.34.0 LibKa0s testkit | tar -x -C <scratch>/`, never the working tree.
The tag is local to `../LibKa0s` and not yet pushed. `tests/test_vendor_sync.lua` compares against
the tag the provenance line names, so the local tag is enough.

```
git -C ../LibKa0s log --oneline v1.33.0..v1.34.0
  33bae81 v1.34.0: release test record 20260913-002423
  b9d64c7 v1.34.0: string rows keep every word; Reset-all tooltip follows the reset; kit 19
```

## 3a — Claimed version, before this run

`CLAUDE.md:35`: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) **v1.33.0** (MIT).

## 3b — Actual version, before this run

Core 7, DebugLog 12, Env 1, Item 1, Media 3, Options 17, OptionsScroll 3, OptionsWidgets 15,
OptionsCompose 4, Perf 11, PerfPanel 5, Pool 3, Slash 9, Widgets 9; kit revision 18. That is
v1.33.0's version block, so the line and the bytes agreed before the copy.

## 3c — Per-file minor delta

| File | v1.33.0 | v1.34.0 |
|---|---|---|
| Core | 7 | 7 |
| Env | 1 | 1 |
| Pool | 3 | 3 |
| Item | 1 | 1 |
| Media | 3 | 3 |
| Widgets | 9 | 9 |
| DebugLog | 12 | 12 |
| **Slash** | **9** | **10** |
| **Options** | **17** | **18** |
| OptionsWidgets | 15 | 15 |
| **OptionsCompose** | **4** | **5** |
| OptionsScroll | 3 | 3 |
| Perf | 11 | 11 |
| PerfPanel | 5 | 5 |
| **kit revision** | **18** | **19** |

No cross-major skew. The three moved files arrive in the same whole-folder copy; `Options.lua` and
`OptionsCompose.lua` are one major and move together, as the paired-minor guard requires.

## 3d — Both diffs

Payloads synced whole from the extracted tag (`rsync -a --delete`), so a file deleted upstream would
be deleted here. None was: the file lists match the tag's.

```
git status --short            # libs/LibKa0s/Options.lua, libs/LibKa0s/OptionsCompose.lua,
                              # libs/LibKa0s/Slash.lua, tests/_kit/README.md,
                              # tests/_kit/framework.lua, tests/_kit/mock_base.lua
diff -r --strip-trailing-cr ../LibKa0s/LibKa0s libs/LibKa0s   # content: empty
diff -r                     ../LibKa0s/LibKa0s libs/LibKa0s   # bytes:   empty
diff -r --strip-trailing-cr <scratch>/testkit tests/_kit      # content: empty
diff -r                     ../LibKa0s/testkit tests/_kit     # bytes:   empty
```

`../LibKa0s` was clean at `33bae81`, the tag's commit, so its working tree is the tag. Every changed
file carries as many CRs as LFs. `tests/_kit/run-automated-tests.sh` keeps mode 100755.

## 3e — Consumption map

`LibKa0s-Options-1.0` is looked up at `settings/OptionsSetup.lua:28` and `LibKa0s-Slash-1.0` at
`settings/Slash.lua:26`. Both moved majors are consumed here. Unchanged from v1.33.0.

## 3f — Kit revision, and the pairing rule

`Kit.VERSION` moves 18 → 19 in the same commit as the v1.34.0 library payload, which is the pairing
the tag ships.

## What moved (from the v1.34.0 changelog block)

- **`Slash.lua` minor 10: a free-text value keeps every word.** A `string` row takes the whole
  remainder after the path, trimmed at both ends, internal spacing kept; with `values` declared,
  the full string is matched. Through minor 9 `lib.ParseValue` split on whitespace and a `string`
  row took the first token, so `/am set container.name My Raid Buffs` stored `"My"` (found by an
  AuraMaster test agent). One input is now refused that was accepted: a valid enum entry followed by
  more words. `bool`, `number` and `color` rows parse as before.
- **`Options.lua` minor 18 and `OptionsCompose.lua` minor 5: the *Reset all settings* tooltip says
  what the reset does.** With no `resetProfile` it is unchanged; with `resetProfile` it reads "Reset
  the current profile to its defaults. Your other profiles are not affected."; with `resetProfile`
  and the new optional descriptor field `profilesPage = true` it names the equivalence with Profiles
  → Reset Profile. `profilesPage` is the one field added (O18).
- **Kit revision 19.** The AceDB fake's `ResetProfile` fires `OnProfileReset` with the database
  alone, as AceDB-3.0 does. Through revision 18 it passed the active profile's key as well.

No member is added, removed or renamed.

## Baseline, before the copy

`lua tests/run.lua`: 680 passed, 0 failed, 0 skipped, 680 total. `luacheck .`: 0 warnings / 0 errors
in 90 files.
