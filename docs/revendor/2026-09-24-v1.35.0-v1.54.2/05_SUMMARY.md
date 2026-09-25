# 05 - Summary: LibKa0s v1.35.0 -> v1.54.2 (consolidated span)

Written 2026-09-24 as remediation item AM-02 (finding `AuraMaster-A-01`). The previous base was
v1.34.0 (`0c6f99f`, bundle `docs/revendor/2026-09-13-v1.34.0/`).

The sweeps and feature branches of 2026-09-13 to 2026-09-22 carried these 22 tags into
`libs/LibKa0s/` and `tests/_kit/` and wrote no bundle for any of them. Each carrier commit is
listed in `01_DELTA.md`. Nothing is decided here in retrospect, so this bundle has no
`02_CANDIDATES.md`, `03_DECISIONS.md` or `04_EXECUTION_PLAN.md`.

## The adoptions the span brought

- **DragHandle, v1.48.0** (`6462e06`): the container strip is one `KW.DragHandle` call, and
  `modules/Anchors.lua` lost its own help, tooltip, drag and label-measuring code.
- **The entry suffix, v1.49.0** (`7787b0f`): a claimed spell's `(also in N)` count is drawn
  through `entry.suffix`, and the claiming categories' names moved to the entry's tooltip.
- **The Lifecycle/Slash minor-14 floor, v1.42.0** (`42bdff6`): `core/LifecycleSetup.lua` takes
  LibKa0s-Lifecycle-1.0 as the one stand-down latch (the `disabled` and `perf` holds), Perf
  minor 12 takes the latch, and the disabled-state slash refusal moves onto Slash minor 14's
  `isEnabled`, `brandName` and `liveVerbs`. Slash minor 14 is the floor this addon now needs.

## One line per tag

- v1.35.0: adopted in `fe556b2` (ChoiceGrid), `1514e59` (`disabledIf`) and `e697a4f` (IdList)
- v1.36.0: adopted in `f4e09a4` (`SelectTab` on `NS.Helpers`)
- v1.36.1: carried by sweep, nothing adopted
- v1.36.2: carried by sweep, nothing adopted
- v1.37.0: adopted in `fec3784` (the Master controls Test mode row)
- v1.38.0: adopted in `e4cfa04` (a bare `/am` opens the settings panel)
- v1.39.0: adopted in `d3013bd` (the launcher: broker object and minimap button)
- v1.42.0: adopted in `42bdff6` (Lifecycle latch, Perf minor 12, Slash minor 14)
- v1.43.0: carried by sweep, nothing adopted
- v1.44.0: adopted in `b7832c6` (`removeStyle = "icon"` on every spell list)
- v1.45.0: adopted in `3c7ab52` (`shownWhen` on Layout -> Anchor)
- v1.46.1: carried by sweep, nothing adopted
- v1.47.0: adopted in `c0552a5` (IdList `columns`)
- v1.48.0: adopted in `6462e06` (DragHandle)
- v1.48.1: carried by sweep, nothing adopted
- v1.49.0: adopted in `7787b0f` (`entry.suffix`)
- v1.49.1: carried by sweep, nothing adopted
- v1.50.0: carried by sweep, nothing adopted
- v1.51.0: adopted in `482000f` (the entry help mark and `kind.suggestTag`)
- v1.52.0: adopted in `f434521` (`help.level`)
- v1.53.0: carried by sweep, nothing adopted
- v1.54.2: adopted in `329e1a3` (the kit's US-English gate replaces this repo's own copy)

## The v1.55.0 bundle's base

The frozen `docs/revendor/2026-09-23-v1.55.0/` bundle reads `v1.54.2 -> v1.55.0`. That base is
**correct**. `329e1a3` re-vendored v1.54.2 whole: it changed only `tests/_kit/`, because the
library bytes are identical to v1.53.0, and it rolled the `CLAUDE.md` provenance line from v1.53.0
to v1.54.2. The re-vendor before v1.55.0 was therefore v1.54.2, and that bundle stays as written.
