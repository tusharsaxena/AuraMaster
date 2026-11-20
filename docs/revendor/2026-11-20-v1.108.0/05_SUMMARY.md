# 05 Summary

- The tag moved from v1.107.0 to v1.108.0 (tag commit 56c20b76, local only at the time of this run, which the run expects). The base comes from the `CLAUDE.md` provenance line and agrees with the last payload commit, ffeaa16. Seventeen files moved a minor (01_DELTA 3c); the kit moves from revision 57 to 58. There was no cross-major skew before the copy.
- Span bundle: none needed. Base correction: none.
- Diffs: before the prune, both payloads matched the v1.108.0 extract byte for byte. After the prune only the undeclared icons and the voice packs differ.
- Delivered for free (class A): the secret-rect strip tooltip above the nearest readable ancestor (LibKa0s#99), the library's repaint of the strip's host edge, the menu's arrow tint and secret-label measure, the footer's layout.
- Contract blockers: none left. The composer's new spark companion (`sparkColorFromSkin`) broke the schema; the spark block opts out under U-11. The kit's `GetStatusBarTexture` walk exhausted memory on the test recorder; the recorder is fixed. One edge case re-pinned.
- The `LibKa0s icons:` line is kept as written. The prune kept the declared icons and removed the undeclared copies again; sounds: none ship (`kept 0, removed 362`). No provenance split. README credits: unchanged. Dead stub mirrors: none.
- Adopted: B1 and B2 as SD-SK-AM, the LibKa0s#99 follow-up as SD-AM-99. Not adopted here: B3 (`W.OwnerWarnings`), reported to the run's lead.
- Gate (SD-RV-AM commit): `lua tests/run.lua` 2554 passed, 0 failed, 1 skipped; `KA0S_KIT_CLIENT=forever lua tests/run.lua` 2553 passed, 0 failed, 2 skipped; `ka0s-bounded luacheck .` 0 warnings / 0 errors in 230 files. Before the fixes the Retail run had 38 failures and one shard out of memory. In-game smoke was not run and is owed to the owner.
