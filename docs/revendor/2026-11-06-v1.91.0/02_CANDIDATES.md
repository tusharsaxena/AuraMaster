# Candidates

Sources: `git -C ../LibKa0s log --oneline v1.90.0..v1.91.0`, the CHANGELOG block v1.91.0 and the `docs/api/`
documents of every major whose minor moved (`01_DELTA.md` 3c, 3g).

## A. Delivered on the re-vendor

- **WidgetsLineChart 6 -> 7** (FU-L1): a chart's axis, grid, markers, crosshair and series lines are physical
  pixels at any UI scale (`docs/api/Widgets/version-26.1.6.13.7.8.5-docs.md`, "What a host owes: nothing").
  AuraMaster draws no LineChart, so nothing on screen changes.
- **Core 16 -> 17 with CorePixel 1** (FU-L2): the pixel-edge internals moved to their own file, a pure move.
- **Widgets 25 -> 26 with WidgetsDropdown 1** (FU-L2): the dropdown and its shared menu moved, a pure move.
- **SkinPaintExtras 18 -> 19 with SkinPaintHud 1 and SkinAceConfirm 1** (FU-L2): `S.BarGloss`, `S.HudFont`
  and the AceConfigDialog confirmation box moved, a pure move. AuraMaster's calls of `BarGloss` and
  `HudFont` reach the same code.

## B. Host change required

None. No member, option or data field was added (CHANGELOG v1.91.0, "No member, option or behavior changes").

## C. Whole-module adoption

None new in this range. IconBrowser stays settled as in the v1.89.0 bundle (no icon chooser in AuraMaster).
