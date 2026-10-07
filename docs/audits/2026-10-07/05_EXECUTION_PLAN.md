# 05 — Execution plan: Ka0s Aura Master (2026-10-07)

This plan orders the steps that close the open deviations in `02_DEVIATIONS.md`. It covers **9 roots
and no dependents**:

- 0 High, 0 Medium, 7 Low and 2 Info;
- 5 MUST failures, all Low.

AM-03 is a recorded deviation and is not in scope. The gate after every code step is
`ka0s-bounded lua tests/run.lua` (2049 passed / 1 skipped / 2050 total, or the new figure) plus
`ka0s-bounded luacheck .` at 0/0. Commit only on green, with each commit subject starting with its id.

## Sprint 1 — record and config (no code)

- [ ] **AM-21.** Write `docs/revendor/2026-10-07-v1.69.0-v1.70.0/01_DELTA.md`, whose line 1 must read exactly `Delta: LibKa0s v1.68.1 -> v1.70.0 (span: v1.68.1 v1.69.0 v1.70.0)`, and `05_SUMMARY.md`. Re-run E-7's loop; it must print no unrecorded tag.
- [ ] **AM-35.** Make `.pkgmeta:12-13` a live `  - .claude` ignore line with its reason. Re-run packaging checks (a)–(c).
- [ ] **AM-36.** Run `gh issue edit 22 --remove-label state:untriaged --add-label state:done`.
- [ ] **AM-40.** This is the owner's decision. If accepted, add `  - media/screenshots` to `.pkgmeta` and propose the same line for packaging's template upstream.

## Sprint 2 — docs

- [ ] **AM-37.** Sweep the six launcher left-click claims (`docs/ARCHITECTURE.md:216-218`, `docs/settings-panel.md:148-149`, `modules/Preview.lua:27`, `settings/General.lua:31-32` and `:117`). Then fix the map row (`docs/ARCHITECTURE.md:384`) and the stale test comment (`tests/test_render_coverage.lua:24-25`). Grep check as in `04_TECHNICAL_DESIGN.md`.
- [ ] **AM-25.** Move `docs/ARCHITECTURE.md:73-134` into `docs/data-flow.md` and the module-map rows, and leave a short summary plus the one link. Confirm with the E-15 `awk` that Module Map is about 60 lines or fewer and the hub about 400 or fewer. `tests/test_docs.lua` must stay green.

## Sprint 3 — code (each step test-first)

- [ ] **AM-38.** Add a red case: a degraded help row carries no `—` and no `|c`. Then delete the stub `FormatRow` (`settings/Slash.lua:423`) and build the row inline (`:441`). Green.
- [ ] **AM-39.** Add a red case: a migration run with logging off, followed by `SetEnabled(true)`, shows the `[Migrate] vX -> vY` line after `[Init]`. Then route `core/Database.lua:1252–1346`, `:1377` and `:1405` through `NS.DebugLog.DebugAtEnable`. Green.
- [ ] **AM-31 (a).** Add a characterization case for `logCandidates`' exact `[Anchor]` line. Then extract `targetText` and `rectOrNone` at module level. Run `ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`; it must report 0 warnings and max CCN ≤ 15.

## Sprint 4 — the record (last)

- [ ] **AM-31 (b).** Cut a sighted four-suite run, `ka0s-bounded bash tests/_kit/run-automated-tests.sh`, on a clean tree. Check that the manifest has `blindFiles` 0 and complexity warnings 0. Write dispositions for `modules/Anchors_Snap.lua` and `tests/test_anchors_drag.lua`; the test file is 1490/1500, so name its peel seam. Commit the bundle and `RESULTS.md`.

## Traceability

| ID | Sprint | Files | Kind |
|---|---|---|---|
| AM-21 | 1 | `docs/revendor/2026-10-07-v1.69.0-v1.70.0/` | record |
| AM-35 | 1 | `.pkgmeta` | config |
| AM-36 | 1 | issue #22 | issue store |
| AM-40 | 1 | `.pkgmeta` (owner's call) | config |
| AM-37 | 2 | `docs/ARCHITECTURE.md`, `docs/settings-panel.md`, `modules/Preview.lua`, `settings/General.lua`, `tests/test_render_coverage.lua` | doc and comment |
| AM-25 | 2 | `docs/ARCHITECTURE.md`, `docs/data-flow.md`, `docs/module-map.md` | doc |
| AM-38 | 3 | `settings/Slash.lua`, degraded-env suite | code (library-absent path) |
| AM-39 | 3 | `core/Database.lua`, a database or debug suite | code (debug path) |
| AM-31 | 3–4 | `modules/Anchors_Snap.lua`, `tests/test_anchors_drag.lua` (disposition), `docs/automated-tests/` | code and record |

No step needs an in-client smoke test. AM-39 can optionally be confirmed in game: `/reload` after a
schema bump, then `/am debug on` shows the `[Migrate]` lines. The owner runs that check.
