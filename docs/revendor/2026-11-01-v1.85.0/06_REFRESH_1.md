# 06 - Refresh 1: the re-cut v1.85.0

The tag was moved on the run branch before its release was pushed. This is a refresh, so line 1 of
`01_DELTA.md` stands, and the provenance line and the `LibKa0s icons:` line do not move.

| | `git -C ../LibKa0s rev-parse --short v1.85.0^{commit}` |
|---|---|
| Old | `09a835c` (vendored in `146d913`) |
| New | `2ad1a50` |

## Why it moved

The owner's rulings of 2026-11-01: every skin's own `bar.bg`, `bar.border`, `icon.border`, `glow.color`
and `cover.dim`, a skin's None deferring and a real `bar.borderStyle` winning, plus `FS-FIX` and `FS-GATE`
(LibKa0s `docs/releasing.md`, Step 8 for v1.85.0).

## Per-file minors, old -> new

| File | Old | New |
|---|---|---|
| `Media.lua` | 11 | 12 |
| `OptionsCompose.lua` | 17 | 18 |
| `Skin.lua` | 14 | 15 |
| `SkinDefs.lua` | 24 | 25 |
| `SkinDefsOthers.lua` | 6 | 7 |
| `SkinEUI.lua` | 3 | 4 |
| `SkinPaint.lua` | 16 | 17 |
| `SkinPaintControls.lua` | 14 | 15 |
| `SkinPaintExtras.lua` | 15 | 16 |
| `Widgets.lua` | 20 | 21 |

Kit revision 49 -> 50: `skin_values.lua`, `skin_switch.lua` and their two suites.

## Contract delta and what moved here

- **Facade.** The degraded Skin facade gains `BarBorder`, answering its stored three, and `HoverArt`.
- **`disabledIf`.** A bar-family style or thickness row's field is a function; `tests/test_skin_flip.lua`'s pin moved. `settings/Layout.lua`'s reader takes font rows only and did not.
- **Numeric paths.** `Database.FollowSkin` hands `Skin.FollowOnce` a view with string keys, so no profile has its record set with its entries unmoved. No repair step is owed.
- **`S.Mark` on a pooled widget.** This addon calls neither `S.Mark` nor `S.HoverArt`, so nothing needs to untrack on release.
- **The bar's border.** `Style.BorderLook` draws through `S.BarBorder`. `tests/test_render_coverage.lua` walks `bars.borderStyleFromSkin` under WoW Midnight, because Ka0s Default's None leaves it nothing to move.

## Copy and prune

Both payloads copied from the tag; `libs/LibKa0s/` keeps the 13 declared icons and their license, and `diff -rq` names only the pruned icons. No credit change and no dead stub mirror.

## Gate

`tests/test_skin_literals.lua` retired into the kit's `test_skin_values`, with its rows moved to `tests/skin_gate.lua`; every old row went stale under a kit category. New rows: `D5`, `MC`, `A6` and `FS-AM-01`, a channel a stored color lacks. The gate's and the switch test's totals are in the run recorded by `FS-AM-REC`.
