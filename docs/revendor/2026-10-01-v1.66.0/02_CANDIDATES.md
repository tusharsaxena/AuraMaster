# 02 - Candidates: LibKa0s v1.65.0 -> v1.66.0

Sources:

```sh
git -C ../LibKa0s log --oneline v1.65.0..v1.66.0
git -C ../LibKa0s show v1.66.0:CHANGELOG.md          # the v1.66.0 block
git -C ../LibKa0s show v1.66.0:docs/api/testkit/version-35-docs.md
```

Listed for the 2026-10-01 consumer census (`GI-LK-13`). None is interviewed or adopted this cycle
(spec S4 step 1).

## A. Delivered on the re-vendor alone

- **Perf minor 14, zero-count ancestors** (`P.BuildRecord`): every declared parent of a recorded
  bucket is in the record. `core/PerfSetup.lua` declares `applyContainer` within `applyPass`, so a
  capture where only the child fired now records the parent too.
- **OptionsWidgets minor 34, the failed-item guard**: a wide `RenderGrid` item that raised leaves no
  blank row and gap.
- **The four peels** (`WidgetsReorder.lua`, `SlashParse.lua`, `PerfSampler.lua`, `PerfCommands.lua`)
  and **DebugLog minor 19**: no member moves.
- **Kit revision 35's sighted complexity suite**: the runner now measures every function lizard
  1.24.0 was blind to (`docs/testing.md`, the four suites).

## B. Host change required

| Candidate | Evidence | What the host would do |
|---|---|---|
| Report-only Perf budgets | CHANGELOG v1.66.0, *Perf minor 14: report-only per-bucket budgets*; `docs/api/Perf/version-14.1.1.6-docs.md` | `budget = { msPerSec, maxMs }` on each top-level bucket in `core/PerfSetup.lua`, from the committed captures under `docs/perf-analysis/` |
| `RenderGrid(ctx, items, parent, opts)` | CHANGELOG v1.66.0, *OptionsWidgets minor 34* | Nothing obvious: the General and Containers pages draw into the page scroll with the default gap |
| `RenderTabbedSchema` opt-ins (`untabbedSkipRender`, `disabledReplaces`, `disabledNoticeFont`, `rerender`) | CHANGELOG v1.66.0, *OptionsTabs minor 8* | Possibly through `pageOpts` in `settings/OptionsSetup.lua:521`; the Filters category rows are `skipRender`, so the default partition must stay |
| The parse resolver (`textOf`) to a host `parse` | `docs/api/Slash/version-19.1-docs.md` | Only if a schema row's own `parse` wants the host's `L`; none does today |

## C. Whole-module adoption

None. No major is added in this range; `LibKa0s-Item-1.0` stays unbound, as before.
