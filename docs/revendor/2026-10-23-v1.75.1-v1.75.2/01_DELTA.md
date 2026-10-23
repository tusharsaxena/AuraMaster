Delta: LibKa0s v1.75.1 -> v1.75.2 (span: v1.75.1 v1.75.2)

# 01 - Delta: the unrecorded span, LibKa0s v1.75.1 and v1.75.2

A consolidated span bundle (`audit-review-history`), written 2026-10-23 beside
`docs/revendor/2026-10-23-v1.76.0/` as item `AM-RV` of the 2026-10-23 run "sim auto-run, QC preview
selector, mode strips, MM/KCD simulators". Between the store's `2026-10-22-v1.75.0` bundle and this
run, two plain re-vendor commits carried LibKa0s v1.75.1 and v1.75.2 and wrote no bundle for either.
This folder records both. It holds `01_DELTA.md` and `05_SUMMARY.md` only: nothing about them is
decided in retrospect.

**Base: v1.75.0**, the last recorded tag (`docs/revendor/2026-10-22-v1.75.0/`, whose line 1 states
`v1.71.0 -> v1.75.0`). Line 1 above names the span's first and last unrecorded tags, as the
re-vendor command's step 3h fixes it, not a base and a new tag.

## How the tag list was derived

Step 3h of the installed dev-copilot 2.4.0 `/dev-copilot:wow-revendor-libka0s`, run against `HEAD`
(`9ea3e82`) before this run's copy:

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)   # 2026-09-12
# the audit's walk over libs/LibKa0s and tests/_kit, plus every CLAUDE.md commit that rolls the line
grep -vxF -f recorded.txt vendored.txt
# v1.75.1
# v1.75.2
```

The carrier commits, from the payload and provenance history:

```sh
git log --format='%h %ad %s' --date=short -3 -- libs/LibKa0s tests/_kit CLAUDE.md
# 34772b4 2026-10-23 Re-vendor LibKa0s v1.75.2 (SimPanel minor 4)
# 4d425cc 2026-10-23 Re-vendor LibKa0s v1.75.1 (SimPanel minor 3)
# 4b4393c 2026-10-23 AM-RV2: refresh LibKa0s v1.75.0 payload from the moved local tag
```

Each carrier replaced `libs/LibKa0s/SimPanel.lua` alone and rolled the `CLAUDE.md` provenance line;
neither rolled `DEPENDENCIES.md:85`/`:92` or `docs/module-map.md:309`, which still named v1.75.0
until this run's copy commit moved them to v1.76.0.

## v1.75.1 (`4d425cc`; tag commit `39dfb98`)

From the LibKa0s `CHANGELOG.md` v1.75.1 block (line 121 at v1.76.0):

- **SimPanel minor 2 -> 3** (`LibKa0s-Sim-1.0` key 2.2.3): every row and control the step panel
  builds keeps its hover scripts while disabled (`SetMotionScriptsWhileDisabled(true)`).
- Every other file unchanged from v1.75.0; kit revision 41 unchanged. "Re-vendor; no call changes."

## v1.75.2 (`34772b4`; tag commit `154599c`)

From the LibKa0s `CHANGELOG.md` v1.75.2 block (line 103 at v1.76.0):

- **SimPanel minor 3 -> 4** (`LibKa0s-Sim-1.0` key 2.2.4): the picker's scenario dropdown takes the
  width the bar leaves, on one line.
- Every other file unchanged from v1.75.1; kit revision 41 unchanged. "Re-vendor; no call changes."

AuraMaster hosts no simulator (`LibKa0s-Sim-1.0` has no lookup site here), so neither tag touched a
surface it calls.
