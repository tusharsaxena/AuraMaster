# 02 - Candidates: LibKa0s v1.67.0 -> v1.68.0

Sources:

```sh
git -C ../LibKa0s log --oneline v1.67.0..v1.68.0
git -C ../LibKa0s show v1.68.0:CHANGELOG.md          # the v1.68.0 block
git -C ../LibKa0s show v1.68.0:docs/api/Widgets/version-12.1.4-docs.md
```

No interview. The tooltip-place bundle's `00_PLAN.md` (Scope, AuraMaster) already decides the one
candidate; this file records it.

## A. Delivered on the re-vendor alone

- **WidgetsDragHandle minor 4, the split of tooltip evaluation and drawing** (`dhTooltipLines`,
  `dhDrawTooltip`): a host with no hook gets minor 3's calls. Nothing visible moves.

## B. Host change required

| Candidate | Evidence | Taken by |
|---|---|---|
| `spec.tooltipPlace(tip, frame)` | CHANGELOG v1.68.0, *WidgetsDragHandle minor 4*; `docs/api/Widgets/version-12.1.4-docs.md:20-48` | **adopt, `TP-AM-01`'s second commit**: `modules/Anchors.lua` BuildHandle passes `tooltipPlace = NS.AnchorsTooltip.Place`, a new module that reads the strip's rect through `NS.Secrets` and puts the tooltip beside it (right, or left near the right screen edge), answering nil to fall back to the cursor. Additive: `tooltipOwner = "cursor"` stays as the fallback |
| descriptor `place` | as above, :41-43 | **none**: the strip and the close mark share one placement, so the spec-level hook covers both |

## C. Whole-module adoption

None. No major is added in this range; `LibKa0s-Item-1.0` stays unbound, as before.
