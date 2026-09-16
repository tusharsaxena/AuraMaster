# Analysis — 20260916-184324

- **Addon:** AuraMaster 0.1.0
- **Verdict:** green
- **Commit:** a326ed7f79abdf86531d8374fa045c215c6762e0 (master)
- **Previous run:** 20260916-094427

## Headline

All four suites pass ([`manifest.json`](manifest.json)): lint 0/0 over 95 files, 943 cases with
nothing skipped, 9 perf scenarios, and **0 functions above CCN 15** with max CCN still 15 — so the
release gate would be satisfied on today's numbers. The run spans the launcher adoption
(`5d2520c`, `d3013bd`) plus the doc-count corrections and the CurseForge/README metadata commit
(`a17a669`, `a326ed7`): the addon grew by 559 NLOC and 65 functions while **every average held
flat**, which is growth, not densification. Nothing newly crossed a threshold and nothing is owed
a disposition.

## Suites

| Suite | Status | Result | Artifact | Moved since 20260916-094427 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 95 files | [`lint.txt`](lint.txt) | Still 0/0; scope 93 → 95 files |
| tests | pass | 943 passed, 0 skipped, 0 failed, 943 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 914 → 943 (+29) |
| perf | pass | 9 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | bytes/iter and api/iter flat on all 9; ms/iter uniformly higher (host load, not comparable) |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | Totals +559 NLOC / +65 funcs; every average unchanged bar avg tokens 66.4 → 66.3 |

