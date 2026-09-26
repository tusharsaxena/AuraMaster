# 05 - Summary: LibKa0s v1.61.0 -> v1.62.0

## The move

Tag `v1.61.0` -> `v1.62.0` (`5dc9f5d`, a local tag), base taken from the `CLAUDE.md` provenance line.
Re-vendored in the `AM-ATS-RV` commit on `feat/2026-09-26-automated-tests-sweep`, with the provenance
line and the two other places that name the vendored tag (`DEPENDENCIES.md`'s vendor-sync paragraph,
`docs/module-map.md`'s library row). Three files moved a LibStub minor and four are new:

| File | Minor |
|---|---|
| `Options.lua` | 25 -> 26 |
| `OptionsWidgets.lua` | 31 -> 32 |
| `OptionsTabs.lua` | 5 -> 6 |
| `OptionsRegistry.lua`, `OptionsIds.lua`, `OptionsIdList.lua`, `OptionsCombat.lua` | new, 1 each |

`LibKa0s-Options-1.0` key 25.31.5.7.4.1 -> 26.1.32.1.1.6.1.7.4.1. No file was removed, no `NEEDS_*`
floor rose, no major was added. The test kit moves from revision 27 to **31**, with three new files
(`inventory.lua`, `prose_coverage.lua`, `prose_selftests.lua`).

## Delivered for free (class A)

- `ATS-20`: the runner prints `None.` under an empty watch-list table in `RESULTS.md` (kit 30).
- `ATS-21`: the runner leaves `Kit.layoutCap.exempt`'s generated files out of the band table (kit 31).
  AuraMaster declares no exempt set, so its table does not change.
- Every vendored Options file is under `layout-§1`'s 1500-line cap.

## Contract blockers

None (`01_DELTA.md` 3g).

## Carried in the re-vendor commit

- The provenance line, `DEPENDENCIES.md` and `docs/module-map.md`, rolled to `v1.62.0`.
- `docs/test-cases.md` regenerated with `lua tests/run.lua --list`. The case count does not move
  (1660). The one line that changes is the prose gate's disclosure, 181 -> 177 tracked authored
  files: the committed file carried 181 from an earlier tree, and the v1.61.0 kit already printed
  177 at the base commit, so this is a stale line refreshed, not a change the re-vendor made.
- The library-absent Options stub (`settings/OptionsSetup.lua`) needs nothing: no public member was
  added or removed, and the Options surface-parity case passed after the copy.

## Left for the owner: comment citations into code that moved

Host comments cite `libs/LibKa0s/OptionsWidgets.lua:<line>` for id-surface code that now lives in
`OptionsIds.lua` or `OptionsIdList.lua`. They are comments only and no test reads them, and
`/wow-addon:sync-docs` corrects a comment citation only on confirmation, so this commit leaves them
as they are. Where each named thing now lives:

| Citing site | Names | Now at |
|---|---|---|
| `modules/CastAura.lua:126`, `tests/general_page_helpers.lua:216` | `ID_HELP_DIM` (and `ID_HELP_TINT`) | `OptionsIdList.lua:179` |
| `modules/CastAura.lua:181` | `entryHelpLevel` | `OptionsIdList.lua:488` |
| `settings/Filters.lua:565` | `entry.note` | `OptionsIdList.lua:833` |
| `settings/Filters.lua:711`, `tests/test_pages_filters.lua:880` | `entryNoted` | `OptionsIdList.lua:849` |
| `settings/GeneralSpells.lua:246` | the spell name lookup | `OptionsIds.lua:51` |
| `settings/GeneralSpells.lua:262`, `:1168` | `entryLabel`, `entry.suffix` | `OptionsIdList.lua:301` |
| `settings/GeneralSpells.lua:270` | `loadEntry` | `OptionsIdList.lua:349` |
| `settings/GeneralSpells.lua:1200` | `entryTooltip` | `OptionsIdList.lua:383` |
| `settings/GeneralSpells.lua:1204` | `BASE_FIELDS` | `OptionsIds.lua:124` |
| `settings/GeneralSpells.lua:1211` | `suggestRow`, `decorKind` | `OptionsIds.lua:522`, `:167` |
| `settings/GeneralSpells.lua:1361` | `columns`, `ID_COLUMNS_MAX` | `OptionsIdList.lua:139` |
| `settings/GeneralSpells.lua:1370` | `entryNoWrap` | `OptionsIdList.lua:726` |
| `settings/GeneralSpells.lua:1378` | `entryNameRel`, `ID_ICON_SIZE` | `OptionsIdList.lua:666`, `:44` |
| `tests/test_pages_filters.lua:72` | `__helpTint` | `OptionsIdList.lua:530` |
| `tests/test_pages_filters.lua:94` | `listHasHelp` | `OptionsIdList.lua:437` |

## Adopted

Nothing. The sweep plan puts adoption out of scope, and there is no candidate (`03_DECISIONS.md`).

## Declined

None. No issue filed.

## Skipped or unreached

None.

## Suite results

Run through `ka0s-bounded` from the repo root: `lua tests/run.lua`, `luacheck .`,
`lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .`.

| Gate | Headless tests | Lint | Complexity |
|---|---|---|---|
| Before the copy (v1.61.0) | 1660 passed / 0 failed / 0 skipped | 0 / 0 in 140 files | 0 above CCN 15 |
| After the re-vendor commit (v1.62.0) | 1660 passed / 0 failed / 0 skipped | 0 / 0 in 140 files | 0 above CCN 15 |

`tests/test_vendor_sync.lua` compared both payloads against `v1.62.0` and passed. No authored Lua
file is over 1500 lines (largest `tests/test_anchors.lua`, 1481).
