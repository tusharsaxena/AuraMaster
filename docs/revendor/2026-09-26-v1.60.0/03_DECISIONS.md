# 03 - Decisions

No interview was held. The 2026-09-25 diagnostics rollout plan decided every candidate in this release
before it was cut (`Ka0sAddonsCommonTasks/docs/2026-09-25-DIAGNOSTICS_COMMAND/03_EXECUTION_PLAN.md`,
M3; `OWNER_RULINGS.md` DR-OW-01 Q3), and this run answers from the plan. No decline issue is filed.

| Candidate | Decision | Where it lands | Source |
|---|---|---|---|
| The shared diagnostics report (DebugLogDiagnostics 1) | **adopt** | `DR-AM-02`: move `modules/Diagnostics.lua`'s plumbing onto the helper, markers per STD-08, cap from `lib.DIAG_MAX_LINES`, `tests/test_diagnostics.lua` adjusted | Owner ruling Q3 (a) |
| `Kit.diagnostics` (kit revision 27) | **adopt** | Registered here as a declared skip; wired in `DR-AM-02` with the report | Plan, STD-19 |
| Slash 16 `diagnostics` live verb | not a candidate (class A) | Already in AuraMaster's live set | `02_CANDIDATES.md` A |
| The buffer change | not an adoption (class A) | Delivered on the copy; the doc ripple (`core/DebugLogSetup.lua:5` and the docs) is `DR-AM-05` | Plan, M3 |
| WidgetsDragHandle close mark | not in this range | Adopted in batch 8 (v1.59.0) | Plan, M3 table |
