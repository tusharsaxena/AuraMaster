# 05 - Summary: LibKa0s v1.64.0 -> v1.65.0 (consolidated span)

Written 2026-10-01 as part of item `GI-AM-RV` of the 2026-10-01 GitHub issue pass. The previous
base was v1.63.0 (bundle `docs/revendor/2026-09-29-v1.63.0/`).

The 2026-09-30 debug-logging run and the 2026-09-30 LibKa0s debug-gaps run carried these two tags
into `libs/LibKa0s/` and `tests/_kit/` and wrote no bundle for either. Each carrier commit is listed
in `01_DELTA.md`. Nothing is decided here in retrospect, so this bundle has no `02_CANDIDATES.md`,
`03_DECISIONS.md` or `04_EXECUTION_PLAN.md`.

## One line per tag

- v1.64.0: adopted in `08d3654` (the resize smoke checks), `ebbd026` (the Diagnostics link) and
  `63897cb` (diagnostics turns logging on for the session), each with its re-vendor of the tag
- v1.65.0: adopted in `fa9dae9` (the gated sink handed to every module, the console's change gates
  and at-enable queue) and `361a381` (`docs/debug.md` Coverage names the library's tags)
