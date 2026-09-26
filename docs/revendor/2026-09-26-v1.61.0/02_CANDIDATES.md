# 02 - Candidates: LibKa0s v1.60.0 -> v1.61.0

Sources:

```sh
git -C ../LibKa0s log --oneline v1.60.0..v1.61.0
git -C ../LibKa0s show v1.61.0:CHANGELOG.md          # the v1.61.0 block
```

## A. Delivered on the re-vendor alone

| What | Evidence | Why no host change |
|---|---|---|
| The strip, the content panel and the scroll read one rail inset | `CHANGELOG.md` v1.61.0, *Options minor 25* and *OptionsTabs minor 5* | With no rail the inset is 0 and every page is laid out as at v1.60.0. |

## B. Host change required

| Candidate | Evidence | Files it would touch | Recommendation | Blast radius |
|---|---|---|---|---|
| **`O.NavRail(ctx, spec)`**, the pinned nav rail | `CHANGELOG.md` v1.61.0, *OptionsNav minor 1* | `settings/OptionsSetup.lua`, `settings/Containers.lua` and the folded sub-pages, their tests | **Adopt**, in `SR-AM-03` (the settings redesign plan, #6) | Replaces the Filters, Layout, Bars, Icons and Text sub-pages with sections of the Containers page |

## C. Whole-module adoption

None. No major is added in this range.
