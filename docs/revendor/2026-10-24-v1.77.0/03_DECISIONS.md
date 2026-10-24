# 03 — Decisions

These are decided by the run's item spec (`AM-RV`, Ka0sAddonsCommonTasks
`docs/2026-10-24-KEYBINDS_LAYOUT_STRATA/plan-data/items.json`). There is no interview. The
adoptions this run needs are its AM-ZS item's, every other candidate is recorded as deferred, and no
GitHub issue is filed.

| Candidate | Decision | Source |
|---|---|---|
| DragHandle `spec.level` / `ApplyLevel` / `ignoreParentAlpha` | adopted in this run by AM-ZS, not by this item | item spec; LibKa0s CHANGELOG v1.77.0 adopter list |
| `O.StrataTooltip` | adopted in this run by AM-ZS, not by this item | same |
| kit `mock_layers.lua` | used by AM-ZS's suites, not by this item | same |
| `O.KeybindingsTab` / `O.KeybindRows` / `O.KEYBINDS_UNCHANGED` | deferred (run 2026-10-24); options-ui-§20 does not apply while AuraMaster ships no `Bindings.xml` | item spec |
| `Core.RaiseStaticPopups` | deferred (run 2026-10-24) | item spec |
| kit `mock_bindings.lua`, `Kit.assertBindingsXml`, `Kit.keybindThroughTab` | deferred (run 2026-10-24); no `Bindings.xml` to check | item spec |
| `LibKa0s-Sim-1.0` | not adopted (settled at v1.75.0, premise unmoved) | `docs/revendor/2026-10-22-v1.75.0/03_DECISIONS.md` |
| `LibKa0s-Glow-1.0`, `LibKa0s-Item-1.0` | not adopted (settled) | same |
