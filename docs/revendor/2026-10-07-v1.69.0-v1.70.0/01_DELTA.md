Delta: LibKa0s v1.69.0 -> v1.70.0 (span: v1.69.0 v1.70.0)

# 01 - Delta: the unrecorded span, LibKa0s v1.69.0 and v1.70.0

A consolidated span bundle (`audit-review-history`), written 2026-10-07 beside
`docs/revendor/2026-10-07-v1.71.0/` as item `RV-AM` of the 2026-10-07 review and standards-audit
remediation (finding `AM-A-01`, the audit's `AM-21`). Between the store's `2026-10-04-v1.68.1` bundle
and this run, two plain re-vendor commits carried LibKa0s v1.69.0 and v1.70.0 and wrote no bundle for
either. This folder records both. It holds `01_DELTA.md` and `05_SUMMARY.md` only: nothing about them
is decided in retrospect.

**Base: v1.68.1**, the last recorded tag (`docs/revendor/2026-10-04-v1.68.1/`, whose line 1 states
`v1.68.0 -> v1.68.1`). Line 1 above names the span's first and last unrecorded tags, as the
re-vendor command's step 3h fixes it, not a base and a new tag.

## How the tag list was derived

Step 3h of `/dev-copilot:wow-revendor-libka0s`, run against `HEAD` (`20a39d6`) before this run's copy:

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)   # 2026-09-12
# the audit's walk over libs/LibKa0s and tests/_kit, plus every CLAUDE.md commit that rolls the line
grep -vxF -f recorded.txt vendored.txt
# v1.69.0
# v1.70.0
```

44 vendored tags against 42 recorded (the recorded list also holds v1.45.0, recorded but never
vendored here). The carrier commits, from the payload and provenance history:

```sh
git log --format='%h %ad %s' --date=short 3656914^..c070393 -- libs/LibKa0s tests/_kit
# c070393 2026-10-07 chore: re-vendor LibKa0s v1.70.0
# 3656914 2026-10-06 chore: re-vendor LibKa0s v1.69.0 (kit 37; adds the line chart widget)
git log --format='%h %s' -p 3656914^..c070393 -- CLAUDE.md | grep -E '^\+Bundles'
# 3656914 rolls the line to v1.69.0; c070393 rolls it to v1.70.0
```

Both landed on `feat/2026-10-06-revendor-libka0s-v1.69.0`, merged to `master` in `bed2784`. Each
commit also rolled `DEPENDENCIES.md:85`/`:92` and `docs/module-map.md:293` with the line.

## v1.69.0 (`3656914`; tag commit `5949f4c`)

From the LibKa0s `CHANGELOG.md` v1.69.0 block (lines 227-274 at v1.71.0):

- **New file `WidgetsLineChart.lua`, minor 1**: `LibKa0s-Widgets-1.0` key 12.1.4.1 (`Widgets` 12,
  `WidgetsReorder` 1, `WidgetsDragHandle` 4, `WidgetsLineChart` 1). Adds `lib.LineChart`,
  `lib.LINE_CHART` and `lib.ChartMath`. `libs/LibKa0s/LibKa0s.xml` gains its row.
- Every other file unchanged from v1.68.1: `Core` 10, `Env` 1, `Compat` 1, `Lifecycle` 3, `Bus` 2,
  `Schema` 2, `Pool` 3, `Item` 2, `Media` 4, `Slash` key 19.1, `DebugLog` key 19.2.1, `Launcher` 5,
  `Options` key 28.2.34.2.3.8.1.7.4.2, `Perf` key 14.1.1.6. No `NEEDS_*` floor rises, no major added;
  fifteen majors across thirty-three files.
- **Kit revision 36 -> 37**: new `mock_lines.lua` (`CreateLine` on every tracked frame), loaded by
  `mock_base.lua`.

## v1.70.0 (`c070393`; tag commit `162a7fd`)

From the LibKa0s `CHANGELOG.md` v1.70.0 block (lines 160-225 at v1.71.0):

- **New file `WidgetsAutocomplete.lua`, minor 1**, and **`WidgetsLineChart` minor 1 -> 2**
  (`opts.pxPerPoint`, `ChartMath.Budget`'s optional second argument): `LibKa0s-Widgets-1.0` key
  12.1.4.2.1. `libs/LibKa0s/LibKa0s.xml` gains the autocomplete's row.
- Every other file unchanged from v1.69.0. Fifteen majors across thirty-four files.
- **Kit stays at revision 37**; its bytes are unchanged from v1.69.0.

AuraMaster draws no chart and hangs no autocomplete, so neither tag touched a surface it calls.
