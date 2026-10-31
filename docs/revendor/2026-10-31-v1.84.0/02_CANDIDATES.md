# 02 - Candidates

Sources: `git -C ../LibKa0s log --oneline v1.83.0..v1.84.0`, the v1.84.0 block of the library's
`CHANGELOG.md`, and the tag's `docs/api/Options/`, `docs/api/Charts/`, `docs/api/Schema/` and
`docs/api/Slash/` documents.

## A. Reached this addon on the re-vendor alone

- The eight peels: pure moves, no surface changed.
- `O.ClearScroll` keeps the band's refresher.
- `ApplyLevel` allocates nothing per call (WidgetsDragHandle minor 9).
- The strip measures at its own effective scale and writes the measured text fresh (minor 10).
- The show re-fit does not apply: this addon's strip passes `onRefit`.

## B. Host change required

| Candidate | Evidence | Would touch | Blast radius | Recommendation |
|---|---|---|---|---|
| `opts.beforeGroup`, `opts.afterSubgroup` | CHANGELOG v1.84.0, OptionsFlow minor 2 | `settings/OptionsSetup.lua`, pages | replaces host render hooks | not in this brief |
| `note` row | CHANGELOG v1.84.0, OptionsFlow minor 2 | `settings/Text.lua` notes (`iconNote`, `pandemicNote`) and the Schema walks | replaces, and `NS.Schema` walkers must skip it | not in this brief |
| `O.PositionBlock` | CHANGELOG v1.84.0, OptionsCompose minor 15 | `settings/Layout.lua` | replaces owned rows, under `shownWhen` | not in this brief |
| `O.PageBanner{ acts }` | CHANGELOG v1.84.0, OptionsTabs minor 13 | `settings/OptionsSetup.lua` banner | replaces `action` | not in this brief |

## C. Whole-module adoption

| Candidate | Evidence | Recommendation |
|---|---|---|
| `LibKa0s-Charts-1.0` | `docs/api/Charts/version-1.1-docs.md` | not applicable: this addon draws no chart |
| `LibKa0s-Sim-1.0`, `LibKa0s-Glow-1.0`, `LibKa0s-Item-1.0` | settled at `docs/revendor/2026-10-22-v1.75.0/03_DECISIONS.md` | settled, premise unmoved |
