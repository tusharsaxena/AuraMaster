# 04 Execution plan

Nothing adopted, so no characterization tests and no adoption commits. The run is one AM-FP01 commit: both payloads copied whole from the tag and pruned, the provenance roll, and the two host fixes the new payload forced:

- `tests/test_surface_parity.lua`: Compat minor 4's four members join both exclusion lists (no caller here). The gate failed on them as designed ("a member the major gains later ... fails one of them until this host decides where it goes").
- `DEPENDENCIES.md`: two `tests/_kit/vendor_sync.lua` citations re-pointed at the moved lines (441 -> 598, the sibling `git -C` call; 657 -> 894, `ls-files -s`), which the docs citation gate failed on.
