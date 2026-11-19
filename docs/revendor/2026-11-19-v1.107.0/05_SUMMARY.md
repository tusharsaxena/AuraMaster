# 05 Summary

- The tag moved from v1.106.0 to v1.107.0 (tag commit 5e96365, local only at the time of this run, which the run expects). The base comes from the `CLAUDE.md` provenance line and agrees with the last payload commit, 6917790. Two files moved a minor: WidgetsDragHandle 14 -> 15 and WidgetsDragHandleTip 1 -> 2. The kit stays at revision 57. There was no cross-major skew before the copy.
- Span bundle: `../2026-11-19-v1.106.0-v1.106.0/`, one tag (v1.106.0, vendored by 6917790 without a bundle). Base correction: none.
- Diffs: before the prune, both payloads matched the v1.107.0 extract byte for byte. After the prune only the undeclared icons and the voice packs differ.
- Delivered for free (class A): the strip's marks in the header's order, pitch and tints, the strip tooltip above the strip, and the settings mark's re-level (LibKa0s#96).
- Contract blockers: none. `spec.tooltipPlace` is no longer read; the hook is removed in AF-STRIP-AM. The secret-rect fallback beside a readable ancestor container has no library equivalent (01_DELTA 3g).
- The `LibKa0s icons:` line is kept as written. The prune kept the declared icons and removed the undeclared copies again; sounds: none ship (`kept 0, removed 362`). No provenance split. README credits: unchanged. Dead stub mirrors: none.
- Adopted: B1 as AF-STRIP-AM. Declined: none.
- Gate (AF-RV-AM commit): `lua tests/run.lua` 2560 passed, 0 failed, 1 skipped; `KA0S_KIT_CLIENT=forever lua tests/run.lua` 2559 passed, 0 failed, 2 skipped; `ka0s-bounded luacheck .` 0 warnings / 0 errors in 231 files. Before the re-pins the Retail run had 11 failures, all pinned strip literals or the beside placement. In-game smoke was not run and is owed to the owner.
