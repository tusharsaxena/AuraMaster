# 05 — Summary

**Tag moved v1.31.0 → v1.32.0 (`e18dd12`).** Two files moved: `Options.lua` (minor 15 → 16) and
`Slash.lua` (minor 7 → 8). Every other file keeps its minor, and the kit stays at revision 17. The
per-file table is in `01_DELTA.md`. Nothing was deleted inside either payload.

**Reached the addon for free (class A).** With neither bracket field supplied, both walks run
exactly as at v1.31.0. No instance member was added, so the surface-parity exclusions do not move.

**Adopted:** B1 (the bracket on the Options and Slash descriptors, muting and tallying the seam),
B2 (the profile handler logs a reset and a copy once, worded by the event) and B3 (`CopyFrom` and
`ResetPositions` as one line each). They land in the commits after the re-vendor commit, tests
first. N is the seam's count of rows actually changed, not the library's `count`
(`03_DECISIONS.md`).

**Declined:** none. **Skipped or unreached:** none.

**Gates at the re-vendor commit.**

| Point | `lua tests/run.lua` | `luacheck .` |
|---|---|---|
| Before the copy | 252 passed, 0 failed, 0 skipped, 252 total | 0 / 0 in 62 files |
| After the copy and the provenance roll | 252 passed, 0 failed, 0 skipped, 252 total | 0 / 0 in 62 files |

The vendored-payload pair ran rather than skipped, against `../LibKa0s` at `v1.32.0`. Nothing was
pushed, and no issue was filed.
