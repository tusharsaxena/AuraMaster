# Ka0s Aura Master — execution plan (2026-09-23)

Each task keeps the green gate (`lua tests/run.lua`, `luacheck .` 0/0) and moves `docs/test-cases.md`
+ the README `[tests]` badge in the same commit whenever it moves the pass count.

## M0 — Upstream (LibKa0s), cross-repo — runs first, in parallel with M1

| Task | Owner role | Implements | Where |
|---|---|---|---|
| U-1 | lib-author (LibKa0s repo) | F-004 upstream request | `LibKa0s/OptionsWidgets.lua`, `LibKa0s/OptionsTabs.lua` — additive fields, minor bumps, anti-pattern #55 review with the other candidate consumers |
| U-2 | revendor | U-1 | copy the **whole** `../LibKa0s/LibKa0s/` into `libs/LibKa0s/` (and every consumer) as its own commit; `diff -rq` empty after |

**Done when:** LibKa0s tagged with U-1; this repo's `libs/LibKa0s/` byte-identical to it in a
standalone re-vendor commit. **Never** edit `libs/` here otherwise. If U-1 is declined, record the
fork as a documented deviation row (C-04a) and close the milestone.

## M1 — Correctness and the disabled contract

| Task | Owner role | Implements | Files |
|---|---|---|---|
| T1 | lua-refactorer | C-01 (F-001) | `modules/ContainerManager.lua`, `modules/Container.lua` (only if needed), `tests/test_containermanager.lua` |
| T2 | wow-api-migrator | C-02 (F-002) | `modules/TimedSpells.lua`, `tests/test_timedspells.lua`, `tests/test_disabled.lua`, `tests/perf.lua`, `docs/performance.md` |
| T3 | lua-refactorer | C-06 (F-006) | `modules/ContainerManager.lua`, `core/LifecycleSetup.lua`, `tests/test_disabled.lua` |
| T4 | lua-refactorer | C-05 (F-005) | `core/AuraMaster.lua`, `modules/TimedSpells.lua`, `core/DebugLogSetup.lua`, `tests/test_lifecycle.lua` |
| T5 | ux-cleanup | C-09 (F-009) | `settings/General.lua`, `tests/test_disabled.lua` |
| T6 | lua-refactorer | C-07 (F-007) | `core/LifecycleSetup.lua`, degraded suite |

**Serialize:** T1 → T3 (both `modules/ContainerManager.lua`). T2 → T4 (both `modules/TimedSpells.lua`).
T2, T3, T5 all touch `tests/test_disabled.lua` → serialize in order T2 → T3 → T5. T3 → T6 (both
`core/LifecycleSetup.lua`). **Parallelizable:** T1 ∥ T2 at start.

**Checkpoint A (human):** in-client C-01, C-02, C-06, C-09 from `03_SMOKE_TESTS.md`; perf capture pair
for F-002 committed as `docs/perf-analysis/` bundles.

## M2 — Complexity (release blocker)

| Task | Owner role | Implements | Files |
|---|---|---|---|
| T7 | lua-refactorer | C-03 `SyncUserCategories` | `defaults/Categories.lua` |
| T8 | lua-refactorer | C-03 `renderCategories` | `settings/Filters.lua` |

Parallelizable (disjoint files). **Done when:** fresh `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .`
(scratch output) shows 0 warnings; suite count unchanged. Do not regenerate `docs/automated-tests/`
here — that is the release run.

## M3 — Hygiene

| Task | Owner role | Implements | Files |
|---|---|---|---|
| T9 | ux-cleanup | C-08 (F-008) | `settings/Slash.lua`, `settings/OptionsSetup.lua`, `core/PoolSetup.lua`, `tests/test_surface_parity.lua` |
| T10 | lint | C-10 (F-010) | `.luacheckrc`, `tests/test_lintconfig.lua` (if pinned) |
| T11 | docs | C-11 (F-011) | `core/Database.lua`, `modules/Container.lua` (comments only) |
| T12 | docs | C-12 (F-012) | `docs/performance.md`, `README.md` |
| T13 | lua-refactorer | C-13 (F-013, F-014) | `core/LifecycleSetup.lua`, `settings/Slash.lua`, `settings/Layout.lua`, `modules/FramePicker.lua`, `modules/ContainerManager.lua`, `core/Database.lua`, `settings/Schema.lua`, `core/Compat.lua`, tests calling the renamed seams |

**Serialize:** T9 → T13 (`settings/Slash.lua`); T11 → T13 (`core/Database.lua`); T13 after M1's T3/T6
(`core/LifecycleSetup.lua`, `modules/ContainerManager.lua`); T12 after T2 (`docs/performance.md`).
T10 ∥ T11 ∥ T12 otherwise.

## M4 — Adopt the library render (after M0)

| Task | Owner role | Implements | Files |
|---|---|---|---|
| T14 | lua-refactorer | C-04b | `settings/OptionsSetup.lua`, `settings/*.lua` page builders, `tests/test_optionssetup.lua`, `tests/test_pages_*.lua` |
| T14a | docs | C-04a (only if U-1 declined) | `docs/ARCHITECTURE.md` deviation row |

**Checkpoint B:** C-04b in-client; full regression suite.

## Commit strategy

One commit per task, e.g.:
- `Revive a destroyed container id instead of building a second anchor` (T1)
- `Filter UNIT_AURA to player and pet in the client` (T2)
- `Build no container frames while the addon is stood down` (T3)
- `Register lifecycle events one at a time and record the rejects` (T4)
- `Refuse Test mode from the panel while disabled` (T5)
- `Make the degraded latch fire only on an edge` (T6)
- `Split SyncUserCategories into its four phases` / `Pull the custom grid out of renderCategories` (T7/T8)
- `Re-vendor LibKa0s vX.Y.Z` (U-2, standalone)

Push after each milestone; do not merge without the owner's go-ahead.
