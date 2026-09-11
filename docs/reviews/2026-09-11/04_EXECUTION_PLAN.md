# 04 — Execution plan

Gate after **every** task: `lua tests/run.lua` green and `luacheck .` at 0/0. When a task adds or renames a case, regenerate `docs/test-cases.md` (`lua tests/run.lua --list > docs/test-cases.md`) and update the README `[tests]` badge **in the same commit**. Never edit `libs/` or `tests/_kit/`. Never stage, commit, push or bump the version without the user's explicit instruction (CLAUDE.md).

## M0 — Decisions (checkpoint; no code)
- **D-1 (F-006):** ratify the registry deviation (D-1a, recommended) or reroute through the seam (D-1b).
- **D-2 (F-002):** defer teardown (recommended), or also refuse `/am delete` in combat.
- **Done when:** the user has answered both in writing.

## M1 — Correctness (parallelizable across disjoint files)

| Task | Owner role | Implements | Files |
|---|---|---|---|
| T1.1 | lua-refactorer | C-01 / F-001 | modules/FilterCompiler.lua, modules/Container.lua, tests/test_filtercompiler.lua, tests/test_container.lua |
| T1.2 | lua-refactorer | C-04 / F-004 | modules/FramePicker.lua, tests/test_anchors.lua |
| T1.3 | lua-refactorer | C-05 / F-005 | core/Database.lua, tests/test_database.lua |

**Done when:** all three merge green, and the pass count is 154 → 158 (T1.1 +2, T1.2 +1, T1.3 +1), with the inventory and badge moved.

## M2 — Combat safety (serial after T1.1: shares modules/Container.lua)

| Task | Owner | Implements | Files |
|---|---|---|---|
| T2.1 | wow-taint-specialist | C-02 / F-002 | modules/ContainerManager.lua, modules/Container.lua, tests/test_containermanager.lua, tests/test_container.lua |

**Checkpoint:** the human runs S-02 in-client (and the taint section) before M3.

## M3 — Write path and UX (serial: all touch ContainerManager.lua, Schema.lua or enUS.lua)

| Task | Owner | Implements | Files |
|---|---|---|---|
| T3.1 | lua-refactorer | C-03 / F-003, F-012 | settings/Schema.lua, modules/ContainerManager.lua, locales/enUS.lua, tests/test_schema.lua, tests/test_containermanager.lua |
| T3.2 | lua-refactorer | C-06 / F-006, F-007 | settings/Schema.lua, settings/Containers.lua, settings/General.lua, modules/ContainerManager.lua, docs/ARCHITECTURE.md, tests/test_schema.lua |
| T3.3 | ux-cleanup | C-09 / F-013, F-018 | settings/Slash.lua, settings/General.lua, modules/ContainerManager.lua, locales/enUS.lua |

**Order:** T3.1 → T3.2 → T3.3.

**Done when:** green, with S-03, S-06 and S-09 queued.

## M4 — Performance and evidence

| Task | Owner | Implements | Files | Concurrency |
|---|---|---|---|---|
| T4.1 | perf-harness | C-07 / F-008, F-009 | tests/perf.lua, tests/wow_mock.lua | parallel with T4.3 |
| T4.2 | perf-harness | C-07 / F-010 | modules/TimedSpells.lua, core/PerfSetup.lua, tests/test_perf.lua, docs/performance.md | after T4.1 (shares the perf story and doc) |
| T4.3 | lua-refactorer | C-08 / F-011, F-020 | core/Compat.lua, modules/Style.lua, modules/Preview.lua | parallel with T4.1 |
| T4.4 | test-hygiene | C-07 / F-021 | tests/test_setups.lua, tests/test_slash.lua, tests/test_schema.lua | after T3.x (test_schema shared); mutation-verify with `cp` backups |

**Done when:** `lua tests/perf.lua` exits 0 with the new `probeAbsent` arm and no negative bytes/iter. **Checkpoint:** the human runs S-07 and S-08.

## M5 — Low hygiene

| Task | Owner | Implements | Files |
|---|---|---|---|
| T5.1 | lua-refactorer | C-10 / F-015, F-016, F-017 | modules/Container.lua, settings/Slash.lua, core/PoolSetup.lua, modules/Anchors.lua, core/AuraMaster.lua |
| T5.2 | docs | C-09 / F-014 | docs/ARCHITECTURE.md, docs/performance.md |

T5.2 runs **last**, because it cites lines that every earlier task moves.

## M6 — Upstream handoff (cross-repo)
- **T6.1 (LibKa0s repo):** U-001, model `AceGUI:Release` in `testkit/mock_base.lua`, then cut a LibKa0s release.
- **T6.2 (this repo):** a **re-vendor commit**. Copy the whole `testkit/` into `tests/_kit/` (and `LibKa0s/` into `libs/LibKa0s/` if the release touched it), bump the CLAUDE.md `Bundles … vX.Y.Z` line in the same commit, then delete tests/wow_mock.lua:128–139.
- **Done when:** `test_vendor_sync` passes against the new tag.

## Concurrency map (files shared, so tasks must serialize)
- **modules/Container.lua:** T1.1 → T2.1 → T5.1.
- **modules/ContainerManager.lua:** T2.1 → T3.1 → T3.2 → T3.3.
- **settings/Schema.lua:** T3.1 → T3.2.
- **locales/enUS.lua:** T3.1 → T3.3.
- **settings/General.lua:** T3.2 → T3.3.
- **tests/test_schema.lua:** T3.1 → T3.2 → T4.4.
- **Parallelizable:** T1.2, T1.3, T4.1 and T4.3 have disjoint file sets.

## Commit strategy (proposed; commit only on instruction)
One commit per task. Suggested messages:
- `Container: re-send enchant options on in-place update (F-001)`
- `FramePicker: check IsForbidden before touching a frame (F-004)`
- `Database: drop unnormalizable container keys (F-005)`
- `ContainerManager: park teardown until combat ends (F-002)`
- `Schema: session rows announce no apply; deferral names its cause (F-003, F-012)`
- `Write path: normalize names at the seam; ratify registry deviation (F-006, F-007)`
- `Locale: whole-sentence CLI strings, one reset key (F-013, F-018)`
- `perf: stop GC in measured loops, count-only recorder, instrumentation-absent arm (F-008, F-009)`
- `TimedSpells: bracket the scan as timedScan (F-010)`
- `Style: build formatter, curve and dispel map once per look (F-011, F-020)`
- `tests: red-under notes on negative assertions (F-021)`
- `Anchors/Container: no layout cache, retry pending after combat (F-015, F-017); stub comments (F-016)`
- `docs: resolve stale line citations (F-014)`
- `Re-vendor LibKa0s vX.Y.Z (U-001)`
