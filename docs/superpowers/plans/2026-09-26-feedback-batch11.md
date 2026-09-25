# Feedback batch 11 Implementation Plan

> Run as Workflow orchestration (ultracode): one implementer and one independent reviewer per task.

**Spec:** `docs/superpowers/specs/2026-09-26-feedback-batch11-design.md` (binding). The batch 9 plan's
global constraints and resume rules apply unchanged, with commit prefix `B11-`.

**Lesson (batch 10 F7):** a migration step already pushed to the branch is never extended again. Add a new step.

## Status ledger

| Task | Req | Status | Commit | Notes |
|---|---|---|---|---|
| T1 points model, defaults, v11 migration | G2 G3 G4 G5 | done | the `B11-T1: ` commit (a commit cannot hold its own hash) | KEY NAMES: the child point is stored as `attach.childPoint`, not the spec's `attach.point`, because `attach.point`/`.relativePoint` already hold a named frame's corners with template defaults (TOPLEFT/BOTTOMLEFT) that the backfill stamps on every container, so nil could never mean Automatic there; the parent point is `attach.relPoint` as specified; neither is declared in the template (nil = Automatic; T2's rows must keep that, e.g. no template default or a sentinel the loader keeps: `normalizeAttach` drops any stored value that is not one of the nine WoW points). Anchors: `AttachPoints(cfg)` (point, rel, pointAuto, relAuto, growH, growV), `DefaultEdge(cfg)` is G3 (Text child by its justify, icons/bars under a CENTER Text parent centered, else after-start), `AttachEdge(cfg)` classifies (token or nil = free) via tables built at load (allocation-free), `EdgePoints` reads the same tables; attachSpec/ownSide/JoinText/pin use them, a free pair is placed at X/Y alone with no seam, spread or push and its strip/label on its own before side (H0); `EdgeAllowed` refuses no token, `ResolvedEdge`/`EdgeLabel`/`C.EDGE_SIDE_LABELS` removed; FLOW_PATHS: childPoint, relPoint, style, text.justifyH (perLine and attach.edge out); ContainerManager PARENT_PATHS: the two points. Layout: batch 9's Side row, its values/validate, the fallback note and the new-attachment stamp removed (an attachment writes no points; picks survive attach, retarget and detach), the joins line reads AttachPoints; 12 dead locale keys removed, the Container row help reworded. Database: template `edge` removed; `MigrateV11` + ladder row {to=11}: drop after-start (and an unknown token), convert any other side to the points batch 10 resolved it to (behind on a wide child read as after, the chain root's growth from that profile's own raw containers, frozen in the step), keep stored points, remove `attach.edge`, idempotent; normalizeAttach now validates the points. Tests: new suite test_anchors_points (17); v11 tests in test_migrations (unit, every growth vs EdgePoints, kept points, ladders from v10/v9/v8/v1 in every profile, load normalize); edges/strip/column/pages/diagnostics/database cases rewritten for points; schema 10s -> 11 (per-profile log count 20). Docs: schema.md (attach rows, load pass, v11 entry, 256 rows, Layout 36), ARCHITECTURE, data-flow, known-limitations, module-map, settings-panel, README, citations remapped; test-cases + badge 1604 |
| T2 two anchor-point dropdowns, `/am set`, diagnostics | G1 G7 | todo | | |
| T3 remove the join dot | G6 | todo | | |
| T4 docs sync, smoke section AC, full battery | all | todo | | |

## Checkpoint log

| When | Milestone | Evidence |
|---|---|---|
