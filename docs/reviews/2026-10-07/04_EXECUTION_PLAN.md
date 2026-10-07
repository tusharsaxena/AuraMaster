# AuraMaster — execution plan (review 2026-10-07)

Branch: `feat/2026-10-07-review-audit-remediation` (shared with the cross-repo run). Gate for every commit: `lua tests/run.lua` green and `luacheck .` 0/0. Run both through `ka0s-bounded`.

## M1 — Upstream handoff (cross-repo; LibKa0s)
| Task | Role | Implements | Files |
|---|---|---|---|
| U-01 | kit-maintainer (in `../LibKa0s`) | F-003 | `testkit/framework.lua` (`renderTotals` and header), a kit self-test, `Kit.VERSION` 37→38, CHANGELOG |
| U-02 | revendor (here) | F-003 | `tests/_kit/` (whole-folder copy), `docs/test-cases.md` (regenerated), `CLAUDE.md` provenance line |

**Done when:** LibKa0s carries the fix at kit 38, and AuraMaster has a **re-vendor commit** whose `docs/test-cases.md` Total equals the badge's `<Y>`. U-02 is never folded into another task. Use `/dev-copilot:wow-revendor-libka0s`.

## M2 — Local hygiene (independent of M1)
| Task | Role | Implements | Files |
|---|---|---|---|
| T-01 | lua-refactorer | C-01 / F-001 | `modules/Anchors_Snap.lua` |
| T-02 | lua-refactorer | C-02 / F-002 | `core/Database.lua`, new `core/Database_Migrations.lua`, `AuraMaster.toc`, `docs/module-map.md`, `docs/ARCHITECTURE.md` |
| T-03 | test-author | C-03 / F-004 | `tests/test_anchors_drag.lua`, new `tests/test_anchors_drag_drop.lua`, `tests/run.lua`, `docs/test-cases.md` |
| T-04 | ux-cleanup | C-04 / F-005 | `settings/Slash.lua`, `locales/enUS.lua`, `tests/test_slash_verbs.lua`, `docs/slash-dispatch.md`, `docs/test-cases.md`, `README.md` (badge) |
| T-05 | ux-cleanup | C-05 / F-006 | `settings/OptionsSetup.lua` (plus a `tests/test_pages_*.lua` expectation, if one pins lowercase) |
| T-06 | ux-cleanup | C-06 / F-007 | `settings/Slash.lua`, `locales/enUS.lua`, `docs/slash-dispatch.md` |

## Concurrency map
- T-04 and T-06 both touch `settings/Slash.lua`, `locales/enUS.lua` and `docs/slash-dispatch.md`, so they **must be serialized** (T-06 first, since it is smaller).
- T-03, T-04 and U-02 all regenerate `docs/test-cases.md`, so they **must be serialized**. Regenerate after each and never hand-merge.
- T-01 (`Anchors_Snap.lua`) and T-03 (`test_anchors_drag.lua`) touch different files, but T-03's cases pin T-01's output. Run T-01 first, then T-03.
- T-02 and T-05 are disjoint from everything else and **parallelizable**.

## Checkpoints
1. After T-02: run the full suite plus `tests/test_migrations.lua` and `tests/test_loadorder.lua` by name. Run the C-02 in-client check (old SavedVariables) before going further, because it is the only change touching the load pass.
2. After M2: the gate passes, `wc -l core/Database.lua tests/test_anchors_drag*.lua` shows all files under 1000/1500, and the sighted complexity run shows 0 warnings (scratch only, never into the repo).
3. After U-02: the vendor-sync suite passes, and the inventory Total equals the badge.

## Commits (one per task)
- `AM-REV-01: logCandidates names its per-target read (targetText); CCN 18 -> under 15 (F-001)`
- `AM-REV-02: schema step bodies move to core/Database_Migrations.lua; runner stays in Database.lua (F-002)`
- `AM-REV-03: split test_anchors_drag along drag vs drop; inventory regenerated (F-004)`
- `AM-REV-06: debug help row in the standard's wording; slash-dispatch listing row matches the output (F-007)`
- `AM-REV-04: /am select|delete prefer a name, #N is always an id, a name/id clash is refused (F-005)`
- `AM-REV-05: the container picker shows labels in their translated case (F-006)`
- `chore: re-vendor LibKa0s <tag> (kit 38: inventory Total excludes skips) (F-003)`

Every commit ends with the session's attribution trailers. Do not bump the version and do not merge without the owner's go-ahead.
