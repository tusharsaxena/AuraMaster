Delta: LibKa0s v1.64.0 -> v1.65.0 (span: v1.64.0 v1.65.0)

# 01 - Delta: the unrecorded span, LibKa0s v1.64.0 and v1.65.0

A consolidated span bundle (`audit-review-history`), written 2026-10-01 beside
`docs/revendor/2026-10-01-v1.66.0/` as part of item `GI-AM-RV` of the 2026-10-01 GitHub issue pass.
Between the store's `2026-09-29-v1.63.0` bundle and this run, the 2026-09-30 debug-logging run
(`DL-AM-*`) and the 2026-09-30 LibKa0s debug-gaps run (`DG-AM-*`) vendored two LibKa0s tags and wrote
no bundle for either. This folder records both. It holds `01_DELTA.md` and `05_SUMMARY.md` only:
nothing about them is decided in retrospect.

## How the tag list was derived

Step 3h of `revendor-libka0s`, run before this run's copy:

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)
# the audit's walk over libs/LibKa0s and tests/_kit, plus every CLAUDE.md commit that rolls the line
grep -vxF -f recorded.txt vendored.txt
# v1.64.0
# v1.65.0
```

The carrier commits, from the payload and provenance history:

```sh
git log --format='%h %ad %s' --date=short 360a9f4~1..ecd2109 -- libs/LibKa0s tests/_kit
# ecd2109 2026-10-01 DG-AM-01: re-vendor LibKa0s v1.65.0 (kit 34); the DebugLog stub answers the new gates
# 63897cb 2026-09-30 DL-AM-04: re-vendor the final LibKa0s v1.64.0 (kit 34); diagnostics turns logging on for the session
# ebbd026 2026-09-30 DL-AM-03: re-vendor the re-cut LibKa0s v1.64.0 (DebugLog 16), Diagnostics link smoke check
# 08d3654 2026-09-30 DL-AM-01: re-vendor LibKa0s v1.64.0 (kit revision 33), resize smoke checks
# 360a9f4 2026-09-30 SP-FIN-01: re-vendor the test kit at revision 32 (LibKa0s v1.63.0, re-cut)
git log --format='%h %s' -p 360a9f4~1..ecd2109 -- CLAUDE.md | grep -E '^\+Bundles'
# 08d3654 rolls the line to v1.64.0; ecd2109 rolls it to v1.65.0
```

v1.64.0 was re-cut twice on the library's feature branch before it was tagged; `08d3654`, `ebbd026`
and `63897cb` each re-vendored the tag as it then stood, and the final tag (`1cb69a7`) is the one
`63897cb` carries. v1.65.0 is `6cb04da`. The previous base, v1.63.0, is recorded in
`docs/revendor/2026-09-29-v1.63.0/`, and that bundle's line 1 states its base correctly.
