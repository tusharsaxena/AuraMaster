# 05 Summary

- Tag moved v1.93.0 -> v1.98.0 (tag commit 9dd6d09, pushed), base taken from the `CLAUDE.md` provenance line and agreeing with the last payload commit 238bbed. Kit revision 53 -> 56. Files that moved a minor: Compat 4, Skin 18, SkinDefsOthers 9, Media 13, Launcher 10, DebugLogDiagnostics 9, and three new files, Role 1, Callout 2, CalloutSettings 3 (table in 01_DELTA.md). No cross-major skew before the copy.
- Span bundle: none. Base correction: none.
- Diffs: before the prune, `diff -r --strip-trailing-cr` and `diff -r` of both payloads against the v1.98.0 extract were empty. After the prune only `Only in <extract>/LibKa0s/media/icons` and `.../media/sounds` lines remain, and the kit diff is empty.
- Delivered for free (class A): the Launcher peel, the diagnostics `running:` line, two new fonts in the font dropdowns, Skin 18's empty-choice cleaning (no change for this host), kit revisions 54 to 56.
- Contract blockers: none (3g).
- `LibKa0s icons:` line kept as written (13 names). Prune: `kept 14 file(s), removed 5826` (open-iconic 211, phosphor 1435, game-icons 4180, all re-removed after the whole copy; the shipped icon set is unchanged). Sounds: no line, so none; `removed 91` (both Callout voice packs). Provenance split: none needed.
- README credits: unchanged (Open Iconic only, as before; no sound pack ships). Dead stub mirrors: none (`__releaseChrome` has no mirror here).
- Host fixes in the re-vendor commit: `tests/test_surface_parity.lua` (Compat 4's members listed as no-caller), `DEPENDENCIES.md` (two kit citations re-pointed).
- Adopted: nothing. Declined: nothing. Every candidate is deferred (port run), see 03_DECISIONS.md; no GitHub issue filed.
- Gate after the copy, before the fixes: `lua tests/run.lua` 2355 passed, 3 failed (the two above, plus the line-ending check on the plan's three `.tsv` files, which AM-FP00 left LF on disk; repaired on disk with no index change). After: `lua tests/run.lua` 2358 passed, 0 failed, 1 skipped; `KA0S_KIT_CLIENT=forever lua tests/run.lua` 2358 passed, 0 failed, 1 skipped; `ka0s-bounded luacheck .` 0 warnings / 0 errors in 207 files. In-game smoke: not run, owed to the owner.