**Complexity is reported in full** (from [`manifest.json`](manifest.json) `suites.complexity`, which
mirrors `lizard`'s footer in [`complexity.txt`](complexity.txt)):

| Metric | Value |
|---|---|
| Total NLOC | 21163 |
| Functions | 2446 |
| Avg NLOC / function | 7.9 |
| Avg CCN | 2.2 |
| Max CCN | 15 |
| Avg tokens / function | 66.3 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 2 |
| Files over the 1500 cap | 0 |

Every suite is a clean pass. Nothing was skipped at suite level and no case reported a `skip`
([`tests.txt`](tests.txt)), so passed and total agree and no figure here stands in for something
that was not measured.

## What moved

- **tests:** 914 → 943, +29 ([`tests.txt`](tests.txt); inventory
  [`test-cases.md`](test-cases.md)). The whole delta is accounted for by four suite files, and it
  tracks the launcher work rather than backfilling old ground: `test_launcher.lua` is new at **20**
  cases, `test_slash_verbs.lua` 37 → 40, `test_pages_filters.lua` 38 → 42,
  `test_pages_containers.lua` 22 → 24. The suite grew alongside the source (+559 NLOC), so no
  coverage gap opened in this span.
- **lint:** still 0 warnings / 0 errors, now over 95 files rather than 93
  ([`lint.txt`](lint.txt)). The two new in-scope files are `core/LauncherSetup.lua` and
  `tests/test_launcher.lua`; the libraries that arrived with the same work
  (`libs/LibDataBroker-1.1/`, `libs/LibDBIcon-1.0/`, `libs/LibKa0s/Launcher.lua`) are under
  `.luacheckrc`'s `exclude_files` and were never linted. The exclusion set itself is unchanged;
  `RESULTS.md`'s `## Lint` section restates what is out of scope, because a `0/0` row is only as
  meaningful as its scope.
- **complexity** ([`complexity.txt`](complexity.txt)): total NLOC 20604 → 21163 and functions
  2381 → 2446. Read the averages beside those totals — avg CCN **2.2 → 2.2**, avg NLOC/function
  **7.9 → 7.9**, avg tokens 66.4 → **66.3**, max CCN **15 → 15**, warnings **0 → 0**. The totals
  rose because the addon gained a launcher; the density did not move at all, and the token average
  ticked very slightly *down*. That is the distinction this section exists to keep: a rising total
  is a size fact, only a rising average is a complexity signal.
  The order at the top of the list is unchanged from the previous run: `Preview.Offset`
  (`modules/Preview.lua:24-49`) and `ContainerClass` (`modules/Container.lua:413-430`) at 15, then
  `renderCategories` (`settings/Filters.lua:394-437`), `TS.Scan` (`modules/TimedSpells.lua:58-83`)
  and `FP.NamedAncestor` (`modules/FramePicker.lua:26-40`) at 14. None of these is warned on, and
  none moved.
- **perf** ([`perf.txt`](perf.txt), against `20260916-094427/perf.txt`). `tests/perf.lua` is
  byte-identical across the two commits (`git diff 9ddad71..a326ed7 -- tests/perf.lua` is empty),
  and so are the two figures that carry signal:
  - **api/iter is identical on all nine scenarios** — `applyPass` still 22.0 engine calls per pass
    over 3 containers, `visibilityPass` 3.0, the three probe scenarios 4.0, `unitSwap` 1.0.
  - **bytes/iter is flat**: `compile` 22200.0 → 22200.0, `restyle` 49434.5 → 49434.5,
    `visibilityPass` 288.0 → 288.0, `unitSwap` and `unitAuraOther` 0.0 → 0.0. The single
    non-identical cell is `applyPass` 44907.5 → 44907.6, a 0.1-byte rounding difference.
  - The dormant probe bracket is still free: `probeOverheadOff` (288.0) equals `probeAbsent`
    (288.0), with `probeOverheadOn` at 288.5 — the launcher adoption did not put anything on the
    dormant path.
  - ms/iter rose across the board (`compile` 0.03891 → 0.05947, `restyle` 0.28693 → 0.35630, and
    similarly for every other scenario including the ones that allocate nothing). A uniform
    multiplier on scenarios whose allocation and API counts did not change is host load, not code:
    timings are orientation only and are not comparable across runs or machines, which
    [`perf.txt`](perf.txt) says on its own last line.
  - Note what this suite does **not** cover: `perf` exercises the offline scenarios in
    `tests/perf.lua`, and the launcher/minimap-button path added in this span is not one of them.

## Complexity watch list

### Functions `lizard` warned on

None. Max CCN is 15 across 2446 functions and the warning count is 0
([`complexity.txt`](complexity.txt) footer, `Warning cnt 0`, `Fun Rt 0.00`, `nloc Rt 0.00`).

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_anchors.lua` | 1100 | Accepted — case count, not tangle: 55 independent `test(` cases, no function in it above CCN 15 |
| 1000–1500 (on notice) | `tests/test_database.lua` | 1037 | Accepted — case count, not tangle: 64 independent `test(` cases, no function in it above CCN 15 |

Neither row is new and neither moved: both files are byte-identical in this span, and
[`complexity.txt`](complexity.txt) reports the same per-file footer as the previous run
(`test_anchors.lua` 918 NLOC / avg CCN 1.1, `test_database.lua` 811 NLOC / avg CCN 1.4). These are
suite files whose length is a case count, so the disposition is carried forward rather than
re-argued. On the shelf-life rule: an `Accepted` carried across three consecutive **release** runs
is owed a fix or a tracked deviation ID, and no run in `RESULTS.md`'s history is a release run —
every `manifest.json` from `20260911-141809` onward has `"release": null`, and the addon is still
at 0.1.0 untagged. The clock has therefore not started; it starts at the first `--release` run.

Nothing newly crossed a threshold in this run, so no Disposition cell is blank.

## Actions

None. No suite failed, no suite was skipped, no function is warned on, no file is over the
`layout-§1` cap, and no disposition is owed. The one thing worth carrying into the next run rather
than acting on now is the `perf` ms/iter shift: it is attributable to host load on today's
evidence (allocation and API counts are flat), and if a future run shows ms/iter high *with*
bytes/iter moving, that is a different fact and wants explaining then.
