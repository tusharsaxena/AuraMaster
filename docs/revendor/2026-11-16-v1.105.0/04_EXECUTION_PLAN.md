# 04 Execution plan

Nothing is adopted, so there are no characterization tests and no adoption commits. The run is one RV-AM commit. It carries both payloads, copied whole from the tag and then pruned, the provenance roll, and the host fixes the new payload forced:

- `core/DebugLogSetup.lua`: the library-absent DebugLog stub gains `Report` (the report streamed to chat, no pointer) and `Serialize` (one line), following `docs/api/DebugLog/version-23.11.1.5-docs.md:52-66`. The parity case failed on both, as designed.
- `settings/OptionsSetup.lua`: the Options stub gains a no-op `SideTabs` (OptionsNav minor 7, v1.100.0). The parity case failed on it.
- `tests/test_anchors_handle.lua` and `tests/test_anchors_close.lua`: the two cases that pinned the library's old cursor fallback (a second `SetOwner(UIParent, "ANCHOR_CURSOR")` after the host placer declined) are re-pinned to the new contract: one `SetOwner(UIParent, "ANCHOR_NONE")` per show and no cursor owner (`docs/api/Widgets/version-27.2.7.14.1.7.8.6.1.1-docs.md:93`, `:95`). The handle case's name now says so. This re-pins a behavior the library moved; it does not loosen the case, since it still asserts every owner and the count.
- Citations that the two stub insertions moved: `docs/ARCHITECTURE.md` (`settings/OptionsSetup.lua:440 -> 442`), `docs/midnight-quirks.md` (`:402 -> 404`) and `settings/GeneralSpells.lua`, a comment only (`:453 -> 455`). The docs citation gate failed on the first two.
- `DEPENDENCIES.md`: the sibling-checkout verify line names v1.105.0.
- `docs/test-cases.md` is regenerated for the renamed case. The README `Tests` badge is unchanged at 2523/2523.
